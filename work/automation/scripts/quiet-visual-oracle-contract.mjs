import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const relative='work/punch-wall-rpg/src/client/PunchWallClient.client.lua';
const source=fs.readFileSync(path.join(root,relative),'utf8').replace(/\r\n?/g,'\n');
const config=fs.readFileSync(path.join(root,'work/punch-wall-rpg/src/shared/GameConfig.lua'),'utf8');
const targets=[['iteration01-complete-polish',10],['hero-shop-reference-polish',7],['hero-city-theme',3]];
const current={},historical={};
let structuralChecks=0;
for(const [name,index]of targets){
  const file='work/automation/flows/'+name+'.json';
  current[name]=JSON.parse(fs.readFileSync(path.join(root,file),'utf8'));
  const old=spawnSync('git',['show','1529b7d:'+file],{cwd:root,encoding:'utf8'});assert.equal(old.status,0,old.stderr);
  historical[name]=JSON.parse(old.stdout);
  const copy=structuredClone(current[name]);copy.steps[index]=historical[name].steps[index];
  if(name==='iteration01-complete-polish'){
    copy.steps[8]=historical[name].steps[8];
    const prerequisiteStep=structuredClone(current[name].steps[8]);prerequisiteStep.args.code=historical[name].steps[8].args.code;
    assert.deepEqual(prerequisiteStep,historical[name].steps[8],'Only prerequisite code may change in step 9');structuralChecks++;
  }
  assert.deepEqual(copy,historical[name],'Unrelated flow steps/cleanup changed: '+name);structuralChecks++;
  assert.deepEqual(current[name].steps[index].expectRegex,historical[name].steps[index].expectRegex,'Original acceptance markers preserved');structuralChecks++;
}
const objective=current['iteration01-complete-polish'].steps[10].args.code;
const prerequisite=current['iteration01-complete-polish'].steps[8].args.code;
const oldPrerequisite=historical['iteration01-complete-polish'].steps[8].args.code;
const chrome=current['hero-shop-reference-polish'].steps[7].args.code;
const theme=current['hero-city-theme'].steps[3].args.code;
const oldObjective=historical['iteration01-complete-polish'].steps[10].args.code;
const oldChrome=historical['hero-shop-reference-polish'].steps[7].args.code;
const oldTheme=historical['hero-city-theme'].steps[3].args.code;
function between(text,start,end){const a=text.indexOf(start),b=text.indexOf(end,a+start.length);assert(a>=0&&b>a,'Missing exact producer boundary '+start);return text.slice(a,b);}
const objectiveProducer=source.split('\n').find(line=>line.trim().startsWith('widgets.ObjectiveText.Text = string.upper(tostring(tutorial.title'));
assert(objectiveProducer,'Actual title-only producer missing');
const tutorialLine=config.split('\n').find(line=>line.includes('[3] = { id = "BuyStarterFist"'));
const fistLine=config.split('\n').find(line=>line.includes('{ name = "Boxing Glove",'));
assert(tutorialLine&&fistLine);
const title=tutorialLine.match(/title = ("[^"]+")/)[1],detail=tutorialLine.match(/detail = ("[^"]+")/)[1];
const display=fistLine.match(/displayName = ("[^"]+")/)[1],cost=Number(fistLine.match(/cost = ([0-9]+)/)[1]);
assert.equal(cost,180,'Current first-fist boundary changed; review intended tutorial fixture');
const fists=between(config,'GameConfig.Fists = {','-- Coin cost controls pacing inside a band;');
const fistNames=[...fists.matchAll(/\{ name = "([^"]+)"/g)].map(match=>match[1]);
const unlockDepths=config.match(/local fistUnlockDepths = \{([^}]+)\}/)[1].split(',').map(Number);
const unlockDepth=unlockDepths[fistNames.indexOf('Boxing Glove')];assert.equal(unlockDepth,1,'Review first-fist catalog depth boundary');
const server=fs.readFileSync(path.join(root,'work/punch-wall-rpg/src/server/PunchWallBootstrap.server.lua'),'utf8').replace(/\r\n?/g,'\n');
const buy=between(server,'local function buyFist(player, item)','local function ');
const buyGates=between(buy,'\tlocal requiredDepth =','\taddStat(player, "Coins", -item.cost)');
const responsive=between(theme,'local function expectedResponsive','local viewport=');
const actualResponsive=between(source,'shared.PunchWallClassifyResponsiveViewport = function(size)','shared.PunchWallGetResponsiveViewport = function()');
const actualViewport=between(source,'shared.PunchWallGetResponsiveViewport = function()','shared.PunchWallOpenRebirthPanel = function()');
const observedViewport=between(theme,'local viewport=','local titleResponsive=');
const beforeGateFix=spawnSync('git',['show','5e938a2:work/automation/flows/iteration01-complete-polish.json'],{cwd:root,encoding:'utf8'});
assert.equal(beforeGateFix.status,0,beforeGateFix.stderr);
const beforeGateFlow=JSON.parse(beforeGateFix.stdout),withOldPrerequisite=structuredClone(current['iteration01-complete-polish']);
withOldPrerequisite.steps[8]=beforeGateFlow.steps[8];assert.deepEqual(withOldPrerequisite,beforeGateFlow,'Guidance gates fix must preserve every UI/price/BUY/bounds oracle');structuralChecks++;

const prerequisiteMock=`
local flags={PersistenceMode='EphemeralStudio',PersistenceStudioLiveDataOptIn=false,ProfileReady=true,ProfilePersistenceState='EphemeralStudio',ProfileWritable=false,studio=true}
local stats={TutorialStep={Value=1},TutorialCompleted={Value=0},Depth={Value=0},EquippedFist={Value='Starter Glove'},OwnedFistsJSON={Value='starter'}}
local leader={Coins={Value=0}}function stats:FindFirstChild(key)return self[key]end function leader:FindFirstChild(key)return self[key]end
local p={RPGStats=stats,leaderstats=leader,GetAttribute=function(_,key)return flags[key]end}
local def={name='Boxing Glove',displayName=${display},cost=${cost},unlockDepth=${unlockDepth}}
local G={FistDefinition=function()return def end}local require=function()return G end
local H={JSONEncode=function(_,value)return value end,JSONDecode=function(_,raw)return raw=='owned' and {'Starter Glove','Boxing Glove'} or {'Starter Glove'}end}
local setCalls,snapshotCalls=0,0
local function snapshot()
 local result={ok=true}for key,item in pairs(stats)do if type(item)=='table'then result[key]=item.Value end end
 for key,item in pairs(leader)do if type(item)=='table'then result[key]=item.Value end end return result
end
local c={Invoke=function(_,action,values)
 if action=='SetStats'then setCalls+=1
  for key,value in pairs(values)do
   if not (key=='Depth' and flags.ignoreDepth or key=='Coins' and flags.ignoreCoins)then
    local stat=stats[key] or leader[key] assert(stat,'unknown prerequisite stat')stat.Value=value
   end
  end
  if flags.oneCoinShort then leader.Coins.Value=def.cost-1 end
  if flags.grantOwned then stats.OwnedFistsJSON.Value='owned' end
  if flags.equipWrong then stats.EquippedFist.Value='Boxing Glove' end
  local result=snapshot()if flags.setFails then result.ok=false end if flags.badSeedReceipt then result.Depth=-1 end return result
 elseif action=='Snapshot'then snapshotCalls+=1 local result=snapshot()
  if flags.snapshotFails then result.ok=false end
  if flags.badReadback and setCalls>0 then result.Coins=-1 end return result
 end error('Prerequisite may not buy, grant or reset: '..action)
end}
local root={GetAttribute=function(_,key)return flags[key]end}
local storage={PunchWallAutomation=c,GetAttribute=function(_,key)return flags[key]end}
local services={HttpService=H,RunService={IsStudio=function()return flags.studio end},ServerStorage=storage}
local game={Players={GetPlayers=function()return {p}end},ReplicatedStorage={GameConfig={}},GetService=function(_,key)return services[key]end}
local workspace={FindFirstChild=function()return root end}
local function buyGate()
 local player,item=p,def
 local function statValue(_,key,fallback)local stat=stats[key] or leader[key]return stat and stat.Value or fallback end
 local function sendFeedback()end local PolishConfig={Palette={Fail=0}}
 ${buyGates}
 return {ok=true}
end
`;
const verifyPrerequisite=code=>`local result=(function()\n${code}\nend)()\nassert(buyGate().ok,'actual server purchase gates remain unsatisfied')\nassert(leader.Coins.Value==def.cost and stats.Depth.Value==def.unlockDepth,'catalog exact funding/depth boundary differs')\nreturn result`;

const objectiveMock=`
local clock=0 local os={clock=function()return clock end} local task={wait=function(seconds)clock+=seconds end}
local Vector2={new=function(x,y)return {X=x,Y=y}end}
local function node(class,name,x,y,w,h)
 local o={class=class,Name=name,Visible=true,Enabled=true,AbsolutePosition={X=x or 0,Y=y or 0},AbsoluteSize={X=w or 900,Y=h or 700},children={}}
 function o:IsA(kind)return self.class==kind or kind=='GuiObject' and (self.class=='Frame' or self.class=='TextLabel' or self.class=='TextButton' or self.class=='ScrollingFrame')end
 function o:FindFirstChild(name,recursive)for _,c in ipairs(self.children)do if c.Name==name then return c end if recursive then local found=c:FindFirstChild(name,true)if found then return found end end end return nil end
 return o
end
local function child(parent,o)parent.children[#parent.children+1]=o if parent[o.Name]==nil then parent[o.Name]=o end o.Parent=parent return o end
local function text(parent,name,value,x,y,w,h)local o=child(parent,node('TextLabel',name,x,y,w,h))o.Text=value o.TextFits=true o.TextBounds={X=80,Y=16}return o end
local gui=node('ScreenGui','PunchWallHUD')
local safe=child(gui,node('Frame','PixelPerfectHeroCityHUD'))
local objectiveCard=child(safe,node('Frame','TutorialObjectiveHUD',300,20,280,40))
local primary=text(objectiveCard,'ObjectiveText','',320,25,240,30)
local widgets={ObjectiveText=primary}local tutorial={title=${title},detail=${detail}}
${objectiveProducer}
local menu=child(gui,node('Frame','GameMenu',50,80,800,600))menu.Visible=false
local shop=child(menu,node('Frame','FunctionalHeroShop',50,80,800,600))
local scroll=child(shop,node('ScrollingFrame','ShopCatalogScroll',70,160,760,430))scroll.CanvasPosition=Vector2.new(0,0)
local card=child(scroll,node('Frame','Boxing GloveShopCard',80,170,350,130))
local itemTitle=text(card,'Name',string.upper(${display}),100,185,300,24)
local price=text(card,'Price','${cost}',100,218,95,24)
local action=text(card,'Boxing GloveAction','BUY',300,246,100,44)action.class='TextButton'action.Active=true action.Selectable=true
local actionAttrs={ShopActionBound=true}function action:GetAttribute(key)return actionAttrs[key]end
local attrs={OnboardingObjectiveReady=true,OnboardingObjectiveStep=3}
function gui:GetAttribute(key)return attrs[key]end
local stats={TutorialStep={Value=3},TutorialCompleted={Value=0},Depth={Value=${unlockDepth}},EquippedFist={Value='Starter Glove'},OwnedFistsJSON={Value='starter'}}
local p={PlayerGui={PunchWallHUD=gui},RPGStats=stats,leaderstats={Coins={Value=${cost}}}}
local calls={}local faults={}local closes=0
local automation={Invoke=function(_,command,value)
 calls[#calls+1]=command assert(command~='InvokeShopAction' and command~='RequestAction','guidance check must not purchase')
 if command=='CloseMenus'then closes+=1 menu.Visible=false safe.Visible=true if faults.purchase and closes==2 then p.leaderstats.Coins.Value-=1 end return not faults.close end
 if command=='OpenTab' or command=='OpenShopPage'then menu.Visible=true safe.Visible=false return not faults.route end
 if command=='Snapshot'then return {ok=true,shopVisible=not faults.snapshot,activeTab='Fists',shopPage='Fists',inventoryVisible=false}end
 error('unexpected command '..command)
end}
gui.PunchWallClientAutomation=automation
local G={Tutorial={[3]={id='BuyStarterFist',title=${title},detail=${detail}}},FistDefinition=function()return {name='Boxing Glove',displayName=${display},cost=${cost}}end}
local require=function()return G end
local H={JSONEncode=function(_,value)return value end,JSONDecode=function(_,value)return value=='owned' and {'Starter Glove','Boxing Glove'} or {'Starter Glove'}end}
local game={Players={LocalPlayer=p},ReplicatedStorage={GameConfig={}},GetService=function()return H end}
`;

const chromeMock=`
local objects={} local function object(name,class)
 local o={Name=name,class=class or 'Frame',children={},Visible=true}
 function o:IsA(class)return self.class==class end
 function o:FindFirstChild(name)return self.children[name]end
 function o:GetChildren()local out={}for _,c in pairs(self.children)do table.insert(out,c)end return out end
 objects[name]=o return o
end
local function add(parent,name,class)local o=object(name,class)parent.children[name]=o parent[name]=o return o end
local shop=object('Shop')local header=add(shop,'ShopHeader')local footer=add(shop,'ShopFooter')local tabs=add(shop,'ShopTabs')
local title=add(header,'Title','TextLabel')title.Text='SHOP'title.TextFits=true
for _,name in ipairs({'Subtitle','HeaderRedRail','HeaderCyanRail','CloseShop'})do add(header,name)end
header.HeaderRedRail.Visible=false header.HeaderCyanRail.Visible=false
for _,name in ipairs({'SecureLabel','ServerLabel'})do add(footer,name)end
for _,name in ipairs({'Fists','Premium','Boosts','Honor','Robux'})do local tab=add(tabs,name..'ShopTab','TextButton')tab.TextFits=true add(tab,'SelectedRail')end
function shop:GetDescendants()local out={}for _,o in pairs(objects)do if o~=self then table.insert(out,o)end end return out end
local H={JSONEncode=function(_,value)return value end}local automation={Invoke=function()return true end}
local game={Players={LocalPlayer={PlayerGui={PunchWallHUD={PunchWallClientAutomation=automation,GameMenu={FunctionalHeroShop=shop}}}}},GetService=function()return H end}
local task={wait=function()end}
`;

const responsiveProgram=`
local n=0 local function check(v,label)assert(v,label)n+=1 end
local typeof=function(value)return type(value)=='table' and 'Vector2' or type(value)end
local Vector2={zero={X=0,Y=0}}local UserInputService={TouchEnabled=false}local shared={}
${actualResponsive}
${responsive}
for _,s in ipairs({{1400,500,false},{500,1400,false},{1179,500,false},{1180,500,false},{900,519,false},{900,520,false},
 {637,654,false},{874,402,false},{874,402,true},{402,874,true},{1200,800,true},{1200,600,true},{1200,601,true},{900,700,false}})do
 local size={X=s[1],Y=s[2]}UserInputService.TouchEnabled=s[3]
 local expected,compact=expectedResponsive(size,s[3])local actual,actualCompact=shared.PunchWallClassifyResponsiveViewport(size)
 check(expected==actual and compact==actualCompact,'actual responsive producer parity')
end
local profile,compact=expectedResponsive({X=1400,Y=500},false)
check(profile=='Desktop' and not compact,'wide short desktop remains desktop')
local legacyCompact=false or 500<520 check(legacyCompact~=compact,'historical height-only oracle demonstrably disagrees')
local camera={ViewportSize={X=1277,Y=780}}local reference={AbsoluteSize={X=1277,Y=780}}
local gui={attrs={}}function gui:GetAttribute(key)return self.attrs[key]end
gui.PixelPerfectHeroCityHUD=reference
local hud={FindFirstChild=function()return reference end}
local player={PlayerGui={FindFirstChild=function()return hud end}}local workspace={CurrentCamera=camera}
${actualViewport}
local g=gui local U=UserInputService
for _,sample in ipairs({{1277,780,1277,780,false},{1400,500,1400,500,false},{874,402,749,361,true},{100,100,900,700,false},{637,654,636,654,false}})do
 camera.ViewportSize={X=sample[1],Y=sample[2]}reference.AbsoluteSize={X=sample[3],Y=sample[4]}U.TouchEnabled=sample[5]
 local actual,source=shared.PunchWallGetResponsiveViewport()local profile=shared.PunchWallClassifyResponsiveViewport(actual)
 gui.attrs={ResponsiveProfile=profile,ResponsiveViewportSource=source,ResponsiveViewportWidth=math.floor(actual.X+.5),ResponsiveViewportHeight=math.floor(actual.Y+.5)}
 local function observe()
 ${observedViewport}
 return viewportSource,profile,compact
 end
 local observed,observedProfile=observe()check(observed==source and observedProfile==profile,'observed source/viewport is independently matched')
 gui.attrs.ResponsiveProfile='Wrong'check(not pcall(observe),'wrong published responsive profile rejects')
 gui.attrs.ResponsiveProfile=profile gui.attrs.ResponsiveViewportWidth+=1 check(not pcall(observe),'wrong published dimensions reject')
end
print('PASS '..n)
`;

const dirs=[process.env.PUNCH_WALL_LUAU_TOOL_DIR,...fs.readdirSync(os.tmpdir(),{withFileTypes:true}).filter(d=>d.isDirectory()&&d.name.startsWith('codex-luau-')).map(d=>path.join(os.tmpdir(),d.name))].filter(Boolean);
const luau=dirs.map(dir=>path.join(dir,process.platform==='win32'?'luau.exe':'luau')).find(fs.existsSync);assert(luau,'Luau CLI required');
const compiler=path.join(path.dirname(luau),process.platform==='win32'?'luau-compile.exe':'luau-compile');assert(fs.existsSync(compiler));
const directory=fs.mkdtempSync(path.join(os.tmpdir(),'smash-quiet-oracle-contract-'));
let compiled=0,executed=0;const controls=[];
function compile(name,code){const file=path.join(directory,name+'.luau');fs.writeFileSync(file,code);const r=spawnSync(compiler,['--null',file],{encoding:'utf8',timeout:15000});assert.equal(r.status,0,r.stderr);compiled++;return file;}
function run(name,code){const file=compile(name,code);const r=spawnSync(luau,[file],{encoding:'utf8',timeout:15000});executed++;if(r.status!==0){const lines=code.split('\n');r.stderr+='\nFixture source:\n'+lines.map((line,index)=>`${index+1}: ${line}`).join('\n');}return r;}
function fixture(name,prefix,setup,code,pass,after='true'){
 const result=run(name,prefix+'\n'+setup+'\nlocal ok,result=pcall(function()\n'+code+`\nend)assert(ok==${pass},'${name}: '..tostring(result)) assert(${after},'${name} outcome')`);
 assert.equal(result.status,0,result.stderr||result.stdout);controls.push(name);
}
try {
 for(const [name,code]of [['prerequisite',prerequisite],['objective',objective],['shop',chrome],['theme',theme]])compile(name,code);
 fixture('catalog-prerequisites-meet-actual-server-gates',prerequisiteMock,'',verifyPrerequisite(prerequisite),true,"setCalls==1 and snapshotCalls==2 and result.unowned and result.cost==def.cost and result.depth==def.unlockDepth and stats.OwnedFistsJSON.Value=='starter'");
 fixture('historical-fixture-leaves-actual-depth-locked',prerequisiteMock,'',oldPrerequisite,true,"buyGate().ok==false and buyGate().reason=='depth_locked' and stats.Depth.Value==0 and leader.Coins.Value==0");
 fixture('actual-server-rejects-one-coin-short',prerequisiteMock,'stats.Depth.Value=def.unlockDepth leader.Coins.Value=def.cost-1','return buyGate()',true,"result.ok==false and result.reason=='not_enough_coins'");
 for(const [name,setup]of [
  ['prerequisite-missing-depth','flags.ignoreDepth=true'],['prerequisite-walllevel-is-not-depth','flags.ignoreDepth=true stats.WallLevel={Value=999}'],
  ['prerequisite-missing-coins','flags.ignoreCoins=true'],['prerequisite-one-coin-short','flags.oneCoinShort=true'],
  ['prerequisite-already-owned',"stats.OwnedFistsJSON.Value='owned'"],['prerequisite-accidental-grant','flags.grantOwned=true'],
  ['prerequisite-accidental-equip','flags.equipWrong=true'],['prerequisite-set-failed','flags.setFails=true'],
  ['prerequisite-snapshot-failed','flags.snapshotFails=true'],['prerequisite-seed-receipt-disagrees','flags.badSeedReceipt=true'],
  ['prerequisite-readback-disagrees','flags.badReadback=true'],['prerequisite-missing-catalog-depth','def.unlockDepth=nil'],
  ['prerequisite-live-profile',"flags.ProfilePersistenceState='Live'"],['prerequisite-live-optin','flags.PersistenceStudioLiveDataOptIn=true'],
 ])fixture(name,prerequisiteMock,setup,verifyPrerequisite(prerequisite),false);
 for(const [name,from,to]of [
  ['missing-depth-in-fixture','Depth=requiredDepth,',''],['missing-funding-in-fixture',',Coins=def.cost',''],
  ['excess-funding-in-fixture','Coins=def.cost','Coins=def.cost+1'],
 ]){const changed=prerequisite.replace(from,to);assert.notEqual(changed,prerequisite);fixture(name,prerequisiteMock,'',verifyPrerequisite(changed),false);}
 fixture('current-objective-real-route',objectiveMock,'',objective,true,"result.step==3 and result.objective==string.upper(tutorial.title) and result.purchaseGuidance.price=='180' and result.unchangedAfterClose and closes==2");
 fixture('historical-objective-fails-title-only-producer',objectiveMock,'',oldObjective,false,"string.find(tostring(result),'purchase cost guidance missing',1,true)~=nil");
 for(const [name,setup]of [
  ['wrong-primary-title',"primary.Text='BUY WRONG FIST'"],['old-duplicated-primary',"primary.Text=string.upper(tutorial.title)..' 180'"],
  ['wrong-step','stats.TutorialStep.Value=2'],['completed-tutorial','stats.TutorialCompleted.Value=1'],['unready-objective','attrs.OnboardingObjectiveReady=false'],
  ['wrong-published-step','attrs.OnboardingObjectiveStep=2'],['hidden-primary','primary.Visible=false'],['clipped-primary','primary.TextFits=false'],
  ['offscreen-primary','primary.AbsolutePosition.X=1000'],['wrong-price',"price.Text='179'"],['clipped-price','price.TextFits=false'],['hidden-price','price.Visible=false'],
  ['wrong-card-title',"itemTitle.Text='WRONG FIST'"],['hidden-card-title','itemTitle.Visible=false'],['offscreen-card-title','itemTitle.AbsolutePosition.X=1000'],
  ['wrong-shop-route','faults.route=true'],['wrong-shop-snapshot','faults.snapshot=true'],
  ['owned-instead-of-buy',"stats.OwnedFistsJSON.Value='owned'"],['unbound-action','actionAttrs.ShopActionBound=false'],['disabled-buy','action.Active=false'],
  ['small-buy-target','action.AbsoluteSize.Y=43'],['wrong-buy-state',"action.Text='EQUIP'"],['clipped-card','card.AbsolutePosition.X=1000'],['accidental-purchase','faults.purchase=true'],
 ])fixture(name,objectiveMock,setup,objective,false);
 fixture('current-chrome-hides-decorative-rails',chromeMock,'',chrome,true);
 for(const [name,setup]of [['wrong-shop-title',"title.Text='WRONG'"],['duplicate-close',"add(footer,'CloseShopBottom','TextButton').TextFits=true"]]){
  fixture(name+'-rejected',chromeMock,setup,chrome,false);
  fixture(name+'-historical-false-pass',chromeMock,setup,oldChrome,true);
 }
 for(const [name,setup]of [['missing-close',"header.children.CloseShop=nil"],['missing-rail',"header.children.HeaderRedRail=nil"],
  ['clipped-shop-title','title.TextFits=false'],['missing-tab',"tabs.children.RobuxShopTab=nil"],['extra-tab',"add(tabs,'OtherShopTab','TextButton').TextFits=true"]])fixture(name,chromeMock,setup,chrome,false);
 const response=run('responsive-source-parity',responsiveProgram);assert.equal(response.status,0,response.stderr);controls.push(response.stdout.trim());
 const weakChrome=chrome.replace('ok=not not chrome','ok=chrome~=nil').replace('chrome=not not chrome','chrome=chrome~=nil');assert.notEqual(weakChrome,chrome);
 fixture('weak-chrome-demonstrably-admits-wrong-title',chromeMock,"title.Text='WRONG'",weakChrome,true);
 const weakPrice=objective.replace('view.price==expected.price and view.priceFits','view.priceFits');assert.notEqual(weakPrice,objective);
 fixture('weak-price-demonstrably-admits-wrong-cost',objectiveMock,"price.Text='179'",weakPrice,true);
 const weakStep=objective.replace('view.step==3 and view.completed==0 and view.ready','view.completed==0 and view.ready');assert.notEqual(weakStep,objective);
 fixture('weak-step-demonstrably-admits-wrong-state',objectiveMock,'stats.TutorialStep.Value=2',weakStep,true);
 const weakBounds=objective.replace('view.textFits and view.safeBounds','view.textFits');assert.notEqual(weakBounds,objective);
 fixture('weak-bounds-demonstrably-admits-offscreen-objective',objectiveMock,'primary.AbsolutePosition.X=1000',weakBounds,true);
 const changedBreakpoint=responsiveProgram.replace('if shortSide<520 and longSide<1180 then','if shortSide<520 then');assert.notEqual(changedBreakpoint,responsiveProgram);
 const breakpointResult=run('weakened-breakpoint',changedBreakpoint);assert(breakpointResult.status!==0&&breakpointResult.stderr.includes('actual responsive producer parity'),'Old breakpoint must fail against production');
 assert(oldTheme.includes('U.TouchEnabled or workspace.CurrentCamera.ViewportSize.Y<520'),'Historical breakpoint control changed');
 console.log(JSON.stringify({ok:true,studioUsed:false,structuralChecks,compiledPrograms:compiled,executedPrograms:executed,controls,mutationControls:8},null,2));
} finally {for(const name of fs.readdirSync(directory))fs.unlinkSync(path.join(directory,name));fs.rmdirSync(directory);}
