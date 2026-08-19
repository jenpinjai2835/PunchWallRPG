import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const repositoryRoot = path.resolve(import.meta.dirname, "..", "..", "..");
const alignmentPath = path.join(
  repositoryRoot,
  "work",
  "automation",
  "flows",
  "fist-arm-alignment-qc.json",
);
const creatorStorePath = path.join(
  repositoryRoot,
  "work",
  "automation",
  "flows",
  "creator-store-fist-visuals.json",
);

const alignment = JSON.parse(fs.readFileSync(alignmentPath, "utf8"));
const creatorStore = JSON.parse(fs.readFileSync(creatorStorePath, "utf8"));
const checks = {};
const failures = {};

function check(name, ok, note) {
  checks[name] = Boolean(ok);
  if (!ok) failures[name] = note;
}

function includesAll(source, needles) {
  return needles.every((needle) => source.includes(needle));
}

function executeSteps(flow, datamodelType) {
  return flow.steps.filter(
    (step) =>
      step.tool === "execute_luau"
      && (!datamodelType || step.args?.datamodel_type === datamodelType),
  );
}

function combinedCode(flow) {
  return executeSteps(flow)
    .map((step) => step.args?.code ?? "")
    .join("\n");
}

function terminalContract(flow) {
  const steps = flow.steps ?? [];
  const cleanup = flow.cleanup ?? [];
  return steps.at(-3)?.tool === "get_console_output"
    && steps.at(-2)?.type === "assertNoConsoleErrors"
    && steps.at(-1)?.tool === "start_stop_play"
    && steps.at(-1)?.args?.is_start === false
    && cleanup.length === 1
    && cleanup[0]?.tool === "start_stop_play"
    && cleanup[0]?.args?.is_start === false
    && cleanup[0]?.allowError === true;
}

function countLiteral(source, literal) {
  return source.split(literal).length - 1;
}

const alignmentCode = combinedCode(alignment);
const creatorStoreCode = combinedCode(creatorStore);
const allCode = `${alignmentCode}\n${creatorStoreCode}`;
const alignmentServer = executeSteps(alignment, "Server")[0]?.args?.code ?? "";
const creatorStoreServer =
  executeSteps(creatorStore, "Server").find((step) =>
    step.label?.includes("prepare all eight"),
  )?.args?.code ?? "";
const alignmentMatrix =
  alignment.steps.find((step) => step.saveAs === "alignmentMatrix") ?? {};
const creatorStoreMatrix =
  creatorStore.steps.find((step) => step.saveAs === "fistTierMatrix") ?? {};
const shopChrome =
  creatorStore.steps.find((step) => step.saveAs === "creatorStoreShopChrome")
  ?? {};
const postRespawn =
  creatorStore.steps.find(
    (step) => step.saveAs === "postRespawnPunchDiagnostics",
  ) ?? {};
const alignmentMatrixCode = alignmentMatrix.args?.code ?? "";
const creatorStoreMatrixCode = creatorStoreMatrix.args?.code ?? "";
const shopChromeCode = shopChrome.args?.code ?? "";
const postRespawnCode = postRespawn.args?.code ?? "";

const commonAnatomy = [
  "Hero Gauntlet Palm Shell",
  "Hero Gauntlet Wrist Cuff",
  "Hero Gauntlet Wrist Bridge",
  "Hero Gauntlet Backhand Plate",
  "Hero Closed Knuckle 1",
  "Hero Closed Knuckle 2",
  "Hero Closed Knuckle 3",
  "Hero Closed Knuckle 4",
  "Hero Folded Thumb",
  "Hero Gauntlet Energy Core",
  "KnuckleCount",
  "HasWristCuff",
  "HasBackhandPlate",
  "HasFoldedThumb",
  "HasEnergyCore",
];
const commonIdentity = [
  "HeroGauntletV2",
  "ProceduralRuntime",
  "ImportedRuntimeSilhouette",
  "SilhouetteFamily",
  "ShopArtMatchedTier",
  "ArmorPattern",
  "TierAura",
  "AuraRate",
];
const commonAlignment = [
  "hand.Name=='RightHand' and 'R15RightHand'",
  "hand.Name=='Right Arm' and 'R6DistalWrist'",
  "alignment==expectedAlignment",
  "WristAttachmentBounded",
  "FaceOcclusionSafe",
  "WithinVisualPartBudget",
  "WholeHandHidden",
  "HandTransparencyPreserved",
  "hand.Transparency<1",
  "parts>=10",
  "parts<=28",
  "welds>=parts",
  "anchored==0",
  "collidable==0",
  "maxDistance<3.6",
  "ratio>=1.1",
  "ratio<=2.2",
  "math.abs(localCenter.X)<.4",
  "forward>.02",
];
const commonSanitization = [
  "LuaSourceContainer",
  "Tool",
  "RemoteEvent",
  "RemoteFunction",
  "BindableEvent",
  "BindableFunction",
  "ClickDetector",
  "ProximityPrompt",
  "Sound",
  "AnimationController",
  "Animator",
  "Humanoid",
  "BodyMover",
  "JointInstance",
  "Constraint",
  "behaviorUnsafe==0",
];
const forbiddenExecutables = [
  "Instance.new('BindableFunction')",
  'Instance.new("BindableFunction")',
  "Instance.new('ModuleScript')",
  'Instance.new("ModuleScript")',
  "Instance.new('RemoteEvent')",
  'Instance.new("RemoteEvent")',
  "Instance.new('RemoteFunction')",
  'Instance.new("RemoteFunction")',
  "loadstring(",
  "getfenv(",
  "setfenv(",
];
const alignmentSpecs = [
  "{name='Boxing Glove',tier=2,style='Boxing',pattern='BoxingWrap'}",
  "{name='Iron Knuckle',tier=3,style='Iron',pattern='RivetedIron'}",
  "{name='Thunder Fist',tier=4,style='Thunder',pattern='ThunderRails'}",
  "{name='Titan Gauntlet',tier=5,style='Titan',pattern='SiegePlates'}",
];
const creatorStoreSpecs = [
  "{name='Starter Glove',tier=1,style='Starter',pattern='PaddedStarter'}",
  "{name='Boxing Glove',tier=2,style='Boxing',pattern='BoxingWrap'}",
  "{name='Iron Knuckle',tier=3,style='Iron',pattern='RivetedIron'}",
  "{name='Thunder Fist',tier=4,style='Thunder',pattern='ThunderRails'}",
  "{name='Titan Gauntlet',tier=5,style='Titan',pattern='SiegePlates'}",
  "{name='Crimson Vanguard Fist',tier=6,style='Vanguard',pattern='VanguardShield'}",
  "{name='Stormbreaker Fist',tier=7,style='Storm',pattern='StormBlades'}",
  "{name='Celestial Titan Fist',tier=8,style='Celestial',pattern='CelestialCrown'}",
];

check(
  "flow_identity_and_terminal_cleanup",
  alignment.name === "fist-arm-alignment-qc"
    && alignment.studioName === "^(?:PunchWallRPGPlayable_v1_final|PunchWallRPG_ManualPlaytest_20260818_FistAuraV10)\\.rbxlx$"
    && creatorStore.name === "creator-store-fist-visuals"
    && creatorStore.studioName === "^(?:PunchWallRPGPlayable_v1_final|PunchWallRPG_ManualPlaytest_20260818_FistAuraV10)\\.rbxlx$"
    && terminalContract(alignment)
    && terminalContract(creatorStore),
  "Both Batch-B flows must retain exact Studio routing, clean-console gates, terminal stop, and recoverable cleanup stop.",
);

check(
  "cross_vm_executable_state_is_forbidden",
  !allCode.includes("shared.PunchWallVerifyHeroGauntlet")
    && !allCode.includes("shared.PunchWallVerifyFist")
    && !allCode.includes("shared.")
    && forbiddenExecutables.every((token) => !allCode.includes(token)),
  "Flow executables must be self-contained and must not persist verifier functions through shared or executable Instances.",
);

check(
  "alignment_catalog_seed_is_authoritative_and_diagnostic",
  includesAll(alignmentServer, [
    "c:Invoke('Reset')",
    "c:Invoke('SetStats'",
    "'Boxing Glove','Iron Knuckle','Thunder Fist','Titan Gauntlet'",
    "c:Invoke('BuyFist',name)",
    "assert(result.ok==true",
    "p:SetAttribute('LastMobileAction',0)",
    "OwnedFistsJSON",
    "allOwned",
    "p.RPGStats.EquippedFist.Value=='Titan Gauntlet'",
    "H:JSONEncode(result)",
  ]),
  "The four-tier alignment flow must seed and prove owned authority before real client equips.",
);

check(
  "creator_store_catalog_seed_is_authoritative_and_diagnostic",
  includesAll(creatorStoreServer, [
    "c:Invoke('Reset')",
    "c:Invoke('SetStats'",
    "'Boxing Glove','Iron Knuckle','Thunder Fist','Titan Gauntlet'",
    "'Crimson Vanguard Fist','Stormbreaker Fist','Celestial Titan Fist'",
    "c:Invoke('BuyFist',name)",
    "c:Invoke('GrantPremiumFist',name)",
    "OwnedFistsJSON",
    "OwnedPremiumFistsJSON",
    "regularOwned",
    "premiumOwned",
    "p.RPGStats.EquippedFist.Value=='Celestial Titan Fist'",
    "assert(result.valid",
    "H:JSONEncode(result)",
  ]),
  "The eight-tier flow must prove standard and premium ownership separately and emit JSON failure diagnostics.",
);

check(
  "alignment_matrix_is_self_contained_exact_and_bounded",
  alignmentMatrix.args?.datamodel_type === "Client"
    && includesAll(alignmentMatrixCode, alignmentSpecs)
    && countLiteral(alignmentMatrixCode, "{name='") === alignmentSpecs.length
    && includesAll(alignmentMatrixCode, [
      "local function verify(spec)",
      "local deadline=os.clock()+4",
      "until os.clock()>=deadline",
      "for index,spec in ipairs(specs)",
      "actionRemote:FireServer({action='EquipFist',target=spec.name})",
      "assert(valid,'HeroGauntlet alignment contract failed: '..H:JSONEncode(result))",
      "count=#results",
    ])
    && countLiteral(
      alignmentMatrixCode,
      "actionRemote:FireServer({action='EquipFist',target=spec.name})",
    ) === 1
    && alignmentMatrix.expectRegex?.includes('"count"\\s*:\\s*4'),
  "The alignment matrix must contain exactly four tiers, one intended equip dispatch site, bounded observation, and assertion diagnostics.",
);

check(
  "creator_store_matrix_is_self_contained_exact_and_bounded",
  creatorStoreMatrix.args?.datamodel_type === "Client"
    && includesAll(creatorStoreMatrixCode, creatorStoreSpecs)
    && countLiteral(creatorStoreMatrixCode, "{name='") === creatorStoreSpecs.length
    && includesAll(creatorStoreMatrixCode, [
      "local function verify(spec)",
      "local deadline=os.clock()+4",
      "until os.clock()>=deadline",
      "for index,spec in ipairs(specs)",
      "actionRemote:FireServer({action='EquipFist',target=spec.name})",
      "assert(valid,'HeroGauntlet tier contract failed: '..H:JSONEncode(result))",
      "count=#results",
    ])
    && countLiteral(
      creatorStoreMatrixCode,
      "actionRemote:FireServer({action='EquipFist',target=spec.name})",
    ) === 1
    && creatorStoreMatrix.expectRegex?.includes('"count"\\s*:\\s*8'),
  "The Creator Store matrix must contain exactly eight tiers, one intended equip dispatch site, bounded observation, and assertion diagnostics.",
);

check(
  "all_runtime_verifiers_cover_identity_anatomy_and_visibility",
  [alignmentMatrixCode, creatorStoreMatrixCode, postRespawnCode].every(
    (code) =>
      includesAll(code, commonIdentity)
      && includesAll(code, commonAnatomy)
      && includesAll(code, commonAlignment),
  ),
  "Every runtime verifier must prove exact tier identity, complete fist anatomy, current-rig wrist alignment, geometry bounds, and preserved avatar-hand visibility.",
);

check(
  "all_runtime_verifiers_reject_behavior_and_collision_hazards",
  [alignmentMatrixCode, creatorStoreMatrixCode, postRespawnCode].every(
    (code) =>
      includesAll(code, commonSanitization)
      && code.includes("descendant:IsA('WeldConstraint')")
      && code.indexOf("descendant:IsA('WeldConstraint')")
        < code.indexOf("descendant:IsA('Constraint')")
      && code.includes("descendant.CanCollide or descendant.CanTouch or descendant.CanQuery"),
  ),
  "Every runtime verifier must count welded geometry separately and reject scripting, interaction, audio, controller, joint, constraint, and collision/query hazards.",
);

check(
  "creator_store_static_shop_chrome_coverage_is_preserved",
  shopChrome.args?.datamodel_type === "Client"
    && includesAll(shopChromeCode, [
      "OpenTab','Fists'",
      "Boxing GloveShopCard",
      "Iron KnuckleShopCard",
      "Thunder FistShopCard",
      "ProductArt",
      "ProductArtFallback",
      "HeroGauntletTierChrome",
      "HeroGauntletV2StaticChrome",
      "StaticPreviewRenderLoop",
      "StaticPreviewChromeOnly",
      "PerimeterOnlyV1",
      "LoadedArtUnobscured",
      "StaticTierOutline",
      "StaticTierRail",
      "StaticTierPip",
      "HeroGauntletV2StaticSilhouette",
      "a:Invoke('CloseMenus')",
    ])
    && [
      '"boxing"\\s*:\\s*true',
      '"iron"\\s*:\\s*true',
      '"thunder"\\s*:\\s*true',
      '"distinct"\\s*:\\s*true',
    ].every((pattern) => shopChrome.expectRegex?.includes(pattern)),
  "Creator Store coverage must keep distinct unobscured loaded art and perimeter-only static chrome for tiers two through four.",
);

check(
  "post_respawn_punch_verifier_is_self_contained_and_full_strength",
  postRespawn.args?.datamodel_type === "Client"
    && includesAll(postRespawnCode, [
      "local punch=automation:Invoke('Punch')",
      "task.wait(.8)",
      "{name='Celestial Titan Fist',tier=8,style='Celestial',pattern='CelestialCrown'}",
      "local function verify(expected)",
      "local deadline=os.clock()+4",
      "local result=verify(spec)",
      "punch=punch==true",
      "assert(diagnostics.valid,'post-respawn punch gauntlet contract failed: '..H:JSONEncode(diagnostics))",
    ])
    && !postRespawnCode.includes("FireServer")
    && !postRespawnCode.includes("shared.")
    && [
      '"valid"\\s*:\\s*true',
      '"punch"\\s*:\\s*true',
      '"tier"\\s*:\\s*8',
      '"unsafe"\\s*:\\s*0',
      '"handVisible"\\s*:\\s*true',
      '"complete"\\s*:\\s*true',
    ].every((pattern) => postRespawn.expectRegex?.includes(pattern)),
  "Respawn/punch validation must reacquire and fully inspect Celestial locally without dispatch retries or cross-VM state.",
);

check(
  "real_equip_dispatches_are_not_retried",
  countLiteral(
    alignmentCode,
    "actionRemote:FireServer({action='EquipFist',target=spec.name})",
  ) === 1
    && countLiteral(
      creatorStoreCode,
      "actionRemote:FireServer({action='EquipFist',target=spec.name})",
    ) === 1
    && countLiteral(alignmentCode, "FireServer(") === 1
    && countLiteral(creatorStoreCode, "FireServer(") === 1,
  "Each matrix may dispatch one intentional equip per tier through one loop site, with no hidden retry dispatch.",
);

const passed = Object.values(checks).filter(Boolean).length;
const total = Object.keys(checks).length;
const ok = passed === total;
console.log(
  JSON.stringify(
    {
      ok,
      passed,
      total,
      fistTiers: alignmentSpecs.length,
      creatorStoreTiers: creatorStoreSpecs.length,
      checks,
      failures,
      files: [
        path.relative(repositoryRoot, alignmentPath),
        path.relative(repositoryRoot, creatorStorePath),
      ],
    },
    null,
    2,
  ),
);
if (!ok) process.exitCode = 1;
