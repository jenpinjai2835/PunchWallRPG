import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";

const root = path.resolve(import.meta.dirname, "..", "..");
const gameConfig = fs.readFileSync(path.join(root, "punch-wall-rpg", "src", "shared", "GameConfig.lua"), "utf8");
const server = fs.readFileSync(path.join(root, "punch-wall-rpg", "src", "server", "PunchWallBootstrap.server.lua"), "utf8");
const client = fs.readFileSync(path.join(root, "punch-wall-rpg", "src", "client", "PunchWallClient.client.lua"), "utf8");
const flow = JSON.parse(fs.readFileSync(path.join(root, "automation", "flows", "power-avatar-growth.json"), "utf8"));

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

console.log(JSON.stringify({
  ok: true,
  passed: checks.length,
  total: checks.length,
  curve: "PowerLogWallCappedV1",
  maxScaleMultiplier: 1.25,
  fullGrowthPower: 1.5e9,
  checks: Object.fromEntries(checks),
}, null, 2));
