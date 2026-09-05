import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import {spawnSync} from 'node:child_process';
import {createHash} from 'node:crypto';

const sourceRootIndex=process.argv.indexOf('--source-root');
if(sourceRootIndex>=0&&!process.argv[sourceRootIndex+1])throw new Error('--source-root requires a repository path');
const repositoryRoot=sourceRootIndex>=0?path.resolve(process.argv[sourceRootIndex+1]):path.resolve(import.meta.dirname,'../../..');
const flowNames=['first-five-fist-presentation','item-matched-fist-visuals','fist-arm-alignment-qc'];
const flows=flowNames.map(name=>JSON.parse(fs.readFileSync(path.join(repositoryRoot,'work/automation/flows',name+'.json'),'utf8')));
const config=fs.readFileSync(path.join(repositoryRoot,'work/punch-wall-rpg/src/shared/GameConfig.lua'),'utf8');
const mcpClient=fs.readFileSync(path.join(repositoryRoot,'work/automation/scripts/studio_mcp_client.mjs'),'utf8');
const firstFive=['Starter Glove','Boxing Glove','Iron Knuckle','Thunder Fist','Titan Gauntlet'];
const codeOf=(flow)=>flow.steps.map(step=>step.args?.code||'').join('\n');
const stepOf=(flow,name)=>flow.steps.find(step=>step.saveAs===name);
const codeAt=(flow,name)=>stepOf(flow,name)?.args?.code||'';
const has=(source,tokens)=>tokens.every(token=>source.includes(token));
const section=(source,start,end)=>{const from=source.indexOf(start);if(from<0)return '';const to=source.indexOf(end,from+start.length);return source.slice(from,to<0?undefined:to);};
function stopsAfterConsole(flow){
 const playIndex=flow.steps.findLastIndex(step=>step.tool==='start_stop_play');
 const consoleIndex=flow.steps.findLastIndex(step=>step.type==='assertNoConsoleErrors');
 return playIndex>consoleIndex && flow.steps[playIndex]?.args?.is_start===false
  && flow.steps.slice(playIndex+1).every(step=>step.args?.datamodel_type==='Edit');
}
function evaluate(input){
 const [presentation,catalog,alignment]=input;
 const all=input.map(codeOf).join('\n');
 const parity=codeAt(presentation,'firstFiveParity'),matrix=codeAt(catalog,'itemMatchedFistMatrix'),wrist=codeAt(alignment,'alignmentMatrix'),respawn=codeAt(alignment,'respawnLifecycle');
 const aura=codeAt(catalog,'tierProminenceAuraMatrix'),motion=codeAt(catalog,'auraReducedMotion');
 const seeds=input.map(flow=>flow.steps.find(step=>step.args?.datamodel_type==='Server')?.args?.code||'');
 const clients=input.flatMap(flow=>flow.steps.filter(step=>step.args?.datamodel_type==='Client'));
 const verifierCodes=clients.map(step=>step.args.code).filter(code=>code.includes('local function verifyGeometry'));
 const checks={},failures={};
 const check=(name,value,note)=>{checks[name]=Boolean(value);if(!value)failures[name]=note;};
 check('unique_studio_selection_and_clean_stop_gates',input.every((flow,index)=>flow.name===flowNames[index]&&typeof flow.studioName==='string'&&flow.studioName.trim()!==''&&flow.steps.some(step=>step.type==='assertNoConsoleErrors'&&step.source==='console')&&flow.steps.some(step=>step.tool==='get_console_output'&&step.saveAs==='console')&&stopsAfterConsole(flow)&&flow.cleanup?.some(step=>step.tool==='start_stop_play'&&step.args?.is_start===false&&step.allowError===true))&&mcpClient.includes('Expected exactly one Studio matching'),'Current flows must select exactly one Studio, require clean console, and stop on success and failure.');
 check('no_cross_vm_executable_or_instance_state',!all.includes('shared.')&&!/Instance\.new\(['"](?:BindableFunction|BindableEvent|ModuleScript|Script|LocalScript|RemoteEvent|RemoteFunction)['"]\)|loadstring\(|getfenv\(|setfenv\(/.test(all),'Observation calls must be self-contained; cross-call evidence uses serializable attributes, never shared functions or Instance references.');
 check('complete_catalog_seed_is_authoritative',seeds.every(code=>has(code,["c:Invoke('Reset')","c:Invoke('SetStats'",'G.Fists','G.PremiumFists',"c:Invoke('BuyFist',def.name)","c:Invoke('GrantPremiumFist',def.name)",'assert(r.ok==true','OwnedFistsJSON','table.find(owned,def.name)','#all==#G.Fists+#G.PremiumFists'])),'All configured items must be authoritatively granted/bought and ownership asserted before client equips.');
 check('five_native_and_complete_catalog_counts_are_asserted',firstFive.every(name=>parity.includes("'"+name+"'")&&wrist.includes("'"+name+"'"))&&has(parity,['for _,name in ipairs(firstNames)','#rows==5'])&&has(wrist,['for _,name in ipairs(firstNames)','#rows==5'])&&has(matrix,['local definitions=G.AllFists()','#results==#definitions','nativeCount==5','importedCount==#definitions-5'])&&!/#(?:rows|results)==8|HeroGauntletV2/.test(all),'Exactly five canonical native items and the complete configured normal/premium catalog must be inspected.');
 check('real_equips_dispatch_once_before_bounded_observation',[parity,matrix,wrist].every(code=>{const equip=section(code,'local function equipped(def)','\nend\n');const observe=section(code,'local function untilReady','\nend\n');return (equip.match(/FireServer\(/g)||[]).length===1&&equip.indexOf('FireServer(')<equip.indexOf('return untilReady(')&&has(observe,['local deadline=os.clock()','os.clock()>=deadline','task.wait('])&&!/FireServer\(|:Invoke\(/.test(observe);}), 'Each matrix sends once per item then polls with a deadline; observation cannot retry actions.');
 check('actual_shape_material_color_and_anatomy_parity',has(parity,['part.Shape==expected.shape','part.Size/scale','relative.Position/scale','part.Material==expected.material','colorNear(part.Color,expected.color)','roles.ClosedKnuckle==4','roles.CurledFinger==4','roles.FoldedThumb==1','shopParts==inventoryParts and inventoryParts==equippedParts',"'SharedCatalogGeometry'","'SharedClosedFistV1'"]),'Geometry parity must compare real parts and material/color, not labels or attestation attributes alone.');
 check('all_native_verifiers_call_explicit_hazard_audit',verifierCodes.length>=5&&verifierCodes.every(code=>{const helper=section(code,'local function verifyVisualHazards','local function verifyGeometry');const geometry=section(code,'local function verifyGeometry','local function equipped');return helper!==''&&/verifyVisualHazards\(model,\s*preview/.test(geometry)&&['LuaSourceContainer','Tool','RemoteEvent','RemoteFunction','BindableEvent','BindableFunction','ClickDetector','ProximityPrompt','Sound','Humanoid','Animator','AnimationController','BodyMover','JointInstance','WeldConstraint','Constraint'].every(name=>helper.includes("'"+name+"'")||helper.includes('"'+name+'"'));}), 'Every native verifier must audit scripts, behavior, controllers, body movers and joints; only a valid equipped wrist WeldConstraint is allowed.');
 check('equipped_outer_models_are_audited',/verifyVisualHazards\(model,\s*false/.test(wrist)&&/verifyVisualHazards\(m,\s*false/.test(matrix),'Audit outer equipped models too so imported fallback or sibling behavior cannot bypass native-child inspection.');
 check('actual_final_bounds_weld_endpoints_and_current_rig',has(wrist,['for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do','part.Size*Vector3.new(x,y,z)*.5','actualBounds(model,hand.CFrame)','expectedLow,expectedHigh','weld.Part0==part and weld.Part1==hand','hand.Transparency<1','outerCount==1','RigType.Name',"a:Invoke('Punch')"]),'Current-rig checks must measure every actual part corner, verify hand weld endpoints and visible hand, and inspect punch/recovery; both-rig coverage needs two runs.');
 check('respawn_uses_tagged_serializable_identity_and_release',has(wrist,['SmashFistQALifecycleToken','SmashFistQALifecycleName','SmashFistQAOldCharacter','SmashFistQAOldModel'])&&has(respawn,['SmashFistQALifecycleToken','SmashFistQALifecycleName','SmashFistQAOldCharacter','SmashFistQAOldModel','workspace:GetDescendants()','EquippedFist.Value','copies==1'])&&!respawn.includes('shared.'),'Tag old objects with a serialized token, reacquire the new character, and prove tagged objects are absent and saved identity restored.');
 check('static_preview_and_resource_lifecycle_are_inspected',has(parity,['palm.CFrame==pose','viewport.CurrentCamera.CFrame==camera','invPalm.Parent','invPalm.CFrame==invPose'])&&has(codeAt(presentation,'previewLifecycle'),['current.models==baseline.models','current.parts==baseline.parts','offscreen first-five Shop models retained']),'Preview cameras/models must stay static and repeated menu cycles must not accumulate models or parts.');
 check('imported_fallback_and_aura_regression_are_preserved',has(matrix,["'SanitizedCreatorStoreMesh'","'CreatorStore_ArmoredClosedHeroFist'",'near(meshPart.Color,def.color)','meshPart.Material==def.material','parts<=28','anchored==0','collidable==0'])&&has(aura,['totalRate<=22','ok=#rows==#G.AllFists()'])&&has(motion,['fullBefore==2','reduced==0','restored==2','suppressed']),'Later normal/premium fists retain imported asset matching, noncollision/budget limits, and bounded motion-aware aura.');
 return {checks,failures};
}
const result=evaluate(flows);
const negativeControls=[];
function mutate(name,target,change){const candidate=structuredClone(flows);change(candidate);const observed=evaluate(candidate);const rejected=result.checks[target]===true&&observed.checks[target]===false;negativeControls.push({name,target,status:rejected?'REJECTED':'BLOCKED',positiveBaseline:result.checks[target]===true});return rejected;}
const mutationResults=[
 mutate('restart_after_console_gate','unique_studio_selection_and_clean_stop_gates',items=>items[0].steps.push({type:'call',tool:'start_stop_play',args:{is_start:true}})),
 mutate('remove_cleanup_stop','unique_studio_selection_and_clean_stop_gates',items=>items[0].cleanup=[]),
 mutate('truncate_catalog_to_eight','five_native_and_complete_catalog_counts_are_asserted',items=>{const s=stepOf(items[1],'itemMatchedFistMatrix');s.args.code=s.args.code.replace('#results==#definitions','#results==8');}),
 mutate('remove_actual_corner_audit','actual_final_bounds_weld_endpoints_and_current_rig',items=>{const s=stepOf(items[2],'alignmentMatrix');s.args.code=s.args.code.replace('for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do','for x=1,1 do for y=1,1 do for z=1,1 do');}),
 mutate('allow_appearance_mismatch','actual_shape_material_color_and_anatomy_parity',items=>{const s=stepOf(items[0],'firstFiveParity');s.args.code=s.args.code.replace('part.Material==expected.material','true');}),
 mutate('retry_equip_during_poll','real_equips_dispatch_once_before_bounded_observation',items=>{const s=stepOf(items[0],'firstFiveParity');s.args.code=s.args.code.replace('repeat local result=callback()','repeat remote:FireServer({action="EquipFist"}) local result=callback()');}),
];
result.checks.negative_flow_controls_reject_regressions=mutationResults.every(Boolean);
if(!mutationResults.every(Boolean))result.failures.negative_flow_controls_reject_regressions='A positive baseline is required and each mutation must fail its targeted guard.';

// Execute the exact flow hazard helper against class/ownership doubles. This does
// not render Roblox geometry, but catches a weakened predicate rather than merely
// detecting a missing word. The helper is supplied by the current flow owner.
const hazardHelpers=[...new Set(flows.flatMap(flow=>flow.steps.map(step=>step.args?.code||'')).map(code=>section(code,'local function verifyVisualHazards','local function verifyGeometry')).filter(Boolean))];
let hazardEvidence={status:'BLOCKED',reason:'required runtime hazard helper missing'};
if(hazardHelpers.length){
 const stub=String.raw`
local relations={Part={BasePart=true},MeshPart={BasePart=true},Motor6D={JointInstance=true},Weld={JointInstance=true},HingeConstraint={Constraint=true},AlignPosition={Constraint=true},WeldConstraint={Constraint=true},Script={LuaSourceContainer=true},LocalScript={LuaSourceContainer=true},ModuleScript={LuaSourceContainer=true},BodyVelocity={BodyMover=true},PointLight={Light=true}}
local function node(class,parent)
 local n={ClassName=class,Name=class,Parent=parent,Enabled=true,CanCollide=false,CanTouch=false,CanQuery=false,Massless=true,CastShadow=false,Anchored=false}
 function n:IsA(expected)return self.ClassName==expected or (relations[self.ClassName] or {})[expected]==true end
 function n:IsDescendantOf(root)local p=self.Parent while p do if p==root then return true end p=p.Parent end return false end
 return n
end
local function scenario(extra,preview,wrongEndpoint,disabled)
 local model=node('Model') local hand=node('Part') local part=node('Part',model) part.Anchored=preview
 local weld=node('WeldConstraint',part) weld.Part0=part weld.Part1=wrongEndpoint and node('Part') or hand weld.Enabled=not disabled
 local descendants={part} if not preview then table.insert(descendants,weld)end
 if extra then table.insert(descendants,node(extra,model))end
 function model:GetDescendants()return descendants end
 return model,hand
end
local passes,negative=0,0
local function expect(allowed,extra,preview,wrongEndpoint,disabled)
 local model,hand=scenario(extra,preview,wrongEndpoint,disabled)
 local ok=pcall(verifyVisualHazards,model,preview,hand)
 assert(ok==allowed,'hazard decision '..tostring(extra)..' preview='..tostring(preview)..' expected='..tostring(allowed))
 if allowed then passes+=1 else negative+=1 end
end
expect(true,nil,true) expect(true,nil,false)
for _,class in ipairs({'Attachment','ParticleEmitter','Trail','Beam','PointLight','Highlight'})do expect(true,class,false)end
for _,class in ipairs({'Script','LocalScript','ModuleScript','Tool','RemoteEvent','RemoteFunction','BindableEvent','BindableFunction','ClickDetector','ProximityPrompt','Sound','Humanoid','Animator','AnimationController','BodyVelocity','Motor6D','Weld','HingeConstraint','AlignPosition'})do expect(false,class,false)end
for _,class in ipairs({'ParticleEmitter','Trail','Beam','PointLight','Highlight','WeldConstraint'})do expect(false,class,true)end
expect(false,nil,false,true) expect(false,nil,false,false,true)
print('HAZARD_HELPER_PASS safe='..passes..' rejected='..negative)
`;
 const program=hazardHelpers.map(helper=>'do '+helper+'\n'+stub+' end').join('\n');
 const command=process.env.LUAU_COMMAND||'C:/Users/Jennarong Pinjai/AppData/Local/Temp/codex-luau-smash-0.737/luau.exe';
 const runLuau=(code)=>spawnSync(command,[],{input:'do '+code.replace(/\r?\n/g,' ')+' end\n',encoding:'utf8',maxBuffer:4*1024*1024});
 const run=runLuau(program);
 const markers=(run.stdout||'').split(/\r?\n/).filter(line=>line.startsWith('HAZARD_HELPER_PASS'));
 const positivePass=run.status===0&&!run.error&&markers.length===hazardHelpers.length;
 const helperMutations=[
  ['allow_body_movers',"not d:IsA('BodyMover')",'true'],
  ['allow_wrong_weld_endpoint',"assert(valid,'wrong wrist weld endpoints')","assert(true,'wrong wrist weld endpoints')"],
  ['allow_preview_particles',"not d:IsA('ParticleEmitter')",'true'],
 ];
 const mutationPrograms=[];
 let mutationsApplied=true;
 for(const helper of hazardHelpers)for(const [name,before,after]of helperMutations){
  const changed=helper.replace(before,after);
  mutationsApplied=mutationsApplied&&changed!==helper;
  mutationPrograms.push('do '+changed+' local function runHazardSuite() '+stub+' end local ok=pcall(runHazardSuite) assert(not ok,"weakened helper escaped '+name+'") print("HAZARD_MUTATION_REJECTED '+name+'") end');
 }
 const negativeRun=runLuau(mutationPrograms.join('\n'));
 const mutationMarkers=(negativeRun.stdout||'').split(/\r?\n/).filter(line=>line.startsWith('HAZARD_MUTATION_REJECTED'));
 const negativePass=positivePass&&mutationsApplied&&negativeRun.status===0&&!negativeRun.error&&mutationMarkers.length===mutationPrograms.length;
 const passed=positivePass&&negativePass;
 hazardEvidence={status:passed?'PASS':'BLOCKED',helpers:hazardHelpers.length,markers,mutationMarkers,...(!passed?{diagnostic:run.error?.message||negativeRun.error?.message||(run.stdout||'')+(run.stderr||'')+(negativeRun.stdout||'')+(negativeRun.stderr||'')}:{})};
}
result.checks.actual_hazard_helpers_reject_unsafe_descendants=hazardEvidence.status==='PASS';
if(hazardEvidence.status!=='PASS')result.failures.actual_hazard_helpers_reject_unsafe_descendants='Live flow hazard functions must pass safe cases and reject behavior, physics, effects, wrong endpoints, and disabled welds.';
const normalCount=(config.match(/GameConfig\.Fists = \{([\s\S]*?)\n\}/)?.[1].match(/name = "/g)||[]).length;
const premiumCount=(config.match(/GameConfig\.PremiumFists = \{([\s\S]*?)\n\}/)?.[1].match(/name = "/g)||[]).length;
const passed=Object.values(result.checks).filter(Boolean).length,total=Object.keys(result.checks).length;
console.log(JSON.stringify({ok:passed===total,passed,total,firstFiveCount:5,normalCount,premiumCount,catalogCount:normalCount+premiumCount,sourceRoot:repositoryRoot,flowHashes:Object.fromEntries(flows.map(flow=>[flow.name,createHash('sha256').update(JSON.stringify(flow)).digest('hex')])),studioRuntimeStatus:'BLOCKED_PENDING_SEPARATE_COORDINATOR_RUNTIME_EVIDENCE',...result,negativeControls,hazardEvidence,files:flowNames.map(name=>'work/automation/flows/'+name+'.json')},null,2));
if(passed!==total)process.exitCode=1;
