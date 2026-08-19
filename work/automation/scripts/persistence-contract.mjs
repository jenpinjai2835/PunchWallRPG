#!/usr/bin/env node
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const repositoryRoot = path.resolve(scriptDirectory, "..", "..", "..");
const profilePath = path.join(
  repositoryRoot,
  "work",
  "punch-wall-rpg",
  "src",
  "server",
  "ProfilePersistence.lua",
);
const bootstrapPath = path.join(
  repositoryRoot,
  "work",
  "punch-wall-rpg",
  "src",
  "server",
  "PunchWallBootstrap.server.lua",
);
const gameConfigPath = path.join(
  repositoryRoot,
  "work",
  "punch-wall-rpg",
  "src",
  "shared",
  "GameConfig.lua",
);
const forestBuilderPath = path.join(
  repositoryRoot,
  "work",
  "punch-wall-rpg",
  "src",
  "shared",
  "ForestVisualBuilder.lua",
);
const shutdownFlowPath = path.join(
  repositoryRoot,
  "work",
  "automation",
  "flows",
  "persistence-shutdown-single-flight.json",
);
const read = (file) => fs.readFileSync(file, "utf8").replace(/\r\n?/g, "\n");
const profileSource = read(profilePath);
const bootstrapSource = read(bootstrapPath);
const gameConfigSource = read(gameConfigPath);
const forestBuilderSource = read(forestBuilderPath);
const shutdownFlow = JSON.parse(read(shutdownFlowPath));
const checks = {};

function check(name, condition, detail) {
  checks[name] = condition === true;
  assert.equal(condition, true, `${name}: ${detail}`);
}

function sourceSlice(source, startMarker, endMarker) {
  const start = source.indexOf(startMarker);
  const end = source.indexOf(endMarker, Math.max(0, start + startMarker.length));
  assert.notEqual(start, -1, `Missing source marker: ${startMarker}`);
  assert.notEqual(end, -1, `Missing source marker: ${endMarker}`);
  return source.slice(start, end);
}

function valueFrom(source, expression, label) {
  const match = source.match(expression);
  assert(match, `Could not resolve ${label}`);
  return match[1];
}

function parseArgs(argv) {
  const args = {};
  for (let index = 0; index < argv.length; index += 1) {
    if (argv[index] === "--luau-tool-dir") {
      args.luauToolDir = path.resolve(argv[index + 1]);
      index += 1;
    } else if (argv[index] === "--help" || argv[index] === "-h") {
      console.log("Usage: node persistence-contract.mjs [--luau-tool-dir <directory>]");
      process.exit(0);
    } else {
      throw new Error(`Unknown argument: ${argv[index]}`);
    }
  }
  return args;
}

function executableCandidates(baseName) {
  return process.platform === "win32" ? [`${baseName}.exe`, baseName] : [baseName];
}

function candidateToolDirectories(explicitDirectory) {
  const directories = [];
  if (explicitDirectory) directories.push(explicitDirectory);
  if (process.env.PUNCH_WALL_LUAU_TOOL_DIR) {
    directories.push(path.resolve(process.env.PUNCH_WALL_LUAU_TOOL_DIR));
  }
  directories.push(
    path.join(repositoryRoot, ".tools", "luau"),
    path.join(repositoryRoot, "tools", "luau"),
  );
  for (const pathEntry of String(process.env.PATH ?? "").split(path.delimiter)) {
    if (pathEntry) directories.push(pathEntry);
  }
  const temporaryRoots = [
    os.tmpdir(),
    path.join(path.parse(os.tmpdir()).root, "Temp"),
  ];
  for (const temporaryRoot of [...new Set(
    temporaryRoots.map((candidate) => path.resolve(candidate)),
  )]) {
    try {
      const temporaryCandidates = fs
        .readdirSync(temporaryRoot, { withFileTypes: true })
        .filter((entry) => entry.isDirectory() && /^codex-luau-/i.test(entry.name))
        .map((entry) => path.join(temporaryRoot, entry.name))
        .sort((left, right) => fs.statSync(right).mtimeMs - fs.statSync(left).mtimeMs);
      directories.push(...temporaryCandidates);
    } catch {
      // The required-tool error below remains actionable when discovery is unavailable.
    }
  }
  return [...new Set(directories.map((directory) => path.resolve(directory)))];
}

function resolveTool(baseName, directories) {
  for (const directory of directories) {
    for (const candidateName of executableCandidates(baseName)) {
      const candidate = path.join(directory, candidateName);
      if (fs.existsSync(candidate) && fs.statSync(candidate).isFile()) return candidate;
    }
  }
  throw new Error(
    `Required ${baseName} executable was not found. Install Luau, add it to PATH, `
      + "set PUNCH_WALL_LUAU_TOOL_DIR, or pass --luau-tool-dir.",
  );
}

function runTool(command, args, options = {}) {
  const result = spawnSync(command, args, {
    cwd: repositoryRoot,
    encoding: "utf8",
    timeout: 120000,
    ...options,
  });
  if (result.error) throw result.error;
  assert.equal(
    result.status,
    0,
    `${path.basename(command)} ${args.join(" ")} failed:\n${result.stderr || result.stdout}`,
  );
  return result;
}

const expectedBoostFields = [
  "CoinBoostExpiresAt",
  "DamageBoostExpiresAt",
  "SpeedBoostExpiresAt",
  "TrainingBoostExpiresAt",
];
const boostBlock = valueFrom(
  profileSource,
  /ProfilePersistence\.BoostExpiryFields\s*=\s*\{([\s\S]*?)\n\}/,
  "ProfilePersistence.BoostExpiryFields",
);
const actualBoostFields = [...boostBlock.matchAll(/"([^"]+)"/g)].map((match) => match[1]);
check(
  "boost_schema_is_complete_and_exact",
  JSON.stringify(actualBoostFields) === JSON.stringify(expectedBoostFields),
  `Expected ${expectedBoostFields.join(", ")}, received ${actualBoostFields.join(", ")}`,
);

const loadBlock = sourceSlice(
  bootstrapSource,
  "local function loadPlayerData(player)",
  "local function applySpeedBoostState(player, character)",
);
check(
  "load_failure_is_non_writable_and_never_defaults",
  /return\s*\{\s*ok\s*=\s*false,\s*state\s*=\s*"Failed",\s*writable\s*=\s*false,\s*reason\s*=\s*"current_profile_lease_failed:/.test(loadBlock)
    && /return\s*\{\s*ok\s*=\s*false,\s*state\s*=\s*"Failed",\s*writable\s*=\s*false,\s*reason\s*=\s*"legacy_load_failed:/.test(loadBlock)
    && /return\s*\{\s*ok\s*=\s*false,\s*state\s*=\s*"Failed",\s*writable\s*=\s*false,\s*reason\s*=\s*"seed_profile_lease_failed:/.test(loadBlock)
    && !/return\s*\{\s*\}/.test(loadBlock),
  "DataStore failures must return a non-writable failure, never an empty/default profile.",
);
check(
  "load_acquires_atomic_fenced_lease_before_writable",
  loadBlock.includes("persistenceRuntime.playerStore:UpdateAsync")
    && loadBlock.includes("ProfilePersistence.AcquireSessionLease")
    && loadBlock.includes("HttpService:GenerateGUID(false)")
    && loadBlock.includes("fence = currentFence")
    && loadBlock.includes("fence = seededFence")
    && loadBlock.indexOf("ProfilePersistence.AcquireSessionLease")
      < loadBlock.indexOf("writable = true"),
  "A durable load must acquire a token/revision lease inside UpdateAsync before exposing writability.",
);
const ensureStatsBlock = sourceSlice(
  bootstrapSource,
  "local function ensureStats(player)",
  "local function statValue(player, name, fallback)",
);
const loadGuardIndex = ensureStatsBlock.indexOf("if not loadResult.ok");
const kickIndex = ensureStatsBlock.indexOf("player:Kick(", loadGuardIndex);
const statsCreationIndex = ensureStatsBlock.indexOf('stats.Name = "RPGStats"');
check(
  "failed_load_kicks_before_stats_creation",
  loadGuardIndex >= 0
    && kickIndex > loadGuardIndex
    && statsCreationIndex > kickIndex
    && /ProfilePersistenceState", "Failed"/.test(ensureStatsBlock.slice(loadGuardIndex, statsCreationIndex)),
  "A failed load must fail closed before any authoritative stats folder is created.",
);
const readinessBlock = sourceSlice(
  bootstrapSource,
  "local function profileSessionReady(session, hasRPGStats, hasLeaderstats, requireWritable)",
  "persistenceRuntime.readinessContract = runProfileReadinessContract()",
);
const restoreBlock = sourceSlice(
  bootstrapSource,
  "local function initializePlayerProfileSession(player, loadResult)",
  "local function savedNumber(savedData, name)",
);
const readyCallIndex = ensureStatsBlock.indexOf(
  "persistenceRuntime.markPlayerProfileReady(player)",
);
check(
  "profile_readiness_blocks_mutation_save_and_receipt_until_stats_complete",
  readinessBlock.includes("session.initializing == true or session.ready ~= true")
    && readinessBlock.includes("not hasRPGStats or not hasLeaderstats")
    && (readinessBlock.match(/value:IsA\("NumberValue"\)/g) ?? []).length === 2
    && readinessBlock.includes('value:IsA("StringValue")')
    && !readinessBlock.includes('value:IsA("ValueBase")')
    && readinessBlock.includes("Initializing profiles must not call UpdateAsync")
    && readinessBlock.includes("Initializing profiles must not grant purchases")
    && restoreBlock.includes("initializing = true")
    && restoreBlock.includes("ready = false")
    && restoreBlock.includes('player:SetAttribute("ProfileWritable", false)')
    && restoreBlock.includes("session.initializing = false")
    && restoreBlock.includes("session.ready = true")
    && readyCallIndex > statsCreationIndex
    && readyCallIndex > ensureStatsBlock.indexOf("stats.TrainingUpdatedAt.Value = nowEpoch"),
  "Writability and receipt/save paths must stay closed until both stat folders are fully normalized.",
);
const settingsHelperBlock = sourceSlice(
  bootstrapSource,
  "local function normalizedUiScale(value)",
  "local function handleMobileAction(player, request)",
);
const mobileActionBlock = sourceSlice(
  bootstrapSource,
  "local function handleMobileAction(player, request)",
  "local function resetWallState(wall)",
);
check(
  "settings_input_is_canonicalized_before_persistence",
  settingsHelperBlock.includes("local numeric = tonumber(value)")
    && settingsHelperBlock.includes("numeric ~= numeric")
    && settingsHelperBlock.includes("numeric == math.huge")
    && settingsHelperBlock.includes("numeric == -math.huge")
    && settingsHelperBlock.includes('typeof(value) == "boolean"')
    && mobileActionBlock.includes('action == "UpdateSettings"')
    && mobileActionBlock.includes("motion = normalizedSettingBoolean(value.motion)")
    && mobileActionBlock.includes("sound = normalizedSettingBoolean(value.sound)")
    && mobileActionBlock.includes("uiScale = normalizedUiScale(value.uiScale)"),
  "UpdateSettings must convert only real booleans and reject/fallback nonfinite uiScale input before JSON persistence.",
);
const gamePassReconciliationBlock = sourceSlice(
  bootstrapSource,
  "local function ownsGamePassWithRetry(player, gamePassId)",
  "persistenceRuntime.flushPendingGamePassGrants = flushPendingGamePassGrants",
);
check(
  "game_pass_reconciliation_is_error_aware_and_bounded",
  bootstrapSource.includes("gamePassReconciliationAttempts = 3")
    && bootstrapSource.includes("gamePassReconciliationRetryBaseSeconds = 2")
    && gamePassReconciliationBlock.includes(
      "local ownsPass, ownershipError = ownsGamePassWithRetry",
    )
    && gamePassReconciliationBlock.includes("if ownershipError ~= nil then")
    && gamePassReconciliationBlock.includes("failedCount += 1")
    && gamePassReconciliationBlock.includes("if failedCount == 0 then")
    && gamePassReconciliationBlock.includes(
      "session.gamePassReconciliationComplete = true",
    )
    && gamePassReconciliationBlock.includes("task.delay(retryDelay")
    && gamePassReconciliationBlock.includes(
      'player:SetAttribute("GamePassOwnershipReconciled", false)',
    ),
  "Marketplace errors must remain distinct from definitive non-ownership and retry with a hard bound.",
);
check(
  "forest_imported_visuals_have_hard_geometry_caps",
  forestBuilderSource.includes("MAX_IMPORTED_TREE_BASE_PARTS = 8")
    && forestBuilderSource.includes("MAX_IMPORTED_TREE_DESCENDANTS = 32")
    && forestBuilderSource.includes("HARD_FOREST_VISUAL_PART_BUDGET = 448")
    && forestBuilderSource.includes("local function importedTreeWithinBudget(template)")
    && forestBuilderSource.includes("basePartCount <= MAX_IMPORTED_TREE_BASE_PARTS")
    && forestBuilderSource.includes("#descendants <= MAX_IMPORTED_TREE_DESCENDANTS")
    && forestBuilderSource.includes(
      "forestVisualPartCount <= HARD_FOREST_VISUAL_PART_BUDGET",
    )
    && forestBuilderSource.includes(
      'forestFolder:SetAttribute("ForestVisualBudgetValidated", true)',
    ),
  "Imported templates and the fully cloned forest must both have enforced BasePart/descendant budgets.",
);
check(
  "forest_imports_use_shared_strict_visual_sanitizer",
  forestBuilderSource.includes(
    'local FistVisualBuilder = require(ReplicatedStorage:WaitForChild("FistVisualBuilder"))',
  )
    && forestBuilderSource.includes(
      "pcall(FistVisualBuilder.SanitizeVisual, model)",
    )
    && (forestBuilderSource.match(/FistVisualBuilder\.IsSanitizedVisual\(model\)/g) ?? []).length >= 3
    && forestBuilderSource.includes(
      'model:SetAttribute("StrictVisualAllowlistVerified", true)',
    )
    && forestBuilderSource.indexOf(
      'model:SetAttribute("AssetSanitized", true)',
    ) > forestBuilderSource.indexOf(
      "pcall(FistVisualBuilder.SanitizeVisual, model)",
    ),
  "Forest Creator Store clones must receive and retain the shared strict sanitizer attestation before use.",
);
const externalVisualSafetyBlock = sourceSlice(
  bootstrapSource,
  "function visualSafety.geometry(instance)",
  "local function tryInsertVisualAsset(candidate, position, scale, yaw)",
);
const externalTemplateBlock = sourceSlice(
  bootstrapSource,
  "local function loadExternalVisualTemplates()",
  "loadExternalVisualTemplates()",
);
const externalCloneBlock = sourceSlice(
  bootstrapSource,
  "local function cloneExternalVisual(",
  "local function makeProceduralHeroNPC(",
);
check(
  "all_creator_store_visuals_use_strict_sanitizer_and_geometry_budgets",
  bootstrapSource.includes(
    'sanitizer = require(ReplicatedStorage:WaitForChild("FistVisualBuilder"))',
  )
    && bootstrapSource.includes("maxBaseParts = 96")
    && bootstrapSource.includes("maxDescendants = 256")
    && bootstrapSource.includes("maxRawDescendants = 512")
    && externalVisualSafetyBlock.includes(
      "pcall(visualSafety.sanitizer.SanitizeVisual, instance)",
    )
    && (externalVisualSafetyBlock.match(
      /visualSafety\.sanitizer\.IsSanitizedVisual\(instance\)/g,
    ) ?? []).length >= 1
    && externalVisualSafetyBlock.indexOf(
      'instance:SetAttribute("AssetSanitized", true)',
    ) > externalVisualSafetyBlock.indexOf(
      "visualSafety.sanitizer.IsSanitizedVisual(instance)",
    )
    && externalVisualSafetyBlock.includes(
      "basePartCount <= visualSafety.maxBaseParts",
    )
    && externalVisualSafetyBlock.includes("descendantCount <= descendantLimit")
    && externalVisualSafetyBlock.includes(
      "visualSafety.withinBudget(instance, true)",
    )
    && externalVisualSafetyBlock.includes(
      "visualSafety.withinBudget(instance)",
    )
    && externalTemplateBlock.includes(
      "for _, existing in ipairs(folder:GetChildren()) do",
    )
    && externalTemplateBlock.includes("visualSafety.sanitize(existing)")
    && externalTemplateBlock.includes("visualSafety.sanitize(asset)")
    && externalTemplateBlock.includes("external_template_total_budget_exceeded")
    && externalCloneBlock.includes("visualSafety.sanitize(clone)")
    && externalCloneBlock.includes(
      "visualSafety.reserveRuntimeBudget(basePartCount, descendantCount)",
    )
    && !bootstrapSource.includes("local allowedVisualClasses")
    && !bootstrapSource.includes("local function sanitizeVisualAsset"),
  "Every preloaded, loaded, inserted, and cloned Creator Store visual must fail closed through one shared strict sanitizer and bounded geometry budgets.",
);

const queueBlock = sourceSlice(
  bootstrapSource,
  "local function newPersistenceTicket(reason)",
  'local base = makePart("World 1 Forest Ground"',
);
const requestPlayerSaveBlock = sourceSlice(
  queueBlock,
  "local function requestPlayerSave(player, reason, finalSave)",
  "local function enqueueReceiptOperation(player, purchaseId, execute)",
);
check(
  "save_operations_are_serialized_and_coalesced",
  queueBlock.includes("state.running")
    && queueBlock.includes("table.remove(state.operations, 1)")
    && queueBlock.includes("previousOperation.kind == \"save\"")
    && queueBlock.includes("not previousOperation.finalSave")
    && queueBlock.includes("startPersistenceWorker(player)"),
  "Save requests must share one FIFO worker and only coalesce non-final queued saves.",
);
check(
  "persistence_queue_and_coalesced_ticket_counts_are_bounded",
  bootstrapSource.includes("maxQueueOperations = 32")
    && bootstrapSource.includes("maxSaveTicketsPerOperation = 8")
    && queueBlock.includes(
      "previousOperation.tickets >= persistenceRuntime.maxSaveTicketsPerOperation",
    )
    && queueBlock.includes(
      "state.queuedReceiptCount >= persistenceRuntime.maxQueueOperations",
    )
    && queueBlock.includes("receipt_queue_full"),
  "Receipt operations and coalesced save tickets must both have explicit hard bounds.",
);
const finalTicketLookupIndex = requestPlayerSaveBlock.indexOf(
  "local existingFinalTicket = finalSave and persistenceRuntime.finalSaveTickets[player]",
);
const requestReadinessIndex = requestPlayerSaveBlock.indexOf(
  "local ready, readinessError = profileReady(player, false)",
);
const releaseRememberIndex = requestPlayerSaveBlock.indexOf(
  "rememberFinalSaveTicket(player, finalSave, ticket)",
);
const releaseWorkerIndex = requestPlayerSaveBlock.indexOf(
  "startPersistenceWorker(player)",
  releaseRememberIndex,
);
const saveRememberIndex = requestPlayerSaveBlock.lastIndexOf(
  "rememberFinalSaveTicket(player, finalSave, ticket)",
);
const saveWorkerIndex = requestPlayerSaveBlock.lastIndexOf(
  "startPersistenceWorker(player)",
);
check(
  "final_save_requests_are_single_flight_without_masking_unready_profiles",
  bootstrapSource.includes(
    'finalSaveTickets = setmetatable({}, { __mode = "k" })',
  )
    && queueBlock.includes(
      "persistenceRuntime.finalSaveTickets[player] = ticket",
    )
    && finalTicketLookupIndex >= 0
    && finalTicketLookupIndex < requestReadinessIndex
    && requestPlayerSaveBlock.includes(
      "return existingFinalTicket",
    )
    && releaseRememberIndex >= 0
    && releaseRememberIndex < releaseWorkerIndex
    && saveRememberIndex >= 0
    && saveRememberIndex < saveWorkerIndex
    && requestPlayerSaveBlock.includes(
      "return completedPersistenceTicket(reason, false, readinessError)",
    )
    && !requestPlayerSaveBlock.includes(
      "completedPersistenceTicket(reason, true, readinessError",
    )
    && ensureStatsBlock.includes(
      "local finalSaveTicket = persistenceRuntime.finalSaveTickets[player]",
    )
    && ensureStatsBlock.includes(
      "session and session.fence and not finalSaveTicket",
    )
    && ensureStatsBlock.includes("if not finalSaveTicket then"),
  "Final saves must reuse one weakly held ticket before readiness checks, cache accepted work before starting a worker, and preserve missing/initializing profile failures when no ticket exists.",
);
const persistBlock = sourceSlice(
  bootstrapSource,
  "local function persistSnapshot(player, snapshot, releaseLease)",
  "local function runPersistenceOperation(player, operation)",
);
check(
  "save_merge_is_fenced_and_atomically_renews_or_releases_lease",
  persistBlock.includes("profileReady(player, true)")
    && persistBlock.includes("persistenceRuntime.playerStore:UpdateAsync")
    && persistBlock.includes("ProfilePersistence.MergeSnapshotFenced")
    && persistBlock.includes("ProfilePersistence.RenewSessionLease")
    && persistBlock.includes("ProfilePersistence.ReleaseSessionLease")
    && persistBlock.indexOf("ProfilePersistence.MergeSnapshotFenced")
      < persistBlock.indexOf("ProfilePersistence.RenewSessionLease")
    && persistBlock.indexOf("ProfilePersistence.MergeSnapshotFenced")
      < persistBlock.indexOf("ProfilePersistence.ReleaseSessionLease"),
  "Every durable snapshot must validate its fence and renew/release in the same UpdateAsync callback.",
);
const shutdownBlock = sourceSlice(
  bootstrapSource,
  "Players.PlayerRemoving:Connect(function(player)",
  "task.spawn(function()\n\twhile not persistenceRuntime.serverClosing",
);
check(
  "player_removing_and_shutdown_drain_final_tickets",
  shutdownBlock.includes(
    "local session = persistenceRuntime.profileSessions[player]",
  )
    && shutdownBlock.includes("local canFinalizeCurrentSession = session and (")
    && shutdownBlock.includes("session.ready == true")
    && shutdownBlock.includes("session.fence")
    && shutdownBlock.includes("session.canBecomeWritable")
    && shutdownBlock.includes("if not canFinalizeCurrentSession then")
    && shutdownBlock.includes(
      "persistenceRuntime.markPlayerDeparted(player, true)",
    )
    && shutdownBlock.includes('requestPlayerSave(player, "PlayerRemoving", true)')
    && shutdownBlock.includes("persistenceRuntime.playerRemovingSaveTimeout")
    && shutdownBlock.includes("persistenceRuntime.waitForTicket")
    && shutdownBlock.includes("game:BindToClose(function()")
    && shutdownBlock.includes("if session and session.ready == true then")
    && shutdownBlock.includes('requestPlayerSave(player, "BindToClose", true)')
    && shutdownBlock.includes("pending.ticket.completed")
    && shutdownBlock.includes("persistenceRuntime.shutdownDrainTimeout")
    && shutdownBlock.includes("Shutdown drain incomplete"),
  "Lifecycle hooks must skip stale or never-ready players without a fake save result, while current ready sessions still share, drain, and report failures from one real final-save ticket.",
);
const shutdownSteps = shutdownFlow.steps ?? [];
const shutdownStartSteps = shutdownSteps.filter(
  (step) => step.tool === "start_stop_play" && step.args?.is_start === true,
);
const firstShutdownStopIndex = shutdownSteps.findIndex(
  (step) => step.tool === "start_stop_play" && step.args?.is_start === false,
);
const postStopConsoleIndex = shutdownSteps.findIndex(
  (step) => step.tool === "get_console_output"
    && step.saveAs === "postStopConsole",
);
const defaultPostStopAssertionIndex = shutdownSteps.findIndex(
  (step) => step.type === "assertNoConsoleErrors"
    && step.source === "postStopConsole"
    && step.patterns === undefined,
);
const persistenceWarningAssertionIndex = shutdownSteps.findIndex(
  (step) => step.type === "assertNoConsoleErrors"
    && step.source === "postStopConsole"
    && Array.isArray(step.patterns)
    && step.patterns.includes("Shutdown drain incomplete")
    && step.patterns.includes("PlayerRemoving save did not complete")
    && step.patterns.includes("profile_not_loaded"),
);
const finalEditStep = shutdownSteps.at(-1);
const shutdownCleanupStep = shutdownFlow.cleanup?.at(-1);
check(
  "studio_shutdown_flow_captures_post_stop_errors_and_persistence_warnings",
  shutdownStartSteps.length === 1
    && firstShutdownStopIndex >= 0
    && postStopConsoleIndex > firstShutdownStopIndex
    && defaultPostStopAssertionIndex > postStopConsoleIndex
    && persistenceWarningAssertionIndex > postStopConsoleIndex
    && finalEditStep?.tool === "start_stop_play"
    && finalEditStep.args?.is_start === false
    && finalEditStep.allowError === true
    && shutdownCleanupStep?.tool === "start_stop_play"
    && shutdownCleanupStep.args?.is_start === false
    && shutdownCleanupStep.allowError === true,
  "The one-cycle Studio regression must stop before capture, reject exact lifecycle warnings, and leave both success and cleanup paths in Edit mode.",
);

const receiptBlock = sourceSlice(
  bootstrapSource,
  "local function processReceiptDurably(player, productId, purchaseId, product)",
  "shared.PunchWallBuildPremiumOffers = function()",
);
const purchaseGrantedIndex = receiptBlock.indexOf(
  "return Enum.ProductPurchaseDecision.PurchaseGranted",
);
const ticketWaitIndex = receiptBlock.indexOf("persistenceRuntime.waitForTicket");
check(
  "receipt_grants_only_after_durable_idempotent_commit",
  receiptBlock.includes("session.receiptUncertain[purchaseId] = true")
    && receiptBlock.includes("persistenceRuntime.playerStore:UpdateAsync")
    && receiptBlock.includes("ProfilePersistence.CommitReceiptFenced")
    && receiptBlock.includes("ProfilePersistence.RenewSessionLease")
    && receiptBlock.includes("ProfilePersistence.NormalizePurchaseId")
    && receiptBlock.includes("persistenceRuntime.enqueueReceiptOperation")
    && receiptBlock.includes("profileReady(player, true)")
    && ticketWaitIndex >= 0
    && purchaseGrantedIndex > ticketWaitIndex
    && receiptBlock.slice(ticketWaitIndex, purchaseGrantedIndex).includes("if granted then"),
  "ProcessReceipt must return PurchaseGranted only after its serialized durable ticket succeeds.",
);
check(
  "receipt_module_self_test_covers_retry_and_compaction",
  profileSource.includes("receipt retry erased or doubled durable reward")
    && profileSource.includes("duplicate receipt changed balance")
    && profileSource.includes("compacted duplicate receipt was granted again")
    && profileSource.includes("compaction forgot durable purchase id")
    && profileSource.includes("receipt seen guard must fail closed")
    && profileSource.includes("mixed Seen migration forgot array purchase id")
    && profileSource.includes("mixed Seen migration forgot mapped purchase id")
    && profileSource.includes("duplicate after mixed Seen migration was not rejected"),
  "The executable module contract must cover retry, compaction, mixed Seen migration, and duplicate rejection.",
);
const numberSchemaBlock = valueFrom(
  profileSource,
  /ProfilePersistence\.NumberFieldSchema\s*=\s*\{([\s\S]*?)\n\}/,
  "ProfilePersistence.NumberFieldSchema",
);
const textSchemaBlock = valueFrom(
  profileSource,
  /ProfilePersistence\.TextFieldSchema\s*=\s*\{([\s\S]*?)\n\}/,
  "ProfilePersistence.TextFieldSchema",
);
const countSchemaEntries = (source) => (
  [...source.matchAll(/^\s*[A-Za-z][A-Za-z0-9]*\s*=\s*\{/gm)].length
);
check(
  "authoritative_profile_schema_is_complete_and_fail_closed",
  countSchemaEntries(numberSchemaBlock) === 34
    && countSchemaEntries(textSchemaBlock) === 17
    && /TrainingStationId\s*=\s*\{\s*default\s*=\s*"rookie_bag",\s*maxBytes\s*=\s*64\s*\}/.test(textSchemaBlock)
    && profileSource.includes("current wrong-type number must fail closed")
    && profileSource.includes("current nonfinite number must fail closed")
    && profileSource.includes("current oversized JSON must fail closed")
    && profileSource.includes("current malformed JSON must fail closed")
    && profileSource.includes(
      "legacy-shaped current profile did not receive a compatible missing-field default",
    ),
  "All authoritative numeric/text/JSON fields need strict current-value validation and compatible missing-field defaults.",
);
check(
  "counter_flag_and_epoch_fields_require_integers",
  (numberSchemaBlock.match(/integer\s*=\s*true/g) ?? []).length === 24
    && /CritChance\s*=\s*\{[^}]*\}/.test(numberSchemaBlock)
    && !/CritChance\s*=\s*\{[^}]*integer\s*=\s*true/.test(numberSchemaBlock)
    && !/FistMultiplier\s*=\s*\{[^}]*integer\s*=\s*true/.test(numberSchemaBlock)
    && !/HonorPowerBonus\s*=\s*\{[^}]*integer\s*=\s*true/.test(numberSchemaBlock)
    && profileSource.includes("fractional authoritative counter must fail closed")
    && profileSource.includes(
      "legitimate fractional multiplier or crit value was rejected",
    ),
  "Counters, flags, and epoch fields must be integral without rejecting valid fractional multipliers or crit values.",
);
check(
  "json_lists_and_settings_have_typed_bounded_shapes",
  profileSource.includes('schema.jsonShape = "stringArray"')
    && profileSource.includes(
      "ProfilePersistence.TextFieldSchema.SettingsJSON.jsonShape = \"settings\"",
    )
    && profileSource.includes('element.kind ~= "string"')
    && profileSource.includes('motion.kind ~= "boolean"')
    && profileSource.includes('sound.kind ~= "boolean"')
    && profileSource.includes("uiScale.value < 0.8")
    && profileSource.includes("uiScale.value > 1.2")
    && profileSource.includes("JSON list accepted a non-string element")
    && profileSource.includes("Settings JSON accepted a nonfinite uiScale")
    && profileSource.includes("Settings JSON accepted an unknown key"),
  "Persisted list JSON must contain bounded strings only and SettingsJSON must match its exact typed shape.",
);
check(
  "top_level_profiles_and_snapshots_are_canonical",
  profileSource.includes("local KNOWN_PROFILE_FIELDS = {}")
    && profileSource.includes("local function canonicalProfileCopy(")
    && profileSource.includes('return nil, "unknown_profile_field"')
    && profileSource.includes('return false, "snapshot_unknown_field"')
    && profileSource.includes(
      "legacy migration did not drop unknown top-level fields",
    )
    && profileSource.includes(
      "current profile accepted an unknown top-level field",
    )
    && profileSource.includes(
      "snapshot accepted an unknown top-level field",
    ),
  "Current profiles and snapshots must reject unknown keys while legacy migration explicitly drops them.",
);
check(
  "session_lease_fencing_api_and_contract_are_complete",
  profileSource.includes("function ProfilePersistence.AcquireSessionLease(")
    && profileSource.includes("function ProfilePersistence.RenewSessionLease(")
    && profileSource.includes("function ProfilePersistence.ReleaseSessionLease(")
    && profileSource.includes("function ProfilePersistence.MergeSnapshotFenced(")
    && profileSource.includes("function ProfilePersistence.CommitReceiptFenced(")
    && profileSource.includes("stale lease takeover did not advance the fencing revision")
    && profileSource.includes("stale fencing revision was allowed to merge")
    && profileSource.includes("stale fencing revision was allowed to commit a receipt")
    && profileSource.includes("session lease was not bounded or revisioned"),
  "The pure module must expose acquire/renew/release plus fenced save/receipt helpers with monotonic stale-writer tests.",
);

const collectBlock = sourceSlice(
  bootstrapSource,
  "local function collectPlayerData(player)",
  "local function newPersistenceTicket(reason)",
);
check(
  "boost_expiries_round_trip_and_reapply",
  collectBlock.includes("ProfilePersistence.BoostExpiryFields")
    && collectBlock.includes("player:GetAttribute(field)")
    && restoreBlock.includes("ProfilePersistence.BoostExpiryFields")
    && restoreBlock.includes("player:SetAttribute(field")
    && bootstrapSource.includes("persistenceRuntime.applySpeedBoostState(player, character)")
    && bootstrapSource.includes("TrainingEndsAt = player:GetAttribute(\"TrainingBoostExpiresAt\")")
    && profileSource.includes("boost expiry contract failed"),
  "All four boost expiries must serialize, restore, sync, and reapply runtime movement state.",
);

const dataVersion = Number(valueFrom(gameConfigSource, /\bDataVersion\s*=\s*(\d+)/, "GameConfig.DataVersion"));
const contractVersion = valueFrom(
  profileSource,
  /ProfilePersistence\.ContractVersion\s*=\s*"([^"]+)"/,
  "ProfilePersistence.ContractVersion",
);
const maxLedgerEntries = Number(valueFrom(
  profileSource,
  /ProfilePersistence\.MaxReceiptLedgerEntries\s*=\s*(\d+)/,
  "ProfilePersistence.MaxReceiptLedgerEntries",
));
const maxSeenReceiptIds = Number(valueFrom(
  profileSource,
  /ProfilePersistence\.MaxSeenReceiptIds\s*=\s*(\d+)/,
  "ProfilePersistence.MaxSeenReceiptIds",
));

const commandLine = parseArgs(process.argv.slice(2));
const toolDirectories = candidateToolDirectories(commandLine.luauToolDir);
const luauCompile = resolveTool("luau-compile", toolDirectories);
const luauAnalyze = resolveTool("luau-analyze", toolDirectories);
const luau = resolveTool("luau", toolDirectories);
check(
  "luau_tools_resolve_from_one_installation",
  path.dirname(luauCompile) === path.dirname(luauAnalyze)
    && path.dirname(luauCompile) === path.dirname(luau),
  "Compiler, analyzer, and runtime must resolve from the same Luau installation.",
);

for (const optimization of ["O0", "O1", "O2"]) {
  runTool(luauCompile, ["--null", `-${optimization}`, bootstrapPath]);
  runTool(luauCompile, ["--null", `-${optimization}`, profilePath]);
}
check(
  "persistence_sources_compile_at_all_release_levels",
  true,
  "Bootstrap and persistence module must compile at O0, O1, and O2.",
);
runTool(luauAnalyze, [profilePath]);
check(
  "profile_persistence_static_analysis_passes",
  true,
  "ProfilePersistence must pass luau-analyze.",
);

const selfTestDirectory = fs.mkdtempSync(
  path.join(repositoryRoot, ".persistence-contract-"),
);
const selfTestPath = path.join(selfTestDirectory, "runner.luau");
const selfTestRequirePath = path
  .relative(selfTestDirectory, profilePath)
  .replaceAll(path.sep, "/")
  .replace(/\.lua$/i, "");
fs.writeFileSync(
  selfTestPath,
  [
    `local p=require(${JSON.stringify(selfTestRequirePath)})`,
    `local r=p.RunContractSelfTest(${dataVersion})`,
    "print(r.ok,r.version,r.dataVersion,r.maxReceiptLedgerEntries,r.maxSeenReceiptIds)",
  ].join("\n"),
  "utf8",
);
let selfTest;
try {
  selfTest = runTool(luau, [selfTestPath]);
} finally {
  fs.rmSync(selfTestDirectory, { recursive: true, force: true });
}
const selfTestTokens = selfTest.stdout.trim().split(/\s+/);
const expectedSelfTestTokens = [
  "true",
  contractVersion,
  String(dataVersion),
  String(maxLedgerEntries),
  String(maxSeenReceiptIds),
];
check(
  "profile_persistence_executable_self_test_passes",
  JSON.stringify(selfTestTokens) === JSON.stringify(expectedSelfTestTokens),
  `Expected ${expectedSelfTestTokens.join(" ")}, received ${selfTestTokens.join(" ")}`,
);

const passed = Object.values(checks).filter(Boolean).length;
console.log(JSON.stringify({
  ok: passed === Object.keys(checks).length,
  passed,
  total: Object.keys(checks).length,
  contractVersion,
  dataVersion,
  maxReceiptLedgerEntries: maxLedgerEntries,
  maxSeenReceiptIds,
  toolDirectory: path.dirname(luau),
  checks,
}, null, 2));
