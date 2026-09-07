import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "..", "..");
const readNormalized = (...segments) => fs.readFileSync(path.join(root, ...segments), "utf8").replaceAll("\r\n", "\n");
const config = readNormalized("punch-wall-rpg", "src", "shared", "GameConfig.lua");
const client = readNormalized("punch-wall-rpg", "src", "client", "PunchWallClient.client.lua");
const server = readNormalized("punch-wall-rpg", "src", "server", "PunchWallBootstrap.server.lua");

let passed = 0;
const check = (condition, message) => {
  if (!condition) throw new Error(message);
  passed += 1;
};

const block = (name, nextName) => {
  const start = config.indexOf(`GameConfig.${name} = {`);
  const end = config.indexOf(`GameConfig.${nextName}`, start + 1);
  check(start >= 0 && end > start, `${name} catalog block must exist`);
  return config.slice(start, end);
};
const numberField = (line, field) => Number(line.match(new RegExp(`${field} = ([0-9.]+)`))?.[1]);

const fists = [...block("Fists", "PremiumFists").matchAll(/\{ name = "([^"]+)"[^\n]+/g)].map((match) => ({
  name: match[1],
  tier: numberField(match[0], "tier"),
  cost: numberField(match[0], "cost"),
  mult: numberField(match[0], "mult"),
  icon: match[0].match(/icon = "([^"]+)"/)?.[1],
}));
check(fists.length === 16, `expected 16 regular fists, found ${fists.length}`);
check(new Set(fists.map((item) => item.name)).size === fists.length, "regular fist names must be unique");
check(new Set(fists.map((item) => item.icon)).size === fists.length, "regular fist icon keys must be unique");
check(fists.every((item, index) => item.tier === index + 1), "regular fist tiers must be contiguous 1..16");
check(fists.every((item, index) => index === 0 || item.cost > fists[index - 1].cost), "regular fist costs must increase strictly");
check(fists.every((item, index) => index === 0 || item.mult > fists[index - 1].mult), "regular fist multipliers must increase strictly");
check(fists.at(-1).cost >= 1e14 && fists.at(-1).mult >= 2.8e6, "endgame fist must support trillion-coin/high-power play");
check(config.includes("local fistUnlockDepths = { 0, 1, 9, 17, 25, 31, 37, 43, 49, 55, 60, 64, 68, 71, 73, 75 }"), "fist unlock bands must span the complete 75-depth journey");

const pets = [...block("Pets", "PetInventoryArt").matchAll(/\{ name = "([^"]+)"[^\n]+/g)].map((match) => ({
  name: match[1],
  depth: numberField(match[0], "minDepth"),
  mult: numberField(match[0], "mult"),
  artKey: match[0].match(/artKey = "([^"]+)"/)?.[1],
  template: match[0].match(/templateName = "([^"]+)"/)?.[1],
}));
check(pets.length === 16, `expected 16 normal pets, found ${pets.length}`);
check(new Set(pets.map((item) => item.name)).size === pets.length, "normal pet names must be unique");
check(new Set(pets.map((item) => item.artKey)).size === pets.length, "normal pet art keys must be unique");
check(pets.every((item, index) => index === 0 || item.depth > pets[index - 1].depth), "pet unlock depths must increase strictly");
check(pets.every((item, index) => index === 0 || item.mult > pets[index - 1].mult), "pet multipliers must increase strictly");
check(pets[0].depth === 1 && pets.at(-1).depth === 75, "pet progression must span depth 1 through 75");
check(pets.at(-1).mult >= 48, "deepest pet must provide an endgame multiplier");
check(pets.every((item) => item.template?.startsWith("Sanitized_")), "every normal pet must use a sanitized visual template");
check(config.includes("GameConfig.MaxPetInventory = 150"), "expanded pet capacity must be 150");

check(client.includes('catalogScrollable = compactCards or desktopRows or (page == "Fists" and #products > 6)'), "compact and narrow desktop catalogs and the large fist catalog must activate scrolling");
check(client.includes('catalogScroll.Name = "ShopCatalogScroll"'), "every scrollable catalog must expose a named scroll viewport");
check(client.includes('"FixedReadableCardsV1"'), "shop must attest fixed readable cards");
check(client.includes("scrollCardHeight = compactCards and 112 or 154"), "shop cards must retain readable mobile and desktop row heights");
check(server.includes("local poolStart = math.max(1, #eligible - 1)"), "pet rolls must remain in the current depth band");
check(server.includes("depth >= (pet.minDepth or 1)"), "pet rolls must enforce depth unlocks on the server");
check(server.includes('reason = "depth_locked"') && server.includes('message = ("Reach Depth %d")'), "server must reject fist progression skips");
check(server.includes('local progressionDepth = math.max(0, math.floor(statValue(player, "Depth", 0)))'), "fist purchase gate must use tunnel Depth only");
check(!server.includes('math.floor(statValue(player, "WallLevel", 0)))\n\t)'), "WallLevel must not bypass fist depth locks");
check(client.includes('local playerProgressDepth = math.max(0, math.floor(tonumber(latestStats.Depth) or 0))'), "shop lock display must use tunnel Depth only");
check(server.includes("local firstDiscovery = not listContains(discovered, chosen.name)") && server.includes("if firstDiscovery then\n\t\taddStat(player, \"Luck\", chosen.luckGain)"), "duplicate or reclaimed pets must not farm Luck");

console.log(`Long-run content contract passed (${passed} checks, ${fists.length} fists, ${pets.length} normal pets).`);
