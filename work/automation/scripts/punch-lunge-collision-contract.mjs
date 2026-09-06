import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
const root=path.resolve(import.meta.dirname,'../../..');
const sourcePath='work/punch-wall-rpg/src/server/PunchWallBootstrap.server.lua';
const source=fs.readFileSync(path.join(root,sourcePath),'utf8').replace(/\r\n?/g,'\n');
const baselineResult=spawnSync('git',['show',`f10dfc5:${sourcePath}`],{cwd:root,encoding:'utf8'});
assert.equal(baselineResult.status,0,baselineResult.stderr);
const baseline=baselineResult.stdout.replace(/\r\n?/g,'\n');
const flow=JSON.parse(fs.readFileSync(path.join(root,'work/automation/flows/punch-lunge-collision-filter.json'),'utf8'));
const step=flow.steps.find(s=>s.saveAs==='lungeCollision');
const code=step.args.code;
function between(text,from,to){const a=text.indexOf(from),b=text.indexOf(to,a+from.length);assert(a>=0&&b>a,from);return text.slice(a,b);}
const begin='function depthPunch.Lunge(player, rootPart, profile)';
const end='\nlocal function hitDepthBlock';
const lunge=between(source,begin,end),oldLunge=between(baseline,begin,end);
const added='\t-- Pickup targets remain queryable, but only physical solids stop a lunge.\n\tparams.RespectCanCollide = true\n';
assert.equal(lunge.replace(added,''),oldLunge,'Only the physical-ray filter changes in Lunge');
for(const [from,to]of[
 ['function depthPunch.ComputeClearedLunge(',begin],
 ['function depthPunch.Punch(player, directionName)','\nlocal BOSS_BASE_HP'],
 ['function petDropRuntime.Spawn(', '\nfunction petDropRuntime.Claim('],
])assert.equal(between(source,from,to),between(baseline,from,to),'Preserve body sweep, authority/damage/level planning and native pickup producer');
assert(lunge.indexOf('params.RespectCanCollide = true')<lunge.indexOf('workspace:Raycast('));
assert(code.includes("{'clear','egg','solid'}")&&code.includes("c:Invoke('ForcePetEggDrop',1)")&&code.includes("c:Invoke('PunchRadius')"),'Native fixture uses production pickup and server punch');
assert(code.indexOf('connection=R.PostSimulation:Connect')<code.indexOf("local punch=c:Invoke('PunchRadius')"),'Observe native physics before the yielding launch');
assert(code.includes("egg.CanQuery and not egg.CanCollide")&&!/egg\.(?:CanQuery|CanCollide)\s*=(?!=)/.test(code),'Preserve production pickup flags');
assert(code.indexOf("world:GetAttribute('PersistenceMode')=='EphemeralStudio'")<code.indexOf('Instance.new'),'Strict ephemeral guard precedes fixture mutation');
for(const gate of ["#players==1","PersistenceStudioDefaultEphemeral')==true","PersistenceStudioLiveDataOptIn')==false","PunchWallAllowLiveDataStoreAccess')~=true","ProfilePersistenceState')=='EphemeralStudio'","ProfileWritable')==false"])assert(code.includes(gate),gate);
assert(code.includes('local ok,why=xpcall')&&code.includes('local cleaned=cleanup()')&&code.includes('connection:Disconnect()')&&code.includes('#encoded<3900'),'Bounded evidence and independent cleanup');
assert(flow.cleanup[0].args.code.includes("OwnedByFlow')=='punch-lunge-collision-filter'")&&flow.cleanup.at(-1).args.is_start===false,'Owned-only fixture cleanup followed by independent stop');
const verify=between(code,'local function verifyLungeFixtureRow(row)','\nlocal H=');
const tmp=os.tmpdir();
const luau=[process.env.LUAU_COMMAND,...fs.readdirSync(tmp).filter(n=>n.startsWith('codex-luau-')).sort().reverse().map(n=>path.join(tmp,n,'luau.exe')),'luau'].find(p=>p&&spawnSync(p,['--help']).status===0);
assert(luau,'BLOCKED: Luau CLI required');
const compiler=process.env.LUAU_COMPILE_COMMAND||path.join(path.dirname(luau),'luau-compile.exe');
const directory=fs.mkdtempSync(path.join(tmp,'smash-lunge-collision-contract-'));
const files=[];
function write(name,text){const file=path.join(directory,name+'.luau');fs.writeFileSync(file,text);files.push(file);return file;}
function run(name,text){const file=write(name,text);const result=spawnSync(luau,[file],{encoding:'utf8',timeout:15000});return {status:result.status,output:result.stdout+result.stderr};}
const setup=`
local count=0 local function check(v,n)assert(v,n)count+=1 end
local Vector3,vm={},{} function Vector3.new(x,y,z)return setmetatable({X=x,Y=y,Z=z},vm)end
vm.__add=function(a,b)return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z)end
vm.__sub=function(a,b)return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end
vm.__mul=function(a,b)return Vector3.new(a.X*b,a.Y*b,a.Z*b)end
vm.__index=function(a,k)if k=='Magnitude'then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z)end if k=='Unit'then return a*(1/a.Magnitude)end if k=='Dot'then return function(a,b)return a.X*b.X+a.Y*b.Y+a.Z*b.Z end end end
Vector3.zero=Vector3.new(0,0,0)
local CFrame,fm={},{} function CFrame.new(v)return setmetatable({Position=v or Vector3.zero,LookVector=Vector3.new(0,0,-1)},fm)end
function CFrame.lookAt(v)return CFrame.new(v)end fm.__add=function(a,b)return CFrame.new(a.Position+b)end
local function typeof(v)return getmetatable(v)==vm and 'Vector3'or type(v)end
local Enum={RaycastFilterType={Exclude='Exclude',Include='Include'},EasingStyle={Quad='Quad'},EasingDirection={InOut='InOut'},PlaybackState={Completed='Completed'}}
local RaycastParams={new=function()return {RespectCanCollide=false}end}local OverlapParams={new=function()return {}end}
local TweenInfo={new=function(...)return {...}end}local delayed={}local task={wait=function()end,delay=function(_,fn)table.insert(delayed,fn)end}
local attrs={}local player={Character={},Parent=true}function player:GetAttribute(k)return attrs[k]end function player:SetAttribute(k,v)attrs[k]=v end
local rootPart={Parent=player.Character}local ownedCalls=0 local autoCalls=0 local restored=0 local owner='client'local completion='Completed'
function rootPart:SetNetworkOwner(value)owner=value ownedCalls+=1 end function rootPart:SetNetworkOwnershipAuto()autoCalls+=1 end
local depthDebrisFolder={}local depthBlocksFolder={}local hits={}local locked={}local level=1
local function statValue(_,name,fallback)if name=='WallLevel'then return level end return fallback end
local depthPunch={LungeClearance=2.6,LungeSeconds=.42,WindupSeconds=.2,OwnershipHoldSeconds=.35,ActiveLunges={},ResolveCharacterOverlaps=function()restored+=1 end}
local shared={PunchWallSetCharacterCollisionGroup=function(_,group)check(group=='PlayerCharacters','restore_character_collision_group')end}
local workspace={GetServerTimeNow=function()return 100 end,GetPartBoundsInBox=function(_,_,_,params)check(params.FilterDescendantsInstances[1]==depthBlocksFolder and params.MaxParts==80,'locked_depth_query_preserved')return locked end}
function workspace:Raycast(origin,extent,params)
 check(origin==rootPart.Position and extent.Z==-48,'actual_ray_origin_and_extent')
 check(params.FilterType=='Exclude' and params.IgnoreWater and params.FilterDescendantsInstances[1]==player.Character and params.FilterDescendantsInstances[2]==depthDebrisFolder and params.FilterDescendantsInstances[3]==depthBlocksFolder,'actual_exclusions_preserved')
 for _,hit in ipairs(hits)do if (params.RespectCanCollide and hit.Instance.CanCollide)or(not params.RespectCanCollide and hit.Instance.CanQuery)then return hit end end
end
local TweenService={Create=function(_,part,info,props)
 check(info[1]==.42,'actual_tween_duration_preserved')
 return {Play=function()check(owner==nil,'tween_remains_server_owned')if completion=='Completed'then part.CFrame=props.CFrame part.Position=props.CFrame.Position end end,Completed={Wait=function()return completion end}}
end}
local function reset()
 attrs={PunchOwnershipToken=1}rootPart.Parent=player.Character rootPart.Position=Vector3.zero rootPart.CFrame=CFrame.new()rootPart.AssemblyLinearVelocity=Vector3.new(0,3,0)
 delayed={}ownedCalls=0 autoCalls=0 restored=0 owner='client'completion='Completed'hits={}locked={}level=1
end
local function invoke()
 return depthPunch.Lunge(player,rootPart,{distance=48,requestedDistance=48,powerScale=1,forceScale=3.4,limit=48,ownershipToken=1,skipWindup=true})
end
local egg={Instance={CanCollide=false,CanQuery=true},Distance=2.6001739501953124}
local wall={Instance={CanCollide=true,CanQuery=true},Distance=14}
local function depth(required,broken)
 return {Position=Vector3.new(0,0,-10),Size=Vector3.new(4,4,4),GetAttribute=function(_,key)return ({IsDepthBlock=true,Broken=broken,RequiredLevel=required})[key]end}
end
`;
const cases=`
reset()hits={egg}local r=invoke()check(r and r.travel==48 and rootPart.Position.Z==-48,'query_only_egg_cannot_shorten_real_producer')
check(ownedCalls==1 and attrs.LastPunchLungeAt==100 and attrs.LastPunchLungeDistance==48,'actual_metadata_and_server_ownership')
delayed[1]()check(autoCalls==1 and restored==1,'ownership_and_collision_cleanup_preserved')
reset()hits={egg,wall}r=invoke()check(r and math.abs(r.travel-11.4)<1e-10,'real_solid_behind_pickup_still_stops_lunge')
reset()hits={wall}r=invoke()check(math.abs(r.travel-11.4)<1e-10,'ordinary_solid_clearance_unchanged')
reset()r=invoke()check(r.travel==48,'no_hit_path_unchanged')
reset()hits={{Instance={CanCollide=true,CanQuery=true},Distance=1}}r=invoke()check(r.travel==0 and rootPart.Position.Z==0,'near_solid_never_causes_negative_travel')
reset()locked={depth(2,false)}r=invoke()check(math.abs(r.travel-5.4)<1e-10,'locked_depth_remains_a_barrier')
reset()locked={depth(1,false)}r=invoke()check(r.travel==48,'unlocked_depth_does_not_add_a_lock')
reset()locked={depth(99,true)}r=invoke()check(r.travel==48,'broken_depth_does_not_add_a_lock')
reset()attrs.PunchOwnershipToken=2 check(invoke()==nil and ownedCalls==0,'stale_ownership_cannot_lunge')
reset()rootPart.Parent={}check(invoke()==nil and ownedCalls==0,'old_character_cannot_lunge')
reset()completion='Cancelled'check(invoke()==nil and #delayed==0,'interrupted_tween_cannot_finish_as_success')
reset()invoke()attrs.PunchOwnershipToken=2 delayed[1]()check(autoCalls==0,'stale_delayed_cleanup_cannot_change_new_owner')
check(egg.Instance.CanQuery and not egg.Instance.CanCollide,'pickup_properties_unchanged')
print('PASS '..count)
`;
const oracleCases=`
local count=0 local function check(v,n)assert(v,n)count+=1 end
${verify}
local function row(kind)
 return {case=kind,accepted=true,timestampFresh=true,ownershipAdvanced=true,serverOwned=true,physicsSamples=10,maxObservedMove=4,unanchored=true,noDepthTarget=true,planClear=true,requested=10.5,planned=10.5,actualMoved=10.5,reportedTravel=10.5,expectedTravel=10.5,bodyOverlaps=0,endpointClearance=999,coinsUnchanged=true,petsUnchanged=true,originalNoHit=kind=='clear',physicalNoHit=kind~='solid',originalHitEgg=kind~='clear',eggQueryable=true,eggNoncollidable=true,physicalHitSolid=kind=='solid'}
end
for _,kind in ipairs({'clear','egg','solid'})do local r=row(kind)if kind=='solid'then r.actualMoved=4.9 r.reportedTravel=4.9 r.expectedTravel=4.9 r.endpointClearance=2.6 end check(pcall(verifyLungeFixtureRow,r),'valid_native_'..kind)end
for _,bad in ipairs({{'actualMoved',0},{'reportedTravel',0},{'timestampFresh',false},{'ownershipAdvanced',false},{'serverOwned',false},{'physicsSamples',0},{'maxObservedMove',0},{'unanchored',false},{'planClear',false},{'bodyOverlaps',1},{'coinsUnchanged',false},{'petsUnchanged',false},{'eggQueryable',false},{'eggNoncollidable',false}})do local r=row('egg')r[bad[1]]=bad[2]check(not pcall(verifyLungeFixtureRow,r),'native_oracle_rejects_'..bad[1])end
print('PASS '..count)
`;
const mutations=[
 ['query_filter_removed',t=>t.replace('params.RespectCanCollide = true','params.RespectCanCollide = false'),'query_only_egg_cannot_shorten_real_producer'],
 ['all_solids_ignored',t=>t.replace('local ray = workspace:Raycast(startPosition, direction * profile.distance, params)','local ray = nil'),'real_solid_behind_pickup_still_stops_lunge'],
 ['negative_travel_allowed',t=>t.replace('math.max(0, ray.Distance - depthPunch.LungeClearance)','ray.Distance - depthPunch.LungeClearance'),'near_solid_never_causes_negative_travel'],
 ['depth_lock_removed',t=>t.replace('wallLevel < (block:GetAttribute("RequiredLevel") or 1)','false'),'locked_depth_remains_a_barrier'],
 ['ownership_removed',t=>t.replace('rootPart:SetNetworkOwner(nil)','owner = "client"'),'tween_remains_server_owned'],
 ['stale_token_accepted',t=>t.replace('if profile.ownershipToken and player:GetAttribute("PunchOwnershipToken") ~= profile.ownershipToken then return nil end',''),'stale_ownership_cannot_lunge'],
];
const rejected=[];let assertions=0,oracleAssertions=0,compiled=0;
try{
 const text=setup+lunge+cases;const result=run('production-lunge',text);assert.equal(result.status,0,result.output);assertions=Number(result.output.match(/PASS (\d+)/)?.[1]);
 const before=run('fail-before',setup+oldLunge+cases);assert(before.status!==0&&before.output.includes('query_only_egg_cannot_shorten_real_producer'),before.output);
 const oracle=run('native-flow-oracle',oracleCases);assert.equal(oracle.status,0,oracle.output);oracleAssertions=Number(oracle.output.match(/PASS (\d+)/)?.[1]);
 for(const [name,mutate,expected]of mutations){const modified=mutate(text);assert.notEqual(modified,text);const result=run(name,modified);assert(result.status!==0&&result.output.includes(expected),name+result.output);rejected.push(name);}
 for(const [name,text]of [['server',source],...flow.steps.concat(flow.cleanup).filter(s=>s.tool==='execute_luau').map((s,i)=>['flow-'+i,s.args.code])]){
  const file=write(name,text);const result=spawnSync(compiler,['--null',file],{encoding:'utf8',timeout:15000});assert.equal(result.status,0,result.stdout+result.stderr);compiled++;
 }
}finally{for(const file of files)fs.unlinkSync(file);fs.rmdirSync(directory);}
console.log(JSON.stringify({ok:true,exactProductionAssertions:assertions,actualFlowOracleAssertions:oracleAssertions,baseline:'f10dfc5 fails on query-only egg',rejectedMutations:rejected,compiled},null,2));
