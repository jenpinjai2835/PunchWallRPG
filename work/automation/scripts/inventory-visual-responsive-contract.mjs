#!/usr/bin/env node
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import { spawnSync } from "node:child_process";
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
const flowPath = path.join(
  repositoryRoot,
  "work",
  "automation",
  "flows",
  "inventory-visual-responsive.json",
);
const source = fs.readFileSync(inventoryPath, "utf8").replace(/\r\n?/g, "\n");
const flowSource = fs.readFileSync(flowPath, "utf8").replace(/\r\n?/g, "\n");
const flow = JSON.parse(flowSource);
const checks = {};

function check(name, condition, detail) {
  checks[name] = condition === true;
  assert.equal(condition, true, `${name}: ${detail}`);
}

function block(start, end) {
  const startIndex = source.indexOf(start);
  assert.notEqual(startIndex, -1, `Missing start sentinel: ${start}`);
  const endIndex = source.indexOf(end, startIndex + start.length);
  assert.notEqual(endIndex, -1, `Missing end sentinel: ${end}`);
  return source.slice(startIndex, endIndex);
}


function runProductionLuau(name, code) {
  const optionIndex = process.argv.indexOf("--luau-tool-dir");
  const explicitDirectory = optionIndex >= 0
    ? process.argv[optionIndex + 1] : process.env.PUNCH_WALL_LUAU_TOOL_DIR;
  const directories = explicitDirectory ? [explicitDirectory] : [
    path.join(repositoryRoot, ".tools/luau"),
    ...String(process.env.PATH || "").split(path.delimiter),
    ...fs.readdirSync(os.tmpdir(), { withFileTypes: true })
      .filter((entry) => entry.isDirectory() && /^codex-luau-/i.test(entry.name))
      .map((entry) => path.join(os.tmpdir(), entry.name)),
  ];
  const executable = directories.filter(Boolean)
    .map((directory) => path.join(directory, process.platform === "win32" ? "luau.exe" : "luau"))
    .find((candidate) => fs.existsSync(candidate));
  assert(executable, "BLOCKED: Luau runtime unavailable; pass --luau-tool-dir or PUNCH_WALL_LUAU_TOOL_DIR");
  const temporaryDirectory = fs.mkdtempSync(path.join(os.tmpdir(), name + "-"));
  const temporaryFile = path.join(temporaryDirectory, "contract.luau");
  try {
    fs.writeFileSync(temporaryFile, code);
    const result = spawnSync(executable, [temporaryFile], { encoding: "utf8", timeout: 30000 });
    assert.ifError(result.error);
    assert.equal(result.status, 0, result.stderr || result.stdout || "Luau contract failed without output");
    return result.stdout.trim();
  } finally {
    if (fs.existsSync(temporaryFile)) fs.unlinkSync(temporaryFile);
    fs.rmdirSync(temporaryDirectory);
  }
}

const allocation = block(
  "local function allocateToolbarWidths(totalWidth, useCompact, touchTarget)",
  "local function hasTimedItem",
);
const categoryBuild = block(
  "for order, category in ipairs(CATEGORIES) do",
  'self.GridPane = create("Frame", self.Body',
);
const categoryVisual = block(
  "function InventoryUI:_applyCategoryVisual(category)",
  "function InventoryUI:_setCategoryInteractionState(category)",
);
const categoryInteraction = block(
  "function InventoryUI:_setCategoryInteractionState(category)",
  "function InventoryUI:_renderCategories()",
);
const responsive = block(
  "function InventoryUI:ApplyResponsive(viewport, compact, uiScale)",
  "function InventoryUI:_enabledActionNames",
);

check(
  "desktop_search_has_explicit_readable_minimum",
  allocation.includes("useCompact and touchTarget or 160")
    && responsive.includes(
      'self.Root:SetAttribute("InventorySearchMinimumWidth", toolbarWidths.minimumSearch * scale)',
    )
    && responsive.includes(
      'self.Root:SetAttribute("InventorySearchReadable", toolbarWidths.readable)',
    ),
  "Desktop allocation must target at least 160 px and expose the result.",
);

check(
  "toolbar_uses_real_grid_width",
  responsive.includes("local toolbarContentWidth = math.max(0, gridPaneWidth - 16)")
    && responsive.includes(
      "local toolbarWidths = allocateToolbarWidths(toolbarContentWidth, useCompact, touchTarget)",
    )
    && responsive.includes("self.Search.Size = UDim2.fromOffset(searchWidth, toolbarHeight)")
    && responsive.includes(
      "searchWidth + toolbarGap + rarityWidth + toolbarGap",
    ),
  "Search, rarity, and capacity widths must share the actual GridPane toolbar width.",
);

check(
  "narrow_grid_reduces_columns_before_overflow",
  responsive.includes("local gridContentWidth = math.max(1, gridPaneWidth - 24)")
    && responsive.includes("local fittingColumns = math.max(")
    && responsive.includes(
      "local columns = math.min(preferredColumns, fittingColumns)",
    )
    && responsive.includes(
      "math.floor((gridContentWidth - (columns - 1) * padding) / columns)",
    ),
  "A narrow scaled grid must reduce its column count instead of relying on a synthetic 280 logical px width.",
);

check(
  "rendered_bounds_are_runtime_observable",
  responsive.includes(
    'self.Root:SetAttribute("InventoryRenderedWindowWidth", windowWidth * scale)',
  )
    && responsive.includes(
      'self.Root:SetAttribute("InventoryRenderedWindowHeight", windowHeight * scale)',
    )
    && responsive.includes(
      '"InventoryWindowBoundsSafe"',
    )
    && source.includes(
      'renderedWindowWidth = tonumber(self.Root:GetAttribute("InventoryRenderedWindowWidth")) or 0',
    )
    && source.includes(
      'boundsSafe = self.Root:GetAttribute("InventoryWindowBoundsSafe") == true',
    ),
  "Tester snapshots need the calculated rendered size and safe-bounds invariant.",
);

check(
  "runtime_flow_covers_narrow_phone_scale_matrix",
  flow.name === "inventory-visual-responsive"
    && flowSource.includes("Inventory Visual QA Phone 568x320")
    && flowSource.includes("for _,scale in ipairs({.8,1,1.2})")
    && flowSource.includes("l.boundsSafe and l.insideSafeArea")
    && flowSource.includes("l.minTouchTarget>=43.5")
    && flowSource.includes("l.toolbarNoOverlap")
    && flowSource.includes("Inventory_Visual_Responsive_Phone_568x320_Scale120")
    && flow.cleanup.some(
      (step) =>
        step.tool === "execute_luau"
        && String(step.args?.code || "").includes(
          "Inventory Visual QA Phone 568x320",
        ),
    ),
  "The Studio handoff flow must exercise all supported scales on a narrow phone and clean up its custom device.",
);

check(
  "toolbar_overlap_contract_is_observable",
  allocation.includes("noOverlap = usedWidth <= totalWidth")
    && responsive.includes(
      'self.Toolbar:SetAttribute("InventoryToolbarNoOverlap", toolbarWidths.noOverlap)',
    )
    && responsive.includes(
      'self.Root:SetAttribute("InventoryToolbarNoOverlap", toolbarWidths.noOverlap)',
    )
    && source.includes(
      'searchWidth = tonumber(self.Root:GetAttribute("InventorySearchExpectedWidth")) or 0',
    )
    && source.includes(
      'toolbarNoOverlap = self.Root:GetAttribute("InventoryToolbarNoOverlap") == true',
    ),
  "The allocator and runtime hierarchy must expose the no-overlap invariant.",
);

check(
  "category_pointer_and_selection_states_are_connected_once",
  [
    "button.Activated",
    "button.MouseEnter",
    "button.MouseLeave",
    "button.SelectionGained",
    "button.SelectionLost",
  ].every((token) => categoryBuild.includes(token))
    && categoryBuild.includes(
      'self.Root:SetAttribute("InventoryCategoryConnectionCount", #CATEGORIES * 5)',
    ),
  "Every category needs one activation, pointer pair, and selection pair.",
);

check(
  "selected_state_precedes_hover_state",
  categoryVisual.includes(
    'local state = selected and "Selected" or hovered and "Hovered" or "Idle"',
  )
    && categoryVisual.includes(
      "widgets.stroke.Color = selected and PALETTE.Cyan",
    )
    && categoryVisual.includes(
      "widgets.indicator.Visible = selected or hovered",
    )
    && categoryVisual.includes(
      "widgets.arrow.Visible = selected and not self._layout.compact",
    ),
  "Selected chrome must win over pointer or keyboard focus styling.",
);

check(
  "hover_state_is_observable_and_source_aware",
  categoryInteraction.includes(
    "widgets.hovered = widgets.pointerHovered == true or widgets.selectionHovered == true",
  )
    && categoryInteraction.includes(
      'self.Root:SetAttribute("InventoryHoveredCategory", category)',
    )
    && categoryVisual.includes(
      'widgets.button:SetAttribute("InventoryVisualState", state)',
    ),
  "Hover must remain active while either pointer or selection focus owns it.",
);

check(
  "category_interaction_has_no_render_loop_or_connection_churn",
  !categoryVisual.includes(":Connect(")
    && !categoryInteraction.includes(":Connect(")
    && !categoryVisual.includes("RunService")
    && !categoryInteraction.includes("RunService")
    && !categoryVisual.includes("task.")
    && !categoryInteraction.includes("task."),
  "A hover transition may only update the existing bounded widget set.",
);

check(
  "capacity_copy_adapts_without_hiding_full_value",
  source.includes('InventoryCapacityTextMode", "Compact"')
    && source.includes('InventoryCapacityTextMode", "Condensed"')
    && source.includes('InventoryCapacityTextMode", "Full"')
    && source.includes('InventoryCapacityFullText", fullText'),
  "Narrow capacity chrome must retain an inspectable full semantic label.",
);

const code=String.raw`
local function vec2(x,y) return {X=x,Y=y,__kind='Vector2'} end
local Vector2={new=vec2,zero=vec2(0,0)}
local UDim={new=function(s,o)return {Scale=s,Offset=o}end}
local UDim2={new=function(xs,xo,ys,yo)return {X={Scale=xs,Offset=xo},Y={Scale=ys,Offset=yo}}end}
UDim2.fromOffset=function(x,y)return UDim2.new(0,x,0,y)end
local function typeof(x)return type(x)=='table' and x.__kind or type(x) end
local Enum=setmetatable({},{__index=function(t,k)local v=setmetatable({},{__index=function(_,v)return v end});rawset(t,k,v);return v end})
local function node()
 local result={Visible=true,attrs={},AbsoluteSize=vec2(0,0),Position=UDim2.fromOffset(0,0),Size=UDim2.fromOffset(0,0),AnchorPoint=Vector2.zero}
 result.SetAttribute=function(self,k,v)self.attrs[k]=v end
 result.GetAttribute=function(self,k)return self.attrs[k] end
 result.IsA=function(_,k)return k=='TextButton' end
 return setmetatable(result,{__index=function(t,k)local n=node();rawset(t,k,n);return n end})
end
local CATEGORIES={'All','Fists','Pets','Boosts','Honor'}
local RARITIES={'All','Common','Uncommon','Rare','Epic','Legendary','Mythic','Secret'}
local WIDE_CATEGORY_WIDTH=164
local WIDE_CATEGORY_GAP=12
local InventoryUI={}
`+block('local function allocateToolbarWidths(', 'local function hasTimedItem(')+block('function InventoryUI:ApplyResponsive(', 'function InventoryUI:_enabledActionNames(')+String.raw`
local count=0
local function check(ok,message) count+=1;assert(ok,message) end
local function near(a,b)return math.abs(a-b)<.01 end
local function makeSelf(actions)
 local self=setmetatable({_layout={},_rarityButtons={},_cardPool={},_categoryButtons={},_activeActionButtons={},EmptySlotLabels={},_sparseSlotPool={},DetailStatRows={},_snapshot=false,_category='All',_detailExpanded=true,_selectedItem={key='pet:1'},_selectedKey='pet:1',_search='cat'}, {__index=function(t,k)
  local n=node();rawset(t,k,n);return n
 end})
 for _,name in ipairs({'_updateCapacity','_setRarityMenu','_syncDetailVisibility'}) do self[name]=function()end end
 for _,name in ipairs(CATEGORIES)do self._categoryButtons[name]={button=node(),padding=node(),icon=node(),indicator=node(),arrow=node()}end
 for i=1,actions do table.insert(self._activeActionButtons,node())end
 local card={}
 for _,name in ipairs({'rarity','quantity','equipped','locked','lockedMessage','footerRail','artFrame','name','nameTextLimit'})do card[name]=node()end
 card.quantity.Visible=true
 table.insert(self._cardPool,card)
 self.DetailStatus.Visible=false
 self.Grid.CanvasPosition=vec2(0,93)
 return self
end
for _,viewport in ipairs({{296,716},{336,616},{366,736},{716,296},{616,336},{576,316},{796,366},{876,466},{716,260},{776,315}}) do
 for _,scale in ipairs({.8,1,1.2})do
  for actions=1,4 do
   local s=makeSelf(actions)
   InventoryUI.ApplyResponsive(s,vec2(viewport[1],viewport[2]),true,scale)
   local prefix=tostring(viewport[1])..'x'..tostring(viewport[2])..'@'..tostring(scale)..'/'..actions..': '
   check(near(s.Window.Size.X.Offset*scale,viewport[1]),prefix..'host width')
   check(near(s.Window.Size.Y.Offset*scale,viewport[2]),prefix..'host height')
   check(near(s.GridLayout.CellSize.Y.Offset*scale,92),prefix..'row height')
   check(s._layout.columns==(s.Root.attrs.InventoryAvailableGridWidth>=600 and 2 or 1),prefix..'column breakpoint')
   check(s._cardPool[1].name.TextSize*scale>=14,prefix..'primary text')
   check(s._cardPool[1].rarity.TextSize*scale>=12,prefix..'secondary text')
   check(s.Grid.CanvasPosition.Y==93 and s._selectedKey=='pet:1' and s._search=='cat',prefix..'state retained')
   check(#s._cardPool==1 and #s._activeActionButtons==actions,prefix..'pool retained')
   local card=s._cardPool[1]
   local width=s.GridLayout.CellSize.X.Offset
   local gridUsed=width*s._layout.columns+(s._layout.columns-1)*s.GridLayout.CellPadding.X.Offset
   check(gridUsed*scale<=s.Root.attrs.InventoryAvailableGridWidth+.01,prefix..'grid cells within content')
   local categoryUsed=s._categoryButtons.All.button.Size.X.Offset*#CATEGORIES+(#CATEGORIES-1)*s.CategoryLayout.Padding.Offset+s.CategoryPadding.PaddingLeft.Offset+s.CategoryPadding.PaddingRight.Offset
   check(categoryUsed<=s.Window.Size.X.Offset-24+.01,prefix..'category controls within bar')
   check(card.equipped.Position.X.Offset+card.equipped.Size.X.Offset<=width-card.quantity.Size.X.Offset-8/scale,prefix..'state quantity separation')
   check(s.DetailActionLayout.CellSize.X.Offset*scale>=44 and s.DetailActionLayout.CellSize.Y.Offset*scale>=44,prefix..'actions touch target')
   local action=s.DetailActions
   local panelWidth=s.Window.Size.X.Offset-24
   check(action.Position.X.Offset>=0 and action.Position.X.Offset+action.Size.X.Offset<=panelWidth+.01,prefix..'actions x bounds')
   check(action.Position.Y.Offset>=0 and action.Position.Y.Offset+action.Size.Y.Offset<=s.Detail.Size.Y.Offset+.01,prefix..'actions y bounds')
   local used=s.DetailActionLayout.CellSize.X.Offset*s.DetailActionLayout.FillDirectionMaxCells+(s.DetailActionLayout.FillDirectionMaxCells-1)*s.DetailActionLayout.CellPadding.X.Offset
   check(used<=action.Size.X.Offset+.01,prefix..'action grid within panel')
   check(s.Root.attrs.InventoryToolbarNoOverlap,prefix..'toolbar')
   s._detailExpanded=false
   InventoryUI.ApplyResponsive(s,vec2(viewport[1],viewport[2]),true,scale)
   check(s.Grid.Visible and s.GridPane.Visible and s.Grid.CanvasPosition.Y==93,prefix..'drawer return retains scroll')
   InventoryUI.ApplyResponsive(s,vec2(1280,800),false,1)
   check(not s._cardPool[1].name.TextScaled and s.DetailInternalName.Visible and s._categoryButtons.Boosts.button.Text=='BOOSTS',prefix..'desktop restores readable rows')
  end
 end
end
-- Test both sides at every scale and the exact inclusive boundary at 100%.
-- A double-based Vector2 mock cannot represent fractional scaled pixels exactly.
for _,scale in ipairs({.8,1,1.2}) do
 for _,availableGridWidth in ipairs(scale==1 and {599,600,601} or {599,601}) do
  local s=makeSelf(1)
  InventoryUI.ApplyResponsive(s,vec2(availableGridWidth+48*scale,616),true,scale)
  check(s._layout.columns==(availableGridWidth>=600 and 2 or 1),'inclusive rendered column breakpoint: '..tostring(scale)..' / '..tostring(availableGridWidth)..' / actual '..tostring(s.Root.attrs.InventoryAvailableGridWidth)..' / columns '..tostring(s._layout.columns))
 end
end
-- Execute the production allocator, including its desktop minimum and compact collapse.
for _,width in ipairs({379,440,640}) do
 local result=allocateToolbarWidths(width,false,44)
 check(result.search>=160 and result.capacity>=44 and result.rarity>=44 and result.used<=width,'desktop toolbar allocation')
end
for _,width in ipairs({280,320,400}) do
 local result=allocateToolbarWidths(width,true,44)
 check(result.search>=44 and result.capacity>=44 and result.rarity>=44 and result.used<=width,'compact toolbar allocation')
end
-- Real desktop layout must retain text floors at every scale. Increasing UI scale
-- switches a too-narrow three-pane host to compact before its toolbar overlaps.
for _,viewport in ipairs({{900,600},{980,620},{1100,720},{1277,780},{1600,900}}) do
 for _,scale in ipairs({.8,1,1.2})do
  for actions=1,4 do
   local s=makeSelf(actions)
   InventoryUI.ApplyResponsive(s,vec2(viewport[1],viewport[2]),false,scale)
   local c=s._cardPool[1]
   local prefix='desktop '..tostring(viewport[1])..'@'..tostring(scale)..'/'..tostring(actions)..': '
   check(not c.name.TextScaled and c.name.TextSize*scale>=14,prefix..'desktop primary floor')
   check(c.rarity.TextSize*scale>=12 and c.equipped.TextSize*scale>=12 and c.locked.TextSize*scale>=12,prefix..'desktop secondary floor')
   check(s.Empty.TextSize*scale>=12,prefix..'no-results secondary floor')
   check(s._layout.columns<=2 and s._layout.columns>=1,prefix..'bounded columns')
   local width=s.GridLayout.CellSize.X.Offset
   check(width*scale>=280,prefix..'readable row width')
   check(near(s.GridLayout.CellSize.Y.Offset*scale,s._layout.compact and 92 or 104),prefix..'readable row height')
   check(s.Root.attrs.InventoryToolbarNoOverlap,prefix..'desktop toolbar no overlap')
   check(c.artFrame.Position.X.Offset+c.artFrame.Size.X.Offset<=c.name.Position.X.Offset,prefix..'art name separation')
   check(c.name.Position.Y.Offset+c.name.Size.Y.Offset<=c.rarity.Position.Y.Offset,prefix..'name rarity separation')
   check(c.equipped.Position.X.Offset+c.equipped.Size.X.Offset<=width-c.quantity.Size.X.Offset-8/scale,prefix..'desktop state quantity separation')
   check(width*s._layout.columns+(s._layout.columns-1)*s.GridLayout.CellPadding.X.Offset<=s.Root.attrs.InventoryAvailableGridWidth/scale+.01,prefix..'desktop grid bounds')
   check(s.Grid.CanvasPosition.Y==93 and s._selectedKey=='pet:1' and s._search=='cat',prefix..'desktop state retained')
   check(s.DetailActionLayout.CellSize.X.Offset*scale>=44 and s.DetailActionLayout.CellSize.Y.Offset*scale>=44,prefix..'desktop actions touch')
  end
 end
end
print('Inventory production ApplyResponsive: '..count..' assertions passed')
`;

const productionOutput = runProductionLuau("inventory-responsive-contract", code);
assert.match(productionOutput, /Inventory production ApplyResponsive: 2953 assertions passed/);
const polishSource = fs.readFileSync(path.join(repositoryRoot, "work/punch-wall-rpg/src/shared/PolishConfig.lua"), "utf8").replace(/\r\n?/g, "\n");
const rarityMapping = polishSource.match(/PolishConfig\.RarityColors = \{[\s\S]*?\n\}/)?.[0];
assert(rarityMapping, "Missing shared rarity mapping");
const premiumFlow = JSON.parse(fs.readFileSync(path.join(repositoryRoot, "work/automation/flows/inventory-premium-readability.json"), "utf8"));
const actualVerification = premiumFlow.steps.find((step) => step.label === "actual Inventory dimensions, semantic colors, selection, search and pet actions").args.code;
const fitHelper = actualVerification.slice(actualVerification.indexOf("local function fits("), actualVerification.indexOf("local function cardByKey("));
assert(fitHelper.startsWith("local function fits("), "Missing actual TextBounds verifier");
const semanticCode = String.raw`
local Color3={fromRGB=function(r,g,b)return {R=r/255,G=g/255,B=b/255,__kind='Color3'}end}
local function typeof(v)return type(v)=='table' and v.__kind or type(v)end
local PolishConfig={}
` + rarityMapping + "\n" + block("local PALETTE = {", "-- UIGradient")
  + block("local RARITY_COLORS = {", "local function create(")
  + block("local function asColor(", "local function itemAccent(")
  + block("local function itemRarityColor(", "local function actionName(")
  + fitHelper + String.raw`
local count=0
local function check(value,message)count+=1;assert(value,message)end
for rarity,expected in pairs(PolishConfig.RarityColors)do
 local original=Color3.fromRGB(255,0,255)
 local item={rarity=rarity,accent=original}
 check(itemRarityColor(item)==expected,'shared rarity ignores model accent '..rarity)
 check(item.accent==original,'model accent unchanged '..rarity)
end
check(itemRarityColor(nil)==PolishConfig.RarityColors.Common,'empty defaults to common')
check(itemRarityColor({rarity='Premium'})==RARITY_COLORS.Premium,'premium fallback')
check(itemRarityColor({rarity='Unmapped',accent=Color3.fromRGB(255,0,255)})==PALETTE.Muted,'unknown is semantic neutral')
local function label()
 return {Text='Readable',TextScaled=false,TextSize=14,TextFits=true,TextBounds={X=80,Y=17},AbsoluteSize={X=180,Y=36},GetFullName=function()return 'actual label' end}
end
check(pcall(fits,label(),14,1),'valid text accepted')
for _,mutate in ipairs({
 function(x)x.TextScaled=true end,
 function(x)x.TextSize=13 end,
 function(x)x.TextFits=false end,
 function(x)x.TextBounds.X=182 end,
 function(x)x.TextBounds.Y=38 end,
})do local x=label();mutate(x);check(not pcall(fits,x,14,1),'invalid actual text rejected')end
check(not pcall(fits,label(),14,.8),'rendered scale floor enforced')
print('Inventory semantic/text helper: '..count..' assertions passed')
`;
const semanticOutput = runProductionLuau("inventory-semantic-contract", semanticCode);
assert.match(semanticOutput, /Inventory semantic\/text helper: 20 assertions passed/);
let baselineProof;
const baselineIndex = process.argv.indexOf("--readability-baseline");
if (baselineIndex >= 0) {
  const ref = process.argv[baselineIndex + 1];
  assert(ref, "--readability-baseline requires a Git ref");
  const result = spawnSync("git", ["show", `${ref}:work/punch-wall-rpg/src/client/InventoryUI.lua`], {cwd: repositoryRoot, encoding:"utf8"});
  assert.equal(result.status, 0, result.stderr);
  const baseline = result.stdout.replace(/\r\n?/g, "\n");
  const begin = baseline.indexOf("function InventoryUI:ApplyResponsive(");
  const end = baseline.indexOf("function InventoryUI:_enabledActionNames(", begin);
  assert(begin >= 0 && end > begin, "Missing baseline layout");
  assert.throws(() => runProductionLuau("inventory-readability-baseline", code.replace(responsive, baseline.slice(begin,end))), /desktop restores readable rows|desktop primary floor|readable row width|no-results secondary floor/);
  baselineProof = {ref, intendedFailure:true};
}
const mutationChecks = [];
if (process.argv.includes("--self-test")) {
  for (const [name, original, replacement, failure] of [
    ["duplicate_inset", "and availableWidth\n", "and (availableWidth - 40)\n", /host width/],
    ["tiny_primary_text", "math.ceil(14 / scale)", "math.ceil(10 / scale)", /primary text/],
    ["early_two_column_breakpoint", "gridContentWidth * scale >= 600", "gridContentWidth * scale >= 500", /column breakpoint/],
    ["oversized_grid_cells", "math.floor((gridContentWidth - (columns - 1) * padding) / columns)", "100 + math.floor((gridContentWidth - (columns - 1) * padding) / columns)", /grid cells within content/],
    ["tiny_desktop_primary_text", "cardRef.name.TextSize = primaryTextSize", "cardRef.name.TextSize = useCompact and primaryTextSize or 10", /desktop primary floor/],
    ["tiny_desktop_empty_text", "self.Empty.TextSize = secondaryTextSize", "self.Empty.TextSize = useCompact and secondaryTextSize or 12", /no-results secondary floor/],
    ["scale_ignores_available_width", " or availableWidth < 900", "", /readable row width/],
  ]) {
    assert(code.includes(original), `Missing mutation target: ${name}`);
    assert.throws(() => runProductionLuau("inventory-responsive-mutation", code.replace(original, replacement)), failure);
    mutationChecks.push(name);
  }
  assert.throws(() => runProductionLuau("inventory-semantic-mutation", semanticCode.replace("PolishConfig.RarityColors[rarity]", "item and item.accent")), /shared rarity ignores model accent/);
  mutationChecks.push("rarity_uses_model_accent");
  assert.throws(() => runProductionLuau("inventory-text-mutation", semanticCode.replace("label.TextFits and label.TextBounds.X<=label.AbsoluteSize.X+1 and label.TextBounds.Y<=label.AbsoluteSize.Y+1", "true")), /invalid actual text rejected/);
  mutationChecks.push("text_clipping_guard_removed");
}
const passed = Object.values(checks).filter(Boolean).length;
console.log(
  JSON.stringify(
    {
      ok: passed === Object.keys(checks).length,
      passed,
      total: Object.keys(checks).length,
      checks,
      productionOutput,
      semanticOutput,
      baselineProof,
      mutationChecks,
      limitation: "UI value mocks do not render Roblox text or establish device performance",
      files: [
        path.relative(repositoryRoot, inventoryPath),
        path.relative(repositoryRoot, flowPath),
      ],
    },
    null,
    2,
  ),
);
