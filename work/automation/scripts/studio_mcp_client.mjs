import { spawn } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

export function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export function assertCondition(value, message) {
  if (!value) throw new Error(message);
}

export function textOf(response) {
  return response?.result?.content?.map((item) => item.text ?? "").join("\n")
    ?? JSON.stringify(response);
}

export function findStudioMcp(explicitPath) {
  if (explicitPath) {
    const resolved = path.resolve(explicitPath);
    assertCondition(fs.existsSync(resolved), `StudioMCP.exe not found: ${resolved}`);
    return resolved;
  }

  const localAppData = process.env.LOCALAPPDATA || path.join(os.homedir(), "AppData", "Local");
  const versionsDir = path.join(localAppData, "Roblox", "Versions");
  assertCondition(fs.existsSync(versionsDir), `Roblox versions directory not found: ${versionsDir}`);
  const candidates = fs
    .readdirSync(versionsDir)
    .map((versionName) => path.join(versionsDir, versionName, "StudioMCP.exe"))
    .filter(fs.existsSync)
    .map((file) => ({ file, mtimeMs: fs.statSync(file).mtimeMs }))
    .sort((left, right) => right.mtimeMs - left.mtimeMs);
  assertCondition(candidates.length > 0, "Could not find StudioMCP.exe");
  return candidates[0].file;
}

export function compileStudioNameMatcher(studioName) {
  assertCondition(
    typeof studioName === "string" && studioName.trim().length > 0,
    "A non-empty studioName regex or exact studioInstanceId is required",
  );
  try {
    return new RegExp(studioName, "i");
  } catch (error) {
    throw new Error(`Invalid studioName regex ${JSON.stringify(studioName)}: ${error.message}`);
  }
}

export function resolveStudioCandidate(studios, selection = {}) {
  const validStudios = (studios ?? []).filter((studio) => studio?.id && studio?.name);
  const studioInstanceId = String(selection.studioInstanceId ?? "").trim();
  const studioName = String(selection.studioName ?? "").trim();

  if (studioInstanceId) {
    const matches = validStudios.filter((studio) => String(studio.id) === studioInstanceId);
    assertCondition(
      matches.length === 1,
      `Expected exactly one Studio with id ${studioInstanceId}, found ${matches.length}`,
    );
    if (studioName) {
      const matcher = compileStudioNameMatcher(studioName);
      assertCondition(
        matcher.test(matches[0].name),
        `Studio id ${studioInstanceId} is ${JSON.stringify(matches[0].name)}, which does not match ${JSON.stringify(studioName)}`,
      );
    }
    return matches[0];
  }

  const matcher = compileStudioNameMatcher(studioName);
  const matches = validStudios.filter((studio) => matcher.test(studio.name));
  assertCondition(
    matches.length === 1,
    `Expected exactly one Studio matching ${JSON.stringify(studioName)}, found ${matches.length}: ${matches.map((studio) => `${studio.name} (${studio.id})`).join(", ") || "none"}`,
  );
  return matches[0];
}

export function candidateNameSlices(parts, startIndex) {
  const candidates = [];
  for (let endIndex = startIndex; endIndex < parts.length; endIndex += 1) {
    candidates.push(parts.slice(startIndex, endIndex + 1).join("."));
  }
  return candidates;
}

export class McpClient {
  constructor(command, clientName = "punch-wall-automation") {
    this.clientName = clientName;
    this.nextId = 1;
    this.responses = new Map();
    this.buffer = "";
    this.studioId = null;
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
      await sleep(40);
    }
    throw new Error(`Timed out waiting for Studio MCP response ${id}`);
  }

  async initialize() {
    const response = await this.waitFor(this.send("initialize", {
      protocolVersion: "2024-11-05",
      capabilities: {},
      clientInfo: { name: this.clientName, version: "1.0.0" },
    }));
    this.notify("notifications/initialized");
    return response;
  }

  async callTool(name, args = {}, timeoutMs = 30000) {
    const studioScopedTools = new Set([
      "execute_luau",
      "get_console_output",
      "get_studio_state",
      "inspect_instance",
      "multi_edit",
      "screen_capture",
      "search_game_tree",
      "start_stop_play",
      "store_image",
      "user_keyboard_input",
      "user_mouse_input",
    ]);
    const toolArgs = this.studioId && studioScopedTools.has(name)
      ? { ...args, studio_id: this.studioId }
      : args;
    const response = await this.waitFor(
      this.send("tools/call", { name, arguments: toolArgs }),
      timeoutMs,
    );
    return {
      raw: response,
      text: textOf(response),
      content: response?.result?.content ?? [],
      isError: response?.error !== undefined || response?.result?.isError === true,
    };
  }

  close() {
    if (!this.child.killed) this.child.kill();
  }
}

function parseStudioList(text) {
  try {
    const parsed = JSON.parse(text);
    return Array.isArray(parsed?.studios) ? parsed.studios : [];
  } catch {
    return [];
  }
}

export async function listStudios(client, options = {}) {
  const pollAttempts = options.pollAttempts ?? 15;
  const pollMs = options.pollMs ?? 3000;
  let studios = [];
  for (let attempt = 1; attempt <= pollAttempts; attempt += 1) {
    const response = await client.callTool("list_roblox_studios", {});
    if (!response.isError) studios = parseStudioList(response.text);
    if (studios.length > 0) return studios;
    if (attempt < pollAttempts) await sleep(pollMs);
  }
  throw new Error("No Roblox Studio instances registered with MCP");
}

export async function selectStudioStrict(client, selection = {}) {
  const studios = await listStudios(client, selection);
  const selected = resolveStudioCandidate(studios, selection);
  client.studioId = selected.id;
  const setResult = await client.callTool("set_active_studio", { studio_id: selected.id });
  const explicitRoutingWithoutActivationTool =
    setResult.isError
    && /tool handler not found:\s*set_active_studio/i.test(setResult.text);
  assertCondition(
    !setResult.isError || explicitRoutingWithoutActivationTool,
    `Could not activate Studio ${selected.id}: ${setResult.text}`,
  );

  const verifiedStudios = await listStudios(client, { pollAttempts: 2, pollMs: 100 });
  const verified = verifiedStudios.find((studio) => String(studio.id) === String(selected.id));
  assertCondition(verified, `Selected Studio ${selected.id} disappeared before verification`);
  const explicitlyActive = verifiedStudios.filter((studio) => studio.active === true);
  if (explicitlyActive.length > 0) {
    assertCondition(
      explicitlyActive.length === 1 && String(explicitlyActive[0].id) === String(selected.id),
      `Studio activation verification failed; active ids: ${explicitlyActive.map((studio) => studio.id).join(", ")}`,
    );
  }
  return verified;
}

function isUnavailableDataModel(text) {
  return /datamodel.*not available|not available.*datamodel|available datamodel|no .*datamodel/i.test(text)
    // New Studio builds expose the DataModel before its execution bridge has
    // finished loading. Retry only this readiness error within the same bound;
    // script errors and unrelated unreachable services must still fail closed.
    || /^Target is not reachable \(createExecuteLuauBridge_loadCodeAsync, (?:Client|Server|Edit)\)/i.test(text);
}

export async function waitForDataModels(client, datamodelTypes, timeoutMs = 60000) {
  const pending = new Set(datamodelTypes.filter(Boolean));
  const startedAt = Date.now();
  const lastErrors = new Map();
  while (pending.size > 0 && Date.now() - startedAt < timeoutMs) {
    for (const datamodelType of [...pending]) {
      const probe = await client.callTool("execute_luau", {
        datamodel_type: datamodelType,
        code: "return game.Name",
      }, 15000);
      if (!probe.isError) {
        pending.delete(datamodelType);
        lastErrors.delete(datamodelType);
      } else {
        lastErrors.set(datamodelType, probe.text);
        if (!isUnavailableDataModel(probe.text)) {
          throw new Error(`DataModel ${datamodelType} readiness probe failed: ${probe.text}`);
        }
      }
    }
    if (pending.size > 0) await sleep(200);
  }
  assertCondition(
    pending.size === 0,
    `Timed out waiting for DataModel(s) ${[...pending].join(", ")}: ${[...pending].map((type) => `${type}=${lastErrors.get(type) ?? "unavailable"}`).join("; ")}`,
  );
}

function extractIdentity(text) {
  const nameMatch = text.match(/"name"\s*:\s*"((?:\\.|[^"])*)"/i);
  const placeIdMatch = text.match(/"placeId"\s*:\s*(?:"([^"]*)"|(-?\d+))/i);
  if (!nameMatch) return null;
  return {
    name: JSON.parse(`"${nameMatch[1]}"`),
    placeId: String(placeIdMatch?.[1] ?? placeIdMatch?.[2] ?? ""),
  };
}

export async function inspectSelectedPlace(client, options = {}) {
  const candidates = options.datamodelTypes ?? ["Edit", "Server", "Client"];
  const errors = [];
  for (const datamodelType of candidates) {
    const result = await client.callTool("execute_luau", {
      datamodel_type: datamodelType,
      code: "local H=game:GetService('HttpService') return H:JSONEncode({name=game.Name,placeId=tostring(game.PlaceId)})",
    }, 15000);
    if (!result.isError) {
      const identity = extractIdentity(result.text);
      if (identity) return { ...identity, datamodelType };
    }
    errors.push(`${datamodelType}: ${result.text}`);
  }
  throw new Error(`Could not inspect selected place identity: ${errors.join(" | ")}`);
}

export function assertPlaceIdentity(identity, expected = {}) {
  assertCondition(identity?.name, "Selected place identity is missing a name");
  if (expected.placeName) {
    let matcher;
    try {
      matcher = new RegExp(expected.placeName, "i");
    } catch (error) {
      throw new Error(`Invalid placeName regex ${JSON.stringify(expected.placeName)}: ${error.message}`);
    }
    assertCondition(
      matcher.test(identity.name),
      `Selected place ${JSON.stringify(identity.name)} does not match ${JSON.stringify(expected.placeName)}`,
    );
  }
  if (expected.placeId !== undefined && expected.placeId !== null && String(expected.placeId) !== "") {
    assertCondition(
      String(identity.placeId) === String(expected.placeId),
      `Selected place id ${identity.placeId} does not equal expected ${expected.placeId}`,
    );
  }
}

function longLuauString(value) {
  let equals = "";
  while (value.includes(`]${equals}]`)) equals += "=";
  return `[${equals}[${value}]${equals}]`;
}

function coordinatesFromText(text) {
  const xMatch = text.match(/"x"\s*:\s*(-?\d+(?:\.\d+)?)/i);
  const yMatch = text.match(/"y"\s*:\s*(-?\d+(?:\.\d+)?)/i);
  if (!xMatch || !yMatch) return null;
  return { x: Math.round(Number(xMatch[1])), y: Math.round(Number(yMatch[1])) };
}

export async function resolveGuiCoordinates(client, action) {
  const literalSegments = action.instance_path_segments ?? action.instancePathSegments;
  const instancePath = action.instance_path;
  assertCondition(
    Array.isArray(literalSegments) || typeof instancePath === "string",
    "Mouse action path resolution requires instance_path or instance_path_segments",
  );
  const specification = Array.isArray(literalSegments)
    ? { segments: literalSegments.map(String) }
    : { path: instancePath };
  const encoded = longLuauString(JSON.stringify(specification));
  const code = `
local H=game:GetService("HttpService")
local spec=H:JSONDecode(${encoded})
local function rootFor(name)
	if name=="game" then return game end
	if name=="Workspace" or name=="workspace" then return workspace end
	if name=="LocalPlayer" then return game:GetService("Players").LocalPlayer end
	return nil
end
local function exactWalk(segments)
	local node=rootFor(segments[1])
	if not node then return {} end
	local results={}
	local function walk(current,index)
		if index>#segments then table.insert(results,current) return end
		local child=current:FindFirstChild(segments[index])
		if child then walk(child,index+1) end
	end
	walk(node,2)
	return results
end
local function dottedWalk(rawPath)
	local parts=string.split(rawPath,".")
	local node=rootFor(parts[1])
	if not node then return {} end
	local results={}
	local function walk(current,index)
		if index>#parts then table.insert(results,current) return end
		local candidate=""
		for stop=index,#parts do
			candidate=candidate..(stop==index and "" or ".")..parts[stop]
			local child=current:FindFirstChild(candidate)
			if child then walk(child,stop+1) end
		end
	end
	walk(node,2)
	return results
end
local results=spec.segments and exactWalk(spec.segments) or dottedWalk(spec.path)
local guiResults={}
for _,node in ipairs(results) do if node:IsA("GuiObject") then table.insert(guiResults,node) end end
assert(#guiResults==1,("expected one GuiObject, found %d"):format(#guiResults))
local target=guiResults[1]
local position=target.AbsolutePosition
local size=target.AbsoluteSize
assert(size.X>0 and size.Y>0,"target GuiObject has no clickable area")
return H:JSONEncode({x=position.X+size.X*.5,y=position.Y+size.Y*.5,name=target.Name})
`;
  const result = await client.callTool("execute_luau", {
    datamodel_type: "Client",
    code,
  }, 30000);
  assertCondition(!result.isError, `Could not resolve mouse target path: ${result.text}`);
  const coordinates = coordinatesFromText(result.text);
  assertCondition(coordinates, `Mouse target resolver returned no coordinates: ${result.text}`);
  return coordinates;
}

export async function normalizeMouseInputArgs(client, args) {
  const normalized = structuredClone(args ?? {});
  if (normalized.native_instance_paths === true) {
    delete normalized.native_instance_paths;
    for (const action of normalized.actions ?? []) {
      assertCondition(
        !action.instance_path_segments && !action.instancePathSegments,
        "Native mouse paths require the official instance_path string field",
      );
    }
    return normalized;
  }
  normalized.actions = [];
  // Scope coordinate reuse to this one ordered input gesture. Repeated actions
  // against the same exact path (move/down/up) must share a fresh center, while
  // a later gesture re-resolves after any UI rerender.
  const coordinateCache = new Map();
  for (const action of args?.actions ?? []) {
    const copy = { ...action };
    if (copy.instance_path || copy.instance_path_segments || copy.instancePathSegments) {
      const literalSegments =
        copy.instance_path_segments ?? copy.instancePathSegments;
      const cacheKey = Array.isArray(literalSegments)
        ? `segments:${JSON.stringify(literalSegments.map(String))}`
        : `path:${String(copy.instance_path)}`;
      let coordinates = coordinateCache.get(cacheKey);
      if (!coordinates) {
        coordinates = await resolveGuiCoordinates(client, copy);
        coordinateCache.set(cacheKey, coordinates);
      }
      delete copy.instance_path;
      delete copy.instance_path_segments;
      delete copy.instancePathSegments;
      copy.x = coordinates.x;
      copy.y = coordinates.y;
    }
    normalized.actions.push(copy);
  }
  return normalized;
}
