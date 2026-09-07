import fs from "node:fs";
import { spawnSync } from "node:child_process";
import path from "node:path";
import process from "node:process";
import { createHash } from "node:crypto";

const sourceRootIndex = process.argv.indexOf('--source-root');
if (sourceRootIndex >= 0 && !process.argv[sourceRootIndex + 1]) throw new Error('--source-root requires a repository path');
const repositoryRoot = sourceRootIndex >= 0 ? path.resolve(process.argv[sourceRootIndex + 1]) : path.resolve(import.meta.dirname, '..', '..', '..');
const clientPath = path.join(
  repositoryRoot,
  "work",
  "punch-wall-rpg",
  "src",
  "client",
  "PunchWallClient.client.lua",
);
const serverPath = path.join(
  repositoryRoot,
  "work",
  "punch-wall-rpg",
  "src",
  "server",
  "PunchWallBootstrap.server.lua",
);
const builderPath = path.join(
  repositoryRoot,
  "work",
  "punch-wall-rpg",
  "src",
  "shared",
  "FistVisualBuilder.lua",
);
const fistItemsFlowPath = path.join(
  repositoryRoot,
  "work",
  "automation",
  "flows",
  "fist-items-icon-ui.json",
);
const legacySlotFlowPath = path.join(
  repositoryRoot,
  "work",
  "automation",
  "flows",
  "fist-pet-legacy-slot-safety.json",
);
const studioMcpClientPath = path.join(
  repositoryRoot,
  "work",
  "automation",
  "scripts",
  "studio_mcp_client.mjs",
);
const client = fs.readFileSync(clientPath, "utf8").replaceAll("\r\n", "\n");
const server = fs.readFileSync(serverPath, "utf8").replaceAll("\r\n", "\n");
const builder = fs.readFileSync(builderPath, "utf8").replaceAll("\r\n", "\n");
const fistItemsFlow = JSON.parse(fs.readFileSync(fistItemsFlowPath, "utf8"));
const legacySlotFlow = JSON.parse(fs.readFileSync(legacySlotFlowPath, "utf8"));
const studioMcpClient = fs
  .readFileSync(studioMcpClientPath, "utf8")
  .replaceAll("\r\n", "\n");

function section(source, start, end) {
  const startIndex = source.indexOf(start);
  if (startIndex < 0) return "";
  const endIndex = source.indexOf(end, startIndex + start.length);
  return endIndex < 0 ? source.slice(startIndex) : source.slice(startIndex, endIndex);
}

const deleteArm = section(
  client,
  "function legacyPetMenuRuntime.ArmDelete",
  "local function renderPets",
);
const deleteValidation = section(
  client,
  "function legacyPetMenuRuntime.ValidateDelete",
  "function legacyPetMenuRuntime.IsDeleteArmed",
);
const deleteQuery = section(
  client,
  "function legacyPetMenuRuntime.IsDeleteArmed",
  "function legacyPetMenuRuntime.ArmDelete",
);
const legacyPets = section(
  client,
  "local function renderPets()",
  "local function renderHonor()",
);
const proceduralPets = section(
  client,
  "function companionRuntime.BuildProceduralPet",
  "local function buildCompanion",
);
const contextualActions = section(
  client,
  "function clientRuntime.IsTrainingTarget",
  "local targetTimer = 0",
);
const shopPresentation = section(
  client,
  "function shopRuntime.AddStaticFistPresentation",
  "function shopRuntime.ScheduleBoostTick",
);
const shopCards = section(
  client,
  "local fistPresentation = item.tier",
  "local priceX = wideCard",
);
const feedbackText = section(
  client,
  "local function feedbackText(payload)",
  "local function feedbackIcon(payloadType)",
);
const feedbackIcon = section(
  client,
  "local function feedbackIcon(payloadType)",
  "local performPunchAnimation",
);
const feedbackPresentation = section(
  client,
  "local feedbackPresentation = {",
  "local function feedbackText(payload)",
);
const showFeedback = section(
  client,
  "local function showFeedback(payload)",
  "shared.PunchWallShowToast = function",
);
const boundedToast = section(
  client,
  "shared.PunchWallShowToast = function",
  "notifyRemote.OnClientEvent",
);
const shopToastFlowStep = fistItemsFlow.steps.find(
  (step) => step.label === "shop notification uses visible bounded themed toast icon",
);
const shopToastFlowCode = shopToastFlowStep?.args?.code ?? "";
const shopToastFlowExpect = shopToastFlowStep?.expectRegex ?? [];
const legacySlotSteps = legacySlotFlow.steps ?? [];
const legacyStepIndex = (label) =>
  legacySlotSteps.findIndex((step) => step.label === label);
const duplicateExposeLabels = [
  "open legacy Pets and expose duplicate slot two action",
  "expose occurrence one invalid out-of-order unequip",
  "expose last equipped duplicate occurrence",
];
const duplicateExposeSteps = duplicateExposeLabels.map(
  (label) => legacySlotSteps[legacyStepIndex(label)],
);
const duplicateCallbackLabels = [
  "slot two real click reached fresh Equip callback exactly once",
  "slot one real click reached fresh Unequip callback exactly once",
  "slot two real click reached fresh Unequip callback exactly once",
];
const duplicateCallbackSteps = duplicateCallbackLabels.map(
  (label) => legacySlotSteps[legacyStepIndex(label)],
);
const duplicateAuthorityLabels = [
  "slot two became the second equipped occurrence",
  "out-of-order duplicate did not mutate equipped state",
  "exact duplicate unequip left one occurrence equipped",
];
const duplicateAuthoritySteps = duplicateAuthorityLabels.map(
  (label) => legacySlotSteps[legacyStepIndex(label)],
);
const duplicateSeedStep =
  legacySlotSteps[legacyStepIndex("seed duplicate pet occurrences with only slot one equipped")];
const realClickLabels = [
  "real click equips duplicate occurrence two",
  "real click occurrence one is rejected by exact-index order",
  "real click unequips exact last occurrence",
  "first real Delete click arms exact slot two",
  "real click re-arms slot two Delete",
  "second real click confirms exact slot two Delete",
];
const realClickSteps = realClickLabels.map(
  (label) => legacySlotSteps[legacyStepIndex(label)],
);
const deleteExposeLabels = [
  "expose unlocked duplicate slot two Delete",
  "re-expose slot two for confirmed Delete",
  "reacquire fresh armed Delete2 immediately before confirm click",
];
const deleteExposeSteps = deleteExposeLabels.map(
  (label) => legacySlotSteps[legacyStepIndex(label)],
);
const allRealInputPrecheckSteps = [
  ...duplicateExposeSteps,
  ...deleteExposeSteps,
];
const firstDeleteExposeIndex = legacyStepIndex(
  "expose unlocked duplicate slot two Delete",
);
const firstDeleteGestureIndex = legacyStepIndex(
  "first real Delete click arms exact slot two",
);
const firstDeleteStateIndex = legacyStepIndex(
  "legacy confirmation survives row rerender with exact key",
);
const firstDeleteExposeStep = legacySlotSteps[firstDeleteExposeIndex];
const firstDeleteStateStep = legacySlotSteps[firstDeleteStateIndex];
const firstDeleteExposeCode = firstDeleteExposeStep?.args?.code ?? "";
const firstDeleteStateCode = firstDeleteStateStep?.args?.code ?? "";
const reExposeDeleteIndex = legacyStepIndex(
  "re-expose slot two for confirmed Delete",
);
const rearmDeleteIndex = legacyStepIndex("real click re-arms slot two Delete");
const freshDeleteIndex = legacyStepIndex(
  "reacquire fresh armed Delete2 immediately before confirm click",
);
const confirmDeleteIndex = legacyStepIndex(
  "second real click confirms exact slot two Delete",
);
const confirmedMarkerIndex = legacyStepIndex(
  "second click reached confirmed client callback exactly once",
);
const authorityPollIndex = legacyStepIndex(
  "bounded authority poll proves only duplicate slot two deleted",
);
const freshDeleteStep = legacySlotSteps[freshDeleteIndex];
const confirmedMarkerStep = legacySlotSteps[confirmedMarkerIndex];
const authorityPollStep = legacySlotSteps[authorityPollIndex];
const freshDeleteCode = freshDeleteStep?.args?.code ?? "";
const confirmedMarkerCode = confirmedMarkerStep?.args?.code ?? "";
const authorityPollCode = authorityPollStep?.args?.code ?? "";
const confirmAttemptSteps =
  reExposeDeleteIndex >= 0 && authorityPollIndex > reExposeDeleteIndex
    ? legacySlotSteps.slice(reExposeDeleteIndex, authorityPollIndex + 1)
    : [];
const confirmAttemptClickSteps = confirmAttemptSteps.filter(
  (step) => step.tool === "user_mouse_input",
);
const confirmAttemptClickActions = confirmAttemptClickSteps.flatMap(
  (step) => step.args?.actions ?? [],
);
const confirmAttemptLuau = confirmAttemptSteps
  .filter((step) => step.tool === "execute_luau")
  .map((step) => step.args?.code ?? "")
  .join("\n");
const checks = {};
const notes = {};

function check(name, ok, note) {
  checks[name] = Boolean(ok);
  if (!ok) notes[name] = note;
}

function includesAll(source, needles) {
  return needles.every((needle) => source.includes(needle));
}

function coupledRealPress(step, expectedButtonName) {
  const actions = step?.args?.actions ?? [];
  const firstPath = actions[0]?.instance_path_segments;
  const secondMovePath = actions[2]?.instance_path_segments;
  const downPath = actions[4]?.instance_path_segments;
  const upPath = actions[6]?.instance_path_segments;
  return step?.tool === "user_mouse_input"
    && step?.args?.datamodel_type === "Client"
    && actions.length === 7
    && actions[0]?.action === "moveTo"
    && Array.isArray(firstPath)
    && firstPath.at(-1) === expectedButtonName
    && actions[1]?.action === "wait"
    && actions[1]?.wait_time_ms === 250
    && actions[2]?.action === "moveTo"
    && JSON.stringify(secondMovePath) === JSON.stringify(firstPath)
    && actions[3]?.action === "wait"
    && actions[3]?.wait_time_ms === 120
    && actions[4]?.action === "mouseButtonDown"
    && actions[4]?.mouse_button === "left"
    && JSON.stringify(downPath) === JSON.stringify(firstPath)
    && actions[5]?.action === "wait"
    && actions[5]?.wait_time_ms === 80
    && actions[6]?.action === "mouseButtonUp"
    && actions[6]?.mouse_button === "left"
    && JSON.stringify(upPath) === JSON.stringify(firstPath)
    && actions.filter((action) => action.action === "mouseButtonDown").length === 1
    && actions.filter((action) => action.action === "mouseButtonUp").length === 1
    && actions.every((action) => action.action !== "mouseButtonClick");
}

check(
  "legacy_equip_and_unequip_dispatch_exact_index",
  legacyPets.includes('local petAction = equippedNow and "UnequipPet" or "EquipPet"')
    && /action = petAction,\s+target = slotPetToken,\s+index = slotIndex,/s.test(
      legacyPets,
    ),
  "Legacy Pets must identify the exact duplicate inventory occurrence.",
);
check(
  "legacy_studio_action_attestation_is_bounded",
  legacyPets.includes("if RunService:IsStudio() then")
    && legacyPets.includes('"LegacyPetActionCallbackSequence"')
    && legacyPets.includes('"LegacyPetActionCallback", petAction')
    && legacyPets.includes('"LegacyPetActionCallbackIndex", slotIndex')
    && legacyPets.includes('"LegacyPetActionCallbackToken", slotPetToken')
    && server.includes("local function recordStudioPetActionResult")
    && server.includes("if not RunService:IsStudio() or studioPetActionNames[action] ~= true then")
    && server.includes('"LegacyPetServerResultSequence"')
    && server.includes('"LegacyPetServerResultReason"')
    && server.includes('reason = "mobile_action_cooldown"')
    && !section(
      client,
      'local petAction = equippedNow and "UnequipPet" or "EquipPet"',
      "local slotToken =",
    ).includes(":Connect(")
    && !section(
      server,
      "local function recordStudioPetActionResult",
      "local function handleMobileAction",
    ).includes(":Connect("),
  "Real-input attestation must be Studio-only, bounded attribute writes with no new listener or loop.",
);
check(
  "legacy_flow_reacquires_hittable_duplicate_actions",
  duplicateExposeSteps.every(
    (step) =>
      step?.tool === "execute_luau"
      && step?.args?.datamodel_type === "Client"
      && includesAll(step?.args?.code ?? "", [
        "local function expose(rowName,buttonName,expectedText)",
        "c.CanvasPosition=Vector2.zero",
        "c.AbsoluteCanvasSize.Y-c.AbsoluteSize.Y",
        "local hitDeadline=os.clock()+1.25",
        "p.PlayerGui:GetGuiObjectsAtPosition",
        "while ancestor and ancestor~=g do",
        "ancestorVisible=ancestorVisible and ancestor==g and g.Enabled",
        "pcall(function() return current.Interactable end)",
        "GuiService.SelectedObject=current",
        "RunService.RenderStepped:Connect",
        "local frameDeadline=os.clock()+.5",
        "while frames<2 and os.clock()<frameDeadline",
        "if GuiService.SelectedObject~=current then GuiService.SelectedObject=current end",
        "finalState.reacquired=observed==current",
        "finalState.selected=GuiService.SelectedObject==current",
      ])
      && [
        '"active"\\s*:\\s*true',
        '"selectable"\\s*:\\s*true',
        '"interactableAvailable"\\s*:\\s*true',
        '"interactable"\\s*:\\s*true',
        '"ancestorVisible"\\s*:\\s*true',
        '"visibleArea"\\s*:\\s*true',
        '"topmost"\\s*:\\s*true',
        '"frames"\\s*:\\s*2',
        '"reacquired"\\s*:\\s*true',
        '"selected"\\s*:\\s*true',
      ].every((pattern) => step.expectRegex?.includes(pattern)),
  )
    && duplicateExposeSteps.every((step) =>
      step.args.code.includes(
        "g:SetAttribute('Flow30ExpectedCallbackSequence',state.callbackSequence+1)",
      )),
  "Every duplicate action must use a self-contained bounded two-frame focus handshake, then reacquire and reassert interactable, ancestor-visible, clip-safe, selected, topmost state.",
);
check(
  "legacy_flow_uses_only_serializable_cross_call_state",
  !JSON.stringify(legacySlotFlow).includes("shared.")
    && allRealInputPrecheckSteps.length === 6
    && allRealInputPrecheckSteps.every(
      (step) =>
        (step?.args?.code ?? "").includes(
          "local function expose(rowName,buttonName,expectedText)",
        )
        && !(step?.args?.code ?? "").includes("shared."),
    )
    && duplicateCallbackSteps.every((step) =>
      (step?.args?.code ?? "").includes(
        "g:GetAttribute('Flow30ExpectedCallbackSequence')",
      ))
    && firstDeleteExposeCode.includes(
      "g:SetAttribute('Flow30DeleteArmBeforeScheduled'",
    )
    && firstDeleteStateCode.includes(
      "g:GetAttribute('Flow30DeleteArmBeforeScheduled')",
    ),
  "Flow30 must never depend on cross-Assistant-VM shared tables or functions; all cross-call state must be serialized into GUI attributes.",
);
check(
  "legacy_flow_couples_pointer_settle_reresolve_and_balanced_real_press",
  realClickSteps.length === 6
    && realClickSteps.every((step, index) =>
      coupledRealPress(step, index < 3 ? (index === 1 ? "Equip1" : "Equip2") : "Delete2")
    )
    && realClickSteps
      .flatMap((step) => step.args?.actions ?? [])
      .every((action) => action.action !== "mouseButtonClick")
    && includesAll(studioMcpClient, [
      "export async function normalizeMouseInputArgs",
      "const coordinateCache = new Map()",
      "for (const action of args?.actions ?? [])",
      "coordinateCache.get(cacheKey)",
      "coordinates = await resolveGuiCoordinates(client, copy)",
      "coordinateCache.set(cacheKey, coordinates)",
      "delete copy.instance_path_segments",
      "copy.x = coordinates.x",
      "copy.y = coordinates.y",
      "normalized.actions.push(copy)",
    ]),
  "Each real gesture must move, press, and release the same exact path with explicit coordinates supplied by one per-call cached resolution.",
);
check(
  "legacy_delete_real_click_preconditions_reuse_hittable_helper",
  deleteExposeSteps.every(
    (step) =>
      step?.tool === "execute_luau"
      && step?.args?.datamodel_type === "Client"
      && includesAll(step?.args?.code ?? "", [
        "local function expose(rowName,buttonName,expectedText)",
        'expose("#02  [Common] Forest Pup  *","Delete2"',
        "state.index=state.exactIndex",
        "GuiService.SelectedObject=current",
        "RunService.RenderStepped:Connect",
        "finalState.interactable",
        "finalState.reacquired",
        "finalState.selected",
        "H:JSONEncode(state)",
      ])
      && [
        '"active"\\s*:\\s*true',
        '"selectable"\\s*:\\s*true',
        '"interactable"\\s*:\\s*true',
        '"ancestorVisible"\\s*:\\s*true',
        '"visibleArea"\\s*:\\s*true',
        '"topmost"\\s*:\\s*true',
        '"frames"\\s*:\\s*2',
        '"reacquired"\\s*:\\s*true',
        '"selected"\\s*:\\s*true',
      ].every((pattern) => step.expectRegex?.includes(pattern)),
  ),
  "Every Delete2 real press must repeat the same self-contained focus, reacquisition, interactability, visibility, clip, and topmost contract.",
);
check(
  "legacy_first_delete_press_reports_callback_vs_invalidation_state",
  firstDeleteExposeIndex >= 0
    && firstDeleteGestureIndex === firstDeleteExposeIndex + 1
    && firstDeleteStateIndex > firstDeleteGestureIndex
    && includesAll(firstDeleteExposeCode, [
      "Flow30DeleteArmBeforeScheduled",
      "Flow30DeleteArmBeforeKey",
      "Flow30DeleteArmBeforeReason",
      "Flow30DeleteArmBeforeIndex",
      "Flow30DeleteArmBeforeToken",
      "LegacyPetDeleteConfirmationScheduled",
      "LegacyPetDeleteConfirmationKey",
      "LegacyPetDeleteConfirmationReason",
      "LegacyPetDeleteConfirmationIndex",
      "LegacyPetDeleteConfirmationToken",
    ])
    && includesAll(firstDeleteStateCode, [
      "local before={scheduled=g:GetAttribute('Flow30DeleteArmBeforeScheduled')",
      "local transitioned=",
      "local phase=scheduled and 'armed'",
      "'invalidated:'..reason",
      "or 'callback_missed'",
      "state.exact=",
      "assert(state.exact",
      "H:JSONEncode(state)",
    ])
    && [
      '"scheduled"\\s*:\\s*true',
      '"key"\\s*:\\s*"slot:2:Forest Pup"',
      '"reason"\\s*:\\s*"armed"',
      '"index"\\s*:\\s*2',
      '"token"\\s*:\\s*"Forest Pup"',
      '"transitioned"\\s*:\\s*true',
      '"phase"\\s*:\\s*"armed"',
      '"exact"\\s*:\\s*true',
    ].every((pattern) => firstDeleteStateStep?.expectRegex?.includes(pattern))
    && !firstDeleteStateCode.includes("FireServer")
    && !firstDeleteStateCode.includes("ActionRequest"),
  "The first Delete press must assert its full exact-slot confirmation transition and diagnose armed, invalidated, or callback-missed state inline.",
);
check(
  "legacy_flow_proves_callback_request_and_result_reason",
  includesAll(duplicateSeedStep?.args?.code ?? "", [
    "Flow30RawPetRequestSequence",
    "Flow30RawPetRequestJSON",
    "remote.OnServerEvent:Connect",
    "LegacyPetServerResultSequence",
  ])
    && duplicateCallbackSteps.every(
      (step) =>
        step?.tool === "execute_luau"
        && step?.args?.datamodel_type === "Client"
        && includesAll(step?.args?.code ?? "", [
          "LegacyPetActionCallbackSequence",
          "g:GetAttribute('Flow30ExpectedCallbackSequence')",
          "LegacyPetActionCallback",
          "LegacyPetActionCallbackIndex",
          "H:JSONEncode(state)",
        ]),
    )
    && duplicateAuthoritySteps.every(
      (step) =>
        step?.tool === "execute_luau"
        && step?.args?.datamodel_type === "Server"
        && includesAll(step?.args?.code ?? "", [
          "local deadline=started+2",
          "Flow30RawPetRequestSequence",
          "Flow30RawPetRequestJSON",
          "LegacyPetServerResultSequence",
          "LegacyPetServerResultReason",
          "assert(state.exact",
          "H:JSONEncode(state)",
        ])
        && !step.args.code.includes("FireServer")
        && !step.args.code.includes(":Invoke("),
    )
    && (duplicateAuthoritySteps[1]?.args?.code ?? "").includes(
      "state.reason=='not_last_equipped'",
    )
    && duplicateAuthoritySteps[1]?.expectRegex?.includes(
      '"reason"\\s*:\\s*"not_last_equipped"',
    ),
  "Each real click must prove its client callback, raw server request, bounded authoritative result, and explicit exact-index rejection reason.",
);
check(
  "legacy_delete_first_click_is_local_only",
  deleteArm.includes("LegacyPetDeleteFirstClickMutationGuard")
    && deleteArm.includes('"LegacyPetDeleteConfirmationIndex", index')
    && deleteArm.includes('"LegacyPetDeleteConfirmationToken", tostring(token)')
    && deleteArm.includes('"LegacyPetDeleteConfirmationReason", "armed"')
    && !deleteArm.includes('action = "DeletePet"')
    && client.includes("It deliberately performs no remote mutation."),
  "The arming path must not mutate authority and must expose bounded exact-slot telemetry.",
);
check(
  "legacy_delete_second_click_dispatches_exact_slot",
  /IsDeleteArmed\(slotIndex, slotPetToken, inventory\)[\s\S]*?ClearDelete\("confirmed"\)[\s\S]*?actionRemote:FireServer\(\{ action = "DeletePet", target = slotPetToken, index = slotIndex \}\)/.test(
    client,
  ),
  "Only the confirmed, still-matching slot may dispatch DeletePet.",
);
check(
  "legacy_delete_confirmation_survives_rerender",
  deleteValidation.includes("inventory[index] == token")
    && deleteValidation.includes('ClearDelete("expired_or_slot_changed")')
    && deleteQuery.includes("legacyPetMenuRuntime.ValidateDelete(inventory)")
    && !deleteQuery.includes("ClearDelete(")
    && legacyPets.includes("legacyPetMenuRuntime.ValidateDelete(inventory)")
    && legacyPets.includes("task.defer(renderOpenPanel)"),
  "A different rendered row must not clear a still-valid exact-slot confirmation.",
);
check(
  "legacy_duplicate_callbacks_snapshot_exact_occurrence",
  legacyPets.includes("local slotIndex = index")
    && legacyPets.includes("local slotPetToken = petToken")
    && legacyPets.includes("legacyPetMenuRuntime.ArmDelete(slotIndex, slotPetToken)")
    && legacyPets.includes('action = "DeletePet", target = slotPetToken, index = slotIndex')
    && legacyPets.includes('action = "LockPet", target = slotPetToken')
    && legacyPets.includes('deleteButton:SetAttribute("ExactInventoryIndex", slotIndex)'),
  "Every duplicate-row callback must retain its own index/token snapshot.",
);
check(
  "legacy_delete_timeout_and_locked_guard",
  client.includes("deleteConfirmationSeconds = 3")
    && deleteArm.includes('legacyPetMenuRuntime.ClearDelete("timeout")')
    && client.includes('legacyPetMenuRuntime.ClearDelete("locked_guard")')
    && client.includes("deleteButton.Active = not isLocked")
    && client.includes("deleteButton.Selectable = not isLocked"),
  "Delete must expire and locked rows must remain inert.",
);
check(
  "legacy_flow_reacquires_fresh_confirmation_before_second_click",
  freshDeleteIndex === confirmDeleteIndex - 1
    && freshDeleteStep?.tool === "execute_luau"
    && freshDeleteStep?.args?.datamodel_type === "Client"
    && includesAll(freshDeleteCode, [
      'expose("#02  [Common] Forest Pup  *","Delete2","CONFIRM")',
      "GuiService.SelectedObject=current",
      "RunService.RenderStepped:Connect",
      "finalState.reacquired=observed==current",
      "finalState.selected=GuiService.SelectedObject==current",
      "state.exists=state.button",
      "state.armed=state.confirmationArmed",
      "state.index=state.exactIndex",
      "state.armed==true",
      "state.index==2",
      "H:JSONEncode(state)",
    ])
    && [
      '"exists"\\s*:\\s*true',
      '"text"\\s*:\\s*"CONFIRM"',
      '"armed"\\s*:\\s*true',
      '"index"\\s*:\\s*2',
      '"active"\\s*:\\s*true',
      '"selectable"\\s*:\\s*true',
      '"interactable"\\s*:\\s*true',
      '"ancestorVisible"\\s*:\\s*true',
      '"visibleArea"\\s*:\\s*true',
      '"topmost"\\s*:\\s*true',
      '"frames"\\s*:\\s*2',
      '"reacquired"\\s*:\\s*true',
      '"selected"\\s*:\\s*true',
    ].every((pattern) => freshDeleteStep?.expectRegex?.includes(pattern)),
  "The second click must target a freshly focused and reacquired, armed, interactable, ancestor-visible, clip-safe, topmost exact-slot button after rerender.",
);
check(
  "legacy_flow_proves_confirmed_client_callback_before_authority",
  confirmedMarkerIndex === confirmDeleteIndex + 1
    && authorityPollIndex === confirmedMarkerIndex + 1
    && confirmedMarkerStep?.tool === "execute_luau"
    && confirmedMarkerStep?.args?.datamodel_type === "Client"
    && includesAll(confirmedMarkerCode, [
      "LegacyPetDeleteConfirmationReason",
      "LegacyPetDeleteConfirmationScheduled",
      "state.reason=='confirmed'",
      "state.scheduled==false",
      "H:JSONEncode(state)",
    ])
    && confirmedMarkerStep?.expectRegex?.includes(
      '"reason"\\s*:\\s*"confirmed"',
    )
    && confirmedMarkerStep?.expectRegex?.includes(
      '"scheduled"\\s*:\\s*false',
    ),
  "The real second click must prove the confirmed client callback marker before polling authority.",
);
check(
  "legacy_flow_authority_poll_is_bounded_exact_and_diagnostic",
  authorityPollStep?.tool === "execute_luau"
    && authorityPollStep?.args?.datamodel_type === "Server"
    && includesAll(authorityPollCode, [
      "local deadline=started+2",
      "while true do",
      "os.clock()>=deadline",
      "task.wait(math.min(.05,math.max(0,deadline-os.clock())))",
      "count=#i",
      "one=i[1]",
      "two=i[2]",
      "lock=l[1]",
      "exact=#i==2 and i[1]=='Forest Pup' and i[2]=='Miner Cat' and l[1]=='slot:1'",
      "attempts=attempts",
      "elapsed=os.clock()-started",
      "assert(state.exact",
      "H:JSONEncode(state)",
    ])
    && !authorityPollCode.includes("FireServer")
    && !authorityPollCode.includes(":Invoke(")
    && !authorityPollCode.includes('action="DeletePet"')
    && !legacySlotSteps.some(
      (step) => step.label === "wait for authoritative Delete sync",
    )
    && [
      '"count"\\s*:\\s*2',
      '"one"\\s*:\\s*"Forest Pup"',
      '"two"\\s*:\\s*"Miner Cat"',
      '"lock"\\s*:\\s*"slot:1"',
      '"exact"\\s*:\\s*true',
    ].every((pattern) => authorityPollStep?.expectRegex?.includes(pattern)),
  "Authority must be observed with a <=2 second read-only poll and emit exact JSON diagnostics on failure.",
);
check(
  "legacy_flow_confirm_attempt_has_exactly_two_real_clicks_without_retry",
  reExposeDeleteIndex >= 0
    && rearmDeleteIndex > reExposeDeleteIndex
    && confirmDeleteIndex > rearmDeleteIndex
    && confirmAttemptClickSteps.length === 2
    && confirmAttemptClickSteps.every(
      (step) => coupledRealPress(step, "Delete2"),
    )
    && confirmAttemptClickActions.filter(
      (action) => action.action === "mouseButtonDown",
    ).length === 2
    && confirmAttemptClickActions.filter(
      (action) => action.action === "mouseButtonUp",
    ).length === 2
    && confirmAttemptClickActions.every(
      (action) => action.action !== "mouseButtonClick",
    )
    && legacySlotSteps
      .slice(rearmDeleteIndex + 1, confirmDeleteIndex)
      .every((step) => step.args?.datamodel_type !== "Server")
    && !confirmAttemptLuau.includes("FireServer")
    && !confirmAttemptLuau.includes("ActionRequest")
    && !confirmAttemptLuau.includes('action = "DeletePet"'),
  "The final confirmation attempt must contain exactly two balanced real Delete2 presses and no click shortcut or action retry.",
);
check(
  "procedural_pets_are_species_readable",
  proceduralPets.includes('"SpeciesReadableV2"')
    && proceduralPets.includes('"Pup Floppy Ear "')
    && proceduralPets.includes('"Miner Helmet"')
    && proceduralPets.includes('"Fox Crystal Shard "')
    && proceduralPets.includes('"Dragon Wing "')
    && proceduralPets.includes('"Guardian Armored Torso"')
    && proceduralPets.includes('"ProceduralPrimitiveBlob", false'),
  "Each base species needs a recognizable silhouette and identity feature.",
);
check(
  "procedural_pets_keep_bounded_existing_motion",
  client.includes('"ProceduralPetV2"')
    && client.includes('"ProceduralFallbackV2"')
    && client.includes("function companionRuntime.ResolveVisualPolicy")
    && client.includes('"Reposition>Scale>LOD>Cull"')
    && !proceduralPets.includes("Heartbeat:Connect")
    && !proceduralPets.includes("RenderStepped:Connect"),
  "Visual upgrades must reuse the bounded companion runtime without another loop.",
);
// Test the active first-five catalog route; inactive HeroGauntlet code cannot satisfy it.
function evaluateFistSources(clientSource, builderSource) {
 const runtime=section(clientSource,'function companionRuntime.BuildItemMatchedGauntlet','function companionRuntime.BuildHeroGauntlet');
 const catalog=section(runtime,'local catalogModel, catalogSpec = FistVisualBuilder.BuildCatalogModel(definition)','local importedSource');
 const modelBuilder=section(builderSource,'function FistVisualBuilder.BuildCatalogModel','function FistVisualBuilder.ComputeImportedScale');
 const spec=section(builderSource,'local CATALOG_GEOMETRY_VERSION','function FistVisualBuilder.BuildCatalogModel');
 const preview=section(clientSource,'function shopRuntime.AddCatalogFistPreview','function shopRuntime.AddStaticFistPresentation');
 const inventory=section(clientSource,'function companionRuntime.BuildInventoryFistPreview','function companionRuntime.BuildItemMatchedGauntlet');
 const classes=[...modelBuilder.matchAll(/Instance\.new\("([^"]+)"\)/g)].map(m=>m[1]);
 return {
  active_route_prefers_catalog_retains_sanitized_fallback:
   clientSource.includes('companionRuntime.BuildItemMatchedGauntlet(latestStats.EquippedFist or "Starter Glove")')
   && includesAll(runtime,['"VisualSystem", "ItemMatchedClosedFistV3"','"SanitizedCreatorStoreMesh"','"CreatorStore_ArmoredClosedHeroFist"','"ItemColorMatched", true','"ItemMaterialMatched", true'])
   && includesAll(catalog,['"SharedCatalogGeometry"','"ImportedRuntimeSilhouette", false','"ItemVisualReady", true','return true'])
   && runtime.indexOf('FistVisualBuilder.BuildCatalogModel(definition)')<runtime.indexOf('local importedSource'),
  native_geometry_is_visual_only_and_bounded:
   classes.length===2 && classes[0]==='Model' && classes[1]==='Part'
   && includesAll(modelBuilder,['#spec.parts >= 12','#spec.parts <= spec.partBudget','part.Anchored = true','part.CanCollide = false','part.CanTouch = false','part.CanQuery = false','part.Massless = true','part.CastShadow = false','FistVisualBuilder.SanitizeVisual(model)'])
   && spec.includes('partBudget = 28') && !/Heartbeat:Connect|RenderStepped:Connect|while\s/.test(modelBuilder),
  first_five_have_closed_anatomy_and_wrist_origin:
   ['Starter Glove','Boxing Glove','Iron Knuckle','Thunder Fist','Titan Gauntlet'].every(name=>spec.includes('["'+name+'"]'))
   && includesAll(spec,['catalog_identity_mismatch','unsupported_catalog_fist','Catalog Closed Palm','Catalog Wrist Cuff','Catalog Backhand Guard','Catalog Knuckle ','Catalog Curled Finger ','Catalog Folded Thumb','for finger = 1, 4 do','wristOrigin = CFrame.identity'])
   && includesAll(modelBuilder,['model.WorldPivot = spec.wristOrigin','"FistCatalogVisual", true','"CatalogGeometryVersion", spec.version','"FistVisualKey", spec.name','"HasEnergyCore", spec.tier >= 4']),
  catalog_equipment_welds_measures_final_bounds_and_tears_down:
   includesAll(runtime,['if currentGauntlet then currentGauntlet:Destroy() end','"WholeHandHidden", false','"HandTransparencyPreserved", true'])
   && includesAll(catalog,['hand.Size.X','catalogSpec.referenceHandWidth','rigProfile.cuffYScale','math.rad(180)','part.Anchored = false','Instance.new("WeldConstraint")','weld.Part0, weld.Part1 = part, hand','catalogModel:GetBoundingBox()','"CatalogWristOriginV1"','"WristAttachmentBounded"','"FaceOcclusionSafe"'])
   && catalog.indexOf('catalogModel:GetBoundingBox()')>catalog.indexOf('catalogModel:PivotTo(wrist)') && !/Heartbeat:Connect|RenderStepped:Connect/.test(catalog),
  imported_fallback_retains_collision_and_budget_guards:
   includesAll(runtime,['descendant.CanCollide = false','descendant.CanTouch = false','descendant.CanQuery = false','"WristAttachmentBounded", wristCenterOffset <= rigProfile.maxCenterOffset','"FaceOcclusionSafe", visualToHandRatio <= rigProfile.maxTargetRatio + 0.01','"WithinVisualPartBudget", visualPartCount <= 28'])
   && !/Heartbeat:Connect|RenderStepped:Connect/.test(runtime),
  both_routes_reuse_bounded_motion_aware_aura:
   catalog.includes('addTierAura(palm)') && includesAll(runtime,['if tier < 3 then','"AuraClass", "None"','"AuraEmitterCount", emitterCount','"AuraTotalRate", totalRate','"FistAuraEffect", true','"ProminenceSystem", "TierHeroVolumeV4"'])
   && clientSource.includes('shared.PunchWallApplyFistAuraMotion = companionRuntime.ApplyFistAuraMotionSetting') && clientSource.includes('"AuraReducedMotionSuppressed", not enabled and emitterCount > 0'),
  r6_and_r15_have_live_shared_wrist_profiles:
   includesAll(builderSource,['name = "R15RightHand"','name = "R6DistalWrist"','function FistVisualBuilder.GetRigProfile'])
   && includesAll(catalog,['FistVisualBuilder.GetRigProfile(hand)','rigProfile.cuffYScale','"AlignmentStandard", rigProfile.name']),
  shop_and_inventory_use_same_catalog_builder:
   includesAll(preview,['FistVisualBuilder.BuildCatalogModel(item)','"FistCatalogPreview"','"FistVisualKey", item.name','"RenderLoop", false'])
   && inventory.includes('FistVisualBuilder.BuildCatalogModel(GameConfig.FistDefinition(fistName))') && clientSource.includes('BuildFistPreview = companionRuntime.BuildInventoryFistPreview'),
  shop_catalog_releases_hidden_models_and_connections:
   includesAll(preview,['card.AbsolutePosition','scroll.AbsolutePosition','"FistPreviewVisible", visible','if visible and not model then','elseif not visible and model then','model:Destroy()','model = nil','viewport.Destroying:Once(function()','connection:Disconnect()'])
   && !/Heartbeat:Connect|RenderStepped:Connect/.test(preview),
  static_fallback_retains_distinct_existing_art_keys:
   /Boxing = \{[\s\S]*?shopArtKey = "StarterGlove"/.test(builderSource) && /Iron = \{[\s\S]*?shopArtKey = "ChampionGlove"/.test(builderSource) && /Thunder = \{[\s\S]*?shopArtKey = "TitanGlove"/.test(builderSource),
 };
}
const fistChecks=evaluateFistSources(client,builder);
for(const [name,value] of Object.entries(fistChecks))check(name,value,'Active shared catalog or preserved sanitized fallback safety contract missing.');
const negativeControls=[];
function rejectsFistMutation(name,target,kind,before,after){
 const original=kind==='client'?client:builder;
 const mutated=original.replace(before,after);
 const actual=evaluateFistSources(kind==='client'?mutated:client,kind==='builder'?mutated:builder);
 const rejected=original!==mutated&&fistChecks[target]===true&&actual[target]===false;
 negativeControls.push({name,target,status:rejected?'REJECTED':'BLOCKED',positiveBaseline:fistChecks[target]===true,mutationApplied:original!==mutated});
 return rejected;
}
const negativeResults=[
 rejectsFistMutation('remove_active_catalog_route','active_route_prefers_catalog_retains_sanitized_fallback','client','local catalogModel, catalogSpec = FistVisualBuilder.BuildCatalogModel(definition)','local catalogModel, catalogSpec = nil, nil'),
 rejectsFistMutation('allow_catalog_collision','native_geometry_is_visual_only_and_bounded','builder','part.CanCollide = false','part.CanCollide = true'),
 rejectsFistMutation('inflate_part_budget','native_geometry_is_visual_only_and_bounded','builder','partBudget = 28','partBudget = 999'),
 rejectsFistMutation('wrong_weld_endpoint','catalog_equipment_welds_measures_final_bounds_and_tears_down','client','weld.Part0, weld.Part1 = part, hand','weld.Part0, weld.Part1 = part, part'),
 rejectsFistMutation('leak_preview_connections','shop_catalog_releases_hidden_models_and_connections','client',/viewport\.Destroying:Once\(function\(\)\s*for _, connection in ipairs\(connections\) do connection:Disconnect\(\) end/,'viewport.Destroying:Once(function() for _, connection in ipairs(connections) do print(connection) end'),
];
check('live_fist_negative_controls_reject_regressions',negativeResults.every(Boolean),'Every negative control needs a positive baseline and must fail its specific safety gate.');
check(
  "shop_fallback_loaded_art_uses_perimeter_only_static_identity",
  shopPresentation.includes('"HeroGauntletTierChrome"')
    && shopPresentation.includes('"StaticPreviewRenderLoop", false')
    && shopPresentation.includes('"StaticPreviewChromeOnly", true')
    && shopPresentation.includes('"StaticPreviewChromeCoverage", "PerimeterOnlyV1"')
    && shopPresentation.includes('"StaticPreviewIdentityVersion", "UniqueFistPerimeterV2"')
    && shopPresentation.includes('"StaticPreviewStyleVersion", "PerimeterCatalogIdentityV2"')
    && shopPresentation.includes('card:SetAttribute("ShopFistStyle", presentation.style)')
    && shopPresentation.includes('card:SetAttribute("ShopFistArmorPattern", presentation.armorPattern)')
    && shopPresentation.includes('card:SetAttribute("ShopFistSignatureFeature", presentation.signatureFeature)')
    && shopPresentation.includes('card:SetAttribute("ShopFistCatalogMotif", presentation.catalogMotif)')
    && shopPresentation.includes("icon.ImageColor3 = Color3.new(1, 1, 1)")
    && shopPresentation.includes("icon.ImageTransparency = 0")
    && shopPresentation.includes('"HeroGauntletTintMatched", false')
    && shopPresentation.includes('"LoadedArtUnobscured", icon.Image ~= ""')
    && shopPresentation.includes('"StaticTierOutline"')
    && shopPresentation.includes('"StaticTierBadge"')
    && shopPresentation.includes('"StaticTierNumber"')
    && shopPresentation.includes('("T%02d"):format(presentation.tier)')
    && shopPresentation.includes('"StaticSignatureFeature"')
    && shopPresentation.includes('"StaticCatalogMotif"')
    && shopPresentation.includes('"StaticTierRail"')
    && shopPresentation.includes('"StaticTierPip" .. tierIndex')
    && shopPresentation.includes('"StaticArmorPlate" .. plateIndex')
    && shopPresentation.includes('"StaticArmorFin" .. finIndex')
    && shopPresentation.includes('"StaticPreviewPartCount"')
    && !shopPresentation.includes("icon.ImageColor3 = Color3.new(1, 1, 1):Lerp(")
    && !shopPresentation.includes("Heartbeat:Connect")
    && !shopPresentation.includes("RenderStepped:Connect"),
  "Loaded fist art must remain white and unobscured while unique style, motif, and signature identity stays in bounded perimeter chrome.",
);
const shopDescriptionSurface = section(client, 'for index, item in ipairs(products) do', 'detail:SetAttribute("DescriptionReadabilityMode"');
function validShopDescriptionSurface(source) {
  const background = source.match(/card\.BackgroundColor3 = Color3\.fromRGB\((\d+), (\d+), (\d+)\)/);
  const foreground = source.match(/local detail = label\(card, "Detail",[^\n]+Color3\.fromRGB\((\d+), (\d+), (\d+)\), 12, Enum\.Font\.GothamMedium/);
  if (!background || !foreground) return false;
  const luminance = match => match.slice(1, 4).map(Number).map(value => {
    const channel = value / 255;
    return channel <= 0.04045 ? channel / 12.92 : ((channel + 0.055) / 1.055) ** 2.4;
  }).reduce((sum, value, index) => sum + value * [0.2126, 0.7152, 0.0722][index], 0);
  const dark = luminance(background), light = luminance(foreground);
  return dark < 0.05 && (light + 0.05) / (dark + 0.05) >= 7
    && source.includes('detailBackdrop.Visible = false')
    && source.includes('detail.TextStrokeTransparency = 1')
    && source.includes('ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1))')
    && source.includes('ColorSequenceKeypoint.new(1, Color3.fromRGB(242, 247, 252))');
}
check('shop_description_has_high_contrast_readability_surface', validShopDescriptionSurface(shopDescriptionSurface),
  'Descriptions require a quiet dark card with at least 7:1 authored text contrast and medium-weight type.');
for (const [name, from, to] of [
  ['bright_card', 'card.BackgroundColor3 = Color3.fromRGB(18, 26, 38)', 'card.BackgroundColor3 = Color3.fromRGB(230, 230, 230)'],
  ['low_contrast_text', 'Color3.fromRGB(236, 242, 244), 12, Enum.Font.GothamMedium', 'Color3.fromRGB(40, 48, 56), 12, Enum.Font.GothamMedium'],
  ['extra_backdrop', 'detailBackdrop.Visible = false', 'detailBackdrop.Visible = true'],
]) {
  const mutated = shopDescriptionSurface.replace(from, to);
  check('shop_description_rejects_' + name, validShopDescriptionSurface(shopDescriptionSurface) && mutated !== shopDescriptionSurface && !validShopDescriptionSurface(mutated),
    'The readability surface check must reject this distinct regression.');
}
check(
  "shop_feedback_text_is_explicit_and_truthful",
  feedbackText.includes('elseif payload.type == "Shop" then')
    && feedbackText.includes('local message = tostring(payload.message or "")')
    && feedbackText.includes("return string.upper(message)")
    && feedbackText.includes('local target = tostring(payload.target or "")')
    && feedbackText.includes("if fist and fist.name == target then")
    && feedbackText.includes('"EQUIPPED | %s"')
    && feedbackText.includes('"SHOP | %s"'),
  "Shop feedback must prefer authoritative messages, identify real fist equips, and avoid claiming unknown targets were equipped.",
);
check(
  "shop_feedback_uses_existing_starter_fist_icon",
  feedbackIcon.includes('Shop = "StarterFist"'),
  "Shop feedback must resolve through the existing StarterFist theme icon.",
);
check(
  "shop_feedback_uses_bounded_no_center_toast_without_sound_change",
  showFeedback.includes('or payload.type == "PremiumPrompt" or payload.type == "PremiumSetup" or payload.type == "Fail" or payload.type == "Shop" then')
    && showFeedback.includes('payload.type ~= "Fail" and payload.type ~= "PremiumSetup" and payload.type ~= "PremiumPrompt" and payload.type ~= "Shop"')
    && showFeedback.includes("shared.PunchWallShowToast(")
    && showFeedback.includes("feedbackText(payload)")
    && showFeedback.includes("feedbackIcon(payload.type)")
    && feedbackPresentation.includes("maxToasts = 3")
    && feedbackPresentation.includes("while #list >= limit do")
    && feedbackPresentation.includes("local oldest = table.remove(list, 1)")
    && feedbackPresentation.includes("if oldest.Parent then oldest:Destroy() end")
    && boundedToast.includes(
      "feedbackPresentation.Present(toastHolder, feedbackPresentation.toasts, toast, feedbackPresentation.maxToasts)",
    )
    && boundedToast.includes('local compactToast = UserInputService.TouchEnabled')
    && boundedToast.includes('compactToast and 232 or 440')
    && boundedToast.includes('compactToast and 34 or 46')
    && boundedToast.includes('compactToast and -31 or -44')
    && boundedToast.includes('compactToast and 26 or 34')
    && boundedToast.includes('"PhoneCompactNoticeV1"'),
  "With center feedback disabled, Shop must reuse the existing three-item bounded toast queue and preserve prior sound behavior.",
);
check(
  "shop_feedback_flow_proves_visible_exact_bounded_toast_icon",
  shopToastFlowCode.includes('g:FindFirstChild("Toasts")')
    && shopToastFlowCode.includes("holder:GetChildren()")
    && !shopToastFlowCode.includes("g:GetDescendants()")
    && shopToastFlowCode.includes('toast:IsA("GuiObject") and toast.Visible')
    && shopToastFlowCode.includes('toast:FindFirstChild("ToastIcon")')
    && shopToastFlowCode.includes("icon.Visible")
    && shopToastFlowCode.includes('icon.Image=="rbxassetid://104014193600358"')
    && shopToastFlowCode.includes('icon:GetAttribute("ThemeIcon")=="StarterFist"')
    && shopToastFlowCode.includes("icon.ImageRectOffset==Vector2.new(191,187)")
    && shopToastFlowCode.includes("icon.ImageRectSize==Vector2.new(70,122)")
    && shopToastFlowCode.includes('mode=="BoundedVisibleQueueV1"')
    && shopToastFlowCode.includes("visibleItems>=1 and visibleItems<=3")
    && shopToastFlowCode.includes("countSynced=tracked==visibleItems")
    && shopToastFlowCode.includes('feedbackType=="Shop"')
    && shopToastFlowExpect.includes('"holderVisible"\\s*:\\s*true')
    && shopToastFlowExpect.includes('"visibleItems"\\s*:\\s*[1-3]')
    && shopToastFlowExpect.includes('"countSynced"\\s*:\\s*true')
    && shopToastFlowExpect.includes('"valid"\\s*:\\s*true'),
  "The Shop flow must assert the visible no-center ToastIcon, exact StarterFist atlas region, synchronized bounded count, and Shop feedback type.",
);
check(
  "contextual_train_and_use_reuse_target_scan",
  contextualActions.includes('candidate:GetAttribute("TrainingStationId") ~= nil')
    && contextualActions.includes('candidate:GetAttribute("PowerPerSecond") ~= nil')
    && contextualActions.includes('candidate.Name == "Pet Egg Machine"')
    && contextualActions.includes('candidate.Name == "Rebirth Shrine"')
    && contextualActions.includes('candidate:GetAttribute("PremiumOnly") == true')
    && contextualActions.includes('candidate:GetAttribute("InteractionMenu") ~= nil')
    && client.includes('"ContextualActionUsesExistingTargetScan", true')
    && client.includes('"ContextualActionScanInterval", 0.15')
    && client.includes("for folderIndex = 1, 2 do")
    && client.includes("clientRuntime.InteractablesFolder")
    && (client.match(/local targetTimer = 0/g) ?? []).length === 1,
  "Progressive TRAIN/USE discovery must reuse the single bounded 0.15-second target scan.",
);
check(
  "contextual_action_is_visible_safe_and_exact",
  client.includes('Name = "ContextAction"')
    && client.includes("contextActionSize.MinSize = Vector2.new(196, 52)")
    && client.includes('Name = "ActionTitle"')
    && client.includes('Name = "ActionDetail"')
    && client.includes('"PresentationVersion", "TwoLineCompactV2"')
    && client.includes('"SafeAreaLane", "CenterAboveTraining"')
    && client.includes("requestAction(actionName)")
    && client.includes('actionName ~= "Train" and actionName ~= "Use"')
    && client.includes("and not mainPanel.Visible"),
  "The reference HUD needs a >=44px safe action button with exact requests.",
);

const feedbackHolderFlowPath = path.join(repositoryRoot, 'work/automation/flows/feedback-holder-presentation.json');
const feedbackHolderFlow = JSON.parse(fs.readFileSync(feedbackHolderFlowPath, 'utf8'));
function validLegacySurface(candidate) {
 const open = candidate.steps.find(step => step.label === 'open legacy Pets and expose duplicate slot two action')?.args?.code ?? '';
 return includesAll(open, ["IsStudio()", "a:Invoke('CloseMenus')", "g:SetAttribute('AutomationTab','Pets')", "g:GetAttribute('RenderedGenericTab')=='Pets'", 'and modern and not modern.Visible', 'local routeDeadline=os.clock()+3'])
  && !open.includes("a:Invoke('OpenTab','Pets')")
  && includesAll(client, ['gui:GetAttributeChangedSignal("AutomationTab"):Connect(function()', 'activeTab = requestedTab', 'renderOpenPanel()']);
}
check('legacy_flow_opens_existing_studio_hook_and_proves_legacy_surface', validLegacySurface(legacySlotFlow), 'Public Pets intentionally routes to modern Inventory; retained legacy callbacks require the existing Studio hook and actual surface checks.');
const legacyRouteNegativeControls=[];
for(const [name,from,to] of [
 ['public_modern_route',"g:SetAttribute('AutomationTab','Pets')","a:Invoke('OpenTab','Pets')"],
 ['remove_legacy_surface_assertion','and modern and not modern.Visible','and modern'],
]) {
 const candidate=structuredClone(legacySlotFlow);
 const step=candidate.steps.find(item=>item.label==='open legacy Pets and expose duplicate slot two action');
 const original=step.args.code;step.args.code=original.replace(from,to);
 const applied=step.args.code!==original,rejected=!validLegacySurface(candidate);
 check('legacy_route_negative_'+name,applied&&rejected,'The invalid legacy route must be detected.');
 legacyRouteNegativeControls.push({name,mutationApplied:applied,status:rejected?'REJECTED':'MISSED'});
}
const seedCode=duplicateSeedStep.args.code;
check('legacy_duplicate_seed_refuses_live_persistence',includesAll(seedCode,["PersistenceMode')=='EphemeralStudio'","ProfileWritable')==false","PunchWallAllowLiveDataStoreAccess')~=true"])&&seedCode.indexOf('verifyEphemeralSeed(game.Players:GetPlayers()[1]')<seedCode.indexOf("c:Invoke('Reset')"),'Duplicate fixture must fail closed before Reset.');
const rejectionStep=feedbackHolderFlow.steps.find(step=>step.label==='request a gated rebirth through the player remote');
const premiumArmStep=feedbackHolderFlow.steps.find(step=>step.label==='arm exact premium Feedback observation before server grant');
const premiumGrantStep=feedbackHolderFlow.steps.find(step=>step.label==='request the deterministic Studio premium pet grant');
const premiumVerifyStep=feedbackHolderFlow.steps.find(step=>step.label==='premium grant renders one visible feedback channel');
const rejectionCode=rejectionStep?.args?.code??'';
const premiumArmCode=premiumArmStep?.args?.code??'';
const premiumGrantCode=premiumGrantStep?.args?.code??'';
const premiumVerifyCode=premiumVerifyStep?.args?.code??'';
check('feedback_rebirth_captures_numeric_baseline_and_real_event_in_one_call',includesAll(rejectionCode,["local before=tonumber(g:GetAttribute('FeedbackCount')) or 0",'events.Feedback.OnClientEvent:Connect(function(payload)',"events.ActionRequest:FireServer({action='Rebirth'})",'evidence.eventCount+=1','connection:Disconnect()',"pcall(verifyFeedbackEvidence,evidence,'Fail','Rebirth')",'return encoded'])&&rejectionCode.indexOf('local before=')<rejectionCode.indexOf('events.Feedback.OnClientEvent:Connect')&&rejectionCode.indexOf('events.Feedback.OnClientEvent:Connect')<rejectionCode.indexOf('events.ActionRequest:FireServer'), 'The before value, actual event, displayed identity, count increment and visible channel must belong to the same action call.');
check('feedback_premium_grant_is_guarded_and_observed_without_commerce',premiumGrantStep?.args?.datamodel_type==='Server'&&includesAll(premiumGrantCode,["PersistenceMode')=='EphemeralStudio'","ProfileWritable')==false","Invoke('GrantPremiumPet','Crimson Phoenix')",'OwnedPremiumPetsJSON.Value','PetInventoryJSON.Value'])&&!JSON.stringify(feedbackHolderFlow).includes('BuyPremiumPet')&&includesAll(premiumArmCode,['local before=','events.Feedback.OnClientEvent:Connect(function(payload)','evidence.eventCount+=1','task.delay(30,function()connection:Disconnect()end)'])&&includesAll(premiumVerifyCode,["pcall(verifyFeedbackEvidence,evidence,'Pet','Crimson Phoenix')",'evidence.token==token'])&&feedbackHolderFlow.steps.indexOf(premiumArmStep)<feedbackHolderFlow.steps.indexOf(premiumGrantStep)&&feedbackHolderFlow.steps.indexOf(premiumGrantStep)<feedbackHolderFlow.steps.indexOf(premiumVerifyStep),'A server grant is an ephemeral test fixture; real commerce prompts cannot substitute for granting or feedback.');
const exactFeedbackHelper = section(rejectionCode, 'local function verifyFeedbackEvidence(', "g.PunchWallClientAutomation:Invoke('ClearToasts')").trim();
const premiumFeedbackHelper = section(premiumVerifyCode, 'local function verifyFeedbackEvidence(', 'local token=assert(').trim();
check('feedback_evidence_uses_one_exact_shared_verifier', exactFeedbackHelper.length>500&&exactFeedbackHelper===premiumFeedbackHelper, 'Both paths must use the same strict count, event, identity and actual channel verifier.');
const feedbackHelperFixture = String.raw`
local function valid(reward)
 return {presentationCaptured=true,before=10,after=11,delta=1,baselineVisualCount=0,eventCount=1,events={{type='Pet',target='Crimson Phoenix'}},type='Pet',target='Crimson Phoenix',channels=1,toasts=reward and 0 or 1,rewards=reward and 1 or 0,presented=true}
end
local safe,rejected=0,0
local function test(name,mutation,reward)
 local e=valid(reward) if mutation then mutation(e) end
 local ok=pcall(verifyFeedbackEvidence,e,'Pet','Crimson Phoenix')
 assert(ok==(mutation==nil),name..' verifier outcome incorrect')
 if ok then safe+=1 else rejected+=1 end
end
test('one toast') test('one reward',nil,true)
test('missing actual presentation capture',function(e)e.presentationCaptured=false end)
test('counter missing',function(e)e.after=10 e.delta=0 end)
test('counter doubled',function(e)e.after=12 e.delta=2 end)
test('missing actual event',function(e)e.eventCount=0 e.events={} end)
test('duplicate actual event',function(e)e.eventCount=2 table.insert(e.events,{type='Pet',target='Crimson Phoenix'})end)
test('wrong event type',function(e)e.events[1].type='Fail'end)
test('wrong event target',function(e)e.events[1].target='Rebirth'end)
test('wrong displayed type',function(e)e.type='Fail'end)
test('wrong displayed target',function(e)e.target='Rebirth'end)
test('two channels',function(e)e.rewards=1 e.channels=2 end)
test('two instances in one channel',function(e)e.toasts=2 end)
test('no visible presentation',function(e)e.toasts=0 e.channels=0 e.presented=false end)
test('stale visible item',function(e)e.baselineVisualCount=1 end)
test('non numeric baseline',function(e)e.before='10'end)
assert(safe==2 and rejected==14)
print('EXACT_FEEDBACK_HELPER_PASS safe='..safe..' rejected='..rejected)
`;
function executeFeedbackHelper(helper) {
 const code=helper+'\n'+feedbackHelperFixture;
 let input='LegacyInputContract=""\n';
 for(let i=0;i<code.length;i+=200)input+='LegacyInputContract=LegacyInputContract..'+JSON.stringify(code.slice(i,i+200))+'\n';
 input+='assert(loadstring(LegacyInputContract))()\n';
 const result=spawnSync(process.env.LUAU_COMMAND||'C:/Users/Jennarong Pinjai/AppData/Local/Temp/codex-luau-smash-0.737/luau.exe',[],{input,encoding:'utf8',maxBuffer:4*1024*1024});
 const output=(result.stdout??'')+(result.stderr??'');
 return {pass:result.status===0&&output.includes('EXACT_FEEDBACK_HELPER_PASS safe=2 rejected=14')&&!/stdin:|stack backtrace|SyntaxError/.test(output),output,error:result.error?.message};
}
const feedbackHelperResult=executeFeedbackHelper(exactFeedbackHelper);
check('feedback_exact_helper_accepts_two_valid_and_rejects_fourteen_faults',feedbackHelperResult.pass,feedbackHelperResult.error||feedbackHelperResult.output);
const feedbackWeakeningControls=[];
for(const [name,pattern] of [
 ['omit_count_check',/^ assert\(type\(e.before\)[^\n]+$/m],
 ['omit_actual_event_count',/^ assert\(e.eventCount[^\n]+$/m],
 ['omit_visible_channel_check',/^ assert\(e.channels[^\n]+$/m],
]) {
 const weakened=exactFeedbackHelper.replace(pattern,'');
 const applied=weakened!==exactFeedbackHelper;
 const result=executeFeedbackHelper(weakened);
 check('feedback_negative_'+name,feedbackHelperResult.pass&&applied&&!result.pass,'Weakening an exact evidence guard must make the helper fixture fail.');
 feedbackWeakeningControls.push({name,mutationApplied:applied,status:!result.pass?'REJECTED':'MISSED'});
}

function validLegacyIdleObservation(candidate) {
 const code=candidate.steps.find(step=>step.label==='open legacy Pets and expose duplicate slot two action')?.args?.code??'';
 const observation=section(code,'local function observeIdleControl(','local state=expose(');
 return includesAll(observation,[
  'local original=assert(currentButton()', 'local observed,destroyed=false,false',
  'StatsChanged.OnClientEvent:Connect(function(payload)', '(tonumber(payload.PlaytimeSeconds) or 0)>startPlaytime',
  'original.Destroying:Connect(function()destroyed=true end)', 'b==original and b:IsDescendantOf(c) and not destroyed',
  'hittable=live and contained and ancestorVisible', 'local deadline=os.clock()+3',
  'stats:Disconnect()', 'lifetime:Disconnect()', 'pcall(verifyIdleControlState,result)',
  "g:GetAttribute('GenericPanelStructuralRenderCount')", 'requestAfter=p:GetAttribute(requestAttribute) or 0',
 ]) && !/FireServer|:Invoke\(|CreateVirtualInput|SendMouse|SetAttribute/.test(observation)
  && includesAll(code,["observeIdleControl(currentIdleButton,g.GameMenu.Content,g,p,'Flow30RawPetRequestSequence')",'state.idleIdentityStable=idle.identityStable','state.idleCanvasStable=idle.canvasStable'])
  && code.indexOf('local idle=observeIdleControl(')<code.indexOf("g:SetAttribute('Flow30ExpectedCallbackSequence'");
}
check('legacy_real_input_waits_for_an_actual_idle_snapshot_without_replacing_target',validLegacyIdleObservation(legacySlotFlow),'Before one real Equip gesture, observe an increasing real Playtime payload, current Instance identity, canvas and request count; disconnect all temporary listeners without injecting input or changing the UI.');
const idleObservationNegativeControls=[];
for(const [name,from,to]of[
 ['drop_identity_equality','b==original and b:IsDescendantOf(c) and not destroyed','b:IsDescendantOf(c)'],
 ['force_hittable','hittable=live and contained and ancestorVisible','hittable=true or live and contained and ancestorVisible'],
 ['remove_stats_listener_cleanup','stats:Disconnect()','-- omitted cleanup'],
]) {
 const candidate=structuredClone(legacySlotFlow);const step=candidate.steps.find(item=>item.label==='open legacy Pets and expose duplicate slot two action');
 const original=step.args.code;step.args.code=original.replace(from,to);
 const applied=step.args.code!==original,rejected=!validLegacyIdleObservation(candidate);
 check('legacy_idle_negative_'+name,applied&&rejected,'A weakened idle-input evidence path must be rejected.');
 idleObservationNegativeControls.push({name,mutationApplied:applied,status:rejected?'REJECTED':'MISSED'});
}

const passed = Object.values(checks).filter(Boolean).length;
const total = Object.keys(checks).length;
const ok = passed === total;
console.log(
  JSON.stringify(
    {
      ok,
      passed,
      total,
      checks,
      negativeControls,
      legacyRouteNegativeControls,
      feedbackWeakeningControls,
      idleObservationNegativeControls,
      feedbackHelperControls: {valid: 2, rejected: 14, passed: feedbackHelperResult.pass},
      sourceRoot: repositoryRoot,
      sourceHashes: Object.fromEntries(Object.entries({client,server,builder}).map(([name,text]) => [name,createHash("sha256").update(text).digest("hex")])),
      studioRuntimeStatus: "BLOCKED_PENDING_SEPARATE_COORDINATOR_RUNTIME_EVIDENCE",
      failures: notes,
      files: [
        path.relative(repositoryRoot, clientPath),
        path.relative(repositoryRoot, serverPath),
        path.relative(repositoryRoot, builderPath),
        path.relative(repositoryRoot, fistItemsFlowPath),
        path.relative(repositoryRoot, legacySlotFlowPath),
        path.relative(repositoryRoot, feedbackHolderFlowPath),
        path.relative(repositoryRoot, studioMcpClientPath),
      ],
    },
    null,
    2,
  ),
);
if (!ok) process.exitCode = 1;
