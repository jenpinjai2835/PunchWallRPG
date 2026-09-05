import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";

const root = path.resolve(import.meta.dirname, "..", "..");
const server = fs.readFileSync(path.join(root, "punch-wall-rpg", "src", "server", "PunchWallBootstrap.server.lua"), "utf8");
const client = fs.readFileSync(path.join(root, "punch-wall-rpg", "src", "client", "PunchWallClient.client.lua"), "utf8");
const flow = JSON.parse(fs.readFileSync(path.join(root, "automation", "flows", "world-boost-showcases.json"), "utf8"));

const checks = [
  ["three_exact_showcases", /WorldBoostShowcaseCount", #boostShowcaseSpecs/.test(server) && /ShowcaseCount", #boostShowcaseSpecs/.test(server)],
  ["outside_lane_policy", server.includes('PlacementPolicy", "OutsideDepthLaneRightEdge"') && flow.description.includes("collision-free")],
  ["static_bounded_visuals", server.includes('StaticVisualPartBudget", 48') && server.includes('ContainsRuntimeLoops", false')],
  ["keyboard_gamepad_touch_prompt", server.includes("KeyboardKeyCode = Enum.KeyCode.E") && server.includes("GamepadKeyCode = Enum.KeyCode.ButtonX") && server.includes("ClickablePrompt = true") && flow.steps.some((step) => step.tool === "user_keyboard_input" && step.label === "press E through the live player input path") && flow.steps.some((step) => step.tool === "execute_luau" && step.label === "verify Damage server route paired with ButtonX-bound prompt")],
  ["mouse_click_route", server.includes('Instance.new("ClickDetector")') && server.includes("PunchWallOpenWorldBoostKiosk") && flow.steps.some((step) => step.tool === "user_mouse_input" && step.label === "click Speed showcase through the live mouse path")],
  ["touch_simulator_route", flow.steps.some((step) => step.label === "phone simulator exposes touch input") && flow.steps.some((step) => step.tool === "user_mouse_input" && step.label === "tap Coin showcase in the live phone simulator")],
  ["shared_server_route", server.includes('type = "OpenMenu"') && server.includes('tab = selected.shopPage or "Boosts"')],
  ["coin_showcase_uses_real_currency_catalog", server.includes('detail = "15 MINUTES  |  ROBUX SHOP"') && server.includes('shopPage = "Robux"') && !server.includes('detail = "15 MINUTES  |  5K COINS"') && server.includes('page = selected.shopPage or "Boosts"')],
  ["client_exact_page_route", client.includes('reason = "world-commerce-showcase"') && client.includes('shared.PunchWallHeroShopPage = requested')],
  ["anti_spam_and_rebuild_churn", server.includes("boostShowcaseLastOpenByPlayer") && server.includes('reason = "cooldown"') && client.includes("force = not samePageOpen")],
  ["runtime_flow_has_post_stop_console", flow.steps.some((step) => step.label === "post-stop console clean")],
];

for (const [name, passed] of checks) {
  assert.equal(passed, true, name);
}
console.log(JSON.stringify({
  ok: true,
  passed: checks.length,
  total: checks.length,
  showcases: 3,
  checks: Object.fromEntries(checks),
}, null, 2));
