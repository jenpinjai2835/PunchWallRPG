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
  "InventoryGrid/ItemCard_fist_Boxing_Glove",
  "DetailActions/Actionequip",
  "PixelPerfectHeroCityHUD/DailyButton",
  "Daily Supply/Actions/ClaimDaily",
  "City Cleanup/Actions/ClaimQuest",
  "Five Minute Supply/Actions/ClaimPlaytime",
  "PixelPerfectHeroCityHUD/SettingsTool",
  "Motion Feedback/Actions/motion",
  "Sound Feedback/Actions/sound",
  "UI Scale/Actions/Scale80RealInput",
  "UI Scale/Actions/Scale100RealInput",
  "UI Scale/Actions/Scale120RealInput",
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
    "Flow31LastActionTarget')=='Boxing Glove'",
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
  allStepSource.includes("d.key=='fist:Boxing Glove'")
    && allStepSource.includes("d.equipped==true")
    && allStepSource.includes(
      "p.RPGStats.EquippedFist.Value=='Boxing Glove'",
    )
    && allStepSource.includes("payload.action=='EquipFist'")
    && allStepSource.includes("payload.target=='Boxing Glove'")
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
  "settings_rebuilds_use_path_safe_current_controls",
  allStepSource.includes("FindFirstChild('Scale0.8')")
    && allStepSource.includes("b.Name='Scale80RealInput'")
    && allStepSource.includes("FindFirstChild('Scale1')")
    && allStepSource.includes("b.Name='Scale100RealInput'")
    && allStepSource.includes("FindFirstChild('Scale1.2')")
    && allStepSource.includes("b.Name='Scale120RealInput'")
    && allStepSource.includes(
      "settings.motion==false and settings.sound==false and math.abs((settings.uiScale or 0)-1.2)<.001",
    )
    && pathStrings.some((value) => value.endsWith("Scale80RealInput"))
    && pathStrings.some((value) => value.endsWith("Scale100RealInput"))
    && pathStrings.some((value) => value.endsWith("Scale120RealInput")),
  "Each rebuilt Settings callback must be reacquired, renamed to a dot-safe current path, and correlated with its UpdateSettings payload.",
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
    'makeMenuCommand(actions, key, clientSettings[key]',
    '"Scale" .. value',
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
      files: [
        path.relative(repositoryRoot, flowPath),
        path.relative(repositoryRoot, clientPath),
        path.relative(repositoryRoot, inventoryPath),
      ],
    },
    null,
    2,
  ),
);
