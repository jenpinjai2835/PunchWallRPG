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
  "device-matrix-hud-shop.json",
);
const flow = JSON.parse(fs.readFileSync(flowPath, "utf8"));
const clientPath = path.join(
  repositoryRoot,
  "work",
  "punch-wall-rpg",
  "src",
  "client",
  "PunchWallClient.client.lua",
);
const client = fs.readFileSync(clientPath, "utf8");
const checks = {};

function check(name, condition, detail) {
  checks[name] = condition === true;
  assert.equal(condition, true, name + ": " + detail);
}

const shopSteps = flow.steps.filter((step) => step.label?.endsWith("shop fits"));
const phoneTargetSteps = flow.steps.filter((step) =>
  step.label?.includes("all visible HUD targets are touch safe"));
const flowText = JSON.stringify(flow);

check(
  "flow_targets_full_device_matrix",
  flow.name === "device-matrix-hud-shop"
    && flowText.includes("1920x1080")
    && flowText.includes("1366x768")
    && flowText.includes("1024x768")
    && flowText.includes("844x390")
    && flowText.includes("740x360"),
  "The device matrix must retain desktop, tablet, and both supported phone sizes.",
);

check(
  "every_shop_viewport_requires_current_sixteen_cards",
  shopSteps.length === 5
    && shopSteps.every((step) => {
      const source = step.args?.code || "";
      return step.expectRegex?.some((pattern) =>
        pattern.includes("cards") && pattern.endsWith("16"))
        && source.includes("local function shown(d)")
        && source.includes("notFitNames=notFitNames")
        && source.includes("assert(result.visible")
        && !source.includes("d.Visible and not d.TextFits");
    }),
  "All five viewports must fail if the current sixteen-fist catalog is incomplete.",
);

check(
  "both_phone_profiles_check_every_visible_button",
  phoneTargetSteps.length === 2
    && phoneTargetSteps.some((step) => step.label.startsWith("844 "))
    && phoneTargetSteps.some((step) => step.label.startsWith("740 "))
    && phoneTargetSteps.every((step) => {
      const source = step.args?.code || "";
      return source.includes("d:IsA('GuiButton') and visible(d)")
        && source.includes("if size<44 then")
        && source.includes("smallNames=small")
        && source.includes("#small==0")
        && source.includes("count>=10");
    }),
  "844 and 740 must enumerate every actually visible GuiButton and reject any rendered target below 44px.",
);

check(
  "both_phone_profiles_reject_quests_jump_overlap",
  phoneTargetSteps.every((step) => {
    const source = step.args?.code || "";
    return source.includes("h:FindFirstChild('QuestsButton')")
      && source.includes("h:FindFirstChild('ActionJump')")
      && source.includes("not overlaps(quests,jump)")
      && step.expectRegex?.some((pattern) =>
        pattern.includes("questsJumpClear") && pattern.endsWith("true"));
  }),
  "Both phone profiles must fail closed if Quests overlaps Jump.",
);

check(
  "phone_target_assertions_are_exact_and_diagnostic",
  phoneTargetSteps.every((step) =>
    step.expectRegex?.some((pattern) =>
      pattern.includes("small") && pattern.endsWith("0"))
    && step.expectRegex?.some((pattern) =>
      pattern.includes("minTarget") && pattern.includes("4[4-9]"))
    && !(step.args?.code || "").includes("or true")),
  "Phone target assertions must expose failing names, require zero small targets, and retain a numeric 44px floor.",
);

check(
  "compact_honor_and_directional_punch_targets_have_real_48px_profiles",
  client.includes("enforceReferenceTouchTarget(honorOpen)")
    && client.includes('"CompactTransparentHit48V1"')
    && client.includes("enforceReferenceTouchTarget(punchUpButton)")
    && client.includes("enforceReferenceTouchTarget(punchDownButton)")
    && client.includes('constraint.Name = "MinimumTouchTarget"')
    && client.includes("constraint.MinSize = Vector2.new(44, 44)")
    && client.includes('"CompactTouchPair48V1"')
    && client.includes("punchUpButton.Size = UDim2.fromOffset(48, 48)")
    && client.includes("punchDownButton.Size = UDim2.fromOffset(48, 48)"),
  "The compact Honor overlay and both directional punch controls must keep explicit 48px hit areas instead of design-scale shrinking below 44px.",
);

check(
  "long_catalog_names_and_prices_scale_inside_every_card",
  client.includes("productNameLabel.TextScaled = true")
    && client.includes("productNameSize.MinTextSize = compactCards and 8 or 10")
    && client.includes("priceLabel.TextScaled = true")
    && client.includes("priceTextSize.MaxTextSize = compactCards and 10 or 14")
    && !client.includes("if #productName > 18 then"),
  "Every visible long-play product name and price must use bounded scaling; short strings can still clip in narrow half-width cards.",
);

const passed = Object.values(checks).filter(Boolean).length;
console.log(JSON.stringify({
  ok: passed === Object.keys(checks).length,
  passed,
  total: Object.keys(checks).length,
  shopViewports: shopSteps.length,
  phoneProfiles: phoneTargetSteps.length,
  checks,
  files: [path.relative(repositoryRoot, flowPath), path.relative(repositoryRoot, clientPath)],
}, null, 2));
