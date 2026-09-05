#!/usr/bin/env node
// Executes extracted production Luau functions. No Roblox client or service access.
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../../..");
const clientPath = "work/punch-wall-rpg/src/client/PunchWallClient.client.lua";
const baselineIndex = process.argv.indexOf("--baseline");
const baseline = baselineIndex < 0 ? null : process.argv[baselineIndex + 1] || "4094e51";
const gitSource = baseline && spawnSync("git", ["show", `${baseline}:${clientPath}`], { cwd: root, encoding: "utf8" });
if (gitSource) assert.equal(gitSource.status, 0, gitSource.stderr);
const source = (gitSource ? gitSource.stdout : fs.readFileSync(path.join(root, clientPath), "utf8")).replace(/\r\n?/g, "\n");
const tempRoot = os.tmpdir();
const candidates = [process.env.LUAU_COMMAND, ...fs.readdirSync(tempRoot)
  .filter((name) => name.startsWith("codex-luau-"))
  .sort().reverse().map((name) => path.join(tempRoot, name, process.platform === "win32" ? "luau.exe" : "luau")), "luau"];
const luau = candidates.find((candidate) => candidate && spawnSync(candidate, ["--help"], { encoding: "utf8" }).status === 0);
assert.ok(luau, "BLOCKED: set LUAU_COMMAND to a Luau CLI executable");

function block(start, end) {
  const from = source.indexOf(start);
  assert.ok(from >= 0, `Missing production function ${start}`);
  const to = source.indexOf(end, from + start.length);
  assert.ok(to > from, `Missing production boundary ${end}`);
  return source.slice(from, to);
}
const common = `
local count = 0
local function check(value, name)
  assert(value, name)
  count += 1
end
local now = 100
local attributes = {}
local gui = {
  SetAttribute = function(_, k, v) attributes[k] = v end,
  GetAttribute = function(_, k) return attributes[k] end,
}
local Vector3 = {}
local vectorMeta = {}
function Vector3.new(x,y,z) return setmetatable({X=x,Y=y,Z=z}, vectorMeta) end
vectorMeta.__add = function(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
vectorMeta.__sub = function(a,b) return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
vectorMeta.__mul = function(a,b) if type(a)=='number' then a,b=b,a end return Vector3.new(a.X*b,a.Y*b,a.Z*b) end
vectorMeta.__index = function(a,k)
  if k=='Magnitude' then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z) end
  if k=='Unit' then return a*(1/a.Magnitude) end
end
Vector3.zero = Vector3.new(0,0,0)
local frameMeta = {}
local function frame(position, yaw) return setmetatable({Position=position,Yaw=yaw},frameMeta) end
frameMeta.__add = function(a,b) return frame(a.Position+b,a.Yaw) end
local Enum = {CameraType={Custom='Custom', Scriptable='Scriptable'}}
local shared = {PunchWallCameraPositionBlocked=function() return false end}
local Color3 = {fromRGB=function(r,g,b) return tostring(r)..','..tostring(g)..','..tostring(b) end}
local workspace = {GetServerTimeNow=function() return now end}
`;
const shopSetup = `
local shopRuntime = {Pages={'Fists','Premium','Boosts','Honor','Robux'}, BoostTickGeneration=0, BoostTickCount=0, BoostTickScheduled=false, BoostButtons={}}
local latestStats = {OwnedFistsJSON={'Starter Glove'}, EquippedFist='Starter Glove',Depth=0,ShopBoosts={CoinEndsAt=0, SpeedEndsAt=110, DamageEndsAt=0}}
local clientSettings = {uiScale=1}
local UserInputService = {TouchEnabled=true}
local GameConfig = {PremiumProducts={}}
workspace.CurrentCamera = {ViewportSize={X=740,Y=360}}
shared.PunchWallGetResponsiveViewport=function() return workspace.CurrentCamera.ViewportSize end
shared.PunchWallHeroShopPage = 'Fists'
local HttpService = {JSONEncode=function(_, fields)
  local result={} for _,v in ipairs(fields) do table.insert(result,tostring(v)) end return table.concat(result,'|')
end}
local function decodeJSON(raw, fallback) return raw or fallback end
${block("\tfunction shopRuntime.ResolvePage()", "\tfunction shopRuntime.AddStaticFistPresentation")}
`;
const fixtures = {
  camera: `${common}
local rootPart = {Position=Vector3.new(0,0,-2)}
local character = {FindFirstChild=function() return rootPart end}
local player = {Character=character}
local camera = {CameraType='Custom', CameraSubject=character}
workspace.CurrentCamera = camera
local os = {clock=function() return now end}
local function state()
 return {startedAt=99.8,delay=.08,followSpeed=48,maximumFollowSpeed=96,maximumLead=4,followSharpness=12,settleDistance=.2,
  startPosition=Vector3.zero,baseCFrame=frame(Vector3.new(0,4,12),0),baseFocus=frame(Vector3.new(0,0,0),0),translation=Vector3.zero,cameraType='Custom',cameraSubject=character}
end
local activePunchCamera = state()
${block("local function updatePunchCameraFollow(", 'RunService:BindToRenderStep("PunchWallDelayedCameraFollow"')}
camera.CFrame=frame(Vector3.new(8,4,9),.7)
camera.Focus=frame(Vector3.new(0,0,-2),.7)
local liveZoom=(camera.CFrame.Position-camera.Focus.Position).Magnitude
updatePunchCameraFollow(1/60)
check(camera.CFrame.Yaw==.7, 'camera_input_preserved')
check(math.abs((camera.CFrame.Position-camera.Focus.Position).Magnitude-liveZoom)<.00001,'camera_zoom_preserved')
check((camera.CFrame.Position-Vector3.new(8,4,9)).Magnitude>0,'camera_translation_feedback_retained')
for i=1,90 do
 now+=1/60
 camera.CFrame=frame(Vector3.new(8,4,9),.7)
 camera.Focus=frame(Vector3.new(0,0,-2),.7)
 updatePunchCameraFollow(1/60)
end
check(activePunchCamera==nil and (camera.CFrame.Position-Vector3.new(8,4,9)).Magnitude<.00001,'camera_no_accumulation_and_settles')
activePunchCamera=state()
activePunchCamera.startedAt=now
camera.CFrame=activePunchCamera.baseCFrame
camera.Focus=activePunchCamera.baseFocus
for i=1,90 do now+=1/60 updatePunchCameraFollow(1/60,true) end
check(activePunchCamera==nil and (camera.CFrame.Position-Vector3.new(0,4,10)).Magnitude<.00001,'camera_suspended_render_no_accumulation')
activePunchCamera=state()
camera.CameraType='Scriptable'
camera.CFrame=frame(Vector3.new(100,20,100),1.2)
updatePunchCameraFollow(1/60)
check(activePunchCamera==nil and camera.CameraType=='Scriptable' and camera.CFrame.Position.X==100 and camera.CFrame.Yaw==1.2,'camera_scriptable_handoff_preserved')
print('PASS '..count)
`,
  depth: `${common}${shopSetup}
local initial=shopRuntime.StateSignature(now)
latestStats.Depth=1
check(shopRuntime.StateSignature(now)~=initial,'depth_invalidates')
local reached=shopRuntime.StateSignature(now)
latestStats.Coins=999999
check(shopRuntime.StateSignature(now)==reached,'unrelated_coins_do_not_rebuild')
latestStats.Depth=0
check(shopRuntime.StateSignature(now)==initial,'depth_reset_relocks')
latestStats.Depth=-1
check(shopRuntime.StateSignature(now)==initial,'depth_normalizes_negative')
print('PASS '..count)
`,
  boost: `${common}${shopSetup}
shared.PunchWallHeroShopPage='Boosts'
local before=shopRuntime.StateSignature(now)
now+=1
check(shopRuntime.StateSignature(now)==before,'boost_without_rebuild')
latestStats.ShopBoosts.SpeedEndsAt=105
check(shopRuntime.StateSignature(now)~=before,'boost_endpoint_invalidates')
local shopReference={Visible=true,Parent=true,SetAttribute=gui.SetAttribute}
local callbacks={}
local task={delay=function(_,callback) table.insert(callbacks,callback) end}
local rebuilds=0
shared.PunchWallHeroShopRefresh=function() rebuilds+=1 end
${block(source.includes("\tfunction shopRuntime.UpdateBoostCountdown(now)") ? "\tfunction shopRuntime.UpdateBoostCountdown(now)" : "\tfunction shopRuntime.ScheduleBoostTick(page, now)", "\tshared.PunchWallHeroShopRefresh = function(options)")}
local activeSpeed={Parent=true,Text='',SetAttribute=gui.SetAttribute}
local damage={Parent=true,Text='',SetAttribute=gui.SetAttribute}
shopRuntime.BoostButtons={SpeedBoost={button=activeSpeed,idleColor='idle'},DamageBoost={button=damage,idleColor='idle'}}
shopRuntime.UpdateBoostCountdown(now)
check(activeSpeed.Text=='ACTIVE 00:04' and damage.Text=='BUY','boost_initial_labels')
shopRuntime.ScheduleBoostTick('Boosts',now)
now+=1
table.remove(callbacks,1)()
check(activeSpeed.Text=='ACTIVE 00:03' and rebuilds==0 and #callbacks==1,'boost_tick_mutates_only_existing_labels')
now=106
table.remove(callbacks,1)()
check(activeSpeed.Text=='BUY' and activeSpeed.BackgroundColor3=='idle' and #callbacks==0 and not shopRuntime.BoostTickScheduled,'boost_expiry_restores_buy_and_stops')
latestStats.ShopBoosts.SpeedEndsAt=200
shopRuntime.ScheduleBoostTick('Boosts',now)
shopReference.Visible=false
table.remove(callbacks,1)()
check(#callbacks==0 and not shopRuntime.BoostTickScheduled,'boost_hidden_page_stops')
shopReference.Visible=true
shopRuntime.ScheduleBoostTick('Boosts',now)
shopRuntime.BoostTickGeneration+=1
table.remove(callbacks,1)()
check(#callbacks==0 and rebuilds==0,'boost_stale_generation_no_work')
print('PASS '..count)
`,
};

const temp = fs.mkdtempSync(path.join(tempRoot, "smash-client-contract-"));
const results = {};
try {
  for (const [name, fixture] of Object.entries(fixtures)) {
    const file = path.join(temp, `${name}.luau`);
    fs.writeFileSync(file, fixture);
    const result = spawnSync(luau, [file], { encoding: "utf8", timeout: 15000 });
    const output = `${result.stdout || ""}${result.stderr || ""}`;
    const expected = { camera: "camera_input_preserved", depth: "depth_invalidates", boost: "boost_without_rebuild" }[name];
    if (baseline) {
      assert.ok(result.status !== 0 && output.includes(expected), `${name}: baseline must reproduce ${expected}: ${output}`);
      results[name] = { reproduced: expected };
    } else {
      assert.equal(result.status, 0, `${name}: ${output}`);
      results[name] = { passed: Number(output.match(/PASS (\d+)/)?.[1] || 0) };
    }
  }
  console.log(JSON.stringify({ ok: true, mode: baseline ? `baseline ${baseline}` : "current source", luau, results }, null, 2));
} finally {
  // Only remove files created in this exact temp directory; no recursive cleanup.
  for (const name of Object.keys(fixtures)) {
    const file = path.join(temp, `${name}.luau`);
    if (fs.existsSync(file)) fs.unlinkSync(file);
  }
  fs.rmdirSync(temp);
}
