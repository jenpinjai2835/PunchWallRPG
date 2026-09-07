#!/usr/bin/env node
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../..');
const clientPath = 'work/punch-wall-rpg/src/client/PunchWallClient.client.lua';
const baselineIndex = process.argv.indexOf('--baseline');
const baseline = baselineIndex < 0 ? null : process.argv[baselineIndex + 1] || '05e15fa';
const old = baseline && spawnSync('git', ['show', `${baseline}:${clientPath}`], { cwd: root, encoding: 'utf8' });
if (old) assert.equal(old.status, 0, old.stderr);
const source = (old ? old.stdout : fs.readFileSync(path.join(root, clientPath), 'utf8')).replace(/\r\n?/g, '\n');
function between(start, end) {
  const from = source.indexOf(start), to = source.indexOf(end, from + start.length);
  assert.ok(from >= 0 && to > from, `Missing production boundary ${start}`);
  return source.slice(from, to);
}
const hasHelper = source.includes('function clientRuntime.SelectNearestDepthTarget(');
const producer = hasHelper
  ? between('function clientRuntime.SelectNearestDepthTarget(', '\nfunction clientRuntime.BindGameRoot(')
  : `function clientRuntime.SelectNearestDepthTarget(rootPart, nearestWall, nearestWallDistance)\n${between('\tlocal depthBlocks = clientRuntime.DepthBlocksFolder\n\tif depthBlocks then', '\n\t-- The invisible station hit volume')}\nreturn nearestWall, nearestWallDistance\nend\n`;
const params = between('clientRuntime.TargetDepthOverlap.FilterType =', '\ngui:SetAttribute("AmbientPulseRegistryMode"');
const cache = between('function clientRuntime.RefreshTargetFolderCache()', hasHelper ? '\nfunction clientRuntime.SelectNearestDepthTarget(' : '\nfunction clientRuntime.BindGameRoot(');
const tempRoot = os.tmpdir();
const candidates = [process.env.LUAU_COMMAND, ...fs.readdirSync(tempRoot).filter(name => name.startsWith('codex-luau-')).sort().reverse().map(name => path.join(tempRoot, name, process.platform === 'win32' ? 'luau.exe' : 'luau')), 'luau'];
const luau = candidates.find(candidate => candidate && spawnSync(candidate, ['--help'], { encoding: 'utf8' }).status === 0);
assert.ok(luau, 'BLOCKED: set LUAU_COMMAND to the Luau CLI');
const compiler = process.env.LUAU_COMPILE_COMMAND || path.join(path.dirname(luau), process.platform === 'win32' ? 'luau-compile.exe' : 'luau-compile');

const setup = `
local assertions=0
local function check(value,name) assert(value,name) assertions+=1 end
local Vector3,vm={},{}
function Vector3.new(x,y,z) return setmetatable({X=x,Y=y,Z=z},vm) end
vm.__sub=function(a,b) return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
vm.__mul=function(a,b) return Vector3.new(a.X*b,a.Y*b,a.Z*b) end
vm.__index=function(a,k)
 if k=='Magnitude' then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z) end
 if k=='Unit' then return a*(1/a.Magnitude) end
 if k=='Dot' then return function(a,b) return a.X*b.X+a.Y*b.Y+a.Z*b.Z end end
end
local attrs={}
local gui={SetAttribute=function(_,key,value) attrs[key]=value end}
local Enum={RaycastFilterType={Include='Include'}}
local gameRoot={}
local function folder(name,parent)
 return {Name=name,Parent=parent,GetChildren=function() error('forbidden_full_depth_scan') end,GetDescendants=function() error('forbidden_full_depth_scan') end}
end
local depth=folder('Depth Blocks',gameRoot)
function gameRoot:FindFirstChild(name) return name=='Depth Blocks' and depth or nil end
local clientRuntime={GameRoot=gameRoot,TargetDepthOverlap={},TargetFolderCacheRefreshCount=0}
${params}
${cache}
clientRuntime.RefreshTargetFolderCache()
local rootPart={Position=Vector3.new(0,0,0),CFrame={LookVector=Vector3.new(0,0,-1)}}
local reads={}
local function part(name,x,y,z,options)
 options=options or {}
 local item={Name=name,Position=Vector3.new(x,y,z),Parent=options.parent or depth,Extent=options.extent or 2,IsPart=options.isPart~=false,Depth=options.isDepth~=false,Broken=options.broken==true}
 function item:IsA() return self.IsPart end
 function item:IsDescendantOf(parent) return self.Parent==parent end
 function item:GetAttribute(key)
  reads[self]=(reads[self] or 0)+1
  if key=='IsDepthBlock' then return self.Depth end
  if key=='Broken' then return self.Broken end
 end
 return item
end
local world,queries={},{}
local override
local workspace={}
function workspace:GetPartBoundsInRadius(position,radius,overlap)
 check(overlap==clientRuntime.TargetDepthOverlap,'query_reuses_single_params_object')
 local found={}
 if override then found=override(position,radius,overlap) else
  for _,item in ipairs(world) do
   if item.Parent==overlap.FilterDescendantsInstances[1] and (item.Position-position).Magnitude<=radius+item.Extent then
    table.insert(found,item)
    if overlap.MaxParts>0 and #found>=overlap.MaxParts then break end
   end
  end
 end
 table.insert(queries,{radius=radius,count=#found})
 return found
end
${producer}
local function scan(existing,distance)
 queries={} reads={}
 return clientRuntime.SelectNearestDepthTarget(rootPart,existing,distance or 50)
end
`;

const fixtures = {
  unorderedCap: `${setup}
rootPart.Position=Vector3.new(-4,30.25,-113)
rootPart.CFrame.LookVector=Vector3.new(0,-1,0)
for i=1,400 do table.insert(world,part('Distant'..i,-4,18.25,-113)) end
local iron=part('DepthBlock_L020_C06_R06',-4,22.25,-113)
table.insert(world,iron)
local selected,distance=scan()
check(selected==iron and distance==8,'unordered_400_results_cannot_omit_nearest_iron')
check(#queries==1 and queries[1].radius==8 and queries[1].count==1,'near_target_stops_complete_small_radius_query')
check(clientRuntime.TargetDepthOverlap.MaxParts==0,'distance_selection_never_caps_unordered_spatial_results')
print('PASS '..assertions)
`,
  denseLocalOrder: `${setup}
for i=1,400 do table.insert(world,part('Behind'..i,0,0,2)) end
local closest=part('NearestFront',0,0,-1)
table.insert(world,closest)
local selected,distance=scan()
check(selected==closest and distance==1,'uncapped_dense_small_radius_never_omits_nearest_eligible_result')
check(#queries==1 and queries[1].count==401,'dense_region_returns_all_hits_without_artificial_result_cap')
print('PASS '..assertions)
`,
  completeness: `${setup}
local boundsOnly=part('LargeBoundsCenter12',0,0,-12,{extent=5})
local nearer=part('Center10',0,0,-10,{extent=.2})
world={boundsOnly,nearer}
local selected,distance=scan()
check(selected==nearer and distance==10,'first_nonempty_query_does_not_hide_unsearched_closer_center')
check(#queries==2 and queries[1].radius==8 and queries[2].radius==16,'expansion_requires_center_distance_proof')
check(reads[boundsOnly]==2 and reads[nearer]==2,'repeated_bounds_hits_are_evaluated_once')
check(attrs.TargetDepthCandidateCount==3 and attrs.TargetDepthUniqueCandidates==2,'raw_and_unique_workload_are_reported')
print('PASS '..assertions)
`,
  eligibility: `${setup}
local behind=part('Behind',0,0,1)
local broken=part('Broken',0,0,-2,{broken=true})
local nonDepth=part('Visual',0,0,-1,{isDepth=false})
local foreign=part('WrongFolder',0,0,-1,{parent={}})
local invalid=part('NotPart',0,0,-1,{isPart=false})
local valid=part('Eligible',3,0,-4)
override=function() return {behind,broken,nonDepth,foreign,invalid,valid} end
local selected,distance=scan()
check(selected==valid and distance==5,'broken_non_depth_nonpart_foreign_and_behind_results_are_rejected')
override=nil
local side=part('Side',5,0,0)
world={side}
check(scan()==side,'original_slightly_behind_facing_threshold_still_accepts_side_target')
rootPart.CFrame.LookVector=Vector3.new(math.sqrt(.99),0,-.1)
local boundary=part('FacingBoundary',0,0,5)
world={boundary}
check(scan()==nil,'facing_exactly_negative_point_one_is_rejected')
rootPart.CFrame.LookVector=Vector3.new(math.sqrt(1-.099*.099),0,-.099)
check(scan()==boundary,'facing_above_negative_point_one_is_accepted')
rootPart.CFrame.LookVector=Vector3.new(0,0,-1)
local coincident=part('Coincident',0,0,0)
world={coincident}
check(scan()==coincident,'coincident_center_uses_original_facing_one_without_unit_nan')
print('PASS '..assertions)
`,
  horizonAndExisting: `${setup}
local existing=part('OrdinaryWall',0,0,-6)
world={part('FartherDepth',0,0,-7)}
local selected,distance=scan(existing,6)
check(selected==existing and distance==6,'nearer_ordinary_wall_is_preserved')
world={part('CloserDepth',0,0,-5)}
check(scan(existing,6)==world[1],'nearer_depth_can_replace_ordinary_wall')
world={part('FarDepth',0,0,-30)}
selected,distance=scan()
check(selected==world[1] and distance==30 and #queries==4 and queries[4].radius==38,'far_target_uses_original_final_query_horizon')
world={part('BoundsTouchHorizon',0,0,-39)}
check(scan()==world[1] and queries[#queries].radius==38,'original_sphere_bounds_intersection_semantics_are_preserved')
world={part('BeyondHorizon',0,0,-41)}
check(scan()==nil and queries[#queries].radius==38,'query_never_expands_past_original_horizon')
world={}
selected,distance=scan()
check(selected==nil and distance==50 and #queries==4,'empty_search_preserves_no_target_and_distance')
check(attrs.TargetDepthSelectedDistance==-1,'empty_search_clears_stale_selection_telemetry')
print('PASS '..assertions)
`,
  staleCache: `${setup}
world={part('OldTarget',0,0,-5)}
check(scan()==world[1],'initial_cached_folder_is_usable')
depth.Parent=nil
check(scan()==nil and #queries==0,'detached_cached_folder_is_never_queried')
depth=folder('Depth Blocks',gameRoot)
world={part('NewTarget',0,0,-4)}
clientRuntime.RefreshTargetFolderCache()
check(scan()==world[1] and clientRuntime.TargetDepthOverlap.FilterDescendantsInstances[1]==depth,'replacement_folder_refreshes_original_shared_query_filter')
depth.Name='Old Name'
check(scan()==nil and #queries==0,'renamed_cached_folder_is_never_queried')
depth=nil clientRuntime.RefreshTargetFolderCache()
check(scan()==nil and #queries==0,'missing_depth_folder_has_zero_query_work')
rootPart=nil
check(scan()==nil and #queries==0,'missing_character_root_has_zero_query_work')
print('PASS '..assertions)
`,
  workload: `${setup}
for layer=1,75 do for row=1,6 do for column=1,12 do
 table.insert(world,part('Grid',-2+(column-6.5)*4,(row-.5)*4+.25,-37-(layer-1)*4))
end end end
rootPart.Position=Vector3.new(-2,3,-45)
local selected,distance=scan()
check(#world==5400 and selected and distance<8,'real_sized_grid_has_nearby_eligible_target')
check(#queries==1 and queries[1].radius==8 and queries[1].count<100,'near_grid_workload_avoids_full_5400_part_scan')
check(attrs.TargetDepthUniqueCandidates==queries[1].count,'near_grid_work_matches_actual_local_results')
rootPart.Position=Vector3.new(500,0,500)
scan()
check(#queries==4 and attrs.TargetDepthCandidateCount==0,'empty_far_region_uses_four_spatial_queries_without_part_enumeration')
print('PASS '..assertions)
`,
};

const temp = fs.mkdtempSync(path.join(tempRoot, 'smash-target-depth-contract-'));
const generated = [], results = {}, mutations = {};
try {
  for (const [name, fixture] of Object.entries(fixtures)) {
    if (baseline && name !== 'unorderedCap') continue;
    const file = path.join(temp, `${name}.luau`);
    fs.writeFileSync(file, fixture); generated.push(file);
    const result = spawnSync(luau, [file], { encoding: 'utf8', timeout: 15000 });
    const output = `${result.stdout || ''}${result.stderr || ''}`;
    if (baseline) {
      assert.ok(result.status !== 0 && output.includes('unordered_400_results_cannot_omit_nearest_iron'), `Wrong fail-before result: ${output}`);
      results[name] = { reproduced: 'unordered_400_results_cannot_omit_nearest_iron' };
    } else {
      assert.equal(result.status, 0, `${name}: ${output}`);
      results[name] = { passed: Number(output.match(/PASS (\d+)/)?.[1] || 0) };
    }
  }
  if (!baseline) {
    const controls = [
      ['restore_400_cap','denseLocalOrder',text=>text.replace('clientRuntime.TargetDepthOverlap.MaxParts = 0','clientRuntime.TargetDepthOverlap.MaxParts = 400'),'uncapped_dense_small_radius_never_omits_nearest_eligible_result'],
      ['stop_after_any_hit','completeness',text=>text.replace('if nearestWall and nearestWallDistance <= radius then break end','if nearestWall then break end'),'first_nonempty_query_does_not_hide_unsearched_closer_center'],
      ['include_facing_boundary','eligibility',text=>text.replace('facing > -0.1','facing >= -0.1'),'facing_exactly_negative_point_one_is_rejected'],
      ['include_broken_block','eligibility',text=>text.replace('and not block:GetAttribute("Broken")','and true'),'broken_non_depth_nonpart_foreign_and_behind_results_are_rejected'],
      ['include_foreign_block','eligibility',text=>text.replace('block:IsDescendantOf(depthBlocks)','true'),'broken_non_depth_nonpart_foreign_and_behind_results_are_rejected'],
      ['repeat_eligibility_work','completeness',text=>text.replace('if not seen[block] then','if true then'),'repeated_bounds_hits_are_evaluated_once'],
      ['scan_entire_depth_folder','workload',text=>text.replace('workspace:GetPartBoundsInRadius(rootPart.Position, radius, clientRuntime.TargetDepthOverlap)','depthBlocks:GetChildren()'),'forbidden_full_depth_scan'],
      ['extend_search_horizon','horizonAndExisting',text=>text.replace('ipairs({ 8, 16, 24, 38 })','ipairs({ 8, 16, 24, 60 })'),'far_target_uses_original_final_query_horizon'],
      ['replace_nearer_ordinary_wall','horizonAndExisting',text=>text.replace('distance < nearestWallDistance','distance < 50'),'nearer_ordinary_wall_is_preserved'],
      ['use_detached_depth_folder','staleCache',text=>text.replace('depthBlocks.Parent == clientRuntime.GameRoot','true'),'detached_cached_folder_is_never_queried'],
    ];
    for (const [name, fixtureName, mutate, expectedFailure] of controls) {
      const fixture = mutate(fixtures[fixtureName]);
      assert.notEqual(fixture, fixtures[fixtureName], `Missing mutation boundary: ${name}`);
      const file = path.join(temp, `mutation-${name}.luau`);
      fs.writeFileSync(file, fixture); generated.push(file);
      const result = spawnSync(luau, [file], { encoding: 'utf8', timeout: 15000 });
      const output = `${result.stdout || ''}${result.stderr || ''}`;
      assert.ok(result.status !== 0 && output.includes(expectedFailure), `Mutation survived or failed for wrong reason ${name}: ${output}`);
      mutations[name] = expectedFailure;
    }
    assert.ok(source.includes('nearestWall, nearestWallDistance = clientRuntime.SelectNearestDepthTarget(rootPart, nearestWall, nearestWallDistance)'), 'Heartbeat must consume both actual selector results');
    const compile = spawnSync(compiler, ['--null', path.join(root, clientPath)], { encoding: 'utf8', timeout: 15000 });
    assert.equal(compile.status, 0, `BLOCKED compile: ${compile.error || compile.stderr || compile.stdout}`);
  }
  console.log(JSON.stringify({ ok: true, source: baseline || 'current', luau, results, mutations, compiled: !baseline }, null, 2));
} finally {
  for (const file of generated) fs.unlinkSync(file);
  fs.rmdirSync(temp);
}
