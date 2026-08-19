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
const outputDirectory = path.join(repositoryRoot, "work", "docs", "evidence", "power-avatar-growth-20260819");
const studioInstanceId = process.argv[2] || "6d29b2d4-41ab-41fb-838f-3dfd8727c725";
const studioName = "^PunchWallRPG_ManualPlaytest_20260818_FistAuraV10[.]rbxlx$";

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

function assertConsoleClean(value, label) {
  const suspicious = String(value || "").split(/\r?\n/).filter(Boolean)
    .filter((line) => !line.includes("Unpublished Studio session is EPHEMERAL"))
    .filter((line) => /error|failed|stack begin|infinite yield|traceback/i.test(line));
  if (suspicious.length) throw new Error(`${label}: ${suspicious.join(" | ")}`);
}

async function main() {
  fs.mkdirSync(outputDirectory, { recursive: true });
  const client = new McpClient(findStudioMcp());
  const summary = { ok: false, captures: [] };
  let started = false;
  try {
    await client.initialize();
    summary.selectedStudio = await selectStudioStrict(client, { studioInstanceId, studioName, pollAttempts: 15, pollMs: 3000 });
    summary.selectedPlace = await inspectSelectedPlace(client);
    assertPlaceIdentity(summary.selectedPlace, { placeName: studioName });
    requireTool(await client.callTool("start_stop_play", { is_start: true }, 35000), "start play");
    started = true;
    await waitForDataModels(client, ["Server", "Client"], 60000);
    await sleep(7000);

    const captureState = async (id, power, pets) => {
      requireTool(await client.callTool("execute_luau", {
        datamodel_type: "Server",
        code: `local c=game.ServerStorage.PunchWallAutomation local p=game.Players:GetPlayers()[1] c:Invoke('Reset') c:Invoke('SetStats',{Power=${power},WallLevel=1}) ${pets ? "for _,n in ipairs({'Forest Pup','Miner Cat','Crystal Fox'}) do c:Invoke('GrantPet',{name=n,stars=1}) end" : ""} local r=p.Character.HumanoidRootPart r.AssemblyLinearVelocity=Vector3.zero r.CFrame=CFrame.lookAt(Vector3.new(-2,3,-15),Vector3.new(-2,3,-40)) task.wait(.8) return true`,
      }, 30000), `prepare ${id}`);
      requireTool(await client.callTool("execute_luau", {
        datamodel_type: "Client",
        code: "local R=game:GetService('RunService') local p=game.Players.LocalPlayer local c=p.Character local r=c.HumanoidRootPart local cam=workspace.CurrentCamera local g=p.PlayerGui:WaitForChild('PunchWallHUD') g.Enabled=true g.GameMenu.Visible=false cam.CameraType=Enum.CameraType.Scriptable R:UnbindFromRenderStep('PowerGrowthCapture') R:BindToRenderStep('PowerGrowthCapture',Enum.RenderPriority.Camera.Value+1000,function() local focus=r.Position+Vector3.new(0,2.2,0) cam.CFrame=CFrame.lookAt(r.Position+Vector3.new(8,4.8,9),focus) cam.Focus=CFrame.new(focus) end) task.wait(1) return true",
      }, 30000), `camera ${id}`);
      requireTool(await client.callTool("screen_capture", { capture_id: `${id}_warmup` }, 60000), `warmup ${id}`);
      const capture = requireTool(await client.callTool("screen_capture", { capture_id: id }, 60000), `capture ${id}`);
      const file = path.join(outputDirectory, `${id}.jpg`);
      fs.writeFileSync(file, Buffer.from(imageData(capture.content), "base64"));
      summary.captures.push({ id, power, pets, file, sha256: sha256(file) });
    };

    await captureState("01_power_15_baseline", 15, false);
    await captureState("02_power_1500000000_three_pets", 1500000000, true);
    requireTool(await client.callTool("execute_luau", {
      datamodel_type: "Client",
      code: "game:GetService('RunService'):UnbindFromRenderStep('PowerGrowthCapture') return true",
    }, 30000), "release capture camera");
    const runtimeConsole = requireTool(await client.callTool("get_console_output", {}, 30000), "runtime console");
    assertConsoleClean(runtimeConsole.text, "runtime console");
    requireTool(await client.callTool("start_stop_play", { is_start: false }, 35000), "stop play");
    started = false;
    const postStopConsole = requireTool(await client.callTool("get_console_output", {}, 30000), "post-stop console");
    assertConsoleClean(postStopConsole.text, "post-stop console");
    summary.console = { runtime: runtimeConsole.text, postStop: postStopConsole.text, clean: true };
    summary.sources = {};
    for (const relative of [
      "work/punch-wall-rpg/src/shared/GameConfig.lua",
      "work/punch-wall-rpg/src/server/PunchWallBootstrap.server.lua",
      "work/punch-wall-rpg/src/client/PunchWallClient.client.lua",
      "work/automation/flows/power-avatar-growth.json",
    ]) summary.sources[relative] = sha256(path.join(repositoryRoot, relative));
    summary.ok = true;
    fs.writeFileSync(path.join(outputDirectory, "capture-summary.json"), JSON.stringify(summary, null, 2));
    console.log(JSON.stringify(summary, null, 2));
  } finally {
    if (started) await client.callTool("start_stop_play", { is_start: false }, 35000);
    client.close();
  }
}

main().catch((error) => {
  console.error(JSON.stringify({ ok: false, error: error.message }, null, 2));
  process.exitCode = 1;
});
