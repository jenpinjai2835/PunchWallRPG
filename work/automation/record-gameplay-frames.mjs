#!/usr/bin/env node

import { spawn } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

function parseArgs(argv) {
  const args = {
    studioName: "PunchWallRPGPlayable_v1_final.rbxlx",
    outputDir: path.resolve("qc-gameplay-frames"),
    durationSeconds: 24,
    captureIntervalMs: 180,
  };
  for (let index = 0; index < argv.length; index += 1) {
    const key = argv[index];
    const value = argv[index + 1];
    if (key === "--studio-name") args.studioName = value;
    else if (key === "--output-dir") args.outputDir = path.resolve(value);
    else if (key === "--duration") args.durationSeconds = Number(value);
    else if (key === "--interval") args.captureIntervalMs = Number(value);
    else if (key === "--studio-mcp") args.studioMcp = value;
    else continue;
    index += 1;
  }
  if (!Number.isFinite(args.durationSeconds) || args.durationSeconds < 3) {
    throw new Error("--duration must be at least 3 seconds");
  }
  if (!Number.isFinite(args.captureIntervalMs) || args.captureIntervalMs < 50) {
    throw new Error("--interval must be at least 50 milliseconds");
  }
  return args;
}

function findStudioMcp(explicitPath) {
  if (explicitPath) return explicitPath;
  const localAppData = process.env.LOCALAPPDATA || path.join(os.homedir(), "AppData", "Local");
  const versionsDir = path.join(localAppData, "Roblox", "Versions");
  const candidates = [];
  for (const versionName of fs.readdirSync(versionsDir)) {
    const candidate = path.join(versionsDir, versionName, "StudioMCP.exe");
    if (fs.existsSync(candidate)) candidates.push(candidate);
  }
  candidates.sort((left, right) => fs.statSync(right).mtimeMs - fs.statSync(left).mtimeMs);
  if (!candidates.length) throw new Error("Could not find StudioMCP.exe");
  return candidates[0];
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function textOf(response) {
  return response?.result?.content?.map((item) => item.text ?? "").join("\n") ?? "";
}

class McpClient {
  constructor(command) {
    this.nextId = 1;
    this.responses = new Map();
    this.buffer = "";
    this.child = spawn(command, ["--stdio"], { stdio: ["pipe", "pipe", "pipe"] });
    this.child.stdout.on("data", (data) => this.onData(data.toString()));
    this.child.stderr.on("data", (data) => {
      const message = data.toString();
      if (!/No studio available/i.test(message)) process.stderr.write(message);
    });
  }

  onData(text) {
    this.buffer += text;
    let lineEnd;
    while ((lineEnd = this.buffer.indexOf("\n")) >= 0) {
      const line = this.buffer.slice(0, lineEnd).trim();
      this.buffer = this.buffer.slice(lineEnd + 1);
      if (!line) continue;
      try {
        const message = JSON.parse(line);
        if (message.id !== undefined) this.responses.set(message.id, message);
      } catch (error) {
        process.stderr.write(`Ignored malformed Studio MCP line: ${error.message}\n`);
      }
    }
  }

  send(method, params = {}) {
    const id = this.nextId++;
    this.child.stdin.write(`${JSON.stringify({ jsonrpc: "2.0", id, method, params })}\n`);
    return id;
  }

  notify(method, params = {}) {
    this.child.stdin.write(`${JSON.stringify({ jsonrpc: "2.0", method, params })}\n`);
  }

  async waitFor(id, timeoutMs = 30000) {
    const startedAt = Date.now();
    while (Date.now() - startedAt < timeoutMs) {
      if (this.responses.has(id)) {
        const response = this.responses.get(id);
        this.responses.delete(id);
        return response;
      }
      await sleep(25);
    }
    throw new Error(`Timed out waiting for Studio MCP response ${id}`);
  }

  async initialize() {
    await this.waitFor(this.send("initialize", {
      protocolVersion: "2024-11-05",
      capabilities: {},
      clientInfo: { name: "smash-wall-gameplay-recorder", version: "1.0.0" },
    }));
    this.notify("notifications/initialized");
  }

  async callTool(name, args = {}, timeoutMs = 30000) {
    const response = await this.waitFor(this.send("tools/call", { name, arguments: args }), timeoutMs);
    if (response?.result?.isError) throw new Error(`${name} failed: ${textOf(response)}`);
    return response;
  }

  close() {
    this.child.kill();
  }
}

async function selectStudio(client, studioName) {
  let studios = [];
  for (let attempt = 0; attempt < 15; attempt += 1) {
    const result = await client.callTool("list_roblox_studios");
    try {
      studios = JSON.parse(textOf(result)).studios ?? [];
    } catch {
      studios = [];
    }
    if (studios.length) break;
    await sleep(2500);
  }
  if (!studios.length) throw new Error("No Roblox Studio instances registered with MCP");
  const expected = studioName.toLowerCase();
  const studio = studios.find((item) => item.name?.toLowerCase().includes(expected)) ?? studios[0];
  await client.callTool("set_active_studio", { studio_id: studio.id });
  return studio;
}

function extractImage(response) {
  const content = response?.result?.content ?? [];
  const image = content.find((item) => item.type === "image" && typeof item.data === "string");
  if (!image) return null;
  const buffer = Buffer.from(image.data, "base64");
  const isJpeg = buffer[0] === 0xff && buffer[1] === 0xd8;
  const isPng = buffer.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]));
  return {
    buffer,
    extension: isJpeg ? "jpg" : isPng ? "png" : (image.mimeType === "image/jpeg" ? "jpg" : "png"),
    mimeType: image.mimeType ?? (isJpeg ? "image/jpeg" : "image/png"),
  };
}

function prepareOutputDirectory(outputDir) {
  fs.mkdirSync(outputDir, { recursive: true });
  for (const name of fs.readdirSync(outputDir)) {
    if (/^frame-\d{4}\.(png|jpg)$/i.test(name) || name === "recording-metadata.json") {
      fs.rmSync(path.join(outputDir, name));
    }
  }
}

async function prepareGameplay(client, durationSeconds) {
  await client.callTool("execute_luau", {
    datamodel_type: "Server",
    code: `local c=game.ServerStorage:WaitForChild('PunchWallAutomation',10)
c:Invoke('Reset')
c:Invoke('SetStats',{Coins=1000000000,Power=6000,WallLevel=99,CritChance=0,FistMultiplier=1,PetMultiplier=0})
c:Invoke('BuyFist','Titan Gauntlet')
local p=game.Players:GetPlayers()[1]
local character=p.Character or p.CharacterAdded:Wait()
local root=character:WaitForChild('HumanoidRootPart')
root.AssemblyLinearVelocity=Vector3.zero
root.CFrame=CFrame.lookAt(Vector3.new(-2,3,-20),Vector3.new(-2,3,-200))
p:SetAttribute('LastWallHit',0)
return true`,
  }, 45000);

  const punchCount = Math.max(3, Math.floor(durationSeconds / 1.02));
  await client.callTool("execute_luau", {
    datamodel_type: "Client",
    code: `local player=game.Players.LocalPlayer
local gui=player.PlayerGui:WaitForChild('PunchWallHUD',10)
local bridge=gui:WaitForChild('PunchWallClientAutomation',10)
pcall(function() bridge:Invoke('__HideLoading') end)
local menu=gui:FindFirstChild('GameMenu')
if menu then menu.Visible=false end
local shop=gui:FindFirstChild('FunctionalHeroShop')
if shop then shop.Visible=false end
local root=player.Character and player.Character:FindFirstChild('HumanoidRootPart')
local humanoid=player.Character and player.Character:FindFirstChildOfClass('Humanoid')
local camera=workspace.CurrentCamera
if camera and humanoid then
  camera.CameraType=Enum.CameraType.Custom
  camera.CameraSubject=humanoid
  camera.FieldOfView=70
end
task.spawn(function()
  task.wait(.35)
  for _=1,${punchCount} do
    bridge:Invoke('Punch')
    task.wait(1.02)
  end
end)
return ${punchCount}`,
  }, 45000);
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  prepareOutputDirectory(args.outputDir);
  const studioMcp = findStudioMcp(args.studioMcp);
  const client = new McpClient(studioMcp);
  const frames = [];
  const errors = [];
  let selectedStudio;
  let recordingStartedAt;
  try {
    await client.initialize();
    selectedStudio = await selectStudio(client, args.studioName);
    await client.callTool("start_stop_play", { is_start: false }, 35000).catch(() => {});
    await sleep(1500);
    await client.callTool("start_stop_play", { is_start: true }, 35000);
    await sleep(7000);
    await prepareGameplay(client, args.durationSeconds);
    await sleep(500);

    recordingStartedAt = Date.now();
    const recordingEndsAt = recordingStartedAt + args.durationSeconds * 1000;
    let frameNumber = 1;
    while (Date.now() < recordingEndsAt) {
      const requestedAt = Date.now();
      try {
        const response = await client.callTool("screen_capture", {
          capture_id: `SmashWallDirectClient_${String(frameNumber).padStart(4, "0")}`,
        }, 30000);
        const image = extractImage(response);
        if (!image?.buffer?.length) throw new Error("screen_capture returned no image block");
        const filename = `frame-${String(frameNumber).padStart(4, "0")}.${image.extension}`;
        fs.writeFileSync(path.join(args.outputDir, filename), image.buffer);
        frames.push({
          filename,
          requestedAtMs: requestedAt - recordingStartedAt,
          capturedAtMs: Date.now() - recordingStartedAt,
          bytes: image.buffer.length,
          mimeType: image.mimeType,
        });
        frameNumber += 1;
      } catch (error) {
        errors.push({ atMs: Date.now() - recordingStartedAt, message: error.message });
      }
      const waitMs = args.captureIntervalMs - (Date.now() - requestedAt);
      if (waitMs > 0) await sleep(waitMs);
    }

    const consoleResponse = await client.callTool("get_console_output", {}, 30000);
    const consoleText = textOf(consoleResponse);
    const durationMs = Math.max(1, Date.now() - recordingStartedAt);
    const metadata = {
      ok: frames.length >= 3,
      selectedStudio,
      studioMcp,
      requestedDurationSeconds: args.durationSeconds,
      actualDurationSeconds: durationMs / 1000,
      frameCount: frames.length,
      averageFps: frames.length / (durationMs / 1000),
      captureIntervalMs: args.captureIntervalMs,
      frames,
      errors,
      consoleWarnings: consoleText.split(/\r?\n/).filter((line) => /warn|error|stack|infinite yield/i.test(line)).slice(-30),
    };
    fs.writeFileSync(path.join(args.outputDir, "recording-metadata.json"), `${JSON.stringify(metadata, null, 2)}\n`);
    console.log(JSON.stringify(metadata, null, 2));
    if (!metadata.ok) process.exitCode = 1;
  } finally {
    try {
      await client.callTool("start_stop_play", { is_start: false }, 35000);
    } catch (error) {
      process.stderr.write(`Could not stop Studio playtest: ${error.message}\n`);
    }
    client.close();
  }
}

main().catch((error) => {
  console.error(error.stack ?? error.message);
  process.exit(1);
});
