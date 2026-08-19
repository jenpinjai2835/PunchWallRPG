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

function parseArgs(argv) {
  const options = {
    outDir: path.join(repositoryRoot, "work", "docs", "evidence", "world-boost-showcases-20260819"),
    studioName: "PunchWallRPG_ManualPlaytest_20260818_FistAuraV10.rbxlx",
    placeName: "^PunchWallRPG_ManualPlaytest_20260818_FistAuraV10[.]rbxlx$",
  };
  for (let index = 0; index < argv.length; index += 1) {
    const key = argv[index];
    const value = argv[index + 1];
    if (key === "--out-dir") options.outDir = path.resolve(value), index += 1;
    else if (key === "--studio-name") options.studioName = value, index += 1;
    else if (key === "--studio-instance-id") options.studioInstanceId = value, index += 1;
    else if (key === "--place-name") options.placeName = value, index += 1;
    else throw new Error(`Unknown argument: ${key}`);
  }
  return options;
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
  const value = fs.readFileSync(file, "utf8").replace(/\r\n?/g, "\n");
  const bytes = Buffer.from(value, "utf8");
  let a = 1;
  let b = 0;
  for (const byte of bytes) {
    a = (a + byte) % 65521;
    b = (b + a) % 65521;
  }
  return { length: bytes.length, adler32: b * 65536 + a };
}

function requireTool(result, label) {
  if (result?.isError) throw new Error(`${label}: ${result.text}`);
  return result;
}

function assertConsoleClean(text, label) {
  const unexpected = String(text ?? "")
    .split(/\r?\n/)
    .filter(Boolean)
    .filter((line) => !line.includes("Unpublished Studio session is EPHEMERAL"))
    .filter((line) => /error|failed|stack begin|infinite yield|traceback/i.test(line));
  if (unexpected.length) throw new Error(`${label}: ${unexpected.join(" | ")}`);
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  fs.mkdirSync(options.outDir, { recursive: true });
  const client = new McpClient(findStudioMcp());
  const summary = { ok: false, captures: [], sources: {} };
  let started = false;
  const deviceNames = [
    "PunchWall Gate3 Desktop 1366x768",
    "PunchWall Gate3 Phone 844x390",
    "PunchWall Gate3 Phone 740x360",
  ];
  try {
    await client.initialize();
    summary.selectedStudio = await selectStudioStrict(client, {
      studioInstanceId: options.studioInstanceId,
      studioName: options.studioName,
      pollAttempts: 15,
      pollMs: 3000,
    });
    summary.selectedPlace = await inspectSelectedPlace(client);
    assertPlaceIdentity(summary.selectedPlace, { placeName: options.placeName });
    const scopedSourceFiles = {
      GameConfig: "work/punch-wall-rpg/src/shared/GameConfig.lua",
      PunchWallBootstrap: "work/punch-wall-rpg/src/server/PunchWallBootstrap.server.lua",
      PunchWallClient: "work/punch-wall-rpg/src/client/PunchWallClient.client.lua",
    };
    const runtimeSourceResult = requireTool(await client.callTool("execute_luau", {
      datamodel_type: "Edit",
      code: "local H=game:GetService('HttpService') local function fp(s) local a,b=1,0 for i=1,#s do a=(a+string.byte(s,i))%65521 b=(b+a)%65521 end return {length=#s,adler32=b*65536+a} end return H:JSONEncode({GameConfig=fp(game.ReplicatedStorage.GameConfig.Source),PunchWallBootstrap=fp(game.ServerScriptService.PunchWallBootstrap.Source),PunchWallClient=fp(game.StarterPlayer.StarterPlayerScripts.PunchWallClient.Source)})",
    }, 30000), "fingerprint running Studio sources");
    summary.runtimeSources = JSON.parse(runtimeSourceResult.text);
    for (const [name, relative] of Object.entries(scopedSourceFiles)) {
      const file = path.join(repositoryRoot, relative);
      const expected = sourceFingerprint(file);
      const actual = summary.runtimeSources[name];
      if (!actual || actual.length !== expected.length || actual.adler32 !== expected.adler32) {
        throw new Error(`Studio source mismatch for ${name}: ${JSON.stringify({ expected, actual })}`);
      }
      summary.runtimeSources[name].file = relative;
      summary.runtimeSources[name].matchesLocal = true;
    }
    const setDevice = async ({ name, width, height, form }) => {
      const result = requireTool(await client.callTool("execute_luau", {
        datamodel_type: "Edit",
        code: `local H=game:GetService('HttpService') local S=game:GetService('StudioDeviceSimulatorService') local n=${JSON.stringify(name)} local id for _,x in ipairs(S:GetDeviceListAsync()) do if S:GetDeviceInfoAsync(x).Name==n then id=x break end end local c={Name=n,Width=${width},Height=${height},PixelDensity=${form === "Desktop" ? 96 : 326},DeviceForm=Enum.DeviceForm.${form}} if id then S:UpdateDeviceAsync(id,c) else id=S:CreateDeviceAsync(c) end S:SetDeviceAsync(id) ${form === "Desktop" ? "" : "S:SetOrientationAsync(Enum.ScreenOrientation.LandscapeLeft)"} S:SetScalingModeAsync(Enum.DeviceSimulatorScalingMode.FitToWindow) task.wait(.4) local r=S:GetResolutionAsync() return H:JSONEncode({name=n,width=r.X,height=r.Y,active=S:GetDeviceAsync()==id})`,
      }, 30000), `set ${name}`);
      if (!result.text.includes(`\"width\":${width}`) || !result.text.includes(`\"height\":${height}`)) {
        throw new Error(`device resolution mismatch for ${name}: ${result.text}`);
      }
    };

    const capturePlayerView = async ({ id, name, width, height, form, overview = false }) => {
      await setDevice({ name, width, height, form });
      requireTool(await client.callTool("start_stop_play", { is_start: true }, 35000), `start ${id}`);
      started = true;
      await waitForDataModels(client, ["Server", "Client"], 60000);
      await sleep(7000);
      requireTool(await client.callTool("execute_luau", {
        datamodel_type: "Server",
        code: "local p=game.Players:GetPlayers()[1] local c=p and (p.Character or p.CharacterAdded:Wait()) local r=c and c:FindFirstChild('HumanoidRootPart') assert(r,'player root missing') r.AssemblyLinearVelocity=Vector3.zero r.CFrame=CFrame.lookAt(Vector3.new(34,3,-10),Vector3.new(34,3,-21.5)) return true",
      }, 30000), `place player ${id}`);
      requireTool(await client.callTool("execute_luau", {
        datamodel_type: "Client",
        code: "local H=game:GetService('HttpService') local R=game:GetService('RunService') local p=game.Players.LocalPlayer local g=p.PlayerGui:WaitForChild('PunchWallHUD') local c=p.Character or p.CharacterAdded:Wait() local h=c:FindFirstChildOfClass('Humanoid') local cam=workspace.CurrentCamera g.Enabled=true g.GameMenu.Visible=false cam.CameraType=Enum.CameraType.Custom cam.CameraSubject=h cam.FieldOfView=50 R:UnbindFromRenderStep('Gate3PlayerRouteCapture') R:BindToRenderStep('Gate3PlayerRouteCapture',Enum.RenderPriority.Camera.Value+1000,function() cam.CFrame=CFrame.lookAt(Vector3.new(34,8,0),Vector3.new(34,3.5,-21.5)) cam.Focus=CFrame.new(34,3.5,-21.5) end) task.wait(1.2) return H:JSONEncode({viewportX=cam.ViewportSize.X,viewportY=cam.ViewportSize.Y,hud=g.Enabled,camera=cam.CameraType.Name})",
      }, 30000), `prepare player camera ${id}`);
      requireTool(await client.callTool("screen_capture", { capture_id: `${id}_warmup` }, 60000), `warmup ${id}`);
      await sleep(200);
      const capture = requireTool(await client.callTool("screen_capture", { capture_id: id }, 60000), `capture ${id}`);
      const file = path.join(options.outDir, `${id}.jpg`);
      fs.writeFileSync(file, Buffer.from(imageData(capture.content), "base64"));
      summary.captures.push({ id, view: "actual-player", device: { name, width, height, form }, file, sha256: sha256(file) });
      if (overview) {
        const overviewId = "02_desktop_overview";
        requireTool(await client.callTool("execute_luau", {
          datamodel_type: "Client",
          code: "game:GetService('RunService'):UnbindFromRenderStep('Gate3PlayerRouteCapture') return true",
        }, 30000), `release player camera ${id}`);
        const overviewCapture = requireTool(await client.callTool("screen_capture", {
          capture_id: overviewId,
          camera_position: [-4, 9, -6],
          look_at_position: [34, 3.6, -21.5],
        }, 60000), `capture ${overviewId}`);
        const overviewFile = path.join(options.outDir, `${overviewId}.jpg`);
        fs.writeFileSync(overviewFile, Buffer.from(imageData(overviewCapture.content), "base64"));
        summary.captures.push({ id: overviewId, view: "overview", file: overviewFile, sha256: sha256(overviewFile) });
      }
      const runtimeConsole = requireTool(await client.callTool("get_console_output", {}, 30000), `runtime console ${id}`);
      assertConsoleClean(runtimeConsole.text, `runtime console ${id}`);
      requireTool(await client.callTool("start_stop_play", { is_start: false }, 35000), `stop ${id}`);
      started = false;
      const postStopConsole = requireTool(await client.callTool("get_console_output", {}, 30000), `post-stop console ${id}`);
      assertConsoleClean(postStopConsole.text, `post-stop console ${id}`);
      return { id, runtime: runtimeConsole.text, postStop: postStopConsole.text };
    };

    summary.runs = [];
    summary.runs.push(await capturePlayerView({ id: "01_desktop_player_route", name: deviceNames[0], width: 1366, height: 768, form: "Desktop", overview: true }));
    summary.runs.push(await capturePlayerView({ id: "03_phone_844_player_route", name: deviceNames[1], width: 844, height: 390, form: "Phone" }));
    summary.runs.push(await capturePlayerView({ id: "04_phone_740_player_route", name: deviceNames[2], width: 740, height: 360, form: "Phone" }));
    const consoleFile = path.join(options.outDir, "console.txt");
    fs.writeFileSync(consoleFile, summary.runs.map((run) => `[${run.id} runtime]\n${run.runtime}\n[${run.id} post-stop]\n${run.postStop}`).join("\n"));
    summary.console = { file: consoleFile, clean: true };
    for (const relative of [
      "work/punch-wall-rpg/src/server/PunchWallBootstrap.server.lua",
      "work/punch-wall-rpg/src/client/PunchWallClient.client.lua",
      "work/automation/flows/world-boost-showcases.json",
    ]) {
      summary.sources[relative] = sha256(path.join(repositoryRoot, relative));
    }
  } finally {
    if (started) requireTool(await client.callTool("start_stop_play", { is_start: false }, 35000), "final cleanup stop play");
    const cleanupResult = requireTool(await client.callTool("execute_luau", {
      datamodel_type: "Edit",
      code: `local H=game:GetService('HttpService') local S=game:GetService('StudioDeviceSimulatorService') S:StopSimulationAsync() local names={} for _,name in ipairs({${deviceNames.map((name) => JSON.stringify(name)).join(",")}}) do names[name]=true end local removed=0 for _,id in ipairs(S:GetDeviceListAsync()) do local info=S:GetDeviceInfoAsync(id) if names[info.Name] and info.IsCustom then S:RemoveDeviceAsync(id) removed+=1 end end return H:JSONEncode({default=S:GetDeviceAsync()=='default',removed=removed})`,
    }, 30000), "cleanup capture simulator devices");
    summary.cleanup = JSON.parse(cleanupResult.text);
    client.close();
    if (summary.cleanup.default !== true || summary.cleanup.removed !== deviceNames.length) {
      throw new Error(`capture simulator cleanup mismatch: ${cleanupResult.text}`);
    }
  }
  summary.ok = true;
  fs.writeFileSync(path.join(options.outDir, "capture-summary.json"), JSON.stringify(summary, null, 2));
  console.log(JSON.stringify(summary, null, 2));
}

main().catch((error) => {
  console.error(JSON.stringify({ ok: false, error: error.message }, null, 2));
  process.exitCode = 1;
});
