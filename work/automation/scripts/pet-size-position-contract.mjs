import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
const root=path.resolve(import.meta.dirname,'../../..');
const relative='work/punch-wall-rpg/src/client/PunchWallClient.client.lua';
const narrowAt=process.argv.indexOf('--narrow-baseline'),narrowBaseline=narrowAt<0?null:process.argv[narrowAt+1]||'39d3c40';
const projectionAt=process.argv.indexOf('--projection-baseline'),projectionBaseline=projectionAt<0?null:process.argv[projectionAt+1]||'521711b';
const at=process.argv.indexOf('--baseline'),baseline=narrowBaseline||projectionBaseline||(at<0?null:process.argv[at+1]||'2ddecc6');
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
V.__index=function(a,k)if k=='Magnitude'then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z)elseif k=='Dot'then return function(a,b)return a.X*b.X+a.Y*b.Y+a.Z*b.Z end end end
local F={} local function frame(x,y,z,roll)return setmetatable({Position=Vector3.new(x,y,z),roll=roll or 0},F)end
F.__add=function(a,b)return frame(a.Position.X+b.X,a.Position.Y+b.Y,a.Position.Z+b.Z,a.roll)end
F.__mul=function(a,b)return a end
F.__index={PointToWorldSpace=function(a,v)local c,s=math.cos(a.roll),math.sin(a.roll)return a.Position+Vector3.new(v.X*c-v.Y*s,v.X*s+v.Y*c,v.Z)end,
 Lerp=function(a,b,t)return frame(a.Position.X+(b.Position.X-a.Position.X)*t,a.Position.Y+(b.Position.Y-a.Position.Y)*t,a.Position.Z+(b.Position.Z-a.Position.Z)*t,a.roll+(b.roll-a.roll)*t)end,
 Inverse=function(a)return a end}
local camera={ViewportSize={X=1277,Y=780},FieldOfView=70,CFrame={Position=Vector3.new(0,0,0),LookVector=Vector3.new(0,0,1),RightVector=Vector3.new(1,0,0),UpVector=Vector3.new(0,1,0)}}
function camera:WorldToViewportPoint(p)local f=(self.projectionHeight or self.ViewportSize.Y)/(2*math.tan(math.rad(self.FieldOfView/2)))return Vector3.new(self.ViewportSize.X/2+p.X*f/p.Z,self.ViewportSize.Y/2-p.Y*f/p.Z,p.Z)end
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
local function publish(cf,size,forbidden)
 local formationRects=forbidden
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
camera.NearPlaneZ=-.5 local near=frame(0,0,.3)
same,ok=companionRuntime.KeepBoundsInSafeFrame(near,companionRuntime.BoundsCorners(Vector3.new(.02,.02,.02)))
check(same==near and ok==false,'positive_depth_inside_hardware_near_plane_cannot_claim_safe_fit')
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
if(!baseline||narrowBaseline){
fixtures.narrowFormation=`${vector}
local function overlap(a,b)
 local area=math.max(0,math.min(a.maxX,b.maxX)-math.max(a.minX,b.minX))*math.max(0,math.min(a.maxY,b.maxY)-math.max(a.minY,b.minY))
 return area/math.max(1,math.min((a.maxX-a.minX)*(a.maxY-a.minY),(b.maxX-b.minX)*(b.maxY-b.minY)))
end
local petSize=Vector3.new(1.8,1.1,.75)
camera.ViewportSize={X=637,Y=654}
local avatar=rect(frame(0,-.5,7),Vector3.new(4.3,5,1))
local original=frame(-3.1,0,5.6)
local independentlyClamped=companionRuntime.KeepBoundsInSafeFrame(original,companionRuntime.BoundsCorners(petSize))
check(overlap(rect(independentlyClamped,petSize),avatar)>.08,'control_independent_safe_frame_pushes_pet_onto_avatar')
local out,state=publish(original,petSize,{avatar})
check(state.safeFrameValid and safe(rect(out,petSize))and overlap(rect(out,petSize),avatar)<=.08,'narrow_layout_preserves_safe_frame_and_clears_actual_avatar')
check(out.Position.Z==original.Position.Z and out.roll==original.roll and state.boundsSize==petSize,'narrow_layout_preserves_world_size_depth_rotation')
for _,viewport in ipairs({{637,654},{402,874},{874,402},{1277,780}})do
 camera.ViewportSize={X=viewport[1],Y=viewport[2]}
 for _,distance in ipairs(viewport[1]==402 and {12,18}or {6,12,18})do
  local avatar=rect(frame(0,-.5,distance+1),Vector3.new(4.3,5,1))
  for step=0,15 do
   local blocked={avatar}local positions={}
   for i=1,3 do
    local bob=math.sin(step*.4+i)*.2 local roll=math.sin(step*.6+i)*.08
    local pose=frame(i==2 and 3.1 or -3.1,i==3 and 3+bob or bob,distance-.4,roll)
    local fitted,s=publish(pose,petSize,blocked)local r=rect(fitted,petSize)
    check(s.safeFrameValid and safe(r),'joint_layout_all_eight_corners_fit_aspect_distance_motion_matrix'..viewport[1]..':'..distance..':'..step..':'..i)
    for _,b in ipairs(blocked)do check(overlap(r,b)<=.08,'joint_layout_preserves_avatar_and_pair_overlap_gate')end
    check(fitted.Position.Z==pose.Position.Z and fitted.roll==pose.roll and s.boundsSize==petSize,'joint_layout_does_not_shrink_rotate_or_change_depth')
    for _,p in ipairs(positions)do check((fitted.Position-p).Magnitude>=1.45,'joint_layout_preserves_world_separation')end
    r.worldPosition=fitted.Position r.minimumCenterDistance=1.45 table.insert(positions,fitted.Position)table.insert(blocked,r)
   end
  end
 end
end
camera.ViewportSize={X=402,Y=874}
local tallAvatar=rect(frame(0,-.5,7),Vector3.new(4.3,5,1))
local first,firstState=publish(frame(-3.1,0,5.6),petSize,{tallAvatar})
local second,secondState=publish(frame(3.1,0,5.6),petSize,{tallAvatar,rect(first,petSize)})
check(firstState.safeFrameValid and not secondState.safeFrameValid,'tall_impossible_joint_region_is_not_falsely_marked_safe')
camera.ViewportSize={X=637,Y=654}
local untouched=frame(0,0,6)local blocked={{minX=0,minY=0,maxX=637,maxY=654}}
out,state=publish(untouched,petSize,blocked)
check(not state.safeFrameValid and (out.Position-untouched.Position).Magnitude==0 and state.boundsSize==petSize,'impossible_joint_fit_is_reported_without_camera_depth_or_size_cheat')
print('PASS '..n)
`;
}
if(!baseline||projectionBaseline){
 fixtures.croppedProjection=`${vector}
camera.ViewportSize={X=390,Y=750}camera.projectionHeight=844 camera.FieldOfView=70
local original=frame(.15,0,2.88)local size=Vector3.new(1.8,.054,.054)
local out,state=publish(original,size)
check(state.safeFrameValid and safe(rect(out,size)),'cropped_projection_keeps_both_opposite_edges_inside_original_inset')
check(out.Position.Z==original.Position.Z and state.boundsSize==size,'cropped_projection_preserves_depth_and_readable_geometry')
local r=rect(out,size)check(r.maxX<=390-4.4+.00001 and r.minX>=4.4-.00001,'cropped_projection_retains_extra_half_pixel_reserve')
local normal=frame(.15,0,3.328)local normalSize=Vector3.new(1.8,1.1,.95)local fitted,normalState=publish(normal,normalSize)
check(normalState.safeFrameValid and safe(rect(fitted,normalSize)),'ordinary_pet_height_and_depth_fit_cropped_projection')
camera.projectionHeight=1200
out,state=publish(original,size)check(state.safeFrameValid==false and (out.Position-original.Position).Magnitude<.00001 and state.boundsSize==size,'cropped_impossible_box_is_not_shrunk_or_marked_safe')
print('PASS '..n)
`;
}
if(!baseline){
 const flow=JSON.parse(fs.readFileSync(path.join(root,'work/automation/flows/pet-size-position-qc.json')));
 const separationFlow=flow.steps.find(s=>s.saveAs==='premiumScreenSeparation');
 assert.ok(separationFlow.expectRegex.some(p=>p.includes('contractValid')),'separation requires unique top-level aggregate');
 for(const suffix of ['Narrow','Landscape']){
  const actual=flow.steps.find(s=>s.saveAs==='actual'+suffix+'PetViewport');assert.ok(actual?.args.code.includes('math.abs(v.Y-'),'exact actual custom-desktop viewport gate');
  for(const key of ['premiumCameraMatrix','premiumScreenSeparation','premiumSafeFrame'])assert.ok(flow.steps.some(s=>s.saveAs===key+suffix),'explicit device phase '+key+suffix);
 }
 fixtures.separationOracle=`${vector}
F.__index.LookVector=Vector3.new(0,0,1)
local CFrame={new=function(p)return frame(p.X,p.Y,p.Z)end,lookAt=function(p)return frame(p.X,p.Y,p.Z)end}
local Enum={CameraType={Scriptable='Scriptable'}}camera.NearPlaneZ=-.5
local root={Position=Vector3.new(0,0,0),CFrame={LookVector=Vector3.new(0,0,-1)}}
local mode='clear'local sample=0 local phase=0 local waits=0
local character={FindFirstChild=function()return root end,GetBoundingBox=function()return frame(0,0,8),Vector3.new(mode=='avatar'and 20 or 3,5,1)end}
local models={}
for i=1,3 do
 local model={IsA=function()return true end,GetAttribute=function(_,key)return key=='FormationPolicy'and 'BoundsAwarePremiumFormationV2'or 'Known Pet'end}
 function model:GetBoundingBox()
  local pose=frame(i==2 and 3 or -3,i==3 and 3 or 0,8)local size=Vector3.new(1.4,1.1,.5)
  if i==2 and (mode=='pair'or mode=='transient'and sample==2 or mode=='firstDistance'and phase%3==1 and sample==2)then pose=frame(-3,0,10)end
  if mode=='world'then size=Vector3.new(.1,.1,.1)if i==1 then pose=frame(-4,0,8)elseif i==2 then pose=frame(-2.56,0,8)end end
  if mode=='near'then pose=frame(0,0,.3)end
  return pose,size
 end table.insert(models,model)
end
local folder={GetChildren=function()return models end}function workspace:FindFirstChild()return folder end
local game={Players={LocalPlayer={Name='Player',Character=character,PlayerGui={PunchWallHUD={GetAttribute=function()return 'BoundsAwarePremiumFormationV2'end}}}},GetService=function()return {JSONEncode=function(_,v)return v end}end}
local task={wait=function(dt)
 waits+=1 if dt==1 then sample=0 phase+=1 else sample+=1 end
 if mode=='camera'and sample==2 then camera.CFrame=camera.CFrame+Vector3.new(1,0,0)end
 if mode=='focus'and sample==2 then camera.Focus=camera.Focus+Vector3.new(0,1,0)end
 if mode=='type'and sample==2 then camera.CameraType='Custom'end
 if mode=='angle'and sample==2 then local changed=camera.CFrame+Vector3.new(0,0,0)changed.LookVector=Vector3.new(math.sin(math.rad(1)),0,math.cos(math.rad(1)))camera.CFrame=changed end
end}
local function execute()
${separationFlow.args.code}
end
local r=execute()check(r.contractValid and r.valid and waits==63,'actual_separation_flow_accepts_complete_three_distance_bob_window')
for _,m in ipairs({'avatar','pair','world','transient','near','camera','focus','type','angle'})do
 mode=m r=execute()check(not r.contractValid and not r.valid,m..'_cannot_pass_actual_separation_flow')
 check(#r.failures==1 and r.failures[1].avatarRect and #r.failures[1].pets==3 and r.failures[1].camera,m..'_retains_bounded_actual_rectangle_diagnostics')
 local c=r.failures[1].camera
 if m=='camera'then check(c.positionDelta==1 and c.focusDelta==0 and c.angleDegrees==0 and c.scriptable,'translation_diagnostic_identifies_failed_camera_gate')end
 if m=='focus'then check(c.positionDelta==0 and c.focusDelta==1 and c.angleDegrees==0 and c.scriptable,'focus_diagnostic_identifies_failed_camera_gate')end
 if m=='type'then check(not c.scriptable and c.cameraType=='Custom','type_diagnostic_identifies_failed_camera_gate')end
 if m=='angle'then check(c.angleDegrees>.99 and c.angleDegrees<1.01 and c.lookDot<.999999 and c.scriptable,'angle_diagnostic_identifies_failed_camera_gate')end
end
mode='firstDistance'r=execute()check(not r.contractValid and not r.matrix['6'].valid and r.matrix['12'].valid and r.matrix['18'].valid,'later_distances_cannot_erase_earlier_separation_failure')
mode='clear'camera.ViewportSize={X=1,Y=1}r=execute()check(not r.contractValid,'uninitialized_viewport_cannot_pass_separation')
print('PASS '..n)
`;
 const formationSetup=block('\tlocal formationRects = {}','\n\tfor index, state in ipairs(companionModels) do');
 fixtures.formationWiring=`${vector}
local queried=0 local size=Vector3.new(4,5,1)
local character={GetBoundingBox=function()queried+=1 return frame(0,0,7),size end}
local companionModels={{model={Parent=true,PrimaryPart=true},updateAccumulator=0},{model={Parent=true,PrimaryPart=true},updateAccumulator=0},{model={Parent=true,PrimaryPart=true},updateAccumulator=0}}
local updateInterval=.05 local deltaTime=.01
local function execute()
${formationSetup}
return formationRects
end
local r=execute()check(queried==0 and #r==0,'no_bounds_query_without_a_due_companion_update')
deltaTime=.05 r=execute()check(queried==1 and #r==1,'one_actual_avatar_bounds_query_for_three_companions')
local corners=companionRuntime.avatarBoundsCorners
r=execute()check(queried==2 and companionRuntime.avatarBoundsCorners==corners,'unchanged_avatar_size_reuses_cached_eight_corners')
size=Vector3.new(5,6,1)r=execute()check(companionRuntime.avatarBoundsCorners~=corners and #companionRuntime.avatarBoundsCorners==8,'actual_growth_invalidates_avatar_corner_cache')
print('PASS '..n)
`;
 const actualFlow=JSON.parse(fs.readFileSync(path.join(root,'work/automation/flows/pet-size-position-qc.json'))).steps.find(s=>s.saveAs==='premiumSafeFrame');
 assert.ok(actualFlow.expectRegex.some(p=>p.includes('contractValid')),'unique top-level all-distances gate');
 fixtures.frameOracle=`${vector}
local mode='clear'local sample=0 local waits=0 local distanceIndex=0
local CFrame={new=function(p)return frame(p.X,p.Y,p.Z)end,lookAt=function(p)return frame(p.X,p.Y,p.Z)end}
local Enum={CameraType={Scriptable='Scriptable'}}
local root={Position=Vector3.new(0,0,0),CFrame={LookVector=Vector3.new(0,0,-1)}}
local model={IsA=function()return true end,GetAttribute=function()return 'Known Pet'end,GetBoundingBox=function()return {PointToWorldSpace=function(_,p)return p end},Vector3.new(2,2,2)end}
local folder={GetChildren=function()return {model,model,model}end}
function workspace:FindFirstChild()return folder end
local game={Players={LocalPlayer={Name='Player',Character={FindFirstChild=function()return root end}}},GetService=function()return {JSONEncode=function(_,v)return v end}end}
function camera:WorldToViewportPoint(p)
 local y=p.Y>0 and 300 or 80 local z=5
 if (mode=='edge'or(mode=='first_distance_edge'and distanceIndex%3==1))and sample==2 and p.Y>0 then y=1 end
 if mode=='near'and p.Z>0 then z=-1 end
 return Vector3.new(p.X>0 and 1200 or 80,y,z)
end
local task={wait=function(dt)waits+=1 if dt==1 then sample=0 distanceIndex+=1 else sample+=1 end if mode=='camera'and sample==2 then camera.CFrame=camera.CFrame+Vector3.new(1,0,0)end end}
local function execute()
${actualFlow.args.code}
end
local result=execute()check(result.contractValid and result.valid and result.safe,'exact_flow_accepts_all_eight_clear_corners')
check(waits==63 and result.matrix['6'].samples==20 and result.matrix['12'].samples==20 and result.matrix['18'].samples==20,'exact_flow_samples_full_bob_window_at_all_three_distances')
mode='edge'result=execute()check(not result.contractValid and not result.valid and result.safe==false and result.failures[1].minY==1,'exact_flow_rejects_transient_one_pixel_top_edge')
mode='first_distance_edge'result=execute()check(result.safe==false and not result.contractValid and not result.valid and result.matrix['6'].valid==false and result.matrix['12'].valid and result.matrix['18'].valid,'exact_flow_rejects_failed_distance_even_when_later_distances_pass')
mode='near'result=execute()check(not result.contractValid and not result.valid and result.safe==false and result.failures[1].front==4,'exact_flow_rejects_partially_behind_camera_bounds')
mode='camera'result=execute()check(not result.contractValid and not result.valid and result.safe==false,'exact_flow_rejects_camera_motion_used_to_fake_fit')
mode='clear'camera.ViewportSize={X=1,Y=1}result=execute()check(not result.contractValid and not result.valid and result.safe==false,'exact_flow_rejects_uninitialized_viewport')
print('PASS '..n)
`;
}
const temp=fs.mkdtempSync(path.join(os.tmpdir(),'smash-pet-contract-')),files=[],results={},mutations=[];
let compiledPrograms=0;
function run(name,text){const file=path.join(temp,`${name}.luau`);files.push(file);fs.writeFileSync(file,text);const compiled=spawnSync(compiler,['--null',file],{encoding:'utf8',timeout:15000});assert.equal(compiled.status,0,name+': '+compiled.stderr);compiledPrograms++;const r=spawnSync(luau,[file],{encoding:'utf8',timeout:15000});return {status:r.status,output:(r.stdout||'')+(r.stderr||'')};}
try{
 for(const [name,text]of Object.entries(fixtures)){if(projectionBaseline&&name!=='croppedProjection'||narrowBaseline&&name!=='narrowFormation')continue;const r=run(name,text);if(baseline){const expected=narrowBaseline?'narrow_layout_preserves_safe_frame_and_clears_actual_avatar':projectionBaseline?'cropped_projection_keeps_both_opposite_edges_inside_original_inset':name==='safeFrame'?'all_eight_corners_publish_inside_original_one_percent_inset':'hand_growth_retains_actual_companion_instances';assert.ok(r.status!==0&&r.output.includes(expected),r.output);results[name]={reproduced:expected};}else{assert.equal(r.status,0,r.output);results[name]={passed:Number(r.output.match(/PASS (\d+)/)?.[1])};}}
 if(!baseline){
  const controls=[['skip_actual_safe_publication','safeFrame',t=>t.replace('state.currentBoundsCFrame = safeBounds','state.currentBoundsCFrame = state.currentBoundsCFrame'),'all_eight_corners_publish_inside_original_one_percent_inset'],['remove_safe_inset','safeFrame',t=>t.replace('math.min(viewport.X, viewport.Y) * 0.01 + 0.5','0'),'all_eight_corners_publish_inside_original_one_percent_inset'],['rebuild_pets_on_hand_size','petLifetime',t=>t.replace('if petsCurrent then return end','if false then return end'),'hand_growth_retains_actual_companion_instances'],['ignore_template_replacement','petLifetime',t=>t.replace('and companionRuntime.petSources[index] == petSources[index]','and true'),'template_instance_replacement_invalidates_pet_cache_on_refresh'],['ignore_companion_lifetime','petLifetime',t=>t.replace('state.model.Parent == companionsFolder','true'),'detached_companion_invalidates_cache_on_refresh']];
  for(const [name,fixture,mutate,expected]of controls){const altered=mutate(fixtures[fixture]);assert.notEqual(altered,fixtures[fixture],name);const r=run(name,altered);assert.ok(r.status!==0&&r.output.includes(expected),name+': '+r.output);mutations.push(name);}
  for(const [name,fixture,from,to,expected]of [
   ['omit_publication_blockers','narrowFormation','state.safeFrameCorners, formationRects','state.safeFrameCorners','narrow_layout_preserves_safe_frame_and_clears_actual_avatar'],
   ['ignore_pair_world_separation','narrowFormation','if rect.minimumCenterDistance and rect.worldPosition then','if false then','joint_layout_preserves_world_separation'],
   ['fabricate_impossible_fit','narrowFormation','if bestDistance == math.huge then return boundsCFrame, false, 0 end','if bestDistance == math.huge then return boundsCFrame, true, 0 end','tall_impossible_joint_region_is_not_falsely_marked_safe'],
   ['query_avatar_between_lod_updates','formationWiring','if formationNeedsUpdate then','if true then','no_bounds_query_without_a_due_companion_update'],
   ['retain_stale_avatar_growth_corners','formationWiring','companionRuntime.avatarBoundsSize ~= avatarSize','companionRuntime.avatarBoundsSize == nil','actual_growth_invalidates_avatar_corner_cache'],
   ['allow_avatar_overlap','separationOracle','avatarOverlap<=.08','true','avatar_cannot_pass_actual_separation_flow'],
   ['allow_pair_overlap','separationOracle','pairOverlap<=.08','true','pair_cannot_pass_actual_separation_flow'],
   ['allow_world_intersection','separationOracle','worldPair>=1.45','true','world_cannot_pass_actual_separation_flow'],
   ['check_only_final_separation_distance','separationOracle','allValid=allValid and valid','allValid=valid','later_distances_cannot_erase_earlier_separation_failure'],
   ['allow_changed_focus','separationOracle','focusDelta<.001','true','focus_cannot_pass_actual_separation_flow'],
   ['allow_changed_look_direction','separationOracle','lookDot>.999999','true','angle_cannot_pass_actual_separation_flow'],
   ['allow_changed_camera_owner','separationOracle','cam.CameraType==Enum.CameraType.Scriptable and positionDelta','true and positionDelta','type_cannot_pass_actual_separation_flow'],
   ['unbound_first_camera_failure','separationOracle','not sampleValid and #failures<1','not sampleValid and #failures<6','avatar_retains_bounded_actual_rectangle_diagnostics'],
  ]){
   const altered=fixtures[fixture].replace(from,to);assert.notEqual(altered,fixtures[fixture],name);const r=run(name,altered);assert.ok(r.status!==0&&r.output.includes(expected),name+': '+r.output);mutations.push(name);
  }
  for(const [name,from,to,expected]of [['only_last_distance_aggregate','allValid=allValid and valid','allValid=valid','exact_flow_rejects_failed_distance_even_when_later_distances_pass'],['omit_safe_aggregate','safe=allValid,','', 'exact_flow_accepts_all_eight_clear_corners'],['fabricate_safe_aggregate','safe=allValid','safe=true','exact_flow_rejects_transient_one_pixel_top_edge'],['allow_partial_front','front==8 and minX','front>0 and minX','exact_flow_rejects_partially_behind_camera_bounds'],['allow_top_edge','minY>=inset','minY>=0','exact_flow_rejects_transient_one_pixel_top_edge'],['skip_motion_window','for sample=1,20 do','for sample=1,1 do','exact_flow_samples_full_bob_window_at_all_three_distances']]){
   const altered=fixtures.frameOracle.replace(from,to);assert.notEqual(altered,fixtures.frameOracle,name);const r=run(name,altered);assert.ok(r.status!==0&&r.output.includes(expected),name+': '+r.output);mutations.push(name);
  }
  const wrongProjection=fixtures.croppedProjection.replace('local worldPerPixelX = point.Z / pixelsAtUnitDepthX','local worldPerPixelX = 2 * math.tan(math.rad(camera.FieldOfView * 0.5)) * point.Z / viewport.Y');
  assert.notEqual(wrongProjection,fixtures.croppedProjection);const wrongResult=run('assume_safe_height_equals_projection_height',wrongProjection);assert.ok(wrongResult.status!==0&&wrongResult.output.includes('cropped_projection_keeps_both_opposite_edges_inside_original_inset'),wrongResult.output);mutations.push('assume_safe_height_equals_projection_height');
  const wrongNear=fixtures.safeFrame.replace('if point.Z <= nearDepth then','if point.Z <= 0.05 then');assert.notEqual(wrongNear,fixtures.safeFrame);const wrongNearResult=run('ignore_hardware_near_plane',wrongNear);assert.ok(wrongNearResult.status!==0&&wrongNearResult.output.includes('positive_depth_inside_hardware_near_plane_cannot_claim_safe_fit'),wrongNearResult.output);mutations.push('ignore_hardware_near_plane');
  for(const [name,code]of [['client',source],...['pet-size-position-qc','power-avatar-growth'].flatMap(name=>{const f=JSON.parse(fs.readFileSync(path.join(root,'work/automation/flows',name+'.json')));return [...f.steps,...(f.cleanup||[])].flatMap((s,i)=>s.args?.code?[[`${name}-${i}`,s.args.code]]:[]);})]){const file=path.join(temp,name+'.luau');files.push(file);fs.writeFileSync(file,code);const r=spawnSync(compiler,['--null',file],{encoding:'utf8'});assert.equal(r.status,0,r.stderr);}
 }
 console.log(JSON.stringify({ok:true,source:baseline||'current',results,mutations,compiledPrograms},null,2));
}finally{for(const f of files)fs.unlinkSync(f);fs.rmdirSync(temp);}
