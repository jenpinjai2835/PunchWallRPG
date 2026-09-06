import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {spawnSync, execFileSync} from 'node:child_process';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const flowPath='work/automation/flows/world-wall-reset.json';
const baselineRef='126a299f0fb18d99016781cbccb33e2972ee1ef2'; // Reachable integrated pre-hardening flow.
const flow=JSON.parse(fs.readFileSync(path.join(root,flowPath),'utf8'));
const historical=JSON.parse(execFileSync('git',['show',baselineRef+':'+flowPath],{cwd:root,encoding:'utf8'}));
const indices=[2,6];
const first=flow.steps[2].args.code;
const second=flow.steps[6].args.code;
assert.equal(first.replace('result.phase="bootstrap"','result.phase="post-reset"'),second,'Both observations must share the exact helper and adapter');
const normalized=structuredClone(flow);
for(const i of indices) {
 assert.deepEqual(flow.steps[i].expectRegex.slice(0,historical.steps[i].expectRegex.length),historical.steps[i].expectRegex,'Original Wave/endpoint gates survive');
 assert.deepEqual(flow.steps[i].expectRegex.slice(historical.steps[i].expectRegex.length),['"idleReady"\\s*:\\s*true','"invokeCleanup"\\s*:\\s*true','"finalIdentity"\\s*:\\s*true','"valid"\\s*:\\s*true']);
 normalized.steps[i].args.code=historical.steps[i].args.code;
 normalized.steps[i].expectRegex=historical.steps[i].expectRegex;
}
assert.deepEqual(normalized,historical,'Every reset/stat/feedback step, label, timeout and cleanup is unchanged');
const nativeContract=fs.readFileSync(path.join(root,'work/automation/scripts/animate-hook-lifecycle-contract.mjs'),'utf8');
const nativeBinding=JSON.parse(assertMatch(nativeContract,/const nativeBinding=("(?:[^"\\]|\\.)*");/)[1]);
assert.equal(crypto.createHash('sha256').update(nativeBinding).digest('hex'),'3e6b8779e88d1feee2511690bdd9879a1496c59b7ebd10ae560996964b49f40a','Use the exact retained native Animate binding');
function assertMatch(text,pattern){const m=text.match(pattern);assert(m,'Missing '+pattern);return m;}
const tooling=path.join(process.env.LOCALAPPDATA || path.join(os.homedir(),'AppData/Local'),'Temp/codex-luau-smash-0.737');
const luau=process.env.LUAU_QA_EXE || path.join(tooling,'luau.exe');
const compiler=path.join(path.dirname(luau),'luau-compile.exe');
assert(fs.existsSync(luau)&&fs.existsSync(compiler),'Official Luau0.737 runtime/compiler unavailable');
const tmp=fs.mkdtempSync(path.join(os.tmpdir(),'smash-world-emote-'));
let serial=0,compiles=0,executions=0,assertions=0;
function compile(code,label) {
 const file=path.join(tmp,String(++serial)+'-'+label.replace(/[^a-z0-9-]/gi,'-')+'.luau');
 fs.writeFileSync(file,code);
 const r=spawnSync(compiler,['-O1',file],{encoding:'utf8',maxBuffer:2**20});
 assert.equal(r.status,0,label+' compile\n'+r.stdout+r.stderr);compiles++;
 return file;
}
function execute(code,label,negative=false) {
 const file=compile(code,label);
 const r=spawnSync(luau,[file],{encoding:'utf8',maxBuffer:2**20,timeout:10000});
 const output=(r.stdout || '')+(r.stderr || '');
 executions++;
 if(negative){assert(r.status!==0,label+' did not reject');assert.match(output,/QA_ASSERT:/,label+' failed for an unintended reason:\n'+output);}
 else {assert.equal(r.status,0,label+'\n'+output);const m=assertMatch(output,/CASE_PASS (\d+)/);assertions+=Number(m[1]);const raw=assertMatch(output,/RETURNED (.+)/)[1];const value=JSON.parse(raw);assert.equal(flow.steps[2].expectRegex.every(pattern=>new RegExp(pattern).test(raw)),value.valid,label+' actual outer response gates');}
 return output;
}
const mock=String.raw`
local nativePrint=print
local now,sequence=0,0
local queue,threads,cancelled,schedulerErrors,messages={},{},{},{},{}
local checks,animationCalls=0,0
local calls={}
local published,encoded
local function check(value,label)checks+=1 assert(value,'QA_ASSERT: '..label)end
local rawClock
local os={clock=function()return rawClock and rawClock(now) or now end}
local function schedule(thread,at)sequence+=1 table.insert(queue,{thread=thread,at=at,sequence=sequence})end
local function resume(thread)
 if cancelled[thread] or coroutine.status(thread)=='dead' then return end
 local ok,token=coroutine.resume(thread)
 if not ok then table.insert(schedulerErrors,tostring(token))return end
 if coroutine.status(thread)=='dead' then return end
 assert(type(token)=='table','invalid mock yield')
 if token.kind=='wait' then schedule(thread,now+token.seconds)
 elseif token.kind~='invoke' then error('unknown mock yield')end
end
local task={}
function task.spawn(fn)local thread=coroutine.create(fn)threads[thread]=true resume(thread)return thread end
function task.delay(seconds,fn)local thread=coroutine.create(fn)threads[thread]=true schedule(thread,now+seconds)return thread end
local cancelFails=false
local waitStep
function task.cancel(thread)
 if cancelFails then error('cancel failure')end
 cancelled[thread]=true
 if coroutine.status(thread)~='dead' then assert(coroutine.close(thread))end
end
function task.wait(seconds)return coroutine.yield({kind='wait',seconds=math.max(seconds or .01,waitStep or 0)})end
local function advance(limit)
 local iterations=0
 while true do
  table.sort(queue,function(a,b)return a.at==b.at and a.sequence<b.sequence or a.at<b.at end)
  local event=queue[1]if not event or event.at>limit then break end
  table.remove(queue,1)now=event.at resume(event.thread)
  iterations+=1 assert(iterations<10000,'scheduler is unbounded')
 end
 now=limit
end
local function instance(class,name,parent)
 local value={ClassName=class,Name=name,Parent=parent,children={},attrs={},__instance=true}
 if parent then table.insert(parent.children,value)end
 function value:IsA(wanted)return wanted==self.ClassName or wanted=='BasePart' and self.ClassName=='Part'end
 function value:GetChildren()local result={}for _,child in ipairs(self.children)do if child.Parent==self then table.insert(result,child)end end return result end
 function value:FindFirstChild(name)for _,child in ipairs(self:GetChildren())do if child.Name==name then return child end end end
 function value:FindFirstChildOfClass(class)for _,child in ipairs(self:GetChildren())do if child:IsA(class)then return child end end end
 function value:WaitForChild(name)return assert(self:FindFirstChild(name),'missing native fixture child')end
 function value:GetAttribute(name)return self.attrs[name]end
 return value
end
local rawTypeof=typeof
local function typeof(value)return type(value)=='table' and value.__instance and 'Instance' or rawTypeof(value)end
local Enum={Material={Air={Name='Air'},Slate={Name='Slate'}},HumanoidStateType={Running={Name='Running'},Freefall={Name='Freefall'},Seated={Name='Seated'}}}
local workspace=instance('Workspace','Workspace')
local character=instance('Model','Character',workspace)
local humanoid=instance('Humanoid','Humanoid',character)
humanoid.Health=100 humanoid.FloorMaterial=Enum.Material.Slate humanoid.MoveDirection={Magnitude=0}
humanoid.state=Enum.HumanoidStateType.Running
function humanoid:GetState()return self.state end
local root=instance('Part','HumanoidRootPart',character)root.Anchored=false root.AssemblyLinearVelocity={Magnitude=0}
local animate=instance('LocalScript','Animate',character)animate.Enabled=true
local hook=instance('BindableFunction','PlayEmote',animate)
character.attrs.PunchWallAnimateRepairState='EngineHookReady'
character.attrs.PunchWallAnimateNativeHookReady=true
local player={Character=character}
local pose='Standing'
local emoteNames={wave=false}
local EMOTE_TRANSITION_TIME=.1
local Humanoid=humanoid
local currentAnimTrack
local script=animate
local function playAnimation(name)
 animationCalls+=1
 currentAnimTrack=instance('AnimationTrack',name)
 currentAnimTrack.IsPlaying=true
 currentAnimTrack.Animation=instance('Animation',name)
 currentAnimTrack.Animation.AnimationId='rbxassetid://507770239'
end
local function playEmote()error('unexpected nondefault emote')end
NATIVE_HANDLER
function hook:Invoke(name)
 table.insert(calls,{at=now,move=humanoid.MoveDirection.Magnitude,speed=root.AssemblyLinearVelocity.Magnitude,pose=pose,name=name})
 if not self.OnInvoke then return coroutine.yield({kind='invoke'})end
 return self.OnInvoke(name)
end
local function escape(value)return value:gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n'):gsub('\r','\\r'):gsub('\t','\\t')end
local function json(value)
 local t=type(value)
 if t=='nil' then return 'null'elseif t=='boolean' or t=='number' then return tostring(value)
 elseif t=='string' then return '"'..escape(value)..'"'
 elseif t=='table' then
  local values={}
  if #value>0 then for _,entry in ipairs(value)do table.insert(values,json(entry))end return '['..table.concat(values,',')..']'end
  local names={}for key in pairs(value)do table.insert(names,key)end table.sort(names)
  for _,key in ipairs(names)do table.insert(values,json(key)..':'..json(value[key]))end return '{'..table.concat(values,',')..'}'
 end
 error('nonserializable result')
end
local H={}
function H:JSONEncode(value)published=value return json(value)end
local game={}
function game:GetService(name)if name=='HttpService' then return H elseif name=='Players' then return {LocalPlayer=player}end error('unexpected service '..name)end
local function print(value)table.insert(messages,value)end
local function pending()
 local n=0 for thread in pairs(threads)do if coroutine.status(thread)~='dead' and not cancelled[thread]then n+=1 end end return n
end
`;
function program(code,before='',after='') {
 return mock.replace('NATIVE_HANDLER',()=>nativeBinding)+'\n'+before+'\nlocal function flowChunk()\n'+code+
 '\nend\ntask.spawn(function()encoded=flowChunk()end)\nadvance(6)\ncheck(#schedulerErrors==0,table.concat(schedulerErrors," | "))\n'+after+
 '\ncheck(encoded~=nil,"flow returned diagnostics")\ncheck(#encoded<3900,"bounded diagnostics")\n'+
 'check(#messages==1 and messages[1]=="[SMASH_WORLD_RESET_EMOTE_V1]"..encoded,"exact durable tag and encoded return")\n'+
 'nativePrint("RETURNED "..encoded)\nnativePrint("CASE_PASS "..checks)\n';
}
const success=String.raw`
check(published.valid and published.idleReady and published.invokeOk and published.invokeCompleted,'valid idle Wave')
check(published.finalIdentity and published.invokeCleanup and pending()==0,'identity and owned cleanup')
check(published.stableSeconds>=.2 and published.stableSamples>=3,'real stable observation streak')
check(published.idleReadyAt<2 and published.invokeAttempts==1 and #calls==1,'bounded precondition and one success attempt')
check(calls[1].at>=published.idleReadyAt and animationCalls==1,'native animation only after readiness')
check(published.lastReturn.pcallOk and published.lastReturn.returnCount==2 and published.lastReturn.firstKind=='boolean' and published.lastReturn.firstValue=='true','packed native true')
check(published.lastReturn.secondKind=='Instance' and published.lastReturn.secondClass=='AnimationTrack' and published.lastReturn.trackPlaying,'actual returned native track')
`;
const failure=String.raw`
check(not published.valid and not published.invokeOk,'failure cannot pass')
check(published.invokeCleanup and pending()==0,'failure cleans owned invocation')
`;
const cases=[
 ['idle-bootstrap','',success],
 ['three-samples-required','waitStep=.25',success],
 ['idle-post-reset','',success,second],
 ['settles-passively',"humanoid.MoveDirection.Magnitude=.2 root.AssemblyLinearVelocity.Magnitude=.2 pose='Running' task.delay(.4,function()humanoid.MoveDirection.Magnitude=0 root.AssemblyLinearVelocity.Magnitude=0 pose='Standing'end)",success+"\ncheck(calls[1].at>=.6,'do not invoke during initial motion')"],
 ['interrupted-streak',"task.delay(.15,function()root.AssemblyLinearVelocity.Magnitude=.2 end)task.delay(.25,function()root.AssemblyLinearVelocity.Magnitude=0 end)",success+"\ncheck(calls[1].at>=.45,'movement resets the stable streak')"],
 ['moving-timeout',"humanoid.MoveDirection.Magnitude=.2 pose='Running'",failure+"\ncheck(not published.idleReady and #calls==0 and published.reason=='idle_precondition_timeout' and published.idleElapsed>=2 and published.idleElapsed<2.051,'bounded moving precondition')"],
 ['velocity-timeout',"root.AssemblyLinearVelocity.Magnitude=.051",failure+"\ncheck(#calls==0,'total velocity gate')"],
 ['airborne',"humanoid.FloorMaterial=Enum.Material.Air",failure+"\ncheck(#calls==0,'grounded gate')"],
 ['dead',"humanoid.Health=0",failure+"\ncheck(#calls==0,'alive gate')"],
 ['anchored',"root.Anchored=true",failure+"\ncheck(#calls==0,'unanchored gate')"],
 ['non-running',"humanoid.state=Enum.HumanoidStateType.Seated",failure+"\ncheck(#calls==0,'Running gate')"],
 ['move-nan',"humanoid.MoveDirection.Magnitude=0/0",failure+"\ncheck(#calls==0,'finite movement')"],
 ['velocity-infinity',"root.AssemblyLinearVelocity.Magnitude=math.huge",failure+"\ncheck(#calls==0,'finite velocity')"],
 ['late-settlement',"root.AssemblyLinearVelocity.Magnitude=.2 task.delay(1.9,function()root.AssemblyLinearVelocity.Magnitude=0 end)",failure+"\ncheck(#calls==0,'late streak never extends idle deadline')"],
 ['character-replaced',"task.delay(.1,function()player.Character=instance('Model','Other',workspace)end)",failure+"\ncheck(not published.finalIdentity and #calls==0,'character identity')"],
 ['humanoid-replaced',"task.delay(.1,function()humanoid.Parent=nil instance('Humanoid','Humanoid',character)end)",failure+"\ncheck(not published.finalIdentity and #calls==0,'Humanoid identity')"],
 ['root-replaced',"task.delay(.1,function()root.Parent=nil instance('Part','HumanoidRootPart',character)end)",failure+"\ncheck(not published.finalIdentity and #calls==0,'root identity')"],
 ['animate-replaced',"task.delay(.1,function()animate.Parent=nil instance('LocalScript','Animate',character)end)",failure+"\ncheck(not published.finalIdentity and #calls==0,'Animate identity')"],
 ['hook-replaced',"task.delay(.1,function()hook.Parent=nil instance('BindableFunction','PlayEmote',animate)end)",failure+"\ncheck(not published.finalIdentity and #calls==0,'hook identity')"],
 ['duplicate-hook',"instance('BindableFunction','PlayEmote',animate)",failure+"\ncheck(#calls==0,'unique public hook')"],
 ['wrong-hook-type',"hook.ClassName='Folder'",failure+"\ncheck(#calls==0,'typed endpoint')"],
 ['native-nil-rejection',"pose='Running'",failure+"\ncheck(published.idleReady and published.invokeCompleted and published.reason=='wave_rejected','physical idle is not fabricated private pose') check(published.firstRejection.firstKind=='nil' and published.lastRejection.returnCount==0 and animationCalls==0,'native nil return preserved') check(published.waveElapsed>=2 and published.waveElapsed<2.11,'original two second retry window') for i=2,#calls do check(math.abs(calls[i].at-calls[i-1].at-.1)<.000001,'original retry spacing') end"],
 ['native-unsupported-false',"emoteNames.wave=nil",failure+"\ncheck(published.firstRejection.firstKind=='boolean' and published.firstRejection.firstValue=='false' and published.lastRejection.returnCount==1 and animationCalls==0,'native false is not readiness success')"],
 ['native-load-error',"playAnimation=function()error('asset unavailable')end",failure+"\ncheck(not published.lastRejection.pcallOk and string.find(published.lastRejection.error,'asset unavailable',1,true)~=nil,'native playback error remains diagnostic')"],
 ['unbound-invoke',"hook.OnInvoke=nil",failure+"\ncheck(published.reason=='invoke_timeout' and not published.invokeCompleted and #calls==1 and published.waveElapsed>=2.5 and published.waveElapsed<2.511,'original outer deadline cancels blocked invoke')"],
 ['slow-return',"local native=hook.OnInvoke hook.OnInvoke=function(...)task.wait(2.4)return native(...)end",success],
 ['too-late-return',"local native=hook.OnInvoke hook.OnInvoke=function(...)task.wait(2.6)return native(...)end",failure+"\ncheck(published.reason=='invoke_timeout' and animationCalls==0,'late call cancelled before native playback')"],
 ['post-call-identity-change',"local native=hook.OnInvoke hook.OnInvoke=function(...)local a,b=native(...)root.Parent=nil return a,b end",failure+"\ncheck(not published.finalIdentity,'replacement after return fails')"],
 ['cancel-failure',"hook.OnInvoke=nil cancelFails=true","check(not published.valid and not published.invokeCleanup and pending()==1,'cleanup failure is required failure')"],
 ['clock-reversal',"rawClock=function(t)return t>=.1 and -1 or t end",failure+"\ncheck(#calls==0 and published.reason=='observation_error','invalid clock fails explicitly')"],
 ['large-diagnostics',"for i=1,25 do instance('StringValue',string.rep('N',90)..i,animate)end playAnimation=function()error(string.rep('E',1000))end",failure+"\ncheck(#published.children<=20 and #published.lastRejection.error<=180,'bounded names and errors')"],
];
const mutations=[
 ['skip-idle',s=>s.replace('if idle(state) then','if true then'),'moving-timeout'],
 ['skip-ground',s=>s.replace('state.alive and state.grounded','state.alive and true'),'airborne'],
 ['skip-health',s=>s.replace('state.alive and state.grounded','true and state.grounded'),'dead'],
 ['skip-anchor',s=>s.replace('state.unanchored and state.running','true and state.running'),'anchored'],
 ['skip-running',s=>s.replace('state.unanchored and state.running','state.unanchored and true'),'non-running'],
 ['loosen-move',s=>s.replace('state.move<=.01','state.move<=1'),'moving-timeout'],
 ['loosen-speed',s=>s.replace('state.speed<=.05','state.speed<=1'),'velocity-timeout'],
 ['omit-stable-time',s=>s.replace('now-stableAt>=stableSeconds','true'),'idle-bootstrap'],
 ['omit-streak-reset',s=>s.replace('else stableAt=nil stableCount=0 end','else end'),'interrupted-streak'],
 ['extend-idle-timeout',s=>s.replace('idleTimeout,stableSeconds,minSamples=2,.2,3','idleTimeout,stableSeconds,minSamples=3,.2,3'),'late-settlement'],
 ['skip-unique-hook',s=>s.replace('and count==1','and true'),'duplicate-hook'],
 ['accept-nil',s=>s.replace('values[2]==true','values[2]==true or values[2]==nil'),'native-nil-rejection'],
 ['accept-false',s=>s.replace('values[2]==true','values[1]'),'native-unsupported-false'],
 ['extend-retry',s=>s.replace('retrySeconds,retryGap,outerSeconds=2,.1,2.5','retrySeconds,retryGap,outerSeconds=2.4,.1,2.5'),'native-nil-rejection'],
 ['change-retry-spacing',s=>s.replace('retrySeconds,retryGap,outerSeconds=2,.1,2.5','retrySeconds,retryGap,outerSeconds=2,.01,2.5'),'native-nil-rejection'],
 ['extend-outer',s=>s.replace('retrySeconds,retryGap,outerSeconds=2,.1,2.5','retrySeconds,retryGap,outerSeconds=2,.1,3'),'too-late-return'],
 ['omit-cancel',s=>s.replace('pcall(deps.cancel,ownedThread)','true'),'unbound-invoke'],
 ['fake-cleanup-success',s=>s.replace("result.invokeCleanup=cancelled and coroutine.status(ownedThread)=='dead'",'result.invokeCleanup=true'),'cancel-failure'],
 ['omit-minimum-samples',s=>s.replace('stableCount>=minSamples','true'),'three-samples-required'],
 ['skip-character-identity',s=>s.replace('p.Character==character','true'),'character-replaced'],
 ['lose-nil-arity',s=>s.replace('table.pack(pcall(deps.invoke))','{pcall(deps.invoke)}'),'native-nil-rejection'],
 ['lose-durable-tag',s=>s.replace("print('[SMASH_WORLD_RESET_EMOTE_V1]'..encoded)","print(encoded)"),'idle-bootstrap'],
];
try {
 for(const [index,step]of flow.steps.entries())if(step.args?.code)compile(step.args.code,'flow-step-'+index);
 for(const [label,before,after,code]of cases)execute(program(code || first,before,after),label);
 for(const [label,mutate,target]of mutations){
  const modified=mutate(first);assert.notEqual(modified,first,'Mutation anchor missing '+label);
  const scenario=cases.find(c=>c[0]===target);
  execute(program(modified,scenario[1],scenario[2]),'mutation-'+label,true);
 }
 // This is a missing-precondition control, not a reconstruction of the unknown full-run failure.
 const originalProgram=program(historical.steps[2].args.code,
  "humanoid.MoveDirection.Magnitude=.2 pose='Running' task.delay(.4,function()humanoid.MoveDirection.Magnitude=0 pose='Standing'end)",
  "check(#calls>0 and calls[1].at>=.6,'historical caller invokes before observed idle')");
 execute(originalProgram,'historical-missing-idle-precondition',true);
 assert(!/:Move\(|:ChangeState\(|:PivotTo\(|\.Anchored\s*=|\.CFrame\s*=|\.OnInvoke\s*=|:SetAttribute\(/.test(first),'Observer cannot manufacture movement, pose, hook or readiness state');
 console.log(JSON.stringify({ok:true,contract:'WorldResetEmoteReadinessV1',flowChunks:flow.steps.filter(s=>s.args?.code).length,
  cases:cases.length,assertions,mutations:mutations.length,historicalControls:1,compiles,executions,
  exactNativeHandlerSHA256:'3e6b8779e88d1feee2511690bdd9879a1496c59b7ebd10ae560996964b49f40a',
  normalization:'Only the two Wave chunks and four additional guards per chunk differ',
  limitation:'Independent fixture hardening; original130/1 native rejection cause remains unknown. Mock native animation is not Studio asset playback.'},null,2));
} finally {
 const resolved=path.resolve(tmp),parent=path.resolve(os.tmpdir());
 assert.equal(path.dirname(resolved),parent);assert(path.basename(resolved).startsWith('smash-world-emote-'));
 fs.rmSync(resolved,{recursive:true,force:true});
}
