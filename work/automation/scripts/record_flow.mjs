#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";

function slugify(value) {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 80);
}

function parseArgs(argv) {
  const args = {};
  for (let index = 0; index < argv.length; index += 1) {
    const key = argv[index];
    const value = argv[index + 1];
    if (key === "--name") args.name = value;
    else if (key === "--flows-dir") args.flowsDir = value;
    else if (key === "--studio-name") args.studioName = value;
    else if (key === "--studio-instance-id") args.studioInstanceId = value;
    else if (key === "--place-name") args.placeName = value;
    else if (key === "--root") args.root = value;
    else if (key === "--description") args.description = value;
    else if (key === "--help" || key === "-h") {
      console.log("Usage: node record_flow.mjs --name <name> --flows-dir <dir> --studio-name <unique-regex>");
      process.exit(0);
    } else {
      throw new Error(`Unknown argument: ${key}`);
    }
    index += 1;
  }
  if (!args.name || !args.flowsDir) throw new Error("Provide --name and --flows-dir");
  if (!args.studioName && !args.studioInstanceId) {
    throw new Error("Provide --studio-name or --studio-instance-id; drafts must fail closed");
  }
  return args;
}

const args = parseArgs(process.argv.slice(2));
fs.mkdirSync(args.flowsDir, { recursive: true });
const slug = slugify(args.name);
const file = path.join(args.flowsDir, `${slug}.json`);
if (fs.existsSync(file)) throw new Error(`Flow already exists: ${file}`);

const flow = {
  name: slug,
  description: args.description
    ?? "Recorded flow draft. Replace assertions with exact expected behavior after first successful run.",
  ...(args.studioName ? { studioName: args.studioName } : {}),
  ...(args.studioInstanceId ? { studioInstanceId: args.studioInstanceId } : {}),
  ...(args.placeName ? { placeName: args.placeName } : {}),
  pollAttempts: 15,
  pollMs: 3000,
  steps: [
    {
      type: "call",
      tool: "get_studio_state",
      saveAs: "stateBefore",
      expectRegex: ["Current Studio Mode:\\s*Edit"],
      label: "edit mode detected",
    },
    {
      type: "call",
      tool: "search_game_tree",
      args: {
        path: args.root ?? "Workspace.PunchWallRPG",
        max_depth: 3,
        head_limit: 120,
      },
      saveAs: "editTree",
      label: "capture edit tree",
    },
    {
      type: "call",
      tool: "start_stop_play",
      args: { is_start: true },
      timeoutMs: 60000,
      label: "start play and wait for DataModels",
    },
    {
      type: "call",
      tool: "get_console_output",
      saveAs: "console",
      label: "capture console",
    },
    {
      type: "assertNoConsoleErrors",
      source: "console",
      label: "console clean",
    },
    {
      type: "call",
      tool: "start_stop_play",
      args: { is_start: false },
      timeoutMs: 60000,
      label: "stop play and wait for Edit",
    },
  ],
  cleanup: [
    {
      type: "call",
      tool: "start_stop_play",
      args: { is_start: false },
      timeoutMs: 60000,
      allowError: true,
      label: "cleanup stop play",
    },
  ],
};

fs.writeFileSync(file, `${JSON.stringify(flow, null, 2)}\n`, "utf8");
console.log(file);
