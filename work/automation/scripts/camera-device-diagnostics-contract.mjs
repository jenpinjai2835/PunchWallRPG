#!/usr/bin/env node
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {runFailureCleanup} from './flow_runner.mjs';

const root=path.resolve(import.meta.dirname,'../../..');
const flowPath='work/automation/flows/punch-camera-device-20.json';
const read=p=>fs.readFileSync(path.join(root,p),'utf8').replace(/\r/g,'');
const flow=JSON.parse(read(flowPath));
const oldResult=spawnSync('git',['show','2a2f14b:'+flowPath],{cwd:root,encoding:'utf8'});
assert.equal(oldResult.status,0,oldResult.stderr);
const old=JSON.parse(oldResult.stdout);
const pageNames=['cameraVisibilityDetail1','cameraVisibilityDetail2','cameraVisibilityDetail3','cameraVisibilityDetail4','cameraRecoveryLast','cameraRecoveryFirst'];
const pageSourcePath='work/automation/flows/camera-tunnel-frame-profile.json';
const frozenResult=spawnSync('git',['show','be79f1640583944462ce10c966d5d6fe2a15732d:'+pageSourcePath],{cwd:root,encoding:'utf8'});
assert.equal(frozenResult.status,0,frozenResult.stderr);
const frozenPageSource=JSON.parse(frozenResult.stdout);
const frozenDeviceResult=spawnSync('git',['show','be79f1640583944462ce10c966d5d6fe2a15732d:'+flowPath],{cwd:root,encoding:'utf8'});
assert.equal(frozenDeviceResult.status,0,frozenDeviceResult.stderr);
const frozenDeviceFlow=JSON.parse(frozenDeviceResult.stdout);
const pages=pageNames.map(name=>{
 const matches=frozenPageSource.cleanup.filter(s=>s.saveAs===name);assert.equal(matches.length,1,name);return matches[0];
});
assert.deepEqual(JSON.parse(read(pageSourcePath)).cleanup.filter(s=>pageNames.includes(s.saveAs)),pages,'approved existing page producers changed');
const client=read('work/punch-wall-rpg/src/client/PunchWallClient.client.lua');
const runner=read('work/automation/scripts/flow_runner.mjs');
function between(s,a,b){const i=s.indexOf(a),j=s.indexOf(b,i+a.length);assert(i>=0&&j>i,a);return s.slice(i,j);}
const names=['desktopCamera','tabletCamera','phoneCamera'];
const samples=flow.steps.filter(s=>names.includes(s.saveAs));
function predicate(code){return between(code,'local metricsValid=',' local diagnostics=');}
// The new immediate camera read is outside, and cannot change, the original predicate.
function currentPredicate(code){return between(code,'local metricsValid=',' local camera=');}
const helper=between(samples[0].args.code,'local function compactCameraDeviceDecision(', '\nlocal H=');
function verifyFlow(candidate){
 const withoutPages=structuredClone(candidate);withoutPages.cleanup=withoutPages.cleanup.slice(6);
 assert.deepEqual(withoutPages,frozenDeviceFlow,'failure pages must be the only change to the approved device flow');
 assert.equal(candidate.steps.length,old.steps.length,'all original fixture and20 punch steps remain');
 assert.equal(candidate.cleanup.length,old.cleanup.length+7,'six bounded diagnostic pages then existing console observation');
 assert.deepEqual(candidate.cleanup.slice(0,6),pages,'six exact approved page codes, targets, bounds and order required');
 assert.deepEqual(candidate.cleanup.slice(7),old.cleanup,'original Stop and viewport cleanup must remain exact');
 for(const page of candidate.cleanup.slice(0,6)){
  assert.equal(page.args.datamodel_type,'Client');assert.equal(page.allowError,true);
  assert(page.args.code.includes('assert(#encoded<3900,'),'diagnostic page must retain strict evidence bound');
  assert(!/task\.|:Invoke|:Fire|:SetAttribute|Instance\.new|\.CFrame\s*=|\.CameraType\s*=/.test(page.args.code),'pages must be read-only and non-yielding');
 }
 const diagnostic=candidate.cleanup[6];
 assert.equal(diagnostic.tool,'get_console_output');assert.equal(diagnostic.saveAs,'cameraFailureConsole');
 assert.equal(diagnostic.allowError,true);assert.equal(diagnostic.timeoutMs,15000);
 assert.equal(diagnostic.args,undefined,'cleanup console must not require a Client DataModel');
 for(let i=0;i<candidate.steps.length;i++){
  const step=candidate.steps[i],before=old.steps[i];
  if(!names.includes(step.saveAs)){assert.deepEqual(step,before);continue;}
  assert.equal(currentPredicate(step.args.code),predicate(before.args.code),'every original inner predicate remains byte-for-byte');
  assert(step.args.code.includes("local encoded=H:JSONEncode(diagnostics) assert(#encoded<3900,'camera decision summary exceeds bound') return encoded"),'bounded result must return before the outer verdict');
  assert(!step.args.code.includes("assert(metricsValid,"),'failed metric must not throw before saveAs');
  assert.equal(between(step.args.code,'local function compactCameraDeviceDecision(', '\nlocal H='),helper,'all three devices share the exact diagnostic producer');
  assert.deepEqual(step.expectRegex.slice(0,-1),before.expectRegex,'every old outer gate remains exact');
  assert.equal(step.expectRegex.length,before.expectRegex.length+1,'one unique flat decision gate');
  const unchanged=structuredClone(step);unchanged.args.code=before.args.code;unchanged.expectRegex=before.expectRegex;assert.deepEqual(unchanged,before);
  const invocations=[...step.args.code.matchAll(/:Invoke\('__RunCamera',(\d+)\)/g)];assert.equal(invocations.length,1);assert.equal(Number(invocations[0][1]),step.saveAs==='desktopCamera'?8:6);
 }
 assert(!/task\.|:Invoke|:Fire|:SetAttribute|Instance\.new|\.CFrame\s*=|\.CameraType\s*=/.test(helper),'diagnostic helper cannot yield, replay input, alter camera, or create state');
}
verifyFlow(flow);

const validity=between(client,'\t\tlocal valid = actions == requested','\t\tlocal visualFailureReasons =');
const resultBuilder=between(client,'\t\tlocal result = {\n\t\t\tvalid = valid,','\t\tgui:SetAttribute("CameraAutomationLastValid"');
const producer=String.raw`
local Enum={CameraType={Custom={Name='Custom'},Scriptable={Name='Scriptable'}}}
local function produce(input,requested)
 local function value(name,fallback)if input[name]~=nil then return input[name]end return fallback end
 local actions=value('actions',requested)local initialOrbitSettled=value('initialOrbitSettled',true)
 local appliedStep=value('maxStep',2.4)local correctionStep=value('maxCorrectionStep',2.4)local escapeStep=value('maxEscapeStep',0)
 local unresolvedSafetyFrames=value('unresolvedSafetyFrames',0)local finishDistance=value('finishDistance',22)local selectedDistance=22
 local angle=value('angle',0)local visibility=value('visibleRatio',1)local insideFrames=value('inside',0)local maxBackwardStep=value('maxBack',0)
 local lead=value('lead',5)local clearVisibility=value('clearRatio',1)local readableVisibility=value('readableRatio',1)
 local settledClearVisibility=value('settledClearRatio',1)local settledReadableVisibility=value('settledReadableRatio',1)
 local camera={CameraType=Enum.CameraType[value('type','Custom')]}
 local attrs={PunchCameraFollowActive=value('followActive',false),PunchCameraHandoffActive=false,PunchCameraGeometryClamped=false,PunchCameraMode=value('mode','CustomPreserved'),PunchCameraUserOrbitDistance=22}
 local gui={}function gui:GetAttribute(key)return attrs[key]end
 local shared={}local visibilityDiagnostics={phases={},longestObscuredRun=0}
 local visualFailureReasons={}local unresolvedSafetySamples=input.unresolvedSafetySamples or {}
 local transientLineOfSightFrames=0 local selectedOrbit=22 local maxCameraStep=2.4
 local maxStepFrom,maxStepTo,maxBackFrom,maxBackTo='0,0,0','0,0,0','0,0,0','0,0,0'
 local settleTimedOut=value('settleTimedOut',false)local maxBackPunch=0 local settledSamples=6 local sampledFrames=56
 local obscurerNames={}local insideNames={}local insideSamples={}
`+validity+resultBuilder+String.raw`
 return result
end
local function encode(value)
 local kind=type(value)
 if kind=='nil'then return 'null'elseif kind=='boolean'then return value and 'true'or'false'elseif kind=='number'then assert(value==value and math.abs(value)<math.huge,'JSON cannot encode nonfinite value')return tostring(value)
 elseif kind=='string'then return '"'..string.gsub(value,'[%z\1-\31\\"]',function(c)if c=='"'then return '\\"'elseif c=='\\'then return '\\\\'else return string.format('\\u%04x',string.byte(c))end end)..'"'
 elseif kind=='table'then local keys={}for key in pairs(value)do table.insert(keys,key)end table.sort(keys,function(a,b)return tostring(a)<tostring(b)end)local out={}for _,key in ipairs(keys)do table.insert(out,encode(tostring(key))..':'..encode(value[key]))end return '{'..table.concat(out,',')..'}'end
 error('unsupported JSON type')
end
local H={}function H:JSONEncode(value)return encode(value)end
`;
const cases=[
 ['good',{},true],['step_boundary',{maxStep:2.65,maxCorrectionStep:2.65,maxEscapeStep:2.65},true],
 ['actions',{actions:1},false],['initial_orbit',{initialOrbitSettled:false},false],
 ['applied_step',{maxStep:2.65001},false],['correction',{maxCorrectionStep:2.65001},false],['escape',{maxEscapeStep:2.65001},false],
 ['physical',{unresolvedSafetyFrames:1},false],['zoom',{finishDistance:22.081},false],['angle',{angle:.25},false],
 ['visibility',{visibleRatio:.8999},false],['inside',{inside:1},false],['backward',{maxBack:.5},false],
 ['camera_type',{type:'Scriptable'},false],['follow',{followActive:true},false],['lead',{lead:1},false],
 ['clear_visibility',{clearRatio:.5499},false],['readability',{readableRatio:.6499},false],
 ['settled_clear',{settledClearRatio:.8999},false],['settled_readable',{settledReadableRatio:.8999},false],
 ['outer_timeout',{settleTimedOut:true},false],['outer_mode',{mode:'WrongMode'},false],
];
function lua(value){if(value===null)return'nil';if(typeof value==='string')return JSON.stringify(value);if(typeof value==='object')return'{'+Object.entries(value).map(([k,v])=>'['+lua(k)+']='+lua(v)).join(',')+'}';return String(value);}
function programFor(step,code=step.args.code){
 const n=step.saveAs==='desktopCamera'?8:6;
 const scenarioTable=cases.map(([name,input])=>'{name='+lua(name)+',input='+lua(input)+'}').join(',');
 return producer+String.raw`
local currentResult,currentInput,invokes
local g={}function g:GetAttribute(key)assert(key=='PunchCameraFollowActive')return currentInput.followActive==true end
g.PunchWallClientAutomation={}function g.PunchWallClientAutomation:Invoke(action,n)assert(action=='__RunCamera'and n==`+n+String.raw`)invokes+=1 return currentResult end
local game={Players={LocalPlayer={PlayerGui={PunchWallHUD=g}}}}function game:GetService(name)assert(name=='HttpService')return H end
local workspace={CurrentCamera={ViewportSize={X=844,Y=332}}}
local function invokeActual()
`+code+String.raw`
end
local function exercise(name,input,result)
 currentInput=input currentResult=result invokes=0
 local encoded=invokeActual()assert(invokes==1,'camera diagnostics replayed the action')assert(#encoded<3900,'primary data was truncated')print(name..'|'..encoded)
end
for _,case in ipairs({`+scenarioTable+String.raw`})do exercise(case.name,case.input,produce(case.input,`+n+String.raw`))end
exercise('missing',{},nil)exercise('wrong_result_type',{},'not a result')
local bad=produce({inside=1},`+n+String.raw`)
bad.nested={metricsValid=true,cameraDeviceContractValid=true,valid=true,visualValid=true,inside=0}
bad.largestEscape={distance=1.8,losClear=true,parts={name='DepthBlock_L017_C07_R05'},data=string.rep('nested',3000)}
exercise('nested_true',{},bad)
local huge=produce({},`+n+String.raw`)huge.reason=string.rep('long reason ',1000)huge.visualFailureReasons={string.rep('reason ',1000)}exercise('bounded_strings',{},huge)
local physical=produce({unresolvedSafetyFrames=1},`+n+String.raw`)
physical.unresolvedSafetySamples={{camera='1,2,3',root='4,5,6',guardPhase='postsimulation-overlap',punch=2,guardAge=.01,renderAge=.03,overlapCount=1,parts={{name='Workspace.PunchWallRPG.Depth Blocks.DepthBlock_L017_C07_R05'}}}}
exercise('physical_detail',{},physical)
local nan=produce({maxBack=0/0},`+n+String.raw`)exercise('nonfinite',{},nan)
local extreme=produce({inside=1},`+n+String.raw`)
for key,value in pairs(extreme)do if type(value)=='number'then extreme[key]=1.234567890123456e308 elseif type(value)=='string'then extreme[key]=string.rep('x',1000)end end
extreme.visualFailureReasons={string.rep('r',1000),string.rep('r',1000),string.rep('r',1000),string.rep('r',1000),string.rep('r',1000)}
extreme.unresolvedSafetySamples={{camera=string.rep('c',1000),root=string.rep('r',1000),guardPhase=string.rep('p',1000),punch=1e308,guardAge=1e308,renderAge=1e308,overlapCount=1e308,parts={{name=string.rep('n',1000)}}}}
exercise('maximum_scalar_payload',{},extreme)
`;
}
const pageCodec=producer.slice(producer.indexOf('local function encode(value)'));
function pageProgram(page,code=page.args.code){
 const index=pageNames.indexOf(page.saveAs),visibility=index<4;
 const expectedAttribute=visibility?'CameraAutomationVisibilityJSON':'CameraAutomationRecoveryJSON';
 const marker=visibility?(index===3?'last':'stage'+(index+1)):(index===4?'last':'first');
 const selected=visibility?(index===3?'doc.last=sample':'doc.stages['+(index+1)+']=sample'):(index===4?'doc.last=sample':'doc.first=sample');
 const envelope=visibility?'page='+(index+1):'record='+lua(marker);
 return pageCodec+String.raw`
local mode,document,reads
function H:JSONDecode(raw)assert(raw=='fixture','injected invalid JSON')return document end
local g={}function g:GetAttribute(name)assert(name==`+lua(expectedAttribute)+String.raw`,'wrong diagnostic attribute')reads+=1 if mode=='missing_attribute'then return nil end if mode=='invalid_json'then return 'invalid' end return 'fixture' end
local pg={}function pg:FindFirstChild(name)assert(name=='PunchWallHUD')if mode~='missing_gui'then return g end end
local game={Players={}}function game:GetService(name)assert(name=='HttpService')return H end
local function invokeActual()
`+code+String.raw`
end
for _,scenario in ipairs({'available','missing_player','missing_gui','missing_attribute','empty_document','invalid_json','bounded_3899','oversized_3900'})do
 mode=scenario reads=0 game.Players.LocalPlayer=mode~='missing_player'and{PlayerGui=pg}or nil
 local sample={marker=`+lua(marker)+String.raw`}
 document={stages={{marker='stage1'},{marker='stage2'},{marker='stage3'}},last={marker='last'},first={marker='first'}}
 if mode=='empty_document'then document={}
 elseif mode=='bounded_3899'or mode=='oversized_3900'then
  sample.pad=''
  local base=H:JSONEncode({`+envelope+String.raw`,available=true,sample=sample})
  sample.pad=string.rep('x',(mode=='bounded_3899' and 3899 or 3900)-#base)
  local doc=document `+selected+String.raw`
 end
 local called,result=pcall(invokeActual)
 if mode=='missing_player'or mode=='missing_gui'then assert(reads==0,'missing GUI should not read attributes')else assert(reads==1,'each page must read one bounded record')end
 if called then assert(type(result)=='string')print(mode..'|'..result)
 else print(mode..'|'..H:JSONEncode({pageError=true,error=tostring(result):sub(1,250)}))end
end
`;
}
function verifyPageResults(page,results){
 const index=pageNames.indexOf(page.saveAs),visibility=index<4,marker=visibility?(index===3?'last':'stage'+(index+1)):(index===4?'last':'first');
 for(const name of ['available','missing_player','missing_gui','missing_attribute','empty_document','bounded_3899']){
  const result=results.get(name);assert(result,name);assert.equal(result.available,name==='available'||name==='bounded_3899');
  if(visibility)assert.equal(result.page,index+1);else assert.equal(result.record,marker);
  if(result.available)assert.equal(result.sample.marker,marker,'wrong page/record selected');else assert(!Object.hasOwn(result,'sample'),'missing record fabricated');
  assert(JSON.stringify(result).length<3900,'unbounded page returned');
 }
 assert.equal(JSON.stringify(results.get('bounded_3899')).length,3899,'near-bound positive must exercise the exact byte boundary');
 assert.equal(results.get('invalid_json').pageError,true,'invalid JSON must remain explicit failure');
 assert.match(results.get('invalid_json').error,/injected invalid JSON/);
 assert.equal(results.get('oversized_3900').pageError,true,'oversized native page must fail before runner truncation');
 assert.match(results.get('oversized_3900').error,/detail exceeds runner context bound/);
}
const luau=[process.env.LUAU_COMMAND,...fs.readdirSync(os.tmpdir()).filter(n=>n.startsWith('codex-luau-')).sort().reverse().map(n=>path.join(os.tmpdir(),n,'luau.exe'))].find(p=>p&&fs.existsSync(p));assert(luau,'Luau runtime is required');
const compiler=process.env.LUAU_COMPILE_COMMAND||path.join(path.dirname(luau),'luau-compile.exe');
const temp=fs.mkdtempSync(path.join(os.tmpdir(),'smash-camera-device-diagnostics-'));let compiled=0;const mutations=[];
function run(name,code,expectFailure=false){const file=path.join(temp,name+'.luau');fs.writeFileSync(file,code);const c=spawnSync(compiler,['--null',file],{encoding:'utf8'});assert.equal(c.status,0,c.stderr);compiled++;const r=spawnSync(luau,[file],{encoding:'utf8',timeout:10000});if(expectFailure){assert.notEqual(r.status,0,'mutant unexpectedly returned');return r;}assert.equal(r.status,0,r.stdout+r.stderr);return new Map(r.stdout.trim().split(/\r?\n/).map(line=>{const split=line.indexOf('|');assert(split>0,line);return[line.slice(0,split),JSON.parse(line.slice(split+1))];}));}
function accepts(step,value){return step.expectRegex.every(expression=>new RegExp(expression,'i').test(JSON.stringify(value)));}
function verifyResults(step,results){
 for(const [name,input,expected]of cases){const result=results.get(name);assert(result,name);assert.equal(result.metricsValid,expected,name+' original predicate');assert.equal(result.cameraDeviceContractValid,expected,name+' unique verdict');assert.equal(accepts(step,result),expected,name+' original outer gates');
  assert.equal(result.viewportWidth,844);assert.equal(result.viewportHeight,332);assert.equal(result.followActiveObserved,input.followActive===true);
  for(const key of ['maxStep','maxCorrectionStep','maxEscapeStep','unresolvedSafetyFrames','physicalUnresolvedFrames','zoomDelta','angle','lead','selectedDistance','finishDistance','configuredOrbit','userOrbitDistance','visibleRatio','clearRatio','readableRatio','settledClearRatio','settledReadableRatio','settledSamples','inside','maxBack','initialOrbitSettled','settleTimedOut','handoffActive','type','mode'])assert(Object.hasOwn(result,key),'missing decision field '+key);
  assert.equal(result.maxStep,input.maxStep??2.4);assert.equal(result.maxCorrectionStep,input.maxCorrectionStep??2.4);assert.equal(result.maxEscapeStep,input.maxEscapeStep??0);assert.equal(result.inside,input.inside??0);
  assert(Object.values(result).every(v=>v===null||typeof v!=='object'),'decision output must stay flat');assert(JSON.stringify(result).length<3900);
 }
 for(const name of ['missing','wrong_result_type','nested_true','physical_detail','nonfinite','maximum_scalar_payload'])assert(!accepts(step,results.get(name)),name+' must remain failed');
 assert.equal(results.get('nested_true').valid,false);assert.equal(results.get('nested_true').visualValid,false);assert(!Object.hasOwn(results.get('nested_true'),'nested'));
 assert.equal(results.get('good').settleTimedOut,false,'false must remain a boolean');assert.equal(results.get('good').followActiveObserved,false);
 assert.equal(results.get('bounded_strings').reason.length,96);assert.equal(results.get('bounded_strings').visualFailureReasons.length,64);assert(accepts(step,results.get('bounded_strings')),'bounded diagnostic text cannot change valid metrics');
 const physical=results.get('physical_detail');assert.equal(physical.physicalFirst_camera,'1,2,3');assert.equal(physical.physicalFirst_punch,2);assert.match(physical.physicalFirst_part,/L017_C07_R05$/);
 assert.equal(results.get('nonfinite').maxBack,'invalid_number');
 assert(JSON.stringify(results.get('maximum_scalar_payload')).length<3900,'fixed scalar/schema bound failed');
}
const checkTextCode=between(runner,'function checkText(', '\nconst defaultConsolePatterns');
const runActionEnd=runner.includes('\nexport async function runFailureCleanup(')?'\nexport async function runFailureCleanup(':'\nasync function runFlow(';
const runActionCode=between(runner,'async function runAction(',runActionEnd);
const assertCondition=(ok,message)=>{if(!ok)throw new Error(message);};
const runAction=Function('assertCondition','waitForDataModels','normalizeMouseInputArgs','sleep','runAssertion',checkTextCode+'\n'+runActionCode+'\nreturn runAction;')(assertCondition,async()=>{},async(_,a)=>a,async()=>{},()=>{});
try{
 const pageCases=[];
 for(const page of pages){const results=run(page.saveAs,pageProgram(page));verifyPageResults(page,results);pageCases.push({page,results});}
 for(const [name,index,from,to]of [
  ['wrong_visibility_stage',0,'d.stages[1]','d.stages[2]'],
  ['wrong_visibility_last',3,'local sample=d.last','local sample=d.first'],
  ['wrong_recovery_last',4,'d.last','d.first'],
  ['wrong_recovery_first',5,'d.first','d.last'],
  ['unsafe_page_bound',0,'assert(#encoded<3900,','assert(true,'],
 ]){
  const page=pages[index],code=page.args.code.replaceAll(from,to);assert.notEqual(code,page.args.code,name);
  assert.throws(()=>verifyPageResults(page,run(name,pageProgram(page,code))),name+' executable mutation survived');mutations.push(name);
 }
 const collected=[];
 for(const step of samples){const results=run(step.saveAs,programFor(step));verifyResults(step,results);collected.push({step,results});}
 const first=collected[0];
 for(const [name,code]of [
  ['false_boolean_lost',samples[0].args.code.replace("if type(value)=='boolean'then summary[key]=value else summary[key]='invalid_boolean'end","summary[key]=value or 'invalid_boolean'")],
  ['missing_correction',samples[0].args.code.replace("'maxCorrectionStep',",'')],
  ['missing_physical_frames',samples[0].args.code.replace("'unresolvedSafetyFrames',",'')],
  ['force_unique_verdict',samples[0].args.code.replace('cameraDeviceContractValid=metricsValid','cameraDeviceContractValid=true')],
 ]){assert.notEqual(code,samples[0].args.code);assert.throws(()=>verifyResults(samples[0],run(name,programFor(samples[0],code))));mutations.push(name);}
 run('unbounded_string',programFor(samples[0],samples[0].args.code.replace('string.sub(value,1,96)','value')),true);mutations.push('unbounded_string');
 const contaminated={...first.results.get('good'),metricsValid:false,cameraDeviceContractValid:false,valid:false,nested:first.results.get('good')};assert(!accepts(samples[0],contaminated),'nested true values hid a failed top-level decision');
 const missing={...contaminated};delete missing.cameraDeviceContractValid;assert(!accepts(samples[0],missing),'nested marker replaced missing top-level verdict');mutations.push('nested_true_and_missing_top_marker');
 const weakened=structuredClone(samples[0]);weakened.expectRegex.pop();assert(accepts(weakened,contaminated),'negative control no longer exercises generic nested regex collision');mutations.push('remove_flat_unique_gate');
 for(const [step,results]of collected.map(x=>[x.step,x.results])){
  const context={};const text=JSON.stringify(results.get('physical'));
  await assert.rejects(runAction({callTool:async()=>({isError:false,text})},step,context,[],100,[]));
  assert.equal(context[step.saveAs],text,'actual runner failed to retain decision before regex failure');
  const oldContext={};await assert.rejects(runAction({callTool:async()=>({isError:true,text:'original inner assert: phone camera metrics failed'})},old.steps.find(s=>s.saveAs===step.saveAs),oldContext,[],100,[]));assert(!Object.hasOwn(oldContext,step.saveAs),'historical lost-context behavior was not reproduced');
 }
 for(const [name,mutate]of [
  ['missing_failure_console',f=>f.cleanup.splice(6,1)],['missing_stop',f=>f.cleanup.splice(7,1)],
  ['console_after_stop',f=>{const [capture]=f.cleanup.splice(6,1);f.cleanup.push(capture);}],
  ['missing_diagnostic_page',f=>f.cleanup.splice(2,1)],
  ['swapped_diagnostic_pages',f=>{[f.cleanup[0],f.cleanup[1]]=[f.cleanup[1],f.cleanup[0]];}],
  ['wrong_page_datamodel',f=>{f.cleanup[0].args.datamodel_type='Server';}],
  ['wrong_diagnostic_attribute',f=>{f.cleanup[0].args.code=f.cleanup[0].args.code.replace('CameraAutomationVisibilityJSON','CameraAutomationRecoveryJSON');}],
  ['unbounded_diagnostic_page',f=>{f.cleanup[0].args.code=f.cleanup[0].args.code.replace('assert(#encoded<3900,','assert(true,');}],
  ['yielding_diagnostic_page',f=>{f.cleanup[0].args.code='task.wait(30) '+f.cleanup[0].args.code;}],
  ['lower_clear_threshold',f=>{f.steps.find(s=>s.saveAs==='phoneCamera').args.code=f.steps.find(s=>s.saveAs==='phoneCamera').args.code.replace('(result.clearRatio or 0)>=.55','(result.clearRatio or 0)>=.4');}],
 ]){const candidate=structuredClone(flow);mutate(candidate);assert.throws(()=>verifyFlow(candidate));mutations.push(name);}
 for(const failedPage of [null,...pageNames]){
  const calls=[],context={},place={name:'PunchWallRPGPlayable_v1_final.rbxlx',placeId:'0',datamodelType:'Edit'};
  const mock={async callTool(tool,args){
   if(tool==='execute_luau'&&args.code==='return game.Name')return{isError:false,text:place.name};
   if(tool==='execute_luau'&&args.code.includes('placeId=tostring(game.PlaceId)')){assert.equal(args.datamodel_type,'Edit');return{isError:false,text:JSON.stringify(place)};}
   const page=pages.find(p=>p.args.code===args.code);
   if(page){calls.push(page.saveAs);return page.saveAs===failedPage?{isError:true,text:'injected bounded page failure'}:{isError:false,text:JSON.stringify(pageCases.find(p=>p.page.saveAs===page.saveAs).results.get('available'))};}
   if(tool==='get_console_output'){calls.push('console');return{isError:false,text:'original camera warning'};}
   if(tool==='start_stop_play'){assert.equal(args.is_start,false);calls.push('stop');return{isError:false,text:'ok'};}
   assert.equal(tool,'execute_luau');assert.equal(args.datamodel_type,'Edit');assert.equal(args.code,old.cleanup[1].args.code);calls.push('viewport');return{isError:false,text:'true'};
  }};
  const result=await runFailureCleanup(mock,flow.cleanup,context,[],100,[],{placeName:'^PunchWallRPGPlayable_v1_final[.]rbxlx$',placeId:'0'},place);
  assert.deepEqual(calls,[...pageNames,'console','stop','viewport'],'failed page prevented later evidence/Stop/viewport cleanup');
  assert.equal(result.actions.length,9);assert(result.stopAcknowledged&&result.editVerified);assert.equal(result.restored,failedPage===null);
  for(const name of pageNames){assert.equal(Object.hasOwn(context,name),name!==failedPage);if(name===failedPage)assert.match(result.actions[pageNames.indexOf(name)].error,/injected bounded page failure/);}
  assert.equal(context.cameraFailureConsole,'original camera warning','original console evidence changed');
 }
 for(const [i,step]of [...flow.steps,...flow.cleanup].entries())if(step.args?.code){const file=path.join(temp,'flow-'+i+'.luau');fs.writeFileSync(file,step.args.code);const result=spawnSync(compiler,['--null',file],{encoding:'utf8'});assert.equal(result.status,0,result.stderr);compiled++;}
 console.log(JSON.stringify({ok:true,deviceCases:collected.reduce((sum,x)=>sum+x.results.size,0),diagnosticPageCases:pageCases.reduce((sum,x)=>sum+x.results.size,0),failedPageCleanupCases:7,originalTwentyActions:true,originalThresholdsAndFixtures:true,actualNativePredicate:true,runnerRetainsFailures:true,mutations,compiled,nativeReplay:'pending'},null,2));
}finally{assert.equal(path.dirname(fs.realpathSync(temp)),fs.realpathSync(os.tmpdir()));fs.rmSync(temp,{recursive:true,force:true});}
