#!/usr/bin/env node
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../../..");
const clientPath = "work/punch-wall-rpg/src/client/PunchWallClient.client.lua";
const baselineIndex = process.argv.indexOf("--baseline");
const baseline = baselineIndex < 0 ? null : process.argv[baselineIndex + 1] || "fd845d3";
const original = baseline && spawnSync("git", ["show", `${baseline}:${clientPath}`], { cwd: root, encoding: "utf8" });
if (original) assert.equal(original.status, 0, original.stderr);
const source = (original ? original.stdout : fs.readFileSync(path.join(root, clientPath), "utf8")).replace(/\r\n?/g, "\n");
function block(start, end) {
  const from = source.indexOf(start), to = source.indexOf(end, from + start.length);
  assert.ok(from >= 0 && to > from, `Missing production boundary ${start} -> ${end}`);
  return source.slice(from, to);
}
const observer = source.includes("function companionRuntime.CharacterHandSizeSignature")
  ? block("function companionRuntime.CharacterHandSizeSignature", "\nrefreshCharacterVisuals = function()") : "";
if (!baseline) {
  assert.ok(observer);
  assert.ok(source.includes("companionRuntime.ObserveCharacterHandSizes(player.Character)"), "initial character must be observed");
}
const refresh = block("\nrefreshCharacterVisuals = function()", "\n\tbuildHonorCosmetic(latestStats.EquippedHonorItem)") + "\nend\n";
const lifecycle = block("\nplayer.CharacterAdded:Connect(function(character)", source.includes("\n\tcompanionRuntime.ObserveCharacterHandSizes(player.Character)")
  ? "\ntask.defer(function()\n\tcompanionRuntime.ObserveCharacterHandSizes(player.Character)" : "\ntask.defer(function()\n\trequestAction(\"RequestSync\")");
const tempRoot = os.tmpdir();
const candidates = [process.env.LUAU_COMMAND, ...fs.readdirSync(tempRoot).filter((name) => name.startsWith("codex-luau-")).sort().reverse()
  .map((name) => path.join(tempRoot, name, process.platform === "win32" ? "luau.exe" : "luau")), "luau"];
const luau = candidates.find((candidate) => candidate && spawnSync(candidate, ["--help"], { encoding: "utf8" }).status === 0);
assert.ok(luau, "BLOCKED: set LUAU_COMMAND to a Luau CLI executable");

const setup = `
local checks=0
local function check(v,name) assert(v,name) checks+=1 end
local function signal()
 local s={records={}}
 function s:Connect(cb)
  local c={callback=cb,connected=true}
  function c:Disconnect()self.connected=false end
  table.insert(self.records,c) return c
 end
 function s:Fire(...)for _,c in ipairs(self.records)do if c.connected then c.callback(...)end end end
 function s:FireAll(...)for _,c in ipairs(self.records)do c.callback(...)end end
 function s:Count()local n=0 for _,c in ipairs(self.records)do if c.connected then n+=1 end end return n end
 return s
end
local now=0 local queue={}
local task={}
function task.delay(delay,cb)table.insert(queue,{at=now+delay,callback=cb})end
function task.defer(cb)task.delay(0,cb)end
local function advance(delta)
 local finish=now+delta
 while true do
  table.sort(queue,function(a,b)return a.at<b.at end)
  local next=queue[1] if not next or next.at>finish then break end
  table.remove(queue,1) now=next.at next.callback()
 end
 now=finish
end
local function hand(name,x,y,z)
 local h={Name=name,Size={X=x or 1,Y=y or 1,Z=z or 1},changed=signal()}
 function h:IsA(kind)return kind=='BasePart'end
 function h:GetPropertyChangedSignal(key)assert(key=='Size')return self.changed end
 function h:Resize(x,y,z)self.Size={X=x,Y=y,Z=z} self.changed:Fire()end
 return h
end
local function character(rig,missing)
 local c={ChildAdded=signal(),ChildRemoved=signal(),children={}}
 function c:FindFirstChild(name)return self.children[name]end
 function c:GetChildren()local result={}for _,v in pairs(self.children)do table.insert(result,v)end return result end
 function c:Add(h)self.children[h.Name]=h h.Parent=self self.ChildAdded:Fire(h)end
 function c:Remove(h)self.children[h.Name]=nil h.Parent=nil self.ChildRemoved:Fire(h)end
 if not missing then c:Add(hand(rig=='R6' and 'Right Arm' or 'RightHand')) c:Add(hand(rig=='R6' and 'Left Arm' or 'LeftHand')) end
 return c
end
local player={CharacterAdded=signal(),CharacterRemoving=signal()}
local gui={SetAttribute=function()end}
local shared={PunchWallResetCameraGeometryGuard=function()end}
local punchMotionState,activePunchCamera
local latestStats={EquippedFist='Titan Gauntlet',EquippedPetsJSON='[]',EquippedHonorItem='None'}
local function decodeJSON()return {}end
local currentGauntlet local visualSignature='' local rebuilds,retries=0,0
local companionRuntime={CancelVisualRetry=function()end,ScheduleVisualRetry=function()retries+=1 end}
function companionRuntime.BuildItemMatchedGauntlet(name)
 local c=player.Character local h=c and (c:FindFirstChild('RightHand')or c:FindFirstChild('Right Arm'))
 if not h then return false end
 rebuilds+=1
 currentGauntlet={Parent=c,hand=h,name=name,size={X=h.Size.X,Y=h.Size.Y,Z=h.Size.Z}}
 return true
end
local refreshCharacterVisuals
${observer}
${refresh}
${lifecycle}
local function spawn(c)player.Character=c player.CharacterAdded:Fire(c)advance(.06)end
`;
const fixtures = {
  growth: `${setup}
local c=character('R15') spawn(c)
local right,left=c:FindFirstChild('RightHand'),c:FindFirstChild('LeftHand')
check(rebuilds==1,'initial_refreshes_coalesce_through_signature')
local state=companionRuntime.handSizeObserver
if companionRuntime.ObserveCharacterHandSizes then companionRuntime.ObserveCharacterHandSizes(c) end
check(companionRuntime.handSizeObserver==state,'same_character_binding_is_idempotent')
local foot=hand('RightFoot')c:Add(foot)foot:Resize(5,5,5)advance(.06)
check(foot.changed:Count()==0 and rebuilds==1,'unrelated_body_parts_do_not_schedule_refresh')
right:Resize(1.05,1.08,1.02) right:Resize(1.08,1.1,1.04) left:Resize(1.08,1.1,1.04)
advance(.06)
check(currentGauntlet.size.X==1.08 and currentGauntlet.size.Y==1.1,'late_growth_refreshes_actual_hand_dimensions')
check(rebuilds==2,'both_hand_resize_burst_builds_once')
check(currentGauntlet.name=='Titan Gauntlet','growth_preserves_equipped_identity')
left:Resize(1.08,1.2,1.04) advance(.06)
check(rebuilds==3,'left_hand_size_participates_in_signature')
advance(2) check(rebuilds==3 and #queue==0,'idle_has_no_scheduled_rebuild_loop')
right.changed:Fire()left.changed:Fire()advance(.06)
check(rebuilds==3,'unchanged_size_events_do_not_rebuild')
for index=1,100 do right:Resize(1+index/100,1,1)left:Resize(1+index/100,1,1)end
advance(.06)
check(rebuilds==4 and currentGauntlet.size.X==2,'large_scale_burst_coalesces_to_final_dimensions')
print('PASS '..checks)
`,
  replacement: `${setup}
local c=character('R6')spawn(c)
local old=c:FindFirstChild('Right Arm')local replacement=hand('Right Arm')
c:Remove(old)c:Add(replacement)advance(.06)
check(currentGauntlet.hand==replacement,'same_size_replacement_rebinds_equipment')
check(old.changed:Count()==0 and replacement.changed:Count()==1,'old_hand_signal_is_released')
check(rebuilds==2,'replacement_burst_builds_once')
c:Remove(replacement)advance(.06)
check(retries>=1,'missing_hand_uses_existing_retry_path')
local late=hand('Right Arm',.7,.8,.6)c:Add(late)advance(.06)
check(currentGauntlet.hand==late and currentGauntlet.size.X==.7,'late_hand_creation_recovers_real_attachment')
print('PASS '..checks)
`,
  missingAndLifecycle: `${setup}
local c=character('R15',true)spawn(c)
check(rebuilds==0 and retries>=1,'initial_missing_hands_do_not_fake_readiness')
c:Add(hand('RightHand',.7,.8,.6))c:Add(hand('LeftHand',.7,.8,.6))advance(.06)
check(rebuilds==1 and currentGauntlet.size.X==.7,'initial_late_hands_build_once')
local state=companionRuntime.handSizeObserver
local right=c:FindFirstChild('RightHand')local left=c:FindFirstChild('LeftHand')
right:Resize(.9,.9,.9)
player.CharacterRemoving:Fire(c)
check(companionRuntime.handSizeObserver==nil,'removal_releases_active_observer')
local nextCharacter=character('R6')spawn(nextCharacter)
local nextState=companionRuntime.handSizeObserver local before=rebuilds
advance(.2)
check(currentGauntlet.Parent==nextCharacter and currentGauntlet.hand==nextCharacter:FindFirstChild('Right Arm'),'pending_old_callback_cannot_mutate_new_character')
check(rebuilds==before,'pending_old_generation_does_not_rebuild_new_character')
check(nextState.generation>state.generation,'new_character_uses_new_generation')
check(c.ChildAdded:Count()==0 and c.ChildRemoved:Count()==0 and right.changed:Count()==0 and left.changed:Count()==0,'all_old_character_and_hand_connections_disconnected')
right.changed:FireAll()left.changed:FireAll()c.ChildAdded:FireAll(hand('RightHand',9,9,9))advance(.2)
check(rebuilds==before and companionRuntime.handSizeObserver==nextState,'stale_delivered_callbacks_cannot_resurrect_old_observer')
player.CharacterRemoving:Fire(c)
check(companionRuntime.handSizeObserver==nextState,'late_old_character_removal_preserves_new_observer')
nextCharacter:FindFirstChild('Right Arm'):Resize(1.2,1,1)
player.CharacterRemoving:Fire(nextCharacter)player.Character=nil advance(.2)
check(companionRuntime.handSizeObserver==nil and rebuilds==before,'final_removal_cancels_queued_size_refresh')
print('PASS '..checks)
`,
};
const expectedFailures = { growth: "late_growth_refreshes_actual_hand_dimensions", replacement: "same_size_replacement_rebinds_equipment" };
const temp = fs.mkdtempSync(path.join(tempRoot, "smash-fist-growth-contract-"));
const results = {};
try {
  for (const [name, fixture] of Object.entries(fixtures)) {
    if (baseline && !(name in expectedFailures)) continue;
    const file = path.join(temp, `${name}.luau`);fs.writeFileSync(file, fixture);
    const result = spawnSync(luau, [file], { encoding: "utf8", timeout: 15000 });
    const output = `${result.stdout || ""}${result.stderr || ""}`;
    if (baseline) {
      assert.ok(result.status !== 0 && output.includes(expectedFailures[name]), `${name}: expected ${expectedFailures[name]}: ${output}`);
      results[name] = { reproduced: expectedFailures[name] };
    } else {
      assert.equal(result.status, 0, `${name}: ${output}`);
      results[name] = { passed: Number(output.match(/PASS (\d+)/)?.[1] || 0) };
    }
  }
  console.log(JSON.stringify({ ok: true, mode: baseline ? `baseline ${baseline}` : "current source", luau, results }, null, 2));
} finally {
  for (const name of Object.keys(fixtures)) { const file = path.join(temp, `${name}.luau`);if (fs.existsSync(file)) fs.unlinkSync(file); }
  fs.rmdirSync(temp);
}
