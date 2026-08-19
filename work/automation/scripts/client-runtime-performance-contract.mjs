#!/usr/bin/env node
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const repositoryRoot = path.resolve(scriptDirectory, "../../..");
const clientPath = path.join(
  repositoryRoot,
  "work",
  "punch-wall-rpg",
  "src",
  "client",
  "PunchWallClient.client.lua",
);
const fistVisualBuilderPath = path.join(
  repositoryRoot,
  "work",
  "punch-wall-rpg",
  "src",
  "shared",
  "FistVisualBuilder.lua",
);
const client = fs.readFileSync(clientPath, "utf8").replace(/\r\n?/g, "\n");
const fistVisualBuilder = fs
  .readFileSync(fistVisualBuilderPath, "utf8")
  .replace(/\r\n?/g, "\n");
const checks = {};

function check(name, condition, detail) {
  checks[name] = condition === true;
  assert.equal(condition, true, `${name}: ${detail}`);
}

function block(source, start, end) {
  const startIndex = source.indexOf(start);
  assert.notEqual(startIndex, -1, `Missing start sentinel: ${start}`);
  const endIndex = source.indexOf(end, startIndex + start.length);
  assert.notEqual(endIndex, -1, `Missing end sentinel: ${end}`);
  return source.slice(startIndex, endIndex);
}

const ambientRegistry = block(
  client,
  "local clientRuntime = {",
  "local ambientPhase = 0",
);
check(
  "ambient_periodic_full_scan_removed",
  !ambientRegistry.includes("while gui.Parent")
    && !ambientRegistry.includes("task.wait(2)")
    && (ambientRegistry.match(/root:GetDescendants\(\)/g) || []).length === 1,
  "Ambient discovery may scan only once per bound root, never on a periodic loop.",
);
check(
  "runtime_state_uses_bounded_local_scopes",
  client.includes("do\nlocal clientRuntime = {")
    && client.includes(
      'end)\nend\n\ngui:SetAttribute("CombatCameraActive", false)',
    )
    && ambientRegistry.includes("function clientRuntime.RegisterAmbientPulsePart")
    && !ambientRegistry.includes("local function registerAmbientPulsePart"),
  "Ambient and target runtime state must consume one scoped namespace and release it after callbacks bind.",
);
check(
  "ambient_registry_tracks_hierarchy_events",
  ambientRegistry.includes("root.DescendantAdded:Connect")
    && ambientRegistry.includes("root.DescendantRemoving:Connect")
    && ambientRegistry.includes("workspace.ChildAdded:Connect")
    && ambientRegistry.includes("workspace.ChildRemoved:Connect"),
  "Late descendants and a late or replaced PunchWallRPG root must update the registry.",
);
check(
  "ambient_deferred_attribute_capture_is_bounded",
  ambientRegistry.includes("task.defer(function()")
    && ambientRegistry.includes("clientRuntime.RegisterAmbientPulsePart(descendant)")
    && !ambientRegistry.includes('GetAttributeChangedSignal("AmbientMotion")'),
  "Server construction order is handled without one persistent connection per part.",
);
check(
  "ambient_registry_preserves_order_without_extra_visual_writes",
  ambientRegistry.includes("table.insert(clientRuntime.AmbientPulseParts, candidate)")
    && ambientRegistry.includes("table.remove(clientRuntime.AmbientPulseParts, index)")
    && !ambientRegistry.includes("candidate.Transparency ="),
  "The pulse phase order remains deterministic and registry maintenance must not mutate visuals.",
);
check(
  "ambient_registry_is_observable",
  ambientRegistry.includes('gui:SetAttribute("AmbientPulseRegistryMode", "EventDrivenV1")')
    && ambientRegistry.includes('gui:SetAttribute("AmbientPulseInitialScanCount"')
    && ambientRegistry.includes('gui:SetAttribute("AmbientPulseAddedCount"')
    && ambientRegistry.includes('gui:SetAttribute("AmbientPulseRemovedCount"'),
  "Root scans and incremental registry updates require observable counters.",
);

const targetHeartbeat = block(
  client,
  "local targetTimer = 0",
  'gui:SetAttribute("CombatCameraActive", false)',
);
check(
  "target_responsiveness_is_unchanged",
  targetHeartbeat.includes("if targetTimer < 0.15 then return end"),
  "The target refresh cadence must remain exactly 0.15 seconds.",
);
check(
  "target_overlap_params_are_stable",
  ambientRegistry.includes("TargetDepthOverlap = OverlapParams.new()")
    && ambientRegistry.includes("clientRuntime.TargetDepthOverlap.MaxParts = 400")
    && !targetHeartbeat.includes("OverlapParams.new()")
    && targetHeartbeat.includes(
      "workspace:GetPartBoundsInRadius(rootPart.Position, 38, clientRuntime.TargetDepthOverlap)",
    ),
  "The Heartbeat path must reuse one equivalent OverlapParams instance.",
);
check(
  "target_folders_are_event_driven",
  ambientRegistry.includes("function clientRuntime.RefreshTargetFolderCache()")
    && ambientRegistry.includes("root.ChildAdded:Connect")
    && ambientRegistry.includes("root.ChildRemoved:Connect")
    && targetHeartbeat.includes("clientRuntime.WallsFolder")
    && targetHeartbeat.includes("clientRuntime.InteractablesFolder")
    && targetHeartbeat.includes("clientRuntime.DepthBlocksFolder"),
  "Stable root folders must be cached and invalidated by direct hierarchy changes.",
);
check(
  "target_cache_is_observable",
  ambientRegistry.includes(
    'gui:SetAttribute("TargetHeartbeatCacheMode", "EventDrivenFoldersV1")',
  )
    && ambientRegistry.includes('gui:SetAttribute("TargetOverlapParamsCreateCount", 1)')
    && ambientRegistry.includes('gui:SetAttribute("TargetFolderCacheRefreshCount"')
    && targetHeartbeat.includes('gui:SetAttribute("TargetCacheMissCount"'),
  "The cache strategy, construction count, refreshes, and safety misses need attributes.",
);

const shop = block(
  client,
  "local shopRuntime = {",
  "\tshared.PunchWallHeroShopRefresh()\n\treturn shopReference",
);
const signatureGuard = shop.indexOf(
  "if not force and signature == shopRuntime.LastSignature then",
);
const skipReturn = shop.indexOf("return false", signatureGuard);
const destroyChildren = shop.indexOf("child:Destroy()");
check(
  "shop_signature_precedes_rebuild",
  signatureGuard >= 0 && skipReturn > signatureGuard && destroyChildren > skipReturn,
  "An unchanged relevant signature must return before any shop UI is destroyed.",
);
check(
  "shop_signature_covers_state_and_layout",
  shop.includes('"HeroShopStateV1"')
    && shop.includes("shopRuntime.CanonicalOwnedList(latestStats.OwnedFistsJSON")
    && shop.includes("shopRuntime.CanonicalOwnedList(latestStats.OwnedPremiumPetsJSON")
    && shop.includes("shopRuntime.CanonicalOwnedList(latestStats.EquippedPetsJSON")
    && shop.includes("latestStats.EquippedFist")
    && shop.includes("shopRuntime.BoostSecond(boostInfo.CoinEndsAt, now)")
    && shop.includes("shopRuntime.BoostSecond(boostInfo.SpeedEndsAt, now)")
    && shop.includes("shopRuntime.BoostSecond(boostInfo.DamageEndsAt, now)")
    && shop.includes("viewport.X")
    && shop.includes("viewport.Y")
    && shop.includes("UserInputService.TouchEnabled")
    && shop.includes("clientSettings.uiScale"),
  "Owned/equipped/page/countdown and every layout input must invalidate correctly.",
);
check(
  "shop_signature_is_deterministic",
  shop.includes("table.sort(normalized)")
    && shop.includes("HttpService:JSONEncode(fields)")
    && shop.includes("shopRuntime.ResolvePage()"),
  "Owned list ordering and invalid page values must not create unstable signatures.",
);
check(
  "shop_force_and_invalidation_are_explicit",
  shop.includes("options.force == true")
    && shop.includes("shared.PunchWallInvalidateHeroShop = function")
    && shop.includes("shopRuntime.LastSignature = nil")
    && shop.includes('shopReference:SetAttribute("LastInvalidationReason"'),
  "Callers need both force-refresh and durable invalidation semantics.",
);
check(
  "shop_boost_countdown_self_refreshes",
  shop.includes("function shopRuntime.ScheduleBoostTick(page, now)")
    && shop.includes("shopRuntime.BoostTickScheduled")
    && shop.includes("task.delay(nextDelay")
    && shop.includes('shopReference:SetAttribute("BoostTickCount"'),
  "A visible Boosts page must advance at its next displayed-second boundary.",
);
check(
  "shop_refresh_is_observable",
  shop.includes('shopReference:SetAttribute("RefreshRequestCount"')
    && shop.includes('shopReference:SetAttribute("RefreshBuildCount"')
    && shop.includes('shopReference:SetAttribute("RefreshSkipCount"')
    && shop.includes('shopReference:SetAttribute("RefreshForceCount"')
    && shop.includes(
      'shopReference:SetAttribute("RefreshMode", "RelevantStateSignatureV1")',
    ),
  "Requests, rebuilds, skips, forces, and mode need runtime evidence.",
);
check(
  "shop_runtime_state_uses_table_namespace",
  shop.includes("local shopRuntime = {")
    && shop.includes("function shopRuntime.StateSignature(now)")
    && !shop.includes("local shopLastSignature")
    && !shop.includes("local shopRefreshRequestCount")
    && !shop.includes("local function shopStateSignature"),
  "Shop cache state and helper closures must consume one enclosing local, not a register per field.",
);
check(
  "viewport_path_rechecks_shop_signature",
  client.includes(
    "if shopOpen and shared.PunchWallHeroShopRefresh then\n\t\tshared.PunchWallHeroShopRefresh()",
  ),
  "Responsive layout changes must re-evaluate the viewport-dependent signature.",
);
check(
  "stats_path_preserves_visible_shop_refresh",
  client.includes(
    "if shared.PunchWallHeroShopRefresh and shared.PunchWallShopReference.Visible then\n\t\tshared.PunchWallHeroShopRefresh()",
  ),
  "StatsChanged must still request a refresh; the signature decides whether work is needed.",
);

check(
  "studio_harness_uses_isolated_register_frame",
  client.includes(
    '\t(function()\n\tlocal automation = gui:FindFirstChild("PunchWallClientAutomation")',
  )
    && client.includes("\tend)()\nend\n\nplayer.CharacterAdded:Connect"),
  "Studio automation must live in a separate closure so production/client locals compile at every optimization level.",
);
check(
  "visual_sanitizer_is_strict_fail_closed",
  fistVisualBuilder.includes('local SANITIZER_VERSION = "StrictVisualAllowlistV1"')
    && fistVisualBuilder.includes("local ALLOWED_VISUAL_CLASSES = {")
    && fistVisualBuilder.includes("if isAllowedVisual(child) then")
    && fistVisualBuilder.includes("child:Destroy()")
    && fistVisualBuilder.includes("FistVisualBuilder.AssertSanitizedVisual(root)")
    && !fistVisualBuilder.includes("removeUnsafeDescendants"),
  "Imported visuals must use an allowlist, remove every other descendant, and assert the sanitized result.",
);
check(
  "visual_attestation_is_exact_before_clone",
  client.includes("companionRuntime.PrepareVisualAsset(visualAssetFolder, importedSource)")
    && client.includes("companionRuntime.CloneSanitizedVisual(importedSource)")
    && client.includes('container:GetAttribute("SanitizedVisualOnly") == true')
    && client.includes('asset:GetAttribute("VisualSanitizerVerified") == true')
    && !client.includes('visualAssetFolder:GetAttribute("SanitizedVisualOnly") ~= false'),
  "Every imported source/container and runtime clone requires verified true attestation; nil must fail closed.",
);
check(
  "pet_slot_three_is_rear_and_off_center",
  client.includes("local thirdSlotMultiplier = isPremium and (1.12 + zoomAlpha * 0.1) or 1.65")
    && client.includes("local thirdSlotRear = isPremium and 0.5 or 1.25")
    && client.includes("-sideSpacing * thirdSlotMultiplier")
    && client.includes("rearSpacing + thirdSlotRear / boundedDistanceScale")
    && !client.includes(
      "offset = Vector3.new(0, followHeight or 1.05, -2.1 - zoomAlpha * 0.35)",
    ),
  "The third companion must remain behind the avatar and outside the centerline.",
);
check(
  "pet_screen_budget_is_enforced",
  client.includes("function companionRuntime.ResolveVisualPolicy")
    && client.includes('"Repositioned"')
    && client.includes('"BudgetLOD"')
    && client.includes('"CulledAfterBudgetLOD"')
    && client.includes('model:SetAttribute("BudgetEnforcementOrder", "Reposition>Scale>LOD>Cull")')
    && client.includes("actualScreenArea > effectiveBudget + 0.0005"),
  "Screen-area limits must drive bounded reposition, scale, LOD, and final culling rather than telemetry only.",
);
check(
  "reduced_motion_suppresses_high_motion_feedback",
  client.includes('gui:SetAttribute("ReducedMotionDebrisSuppressed", true)')
    && client.includes('gui:SetAttribute("ReducedMotionCoinTravelSuppressed", true)')
    && client.includes('gui:SetAttribute("ReducedMotionTrailSuppressed", true)')
    && client.includes('gui:SetAttribute("PunchMotionPhase", "StaticFeedback")')
    && client.includes("if not clientSettings.motion then\n\t\tif updatePunchMotion then updatePunchMotion() end"),
  "Reduced motion must suppress debris, coin travel, trails, and joint animation while retaining semantic feedback.",
);
check(
  "punch_motion_has_one_deterministic_update_owner",
  (client.match(/RunService\.PreSimulation:Connect\(updatePunchMotion\)/g) || []).length === 1
    && !client.includes("RunService.Heartbeat:Connect(updatePunchMotion)")
    && !client.includes("while punchMotionState == startedState"),
  "The punch state may be advanced only from PreSimulation, never a per-punch loop plus Heartbeat.",
);

const passed = Object.values(checks).filter(Boolean).length;
console.log(
  JSON.stringify(
    {
      ok: passed === Object.keys(checks).length,
      passed,
      total: Object.keys(checks).length,
      checks,
      files: [
        path.relative(repositoryRoot, clientPath),
        path.relative(repositoryRoot, fistVisualBuilderPath),
      ],
    },
    null,
    2,
  ),
);
