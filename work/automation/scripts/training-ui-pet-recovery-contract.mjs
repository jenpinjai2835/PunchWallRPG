import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import { spawnSync } from "node:child_process";

const root = path.resolve(import.meta.dirname, "..", "..");
const read = (...parts) => fs.readFileSync(path.join(root, ...parts), "utf8");
const server = read("punch-wall-rpg", "src", "server", "PunchWallBootstrap.server.lua");
const client = read("punch-wall-rpg", "src", "client", "PunchWallClient.client.lua");
const inventory = read("punch-wall-rpg", "src", "client", "InventoryUI.lua");
const config = read("punch-wall-rpg", "src", "shared", "GameConfig.lua");
const polish = read("punch-wall-rpg", "src", "shared", "PolishConfig.lua");
const petFlow = read("automation", "flows", "creator-store-pet-pack-visuals.json");
const recoveryFlow = read("automation", "flows", "training-ui-pet-recovery.json");
const captureScript = read("automation", "scripts", "capture-training-ui-pet-recovery.mjs");
const finalArtifact = read("..", "outputs", "PunchWallRPGPlayable_v1_final.rbxlx");

const packTemplates = [
  ["Sanitized_ForestPupPet", "Dowodle", "Forest Pup"],
  ["Sanitized_MinerCatPet", "Catmouse", "Miner Cat"],
  ["Sanitized_CrystalFoxPet", "Ocelot", "Crystal Fox"],
  ["Sanitized_LavaDragonPet", "Mythic Autumn Dragon", "Lava Dragon"],
  ["Sanitized_SecretTitanGolemPet", "Dark Guardian", "Secret Titan Golem"],
  ["Sanitized_EnragedPhoenixPet", "Enraged Phoenix", "Thunder Roc"],
  ["Sanitized_ElectraHydraPet", "Electra Hydra", "Frost Hydra"],
  ["Sanitized_MythicRadiantOnePet", "Mythic Radiant One", "Solar Kirin"],
];
const premiumTemplates = [
  ["Sanitized_CrimsonPhoenixPet", "Crimson Phoenix", "86478691482535"],
  ["Sanitized_StormWyvernPet", "Storm Wyvern", "83562531232957"],
  ["Sanitized_CelestialGuardianPet", "Celestial Guardian", "121956330907081"],
];

const checks = [
  ["selected_training_station_validates_its_own_range", server.includes("requested.part and requested.part.Parent") && server.includes("requestedDistance <= TRAINING_INTERACTION_DISTANCE") && server.includes("config = requested") && !server.includes("if requested and requested ~= config then config = nil end")],
  ["training_unlock_uses_displayed_effective_power", server.includes("local function trainingQualificationPower(player)") && server.includes("return GameConfig.EffectivePower(") && server.includes("if qualificationPower < config.minPower then") && client.includes("latestStats.TrainingQualificationPower")],
  ["context_scan_only_compares_actionable_targets", client.includes("local nearestTraining") && client.includes("local nearestUse") && client.includes("clientRuntime.IsTrainingTarget(candidate)") && client.includes("clientRuntime.IsUseTarget(candidate)") && client.includes("nearestTrainingDistance <= nearestUseDistance + 5")],
  ["context_action_is_compact_two_line", client.includes('Name = "ActionTitle"') && client.includes('Name = "ActionDetail"') && client.includes('"PresentationVersion", "TwoLineCompactV2"') && client.includes("contextActionSize.MinSize = Vector2.new(196, 52)") && client.includes('"PhoneTwoLineCenterLane56V4"')],
  ["context_action_uses_dark_readable_panel", client.includes("button.BackgroundColor3 = Color3.fromRGB(10, 23, 31)") && client.includes("actionTitle.TextColor3 = actionAccent") && client.includes("contextActionDetail.TextColor3 = Color3.fromRGB(225, 240, 246)")],
  ["context_action_preserves_exact_station_identity", client.includes('button:SetAttribute("Target", targetName)') && client.includes('target = gui:GetAttribute("ContextualActionTarget")') && client.includes('"InvokeContextualAction"') && client.includes("requestAction(contextualAction)")],
  ["contextual_use_is_active_without_training_eligibility", client.includes('button.Active = button.Visible and (actionName ~= "Train" or trainingEligible)') && recoveryFlow.includes("nearest real non-training contextual Use stays active and follows the production path") && recoveryFlow.includes("result.detail==string.upper(result.target)")],
  ["inventory_compact_cards_reserve_art_from_tags", inventory.includes('"HorizontalPreviewV5"') && inventory.includes("cardRef.artFrame.Position = UDim2.fromOffset(8 / scale, 8 / scale)") && inventory.includes("local contentLeft = useCompact and 92 or 104") && inventory.includes("cardRef.rarity.Position = UDim2.fromOffset(contentLeft / scale, 46 / scale)") && recoveryFlow.includes("ItemRarity") && recoveryFlow.includes("EquippedBadge") && recoveryFlow.includes("LockedBadge")],
  ["inventory_compact_typography_is_readable_at_effective_scale", inventory.includes("math.ceil(14 / scale)") && inventory.includes("math.ceil(12 / scale)") && inventory.includes("cardRef.name.TextScaled = false") && recoveryFlow.includes("renderedFloor") && recoveryFlow.includes("readable(nameLabel,14)") && recoveryFlow.includes("readable(rarity,12)")],
  ["robux_prices_use_non_coin_palette", client.includes("Color3.fromRGB(105, 242, 169)") && client.includes('"RobuxGreen"') && client.includes('"CoinGold"') && client.includes('priceLabel:SetAttribute("CurrencyPalette"')],
  ["unsupported_rigs_use_equipped_fist_strike", client.includes("function companionRuntime.PerformTrainingFistStrike(target)") && client.includes('echo.Name = "Training Equipped Fist Strike"') && client.includes('"TrainingFistStrikeFallback"') && client.includes('tostring(latestStats.EquippedFist or "Starter Glove")')],
  ["fallback_is_visual_only_bounded_and_cleaned", client.includes("descendant.Anchored = true") && client.includes("descendant.CanCollide = false") && client.includes("math.min(descendant.Rate, 8)") && client.includes("if echo.Parent then echo:Destroy() end")],
  ["training_loop_uses_fallback_only_without_character_animation", client.includes("local characterAnimated = performPunchAnimation()") && client.includes("if not characterAnimated then") && client.includes("companionRuntime.PerformTrainingFistStrike(target)") && client.includes('"TrainingCharacterAnimationApplied"')],
  ["pet_pack_policy_has_exact_eight_preloaded_templates", packTemplates.every(([template, source, definition]) => polish.includes(`templateName = "${template}"`) && polish.includes(`sourceModel = "${source}"`) && polish.includes(`petDefinitionName = "${definition}"`)) && (polish.match(/preloadedOnly = true/g) ?? []).length === 8],
  ["premium_policy_restores_three_original_detailed_assets", premiumTemplates.every(([template, definition, asset]) => polish.includes(`templateName = "${template}"`) && polish.includes(`assetId = ${asset}`) && polish.includes(`petDefinitionName = "${definition}"`))],
  ["invisible_pet_rig_helpers_do_not_distort_visual_bounds", client.includes("function companionRuntime.NormalizeInvisibleRigBounds(model)") && client.includes('descendant.Name == "HumanoidRootPart"') && client.includes("companionRuntime.NormalizeInvisibleRigBounds(model)")],
  ["wide_wyvern_preview_prioritizes_creature_identity", client.includes('item.name == "Storm Wyvern" and 0.48') && client.includes('PreviewFitPadding')],
  ["pet_release_gate_requires_eight_pack_plus_three_premium_templates", server.includes('"PetVisualReadyTemplateCount"') && server.includes('"PetVisualRequiredTemplateCount"') && server.includes('"PetVisualReleasePolicy", "EightPackPlusThreeDetailedPremiumV3"') && server.includes("petTemplatePolicyCount == 11") && server.includes("readyPetTemplateCount == petTemplatePolicyCount") && server.includes("rejectedTemplateCount == 0")],
  ["pet_runtime_flow_checks_real_templates_and_no_unsafe_descendants", [...packTemplates, ...premiumTemplates].every(([template]) => petFlow.includes(template)) && petFlow.includes("found==11") && petFlow.includes("unsafe==0") && petFlow.includes("PetPackTemplateCount")],
  ["final_artifact_contains_all_eleven_pet_models", [...packTemplates, ...premiumTemplates].every(([template]) => finalArtifact.includes(template))],
  ["all_pet_definitions_reference_correct_template_families", packTemplates.every(([template, source, definition]) => config.includes(`name = "${definition}"`) && config.includes(`templateName = "${template}"`) && config.includes(`packModel = "${source}"`)) && premiumTemplates.every(([template, definition]) => config.includes(`name = "${definition}"`) && config.includes(`templateName = "${template}"`))],
  ["focused_flow_is_exact_and_covers_runtime_lifecycle", !JSON.parse(recoveryFlow).studioInstanceId && recoveryFlow.includes("PunchWallRPGPlayable_v1_final") && recoveryFlow.includes("below-threshold request never starts or switches training") && recoveryFlow.includes("reproduce public case where displayed effective Power exceeds Iron threshold") && recoveryFlow.includes("unsupported avatar visibly strikes with the equipped fist") && recoveryFlow.includes("compact Inventory shows all pet art without tag overlap") && recoveryFlow.includes("premium Shop uses green Robux pricing and original detailed pet previews") && recoveryFlow.includes("runtime console clean") && recoveryFlow.includes("post-stop console clean") && recoveryFlow.includes("restore simulator default")],
  ["capture_bundle_is_source_bound_and_has_four_distinct_views", captureScript.includes('"01_iphone17_training_action"') && captureScript.includes('"02_iphone17_inventory_pets"') && captureScript.includes('"03_iphone17_shop_premium"') && captureScript.includes('"04_iphone17_premium_companions"') && captureScript.includes('"work/automation/flows/training-ui-pet-recovery.json"') && captureScript.includes('"work/automation/scripts/training-ui-pet-recovery-contract.mjs"') && captureScript.includes("summary.runtimeSources") && captureScript.includes("summary.cleanup")],
];

for (const [name, passed] of checks) assert.equal(passed, true, name);

const normalize = s => s.replace(/\r\n?/g, '\n');
const source = normalize(client), serverSource = normalize(server);
function extract(text, start, end) {
  const a = text.indexOf(start), b = text.indexOf(end, a + start.length);
  assert.ok(a >= 0 && b > a, start); return text.slice(a, b);
}
const useProducer = extract(serverSource, 'local function nearestUseTarget(player)', '\nlocal function normalizedUiScale');
const contextualProducer = extract(source, '\tlocal nearestAction\n\tlocal nearestActionDistance = 44', '\n\tlocal focusedWall');
const targetKinds = extract(source, 'function clientRuntime.IsTrainingTarget(candidate)', '\nfunction clientRuntime.SetContextualAction');
const armoryConstructor = serverSource.split('\n').find(s => s.startsWith('local armoryNPCTrigger = makePart('));
const fistConstructor = serverSource.split('\n').find(s => s.includes('local stand = makePart(item.name .. " Stand", interactFolder'));
assert.ok(armoryConstructor && fistConstructor);
const candidates = [process.env.LUAU_COMMAND, ...fs.readdirSync(os.tmpdir()).filter(n => n.startsWith('codex-luau-')).sort().reverse().map(n => path.join(os.tmpdir(), n, process.platform === 'win32' ? 'luau.exe' : 'luau')), 'luau'];
const luau = candidates.find(p => p && spawnSync(p, ['--help']).status === 0);
assert.ok(luau, 'BLOCKED: Luau CLI required');
const compiler = process.env.LUAU_COMPILE_COMMAND || path.join(path.dirname(luau), process.platform === 'win32' ? 'luau-compile.exe' : 'luau-compile');
const geometryFixture = `
local count=0 local function check(v,label)assert(v,label)count+=1 end
local Vector3,V={},{}function Vector3.new(x,y,z)return setmetatable({X=x,Y=y,Z=z},V)end
V.__sub=function(a,b)return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end V.__add=function(a,b)return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z)end
V.__index=function(a,k)if k=='Magnitude'then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z)end end
local Color3={new=function()end,fromRGB=function()end}local Enum={Material={SmoothPlastic=1,Metal=2}}
local parts={} local function makePart(name,_,size,pos)
 local p={Name=name,Position=pos,Size=size,Parent=true,attrs={}}function p:IsA(v)return v=='BasePart'end
 function p:GetAttribute(k)return self.attrs[k]end function p:SetAttribute(k,v)self.attrs[k]=v end
 table.insert(parts,p)return p
end
${armoryConstructor}
armoryNPCTrigger:SetAttribute('InteractionMenu','Fists')
local fistPartsByName={}
local item={name='Crimson Vanguard Fist'}local index=1
${fistConstructor}
stand:SetAttribute('PremiumOnly',true)stand:SetAttribute('PurchaseConfigured',true)fistPartsByName[item.name]=stand
local shared={PunchWallArmoryNPCTrigger=armoryNPCTrigger}
local rootPart={Position=Vector3.new(0,0,0)}local function characterRoot()return rootPart end
local MOBILE_ACTION_DISTANCE=38
${useProducer}
local clientRuntime={WallsFolder={GetChildren=function()return {}end},InteractablesFolder={GetChildren=function()return parts end},SelectNearestDepthTarget=function(_,wall,distance)return wall,distance end}
${targetKinds}
local function clientSelect()
${contextualProducer}
return nearestAction and nearestAction.Name,nearestActionDistance
end
rootPart.Position=armoryNPCTrigger.Position+Vector3.new(-6,0,0)
local kind,name,distance=nearestUseTarget({})local clientName,clientDistance=clientSelect()
check(clientName=='Hero Armory Merchant Interaction' and clientDistance==6,'nominal_old_placement_selects_exact_armory_on_client')
check(kind=='Menu' and name=='Fists' and distance==6,'nominal_old_placement_selects_armory_on_server')
check((stand.Position-rootPart.Position).Magnitude>13,'source_authored_premium_stand_is_farther_at_old_nominal_point')
rootPart.Position=stand.Position+Vector3.new(0,0,1)
kind,name=nearestUseTarget({})clientName=clientSelect()
check(kind=='Fist' and name=='Crimson Vanguard Fist' and clientName=='Crimson Vanguard Fist Stand','actual_movement_near_stand_changes_both_production_selectors')
stand:SetAttribute('PurchaseConfigured',false)
kind,name=nearestUseTarget({})clientName=clientSelect()
check(kind=='Menu' and name=='Fists' and clientName=='Hero Armory Merchant Interaction','unconfigured_offer_is_not_an_actionable_competitor')
stand:SetAttribute('PurchaseConfigured',true)
rootPart.Position=Vector3.new(-66.5359039,4.3942165,-8.6931524)
kind,name=nearestUseTarget({})clientName=clientSelect()
check(kind=='Fist' and name=='Crimson Vanguard Fist' and clientName=='Crimson Vanguard Fist Stand','retained_actual_runtime_position_correctly_selects_crimson')
rootPart.Position=Vector3.new(-75,3.54,-8)
kind,name,distance=nearestUseTarget({})clientName=clientSelect()
check(kind=='Menu' and name=='Fists' and clientName=='Hero Armory Merchant Interaction','open_plaza_candidate_selects_exact_armory_in_both_producers')
check((stand.Position-rootPart.Position).Magnitude-distance>=2,'new_candidate_has_discriminatory_distance_margin')
print('PASS '..count)
`;
const useStep = JSON.parse(recoveryFlow).steps.find(s => s.label === 'nearest real non-training contextual Use stays active and follows the production path');
assert.ok(useStep.expectRegex.some(s => s.includes('serverOpened')), 'fresh server/menu result must gate the flow');
const useFixture = `
local count=0 local function check(v,label)assert(v,label)count+=1 end
local Vector3,V={},{}function Vector3.new(x,y,z)return setmetatable({X=x,Y=y,Z=z},V)end
V.__sub=function(a,b)return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end
V.__index=function(a,k)if k=='Magnitude'then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z)end end
local now=0 local mode='normal'local requests=0 local useAt local active=0 local sent=false local callback
local attrs={}local encoded={}local serial=0 local H={}
function H:JSONEncode(v)serial+=1 local key=tostring(serial)encoded[key]=v return key end
local root={Position=Vector3.new(-75,4,-14),Anchored=false,AssemblyLinearVelocity=Vector3.new(0,0,0)}
local target={Position=Vector3.new(-69,4,-14)}local b={Active=true,ActionTitle={Text='USE'},ActionDetail={Text=''}}
local g={PixelPerfectHeroCityHUD={ContextAction=b},GetAttribute=function(_,k)return attrs[k]end}
local remote={OnClientEvent={Connect=function(_,cb)callback=cb active+=1 local c={Connected=true}function c:Disconnect()if self.Connected then active-=1 self.Connected=false end callback=nil end return c end}}
local a={}
function a:Invoke(command)
 if command=='InvokeContextualAction'then requests+=1 useAt=now if mode=='invokeError'then error('invocation failed')end return true end
 if command=='Snapshot'then if mode=='snapshotError'then error('snapshot failed')end return {shopVisible=sent,shopPage=mode=='wrongPage'and 'Pets'or 'Fists'}end
 error('unexpected command '..tostring(command))
end
g.PunchWallClientAutomation=a
local game={Players={LocalPlayer={Character={FindFirstChild=function()return root end},PlayerGui={PunchWallHUD=g}}}}
function game:GetService(name)if name=='HttpService'then return H end if name=='ReplicatedStorage'then return {PunchWallEvents={Feedback=remote}}end error(name)end
local workspace={PunchWallRPG={Interactables={FindFirstChild=function()return target end}}}
local os={clock=function()return now end}
local function setTarget(name)attrs.ContextualActionTarget=name b.ActionDetail.Text=string.upper(name)end
local task={wait=function(dt)
 now+=dt
 if mode=='late'and now>=.35 then setTarget('Hero Armory Merchant Interaction')root.AssemblyLinearVelocity=Vector3.new(0,0,0)end
 if useAt and not sent and mode~='noReply'and now-useAt>=.1 then
  sent=true local reply={type='OpenMenu',target=mode=='wrongReply'and 'Pets'or 'Fists',tab=mode=='wrongReply'and 'Pets'or 'Fists'}
  if callback then callback(reply)if mode=='duplicate'then callback(reply)end end
 end
end}
local function run(which)
 now=0 mode=which requests=0 useAt=nil active=0 sent=false callback=nil
 attrs={ContextualActionName='Use'}root.Anchored=false root.AssemblyLinearVelocity=Vector3.new(0,0,0)
 setTarget((which=='wrongTarget'or which=='late')and 'Crimson Vanguard Fist Stand'or 'Hero Armory Merchant Interaction')
 if which=='moving'or which=='late'then root.AssemblyLinearVelocity=Vector3.new(1,0,0)end
 local function payload()
${useStep.args.code}
 end
 return pcall(payload)
end
local ok,result=run('normal')check(active==0 and ok and encoded[result].observerCleaned,'successful_server_observer_is_disconnected')
check(ok and encoded[result].serverOpened and requests==1,'exact_ready_armory_sends_one_use_and_proves_server_menu')
ok,result=run('late')check(ok and useAt>=.65-.00001,'request_waits_for_real_target_and_physics_stability')
ok=run('wrongTarget')check(not ok and requests==0 and active==0,'wrong_target_fails_before_any_contextual_request')
ok=run('moving')check(not ok and requests==0,'moving_character_cannot_satisfy_ready_fixture')
for _,which in ipairs({'wrongReply','noReply','wrongPage','duplicate','invokeError','snapshotError'})do
 ok=run(which)check(not ok and requests==1,which..'_does_not_fake_success')check(active==0,which..'_cleans_feedback_observer')
end
print('PASS '..count)
`;
const trainingCode=JSON.parse(recoveryFlow).steps.find(s=>s.label==='qualified player trains at the exact Iron rate').args.code;
const trainingFixture=`
local count=0 local function check(v,label)assert(v,label)count+=1 end
local now=0 local mode='delayed' local os={clock=function()return now end}local task={wait=function(dt)now+=dt end}
local a={Invoke=function()
 local ticks=mode=='delayed'and(now>=2 and 2 or 1)or(mode=='oneTick'and 1 or 2)
 return {active=mode~='inactive',stationId=mode=='wrongStation'and 'rookie_bag'or 'iron_dummy',gainPerSecond=mode=='wrongRate'and 20 or 40,Power=mode=='shortPower'and 1578 or(mode=='oneTick'and 1579 or 1499+40*ticks),sessionTickCount=ticks}
end}
local game={ServerStorage={PunchWallAutomation=a},GetService=function()return {JSONEncode=function(_,v)return v end}end}
local function run(which)now=0 mode=which local function payload()
${trainingCode}
end return payload()end
local r=run('delayed')check(r.ok and r.tickCount==2 and r.Power==1579 and now>=2,'two_actual_ticks_are_awaited_before_success')
r=run('oneTick')check(not r.ok and now>=6,'one_tick_with_high_power_cannot_fake_two_training_ticks')
r=run('shortPower')check(not r.ok,'two_ticks_require_full_two_tick_power_delta')
for _,which in ipairs({'inactive','wrongStation','wrongRate'})do r=run(which)check(not r.ok,which..'_training_rejected')end
print('PASS '..count)
`;
const parsedFlow=JSON.parse(recoveryFlow);
const rigCode=extract(parsedFlow.steps.find(s=>s.label==='exact eligible station starts through the production request path').args.code,"assert(not g:FindFirstChild('TrainingUnsupportedRigCleanup')",'local result={eligible=');
const rigCleanupCode=parsedFlow.cleanup.find(s=>s.label==='cleanup exact original unsupported shoulder before stopping play').args.code;
const rigFixture=`
local count=0 local function check(v,label)assert(v,label)count+=1 end
local p={}local g={}local nodes={}local character={}p.Character=character p.PlayerGui=g
function g:FindFirstChild(name)if name=='PunchWallHUD'then return self end return nodes[name]end
function p:FindFirstChild()return g end
local game={Players={LocalPlayer=p}}
local Instance={new=function()
 local obj={}
 function obj:Invoke()return self.OnInvoke()end
 function obj:Destroy()nodes[self.Name]=nil self.Parent=nil self.destroyed=true end
 return setmetatable(obj,{__newindex=function(t,k,v)rawset(t,k,v)if k=='Parent'then nodes[t.Name]=t end end})
end}
local function build(kind)
 local endpoint={Name=kind=='Motor6D'and 'Right Arm'or 'RightShoulderRigAttachment',Parent={Name='RightUpperArm'}}
 local joint={Name=kind=='Motor6D'and 'Right Shoulder'or 'RightShoulder',Parent=character,Part1=kind=='Motor6D'and endpoint or nil,Attachment1=kind=='AnimationConstraint'and endpoint or nil}
 function joint:IsA(k)return k==kind end function joint:IsDescendantOf(c)return self.Parent==c end
 function character:GetDescendants()return {joint}end return joint,endpoint
end
local function setup()
${rigCode}
end
local function cleanupPayload()
${rigCleanupCode}
end
for _,kind in ipairs({'Motor6D','AnimationConstraint'})do
 local joint,endpoint=build(kind)local originalName=joint.Name
 setup()local cleanup=nodes.TrainingUnsupportedRigCleanup
 check(cleanup~=nil and joint.Name=='QC Unsupported Shoulder','fixture_registers_cleanup_before_mutation_'..kind)
 check((kind=='Motor6D'and joint.Part1==nil)or(kind=='AnimationConstraint'and joint.Attachment1==nil),'actual_original_connection_detached_'..kind)
 local r=cleanup:Invoke()
 check(r.ok and r.restored==1 and joint.Name==originalName and (kind=='Motor6D'and joint.Part1==endpoint or kind=='AnimationConstraint'and joint.Attachment1==endpoint),'exact_original_reference_and_name_restored_'..kind)
 check(cleanup.destroyed and nodes.TrainingUnsupportedRigCleanup==nil,'cleanup_resource_destroyed_'..kind)
 check(cleanupPayload().alreadyClean==true,'post_success_cleanup_idempotent_'..kind)
 joint,endpoint=build(kind)setup()
 r=cleanupPayload()check(r.ok and joint.Name==originalName,'failure_path_cleanup_restores_original_'..kind)
 joint,endpoint=build(kind)setup()joint.Parent=nil
 local ok=pcall(cleanupPayload)check(not ok and nodes.TrainingUnsupportedRigCleanup==nil,'missing_original_cannot_report_restoration_'..kind)
 joint,endpoint=build(kind)setup()endpoint.Parent=nil
 ok=pcall(cleanupPayload)check(not ok,'destroyed_original_endpoint_cannot_report_restoration_'..kind)
end
print('PASS '..count)
`;
const placementCode=parsedFlow.steps.find(s=>s.label==='stop training and seed exact pet preview catalog').args.code;
assert.ok(!/\.Anchored\s*=/.test(placementCode),'placement cannot anchor the character to force stability');
const placementFixture=`
local count=0 local function check(v,label)assert(v,label)count+=1 end
local Vector3,V={},{}function Vector3.new(x,y,z)return setmetatable({X=x,Y=y,Z=z},V)end
V.__add=function(a,b)return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z)end V.__sub=function(a,b)return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end
V.__index=function(a,k)if k=='Magnitude'then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z)end end Vector3.zero=Vector3.new(0,0,0)
local CFrame,C={},{}function CFrame.new(p,yaw)return setmetatable({Position=p,yaw=yaw or 0},C)end
function CFrame.lookAt(p,t)local d=t-p return CFrame.new(p,math.atan2(-d.X,-d.Z))end
function C:PointToWorldSpace(v)local c,s=math.cos(self.yaw),math.sin(self.yaw)return self.Position+Vector3.new(c*v.X+s*v.Z,v.Y,-s*v.X+c*v.Z)end
function C:ToObjectSpace(other)local d=other.Position-self.Position local c,s=math.cos(self.yaw),math.sin(self.yaw)return CFrame.new(Vector3.new(c*d.X-s*d.Z,d.Y,s*d.X+c*d.Z),other.yaw-self.yaw)end
C.__index=C C.__mul=function(a,b)return CFrame.new(a:PointToWorldSpace(b.Position),a.yaw+b.yaw)end
local Enum={RaycastFilterType={Exclude='Exclude'}}local RaycastParams={new=function()return {}end}local OverlapParams={new=function()return {}end}
local now,mode,rig=0,'normal','R6' local os={clock=function()return now end}
local encoded={}local serial=0 local H={JSONEncode=function(_,v)serial+=1 local key=tostring(serial)encoded[key]=v return key end}local a={Invoke=function(_,cmd,params)return {ok=true,PetInventoryJSON=params and params.PetInventoryJSON}end}
local root local character local parts local desired local queries=0
local target={Name='Hero Armory Merchant Interaction',Position=Vector3.new(-69,4,-14)}
local competitor={Name='Crimson Vanguard Fist Stand',Position=Vector3.new(-62,3,-10),IsA=function()return true end,GetAttribute=function(_,k)return k=='PremiumOnly'or k=='PurchaseConfigured'end}
local folder={FindFirstChild=function()return target end,GetChildren=function()return {competitor}end}
local workspace={PunchWallRPG={Interactables=folder}}
function workspace:Raycast(origin,direction,params)
 assert(params.RespectCanCollide and params.FilterType=='Exclude'and params.FilterDescendantsInstances[1]==character,'floor_query_must_exclude_character_and_respect_collision')
 if mode=='noFloor'then return nil end
 return {Instance={Name='Armory Path',CanCollide=mode~='noncollidableFloor'},Position=Vector3.new(origin.X,.42,origin.Z),Normal=Vector3.new(0,mode=='slope'and .5 or 1,0)}
end
function workspace:GetPartBoundsInBox(cf,size,params)
 queries+=1 assert(params.MaxParts==0 and params.RespectCanCollide and params.FilterDescendantsInstances[1]==character,'uncapped_real_core_query')
 -- Independent plane/intersection oracle: a body below the floor or a pillar at the root cannot pass.
 if cf.Position.Y-size.Y*.5<.419 or mode=='obstacle'and math.abs(cf.Position.X+75)<1.5 and math.abs(cf.Position.Z+8)<1.5 then return {{Name='Physical Obstacle',CanCollide=true}}end
 return {}
end
local game={ServerStorage={PunchWallAutomation=a},GetService=function()return H end,Players={GetPlayers=function()return {{Character=character}}end}}
local function part(name,y,size)
 local p={Name=name,Size=size,CFrame=CFrame.new(Vector3.new(0,y,0)),IsA=function()return true end}table.insert(parts,p)return p
end
local task={wait=function(dt)
 now+=dt
 if mode=='moving'then root.AssemblyLinearVelocity=Vector3.new(1,0,0)end
 if mode=='drift'then root.Position=desired+Vector3.new(1,0,0)end
 if mode=='anchoredAfter'then root.Anchored=true end
 if mode=='competitor'then competitor.Position=root.Position end
end}
local function run(which,bodyRig)
 now=0 mode=which rig=bodyRig or 'R6'queries=0 parts={}desired=nil competitor.Position=Vector3.new(-62,3,-10)
 root=part('HumanoidRootPart',0,Vector3.new(2,2,1))root.Position=root.CFrame.Position root.Anchored=which=='anchoredBefore' root.AssemblyLinearVelocity=Vector3.zero
 part('Head',1.5,Vector3.new(2,1,1))part(rig=='R6'and 'Torso'or 'UpperTorso',0,Vector3.new(2,2,1))
 if rig=='R6' then part('Left Leg',-2,Vector3.new(1,2,1))part('Right Leg',-2,Vector3.new(1,2,1))
 else part('LowerTorso',-.8,Vector3.new(2,.8,1))part('LeftFoot',-3,Vector3.new(1,.8,1.5))part('RightFoot',-3,Vector3.new(1,.8,1.5))end
 part('Right Arm',-100,Vector3.new(1,2,1))part('Accessory',-200,Vector3.new(10,10,10))
 if which=='missingCore'then parts={root}end
 character={GetChildren=function()return parts end,FindFirstChild=function()return root end,GetPivot=function()return root.CFrame end}
 function character:PivotTo(cf)
  desired=cf.Position local old=root.CFrame local relative={}for i,p in ipairs(parts)do relative[i]=old:ToObjectSpace(p.CFrame)end
  for i,p in ipairs(parts)do p.CFrame=cf*relative[i]end root.Position=cf.Position
 end
 local function payload()
${placementCode}
 end
 local ok,result=pcall(payload)return ok,encoded[result]or result
end
for _,bodyRig in ipairs({'R6','R15'})do
 local ok,r=run('normal',bodyRig)check(ok,'normal_walkup_is_physically_valid_'..bodyRig)
 check(r.placement.stable and not root.Anchored and r.placement.margin>=2 and now>=.3,'unanchored_stable_discriminatory_placement_'..bodyRig)
 local expected=bodyRig=='R6'and 3.54 or 3.94
 check(math.abs(desired.Y-expected)<.00001 and desired.X==-75 and desired.Z==-8,'floor_height_uses_real_feet_excluding_arm_and_accessory_'..bodyRig)
 check(queries>10,'real_core_collision_is_rechecked_during_stability_'..bodyRig)
end
for _,which in ipairs({'noFloor','noncollidableFloor','slope','obstacle','missingCore','anchoredBefore','anchoredAfter','moving','drift','competitor'})do
 local ok=run(which)check(not ok,which..'_cannot_fake_valid_walkup')
end
print('PASS '..count)
`;
const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'smash-contextual-use-contract-')), generated = [];
let geometryAssertions = 0, useAssertions = 0, trainingAssertions = 0, rigAssertions=0, placementAssertions=0, compiledPayloads = 0;
const rejectedMutations=[];
function writeChunk(name, code) { const file = path.join(temp, name + '.luau'); generated.push(file); fs.writeFileSync(file, code); return file; }
try {
  const file = writeChunk('actual-client-and-server-selectors', geometryFixture);
  const result = spawnSync(luau, [file], {encoding:'utf8',timeout:15000});
  assert.equal(result.status, 0, result.stdout + result.stderr);
  geometryAssertions = Number(result.stdout.match(/PASS (\d+)/)?.[1]);
  const useResult=spawnSync(luau,[writeChunk('actual-use-payload',useFixture)],{encoding:'utf8',timeout:15000});
  assert.equal(useResult.status,0,useResult.stdout+useResult.stderr);useAssertions=Number(useResult.stdout.match(/PASS (\d+)/)?.[1]);
  const trainingResult=spawnSync(luau,[writeChunk('actual-training-readiness',trainingFixture)],{encoding:'utf8',timeout:15000});
  assert.equal(trainingResult.status,0,trainingResult.stdout+trainingResult.stderr);trainingAssertions=Number(trainingResult.stdout.match(/PASS (\d+)/)?.[1]);
  for(const [name,fixture]of [['rig',rigFixture],['placement',placementFixture]]){
    const r=spawnSync(luau,[writeChunk('actual-'+name,fixture)],{encoding:'utf8',timeout:15000});assert.equal(r.status,0,r.stdout+r.stderr);
    if(name==='rig')rigAssertions=Number(r.stdout.match(/PASS (\d+)/)?.[1]);else placementAssertions=Number(r.stdout.match(/PASS (\d+)/)?.[1]);
  }
  for(const [name,fixture,from,to,expected]of [
    ['drop_original_joint_name',rigFixture,'joint.Name=r.name','joint.Name="replacement"','exact_original_reference_and_name_restored_Motor6D'],
    ['do_not_restore_original_endpoint',rigFixture,'joint.Part1=r.endpoint','joint.Part1=nil','exact_original_reference_and_name_restored_Motor6D'],
    ['ignore_colliding_core',placementFixture,"assert(clear,'walk-up body overlaps", "assert(true,'walk-up body overlaps",'obstacle_cannot_fake_valid_walkup'],
    ['ignore_stability_motion',placementFixture,'root.AssemblyLinearVelocity.Magnitude<.5','true','moving_cannot_fake_valid_walkup'],
    ['ignore_competitor_margin',placementFixture,'margin>=2','true','competitor_cannot_fake_valid_walkup'],
  ]){
    let changed=fixture.replace(from,to);assert.notEqual(changed,fixture,name);
    if(name==='ignore_colliding_core')changed=changed.replace('not root.Anchored and clear and drift','not root.Anchored and true and drift');
    const r=spawnSync(luau,[writeChunk(name,changed)],{encoding:'utf8',timeout:15000});assert.ok(r.status!==0&&(r.stdout+r.stderr).includes(expected),name+': '+r.stdout+r.stderr);rejectedMutations.push(name);
  }
  for(const [name,from,to,expected]of [['ignore_actual_ticks','and (s.sessionTickCount or 0)>=2','and true','one_tick_with_high_power_cannot_fake_two_training_ticks'],['reduce_two_tick_power_gate','s.Power>=1579','s.Power>=1540','two_ticks_require_full_two_tick_power_delta']]){
    const changed=trainingFixture.replace(from,to);assert.notEqual(changed,trainingFixture,name);const r=spawnSync(luau,[writeChunk(name,changed)],{encoding:'utf8',timeout:15000});assert.ok(r.status!==0&&(r.stdout+r.stderr).includes(expected),name+': '+r.stdout+r.stderr);rejectedMutations.push(name);
  }
  for(const [name,mutate,expected]of [
    ['request_before_exact_ready',t=>t.replace("assert(result.ready,'exact Armory", "assert(true,'exact Armory"),'wrong_target_fails_before_any_contextual_request'],
    ['skip_stable_physics',t=>t.replace('if exact and settled then','if exact then'),'moving_character_cannot_satisfy_ready_fixture'],
    ['accept_wrong_server_menu',t=>t.replace("reply.target=='Fists' and reply.tab=='Fists'","true"),'wrongReply_does_not_fake_success'],
    ['accept_wrong_visible_page',t=>t.replace("snapshot.shopPage=='Fists'","true"),'wrongPage_does_not_fake_success'],
    ['leak_feedback_observer',t=>t.replace('watcher:Disconnect()','-- cleanup removed'),'successful_server_observer_is_disconnected'],
  ]){
    const changed=mutate(useFixture);assert.notEqual(changed,useFixture,name);
    const r=spawnSync(luau,[writeChunk(name,changed)],{encoding:'utf8',timeout:15000});
    assert.ok(r.status!==0&&(r.stdout+r.stderr).includes(expected),name+': '+r.stdout+r.stderr);rejectedMutations.push(name);
  }
  for (const [index, step] of [...parsedFlow.steps,...parsedFlow.cleanup].entries()) if (step.args?.code) {
    const code = writeChunk('flow-' + index, step.args.code);
    const r = spawnSync(compiler, ['--null', code], {encoding:'utf8',timeout:15000});
    assert.equal(r.status, 0, 'flow payload ' + index + ': ' + r.stderr); compiledPayloads++;
  }
} finally { for (const file of generated) fs.unlinkSync(file); fs.rmdirSync(temp); }

console.log(JSON.stringify({
  ok: true,
  passed: checks.length,
  total: checks.length,
  petTemplates: packTemplates.length + premiumTemplates.length,
  checks: Object.fromEntries(checks),
  geometryAssertions,
  useAssertions,
  trainingAssertions,
  rigAssertions,
  placementAssertions,
  rejectedMutations,
  compiledPayloads,
}, null, 2));
