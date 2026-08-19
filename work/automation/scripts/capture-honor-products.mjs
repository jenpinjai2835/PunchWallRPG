#!/usr/bin/env node
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import {
  McpClient,
  assertPlaceIdentity,
  findStudioMcp,
  inspectSelectedPlace,
  selectStudioStrict,
  sleep,
  waitForDataModels,
} from "./studio_mcp_client.mjs";

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const repositoryRoot = path.resolve(scriptDirectory, "..", "..", "..");
const outputDirectory = path.join(repositoryRoot, "work", "docs", "evidence", "honor-products-20260819");
const studioInstanceId = process.argv[2] || "6d29b2d4-41ab-41fb-838f-3dfd8727c725";
const studioName = "^PunchWallRPG_ManualPlaytest_20260818_FistAuraV10[.]rbxlx$";
const devices = [
  { id: "01_desktop_1366_honor_products", name: "PunchWallHonorProductsDesktop1366", width: 1366, height: 768, form: "Desktop" },
  { id: "02_phone_844_honor_products", name: "PunchWallHonorProductsPhone844", width: 844, height: 390, form: "Phone" },
  { id: "03_phone_740_honor_products", name: "PunchWallHonorProductsPhone740", width: 740, height: 360, form: "Phone" },
];

function requireTool(result, label) {
  if (result?.isError) throw new Error(`${label}: ${result.text}`);
  return result;
}
function imageData(content) {
  const item = content.find((entry) => entry.type === "image" && entry.data);
  if (!item) throw new Error("screen_capture did not return image data");
  return item.data;
}
function sha256(file) {
  return crypto.createHash("sha256").update(fs.readFileSync(file)).digest("hex");
}
function sourceFingerprint(file) {
  const source = fs.readFileSync(file, "utf8").replace(/\r\n?/g, "\n");
  const bytes = Buffer.from(source, "utf8");
  let a = 1;
  let b = 0;
  for (const value of bytes) {
    a = (a + value) % 65521;
    b = (b + a) % 65521;
  }
  return { length: bytes.length, adler32: b * 65536 + a };
}
function assertConsoleClean(value, label) {
  const suspicious = String(value || "").split(/\r?\n/).filter(Boolean)
    .filter((line) => !line.includes("Unpublished Studio session is EPHEMERAL"))
    .filter((line) => /error|failed|stack begin|infinite yield|traceback/i.test(line));
  if (suspicious.length) throw new Error(`${label}: ${suspicious.join(" | ")}`);
}

async function main() {
  fs.mkdirSync(outputDirectory, { recursive: true });
  const client = new McpClient(findStudioMcp(), "punch-wall-honor-products-capture");
  const summary = { ok: false, captures: [], runs: [], sources: {} };
  let started = false;
  let configuredDevices = 0;
  try {
    await client.initialize();
    summary.selectedStudio = await selectStudioStrict(client, { studioInstanceId, studioName, pollAttempts: 15, pollMs: 3000 });
    summary.selectedPlace = await inspectSelectedPlace(client);
    assertPlaceIdentity(summary.selectedPlace, { placeName: studioName });

    const scopedSources = {
      GameConfig: "work/punch-wall-rpg/src/shared/GameConfig.lua",
      ProfilePersistence: "work/punch-wall-rpg/src/server/ProfilePersistence.lua",
      PunchWallBootstrap: "work/punch-wall-rpg/src/server/PunchWallBootstrap.server.lua",
      PunchWallClient: "work/punch-wall-rpg/src/client/PunchWallClient.client.lua",
    };
    const runtimeSourceResult = requireTool(await client.callTool("execute_luau", {
      datamodel_type: "Edit",
      code: "local H=game:GetService('HttpService') local function fp(s) local a,b=1,0 for i=1,#s do a=(a+string.byte(s,i))%65521 b=(b+a)%65521 end return {length=#s,adler32=b*65536+a} end return H:JSONEncode({GameConfig=fp(game.ReplicatedStorage.GameConfig.Source),ProfilePersistence=fp(game.ServerScriptService.ProfilePersistence.Source),PunchWallBootstrap=fp(game.ServerScriptService.PunchWallBootstrap.Source),PunchWallClient=fp(game.StarterPlayer.StarterPlayerScripts.PunchWallClient.Source)})",
    }, 30000), "fingerprint Studio sources");
    summary.runtimeSources = JSON.parse(runtimeSourceResult.text);
    for (const [name, relative] of Object.entries(scopedSources)) {
      const expected = sourceFingerprint(path.join(repositoryRoot, relative));
      const actual = summary.runtimeSources[name];
      if (!actual || actual.length !== expected.length || actual.adler32 !== expected.adler32) {
        throw new Error(`Studio source mismatch for ${name}: ${JSON.stringify({ expected, actual })}`);
      }
      actual.file = relative;
      actual.matchesLocal = true;
    }

    for (const device of devices) {
      const deviceResult = requireTool(await client.callTool("execute_luau", {
        datamodel_type: "Edit",
        code: `local H=game:GetService('HttpService') local S=game:GetService('StudioDeviceSimulatorService') local n=${JSON.stringify(device.name)} local id for _,x in ipairs(S:GetDeviceListAsync()) do if S:GetDeviceInfoAsync(x).Name==n then id=x break end end local c={Name=n,Width=${device.width},Height=${device.height},PixelDensity=${device.form === "Desktop" ? 96 : 326},DeviceForm=Enum.DeviceForm.${device.form}} if id then S:UpdateDeviceAsync(id,c) else id=S:CreateDeviceAsync(c) end S:SetDeviceAsync(id) ${device.form === "Desktop" ? "" : "S:SetOrientationAsync(Enum.ScreenOrientation.LandscapeLeft)"} S:SetScalingModeAsync(Enum.DeviceSimulatorScalingMode.FitToWindow) task.wait(.4) local r=S:GetResolutionAsync() return H:JSONEncode({name=n,width=r.X,height=r.Y,active=S:GetDeviceAsync()==id})`,
      }, 30000), `set ${device.name}`);
      const deviceState = JSON.parse(deviceResult.text);
      if (!deviceState.active || deviceState.width !== device.width || deviceState.height !== device.height) {
        throw new Error(`device resolution mismatch: ${deviceResult.text}`);
      }
      configuredDevices += 1;

      requireTool(await client.callTool("start_stop_play", { is_start: true }, 35000), `start ${device.id}`);
      started = true;
      await waitForDataModels(client, ["Server", "Client"], 60000);
      await sleep(7000);
      const diagnosticsResult = requireTool(await client.callTool("execute_luau", {
        datamodel_type: "Client",
        code: `local H=game:GetService('HttpService')
local M=game:GetService('MarketplaceService')
local g=game.Players.LocalPlayer.PlayerGui:WaitForChild('PunchWallHUD')
local a=g:WaitForChild('PunchWallClientAutomation')
assert(a:Invoke('OpenTab','Fists')==true)
assert(a:Invoke('OpenShopPage','Honor')==true)
local s=g.GameMenu.FunctionalHeroShop
local compact=workspace.CurrentCamera.ViewportSize.Y<520
local subtitle=s.ShopHeader:FindFirstChild('Subtitle')
local expectedSubtitle=compact and 'HONOR 0  •  CURRENCY ONLY  •  GATES APPLY' or 'HONOR 0  •  CURRENCY ONLY  •  RELIC GATES STILL APPLY'
local expected={{'HonorPouch25',25,1,3708804891},{'HonorCache90',90,2,3708804911},{'HonorVault300',300,3,3708804933},{'HonorTreasury850',850,4,3708804944}}
local deadline=os.clock()+8
local resolved=false
repeat
  task.wait(.1)
  resolved=true
  for _,e in ipairs(expected) do
    local c=s:FindFirstChild(e[1]..'ShopCard',true)
    resolved=resolved and c and c:GetAttribute('RegionalPriceResolved')==true
  end
until resolved or os.clock()>=deadline
local rows={}
local failures={}
local ok=resolved and g.GameMenu.Visible and s.Visible and s:GetAttribute('ShopCatalogItemCount')==4 and s.ShopTabs:FindFirstChild('HonorShopTab')~=nil and subtitle and subtitle.Text==expectedSubtitle and subtitle.TextFits==true
for _,e in ipairs(expected) do
  local c=s:FindFirstChild(e[1]..'ShopCard',true)
  local b=c and c:FindFirstChild(e[1]..'Action',true)
  local name=c and c:FindFirstChild('Name',true)
  local rarity=c and c:FindFirstChild('Rarity',true)
  local detail=c and c:FindFirstChild('Detail',true)
  local lookup,info=pcall(function() return M:GetProductInfoAsync(e[4],Enum.InfoType.Product) end)
  local live=lookup and tonumber(info.PriceInRobux) or 0
  local amountVisible=compact and name and name.Text:find(e[2]..' HONOR',1,true)~=nil or not compact and rarity and rarity.Text:find('+'..e[2]..' HONOR',1,true)~=nil
  local exact=c and b and name and rarity and detail and lookup and info.IsForSale==true and c:GetAttribute('HonorPackPipCount')==e[3] and c:GetAttribute('ProductId')==e[4] and c:GetAttribute('PurchaseConfigured')==true and c:GetAttribute('PurchaseUnavailable')==false and c:GetAttribute('RegionalPriceResolved')==true and c:GetAttribute('DisplayedRobuxPrice')==live and b:GetAttribute('DisplayedRobuxPrice')==live and b.Active==true and b.Selectable==true and b:GetAttribute('ShopActionBound')==true and b.Text=='BUY' and b.TextWrapped==false and b.TextFits and name.TextFits and rarity.TextFits and (not detail.Visible or detail.TextFits) and amountVisible and b.AbsoluteSize.X>=44 and b.AbsoluteSize.Y>=44
  rows[#rows+1]={id=e[1],productId=e[4],livePrice=live,exact=exact==true,pips=c and c:GetAttribute('HonorPackPipCount'),name=name and name.Text,rarity=rarity and rarity.Text,wrapped=b and b.TextWrapped,text=b and b.Text,button=b and {x=b.AbsoluteSize.X,y=b.AbsoluteSize.Y},card=c and {x=c.AbsoluteSize.X,y=c.AbsoluteSize.Y}}
  if not exact then failures[#failures+1]={id=e[1],sale=lookup and info.IsForSale,configured=c and c:GetAttribute('PurchaseConfigured'),unavailable=c and c:GetAttribute('PurchaseUnavailable'),resolved=c and c:GetAttribute('RegionalPriceResolved'),cardPrice=c and c:GetAttribute('DisplayedRobuxPrice'),buttonPrice=b and b:GetAttribute('DisplayedRobuxPrice'),active=b and b.Active,selectable=b and b.Selectable,bound=b and b:GetAttribute('ShopActionBound'),text=b and b.Text,textFits=b and b.TextFits,nameFits=name and name.TextFits,rarityFits=rarity and rarity.TextFits,detailVisible=detail and detail.Visible,detailFits=detail and detail.TextFits,amountVisible=amountVisible,size=b and tostring(b.AbsoluteSize)} end
  ok=ok and exact
end
local function overlaps(left,right)
  if not left or not right or not left.Visible or not right.Visible then return false end
  local rightMaxZ=right.ZIndex
  for _,descendant in ipairs(right:GetDescendants()) do
    if descendant:IsA('GuiObject') and descendant.Visible then rightMaxZ=math.max(rightMaxZ,descendant.ZIndex) end
  end
  if rightMaxZ<left.ZIndex then return false end
  local lp,ls=left.AbsolutePosition,left.AbsoluteSize
  local rp,rs=right.AbsolutePosition,right.AbsoluteSize
  return lp.X<rp.X+rs.X and rp.X<lp.X+ls.X and lp.Y<rp.Y+rs.Y and rp.Y<lp.Y+ls.Y
end
local fixedOverlap=false
local rightRail=g:FindFirstChild('ReferenceHUD') and g.ReferenceHUD:FindFirstChild('RightMenu')
for _,e in ipairs(expected) do
  local c=s:FindFirstChild(e[1]..'ShopCard',true)
  fixedOverlap=fixedOverlap or overlaps(c,rightRail)
end
local result={ok=ok and not fixedOverlap,viewport={x=workspace.CurrentCamera.ViewportSize.X,y=workspace.CurrentCamera.ViewportSize.Y},subtitle=subtitle and {text=subtitle.Text,fits=subtitle.TextFits},rows=rows,fixedOverlap=fixedOverlap,modal=s.Parent:GetAttribute('ShopModalSizing')}
assert(result.ok,'Honor responsive diagnostics failed '..H:JSONEncode({resolved=resolved,menu=g.GameMenu.Visible,shop=s.Visible,count=s:GetAttribute('ShopCatalogItemCount'),subtitle=subtitle and subtitle.Text,subtitleFits=subtitle and subtitle.TextFits,fixedOverlap=fixedOverlap,failures=failures}))
return H:JSONEncode(result)`,
      }, 60000), `prepare ${device.id}`);
      const diagnostics = JSON.parse(diagnosticsResult.text);
      const warmup = requireTool(await client.callTool("screen_capture", { capture_id: `${device.id}_warmup` }, 120000), `warmup ${device.id}`);
      if (!imageData(warmup.content)) throw new Error(`warmup capture missing for ${device.id}`);
      await sleep(200);
      const captured = requireTool(await client.callTool("screen_capture", { capture_id: device.id }, 120000), `capture ${device.id}`);
      const file = path.join(outputDirectory, `${device.id}.jpg`);
      fs.writeFileSync(file, Buffer.from(imageData(captured.content), "base64"));
      summary.captures.push({ ...device, diagnostics, file, sha256: sha256(file) });

      const runtimeConsole = requireTool(await client.callTool("get_console_output", {}, 30000), `runtime console ${device.id}`);
      assertConsoleClean(runtimeConsole.text, `runtime console ${device.id}`);
      requireTool(await client.callTool("start_stop_play", { is_start: false }, 35000), `stop ${device.id}`);
      started = false;
      const postStopConsole = requireTool(await client.callTool("get_console_output", {}, 30000), `post-stop console ${device.id}`);
      assertConsoleClean(postStopConsole.text, `post-stop console ${device.id}`);
      summary.runs.push({ id: device.id, runtime: runtimeConsole.text, postStop: postStopConsole.text });
      await waitForDataModels(client, ["Edit"], 60000);
    }

    for (const relative of [
      ...Object.values(scopedSources),
      "work/automation/flows/honor-product-receipts.json",
      "work/automation/scripts/honor-product-receipts-contract.mjs",
      "work/automation/scripts/capture-honor-products.mjs",
    ]) summary.sources[relative] = sha256(path.join(repositoryRoot, relative));
    const consoleFile = path.join(outputDirectory, "console.txt");
    fs.writeFileSync(consoleFile, summary.runs.map((run) => `[${run.id} runtime]\n${run.runtime}\n[${run.id} post-stop]\n${run.postStop}`).join("\n"));
    summary.console = { file: consoleFile, clean: true };
  } finally {
    if (started) {
      requireTool(await client.callTool("start_stop_play", { is_start: false }, 35000), "final cleanup stop play");
      started = false;
      await waitForDataModels(client, ["Edit"], 60000);
    }
    let cleanupResult;
    for (let attempt = 1; attempt <= 12; attempt += 1) {
      cleanupResult = await client.callTool("execute_luau", {
        datamodel_type: "Edit",
        code: `local H=game:GetService('HttpService') local S=game:GetService('StudioDeviceSimulatorService') S:StopSimulationAsync() local names={} for _,name in ipairs({${devices.map((device) => JSON.stringify(device.name)).join(",")}}) do names[name]=true end local removed=0 for _,id in ipairs(S:GetDeviceListAsync()) do local info=S:GetDeviceInfoAsync(id) if names[info.Name] and info.IsCustom then S:RemoveDeviceAsync(id) removed+=1 end end return H:JSONEncode({default=S:GetDeviceAsync()=='default',removed=removed})`,
      }, 30000);
      if (!cleanupResult.isError) break;
      await client.callTool("start_stop_play", { is_start: false }, 35000);
      await sleep(500);
    }
    requireTool(cleanupResult, "cleanup simulator devices");
    summary.cleanup = JSON.parse(cleanupResult.text);
    client.close();
    if (summary.cleanup.default !== true || summary.cleanup.removed !== configuredDevices) {
      throw new Error(`capture cleanup mismatch: ${cleanupResult.text}`);
    }
  }
  summary.ok = true;
  fs.writeFileSync(path.join(outputDirectory, "capture-summary.json"), JSON.stringify(summary, null, 2));
  console.log(JSON.stringify(summary, null, 2));
}

main().catch((error) => {
  console.error(JSON.stringify({ ok: false, error: error.message }, null, 2));
  process.exitCode = 1;
});
