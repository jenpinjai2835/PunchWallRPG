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

// Reset is a showcase fixture, not an assertion that the Studio account owns no passes.
// Real entitlement reconciliation must finish before the ephemeral reset can be stable.
const freshProfileCheck = `local G=require(game.ReplicatedStorage.GameConfig)
local function reconciled()
 local pending=p:GetAttribute('PendingGamePassGrantCount')
 return p:GetAttribute('GamePassOwnershipReconciled')==true
  and p:GetAttribute('GamePassOwnershipReconciliationFailed')==false and (pending==nil or pending==0)
end
local function starterProfile(snapshot)
 assert(reconciled(),'Entitlements are not completely reconciled with an empty pending queue')
 local stats=assert(p:FindFirstChild('RPGStats')) local leader=assert(p:FindFirstChild('leaderstats'))
 local expected={Power=15,Coins=0,FistMastery=1,FistMultiplier=1,PetMultiplier=0,Rebirths=0,HonorPowerBonus=0,
  TutorialStep=1,TutorialVersion=2,TutorialCompleted=0,TrainingActive=0,EquippedFist='Starter Glove',Pet='None',EquippedHonorItem='None'}
 for key,value in pairs(expected) do
  local stat=assert(stats:FindFirstChild(key) or leader:FindFirstChild(key),'Missing starter stat '..key)
  assert(stat.Value==value,'Not a reset starter stat '..key)
  if snapshot then assert(snapshot[key]==value,'Authoritative snapshot differs '..key) end
 end
 for _,key in ipairs({'OwnedPremiumFistsJSON','OwnedPremiumPetsJSON','PetInventoryJSON','EquippedPetsJSON','OwnedHonorItemsJSON','DiscoveredPetsJSON','LockedPetsJSON','OwnedFistsJSON'}) do
  local raw=assert(stats:FindFirstChild(key),'Missing starter list '..key).Value local list=H:JSONDecode(raw)
  assert(type(list)=='table','Invalid starter list '..key)
  local count=0 for _ in pairs(list) do count+=1 end
  assert(key=='OwnedFistsJSON' and count==1 and list[1]=='Starter Glove' or key~='OwnedFistsJSON' and count==0,'Not a reset starter list '..key)
  if snapshot then assert(snapshot[key]==raw,'Authoritative starter list differs '..key) end
 end
 local effective=G.EffectivePower(15,1,0,0,1,0)
 assert(type(effective)=='number' and effective==effective and effective>15 and effective<16,'Unexpected starter power formula')
 if snapshot then assert(math.abs(snapshot.EffectivePower-effective)<1e-8,'Authoritative effective power differs') end
 return {kind='Reset starter fixture after entitlement reconciliation',power=15,coins=0,fist='Starter Glove',pets=0,
  expectedEffectivePower=effective,pendingGrants=p:GetAttribute('PendingGamePassGrantCount') or 0,reconciled=true}
end
`;
const freshVisualCheck = `local function starterVisual()
 local profile=starterProfile(nil)
 local power=assert(h:FindFirstChild('PowerValue',true)) local coins=assert(h:FindFirstChild('CoinsValue',true))
 assert(power:IsA('TextLabel') and power.Visible and power.Text==tostring(math.floor(profile.expectedEffectivePower+.5)),'Starter power HUD is stale')
 assert(coins:IsA('TextLabel') and coins.Visible and coins.Text=='0','Starter coin HUD is stale')
 local companions=workspace:FindFirstChild(p.Name..' Client Companions') local models=0
 if companions then for _,item in ipairs(companions:GetChildren()) do if item:IsA('Model') then models+=1 end end end
 assert(models==0,'Premium or seeded companions remain in the starter showcase')
 local character=assert(p.Character) local fist=assert(character:FindFirstChild('Equipped Kaiju Gauntlet'))
 assert(fist:GetAttribute('FistVisualKey')=='Starter Glove' and fist:GetAttribute('VisualSource')=='SharedCatalogGeometry','Starter equipped model is stale')
 assert(g:GetAttribute('OnboardingObjectiveReady')==true and g:GetAttribute('OnboardingObjectiveStep')==1
  and g:GetAttribute('OnboardingTutorialCompleted')==false,'Starter onboarding is stale')
 profile.powerText=power.Text profile.coinText=coins.Text profile.companions=models profile.onboardingStep=1
 return profile
end
local function cleanFeedback()
 local s=a:Invoke('Snapshot') assert(s.ok==true and s.feedbackCount==0 and s.lastFeedbackType==nil and s.lastFeedbackTarget==nil,'Fresh feedback arrived after settlement')
 local toasts=assert(g:FindFirstChild('Toasts'))
 for _,child in ipairs(toasts:GetChildren()) do assert(not child:IsA('TextLabel'),'Starter toast remains') end
 return s
end
`;

export const LUA = {
  freshServer: PROFILE_LUA.guard + freshProfileCheck + `
local deadline=os.clock()+25
while not reconciled() and os.clock()<deadline do
 assert(p:GetAttribute('GamePassOwnershipReconciliationFailed')~=true,'Entitlement reconciliation exhausted its retries') task.wait(.1)
end
assert(reconciled(),'Timed out waiting for entitlement reconciliation; Reset was not invoked')
local before=a:Invoke('Snapshot') assert(type(before)=='table' and before.ok==true,'Pre-reset snapshot failed')
local reset=a:Invoke('Reset') assert(type(reset)=='table' and reset.ok==true,'Ephemeral starter Reset failed')
local s=a:Invoke('Snapshot') assert(type(s)=='table' and s.ok==true,'Starter snapshot failed')
local profile=starterProfile(s)
return H:JSONEncode({ok=true,profile=profile,beforeReset={power=before.Power,effectivePower=before.EffectivePower,
 equippedFist=before.EquippedFist,premiumFists=before.OwnedPremiumFistsJSON,premiumPets=before.OwnedPremiumPetsJSON,pets=before.PetInventoryJSON}})`,
  freshServerRead: PROFILE_LUA.guard + freshProfileCheck + `local s=a:Invoke('Snapshot') assert(type(s)=='table' and s.ok==true,'Starter snapshot failed') return H:JSONEncode({ok=true,profile=starterProfile(s)})`,
  freshClient: `local p=game.Players.LocalPlayer local H=game:GetService('HttpService') local g=assert(p.PlayerGui:FindFirstChild('PunchWallHUD'))
local h=assert(g:FindFirstChild('PixelPerfectHeroCityHUD')) local a=assert(g:FindFirstChild('PunchWallClientAutomation'))
${freshProfileCheck}${freshVisualCheck}
assert(a:Invoke('CloseMenus')==true,'CloseMenus before starter capture failed')
local deadline=os.clock()+8 local ready,profile
repeat ready,profile=pcall(starterVisual) if not ready then task.wait(.1) end until ready or os.clock()>=deadline
assert(ready,'Starter replication/visual settlement failed: '..tostring(profile))
local priorFeedback=a:Invoke('Snapshot') assert(priorFeedback.ok==true,'Pre-clear client snapshot failed')
assert(a:Invoke('ClearToasts')==true,'ClearToasts failed') local cleared=a:Invoke('ClearMarkers') assert(cleared.ok==true,'ClearMarkers failed')
task.wait(.5) profile=starterVisual() cleanFeedback()
return H:JSONEncode({ok=true,profile=profile,priorFeedback={count=priorFeedback.feedbackCount,type=priorFeedback.lastFeedbackType,target=priorFeedback.lastFeedbackTarget}})`,
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
local orientation=S:GetOrientationAsync() local scaling=S:GetScalingModeAsync()
assert(S:GetDeviceAsync()==matches[1].id and matches[1].id=='iphone_17_pro' and size.X==874 and size.Y==402
 and orientation==Enum.ScreenOrientation.LandscapeLeft and scaling==Enum.DeviceSimulatorScalingMode.FitToWindow,'Actual built-in iPhone landscape configuration mismatch')
return game.HttpService:JSONEncode({ok=true,id=matches[1].id,name=matches[1].name,custom=false,width=size.X,height=size.Y,orientation=orientation.Name,scaling=scaling.Name})`,
  settings: `local a=game.Players.LocalPlayer.PlayerGui.PunchWallHUD.PunchWallClientAutomation
assert(a:Invoke('CloseMenus')==true,'CloseMenus before Settings failed')
assert(a:Invoke('OpenSettings')==true,'OpenSettings failed')
return game.HttpService:JSONEncode({ok=true})`,
};

export function stateCode(device, screen) {
  assert(['desktop', 'iphone17pro-landscape'].includes(device), 'Unknown device');
  assert(['fresh-hud', 'shop', 'inventory-fists', 'inventory-pets', 'settings'].includes(screen), 'Unknown screen');
  const viewport = device === 'desktop'
    ? "assert(S:GetDeviceAsync()=='default' and v.X>=900 and v.Y>=600,'Maximize desktop Studio viewport and disable emulation before capture')"
    : `local id=S:GetDeviceAsync() local info=S:GetDeviceInfoAsync(id) local resolution=S:GetResolutionAsync()
local orientation=S:GetOrientationAsync() local scaling=S:GetScalingModeAsync()
assert(id=='iphone_17_pro' and info.IsCustom==false and info.Name:lower():gsub('%s','')=='iphone17pro'
 and resolution.X==874 and resolution.Y==402 and orientation==Enum.ScreenOrientation.LandscapeLeft
 and scaling==Enum.DeviceSimulatorScalingMode.FitToWindow,'Client is not the verified built-in iPhone landscape configuration')
assert(math.abs(areas.full.size.x-resolution.X)<=1 and math.abs(areas.full.size.y-resolution.Y)<=1,'Full UI area differs from device resolution beyond one-unit native boundary rounding')
configuration={id=id,name=info.Name,custom=info.IsCustom,resolution={x=resolution.X,y=resolution.Y},
 resolutionScale=info.ResolutionScale,presetPixelDensity=info.PixelDensity,activePixelDensity=S:GetPixelDensityAsync(),orientation=orientation.Name,scaling=scaling.Name}`;
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
  return `local p=game.Players.LocalPlayer local H=game:GetService('HttpService') local g=assert(p.PlayerGui:FindFirstChild('PunchWallHUD'))
local h=assert(g:FindFirstChild('PixelPerfectHeroCityHUD')) local v=assert(workspace.CurrentCamera).ViewportSize
local S=game:GetService('StudioDeviceSimulatorService') local U=game:GetService('GuiService')
local function finite(value) return type(value)=='number' and value==value and value>-math.huge and value<math.huge end
local function area(kind)
 local r=U:GetInsetArea(kind) local x,y=r.Max.X-r.Min.X,r.Max.Y-r.Min.Y
 assert(finite(x) and finite(y) and finite(r.Min.X) and finite(r.Min.Y) and x>0 and y>0 and x<=16384 and y<=16384,'Invalid native screen area')
 return {min={x=r.Min.X,y=r.Min.Y},max={x=r.Max.X,y=r.Max.Y},size={x=x,y=y}}
end
local areas={full=area(Enum.ScreenInsets.None),deviceSafe=area(Enum.ScreenInsets.DeviceSafeInsets),coreSafe=area(Enum.ScreenInsets.CoreUISafeInsets)}
local function contained(inner,outer) return inner.min.x>=outer.min.x and inner.min.y>=outer.min.y and inner.max.x<=outer.max.x and inner.max.y<=outer.max.y end
assert(contained(areas.deviceSafe,areas.full) and contained(areas.coreSafe,areas.deviceSafe),'Native inset rectangles are inconsistent')
assert(v.X==areas.deviceSafe.size.x and v.Y==areas.deviceSafe.size.y,'Camera ViewportSize must equal the independently observed device-safe UI area')
assert(g.ScreenInsets==Enum.ScreenInsets.DeviceSafeInsets and g.IgnoreGuiInset==true and g.ClipToDeviceSafeArea==true,'Unexpected production HUD inset configuration')
assert(h.AbsolutePosition.X==areas.deviceSafe.min.x and h.AbsolutePosition.Y==areas.deviceSafe.min.y
 and h.AbsoluteSize.X==areas.deviceSafe.size.x and h.AbsoluteSize.Y==areas.deviceSafe.size.y,'HUD root does not match the actual safe area')
local configuration={id='default',emulated=false}
${viewport}
assert(h.AbsoluteSize.X>200 and h.AbsoluteSize.Y>200,'Degenerate safe HUD size')
local a=assert(g:FindFirstChild('PunchWallClientAutomation')) local s=a:Invoke('Snapshot')
assert(type(s)=='table' and s.ok==true,'Actual client Snapshot failed')
${gate}
local out={ok=true,device='${device}',screen='${screen}',viewport={x=v.X,y=v.Y},safePosition=tostring(h.AbsolutePosition),
 safeSize=tostring(h.AbsoluteSize),areas=areas,deviceConfiguration=configuration,viewportMeaning='Device-safe Roblox UI units; not full render raster',
 responsiveProfile=g:GetAttribute('ResponsiveProfile'),snapshot=s}
${screen === 'fresh-hud' ? freshProfileCheck + freshVisualCheck + 'out.freshProfile=starterVisual() cleanFeedback()' : ''}
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

export function assertCaptureArea(image, before, after) {
  for (const key of ['viewport', 'areas', 'deviceConfiguration', 'safePosition', 'safeSize']) {
    assert.deepEqual(after[key], before[key], `Native ${key} changed during capture`);
  }
  const full = before.areas?.full?.size;
  assert(full && Number.isFinite(full.x) && Number.isFinite(full.y) && full.x > 200 && full.y > 200, 'Missing actual full UI area');
  assert(Number.isInteger(image.width) && Number.isInteger(image.height) && image.width > 200 && image.height > 200
    && image.width <= 16384 && image.height <= 16384, 'Invalid original raster dimensions');
  // FitToWindow scales the full rendering area; allow only one raster edge's rounding.
  const residual = Math.abs(image.height - image.width * full.y / full.x);
  assert(residual <= 1, 'Original screenshot aspect does not match the actual full render area');
  return {fullUIArea: full, scaleX: image.width / full.x, scaleY: image.height / full.y, aspectResidualPixels: residual,
    meaning: 'Original full-area MCP raster; UI offset units and device preset resolution are recorded separately'};
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
      d.clientConfiguration = await call('Client', device === 'desktop' ? LUA.desktop : LUA.phone);
      assert.equal(d.clientConfiguration.ok, true, 'Client device configuration failed');
      d.freshProfile = await call('Server', LUA.freshServer);
      d.freshClient = await call('Client', LUA.freshClient);
      const capture = async screen => {
        const serverBefore = screen === 'fresh-hud' ? await call('Server', LUA.freshServerRead) : undefined;
        const before = await call('Client', stateCode(device, screen));
        assert.equal(before.ok, true, 'Pre-capture state failed');
        const requestedAt = new Date().toISOString();
        const response = await c.callTool('screen_capture', {capture_id: device + '-' + screen}, 35000);
        const image = decodeCapture(response);
        const target = path.join(directory, device + '-' + screen + image.extension);
        fs.writeFileSync(target, image.bytes, {flag: 'wx'});
        const entry = {screen, file: target, requestedAt, capturedAt: new Date().toISOString(), verified: false,
          width: image.width, height: image.height, bytes: image.bytes.length, sha256: image.sha256, mimeType: image.mimeType, before, serverBefore};
        d.captures.push(entry); // Retain the original image even if its post-capture check fails.
        entry.after = await call('Client', stateCode(device, screen));
        entry.serverAfter = screen === 'fresh-hud' ? await call('Server', LUA.freshServerRead) : undefined;
        assert.equal(entry.after.ok, true, 'Post-capture state failed');
        entry.rasterMapping = assertCaptureArea(image, before, entry.after);
        entry.verified = true; entry.completedAt = new Date().toISOString();
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
    record.ok = !primary && cleanupOK && record.postflightUnchanged === true && record.devices.length === 2
      && record.devices.every(d => d.captures.length === 5 && d.captures.every(capture => capture.verified === true));
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
  const nativeArea = {viewport: {x: 749, y: 361}, areas: {full: {size: {x: 873, y: 401}}},
    deviceConfiguration: {id: 'iphone_17_pro', resolution: {x: 874, y: 402}}, safePosition: '0,-58', safeSize: '749,361'};
  const raster = {width: 1204, height: 553};
  check(assertCaptureArea(raster, nativeArea, structuredClone(nativeArea)).aspectResidualPixels < .05, 'Actual native FitToWindow raster maps to full area');
  rejects(() => assertCaptureArea({width: 1204, height: 560}, nativeArea, nativeArea), 'Wrong raster aspect rejected');
  rejects(() => assertCaptureArea({width: 0, height: 553}, nativeArea, nativeArea), 'Empty raster rejected');
  for (const key of ['viewport', 'areas', 'deviceConfiguration', 'safePosition', 'safeSize']) {
    const after = structuredClone(nativeArea); after[key] = null;
    rejects(() => assertCaptureArea(raster, nativeArea, after), `Actual ${key} change rejected`);
  }
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
  const snippets = [LUA.desktop, LUA.phone, LUA.settings, LUA.freshServer, LUA.freshServerRead, LUA.freshClient,
    ...['desktop', 'iphone17pro-landscape'].flatMap(device => ['fresh-hud', 'shop', 'inventory-fists', 'inventory-pets', 'settings'].map(screen => stateCode(device, screen)))];
  const directory = fs.mkdtempSync(path.join(tempRoot, 'smash-final-visual-capture-'));
  let executedStateAssertions = 0;
  try {
    for (const [index, snippet] of snippets.entries()) {
      const target = path.join(directory, `${index}.luau`); fs.writeFileSync(target, snippet);
      const result = spawnSync(compiler, ['--null', target], {encoding: 'utf8', timeout: 15000});
      check(result.status === 0, `Snippet ${index}: ${result.stderr || result.stdout}`);
    }
    const configSource = fs.readFileSync(path.join(root, 'work/punch-wall-rpg/src/shared/GameConfig.lua'), 'utf8').replace(/\r/g, '');
    const effectiveSource = configSource.match(/function GameConfig\.EffectivePower\([^]*?\nend/)[0];
    const rebirthSource = configSource.match(/function GameConfig\.RebirthBonus\([^]*?\nend/)[0];
    const freshMock = `
local attrs={GamePassOwnershipReconciled=true,GamePassOwnershipReconciliationFailed=false,PendingGamePassGrantCount=0,
 ProfileReady=true,ProfilePersistenceState='EphemeralStudio',ProfileWritable=false}
local values={Power=15,Coins=0,FistMastery=1,FistMultiplier=1,PetMultiplier=0,Rebirths=0,HonorPowerBonus=0,
 TutorialStep=1,TutorialVersion=2,TutorialCompleted=0,TrainingActive=0,EquippedFist='Starter Glove',Pet='None',EquippedHonorItem='None'}
for _,key in ipairs({'OwnedPremiumFistsJSON','OwnedPremiumPetsJSON','PetInventoryJSON','EquippedPetsJSON','OwnedHonorItemsJSON','DiscoveredPetsJSON','LockedPetsJSON'}) do values[key]='[]' end
values.OwnedFistsJSON='starter'
local function stat(_,key) return values[key]~=nil and {Value=values[key]} or nil end
local stats={FindFirstChild=stat}
player.GetAttribute=function(_,key) return attrs[key] end player.Name='MockPlayer'
player.FindFirstChild=function(_,key) return (key=='leaderstats' or key=='RPGStats') and stats or nil end
local GameConfig={Rebirth={MaxRebirths=100,BonusPerRebirth=.25}}
${rebirthSource}
${effectiveSource}
game.ReplicatedStorage={GameConfig=GameConfig} local require=function(module) return module end
game.HttpService.JSONDecode=function(_,raw) if raw=='[]' then return {} elseif raw=='starter' then return {'Starter Glove'} else return {'Premium Pet'} end end
local H=game.HttpService
local power={Visible=true,Text='15',IsA=function(_,name)return name=='TextLabel' end}
local coins={Visible=true,Text='0',IsA=power.IsA}
h.FindFirstChild=function(_,name) return name=='PowerValue' and power or coins end
local companionCount=0 local companions={GetChildren=function()local result={} for i=1,companionCount do table.insert(result,{IsA=function()return true end}) end return result end}
workspace.FindFirstChild=function(_,name) return name==player.Name..' Client Companions' and companions or nil end
local fistAttrs={FistVisualKey='Starter Glove',VisualSource='SharedCatalogGeometry'}
local fist={GetAttribute=function(_,key)return fistAttrs[key] end}
player.Character={FindFirstChild=function(_,name)return name=='Equipped Kaiju Gauntlet' and fist or nil end}
local guiAttrs={OnboardingObjectiveReady=true,OnboardingObjectiveStep=1,OnboardingTutorialCompleted=false}
g.GetAttribute=function(_,key)return guiAttrs[key] end
local toastCount=0 local toastHolder={GetChildren=function()local result={} for i=1,toastCount do table.insert(result,{IsA=function()return true end}) end return result end}
g.FindFirstChild=function(_,name)return name=='PixelPerfectHeroCityHUD' and h or name=='Toasts' and toastHolder or automation end
s.feedbackCount=0 s.lastFeedbackType=nil s.lastFeedbackTarget=nil
local now=0 local tick=function()end local os={clock=function()return now end}
local task={wait=function(seconds) now+=seconds tick() end}
local resetCount=0 local serverSnapshotOverride=nil
local function serverSnapshot()
 local result=table.clone(values) result.ok=true result.EffectivePower=GameConfig.EffectivePower(values.Power,values.FistMultiplier,values.PetMultiplier,values.Rebirths,values.FistMastery,values.HonorPowerBonus)
 if serverSnapshotOverride then serverSnapshotOverride(result) end return result
end
local starterValues=table.clone(values)
local serverAutomation={Invoke=function(_,action)
 if action=='Snapshot' then return serverSnapshot() end
 assert(action=='Reset') resetCount+=1 values=table.clone(starterValues) return {ok=true}
end}
local wAttrs={PersistenceMode='EphemeralStudio',PersistenceStudioDefaultEphemeral=true,PersistenceStudioLiveDataOptIn=false}
local world={GetAttribute=function(_,key)return wAttrs[key] end}
local originalFind=workspace.FindFirstChild workspace.FindFirstChild=function(self,name)return name=='PunchWallRPG' and world or originalFind(self,name) end
local serverStorage={GetAttribute=function()return false end,FindFirstChild=function()return serverAutomation end}
local players={GetPlayers=function()return {player} end}
local baseGetService=game.GetService
game.GetService=function(_,name) return name=='HttpService' and H or name=='RunService' and {IsStudio=function()return true end}
 or name=='Players' and players or name=='ServerStorage' and serverStorage or baseGetService(game,name) end
automation.Invoke=function(_,action)
 if action=='Snapshot' then return s elseif action=='CloseMenus' then s.menuVisible=false return true
 elseif action=='ClearMarkers' then s.feedbackCount=0 s.lastFeedbackType=nil s.lastFeedbackTarget=nil return s
 elseif action=='ClearToasts' then toastCount=0 return true end error('Unexpected client mutation '..tostring(action))
end
`;
    const cases = [], mutationGuards = [];
    for (const device of ['desktop', 'iphone17pro-landscape']) for (const screen of ['fresh-hud', 'shop', 'inventory-fists', 'inventory-pets', 'settings']) {
      const setup = `
local v={X=${device === 'desktop' ? 1200 : 749},Y=${device === 'desktop' ? 800 : 361}}
local h={Visible=true,AbsoluteSize=table.clone(v),AbsolutePosition={X=0,Y=-58}}
local Enum={ScreenInsets={None='None',DeviceSafeInsets='DeviceSafeInsets',CoreUISafeInsets='CoreUISafeInsets'},
 ScreenOrientation={LandscapeLeft={Name='LandscapeLeft'}},DeviceSimulatorScalingMode={FitToWindow={Name='FitToWindow'}}}
local nativeAreas={None={Min={X=${device === 'desktop' ? 0 : -62},Y=${device === 'desktop' ? -58 : -78}},Max={X=${device === 'desktop' ? 1200 : 811},Y=${device === 'desktop' ? 742 : 323}}},
 DeviceSafeInsets={Min={X=0,Y=-58},Max={X=v.X,Y=v.Y-58}},CoreUISafeInsets={Min={X=0,Y=0},Max={X=v.X,Y=v.Y-58}}}
local deviceId='${device === 'desktop' ? 'default' : 'iphone_17_pro'}'
local preset={Name='iPhone 17 Pro',IsCustom=false,ResolutionScale=3,PixelDensity=460}
local resolution={X=874,Y=402} local orientation=Enum.ScreenOrientation.LandscapeLeft local scaling=Enum.DeviceSimulatorScalingMode.FitToWindow
local simulator={GetDeviceAsync=function()return deviceId end,GetDeviceInfoAsync=function()return preset end,
 GetResolutionAsync=function()return resolution end,GetOrientationAsync=function()return orientation end,
 GetScalingModeAsync=function()return scaling end,GetPixelDensityAsync=function()return 153.3333282470703 end}
local guiService={GetInsetArea=function(_,kind)return nativeAreas[kind] end}
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
local g={SettingsWindow=panel,ScreenInsets=Enum.ScreenInsets.DeviceSafeInsets,IgnoreGuiInset=true,ClipToDeviceSafeArea=true,GetAttribute=function() return 'actual profile' end,
 FindFirstChild=function(_,name) return name=='PixelPerfectHeroCityHUD' and h or automation end}
local player={PlayerGui={FindFirstChild=function() return g end}}
local game={Players={LocalPlayer=player},HttpService={JSONEncode=function(_,value) return value end}}
game.GetService=function(_,name) return name=='StudioDeviceSimulatorService' and simulator or name=='GuiService' and guiService or game.HttpService end
local workspace={CurrentCamera={ViewportSize=v}}
${screen === 'fresh-hud' ? freshMock : ''}
`;
      const wrong = screen === 'fresh-hud' ? 's.menuVisible=true' : screen === 'shop' ? 's.shopVisible=false'
        : screen === 'settings' ? 's.settingsVisible=false' : "s.inventory.category='Wrong'";
      for (const [mutation, shouldPass] of [['', true], [wrong, false], ['v.X=10', false],
        ...(screen.startsWith('inventory') ? [["s.inventory.visibleNames={}", false], ['s.inventory.layout.allTextFits=false', false]] : []),
        ...(screen === 'settings' ? [['button.AbsoluteSize.Y=40', false], ['button.TextFits=false', false]] : []),
        ['nativeAreas.DeviceSafeInsets.Max.X+=1', false], ['h.AbsolutePosition.Y=0', false], ['g.ClipToDeviceSafeArea=false', false],
        ...(device === 'iphone17pro-landscape' ? [["deviceId='wrong_device'", false], ['preset.IsCustom=true', false], ['resolution.X=873', false],
          ['orientation={Name="Portrait"}', false], ['nativeAreas.None.Max.X+=2', true], ['nativeAreas.None.Max.X+=3', false]] : []),
        ...(screen === 'fresh-hud' ? [
          ["values.PetInventoryJSON='premium'", false], ['values.PetMultiplier=24.3', false], ["values.OwnedPremiumFistsJSON='premium'", false],
          ["power.Text='22.8K'", false], ['companionCount=2', false], ["fistAttrs.FistVisualKey='Celestial Titan'", false],
          ['guiAttrs.OnboardingObjectiveStep=2', false], ['s.feedbackCount=1', false], ['toastCount=1', false],
          ['attrs.GamePassOwnershipReconciled=false', false], ['attrs.PendingGamePassGrantCount=1', false],
          ['attrs.PendingGamePassGrantCount=nil', true], ['values.FistMastery=0', false]] : [])]) {
        cases.push(`do ${setup}\n${mutation}\nlocal ok=pcall(function() ${stateCode(device, screen)} end) assert(ok==${shouldPass},'actual_state_guard_${device}_${screen}') count+=1 end`);
      }
      if (device === 'desktop' && screen === 'fresh-hud') {
        for (const [mutation, pass, resets] of [
          ['', true, 1], ['attrs.PendingGamePassGrantCount=nil', true, 1],
          ["values.OwnedPremiumFistsJSON='premium' values.FistMultiplier=60 values.PetMultiplier=24.3 values.PetInventoryJSON='premium'", true, 1],
          ['attrs.GamePassOwnershipReconciled=false tick=function()if now>=.3 then attrs.GamePassOwnershipReconciled=true end end', true, 1],
          ['attrs.GamePassOwnershipReconciled=false', false, 0], ['attrs.GamePassOwnershipReconciliationFailed=true', false, 0],
          ['attrs.PendingGamePassGrantCount=1', false, 0], ['wAttrs.PersistenceStudioLiveDataOptIn=true', false, 0],
          ["serverSnapshotOverride=function(result)if resetCount>0 then result.PetInventoryJSON='premium' end end", false, 1],
          ['serverSnapshotOverride=function(result)if resetCount>0 then result.EffectivePower=15 end end', false, 1],
        ]) cases.push(`do ${setup}\n${mutation}\nlocal ok=pcall(function() ${LUA.freshServer} end) assert(ok==${pass} and resetCount==${resets},'server_fresh_gate') count+=1 end`);
        for (const [mutation, pass] of [
          ['s.feedbackCount=6 s.lastFeedbackType="PremiumPurchase" toastCount=1', true],
          ['values.PetMultiplier=24.3', false], ['tick=function()s.feedbackCount=1 end', false],
          ['tick=function()companionCount=2 end', false], ['tick=function()attrs.PendingGamePassGrantCount=1 end', false],
        ]) cases.push(`do ${setup}\n${mutation}\nlocal ok=pcall(function() ${LUA.freshClient} end) assert(ok==${pass},'client_fresh_settlement') count+=1 end`);
        for (const [label, original, from, to, mutation] of [
          ['waive_pending_entitlement_queue', LUA.freshServer, ' and (pending==nil or pending==0)', '', 'attrs.PendingGamePassGrantCount=1'],
          ['waive_actual_starter_HUD', stateCode(device, screen), "power.Text==tostring(math.floor(profile.expectedEffectivePower+.5))", 'true', "power.Text='22.8K'"],
          ['waive_post_reset_effective_power', LUA.freshServer, "math.abs(snapshot.EffectivePower-effective)<1e-8", 'true', 'serverSnapshotOverride=function(result)if resetCount>0 then result.EffectivePower=22792.77 end end'],
        ]) {
          const weak = original.replace(from, to); assert.notEqual(weak, original, label);
          cases.push(`do ${setup}\n${mutation}\nlocal ok=pcall(function() ${weak} end) assert(ok==true,'weakening_control_${label}') count+=1 end`);
          mutationGuards.push(label);
        }
      }
      if (device === 'iphone17pro-landscape' && screen === 'shop') {
        const original = stateCode(device, screen);
        const weak = original.replace('v.X==areas.deviceSafe.size.x and v.Y==areas.deviceSafe.size.y', 'true'); assert.notEqual(weak, original);
        cases.push(`do ${setup}\nv.X-=1\nlocal ok=pcall(function() ${weak} end) assert(ok==true,'weakening_control_native_camera_area') count+=1 end`);
        mutationGuards.push('waive_native_camera_area');
      }
    }
    const stateTest = 'local count=0\n' + cases.join('\n') + "\nprint('PASS '..count)";
    const target = path.join(directory, 'state-execution.luau'); fs.writeFileSync(target, stateTest);
    const runtime = path.join(path.dirname(compiler), process.platform === 'win32' ? 'luau.exe' : 'luau');
    const result = spawnSync(runtime, [target], {encoding: 'utf8', timeout: 15000});
    check(result.status === 0 && result.stdout.trim() === `PASS ${cases.length}`, `Exact screen-state execution: ${result.stderr || result.stdout}`);
    executedStateAssertions = cases.length;
    check(mutationGuards.length === 4, 'Four weakened source guards demonstrably admit their rejected controls');
  } finally { for (const item of fs.readdirSync(directory)) fs.unlinkSync(path.join(directory, item)); fs.rmdirSync(directory); }
  return {ok: true, checks, compiledSnippets: snippets.length, executedStateAssertions, weakeningControls: 4, sharedProfilerContract: dependency, studioUsed: false};
}

if (process.argv[1] && path.resolve(process.argv[1]) === filename) {
  try {
    if (process.argv.length === 3 && process.argv[2] === '--self-test') console.log(JSON.stringify(await selfTest(), null, 2));
    else await run(parseArgs(process.argv.slice(2)));
  } catch (error) { console.error(error.stack || error); process.exitCode = 1; }
}
