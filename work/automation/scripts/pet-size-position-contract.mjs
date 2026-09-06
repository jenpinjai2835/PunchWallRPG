import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
const root=path.resolve(import.meta.dirname,'../../..');
const relative='work/punch-wall-rpg/src/client/PunchWallClient.client.lua';
const at=process.argv.indexOf('--baseline'),baseline=at<0?null:process.argv[at+1]||'2ddecc6';
const old=baseline&&spawnSync('git',['show',`${baseline}:${relative}`],{cwd:root,encoding:'utf8'});
if(old)assert.equal(old.status,0,old.stderr);
const source=(old?old.stdout:fs.readFileSync(path.join(root,relative),'utf8')).replace(/\r\n?/g,'\n');
function block(from,to){const a=source.indexOf(from),b=source.indexOf(to,a+from.length);assert.ok(a>=0&&b>a,from);return source.slice(a,b);}
const candidates=[process.env.LUAU_COMMAND,...fs.readdirSync(os.tmpdir()).filter(n=>n.startsWith('codex-luau-')).sort().reverse().map(n=>path.join(os.tmpdir(),n,process.platform==='win32'?'luau.exe':'luau')),'luau'];
const luau=candidates.find(p=>p&&spawnSync(p,['--help']).status===0);assert.ok(luau,'BLOCKED: Luau CLI required');
const compiler=process.env.LUAU_COMPILE_COMMAND||path.join(path.dirname(luau),process.platform==='win32'?'luau-compile.exe':'luau-compile');
const geometry=source.includes('function companionRuntime.BoundsCorners')?block('function companionRuntime.BoundsCorners','function companionRuntime.ApplyVisualScale'):'';
const publication=block('\t\t\t\tlocal distance = (state.currentBoundsCFrame.Position - targetBounds.Position).Magnitude','\n\t\t\t\tstate.motionFrames += 1');
const refresh=block('\nrefreshCharacterVisuals = function()','\n-- Heartbeat drives normal gameplay;');
const vector=`
local n=0 local function check(v,label) assert(v,label) n+=1 end
local Vector3,V={},{}
function Vector3.new(x,y,z)return setmetatable({X=x,Y=y,Z=z},V)end
V.__add=function(a,b)return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z)end
V.__sub=function(a,b)return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end
V.__mul=function(a,b)return Vector3.new(a.X*b,a.Y*b,a.Z*b)end
V.__index=function(a,k)if k=='Magnitude'then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z)end end
local F={} local function frame(x,y,z,roll)return setmetatable({Position=Vector3.new(x,y,z),roll=roll or 0},F)end
F.__add=function(a,b)return frame(a.Position.X+b.X,a.Position.Y+b.Y,a.Position.Z+b.Z,a.roll)end
F.__mul=function(a,b)return a end
F.__index={PointToWorldSpace=function(a,v)local c,s=math.cos(a.roll),math.sin(a.roll)return a.Position+Vector3.new(v.X*c-v.Y*s,v.X*s+v.Y*c,v.Z)end,
 Lerp=function(a,b,t)return frame(a.Position.X+(b.Position.X-a.Position.X)*t,a.Position.Y+(b.Position.Y-a.Position.Y)*t,a.Position.Z+(b.Position.Z-a.Position.Z)*t,a.roll+(b.roll-a.roll)*t)end,
 Inverse=function(a)return a end}
local camera={ViewportSize={X=1277,Y=780},FieldOfView=70,CFrame={RightVector=Vector3.new(1,0,0),UpVector=Vector3.new(0,1,0)}}
function camera:WorldToViewportPoint(p)local f=self.ViewportSize.Y/(2*math.tan(math.rad(self.FieldOfView/2)))return Vector3.new(self.ViewportSize.X/2+p.X*f/p.Z,self.ViewportSize.Y/2-p.Y*f/p.Z,p.Z)end
local workspace={CurrentCamera=camera} local companionRuntime={}
${geometry}
local function rect(cf,size)
 local r={minX=math.huge,minY=math.huge,maxX=-math.huge,maxY=-math.huge,front=0}
 for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
  local p=camera:WorldToViewportPoint(cf:PointToWorldSpace(Vector3.new(size.X*x/2,size.Y*y/2,size.Z*z/2)))
  r.minX=math.min(r.minX,p.X)r.minY=math.min(r.minY,p.Y)r.maxX=math.max(r.maxX,p.X)r.maxY=math.max(r.maxY,p.Y)if p.Z>0 then r.front+=1 end
 end end end return r
end
local function safe(r)local v=camera.ViewportSize local i=math.min(v.X,v.Y)*.01 return r.front==8 and r.minX>=i-.00001 and r.minY>=i-.00001 and r.maxX<=v.X-i+.00001 and r.maxY<=v.Y-i+.00001 end
local function publish(cf,size)
 local state={currentBoundsCFrame=cf,boundsSize=size,pivotToBounds=frame(0,0,0),followResponsiveness=8}
 local targetBounds=cf local effectiveDelta=1/60 local published
 local model={PivotTo=function(_,pose)published=pose end}
 ${publication}
 return published,state
end
`;
const petSetup=`
local n=0 local function check(v,label)assert(v,label)n+=1 end
local companionModels={} local created,cleared,gloves=0,0,0
local companionRuntime={} local visualSignature='' local currentGauntlet
local player={Character={}} local latestStats={EquippedFist='Starter Glove',EquippedHonorItem='None',EquippedPetsJSON={'Forest Pup','Miner Cat','Crystal Fox'}}
local function decodeJSON(v)return v end
local revision=0 local function buildHonorCosmetic()end
local companionsFolder={}
function companionsFolder:ClearAllChildren()cleared+=1 for _,s in ipairs(companionModels)do s.model.Parent=nil end end
local templates={['Forest Pup']={},['Miner Cat']={},['Crystal Fox']={}}
local GameConfig={ParsePetToken=function(v)return v end,PetDefinition=function(v)return {name=v,rarity='Normal'}end}
local function catalogCompanionTemplate(d)return templates[d.name]end
function companionRuntime.CharacterHandSizeSignature()return tostring(revision)end
function companionRuntime.BuildItemMatchedGauntlet()gloves+=1 currentGauntlet={Parent=player.Character}return true end
function companionRuntime.ScheduleVisualRetry()end function companionRuntime.CancelVisualRetry()end
local function buildCompanion(token,index)
 created+=1 local m={Parent=companionsFolder,name=token,identity=created,scale=1,height=1.45,GetAttribute=function()return false end}
 table.insert(companionModels,{model=m})return m
end
local gui={SetAttribute=function()end}local companionMotionVersion='mock'
local refreshCharacterVisuals
${refresh}
`;
const fixtures={
 safeFrame:`${vector}
local size=Vector3.new(1.8,1.58,.45)
local f=780/(2*math.tan(math.rad(35)))local depth=5
local y=(390-1)*(depth-size.Z/2)/f-size.Y/2
local original=frame(-3.1,y,depth)
check(math.abs(rect(original,size).minY-1)<.0001,'control_reproduces_observed_one_pixel_top_edge')
local out,state=publish(original,size)
check(safe(rect(out,size)),'all_eight_corners_publish_inside_original_one_percent_inset')
check(out.Position.Z==original.Position.Z and out.roll==original.roll,'fit_preserves_depth_and_rotation')
check(state.boundsSize==size,'fit_preserves_underlying_readable_size')
check((out.Position-original.Position).Magnitude<.1,'observed_edge_case_uses_small_translation')
for _,viewport in ipairs({{1277,780},{874,402},{402,874}})do camera.ViewportSize={X=viewport[1],Y=viewport[2]}
 for _,fov in ipairs({55,70,90})do camera.FieldOfView=fov
  for _,depth in ipairs({6,12,18})do for step=0,15 do
   local bob=math.sin(step*math.pi/8)*.32 local roll=math.sin(step*.6)*.15
   local pose=frame(-depth*.5,depth*.6+bob,depth,roll)local out=publish(pose,size)
   check(safe(rect(out,size)),'rotated_bobbing_box_fits_aspect_fov_depth_matrix')
  end end
 end
end
camera.ViewportSize={X=1,Y=1}local same,ok=companionRuntime.KeepBoundsInSafeFrame(original,companionRuntime.BoundsCorners(size))
check(same==original and ok==false,'invalid_viewport_cannot_claim_fit')
camera.ViewportSize={X=1277,Y=780}local behind=frame(0,0,-1)
same,ok=companionRuntime.KeepBoundsInSafeFrame(behind,companionRuntime.BoundsCorners(size))check(same==behind and ok==false,'behind_camera_cannot_claim_fit')
local huge=Vector3.new(100,100,1)same,ok=companionRuntime.KeepBoundsInSafeFrame(frame(0,0,2),companionRuntime.BoundsCorners(huge))check(ok==false,'impossible_frame_fit_is_reported_without_shrinking')
print('PASS '..n)
`,
 petLifetime:`${petSetup}
refreshCharacterVisuals()local original={}for i,s in ipairs(companionModels)do original[i]=s.model end
for step=1,10 do revision=step refreshCharacterVisuals()for i,s in ipairs(companionModels)do check(s.model==original[i] and s.model.Parent==companionsFolder,'hand_growth_retains_actual_companion_instances')end end
check(created==3 and gloves==11,'growth_rebuilds_gloves_without_rebuilding_pets')
latestStats.EquippedFist='Titan Gauntlet'refreshCharacterVisuals()check(created==3,'fist_change_retains_unrelated_pets')
latestStats.EquippedHonorItem='Crown'refreshCharacterVisuals()check(created==3,'honor_change_retains_unrelated_pets')
templates['Forest Pup']={}revision+=1 refreshCharacterVisuals()check(created==6,'template_instance_replacement_invalidates_pet_cache_on_refresh')
companionModels[1].model.Parent=nil revision+=1 refreshCharacterVisuals()check(created==9,'detached_companion_invalidates_cache_on_refresh')
latestStats.EquippedPetsJSON={'Miner Cat','Forest Pup'}refreshCharacterVisuals()check(created==11 and #companionModels==2 and companionModels[1].model.name=='Miner Cat','equipped_token_order_invalidates_cache')
player.Character={}refreshCharacterVisuals()check(created==13,'new_character_rebuilds_companions')
latestStats.EquippedPetsJSON={}refreshCharacterVisuals()check(#companionModels==0,'unequipping_last_pet_clears_models')
print('PASS '..n)
`};
if(!baseline){
 const actualFlow=JSON.parse(fs.readFileSync(path.join(root,'work/automation/flows/pet-size-position-qc.json'))).steps.find(s=>s.saveAs==='premiumSafeFrame');
 assert.ok(actualFlow.expectRegex.some(p=>p.includes('contractValid')),'unique top-level all-distances gate');
 fixtures.frameOracle=`${vector}
local mode='clear'local sample=0 local waits=0
local CFrame={new=function(p)return frame(p.X,p.Y,p.Z)end,lookAt=function(p)return frame(p.X,p.Y,p.Z)end}
local Enum={CameraType={Scriptable='Scriptable'}}
local root={Position=Vector3.new(0,0,0),CFrame={LookVector=Vector3.new(0,0,-1)}}
local model={IsA=function()return true end,GetAttribute=function()return 'Known Pet'end,GetBoundingBox=function()return {PointToWorldSpace=function(_,p)return p end},Vector3.new(2,2,2)end}
local folder={GetChildren=function()return {model,model,model}end}
function workspace:FindFirstChild()return folder end
local game={Players={LocalPlayer={Name='Player',Character={FindFirstChild=function()return root end}}},GetService=function()return {JSONEncode=function(_,v)return v end}end}
function camera:WorldToViewportPoint(p)
 local y=p.Y>0 and 300 or 80 local z=5
 if mode=='edge'and sample==2 and p.Y>0 then y=1 end
 if mode=='near'and p.Z>0 then z=-1 end
 return Vector3.new(p.X>0 and 1200 or 80,y,z)
end
local task={wait=function(dt)waits+=1 if dt==1 then sample=0 else sample+=1 end if mode=='camera'and sample==2 then camera.CFrame=camera.CFrame+Vector3.new(1,0,0)end end}
local function execute()
${actualFlow.args.code}
end
local result=execute()check(result.contractValid and result.valid,'exact_flow_accepts_all_eight_clear_corners')
check(waits==63 and result.matrix['6'].samples==20 and result.matrix['12'].samples==20 and result.matrix['18'].samples==20,'exact_flow_samples_full_bob_window_at_all_three_distances')
mode='edge'result=execute()check(not result.contractValid and result.failures[1].minY==1,'exact_flow_rejects_transient_one_pixel_top_edge')
mode='near'result=execute()check(not result.contractValid and result.failures[1].front==4,'exact_flow_rejects_partially_behind_camera_bounds')
mode='camera'result=execute()check(not result.contractValid,'exact_flow_rejects_camera_motion_used_to_fake_fit')
mode='clear'camera.ViewportSize={X=1,Y=1}result=execute()check(not result.contractValid,'exact_flow_rejects_uninitialized_viewport')
print('PASS '..n)
`;
}
const temp=fs.mkdtempSync(path.join(os.tmpdir(),'smash-pet-contract-')),files=[],results={},mutations=[];
function run(name,text){const file=path.join(temp,`${name}.luau`);files.push(file);fs.writeFileSync(file,text);const r=spawnSync(luau,[file],{encoding:'utf8',timeout:15000});return {status:r.status,output:(r.stdout||'')+(r.stderr||'')};}
try{
 for(const [name,text]of Object.entries(fixtures)){const r=run(name,text);if(baseline){const expected=name==='safeFrame'?'all_eight_corners_publish_inside_original_one_percent_inset':'hand_growth_retains_actual_companion_instances';assert.ok(r.status!==0&&r.output.includes(expected),r.output);results[name]={reproduced:expected};}else{assert.equal(r.status,0,r.output);results[name]={passed:Number(r.output.match(/PASS (\d+)/)?.[1])};}}
 if(!baseline){
  const controls=[['skip_actual_safe_publication','safeFrame',t=>t.replace('state.currentBoundsCFrame = safeBounds','state.currentBoundsCFrame = state.currentBoundsCFrame'),'all_eight_corners_publish_inside_original_one_percent_inset'],['remove_safe_inset','safeFrame',t=>t.replace('math.min(viewport.X, viewport.Y) * 0.01 + 0.5','0'),'all_eight_corners_publish_inside_original_one_percent_inset'],['rebuild_pets_on_hand_size','petLifetime',t=>t.replace('if petsCurrent then return end','if false then return end'),'hand_growth_retains_actual_companion_instances'],['ignore_template_replacement','petLifetime',t=>t.replace('and companionRuntime.petSources[index] == petSources[index]','and true'),'template_instance_replacement_invalidates_pet_cache_on_refresh'],['ignore_companion_lifetime','petLifetime',t=>t.replace('state.model.Parent == companionsFolder','true'),'detached_companion_invalidates_cache_on_refresh']];
  for(const [name,fixture,mutate,expected]of controls){const altered=mutate(fixtures[fixture]);assert.notEqual(altered,fixtures[fixture],name);const r=run(name,altered);assert.ok(r.status!==0&&r.output.includes(expected),name+': '+r.output);mutations.push(name);}
  for(const [name,from,to,expected]of [['allow_partial_front','front==8 and minX','front>0 and minX','exact_flow_rejects_partially_behind_camera_bounds'],['allow_top_edge','minY>=inset','minY>=0','exact_flow_rejects_transient_one_pixel_top_edge'],['skip_motion_window','for sample=1,20 do','for sample=1,1 do','exact_flow_samples_full_bob_window_at_all_three_distances']]){
   const altered=fixtures.frameOracle.replace(from,to);assert.notEqual(altered,fixtures.frameOracle,name);const r=run(name,altered);assert.ok(r.status!==0&&r.output.includes(expected),name+': '+r.output);mutations.push(name);
  }
  for(const [name,code]of [['client',source],...['pet-size-position-qc','power-avatar-growth'].flatMap(name=>JSON.parse(fs.readFileSync(path.join(root,'work/automation/flows',name+'.json'))).steps.flatMap((s,i)=>s.args?.code?[[`${name}-${i}`,s.args.code]]:[]))]){const file=path.join(temp,name+'.luau');files.push(file);fs.writeFileSync(file,code);const r=spawnSync(compiler,['--null',file],{encoding:'utf8'});assert.equal(r.status,0,r.stderr);}
 }
 console.log(JSON.stringify({ok:true,source:baseline||'current',results,mutations},null,2));
}finally{for(const f of files)fs.unlinkSync(f);fs.rmdirSync(temp);}
