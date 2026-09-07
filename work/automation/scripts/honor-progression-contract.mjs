import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import { spawnSync } from "node:child_process";
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
    && profile.includes("and 0.12 or 0.25")
    && profile.includes('assert(migrated.HonorPowerBonus == 0, "legacy Honor bonus was not cleared before v7 validation")'),
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
    && flowText.includes("local canvasExact=placement.valid")
    && flowText.includes("rootCanvas==canvas")
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

// Execute the exact live-flow scroll oracle; dimensions are observed GUI pixels.
const honorStep=flow.steps.find(step=>step.label==='world preview opens Inventory Honor and keeps the exact eighth unaffordable relic in view');
const placementHelper=block(honorStep.args.code,'local function verifyHonorScrollPlacement','local H=');
const candidates=[process.env.LUAU_COMMAND,...fs.readdirSync(os.tmpdir()).filter(name=>name.startsWith('codex-luau-')).sort().reverse().map(name=>path.join(os.tmpdir(),name,process.platform==='win32'?'luau.exe':'luau'))];
const luau=candidates.find(candidate=>candidate&&fs.existsSync(candidate))||'luau';
function executeOracle(code){
 const result=spawnSync(luau,[],{input:'local f=assert(loadstring('+JSON.stringify(code)+')) print("HONOR_ORACLE_COMPILED") f()\n',encoding:'utf8',timeout:20000,maxBuffer:4*1024*1024});
 const output=(result.stdout||'')+'\n'+(result.stderr||'');
 return {ok:!result.error&&result.status===0&&!result.stderr&&output.includes('HONOR_ORACLE_PASS'),compiled:output.includes('HONOR_ORACLE_COMPILED'),output};
}
const scrollCases=String.raw`
local passed=0
local function test(label,allowed,...)
 local result=verifyHonorScrollPlacement(...)
 assert(result.valid==allowed,label) passed+=1
end
test('authored_old_grid_zero_is_valid_when_fitted',true,50,150,0,200,0,200,0,0)
test('centered_interior',true,80,120,0,200,220,800,220,220)
test('top_boundary_clamped',true,0,50,0,200,0,800,0,0)
test('recorded_eighth_relic_bottom_clamped',true,500.5,604.5,161.5,612.5,449,900,449,449)
test('stale_root_diagnostic',false,500.5,604.5,161.5,612.5,449,900,0,449)
test('stale_screen_diagnostic',false,500.5,604.5,161.5,612.5,449,900,449,0)
test('unsettled_visible_but_not_centered',false,80,120,0,300,220,800,220,220)
test('selected_relic_is_clipped',false,602,706,161.5,612.5,449,900,449,449)
test('negative_scroll',false,50,150,0,200,-1,200,-1,-1)
test('beyond_canvas',false,50,150,0,200,601.5,800,601.5,601.5)
test('zero_height_viewport',false,50,150,0,0,0,800,0,0)
test('empty_card',false,50,50,0,200,0,200,0,0)
test('nonfinite_scroll',false,50,150,0,200,0/0,200,0,0)
print('HONOR_ORACLE_PASS cases='..passed)
`;
const scrollProgram=placementHelper+scrollCases;
const scrollResult=executeOracle(scrollProgram);
check('actual_honor_scroll_geometry_rejects_stale_or_clipped_selection',scrollResult.ok,scrollResult.output);
const mutations=[
 ['omit_center_or_clamp','and math.abs(canvas-expectedY)<=1','','unsettled_visible_but_not_centered'],
 ['ignore_diagnostic_coherence','local coherent=rootCanvas==canvas and screenCanvas==rootCanvas','local coherent=true','stale_root_diagnostic'],
 ['ignore_actual_card_containment','and cardTop>=viewTop-2 and cardBottom<=viewBottom+2','','selected_relic_is_clipped'],
 ['restore_obsolete_zero_scroll','local centeredOrClamped=canvas>=0 and canvas<=maxY+1 and math.abs(canvas-expectedY)<=1','local centeredOrClamped=canvas==0','centered_interior'],
 ['omit_scroll_clamp','math.clamp(canvas+(cardTop+cardBottom-viewTop-viewBottom)*.5,0,maxY)','canvas+(cardTop+cardBottom-viewTop-viewBottom)*.5','top_boundary_clamped'],
];
const rejectedMutations=[];
for(const [name,before,after,expected]of mutations){
 assert(scrollProgram.includes(before),name);
 const result=executeOracle(scrollProgram.replace(before,after));
 check('scroll_mutation_'+name,result.compiled&&!result.ok&&result.output.includes(expected),result.output);
 rejectedMutations.push(name);
}
const focusProducer=block(inventoryUi,'\t\tlocal lastInput = UserInputService:GetLastInputType()','\t\tself.Root:SetAttribute("InventoryHonorSelectedId", selectedId)');
const focusProgram=String.raw`
local Enum={UserInputType={Keyboard={Name='Keyboard'},MouseButton1={Name='MouseButton1'},Touch={Name='Touch'},Gamepad1={Name='Gamepad1'}}}
local GuiService={} local UserInputService={} local lastInput
function UserInputService:GetLastInputType()return lastInput end
local card={Selectable=true} local inView=true
local function apply()
`+focusProducer+String.raw`
end
local count=0
for _,name in ipairs({'Keyboard','Gamepad1','MouseButton1','Touch'})do
 for _,shown in ipairs({true,false})do for _,selectable in ipairs({true,false})do
  lastInput=Enum.UserInputType[name] inView=shown card.Selectable=selectable GuiService.SelectedObject=nil
  apply()
  local expected=shown and selectable and (name=='Keyboard' or name=='Gamepad1')
  assert((GuiService.SelectedObject==card)==expected,'focus ownership '..name)count+=1
 end end
end
print('HONOR_ORACLE_PASS focus='..count)
`;
const focusResult=executeOracle(focusProgram);
check('actual_inventory_focus_preserves_mouse_keyboard_and_gamepad_semantics',focusResult.ok,focusResult.output);
const focusMutant=executeOracle(focusProgram.replace('if selectionInput and inView and card.Selectable then','if inView and card.Selectable then'));
check('focus_mutation_rejects_mouse_focus_theft',focusMutant.compiled&&!focusMutant.ok&&focusMutant.output.includes('focus ownership MouseButton1'),focusMutant.output);
const historical=spawnSync('git',['show','85c51e5:work/automation/flows/honor-progression.json'],{cwd:path.resolve(root,'..'),encoding:'utf8',timeout:15000});
assert.equal(historical.status,0,historical.stderr);
const oldFlow=JSON.parse(historical.stdout);
const oldStep=oldFlow.steps.find(step=>step.label===honorStep.label);
assert.equal(flow.steps.length,oldFlow.steps.length);assert.deepEqual(flow.cleanup,oldFlow.cleanup);
for(let i=0;i<flow.steps.length;i++)if(flow.steps[i].label!==honorStep.label)assert.deepEqual(flow.steps[i],oldFlow.steps[i]);
const oldPredicate=block(oldStep.args.code,'local canvasExact=',' local ok=');
const oldResult=executeOracle('local grid={CanvasPosition={Y=449}} local rootCanvas=449 local screenCanvas=449 '+oldPredicate+' assert(canvasExact==false,"old zero-scroll predicate unexpectedly accepted recorded449") print("HONOR_ORACLE_PASS historical=1")');
check('recorded_449_scroll_reproduces_historical_zero_only_failure',oldResult.ok,oldResult.output);
const payload={ok:true,version:'HonorInventoryWorldSelectionV1',item:'eternal_crown_of_honor',key:'honor:eternal_crown_of_honor',canvas:449,scrollPlacementValid:true,state:'Insufficient',focused:false,catalog:8,visible:8};
const accepts=(patterns,value)=>patterns.every(pattern=>new RegExp(pattern).test(JSON.stringify(value)));
check('outer_honor_oracle_accepts_actual_nonzero_and_rejects_invalid_placement',accepts(honorStep.expectRegex,payload)&&!accepts(oldStep.expectRegex,payload)&&!accepts(honorStep.expectRegex,{...payload,scrollPlacementValid:false})&&!accepts(honorStep.expectRegex,{...payload,ok:false}),'Outer response predicates must follow the actual placement aggregate.');
const chunks=flow.steps.filter(step=>typeof step.args?.code==='string').map(step=>step.args.code).concat(flow.cleanup.filter(step=>typeof step.args?.code==='string').map(step=>step.args.code));
const compileResult=executeOracle(chunks.map(code=>'assert(loadstring('+JSON.stringify(code)+'))').join('\n')+'\nprint("HONOR_ORACLE_PASS compiled='+chunks.length+'")');
check('all_honor_flow_chunks_compile',compileResult.ok,compileResult.output);
const oracleEvidence={scrollCases:13,focusCases:16,rejectedMutations:[...rejectedMutations,'mouse_focus_theft'],historicalRef:'85c51e5',compiledChunks:chunks.length};
console.log(JSON.stringify({
  ok: true,
  passed: Object.values(results).filter(Boolean).length,
  total: Object.keys(results).length,
  depthMilestones: expectedDepth.length,
  rebirthMilestones: expectedRebirth.length,
  relics: expectedItems.length,
  checks: results,
  oracleEvidence,
}, null, 2));
