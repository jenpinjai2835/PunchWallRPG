#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const args = process.argv.slice(2);
const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const valueAfter = (name, fallback) => {
  const index = args.indexOf(name);
  return index >= 0 && args[index + 1] ? args[index + 1] : fallback;
};
const iterations = Math.max(1, Number(valueAfter("--iterations", "10000")) || 10000);
const studioName = valueAfter("--studio-name", "PunchWallRPG");
const runner = valueAfter(
  "--runner",
  path.join(scriptDirectory, "flow_runner.mjs"),
);
const studioInstanceId = valueAfter("--studio-instance-id", "");

if (args.includes("--help") || args.includes("-h")) {
  console.log(`Usage:
  node inventory-performance-contract.mjs [--iterations 10000] [--studio-name PunchWallRPG]

Requires the current source to be synced into an open Roblox Studio place. Runs
deterministic Signature contract assertions and a warmed-call benchmark in Edit mode.`);
  process.exit(0);
}
if (!fs.existsSync(runner)) {
  throw new Error(`Roblox Studio flow runner not found: ${runner}`);
}

const luau = `
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InventoryViewModel = require(ReplicatedStorage:WaitForChild("InventoryViewModel"))
local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

local function shallowCopy(source)
	local result = {}
	for key, value in pairs(source) do result[key] = value end
	return result
end

local function cloneStats(source)
	local result = shallowCopy(source)
	if type(source.ShopBoosts) == "table" then result.ShopBoosts = shallowCopy(source.ShopBoosts) end
	return result
end

local checks = {}
local function check(name, condition)
	checks[name] = condition == true
	assert(condition, "Inventory Signature contract failed: " .. name)
end

local stats = {
	OwnedFistsJSON = '["Starter Glove","Boxing Glove"]',
	OwnedPremiumFistsJSON = '["Crimson Vanguard Fist"]',
	EquippedFist = "Starter Glove",
	PetInventoryJSON = '["Crystal Fox#2","Crystal Fox#2","Miner Cat"]',
	EquippedPetsJSON = '["Crystal Fox#2"]',
	LockedPetsJSON = '["slot:2"]',
	OwnedHonorItemsJSON = '["Vanguard Trail"]',
	EquippedHonorItem = "Vanguard Trail",
	ShopBoosts = { CoinEndsAt = 120, DamageEndsAt = 0, SpeedEndsAt = 30 },
}

local baseline = InventoryViewModel.Signature(GameConfig, stats)
check("identical_input_stable", baseline == InventoryViewModel.Signature(GameConfig, stats))
check("identical_value_clone_stable", baseline == InventoryViewModel.Signature(GameConfig, cloneStats(stats)))

local mutations = {
	OwnedFistsJSON = stats.OwnedFistsJSON .. " ",
	OwnedPremiumFistsJSON = stats.OwnedPremiumFistsJSON .. " ",
	EquippedFist = stats.EquippedFist .. "|",
	PetInventoryJSON = stats.PetInventoryJSON .. " ",
	EquippedPetsJSON = stats.EquippedPetsJSON .. " ",
	LockedPetsJSON = stats.LockedPetsJSON .. " ",
	OwnedHonorItemsJSON = stats.OwnedHonorItemsJSON .. " ",
	EquippedHonorItem = stats.EquippedHonorItem .. "|",
	ShopBoosts = { CoinEndsAt = 121, DamageEndsAt = 0, SpeedEndsAt = 30 },
}
for field, changedValue in pairs(mutations) do
	local changed = cloneStats(stats)
	changed[field] = changedValue
	check("relevant_" .. field, baseline ~= InventoryViewModel.Signature(GameConfig, changed))
end

local delimiterA = cloneStats(stats)
delimiterA.OwnedFistsJSON = "ab"
delimiterA.EquippedFist = "c|d"
local delimiterB = cloneStats(stats)
delimiterB.OwnedFistsJSON = "ab|c"
delimiterB.EquippedFist = "d"
check(
	"length_framing_prevents_delimiter_collision",
	InventoryViewModel.Signature(GameConfig, delimiterA) ~= InventoryViewModel.Signature(GameConfig, delimiterB)
)

local irrelevantStats = cloneStats(stats)
irrelevantStats.Power = 999999
irrelevantStats.Unrelated = "changed"
check("irrelevant_stats_ignored", baseline == InventoryViewModel.Signature(GameConfig, irrelevantStats))

local equivalentRoot = shallowCopy(GameConfig)
check("equivalent_root_config_stable", baseline == InventoryViewModel.Signature(equivalentRoot, stats))
equivalentRoot.Irrelevant = "changed"
check("irrelevant_config_ignored", baseline == InventoryViewModel.Signature(equivalentRoot, stats))

local scalarConfig = shallowCopy(GameConfig)
scalarConfig.MaxPetInventory = (tonumber(GameConfig.MaxPetInventory) or 0) + 1
check("config_scalar_invalidates", baseline ~= InventoryViewModel.Signature(scalarConfig, stats))

local catalogConfig = shallowCopy(GameConfig)
catalogConfig.Fists = table.clone(GameConfig.Fists)
catalogConfig.Fists[1] = table.clone(catalogConfig.Fists[1])
catalogConfig.Fists[1].mult = (tonumber(catalogConfig.Fists[1].mult) or 0) + 0.125
check("config_catalog_reference_invalidates", baseline ~= InventoryViewModel.Signature(catalogConfig, stats))

local inPlaceConfig = shallowCopy(GameConfig)
inPlaceConfig.Fists = table.clone(GameConfig.Fists)
inPlaceConfig.Fists[1] = table.clone(inPlaceConfig.Fists[1])
local beforeInPlace = InventoryViewModel.Signature(inPlaceConfig, stats)
inPlaceConfig.Fists[1].mult = (tonumber(inPlaceConfig.Fists[1].mult) or 0) + 0.25
InventoryViewModel.InvalidateSignatureCache(inPlaceConfig)
check(
	"explicit_in_place_invalidation",
	beforeInPlace ~= InventoryViewModel.Signature(inPlaceConfig, stats)
)

InventoryViewModel.InvalidateSignatureCache(GameConfig)
local warmed = InventoryViewModel.Signature(GameConfig, stats)
local started = os.clock()
for _ = 1, ${iterations} do
	assert(InventoryViewModel.Signature(GameConfig, stats) == warmed)
end
local elapsedMs = (os.clock() - started) * 1000
local checkCount = 0
for _ in pairs(checks) do checkCount += 1 end
return HttpService:JSONEncode({
	allPassed = true,
	checks = checks,
	checkCount = checkCount,
	iterations = ${iterations},
	elapsedMs = elapsedMs,
	perCallMs = elapsedMs / ${iterations},
	baselinePerCallMs = 2.267872,
	speedup = 2.267872 / math.max(elapsedMs / ${iterations}, 0.000001),
	signatureBytes = #warmed,
})
`;

const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), "inventory-signature-contract-"));
const flowPath = path.join(tempRoot, "inventory-performance-contract.json");
const flow = {
  name: "inventory-performance-contract",
  description: "Contract and warmed-call benchmark for InventoryViewModel.Signature.",
  studioName,
  pollAttempts: 15,
  pollMs: 2000,
  steps: [
    {
      type: "call",
      tool: "execute_luau",
      args: { datamodel_type: "Edit", code: luau },
      expectRegex: ['"allPassed"\\s*:\\s*true', '"checkCount"\\s*:\\s*18'],
      label: "signature contract and warmed benchmark pass",
    },
  ],
};

try {
  fs.writeFileSync(flowPath, `${JSON.stringify(flow, null, 2)}\n`, "utf8");
  const runnerArguments = [runner, "--flow", flowPath];
  if (studioInstanceId) runnerArguments.push("--studio-instance-id", studioInstanceId);
  const result = spawnSync(process.execPath, runnerArguments, {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
    timeout: 120000,
  });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  if (result.status !== 0) process.exitCode = result.status || 1;
} finally {
  fs.rmSync(tempRoot, { recursive: true, force: true });
}
