import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";

const root = path.resolve(import.meta.dirname, "..", "..");
const read = (...parts) => fs.readFileSync(path.join(root, ...parts), "utf8");
const config = read("punch-wall-rpg", "src", "shared", "GameConfig.lua");
const persistence = read("punch-wall-rpg", "src", "server", "ProfilePersistence.lua");
const server = read("punch-wall-rpg", "src", "server", "PunchWallBootstrap.server.lua");
const client = read("punch-wall-rpg", "src", "client", "PunchWallClient.client.lua");
const flowText = read("automation", "flows", "rebirth-progression.json");
const flow = JSON.parse(flowText);
const hasLabel = (label) => flow.steps.some((step) => step.label === label);

const expected = [
  [0, 55, 1000000, 1.25],
  [4, 55, 1939000, 2.25],
  [5, 60, 2288000, 2.5],
  [9, 60, 4436000, 3.5],
  [10, 65, 5234000, 3.75],
  [24, 75, 53110000, 7.25],
  [25, 80, 62669000, 7.5],
  [49, 99, 3328269000, 13.5],
  [50, 99, 3927357000, 13.75],
  [100, 99, 19636785000, 26.25],
  [249, 99, 66450879000, 63.5],
];

const rebirthBlock = server.slice(server.indexOf("shared.PunchWallTryRebirth = function"), server.indexOf("rebirthDetector.MouseClick"));
const checks = [
  ["canonical_scaled_policy", config.includes('Version = "ScaledRebirthV1"') && config.includes("MaxRebirths = 250") && config.includes("StartingPower = 25") && config.includes("BaseLevel = 55") && config.includes("LevelStepEvery = 5") && config.includes("LevelStep = 5") && config.includes("MaxLevel = 99")],
  ["canonical_coin_curve", config.includes("BaseCoins = 1000000") && config.includes("CoinGrowth = 1.18") && config.includes("ExponentialSteps = 50") && config.includes("TailGrowth = 0.08") && config.includes("CoinRoundTo = 1000")],
  ["bounded_bonus_is_shared", config.includes("function GameConfig.RebirthBonus(rebirths)") && config.includes("function GameConfig.RebirthRequirement(rebirths)") && config.includes("* GameConfig.RebirthBonus(rebirths)") && server.includes("payload.RebirthBonus = GameConfig.RebirthBonus(payload.Rebirths)")],
  ["server_uses_canonical_requirements", rebirthBlock.includes("GameConfig.RebirthRequirement(currentRebirths)") && rebirthBlock.includes("currentLevel < requirement.requiredLevel") && rebirthBlock.includes("currentCoins < requirement.requiredCoins") && !rebirthBlock.includes("< 55") && !rebirthBlock.includes("< 1000000")],
  ["server_confirmation_and_stale_guard", rebirthBlock.includes("options.requireConfirmation == true") && rebirthBlock.includes("options.confirmed == true") && rebirthBlock.includes("expected ~= currentRebirths") && server.includes("requireConfirmation = true")],
  ["server_profile_reentry_and_cap_guards", rebirthBlock.includes("profileReady(player, not RunService:IsStudio())") && rebirthBlock.includes("requirement.maxed") && rebirthBlock.includes("rebirthRuntime.busy[player]") && rebirthBlock.includes("rebirthRuntime.cooldownSeconds")],
  ["honor_headroom_is_atomic", server.includes("function shared.PunchWallHonor.PendingMilestones") && server.includes('return 0, claimed, "honor_headroom"') && rebirthBlock.indexOf("currentHonor + pendingHonor") < rebirthBlock.indexOf('setStat(player, "Rebirths"')],
  ["reset_matrix_is_explicit", [
    'setStat(player, "Power", GameConfig.Rebirth.StartingPower)', 'setStat(player, "Coins", 0)', 'setStat(player, "WallLevel", 1)', 'setStat(player, "WallXP", 0)',
    'setStat(player, "FistMultiplier", 1)', 'setStat(player, "BreakSpeed", 1)', 'fist.Value = "Starter Glove"', 'setStat(player, "TrainingStationId", GameConfig.Training.DefaultStationId)',
  ].every((token) => rebirthBlock.includes(token)) && rebirthBlock.indexOf('stopTraining(player, "rebirth")') < rebirthBlock.indexOf('setStat(player, "Power"')],
  ["success_is_immediately_queued_for_save", rebirthBlock.includes('persistenceRuntime.requestPlayerSave(player, "Rebirth", false)') && persistence.includes("Rebirths = { default = 0, min = 0, integer = true }")],
  ["world_routes_preview_instead_of_mutating", server.includes('ActivationPolicy", "GlobalMenuConfirmed"') && server.includes('openRebirthMenu(player, "world_click")') && server.includes('openRebirthMenu(player, "contextual_use")')],
  ["client_locked_ready_review_confirm_states", client.includes('"RebirthWindow"') && client.includes('"WallLevelRequirement"') && client.includes('"CoinsRequirement"') && client.includes('"RebirthLocked"') && client.includes('"ReviewRebirth"') && client.includes('"CancelRebirth"') && client.includes('"ConfirmRebirth"') && client.includes("RebirthFirstActivationMutationGuard") && client.includes("PunchWallRebirthActionCallbacks") && client.includes('action == "InvokeRebirthAction"')],
  ["client_sends_only_confirmation_identity", client.includes('action = "Rebirth"') && client.includes("expectedRebirths = q.currentRebirths") && client.includes("policyVersion = q.policyVersion") && !client.includes("requiredCoins = q.currentCoins")],
  ["client_discloses_reset_and_keep_contract", client.includes('POWER 25 • COINS 0 • WALL LV 1') && client.includes('STARTER FIST • TRAINING STOPS') && client.includes('DEPTH • GEAR • PETS • HONOR • BOOSTS') && client.includes('ResetContract') && client.includes('RetainContract')],
  ["semantic_focus_defaults_safe", client.includes('Safe default: gamepad/keyboard lands on Cancel') && client.includes('focusButton = cancel') && client.includes('GuiService.SelectedObject = selectionInput') && client.includes('string.find(lastInput.Name, "Gamepad", 1, true) == 1')],
  ["mobile_rebirth_target_is_at_least_44", client.includes("CompactTouchGrid58x72QuestsJumpSafeV2") && client.includes('shared.PunchWallReferenceRebirth:SetAttribute("ToolAction", "OpenRebirthReview")') && client.includes('button:SetAttribute("MinimumTouchTarget", 44)')],
  ["runtime_exact_checkpoint_matrix", hasLabel("canonical scalable Rebirth checkpoints are exact and finite") && expected.every(([r, level, coins, bonus]) => flowText.includes(`{${r},${level},${coins},${bonus}}`))],
  ["runtime_bound_callbacks_confirmation_and_reset", hasLabel("standalone Rebirth route opens without legacy combined tabs") && hasLabel("review uses the bound Rebirth callback without mutation") && hasLabel("cancel uses the bound Rebirth callback") && hasLabel("confirm uses the bound Rebirth callback exactly once") && flowText.includes("InvokeRebirthAction") && flowText.includes("RebirthWindow")],
  ["runtime_retention_training_respawn_and_headroom", hasLabel("Rebirth resets the exact prestige fields and retains permanent progression") && hasLabel("stopped training cannot pay after Rebirth") && hasLabel("respawn retains authoritative Rebirth state and rebuilt UI") && hasLabel("insufficient Honor headroom rejects the whole Rebirth")],
  ["flow_is_strict_and_clean", flow.studioInstanceId === "6d29b2d4-41ab-41fb-838f-3dfd8727c725" && flow.studioName === "^PunchWallRPG_ManualPlaytest_20260818_FistAuraV10[.]rbxlx$" && hasLabel("boot console clean") && hasLabel("runtime console clean") && hasLabel("post-stop console clean") && !flowText.includes("Invoke('Rebirth')") && !flowText.includes(':ScaleTo(')],
];

for (const [name, passed] of checks) assert.equal(passed, true, name);
console.log(JSON.stringify({ ok: true, passed: checks.length, total: checks.length, checkpoints: expected.length, checks: Object.fromEntries(checks) }, null, 2));
