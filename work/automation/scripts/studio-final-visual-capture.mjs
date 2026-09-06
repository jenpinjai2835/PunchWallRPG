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

const captureCRCTable = Uint32Array.from({length: 256}, (_, value) => {
  for (let bit = 0; bit < 8; bit++) value = value & 1 ? 0xedb88320 ^ (value >>> 1) : value >>> 1;
  return value >>> 0;
});
function captureCRC(bytes) {
  let value = 0xffffffff;
  for (const byte of bytes) value = captureCRCTable[(value ^ byte) & 255] ^ (value >>> 8);
  return (value ^ 0xffffffff) >>> 0;
}

export function decodeCapture(result) {
  assert(!result.isError, result.text || 'screen_capture failed');
  const images = (result.content || []).filter(item => item.type === 'image');
  assert.equal(images.length, 1, 'Expected one actual MCP image');
  const image = images[0]; assert(['image/png', 'image/jpeg'].includes(image.mimeType), 'Expected original PNG or JPEG capture');
  assert(typeof image.data === 'string' && image.data.length <= 128 * 1024 * 1024
    && image.data.length % 4 === 0 && /^[A-Za-z0-9+/]+={0,2}$/.test(image.data), 'Malformed image base64');
  const bytes = Buffer.from(image.data, 'base64');
  assert.equal(bytes.toString('base64'), image.data, 'Noncanonical image base64');
  let width, height, extension;
  if (image.mimeType === 'image/png') {
    extension = '.png';
    assert(bytes.length > 45 && bytes.subarray(0, 8).equals(Buffer.from([137,80,78,71,13,10,26,10])), 'PNG signature missing');
    let offset = 8, dataSeen = false, ended = false;
    while (offset < bytes.length) {
      assert(offset + 12 <= bytes.length, 'Truncated PNG chunk header');
      const length = bytes.readUInt32BE(offset), end = offset + 12 + length;
      assert(length <= 0x7fffffff && end <= bytes.length, 'Truncated PNG chunk payload');
      const kind = bytes.toString('ascii', offset + 4, offset + 8);
      assert(/^[A-Za-z]{4}$/.test(kind), 'Invalid PNG chunk type');
      assert.equal(captureCRC(bytes.subarray(offset + 4, end - 4)), bytes.readUInt32BE(end - 4), 'PNG chunk CRC mismatch');
      if (offset === 8) {
        assert(kind === 'IHDR' && length === 13, 'PNG IHDR missing or invalid');
        width = bytes.readUInt32BE(offset + 8); height = bytes.readUInt32BE(offset + 12);
        const depths = {0: [1,2,4,8,16], 2: [8,16], 3: [1,2,4,8], 4: [8,16], 6: [8,16]};
        assert(depths[bytes[offset + 17]]?.includes(bytes[offset + 16]) && bytes[offset + 18] === 0
          && bytes[offset + 19] === 0 && bytes[offset + 20] <= 1, 'Invalid PNG image header encoding');
      } else assert(kind !== 'IHDR', 'Duplicate PNG IHDR');
      if (kind === 'IDAT' && length > 0) dataSeen = true;
      if (kind === 'IEND') {
        assert(length === 0 && dataSeen && end === bytes.length, 'Incomplete PNG or bytes after IEND');
        ended = true; break;
      }
      offset = end;
    }
    assert(ended, 'PNG capture is truncated');
  } else {
    extension = '.jpg';
    assert(bytes.length > 4 && bytes[0] === 0xff && bytes[1] === 0xd8, 'JPEG SOI signature missing');
    // ITU T.81 marker segments, including progressive multi-scan images. This
    // validates the original container/header bounds; it does not transcode pixels.
    let offset = 2, scanning = false, scans = 0, entropyBytes = 0, ended = false, components;
    while (offset < bytes.length) {
      if (scanning && bytes[offset] !== 0xff) { offset++; entropyBytes++; continue; }
      assert.equal(bytes[offset++], 0xff, 'JPEG marker prefix missing');
      while (offset < bytes.length && bytes[offset] === 0xff) offset++;
      assert(offset < bytes.length, 'Truncated JPEG marker');
      const marker = bytes[offset++];
      if (scanning && marker === 0) { entropyBytes++; continue; }
      if (scanning && marker >= 0xd0 && marker <= 0xd7) continue;
      scanning = false;
      if (marker === 0xd9) {
        assert(width && scans > 0 && entropyBytes > 0 && offset === bytes.length, 'Incomplete JPEG or bytes after EOI');
        ended = true; break;
      }
      assert(marker !== 0 && marker !== 0xd8 && marker !== 1 && !(marker >= 0xd0 && marker <= 0xd7), 'Unexpected JPEG standalone marker');
      assert(offset + 2 <= bytes.length, 'Truncated JPEG segment length');
      const length = bytes.readUInt16BE(offset), end = offset + length;
      assert(length >= 2 && end <= bytes.length, 'Truncated JPEG segment payload');
      if (marker >= 0xc0 && marker <= 0xcf && ![0xc4, 0xc8, 0xcc].includes(marker)) {
        assert(!width && length >= 8, 'Duplicate or incomplete JPEG frame header');
        components = bytes[offset + 7];
        assert(components > 0 && length === 8 + 3 * components, 'Invalid JPEG frame component length');
        const precision = bytes[offset + 2];
        assert(marker === 0xc0 ? precision === 8 : precision >= 2 && precision <= 16, 'Invalid JPEG sample precision');
        height = bytes.readUInt16BE(offset + 3); width = bytes.readUInt16BE(offset + 5);
      }
      if (marker === 0xda) {
        assert(width && length >= 6 && bytes[offset + 2] > 0 && bytes[offset + 2] <= components
          && length === 6 + 2 * bytes[offset + 2], 'Invalid JPEG scan header');
        scans++; scanning = true;
      }
      offset = end;
    }
    assert(ended, 'JPEG capture is truncated');
  }
  assert(width > 200 && height > 200 && width <= 16384 && height <= 16384, 'Degenerate actual capture dimensions');
  return {bytes, width, height, sha256: sha(bytes), mimeType: image.mimeType, extension};
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
    limitations: ['Built-in device emulation is not a physical phone GPU test.', 'Image header dimensions describe the original MCP capture, not an assumed device raster.',
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
        const target = path.join(directory, device + '-' + screen + image.extension);
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
  rejects(() => decodeCapture({content: [{type: 'image', mimeType: 'image/jpeg', data: 'AA=='}]}), 'Malformed JPEG capture rejected');
  rejects(() => decodeCapture({content: [{type: 'image', mimeType: 'image/png', data: '../bad'}]}), 'Invalid image data rejected');
  // Complete, independently encoded Pillow fixtures (256x224), not fabricated headers.
  const png = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAQAAAADgCAIAAABjIy8HAAACbUlEQVR4nO3TQQEAEADAQKSRRAj9g4jhsbsE+2zucwdUrd8B8JMBSDMAaQYgzQCkGYA0A5BmANIMQJoBSDMAaQYgzQCkGYA0A5BmANIMQJoBSDMAaQYgzQCkGYA0A5BmANIMQJoBSDMAaQYgzQCkGYA0A5BmANIMQJoBSDMAaQYgzQCkGYA0A5BmANIMQJoBSDMAaQYgzQCkGYA0A5BmANIMQJoBSDMAaQYgzQCkGYA0A5BmANIMQJoBSDMAaQYgzQCkGYA0A5BmANIMQJoBSDMAaQYgzQCkGYA0A5BmANIMQJoBSDMAaQYgzQCkGYA0A5BmANIMQJoBSDMAaQYgzQCkGYA0A5BmANIMQJoBSDMAaQYgzQCkGYA0A5BmANIMQJoBSDMAaQYgzQCkGYA0A5BmANIMQJoBSDMAaQYgzQCkGYA0A5BmANIMQJoBSDMAaQYgzQCkGYA0A5BmANIMQJoBSDMAaQYgzQCkGYA0A5BmANIMQJoBSDMAaQYgzQCkGYA0A5BmANIMQJoBSDMAaQYgzQCkGYA0A5BmANIMQJoBSDMAaQYgzQCkGYA0A5BmANIMQJoBSDMAaQYgzQCkGYA0A5BmANIMQJoBSDMAaQYgzQCkGYA0A5BmANIMQJoBSDMAaQYgzQCkGYA0A5BmANIMQJoBSDMAaQYgzQCkGYA0A5BmANIMQJoBSDMAaQYgzQCkGYA0A5BmANIMQJoBSDMAaQYgzQCkGYA0A5BmANIMQJoBSDMAaQYgzQCkGYA0A5BmANIMQJoBSDMAaQYgzQCkGYA0A5BmANIMQJoBSDMAaQYgzQCkGYA0AzDKHlORAoiZuxHGAAAAAElFTkSuQmCC', 'base64');
  const jpeg = Buffer.from('/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wAARCADgAQADASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAf/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFQEBAQAAAAAAAAAAAAAAAAAAAAT/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIRAxEAPwCfALUAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD//2Q==', 'base64');
  const progressive = Buffer.from('/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wgARCADgAQADASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAb/xAAWAQEBAQAAAAAAAAAAAAAAAAAAAwT/2gAMAwEAAhADEAAAAZ4WzgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAf//EABQQAQAAAAAAAAAAAAAAAAAAAJD/2gAIAQEAAQUCYD//xAAUEQEAAAAAAAAAAAAAAAAAAABw/9oACAEDAQE/AWD/xAAUEQEAAAAAAAAAAAAAAAAAAABw/9oACAECAQE/AWD/xAAUEAEAAAAAAAAAAAAAAAAAAACQ/9oACAEBAAY/AmA//8QAFBABAAAAAAAAAAAAAAAAAAAAkP/aAAgBAQABPyFgP//aAAwDAQACAAMAAAAQ/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/8QAFBEBAAAAAAAAAAAAAAAAAAAAcP/aAAgBAwEBPxBg/8QAFBEBAAAAAAAAAAAAAAAAAAAAcP/aAAgBAgEBPxBg/8QAFBABAAAAAAAAAAAAAAAAAAAAkP/aAAgBAQABPxBgP//Z', 'base64');
  const response = (data, mimeType = 'image/png') => ({content: [{type: 'image', mimeType, data: data.toString('base64')}]});
  for (const [original, mime, extension] of [[png, 'image/png', '.png'], [jpeg, 'image/jpeg', '.jpg'], [progressive, 'image/jpeg', '.jpg']]) {
    const parsed = decodeCapture(response(original, mime));
    check(parsed.width === 256 && parsed.height === 224 && parsed.mimeType === mime && parsed.extension === extension, 'Read exact original header/MIME/extension');
    check(parsed.bytes.equals(original) && parsed.sha256 === sha(original), 'Original capture bytes and hash preserved without transcoding');
    rejects(() => decodeCapture(response(original.subarray(0, original.length - 1), mime)), 'Truncated original rejected');
    rejects(() => decodeCapture(response(Buffer.concat([original, Buffer.from([0])]), mime)), 'Trailing bytes rejected');
  }
  rejects(() => decodeCapture(response(png, 'image/jpeg')), 'PNG bytes cannot masquerade as JPEG');
  rejects(() => decodeCapture(response(jpeg, 'image/png')), 'JPEG bytes cannot masquerade as PNG');
  rejects(() => decodeCapture(response(jpeg, 'image/gif')), 'Unsupported capture MIME rejected');
  rejects(() => decodeCapture({content: [response(png).content[0], response(jpeg, 'image/jpeg').content[0]]}), 'Multiple ambiguous image blocks rejected');
  const dimensionPNG = (width, height) => {const copy = Buffer.from(png); copy.writeUInt32BE(width, 16); copy.writeUInt32BE(height, 20); copy.writeUInt32BE(captureCRC(copy.subarray(12,29)),29); return copy;};
  rejects(() => decodeCapture(response(dimensionPNG(0,224))), 'Zero PNG width rejected');
  rejects(() => decodeCapture(response(dimensionPNG(256,200))), 'Degenerate PNG height rejected');
  rejects(() => decodeCapture(response(dimensionPNG(16385,224))), 'Out-of-bounds PNG width rejected');
  const corruptPNG = Buffer.from(png); corruptPNG[corruptPNG.length - 5] ^= 1;
  rejects(() => decodeCapture(response(corruptPNG)), 'Corrupt PNG CRC rejected');
  const badEncodingPNG = Buffer.from(png); badEncodingPNG[25] = 5; badEncodingPNG.writeUInt32BE(captureCRC(badEncodingPNG.subarray(12,29)),29);
  rejects(() => decodeCapture(response(badEncodingPNG)), 'Invalid PNG color type rejected despite correct CRC');
  const overrunPNG = Buffer.from(png); overrunPNG.writeUInt32BE(0x7fffffff,33);
  rejects(() => decodeCapture(response(overrunPNG)), 'PNG chunk length overrun rejected');
  const fakeHeader = Buffer.alloc(50); png.subarray(0,33).copy(fakeHeader); fakeHeader.write('IEND',42);
  rejects(() => decodeCapture(response(fakeHeader)), 'Old fabricated PNG header without image stream rejected');
  const frame = jpeg.indexOf(Buffer.from([0xff,0xc0])); assert(frame > 0);
  const dimensionJPEG = (width, height) => {const copy = Buffer.from(jpeg); copy.writeUInt16BE(width,frame+7); copy.writeUInt16BE(height,frame+5); return copy;};
  rejects(() => decodeCapture(response(dimensionJPEG(0,224),'image/jpeg')), 'Zero JPEG width rejected');
  rejects(() => decodeCapture(response(dimensionJPEG(256,200),'image/jpeg')), 'Degenerate JPEG height rejected');
  rejects(() => decodeCapture(response(dimensionJPEG(256,16385),'image/jpeg')), 'Out-of-bounds JPEG height rejected');
  const overrunJPEG = Buffer.from(jpeg); overrunJPEG.writeUInt16BE(65535,4);
  rejects(() => decodeCapture(response(overrunJPEG,'image/jpeg')), 'JPEG segment length overrun rejected');
  const shortJPEG = Buffer.from(jpeg); shortJPEG.writeUInt16BE(1,4);
  rejects(() => decodeCapture(response(shortJPEG,'image/jpeg')), 'JPEG segment length below two rejected');
  const badFrame = Buffer.from(jpeg); badFrame[frame+9] = 0;
  rejects(() => decodeCapture(response(badFrame,'image/jpeg')), 'JPEG frame component count mismatch rejected');
  const badPrecision = Buffer.from(jpeg); badPrecision[frame+4] = 0;
  rejects(() => decodeCapture(response(badPrecision,'image/jpeg')), 'Invalid JPEG precision rejected');
  const scan = jpeg.indexOf(Buffer.from([0xff,0xda])); assert(scan > frame);
  const emptyScan = Buffer.concat([jpeg.subarray(0,scan+2+jpeg.readUInt16BE(scan+2)),Buffer.from([0xff,0xd9])]);
  rejects(() => decodeCapture(response(emptyScan,'image/jpeg')), 'JPEG header without entropy scan rejected');
  const metadataEOI = Buffer.concat([jpeg.subarray(0,2),Buffer.from([0xff,0xfe,0,4,0xff,0xd9]),jpeg.subarray(2)]);
  check(decodeCapture(response(metadataEOI,'image/jpeg')).bytes.equals(metadataEOI), 'EOI-like metadata bytes do not truncate a valid JPEG');
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
