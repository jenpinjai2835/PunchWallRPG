import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";

const root = path.resolve(import.meta.dirname, "..", "..");
const read = (...parts) => fs.readFileSync(path.join(root, ...parts), "utf8");
const server = read("punch-wall-rpg", "src", "server", "PunchWallBootstrap.server.lua");
const client = read("punch-wall-rpg", "src", "client", "PunchWallClient.client.lua");
const inventory = read("punch-wall-rpg", "src", "client", "InventoryUI.lua");
const config = read("punch-wall-rpg", "src", "shared", "GameConfig.lua");
const polish = read("punch-wall-rpg", "src", "shared", "PolishConfig.lua");
const petFlow = read("automation", "flows", "creator-store-pet-pack-visuals.json");
const recoveryFlow = read("automation", "flows", "training-ui-pet-recovery.json");
const captureScript = read("automation", "scripts", "capture-training-ui-pet-recovery.mjs");
const finalArtifact = read("..", "outputs", "PunchWallRPGPlayable_v1_final.rbxlx");

const templates = [
  ["Sanitized_ForestPupPet", "Dowodle"],
  ["Sanitized_MinerCatPet", "Catmouse"],
  ["Sanitized_CrystalFoxPet", "Ocelot"],
  ["Sanitized_LavaDragonPet", "Mythic Autumn Dragon"],
  ["Sanitized_SecretTitanGolemPet", "Dark Guardian"],
  ["Sanitized_CrimsonPhoenixPet", "Enraged Phoenix"],
  ["Sanitized_StormWyvernPet", "Electra Hydra"],
  ["Sanitized_CelestialGuardianPet", "Mythic Radiant One"],
];

const checks = [
  ["selected_training_station_validates_its_own_range", server.includes("requested.part and requested.part.Parent") && server.includes("requestedDistance <= TRAINING_INTERACTION_DISTANCE") && server.includes("config = requested") && !server.includes("if requested and requested ~= config then config = nil end")],
  ["training_unlock_uses_authoritative_base_power", server.includes('local power = statValue(player, "Power", 0)') && server.includes("if power < config.minPower then") && !server.slice(server.indexOf("local function trainPlayer"), server.indexOf("stopTraining = function")).includes("EffectivePower")],
  ["context_scan_only_compares_actionable_targets", client.includes("local nearestTraining") && client.includes("local nearestUse") && client.includes("clientRuntime.IsTrainingTarget(candidate)") && client.includes("clientRuntime.IsUseTarget(candidate)") && client.includes("nearestTrainingDistance <= nearestUseDistance + 5")],
  ["context_action_is_compact_two_line", client.includes('Name = "ActionTitle"') && client.includes('Name = "ActionDetail"') && client.includes('"PresentationVersion", "TwoLineCompactV2"') && client.includes("contextActionSize.MinSize = Vector2.new(196, 52)") && client.includes('"PhoneTwoLineCenterLane56V4"')],
  ["context_action_uses_dark_readable_panel", client.includes("button.BackgroundColor3 = Color3.fromRGB(10, 23, 31)") && client.includes("actionTitle.TextColor3 = actionAccent") && client.includes("contextActionDetail.TextColor3 = Color3.fromRGB(225, 240, 246)")],
  ["context_action_preserves_exact_station_identity", client.includes('button:SetAttribute("Target", targetName)') && client.includes('target = gui:GetAttribute("ContextualActionTarget")') && client.includes('"InvokeContextualAction"') && client.includes("requestAction(contextualAction)")],
  ["contextual_use_is_active_without_training_eligibility", client.includes('button.Active = button.Visible and (actionName ~= "Train" or trainingEligible)') && recoveryFlow.includes("nearest real non-training contextual Use stays active and follows the production path") && recoveryFlow.includes("result.detail==string.upper(result.target)")],
  ["inventory_compact_cards_reserve_art_from_tags", inventory.includes('"InventoryCompactCardContentVersion"') && inventory.includes('"StatusRailV4"') && inventory.includes("cardRef.artFrame.Position = UDim2.fromOffset(4, 19)") && inventory.includes("cardRef.rarity.Size = UDim2.new(0.5, -6, 0, 12)") && inventory.includes("cardRef.equipped.Size = UDim2.new(0.48, -4, 0, 12)")],
  ["inventory_compact_typography_is_bounded", inventory.includes("self.Search.TextSize = useCompact and 8 or 13") && inventory.includes("self.TitleTextLimit.MaxTextSize = useCompact and 17 or 40") && inventory.includes("cardRef.rarity.TextSize = useCompact and 6 or 10")],
  ["robux_prices_use_non_coin_palette", client.includes("Color3.fromRGB(105, 242, 169)") && client.includes('"RobuxGreen"') && client.includes('"CoinGold"') && client.includes('priceLabel:SetAttribute("CurrencyPalette"')],
  ["unsupported_rigs_use_equipped_fist_strike", client.includes("function companionRuntime.PerformTrainingFistStrike(target)") && client.includes('echo.Name = "Training Equipped Fist Strike"') && client.includes('"TrainingFistStrikeFallback"') && client.includes('tostring(latestStats.EquippedFist or "Starter Glove")')],
  ["fallback_is_visual_only_bounded_and_cleaned", client.includes("descendant.Anchored = true") && client.includes("descendant.CanCollide = false") && client.includes("math.min(descendant.Rate, 8)") && client.includes("if echo.Parent then echo:Destroy() end")],
  ["training_loop_uses_fallback_only_without_character_animation", client.includes("local characterAnimated = performPunchAnimation()") && client.includes("if not characterAnimated then") && client.includes("companionRuntime.PerformTrainingFistStrike(target)") && client.includes('"TrainingCharacterAnimationApplied"')],
  ["pet_pack_policy_has_exact_eight_preloaded_templates", templates.every(([template, source]) => polish.includes(`templateName = "${template}"`) && polish.includes(`sourceModel = "${source}"`) && polish.includes("preloadedOnly = true")) && (polish.match(/preloadedOnly = true/g) ?? []).length === 8],
  ["pet_release_gate_requires_all_eight_sanitized_templates", server.includes('"PetVisualReadyTemplateCount"') && server.includes('"PetVisualReleasePolicy", "ExactEightPreloadedSanitizedV2"') && server.includes('"PetVisualReleaseReady"') && server.includes("readyPetTemplateCount == 8") && server.includes("rejectedTemplateCount == 0")],
  ["pet_runtime_flow_checks_real_templates_and_no_unsafe_descendants", templates.every(([template, source]) => petFlow.includes(template) && petFlow.includes(source)) && petFlow.includes("found==8") && petFlow.includes("unsafe==0") && petFlow.includes("PetPackTemplateCount")],
  ["final_artifact_contains_all_eight_pet_models", templates.every(([template, source]) => finalArtifact.includes(template) && finalArtifact.includes(source))],
  ["all_pet_definitions_reference_preloaded_template_families", templates.every(([template, source]) => config.includes(`templateName = "${template}"`) && config.includes(`packModel = "${source}"`))],
  ["focused_flow_is_exact_and_covers_runtime_lifecycle", recoveryFlow.includes('"studioInstanceId": "8e0ad201-e63b-44d9-b20c-38e9957106e0"') && recoveryFlow.includes("below-threshold request never starts or switches training") && recoveryFlow.includes("unsupported avatar visibly strikes with the equipped fist") && recoveryFlow.includes("compact Inventory shows all pet art without tag overlap") && recoveryFlow.includes("premium Shop uses green Robux pricing and real pet previews") && recoveryFlow.includes("runtime console clean") && recoveryFlow.includes("post-stop console clean") && recoveryFlow.includes("restore simulator default")],
  ["capture_bundle_is_source_bound_and_has_four_distinct_views", captureScript.includes('"01_iphone17_training_action"') && captureScript.includes('"02_iphone17_inventory_pets"') && captureScript.includes('"03_iphone17_shop_premium"') && captureScript.includes('"04_iphone17_premium_companions"') && captureScript.includes('"work/automation/flows/training-ui-pet-recovery.json"') && captureScript.includes('"work/automation/scripts/training-ui-pet-recovery-contract.mjs"') && captureScript.includes("summary.runtimeSources") && captureScript.includes("summary.cleanup")],
];

for (const [name, passed] of checks) assert.equal(passed, true, name);

console.log(JSON.stringify({
  ok: true,
  passed: checks.length,
  total: checks.length,
  petTemplates: templates.length,
  checks: Object.fromEntries(checks),
}, null, 2));
