#!/usr/bin/env node
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const repositoryRoot = path.resolve(scriptDirectory, "../../..");
const flowPath = path.join(
  repositoryRoot,
  "work",
  "automation",
  "flows",
  "full-game-real-ui-controls.json",
);
const clientPath = path.join(
  repositoryRoot,
  "work",
  "punch-wall-rpg",
  "src",
  "client",
  "PunchWallClient.client.lua",
);
const inventoryPath = path.join(
  repositoryRoot,
  "work",
  "punch-wall-rpg",
  "src",
  "client",
  "InventoryUI.lua",
);

const flow = JSON.parse(fs.readFileSync(flowPath, "utf8"));
const client = fs.readFileSync(clientPath, "utf8").replace(/\r\n?/g, "\n");
const inventory = fs.readFileSync(inventoryPath, "utf8").replace(/\r\n?/g, "\n");
const checks = {};

function check(name, condition, detail) {
  checks[name] = condition === true;
  assert.equal(condition, true, `${name}: ${detail}`);
}

function includesAll(source, tokens) {
  return tokens.every((token) => source.includes(token));
}

function countLiteral(source, literal) {
  return source.split(literal).length - 1;
}

const mouseSteps = flow.steps.filter(
  (step) => step.type === "call" && step.tool === "user_mouse_input",
);
const mouseActions = mouseSteps.flatMap((step) => step.args?.actions || []);
const clickActions = mouseActions.filter(
  (action) => action.action === "mouseButtonClick",
);
const mouseDownActions = mouseActions.filter(
  (action) => action.action === "mouseButtonDown",
);
const mouseUpActions = mouseActions.filter(
  (action) => action.action === "mouseButtonUp",
);
const moveActions = mouseActions.filter((action) => action.action === "moveTo");
const waitActions = mouseActions.filter((action) => action.action === "wait");
const settleWaitActions = waitActions.filter(
  (action) => action.wait_time_ms === 80,
);
const holdWaitActions = waitActions.filter(
  (action) => action.wait_time_ms === 60,
);
const pathStrings = mouseSteps.map((step) =>
  step.args.actions[0].instance_path_segments.join("/"),
);
const executeSteps = flow.steps.filter(
  (step) => step.tool === "execute_luau",
);
const allStepSource = executeSteps
  .map((step) => step.args?.code || "")
  .join("\n");
const clientStepSource = executeSteps
  .filter((step) => step.args?.datamodel_type === "Client")
  .map((step) => step.args?.code || "")
  .join("\n");

function previousClientStep(mouseStep) {
  const mouseIndex = flow.steps.indexOf(mouseStep);
  for (let index = mouseIndex - 1; index >= 0; index -= 1) {
    const candidate = flow.steps[index];
    if (
      candidate.tool === "execute_luau"
      && candidate.args?.datamodel_type === "Client"
    ) {
      return candidate;
    }
  }
  return null;
}

function nextClientStep(mouseStep, order) {
  const mouseIndex = flow.steps.indexOf(mouseStep);
  const nextMouse = mouseSteps[order + 1];
  const nextMouseIndex = nextMouse
    ? flow.steps.indexOf(nextMouse)
    : flow.steps.length;
  for (let index = mouseIndex + 1; index < nextMouseIndex; index += 1) {
    const candidate = flow.steps[index];
    if (
      candidate.tool === "execute_luau"
      && candidate.args?.datamodel_type === "Client"
    ) {
      return candidate;
    }
  }
  return null;
}

const prechecks = mouseSteps.map(previousClientStep);
const postchecks = mouseSteps.map(nextClientStep);

const inventoryCloseToShopPrecheck = flow.steps.find(
  (step) =>
    step.label === "assert Inventory closed and precheck reference Shop open",
);

check(
  "flow_identity_version_and_cleanup",
  flow.name === "full-game-real-ui-controls"
    && flow.inputContractVersion === "RealInputAttestationV3BalancedGesture"
    && flow.studioName === "^PunchWallRPGPlayable_v1_final[.]rbxlx$"
    && Array.isArray(flow.cleanup)
    && flow.cleanup.some(
      (step) =>
        step.tool === "start_stop_play"
        && step.args?.is_start === false
        && step.allowError === true,
    ),
  "The hardened flow needs an explicit contract version, deterministic Studio target, and fail-safe cleanup stop.",
);

check(
  "exactly_25_coupled_balanced_left_gestures",
  mouseSteps.length === 25
    && clickActions.length === 0
    && mouseDownActions.length === 25
    && mouseUpActions.length === 25
    && moveActions.length === 50
    && waitActions.length === 50
    && settleWaitActions.length === 25
    && holdWaitActions.length === 25
    && mouseActions.length === 150
    && mouseSteps.every((step) => {
      const actions = step.args?.actions || [];
      const firstPath = actions[0]?.instance_path_segments;
      const secondPath = actions[2]?.instance_path_segments;
      return actions.length === 6
        && actions[0]?.action === "moveTo"
        && Array.isArray(firstPath)
        && actions[1]?.action === "wait"
        && actions[1]?.wait_time_ms === 80
        && actions[2]?.action === "moveTo"
        && Array.isArray(secondPath)
        && JSON.stringify(secondPath) === JSON.stringify(firstPath)
        && actions[3]?.action === "mouseButtonDown"
        && actions[3]?.mouse_button === "left"
        && JSON.stringify(actions[3]?.instance_path_segments)
          === JSON.stringify(firstPath)
        && actions[4]?.action === "wait"
        && actions[4]?.wait_time_ms === 60
        && actions[5]?.action === "mouseButtonUp"
        && actions[5]?.mouse_button === "left"
        && JSON.stringify(actions[5]?.instance_path_segments)
          === JSON.stringify(firstPath);
    }),
  `Expected 25 move/wait80/move/down/wait60/up gestures; got moves=${moveActions.length}, settle=${settleWaitActions.length}, hold=${holdWaitActions.length}, down=${mouseDownActions.length}, up=${mouseUpActions.length}, legacyClick=${clickActions.length}.`,
);

check(
  "all_gesture_actions_share_one_segmented_coordinate_cache_key",
  mouseSteps.every((step) => {
    const first = step.args.actions[0].instance_path_segments;
    const second = step.args.actions[2].instance_path_segments;
    const down = step.args.actions[3].instance_path_segments;
    const up = step.args.actions[5].instance_path_segments;
    return first[0] === "LocalPlayer"
      && first[1] === "PlayerGui"
      && first.every(
        (segment) => typeof segment === "string" && !segment.includes("."),
      )
      && JSON.stringify(second) === JSON.stringify(first)
      && JSON.stringify(down) === JSON.stringify(first)
      && JSON.stringify(up) === JSON.stringify(first);
  }),
  "Both moves and the balanced down/up pair must carry one exact segmented, dot-safe path so the runner can reuse one fresh per-call coordinate.",
);

const expectedPathSuffixes = [
  "PixelPerfectHeroCityHUD/InventoryButton",
  "InventoryHeader/InventoryClose",
  "PixelPerfectHeroCityHUD/ShopButton",
  "ShopHeader/CloseShop",
  "CategoryBar/CategoryFists",
  "InventoryToolbar/RarityFilter",
  "RarityMenu/RarityRare",
  "InventoryGrid/ItemCard_fist_Iron_Knuckle",
  "DetailActions/Actionequip",
  "PixelPerfectHeroCityHUD/DailyButton",
  "Daily Supply/Actions/ClaimDaily",
  "City Cleanup/Actions/ClaimQuest",
  "Five Minute Supply/Actions/ClaimPlaytime",
  "PixelPerfectHeroCityHUD/SettingsTool",
  "SettingsWindow/Body/MOTIONSetting/Options/MotionCalm",
  "SettingsWindow/Body/SOUNDSetting/Options/SoundOff",
  "SettingsWindow/Body/UI SIZESetting/Options/Scale80",
  "SettingsWindow/Body/UI SIZESetting/Options/Scale100",
  "SettingsWindow/Body/UI SIZESetting/Options/Scale120",
  "PixelPerfectHeroCityHUD/SpinButton",
  "SpinPanel/CloseSpin",
];
check(
  "required_real_control_paths_are_covered",
  expectedPathSuffixes.every((suffix) =>
    pathStrings.some((instancePath) => instancePath.endsWith(suffix)),
  ),
  `Missing required path suffixes: ${expectedPathSuffixes
    .filter(
      (suffix) =>
        !pathStrings.some((instancePath) => instancePath.endsWith(suffix)),
    )
    .join(", ")}`,
);

const precheckTokens = [
  "b:IsDescendantOf(g)",
  "b.Visible",
  "b.Active",
  "b.Selectable",
  "visibleArea",
  "GetGuiObjectsAtPosition",
  "hitTop==b",
  "hitTop:IsDescendantOf(b)",
  "topmost",
  "b.AbsoluteSize.X>=44",
  "b.AbsoluteSize.Y>=44",
  "Flow31ExpectedControl",
  "Flow31ActivatedControl",
  "Activated:Once(function()",
];
const precheckExpectations = [
  '"hittable"\\s*:\\s*true',
  '"selectable"\\s*:\\s*true',
  '"visibleArea"\\s*:\\s*true',
  '"topmost"\\s*:\\s*true',
];
check(
  "every_click_has_fresh_complete_hit_precheck",
  prechecks.length === 25
    && prechecks.every(
      (step) =>
        step?.args?.datamodel_type === "Client"
        && includesAll(step.args.code, precheckTokens)
        && precheckExpectations.every((pattern) =>
          step.expectRegex?.includes(pattern),
        ),
    )
    && countLiteral(clientStepSource, "Activated:Once(function()") === 25,
  "Every intended click must arm its current button only after proving descendant freshness, Active, Selectable, viewport visibility, topmost hit ownership, and both 44 px dimensions.",
);

check(
  "telemetry_listeners_are_observation_only",
  prechecks.every((step) => {
    const source = step.args.code;
    const listenerStart = source.lastIndexOf("armedButton.Activated:Once(function()");
    const listenerEnd = source.indexOf("\n end)", listenerStart);
    if (listenerStart < 0 || listenerEnd < 0) return false;
    const listener = source.slice(listenerStart, listenerEnd);
    return includesAll(listener, [
      "Flow31ExpectedControl",
      "Flow31ActivatedControl",
      "SetAttribute",
    ])
      && !/FireServer|:Invoke|CreateVirtualInput|SendMouse|mouseButtonClick|mouseButtonDown|mouseButtonUp|Button1Down|Button1Up/.test(
        listener,
      );
  }),
  "Activated:Once telemetry may only write bounded HUD attributes; it must never invoke, request, or synthesize input.",
);

check(
  "every_click_has_exact_callback_attestation",
  postchecks.length === 25
    && postchecks.every(
      (step) =>
        step?.args?.datamodel_type === "Client"
        && (
          step.args.code.includes(
            "g:GetAttribute('Flow31ActivatedControl')==",
          )
          || (
            step === inventoryCloseToShopPrecheck
            && includesAll(step.args.code, [
              "local c02CloseCallbackMarker=tostring(g:GetAttribute('Flow31ActivatedControl') or '')",
              "local activated=c02CloseCallbackMarker=='C02_InventoryClose'",
            ])
          )
        )
        && step.args.code.includes("ok=ok and activated")
        && step.expectRegex?.includes('"activated"\\s*:\\s*true'),
    )
    && countLiteral(
      clientStepSource,
      "g:GetAttribute('Flow31ActivatedControl')==",
    ) === 24
    && countLiteral(
      clientStepSource,
      "local activated=c02CloseCallbackMarker=='C02_InventoryClose'",
    ) === 1,
  "The first client observation after every real click must prove that exact armed GuiButton emitted Activated.",
);

check(
  "inventory_close_to_shop_precheck_preserves_exact_failure_state",
  inventoryCloseToShopPrecheck?.args?.datamodel_type === "Client"
    && includesAll(inventoryCloseToShopPrecheck.args.code, [
      "local c02CloseCallbackMarker=tostring(g:GetAttribute('Flow31ActivatedControl') or '')",
      "local activated=c02CloseCallbackMarker=='C02_InventoryClose'",
      "local menuClosed=s.menuVisible==false",
      "local inventoryClosed=s.inventoryVisible==false",
      "c02CloseCallbackMarker=c02CloseCallbackMarker",
      "c02CloseActivated=activated",
      "menuVisible=s.menuVisible==true",
      "menuClosed=menuClosed",
      "inventoryVisible=s.inventoryVisible==true",
      "inventoryClosed=inventoryClosed",
      "c03ShopExists=c03ShopExists",
      "c03ShopDescendant=c03ShopDescendant",
      "c03ShopVisible=c03ShopVisible",
      "c03ShopActive=c03ShopActive",
      "c03ShopSelectable=c03ShopSelectable",
      "c03ShopVisibleArea=visibleArea",
      "c03ShopTopmost=topmost",
      "c03ShopHittable=hittable",
      "local evidenceJson=H:JSONEncode(evidence)",
      "assert(ok,'Flow31 C02 close callback / C03 Shop precheck failed: '..evidenceJson)",
      "return evidenceJson",
    ])
    && inventoryCloseToShopPrecheck.args.code.indexOf(
      "local evidenceJson=H:JSONEncode(evidence)",
    ) < inventoryCloseToShopPrecheck.args.code.indexOf(
      "g:SetAttribute('Flow31ActivatedControl','')",
    )
    && inventoryCloseToShopPrecheck.args.code.indexOf(
      "assert(ok,'Flow31 C02 close callback / C03 Shop precheck failed: '..evidenceJson)",
    ) < inventoryCloseToShopPrecheck.args.code.indexOf(
      "g:SetAttribute('Flow31ActivatedControl','')",
    )
    && [
      '"c02CloseCallbackMarker"\\s*:\\s*"C02_InventoryClose"',
      '"c02CloseActivated"\\s*:\\s*true',
      '"menuVisible"\\s*:\\s*false',
      '"menuClosed"\\s*:\\s*true',
      '"inventoryVisible"\\s*:\\s*false',
      '"inventoryClosed"\\s*:\\s*true',
      '"c03ShopHittable"\\s*:\\s*true',
    ].every((pattern) =>
      inventoryCloseToShopPrecheck.expectRegex?.includes(pattern),
    ),
  "The C02 result must be serialized and asserted before its marker is reset, while C03's exact Shop hit-test state remains visible in both failures and successful output.",
);

check(
  "no_cross_call_executable_state_or_hidden_input_retry",
  !allStepSource.includes("shared.")
    && !allStepSource.includes("CreateVirtualInput")
    && !allStepSource.includes("SendMouseButton")
    && !allStepSource.includes("VirtualInput")
    && !allStepSource.includes("Instance.new('BindableFunction')")
    && !allStepSource.includes('Instance.new("BindableFunction")')
    && !allStepSource.includes("Instance.new('ModuleScript')")
    && !allStepSource.includes('Instance.new("ModuleScript")')
    && !flow.steps.some((step) => /retry/i.test(step.label ?? ""))
    && clickActions.length === 0
    && mouseDownActions.length === 25
    && mouseUpActions.length === 25,
  "Flow31 must fail if an intended real gesture does not settle; legacy click actions, shared verifiers, executable carriers, synthetic input, and hidden retry steps are forbidden.",
);

const seedStep = flow.steps.find(
  (step) => step.label === "seed ready safe authoritative UI state",
);
check(
  "server_request_spy_is_bounded_to_nine_mutations",
  seedStep?.args?.datamodel_type === "Server"
    && includesAll(seedStep.args.code, [
      "local tracked={EquipFist=true,ClaimDaily=true,ClaimQuest=true,ClaimPlaytime=true,UpdateSettings=true}",
      "Flow31ActionRequestSequence",
      "Flow31LastActionRequest",
      "Flow31LastActionTarget",
      "Flow31LastActionPayloadJSON",
      "ActionRequest.OnServerEvent:Connect(function(source,payload)",
      "if source~=p or type(payload)~='table' then return end",
      "if tracked[action]~=true then return end",
      "local sequence=(p:GetAttribute('Flow31ActionRequestSequence') or 0)+1",
      "H:JSONEncode(payload)",
    ])
    && !seedStep.args.code.includes("FireServer")
    && !seedStep.args.code.includes("CreateVirtualInput")
    && seedStep.expectRegex?.includes('"requestSequence"\\s*:\\s*0'),
  "The read-only server spy must record only the nine expected mutating requests and cannot create requests itself.",
);

const authorityLabels = [
  "assert authoritative safe Inventory equip",
  "assert authoritative Daily claim",
  "assert authoritative Quest claim",
  "poll exact authoritative Playtime reward delta and final state",
  "assert authoritative final Settings state",
];
const authoritySteps = authorityLabels.map((label) =>
  flow.steps.find((step) => step.label === label),
);
check(
  "mutating_clicks_have_bounded_exact_authority_assertions",
  authoritySteps.every(
    (step) =>
      step?.args?.datamodel_type === "Server"
      && includesAll(step.args.code, [
        "local deadline=os.clock()+4",
        "task.wait(.05)",
        "until os.clock()>=deadline",
        "Flow31ActionRequestSequence",
        "Flow31LastActionRequest",
        "assert(result.ok",
        "H:JSONEncode(result)",
      ])
      && !step.args.code.includes("FireServer")
      && !step.args.code.includes("CreateVirtualInput"),
  ),
  "Equip, three claims, and final Settings state must each use a bounded read-only poll with exact request/state JSON diagnostics.",
);

check(
  "request_sequence_and_payload_contract_is_exact",
  includesAll(allStepSource, [
    "Flow31ActionRequestSequence')==1",
    "Flow31LastActionRequest')=='EquipFist'",
    "Flow31LastActionTarget')=='Iron Knuckle'",
    "Flow31ActionRequestSequence')==2",
    "Flow31LastActionRequest')=='ClaimDaily'",
    "Flow31ActionRequestSequence')==3",
    "Flow31LastActionRequest')=='ClaimQuest'",
    "Flow31ActionRequestSequence')==4",
    "Flow31LastActionRequest')=='ClaimPlaytime'",
    "requestSequence==5",
    "requestSequence==6",
    "requestSequence==7",
    "requestSequence==8",
    "requestSequence==9",
    "payload.action=='UpdateSettings'",
    "payload.value.motion==false",
    "payload.value.sound==false",
    "payload.value.uiScale",
  ]),
  "The one Equip, three claim, and five Settings clicks must advance the observed server request sequence exactly from 1 through 9 with payload checks.",
);

const removedFixedWaitLabels = [
  "wait for authoritative fist equip replication",
  "wait for Daily claim and Tasks rebuild",
  "wait for Quest claim and Tasks rebuild",
];
check(
  "rerender_sensitive_paths_use_bounded_observation",
  removedFixedWaitLabels.every(
    (label) => !flow.steps.some((step) => step.label === label),
  )
    && includesAll(allStepSource, [
      "single real Playtime click did not settle",
      "local function currentButton()",
      "b==select(2,currentButton())",
      "requestAttested=requestSequence==5",
      "requestAttested=requestSequence==6",
      "requestAttested=requestSequence==7",
      "requestAttested=requestSequence==8",
      "requestAttested=requestSequence==9",
    ]),
  "Equip, Tasks rebuilds, Playtime, and Settings rebuilds must observe current state with deadlines instead of sleeping then retrying.",
);

check(
  "inventory_safe_action_is_server_verified",
  allStepSource.includes("d.key=='fist:Iron Knuckle'")
    && allStepSource.includes("d.equipped==true")
    && allStepSource.includes(
      "p.RPGStats.EquippedFist.Value=='Iron Knuckle'",
    )
    && allStepSource.includes("payload.action=='EquipFist'")
    && allStepSource.includes("payload.target=='Iron Knuckle'")
    && !allStepSource.includes("DeletePet")
    && !allStepSource.includes("BuyPremium"),
  "Inventory coverage must use one owned safe Equip action and prove callback, request, ownership, and exact equipped authority.",
);

check(
  "tasks_claims_are_exact_and_authoritative",
  allStepSource.includes("p.leaderstats.Coins.Value==600")
    && allStepSource.includes("p.RPGStats.DailyQuestClaimed.Value==1")
    && allStepSource.includes("p.leaderstats.Coins.Value==1450")
    && allStepSource.includes("p.RPGStats.PlaytimeClaimed.Value==1")
    && allStepSource.includes("p.leaderstats.Coins.Value==2650")
    && allStepSource.includes("delta==config.Rewards.PlaytimeCoins"),
  "Daily, Quest, and Playtime clicks need exact cumulative server rewards and the configured Playtime delta.",
);

check(
  "settings_rebuilds_use_current_standalone_controls",
  includesAll(allStepSource, ["g:FindFirstChild('SettingsWindow')", "row.Options:FindFirstChild('MotionCalm')", "row.Options:FindFirstChild('SoundOff')", "row.Options:FindFirstChild('Scale80')", "row.Options:FindFirstChild('Scale100')", "row.Options:FindFirstChild('Scale120')", "s.settingsVisible==true", "s.activeWindow=='Settings'", "local b=g.SettingsWindow.Close", "s.settingsVisible==false", "settings.motion==false and settings.sound==false and math.abs((settings.uiScale or 0)-1.2)<.001"])
    && ['MotionCalm','SoundOff','Scale80','Scale100','Scale120'].every(name=>pathStrings.some(value=>value.includes('SettingsWindow/Body/')&&value.endsWith('/'+name)))
    && pathStrings.some(value=>value.endsWith('SettingsWindow/Close')),
  "Standalone Settings must use its current semantic controls, one actual gesture per action, fresh callback checks and the same exact UpdateSettings authority sequence.",
);

check(
  "current_source_hierarchy_matches_flow",
  [
    'mainPanel.Name = "GameMenu"',
    'shopReference.Name = "FunctionalHeroShop"',
    'close.Name = "CloseShop"',
    'makeMenuCommand(dailyActions, "ClaimDaily"',
    'makeMenuCommand(questActions, "ClaimQuest"',
    'makeMenuCommand(playActions, "ClaimPlaytime"',
    'makeMenuCommand(optionArea, option.name, option.label',
    'name = "Scale80", label = "80%"',
    'name = "Scale100", label = "100%"',
    'name = "Scale120", label = "120%"',
    'settingsClose.Activated:Connect(function() closeStandaloneWindows("SettingsClose") end)',
    'spinOverlay.Name = "HeroSpinModal"',
    'local close = imageLayer("ImageButton", "CloseSpin"',
    'referenceButton("SettingsTool"',
    'referenceButton("SpinButton"',
  ].every((token) => client.includes(token))
    && [
      'Name = "InventoryClose"',
      'Name = "Category" .. category',
      'Name = "Rarity" .. rarity',
      'card.Name = "ItemCard_" .. safeName(key)',
      'button.Name = "Action" .. safeName(controlKey)',
    ].every((token) => inventory.includes(token)),
  "A renamed current UI control must fail this static contract before Studio execution.",
);

check(
  "scope_excludes_other_real_input_profiles",
  !allStepSource.includes("ContextAction")
    && !allStepSource.includes("EquipPet")
    && !allStepSource.includes("UnequipPet")
    && !allStepSource.includes("LockPet")
    && !allStepSource.includes("FusePet"),
  "Flow31 must not duplicate contextual-action or fist-pet slot coverage.",
);

check(
  "every_click_has_post_state_or_authority_evidence",
  postchecks.every(
    (step) =>
      step
      && step.args.code.includes("local ok=")
      && step.args.code.includes("ok=ok and activated")
      && step.expectRegex?.some((pattern) => pattern.includes('"ok"')),
  ),
  "Each click must settle into an asserted callback plus client/request/authority snapshot before the next real click.",
);

check(
  "console_and_edit_cleanup_are_terminal",
  flow.steps.some(
    (step) =>
      step.type === "assertNoConsoleErrors"
      && step.source === "console",
  )
    && flow.steps.at(-3)?.tool === "get_console_output"
    && flow.steps.at(-2)?.type === "assertNoConsoleErrors"
    && flow.steps.at(-1)?.tool === "start_stop_play"
    && flow.steps.at(-1)?.args?.is_start === false,
  "A clean console assertion and terminal Play stop are mandatory.",
);


const gameConfigPath = path.join(repositoryRoot, 'work/punch-wall-rpg/src/shared/GameConfig.lua');
const gameConfig = fs.readFileSync(gameConfigPath, 'utf8');
function validRareFixture(candidate, config) {
  const seed = candidate.steps.find(step => step.label === 'seed ready safe authoritative UI state')?.args?.code ?? '';
  const pre = candidate.steps.find(step => step.label === 'assert canonical Rare rarity and precheck Iron card')?.args?.code ?? '';
  const authority = candidate.steps.find(step => step.label === 'assert authoritative safe Inventory equip')?.args?.code ?? '';
  return /name = "Iron Knuckle"[^\n]+rarity = "Rare"/.test(config)
    && /name = "Boxing Glove"[^\n]+rarity = "Common"/.test(config)
    && seed.includes('OwnedFistsJSON=\'["Starter Glove","Boxing Glove","Iron Knuckle"]\'')
    && includesAll(pre, ["s.rarity=='Rare'", "grid:FindFirstChild('ItemCard_fist_Iron_Knuckle')", "table.find(s.visibleKeys or {},'fist:Iron Knuckle')~=nil", "table.find(s.visibleKeys or {},'fist:Boxing Glove')==nil", "table.find(s.visibleKeys or {},'fist:Starter Glove')==nil", 'and present and commonExcluded and', 'local deadline=os.clock()+3', 'until os.clock()>=deadline'])
    && includesAll(authority, ["payload.target=='Iron Knuckle'", "p.RPGStats.EquippedFist.Value=='Iron Knuckle'", "table.find(owned,'Iron Knuckle')~=nil"])
    && candidate.steps.filter(step => step.tool === 'user_mouse_input').some(step => step.args.actions[0].instance_path_segments.at(-1) === 'ItemCard_fist_Iron_Knuckle');
}
check('rare_fixture_matches_current_catalog_and_excludes_owned_common_items', validRareFixture(flow, gameConfig), 'Rare filtering must expose the real owned Rare Iron item, exclude both seeded Common items, and retain exact real-click/authority identity.');
const fixtureNegativeControls = [];
for (const [name, mutateFlow, mutateConfig] of [
  ['common_item_in_rare_fixture', value => JSON.parse(JSON.stringify(value).replaceAll('Iron Knuckle','Boxing Glove').replaceAll('Iron_Knuckle','Boxing_Glove')), null],
  ['drop_common_exclusion', value => { value.steps.find(step => step.label === 'assert canonical Rare rarity and precheck Iron card').args.code = value.steps.find(step => step.label === 'assert canonical Rare rarity and precheck Iron card').args.code.replace('and present and commonExcluded and','and present and'); return value; }, null],
  ['wrong_authoritative_item', value => { value.steps.find(step => step.label === 'assert authoritative safe Inventory equip').args.code = value.steps.find(step => step.label === 'assert authoritative safe Inventory equip').args.code.replaceAll("payload.target=='Iron Knuckle'", "payload.target=='Starter Glove'"); return value; }, null],
  ['changed_catalog_rarity', null, value => value.replace(/(name = "Iron Knuckle"[^\n]+rarity = )"Rare"/, '$1"Common"')],
]) {
  const candidate = mutateFlow ? mutateFlow(structuredClone(flow)) : flow;
  const config = mutateConfig ? mutateConfig(gameConfig) : gameConfig;
  const applied = JSON.stringify(candidate) !== JSON.stringify(flow) || config !== gameConfig;
  const rejected = !validRareFixture(candidate, config);
  check('rare_negative_' + name, applied && rejected, 'The changed fixture/config must be applied and rejected.');
  fixtureNegativeControls.push({name, mutationApplied: applied, status: rejected ? 'REJECTED' : 'MISSED'});
}
check('real_ui_seed_refuses_live_persistence', includesAll(seedStep.args.code, ["PersistenceMode')=='EphemeralStudio'", "ProfileWritable')==false", "PunchWallAllowLiveDataStoreAccess')~=true", "verifyEphemeralSeed(game.Players:GetPlayers()[1]"]) && seedStep.args.code.indexOf('verifyEphemeralSeed(game.Players:GetPlayers()[1]') < seedStep.args.code.indexOf("c:Invoke('Reset')"), 'The fixture must assert the existing isolated persistence state before Reset.');

function validStandaloneSettingsGestures(candidate) {
  return [
    ['real click Settings Motion control', 'SettingsWindow/Body/MOTIONSetting/Options/MotionCalm'],
    ['real click Settings Sound control', 'SettingsWindow/Body/SOUNDSetting/Options/SoundOff'],
    ['real click Settings 80 percent control', 'SettingsWindow/Body/UI SIZESetting/Options/Scale80'],
    ['real click Settings 100 percent control', 'SettingsWindow/Body/UI SIZESetting/Options/Scale100'],
    ['real click Settings 120 percent control', 'SettingsWindow/Body/UI SIZESetting/Options/Scale120'],
    ['real click Settings close', 'SettingsWindow/Close'],
  ].every(([label, suffix]) => {
    const step = candidate.steps.find(item => item.label === label);
    const paths = step?.args?.actions?.filter(action => action.instance_path_segments) ?? [];
    return paths.length === 4 && paths.every(action => action.instance_path_segments.join('/').endsWith(suffix));
  });
}
check('standalone_settings_gestures_keep_exact_action_identity', validStandaloneSettingsGestures(flow), 'Each complete gesture must target the semantic option for that step, including both moves and release.');
for (const [name, mutate] of [
  ['obsolete_settings_host', value => JSON.parse(JSON.stringify(value).replaceAll('"SettingsWindow","Body"','"GameMenu","Content"'))],
  ['wrong_scale_option', value => { const step = value.steps.find(item => item.label === 'real click Settings 80 percent control'); for (const action of step.args.actions) if (action.instance_path_segments) action.instance_path_segments[action.instance_path_segments.length - 1] = 'Scale120'; return value; }],
]) {
  const candidate = mutate(structuredClone(flow));
  const applied = JSON.stringify(candidate) !== JSON.stringify(flow);
  const rejected = !validStandaloneSettingsGestures(candidate);
  check('settings_negative_' + name, applied && rejected, 'An obsolete host or wrong scale option must fail the gesture contract.');
  fixtureNegativeControls.push({name, mutationApplied: applied, status: rejected ? 'REJECTED' : 'MISSED'});
}

function validTasksIdleObservation(candidate) {
  const code=candidate.steps.find(step=>step.label==='assert Tasks opened and precheck Daily claim')?.args?.code??'';
  const start=code.indexOf('local function observeIdleControl('),end=code.indexOf('local idle=observeIdleControl(',start);
  const observation=start>=0&&end>start?code.slice(start,end):'';
  return includesAll(observation,[
    'local original=assert(currentButton()', 'local observed,destroyed=false,false',
    'StatsChanged.OnClientEvent:Connect(function(payload)', '(tonumber(payload.PlaytimeSeconds) or 0)>startPlaytime',
    'original.Destroying:Connect(function()destroyed=true end)', 'b==original and b:IsDescendantOf(c) and not destroyed',
    'hittable=live and contained and ancestorVisible', 'local deadline=os.clock()+3',
    'stats:Disconnect()', 'lifetime:Disconnect()', 'pcall(verifyIdleControlState,result)',
  ]) && !/FireServer|:Invoke\(|CreateVirtualInput|SendMouse|SetAttribute/.test(observation)
    && includesAll(code,["observeIdleControl(function()return select(2,currentDailyButton())end,c,g,p,'Flow31ActionRequestSequence')",'row,b=currentDailyButton()',"local s=a:Invoke('Snapshot')",'b==select(2,currentDailyButton())',"g:SetAttribute('Flow31ExpectedControl','C13_ClaimDaily')"])
    && code.lastIndexOf('row,b=currentDailyButton()')>code.indexOf('local idle=observeIdleControl(')
    && code.indexOf('local idle=observeIdleControl(')<code.indexOf("g:SetAttribute('Flow31ExpectedControl','C13_ClaimDaily')");
}
check('tasks_claim_precheck_reacquires_after_idle_snapshot_and_scroll',validTasksIdleObservation(flow),'The actual native Daily button must survive a real clock snapshot, remain visible/hittable and leave request authority untouched; reacquire after every layout/idle wait before arming the single gesture.');
const idleObservationNegativeControls=[];
for(const [name,from,to]of[
  ['drop_identity_equality','b==original and b:IsDescendantOf(c) and not destroyed','b:IsDescendantOf(c)'],
  ['force_hittable','hittable=live and contained and ancestorVisible','hittable=true or live and contained and ancestorVisible'],
  ['remove_stats_listener_cleanup','stats:Disconnect()','-- omitted cleanup'],
]) {
  const candidate=structuredClone(flow);const step=candidate.steps.find(item=>item.label==='assert Tasks opened and precheck Daily claim');
  const original=step.args.code;step.args.code=original.replace(from,to);
  const applied=step.args.code!==original,rejected=!validTasksIdleObservation(candidate);
  check('tasks_idle_negative_'+name,applied&&rejected,'A weakened or leaked idle-input observer must be rejected.');
  idleObservationNegativeControls.push({name,mutationApplied:applied,status:rejected?'REJECTED':'MISSED'});
}

const passed = Object.values(checks).filter(Boolean).length;
console.log(
  JSON.stringify(
    {
      ok: passed === Object.keys(checks).length,
      passed,
      total: Object.keys(checks).length,
      realClickGestures: mouseDownActions.length,
      mouseDownActions: mouseDownActions.length,
      mouseUpActions: mouseUpActions.length,
      legacyClickActions: clickActions.length,
      moveActions: moveActions.length,
      settleWaitActions: settleWaitActions.length,
      holdWaitActions: holdWaitActions.length,
      freshPrechecks: prechecks.length,
      callbackAttestations: postchecks.length,
      requestAttestations: 9,
      checks,
      fixtureNegativeControls,
      idleObservationNegativeControls,
      studioRuntimeStatus: "BLOCKED_PENDING_SEPARATE_COORDINATOR_RUNTIME_EVIDENCE",
      files: [
        path.relative(repositoryRoot, flowPath),
        path.relative(repositoryRoot, clientPath),
        path.relative(repositoryRoot, inventoryPath),
        path.relative(repositoryRoot, gameConfigPath),
      ],
    },
    null,
    2,
  ),
);
