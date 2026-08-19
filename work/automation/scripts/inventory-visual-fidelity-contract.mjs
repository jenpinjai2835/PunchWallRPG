#!/usr/bin/env node
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const repositoryRoot = path.resolve(scriptDirectory, "../../..");
const inventoryPath = path.join(
  repositoryRoot,
  "work",
  "punch-wall-rpg",
  "src",
  "client",
  "InventoryUI.lua",
);
const viewModelPath = path.join(
  repositoryRoot,
  "work",
  "punch-wall-rpg",
  "src",
  "shared",
  "InventoryViewModel.lua",
);
const shopPath = path.join(
  repositoryRoot,
  "work",
  "punch-wall-rpg",
  "src",
  "client",
  "PunchWallClient.client.lua",
);
const gameConfigPath = path.join(
  repositoryRoot,
  "work",
  "punch-wall-rpg",
  "src",
  "shared",
  "GameConfig.lua",
);
const petIconDirectory = path.join(
  repositoryRoot,
  "work",
  "assets",
  "generated",
  "pet-inventory-icons-v1",
  "runtime-512",
);

const source = fs.readFileSync(inventoryPath, "utf8").replace(/\r\n?/g, "\n");
const viewModel = fs
  .readFileSync(viewModelPath, "utf8")
  .replace(/\r\n?/g, "\n");
const shop = fs.readFileSync(shopPath, "utf8").replace(/\r\n?/g, "\n");
const gameConfig = fs
  .readFileSync(gameConfigPath, "utf8")
  .replace(/\r\n?/g, "\n");
const checks = {};

function check(name, condition, detail) {
  checks[name] = condition === true;
  assert.equal(condition, true, `${name}: ${detail}`);
}

function block(text, start, end) {
  const startIndex = text.indexOf(start);
  assert.notEqual(startIndex, -1, `Missing start sentinel: ${start}`);
  const endIndex = text.indexOf(end, startIndex + start.length);
  assert.notEqual(endIndex, -1, `Missing end sentinel: ${end}`);
  return text.slice(startIndex, endIndex);
}

function linearize(channel) {
  const normalized = channel / 255;
  return normalized <= 0.03928
    ? normalized / 12.92
    : ((normalized + 0.055) / 1.055) ** 2.4;
}

function luminance([red, green, blue]) {
  return linearize(red) * 0.2126
    + linearize(green) * 0.7152
    + linearize(blue) * 0.0722;
}

function contrast(first, second) {
  const firstLuminance = luminance(first);
  const secondLuminance = luminance(second);
  return (
    (Math.max(firstLuminance, secondLuminance) + 0.05)
    / (Math.min(firstLuminance, secondLuminance) + 0.05)
  );
}

function multiply(first, second) {
  return first.map((channel, index) => channel * second[index] / 255);
}

const actionCreation = block(
  source,
  "function InventoryUI:_createActionButton(controlKey)",
  "function InventoryUI:_ensureViewOnlyAction()",
);
const actionRender = block(
  source,
  "function InventoryUI:_renderDetail()",
  "function InventoryUI:_syncDetailVisibility()",
);
const capacityUpdate = block(
  source,
  "function InventoryUI:_updateCapacity()",
  "function InventoryUI:_applyCategoryVisual(category)",
);
const rarityMenu = block(
  source,
  "function InventoryUI:_setRarityMenu(visible)",
  "function InventoryUI:_requestClose()",
);
const gridRender = block(
  source,
  "function InventoryUI:_renderGrid()",
  "function InventoryUI:_clearActionButtons()",
);
const responsive = block(
  source,
  "function InventoryUI:ApplyResponsive(viewport, compact, uiScale)",
  "function InventoryUI:_enabledActionNames(item)",
);
const fistRarity = block(
  viewModel,
  "local FIST_TIER_RARITY = {",
  "local function formatDecimal(value)",
);
const sparseSlots = block(
  source,
  "function InventoryUI:_createSparseSlot(index)",
  "function InventoryUI:_renderGrid()",
);

const ink = [2, 9, 15];
const lightText = [246, 249, 250];
const mutedText = [157, 185, 201];
const goldText = [255, 194, 24];
const cyanText = [165, 241, 255];
const neutralStops = [
  [255, 255, 255],
  [239, 246, 249],
  [211, 224, 230],
];
const effectiveContrasts = (text, background) =>
  neutralStops.map((stop) =>
    contrast(multiply(text, stop), multiply(background, stop))
  );
const actionContrastMatrix = {
  primary: effectiveContrasts(ink, [68, 211, 42]),
  secondary: effectiveContrasts(lightText, [12, 75, 151]),
  utility: effectiveContrasts(ink, [225, 149, 22]),
  danger: effectiveContrasts(lightText, [137, 22, 31]),
  disabled: effectiveContrasts(mutedText, [32, 44, 54]),
};
const textControlContrastMatrix = {
  capacity: effectiveContrasts(lightText, [4, 14, 22]),
  rarityFilter: effectiveContrasts(lightText, [6, 24, 36]),
  close: effectiveContrasts(lightText, [139, 8, 17]),
  categoryIdle: effectiveContrasts(lightText, [13, 31, 43]),
  categoryHover: effectiveContrasts(cyanText, [10, 43, 57]),
  categorySelected: effectiveContrasts(goldText, [34, 36, 28]),
};

check(
  "enabled_action_palettes_clear_wcag_style_target",
  Object.values(actionContrastMatrix).every(
    (ratios) => Math.min(...ratios) >= 4.5,
  )
    && Object.values(textControlContrastMatrix).every(
      (ratios) => Math.min(...ratios) >= 4.5,
    )
    && source.includes(
      'self.Root:SetAttribute("InventoryActionContrastTarget", 4.5)',
    ),
  `Expected every audited text/semantic stop to meet 4.5:1: ${JSON.stringify({ actionContrastMatrix, textControlContrastMatrix })}`,
);

check(
  "enabled_and_disabled_actions_have_distinct_runtime_states",
  actionRender.includes("button.Active = enabled")
    && actionRender.includes("button.Selectable = enabled")
    && actionRender.includes(
      'button:SetAttribute("InventoryActionVisualState", enabled and "Enabled" or "Disabled")',
    )
    && actionRender.includes("button.BackgroundColor3 = style.base")
    && actionRender.includes("buttonRef.gradient.Color = TEXT_SAFE_GRADIENT")
    && actionRender.includes("buttonRef.stroke.Thickness = enabled and 2 or 1.25")
    && actionCreation.includes('InventoryActionVisualState", "Disabled"'),
  "Action controls must expose and visibly render enabled/disabled state instead of reusing pale generic chrome.",
);

check(
  "text_bearing_gradients_use_neutral_multiplier",
  source.includes("local TEXT_SAFE_GRADIENT_STOPS = {")
    && source.includes("local function multiplyColor(first, second)")
    && [
      "addGradient(self.Capacity, TEXT_SAFE_GRADIENT, 90)",
      "addGradient(self.Close, TEXT_SAFE_GRADIENT, 90)",
      "local buttonGradient = addGradient(button, TEXT_SAFE_GRADIENT, 90)",
      "addGradient(self.RarityFilter, TEXT_SAFE_GRADIENT, 90)",
      "local gradient = addGradient(button, TEXT_SAFE_GRADIENT, 90)",
      "addGradient(label, TEXT_SAFE_GRADIENT, 90)",
    ].every((token) => source.includes(token))
    && source.includes(
      'self.Root:SetAttribute("InventoryTextGradientPolicy", "NeutralMultiplierV1")',
    )
    && !source.includes("buttonRef.gradient.Color = ColorSequence.new({"),
  "A UIGradient parented to text may only use high-luminance neutral stops; semantic darkness belongs on BackgroundColor3.",
);

check(
  "equip_use_and_danger_use_semantic_chrome",
  source.includes('if semantic == "equip" then')
    && source.includes('elseif semantic == "use" or semantic == "unequip" then')
    && source.includes("return ACTION_STYLES.Primary")
    && source.includes("return ACTION_STYLES.Secondary")
    && source.includes("return ACTION_STYLES.Danger"),
  "EQUIP, USE/UNEQUIP, and destructive actions need stable high-contrast semantic palettes.",
);

check(
  "capacity_is_parseable_at_every_width",
  capacityUpdate.includes('string.format("ITEM %s\\nPET %s/%s"')
    && capacityUpdate.includes('string.format("ITEMS %s\\nPETS %s/%s"')
    && !capacityUpdate.includes('"I %s')
    && !capacityUpdate.includes('"P %s')
    && capacityUpdate.includes('InventoryCapacityFullText", fullText')
    && capacityUpdate.includes('InventoryCapacityReadable", true')
    && responsive.includes(
      "self.Capacity.TextSize = capacityWidth < 104 and 10 or useCompact and 11 or 12",
    ),
  "Compact capacity copy must keep explicit ITEM/PET semantics and readable type.",
);

check(
  "rarity_menu_has_intentional_overlay_and_close_state",
  rarityMenu.includes("self.RarityMenu.ScrollingEnabled = self._rarityMenuOpen")
    && rarityMenu.includes("self.RarityMenu.CanvasPosition = Vector2.zero")
    && rarityMenu.includes('InventoryZLayerIntent", "OverlayAboveGrid"')
    && rarityMenu.includes('InventoryRarityMenuOpen", self._rarityMenuOpen')
    && source.includes("self:_connect(self.Search.Focused, function()\n\t\tself:_setRarityMenu(false)")
    && source.includes("if self._rarityMenuOpen then\n\t\t\t\tself:_setRarityMenu(false)"),
  "The rarity overlay must be scrollable only while open, reset on opening, and close on another interaction.",
);

check(
  "rarity_entries_are_readable_and_touch_bounded",
  source.includes("button.TextSize = useCompact and 11 or 13")
    && source.includes("button.Size = UDim2.new(1, 0, 0, touchTarget)")
    && source.includes("AutomaticCanvasSize = Enum.AutomaticSize.Y")
    && source.includes("ClipsDescendants = true")
    && source.includes('button:SetAttribute("InventoryRaritySelected", selected)'),
  "Rarity choices need readable type, selected state, 44 px rendered rows, and bounded scrolling.",
);

check(
  "native_fallback_has_reference_depth_without_uploaded_chrome",
  source.includes('self.Root:SetAttribute("ArtMode", "ReferenceNativeV3")')
    && source.includes('self.Root:SetAttribute("ChromeAssetMode", "Native")')
    && [
      'Name = "InventoryWindowInnerFrame"',
      'Name = "InventoryWindowTopRail"',
      'Name = "HeaderPattern"',
      'Name = "CardDepthInset"',
      'Name = "ItemArtBloom"',
      'Name = "DetailMetaStrip"',
      'Name = "DetailArtCore"',
    ].every((token) => source.includes(token)),
  "The always-available fallback must provide layered red/cyan/steel chrome without requiring an uploaded atlas.",
);

check(
  "inventory_owns_one_modal_frame",
  shop.includes("mainStroke.Transparency = inventoryVisible and 1 or 0")
    && shop.includes('local mainAccent = mainPanel:FindFirstChild("HeroAccent")')
    && shop.includes("mainAccent.Visible = not inventoryVisible")
    && shop.includes('mainPanel:SetAttribute("InventoryParentChromeSuppressed", inventoryVisible)'),
  "The transparent GameMenu host must suppress its generic outline and accent while Inventory renders its own frame.",
);

check(
  "empty_and_locked_slots_are_meaningful",
  source.includes('Name = "InventoryEmptyState"')
    && source.includes('Name = "EmptySlotPreview"')
    && gridRender.includes('"YOUR INVENTORY IS EMPTY\\nEARN OR BUY ITEMS')
    && gridRender.includes('"NO ITEMS MATCH THIS FILTER\\nCHANGE RARITY')
    && gridRender.includes('InventoryEmptyTreatment", "FilterEmpty"')
    && gridRender.includes('InventoryEmptyTreatment", "InventoryEmpty"')
    && gridRender.includes('InventoryLockedTreatment"')
    && gridRender.includes("cardRef.lockedVeil.Visible = item.locked == true"),
  "Empty inventory, empty filter, and locked cards must communicate different recovery/state information.",
);

check(
  "sparse_inventory_uses_quiet_bounded_noninteractive_placeholders",
  source.includes("local SPARSE_SLOT_ROWS = 1")
    && source.includes("local MAX_SPARSE_SLOT_PLACEHOLDERS = 5")
    && sparseSlots.includes('create("Frame", self.CardPool')
    && sparseSlots.includes('slot:SetAttribute("InventoryOwnsItem", false)')
    && sparseSlots.includes('slot:SetAttribute("InventoryInteractive", false)')
    && sparseSlots.includes('ref.label.Text = locked and "LOCKED" or "EMPTY"')
    && sparseSlots.includes("self._activeCardCount > 0 and not filterActive")
    && sparseSlots.includes('InventorySparseSlotMode", filterActive and "FilteredHidden" or "InventoryQuiet"')
    && sparseSlots.includes('InventoryFilteredPlaceholderCount", filterActive and self._activeSparseSlotCount or 0')
    && sparseSlots.includes("self._activeSparseSlotCount <= MAX_SPARSE_SLOT_PLACEHOLDERS")
    && !sparseSlots.includes("_connect")
    && !sparseSlots.includes("Activated")
    && gridRender.includes("self:_renderSparseSlots()")
    && responsive.includes("self:_renderSparseSlots()"),
  "Filtered results must show only real items; the unfiltered view may show one quiet, bounded, listener-free placeholder row.",
);

check(
  "wide_composition_uses_balanced_three_pane_hierarchy",
  source.includes('InventoryCompositionMode", "CleanThreePaneV4"')
    && source.includes('InventoryFilteredPlaceholderPolicy", "HideSyntheticSlots"')
    && source.includes('InventoryWideActionLayout", "ThreeSingleOrFourTwoByTwo"')
    && source.includes('InventoryBackdropMode", "InputOnlyTransparent"')
    && source.includes("BackgroundTransparency = 1")
    && responsive.includes("local headerHeight = useCompact and math.max(54, touchTarget + 10) or math.max(68, touchTarget + 16)")
    && responsive.includes("local detailWidth = math.clamp(windowWidth * 0.285, 282, 320)")
    && responsive.includes("local artSize = math.clamp(detailHeight * 0.245, 124, 154)")
    && responsive.includes("local actionColumns = wideActionCount == 4 and 2 or math.min(3, wideActionCount)")
    && responsive.includes("local showStats = detailHeight >= 430 and statsY >= descriptionY + 46")
    && responsive.includes('InventoryWideActionColumns", actionColumns'),
  "Wide Inventory should use a compact header, square centered art, and a balanced 2x2 layout for four pet actions.",
);

check(
  "detail_avoids_duplicate_selected_status_banner",
  actionRender.includes("self.DetailStatus.Visible = true")
    && actionRender.includes("self.DetailStatus.Visible = false")
    && actionRender.includes(
      'self.Root:SetAttribute("InventoryDetailStatusTreatment", "StateRowAndAction")',
    )
    && responsive.includes(
      "local statusY = actionY - (self.DetailStatus.Visible and 50 or 0)",
    )
    && responsive.includes("self.DetailActions.Position = UDim2.fromOffset(14, actionY)"),
  "Selected detail should use the STATE row plus its readable CTA, not repeat the same state in a banner.",
);

check(
  "fist_rarity_uses_one_exported_canonical_mapping",
  fistRarity.includes('[1] = "Common"')
    && fistRarity.includes('[2] = "Rare"')
    && fistRarity.includes('[3] = "Rare"')
    && fistRarity.includes('[4] = "Epic"')
    && fistRarity.includes('or "Legendary"')
    && viewModel.includes(
      "function InventoryViewModel.GetCanonicalFistRarity(definition, premium)",
    )
    && viewModel.includes("return canonicalFistRarity(definition, premium)")
    && shop.includes('tier == 1 and "COMMON"')
    && shop.includes('tier >= 4 and "EPIC"')
    && shop.includes('or "RARE"'),
  "Inventory fist labels must canonically match the Shop's tier-1 Common, tier-2/3 Rare, tier-4 Epic, tier-5+ Legendary behavior.",
);

const expectedPetIcons = [
  "forest-pup.png",
  "miner-cat.png",
  "crystal-fox.png",
  "lava-dragon.png",
  "secret-titan-golem.png",
  "crimson-phoenix.png",
  "storm-wyvern.png",
  "celestial-guardian.png",
];
check(
  "pets_use_species_specific_model_matched_art",
  expectedPetIcons.every((file) => fs.existsSync(path.join(petIconDirectory, file)))
    && [
      "ForestPup",
      "MinerCat",
      "CrystalFox",
      "LavaDragon",
      "SecretTitanGolem",
      "CrimsonPhoenix",
      "StormWyvern",
      "CelestialGuardian",
    ].every((key) => gameConfig.includes(`artKey = "${key}"`))
    && source.includes("function InventoryUI:_applyPetPreview")
    && source.includes('"ModelMatchedViewportV1"')
    && shop.includes("function companionRuntime.BuildInventoryPetPreview")
    && shop.includes("BuildPetPreview = companionRuntime.BuildInventoryPetPreview"),
  "All eight pets need their own upload candidate and an exact-model ViewportFrame fallback.",
);

check(
  "pet_fusion_is_visible_balanced_and_server_routed",
  viewModel.includes('"FusePet"')
    && viewModel.includes('actions = { primary, fusionAction, lockAction, deleteAction }')
    && source.includes('elseif remoteAction == "FusePet" then')
    && source.includes('return ACTION_STYLES.Fusion, "Fusion"')
    && source.includes("local actionColumns = actionCount == 4 and 2 or math.min(3, actionCount)")
    && source.includes("local actionColumns = wideActionCount == 4 and 2 or math.min(3, wideActionCount)"),
  "Pets need a semantic Fusion button and a 2x2 four-action layout on compact and wide screens.",
);

check(
  "category_icons_use_one_text_free_semantic_tile_system",
  source.includes("function InventoryUI:_createCategoryIcon(parent, category)")
    && source.includes('InventoryCategoryIconStyle", "UnifiedProceduralGlyphV1"')
    && source.includes('InventoryCategoryIconEmbeddedText", false')
    && [
      '"GridTile" .. index',
      '"GlovePalm"',
      '"PetEgg"',
      '"BoostBolt"',
      '"HonorMedal"',
    ].every((token) => source.includes(token))
    && !source.includes("local CATEGORY_ICONS =")
    && responsive.includes("widgets.icon.Size = UDim2.fromOffset(24, 24)")
    && responsive.includes("widgets.icon.Size = UDim2.fromOffset(40, 40)"),
  "All five category entries need equal text-free icon tiles with semantic glyphs and explicit compact/wide sizes.",
);

check(
  "visual_observability_is_exposed_to_tester",
  source.includes("actionVisuals = actionVisuals")
    && source.includes("minimumEnabledActionContrast = tonumber(")
    && source.includes("enabledActionContrastPass = self.Root:GetAttribute(")
    && source.includes("capacityFullText = tostring(")
    && source.includes("rarityMenuOpen = self.Root:GetAttribute(")
    && source.includes("emptyTreatment = tostring(")
    && source.includes("textGradientPolicy = tostring(")
    && source.includes("sparseSlotCreates = self._sparseSlotCreateCount"),
  "Tester snapshots need action contrast, gradient policy, capacity, menu, empty, and sparse-slot evidence.",
);

check(
  "category_connection_observability_survives_constructor",
  !source.includes('self.Root:SetAttribute("InventoryCategoryConnectionCount", 0)')
    && (
      source.match(
        /self\.Root:SetAttribute\("InventoryCategoryConnectionCount", #CATEGORIES \* 5\)/g,
      ) || []
    ).length >= 2,
  "The constructor must not erase the 25 category interaction connections recorded by _build.",
);

check(
  "visual_refresh_has_no_new_frame_loop",
  !actionRender.includes("RunService")
    && !actionRender.includes("Heartbeat")
    && !gridRender.includes("RunService")
    && !gridRender.includes("Heartbeat")
    && !rarityMenu.includes("RunService")
    && !rarityMenu.includes("Heartbeat"),
  "Visual fidelity state changes must remain event-driven and bounded.",
);

const passed = Object.values(checks).filter(Boolean).length;
console.log(
  JSON.stringify(
    {
      ok: passed === Object.keys(checks).length,
      passed,
      total: Object.keys(checks).length,
      checks,
      actionContrastMatrix,
      textControlContrastMatrix,
      files: [inventoryPath, viewModelPath, shopPath, gameConfigPath].map((filePath) =>
        path.relative(repositoryRoot, filePath)
      ),
    },
    null,
    2,
  ),
);
