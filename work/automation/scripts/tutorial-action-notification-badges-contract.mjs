import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";

const root = path.resolve(import.meta.dirname, "..", "..");
const read = (...parts) => fs.readFileSync(path.join(root, ...parts), "utf8").replace(/\r\n/g, "\n");
const config = read("punch-wall-rpg", "src", "shared", "GameConfig.lua");
const persistence = read("punch-wall-rpg", "src", "server", "ProfilePersistence.lua");
const server = read("punch-wall-rpg", "src", "server", "PunchWallBootstrap.server.lua");
const client = read("punch-wall-rpg", "src", "client", "PunchWallClient.client.lua");
const flowText = read("automation", "flows", "tutorial-action-notification-badges.json");
const flow = JSON.parse(flowText);
const hasLabel = (label) => flow.steps.some((step) => step.label === label);
const hasCleanupLabel = (label) => (flow.cleanup || []).some((step) => step.label === label);

const checks = [
  ["data_version_and_tutorial_policy_are_current", config.includes("GameConfig.DataVersion = 8") && config.includes("GameConfig.TutorialVersion = 2") && config.includes("GameConfig.TutorialCompleteStep = 4")],
  ["tutorial_is_short_action_led_journey", config.includes('id = "PunchWall"') && config.includes('target = "Depth Course Entrance"') && config.includes('id = "OpenShop"') && config.includes('id = "BuyStarterFist"') && config.includes('Buy the Street Boxing Fist for 180 Coins')],
  ["legacy_long_tutorial_removed", !config.includes('title = "Train Power"') && !config.includes('title = "Reach Titan HQ"') && !config.includes('title = "Rebirth", detail')],
  ["completion_is_persisted_separately", persistence.includes('ProfilePersistence.ContractVersion = "2.3.0"') && persistence.includes("TutorialVersion = { default = 2") && persistence.includes("TutorialCompleted = { default = 0, min = 0, max = 1") && server.includes('"TutorialVersion"') && server.includes('"TutorialCompleted"')],
  ["legacy_migration_preserves_only_true_completers", persistence.includes("local legacyCompleted = legacyStep >= 8") && persistence.includes("profile.TutorialCompleted = legacyCompleted and 1 or 0") && persistence.includes("profile.TutorialStep = legacyCompleted and 4 or 1") && persistence.includes("completed legacy tutorial was not preserved during v8 migration") && persistence.includes("unfinished legacy tutorial was not restarted safely during v8 migration")],
  ["server_sends_authoritative_tutorial_state", server.includes("payload.TutorialCompleted = tutorialCompleted") && server.includes("payload.TutorialVersion = GameConfig.TutorialVersion") && server.includes("payload.TutorialProgress")],
  ["server_progresses_only_named_real_actions", server.includes('actionId == "PunchWall"') && server.includes('actionId == "OpenShop"') && server.includes('actionId == "BuyStarterFist"') && !server.includes("advanceTutorial")],
  ["punch_routes_are_hooked", (server.match(/completeTutorialAction\(player, "PunchWall"\)/g) || []).length === 2],
  ["shop_open_and_exact_fist_purchase_are_hooked", server.includes('action == "TutorialShopOpened"') && server.includes('completeTutorialAction(player, "OpenShop")') && server.includes('item.name == "Boxing Glove"') && server.includes('completeTutorialAction(player, "BuyStarterFist")')],
  ["completion_is_saved_immediately", server.includes('requestPlayerSave(player, "TutorialComplete", false)') && server.includes('type = "TutorialComplete"')],
  ["completed_or_already_owned_players_never_reopen", server.includes('stats.TutorialCompleted.Value >= 1 or (decodedOwnedFists and table.find(decodedOwnedFists, "Boxing Glove"))') && client.includes("payload.TutorialCompleted ~= true") && client.includes('gui:SetAttribute("OnboardingTutorialCompleted"')],
  ["shop_ui_reports_open_step", client.includes('actionRemote:FireServer({ action = "TutorialShopOpened" })') && client.includes('gui:GetAttribute("TutorialShopSignalStep")')],
  ["red_dot_is_reusable_and_nonblocking", client.includes('"NotificationDot"') && client.includes('BackgroundColor3 = Color3.fromRGB(239, 42, 48)') && client.includes('stroke.Color = Color3.fromRGB(255, 255, 255)') && client.includes("badge.Active = false")],
  ["pet_dot_uses_exact_unlocked_fusion_policy", client.includes("GameConfig.PetFusionRequirement(stars)") && client.includes('not lockedPets[token] and not lockedPets["slot:"') && client.includes('setActionBadge("Pets", petFuseCount, "PetFusionReady")')],
  ["spin_dot_uses_credit_or_cooldown", client.includes("latestStats.SpinCredits") && client.includes("latestStats.SpinReadyAt") && client.includes('setActionBadge("Spin", spinReady and 1 or 0, "SpinReady")')],
  ["shop_dot_excludes_robux_and_consumables", client.includes("for _, fist in ipairs(GameConfig.Fists or {})") && client.includes("cost > 0 and not ownedFists[fist.name]") && client.includes("coins >= cost and depth >= requiredDepth") && client.includes('setActionBadge("Shop", affordableFists, "AffordableFist")')],
  ["daily_dot_uses_claimable_actions", client.includes("latestStats.LastDailyDate") && client.includes("latestStats.DailyQuestClaimed") && client.includes("latestStats.PlaytimeClaimed") && client.includes('setActionBadge("Daily", dailyActionCount, "RewardClaimable")')],
  ["dots_follow_action_state_not_dismissal", client.includes('entry.dot.Visible = count > 0') && client.includes('button:SetAttribute("NotificationActionCount", 0)') && !client.includes("NotificationDismissed")],
  ["runtime_flow_uses_exact_studio_and_production_actions", flow.studioInstanceId === "6d29b2d4-41ab-41fb-838f-3dfd8727c725" && flow.studioName === "^PunchWallRPG_ManualPlaytest_20260818_FistAuraV10[.]rbxlx$" && flowText.includes("ActionRequest:FireServer") && !flowText.includes("Invoke('BuyFist'") && !flowText.includes("Invoke('FusePet'")],
  ["runtime_flow_covers_tutorial_persistence", hasLabel("fresh profile starts punch-first tutorial") && hasLabel("server accepts one successful punch outcome") && hasLabel("tutorial completion persists and legacy completion migrates once")],
  ["runtime_flow_covers_all_badge_transitions", hasLabel("pet icon dot appears only when an unlocked fusion is possible") && hasLabel("pet dot clears after the fusion action is exhausted") && hasLabel("spin and claimable quest dots appear on their exact icons") && hasLabel("all dots and tutorial disappear when no action remains")],
  ["runtime_flow_has_clean_lifecycle", hasLabel("tutorial badge boot console clean") && hasLabel("tutorial badge runtime console clean") && hasLabel("tutorial badge post-stop console clean") && hasCleanupLabel("cleanup tutorial badge playtest")],
];

for (const [name, passed] of checks) assert.equal(passed, true, name);
console.log(JSON.stringify({ ok: true, passed: checks.length, total: checks.length, checks: Object.fromEntries(checks) }, null, 2));
