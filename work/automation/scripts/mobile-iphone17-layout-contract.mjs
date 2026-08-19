import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";

const root = path.resolve(import.meta.dirname, "..", "..");
const read = (...parts) => fs.readFileSync(path.join(root, ...parts), "utf8");
const client = read("punch-wall-rpg", "src", "client", "PunchWallClient.client.lua");
const flowText = read("automation", "flows", "mobile-iphone17-layout.json");
const flow = JSON.parse(flowText);
const labels = new Set(flow.steps.map((step) => step.label));

const checks = [
  ["responsive_profiles_are_dimension_driven", client.includes('return "PhoneLandscape", true') && client.includes('return "TabletTouch", true') && client.includes('return "Desktop", false')],
  ["iphone_reference_is_exact", flowText.includes("Width=874,Height=402,PixelDensity=460") && flowText.includes("DeviceForm=Enum.DeviceForm.Phone")],
  ["active_punch_is_compact", client.includes('referencePunch:SetAttribute("ResponsiveProfile", "PhoneLandscapePunchV3")') && client.includes('referencePunch:SetAttribute("MaximumCompactSize", 92)')],
  ["active_joystick_is_compact", client.includes('referenceJoystick:SetAttribute("ResponsiveProfile", "PhoneLandscapeJoystickV3")') && client.includes("local joystickSize = math.max(96")],
  ["active_jump_and_directions_are_compact", client.includes('referenceJump:SetAttribute("ResponsiveProfile", "PhoneLandscapeJumpV3")') && client.includes('"PhoneLandscapeDirectionPair44V3"')],
  ["phone_menu_is_sparse", client.includes('"PhoneLandscape2x2SafeV3"') && client.includes("referenceQuests.Visible = false") && client.includes('"CompactQuestsRoutedThroughMissions"')],
  ["phone_information_is_reduced", client.includes("rankWidgets.Root.Visible = false") && client.includes("PunchWallHUDWidgets.QuestCard.Visible = false") && client.includes('"EssentialProgressV3"')],
  ["phone_context_lane_is_clear", client.includes('"PhoneCenterLane48V3"') && client.includes("PunchWallContextActionButton.Size = UDim2.fromOffset(180, 48)")],
  ["compact_modals_share_safe_margin", client.includes('"PhoneSafeMargin12V3"') && client.includes('SetAttribute("CompactModalSafeMargin", 12)')],
  ["settings_options_render_above_row_chrome", client.includes("button.ZIndex = optionArea.ZIndex + 1")],
  ["spin_is_isolated_and_safe", client.includes("local edgeMargin = compact and 32 or 18") && client.includes("referenceHUD.Visible = false") && client.includes('close:SetAttribute("MinimumEffectiveTouchTarget", 44)')],
  ["runtime_diagnostics_fail_closed", ["PhonePrimaryTargetsPass", "PhonePrimaryBoundsPass", "PhonePrimaryPairwisePass", "PhoneControlCoveragePass", "PhonePunchMaximumPass", "PhoneJoystickMaximumPass"].every((token) => client.includes(token))],
  ["flow_uses_exact_studio", flow.studioInstanceId === "03d68549-ed19-438d-bb8c-922b03f9d7b1" && flow.studioName === "^SmashWall_v1[.]0[.]1[.]rbxlx$" && flow.placeName === flow.studioName],
  ["flow_covers_every_surface", ["Inventory All uses bounded phone drawer", "Inventory Pets and Honor retain compact detail behavior", "all five Shop pages fit iPhone 17", "Missions surface is safe", "Rebirth compact header and action fit", "Settings rows stay contained", "Hero Spin is isolated and touch safe"].every((label) => labels.has(label))],
  ["flow_checks_hud_hierarchy", labels.has("iPhone HUD is bounded sparse and touch safe") && labels.has("top information hierarchy is clear") && flowText.includes("PhoneLandscapeV3")],
  ["flow_has_clean_lifecycle", labels.has("runtime console clean") && labels.has("post-stop console clean") && labels.has("restore simulator default")],
  ["flow_does_not_claim_real_input_or_screenshots", !flowText.includes("user_mouse_input") && !flowText.includes("screen_capture")],
];

for (const [name, passed] of checks) assert.equal(passed, true, name);
console.log(JSON.stringify({ ok: true, passed: checks.length, total: checks.length, checks: Object.fromEntries(checks) }, null, 2));
