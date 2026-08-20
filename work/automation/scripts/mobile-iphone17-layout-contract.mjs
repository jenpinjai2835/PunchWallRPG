import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";

const root = path.resolve(import.meta.dirname, "..", "..");
const read = (...parts) => fs.readFileSync(path.join(root, ...parts), "utf8");
const client = read("punch-wall-rpg", "src", "client", "PunchWallClient.client.lua");
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
  ["phone_information_has_aligned_four_stat_row", client.includes('"PhoneLandscapeStatRowHonorAlignedV5"') && client.includes('"FourStatsAlignedNoDowntownV5"') && client.includes("UDim2.fromOffset(math.min(220, viewport.X * 0.27), 30)")],
  ["downtown_card_is_disabled_until_feature_release", client.includes('NextWorldCard.Visible = false') && client.includes('NextWorldCard:SetAttribute("DisabledReason", "DowntownNotReleased")')],
  ["settings_is_the_top_right_utility", client.includes('shared.PunchWallSettingsToolButton,\n\t\t\tshared.PunchWallSoundToolButton,\n\t\t\tshared.PunchWallMoreToolButton')],
  ["settings_window_uses_the_gear_asset", client.includes('"SettingsWindow",\n\t"SETTINGS",\n\tColor3.fromRGB(46, 205, 255),\n\t"SettingsTool"')],
  ["inventory_uses_dense_mobile_cards_and_single_lock_state", inventory.includes('"PhoneDenseBalancedV5"') && inventory.includes('useCompact and 60 or 92') && inventory.includes('"InventoryCardMaximumCompactHeight", useCompact and 94 or 0') && inventory.includes('"InventoryLockedLabelCount"')],
  ["shop_uses_dense_half_scale_mobile_catalog", client.includes('"MobileCatalogDenseV3"') && client.includes('"ShopCompactCardHeight"') && client.includes('"ShopCompactTextScale"') && client.includes('compactCards and 0.5 or 1')],
  ["coin_boost_is_not_in_coin_shop", !client.includes('key = "CoinBoost",\n\t\t\tname = "COIN BOOST"') && flowText.includes("MobileCatalogDenseV3")],
  ["phone_context_lane_is_clear", client.includes('"PhoneCenterLane48V3"') && client.includes("PunchWallContextActionButton.Size = UDim2.fromOffset(180, 48)")],
  ["compact_modals_share_safe_margin", client.includes('"PhoneSafeMargin12V3"') && client.includes('SetAttribute("CompactModalSafeMargin", 12)')],
  ["settings_options_render_above_row_chrome", client.includes("button.ZIndex = optionArea.ZIndex + 1")],
  ["spin_is_isolated_and_safe", client.includes("local edgeMargin = compact and 32 or 18") && client.includes("referenceHUD.Visible = false") && client.includes('close:SetAttribute("MinimumEffectiveTouchTarget", 44)')],
  ["runtime_diagnostics_fail_closed", ["PhonePrimaryTargetsPass", "PhonePrimaryBoundsPass", "PhonePrimaryPairwisePass", "PhoneControlCoveragePass", "PhonePunchMaximumPass", "PhoneJoystickMaximumPass"].every((token) => client.includes(token))],
  ["flow_uses_exact_studio", flow.studioInstanceId === "03d68549-ed19-438d-bb8c-922b03f9d7b1" && flow.studioName === "^SmashWall_v1[.]0[.]1[.]rbxlx$" && flow.placeName === flow.studioName],
  ["flow_covers_every_surface", ["premium pet equipped notice stays compact", "Inventory All uses bounded phone drawer", "Inventory Pets and Honor retain compact detail behavior", "all five Shop pages fit iPhone 17", "Missions surface is safe", "Rebirth compact header and action fit", "Settings rows stay contained", "Hero Spin is isolated and touch safe"].every((label) => labels.has(label))],
  ["flow_checks_hud_hierarchy", labels.has("iPhone HUD is bounded sparse and touch safe") && labels.has("top information hierarchy is clear") && flowText.includes("PhoneLandscapeV5") && flowText.includes("FourStatsAlignedNoDowntownV5")],
  ["flow_has_clean_lifecycle", labels.has("runtime console clean") && labels.has("post-stop console clean") && labels.has("restore simulator default")],
  ["flow_does_not_claim_real_input_or_screenshots", !flowText.includes("user_mouse_input") && !flowText.includes("screen_capture")],
];

for (const [name, passed] of checks) assert.equal(passed, true, name);
console.log(JSON.stringify({ ok: true, passed: checks.length, total: checks.length, checks: Object.fromEntries(checks) }, null, 2));
