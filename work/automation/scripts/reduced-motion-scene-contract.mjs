#!/usr/bin/env node
// Offline only. Execute the exact scene flow against production egg creation,
// owner/pity decisions, twenty-cycle loop and natural expiry scheduler.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
const root=path.resolve(import.meta.dirname,'../../..');
const read=name=>fs.readFileSync(path.join(root,name),'utf8').replace(/\r/g,'');
const server=read('work/punch-wall-rpg/src/server/PunchWallBootstrap.server.lua');
const config=read('work/punch-wall-rpg/src/shared/GameConfig.lua');
const flowPath='work/automation/flows/reduced-motion-performance.json';
const flow=JSON.parse(read(flowPath));
const old=spawnSync('git',['show',`ad3e2bb:${flowPath}`],{cwd:root,encoding:'utf8'});
assert.equal(old.status,0,old.stderr);
const baseline=JSON.parse(old.stdout);
function block(text,start,end){const a=text.indexOf(start),b=text.indexOf(end,a+start.length);assert(a>=0&&b>a,start);return text.slice(a,b);}
const final=flow.steps.find(step=>step.saveAs==='reducedSceneDiagnostics');
function verifyFlowShape(candidate){
 for(let i=3;i<=7;i++)assert.deepEqual(candidate.steps[i],baseline.steps[i],'original reduced-motion and camera gates must remain unchanged');
 assert(candidate.steps[2].args.code.endsWith(baseline.steps[2].args.code),'initial deterministic actions remain unchanged');
 const step=candidate.steps.find(s=>s.saveAs==='reducedSceneDiagnostics');
 assert(step&&step.timeoutMs===60000,'bounded long scene call');
 const code=step.args.code,destruction=code.indexOf("command:Invoke('BreakWallCycles','Brick Wall',20)");
 assert(destruction>0&&code.includes('cycles.completed==20'),'original twenty cycles are attested');
 assert(code.indexOf('verifyEphemeralSeed(player,root,game.ServerStorage)')<code.indexOf("command:Invoke('Reset')"),'ephemeral guard precedes Reset');
 assert(code.includes('PetDropPity=config.PityBreaks-1'),'pity seeded through original SetStats path');
 assert(!/:Destroy\s*\(|command:Invoke\s*\(\s*['"](?:Reset|ResetWorld|CollectPetEgg|ForcePetEggDrop)/.test(code.slice(destruction)),'no manual cleanup can mask a scene leak');
 assert(code.includes('local deadline=record.expiresAt+1')&&code.includes('config.LifetimeSeconds<=30'),'finite expiry-derived deadline');
 assert(step.expectRegex.some(v=>v.includes('naturalExpiry'))&&step.expectRegex.some(v=>v.includes('stable')),'natural expiry and exact scene result are required');
 assert.deepEqual(candidate.cleanup,baseline.cleanup,'original stop cleanup preserved');
 return true;
}
verifyFlowShape(flow);
const sourceRoute=block(server,'local function automationSnapshot','local function resetAutomationState');
assert(sourceRoute.includes('result[key] = value'),'completed field is preserved by automation snapshot');
assert(server.includes('if tryDropPetEgg then tryDropPetEgg(contributor, layer, block.Position) end'),'actual destruction contributor route includes pet drops');
assert(server.includes('depthBlockAliases["Brick Wall"]'),'legacy wall alias remains backed by a depth block');
const drops=block(config,'GameConfig.PetDrops = {','\nfunction GameConfig.AllPets');
const makePart=block(server,'local function makePart(','\nlocal function makeVisualPart');
const primitives=block(server,'local function makeBall(','\nlocal function makeWedge');
const clear=block(server,'function petDropRuntime.Clear(','\nfunction petDropRuntime.GroundPosition');
const spawn=block(server,'function petDropRuntime.Spawn(','\nfunction petDropRuntime.Claim');
const drop=block(server,'tryDropPetEgg = function(','\nlocal function equipPet');
const cycleBody=block(server,'\t\telseif action == "BreakWallCycles" then','\n\t\telseif action == "BuyFist" then')
 .replace('\t\telseif action == "BreakWallCycles" then','local function runCycles(target,amount)\n local action="BreakWallCycles"')+'\nend\n';
const setup=String.raw`
local assertions=0
local function check(value,label)assert(value,label)assertions+=1 end
local vm={}local Vector3={}
function Vector3.new(x,y,z)return setmetatable({X=x,Y=y,Z=z},vm)end
Vector3.zero=Vector3.new(0,0,0)
vm.__add=function(a,b)return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z)end
vm.__sub=function(a,b)return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end
vm.__index=function(a,k)if k=='Magnitude'then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z)end end
local function enum(names)local result={}for _,name in ipairs(names)do result[name]=name end return result end
local Enum={Material=enum({'SmoothPlastic','Neon','Metal','CorrodedMetal'}),PartType=enum({'Ball','Cylinder','Block'}),SurfaceType=enum({'Smooth'}),Font=enum({'GothamBlack'}),HighlightDepthMode=enum({'Occluded'}),KeyCode=enum({'E'}),UserInputType={},}
Enum.KeyCode.ButtonX='ButtonX'
local Color3={fromRGB=function(...)return {...}end}
local UDim2={fromOffset=function(...)return {...}end,fromScale=function(...)return {...}end}
local UDim={new=function(...)return {...}end}
local function signal()return {Connect=function()return {Disconnect=function()end}end}end
local methods={}local mt={}
mt.__index=function(object,key)if key=='Parent'then return rawget(object,'_parent')end return methods[key]or rawget(object,key)or methods.FindFirstChild(object,key)end
mt.__newindex=function(object,key,value)
 if key~='Parent'then rawset(object,key,value)return end
 local old=rawget(object,'_parent')if old then for i,child in ipairs(old.children)do if child==object then table.remove(old.children,i)break end end end
 rawset(object,'_parent',value)if value then table.insert(value.children,object)end
end
local Instance={}
function Instance.new(kind)return setmetatable({ClassName=kind,Name=kind,children={},attributes={},Anchored=false,CanCollide=true,CanTouch=true,CanQuery=true,Triggered=signal(),MouseClick=signal()},mt)end
function methods:IsA(kind)return kind==self.ClassName or kind=='BasePart'and self.ClassName=='Part'end
function methods:GetChildren()return table.clone(self.children)end
function methods:GetDescendants()local result={}local function visit(object)for _,child in ipairs(object.children)do table.insert(result,child)visit(child)end end visit(self)return result end
function methods:FindFirstChild(name,recursive)for _,child in ipairs(self.children)do if child.Name==name then return child end end if recursive then for _,child in ipairs(self.children)do local found=child:FindFirstChild(name,true)if found then return found end end end end
function methods:WaitForChild(name)return assert(self:FindFirstChild(name),'missing fixture '..name)end
function methods:FindFirstChildWhichIsA(kind)for _,child in ipairs(self.children)do if child:IsA(kind)then return child end end end
methods.FindFirstChildOfClass=methods.FindFirstChildWhichIsA
function methods:SetAttribute(name,value)self.attributes[name]=value end
function methods:GetAttribute(name)return self.attributes[name]end
function methods:GetFullName()return self.Parent and self.Parent:GetFullName()..'.'..self.Name or self.Name end
function methods:Destroy()for _,child in ipairs(self:GetChildren())do child:Destroy()end self.Parent=nil end
local function object(kind,name,parent)local value=Instance.new(kind)value.Name=name value.Parent=parent return value end
local now,queue,running=1000,{},false
local task={}
function task.spawn(fn)table.insert(queue,{at=now,thread=coroutine.create(fn)})end
local function advance(delta)
 local finish=now+delta local iterations=0
 while true do
  table.sort(queue,function(a,b)return a.at<b.at end)local next=queue[1]
  if not next or next.at>finish+1e-9 then break end
  table.remove(queue,1)now=next.at iterations+=1 assert(iterations<2000,'bounded production scheduler')
  running=true local ok,wait=coroutine.resume(next.thread)running=false assert(ok,tostring(wait))
  if coroutine.status(next.thread)~='dead'then table.insert(queue,{at=now+(wait or 0),thread=next.thread})end
 end
 now=finish
end
function task.wait(delta)if running then return coroutine.yield(delta)end advance(delta)return delta end
local mode='normal'local hits=0 local calls={}local completedOverride
local workspace=object('Workspace','Workspace')
function workspace:GetServerTimeNow()return now end
local root=object('Folder','PunchWallRPG',workspace)
local interactFolder=object('Folder','Interactables',root)
local debris=object('Folder','Depth Physics Debris',root)
local wallsFolder=object('Folder','Walls',root)
local player=object('Player','Player')player.UserId=37
object('PlayerGui','PlayerGui',player)
local storage=object('ServerStorage','ServerStorage')
local stats={}
local function statValue(_,name,fallback)local value=stats[name]return value==nil and fallback or value end
local function setStat(_,name,value)stats[name]=value end
local GameConfig={WorldProgressTarget=75}
local encoded={}local serial=0
local HttpService={}
function HttpService:GenerateGUID()serial+=1 return 'actual-guid-'..serial end
function HttpService:JSONEncode(value)serial+=1 local key='json-'..serial encoded[key]=value return key end
function HttpService:JSONDecode(key)return encoded[key]end
local game={Players={GetPlayers=function()return {player}end},ServerStorage=storage,ReplicatedStorage={GameConfig=GameConfig}}
function game:GetService(name)if name=='HttpService'then return HttpService end if name=='RunService'then return {IsStudio=function()return true end}end end
local require=function(value)return value end
local petDropRuntime={active={},folder=object('Folder','Pet Egg Drops',interactFolder)}
local PolishConfig={Palette={Fail={}}}
local function applyGeneratedMaterial()end
local function petRarityColor()return {}end
local function sendFeedback()end
local function rollPet()return {name='Forest Pup',rarity='Common'}end
function petDropRuntime.GroundPosition()return Vector3.new(0,1.45,0)end
`;
const environment=String.raw`
local wall=object('Part','DepthBlock_L001_C06_R02',wallsFolder)wall.Position=Vector3.new(0,0,-25)
wall:SetAttribute('IsDepthBlock',true)wall:SetAttribute('RequiredLevel',1)wall:SetAttribute('MaxHP',100)
local baselinePart=object('Part','Baseline landmark',root)
local sound=object('Sound','Loaded world sound',root)sound.IsLoaded=true
object('ParticleEmitter','Baseline particles',root)
local depthBlockAliases={['Brick Wall']=wall}local depthBlockContributions={}
local function hitDepthBlock(p,block)
 hits+=1 block:SetAttribute('Broken',true)
 local result=tryDropPetEgg(p,1,block.Position)
 if hits==1 then
  local record=petDropRuntime.active[player.UserId]local model=record and record.model
  if mode=='fake_geometry'then model['Egg Spot 1'].Size=Vector3.new(.9,.58,.18)end
  if mode=='wrong_owner'then model:SetAttribute('OwnerUserId',38)end
  if mode=='fake_expiry'then model:SetAttribute('ExpiresAt',record.expiresAt+5)player:SetAttribute('ActivePetEggExpiresAt',record.expiresAt+5)end
  if mode=='persistent_leak'then local leak=object('Part','Persistent unrelated part',root)leak:SetAttribute('VisualRole','PetDropEgg')end
  if mode=='late_leak'then task.spawn(function()task.wait(8)object('Part','Late persistent part',root)end)end
  if mode=='late_particles'then task.spawn(function()task.wait(8)object('ParticleEmitter','Late persistent emitter',root)end)end
  if mode=='late_unloaded_sound'then task.spawn(function()task.wait(8)sound.IsLoaded=false end)end
  if mode=='missing_baseline'then baselinePart:Destroy()object('Part','Replacement with same count',root)end
  if mode=='unloaded_sound'then sound.IsLoaded=false end
  if mode=='physics_leak'then object('Part','Unexpired physics fragment',debris)end
  if mode=='early_removal'then task.spawn(function()task.wait(7)petDropRuntime.Clear(player,'claimed')end)end
 end
 return result
end
local function hitWall()error('wrong legacy wall route')end
local function resetWallState()error('wrong legacy reset route')end
local wallContributions={}
local function automationSnapshot(_,value)return value end
`;
const command=String.raw`
local command=object('BindableFunction','PunchWallAutomation',storage)
function command:Invoke(action,target,amount)
 table.insert(calls,action)
 if action=='Reset'then petDropRuntime.Clear(player,'automation_reset')stats={Power=1,WallLevel=1,PetDropPity=0}player:SetAttribute('PetDropCooldownUntil',0)return {ok=true}end
 if action=='SetStats'then for k,v in pairs(target)do setStat(player,k,v)end return {ok=true}end
 if action=='BreakWallCycles'then local result=runCycles(target,amount)if completedOverride then result.completed=completedOverride end return result end
 error('unexpected fixture mutation '..action)
end
root:SetAttribute('PersistenceMode','EphemeralStudio')root:SetAttribute('PersistenceStudioDefaultEphemeral',true)root:SetAttribute('PersistenceStudioLiveDataOptIn',false)
player:SetAttribute('ProfileReady',true)player:SetAttribute('ProfilePersistenceState','EphemeralStudio')player:SetAttribute('ProfileWritable',false)
`;
const snapshots=String.raw`
local result=HttpService:JSONDecode(runFlow())
check(result.stable and result.loadedAll and result.naturalExpiry,'exact flow succeeds after production natural expiry')
check(hits==20 and result.completed==20 and result.originalCycles==20,'same twenty production cycles complete')
check(result.fiveSeconds.parts==result.before.parts+7 and result.fiveDelta.added==7 and result.fiveDelta.unexpected==0 and result.fiveDelta.missing==0,'five-second additions are only the seven identified egg parts')
check(result.egg.owner==player.UserId and result.egg.partCount==7 and result.egg.expiresAt-result.egg.spawnedAt==GameConfig.PetDrops.LifetimeSeconds,'actual production identity and lifetime attested')
check(result.fiveAt-result.breakFinishedAt>=5 and result.fiveAt<result.egg.expiresAt,'egg is still present at five seconds')
check(result.afterAt>=result.egg.expiresAt and result.afterAt<=result.egg.expiresAt+1,'wait uses bounded actual expiry')
check(result.removalReason=='expired'and petDropRuntime.active[player.UserId]==nil,'production expiry clears original record')
check(result.after.parts==result.before.parts and result.after.particles==result.before.particles and result.after.sounds==result.before.sounds and result.after.loaded==result.after.sounds and result.after.debris==0,'exact final composition audio and debris restored')
check(result.finalDelta.added==0 and result.finalDelta.missing==0,'final exact part identities restored')
check(#calls==3 and calls[1]=='Reset'and calls[2]=='SetStats'and calls[3]=='BreakWallCycles','no post-destruction cleanup or impulse mutation used')
check(stats.Power==500 and stats.PetDropPity==0,'original Power and authoritative pity path retained')
check(result.egg.expiresAt-result.egg.spawnedAt==24 and GameConfig.PetDrops.MaxActivePerPlayer==1,'current configuration bound remains exact')
print('PASS '..assertions)
`;
function program({flowCode=final.args.code,spawnCode=spawn,clearCode=clear,dropCode=drop,setupCode='',tail=snapshots}={}){
 return [setup,drops,makePart,primitives,clearCode,spawnCode,dropCode,environment,cycleBody,command,setupCode,'local function runFlow()\n'+flowCode+'\nend',tail].join('\n');
}
const candidates=[process.env.LUAU_COMMAND,...fs.readdirSync(os.tmpdir()).filter(n=>n.startsWith('codex-luau-')).sort().reverse().map(n=>path.join(os.tmpdir(),n,'luau.exe')),'luau'];
const luau=candidates.find(p=>p&&spawnSync(p,['--help']).status===0);assert(luau,'BLOCKED: Luau CLI required');
const compiler=process.env.LUAU_COMPILE_COMMAND||path.join(path.dirname(luau),'luau-compile.exe');
const temp=fs.mkdtempSync(path.join(os.tmpdir(),'smash-reduced-scene-')),files=[],results={},mutations=[];
function run(name,text,expected){const file=path.join(temp,name+'.luau');files.push(file);fs.writeFileSync(file,text);const compiled=spawnSync(compiler,['--null',file],{encoding:'utf8'});assert.equal(compiled.status,0,compiled.stderr);const r=spawnSync(luau,[file],{encoding:'utf8',timeout:10000});const output=(r.stdout||'')+(r.stderr||'');if(expected)assert(r.status!==0&&output.includes(expected),name+': '+output);else assert.equal(r.status,0,output);return output;}
try{
 results.production=Number(run('production',program()).match(/PASS (\d+)/)?.[1]);
 const negatives=[['fake_geometry','actual egg shape or size does not match'],['wrong_owner','egg ownership and active drop identity disagree'],['fake_expiry','expiry disagrees with authoritative lifetime'],['persistent_leak','scene instance identity changed beyond the verified egg'],['late_leak','scene instance identity changed beyond the verified egg'],['late_particles','scene composition did not return to expected counts'],['late_unloaded_sound','scene audio is not fully loaded'],['missing_baseline','scene instance identity changed beyond the verified egg'],['unloaded_sound','scene audio is not fully loaded'],['physics_leak','scene instance identity changed beyond the verified egg'],['early_removal','expiry observation is early']];
 for(const [mode,expected]of negatives){run(mode,program({setupCode:`mode='${mode}'`}),expected);results[mode]='rejected';}
 run('partial_cycles',program({setupCode:'completedOverride=19'}),'original twenty destruction cycles did not complete');results.partial_cycles='rejected';
 run('live_opt_in',program({setupCode:"storage:SetAttribute('PunchWallAllowLiveDataStoreAccess',true)"}),'live DataStore opt-in forbids Reset');results.live_opt_in='rejected';
 run('writable_profile',program({setupCode:"player:SetAttribute('ProfileWritable',true)"}),'profile must be ready ephemeral and non-writable');results.writable_profile='rejected';
 run('invalid_lifetime',program({setupCode:'GameConfig.PetDrops.LifetimeSeconds=31'}),'pet lifetime or owner cap contract changed');results.invalid_lifetime='rejected';
 run('nonfinite_lifetime',program({setupCode:'GameConfig.PetDrops.LifetimeSeconds=math.huge'}),'egg did not originate in the observed destruction');results.nonfinite_lifetime='rejected';
 run('invalid_owner_cap',program({setupCode:'GameConfig.PetDrops.MaxActivePerPlayer=2'}),'pet lifetime or owner cap contract changed');results.invalid_owner_cap='rejected';
 const noExpiry=clear.replace('function petDropRuntime.Clear(player, reason)','function petDropRuntime.Clear(player, reason)\n if reason=="expired"then return false end');
 run('expired_survivor',program({clearCode:noExpiry}),'original egg did not expire naturally');results.expired_survivor='rejected';
 const controls=[
  ['ignore_part_identity',t=>t.replace("assert(delta.missing==0 and delta.unexpected==0 and delta.allowedMissing==0 and delta.added==expectedAdded",'assert(true'),'missing_baseline','scene instance identity changed beyond the verified egg'],
  ['ignore_egg_shape',t=>t.replace("assert(object and object:IsA('Part') and object.Shape==shape and (object.Size-size).Magnitude<.00001",'assert(true'),'fake_geometry','actual egg shape or size does not match'],
  ['ignore_owner',t=>t.replace("and owner==player.UserId and id==player:GetAttribute('ActivePetEggDropId')",''),'wrong_owner','egg ownership and active drop identity disagree'],
  ['ignore_natural_reason',t=>t.replace("model.Parent==nil and model:GetAttribute('RemovalReason')=='expired'",'model.Parent==nil').replace('at>=record.expiresAt and at<=record.expiresAt+1.1','at<=record.expiresAt+1.1'),'early_removal','expiry observation is early'],
 ];
 for(const [name,alter,mode,expected]of controls){const changed=alter(final.args.code);assert.notEqual(changed,final.args.code,name);const text=program({flowCode:changed,setupCode:`mode='${mode}'`,tail:`local ok,reason=pcall(runFlow)assert(not ok and tostring(reason):find('${expected}',1,true),'negative oracle must reject ${name}')print('PASS')`});run(name,text,'negative oracle must reject '+name);mutations.push(name);}
 const fakeCleanup=structuredClone(flow);fakeCleanup.steps[8].args.code=fakeCleanup.steps[8].args.code.replace('task.wait(5)',"model:Destroy()\ntask.wait(5)");assert.throws(()=>verifyFlowShape(fakeCleanup),/no manual cleanup/);mutations.push('cleanup_cannot_mask_scene');
 const weakenedCamera=structuredClone(flow);weakenedCamera.steps[7].args.code=weakenedCamera.steps[7].args.code.replace('<=.05','<=500');assert.throws(()=>verifyFlowShape(weakenedCamera),/original reduced-motion/);mutations.push('camera_impulse_gate_unchanged');
 for(const [index,step]of flow.steps.entries())if(step.args?.code){const file=path.join(temp,'flow-'+index+'.luau');files.push(file);fs.writeFileSync(file,step.args.code);const c=spawnSync(compiler,['--null',file],{encoding:'utf8'});assert.equal(c.status,0,c.stderr);}
 console.log(JSON.stringify({ok:true,results,mutations,compiledFlowChunks:flow.steps.filter(s=>s.args?.code).length},null,2));
}finally{for(const file of files)fs.unlinkSync(file);fs.rmdirSync(temp);}
