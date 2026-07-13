#!/usr/bin/env node
import { spawn } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

function parseArgs(argv) {
  const args = {
    outDir: "F:\\Roblox\\PuchWall\\work\\docs\\qc-screenshots\\kaiju-city",
    studioName: "PunchWallRPGPlayable",
    waitMs: 7000,
    combatOnly: false,
  };
  for (let index = 0; index < argv.length; index += 1) {
    const key = argv[index];
    const value = argv[index + 1];
    if (key === "--out-dir") {
      args.outDir = value;
      index += 1;
    } else if (key === "--studio-name") {
      args.studioName = value;
      index += 1;
    } else if (key === "--wait-ms") {
      args.waitMs = Number(value);
      index += 1;
    } else if (key === "--combat-only") {
      args.combatOnly = true;
    }
  }
  return args;
}

function findStudioMcp() {
  const localAppData = process.env.LOCALAPPDATA || path.join(os.homedir(), "AppData", "Local");
  const versionsDir = path.join(localAppData, "Roblox", "Versions");
  const candidates = [];
  for (const versionName of fs.readdirSync(versionsDir)) {
    const candidate = path.join(versionsDir, versionName, "StudioMCP.exe");
    if (fs.existsSync(candidate)) {
      candidates.push({ file: candidate, mtimeMs: fs.statSync(candidate).mtimeMs });
    }
  }
  candidates.sort((left, right) => right.mtimeMs - left.mtimeMs);
  if (!candidates.length) throw new Error("Could not find StudioMCP.exe");
  return candidates[0].file;
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function textOf(response) {
  return response?.result?.content?.map((item) => item.text ?? "").join("\n") ?? JSON.stringify(response);
}

class McpClient {
  constructor(command) {
    this.nextId = 1;
    this.responses = new Map();
    this.buffer = "";
    this.child = spawn(command, ["--stdio"], { stdio: ["pipe", "pipe", "pipe"] });
    this.child.stdout.on("data", (data) => this.onData(data.toString()));
  }

  onData(text) {
    this.buffer += text;
    let lineEnd;
    while ((lineEnd = this.buffer.indexOf("\n")) >= 0) {
      const line = this.buffer.slice(0, lineEnd).trim();
      this.buffer = this.buffer.slice(lineEnd + 1);
      if (!line) continue;
      const message = JSON.parse(line);
      if (message.id !== undefined) this.responses.set(message.id, message);
    }
  }

  send(method, params = {}) {
    const id = this.nextId++;
    this.child.stdin.write(JSON.stringify({ jsonrpc: "2.0", id, method, params }) + "\n");
    return id;
  }

  notify(method, params = {}) {
    this.child.stdin.write(JSON.stringify({ jsonrpc: "2.0", method, params }) + "\n");
  }

  async waitFor(id, timeoutMs = 30000) {
    const started = Date.now();
    while (Date.now() - started < timeoutMs) {
      if (this.responses.has(id)) {
        const response = this.responses.get(id);
        this.responses.delete(id);
        return response;
      }
      await sleep(50);
    }
    throw new Error(`Timed out waiting for response ${id}`);
  }

  async initialize() {
    await this.waitFor(this.send("initialize", {
      protocolVersion: "2024-11-05",
      capabilities: {},
      clientInfo: { name: "codex-roblox-qc-capture", version: "0.1.0" },
    }));
    this.notify("notifications/initialized");
  }

  async callTool(name, args = {}, timeoutMs = 30000) {
    const response = await this.waitFor(this.send("tools/call", { name, arguments: args }), timeoutMs);
    return {
      raw: response,
      text: textOf(response),
      content: response?.result?.content ?? [],
      isError: response?.result?.isError === true,
    };
  }

  close() {
    this.child.kill();
  }
}

function imageDataFromContent(content) {
  const image = content.find((item) => item.type === "image" && item.data);
  if (!image) throw new Error("screen_capture did not return image data");
  return image.data;
}

function saveImage(file, base64) {
  fs.writeFileSync(file, Buffer.from(base64, "base64"));
}

async function captureStable(client, args) {
  await client.callTool("screen_capture", { ...args, capture_id: `${args.capture_id}_warmup` }, 60000);
  await sleep(180);
  return client.callTool("screen_capture", args, 60000);
}

async function selectStudio(client, studioName) {
  let studios = [];
  for (let attempt = 0; attempt < 15; attempt += 1) {
    const list = await client.callTool("list_roblox_studios", {}, 15000);
    try {
      studios = JSON.parse(list.text).studios ?? [];
    } catch {
      studios = [];
    }
    if (studios.length) break;
    await sleep(3000);
  }
  if (!studios.length) throw new Error("No Roblox Studio instances registered with MCP");
  const matcher = new RegExp(studioName, "i");
  const studio = studios.find((item) => matcher.test(item.name)) ?? studios[0];
  await client.callTool("set_active_studio", { studio_id: studio.id });
  return studio;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  fs.mkdirSync(args.outDir, { recursive: true });
  const client = new McpClient(findStudioMcp());
  const captures = [
    { id: "01_spawn_player_view", camera: [-60, 7, 8], look: [-15, 8, -21] },
    { id: "02_wall_lane_close", camera: [-34, 8, -6], look: [32, 10, -27] },
    { id: "03_wall_facade_detail", camera: [-6, 10, -9], look: [20, 11, -27] },
    { id: "04_shop_and_lab", camera: [-100, 11, 10], look: [-55, 6, 12] },
    { id: "05_boss_tower", camera: [138, 28, 10], look: [82, 17, 27] },
    { id: "05b_boss_front", camera: [82, 25, -28], look: [82, 20, 27] },
    { id: "06_long_progression_read", camera: [-88, 32, -82], look: [76, 12, -22] },
  ];

  let playStarted = false;
  const summary = { captures: [], selectedStudio: null };
  try {
    await client.initialize();
    summary.selectedStudio = await selectStudio(client, args.studioName);
    const state = await client.callTool("get_studio_state");
    if (/Current Studio Mode:\s*Edit/i.test(state.text)) {
      await client.callTool("start_stop_play", { is_start: true }, 35000);
      playStarted = true;
      await sleep(args.waitMs);
    }

    for (const capture of args.combatOnly ? [] : captures) {
      const result = await captureStable(client, {
        capture_id: capture.id,
        camera_position: capture.camera,
        look_at_position: capture.look,
      });
      const file = path.join(args.outDir, `${capture.id}.jpg`);
      saveImage(file, imageDataFromContent(result.content));
      summary.captures.push({ id: capture.id, file, camera: capture.camera, look: capture.look });
      await sleep(400);
    }

    await client.callTool("execute_luau", {
      datamodel_type: "Server",
      code: `local c=game.ServerStorage:WaitForChild("PunchWallAutomation")
c:Invoke("Reset")
c:Invoke("SetStats",{Power=35,WallLevel=1,CritChance=0,FistMultiplier=1,PetMultiplier=0,TutorialStep=2})
local p=game.Players:GetPlayers()[1]
p.Character.HumanoidRootPart.CFrame=CFrame.new(-2,7,-13)
c:Invoke("HitWall","Brick Wall")
c:Invoke("HitWall","Brick Wall")
return true`,
    }, 30000);
    await sleep(800);
    await client.callTool("user_keyboard_input", {
      datamodel_type: "Client",
      actions: [
        { action: "keyDown", key_code: "F" },
        { action: "wait", wait_time_ms: 170 },
      ],
    }, 30000);
    {
      const id = "08_combat_damaged";
      const result = await client.callTool("screen_capture", { capture_id: id }, 60000);
      const file = path.join(args.outDir, `${id}.jpg`);
      saveImage(file, imageDataFromContent(result.content));
      summary.captures.push({ id, file, gameplayState: "damage_stage_3" });
    }
    await client.callTool("user_keyboard_input", {
      datamodel_type: "Client",
      actions: [{ action: "keyUp", key_code: "F" }],
    }, 30000);

    await client.callTool("user_keyboard_input", {
      datamodel_type: "Client",
      actions: [
        { action: "keyDown", key_code: "F" },
        { action: "wait", wait_time_ms: 100 },
      ],
    }, 30000);
    await sleep(45);
    {
      const id = "09_combat_break";
      const result = await client.callTool("screen_capture", { capture_id: id }, 60000);
      const file = path.join(args.outDir, `${id}.jpg`);
      saveImage(file, imageDataFromContent(result.content));
      summary.captures.push({ id, file, gameplayState: "wall_break" });
    }
    await client.callTool("user_keyboard_input", {
      datamodel_type: "Client",
      actions: [{ action: "keyUp", key_code: "F" }],
    }, 30000);

    for (const tab of args.combatOnly ? [] : ["Fists", "Pets", "Tasks", "Settings"]) {
      const opened = await client.callTool("execute_luau", {
        datamodel_type: "Client",
        code: `local g=game.Players.LocalPlayer.PlayerGui:WaitForChild("PunchWallHUD")
g.GameMenu.Visible=true
g:SetAttribute("AutomationTab","__capture_transition__")
task.wait()
g:SetAttribute("AutomationTab","${tab}")
task.wait(.45)
return g.GameMenu.Visible and "MENU_OPEN" or "MENU_CLOSED"`,
      }, 30000);
      if (!/MENU_OPEN/i.test(opened.text)) throw new Error(`Could not open ${tab} menu for QC`);
      const id = `07_menu_${tab.toLowerCase()}`;
      const result = await captureStable(client, {
        capture_id: id,
        camera_position: [-55, 8, 8],
        look_at_position: [-55, 8, -10],
      });
      const file = path.join(args.outDir, `${id}.jpg`);
      saveImage(file, imageDataFromContent(result.content));
      summary.captures.push({ id, file, uiTab: tab });
      await sleep(300);
    }

    await client.callTool("execute_luau", {
      datamodel_type: "Client",
      code: "game.Players.LocalPlayer.PlayerGui.PunchWallHUD.GameMenu.Visible=false return true",
    }, 30000);

    const consoleOutput = await client.callTool("get_console_output", {}, 30000);
    fs.writeFileSync(path.join(args.outDir, "console.txt"), consoleOutput.text);
    fs.writeFileSync(path.join(args.outDir, "capture-summary.json"), JSON.stringify(summary, null, 2));
    console.log(JSON.stringify({ ok: true, ...summary }, null, 2));
  } catch (error) {
    console.error(JSON.stringify({ ok: false, error: error.message, ...summary }, null, 2));
    process.exitCode = 1;
  } finally {
    if (playStarted) {
      try {
        await client.callTool("start_stop_play", { is_start: false }, 35000);
      } catch {}
    }
    client.close();
  }
}

main();
