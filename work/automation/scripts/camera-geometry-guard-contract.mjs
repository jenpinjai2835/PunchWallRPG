#!/usr/bin/env node
// Execute the production guard, respawn callback and occlusion binding with controlled geometry.
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../../..");
const clientPath = "work/punch-wall-rpg/src/client/PunchWallClient.client.lua";
const losBaseline = process.argv.includes("--baseline-los");
const runtimeBaseline = process.argv.includes("--baseline-runtime2");
const faceBaseline = process.argv.includes('--baseline-face');
const finalBaseline = process.argv.includes('--baseline-final');
const settleBaseline = process.argv.includes('--baseline-settle');
const baselineIndex = process.argv.indexOf(settleBaseline ? '--baseline-settle' : finalBaseline ? '--baseline-final' : faceBaseline ? '--baseline-face' : runtimeBaseline ? "--baseline-runtime2" : losBaseline ? "--baseline-los" : "--baseline");
const baseline = baselineIndex < 0 ? null : process.argv[baselineIndex + 1] || (settleBaseline ? '07e4009' : finalBaseline ? '6211b00' : faceBaseline ? '4d23e28' : runtimeBaseline ? "781ff4b" : losBaseline ? "ef9b5f8" : "b521dea");
const original = baseline && spawnSync("git", ["show", `${baseline}:${clientPath}`], { cwd: root, encoding: "utf8" });
if (original) assert.equal(original.status, 0, original.stderr);
const source = (original ? original.stdout : fs.readFileSync(path.join(root, clientPath), "utf8")).replace(/\r\n?/g, "\n");
function block(start, end) {
  const from = source.indexOf(start);
  const to = source.indexOf(end, from + start.length);
  assert.ok(from >= 0 && to > from, `Missing production boundary ${start} -> ${end}`);
  return source.slice(from, to);
}
const tempRoot = os.tmpdir();
const candidates = [process.env.LUAU_COMMAND, ...fs.readdirSync(tempRoot)
  .filter((name) => name.startsWith("codex-luau-")).sort().reverse()
  .map((name) => path.join(tempRoot, name, process.platform === "win32" ? "luau.exe" : "luau")), "luau"];
const luau = candidates.find((candidate) => candidate && spawnSync(candidate, ["--help"], { encoding: "utf8" }).status === 0);
assert.ok(luau, "BLOCKED: set LUAU_COMMAND to a Luau CLI executable");
const compiler = process.env.LUAU_COMPILE_COMMAND || path.join(path.dirname(luau), process.platform === 'win32' ? 'luau-compile.exe' : 'luau-compile');

const common = `
local count = 0
local function check(value, name) assert(value, name) count += 1 end
local function signal()
 local callbacks = {}
 return {Connect=function(_, cb) table.insert(callbacks, cb) end,
  Fire=function(_, ...) for _,cb in ipairs(callbacks) do cb(...) end end}
end
local Vector3, vm = {}, {}
function Vector3.new(x,y,z) return setmetatable({X=x,Y=y,Z=z},vm) end
vm.__add=function(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
vm.__sub=function(a,b) return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
vm.__mul=function(a,b) if type(a)=='number' then a,b=b,a end return Vector3.new(a.X*b,a.Y*b,a.Z*b) end
vm.__index=function(a,k)
 if k=='Magnitude' then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z) end
 if k=='Unit' then return a*(1/a.Magnitude) end
 if k=='Dot' then return function(a,b) return a.X*b.X+a.Y*b.Y+a.Z*b.Z end end
 if k=='Cross' then return function(a,b) return Vector3.new(a.Y*b.Z-a.Z*b.Y,a.Z*b.X-a.X*b.Z,a.X*b.Y-a.Y*b.X) end end
end
Vector3.zero=Vector3.new(0,0,0)
local CFrame, fm = {}, {}
local function frame(p,yaw) return setmetatable({Position=p,Yaw=yaw or 0},fm) end
function CFrame.new(x,y,z) return frame(type(x)=='table' and x or Vector3.new(x or 0,y or 0,z or 0)) end
fm.__add=function(a,b) return frame(a.Position+b,a.Yaw) end
fm.__mul=function(a,b) return frame(a.Position+b.Position,a.Yaw+b.Yaw) end
fm.__index=function(a,k)
 if k=='Rotation' then return frame(Vector3.zero,a.Yaw) end
 if k=='LookVector' then return Vector3.new(math.sin(a.Yaw),0,-math.cos(a.Yaw)) end
end
local now=100
local os={clock=function() return now end}
local attrs={}
local gui={GetAttribute=function(_,key) return attrs[key] end, SetAttribute=function(_,key,value) attrs[key]=value end}
local Enum={CameraType={Custom='Custom',Scriptable='Scriptable'},
 DevCameraOcclusionMode={Zoom='Zoom',Invisicam='Invisicam'},
 RenderPriority={Camera={Value=200},Last={Value=2000}},
 UserInputType={MouseWheel='MouseWheel'},UserInputState={Begin='Begin',Change='Change',End='End',Cancel='Cancel'}}
local rootPart={Position=Vector3.zero}
local character={FindFirstChild=function() return rootPart end}
local propertySignal=signal()
local player={Character=character,CharacterAdded=signal(),CharacterRemoving=signal(),DevCameraOcclusionMode='Zoom',
 GetPropertyChangedSignal=function() return propertySignal end}
local camera={CameraType='Custom',CFrame=CFrame.new(),Focus=CFrame.new(0,0,-12)}
local workspace={CurrentCamera=camera}
local bound,bindCounts={},{}
local RunService={IsStudio=function() return true end,Heartbeat=signal(),PostSimulation=signal(),BindToRenderStep=function(_,name,_,cb) bound[name]=cb bindCounts[name]=(bindCounts[name] or 0)+1 end}
local UserInputService={InputChanged=signal(),TouchPinch=signal()}
local blocked=function() return false end
local occluded=function() return false end
local resolver=function(cf,focus)
 if blocked(cf.Position) or occluded(cf.Position) then return nil,nil,nil,nil end
 return cf,focus,Vector3.zero,nil
end
local shared={PunchWallCameraPositionBlocked=function(p) return blocked(p) end}
local function cameraPoseBlocked(cf) return blocked(cf.Position) or occluded(cf.Position) end
local function cameraCharacterTarget(c) return c:FindFirstChild('HumanoidRootPart').Position end
local function resolveClearCameraPose(cf,focus,c) return resolver(cf,focus,c) end
local activePunchCamera=nil
local lastPunchCameraRenderAt=now
local lastPunchActionAt=now
local function pose(x,y,z) camera.CFrame=frame(Vector3.new(x,y or 0,z or 0),.7) camera.Focus=frame(camera.CFrame.Position+Vector3.new(0,0,-12),.7) end
`;
const guard = block("shared.PunchWallInstallCameraGeometryGuard = function()", "\nif RunService:IsStudio() then\n\tshared.PunchWallRunCameraAutomation");
const guardSetup = `${common}${guard}
local update=bound.PunchWallCameraGeometryGuard
local function seed()
 pose(0,0,0) update(1/60)
 attrs.PunchCameraFollowActive=true
end
`;
const automationSetup = block('shared.PunchWallRunCameraAutomation = function(punchCount)', '\n\t\tlocal initialOrbitSettled = false');
const flow = JSON.parse(fs.readFileSync(path.join(root, 'work/automation/flows/camera-long-tunnel-regression.json'), 'utf8'));
const flowCode = flow.steps.find(step => step.args?.code?.includes("automation:Invoke('__RunCamera',18)")).args.code;
const flowGate = flowCode.slice(flowCode.indexOf('local correctionBounded='), flowCode.indexOf(' diagnostics={'));
assert.ok(flowGate.includes('local contractValid='), 'Missing actual long-tunnel flow gate');
// Independent 15-axis separating-axis oracle for a .55 world-axis camera box
// against oriented block boxes. Production code supplies candidates and sweeps.
const orientedWorld = `
local worldAxes={Vector3.new(1,0,0),Vector3.new(0,1,0),Vector3.new(0,0,1)}
local rotatedAxes={Vector3.new(2/3,2/3,-1/3),Vector3.new(-1/3,2/3,2/3),Vector3.new(2/3,-1/3,2/3)}
local function testBlock(name,position,axes,size)
 return {Name=name,Position=position,Size=size or Vector3.new(4,4,4),Axes=axes,
 CFrame={RightVector=axes[1],UpVector=axes[2],LookVector=axes[3]},AssemblyLinearVelocity=Vector3.new(0,-7,0),GetAttribute=function() return true end}
end
local function intersects(part,position)
 local axes=table.clone(worldAxes)
 for _,axis in ipairs(part.Axes) do table.insert(axes,axis) end
 for _,a in ipairs(worldAxes) do for _,b in ipairs(part.Axes) do table.insert(axes,a:Cross(b)) end end
 local extents={part.Size.X*.5,part.Size.Y*.5,part.Size.Z*.5}
 for _,axis in ipairs(axes) do
  local radius=.275*(math.abs(axis.X)+math.abs(axis.Y)+math.abs(axis.Z))
  for index,partAxis in ipairs(part.Axes) do radius+=extents[index]*math.abs(partAxis:Dot(axis)) end
  if math.abs((position-part.Position):Dot(axis))>radius then return false end
 end
 return true
end
local blocks={}
blocked=function(position)
 for _,part in ipairs(blocks) do if intersects(part,position) then return true end end
 return false
end
shared.PunchWallCameraPositionBlocked=function(position,_,collect)
 local hits={}
 for _,part in ipairs(blocks) do if intersects(part,position) then table.insert(hits,part) end end
 return #hits>0,collect and hits or nil
end
`;
const fixtures = {
  limiter: `${guardSetup}
seed()
blocked=function(p) return p.X>.15 and p.X<1 and p.Y<.35 end
pose(4,4,0)
local originalOffset=camera.CFrame.Position-camera.Focus.Position
update(1/60)
check(not blocked(camera.CFrame.Position),'limited_pose_physically_clear')
check(camera.CFrame.Position.Magnitude<=.40001,'limited_step_bounded')
check(camera.CFrame.Position.Y>.39 and math.abs(camera.CFrame.Position.X)<.001,'blocked_diagonal_uses_vertical_step')
check(camera.CFrame.Yaw==.7 and ((camera.CFrame.Position-camera.Focus.Position)-originalOffset).Magnitude<.001,'limiter_preserves_orbit_rotation_and_zoom')
check(not blocked(shared.PunchWallHeartbeatLastClearCFrame.Position),'cache_contains_checked_pose')
blocked=function() return false end
local previous=camera.CFrame.Position
pose(4,4,0) update(1/60)
check((camera.CFrame.Position-previous).Magnitude<=.40001 and (camera.CFrame.Position-previous).Magnitude>.39,'clear_direct_step_resumes')
print('PASS '..count)
`,
  sweep: `${guardSetup}
seed()
blocked=function(p) return p.X>.09 and p.X<.3 end
pose(4,0,0) update(1/60)
check(camera.CFrame.Position.Magnitude<.001,'clear_endpoint_does_not_cross_thin_wall')
check(shared.PunchWallHeartbeatLastClearCFrame.Position.Magnitude<.001,'blocked_path_does_not_poison_cache')
blocked=function() return false end
pose(4,0,0) update(1/60)
check(math.abs(camera.CFrame.Position.X-.4)<.001,'removed_obstacle_resumes_bounded_follow')
print('PASS '..count)
`,
  fallback: `${guardSetup}
seed()
attrs.PunchCameraFollowActive=false
shared.PunchWallCameraBaselineCFrame=CFrame.new(3,0,0)
shared.PunchWallCameraBaselineFocus=CFrame.new(3,0,-12)
blocked=function(p) return math.abs(p.X)<.01 or math.abs(p.X-3)<.01 end
resolver=function() return nil,nil,nil,nil end
pose(4,0,0) update(1/60)
check(math.abs(camera.CFrame.Position.X-4)<.001,'blocked_baseline_is_never_published')
check(shared.PunchWallHeartbeatLastClearCFrame.Position.X~=3,'blocked_fallback_not_cached')
blocked=function(p) return math.abs(p.X)<.01 end
pose(4,0,0) update(1/60)
check(not blocked(camera.CFrame.Position) and math.abs(camera.CFrame.Position.X)>.01,'clear_baseline_or_local_egress_remains_available')
print('PASS '..count)
`,
  final: `${guardSetup}
-- The guard must check the actual published pose even if geometry changes
-- after the earlier resolver observation.
blocked=function(p) return p.X==5 end
resolver=function(_,focus) return CFrame.new(5,0,0),focus,Vector3.zero,nil end
pose(4,0,0) update(1/60)
check(camera.CFrame.Position.X==4,'final_physical_check_precedes_publish')
check(shared.PunchWallHeartbeatLastClearCFrame==nil,'invalid_final_pose_not_cached')
print('PASS '..count)
`,
  lifecycle: `${guardSetup}
seed()
attrs.PunchCameraFollowActive=false
resolver=function() return nil,nil,nil,nil end
pose(4,0,0) update(1/60)
local newRoot={Position=Vector3.new(100,0,0)}
local newCharacter={FindFirstChild=function() return newRoot end}
player.Character=newCharacter
resolver=function(cf,focus) return cf,focus,Vector3.zero,nil end
pose(105,0,0) update(1/60)
check(camera.CFrame.Position.X==105,'new_character_does_not_recover_toward_old_cache')
local punchMotionState={}
activePunchCamera={}
attrs.PunchCameraFollowActive=true
attrs.PunchCameraHandoffActive=true
attrs.CharacterPunchMotionActive=true
shared.PunchWallCameraBaselineCFrame=CFrame.new(0,0,0)
shared.PunchWallCameraBaselineFocus=CFrame.new(0,0,-12)
local companionRuntime={CancelVisualRetry=function() end,ObserveCharacterHandSizes=function() end}
local visualSignature='old'
local refreshCharacterVisuals=function() end
local task={defer=function() end}
${block("\nplayer.CharacterAdded:Connect(function(", source.includes("\ntask.defer(function()\n\tcompanionRuntime.ObserveCharacterHandSizes") ? "\ntask.defer(function()\n\tcompanionRuntime.ObserveCharacterHandSizes" : "\ntask.defer(function()\n\trequestAction(\"RequestSync\")")}
player.CharacterAdded:Fire(newCharacter)
check(attrs.PunchCameraFollowActive==false and attrs.PunchCameraHandoffActive==false,'respawn_clears_persistent_follow_flags')
check(activePunchCamera==nil and punchMotionState==nil and attrs.CharacterPunchMotionActive==false,'respawn_cancels_motion_state')
check(shared.PunchWallHeartbeatLastClearCFrame==nil and shared.PunchWallCameraBaselineCFrame==nil,'respawn_clears_shared_camera_caches')
lastPunchActionAt=0
pose(105,0,0) update(1/60)
check(attrs.PunchCameraUserOrbitDistance==5 and camera.CFrame.Position.X==105,'new_character_initializes_own_orbit')
camera.CameraType='Scriptable'
pose(123,0,0) update(1/60)
check(camera.CFrame.Position.X==123 and attrs.PunchCameraScriptableBypass==true,'lifecycle_preserves_scriptable_owner')
print('PASS '..count)
`,
  respawn: `${guardSetup}
seed()
local punchMotionState={}
activePunchCamera={}
attrs.PunchCameraFollowActive=true
attrs.PunchCameraHandoffActive=true
local companionRuntime={CancelVisualRetry=function() end,ObserveCharacterHandSizes=function() end}
local visualSignature='old'
local refreshCharacterVisuals=function() end
local task={defer=function() end}
${block("\nplayer.CharacterAdded:Connect(function(", source.includes("\ntask.defer(function()\n\tcompanionRuntime.ObserveCharacterHandSizes") ? "\ntask.defer(function()\n\tcompanionRuntime.ObserveCharacterHandSizes" : "\ntask.defer(function()\n\trequestAction(\"RequestSync\")")}
player.CharacterAdded:Fire(character)
check(attrs.PunchCameraFollowActive==false and attrs.PunchCameraHandoffActive==false,'respawn_clears_persistent_follow_flags')
check(activePunchCamera==nil and punchMotionState==nil,'respawn_releases_actual_follow_and_motion')
print('PASS '..count)
`,
  occlusion: `${common}
local part={Parent=true,LocalTransparencyModifier=.75,IsA=function() return true end}
function camera:GetPartsObscuringTarget() return {part} end
${block("local cameraOcclusionApplied =", source.includes("\nlocal bossHudTimer =") ? "\nlocal bossHudTimer =" : "\n-- Boss HP and countdown")}
check(attrs.PreservePlayerZoomInTunnels==false,'initial_zoom_mode_is_not_misreported')
player.DevCameraOcclusionMode='Invisicam' propertySignal:Fire()
check(attrs.PreservePlayerZoomInTunnels==true and attrs.CameraOcclusionMode=='OpaqueInvisicam','late_invisicam_updates_policy')
bound.PunchWallOpaqueOcclusion()
check(part.LocalTransparencyModifier==0,'late_invisicam_restores_actual_opacity')
for _=1,4 do player.DevCameraOcclusionMode='Zoom' propertySignal:Fire() player.DevCameraOcclusionMode='Invisicam' propertySignal:Fire() end
check(bindCounts.PunchWallOpaqueOcclusion==1,'mode_changes_never_duplicate_render_binding')
player.DevCameraOcclusionMode='Zoom' propertySignal:Fire()
part.LocalTransparencyModifier=.5 bound.PunchWallOpaqueOcclusion()
check(attrs.CameraOcclusionOpaque==false and part.LocalTransparencyModifier==.5,'inactive_mode_does_not_override_other_owner')
print('PASS '..count)
`,
  losLimiter: `${guardSetup}
seed()
occluded=function(p) return p.X>.15 and p.X<1 and p.Y<.35 end
pose(4,4,0) update(1/60)
check(not occluded(camera.CFrame.Position),'limited_pose_has_clear_line_of_sight')
check(camera.CFrame.Position.Y>.39 and math.abs(camera.CFrame.Position.X)<.001,'los_blocked_diagonal_uses_clear_vertical_step')
check(camera.CFrame.Position.Magnitude<=.40001,'los_alternative_keeps_correction_bounded')
check(not occluded(shared.PunchWallHeartbeatLastClearCFrame.Position),'occluded_pose_never_poisoned_clear_cache')
occluded=function() return false end
local previous=camera.CFrame.Position
pose(4,4,0) update(1/60)
check((camera.CFrame.Position-previous).Magnitude<=.40001 and camera.CFrame.Position.X>0,'removed_los_obstacle_resumes_direct_follow')
print('PASS '..count)
`,
  losFinal: `${guardSetup}
occluded=function(p) return p.X==5 end
resolver=function(_,focus) return CFrame.new(5,0,0),focus,Vector3.zero,nil end
pose(4,0,0) update(1/60)
check(camera.CFrame.Position.X==4,'final_los_check_precedes_publish')
check(shared.PunchWallHeartbeatLastClearCFrame==nil,'invalid_los_final_pose_not_cached')
print('PASS '..count)
`,
  losFallback: `${guardSetup}
seed()
attrs.PunchCameraFollowActive=false
shared.PunchWallCameraBaselineCFrame=CFrame.new(3,0,0)
shared.PunchWallCameraBaselineFocus=CFrame.new(3,0,-12)
occluded=function(p) return p.X<2 or math.abs(p.X-3)<.01 end
resolver=function() return nil,nil,nil,nil end
pose(4,0,0) update(1/60)
check(math.abs(camera.CFrame.Position.X-4)<.001,'occluded_cache_and_baseline_never_published')
occluded=function(p) return p.X<2 end
pose(4,0,0) update(1/60)
check(math.abs(camera.CFrame.Position.X-3)<.001,'clear_los_baseline_remains_available')
print('PASS '..count)
`,
  lowFpsRootFollow: `${guardSetup}
lastPunchActionAt=0
pose(0,0,12) update(1/60)
attrs.PunchCameraFollowActive=true
for index=1,10 do
 rootPart.Position=Vector3.new(0,0,-5*index)
 pose(0,0,rootPart.Position.Z+12)
 now+=.2 update(.2)
 check(math.abs((camera.CFrame.Position-rootPart.Position).Magnitude-12)<.001,'low_fps_root_follow_preserves_requested_orbit')
end
check(attrs.PunchCameraMaxCorrectionStep<.001,'ordinary_root_translation_does_not_spend_correction_budget')
check(attrs.PunchCameraInheritedRootStep==5,'ordinary_root_step_is_measured_separately')
attrs.PunchCameraFollowActive=false
pose(0,0,rootPart.Position.Z+12) update(.2)
check(attrs.PunchCameraHandoffActive==false,'clear_follow_settles_without_backlog')
check(camera.CFrame.Yaw==.7 and math.abs((camera.CFrame.Position-camera.Focus.Position).Magnitude-12)<.001,'root_follow_preserves_live_rotation_and_focus_distance')
print('PASS '..count)
`,
  rootSweep: `${guardSetup}
seed()
blocked=function(p) return p.X>.9 and p.X<1.1 end
rootPart.Position=Vector3.new(4,0,0)
pose(4,0,0) update(1/60)
check(camera.CFrame.Position.X<.9 and not blocked(camera.CFrame.Position),'inherited_root_motion_cannot_cross_thin_wall')
check((attrs.PunchCameraInheritedRootStep or 0)==0,'blocked_root_translation_is_not_inherited')
check(camera.CFrame.Position.Magnitude<=.40001,'blocked_root_path_retains_bounded_correction')
print('PASS '..count)
`,
  rootCarryLos: `${guardSetup}
seed()
rootPart.Position=Vector3.new(4,0,0)
occluded=function(p) return p.X>3.9 and p.X<5 and p.Y<.35 end
pose(8,4,0) update(1/60)
check(math.abs(camera.CFrame.Position.X-4)<.001 and camera.CFrame.Position.Y>.39,'carried_pose_keeps_current_character_line_of_sight')
check(not occluded(camera.CFrame.Position) and not occluded(shared.PunchWallHeartbeatLastClearCFrame.Position),'carried_pose_and_cache_are_not_occluded')
check(attrs.PunchCameraMaxCorrectionStep<=.40001,'carried_los_alternative_keeps_correction_bounded')
print('PASS '..count)
`,
  clearPartialRecovery: `${guardSetup}
seed()
rootPart.Position=Vector3.new(5,0,0)
resolver=function() return nil,nil,nil,nil end
pose(15,0,0) update(1/60)
check(camera.CFrame.Position.X>5 and camera.CFrame.Position.X<5.401,'verified_partial_recovery_does_not_stall_with_unavailable_far_endpoint')
check(shared.PunchWallHeartbeatLastClearCFrame.Position.X==camera.CFrame.Position.X,'verified_partial_recovery_is_cached')
print('PASS '..count)
`,
  overlapRecovery: `${guardSetup}
lastPunchActionAt=0
pose(0,0,12) update(1/60)
attrs.PunchCameraFollowActive=true
blocked=function(p) return math.abs(p.X)<.6 and math.abs(p.Y)<.6 and math.abs(p.Z-12)<.6 end
local originalPosition=camera.CFrame.Position
local originalOffset=camera.CFrame.Position-camera.Focus.Position
update(1/60)
check(not blocked(camera.CFrame.Position),'falling_block_overlap_has_clear_published_egress')
check((camera.CFrame.Position-originalPosition).Magnitude<=2.40001,'overlap_egress_stays_bounded')
check(not occluded(camera.CFrame.Position),'overlap_egress_requires_line_of_sight')
check(((camera.CFrame.Position-camera.Focus.Position)-originalOffset).Magnitude<.001 and camera.CFrame.Yaw==.7,'overlap_egress_preserves_live_rotation_and_focus')
check(not blocked(shared.PunchWallHeartbeatLastClearCFrame.Position),'overlap_egress_refreshes_checked_cache')
check(attrs.PunchCameraOverlapEscapes==1 and attrs.PunchCameraSafetyUnresolved==false,'overlap_egress_is_measured_and_resolved')
blocked=function() return false end
attrs.PunchCameraFollowActive=false
for _=1,80 do pose(0,0,12) update(1/60) end
check(attrs.PunchCameraHandoffActive==false and math.abs(camera.CFrame.Position.Magnitude-12)<.001,'removed_falling_block_restores_selected_radius_and_handoff')
print('PASS '..count)
`,
  heartbeatOverlap: `${guardSetup}
lastPunchActionAt=0
pose(0,0,12) update(1/60)
attrs.PunchCameraFollowActive=true
blocked=function(p) return math.abs(p.X)<.6 and math.abs(p.Y)<.6 and math.abs(p.Z-12)<.6 end
now+=.02
RunService.PostSimulation:Fire(1/60)
RunService.Heartbeat:Fire(1/60)
check(not blocked(camera.CFrame.Position),'physics_overlap_is_repaired_before_next_render')
check(attrs.PunchCameraOverlapEscapes==1,'fresh_render_physics_egress_is_measured')
check(shared.PunchWallCameraFirstEscape.phase=='postsimulation-overlap' and shared.PunchWallCameraFirstEscape.originKind=='cached','physics_egress_attributes_actual_phase_and_origin')
camera.CameraType='Scriptable'
pose(0,0,12) RunService.Heartbeat:Fire(1/60)
check(blocked(camera.CFrame.Position),'physics_safety_does_not_steal_scriptable_camera')
print('PASS '..count)
`,
  overlapWithoutHistory: `${guardSetup}
blocked=function(p) return math.abs(p.X)<.6 and math.abs(p.Y)<.6 and math.abs(p.Z)<.6 end
pose(0,0,0) update(1/60)
check(not blocked(camera.CFrame.Position),'blocked_raw_camera_without_usable_cache_has_validated_egress')
check(camera.CFrame.Position.Magnitude<=2.40001,'uncached_egress_stays_bounded')
check(shared.PunchWallHeartbeatLastClearCFrame and not blocked(shared.PunchWallHeartbeatLastClearCFrame.Position),'uncached_egress_becomes_valid_history')
check(attrs.PunchCameraSafetyUnresolved==false,'uncached_egress_reports_actual_final_safety')
print('PASS '..count)
`,
  enclosingObject: `${guardSetup}
blocked=function(p) return math.abs(p.X)<3 and math.abs(p.Y)<3 and math.abs(p.Z)<3 end
pose(0,0,0) update(1/60)
check(not blocked(camera.CFrame.Position),'larger_enclosing_object_does_not_freeze_inside_pose')
check(attrs.PunchCameraMaxEscapeStep>2.65 and math.abs(attrs.PunchCameraMaxEscapeStep-camera.CFrame.Position.Magnitude)<.001,'exceptional_escape_exceeds_ordinary_gate_visibly_not_silently')
check(attrs.PunchCameraSafetyUnresolved==false,'exceptional_escape_is_validated_before_publication')
print('PASS '..count)
`,
  overlapControls: `${guardSetup}
seed()
blocked=function(p) return p.Magnitude<.1 or (p.X>.25 and p.X<.6 and math.abs(p.Y)<.3 and math.abs(p.Z)<.3) end
occluded=function(p) return p.Y<-.1 end
pose(4,0,0) update(1/60)
check(not blocked(camera.CFrame.Position) and not occluded(camera.CFrame.Position),'egress_rejects_occluded_endpoints')
check(camera.CFrame.Position.X<.25 or math.abs(camera.CFrame.Position.Y)>=.3 or math.abs(camera.CFrame.Position.Z)>=.3,'egress_cannot_leave_overlap_then_cross_separate_wall')
check(attrs.PunchCameraMaxEscapeStep<=2.4,'egress_negative_controls_keep_small_step')
local previousEscapes=attrs.PunchCameraOverlapEscapes
blocked=function() return false end occluded=function() return false end
pose(4,0,0) update(1/60)
check(attrs.PunchCameraOverlapEscapes==previousEscapes,'ordinary_clear_motion_does_not_use_safety_escape')
print('PASS '..count)
`,
  unavailableSafety: `${guardSetup}
seed()
blocked=function() return true end
pose(0,0,0) update(1/60)
check(attrs.PunchCameraSafetyUnresolved==true and attrs.LastCameraInsideGeometry==true,'impossible_geometry_is_explicit_failure_not_false_clear')
check(attrs.PunchCameraOverlapEscapes==0,'unavailable_egress_is_never_counted_as_success')
print('PASS '..count)
`,
  selectedOrbitSetup: `${common}
function CFrame.lookAt(position) return frame(position) end
rootPart.CFrame=frame(Vector3.zero)
function character:FindFirstChildOfClass() return {} end
function gui:FindFirstChild() return {} end
local task={wait=function() end}
${automationSetup}
return (camera.CFrame.Position-camera.Focus.Position).Magnitude
end
player.CameraMinZoomDistance=2 player.CameraMaxZoomDistance=80
for _,selected in ipairs({22.620990753173829,8,12,37.5}) do
 attrs.PunchCameraUserOrbitDistance=selected
 local actual=shared.PunchWallRunCameraAutomation(18)
 check(math.abs(actual-selected)<.00001,'automation_initial_pose_preserves_actual_selected_orbit')
 check(player.CameraMinZoomDistance==selected and player.CameraMaxZoomDistance==selected,'automation_engine_bounds_match_selected_orbit')
 check(attrs.PunchCameraUserOrbitDistance==selected,'automation_never_rewrites_player_selected_orbit')
end
attrs.PunchCameraUserOrbitDistance=nil
pose(0,1.5,17)
local measured=shared.PunchWallRunCameraAutomation(18)
check(math.abs(measured-17)<.00001 and player.CameraMinZoomDistance==17 and player.CameraMaxZoomDistance==17,'automation_uncached_selection_uses_actual_camera_distance')
print('PASS '..count)
`,
  runtimeAcceptance: `${common}
local function accepted(changes, freshChanges)
 local result={valid=true,visualValid=true,actions=18,inside=0,type='Custom',mode='CustomPreserved',maxCorrectionStep=.4,maxEscapeStep=.7,unresolvedSafetyFrames=0,physicalUnresolvedFrames=0,transientLineOfSightFrames=0,clearRatio=1,settledClearRatio=1,readableRatio=1,settledReadableRatio=1,configuredOrbit=22.62,selectedDistance=22.62,userOrbitDistance=22.62,finishDistance=22.62}
 for key,value in pairs(changes or {}) do result[key]=value end
 local p={CameraMinZoomDistance=2,CameraMaxZoomDistance=80}
 local oldMinZoom,oldMaxZoom=2,80
 local onScreen,readable,freshLineOfSightClear,freshInside,freshFaded=true,true,true,0,0
 if freshChanges then freshInside=freshChanges.inside or 0 freshFaded=freshChanges.faded or 0 freshLineOfSightClear=not freshChanges.obscured end
 local cam={CameraType=Enum.CameraType.Custom}
 local g={GetAttribute=function() return false end}
 ${flowGate}
 return contractValid
end
check(accepted(),'ordinary_egress_selected_orbit_and_fresh_scene_pass')
check(not accepted({maxEscapeStep=2.66}),'excessive_emergency_egress_cannot_pass_smoothness_gate')
check(not accepted({unresolvedSafetyFrames=1}),'reported_unresolved_pose_cannot_pass')
check(not accepted({physicalUnresolvedFrames=1,unresolvedSafetyFrames=1}),'actual_physical_unresolved_pose_cannot_pass')
check(accepted({transientLineOfSightFrames=25,clearRatio=.7988}),'measured_transient_los_with_clear_settled_scene_preserves_original_contract')
check(not accepted({clearRatio=.54}),'original_sampled_los_floor_is_retained')
check(not accepted({settledClearRatio=.89}),'original_settled_los_floor_is_retained')
check(not accepted({readableRatio=.64}),'original_sampled_readability_floor_is_retained')
check(not accepted({settledReadableRatio=.89}),'original_settled_readability_floor_is_retained')
check(not accepted({configuredOrbit=12}),'contradictory_test_radius_cannot_pass')
check(not accepted({userOrbitDistance=12}),'rewritten_selected_radius_cannot_pass')
check(not accepted({finishDistance=12}),'shortened_final_radius_cannot_pass')
check(not accepted({inside=1}),'sampled_inside_frame_cannot_pass')
check(not accepted({}, {inside=1}),'fresh_inside_pose_cannot_pass')
check(not accepted({}, {faded=1}),'faded_avatar_cannot_pass')
check(not accepted({}, {obscured=true}),'fresh_opaque_obstruction_cannot_pass')
check(not accepted({visualValid=false}),'historical_readability_failure_cannot_pass')
print('PASS '..count)
`,
  orientedFaceExit: `${guardSetup}${orientedWorld}
blocks={testBlock('Rotated4StudBlock',Vector3.zero,rotatedAxes)}
pose(0,0,0) update(1/60)
check(camera.CFrame.Position.Magnitude<2.49 and camera.CFrame.Position.Magnitude>2.46,'rotated_block_uses_near_face_exit_within_existing_budget')
check(not intersects(blocks[1],camera.CFrame.Position),'rotated_face_exit_clears_camera_box_support')
check(attrs.PunchCameraMaxEscapeStep<=2.65,'oriented_egress_keeps_existing_safety_bound')
check(shared.PunchWallCameraFirstEscape.kind=='face' and shared.PunchWallCameraFirstEscape.originKind=='current','analytic_source_and_current_origin_are_diagnosed')
check(shared.PunchWallCameraFirstEscape.phase=='render' and shared.PunchWallCameraFirstEscape.parts[1].name=='Rotated4StudBlock','escape_diagnostics_identify_phase_and_actual_part')
check(shared.PunchWallCameraFirstEscape.overlapCount==1 and #shared.PunchWallCameraFirstEscape.parts==1,'bounded_escape_snapshot_matches_actual_overlaps')
print('PASS '..count)
`,
  compoundFaceExit: `${guardSetup}${orientedWorld}
blocks={testBlock('Primary',Vector3.zero,rotatedAxes),testBlock('Neighbor',rotatedAxes[1]*2.2,rotatedAxes)}
occluded=function(p) return p:Dot(rotatedAxes[1])<2 end
pose(0,0,0) update(1/60)
check(not intersects(blocks[1],camera.CFrame.Position) and not intersects(blocks[2],camera.CFrame.Position),'compound_egress_checks_entire_overlap_set')
check(camera.CFrame.Position.Magnitude<=2.65,'compound_egress_stays_within_existing_budget')
check(shared.PunchWallCameraFirstEscape.overlapCount==2 and #shared.PunchWallCameraFirstEscape.parts==2,'compound_escape_reports_both_overlaps')
check(attrs.PunchCameraSafetyUnresolved==false,'compound_physical_exit_is_resolved')
check(attrs.PunchCameraLineOfSightUnresolved==true and shared.PunchWallCameraFirstEscape.losRejected>0,'transient_los_rejection_is_reported_separately')
print('PASS '..count)
`,
  physicalVersusLos: `${guardSetup}
seed()
attrs.PunchCameraFollowActive=false
occluded=function() return true end
pose(4,0,0) update(1/60)
check(attrs.PunchCameraSafetyUnresolved==false,'opaque_query_only_egg_is_not_reported_as_physical_penetration')
check(attrs.PunchCameraLineOfSightUnresolved==true,'opaque_query_only_egg_retains_los_failure_diagnostic')
check(camera.CFrame.Position.X==4 and (attrs.PunchCameraOverlapEscapes or 0)==0,'los_only_failure_never_triggers_large_overlap_escape')
print('PASS '..count)
`,
  lateScriptableOwner: `${guardSetup}
seed()
activePunchCamera={}
attrs.PunchCameraFollowActive=true
camera.CameraType=Enum.CameraType.Scriptable
pose(10,3,0)
local originalPosition=camera.CFrame.Position
local originalFocus=camera.Focus.Position
update(1/60)
RunService.PostSimulation:Fire(1/60)
now+=.5 RunService.Heartbeat:Fire(1/60)
check((camera.CFrame.Position-originalPosition).Magnitude<.00001,'new_scriptable_position_preserved')
check((camera.Focus.Position-originalFocus).Magnitude<.00001,'new_scriptable_focus_preserved')
check(attrs.PunchCameraScriptableBypass==true,'new_scriptable_owner_observed')
print('PASS '..count)
`,
  coarseGap: `${guardSetup}
blocked=function(p) return p.Magnitude<2.5 end
pose(0,0,0) update(1/60)
check(not blocked(camera.CFrame.Position) and camera.CFrame.Position.Magnitude<=2.65,'clear_exit_between_coarse_steps_keeps_existing_budget')
check(attrs.PunchCameraMaxEscapeStep<=2.65,'gap_control_never_hides_emergency_distance')
print('PASS '..count)
`,
  freshPhysicalSample: `${common}
local unresolvedSafetyFrames=0
local unresolvedSafetySamples={}
${block('\t\tlocal function sampleCamera(settledSample)', '\n\t\t\tlocal cameraPosition')}
return unresolvedSafetyFrames
end
attrs.PunchCameraSafetyUnresolved=true
blocked=function() return false end
check(sampleCamera()==0,'fresh_clear_physical_pose_does_not_replay_stale_guard_los_flag')
attrs.PunchCameraSafetyUnresolved=false
blocked=function() return true end
check(sampleCamera()==1,'fresh_physical_penetration_is_counted_despite_previous_clear_flag')
print('PASS '..count)
`,
  overlapCollection: `${common}
local localDebrisFolder,companionsFolder={},{}
local OverlapParams={new=function() return {} end}
Enum.RaycastFilterType={Exclude='Exclude'}
local function part(collides,transparency) return {CanCollide=collides,Transparency=transparency,IsA=function() return true end} end
local solid,egg,invisible=part(true,0),part(false,0),part(true,1)
local queried={egg,invisible}
function workspace:GetPartBoundsInBox() return queried end
${block('shared.PunchWallCameraPositionBlocked = function', '\nlocal function cameraCharacterTarget')}
check(shared.PunchWallCameraPositionBlocked(Vector3.zero,character)==false,'query_only_egg_and_transparent_part_do_not_count_as_physical')
check(select('#',shared.PunchWallCameraPositionBlocked(Vector3.zero,character))==1,'ordinary_clear_predicate_has_single_return_value')
queried={egg,solid,invisible}
check(shared.PunchWallCameraPositionBlocked(Vector3.zero,character)==true,'opaque_collidable_part_is_physical')
local hit,parts=shared.PunchWallCameraPositionBlocked(Vector3.zero,character,true)
check(hit and #parts==1 and parts[1]==solid,'analytic_collection_uses_same_physical_filter')
check(select('#',shared.PunchWallCameraPositionBlocked(Vector3.zero,character))==1,'ordinary_blocked_predicate_has_single_return_value')
print('PASS '..count)
`,
};
fixtures.boundsTransition = `${guardSetup}
lastPunchActionAt=0
player.CameraMinZoomDistance=2 player.CameraMaxZoomDistance=80
pose(0,0,30.1643219) update(1/60)
check(math.abs(attrs.PunchCameraUserOrbitDistance-30.1643219)<.00001,'prior_selected_radius_is_observed')
camera.CameraType='Scriptable' pose(18,12,18)
local scriptPosition=camera.CFrame.Position local scriptFocus=camera.Focus.Position
player.CameraMinZoomDistance=12 player.CameraMaxZoomDistance=12
update(1/60) RunService.PostSimulation:Fire(1/60)
check(camera.CFrame.Position==scriptPosition and camera.Focus.Position==scriptFocus,'zoom_bounds_do_not_mutate_scriptable_owner')
camera.CameraType='Custom' pose(0,0,12) update(1/60)
check(math.abs(camera.CFrame.Position.Magnitude-12)<.00001,'new_zoom_bounds_replace_stale_selected_radius')
check(attrs.PunchCameraUserOrbitDistance==12 and attrs.PunchCameraScriptableBypass==false,'custom_radius_and_bypass_report_current_owner')
rootPart.Position=Vector3.new(63,0,0) pose(63,0,12) update(1/60)
check(math.abs((camera.CFrame.Position-rootPart.Position).Magnitude-12)<.00001,'teleport_preserves_new_bounded_orbit')
player.CameraMinZoomDistance=2 player.CameraMaxZoomDistance=80
pose(63,0,12) update(1/60)
check(math.abs((camera.CFrame.Position-rootPart.Position).Magnitude-12)<.00001,'widening_zoom_bounds_does_not_restore_old_radius')
player.CameraMinZoomDistance=4 player.CameraMaxZoomDistance=14
UserInputService.InputChanged:Fire({UserInputType=Enum.UserInputType.MouseWheel,Position=Vector3.new(0,0,-100)})
update(1/60)
check(attrs.PunchCameraUserOrbitDistance==14,'wheel_respects_current_maximum_zoom')
UserInputService.TouchPinch:Fire(nil,1,nil,Enum.UserInputState.Begin)
UserInputService.TouchPinch:Fire(nil,100,nil,Enum.UserInputState.Change)
update(1/60)
check(attrs.PunchCameraUserOrbitDistance==4,'pinch_respects_current_minimum_zoom')
print('PASS '..count)
`;
fixtures.postSimulationOrdering = `${guardSetup}${orientedWorld}
local origin=Vector3.new(-2.000030517578125,7.214212417602539,-184.6427001953125)
pose(origin.X,origin.Y,origin.Z) update(1/60)
blocks={testBlock('DepthBlock_L038_C07_R03',Vector3.new(-2.09546661,7.03004837,-185.077042),{
 Vector3.new(.720844448,-.693060577,-.00710370345),
 Vector3.new(.692197204,.719348729,.0583141856),
 Vector3.new(.0353052169,.0469526164,-.998273015)})}
check(blocked(origin),'recorded_falling_block_overlaps_previous_camera_box')
now+=.05
-- Documented deferred order: physics -> PostSimulation -> task.wait -> Heartbeat.
RunService.PostSimulation:Fire(1/60)
check(not blocked(camera.CFrame.Position),'recorded_overlap_is_clear_before_waiting_script_resumes')
check((camera.CFrame.Position-origin).Magnitude<=2.65,'recorded_overlap_egress_keeps_existing_actual_bound')
local repaired=camera.CFrame.Position
RunService.Heartbeat:Fire(1/60)
check((camera.CFrame.Position-repaired).Magnitude<.00001,'fresh_heartbeat_does_not_repeat_postsimulation_correction')
check(attrs.PunchCameraLastGuardPhase=='postsimulation-overlap','recorded_physics_response_reports_owning_phase')
blocks={} local previous=camera.CFrame.Position
local lastGuard=attrs.PunchCameraLastGuardAt now+=.01
RunService.PostSimulation:Fire(1/60)
check((camera.CFrame.Position-previous).Magnitude<.00001,'clear_postsimulation_does_not_advance_camera_follow')
check(attrs.PunchCameraLastGuardAt==lastGuard,'clear_postsimulation_does_not_run_ordinary_guard')
print('PASS '..count)
`;
fixtures.unresolvedDiagnostics = `${common}
local unresolvedSafetyFrames=0
local unresolvedSafetySamples={}
local currentPunch=11
attrs.PunchCameraLastGuardPhase='postsimulation-overlap'
attrs.PunchCameraLastGuardAt=99.9
local parts={}
for index=1,3 do table.insert(parts,{Size=Vector3.new(4,4,4),CFrame=CFrame.new(index,0,0),AssemblyLinearVelocity=Vector3.new(0,-7,0),
 GetFullName=function() return 'FallingBlock'..index end,GetAttribute=function() return true end}) end
shared.PunchWallCameraPositionBlocked=function(_,_,collect) return true,collect and parts or nil end
${block('\t\tlocal function sampleCamera(settledSample)', '\n\t\t\tlocal cameraPosition')}
return unresolvedSafetyFrames
end
for _=1,8 do sampleCamera() end
check(unresolvedSafetyFrames==8,'bounded_diagnostics_do_not_cap_physical_failure_count')
check(#unresolvedSafetySamples==4,'unresolved_sample_storage_is_bounded')
check(#unresolvedSafetySamples[1].parts==2 and unresolvedSafetySamples[1].overlapCount==3,'part_detail_is_bounded_without_hiding_overlap_count')
check(unresolvedSafetySamples[1].physicalBoxSize==.55 and unresolvedSafetySamples[1].punch==11,'unresolved_diagnostic_uses_actual_safety_box_and_punch')
check(unresolvedSafetySamples[1].guardPhase=='postsimulation-overlap' and math.abs(unresolvedSafetySamples[1].guardAge-.1)<.00001,'unresolved_diagnostic_attributes_last_guard_phase_and_age')
print('PASS '..count)
`;
fixtures.releaseNoPublicationDiagnostics = `${common.replace('IsStudio=function() return true end','IsStudio=function() return false end')}${guard}
local update=bound.PunchWallCameraGeometryGuard
blocked=function(p) return p.Magnitude<.2 end
pose(0,0,0) update(1/60)
check(not blocked(camera.CFrame.Position),'published_game_still_repairs_physical_overlap')
check(shared.PunchWallCameraLastPublication==nil and shared.PunchWallCameraMaxCyclePublication==nil,'published_game_does_not_allocate_studio_publication_records')
print('PASS '..count)
`;
fixtures.publicationDiagnostics = `${guardSetup}
pose(0,0,0) update(1/60)
blocked=function(p) return (p-Vector3.zero).Magnitude<.2 end
RunService.PostSimulation:Fire(1/60)
local first=camera.CFrame.Position local firstTravel=first.Magnitude
blocked=function(p) return (p-first).Magnitude<.2 end
RunService.PostSimulation:Fire(1/60)
local secondTravel=(camera.CFrame.Position-first).Magnitude
check(math.abs(attrs.PunchCameraMaxPublishedTravelPerCycle-firstTravel-secondTravel)<.00001,'multiple_guard_responses_publish_actual_cumulative_travel')
check(attrs.PunchCameraMaxPublishedWritesPerCycle==2,'multiple_guard_responses_publish_actual_write_count')
check(math.abs(attrs.PunchCameraMaxEscapeTravelPerCycle-firstTravel-secondTravel)<.00001,'multiple_escape_responses_are_not_hidden_by_per_call_maximum')
check(shared.PunchWallCameraLastPublication.phase=='postsimulation-overlap' and shared.PunchWallCameraLastPublication.kind=='escape','last_publication_attributes_actual_phase_and_reason')
check(shared.PunchWallCameraMaxCyclePublication.cycleWrites==2,'bounded_max_cycle_record_retains_actual_largest_cycle')
blocked=function() return false end
bound.PunchWallCameraGeometryGuard(1/60)
check(shared.PunchWallCameraMaxCyclePublication.cycleWrites==2,'new_render_cycle_does_not_erase_largest_record')
print('PASS '..count)
`;
// Execute the real radial resolver together with the complete guard. The LOS
// scene models an edge around the cached pose; it is not a captured live wall.
const settleSetup = common
 .replace('vm.__add=', 'vm.__unm=function(a)return a*-1 end\nvm.__add=')
 .replace("if k=='Rotation'", "if k=='RightVector' then return Vector3.new(math.cos(a.Yaw),0,math.sin(a.Yaw)) end\n if k=='Rotation'")
 .replace('local rootPart={Position=Vector3.zero}', "local rootPart={Position=Vector3.zero,CFrame=CFrame.new(),IsA=function(_,k)return k=='BasePart'end}")
 .replace('local function resolveClearCameraPose(cf,focus,c) return resolver(cf,focus,c) end','')
 + block('local function resolveClearCameraPose(desiredCFrame','\nlocal lastPunchCameraRenderAt') + guard + `
local update=bound.PunchWallCameraGeometryGuard
lastPunchActionAt=0 pose(0,0,12)update(1/60)
attrs.PunchCameraFollowActive=true update(1/60)
attrs.PunchCameraFollowActive=false
occluded=function(p)return p.Z<12.02 and math.abs(p.X)<3 end
`;
fixtures.settleEdge = `${settleSetup}
local arrived=false local previous=camera.CFrame.Position local steps=0
for i=1,81 do
 now+=.05 pose(0,0,12.026091575622558)update(.05)steps=i
 check(not blocked(camera.CFrame.Position) and not occluded(camera.CFrame.Position),'recovery_publication_is_physical_and_LOS_clear')
 check((camera.CFrame.Position-previous).Magnitude<=24*.05+.00001,'actual_recovery_publications_keep_original_correction_bound')
 previous=camera.CFrame.Position
 if attrs.PunchCameraHandoffActive==false then arrived=true break end
end
check(arrived,'valid_native_origin_and_axis_waypoint_complete_real_handoff_before_timeout')
check(math.abs(camera.CFrame.Position.Magnitude-12)<.001,'handoff_completes_only_at_original_exact_radius')
check(camera.CFrame.Yaw==.7 and math.abs((camera.CFrame.Position-camera.Focus.Position).Magnitude-12)<.001,'recovery_waypoints_preserve_camera_rotation_and_focus_distance')
check(steps>1 and steps<81,'edge_recovery_requires_bounded_progress_without_timeout_acceptance')
check(attrs.PunchCameraMaxCorrectionStep<=2.4 and (attrs.PunchCameraMaxEscapeStep or 0)<=2.65,'ordinary_and_escape_metrics_keep_original_gates')
if shared.PunchWallCameraLastRecovery then
 local d=shared.PunchWallCameraLastRecovery
 check(d.handoffRecovery==false and d.remaining<.001 and d.raw and d.cache and d.origin and d.requested and d.candidate and d.published,'final_recovery_diagnostics_expose_all_pose_stages')
end
occluded=function()return false end now+=.05 pose(0,0,12.026091575622558)update(.05)
check(attrs.PunchCameraHandoffActive==false and math.abs(camera.CFrame.Position.Magnitude-12)<.08,'released_native_camera_keeps_existing_regular_zoom_tolerance')
print('PASS '..count)
`;
fixtures.teleportHandoffMarker = `${settleSetup}
-- Isolate marker ownership with no available recovery path before teleport.
occluded=function()return true end
now+=.05 pose(0,0,12.026091575622558)update(.05)
check(attrs.PunchCameraHandoffActive==true,'control_enters_real_handoff_before_teleport')
occluded=function()return false end rootPart.Position=Vector3.new(0,0,40)
now+=.05 pose(0,0,52)update(.05)
check(attrs.PunchCameraTeleportRebaseCount==1,'control_takes_successful_teleport_rebase')
check(attrs.PunchCameraHandoffActive==false,'successful_rebase_synchronizes_public_handoff_marker')
check(math.abs((camera.CFrame.Position-rootPart.Position).Magnitude-12)<.001,'teleport_keeps_exact_selected_radius')
if shared.PunchWallCameraLastRecovery then local d=shared.PunchWallCameraLastRecovery
 check(d.reason=='teleport-rebase' and d.teleportRebaseCount==1 and not d.handoffRecovery and not d.handoffAttribute,'teleport_diagnostics_distinguish_internal_and_public_state')end
for i=1,81 do now+=.05 pose(0,0,52)update(.05)end
check(attrs.PunchCameraHandoffActive==false,'teleport_marker_stays_released_after_original_timeout_window')
print('PASS '..count)
`;
fixtures.exactHandoffArrival = `${guardSetup}
seed()pose(0,0,0)update(.01)attrs.PunchCameraFollowActive=false
pose(.05,0,0)update(.0002)
check(attrs.PunchCameraHandoffActive==true,'sub_point_zero_eight_error_does_not_clear_original_arrival_gate')
check(camera.CFrame.Position.X<.005,'small_frame_keeps_original_response_budget')
pose(.05,0,0)update(.05)
check(attrs.PunchCameraHandoffActive==false and math.abs(camera.CFrame.Position.X-.05)<.001,'exact_endpoint_releases_handoff')
print('PASS '..count)
`;
fixtures.rawOriginControls = `${settleSetup}
local function restart(rawZ,physical,los,active)
 blocked=function()return false end occluded=function()return false end
 attrs.PunchCameraFollowActive=false shared.PunchWallResetCameraGeometryGuard(character)
 pose(0,0,12)update(1/60)attrs.PunchCameraFollowActive=true update(1/60)
 attrs.PunchCameraFollowActive=active==true blocked=physical occluded=los
 now+=.05 pose(0,0,rawZ)update(.05)
 return shared.PunchWallCameraLastRecovery
end
local clear=function()return false end
local edge=function(p)return p.Z<12.2 and math.abs(p.X)<3 end
local d=restart(12.4,function(p)return p.Z>12.12 and p.Z<12.24 end,edge)
check(d.reason:find('cached%-recovery/')~=nil and shared.PunchWallHeartbeatLastClearCFrame.Position.Z==12,'physical_barrier_prevents_native_origin_adoption')
check(d.rawBlocked==false and d.cacheBlocked==true,'barrier_control_distinguishes_safe_endpoints_from_unsafe_route')
d=restart(12.4,clear,function(p)return p.Z<12.5 and math.abs(p.X)<3 end)
check(d.reason:find('cached%-recovery/')~=nil and d.rawBlocked==true,'LOS_blocked_raw_pose_never_becomes_recovery_origin')
d=restart(14.4,clear,edge)
check(d.reason:find('cached%-recovery/')~=nil and shared.PunchWallHeartbeatLastClearCFrame.Position.Z==12,'distant_native_pose_does_not_bypass_local_recovery_budget')
d=restart(12.4,clear,clear)
check(d.reason:find('cached%-recovery/')~=nil and d.cacheBlocked==false,'valid_cached_origin_remains_owned_by_existing_limiter')
d=restart(12.4,clear,edge,true)
check(d.reason:find('cached%-recovery/')~=nil and d.activeFollow==true,'active_punch_follow_does_not_adopt_native_recovery_origin')
d=restart(12.4,function(p)return p.Z>12.12 and p.Z<12.24 end,edge)
local first=shared.PunchWallCameraFirstStalledRecovery
for i=1,100 do now+=.05 pose(0,0,12.4)update(.05)end
check(first and shared.PunchWallCameraFirstStalledRecovery==first,'first_stall_diagnostic_remains_bounded_and_stable')
check(shared.PunchWallCameraLastRecovery and shared.PunchWallCameraMaxRemainingRecovery,'last_and_max_remaining_diagnostics_are_available')
shared.PunchWallResetCameraGeometryGuard(character)
check(shared.PunchWallCameraLastRecovery==nil and shared.PunchWallCameraFirstStalledRecovery==nil and shared.PunchWallCameraMaxRemainingRecovery==nil,'respawn_reset_clears_all_recovery_diagnostics')
print('PASS '..count)
`;
fixtures.releaseNoRecoveryDiagnostics = `${settleSetup.replace('IsStudio=function() return true end','IsStudio=function() return false end')}
now+=.05 pose(0,0,12.026091575622558)update(.05)
check(shared.PunchWallCameraLastRecovery==nil and shared.PunchWallCameraFirstStalledRecovery==nil and shared.PunchWallCameraMaxRemainingRecovery==nil,'published_game_does_not_allocate_recovery_records')
print('PASS '..count)
`;
const settleFailures = {
 settleEdge:'valid_native_origin_and_axis_waypoint_complete_real_handoff_before_timeout',
 teleportHandoffMarker:'successful_rebase_synchronizes_public_handoff_marker',
};
if (!baseline) {
  const visibilityObserver = block('\t\tlocal visibilityDiagnostics = ', '\n\t\tgui:SetAttribute("PunchCameraMaxAppliedStep", 0)');
  fixtures.visibilityObservation = `${common}
local punchCount=18 local currentPunch=1 local head={Position=Vector3.new(0,2,0)}
local freshRayBlocked=true local rayCalls=0
local part={Name='OpaqueBlock',CanQuery=true,CanCollide=true,CFrame=CFrame.new(0,1,3),Size=Vector3.new(4,4,4),AssemblyLinearVelocity=Vector3.new(0,-8,0),
 GetFullName=function()return 'Workspace.PunchWallRPG.Depth Blocks.OpaqueBlock'end,GetAttribute=function(_,key)return key=='StructuralFalling'end}
local function cameraLineOfSightBlocked()rayCalls+=1 return freshRayBlocked,freshRayBlocked and part or nil end
${visibilityObserver}
attrs.PunchCameraFollowActive=true attrs.PunchCameraLastGuardAt=99.95 attrs.PunchCameraLastGuardPhase='render'
shared.PunchWallCameraLastRecovery={publishedBlocked=false,reason='cached-recovery/direct',requested='0,0,12',published='0,0,12',rootDelta='0,0,-10'}
local original=camera.CFrame
recordVisibilityObservation(true,part,true,true)
local first=visibilityDiagnostics.stages[1]
check(first.headRayBlocked and first.bodyRayBlocked and first.guardPublishedBlocked==false,'fresh_sample_LOS_is_distinguished_from_prior_guard_clearance')
check(first.part==part:GetFullName() and first.canQuery and first.canCollide and first.falling and not first.detached,'actual_obscurer_properties_are_retained')
check(first.phase=='follow' and math.abs(first.guardAge-.05)<.00001 and first.guardRootDelta=='0,0,-10','sample_keeps_actual_phase_age_and_root_motion')
check(rayCalls==2 and camera.CFrame==original,'diagnostic_queries_do_not_move_camera')
freshRayBlocked=false part.CanQuery=false
recordVisibilityObservation(true,part,true,true)
check(visibilityDiagnostics.phases.follow.rayMismatch==1,'query_ineligible_visual_obstruction_is_counted_without_reclassifying_clear')
recordVisibilityObservation(false,nil,true,true)
check(rayCalls==4 and obscuredRun==0,'clear_sample_does_not_add_unneeded_diagnostic_rays')
for punch=1,18 do currentPunch=punch recordVisibilityObservation(true,part,true,true) end
check(#visibilityDiagnostics.stages==3 and visibilityDiagnostics.stages[1]==first,'three_stage_records_are_bounded_and_first_record_is_stable')
check(visibilityDiagnostics.stages[2].punch==7 and visibilityDiagnostics.stages[3].punch==13 and visibilityDiagnostics.last.punch==18,'stage_and_last_records_show_actual_run_progression')
check(visibilityDiagnostics.longestObscuredRun==18 and visibilityDiagnostics.phases.follow.samples==21 and visibilityDiagnostics.phases.follow.obscured==20,'diagnostic_storage_cap_never_caps_failure_counters')
attrs.PunchCameraFollowActive=false attrs.PunchCameraHandoffActive=true recordVisibilityObservation(false,nil,true,true)
attrs.PunchCameraHandoffActive=false attrs.PunchCameraGeometryClamped=true recordVisibilityObservation(false,nil,true,true)
attrs.PunchCameraGeometryClamped=false recordVisibilityObservation(false,nil,true,true)
check(visibilityDiagnostics.phases.handoff.samples==1 and visibilityDiagnostics.phases.geometry.samples==1 and visibilityDiagnostics.phases.native.samples==1,'all_four_actual_camera_states_are_counted')
print('PASS '..count)
`;
  const compact = flowCode.slice(0, flowCode.indexOf('\nlocal H='));
  assert(compact.includes('local function compactCameraResult(result)'), 'Missing bounded flow result producer');
  fixtures.compactVisibilityResult = `${common}${compact}
local huge={sample=string.rep('large diagnostics',1000)}
local result={valid=false,visualValid=false,clearRatio=.49390243902439026,inside=0,selectedDistance=23.26280403137207,
 configuredOrbit=23.26280403137207,settledSamples=5,settledClearRatio=1,settledReadableRatio=1,
 largestEscape=huge,maxRemainingRecovery=huge,visualFailureReasons={'clear_visibility'},visibilityPhases={follow={samples=10,obscured=8}}}
local compact=compactCameraResult(result)
check(compact.valid==false and compact.visualValid==false and compact.clearRatio==result.clearRatio,'compact_evidence_retains_failed_acceptance_and_exact_measurements')
check(compact.selectedDistance==result.selectedDistance and compact.configuredOrbit==result.configuredOrbit and compact.inside==0,'compact_evidence_never_replaces_selected_zoom_or_safety')
check(compact.largestEscape==nil and compact.maxRemainingRecovery==nil,'bulky_nested_diagnostics_are_paged_out_of_primary_result')
check(compact.visualFailureReasons==result.visualFailureReasons and compact.visibilityPhases==result.visibilityPhases,'compact_evidence_keeps_failure_reason_and_phase_counts')
check(compactCameraResult(nil).valid==false,'missing_metrics_fail_closed')
print('PASS '..count)
`;
  const originalFlow = JSON.parse(spawnSync('git', ['show', '532e03c:work/automation/flows/camera-long-tunnel-regression.json'], {cwd: root, encoding: 'utf8'}).stdout);
  const originalStep = originalFlow.steps.find(item => item.label === 'sample and freshly verify eighteen high-power tunnel punches');
  const currentStep = flow.steps.find(item => item.label === originalStep.label);
  assert.deepEqual(currentStep.expectRegex, originalStep.expectRegex, 'Preserve every original long-tunnel acceptance expression');
  assert.equal(flow.steps.length, originalFlow.steps.length, 'Preserve ordinary long-tunnel sequence');
  for (let index=0; index<flow.steps.length; index++) {
    if (flow.steps[index].label!==originalStep.label) assert.deepEqual(flow.steps[index],originalFlow.steps[index]);
  }
  assert.deepEqual(flow.cleanup.slice(-originalFlow.cleanup.length),originalFlow.cleanup,'Keep original stop cleanup after diagnostic reads');
  assert.equal(flow.cleanup.length-originalFlow.cleanup.length,4,'Exactly four bounded failure-detail pages');
  for(const item of flow.cleanup.slice(0,4)) {
    assert(item.saveAs && item.allowError===true && item.args.datamodel_type==='Client' && item.args.code.includes("#encoded<3900"),'Failure details must be bounded and must not prevent stop cleanup');
  }
}
const expectedFailures = {
  limiter: "limited_pose_physically_clear", sweep: "clear_endpoint_does_not_cross_thin_wall",
  fallback: "blocked_baseline_is_never_published", final: "final_physical_check_precedes_publish",
  lifecycle: "new_character_does_not_recover_toward_old_cache", occlusion: "late_invisicam_updates_policy",
  respawn: "respawn_clears_persistent_follow_flags",
};
const losFailures = {
  losLimiter: "limited_pose_has_clear_line_of_sight",
  losFinal: "final_los_check_precedes_publish",
  losFallback: "occluded_cache_and_baseline_never_published",
  lowFpsRootFollow: "low_fps_root_follow_preserves_requested_orbit",
  rootCarryLos: "carried_pose_keeps_current_character_line_of_sight",
  clearPartialRecovery: "verified_partial_recovery_does_not_stall_with_unavailable_far_endpoint",
};
const runtimeFailures = {
  overlapRecovery: 'falling_block_overlap_has_clear_published_egress',
  heartbeatOverlap: 'physics_overlap_is_repaired_before_next_render',
  overlapWithoutHistory: 'blocked_raw_camera_without_usable_cache_has_validated_egress',
  selectedOrbitSetup: 'automation_initial_pose_preserves_actual_selected_orbit',
};
const faceFailures = {
  orientedFaceExit: 'rotated_block_uses_near_face_exit_within_existing_budget',
  physicalVersusLos: 'opaque_query_only_egg_is_not_reported_as_physical_penetration',
  coarseGap: 'clear_exit_between_coarse_steps_keeps_existing_budget',
  freshPhysicalSample: 'fresh_clear_physical_pose_does_not_replay_stale_guard_los_flag',
};
const finalFailures = {
 boundsTransition:'new_zoom_bounds_replace_stale_selected_radius',
 postSimulationOrdering:'recorded_overlap_is_clear_before_waiting_script_resumes',
};
const temp = fs.mkdtempSync(path.join(tempRoot, "smash-camera-guard-contract-"));
const results = {};
const mutations = {};
const generated = [];
const compiled = [];
try {
  for (const [name, fixture] of Object.entries(fixtures)) {
    if (settleBaseline && !(name in settleFailures)) continue;
    if (baseline && !settleBaseline && name in settleFailures) continue;
    if (baseline && ['exactHandoffArrival','rawOriginControls','releaseNoRecoveryDiagnostics'].includes(name)) continue;
    if (finalBaseline && !(name in finalFailures)) continue;
    if (faceBaseline && !(name in faceFailures)) continue;
    if (runtimeBaseline && !(name in runtimeFailures)) continue;
    if (baseline && !settleBaseline && !losBaseline && !runtimeBaseline && !faceBaseline && !finalBaseline && !(name in expectedFailures)) continue;
    if (baseline && !finalBaseline && ['boundsTransition','postSimulationOrdering','publicationDiagnostics','unresolvedDiagnostics','releaseNoPublicationDiagnostics'].includes(name)) continue;
    if (losBaseline && ['overlapRecovery','heartbeatOverlap','overlapWithoutHistory','enclosingObject','overlapControls','unavailableSafety','selectedOrbitSetup','runtimeAcceptance'].includes(name)) continue;
    if (losBaseline && ['orientedFaceExit','compoundFaceExit','physicalVersusLos','lateScriptableOwner','coarseGap','freshPhysicalSample','overlapCollection'].includes(name)) continue;
    const file = path.join(temp, `${name}.luau`);
    fs.writeFileSync(file, fixture);
    generated.push(file);
    const result = spawnSync(luau, [file], { encoding: "utf8", timeout: 15000 });
    const output = `${result.stdout || ""}${result.stderr || ""}`;
    const expectedFailure = baseline && (settleBaseline ? settleFailures[name] : finalBaseline ? finalFailures[name] : faceBaseline ? faceFailures[name] : runtimeBaseline ? runtimeFailures[name] : losBaseline ? losFailures[name] : expectedFailures[name]);
    if (expectedFailure) {
      assert.ok(result.status !== 0 && output.includes(expectedFailure), `${name}: expected baseline failure ${expectedFailure}: ${output}`);
      results[name] = { reproduced: expectedFailure };
    } else {
      assert.equal(result.status, 0, `${name}: ${output}`);
      results[name] = { passed: Number(output.match(/PASS (\d+)/)?.[1] || 0) };
    }
  }
  if (!baseline) {
    const mutationsToCheck = [
      ['conflate_prior_guard_and_current_LOS','visibilityObservation',text=>text.replace('headRayBlocked = headBlocked, bodyRayBlocked = bodyBlocked','headRayBlocked = recovery and recovery.publishedBlocked, bodyRayBlocked = bodyBlocked'),'fresh_sample_LOS_is_distinguished_from_prior_guard_clearance'],
      ['unbound_visibility_stage_records','visibilityObservation',text=>text.replace('visibilityDiagnostics.stages[stage] = visibilityDiagnostics.stages[stage] or sample','visibilityDiagnostics.stages[currentPunch] = visibilityDiagnostics.stages[currentPunch] or sample'),'three_stage_records_are_bounded_and_first_record_is_stable'],
      ['mask_visibility_failure_in_summary','compactVisibilityResult',text=>text.replace('summary[key]=value','summary[key]=key=="visualValid" and true or value'),'compact_evidence_retains_failed_acceptance_and_exact_measurements'],
      ['ignore_valid_native_recovery_origin','settleEdge',text=>text.replace('local adoptedRawOrigin = not activeFollow','local adoptedRawOrigin = false'),'valid_native_origin_and_axis_waypoint_complete_real_handoff_before_timeout'],
      ['omit_axis_waypoints','settleEdge',text=>text.replace('Vector3.new(displacement.X, 0, 0), Vector3.new(0, 0, displacement.Z)','Vector3.zero, Vector3.zero'),'valid_native_origin_and_axis_waypoint_complete_real_handoff_before_timeout'],
      ['ignore_origin_adoption_budget','settleEdge',text=>text.replace('correctionBudget = math.max(0, maxStep - rawOffset.Magnitude)','correctionBudget = maxStep'),'actual_recovery_publications_keep_original_correction_bound'],
      ['leave_stale_rebase_handoff_marker','teleportHandoffMarker',text=>text.replace('recoveringFromFollowHandoff = false\n\t\t\t\t\tgui:SetAttribute("PunchCameraHandoffActive", false)','recoveringFromFollowHandoff = false'),'successful_rebase_synchronizes_public_handoff_marker'],
      ['loosen_exact_handoff_arrival','exactHandoffArrival',text=>text.replace('local arrived = limitedCFrame and (desiredPosition - requestedPosition).Magnitude < 0.001','local arrived = limitedCFrame and (desiredPosition - requestedPosition).Magnitude < 0.08'),'sub_point_zero_eight_error_does_not_clear_original_arrival_gate'],
      ['skip_raw_origin_physical_sweep','rawOriginControls',text=>text.replace('and clearTranslationStep(followOrigin, rawOffset, character)','and true'),'physical_barrier_prevents_native_origin_adoption'],
      ['accept_LOS_blocked_native_origin','rawOriginControls',text=>text.replace('and not cameraPoseBlocked(rawCFrame, character)','and true'),'LOS_blocked_raw_pose_never_becomes_recovery_origin'],
      ['adopt_distant_native_origin','rawOriginControls',text=>text.replace('and rawOffset.Magnitude <= maxStep','and true'),'distant_native_pose_does_not_bypass_local_recovery_budget'],
      ['allocate_release_recovery_records','releaseNoRecoveryDiagnostics',text=>text.replace('local function recordRecoveryState(raw, cached, requested, origin, candidate, rootDelta, reason)\n\t\tif not recordCameraDiagnostics then return end','local function recordRecoveryState(raw, cached, requested, origin, candidate, rootDelta, reason)\n\t\tif false then return end'),'published_game_does_not_allocate_recovery_records'],
      ['omit_face_candidates','orientedFaceExit',text=>text.replace('if distance > 0 then addCandidate(normal * distance, "face") end','if false then addCandidate(normal * distance, "face") end'),'rotated_block_uses_near_face_exit_within_existing_budget'],
      ['undersized_camera_support','orientedFaceExit',text=>text.replace('local support = 0.275 *','local support = 0.05 *'),'rotated_block_uses_near_face_exit_within_existing_budget'],
      ['skip_compound_endpoint_and_sweep','compoundFaceExit',text=>text.replace('if not shared.PunchWallCameraPositionBlocked(candidate.cframe.Position, character)\n\t\t\t\tand clearTranslationStep(origin, candidate.step, character, true) then','if true then'),'compound_egress_checks_entire_overlap_set'],
      ['require_clear_los_before_physical_exit','compoundFaceExit',text=>text.replace('selected = selected or nearestPhysical','selected = selected').replace('if maximumDistance > 2.65 then\n\t\t\t\t\tselected = candidate\n\t\t\t\t\tbreak\n\t\t\t\tend','if false then selected = candidate break end'),'compound_egress_stays_within_existing_budget'],
      ['conflate_los_with_physical_failure','physicalVersusLos',text=>text.replace('gui:SetAttribute("PunchCameraSafetyUnresolved", physicallyBlocked)','gui:SetAttribute("PunchCameraSafetyUnresolved", cameraPoseBlocked(camera.CFrame, character))'),'opaque_query_only_egg_is_not_reported_as_physical_penetration'],
      ['steal_late_scriptable_owner','lateScriptableOwner',text=>text.replace('if camera.CameraType == Enum.CameraType.Scriptable then','if camera.CameraType == Enum.CameraType.Scriptable and not activePunchCamera then'),'new_scriptable_position_preserved'],
      ['allow_exit_path_reentry','sweep',text=>text.replace('if leftOverlap then return false end','if false then return false end'),'clear_endpoint_does_not_cross_thin_wall'],
      ['sample_stale_safety_flag','freshPhysicalSample',text=>text.replace('if shared.PunchWallCameraPositionBlocked(camera.CFrame.Position, character) then','if gui:GetAttribute("PunchCameraSafetyUnresolved") then'),'fresh_clear_physical_pose_does_not_replay_stale_guard_los_flag'],
      ['mask_emergency_escape_distance','enclosingObject',text=>text.replace('local distance = selected.step.Magnitude','local distance = math.min(selected.step.Magnitude, 2.4)'),'exceptional_escape_exceeds_ordinary_gate_visibly_not_silently'],
      ['ignore_current_zoom_bounds','boundsTransition',text=>text.replace('return math.clamp(distance, minimum, maximum)','return distance'),'new_zoom_bounds_replace_stale_selected_radius'],
      ['defer_physical_repair_until_heartbeat','postSimulationOrdering',text=>text.replace('RunService.PostSimulation:Connect(function(deltaTime)','RunService.Heartbeat:Connect(function(deltaTime)'),'recorded_overlap_is_clear_before_waiting_script_resumes'],
      ['run_ordinary_guard_after_physics','postSimulationOrdering',text=>text.replace('if camera and character and camera.CameraType == Enum.CameraType.Custom\n\t\t\tand shared.PunchWallCameraPositionBlocked(camera.CFrame.Position, character) then','if camera and character and camera.CameraType == Enum.CameraType.Custom then'),'clear_postsimulation_does_not_run_ordinary_guard'],
      ['hide_cumulative_publication_distance','publicationDiagnostics',text=>text.replace('cyclePublishedTravel += distance','cyclePublishedTravel = distance'),'multiple_guard_responses_publish_actual_cumulative_travel'],
      ['unbound_unresolved_sample_storage','unresolvedDiagnostics',text=>text.replace('if #unresolvedSafetySamples < 4 then','if true then'),'unresolved_sample_storage_is_bounded'],
      ['allocate_studio_diagnostics_in_published_game','releaseNoPublicationDiagnostics',text=>text.replace('if not recordCameraDiagnostics then return end','if false then return end'),'published_game_does_not_allocate_studio_publication_records'],
    ];
    for (const [name, fixtureName, mutate, expectedFailure] of mutationsToCheck) {
      const fixture = mutate(fixtures[fixtureName]);
      assert.notEqual(fixture, fixtures[fixtureName], `Mutation boundary missing: ${name}`);
      const file = path.join(temp, `mutation-${name}.luau`);
      fs.writeFileSync(file, fixture);
      generated.push(file);
      const result = spawnSync(luau, [file], { encoding: 'utf8', timeout: 15000 });
      const output = `${result.stdout || ''}${result.stderr || ''}`;
      assert.ok(result.status !== 0 && output.includes(expectedFailure), `Mutation survived or failed for wrong reason: ${name}: ${output}`);
      mutations[name] = expectedFailure;
    }
    const chunks = [['complete-client', source], ...flow.steps.flatMap((step, index) => step.tool === 'execute_luau' ? [[`long-tunnel-${index}`, step.args.code]] : []),
      ...flow.cleanup.flatMap((step,index)=>step.tool==='execute_luau'?[[`long-tunnel-cleanup-${index}`,step.args.code]]:[])];
    for (const [name, code] of chunks) {
      const file = path.join(temp, `${name}.luau`);
      fs.writeFileSync(file, code);
      generated.push(file);
      const result = spawnSync(compiler, ['--null', file], { encoding: 'utf8', timeout: 15000 });
      assert.equal(result.status, 0, `BLOCKED ${name} compile: ${result.error || result.stderr || result.stdout}`);
      compiled.push(name);
      if(name==='complete-client')for(const level of [0,2]){
        const optimized=spawnSync(compiler,['--null',`-O${level}`,file],{encoding:'utf8',timeout:15000});
        assert.equal(optimized.status,0,`BLOCKED ${name} O${level} compile: ${optimized.error||optimized.stderr||optimized.stdout}`);
        compiled.push(`${name}-O${level}`);
      }
    }
  }
  console.log(JSON.stringify({ ok: true, mode: baseline ? `baseline ${baseline}` : "current source", luau, results, mutations, compiled }, null, 2));
} finally {
  for (const file of generated) {
    if (fs.existsSync(file)) fs.unlinkSync(file);
  }
  fs.rmdirSync(temp);
}
