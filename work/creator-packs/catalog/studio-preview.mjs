// Local visual QA only. EditableMesh content is not an uploaded Store asset.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {McpClient,findStudioMcp,selectStudioStrict,waitForDataModels} from '../../automation/scripts/studio_mcp_client.mjs';
const [id,input]=process.argv.slice(2);
if(!id||!input)throw Error('studio-preview STUDIO_ID PACK_OUTPUT_DIR');
const here=path.dirname(fileURLToPath(import.meta.url));
const packDir=path.resolve(input);
const manifest=JSON.parse(fs.readFileSync(path.join(packDir,'manifest.json')));
const gate=JSON.parse(fs.readFileSync(path.join(packDir,'evidence/native-roundtrip.json')));
if(gate.status!=='PASS'||manifest.assets.length!==12)throw Error('Final export prerequisite has not passed');
const template=fs.readFileSync(path.join(here,'../gilded-grove/src/studio-preview.lua'),'utf8')
 .replaceAll('GildedGrovePreview','CreatorCatalogPreview')
 .replace('Vector3.new((data.index % 6 - 2.5) * 8, 0, -(math.floor(data.index / 6) - 1.5) * 8)',
          'Vector3.new((data.index % 4 - 1.5) * data.step, 0, 500 - (math.floor(data.index / 4) - 1) * data.step)');
const verify=`assert(game.PlaceId==0, 'Isolated authoring place only')
local H=game:GetService('HttpService')
local data=H:JSONDecode([==[${JSON.stringify(manifest)}]==])
local pack=assert(workspace:FindFirstChild('CreatorCatalogPreview'))
assert(pack:GetAttribute('LocalGeometryPreview') and pack:GetAttribute('PackSlug')==data.slug,'Unexpected owner')
assert(#pack:GetChildren()==12,'Model count')
local count,triangles=0,0
local function xyz(v) return Vector3.new(v[1],v[3],-v[2]) end
for _,asset in data.assets do
 local model=assert(pack:FindFirstChild(asset.id))
 assert(model:IsA('Model') and model:GetAttribute('PreviewOnly'))
 local pivot=model:GetPivot()
 local lo=Vector3.new(math.huge,math.huge,math.huge)
 local hi=-lo
 local roles={}
 for _,part in model:GetChildren() do
  assert(part:IsA('MeshPart') and part.Anchored and not part.CanCollide and not part.CanTouch)
  assert(#part:GetChildren()==0,'Unexpected behavior or child')
  local p=pivot:PointToObjectSpace(part.Position)
  lo=lo:Min(p-part.Size/2); hi=hi:Max(p+part.Size/2)
  count+=1;triangles+=part:GetAttribute('Triangles')
  roles[part.Name]=part
 end
 for _,expected in asset.meshes do
  local role=assert(expected.name:match('__(.+)$'))
  local part=assert(roles[role],'Missing semantic role')
  assert((pivot:PointToObjectSpace(part:GetPivot().Position)-xyz(expected.pivot)).Magnitude<0.002,'Role pivot')
 end
 local a,b=asset.bounds_min,asset.bounds_max
 assert((lo-Vector3.new(a[1],a[3],-b[2])).Magnitude<0.002,'Authored minimum bounds')
 assert((hi-Vector3.new(b[1],b[3],-a[2])).Magnitude<0.002,'Authored maximum bounds')
 assert(lo.Y>=-0.005,'Grounding')
end
assert(triangles==data.total_triangles,'Total triangles')
return H:JSONEncode({status='PASS',slug=data.slug,models=12,meshParts=count,triangles=triangles,scope='Local EditableMesh preview only; persistent native upload is a separate blocked gate'})`;
const flow={name:'catalog-'+manifest.slug+'-local-preview',description:'Local authoring geometry, pivot, anchoring and behavior checks. Does not prove persistent uploaded assets or a paid listing.',studioName:'^(Place1|GildedGrove.*)$',steps:[{type:'call',tool:'execute_luau',args:{datamodel_type:'Edit',code:verify},expectRegex:['"status":"PASS"','"models":12'],label:'Check final exported geometry in local Studio preview'}]};
const flowPath=path.resolve(here,'../../automation/flows/creator-packs',flow.name+'.json');
fs.writeFileSync(flowPath,JSON.stringify(flow,null,2)+'\n');
const client=new McpClient(findStudioMcp(),'catalog-local-visual-qa');
const evidence={at:new Date().toISOString(),studio:id,slug:manifest.slug,status:'WORKING',scope:'Local preview only',results:[]};
const report=path.join(packDir,'evidence/studio-preview.json');
try{
 await client.initialize();
 await selectStudioStrict(client,{studioInstanceId:id,studioName:'^(Place1|GildedGrove.*)$'});
 await waitForDataModels(client,['Edit'],30000);
 const setup=await client.callTool('execute_luau',{datamodel_type:'Edit',code:`assert(game.PlaceId==0)
local old=workspace:FindFirstChild('CreatorCatalogPreview')
if old then assert(old:GetAttribute('LocalGeometryPreview'),'Unexpected owner'); old:Destroy() end
local f=Instance.new('Folder');f.Name='CreatorCatalogPreview';f:SetAttribute('LocalGeometryPreview',true);f:SetAttribute('PackSlug','${manifest.slug}');f.Parent=workspace
local stage=workspace:FindFirstChild('CreatorCatalogStage')
if stage then assert(stage:GetAttribute('LocalGeometryPreview'),'Unexpected stage owner')
else stage=Instance.new('Part');stage.Name='CreatorCatalogStage';stage:SetAttribute('LocalGeometryPreview',true);stage.Parent=workspace end
stage.Anchored=true;stage.CanCollide=false;stage.Size=Vector3.new(40,0.2,32);stage.Position=Vector3.new(0,-0.1,500)
stage.Color=Color3.fromRGB(200,199,186);stage.Material=Enum.Material.SmoothPlastic
return 'PASS'`},35000);
 if(setup.isError||!setup.text.includes('PASS'))throw Error(setup.text);
 for(const asset of manifest.assets){
  const data=JSON.parse(fs.readFileSync(path.join(packDir,'studio-geometry',asset.id+'.json')));
  data.step=gate.layoutStep;
  const result=await client.callTool('execute_luau',{datamodel_type:'Edit',code:template.replace('__ASSET_JSON__',()=>JSON.stringify(data))},35000);
  evidence.results.push({id:asset.id,isError:result.isError,text:result.text});
  fs.writeFileSync(report,JSON.stringify(evidence,null,2));
  if(result.isError||!result.text.includes('PASS'))throw Error(result.text);
 }
 evidence.status='PASS';evidence.flow=flowPath;
 fs.writeFileSync(report,JSON.stringify(evidence,null,2)+'\n');
 console.log(JSON.stringify({status:'PASS',slug:manifest.slug,models:12,flow:flowPath}));
}catch(error){evidence.status='FAIL';evidence.error=String(error);fs.writeFileSync(report,JSON.stringify(evidence,null,2)+'\n');throw error;
}finally{client.close();}
