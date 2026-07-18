#!/usr/bin/env node
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const repositoryRoot = path.resolve(scriptDirectory, "../../..");
const clientPath = path.join(
  repositoryRoot,
  "work",
  "punch-wall-rpg",
  "src",
  "client",
  "PunchWallClient.client.lua",
);
const inventoryPath = path.join(
  repositoryRoot,
  "work",
  "punch-wall-rpg",
  "src",
  "client",
  "InventoryUI.lua",
);

const read = (filePath) => fs.readFileSync(filePath, "utf8").replace(/\r\n?/g, "\n");
const client = read(clientPath);
const inventory = read(inventoryPath);
const checks = {};

function check(name, condition, detail) {
  checks[name] = condition === true;
  assert.equal(condition, true, `${name}: ${detail}`);
}

function block(source, start, end) {
  const startIndex = source.indexOf(start);
  assert.notEqual(startIndex, -1, `Missing start sentinel: ${start}`);
  const endIndex = source.indexOf(end, startIndex + start.length);
  assert.notEqual(endIndex, -1, `Missing end sentinel: ${end}`);
  return source.slice(startIndex, endIndex);
}

const training = block(
  client,
  "shared.PunchWallSetTrainingAnimation = function(active)",
  "local function beginPunchCamera",
);
const trainingGuard = training.indexOf("if trainingAnimationActive == active then");
const trainingGeneration = training.indexOf("trainingAnimationGeneration += 1");
const trainingSpawn = training.indexOf("task.spawn(function()");
check(
  "training_single_stats_dispatch",
  (client.match(
    /shared\.PunchWallSetTrainingAnimation\(\(payload\.TrainingActive or 0\) >= 1\)/g,
  ) || []).length === 1,
  "StatsChanged must dispatch training state once.",
);
check(
  "training_idempotency_precedes_restart",
  trainingGuard >= 0
    && trainingGeneration > trainingGuard
    && trainingSpawn > trainingGeneration
    && training.includes("return false")
    && training.includes("return true"),
  "The desired-state guard must return before generation changes or a loop is spawned.",
);
check(
  "training_loop_retains_authoritative_guard",
  training.includes("and latestStats.TrainingActive == 1"),
  "A stale direct client request must not animate when authoritative training is inactive.",
);
check(
  "training_restart_is_observable",
  training.includes('gui:SetAttribute("TrainingAnimationGeneration", trainingAnimationGeneration)')
    && training.includes('gui:SetAttribute("TrainingAnimationLoopStartCount", trainingAnimationLoopStartCount)'),
  "Changed-state generations and loop starts need observable counters.",
);

const atmosphere = block(
  client,
  "shared.PunchWallUpdateTierAtmosphere = function(depth)",
  'gui:SetAttribute("FreeAimPunch", true)',
);
const atmosphereGate = atmosphere.indexOf("if not tierAtmosphereCache.dirty");
const atmosphereReturn = atmosphere.indexOf("return false", atmosphereGate);
const firstTween = atmosphere.indexOf("TweenService:Create");
const landmarkChildren = atmosphere.indexOf("landmarks:GetChildren()");
const landmarkDescendants = atmosphere.indexOf("landmark:GetDescendants()");
check(
  "atmosphere_key_covers_tier_motion_and_sound",
  atmosphere.includes("tierAtmosphereCache.tier == tier")
    && atmosphere.includes("tierAtmosphereCache.motion == motionEnabled")
    && atmosphere.includes("tierAtmosphereCache.sound == soundEnabled")
    && atmosphere.includes("motionEnabled = clientSettings.motion == true")
    && atmosphere.includes("soundEnabled = clientSettings.sound == true"),
  "Atmosphere cache must cover every tier, motion, and audio-dependent output.",
);
check(
  "atmosphere_gate_precedes_expensive_work",
  atmosphereGate >= 0
    && atmosphereReturn > atmosphereGate
    && firstTween > atmosphereReturn
    && landmarkChildren > atmosphereReturn
    && landmarkDescendants > atmosphereReturn,
  "An identical cache key must return before tweens or landmark hierarchy scans.",
);
check(
  "atmosphere_sources_invalidate_cache",
  client.includes("landmarks.DescendantAdded:Connect")
    && client.includes("landmarks.DescendantRemoving:Connect")
    && client.includes("gameRoot.ChildAdded:Connect")
    && client.includes("tierAtmosphereRefreshScheduled")
    && client.includes("task.defer(function()")
    && client.includes("shared.PunchWallInvalidateTierAtmosphere = invalidateTierAtmosphere"),
  "Late or replaced landmark content must coalesce and reapply the cached depth.",
);
check(
  "atmosphere_waits_for_authoritative_depth",
  client.includes("local latestTierAtmosphereDepth = nil")
    && client.includes("or latestTierAtmosphereDepth == nil"),
  "Startup replication events must not apply tier zero before the first authoritative depth.",
);
check(
  "atmosphere_application_is_observable",
  atmosphere.includes('gui:SetAttribute("TierAtmosphereApplyCount", tierAtmosphereApplyCount)')
    && atmosphere.includes(
      'gui:SetAttribute("TierAtmosphereLandmarkScanCount", tierAtmosphereLandmarkScanCount)',
    ),
  "Actual applications and hierarchy scans need observable counters.",
);

const snapshotResult = block(
  inventory,
  "function InventoryUI:_snapshotResult(includeDiagnostics)",
  "function InventoryUI:Refresh",
);
const refresh = block(
  inventory,
  "function InventoryUI:Refresh(force, includeDiagnostics)",
  "function InventoryUI:SetCategory",
);
check(
  "refresh_diagnostic_default_is_backward_compatible",
  snapshotResult.includes("if includeDiagnostics == false then")
    && snapshotResult.indexOf("return nil") < snapshotResult.indexOf("return self:GetSnapshot()")
    && !refresh.includes("GetSnapshot()"),
  "Only explicit false may skip diagnostics; the default Refresh return stays a full snapshot.",
);
check(
  "stats_and_visibility_use_fast_refresh",
  client.includes("shared.PunchWallInventoryController:Refresh(false, false)")
    && inventory.includes("self:Refresh(true, false)")
    && !client.includes("shared.PunchWallInventoryController:Refresh()"),
  "Production StatsChanged and visibility refreshes must explicitly skip diagnostic scans.",
);

const nativeCallbackCalls = [
  "self:SetCategory(category, false)",
  "self:SetRarity(rarity, false)",
  "self:SetSearch(self.Search.Text, false)",
  "self:SelectItem(key, false)",
];
check(
  "native_callbacks_skip_diagnostic_snapshots",
  nativeCallbackCalls.every((call) => inventory.includes(call)),
  "Native category, rarity, search, and card callbacks ignore results and must pass false.",
);
check(
  "public_inventory_methods_default_to_diagnostics",
  inventory.includes("function InventoryUI:SetCategory(name, includeDiagnostics)")
    && inventory.includes("function InventoryUI:SetSearch(text, includeDiagnostics)")
    && inventory.includes("function InventoryUI:SetRarity(name, includeDiagnostics)")
    && inventory.includes("function InventoryUI:SelectItem(key, includeDiagnostics)")
    && (inventory.match(/return self:_snapshotResult\(includeDiagnostics\)/g) || []).length >= 8,
  "Public methods need an optional flag while retaining full snapshots when omitted.",
);
check(
  "automation_handlers_still_return_full_snapshots",
  client.includes(
    'return shared.PunchWallInventoryController:SetCategory(tostring(value or "All"))',
  )
    && client.includes(
      'return shared.PunchWallInventoryController:SetSearch(tostring(value or ""))',
    )
    && client.includes(
      'return shared.PunchWallInventoryController:SetRarity(tostring(value or "All"))',
    )
    && client.includes(
      'return shared.PunchWallInventoryController:SelectItem(tostring(value or ""))',
    ),
  "Automation must return exactly one default full snapshot from each public method.",
);
check(
  "diagnostic_cost_is_observable",
  inventory.includes(
    "self._diagnosticSnapshotCount = self._diagnosticSnapshotCount + 1",
  )
    && inventory.includes("diagnosticSnapshots = self._diagnosticSnapshotCount")
    && inventory.includes("diagnosticSnapshotSkips = self._diagnosticSnapshotSkipCount"),
  "Automation snapshots must expose diagnostic builds and explicit skips.",
);

const passed = Object.values(checks).filter(Boolean).length;
console.log(
  JSON.stringify(
    {
      ok: passed === Object.keys(checks).length,
      passed,
      total: Object.keys(checks).length,
      checks,
      files: [
        path.relative(repositoryRoot, clientPath),
        path.relative(repositoryRoot, inventoryPath),
      ],
    },
    null,
    2,
  ),
);
