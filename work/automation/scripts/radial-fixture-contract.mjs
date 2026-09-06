import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {spawnSync} from 'node:child_process';

const root=path.resolve(import.meta.dirname,'../../..');
const flowPath='work/automation/flows/punchwall-radius-damage-shake.json';
const sourcePath='work/punch-wall-rpg/src/server/PunchWallBootstrap.server.lua';
const flow=JSON.parse(fs.readFileSync(path.join(root,flowPath),'utf8'));
const source=fs.readFileSync(path.join(root,sourcePath),'utf8').replace(/\r\n?/g,'\n');
const config=fs.readFileSync(path.join(root,'work/punch-wall-rpg/src/shared/GameConfig.lua'),'utf8').replace(/\r\n?/g,'\n');
function between(s,a,b){const i=s.indexOf(a),j=s.indexOf(b,i+a.length);assert(i>=0&&j>i,a);return s.slice(i,j);}
function historical(file){const r=spawnSync('git',['show',`4adf4fd:${file}`],{cwd:root,encoding:'utf8'});assert.equal(r.status,0,r.stderr);return r.stdout.replace(/\r\n?/g,'\n');}
const old=JSON.parse(historical(flowPath));
assert.equal(flow.steps.length,old.steps.length);
for(let i=0;i<flow.steps.length;i++)if(i!==4)assert.deepEqual(flow.steps[i],old.steps[i],`Unrelated original phase ${i} changed`);
const step=flow.steps[4], code=step.args.code;
for(const gate of old.steps[4].expectRegex)assert(step.expectRegex.includes(gate),`Original gate removed: ${gate}`);
assert.equal(step.saveAs,'toughBlockDiagnostic');
assert.deepEqual(flow.cleanup.slice(1),old.cleanup,'Original Stop must remain independent of fixture restoration');
assert.equal(flow.cleanup[0].allowError,true);
assert.equal(flow.cleanup[0].tool,'execute_luau');
assert(code.indexOf('verifyEphemeralSeed(players[1]')<code.indexOf("c:Invoke('Reset')"),'Guard must precede all mutation');
assert(!/rootPart\.Anchored\s*=|humanoid\.(?:AutoRotate|WalkSpeed|HipHeight)\s*=|:Clone\(/.test(code),'Do not anchor, alter humanoid, or clone blocks');
assert(code.includes("c:Invoke('SetStats',{Power=100,WallLevel=3,CritChance=0,FistMultiplier=1,PetMultiplier=0,FistMastery=1,Rebirths=0,HonorPowerBonus=0})"));
assert(code.indexOf('xpcall(function()')<code.indexOf("local r=c:Invoke('PunchRadius')")&&code.indexOf('pcall(restoreRadialFixture')>code.indexOf('end,function(err)'),'Independent protected restoration must follow success or failure');
const helpers=between(code,'local function selectStoneFixture(',"\nlocal H=game:GetService('HttpService')");
assert(flow.cleanup[0].args.code.includes(helpers),'Failure cleanup uses the same owned restoration helper');
const punch=between(source,'function depthPunch.Punch(player, directionName)','\nlocal BOSS_BASE_HP');
assert.equal(punch,between(historical(sourcePath),'function depthPunch.Punch(player, directionName)','\nlocal BOSS_BASE_HP'),'Fixture must preserve the exact authoritative attack');
assert(punch.indexOf('task.wait(depthPunch.WindupSeconds)')<punch.indexOf('local origin = rootPart.Position'),'Native selection reads the pose after windup');
assert(source.includes('WindupSeconds = 0.2,'));
const distance=between(punch,'\tlocal function distanceToBlockSurface(', '\n\tlocal character =');
const scan=between(punch,'\tlocal direction = actionDirection','\n\tlocal hitCount = 0');
const damage=between(source,'\tlocal previousHP = block:GetAttribute("HP") or 0','\n\tdepthPunch.CancelShake(block)');
const shake=between(source,'function depthPunch.Shake(block, intensity)','\nfunction depthPunch.ReleaseStructuralSlot');
const cancelShake=between(source,'function depthPunch.CancelShake(block)','\nfunction depthPunch.CancelPunch');
const power=between(config,'function GameConfig.EffectivePower(', '\nGameConfig.Pets =');
const grid=between(source,'\t\t\tlocal x = -2 + (column', '\n\t\t\tlocal shade =');
const depthConfig=between(config,'GameConfig.DepthWall = {','\n\n-- Hero scale');
const punchConstants=between(source,'local depthPunch = {','\nlocal structuralDirtyLayers');
const profile=between(source,'function depthPunch.PowerProfile(player)','\nfunction depthPunch.PlanSafeLunge');
const outCases=[];
const tmp=os.tmpdir();
const luau=[process.env.LUAU_COMMAND,...fs.readdirSync(tmp).filter(n=>n.startsWith('codex-luau-')).sort().reverse().map(n=>path.join(tmp,n,'luau.exe')),'luau'].find(p=>p&&spawnSync(p,['--help']).status===0);
assert(luau,'BLOCKED: Luau runtime required');
const compiler=process.env.LUAU_COMPILE_COMMAND||path.join(path.dirname(luau),'luau-compile.exe');
const directory=fs.mkdtempSync(path.join(tmp,'smash-radial-fixture-contract-'));
let compiled=0,mutations=0;
function compile(name,body){const file=path.join(directory,name+'.luau');fs.writeFileSync(file,body);const r=spawnSync(compiler,['--null',file],{encoding:'utf8',timeout:15000});assert.equal(r.status,0,r.stdout+r.stderr);compiled++;return file;}
function execute(name,body){const file=compile(name,body);const r=spawnSync(luau,[file],{encoding:'utf8',timeout:20000});return {status:r.status,output:r.stdout+r.stderr};}
const setup=String.raw`
local checks=0 local function check(value,name) assert(value,name) checks+=1 end
local Vector3,vm={},{}
function Vector3.new(x,y,z) return setmetatable({X=x or 0,Y=y or 0,Z=z or 0},vm) end
vm.__add=function(a,b)return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z)end
vm.__sub=function(a,b)return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end
vm.__mul=function(a,b)if type(a)=='number'then a,b=b,a end return Vector3.new(a.X*b,a.Y*b,a.Z*b)end
vm.__eq=function(a,b)return a.X==b.X and a.Y==b.Y and a.Z==b.Z end
vm.__index=function(a,k)if k=='Magnitude'then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z)end if k=='Unit'then return a*(1/a.Magnitude)end if k=='Dot'then return function(a,b)return a.X*b.X+a.Y*b.Y+a.Z*b.Z end end end
Vector3.zero=Vector3.new(0,0,0)
local CFrame,cm={},{}
function CFrame.new(x,y,z)if type(x)=='number'then x=Vector3.new(x,y,z)end return setmetatable({Position=x or Vector3.zero,LookVector=Vector3.new(0,0,-1)},cm)end
function CFrame.lookAt(v)return CFrame.new(v)end
cm.__index={PointToObjectSpace=function(a,b)return b-a.Position end,PointToWorldSpace=function(a,b)return b+a.Position end}
cm.__eq=function(a,b)return a.Position==b.Position end
cm.__mul=function(a,b)return CFrame.new(a.Position+b.Position)end
local function typeof(v)if getmetatable(v)==vm then return 'Vector3'elseif getmetatable(v)==cm then return 'CFrame'end return type(v)end
local Enum={HumanoidRigType={R6='R6',R15='R15'},RaycastFilterType={Include='Include'},EasingStyle={Quad='Quad',Elastic='Elastic'},EasingDirection={Out='Out'}}
local OverlapParams={new=function()return {}end}
local Color3={fromRGB=function()return {Lerp=function(a)return a end}end}
local TweenInfo={new=function()return {}end}
local delayed={}local task={delay=function(_,fn)table.insert(delayed,fn)end}
local TweenService={Create=function(_,block,_,properties)return {Cancel=function()end,Play=function()block.CFrame=properties.CFrame end,Completed={Once=function(_,fn)fn()end}}end}
local failRestoreAt,restoreAttempts,protectedDepth=nil,0,nil
local methods,im={},{}
im.__index=function(a,k)if k=='Position'then return a.props.CFrame.Position end return methods[k]or a.props[k]end
im.__newindex=function(a,k,v)
 if k=='Parent'and v==protectedDepth and a.props.Parent and string.find(a.props.Parent.Name,'RadialStoneFixture_',1,true)==1 then
  restoreAttempts+=1 if failRestoreAt==restoreAttempts then failRestoreAt=nil error('injected partial corridor restoration')end
 end
 if k=='Parent'and a.props.Parent then local children=a.props.Parent.children for i=#children,1,-1 do if children[i]==a then table.remove(children,i)end end end
 a.props[k]=v if k=='Parent'and v then table.insert(v.children,a)end
end
local Instance={new=function(class)return setmetatable({props={ClassName=class,Name=class,CFrame=CFrame.new(),Size=Vector3.new(4,4,4),Anchored=true,CanCollide=true,CanQuery=true,CanTouch=true},attrs={},children={}},im)end}
function methods:IsA(class)return self.ClassName==class or(class=='BasePart'and self.ClassName=='Part')end
function methods:GetAttribute(key)return self.attrs[key]end
function methods:SetAttribute(key,value)self.attrs[key]=value end
function methods:GetAttributes()return table.clone(self.attrs)end
function methods:GetChildren()return table.clone(self.children)end
function methods:FindFirstChild(name,recurse)for _,c in ipairs(self.children)do if c.Name==name then return c end if recurse then local hit=c:FindFirstChild(name,true)if hit then return hit end end end end
function methods:FindFirstChildOfClass(class)for _,c in ipairs(self.children)do if c.ClassName==class then return c end end end
function methods:Destroy()for _,c in ipairs(self:GetChildren())do c:Destroy()end self.Parent=nil self.destroyed=true end
local GameConfig={Walls={{hp=8},{hp=900}},RebirthBonus=function()return 1 end}
__DEPTH_CONFIG__
__POWER__
local depthBlocksFolder,world,storage,player,character,rootPart,humanoid,workspace,game
local actualStats={}local failPunch=nil local malformed=nil local invocations=0 local sideEffects=0 local lastResult
local function statValue(_,key,fallback)return actualStats[key]or fallback end
__PUNCH_CONSTANTS__
__PROFILE__
local depthBlockContributions={}
local function markDepthBlockDirty()end
local function sendFeedback()end local function completeTutorialAction()end
local function create(class,name,parent)local obj=Instance.new(class)obj.Name=name obj.Parent=parent return obj end
__CANCEL_SHAKE__
__SHAKE__
local function actualHit(player,block,amount)
 local damage=amount local wasDetached=false local options={}local critical=false
 __DAMAGE__
 error('unexpected fixture destruction')
end
local function actualPrimary(position)
 local rootPart={Position=position}local actionDirection=Vector3.new(0,0,-1)
 local profile=depthPunch.PowerProfile(player) profile.requestedDistance=profile.distance
 __DISTANCE__
 __SCAN__
 return candidates[1]and candidates[1].block,candidates
end
local function overlapBox(cf,size,block)
 local d=block.Position-cf.Position
 return math.abs(d.X)<(size.X+block.Size.X)*.5 and math.abs(d.Y)<(size.Y+block.Size.Y)*.5 and math.abs(d.Z)<(size.Z+block.Size.Z)*.5
end
local function scene()
 depthBlockContributions={}delayed={}failPunch=nil malformed=nil invocations=0 sideEffects=0 depthPunch.ActiveShakes={}
 world=create('Folder','PunchWallRPG')storage=create('Folder','ServerStorage')depthBlocksFolder=create('Folder','Depth Blocks',world)world['Depth Blocks']=depthBlocksFolder
 protectedDepth=depthBlocksFolder failRestoreAt=nil restoreAttempts=0
 world:SetAttribute('PersistenceMode','EphemeralStudio')world:SetAttribute('PersistenceStudioDefaultEphemeral',true)world:SetAttribute('PersistenceStudioLiveDataOptIn',false)
 player=create('Player','QA')player.UserId=123 player:SetAttribute('ProfileReady',true)player:SetAttribute('ProfilePersistenceState','EphemeralStudio')player:SetAttribute('ProfileWritable',false)
 character=create('Model','QA')player.Character=character
 rootPart=create('Part','HumanoidRootPart',character)rootPart.Size=Vector3.new(2,2,1)rootPart.CFrame=CFrame.new(-2,3,-20)rootPart.Anchored=false rootPart.AssemblyLinearVelocity=Vector3.new(1,2,3)rootPart.AssemblyAngularVelocity=Vector3.new(.1,.2,.3)character.HumanoidRootPart=rootPart
 humanoid=create('Humanoid','Humanoid',character)humanoid.Health=100 humanoid.HipHeight=2 humanoid.RigType='R15' humanoid.AutoRotate=true
 function character:GetBoundingBox()return CFrame.new(rootPart.Position+Vector3.new(0,-.25,0)),Vector3.new(4.5,6,2.5)end
 local floor=create('Part','Depth Corridor Floor',world)floor.CFrame=CFrame.new(-2,.05,-192)floor.Size=Vector3.new(56,.5,330)
 local DEPTH_BLOCK_SIZE=GameConfig.DepthWall.BlockSize local DEPTH_COLUMNS=GameConfig.DepthWall.Columns
 for layer=1,GameConfig.DepthWall.Layers do for row=1,GameConfig.DepthWall.Rows do for column=1,DEPTH_COLUMNS do
  __GRID__
  local tier=math.ceil(layer/GameConfig.DepthWall.LayersPerTier)
  local b=create('Part',('DepthBlock_L%03d_C%02d_R%02d'):format(layer,column,row),depthBlocksFolder)b.CFrame=CFrame.new(x,y,z)b.Size=DEPTH_BLOCK_SIZE
  for k,v in pairs({IsDepthBlock=true,Depth=layer,Tier=tier,MaterialTier=tier,Column=column,Row=row,MaxHP=tier==1 and 8 or 900,HP=tier==1 and 8 or 900,RequiredLevel=tier==1 and 1 or 3,Broken=false,BaseCFrame=b.CFrame})do b:SetAttribute(k,v)end
  b.Color=Color3.fromRGB()b.Material={Name='Stone'}
 end end end
 workspace={PunchWallRPG=world,FindFirstChild=function(_,name)if name=='PunchWallRPG'then return world end end,GetServerTimeNow=function()return 200 end}
 function workspace:GetPartBoundsInBox(cf,size,params)
  local found={}for _,b in ipairs(params.FilterDescendantsInstances[1]:GetChildren())do
   if params.MaxParts~=0 or overlapBox(cf,size,b)then table.insert(found,b)end
  end return found
 end
 local players={GetPlayers=function()return {player}end}
 local H={GenerateGUID=function()return 'owned-token'end,JSONEncode=function(_,value)lastResult=value return value end}
 local c={}
 function c:Invoke(action,values)
  invocations+=1
  if action=='Reset'then return {ok=true}end
  if action=='SetStats'then actualStats=values return {ok=true}end
  check(action=='PunchRadius','actual single punch API')sideEffects+=1
  if failPunch=='before'then error('injected before producer')end
  if failPunch=='character'then player.Character=create('Model','Replacement')error('injected character replacement')end
  local primary=actualPrimary(rootPart.Position)
  if primary then actualHit(player,primary,GameConfig.EffectivePower(100,1,0,0,1,0))end
  if failPunch=='after'then error('injected after producer')end
  return {ok=primary~=nil,primary=primary and primary.Name or 'none'}
 end
 storage.PunchWallAutomation=c
 local services={HttpService=H,ServerStorage=storage,Players=players,RunService={IsStudio=function()return true end}}
 game={ServerStorage=storage,Players=players,ReplicatedStorage={GameConfig=GameConfig},GetService=function(_,name)return services[name]end}
end
local function require(value)return value end
`;
const filled=setup.replace('__DEPTH_CONFIG__',depthConfig).replace('__POWER__',power).replace('__PUNCH_CONSTANTS__',punchConstants).replace('__PROFILE__',profile).replace('__CANCEL_SHAKE__',cancelShake).replace('__SHAKE__',shake).replace('__DAMAGE__',damage).replace('__DISTANCE__',distance).replace('__SCAN__',scan).replace('__GRID__',grid);
const test=String.raw`
local function fixture()
__CODE__
end
local function failureCleanup()
__CLEANUP__
end
local function allRestored(originalRoot,linear,angular)
 check(#depthBlocksFolder:GetChildren()==5400,'all original blocks returned')
 check(#storage:GetChildren()==0 and world:GetAttribute('RadialStoneFixtureToken')==nil,'owned holding removed')
 check(rootPart.CFrame==originalRoot and rootPart.AssemblyLinearVelocity==linear and rootPart.AssemblyAngularVelocity==angular,'original pose and both velocities restored')
 check(not rootPart.Anchored and humanoid.AutoRotate,'real unanchored humanoid preserved')
 for _,b in ipairs(depthBlocksFolder:GetChildren())do
  if b:GetAttribute('Tier')==1 then check(b:GetAttribute('HP')==8 and not b:GetAttribute('Broken') and b.CFrame==b:GetAttribute('BaseCFrame') and b.CanCollide and b.CanQuery,'held wood untouched')end
 end
end
scene()local original=rootPart.CFrame local linear=rootPart.AssemblyLinearVelocity local angular=rootPart.AssemblyAngularVelocity
local out=fixture()
check(out.ok and out.selectedTarget and out.fixtureRestored,'actual fixture producer pass')
check(out.expectedTarget=='DepthBlock_L009_C06_R01' and out.primary==out.expectedTarget and out.tier==2 and out.materialTier==2,'actual grid-derived identity')
check(out.approachBlocking==0 and out.beforeTarget and out.clearedCount==27,'bounded clear approach before intact face')
check(out.maxHP==900 and math.abs(out.hp-799.9)<1e-9 and out.exactDamage and out.survived and out.shakeToken>=2,'unchanged actual damage and shake producer')
check(out.poseBefore.z==-61 and out.poseAfter.z==-61,'both actual pose observations retained')
check(invocations==3 and sideEffects==1,'one Reset, exact seed and one real punch')
allRestored(original,linear,angular)
for _,fn in ipairs(delayed)do fn()end
local target=depthBlocksFolder:FindFirstChild(out.primary)
check(target.CFrame==target:GetAttribute('BaseCFrame')and target:GetAttribute('Shaking')==false,'actual native shake completion writes grid and false')
for _,failure in ipairs({'before','after'})do
 scene()failPunch=failure original=rootPart.CFrame linear=rootPart.AssemblyLinearVelocity angular=rootPart.AssemblyAngularVelocity
 out=fixture()check(not out.ok and out.fixtureRestored and string.find(out.error,'injected'),'failed punch evidence preserved after restoration')
 check(out.poseBefore and out.poseAfter and out.targetAfterTier==2 and type(out.targetAfterHP)=='number','error retains actual pose and target state before cleanup')
 allRestored(original,linear,angular)
end
scene()failPunch='character'out=fixture()
check(not out.ok and not out.fixtureRestored and string.find(out.restoreError,'original character changed'),'character replacement reports a failed pose restore')
check(#depthBlocksFolder:GetChildren()==5400 and #storage:GetChildren()==0 and world:GetAttribute('RadialStoneFixtureToken')==nil,'character replacement still restores every held block')
check(#player.Character:GetChildren()==0,'never moves or modifies a replacement character')
scene()failRestoreAt=5 original=rootPart.CFrame linear=rootPart.AssemblyLinearVelocity angular=rootPart.AssemblyAngularVelocity
out=fixture()check(not out.ok and not out.fixtureRestored and #depthBlocksFolder:GetChildren()<5400,'partial restoration remains a reported failure')
check(failureCleanup().fixtureRestored,'separate cleanup resumes an interrupted restoration')
allRestored(original,linear,angular)
scene()world:SetAttribute('RadialStoneFixtureToken','foreign')local foreign=create('Folder','RadialStoneFixture_foreign',storage)foreign:SetAttribute('FixtureKind','SomeOtherOwner')foreign:SetAttribute('OwnerUserId',player.UserId)
check(not pcall(failureCleanup)and foreign.Parent==storage and not foreign.destroyed,'cleanup refuses a foreign holding folder')
for _,invalid in ipairs({'world','live','writable','notReady','storageLive'})do
 scene()
 if invalid=='world'then world:SetAttribute('PersistenceMode','Live')elseif invalid=='live'then world:SetAttribute('PersistenceStudioLiveDataOptIn',true)elseif invalid=='writable'then player:SetAttribute('ProfileWritable',true)elseif invalid=='notReady'then player:SetAttribute('ProfileReady',false)else storage:SetAttribute('PunchWallAllowLiveDataStoreAccess',true)end
 check(not pcall(fixture)and invocations==0 and #storage:GetChildren()==0,'strict guard rejects '..invalid..' before Reset')
end
scene()actualStats={WallLevel=3,Power=100}
local historical=actualPrimary(Vector3.new(-2.774242401123047,2.948559045791626,-66.9987564086914))
check(historical:GetAttribute('Tier')==1 and historical:GetAttribute('MaxHP')==8,'actual post-windup native diagnostic pose selects the preceding wood')
local oldOverlaps=0 for _,b in ipairs(depthBlocksFolder:GetChildren())do if overlapBox(CFrame.new(-2,3,-68),Vector3.new(4.5,6,2.5),b)then oldOverlaps+=1 end end
check(oldOverlaps>0,'original embedded pose is not a clear physics fixture')
print('PASS '..checks..' production fixture/restoration assertions')
`;
const testWithCleanup=test.replace('__CLEANUP__',flow.cleanup[0].args.code);
try{
 for(let i=0;i<flow.steps.length;i++)if(flow.steps[i].args?.code)compile('flow-step-'+i,flow.steps[i].args.code);
 for(let i=0;i<flow.cleanup.length;i++)if(flow.cleanup[i].args?.code)compile('flow-cleanup-'+i,flow.cleanup[i].args.code);
 const result=execute('production-fixture',filled+testWithCleanup.replace('__CODE__',code));
 assert.equal(result.status,0,result.output);console.log(result.output.trim());
 const replacements=[
  ['last preceding layer retained',"b:GetAttribute('Depth')<target:GetAttribute('Depth')","b:GetAttribute('Depth')<target:GetAttribute('Depth')-1"],
  ['wrong tier admitted',"b:GetAttribute('Tier')==2 and b:GetAttribute('MaterialTier')==2 and b:GetAttribute('MaxHP')==G.Walls[2].hp","b:GetAttribute('Tier')==1 and b:GetAttribute('MaterialTier')==1"],
  ['approach moved inside target','target.Position.Z+target.Size.Z*2','target.Position.Z'],
  ['root velocity restoration omitted',"rootPart.AssemblyLinearVelocity=holding:GetAttribute('OriginalLinearVelocity')","-- omitted original linear velocity"],
  ['held instances not restored','b.Parent=folder restored+=1','restored+=1'],
  ['wrong damage accepted',"out.exactDamage=math.abs(b:GetAttribute('HP')-expectedHP)<1e-6","out.exactDamage=false"],
 ];
 for(const[name,from,to]of replacements){assert(code.includes(from),name);const mutant=code.replace(from,to);const r=execute('mutant-'+mutations,filled+testWithCleanup.replace('__CODE__',mutant));assert.notEqual(r.status,0,`Survived: ${name}`);mutations++;}
 for(const [name,from,to]of [['actual HP damage removed','block:SetAttribute("HP", remainingHP)','block:SetAttribute("HP", previousHP)'],['actual shake notification removed','depthPunch.Shake(block, 0.08 + stage * 0.045 + math.min(0.1, damage / math.max(1, block:GetAttribute("MaxHP") or 1) * 0.12))','do end']]){
  assert(filled.includes(from),name);const r=execute('mutant-source-'+mutations,filled.replace(from,to)+testWithCleanup.replace('__CODE__',code));assert.notEqual(r.status,0,`Survived: ${name}`);mutations++;
 }
 const passing={ok:true,shakeToken:2,survived:true,hp:799.9,maxHP:900,exactDamage:true,selectedTarget:true,fixtureRestored:true,beforeTarget:true,approachBlocking:0,materialTier:2};
 const accepted=row=>step.expectRegex.every(pattern=>new RegExp(pattern,'s').test(JSON.stringify(row)));
 assert(accepted(passing));
 for(const[key,value]of Object.entries({ok:false,shakeToken:1,survived:false,hp:900,maxHP:8,exactDamage:false,selectedTarget:false,fixtureRestored:false,beforeTarget:false,approachBlocking:1,materialTier:1})){assert(!accepted({...passing,[key]:value}),key);outCases.push(key);}
 console.log(`PASS ${compiled} Luau compiles, ${mutations} executed weakening mutations, ${outCases.length} retained output-gate controls. Native physics remains coordinator-only.`);
}finally{
 const resolved=path.resolve(directory);assert(path.dirname(resolved)===path.resolve(tmp));fs.rmSync(resolved,{recursive:true,force:true});
}
