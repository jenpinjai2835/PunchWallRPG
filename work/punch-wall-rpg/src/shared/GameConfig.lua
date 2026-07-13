local GameConfig = {}

GameConfig.DataVersion = 3
GameConfig.MaxCritChance = 65
GameConfig.MaxPetInventory = 60
GameConfig.MaxEquippedPets = 3
GameConfig.RegularWallRespawnSeconds = 8
GameConfig.BossRespawnSeconds = 20

GameConfig.WallOrder = {
	"Brick Wall",
	"Concrete Wall",
	"Iron Wall",
	"Crystal Wall",
	"Lava Wall",
	"Cyber Gate",
}

GameConfig.WallXP = {
	["Brick Wall"] = 32,
	["Concrete Wall"] = 95,
	["Iron Wall"] = 260,
	["Crystal Wall"] = 720,
	["Lava Wall"] = 1850,
	["Cyber Gate"] = 5200,
	["Titan Server Wall"] = 12000,
}

GameConfig.DepthRanks = {
	{ depth = 0, name = "ROOKIE" },
	{ depth = 10, name = "STREET HERO" },
	{ depth = 20, name = "WALL BREAKER" },
	{ depth = 35, name = "CITY VANGUARD" },
	{ depth = 50, name = "TITAN FIST" },
	{ depth = 65, name = "ABYSS LEGEND" },
}

function GameConfig.RankForDepth(depth)
	depth = math.max(0, math.floor(tonumber(depth) or 0))
	local rank = GameConfig.DepthRanks[1].name
	for _, definition in ipairs(GameConfig.DepthRanks) do
		if depth >= definition.depth then
			rank = definition.name
		end
	end
	return rank
end

function GameConfig.XPForLevel(level)
	level = math.max(1, math.floor(tonumber(level) or 1))
	return math.floor(18 + level * 7 + level ^ 1.38 * 2.4)
end

GameConfig.Fists = {
	{ name = "Starter Glove", displayName = "Starter Fist", tier = 1, style = "Starter", icon = "StarterFist", cost = 0, mult = 1, speed = 0, color = Color3.fromRGB(166, 54, 45), accent = Color3.fromRGB(255, 197, 45), material = Enum.Material.Leather },
	{ name = "Boxing Glove", displayName = "Street Boxing Fist", tier = 2, style = "Boxing", icon = "BoxingFist", cost = 180, mult = 1.8, speed = 0.2, color = Color3.fromRGB(191, 47, 39), accent = Color3.fromRGB(239, 216, 187), material = Enum.Material.Leather },
	{ name = "Iron Knuckle", displayName = "Iron Crusher Fist", tier = 3, style = "Iron", icon = "IronFist", cost = 1100, mult = 4.5, speed = 0.35, color = Color3.fromRGB(92, 101, 108), accent = Color3.fromRGB(196, 208, 214), material = Enum.Material.DiamondPlate },
	{ name = "Thunder Fist", displayName = "Thunder Core Fist", tier = 4, style = "Thunder", icon = "ThunderFist", cost = 8200, mult = 13, speed = 0.7, color = Color3.fromRGB(37, 108, 180), accent = Color3.fromRGB(72, 225, 255), material = Enum.Material.Metal },
	{ name = "Titan Gauntlet", displayName = "Titan Siege Fist", tier = 5, style = "Titan", icon = "TitanFist", cost = 90000, mult = 45, speed = 1.2, color = Color3.fromRGB(29, 33, 39), accent = Color3.fromRGB(244, 165, 45), material = Enum.Material.CorrodedMetal },
}

-- Uploaded from the supplied transparent shop-art layers. Non-transparent frame
-- exports are intentionally not used as UI backgrounds because they contain a checkerboard.
GameConfig.ShopArt = {
	StarterGlove = "rbxassetid://102627532847126",
	TitanGlove = "rbxassetid://97597870943935",
	ChampionGlove = "rbxassetid://123648606849968",
	CoinBoost = "rbxassetid://124043136175492",
	SpeedBoost = "rbxassetid://110700899933892",
	DamageBoost = "rbxassetid://140286541155994",
}

function GameConfig.FistDefinition(name)
	for _, fist in ipairs(GameConfig.Fists) do
		if fist.name == name then return fist end
	end
	return GameConfig.Fists[1]
end

GameConfig.Pets = {
	{ name = "Brick Pup", rarity = "Common", baseWeight = 5500, mult = 0.15, luckGain = 0.03, color = Color3.fromRGB(174, 116, 88) },
	{ name = "Miner Cat", rarity = "Rare", baseWeight = 3000, mult = 0.35, luckGain = 0.08, color = Color3.fromRGB(80, 151, 211) },
	{ name = "Crystal Fox", rarity = "Epic", baseWeight = 1100, mult = 0.85, luckGain = 0.16, color = Color3.fromRGB(168, 103, 219) },
	{ name = "Lava Dragon", rarity = "Legendary", baseWeight = 350, mult = 1.7, luckGain = 0.28, color = Color3.fromRGB(238, 142, 48) },
	{ name = "Secret Titan Golem", rarity = "Secret", baseWeight = 50, mult = 4.5, luckGain = 0.5, color = Color3.fromRGB(225, 59, 65) },
}

GameConfig.RarityLuckPower = {
	Common = -0.55,
	Rare = 0.18,
	Epic = 0.48,
	Legendary = 0.78,
	Secret = 1.05,
}

function GameConfig.PetWeight(pet, luck)
	luck = math.max(1, tonumber(luck) or 1)
	local exponent = GameConfig.RarityLuckPower[pet.rarity] or 0
	return pet.baseWeight * luck ^ exponent
end

function GameConfig.PetChances(luck)
	local total = 0
	local weights = {}
	for _, pet in ipairs(GameConfig.Pets) do
		local weight = GameConfig.PetWeight(pet, luck)
		weights[pet.name] = weight
		total += weight
	end
	local chances = {}
	for _, pet in ipairs(GameConfig.Pets) do
		chances[pet.name] = weights[pet.name] / total
	end
	return chances
end

function GameConfig.ContributionReward(baseReward, share)
	baseReward = math.max(0, tonumber(baseReward) or 0)
	share = math.clamp(tonumber(share) or 0, 0, 1)
	return math.max(baseReward > 0 and 1 or 0, math.floor(baseReward * (0.5 + share * 0.5)))
end

GameConfig.Tutorial = {
	[1] = { title = "Train Power", detail = "Hit the Power Bag once", target = "Power Bag" },
	[2] = { title = "Enter The Depth Run", detail = "Break a front block and walk through the hole", target = "Depth Course Entrance" },
	[3] = { title = "Push Deeper", detail = "Break blocks to reach stronger material tiers", target = "Depth Course Entrance" },
	[4] = { title = "Upgrade Your Fist", detail = "Buy the Street Boxing Fist at Hero HQ", target = "Boxing Glove Stand" },
	[5] = { title = "Recruit A Sidekick", detail = "Open one Sidekick Capsule", target = "Pet Egg Machine" },
	[6] = { title = "Reach Titan HQ", detail = "Clear Depth 30 and damage the Titan", target = "Titan Server Wall" },
	[7] = { title = "Rebirth", detail = "Reach Level 55 and activate the Evac Portal", target = "Rebirth Shrine" },
	[8] = { title = "City Hero", detail = "Tutorial complete. Keep building your hero power.", target = "" },
}

GameConfig.Rewards = {
	DailyCoins = 600,
	QuestBreakTarget = 10,
	QuestCoins = 850,
	PlaytimeSeconds = 300,
	PlaytimeCoins = 1200,
}

GameConfig.Audio = {
	Punch = "rbxassetid://132504023010884",
	Collapse = "rbxassetid://73130804959365",
	Reward = "rbxassetid://4612374209",
	BossRoar = "rbxassetid://133651202885353",
	Music = "rbxassetid://1837768013",
}

GameConfig.GeneratedGraphics = {
	Iteration01Billboard = "rbxassetid://82590428870038",
	Iteration01SpawnBillboard = "rbxassetid://125153703372122",
	Iteration01MenuBanner = "rbxassetid://88173613852029",
	Iteration01GuardianIcon = "rbxassetid://108499712320512",
	Iteration02DNABanner = "rbxassetid://80764015986038",
	Iteration02PetIcon = "rbxassetid://114585325653299",
	Iteration03TasksBanner = "rbxassetid://134754597904456",
	Iteration03SettingsBanner = "rbxassetid://79786692712597",
	Iteration04ArmoryBanner = "rbxassetid://105049638464832",
	Iteration05TitanBanner = "rbxassetid://93552182756522",
	HeroCityHUDAtlas = "rbxassetid://104014193600358",
	FistUIIconAtlas = "rbxassetid://104014193600358",
	HeroCityPixelReference = "rbxassetid://122009159493035",
}

GameConfig.UIIconAtlas = {
	image = GameConfig.GeneratedGraphics.FistUIIconAtlas,
	width = 677,
	height = 408,
	regions = {
		Power = { 10, 64, 73, 78 },
		Punch = { 18, 154, 147, 172 },
		Coin = { 510, 142, 67, 77 },
		Wall = { 579, 142, 77, 77 },
		Train = { 442, 222, 66, 78 },
		Pet = { 510, 222, 67, 78 },
		Quest = { 579, 222, 77, 78 },
		Shop = { 442, 303, 66, 80 },
		Warning = { 510, 303, 67, 80 },
		Rebirth = { 579, 303, 77, 80 },
		Menu = { 449, 307, 52, 46 },
		Use = { 449, 307, 52, 46 },
		Settings = { 587, 307, 60, 48 },
		Success = { 510, 142, 67, 77 },
		StarterFist = { 191, 187, 70, 122 },
		BoxingFist = { 191, 187, 70, 122 },
		IronFist = { 269, 187, 71, 122 },
		ThunderFist = { 269, 187, 71, 122 },
		TitanFist = { 347, 179, 78, 134 },
		ShopHeader = { 174, 134, 271, 66 },
	},
}

GameConfig.HeroCityPixelUI = {
	Power = "rbxassetid://116369277219209",
	Coins = "rbxassetid://129024701441116",
	Wall = "rbxassetid://71796534980277",
	Daily = "rbxassetid://140223386174801",
	Spin = "rbxassetid://107739720698002",
	Rebirth = "rbxassetid://129503393018469",
	Shop = "rbxassetid://104281527974467",
	Pets = "rbxassetid://94981950804472",
	Quests = "rbxassetid://130173685908715",
	QuestCard = "rbxassetid://98132697706518",
	Punch = "rbxassetid://86102957745205",
	Jump = "rbxassetid://113344820616843",
	NextWorld = "rbxassetid://114183013946957",
	Joystick = "rbxassetid://105237841705957",
	TopTools = "rbxassetid://108532231146129",
	SoundTool = "rbxassetid://91707047961392",
	SettingsTool = "rbxassetid://98048887733214",
	MoreTool = "rbxassetid://103143983649151",
	BottomShellLeft = "rbxassetid://104963245770369",
	BottomShellRight = "rbxassetid://84524765387254",
	SmashBillboard = "rbxassetid://111791716595528",
}

return GameConfig
