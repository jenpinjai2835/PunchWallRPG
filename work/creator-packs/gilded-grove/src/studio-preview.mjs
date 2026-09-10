import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {McpClient,findStudioMcp,selectStudioStrict,waitForDataModels} from '../../../automation/scripts/studio_mcp_client.mjs';
const [id,input,report]=process.argv.slice(2);
if(!id||!input||!report)throw Error('studio-preview STUDIO_ID GEOMETRY_DIR REPORT');
const template=fs.readFileSync(path.join(path.dirname(fileURLToPath(import.meta.url)),'studio-preview.lua'),'utf8');
const files=fs.readdirSync(input).filter(x=>/^\d\d_.*\.json$/.test(x)).sort();
if(files.length!==24)throw Error(`Expected 24 assets, got ${files.length}`);
const c=new McpClient(findStudioMcp(),'gilded-grove-native-preview');
const evidence={at:new Date().toISOString(),studio:id,method:'EditableMesh from actual exported GLB geometry; local preview only',results:[]};
try{
 await c.initialize();
 await selectStudioStrict(c,{studioInstanceId:id,studioName:'^(Place1|GildedGrove.*)$'});
 await waitForDataModels(c,['Edit'],30000);
 for(const file of files){
  const raw=fs.readFileSync(path.join(input,file),'utf8');
  const r=await c.callTool('execute_luau',{datamodel_type:'Edit',code:template.replace('__ASSET_JSON__',()=>raw)},35000);
  evidence.results.push({file,isError:r.isError,text:r.text});
  fs.mkdirSync(path.dirname(path.resolve(report)),{recursive:true});
  fs.writeFileSync(report,JSON.stringify(evidence,null,2));
  if(r.isError||!r.text.includes('PASS'))throw Error(r.text);
  console.log(file+': PASS');
 }
 evidence.status='PASS';
 fs.writeFileSync(report,JSON.stringify(evidence,null,2));
}finally{c.close();}
