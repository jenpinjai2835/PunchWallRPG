import fs from 'node:fs';
import path from 'node:path';
import cp from 'node:child_process';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';

const option = (name, fallback) => process.argv.includes(name) ? process.argv[process.argv.indexOf(name) + 1] : fallback;
const root = path.resolve(option('--source-root', process.cwd()));
const baselineRef = option('--baseline-ref', 'f6202ce');
const luau = option('--luau', process.env.LUAU_COMMAND || 'C:/Users/Jennarong Pinjai/AppData/Local/Temp/codex-luau-smash-0.737/luau.exe');
const clientPath = 'work/punch-wall-rpg/src/client/PunchWallClient.client.lua';
const current = fs.readFileSync(path.join(root, clientPath), 'utf8').replace(/\r/g, '');
const baseline = cp.execFileSync('git', ['show', `${baselineRef}:${clientPath}`], {cwd:root,encoding:'utf8',maxBuffer:4*1024*1024}).replace(/\r/g, '');
function section(source, start, end) {
 const a=source.indexOf(start), b=source.indexOf(end,a+start.length);
 assert(a>=0&&b>a, `Production boundary missing: ${start}`); return source.slice(a,b);
}
function producers(source) {
 return [
  section(source,'local function setRounded(', '\nfor order, tabName in ipairs('),
  section(source,'local function clearContent()', '\nlocal function addGeneratedBanner()'),
  section(source,'local function genericMenuIsCompact()', '\nlocal function countNames('),
  section(source,'local function countNames(', '\nlocal function renderFists()'),
  section(source,'local function renderPets()', '\nlocal function renderHonor()'),
  section(source,'local function renderTasks()', '\nlocal function renderSettings()'),
  section(source,'\nrenderOpenPanel = function()', '\nif RunService:IsStudio() then\n\tgui:GetAttributeChangedSignal("AutomationTab")'),
 ].join('\n');
}
const production=producers(current), oldProduction=producers(baseline);
function execute(code) {
 let input='GenericPanelQA=""\n';for(let i=0;i<code.length;i+=200)input+='GenericPanelQA=GenericPanelQA..'+JSON.stringify(code.slice(i,i+200))+'\n';input+='assert(loadstring(GenericPanelQA))()\n';
 const r=cp.spawnSync(luau,[],{input,encoding:'utf8',maxBuffer:4*1024*1024,timeout:20000});
 const output=(r.stdout||'')+'\n'+(r.stderr||'');
 return {ok:!r.error&&r.status===0&&!r.stderr&&!/stdin:|stack backtrace|SyntaxError/.test(output)&&output.includes('GENERIC_PANEL_PASS'),output};
}
function pass(code,label) {const r=execute(code);assert(r.ok,`${label}\n${r.output}`);}
function compile(code,label) {pass(`assert(loadstring(${JSON.stringify(code)})) print('GENERIC_PANEL_PASS compile')`,label);}
compile(current,'complete client compilation');

const mock=String.raw`
local now,serial=0,0 local queue={}
local function schedule(co,t) serial+=1 table.insert(queue,{co=co,t=t,id=serial})end
local function resume(co) local ok,delay=coroutine.resume(co) assert(ok,delay) if coroutine.status(co)~='dead' then schedule(co,now+(delay or .01))end end
local task={spawn=function(fn)local co=coroutine.create(fn)resume(co)return co end,wait=function(t)return coroutine.yield(t or .01)end}
function task.delay(t,fn)local co=coroutine.create(fn)schedule(co,now+t)return co end
function task.defer(fn)return task.delay(0,fn)end
local function advance(t)
 local budget=0
 while true do table.sort(queue,function(a,b)return a.t==b.t and a.id<b.id or a.t<b.t end) local n=queue[1]if not n or n.t>t then break end table.remove(queue,1)now=n.t resume(n.co)budget+=1 assert(budget<10000,'unbounded task queue')end
 now=t
end
local today='2026-09-06'
local os={clock=function()return now end,time=function()return 1000+now end,date=function()return today end}
local function signal()
 local s={listeners={}}
 function s:Connect(fn)local c={Connected=true,fn=fn}function c:Disconnect()self.Connected=false end table.insert(self.listeners,c)return c end
 function s:Fire(...)for _,c in ipairs(table.clone(self.listeners))do if c.Connected then c.fn(...)end end end
 function s:Wait()return task.wait(.01)end
 return s
end
local function enum()return setmetatable({},{__index=function(t,k)local v=enum()rawset(t,k,v)return v end})end
local Enum=enum() local Color3={new=function(...)return {...}end,fromRGB=function(...)return {...}end}
local Vector2={new=function(x,y)return {X=x,Y=y}end}Vector2.zero=Vector2.new(0,0)
local UDim={new=function(s,o)return {Scale=s,Offset=o}end}
local UDim2={new=function(...)return {...}end,fromOffset=function(...)return {...}end,fromScale=function(...)return {...}end}
local props={}local methods={}local Instance={}
local guiClasses={Frame=true,ScrollingFrame=true,TextButton=true,TextLabel=true,ImageLabel=true}
local meta={__index=function(self,key)return methods[key]or props[self][key]end,__newindex=function(self,key,value)
 local p=props[self]
 if key=='Parent' then
  if p.Parent then local list=props[p.Parent].children local i=table.find(list,self)if i then table.remove(list,i)end end
  p.Parent=value if value then table.insert(props[value].children,self)end
 else p[key]=value end
end}
function Instance.new(class,parent)
 local n=setmetatable({},meta)
 props[n]={ClassName=class,Name=class,children={},attrs={},Visible=true,Active=true,Selectable=true,
  AbsoluteSize=Vector2.new(600,400),AbsoluteCanvasSize=Vector2.new(600,2500),AbsolutePosition=Vector2.zero,
  CanvasPosition=Vector2.zero,Text='',Activated=signal()}
 if parent then n.Parent=parent end return n
end
function methods:IsA(class)return self.ClassName==class or class=='GuiObject'and guiClasses[self.ClassName]or class=='GuiButton'and self.ClassName=='TextButton'end
function methods:GetChildren()return table.clone(props[self].children)end
function methods:GetDescendants()local a={}for _,c in ipairs(self:GetChildren())do table.insert(a,c)for _,d in ipairs(c:GetDescendants())do table.insert(a,d)end end return a end
function methods:FindFirstChild(name)for _,c in ipairs(self:GetChildren())do if c.Name==name then return c end end end
function methods:IsDescendantOf(parent)local p=self.Parent while p do if p==parent then return true end p=p.Parent end return false end
function methods:Destroy()for _,c in ipairs(self:GetChildren())do c:Destroy()end self.Parent=nil props[self].destroyed=true end
function methods:SetAttribute(k,v)props[self].attrs[k]=v end
function methods:GetAttribute(k)return props[self].attrs[k]end
local gui=Instance.new('Frame')local mainPanel=Instance.new('Frame',gui)mainPanel.Visible=true
local content=Instance.new('ScrollingFrame',mainPanel)content.Name='Content'
local tabBar=Instance.new('Frame',mainPanel)local tabButtons={}
local GuiService={SelectedObject=nil}local UserInputService={TouchEnabled=false}
local workspace={CurrentCamera={ViewportSize=Vector2.new(1280,720)}}
local RunService={Heartbeat=signal(),IsStudio=function()return true end}
local shared={PunchWallStandaloneHostTitle=Instance.new('TextLabel',mainPanel),PunchWallGenericPanelRuntime={generation=0}}
local palette=setmetatable({},{__index=function()return {}end})
local requests={}local actionRemote={FireServer=function(self,payload)table.insert(requests,payload)end}
local latestStats={PetInventoryJSON='["Forest Pup","Forest Pup","Miner Cat"]',EquippedPetsJSON='["Forest Pup"]',
 LockedPetsJSON='[]',DiscoveredPetsJSON='[]',OwnedPremiumPetsJSON='[]',PetDropPity=0,LastDailyDate='',
 DailyBreaks=10,DailyQuestClaimed=0,PlaytimeSeconds=10,PlaytimeClaimed=0,SpinCredits=0,SpinReadyAt=5000,Tutorial={title='Train',detail='First steps'}}
local jsons={['[]']={},['["Forest Pup"]']={'Forest Pup'},['["Forest Pup","Forest Pup"]']={'Forest Pup','Forest Pup'},
 ['["Forest Pup","Forest Pup","Miner Cat"]']={'Forest Pup','Forest Pup','Miner Cat'},['["Miner Cat","Forest Pup","Forest Pup"]']={'Miner Cat','Forest Pup','Forest Pup'},
 ['["Forest Pup","Forest Pup","Forest Pup"]']={'Forest Pup','Forest Pup','Forest Pup'},['["slot:2"]']={'slot:2'},['["Crimson Phoenix"]']={'Crimson Phoenix'}}
local function decodeJSON(value,fallback)return jsons[value]or fallback end
local function encode(value)
 if type(value)~='table'then return string.format('%q',tostring(value))end
 local list={}for _,v in ipairs(value)do table.insert(list,encode(v))end return '['..table.concat(list,',')..']'
end
local HttpService={JSONEncode=function(self,v)return encode(v)end}
local clientSettings={sound=true,motion=true,uiScale=1}
local legacyPetMenuRuntime={deleteGeneration=0,deleteExpiresAt=0,deleteConfirmationSeconds=3}
local function formatNumber(n)return tostring(n)end
local function createThemeIcon(parent)local n=Instance.new('ImageLabel',parent)return n end
local function addGeneratedBanner()local n=Instance.new('ImageLabel',content)n.Name='Hero City Generated Banner'end
local function applyReferenceHUDState()end
local activeTab='Pets'local renderOpenPanel
local GameConfig={MaxEquippedPets=3,MaxPetStars=5,PetDrops={PityBreaks=90},GeneratedGraphics={Iteration02PetIcon='test'},
 Rewards={QuestBreakTarget=10,QuestCoins=850,PlaytimeSeconds=300,PlaytimeCoins=1200},
 Pets={{name='Forest Pup',rarity='Common',mult=.2,minDepth=1,color={}},{name='Miner Cat',rarity='Common',mult=.3,minDepth=2,color={}}},
 PremiumPets={{name='Crimson Phoenix',gamePassId=0,robux=399,mult=1,accent={}}}}
function GameConfig.ParsePetToken(token)return token,1 end
function GameConfig.PetDefinition(name)for _,pet in ipairs(GameConfig.Pets)do if pet.name==name then return pet end end end
function GameConfig.PetMultiplierForToken(token)return .2 end
function GameConfig.PetFusionRequirement(stars)return 3 end
shared.PunchWallPurchaseRuntime={GamePassPriceCache={},HasConfiguredGamePass=function(pet)return pet.gamePassId>0 end,
 MarkControlUnavailable=function()end,MarkControlConfigured=function()end}
function shared.PunchWallPurchaseRuntime.GetGamePassDisplayPrice(pet)
 local p=shared.PunchWallPurchaseRuntime.GamePassPriceCache[pet.gamePassId]
 return p and p.price or pet.robux,p and p.resolved or false,p and p.state or 'Unconfigured'
end
local function button(row,name)local r=content:FindFirstChild(row)local a=r and r:FindFirstChild('Actions')return a and a:FindFirstChild(name)end
local function petButton(name)return button('#02  [Common] Forest Pup  *',name or 'Equip2')end
local function click(b)assert(b and b.Parent,'click needs current live button')b.Activated:Fire()end
local function holdAcrossSnapshot(b)
 latestStats.PlaytimeSeconds+=1 renderOpenPanel()advance(now+.08)
 if b.Parent and not props[b].destroyed then b.Activated:Fire()end
end
`;

const cases=[
 ['pets-idle-press-lifetime', `renderOpenPanel()local b=petButton()local before=#requests content.CanvasPosition=Vector2.new(0,1300)
  holdAcrossSnapshot(b)assert(petButton()==b,'Pets button replaced by idle snapshot')assert(content.CanvasPosition.Y==1300,'idle refresh moved pet canvas')
  assert(#requests==before+1 and requests[#requests].action=='EquipPet'and requests[#requests].index==2,'held exact-slot input was lost')`],
 ['tasks-idle-press-lifetime', `activeTab='Tasks'renderOpenPanel()local b=button('Daily Supply','ClaimDaily')content.CanvasPosition=Vector2.new(0,90)
  holdAcrossSnapshot(b)assert(button('Daily Supply','ClaimDaily')==b,'Tasks button replaced by idle snapshot')assert(content.CanvasPosition.Y==90,'idle refresh moved Tasks canvas')
  assert(#requests==1 and requests[1].action=='ClaimDaily','held claim input was lost')
  assert(shared.PunchWallGenericPanelRuntime.playtimeLabel.Text:find('11/300',1,true),'playtime text did not update in place')`],
 ['unrelated-pet-stats-retain', `renderOpenPanel()local b=petButton()for _,k in ipairs({'Power','Coins','Depth','Score','PlaytimeSeconds','DailyBreaks','TrainingActive'})do latestStats[k]=101 renderOpenPanel()assert(petButton()==b,'unrelated '..k..' rebuilt pets')end`],
 ['pet-inventory-order-invalidates', `renderOpenPanel()local b=petButton()latestStats.PetInventoryJSON='["Miner Cat","Forest Pup","Forest Pup"]'renderOpenPanel()assert(petButton()~=b,'inventory order not rendered')click(petButton())assert(requests[1].target=='Forest Pup'and requests[1].index==2,'wrong ordered callback slot')`],
 ['pet-equipped-state-invalidates', `renderOpenPanel()local b=petButton()latestStats.EquippedPetsJSON='["Forest Pup","Forest Pup"]'renderOpenPanel()assert(petButton()~=b and petButton().Text=='UNEQUIP','equip state stale')click(petButton())assert(requests[1].action=='UnequipPet'and requests[1].index==2,'unequip targets wrong occurrence')`],
 ['pet-lock-state-invalidates', `renderOpenPanel()latestStats.LockedPetsJSON='["slot:2"]'renderOpenPanel()local d=petButton('Delete2')assert(d.Text=='LOCKED'and not d.Active and not d.Selectable,'locked delete is active')click(d)assert(#requests==0,'locked callback dispatched')`],
 ['pet-fusion-state-invalidates', `renderOpenPanel()assert(not petButton('Fuse2').Active)latestStats.PetInventoryJSON='["Forest Pup","Forest Pup","Forest Pup"]'renderOpenPanel()assert(petButton('Fuse2').Active,'fusion readiness stale')click(petButton('Fuse2'))assert(requests[1].action=='FusePet'and requests[1].target=='Forest Pup')`],
 ['pet-discovery-and-pity-invalidates', `renderOpenPanel()local b=petButton()latestStats.DiscoveredPetsJSON='["Forest Pup"]'renderOpenPanel()assert(petButton()~=b,'discovery stale')b=petButton()latestStats.PetDropPity=42 renderOpenPanel()assert(petButton()~=b,'pity stale')`],
 ['premium-owned-invalidates', `renderOpenPanel()local b=button('Crimson Phoenix','Crimson PhoenixPremiumPet')latestStats.OwnedPremiumPetsJSON='["Crimson Phoenix"]'renderOpenPanel()local n=button('Crimson Phoenix','Crimson PhoenixPremiumPet')assert(n~=b and n.Text=='EQUIP'and n.Active,'premium ownership stale')`],
 ['premium-regional-price-invalidates', `GameConfig.PremiumPets[1].gamePassId=123 renderOpenPanel()local b=button('Crimson Phoenix','Crimson PhoenixPremiumPet')shared.PunchWallPurchaseRuntime.GamePassPriceCache[123]={price=250,resolved=true,state='Resolved'}renderOpenPanel()local n=button('Crimson Phoenix','Crimson PhoenixPremiumPet')assert(n~=b and n.Text=='R$ 250'and n:GetAttribute('DisplayedRobuxPrice')==250,'regional price stale')`],
 ['delete-arm-retain-confirm-exact', `renderOpenPanel()click(petButton('Delete2'))advance(.02)assert(#requests==0,'first Delete mutated request state')local b=petButton('Delete2')assert(b.Text=='CONFIRM'and b:GetAttribute('ExactInventoryIndex')==2,'exact confirmation missing')
  latestStats.PlaytimeSeconds+=1 renderOpenPanel()assert(petButton('Delete2')==b,'idle snapshot replaced armed Delete')click(b)assert(#requests==1 and requests[1].action=='DeletePet'and requests[1].index==2 and requests[1].target=='Forest Pup','second click wrong exact deletion')`],
 ['delete-expiry-invalidates', `renderOpenPanel()click(petButton('Delete2'))advance(.02)local armed=petButton('Delete2')advance(3.1)local b=petButton('Delete2')assert(b~=armed and b.Text=='DEL'and not b:GetAttribute('ConfirmationArmed'),'expired Delete still armed')assert(#requests==0,'expiry dispatched deletion')click(b)assert(#requests==0,'click after expiry deleted immediately')`],
 ['delete-slot-change-disarms', `renderOpenPanel()click(petButton('Delete2'))advance(.02)latestStats.PetInventoryJSON='["Forest Pup"]'renderOpenPanel()assert(legacyPetMenuRuntime.deleteKey==nil,'removed armed slot survived')assert(#requests==0,'slot invalidation deleted')`],
 ['tasks-readiness-and-claims-invalidates', `activeTab='Tasks'latestStats.PlaytimeSeconds=299 renderOpenPanel()local b=button('Five Minute Supply','ClaimPlaytime')assert(not b.Active and b.Text=='WAIT')latestStats.PlaytimeSeconds=300 renderOpenPanel()local n=button('Five Minute Supply','ClaimPlaytime')assert(n~=b and n.Active and n.Text=='CLAIM','playtime readiness stale')click(n)assert(requests[1].action=='ClaimPlaytime')latestStats.PlaytimeClaimed=1 renderOpenPanel()assert(button('Five Minute Supply','ClaimPlaytime').Text=='CLAIMED'and not button('Five Minute Supply','ClaimPlaytime').Active,'claimed state stale')`],
 ['daily-claim-and-midnight-invalidates', `activeTab='Tasks'renderOpenPanel()latestStats.LastDailyDate=today renderOpenPanel()assert(button('Daily Supply','ClaimDaily').Text=='CLAIMED'and not button('Daily Supply','ClaimDaily').Active)today='2026-09-07'renderOpenPanel()assert(button('Daily Supply','ClaimDaily').Text=='CLAIM'and button('Daily Supply','ClaimDaily').Active,'daily UTC boundary stale')`],
 ['quest-progress-and-claim-invalidates', `activeTab='Tasks'latestStats.DailyBreaks=9 renderOpenPanel()assert(button('City Cleanup','ClaimQuest').Text=='WAIT')latestStats.DailyBreaks=10 renderOpenPanel()assert(button('City Cleanup','ClaimQuest').Text=='CLAIM')latestStats.DailyQuestClaimed=1 renderOpenPanel()assert(button('City Cleanup','ClaimQuest').Text=='CLAIMED'and not button('City Cleanup','ClaimQuest').Active)`],
 ['tasks-spin-clock-retains', `activeTab='Tasks'renderOpenPanel()local b=button('Hero Prize Spin','OpenSpin')local label=shared.PunchWallGenericPanelRuntime.spinLabel local oldText=label.Text advance(61)renderOpenPanel()assert(button('Hero Prize Spin','OpenSpin')==b and label==shared.PunchWallGenericPanelRuntime.spinLabel and label.Text~=oldText,'spin clock rebuilt control or stayed stale')latestStats.SpinReadyAt=1000 renderOpenPanel()assert(button('Hero Prize Spin','OpenSpin').Text=='SPIN','spin readiness stale')`],
 ['tasks-tutorial-invalidates', `activeTab='Tasks'renderOpenPanel()local b=button('Daily Supply','ClaimDaily')latestStats.Tutorial={title='Smash',detail='Next wall'}renderOpenPanel()assert(button('Daily Supply','ClaimDaily')~=b,'tutorial step stale')`],
 ['navigation-and-missing-anchor-invalidates', `renderOpenPanel()local b=petButton()activeTab='Inventory'renderOpenPanel()activeTab='Pets'renderOpenPanel()assert(petButton()~=b and petButton().Parent,'return from Inventory kept destroyed cache')b=petButton()content:FindFirstChild('Hero City Generated Banner'):Destroy()renderOpenPanel()assert(petButton()~=b,'missing content anchor not repaired')`],
 ['compact-profile-invalidates', `renderOpenPanel()local b=petButton()UserInputService.TouchEnabled=true renderOpenPanel()assert(petButton()~=b,'touch layout stale')assert(petButton().Parent.Parent:GetAttribute('GenericPhoneLayout')=='StackedActionsV1')`],
 ['ui-scale-invalidates', `renderOpenPanel()local b=petButton()clientSettings.uiScale=1.2 renderOpenPanel()assert(petButton()~=b,'UI scale stale')`],
 ['missing-task-clock-repairs', `activeTab='Tasks'renderOpenPanel()local b=button('Daily Supply','ClaimDaily')shared.PunchWallGenericPanelRuntime.playtimeLabel:Destroy()renderOpenPanel()assert(button('Daily Supply','ClaimDaily')~=b and shared.PunchWallGenericPanelRuntime.playtimeLabel:IsDescendantOf(content),'missing clock was not repaired')`],
 ['obsolete-canvas-job-cancelled', `renderOpenPanel()content.CanvasPosition=Vector2.new(0,1300)latestStats.PetDropPity=1 renderOpenPanel()activeTab='Inventory'renderOpenPanel()activeTab='Pets'content.CanvasPosition=Vector2.zero renderOpenPanel()content.CanvasPosition=Vector2.new(0,250)advance(.1)assert(content.CanvasPosition.Y==250,'old structural job overwrote new surface scroll')`],
];
function code(body, testcase) {return mock+'\n'+body+'\n'+testcase[1]+`\nprint('GENERIC_PANEL_PASS ${testcase[0]}')`;}
for(const testcase of cases)pass(code(production,testcase),testcase[0]);
for(const testcase of cases.slice(0,2)) {
 const r=execute(code(oldProduction,testcase));
 const expected=testcase[0].startsWith('pets')?'Pets button replaced by idle snapshot':'Tasks button replaced by idle snapshot';
 assert(!r.ok&&r.output.includes(expected),`Baseline ${testcase[0]} must fail at exact lifetime assertion\n${r.output}`);
}
function replaceOnce(source,from,to) {assert.equal(source.split(from).length-1,1,`Mutation target ambiguous: ${from}`);return source.replace(from,()=>to);}
const mutations=[
 ['unconditional-rebuild','if signature and runtime.signature == signature','if false and signature and runtime.signature == signature','pets-idle-press-lifetime','Pets button replaced by idle snapshot'],
 ['ignore-pet-inventory','"PetInventoryJSON", "EquippedPetsJSON"','"EquippedPetsJSON"','pet-inventory-order-invalidates','inventory order not rendered'],
 ['ignore-pet-equipment','"EquippedPetsJSON", "LockedPetsJSON"','"LockedPetsJSON"','pet-equipped-state-invalidates','equip state stale'],
 ['ignore-pet-lock','"LockedPetsJSON",','', 'pet-lock-state-invalidates','locked delete is active'],
 ['ignore-delete-generation','table.insert(fields, tostring(legacyPetMenuRuntime.deleteGeneration))','-- omitted Delete invalidation','delete-arm-retain-confirm-exact','exact confirmation missing'],
 ['ignore-premium-ownership','"OwnedPremiumPetsJSON",','', 'premium-owned-invalidates','premium ownership stale'],
 ['ignore-premium-price','local cached = shared.PunchWallPurchaseRuntime.GamePassPriceCache[passId]','local cached = nil','premium-regional-price-invalidates','regional price stale'],
 ['ignore-playtime-readiness','table.insert(fields, tostring((latestStats.PlaytimeSeconds or 0) >= GameConfig.Rewards.PlaytimeSeconds))','-- omitted readiness','tasks-readiness-and-claims-invalidates','playtime readiness stale'],
 ['omit-clock-refresh','or runtime.UpdateClocks())','or true)','tasks-idle-press-lifetime','playtime text did not update in place'],
 ['ignore-spin-readiness','table.insert(fields, tostring(os.time() >= (tonumber(latestStats.SpinReadyAt) or 0)))','-- omitted spin readiness','tasks-spin-clock-retains','spin readiness stale'],
 ['ignore-anchor-lifetime','and runtime.anchor and runtime.anchor.Parent == content','', 'navigation-and-missing-anchor-invalidates','missing content anchor not repaired'],
 ['ignore-canvas-generation','or runtime.generation ~= generation','', 'obsolete-canvas-job-cancelled','old structural job overwrote new surface scroll'],
 ['ignore-ui-scale','tostring(clientSettings.uiScale or 1)','"constant"','ui-scale-invalidates','UI scale stale'],
];
for(const [name,from,to,target,expected]of mutations) {
 const mutated=replaceOnce(production,from,to);compile(mutated,`compiled mutation ${name}`);
 const testcase=cases.find(c=>c[0]===target);assert(testcase,target);const result=execute(code(mutated,testcase));
 assert(!result.ok&&result.output.includes(expected),`${name} must fail at its specific behavioral assertion\n${result.output}`);
}
const flowNames=['fist-pet-legacy-slot-safety','full-game-real-ui-controls'];
const flowHelpers=[];let compiledFlowSnippets=0;
for(const name of flowNames) {
 const flow=JSON.parse(fs.readFileSync(path.join(root,'work/automation/flows',`${name}.json`),'utf8'));
 const step=flow.steps.find(s=>s.args?.code?.includes('local function verifyIdleControlState('));assert(step,`${name} idle verifier missing`);
 flowHelpers.push(section(step.args.code,'local function verifyIdleControlState(', 'local function observeIdleControl('));
 for(const item of [...flow.steps,...(flow.cleanup||[])])if(item.args?.code){compile(item.args.code,`${name}: ${item.label}`);compiledFlowSnippets++;}
}
assert.equal(flowHelpers[0],flowHelpers[1],'Both real-input flows must apply the same exact idle evidence verifier');
const idleEvidenceCases=String.raw`
local function valid()return {observedSnapshot=true,identityStable=true,canvasStable=true,structuralBefore=4,structuralAfter=4,requestBefore=1,requestAfter=1,hittable=true}end
assert(verifyIdleControlState(valid()))
local faults={
 function(e)e.observedSnapshot=false end,function(e)e.identityStable=false end,function(e)e.canvasStable=false end,
 function(e)e.structuralBefore=nil end,function(e)e.structuralAfter=5 end,function(e)e.requestBefore='1'end,
 function(e)e.requestAfter=2 end,function(e)e.hittable=false end,
}
for i,fault in ipairs(faults)do local e=valid()fault(e)local ok=pcall(verifyIdleControlState,e)assert(not ok,'invalid idle evidence accepted: '..i)end
print('GENERIC_PANEL_PASS idle evidence: 1 valid, 8 rejected')
`;
pass(flowHelpers[0]+idleEvidenceCases,'exact idle evidence helper rejects missing/forged evidence');
const idleGuards=[
 'assert(e.observedSnapshot==true', 'assert(e.identityStable==true', 'assert(e.canvasStable==true',
 "assert(type(e.structuralBefore)=='number'", "assert(type(e.requestBefore)=='number'", 'assert(e.hittable==true',
];
for(const guard of idleGuards) {
 const line=flowHelpers[0].split('\n').find(value=>value.trim().startsWith(guard));assert(line,guard);
 const weakened=replaceOnce(flowHelpers[0],line,'');compile(weakened,'idle evidence weakening compiles');
 const result=execute(weakened+idleEvidenceCases);
 assert(!result.ok&&result.output.includes('invalid idle evidence accepted:'),`Omitted idle guard escaped: ${guard}\n${result.output}`);
}
console.log(JSON.stringify({ok:true,contract:'generic-panel-stability',sourceRoot:root,baselineRef,
 sourceSha256:crypto.createHash('sha256').update(current).digest('hex'),producerSha256:crypto.createHash('sha256').update(production).digest('hex'),
 completeClientCompile:true,executedProducerCases:cases.length,baselineFailuresReproduced:2,compiledMutationControlsRejected:mutations.length,
 compiledFlowSnippets,idleEvidenceValid:1,idleEvidenceFaultsRejected:8,compiledIdleGuardWeakeningControlsRejected:idleGuards.length,
 studioRuntime:'Coordinator-owned; production renderers execute in a deterministic mock'},null,2));
