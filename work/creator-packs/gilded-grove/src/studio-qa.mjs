import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {McpClient,findStudioMcp,selectStudioStrict,waitForDataModels} from '../../../automation/scripts/studio_mcp_client.mjs';
const [id,mode,input,report]=process.argv.slice(2);
if(!id||!['luau','capture','console'].includes(mode)||!input)throw Error('studio-qa STUDIO_ID luau|capture|console INPUT [REPORT]');
const c=new McpClient(findStudioMcp(),'gilded-grove-local-qa');
try{
 await c.initialize();
 await selectStudioStrict(c,{studioInstanceId:id,studioName:'^(Place1|GildedGrove.*)$'});
 await waitForDataModels(c,['Edit'],30000);
 const r=mode==='console'
  ?await c.callTool('get_console_output',{},35000)
  :mode==='capture'
  ?await c.callTool('screen_capture',{capture_id:'gilded-grove',...JSON.parse(input)},35000)
  :await c.callTool('execute_luau',{datamodel_type:'Edit',code:fs.readFileSync(path.resolve(input),'utf8')},35000);
 if(report){
  fs.mkdirSync(path.dirname(path.resolve(report)),{recursive:true});
  if(mode==='capture'){
   const im=r.content.find(x=>x.type==='image');
   if(!im)throw Error(r.text);
   fs.writeFileSync(report,Buffer.from(im.data,'base64'));
  }else fs.writeFileSync(report,JSON.stringify({at:new Date().toISOString(),studio:id,isError:r.isError,text:r.text},null,2));
 }
 console.log(r.text.slice(0,14000));
 if(r.isError)process.exitCode=1;
}finally{c.close();}
