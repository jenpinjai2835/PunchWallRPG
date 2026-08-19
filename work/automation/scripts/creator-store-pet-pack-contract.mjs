import fs from "node:fs";
import path from "node:path";

const root = path.resolve(import.meta.dirname, "..", "..", "..");
const read = (...segments) => fs.readFileSync(path.join(root, ...segments), "utf8").replaceAll("\r\n", "\n");
const config = read("work", "punch-wall-rpg", "src", "shared", "GameConfig.lua");
const polish = read("work", "punch-wall-rpg", "src", "shared", "PolishConfig.lua");
const server = read("work", "punch-wall-rpg", "src", "server", "PunchWallBootstrap.server.lua");
const client = read("work", "punch-wall-rpg", "src", "client", "PunchWallClient.client.lua");
const installer = read("work", "automation", "scripts", "install-pet-pack-templates.mjs");
const manifest = read("work", "docs", "FREE_ASSET_MANIFEST.md");
const flow = JSON.parse(read("work", "automation", "flows", "creator-store-pet-pack-visuals.json"));
const gamePassFlow = JSON.parse(read("work", "automation", "flows", "premium-pet-gamepass-configuration.json"));

const mapping = [
  ["Forest Pup", "Dowodle", "Sanitized_ForestPupPet"],
  ["Miner Cat", "Catmouse", "Sanitized_MinerCatPet"],
  ["Crystal Fox", "Ocelot", "Sanitized_CrystalFoxPet"],
  ["Lava Dragon", "Mythic Autumn Dragon", "Sanitized_LavaDragonPet"],
  ["Secret Titan Golem", "Dark Guardian", "Sanitized_SecretTitanGolemPet"],
  ["Crimson Phoenix", "Enraged Phoenix", "Sanitized_CrimsonPhoenixPet"],
  ["Storm Wyvern", "Electra Hydra", "Sanitized_StormWyvernPet"],
  ["Celestial Guardian", "Mythic Radiant One", "Sanitized_CelestialGuardianPet"],
];
const includesMapping = (source) => mapping.every(([definition, model, template]) =>
  source.includes(definition) && source.includes(model) && source.includes(template));
const flowSource = JSON.stringify(flow);
const checks = {
  game_config_maps_all_eight_exact_models: mapping.every(([definition, model, template]) =>
    config.includes(`name = "${definition}"`) && config.includes(`templateName = "${template}"`) && config.includes(`packModel = "${model}"`)),
  premium_pet_gamepasses_match_creator_dashboard: config.includes('name = "Crimson Phoenix", rarity = "Premium", robux = 79, gamePassId = 1948233870')
    && config.includes('name = "Storm Wyvern", rarity = "Premium", robux = 169, gamePassId = 1948851823')
    && config.includes('name = "Celestial Guardian", rarity = "Premium", robux = 349, gamePassId = 1947471788')
    && JSON.stringify(gamePassFlow).includes("GetProductInfoAsync(pet.gamePassId,Enum.InfoType.GamePass)")
    && JSON.stringify(gamePassFlow).includes("without opening a purchase prompt")
    && client.includes("GetGamePassDisplayPrice")
    && client.includes("RegionalPriceResolved"),
  polish_uses_single_preloaded_pack_fail_closed: includesMapping(polish)
    && (polish.match(/assetId = 70715599928632/g) ?? []).length === 8
    && (polish.match(/preloadedOnly = true/g) ?? []).length >= 8,
  server_never_network_loads_preloaded_pack_fallback: server.includes("if candidate.preloadedOnly == true then")
    && server.includes('root:SetAttribute("ExternalTemplatePreloadedOnlyCount", preloadedOnlyCount)')
    && server.includes('root:SetAttribute("ExternalTemplatePreloadedOnlyFailClosed", true)'),
  runtime_preserves_authored_pack_details: client.includes('"CreatorStorePackMatchedV2"')
    && !client.includes('if definition.name == "Lava Dragon" then\n\t\t\tif descendant:IsA("Texture")'),
  installer_keeps_exact_eight_and_removes_raw_pack: includesMapping(installer)
    && installer.includes("rawPackRemoved=true")
    && installer.includes('d:IsA("LuaSourceContainer")')
    && installer.includes('CreatorStorePackAssetId","70715599928632"'),
  runtime_flow_checks_templates_inventory_premium_and_console: flowSource.includes("eight extracted pack templates are exact safe and bounded")
    && flowSource.includes("cards==8 and matched==8 and unsafe==0")
    && flowSource.includes("premium companions keep exact pack identities and non-overlapping formation")
    && flowSource.includes("post-stop console clean"),
  provenance_manifest_records_pack_and_mapping: manifest.includes("70715599928632") && includesMapping(manifest),
};

const failures = Object.entries(checks).filter(([, passed]) => !passed).map(([name]) => name);
const result = { ok: failures.length === 0, passed: Object.keys(checks).length - failures.length, total: Object.keys(checks).length, checks, failures };
console.log(JSON.stringify(result, null, 2));
if (!result.ok) process.exitCode = 1;
