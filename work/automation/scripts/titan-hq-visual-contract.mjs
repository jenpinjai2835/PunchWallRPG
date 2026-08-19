import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const workspaceRoot = path.resolve(scriptDirectory, "..", "..", "..");
const sourceRoot = path.join(workspaceRoot, "work", "punch-wall-rpg", "src");
const builderPath = path.join(sourceRoot, "shared", "ForestVisualBuilder.lua");
const configPath = path.join(sourceRoot, "shared", "PolishConfig.lua");
const flowPath = path.join(
  workspaceRoot,
  "work",
  "automation",
  "flows",
  "titan-hq-tonal-readability.json",
);

const builder = fs.readFileSync(builderPath, "utf8");
const config = fs.readFileSync(configPath, "utf8");
const flow = JSON.parse(fs.readFileSync(flowPath, "utf8"));

function rgb(name) {
  const match = config.match(
    new RegExp(`${name}\\s*=\\s*Color3\\.fromRGB\\((\\d+),\\s*(\\d+),\\s*(\\d+)\\)`),
  );
  assert.ok(match, `missing ${name} RGB token`);
  return match.slice(1, 4).map(Number);
}

function luminance(color) {
  return (color[0] * 0.2126 + color[1] * 0.7152 + color[2] * 0.0722) / 255;
}

const inset = luminance(rgb("TitanInset"));
const panel = luminance(rgb("TitanPanel"));
const metal = luminance(rgb("TitanMetal"));
const seam = luminance(rgb("TitanSeam"));
const edge = luminance(rgb("TitanEdge"));
const accent = luminance(rgb("TitanAccent"));
const weakPoint = luminance(rgb("TitanWeakPointAccent"));
const titanWallBlock = config.match(
  /\["Titan Server Wall"\]\s*=\s*\{([\s\S]*?)\n\t\},/,
);
assert.ok(titanWallBlock, "missing Titan Server Wall style");
const titanWallColor = titanWallBlock[1].match(
  /color\s*=\s*Color3\.fromRGB\((\d+),\s*(\d+),\s*(\d+)\)/,
);
assert.ok(titanWallColor, "missing Titan Server Wall base color");
const wall = luminance(titanWallColor.slice(1, 4).map(Number));

assert.ok(wall >= 0.20, "Titan wall base remains near-black");
assert.ok(panel - inset >= 0.07, "Titan panel does not separate from inset");
assert.ok(metal - panel >= 0.07, "Titan frame does not separate from panel");
assert.ok(seam > metal, "Titan seam must read above the frame");
assert.ok(edge - metal >= 0.18, "Titan edge highlight is too dim");
assert.ok(accent - inset >= 0.20, "Titan emergency accent is too dim");
assert.ok(weakPoint - panel >= 0.35, "Titan weak-point accent is too dim");

for (const role of [
  "TitanFacadePanel",
  "TitanFacadeInset",
  "TitanFacadeSeam",
  "TitanFacadeEdge",
  "TitanWeakPointBracket",
  "TitanWeakPointCorner",
]) {
  assert.ok(builder.includes(`"${role}"`), `missing ${role} presentation role`);
}

const presentationSection = builder.slice(
  builder.indexOf("function ForestVisualBuilder.BuildPresentation"),
);
assert.ok(presentationSection.length > 0, "missing BuildPresentation");
assert.ok(
  presentationSection.includes("expectedTitanParts = 28 + #weakPoints * 8"),
  "missing bounded Titan part-count formula",
);
assert.ok(
  presentationSection.includes(
    "(groupCounts.TitanHQ or 0) == expectedTitanParts",
  ),
  "missing Titan hierarchy part-count assertion",
);
for (const runtimeToken of [
  "RunService",
  "RenderStepped",
  "Heartbeat",
  "Stepped:Connect",
  "task.spawn",
  "while true",
]) {
  assert.equal(
    presentationSection.includes(runtimeToken),
    false,
    `world presentation contains runtime loop token: ${runtimeToken}`,
  );
}

const budgetMatch = config.match(/MaxDecorativeParts\s*=\s*(\d+)/);
assert.ok(budgetMatch, "missing MaxDecorativeParts");
assert.ok(Number(budgetMatch[1]) <= 128, "world presentation budget exceeds hard cap");
assert.equal(flow.name, "titan-hq-tonal-readability");
assert.ok(flow.steps.some((step) => step.label?.includes("gameplay-neutral")));

console.log(
  JSON.stringify({
    ok: true,
    contractVersion: 2,
    budget: Number(budgetMatch[1]),
    checks: 23,
    luminance: {
      wall,
      inset,
      panel,
      metal,
      seam,
      edge,
      accent,
      weakPoint,
    },
  }),
);
