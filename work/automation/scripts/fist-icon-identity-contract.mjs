#!/usr/bin/env node
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

// Source/geometry checks are intentionally separate from actual Studio runtime results.
const root=path.resolve(import.meta.dirname,'../..');
const read=(relative)=>fs.readFileSync(path.join(root,relative),'utf8');
const moduleOnly=process.argv.includes('--module-only');
const command=process.env.LUAU_COMMAND || 'C:/Users/Jennarong Pinjai/AppData/Local/Temp/codex-luau-smash-0.737/luau.exe';
const config=read('punch-wall-rpg/src/shared/GameConfig.lua');
const builder=read('punch-wall-rpg/src/shared/FistVisualBuilder.lua');
const client=read('punch-wall-rpg/src/client/PunchWallClient.client.lua');
const inventory=read('punch-wall-rpg/src/client/InventoryUI.lua');
const checks={};
function check(name,value){checks[name]=value===true;assert.equal(checks[name],true,name);}
const block=(name)=>config.match(new RegExp('GameConfig\\.'+name+' = \\{([\\s\\S]*?)\\n\\}'))?.[1] || '';
const normal=block('Fists'),premium=block('PremiumFists');
const icons=(text)=>[...text.matchAll(/icon = "([^"]+)"/g)].map(match=>match[1]);
const normalIcons=icons(normal),premiumIcons=icons(premium),allIcons=[...normalIcons,...premiumIcons];
check('configured_catalog_identities_are_unique',normalIcons.length===16 && premiumIcons.length===3 && new Set(allIcons).size===allIcons.length);
const flowNames=['first-five-fist-presentation','item-matched-fist-visuals','fist-arm-alignment-qc'];
const flows=flowNames.map(name=>JSON.parse(read('automation/flows/'+name+'.json')));
const allCode=flows.flatMap(flow=>flow.steps.map(step=>step.args?.code).filter(Boolean));
check('every_runtime_flow_has_stop_cleanup_and_console_gate',flows.every(flow=>flow.cleanup?.some(step=>step.tool==='start_stop_play'&&step.args?.is_start===false)&&flow.steps.some(step=>step.type==='assertNoConsoleErrors')));
const matrix=flows[1].steps.find(step=>step.saveAs==='itemMatchedFistMatrix').args.code;
const preparation=flows[1].steps.find(step=>step.args?.datamodel_type==='Server').args.code;
check('complete_catalog_seed_and_matrix_use_configuration',preparation.includes('for _,def in ipairs(G.Fists)')&&preparation.includes('for _,def in ipairs(G.PremiumFists)')&&preparation.includes('table.find(owned,def.name)')&&matrix.includes('local definitions=G.AllFists()')&&matrix.includes('#results==#definitions')&&matrix.includes('importedCount==#definitions-5'));
check('obsolete_eight_item_and_inactive_hero_system_assumptions_removed',!flows.some(flow=>/all eight|HeroGauntletV2|#results==8|#rows==8/.test(JSON.stringify(flow))));
const parity=flows[0].steps.find(step=>step.saveAs==='firstFiveParity').args.code;
const alignment=flows[2].steps.find(step=>step.saveAs==='alignmentMatrix').args.code;
check('parity_checks_actual_parts_and_static_preview_identity',parity.includes('part.Size/scale')&&parity.includes('relative.Position/scale')&&parity.includes('part.Material==expected.material')&&parity.includes('Shop preview rotates or rebuilds')&&parity.includes('same selected item recreated or rotated'));
check('alignment_checks_final_corners_weld_endpoints_and_punch',alignment.includes('for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do')&&alignment.includes('weld.Part0==part and weld.Part1==hand')&&alignment.includes('expectedLow,expectedHigh')&&alignment.includes("a:Invoke('Punch')"));
check('lifecycle_checks_offscreen_release_population_and_respawn',flows[0].steps.some(step=>step.saveAs==='previewLifecycle'&&step.args.code.includes('current.models==baseline.models')&&step.args.code.includes('offscreen first-five Shop models retained'))&&flows[2].steps.some(step=>step.saveAs==='respawnLifecycle'&&step.args.code.includes("workspace:GetDescendants()")&&step.args.code.includes("descendant:GetAttribute('SmashFistQAOldModel')~=token")&&step.args.code.includes("descendant:GetAttribute('SmashFistQAOldCharacter')~=token")&&!step.args.code.includes('shared.SmashFistQALifecycle')));
const harness=String.raw`
local V={} function V.new(x,y,z) return {X=x or 0,Y=y or 0,Z=z or 0} end V.zero=V.new()
local C={} local CM={} CM.__index=CM
function C.new(a,b,c) local p=type(a)=='table' and a or V.new(a,b,c) return setmetatable({Position=p,angle=0},CM) end
function C.Angles(x,y,z) assert(x==0 and y==0,'test expects planar part rotations') local c=C.new() c.angle=z return c end
function CM.__mul(a,b) local ca,sa=math.cos(a.angle),math.sin(a.angle) local p=b.Position return setmetatable({Position=V.new(a.Position.X+ca*p.X-sa*p.Y,a.Position.Y+sa*p.X+ca*p.Y,a.Position.Z+p.Z),angle=a.angle+b.angle},CM) end
C.identity=C.new()
local Colors={} local ColorMT={} ColorMT.__index=ColorMT
function Colors.fromRGB(r,g,b) return setmetatable({R=r/255,G=g/255,B=b/255},ColorMT) end
function Colors.new(r,g,b) return setmetatable({R=r,G=g,B=b},ColorMT) end
function ColorMT:Lerp(other,t) return Colors.new(self.R+(other.R-self.R)*t,self.G+(other.G-self.G)*t,self.B+(other.B-self.B)*t) end
local E={Material=setmetatable({},{__index=function(_,k)return k end}),PartType={Block='Block',Ball='Ball',Cylinder='Cylinder'}}
local function bounds(parts)
 local lo={math.huge,math.huge,math.huge} local hi={-math.huge,-math.huge,-math.huge}
 for _,p in ipairs(parts) do local size=p.size or p.Size local cf=p.cframe or p.CFrame local ca,sa=math.abs(math.cos(cf.angle)),math.abs(math.sin(cf.angle)) local half={(ca*size.X+sa*size.Y)/2,(sa*size.X+ca*size.Y)/2,size.Z/2} local center={cf.Position.X,cf.Position.Y,cf.Position.Z} for axis=1,3 do lo[axis]=math.min(lo[axis],center[axis]-half[axis]) hi[axis]=math.max(hi[axis],center[axis]+half[axis]) end end
 return lo,hi
end
local IM={} IM.__index=IM
function IM:SetAttribute(k,v) self.attributes[k]=v end function IM:GetAttribute(k) return self.attributes[k] end
function IM:IsA(k) return self.ClassName==k or self.ClassName=='Part' and k=='BasePart' end
function IM:GetChildren() return self.children end function IM:GetDescendants() local list={} local function walk(n) for _,c in ipairs(n.children)do table.insert(list,c) walk(c)end end walk(self) return list end
function IM:GetBoundingBox() local lo,hi=bounds(self:GetDescendants()) return C.new((lo[1]+hi[1])/2,(lo[2]+hi[2])/2,(lo[3]+hi[3])/2),V.new(hi[1]-lo[1],hi[2]-lo[2],hi[3]-lo[3]) end
function IM.__newindex(t,k,v) if k=='Parent' and v then table.insert(v.children,t) end rawset(t,k,v) end
local I={} function I.new(class) return setmetatable({ClassName=class,children={},attributes={}},IM) end
local env=setmetatable({Vector3=V,CFrame=C,Color3=Colors,Enum=E,Instance=I,game={GetService=function()return {} end}},{__index=getfenv()})
local loadBuilder=assert(loadstring(SOURCE)) setfenv(loadBuilder,env) local B=loadBuilder()
local loadDefinitions=assert(loadstring(DEFINITIONS)) setfenv(loadDefinitions,env) local definitions=loadDefinitions()
local fingerprints={}
for _,d in ipairs(definitions) do
 local spec=assert(B.GetCatalogSpec(d)) assert(#spec.parts>=12 and #spec.parts<=22,'budget '..d.name)
 local roles={} local names={} local fingerprint=''
 for _,p in ipairs(spec.parts)do assert(p.size.X>0 and p.size.Y>0 and p.size.Z>0,'positive geometry') assert(not names[p.name],'duplicate part name') names[p.name]=true roles[p.role]=(roles[p.role] or 0)+1 fingerprint..=string.format('%s:%.3f:%.3f:%.3f:%.3f:%.3f:%.3f;',p.shape,p.size.X,p.size.Y,p.size.Z,p.cframe.Position.X,p.cframe.Position.Y,p.cframe.Position.Z) end
 assert(roles.ClosedPalm==1 and roles.ClosedKnuckle==4 and roles.CurledFinger==4 and roles.FoldedThumb==1 and roles.WristCuff==1 and roles.BackhandPlate==1,'closed anatomy '..d.name)
 assert(not fingerprints[fingerprint],'identical geometry') fingerprints[fingerprint]=true
 local lo,hi=bounds(spec.parts) assert(lo[2]>=-0.11 and hi[2]<=1.6 and hi[1]-lo[1]<=1.5 and hi[3]-lo[3]<=1.3,'canonical dimensions '..d.name)
 local connected={[1]=true} local changed=true while changed do changed=false for i,p in ipairs(spec.parts) do if not connected[i] then local a,b=bounds({p}) for j,q in ipairs(spec.parts)do if connected[j]then local c,e=bounds({q}) local touch=true for axis=1,3 do if b[axis]<c[axis]-0.002 or e[axis]<a[axis]-0.002 then touch=false end end if touch then connected[i]=true changed=true break end end end end end end
 for i,p in ipairs(spec.parts)do assert(connected[i],'detached part '..d.name..':'..p.name)end
 local model=assert(B.BuildCatalogModel(d)) assert(model.WorldPivot.Position.X==0 and model.WorldPivot.Position.Y==0 and model.WorldPivot.Position.Z==0,'wrist pivot') assert(model:GetAttribute('FistVisualKey')==d.name and model:GetAttribute('VisualPartCount')==#spec.parts,'metadata')
 for _,p in ipairs(model:GetDescendants())do assert(p.ClassName=='Part' and p.Anchored and p.Massless and not p.CanCollide and not p.CanTouch and not p.CanQuery and p.CastShadow==false,'visual-only part')end
 assert(B.IsSanitizedVisual(model),'sanitizer compatibility')
 local again=assert(B.GetCatalogSpec(d)) assert(again.parts~=spec.parts and again.parts[1]~=spec.parts[1],'spec alias')
 print(string.format('CATALOG %s | parts=%d | bounds=%.4f,%.4f,%.4f | center=%.4f,%.4f,%.4f | minY=%.4f',d.name,#spec.parts,hi[1]-lo[1],hi[2]-lo[2],hi[3]-lo[3],(hi[1]+lo[1])/2,(hi[2]+lo[2])/2,(hi[3]+lo[3])/2,lo[2]))
end
assert(B.GetCatalogSpec(nil)==nil and B.BuildCatalogModel({name='Magma Breaker'})==nil,'unsupported fallback')
local wrong=table.clone(definitions[1]) wrong.icon='Wrong' assert(B.GetCatalogSpec(wrong)==nil,'identity mismatch')
print('CATALOG_CHECK_PASS firstFive=5 uniqueGeometry=5 anatomy=true connectedAABB=true wristOrigin=true visualOnly=true unsupported=true independentSpecs=true')
`;
const firstFive=normal.trim().split(/\r?\n/).slice(0,5).join('\n');
const geometryProgram=harness.replace('SOURCE',JSON.stringify(builder)).replace('DEFINITIONS',JSON.stringify('return {'+firstFive+'}'));
const syntaxProgram=allCode.map((code,index)=>'assert(loadstring('+JSON.stringify(code)+'),"flow Luau syntax '+index+'")').join(' ');
const output=spawnSync(command,[],{input:'do '+geometryProgram.replace(/\r?\n/g,' ')+' '+syntaxProgram+' print("FLOW_SYNTAX_PASS '+allCode.length+'") end\n',encoding:'utf8',maxBuffer:4*1024*1024});
if(output.error)throw new Error('Required Luau checks BLOCKED: '+output.error.message);
if(output.status!==0||!output.stdout.includes('CATALOG_CHECK_PASS')||!output.stdout.includes('FLOW_SYNTAX_PASS')){process.stderr.write(output.stdout||'');process.stderr.write(output.stderr||'');throw new Error('Required Luau geometry/syntax checks failed');}
check('actual_builder_pure_geometry_and_flow_luau_syntax',true);
if(!moduleOnly){
 check('equipped_consumer_uses_shared_catalog_geometry',client.includes('FistVisualBuilder.BuildCatalogModel(definition)')&&client.includes('"SharedCatalogGeometry"')&&client.includes('"CatalogWristOriginV1"'));
 check('shop_consumer_uses_static_catalog_viewport',client.includes('"FistCatalogPreview"')&&client.includes('"FistPreviewVisible"')&&client.includes('"FistPreviewReady"')&&client.includes('"RenderLoop", false'));
 check('inventory_uses_shared_fist_preview_callback',client.includes('BuildFistPreview =')&&inventory.includes('BuildFistPreview'));
}
console.log(JSON.stringify({ok:true,mode:moduleOnly?'module-and-flow-only':'integrated-source-and-module',passed:Object.keys(checks).length,normalCount:normalIcons.length,premiumCount:premiumIcons.length,flowLuauChunks:allCode.length,consumerWiringChecked:!moduleOnly,studioRuntimeStatus:'BLOCKED_AWAITING_COORDINATOR_INTEGRATION_RUN',geometryEvidence:output.stdout.split(/\r?\n/).filter(line=>line.startsWith('CATALOG ')||line.startsWith('CATALOG_CHECK_PASS')||line.startsWith('FLOW_SYNTAX_PASS')),checks},null,2));
