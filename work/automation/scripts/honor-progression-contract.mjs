import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "..", "..");
const read = (relative) => fs.readFileSync(path.join(root, relative), "utf8");
const config = read("punch-wall-rpg/src/shared/GameConfig.lua");
const profile = read("punch-wall-rpg/src/server/ProfilePersistence.lua");
const server = read("punch-wall-rpg/src/server/PunchWallBootstrap.server.lua");
const client = read("punch-wall-rpg/src/client/PunchWallClient.client.lua");
const inventory = read("punch-wall-rpg/src/shared/InventoryViewModel.lua");
const inventoryUi = read("punch-wall-rpg/src/client/InventoryUI.lua");
const flowText = read("automation/flows/honor-progression.json");
const flow = JSON.parse(flowText);

const results = {};
function check(name, condition, message) {
  results[name] = Boolean(condition);
  assert.equal(Boolean(condition), true, `${name}: ${message}`);
}
function block(source, start, end) {
  const a = source.indexOf(start);
  const b = source.indexOf(end, a + start.length);
  assert(a >= 0 && b > a, `missing source block ${start}`);
  return source.slice(a, b);
}

const expectedDepth = [
  [10, 2], [20, 3], [35, 5], [50, 8], [65, 12], [75, 20],
];
const expectedRebirth = [[1, 5], [5, 10], [10, 20], [25, 40], [50, 75]];
const expectedItems = [
  ["vanguard_trail", 20, "0.02", 10, 0],
  ["storm_hero_aura", 60, "0.03", 20, 0],
  ["relic_sidekick_core", 120, "0.04", 35, 0],
  ["crown_of_the_deep", 220, "0.05", 50, 0],
  ["titan_vanguard_trail", 360, "0.06", 65, 1],
  ["tempest_commander_aura", 540, "0.08", 75, 5],
  ["celestial_relic_core", 780, "0.10", 75, 10],
  ["eternal_crown_of_honor", 1100, "0.12", 75, 25],
];

check(
  "canonical_honor_policy_is_exact",
  config.includes('Version = "PrestigeHonorV1"')
    && config.includes("WorldClearBase = 5")
    && config.includes("FirstDailyClearBonus = 7")
    && config.includes("MaxWorldClearsPerDay = 3")
    && config.includes("MinimumBossContribution = 0.01")
    && config.includes("MinimumClearIntervalSeconds = 300")
    && config.includes("MaxEquippedPowerBonus = 0.12"),
  "Honor recurring policy must remain the reviewed 12/5/5 daily model.",
);
check(
  "depth_milestones_are_exact",
  expectedDepth.every(([depth, honor]) => config.includes(`{ depth = ${depth}, honor = ${honor} }`)),
  "All six exact lifetime Depth milestone rewards are required.",
);
check(
  "rebirth_milestones_are_exact",
  expectedRebirth.every(([rebirths, honor]) => config.includes(`{ rebirths = ${rebirths}, honor = ${honor} }`)),
  "All five exact lifetime Rebirth milestone rewards are required.",
);
check(
  "relic_catalog_is_long_play_and_stable_id_based",
  expectedItems.every(([id, cost, bonus, depth, rebirths]) => {
    const row = new RegExp(`id = "${id}"[^\\n]*cost = ${cost}[^\\n]*powerBonus = ${bonus}[^\\n]*requiredDepth = ${depth}[^\\n]*requiredRebirths = ${rebirths}`);
    return row.test(config);
  }) && (config.match(/\{ id = "[a-z_]+", name = "[^"]+", displayName = "[^"]+", rarity =/g) ?? []).length === 8,
  "Eight reviewed relics need unique stable ids, costs, bonuses, and unlock gates.",
);
const spinBlock = block(config, "GameConfig.Spin = {", "GameConfig.DepthWall = {");
check(
  "spin_cannot_award_honor",
  !spinBlock.includes('kind = "Honor"') && !spinBlock.includes("HONOR"),
  "Standard and paid Spin chains must not bypass prestige progression.",
);
check(
  "honor_gain_is_server_clamped",
  server.includes("function shared.PunchWallHonor.Grant")
    && server.includes("ProfilePersistence.MaxAuthoritativeNumber, before + requested")
    && server.includes('setStat(player, "Honor", after)'),
  "Every Honor grant must clamp before mutating the authoritative value.",
);
check(
  "milestones_commit_claim_before_currency",
  server.indexOf('setStat(player, maskStat, mask)') < server.indexOf("shared.PunchWallHonor.Grant(player, total")
    && server.includes("shared.PunchWallHonor.ClaimDepthMilestones(contributor, layer)")
    && server.includes("shared.PunchWallHonor.ClaimRebirthMilestones"),
  "Milestone masks must be committed synchronously before the grant.",
);
const clearBlock = block(server, "function shared.PunchWallHonor.ClaimQualifiedWorldClear", "local function effectivePower");
check(
  "world_clear_uses_real_cycle_contribution_daily_cap_and_cooldown",
  clearBlock.includes('root:GetAttribute("WorldResetCount")')
    && clearBlock.includes("game.JobId")
    && clearBlock.includes("MinimumBossContribution")
    && clearBlock.includes("MinimumClearIntervalSeconds")
    && clearBlock.includes("MaxWorldClearsPerDay")
    && clearBlock.includes('setStat(player, "LastHonorClearId", clearId)')
    && clearBlock.includes("MilestoneClaimed")
    && clearBlock.includes('return 0, "depth_milestone_gate"')
    && server.includes("depthBeforeBossReward >= GameConfig.WorldProgressTarget")
    && server.includes("depthBeforeBossReward < 76")
    && server.includes("claimQualifiedWorldHonor") === false,
  "Titan rewards must use actual reset identity and qualified server contribution, not time buckets or one Depth block.",
);
check(
  "legacy_v6_honor_bonus_migrates_before_v7_validation",
  profile.includes("currentVersion >= 7 and sourceVersion < 7")
    && profile.includes("profile.HonorPowerBonus = 0")
    && profile.includes("HonorPowerBonus = 0.25")
    && profile.includes('assert(migrated.HonorPowerBonus == 0'),
  "Previously valid .15/.25 derived bonuses must not make v6 profiles fail v7 migration.",
);
const buyBlock = block(server, "shared.PunchWallBuyHonorItem = function", "shared.PunchWallBuildHonorPlaza = function");
check(
  "purchase_is_authoritative_locked_and_idempotent",
  buyBlock.includes("profileReady(player, false)")
    && buyBlock.includes("GameConfig.HonorItemUnlocked")
    && buyBlock.includes("ownedSet[item.id]")
    && buyBlock.includes('setStat(player, "EquippedHonorItem", item.id)')
    && buyBlock.includes("MaxEquippedPowerBonus")
    && !buyBlock.includes("item.cost =")
    && !buyBlock.includes("item.powerBonus ="),
  "Server catalog must own unlock, cost, ownership, replay, and bonus decisions.",
);
check(
  "profile_schema_persists_all_honor_claim_state",
  [
    "HonorMilestoneMask", "HonorRebirthMilestoneMask", "HonorClearsToday", "LastHonorClearAt",
    "HonorClearDate", "LastHonorClearId", "OwnedHonorItemsJSON", "EquippedHonorItem",
  ].every((field) => profile.includes(`${field} = {`))
    && /HonorPowerBonus\s*=\s*\{[^}]*max\s*=\s*0\.12/.test(profile),
  "Lifetime, daily, cycle, ownership, equip, and derived bonus state must be bounded and persisted.",
);
check(
  "profile_load_canonicalizes_owned_and_equipped_relics",
  server.includes("normalizedHonorOwned")
    && server.includes("normalizedHonorSet[definition.id]")
    && server.includes('stats.EquippedHonorItem.Value = "None"')
    && server.includes("not normalizedHonorSet[honorDefinition.id]")
    && server.includes("GameConfig.Honor.MaxEquippedPowerBonus"),
  "Unknown/duplicate ownership and unowned equipped bonuses must fail closed during load.",
);
check(
  "client_honor_journey_and_states_are_truthful",
  client.includes("ONE RELIC ACTIVE")
    && client.includes("HERO SPIN DOES NOT AWARD HONOR")
    && client.includes('button:SetAttribute("HonorItemId", item.id)')
    && client.includes('button:SetAttribute("HonorState"')
    && client.includes("NEED %s")
    && client.includes('target = item.id'),
  "Honor UI must state all earning rules and expose locked/shortfall/owned/equipped states.",
);
check(
  "honor_hud_and_world_displays_open_canonical_preview_without_spending",
  client.includes('honorOpen.Name = "OpenHonorMenu"')
    && client.includes('openGameTab("Honor")')
    && server.includes('selected = item.id')
    && server.includes('type = "OpenMenu", target = "Honor"')
    && client.includes("local definition = GameConfig.HonorItemDefinition(tostring(payload.selected))")
    && client.includes('local selectedId = definition and tostring(definition.id) or ""')
    && client.includes('shared.PunchWallSelectedHonorItemId = selectedId')
    && client.includes('gui:SetAttribute("RequestedHonorItemId", selectedId)')
    && client.includes('shared.PunchWallOpenInventoryHonorItem(selectedId, "world_relic")')
    && inventoryUi.includes('self.Root:SetAttribute("InventoryHonorSelectionContractVersion", "HonorInventoryWorldSelectionV1")')
    && inventoryUi.includes('self.Root:SetAttribute("InventoryHonorSelectedId"')
    && inventoryUi.includes('self.Root:SetAttribute("InventoryHonorCatalogCount"')
    && inventoryUi.includes('self.Root:SetAttribute("InventoryHonorVisibleCount"')
    && inventoryUi.includes('self.Root:SetAttribute("InventoryHonorCanvasY"')
    && inventoryUi.includes('self.Root:SetAttribute("InventoryHonorSelectionInView"')
    && inventoryUi.includes('self.Root:SetAttribute("InventoryHonorSelectionFocused"')
    && inventoryUi.includes('card:SetAttribute("InventoryWorldSelection"')
    && !block(server, "detector.MouseClick:Connect(function(player)", "shared.PunchWallBuildHonorPlaza = nil").includes("shared.PunchWallBuyHonorItem(player, item)"),
  "Honor HUD and world stands must preview the exact relic through canonical UI; only explicit UI unlock may spend.",
);
check(
  "inventory_uses_stable_honor_ids",
  inventory.includes("owned[definition.id] == true or owned[definition.name] == true")
    && inventory.includes('key = "honor:" .. definition.id')
    && inventory.includes('target = definition.id')
    && inventoryUi.includes('card:SetAttribute("HonorItemId"')
    && inventoryUi.includes('card:SetAttribute("HonorState"')
    && inventoryUi.includes('card:SetAttribute("HonorOwned"')
    && inventoryUi.includes('card:SetAttribute("HonorUnlocked"')
    && inventoryUi.includes('card:SetAttribute("HonorAffordable"')
    && inventoryUi.includes('card:SetAttribute("HonorEquipped"')
    && inventoryUi.includes('card:SetAttribute("HonorCost"')
    && inventoryUi.includes('card:SetAttribute("HonorMissing"'),
  "Inventory ownership, action, and identity need stable ids with legacy migration compatibility.",
);
check(
  "reduced_motion_keeps_static_relic_identity",
  client.includes('model:SetAttribute("MotionSuppressed"')
    && client.includes('trail.Enabled = clientSettings.motion == true')
    && client.includes('emitter.Enabled = clientSettings.motion == true')
    && client.includes('badge.Name = "Static Trail Badge"')
    && client.includes('core.Name = "Static Storm Core"')
    && client.includes("shared.PunchWallRefreshHonorMotion"),
  "Honor effects must stop under Reduced Motion without removing item identity.",
);
check(
  "runtime_flow_is_exact_place_and_fail_closed",
  flow.studioInstanceId === "6d29b2d4-41ab-41fb-838f-3dfd8727c725"
    && flow.studioName === "^PunchWallRPG_ManualPlaytest_20260818_FistAuraV10[.]rbxlx$"
    && flow.steps.length === 40
    && flowText.includes("final.Honor==50")
    && flowText.includes("final.HonorRebirthMilestoneMask==31")
    && flowText.includes("s1.Honor==12")
    && flowText.includes("s4.Honor==22")
    && flowText.includes("duplicate.reason=='duplicate_clear'")
    && flowText.includes("s1.Depth==30 and s2.Depth==30")
    && flowText.includes("s1.Honor==0 and s2.Honor==0")
    && !flowText.includes("or true"),
  "Runtime must hard-code exact reviewed values and reject replay without permissive assertions.",
);
check(
  "runtime_flow_covers_real_ui_purchase_and_respawn",
  flowText.includes('"tool": "user_mouse_input"')
    && flowText.includes("OpenHonorMenu")
    && flowText.includes("Actionequip")
    && flowText.includes("ItemCard_honor_vanguard_trail")
    && flowText.includes("HonorState')=='Insufficient")
    && flowText.includes("HonorState')=='Locked'")
    && flowText.includes("ActionRequest")
    && flowText.includes("client_forged_relic")
    && flowText.includes("SelectedHonorItemId")
    && flowText.includes("eternal_crown_of_honor")
    && flowText.includes("FunctionalInventory")
    && flowText.includes("HonorInventoryWorldSelectionV1")
    && flowText.includes("ItemCard_honor_eternal_crown_of_honor")
    && flowText.includes("InventorySelectedKey')==key")
    && flowText.includes("InventoryHonorCatalogCount')==8")
    && flowText.includes("InventoryHonorVisibleCount')==8")
    && flowText.includes("InventoryHonorSelectionInView')==true")
    && flowText.includes("InventoryHonorSelectionFocused')==false")
    && flowText.includes("InventorySearch')==''")
    && flowText.includes("InventoryRarity')=='All'")
    && flowText.includes("card:GetAttribute('HonorState')=='Insufficient'")
    && flowText.includes("card:GetAttribute('HonorUnlocked')==true")
    && flowText.includes("card:GetAttribute('HonorCost')==1100")
    && flowText.includes("card:GetAttribute('HonorMissing')==1100")
    && flowText.includes("grid.CanvasPosition.Y==0")
    && flowText.includes("rootCanvas==grid.CanvasPosition.Y")
    && flowText.includes("screenCanvas==rootCanvas")
    && flowText.includes("PunchWall Honor Flow Desktop 1366x768")
    && flowText.includes("Static Trail Badge")
    && flowText.includes("Invoke('Respawn')")
    && flowText.includes("s.OwnedHonorItemsJSON")
    && flowText.includes("s.HonorPowerBonus==.02"),
  "Balanced real mouse input must prove shortfall, purchase, exact Inventory Honor world selection/scroll, cosmetic, motion, and respawn.",
);
check(
  "runtime_flow_checks_console_lifecycle",
  flow.steps.some((step) => step.label === "runtime console clean")
    && flow.steps.some((step) => step.label === "post-stop console clean")
    && flow.steps.some((step) => step.label === "restore default viewport after Honor flow")
    && flow.cleanup.some((step) => step.label === "cleanup stop play")
    && flow.cleanup.some((step) => step.label === "cleanup Honor flow viewport"),
  "Honor certification requires runtime and post-stop console checks plus cleanup.",
);

console.log(JSON.stringify({
  ok: true,
  passed: Object.values(results).filter(Boolean).length,
  total: Object.keys(results).length,
  depthMilestones: expectedDepth.length,
  rebirthMilestones: expectedRebirth.length,
  relics: expectedItems.length,
  checks: results,
}, null, 2));
