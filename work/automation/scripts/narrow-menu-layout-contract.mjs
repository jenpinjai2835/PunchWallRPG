#!/usr/bin/env node
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
const root=path.resolve(import.meta.dirname,'../../..');
const read=p=>fs.readFileSync(path.join(root,p),'utf8').replace(/\r/g,'');
const clientPath='work/punch-wall-rpg/src/client/PunchWallClient.client.lua';
const client=read(clientPath);
function historical(p){const r=spawnSync('git',['show','85c51e5:'+p],{cwd:root,encoding:'utf8'});assert.equal(r.status,0,r.stderr);return r.stdout.replace(/\r/g,'');}
function between(s,a,b,from=0){const start=s.indexOf(a,from),end=s.indexOf(b,start+a.length);assert(start>=0&&end>start,a);return s.slice(start,end);}
const oldClient=historical(clientPath);
const helpers=between(client,'function shared.PunchWallResolveNarrowMenuGrid','\nlocal rankWidgets = (function()');
const enforce=between(client,'local function enforceReferenceTouchTarget','\nlocal function setPhoneOpticalScale');
const authorStart='\t\treferenceInventory.Position, referenceInventory.Size = designRect(';
const authorEnd='\n\t\tshared.PunchWallSoundToolButton.AnchorPoint';
const authored=between(client,authorStart,authorEnd);
const oldAuthored=between(oldClient,authorStart,authorEnd);
const resetStart=client.indexOf('\tgui:SetAttribute("ResponsivePhoneScale", phoneScale)');
const metadata=between(client,'\treferenceHUD:SetAttribute("RightMenuLayoutMode", "UniformIconGridV1")','\tlocal coreGuiTopLeft',resetStart);
const modal=between(client,'\t\t\tlocal genericLayout = shared.PunchWallResolveGenericDesktopModal(viewport)','\n\t\t\tcloseButton.Position');
const oldModal=between(oldClient,'\t\t\tmainPanel.Size = UDim2.fromOffset(677, 408)','\n\t\t\tcloseButton.Position');
assert(!/Destroy|Clone|Connect|FireServer/.test(authored),'layout must preserve native button instances and callbacks');
const compact=between(client,'\t\tlocal compactMenuWidth =','\n\t\tfor utilityIndex, button');
assert(!compact.includes('ResolveNarrowMenuGrid'),'compact placement must remain separate');
assert(client.includes('content.AutomaticCanvasSize = Enum.AutomaticSize.Y')&&client.includes('button.Size = UDim2.fromOffset(112, 44)'),'generic content scroll and action floor changed');
const rightPath='work/automation/flows/right-hud-menu-uniform-grid.json';
const right=JSON.parse(read(rightPath)),oldRight=JSON.parse(historical(rightPath));
const geometryStep=right.steps.find(s=>s.label==='right HUD actions share one uniform icon grid');
const geometry=between(geometryStep.args.code,'-- BEGIN RIGHT MENU GEOMETRY ASSERTIONS','-- END RIGHT MENU GEOMETRY ASSERTIONS');
const safePath='work/automation/flows/iteration03-safearea-destruction.json';
const safe=JSON.parse(read(safePath)),oldSafe=JSON.parse(historical(safePath));
const safeStep=safe.steps.find(s=>s.label==='actual HUD and standalone Settings fit safe area with touch targets');
const modalOracle=between(safeStep.args.code,'-- BEGIN GENERIC MODAL ASSERTIONS','-- END GENERIC MODAL ASSERTIONS');
const inputNames=['InventoryButton','ShopButton','PetsButton','QuestsButton','RebirthButton','MoreTool'];
function verifyFlowShape(r,s){
 const copy=structuredClone(r);
 assert.equal(copy.steps.filter(step=>step.tool==='user_mouse_input').length,6,'six actual input routes required');
 for(const name of inputNames){
  const pre=copy.steps.find(step=>step.label==='precheck actual '+name+' hitbox');
  const click=copy.steps.find(step=>step.label==='native click '+name);
  const post=copy.steps.find(step=>step.label==='verify actual '+name+' route');
  assert(pre.args.code.includes("GetGuiObjectsAtPosition")&&pre.args.code.includes('size.X>=44 and size.Y>=44'),'actual input precheck weakened');
  assert.equal(click.args.actions.filter(a=>a.action==='mouseButtonDown').length,1);
  assert.equal(click.args.actions.filter(a=>a.action==='mouseButtonUp').length,1);
  for(const action of click.args.actions.filter(a=>a.instance_path_segments))assert.equal(action.instance_path_segments.at(-1),name);
  assert(post.args.code.includes("a:Invoke('Snapshot')")&&post.args.code.includes("RightMenuNativeActivationCount')==1"),'native action observation missing');
  assert(!/Invoke\('(?:Open|Select|Set|Request)/.test(post.args.code),'postcondition must not perform the requested action');
 }
 copy.steps.splice(4,18);copy.steps[2]=oldRight.steps[2];
 assert.deepEqual(copy,oldRight,'optical-art, console, and lifecycle gates must remain unchanged');
 const normalized=structuredClone(s);
 const index=normalized.steps.findIndex(step=>step.label===safeStep.label);
 assert(normalized.steps[index].args.code.includes("assertContained(safe,host)")&&normalized.steps[index].args.code.includes("effectivelyVisible(host)"),'actual modal visibility/bounds gate missing');
 assert(normalized.steps[index].args.code.includes("assertContained(scroller,last)")&&normalized.steps[index].args.code.includes('scroller.CanvasPosition=before'),'actual last-action scrolling must be checked and restored');
 normalized.steps[index]=oldSafe.steps[index];
 assert.deepEqual(normalized,oldSafe,'wall, reward, boss, debris and settings gates must remain unchanged');
}
verifyFlowShape(right,safe);
const fullUI=read('work/automation/flows/full-game-real-ui-controls.json');
assert(fullUI.includes('c03ShopMin>=44')&&fullUI.includes('b.AbsoluteSize.X>=44 and b.AbsoluteSize.Y>=44')&&fullUI.includes('real click reference Shop open'),'existing real Shop input gate must remain strict');
const setup=String.raw`
local shared={}
local Vector2={new=function(x,y)return {X=x,Y=y}end,zero={X=0,Y=0}}
local ud={}
ud.__eq=function(a,b)return a.X.Scale==b.X.Scale and a.X.Offset==b.X.Offset and a.Y.Scale==b.Y.Scale and a.Y.Offset==b.Y.Offset end
local UDim2={}
function UDim2.new(x,xo,y,yo)return setmetatable({X={Scale=x,Offset=xo},Y={Scale=y,Offset=yo}},ud)end
function UDim2.fromOffset(x,y)return UDim2.new(0,x,0,y)end
function UDim2.fromScale(x,y)return UDim2.new(x,0,y,0)end
local methods={}local mt={}
mt.__index=function(x,key)if key=='Parent'then return rawget(x,'_parent')end return methods[key]or rawget(x,key)end
mt.__newindex=function(x,key,value)if key=='Parent'then rawset(x,'_parent',value)if value then table.insert(value.children,x)end else rawset(x,key,value)end end
local Instance={}
function Instance.new(kind)return setmetatable({ClassName=kind,Name=kind,children={},attributes={},Visible=true,Active=true,Selectable=true,AnchorPoint=Vector2.zero},mt)end
function methods:IsA(kind)return self.ClassName==kind or kind=='GuiObject'and(self.ClassName=='Frame'or self.ClassName=='ImageButton'or self.ClassName=='TextButton'or self.ClassName=='ScrollingFrame')end
function methods:GetAttribute(key)return self.attributes[key]end
function methods:SetAttribute(key,value)self.attributes[key]=value end
function methods:FindFirstChild(name)for _,child in ipairs(self.children)do if child.Name==name then return child end end end
local function object(kind,name,parent)local x=Instance.new(kind)x.Name=name x.Parent=parent return x end
local function resolve(x,host,aspect)
 local size,pos=x.Size,x.Position
 local width=size.X.Scale*host.AbsoluteSize.X+size.X.Offset
 local height=size.Y.Scale*host.AbsoluteSize.Y+size.Y.Offset
 if aspect then width=math.min(width,height*aspect)height=width/aspect end
 local limit=x:FindFirstChild('MinimumTouchTarget')
 if limit then local factor=math.max(1,limit.MinSize.X/width,limit.MinSize.Y/height)width*=factor height*=factor end
 x.AbsoluteSize={X=width,Y=height}
 x.AbsolutePosition={X=host.AbsolutePosition.X+pos.X.Scale*host.AbsoluteSize.X+pos.X.Offset-width*x.AnchorPoint.X,Y=host.AbsolutePosition.Y+pos.Y.Scale*host.AbsoluteSize.Y+pos.Y.Offset-height*x.AnchorPoint.Y}
end
local function designRect(x,y,width,height)return UDim2.fromScale(x/1672,y/941),UDim2.fromScale(width/1672,height/941)end
local Enum={AutomaticSize={Y='Y'}}
`;
function program({producer=helpers,caller=authored,modalCaller=modal,rightOracle=geometry,genericOracle=modalOracle,tail=''}={}){
 return setup+'\n'+producer+'\n'+enforce+'\n'+rightOracle+'\n'+genericOracle+String.raw`
local function scene(width,height,originX,originY)
 local viewport={X=width,Y=height}
 local referenceHUD=object('Frame','PixelPerfectHeroCityHUD')
 referenceHUD.AbsolutePosition={X=originX or 0,Y=originY or 0}
 referenceHUD.AbsoluteSize={X=width,Y=height}
 local referenceInventory=object('ImageButton','InventoryButton',referenceHUD)
 local referenceShop=object('ImageButton','ShopButton',referenceHUD)
 local referencePets=object('ImageButton','PetsButton',referenceHUD)
 local referenceQuests=object('ImageButton','QuestsButton',referenceHUD)
 shared.PunchWallReferenceRebirth=object('ImageButton','RebirthButton',referenceHUD)
 enforceReferenceTouchTarget(referenceInventory)
 local buttons={referenceInventory,referenceShop,referencePets,referenceQuests,shared.PunchWallReferenceRebirth}
 local inventoryMenuX,rightMenuColumnX,rightMenuTop,rightMenuIconWidth,rightMenuIconHeight,rightMenuIconGap=1480,1570,296,87,111,3
 local function apply(newWidth,newHeight)
  viewport.X,viewport.Y=newWidth,newHeight referenceHUD.AbsoluteSize={X=newWidth,Y=newHeight}
`+metadata+'\n'+caller+String.raw`
  for _,button in ipairs(buttons)do resolve(button,referenceHUD,(button.Name=='RebirthButton'and 82 or 87)/111)end
 end
 apply(width,height)
 local mainPanel=object('Frame','GameMenu')mainPanel.AnchorPoint=Vector2.new(.5,.5)
`+modalCaller+String.raw`
 resolve(mainPanel,referenceHUD)
 local content=object('ScrollingFrame','Content',mainPanel)content.ScrollingEnabled=true content.AutomaticCanvasSize=Enum.AutomaticSize.Y
 local close=object('TextButton','Close',mainPanel)close.AbsoluteSize={X=44,Y=44}
 return referenceHUD,mainPanel,buttons,apply
end
`+tail;
}
const positive=String.raw`
local count=0
for _,width in ipairs({520,637,700,845,897,898,900,1000,1277,1672,2048})do
 for _,height in ipairs({520,654,780,941})do
  for _,origin in ipairs({{0,0},{17,-58}})do
   local hud,modal,buttons,apply=scene(width,height,origin[1],origin[2])
   assert(verifyRightMenu(hud,'Desktop').allFiveTargets,'actual right menu fails')
   assert(verifyGenericModal(modal,hud),'actual generic modal fails')
   local originals=table.clone(buttons)
   apply(637,654)assert(verifyRightMenu(hud,'Desktop').layout=='NarrowDesktopUniformIconGridV1')
   apply(1672,941)assert(verifyRightMenu(hud,'Desktop').layout=='UniformIconGridV1')
   for i,button in ipairs(buttons)do assert(button==originals[i],'native button replaced by resize')end
   count+=5
  end
 end
end
local hud,modal=scene(637,654,0,-58)
assert(modal.AbsolutePosition.X==12 and modal.AbsoluteSize.X==613,'recorded narrow desktop modal dimensions')
assert(math.abs(modal.AbsolutePosition.Y-(-58+654*.52-408*.5))<.00001,'modal origin-offset centering changed')
print('NARROW_LAYOUT_PASS='..count)
`;
const candidates=[process.env.LUAU_COMMAND,...fs.readdirSync(os.tmpdir()).filter(n=>n.startsWith('codex-luau-')).sort().reverse().map(n=>path.join(os.tmpdir(),n,'luau.exe')),'luau'];
const luau=candidates.find(c=>c&&spawnSync(c,['--help'],{encoding:'utf8'}).status===0);assert(luau,'Luau required');
const compiler=process.env.LUAU_COMPILE_COMMAND||path.join(path.dirname(luau),'luau-compile.exe');
const temp=fs.mkdtempSync(path.join(os.tmpdir(),'smash-narrow-menu-'));
let compiled=0,executed=0;const mutations=[];
function run(name,text,expected){
 const file=path.join(temp,name+'.luau');fs.writeFileSync(file,text);
 const c=spawnSync(compiler,['--null',file],{encoding:'utf8'});assert.equal(c.status,0,c.stderr);compiled++;
 const result=spawnSync(luau,[file],{encoding:'utf8',timeout:10000});executed++;
 const output=(result.stdout||'')+(result.stderr||'');
 if(expected)assert(result.status!==0&&output.includes(expected),name+': '+output);else assert.equal(result.status,0,name+': '+output);
 return output;
}
try{
 const checks=Number(run('production',program({tail:positive})).match(/NARROW_LAYOUT_PASS=(\d+)/)?.[1]);assert.equal(checks,440);
 const old=run('historical85',program({caller:oldAuthored,modalCaller:oldModal,tail:String.raw`
local hud,modal,buttons=scene(637,654,0,-58)
local inventory,shop=buttons[1],buttons[2]
local gap=shop.AbsolutePosition.X-inventory.AbsolutePosition.X-inventory.AbsoluteSize.X
assert(math.abs(shop.AbsoluteSize.X-33.145334928229665)<.00001,'historical actual size not reproduced')
assert(math.abs(gap-(-9.711722488038247))<.00002,'historical actual overlap not reproduced')
assert(not pcall(verifyGenericModal,modal,hud),'historical oversized modal must fail')
print('HISTORICAL_85_FAIL_BEFORE_PASS')
`}));assert(old.includes('HISTORICAL_85_FAIL_BEFORE_PASS'));
 const sources=[
  ['small_targets',helpers.replace('local width, gap, margin = 48, 4, 12','local width, gap, margin = 32, 4, 12'),'menu outside safe host'],
  ['negative_gap',helpers.replace('local width, gap, margin = 48, 4, 12','local width, gap, margin = 48, -1, 12'),'menu buttons overlap'],
  ['offscreen',helpers.replace('local right = viewport.X - margin - width','local right = viewport.X + 12 - width'),'menu outside safe host'],
  ['wrong_rebirth_ratio',helpers.replace('width * 111 / 82','width * 111 / 87'),'narrow menu lost authored icon ratios'],
 ];
 for(const [name,producer,expected]of sources){assert.notEqual(producer,helpers);run(name,program({producer,tail:positive}),expected);mutations.push(name);}
 const giantModal=modal.replace('genericLayout.width, genericLayout.height','677, 408');
 run('unbounded_modal',program({modalCaller:giantModal,tail:positive}),'generic modal lost the 12px safe margin');mutations.push('unbounded_modal');
 const wrongCenter=modal.replace('genericLayout.centerY','genericLayout.centerY - 200');
 run('wrong_modal_center',program({modalCaller:wrongCenter,tail:positive}),'generic modal lost the 12px safe margin');mutations.push('wrong_modal_center');
 const negatives=String.raw`
local function rejects(change)
 local hud,modal,buttons=scene(637,654,0,-58)
 change(hud,modal,buttons)
 assert(not pcall(verifyRightMenu,hud,'Desktop'),'wrong menu geometry must fail')
end
rejects(function(hud,modal,buttons)buttons[2].AbsoluteSize.X=33 end)
rejects(function(hud,modal,buttons)buttons[2].AbsolutePosition.X=buttons[1].AbsolutePosition.X end)
rejects(function(hud,modal,buttons)buttons[4].AbsolutePosition.Y+=5 end)
rejects(function(hud,modal,buttons)buttons[5].Visible=false end)
rejects(function(hud)hud:SetAttribute('RightMenuLayoutMode','UniformIconGridV1')end)
local hud,modal=scene(637,654,0,-58)
modal:FindFirstChild('Close').AbsoluteSize.Y=43
assert(not pcall(verifyGenericModal,modal,hud),'small generic action must fail')
modal:FindFirstChild('Close').AbsoluteSize.Y=44
modal:FindFirstChild('Content').ScrollingEnabled=false
assert(not pcall(verifyGenericModal,modal,hud),'disabled generic scroll must fail')
print('NARROW_NEGATIVE_SCENARIOS_PASS=7')
`;
 run('bad-native-geometry',program({tail:negatives}));
 const smallWideTargets=String.raw`
local hud,modal,buttons=scene(1000,654,0,-58)
for _,button in ipairs(buttons)do button.AbsoluteSize={X=33,Y=50}end
assert(not pcall(verifyRightMenu,hud,'Desktop'),'minimum target negative control')
print('PASS')
`;
 run('small-wide-targets',program({tail:smallWideTargets}));
 const weakened=geometry.replace("assert(math.min(s.X,s.Y)>=44,","assert(true,");
 run('small_target_oracle',program({rightOracle:weakened,tail:smallWideTargets}),'minimum target negative control');mutations.push('small_target_oracle');
 const wrongInput=structuredClone(right);wrongInput.steps.find(s=>s.label==='native click ShopButton').args.actions.find(a=>a.action==='mouseButtonDown').instance_path_segments[4]='PetsButton';
 assert.throws(()=>verifyFlowShape(wrongInput,safe));mutations.push('wrong_native_input_target');
 const wrongWall=structuredClone(safe);wrongWall.steps.find(s=>s.label==='break depth block with bounded camera-safe physics').expectRegex.pop();
 assert.throws(()=>verifyFlowShape(right,wrongWall),/wall, reward/);mutations.push('unchanged_world_gates');
 for(const [fi,flow]of [right,safe].entries())for(const [index,step]of [...flow.steps,...flow.cleanup].entries())if(step.args?.code){
  const file=path.join(temp,'flow-'+fi+'-'+index+'.luau');fs.writeFileSync(file,step.args.code);
  const c=spawnSync(compiler,['--null',file],{encoding:'utf8'});assert.equal(c.status,0,c.stderr);compiled++;
 }
 const sourceCompile=spawnSync(compiler,['--null',path.join(root,clientPath)],{encoding:'utf8'});assert.equal(sourceCompile.status,0,sourceCompile.stderr);compiled++;
 console.log(JSON.stringify({ok:true,checks,negativeScenarios:8,mutations,compiled,executed,historical85FailBefore:true,nativeRuntime:'pending'},null,2));
}finally{
 const resolved=fs.realpathSync(temp);
 assert.equal(path.dirname(resolved),fs.realpathSync(os.tmpdir()));assert(path.basename(resolved).startsWith('smash-narrow-menu-'));
 fs.rmSync(resolved,{recursive:true,force:true});
}
