import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const clientPath = path.join(
  root,
  "work",
  "punch-wall-rpg",
  "src",
  "client",
  "PunchWallClient.client.lua",
);
const serverPath = path.join(
  root,
  "work",
  "punch-wall-rpg",
  "src",
  "server",
  "PunchWallBootstrap.server.lua",
);
const configPath = path.join(
  root,
  "work",
  "punch-wall-rpg",
  "src",
  "shared",
  "GameConfig.lua",
);
const flowPath = path.join(
  root,
  "work",
  "automation",
  "flows",
  "product-completeness-purchase-availability.json",
);
const developerProductFlowPath = path.join(
  root,
  "work",
  "automation",
  "flows",
  "developer-product-configuration.json",
);
const client = fs.readFileSync(clientPath, "utf8");
const server = fs.readFileSync(serverPath, "utf8");
const config = fs.readFileSync(configPath, "utf8");
const flow = JSON.parse(fs.readFileSync(flowPath, "utf8"));
const developerProductFlow = JSON.parse(fs.readFileSync(developerProductFlowPath, "utf8"));
const developerProductFlowSource = JSON.stringify(developerProductFlow);
const flowLuau = flow.steps
  .filter((step) => step.tool === "execute_luau")
  .map((step) => step.args?.code ?? "")
  .join("\n");
const livePremiumFistMetadataFlowLuau = flow.steps.find(
  (step) => step.saveAs === "livePremiumFistMetadata",
)?.args?.code ?? "";
const clientAvailabilityFlowLuau = flow.steps.find(
  (step) => step.saveAs === "clientAvailability",
)?.args?.code ?? "";
const mobileActionCooldownMatch = server.match(
  /local MOBILE_ACTION_COOLDOWN\s*=\s*([0-9.]+)/,
);
const mobileActionCooldownSeconds = Number(mobileActionCooldownMatch?.[1]);
const includesAll = (source, needles) => needles.every((needle) => source.includes(needle));
const section = (source, start, end) => {
  const startIndex = source.indexOf(start);
  const endIndex = source.indexOf(end, startIndex + start.length);
  return startIndex >= 0 && endIndex > startIndex
    ? source.slice(startIndex, endIndex)
    : "";
};
const fistPrompt = section(
  server,
  "shared.PunchWallPremiumFists.prompt = function",
  "MarketplaceService.PromptGamePassPurchaseFinished:Connect",
);
const productPrompt = section(
  server,
  "shared.PunchWallPremiumProducts.prompt = function",
  "local function requireSafeProfileReload",
);
const petPrompt = section(
  server,
  "shared.PunchWallPremiumPets.prompt = function",
  "MarketplaceService.PromptGamePassPurchaseFinished:Connect",
);
const automationCommands = section(
  server,
  "local serverCommandNames = {",
  "local oldHarness =",
);
const functionalShopAvailability = section(
  client,
  "local purchaseConfigured = true",
  "addStroke(card",
);

const checks = {
  premium_fist_catalog_matches_creator_dashboard: includesAll(config, [
    'name = "Crimson Vanguard Fist", displayName = "Crimson Vanguard", tier = 6, style = "Vanguard", icon = "CrimsonVanguardFist", robux = 49, gamePassId = 1947838143',
    'name = "Stormbreaker Fist", displayName = "Stormbreaker", tier = 7, style = "Storm", icon = "StormbreakerFist", robux = 129, gamePassId = 1951036123',
    'name = "Celestial Titan Fist", displayName = "Celestial Titan", tier = 8, style = "Celestial", icon = "CelestialTitanFist", robux = 299, gamePassId = 1951054054',
  ]),
  developer_product_catalog_matches_creator_dashboard: includesAll(config, [
    'id = "CoinPack", displayName = "Hero Coin Pack", robux = 29, productId = 3708736246',
    'id = "SpinPack", displayName = "3 Hero Spins", robux = 49, productId = 3708736283',
    'id = "CoinBoost", displayName = "2X Coins 15 Minutes", robux = 49, productId = 3708736312',
    'id = "TrainingBoost", displayName = "2X Training 15 Minutes", robux = 59, productId = 3708736344',
  ]),
  developer_product_regional_price_runtime_is_bounded_and_covered:
    includesAll(client, [
      "GetDeveloperProductDisplayPrice",
      "ApplyDeveloperProductWorldPrice",
      "ApplyDeveloperProductControlPrice",
      "DeveloperProductPriceCache",
      "RegionalPriceResolved",
      "marketplaceService.GetProductInfoAsync",
      "Enum.InfoType.Product",
    ])
    && developerProductFlowSource.includes("without opening a purchase prompt")
    && developerProductFlowSource.includes("GetProductInfoAsync(product.productId,Enum.InfoType.Product)")
    && developerProductFlowSource.includes("GrantPremiumProduct"),
  purchase_helpers_do_not_add_top_level_register_pressure: includesAll(client, [
    "shared.PunchWallPurchaseRuntime = {}",
    "shared.PunchWallPurchaseRuntime.HasConfiguredGamePass",
    "shared.PunchWallPurchaseRuntime.HasConfiguredDeveloperProduct",
  ]) && includesAll(server, [
    "visualSafety.hasConfiguredGamePass",
    "visualSafety.hasConfiguredDeveloperProduct",
  ]),
  game_pass_configuration_is_unique_across_fists_and_pets:
    [client, server].every((source) => includesAll(source, [
      "for _, catalog in ipairs({ GameConfig.PremiumFists, GameConfig.PremiumPets }) do",
      "if tonumber(candidate.gamePassId) == gamePassId then",
      "matches += 1",
      "return matches == 1",
    ])),
  disabled_purchase_controls_are_noninteractive: includesAll(client, [
    "button.Active = false",
    "button.Selectable = false",
    "button.AutoButtonColor = false",
    'button:SetAttribute("PurchaseUnavailable", true)',
    '"UNAVAILABLE"',
  ]),
  legacy_fist_and_pet_offers_respect_configuration: includesAll(client, [
    "local purchaseUnavailable = not isOwned and not purchaseConfigured",
    "local purchaseUnavailable = not owned and not purchaseConfigured",
    'action = "BuyPremiumFist"',
    'action = "BuyPremiumPet"',
  ]),
  bonus_spin_purchase_respects_product_configuration: includesAll(client, [
    'FindPremiumProduct("SpinPack")',
    "bonusSpinPurchaseConfigured",
    'action = "BuyPremiumProduct", target = "SpinPack"',
    '"BONUS SPINS\\nUNAVAILABLE"',
  ]),
  functional_shop_marks_unconfigured_offers: includesAll(client, [
    'card:SetAttribute("PurchaseConfigured", purchaseConfigured)',
    'card:SetAttribute("PurchaseUnavailable", purchaseUnavailable)',
    "action.Active = actionEnabled",
    "action.Selectable = actionEnabled",
    "action.AutoButtonColor = actionEnabled",
    "Currently unavailable",
  ]),
  functional_shop_purchase_unavailable_is_always_boolean:
    includesAll(functionalShopAvailability, [
      "local purchaseUnavailable = false",
      "if item.isPremiumPet then",
      "purchaseUnavailable = not premiumOwned and not purchaseConfigured",
      "elseif item.isRobuxProduct then",
      "purchaseUnavailable = not purchaseConfigured",
      'card:SetAttribute("PurchaseUnavailable", purchaseUnavailable)',
    ])
    && !functionalShopAvailability.includes(
      "local purchaseUnavailable = item.isPremiumPet and not premiumOwned and not purchaseConfigured"
    )
    && functionalShopAvailability.indexOf("local purchaseUnavailable = false")
      < functionalShopAvailability.indexOf(
        'card:SetAttribute("PurchaseUnavailable", purchaseUnavailable)'
      ),
  contextual_use_excludes_unconfigured_stands: includesAll(client, [
    'candidate:GetAttribute("PremiumOnly") == true',
    'candidate:GetAttribute("PurchaseConfigured") == true',
  ]) && includesAll(server, [
    'part:GetAttribute("PremiumOnly") ~= true',
    'part:GetAttribute("PurchaseConfigured") == true',
  ]),
  world_offer_detectors_exist_only_when_configured: includesAll(server, [
    "if purchaseConfigured then",
    'Instance.new("ClickDetector")',
    "visualSafety.markWorldOfferAvailability",
    '"OFFER UNAVAILABLE"',
    '"UNAVAILABLE | PASS ID NOT CONFIGURED"',
  ]),
  server_rejects_unconfigured_ids: includesAll(server, [
    'reason = "game_pass_not_configured"',
    'reason = "product_not_configured"',
    '"PURCHASE UNAVAILABLE | PASS ID NOT CONFIGURED"',
    '"PURCHASE UNAVAILABLE | PRODUCT ID NOT CONFIGURED"',
  ]),
  normal_studio_purchase_requests_cannot_auto_grant: includesAll(config, [
    "GameConfig.StudioTestGrantPremium = false",
  ])
    && !config.includes("GameConfig.StudioTestGrantPremium = true")
    && !server.includes("StudioTestGrantPremium")
    && [fistPrompt, productPrompt, petPrompt].every((prompt) =>
      prompt.length > 0
        && !prompt.includes("StudioTestGrantPremium")
        && !prompt.includes('"StudioTest"'))
    && includesAll(fistPrompt, [
      "visualSafety.hasConfiguredGamePass",
      'type = "PremiumSetup"',
      '"PURCHASE UNAVAILABLE | PASS ID NOT CONFIGURED"',
      'reason = "game_pass_not_configured"',
    ])
    && includesAll(petPrompt, [
      "visualSafety.hasConfiguredGamePass",
      'type = "PremiumSetup"',
      '"PURCHASE UNAVAILABLE | PASS ID NOT CONFIGURED"',
      'reason = "game_pass_not_configured"',
    ])
    && includesAll(productPrompt, [
      "visualSafety.hasConfiguredDeveloperProduct",
      'type = "PremiumSetup"',
      '"PURCHASE UNAVAILABLE | PRODUCT ID NOT CONFIGURED"',
      'reason = "product_not_configured"',
    ])
    && fistPrompt.indexOf("visualSafety.hasConfiguredGamePass")
      < fistPrompt.indexOf('decodeList(player, "OwnedPremiumFistsJSON")')
    && petPrompt.indexOf("visualSafety.hasConfiguredGamePass")
      < petPrompt.indexOf('decodeList(player, "OwnedPremiumPetsJSON")'),
  explicit_studio_automation_grants_remain_available: includesAll(automationCommands, [
    'elseif action == "GrantPremiumFist" then',
    'elseif action == "GrantPremiumProduct" then',
    'elseif action == "GrantPremiumPet" then',
    'shared.PunchWallPremiumFists.grant(player, item, "StudioAutomation")',
    "shared.PunchWallPremiumProducts.grant(player, product)",
    'shared.PunchWallPremiumPets.grant(player, item, "StudioAutomation")',
  ]),
  availability_flow_probes_all_catalogs_without_opening_purchase:
    includesAll(flowLuau, [
      "command:Invoke('Reset')",
      "assert(cfg.StudioTestGrantPremium==false",
      "configuredFists",
      "configuredPets",
      "configuredProducts",
      "GetProductInfoAsync(fist.gamePassId,Enum.InfoType.GamePass)",
      "info.Name==fist.name",
      "info.IsForSale==true",
      "command:Invoke('Snapshot')",
      "OwnedPremiumFistsJSON",
      "OwnedPremiumPetsJSON",
      "SpinCredits",
    ])
    && !/cfg\.StudioTestGrantPremium\s*=(?!=)/.test(flowLuau)
    && !/\.(?:gamePassId|productId)\s*=(?!=)/.test(flowLuau)
    && !flowLuau.includes("PromptGamePassPurchase"),
  availability_flow_matches_all_three_live_premium_fists:
    includesAll(livePremiumFistMetadataFlowLuau, [
      "1947838143",
      "1951036123",
      "1951054054",
      "Enum.InfoType.GamePass",
      "info.Name==fist.name",
      "info.IsForSale==true",
      "assert(ok and #rows==3",
    ])
    && !livePremiumFistMetadataFlowLuau.includes(":FireServer"),
  studio_purchase_id_override_is_bounded_vm_local_and_restorable:
    includesAll(client, [
      '"ConfigurePurchaseTestIds"',
      "MaxOverrides = 6",
      "MaxTestId = 2147483647",
      "if not RunService:IsStudio() then",
      'if catalogName == "PremiumFists" then',
      'if catalogName == "PremiumPets" then',
      'if catalogName == "PremiumProducts" then',
      "or #overrides > purchaseTestRuntime.MaxOverrides",
      "or testId > purchaseTestRuntime.MaxTestId",
      "or math.floor(testId) ~= testId",
      'return { ok = false, reason = "duplicate_target_" .. index }',
      "purchaseTestRuntime.Originals = prepared",
      "purchaseTestRuntime.Active = false",
      'pcall(purchaseTestRuntime.Refresh, "studio-purchase-test-rollback")',
      "return purchaseTestRuntime.Restore()",
    ])
    && includesAll(client, [
      'shared.PunchWallHeroShopRefresh({',
      'reason = "studio-automation-open-shop-page"',
      "renderOpenPanel()",
    ]),
  availability_ui_flow_uses_harness_only_and_covers_all_catalogs:
    includesAll(clientAvailabilityFlowLuau, [
      "cfg.PremiumFists",
      "fistWorldOk",
      "workspace.PunchWallRPG.Interactables",
      "FindFirstChildOfClass('ClickDetector')",
      "Enum.InfoType.GamePass",
      "a:Invoke('OpenShopPage','Premium')",
      "validatePage('Robux')",
      "validatePage('Honor')",
      "cfg.PremiumPets",
      "cfg.PremiumProducts",
      "PremiumPetPreviewReady",
      "PurchaseConfigured",
      "RegionalPriceResolved",
      "ShopActionBound",
      "GetProductInfoAsync",
      "PremiumPetPreviewReady",
    ])
    && !/\.(?:gamePassId|productId)\s*=(?!=)/.test(clientAvailabilityFlowLuau),
  availability_ui_flow_restores_on_failure_and_cleanup:
    !flowLuau.includes("ConfigurePurchaseTestIds")
    && flow.cleanup?.length === 1
    && flow.cleanup[0]?.tool === "start_stop_play"
    && flow.cleanup[0]?.allowError === true,
  configured_marketplace_paths_are_preserved: includesAll(server, [
    "MarketplaceService:PromptGamePassPurchase(player, item.gamePassId)",
    "MarketplaceService:PromptProductPurchase(player, product.productId)",
    "MarketplaceService.PromptGamePassPurchaseFinished:Connect",
    "MarketplaceService.ProcessReceipt",
  ]),
  world_gamepass_prices_survive_slow_bootstrap: includesAll(client, [
    "ApplyPremiumPetWorldPrice",
    "task.delay(3, function()",
    "task.delay(12, function()",
    "cannot remain stale without introducing a polling or render loop",
  ]),
  honor_copy_describes_current_release_only: includesAll(client, [
    "DEPTH • REBIRTH • TITAN | EQUIP ONE RELIC",
    "EARN: DEPTH + REBIRTH MILESTONES • TITAN CLEARS 12/5/5 • HERO SPIN: NO HONOR",
    "Currency only • relic Depth and Rebirth gates still apply",
  ]) && includesAll(server, [
    "DEPTH + REBIRTH MILESTONES | TITAN CLEARS | ONE RELIC ACTIVE",
  ]) && !/(NEXT RELEASE|COMING SOON)/.test(client + server),
  external_template_workers_finalize_on_every_path: includesAll(server, [
    "local workerOk, workerError = pcall(function()",
    "completed += 1",
    "completionSignal:Fire()",
    '"ExternalTemplateWorkerFinalizationGuarded", true',
  ]),
  external_template_bootstrap_has_bounded_deadline: includesAll(server, [
    "templateLoadDeadlineSeconds = 12",
    "while completed < pending and os.clock() < loadDeadlineAt do",
    "acceptingLoadedTemplates = false",
    '"ExternalTemplateLoadDeadlineBounded", true',
    '"ExternalTemplateLoadFinalized", true',
    '"ExternalTemplateFallbackMode", "SourceOrProcedural"',
  ]) && !server.includes("while completed < pending do task.wait() end"),
  late_external_template_workers_cannot_mutate_finalized_world: includesAll(server, [
    "if not acceptingLoadedTemplates or os.clock() >= loadDeadlineAt then",
    "asset:Destroy()",
    '"ExternalTemplateLoadLateWorkerCount"',
  ]),
  gauntlet_retry_is_single_flight_and_bounded: includesAll(client, [
    "visualRetryScheduled = false",
    "visualRetryMaxAttempts = 3",
    "visualRetryDeadlineSeconds = 0.8",
    "if companionRuntime.visualRetryScheduled then",
    'companionRuntime.UpdateVisualRetryAttributes("Coalesced")',
    'companionRuntime.UpdateVisualRetryAttributes("Exhausted")',
    'gui:SetAttribute("HeroGauntletRetrySingleFlight", true)',
    'gui:SetAttribute("HeroGauntletRetryEventDriven", true)',
  ]),
  gauntlet_retry_uses_character_event_not_polling: includesAll(client, [
    "character.ChildAdded:Connect(function(child)",
    'child.Name == "RightHand" or child.Name == "Right Arm"',
    "task.delay(companionRuntime.visualRetryDeadlineSeconds",
  ]) && !client.includes("task.delay(0.4, refreshCharacterVisuals)"),
  gauntlet_retry_cancels_on_success_and_character_change: includesAll(client, [
    'companionRuntime.CancelVisualRetry("BuildSucceeded")',
    'companionRuntime.CancelVisualRetry("CharacterAdded")',
    "companionRuntime.visualRetryGeneration += 1",
    "companionRuntime.visualRetryConnection:Disconnect()",
  ]),
};

const failures = Object.entries(checks)
  .filter(([, passed]) => !passed)
  .map(([name]) => name);

const result = {
  ok: failures.length === 0,
  passed: Object.keys(checks).length - failures.length,
  total: Object.keys(checks).length,
  checks,
  failures,
  files: [
    path.relative(root, clientPath),
    path.relative(root, serverPath),
    path.relative(root, configPath),
    path.relative(root, flowPath),
  ],
};

console.log(JSON.stringify(result, null, 2));
if (!result.ok) process.exitCode = 1;
