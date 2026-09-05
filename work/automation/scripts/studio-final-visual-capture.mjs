import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {McpClient, findStudioMcp, selectStudioStrict, waitForDataModels, sleep} from './studio_mcp_client.mjs';
import {parseArgs, assertArtifactBinding, assertLiveBinding, LUA as PROFILE_LUA, navigationCode, selfTest as profileSelfTest} from './studio-frame-profile.mjs';

const filename = fileURLToPath(import.meta.url);
const root = path.resolve(path.dirname(filename), '../../..');
const validationName = 'PunchWallRPGPlayable_v1_final_validation.rbxlx';
const canonicalName = 'PunchWallRPGPlayable_v1_final.rbxlx';
const pattern = '^PunchWallRPGPlayable_v1_final_validation[.]rbxlx$';
const sha = value => crypto.createHash('sha256').update(value).digest('hex').toUpperCase();
const readJSON = file => JSON.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, ''));
const specs = [
  ['GameConfig', 'shared/GameConfig.lua'], ['PolishConfig', 'shared/PolishConfig.lua'],
  ['ForestVisualBuilder', 'shared/ForestVisualBuilder.lua'], ['FistVisualBuilder', 'shared/FistVisualBuilder.lua'],
  ['InventoryViewModel', 'shared/InventoryViewModel.lua'], ['ProfilePersistence', 'server/ProfilePersistence.lua'],
  ['PunchWallBootstrap', 'server/PunchWallBootstrap.server.lua'], ['InventoryUI', 'client/InventoryUI.lua'],
  ['PunchWallClient', 'client/PunchWallClient.client.lua'],
];
const commandJSON = (command, args) => {
  const result = spawnSync(command, args, {cwd: root, encoding: 'utf8', timeout: 120000, maxBuffer: 4 * 1024 * 1024});
  assert.equal(result.status, 0, `${command} failed: ${result.error || result.stderr || result.stdout}`);
  return JSON.parse(result.stdout.replace(/^\uFEFF/, ''));
};

function preflight(options) {
  const sourceRoot = path.join(root, 'work/punch-wall-rpg/src');
  assert.equal(options.manifest.toLowerCase(), path.join(root, 'outputs/PunchWallRPGPlayable_v1_final.build.json').toLowerCase(), 'Canonical manifest required');
  const inventory = fs.readdirSync(sourceRoot, {recursive: true, withFileTypes: true})
    .filter(d => d.isFile() && d.name.endsWith('.lua')).map(d => path.relative(sourceRoot, path.join(d.parentPath, d.name)).replaceAll('\\', '/'));
  assert.deepEqual(inventory.sort(), specs.map(([, relative]) => relative).sort(), 'Exact current nine-source inventory');
  const sources = Object.fromEntries(specs.map(([name, relative]) => {
    const raw = fs.readFileSync(path.join(sourceRoot, relative)), text = raw.toString('utf8').replace(/\r\n?/g, '\n');
    return [name, {relative, rawSHA256: sha(raw), normalizedSHA256: sha(text), normalizedBytes: Buffer.byteLength(text)}];
  }));
  const canonical = path.join(root, 'outputs', canonicalName), validation = path.join(root, 'outputs', validationName);
  const bytes = fs.readFileSync(canonical);
  const disk = {canonical, validation, sourceRoot, bytes: bytes.length, sha256: sha(bytes), validationSHA256: sha(fs.readFileSync(validation))};
  const manifest = readJSON(options.manifest), proof = readJSON(options['reopen-proof']);
  assertArtifactBinding({manifest, proof, disk, sources, options});
  const exactDisk = commandJSON('powershell.exe', ['-NoProfile', '-File', path.join(root, 'work/automation/verify-exact-rbxlx-sources.ps1'), '-PlacePath', canonical]);
  assert.equal(exactDisk.ok, true, 'Actual canonical XML source verification');
  assert.equal(exactDisk.rbxlxSha256.toUpperCase(), disk.sha256, 'Actual XML hash binding');
  const dependencies = ['work/automation/scripts/studio-final-visual-capture.mjs', 'work/automation/scripts/studio-frame-profile.mjs',
    'work/automation/scripts/verify-studio-source.mjs', 'work/automation/scripts/studio_mcp_client.mjs', 'work/automation/verify-exact-rbxlx-sources.ps1'];
  return {disk, sources, manifest, proof, exactDisk, manifestSHA256: sha(fs.readFileSync(options.manifest)),
    reopenProofSHA256: sha(fs.readFileSync(options['reopen-proof'])),
    toolHashes: Object.fromEntries(dependencies.map(relative => [relative, sha(fs.readFileSync(path.join(root, relative)))]))};
}

export const LUA = {
  desktop: `local S=game:GetService('StudioDeviceSimulatorService') S:StopSimulationAsync()
assert(S:GetDeviceAsync()=='default','desktop simulation did not stop')
return game.HttpService:JSONEncode({ok=true,name='Studio desktop window',device=S:GetDeviceAsync(),emulated=false})`,
  phone: `local S=game:GetService('StudioDeviceSimulatorService') local matches={}
for _,id in ipairs(S:GetDeviceListAsync()) do local info=S:GetDeviceInfoAsync(id)
 if info.IsCustom==false and info.Name:lower():gsub('%s','')=='iphone17pro' then table.insert(matches,{id=id,name=info.Name}) end
end
assert(#matches==1,'Expected unique built-in iPhone 17 Pro')
S:SetDeviceAsync(matches[1].id) S:SetOrientationAsync(Enum.ScreenOrientation.LandscapeLeft)
S:SetScalingModeAsync(Enum.DeviceSimulatorScalingMode.FitToWindow) task.wait(.3)
local size=S:GetResolutionAsync()
assert(S:GetDeviceAsync()==matches[1].id and size.X==874 and size.Y==402,'Actual built-in iPhone landscape resolution mismatch')
return game.HttpService:JSONEncode({ok=true,id=matches[1].id,name=matches[1].name,custom=false,width=size.X,height=size.Y,orientation='LandscapeLeft',scaling='FitToWindow'})`,
  settings: `local a=game.Players.LocalPlayer.PlayerGui.PunchWallHUD.PunchWallClientAutomation
assert(a:Invoke('CloseMenus')==true,'CloseMenus before Settings failed')
assert(a:Invoke('OpenSettings')==true,'OpenSettings failed')
return game.HttpService:JSONEncode({ok=true})`,
};

export function stateCode(device, screen) {
  assert(['desktop', 'iphone17pro-landscape'].includes(device), 'Unknown device');
  assert(['fresh-hud', 'shop', 'inventory-fists', 'inventory-pets', 'settings'].includes(screen), 'Unknown screen');
  const viewport = device === 'desktop'
    ? "assert(v.X>=900 and v.Y>=600,'Maximize desktop Studio viewport before capture')"
    : "assert(v.X==874 and v.Y==402,'Client camera is not the exact built-in iPhone landscape viewport')";
  const gate = screen === 'fresh-hud' ? "assert(not s.menuVisible and not s.shopVisible and not s.inventoryVisible and not s.settingsVisible and not s.rebirthVisible and not s.spinVisible and h.Visible,'Fresh HUD is obscured by a menu')"
    : screen === 'shop' ? "assert(s.menuVisible and s.shopVisible and s.activeTab=='Fists' and s.shopPage=='Fists' and not s.inventoryVisible and not s.settingsVisible,'Shop route is not visible')"
      : screen === 'settings' ? "assert(s.settingsVisible and not s.shopVisible and not s.inventoryVisible and g.SettingsWindow.Visible,'Settings route is not visible')"
        : `assert(s.inventoryVisible and not s.shopVisible and not s.settingsVisible and s.inventory and s.inventory.ok==true and s.inventory.visible==true and s.inventory.category=='${screen === 'inventory-fists' ? 'Fists' : 'Pets'}','Inventory category is not visible')
local names={} for _,name in ipairs(s.inventory.visibleNames) do names[name]=(names[name] or 0)+1 end
${screen === 'inventory-fists' ? "assert(#s.inventory.visibleNames==5,'Expected five seeded fists') for _,name in ipairs({'Starter Glove','Boxing Glove','Iron Knuckle','Thunder Fist','Titan Gauntlet'}) do assert(names[name]==1,'missing visible fist '..name) end"
    : "assert(#s.inventory.visibleNames==3 and names['Forest Pup']==2 and names['Miner Cat']==1,'Expected exact three seeded pet copies')"}
assert(s.inventory.layout and s.inventory.layout.insideSafeArea==true and s.inventory.layout.boundsSafe==true
 and s.inventory.layout.allTextFits==true and s.inventory.layout.noOverlap==true,'Inventory layout gate failed')`;
  const settings = screen !== 'settings' ? '' : `
local body=assert(g.SettingsWindow:FindFirstChild('Body')) local controls={}
for _,spec in ipairs({{'SOUNDSetting','SoundOn'},{'SOUNDSetting','SoundOff'},{'MOTIONSetting','MotionOn'},{'MOTIONSetting','MotionCalm'},
 {'UI SIZESetting','Scale80'},{'UI SIZESetting','Scale100'},{'UI SIZESetting','Scale120'},{'Footer','Done'}}) do
 local row=assert(body:FindFirstChild(spec[1])) local parent=spec[1]=='Footer' and row or assert(row:FindFirstChild('Options'))
 local button=assert(parent:FindFirstChild(spec[2]))
 assert(button:IsA('GuiButton') and button.Visible and button.Active and button.Selectable
  and button.AbsoluteSize.X>=44 and button.AbsoluteSize.Y>=44 and button.TextFits,'Settings control is not readable/active '..spec[2])
 table.insert(controls,{name=button.Name,width=button.AbsoluteSize.X,height=button.AbsoluteSize.Y,selected=button:GetAttribute('SettingSelected')})
end
out.settingsControls=controls`;
  return `local p=game.Players.LocalPlayer local g=assert(p.PlayerGui:FindFirstChild('PunchWallHUD'))
local h=assert(g:FindFirstChild('PixelPerfectHeroCityHUD')) local v=assert(workspace.CurrentCamera).ViewportSize
${viewport}
assert(h.AbsoluteSize.X>200 and h.AbsoluteSize.Y>200,'Degenerate safe HUD size')
local a=assert(g:FindFirstChild('PunchWallClientAutomation')) local s=a:Invoke('Snapshot')
assert(type(s)=='table' and s.ok==true,'Actual client Snapshot failed')
${gate}
local out={ok=true,device='${device}',screen='${screen}',viewport={x=v.X,y=v.Y},safePosition=tostring(h.AbsolutePosition),
 safeSize=tostring(h.AbsoluteSize),responsiveProfile=g:GetAttribute('ResponsiveProfile'),snapshot=s}
${settings}
return game.HttpService:JSONEncode(out)`;
}

export function decodeCapture(result) {
  assert(!result.isError, result.text || 'screen_capture failed');
  const images = (result.content || []).filter(item => item.type === 'image');
  assert.equal(images.length, 1, 'Expected one actual MCP image');
  const image = images[0]; assert.equal(image.mimeType, 'image/png', 'Expected actual PNG capture');
  assert(typeof image.data === 'string' && /^[A-Za-z0-9+/]+={0,2}$/.test(image.data), 'Malformed image base64');
  const bytes = Buffer.from(image.data, 'base64');
  assert(bytes.length > 45 && bytes.subarray(0, 8).equals(Buffer.from([137,80,78,71,13,10,26,10])), 'PNG signature missing');
  assert.equal(bytes.toString('ascii', 12, 16), 'IHDR', 'PNG header missing');
  assert.equal(bytes.readUInt32BE(8), 13, 'PNG IHDR size');
  const width = bytes.readUInt32BE(16), height = bytes.readUInt32BE(20);
  assert(width > 200 && height > 200 && width <= 16384 && height <= 16384, 'Degenerate actual capture dimensions');
  assert.equal(bytes.toString('ascii', bytes.length - 8, bytes.length - 4), 'IEND', 'PNG capture is truncated');
  return {bytes, width, height, sha256: sha(bytes), mimeType: image.mimeType};
}

export async function cleanupCaptureSession({stopPlay, resetDevice, closeMcp}) {
  const results = [];
  for (const [name, action] of [['stopPlay', stopPlay], ['resetDevice', resetDevice], ['closeMcp', closeMcp]]) {
    try { results.push({name, ok: true, result: await action()}); }
    catch (error) { results.push({name, ok: false, error: String(error.stack || error)}); }
  }
  return results;
}

async function run(options) {
  const directory = path.join(root, 'work/docs/evidence', options['evidence-leaf']);
  assert(!fs.existsSync(directory), 'Preserve prior visual evidence; choose a new leaf');
  fs.mkdirSync(directory); // Reserve this evidence directory without replacing prior evidence.
  const record = {ok: false, startedAt: new Date().toISOString(), kind: 'Actual Studio screen captures; no generated artwork or FPS claims',
    limitations: ['Built-in device emulation is not a physical phone GPU test.', 'PNG dimensions describe the actual MCP capture, not an assumed device raster.',
      'UI is routed through the real existing automation controllers; this is not a native-input gesture test.'], devices: []};
  let c, binding, selected = false, playAttempted = false, primary;
  const call = async (type, code) => {
    const result = await c.callTool('execute_luau', {datamodel_type: type, code}, 35000);
    assert(!result.isError, result.text); return JSON.parse(result.text);
  };
  const play = async start => {
    if (start) playAttempted = true;
    const result = await c.callTool('start_stop_play', {is_start: start}, 35000);
    assert(!result.isError, result.text);
    await waitForDataModels(c, start ? ['Server', 'Client'] : ['Edit'], 35000);
    if (!start) playAttempted = false;
  };
  const live = () => {
    const result = commandJSON(process.execPath, [path.join(root, 'work/automation/scripts/verify-studio-source.mjs'), options['studio-id'], pattern]);
    assertLiveBinding(result, options, binding.sources); return result;
  };
  try {
    binding = preflight(options); record.binding = binding; // No MCP process exists until all file prerequisites pass.
    const git = spawnSync('git', ['rev-parse', 'HEAD'], {cwd: root, encoding: 'utf8'});
    assert.equal(git.status, 0, git.stderr); record.repositoryCommit = git.stdout.trim();
    record.artifactBuildCommit = binding.manifest.sourceCommit;
    record.liveBefore = live();
    c = new McpClient(findStudioMcp(), 'smash-verified-final-visual-capture'); await c.initialize();
    record.studio = await selectStudioStrict(c, {studioInstanceId: options['studio-id'], studioName: pattern}); selected = true;
    await waitForDataModels(c, ['Edit'], 35000);
    for (const device of ['desktop', 'iphone17pro-landscape']) {
      const d = {device, captures: []}; record.devices.push(d);
      d.configuration = await call('Edit', device === 'desktop' ? LUA.desktop : LUA.phone);
      assert.equal(d.configuration.ok, true, 'Device configuration failed');
      await play(true); await sleep(7000);
      d.freshProfile = await call('Server', PROFILE_LUA.guard + "local s=a:Invoke('Snapshot') assert(type(s)=='table' and s.ok==true and s.Power==15 and s.Coins==0,'Expected fresh ephemeral starter profile') return H:JSONEncode({ok=true,power=s.Power,coins=s.Coins})");
      const capture = async screen => {
        const before = await call('Client', stateCode(device, screen));
        assert.equal(before.ok, true, 'Pre-capture state failed');
        const requestedAt = new Date().toISOString();
        const response = await c.callTool('screen_capture', {capture_id: device + '-' + screen}, 35000);
        const image = decodeCapture(response);
        const after = await call('Client', stateCode(device, screen));
        assert.equal(after.ok, true, 'Post-capture state failed');
        assert.deepEqual(after.viewport, before.viewport, 'Viewport changed during capture');
        const target = path.join(directory, device + '-' + screen + '.png');
        fs.writeFileSync(target, image.bytes, {flag: 'wx'});
        d.captures.push({screen, file: target, requestedAt, completedAt: new Date().toISOString(),
          width: image.width, height: image.height, bytes: image.bytes.length, sha256: image.sha256, mimeType: image.mimeType, before, after});
      };
      await capture('fresh-hud');
      d.seed = await call('Server', PROFILE_LUA.guard + PROFILE_LUA.seed);
      await sleep(1200);
      d.seedClient = await call('Client', PROFILE_LUA.clientReady);
      await call('Client', navigationCode('shop')); await sleep(700); await capture('shop');
      await call('Client', navigationCode('inventory', 'Fists')); await sleep(700); await capture('inventory-fists');
      await call('Client', navigationCode('inventory', 'Pets')); await sleep(700); await capture('inventory-pets');
      await call('Client', LUA.settings); await sleep(700); await capture('settings');
      await play(false);
    }
  } catch (error) { primary = error; record.error = String(error.stack || error); }
  finally {
    record.cleanup = await cleanupCaptureSession({
      stopPlay: async () => {
        if (!c || !selected || !playAttempted) return {skipped: true, reason: 'No owned Play attempt remains'};
        await play(false); return {ok: true, editAvailable: true};
      },
      resetDevice: async () => {
        if (!c || !selected) return {skipped: true, reason: 'No selected owned Studio'};
        return call('Edit', LUA.desktop);
      },
      closeMcp: () => { if (c) c.close(); return {ok: true}; },
    });
    const cleanupOK = record.cleanup.every(item => item.ok);
    if (binding && cleanupOK && !primary) {
      try {
        record.liveAfter = live(); const after = preflight(options);
        assert.deepEqual(after, binding, 'Artifact/source/manifest/reopen proof/tools changed during visual capture');
        record.postflightUnchanged = true;
      } catch (error) { primary = error; record.error = String(error.stack || error); }
    }
    record.ok = !primary && cleanupOK && record.postflightUnchanged === true && record.devices.length === 2 && record.devices.every(d => d.captures.length === 5);
    record.finishedAt = new Date().toISOString();
    try { fs.writeFileSync(path.join(directory, 'manifest.json'), JSON.stringify(record, null, 2), {flag: 'wx'}); }
    catch (error) { record.ok = false; record.evidenceWriteError = String(error.stack || error); }
    if (!record.ok) process.exitCode = 1;
    console.log(JSON.stringify({ok: record.ok, directory, captures: record.devices.flatMap(d => d.captures.map(capture => capture.file)),
      error: record.error, evidenceWriteError: record.evidenceWriteError, cleanup: record.cleanup}, null, 2));
  }
}

export async function selfTest() {
  let checks = 0;
  const check = (condition, label) => { assert(condition, label); checks++; };
  const rejects = (fn, label) => { assert.throws(fn, undefined, label); checks++; };
  const dependency = await profileSelfTest();
  check(dependency.ok && dependency.studioUsed === false, 'Shared artifact/live/seed/cleanup contracts');
  rejects(() => stateCode('imaginary', 'shop'), 'Unknown device rejected');
  rejects(() => stateCode('desktop', 'checkout'), 'Unknown screen rejected');
  rejects(() => decodeCapture({isError: true, text: 'injected capture failure'}), 'MCP capture error rejected');
  rejects(() => decodeCapture({content: []}), 'No actual image rejected');
  rejects(() => decodeCapture({content: [{type: 'image', mimeType: 'image/jpeg', data: 'AA=='}]}), 'Wrong capture format rejected');
  rejects(() => decodeCapture({content: [{type: 'image', mimeType: 'image/png', data: '../bad'}]}), 'Invalid image data rejected');
  const pngHeader = Buffer.alloc(50); Buffer.from([137,80,78,71,13,10,26,10]).copy(pngHeader); pngHeader.writeUInt32BE(13,8);
  pngHeader.write('IHDR',12); pngHeader.writeUInt32BE(874,16); pngHeader.writeUInt32BE(402,20); pngHeader.write('IEND',42);
  const response = data => ({content: [{type: 'image', mimeType: 'image/png', data: data.toString('base64')}]});
  const parsed = decodeCapture(response(pngHeader)); check(parsed.width === 874 && parsed.height === 402, 'Read actual PNG dimensions');
  const zero = Buffer.from(pngHeader); zero.writeUInt32BE(0,16); rejects(() => decodeCapture(response(zero)), 'Degenerate image rejected');
  rejects(() => decodeCapture(response(pngHeader.subarray(0,45))), 'Truncated PNG rejected');
  let reset = 0, closed = 0;
  const cleanup = await cleanupCaptureSession({stopPlay: () => {throw Error('injected stop failure');}, resetDevice: () => {reset++;}, closeMcp: () => {closed++;}});
  check(!cleanup[0].ok && reset === 1 && closed === 1, 'Stop failure does not skip simulator reset/MCP close');
  const other = await cleanupCaptureSession({stopPlay: () => true, resetDevice: () => {throw Error('injected reset failure');}, closeMcp: () => {closed++;}});
  check(!other[1].ok && closed === 2, 'Simulator reset failure does not skip MCP close');
  const tempRoot = os.tmpdir();
  const compiler = process.env.LUAU_COMPILE_COMMAND || fs.readdirSync(tempRoot).filter(name => name.startsWith('codex-luau-')).sort().reverse()
    .map(name => path.join(tempRoot, name, process.platform === 'win32' ? 'luau-compile.exe' : 'luau-compile')).find(fs.existsSync);
  assert(compiler, 'BLOCKED: LUAU_COMPILE_COMMAND required');
  const snippets = [LUA.desktop, LUA.phone, LUA.settings,
    ...['desktop', 'iphone17pro-landscape'].flatMap(device => ['fresh-hud', 'shop', 'inventory-fists', 'inventory-pets', 'settings'].map(screen => stateCode(device, screen)))];
  const directory = fs.mkdtempSync(path.join(tempRoot, 'smash-final-visual-capture-'));
  let executedStateAssertions = 0;
  try {
    for (const [index, snippet] of snippets.entries()) {
      const target = path.join(directory, `${index}.luau`); fs.writeFileSync(target, snippet);
      const result = spawnSync(compiler, ['--null', target], {encoding: 'utf8', timeout: 15000});
      check(result.status === 0, `Snippet ${index}: ${result.stderr || result.stdout}`);
    }
    const cases = [];
    for (const device of ['desktop', 'iphone17pro-landscape']) for (const screen of ['fresh-hud', 'shop', 'inventory-fists', 'inventory-pets', 'settings']) {
      const setup = `
local v={X=${device === 'desktop' ? 1200 : 874},Y=${device === 'desktop' ? 800 : 402}}
local h={Visible=true,AbsoluteSize={X=800,Y=350},AbsolutePosition='safe position'}
local names=${screen === 'inventory-fists' ? "{'Starter Glove','Boxing Glove','Iron Knuckle','Thunder Fist','Titan Gauntlet'}" : "{'Forest Pup','Forest Pup','Miner Cat'}"}
local inv={ok=true,visible=true,category='${screen === 'inventory-fists' ? 'Fists' : 'Pets'}',visibleNames=names,
 layout={insideSafeArea=true,boundsSafe=true,allTextFits=true,noOverlap=true}}
local s={ok=true,menuVisible=${['shop', 'settings'].includes(screen)},shopVisible=${screen === 'shop'},
 inventoryVisible=${screen.startsWith('inventory')},settingsVisible=${screen === 'settings'},rebirthVisible=false,spinVisible=false,
 activeTab='Fists',shopPage='Fists',inventory=inv}
local button={Name='mock actual control',Visible=true,Active=true,Selectable=true,TextFits=true,AbsoluteSize={X=78,Y=44},
 IsA=function() return true end,GetAttribute=function() return true end}
local parent={FindFirstChild=function() return button end}
local row={FindFirstChild=function(_,name) return name=='Options' and parent or button end}
local body={FindFirstChild=function() return row end}
local panel={Visible=true,FindFirstChild=function() return body end}
local automation={Invoke=function() return s end}
local g={SettingsWindow=panel,GetAttribute=function() return 'actual profile' end,
 FindFirstChild=function(_,name) return name=='PixelPerfectHeroCityHUD' and h or automation end}
local player={PlayerGui={FindFirstChild=function() return g end}}
local game={Players={LocalPlayer=player},HttpService={JSONEncode=function(_,value) return value end}}
local workspace={CurrentCamera={ViewportSize=v}}
`;
      const wrong = screen === 'fresh-hud' ? 's.menuVisible=true' : screen === 'shop' ? 's.shopVisible=false'
        : screen === 'settings' ? 's.settingsVisible=false' : "s.inventory.category='Wrong'";
      for (const [mutation, shouldPass] of [['', true], [wrong, false], ['v.X=10', false],
        ...(screen.startsWith('inventory') ? [["s.inventory.visibleNames={}", false], ['s.inventory.layout.allTextFits=false', false]] : []),
        ...(screen === 'settings' ? [['button.AbsoluteSize.Y=40', false], ['button.TextFits=false', false]] : [])]) {
        cases.push(`do ${setup}\n${mutation}\nlocal ok=pcall(function() ${stateCode(device, screen)} end) assert(ok==${shouldPass},'actual_state_guard_${device}_${screen}') count+=1 end`);
      }
    }
    const stateTest = 'local count=0\n' + cases.join('\n') + "\nprint('PASS '..count)";
    const target = path.join(directory, 'state-execution.luau'); fs.writeFileSync(target, stateTest);
    const runtime = path.join(path.dirname(compiler), process.platform === 'win32' ? 'luau.exe' : 'luau');
    const result = spawnSync(runtime, [target], {encoding: 'utf8', timeout: 15000});
    check(result.status === 0 && result.stdout.trim() === `PASS ${cases.length}`, `Exact screen-state execution: ${result.stderr || result.stdout}`);
    executedStateAssertions = cases.length;
  } finally { for (const item of fs.readdirSync(directory)) fs.unlinkSync(path.join(directory, item)); fs.rmdirSync(directory); }
  return {ok: true, checks, compiledSnippets: snippets.length, executedStateAssertions, sharedProfilerContract: dependency, studioUsed: false};
}

if (process.argv[1] && path.resolve(process.argv[1]) === filename) {
  try {
    if (process.argv.length === 3 && process.argv[2] === '--self-test') console.log(JSON.stringify(await selfTest(), null, 2));
    else await run(parseArgs(process.argv.slice(2)));
  } catch (error) { console.error(error.stack || error); process.exitCode = 1; }
}
