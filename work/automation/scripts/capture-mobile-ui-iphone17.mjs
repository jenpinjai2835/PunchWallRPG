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
  normalizeMouseInputArgs,
  selectStudioStrict,
  sleep,
  waitForDataModels,
} from "./studio_mcp_client.mjs";

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const repositoryRoot = path.resolve(scriptDirectory, "..", "..", "..");
const afterMode = process.argv.includes("--after");
const outputDirectory = path.join(
  repositoryRoot,
  "work",
  "docs",
  "evidence",
  "mobile-iphone17-layout-20260820",
  afterMode ? "after" : "before",
);
const studioInstanceId = process.argv[2] || "03d68549-ed19-438d-bb8c-922b03f9d7b1";
const automationFallback = process.argv.includes("--automation-fallback");
const diagnosticsOnly = process.argv.includes("--diagnostics-only");
const studioName = "^SmashWall_v1[.]0[.]1[.]rbxlx$";
const device = {
  name: "PunchWall iPhone 17 874x402",
  width: 874,
  height: 402,
  pixelDensity: 460,
  form: "Phone",
};

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
    // Studio emits bare "Stack Begin/End" framing lines for non-error warnings.
    // Treat the frame itself as neutral; the actual error/trace line still fails.
    .filter((line) => /error|failed|infinite yield|traceback|out of local registers/i.test(line));
  if (suspicious.length) throw new Error(`${label}: ${suspicious.join(" | ")}`);
}

async function click(client, instancePathSegments, label) {
  const args = await normalizeMouseInputArgs(client, {
    datamodel_type: "Client",
    actions: [
      { action: "moveTo", instance_path_segments: instancePathSegments },
      { action: "mouseButtonDown", mouse_button: "left", instance_path_segments: instancePathSegments },
      { action: "wait", wait_time_ms: 60 },
      { action: "mouseButtonUp", mouse_button: "left", instance_path_segments: instancePathSegments },
    ],
  });
  requireTool(await client.callTool("user_mouse_input", args, 60000), label);
}

async function clickUntil(client, instancePathSegments, label, predicateCode, attempts = 3) {
  for (let attempt = 1; attempt <= attempts; attempt += 1) {
    await click(client, instancePathSegments, `${label} attempt ${attempt}`);
    await sleep(350);
    const result = requireTool(await client.callTool("execute_luau", {
      datamodel_type: "Client",
      code: `return tostring((${predicateCode}) == true)`,
    }, 30000), `${label} verification ${attempt}`);
    if (/true/i.test(result.text)) return attempt;
  }
  throw new Error(`${label} did not reach its verified state after ${attempts} real clicks`);
}

const diagnosticsCode = (stateName) => `local H=game:GetService('HttpService')
local GuiService=game:GetService('GuiService')
local p=game.Players.LocalPlayer
local g=p.PlayerGui:WaitForChild('PunchWallHUD')
local camera=workspace.CurrentCamera
local viewport=camera.ViewportSize
local insetTopLeft,insetBottomRight=GuiService:GetGuiInset()
local safe={left=59,right=59,top=8,bottom=21}
local function actualVisible(object)
  if not object:IsA('GuiObject') then return false end
  local cursor=object
  while cursor and cursor~=g.Parent do
    if cursor:IsA('GuiObject') and cursor.Visible==false then return false end
    cursor=cursor.Parent
  end
  return true
end
local function pathOf(object)
  local parts={}
  local cursor=object
  while cursor and cursor~=g.Parent do table.insert(parts,1,cursor.Name) cursor=cursor.Parent end
  return table.concat(parts,'/')
end
local function rectOf(object)
  local pos,size=object.AbsolutePosition,object.AbsoluteSize
  return {x=math.floor(pos.X+.5),y=math.floor(pos.Y+.5),w=math.floor(size.X+.5),h=math.floor(size.Y+.5)}
end
local function insideSafe(rect)
  return rect.x>=safe.left and rect.y>=safe.top and rect.x+rect.w<=viewport.X-safe.right and rect.y+rect.h<=viewport.Y-safe.bottom
end
local function areaOverlap(a,b)
  local x=math.max(0,math.min(a.x+a.w,b.x+b.w)-math.max(a.x,b.x))
  local y=math.max(0,math.min(a.y+a.h,b.y+b.h)-math.max(a.y,b.y))
  return x*y
end
local buttons,smallTargets,outOfBounds,textFailures={}, {}, {}, {}
local labels={}
for _,object in ipairs(g:GetDescendants()) do
  if actualVisible(object) then
    if object:IsA('GuiButton') then
      local rect=rectOf(object)
      local row={path=pathOf(object),name=object.Name,rect=rect,active=object.Active,selectable=object.Selectable,text=object:IsA('TextButton') and object.Text or nil,safe=insideSafe(rect)}
      buttons[#buttons+1]=row
      if math.min(rect.w,rect.h)<44 then smallTargets[#smallTargets+1]=row end
      if rect.x<0 or rect.y<0 or rect.x+rect.w>viewport.X or rect.y+rect.h>viewport.Y then outOfBounds[#outOfBounds+1]=row end
      if object:IsA('TextButton') and object.Text~='' and object.TextFits==false then textFailures[#textFailures+1]=row end
    elseif object:IsA('TextLabel') and object.Text~='' then
      local rect=rectOf(object)
      local row={path=pathOf(object),name=object.Name,rect=rect,text=object.Text,textSize=object.TextSize,fits=object.TextFits,safe=insideSafe(rect)}
      labels[#labels+1]=row
      if object.TextFits==false then textFailures[#textFailures+1]=row end
      if rect.x<0 or rect.y<0 or rect.x+rect.w>viewport.X or rect.y+rect.h>viewport.Y then outOfBounds[#outOfBounds+1]=row end
    end
  end
end
local overlaps={}
for i=1,#buttons do
  local left=buttons[i]
  local leftObject=g:FindFirstChild(left.name,true)
  for j=i+1,#buttons do
    local right=buttons[j]
    local rightObject=g:FindFirstChild(right.name,true)
    local related=leftObject and rightObject and (leftObject:IsDescendantOf(rightObject) or rightObject:IsDescendantOf(leftObject))
    local overlap=not related and areaOverlap(left.rect,right.rect) or 0
    if overlap>=64 then overlaps[#overlaps+1]={left=left.path,right=right.path,area=overlap} end
  end
end
local windows={}
for _,name in ipairs({'GameMenu','FunctionalInventory','FunctionalHeroShop','MissionsWindow','RebirthWindow','SettingsWindow','HeroSpinModal','TrainingOverlay'}) do
  local object=g:FindFirstChild(name,true)
  if object and object:IsA('GuiObject') and actualVisible(object) then
    local rect=rectOf(object)
    windows[#windows+1]={name=name,rect=rect,coverage=math.floor((rect.w*rect.h)/(math.max(1,viewport.X*viewport.Y))*1000+.5)/1000}
  end
end
local result={state=${JSON.stringify(stateName)},viewport={x=viewport.X,y=viewport.Y},guiInset={left=insetTopLeft.X,top=insetTopLeft.Y,right=insetBottomRight.X,bottom=insetBottomRight.Y},safe=safe,profile=g:GetAttribute('ResponsiveProfile'),width=g:GetAttribute('ResponsiveViewportWidth'),height=g:GetAttribute('ResponsiveViewportHeight'),windows=windows,buttonCount=#buttons,labelCount=#labels,smallTargets=smallTargets,textFailures=textFailures,outOfBounds=outOfBounds,overlaps=overlaps,buttons=buttons,labels=labels}
return H:JSONEncode(result)`;

async function main() {
  fs.mkdirSync(outputDirectory, { recursive: true });
  const client = new McpClient(findStudioMcp(), "punch-wall-iphone17-layout-audit");
  const summary = {
    ok: false,
    mode: afterMode ? "AFTER_REMEDIATION" : "BEFORE_REMEDIATION",
    device,
    captures: [],
    routes: [],
    inputMode: automationFallback ? "AUTOMATION_FALLBACK_AFTER_REAL_INPUT_TIMEOUT" : "REAL_MOUSE_INPUT",
    diagnosticsOnly,
    sources: {},
  };
  let started = false;
  let configured = false;
  try {
    await client.initialize();
    summary.selectedStudio = await selectStudioStrict(client, {
      studioInstanceId,
      studioName,
      pollAttempts: 15,
      pollMs: 3000,
    });
    summary.selectedPlace = await inspectSelectedPlace(client);
    assertPlaceIdentity(summary.selectedPlace, { placeName: studioName });

    const scopedSources = {
      GameConfig: "work/punch-wall-rpg/src/shared/GameConfig.lua",
      InventoryViewModel: "work/punch-wall-rpg/src/shared/InventoryViewModel.lua",
      PunchWallBootstrap: "work/punch-wall-rpg/src/server/PunchWallBootstrap.server.lua",
      InventoryUI: "work/punch-wall-rpg/src/client/InventoryUI.lua",
      PunchWallClient: "work/punch-wall-rpg/src/client/PunchWallClient.client.lua",
    };
    const runtimeSourceResult = requireTool(await client.callTool("execute_luau", {
      datamodel_type: "Edit",
      code: "local H=game:GetService('HttpService') local function fp(s) local a,b=1,0 for i=1,#s do a=(a+string.byte(s,i))%65521 b=(b+a)%65521 end return {length=#s,adler32=b*65536+a} end return H:JSONEncode({GameConfig=fp(game.ReplicatedStorage.GameConfig.Source),InventoryViewModel=fp(game.ReplicatedStorage.InventoryViewModel.Source),PunchWallBootstrap=fp(game.ServerScriptService.PunchWallBootstrap.Source),InventoryUI=fp(game.StarterPlayer.StarterPlayerScripts.InventoryUI.Source),PunchWallClient=fp(game.StarterPlayer.StarterPlayerScripts.PunchWallClient.Source)})",
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
      summary.sources[relative] = sha256(path.join(repositoryRoot, relative));
    }

    const configuredResult = requireTool(await client.callTool("execute_luau", {
      datamodel_type: "Edit",
      code: `local H=game:GetService('HttpService') local S=game:GetService('StudioDeviceSimulatorService') local n=${JSON.stringify(device.name)} local id for _,candidate in ipairs(S:GetDeviceListAsync()) do if S:GetDeviceInfoAsync(candidate).Name==n then id=candidate break end end local config={Name=n,Width=${device.width},Height=${device.height},PixelDensity=${device.pixelDensity},DeviceForm=Enum.DeviceForm.Phone} if id then S:UpdateDeviceAsync(id,config) else id=S:CreateDeviceAsync(config) end S:SetDeviceAsync(id) S:SetOrientationAsync(Enum.ScreenOrientation.LandscapeLeft) S:SetScalingModeAsync(Enum.DeviceSimulatorScalingMode.FitToWindow) task.wait(.4) local r=S:GetResolutionAsync() return H:JSONEncode({active=S:GetDeviceAsync()==id,width=r.X,height=r.Y})`,
    }, 30000), "configure iPhone 17 simulator");
    const configuredState = JSON.parse(configuredResult.text);
    if (!configuredState.active || configuredState.width !== device.width || configuredState.height !== device.height) {
      throw new Error(`iPhone 17 simulator mismatch: ${configuredResult.text}`);
    }
    configured = true;

    requireTool(await client.callTool("start_stop_play", { is_start: true }, 60000), "start iPhone 17 audit");
    started = true;
    await waitForDataModels(client, ["Server", "Client"], 60000);
    await sleep(7500);

    requireTool(await client.callTool("execute_luau", {
      datamodel_type: "Server",
      code: `local H=game:GetService('HttpService') local a=game.ServerStorage.PunchWallAutomation a:Invoke('Reset') return H:JSONEncode(a:Invoke('SetStats',{Coins=50000,Power=1000,Honor=500,Depth=75,WallLevel=55,WallXP=0,Rebirths=0,SpinCredits=1,OwnedFistsJSON='["Starter Glove","Boxing Glove"]',EquippedFist='Starter Glove',PetInventoryJSON='["Forest Pup","Miner Cat","Crystal Fox","Crimson Phoenix","Storm Wyvern","Celestial Guardian"]',EquippedPetsJSON='["Crimson Phoenix","Storm Wyvern","Celestial Guardian"]',DiscoveredPetsJSON='["Forest Pup","Miner Cat","Crystal Fox","Crimson Phoenix","Storm Wyvern","Celestial Guardian"]',LockedPetsJSON='[]',OwnedHonorItemsJSON='["vanguard_trail"]',EquippedHonorItem='vanguard_trail',SettingsJSON=H:JSONEncode({motion=true,sound=true,uiScale=1})}))`,
    }, 30000), "seed rich mobile audit state");
    await sleep(800);

    const guiPath = ["LocalPlayer", "PlayerGui", "PunchWallHUD", "PixelPerfectHeroCityHUD"];
    const captureState = async (id, stateName) => {
      await sleep(350);
      const diagnosticsResult = requireTool(await client.callTool("execute_luau", {
        datamodel_type: "Client",
        code: diagnosticsCode(stateName),
      }, 60000), `diagnose ${id}`);
      const diagnostics = JSON.parse(diagnosticsResult.text);
      if (diagnosticsOnly) {
        summary.captures.push({ id, state: stateName, diagnostics, visualCapture: "BLOCKED_STUDIO_SCREEN_CAPTURE_TIMEOUT" });
      } else {
        const capture = requireTool(await client.callTool("screen_capture", { capture_id: id }, 120000), `capture ${id}`);
        const file = path.join(outputDirectory, `${id}.jpg`);
        fs.writeFileSync(file, Buffer.from(imageData(capture.content), "base64"));
        summary.captures.push({ id, state: stateName, diagnostics, file, sha256: sha256(file) });
      }
    };
    const automation = async (code, label) => requireTool(await client.callTool("execute_luau", {
      datamodel_type: "Client",
      code,
    }, 60000), label);

    await automation("local a=game.Players.LocalPlayer.PlayerGui.PunchWallHUD.PunchWallClientAutomation a:Invoke('CloseMenus') return true", "close all for baseline");
    await captureState("01_iphone17_hud", "HUD baseline");
    await automation("local g=game.Players.LocalPlayer.PlayerGui.PunchWallHUD local a=g.PunchWallClientAutomation a:Invoke('ShowToast',{message='CELESTIAL GUARDIAN EQUIPPED',icon='Pet'}) task.wait(.2) return g.Toasts.Visible", "show compact premium pet notice");
    await captureState("15_iphone17_premium_pet_notice", "Premium pet equipped notice");
    await automation("return game.Players.LocalPlayer.PlayerGui.PunchWallHUD.PunchWallClientAutomation:Invoke('ClearToasts')", "clear compact premium pet notice");

    if (automationFallback) {
      await automation("local a=game.Players.LocalPlayer.PlayerGui.PunchWallHUD.PunchWallClientAutomation return tostring(a:Invoke('OpenInventory','All'))", "open Inventory fallback");
      summary.routes.push({ id: "inventory", realInput: false, fallback: "OpenInventory" });
    } else {
      summary.routes.push({
        id: "inventory",
        realInput: true,
        attempts: await clickUntil(client, [...guiPath, "InventoryButton"], "click Inventory HUD", "game.Players.LocalPlayer.PlayerGui.PunchWallHUD.GameMenu.Visible and game.Players.LocalPlayer.PlayerGui.PunchWallHUD:FindFirstChild('FunctionalInventory',true).Visible"),
      });
    }
    await automation("local a=game.Players.LocalPlayer.PlayerGui.PunchWallHUD.PunchWallClientAutomation a:Invoke('SelectInventoryCategory','All') a:Invoke('SetInventorySearch','') a:Invoke('SetInventoryRarity','All') return true", "prepare Inventory All");
    await captureState("02_iphone17_inventory_all", "Inventory All");
    await automation("local a=game.Players.LocalPlayer.PlayerGui.PunchWallHUD.PunchWallClientAutomation a:Invoke('SelectInventoryCategory','Pets') task.wait(.2) local s=a:Invoke('InventorySnapshot') if s.visibleKeys and s.visibleKeys[1] then a:Invoke('SelectInventoryItem',s.visibleKeys[1]) end return true", "prepare Inventory Pets detail");
    await captureState("03_iphone17_inventory_pets_detail", "Inventory Pets detail");
    await automation("local a=game.Players.LocalPlayer.PlayerGui.PunchWallHUD.PunchWallClientAutomation a:Invoke('SelectInventoryCategory','Honor') return true", "prepare Inventory Honor");
    await captureState("04_iphone17_inventory_honor", "Inventory Honor");

    await automation("local a=game.Players.LocalPlayer.PlayerGui.PunchWallHUD.PunchWallClientAutomation a:Invoke('CloseMenus') return true", "close Inventory");
    if (automationFallback) {
      await automation("local a=game.Players.LocalPlayer.PlayerGui.PunchWallHUD.PunchWallClientAutomation assert(a:Invoke('OpenTab','Fists')==true,'Shop host did not open') return tostring(a:Invoke('OpenShopPage','Fists'))", "open Shop fallback");
      summary.routes.push({ id: "shop", realInput: false, fallback: "OpenTab Fists + OpenShopPage" });
    } else {
      summary.routes.push({
        id: "shop",
        realInput: true,
        attempts: await clickUntil(client, [...guiPath, "ShopButton"], "click Shop HUD", "game.Players.LocalPlayer.PlayerGui.PunchWallHUD.GameMenu.Visible and game.Players.LocalPlayer.PlayerGui.PunchWallHUD:FindFirstChild('FunctionalHeroShop',true).Visible"),
      });
    }
    for (const [page, id] of [["Fists", "05_iphone17_shop_fists"], ["Premium", "06_iphone17_shop_premium"], ["Boosts", "07_iphone17_shop_boosts"], ["Honor", "08_iphone17_shop_honor"], ["Robux", "09_iphone17_shop_robux"]]) {
      await automation(`local a=game.Players.LocalPlayer.PlayerGui.PunchWallHUD.PunchWallClientAutomation return tostring(a:Invoke('OpenShopPage',${JSON.stringify(page)}))`, `open Shop ${page}`);
      await captureState(id, `Shop ${page}`);
    }

    await automation("local a=game.Players.LocalPlayer.PlayerGui.PunchWallHUD.PunchWallClientAutomation a:Invoke('CloseMenus') return true", "close Shop");
    if (automationFallback) {
      await automation("local a=game.Players.LocalPlayer.PlayerGui.PunchWallHUD.PunchWallClientAutomation return tostring(a:Invoke('OpenMore'))", "open Missions fallback");
      summary.routes.push({ id: "missions", realInput: false, fallback: "OpenMore" });
    } else {
      summary.routes.push({
        id: "missions",
        realInput: true,
        attempts: await clickUntil(client, [...guiPath, "MoreTool"], "click More HUD", "(function() local g=game.Players.LocalPlayer.PlayerGui.PunchWallHUD local s=g.PunchWallClientAutomation:Invoke('Snapshot') return g.GameMenu.Visible and s.activeTab=='Tasks' end)()"),
      });
    }
    await captureState("10_iphone17_missions", "Missions");

    await automation("local a=game.Players.LocalPlayer.PlayerGui.PunchWallHUD.PunchWallClientAutomation a:Invoke('CloseMenus') return true", "close Missions");
    requireTool(await client.callTool("execute_luau", { datamodel_type: "Server", code: "local a=game.ServerStorage.PunchWallAutomation a:Invoke('SetStats',{WallLevel=54,Coins=1000000,Rebirths=0}) return true" }, 30000), "seed Rebirth locked");
    if (automationFallback) {
      await automation("local a=game.Players.LocalPlayer.PlayerGui.PunchWallHUD.PunchWallClientAutomation return tostring(a:Invoke('OpenRebirth','iphone17_audit_fallback'))", "open Rebirth fallback");
      summary.routes.push({ id: "rebirth", realInput: false, fallback: "OpenRebirth" });
    } else {
      summary.routes.push({
        id: "rebirth",
        realInput: true,
        attempts: await clickUntil(client, [...guiPath, "RebirthButton"], "click Rebirth HUD", "game.Players.LocalPlayer.PlayerGui.PunchWallHUD.RebirthWindow.Visible"),
      });
    }
    await captureState("11_iphone17_rebirth_locked", "Rebirth locked");
    await automation("local a=game.Players.LocalPlayer.PlayerGui.PunchWallHUD.PunchWallClientAutomation a:Invoke('CloseMenus') return true", "close locked Rebirth");
    requireTool(await client.callTool("execute_luau", { datamodel_type: "Server", code: "local a=game.ServerStorage.PunchWallAutomation a:Invoke('SetStats',{WallLevel=55,Coins=1000000,Rebirths=0}) return true" }, 30000), "seed Rebirth ready");
    await automation("local a=game.Players.LocalPlayer.PlayerGui.PunchWallHUD.PunchWallClientAutomation a:Invoke('OpenRebirth','iphone17_audit') task.wait(.2) a:Invoke('InvokeRebirthAction','Review') return true", "open Rebirth confirm");
    await captureState("12_iphone17_rebirth_confirm", "Rebirth confirm");

    await automation("local a=game.Players.LocalPlayer.PlayerGui.PunchWallHUD.PunchWallClientAutomation a:Invoke('CloseMenus') return true", "close Rebirth");
    if (automationFallback) {
      await automation("local a=game.Players.LocalPlayer.PlayerGui.PunchWallHUD.PunchWallClientAutomation return tostring(a:Invoke('OpenSettings','iphone17_audit_fallback'))", "open Settings fallback");
      summary.routes.push({ id: "settings", realInput: false, fallback: "OpenSettings" });
    } else {
      summary.routes.push({
        id: "settings",
        realInput: true,
        attempts: await clickUntil(client, [...guiPath, "SettingsTool"], "click Settings HUD", "game.Players.LocalPlayer.PlayerGui.PunchWallHUD.SettingsWindow.Visible"),
      });
    }
    await captureState("13_iphone17_settings", "Settings");

    await automation("local a=game.Players.LocalPlayer.PlayerGui.PunchWallHUD.PunchWallClientAutomation a:Invoke('CloseMenus') return true", "close Settings");
    if (automationFallback) {
      await automation("local a=game.Players.LocalPlayer.PlayerGui.PunchWallHUD.PunchWallClientAutomation return tostring(a:Invoke('OpenSpin'))", "open Spin fallback");
      summary.routes.push({ id: "spin", realInput: false, fallback: "OpenSpin" });
    } else {
      summary.routes.push({
        id: "spin",
        realInput: true,
        attempts: await clickUntil(client, [...guiPath, "SpinButton"], "click Spin HUD", "game.Players.LocalPlayer.PlayerGui.PunchWallHUD.HeroSpinModal.Visible"),
      });
    }
    await captureState("14_iphone17_spin", "Hero Spin");

    const runtimeConsole = requireTool(await client.callTool("get_console_output", {}, 30000), "capture audit runtime console");
    assertConsoleClean(runtimeConsole.text, "audit runtime console");
    requireTool(await client.callTool("start_stop_play", { is_start: false }, 60000), "stop iPhone 17 audit");
    started = false;
    await waitForDataModels(client, ["Edit"], 60000);
    const postStopConsole = requireTool(await client.callTool("get_console_output", {}, 30000), "capture audit post-stop console");
    assertConsoleClean(postStopConsole.text, "audit post-stop console");
    summary.console = { runtime: runtimeConsole.text, postStop: postStopConsole.text, clean: true };
    summary.sources["work/automation/scripts/capture-mobile-ui-iphone17.mjs"] = sha256(fileURLToPath(import.meta.url));
    summary.ok = true;
  } finally {
    if (started) {
      await client.callTool("start_stop_play", { is_start: false }, 60000).catch(() => {});
      await waitForDataModels(client, ["Edit"], 60000).catch(() => {});
    }
    if (configured) {
      let cleanupResult;
      for (let attempt = 1; attempt <= 10; attempt += 1) {
        cleanupResult = await client.callTool("execute_luau", {
          datamodel_type: "Edit",
          code: `local H=game:GetService('HttpService') local S=game:GetService('StudioDeviceSimulatorService') pcall(function() S:StopSimulationAsync() end) local removed=0 for _,id in ipairs(S:GetDeviceListAsync()) do local info=S:GetDeviceInfoAsync(id) if info.Name==${JSON.stringify(device.name)} and info.IsCustom then S:RemoveDeviceAsync(id) removed+=1 end end return H:JSONEncode({default=S:GetDeviceAsync()=='default',removed=removed})`,
        }, 30000);
        if (!cleanupResult.isError) break;
        await sleep(500);
      }
      requireTool(cleanupResult, "cleanup iPhone 17 simulator");
      summary.cleanup = JSON.parse(cleanupResult.text);
    }
    client.close();
    fs.mkdirSync(outputDirectory, { recursive: true });
    fs.writeFileSync(path.join(outputDirectory, "capture-summary.json"), JSON.stringify(summary, null, 2));
  }
  console.log(JSON.stringify(summary, null, 2));
}

main().catch((error) => {
  console.error(JSON.stringify({ ok: false, error: error.message }, null, 2));
  process.exitCode = 1;
});
