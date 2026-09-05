#!/usr/bin/env node
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../..');
const sourceIndex=process.argv.indexOf('--source');
const file = sourceIndex>=0 ? path.resolve(process.argv[sourceIndex+1]) : path.join(root, 'work/punch-wall-rpg/src/client/PunchWallClient.client.lua');
const source = fs.readFileSync(file, 'utf8').replace(/\r\n?/g, '\n');
const extract = (start, end) => { const a=source.indexOf(start), b=source.indexOf(end,a+start.length); assert(a>=0&&b>a,`Missing production boundary ${start}`); return source.slice(a,b); };
const helpers = extract('function shared.PunchWallCombatHUD.Resolve(state)', 'function shared.PunchWallCombatHUD.Refresh()');
const number = extract('local function formatNumber(value)', 'for index, key in ipairs(order)');
const scan = extract('local targetTimer = 0','gui:SetAttribute("CombatCameraActive", false)\nif workspace.CurrentCamera');
const checkWiring = () => {
assert(scan.includes('if targetTimer < 0.15 then return end'));
assert(scan.includes('shared.PunchWallCombatHUD.wall = focusedWall and nearestWall or nil'));
assert(scan.includes('shared.PunchWallCombatHUD.Refresh()'));
const missingRoot = scan.slice(scan.indexOf('if not rootPart or not gameRoot then'),scan.indexOf('if (clientRuntime.WallsFolder'));
assert(missingRoot.includes('shared.PunchWallCombatHUD.wall = nil') && missingRoot.includes('shared.PunchWallCombatHUD.boss = nil') && missingRoot.includes('shared.PunchWallCombatHUD.Refresh()'),'missing-character/world does not clear stale target');
assert(!source.includes('local bossHudTimer = 0'),'Duplicate boss heartbeat returned');
assert(!scan.includes('targetHUD.Visible = false'),'Unconditional target hiding returned');
assert(!source.includes('setVisibleIfChanged(bossHUD, false)'),'Reference HUD still suppresses the boss');
assert(source.includes('gui:GetAttributeChangedSignal("ModalCoreGuiHidden"):Connect'));
assert(source.includes('shared.PunchWallCombatHUD.ScheduleLayout(viewport, compact, userScale, referenceHUD'));
};
const dirs = [process.env.PUNCH_WALL_LUAU_TOOL_DIR, path.join(root,'.tools/luau'), ...String(process.env.PATH||'').split(path.delimiter), ...fs.readdirSync(os.tmpdir(),{withFileTypes:true}).filter(e=>e.isDirectory()&&/^codex-luau-/i.test(e.name)).map(e=>path.join(os.tmpdir(),e.name))].filter(Boolean);
const exeName=process.platform==='win32'?'luau.exe':'luau';
const exe=dirs.map(d=>path.join(d,exeName)).find(fs.existsSync);
assert(exe,'BLOCKED: official Luau runtime missing; set PUNCH_WALL_LUAU_TOOL_DIR');
const compiler=path.join(path.dirname(exe),process.platform==='win32'?'luau-compile.exe':'luau-compile');
assert(fs.existsSync(compiler),'BLOCKED: matching Luau compiler missing');
const temp=fs.mkdtempSync(path.join(os.tmpdir(),'smash-combat-hud-contract-'));
const run=(program,name='checks')=>{const p=path.join(temp,`${name}.luau`);fs.writeFileSync(p,program);return spawnSync(exe,[p],{encoding:'utf8'});};
const mocks=String.raw`
local checks=0
local function check(v,m) assert(v,m) checks+=1 end
local shared={PunchWallCombatHUD={renderCount=0,Outline={}}}
local UDim2={fromScale=function(x,y)return tostring(x)..':'..tostring(y)end}
local gui={attrs={}} function gui:SetAttribute(k,v) self.attrs[k]=v end
local targetHUD,bossHUD,targetTitle,bossTitle,targetDetail,bossSubtitle,targetFill,bossFill={},{},{},{},{},{},{},{}
`;
const tests=String.raw`
local R=shared.PunchWallCombatHUD
local function state()
 return {ready=true,blocked=false,now=100,damageBoostExpiresAt=0,power=2,level=1,
 wall={valid=true,broken=false,hp=6,maxHP=8,distance=8,facing=1,title='Forest Stone',name='DepthBlock_L001_C06_R02',canonical='Brick Wall',requiredLevel=1},
 boss={valid=true,broken=false,hp=320000000,maxHP=600000000,distance=40,name='Titan Server Wall',phase=2,nextAttackAt=107}}
end
local s=state() local p=R.Resolve(s)
check(p.kind=='Wall' and p.title=='FOREST STONE' and p.canonical=='Brick Wall','actual title/identity')
check(p.ratio==.75 and p.hits==3 and p.detail=='HP 6/8  |  ~3 hits','actual HP and noncritical hits')
s.damageBoostExpiresAt=101 check(R.Resolve(s).hits==2,'active damage boost')
s.damageBoostExpiresAt=100 check(R.Resolve(s).hits==3,'boost expiry equality')
s.wall.requiredLevel=2 check(R.Resolve(s).detail:find('NEED LV 2',1,true)~=nil,'level gate guidance')
s=state() s.power=0 check(R.Resolve(s).detail:find('TRAIN FOR POWER',1,true)~=nil,'zero power guidance')
for _,mutate in ipairs({function(v)v.ready=false end,function(v)v.blocked=true end}) do s=state() mutate(s) check(R.Resolve(s)==nil,'modal/dead/layout readiness suppression') end
for _,mutate in ipairs({function(v)v.wall.valid=false end,function(v)v.wall.broken=true end,function(v)v.wall.hp=0 end,function(v)v.wall.maxHP=0 end,function(v)v.wall.distance=24.01 end,function(v)v.wall.facing=-.1 end}) do s=state() mutate(s) check(R.Resolve(s).kind=='Boss','invalid wall must release ownership to near boss') end
s=state() s.wall=nil p=R.Resolve(s) check(p.kind=='Boss' and p.ratio==320/600 and p.title=='TITAN P2  |  WEAK x1.5','actual boss phase/HP')
check(p.detail=='HP 320.0M/600.0M  |  SHOCKWAVE 7s','actual replicated deadline')
s.now=101.2 check(R.Resolve(s).detail:find('SHOCKWAVE 6s',1,true)~=nil,'countdown changes with clock')
s.now=110 check(R.Resolve(s).detail:find('SHOCKWAVE 0s',1,true)~=nil,'overdue countdown clamps zero')
s.boss.nextAttackAt=0 check(R.Resolve(s).detail:find('TARGET RED CORES',1,true)~=nil,'idle boss guidance')
for _,mutate in ipairs({function(v)v.boss.valid=false end,function(v)v.boss.broken=true end,function(v)v.boss.hp=0 end,function(v)v.boss.maxHP=0 end,function(v)v.boss.distance=55.01 end}) do s=state() s.wall=nil mutate(s) check(R.Resolve(s)==nil,'no stale/distant/broken boss display') end
-- Execute actual property application, including same-name replacement and stale outline release.
R.wall={} s=state() p=R.Resolve(s) check(R.Apply(p)==true,'initial display')
check(targetHUD.Visible and not bossHUD.Visible and R.Outline.Enabled and R.Outline.Adornee==R.wall,'actual wall ownership')
check(targetTitle.Text==p.title and targetDetail.Text==p.detail and targetFill.Size=='0.75:1','actual wall GUI content')
local before=R.renderCount for i=1,50 do check(R.Apply(p)==false,'unchanged presentation rewrote text') end check(R.renderCount==before,'render cache count')
R.wall={} R.Apply(p) check(R.Outline.Adornee==R.wall,'same-name new Instance outline')
s.wall=nil p=R.Resolve(s) R.Apply(p) check(bossHUD.Visible and not targetHUD.Visible and R.Outline.Adornee==nil and not R.Outline.Enabled,'boss takes exclusive ownership')
check(bossTitle.Text==p.title and bossSubtitle.Text==p.detail,'actual boss GUI content')
R.Apply(nil) check(not bossHUD.Visible and not targetHUD.Visible and not R.Outline.Enabled and R.Outline.Adornee==nil,'hide clears both panels and outline')
check(gui.attrs.CombatHUDKind=='Hidden' and gui.attrs.CombatHUDTarget=='','stale diagnostics clear')
-- Placement consumes rendered rectangles, never a fixed joystick assumption.
local function overlaps(a,b) return a.x<b.x+b.width+6 and a.x+a.width>b.x-6 and a.y<b.y+b.height+6 and a.y+a.height>b.y-6 end
for _,size in ipairs({{1277,720,false},{900,600,false},{1920,1080,false},{874,402,true},{844,390,true},{740,360,true},{667,375,true},{568,320,true},{390,844,true},{320,740,true},{1024,768,true}}) do
 local w,h,compact=table.unpack(size)
 local obstacles={{x=w/2-110,y=50,width=220,height=30},{x=8,y=h-108,width=100,height=100},{x=w-190,y=h-100,width=182,height=92},{x=8,y=90,width=90,height=146},{x=w-98,y=90,width=90,height=218},{x=w/2-170,y=5,width=340,height=40}}
 for _,scale in ipairs({.8,1,1.2}) do local layout=R.FindLayout(w,h,compact,scale,obstacles) check(layout~=nil,'no safe lane '..w..'x'..h..'@'..scale)
 check(layout.x>=0 and layout.y>=8 and layout.x+layout.width<=w and layout.y+layout.height<=h-8,'viewport bounds')
 check(layout.titleSize>=14 and layout.detailSize>=12,'readability floors')
 for _,o in ipairs(obstacles) do check(not overlaps(layout,o),'actual control overlap') end
 end
end
check(R.FindLayout(200,100,true,1,{})==nil,'unready viewport fails closed')
check(R.FindLayout(500,300,true,1,{{x=0,y=0,width=500,height=300}})==nil,'no safe lane must not overlap controls')
print('PASS '..checks..' production combat HUD behavioral assertions')
`;
const program=mocks+number+helpers+tests;
const result=run(program);assert.equal(result.status,0,result.stderr||result.stdout);console.log(result.stdout.trim());
const mutations=[
 ['modal guard','if not state.ready or state.blocked then return nil end','if not state.ready then return nil end'],
 ['broken wall','wall.valid and not wall.broken and wall.hp','wall.valid and wall.hp'],
 ['boss range','and boss.distance <= 55','and boss.distance <= 9999'],
 ['boost expiry','state.damageBoostExpiresAt > state.now','state.damageBoostExpiresAt >= state.now'],
 ['HP fill','ratio = math.clamp(wall.hp / wall.maxHP, 0, 1)','ratio = 1'],
 ['outline release','local adornee = kind == "Wall" and runtime.wall or nil','local adornee = runtime.wall'],
 ['cache','if key == runtime.renderKey then return false end','if false then return false end'],
 ['control clearance','then clear = false break end','then clear = true break end'],
];
for(const [name,from,to] of mutations){assert(helpers.includes(from),`missing mutation ${name}`);const mutant=run(mocks+number+helpers.replace(from,to)+tests,'mutant');assert.notEqual(mutant.status,0,`survived mutation ${name}`);assert(!String(mutant.stderr).includes('SyntaxError'),`syntax-only failure ${name}`);}
console.log(`PASS ${mutations.length} semantic negative mutations`);
const compiled=spawnSync(compiler,[file],{encoding:'utf8',maxBuffer:8*1024*1024});assert.equal(compiled.status,0,compiled.stderr);
const flow=JSON.parse(fs.readFileSync(path.join(root,'work/automation/flows/combat-target-boss-hud.json'),'utf8'));
let chunks=0;for(const step of [...flow.steps,...(flow.cleanup||[])]){if(!step.args?.code)continue;const p=path.join(temp,`flow-${chunks++}.luau`);fs.writeFileSync(p,step.args.code);const c=spawnSync(compiler,[p],{encoding:'utf8'});assert.equal(c.status,0,`${step.label}: ${c.stderr}`);}
console.log(`PASS full client and ${chunks} runtime-flow chunks compile; no Studio calls`);

checkWiring();
console.log('PASS current source scan/event wiring');

console.log('Source SHA256 (LF normalized): '+createHash('sha256').update(source).digest('hex'));
