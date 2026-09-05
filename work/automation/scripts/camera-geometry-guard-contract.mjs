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
const baselineIndex = process.argv.indexOf(runtimeBaseline ? "--baseline-runtime2" : losBaseline ? "--baseline-los" : "--baseline");
const baseline = baselineIndex < 0 ? null : process.argv[baselineIndex + 1] || (runtimeBaseline ? "781ff4b" : losBaseline ? "ef9b5f8" : "b521dea");
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
local RunService={Heartbeat=signal(),BindToRenderStep=function(_,name,_,cb) bound[name]=cb bindCounts[name]=(bindCounts[name] or 0)+1 end}
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
check(not blocked(camera.CFrame.Position) and camera.CFrame.Position.X>0,'clear_baseline_or_local_egress_remains_available')
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
RunService.Heartbeat:Fire(1/60)
check(not blocked(camera.CFrame.Position),'physics_overlap_is_repaired_before_next_render')
check(attrs.PunchCameraOverlapEscapes==1,'fresh_render_physics_egress_is_measured')
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
 local result={valid=true,visualValid=true,actions=18,inside=0,type='Custom',mode='CustomPreserved',maxCorrectionStep=.4,maxEscapeStep=.7,unresolvedSafetyFrames=0,configuredOrbit=22.62,selectedDistance=22.62,userOrbitDistance=22.62,finishDistance=22.62}
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
};
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
const temp = fs.mkdtempSync(path.join(tempRoot, "smash-camera-guard-contract-"));
const results = {};
const generated = [];
const compiled = [];
try {
  for (const [name, fixture] of Object.entries(fixtures)) {
    if (runtimeBaseline && !(name in runtimeFailures)) continue;
    if (baseline && !losBaseline && !runtimeBaseline && !(name in expectedFailures)) continue;
    if (losBaseline && ['overlapRecovery','heartbeatOverlap','overlapWithoutHistory','enclosingObject','overlapControls','unavailableSafety','selectedOrbitSetup','runtimeAcceptance'].includes(name)) continue;
    const file = path.join(temp, `${name}.luau`);
    fs.writeFileSync(file, fixture);
    generated.push(file);
    const result = spawnSync(luau, [file], { encoding: "utf8", timeout: 15000 });
    const output = `${result.stdout || ""}${result.stderr || ""}`;
    const expectedFailure = baseline && (runtimeBaseline ? runtimeFailures[name] : losBaseline ? losFailures[name] : expectedFailures[name]);
    if (expectedFailure) {
      assert.ok(result.status !== 0 && output.includes(expectedFailure), `${name}: expected baseline failure ${expectedFailure}: ${output}`);
      results[name] = { reproduced: expectedFailure };
    } else {
      assert.equal(result.status, 0, `${name}: ${output}`);
      results[name] = { passed: Number(output.match(/PASS (\d+)/)?.[1] || 0) };
    }
  }
  if (!baseline) {
    const chunks = [['complete-client', source], ...flow.steps.flatMap((step, index) => step.tool === 'execute_luau' ? [[`long-tunnel-${index}`, step.args.code]] : [])];
    for (const [name, code] of chunks) {
      const file = path.join(temp, `${name}.luau`);
      fs.writeFileSync(file, code);
      generated.push(file);
      const result = spawnSync(compiler, ['--null', file], { encoding: 'utf8', timeout: 15000 });
      assert.equal(result.status, 0, `BLOCKED ${name} compile: ${result.error || result.stderr || result.stdout}`);
      compiled.push(name);
    }
  }
  console.log(JSON.stringify({ ok: true, mode: baseline ? `baseline ${baseline}` : "current source", luau, results, compiled }, null, 2));
} finally {
  for (const file of generated) {
    if (fs.existsSync(file)) fs.unlinkSync(file);
  }
  fs.rmdirSync(temp);
}
