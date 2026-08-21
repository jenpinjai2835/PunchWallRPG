import fs from "node:fs";

const sourcePath = process.argv[2];
const targetPath = process.argv[3];
const outputPath = process.argv[4];
if (!sourcePath || !targetPath || !outputPath) {
  throw new Error("Usage: node restore-rbxmk-mesh-content.mjs <source.rbxmx> <target.rbxlx> <output.rbxlx>");
}

const itemPattern = /<Item class="MeshPart"[^>]*>\s*<Properties>([\s\S]*?)<\/Properties>/g;
const namePattern = /<string name="Name">([\s\S]*?)<\/string>/;
const meshPattern = /<Content name="MeshContent">[\s\S]*?<\/Content>/;
const texturePattern = /<Content name="TextureContent">[\s\S]*?<\/Content>/;

function collect(source) {
  const entries = new Map();
  for (const match of source.matchAll(itemPattern)) {
    const properties = match[1];
    const name = properties.match(namePattern)?.[1];
    const meshContent = properties.match(meshPattern)?.[0];
    const textureContent = properties.match(texturePattern)?.[0];
    if (!name || !meshContent || /<null\b/i.test(meshContent)) continue;
    const list = entries.get(name) ?? [];
    list.push({ meshContent, textureContent });
    entries.set(name, list);
  }
  return entries;
}

const source = fs.readFileSync(sourcePath, "utf8");
const target = fs.readFileSync(targetPath, "utf8");
const sourceEntries = collect(source);
const used = new Map();
let restored = 0;
let matchedNames = 0;

const result = target.replace(itemPattern, (whole, properties) => {
  const name = properties.match(namePattern)?.[1];
  const candidates = name ? sourceEntries.get(name) : undefined;
  if (!candidates?.length) return whole;
  const index = used.get(name) ?? 0;
  const sourceEntry = candidates[Math.min(index, candidates.length - 1)];
  used.set(name, index + 1);
  let updated = properties;
  if (meshPattern.test(updated)) {
    updated = updated.replace(meshPattern, sourceEntry.meshContent);
    restored += 1;
  }
  if (sourceEntry.textureContent && texturePattern.test(updated)) {
    updated = updated.replace(texturePattern, sourceEntry.textureContent);
  }
  matchedNames += 1;
  return whole.replace(properties, updated);
});

if (sourceEntries.size < 8 || restored < 8 || matchedNames < 8) {
  throw new Error(`Insufficient skinned mesh restoration: ${JSON.stringify({ sourceNames: sourceEntries.size, restored, matchedNames })}`);
}
fs.writeFileSync(outputPath, result, "utf8");
process.stdout.write(JSON.stringify({ ok: true, sourceNames: sourceEntries.size, restored, matchedNames, outputPath }) + "\n");
