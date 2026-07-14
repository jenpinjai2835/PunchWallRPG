import { spawn } from "node:child_process";
import fs from "node:fs";
import path from "node:path";

const base = process.env.LOCALAPPDATA + "\\Roblox\\Versions";
const exe = [...fs.readdirSync(base)].map((v) => path.join(base, v, "StudioMCP.exe")).filter(fs.existsSync).sort((a, b) => fs.statSync(b).mtimeMs - fs.statSync(a).mtimeMs)[0];
const child = spawn(exe, ["--stdio"], { stdio: ["pipe", "pipe", "pipe"] });
let nextId = 1, buffer = ""; const responses = new Map();
child.stdout.on("data", (d) => { buffer += d.toString(); let i; while ((i = buffer.indexOf("\n")) >= 0) { const line = buffer.slice(0, i).trim(); buffer = buffer.slice(i + 1); if (!line) continue; const m = JSON.parse(line); if (m.id !== undefined) responses.set(m.id, m); } });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
async function call(name, args = {}, timeout = 60000) { const id = nextId++; child.stdin.write(JSON.stringify({ jsonrpc: "2.0", id, method: "tools/call", params: { name, arguments: args } }) + "\n"); const started = Date.now(); while (Date.now() - started < timeout) { if (responses.has(id)) { const r = responses.get(id); responses.delete(id); return r; } await sleep(50); } throw new Error("timeout " + name); }
function content(msg) { return msg?.result?.content || []; }
function text(msg) { return content(msg).map((x) => x.text || "").join("\n"); }
async function main() {
  const init = nextId++; child.stdin.write(JSON.stringify({ jsonrpc: "2.0", id: init, method: "initialize", params: { protocolVersion: "2024-11-05", capabilities: {}, clientInfo: { name: "fist-angle-qc", version: "1" } } }) + "\n"); while (!responses.has(init)) await sleep(50); responses.delete(init); child.stdin.write(JSON.stringify({ jsonrpc: "2.0", method: "notifications/initialized" }) + "\n");
  const studios = JSON.parse(text(await call("list_roblox_studios"))).studios; const studio = studios.find((s) => /PunchWallRPGPlayable/.test(s.name)) || studios[0]; await call("set_active_studio", { studio_id: studio.id }); await call("start_stop_play", { is_start: true }, 35000); await sleep(8000);
  const outDir = "F:\\Roblox\\PuchWall\\work\\qc-fist-angle"; fs.mkdirSync(outDir, { recursive: true });
  const items = [["Starter Glove", "starter"], ["Iron Knuckle", "iron"], ["Thunder Fist", "thunder"], ["Titan Gauntlet", "titan"]];
  for (const [item, label] of items) { await call("execute_luau", { datamodel_type: "Server", code: `local c=game.ServerStorage.PunchWallAutomation c:Invoke('SetStats',{Coins=1000000,Power=1000,WallLevel=99}) return c:Invoke('BuyFist','${item}')` }); await sleep(450); const shot = await call("screen_capture", { capture_id: "FistAngleQC_" + label, camera_position: [8, 6, -18], look_at_position: [1, 5, -19] }, 60000); const img = content(shot).find((x) => x.type === "image" && x.data); if (!img) throw new Error("no image " + label); fs.writeFileSync(path.join(outDir, label + ".jpg"), Buffer.from(img.data, "base64")); }
  await call("start_stop_play", { is_start: false }, 35000); child.kill(); console.log(JSON.stringify({ ok: true, outDir }, null, 2));
}
main().catch((e) => { console.error(e); child.kill(); process.exitCode = 1; });
