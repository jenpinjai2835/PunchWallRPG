#!/usr/bin/env node
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {spawnSync} from 'node:child_process';

const root=path.resolve(import.meta.dirname,'../../..');
const sourcePath='work/punch-wall-rpg/src/client/InventoryUI.lua';
const read=p=>fs.readFileSync(path.join(root,p),'utf8').replace(/\r/g,'');
const source=read(sourcePath);
function between(s,a,b){const i=s.indexOf(a),j=s.indexOf(b,i+a.length);assert(i>=0&&j>i,a);return s.slice(i,j);}
const oldResult=spawnSync('git',['show','63eeb8f:'+sourcePath],{cwd:root,encoding:'utf8'});assert.equal(oldResult.status,0,oldResult.stderr);const old=oldResult.stdout.replace(/\r/g,'');
const responsive=s=>between(s,'function InventoryUI:ApplyResponsive(', 'function InventoryUI:_enabledActionNames(');
const refit=between(source,'function InventoryUI:_refitDetailPreview()', 'function InventoryUI:_applyItemArt(');
const signal='\tself:_connect(self.DetailPetPreview.viewport:GetPropertyChangedSignal("AbsoluteSize"), function()\n\t\tself:_refitDetailPreview()\n\tend)\n';
assert(source.includes(signal),'bounded detail resize subscription missing');
assert.equal(source.replace(signal,'').replace(refit,'').replace(responsive(source),responsive(old)),old,'unrelated construction, actions, cache, render or authority changed');
assert(!/Connect|Clone|Destroy|task\.|RenderStepped|Heartbeat/.test(refit),'refit must reuse the existing preview without work loops');
const existing=read('work/automation/scripts/inventory-visual-responsive-contract.mjs');
const expression=between(existing,'const code=',';\n\nconst productionOutput').slice('const code='.length);
function harness(s){const code=Function('block','return ('+expression+')')((a,b)=>between(s,a,b));return code.slice(0,code.indexOf('\nfor _,viewport in ipairs({'));}
const geometry=String.raw`
local function box(n,w,h)
 local width=n.Size.X.Scale*w+n.Size.X.Offset local height=n.Size.Y.Scale*h+n.Size.Y.Offset
 return {x=n.Position.X.Scale*w+n.Position.X.Offset-n.AnchorPoint.X*width,y=n.Position.Y.Scale*h+n.Position.Y.Offset-n.AnchorPoint.Y*height,w=width,h=height}
end
local function inside(a,w,h)return a.x>=-.01 and a.y>=-.01 and a.x+a.w<=w+.01 and a.y+a.h<=h+.01 end
local function overlap(a,b)return math.min(a.x+a.w,b.x+b.w)>math.max(a.x,b.x)+.01 and math.min(a.y+a.h,b.y+b.h)>math.max(a.y,b.y)+.01 end
local function selected(width,height,scale,n)
 local s=makeSelf(n)s.DetailClose.Position=UDim2.new(1,-8,0,8)s.DetailClose.AnchorPoint=vec2(1,0)
 local limits={MinTextSize=1,MaxTextSize=100}
 s.DetailNameTextLimit=setmetatable({},{__index=limits,__newindex=function(_,k,v)limits[k]=v assert(limits.MinTextSize<=limits.MaxTextSize,'text size constraint endpoints reversed')end})
 local refs={s.Detail,s.DetailName,s.DetailArtFrame,s.DetailActions,s._activeActionButtons[1],s.Grid.CanvasPosition}
 InventoryUI.ApplyResponsive(s,vec2(width,height),true,scale)
 return s,refs
end
local function verify(s,refs,scale,expectColumns)
 local w=s.Window.Size.X.Offset-24 local h=s.Detail.Size.Y.Offset
 local mode=s.Root:GetAttribute('InventoryCompactDetailLayout')
 check(mode==(expectColumns and 'TallHeroColumnsV1' or 'TallHeroPortraitV1'),'tall selected detail must use a balanced hero layout')
 local regions={s.DetailArtFrame,s.DetailRarity,s.DetailName,s.DetailDescription,s.DetailActions,s.DetailClose}
 for i,n in ipairs(regions)do
  local r=box(n,w,h)check(inside(r,w,h),'tall content outside actual drawer')
  for j=i+1,#regions do check(not overlap(r,box(regions[j],w,h)),'tall content overlap')end
 end
 local art=box(s.DetailArtFrame,w,h)local description=box(s.DetailDescription,w,h)local actions=box(s.DetailActions,w,h)
 check(near(art.w,art.h),'hero not square')
 check(art.w*scale>=(expectColumns and 200 or 160) and art.w*scale<=280,'hero remains too small or excessive')
 check(near(s.Root:GetAttribute('InventoryDetailHeroSize'),art.w*scale),'hero metadata differs from actual producer')
 check(near(description.h*scale,64)and s.DetailDescription.Visible,'summary must be concise and visible')
 check(s.DetailDescription.BackgroundTransparency==1 and s.DetailDescriptionStroke.Transparency==1,'giant hollow field styling retained')
 check(near((actions.y-description.y-description.h)*scale,12),'actions detached from decision information')
 check(s.DetailName.TextSize*scale>=16 and s.DetailNameTextLimit.MinTextSize*scale>=16,'title hierarchy too small')
 check(s.DetailRarity.TextSize*scale>=12 and s.DetailDescription.TextSize*scale>=12,'information floor reduced')
 check(s.DetailActionLayout.CellSize.X.Offset*scale>=44 and s.DetailActionLayout.CellSize.Y.Offset*scale>=44,'action smaller than44')
 local gridWidth=s.DetailActionLayout.CellSize.X.Offset*s.DetailActionLayout.FillDirectionMaxCells+(s.DetailActionLayout.FillDirectionMaxCells-1)*s.DetailActionLayout.CellPadding.X.Offset
 check(gridWidth<=actions.w+.01,'action cells overflow their group')
 check(s.Detail==refs[1]and s.DetailName==refs[2]and s.DetailArtFrame==refs[3]and s.DetailActions==refs[4]and s._activeActionButtons[1]==refs[5]and s.Grid.CanvasPosition==refs[6]and s._selectedKey=='pet:1'and s._search=='cat','native identity or selected state replaced')
end
for _,width in ipairs({520,600,637,899})do for _,height in ipairs({520,654,801})do for _,scale in ipairs({.8,1,1.2})do for _,n in ipairs({1,4})do
 local s,refs=selected(width-24,height-24,scale,n)verify(s,refs,scale,true)
 if width==637 then check(s.DetailArtFrame.Size.X.Offset*scale>=240 and s.DetailArtFrame.Size.X.Offset*scale<=280,'recorded637 hero must be240 to280')end
 InventoryUI.ApplyResponsive(s,vec2(width-24,height-24),true,scale)verify(s,refs,scale,true)
 -- The same objects return to the established short layout, then wide pane.
 InventoryUI.ApplyResponsive(s,vec2(716,296),true,scale)
 check(not s._layout.tallDetail and near(s.DetailArtFrame.Size.X.Offset*scale,96),'short landscape art changed')
 check(s.DetailDescription.BackgroundTransparency==.12 and s.DetailDescriptionStroke.Transparency==.28,'short description style was not restored')
 InventoryUI.ApplyResponsive(s,vec2(1280,800),false,1)
 check(not s._layout.tallDetail and s.DetailInternalName.Visible,'wide pane not restored')
 check(s.DetailDescription.BackgroundTransparency==.12 and s.DetailDescriptionStroke.Transparency==.28,'wide description style was not restored')
end end end end
for _,viewport in ipairs({{336,660},{366,736},{400,800}})do for _,scale in ipairs({.8,1,1.2})do for _,n in ipairs({1,4})do
 local s,refs=selected(viewport[1],viewport[2],scale,n)verify(s,refs,scale,false)
end end end
-- At a collapsed/short drawer, do not pretend there is room for a hero layout.
for _,viewport in ipairs({{716,260},{716,296},{876,466},{296,400}})do
 local s=selected(viewport[1],viewport[2],1,4)check(not s._layout.tallDetail,'short drawer incorrectly entered tall mode')
end
print('TALL_DETAIL_GEOMETRY_PASS='..count)
`;
const geometryProgram=harness(source)+geometry;
const restorationProgram=harness(source)+'\n'+responsive(old).replace('function InventoryUI:ApplyResponsive(', 'function InventoryUI:ApplyOriginalResponsive(')+String.raw`
local paths={'DetailArtFrame','DetailRarity','DetailName','DetailDescription','DetailActions','Detail','GridPane','CategoryBar'}
for _,size in ipairs({{716,260},{716,296},{876,466},{1280,800},{1600,900}})do for _,scale in ipairs({.8,1,1.2})do for _,actions in ipairs({1,4})do
 local current,before=makeSelf(actions),makeSelf(actions)
 InventoryUI.ApplyResponsive(current,vec2(613,630),true,scale)
 InventoryUI.ApplyResponsive(current,vec2(size[1],size[2]),size[2]<520,scale)
 InventoryUI.ApplyOriginalResponsive(before,vec2(size[1],size[2]),size[2]<520,scale)
 for _,name in ipairs(paths)do for _,property in ipairs({'Position','Size'})do for _,axis in ipairs({'X','Y'})do for _,unit in ipairs({'Scale','Offset'})do
  check(near(current[name][property][axis][unit],before[name][property][axis][unit]),'short/wide authored geometry changed: '..name)
 end end end end
 check(current.DetailDescription.Visible==before.DetailDescription.Visible and current.DetailStats.Visible==before.DetailStats.Visible,'short/wide visibility changed')
 check(current.DetailDescription.BackgroundTransparency==.12 and current.DetailDescriptionStroke.Transparency==.28,'short/wide style restoration failed')
end end end
print('TALL_DETAIL_RESTORATION_PASS='..count)
`;

const previewContract=read('work/automation/scripts/inventory-model-preview-contract.mjs');
const previewMocks=between(previewContract,'let code=String.raw`',"`+block('function InventoryUI:_getPetPreviewMaster(',").slice('let code=String.raw`'.length);
const cameraChecks=String.raw`
local fitCalls=0
local function scene(w,h,d,angle,viewportWidth,viewportHeight)
 local a=math.rad(angle)local cf=frame(vec(4,-2,7),vec(math.cos(a),0,-math.sin(a)),vec(0,1,0),vec(math.sin(a),0,math.cos(a)))
 local size=vec(w,h,d)local m={}
 function m:GetBoundingBox()fitCalls+=1 return cf,size end
 local p=preview()p.viewport.AbsoluteSize={X=viewportWidth,Y=viewportHeight}
 function p.world:FindFirstChildWhichIsA(kind)assert(kind=='Model')return self.current end p.world.current=m
 p.camera.CFrame=CFrame.lookAt(cf.Position+vec(4,2,6),cf.Position)
 local original=p.camera.CFrame
 local s=setmetatable({DetailPetPreview=p,_layout={tallDetail=true}},{__index=InventoryUI})
 s:_refitDetailPreview()
 local function verify()
  local tanY=math.tan(math.rad(p.camera.FieldOfView*.5))local tanX=tanY*p.viewport.AbsoluteSize.X/p.viewport.AbsoluteSize.Y
  for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
   local point=p.camera.CFrame:PointToObjectSpace(cf:PointToWorldSpace(vec(w*x,h*y,d*z)*.5))local depth=-point.Z
   check(depth>0,'preview corner behind camera')
   check(math.abs(point.X)/(depth*tanX)<=1/1.12+.0001 and math.abs(point.Y)/(depth*tanY)<=1/1.12+.0001,'actual eight-corner fit clipped model')
  end end end
  check((p.camera.CFrame.Position-cf.Position).Unit:Dot((original.Position-cf.Position).Unit)>.99999,'preview front direction changed')
  check(p.viewport.attrs.PreviewFitMode=='TallDetailEightCornersV1'and p.viewport.attrs.PreviewFitWidth==p.viewport.AbsoluteSize.X and p.viewport.attrs.PreviewFitHeight==p.viewport.AbsoluteSize.Y,'fit metadata does not match rendered stage')
 end
 verify()
 local firstCalls=fitCalls local fitted=p.camera.CFrame
 for i=1,10 do s:_refitDetailPreview()end
 check(fitCalls==firstCalls and p.camera.CFrame==fitted and p.world.current==m,'unchanged detail refit or cloned repeatedly')
 p.viewport.AbsoluteSize={X=math.max(24,viewportWidth*.5),Y=viewportHeight*1.25}s:_refitDetailPreview()verify()
 check(fitCalls==firstCalls+1 and p.world.current==m,'resize must refit exactly once without replacing the model')
 s._layout.tallDetail=false s:_refitDetailPreview()
 check(p.camera.CFrame==original and p.detailFitModel==nil and p.detailFitSize==nil and p.viewport.attrs.PreviewFitMode=='Original','original camera was not restored')
 s._layout.tallDetail=true s:_refitDetailPreview()verify()
 local replacement={}function replacement:GetBoundingBox()return cf,size end p.world.current=replacement
 local replacementBase=CFrame.lookAt(cf.Position+vec(-5,1,3),cf.Position)p.camera.CFrame=replacementBase s:_refitDetailPreview()
 check(p.detailFitModel==replacement and p.detailBaseCamera==replacementBase,'new model reused stale base camera')
 s._layout.tallDetail=false s:_refitDetailPreview()check(p.camera.CFrame==replacementBase,'new model restore uses old item camera')
 p.world.current=nil s._layout.tallDetail=true s:_refitDetailPreview()
 check(p.detailFitModel==nil and p.detailBaseCamera==nil and p.detailFitSize==nil and p.viewport.attrs.PreviewFitMode=='Unavailable','removed model retained stale fit state')
 p.world.current=m p.viewport.AbsoluteSize={X=0,Y=0}local before=fitCalls s:_refitDetailPreview()check(fitCalls==before,'zero viewport attempted fitting')
end
for _,shape in ipairs({{1.5,1.8,1.1},{2.1,2.8,1.8},{8,2,3},{2,9,4}})do for _,angle in ipairs({0,35,90,175})do for _,viewport in ipairs({{252,252},{160,160},{140,280},{360,160}})do scene(shape[1],shape[2],shape[3],angle,viewport[1],viewport[2])end end end
print('TALL_DETAIL_REFIT_PASS='..count)
`;
const cameraProgram=previewMocks+refit+cameraChecks;
const flowPath='work/automation/flows/narrow-desktop-menu-real-input.json';
const flow=JSON.parse(read(flowPath));
const oldFlowResult=spawnSync('git',['show','63eeb8f:'+flowPath],{cwd:root,encoding:'utf8'});assert.equal(oldFlowResult.status,0,oldFlowResult.stderr);const oldFlow=JSON.parse(oldFlowResult.stdout);
const label='verify selected fist and pet detail lanes at explicit narrow desktop';
function verifyFlow(candidate){
 const copy=structuredClone(candidate),step=copy.steps.find(s=>s.label===label);
 assert(step.args.code.includes('projected<=.9')&&step.args.code.includes("'TallDetailEightCornersV1'")&&step.args.code.includes('art.AbsoluteSize.X>=240')&&step.args.code.includes('decisionGap>=11 and decisionGap<=13')&&step.args.code.includes('summary.BackgroundTransparency==1'),'real hero/projection/summary/action gates missing');
 assert(step.args.code.includes("==previewModel,'repeat selection rebuilt the tall detail model'"),'native model identity check missing');
 step.args.code=step.args.code.replace(/-- BEGIN TALL DETAIL VISUAL GATES[\s\S]*?-- END TALL DETAIL VISUAL GATES\n /,'').replace(/\n assert\(liveDetail\.DetailArtFrame\.DetailPetPreview[^\n]+repeat selection rebuilt the tall detail model'\)/,'').replace('return {tallHero=true,previewCorners=true,previewIdentity=true,category=category','return {category=category');
 assert.deepEqual(copy,oldFlow,'previous fixture, routes, names, targets, safe areas, identity or cleanup gates changed');
}
verifyFlow(flow);
const luau=[process.env.LUAU_COMMAND,...fs.readdirSync(os.tmpdir()).filter(n=>n.startsWith('codex-luau-')).sort().reverse().map(n=>path.join(os.tmpdir(),n,'luau.exe'))].find(p=>p&&fs.existsSync(p));assert(luau);
const compiler=process.env.LUAU_COMPILE_COMMAND||path.join(path.dirname(luau),'luau-compile.exe');
const temp=fs.mkdtempSync(path.join(os.tmpdir(),'smash-tall-detail-'));let compiled=0;const mutations=[];
function run(name,code,expected){const p=path.join(temp,name+'.luau');fs.writeFileSync(p,code);const c=spawnSync(compiler,['--null',p],{encoding:'utf8'});assert.equal(c.status,0,c.stderr);compiled++;const r=spawnSync(luau,[p],{encoding:'utf8',timeout:10000});if(expected)assert(r.status!==0&&(r.stdout+r.stderr).includes(expected),name+': '+r.stdout+r.stderr);else assert.equal(r.status,0,r.stdout+r.stderr);return r.stdout;}
try{
 const geometryOutput=run('actual-responsive',geometryProgram),cameraOutput=run('actual-camera-refit',cameraProgram),restorationOutput=run('exact-short-wide-restoration',restorationProgram);
 run('historical-hollow-drawer',harness(old)+geometry,'tall selected detail must use a balanced hero layout');mutations.push('historical_63e_hollow_drawer');
 const variants=[
  ['tiny_hero',geometryProgram,'math.min(280, physicalWidth * 0.44, physicalHeight - 72)','96','hero remains too small'],
  ['detached_actions',geometryProgram,'(infoY + 152) / scale','(infoY + 180) / scale','actions detached'],
  ['giant_summary',geometryProgram,'infoWidth / scale, 64 / scale','infoWidth / scale, 200 / scale','tall content overlap'],
  ['close_lane_overlap',geometryProgram,'math.max(60, (physicalHeight - groupHeight) * 0.5)','0','tall content overlap'],
  ['tiny_title',geometryProgram,'infoWidth >= 220 and 18 or 16','12','title hierarchy too small'],
  ['style_not_restored',geometryProgram,'self.DetailDescription.BackgroundTransparency = 0.12','self.DetailDescription.BackgroundTransparency = 1','short description style was not restored'],
  ['title_constraint_order',geometryProgram,'self.DetailNameTextLimit.MinTextSize = 1\n\t\t\tself.DetailNameTextLimit.MaxTextSize = titleSize','self.DetailNameTextLimit.MinTextSize = titleSize\n\t\t\tself.DetailNameTextLimit.MaxTextSize = titleSize','text size constraint endpoints reversed'],
  ['repeat_refit',cameraProgram,'if preview.detailFitModel == model and preview.detailFitSize == size then return end','if false then return end','unchanged detail refit'],
  ['ignore_resize',cameraProgram,'preview.detailFitModel == model and preview.detailFitSize == size','preview.detailFitModel == model','actual eight-corner fit clipped model'],
  ['ignore_horizontal_fov',cameraProgram,'local tanX = tanY * size.X / size.Y','local tanX = tanY','actual eight-corner fit clipped model'],
  ['ignore_box_rotation',cameraProgram,'bounds:PointToWorldSpace(Vector3.new(boundsSize.X * x, boundsSize.Y * y, boundsSize.Z * z) * 0.5)','center + Vector3.new(boundsSize.X * x, boundsSize.Y * y, boundsSize.Z * z) * 0.5','actual eight-corner fit clipped model'],
  ['camera_not_restored',cameraProgram,'preview.camera.CFrame = preview.detailBaseCamera','preview.camera.CFrame = preview.camera.CFrame','original camera was not restored'],
 ];
 for(const [name,program,from,to,error]of variants){assert(program.includes(from),name);run(name,program.replace(from,to),error);mutations.push(name);}
 for(const [name,from,to]of [['native_projection','projected<=.9','true'],['native_hero','art.AbsoluteSize.X>=240','true'],['native_identity',"==previewModel,'repeat selection rebuilt the tall detail model'","~=nil,'repeat selection rebuilt the tall detail model'"]]){
  const candidate=JSON.parse(JSON.stringify(flow).replace(from,to));assert.throws(()=>verifyFlow(candidate));mutations.push(name);
 }
 for(const [i,step]of [...flow.steps,...flow.cleanup].entries())if(step.args?.code){const file=path.join(temp,'flow-'+i+'.luau');fs.writeFileSync(file,step.args.code);const c=spawnSync(compiler,['--null',file],{encoding:'utf8'});assert.equal(c.status,0,c.stderr);compiled++;}
 for(const opt of ['-O0','-O1','-O2']){const r=spawnSync(compiler,[opt,'--null',path.join(root,sourcePath)],{encoding:'utf8'});assert.equal(r.status,0,r.stderr);compiled++;}
 console.log(JSON.stringify({ok:true,geometryOutput,cameraOutput,restorationOutput,mutations,compiled,actualProducer:true,nativeTextFitsAndVisualApproval:'pending'},null,2));
}finally{assert.equal(path.dirname(fs.realpathSync(temp)),fs.realpathSync(os.tmpdir()));fs.rmSync(temp,{recursive:true,force:true});}
