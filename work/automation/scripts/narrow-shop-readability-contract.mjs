import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import cp from 'node:child_process';
import assert from 'node:assert/strict';
const root=process.cwd(), clientPath='work/punch-wall-rpg/src/client/PunchWallClient.client.lua';
const source=fs.readFileSync(path.join(root,clientPath),'utf8').replace(/\r/g,'');
const arg=process.argv.indexOf('--baseline');
const baselineRef=arg>=0?process.argv[arg+1]:'361d13b';
const baseline=cp.execFileSync('git',['show',baselineRef+':'+clientPath],{cwd:root,encoding:'utf8'}).replace(/\r/g,'');
const dirs=[...String(process.env.PATH||'').split(path.delimiter),...fs.readdirSync(os.tmpdir(),{withFileTypes:true}).filter(x=>x.isDirectory()&&/^codex-luau-/.test(x.name)).map(x=>path.join(os.tmpdir(),x.name))];
const luau=process.env.LUAU_COMMAND||dirs.map(d=>path.join(d,process.platform==='win32'?'luau.exe':'luau')).find(fs.existsSync);
assert(luau,'Set LUAU_COMMAND to the Luau executable');
const compiler=path.join(path.dirname(luau),process.platform==='win32'?'luau-compile.exe':'luau-compile');
const scratch=fs.mkdtempSync(path.join(os.tmpdir(),'smash-narrow-shop-'));
let cases=0,compiled=0;
function between(s,a,b,from=0){const x=s.indexOf(a,from),y=s.indexOf(b,x+a.length);assert(x>=0&&y>x,a);return s.slice(x,y);}
function parts(s){
 const build=s.indexOf('shared.PunchWallBuildShopUI = function()');
 return {
 classifier:between(s,'shared.PunchWallClassifyResponsiveViewport =','shared.PunchWallGetResponsiveViewport ='),
 resolve:s.includes('shared.PunchWallResolveShopLayout =')?between(s,'shared.PunchWallResolveShopLayout =','-- Functional Hero City shop'): '',
 compactModal:between(s,'\t\telseif shopOpen then','\t\telse',s.indexOf('applyResponsiveLayout = function()')).replace(/^\s*elseif shopOpen then/,''),
 modal:between(s,'\t\telseif shopOpen then','\t\telse',s.indexOf('"CenteredReference1.50"')).replace(/^\s*elseif shopOpen then/,''),
 label:between(s,'\t\tlocal function label(','\t\tlocal function bindButtonMotion',build),
 catalog:between(s,'\t\tlocal compactCards =','\t\tlocal compactProductNames =',build),
 card:between(s,'\t\t\tlocal column = (index - 1)','\t\t\tlocal equippedCard =',build),
 name:between(s,'\t\t\tlocal textX =','\t\t\tlocal requiredDepth =',build),
 detail:between(s,'\t\t\tlocal detailText =','\t\t\tlocal priceX =',build),
 price:between(s,'\t\t\tlocal priceLabel =','\t\t\tif purchaseUnavailable then',s.indexOf('local priceColor =',build)),
 action:between(s,'\t\t\tlocal actionShadow =','\t\t\tif page == "Boosts" then',build),
 phone:between(s,'\t\t\tif compactCards then\n\t\t\t\t-- One readable offer','\t\t\tlocal actionSize =',build),
 };
}
const mock=String.raw`
local shared={}
local UserInputService={TouchEnabled=false}
local typeof=function(x)return type(x)=='table' and x.X and x.Y and 'Vector2' or type(x)end
local Vector2={new=function(x,y)return {X=x,Y=y}end,zero={X=0,Y=0}}
local UDim2={}
function UDim2.new(xs,xo,ys,yo)return {X={Scale=xs,Offset=xo},Y={Scale=ys,Offset=yo}}end
function UDim2.fromOffset(x,y)return UDim2.new(0,x,0,y)end
function UDim2.fromScale(x,y)return UDim2.new(x,0,y,0)end
local enum function enum()return setmetatable({},{__index=function(t,k)local v=enum()rawset(t,k,v)return v end})end
local Enum=enum()
local Color3={} function Color3.fromRGB(...)return {Lerp=function(self)return self end}end
local Instance={}
function Instance.new(class)
 local x={Name=class,ClassName=class,children={},attrs={},AnchorPoint=Vector2.zero,Visible=true,TextScaled=false}
 function x:SetAttribute(k,v)self.attrs[k]=v end
 function x:FindFirstChild(k)for _,v in ipairs(self.children)do if v.Name==k then return v end end end
 function x:FindFirstChildOfClass(k)for _,v in ipairs(self.children)do if v.ClassName==k then return v end end end
 function x:IsA(k)return self.ClassName==k end
 return setmetatable(x,{__newindex=function(t,k,v)rawset(t,k,v)if k=='Parent' then table.insert(v.children,t)end end})
end
local function addCorner()end
local function addStroke()return {}end
local formatNumber=tostring
local function compactStat(n)return tostring(n)end
local PolishConfig={RarityColors={}}
local palette={MutedText=Color3.fromRGB()}
local checks=0 local function check(v,m)assert(v,m)checks+=1 end
local function rect(x,w,h)
 local rw=x.Size.X.Scale*w+x.Size.X.Offset local rh=x.Size.Y.Scale*h+x.Size.Y.Offset
 return {x=x.Position.X.Scale*w+x.Position.X.Offset-x.AnchorPoint.X*rw,y=x.Position.Y.Scale*h+x.Position.Y.Offset-x.AnchorPoint.Y*rh,w=rw,h=rh}
end
local function contains(a,b)return b.x>=a.x-.0001 and b.y>=a.y-.0001 and b.x+b.w<=a.x+a.w+.0001 and b.y+b.h<=a.y+a.h+.0001 end
local function overlap(a,b)return math.min(a.x+a.w,b.x+b.w)>math.max(a.x,b.x)+.0001 and math.min(a.y+a.h,b.y+b.h)>math.max(a.y,b.y)+.0001 end
`;
function program(p,test){return mock+p.classifier+p.resolve+p.label+String.raw`
local function build(w,h,touch,page,scale)
 UserInputService.TouchEnabled=touch
 local clientSettings={uiScale=scale}
 local viewport=Vector2.new(w,h) local shopViewport=viewport
 local mainPanel=Instance.new('Frame')
 local _,isCompact=shared.PunchWallClassifyResponsiveViewport(viewport)
 if isCompact then
`+p.compactModal+'\nelse\n'+p.modal+String.raw`
 end
 local _,compactHeader=shared.PunchWallClassifyResponsiveViewport(viewport)
 local shopLayout=shared.PunchWallResolveShopLayout and shared.PunchWallResolveShopLayout(viewport) or {compactCards=compactHeader,desktopRows=false}
 compactHeader=compactHeader or shopLayout.desktopRows
 local count=page=='Fists' and 16 or page=='Premium' and 3 or page=='Boosts' and 2 or 4
 local products={} for i=1,count do products[i]={}end
 local shopReference=Instance.new('Frame') local previousScrollPosition=Vector2.new(0,163)
`+p.catalog+String.raw`
 local index=1
 local item={name='Crimson Phoenix',displayName='Crimson Phoenix',rarity='PREMIUM COMPANION',isPremiumPet=true,mult=2.8,accent=Color3.fromRGB(),detail='Permanent sidekick  •  +280% Power  •  +20% Luck'}
 local purchaseUnavailable,purchaseLoading,depthLocked=false,false,false
`+p.card+String.raw`
 local compactProductNames={}
`+p.name+p.detail+String.raw`
 local priceX=.7 local priceText='CHECKING PRICE' local priceColor=Color3.fromRGB()
`+p.price+String.raw`
 local actionText='ACTIVE 15:00' local actionColor=Color3.fromRGB() local actionEnabled=true
`+p.action+String.raw`
 local artPlate=Instance.new('Frame') local icon=Instance.new('Frame') local fallback=Instance.new('TextLabel') local priceIcon=Instance.new('TextLabel')
 local petPlate=Instance.new('Frame') petPlate.Name='PremiumPetPreviewPlate' petPlate.Parent=card
 local tierChrome=Instance.new('Frame') tierChrome.Name='HeroGauntletTierChrome' tierChrome.Parent=card
`+p.phone+String.raw`
 local mw,mh=mainPanel.Size.X.Offset,mainPanel.Size.Y.Offset
 local cr=rect(card,mw,mh)
 return {w=mw,h=mh,compact=compactCards,rows=shopLayout.desktopRows,columns=catalogColumns,scroll=catalogScrollable,scrollPosition=cardsHost.CanvasPosition,card=cr,name=rect(productNameLabel,cr.w,cr.h),rarity=rect(rarityLabel,cr.w,cr.h),detail=rect(detail,cr.w,cr.h),price=rect(priceLabel,cr.w,cr.h),action=rect(action,cr.w,cr.h),title=productNameLabel.Text,copy=detail.Text,rarityText=rarityLabel.Text,nameFloor=productNameSize.MinTextSize,raritySize=rarityLabel.TextSize,detailSize=detail.TextSize,priceFloor=priceTextSize.MinTextSize,actionSize=action.TextSize,petSize=petPlate.Size,iconSize=icon.Size}
end
`+test;}
function execute(code){const file=path.join(scratch,'case-'+(++cases)+'.luau');fs.writeFileSync(file,code);const c=cp.spawnSync(compiler,['--null',file],{encoding:'utf8'});assert.equal(c.status,0,'fixture compilation\n'+c.stdout+c.stderr);compiled++;const r=cp.spawnSync(luau,[file],{encoding:'utf8'});return {ok:r.status===0,text:r.stdout+r.stderr};}
function pass(code,name){const r=execute(code);assert(r.ok,name+'\n'+r.text);return r;}
const fixed=parts(source),old=parts(baseline);
const tests=String.raw`
for _,size in ipairs({{520,654},{600,654},{636,654},{637,654},{800,654},{900,900},{1024,768},{1277,780},{1366,768},{1920,1080}})do
 for _,scale in ipairs({.8,1,1.2})do
  for _,page in ipairs({'Fists','Premium','Boosts','Honor','Robux'})do
   local r=build(size[1],size[2],false,page,scale)
   check(r.w<=size[1]-24 and r.h<=size[2]-24,'modal exceeds safe viewport')
   if size[1]<=900 then check(r.rows,'narrow desktop must reflow') end
   if r.rows then
    check(r.columns==1 and r.scroll,'narrow offers must be one scrolling column')
    check(r.card.h==154 and r.card.x>=12 and r.card.x+r.card.w<=r.w,'card geometry')
    check(r.name.w>=200 and r.name.h>=40,'title lost independent full-name allocation')
    check(r.rarity.w>=200 and r.rarity.h>=18,'rarity lost one full line')
    check(r.detail.w>=200 and r.detail.h>=64,'full benefit description lost four lines')
    check(r.title=='CRIMSON PHOENIX' and r.rarityText=='PREMIUM COMPANION' and r.copy=='Permanent sidekick  •  +280% Power  •  +20% Luck','semantic offer was shortened')
    check(r.nameFloor>=14 and r.raritySize>=12 and r.detailSize>=12 and r.priceFloor>=14 and r.actionSize>=14,'font floor')
    local cr={x=0,y=0,w=r.card.w,h=r.card.h}
    for _,v in ipairs({r.name,r.rarity,r.detail,r.price,r.action})do check(contains(cr,v),'text/action outside card')end
    check(not overlap(r.name,r.rarity) and not overlap(r.rarity,r.detail) and not overlap(r.detail,r.action) and not overlap(r.name,r.price),'copy/action overlap')
    check(r.action.w>=112 and r.action.h>=48,'action target too small')
    check(r.petSize.X.Offset==76 and r.petSize.Y.Offset==76 and r.iconSize.X.Offset==76,'real art viewport resizing missing')
    check(r.scrollPosition.Y==163,'same-page scroll state reset')
   elseif size[1]>=1277 then check(r.columns==2 and not r.compact,'wide desktop grid changed')end
  end
 end
end
for _,size in ipairs({{750,362},{740,339},{390,750},{1024,768}})do
 for _,scale in ipairs({.8,1,1.2})do
  local r=build(size[1],size[2],true,'Premium',scale)
  check(r.compact and not r.rows and r.columns==1 and r.card.h==112,'existing phone/tablet row changed')
  check(r.w==size[1]-24 and r.h==size[2]-24,'existing phone safe fill changed')
  check(r.action.w==112 and r.action.h==48,'existing phone action changed')
 end
end
print('PASS '..checks..' extracted Shop geometry/semantic assertions')
`;
try {
 const result=pass(program(fixed,tests),'new producer');

 const unchanged=String.raw`
for _,v in ipairs({{750,362,true},{740,339,true},{390,750,true},{1024,768,true},{1277,780,false},{1366,768,false},{1920,1080,false}})do
 for _,scale in ipairs({.8,1,1.2})do
  for _,page in ipairs({'Fists','Premium','Boosts','Honor','Robux'})do
   local r=build(v[1],v[2],v[3],page,scale)
   print(r.w,r.h,r.columns,r.card.x,r.card.y,r.card.w,r.card.h,r.name.x,r.name.y,r.name.w,r.name.h,r.detail.w,r.detail.h,r.title,r.copy,r.nameFloor,r.priceFloor,r.action.w,r.action.h)
  end
 end
end
`;
 const unchangedNew=pass(program(fixed,unchanged),'current normal desktop/phone geometry');
 const unchangedOld=pass(program(old,unchanged),'baseline normal desktop/phone geometry');
 assert.equal(unchangedNew.text,unchangedOld.text,'105 existing desktop/phone/page/scale geometries changed');
 const beforeModal=execute(program(old,"local r=build(637,654,false,'Premium',1) assert(r.w<=637-24,'recorded modal exceeded637 safe frame')"));
 assert(!beforeModal.ok&&beforeModal.text.includes('recorded modal exceeded637 safe frame'));
 const beforeCopy=execute(program(old,"local r=build(637,654,false,'Premium',1) assert(r.name.w>=200 and r.rarity.w>=200 and r.detail.h>=64,'recorded full-copy allocation remains compressed')"));
 assert(!beforeCopy.ok&&beforeCopy.text.includes('recorded full-copy allocation remains compressed'));
 const mutations=[
 ['retain-two-columns',p=>({...p,catalog:p.catalog.replace('(compactCards or desktopRows) and 1 or 2','compactCards and 1 or 2')})],
 ['disable-narrow-mode',p=>({...p,resolve:p.resolve.replace('not compact and width < 900','false')})],
 ['omit-copy-reflow',p=>({...p,phone:p.phone.replace('if desktopRows then','if false then')})],
 ['compress-description',p=>({...p,phone:p.phone.replace('UDim2.new(1, -254, 0, 64)','UDim2.new(1, -254, 0, 18)')})],
 ['drop-luck-semantic',p=>({...p,phone:p.phone.replace('detail.Position = UDim2.fromOffset(100, 74)','detail.Text = "+280% Power"\n detail.Position = UDim2.fromOffset(100, 74)')})],
 ['lower-price-font',p=>({...p,phone:p.phone.replace('priceTextSize.MinTextSize = 14','priceTextSize.MinTextSize = 7')})],
 ['reset-scroll',p=>({...p,catalog:p.catalog.replace('catalogScroll.CanvasPosition = previousScrollPosition','catalogScroll.CanvasPosition = Vector2.zero')})],
 ['shrink-action',p=>({...p,phone:p.phone.replace('UDim2.fromOffset(128, 48)','UDim2.fromOffset(128, 30)')})],
 ];
 for(const [name,mutate]of mutations){const mutant=mutate(fixed);assert.notDeepEqual(mutant,fixed,name);assert(!execute(program(mutant,tests)).ok,'mutation survived '+name);}
 // The engine owns TextFits. Keep it as an independent runtime oracle even
 // when TextBounds reports a clipped/substituted run smaller than the box.
 const flow=JSON.parse(fs.readFileSync(path.join(root,'work/automation/flows/hero-shop-reference-polish.json'),'utf8'));
 const textStep=flow.steps.find(s=>s.label==='full semantic typography fits and modal stays inside actual safe viewport');
 assert(textStep&&textStep.expectRegex.some(x=>x.includes('"ok"')));
 assert(textStep.args.code.includes('allTextFits=allTextFits and x.TextFits'));
 assert(!textStep.args.code.includes('assert(result.ok'),'diagnostics must return full failure object');
 const textOracle=between(textStep.args.code,'local allTextFits=true','local chrome=');
 const oracleMock=String.raw`
local x={Name='Name',Parent={Name='Crimson PhoenixShopCard'},Visible=true,TextFits=FIT,Text='CRIMSON PHOENIX',TextBounds={X=74,Y=14},TextSize=17,TextScaled=true,TextWrapped=true}
function x:IsA(k)return k=='TextLabel'end
local s={} function s:GetDescendants()return {x}end
local function rect()return {0,0,121.576,26.884}end
local function shown()return true end
`;
 for(const fit of [true,false])pass(oracleMock.replace('FIT',String(fit))+textOracle+`\nassert(allTextFits==${fit});assert(badCount==${fit?0:1});print('PASS native TextFits fixture')`,'TextFits independent control');
 const weak=textOracle.replace('allTextFits=allTextFits and x.TextFits','allTextFits=true');
 assert(!execute(oracleMock.replace('FIT','false')+weak+"\nassert(allTextFits==false,'clipped native TextFits must fail')").ok,'TextFits weakening survived');

 const matrix=flow.steps.find(s=>s.label==='all five Shop pages retain full text and bounds at three authoritative UI scales');
 assert(matrix&&matrix.args.code.includes("{.8,1,1.2}")&&matrix.args.code.includes("{'Fists','Premium','Boosts','Honor','Robux'}"));
 assert.equal((matrix.args.code.match(/a:Invoke\('SetSettings'/g)||[]).length,1,'one authoritative call site; no retry writes');
 assert(!matrix.args.code.includes('persist=false'));
 const scaleCode=between(matrix.args.code,'local function observeScale','local function inside');
 const scaleMock=String.raw`
local now,calls,mode=0,0,'delayed'
local authority,snapshot=1,1
local H={} function H:JSONDecode(v)return v end
local p={RPGStats={SettingsJSON={Value={uiScale=1}}}}
local a={}
function a:Invoke(command,payload)
 if command=='SetSettings' then calls+=1 return {ok=true,uiScale=payload.uiScale}end
 return {ok=true,uiScale=snapshot}
end
local os={clock=function()return now end}
local task={wait=function(dt)
 now+=dt
 if mode=='delayed' then authority=now>=.2 and .8 or 1 snapshot=now>=.35 and .8 or 1
 elseif mode=='authority-stale' then authority=1 snapshot=.8
 elseif mode=='snapshot-stale' then authority=.8 snapshot=1
 elseif mode=='revert' then authority=now<.15 and .8 or 1 snapshot=authority end
 p.RPGStats.SettingsJSON.Value.uiScale=authority
end}
`;
 const scaleTests=String.raw`
setScale(.8) assert(calls==1 and now>=.65 and now<1,'delayed authority settlement/repeated write')
for _,case in ipairs({'authority-stale','snapshot-stale','revert'})do
 mode=case now=0 calls=0 authority=.8 snapshot=.8 p.RPGStats.SettingsJSON.Value.uiScale=.8
 local ok=pcall(setScale,.8)
 assert(not ok and calls==1 and now>=6,'stale/reverting authority incorrectly accepted: '..case)
end
print('PASS delayed authority, both stale channels, revert, one request per scale')
`;
 pass(scaleMock+scaleCode+scaleTests,'authoritative UI scale observation');
 const noAuthority=scaleCode.replace('and math.abs(authority-value)<.001','');
 assert(!execute(scaleMock+noAuthority+scaleTests).ok,'authoritative scale weakening survived');
 const noStable=scaleCode.replace('now-stable>=.3','now-stable>=0');
 assert(!execute(scaleMock+noStable+scaleTests).ok,'stability weakening survived');
 for(const st of flow.steps){if(st.args?.code){const file=path.join(scratch,'flow-'+(++cases)+'.luau');fs.writeFileSync(file,st.args.code);const r=cp.spawnSync(compiler,['--null',file],{encoding:'utf8'});assert.equal(r.status,0,st.label+'\n'+r.stdout+r.stderr);compiled++;}}
 for(const level of ['-O0','-O1','-O2']){const r=cp.spawnSync(compiler,['--null',level,path.join(root,clientPath)],{encoding:'utf8'});assert.equal(r.status,0,r.stdout+r.stderr);}
 console.log(JSON.stringify({ok:true,production:result.text.trim(),baseline:baselineRef,historicalFailures:2,mutations:mutations.length+3,compiledPrograms:compiled,clientOptimizationLevels:[0,1,2],nativeTypography:'PENDING Coordinator runtime; no mocked TextFits claim'},null,2));
} finally { fs.rmSync(scratch,{recursive:true,force:true}); }
