// Consume completed exports sequentially in the one isolated Studio instance.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
import {createHash} from 'node:crypto';
const exec=promisify(execFile);
const [id,input,flowRunner]=process.argv.slice(2);
if(!id||!input||!flowRunner)throw Error('studio-batch STUDIO_ID CATALOG_OUTPUT_DIR FLOW_RUNNER_PATH');
const here=path.dirname(fileURLToPath(import.meta.url));
const root=path.resolve(here,'../../..');
const out=path.resolve(input);
const slugs=fs.readdirSync(path.join(here,'packs')).filter(n=>n.endsWith('.py')).map(n=>n.slice(0,-3).replaceAll('_','-')).sort();
const report={status:'WORKING',studio:id,scope:'Local Studio geometry and visual preview; no persistent uploaded assets',packs:[]};
const pending=new Set(slugs);
const started=Date.now();
const save=()=>fs.writeFileSync(path.join(out,'studio-batch-validation.json'),JSON.stringify(report,null,2)+'\n');
const sha=file=>createHash('sha256').update(fs.readFileSync(file)).digest('hex');
while(pending.size){
 if(Date.now()-started>3600000)throw Error('Timed out waiting for final export prerequisites');
 for(const slug of [...pending]){
  const dir=path.join(out,slug);
  const gate=path.join(dir,'evidence/package-validation.json');
  if(!fs.existsSync(gate))continue;
  if(JSON.parse(fs.readFileSync(gate)).status!=='PASS')throw Error('Package prerequisite failed '+slug);
  const evidence=path.join(dir,'evidence');
  try{
   await exec(process.execPath,[path.join(here,'studio-preview.mjs'),id,dir],{timeout:180000,windowsHide:true,maxBuffer:2000000});
   const flow=path.join(root,'work/automation/flows/creator-packs',`catalog-${slug}-local-preview.json`);
   const flowHash=sha(flow),manifestHash=sha(path.join(dir,'manifest.json'));
   const check=await exec(process.execPath,[flowRunner,'--flow',flow],{timeout:90000,windowsHide:true,maxBuffer:2000000});
   const result=JSON.parse(check.stdout);
   if(sha(flow)!==flowHash||sha(path.join(dir,'manifest.json'))!==manifestHash)throw Error('Inputs changed during Studio flow execution');
   result.flow_sha256=flowHash;result.manifest_sha256=manifestHash;result.executed_at=new Date().toISOString();
   fs.writeFileSync(path.join(evidence,'studio-flow.json'),JSON.stringify(result,null,2)+'\n');
   if(!result.ok||!result.results?.[0]?.ok)throw Error('Recorded flow failed');
   await exec(process.execPath,[path.join(here,'../gilded-grove/src/studio-qa.mjs'),id,'capture',JSON.stringify({camera_position:[36,42,546],look_at_position:[0,1,500]}),path.join(evidence,'studio-preview.png')],{timeout:60000,windowsHide:true});
   report.packs.push({slug,status:'PASS',flow,models:12,capture:'evidence/studio-preview.png'});
  }catch(error){
   report.packs.push({slug,status:'FAIL',error:String(error),stdout:error.stdout,stderr:error.stderr});
  }
  pending.delete(slug);save();
  console.log(JSON.stringify(report.packs.at(-1)));
 }
 if(pending.size)await new Promise(r=>setTimeout(r,2000));
}
report.status=report.packs.every(p=>p.status==='PASS')?'PASS':'FAIL';save();
process.exitCode=report.status==='PASS'?0:1;
