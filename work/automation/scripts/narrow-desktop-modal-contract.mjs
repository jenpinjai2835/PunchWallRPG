#!/usr/bin/env node
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
const root=path.resolve(import.meta.dirname,'../../..');
const clientPath='work/punch-wall-rpg/src/client/PunchWallClient.client.lua';
const read=p=>fs.readFileSync(path.join(root,p),'utf8').replace(/\r/g,'');
const client=read(clientPath);
const oldResult=spawnSync('git',['show','b7b6663:'+clientPath],{cwd:root,encoding:'utf8'});assert.equal(oldResult.status,0,oldResult.stderr);const old=oldResult.stdout.replace(/\r/g,'');
function between(s,a,b){const i=s.indexOf(a),j=s.indexOf(b,i+a.length);assert(i>=0&&j>i,a);return s.slice(i,j);}
const helpers=between(client,'function shared.PunchWallResolveStandaloneDesktopSize','function shared.PunchWallResolveNarrowMenuGrid');
const dimensions=between(client,'\t\tlocal rebirthLayout = shared.PunchWallResolveStandaloneDesktopSize','\n\t\tfor _, panel in ipairs');
const actions=between(client,'\tlocal rebirthActions = shared.PunchWallStandaloneWindows.RebirthBody:FindFirstChild','\n\tlocal shopOpen =');
const helperLane=between(client,'\t\t\t\t\tlocal options = row:FindFirstChild("Options")','\n\t\t\t\tend');
const inventoryBody=full=>{const s=full.slice(full.indexOf('local narrowPair ='));return between(s,'\t\tif inventoryOpen then','\n\t\telseif shopOpen then').slice('\t\tif inventoryOpen then'.length);};
const currentInventory=inventoryBody(client),oldInventory=inventoryBody(old);
const oldDimensions=between(old,'\t\tshared.PunchWallStandaloneWindows.RebirthPanel.Size = UDim2.fromOffset(720, 468)','\n\t\tfor _, panel in ipairs');
for(const [a,b]of [['local settingsRuntime = {','\ncloseStandaloneWindows = function(reason)'],['renderStandaloneRebirth = function()','\nlocal settingsRuntime = {'],['\tif compact then\n\t\tlocal rebirthWidth','\n\telse\n\t\t']])assert.equal(between(client,a,b),between(old,a,b),'existing settings/rebirth callbacks or compact layout changed');
const indentless=s=>s.split('\n').map(line=>line.trim()).join('\n').trim();
assert.equal(indentless(currentInventory.slice(currentInventory.indexOf('local referenceAspect'))),indentless(oldInventory.slice(oldInventory.indexOf('local referenceAspect')))+'\nend','wide Inventory formula changed');
assert(!/Destroy|Connect|FireServer|Invoke/.test(dimensions+actions+helperLane+currentInventory),'responsive layout must preserve native callbacks and item state');
const inv=read('work/punch-wall-rpg/src/client/InventoryUI.lua');
const existingContract=read('work/automation/scripts/inventory-visual-responsive-contract.mjs');
const expression=between(existingContract,'const code=',';\n\nconst productionOutput').slice('const code='.length);
const originalInventoryProgram=Function('block','return ('+expression+')')((a,b)=>between(inv,a,b));
const inventoryHarness=originalInventoryProgram.slice(0,originalInventoryProgram.indexOf('\nfor _,viewport in ipairs({'));
const flowPath='work/automation/flows/narrow-desktop-menu-real-input.json';
const flow=JSON.parse(read(flowPath));
const oldFlowResult=spawnSync('git',['show','b7b6663:'+flowPath],{cwd:root,encoding:'utf8'});assert.equal(oldFlowResult.status,0,oldFlowResult.stderr);const oldFlow=JSON.parse(oldFlowResult.stdout);
function verifyFlow(candidate){
 const copy=structuredClone(candidate);
 const rebirth=copy.steps.find(s=>s.label==='verify actual RebirthButton route');
 assert(rebirth.args.code.includes("inside(host,safe)")&&rebirth.args.code.includes("inside(close,host)")&&rebirth.args.code.includes('close.AbsoluteSize.Y)>=44'),'actual Rebirth host/44px close gates missing');
 rebirth.args.code=rebirth.args.code.replace(/\n-- BEGIN NARROW REBIRTH GEOMETRY[\s\S]*?-- END NARROW REBIRTH GEOMETRY\n/,'');rebirth.expectRegex.splice(-2);
 const detail=copy.steps.find(s=>s.label==='verify selected fist and pet detail lanes at explicit narrow desktop');
 assert(detail.args.code.includes("verify('Fists','fist:Starter Glove','Starter Fist',1)")&&detail.args.code.includes("verify('Pets',nil,'Forest Pup',4)"),'actual fist/normal-pet selection coverage missing');
 assert(detail.args.code.includes('name.TextFits==true')&&detail.args.code.includes('name.TextSize>=14')&&detail.args.code.includes('overlap(button,name)<1')&&detail.args.code.includes('button.AbsoluteSize.Y)>=44'),'actual selected-item readability/action gates missing');
 assert(detail.args.code.includes('name.Text==string.upper(expectedName)')&&detail.args.code.includes('label.Text==expectedName'),'actual detail/card name normalization must remain distinct');
 const seed=copy.steps.find(s=>s.label==='seed one normal pet for narrow selected-detail geometry');
 assert(seed.args.code.includes("world:GetAttribute('PersistenceMode')=='EphemeralStudio'")&&seed.args.code.includes("p:GetAttribute('ProfileWritable')==false")&&seed.args.code.includes("table.find(pets,'Forest Pup')"),'strict seed and authoritative readback required');
 copy.steps=copy.steps.filter(s=>s!==detail&&s!==seed);
 assert.deepEqual(copy,oldFlow,'all existing narrow fixture/native routes/settings/world/cleanup gates must remain exact');
}
verifyFlow(flow);
const detailCode=flow.steps.find(s=>s.label==='verify selected fist and pet detail lanes at explicit narrow desktop').args.code;
const detailNameProducer=inv.match(/self\.DetailName\.Text = string\.upper\(displayName\)/)?.[0];
const cardNameProducer=inv.match(/cardRef\.name\.Text = [^\n]+/)?.[0];
assert(detailNameProducer&&cardNameProducer,'actual Inventory name producers missing');
const detailNameConsumer=detailCode.match(/name\.Text==[^\n]+? and shown\(name\)/)?.[0].replace(' and shown(name)','');
const cardNameConsumer=detailCode.match(/label\.Text==expectedName/)?.[0];
assert(detailNameConsumer&&cardNameConsumer,'actual flow name consumers missing');
const nameCaseProgram=`for _,expectedName in ipairs({'Starter Fist','Forest Pup'})do
 local item={displayName=expectedName,name='internal-name'}local displayName=tostring(item.displayName or item.name)
 local self={DetailName={}}local cardRef={name={}}
 ${detailNameProducer}
 ${cardNameProducer}
 local name,label=self.DetailName,cardRef.name
 assert(${detailNameConsumer},'actual detail-name consumer differs from producer')
 assert(${cardNameConsumer},'actual mixed-case card lookup differs from producer')
 assert(name.Text~=expectedName,'wrong-case negative did not exercise different values')
end print('ACTUAL_NAME_CASE_PASS=2')`;
const identityConsumer=detailCode.match(/local original=name[^\n]+repeat selection replaced detail identity'\)/)?.[0];
assert(identityConsumer&&identityConsumer.includes('local liveRoot=g.GameMenu.FunctionalInventory'),'repeat selection must resolve the live tree');
const identityProgram=`local function verify(replacement)
 local key='pet:slot:1'local detail={}local name={Parent=detail}detail.DetailName=name
 local root={InventoryWindow={InventoryBody={InventoryDetail=detail}}}
 function root:GetAttribute(k)assert(k=='InventorySelectedKey')return key end
 local g={GameMenu={FunctionalInventory=root}}local task={wait=function()end}
 local a={}function a:Invoke(action,requested)
  assert(action=='SelectInventoryItem'and requested==key)
  if replacement=='root'then
   local clone={InventoryWindow=root.InventoryWindow,GetAttribute=root.GetAttribute}g.GameMenu.FunctionalInventory=clone
  elseif replacement=='detail'then
   local clone={}local newName={Parent=clone}clone.DetailName=newName root.InventoryWindow.InventoryBody.InventoryDetail=clone
  elseif replacement=='name'then detail.DetailName={Parent=detail}end
 end
 ${identityConsumer}
end
assert(pcall(verify,'none'))
for _,replacement in ipairs({'root','detail','name'})do assert(not pcall(verify,replacement),'replacement escaped live identity consumer')end
print('LIVE_IDENTITY_PASS=4')`;
const main=String.raw`
UDim2.fromScale=function(x,y)return UDim2.new(x,0,y,0)end
local shared={}
`+helpers+String.raw`
local function dim(value,total)return value.Scale*total+value.Offset end
local function rect(n,w,h)return {x=dim(n.Position.X,w)-dim(n.Size.X,w)*(n.AnchorPoint and n.AnchorPoint.X or 0),y=dim(n.Position.Y,h)-dim(n.Size.Y,h)*(n.AnchorPoint and n.AnchorPoint.Y or 0),w=dim(n.Size.X,w),h=dim(n.Size.Y,h)}end
local function inside(a,w,h,margin)margin=margin or 0 return a.x>=margin-.001 and a.y>=margin-.001 and a.x+a.w<=w-margin+.001 and a.y+a.h<=h-margin+.001 end
local function overlaps(a,b)return math.min(a.x+a.w,b.x+b.w)>math.max(a.x,b.x)+.001 and math.min(a.y+a.h,b.y+b.h)>math.max(a.y,b.y)+.001 end
local function object(children)local n=node()n.FindFirstChild=function(_,name)return children and children[name]end return n end
local function standalone(width,height,compact)
 local viewport=vec2(width,height)
 local cancel,question,ready=object(),object(),object()
 cancel.Size=UDim2.fromOffset(112,48)cancel.AnchorPoint=vec2(1,.5)
 local actionContainer=object({CancelRebirth=cancel,ConfirmQuestion=question,ReadyHint=ready})
 local rebirthBody=object({Actions=actionContainer})
 shared.PunchWallStandaloneWindows={RebirthPanel=object(),SettingsPanel=object(),RebirthBody=rebirthBody}
`+dimensions+String.raw`
`+actions+String.raw`
 return shared.PunchWallStandaloneWindows,cancel,question,ready
end
local function inventory(width,height)
 local viewport=vec2(width,height)local mainPanel=object()
`+currentInventory+String.raw`
 return mainPanel
end
local function testInventory(width,height,scale,actionCount,expectValid)
 local host=inventory(width,height)local size=host.Size
 local self=makeSelf(actionCount)local savedKey=self._selectedKey local savedSearch=self._search local savedCanvas=self.Grid.CanvasPosition
 InventoryUI.ApplyResponsive(self,vec2(size.X.Offset,size.Y.Offset),false,scale)
 local dw=dim(self.Detail.Size.X,self.Body.Size.X.Offset+self.Window.Size.X.Offset)
 local dh=self.Detail.Size.Y.Offset
 local name=rect(self.DetailName,dw,dh)local area=rect(self.DetailActions,dw,dh)
 local valid=inside(name,dw,dh)and inside(area,dw,dh)and not overlaps(name,area)
 if expectValid then
  check(valid,'selected name/actions overlap or escape actual Inventory drawer')
  check(self.DetailActionLayout.CellSize.X.Offset*scale>=44 and self.DetailActionLayout.CellSize.Y.Offset*scale>=44,'Inventory action below44')
  check(self.DetailName.TextSize*scale>=14,'Inventory name below14')
  check(self._selectedKey==savedKey and self._search==savedSearch and self.Grid.CanvasPosition==savedCanvas,'Inventory selection/search/canvas changed')
 else check(not valid,'historical Inventory overlap not reproduced')end
 return valid
end
for _,width in ipairs({520,600,637,700,899,900,1277,1920})do
 for _,height in ipairs({520,654,801})do
  local windows,cancel,question,ready=standalone(width,height,false)
  for _,panel in ipairs({windows.SettingsPanel,windows.RebirthPanel})do
   panel.AnchorPoint=vec2(.5,.5)panel.Position=UDim2.fromScale(.5,.5)
   local box=rect(panel,width,height)
   check(inside(box,width,height,12),'standalone host outside12px margins')
   local close={x=box.w-58,y=10,w=48,h=48}check(inside(close,box.w,box.h)and close.w>=44 and close.h>=44,'close outside host or too small')
  end
  local bw,bh=windows.RebirthPanel.Size.X.Offset-24,windows.RebirthPanel.Size.Y.Offset-94
  local ah=bh*.23 local cr=rect(cancel,bw,ah)local qr=rect(question,bw,ah)local rr=rect(ready,bw,ah)
  local confirm={x=bw-140,y=(ah-48)/2,w=140,h=48}local review={x=bw-180,y=(ah-48)/2,w=180,h=48}
  check(inside(cr,bw,ah)and inside(confirm,bw,ah)and not overlaps(cr,confirm),'rebirth confirmation controls overlap or escape')
  check(not overlaps(qr,cr)and not overlaps(rr,review),'rebirth copy overlaps actions')
  local settingsLayout={width=windows.SettingsPanel.Size.X.Offset}
  for _,optionWidth in ipairs({172,258})do
   local optionArea={Size=UDim2.fromOffset(optionWidth,48)}local row=object({Options=optionArea})local helper=object()
`+helperLane+String.raw`
   check(70+helper.Size.X.Offset<=settingsLayout.width-24-optionWidth-10-8+.001,'Settings helper overlaps option lane')
  end
  if width>=744 then check(windows.SettingsPanel.Size.X.Offset==640 and windows.RebirthPanel.Size.X.Offset==720,'authored wide size changed')end
 end
end
local windows=standalone(637,654,false)
check(windows.SettingsPanel.Size.X.Offset==613 and windows.SettingsPanel.Size.Y.Offset==420,'recorded Settings fit must be613x420')
check(windows.RebirthPanel.Size.X.Offset==613 and windows.RebirthPanel.Size.Y.Offset==468,'recorded Rebirth fit must be613x468')
local oldSettings={x=(637-640)/2,y=-58+(654-420)/2,w=640,h=420}
check(oldSettings.x==-1.5 and oldSettings.y==59 and not inside(oldSettings,637,654),'actual Settings failure not reproduced')
check((637-720)/2==-41.5,'actual Rebirth failure not reproduced')
for _,size in ipairs({{0,0},{1,1},{24,24},{1920,180},{-1,20},{0/0,math.huge},{math.huge,0}})do
 local p=shared.PunchWallResolveStandaloneDesktopSize(vec2(size[1],size[2]),640,420)
 if size[1]==math.huge then check(p.width==1,'collapsed viewport must remain finite and minimal')end
 check(p.width==p.width and p.height==p.height and p.width>=1 and p.height>=1 and p.width<=640 and p.height<=420,'collapsed viewport must remain finite, no fit claim')
end
local _,cancel,question,ready=standalone(520,520,true)
check(cancel.Position.X.Scale==.75 and question.Size.X.Scale==.48 and ready.Size.X.Scale==.63,'compact action lanes not restored')
for _,width in ipairs({520,600,637,899})do for _,height in ipairs({520,654,801})do for _,scale in ipairs({.8,1,1.2})do for _,n in ipairs({1,4})do testInventory(width,height,scale,n,true)end end end end
local wide=inventory(1277,801)check(wide:GetAttribute('InventoryModalSizing')=='CenteredReference1.50','wide Inventory changed')
print('NARROW_MODAL_PASS='..count)
`;
const program=inventoryHarness+'\n'+main;
const luau=[process.env.LUAU_COMMAND,...fs.readdirSync(os.tmpdir()).filter(n=>n.startsWith('codex-luau-')).sort().reverse().map(n=>path.join(os.tmpdir(),n,'luau.exe'))].find(p=>p&&fs.existsSync(p));assert(luau);const compiler=process.env.LUAU_COMPILE_COMMAND||path.join(path.dirname(luau),'luau-compile.exe');const temp=fs.mkdtempSync(path.join(os.tmpdir(),'smash-narrow-modal-'));let compiled=0;const mutations=[];
function run(name,code,expected){const p=path.join(temp,name+'.luau');fs.writeFileSync(p,code);const c=spawnSync(compiler,['--null',p],{encoding:'utf8'});assert.equal(c.status,0,c.stderr);compiled++;const r=spawnSync(luau,[p],{encoding:'utf8',timeout:10000});if(expected)assert(r.status!==0&&(r.stdout+r.stderr).includes(expected),name+': '+r.stdout+r.stderr);else assert.equal(r.status,0,r.stdout+r.stderr);return r.stdout;}
try{
 run('actual-name-producer-consumer',nameCaseProgram);
 run('wrong-detail-consumer-case',nameCaseProgram.replace(detailNameConsumer,'name.Text==expectedName'),'actual detail-name consumer differs from producer');mutations.push('wrong_detail_consumer_case');
 run('wrong-card-lookup-case',nameCaseProgram.replace(cardNameConsumer,'label.Text==string.upper(expectedName)'),'actual mixed-case card lookup differs from producer');mutations.push('wrong_card_lookup_case');
 run('live-detail-identity',identityProgram);
 run('stale-alias-identity',identityProgram.replace('liveRoot==root and liveDetail==detail and liveName==original and liveName.Parent==liveDetail', 'name==original and name.Parent==detail'),'replacement escaped live identity consumer');mutations.push('stale_alias_identity');
 const out=run('actual-producers',program);const checks=Number(out.match(/NARROW_MODAL_PASS=(\d+)/)?.[1]);assert(checks>400);
 const variants=[
 ['historical_b7_standalone',program.replace(dimensions,oldDimensions),'standalone host outside12px margins'],
 ['uncapped_settings',program.replace('math.min(authoredWidth, math.max(1, width - 24))','authoredWidth'),'standalone host outside12px margins'],
 ['lost_margin',program.replace('width - 24','width'),'standalone host outside12px margins'],
 ['overlap_cancel',program.replace('math.min(bodyWidth * 0.75, bodyWidth - 148)','bodyWidth * 0.75'),'rebirth confirmation controls overlap or escape'],
 ['overlap_hint',program.replace('math.min(bodyWidth * 0.63, bodyWidth - 188)','bodyWidth * 0.63'),'rebirth copy overlaps actions'],
 ['settings_helper_overlap',program.replace('math.min(170, math.max(1, settingsLayout.width - 24 - 70 - optionWidth - 18))','170'),'Settings helper overlaps option lane'],
 ['collapsed_nan',program.replace('viewport.X >= 0 and viewport.X < math.huge and viewport.X or 0','viewport.X'),'collapsed viewport must remain finite'],
 ['old_inventory_host',program.replace(currentInventory,oldInventory),'selected name/actions overlap or escape actual Inventory drawer'],
 ];
 for(const [name,value,error]of variants){assert.notEqual(value,program);run(name,value,error);mutations.push(name);}
 for(const [name,from,to]of [['missing_rebirth_bounds','inside(host,safe)','true'],['missing_detail_overlap','overlap(button,name)<1','true'],['missing_ephemeral_guard',"world:GetAttribute('PersistenceMode')=='EphemeralStudio'",'true']]){
  const candidate=JSON.parse(JSON.stringify(flow).replace(from,to));assert.throws(()=>verifyFlow(candidate));mutations.push(name);
 }
 for(const [i,step]of [...flow.steps,...flow.cleanup].entries())if(step.args?.code){const file=path.join(temp,'flow-'+i+'.luau');fs.writeFileSync(file,step.args.code);const c=spawnSync(compiler,['--null',file],{encoding:'utf8'});assert.equal(c.status,0,c.stderr);compiled++;}
 for(const opt of ['-O0','-O1','-O2']){const r=spawnSync(compiler,[opt,'--null',path.join(root,clientPath)],{encoding:'utf8'});assert.equal(r.status,0,r.stderr);compiled++;}
 console.log(JSON.stringify({ok:true,checks,mutations,compiled,actualInventoryProducer:true,callbacksAndCompactUnchanged:true,native:'pending'},null,2));
}finally{assert.equal(path.dirname(fs.realpathSync(temp)),fs.realpathSync(os.tmpdir()));fs.rmSync(temp,{recursive:true,force:true});}
