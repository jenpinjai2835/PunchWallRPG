#!/usr/bin/env node
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";

const root = path.resolve(import.meta.dirname, "../..");
const read = (relative) => fs.readFileSync(path.join(root, relative), "utf8");
const config = read("punch-wall-rpg/src/shared/GameConfig.lua");
const builder = read("punch-wall-rpg/src/shared/FistVisualBuilder.lua");
const client = read("punch-wall-rpg/src/client/PunchWallClient.client.lua");
const flow = JSON.parse(read("automation/flows/fist-items-icon-ui.json"));

const checks = {};
function check(name, value, message) {
  checks[name] = value === true;
  assert.equal(checks[name], true, `${name}: ${message}`);
}

const normalBlock = config.match(/GameConfig\.Fists = \{([\s\S]*?)\n\}/)?.[1] || "";
const premiumBlock = config.match(/GameConfig\.PremiumFists = \{([\s\S]*?)\n\}/)?.[1] || "";
const iconKeys = (text) => [...text.matchAll(/icon = "([^"]+)"/g)].map((match) => match[1]);
const normalIcons = iconKeys(normalBlock);
const premiumIcons = iconKeys(premiumBlock);
const allIcons = [...normalIcons, ...premiumIcons];
const signatures = [...builder.matchAll(/signatureFeature = "([A-Z]+)"/g)].map((match) => match[1]);

check(
  "sixteen_normal_fists_have_unique_icon_keys",
  normalIcons.length === 16 && new Set(normalIcons).size === 16,
  "Every normal fist must expose a unique icon identity.",
);
check(
  "premium_fists_do_not_alias_normal_or_each_other",
  premiumIcons.length === 3 && new Set(allIcons).size === 19,
  "Premium fist identities must not reuse normal fist keys or each other.",
);
check(
  "eight_armor_families_have_distinct_signatures",
  signatures.length === 8 && new Set(signatures).size === 8,
  "Every armor family needs a distinct short visual signature.",
);
check(
  "unknown_styles_and_missing_icons_fail_closed",
  builder.includes('assert(style, ("Unknown hero gauntlet style: %s")')
    && builder.includes('assert(iconIdentity ~= "", ("Fist %s is missing a unique icon identity")'),
  "Controlled catalog mistakes must fail loudly instead of becoming Starter art.",
);
check(
  "shop_uses_perimeter_only_catalog_identity",
  client.includes('card:SetAttribute("ShopFistIconIdentity", presentation.iconIdentity)')
    && client.includes('card:SetAttribute("ShopFistCatalogMotif", presentation.catalogMotif)')
    && client.includes('card:SetAttribute("StaticPreviewChromeOnly", true)')
    && client.includes('card:SetAttribute("StaticPreviewChromeCoverage", "PerimeterOnlyV1")')
    && client.includes('tierText.Text = ("T%02d"):format(presentation.tier)')
    && client.includes("featureLabel.Text = presentation.signatureFeature")
    && client.includes('card:SetAttribute("StaticPreviewIdentityVersion", "UniqueFistPerimeterV2")')
    && client.includes('card:SetAttribute("StaticPreviewStyleVersion", "PerimeterCatalogIdentityV2")')
    && client.includes("icon.ImageColor3 = Color3.new(1, 1, 1)")
    && client.includes('icon:SetAttribute("HeroGauntletTintMatched", false)')
    && client.includes('icon:SetAttribute("LoadedArtUnobscured", icon.Image ~= "")')
    && client.includes('catalogMotif.Name = "StaticCatalogMotif"'),
  "Shop cards must keep loaded pixels unobscured and move unique motif, tier, and armor-family identity to perimeter chrome.",
);
check(
  "icon_identity_is_static_and_bounded",
  client.includes('card:SetAttribute("StaticPreviewRenderLoop", false)')
    && client.includes("local tierPipCount = math.clamp(math.ceil(presentation.tier / 4), 1, 4)")
    && client.includes("for plateIndex = 1, presentation.plateCount do")
    && client.includes("for finIndex = 1, presentation.finCount do"),
  "The richer icon treatment must remain bounded and use no render loop.",
);
const flowCode = flow.steps.map((step) => step.args?.code || "").join("\n");
const iconStep = flow.steps.find((step) => step.label?.includes("sixteen Shop fists"));
check(
  "runtime_flow_rejects_duplicate_visual_identity",
  flowCode.includes("uniqueIdentity=uniqueIdentity")
    && flowCode.includes("variantCount=variantCount")
    && flowCode.includes("whiteUnobscured=whiteUnobscured")
    && flowCode.includes("motifCount=motifCount")
    && iconStep?.expectRegex?.some((pattern) => pattern.includes("uniqueIdentity") && pattern.endsWith("16"))
    && iconStep?.expectRegex?.some((pattern) => pattern.includes("variantCount") && pattern.endsWith("16"))
    && iconStep?.expectRegex?.some((pattern) => pattern.includes("motifCount") && pattern.endsWith("16"))
    && iconStep?.expectRegex?.some((pattern) => pattern.includes("whiteUnobscured") && pattern.endsWith("16")),
  "Studio QC must prove all sixteen visible icon identities and motifs are unique while every uploaded image remains unobscured.",
);

console.log(JSON.stringify({
  ok: true,
  passed: Object.values(checks).filter(Boolean).length,
  total: Object.keys(checks).length,
  normalIcons: normalIcons.length,
  premiumIcons: premiumIcons.length,
  checks,
}, null, 2));
