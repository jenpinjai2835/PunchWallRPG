import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {McpClient, findStudioMcp, selectStudioStrict, waitForDataModels, sleep} from './studio_mcp_client.mjs';
import {LUA as PROFILE, assertLiveBinding} from './studio-frame-profile.mjs';
import {LUA as CAPTURE} from './studio-final-visual-capture.mjs';

const filename = fileURLToPath(import.meta.url);
const root = path.resolve(path.dirname(filename), '../../..');
const sha = value => crypto.createHash('sha256').update(value).digest('hex');
const specs = [['GameConfig','shared/GameConfig.lua'],['PolishConfig','shared/PolishConfig.lua'],
  ['ForestVisualBuilder','shared/ForestVisualBuilder.lua'],['FistVisualBuilder','shared/FistVisualBuilder.lua'],
  ['InventoryViewModel','shared/InventoryViewModel.lua'],['ProfilePersistence','server/ProfilePersistence.lua'],
  ['PunchWallBootstrap','server/PunchWallBootstrap.server.lua'],['InventoryUI','client/InventoryUI.lua'],['PunchWallClient','client/PunchWallClient.client.lua']];
const dependencies = ['studio-premium-pet-profile.mjs','studio-frame-profile.mjs','studio-final-visual-capture.mjs',
  'verify-studio-source.mjs','studio_mcp_client.mjs'].map(name => 'work/automation/scripts/' + name);
const petNames = ['Crimson Phoenix','Storm Wyvern','Celestial Guardian'];
const namesLua = '{' + petNames.map(name => JSON.stringify(name)).join(',') + '}';
const quote = value => { let equal='='; while(String(value).includes(']'+equal+']')) equal+='='; return `string.sub([${equal}[!${value}]${equal}],2)`; };
const patternFor = value => '^' + value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + '$';
const readDeviceState = `local function readDeviceState()
 local ok,id=pcall(function()return S:GetDeviceAsync()end)
 if not ok then assert(string.find(tostring(id),'no device is active',1,true),'Unrecognized device-state failure: '..tostring(id)) end
 if not ok or id==nil or id=='default' then return {ok=true,id='default',active=false,state='cleared'} end
 assert(type(id)=='string' and #id>0,'Invalid active device identity')
 return {ok=true,id=id,active=true,state='configured',orientation=S:GetOrientationAsync().Name,scaling=S:GetScalingModeAsync().Name}
end`;

export function assertAbsentPlayModel(probe) {
  // An existing but still-loading execution bridge is not proof of absent Play.
  assert(probe.isError && /datamodel.*not available|not available.*datamodel|available datamodel|no .*datamodel/i.test(probe.text),
    'Existing/unverified Play session; refuse to start or stop it');
}

export function parseArgs(args) {
  const options = {};
  for (let i=0;i<args.length;i+=2) {
    const key=args[i]?.slice(2);
    assert(args[i]?.startsWith('--') && ['studio-id','studio-name','evidence-leaf'].includes(key) && !options[key], 'Unknown/duplicate option');
    assert(args[i+1] && !args[i+1].startsWith('--'), 'Missing explicit option value'); options[key]=args[i+1];
  }
  for(const key of ['studio-id','studio-name','evidence-leaf']) assert(options[key], 'Explicit --'+key+' required');
  assert(/^[a-zA-Z0-9_-]+$/.test(options['studio-id']), 'Invalid Studio id');
  assert(/^PunchWallRPG(?:Playable_v1_final(?:_validation)?|_ManualPlaytest_[0-9]{8}(?:_[A-Za-z0-9]+)?)\.rbxlx$/.test(options['studio-name']), 'Exact local project place name required');
  assert(/^smash-[a-z0-9-]+$/.test(options['evidence-leaf']), 'New smash-* evidence leaf required');
  options.output=path.join(root,'work/docs/evidence',options['evidence-leaf']+'.json');
  assert(!fs.existsSync(options.output), 'Existing evidence is immutable; choose another leaf');
  return options;
}

function command(command,args,timeout=120000) {
  const result=spawnSync(command,args,{cwd:root,encoding:'utf8',timeout,maxBuffer:4*1024*1024});
  assert.equal(result.status,0,result.error?.message || result.stderr || result.stdout); return result.stdout.trim();
}
function binding() {
  const sourceRoot=path.join(root,'work/punch-wall-rpg/src');
  const files=fs.readdirSync(sourceRoot,{recursive:true,withFileTypes:true}).filter(d=>d.isFile()&&d.name.endsWith('.lua'))
    .map(d=>path.relative(sourceRoot,path.join(d.parentPath,d.name)).replaceAll('\\','/'));
  assert.deepEqual(files.sort(),specs.map(([,file])=>file).sort(),'Exact local nine-source inventory');
  const sources=Object.fromEntries(specs.map(([name,file])=>{const raw=fs.readFileSync(path.join(sourceRoot,file));const normalized=raw.toString('utf8').replace(/\r\n?/g,'\n');
    return [name,{relative:file,rawSHA256:sha(raw),normalizedSHA256:sha(normalized),normalizedBytes:Buffer.byteLength(normalized)}];}));
  const paths=[...dependencies,'work/automation/flows/pet-size-position-qc.json',...specs.map(([,file])=>'work/punch-wall-rpg/src/'+file)];
  assert.equal(command('git',['status','--porcelain','--untracked-files=no','--',...paths]),'','Relevant tracked inputs must be committed');
  return {kind:'Current source only; no artifact or reopen verification',head:command('git',['rev-parse','HEAD']),sources,
    files:Object.fromEntries(paths.map(file=>[file,sha(fs.readFileSync(path.join(root,file)))]))};
}

export const LUA = {
  seed: PROFILE.guard + `local G=require(game.ReplicatedStorage.GameConfig) local names=${namesLua}
local function exact(raw,expected) local list=H:JSONDecode(raw) assert(type(list)=='table' and #list==#expected,'Seed list count differs')
 for i,name in ipairs(expected)do assert(list[i]==name,'Seed list identity/order differs')end end
local pending=p:GetAttribute('PendingGamePassGrantCount')
assert(p:GetAttribute('GamePassOwnershipReconciled')==true and p:GetAttribute('GamePassOwnershipReconciliationFailed')==false
 and (pending==nil or pending==0),'Seed requires settled entitlements')
for _,name in ipairs(names)do local found=false for _,item in ipairs(G.PremiumPets)do if item.name==name then found=true end end assert(found,'Unknown premium pet')end
for _,name in ipairs(names)do local result=a:Invoke('GrantPremiumPet',name) assert(type(result)=='table' and result.ok==true,'Premium fixture grant failed')end
local snapshot=a:Invoke('Snapshot') assert(snapshot.ok==true,'Premium fixture snapshot failed') local stats=p.RPGStats
for _,key in ipairs({'OwnedPremiumPetsJSON','PetInventoryJSON','EquippedPetsJSON'})do exact(stats[key].Value,names) assert(snapshot[key]==stats[key].Value,'Server snapshot differs')end
assert(snapshot.Power==15 and snapshot.Coins==0 and snapshot.EquippedFist=='Starter Glove','Unexpected reset base profile')
local settings=H:JSONDecode(stats.SettingsJSON.Value) assert(settings.motion==true and settings.uiScale==1,'Normal-motion default scale required')
assert(p:GetAttribute('GamePassOwnershipReconciled')==true and p:GetAttribute('GamePassOwnershipReconciliationFailed')==false
 and (p:GetAttribute('PendingGamePassGrantCount') or 0)==0,'Late entitlement work')
return H:JSONEncode({ok=true,names=names,equipped=H:JSONDecode(snapshot.EquippedPetsJSON),power=snapshot.Power,effectivePower=snapshot.EffectivePower})`,
  deviceBefore: `local S=game:GetService('StudioDeviceSimulatorService') ${readDeviceState} return game.HttpService:JSONEncode(readDeviceState())`,
};

export function deviceCode(name, id) {
  assert(/^Smash Premium Profile [a-f0-9-]+$/.test(name),'Owned preset name required');
  return `local S=game:GetService('StudioDeviceSimulatorService') local H=game:GetService('HttpService') local name=${quote(name)} local id=${id ? quote(id) : 'nil'}
if not id then
 for _,candidate in ipairs(S:GetDeviceListAsync())do assert(S:GetDeviceInfoAsync(candidate).Name~=name,'Owned preset already exists')end
 id=S:CreateDeviceAsync({Name=name,Width=637,Height=654,PixelDensity=96,DeviceForm=Enum.DeviceForm.Desktop})
end
local info=S:GetDeviceInfoAsync(id) assert(info.IsCustom and info.Name==name and info.Width==637 and info.Height==654,'Owned custom preset mismatch')
S:SetDeviceAsync(id) S:SetScalingModeAsync(Enum.DeviceSimulatorScalingMode.FitToWindow) task.wait(.3)
local resolution=S:GetResolutionAsync() assert(S:GetDeviceAsync()==id and resolution.X==637 and resolution.Y==654,'Requested custom device not active')
return H:JSONEncode({ok=true,id=id,name=name,resolution={x=resolution.X,y=resolution.Y},scaling=S:GetScalingModeAsync().Name})`;
}

export function deviceCleanup(name, before) {
  assert(/^Smash Premium Profile [a-f0-9-]+$/.test(name));
  assert(before && typeof before.id==='string' && typeof before.active==='boolean');
  assert(before.active ? before.id!=='default' && /^[A-Za-z]+$/.test(before.orientation) && /^[A-Za-z]+$/.test(before.scaling) : before.id==='default');
  return `local S=game:GetService('StudioDeviceSimulatorService') local H=game:GetService('HttpService')
${readDeviceState}
local previous=${quote(before.id)} local removed=0
${before.active ? `S:SetDeviceAsync(previous)
S:SetOrientationAsync(Enum.ScreenOrientation[${quote(before.orientation)}]) S:SetScalingModeAsync(Enum.DeviceSimulatorScalingMode[${quote(before.scaling)}])`
    : 'S:ClearDeviceAsync()'}
for _,id in ipairs(S:GetDeviceListAsync())do local info=S:GetDeviceInfoAsync(id) if info.Name==${quote(name)} then
 assert(info.IsCustom,'Refuse to remove non-owned built-in preset') S:RemoveDeviceAsync(id) removed+=1 end end
local state=readDeviceState() assert(removed<=1 and state.id==previous and state.active==${before.active},'Owned device cleanup failed')
${before.active ? `assert(state.orientation==${quote(before.orientation)} and state.scaling==${quote(before.scaling)},'Previous device options not restored')` : ''}
state.removed=removed return H:JSONEncode(state)`;
}

// These pure predicates are executed in offline controls as well as the actual native observer.
export const METRIC_HELPERS = `local function validSample(s)
 return s.count==3 and s.childCount==3 and s.identities and s.visible==3 and s.unculled and s.formation and s.safe and s.normalNearMotion
  and s.maxLargest<=1.81 and s.maxScreen<=.18 and s.combined<=.35 and s.minCenterSeparation>=24
  and s.rootOn and s.avatarOverlap<=.08 and s.pairOverlap<=.08 and s.worldPair>=1.45 and s.cameraUnchanged
end
local function summarize(frames,total,dropped,invalid,seconds)
 local out={samples=#frames,totalIntervals=total,sampleCap=7200,droppedSamples=dropped,invalidSamples=invalid,seconds=seconds}
 out.valid=#frames>=30 and dropped==0 and invalid==0 and seconds>=6 and total==#frames
 if #frames>0 then table.sort(frames) local function q(p)return frames[math.clamp(math.ceil(#frames*p),1,#frames)]end
  out.p50MS=q(.5) out.p95MS=q(.95) out.p99MS=q(.99) out.maxMS=frames[#frames] out.over50MS=0 out.over100MS=0
  for _,v in ipairs(frames)do if v>50 then out.over50MS+=1 end if v>100 then out.over100MS+=1 end end
 end return out
end`;

export function observationCode(deviceName, deviceId) {
  assert(typeof deviceName==='string' && typeof deviceId==='string');
  return `local H=game:GetService('HttpService') local R=game:GetService('RunService') local U=game:GetService('UserInputService') local GS=game:GetService('GuiService')
local p=game.Players.LocalPlayer local character=assert(p.Character) local root=assert(character:FindFirstChild('HumanoidRootPart'))
local g=assert(p.PlayerGui:FindFirstChild('PunchWallHUD')) local a=assert(g:FindFirstChild('PunchWallClientAutomation'))
local camera=assert(workspace.CurrentCamera) local folder local names=${namesLua}
local original={cameraType=camera.CameraType,cframe=camera.CFrame,focus=camera.Focus,subject=camera.CameraSubject,fov=camera.FieldOfView}
local connections={} local result local failure local beforeRoot=root.Position
local function xyz(v)return {x=v.X,y=v.Y,z=v.Z}end
local function pose(cf)return {cf:GetComponents()}end
${METRIC_HELPERS}
local function config()
 local S=game:GetService('StudioDeviceSimulatorService') local info=S:GetDeviceInfoAsync(S:GetDeviceAsync()) local resolution=S:GetResolutionAsync()
 assert(S:GetDeviceAsync()==${quote(deviceId)} and info.IsCustom and info.Name==${quote(deviceName)} and info.Width==637 and info.Height==654,'Actual owned device differs')
 assert(resolution.X==637 and resolution.Y==654 and S:GetScalingModeAsync()==Enum.DeviceSimulatorScalingMode.FitToWindow,'Device resolution/scaling changed')
 local v=camera.ViewportSize local safe=GS:GetInsetArea(Enum.ScreenInsets.DeviceSafeInsets) local full=GS:GetInsetArea(Enum.ScreenInsets.None)
 assert(v.X==safe.Width and v.Y==safe.Height and math.abs(v.X-637)<=1 and math.abs(v.Y-654)<=1,'Actual narrow device-safe viewport differs')
 assert(math.abs(full.Width-637)<=1 and math.abs(full.Height-654)<=1,'Full UI rectangle differs')
 return {id=S:GetDeviceAsync(),name=info.Name,resolution={x=resolution.X,y=resolution.Y},viewport={x=v.X,y=v.Y},full={x=full.Width,y=full.Height},scaling=S:GetScalingModeAsync().Name}
end
local function rectFor(cf,size)
 local rect={minX=math.huge,minY=math.huge,maxX=-math.huge,maxY=-math.huge,front=0}
 for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
  local point=camera:WorldToViewportPoint(cf:PointToWorldSpace(Vector3.new(size.X*x*.5,size.Y*y*.5,size.Z*z*.5)))
  if point.Z>math.max(.05,math.abs(camera.NearPlaneZ))then rect.front+=1 end
  rect.minX=math.min(rect.minX,point.X) rect.maxX=math.max(rect.maxX,point.X) rect.minY=math.min(rect.minY,point.Y) rect.maxY=math.max(rect.maxY,point.Y)
 end end end return rect
end
local function overlap(a,b)
 if a.front~=8 or b.front~=8 then return 1 end
 local areaA=math.max((a.maxX-a.minX)*(a.maxY-a.minY),1) local areaB=math.max((b.maxX-b.minX)*(b.maxY-b.minY),1)
 return math.max(0,math.min(a.maxX,b.maxX)-math.max(a.minX,b.minX))*math.max(0,math.min(a.maxY,b.maxY)-math.max(a.minY,b.minY))/math.min(areaA,areaB)
end
local ok,err=xpcall(function()
 assert(R:IsStudio() and a:Invoke('CloseMenus')==true,'Studio closed-menu fixture required')
 local deadline=os.clock()+8 local ready=false
 repeat
  folder=workspace:FindFirstChild(p.Name..' Client Companions')
  local actual=H:JSONDecode(p.RPGStats.EquippedPetsJSON.Value)
  ready=folder~=nil and #folder:GetChildren()==3 and #actual==3
  for i,name in ipairs(names)do ready=ready and actual[i]==name end
  if not ready then task.wait(.1)end
 until ready or os.clock()>=deadline
 assert(ready,'Exact three premium companion seed did not replicate')
 local snapshot=a:Invoke('Snapshot') assert(snapshot.ok and snapshot.motion==true and snapshot.uiScale==1 and not snapshot.menuVisible and not snapshot.shopVisible and not snapshot.inventoryVisible and not snapshot.settingsVisible,'Normal-motion closed-menu profile required')
 local before=config() local desired=CFrame.lookAt(root.Position-root.CFrame.LookVector*6+Vector3.new(0,2.2,0),root.Position+Vector3.new(0,1.5,0))
 local requestedFocus=root.Position+Vector3.new(0,1.5,0)
 camera.CameraType=Enum.CameraType.Scriptable camera.CFrame=desired camera.Focus=CFrame.new(requestedFocus) task.wait(1)
 local observedFocus=camera.Focus.Position local nativePlane=desired.Position+desired.LookVector*20
 local focusPolicy=(observedFocus-requestedFocus).Magnitude<.001 and 'RequestedFocus' or (observedFocus-nativePlane).Magnitude<.001 and 'ObservedStudio20StudPlane' or 'UnexpectedFocus'
 local acceptedFocus=focusPolicy=='ObservedStudio20StudPlane' and nativePlane or requestedFocus
 assert(focusPolicy~='UnexpectedFocus','Unexpected initial native focus plane')
 local frames={} local total,dropped,invalid=0,0,0 local samples,invalidGeometry=0,0 local first,last,firstFailure
 local extrema={maxAvatarOverlap=0,maxPairOverlap=0,minWorldPair=99,maxScreen=0,maxCombined=0,maxLargest=0,minCenterSeparation=99}
 local contextChanges,focusTransitions=0,0 local focusState='unknown' local lastObserved=-math.huge local started=os.clock()
 local function observe()
  local v=camera.ViewportSize local inset=math.min(v.X,v.Y)*.01 local cf,size=character:GetBoundingBox() local avatar=rectFor(cf,size)
  local rootPoint,rootOn=camera:WorldToViewportPoint(root.Position+Vector3.new(0,1.4,0)) local pets={} local found={}
  local s={count=0,childCount=#folder:GetChildren(),identities=true,visible=0,unculled=true,formation=g:GetAttribute('CompanionFormationPolicy')=='BoundsAwarePremiumFormationV2',safe=true,
   normalNearMotion=g:GetAttribute('CompanionLOD')=='Near60' and H:JSONDecode(p.RPGStats.SettingsJSON.Value).motion==true,
   maxLargest=0,maxScreen=0,combined=g:GetAttribute('CompanionCombinedScreenAreaEstimate') or 99,minCenterSeparation=99,rootOn=rootOn==true,
   avatarOverlap=0,pairOverlap=0,worldPair=99,cameraUnchanged=p.Character==character and root.Parent==character and workspace.CurrentCamera==camera and camera.CameraType==Enum.CameraType.Scriptable
    and (camera.CFrame.Position-desired.Position).Magnitude<.001 and camera.CFrame.LookVector:Dot(desired.LookVector)>.999999
    and (camera.Focus.Position-acceptedFocus).Magnitude<.001 and camera.FieldOfView==original.fov and v.X==before.viewport.x and v.Y==before.viewport.y}
  for _,model in ipairs(folder:GetChildren())do if model:IsA('Model')then
   local box,extent=model:GetBoundingBox() local rect=rectFor(box,extent) local point,on=camera:WorldToViewportPoint(box.Position)
   local name=model:GetAttribute('PetDefinitionName') found[name or 'unknown']=(found[name or 'unknown'] or 0)+1 s.count+=1
   if on and point.Z>0 then s.visible+=1 end
   s.safe=s.safe and rect.front==8 and rect.minX>=inset and rect.minY>=inset and rect.maxX<=v.X-inset and rect.maxY<=v.Y-inset
   s.unculled=s.unculled and model:GetAttribute('CompanionBudgetCulled')~=true
   s.formation=s.formation and model:GetAttribute('FormationPolicy')=='BoundsAwarePremiumFormationV2'
   s.maxLargest=math.max(s.maxLargest,extent.X,extent.Y,extent.Z) s.maxScreen=math.max(s.maxScreen,model:GetAttribute('EstimatedScreenArea') or 99)
   s.minCenterSeparation=math.min(s.minCenterSeparation,(Vector2.new(point.X,point.Y)-Vector2.new(rootPoint.X,rootPoint.Y)).Magnitude)
   s.avatarOverlap=math.max(s.avatarOverlap,overlap(rect,avatar))
   table.insert(pets,{name=name,position=box.Position,rect=rect,box=pose(box),size=xyz(extent)})
  end end
  for _,name in ipairs(names)do s.identities=s.identities and found[name]==1 end
  for i=1,#pets do for j=i+1,#pets do s.pairOverlap=math.max(s.pairOverlap,overlap(pets[i].rect,pets[j].rect)) s.worldPair=math.min(s.worldPair,(pets[i].position-pets[j].position).Magnitude)end end
  for _,pet in ipairs(pets)do pet.position=xyz(pet.position)end
  s.valid=validSample(s) s.at=os.clock()-started s.root=xyz(root.Position) s.camera=pose(camera.CFrame) s.pets=pets
  extrema.maxAvatarOverlap=math.max(extrema.maxAvatarOverlap,s.avatarOverlap) extrema.maxPairOverlap=math.max(extrema.maxPairOverlap,s.pairOverlap)
  extrema.minWorldPair=math.min(extrema.minWorldPair,s.worldPair) extrema.maxScreen=math.max(extrema.maxScreen,s.maxScreen)
  extrema.maxCombined=math.max(extrema.maxCombined,s.combined) extrema.maxLargest=math.max(extrema.maxLargest,s.maxLargest)
  extrema.minCenterSeparation=math.min(extrema.minCenterSeparation,s.minCenterSeparation)
  samples+=1 if not s.valid then invalidGeometry+=1 if not firstFailure then firstFailure=s end end
  first=first or s last=s
 end
 table.insert(connections,workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(function()contextChanges+=1 end))
 table.insert(connections,camera:GetPropertyChangedSignal('ViewportSize'):Connect(function()contextChanges+=1 end))
 local function focus(value)if value~=focusState then focusTransitions+=1 focusState=value end end
 table.insert(connections,U.WindowFocused:Connect(function()focus('focused')end))
 table.insert(connections,U.WindowFocusReleased:Connect(function()focus('unfocused')end))
 observe()
 table.insert(connections,R.RenderStepped:Connect(function(dt)
  total+=1 if type(dt)~='number' or dt~=dt or dt<=0 or dt==math.huge then invalid+=1 elseif #frames<7200 then frames[#frames+1]=dt*1000 else dropped+=1 end
  if os.clock()-lastObserved>=.15 then lastObserved=os.clock() local success,problem=pcall(observe)
   if not success then invalidGeometry+=1 if not firstFailure then firstFailure={error=tostring(problem)}end end
  end
 end))
 task.wait(6)
 for _,connection in ipairs(connections)do connection:Disconnect()end connections={}
 local seconds=os.clock()-started observe() local metrics=summarize(frames,total,dropped,invalid,seconds) local after=config()
 result={ok=metrics.valid and invalidGeometry==0 and samples>=30 and contextChanges==0 and focusTransitions==0,
  frames=metrics,geometry={samples=samples,invalidSamples=invalidGeometry,observationIntervalSeconds=.15,extrema=extrema,first=first,last=last,firstFailure=firstFailure},
  configurationBefore=before,configurationAfter=after,focusPolicy=focusPolicy,focusState=focusState,focusTransitions=focusTransitions,contextChanges=contextChanges,
  rootDisplacement=(root.Position-beforeRoot).Magnitude,cameraDistanceAlongRootLook=6,requestedCamera=pose(desired),requestedFocus=xyz(requestedFocus),acceptedFocus=xyz(acceptedFocus),
  packingFrequency={available=false,reason='Production packing attempts/order are local unpublished fields; no source instrumentation was added'}}
end,debug.traceback)
for _,connection in ipairs(connections)do connection:Disconnect()end
local restored,restoreError=pcall(function()
 camera.CameraType=original.cameraType camera.CFrame=original.cframe camera.Focus=original.focus camera.CameraSubject=original.subject camera.FieldOfView=original.fov
 assert(camera.CameraType==original.cameraType and camera.CFrame==original.cframe and camera.Focus==original.focus and camera.CameraSubject==original.subject and camera.FieldOfView==original.fov,'Camera restoration readback failed')
end)
result=result or {ok=false} result.cameraRestored=restored result.connectionsDisconnected=true
if not ok then result.ok=false result.error=tostring(err)end if not restored then result.ok=false result.cleanupError=tostring(restoreError)end
return H:JSONEncode(result)`;
}

export function assertObservation(value) {
  assert.equal(value.ok,true,'Native profile or geometry failed');
  assert.equal(value.cameraRestored,true,'Camera not restored'); assert.equal(value.connectionsDisconnected,true,'Observer not disconnected');
  const f=value.frames; assert(f && f.valid && f.samples>=30 && f.totalIntervals===f.samples && f.droppedSamples===0 && f.invalidSamples===0 && f.seconds>=6,'Incomplete frame evidence');
  for(const key of ['p50MS','p95MS','p99MS','maxMS']) assert(Number.isFinite(f[key])&&f[key]>0,'Invalid distribution');
  assert(f.p50MS<=f.p95MS&&f.p95MS<=f.p99MS&&f.p99MS<=f.maxMS,'Unordered distribution');
  assert(value.geometry?.samples>=30 && value.geometry.invalidSamples===0 && !value.geometry.firstFailure,'Incomplete/failed geometry evidence');
  assert.equal(value.contextChanges,0); assert.equal(value.focusTransitions,0);
  assert.deepEqual(value.configurationBefore,value.configurationAfter,'Device configuration changed');
  assert.equal(value.packingFrequency?.available,false,'Uninstrumented packing frequency must not be fabricated');
}

export async function cleanup(actions) {
  const results=[];
  for(const [name,action]of actions){try{results.push({name,ok:true,result:await action()});}catch(error){results.push({name,ok:false,error:String(error.stack||error)});}}
  return results;
}

async function run(options) {
  const record={ok:false,startedAt:new Date().toISOString(),kind:'Source-bound narrow three-premium-pet native RenderStepped profile',artifactVerified:false,
    limitations:['Studio emulation is not physical-device FPS.','Six native seconds include bounded geometry observer work and any concurrent Studio/MCP scheduling.',
      'At most 7,200 intervals are retained; saturation fails. Geometry is observed approximately every 0.15 seconds, not every render.',
      'Window focus is initially unknown; observed focus transitions invalidate the run.','No FPS pass threshold or per-frame packing count is claimed.']};
  let c,before,previous,playAttempted=false,selected=false,primary;
  const name='Smash Premium Profile '+crypto.randomUUID();
  const call=async(type,code)=>{const value=await c.callTool('execute_luau',{datamodel_type:type,code},35000);assert(!value.isError,value.text);return JSON.parse(value.text);};
  const tool=async(name,args)=>{const value=await c.callTool(name,args,35000);assert(!value.isError,value.text);return value.text;};
  const live=()=>{const result=JSON.parse(command(process.execPath,[path.join(root,'work/automation/scripts/verify-studio-source.mjs'),options['studio-id'],patternFor(options['studio-name'])]));assertLiveBinding(result,options,before.sources);return result;};
  try {
    before=binding(); record.binding=before; record.liveBefore=live();
    c=new McpClient(findStudioMcp(),'smash-premium-pet-profile');await c.initialize();
    record.selectedStudio=await selectStudioStrict(c,{studioInstanceId:options['studio-id'],studioName:patternFor(options['studio-name'])});selected=true;
    await waitForDataModels(c,['Edit'],35000);
    // Edit exists during Play too. Do not take ownership of another running session.
    for(const type of ['Server','Client']) {
      const probe=await c.callTool('execute_luau',{datamodel_type:type,code:'return game.Name'},15000);
      assertAbsentPlayModel(probe);
    }
    const edit=await call('Edit',"assert(not game:GetService('RunService'):IsRunning(),'Profiler must begin in Edit') return game.HttpService:JSONEncode({ok=true})"); assert(edit.ok);
    previous=await call('Edit',LUA.deviceBefore); record.previousDevice=previous;
    record.device=await call('Edit',deviceCode(name));
    playAttempted=true;await tool('start_stop_play',{is_start:true});await waitForDataModels(c,['Server','Client'],35000);await sleep(6500);
    record.clientDevice=await call('Client',deviceCode(name,record.device.id));
    record.entitlementReset=await call('Server',CAPTURE.freshServer);
    record.seed=await call('Server',LUA.seed);assert.equal(record.seed.ok,true);
    await sleep(1200);
    record.observation=await call('Client',observationCode(name,record.device.id)); assertObservation(record.observation);
  } catch(error){primary=error;record.error=String(error.stack||error);}
  finally {
    record.cleanup=await cleanup([
      ['stopOwnedPlay',async()=>{if(!playAttempted)return {skipped:true};await tool('start_stop_play',{is_start:false});await waitForDataModels(c,['Edit'],35000);
        for(const type of ['Server','Client']){const probe=await c.callTool('execute_luau',{datamodel_type:type,code:'return game.Name'},15000);assertAbsentPlayModel(probe);}
        return {ok:true,editAvailable:true,serverAndClientAbsent:true};}],
      ['restoreDeviceAndRemoveOwnedPreset',async()=>{if(!selected||!previous)return {skipped:true};return await call('Edit',deviceCleanup(name,previous));}],
      ['closeMcp',()=>{if(c)c.close();return {ok:true};}],
    ]);
    const clean=record.cleanup.every(item=>item.ok);
    if(before&&clean){try{record.liveAfter=live();assert.deepEqual(binding(),before,'HEAD/source/tool inputs changed');record.bindingUnchanged=true;}catch(error){primary=primary||error;record.postflightError=String(error.stack||error);}}
    record.ok=!primary&&clean&&record.bindingUnchanged===true;record.finishedAt=new Date().toISOString();
    try{fs.mkdirSync(path.dirname(options.output),{recursive:true});fs.writeFileSync(options.output,JSON.stringify(record,null,2),{flag:'wx'});}catch(error){record.ok=false;record.evidenceWriteError=String(error.stack||error);}
    if(!record.ok)process.exitCode=1;
    console.log(JSON.stringify({ok:record.ok,evidence:options.output,artifactVerified:false,error:record.error,postflightError:record.postflightError,evidenceWriteError:record.evidenceWriteError,cleanup:record.cleanup},null,2));
  }
}

export async function selfTest() {
  let checks=0;const check=(condition,label)=>{assert(condition,label);checks++;};const reject=(fn,label)=>{assert.throws(fn,undefined,label);checks++;};
  reject(()=>parseArgs([]),'Explicit target required');reject(()=>parseArgs(['--studio-id','x','--studio-name','other.rbxlx','--evidence-leaf','smash-check']),'Wrong place');
  reject(()=>parseArgs(['--studio-id','x','--studio-name','PunchWallRPGPlayable_v1_final.rbxlx','--evidence-leaf','../escape']),'Traversal');
  assertAbsentPlayModel({isError:true,text:'Client DataModel not available'});checks++;
  for(const probe of [{isError:false,text:'game'}, {isError:true,text:'Target is not reachable (createExecuteLuauBridge_loadCodeAsync, Client)'}, {isError:true,text:'execution failed'}])reject(()=>assertAbsentPlayModel(probe),'Absent Play must be proven');
  const valid={ok:true,cameraRestored:true,connectionsDisconnected:true,frames:{valid:true,samples:360,totalIntervals:360,droppedSamples:0,invalidSamples:0,seconds:6,p50MS:16,p95MS:20,p99MS:25,maxMS:30},
    geometry:{samples:41,invalidSamples:0},contextChanges:0,focusTransitions:0,configurationBefore:{viewport:{x:636,y:654}},configurationAfter:{viewport:{x:636,y:654}},packingFrequency:{available:false}};
  assertObservation(valid);checks++;
  for(const [key,value]of [['ok',false],['cameraRestored',false],['connectionsDisconnected',false],['contextChanges',1],['focusTransitions',1]])reject(()=>assertObservation({...valid,[key]:value}),key);
  for(const [key,value]of [['samples',29],['totalIntervals',361],['droppedSamples',1],['invalidSamples',1],['seconds',5.99],['p95MS',NaN]])reject(()=>assertObservation({...valid,frames:{...valid.frames,[key]:value}}),key);
  reject(()=>assertObservation({...valid,geometry:{samples:40,invalidSamples:1}}),'Failed geometric observation');
  reject(()=>assertObservation({...valid,configurationAfter:{viewport:{x:637,y:654}}}),'Actual viewport drift');
  reject(()=>assertObservation({...valid,packingFrequency:{available:true}}),'Invented counter');
  let reached=0;const cleaned=await cleanup([['first',()=>{throw Error('injected');}],['second',()=>{reached++;}],['third',()=>{reached++;}]]);
  check(!cleaned[0].ok&&reached===2,'Failure cannot bypass remaining cleanup');
  const bins=[process.env.LUAU_COMMAND,...fs.readdirSync(os.tmpdir()).filter(name=>name.startsWith('codex-luau-')).sort().reverse().map(name=>path.join(os.tmpdir(),name,'luau.exe'))];
  const luau=bins.find(file=>file&&spawnSync(file,['--help']).status===0);assert(luau,'Luau CLI required');const compiler=path.join(path.dirname(luau),'luau-compile.exe');
  const directory=fs.mkdtempSync(path.join(os.tmpdir(),'smash-premium-profile-contract-'));let compiled=0;const outputs=[];
  try {
    const snippets=[PROFILE.guard,CAPTURE.freshServer,LUA.seed,LUA.deviceBefore,deviceCode('Smash Premium Profile abc'),deviceCode('Smash Premium Profile abc','owned'),
      deviceCleanup('Smash Premium Profile abc',{id:'default',active:false}),deviceCleanup('Smash Premium Profile abc',{id:'prior',active:true,orientation:'LandscapeLeft',scaling:'FitToWindow'}),observationCode('Smash Premium Profile abc','owned')];
    for(const [i,code]of snippets.entries()){const file=path.join(directory,i+'.luau');fs.writeFileSync(file,code);const result=spawnSync(compiler,['--null',file],{encoding:'utf8'});assert.equal(result.status,0,result.stderr);compiled++;}
    const script=METRIC_HELPERS+`
local checks=0 local function check(v)assert(v)checks+=1 end
local original={count=3,childCount=3,identities=true,visible=3,unculled=true,formation=true,safe=true,normalNearMotion=true,maxLargest=1.81,maxScreen=.18,combined=.35,minCenterSeparation=24,rootOn=true,avatarOverlap=.08,pairOverlap=.08,worldPair=1.45,cameraUnchanged=true}
check(validSample(original))
for _,key in ipairs({'identities','unculled','formation','safe','normalNearMotion','rootOn','cameraUnchanged'})do local value=table.clone(original)value[key]=false check(not validSample(value))end
for key,value in pairs({count=2,childCount=4,visible=2,maxLargest=1.811,maxScreen=.181,combined=.351,minCenterSeparation=23.99,avatarOverlap=.081,pairOverlap=.081,worldPair=1.449})do local wrong=table.clone(original)wrong[key]=value check(not validSample(wrong))end
local frames={}for i=1,60 do frames[i]=i end local m=summarize(frames,60,0,0,6)check(m.valid and m.p50MS==30 and m.p95MS==57 and m.p99MS==60 and m.maxMS==60 and m.over50MS==10 and m.over100MS==0)
check(not summarize(frames,61,1,0,6).valid)check(not summarize(frames,61,0,1,6).valid)check(not summarize(frames,60,0,0,5.99).valid)check(not summarize({},0,0,0,6).valid)
print('PASS '..checks)`;
    const execute=(name,code)=>{const file=path.join(directory,name+'.luau');fs.writeFileSync(file,code);const cr=spawnSync(compiler,['--null',file],{encoding:'utf8'});assert.equal(cr.status,0,cr.stderr);const r=spawnSync(luau,[file],{encoding:'utf8'});return r;};
    const result=execute('metrics',script);assert.equal(result.status,0,result.stderr);outputs.push(result.stdout.trim());
    for(const [from,to]of [['s.safe','true'],['s.pairOverlap<=.08','true'],['s.worldPair>=1.45','true'],['dropped==0','true'],['seconds>=6','true']]){
      let modified=script.replace(from,to);assert.notEqual(modified,script);if(from==='dropped==0')modified=modified.replace('total==#frames','true');
      const r=execute('mutation-'+checks,modified);check(r.status!==0,'Weakened producer predicate detected');
    }
    const seedMock=`
local names=${namesLua} local mutations={} local calls=0
local attrs={ProfileReady=true,ProfilePersistenceState='EphemeralStudio',ProfileWritable=false,GamePassOwnershipReconciled=true,GamePassOwnershipReconciliationFailed=false}
local stats={}for _,key in ipairs({'OwnedPremiumPetsJSON','PetInventoryJSON','EquippedPetsJSON'})do stats[key]={Value={}}end
stats.SettingsJSON={Value={motion=true,uiScale=1}}
local p={RPGStats=stats,GetAttribute=function(_,key)return attrs[key]end}
local worldAttrs={PersistenceMode='EphemeralStudio',PersistenceStudioDefaultEphemeral=true,PersistenceStudioLiveDataOptIn=false}
local world={GetAttribute=function(_,key)return worldAttrs[key]end}
local config={PremiumPets={}}for _,name in ipairs(names)do table.insert(config.PremiumPets,{name=name})end
local require=function()return config end
local automation={Invoke=function(_,action,name)
 if action=='GrantPremiumPet'then calls+=1 if mutations.grantFailed then return {ok=false}end
  for _,key in ipairs({'OwnedPremiumPetsJSON','PetInventoryJSON','EquippedPetsJSON'})do table.insert(stats[key].Value,name)end return {ok=true}
 end
 local result={ok=true,Power=15,Coins=0,EquippedFist='Starter Glove'}for key,stat in pairs(stats)do result[key]=stat.Value end
 if mutations.badSnapshot then result.EquippedPetsJSON={}end
 if mutations.badOrder then local copy=table.clone(stats.EquippedPetsJSON.Value)copy[1],copy[2]=copy[2],copy[1]stats.EquippedPetsJSON.Value=copy result.EquippedPetsJSON=copy end
 return result
end}
local ss={FindFirstChild=function()return automation end,GetAttribute=function()return mutations.liveOptIn end}
local H={JSONDecode=function(_,value)return value end,JSONEncode=function(_,value)return value end}
local services={RunService={IsStudio=function()return true end},HttpService=H,Players={GetPlayers=function()return {p}end},ServerStorage=ss}
local game={ReplicatedStorage={GameConfig={}},GetService=function(_,key)return services[key]end}
local workspace={FindFirstChild=function()return world end}
`;
    let seedChecks=0;
    for(const [setup,pass,expectedCalls]of [['',true,3],['attrs.PendingGamePassGrantCount=1',false,0],['attrs.GamePassOwnershipReconciliationFailed=true',false,0],
      ['attrs.GamePassOwnershipReconciled=false',false,0],['attrs.ProfileWritable=true',false,0],['mutations.liveOptIn=true',false,0],
      ['config.PremiumPets={}',false,0],['mutations.grantFailed=true',false,1],['mutations.badSnapshot=true',false,3],['mutations.badOrder=true',false,3],['stats.SettingsJSON.Value.motion=false',false,3]]) {
      const r=execute('seed-'+seedChecks,seedMock+setup+`\nlocal ok=pcall(function()${LUA.seed}\nend)assert(ok==${pass} and calls==${expectedCalls},'exact seed guard')`);
      assert.equal(r.status,0,r.stderr);seedChecks++;
    }
    outputs.push('PASS '+seedChecks+' exact seed controls');
    const deviceMock=`
local state={id='default',active=false,orientation='LandscapeLeft',scaling='ActualSize',metaReads=0,clears=0,sets=0,removed=0}
local catalog={owned={Name='Smash Premium Profile abc',IsCustom=true},other={Name='Another task device',IsCustom=true}}
local S={}
function S:GetDeviceAsync()if state.unknown then error('unrelated service failure')end if state.throwNoActive and not state.active then error('StudioDeviceSimulatorService: no device is active — call SetDeviceAsync() first')end return state.id end
function S:GetOrientationAsync()state.metaReads+=1 assert(state.active,'no device is active')if state.badOrientation then error('active orientation unavailable')end return {Name=state.orientation}end
function S:GetScalingModeAsync()state.metaReads+=1 assert(state.active,'no device is active')return {Name=state.scaling}end
function S:ClearDeviceAsync()state.clears+=1 if not state.ignoreClear then state.id='default'state.active=false end end
function S:SetDeviceAsync(id)state.sets+=1 state.id=id state.active=true end
function S:SetOrientationAsync(value)assert(state.active)if not state.ignoreOptions then state.orientation=value end end
function S:SetScalingModeAsync(value)assert(state.active)if not state.ignoreOptions then state.scaling=value end end
function S:GetDeviceListAsync()local ids={}for id in pairs(catalog)do table.insert(ids,id)end return ids end
function S:GetDeviceInfoAsync(id)return catalog[id]end
function S:RemoveDeviceAsync(id)assert(id=='owned','must retain unrelated preset')catalog[id]=nil state.removed+=1 end
local Enum={ScreenOrientation={LandscapeLeft='LandscapeLeft'},DeviceSimulatorScalingMode={FitToWindow='FitToWindow',ActualSize='ActualSize'}}
local H={JSONEncode=function(_,value)return value end}
local game={HttpService=H,GetService=function(_,name)return name=='HttpService' and H or S end}
`;
    let deviceChecks=0;
    const verifyDevice=(label,setup,code,pass,predicate='true')=>{
      const r=execute('device-'+deviceChecks,deviceMock+setup+`\nlocal ok,result=pcall(function()${code}\nend)assert(ok==${pass},'${label}')assert(${predicate},'${label} readback')`);
      assert.equal(r.status,0,r.stderr);deviceChecks++;
    };
    for(const setup of ['', 'state.throwNoActive=true', 'state.id=nil'])verifyDevice('cleared no active metadata',setup,LUA.deviceBefore,true,"result.id=='default' and result.active==false and result.state=='cleared' and state.metaReads==0");
    verifyDevice('active metadata preserved',"state.id='prior' state.active=true",LUA.deviceBefore,true,"result.id=='prior' and result.active and result.orientation=='LandscapeLeft' and result.scaling=='ActualSize' and state.metaReads==2");
    verifyDevice('unknown failure rejects','state.unknown=true',LUA.deviceBefore,false,'state.metaReads==0');
    verifyDevice('active option failure rejects',"state.id='prior' state.active=true state.badOrientation=true",LUA.deviceBefore,false);
    const clearedCleanup=deviceCleanup('Smash Premium Profile abc',{id:'default',active:false});
    const activeCleanup=deviceCleanup('Smash Premium Profile abc',{id:'prior',active:true,orientation:'LandscapeLeft',scaling:'FitToWindow'});
    for(const setup of ["state.id='owned' state.active=true",'state.throwNoActive=true'])verifyDevice('restore cleared state',setup,clearedCleanup,true,"not result.active and result.id=='default' and state.clears==1 and state.sets==0 and state.metaReads==0 and state.removed==1 and catalog.other~=nil");
    verifyDevice('restore active options',"state.id='owned' state.active=true state.orientation='Portrait'",activeCleanup,true,"result.active and result.id=='prior' and result.orientation=='LandscapeLeft' and result.scaling=='FitToWindow' and state.clears==0 and state.sets==1 and state.removed==1 and catalog.other~=nil");
    verifyDevice('failed clear rejects',"state.id='owned' state.active=true state.ignoreClear=true",clearedCleanup,false);
    verifyDevice('failed option restore rejects',"state.id='owned' state.active=true state.orientation='Portrait' state.ignoreOptions=true",activeCleanup,false);
    verifyDevice('built-in cannot be deleted','catalog.owned.IsCustom=false',clearedCleanup,false,'state.removed==0 and catalog.other~=nil');
    const unconditional=LUA.deviceBefore.replace('local ok,id=pcall', 'S:GetOrientationAsync() local ok,id=pcall');assert.notEqual(unconditional,LUA.deviceBefore);
    verifyDevice('old unconditional metadata fails', '',unconditional,false,'state.metaReads==1');
    outputs.push('PASS '+deviceChecks+' exact device lifecycle controls (including fail-before)');
  } finally {for(const file of fs.readdirSync(directory))fs.unlinkSync(path.join(directory,file));fs.rmdirSync(directory);}
  return {ok:true,studioUsed:false,checks,compiledSnippets:compiled,executed:outputs,weakeningControls:5};
}

if(process.argv[1]&&path.resolve(process.argv[1])===filename){if(process.argv[2]==='--self-test')console.log(JSON.stringify(await selfTest(),null,2));else await run(parseArgs(process.argv.slice(2)));}
