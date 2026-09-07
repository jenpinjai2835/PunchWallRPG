import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {spawnSync} from 'node:child_process';

const root=path.resolve(import.meta.dirname,'../../..');
const clientPath='work/punch-wall-rpg/src/client/PunchWallClient.client.lua';
const baseline='4adf4fda3e503acdbe20e52316e05c89851a5e62';
const source=fs.readFileSync(path.join(root,clientPath),'utf8').replace(/\r\n?/g,'\n');
const prior=spawnSync('git',['show',`${baseline}:${clientPath}`],{cwd:root,encoding:'utf8',maxBuffer:4*1024*1024});
assert.equal(prior.status,0,prior.stderr);
const old=prior.stdout.replace(/\r\n?/g,'\n');
function between(text,start,end){const a=text.indexOf(start),b=text.indexOf(end,a+start.length);assert(a>=0&&b>a,start);return text.slice(a,b);}
const guard=text=>between(text,'shared.PunchWallInstallCameraGeometryGuard = function()','\nif RunService:IsStudio() then\n\tshared.PunchWallRunCameraAutomation');
const inherited=fs.readFileSync(path.join(root,'work/automation/scripts/camera-geometry-guard-contract.mjs'),'utf8');
// Reuse only the existing deterministic math/service mocks, never run its tests.
const commonLiteral=between(inherited,'const common = ','\nconst guard =').slice('const common = '.length).trim().replace(/;$/,'');
const common=Function(`return ${commonLiteral};`)()
 .replace("if k=='Rotation'",`if k=='RightVector' then return Vector3.new(1,0,0) end
 if k=='UpVector' then return Vector3.new(0,1,0) end
 if k=='PointToObjectSpace' then return function(a,p)return p-a.Position end end
 if k=='PointToWorldSpace' then return function(a,p)return p+a.Position end end
 if k=='Rotation'`)
 .replace("local character={FindFirstChild=function() return rootPart end}","local headPart={Position=Vector3.zero}\nlocal character={FindFirstChild=function(_,name)return name=='Head' and headPart or rootPart end}");
// The hook sets the captured native failure's initial private state. Every
// production sensor, limiter, fallback, publication and next-update path stays
// verbatim. It is injected only into the temporary executable harness.
const seedHook=`
 shared.__SeedPublishedCache=function(cache,focus,radius)
  lastClearCameraCFrame=cache lastClearCameraFocus=focus
  shared.PunchWallHeartbeatLastClearCFrame=cache shared.PunchWallHeartbeatLastClearFocus=focus
  userOrbitDistance=radius orbitCharacter=player.Character lastRootPosition=rootPart.Position
  recoveringFromGeometryClamp=true recoveringFromFollowHandoff=true wasActiveFollow=false
  gui:SetAttribute('PunchCameraHandoffActive',true)
  gui:SetAttribute('PunchCameraGeometryClamped',true)
  gui:SetAttribute('PunchCameraUserOrbitDistance',radius)
 end
 shared.__ReadPublishedCache=function()
  return lastClearCameraCFrame,lastClearCameraFocus,shared.PunchWallHeartbeatLastClearCFrame,shared.PunchWallHeartbeatLastClearFocus
 end
`;
const setup=String.raw`
local update=bound.PunchWallCameraGeometryGuard
camera.ViewportSize={X=844,Y=369}
function camera:WorldToViewportPoint(p)return Vector3.new(422,184+p.Y*20,50),true end
local capturedRaw=Vector3.new(-2.000030517578125,9.414546966552734,-94.07560729980469)
local capturedRequested=Vector3.new(-2.000030517578125,9.415884971618652,-94.06913757324219)
local capturedCache=Vector3.new(-.9377396106719971,1.3844385147094727,-72.80543518066406)
local selected=23.26280403137207
local residual=(capturedRequested-capturedRaw).Magnitude
local target=capturedRaw-(capturedRequested-capturedRaw).Unit*(selected-residual)
rootPart.Position=target headPart.Position=target+Vector3.new(0,1.5,0)
local rawFrame=frame(capturedRaw,.7)
local rawFocus=frame(capturedRaw+Vector3.new(0,-4.7,-22.7),.7)
local cacheFrame=frame(capturedCache,.7)
local cacheFocus=frame(capturedCache+Vector3.new(0,-4.7,-22.7),.7)
local function begin(kind)
 shared.PunchWallResetCameraGeometryGuard(character)
 camera.CameraType='Custom'camera.CFrame=rawFrame camera.Focus=rawFocus
 player.CameraMinZoomDistance=selected player.CameraMaxZoomDistance=selected
 attrs.PunchCameraFollowActive=false
 shared.__SeedPublishedCache(cacheFrame,cacheFocus,selected)
 blocked=function()return kind=='physical'end
 -- Match the retained clear raw/desired and occluded old cache. Unavailable
 -- angular endpoints are a controlled sensor fixture, not a reconstruction
 -- of every live falling block from a single captured frame.
 occluded=function(p)return kind=='los' or (p-capturedRaw).Magnitude>.05 end
 now+=.05 update(.05)
 return shared.PunchWallCameraLastRecovery
end
local function cacheIs(cf,focus)
 local a,b,c,d=shared.__ReadPublishedCache()
 return a==cf and b==focus and c==cf and d==focus
end
`;
const cases=String.raw`
check(residual>.0065 and residual<.0067,'fixture preserves actual retained endpoint residual')
local first=begin('clear')
check((camera.CFrame.Position-capturedRaw).Magnitude==0 and camera.Focus==rawFocus,'fallback cache synchronization adds no camera or focus assignment')
check(first.reason=='cached-recovery/no-safe-step' and first.cacheBlocked and not first.rawBlocked and not first.publishedBlocked,'fixture takes actual stale-cache no-safe-step failure path')
check(cacheIs(camera.CFrame,camera.Focus),'all four caches track the actual clear published pose')
check(attrs.PunchCameraHandoffActive==true and attrs.PunchCameraGeometryClamped==true,'cache synchronization does not waive handoff or geometry recovery')
local before=camera.CFrame.Position local focusOffset=camera.CFrame.Position-camera.Focus.Position
now+=.05 camera.CFrame=rawFrame camera.Focus=rawFocus update(.05)
local next=shared.PunchWallCameraLastRecovery
check(attrs.PunchCameraHandoffActive==false and attrs.PunchCameraGeometryClamped==false,'next actual update completes exact recovery instead of repeating stale history')
check(next.remaining<.001 and (camera.CFrame.Position-capturedRequested).Magnitude<.001,'handoff only completes at the actual requested endpoint')
check((camera.CFrame.Position-before).Magnitude<=1.200001 and (camera.CFrame.Position-before).Magnitude<.007,'final correction keeps the original response budget')
check(camera.CFrame.Yaw==.7 and ((camera.CFrame.Position-camera.Focus.Position)-focusOffset).Magnitude<.00001,'actual correction preserves rotation and focus offset')
check(cacheIs(camera.CFrame,camera.Focus),'normal completion retains matching four caches')
begin('clear')now+=.00001 camera.CFrame=rawFrame camera.Focus=rawFocus update(.00001)
check(attrs.PunchCameraHandoffActive==true and shared.PunchWallCameraLastRecovery.remaining>.001,'small frame cannot use .08 zoom tolerance as handoff completion')
check((camera.CFrame.Position-capturedRaw).Magnitude<=.000241,'small frame preserves 24 times deltaTime correction budget')
now+=.05 camera.CFrame=rawFrame camera.Focus=rawFocus update(.05)
check(attrs.PunchCameraHandoffActive==false and shared.PunchWallCameraLastRecovery.remaining<.001,'subsequent budget completes real residual correction')
for _,kind in ipairs({'los','physical'})do
 local result=begin(kind)
 check(cacheIs(cacheFrame,cacheFocus),'blocked actual pose never contaminates any safety cache: '..kind)
 check(attrs.PunchCameraHandoffActive==true and attrs.PunchCameraGeometryClamped==true,'no-fit scene does not certify recovery: '..kind)
 check(result.publishedBlocked and result.candidate==nil,'unresolved no-fit pose remains explicit: '..kind)
 check(attrs.PunchCameraSafetyUnresolved==(kind=='physical'),'physical safety diagnostic remains actual: '..kind)
 check(attrs.PunchCameraLineOfSightUnresolved==(kind=='los'),'LOS diagnostic remains separate: '..kind)
end
begin('clear')camera.CameraType='Scriptable'local owned=frame(Vector3.new(100,20,30),1.1)local ownedFocus=frame(Vector3.new(100,20,20),1.1)
camera.CFrame=owned camera.Focus=ownedFocus now+=.05 update(.05)
check(camera.CFrame==owned and camera.Focus==ownedFocus,'Scriptable ownership remains untouched')
check(cacheIs(rawFrame,rawFocus),'Scriptable pose does not enter the Custom safety cache')
shared.PunchWallResetCameraGeometryGuard(character)
local a,b,c,d=shared.__ReadPublishedCache()
check(a==nil and b==nil,'normal lifecycle reset still removes private camera history')
print('PUBLISHED_CACHE_PASS '..count)
`;
const historical=String.raw`
begin('clear')
check(cacheIs(cacheFrame,cacheFocus),'baseline retains the stale cache despite actual clear publication')
for i=1,81 do now+=.05 camera.CFrame=rawFrame camera.Focus=rawFocus update(.05)end
local last=shared.PunchWallCameraLastRecovery
check(attrs.PunchCameraHandoffActive==true and attrs.PunchCameraGeometryClamped==true,'baseline reproduces handoff timeout after the original four-second window')
check(last.reason=='cached-recovery/no-safe-step' and last.cacheBlocked and not last.rawBlocked and not last.publishedBlocked,'baseline reproduces actual failure classification')
check(last.remaining>.0065 and last.remaining<.0067,'baseline remains stuck despite a real correctable residual')
print('PUBLISHED_CACHE_PASS '..count)
`;
const candidates=[process.env.LUAU_COMMAND,...fs.readdirSync(os.tmpdir()).filter(n=>n.startsWith('codex-luau-')).sort().reverse().map(n=>path.join(os.tmpdir(),n,'luau.exe'))];
const luau=candidates.find(p=>p&&fs.existsSync(p));assert(luau,'Official Luau executable required');
const compiler=process.env.LUAU_COMPILE_COMMAND||path.join(path.dirname(luau),'luau-compile.exe');
const temp=fs.mkdtempSync(path.join(os.tmpdir(),'smash-published-cache-'));let compiled=0,assertions=0,mutations=0;
function compile(name,code,opt='-O1'){const p=path.join(temp,name+'.luau');fs.writeFileSync(p,code);const r=spawnSync(compiler,['--null',opt,p],{encoding:'utf8',timeout:15000});assert.equal(r.status,0,r.stderr);compiled++;return p;}
function execute(name,text,expectFailure=false){
 const p=compile(name,text),r=spawnSync(luau,[p],{encoding:'utf8',timeout:15000});
 if(expectFailure){assert.notEqual(r.status,0,name+' survived');assert.match(r.stderr,/function check/,name+' must fail an executed behavior assertion');mutations++;}
 else{assert.equal(r.status,0,r.stdout+r.stderr);const m=r.stdout.match(/PUBLISHED_CACHE_PASS (\d+)/);assert(m,r.stdout);assertions+=Number(m[1]);}
}
function program(text,checks){return common+guard(text).replace('\tlocal function clearTranslationStep',seedHook+'\tlocal function clearTranslationStep')+setup+checks;}
try{
 for(const opt of ['-O0','-O1','-O2'])compile('client-'+opt.slice(1),source,opt);
 execute('actual-recorded-state',program(source,cases));
 execute('historical-recorded-state',program(old,historical));
 const patch=between(source,'\t\t\tlocal lineOfSightBlocked = not physicallyBlocked','\t\t\tgui:SetAttribute("PunchCameraSafetyUnresolved", physicallyBlocked)');
 assert(!/camera\.(CFrame|Focus)\s*=|recoveringFrom\w+\s*=|SetAttribute|task\./.test(patch),'cache repair cannot move camera, waive flags, yield or publish invented diagnostics');
 for(const [name,from,to]of [
  ['physical_guard_removed','if not physicallyBlocked and not lineOfSightBlocked then','if not lineOfSightBlocked then'],
  ['los_guard_removed','if not physicallyBlocked and not lineOfSightBlocked then','if not physicallyBlocked then'],
  ['private_pose_omitted','lastClearCameraCFrame = camera.CFrame','lastClearCameraCFrame = lastClearCameraCFrame'],
  ['private_focus_omitted','lastClearCameraFocus = camera.Focus','lastClearCameraFocus = lastClearCameraFocus'],
  ['heartbeat_pose_omitted','shared.PunchWallHeartbeatLastClearCFrame = camera.CFrame','shared.PunchWallHeartbeatLastClearCFrame = shared.PunchWallHeartbeatLastClearCFrame'],
  ['heartbeat_focus_omitted','shared.PunchWallHeartbeatLastClearFocus = camera.Focus','shared.PunchWallHeartbeatLastClearFocus = shared.PunchWallHeartbeatLastClearFocus'],
  ['camera_assignment_added','lastClearCameraCFrame = camera.CFrame','camera.CFrame = lastClearCameraCFrame\n\t\t\t\tlastClearCameraCFrame = camera.CFrame'],
  ['handoff_waived','lastClearCameraCFrame = camera.CFrame','gui:SetAttribute("PunchCameraHandoffActive", false)\n\t\t\t\tlastClearCameraCFrame = camera.CFrame'],
 ]){assert(patch.includes(from),name);execute(name,program(source.replace(patch,patch.replace(from,to)),cases),true);}
 execute('arrival_tolerance_waived',program(source.replace('local arrived = limitedCFrame and (desiredPosition - requestedPosition).Magnitude < 0.001','local arrived = limitedCFrame and (desiredPosition - requestedPosition).Magnitude < 0.08'),cases),true);
 console.log(JSON.stringify({ok:true,baseline,compiled,executedAssertions:assertions,compiledMutationRejections:mutations,retainedNativeCoordinates:true,scope:'Recorded private-state replay with controlled physical/LOS sensors; full native replay pending.'},null,2));
}finally{assert.equal(path.dirname(fs.realpathSync(temp)),fs.realpathSync(os.tmpdir()));assert(path.basename(temp).startsWith('smash-published-cache-'));fs.rmSync(temp,{recursive:true,force:true});}
