#!/usr/bin/env node
// Offline only: actual production world geometry, placement and waypoint policy.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../..');
const read = name => fs.readFileSync(path.join(root, name), 'utf8').replace(/\r/g, '');
const serverPath = 'work/punch-wall-rpg/src/server/PunchWallBootstrap.server.lua';
const server = read(serverPath), client = read('work/punch-wall-rpg/src/client/PunchWallClient.client.lua');
const flow = JSON.parse(read('work/automation/flows/onboarding-waypoint.json'));
const preview = JSON.parse(read('work/punch-wall-rpg/default.project.json')).tree.Workspace.PunchWallRPG['Spawn Pad Preview'];
const seed = flow.steps[2].args.code, near = flow.steps[4].args.code, far = flow.steps[7].args.code;
function slice(text, start, end, include = false) {
  const a = text.indexOf(start), b = text.indexOf(end, a + start.length);
  assert(a >= 0 && b > a, 'BLOCKED: extraction boundary changed: ' + start);
  return text.slice(a, b + (include ? end.length : 0));
}
const facing = slice(seed, 'local function verifySpawnGeometry(', '\nend', true);
const ephemeral = slice(seed, 'local function verifyEphemeralSeed(', '\nend', true);
const waypoint = slice(near, 'local function verifyWaypointState(', '\nend', true);
assert.equal(waypoint, slice(far, 'local function verifyWaypointState(', '\nend', true));
function geometry(text) {
  const spawn = slice(text, 'local spawn = Instance.new("SpawnLocation")', '\nspawn.Parent = root', true);
  const entrance = text.match(/^local courseEntrance = makePart\("Depth Course Entrance".*$/m)?.[0];
  assert(entrance, 'BLOCKED: production entrance creation not found');
  return spawn + '\n' + entrance;
}
const place = server.match(/local position = spawn\.Position \+ Vector3\.new\(0, 4, 0\)\n\s*rootPart\.CFrame = CFrame\.lookAt\([^\n]+/)?.[0];
assert(place, 'BLOCKED: production character placement not found');
const scan = slice(client, '\tif tutorialTarget and tutorialTarget:IsA("BasePart") then', '\n\tlocal nearbyAction =');
const objectiveStart = client.indexOf('statRemote.OnClientEvent:Connect(function(payload)\n\tlocal widgets = shared.PunchWallHUDWidgets');
assert(objectiveStart >= 0);
const objective = slice(client.slice(objectiveStart), '\tlocal tutorial = payload.Tutorial', '\n\tif shared.PunchWallRefreshActionBadges');
const old = spawnSync('git', ['show', `4094e51:${serverPath}`], { cwd: root, encoding: 'utf8', maxBuffer: 4e6 });
assert.equal(old.status, 0, old.stderr);
const checks = {};
function check(name, condition) { assert(condition, name); checks[name] = true; }
check('natural_pose_observed_before_reset_can_reposition_character',
  seed.indexOf('local natural=verifySpawnGeometry(') < seed.indexOf("command:Invoke('Reset')") &&
  !seed.includes(':PivotTo(') && !seed.includes('rootPart.CFrame=') &&
  seed.includes("p.RespawnLocation==spawn") && seed.includes("character:GetAttribute('PunchWallSpawnPlaced')==true") &&
  seed.includes('local reset=verifySpawnGeometry('));
check('reset_is_guarded_and_fresh_tutorial_is_still_required',
  seed.indexOf('verifyEphemeralSeed(p,world,storage)') < seed.indexOf("command:Invoke('Reset')") &&
  seed.includes('result.TutorialStep==1') && flow.steps[2].expectRegex.some(value => value.includes('spawnFacingValid')) &&
  !flow.steps[2].expectRegex.some(value => value.includes('spawnYaw')));
check('real_visible_objective_and_exact_adornee_are_observed', [near, far].every(code =>
  code.includes("hud:WaitForChild('TutorialObjectiveHUD')") && code.includes('targetMatches=w.Adornee==entrance') &&
  code.includes('objectiveVisible=g.Enabled and hud.Visible and card.Visible and text.Visible') &&
  code.includes('valid,reason=pcall(verifyWaypointState,state,') && code.includes('local deadline=os.clock()+4')));
check('near_far_fixture_and_console_cleanup_remain',
  near.includes('verifyWaypointState,state,false') && far.includes('verifyWaypointState,state,true') &&
  flow.steps[5].args.code.includes('target.Position+Vector3.new(0,3,35)') &&
  flow.steps.filter(step => step.type === 'assertNoConsoleErrors').length === 2 &&
  flow.cleanup[0].tool === 'start_stop_play' && flow.cleanup[0].args.is_start === false);

const common = String.raw`
local checks=0
local function check(value,name) checks+=1 assert(value,'ONBOARDING: '..name) end
local function reject(fn,name)local ok=pcall(fn) check(not ok,'reject '..name)end
local vm={} local Vector3={}
function Vector3.new(x,y,z)return setmetatable({X=x,Y=y,Z=z},vm)end
Vector3.zero=Vector3.new(0,0,0)
vm.__add=function(a,b)return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z)end
vm.__sub=function(a,b)return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end
vm.__mul=function(a,b)return Vector3.new(a.X*b,a.Y*b,a.Z*b)end
vm.__index=function(a,k)
 if k=='Magnitude' then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z) end
 if k=='Unit' then return a*(1/a.Magnitude) end
 if k=='Dot' then return function(a,b)return a.X*b.X+a.Y*b.Y+a.Z*b.Z end end
end
local CFrame={}
function CFrame.lookAt(position,target)return {Position=position,LookVector=(target-position).Unit}end
function CFrame.new(position)return {Position=position,LookVector=Vector3.new(0,0,-1)}end
local function part(name,position,size,kind)
 local value={Name=name,Position=position or Vector3.zero,Orientation=Vector3.zero,Size=size or Vector3.new(1,1,1),attributes={},kind=kind or 'Part'}
 function value:IsA(class)return class=='BasePart' or class==self.kind end
 function value:GetAttribute(name)return self.attributes[name]end
 function value:SetAttribute(name,v)self.attributes[name]=v end
 return setmetatable(value,{__index=function(self,key)
  if key=='CFrame' then local angle=math.rad(self.Orientation.Y) return {Position=self.Position,LookVector=Vector3.new(-math.sin(angle),0,-math.cos(angle))} end
 end})
end
local root,interactFolder={},{}
local Instance={new=function(kind)return part('',nil,nil,kind)end}
local Enum={Material={Slate='Slate',SmoothPlastic='SmoothPlastic'}}
local PolishConfig={Palette={HeroCyan={}}}
local Color3={new=function(...)return {...}end}
local function makePart(name,parent,size,position,...)return part(name,position,size)end
local rootPart={}
`;
const previewPosition = preview.$properties.Position;
function program({ geometryCode = geometry(server), facingCode = facing, placeCode = place,
  waypointCode = waypoint, scanCode = scan, ephemeralCode = ephemeral } = {}) {
  return common + '\n' + [facingCode, waypointCode, ephemeralCode, geometryCode, placeCode].join('\n') + `
local natural=verifySpawnGeometry(spawn.CFrame,rootPart.CFrame,courseEntrance.Position,spawn.Size)
check(natural.spawnDot>.999 and natural.characterDot>.999,'actual production spawn and character face entrance')
check((courseEntrance.Position-spawn.Position).Z<0,'actual production course lies forward in negative Z')
local backwards=CFrame.lookAt(spawn.Position,spawn.Position+Vector3.new(0,0,1))
reject(function()verifySpawnGeometry(backwards,rootPart.CFrame,courseEntrance.Position,spawn.Size)end,'backward SpawnLocation')
reject(function()verifySpawnGeometry(spawn.CFrame,backwards,courseEntrance.Position,spawn.Size)end,'backward character')
local sideways=CFrame.lookAt(spawn.Position,spawn.Position+Vector3.new(1,0,0))
reject(function()verifySpawnGeometry(sideways,rootPart.CFrame,courseEntrance.Position,spawn.Size)end,'sideways spawn')
local outside=spawn.Position+Vector3.new(12,4,0)
local outsideFacing=CFrame.lookAt(outside,Vector3.new(courseEntrance.Position.X,outside.Y,courseEntrance.Position.Z))
reject(function()verifySpawnGeometry(spawn.CFrame,outsideFacing,courseEntrance.Position,spawn.Size)end,'character outside runtime spawn')
local tooHigh=spawn.Position+Vector3.new(0,12,0)
reject(function()verifySpawnGeometry(spawn.CFrame,CFrame.new(tooHigh),courseEntrance.Position,spawn.Size)end,'wrong spawn height')
reject(function()verifySpawnGeometry(spawn.CFrame,rootPart.CFrame,spawn.Position,spawn.Size)end,'coincident target')
local preview=CFrame.new(Vector3.new(${previewPosition.join(',')}))
reject(function()verifySpawnGeometry(preview,preview,courseEntrance.Position,spawn.Size)end,'legacy edit preview is not runtime entrance-facing spawn')
local south=Vector3.new(0,4,20) local center=Vector3.new(0,2,0)
local southFrame=CFrame.lookAt(center,Vector3.new(0,2,20))
check(verifySpawnGeometry(southFrame,southFrame,south,spawn.Size).spawnDot>.999,'geometry oracle supports relocated entrance, not fixed yaw zero')

local attrs={} local gui={SetAttribute=function(_,k,v)attrs[k]=v end}
local tutorialWaypoint={} local tutorialWaypointLabel={} local help={}
local tutorialObjectiveText='OBJECTIVE | Punch The Wall'
local function observe(distance,hasTarget,completed)
 local rootPart={Position=courseEntrance.Position+Vector3.new(0,0,distance)}
 local tutorialTarget=hasTarget and courseEntrance or nil
 local payload={Tutorial=hasTarget and {title='Punch The Wall',detail='Follow the arrow and punch a front wall block',target='Depth Course Entrance'} or nil,TutorialStep=1,TutorialCompleted=completed or false}
 local widgets={ObjectiveCard={},ObjectiveText={}}
 ${objective}
 ${scanCode}
 return {targetMatches=tutorialWaypoint.Adornee==courseEntrance,ready=attrs.OnboardingWaypointReady==true,step=attrs.OnboardingObjectiveStep,
  objectiveVisible=widgets.ObjectiveCard.Visible==true,objective=widgets.ObjectiveText.Text or '',distance=math.floor(distance+.5),
  distanceText=tutorialWaypointLabel.Text or '',enabled=tutorialWaypoint.Enabled,contextVisible=false,actionVisible=false}
end
for _,case in ipairs({{7,false},{18,false},{18.49,false},{18.5,true},{19,true},{35,true}})do
 local e=observe(case[1],true,false)
 check(verifyWaypointState(e,case[2]),'actual near/far producer distance '..case[1])
 check(e.enabled==case[2],'actual marker visibility distance '..case[1])
end
reject(function()verifyWaypointState(observe(35,false,false),true)end,'missing actual target')
reject(function()verifyWaypointState(observe(7,true,true),false)end,'completed hidden objective')
local e=observe(7,true,false) e.objectiveVisible=false
reject(function()verifyWaypointState(e,false)end,'hidden objective with correct text')
e=observe(7,true,false) e.actionVisible=true
reject(function()verifyWaypointState(e,false)end,'unrelated near action')
e=observe(7,true,false) e.distanceText='NEXT: PUNCH THE WALL 99 studs'
reject(function()verifyWaypointState(e,false)end,'stale distance label')
e=observe(7,true,false) e.targetMatches=false
reject(function()verifyWaypointState(e,false)end,'same-name wrong target instance')
e=observe(7,true,false) e.step=2
reject(function()verifyWaypointState(e,false)end,'wrong tutorial step')
local player=part('Player') local world=part('World') local storage=part('Storage')
world.attributes={PersistenceMode='EphemeralStudio',PersistenceStudioDefaultEphemeral=true,PersistenceStudioLiveDataOptIn=false}
player.attributes={ProfileReady=true,ProfilePersistenceState='EphemeralStudio',ProfileWritable=false}
check(verifyEphemeralSeed(player,world,storage),'ephemeral seed allowed')
storage.attributes.PunchWallAllowLiveDataStoreAccess=true
reject(function()verifyEphemeralSeed(player,world,storage)end,'live datastore opt in')
storage.attributes.PunchWallAllowLiveDataStoreAccess=nil player.attributes.ProfileWritable=true
reject(function()verifyEphemeralSeed(player,world,storage)end,'writable live profile')
print('ONBOARDING_PASS '..checks)
`;
}
const luau = [process.env.LUAU_COMMAND, ...fs.readdirSync(os.tmpdir()).filter(name => name.startsWith('codex-luau-'))
  .sort().reverse().map(name => path.join(os.tmpdir(), name, process.platform === 'win32' ? 'luau.exe' : 'luau')), 'luau']
  .find(command => command && spawnSync(command, ['--help'], { encoding: 'utf8' }).status === 0);
assert(luau, 'BLOCKED: Luau unavailable');
const compiler = process.env.LUAU_COMPILE_COMMAND || path.join(path.dirname(luau), process.platform === 'win32' ? 'luau-compile.exe' : 'luau-compile');
const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'smash-onboarding-contract-'));
const files = [], negatives = [];
let assertions = 0, compiled = 0;
function execute(name, code) {
  const file = path.join(temp, name + '.luau'); fs.writeFileSync(file, code); files.push(file);
  const compile = spawnSync(compiler, ['--null', file], { encoding: 'utf8' });
  assert.equal(compile.status, 0, 'BLOCKED syntax ' + name + ': ' + compile.stderr);
  const result = spawnSync(luau, [file], { encoding: 'utf8', timeout: 15000 });
  return { status: result.status, text: `${result.stdout || ''}${result.stderr || ''}` };
}
try {
  const positive = execute('actual-world-and-flow', program());
  assert(positive.status === 0 && /ONBOARDING_PASS \d+/.test(positive.text), positive.text);
  assertions = Number(positive.text.match(/ONBOARDING_PASS (\d+)/)[1]);
  const baseline = execute('old-yaw180-world', program({ geometryCode: geometry(old.stdout.replace(/\r/g, '')) }));
  check('actual_old_yaw180_is_rejected_by_entrance_geometry', baseline.status !== 0 && baseline.text.includes('SpawnLocation faces away from the actual entrance'));
  for (const [name, option, from, to, failure] of [
    ['accept_backward_spawn', 'facingCode', 'spawnDot>=.98', 'math.abs(spawnDot)>=.98', 'reject backward SpawnLocation'],
    ['ignore_character_direction', 'facingCode', 'characterDot>=.98', 'true', 'reject backward character'],
    ['ignore_actual_spawn_location', 'facingCode', 'math.abs(offset.X)<=spawnSize.X*.5+.5 and math.abs(offset.Z)<=spawnSize.Z*.5+.5', 'true', 'reject character outside runtime spawn'],
    ['production_character_faces_backwards', 'placeCode', 'Vector3.new(0, 0, -1)', 'Vector3.new(0, 0, 1)', 'natural character faces away'],
    ['hide_far_marker', 'scanCode', 'tutorialWaypoint.Enabled = distance > 18', 'tutorialWaypoint.Enabled = false', 'waypoint visibility does not match'],
    ['accept_hidden_objective', 'waypointCode', 'e.objectiveVisible==true and ', '', 'reject completed hidden objective'],
    ['permit_live_reset', 'ephemeralCode', "storage:GetAttribute('PunchWallAllowLiveDataStoreAccess')~=true", 'true', 'reject live datastore opt in'],
  ]) {
    const originals = { facingCode: facing, placeCode: place, scanCode: scan, waypointCode: waypoint, ephemeralCode: ephemeral };
    const mutation = originals[option].replace(from, to); assert.notEqual(mutation, originals[option], 'mutation did not apply: ' + name);
    const result = execute(name, program({ [option]: mutation }));
    assert(result.status !== 0 && result.text.includes(failure), name + ': ' + result.text);
    negatives.push({ name, status: 'REJECTED' });
  }
  for (const [index, step] of flow.steps.entries()) if (step.tool === 'execute_luau') {
    const file = path.join(temp, 'flow-' + index + '.luau'); fs.writeFileSync(file, step.args.code); files.push(file);
    const result = spawnSync(compiler, ['--null', file], { encoding: 'utf8' });
    assert.equal(result.status, 0, 'flow compile ' + index + ': ' + result.stderr); compiled += 1;
  }
} finally { for (const file of files) fs.unlinkSync(file); fs.rmdirSync(temp); }
console.log(JSON.stringify({ ok: true, assertions, checks, negatives, compiledFlowChunks: compiled,
  runtime: 'BLOCKED_PENDING_COORDINATOR_STUDIO_RUN' }, null, 2));
