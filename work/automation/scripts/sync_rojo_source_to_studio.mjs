#!/usr/bin/env node
import { spawn } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const PROJECT_ROOT = "F:\\Roblox\\PuchWall\\work\\punch-wall-rpg";
const DEFAULT_STUDIO_NAME = "PunchWallRPGPrototype";

const SCRIPT_MAPPINGS = [
  {
    source: path.join(PROJECT_ROOT, "src", "shared", "GameConfig.lua"),
    datamodelType: "Edit",
    className: "ModuleScript",
    service: "ReplicatedStorage",
    name: "GameConfig",
  },
  {
    source: path.join(PROJECT_ROOT, "src", "shared", "PolishConfig.lua"),
    datamodelType: "Edit",
    className: "ModuleScript",
    service: "ReplicatedStorage",
    name: "PolishConfig",
  },
  {
    source: path.join(PROJECT_ROOT, "src", "server", "PunchWallBootstrap.server.lua"),
    datamodelType: "Edit",
    className: "Script",
    service: "ServerScriptService",
    name: "PunchWallBootstrap",
  },
  {
    source: path.join(PROJECT_ROOT, "src", "client", "PunchWallClient.client.lua"),
    datamodelType: "Edit",
    className: "LocalScript",
    service: "StarterPlayer.StarterPlayerScripts",
    name: "PunchWallClient",
  },
];

function parseArgs(argv) {
  const args = {};
  for (let index = 0; index < argv.length; index += 1) {
    const key = argv[index];
    const value = argv[index + 1];
    if (key === "--studio-name") {
      args.studioName = value;
      index += 1;
    } else if (key === "--studio-mcp") {
      args.studioMcp = value;
      index += 1;
    } else if (key === "--help" || key === "-h") {
      console.log(`Usage:
  node sync_rojo_source_to_studio.mjs [--studio-name PunchWallRPGPrototype] [--studio-mcp path]

Pushes local Rojo source scripts into the active Roblox Studio edit DataModel through Studio MCP.`);
      process.exit(0);
    }
  }
  return args;
}

function findStudioMcp(explicitPath) {
  if (explicitPath) {
    if (!fs.existsSync(explicitPath)) throw new Error(`StudioMCP.exe not found: ${explicitPath}`);
    return explicitPath;
  }

  const localAppData = process.env.LOCALAPPDATA || path.join(os.homedir(), "AppData", "Local");
  const versionsDir = path.join(localAppData, "Roblox", "Versions");
  const candidates = fs
    .readdirSync(versionsDir)
    .map((versionName) => path.join(versionsDir, versionName, "StudioMCP.exe"))
    .filter(fs.existsSync)
    .map((file) => ({ file, mtimeMs: fs.statSync(file).mtimeMs }))
    .sort((left, right) => right.mtimeMs - left.mtimeMs);

  if (!candidates.length) throw new Error("Could not find StudioMCP.exe");
  return candidates[0].file;
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function textOf(response) {
  return response?.result?.content?.map((item) => item.text ?? "").join("\n") ?? JSON.stringify(response);
}

function luauString(value) {
  let equals = "";
  while (value.includes(`]${equals}]`)) {
    equals += "=";
  }
  return `[${equals}[${value}]${equals}]`;
}

class McpClient {
  constructor(command) {
    this.nextId = 1;
    this.responses = new Map();
    this.buffer = "";
    this.child = spawn(command, ["--stdio"], { stdio: ["pipe", "pipe", "pipe"] });
    this.child.stdout.on("data", (data) => this.onData(data.toString()));
    this.child.stderr.on("data", (data) => {
      const text = data.toString();
      if (!/No studio available/.test(text)) process.stderr.write(text);
    });
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
    const start = Date.now();
    while (Date.now() - start < timeoutMs) {
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
    const response = await this.waitFor(this.send("initialize", {
      protocolVersion: "2024-11-05",
      capabilities: {},
      clientInfo: { name: "codex-roblox-source-sync", version: "0.1.0" },
    }));
    this.notify("notifications/initialized");
    return response;
  }

  async callTool(name, args = {}, timeoutMs = 30000) {
    const response = await this.waitFor(this.send("tools/call", { name, arguments: args }), timeoutMs);
    return {
      raw: response,
      text: textOf(response),
      isError: response?.result?.isError === true,
    };
  }

  close() {
    this.child.kill();
  }
}

async function selectStudio(client, studioName) {
  let studios = [];
  for (let attempt = 1; attempt <= 15; attempt += 1) {
    const list = await client.callTool("list_roblox_studios", {});
    studios = JSON.parse(list.text).studios ?? [];
    if (studios.length) break;
    await sleep(3000);
  }
  if (!studios.length) throw new Error("No Roblox Studio instances registered with MCP");

  const matcher = new RegExp(studioName ?? DEFAULT_STUDIO_NAME, "i");
  const studio = studios.find((item) => matcher.test(item.name)) ?? studios[0];
  await client.callTool("set_active_studio", { studio_id: studio.id });
  return studio;
}

function syncCode(mapping, source) {
  const targetService = mapping.service
    .split(".")
    .map((part, index) => index === 0 ? `game:GetService(${luauString(part)})` : `:WaitForChild(${luauString(part)})`)
    .join("");

  return `
local parent = ${targetService}
local scriptInstance = parent:FindFirstChild(${luauString(mapping.name)})
if not scriptInstance then
\tscriptInstance = Instance.new(${luauString(mapping.className)})
\tscriptInstance.Name = ${luauString(mapping.name)}
\tscriptInstance.Parent = parent
end
if scriptInstance.ClassName ~= ${luauString(mapping.className)} then
\treturn "wrong class for ${mapping.name}: " .. scriptInstance.ClassName
end
scriptInstance.Source = ${luauString(source)}
return "synced ${mapping.name}"
`;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const studioMcp = findStudioMcp(args.studioMcp);
  const client = new McpClient(studioMcp);
  const synced = [];
  try {
    await client.initialize();
    const selectedStudio = await selectStudio(client, args.studioName ?? DEFAULT_STUDIO_NAME);
    const state = await client.callTool("get_studio_state", {});
    if (/Current Studio Mode:\s*Play/i.test(state.text)) {
      await client.callTool("start_stop_play", { is_start: false }, 45000);
      await sleep(3000);
    }
    for (const mapping of SCRIPT_MAPPINGS) {
      const source = fs.readFileSync(mapping.source, "utf8");
      const result = await client.callTool("execute_luau", {
        datamodel_type: mapping.datamodelType,
        code: syncCode(mapping, source),
      }, 45000);
      if (result.isError || !/synced/i.test(result.text)) {
        throw new Error(`Failed to sync ${mapping.name}: ${result.text}`);
      }
      synced.push({ name: mapping.name, source: mapping.source, result: result.text });
    }

    console.log(JSON.stringify({ ok: true, studioMcp, selectedStudio, synced }, null, 2));
  } finally {
    client.close();
  }
}

main().catch((error) => {
  console.error(error.stack ?? error.message);
  process.exit(1);
});
