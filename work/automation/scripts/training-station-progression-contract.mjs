import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";

const root = path.resolve(import.meta.dirname, "..", "..");
const read = (...parts) => fs.readFileSync(path.join(root, ...parts), "utf8");
const config = read("punch-wall-rpg", "src", "shared", "GameConfig.lua");
const persistence = read("punch-wall-rpg", "src", "server", "ProfilePersistence.lua");
const server = read("punch-wall-rpg", "src", "server", "PunchWallBootstrap.server.lua");
const client = read("punch-wall-rpg", "src", "client", "PunchWallClient.client.lua");
const flowText = read("automation", "flows", "training-station-progression.json");
const flow = JSON.parse(flowText);

const matrix = [
  ["rookie_bag", "Power Bag", "Rookie Bag", 0, 4],
  ["iron_dummy", "Iron Impact Dummy", "Iron Impact", 1500, 40],
  ["titan_reactor", "Titan Reactor", "Titan Reactor", 150000, 1200],
  ["celestial_core", "Celestial Power Core", "Celestial Core", 15000000, 50000],
];

const hasLabel = (label) => flow.steps.some((step) => step.label === label);
const stationLiteral = ([id, name, hudName, minPower, gain]) =>
  config.includes(`id = "${id}"`) && config.includes(`name = "${name}"`) &&
  config.includes(`hudName = "${hudName}"`) && config.includes(`minPower = ${minPower}`) && config.includes(`gain = ${gain}`);

const trainFunction = server.slice(server.indexOf("local function trainPlayer"), server.indexOf("stopTraining = function"));
const checks = [
  ["exact_four_station_matrix", matrix.every(stationLiteral) && (config.match(/id = "(?:rookie_bag|iron_dummy|titan_reactor|celestial_core)"/g) ?? []).length === 4],
  ["exact_global_timing_and_offline_policy", config.includes("TickSeconds = 1") && config.includes("OfflineEfficiency = 0.35") && config.includes("MaxOfflineSeconds = 8 * 60 * 60")],
  ["canonical_station_resolvers", config.includes("function GameConfig.TrainingStation(idOrName)") && config.includes("function GameConfig.TrainingStationForPower(power)") && config.includes("function GameConfig.TrainingOfflineGain(stationId, elapsedSeconds)")],
  ["persistent_selected_station", persistence.includes('TrainingStationId = { default = "rookie_bag", maxBytes = 64 }') && server.includes('TrainingStationId = "rookie_bag"') && server.includes('"TrainingStationId",')],
  ["profile_load_uses_persisted_station_offline_helper", server.includes("local trainingStation = GameConfig.TrainingStation(stats.TrainingStationId.Value)") && server.includes("GameConfig.TrainingOfflineGain(trainingStation.id, elapsed)")],
  ["server_derives_runtime_from_shared_matrix", server.includes("for _, definition in ipairs(GameConfig.Training.Stations) do") && server.includes("trainingRuntime.byId[config.id] = config")],
  ["world_has_unique_positions_and_authoritative_attributes", server.includes("rookie_bag = Vector3.new(-16, 4, 24)") && server.includes("celestial_core = Vector3.new(-70, 4, 24)") && server.includes('station:SetAttribute("RequiredPower", config.minPower)') && server.includes('station:SetAttribute("PowerPerSecond", config.gain)')],
  ["displayed_effective_power_authority_precedes_mutation", server.includes("local function trainingQualificationPower(player)") && server.includes("return GameConfig.EffectivePower(") && trainFunction.includes("local qualificationPower = trainingQualificationPower(player)") && trainFunction.indexOf("if qualificationPower < config.minPower") < trainFunction.indexOf("setActiveTrainingStation(player, config)")],
  ["starts_and_switches_without_free_tick", trainFunction.includes("gain = 0") && !trainFunction.includes("grantTrainingTick(") && trainFunction.includes("alreadyActive = true") && trainFunction.includes("switched = true")],
  ["single_scheduler_resolves_selected_station", server.includes('local stationId = tostring(statValue(player, "TrainingStationId"') && server.includes("local config = trainingRuntime.byId[stationId]") && server.includes("grantTrainingTick(player, config, false, due)") && !server.includes("grantTrainingTick(player, trainingConfigs[1]")],
  ["gain_is_capped_for_persistence", server.includes("ProfilePersistence.MaxAuthoritativeNumber - statValue(player, \"Power\", 0)") && server.includes("ProfilePersistence.MaxAuthoritativeNumber - leaderstats.Power.Value")],
  ["stop_clears_anchor_and_restores_movement", server.includes('player:SetAttribute("TrainingTickAnchor", nil)') && server.includes("setTrainingMovementLocked(player, false, selected)")],
  ["world_reset_preserves_eligible_training", server.includes("if activeStation and trainingQualificationPower(player) >= activeStation.minPower then") && server.includes('player:SetAttribute("TrainingTickAnchor", workspace:GetServerTimeNow())') && server.includes("stopTraining(player, \"world_reset_ineligible\")")],
  ["rebirth_stops_training_before_reset", server.includes('stopTraining(player, "rebirth")')],
  ["dynamic_client_station_hud_and_target", client.includes("GameConfig.TrainingStation(latestStats.TrainingStationId)") && client.includes("station.hudName or station.displayName") && client.includes('gui:SetAttribute("ActiveTrainingStationId"') && client.includes('gui:SetAttribute("TrainingAnimationTarget", activeStation.id)')],
  ["interaction_identity_and_radius_are_server_validated", server.includes("TRAINING_INTERACTION_DISTANCE = 18") && server.includes("requested.part and requested.part.Parent") && server.includes("requestedDistance <= TRAINING_INTERACTION_DISTANCE") && !server.includes("if requested and requested ~= config then config = nil end") && client.includes('target = gui:GetAttribute("ContextualActionTarget")')],
  ["runtime_covers_boundaries_rates_switch_reset_and_stop", hasLabel("last rejected raw Power lies immediately below the effective-Power station threshold") && hasLabel("first qualifying raw Power starts without free payout and earns the exact station rate") && flowText.includes("G.EffectivePower(first-1,1,0,0,1,0)<required") && flowText.includes("G.EffectivePower(first,1,0,0,1,0)>=required") && flowText.includes("before.qualificationPower<case[2]") && flowText.includes("normalized==case[3]") && flowText.includes("after.lastTickBatch==ticks") && hasLabel("same station is idempotent and active switch pays only the new station rate") && hasLabel("world reset preserves and reanchors active training without a duplicate payout") && hasLabel("stop clears movement lock and no server tick leaks afterward")],
  ["runtime_covers_offline_cap_growth_and_ui", hasLabel("selected station survives respawn and canonical offline gains use its rate and eight-hour cap") && hasLabel("training clamps at the persistence maximum while live growth stays under the gameplay opening") && hasLabel("switched station HUD and continuous animation display the authoritative station and rate")],
  ["runtime_covers_compact_celestial_and_client_loop_lifecycle", hasLabel("compact Celestial HUD keeps station and rate visible without restarting the animation loop") && hasLabel("record the single active client loop before stopping") && hasLabel("stop hides the training HUD without starting another client animation loop") && flowText.includes("CELESTIAL CORE") && flowText.includes("+50.0K POWER / SEC")],
  ["runtime_training_tick_drives_live_growth", server.includes('growthBodyHeight = character and character:GetAttribute("PowerGrowthBodyHeight")') && hasLabel("a real rookie station tick crosses the canonical Power growth boundary") && flowText.includes("after.directScale>before.directScale+.001") && flowText.includes("math.abs(actualMultiplier-expected)<=.003") && flowText.includes("after.growthBodyHeight<=maxHeight+.05") && flowText.includes("sourcePower==after.Power")],
  ["flow_is_fail_closed_and_non_mutating", flow.studioInstanceId === "6d29b2d4-41ab-41fb-838f-3dfd8727c725" && flow.studioName === "^PunchWallRPG_ManualPlaytest_20260818_FistAuraV10[.]rbxlx$" && hasLabel("runtime console clean") && hasLabel("post-stop console clean") && !flowText.includes(":ScaleTo(") && !flowText.includes("TrainingPayoutSerial',") && !flowText.includes("GameConfig.Training.Stations=")],
];

for (const [name, passed] of checks) assert.equal(passed, true, name);

console.log(JSON.stringify({
  ok: true,
  passed: checks.length,
  total: checks.length,
  stations: matrix.length,
  matrix: matrix.map(([id, name, hudName, minPower, gain]) => ({ id, name, hudName, minPower, gain })),
  checks: Object.fromEntries(checks),
}, null, 2));
