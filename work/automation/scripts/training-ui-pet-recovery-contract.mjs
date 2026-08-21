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

const packTemplates = [
  ["Sanitized_ForestPupPet", "Dowodle", "Forest Pup"],
  ["Sanitized_MinerCatPet", "Catmouse", "Miner Cat"],
  ["Sanitized_CrystalFoxPet", "Ocelot", "Crystal Fox"],
  ["Sanitized_LavaDragonPet", "Mythic Autumn Dragon", "Lava Dragon"],
  ["Sanitized_SecretTitanGolemPet", "Dark Guardian", "Secret Titan Golem"],
  ["Sanitized_EnragedPhoenixPet", "Enraged Phoenix", "Thunder Roc"],
  ["Sanitized_ElectraHydraPet", "Electra Hydra", "Frost Hydra"],
  ["Sanitized_MythicRadiantOnePet", "Mythic Radiant One", "Solar Kirin"],
];
const premiumTemplates = [
  ["Sanitized_CrimsonPhoenixPet", "Crimson Phoenix", "86478691482535"],
  ["Sanitized_StormWyvernPet", "Storm Wyvern", "83562531232957"],
  ["Sanitized_CelestialGuardianPet", "Celestial Guardian", "121956330907081"],
];

const checks = [
  ["selected_training_station_validates_its_own_range", server.includes("requested.part and requested.part.Parent") && server.includes("requestedDistance <= TRAINING_INTERACTION_DISTANCE") && server.includes("config = requested") && !server.includes("if requested and requested ~= config then config = nil end")],
  ["training_unlock_uses_displayed_effective_power", server.includes("local function trainingQualificationPower(player)") && server.includes("return GameConfig.EffectivePower(") && server.includes("if qualificationPower < config.minPower then") && client.includes("latestStats.TrainingQualificationPower")],
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
  ["pet_pack_policy_has_exact_eight_preloaded_templates", packTemplates.every(([template, source, definition]) => polish.includes(`templateName = "${template}"`) && polish.includes(`sourceModel = "${source}"`) && polish.includes(`petDefinitionName = "${definition}"`)) && (polish.match(/preloadedOnly = true/g) ?? []).length === 8],
  ["premium_policy_restores_three_original_detailed_assets", premiumTemplates.every(([template, definition, asset]) => polish.includes(`templateName = "${template}"`) && polish.includes(`assetId = ${asset}`) && polish.includes(`petDefinitionName = "${definition}"`))],
  ["invisible_pet_rig_helpers_do_not_distort_visual_bounds", client.includes("function companionRuntime.NormalizeInvisibleRigBounds(model)") && client.includes('descendant.Name == "HumanoidRootPart"') && client.includes("companionRuntime.NormalizeInvisibleRigBounds(model)")],
  ["wide_wyvern_preview_prioritizes_creature_identity", client.includes('item.name == "Storm Wyvern" and 0.48') && client.includes('PreviewFitPadding')],
  ["pet_release_gate_requires_eight_pack_plus_three_premium_templates", server.includes('"PetVisualReadyTemplateCount"') && server.includes('"PetVisualRequiredTemplateCount"') && server.includes('"PetVisualReleasePolicy", "EightPackPlusThreeDetailedPremiumV3"') && server.includes("petTemplatePolicyCount == 11") && server.includes("readyPetTemplateCount == petTemplatePolicyCount") && server.includes("rejectedTemplateCount == 0")],
  ["pet_runtime_flow_checks_real_templates_and_no_unsafe_descendants", [...packTemplates, ...premiumTemplates].every(([template]) => petFlow.includes(template)) && petFlow.includes("found==11") && petFlow.includes("unsafe==0") && petFlow.includes("PetPackTemplateCount")],
  ["final_artifact_contains_all_eleven_pet_models", [...packTemplates, ...premiumTemplates].every(([template]) => finalArtifact.includes(template))],
  ["all_pet_definitions_reference_correct_template_families", packTemplates.every(([template, source, definition]) => config.includes(`name = "${definition}"`) && config.includes(`templateName = "${template}"`) && config.includes(`packModel = "${source}"`)) && premiumTemplates.every(([template, definition]) => config.includes(`name = "${definition}"`) && config.includes(`templateName = "${template}"`))],
  ["focused_flow_is_exact_and_covers_runtime_lifecycle", /"studioInstanceId": "[0-9a-f-]{36}"/.test(recoveryFlow) && recoveryFlow.includes("PunchWallRPGPlayable_v1_candidate_training_pets") && recoveryFlow.includes("PunchWallRPGPlayable_v1_final") && recoveryFlow.includes("below-threshold request never starts or switches training") && recoveryFlow.includes("reproduce public case where displayed effective Power exceeds Iron threshold") && recoveryFlow.includes("unsupported avatar visibly strikes with the equipped fist") && recoveryFlow.includes("compact Inventory shows all pet art without tag overlap") && recoveryFlow.includes("premium Shop uses green Robux pricing and original detailed pet previews") && recoveryFlow.includes("runtime console clean") && recoveryFlow.includes("post-stop console clean") && recoveryFlow.includes("restore simulator default")],
  ["capture_bundle_is_source_bound_and_has_four_distinct_views", captureScript.includes('"01_iphone17_training_action"') && captureScript.includes('"02_iphone17_inventory_pets"') && captureScript.includes('"03_iphone17_shop_premium"') && captureScript.includes('"04_iphone17_premium_companions"') && captureScript.includes('"work/automation/flows/training-ui-pet-recovery.json"') && captureScript.includes('"work/automation/scripts/training-ui-pet-recovery-contract.mjs"') && captureScript.includes("summary.runtimeSources") && captureScript.includes("summary.cleanup")],
];

for (const [name, passed] of checks) assert.equal(passed, true, name);

console.log(JSON.stringify({
  ok: true,
  passed: checks.length,
  total: checks.length,
  petTemplates: packTemplates.length + premiumTemplates.length,
  checks: Object.fromEntries(checks),
}, null, 2));
