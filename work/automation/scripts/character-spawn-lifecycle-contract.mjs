import fs from 'node:fs';
import path from 'node:path';
import cp from 'node:child_process';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';

const option = (name, fallback) => {
  const index = process.argv.indexOf(name);
  if (index < 0) return fallback;
  assert(process.argv[index + 1] && !process.argv[index + 1].startsWith('--'), `Missing ${name} value`);
  return process.argv[index + 1];
};
const sourceRoot = path.resolve(option('--source-root', process.cwd()));
const baselineRef = option('--baseline-ref', '781ff4b');
const luau = option('--luau', process.env.LUAU_QA_EXE
  || 'C:/Users/Jennarong Pinjai/AppData/Local/Temp/codex-luau-smash-0.737/luau.exe');
const serverPath = 'work/punch-wall-rpg/src/server/PunchWallBootstrap.server.lua';
const source = fs.readFileSync(path.join(sourceRoot, serverPath), 'utf8').replace(/\r/g, '');
const baseline = cp.execFileSync('git', ['show', `${baselineRef}:${serverPath}`], {
  cwd: sourceRoot, encoding: 'utf8', maxBuffer: 4 * 1024 * 1024,
}).replace(/\r/g, '');

function extract(text) {
  const start = text.indexOf('do\nlocal spawnBindings = {}');
  const end = text.indexOf('\nlocal fallRecovery =', start);
  const registrationStart = text.indexOf('Players.PlayerAdded:Connect(shared.PunchWallBindPlayerSpawn)');
  const registrationEnd = text.indexOf('Players.PlayerAdded:Connect(depthPunch.BindCharacterLifetime)', registrationStart);
  assert(start >= 0 && end > start && registrationStart > end && registrationEnd > registrationStart,
    'Production spawn binder or bootstrap registration boundary changed; review extraction');
  const binder = text.slice(start, end);
  assert.equal((binder.match(/function shared\.PunchWallBindPlayerSpawn\(player\)/g) || []).length, 1);
  return { binder, registration: text.slice(registrationStart, registrationEnd) };
}
const current = extract(source);
const old = extract(baseline);

function execute(code) {
  let input = 'QAChunk=""\n';
  for (let i = 0; i < code.length; i += 200) input += `QAChunk=QAChunk..${JSON.stringify(code.slice(i, i + 200))}\n`;
  input += 'assert(loadstring(QAChunk))()\n';
  const result = cp.spawnSync(luau, [], { input, encoding: 'utf8', maxBuffer: 4 * 1024 * 1024, timeout: 20000 });
  const output = `${result.stdout || ''}\n${result.stderr || ''}`;
  return {
    ok: !result.error && result.status === 0 && !result.stderr
      && !/stdin:|stack backtrace|SyntaxError/.test(output) && output.includes('SPAWN_CASE_PASS'),
    output, error: result.error,
  };
}
function requirePass(code, label) {
  const result = execute(code);
  assert(result.ok, `${label}\n${result.output}\n${result.error || ''}`);
}
function compile(code, label) {
  requirePass(`assert(loadstring(${JSON.stringify(code)})) print('SPAWN_CASE_PASS compiled')`, label);
}
compile(source, 'Complete current server compiles within Luau register limits');

// Deterministic, cooperative scheduler. task.spawn runs immediately to the first
// yield; WaitForChild polls direct children with its actual supplied timeout.
// Each scenario runs in an independent VM. No Roblox services or files are mutated.
const mock = String.raw`
local now, sequence = 0, 0
local queue, connections, errors = {}, {}, {}
local eventDelay = EVENT_DELAY
local function schedule(thread, at)
 sequence += 1 table.insert(queue, {thread=thread, at=at, sequence=sequence})
end
local function resume(thread)
 local ok, delay = coroutine.resume(thread)
 if not ok then table.insert(errors, tostring(delay)) return end
 if coroutine.status(thread) ~= 'dead' then schedule(thread, now + (delay or .01)) end
end
local task = {}
function task.spawn(fn) local thread=coroutine.create(fn) resume(thread) return thread end
function task.wait(seconds) return coroutine.yield(seconds or .01) end
function task.delay(seconds, fn) local thread=coroutine.create(fn) schedule(thread, now+seconds) return thread end
local function advance(target)
 local work=0
 while true do
  table.sort(queue, function(a,b) return a.at==b.at and a.sequence<b.sequence or a.at<b.at end)
  local next=queue[1] if not next or next.at>target then break end
  table.remove(queue,1) now=next.at resume(next.thread)
  work+=1 assert(work<20000, 'unbounded scheduler')
 end
 now=target assert(#errors==0, table.concat(errors,' | '))
end
local os={clock=function() return now end}
local function signal()
 local sig={handlers={}}
 function sig:Connect(fn)
  local connection={Connected=true, fn=fn, signal=self}
  function connection:Disconnect() self.Connected=false end
  table.insert(self.handlers,connection) table.insert(connections,connection) return connection
 end
 function sig:Fire(value)
  for _, connection in ipairs(table.clone(self.handlers)) do
   if connection.Connected then
    local function deliver() if connection.Connected then connection.fn(value) end end
    if eventDelay>0 then task.delay(eventDelay,deliver) else task.spawn(deliver) end
   end
  end
 end
 function sig:LiveCount() local n=0 for _,c in ipairs(self.handlers) do if c.Connected then n+=1 end end return n end
 return sig
end
local vector={} vector.__index=vector
vector.__add=function(a,b) return setmetatable({X=a.X+b.X,Y=a.Y+b.Y,Z=a.Z+b.Z},vector) end
local Vector3={new=function(x,y,z) return setmetatable({X=x,Y=y,Z=z},vector) end}
Vector3.zero=Vector3.new(0,0,0)
local CFrame={lookAt=function(position,target) return {Position=position,Target=target} end}
local workspace={} local spawn={Position=Vector3.new(-2,2,-18)} local shared={}
local Players={PlayerAdded=signal(),PlayerRemoving=signal(),players={}}
function Players:GetPlayers() return table.clone(self.players) end
local function character()
 local c={inside=true,children={},attrs={}}
 function c:FindFirstChild(name)
  for _, child in ipairs(self.children) do if child.Parent==self and child.Name==name then return child end end
 end
 function c:FindFirstChildOfClass(class)
  for _, child in ipairs(self.children) do if child.Parent==self and child.ClassName==class then return child end end
 end
 function c:WaitForChild(name, timeout)
  local deadline=now+timeout
  repeat local found=self:FindFirstChild(name) if found then return found end task.wait(.01) until now>=deadline
  return self:FindFirstChild(name)
 end
 function c:IsDescendantOf(parent) assert(parent==workspace) return self.inside end
 function c:SetAttribute(key,value) self.attrs[key]=value end
 return c
end
local function attach(c,node) node.Parent=c table.insert(c.children,node) return node end
local function root(c,class)
 local value={ClassName=class or 'Part',Name='HumanoidRootPart',CFrame='original',
  AssemblyLinearVelocity=Vector3.new(3,4,5),AssemblyAngularVelocity=Vector3.new(6,7,8)}
 function value:IsA(name) return name==self.ClassName or (name=='BasePart' and self.ClassName=='Part') end
 return attach(c,value)
end
local function humanoid(c,health) return attach(c,{ClassName='Humanoid',Name='Humanoid',Health=health or 100}) end
local function readyCharacter() local c=character() root(c) humanoid(c) return c end
local function player(c)
 local p={Character=c,CharacterAdded=signal(),Parent=Players}
 table.insert(Players.players,p) return p
end
local function poseMatches(part)
 local f=part and part.CFrame
 return type(f)=='table' and f.Position.X==-2 and f.Position.Y==6 and f.Position.Z==-18
  and f.Target.X==-2 and f.Target.Y==6 and f.Target.Z==-19
end
local function assertPlaced(p,c)
 assert(p.RespawnLocation==spawn,'canonical respawn not bound')
 assert(c.attrs.PunchWallSpawnPlaced==true,'current character not marked placed')
 local r=c:FindFirstChild('HumanoidRootPart') assert(poseMatches(r),'wrong spawn pose or course facing')
 for _,key in ipairs({'AssemblyLinearVelocity','AssemblyAngularVelocity'}) do
  assert(r[key].X==0 and r[key].Y==0 and r[key].Z==0,'spawn retains velocity')
 end
end
`;

const scenarios = [
  ['fresh-existing-player', `local c=readyCharacter() local p=player(c)`, `advance(.1) assertPlaced(p,c)`],
  ['future-player', '', `local c=readyCharacter() local p=player(c) Players.PlayerAdded:Fire(p) advance(.1) assertPlaced(p,c)`],
  ['future-character', `local p=player(nil)`, `local c=readyCharacter() p.Character=c p.CharacterAdded:Fire(c) advance(.1) assertPlaced(p,c)`],
  ['one-binding-one-placement', `local c=readyCharacter() local p=player(c)`, `
   advance(.1) assertPlaced(p,c) local r=c:FindFirstChild('HumanoidRootPart') r.CFrame='player moved'
   shared.PunchWallBindPlayerSpawn(p) p.CharacterAdded:Fire(c) advance(1)
   assert(p.CharacterAdded:LiveCount()==1,'duplicate character connection')
   assert(r.CFrame=='player moved','same character teleported again')`],
  ['late-root', `local c=character() humanoid(c) local p=player(c)`, `
   task.delay(.3,function()root(c)end) advance(.5) assertPlaced(p,c)`],
  ['late-humanoid', `local c=character() root(c) local p=player(c)`, `
   task.delay(.3,function()humanoid(c)end) advance(.5) assertPlaced(p,c)`],
  ['late-workspace-parent', `local c=readyCharacter() c.inside=false local p=player(c)`, `
   task.delay(.3,function()c.inside=true end) advance(.5) assertPlaced(p,c)`],
  ['dead-during-root-wait', `local c=character() local h=humanoid(c) local p=player(c)`, `
   task.delay(.1,function()h.Health=0 end) task.delay(.3,function()root(c)end) advance(.5)
   assert(not c.attrs.PunchWallSpawnPlaced,'dead character was placed')
   assert(c:FindFirstChild('HumanoidRootPart').CFrame=='original','dead character moved')`],
  ['dead-during-workspace-wait', `local c=readyCharacter() c.inside=false local p=player(c)`, `
   task.delay(.1,function()c:FindFirstChildOfClass('Humanoid').Health=0 end)
   task.delay(.3,function()c.inside=true end) advance(.5)
   assert(not c.attrs.PunchWallSpawnPlaced,'death during parent wait was ignored')`],
  ['replaced-root-during-workspace-wait', `local c=readyCharacter() c.inside=false local oldRoot=c:FindFirstChild('HumanoidRootPart') local p=player(c)`, `
   task.delay(.1,function()oldRoot.Parent=nil root(c)end)
   task.delay(.3,function()c.inside=true end) advance(.5)
   assertPlaced(p,c) assert(oldRoot.CFrame=='original','obsolete root was moved')`],
  ['removed-root-during-workspace-wait', `local c=readyCharacter() c.inside=false local oldRoot=c:FindFirstChild('HumanoidRootPart') local p=player(c)`, `
   task.delay(.1,function()oldRoot.Parent=nil end) task.delay(.3,function()c.inside=true end) advance(.5)
   assert(not c.attrs.PunchWallSpawnPlaced and oldRoot.CFrame=='original','detached root was used')`],
  ['wrong-class-root', `local c=character() local r=root(c,'Folder') humanoid(c) local p=player(c)`, `
   advance(.1) assert(not c.attrs.PunchWallSpawnPlaced and r.CFrame=='original','non-part root accepted')`],
  ['normal-respawn', `local oldCharacter=readyCharacter() local p=player(oldCharacter)`, `
   advance(.1) assertPlaced(p,oldCharacter) local c=readyCharacter() p.Character=c p.CharacterAdded:Fire(c)
   advance(.2) assertPlaced(p,c) c:FindFirstChild('HumanoidRootPart').CFrame='respawn player moved'
   p.CharacterAdded:Fire(c) advance(1) assert(c:FindFirstChild('HumanoidRootPart').CFrame=='respawn player moved')`],
  ['respawn-cancels-old-wait', `local oldCharacter=character() humanoid(oldCharacter) local p=player(oldCharacter)`, `
   local c=readyCharacter() task.delay(.1,function()p.Character=c p.CharacterAdded:Fire(c)end)
   task.delay(.3,function()root(oldCharacter)end) advance(.5) assertPlaced(p,c)
   assert(not oldCharacter.attrs.PunchWallSpawnPlaced,'old character wait survived respawn')`],
  ['current-character-before-deferred-added', `local oldCharacter=character() humanoid(oldCharacter) local p=player(oldCharacter)`, `
   local c=readyCharacter() task.delay(.1,function()p.Character=c p.CharacterAdded:Fire(c) root(oldCharacter)end)
   advance(.115) assert(not oldCharacter.attrs.PunchWallSpawnPlaced,'old character moved before queued CharacterAdded')
   advance(.3) assertPlaced(p,c)`],
  ['player-removal-cancels-wait', `local c=character() humanoid(c) local p=player(c)`, `
   task.delay(.1,function()p.Parent=nil Players.PlayerRemoving:Fire(p)end)
   task.delay(.3,function()root(c)end) advance(.5)
   assert(not c.attrs.PunchWallSpawnPlaced,'removed player was placed')
   assert(p.CharacterAdded:LiveCount()==0,'player removal leaked character connection')`],
  ['missing-root-bounded', `local c=character() humanoid(c) local p=player(c)`, `
   advance(5.2) assert(not c.attrs.PunchWallSpawnPlaced and #queue==0,'missing root wait was not bounded')`],
  ['missing-humanoid-bounded', `local c=character() root(c) local p=player(c)`, `
   advance(5.2) assert(not c.attrs.PunchWallSpawnPlaced and #queue==0,'missing humanoid wait was not bounded')`],
  ['missing-workspace-bounded', `local c=readyCharacter() c.inside=false local p=player(c)`, `
   advance(5.2) assert(not c.attrs.PunchWallSpawnPlaced and #queue==0,'workspace wait accepted detached character')`],
  ['missing-all-bounded', `local c=character() c.inside=false local p=player(c)`, `
   advance(15.3) assert(not c.attrs.PunchWallSpawnPlaced and #queue==0,'sequential discovery did not finish')`],
];

function caseCode(version, scenario, delay = 0) {
  return `${mock.replace('EVENT_DELAY', String(delay))}\n${version.binder}\n${scenario[1]}\n${version.registration}\n${scenario[2]}\nadvance(now) print('SPAWN_CASE_PASS ${scenario[0]}')`;
}
const delays = [0, .02];
let passed = 0;
for (const delay of delays) for (const scenario of scenarios) {
  if (scenario[0] === 'current-character-before-deferred-added' && delay === 0) continue;
  requirePass(caseCode(current, scenario, delay), `${scenario[0]} (event delay ${delay})`);
  passed++;
}
const scenario = name => { const result = scenarios.find(value => value[0] === name); assert(result, name); return result; };
const baselineFailures = ['dead-during-root-wait', 'replaced-root-during-workspace-wait'];
compile(old.binder, 'Baseline binder compiles');
for (const name of baselineFailures) {
  const result = execute(caseCode(old, scenario(name)));
  assert(!result.ok && /dead character was placed|wrong spawn pose or course facing/.test(result.output),
    `Baseline must reproduce the expected ${name} assertion, not an unrelated harness error\n${result.output}`);
}

function replaceOnce(text, from, to) {
  assert.equal(text.split(from).length - 1, 1, `Mutation target missing or ambiguous: ${from}`);
  return text.replace(from, () => to);
}
const mutations = [
  ['allow-dead-humanoid', 'or not humanoid or humanoid.Health <= 0', 'or not humanoid', 'dead-during-root-wait'],
  ['retain-captured-root', 'character:WaitForChild("HumanoidRootPart", 5)', 'local capturedRoot = character:WaitForChild("HumanoidRootPart", 5)', 'replaced-root-during-workspace-wait',
    ['local rootPart = character:FindFirstChild("HumanoidRootPart")', 'local rootPart = capturedRoot']],
  ['ignore-current-character', 'or player.Character ~= character or not character:IsDescendantOf(workspace)', 'or not character:IsDescendantOf(workspace)', 'current-character-before-deferred-added'],
  ['ignore-player-removal-state', 'or spawnBindings[player] ~= state or state.character ~= character', 'or state.character ~= character', 'player-removal-cancels-wait'],
  ['ignore-workspace-membership', 'or player.Character ~= character or not character:IsDescendantOf(workspace)', 'or player.Character ~= character', 'missing-workspace-bounded'],
  ['repeat-character-placement', 'if state.character == character then return end', '-- weakened once-per-character guard', 'one-binding-one-placement'],
  ['duplicate-player-binding', 'if spawnBindings[player] then return end', '-- weakened player binding guard', 'one-binding-one-placement'],
  ['leak-character-connection', 'state.connection:Disconnect()', '-- connection intentionally leaked\n', 'player-removal-cancels-wait'],
  ['retain-linear-velocity', 'rootPart.AssemblyLinearVelocity = Vector3.zero', '-- velocity left unchanged', 'fresh-existing-player'],
  ['retain-angular-velocity', 'rootPart.AssemblyAngularVelocity = Vector3.zero', '-- angular velocity left unchanged', 'fresh-existing-player'],
  ['wrong-spawn-height', 'spawn.Position + Vector3.new(0, 4, 0)', 'spawn.Position + Vector3.new(0, 0, 0)', 'fresh-existing-player'],
  ['wrong-course-facing', 'position + Vector3.new(0, 0, -1)', 'position + Vector3.new(0, 0, 1)', 'fresh-existing-player'],
  ['skip-humanoid-discovery', 'character:WaitForChild("Humanoid", 5)', '-- no humanoid discovery', 'late-humanoid'],
  ['accept-non-part-root', 'or not rootPart:IsA("BasePart")', '', 'wrong-class-root'],
];
const expectedMutationFailures = {
  'allow-dead-humanoid': 'dead character was placed',
  'retain-captured-root': 'current character not marked placed',
  'ignore-current-character': 'old character moved before queued CharacterAdded',
  'ignore-player-removal-state': 'removed player was placed',
  'ignore-workspace-membership': 'workspace wait accepted detached character',
  'repeat-character-placement': 'same character teleported again',
  'duplicate-player-binding': 'duplicate character connection',
  'leak-character-connection': 'player removal leaked character connection',
  'retain-linear-velocity': 'spawn retains velocity',
  'retain-angular-velocity': 'spawn retains velocity',
  'wrong-spawn-height': 'wrong spawn pose or course facing',
  'wrong-course-facing': 'wrong spawn pose or course facing',
  'skip-humanoid-discovery': 'current character not marked placed',
  'accept-non-part-root': 'non-part root accepted',
};
for (const [name, from, to, target, second] of mutations) {
  let binder = replaceOnce(current.binder, from, to);
  if (second) binder = replaceOnce(binder, ...second);
  compile(binder, `Mutation ${name} compiles before behavioral execution`);
  const result = execute(caseCode({ ...current, binder }, scenario(target), target === 'current-character-before-deferred-added' ? .02 : 0));
  assert(!result.ok && result.output.includes(expectedMutationFailures[name]),
    `Mutation ${name} escaped ${target}\n${result.output}`);
}

console.log(JSON.stringify({
  ok: true, contract: 'character-spawn-lifecycle', sourceRoot, baselineRef,
  sourceSha256: crypto.createHash('sha256').update(source).digest('hex'),
  binderSha256: crypto.createHash('sha256').update(current.binder).digest('hex'),
  completeServerCompile: true, executedScenarios: passed,
  baselineFailuresReproduced: baselineFailures.length,
  compiledMutationControlsRejected: mutations.length,
  studioRuntime: 'Coordinator-owned; this contract executes source in a deterministic mock only',
}, null, 2));
