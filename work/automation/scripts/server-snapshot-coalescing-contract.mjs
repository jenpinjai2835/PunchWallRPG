#!/usr/bin/env node
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const repositoryRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../../..");
const sourcePath = path.join(repositoryRoot, "work/punch-wall-rpg/src/server/PunchWallBootstrap.server.lua");
const source = fs.readFileSync(sourcePath, "utf8").replace(/\r\n?/g, "\n");
function extract(start, end) {
  const a = source.indexOf(start);
  const b = source.indexOf(end, a + start.length);
  assert(a >= 0 && b > a, `Missing production source boundary: ${start}`);
  return source.slice(a, b);
}
const snapshotCode = extract("shared.PunchWallStatsSync = {", "do\nlocal function retryDataStoreCall");
const bossCode = extract("local function hitBoss(player, weakPointMultiplier)", "bossClick.MouseClick:Connect");
const numberListener = extract("local function number(name, value, parent)", "local function text(name)");
const textListener = extract("local function text(name)", "for _, name in ipairs(LEADERSTAT_NAMES)");
assert(numberListener.includes('shared.PunchWallStatsSync.queue(player, name == "Depth" or name == "Score")'));
assert(!numberListener.includes("syncStats("), "Ordinary numeric changes must use the queue");
assert(textListener.includes("shared.PunchWallStatsSync.queue(player)"));
assert([...source.matchAll(/Players\.PlayerRemoving:Connect\(function\(player\)([\s\S]*?)\nend\)/g)].some(match => match[1].includes("shared.PunchWallStatsSync.remove(player)")), "Player removal must discard queued snapshots");
assert(source.includes('if action == "RequestSync" then\n\t\tif profileReady(player, false) then\n\t\t\tsyncStats(player)'));

const cliDirIndex = process.argv.indexOf("--luau-tool-dir");
const toolDirs = [
  cliDirIndex >= 0 && process.argv[cliDirIndex + 1],
  process.env.PUNCH_WALL_LUAU_TOOL_DIR,
  path.join(repositoryRoot, ".tools/luau"),
  ...String(process.env.PATH || "").split(path.delimiter),
  ...fs.readdirSync(os.tmpdir(), { withFileTypes: true })
    .filter((entry) => entry.isDirectory() && /^codex-luau-/i.test(entry.name))
    .map((entry) => path.join(os.tmpdir(), entry.name)),
].filter(Boolean);
const executable = toolDirs.map((dir) => path.join(dir, process.platform === "win32" ? "luau.exe" : "luau"))
  .find((candidate) => fs.existsSync(candidate));
assert(executable, "BLOCKED: Luau runtime unavailable; pass --luau-tool-dir or PUNCH_WALL_LUAU_TOOL_DIR");
const compiler = path.join(path.dirname(executable), process.platform === "win32" ? "luau-compile.exe" : "luau-compile");
assert(fs.existsSync(compiler), "BLOCKED: matching Luau compiler unavailable");

const mocks = String.raw`
local now, timers, sent, leaderboardBuilds, boardUpdates = 0, {}, {}, 0, 0
local task = {}
function task.delay(delay, callback, ...)
  table.insert(timers, { at = now + delay, callback = callback, args = {...} })
end
function task.defer(callback, ...) task.delay(0, callback, ...) end
local function advance(target)
  local safety = 0
  while true do
    table.sort(timers, function(a,b) return a.at < b.at end)
    if #timers == 0 or timers[1].at > target + 0.0000001 then break end
    local timer = table.remove(timers, 1)
    now = timer.at
    timer.callback(table.unpack(timer.args))
    safety += 1
    assert(safety < 1000, 'scheduler did not terminate')
  end
  now = target
end
local Players = { list = {} }
function Players:GetPlayers() return table.clone(self.list) end
local function newPlayer(id)
  local values = {
    Power = {Name='Power',Value=15}, Coins={Name='Coins',Value=0}, Score={Name='Score',Value=0},
    Depth={Name='Depth',Value=0}, WallLevel={Name='WallLevel',Value=1},
    TutorialCompleted={Name='TutorialCompleted',Value=1},
  }
  for _,v in pairs(values) do function v:IsA(kind) return kind == 'NumberValue' end end
  local folder = {}
  function folder:GetChildren()
    local children = {} for _,v in pairs(values) do table.insert(children,v) end return children
  end
  local emptyFolder = {} function emptyFolder:GetChildren() return {} end
  local player = { UserId=id, DisplayName='Player'..id, Parent=Players, values=values, attributes={}, ready=true }
  function player:FindFirstChild(name)
    if name == 'RPGStats' then return folder elseif name == 'leaderstats' then return emptyFolder end
  end
  function player:GetAttribute(name) return self.attributes[name] end
  function player:SetAttribute(name,value) self.attributes[name]=value end
  table.insert(Players.list,player)
  return player
end
local function profileReady(player) return player.ready end
local function trainingQualificationPower(player) return player.values.Power.Value end
local function buildServerLeaderboard()
  leaderboardBuilds += 1
  local entries = {}
  for _,p in ipairs(Players:GetPlayers()) do
    table.insert(entries, {userId=p.UserId,name=p.DisplayName,depth=p.values.Depth.Value,score=p.values.Score.Value})
  end
  return entries
end
local shared = { PunchWallUpdateWorldRankBoard = function() boardUpdates += 1 end }
local GameConfig = {
  MaxCritChance=65, MaxEquippedPets=3, TutorialCompleteStep=4, TutorialVersion=2, Tutorial={},
  Fists={{name='Starter'}}, PremiumFists={}, HonorItems={}, Pets={}, PremiumPets={}, Rewards={},
  Spin={CooldownSeconds=72000}, Training={}, PremiumProducts={}, WorldProgressTarget=75,
}
function GameConfig.XPForLevel() return 30 end
function GameConfig.RebirthBonus() return 1 end
function GameConfig.RankForDepth() return 'ROOKIE' end
function GameConfig.RebirthRequirement()
  return {requiredLevel=55,requiredCoins=1000000,nextRebirths=1,permanentMultiplier=1.25,maxed=false}
end
local fireHook
local statRemote = {}
function statRemote:FireClient(player,payload)
  table.insert(sent,{player=player,payload=payload,at=now})
  if fireHook then fireHook(player,payload) end
end
`;
const snapshotTests = String.raw`
local passed=0
local function check(condition,message) assert(condition,message) passed += 1 end
local function reset()
  now=0 timers={} sent={} leaderboardBuilds=0 boardUpdates=0 Players.list={} fireHook=nil
  shared.PunchWallStatsSync.pending={} shared.PunchWallStatsSync.scheduled=false shared.PunchWallStatsSync.leaderboardDirty=false
end
reset()
local p=newPlayer(1)
for i=1,480 do p.values.Coins.Value=i shared.PunchWallStatsSync.queue(p) end
check(#sent==0 and #timers==1,'burst must have one deadline and no synchronous snapshots')
advance(.049)
check(#sent==0,'window must remain bounded without flushing early')
advance(.05)
check(#sent==1 and sent[1].payload.Coins==480,'burst must send exactly one complete final state')
check(sent[1].payload.FistCatalog==GameConfig.Fists and sent[1].payload.TrainingConfig==GameConfig.Training,'complete payload contract changed')
check(leaderboardBuilds==1 and boardUpdates==1,'single burst must build/update leaderboard once')

reset() p=newPlayer(1) local q=newPlayer(2)
for i=1,192 do
  p.values.Score.Value=i shared.PunchWallStatsSync.queue(p,true)
  q.values.Score.Value=i*2 shared.PunchWallStatsSync.queue(q,true)
end
advance(.05)
check(#sent==2 and leaderboardBuilds==1 and boardUpdates==1,'shared score burst must flush each player once')
local snapshots={} for _,e in ipairs(sent) do snapshots[e.player]=e.payload end
check(snapshots[p].Score==192 and snapshots[q].Score==384,'shared flush lost final contributor scores')

reset() p=newPlayer(1)
for i=1,10 do
  p.values.Power.Value=i shared.PunchWallStatsSync.queue(p)
  advance(i*.01)
end
check(#sent==2 and sent[1].at<=.05 and sent[2].at<=.10,'continuous input postponed its original deadlines')

reset() p=newPlayer(1)
shared.PunchWallStatsSync.queue(p)
fireHook=function(player)
  fireHook=nil player.values.Power.Value=99 shared.PunchWallStatsSync.queue(player)
end
advance(.05)
check(#sent==1 and sent[1].payload.Power==15 and #timers==1,'mutation during flush must retain next window')
advance(.1)
check(#sent==2 and sent[2].payload.Power==99,'follow-up flush lost its new state')

reset() p=newPlayer(1)
shared.PunchWallStatsSync.queue(p)
syncStats(p)
check(#sent==1 and sent[1].at==0,'explicit sync must remain immediate')
advance(.05)
check(#sent==1,'explicit sync must consume ordinary pending update')

reset() p=newPlayer(1) q=newPlayer(2)
shared.PunchWallStatsSync.queue(p,true)
shared.PunchWallStatsSync.remove(p) p.Parent=nil table.remove(Players.list,1)
advance(.05)
check(#sent==1 and sent[1].player==q and shared.PunchWallStatsSync.pending[p]==nil,'removed player retained or sent stale snapshot')

reset() p=newPlayer(1)
shared.PunchWallStatsSync.queue(p) p.ready=false
advance(.05)
check(#sent==0,'unready profile must not receive deferred snapshot')
shared.PunchWallStatsSync.queue(p)
check(#timers==0,'unready profile must not create pending work')
p.ready=true shared.PunchWallStatsSync.queue(p) advance(.1)
check(#sent==1,'queue failed to recover after skipped unready player')
print('snapshot_checks',passed)
`;
const bossMocks = String.raw`
local boss = {Name='Titan Server Wall',attributes={}}
function boss:GetAttribute(name) return self.attributes[name] end
function boss:SetAttribute(name,value) self.attributes[name]=value end
local bossStyle={accent='accent'}
local BOSS_BASE_HP=800000000
local bossParticipants,bossContributions={},{}
local feedback={}
local function statValue(player,name,fallback)
  return player.values[name] and player.values[name].Value or fallback
end
local function sendFeedback(player,payload) table.insert(feedback,payload) end
local function effectivePower() return 5 end
local function broadcastFeedback() end
local function updateWallText() end
local function updateWallDamage() end
local function emitNamed() end
local function playNamedSound() end
local PolishConfig={Palette={Fail='fail'},Motion={HitEmit=1}}
`;
const bossTests = String.raw`
local function setupBoss(depth,level,required)
  Players.list={}
  local player=newPlayer(1)
  player.values.Depth.Value=depth player.values.WallLevel.Value=level
  player:SetAttribute('LastBossHit',-100)
  boss.attributes={HP=BOSS_BASE_HP,MaxHP=BOSS_BASE_HP,RequiredDepth=required,RequiredLevel=99,ParticipantCount=0,BossPhase=1,Broken=false}
  bossContributions={} bossParticipants={} feedback={}
  return player
end
local gateChecks=0
local function gateCheck(condition,message) assert(condition,message) gateChecks+=1 end
for _,depth in ipairs({0,29,30,74}) do
  local player=setupBoss(depth,99,75)
  local result=hitBoss(player)
  gateCheck(result.ok==false and result.reason=='depth_gate' and result.requiredDepth==75,'boss admitted premature depth '..depth)
  gateCheck(boss:GetAttribute('HP')==BOSS_BASE_HP and next(bossParticipants)==nil and next(bossContributions)==nil and player:GetAttribute('LastBossHit')==-100,'rejected boss entry mutated combat state')
  gateCheck(#feedback==1 and feedback[1].message=='Clear Depth 75 first','boss rejection shows stale requirement')
end
local player=setupBoss(75,98,75)
local result=hitBoss(player)
gateCheck(result.ok==false and result.reason=='level_gate' and boss:GetAttribute('HP')==BOSS_BASE_HP,'Lv98 should remain gated')
player=setupBoss(75,99,75) result=hitBoss(player)
gateCheck(result.ok==true and result.outcome=='hit' and boss:GetAttribute('HP')==BOSS_BASE_HP-7,'eligible boss hit failed')
gateCheck(bossParticipants[player.UserId]==true and bossContributions[player.UserId]==7,'eligible contribution not recorded')
player=setupBoss(74,99,nil) result=hitBoss(player)
gateCheck(result.reason=='depth_gate' and result.requiredDepth==75,'missing attribute must fall back to configured target')
player=setupBoss(75,99,76) result=hitBoss(player)
gateCheck(result.reason=='depth_gate' and result.requiredDepth==76,'boss gate must read server attribute')
print('boss_gate_checks',gateChecks)
print('SERVER_SNAPSHOT_AND_BOSS_CONTRACT_PASS')
`;

const tempRoot = path.resolve(os.tmpdir());
const runDirectory = fs.mkdtempSync(path.join(tempRoot, "smash-server-contract-"));
const runner = path.join(runDirectory, "runner.luau");
let result;
let flowSnippetsCompiled = 0;
try {
  for (const name of ["server-snapshot-coalescing", "boss-depth-authority", "honor-progression"]) {
    const flow = JSON.parse(fs.readFileSync(path.join(repositoryRoot, `work/automation/flows/${name}.json`), "utf8"));
    for (const step of flow.steps) {
      if (step.tool !== "execute_luau" || !step.args?.code) continue;
      const snippetPath = path.join(runDirectory, `flow-${flowSnippetsCompiled}.luau`);
      fs.writeFileSync(snippetPath, step.args.code, "utf8");
      const compiled = spawnSync(compiler, ["--null", "-O0", snippetPath], { encoding: "utf8", timeout: 30000 });
      assert.equal(compiled.status, 0, `Flow ${name}, ${step.label} failed compilation:\n${compiled.stderr || compiled.error}`);
      flowSnippetsCompiled += 1;
    }
  }
  fs.writeFileSync(runner, [mocks, snapshotCode, snapshotTests, bossMocks, bossCode, bossTests].join("\n"), "utf8");
  result = spawnSync(executable, [runner], { encoding: "utf8", timeout: 30000, cwd: repositoryRoot });
  assert(!result.error, result.error?.message);
  assert.equal(result.status, 0, `Extracted production Luau failed:\n${result.stdout}\n${result.stderr}`);
  assert(result.stdout.includes("SERVER_SNAPSHOT_AND_BOSS_CONTRACT_PASS"));
} finally {
  assert.equal(path.dirname(path.resolve(runDirectory)), tempRoot, "Refuse cleanup outside the intended temporary directory");
  assert(path.basename(runDirectory).startsWith("smash-server-contract-"));
  fs.rmSync(runDirectory, { recursive: true, force: true });
}
const snapshotChecks = Number(result.stdout.match(/snapshot_checks\s+(\d+)/)?.[1]);
const bossGateChecks = Number(result.stdout.match(/boss_gate_checks\s+(\d+)/)?.[1]);
console.log(JSON.stringify({ ok: true, snapshotChecks, bossGateChecks, flowSnippetsCompiled, executedProductionLuau: true, luau: executable, output: result.stdout.trim() }, null, 2));
