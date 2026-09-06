import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {McpClient, findStudioMcp, selectStudioStrict, waitForDataModels, sleep} from './studio_mcp_client.mjs';

const filename = fileURLToPath(import.meta.url);
const root = path.resolve(path.dirname(filename), '../../..');
const canonicalName = 'PunchWallRPGPlayable_v1_final.rbxlx';
const validationName = 'PunchWallRPGPlayable_v1_final_validation.rbxlx';
const specs = [
  ['GameConfig', 'shared/GameConfig.lua'], ['PolishConfig', 'shared/PolishConfig.lua'],
  ['ForestVisualBuilder', 'shared/ForestVisualBuilder.lua'], ['FistVisualBuilder', 'shared/FistVisualBuilder.lua'],
  ['InventoryViewModel', 'shared/InventoryViewModel.lua'], ['ProfilePersistence', 'server/ProfilePersistence.lua'],
  ['PunchWallBootstrap', 'server/PunchWallBootstrap.server.lua'], ['InventoryUI', 'client/InventoryUI.lua'],
  ['PunchWallClient', 'client/PunchWallClient.client.lua'],
];
const sha = value => crypto.createHash('sha256').update(value).digest('hex').toUpperCase();
const normalized = value => value.replace(/\r\n?/g, '\n');
const readJSON = file => JSON.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, ''));
const samePath = (a, b) => typeof a === 'string' && path.resolve(a).toLowerCase() === path.resolve(b).toLowerCase();
const sameHash = (a, b) => typeof a === 'string' && /^[a-f0-9]{64}$/i.test(a) && a.toUpperCase() === b.toUpperCase();
const exactNames = (actual, expected, label) => assert.deepEqual([...actual].sort(), [...expected].sort(), label);
const luaString = value => JSON.stringify(value); // Only controlled ASCII phase/category names are interpolated.

export function parseArgs(args) {
  const flags = ['studio-id', 'studio-name', 'evidence-leaf', 'manifest', 'reopen-proof'];
  const result = {};
  for (let i = 0; i < args.length; i += 2) {
    const key = args[i]?.slice(2);
    assert(args[i]?.startsWith('--') && flags.includes(key) && !result[key], `Unknown/duplicate argument ${args[i]}`);
    assert(args[i + 1] && !args[i + 1].startsWith('--'), `Missing value for ${args[i]}`);
    result[key] = args[i + 1];
  }
  for (const key of flags) assert(result[key], `Explicit --${key} is required`);
  assert(/^[a-zA-Z0-9_-]+$/.test(result['studio-id']), 'Invalid Studio id');
  assert.equal(result['studio-name'], validationName, 'Reopened canonical validation-copy Studio name required');
  assert(/^smash-[a-z0-9-]+$/.test(result['evidence-leaf']), 'Evidence leaf must be a new smash-* name');
  result.manifest = path.resolve(result.manifest);
  result['reopen-proof'] = path.resolve(result['reopen-proof']);
  result.output = path.join(root, 'work/docs/evidence', result['evidence-leaf'] + '.json');
  assert(!fs.existsSync(result.output), 'Preserve existing evidence; choose a new leaf');
  return result;
}

export function assertArtifactBinding({manifest, proof, disk, sources, options}) {
  const names = specs.map(([name]) => name);
  assert.equal(manifest.ok, true, 'Build manifest did not pass');
  assert.equal(proof.ok, true, 'Reopen runtime proof did not pass');
  assert.equal(manifest.sourceMapVersion, 1, 'Build source-map version');
  assert.equal(manifest.codeAllowlistVersion, 1, 'Build allowlist version');
  assert.equal(manifest.embeddedModuleCount, 9, 'Build module count');
  assert.equal(manifest.codeObjectCount, 9, 'Build global code count');
  assert.equal(manifest.cdataPreserved, true, 'Build CDATA preservation');
  assert(samePath(manifest.outputPlace, disk.canonical), 'Manifest does not name this canonical artifact');
  assert(samePath(manifest.sourceRoot, disk.sourceRoot), 'Manifest source root differs from current source root');
  assert(sameHash(manifest.sha256, disk.sha256), 'Manifest artifact hash is stale');
  assert.equal(manifest.bytes, disk.bytes, 'Manifest artifact byte count differs');
  assert(sameHash(disk.validationSHA256, disk.sha256), 'Validation copy differs from canonical bytes');
  exactNames(manifest.embeddedScripts, names, 'Manifest module inventory');
  exactNames(Object.keys(manifest.exactSourceSha256 || {}), names, 'Manifest normalized-hash inventory');
  exactNames(Object.keys(manifest.sourceFileSha256 || {}), names, 'Manifest raw-hash inventory');
  for (const [name] of specs) {
    assert(sameHash(manifest.exactSourceSha256[name], sources[name].normalizedSHA256), `Current normalized source differs: ${name}`);
    assert(sameHash(manifest.sourceFileSha256[name], sources[name].rawSHA256), `Current raw source differs: ${name}`);
  }
  assert(samePath(proof.canonicalOutput, disk.canonical), 'Reopen proof canonical path');
  assert(samePath(proof.canonicalValidationCopy, disk.validation), 'Reopen proof validation-copy path');
  assert(sameHash(proof.rbxlxSha256, disk.sha256), 'Reopen proof artifact hash is stale');
  assert.equal(proof.moduleCount, 9, 'Reopen proof module count');
  assert.equal(proof.codeObjectCount, 9, 'Reopen proof global code count');
  assert.equal(proof.codeAllowlistVersion, 1, 'Reopen proof allowlist');
  assert.equal(proof.cdataPreserved, true, 'Reopen proof CDATA preservation');
  assert.equal(proof.selectedStudio?.id, options['studio-id'], 'Reopen proof belongs to another Studio id');
  assert.equal(proof.selectedStudio?.name, options['studio-name'], 'Reopen proof belongs to another Studio name');
  assert.equal(proof.selectedPlace?.name, options['studio-name'], 'Reopen proof live place name mismatch');
  assert.equal(String(proof.selectedPlace?.placeId), '0', 'Reopen proof must be a local place');
  assert(Array.isArray(proof.checks) && proof.checks.length > 0, 'Native runtime reopen checks are required; StaticOnly is insufficient');
}

export function assertLiveBinding(live, options, sources) {
  assert.equal(live.ok, true, 'Exact live source check failed');
  assert.equal(live.readOnly, true, 'Source proof must be read-only');
  assert.equal(live.selectedStudio?.id, options['studio-id'], 'Live source proof Studio id');
  assert.equal(live.selectedStudio?.name, options['studio-name'], 'Live source proof Studio name');
  assert.equal(live.placeName, options['studio-name'], 'Live source proof place name');
  assert.equal(live.placeId, 0, 'Live source proof local place');
  assert.equal(live.globalCodeObjectCount, 9, 'Live source inventory');
  exactNames(live.sources.map(s => s.name), specs.map(([name]) => name), 'Live proof module inventory');
  for (const item of live.sources) {
    assert(sameHash(item.normalizedSHA256, sources[item.name].normalizedSHA256), `Live normalized hash: ${item.name}`);
    assert.equal(item.exactByteComparison?.ok, true, `Actual live source equality: ${item.name}`);
    assert.equal(item.exactByteComparison?.actualBytes, sources[item.name].normalizedBytes, `Live byte count: ${item.name}`);
    assert.equal(item.exactByteComparison?.expectedBytes, sources[item.name].normalizedBytes, `Expected live byte count: ${item.name}`);
  }
}

function commandJSON(command, args, timeout = 120000) {
  const result = spawnSync(command, args, {cwd: root, encoding: 'utf8', timeout, maxBuffer: 4 * 1024 * 1024});
  assert.equal(result.status, 0, `${command} failed: ${result.error || result.stderr || result.stdout}`);
  return JSON.parse(result.stdout.replace(/^\uFEFF/, ''));
}

function diskPreflight(options) {
  assert(samePath(options.manifest, path.join(root, 'outputs/PunchWallRPGPlayable_v1_final.build.json')), 'Use this repository canonical build manifest');
  const sourceRoot = path.join(root, 'work/punch-wall-rpg/src');
  const files = fs.readdirSync(sourceRoot, {recursive: true, withFileTypes: true})
    .filter(d => d.isFile() && d.name.endsWith('.lua')).map(d => path.relative(sourceRoot, path.join(d.parentPath, d.name)).replaceAll('\\', '/'));
  exactNames(files, specs.map(([, relative]) => relative), 'Current exact local Lua inventory');
  const sources = Object.fromEntries(specs.map(([name, relative]) => {
    const raw = fs.readFileSync(path.join(sourceRoot, relative));
    const text = normalized(raw.toString('utf8'));
    return [name, {relative, rawSHA256: sha(raw), normalizedSHA256: sha(text), normalizedBytes: Buffer.byteLength(text)}];
  }));
  const canonical = path.join(root, 'outputs', canonicalName), validation = path.join(root, 'outputs', validationName);
  const bytes = fs.readFileSync(canonical), validationBytes = fs.readFileSync(validation);
  const disk = {canonical, validation, sourceRoot, bytes: bytes.length, sha256: sha(bytes), validationSHA256: sha(validationBytes)};
  const manifest = readJSON(options.manifest), proof = readJSON(options['reopen-proof']);
  assertArtifactBinding({manifest, proof, disk, sources, options});
  // Independently parse the actual artifact, not only assertions in its manifest.
  const exactDisk = commandJSON('powershell.exe', ['-NoProfile', '-File', path.join(root, 'work/automation/verify-exact-rbxlx-sources.ps1'), '-PlacePath', canonical]);
  assert.equal(exactDisk.ok, true, 'Canonical exact embedded-source contract');
  assert(sameHash(exactDisk.rbxlxSha256, disk.sha256), 'Exact disk verifier hash');
  const runnerPaths = ['work/automation/scripts/studio-frame-profile.mjs', 'work/automation/scripts/verify-studio-source.mjs',
    'work/automation/scripts/studio_mcp_client.mjs', 'work/automation/verify-exact-rbxlx-sources.ps1'];
  return {disk, sources, manifest, proof, exactDisk, manifestSHA256: sha(fs.readFileSync(options.manifest)),
    reopenProofSHA256: sha(fs.readFileSync(options['reopen-proof'])),
    toolHashes: Object.fromEntries(runnerPaths.map(relative => [relative, sha(fs.readFileSync(path.join(root, relative)))]))};
}

const FISTS = ['Starter Glove', 'Boxing Glove', 'Iron Knuckle', 'Thunder Fist', 'Titan Gauntlet'];
const PETS = ['Forest Pup', 'Forest Pup', 'Miner Cat'];
const EQUIPPED = ['Forest Pup', 'Miner Cat'];
const seedValues = {OwnedFistsJSON: JSON.stringify(FISTS), PetInventoryJSON: JSON.stringify(PETS), EquippedPetsJSON: JSON.stringify(EQUIPPED)};
const luaSeed = Object.entries(seedValues).map(([key, value]) => `[${luaString(key)}]=${luaString(value)}`).join(',');

export const LUA = {
  guard: `local R=game:GetService('RunService') local H=game:GetService('HttpService')
local players=game:GetService('Players'):GetPlayers() assert(R:IsStudio() and #players==1,'isolated Studio player required')
local p=players[1] local w=assert(workspace:FindFirstChild('PunchWallRPG')) local ss=game:GetService('ServerStorage')
assert(w:GetAttribute('PersistenceMode')=='EphemeralStudio' and w:GetAttribute('PersistenceStudioDefaultEphemeral')==true
 and w:GetAttribute('PersistenceStudioLiveDataOptIn')==false and ss:GetAttribute('PunchWallAllowLiveDataStoreAccess')~=true,'strict ephemeral defaults required')
assert(p:GetAttribute('ProfileReady')==true and p:GetAttribute('ProfilePersistenceState')=='EphemeralStudio'
 and p:GetAttribute('ProfileWritable')==false,'non-writable ephemeral profile required')
local a=assert(ss:FindFirstChild('PunchWallAutomation'))
`,
  seed: `local G=require(game.ReplicatedStorage.GameConfig) local values={${luaSeed}}
local function catalogHas(catalog,name) for _,item in ipairs(catalog) do if item.name==name then return true end end return false end
for _,name in ipairs(H:JSONDecode(values.OwnedFistsJSON)) do assert(catalogHas(G.Fists,name),'invalid configured fist '..name) end
for _,name in ipairs(H:JSONDecode(values.PetInventoryJSON)) do assert(catalogHas(G.Pets,name),'invalid configured pet '..name) end
local reset=a:Invoke('Reset') assert(type(reset)=='table' and reset.ok==true,'Reset failed')
local seeded=a:Invoke('SetStats',values) assert(type(seeded)=='table' and seeded.ok==true,'SetStats failed')
local readback=a:Invoke('Snapshot') assert(type(readback)=='table' and readback.ok==true,'Snapshot failed')
for key,expected in pairs(values) do
 local actual=assert(p:FindFirstChild('RPGStats'):FindFirstChild(key),'missing stat '..key).Value
 assert(actual==expected and readback[key]==expected,'seed readback differs '..key)
end
return H:JSONEncode({ok=true,values=values,ownedFists=5,inventoryCopies=3,inventorySpecies=2,equippedPets=2})`,
  clientReady: `local p=game.Players.LocalPlayer local H=game:GetService('HttpService') local g=assert(p.PlayerGui:FindFirstChild('PunchWallHUD'))
local expected={${luaSeed}} local stats=assert(p:FindFirstChild('RPGStats'))
for key,value in pairs(expected) do assert(stats:FindFirstChild(key) and stats[key].Value==value,'seed not replicated '..key) end
local companions=assert(workspace:FindFirstChild(p.Name..' Client Companions'),'missing companions') local models=0
for _,d in ipairs(companions:GetChildren()) do if d:IsA('Model') then models+=1 end end assert(models==2,'two equipped companion models required')
local a=assert(g:FindFirstChild('PunchWallClientAutomation'))
assert(type(a:Invoke('OpenInventory'))=='table','Inventory controller unavailable')
local result=a:Invoke('SelectInventoryCategory','All') assert(type(result)=='table' and result.ok==true,'Inventory selection failed')
local s=a:Invoke('Snapshot') assert(s.ok==true and s.inventoryVisible==true and s.inventory.ok==true and s.inventory.category=='All','Inventory seed view unavailable')
assert(s.inventory.capacity.used==3,'Inventory capacity does not reflect three copies')
local names={} for _,name in ipairs(s.inventory.visibleNames) do names[name]=(names[name] or 0)+1 end
for _,name in ipairs(H:JSONDecode(expected.OwnedFistsJSON)) do assert(names[name]==1,'missing owned fist '..name) end
assert(names['Forest Pup']==2 and names['Miner Cat']==1,'Inventory does not expose exact seeded pet copies')
assert(a:Invoke('CloseMenus')==true,'CloseMenus failed') local closed=a:Invoke('Snapshot')
assert(closed.ok==true and not closed.menuVisible and not closed.shopVisible and not closed.inventoryVisible,'Menus did not close')
return H:JSONEncode({ok=true,companions=models,inventory=s.inventory,closed=closed})`,
  profiler: `local p=game.Players.LocalPlayer local g=assert(p.PlayerGui:FindFirstChild('PunchWallHUD'))
local R=game:GetService('RunService') local Stats=game:GetService('Stats') local H=game:GetService('HttpService')
local U=game:GetService('UserInputService')
assert(R:IsStudio() and not g:FindFirstChild('SmashFramePacingQA'),'isolated profiler required')
local f=Instance.new('BindableFunction') f.Name='SmashFramePacingQA' f.Parent=g
local phase=nil local frames={} local before=0 local began=0 local total=0 local dropped=0 local invalid=0 local limit=36000
local connection local destroying local stopped=false local contextConnections={} local viewportConnection
local focus='unknown' local context local currentCamera=workspace.CurrentCamera local traceLimit=12
local function viewport()
 local camera=workspace.CurrentCamera local v=camera and camera.ViewportSize
 local x,y=v and v.X or 0,v and v.Y or 0
 local valid=type(x)=='number' and type(y)=='number' and x==x and y==y and x>1 and y>1 and x<math.huge and y<math.huge
 local function finite(v)return type(v)=='number' and v==v and v>-math.huge and v<math.huge end
 return {x=finite(x) and x or 0,y=finite(y) and y or 0,valid=valid}
end
local function recordViewport(kind)
 if not phase then return end
 local v=viewport() local camera=workspace.CurrentCamera
 context.viewportValid=context.viewportValid and v.valid
 -- Property events prove a change even if deferred delivery sees the already-restored value.
 if kind~='Finish' or camera~=context.lastCamera or v.x~=context.lastViewport.x or v.y~=context.lastViewport.y then
  context.viewportChanges+=1
  if #context.viewportTrace<traceLimit then table.insert(context.viewportTrace,{kind=kind,at=os.clock()-began,viewport=v}) end
 end
 context.lastCamera=camera context.lastViewport=v
end
local function bindCamera()
 if viewportConnection then viewportConnection:Disconnect() viewportConnection=nil end
 currentCamera=workspace.CurrentCamera
 if currentCamera then viewportConnection=currentCamera:GetPropertyChangedSignal('ViewportSize'):Connect(function()recordViewport('ViewportSize')end) end
 recordViewport('CurrentCamera')
end
local function observeFocus(value)
 if value==focus then return end
 if phase then
  context.focusTransitions+=1
  if #context.focusTrace<traceLimit then table.insert(context.focusTrace,{from=focus,to=value,at=os.clock()-began}) end
 end
 focus=value
end
local function stop() if stopped then return end stopped=true phase=nil
 if connection then connection:Disconnect() end if destroying then destroying:Disconnect() end
 if viewportConnection then viewportConnection:Disconnect() end
 for _,c in ipairs(contextConnections) do c:Disconnect() end
end
table.insert(contextConnections,workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(bindCamera))
table.insert(contextConnections,U.WindowFocused:Connect(function()observeFocus('focused')end))
table.insert(contextConnections,U.WindowFocusReleased:Connect(function()observeFocus('unfocused')end))
bindCamera()
destroying=f.Destroying:Connect(stop)
connection=R.RenderStepped:Connect(function(dt)
 if phase then total+=1
  if type(dt)~='number' or dt~=dt or dt<=0 or dt==math.huge then invalid+=1
  elseif #frames<limit then table.insert(frames,dt*1000) else dropped+=1 end
 end
end)
f.OnInvoke=function(action,value)
 if action=='Destroy' then stop() f:Destroy() return {ok=true,disconnected=true} end
 assert(not stopped,'profiler expired')
 if action=='Begin' then assert(not phase,'phase already active') assert(type(value)=='string','phase name required')
  frames={} total=0 dropped=0 invalid=0 before=Stats:GetTotalMemoryUsageMb() began=os.clock()
  local v=viewport() context={viewportStart=v,lastViewport=v,lastCamera=workspace.CurrentCamera,viewportValid=v.valid,
   viewportChanges=0,viewportTrace={},focusStart=focus,focusTransitions=0,focusTrace={}}
  phase=value return {ok=true,name=phase,sampleCap=limit,viewportStart=v,focusStart=focus}
 end
 if action=='Finish' then assert(phase==value,'phase boundary mismatch') recordViewport('Finish') local ended=os.clock() phase=nil
  local out={ok=true,name=value,seconds=ended-began,samples=#frames,totalIntervals=total,sampleCap=limit,
   droppedSamples=dropped,invalidSamples=invalid,saturated=dropped>0,memoryStartMB=before,memoryEndMB=Stats:GetTotalMemoryUsageMb(),
   viewportStart=context.viewportStart,viewportEnd=context.lastViewport,viewportChanges=context.viewportChanges,
   viewportTrace=context.viewportTrace,viewportTraceTruncated=context.viewportChanges>#context.viewportTrace,
   focusStart=context.focusStart,focusEnd=focus,focusTransitions=context.focusTransitions,focusTrace=context.focusTrace,
   focusTraceTruncated=context.focusTransitions>#context.focusTrace,contextTraceLimit=traceLimit,
   focusKnownWholePhase=context.focusStart~='unknown',
   contextValid=context.viewportValid and context.viewportChanges==0 and context.focusTransitions==0}
  assert(#frames>=30,'insufficient frame samples') assert(invalid==0,'invalid frame intervals')
  table.sort(frames) local function percentile(q) return frames[math.clamp(math.ceil(#frames*q),1,#frames)] end
  out.p50MS=percentile(.5) out.p95MS=percentile(.95) out.p99MS=percentile(.99) out.maxMS=frames[#frames]
  out.over50MS=0 out.over100MS=0
  for _,dt in ipairs(frames) do if dt>50 then out.over50MS+=1 end if dt>100 then out.over100MS+=1 end end
  out.lastTargetScan={queries=g:GetAttribute('TargetDepthQueryCount'),candidates=g:GetAttribute('TargetDepthCandidateCount'),unique=g:GetAttribute('TargetDepthUniqueCandidates')}
  return out
 end error('unknown profiler action')
end
task.delay(300,function() if f.Parent then stop() f:Destroy() end end)
local quality='unavailable' pcall(function() quality=tostring(settings().Rendering.QualityLevel) end)
return H:JSONEncode({ok=true,viewport=tostring(workspace.CurrentCamera.ViewportSize),graphics=quality,
 device='Studio desktop window',sampleCap=limit,maximumLifetimeSeconds=300,focusState=focus,focusSource='ObservedWindowEvents',contextTraceLimit=traceLimit})`,
  stress: `local result=a:Invoke('StressPunchCase',{name='frame-profile-four-reset-server-stress',x=-2,power=1500000000,cycles=4,attempts=5,resetTotal=true,expectedTotal=20})
assert(type(result)=='table' and result.valid==true and result.punches==20 and result.total==20 and result.overlaps==0 and result.stuck==0,'server stress route failed')
return H:JSONEncode(result)`,
};

export function navigationCode(mode, category) {
  assert(['closed', 'shop', 'inventory'].includes(mode), 'Unknown navigation mode');
  assert(mode !== 'inventory' || ['All', 'Fists', 'Pets', 'Honor'].includes(category), 'Unknown inventory category');
  const action = mode === 'closed' ? "assert(a:Invoke('CloseMenus')==true,'CloseMenus failed')"
    : mode === 'shop' ? "assert(a:Invoke('OpenTab','Fists')==true,'OpenTab failed')"
      : `local opened=a:Invoke('OpenInventory') assert(type(opened)=='table' and opened.ok==true,'OpenInventory failed')
local selected=a:Invoke('SelectInventoryCategory',${luaString(category)}) assert(type(selected)=='table' and selected.ok==true,'SelectInventoryCategory failed')`;
  const predicate = mode === 'closed' ? 'not s.menuVisible and not s.shopVisible and not s.inventoryVisible'
    : mode === 'shop' ? "s.menuVisible and s.shopVisible and s.activeTab=='Fists' and not s.inventoryVisible"
      : `s.inventoryVisible and not s.shopVisible and s.inventory and s.inventory.ok==true and s.inventory.visible==true and s.inventory.category==${luaString(category)}`;
  return `local a=game.Players.LocalPlayer.PlayerGui.PunchWallHUD.PunchWallClientAutomation
${action}
local s=a:Invoke('Snapshot') assert(type(s)=='table' and s.ok==true and ${predicate},'requested navigation not visible')
return game.HttpService:JSONEncode(s)`;
}

export async function cleanupOwnedSession(record, {destroy, stop, close}) {
  record.cleanup = [];
  for (const [name, action] of [['destroyProfiler', destroy], ['stopPlay', stop], ['closeMcp', close]]) {
    try { record.cleanup.push({name, ok: true, result: await action()}); }
    catch (error) { record.cleanup.push({name, ok: false, error: String(error.stack || error)}); }
  }
  return record.cleanup.every(item => item.ok);
}

async function run(options) {
  const record = {ok: false, startedAt: new Date().toISOString(), kind: 'Studio RenderStepped intervals including MCP/harness work',
    limitations: ['Not physical-phone performance or ordinary client-input FPS.', 'Separate MCP Begin/Finish include command boundaries and transport scheduling.',
      'Inventory automation computes diagnostic snapshots in addition to navigation.', 'Last target scan values are neither phase totals nor maxima.',
      'Memory is total client-reported MB at boundaries, not game allocations or leak proof.',
      'Initial focus remains unknown until an observed window event; native foreground identity/activation is separate execution evidence.',
      'Viewport/camera or focus transitions invalidate phase context even when restored; raw interval metrics are retained.'], phases: [], commands: []};
  let c, before, playAttempted = false, profilerAttempted = false, primaryError;
  const call = async (type, code, timeout = 35000) => {
    const result = await c.callTool('execute_luau', {datamodel_type: type, code}, timeout);
    assert(!result.isError, result.text); return JSON.parse(result.text);
  };
  const tool = async (name, args) => { const result = await c.callTool(name, args, 35000); assert(!result.isError, result.text); return result.text; };
  const liveCheck = () => {
    const pattern = '^' + options['studio-name'].replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + '$';
    const result = commandJSON(process.execPath, [path.join(root, 'work/automation/scripts/verify-studio-source.mjs'), options['studio-id'], pattern]);
    assertLiveBinding(result, options, before.sources); return result;
  };
  try {
    before = diskPreflight(options); // All paths, hashes, and native reopen evidence validated before MCP spawn.
    record.binding = before;
    const git = spawnSync('git', ['rev-parse', 'HEAD'], {cwd: root, encoding: 'utf8'});
    assert.equal(git.status, 0, git.stderr); record.repositoryCommit = git.stdout.trim();
    record.artifactBuildCommit = before.manifest.sourceCommit;
    record.liveBefore = liveCheck();
    c = new McpClient(findStudioMcp(), 'smash-final-artifact-frame-profile');
    await c.initialize();
    record.selectedStudio = await selectStudioStrict(c, {studioInstanceId: options['studio-id'], studioName: '^' + validationName.replaceAll('.', '[.]') + '$'});
    await waitForDataModels(c, ['Edit'], 35000);
    playAttempted = true;
    await tool('start_stop_play', {is_start: true}); await waitForDataModels(c, ['Server', 'Client'], 35000); await sleep(6500);
    record.seed = await call('Server', LUA.guard + LUA.seed);
    await sleep(1200);
    record.seedClient = await call('Client', LUA.clientReady);
    profilerAttempted = true; record.setup = await call('Client', LUA.profiler);
    const prof = (action, value) => call('Client', `return game.HttpService:JSONEncode(game.Players.LocalPlayer.PlayerGui.PunchWallHUD.SmashFramePacingQA:Invoke(${luaString(action)},${luaString(value)}))`);
    const navigation = async (mode, category) => {
      const startedAt = new Date().toISOString(); const snapshot = await call('Client', navigationCode(mode, category));
      record.commands.push({mode, category, startedAt, finishedAt: new Date().toISOString(), snapshot});
    };
    const phase = async (name, action, workload) => {
      const beginRequestedAt = new Date().toISOString(); const start = await prof('Begin', name); assert.equal(start.ok, true);
      await action(); const finishRequestedAt = new Date().toISOString(); const result = await prof('Finish', name);
      assert.equal(result.ok, true); assert.equal(result.name, name);
      record.phases.push({...result, workload, beginRequestedAt, finishRequestedAt, finishReceivedAt: new Date().toISOString()});
      assert.equal(result.contextValid, true, 'Viewport/camera or focus changed during phase; preserve metrics as invalid context');
      assert.equal(result.droppedSamples, 0, 'Sample cap reached; partial phase cannot pass');
      assert.equal(result.invalidSamples, 0, 'Invalid samples cannot pass');
    };
    await navigation('closed'); await sleep(700);
    await phase('idle-two-seeded-companions', () => sleep(6000), 'No gameplay input; two verified seeded companion models.');
    await navigation('shop'); await sleep(700);
    await phase('shop-visible', () => sleep(6000), 'Open Shop with five owned catalog fists; MCP boundary overhead included.');
    await navigation('inventory', 'All'); await sleep(700);
    await phase('inventory-automation-navigation', async () => {
      for (let i = 0; i < 3; i++) for (const category of ['All', 'Fists', 'Pets', 'Honor']) {
        await navigation('inventory', category); await sleep(400);
      }
    }, 'Twelve automated category selections, repeated OpenInventory and diagnostic Snapshots; not native-navigation-only timing.');
    await navigation('closed'); await sleep(500);
    await phase('four-world-reset-twenty-direct-server-punch-stress', async () => {
      record.stress = await call('Server', LUA.guard + LUA.stress, 90000);
    }, 'StressPunchCase: four world resets, four teleports, twenty direct authoritative server punches, collision diagnostics. First reset clears seeded inventory/equipment; not client-input punch FPS.');
  } catch (error) { primaryError = error; record.error = String(error.stack || error); }
  finally {
    const cleanupOK = await cleanupOwnedSession(record, {
      destroy: async () => {
        if (!c || !profilerAttempted) return {skipped: true, reason: 'Profiler was not attempted'};
        const result = await call('Client', "local p=game.Players.LocalPlayer local g=p and p:FindFirstChild('PlayerGui') and p.PlayerGui:FindFirstChild('PunchWallHUD') local f=g and g:FindFirstChild('SmashFramePacingQA') if f then return game.HttpService:JSONEncode(f:Invoke('Destroy')) end return game.HttpService:JSONEncode({ok=true,alreadyAbsent=true})");
        assert.equal(result.ok, true, 'Profiler cleanup did not acknowledge success'); return result;
      },
      stop: async () => {
        if (!c || !playAttempted) return {skipped: true, reason: 'Play was not attempted'};
        await tool('start_stop_play', {is_start: false}); await waitForDataModels(c, ['Edit'], 35000);
        return {ok: true, editAvailable: true};
      },
      close: () => { if (c) c.close(); return {ok: true}; },
    });
    // Postflight runs only after owned Play cleanup. Evidence I/O cannot bypass cleanup.
    if (before && cleanupOK && !primaryError) {
      try {
        record.liveAfter = liveCheck(); const after = diskPreflight(options);
        assert.deepEqual(after, before, 'Artifact/source/manifest/proof/tool binding changed during profiling');
        record.postflightUnchanged = true;
      } catch (error) { primaryError = error; record.error = String(error.stack || error); }
    }
    record.ok = !primaryError && cleanupOK && record.postflightUnchanged === true;
    record.finishedAt = new Date().toISOString();
    try {
      fs.mkdirSync(path.dirname(options.output), {recursive: true});
      fs.writeFileSync(options.output, JSON.stringify(record, null, 2), {flag: 'wx'});
    } catch (error) {
      record.ok = false; record.evidenceWriteError = String(error.stack || error);
    }
    if (!record.ok) process.exitCode = 1;
    console.log(JSON.stringify({ok: record.ok, evidence: options.output, error: record.error, evidenceWriteError: record.evidenceWriteError, cleanup: record.cleanup}, null, 2));
  }
}

export async function selfTest() {
  let checks = 0;
  const check = (condition, label) => { assert(condition, label); checks++; };
  const expectReject = (action, label) => { assert.throws(action, undefined, label); checks++; };
  const options = {'studio-id': 'test-studio', 'studio-name': validationName};
  const hash = 'A'.repeat(64), names = specs.map(([name]) => name);
  const sources = Object.fromEntries(names.map(name => [name, {normalizedSHA256: hash, rawSHA256: hash, normalizedBytes: 12}]));
  const disk = {canonical: path.join(root, 'outputs', canonicalName), validation: path.join(root, 'outputs', validationName), sourceRoot: path.join(root, 'work/punch-wall-rpg/src'), bytes: 25, sha256: hash, validationSHA256: hash};
  const manifest = {ok: true, sourceMapVersion: 1, codeAllowlistVersion: 1, embeddedModuleCount: 9, codeObjectCount: 9, cdataPreserved: true,
    outputPlace: disk.canonical, sourceRoot: disk.sourceRoot, sha256: hash, bytes: 25, embeddedScripts: names,
    exactSourceSha256: Object.fromEntries(names.map(name => [name, hash])), sourceFileSha256: Object.fromEntries(names.map(name => [name, hash]))};
  const proof = {ok: true, canonicalOutput: disk.canonical, canonicalValidationCopy: disk.validation, rbxlxSha256: hash, moduleCount: 9, codeObjectCount: 9,
    codeAllowlistVersion: 1, cdataPreserved: true, selectedStudio: {id: options['studio-id'], name: validationName}, selectedPlace: {name: validationName, placeId: 0}, checks: ['actual native run']};
  const binding = {manifest, proof, disk, sources, options}; assertArtifactBinding(binding); checks++;
  for (const mutate of [b => b.manifest.ok = false, b => b.manifest.sha256 = 'B'.repeat(64), b => b.disk.validationSHA256 = 'B'.repeat(64),
    b => b.manifest.bytes++, b => b.manifest.codeObjectCount++, b => b.manifest.cdataPreserved = false,
    b => b.manifest.embeddedScripts.push('Injected'), b => delete b.manifest.exactSourceSha256.PolishConfig,
    b => b.sources.PunchWallClient.normalizedSHA256 = 'B'.repeat(64), b => b.sources.InventoryUI.rawSHA256 = 'B'.repeat(64),
    b => b.manifest.outputPlace = b.disk.validation, b => b.proof.selectedStudio.id = 'other', b => b.proof.selectedPlace.placeId = 42,
    b => b.proof.checks = [], b => b.proof.rbxlxSha256 = 'B'.repeat(64), b => b.proof.ok = false]) {
    const altered = structuredClone(binding); mutate(altered); expectReject(() => assertArtifactBinding(altered), 'Weakened artifact binding');
  }
  const live = {ok: true, readOnly: true, selectedStudio: proof.selectedStudio, placeName: validationName, placeId: 0, globalCodeObjectCount: 9,
    sources: names.map(name => ({name, normalizedSHA256: hash, exactByteComparison: {ok: true, actualBytes: 12, expectedBytes: 12}}))};
  assertLiveBinding(live, options, sources); checks++;
  for (const mutate of [v => v.selectedStudio.id = 'other', v => v.sources[0].exactByteComparison.ok = false,
    v => v.sources[0].exactByteComparison.actualBytes++, v => v.sources[0].normalizedSHA256 = 'B'.repeat(64),
    v => v.sources.push(v.sources[0]), v => v.readOnly = false, v => v.placeId = 1]) {
    const altered = structuredClone(live); mutate(altered); expectReject(() => assertLiveBinding(altered, options, sources), 'Weakened actual source proof');
  }
  let stopped = 0, closed = 0; const failed = {};
  check(await cleanupOwnedSession(failed, {destroy: () => {throw Error('injected Destroy failure');}, stop: () => {stopped++;}, close: () => {closed++;}}) === false, 'Cleanup failure must fail result');
  check(stopped === 1 && closed === 1 && failed.cleanup[0].error.includes('injected'), 'Destroy failure cannot skip Stop/Close');
  const stopFailed = {};
  check(await cleanupOwnedSession(stopFailed, {destroy: () => true, stop: () => {throw Error('injected Stop failure');}, close: () => {closed++;}}) === false && closed === 2, 'Stop failure cannot skip Close');
  expectReject(() => parseArgs(['--studio-id', 'x']), 'Required CLI identity');
  expectReject(() => navigationCode('inventory', 'Bogus'), 'Invalid category');
  for (const text of [LUA.guard, LUA.seed, LUA.clientReady, LUA.profiler, LUA.stress, navigationCode('closed'), navigationCode('shop'), navigationCode('inventory', 'Pets')]) check(text.length > 0, 'Executable snippet is nonempty');
  const source = fs.readFileSync(path.join(root, 'work/punch-wall-rpg/src/server/PunchWallBootstrap.server.lua'), 'utf8');
  check(source.includes('root:SetAttribute("PersistenceStudioDefaultEphemeral", true)'), 'Default ephemeral source contract');
  const stress = source.slice(source.indexOf('shared.PunchWallRunStressCase = function'), source.indexOf('local function automationCatalog'));
  check(stress.includes('resetAutomationState(player)') && stress.includes('resetWorldState()') && stress.includes('cycleCount * attemptCount'), 'Stress label follows current actual producer');
  const tempRoot = os.tmpdir();
  const compiler = process.env.LUAU_COMPILE_COMMAND || fs.readdirSync(tempRoot).filter(n => n.startsWith('codex-luau-')).sort().reverse()
    .map(n => path.join(tempRoot, n, process.platform === 'win32' ? 'luau-compile.exe' : 'luau-compile')).find(fs.existsSync);
  assert(compiler, 'BLOCKED: LUAU_COMPILE_COMMAND is required for snippet compile');
  const temp = fs.mkdtempSync(path.join(tempRoot, 'smash-frame-profile-'));
  const snippets = [LUA.guard + LUA.seed, LUA.clientReady, LUA.profiler, LUA.guard + LUA.stress,
    navigationCode('closed'), navigationCode('shop'), navigationCode('inventory', 'All'), navigationCode('inventory', 'Honor')];
  let executedLuauAssertions = 0; const mutationsRejected = [];
  try {
    for (const [index, snippet] of snippets.entries()) {
      const file = path.join(temp, `${index}.luau`); fs.writeFileSync(file, snippet);
      const result = spawnSync(compiler, ['--null', file], {encoding: 'utf8', timeout: 15000});
      check(result.status === 0, `Snippet ${index} compile: ${result.stderr || result.stdout}`);
    }
    const runtime = path.join(path.dirname(compiler), process.platform === 'win32' ? 'luau.exe' : 'luau');
    const guardTest = `
local count=0 local function check(v,n) assert(v,n) count+=1 end
local function fixture(change,expected)
 local flags={studio=true,players=1,PersistenceMode='EphemeralStudio',PersistenceStudioDefaultEphemeral=true,
  PersistenceStudioLiveDataOptIn=false,ProfileReady=true,ProfilePersistenceState='EphemeralStudio',ProfileWritable=false,harness=true}
 change(flags)
 local function attrs(_,name) return flags[name] end
 local p={GetAttribute=attrs} local w={GetAttribute=attrs}
 local ss={GetAttribute=attrs,FindFirstChild=function() return flags.harness and {} or nil end}
 local list={} for i=1,flags.players do list[i]=p end
 local services={RunService={IsStudio=function() return flags.studio end},HttpService={},Players={GetPlayers=function() return list end},ServerStorage=ss}
 local game={GetService=function(_,name) return services[name] end}
 local workspace={FindFirstChild=function() return w end}
 local ok=pcall(function() ${LUA.guard} return true end)
 check(ok==expected,'exact_ephemeral_guard')
end
fixture(function() end,true)
fixture(function(f) f.PunchWallAllowLiveDataStoreAccess=false end,true)
for _,change in ipairs({
 function(f) f.studio=false end,function(f) f.players=0 end,function(f) f.players=2 end,
 function(f) f.PersistenceMode='Live' end,function(f) f.PersistenceStudioDefaultEphemeral=false end,
 function(f) f.PersistenceStudioDefaultEphemeral=nil end,function(f) f.PersistenceStudioLiveDataOptIn=true end,
 function(f) f.PersistenceStudioLiveDataOptIn=nil end,function(f) f.PunchWallAllowLiveDataStoreAccess=true end,
 function(f) f.ProfileReady=false end,function(f) f.ProfilePersistenceState='Live' end,
 function(f) f.ProfileWritable=true end,function(f) f.ProfileWritable=nil end,function(f) f.harness=false end,
}) do fixture(change,false) end
print('PASS '..count)
`;
    const collectorTest = `
local count=0 local function check(v,n) assert(v,n) count+=1 end
local function signal()
 local s={connections={}}
 function s:Connect(fn) local c={fn=fn,Connected=true} function c:Disconnect() self.Connected=false end table.insert(self.connections,c) return c end
 function s:Fire(...) for _,c in ipairs(table.clone(self.connections)) do if c.Connected then c.fn(...) end end end
 return s
end
local created=nil local delays={} local R={RenderStepped=signal(),IsStudio=function() return true end}
local g={GetAttribute=function(_,key) return ({TargetDepthQueryCount=2,TargetDepthCandidateCount=12,TargetDepthUniqueCandidates=9})[key] end}
function g:FindFirstChild() return created and created.Parent==self and created or nil end
local player={PlayerGui={FindFirstChild=function() return g end}}
local U={WindowFocused=signal(),WindowFocusReleased=signal()}
local services={RunService=R,UserInputService=U,Stats={GetTotalMemoryUsageMb=function() return 100 end},HttpService={JSONEncode=function(_,v) return v end}}
local game={Players={LocalPlayer=player},GetService=function(_,name) return services[name] end}
local cameras={} local function camera(x,y)
 local c={ViewportSize={X=x,Y=y},changed=signal()}
 function c:GetPropertyChangedSignal(key)assert(key=='ViewportSize')return self.changed end
 function c:Resize(x,y)self.ViewportSize={X=x,Y=y}self.changed:Fire()end
 table.insert(cameras,c)return c
end
local cameraChanged=signal() local workspace={CurrentCamera=camera(1277,780)}
function workspace:GetPropertyChangedSignal(key)assert(key=='CurrentCamera')return cameraChanged end
function workspace:ReplaceCamera(c)self.CurrentCamera=c cameraChanged:Fire()end
local function contextListeners()
 local n=0 local signals={cameraChanged,U.WindowFocused,U.WindowFocusReleased}
 for _,c in ipairs(cameras)do table.insert(signals,c.changed)end
 for _,s in ipairs(signals)do for _,c in ipairs(s.connections)do if c.Connected then n+=1 end end end return n
end
local function frames()for i=1,40 do R.RenderStepped:Fire(.016)end end
local task={delay=function(_,fn) table.insert(delays,fn) end}
local settings=function() return {Rendering={QualityLevel='test'}} end
local Instance={new=function()
 local f={Destroying=signal()} function f:Destroy() self.Destroying:Fire() self.Parent=nil end created=f return f
end}
local create=function() ${LUA.profiler} end
local setup=create() check(setup.sampleCap==36000,'sample_limit_reported')
check(setup.focusState=='unknown' and setup.focusSource=='ObservedWindowEvents','initial_focus_is_unknown_not_fabricated')
check(contextListeners()==4,'bounded_camera_and_focus_listeners')
local f=created
check(f.OnInvoke('Begin','timing').name=='timing','phase_begin')
check(not pcall(function() f.OnInvoke('Begin','duplicate') end),'double_begin_rejected')
for i=1,38 do R.RenderStepped:Fire(.016) end R.RenderStepped:Fire(.08) R.RenderStepped:Fire(.12)
check(not pcall(function() f.OnInvoke('Finish','wrong') end),'wrong_phase_rejected')
local out=f.OnInvoke('Finish','timing')
check(out.samples==40 and out.totalIntervals==40 and out.droppedSamples==0,'complete_interval_accounting')
check(out.p50MS==16 and out.p95MS==16 and out.p99MS==120 and out.maxMS==120,'nearest_rank_millisecond_percentiles')
check(out.over50MS==2 and out.over100MS==1,'long_frame_counts')
check(out.lastTargetScan.queries==2 and out.lastTargetScan.candidates==12 and out.lastTargetScan.unique==9,'last_scan_is_snapshot_only')
check(out.contextValid and out.viewportStart.x==1277 and out.viewportEnd.y==780 and out.viewportChanges==0,'stable_actual_viewport_is_valid')
check(out.focusStart=='unknown' and out.focusEnd=='unknown' and not out.focusKnownWholePhase,'no_focus_event_never_implies_foreground')
f.OnInvoke('Begin','resize')workspace.CurrentCamera:Resize(900,600)frames()out=f.OnInvoke('Finish','resize')
check(not out.contextValid and out.viewportChanges==1 and out.viewportStart.x==1277 and out.viewportEnd.x==900 and out.samples==40,'resize_invalidates_context_but_retains_raw_metrics')
f.OnInvoke('Begin','resize-back')workspace.CurrentCamera:Resize(700,500)workspace.CurrentCamera:Resize(900,600)frames()out=f.OnInvoke('Finish','resize-back')
check(not out.contextValid and out.viewportChanges==2 and out.viewportStart.x==out.viewportEnd.x,'resize_back_cannot_mask_changed_phase')
f.OnInvoke('Begin','deferred-resize-back')frames()workspace.CurrentCamera.changed:Fire()workspace.CurrentCamera.changed:Fire()out=f.OnInvoke('Finish','deferred-resize-back')
check(not out.contextValid and out.viewportChanges==2 and out.viewportStart.x==out.viewportEnd.x,'deferred_resize_events_reject_even_when_values_already_restored')
f.OnInvoke('Begin','unannounced-resize')workspace.CurrentCamera.ViewportSize={X=800,Y=600}frames()out=f.OnInvoke('Finish','unannounced-resize')
check(not out.contextValid and out.viewportChanges==1 and out.viewportTrace[1].kind=='Finish','finish_rechecks_actual_dimensions')
local oldCamera=workspace.CurrentCamera
f.OnInvoke('Begin','camera-replaced')workspace:ReplaceCamera(camera(800,600))frames()out=f.OnInvoke('Finish','camera-replaced')
check(not out.contextValid and out.viewportChanges==1,'same_size_camera_replacement_is_context_change')
check(not oldCamera.changed.connections[1].Connected and contextListeners()==4,'camera_replacement_disconnects_old_listener_without_growth')
f.OnInvoke('Begin','camera-back')local held=workspace.CurrentCamera workspace:ReplaceCamera(oldCamera)workspace:ReplaceCamera(held)frames()out=f.OnInvoke('Finish','camera-back')
check(not out.contextValid and out.viewportChanges==2,'camera_changed_back_is_still_rejected')
f.OnInvoke('Begin','deferred-camera-back')frames()cameraChanged:Fire()cameraChanged:Fire()out=f.OnInvoke('Finish','deferred-camera-back')
check(not out.contextValid and out.viewportChanges==2,'deferred_camera_replacement_events_remain_invalid')
workspace.CurrentCamera:Resize(0,0)f.OnInvoke('Begin','invalid-viewport')frames()out=f.OnInvoke('Finish','invalid-viewport')
check(not out.contextValid and not out.viewportStart.valid,'invalid_initial_viewport_cannot_pass')
workspace.CurrentCamera:Resize(0/0,600)f.OnInvoke('Begin','nonfinite-viewport')frames()out=f.OnInvoke('Finish','nonfinite-viewport')
check(not out.contextValid and out.viewportStart.x==0,'invalid_viewport_diagnostics_remain_finite')
workspace.CurrentCamera:Resize(800,600)
U.WindowFocused:Fire()f.OnInvoke('Begin','known-focus')frames()out=f.OnInvoke('Finish','known-focus')
check(out.contextValid and out.focusKnownWholePhase and out.focusStart=='focused' and out.focusEnd=='focused','observed_focus_persists_until_another_event')
f.OnInvoke('Begin','lost-restored-focus')U.WindowFocusReleased:Fire()U.WindowFocused:Fire()frames()out=f.OnInvoke('Finish','lost-restored-focus')
check(not out.contextValid and out.focusTransitions==2 and out.focusStart==out.focusEnd,'lost_and_restored_focus_invalidates_phase')
f.OnInvoke('Begin','bounded-transitions')
for i=1,20 do workspace.CurrentCamera:Resize(800+i,600)if i%2==1 then U.WindowFocusReleased:Fire()else U.WindowFocused:Fire()end end
frames()out=f.OnInvoke('Finish','bounded-transitions')
check(not out.contextValid and out.viewportChanges==20 and #out.viewportTrace==12 and out.viewportTraceTruncated,'resize_trace_is_bounded_without_losing_total')
check(out.focusTransitions==20 and #out.focusTrace==12 and out.focusTraceTruncated,'focus_trace_is_bounded_without_losing_total')

f.OnInvoke('Begin','cap') for i=1,36010 do R.RenderStepped:Fire(.016) end
out=f.OnInvoke('Finish','cap')
check(out.samples==36000 and out.totalIntervals==36010 and out.droppedSamples==10 and out.saturated,'cap_and_drop_accounting')
f.OnInvoke('Begin','short') for i=1,29 do R.RenderStepped:Fire(.016) end
check(not pcall(function() f.OnInvoke('Finish','short') end),'too_few_intervals_rejected')
f.OnInvoke('Begin','invalid') for i=1,30 do R.RenderStepped:Fire(.016) end R.RenderStepped:Fire(0/0)
check(not pcall(function() f.OnInvoke('Finish','invalid') end),'invalid_interval_rejected')
check(f.OnInvoke('Destroy').disconnected and not f.Parent,'explicit_cleanup_destroys_profiler')
check(not R.RenderStepped.connections[1].Connected,'explicit_cleanup_disconnects_render_listener')
check(contextListeners()==0,'explicit_cleanup_disconnects_all_context_listeners')
create() local second=created
second.OnInvoke('Begin','initial-focus-event')frames()U.WindowFocused:Fire()out=second.OnInvoke('Finish','initial-focus-event')
check(not out.contextValid and out.focusStart=='unknown' and out.focusEnd=='focused' and out.focusTransitions==1,'first_actual_focus_event_is_recorded_without_retroactive_foreground')
second:Destroy()
check(not R.RenderStepped.connections[2].Connected,'external_instance_destruction_disconnects_listener')
check(contextListeners()==0,'external_destruction_disconnects_all_context_listeners')
create() local third=created delays[#delays]()
check(not third.Parent and not R.RenderStepped.connections[3].Connected,'maximum_lifetime_cleans_up')
check(contextListeners()==0,'deadline_disconnects_all_context_listeners')
print('PASS '..count)
`;
    for (const [name, code, expected] of [['ephemeral', guardTest, 16], ['collector', collectorTest, 37]]) {
      const file = path.join(temp, `${name}.luau`); fs.writeFileSync(file, code);
      const compiled = spawnSync(compiler, ['--null', file], {encoding: 'utf8', timeout: 15000});
      check(compiled.status === 0, `${name} mock compile: ${compiled.stderr || compiled.stdout}`);
      const result = spawnSync(runtime, [file], {encoding: 'utf8', timeout: 15000});
      check(result.status === 0 && result.stdout.trim() === `PASS ${expected}`, `${name} exact execution: ${result.stderr || result.stdout}`);
      executedLuauAssertions += expected;
    }
    const mutations = [
      ['trust_only_current_property_value', "kind~='Finish' or camera~=context.lastCamera", 'camera~=context.lastCamera', 'deferred_resize_events_reject_even_when_values_already_restored'],
      ['ignore_resize_events', "recordViewport('ViewportSize')", "-- resize event ignored\n", 'resize_back_cannot_mask_changed_phase'],
      ['fabricate_initial_foreground', "local focus='unknown'", "local focus='focused'", 'initial_focus_is_unknown_not_fabricated'],
      ['waive_viewport_context', 'context.viewportChanges==0', 'true', 'resize_invalidates_context_but_retains_raw_metrics'],
      ['waive_focus_context', 'context.focusTransitions==0', 'true', 'lost_and_restored_focus_invalidates_phase'],
      ['leak_context_listeners', 'for _,c in ipairs(contextConnections) do c:Disconnect() end', '-- context cleanup removed', 'explicit_cleanup_disconnects_all_context_listeners'],
      ['unbounded_resize_trace', '#context.viewportTrace<traceLimit', 'true', 'resize_trace_is_bounded_without_losing_total'],
    ];
    for (const [name, from, to, expected] of mutations) {
      assert.equal(LUA.profiler.split(from).length, 2, `Unique collector mutation ${name}`);
      const text=collectorTest.replace(LUA.profiler,()=>LUA.profiler.replace(from,()=>to));
      const file=path.join(temp,name+'.luau'); fs.writeFileSync(file,text);
      const compiled=spawnSync(compiler,['--null',file],{encoding:'utf8',timeout:15000});
      check(compiled.status===0, `${name} mutation must compile: ${compiled.stderr || compiled.stdout}`);
      const result=spawnSync(runtime,[file],{encoding:'utf8',timeout:15000});
      check(result.status!==0 && (result.stderr+result.stdout).includes(expected), `${name} mutation survived or failed for another reason: ${result.stderr || result.stdout}`);
      mutationsRejected.push(name);
    }
  } finally { for (const file of fs.readdirSync(temp)) fs.unlinkSync(path.join(temp, file)); fs.rmdirSync(temp); }
  return {ok: true, checks, compiledSnippets: snippets.length, executedLuauAssertions, mutationsRejected, studioUsed: false};
}

if (process.argv[1] && path.resolve(process.argv[1]) === filename) {
  try {
    if (process.argv.length === 3 && process.argv[2] === '--self-test') console.log(JSON.stringify(await selfTest(), null, 2));
    else await run(parseArgs(process.argv.slice(2)));
  } catch (error) { console.error(error.stack || error); process.exitCode = 1; }
}
