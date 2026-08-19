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
const outputDirectory = path.join(repositoryRoot, "work", "docs", "evidence", "honor-progression-20260819");
const studioInstanceId = process.argv[2] || "6d29b2d4-41ab-41fb-838f-3dfd8727c725";
const studioName = "^PunchWallRPG_ManualPlaytest_20260818_FistAuraV10[.]rbxlx$";
const deviceNames = [
  "PunchWallHonorDesktop1366",
  "PunchWallHonorPhone844",
  "PunchWallHonorPhone740",
  "PunchWallHonorWorld1366",
  "PunchWallHonorPhone740Bottom",
  "PunchWallHonorWorld844",
  "PunchWallHonorWorld740",
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
  const client = new McpClient(findStudioMcp());
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
      InventoryViewModel: "work/punch-wall-rpg/src/shared/InventoryViewModel.lua",
      ProfilePersistence: "work/punch-wall-rpg/src/server/ProfilePersistence.lua",
      PunchWallBootstrap: "work/punch-wall-rpg/src/server/PunchWallBootstrap.server.lua",
      PunchWallClient: "work/punch-wall-rpg/src/client/PunchWallClient.client.lua",
    };
    const runtimeSourceResult = requireTool(await client.callTool("execute_luau", {
      datamodel_type: "Edit",
      code: "local H=game:GetService('HttpService') local function fp(s) local a,b=1,0 for i=1,#s do a=(a+string.byte(s,i))%65521 b=(b+a)%65521 end return {length=#s,adler32=b*65536+a} end return H:JSONEncode({GameConfig=fp(game.ReplicatedStorage.GameConfig.Source),InventoryViewModel=fp(game.ReplicatedStorage.InventoryViewModel.Source),ProfilePersistence=fp(game.ServerScriptService.ProfilePersistence.Source),PunchWallBootstrap=fp(game.ServerScriptService.PunchWallBootstrap.Source),PunchWallClient=fp(game.StarterPlayer.StarterPlayerScripts.PunchWallClient.Source)})",
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

    const setDevice = async ({ name, width, height, form }) => {
      const result = requireTool(await client.callTool("execute_luau", {
        datamodel_type: "Edit",
        code: `local H=game:GetService('HttpService') local S=game:GetService('StudioDeviceSimulatorService') local n=${JSON.stringify(name)} local id for _,x in ipairs(S:GetDeviceListAsync()) do if S:GetDeviceInfoAsync(x).Name==n then id=x break end end local c={Name=n,Width=${width},Height=${height},PixelDensity=${form === "Desktop" ? 96 : 326},DeviceForm=Enum.DeviceForm.${form}} if id then S:UpdateDeviceAsync(id,c) else id=S:CreateDeviceAsync(c) end S:SetDeviceAsync(id) ${form === "Desktop" ? "" : "S:SetOrientationAsync(Enum.ScreenOrientation.LandscapeLeft)"} S:SetScalingModeAsync(Enum.DeviceSimulatorScalingMode.FitToWindow) task.wait(.4) local r=S:GetResolutionAsync() return H:JSONEncode({name=n,width=r.X,height=r.Y,active=S:GetDeviceAsync()==id})`,
      }, 30000), `set ${name}`);
      if (!result.text.includes(`\"width\":${width}`) || !result.text.includes(`\"height\":${height}`)) {
        throw new Error(`device resolution mismatch: ${result.text}`);
      }
      configuredDevices += 1;
    };

    const captureRun = async ({ id, name, width, height, form, serverCode, clientCode }) => {
      await setDevice({ name, width, height, form });
      requireTool(await client.callTool("start_stop_play", { is_start: true }, 35000), `start ${id}`);
      started = true;
      await waitForDataModels(client, ["Server", "Client"], 60000);
      await sleep(6500);
      requireTool(await client.callTool("execute_luau", { datamodel_type: "Server", code: serverCode }, 30000), `prepare ${id}`);
      const state = requireTool(await client.callTool("execute_luau", { datamodel_type: "Client", code: clientCode }, 30000), `view ${id}`);
      await sleep(700);
      requireTool(await client.callTool("screen_capture", { capture_id: `${id}_warmup` }, 60000), `warmup ${id}`);
      const capture = requireTool(await client.callTool("screen_capture", { capture_id: id }, 60000), `capture ${id}`);
      requireTool(await client.callTool("execute_luau", {
        datamodel_type: "Client",
        code: "game:GetService('RunService'):UnbindFromRenderStep('HonorCaptureCustomOrbit') return true",
      }, 30000), `release deterministic custom-camera orbit ${id}`);
      const file = path.join(outputDirectory, `${id}.jpg`);
      fs.writeFileSync(file, Buffer.from(imageData(capture.content), "base64"));
      summary.captures.push({ id, device: { name, width, height, form }, state: state.text, file, sha256: sha256(file) });
      const runtimeConsole = requireTool(await client.callTool("get_console_output", {}, 30000), `runtime console ${id}`);
      assertConsoleClean(runtimeConsole.text, `runtime console ${id}`);
      requireTool(await client.callTool("start_stop_play", { is_start: false }, 35000), `stop ${id}`);
      started = false;
      const postStopConsole = requireTool(await client.callTool("get_console_output", {}, 30000), `post-stop console ${id}`);
      assertConsoleClean(postStopConsole.text, `post-stop console ${id}`);
      summary.runs.push({ id, runtime: runtimeConsole.text, postStop: postStopConsole.text });
    };

    const menuView = "local H=game:GetService('HttpService') local p=game.Players.LocalPlayer local g=p.PlayerGui:WaitForChild('PunchWallHUD') local a=g:WaitForChild('PunchWallClientAutomation') a:Invoke('OpenTab','Honor') local deadline=os.clock()+4 repeat task.wait(.05) until a:Invoke('Snapshot').activeTab=='Honor' or os.clock()>=deadline local row=g.GameMenu.Content:FindFirstChild('Vanguard Trail') local b=row and row:FindFirstChild('Vanguard TrailHonorAction',true) assert(b and b.Visible,'Honor row unavailable') return H:JSONEncode({tab=a:Invoke('Snapshot').activeTab,state=b:GetAttribute('HonorState'),text=b.Text,viewport=workspace.CurrentCamera.ViewportSize})";
    await captureRun({
      id: "01_desktop_honor_locked",
      name: deviceNames[0], width: 1366, height: 768, form: "Desktop",
      serverCode: "local c=game.ServerStorage.PunchWallAutomation c:Invoke('Reset') c:Invoke('SetStats',{Depth=0,Rebirths=0,Honor=20,OwnedHonorItemsJSON='[]',EquippedHonorItem='None',HonorPowerBonus=0}) return true",
      clientCode: menuView,
    });
    await captureRun({
      id: "02_phone_844_honor_catalog",
      name: deviceNames[1], width: 844, height: 390, form: "Phone",
      serverCode: "local c=game.ServerStorage.PunchWallAutomation c:Invoke('Reset') c:Invoke('SetStats',{Depth=75,Rebirths=25,Honor=1100,OwnedHonorItemsJSON='[]',EquippedHonorItem='None',HonorPowerBonus=0}) return true",
      clientCode: menuView,
    });
    await captureRun({
      id: "03_phone_740_honor_equipped",
      name: deviceNames[2], width: 740, height: 360, form: "Phone",
      serverCode: "local c=game.ServerStorage.PunchWallAutomation c:Invoke('Reset') c:Invoke('SetStats',{Depth=75,Rebirths=25,Honor=20}) local r=c:Invoke('BuyHonorItem','vanguard_trail') assert(r.ok) return true",
      clientCode: menuView,
    });
    await captureRun({
      id: "04_desktop_honor_world",
      name: deviceNames[3], width: 1366, height: 768, form: "Desktop",
      serverCode: "local c=game.ServerStorage.PunchWallAutomation local p=game.Players:GetPlayers()[1] c:Invoke('Reset') local root=p.Character.HumanoidRootPart root.AssemblyLinearVelocity=Vector3.zero root.CFrame=CFrame.lookAt(Vector3.new(22,3,-5),Vector3.new(22,3,28)) return true",
      clientCode: "local H=game:GetService('HttpService') local R=game:GetService('RunService') local p=game.Players.LocalPlayer local g=p.PlayerGui:WaitForChild('PunchWallHUD') local a=g.PunchWallClientAutomation a:Invoke('CloseMenus') assert(a:Invoke('ResetCamera'),'player camera reset failed') local cam=workspace.CurrentCamera local hum=p.Character and p.Character:FindFirstChildOfClass('Humanoid') p.CameraMode=Enum.CameraMode.Classic p.CameraMinZoomDistance=18 p.CameraMaxZoomDistance=18 cam.FieldOfView=68 R:BindToRenderStep('HonorCaptureCustomOrbit',Enum.RenderPriority.Camera.Value+1,function() cam.CFrame=CFrame.lookAt(Vector3.new(22,8,-22),Vector3.new(22,5,-5)) cam.Focus=CFrame.new(22,5,-5) end) task.wait(1.2) assert(cam.CameraType==Enum.CameraType.Custom and cam.CameraSubject==hum,'normal player camera not active') return H:JSONEncode({menu=g.GameMenu.Visible,world='HonorPlaza',camera=tostring(cam.CameraType),subject=cam.CameraSubject==hum,zoom=p.CameraMaxZoomDistance,orbit='reachable-third-person',viewport=cam.ViewportSize})",
    });
    await captureRun({
      id: "05_phone_740_honor_bottom_selected",
      name: deviceNames[4], width: 740, height: 360, form: "Phone",
      serverCode: "local c=game.ServerStorage.PunchWallAutomation c:Invoke('Reset') c:Invoke('SetStats',{Depth=75,Rebirths=25,Honor=1100,OwnedHonorItemsJSON='[]',EquippedHonorItem='None',HonorPowerBonus=0}) return true",
      clientCode: "local H=game:GetService('HttpService') local p=game.Players.LocalPlayer local g=p.PlayerGui:WaitForChild('PunchWallHUD') local a=g:WaitForChild('PunchWallClientAutomation') assert(a:Invoke('OpenHonorItem','eternal_crown_of_honor')==true,'OpenHonorItem rejected exact id') local deadline=os.clock()+4 local content=g.GameMenu.Content local row,button repeat row=content:FindFirstChild('Eternal Crown of Honor') button=row and row:FindFirstChild('Eternal Crown of HonorHonorAction',true) task.wait(.05) until (g:GetAttribute('SelectedHonorItemId')=='eternal_crown_of_honor' and button) or os.clock()>=deadline task.wait(2.2) row=content:FindFirstChild('Eternal Crown of Honor') button=row and row:FindFirstChild('Eternal Crown of HonorHonorAction',true) local top=row and row.AbsolutePosition.Y or -1 local bottom=row and top+row.AbsoluteSize.Y or -1 local viewTop=content.AbsolutePosition.Y local viewBottom=viewTop+content.AbsoluteSize.Y local ok=button and row:GetAttribute('HonorWorldSelection')=='eternal_crown_of_honor' and content.CanvasPosition.Y>0 and top>=viewTop-2 and bottom<=viewBottom+2 and math.min(button.AbsoluteSize.X,button.AbsoluteSize.Y)>=44 assert(ok,'phone bottom Honor row not safely visible after stat refresh '..H:JSONEncode({canvas=content.CanvasPosition.Y,top=top,bottom=bottom,viewTop=viewTop,viewBottom=viewBottom,selected=g:GetAttribute('SelectedHonorItemId'),highlight=row and row:GetAttribute('HonorWorldSelection')})) return H:JSONEncode({tab=a:Invoke('Snapshot').activeTab,item=button:GetAttribute('HonorItemId'),state=button:GetAttribute('HonorState'),canvas=content.CanvasPosition.Y,min=math.min(button.AbsoluteSize.X,button.AbsoluteSize.Y),viewport=workspace.CurrentCamera.ViewportSize})",
    });
    const phoneWorldView = "local H=game:GetService('HttpService') local R=game:GetService('RunService') local p=game.Players.LocalPlayer local g=p.PlayerGui:WaitForChild('PunchWallHUD') local a=g.PunchWallClientAutomation a:Invoke('CloseMenus') assert(a:Invoke('ResetCamera'),'player camera reset failed') local cam=workspace.CurrentCamera local hum=p.Character and p.Character:FindFirstChildOfClass('Humanoid') p.CameraMode=Enum.CameraMode.Classic p.CameraMinZoomDistance=18 p.CameraMaxZoomDistance=18 cam.FieldOfView=68 R:BindToRenderStep('HonorCaptureCustomOrbit',Enum.RenderPriority.Camera.Value+1,function() cam.CFrame=CFrame.lookAt(Vector3.new(22,8,-22),Vector3.new(22,5,-5)) cam.Focus=CFrame.new(22,5,-5) end) task.wait(1.2) assert(cam.CameraType==Enum.CameraType.Custom and cam.CameraSubject==hum,'normal player camera not active') return H:JSONEncode({menu=g.GameMenu.Visible,world='HonorPlaza',camera=tostring(cam.CameraType),subject=cam.CameraSubject==hum,zoom=p.CameraMaxZoomDistance,orbit='reachable-third-person',viewport=cam.ViewportSize})";
    const phoneWorldServer = "local c=game.ServerStorage.PunchWallAutomation local p=game.Players:GetPlayers()[1] c:Invoke('Reset') local root=p.Character.HumanoidRootPart root.AssemblyLinearVelocity=Vector3.zero root.CFrame=CFrame.lookAt(Vector3.new(22,3,-5),Vector3.new(22,3,28)) return true";
    await captureRun({
      id: "06_phone_844_honor_world",
      name: deviceNames[5], width: 844, height: 390, form: "Phone",
      serverCode: phoneWorldServer,
      clientCode: phoneWorldView,
    });
    await captureRun({
      id: "07_phone_740_honor_world",
      name: deviceNames[6], width: 740, height: 360, form: "Phone",
      serverCode: phoneWorldServer,
      clientCode: phoneWorldView,
    });

    const consoleFile = path.join(outputDirectory, "console.txt");
    fs.writeFileSync(consoleFile, summary.runs.map((run) => `[${run.id} runtime]\n${run.runtime}\n[${run.id} post-stop]\n${run.postStop}`).join("\n"));
    summary.console = { file: consoleFile, clean: true };
    for (const relative of [
      ...Object.values(scopedSources),
      "work/automation/flows/honor-progression.json",
      "work/automation/scripts/honor-progression-contract.mjs",
      "work/automation/scripts/capture-honor-progression.mjs",
    ]) summary.sources[relative] = sha256(path.join(repositoryRoot, relative));
  } finally {
    if (started) requireTool(await client.callTool("start_stop_play", { is_start: false }, 35000), "final cleanup stop play");
    const cleanupResult = requireTool(await client.callTool("execute_luau", {
      datamodel_type: "Edit",
      code: `local H=game:GetService('HttpService') local S=game:GetService('StudioDeviceSimulatorService') S:StopSimulationAsync() local names={} for _,name in ipairs({${deviceNames.map((name) => JSON.stringify(name)).join(",")}}) do names[name]=true end local removed=0 for _,id in ipairs(S:GetDeviceListAsync()) do local info=S:GetDeviceInfoAsync(id) if names[info.Name] and info.IsCustom then S:RemoveDeviceAsync(id) removed+=1 end end return H:JSONEncode({default=S:GetDeviceAsync()=='default',removed=removed})`,
    }, 30000), "cleanup simulator devices");
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
