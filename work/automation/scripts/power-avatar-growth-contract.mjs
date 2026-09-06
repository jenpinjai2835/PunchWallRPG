import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import { spawnSync } from "node:child_process";

const root = path.resolve(import.meta.dirname, "..", "..");
const gameConfig = fs.readFileSync(path.join(root, "punch-wall-rpg", "src", "shared", "GameConfig.lua"), "utf8");
const server = fs.readFileSync(path.join(root, "punch-wall-rpg", "src", "server", "PunchWallBootstrap.server.lua"), "utf8");
const client = fs.readFileSync(path.join(root, "punch-wall-rpg", "src", "client", "PunchWallClient.client.lua"), "utf8");
const flow = JSON.parse(fs.readFileSync(path.join(root, "automation", "flows", "power-avatar-growth.json"), "utf8"));
const repositoryRoot = path.resolve(root, '..');
const originalFlowResult = spawnSync('git', ['show', '532e03c:work/automation/flows/power-avatar-growth.json'], {cwd:repositoryRoot,encoding:'utf8'});
assert.equal(originalFlowResult.status,0,originalFlowResult.stderr);
const originalFlow = JSON.parse(originalFlowResult.stdout);
const cameraLabel = 'maximum-size hero remains fully framed by the live camera';
const cameraStep = flow.steps.find(step=>step.label===cameraLabel);
const originalCameraStep = originalFlow.steps.find(step=>step.label===cameraLabel);
for(const expression of originalCameraStep.expectRegex)assert(cameraStep.expectRegex.includes(expression),'Retain original growth camera gate: '+expression);
assert(cameraStep.expectRegex.includes('"growthCameraContractValid"\\s*:\\s*true'),'Require unique top-level growth camera contract result');
assert(cameraStep.args.code.includes('growthCameraContractValid=valid'),'Publish the actual combined validity decision');
assert(!cameraStep.args.code.includes("assert(valid,'Power growth camera framing failed"),'Return the bounded result before runner validation can fail');
const acceptsCameraResult=result=>cameraStep.expectRegex.every(expression=>new RegExp(expression,'i').test(JSON.stringify(result)));
const goodCameraResult={valid:true,growthCameraContractValid:true,visibleCorners:8,totalCorners:8,subjectCurrent:true,inside:0,visualValid:true,sampledResult:{valid:true,visualValid:true}};
assert(acceptsCameraResult(goodCameraResult),'Complete growth camera result passes actual flow regex gates');
const failedCameraResult={...goodCameraResult,valid:false,growthCameraContractValid:false};
assert(originalCameraStep.expectRegex.every(expression=>new RegExp(expression,'i').test(JSON.stringify(failedCameraResult))),'Control exposes generic regex matching nested valid metrics');
assert(!acceptsCameraResult(failedCameraResult),'Nested valid metrics cannot hide a failed whole growth contract');
const missingCameraResult={...goodCameraResult};delete missingCameraResult.growthCameraContractValid;
assert(!acceptsCameraResult(missingCameraResult),'Missing combined validity marker fails closed');
const validity = text=>text.slice(text.indexOf('local valid=type(metrics)'),text.indexOf(' local result={valid=valid,'));
assert(validity(cameraStep.args.code).length>100,'Missing actual growth camera validity producer');
assert.equal(validity(cameraStep.args.code),validity(originalCameraStep.args.code),'Do not change any visual/subject/settle/geometry requirement');
assert.equal(flow.steps.length,originalFlow.steps.length,'Keep original growth sequence');
for(let i=0;i<flow.steps.length;i++)if(flow.steps[i].label!==cameraLabel)assert.deepEqual(flow.steps[i],originalFlow.steps[i]);
assert.deepEqual(flow.cleanup.slice(-originalFlow.cleanup.length),originalFlow.cleanup,'Keep original stop cleanup');
assert.equal(flow.cleanup.length-originalFlow.cleanup.length,4,'Four bounded diagnostic pages precede stop');
const longFlow = JSON.parse(fs.readFileSync(path.join(root,'automation/flows/camera-long-tunnel-regression.json'),'utf8'));
const longCameraCode=longFlow.steps.find(step=>step.label==='sample and freshly verify eighteen high-power tunnel punches').args.code;
assert.equal(cameraStep.args.code.slice(0,cameraStep.args.code.indexOf('\nlocal H=')),longCameraCode.slice(0,longCameraCode.indexOf('\nlocal H=')),'Growth uses the independently executed compact evidence producer');
for(const item of flow.cleanup.slice(0,4))assert(item.saveAs&&item.allowError===true&&item.args.datamodel_type==='Client'&&item.args.code.includes('#encoded<3900'),'Diagnostic retrieval must remain bounded and non-blocking for stop cleanup');

const checks = [
  ["shared_logarithmic_power_curve", gameConfig.includes('Version = "PowerLogWallCappedV1"') && gameConfig.includes("FullGrowthPower = 1.5e9") && gameConfig.includes("math.log(safePower / baseline)") && gameConfig.includes("function GameConfig.PlayerGrowthMultiplier(power)")],
  ["canonical_geometry_scale_function", gameConfig.includes("function GameConfig.PlayerGrowthModelScale(power, baseModelScale, baseBodyHeight)") && gameConfig.includes("targetModelScale + 0.002 < safeBaseScale * requestedMultiplier")],
  ["bounded_scale_contract", gameConfig.includes("MaxScaleMultiplier = 1.25") && gameConfig.includes("ShortestWallHeightStuds = 11") && gameConfig.includes("GameplayClearanceHeightStuds = 8") && gameConfig.includes("GameplayClearanceMarginStuds = 0.8")],
  ["power_not_wall_level_drives_growth", server.includes('if name == "Power" then shared.PunchWallPowerGrowth.Schedule(player) end') && !server.includes('if name == "WallLevel" then applyKaijuGrowth(player) end')],
  ["server_owned_coalesced_updates", server.includes("function shared.PunchWallPowerGrowth.Schedule(player)") && server.includes("shared.PunchWallPowerGrowth.pending[player]") && server.includes("task.delay(GameConfig.PlayerGrowth.UpdateDelaySeconds")],
  ["core_body_bounds_enforce_wall_cap", server.includes("function shared.PunchWallPowerGrowth.CoreBodyBounds(character)") && server.includes("GameConfig.PlayerGrowthModelScale(") && server.includes("afterBodyHeight > maximumHeight + 0.025") && server.includes('character:SetAttribute("PowerGrowthCappedByWall"')],
  ["feet_preserved_during_resize", server.includes("beforeBottom") && server.includes("afterBottom") && server.includes("footCorrection") && server.includes("character:PivotTo")],
  ["appearance_and_generation_safe_respawn", server.includes("player.CharacterAppearanceLoaded:Connect(function(character)") && server.includes('player:SetAttribute("PowerGrowthGeneration", generation)') && server.includes("player.Character == scheduledCharacter")],
  ["punch_and_network_ownership_serialized", server.includes('DepthActiveCollisionGroup") == "PunchingCharacters"') && server.includes("rootPart:SetNetworkOwner(nil)") && server.includes("rootPart:SetNetworkOwnershipAuto()") && server.includes("PunchOwnershipToken")],
  ["r6_r15_accessory_contract", server.includes("function shared.PunchWallPowerGrowth.RunRigContract()") && server.includes('name = "R6Default"') && server.includes('name = "R15Tall"') && server.includes('accessory.Name = "Oversized Accessory Contract"') && flow.steps.some((step) => step.label === "R6 R15 and tall R15 obey the core-body growth cap")],
  ["pet_scale_path_is_independent", server.includes('character:SetAttribute("PowerGrowthPetScalePolicy", "IndependentFixedTarget")') && client.includes("state.model:ScaleTo(state.baseModelScale * visualScale)") && !client.includes("PowerGrowthAppliedMultiplier")],
  ["runtime_matrix_covers_progression_punch_and_respawn", flow.steps.some((step) => step.label === "Power growth is monotonic grounded and shorter than every normal wall") && flow.steps.some((step) => step.label === "Power growth waits for punch ownership and restores physics") && flow.steps.some((step) => step.label === "Power growth reapplies after respawn")],
  ["runtime_pet_invariant_and_post_stop_console", flow.steps.some((step) => step.label === "pets do not grow when hero Power grows") && flow.steps.some((step) => step.label === "post-stop console clean")],
  ["runtime_downscale_restores_baseline", flow.steps.some((step) => step.label === "hero shrinks back at low Power and grows again independently of WallLevel") && JSON.stringify(flow).includes("low<=1.01") && JSON.stringify(flow).includes("restored>1.18")],
  ["runtime_camera_frames_maximum_body", flow.steps.some((step) => step.label === "maximum-size hero remains fully framed by the live camera") && JSON.stringify(flow).includes("visible==total") && JSON.stringify(flow).includes("camera.CameraSubject==humanoid") && JSON.stringify(flow).includes("metrics.inside==0")],
  ["runtime_reads_direct_model_scale", JSON.stringify(flow).includes("character:GetScale()") && JSON.stringify(flow).includes("directScaleValid")],
  ["runtime_proves_exact_pet_set_and_separation", JSON.stringify(flow).includes("exactIdentities") && flow.steps.some((step) => step.label === "maximum-size hero and pets remain separated inside the camera safe frame") && JSON.stringify(flow).includes("maxAvatarOverlap<=.35") && JSON.stringify(flow).includes("maxPairOverlap<=.15")],
  ["runtime_rebinds_camera_and_pets_after_respawn", flow.steps.some((step) => step.label === "camera and exact companion identities rebuild on the new character") && JSON.stringify(flow).includes("workspace.CurrentCamera.CameraSubject==humanoid")],
];

for (const [name, passed] of checks) assert.equal(passed, true, name);

// Execute the exact two runtime payloads: these controls exercise the oracle's
// readiness, measured geometry, native lifetime observation, and cleanup.
const record = flow.steps.find(s => s.label === "record pet size before hero growth").args.code;
const verify = flow.steps.find(s => s.label === "pets do not grow when hero Power grows").args.code;
const candidates = [process.env.LUAU_COMMAND, ...fs.readdirSync(os.tmpdir()).filter(n => n.startsWith("codex-luau-")).sort().reverse().map(n => path.join(os.tmpdir(), n, process.platform === "win32" ? "luau.exe" : "luau")), "luau"];
const luau = candidates.find(p => p && spawnSync(p, ["--help"]).status === 0);
assert.ok(luau, "BLOCKED: Luau CLI required for actual growth-flow oracle controls");
const compiler=process.env.LUAU_COMPILE_COMMAND||path.join(path.dirname(luau),process.platform==='win32'?'luau-compile.exe':'luau-compile');
const setup = `
local assertions=0 local function check(v,label)assert(v,label)assertions+=1 end
local now=0 local models={}local bindable local attributes={}local active=0 local serial=0 local encoded={}
local H={}
function H:JSONEncode(v)serial+=1 local key=tostring(serial)encoded[key]=v return key end
function H:JSONDecode(v)return encoded[v] or {}end
function H:GenerateGUID()serial+=1 return 'instance-'..serial end
local g={}
function g:SetAttribute(k,v)attributes[k]=v end function g:GetAttribute(k)return attributes[k]end
function g:FindFirstChild(name)if bindable and bindable.Name==name and bindable.Parent==g then return bindable end end
local character={GetAttribute=function(_,k)if k=='PowerGrowthAppliedMultiplier'then return 1.25 end if k=='PowerGrowthPetScalePolicy'then return 'IndependentFixedTarget'end end}
local folder={GetChildren=function()return models end}
local game={Players={LocalPlayer={Name='Player',PlayerGui={PunchWallHUD=g},Character=character}},GetService=function()return H end}
local workspace={FindFirstChild=function()return folder end}
local Instance={new=function()bindable={Destroy=function(self)self.Parent=nil end,Invoke=function(self)return self.OnInvoke()end}return bindable end}
local delayed=false local os={clock=function()return now end}
local task={wait=function(dt)now+=dt if delayed and now>=.15 then for _,m in ipairs(models)do m.attrs.SmoothFollowReady=true end end end}
local function model(name)
 local m={Parent=folder,PrimaryPart={},height=1.45,scale=.84,attrs={PetDefinitionName=name,CompanionTargetHeight=1.45,SmoothFollowReady=true},events={}}
 function m:IsA(v)return v=='Model'end function m:GetBoundingBox()return {},{Y=self.height}end function m:GetScale()return self.scale end
 function m:GetAttribute(k)return self.attrs[k]end function m:SetAttribute(k,v)self.attrs[k]=v end
 m.Destroying={Connect=function(_,callback)local c={alive=true,callback=callback}function c:Disconnect()if self.alive then active-=1 self.alive=false end end table.insert(m.events,c)active+=1 return c end}
 function m:Destroy()for _,c in ipairs(self.events)do if c.alive then c.callback()end end self.Parent=nil end
 return m
end
local function seed()
 now=0 delayed=false models={model('Forest Pup'),model('Miner Cat'),model('Crystal Fox')}attributes={}bindable=nil active=0
end
local function record()
${record}
end
local function verify()
${verify}
end
local function rejected(label)
 local ok=pcall(verify)check(not ok,label)check(active==0 and g:FindFirstChild('GrowthQCCleanup')==nil,label..'_observers_cleaned')
end
`;
const cases = `
seed()local baseline=H:JSONDecode(record())check(baseline.baselineReady and active==3,'baseline_has_three_initialized_observed_instances')
local result=H:JSONDecode(verify())check(result.valid and result.baselinePresent and result.identitiesStable,'unchanged_real_instances_and_sizes_pass')
check(result.rows[1].beforeHeight==1.45 and result.rows[1].beforeScale==.84,'measured_baseline_is_retained')
check(active==0 and g:FindFirstChild('GrowthQCCleanup')==nil and models[1]:GetAttribute('GrowthQCIdentity')==nil,'successful_check_cleans_observers_and_tags')
seed()delayed=true for _,m in ipairs(models)do m.attrs.SmoothFollowReady=false end
record()check(now>=.15,'baseline_waits_for_actual_ready_models')verify()
seed()models[1].height=0 local ok=pcall(record)check(not ok and active==0,'zero_geometry_never_becomes_a_baseline')
seed()record()attributes.GrowthQCBaselinesJSON=nil rejected('missing_baseline_is_not_reported_as_physical_growth_or_success')
seed()record()local old=models[1]local replacement=model('Forest Pup')replacement.attrs.GrowthQCIdentity=old.attrs.GrowthQCIdentity old:Destroy()models[1]=replacement
rejected('same_tag_clone_does_not_satisfy_instance_continuity')
seed()record()models[2].height+=.08 rejected('actual_height_growth_rejected')
seed()record()models[2].scale+=.03 rejected('actual_model_scale_growth_rejected')
seed()record()models[2].attrs.CompanionTargetHeight+=.1 rejected('changed_fixed_target_rejected')
seed()record()table.remove(models,3)rejected('missing_expected_companion_rejected')
print('PASS '..assertions)
`;
const temp = fs.mkdtempSync(path.join(os.tmpdir(), "smash-growth-flow-contract-")), files = [];
let executedAssertions = 0;
let compiledFlowSnippets=0;
const rejectedMutations = [];
function run(name, code) {
  const file = path.join(temp, name + ".luau"); files.push(file); fs.writeFileSync(file, code);
  const r = spawnSync(luau, [file], {encoding: "utf8", timeout: 15000});
  return {status:r.status, output:(r.stdout || "") + (r.stderr || "")};
}
try {
  const text = setup + cases, r = run("actual-payloads", text);
  assert.equal(r.status, 0, r.output); executedAssertions = Number(r.output.match(/PASS (\d+)/)?.[1]);
  const mutations = [
    ["skip_readiness", t => t.replace("if ready and #models==3 then break end", "if #models==3 then break end"), "baseline_waits_for_actual_ready_models"],
    ["ignore_destroyed_original", t => t.replace("identitiesStable=g:GetAttribute('GrowthQCModelDestroyed')==false", "identitiesStable=true"), "same_tag_clone_does_not_satisfy_instance_continuity"],
    ["ignore_measured_growth", t => t.replace("hasBaseline and m:GetScale()<=b.scale+.012 and size.Y<=b.height+.035", "hasBaseline"), "actual_height_growth_rejected"],
    ["leak_lifetime_observers", t => t.replace("for _,connection in ipairs(connections)do connection:Disconnect()end", "-- removed cleanup"), "successful_check_cleans_observers_and_tags"],
  ];
  for (const [name, mutate, expected] of mutations) {
    const altered = mutate(text); assert.notEqual(altered, text, name);
    const result = run(name, altered);
    assert.ok(result.status !== 0 && result.output.includes(expected), name + ": " + result.output);
    rejectedMutations.push(name);
  }
  for(const [index,step] of [...flow.steps,...flow.cleanup].entries())if(step.tool==='execute_luau'){
    const file=path.join(temp,`growth-flow-${index}.luau`);files.push(file);fs.writeFileSync(file,step.args.code);
    const result=spawnSync(compiler,['--null',file],{encoding:'utf8',timeout:15000});
    assert.equal(result.status,0,`${step.label}: ${result.stdout}${result.stderr}`);compiledFlowSnippets++;
  }
} finally { for (const file of files) fs.unlinkSync(file); fs.rmdirSync(temp); }

console.log(JSON.stringify({
  ok: true,
  passed: checks.length,
  total: checks.length,
  curve: "PowerLogWallCappedV1",
  maxScaleMultiplier: 1.25,
  fullGrowthPower: 1.5e9,
  checks: Object.fromEntries(checks),
  actualFlowAssertions: executedAssertions,
  compiledFlowSnippets,
  rejectedMutations,
}, null, 2));
