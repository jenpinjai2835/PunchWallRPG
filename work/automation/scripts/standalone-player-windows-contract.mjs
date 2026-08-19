import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";

const root = path.resolve(import.meta.dirname, "..", "..");
const read = (...parts) => fs.readFileSync(path.join(root, ...parts), "utf8");
const client = read("punch-wall-rpg", "src", "client", "PunchWallClient.client.lua");
const server = read("punch-wall-rpg", "src", "server", "PunchWallBootstrap.server.lua");
const flowText = read("automation", "flows", "standalone-player-windows.json");
const flow = JSON.parse(flowText);
const hasLabel = (label) => flow.steps.some((step) => step.label === label);

const checks = [
  ["legacy_five_tab_navigation_is_hidden", client.includes('tabBar:SetAttribute("LegacyCombinedNavigationRemoved", true)') && client.includes("tabBar.Visible = false") && client.includes('mainPanel:SetAttribute("LegacyCombinedMenuRemoved", true)')],
  ["neutral_host_preserves_shop_and_inventory", client.includes('mainPanel:SetAttribute("SurfaceRole", "NeutralModalHost")') && client.includes("Parent = mainPanel") && client.includes("FunctionalHeroShop")],
  ["rebirth_is_standalone", client.includes('"RebirthWindow"') && client.includes('standaloneWindows.RebirthPanel = rebirthPanel') && client.includes('shared.PunchWallOpenRebirthPanel') && client.includes('shared.PunchWallStandaloneWindows.Open("Rebirth"')],
  ["rebirth_uses_icon_led_real_requirements", client.includes('"WallLevelRequirement"') && client.includes('"CoinsRequirement"') && client.includes('latestStats.RebirthRequiredLevel') && client.includes('latestStats.RebirthRequiredCoins') && client.includes('createThemeIcon(levelCard, "Wall"') && client.includes('createThemeIcon(coinCard, "Coin"')],
  ["rebirth_copy_is_compact_and_truthful", client.includes('POWER 25 • COINS 0 • WALL LV 1') && client.includes('STARTER FIST • TRAINING STOPS') && client.includes('READY • REVIEW BEFORE RESET') && client.includes('DEPTH • GEAR • PETS • HONOR • BOOSTS') && client.includes('"REVIEW REBIRTH"') && client.includes('"REBIRTH NOW"')],
  ["rebirth_safe_confirmation", client.includes("expectedRebirths = q.currentRebirths") && client.includes("policyVersion = q.policyVersion") && client.includes("Safe default: gamepad/keyboard lands on Cancel") && client.includes("focusButton = cancel")],
  ["server_routes_to_standalone_rebirth", server.includes('surface = "Rebirth"') && server.includes('tab = "Rebirth"') && server.includes('selected = "Rebirth"')],
  ["settings_is_standalone", client.includes('"SettingsWindow"') && client.includes('shared.PunchWallOpenSettingsPanel') && client.includes('openStandaloneWindow("Settings"')],
  ["settings_has_exact_player_controls", client.includes('"SOUNDSetting"') && client.includes('"MOTIONSetting"') && client.includes('"UI SIZESetting"') && client.includes('makeSettingRow(1, "SoundTool"') && client.includes('makeSettingRow(2, "Punch"') && client.includes('GameConfig.HeroCityPixelUI[iconName]') && client.includes('"StandaloneAsset"') && client.includes('label = "80%"') && client.includes('label = "100%"') && client.includes('label = "120%"')],
  ["settings_remains_server_authoritative", client.includes('action = "UpdateSettings"') && server.includes('action == "UpdateSettings"') && server.includes("uiScale = normalizedUiScale(value.uiScale)")],
  ["windows_are_exclusive", client.includes('mainPanel.Visible = false') && client.includes('rebirthPanel.Visible = windowName == "Rebirth"') && client.includes('settingsPanel.Visible = windowName == "Settings"') && client.includes('gui:SetAttribute("ActiveStandaloneWindow", windowName)')],
  ["compact_touch_layout_is_bounded", client.includes('"StandaloneCompactSafeV1"') && client.includes("viewport.X - 24") && client.includes("viewport.Y - 24") && client.includes("compactHeaderLeft = math.max(90") && client.includes('SetAttribute("MinimumTouchTarget", 44)')],
  ["missions_no_longer_renders_rebirth", client.includes("Rebirth moved to its own child-friendly modal") && client.includes("if false then -- retained temporarily for selector compatibility") && client.includes('PunchWallStandaloneHostTitle.Text = activeTab == "Tasks" and "MISSIONS"')],
  ["generated_assets_are_versioned", ["wall-level.png", "coins.png", "rebirth-core.png", "README.md"].every((name) => fs.existsSync(path.join(root, "assets", "generated", "rebirth-ui-v1", name)))],
  ["runtime_flow_is_strict", flow.studioInstanceId === "6d29b2d4-41ab-41fb-838f-3dfd8727c725" && flow.studioName === "^PunchWallRPG_ManualPlaytest_20260818_FistAuraV10[.]rbxlx$" && hasLabel("Rebirth HUD route opens standalone window") && hasLabel("Settings tool route opens standalone window")],
  ["runtime_flow_checks_exclusivity_and_legacy_removal", hasLabel("standalone Rebirth is exclusive readable and touch safe") && hasLabel("standalone Settings is exclusive readable and touch safe") && hasLabel("Missions surface has no combined tabs or embedded Rebirth") && flowText.includes("g.GameMenu.Tabs.Visible==false") && flowText.includes("rewardClear") && flowText.includes("headerSafe")],
  ["runtime_flow_checks_settings_authority", hasLabel("Settings sound callback applies immediately") && hasLabel("standalone Settings reaches server normalization") && flowText.includes("s.sound==false") && flowText.includes("ThemeIconSource") && flowText.includes("StandaloneAsset")],
  ["runtime_flow_has_clean_lifecycle", hasLabel("standalone windows boot console clean") && hasLabel("standalone windows runtime console clean") && hasLabel("standalone windows post-stop console clean") && hasLabel("restore default simulator and remove standalone windows device")],
];

for (const [name, passed] of checks) assert.equal(passed, true, name);
console.log(JSON.stringify({ ok: true, passed: checks.length, total: checks.length, checks: Object.fromEntries(checks) }, null, 2));
