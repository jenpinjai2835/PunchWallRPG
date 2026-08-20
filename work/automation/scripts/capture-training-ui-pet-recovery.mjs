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
const outputDirectory = path.join(repositoryRoot, "work", "docs", "evidence", "training-ui-pet-recovery-20260820");
const studioInstanceId = process.argv[2];
const studioName = "^SmashWall_TrainingUIPetRecovery_QC[.]rbxlx$";
const deviceName = "QC Training UI Pet Capture 874x402";

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
    .filter((line) => /error|failed|infinite yield|traceback|out of local registers/i.test(line));
  if (suspicious.length) throw new Error(`${label}: ${suspicious.join(" | ")}`);
}

async function main() {
  if (!studioInstanceId) throw new Error("Exact Studio instance id is required");
  fs.mkdirSync(outputDirectory, { recursive: true });
  const client = new McpClient(findStudioMcp(), "training-ui-pet-recovery-capture");
  const summary = { ok: false, captures: [], sources: {}, device: { width: 874, height: 402, name: deviceName } };
  let started = false;
  let configured = false;
  try {
    await client.initialize();
    summary.selectedStudio = await selectStudioStrict(client, { studioInstanceId, studioName, pollAttempts: 12, pollMs: 1000 });
    summary.selectedPlace = await inspectSelectedPlace(client);
    assertPlaceIdentity(summary.selectedPlace, { placeName: studioName });

    const sourceFiles = {
      GameConfig: "work/punch-wall-rpg/src/shared/GameConfig.lua",
      PolishConfig: "work/punch-wall-rpg/src/shared/PolishConfig.lua",
      PunchWallBootstrap: "work/punch-wall-rpg/src/server/PunchWallBootstrap.server.lua",
      InventoryUI: "work/punch-wall-rpg/src/client/InventoryUI.lua",
      PunchWallClient: "work/punch-wall-rpg/src/client/PunchWallClient.client.lua",
    };
    const runtimeResult = requireTool(await client.callTool("execute_luau", {
      datamodel_type: "Edit",
      code: "local H=game:GetService('HttpService') local function fp(s) local a,b=1,0 for i=1,#s do a=(a+string.byte(s,i))%65521 b=(b+a)%65521 end return {length=#s,adler32=b*65536+a} end return H:JSONEncode({GameConfig=fp(game.ReplicatedStorage.GameConfig.Source),PolishConfig=fp(game.ReplicatedStorage.PolishConfig.Source),PunchWallBootstrap=fp(game.ServerScriptService.PunchWallBootstrap.Source),InventoryUI=fp(game.StarterPlayer.StarterPlayerScripts.InventoryUI.Source),PunchWallClient=fp(game.StarterPlayer.StarterPlayerScripts.PunchWallClient.Source)})",
    }, 30000), "fingerprint Studio sources");
    summary.runtimeSources = JSON.parse(runtimeResult.text);
    for (const [name, relative] of Object.entries(sourceFiles)) {
      const full = path.join(repositoryRoot, relative);
      const expected = sourceFingerprint(full);
      const actual = summary.runtimeSources[name];
      if (!actual || actual.length !== expected.length || actual.adler32 !== expected.adler32) {
        throw new Error(`Studio source mismatch for ${name}: ${JSON.stringify({ expected, actual })}`);
      }
      actual.matchesLocal = true;
      actual.file = relative;
      summary.sources[relative] = sha256(full);
    }
    for (const relative of [
      "work/automation/flows/training-ui-pet-recovery.json",
      "work/automation/scripts/training-ui-pet-recovery-contract.mjs",
    ]) {
      summary.sources[relative] = sha256(path.join(repositoryRoot, relative));
    }

    const device = requireTool(await client.callTool("execute_luau", {
      datamodel_type: "Edit",
      code: `local H=game:GetService('HttpService') local S=game:GetService('StudioDeviceSimulatorService') local n=${JSON.stringify(deviceName)} local id for _,x in ipairs(S:GetDeviceListAsync()) do if S:GetDeviceInfoAsync(x).Name==n then id=x break end end local c={Name=n,Width=874,Height=402,PixelDensity=460,DeviceForm=Enum.DeviceForm.Phone} if id then S:UpdateDeviceAsync(id,c) else id=S:CreateDeviceAsync(c) end S:SetDeviceAsync(id) S:SetOrientationAsync(Enum.ScreenOrientation.LandscapeLeft) S:SetScalingModeAsync(Enum.DeviceSimulatorScalingMode.FitToWindow) task.wait(.5) local r=S:GetResolutionAsync() return H:JSONEncode({active=S:GetDeviceAsync()==id,width=r.X,height=r.Y})`,
    }, 30000), "configure iPhone 17");
    summary.device.runtime = JSON.parse(device.text);
    if (!summary.device.runtime.active || summary.device.runtime.width !== 874 || summary.device.runtime.height !== 402) throw new Error(`device mismatch ${device.text}`);
    configured = true;
    await sleep(2500);

    requireTool(await client.callTool("start_stop_play", { is_start: true }, 60000), "start capture play");
    started = true;
    await waitForDataModels(client, ["Server", "Client"], 60000);
    await sleep(8000);

    const serverSeed = requireTool(await client.callTool("execute_luau", {
      datamodel_type: "Server",
      code: "local H=game:GetService('HttpService') local a=game.ServerStorage.PunchWallAutomation local names={'Forest Pup','Miner Cat','Crystal Fox','Lava Dragon','Secret Titan Golem','Crimson Phoenix','Storm Wyvern','Celestial Guardian'} a:Invoke('Reset') local s=a:Invoke('SetStats',{Power=1500,PetInventoryJSON=H:JSONEncode(names),DiscoveredPetsJSON=H:JSONEncode(names),EquippedPetsJSON='[]',LockedPetsJSON='[]'}) a:Invoke('Teleport','Iron Impact Dummy') local root=workspace.PunchWallRPG assert(root:GetAttribute('PetVisualReleaseReady')==true and root:GetAttribute('PetVisualReadyTemplateCount')==8,'pet release gate') return true",
    }, 30000), "seed capture state");
    if (serverSeed.isError) throw new Error(serverSeed.text);
    await sleep(900);

    const capture = async (id, state) => {
      const result = requireTool(await client.callTool("screen_capture", { capture_id: id }, 120000), `capture ${id}`);
      const file = path.join(outputDirectory, `${id}.jpg`);
      fs.writeFileSync(file, Buffer.from(imageData(result.content), "base64"));
      summary.captures.push({ id, state, file, sha256: sha256(file) });
    };
    const runClient = async (code, label) => requireTool(await client.callTool("execute_luau", { datamodel_type: "Client", code }, 60000), label);

    await capture("01_iphone17_training_action", "Eligible Iron training contextual action");
    await runClient("local g=game.Players.LocalPlayer.PlayerGui.PunchWallHUD local a=g.PunchWallClientAutomation a:Invoke('OpenInventory') a:Invoke('SelectInventoryCategory','Pets') a:Invoke('SetInventorySearch','') a:Invoke('SetInventoryRarity','All') task.wait(1) assert(g.GameMenu.FunctionalInventory:GetAttribute('InventoryCompactCardContentVersion')=='StatusRailV4') return true", "open pet Inventory");
    await capture("02_iphone17_inventory_pets", "Compact pet Inventory with exact model previews");
    await runClient("local g=game.Players.LocalPlayer.PlayerGui.PunchWallHUD local a=g.PunchWallClientAutomation a:Invoke('CloseMenus') assert(a:Invoke('OpenTab','Fists')==true,'Shop host did not open') a:Invoke('OpenShopPage','Premium') task.wait(1) assert(g.GameMenu.FunctionalHeroShop.Visible,'Premium Shop did not become visible') return true", "open premium Shop");
    await capture("03_iphone17_shop_premium", "Premium pets with green Robux pricing");
    requireTool(await client.callTool("execute_luau", { datamodel_type: "Server", code: "local a=game.ServerStorage.PunchWallAutomation a:Invoke('Reset') for _,name in ipairs({'Crimson Phoenix','Storm Wyvern','Celestial Guardian'}) do assert(a:Invoke('GrantPremiumPet',name).ok,name) end return true" }, 30000), "equip premium pets");
    await runClient("return game.Players.LocalPlayer.PlayerGui.PunchWallHUD.PunchWallClientAutomation:Invoke('CloseMenus')", "close menus");
    await runClient("local p=game.Players.LocalPlayer local root=p.Character and p.Character:FindFirstChild('HumanoidRootPart') local cam=workspace.CurrentCamera assert(root and cam,'camera target') cam.CameraType=Enum.CameraType.Scriptable cam.FieldOfView=55 local cameraPoint=root.CFrame:PointToWorldSpace(Vector3.new(0,3.2,8)) cam.CFrame=CFrame.lookAt(cameraPoint,root.Position+Vector3.new(0,1.6,0)) local folder=workspace:FindFirstChild(p.Name..' Client Companions') assert(folder and #folder:GetChildren()==3,'premium companions not ready') return true", "frame premium companions");
    await sleep(2000);
    await capture("04_iphone17_premium_companions", "Three exact premium pet models in formation");

    const runtimeConsole = requireTool(await client.callTool("get_console_output", {}, 30000), "capture runtime console");
    assertConsoleClean(runtimeConsole.text, "runtime console");
    requireTool(await client.callTool("start_stop_play", { is_start: false }, 60000), "stop capture play");
    started = false;
    await waitForDataModels(client, ["Edit"], 60000);
    const postStopConsole = requireTool(await client.callTool("get_console_output", {}, 30000), "capture post-stop console");
    assertConsoleClean(postStopConsole.text, "post-stop console");
    summary.console = { clean: true, runtime: runtimeConsole.text, postStop: postStopConsole.text };
    summary.sources["work/automation/scripts/capture-training-ui-pet-recovery.mjs"] = sha256(fileURLToPath(import.meta.url));
    const flowResult = path.join(outputDirectory, "flow-result.json");
    if (fs.existsSync(flowResult)) {
      summary.sources["work/docs/evidence/training-ui-pet-recovery-20260820/flow-result.json"] = sha256(flowResult);
    }
    summary.ok = true;
  } finally {
    if (started) {
      await client.callTool("start_stop_play", { is_start: false }, 60000).catch(() => {});
      await waitForDataModels(client, ["Edit"], 60000).catch(() => {});
    }
    if (configured) {
      const cleanup = await client.callTool("execute_luau", {
        datamodel_type: "Edit",
        code: `local H=game:GetService('HttpService') local S=game:GetService('StudioDeviceSimulatorService') pcall(function() S:StopSimulationAsync() end) local removed=0 for _,id in ipairs(S:GetDeviceListAsync()) do local info=S:GetDeviceInfoAsync(id) if info.Name==${JSON.stringify(deviceName)} and info.IsCustom then S:RemoveDeviceAsync(id) removed+=1 end end return H:JSONEncode({default=S:GetDeviceAsync()=='default',removed=removed})`,
      }, 30000);
      requireTool(cleanup, "cleanup device");
      summary.cleanup = JSON.parse(cleanup.text);
    }
    client.close();
    fs.writeFileSync(path.join(outputDirectory, "capture-summary.json"), `${JSON.stringify(summary, null, 2)}\n`);
  }
  console.log(JSON.stringify(summary, null, 2));
}

main().catch((error) => {
  console.error(JSON.stringify({ ok: false, error: error.message }, null, 2));
  process.exitCode = 1;
});
