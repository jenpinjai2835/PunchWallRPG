import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';
import {McpClient,findStudioMcp,selectStudioStrict,waitForDataModels} from './studio_mcp_client.mjs';
const id=process.argv[2];assert(id,'Explicit Studio id required');
const expectedName=process.argv[3]??'^PunchWallRPGPlayable_v1_final[.]rbxlx$';
const specs=[
 ['shared/GameConfig.lua','ReplicatedStorage','GameConfig','ModuleScript'],
 ['shared/PolishConfig.lua','ReplicatedStorage','PolishConfig','ModuleScript'],
 ['shared/ForestVisualBuilder.lua','ReplicatedStorage','ForestVisualBuilder','ModuleScript'],
 ['shared/FistVisualBuilder.lua','ReplicatedStorage','FistVisualBuilder','ModuleScript'],
 ['shared/InventoryViewModel.lua','ReplicatedStorage','InventoryViewModel','ModuleScript'],
 ['server/ProfilePersistence.lua','ServerScriptService','ProfilePersistence','ModuleScript'],
 ['server/PunchWallBootstrap.server.lua','ServerScriptService','PunchWallBootstrap','Script'],
 ['client/InventoryUI.lua','StarterPlayer.StarterPlayerScripts','InventoryUI','ModuleScript'],
 ['client/PunchWallClient.client.lua','StarterPlayer.StarterPlayerScripts','PunchWallClient','LocalScript'],
];
const sourceRoot=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../punch-wall-rpg/src');
const localLua=fs.readdirSync(sourceRoot,{recursive:true,withFileTypes:true}).filter(d=>d.isFile()&&d.name.endsWith('.lua')).map(d=>path.resolve(d.parentPath,d.name));
assert.equal(localLua.length,specs.length,'Unexpected local production Lua inventory');
for(const [relative]of specs)assert(localLua.includes(path.resolve(sourceRoot,relative)),`Missing mapped source ${relative}`);
const c=new McpClient(findStudioMcp(),'smash-readonly-live-source-check');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const norm=s=>s.replace(/\r\n?/g,'\n');
try{
 await c.initialize();const selected=await selectStudioStrict(c,{studioInstanceId:id,studioName:expectedName});await waitForDataModels(c,['Edit'],35000);
 const r=await c.callTool('execute_luau',{datamodel_type:'Edit',code:`local H=game:GetService('HttpService') local out={} local count=0 for _,d in ipairs(game:GetDescendants()) do if d:IsA('LuaSourceContainer') then count+=1 local s={name=d.Name,class=d.ClassName,parent=d.Parent:GetFullName()} if d:IsA('BaseScript') then s.disabled=d.Disabled s.runContext=d.RunContext.Name end table.insert(out,s)end end return H:JSONEncode({count=count,scripts=out,placeId=game.PlaceId,name=game.Name})`},35000);
 assert(!r.isError,r.text);const live=JSON.parse(r.text);assert.equal(live.count,9,'Unexpected live global code objects');assert.equal(live.placeId,0,'Expected local task place');assert(new RegExp(expectedName,'i').test(live.name),'Live place name mismatch');
 const checked=[];
 for(const [relative,parent,name,className]of specs){
  const matches=live.scripts.filter(s=>s.name===name&&s.class===className&&s.parent===parent);assert.equal(matches.length,1,`Missing/duplicate/relocated ${name}`);
  if(className!=='ModuleScript'){assert.equal(matches[0].disabled,false,`Disabled ${name}`);assert.equal(matches[0].runContext,'Legacy',`Wrong RunContext for ${name}`);}
  const disk=fs.readFileSync(path.resolve(sourceRoot,relative),'utf8');const expected=norm(disk);let eq='=';while(expected.includes(']'+eq+']'))eq+='=';
  // Compare all actual bytes in Studio without returning a truncated source dump.
  // Prefix a non-newline sentinel because Lua long strings strip a leading newline.
  const literal='['+eq+'[!'+expected+']'+eq+']';
  const expression='game.'+parent+'.'+name;
  const checkedResult=await c.callTool('execute_luau',{datamodel_type:'Edit',code:`local item=${expression} local expected=string.sub(${literal},2) local actual=string.gsub(item.Source,'\\r\\n?','\\n') local exact=actual==expected return game.HttpService:JSONEncode({ok=exact,name=item.Name,actualBytes=#actual,expectedBytes=#expected})`},35000);
  assert(!checkedResult.isError,checkedResult.text);const proof=JSON.parse(checkedResult.text);assert.equal(proof.ok,true,`Live source mismatch: ${name}`);assert.equal(proof.actualBytes,Buffer.byteLength(expected));
  checked.push({name,parent,class:className,disabled:matches[0].disabled,runContext:matches[0].runContext,normalizedSHA256:sha(expected),rawSHA256:sha(disk),exactByteComparison:proof});
 }
 console.log(JSON.stringify({ok:true,checkedAt:new Date().toISOString(),readOnly:true,selectedStudio:selected,placeId:live.placeId,placeName:live.name,globalCodeObjectCount:live.count,sources:checked},null,2));
}finally{c.close();}
