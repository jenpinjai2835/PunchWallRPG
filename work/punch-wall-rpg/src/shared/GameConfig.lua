local GameConfig = {}

GameConfig.DataVersion = 5
GameConfig.MaxCritChance = 65
GameConfig.MaxPetInventory = 60
GameConfig.MaxEquippedPets = 3
GameConfig.MaxPetStars = 5
GameConfig.StudioTestGrantPremium = true
GameConfig.StudioTestHarness = {
	Enabled = true,
	Version = "1.0.0",
	MaxSequenceSteps = 50,
}
GameConfig.RegularWallRespawnSeconds = 8
GameConfig.BossRespawnSeconds = 20
GameConfig.WorldProgressTarget = 75

GameConfig.Training = {
	TickSeconds = 1,
	PowerPerTick = 4,
	OfflineEfficiency = 0.35,
	MaxOfflineSeconds = 8 * 60 * 60,
	LockPlayerWhileOnline = true,
	ImpactEmit = 18,
}

GameConfig.Spin = {
	CooldownSeconds = 20 * 60 * 60,
	Rewards = {
		{ id = "Honor100", label = "100 HONOR", kind = "Honor", amount = 100, weight = 4, color = Color3.fromRGB(220, 229, 255) },
		{ id = "Coins500", label = "500 COINS", kind = "Coins", amount = 500, weight = 28, color = Color3.fromRGB(255, 190, 40) },
		{ id = "Power2000", label = "2K POWER", kind = "Power", amount = 2000, weight = 8, color = Color3.fromRGB(54, 200, 255) },
		{ id = "Honor50", label = "50 HONOR", kind = "Honor", amount = 50, weight = 8, color = Color3.fromRGB(190, 202, 255) },
		{ id = "BonusSpinGreen", label = "BONUS SPIN", kind = "BonusSpin", amount = 1, weight = 10, color = Color3.fromRGB(80, 225, 92) },
		{ id = "Power400", label = "400 POWER", kind = "Power", amount = 400, weight = 22, color = Color3.fromRGB(43, 152, 255) },
		{ id = "Coins3000", label = "3K COINS", kind = "Coins", amount = 3000, weight = 10, color = Color3.fromRGB(255, 156, 27) },
		{ id = "BonusSpinPurple", label = "BONUS SPIN", kind = "BonusSpin", amount = 1, weight = 10, color = Color3.fromRGB(191, 52, 211) },
	},
}

GameConfig.DepthWall = {
	BlockSize = Vector3.new(4, 4, 4),
	Columns = 12,
	Rows = 6,
	Layers = 75,
	LayersPerTier = 8,
}

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
	{ name = "Iron Knuckle", displayName = "Iron Crusher Fist", tier = 3, style = "Iron", icon = "IronFist", cost = 1100, mult = 4.5, speed = 0.35, color = Color3.fromRGB(24, 31, 40), accent = Color3.fromRGB(56, 205, 255), material = Enum.Material.DiamondPlate },
	{ name = "Thunder Fist", displayName = "Thunder Core Fist", tier = 4, style = "Thunder", icon = "ThunderFist", cost = 8200, mult = 13, speed = 0.7, color = Color3.fromRGB(37, 108, 180), accent = Color3.fromRGB(72, 225, 255), material = Enum.Material.Metal },
	{ name = "Titan Gauntlet", displayName = "Titan Siege Fist", tier = 5, style = "Titan", icon = "TitanFist", cost = 90000, mult = 45, speed = 1.2, color = Color3.fromRGB(218, 142, 31), accent = Color3.fromRGB(255, 213, 82), material = Enum.Material.Metal },
}

-- Permanent Premium fists use Game Passes. IDs remain zero until the owner
-- creates the passes for the published experience in Creator Dashboard.
GameConfig.PremiumFists = {
	{ name = "Crimson Vanguard Fist", displayName = "Crimson Vanguard", tier = 6, style = "Vanguard", icon = "BoxingFist", robux = 49, gamePassId = 0, mult = 2.5, color = Color3.fromRGB(214, 38, 42), accent = Color3.fromRGB(255, 186, 49), material = Enum.Material.Metal, model = "Armored" },
	{ name = "Stormbreaker Fist", displayName = "Stormbreaker", tier = 7, style = "Storm", icon = "ThunderFist", robux = 129, gamePassId = 0, mult = 12, color = Color3.fromRGB(24, 47, 72), accent = Color3.fromRGB(46, 211, 255), material = Enum.Material.Metal, model = "Void" },
	{ name = "Celestial Titan Fist", displayName = "Celestial Titan", tier = 8, style = "Celestial", icon = "TitanFist", robux = 299, gamePassId = 0, mult = 60, color = Color3.fromRGB(213, 137, 23), accent = Color3.fromRGB(255, 228, 101), material = Enum.Material.Metal, model = "Gold" },
}

GameConfig.PremiumPets = {
	{ name = "Crimson Phoenix", rarity = "Premium", robux = 79, gamePassId = 0, mult = 2.8, luckGain = 0.2, color = Color3.fromRGB(255, 61, 54), accent = Color3.fromRGB(255, 190, 47), visual = "Phoenix", templateName = "Sanitized_CrimsonPhoenixPet", companionHeight = 3.0, followHeight = 1.75, followResponsiveness = 6.4, hoverAmplitude = 0.32 },
	{ name = "Storm Wyvern", rarity = "Premium", robux = 169, gamePassId = 0, mult = 6.5, luckGain = 0.4, color = Color3.fromRGB(34, 105, 190), accent = Color3.fromRGB(67, 224, 255), visual = "Wyvern", templateName = "Sanitized_StormWyvernPet", companionHeight = 2.55, followHeight = 1.45, followResponsiveness = 7.0, hoverAmplitude = 0.28 },
	{ name = "Celestial Guardian", rarity = "Premium", robux = 349, gamePassId = 0, mult = 15, luckGain = 0.8, color = Color3.fromRGB(231, 166, 35), accent = Color3.fromRGB(255, 239, 130), visual = "Celestial", templateName = "Sanitized_CelestialGuardianPet", companionHeight = 2.85, followHeight = 1.3, followResponsiveness = 7.5, hoverAmplitude = 0.2 },
}

GameConfig.PremiumProducts = {
	{ id = "CoinPack", displayName = "Hero Coin Pack", robux = 29, productId = 0, coins = 7500, billboard = "START STRONG" },
	{ id = "SpinPack", displayName = "3 Hero Spins", robux = 39, productId = 0, spins = 3, billboard = "TRY YOUR LUCK" },
	{ id = "CoinBoost", displayName = "2X Coins - 15 min", robux = 49, productId = 0, boost = "CoinBoostExpiresAt", seconds = 900, billboard = "DOUBLE REWARDS" },
	{ id = "TrainingBoost", displayName = "2X Training - 15 min", robux = 59, productId = 0, boost = "TrainingBoostExpiresAt", seconds = 900, billboard = "TRAIN FASTER" },
}

GameConfig.HonorItems = {
	{ name = "Vanguard Trail", displayName = "Vanguard Trail", cost = 12, powerBonus = 0.05, color = Color3.fromRGB(46, 205, 255), visual = "Trail", icon = "Use" },
	{ name = "Storm Hero Aura", displayName = "Storm Hero Aura", cost = 25, powerBonus = 0.10, color = Color3.fromRGB(89, 113, 255), visual = "Storm", icon = "Power" },
	{ name = "Relic Sidekick Core", displayName = "Relic Sidekick Core", cost = 40, powerBonus = 0.15, color = Color3.fromRGB(190, 78, 255), visual = "Relic", icon = "Pet" },
	{ name = "Crown of the Deep", displayName = "Crown of the Deep", cost = 65, powerBonus = 0.25, color = Color3.fromRGB(255, 204, 49), visual = "Crown", icon = "Rebirth" },
}

GameConfig.HonorPerWorldClear = 5

function GameConfig.AllFists()
	local result = {}
	for _, fist in ipairs(GameConfig.Fists) do table.insert(result, fist) end
	for _, fist in ipairs(GameConfig.PremiumFists) do table.insert(result, fist) end
	return result
end

GameConfig.Walls = {
	{ name = "Brick Wall", displayName = "Forest Stone", depth = 1, hp = 8, level = 1, coins = 45, power = 3, score = 120, pos = Vector3.new(-2, 6, -32), color = Color3.fromRGB(116, 122, 128), material = Enum.Material.Rock, impactStyle = "StoneChips" },
	{ name = "Concrete Wall", depth = 2, hp = 900, level = 3, coins = 180, power = 10, score = 500, pos = Vector3.new(-2, 6, -62), color = Color3.fromRGB(150, 154, 160), material = Enum.Material.Concrete, impactStyle = "ConcreteDust" },
	{ name = "Iron Wall", depth = 3, hp = 6500, level = 8, coins = 980, power = 45, score = 1800, pos = Vector3.new(-2, 6, -92), color = Color3.fromRGB(97, 109, 122), material = Enum.Material.Metal, impactStyle = "MetalSparks" },
	{ name = "Crystal Wall", depth = 4, hp = 42000, level = 16, coins = 5200, power = 230, score = 6200, pos = Vector3.new(-2, 6, -122), color = Color3.fromRGB(88, 220, 245), material = Enum.Material.Glass, impactStyle = "CrystalShards" },
	{ name = "Lava Wall", depth = 5, hp = 220000, level = 30, coins = 28000, power = 1100, score = 22000, pos = Vector3.new(-2, 6, -152), color = Color3.fromRGB(255, 96, 45), material = Enum.Material.CrackedLava, impactStyle = "EmberBurst" },
	{ name = "Cyber Gate", depth = 6, hp = 1200000, level = 48, coins = 160000, power = 5500, score = 80000, pos = Vector3.new(-2, 6, -182), color = Color3.fromRGB(75, 115, 255), material = Enum.Material.CorrodedMetal, impactStyle = "ElectricArc" },
	{ name = "Titan Alloy Gate", style = "Titan Alloy Gate", depth = 7, hp = 4800000, level = 60, coins = 420000, power = 15000, score = 250000, xp = 12000, pos = Vector3.new(-2, 6, -212), color = Color3.fromRGB(82, 92, 105), material = Enum.Material.DiamondPlate, impactStyle = "HeavyMetalShock" },
	{ name = "Meteor Core Gate", style = "Meteor Core Gate", depth = 8, hp = 18000000, level = 70, coins = 1400000, power = 45000, score = 700000, xp = 30000, pos = Vector3.new(-2, 6, -242), color = Color3.fromRGB(185, 66, 42), material = Enum.Material.Basalt, impactStyle = "MeteorEmber" },
	{ name = "Void Crystal Gate", style = "Void Crystal Gate", depth = 9, hp = 65000000, level = 82, coins = 5000000, power = 150000, score = 2000000, xp = 70000, pos = Vector3.new(-2, 6, -272), color = Color3.fromRGB(88, 118, 212), material = Enum.Material.Glacier, impactStyle = "VoidShard" },
	{ name = "Omega Barrier", style = "Omega Barrier", depth = 10, hp = 220000000, level = 94, coins = 18000000, power = 500000, score = 6000000, xp = 150000, pos = Vector3.new(-2, 6, -302), color = Color3.fromRGB(83, 63, 153), material = Enum.Material.Foil, impactStyle = "OmegaPulse" },
}

-- Uploaded from the supplied transparent shop-art layers. Non-transparent frame
-- exports are intentionally not used as UI backgrounds because they contain a checkerboard.
GameConfig.ShopArt = {
	StarterGlove = "rbxassetid://102627532847126",
	TitanGlove = "rbxassetid://97597870943935",
	ChampionGlove = "rbxassetid://123648606849968",
	ShopCoinIcon = "rbxassetid://72320637874093",
	SpinPack = "rbxassetid://107739720698002",
	CoinBoost = "rbxassetid://124043136175492",
	SpeedBoost = "rbxassetid://110700899933892",
	DamageBoost = "rbxassetid://140286541155994",
	HonorIcon = "rbxassetid://84140459445174",
}

GameConfig.SpinArt = {
	Panel = "rbxassetid://110491124400690",
	Wheel = "rbxassetid://99846893531877",
	Pointer = "rbxassetid://91329494172664",
	Center = "rbxassetid://128487037381453",
	SpinNow = "rbxassetid://138626112188133",
	Close = "rbxassetid://99811514961599",
	BonusSpins = "rbxassetid://108769323573776",
	Header = "rbxassetid://137476923055052",
	FreeSpinReady = "rbxassetid://101052002393700",
}

function GameConfig.FistDefinition(name)
	for _, fist in ipairs(GameConfig.Fists) do
		if fist.name == name then return fist end
	end
	for _, fist in ipairs(GameConfig.PremiumFists) do
		if fist.name == name then return fist end
	end
	return GameConfig.Fists[1]
end

function GameConfig.HonorItemDefinition(name)
	for _, item in ipairs(GameConfig.HonorItems) do
		if item.name == name then return item end
	end
	return nil
end

function GameConfig.EffectivePower(basePower, fistMultiplier, petMultiplier, rebirths, mastery, honorBonus)
	return math.max(0, tonumber(basePower) or 0)
		* math.max(1, tonumber(fistMultiplier) or 1)
		* (1 + math.max(0, tonumber(petMultiplier) or 0))
		* (1 + math.max(0, tonumber(rebirths) or 0) * 0.25)
		* (1 + math.min(math.max(0, tonumber(mastery) or 0), 500) * 0.001)
		* (1 + math.max(0, tonumber(honorBonus) or 0))
end

GameConfig.Pets = {
	{ name = "Forest Pup", rarity = "Common", baseWeight = 5500, minDepth = 1, mult = 0.15, luckGain = 0.03, color = Color3.fromRGB(112, 178, 92) },
	{ name = "Miner Cat", rarity = "Rare", baseWeight = 3000, minDepth = 12, mult = 0.35, luckGain = 0.08, color = Color3.fromRGB(80, 151, 211) },
	{ name = "Crystal Fox", rarity = "Epic", baseWeight = 1100, minDepth = 28, mult = 0.85, luckGain = 0.16, color = Color3.fromRGB(168, 103, 219) },
	{ name = "Lava Dragon", rarity = "Legendary", baseWeight = 350, minDepth = 44, mult = 1.7, luckGain = 0.28, color = Color3.fromRGB(238, 142, 48) },
	{ name = "Secret Titan Golem", rarity = "Secret", baseWeight = 50, minDepth = 62, mult = 4.5, luckGain = 0.5, color = Color3.fromRGB(225, 59, 65) },
}

GameConfig.PetDrops = {
	BaseChance = 0.012,
	ChancePerDepth = 0.00028,
	MaxChance = 0.035,
	PityBreaks = 45,
}

function GameConfig.AllPets()
	local result = {}
	for _, pet in ipairs(GameConfig.Pets) do table.insert(result, pet) end
	for _, pet in ipairs(GameConfig.PremiumPets) do table.insert(result, pet) end
	return result
end

function GameConfig.PetDefinition(name)
	for _, pet in ipairs(GameConfig.AllPets()) do
		if pet.name == name then return pet end
	end
	return nil
end

function GameConfig.ParsePetToken(token)
	token = tostring(token or "")
	local name, stars = string.match(token, "^(.-)#(%d+)$")
	if not name or name == "" then return token, 1 end
	return name, math.clamp(math.floor(tonumber(stars) or 1), 1, GameConfig.MaxPetStars)
end

function GameConfig.PetToken(name, stars)
	stars = math.clamp(math.floor(tonumber(stars) or 1), 1, GameConfig.MaxPetStars)
	return stars <= 1 and tostring(name) or (tostring(name) .. "#" .. tostring(stars))
end

function GameConfig.PetMultiplierForToken(token)
	local name, stars = GameConfig.ParsePetToken(token)
	local pet = GameConfig.PetDefinition(name)
	if not pet then return 0 end
	return pet.mult * (1 + (stars - 1) * 0.75)
end

function GameConfig.PetFusionRequirement(stars)
	stars = math.clamp(math.floor(tonumber(stars) or 1), 1, GameConfig.MaxPetStars)
	return stars + 1
end

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
	[1] = { title = "Train Power", detail = "Train at the Power Bag once", target = "Power Bag" },
	[2] = { title = "Enter The Depth Run", detail = "Break a front block and walk through the hole", target = "Depth Course Entrance" },
	[3] = { title = "Push Deeper", detail = "Break blocks to reach stronger material tiers", target = "Depth Course Entrance" },
	[4] = { title = "Upgrade Your Fist", detail = "Buy the Street Boxing Fist at Hero HQ", target = "Boxing Glove Stand" },
	[5] = { title = "Find A Sidekick", detail = "Break deeper blocks to discover a hidden pet egg", target = "Depth Course Entrance" },
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
	Music = "rbxassetid://1837768082",
	MusicVolume = 0.22,
	TrainingImpact = "rbxassetid://132504023010884",
	CoinCollect = "rbxassetid://4612374209",
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
