import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {spawnSync} from 'node:child_process';

const at=process.argv.indexOf('--source-root');
const root=path.resolve(at<0?path.join(import.meta.dirname,'../../..'):process.argv[at+1]);
const relative='work/punch-wall-rpg/src/client/PunchWallClient.client.lua';
const baseline='2a2f14bdf89a48dc6d1894cc7a58c3918b88fe0a';
const source=fs.readFileSync(path.join(root,relative),'utf8').replace(/\r\n?/g,'\n');
const historical=spawnSync('git',['show',`${baseline}:${relative}`],{cwd:root,encoding:'utf8',maxBuffer:4*1024*1024});
assert.equal(historical.status,0,historical.stderr);
const oldSource=historical.stdout.replace(/\r\n?/g,'\n');
function extract(text){
 const marker='-- Complete remote discovery shares one deadline, including folder replacements.';
 const start=text.indexOf(marker)>=0?text.indexOf(marker):text.indexOf('local remotes = ReplicatedStorage:WaitForChild("PunchWallEvents")');
 const end=text.indexOf('\nlocal latestStats = {}',start);
 assert.ok(start>=0&&end>start,'Exact production remote handshake boundary required');
 return text.slice(start,end);
}
const current=extract(source),old=extract(oldSource);
const candidates=[process.env.LUAU_COMMAND,...fs.readdirSync(os.tmpdir()).filter(n=>n.startsWith('codex-luau-')).sort().reverse().map(n=>path.join(os.tmpdir(),n,process.platform==='win32'?'luau.exe':'luau')),'luau'];
const luau=candidates.find(p=>p&&spawnSync(p,['--help']).status===0);
assert.ok(luau,'BLOCKED: official Luau CLI required');
const compiler=process.env.LUAU_COMPILE_COMMAND||path.join(path.dirname(luau),process.platform==='win32'?'luau-compile.exe':'luau-compile');
const temporary=fs.mkdtempSync(path.join(os.tmpdir(),'smash-startup-deadline-'));
let compiled=0,assertions=0,mutations=0;
function compile(label,code,optimization='-O1'){
 const file=path.join(temporary,`${label}.luau`);fs.writeFileSync(file,code);
 const result=spawnSync(compiler,[optimization,file],{encoding:'utf8',maxBuffer:8*1024*1024});
 assert.equal(result.status,0,`${label}: ${result.stderr}`);compiled++;return file;
}
function execute(label,code,expectedFailure){
 const file=compile(label,code);
 const result=spawnSync(luau,[file],{encoding:'utf8',timeout:15000,maxBuffer:1024*1024});
 if(expectedFailure){
  assert.notEqual(result.status,0,`${label} unexpectedly passed`);
  assert.match(result.stderr,/ASSERT:/,`${label} must fail a behavior assertion, not syntax or mock infrastructure: ${result.stderr}`);
  mutations++;
 }else{
  assert.equal(result.status,0,`${label}: ${result.stdout}\n${result.stderr}`);
  assertions+=Number(result.stdout.match(/STARTUP_PASS (\d+)/)?.[1]||0);
 }
}
const fixture=String.raw`
local assertions=0
local function check(value,label)assert(value,'ASSERT: '..label)assertions+=1 end
local names={'Notify','StatsChanged','ActionRequest','Feedback'}
local function runCase(options)
 local now=options.startAt or 0 local started=now local warnings={}local waits={}local events={}local lookupCount=0
 local onFind=options.onFind local Instances={createdByClient=0}local task={}local os={clock=function()return now end}
 local function instance(name,class)
  local object={Name=name,ClassName=class,Parent=nil,children={}}
  function object:IsA(wanted)return self.ClassName==wanted end
  function object:FindFirstChild(wanted)
   lookupCount+=1
   local result=self.children[wanted]
   if result and result.Parent~=self then result=nil end
   if onFind then result=onFind(self,wanted,result,{clock=function()return now end,setClock=function(v)now=v end})end
   return result
  end
  function object:WaitForChild(wanted,timeout)
   local began=now local warned=false
   while true do
    local found=self:FindFirstChild(wanted)if found then return found end
    if timeout and now-began>=timeout then return nil end
    if not timeout and now-began>=5 and not warned then table.insert(warnings,'Infinite yield possible: '..self.Name..':'..wanted)warned=true end
    task.wait(.01)
   end
  end
  return object
 end
 local ReplicatedStorage=instance('ReplicatedStorage','ReplicatedStorage')
 local function attach(parent,child)
  if child.Parent then child.Parent.children[child.Name]=nil end
  local previous=parent.children[child.Name]if previous then previous.Parent=nil end
  parent.children[child.Name]=child child.Parent=parent return child
 end
 local function folder(complete,class)
  local f=instance('PunchWallEvents',class or 'Folder')
  for _,name in ipairs(names)do if complete or name~='Feedback'then attach(f,instance(name,'RemoteEvent'))end end
  return f
 end
 local ctx={storage=ReplicatedStorage,instance=instance,attach=attach,folder=folder}
 function ctx.after(seconds,callback)table.insert(events,{at=started+seconds,callback=callback})end
 function ctx.setOnFind(callback)onFind=callback end
 local expected=options.setup(ctx)
 table.sort(events,function(a,b)return a.at<b.at end)
 function task.wait(seconds)table.insert(waits,seconds)return coroutine.yield(seconds)end
 local Instance={new=function()Instances.createdByClient+=1 error('Client must never create a remote substitute')end}
 local function warn(message)table.insert(warnings,message)end
 local co=coroutine.create(function()
 HANDSHAKE
  return {folder=remotes,Notify=notifyRemote,StatsChanged=statRemote,ActionRequest=actionRemote,Feedback=feedbackRemote,at=now}
 end)
 local ok,value=coroutine.resume(co)local iterations=0
 while ok and coroutine.status(co)~='dead' and now-started<25 and iterations<10000 do
  iterations+=1
  local wake=now+(value or .01)
  if options.oversleep and iterations==1 then wake+=options.oversleep end
  while events[1]and events[1].at<=wake do local event=table.remove(events,1)now=event.at event.callback(ctx)end
  now=wake ok,value=coroutine.resume(co)
 end
 return {ok=ok and coroutine.status(co)=='dead',error=not ok and tostring(value)or nil,bound=ok and coroutine.status(co)=='dead'and value or nil,
  blocked=coroutine.status(co)~='dead',elapsed=now-started,warnings=warnings,waits=waits,lookups=lookupCount,created=Instances.createdByClient,expected=expected,context=ctx}
end
local function validSet(result)
 local b=result.bound if not result.ok or not b or not b.folder or b.folder.ClassName~='Folder' or b.folder.Parent~=result.context.storage then return false end
 for _,name in ipairs(names)do if not b[name]or b[name].ClassName~='RemoteEvent'or b[name].Parent~=b.folder or b.folder.children[name]~=b[name]then return false end end
 return result.context.storage.children.PunchWallEvents==b.folder
end
local function timedOut(result,detail)
 return not result.ok and not result.blocked and result.error~=nil and string.find(result.error,'Client startup timed out',1,true)~=nil
  and string.find(result.error,detail,1,true)~=nil
end
local function partial(ctx)return ctx.attach(ctx.storage,ctx.folder(false))end
local function complete(ctx)return ctx.attach(ctx.storage,ctx.folder(true))end
`;
const currentCases=String.raw`
local immediate=runCase({setup=complete})
check(validSet(immediate)and immediate.elapsed==0 and #immediate.waits==0,'complete valid set binds immediately without scheduler delay')
check(immediate.created==0 and #immediate.warnings==0,'no client-owned substitutes or suppressed startup warning path')
local missingFolder=runCase({setup=function()end})
check(timedOut(missingFolder,'PunchWallEvents missing')and missingFolder.elapsed>=20 and missingFolder.elapsed<=20.001,'missing folder fails explicitly at one total deadline')
local missing=runCase({setup=partial})
check(timedOut(missing,'Feedback missing')and missing.elapsed>=20 and missing.elapsed<=20.001,'permanently missing Feedback terminates instead of yielding indefinitely')
check(missing.bound==nil and missing.created==0,'missing dependency never exposes partial handles or creates replacements')
for _,seconds in ipairs({.013,1.25,6,19.9})do
 local delayed=runCase({setup=function(ctx)local f=partial(ctx)ctx.after(seconds,function()ctx.attach(f,ctx.instance('Feedback','RemoteEvent'))end)return f end})
 check(validSet(delayed)and delayed.elapsed>=seconds and delayed.elapsed<=seconds+.051,'delayed arrival binds at next bounded startup observation')
 check(#delayed.warnings==0 and delayed.created==0,'delayed greater-than-five-second arrival needs no infinite-yield warning or substitute')
end
local folderArrival=runCase({setup=function(ctx)ctx.after(6,function()complete(ctx)end)end})
check(validSet(folderArrival)and folderArrival.elapsed>=6 and folderArrival.elapsed<=6.051,'delayed folder and children share the same bounded discovery')
local wrongFolder=runCase({setup=function(ctx)return ctx.attach(ctx.storage,ctx.folder(true,'Model'))end})
check(timedOut(wrongFolder,'expected Folder, got Model'),'wrong folder type cannot bind')
for _,name in ipairs(names)do
 local wrong=runCase({setup=function(ctx)local f=complete(ctx)ctx.attach(f,ctx.instance(name,'BindableEvent'))return f end})
 check(timedOut(wrong,name..' expected RemoteEvent, got BindableEvent'),'wrong type rejected independently for '..name)
end
local repaired=runCase({setup=function(ctx)local f=complete(ctx)ctx.attach(f,ctx.instance('Feedback','BindableEvent'))ctx.after(6,function()ctx.attach(f,ctx.instance('Feedback','RemoteEvent'))end)return f end})
check(validSet(repaired)and repaired.elapsed>=6 and repaired.elapsed<=6.051,'authoritative repair of wrong type is accepted within original deadline')
local replaced=runCase({setup=function(ctx)local first=partial(ctx)ctx.after(6,function()complete(ctx)end)return first end})
check(validSet(replaced)and replaced.bound.folder~=replaced.expected and replaced.elapsed>=6 and replaced.elapsed<=6.051,'folder replacement discards all previously captured handles')
local repeated=runCase({setup=function(ctx)partial(ctx)for _,t in ipairs({4,8,12,16,19.5})do ctx.after(t,function()partial(ctx)end)end end})
check(timedOut(repeated,'Feedback missing')and repeated.elapsed<=20.001,'repeated folder replacements cannot restart the deadline')
for _,seconds in ipairs({20,20.01,21})do
 local late=runCase({setup=function(ctx)local f=partial(ctx)ctx.after(seconds,function()ctx.attach(f,ctx.instance('Feedback','RemoteEvent'))end)end})
 check(timedOut(late,'Feedback missing')and not late.bound and late.elapsed<=20.001,'arrival at or after the deadline cannot bind')
end
local stall=runCase({oversleep=21,setup=function(ctx)local f=partial(ctx)ctx.after(20.5,function()ctx.attach(f,ctx.instance('Feedback','RemoteEvent'))end)end})
check(timedOut(stall,'Feedback missing')and not stall.bound,'scheduler oversleep cannot accept a late complete set')
local crossing=runCase({setup=function(ctx)local f=complete(ctx)local once=false ctx.setOnFind(function(parent,name,result,clock)
 if parent==f and name=='Feedback'and not once then once=true clock.setClock(20.01)end return result end)return f end})
check(timedOut(crossing,'complete remote set arrived after deadline'),'deadline is rechecked after discovery before binding')
local childReplaced=runCase({setup=function(ctx)local f=complete(ctx)local once=false ctx.setOnFind(function(parent,name,result)
 if parent==f and name=='Feedback'and not once then once=true ctx.attach(f,ctx.instance('Feedback','RemoteEvent'))end return result end)return f end})
check(validSet(childReplaced)and childReplaced.elapsed>=.05,'captured child replaced during discovery is discarded and reacquired')
local childRenamed=runCase({setup=function(ctx)local f=complete(ctx)local once=false ctx.setOnFind(function(parent,name,result)
 if parent==f and name=='Feedback'and not once then
  once=true result.Name='RetiredFeedback' f.children.RetiredFeedback=result
  local replacement=ctx.instance('Feedback','RemoteEvent')replacement.Parent=f f.children.Feedback=replacement
 end return result end)return f end})
check(validSet(childRenamed)and childRenamed.elapsed>=.05,'current named-child identity is verified even when retired handle keeps the same parent')
local folderReplaced=runCase({setup=function(ctx)local f=complete(ctx)local once=false ctx.setOnFind(function(parent,name,result)
 if parent==f and name=='Feedback'and not once then once=true complete(ctx)end return result end)return f end})
check(validSet(folderReplaced)and folderReplaced.bound.folder~=folderReplaced.expected and folderReplaced.elapsed>=.05,'captured folder replaced during discovery is discarded before binding')
local newParent=runCase({setup=function(ctx)local f=complete(ctx)local other=ctx.instance('Other','Folder')local once=false
 ctx.setOnFind(function(parent,name,result)if parent==f and name=='Feedback'and not once then once=true result.Parent=other end return result end)
 ctx.after(.1,function()ctx.attach(f,ctx.instance('Feedback','RemoteEvent'))end)return f end})
check(validSet(newParent)and newParent.elapsed>=.1,'a child with changed current parent cannot be retained')
local offset=runCase({startAt=500,setup=partial})
check(timedOut(offset,'Feedback missing')and offset.elapsed<=20.001,'deadline measures startup elapsed time, not absolute process uptime')
for _,result in ipairs({missing,missingFolder,wrongFolder,repeated,offset})do
 check(result.lookups<=5000 and #result.waits<=402,'missing dependency discovery has bounded startup work')
 for _,seconds in ipairs(result.waits)do check(seconds>0 and seconds<=.05,'poll delay respects remaining deadline and fifty-millisecond cap')end
end
print('STARTUP_PASS '..assertions)
`;
const historicalCases=String.raw`
local delayed=runCase({setup=function(ctx)local f=partial(ctx)ctx.after(6,function()ctx.attach(f,ctx.instance('Feedback','RemoteEvent'))end)end})
check(validSet(delayed)and #delayed.warnings>0,'baseline reproduces greater-than-five-second warning despite eventual arrival')
local missing=runCase({setup=partial})
check(missing.blocked and missing.elapsed>=25 and #missing.warnings>0,'baseline reproduces unbounded missing Feedback')
local replaced=runCase({setup=function(ctx)partial(ctx)ctx.after(6,function()complete(ctx)end)end})
check(replaced.blocked and #replaced.warnings>0,'baseline retains obsolete folder and cannot see replacement Feedback')
local wrong=runCase({setup=function(ctx)local f=complete(ctx)ctx.attach(f,ctx.instance('Feedback','BindableEvent'))end})
check(wrong.ok and not validSet(wrong),'baseline exposes wrong-type handle without validating complete typed set')
print('STARTUP_PASS '..assertions)
`;
try{
 for(const optimization of ['-O0','-O1','-O2'])compile(`full-client-${optimization.slice(1)}`,source,optimization);
 execute('actual-startup',fixture.replace('HANDSHAKE',current)+currentCases);
 execute('historical-startup',fixture.replace('HANDSHAKE',old)+historicalCases);
 const changes=[
  ['extended-deadline','local deadline = startedAt + 20','local deadline = startedAt + 30'],
  ['deadline-reset-on-replacement','local candidate = ReplicatedStorage:FindFirstChild("PunchWallEvents")','deadline = os.clock() + 20 local candidate = ReplicatedStorage:FindFirstChild("PunchWallEvents")'],
  ['accept-late-after-discovery','if os.clock() < deadline then','if true then'],
  ['wrong-folder-accepted','not candidate:IsA("Folder")','false'],
  ['wrong-remote-accepted','not remote:IsA("RemoteEvent")','false'],
  ['missing-dependency-accepted','if #problems == 0 then','if true then'],
  ['unbounded-poll-delay','task.wait(math.min(0.05, remaining))','task.wait(1)'],
  ['no-current-child-check','remote.Parent ~= candidate or candidate:FindFirstChild(requiredNames[index]) ~= remote','false'],
  ['parent-validation-removed','elseif remote.Parent ~= candidate then','elseif false then'],
  ['folder-reacquisition-removed','local candidate = ReplicatedStorage:FindFirstChild("PunchWallEvents")','local candidate = firstCandidate'],
  ['missing-name-diagnostic-removed','table.insert(problems, name .. " missing")','table.insert(problems, "dependency missing")'],
  ['absolute-instead-of-elapsed-deadline','local deadline = startedAt + 20','local deadline = 20'],
 ];
 for(const [label,from,to]of changes){
  assert.ok(current.includes(from),label);
  let weakened=current.replace(from,to);
  if(label==='parent-validation-removed')weakened=weakened.replace('remote.Parent ~= candidate or candidate:FindFirstChild(requiredNames[index]) ~= remote','false');
  if(label==='folder-reacquisition-removed')weakened=weakened.replace('while os.clock() < deadline do','local firstCandidate = ReplicatedStorage:FindFirstChild("PunchWallEvents")\n\twhile os.clock() < deadline do');
  execute(`mutation-${label}`,fixture.replace('HANDSHAKE',weakened)+currentCases,true);
 }
 console.log(JSON.stringify({ok:true,baseline,compiled,executedAssertions:assertions,compilingMutationRejections:mutations,
  historicalCases:4,scope:'Exact extracted startup handshake and deterministic arrival/lifetime/deadline controls; native runtime pending.'},null,2));
}finally{
 assert.equal(path.dirname(path.resolve(temporary)),path.resolve(os.tmpdir()));
 assert.ok(path.basename(temporary).startsWith('smash-startup-deadline-'));
 fs.rmSync(temporary,{recursive:true,force:true});
}
