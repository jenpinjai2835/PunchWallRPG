import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {spawnSync} from 'node:child_process';

const root=path.resolve(import.meta.dirname,'../../..');
const flowPath='work/automation/flows/pet-size-position-qc.json';
const baseline='06b0e9f3d369ed2b001d26856066bab7c9156c06';
const flow=JSON.parse(fs.readFileSync(path.join(root,flowPath),'utf8'));
const oldProcess=spawnSync('git',['show',`${baseline}:${flowPath}`],{cwd:root,encoding:'utf8'});
assert.equal(oldProcess.status,0,oldProcess.stderr);
const oldFlow=JSON.parse(oldProcess.stdout);
const selected=flow.steps.filter(s=>s.saveAs==='premiumFollowMotion');
assert.equal(selected.length,1);
const code=selected[0].args.code;
const oldCode=oldFlow.steps.find(s=>s.saveAs==='premiumFollowMotion').args.code;
const normalized=structuredClone(flow);
normalized.steps.find(s=>s.saveAs==='premiumFollowMotion').args.code=oldCode;
assert.deepEqual(normalized,oldFlow,'Only the bounded follow observation code may change; all other gates/steps/cleanup remain exact.');
const legacyGate='earlyMove>0.01 and earlyMove<7.5 and lateMove>earlyMove+0.8 and lateMove<11';
assert.ok(oldCode.includes(legacyGate));
assert.ok(oldCode.includes('task.wait(.05)')&&oldCode.includes('task.wait(.85)'));
function between(text,from,to){const a=text.indexOf(from),b=text.indexOf(to,a+from.length);assert.ok(a>=0&&b>a,from);return text.slice(a,b);}
const policy=between(code,'local function finite','-- End of extracted observation policy.');
const source=fs.readFileSync(path.join(root,'work/punch-wall-rpg/src/client/PunchWallClient.client.lua'),'utf8').replace(/\r\n?/g,'\n');
const config=fs.readFileSync(path.join(root,'work/punch-wall-rpg/src/shared/GameConfig.lua'),'utf8');
const response=Number(config.match(/name = "Celestial Guardian"[^\n]*followResponsiveness = ([\d.]+)/)?.[1]);
assert.equal(response,7.5,'Use the actual catalog responsiveness.');
const clamp=source.match(/deltaTime = math\.clamp\(tonumber\(deltaTime\) or \(1 \/ 60\), 1 \/ 240, 0\.1\)/)?.[0];
assert.ok(clamp,'Producer delta clamp must still match the bounded timing policy.');
const lod=between(source,'\tlocal lod = cameraDistance <= 8','\tlocal combinedScreenArea =');
const due=between(source,'\t\t\tstate.updateAccumulator += deltaTime','\t\t\t\tlocal availableBudget =');
const smoothing=between(source,'\t\t\t\tlocal distance = (state.currentBoundsCFrame.Position - targetBounds.Position).Magnitude','\t\t\t\tif state.safeFrameBoundsSize');
const candidates=[process.env.LUAU_COMMAND,...fs.readdirSync(os.tmpdir()).filter(n=>n.startsWith('codex-luau-')).sort().reverse().map(n=>path.join(os.tmpdir(),n,process.platform==='win32'?'luau.exe':'luau')),'luau'];
const luau=candidates.find(p=>p&&spawnSync(p,['--help']).status===0);
assert.ok(luau,'BLOCKED: official Luau CLI required');
const compiler=process.env.LUAU_COMPILE_COMMAND||path.join(path.dirname(luau),process.platform==='win32'?'luau-compile.exe':'luau-compile');
const temp=fs.mkdtempSync(path.join(os.tmpdir(),'smash-pet-follow-'));
let compiled=0,executed=0,mutations=0;
function run(label,chunk,expectFailure=false){
 const filename=path.join(temp,`${label}.luau`);fs.writeFileSync(filename,chunk);
 const c=spawnSync(compiler,['-O1',filename],{encoding:'utf8'});assert.equal(c.status,0,`${label} compile: ${c.stderr}`);compiled++;
 const r=spawnSync(luau,[filename],{encoding:'utf8',timeout:20000});
 if(expectFailure){assert.notEqual(r.status,0,`${label} mutation falsely passed`);assert.match(r.stderr,/ASSERT:/,`${label} must fail a behavior assertion: ${r.stderr}`);mutations++;}
 else{assert.equal(r.status,0,`${label}: ${r.stdout}\n${r.stderr}`);executed+=Number(r.stdout.match(/PASS (\d+)/)?.[1]||0);}
}
const setup=`
local n=0 local function check(value,label)assert(value,'ASSERT: '..label)n+=1 end
local function observation(at,move)
 return {at=at,move=move,rootMove=8,motionHz=20,sameCharacter=true,sameRoot=true,samePet=true,anchored=true,ready=true,cameraDistance=20,cameraType='Scriptable'}
end
local initial=observation(0,0)
local Vector3,V={},{}
function Vector3.new(x,y,z)return setmetatable({X=x,Y=y,Z=z},V)end
V.__add=function(a,b)return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z)end
V.__sub=function(a,b)return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end
V.__mul=function(a,b)return Vector3.new(a.X*b,a.Y*b,a.Z*b)end
V.__index=function(a,k)if k=='Magnitude'then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z)end end
local F={} local function frame(x,y,z)return setmetatable({Position=Vector3.new(x,y or 0,z or 0),RightVector=Vector3.new(1,0,0)},F)end
F.__add=function(a,b)return frame(a.Position.X+b.X,a.Position.Y+b.Y,a.Position.Z+b.Z)end
F.__index={Lerp=function(a,b,t)return frame(a.Position.X+(b.Position.X-a.Position.X)*t,a.Position.Y+(b.Position.Y-a.Position.Y)*t,a.Position.Z+(b.Position.Z-a.Position.Z)*t)end}
local function producer(state,deltaTime,targetBounds,cameraDistance)
 ${clamp}
 local clientSettings={motion=true}
 ${lod}
 ${due}
 ${smoothing}
 end
 return state.currentBoundsCFrame.Position.X,updateInterval
end
local function model(phase)return {updateAccumulator=phase,currentBoundsCFrame=frame(0),followResponsiveness=${response}}end
`;
const cases=`
local phaseCases,oldFalseFailures=0,0
-- Independent scheduling: waiting-task nominal capture precedes the producer;
-- the Heartbeat observer is exercised both before and after its publication.
for _,dt in ipairs({.016,1/60,.02,.025,.033,1/30,.05,.1})do
 for phaseIndex=0,10 do for offsetIndex=0,4 do for _,beforeProducer in ipairs({false,true})do
  local s=newFollowObservation()local m=model(.049*phaseIndex/10)local nominal local at=dt*offsetIndex/4
  for event=1,300 do
   if at>=.05 and not nominal then nominal=m.currentBoundsCFrame.Position.X end
   if beforeProducer then captureHeartbeat(s,observation(at,m.currentBoundsCFrame.Position.X),dt)end
   local _,interval=producer(m,dt,frame(8),20)check(interval==.05,'actual Far20 producer cadence')
   if not beforeProducer then captureHeartbeat(s,observation(at,m.currentBoundsCFrame.Position.X),dt)end
   if s.late or s.failure then break end at+=dt
  end
  check(followMotionValid(s,initial),'valid producer phase must pass '..dt..':'..phaseIndex..':'..offsetIndex..':'..tostring(beforeProducer))
  check(s.eligible==2 and s.early.at>=.05 and s.early.at<=.25+.000001,'fixed second eligible event and hard early cap')
  check(s.late.at>=s.early.at+.85 and s.late.at<=s.lateDeadline+.000001,'original late gap and one-frame bound')
  local earlyMove,lateMove=nominal,s.late.move
  if not (${legacyGate})then oldFalseFailures+=1 end
  phaseCases+=1
 end end end
end
check(phaseCases==880 and oldFalseFailures>0,'old nominal wait falsely fails at least one valid production phase')

-- Replay the observed boundary: nominal .062775 was zero, then .062808
-- Heartbeat was zero, then .079823 published 3.0347 studs. These are evidence
-- samples, not a claim that offline scheduling reconstructs native execution.
local recorded=newFollowObservation()
captureHeartbeat(recorded,observation(.046,.0),.016)
captureHeartbeat(recorded,observation(.06280839999817545,0),.0168)
captureHeartbeat(recorded,observation(.07982330000231741,3.0346763134002687),.01702)
captureHeartbeat(recorded,observation(.9296471999987261,8.10512924194336),.01702)
captureHeartbeat(recorded,observation(.9467,8.11),.01706)
check(followMotionValid(recorded,initial),'recorded early publication passes fixed event policy without selecting by movement')
check(recorded.early.at==.07982330000231741 and recorded.late.at==.9467,'second eligible and first original-gap eligible samples retained')

local function deterministic(mode)
 local s=newFollowObservation()local m=model(0)
 for event=1,150 do
  local at=event/60
  if mode~='frozen' and not(mode=='delayed' and at<.12) and not(mode=='late-stall' and at>.07)then producer(m,1/60,frame(8),20)end
  local move=mode=='snap' and 8 or m.currentBoundsCFrame.Position.X
  local o=observation(at,move)
  if mode=='wrong-root' and event==5 then o.sameRoot=false end
  if mode=='wrong-character' and event==5 then o.sameCharacter=false end
  if mode=='wrong-pet' and event==5 then o.samePet=false end
  if mode=='root-still' then o.rootMove=0 end
  if mode=='unanchored' then o.anchored=false end
  if mode=='wrong-cadence' then o.motionHz=60 end
  if mode=='wrong-camera' then o.cameraType='Custom' end
  captureHeartbeat(s,o,1/60)
  if s.failure or s.late then break end
 end
 return s
end
check(followMotionValid(deterministic('normal'),initial),'normal producer is a positive control')
for _,mode in ipairs({'frozen','delayed','snap','late-stall','wrong-root','wrong-character','wrong-pet','root-still','unanchored','wrong-cadence','wrong-camera'})do
 check(not followMotionValid(deterministic(mode),initial),'reject '..mode)
end
-- Equal timestamps under radically different outcomes prove sampling is not
-- a retry-until-success loop, including a producer that remains frozen.
local normal,frozen,delayed=deterministic('normal'),deterministic('frozen'),deterministic('delayed')
check(normal.early and frozen.early and delayed.early and normal.early.heartbeat==frozen.early.heartbeat and normal.early.heartbeat==delayed.early.heartbeat,'capture index independent of movement')
check(frozen.early.move==0 and delayed.early.move==0,'a failed early outcome is retained, never replaced by a later success')
for _,delta in ipairs({0,-.01,.100001,math.huge,0/0})do
 local s=newFollowObservation()captureHeartbeat(s,observation(.06,2),delta)
 check(s.failure~=nil and not followMotionValid(s,initial),'nonfinite or out-of-budget delta fails')
end
for _,at in ipairs({-.01,math.huge,0/0})do
 local s=newFollowObservation()captureHeartbeat(s,observation(at,2),.02)
 check(s.failure~=nil,'nonfinite or negative elapsed time fails')
end
local reversed=newFollowObservation()captureHeartbeat(reversed,observation(.04,2),.02)captureHeartbeat(reversed,observation(.04,2),.02)
check(reversed.failure~=nil,'duplicate or reversed observer timestamp fails')
local earlyMiss=newFollowObservation()captureHeartbeat(earlyMiss,observation(.07,2),.02)captureHeartbeat(earlyMiss,observation(.11,3),.02)
check(earlyMiss.failure~=nil and earlyMiss.earlyDeadline==.09,'missing early frame fails rather than extending wall time')
local lateMiss=newFollowObservation()captureHeartbeat(lateMiss,observation(.05,2),.02)captureHeartbeat(lateMiss,observation(.07,3),.02)captureHeartbeat(lateMiss,observation(.96,8),.02)
check(lateMiss.failure~=nil,'missing late deadline fails')
local frozenDeadline=newFollowObservation()captureHeartbeat(frozenDeadline,observation(.05,2),.02)captureHeartbeat(frozenDeadline,observation(.07,3),.02)
local deadline=frozenDeadline.earlyDeadline local allowance=frozenDeadline.earlyAllowance
captureHeartbeat(frozenDeadline,observation(.17,4),.1)
check(frozenDeadline.earlyDeadline==deadline and frozenDeadline.earlyAllowance==allowance and frozenDeadline.earlyMaxDelta==.02,'later hitch cannot retroactively extend early allowance')
local overflow=newFollowObservation()overflow.total=2048 captureHeartbeat(overflow,observation(.04,2),.02)
check(overflow.failure~=nil,'hard event budget cannot falsely pass')
local missing=newFollowObservation()captureHeartbeat(missing,observation(.06,2),.02)
check(not followMotionValid(missing,initial),'missing early/late captures fail')
local edge=deterministic('normal')edge.early.move=.01 check(not followMotionValid(edge,initial),'strict original early lower bound')
edge=deterministic('normal')edge.early.move=7.5 edge.late.move=9 check(not followMotionValid(edge,initial),'strict original early upper bound')
edge=deterministic('normal')edge.late.move=edge.early.move+.8 check(not followMotionValid(edge,initial),'strict original late increase')
edge=deterministic('normal')edge.late.move=11 check(not followMotionValid(edge,initial),'strict original late upper bound')
print('PASS '..n)
`;
const lifecycle=`
local function runFlow(mode,originalAnchored,injectionAt)
 local clock=0 local os={clock=function()return clock end}local conn,watchdog,lastResult local disconnects,cancels=0,0
 local printed={}local returned,lastEncoded
 local function print(message)table.insert(printed,message)end
 local injected=false local restorationAttempts=0
 local character={}local rootPart=setmetatable({_cf=frame(0),_anchored=originalAnchored,Parent=character},{
  __index=function(t,k)if k=='CFrame'then return rawget(t,'_cf')elseif k=='Position'then return rawget(t,'_cf').Position elseif k=='Anchored'then return rawget(t,'_anchored')end end,
  __newindex=function(t,k,v)
   if k=='CFrame'then rawset(t,'_cf',v)
   elseif k=='Anchored'then
    if mode=='failed-restoration' and injected and v==originalAnchored then restorationAttempts+=1 else rawset(t,'_anchored',v)end
   else rawset(t,k,v)end
  end})
 function character:FindFirstChild(name)return name=='HumanoidRootPart' and rootPart end
 local p={Character=character,Name='Fixture'}local m=model(0)local folder={}local pet={Parent=folder}
 function pet:GetAttribute(k)if k=='PetDefinitionName'then return 'Celestial Guardian' elseif k=='SmoothFollowReady'then return true elseif k=='CompanionMotionHz'then return 20 elseif k=='FollowSmoothing'then return 'ExponentialCFrame'end end
 function pet:GetBoundingBox()if mode=='error' and clock>=.08 then error('injected native bounds failure')end return m.currentBoundsCFrame end
 function folder:GetChildren()return {pet}end
 local workspace={CurrentCamera={CFrame=frame(0,0,18),CameraType={Name='Scriptable'}},FindFirstChild=function()return folder end}
 local function json(v)
  local t=type(v)if t=='table'then local out={}for k,x in pairs(v)do table.insert(out,'"'..tostring(k)..'":'..json(x))end return '{'..table.concat(out,',')..'}'
  elseif t=='string'then return string.format('%q',v)elseif t=='boolean'then return tostring(v)elseif t=='number'then assert(v==v and math.abs(v)<math.huge,'invalid JSON number')return tostring(v)else return 'null'end
 end
 local H={JSONEncode=function(_,v)lastResult=v lastEncoded=json(v)return lastEncoded end}
 local R={Heartbeat={Connect=function(_,callback)conn={Connected=true,callback=callback,Disconnect=function(self)self.Connected=false disconnects+=1 end}return conn end}}
 local game={Players={LocalPlayer=p},GetService=function(_,name)return name=='HttpService' and H or R end}
 local task={wait=function(t)return coroutine.yield(t or 0)end,
  delay=function(t,callback)watchdog={at=clock+t,callback=callback,cancelled=false}return watchdog end,
  cancel=function(token)token.cancelled=true cancels+=1 end}
 local co=coroutine.create(function()
 FLOW_CODE
 end)
 local ok,wait=coroutine.resume(co)check(ok,'flow starts')local wake=wait or 0
 for event=1,300 do
  clock=event/60
  if watchdog and not watchdog.cancelled and not watchdog.fired and clock>=watchdog.at then watchdog.fired=true watchdog.callback()end
  -- Waiting tasks resume before this tick's producer and observer.
  if coroutine.status(co)~='dead' and clock>=wake then
   local resumed,value=coroutine.resume(co)check(resumed,'flow does not leak an uncaught error')if coroutine.status(co)~='dead'then wake=clock+(value or 0)else returned=value end
  end
  if mode~='frozen' then producer(m,1/60,frame(rootPart.Position.X),20)end
  if mode~='watchdog' and conn and conn.Connected then conn.callback(1/60)end
  -- Inject only after the actual normal control's final capture, while its
  -- waiting task has not resumed cleanup; the character object stays alive.
  if injectionAt and not injected and clock>=injectionAt then
   injected=true
   if mode=='post-late-root-removal'then rootPart.Parent=nil end
  end
  if coroutine.status(co)=='dead'then break end
 end
 check(coroutine.status(co)=='dead','flow has bounded completion')
 check(lastResult~=nil,'flow exports durable result')
 check(type(returned)=='string' and returned==lastEncoded and #returned<=3500,'unchanged return JSON is the final budget-checked payload')
 check(#printed==1 and printed[1]=='[SMASH_PET_FOLLOW_OBSERVATION_V1]'..returned,'exact unique console tag retains the complete final JSON on success and failure')
 check(conn and not conn.Connected and disconnects==1,'success/failure/watchdog disconnect exactly once')
 check(cancels==1 and watchdog.cancelled,'watchdog cancelled after completion')
 if injectionAt then
  check(injected and p.Character==character and lastResult.lateObservation.at==injectionAt,'failure injected strictly after the captured late sample, without replacing character')
  check(lastResult.lateObservation.sameRoot==true and lastResult.lateObservation.anchored==true,'all captured identity and root gates passed before cleanup failure')
  check(lastResult.valid==false and lastResult.cleanupRestored==false and not lastResult.watchdogTimedOut,'cleanup failure must invalidate an otherwise completed motion result')
  if mode=='failed-restoration'then check(restorationAttempts==1 and rootPart.Parent==character and rootPart.Anchored~=originalAnchored,'failed restoration readback is actual, not a removed root proxy')end
 else
  check(rootPart.Anchored==originalAnchored,'success/failure/watchdog restore original anchor')
  check(lastResult.cleanupRestored==true,'actual cleanup attested')
 end
 check(#lastResult.samples<=12 and (lastResult.droppedSamples==nil or lastResult.droppedSamples>=0),'bounded retained diagnostics')
 if mode=='normal'then
  check(lastResult.valid==true and not lastResult.watchdogTimedOut,'normal complete flow passes')
  check(lastResult.nominalObservation.at>=.05 and lastResult.earlyObservation.at>lastResult.nominalObservation.at,'nominal and selected early snapshots remain distinct')
 elseif mode=='watchdog'then check(lastResult.valid==false and lastResult.watchdogTimedOut==true,'missing Heartbeats fail through original two-second watchdog')
 else check(lastResult.valid==false and not lastResult.watchdogTimedOut,'frozen producer or observation error cannot pass')end
 return lastResult
end
local completed=runFlow('normal',false)
runFlow('normal',true)runFlow('frozen',false)runFlow('error',false)runFlow('watchdog',false)
runFlow('post-late-root-removal',false,completed.lateObservation.at)
runFlow('failed-restoration',false,completed.lateObservation.at)
print('PASS '..n)
`;
try{
 for(const [index,step]of [...flow.steps,...flow.cleanup].entries())if(step.tool==='execute_luau'){
  const filename=path.join(temp,`flow-${index}.luau`);fs.writeFileSync(filename,step.args.code);
  const r=spawnSync(compiler,['-O1',filename],{encoding:'utf8'});assert.equal(r.status,0,`${step.label}: ${r.stderr}`);compiled++;
 }
 run('phase-and-observer',setup+policy+cases);
 run('whole-flow-lifecycle',setup+lifecycle.replace('FLOW_CODE',code));
 const changes=[
  ['movement-conditioned-selection','if state.eligible==2 then','if state.eligible>=2 and observed.move>.01 then'],
  ['first-event-selection','if state.eligible==2 then','if state.eligible==1 then'],
  ['late-gap-shortened','lateGap=.85','lateGap=.75'],
  ['delta-cap-removed','delta>state.maxFrame','false'],
  ['delta-finite-removed','not finite(delta)','false'],
  ['clock-finite-removed','not finite(observed.at)','false'],
  ['clock-order-removed','observed.at<=state.lastAt','false'],
  ['early-deadline-removed','observed.at>state.earlyDeadline+state.epsilon','false'],
  ['late-deadline-removed','observed.at>state.lateDeadline+state.epsilon','false'],
  ['event-budget-removed','state.total>state.maxEvents','false'],
  ['root-identity-removed','observed.sameRoot==true','true'],
  ['character-identity-removed','observed.sameCharacter==true','true'],
  ['pet-lifetime-removed','observed.samePet==true','true'],
  ['root-movement-removed','math.abs(observed.rootMove-8)<.001','true'],
  ['anchor-removed','observed.anchored==true','true'],
  ['cadence-removed','observed.motionHz==20','true'],
  ['scriptable-removed',"observed.cameraType=='Scriptable'",'true'],
  ['early-frozen-accepted','early.move>0.01','early.move>=0'],
  ['snap-accepted','early.move<7.5','early.move<=8'],
  ['late-stall-accepted','late.move>early.move+0.8','late.move>=early.move'],
  ['late-upper-relaxed','late.move<11','late.move<=11'],
  ['retroactive-early-allowance','observed.heartbeat=state.total', 'if state.early then state.earlyMaxDelta=state.maxDelta state.earlyAllowance=2*state.maxDelta state.earlyDeadline=state.nominalDelay+state.earlyAllowance end observed.heartbeat=state.total'],
 ];
 for(const [label,from,to]of changes){assert.ok(policy.includes(from),label);run(`mutation-${label}`,setup+policy.replace(from,to)+cases,true);}
 for(const [label,from,to]of [
  ['no-disconnect','connection:Disconnect()','do end'],
  ['wrong-anchor-restore','root.Anchored=originalAnchored','root.Anchored=true'],
  ['no-watchdog-cancel','pcall(task.cancel,watchdog)','do end'],
  ['late-watchdog','task.delay(2,','task.delay(20,'],
  ['old-cleanup-diagnostic-only','result.valid=result.valid and result.cleanupRestored','do end'],
  ['missing-durable-print',"print('[SMASH_PET_FOLLOW_OBSERVATION_V1]'..encoded)",'do end'],
  ['wrong-durable-tag',"print('[SMASH_PET_FOLLOW_OBSERVATION_V1]'..encoded)","print('[OTHER]'..encoded)"],
  ['wrong-durable-payload',"print('[SMASH_PET_FOLLOW_OBSERVATION_V1]'..encoded)","print('[SMASH_PET_FOLLOW_OBSERVATION_V1]{}')"],
 ]){assert.ok(code.includes(from),label);run(`mutation-${label}`,setup+lifecycle.replace('FLOW_CODE',code.replace(from,to)),true);}
 console.log(JSON.stringify({ok:true,baseline,unchangedFlowOutsideObserver:true,compiled,executedAssertions:executed,compilingMutationsRejected:mutations,phaseCases:880,scope:'Exact production cadence/smoothing plus extracted observer and full flow lifecycle; no native runtime claim.'},null,2));
}finally{
 assert.equal(path.dirname(path.resolve(temp)),path.resolve(os.tmpdir()),'Temporary cleanup stays in the OS temp directory.');
 assert.ok(path.basename(temp).startsWith('smash-pet-follow-'));
 fs.rmSync(temp,{recursive:true,force:true});
}
