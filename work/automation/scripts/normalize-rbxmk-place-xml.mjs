import fs from "node:fs";
import path from "node:path";

const input = process.argv[2];
const output = process.argv[3];

if (!input || !output) {
  throw new Error("Usage: node normalize-rbxmk-place-xml.mjs <input.rbxlx> <output.rbxlx>");
}
if (path.extname(input).toLowerCase() !== ".rbxlx" || path.extname(output).toLowerCase() !== ".rbxlx") {
  throw new Error("Input and output must use the .rbxlx extension");
}

const source = fs.readFileSync(input, "utf8");
const invalidTypedStringPattern = /\s*<string name="(PhysicsData|AttributesSerialize|Tags|MeshID)">[\s\S]*?<\/string>/g;
const removedByProperty = {};
const normalized = source.replace(invalidTypedStringPattern, (_match, propertyName) => {
  removedByProperty[propertyName] = (removedByProperty[propertyName] ?? 0) + 1;
  return "";
});
let removedLegacySize = 0;
const normalizedProperties = normalized.replace(/<Properties>[\s\S]*?<\/Properties>/g, (block) => {
  if (!block.includes('<Vector3 name="Size">') || !block.includes('<Vector3 name="size">')) return block;
  return block.replace(/\s*<Vector3 name="size">[\s\S]*?<\/Vector3>/g, () => {
    removedLegacySize += 1;
    return "";
  });
});
const forbiddenControlEntity = /&#(?:0|[1-8]|11|12|14|15|16|17|18|19|20|21|22|23|24|25|26|27|28|29|30|31);/;
if (forbiddenControlEntity.test(normalizedProperties)) {
  throw new Error("Normalized RBXLX still contains XML-forbidden control entities");
}
if ((removedByProperty.PhysicsData ?? 0) === 0) {
  throw new Error("No rbxmk PhysicsData string fields were found; refusing an unverified rewrite");
}
fs.writeFileSync(output, normalizedProperties, "utf8");
process.stdout.write(JSON.stringify({ ok: true, removedByProperty, removedLegacySize, output, bytes: Buffer.byteLength(normalizedProperties) }) + "\n");
