import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import assert from 'node:assert/strict';
import cp from 'node:child_process';
const root=process.cwd(),clientPath='work/punch-wall-rpg/src/client/PunchWallClient.client.lua';
const source=fs.readFileSync(path.join(root,clientPath),'utf8').replace(/\r/g,'');
const baselineRef=process.argv.includes('--baseline')?process.argv[process.argv.indexOf('--baseline')+1]:'1529b7d';
const baseline=cp.execFileSync('git',['show',baselineRef+':'+clientPath],{cwd:root,encoding:'utf8'}).replace(/\r/g,'');
const directories=[...String(process.env.PATH||'').split(path.delimiter),...fs.readdirSync(os.tmpdir(),{withFileTypes:true}).filter(x=>x.isDirectory()&&/^codex-luau-/.test(x.name)).map(x=>path.join(os.tmpdir(),x.name))];
const luau=process.env.LUAU_COMMAND||directories.map(d=>path.join(d,process.platform==='win32'?'luau.exe':'luau')).find(fs.existsSync);
assert(luau,'Luau runtime missing; set LUAU_COMMAND');
const compiler=path.join(path.dirname(luau),process.platform==='win32'?'luau-compile.exe':'luau-compile');
const scratch=fs.mkdtempSync(path.join(os.tmpdir(),'smash-narrow-direction-'));
let runCount=0,compiledChunks=0;
function execute(program){const file=path.join(scratch,'case-'+(++runCount)+'.luau');fs.writeFileSync(file,program);const result=cp.spawnSync(luau,[file],{encoding:'utf8'});return {ok:result.status===0,text:result.stdout+result.stderr};}
function pass(program,label){const result=execute(program);assert(result.ok,label+'\n'+result.text);return result;}
function between(s,start,end,from=0){const a=s.indexOf(start,from),b=s.indexOf(end,a+start.length);assert(a>=0&&b>a,start);return s.slice(a,b);}
function pieces(s){return {
 helpers:between(s,'local function designRect(','local rankWidgets'),
 min:between(s,'local function enforceReferenceTouchTarget','local function setPhoneOpticalScale'),
 apply:between(s,'\t\tpunchUpButton.AnchorPoint = Vector2.zero','\t\treferenceHUD:SetAttribute("RightMenuResponsiveProfile"',s.indexOf('applyResponsiveLayout = function()')),
};}
const fixed=pieces(source),old=pieces(baseline);
assert.equal(between(source,'\t\tpunchUpButton.AnchorPoint = Vector2.new(1, 1)','\t\t-- Phone information hierarchy'),between(baseline,'\t\tpunchUpButton.AnchorPoint = Vector2.new(1, 1)','\t\t-- Phone information hierarchy'),'existing compact directional geometry changed');
const mock=String.raw`
local shared={}
local Vector2={zero={X=0,Y=0},new=function(x,y)return {X=x,Y=y}end}
local UDim2={}
function UDim2.new(xs,xo,ys,yo)return {X={Scale=xs,Offset=xo},Y={Scale=ys,Offset=yo}}end
function UDim2.fromScale(x,y)return UDim2.new(x,0,y,0)end
function UDim2.fromOffset(x,y)return UDim2.new(0,x,0,y)end
local Instance={}
function Instance.new(class)
 local value={ClassName=class}
 return setmetatable(value,{__newindex=function(t,k,v)rawset(t,k,v) if k=='Parent'then v.children[t.Name]=t end end})
end
local function button()
 local value={children={},attrs={}}
 function value:FindFirstChild(k)return self.children[k]end
 function value:SetAttribute(k,v)self.attrs[k]=v end
 return value
end
local function render(b,viewport)
 local c=b.children.MinimumTouchTarget
 return {x=b.Position.X.Scale*viewport.X+b.Position.X.Offset,y=b.Position.Y.Scale*viewport.Y+b.Position.Y.Offset,
 w=math.max(c.MinSize.X,b.Size.X.Scale*viewport.X+b.Size.X.Offset),h=math.max(c.MinSize.Y,b.Size.Y.Scale*viewport.Y+b.Size.Y.Offset)}
end
local checks=0
local function check(v,m)assert(v,m)checks+=1 end
`;
const geometryTests=String.raw`
for _,w in ipairs({240,320,390,520,600,636,637,640,680,720,768,800,816,817,850,880,891,892,900,1024,1277,1366,1672,1920})do
 for _,h in ipairs({520,654,780,941})do
  local a,b=layout(w,h)
  check(a.w>=44 and a.h>=44 and b.w>=44 and b.h>=44,'minimum44 preserved')
  check(b.x-(a.x+a.w)>=3.99999,'pair gap below4 at'..w)
  check(a.x>=0 and b.x+b.w<=w and a.y>=0 and a.y+a.h<=h,'pair escaped viewport')
  if w>=900 then
   check(math.abs(a.x-w*1190/1672)<.00001 and math.abs(b.x-w*1280/1672)<.00001,'normal desktop positions changed')
   check(math.abs(a.y-h*590/941)<.00001,'normal desktop Y changed')
  end
 end
end
local a,b=layout(637,654)
check(math.abs((a.x+b.x+b.w)*.5-637*1273/1672)<.00001,'recorded pair center moved')
check(math.abs(b.x-(a.x+a.w)-4)<.00001,'recorded gap must be4')
print('PASS '..checks..' actual desktop producer assertions')
`;
function program(p,tests=geometryTests){return mock+p.helpers+'\n'+p.min+String.raw`
local function layout(w,h)
 local viewport={X=w,Y=h}
 local punchUpButton,punchDownButton=button(),button()
 enforceReferenceTouchTarget(punchUpButton) enforceReferenceTouchTarget(punchDownButton)
`+p.apply+String.raw`
 return render(punchUpButton,viewport),render(punchDownButton,viewport)
end
`+tests;}
const geometryRun=pass(program(fixed),'production layout');
const before=execute(program(old,"local a,b=layout(637,654) assert(b.x>=a.x+a.w,'recorded637 desktop pair overlaps')"));
assert(!before.ok&&before.text.includes('recorded637 desktop pair overlaps'),'baseline must fail for actual narrow overlap');
const mutations=[
 ['drop-gap',p=>({...p,helpers:p.helpers.replace('downX = left + width + 4','downX = left + width')})],
 ['skip-narrow-publication',p=>({...p,apply:p.apply.replace('if narrowPair then','if false then')})],
 ['drop-touch-minimum',p=>({...p,helpers:p.helpers.replace('math.max(44, viewport.X * 76 / 1672)','viewport.X * 76 / 1672'),min:p.min.replace('Vector2.new(44, 44)','Vector2.new(0, 0)')})],
 ['move-pair-offscreen',p=>({...p,helpers:p.helpers.replace('upX = left, downX = left + width + 4','upX = -20, downX = -20 + width + 4')})],
];
for(const [name,mutate]of mutations){const p=mutate(fixed);assert.notDeepEqual(p,fixed);pass('assert(loadstring('+JSON.stringify(program(p))+'))',name+' must compile');assert(!execute(program(p)).ok,name+' survived');}
const legacy=JSON.parse(fs.readFileSync(path.join(root,'work/automation/flows/directional-punch-controls.json'),'utf8'));
const narrow=JSON.parse(fs.readFileSync(path.join(root,'work/automation/flows/narrow-directional-controls.json'),'utf8'));
const oracle=legacy.steps.find(s=>s.label==='direction controls and action layout').args.code;
const oldOracle=JSON.parse(cp.execFileSync('git',['show',baselineRef+':work/automation/flows/directional-punch-controls.json'],{cwd:root,encoding:'utf8'})).steps.find(s=>s.label==='direction controls and action layout').args.code;
const oracleMocks=String.raw`
local attrs={CharacterPunchCount=2}
local H={JSONEncode=function(_,v)return v end}
local U={TouchEnabled=true}
local g={Enabled=true}
local h={Visible=true,Parent=g,AbsolutePosition={X=0,Y=0},AbsoluteSize={X=740,Y=339},children={}}
function g:GetAttribute(k)return attrs[k]end
function h:IsA(c)return c=='GuiObject'end
function h:FindFirstChild(k)return self.children[k]end
local function node(x,y,w,z)
 local n={Visible=true,Active=true,Parent=h,AbsolutePosition={X=x,Y=y},AbsoluteSize={X=w,Y=z},attrs={}}
 function n:IsA(c)return c=='GuiObject'end
 function n:GetAttribute(k)return self.attrs[k]end
 return n
end
local up=node(472,225,44,44) up.attrs.PunchDirection='Up'
local down=node(520,225,44,44) down.attrs.PunchDirection='Down'
local nextCard=node(451.435394,222.278442,69.889481,52.236981) nextCard.Visible=false nextCard.Active=false
h.children={PunchUp=up,PunchDown=down,NextWorldCard=nextCard}
g.PixelPerfectHeroCityHUD=h
local p={PlayerGui={PunchWallHUD=g}}
local game={Players={LocalPlayer=p}}
function game:GetService(n)if n=='HttpService'then return H elseif n=='UserInputService'then return U end error(n)end
local workspace={CurrentCamera={ViewportSize={X=740,Y=339}}}
`;
const oracleCases=[
 ['hidden-next-only','',true],
 ['visible-next-obstruction','nextCard.Visible=true',false],
 ['actual-direction-overlap','down.AbsolutePosition.X=480',false],
 ['disabled-up','up.Active=false',false],
 ['hidden-up','up.Visible=false',false],
 ['hidden-parent','h.Visible=false',false],
 ['screen-disabled','g.Enabled=false',false],
 ['insufficient-motion','attrs.CharacterPunchCount=1',false],
 ['missing-down','h.children.PunchDown=nil',false],
 ['clear-visible-next','nextCard.Visible=true nextCard.AbsolutePosition={X=0,Y=0}',true],
];
for(const [name,setup,expected]of oracleCases){
 pass(oracleMocks+'\n'+setup+'\nlocal r=(function()\n'+oracle+'\nend)()\nassert(r.ok=='+expected+','+JSON.stringify(name)+')',name);
}
pass(oracleMocks+'\nlocal r=(function()\n'+oldOracle+'\nend)()\nassert(r.ok==false,"baseline incorrectly accepted hidden-card scene")','old hidden-card failure control');
const phoneAudit=narrow.steps.find(s=>s.label==='Phone: actual stable target bounds').args.code;
const phoneOracle=phoneAudit.slice(phoneAudit.indexOf("local H=game:GetService('HttpService')"));
for(const [name,setup,expected]of [
 ['actual-phone-safe-area','',true],
 ['tiny-viewport-rejected','h.AbsoluteSize={X=1,Y=1} workspace.CurrentCamera.ViewportSize={X=1,Y=1}',false],
 ['wrong-device-input','U.TouchEnabled=false',false],
 ['camera-hud-mismatch','workspace.CurrentCamera.ViewportSize={X=637,Y=654}',false],
 ['short-touch-target','up.AbsoluteSize.X=43',false],
 ['under-four-gap','down.AbsolutePosition.X=519',false],
 ['offscreen-target','down.AbsolutePosition.X=720',false],
]){
 pass(oracleMocks+'\n'+setup+'\nlocal r=(function()\n'+phoneOracle+'\nend)()\nassert(r.ok=='+expected+','+JSON.stringify(name)+')',name);
}
const weakened=oracle.replace('(not n.effectiveVisible or (not upNext and not downNext))','true');
assert.notEqual(weakened,oracle);
pass('assert(loadstring('+JSON.stringify(weakened)+'))','weakened visible oracle compilation');
assert(!execute(oracleMocks+'\nnextCard.Visible=true\nlocal r=(function()\n'+weakened+'\nend)()\nassert(r.ok==false,"visible obstruction ignored")').ok,'oracle weakening survived');
for(const f of [legacy,narrow]){
 for(const s of [...f.steps,...(f.cleanup||[])]){
  if(s.args?.code){pass('assert(loadstring('+JSON.stringify(s.args.code)+'))',f.name+' '+s.label+' compile');compiledChunks++;}
 }
 for(const s of f.steps.filter(s=>s.type==='assertNoConsoleErrors')){
  assert(s.patterns.includes('Something unexpectedly tried to set the parent of PlayEmote'),'native arrival warning is not gated');
  for(const required of ['Stack Begin','Stack End','Infinite yield','Error:'])assert(s.patterns.includes(required));
 }
}
const clicks=narrow.steps.filter(s=>s.tool==='user_mouse_input');
assert.equal(clicks.length,4,'exact one Up/Down native gesture per device');
assert(narrow.steps.filter(s=>s.label.includes('exact')&&s.label.includes('server direction')).length===4);
for(const s of clicks){assert.equal(s.args.actions.filter(a=>a.action==='mouseButtonDown').length,1);assert.equal(s.args.actions.filter(a=>a.action==='mouseButtonUp').length,1);}
for(const s of narrow.steps.filter(s=>s.label.includes('actual stable target bounds'))){
 assert(s.args.code.includes('awaitStableDirections()')&&s.args.code.includes('os.clock()+5'));
 assert(s.args.code.includes('result.viewportValid')&&s.args.code.includes('result.touchSafe')&&s.args.code.includes('result.contained')&&s.args.code.includes('gap>=3.999'));
}
assert(narrow.steps.at(-1).args.code.includes("assert(S:GetDeviceAsync()=='default'"));
assert(!JSON.stringify(narrow).includes("Invoke('Punch'"),'new flow bypasses native directional input');
for(const level of [0,1,2]){const r=cp.spawnSync(compiler,['--null','-O'+level,path.join(root,clientPath)],{encoding:'utf8'});assert.equal(r.status,0,r.stdout+r.stderr);}
console.log(JSON.stringify({ok:true,baseline:baselineRef,sourceGeometryAssertions:Number(geometryRun.text.match(/PASS (\d+)/)[1]),oracleControls:oracleCases.length+7,semanticMutations:mutations.length+1,compiledFlowChunks:compiledChunks,clientCompile:['O0','O1','O2'],runtime:'Coordinator pending; no Studio calls'},null,2));
