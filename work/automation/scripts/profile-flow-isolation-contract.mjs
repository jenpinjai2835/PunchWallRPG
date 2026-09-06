#!/usr/bin/env node
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {runFailureCleanup, runAssertion} from './flow_runner.mjs';
import {assertCondition, assertPlaceIdentity, inspectSelectedPlace, waitForDataModels} from './studio_mcp_client.mjs';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const read=p=>fs.readFileSync(path.join(root,p),'utf8').replace(/\r\n?/g,'\n');
const flowPath='work/automation/flows/profile-load-hotfix-public-linked-studio.json';
const runnerPath='work/automation/scripts/flow_runner.mjs';
const flow=JSON.parse(read(flowPath)),runner=read(runnerPath);
const prior=p=>{const r=spawnSync('git',['show','2a2f14b:'+p],{cwd:root,encoding:'utf8'});assert.equal(r.status,0,r.stderr);return r.stdout.replace(/\r\n?/g,'\n');};
const oldFlow=JSON.parse(prior(flowPath)),oldRunner=prior(runnerPath);
const startup=flow.steps.find(s=>s.saveAs==='clientStartupReady');
assert(startup && startup.args.datamodel_type==='Client' && startup.timeoutMs===35000);
const retained=structuredClone(flow);retained.steps=retained.steps.filter(s=>s.saveAs!=='clientStartupReady');delete retained.cleanup;
assert.deepEqual(retained,oldFlow,'Original profile, console, identity, success-stop and post-stop gates changed');
assert.deepEqual(flow.cleanup.map(s=>[s.tool,s.saveAs,s.args?.is_start]),[['get_console_output','failureConsole',undefined],['start_stop_play',undefined,false]]);
assert(!/FireServer|SetAttribute|SetStats|RequestSync|Clear|Reset|WaitForChild/.test(startup.args.code),'Startup observer may not write or manufacture readiness');
const between=(s,a,b)=>{const i=s.indexOf(a),j=s.indexOf(b,i+a.length);assert(i>=0&&j>i,a);return s.slice(i,j);};
const cleanupSource=between(runner,'export async function runFailureCleanup(', 'async function runFlow(');
const runSource=between(runner,'async function runFlow(', 'async function runSelfTest(');
const actionSource=between(runner,'async function runAction(', 'export async function runFailureCleanup(');
const previousCatch=between(oldRunner,'    for (const action of flow.cleanup ?? []) {','    return {\n      ok: false');
const newCatch=between(runner,'    const cleanup = await runFailureCleanup(', '    return {\n      ok: false');
assert.equal(runner.replace(cleanupSource,'').replace(newCatch,previousCatch).replace('      cleanup,\n',''),oldRunner,'Runner changed outside failure cleanup reporting');
const source=read('work/punch-wall-rpg/src/client/PunchWallClient.client.lua');
assert(source.includes('latestStats = payload') && source.includes('widgets.PowerValue.Text = formatNumber(payload.EffectivePower or payload.Power or 0)'));
assert(source.includes('widgets.CoinsValue.Text = formatNumber(payload.Coins or 0)') && source.includes('gui:SetAttribute("OnboardingTutorialVersion", tonumber(payload.TutorialVersion) or 0)'));
assert(source.includes('if action == "Snapshot" then return clientSnapshot() end'));
const server=read('work/punch-wall-rpg/src/server/PunchWallBootstrap.server.lua');
assert(server.includes('addStat(player, "PlaytimeSeconds", 1)'),'An ordinary clock update must supply snapshots without a test request');
const action=new Function('sleep','assertCondition','runAssertion','waitForDataModels','normalizeMouseInputArgs','checkText',actionSource+'\nreturn runAction;')(
 async()=>{},assertCondition,runAssertion,waitForDataModels,()=>{throw Error('Unexpected input');},
 (step,text)=>{for(const pattern of step.expectRegex??[])assert(new RegExp(pattern,'i').test(text),'Expected regex not found: '+pattern);for(const expected of step.expectText??[])assert(text.includes(expected));});
const notice='[PunchWallRPG] Studio session is EPHEMERAL by default; live profile reads and writes are disabled.';
const warning='Infinite yield possible on \'ReplicatedStorage.PunchWallEvents:WaitForChild("Feedback")\'\nStack Begin\nScript \'Players.Test.PlayerScripts.PunchWallClient\', Line 621\nStack End';
const name='PunchWallRPGPlayable_v1_final.rbxlx';
const expected={placeName:'^PunchWallRPGPlayable_v1_final[.]rbxlx$',placeId:'0'};
const selected={name,placeId:'0',datamodelType:'Edit'};
let checks=0;
const check=(condition,message)=>{assert(condition,message);checks++;};
function client(options={}){
 return {mode:options.initialMode??'Edit',calls:[],closed:false,stopCount:0,
  async callTool(tool,args){
   this.calls.push({tool,args});
   if(tool==='start_stop_play'){
    if(!args.is_start&&options.stopError)return {isError:true,text:'injected StopPlay failure'};
    if(!args.is_start)this.stopCount++;
    if(args.is_start || !options.stopNoEdit)this.mode=args.is_start?'Play':'Edit';return {isError:false,text:'ok'};
   }
   if(tool==='get_console_output'){
    if(options.consoleReadError && this.calls.filter(x=>x.tool===tool).length>1)return {isError:true,text:'injected cleanup console read failure'};
    return {isError:false,text:notice+(options.warning===false?'':'\n'+warning)};
   }
   if(tool==='execute_luau'){
    const isEdit=args.datamodel_type==='Edit';
    if(isEdit && this.mode!=='Edit')return {isError:true,text:'datamodel is not available in Edit mode'};
    if(!isEdit && this.mode==='Edit')return {isError:true,text:'datamodel is not available'};
    if(args.code==='return game.Name')return {isError:false,text:isEdit?name:'Game'};
    if(args.code.includes('placeId=tostring(game.PlaceId)')){
     if(isEdit&&options.editReadError&&this.stopCount>0)return {isError:true,text:'injected Edit identity read failure'};
     return {isError:false,text:JSON.stringify({name:isEdit?(options.wrongEditName&&this.stopCount>0?'Wrong.rbxlx':name):'Game',placeId:options.wrongEditId&&this.stopCount>0?'99':'0'})};
    }
    if(args.code===startup.args.code)return {isError:false,text:JSON.stringify({ok:!options.clientNotReady,authoritativeSnapshotReceived:true,hudReflectsSnapshot:!options.clientNotReady,clientSnapshotReady:!options.clientNotReady,observerDisconnected:true})};
    return {isError:false,text:JSON.stringify({ok:true,mode:'EphemeralStudio',defaultEphemeral:true,liveOptIn:false,ready:true,writable:false,state:'EphemeralStudio'})};
   }
   throw Error('Unexpected tool '+tool);
  },close(){this.closed=true;}
 };
}
function cleanupFrom(text){
 return new Function('runAction','inspectSelectedPlace','assertPlaceIdentity','assertCondition',text.replace('export async','async')+'\nreturn runFailureCleanup;')(action,inspectSelectedPlace,assertPlaceIdentity,assertCondition);
}
async function cleanupCases(cleanup){
 const stop={type:'call',tool:'start_stop_play',args:{is_start:false},allowError:true,label:'stop'};
 for(const options of [{},{stopError:true},{stopNoEdit:true},{editReadError:true},{wrongEditName:true},{wrongEditId:true}]){
  const c=client({...options,initialMode:'Play'}),result=await cleanup(c,[stop],{},[],1,[],expected,selected);
  const pass=Object.keys(options).length===0;
  check(result.restored===pass,'cleanup restoration must require stop and exact Edit');
  check(result.actions[0].ok===(!options.stopError&&!options.stopNoEdit),'allowed MCP error or missing Edit cannot be cleanup success');
  check(c.calls.filter(x=>x.args?.code?.includes('placeId=tostring(game.PlaceId)')).every(x=>x.args.datamodel_type==='Edit'),'cleanup identity cannot fall back to Server');
  if(!pass)check(typeof(result.error??result.actions[0].error)==='string','cleanup failure evidence missing');
 }
 const c=client({initialMode:'Play'}),ctx={};let attempted=0;
 const broken={type:'assertNoConsoleErrors',source:'broken',label:'optional failing observation'};ctx.broken=warning;
 const r=await cleanup(c,[broken,stop],ctx,[],1,[],expected,selected);
 check(r.actions.length===2 && r.actions[0].ok===false && r.actions[1].ok && r.stopAcknowledged && r.editVerified,'every cleanup action must run after failure');
 check(r.restored===false,'failed optional cleanup cannot certify complete restoration');
 const none=await cleanup(client(),[],{},[],1,[],expected,selected);
 check(none.restored===false && none.attempted===false,'no cleanup must not certify restoration');
 const readOnly=await cleanup(client(),[{type:'call',tool:'get_console_output',saveAs:'console'}],{},[],1,[],expected,selected);
 check(readOnly.restored===false && readOnly.stopAcknowledged===false,'successful diagnostics alone cannot certify restoration');
}
await cleanupCases(runFailureCleanup);
function runWith(c,definition,cleanup=runFailureCleanup){
 const run=new Function('fs','McpClient','selectStudioStrict','inspectSelectedPlace','assertPlaceIdentity','runAction','runFailureCleanup','summarizeContext',
  runSource+'\nreturn runFlow;')(
  {readFileSync:()=>JSON.stringify({...definition,readinessTimeoutMs:1})},class{constructor(){return c;}},async()=>({id:'owned-id',name}),inspectSelectedPlace,assertPlaceIdentity,action,cleanup,x=>x);
 c.initialize=async()=>{};
 return run('fixture.json','unused',{studioInstanceId:'owned-id',studioName:'^'+name+'$',placeName:expected.placeName,placeId:'0'});
}
const live=client(),result=await runWith(live,flow);
check(!result.ok && result.error.includes('Infinite yield'),'original warning must remain the primary failure');
check(result.cleanup.restored && live.mode==='Edit' && live.closed,'failure must stop and verify Edit before closing MCP');
check(result.context.failureConsole===notice+'\n'+warning && result.consoleClassifications[0].identifiedToolWarningCount===0,'original game warning must remain unfiltered');
const before=client(),historical=await runWith(before,oldFlow);
check(!historical.ok && before.mode==='Play' && !historical.cleanup.restored,'historical missing cleanup must reproduce live contamination');
const stress=JSON.parse(read('work/automation/flows/punch-200-stress.json'));
const contaminated=await runWith(before,stress);
check(!contaminated.ok && contaminated.selectedPlace.datamodelType==='Server' && contaminated.selectedPlace.name==='Game','historical following flow must reproduce Server Game');
check(contaminated.checks.every(label=>!label.includes('run and positively')) && contaminated.cleanup.restored,'exact identity must reject before stress while its cleanup restores Edit');
const clean=client({warning:false}),pass=await runWith(clean,flow);
check(pass.ok && clean.mode==='Edit' && clean.closed && !Object.hasOwn(pass,'cleanup'),'normal success and original post-stop gates changed');
for(const options of [{stopError:true},{stopNoEdit:true},{editReadError:true},{wrongEditName:true},{wrongEditId:true},{consoleReadError:true},{clientNotReady:true}]){
 const c=client(options),r=await runWith(c,flow);
 check(!r.ok && c.closed,'failure or MCP closure was lost');
 if(options.clientNotReady)check(r.error.includes('Expected regex')&&r.context.failureConsole.includes('Infinite yield')&&r.cleanup.restored,'readiness failure must retain console and restore Edit');
 else if(options.wrongEditName||options.wrongEditId)check(!r.cleanup.restored,'identity failure cannot certify restoration');
 else check(r.error.includes('Infinite yield')&&!r.cleanup.restored,'cleanup error replaced or masked primary failure: '+JSON.stringify({options,error:r.error,cleanup:r.cleanup}));
}
const mutations=[];
for(const [label,from,to]of [
 ['allow_error_as_success','{ ...action, allowError: false }','{ ...action }'],
 ['invent_stop_acknowledgement','stopAcknowledged: false','stopAcknowledged: true'],
 ['edit_not_required','&& cleanup.stopAcknowledged && cleanup.editVerified','&& cleanup.stopAcknowledged'],
 ['hide_action_failure','entry.error = String(error.message ?? error).slice(0, 4000);','entry.error = undefined;'],
 ['skip_remaining_cleanup','cleanup.actions.push(entry);','cleanup.actions.push(entry); if (!entry.ok) break;'],
 ['ignore_failed_observation','cleanup.actions.every(action => action.ok)','true'],
 ['server_identity_fallback','{ datamodelTypes: ["Edit"] }','{ datamodelTypes: ["Server", "Edit"] }'],
]){
 assert(cleanupSource.includes(from),label);
 let rejected=false;try{await cleanupCases(cleanupFrom(cleanupSource.replace(from,to)));}catch{rejected=true;}
 check(rejected,'compiled cleanup mutation survived: '+label);mutations.push(label);
}

const program=startup.args.code;
const mocks=String.raw`
local count=0
local function check(ok,message)assert(ok,message)count+=1 end
local function scenario(kind)
 local time=0 local events={} local connections={} local snapshotCalls=0 local remoteSerial=0 local oldFolder
 local function node(name,class)
  local n={Name=name,ClassName=class,children={},Visible=true,Enabled=true,attrs={}}
  function n:IsA(c)return self.ClassName==c end
  function n:FindFirstChild(key,recursive)
   if kind=='read_error' and key=='PlayerGui' and time>.01 then error('injected observer failure')end
   for _,child in ipairs(self.children)do if child.Name==key then return child end end
   if recursive then for _,child in ipairs(self.children)do local found=child:FindFirstChild(key,true)if found then return found end end end
  end
  function n:GetAttribute(key)return self.attrs[key]end
  return n
 end
 local function add(parent,child)child.Parent=parent table.insert(parent.children,child)return child end
 local players=node('Players','Players')local rs=node('ReplicatedStorage','ReplicatedStorage')
 local p=add(players,node('Player','Player'))players.LocalPlayer=p
 p.attrs={ProfileReady=true,ProfileWritable=false,ProfilePersistenceState='EphemeralStudio'}
 local pg=add(p,node('PlayerGui','PlayerGui'))
 local gui=node('PunchWallHUD','ScreenGui')local hud=add(gui,node('PixelPerfectHeroCityHUD','Frame'))
 gui.attrs.OnboardingTutorialVersion=2
 local power=add(hud,node('PowerValue','TextLabel'))power.Text='15'
 local coins=add(hud,node('CoinsValue','TextLabel'))coins.Text='0'
 local a=add(gui,node('PunchWallClientAutomation','BindableFunction'))
 function a:Invoke(command)
  check(command=='Snapshot','observer issued mutating command')snapshotCalls+=1
  if kind=='snapshot_error'then error('injected snapshot failure')end
  return {ok=kind~='snapshot_not_ready',inventory={ok=true},viewport={x=637,y=654},position={x=0,y=3,z=0}}
 end
 local stats=add(p,node('RPGStats','Folder'))
 for name,value in pairs({Power=15,Coins=0,Depth=0,WallLevel=1})do local stat=add(stats,node(name,'NumberValue'))stat.Value=value end
 local payload={Power=15,Coins=0,Depth=0,WallLevel=1,EffectivePower=15.015,TutorialVersion=2}
 local function folder()
  remoteSerial+=1
  local f=node('PunchWallEvents','Folder')
  for _,name in ipairs({'Notify','StatsChanged','ActionRequest','Feedback'})do
   local remote=add(f,node(name,'RemoteEvent'))
   if name=='StatsChanged'then
    remote.OnClientEvent={}
    function remote.OnClientEvent:Connect(callback)
     local c={Connected=true,callback=callback,serial=remoteSerial}
     function c:Disconnect()if kind~='disconnect_failure'then self.Connected=false end end
     table.insert(connections,c)return c
    end
   end
  end
  return f
 end
 local current=add(rs,folder())oldFolder=current
 if kind=='missing_feedback' or kind=='delayed'then
  local feedback=current:FindFirstChild('Feedback')feedback.Parent=nil table.remove(current.children,4)
 end
 if kind=='wrong_remote_class'then current:FindFirstChild('Feedback').ClassName='Folder'end
 if kind=='stale_power'then power.Text='14'end
 if kind=='missing_tutorial_version'then gui.attrs.OnboardingTutorialVersion=nil payload.TutorialVersion=nil end
 if kind=='bad_authority'then payload.Power=16 end
 if kind=='invalid_payload'then payload.EffectivePower=0/0 end
 if kind=='profile_not_ready'then p.attrs.ProfileReady=false end
 local delayed=kind=='delayed' or kind=='replace_stale' or kind=='replaced_player'
 if not delayed then add(pg,gui)end
 local function tick(dt)
  time+=dt
  if kind=='delayed' and time>=.3 and not current:FindFirstChild('Feedback')then add(current,node('Feedback','RemoteEvent'))end
  if kind=='replace_stale' and time>=.15 and current==oldFolder then oldFolder.Parent=nil rs.children={}current=add(rs,folder())end
  if kind=='replaced_player' and time>=.1 then players.LocalPlayer=node('Replacement','Player')end
  if delayed and time>=.6 and not pg:FindFirstChild('PunchWallHUD')then add(pg,gui)end
  if kind~='no_payload'then
   for _,c in ipairs(connections)do
    if c.Connected and not(kind=='replace_stale' and c.serial>1)then c.callback(payload)end
    if kind=='replace_stale' and c.serial==1 and time>.15 then c.callback(payload)end
   end
  end
 end
 local H={JSONEncode=function(_,value)return value end}
 -- Retain production table result without depending on a JSON implementation.
 local services={HttpService=H,ReplicatedStorage=rs,RunService={IsStudio=function()return true end}}
 local game={Players=players,GetService=function(_,name)return services[name]end}
 local task={wait=tick}
 local os={clock=function()return time end}
 local function run()
 __PROGRAM__
 end
 local called,result=pcall(run)
 check(called,'actual startup flow raised instead of returning bounded diagnostics')
 local expected=kind=='ready' or kind=='delayed'
 check(result.ok==expected,'startup readiness verdict differs: '..kind)
 check(time<=25.1,'startup wait exceeded its fixed bound')
 if kind~='disconnect_failure'then
  check(result.observerDisconnected==true,'owned observer not disconnected: '..kind)
  for _,c in ipairs(connections)do check(not c.Connected,'observer leaked: '..kind)end
 else check(result.observerDisconnected==false,'failed disconnect accepted')end
 if expected then
  check(result.authoritativeSnapshotReceived and result.authoritativeValuesMatch and result.hudReflectsSnapshot and result.clientSnapshotReady and snapshotCalls>0,'missing actual authoritative/UI proof')
  check(not result.timedOut,'positive startup marked timed out')
 else
  check(result.ok==false,'invalid startup accepted')
  if kind=='read_error'then check(result.error:find('injected observer failure',1,true)~=nil,'startup failure diagnostic lost')
  elseif kind~='disconnect_failure'then check(result.timedOut==true,'never-ready case was not bounded')end
 end
 if kind=='replace_stale'then check(#connections==2 and result.observedSnapshots>0 and result.authoritativeValuesMatch==false,'old folder callback or payload reused')end
 if kind=='no_payload'then check(snapshotCalls==0,'readiness manufactured without real StatsChanged')end
 return result
end
for _,kind in ipairs({'ready','delayed','missing_feedback','wrong_remote_class','no_payload','stale_power','missing_tutorial_version','bad_authority','invalid_payload','profile_not_ready','snapshot_not_ready','snapshot_error','read_error','disconnect_failure','replace_stale','replaced_player'})do scenario(kind)end
print('CLIENT_STARTUP_OBSERVATION_PASS='..count)
`;
const wrapped=program.replace('local encoded=H:JSONEncode(result)\nassert(#encoded<3500,\'client startup diagnostic exceeds evidence bound\')\nreturn encoded','return H:JSONEncode(result)');
assert.notEqual(wrapped,program,'Only JSON encoding boundary may be adapted for Luau mocks');
const luau=process.env.LUAU_COMMAND || fs.readdirSync(os.tmpdir()).filter(n=>n.startsWith('codex-luau-')).sort().reverse().map(n=>path.join(os.tmpdir(),n,'luau.exe')).find(p=>fs.existsSync(p));
assert(luau,'Luau executable required');
const compiler=process.env.LUAU_COMPILE_COMMAND||path.join(path.dirname(luau),'luau-compile.exe');
const temp=fs.mkdtempSync(path.join(os.tmpdir(),'smash-profile-flow-isolation-'));let compiled=0;
function execute(label,text,expectedFailure=false){
 const file=path.join(temp,label+'.luau');fs.writeFileSync(file,text);
 const compile=spawnSync(compiler,['--null',file],{encoding:'utf8',timeout:15000});assert.equal(compile.status,0,compile.stderr);compiled++;
 const run=spawnSync(luau,[file],{encoding:'utf8',timeout:15000});
 if(expectedFailure)assert.notEqual(run.status,0,label+' mutation survived');else assert.equal(run.status,0,run.stderr+run.stdout);
 return run.stdout;
}
try{
 const productionOutput=execute('client-startup',mocks.replace('__PROGRAM__',()=>wrapped));
 for(const [label,from,to]of [
  ['waive_snapshot_payload','valuesMatch and finite(payload.EffectivePower)','true and finite(payload.EffectivePower)'],
  ['waive_hud_power','power.Text==formatNumber(payload.EffectivePower)','true'],
  ['waive_snapshot_readiness','snapshot.ok==true','true'],
  ['waive_profile_readiness','and snapshotReady and profileReady','and snapshotReady'],
  ['waive_tutorial_version','finite(payload.TutorialVersion) and payload.TutorialVersion>=1','true'],
  ['reuse_replaced_folder_payload','connection=nil observedRemote=stat payload=nil','connection=nil observedRemote=stat'],
  ['omit_observer_disconnect','if connection then connection:Disconnect() end','if false then connection:Disconnect() end'],
 ]){
  assert(wrapped.includes(from),label);execute(label,mocks.replace('__PROGRAM__',()=>wrapped.replace(from,to)),true);mutations.push(label);
 }
 for(const [index,step]of [...flow.steps,...flow.cleanup].entries())if(step.args?.code){
  const target=path.join(temp,'flow-'+index+'.luau');fs.writeFileSync(target,step.args.code);
  const result=spawnSync(compiler,['--null',target],{encoding:'utf8',timeout:15000});assert.equal(result.status,0,result.stderr);compiled++;
 }
 console.log(JSON.stringify({ok:true,checks,mutations,compiled,productionOutput,studioUsed:false,sourceChanged:false,nativeRegression:'pending'},null,2));
}finally{
 assert.equal(path.dirname(fs.realpathSync(temp)),fs.realpathSync(os.tmpdir()));
 fs.rmSync(temp,{recursive:true,force:true});
}
