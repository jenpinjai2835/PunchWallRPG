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
const outputDirectory = path.join(repositoryRoot, "work", "docs", "evidence", "standalone-windows-20260819");
const studioInstanceId = process.argv[2] || "6d29b2d4-41ab-41fb-838f-3dfd8727c725";
const studioName = "^PunchWallRPG_ManualPlaytest_20260818_FistAuraV10[.]rbxlx$";
const captures = [
  { id: "01_desktop_1366_locked", name: "PunchWallRebirthDesktopLocked", width: 1366, height: 768, form: "Desktop", state: "LOCKED" },
  { id: "02_desktop_1366_confirm", name: "PunchWallRebirthDesktopConfirm", width: 1366, height: 768, form: "Desktop", state: "CONFIRM" },
  { id: "03_phone_844_confirm", name: "PunchWallRebirthPhone844", width: 844, height: 390, form: "Phone", state: "CONFIRM" },
  { id: "04_phone_740_confirm", name: "PunchWallRebirthPhone740", width: 740, height: 360, form: "Phone", state: "CONFIRM" },
];
let activeCaptureStage = "initialization";

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

async function click(client, instancePathSegments, label) {
	activeCaptureStage = `user_mouse_input:${label}`;
  const args = await normalizeMouseInputArgs(client, {
    datamodel_type: "Client",
    actions: [
      { action: "moveTo", instance_path_segments: instancePathSegments },
      { action: "mouseButtonDown", mouse_button: "left", instance_path_segments: instancePathSegments },
      { action: "wait", wait_time_ms: 60 },
      { action: "mouseButtonUp", mouse_button: "left", instance_path_segments: instancePathSegments },
    ],
  });
  requireTool(await client.callTool("user_mouse_input", args, 30000), label);
}

async function clickUntil(client, instancePathSegments, label, datamodelType, predicateCode, attempts = 2) {
  for (let attempt = 1; attempt <= attempts; attempt += 1) {
    await click(client, instancePathSegments, `${label} attempt ${attempt}`);
    await sleep(350);
    const result = requireTool(await client.callTool("execute_luau", {
      datamodel_type: datamodelType,
      code: `return tostring((${predicateCode}) == true)`,
    }, 30000), `${label} verification ${attempt}`);
    if (/true/i.test(result.text)) return attempt;
  }
  throw new Error(`${label} did not reach its verified state after ${attempts} visible attempts`);
}

async function main() {
  fs.mkdirSync(outputDirectory, { recursive: true });
  const client = new McpClient(findStudioMcp(), "punch-wall-rebirth-capture");
  const summary = { ok: false, captures: [], runs: [], sources: {}, routeProof: null, userMouseInputGate: "PENDING" };
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

    for (const capture of captures) {
      const configured = requireTool(await client.callTool("execute_luau", {
        datamodel_type: "Edit",
        code: `local H=game:GetService('HttpService') local S=game:GetService('StudioDeviceSimulatorService') local n=${JSON.stringify(capture.name)} local id for _,x in ipairs(S:GetDeviceListAsync()) do if S:GetDeviceInfoAsync(x).Name==n then id=x break end end local c={Name=n,Width=${capture.width},Height=${capture.height},PixelDensity=${capture.form === "Desktop" ? 96 : 326},DeviceForm=Enum.DeviceForm.${capture.form}} if id then S:UpdateDeviceAsync(id,c) else id=S:CreateDeviceAsync(c) end S:SetDeviceAsync(id) ${capture.form === "Desktop" ? "" : "S:SetOrientationAsync(Enum.ScreenOrientation.LandscapeLeft)"} S:SetScalingModeAsync(Enum.DeviceSimulatorScalingMode.FitToWindow) task.wait(.4) local r=S:GetResolutionAsync() return H:JSONEncode({active=S:GetDeviceAsync()==id,width=r.X,height=r.Y})`,
      }, 30000), `configure ${capture.id}`);
      const device = JSON.parse(configured.text);
      if (!device.active || device.width !== capture.width || device.height !== capture.height) {
        throw new Error(`device mismatch ${capture.id}: ${configured.text}`);
      }
      configuredDevices += 1;

      requireTool(await client.callTool("start_stop_play", { is_start: true }, 35000), `start ${capture.id}`);
      started = true;
      await waitForDataModels(client, ["Server", "Client"], 60000);
      await sleep(6500);
      const ready = capture.state === "CONFIRM";
      requireTool(await client.callTool("execute_luau", {
        datamodel_type: "Server",
        code: `local c=game.ServerStorage.PunchWallAutomation c:Invoke('Reset') c:Invoke('SetStats',{Rebirths=0,WallLevel=${ready ? 55 : 54},Coins=1000000,Power=777,Depth=65,Score=12345}) return true`,
      }, 30000), `seed ${capture.id}`);
      await sleep(450);
      await clickUntil(client,
        ["LocalPlayer", "PlayerGui", "PunchWallHUD", "PixelPerfectHeroCityHUD", "RebirthButton"],
        `open ${capture.id}`,
        "Client",
        "game.Players.LocalPlayer.PlayerGui.PunchWallHUD.RebirthWindow.Visible",
      );
      await sleep(350);
      if (ready) {
        await clickUntil(client,
          ["LocalPlayer", "PlayerGui", "PunchWallHUD", "RebirthWindow", "Body", "Actions", "ReviewRebirth"],
          `review ${capture.id}`,
          "Client",
          "game.Players.LocalPlayer.PlayerGui.PunchWallHUD:GetAttribute('RebirthConfirmationState')=='Armed'",
        );
        await sleep(350);
      }

      const diagnosticsResult = requireTool(await client.callTool("execute_luau", {
        datamodel_type: "Client",
        code: `local H=game:GetService('HttpService') local G=game:GetService('GuiService') local g=game.Players.LocalPlayer.PlayerGui.PunchWallHUD local row=g.RebirthWindow local labels={} for _,x in ipairs(row:GetDescendants()) do if x:IsA('TextLabel') and x.Visible and x.Text~='' then labels[#labels+1]={name=x.Name,text=x.Text,fits=x.TextFits,wrapped=x.TextWrapped,size={x=x.AbsoluteSize.X,y=x.AbsoluteSize.Y}} end end local actions={} local a=row.Body:FindFirstChild('Actions') if a then for _,x in ipairs(a:GetChildren()) do if x:IsA('GuiButton') and x.Visible then actions[#actions+1]={name=x.Name,text=x.Text,active=x.Active,selectable=x.Selectable,fits=x.TextFits,size={x=x.AbsoluteSize.X,y=x.AbsoluteSize.Y}} end end end local expected=${JSON.stringify(capture.state)} local selected=G.SelectedObject local ok=row.Visible and g.GameMenu.Tabs.Visible==false and row:GetAttribute('RebirthState')==expected and #labels>=8 for _,x in ipairs(labels) do ok=ok and x.fits end for _,x in ipairs(actions) do ok=ok and x.fits and x.size.x>=44 and x.size.y>=44 end if expected=='CONFIRM' then ok=ok and g:GetAttribute('RebirthConfirmationState')=='Armed' and #actions==2 else ok=ok and #actions==1 and actions[1].active==false end local result={ok=ok==true,responsiveViewport={x=g:GetAttribute('ResponsiveViewportWidth'),y=g:GetAttribute('ResponsiveViewportHeight')},state=row:GetAttribute('RebirthState'),selected=selected and selected.Name,row={x=row.AbsolutePosition.X,y=row.AbsolutePosition.Y,w=row.AbsoluteSize.X,h=row.AbsoluteSize.Y},labels=labels,actions=actions,dock={w=g.PixelPerfectHeroCityHUD.RebirthButton.AbsoluteSize.X,h=g.PixelPerfectHeroCityHUD.RebirthButton.AbsoluteSize.Y}} assert(result.ok,'Rebirth visual diagnostics failed '..H:JSONEncode(result)) return H:JSONEncode(result)`,
      }, 30000), `diagnostics ${capture.id}`);
      const diagnostics = JSON.parse(diagnosticsResult.text);
      activeCaptureStage = `screen_capture:warmup:${capture.id}`;
      const warmup = requireTool(await client.callTool("screen_capture", { capture_id: `${capture.id}_warmup` }, 60000), `warmup ${capture.id}`);
      imageData(warmup.content);
      await sleep(200);
      activeCaptureStage = `screen_capture:final:${capture.id}`;
      const screenshot = requireTool(await client.callTool("screen_capture", { capture_id: capture.id }, 60000), `capture ${capture.id}`);
      const file = path.join(outputDirectory, `${capture.id}.jpg`);
      fs.writeFileSync(file, Buffer.from(imageData(screenshot.content), "base64"));
      summary.captures.push({ ...capture, diagnostics, file, sha256: sha256(file) });

      if (capture.id === "04_phone_740_confirm") {
        const cancelAttempts = await clickUntil(client,
          ["LocalPlayer", "PlayerGui", "PunchWallHUD", "RebirthWindow", "Body", "Actions", "CancelRebirth"],
          "route 740 cancel",
          "Client",
          "game.Players.LocalPlayer.PlayerGui.PunchWallHUD:GetAttribute('RebirthConfirmationState')=='Canceled'",
        );
        await sleep(250);
        const canceled = requireTool(await client.callTool("execute_luau", {
          datamodel_type: "Server",
          code: "local H=game:GetService('HttpService') local s=game.ServerStorage.PunchWallAutomation:Invoke('Snapshot') local ok=s.Rebirths==0 and s.Coins==1000000 and s.WallLevel==55 assert(ok,'Cancel mutated Rebirth state') return H:JSONEncode({ok=ok,rebirths=s.Rebirths,coins=s.Coins,level=s.WallLevel})",
        }, 30000), "verify route 740 cancel");
        const reviewAttempts = await clickUntil(client,
          ["LocalPlayer", "PlayerGui", "PunchWallHUD", "RebirthWindow", "Body", "Actions", "ReviewRebirth"],
          "route 740 review",
          "Client",
          "game.Players.LocalPlayer.PlayerGui.PunchWallHUD:GetAttribute('RebirthConfirmationState')=='Armed'",
        );
        const confirmAttempts = await clickUntil(client,
          ["LocalPlayer", "PlayerGui", "PunchWallHUD", "RebirthWindow", "Body", "Actions", "ConfirmRebirth"],
          "route 740 confirm",
          "Server",
          "game.ServerStorage.PunchWallAutomation:Invoke('Snapshot').Rebirths==1",
        );
        await sleep(700);
        const confirmed = requireTool(await client.callTool("execute_luau", {
          datamodel_type: "Server",
          code: "local H=game:GetService('HttpService') local s=game.ServerStorage.PunchWallAutomation:Invoke('Snapshot') local ok=s.Rebirths==1 and s.Power==25 and s.Coins==0 and s.WallLevel==1 assert(ok,'Confirm route did not perform exactly one Rebirth '..H:JSONEncode(s)) return H:JSONEncode({ok=ok,rebirths=s.Rebirths,power=s.Power,coins=s.Coins,level=s.WallLevel})",
        }, 30000), "verify route 740 confirm");
        summary.routeProof = {
          device: capture.id,
          path: "real HUD click -> real REVIEW click -> real CANCEL click -> real REVIEW click -> real CONFIRM click",
          attempts: { cancel: cancelAttempts, review: reviewAttempts, confirm: confirmAttempts },
          canceled: JSON.parse(canceled.text),
          confirmed: JSON.parse(confirmed.text),
        };
        summary.userMouseInputGate = "PASS";
      }

      const runtime = requireTool(await client.callTool("get_console_output", {}, 30000), `runtime console ${capture.id}`);
      assertConsoleClean(runtime.text, `runtime console ${capture.id}`);
      requireTool(await client.callTool("start_stop_play", { is_start: false }, 35000), `stop ${capture.id}`);
      started = false;
      const postStop = requireTool(await client.callTool("get_console_output", {}, 30000), `post-stop console ${capture.id}`);
      assertConsoleClean(postStop.text, `post-stop console ${capture.id}`);
      summary.runs.push({ id: capture.id, runtime: runtime.text, postStop: postStop.text });
    }

    for (const relative of [
      ...Object.values(scopedSources),
      "work/automation/flows/rebirth-progression.json",
      "work/automation/scripts/rebirth-progression-contract.mjs",
      "work/automation/scripts/studio_mcp_client.mjs",
      "work/automation/scripts/flow_runner.mjs",
      "work/automation/scripts/capture-rebirth-progression.mjs",
    ]) summary.sources[relative] = sha256(path.join(repositoryRoot, relative));
    const consoleFile = path.join(outputDirectory, "console.txt");
    fs.writeFileSync(consoleFile, summary.runs.map((run) => `[${run.id} runtime]\n${run.runtime}\n[${run.id} post-stop]\n${run.postStop}`).join("\n"));
    summary.console = { file: consoleFile, clean: true };
  } finally {
    if (started) requireTool(await client.callTool("start_stop_play", { is_start: false }, 35000), "final cleanup stop play");
    await waitForDataModels(client, ["Edit"], 60000);
    const cleanup = requireTool(await client.callTool("execute_luau", {
      datamodel_type: "Edit",
      code: `local H=game:GetService('HttpService') local S=game:GetService('StudioDeviceSimulatorService') S:StopSimulationAsync() local names={} for _,name in ipairs({${captures.map((capture) => JSON.stringify(capture.name)).join(",")}}) do names[name]=true end local removed=0 for _,id in ipairs(S:GetDeviceListAsync()) do local info=S:GetDeviceInfoAsync(id) if names[info.Name] and info.IsCustom then S:RemoveDeviceAsync(id) removed+=1 end end return H:JSONEncode({default=S:GetDeviceAsync()=='default',removed=removed})`,
    }, 30000), "cleanup simulator devices");
    summary.cleanup = JSON.parse(cleanup.text);
    client.close();
    if (summary.cleanup.default !== true || summary.cleanup.removed !== configuredDevices) {
      throw new Error(`capture cleanup mismatch: ${cleanup.text}`);
    }
  }
    if (!summary.routeProof?.canceled?.ok || !summary.routeProof?.confirmed?.ok) {
      throw new Error("Rebirth route proof was not completed");
    }
    summary.ok = true;
  fs.writeFileSync(path.join(outputDirectory, "capture-summary.json"), JSON.stringify(summary, null, 2));
  console.log(JSON.stringify(summary, null, 2));
}

main().catch((error) => {
  const blocker = {
    ok: false,
    status: "blocked",
    capturedAt: new Date().toISOString(),
    studioInstanceId,
    studioName,
    stage: activeCaptureStage,
    error: error.message,
    physicalInputPassed: false,
    currentVisualCapturePassed: false,
  };
  fs.mkdirSync(outputDirectory, { recursive: true });
  fs.writeFileSync(path.join(outputDirectory, "capture-blocker.json"), JSON.stringify(blocker, null, 2));
  console.error(JSON.stringify(blocker, null, 2));
  process.exitCode = 1;
});
