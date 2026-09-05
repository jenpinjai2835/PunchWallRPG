import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../..');
const flowPath = 'work/automation/flows/power-scaled-penetration.json';
const sourcePath = 'work/punch-wall-rpg/src/server/PunchWallBootstrap.server.lua';
const flow = JSON.parse(fs.readFileSync(path.join(root, flowPath), 'utf8'));
const source = fs.readFileSync(path.join(root, sourcePath), 'utf8').replace(/\r\n?/g, '\n');
const label = 'high power carves a long server-physics tunnel';
const code = flow.steps.find(step => step.label === label).args.code;
function between(text, from, to) {
  const start = text.indexOf(from), end = text.indexOf(to, start + from.length);
  assert(start >= 0 && end > start, `Missing exact boundary: ${from}`); return text.slice(start, end);
}
const helpers = between(code, 'local function verifyFragmentObservation(s)', '\nlocal H=game:GetService');
const verification = between(helpers, 'local function verifyFragmentObservation(s)', '\nlocal function startFragmentObservation');
const producer = between(source, 'local function spawnDepthBlockFragments(', '\nlocal depthPunch =');
const profile = between(source, 'function depthPunch.PowerProfile(player)', '\nfunction depthPunch.PlanSafeLunge');
const lunge = between(source, 'function depthPunch.Lunge(player, rootPart, profile)', '\nlocal function hitDepthBlock');
let sourceChecks = 0;
const check = (condition, name) => { assert(condition, name); sourceChecks++; };
const original = spawnSync('git', ['show', `6211b00:${flowPath}`], {cwd: root, encoding: 'utf8'});
assert.equal(original.status, 0, original.stderr);
const originalFlow = JSON.parse(original.stdout);
check(flow.steps.length === originalFlow.steps.length, 'Preserve every existing step');
for (let i = 0; i < flow.steps.length; i++) {
  if (flow.steps[i].label !== label) assert.deepEqual(flow.steps[i], originalFlow.steps[i], `Unrelated step changed: ${i}`);
}
assert.deepEqual(flow.cleanup, originalFlow.cleanup, 'Preserve stop-on-failure cleanup'); sourceChecks++;
for (const regex of originalFlow.steps.find(step => step.label === label).expectRegex) {
  check(flow.steps.find(step => step.label === label).expectRegex.includes(regex), `Preserve existing penetration/force gate ${regex}`);
}
check(source.includes('LungeSeconds = 0.42,') && lunge.includes('local state = tween.Completed:Wait()'), 'Actual Lunge completion is a yielding 0.42-second tween');
const punch = between(source, 'function depthPunch.Punch(player, directionName)', '\nlocal boss =');
check(punch.indexOf('local result = hitDepthBlock') < punch.indexOf('local lunge = depthPunch.Lunge'), 'Damage/fragments precede yielding Lunge');
check(source.includes('spawnDepthBlockFragments(block, player,'), 'Actual damage route spawns the reviewed fragments');
check(producer.includes('fragment:ApplyImpulse(launchVelocity * fragment.AssemblyMass)') && producer.includes('fragment:SetAttribute("InitialForwardSpeed", launchVelocity:Dot(outward))'), 'Actual impulse and separate metadata');
check(producer.includes('PhysicalProperties.new(0.1, 0.78, 0.12, 1, 1)') && producer.includes('task.delay(2.25') && producer.includes('fragment.CanCollide = true'), 'Collidable/frictional fragment lifetime covers the late sample');
check(code.indexOf('startFragmentObservation(folder,runService)') < code.indexOf("command:Invoke('PunchRadius')"), 'Observer starts before the yielding punch');

const tempRoot = os.tmpdir();
const candidates = [process.env.LUAU_COMMAND, ...fs.readdirSync(tempRoot).filter(name => name.startsWith('codex-luau-')).sort().reverse()
  .map(name => path.join(tempRoot, name, process.platform === 'win32' ? 'luau.exe' : 'luau')), 'luau'];
const luau = candidates.find(candidate => candidate && spawnSync(candidate, ['--help'], {encoding: 'utf8'}).status === 0);
assert(luau, 'BLOCKED: set LUAU_COMMAND');
const compiler = process.env.LUAU_COMPILE_COMMAND || path.join(path.dirname(luau), process.platform === 'win32' ? 'luau-compile.exe' : 'luau-compile');
const setup = `
local count=0 local function check(v,n) assert(v,n) count+=1 end
local Vector3,vm={},{}
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
Vector3.zero=Vector3.new(0,0,0) Vector3.yAxis=Vector3.new(0,1,0)
local function typeof(v) return getmetatable(v)==vm and 'Vector3' or type(v) end
local CFrame,cfm={},{}
function CFrame.new(x,y,z) return setmetatable({Position=Vector3.new(x or 0,y or 0,z or 0),LookVector=Vector3.new(0,0,-1),RightVector=Vector3.new(1,0,0)},cfm) end
CFrame.Angles=function() return CFrame.new() end
cfm.__mul=function(a,b) return CFrame.new(a.Position.X+b.Position.X,a.Position.Y+b.Position.Y,a.Position.Z+b.Position.Z) end
cfm.__add=function(a,b) return CFrame.new(a.Position.X+b.X,a.Position.Y+b.Y,a.Position.Z+b.Z) end
local function signal()
 local s={connections={}}
 function s:Connect(fn) local c={fn=fn,Connected=true} function c:Disconnect() self.Connected=false end table.insert(self.connections,c) return c end
 function s:Fire(...) for _,c in ipairs(table.clone(self.connections)) do if c.Connected then c.fn(...) end end end
 return s
end
local now=0 local os={clock=function() return now end}
local deferred,timers={},{} local task={}
function task.defer(fn) table.insert(deferred,fn) end
function task.delay(seconds,fn) local token={at=now+seconds,fn=fn,cancelled=false} table.insert(timers,token) return token end
function task.cancel(token) token.cancelled=true end
local folder={children={},ChildAdded=signal()} function folder:GetChildren() return table.clone(self.children) end
local runService={PostSimulation=signal()}
local partMethods,pm={},{}
pm.__index=function(self,key) if key=='Position' then return self.props.CFrame.Position end return partMethods[key] or self.props[key] end
pm.__newindex=function(self,key,value)
 self.props[key]=value
 if key=='Parent' and value==folder then table.insert(folder.children,self) folder.ChildAdded:Fire(self) end
end
function partMethods:IsA(name) return name=='BasePart' end
function partMethods:SetNetworkOwner(owner) self.owner=owner end
function partMethods:GetNetworkOwner() return self.owner end
function partMethods:ApplyImpulse(impulse) self.AssemblyLinearVelocity=self.AssemblyLinearVelocity+impulse*(1/self.AssemblyMass) end
function partMethods:ApplyAngularImpulse() end
function partMethods:SetAttribute(name,value) self.attributes[name]=value end
function partMethods:GetAttribute(name) return self.attributes[name] end
local Instance={new=function(class) return setmetatable({props={ClassName=class,AssemblyMass=2,AssemblyLinearVelocity=Vector3.zero,CFrame=CFrame.new()},attributes={},owner='client'},pm) end}
local PhysicalProperties={new=function(...) return {...} end}
local Debris={AddItem=function(_,part,seconds) part.DebrisLifetime=seconds end}
local depthDebrisFolder=folder local MAX_DEPTH_PHYSICS_FRAGMENTS=120
local rootPart={Position=Vector3.new(-2,3,-20)} local character={FindFirstChild=function() return rootPart end}
local player={Character=character}
local depthPunch={BaseLimit=8,MaxLimit=48,BaseLungeDistance=10.5,MaxLungeDistance=48}
local power=1500000000 local statValue=function(_,key,default) return key=='Power' and power or default end
${profile}
local launchedAt=nil local noMovement=false
local function flush() local current=deferred deferred={} for _,fn in ipairs(current) do fn() end end
local function advance(seconds)
 local untilTime=now+seconds
 while now<untilTime-.000001 do
  local dt=math.min(.02,untilTime-now) now+=dt flush()
  for _,part in ipairs(folder.children) do
   if not part.Anchored and not noMovement then part.CFrame=part.CFrame+part.AssemblyLinearVelocity*dt end
   -- A deterministic contact-loss scenario, not a Roblox physics simulation.
   if launchedAt and now-launchedAt>=.04 then part.AssemblyLinearVelocity=Vector3.new(21.75751304626465,0,0) end
  end
  runService.PostSimulation:Fire(dt)
  for _,timer in ipairs(timers) do if not timer.cancelled and timer.at<=now then timer.cancelled=true timer.fn() end end
 end
end
task.wait=advance
local function liveConnections()
 local n=0 for _,s in ipairs({folder.ChildAdded,runService.PostSimulation}) do for _,c in ipairs(s.connections) do if c.Connected then n+=1 end end end return n
end
`;
const exercise = `
local profileValue=depthPunch.PowerProfile(player)
check(profileValue.distance==48 and profileValue.forceScale==3.4 and profileValue.limit==48,'actual_high_power_profile')
local command={Invoke=function(_,action)
 check(action=='PunchRadius','actual_punch_command') advance(.2) launchedAt=now
 for i=1,20 do
  local block={Name='block'..i,Position=Vector3.new(0,0,-i),CFrame=CFrame.new(0,0,-i),Size=Vector3.new(4,4,4),Color='color',Material='material'}
  spawnDepthBlockFragments(block,player,Vector3.new(0,0,-1),profileValue.forceScale)
 end
 advance(.42) return {ok=true,BrokenDepthBlocks=44,outcome='penetration'}
end}
local result,summary=runObservedPunch(command,folder,runService)
check(result.ok and summary.fragments==120 and summary.serverOwned==120,'actual_fragment_cap_and_ownership')
check(summary.postSimulationMaxSpeed>=30 and summary.fastMaxDisplacement>=.1 and summary.minPostReads>=2,'actual_postsimulation_motion')
check(summary.maxInitial>=100,'launch_metadata_remains_separate')
check(math.abs(summary.firstFragmentAt-.2)<.000001 and summary.elapsed>=.77-.00001,'windup_lunge_and_old_sample_timing')
local lateMax=0 for _,part in ipairs(folder:GetChildren()) do lateMax=math.max(lateMax,part.AssemblyLinearVelocity.Magnitude) end
check(lateMax<30 and summary.postSimulationMaxSpeed>lateMax,'old_late_snapshot_can_fail_after_valid_launch')
check(liveConnections()==0,'successful_observer_cleanup')
for _,timer in ipairs(timers) do if timer.at==2 then check(timer.cancelled,'observation_deadline_cancelled') end end
print('PASS '..count)
`;
const guardCases = `
local count=0 local function check(v,n) assert(v,n) count+=1 end
${verification}
local good={fragments=120,observedFragments=120,serverOwned=120,ownershipFailures=0,anchoredFailures=0,
 postSimulationSteps=3,postSimulationReads=360,minPostReads=3,maxSpeed=137,postSimulationMaxSpeed=120,
 fastFragmentsMoved=2,fastMaxDisplacement=1,timedOut=false,sampleCapReached=false,observationError=''}
verifyFragmentObservation(good) check(true,'valid observed physics')
for _,change in ipairs({
 function(s) s.fragments=119 end,function(s) s.observedFragments=119 end,function(s) s.serverOwned=119 end,
 function(s) s.ownershipFailures=1 end,function(s) s.anchoredFailures=1 end,function(s) s.postSimulationSteps=1 end,
 function(s) s.postSimulationReads=239 end,function(s) s.minPostReads=1 end,function(s) s.maxSpeed=29.99 end,
 function(s) s.postSimulationMaxSpeed=29.99 end,function(s) s.fastFragmentsMoved=0 end,function(s) s.fastMaxDisplacement=.099 end,
 function(s) s.timedOut=true end,function(s) s.sampleCapReached=true end,function(s) s.observationError='injected failure' end,
}) do local changed=table.clone(good) change(changed) check(not pcall(verifyFragmentObservation,changed),'invalid physics observation accepted') end
print('PASS '..count)
`;
const cleanupExercise = `
local command={Invoke=function() error('injected punch failure') end}
local ok,why=pcall(runObservedPunch,command,folder,runService)
check(not ok and string.find(tostring(why),'injected punch failure',1,true),'preserve primary punch failure')
check(liveConnections()==0,'failure disconnects all observer connections')
for _,timer in ipairs(timers) do check(timer.cancelled,'failure cancels observer deadline') end
print('PASS '..count)
`;
const timerExercise = `
local observation=startFragmentObservation(folder,runService)
advance(2.1)
local result=observation:Finish()
check(result.timedOut and liveConnections()==0,'timeout disconnects both connections')
check(not pcall(verifyFragmentObservation,result),'timeout cannot pass')
print('PASS '..count)
`;
const temp = fs.mkdtempSync(path.join(tempRoot, 'smash-penetration-contract-'));
let compiled = 0, executedAssertions = 0;
const mutationsRejected = [];
function execute(name, text, expectedFailure) {
  const file = path.join(temp, name + '.luau'); fs.writeFileSync(file, text);
  const compile = spawnSync(compiler, ['--null', file], {encoding: 'utf8', timeout: 15000});
  assert.equal(compile.status, 0, `Invalid Luau ${name}: ${compile.stderr || compile.stdout}`); compiled++;
  const run = spawnSync(luau, [file], {encoding: 'utf8', timeout: 15000}); const output = `${run.stdout || ''}${run.stderr || ''}`;
  if (expectedFailure) {
    assert(run.status !== 0 && output.includes(expectedFailure), `${name} survived or wrong failure: ${output}`);
    mutationsRejected.push(name);
  } else {
    assert.equal(run.status, 0, `${name}: ${output}`); const match = run.stdout.trim().match(/^PASS (\d+)$/);
    assert(match && Number(match[1]) > 0, `${name}: missing assertions`); executedAssertions += Number(match[1]);
  }
}
try {
  for (const [index, step] of flow.steps.entries()) if (step.args?.code) {
    const file = path.join(temp, `flow-${index}.luau`); fs.writeFileSync(file, step.args.code);
    const result = spawnSync(compiler, ['--null', file], {encoding: 'utf8', timeout: 15000});
    assert.equal(result.status, 0, `Flow snippet ${index}: ${result.stderr || result.stdout}`); compiled++;
  }
  execute('production-impulse-and-observer', setup + producer + helpers + exercise);
  execute('observation-guards', guardCases);
  execute('failure-cleanup', setup + helpers + cleanupExercise);
  execute('deadline-cleanup', setup + helpers + timerExercise);
  const sourceMutations = [
    ['metadata-only-no-impulse', 'fragment:ApplyImpulse(launchVelocity * fragment.AssemblyMass)', '-- actual impulse removed', 'actual simulated launch speed'],
    ['insufficient-real-impulse', 'fragment:ApplyImpulse(launchVelocity * fragment.AssemblyMass)', 'fragment:ApplyImpulse(launchVelocity * fragment.AssemblyMass * 0.1)', 'actual simulated launch speed'],
    ['client-owned-fragments', 'pcall(function() fragment:SetNetworkOwner(nil) end)', '-- ownership removed', 'all fragments must stay server owned'],
    ['anchored-fragments', 'fragment.Anchored = false', 'fragment.Anchored = true', 'launched fragments must remain physical'],
  ];
  for (const [name, from, to, expected] of sourceMutations) {
    assert.equal(producer.split(from).length, 2, `Unique producer mutation ${name}`);
    execute(name, setup + producer.replace(from, () => to) + helpers + exercise, expected);
  }
  const late = helpers.replace('local observation=startFragmentObservation(folder,runService)', 'local observation')
    .replace("local result=command:Invoke('PunchRadius') returnedAt=os.clock()", "local result=command:Invoke('PunchRadius') observation=startFragmentObservation(folder,runService) returnedAt=os.clock()");
  execute('observer-after-launch', setup + producer + late + exercise, 'actual simulated launch speed');
  execute('velocity-without-displacement', setup + producer + helpers + 'noMovement=true\n' + exercise, 'a fast simulated fragment must actually move');
  const guardLines = verification.split('\n').filter(line => line.trim().startsWith('assert('));
  for (const [index, line] of guardLines.entries()) {
    execute(`weakened-observation-guard-${index}`, guardCases.replace(line, '-- removed one actual observation guard'), 'invalid physics observation accepted');
  }
  console.log(JSON.stringify({ok: true, sourceChecks, compiledSnippetsAndControls: compiled, executedAssertions,
    mutationsRejected, studioUsed: false, note: 'Deterministic contact-loss schedule proves observer timing and guards, not actual Roblox contacts.'}, null, 2));
} finally { for (const file of fs.readdirSync(temp)) fs.unlinkSync(path.join(temp, file)); fs.rmdirSync(temp); }
