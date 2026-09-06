import fs from 'node:fs';
import path from 'node:path';
import cp from 'node:child_process';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
const arg=(key,fallback)=>{const i=process.argv.indexOf(key);return i<0?fallback:process.argv[i+1];};
const root=path.resolve(arg('--source-root',process.cwd()));
const luau=arg('--luau',process.env.LUAU_QA_EXE||'C:/Users/Jennarong Pinjai/AppData/Local/Temp/codex-luau-smash-0.737/luau.exe');
const read=p=>fs.readFileSync(path.join(root,p),'utf8').replace(/\r/g,'');
const client=read('work/punch-wall-rpg/src/client/PunchWallClient.client.lua');
const flowNames=['iteration03-safearea-destruction','iteration04-armory-pets-feedback'];
const flows=flowNames.map(n=>JSON.parse(read('work/automation/flows/'+n+'.json')));
function between(text,a,b){const start=text.indexOf(a),end=text.indexOf(b,start+a.length);assert(start>=0&&end>start,'Extraction changed: '+a);return text.slice(start,end);}
function execute(code){let input='QAChunk=""\n';for(let i=0;i<code.length;i+=200)input+='QAChunk=QAChunk..'+JSON.stringify(code.slice(i,i+200))+'\n';input+='assert(loadstring(QAChunk))()\n';const r=cp.spawnSync(luau,[],{input,encoding:'utf8',maxBuffer:4*1024*1024,timeout:20000});const out=(r.stdout||'')+'\n'+(r.stderr||'');return {ok:!r.error&&r.status===0&&!r.stderr&&!/stdin:|stack backtrace|SyntaxError/.test(out)&&out.includes('FEEDBACK_CASE_PASS'),out};}
function pass(code,label){const r=execute(code);assert(r.ok,label+'\n'+r.out);}
function compile(code,label){pass('assert(loadstring('+JSON.stringify(code)+')) print("FEEDBACK_CASE_PASS")',label);}
compile(client,'full current client');let snippets=0;
for(const flow of flows)for(const step of [...flow.steps,...(flow.cleanup||[])])if(step.args?.code){compile(step.args.code,step.label);snippets++;}
const presentation=between(client,'local feedbackPresentation = {','local function feedbackText');
const textProducer=between(client,'local function feedbackText','local function feedbackIcon');
const routing=between(client,'local function showFeedback','shared.PunchWallShowToast = function');
const toast=between(client,'shared.PunchWallShowToast = function','local refreshCharacterVisuals');
const sound=between(client,'local function playUISound','local punchImpactSound');
const rewardSound=between(client,'shared.PunchWallPlayRewardSound = function()','local function showWorldDamage');
const mock=String.raw`
local now=10 local os={clock=function()return now end}
local delayed={} local task={delay=function(t,fn)local v={at=now+t,fn=fn} table.insert(delayed,v) return v end,cancel=function(v)v.cancelled=true end}
local function node(class)
 local data={ClassName=class,Visible=true,TextTransparency=0,children={},attributes={}}
 local object local methods={}
 function methods:GetAttribute(k)return data.attributes[k]end
 function methods:SetAttribute(k,v)data.attributes[k]=v end
 function methods:GetChildren()return table.clone(data.children)end
 function methods:IsA(c)return c==class or c=='GuiObject' and(class=='TextLabel' or class=='Frame')end
 function methods:Destroy()self.Parent=nil data.destroyed=true end
 function methods:Play()data.played=(data.played or 0)+1 end
 object=setmetatable({}, {__index=function(_,k)return methods[k] or data[k]end,__newindex=function(_,k,v)
  if k=='Parent' then if data.Parent then local i=table.find(data.Parent.children,object) if i then table.remove(data.Parent.children,i)end end if v then table.insert(v.children,object)end end data[k]=v
 end})
 return object
end
local Instance={new=node}
local noop=function()end
local dims=function(...)return {...}end
local UDim={new=dims} local UDim2={new=dims,fromOffset=dims,fromScale=dims} local Vector2={new=dims}
local Enum={Font={GothamBlack=1,GothamBold=2},TextXAlignment={Left=1},EasingStyle={Back=1,Quad=2},EasingDirection={Out=1}}
local Color3={fromRGB=dims}
local TweenInfo={new=dims}
local TweenService={Create=function(_,object,_,values)return {Play=function()for k,v in pairs(values)do object[k]=v end end}end}
local UserInputService={TouchEnabled=false}
local palette={Panel=1,Reward=2,Train=3,Punch=4,Fail=5}
local PolishConfig={Motion={RewardPopSeconds=.8}}
local GameConfig={Audio={Reward='reward',CoinCollect='coin'}}
local clientSettings={motion=true,sound=true}
local gui=node('ScreenGui') local rewardHolder=node('Frame') local toastHolder=node('Frame')
rewardHolder.Parent=gui toastHolder.Parent=gui
local SoundService=node('SoundService') local Debris={AddItem=noop}
local shared={PunchWallLastRewardSoundAt=0}
local worldCalls,coinCalls=0,0
local function showWorldDamage(_)worldCalls+=1 end
local function spawnCoinCollectVFX(_)coinCalls+=1 end
local function formatNumber(v)return tostring(v)end
local feedbackIcon=function(v)return v end
local addHeroAccent=noop local createThemeIcon=noop
local hitFlash=node('Frame') hitFlash.Parent=gui
local lastPunchFeedbackAt=0 local pulseHaptic=noop local playPunchImpact=noop
local combatFeedbackRuntime={Play=noop}
`;
const producer=mock+sound+rewardSound+presentation+textProducer+routing+toast;
const cases=String.raw`
local checks=0 local function check(v,msg)assert(v,msg)checks+=1 end
local function clear()
 for _,holder in ipairs({toastHolder,rewardHolder,SoundService})do for _,n in ipairs(holder:GetChildren())do n:Destroy()end end
 table.clear(feedbackPresentation.toasts) table.clear(feedbackPresentation.rewards)
 worldCalls=0 coinCalls=0 now+=1
end
for _,center in ipairs({false,true})do for _,motion in ipairs({false,true})do
 clear()gui:SetAttribute('CenterActionFeedbackEnabled',center)clientSettings.motion=motion
 showFeedback({type='Reward',target='DepthBlock_L001_C06_R02',wallBreak=true,coins=5,score=2,depth=1})
 check(worldCalls==1 and coinCalls==1,'wall reward bypassed actual downstream dispatch')
 check(#rewardHolder:GetChildren()==0 and #toastHolder:GetChildren()==0,'wall reward has duplicate text channel')
 check(#SoundService:GetChildren()==1 and SoundService:GetChildren()[1].played==1,'wall reward did not play sound')
 showFeedback({type='LevelUp',target='2'})
 check(#rewardHolder:GetChildren()==0 and #toastHolder:GetChildren()==0,'level up duplicated center text')
 check(#SoundService:GetChildren()==1,'same-frame level reward sound bypassed coalescing')
 clear()showFeedback({type='Pet',target='Forest Pup|1'})
 local holder=center and rewardHolder or toastHolder local other=center and toastHolder or rewardHolder
 check(#holder:GetChildren()==1 and #other:GetChildren()==0,'pet lost single-channel routing')
 check(holder:GetChildren()[1].Text=='Recruited Forest Pup|1!','pet copy lost actual identity')
end end
clear()gui:SetAttribute('CenterActionFeedbackEnabled',false)
local sequence=toastHolder:GetAttribute('PresentationSequence') or 0
for i=1,4 do now+=.3 showFeedback({type='Pet',target='Forest Pup|1'}) end
check(#toastHolder:GetChildren()==3 and #feedbackPresentation.toasts==3,'bounded toast queue exceeds three')
for i,item in ipairs(toastHolder:GetChildren())do check(item.LayoutOrder==sequence+i+1,'duplicate pet species reused presentation sequence')end
clear()showFeedback({type='DepthRecord',target='1',depth=1})
check(#toastHolder:GetChildren()==1 and #rewardHolder:GetChildren()==0,'legitimate milestone toast missing or duplicated')
check(gui:GetAttribute('MilestoneToastCount')==1,'milestone consumer did not observe event')
clear()clientSettings.sound=false showFeedback({type='Reward',wallBreak=true,coins=5})
check(#SoundService:GetChildren()==0 and coinCalls==1,'sound preference incorrectly disables visual reward')
local count=gui:GetAttribute('FeedbackCount') showFeedback(nil)
check(gui:GetAttribute('FeedbackCount')==count,'invalid feedback payload counted')
print('FEEDBACK_CASE_PASS producer',checks)
`;
pass(producer+cases,'actual routing, text, bounded presentation and audio producers');
const mutations=[
 ['wall coin dispatch removed','if payload.type == "Reward" and payload.wallBreak then spawnCoinCollectVFX(payload) end','if false then spawnCoinCollectVFX(payload) end'],
 ['center wall suppression removed','or (payload.type == "Reward" and payload.wallBreak) then','then'],
 ['pet center-disabled route removed','or payload.type == "Pet" or payload.type == "PetFusion"','or payload.type == "PetFusion"'],
 ['toast queue enlarged','maxToasts = 3','maxToasts = 99'],
 ['reused presentation identity','(holder:GetAttribute("PresentationSequence") or 0) + 1','1'],
 ['muted sound ignored','if not clientSettings.sound then return end','if false then return end'],
 ['reward debounce removed','if now - shared.PunchWallLastRewardSoundAt < 0.24 then return end','if false then return end'],
 ['milestone duplicated','if milestoneFeedback and shared.PunchWallShowToast then','if (milestoneFeedback or payload.type == "Pet") and shared.PunchWallShowToast then'],
];
const expectedMutationFailures=['wall reward bypassed actual downstream dispatch','wall reward has duplicate text channel','pet lost single-channel routing','bounded toast queue exceeds three','duplicate pet species reused presentation sequence','sound preference incorrectly disables visual reward','same-frame level reward sound bypassed coalescing','pet lost single-channel routing'];
for(const [index,[name,from,to]] of mutations.entries()){assert(producer.includes(from),name);const changed=producer.replace(from,()=>to);compile(changed+cases,name+' compiles');const r=execute(changed+cases);assert(!r.ok&&r.out.includes(expectedMutationFailures[index]),name+' did not fail at the intended behavioral assertion: '+r.out);}
const rewardStep=flows[0].steps.find(s=>s.label.startsWith('real wall reward'));
const petStep=flows[1].steps.find(s=>s.label.startsWith('all three real pickup'));
const rewardVerifier=between(rewardStep.args.code,'local function verifyRewardEvidence','local function numberText');
const petVerifier=between(petStep.args.code,'local function verifyPetEvidence','local deadline=');
const petObserver=flows[1].steps.find(s=>s.label.startsWith('observe each real Pet')).args.code;
const capture=between(petObserver,'local function visible','local connection,tokenConnection');
const captureCases=String.raw`
local g=node('ScreenGui') g.Enabled=true
g.Toasts=node('Frame') g.Toasts.Name='Toasts' g.Toasts.Parent=g
g.RewardPops=node('Frame') g.RewardPops.Name='RewardPops' g.RewardPops.Parent=g
g.PixelPerfectHeroCityHUD={AbsolutePosition={X=0,Y=-58},AbsoluteSize={X=900,Y=600}}
local evidence={baseSequence=40,rewardSequence=0}
CAPTURE_SOURCE
local function label(sequence,text,y)
 local n=node('TextLabel') n.LayoutOrder=sequence n.Text=text n.Parent=g.Toasts
 n.AbsolutePosition={X=200,Y=y} n.AbsoluteSize={X=300,Y=40} return n
end
local old=label(41,'Recruited Pup!',10)
assert(capture('Pup',2).matching==0,'earlier identical pet text reused')
local fresh=label(42,'Recruited Pup!',60)
local v=capture('Pup',2)assert(v.matching==1 and v.channels==1 and v.nonoverlap and v.safeBounds,'actual fresh toast not captured')
g.Enabled=false assert(capture('Pup',2).matching==0,'disabled screen accepted')g.Enabled=true
g.Toasts.Visible=false assert(capture('Pup',2).matching==0,'hidden holder accepted')g.Toasts.Visible=true
fresh.TextTransparency=1 assert(capture('Pup',2).matching==0,'transparent toast accepted')fresh.TextTransparency=0
fresh.AbsolutePosition.Y=10 assert(not capture('Pup',2).nonoverlap,'overlapping labels accepted')fresh.AbsolutePosition.Y=60
fresh.AbsolutePosition.X=850 assert(not capture('Pup',2).safeBounds,'clipped toast accepted')fresh.AbsolutePosition.X=200
local duplicate=label(42,'Recruited Pup!',110)
assert(capture('Pup',2).matching==2,'duplicate fresh toast hidden')duplicate:Destroy()
local other=label(42,'Recruited Pup!',110)other.Parent=g.RewardPops
assert(capture('Pup',2).channels==2,'duplicate feedback channel hidden')
print('FEEDBACK_CASE_PASS capture',9)
`.replace('CAPTURE_SOURCE',()=>capture);
pass(mock+captureCases,'exact Pet capture reads actual fresh instance and visibility');
const verifierFixture=String.raw`
local function goodReward()
 local s={target='Block',coins=5,score=2,newDepth=1,newCoins=10,xp=3,level=1,levelEvents=0}
 local e={token='run',events={{type='Reward',target='Block',coins=5,score=2,depth=1,wallBreak=true}},coinsCreated=7,coinSounds=1,rewardSounds=1}
 local v={token='run',burstDelta=7,coins=10,depth=1,xp=3,level=1,hudCoins='10',expectedCoins='10',hudDepth='1',expectedDepth='1',hudVisible=true,hudFits=true,pops=0,toasts=1,rewardNoticeCount=0,nonoverlap=true,layout=true}
 return e,s,v
end
local function goodPet()
 local e={token='run',baseSequence=40,rewardSequence=0,events={},views={}}local inventory={'Pup','Pup','Pup'}
 for i=1,3 do e.events[i]={type='Pet',target='Pup'}e.views[i]={target='Pup',freshSequence=40+i,rewardSequence=0,matching=1,channels=1,nonoverlap=true,safeBounds=true,rects={{holder='Toasts',text='Recruited Pup!',sequence=40+i}}}end
 return e,inventory,'run'
end
`;
const verifierCases=String.raw`
local checks=0
local function reject(fn,message)local ok=pcall(fn)assert(not ok,message)checks+=1 end
verifyRewardEvidence(goodReward())verifyPetEvidence(goodPet())
local rewardFaults={
 function(e,s,v)e.events={}end,
 function(e,s,v)e.events[2]=table.clone(e.events[1])end,
 function(e,s,v)e.events[1].coins=6 end,
 function(e,s,v)e.coinsCreated=0 end,
 function(e,s,v)e.coinSounds=2 end,
 function(e,s,v)e.rewardSounds=2 end,
 function(e,s,v)v.coins=0 end,
 function(e,s,v)v.xp=99 end,
 function(e,s,v)v.hudCoins='0'end,
 function(e,s,v)v.hudVisible=false end,
 function(e,s,v)v.hudFits=false end,
 function(e,s,v)v.pops=1 end,
 function(e,s,v)v.rewardNoticeCount=1 end,
 function(e,s,v)v.nonoverlap=false end,
 function(e,s,v)v.token='stale'end,
}
for _,fault in ipairs(rewardFaults)do local e,s,v=goodReward()fault(e,s,v)reject(function()verifyRewardEvidence(e,s,v)end,'reward fault escaped')end
local petFaults={
 function(e)e.events[3]=nil end,
 function(e)e.events[2].target='wrong'end,
 function(e)e.views[2].freshSequence=41 end,
 function(e)e.views[2].freshSequence=41 e.views[2].rects[1].sequence=41 end,
 function(e)e.views[2].rects[1].sequence=41 end,
 function(e)e.views[2].matching=2 end,
 function(e)e.views[2].channels=2 end,
 function(e)e.views[2].rewardSequence=1 end,
 function(e)e.views[2].nonoverlap=false end,
 function(e)e.views[2].safeBounds=false end,
 function(e)e.views[2].rects[1].holder='RewardPops'end,
 function(e)e.token='stale'end,
}
for _,fault in ipairs(petFaults)do local e,i,t=goodPet()fault(e)reject(function()verifyPetEvidence(e,i,t)end,'pet fault escaped')end
print('FEEDBACK_CASE_PASS verification',checks)
`;
pass(rewardVerifier+petVerifier+verifierFixture+verifierCases,'exact flow verifiers positive and faults');
const weakChecks=[
 [rewardVerifier,'assert(rewards==1 and levels==s.levelEvents,','assert(true,'],
 [rewardVerifier,'assert(view.hudCoins==view.expectedCoins and view.hudDepth==view.expectedDepth and view.hudVisible and view.hudFits,','assert(true,'],
 [petVerifier,'assert(view.freshSequence==e.baseSequence+i and not seen[view.freshSequence],','assert(true,'],
 [petVerifier,'assert(exact==1,','assert(true,'],
];
for(const [code,from,to]of weakChecks){assert(code.includes(from));const altered=code.replace(from,()=>to);const suite=(code===rewardVerifier?altered+petVerifier:rewardVerifier+altered)+verifierFixture+verifierCases;compile(suite,'weak verifier compiles');const result=execute(suite);assert(!result.ok&&result.out.includes(code===rewardVerifier?'reward fault escaped':'pet fault escaped'),'weakened verifier did not expose the intended fault: '+result.out);}
// Preserve every unrelated authority, wall, boss, safe-area, and cleanup gate.
// Only this exact reviewed step supersedes its older safe-area fixture. Keep
// its full call metadata and code pinned, rather than excluding the label.
const approvedSafeStepLabel='actual HUD and standalone Settings fit safe area with touch targets';
const approvedSafeStepRef='81219f24a824f8636ff55457d7817b4ca971592e';
const approvedSafeFlow=JSON.parse(cp.execFileSync('git',['show',approvedSafeStepRef+':work/automation/flows/iteration03-safearea-destruction.json'],{cwd:root,encoding:'utf8'}));
const approvedSafeStep=approvedSafeFlow.steps.find(s=>s.label===approvedSafeStepLabel);
assert(approvedSafeStep,'Approved safe-area step missing');
function verifyApprovedSafeStep(step){assert.deepEqual(step,approvedSafeStep,'Approved safe-area step changed');}
verifyApprovedSafeStep(flows[0].steps.find(s=>s.label===approvedSafeStepLabel));
const safeStepWeakeningCopies=[
 ['modal safe margin','assert(host.Visible and p.X>=q.X+11 and p.Y>=q.Y+11 and p.X+s.X<=q.X+t.X-11 and p.Y+s.Y<=q.Y+t.Y-11,','assert(true,'],
 ['bounded modal dimensions','assert(math.abs(s.X-math.min(677,t.X-24))<=1 and math.abs(s.Y-math.min(408,t.Y-24))<=1,','assert(true,'],
 ['scroll capability','assert(scroller:IsA(\'ScrollingFrame\') and scroller.ScrollingEnabled and scroller.AutomaticCanvasSize==Enum.AutomaticSize.Y,','assert(true,'],
 ['close action size','assert(close.Visible and close.Active and close.Selectable and math.min(close.AbsoluteSize.X,close.AbsoluteSize.Y)>=44,','assert(true,'],
 ['all visible action sizes','assert(math.min(d.AbsoluteSize.X,d.AbsoluteSize.Y)>=44,','assert(true,'],
 ['actual scroll end','assert(math.abs(scroller.CanvasPosition.Y-maxY)<=1,','assert(true,'],
 ['last action containment','assertContained(scroller,last)','do end'],
 ['scroll position restoration','scroller.CanvasPosition=before','do end'],
];
for(const [name,from,to]of safeStepWeakeningCopies){
 const changed=structuredClone(approvedSafeStep);
 assert(changed.args.code.includes(from),'Approved safe-area control moved: '+name);
 changed.args.code=changed.args.code.replace(from,()=>to);
 compile(changed.args.code,'weaker safe-area copy compiles: '+name);
 assert.throws(()=>verifyApprovedSafeStep(changed),/Approved safe-area step changed/,'Weaker safe-area copy accepted: '+name);
}
const missingSafeEvidence=structuredClone(approvedSafeStep);delete missingSafeEvidence.saveAs;
assert.throws(()=>verifyApprovedSafeStep(missingSafeEvidence),/Approved safe-area step changed/,'Safe-area evidence retention removed');
const allowed=new Set(['break depth block with bounded camera-safe physics','wait for stacked reward feedback','level and reward feedback stack without duplicates','observe each real Pet event and visible presentation before pickups','all three real pickup events have matching visible feedback in one non-overlapping channel']);
let preserved=0;
for(let i=0;i<flowNames.length;i++){
 const before=JSON.parse(cp.execFileSync('git',['show','5fb7237:work/automation/flows/'+flowNames[i]+'.json'],{cwd:root,encoding:'utf8'}));
 for(const step of before.steps){if(allowed.has(step.label))continue;const current=flows[i].steps.find(s=>s.label===step.label);if(i===0&&step.label===approvedSafeStepLabel)verifyApprovedSafeStep(current);else assert.deepEqual(current,step,'Unrelated gate changed: '+step.label);preserved++;}
 assert.deepEqual(flows[i].cleanup,before.cleanup,'Cleanup gate changed');
}
console.log(JSON.stringify({ok:true,clientSHA256:crypto.createHash('sha256').update(client).digest('hex'),compiledFlowSnippets:snippets,producerMutations:mutations.length,actualPetCaptureControls:9,verifierFaults:27,verifierMutations:weakChecks.length,approvedSafeStepRef,approvedSafeStepCopyRejections:safeStepWeakeningCopies.length+1,unrelatedGatesPreserved:preserved,runtime:'PENDING: Coordinator owns Studio; mocks do not prove rendering, audio audibility or server replication'},null,2));
