import fs from 'node:fs';
import path from 'node:path';
import cp from 'node:child_process';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
// Captured default R15 Animate from smash-emote-diagnostic-20260906.json.
const nativeSourceHash="49eab7530cfc33b8af13b995ae1fa87f482a489b6d108ec2410d12dd19b720f0";
const nativeBinding="script:WaitForChild(\"PlayEmote\").OnInvoke = function(emote)\n\t-- Only play emotes when idling\n\tif pose ~= \"Standing\" then\n\t\treturn\n\tend\n\n\tif emoteNames[emote] ~= nil then\n\t\t-- Default emotes\n\t\tplayAnimation(emote, EMOTE_TRANSITION_TIME, Humanoid)\n\n\t\treturn true, currentAnimTrack\n\telseif typeof(emote) == \"Instance\" and emote:IsA(\"Animation\") then\n\t\t-- Non-default emotes\n\t\tplayEmote(emote, EMOTE_TRANSITION_TIME, Humanoid)\n\n\t\treturn true, currentAnimTrack\n\tend\n\n\t-- Return false to indicate that the emote could not be played\n\treturn false\nend";
const option = (name, fallback) => { const i=process.argv.indexOf(name); return i>=0 ? process.argv[i+1] : fallback; };
const sourceRoot=path.resolve(option('--source-root',process.cwd()));
const baselineRef=option('--baseline-ref','0b061fbae8f80b120054a82462108818535c3c05');
const luau=option('--luau',process.env.LUAU_QA_EXE || 'C:/Users/Jennarong Pinjai/AppData/Local/Temp/codex-luau-smash-0.737/luau.exe');
const clientPath='work/punch-wall-rpg/src/client/PunchWallClient.client.lua';
const current=fs.readFileSync(path.join(sourceRoot,clientPath),'utf8').replace(/\r/g,'');
const baseline=cp.execFileSync('git',['show',baselineRef+':'+clientPath],{cwd:sourceRoot,encoding:'utf8'}).replace(/\r/g,'');
function fragment(source) { const a=source.search(/^do\n\s+local repairGeneration/m),z=source.indexOf('\nlocal PolishConfig',a);assert(a>=0&&z>a);return source.slice(a,z); }
const production=fragment(current);
function execute(code) {
 let input='QAChunk=""\n';for(let i=0;i<code.length;i+=200)input+='QAChunk=QAChunk..'+JSON.stringify(code.slice(i,i+200))+'\n';input+='assert(loadstring(QAChunk))()\n';
 const r=cp.spawnSync(luau,[],{input,encoding:'utf8',maxBuffer:2*1024*1024});
 return {ok:r.status===0&&!r.stderr&&!/stdin:|stack backtrace|SyntaxError/.test(r.stdout)&&r.stdout.includes('CASE_PASS'),output:r.stdout+'\n'+r.stderr};
}
function run(code,label) {const r=execute(code);assert(r.ok,label+'\n'+r.output);return r;}
run('assert(loadstring('+JSON.stringify(current)+')) print("CASE_PASS full-client-compile")','full client compilation');
assert.equal((production.match(/\.OnInvoke\s*=/g)||[]).length,1,'only initial owned shim may assign a callback');
assert.match(production,/fallback\.OnInvoke\s*=\s*function/);
assert(!/\.OnInvoke(?!\s*=)/.test(production),'callback reads are prohibited');
assert(!/:Destroy\(|\.Enabled\s*=|\.Disabled\s*=/.test(production),'callbacks and Animate execution must survive');

const mock=String.raw`
local callbacks,props,threads,canceled={}, {}, {}, {}
local queue,connections,trace={}, {}, {}
local now,sequence,animationCalls,guid=0,0,0,0
local invokeWaiters,childWaiters={},{}
local schedulerErrors={}
local eventDelay=EVENT_DELAY
local newestLookup=NEWEST_LOOKUP
local function schedule(thread,time,args)
 sequence+=1 queue[#queue+1]={thread=thread,time=time,args=args or table.pack(),sequence=sequence}
end
local resume
resume=function(thread,...)
 if canceled[thread] or coroutine.status(thread)=='dead' then return end
 local ok,token=coroutine.resume(thread,...)
 if not ok then schedulerErrors[#schedulerErrors+1]=tostring(token) return end
 if coroutine.status(thread)=='dead' then return end
 assert(type(token)=='table','unsupported mocked yield')
 if token.kind=='wait' then schedule(thread,now+math.max(.001,token.duration))
 elseif token.kind=='invoke' then invokeWaiters[token.hook]=invokeWaiters[token.hook] or {};invokeWaiters[token.hook][#invokeWaiters[token.hook]+1]=thread
 elseif token.kind=='child' then childWaiters[token.parent]=childWaiters[token.parent] or {};childWaiters[token.parent][#childWaiters[token.parent]+1]={thread=thread,name=token.name}
 else error('unknown mocked yield') end
end
local task={}
function task.spawn(fn,...)
 local thread=coroutine.create(fn) threads[thread]=true resume(thread,...) return thread
end
function task.delay(seconds,fn)
 local thread=coroutine.create(fn) threads[thread]=true schedule(thread,now+seconds) return thread
end
function task.wait(seconds)return coroutine.yield({kind='wait',duration=seconds or .01})end
function task.cancel(thread)
 canceled[thread]=true
 if coroutine.status(thread)~='dead' then assert(coroutine.close(thread)) end
end
local function advance(time)
 local guard=0
 while true do
  table.sort(queue,function(a,b)return a.time==b.time and a.sequence<b.sequence or a.time<b.time end)
  local next=queue[1] if not next or next.time>time then break end
  table.remove(queue,1) now=next.time resume(next.thread,table.unpack(next.args,1,next.args.n))
  guard+=1 assert(guard<20000,'scheduler did not remain bounded')
 end
 now=time
 assert(#schedulerErrors==0,table.concat(schedulerErrors,' | '))
end
local os={clock=function()return now end}
local function signal(owner,kind)
 local handlers={}
 local sig={}
 function sig:Connect(fn)
  local c={Connected=true,fn=fn,owner=owner,kind=kind}
  function c:Disconnect()self.Connected=false end
  handlers[#handlers+1]=c connections[#connections+1]=c return c
 end
 function sig:Fire(...)
  local args=table.pack(...)
  for _,c in ipairs(table.clone(handlers))do
   if c.Connected then
    local fn=function()if c.Connected then c.fn(table.unpack(args,1,args.n))end end
    if eventDelay>0 then task.delay(eventDelay,fn)else task.spawn(fn)end
   end
  end
 end
 return sig
end
local methods={}
function methods:IsA(c)return props[self].ClassName==c end
function methods:GetAttribute(k)return props[self].attrs[k]end
function methods:SetAttribute(k,v)props[self].attrs[k]=v end
function methods:GetChildren()return table.clone(props[self].children)end
function methods:FindFirstChild(name)
 local found
 for _,child in ipairs(props[self].children)do if child.Name==name then found=child if not newestLookup then break end end end
 return found
end
function methods:WaitForChild(name)
 local found=self:FindFirstChild(name)
 if found then return found end
 return coroutine.yield({kind='child',parent=self,name=name})
end
function methods:Destroy()
 self.Parent=nil props[self].destroyed=true callbacks[self]=nil
end
function methods:Invoke(...)
 while not callbacks[self]do coroutine.yield({kind='invoke',hook=self})end
 return callbacks[self](...)
end
local Instance={}
function Instance.new(class)
 local n={} props[n]={Name=class,ClassName=class,attrs={},children={}}
 props[n].ChildAdded=signal(n,'ChildAdded') props[n].AncestryChanged=signal(n,'AncestryChanged')
 return setmetatable(n,{__index=function(self,key)
  if key=='OnInvoke'then error('OnInvoke is write-only')end
  return methods[key]or props[self][key]
 end,__newindex=function(self,key,value)
  if key=='OnInvoke'then
   callbacks[self]=value
   for _,thread in ipairs(invokeWaiters[self] or {})do schedule(thread,now)end
   invokeWaiters[self]={} return
  end
  if key=='Parent'then
   local old=props[self].Parent
   if old then for i,c in ipairs(props[old].children)do if c==self then table.remove(props[old].children,i)break end end end
   props[self].Parent=value
   if value then
    props[value].children[#props[value].children+1]=self value.ChildAdded:Fire(self)
    for _,waiting in ipairs(childWaiters[value] or {})do
     if waiting.name==self.Name then schedule(waiting.thread,now+eventDelay,table.pack(self))waiting.name=''end
    end
   end
   self.AncestryChanged:Fire(self,value) return
  end
  props[self][key]=value
 end})
end
local HttpService={GenerateGUID=function()guid+=1 return 'test-guid-'..guid end}
local workspace=Instance.new('Workspace')
local function newCharacter()
 local char=Instance.new('Model') char.Name='Character' char.Parent=workspace
 local anim=Instance.new('LocalScript')anim.Name='Animate'anim.Parent=char return char,anim
end
local character,animate=newCharacter()
local player={Character=character,CharacterAdded=signal(nil,'CharacterAdded'),CharacterRemoving=signal(nil,'CharacterRemoving')}
local function engineChild(parent)
 local hook=Instance.new('BindableFunction')hook.Name='PlayEmote'hook.Parent=parent or animate return hook
end
local function nativeInstall(target, initialPose)
 local script=target or animate local pose=initialPose or 'Standing' local emoteNames={wave=false} local EMOTE_TRANSITION_TIME=.1 local Humanoid={} local currentAnimTrack
 local function playAnimation(name)animationCalls+=1 currentAnimTrack={Name=name}end
 local function playEmote()error('probe must never play a nondefault animation')end
 NATIVE_BINDING
 return function(value)pose=value end
end
local function activeConnections(owner,kind)
 local count=0 for _,c in ipairs(connections)do if c.Connected and (not owner or c.owner==owner) and (not kind or c.kind==kind)then count+=1 end end return count
end
local function pendingInvokes()
 local count=0 for _,list in pairs(invokeWaiters)do for _,thread in ipairs(list)do if not canceled[thread] and coroutine.status(thread)~='dead'then count+=1 end end end return count
end
local function publicCount(target)
 local count=0 for _,child in ipairs((target or animate):GetChildren())do if child.Name=='PlayEmote'then count+=1 end end return count
end
local function assertWave(target)
 assert(animationCalls==0,'readiness probe played an animation')
 assert(publicCount(target)==1,'exactly one public emote hook required')
 local hook=(target or animate):FindFirstChild('PlayEmote') local result={done=false}
 local thread=task.spawn(function()result.value=hook:Invoke('wave')result.done=true end)
 advance(now+.2)
 assert(result.done and result.value==true,'public native wave must complete with true')
 assert(animationCalls==1,'wave must use one real native callback')
 assert(pendingInvokes()==0,'readiness checks leaked a blocked invocation')
end
local function assertHeld(hook,target)
 assert(not props[hook].destroyed,'held hook instance was destroyed')
 assert(hook.Name=='PlayEmote','held callback object was renamed')
 assert(hook.Parent and hook.Parent.Name=='PunchWallLatePlayEmoteHooks' and hook.Parent.Parent==(target or animate),'late hook must remain in owned character holding')
 assert(hook.Parent:GetAttribute('PunchWallOwnedHookHolding')==true,'foreign holding folder')
end
`;
function scenarioCode(repair,scenario) {
 return mock.replace('EVENT_DELAY',String(scenario.delay || 0)).replace('NEWEST_LOOKUP',String(scenario.newest || false)).replace('NATIVE_BINDING',()=>nativeBinding)
  +'\n'+(scenario.before || '')+'\n'+repair+'\n'+scenario.after+'\nprint("CASE_PASS '+scenario.name+'")';
}
const scenarios=[
 {name:'native-nil-probe-response-while-moving',before:"local engine=engineChild() local setPose=nativeInstall(nil,'Running')",after:"advance(3) assert(character:GetAttribute('PunchWallAnimateNativeHookReady')==true,'native nil probe response is ready') setPose('Standing') assertWave()"},
 {name:'unexpected-probe-response-never-promoted',after:"advance(.4) local first=animate:FindFirstChild('PlayEmote') local late=engineChild() late.OnInvoke=function()return true end advance(3.5) assert(animate:FindFirstChild('PlayEmote')==first and character:GetAttribute('PunchWallAnimateNativeHookReady')==false,'unexpected reserved-name response must not hide pending state') assertHeld(late) assert(pendingInvokes()==0)"},
 {name:'existing-native-preserved',before:'local engine=engineChild() nativeInstall() local cb=callbacks[engine]',after:"advance(7) assert(animate:FindFirstChild('PlayEmote')==engine and callbacks[engine]==cb,'early native callback changed') assertWave()"},
 {name:'early-native-binds-during-probe',before:'local engine=engineChild()',after:"advance(.18) nativeInstall() advance(3) assert(animate:FindFirstChild('PlayEmote')==engine) assertWave()"},
 {name:'fallback-native-before-late',after:"advance(.4) local first=animate:FindFirstChild('PlayEmote') nativeInstall() local cb=callbacks[first] advance(.5) local late=engineChild() advance(3) assert(animate:FindFirstChild('PlayEmote')==first and callbacks[first]==cb) assertHeld(late) assertWave()"},
 {name:'fallback-native-after-late-callback',after:"advance(.4) local first=animate:FindFirstChild('PlayEmote') advance(.5) local late=engineChild() advance(.6) nativeInstall() advance(3) assert(animate:FindFirstChild('PlayEmote')==first) assertHeld(late) assertWave()"},
 {name:'deferred-newest-binds-late-before-handler',delay:.02,newest:true,after:"advance(.4) local first=animate:FindFirstChild('PlayEmote') advance(.5) local late=engineChild() nativeInstall() local cb=callbacks[late] advance(3) assert(animate:FindFirstChild('PlayEmote')==late and callbacks[late]==cb,'native late endpoint must be promoted intact') assertHeld(first) assertWave()"},
 {name:'deferred-oldest-binds-public-before-handler',delay:.02,after:"advance(.4) local first=animate:FindFirstChild('PlayEmote') advance(.5) local late=engineChild() nativeInstall() local cb=callbacks[first] advance(3) assert(animate:FindFirstChild('PlayEmote')==first and callbacks[first]==cb) assertHeld(late) assertWave()"},
 {name:'deferred-newest-binds-after-handler',delay:.02,newest:true,after:"advance(.4) local first=animate:FindFirstChild('PlayEmote') advance(.5) local late=engineChild() advance(.56) nativeInstall() advance(3) assert(animate:FindFirstChild('PlayEmote')==first) assertHeld(late) assertWave()"},
 {name:'waitforchild-native-before-fallback',delay:.02,newest:true,before:'task.spawn(nativeInstall)',after:"advance(.5) local first=animate:FindFirstChild('PlayEmote') local late=engineChild() advance(3) assert(animate:FindFirstChild('PlayEmote')==first) assertHeld(late) assertWave()"},
 {name:'late-after-six-seconds',after:"advance(.4) local first=animate:FindFirstChild('PlayEmote') nativeInstall() advance(6.5) local late=engineChild() advance(7) assert(animate:FindFirstChild('PlayEmote')==first) assertHeld(late) assert(activeConnections(animate,'ChildAdded')==1) assertWave()"},
 {name:'several-late-hooks-preserved',after:"advance(.4) local first=animate:FindFirstChild('PlayEmote') nativeInstall() local duplicates={} for i=1,4 do advance(.5+i*.15) duplicates[i]=engineChild()end advance(7) for _,late in ipairs(duplicates)do assertHeld(late)end assert(animate:FindFirstChild('PlayEmote')==first) assert(activeConnections(animate,'ChildAdded')==1) assertWave()"},
 {name:'probe-timeouts-cancel-and-do-not-mask-false',after:"advance(.4) local first=animate:FindFirstChild('PlayEmote') local late=engineChild() advance(3.5) assert(pendingInvokes()==0,'unbound candidate probe leaked') assert(character:GetAttribute('PunchWallAnimateNativeHookReady')==false,'pending shim must not count as native') local result={done=false} task.spawn(function()result.value=first:Invoke('wave')result.done=true end) advance(3.7) assert(result.done and result.value==false and animationCalls==0,'unready public shim must stay false') assertHeld(late)"},
 {name:'character-removal-cancels-listeners-and-probes',after:"advance(.4) local first=animate:FindFirstChild('PlayEmote') local late=engineChild() advance(.5) character.Parent=nil advance(.7) assert(activeConnections(animate)==0 and activeConnections(character)==0,'removed character retained repair listeners') assert(pendingInvokes()==0,'removed character retained blocked probe') local later=engineChild() advance(7) assert(later.Parent==animate and callbacks[first]~=nil,'disposed repair touched old character')"},
 {name:'character-removing-event-cancels-immediately',after:"advance(.4) engineChild() advance(.5) player.CharacterRemoving:Fire(character) advance(.55) assert(activeConnections(animate)==0 and activeConnections(character)==0,'CharacterRemoving must stop old repair') assert(pendingInvokes()==0,'CharacterRemoving left a blocked probe')"},
 {name:'respawn-generation-stops-old-work',delay:.02,after:"advance(.4) local oldCharacter,oldAnimate=character,animate engineChild() local fresh,newAnimate=newCharacter() player.Character=fresh player.CharacterAdded:Fire(fresh) character,animate=fresh,newAnimate advance(.9) nativeInstall(newAnimate) advance(3) assert(activeConnections(oldAnimate)==0 and activeConnections(oldCharacter)==0,'old repair survived respawn') assert(activeConnections(newAnimate,'ChildAdded')==1,'respawn duplicated hook guard') assertWave(newAnimate)"},
 {name:'animate-removal-cancels-probes',after:"advance(.4) engineChild() advance(.5) animate.Parent=nil advance(.8) assert(activeConnections(animate)==0 and activeConnections(character)==0) assert(pendingInvokes()==0,'removed Animate left blocked probes')"},
 {name:'discovery-stops-at-six-seconds',before:'animate.Parent=nil',after:"advance(6.5) assert(activeConnections(character)==0,'discovery listener survived deadline') animate.Parent=character advance(7) assert(publicCount()==0,'expired discovery installed a hook')"},
 {name:'preexisting-duplicates-select-ready-producer',newest:true,before:'local ready=engineChild() nativeInstall() local unbound=engineChild()',after:"advance(3) assert(animate:FindFirstChild('PlayEmote')==ready,'ready early callback must remain accessible') assertHeld(unbound) assertWave()"}
];
for(const scenario of scenarios)run(scenarioCode(production,scenario),scenario.name);
const oldFailure=execute(scenarioCode(fragment(baseline),scenarios.find(s=>s.name==='fallback-native-before-late')));
assert(!oldFailure.ok,'baseline unexpectedly passes the demonstrated callback-destruction race');
const oldLate=execute(scenarioCode(fragment(baseline),scenarios.find(s=>s.name==='late-after-six-seconds')));
assert(!oldLate.ok,'baseline unexpectedly maintains one hook after its six-second expiry');
const mutations=[
 ['discard-owned-callback',p=>p.replace('holdHook(hook)\n    character:SetAttribute','canonicalHook:Destroy() canonicalHook=hook\n    character:SetAttribute'),'fallback-native-before-late'],
 ['skip-held-native-readiness',p=>p.replace('candidate:IsA("BindableFunction") and probeHook(candidate)','candidate:IsA("BindableFunction") and false'),'deferred-newest-binds-late-before-handler'],
 ['classify-pending-as-native',p=>p.replace('and result.marker ~= pendingSentinel',''),'deferred-newest-binds-late-before-handler'],
 ['omit-timeout-cancellation',p=>p.replace('if not result.completed then\n    cancelThread(thread)','if not result.completed then\n    -- missing cancellation'),'probe-timeouts-cancel-and-do-not-mask-false'],
 ['omit-listener-cleanup',p=>p.replace('for _, connection in ipairs(connections) do connection:Disconnect() end','-- missing connection cleanup'),'character-removal-cancels-listeners-and-probes'],
 ['expire-hook-guard-at-six',p=>p.replace('finishDiscovery()\n   if not animate then','finishDiscovery() stop("Expired")\n   if not animate then'),'late-after-six-seconds'],
 ['remove-character-removing-cleanup',p=>p.replace('then activeRepair.stop("CharacterRemoving") end','then return end'),'character-removing-event-cancels-immediately'],
 ['destroy-held-instead-of-preserve',p=>p.replace('hook.Parent = holding()','hook:Destroy()'),'fallback-native-before-late']
];
for(const [name,mutate,target]of mutations){const changed=mutate(production);assert.notEqual(changed,production,name+' mutation marker missing');run('assert(loadstring('+JSON.stringify(changed)+')) print("CASE_PASS mutant-compiles")',name+' compilation');const result=execute(scenarioCode(changed,scenarios.find(s=>s.name===target)));assert(!result.ok,name+' survived its negative control');}
console.log(JSON.stringify({ok:true,sourceRoot,clientSha256:crypto.createHash('sha256').update(current).digest('hex'),repairSha256:crypto.createHash('sha256').update(production).digest('hex'),nativeSourceHash,nativeBindingHash:crypto.createHash('sha256').update(nativeBinding).digest('hex'),fullClientCompilation:true,scenarios:scenarios.length,baselineFailuresCaught:2,weakeningMutationsCaught:mutations.length,callbackReads:0,callbackWrites:1,studio:'BLOCKED: Coordinator runtime pending'},null,2));
