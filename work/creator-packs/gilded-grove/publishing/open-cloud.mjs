import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import https from 'node:https';
import {Buffer} from 'node:buffer';

const ORIGIN = 'https://apis.roblox.com';
const USER_ID = '9158952231';
export const title = 'Gilded Grove - Merchant & Loot';
export const description = '24 original stylized merchant and loot props in Teal, Ember and Amethyst palettes. Visual models only; no gameplay systems. Includes chests, crates, barrel, coffer, display tray, treasure cart, coins, gems, crystals, bottle, medallion, hammer, merchant stall, upgrade station, reward pedestal, shop sign, lantern post, shelf, fence and portal arch. Separate selected lids and cart wheels for authoring. 24 unique base props, 72 palette variants. Lighting depends on your experience.';

async function save(file, record) {
  await fs.mkdir(path.dirname(file), {recursive: true});
  await fs.writeFile(file, JSON.stringify(record, null, 2) + '\n', 'utf8');
}
async function read(file) {
  try { return JSON.parse(await fs.readFile(file, 'utf8')); }
  catch (e) { if (e.code === 'ENOENT') return null; throw e; }
}
function keyHeader(apiKey) {
  if (typeof apiKey !== 'string' || apiKey.length < 20) throw Error('A valid assets read/write key is required in memory');
  return {'x-api-key': apiKey};
}
function requestJson(url, {method='GET',headers,body,timeout=25000}) {
  if (new URL(url).origin !== ORIGIN) throw Error('Unexpected API destination');
  return new Promise((resolve,reject)=>{
    const req=https.request(url,{method,headers},res=>{
      const chunks=[];
      res.on('data',chunk=>chunks.push(chunk));
      res.on('end',()=>{try{resolve({status:res.statusCode,ok:res.statusCode>=200&&res.statusCode<300,body:JSON.parse(Buffer.concat(chunks).toString('utf8'))});}catch{reject(Error('Non-JSON API response'));}});
      res.on('error',reject);
    });
    req.setTimeout(timeout,()=>req.destroy(Error('API request timeout')));
    req.on('error',reject);
    req.end(body);
  });
}
export async function inspectPayload(file) {
  const bytes = await fs.readFile(file);
  if (bytes.length < 20 || bytes.length > 20 * 1024 * 1024) throw Error('GLB must be below the 20MB upload limit');
  if (bytes.toString('utf8', 0, 4) !== 'glTF' || bytes.readUInt32LE(4) !== 2 || bytes.readUInt32LE(8) !== bytes.length) throw Error('Invalid GLB2 envelope');
  const jsonLength = bytes.readUInt32LE(12);
  const gltf = JSON.parse(bytes.toString('utf8', 20, 20 + jsonLength));
  if (gltf.asset?.version !== '2.0') throw Error('Expected glTF2 asset');
  return {bytes, sha256: crypto.createHash('sha256').update(bytes).digest('hex'), gltf};
}

// The caller owns the secret; it is never persisted, printed or placed in a URL.
// A journal is written before the POST; ambiguous outcomes require reconciliation.
export async function createModel({file, journal, apiKey}) {
  const payload = await inspectPayload(file);
  const prior = await read(journal);
  if (prior) {
    if (prior.sha256 !== payload.sha256) throw Error('Journal belongs to different content');
    if (prior.operation || prior.assetId) return prior;
    throw Error('An earlier upload needs reconciliation; refusing another POST');
  }
  const headers = keyHeader(apiKey);
  const record = {at: new Date().toISOString(), state:'STARTED', file:path.resolve(file), sha256:payload.sha256, bytes:payload.bytes.length, creatorId:USER_ID, title};
  const boundary='GildedGrove'+crypto.randomBytes(18).toString('hex');
  const metadata=JSON.stringify({assetType:'Model', displayName:title, description, creationContext:{creator:{userId:USER_ID}, expectedPrice:0}});
  const name=path.basename(file);
  if (!/^[A-Za-z0-9_.-]+$/.test(name)) throw Error('Use a simple GLB filename');
  const body=Buffer.concat([
    Buffer.from(`--${boundary}\r\nContent-Disposition: form-data; name="request"\r\n\r\n${metadata}\r\n--${boundary}\r\nContent-Disposition: form-data; name="fileContent"; filename="${name}"\r\nContent-Type: model/gltf-binary\r\n\r\n`),
    payload.bytes, Buffer.from(`\r\n--${boundary}--\r\n`)
  ]);
  headers['content-type']=`multipart/form-data; boundary=${boundary}`;
  headers['content-length']=String(body.length);
  await save(journal, record);
  let response;
  try { response = await requestJson(`${ORIGIN}/assets/v1/assets`, {method:'POST', headers, body, timeout:120000}); }
  catch (e) { record.state='UNKNOWN'; record.error=String(e.message); await save(journal, record); throw Error('Upload outcome uncertain; inspect journal and inventory before any retry'); }
  const responseBody = response.body;
  record.httpStatus=response.status;
  record.response=responseBody;
  if (!response.ok) {record.state='REJECTED'; await save(journal, record); return record;}
  if (!/^operations\/[A-Za-z0-9-]+$/.test(responseBody.path || '')) {record.state='UNKNOWN'; await save(journal,record); throw Error('Unrecognized operation response');}
  record.state='PROCESSING'; record.operation=responseBody.path;
  await save(journal, record);
  return record;
}

export async function pollModel({journal, apiKey}) {
  const record = await read(journal);
  if (!record?.operation || !/^operations\/[A-Za-z0-9-]+$/.test(record.operation)) throw Error('No valid pending operation');
  const response = await requestJson(`${ORIGIN}/assets/v1/${record.operation}`, {headers:keyHeader(apiKey)});
  if (!response.ok) throw Error(`Operation check returned HTTP${response.status}; retained existing journal`);
  const body = response.body;
  record.operationResponse=body; record.checkedAt=new Date().toISOString();
  if (body.done) {
    if (body.error) record.state='FAILED';
    else if (/^\d+$/.test(String(body.response?.assetId || ''))) {record.state='UPLOADED';record.assetId=String(body.response.assetId);}
    else record.state='UNKNOWN';
  }
  await save(journal,record);
  return record;
}

export async function getMetadata({assetId, apiKey}) {
  if (!/^\d+$/.test(String(assetId))) throw Error('Expected numeric asset ID');
  const response=await requestJson(`${ORIGIN}/assets/v1/assets/${assetId}`,{headers:keyHeader(apiKey)});
  if (!response.ok) throw Error(`Metadata check returned HTTP${response.status}`);
  return response.body;
}

// Updating an existing native Model preserves its ordinary Model identity.
// Keep the native binary backup and verified transform audit with this journal.
export async function updateNativeModel({file, journal, assetId, apiKey}) {
  if (String(assetId)!=='122456766146790') throw Error('This correction is restricted to the approved first product');
  const bytes=await fs.readFile(file);
  if (path.extname(file)!=='.rbxm' || bytes.subarray(0,8).toString()!=='<roblox!' || bytes.length>20*1024*1024) throw Error('Expected native RBXM under 20MB');
  const sha256=crypto.createHash('sha256').update(bytes).digest('hex');
  const prior=await read(journal);
  if (prior) {
    if (prior.sha256!==sha256 || prior.assetId!==String(assetId)) throw Error('Journal does not match the correction');
    if (prior.operation) return prior;
    throw Error('Earlier correction outcome requires reconciliation');
  }
  const metadata=await getMetadata({assetId,apiKey});
  if (String(metadata.creationContext?.creator?.userId)!==USER_ID || metadata.revisionId!=='1') throw Error('Unexpected owner or remote revision; reconcile before overwriting');
  const record={at:new Date().toISOString(),state:'STARTED',method:'PATCH',assetId:String(assetId),previousRevision:'1',file:path.resolve(file),sha256,bytes:bytes.length,creatorId:USER_ID};
  const boundary='GildedGrove'+crypto.randomBytes(18).toString('hex');
  const request=JSON.stringify({assetType:'Model',assetId:String(assetId),creationContext:{creator:{userId:USER_ID},expectedPrice:0}});
  const name=path.basename(file);
  if (!/^[A-Za-z0-9_.-]+$/.test(name)) throw Error('Use a simple RBXM filename');
  const body=Buffer.concat([Buffer.from(`--${boundary}\r\nContent-Disposition: form-data; name="request"\r\n\r\n${request}\r\n--${boundary}\r\nContent-Disposition: form-data; name="fileContent"; filename="${name}"\r\nContent-Type: model/x-rbxm\r\n\r\n`),bytes,Buffer.from(`\r\n--${boundary}--\r\n`)]);
  const headers={...keyHeader(apiKey),'content-type':`multipart/form-data; boundary=${boundary}`,'content-length':String(body.length)};
  await save(journal,record);
  let response;
  try { response=await requestJson(`${ORIGIN}/assets/v1/assets/${assetId}`,{method:'PATCH',headers,body,timeout:120000}); }
  catch {record.state='UNKNOWN';await save(journal,record);throw Error('Correction outcome uncertain; reconcile remote revision before retry');}
  record.httpStatus=response.status;record.response=response.body;
  if (!response.ok) record.state='REJECTED';
  else if (/^operations\/[A-Za-z0-9-]+$/.test(response.body.path||'')) {record.state='PROCESSING';record.operation=response.body.path;}
  else record.state='UNKNOWN';
  await save(journal,record);
  return record;
}
