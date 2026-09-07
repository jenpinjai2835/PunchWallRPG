import fs from "node:fs";
import path from "node:path";

const input = process.argv[2];
const output = process.argv[3];

if (!input || !output) {
  throw new Error("Usage: node prepare-rbxmk-place-input.mjs <input.rbxlx> <output.rbxlx>");
}
if (path.extname(input).toLowerCase() !== ".rbxlx" || path.extname(output).toLowerCase() !== ".rbxlx") {
  throw new Error("Input and output must use the .rbxlx extension");
}

const source = fs.readFileSync(input, "utf8");
const prepared = source.replace(/^\uFEFF?<\?xml[^>]*\?>\s*/i, "");
if (!prepared.startsWith("<roblox")) {
  throw new Error("Prepared RBXLX does not begin with the Roblox root element");
}
fs.writeFileSync(output, prepared, "utf8");
process.stdout.write(JSON.stringify({ ok: true, output, bytes: Buffer.byteLength(prepared) }) + "\n");
