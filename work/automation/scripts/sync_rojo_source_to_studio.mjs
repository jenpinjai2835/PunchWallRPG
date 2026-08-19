#!/usr/bin/env node
import { spawn } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import {
  assertPlaceIdentity,
  inspectSelectedPlace,
  selectStudioStrict,
  waitForDataModels,
} from "./studio_mcp_client.mjs";

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));
const REPOSITORY_ROOT = path.resolve(SCRIPT_DIR, "..", "..", "..");
const PROJECT_ROOT = path.join(REPOSITORY_ROOT, "work", "punch-wall-rpg");
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
    source: path.join(PROJECT_ROOT, "src", "shared", "ForestVisualBuilder.lua"),
    datamodelType: "Edit",
    className: "ModuleScript",
    service: "ReplicatedStorage",
    name: "ForestVisualBuilder",
  },
  {
    source: path.join(PROJECT_ROOT, "src", "shared", "FistVisualBuilder.lua"),
    datamodelType: "Edit",
    className: "ModuleScript",
    service: "ReplicatedStorage",
    name: "FistVisualBuilder",
  },
  {
    source: path.join(PROJECT_ROOT, "src", "shared", "InventoryViewModel.lua"),
    datamodelType: "Edit",
    className: "ModuleScript",
    service: "ReplicatedStorage",
    name: "InventoryViewModel",
  },
  {
    source: path.join(PROJECT_ROOT, "src", "server", "ProfilePersistence.lua"),
    datamodelType: "Edit",
    className: "ModuleScript",
    service: "ServerScriptService",
    name: "ProfilePersistence",
  },
  {
    source: path.join(PROJECT_ROOT, "src", "server", "PunchWallBootstrap.server.lua"),
    datamodelType: "Edit",
    className: "Script",
    service: "ServerScriptService",
    name: "PunchWallBootstrap",
  },
  {
    source: path.join(PROJECT_ROOT, "src", "client", "InventoryUI.lua"),
    datamodelType: "Edit",
    className: "ModuleScript",
    service: "StarterPlayer.StarterPlayerScripts",
    name: "InventoryUI",
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
    } else if (key === "--studio-instance-id") {
      args.studioInstanceId = value;
      index += 1;
    } else if (key === "--place-name") {
      args.placeName = value;
      index += 1;
    } else if (key === "--place-id") {
      args.placeId = value;
      index += 1;
    } else if (key === "--help" || key === "-h") {
      console.log(`Usage:
  node sync_rojo_source_to_studio.mjs [--studio-name PunchWallRPGPrototype]
    [--studio-instance-id exact-id] [--place-name regex] [--studio-mcp path]

Pushes local Rojo source scripts into the active Roblox Studio edit DataModel through Studio MCP.`);
      process.exit(0);
    } else {
      throw new Error(`Unknown argument: ${key}`);
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
      isError: response?.error !== undefined || response?.result?.isError === true,
    };
  }

  close() {
    this.child.kill();
  }
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

function targetPath(mapping) {
  return `game.${mapping.service}.${mapping.name}`;
}

function splitUtf8Chunks(value, maximumBytes) {
  const chunks = [];
  let current = "";
  let currentBytes = 0;
  for (const character of value) {
    const characterBytes = Buffer.byteLength(character, "utf8");
    if (current && currentBytes + characterBytes > maximumBytes) {
      chunks.push(current);
      current = "";
      currentBytes = 0;
    }
    current += character;
    currentBytes += characterBytes;
  }
  if (current || chunks.length === 0) chunks.push(current);
  return chunks;
}

function sourceFingerprint(value) {
  let a = 1;
  let b = 0;
  for (const byte of Buffer.from(value, "utf8")) {
    a = (a + byte) % 65521;
    b = (b + a) % 65521;
  }
  return {
    length: Buffer.byteLength(value, "utf8"),
    adler32: b * 65536 + a,
  };
}

async function verifySyncedSource(client, mapping, source) {
  const expected = sourceFingerprint(source);
  const verify = await client.callTool("execute_luau", {
    datamodel_type: mapping.datamodelType,
    code: `
local H=game:GetService("HttpService")
local value=${targetPath(mapping)}.Source
local a,b=1,0
for index=1,#value do
\ta=(a+string.byte(value,index))%65521
\tb=(b+a)%65521
end
return H:JSONEncode({
\tlength=#value,
\tadler32=b*65536+a,
\thasSentinel=string.find(value,"CODEX_CHUNK_SYNC",1,true)~=nil,
})
`,
  }, 45000);
  const lengthMatch = verify.text.match(/"length"\s*:\s*(\d+)/i);
  const adlerMatch = verify.text.match(/"adler32"\s*:\s*(\d+)/i);
  const sentinelMatch = verify.text.match(/"hasSentinel"\s*:\s*(true|false)/i);
  if (
    verify.isError
    || Number(lengthMatch?.[1]) !== expected.length
    || Number(adlerMatch?.[1]) !== expected.adler32
    || sentinelMatch?.[1]?.toLowerCase() !== "false"
  ) {
    throw new Error(
      `Exact sync verification failed for ${mapping.name}: expected ${JSON.stringify(expected)}, received ${verify.text}`,
    );
  }
  return expected;
}

async function syncMapping(client, mapping, source) {
  const directLimit = 165000;
  const chunkSize = 110000;
  if (Buffer.byteLength(source, "utf8") <= directLimit) {
    const result = await client.callTool("execute_luau", {
      datamodel_type: mapping.datamodelType,
      code: syncCode(mapping, source),
    }, 45000);
    if (result.isError || !/synced/i.test(result.text)) {
      throw new Error(`Failed to sync ${mapping.name}: ${result.text}`);
    }
    const fingerprint = await verifySyncedSource(client, mapping, source);
    return { ...result, fingerprint };
  }

  const sentinel = `\n--[[CODEX_CHUNK_SYNC_${mapping.name}_SENTINEL]]`;
  const chunks = splitUtf8Chunks(source, chunkSize);
  const initial = await client.callTool("execute_luau", {
    datamodel_type: mapping.datamodelType,
    code: syncCode(mapping, chunks[0] + sentinel),
  }, 45000);
  if (initial.isError || !/synced/i.test(initial.text)) {
    throw new Error(`Failed to initialize chunked sync for ${mapping.name}: ${initial.text}`);
  }
  for (let index = 1; index < chunks.length; index += 1) {
    const append = await client.callTool("multi_edit", {
      datamodel_type: mapping.datamodelType,
      file_path: targetPath(mapping),
      edits: [{ old_string: sentinel, new_string: chunks[index] + sentinel }],
    }, 45000);
    if (append.isError) {
      throw new Error(`Failed chunk ${index + 1}/${chunks.length} for ${mapping.name}: ${append.text}`);
    }
  }
  const finalize = await client.callTool("multi_edit", {
    datamodel_type: mapping.datamodelType,
    file_path: targetPath(mapping),
    edits: [{ old_string: sentinel, new_string: "" }],
  }, 45000);
  if (finalize.isError) {
    throw new Error(`Failed to finalize chunked sync for ${mapping.name}: ${finalize.text}`);
  }
  const fingerprint = await verifySyncedSource(client, mapping, source);
  return {
    text: `synced ${mapping.name} in ${chunks.length} chunks`,
    isError: false,
    fingerprint,
  };
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const studioMcp = findStudioMcp(args.studioMcp);
  const client = new McpClient(studioMcp);
  const synced = [];
  try {
    await client.initialize();
    const selectedStudio = await selectStudioStrict(client, {
      studioInstanceId: args.studioInstanceId,
      studioName: args.studioName ?? DEFAULT_STUDIO_NAME,
      pollAttempts: 15,
      pollMs: 3000,
    });
    const selectedPlace = await inspectSelectedPlace(client);
    assertPlaceIdentity(selectedPlace, {
      placeName: args.placeName,
      placeId: args.placeId,
    });
    const state = await client.callTool("get_studio_state", {});
    if (/Current Studio Mode:\s*Play/i.test(state.text)) {
      await client.callTool("start_stop_play", { is_start: false }, 45000);
      await waitForDataModels(client, ["Edit"], 60000);
    }
    const mappings = SCRIPT_MAPPINGS.filter((mapping) => {
      if (fs.existsSync(mapping.source)) return true;
      if (mapping.optional) return false;
      throw new Error(`Required Rojo source missing: ${mapping.source}`);
    });
    await waitForDataModels(client, ["Edit"], 60000);
    for (const mapping of mappings) {
      // Roblox normalizes Script.Source line endings to LF. Normalize before
      // chunking so the post-sync length check measures the exact stored text.
      const source = fs.readFileSync(mapping.source, "utf8").replace(/\r\n?/g, "\n");
      const result = await syncMapping(client, mapping, source);
      synced.push({
        name: mapping.name,
        source: mapping.source,
        result: result.text,
        fingerprint: result.fingerprint,
      });
    }

    console.log(JSON.stringify({
      ok: true,
      repositoryRoot: REPOSITORY_ROOT,
      projectRoot: PROJECT_ROOT,
      studioMcp,
      selectedStudio,
      selectedPlace,
      synced,
    }, null, 2));
  } finally {
    client.close();
  }
}

main().catch((error) => {
  console.error(error.stack ?? error.message);
  process.exit(1);
});
