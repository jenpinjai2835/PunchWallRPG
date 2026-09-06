import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../..');
const flowPath = 'work/automation/flows/release-expansion-economy.json';
const serverPath = 'work/punch-wall-rpg/src/server/PunchWallBootstrap.server.lua';
const read = relative => fs.readFileSync(path.join(root, relative), 'utf8').replace(/\r\n?/g, '\n');
const flow = JSON.parse(read(flowPath));
const source = read(serverPath);
const config = read('work/punch-wall-rpg/src/shared/GameConfig.lua');
const label = 'spin grants weighted reward and bonus credits';
const step = flow.steps.find(item => item.label === label);
assert(step?.args?.code, 'Missing real release spin step');
function between(text, start, end) {
  const from = text.indexOf(start), to = text.indexOf(end, from + start.length);
  assert(from >= 0 && to > from, `Missing exact production boundary: ${start}`);
  return text.slice(from, to);
}
const verifier = between(step.args.code, 'local function verifySpinCreditLedger(', '\nlocal H=');
const spinProducer = between(source, 'local function spinReward(player)', '\nlocal function claimQuest');
const grantProducer = between(source, 'shared.PunchWallPremiumProducts.grant = function(', '\nshared.PunchWallPremiumProducts.prompt =');
const spinCatalog = between(config, 'GameConfig.Spin = {', '\nGameConfig.DepthWall =');
const productsCatalog = between(config, 'GameConfig.PremiumProducts = {', '\nGameConfig.Honor =');
let sourceChecks = 0;
function check(condition, name) { assert(condition, name); sourceChecks++; }
const baseline = spawnSync('git', ['show', `6211b00:${flowPath}`], {cwd: root, encoding: 'utf8'});
assert.equal(baseline.status, 0, baseline.stderr);
const oldFlow = JSON.parse(baseline.stdout);
check(flow.steps.length === oldFlow.steps.length, 'Keep the original step count');
for (let index = 0; index < flow.steps.length; index++) {
  if (flow.steps[index].label !== label) assert.deepEqual(flow.steps[index], oldFlow.steps[index], `Unrelated step changed: ${index}`);
}
sourceChecks++;
assert.deepEqual(flow.cleanup, oldFlow.cleanup); sourceChecks++;
check(step.args.datamodel_type === 'Server', 'Observe actual server balances');
check(step.expectRegex.includes('"packCredits"\\s*:\\s*3'), 'Require exact three-credit pack delta');
check(!step.expectRegex.includes('"credits"\\s*:\\s*3'), 'Do not confuse final balance with pack delta');
check(step.args.code.indexOf('strict ephemeral fixture required') < step.args.code.indexOf("c:Invoke('Reset')"), 'Guard the explicit fixture before reset/grant');
check(step.args.code.indexOf("local afterSpin=c:Invoke('Snapshot')") < step.args.code.indexOf("c:Invoke('GrantPremiumProduct','SpinPack')"), 'Read actual baseline before the product grant');
check(step.args.code.includes("local afterGrant=c:Invoke('Snapshot')"), 'Read actual balance after the product grant');
check(source.includes('return automationSnapshot(player, shared.PunchWallPremiumProducts.grant(player, product))'), 'Automation uses the reviewed production grant');
check(source.includes('return automationSnapshot(player, spinReward(player))'), 'Automation uses the reviewed weighted spin producer');
check(oldFlow.steps.find(item => item.label === label).args.code.includes('a.SpinCredits==3'), 'Freeze the observed obsolete total-balance oracle');

const setup = `
local count=0 local function check(value,name) assert(value,name) count+=1 end
local GameConfig={} local Color3={fromRGB=function(...) return {...} end}
${spinCatalog}
${productsCatalog}
local shared={PunchWallPremiumProducts={}}
local stats,events={},{} local attrs={}
local player={GetAttribute=function(_,key) return attrs[key] end,SetAttribute=function(_,key,value) attrs[key]=value end}
local ready=true local function profileReady() return ready end
local function statValue(_,name,default) local value=stats[name] if value==nil then return default end return value end
local function setStat(_,name,value) stats[name]=value end
local function addStat(_,name,value) stats[name]=(stats[name] or 0)+value end
local function sendFeedback(_,event) table.insert(events,event) end
local PolishConfig={Palette={Fail='Fail',Reward='Reward'}}
local now=100000 local os={time=function() return now end}
local workspace={GetServerTimeNow=function() return now end}
local roll=0 local math=table.clone(math) math.random=function() return roll end
local ProfilePersistence={MaxAuthoritativeNumber=9007199254740991}
local persistenceRuntime={applySpeedBoostState=function() end}
local function reset(credits)
 stats={SpinCredits=credits or 0,LastSpinAt=0,Coins=50,Power=15,Honor=0}
 events={} attrs={} ready=true
end
local function snapshot() return table.clone(stats) end
local product
for _,entry in ipairs(GameConfig.PremiumProducts) do if entry.id=='SpinPack' then product=entry end end
check(product and product.spins==3,'actual_spin_pack_catalog')
`;
const cases = `
local total=0 for _,reward in ipairs(GameConfig.Spin.Rewards) do total+=reward.weight end
check(#GameConfig.Spin.Rewards==8 and total==100,'current_weighted_catalog')
local running=0 local seen={}
for index,reward in ipairs(GameConfig.Spin.Rewards) do
 roll=(running+reward.weight*.5)/total running+=reward.weight
 for _,credits in ipairs({0,2}) do
  reset(credits) local before=snapshot()
  local spin=spinReward(player) local afterSpin=snapshot()
  check(spin.index==index and spin.reward==reward.id,'weighted_selection_index')
  local grant=shared.PunchWallPremiumProducts.grant(player,product) local afterGrant=snapshot()
  local result=verifySpinCreditLedger(GameConfig,before,spin,afterSpin,grant,afterGrant)
  check(result.ok and result.packCredits==3,'exact_producer_ledger_accepted')
  check(afterSpin.LastSpinAt==(credits>0 and 0 or now),'free_spin_vs_credit_clock')
  check(#events==2 and events[1].type=='SpinResult' and events[2].type=='PremiumPurchase','actual_feedback_producers_executed')
  if credits==0 then
   local oldOk=spin.ok==true and tostring(spin.reward or '')~='' and afterGrant.SpinCredits==3
   check(oldOk==(reward.kind~='BonusSpin'),'old_total_oracle_fails_only_bonus_outcomes')
  end
 end
 seen[reward.id]=true
end
check(seen.BonusSpinGreen and seen.BonusSpinPurple,'both_bonus_variants_executed')
reset() roll=0 check(spinReward(player).index==1,'first_weight_endpoint')
reset() roll=1 check(spinReward(player).index==#GameConfig.Spin.Rewards,'last_weight_endpoint')

local function sample()
 reset() local selected=5 local cumulative=0
 for i=1,selected-1 do cumulative+=GameConfig.Spin.Rewards[i].weight end
 roll=(cumulative+GameConfig.Spin.Rewards[selected].weight*.5)/total
 local b=snapshot() local s=spinReward(player) local a=snapshot()
 local g=shared.PunchWallPremiumProducts.grant(player,product) local z=snapshot()
 return b,s,a,g,z
end
local function rejected(edit,message)
 local b,s,a,g,z=sample() edit(b,s,a,g,z)
 local ok,err=pcall(verifySpinCreditLedger,GameConfig,b,s,a,g,z)
 check(not ok and string.find(tostring(err),message,1,true)~=nil,'reject_'..message)
end
rejected(function(_,_,a,_,z) z.SpinCredits=a.SpinCredits end,'SpinPack must add its exact catalog delta')
rejected(function(_,_,a,_,z) z.SpinCredits=a.SpinCredits+6 end,'SpinPack must add its exact catalog delta')
rejected(function(_,_,_,g) g.product='CoinPack' end,'SpinPack result must match granted product')
rejected(function(_,_,_,g) g.spins=4 end,'SpinPack result must match granted product')
rejected(function(_,_,_,g) g.ok=false end,'SpinPack result must match granted product')
rejected(function(_,s) s.reward='UnknownReward' end,'weighted reward identity must match catalog')
rejected(function(_,s) s.index=1 end,'weighted reward identity must match catalog')
rejected(function(_,s) s.amount=2 end,'weighted reward identity must match catalog')
rejected(function(_,_,a) a.SpinCredits=0 end,'spin credits must follow reward ledger')
rejected(function(_,s) s.credits=0 end,'spin credits must follow reward ledger')
rejected(function(_,_,a) a.Power+=1 end,'spin reward balance mismatch: Power')
rejected(function(_,_,_,_,z) z.Coins+=1 end,'SpinPack changed unrelated balance: Coins')
reset() stats.LastSpinAt=now local b=snapshot() local refused=spinReward(player)
check(refused.ok==false and refused.reason=='cooldown' and stats.SpinCredits==b.SpinCredits and stats.Power==b.Power,'actual_cooldown_refuses_without_grant')
reset() ready=false b=snapshot() refused=shared.PunchWallPremiumProducts.grant(player,product)
check(refused.ok==false and refused.reason=='profile_not_ready' and stats.SpinCredits==b.SpinCredits,'actual_unready_profile_refuses_product')
print('PASS '..count)
`;

const tempRoot = os.tmpdir();
const candidates = [process.env.LUAU_COMMAND, ...fs.readdirSync(tempRoot).filter(name => name.startsWith('codex-luau-')).sort().reverse()
  .map(name => path.join(tempRoot, name, process.platform === 'win32' ? 'luau.exe' : 'luau')), 'luau'];
const luau = candidates.find(candidate => candidate && spawnSync(candidate, ['--help'], {encoding: 'utf8'}).status === 0);
assert(luau, 'BLOCKED: set LUAU_COMMAND to the Luau CLI');
const compiler = process.env.LUAU_COMPILE_COMMAND || path.join(path.dirname(luau), process.platform === 'win32' ? 'luau-compile.exe' : 'luau-compile');
const temp = fs.mkdtempSync(path.join(tempRoot, 'smash-release-spin-'));
let compiled = 0, assertions = 0;
const mutations = [];
function run(name, text, failure) {
  const file = path.join(temp, `${name}.luau`); fs.writeFileSync(file, text);
  const compilation = spawnSync(compiler, ['--null', file], {encoding: 'utf8', timeout: 15000});
  assert.equal(compilation.status, 0, `${name} compilation: ${compilation.stdout}${compilation.stderr}`); compiled++;
  const result = spawnSync(luau, [file], {encoding: 'utf8', timeout: 15000});
  const output = `${result.stdout || ''}${result.stderr || ''}`;
  if (failure) {
    assert(result.status !== 0 && output.includes(failure), `Mutation survived or failed for wrong reason: ${name}: ${output}`);
    mutations.push(name);
  } else {
    assert.equal(result.status, 0, `${name}: ${output}`);
    const match = output.match(/PASS (\d+)/); assert(match, `Missing completed assertion ledger: ${name}`);
    assertions += Number(match[1]);
  }
}
const fixture = setup + spinProducer + '\n' + grantProducer + '\n' + verifier + cases;
try {
  run('exact-producers', fixture);
  const mutate = (name, from, to, failure) => {
    assert(fixture.includes(from), `Missing mutation boundary: ${name}`);
    run(name, fixture.replace(from, to), failure);
  };
  mutate('missing-bonus-credit', 'addStat(player, "SpinCredits", reward.amount)', '-- omitted bonus credit', 'spin credits must follow reward ledger');
  mutate('double-pack-credit', 'addStat(player, "SpinCredits", grantedSpins)', 'addStat(player, "SpinCredits", grantedSpins * 2)', 'SpinPack must add its exact catalog delta');
  mutate('missing-pack-credit', 'addStat(player, "SpinCredits", grantedSpins)', 'addStat(player, "SpinCredits", 0)', 'SpinPack must add its exact catalog delta');
  mutate('overwrite-existing-credit', 'addStat(player, "SpinCredits", grantedSpins)', 'setStat(player, "SpinCredits", grantedSpins)', 'SpinPack must add its exact catalog delta');
  mutate('mismatched-product-result', 'product = product.id,\n\t\tcoins = grantedCoins,', 'product = "CoinPack",\n\t\tcoins = grantedCoins,', 'SpinPack result must match granted product');
  mutate('non-weighted-selection', 'local roll = math.random() * totalWeight', 'local roll = 0', 'weighted_selection_index');
  mutate('credit-consumption-missing', 'addStat(player, "SpinCredits", -1)', '-- omitted credit consumption', 'spin credits must follow reward ledger');
  mutate('weaken-pack-delta-gate', "assert(packCredits==product.spins,'SpinPack must add its exact catalog delta')", '-- omitted exact delta', 'reject_SpinPack must add its exact catalog delta');
  mutate('weaken-spin-ledger-gate', "assert(afterSpin.SpinCredits==expectedCredits and spin.credits==expectedCredits,'spin credits must follow reward ledger')", '-- omitted spin ledger', 'reject_spin credits must follow reward ledger');
  mutate('weaken-product-identity-gate', "assert(grant.ok==true and grant.product==product.id and grant.spins==product.spins,'SpinPack result must match granted product')", '-- omitted grant identity', 'reject_SpinPack result must match granted product');
  for (const [index, item] of flow.steps.entries()) {
    if (item.tool !== 'execute_luau') continue;
    const file = path.join(temp, `flow-${index}.luau`); fs.writeFileSync(file, item.args.code);
    const result = spawnSync(compiler, ['--null', file], {encoding: 'utf8', timeout: 15000});
    assert.equal(result.status, 0, `${item.label}: ${result.stdout}${result.stderr}`); compiled++;
  }
  console.log(JSON.stringify({ok: true, sourceChecks, assertions, compiled, mutationControls: mutations.length, mutations}, null, 2));
} finally {
  for (const name of fs.readdirSync(temp)) fs.unlinkSync(path.join(temp, name));
  fs.rmdirSync(temp);
}
