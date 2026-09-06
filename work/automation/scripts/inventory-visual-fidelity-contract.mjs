#!/usr/bin/env node
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import { spawnSync } from "node:child_process";
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

const paletteSource = block(source, "local PALETTE = {", "-- UIGradient");
function paletteColor(name) {
  const match = paletteSource.match(new RegExp(`\\b${name} = Color3\\.fromRGB\\((\\d+), (\\d+), (\\d+)\\)`));
  assert(match, `Missing actual palette color: ${name}`);
  return match.slice(1).map(Number);
}
const ink = paletteColor("Ink");
const lightText = paletteColor("Text");
const mutedText = paletteColor("Muted");
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
  close: effectiveContrasts(lightText, paletteColor("PanelRaised")),
  categoryIdle: effectiveContrasts(lightText, paletteColor("PanelRaised")),
  categoryHover: effectiveContrasts(lightText, [10, 43, 57]),
  categorySelected: effectiveContrasts(lightText, paletteColor("CardHover")),
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
      "self.Capacity.TextSize = secondaryTextSize",
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
  source.includes("button.TextSize = secondaryTextSize")
    && source.includes("button.Size = UDim2.new(1, 0, 0, touchTarget)")
    && source.includes("AutomaticCanvasSize = Enum.AutomaticSize.Y")
    && source.includes("ClipsDescendants = true")
    && source.includes('button:SetAttribute("InventoryRaritySelected", selected)'),
  "Rarity choices need readable type, selected state, 44 px rendered rows, and bounded scrolling.",
);

check(
  "native_fallback_uses_quiet_shell_without_uploaded_chrome",
  source.includes('self.Root:SetAttribute("ArtMode", "ReferenceNativeV3")')
    && source.includes('self.Root:SetAttribute("ChromeAssetMode", "Native")')
    && source.includes('InventoryVisualStyle", "QuietNavyV1"')
    && source.includes('self.WindowStroke = addStroke(self.Window, PALETTE.SteelLight, 1)')
    && source.includes('self.HeaderPattern.Visible = false')
    && source.includes('self.DetailMetaStrip.Visible = false')
    && source.includes('cardRef.footerRail.Visible = false')
    && source.includes('cardRef.rarity.BackgroundColor3 = rarityColor')
    && source.includes('self.DetailRarity.BackgroundColor3 = rarityColor')
    && source.includes('PolishConfig.RarityColors[rarity]'),
  "The native shell uses restrained chrome and shared semantic rarity colors; actual rendered visibility is checked by inventory-premium-readability.",
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
    && gridRender.includes("cardRef.lockedVeil.Visible = item.locked == true and not honorItem")
    && gridRender.includes('InventoryLockedLabelCount')
    && gridRender.includes('honorItem and "HonorStateBadgeOnly" or "ArtVeilOnly"'),
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
    && responsive.includes("local headerHeight = useCompact and (52 / scale) or math.max(68, touchTarget + 16)")
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
    && source.includes("local actionColumns = math.min(2, actionCount)")
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
    && responsive.includes("widgets.icon.Size = UDim2.fromOffset(20, 20)")
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

// Execute the exact responsive category/Fusion flow predicates with finite geometry.
const categoryFlow=JSON.parse(fs.readFileSync(path.join(repositoryRoot,'work/automation/flows/inventory-category-icon-cohesion.json'),'utf8'));
const fusionFlow=JSON.parse(fs.readFileSync(path.join(repositoryRoot,'work/automation/flows/inventory-pet-icons-fusion.json'),'utf8'));
const categoryStep=categoryFlow.steps.find(step=>step.label==='five category icons share equal text-free procedural tiles');
const fusionStep=fusionFlow.steps.find(step=>step.label==='all cards and detail use distinct model-matched previews with balanced Fusion action');
const categoryHelper=block(categoryStep.args.code,'local function verifyCategoryIconRow','local function visible');
const fusionHelper=block(fusionStep.args.code,'local function verifyFusionActionGeometry','local function visible');
const luauCandidates=[process.env.LUAU_COMMAND,...fs.readdirSync(os.tmpdir()).filter(name=>name.startsWith('codex-luau-')).sort().reverse().map(name=>path.join(os.tmpdir(),name,process.platform==='win32'?'luau.exe':'luau'))];
const luau=luauCandidates.find(candidate=>candidate&&fs.existsSync(candidate))||'luau';
function executeVisualOracle(code){
 const r=spawnSync(luau,[],{input:'local f=assert(loadstring('+JSON.stringify(code)+')) print("VISUAL_ORACLE_COMPILED") f()\n',encoding:'utf8',timeout:20000,maxBuffer:4*1024*1024});
 const output=(r.stdout||'')+'\n'+(r.stderr||'');
 return {ok:!r.error&&r.status===0&&!r.stderr&&output.includes('VISUAL_ORACLE_PASS'),compiled:output.includes('VISUAL_ORACLE_COMPILED'),output};
}
const categoryFixtures=String.raw`
local function iconRow(compact,scale,width)
 local visible=not compact or width>=90
 local height=(compact and math.ceil(44/scale) or math.max(56,math.ceil(44/scale)))*scale
 local left=compact and (visible and 3*scale or 2-21*scale) or 9*scale
 local size=(compact and 20 or 40)*scale
 return {button=true,icon=true,frame=true,style=true,embeddedText=false,glyph=true,noRaster=true,
  iconVisible=visible,buttonVisible=true,buttonTextFits=true,buttonSelectable=true,buttonActive=true,
  buttonBounds={x=100,y=200,w=width,h=height},iconBounds={x=100+left,y=200+(compact and 10 or 8)*scale,w=size,h=size}}
end
`;
const categoryCases=String.raw`
local positive,negative=0,0
for _,scale in ipairs({.8,1,1.2})do
 for _,spec in ipairs({{compact=true,width=89},{compact=true,width=90},{compact=false,width=160}})do
  local r=verifyCategoryIconRow(iconRow(spec.compact,scale,spec.width),spec.compact,scale)
  assert(r.valid,'source-responsive icon must pass')
  assert(r.expectedVisible==(not spec.compact or spec.width>=90),'visibility policy')
  if spec.compact and spec.width==89 then assert(r.inside==false and r.visibleBoundsValid,'expected hidden bounds must not be relabelled inside')end
  positive+=1
 end
end
local function reject(name,change,compact,width)
 compact=compact~=false width=width or 100
 local row=iconRow(compact,1,width) change(row)
 assert(not verifyCategoryIconRow(row,compact,1).valid,name)negative+=1
end
reject('visible_icon_overflow',function(r)r.iconBounds.x=r.buttonBounds.x-2 end)
reject('unexpected_icon_hiding',function(r)r.iconVisible=false end)
reject('unexpected_narrow_icon_display',function(r)r.iconVisible=true end,true,89)
reject('wrong_responsive_size',function(r)r.iconBounds.w=18 r.iconBounds.h=18 end)
reject('nonsquare_tile',function(r)r.iconBounds.h+=2 end)
reject('missing_semantic_glyph',function(r)r.glyph=false end)
reject('raster_substitution',function(r)r.noRaster=false end)
reject('embedded_text',function(r)r.embeddedText=true end)
reject('hidden_category_button',function(r)r.buttonVisible=false end)
reject('unreadable_category_text',function(r)r.buttonTextFits=false end)
reject('undersized_category_target',function(r)r.buttonBounds.h=43 end)
reject('unselectable_category',function(r)r.buttonSelectable=false end)
reject('inactive_category',function(r)r.buttonActive=false end)
print('VISUAL_ORACLE_PASS categoryPositive='..positive..' categoryNegative='..negative)
`;
const categoryProgram=categoryHelper+categoryFixtures+categoryCases;
const categoryResult=executeVisualOracle(categoryProgram);
check('actual_responsive_category_oracle_keeps_visible_bounds_and_hidden_policy',categoryResult.ok,categoryResult.output);
const fusionFixtures=String.raw`
local function fusionObservation(compact)
 local buttons={}
 for i,name in ipairs({'Equip','Fuse','Lock','Delete'})do
  buttons[i]={action=name,key='pet:slot:1',visible=true,textFits=true,x=((i-1)%2)*128,y=math.floor((i-1)/2)*50,w=122,h=44}
 end
 return {layoutClass='UIGridLayout',columns=2,wideColumns=compact and 0 or 2,compact=compact,detailMode=compact and 'Drawer' or 'Pane',
  detailVisible=true,windowVisible=true,panel={x=0,y=0,w=250,h=94},detail={x=-10,y=-10,w=270,h=114},window={x=-20,y=-20,w=290,h=134},buttons=buttons}
end
`;
const fusionCases=String.raw`
local positive,negative=0,0
for _,compact in ipairs({true,false})do local r=verifyFusionActionGeometry(fusionObservation(compact))assert(r.valid and r.columns==2 and r.rows==2,'actual two by two layout')positive+=1 end
local function reject(name,change)
 local observation=fusionObservation(true)change(observation)
 assert(not verifyFusionActionGeometry(observation).valid,name)negative+=1
end
reject('wrong_layout_class',function(o)o.layoutClass='UIListLayout' end)
reject('wrong_actual_columns',function(o)o.columns=3 end)
reject('wrong_wide_metadata',function(o)o.wideColumns=2 end)
reject('wrong_detail_mode',function(o)o.detailMode='Pane' end)
reject('hidden_detail',function(o)o.detailVisible=false end)
reject('missing_fourth_action',function(o)table.remove(o.buttons)end)
reject('duplicate_action_identity',function(o)o.buttons[4].action='Fuse' end)
reject('missing_action_identity',function(o)o.buttons[4].action=nil end)
reject('wrong_selected_action_key',function(o)o.buttons[2].key='pet:slot:2' end)
reject('unreadable_action',function(o)o.buttons[2].textFits=false end)
reject('undersized_action',function(o)o.buttons[2].h=43 end)
reject('outside_actions_panel',function(o)o.panel.w=249 end)
reject('outside_detail_panel',function(o)o.detail.w=259 end)
reject('outside_window',function(o)o.window.w=269 end)
reject('overlapping_actions',function(o)o.panel.w=258 o.detail.w=278 o.window.w=298 for _,b in ipairs(o.buttons)do b.w=130 end end)
reject('actual_single_column_despite_metadata',function(o)
 o.panel.h=194 o.detail.h=214 o.window.h=234
 for i,b in ipairs(o.buttons)do b.x=0 b.y=(i-1)*50 end
end)
print('VISUAL_ORACLE_PASS fusionPositive='..positive..' fusionNegative='..negative)
`;
const fusionProgram=fusionHelper+fusionFixtures+fusionCases;
const fusionResult=executeVisualOracle(fusionProgram);
check('actual_fusion_drawer_and_pane_require_four_bounded_grid_actions',fusionResult.ok,fusionResult.output);
const visualMutations=[
 ['category_visible_overflow',categoryProgram,'not expectedVisible or inside','true','visible_icon_overflow'],
 ['category_visibility_policy',categoryProgram,'local visibilityValid=row.iconVisible==expectedVisible','local visibilityValid=true','unexpected_icon_hiding'],
 ['category_size_floor',categoryProgram,'semantic and sameSize and visibleBoundsValid','semantic and visibleBoundsValid','wrong_responsive_size'],
 ['category_touch_floor',categoryProgram,'b.w>=43.99 and b.h>=43.99','true','undersized_category_target'],
 ['fusion_actual_columns',fusionProgram,"observation.layoutClass=='UIGridLayout' and observation.columns==2","observation.layoutClass=='UIGridLayout'",'wrong_actual_columns'],
 ['fusion_bounds',fusionProgram,'contains(observation.panel,button) and contains(observation.detail,button) and contains(observation.window,button)','true','outside_actions_panel'],
 ['fusion_touch_floor',fusionProgram,'button.w>=43.99 and button.h>=43.99','true','undersized_action'],
 ['fusion_overlap',fusionProgram,'overlapX<=.5 or overlapY<=.5','true','overlapping_actions'],
 ['fusion_two_by_two',fusionProgram,'#xs==2 and #ys==2','true','actual_single_column_despite_metadata'],
 ['fusion_selected_key',fusionProgram,"button.key=='pet:slot:1'",'true','wrong_selected_action_key'],
];
const rejectedVisualMutations=[];
for(const [name,program,before,after,expected]of visualMutations){
 assert(program.includes(before),name);
 const r=executeVisualOracle(program.replace(before,after));
 check('visual_mutation_'+name,r.compiled&&!r.ok&&r.output.includes(expected),r.output);
 rejectedVisualMutations.push(name);
}
const oldFlow=name=>{
 const r=spawnSync('git',['show','85c51e5:work/automation/flows/'+name+'.json'],{cwd:repositoryRoot,encoding:'utf8',timeout:15000});
 assert.equal(r.status,0,r.stderr);return JSON.parse(r.stdout);
};
const oldCategory=oldFlow('inventory-category-icon-cohesion');
const oldCategoryStep=oldCategory.steps.find(step=>step.label===categoryStep.label);
const oldIconPredicate=block(oldCategoryStep.args.code,'local sameSize=',' local row=');
const historicalIcon=executeVisualOracle(categoryFixtures+String.raw`
local row=iconRow(true,1,89)
local icon={AbsoluteSize={X=row.iconBounds.w,Y=row.iconBounds.h},AbsolutePosition={X=row.iconBounds.x,Y=row.iconBounds.y}}
local button={AbsoluteSize={X=row.buttonBounds.w,Y=row.buttonBounds.h},AbsolutePosition={X=row.buttonBounds.x,Y=row.buttonBounds.y}}
`+oldIconPredicate+` assert(sameSize==false and inside==false,'old fixed40/hidden bounds no longer reproduce') print('VISUAL_ORACLE_PASS historicalIcons=1')`);
check('historical_category_oracle_rejects_source_valid_hidden20_geometry',historicalIcon.ok,historicalIcon.output);
const oldFusion=oldFlow('inventory-pet-icons-fusion');
const oldFusionStep=oldFusion.steps.find(step=>step.label===fusionStep.label);
const oldColumns=oldFusionStep.args.code.match(/r:GetAttribute\('InventoryWideActionColumns'\)==2/)?.[0];
assert(oldColumns,'Missing historical desktop-only Fusion predicate');
const historicalFusion=executeVisualOracle('local r={} function r:GetAttribute()return 0 end local accepted='+oldColumns+" assert(accepted==false,'old desktop-only columns unexpectedly accepted compact') print('VISUAL_ORACLE_PASS historicalFusion=1')");
check('historical_fusion_oracle_rejects_actual_compact_wide_metadata_zero',historicalFusion.ok,historicalFusion.output);
// Preserve the original mutation/preview gates and every unrelated flow step.
for(const [current,old,label]of [[categoryFlow,oldCategory,categoryStep.label],[fusionFlow,oldFusion,fusionStep.label]]){
 assert.equal(current.steps.length,old.steps.length);assert.deepEqual(current.cleanup,old.cleanup);
 for(let i=0;i<current.steps.length;i++)if(current.steps[i].label!==label)assert.deepEqual(current.steps[i],old.steps[i]);
}
check('fusion_preview_and_authoritative_duplicate_star_gates_preserved',[
 'cards==6','ready==6','unique==5',"names['Forest Pup']","names['Miner Cat']","names['Crystal Fox']","names['Lava Dragon']","names['Secret Titan Golem']",
 "r:GetAttribute('InventoryActiveActionCount')==4",'fuse.Visible and fuse.Active',"fuse:GetAttribute('InventoryAction')=='Fuse'","fuse:GetAttribute('InventoryActionStyle')=='Fusion'",
 "detailVp:GetAttribute('PreviewPetName')=='Forest Pup'",'actionGeometry.valid',"layout.FillDirectionMaxCells",'button.AbsolutePosition.X','button.AbsoluteSize.X',
].every(token=>fusionStep.args.code.includes(token)||token==='button.AbsolutePosition.X'&&fusionStep.args.code.includes('object.AbsolutePosition.X')||token==='button.AbsoluteSize.X'&&fusionStep.args.code.includes('object.AbsoluteSize.X')),'Keep every original species/action/authority gate and observe the actual action layout.');
const accepts=(patterns,payload)=>patterns.every(pattern=>new RegExp(pattern).test(JSON.stringify(payload)));
const categoryPayload={ok:true,count:5,rows:[{frame:true,style:true,embeddedText:false,glyph:true,noRaster:true,sameSize:true,inside:false,visibleBoundsValid:true}]};
check('outer_category_oracle_accepts_expected_hidden_bounds_and_rejects_failure',accepts(categoryStep.expectRegex,categoryPayload)&&!accepts(oldCategoryStep.expectRegex,categoryPayload)&&!accepts(categoryStep.expectRegex,{...categoryPayload,ok:false}),'Outer result must not restore an unconditional inside=true requirement.');
const fusionPayload={ok:true,cards:6,ready:6,unique:5,actions:4,columns:2,actionGeometryValid:true,fuseActive:true,fuseStyle:'Fusion'};
check('outer_fusion_oracle_retains_two_actual_columns_and_all_semantics',accepts(fusionStep.expectRegex,fusionPayload)&&!accepts(fusionStep.expectRegex,{...fusionPayload,columns:0})&&!accepts(fusionStep.expectRegex,{...fusionPayload,actionGeometryValid:false})&&!accepts(fusionStep.expectRegex,{...fusionPayload,ok:false}),'Publish actual measured columns and preserve all original response gates.');
const chunks=[categoryFlow,fusionFlow].flatMap(flow=>[...flow.steps,...flow.cleanup].filter(step=>typeof step.args?.code==='string').map(step=>step.args.code));
const compilation=executeVisualOracle(chunks.map(code=>'assert(loadstring('+JSON.stringify(code)+'))').join('\n')+'\nprint("VISUAL_ORACLE_PASS compiled='+chunks.length+'")');
check('all_category_and_fusion_flow_chunks_compile',compilation.ok,compilation.output);
const responsiveOracleEvidence={categoryPositive:9,categoryNegative:13,fusionPositive:2,fusionNegative:16,rejectedMutations:rejectedVisualMutations,historicalRef:'85c51e5',historicalFailures:2,compiledChunks:chunks.length};
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
      responsiveOracleEvidence,
      files: [inventoryPath, viewModelPath, shopPath, gameConfigPath].map((filePath) =>
        path.relative(repositoryRoot, filePath)
      ),
    },
    null,
    2,
  ),
);
