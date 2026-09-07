# Smash HUD consumer reconciliation — 2026-09-06

Owner: HQ agent-1. Isolated branch: codex/test/smash-hud-consumers-20260906, base 18abf72. Source is read-only; source SHA256 after LF normalization: 18396de92d7db099fb043e2ba0b48c673194d8293ab702a5275ca795a44121b2. Coordinator owns Studio, source integration, registry and combined runtime acceptance.

## Changes and evidence

- Updated iteration01–04 and free-aim consumers to compare actual displayName text separately from CombatHUDCanonicalTarget and the exact observed block name. The front material is Forest Stone / Brick Wall. HP text and fill come from actual replicated HP/MaxHP; approximate hits use the production GameConfig.EffectivePower formula and active damage-boost deadline. Mastery 1 produces fractional damage, so no invented exact 6/8 assumption remains.
- The old row-two fixtures were unanchored and could fall into row-one focus. Observation-only fixtures save/restore the original HumanoidRootPart.Anchored value through a serializable attribute. All actual free-aim punches, debris/reward checks and cooldown checks run before the free-aim observation fixture. Existing stop-play cleanup destroys fixtures on failure. No HP, identity or HUD attribute is fabricated.
- The old Iron observation point was inside earlier live layers. It now observes the actual Iron top-row block from the clear top face, with a real Depth Blocks raycast proving that no other live block intervenes. Normal wall/boss exclusivity and actual target identity remain required.
- Titan observation points use the unobstructed negative-Z side. Each server fixture asserts that every live depth block is more than 24 studs away and the actual boss is within 55 studs. Existing level 99/depth 75 gates, real phase-two damage, weak-point action and server countdown checks remain intact.
- iteration04's PowerCard expected base Power 123, although the production renderer uses EffectivePower. It now checks the actual replicated profile inputs through the shared production formula, including mastery/pet/rebirth/honor multipliers. Pet inventory, lock/delete, hatch rejection, hidden-egg pickup and training checks are preserved.
- Free aim retains facing, rewards, physics fragments, one-second action cooldown, animation, audio and actual value-mask bounds. Its obsolete expectation of zero Highlights and a permanently hidden wall HUD is replaced by a separate actual wall presentation check requiring exactly one owned Local Target Highlight with the correct Adornee. Other visual effects are not counted as target highlights.
- The Coordinator's DeviceSafeInsets change in iteration03 is preserved. All eight new wall/boss presentation consumers assert actual rendered text fits and actual HUD rectangle containment in the safe host.

Initial full-suite evidence under work/docs/evidence/smash-full-suite-20260906 records earlier obsolete artwork gates in iteration01–04; those were reconciled in db13ff8 before this assignment. That run could not establish the subsequent latent HUD title assumptions. The free-aim initial run reached visual/audio checks and failed an earlier nil Position access; the current base already contains the actual value/mask verifier, which is retained. This handoff does not claim that initial runtime failure was caused by the HUD title change.

## Countdown failure follow-up

Coordinator granted combat-target-boss-hud.json ownership after the integrated targeted run failed “HUD countdown disagrees with replicated deadline” in work/docs/evidence/smash-integrated-targeted2-20260906/combat-target-boss-hud.json. The evidence did not include the sampled subtitle, so the exact sampled value is unknown.

Source-grounded race: the boss loop starts the deadline asynchronously (up to one second after activation); the client HUD consumes attributes on its 0.15-second scan. The old wait could see BossHUD.Visible and the newly replicated NextAttackAt while the text still showed idle guidance or the previous attack. The revised bounded wait requires the actual parsed subtitle and current deadline to agree within the same original one-second tolerance, with more than three seconds remaining. It records subtitle/deadline/server clock/parsed seconds/expected seconds/render count/kind on failure. The independent subsequent 1.25-second changing-text and 1–3 render-write checks are unchanged. No gameplay action is retried and the countdown tolerance is not widened. iteration02/03 use the same bounded consumption observation before their actual static phase/HP/deadline assertions.

## Verification

- PASS: all 81 Luau chunks across the six owned flows compile with official Luau 0.737.
- PASS: 55 executable assertions using the exact new flow verifier, exact new deadline readiness predicate, production HUD Resolve, production EffectivePower/RebirthBonus and the exact replicated-profile reader.
- PASS: five semantic mutations rejected: wrong title, HP fill, outline, canonical identity and removed deadline consumption gate. Negative cases also reject missing/duplicate outlines, wrong target, old title, wrong HP/hits, stale boss phase/countdown, hidden/overlapping owners, clipped text/bounds and out-of-range targets.
- PASS: all eight runtime consumers contain the same strict extracted verifier.
- PASS: existing combat-target-boss-hud-contract.mjs — 382 production behavioral assertions, eight semantic mutations, full client plus 17 dedicated runtime-flow chunks compile, and scan/event wiring.
- PASS: git diff --check.
- BLOCKED pending Coordinator: actual Studio execution of all six changed flows and combined regression. Offline controls cannot establish engine rendering, frame scheduling, replica arrival, physical aim or device layout. No Studio calls or source edits were made in this task.

## Reproduce the focused offline controls

Run the existing durable production contract from the task root:

~~~powershell
node work/automation/scripts/combat-target-boss-hud-contract.mjs
~~~

Save the JavaScript block below as a temporary .cjs file and execute it with Node from the repository root. It reads the owned flows and production source, writes only temporary Luau programs, and invokes official local Luau tools; it never contacts Studio.

```javascript
const fs=require('fs'),os=require('os'),path=require('path'),assert=require('assert/strict'),{spawnSync}=require('child_process');
const root=process.cwd();
const dir=path.join(os.tmpdir(),'codex-luau-smash-0.737');
const exe=path.join(dir,'luau.exe'),compiler=path.join(dir,'luau-compile.exe');
const names=['iteration01-complete-polish','iteration02-companion-tasks-boss','iteration03-safearea-destruction','iteration04-armory-pets-feedback','punchwall-free-aim-combat-polish','combat-target-boss-hud'];
const temp=fs.mkdtempSync(path.join(os.tmpdir(),'smash-hud-consumers-check-'));
const flows=names.map(n=>JSON.parse(fs.readFileSync(path.join(root,'work/automation/flows',n+'.json'),'utf8')));
let chunks=0;for(const f of flows)for(const s of [...f.steps,...(f.cleanup||[])]){if(!s.args?.code)continue;const p=path.join(temp,`chunk-${chunks++}.luau`);fs.writeFileSync(p,s.args.code);const r=spawnSync(compiler,[p],{encoding:'utf8'});assert.equal(r.status,0,`${f.name}/${s.label}: ${r.stderr}`);}
console.log('PASS '+chunks+' modified-flow Luau chunks compile');
const body=flows[0].steps.find(s=>s.args?.code?.includes('local function verifyCombatPresentation')).args.code;
const cut=(s,a,b)=>{const x=s.indexOf(a),y=s.indexOf(b,x+a.length);assert(x>=0&&y>x);return s.slice(x,y);};
const fmt=cut(body,'local function combatNumber','local function verifyCombatPresentation');
const verify=cut(body,'local function verifyCombatPresentation','local function replicatedPower');
let copies=0;for(const f of flows.slice(0,5))for(const s of f.steps){if(!s.args?.code?.includes('local function verifyCombatPresentation'))continue;const end=s.args.code.includes('local function replicatedPower')?'local function replicatedPower':'local function observeCombatHUD';assert.equal(cut(s.args.code,'local function verifyCombatPresentation',end),verify);copies++;}
assert.equal(copies,8);console.log('PASS all '+copies+' actual wall/boss consumers use the same strict verifier');
const source=fs.readFileSync(path.join(root,'work/punch-wall-rpg/src/client/PunchWallClient.client.lua'),'utf8').replace(/\r\n/g,'\n');
const resolve=cut(source,'function shared.PunchWallCombatHUD.Resolve','function shared.PunchWallCombatHUD.FindLayout');
const number=cut(source,'local function formatNumber(value)','for index, key in ipairs(order)');
const boss=flows[5].steps.find(s=>s.label==='actual boss HP countdown control clearance and menu ownership').args.code;
const ready=cut(boss,'awaitCondition(function()\n local nextAt','end,function()return').replace('awaitCondition(function()','local function ready()')+'end\n';
const tests=String.raw`
local checks=0
local function check(v,m) assert(v,m) checks+=1 end
local function expectedWall(hp,power)
 return {kind='Wall',target='DepthBlock_L001_C06_R02',canonical='Brick Wall',title='FOREST STONE',fill=hp/8,hpText='HP '..combatNumber(hp)..'/8',hits=math.ceil(hp/power)}
end
local function observedPresentation(p)
 return {kind=p.kind,target=p.target,canonical=p.canonical,title=p.title,detail=p.detail,fill=p.ratio,hits=p.hits,wallVisible=p.kind=='Wall',bossVisible=p.kind=='Boss',outlineCount=1,outlineEnabled=p.kind=='Wall',outlineTarget=p.kind=='Wall' and p.target or '',distance=8,textFits=true,safeBounds=true}
end
local function state()
 return {ready=true,blocked=false,now=100,damageBoostExpiresAt=0,power=2,level=25,wall={valid=true,broken=false,hp=5.998,maxHP=8,distance=8,facing=1,title='Forest Stone',name='DepthBlock_L001_C06_R02',canonical='Brick Wall',requiredLevel=1},boss={valid=true,broken=false,hp=320000000,maxHP=600000000,distance=19,name='Titan Server Wall',phase=2,nextAttackAt=107}}
end
local s=state() local actual=observedPresentation(shared.PunchWallCombatHUD.Resolve(s)) local expected=expectedWall(5.998,2)
check(verifyCombatPresentation(actual,expected),'valid partial wall rejected')
for _,entry in ipairs({{'kind','Boss'},{'target','wrong'},{'canonical','wrong'},{'title','BRICK WALL'},{'fill',1},{'hits',99},{'detail','HP 8/8  |  ~3 hits'},{'detail','HP 6/8  |  ~99 hits'},{'wallVisible',false},{'bossVisible',true},{'outlineCount',0},{'outlineCount',2},{'outlineEnabled',false},{'outlineTarget','stale'},{'distance',24.01},{'textFits',false},{'safeBounds',false}}) do local bad=table.clone(actual) bad[entry[1]]=entry[2] check(not pcall(verifyCombatPresentation,bad,expected),'unsafe wall accepted: '..entry[1]) end
for _,entry in ipairs({{8,2,0},{5.998,2.002,0},{5.998,2.002,101},{.2,1000,0}}) do local v=state() v.wall.hp=entry[1] v.power=entry[2] v.damageBoostExpiresAt=entry[3] local p=shared.PunchWallCombatHUD.Resolve(v) local damage=v.power*(v.damageBoostExpiresAt>v.now and 2 or 1) check(verifyCombatPresentation(observedPresentation(p),expectedWall(v.wall.hp,damage)),'power/boost estimate disagreement') end
s.wall=nil actual=observedPresentation(shared.PunchWallCombatHUD.Resolve(s)) expected={kind='Boss',target='Titan Server Wall',canonical='Titan Server Wall',title='TITAN P2  |  WEAK x1.5',fill=320/600,hpText='HP 320.0M/600.0M',countdown=7}
check(verifyCombatPresentation(actual,expected),'valid boss rejected')
for _,entry in ipairs({{'title','TITAN P1  |  WEAK x1.5'},{'fill',1},{'detail','HP 600.0M/600.0M  |  SHOCKWAVE 7s'},{'detail','HP 320.0M/600.0M  |  SHOCKWAVE 4s'},{'detail','HP 320.0M/600.0M  |  TARGET RED CORES'},{'detail','HP 320.0M/600.0M garbage  |  SHOCKWAVE 7s'},{'outlineEnabled',true},{'outlineTarget','stale'},{'wallVisible',true},{'bossVisible',false},{'distance',55.01},{'safeBounds',false}}) do local bad=table.clone(actual) bad[entry[1]]=entry[2] check(not pcall(verifyCombatPresentation,bad,expected),'unsafe boss accepted: '..entry[1]) end
for _,n in ipairs({6,7,8}) do local v=table.clone(actual) v.detail='HP 320.0M/600.0M  |  SHOCKWAVE '..n..'s' check(verifyCombatPresentation(v,expected),'one-scan clock boundary rejected') end
s.boss.nextAttackAt=0 s.boss.phase=1 actual=observedPresentation(shared.PunchWallCombatHUD.Resolve(s)) expected.title='TITAN P1  |  WEAK x1.5' expected.countdown=nil check(verifyCombatPresentation(actual,expected),'idle boss rejected') actual.detail='HP 320.0M/600.0M  |  SHOCKWAVE 0s' check(not pcall(verifyCombatPresentation,actual,expected),'idle stale countdown accepted')
-- Execute the exact added runtime wait predicate against replication/render ordering.
local function readiness(nextAt,now,text,visible)
 boss.nextAt=nextAt workspace.now=now g.BossHUD.BossSubtitle.Text=text g.BossHUD.Visible=visible
 return ready()
end
check(not readiness(107,100,'HP 320.0M/600.0M  |  TARGET RED CORES',true),'new deadline with old idle subtitle accepted')
check(not readiness(107,100,'HP 320.0M/600.0M  |  SHOCKWAVE 0s',true),'previous attack subtitle accepted')
for _,n in ipairs({6,7,8}) do check(readiness(107,100,'HP 320.0M/600.0M  |  SHOCKWAVE '..n..'s',true),'coherent rendered deadline rejected') end
check(not readiness(107,100,'SHOCKWAVE 5s',true),'wide tolerance accepted')
check(not readiness(107,100,'SHOCKWAVE 9s',true),'wide tolerance accepted')
check(not readiness(107,100,'SHOCKWAVE 7s',false),'hidden countdown accepted')
check(not readiness(103,100,'SHOCKWAVE 3s',true),'insufficient independent countdown window accepted')
check(not readiness(0,100,'SHOCKWAVE 0s',true),'unarmed deadline accepted')
check(observed.nextAttackAt==0 and observed.serverNow==100 and observed.remaining==0 and observed.kind=='Boss','missing actual diagnostic capture')
local profile={leaderstats={values={Power=123,Rebirths=0}},RPGStats={values={FistMultiplier=1,PetMultiplier=0,FistMastery=50,HonorPowerBonus=0}}}
for _,folder in ipairs({profile.leaderstats,profile.RPGStats}) do function folder:FindFirstChild(k) local value=self.values[k] return value~=nil and {Value=value} or nil end end
check(math.abs(replicatedPower(profile,GameConfig)-129.15)<.00001,'actual mastery formula disagrees')
check(combatNumber(replicatedPower(profile,GameConfig))=='129','old base-power 123 fixture incorrectly accepted')
profile.RPGStats.values.PetMultiplier=1.85 check(math.abs(replicatedPower(profile,GameConfig)-368.0775)<.00001,'actual duplicate-pet multiplier formula disagrees')
profile.leaderstats.values.Rebirths=1 check(math.abs(replicatedPower(profile,GameConfig)-460.096875)<.00001,'actual rebirth formula disagrees')
print('PASS '..checks..' extracted production/consumer/readiness assertions')
`;
const mocks=`local shared={PunchWallCombatHUD={}}\nlocal boss={nextAt=107} function boss:GetAttribute(k)return self.nextAt end\nlocal workspace={now=100} function workspace:GetServerTimeNow()return self.now end\nlocal g={BossHUD={Visible=true,BossSubtitle={Text=''}}} function g:GetAttribute(k)return k=='CombatHUDKind' and 'Boss' or 1 end\nlocal observed\n`;
const run=(text,name)=>{const p=path.join(temp,name+'.luau');fs.writeFileSync(p,text);return spawnSync(exe,[p],{encoding:'utf8'});};
const config=fs.readFileSync(path.join(root,'work/punch-wall-rpg/src/shared/GameConfig.lua'),'utf8').replace(/\r\n/g,'\n');
const formula='local GameConfig={}\n'+cut(config,'GameConfig.Rebirth =','function GameConfig.RebirthRequirement')+cut(config,'function GameConfig.EffectivePower','GameConfig.Pets =');
const power=cut(body,'local function replicatedPower','local function observeCombatHUD');
const prefix=mocks+number+resolve+fmt+verify+ready+formula+power;
let result=run(prefix+tests,'consumer-controls');assert.equal(result.status,0,result.stderr||result.stdout);console.log(result.stdout.trim());
const mutations=[['title',"assert(actual.title==expected.title",'assert(true'],['HP',"assert(math.abs(actual.fill-expected.fill)<.001",'assert(true'],['outline',"assert(actual.outlineEnabled and actual.outlineTarget==expected.target",'assert(true'],['canonical',"actual.canonical==expected.canonical",'true'],['countdown readiness','and seconds~=nil and math.abs(seconds-expected)<=1','']];
for(const [name,a,b] of mutations){assert(prefix.includes(a));const result=run(prefix.replace(a,b)+tests,'mutant');assert.notEqual(result.status,0,'survived '+name);assert(!result.stderr.includes('SyntaxError'),'syntax-only '+name);}
console.log('PASS '+mutations.length+' semantic verifier/readiness mutations rejected');
console.log('Evidence temp: '+temp);
```
