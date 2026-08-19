#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import {
  McpClient,
  assertCondition,
  assertPlaceIdentity,
  candidateNameSlices,
  findStudioMcp,
  inspectSelectedPlace,
  normalizeMouseInputArgs,
  resolveStudioCandidate,
  selectStudioStrict,
  sleep,
  waitForDataModels,
} from "./studio_mcp_client.mjs";

function parseArgs(argv) {
  const args = {};
  for (let index = 0; index < argv.length; index += 1) {
    const key = argv[index];
    const value = argv[index + 1];
    if (key === "--flow") {
      args.flow = value;
      index += 1;
    } else if (key === "--flows-dir") {
      args.flowsDir = value;
      index += 1;
    } else if (key === "--all") {
      args.all = true;
    } else if (key === "--studio-mcp") {
      args.studioMcp = value;
      index += 1;
    } else if (key === "--studio-instance-id") {
      args.studioInstanceId = value;
      index += 1;
    } else if (key === "--studio-name") {
      args.studioName = value;
      index += 1;
    } else if (key === "--place-name") {
      args.placeName = value;
      index += 1;
    } else if (key === "--place-id") {
      args.placeId = value;
      index += 1;
    } else if (key === "--result-file") {
      args.resultFile = value;
      index += 1;
    } else if (key === "--self-test") {
      args.selfTest = true;
    } else if (key === "--help" || key === "-h") {
      console.log(`Usage:
  node flow_runner.mjs --flow <flow.json> [--studio-instance-id <exact-id>]
  node flow_runner.mjs --flows-dir <dir> --all [--studio-instance-id <exact-id>]
  node flow_runner.mjs --self-test

Selection is fail-closed: an exact id must resolve once, otherwise studioName
must match exactly one connected Studio. No first-Studio fallback is allowed.`);
      process.exit(0);
    } else {
      throw new Error(`Unknown argument: ${key}`);
    }
  }
  if (!args.selfTest && !args.flow && !(args.flowsDir && args.all)) {
    throw new Error("Provide --flow <file>, --flows-dir <dir> --all, or --self-test");
  }
  return args;
}

function parseTree(value, sourceName) {
  const parsed = JSON.parse(value);
  assertCondition(Array.isArray(parsed), `${sourceName} is not a JSON array`);
  return parsed;
}

function namesUnder(tree, parentName) {
  return new Set(tree.filter((item) => item.parentName === parentName).map((item) => item.name));
}

function countUnder(tree, parentName) {
  return tree.filter((item) => item.parentName === parentName).length;
}

function checkText(action, text) {
  for (const expected of action.expectText ?? []) {
    assertCondition(text.includes(expected), `Expected text not found: ${expected}`);
  }
  for (const expected of action.expectRegex ?? []) {
    assertCondition(new RegExp(expected, "i").test(text), `Expected regex not found: ${expected}`);
  }
}

function runAssertion(action, context) {
  if (action.type === "assertTreeNames") {
    const tree = parseTree(context[action.source], action.source);
    const actual = namesUnder(tree, action.parentName);
    for (const name of action.names ?? []) {
      assertCondition(actual.has(name), `Missing ${name} under ${action.parentName}`);
    }
    return;
  }
  if (action.type === "assertTreeMinChildren") {
    const tree = parseTree(context[action.source], action.source);
    const actual = countUnder(tree, action.parentName);
    assertCondition(actual >= action.min, `Expected at least ${action.min} children under ${action.parentName}, got ${actual}`);
    return;
  }
  if (action.type === "assertNoConsoleErrors") {
    const text = context[action.source] ?? "";
    const patterns = action.patterns ?? [
      "Stack Begin",
      "Stack End",
      "Script Runtime Error",
      "Infinite yield",
      "attempt to",
      "Traceback",
      "Error:",
    ];
    const hits = text
      .split(/\r?\n/)
      .filter((line) => patterns.some((pattern) => new RegExp(pattern, "i").test(line)));
    assertCondition(hits.length === 0, `Console contains suspicious lines:\n${hits.slice(-20).join("\n")}`);
    return;
  }
  throw new Error(`Unknown assertion action: ${action.type}`);
}

function summarizeContext(context) {
  return Object.fromEntries(Object.entries(context).map(([key, value]) => {
    if (typeof value !== "string" || value.length <= 4000) return [key, value];
    return [
      key,
      `${value.slice(0, 2000)}\n... <truncated ${value.length - 4000} chars> ...\n${value.slice(-2000)}`,
    ];
  }));
}

async function runAction(client, action, context, checks, readinessTimeoutMs) {
  if (action.type === "wait") {
    await sleep(action.ms ?? 1000);
    checks.push(action.label ?? `wait ${action.ms ?? 1000}ms`);
    return;
  }
  if (action.type?.startsWith("assert")) {
    runAssertion(action, context);
    checks.push(action.label ?? action.type);
    return;
  }
  if (action.type !== "call") throw new Error(`Unknown flow action type: ${action.type}`);

  const requestedTimeout = action.timeoutMs ?? 30000;
  const timeoutMs = action.tool === "start_stop_play"
    ? Math.max(requestedTimeout, 60000)
    : requestedTimeout;
  let toolArgs = action.args ?? {};
  if (toolArgs.datamodel_type) {
    await waitForDataModels(client, [toolArgs.datamodel_type], readinessTimeoutMs);
  }
  if (action.tool === "user_mouse_input") {
    toolArgs = await normalizeMouseInputArgs(client, toolArgs);
  }
  const result = await client.callTool(action.tool, toolArgs, timeoutMs);
  assertCondition(!result.isError || action.allowError === true, `${action.tool} failed: ${result.text}`);

  if (!result.isError && action.tool === "start_stop_play") {
    if (toolArgs.is_start === true) {
      await waitForDataModels(client, ["Server", "Client"], readinessTimeoutMs);
    } else {
      await waitForDataModels(client, ["Edit"], readinessTimeoutMs);
    }
  }
  if (action.saveAs) context[action.saveAs] = result.text;
  checkText(action, result.text);
  checks.push(action.label ?? action.tool);
}

async function runFlow(file, studioMcp, commandLine) {
  const flow = JSON.parse(fs.readFileSync(file, "utf8"));
  const client = new McpClient(studioMcp, "punch-wall-flow-runner");
  const context = {};
  const checks = [];
  let selectedStudio = null;
  let selectedPlace = null;
  const selection = {
    studioInstanceId: commandLine.studioInstanceId ?? flow.studioInstanceId,
    studioName: commandLine.studioName ?? flow.studioName,
    pollAttempts: flow.pollAttempts,
    pollMs: flow.pollMs,
  };
  const expectedPlace = {
    placeName: commandLine.placeName ?? flow.placeName,
    placeId: commandLine.placeId ?? flow.placeId,
  };
  const readinessTimeoutMs = flow.readinessTimeoutMs ?? 60000;
  try {
    await client.initialize();
    selectedStudio = await selectStudioStrict(client, selection);
    selectedPlace = await inspectSelectedPlace(client);
    assertPlaceIdentity(selectedPlace, expectedPlace);
    for (const action of flow.steps ?? []) {
      await runAction(client, action, context, checks, readinessTimeoutMs);
    }
    return {
      ok: true,
      flow: flow.name ?? path.basename(file),
      selectedStudio,
      selectedPlace,
      checks,
    };
  } catch (error) {
    for (const action of flow.cleanup ?? []) {
      try {
        await runAction(client, action, context, checks, readinessTimeoutMs);
      } catch {
        // Preserve the original failure.
      }
    }
    return {
      ok: false,
      flow: flow.name ?? path.basename(file),
      selectedStudio,
      selectedPlace,
      checks,
      error: error.message,
      context: summarizeContext(context),
    };
  } finally {
    client.close();
  }
}

async function runSelfTest() {
  const studios = [
    { id: "studio-a", name: "PunchWallRPGPrototype", active: false },
    { id: "studio-b", name: "PunchWallRPGPlayable_v1_final.rbxlx", active: true },
  ];
  assertCondition(
    resolveStudioCandidate(studios, { studioInstanceId: "studio-b" }).id === "studio-b",
    "exact Studio id selection failed",
  );
  assertCondition(
    resolveStudioCandidate(studios, { studioName: "Prototype$" }).id === "studio-a",
    "single Studio name selection failed",
  );
  for (const selection of [
    { studioInstanceId: "missing" },
    { studioName: "PunchWallRPG" },
    { studioName: "DoesNotExist" },
    {},
  ]) {
    let failedClosed = false;
    try {
      resolveStudioCandidate(studios, selection);
    } catch {
      failedClosed = true;
    }
    assertCondition(failedClosed, `selection did not fail closed: ${JSON.stringify(selection)}`);
  }
  const dotted = candidateNameSlices(
    ["LocalPlayer", "PlayerGui", "PunchWallHUD", "GameMenu", "Scale0", "8"],
    4,
  );
  assertCondition(dotted.includes("Scale0.8"), "dotted 0.8 instance-name candidate is missing");
  const dottedLarge = candidateNameSlices(["Scale1", "2"], 0);
  assertCondition(dottedLarge.includes("Scale1.2"), "dotted 1.2 instance-name candidate is missing");

  function coordinateClient() {
    const calls = [];
    return {
      calls,
      async callTool(tool, args) {
        calls.push({ tool, args });
        const sequence = calls.length;
        return {
          isError: false,
          text: JSON.stringify({ x: sequence * 100 + 1, y: sequence * 100 + 2 }),
        };
      },
    };
  }
  const pathA = ["LocalPlayer", "PlayerGui", "HUD", "Row.With.Dot", "Action"];
  const pathB = ["LocalPlayer", "PlayerGui", "HUD", "OtherAction"];
  const repeatedSource = {
    datamodel_type: "Client",
    actions: [
      { action: "moveTo", instance_path_segments: pathA },
      { action: "mouseButtonDown", mouse_button: "left", instance_path_segments: pathA },
      { action: "mouseButtonUp", mouse_button: "left", instance_path_segments: pathA },
    ],
  };
  const repeatedSnapshot = structuredClone(repeatedSource);
  const repeatedClient = coordinateClient();
  const repeated = await normalizeMouseInputArgs(repeatedClient, repeatedSource);
  assertCondition(
    repeatedClient.calls.length === 1
      && repeated.actions.every((action) => action.x === 101 && action.y === 102),
    "identical move/down/up paths must resolve once and reuse explicit coordinates",
  );
  assertCondition(
    JSON.stringify(repeatedSource) === JSON.stringify(repeatedSnapshot),
    "mouse normalization mutated its source arguments",
  );

  const distinctClient = coordinateClient();
  const distinct = await normalizeMouseInputArgs(distinctClient, {
    actions: [
      { action: "moveTo", instance_path_segments: pathA },
      { action: "mouseButtonDown", mouse_button: "left", instance_path_segments: pathB },
      { action: "mouseButtonUp", mouse_button: "left", instance_path_segments: pathA },
    ],
  });
  assertCondition(
    distinctClient.calls.length === 2
      && distinct.actions[0].x === 101
      && distinct.actions[1].x === 201
      && distinct.actions[2].x === 101,
    "distinct paths must resolve separately while repeated exact paths reuse their coordinate",
  );

  const perCallClient = coordinateClient();
  await normalizeMouseInputArgs(perCallClient, {
    actions: [{ action: "moveTo", instance_path_segments: pathA }],
  });
  await normalizeMouseInputArgs(perCallClient, {
    actions: [{ action: "moveTo", instance_path_segments: pathA }],
  });
  assertCondition(
    perCallClient.calls.length === 2,
    "coordinate cache leaked across separate mouse input calls",
  );

  const pathlessClient = coordinateClient();
  const pathless = await normalizeMouseInputArgs(pathlessClient, {
    actions: [
      { action: "moveTo", instance_path_segments: pathA },
      { action: "mouseButtonDown", mouse_button: "left" },
      { action: "mouseButtonUp", mouse_button: "left" },
    ],
  });
  assertCondition(
    pathlessClient.calls.length === 1
      && pathless.actions[1].x === undefined
      && pathless.actions[1].y === undefined
      && pathless.actions[2].x === undefined
      && pathless.actions[2].y === undefined,
    "pathless actions no longer preserve pointer-position reuse",
  );

  const nativeClient = coordinateClient();
  const native = await normalizeMouseInputArgs(nativeClient, {
    native_instance_paths: true,
    actions: [{ action: "mouseButtonClick", mouse_button: "left", instance_path: "LocalPlayer.PlayerGui.NativeButton" }],
  });
  assertCondition(
    nativeClient.calls.length === 0
      && native.native_instance_paths === undefined
      && native.actions[0].instance_path === "LocalPlayer.PlayerGui.NativeButton",
    "native instance-path input no longer reaches Studio without coordinate conversion",
  );
  return {
    ok: true,
    checks: [
      "exact Studio id",
      "unique Studio regex",
      "zero matches fail closed",
      "multiple matches fail closed",
      "missing selector fails closed",
      "Scale0.8 dotted path",
      "Scale1.2 dotted path",
      "identical triple path resolves once without source mutation",
      "different paths resolve separately",
      "coordinate cache is per call",
      "pathless pointer reuse",
      "native instance-path passthrough",
    ],
  };
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.selfTest) {
    console.log(JSON.stringify(await runSelfTest(), null, 2));
    return;
  }

  const studioMcp = findStudioMcp(args.studioMcp);
  const files = args.all
    ? fs.readdirSync(args.flowsDir)
      .filter((name) => name.endsWith(".json"))
      .sort()
      .map((name) => path.join(args.flowsDir, name))
    : [args.flow];
  for (const file of files) {
    assertCondition(fs.existsSync(file), `Flow file not found: ${file}`);
  }

  const results = [];
  for (const file of files) {
    results.push(await runFlow(file, studioMcp, args));
    if (files.length > 1) await sleep(2500);
  }
  const output = {
    ok: results.every((result) => result.ok),
    studioMcp,
    results,
  };
  const serialized = `${JSON.stringify(output, null, 2)}\n`;
  if (args.resultFile) fs.writeFileSync(path.resolve(args.resultFile), serialized, "utf8");
  process.stdout.write(serialized);
  if (!output.ok) process.exitCode = 1;
}

const isMain = process.argv[1]
  && path.resolve(process.argv[1]) === path.resolve(fileURLToPath(import.meta.url));
if (isMain) {
  main().catch((error) => {
    console.error(error.stack ?? error.message);
    process.exit(1);
  });
}
