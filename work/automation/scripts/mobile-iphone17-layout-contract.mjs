import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import { spawnSync } from "node:child_process";

const root = path.resolve(import.meta.dirname, "..", "..");
const read = (...parts) => fs.readFileSync(path.join(root, ...parts), "utf8");
const client = read("punch-wall-rpg", "src", "client", "PunchWallClient.client.lua").replace(/\r\n/g, "\n");
const inventory = read("punch-wall-rpg", "src", "client", "InventoryUI.lua");
const flowText = read("automation", "flows", "mobile-iphone17-layout.json");
const flow = JSON.parse(flowText);
const labels = new Set(flow.steps.map((step) => step.label));

const checks = [
  ["responsive_profiles_are_dimension_driven", client.includes('return "PhoneLandscape", true') && client.includes('return "TabletTouch", true') && client.includes('return "Desktop", false')],
  ["iphone_reference_is_exact", flowText.includes("Width=874,Height=402,PixelDensity=460") && flowText.includes("DeviceForm=Enum.DeviceForm.Phone")],
  ["punch_and_jump_share_balanced_action_size", client.includes('referencePunch:SetAttribute("ResponsiveProfile", "PhoneLandscapeEqualActionV5")') && client.includes('referenceJump:SetAttribute("ResponsiveProfile", "PhoneLandscapeEqualActionV5")') && client.includes('referenceHUD:SetAttribute("PhoneActionOrder", "PunchThenJump")') && client.includes('referencePunch.Size = UDim2.fromOffset(actionSize, actionSize)') && client.includes('local jumpSize = actionSize') && client.includes('referenceJump.Size = UDim2.fromOffset(jumpSize, jumpSize)')],
  ["active_joystick_is_ten_percent_tighter", client.includes('referenceJoystick:SetAttribute("ResponsiveProfile", "PhoneLandscapeJoystickTightV4")') && client.includes("local joystickSize = math.max(90")],
  ["active_directions_are_compact", client.includes('"PhoneLandscapeDirectionPair44V4"')],
  ["phone_menu_is_sparse_and_tighter", client.includes('"PhoneLandscape2x2TightV4"') && client.includes("local compactMenuGap = 4") && client.includes("referenceQuests.Visible = false") && client.includes('"CompactQuestsRoutedThroughMissions"')],
  ["phone_information_has_aligned_four_stat_row", client.includes('"PhoneLandscapeStatRowHonorAlignedV5"') && client.includes('"FourStatsAlignedNoDowntownV5"') && client.includes("UDim2.fromOffset(math.min(280, viewport.X - 136), 36)")],
  ["downtown_card_is_disabled_until_feature_release", client.includes('NextWorldCard.Visible = false') && client.includes('NextWorldCard:SetAttribute("DisabledReason", "DowntownNotReleased")')],
  ["settings_is_the_top_right_utility", client.includes('shared.PunchWallSettingsToolButton,\n\t\t\tshared.PunchWallSoundToolButton,\n\t\t\tshared.PunchWallMoreToolButton')],
  ["settings_window_uses_the_gear_asset", client.includes('"SettingsWindow",\n\t"SETTINGS",\n\tColor3.fromRGB(46, 205, 255),\n\t"SettingsTool"')],
  ["inventory_uses_readable_rows_and_single_lock_state", inventory.includes('"PhoneReadableRowsV6"') && inventory.includes('"HorizontalPreviewV5"') && inventory.includes("math.ceil(14 / scale)") && inventory.includes("math.ceil(12 / scale)") && inventory.includes('"InventoryLockedLabelCount"')],
  ["shop_uses_full_width_readable_mobile_rows", client.includes('"MobileReadableRowsV1"') && client.includes("local catalogColumns = (compactCards or desktopRows) and 1 or 2") && client.includes("local scrollCardHeight = compactCards and 112 or 154") && client.includes("productNameSize.MinTextSize = 14") && client.includes("rarityLabel.TextSize = 12")],
  ["coin_boost_is_not_in_coin_shop", !client.includes('key = "CoinBoost",\n\t\t\tname = "COIN BOOST"') && flowText.includes("MobileReadableRowsV1")],
  ["phone_context_lane_is_clear", client.includes('"PhoneTwoLineCenterLane56V4"') && client.includes("PunchWallContextActionButton.Size = UDim2.fromOffset(224, 56)") && client.includes('"PresentationVersion", "TwoLineCompactV2"')],
  ["compact_modals_share_safe_margin", client.includes('"PhoneSafeFill12V1"') && client.includes('SetAttribute("CompactModalSafeMargin", 12)')],
  ["settings_options_render_above_row_chrome", client.includes("button.ZIndex = optionArea.ZIndex + 1")],
  ["spin_is_isolated_and_safe", client.includes("local edgeMargin = compact and 32 or 18") && client.includes("referenceHUD.Visible = false") && client.includes('close:SetAttribute("MinimumEffectiveTouchTarget", 44)')],
  ["runtime_diagnostics_fail_closed", ["PhonePrimaryTargetsPass", "PhonePrimaryBoundsPass", "PhonePrimaryPairwisePass", "PhoneControlCoveragePass", "PhonePunchMaximumPass", "PhoneJoystickMaximumPass"].every((token) => client.includes(token))],
  ["flow_targets_named_artifact_without_stale_session_id", !flow.studioInstanceId && flow.studioName === "^PunchWallRPGPlayable_v1_final[.]rbxlx$" && flow.placeName === flow.studioName],
  ["flow_covers_every_surface", ["premium pet equipped notice stays compact", "Inventory All uses bounded phone drawer", "Inventory Pets and Honor retain compact detail behavior", "all five Shop pages fit iPhone 17", "Missions surface is safe", "Rebirth compact header and action fit", "Settings rows stay contained", "Hero Spin is isolated and touch safe"].every((label) => labels.has(label))],
  ["flow_checks_hud_hierarchy", labels.has("iPhone HUD is bounded sparse and touch safe") && labels.has("top information hierarchy is clear") && flowText.includes("PhoneLandscapeV5") && flowText.includes("FourStatsAlignedNoDowntownV5")],
  ["flow_has_clean_lifecycle", labels.has("runtime console clean") && labels.has("post-stop console clean") && labels.has("restore simulator default")],
  ["flow_checks_real_shop_tab_input_without_claiming_screenshots", flow.steps.filter(step => step.tool === "user_mouse_input").length === 4 && !flowText.includes("screen_capture")],
];

checks.push(
  ["runtime_measures_actual_safe_viewport", flowText.includes("safe.AbsoluteSize") && flowText.includes("parent.AbsolutePosition") && flowText.includes("responsive viewport disagrees with rendered safe area")],
  ["runtime_checks_rendered_font_and_bounds", flowText.includes("local function renderedFloor") && flowText.includes("UITextSizeConstraint") && flowText.includes("UIScale") && flowText.includes("readable(x,14)") && flowText.includes("readable(rarity,12)") && flowText.includes("TextBounds")],
  ["runtime_requires_measured_controls_and_scroll", flowText.includes("touch(x,44)") && flowText.includes("touch(action,48)") && flowText.includes("CanvasPosition") && flowText.includes("catalog cannot reach final row") && flowText.includes("inventory scroll or card identity changed")],
  ["runtime_uses_real_open_tab_path", !flowText.includes("OpenShopPage") && !flowText.includes("AutomationTab") && flowText.includes("Invoke('OpenTab','Fists')") && flowText.includes("real Shop tab did not select requested page")],
  ["no_dense_mobile_acceptance_remains", !/PhoneDenseBalancedV5|StatusRailV4|MobileCatalogDenseV3|columns>=5|cardHeight<=94/.test(flowText)],
);

for (const [name, passed] of checks) assert.equal(passed, true, name);
// Execute the exact runtime assertion helpers rather than a second JS approximation.
const helperStep = flow.steps.find(step => step.label === "Inventory All uses bounded phone drawer");
const helpers = helperStep.args.code.split("-- BEGIN MEASURED MOBILE ASSERTIONS\n")[1]?.split("-- END MEASURED MOBILE ASSERTIONS")[0];
assert.ok(helpers, "missing runtime measurement helpers");
let helperCopies = 0;
for (const name of ["mobile-iphone17-layout", "device-matrix-hud-shop", "training-ui-pet-recovery"]) {
  const candidateFlow = JSON.parse(read("automation", "flows", `${name}.json`));
  for (const step of candidateFlow.steps) {
    const code = step.args?.code || "";
    if (!code.includes("-- BEGIN MEASURED MOBILE ASSERTIONS")) continue;
    const copy = code.split("-- BEGIN MEASURED MOBILE ASSERTIONS\n")[1]?.split("-- END MEASURED MOBILE ASSERTIONS")[0];
    assert.equal(copy, helpers, `${name}: ${step.label}: measured assertion helper drift`);
    helperCopies += 1;
  }
}
assert.equal(helperCopies, 13, "every measured Shop/Inventory flow must share the executed assertions");

const objectiveStep=flow.steps.find(step=>step.label==='top information hierarchy is clear');
const objectiveHelpers=objectiveStep.args.code.split('-- BEGIN MOBILE OBJECTIVE ASSERTIONS\n')[1]?.split('-- END MOBILE OBJECTIVE ASSERTIONS')[0];
assert(objectiveHelpers,'missing actual objective geometry/readability helper');
const objectiveBaseline=spawnSync('git',['show','85c51e5:work/automation/flows/mobile-iphone17-layout.json'],{cwd:path.resolve(root,'..'),encoding:'utf8'});
assert.equal(objectiveBaseline.status,0,objectiveBaseline.stderr);
const oldMobile=JSON.parse(objectiveBaseline.stdout);
const oldObjectiveFragment='local objectiveCompact=objects.TutorialObjectiveHUD.AbsoluteSize.X<=220 and objects.TutorialObjectiveHUD.AbsoluteSize.Y<=30 and objects.TutorialObjectiveHUD.AbsolutePosition.Y>=stats[1].AbsolutePosition.Y+stats[1].AbsoluteSize.Y';
const newObjectiveFragment="local objectiveCompact=verifyMobileObjective(objects.TutorialObjectiveHUD,objects.TutorialObjectiveHUD:FindFirstChild('ObjectiveText'),h) and objects.TutorialObjectiveHUD.AbsolutePosition.Y>=stats[1].AbsolutePosition.Y+stats[1].AbsoluteSize.Y";
function verifyObjectiveFlowShape(candidate){
 const actual=structuredClone(candidate);
 const step=actual.steps.find(s=>s.label==='top information hierarchy is clear');
 assert(step.args.code.includes(newObjectiveFragment),'actual current objective assertion required');
 step.args.code=step.args.code.split('-- END MOBILE OBJECTIVE ASSERTIONS\n')[1].replace(newObjectiveFragment,oldObjectiveFragment);
 assert.deepEqual(actual,oldMobile,'all unrelated hierarchy, interaction, and cleanup gates must remain unchanged');
}
verifyObjectiveFlowShape(flow);
const compactObjectiveStart=client.indexOf('\t\tshared.PunchWallHUDWidgets.ObjectiveCard.AnchorPoint',client.indexOf('-- Phone information hierarchy:'));
const compactObjectiveEnd=client.indexOf('\n\t\tlocal honorCard',compactObjectiveStart);
assert(compactObjectiveStart>=0&&compactObjectiveEnd>compactObjectiveStart);
const objectiveProducer=client.slice(compactObjectiveStart,compactObjectiveEnd);
const objectiveTextProducer=client.split('\twidgets.ObjectiveText.Position = ')[1]?.split('\n\twidgets.ObjectiveText.Font')[0];
assert(objectiveTextProducer,'actual objective text rectangle missing');
const objectiveFixture=String.raw`
local function object(name,kind,parent)
 local value={Name=name,ClassName=kind,Parent=parent,children={},Visible=true,Text='PUNCH THE WALL',TextSize=14,TextScaled=true,TextFits=true,TextBounds={X=150,Y=14}}
 if parent then table.insert(parent.children,value)end
 function value:IsA(k)return k==self.ClassName or k=='GuiObject'and(self.ClassName=='Frame'or self.ClassName=='TextLabel')end
 function value:FindFirstChildOfClass(k)for _,child in ipairs(self.children)do if child:IsA(k)then return child end end end
 return value
end
local Vector2={new=function(x,y)return {X=x,Y=y}end}
local UDim2={}
function UDim2.new(x,xo,y,yo)return {X={Scale=x,Offset=xo},Y={Scale=y,Offset=yo}}end
function UDim2.fromOffset(x,y)return UDim2.new(0,x,0,y)end
function UDim2.fromScale(x,y)return UDim2.new(x,0,y,0)end
local function resolve(object,parent)
 local size,position=object.Size,object.Position
 local width,height=size.X.Scale*parent.AbsoluteSize.X+size.X.Offset,size.Y.Scale*parent.AbsoluteSize.Y+size.Y.Offset
 local anchor=object.AnchorPoint or {X=0,Y=0}
 object.AbsoluteSize={X=width,Y=height}
 object.AbsolutePosition={X=parent.AbsolutePosition.X+position.X.Scale*parent.AbsoluteSize.X+position.X.Offset-width*anchor.X,Y=parent.AbsolutePosition.Y+position.Y.Scale*parent.AbsoluteSize.Y+position.Y.Offset-height*anchor.Y}
end
local function build(width,height,x,y)
 local host=object('HUD','Frame')host.AbsolutePosition={X=x or 0,Y=y or 0}host.AbsoluteSize={X=width,Y=height}
 local card=object('TutorialObjectiveHUD','Frame',host)
 local text=object('ObjectiveText','TextLabel',card)
 local limit=object('FontFloor','UITextSizeConstraint',text)limit.MinTextSize=7 limit.MaxTextSize=16
 local shared={PunchWallHUDWidgets={ObjectiveCard=card,ObjectiveText=text}}
 local widgets=shared.PunchWallHUDWidgets local viewport={X=width,Y=height}local topCardHeight=40
`+objectiveProducer+'\n widgets.ObjectiveText.Position = '+objectiveTextProducer+String.raw`
 resolve(card,host)resolve(text,card)
 return card,text,host,limit
end
`;
const objectiveCases=String.raw`
local checks=0
for _,width in ipairs({320,636,749,874})do
 for _,height in ipairs({240,361,402,654})do
  for _,offset in ipairs({{0,0},{17,-58}})do
   local card,text,host,limit=build(width,height,offset[1],offset[2])
   assert(verifyMobileObjective(card,text,host))
   assert(limit.MinTextSize==14 and limit.MaxTextSize==14,'actual producer must set fourteen pixel bounds')
   checks+=2
  end
 end
end
local function rejects(change,label)
 local card,text,host,limit=build(749,361,0,-58)
 change(card,text,host,limit)
 assert(not pcall(verifyMobileObjective,card,text,host),label..' unexpectedly passed')
 checks+=1
end
rejects(function(card,text)card.AbsoluteSize.Y=30 text.AbsoluteSize.Y=26.25 text.AbsolutePosition.Y=card.AbsolutePosition.Y+1.875 end,'old30')
rejects(function(card,text)card.AbsoluteSize.X=220 text.AbsoluteSize.X=170 end,'old220')
rejects(function(card)card.AbsoluteSize.X=282 end,'oversized')
rejects(function(card)card.AbsolutePosition.X=-300 end,'offscreen')
rejects(function(card,text,host)host.AbsoluteSize.Y=70 end,'short safe host')
rejects(function(card)card.AbsolutePosition.Y+=4 end,'wrong stat-row gap')
rejects(function(card,text,host,limit)limit.MinTextSize=13 end,'small primary font')
rejects(function(card,text)text.TextFits=false end,'clipped text')
rejects(function(card,text)text.TextBounds.X=text.AbsoluteSize.X+2 end,'overflowing rendered text')
rejects(function(card,text)text.TextBounds.Y=0 end,'empty rendered text')
rejects(function(card,text)text.Visible=false end,'hidden objective text')
rejects(function(card,text,host)card.Parent={}end,'wrong parent')
rejects(function(card,text,host)local scale=object('Scale','UIScale',host)scale.Scale=.8 end,'shrunk effective font')
print('MOBILE_OBJECTIVE_PASS='..checks)
`;

const candidates = [process.env.LUAU_COMMAND, "luau"];
for (const base of [...new Set([os.tmpdir(), process.env.TEMP].filter(Boolean))]) {
  if (!fs.existsSync(base)) continue;
  for (const entry of fs.readdirSync(base).filter(name => name.startsWith("codex-luau-")).sort().reverse()) {
    candidates.push(path.join(base, entry, process.platform === "win32" ? "luau.exe" : "luau"));
  }
}
const luau = candidates.filter(Boolean).find(command => {
  const probe = spawnSync(command, ["--help"], { encoding: "utf8" });
  return !probe.error && probe.status === 0;
});
assert.ok(luau, "BLOCKED: Luau is required; set LUAU_COMMAND or install it in PATH / codex-luau-* temp directory");
const fixture = `
local function object(name,kind,parent)
 local x={Name=name,ClassName=kind or 'TextLabel',Parent=parent,children={},Visible=true,Text='READABLE',TextSize=14,TextScaled=false,TextFits=true,TextBounds={X=60,Y=14},AbsoluteSize={X=100,Y=24},AbsolutePosition={X=10,Y=10}}
 function x:GetChildren() return self.children end
 function x:IsA(k) return self.ClassName==k end
 function x:FindFirstChildOfClass(k) for _,child in ipairs(self.children) do if child:IsA(k) then return child end end return nil end
 if parent then table.insert(parent.children,x) end
 return x
end
${helpers}
local passed=0
local function rejects(fn,label) local ok=pcall(fn) assert(not ok,label..' unexpectedly passed') passed+=1 end
local host=object('Host','Frame') host.AbsolutePosition={X=0,Y=0} host.AbsoluteSize={X=320,Y=240}
local text=object('Name','TextLabel',host)
inside(text,host) readable(text,14) passed+=2
text.TextSize=13 rejects(function() readable(text,14) end,'13px primary')
text.TextSize=14 text.TextFits=false rejects(function() readable(text,14) end,'clipped text')
text.TextFits=true text.TextBounds.X=102 rejects(function() readable(text,14) end,'overflowing text bounds')
text.TextBounds.X=60 text.TextBounds.Y=0 rejects(function() readable(text,14) end,'empty rendered text bounds') text.TextBounds.Y=14
local scaling=object('Scale','UIScale',host) scaling.Scale=.5
rejects(function() readable(text,14) end,'14px text shrunk to 7px')
text.TextSize=28 readable(text,14) passed+=1
text.TextScaled=true rejects(function() readable(text,14) end,'TextScaled without a font floor')
local limit=object('Limit','UITextSizeConstraint',text) limit.MinTextSize=14
rejects(function() readable(text,14) end,'small constrained scaled text')
limit.MinTextSize=28 readable(text,14) passed+=1
text.TextScaled=false text.TextSize=24 readable(text,12) passed+=1
text.TextSize=22 rejects(function() readable(text,12) end,'11px secondary')
text.AbsolutePosition.X=250 rejects(function() inside(text,host) end,'rectangle outside parent')
text.AbsolutePosition.X=10 text.AbsoluteSize.X=0 rejects(function() inside(text,host) end,'zero sized rectangle')
local button=object('Buy','TextButton',host) button.AbsoluteSize={X=112,Y=48} touch(button,48) passed+=1
button.AbsoluteSize.Y=43 rejects(function() touch(button,44) end,'43px touch target')
button.AbsoluteSize.Y=47 rejects(function() touch(button,48) end,'47px purchase target')
print('MEASURED_MOBILE_ASSERTIONS_PASS='..passed)
`;
const temp = fs.mkdtempSync(path.join(os.tmpdir(), "smash-mobile-assertions-"));
let measurementChecks,objectiveChecks;
const objectiveMutations=[];
try {
  const file = path.join(temp, "runtime-assertions.luau");
  fs.writeFileSync(file, fixture);
  const run = spawnSync(luau, [file], { encoding: "utf8" });
  assert.equal(run.status, 0, `Luau measurement assertions failed: ${run.stdout}\n${run.stderr}`);
  measurementChecks = Number(run.stdout.match(/MEASURED_MOBILE_ASSERTIONS_PASS=(\d+)/)?.[1]);
  assert.equal(measurementChecks, 18, "all measured assertion positive/negative fixtures must run");

  const compiler=process.env.LUAU_COMPILE_COMMAND||path.join(path.dirname(luau),process.platform==='win32'?'luau-compile.exe':'luau-compile');
  const runObjective=(name,helpersText=objectiveHelpers,fixtureText=objectiveFixture,expected)=>{
    const source=helpersText+'\n'+fixtureText+'\n'+objectiveCases;
    const target=path.join(temp,name+'.luau');fs.writeFileSync(target,source);
    const compiled=spawnSync(compiler,['--null',target],{encoding:'utf8'});
    assert.equal(compiled.status,0,compiled.stderr);
    const result=spawnSync(luau,[target],{encoding:'utf8',timeout:10000});
    const output=(result.stdout||'')+(result.stderr||'');
    if(expected)assert(result.status!==0&&output.includes(expected),name+': '+output);
    else assert.equal(result.status,0,name+': '+output);
    return output;
  };
  objectiveChecks=Number(runObjective('objective-actual-producer').match(/MOBILE_OBJECTIVE_PASS=(\d+)/)?.[1]);
  assert.equal(objectiveChecks,77,'all exact objective producer/helper controls must execute');
  const mutations=[
    ['height_gate',s=>s.replace('math.abs(s.Y-36)<=1','true'),'old30 unexpectedly passed'],
    ['width_gate',s=>s.replace('math.abs(s.X-expectedWidth)<=1','true'),'old220 unexpectedly passed'],
    ['safe_host_gate',s=>s.replace('p.X>=origin.X-1 and p.Y>=origin.Y-1 and p.X+s.X<=origin.X+size.X+1 and p.Y+s.Y<=origin.Y+size.Y+1','true'),'short safe host unexpectedly passed'],
    ['font_floor',s=>s.replace('floor*scale>=13.99','true'),'small primary font unexpectedly passed'],
    ['text_fits',s=>s.replace('text.TextFits and ',''),'clipped text unexpectedly passed'],
    ['visibility',s=>s.replace('assert(node.Visible,','assert(true,'),'hidden objective text unexpectedly passed'],
  ];
  for(const [name,change,expected]of mutations){
    const altered=change(objectiveHelpers);assert.notEqual(altered,objectiveHelpers,name);
    runObjective('objective-mutant-'+name,altered,objectiveFixture,expected);
    objectiveMutations.push(name);
  }
  const oldHeight=objectiveFixture.replace('math.min(280, viewport.X - 136), 36','math.min(280, viewport.X - 136), 30');
  assert.notEqual(oldHeight,objectiveFixture);
  runObjective('objective-old-source-height',objectiveHelpers,oldHeight,'objective must use current 280-bounded by 36 geometry');
  objectiveMutations.push('actual_source_height');
  const changedHierarchy=structuredClone(flow);
  changedHierarchy.steps.find(s=>s.label==='top information hierarchy is clear').args.code=objectiveStep.args.code.replace("result.info=='FourStatsAlignedNoDowntownV5'","true");
  assert.throws(()=>verifyObjectiveFlowShape(changedHierarchy),/unrelated/);objectiveMutations.push('original_hierarchy_gate');
  const changedCleanup=structuredClone(flow);changedCleanup.cleanup.pop();
  assert.throws(()=>verifyObjectiveFlowShape(changedCleanup),/unrelated/);objectiveMutations.push('original_cleanup');
  const flowChunk=path.join(temp,'actual-objective-step.luau');fs.writeFileSync(flowChunk,objectiveStep.args.code);
  const compiledFlow=spawnSync(compiler,['--null',flowChunk],{encoding:'utf8'});
  assert.equal(compiledFlow.status,0,compiledFlow.stderr);

} finally {
  const resolvedTemp = fs.realpathSync(temp);
  assert.equal(path.dirname(resolvedTemp), fs.realpathSync(os.tmpdir()), "temporary cleanup escaped temp parent");
  assert.ok(path.basename(resolvedTemp).startsWith("smash-mobile-assertions-"), "unexpected temporary cleanup target");
  fs.rmSync(resolvedTemp, { recursive: true, force: true });
}
console.log(JSON.stringify({ ok: true, passed: checks.length + measurementChecks + objectiveChecks, total: checks.length + measurementChecks + objectiveChecks, staticChecks: checks.length, measurementChecks, objectiveChecks, objectiveMutations, helperCopies, checks: Object.fromEntries(checks) }, null, 2));
