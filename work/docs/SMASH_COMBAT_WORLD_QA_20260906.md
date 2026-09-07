# Combat and world QA fixture repair — 2026-09-06

Scope: eight automation flows only, authored against immutable source commit `0e6c0b5` in `codex/test/smash-combat-world-qa-20260906`. No gameplay, economy, asset, Studio, registry, or shared contract edits. The Coordinator owns integration and actual Studio regression.

## Findings and resulting checks

| Flow | Original failure or latent fixture defect | Current verification |
| --- | --- | --- |
| `punchwall-free-aim-combat-polish` | Removed `WallValue` caused nil access; old 30px maxima and scale limits no longer match the live number areas. | `DepthValue`, exact 26/26/27 maxima, positive visible text, rendered text and value rectangles inside their real artwork masks. Existing free aim, audio, cooldown and camera presentation checks remain. |
| `punchwall-hybrid-physics-lunge` | A delayed call expected rubble to remain unanchored after the server had correctly settled it. | Observe actual displacement while unanchored and server owned in the same punch call; then require real support, zero velocities, settled flags, released physics slot, persistent visible collision/query geometry. Finishing hit still must remove only the target and award the existing result. |
| `punchwall-radius-damage-shake` | Current successful sweep returns `penetration`, including low-power punches; `radius` is retired. | Preserve directional miss, bounded affected count, primary break, weaker surviving neighbors, exact configured effective damage multiplied by each recorded radius scale, untouched HP outside the sweep, and tough-block vibration/restoration. This checks the observed scale and applied damage; it does not independently reconstruct the server overlap query. |
| `punchwall-shared-excavation-field` | First material is 8 HP and all ten material types are now distinct. | Exact current 5,400-block field/material/HP matrix; 7 raw Power deals 7.007 damage, leaving 0.993 HP with its neighbor unchanged; retain shared hole, passage, client replication, level gate and rewards. The existing passage command and snapshot are unchanged. |
| `punchwall-train-and-break` | Start-training instant +4 is retired. | Start gives zero; wait for the first payout serial, require exact configured rate per consumed interval, stop and verify no later gain or lock; then preserve coin-only wall reward checks. |
| `punchwall-motion-feedback` | Retired start sequence expected `Train`, then `TrainingState`. | Current start emits exactly one `TrainingState` for `Rookie Power Bag`; scheduled ticks deliberately call the grant function with feedback disabled. Capture that fresh bounded toast at the real event, serialize evidence, verify actual first payout, exact replicated ongoing Power and no tick feedback/reward leak. Existing real reward, shop, fixture pet grant, rebirth and boss checks remain. |
| `training-lock-motion-feedback` | A fixed 1.25-second wait can precede the first due payout because the global scheduler samples every second. | Bounded polling for a real payout serial, exact rate/interval checks, upright grounded bag, impact/shake/movement lock, visible exit, restored movement and no post-stop payout. |
| `training-station-progression` | Raw threshold minus one can already qualify with the baseline 1.001 mastery multiplier. | Compute adjacent rejected/accepted integer raw Power using the actual `GameConfig.EffectivePower`, verify the replicated qualification, denial without any session/payout, and the first qualifying raw Power with no instant gain. Existing four-station rates, switch/idempotency, HUD, reset, stop, offline cap, respawn and live growth checks remain. |

The exact adjacent boundary pairs are 1,498/1,499, 149,850/149,851 and 14,985,014/14,985,015 raw Power for the 1,500, 150,000 and 15,000,000 effective Power thresholds. These are calculated fixtures, not measured player progression times.

Every flow checks Studio, one isolated player, ready `EphemeralStudio` profile, nonwritable profile state, and both world/ServerStorage live-data opt-ins before its first destructive fixture reset or stat seed.

Source references: `GameConfig.lua` effective Power and wall catalog; `PunchWallBootstrap.server.lua` lines 4580, 4725, 5086, 5187, 5737, 5776 and 10248; `PunchWallClient.client.lua` dynamic number areas around line 9938. Source SHA-256 values:

- GameConfig: `083d3b49645a906cb5a45a80462311dd826521b2ef3eac7b4cc2af850ec3597e`
- Server: `29aa43e672c3e691dfb63f3c24d48f45d01b1c7e248e98b60fb48b318855d3df`
- Client: `581172ad89287266c1f6228b1df5330ab169f813db957aac10e25f7525cbcb52`

## Validation

PASS: all 62 embedded Luau chunks compile; 92 executed controls pass (25 payout, 24 feedback, 8 ephemeral profile, 11 production math, 10 HUD containment and 14 rubble bounce), and all 13 deliberate guard weakenings are caught. `git diff --check` passes. The block reads the exact checked-in flow helpers and current production math, compiles all flow chunks in memory, executes valid and invalid controls, and confirms weakened guards are caught. Mocked helpers verify predicates; they do not prove live Roblox rendering, physics or remote ordering.

**Studio regression: BLOCKED / pending Coordinator run.** No live result is claimed here. In particular, final combined integration must verify actual physics settlement, real scheduler timing, event capture, mobile/desktop text bounds and any subsequent combat HUD source change. The existing target-HUD-disabled assertions describe this immutable base and require review if the separate HUD restoration changes that behavior.

Run the following Node block from this worktree root (Luau 0.737 path can be supplied with `LUAU_QA_EXE`). It writes no files.

```javascript
const fs = require('fs');
const cp = require('child_process');
const path = require('path');
const assert = require('assert/strict');
const luau = process.env.LUAU_QA_EXE || 'C:/Users/Jennarong Pinjai/AppData/Local/Temp/codex-luau-smash-0.737/luau.exe';
const names = ['punchwall-free-aim-combat-polish','punchwall-hybrid-physics-lunge','punchwall-radius-damage-shake','punchwall-shared-excavation-field','punchwall-train-and-break','punchwall-motion-feedback','training-lock-motion-feedback','training-station-progression'];
const flows = Object.fromEntries(names.map(n => [n, JSON.parse(fs.readFileSync(path.join('work/automation/flows', n+'.json'), 'utf8'))]));
const chunks = Object.values(flows).flatMap(f => f.steps.filter(s => s.args?.code).map(s => s.args.code));
function execute(code, marker) {
  let input = 'QAChunk=""\n';
  for (let i=0;i<code.length;i+=200) input += 'QAChunk=QAChunk..'+JSON.stringify(code.slice(i,i+200))+'\n';
  input += 'assert(loadstring(QAChunk))()\n';
  const r = cp.spawnSync(luau, [], {input, encoding:'utf8', maxBuffer:2*1024*1024});
  return {ok:r.status===0 && !r.stderr && r.stdout.includes(marker) && !/stdin:|stack backtrace|SyntaxError/.test(r.stdout), stdout:r.stdout, stderr:r.stderr};
}
function run(code, marker='QA_PASS') {
  const r=execute(code+'\nprint("'+marker+'")', marker);
  assert(r.ok, r.stdout+'\n'+r.stderr);
}
function helper(flow, start, end) {
  const code=flows[flow].steps.find(s => s.args?.code?.includes(start)).args.code;
  const from=code.indexOf(start), to=code.indexOf(end,from);
  assert(to>from, 'helper boundary missing'); return code.slice(from,to);
}
run(chunks.map((c,i)=>'assert(loadstring('+JSON.stringify(c)+'),"chunk '+i+'")').join('\n'),'COMPILE_ALL_PASS');
const payout=helper('punchwall-train-and-break','local function verifyTrainingPayout','local H=');
for(const n of ['punchwall-motion-feedback','training-lock-motion-feedback']) assert.equal(helper(n,'local function verifyTrainingPayout','local H='),payout);
const ledger=`local checks={}
local function check(ok,label) assert(ok,label) checks[#checks+1]=label end
local function rejected(fn,label) check(not pcall(fn),label) end
local function copy(t) local c={} for k,v in pairs(t) do c[k]=v end return c end
`;
const payoutControls=`
local before={Power=15,payoutSerial=0,sessionGeneration=0}
local immediate={Power=15,payoutSerial=0,sessionGeneration=1,sessionTickCount=0,active=true,movementLocked=true,tickAnchor=100}
local after={Power=19,payoutSerial=1,sessionGeneration=1,sessionTickCount=1,lastTickBatch=1,lastGrant=4,gainPerSecond=4,tickAnchor=101,active=true,movementLocked=true}
for _,rate in ipairs({4,40,1200,50000}) do for ticks=1,2 do
 local a=copy(after) a.Power=15+rate*ticks a.sessionTickCount=ticks a.lastTickBatch=ticks a.lastGrant=rate*ticks a.gainPerSecond=rate a.tickAnchor=100+ticks
 check(verifyTrainingPayout(before,immediate,a,rate,1),'valid configured rate/batch')
end end
for _,mutation in ipairs({
 {'immediate','Power',19},{'immediate','payoutSerial',1},{'immediate','sessionTickCount',1},{'immediate','sessionGeneration',2},{'immediate','active',false},{'immediate','movementLocked',false},
 {'after','sessionTickCount',0},{'after','sessionTickCount',3},{'after','sessionTickCount',1.5},{'after','payoutSerial',2},{'after','lastTickBatch',2},{'after','Power',23},{'after','lastGrant',8},{'after','gainPerSecond',8},{'after','tickAnchor',102},{'after','active',false},{'after','movementLocked',false}
}) do
 local i,a=copy(immediate),copy(after) local target=mutation[1]=='immediate' and i or a target[mutation[2]]=mutation[3]
 rejected(function() verifyTrainingPayout(before,i,a,4,1) end,'reject '..mutation[1]..'.'..mutation[2])
end
assert(#checks==25,'payout control ledger')
`;
run(ledger+payout+payoutControls);
let mutations=0;
function weakening(original, replacement, controls, prefix=ledger) {
 assert.notEqual(original,replacement,'weakening edit not found');
 const result=execute(prefix+replacement+controls+'\nprint("MUTANT_SURVIVED")','MUTANT_SURVIVED');
 assert(!result.ok,'a weakened guard survived all negative controls'); mutations++;
}
for(const message of ['training paid before a scheduled tick','duplicate or unaccounted payout batch','training rate differs from the server station configuration','payout did not consume exactly its scheduled intervals']) {
 const line=payout.split('\n').find(l=>l.includes(message)); assert(line);
 weakening(payout,payout.replace(line,' -- removed one guard for negative-control validation'),payoutControls);
}
const feedback=helper('punchwall-motion-feedback','local function verifyTrainingFeedback','local raw=');
const feedbackControls=`
local function fresh()
 return {captured=true,events={{type='TrainingState',target='Rookie Power Bag',active=true,stationId='rookie_bag',gain=4}},expectedTarget='Rookie Power Bag',rate=4,feedbackBefore=10,feedbackAfter=11,lastType='TrainingState',lastTarget='Rookie Power Bag',toastBefore=7,rewardBefore=5,toasts={mode='BoundedVisibleQueueV1',cap=3,count=1,bounded=true,sequence=8,text='Rookie Power Bag'},rewards={mode='BoundedVisibleQueueV1',cap=3,bounded=true,sequence=5}}
end
check(verifyTrainingFeedback(fresh()),'valid one-event start')
local changes={
 function(e)e.captured=false end,function(e)e.events={} end,function(e)e.events[2]=e.events[1] end,
 function(e)e.events[1].type='Train' end,function(e)e.events[1].target='TRAINING' end,function(e)e.events[1].active=false end,function(e)e.events[1].stationId='iron_dummy' end,function(e)e.events[1].gain=8 end,
 function(e)e.feedbackAfter=10 end,function(e)e.feedbackAfter=12 end,function(e)e.lastType='Train' end,function(e)e.lastTarget='old toast' end,
 function(e)e.toasts.mode='unbounded' end,function(e)e.toasts.cap=4 end,function(e)e.toasts.count=0 end,function(e)e.toasts.count=2 end,function(e)e.toasts.bounded=false end,function(e)e.toasts.sequence=7 end,function(e)e.toasts.text='wrong' end,
 function(e)e.rewards.mode='unbounded' end,function(e)e.rewards.cap=4 end,function(e)e.rewards.bounded=false end,function(e)e.rewards.sequence=6 end}
for i,change in ipairs(changes) do local e=fresh() change(e) rejected(function()verifyTrainingFeedback(e)end,'reject feedback '..i) end
assert(#checks==24,'feedback control ledger')
`;
run(ledger+feedback+feedbackControls);
for(const message of ['training start must present exactly one feedback event','start toast is duplicated, hidden, unbounded or wrong','training leaked a center reward presentation']) {
 const line=feedback.split('\n').find(l=>l.includes(message)); assert(line);
 weakening(feedback,feedback.replace(line,' -- removed one guard for negative-control validation'),feedbackControls);
}
const guard=helper('punchwall-train-and-break','local function verifyEphemeralSeed'," assert(game:GetService('RunService')");
const guardControls=`
local function node(attrs) return {GetAttribute=function(_,key)return attrs[key]end} end
local function fresh() return {ProfileReady=true,ProfilePersistenceState='EphemeralStudio',ProfileWritable=false},{PersistenceMode='EphemeralStudio',PersistenceStudioDefaultEphemeral=true,PersistenceStudioLiveDataOptIn=false},{} end
local p,w,s=fresh() check(verifyEphemeralSeed(node(p),node(w),node(s)),'valid ephemeral fixture')
for _,m in ipairs({{'p','ProfileReady',false},{'p','ProfilePersistenceState','Ready'},{'p','ProfileWritable',true},{'w','PersistenceMode','Live'},{'w','PersistenceStudioDefaultEphemeral',false},{'w','PersistenceStudioLiveDataOptIn',true},{'s','PunchWallAllowLiveDataStoreAccess',true}}) do
 p,w,s=fresh() local target=m[1]=='p' and p or m[1]=='w' and w or s target[m[2]]=m[3] rejected(function()verifyEphemeralSeed(node(p),node(w),node(s))end,'reject unsafe '..m[2])
end
assert(#checks==8,'guard control ledger')
`;
run(ledger+guard+guardControls);
const boundary=helper('training-station-progression','local function trainingBoundary','local H=');
const config=fs.readFileSync('work/punch-wall-rpg/src/shared/GameConfig.lua','utf8').replace(/\r/g,'');
function sourceFunction(name) { const from=config.indexOf('function GameConfig.'+name+'('); assert(from>=0); const to=config.indexOf('\nend',from); return config.slice(from,to+4)+'\n'; }
const mathSource='local GameConfig={Rebirth={MaxRebirths=250,BonusPerRebirth=.25}}\n'+sourceFunction('RebirthBonus')+sourceFunction('EffectivePower');
const mathControls=`
for _,case in ipairs({{1500,1498,1499},{150000,149850,149851},{15000000,14985014,14985015}}) do
 local low,first=trainingBoundary(GameConfig,case[1]) check(low==case[2] and first==case[3],'adjacent boundary')
 check(GameConfig.EffectivePower(low,1,0,0,1,0)<case[1] and GameConfig.EffectivePower(first,1,0,0,1,0)>=case[1],'actual production qualification')
 check(GameConfig.EffectivePower(case[1]-1,1,0,0,1,0)>=case[1],'old raw-minus-one fixture qualifies')
end
check(math.abs(8-GameConfig.EffectivePower(7,1,0,0,1,0)-.993)<1e-9,'starter surviving HP')
check(math.abs(900-GameConfig.EffectivePower(100,1,0,0,1,0)-799.9)<1e-9,'tough primary surviving HP')
assert(#checks==11,'math control ledger')
`;
run(ledger+mathSource+boundary+mathControls);
weakening(boundary,boundary.replace('return first-1,first','return required-1,required'),mathControls,ledger+mathSource);
const hud=helper('punchwall-free-aim-combat-polish','local function verifyHudValue','local hudSafe=');
const hudControls=`
local vec function vec(x,y)return setmetatable({X=x,Y=y},{__add=function(a,b)return vec(a.X+b.X,a.Y+b.Y)end})end
local function fresh()
 local value={Visible=true,AbsolutePosition=vec(10,20),AbsoluteSize=vec(40,30),Text='15',TextBounds=vec(25,20),limit={MaxTextSize=26}}
 function value:IsA(c)return c=='TextLabel'end function value:FindFirstChildOfClass(c)return c=='UITextSizeConstraint' and self.limit or nil end
 local mask={AbsolutePosition=vec(8,18),AbsoluteSize=vec(45,35)} function mask:IsA(c)return c=='GuiObject'end return value,mask
end
local v,m=fresh() check(verifyHudValue(v,m,26),'valid contained number')
for _,change in ipairs({function(v)v.Visible=false end,function(v)v.AbsoluteSize=vec(0,30)end,function(v)v.Text=''end,function(v)v.limit.MaxTextSize=30 end,function(v)v.AbsolutePosition=vec(3,20)end,function(v)v.AbsoluteSize=vec(50,30)end,function(v)v.TextBounds=vec(45,20)end,function(v)v.TextBounds=vec(25,40)end}) do
 v,m=fresh() change(v) rejected(function()verifyHudValue(v,m,26)end,'reject malformed HUD value')
end
rejected(function()verifyHudValue(nil,m,26)end,'missing value')
assert(#checks==10,'HUD control ledger')
`;
run(ledger+hud+hudControls);
for(const message of ['HUD number escaped its artwork mask','HUD text overflows its number area']) {const line=hud.split('\n').find(l=>l.includes(message));assert(line);weakening(hud,hud.replace(line,' -- removed one guard for negative-control validation'),hudControls);}
const bounce=helper('punchwall-hybrid-physics-lunge','local function verifyRubbleBounce','local H=');
const bounceControls=`
local result={ok=true,outcome='hit',detached=true}
local state={exactDamage=true,unanchoredAtImpact=true,serverOwnedAtImpact=true,fallingAtImpact=true,movedWhileUnanchored=.5,token=2,beforeToken=1,broken=false,visible=true,collidable=true,queryable=true}
check(verifyRubbleBounce(result,state),'valid server-owned bounce')
for _,m in ipairs({{'result','ok',false},{'result','outcome','broken'},{'result','detached',false},{'state','exactDamage',false},{'state','unanchoredAtImpact',false},{'state','serverOwnedAtImpact',false},{'state','fallingAtImpact',false},{'state','movedWhileUnanchored',0},{'state','token',1},{'state','broken',true},{'state','visible',false},{'state','collidable',false},{'state','queryable',false}}) do
 local r,s=copy(result),copy(state) local target=m[1]=='result' and r or s target[m[2]]=m[3] rejected(function()verifyRubbleBounce(r,s)end,'reject invalid rubble '..m[2])
end
assert(#checks==14,'rubble control ledger')
`;
run(ledger+bounce+bounceControls);
for(const message of ['rubble must receive exact damage under server-owned physics','rubble did not move under a fresh impulse','bouncing rubble disappeared or lost collision/query']) {const line=bounce.split('\n').find(l=>l.includes(message));assert(line);weakening(bounce,bounce.replace(line,' -- removed one guard for negative-control validation'),bounceControls);}
assert.equal(chunks.length,62); assert.equal(mutations,13);
console.log(JSON.stringify({compiledChunks:chunks.length,payoutControls:25,feedbackControls:24,ephemeralControls:8,productionMathControls:11,hudControls:10,rubbleControls:14,weakenedGuardsCaught:mutations,studio:'BLOCKED: Coordinator runtime pending'}));
```
