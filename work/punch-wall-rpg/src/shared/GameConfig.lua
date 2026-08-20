local GameConfig = {}

GameConfig.DataVersion = 8
GameConfig.MaxCritChance = 65
GameConfig.MaxPetInventory = 150
GameConfig.MaxEquippedPets = 3
GameConfig.MaxPetStars = 5
-- Normal player purchase remotes must keep the same configured-ID safety in
-- Studio. Explicit premium grants are available only through the Studio test
-- harness commands owned by the server.
GameConfig.StudioTestGrantPremium = false
GameConfig.StudioTestHarness = {
	Enabled = true,
	Version = "1.0.0",
	MaxSequenceSteps = 50,
}
GameConfig.RegularWallRespawnSeconds = 8
GameConfig.BossRespawnSeconds = 20
GameConfig.WorldProgressTarget = 75

-- Rebirth is a deliberate long-play prestige exchange. Requirements are
-- derived from the current Rebirth count so the first exchange preserves the
-- established LV55/1M contract while later exchanges remain meaningful even
-- after permanent gear and pet progression are retained.
GameConfig.Rebirth = {
	Version = "ScaledRebirthV1",
	MaxRebirths = 250,
	StartingPower = 25,
	BaseLevel = 55,
	LevelStepEvery = 5,
	LevelStep = 5,
	MaxLevel = 99,
	BaseCoins = 1000000,
	CoinGrowth = 1.18,
	ExponentialSteps = 50,
	TailGrowth = 0.08,
	CoinRoundTo = 1000,
	BonusPerRebirth = 0.25,
	ConfirmationSeconds = 6,
}

function GameConfig.RebirthBonus(rebirths)
	local config = GameConfig.Rebirth
	local count = math.clamp(math.floor(tonumber(rebirths) or 0), 0, config.MaxRebirths)
	return 1 + count * config.BonusPerRebirth
end

function GameConfig.RebirthRequirement(rebirths)
	local config = GameConfig.Rebirth
	local count = math.clamp(math.floor(tonumber(rebirths) or 0), 0, config.MaxRebirths)
	local exponentialSteps = math.min(count, config.ExponentialSteps)
	local tailSteps = math.max(0, count - config.ExponentialSteps)
	local rawCoins = config.BaseCoins
		* (config.CoinGrowth ^ exponentialSteps)
		* (1 + config.TailGrowth * tailSteps)
	local rounding = math.max(1, config.CoinRoundTo)
	local requiredCoins = math.ceil(rawCoins / rounding) * rounding
	local requiredLevel = math.min(
		config.MaxLevel,
		config.BaseLevel + config.LevelStep * math.floor(count / config.LevelStepEvery)
	)
	return {
		currentRebirths = count,
		nextRebirths = math.min(config.MaxRebirths, count + 1),
		requiredLevel = requiredLevel,
		requiredCoins = requiredCoins,
		permanentMultiplier = GameConfig.RebirthBonus(math.min(config.MaxRebirths, count + 1)),
		maxed = count >= config.MaxRebirths,
	}
end

GameConfig.Training = {
	TickSeconds = 1,
	PowerPerTick = 4,
	OfflineEfficiency = 0.35,
	MaxOfflineSeconds = 8 * 60 * 60,
	LockPlayerWhileOnline = true,
	ImpactEmit = 18,
	DefaultStationId = "rookie_bag",
	Stations = {
		{ id = "rookie_bag", name = "Power Bag", displayName = "Rookie Power Bag", hudName = "Rookie Bag", tier = 1, minPower = 0, gain = 4, color = Color3.fromRGB(218, 66, 48) },
		{ id = "iron_dummy", name = "Iron Impact Dummy", displayName = "Iron Impact Dummy", hudName = "Iron Impact", tier = 2, minPower = 1500, gain = 40, color = Color3.fromRGB(50, 190, 232) },
		{ id = "titan_reactor", name = "Titan Reactor", displayName = "Titan Reactor", hudName = "Titan Reactor", tier = 3, minPower = 150000, gain = 1200, color = Color3.fromRGB(160, 76, 232) },
		{ id = "celestial_core", name = "Celestial Power Core", displayName = "Celestial Power Core", hudName = "Celestial Core", tier = 4, minPower = 15000000, gain = 50000, color = Color3.fromRGB(255, 196, 48) },
	},
}

function GameConfig.TrainingStation(idOrName)
	local selector = tostring(idOrName or "")
	for _, station in ipairs(GameConfig.Training.Stations) do
		if station.id == selector or station.name == selector then return station end
	end
	return nil
end

function GameConfig.TrainingStationForPower(power)
	local safePower = math.max(0, tonumber(power) or 0)
	local selected = GameConfig.Training.Stations[1]
	for _, station in ipairs(GameConfig.Training.Stations) do
		if safePower >= station.minPower then selected = station end
	end
	return selected
end

function GameConfig.TrainingOfflineGain(stationId, elapsedSeconds)
	local station = GameConfig.TrainingStation(stationId)
		or GameConfig.Training.Stations[1]
	local elapsed = math.clamp(
		math.floor(tonumber(elapsedSeconds) or 0),
		0,
		GameConfig.Training.MaxOfflineSeconds
	)
	return math.floor(
		elapsed / GameConfig.Training.TickSeconds
		* station.gain
		* GameConfig.Training.OfflineEfficiency
	)
end

GameConfig.Spin = {
	CooldownSeconds = 20 * 60 * 60,
	Rewards = {
		{ id = "Coins1500", label = "1.5K COINS", kind = "Coins", amount = 1500, weight = 4, color = Color3.fromRGB(255, 211, 92) },
		{ id = "Coins500", label = "500 COINS", kind = "Coins", amount = 500, weight = 28, color = Color3.fromRGB(255, 190, 40) },
		{ id = "Power2000", label = "2K POWER", kind = "Power", amount = 2000, weight = 8, color = Color3.fromRGB(54, 200, 255) },
		{ id = "Power900", label = "900 POWER", kind = "Power", amount = 900, weight = 8, color = Color3.fromRGB(105, 220, 255) },
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

-- Hero scale is driven by base Power on a logarithmic curve. The hard visual
-- ceiling is the shortest normal wall, not the taller depth wall, so even
-- unusually tall R6/R15 avatars remain below gameplay targets.
GameConfig.PlayerGrowth = {
	Version = "PowerLogWallCappedV1",
	BaselinePower = 15,
	FullGrowthPower = 1.5e9,
	MaxScaleMultiplier = 1.25,
	ShortestWallHeightStuds = 11,
	WallClearanceStuds = 1.25,
	GameplayClearanceHeightStuds = 8,
	GameplayClearanceMarginStuds = 0.8,
	ScaleStep = 0.025,
	UpdateDelaySeconds = 0.08,
	AuraStartMultiplier = 1.12,
}

function GameConfig.PlayerGrowthMultiplier(power)
	local config = GameConfig.PlayerGrowth
	local baseline = math.max(1, tonumber(config.BaselinePower) or 15)
	local fullGrowthPower = math.max(baseline + 1, tonumber(config.FullGrowthPower) or 1e15)
	local maximum = math.max(1, tonumber(config.MaxScaleMultiplier) or 1.25)
	local safePower = math.max(baseline, tonumber(power) or baseline)
	local progress = math.clamp(
		math.log(safePower / baseline) / math.log(fullGrowthPower / baseline),
		0,
		1
	)
	local rawMultiplier = 1 + (maximum - 1) * progress
	local step = math.max(0.001, tonumber(config.ScaleStep) or 0.025)
	local quantized = math.floor(rawMultiplier / step + 0.5) * step
	return math.clamp(quantized, 1, maximum)
end

function GameConfig.PlayerGrowthModelScale(power, baseModelScale, baseBodyHeight)
	local config = GameConfig.PlayerGrowth
	local safeBaseScale = math.max(0.01, tonumber(baseModelScale) or 1)
	local safeBaseHeight = math.max(0.01, tonumber(baseBodyHeight) or 5)
	local requestedMultiplier = GameConfig.PlayerGrowthMultiplier(power)
	local wallMaximumHeight = math.max(0.5,
		(tonumber(config.ShortestWallHeightStuds) or 11)
			- (tonumber(config.WallClearanceStuds) or 1.25)
	)
	local passageMaximumHeight = math.max(0.5,
		(tonumber(config.GameplayClearanceHeightStuds) or 8)
			- (tonumber(config.GameplayClearanceMarginStuds) or 0.8)
	)
	local maximumHeight = math.min(wallMaximumHeight, passageMaximumHeight)
	local heightPerModelScale = safeBaseHeight / safeBaseScale
	local wallLimitedModelScale = maximumHeight / math.max(0.01, heightPerModelScale)
	local targetModelScale = math.max(
		safeBaseScale,
		math.min(safeBaseScale * requestedMultiplier, wallLimitedModelScale)
	)
	return targetModelScale, requestedMultiplier, maximumHeight,
		targetModelScale + 0.002 < safeBaseScale * requestedMultiplier
end

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
	{ name = "Starter Glove", displayName = "Starter Fist", rarity = "Common", tier = 1, style = "Starter", icon = "StarterFist", cost = 0, mult = 1, speed = 0, color = Color3.fromRGB(166, 54, 45), accent = Color3.fromRGB(255, 197, 45), material = Enum.Material.Leather },
	{ name = "Boxing Glove", displayName = "Street Boxing Fist", rarity = "Common", tier = 2, style = "Boxing", icon = "BoxingFist", cost = 180, mult = 1.8, speed = 0.2, color = Color3.fromRGB(191, 47, 39), accent = Color3.fromRGB(239, 216, 187), material = Enum.Material.Leather },
	{ name = "Iron Knuckle", displayName = "Iron Crusher Fist", rarity = "Rare", tier = 3, style = "Iron", icon = "IronFist", cost = 1100, mult = 4.5, speed = 0.35, color = Color3.fromRGB(24, 31, 40), accent = Color3.fromRGB(56, 205, 255), material = Enum.Material.DiamondPlate },
	{ name = "Thunder Fist", displayName = "Thunder Core Fist", rarity = "Epic", tier = 4, style = "Thunder", icon = "ThunderFist", cost = 8200, mult = 13, speed = 0.7, color = Color3.fromRGB(37, 108, 180), accent = Color3.fromRGB(72, 225, 255), material = Enum.Material.Metal },
	{ name = "Titan Gauntlet", displayName = "Titan Siege Fist", rarity = "Legendary", tier = 5, style = "Titan", icon = "TitanFist", cost = 90000, mult = 45, speed = 1.2, color = Color3.fromRGB(218, 142, 31), accent = Color3.fromRGB(255, 213, 82), material = Enum.Material.Metal },
	{ name = "Magma Breaker", displayName = "Magma Breaker Fist", rarity = "Legendary", tier = 6, style = "Titan", icon = "MagmaFist", cost = 650000, mult = 120, speed = 1.35, color = Color3.fromRGB(128, 34, 25), accent = Color3.fromRGB(255, 104, 37), material = Enum.Material.CrackedLava },
	{ name = "Glacier Claw", displayName = "Glacier Claw Fist", rarity = "Legendary", tier = 7, style = "Storm", icon = "GlacierFist", cost = 4800000, mult = 320, speed = 1.5, color = Color3.fromRGB(44, 104, 152), accent = Color3.fromRGB(123, 239, 255), material = Enum.Material.Glacier },
	{ name = "Toxic Reactor", displayName = "Toxic Reactor Fist", rarity = "Mythic", tier = 8, style = "Vanguard", icon = "ToxicFist", cost = 32000000, mult = 850, speed = 1.65, color = Color3.fromRGB(50, 103, 42), accent = Color3.fromRGB(140, 255, 70), material = Enum.Material.CorrodedMetal },
	{ name = "Void Ripper", displayName = "Void Ripper Fist", rarity = "Mythic", tier = 9, style = "Celestial", icon = "VoidFist", cost = 210000000, mult = 2300, speed = 1.8, color = Color3.fromRGB(63, 42, 112), accent = Color3.fromRGB(200, 102, 255), material = Enum.Material.Foil },
	{ name = "Solar Dominion", displayName = "Solar Dominion Fist", rarity = "Mythic", tier = 10, style = "Celestial", icon = "SolarFist", cost = 1400000000, mult = 6200, speed = 1.95, color = Color3.fromRGB(179, 91, 15), accent = Color3.fromRGB(255, 229, 91), material = Enum.Material.Neon },
	{ name = "Nebula Crusher", displayName = "Nebula Crusher Fist", rarity = "Secret", tier = 11, style = "Storm", icon = "NebulaFist", cost = 9500000000, mult = 17000, speed = 2.1, color = Color3.fromRGB(73, 45, 141), accent = Color3.fromRGB(83, 213, 255), material = Enum.Material.ForceField },
	{ name = "Quantum Breaker", displayName = "Quantum Breaker Fist", rarity = "Secret", tier = 12, style = "Thunder", icon = "QuantumFist", cost = 65000000000, mult = 47000, speed = 2.25, color = Color3.fromRGB(18, 102, 111), accent = Color3.fromRGB(91, 255, 223), material = Enum.Material.Neon },
	{ name = "Chrono Sovereign", displayName = "Chrono Sovereign Fist", rarity = "Secret", tier = 13, style = "Vanguard", icon = "ChronoFist", cost = 450000000000, mult = 130000, speed = 2.4, color = Color3.fromRGB(82, 59, 124), accent = Color3.fromRGB(255, 182, 73), material = Enum.Material.Metal },
	{ name = "Galaxy Emperor", displayName = "Galaxy Emperor Fist", rarity = "Ascendant", tier = 14, style = "Celestial", icon = "GalaxyFist", cost = 3200000000000, mult = 360000, speed = 2.55, color = Color3.fromRGB(29, 38, 91), accent = Color3.fromRGB(255, 86, 229), material = Enum.Material.ForceField },
	{ name = "Infinity Core", displayName = "Infinity Core Fist", rarity = "Ascendant", tier = 15, style = "Thunder", icon = "InfinityFist", cost = 24000000000000, mult = 1000000, speed = 2.7, color = Color3.fromRGB(15, 70, 96), accent = Color3.fromRGB(255, 255, 255), material = Enum.Material.Neon },
	{ name = "Ascendant Hero", displayName = "Ascendant Hero Fist", rarity = "Ascendant", tier = 16, style = "Celestial", icon = "AscendantFist", cost = 180000000000000, mult = 2800000, speed = 2.85, color = Color3.fromRGB(119, 42, 91), accent = Color3.fromRGB(255, 222, 93), material = Enum.Material.Neon },
}

-- Coin cost controls pacing inside a band; the server-owned depth gate prevents
-- a funded alt or future coin grant from skipping the complete wall journey.
local fistUnlockDepths = { 0, 1, 9, 17, 25, 31, 37, 43, 49, 55, 60, 64, 68, 71, 73, 75 }
for index, fist in ipairs(GameConfig.Fists) do
	fist.unlockDepth = fistUnlockDepths[index]
end

-- Permanent Premium fists use the configured Smash Wall Game Passes. Runtime
-- purchase helpers also require each ID to be unique across fists and pets.
GameConfig.PremiumFists = {
	{ name = "Crimson Vanguard Fist", displayName = "Crimson Vanguard", tier = 6, style = "Vanguard", icon = "CrimsonVanguardFist", robux = 49, gamePassId = 1947838143, mult = 2.5, color = Color3.fromRGB(214, 38, 42), accent = Color3.fromRGB(255, 186, 49), material = Enum.Material.Metal, model = "Armored" },
	{ name = "Stormbreaker Fist", displayName = "Stormbreaker", tier = 7, style = "Storm", icon = "StormbreakerFist", robux = 129, gamePassId = 1951036123, mult = 12, color = Color3.fromRGB(24, 47, 72), accent = Color3.fromRGB(46, 211, 255), material = Enum.Material.Metal, model = "Void" },
	{ name = "Celestial Titan Fist", displayName = "Celestial Titan", tier = 8, style = "Celestial", icon = "CelestialTitanFist", robux = 299, gamePassId = 1951054054, mult = 60, color = Color3.fromRGB(213, 137, 23), accent = Color3.fromRGB(255, 228, 101), material = Enum.Material.Metal, model = "Gold" },
}

GameConfig.PremiumPets = {
	{ name = "Crimson Phoenix", rarity = "Premium", robux = 79, gamePassId = 1948233870, mult = 2.8, luckGain = 0.2, color = Color3.fromRGB(255, 61, 54), accent = Color3.fromRGB(255, 190, 47), visual = "Phoenix", artKey = "CrimsonPhoenix", templateName = "Sanitized_CrimsonPhoenixPet", packModel = "Enraged Phoenix", companionHeight = 2.35, followHeight = 1.4, followResponsiveness = 6.4, hoverAmplitude = 0.32 },
	{ name = "Storm Wyvern", rarity = "Premium", robux = 169, gamePassId = 1948851823, mult = 6.5, luckGain = 0.4, color = Color3.fromRGB(34, 105, 190), accent = Color3.fromRGB(67, 224, 255), visual = "Wyvern", artKey = "StormWyvern", templateName = "Sanitized_StormWyvernPet", packModel = "Electra Hydra", companionHeight = 2.55, followHeight = 1.35, followResponsiveness = 7.0, hoverAmplitude = 0.28 },
	{ name = "Celestial Guardian", rarity = "Premium", robux = 349, gamePassId = 1947471788, mult = 15, luckGain = 0.8, color = Color3.fromRGB(231, 166, 35), accent = Color3.fromRGB(255, 239, 130), visual = "Celestial", artKey = "CelestialGuardian", templateName = "Sanitized_CelestialGuardianPet", packModel = "Mythic Radiant One", companionHeight = 2.85, followHeight = 1.25, followResponsiveness = 7.5, hoverAmplitude = 0.2 },
}

GameConfig.PremiumProducts = {
	{ id = "CoinPack", displayName = "Hero Coin Pack", robux = 29, productId = 3708736246, coins = 7500, billboard = "START STRONG", shopPage = "Robux", worldOffer = true },
	{ id = "SpinPack", displayName = "3 Hero Spins", robux = 49, productId = 3708736283, spins = 3, billboard = "TRY YOUR LUCK", shopPage = "Robux", worldOffer = true },
	{ id = "CoinBoost", displayName = "2X Coins 15 Minutes", robux = 49, productId = 3708736312, boost = "CoinBoostExpiresAt", seconds = 900, billboard = "DOUBLE REWARDS", shopPage = "Robux", worldOffer = true },
	{ id = "TrainingBoost", displayName = "2X Training 15 Minutes", robux = 59, productId = 3708736344, boost = "TrainingBoostExpiresAt", seconds = 900, billboard = "TRAIN FASTER", shopPage = "Robux", worldOffer = true },
	-- Honor packs are intentionally unavailable until four fresh Developer
	-- Product IDs from this experience are configured. Never reuse Game Pass or
	-- existing product IDs: receipt routing is one numeric ID to one exact grant.
	{ id = "HonorPouch25", displayName = "Honor Pouch", robux = 29, productId = 3708804891, honor = 25, shopPage = "Honor", worldOffer = false, valueBadge = "STARTER", accent = Color3.fromRGB(46, 205, 255) },
	{ id = "HonorCache90", displayName = "Honor Cache", robux = 79, productId = 3708804911, honor = 90, shopPage = "Honor", worldOffer = false, valueBadge = "POPULAR", accent = Color3.fromRGB(89, 113, 255) },
	{ id = "HonorVault300", displayName = "Honor Vault", robux = 199, productId = 3708804933, honor = 300, shopPage = "Honor", worldOffer = false, valueBadge = "GREAT VALUE", accent = Color3.fromRGB(190, 78, 255) },
	{ id = "HonorTreasury850", displayName = "Honor Treasury", robux = 499, productId = 3708804944, honor = 850, shopPage = "Honor", worldOffer = false, valueBadge = "BEST VALUE", accent = Color3.fromRGB(255, 232, 105) },
}

GameConfig.Honor = {
	Version = "PrestigeHonorV1",
	WorldClearBase = 5,
	FirstDailyClearBonus = 7,
	MaxWorldClearsPerDay = 3,
	MinimumBossContribution = 0.01,
	MinimumClearIntervalSeconds = 300,
	MaxEquippedPowerBonus = 0.12,
	DepthMilestones = {
		{ depth = 10, honor = 2 },
		{ depth = 20, honor = 3 },
		{ depth = 35, honor = 5 },
		{ depth = 50, honor = 8 },
		{ depth = 65, honor = 12 },
		{ depth = 75, honor = 20 },
	},
	RebirthMilestones = {
		{ rebirths = 1, honor = 5 },
		{ rebirths = 5, honor = 10 },
		{ rebirths = 10, honor = 20 },
		{ rebirths = 25, honor = 40 },
		{ rebirths = 50, honor = 75 },
	},
}

GameConfig.HonorItems = {
	{ id = "vanguard_trail", name = "Vanguard Trail", displayName = "Vanguard Trail", rarity = "Rare", cost = 20, powerBonus = 0.02, requiredDepth = 10, requiredRebirths = 0, color = Color3.fromRGB(46, 205, 255), visual = "Trail", icon = "Train" },
	{ id = "storm_hero_aura", name = "Storm Hero Aura", displayName = "Storm Hero Aura", rarity = "Epic", cost = 60, powerBonus = 0.03, requiredDepth = 20, requiredRebirths = 0, color = Color3.fromRGB(89, 113, 255), visual = "Storm", icon = "Power" },
	{ id = "relic_sidekick_core", name = "Relic Sidekick Core", displayName = "Relic Sidekick Core", rarity = "Epic", cost = 120, powerBonus = 0.04, requiredDepth = 35, requiredRebirths = 0, color = Color3.fromRGB(190, 78, 255), visual = "Relic", icon = "Pet" },
	{ id = "crown_of_the_deep", name = "Crown of the Deep", displayName = "Crown of the Deep", rarity = "Legendary", cost = 220, powerBonus = 0.05, requiredDepth = 50, requiredRebirths = 0, color = Color3.fromRGB(255, 204, 49), visual = "Crown", icon = "Rebirth" },
	{ id = "titan_vanguard_trail", name = "Titan Vanguard Trail", displayName = "Titan Vanguard Trail", rarity = "Legendary", cost = 360, powerBonus = 0.06, requiredDepth = 65, requiredRebirths = 1, color = Color3.fromRGB(255, 103, 55), visual = "Trail", icon = "Train" },
	{ id = "tempest_commander_aura", name = "Tempest Commander Aura", displayName = "Tempest Commander Aura", rarity = "Mythic", cost = 540, powerBonus = 0.08, requiredDepth = 75, requiredRebirths = 5, color = Color3.fromRGB(66, 235, 255), visual = "Storm", icon = "Power" },
	{ id = "celestial_relic_core", name = "Celestial Relic Core", displayName = "Celestial Relic Core", rarity = "Mythic", cost = 780, powerBonus = 0.10, requiredDepth = 75, requiredRebirths = 10, color = Color3.fromRGB(232, 125, 255), visual = "Relic", icon = "Pet" },
	{ id = "eternal_crown_of_honor", name = "Eternal Crown of Honor", displayName = "Eternal Crown of Honor", rarity = "Secret", cost = 1100, powerBonus = 0.12, requiredDepth = 75, requiredRebirths = 25, color = Color3.fromRGB(255, 232, 105), visual = "Crown", icon = "Rebirth" },
}

-- Compatibility alias for old UI/test readers. Qualified recurring awards are
-- now granted only by the authoritative Titan-clear path.
GameConfig.HonorPerWorldClear = GameConfig.Honor.WorldClearBase

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
		if item.id == name or item.name == name then return item end
	end
	return nil
end

function GameConfig.HonorItemUnlocked(item, depth, rebirths)
	return item ~= nil
		and math.max(0, tonumber(depth) or 0) >= (item.requiredDepth or 0)
		and math.max(0, tonumber(rebirths) or 0) >= (item.requiredRebirths or 0)
end

function GameConfig.EffectivePower(basePower, fistMultiplier, petMultiplier, rebirths, mastery, honorBonus)
	return math.max(0, tonumber(basePower) or 0)
		* math.max(1, tonumber(fistMultiplier) or 1)
		* (1 + math.max(0, tonumber(petMultiplier) or 0))
		* GameConfig.RebirthBonus(rebirths)
		* (1 + math.min(math.max(0, tonumber(mastery) or 0), 500) * 0.001)
		* (1 + math.max(0, tonumber(honorBonus) or 0))
end

GameConfig.Pets = {
	{ name = "Forest Pup", rarity = "Common", baseWeight = 5500, minDepth = 1, mult = 0.15, luckGain = 0.03, color = Color3.fromRGB(112, 178, 92), accent = Color3.fromRGB(202, 244, 114), visual = "Pup", artKey = "ForestPup", templateName = "Sanitized_ForestPupPet", packModel = "Dowodle", companionHeight = 1.45 },
	{ name = "Meadow Bunny", rarity = "Common", baseWeight = 4200, minDepth = 6, mult = 0.22, luckGain = 0.04, color = Color3.fromRGB(194, 151, 205), accent = Color3.fromRGB(255, 225, 242), visual = "Bunny", artKey = "MeadowBunny", templateName = "Sanitized_ForestPupPet", packModel = "Dowodle", companionHeight = 1.5 },
	{ name = "Miner Cat", rarity = "Rare", baseWeight = 3000, minDepth = 12, mult = 0.35, luckGain = 0.08, color = Color3.fromRGB(80, 151, 211), accent = Color3.fromRGB(255, 215, 84), visual = "Cat", artKey = "MinerCat", templateName = "Sanitized_MinerCatPet", packModel = "Catmouse", companionHeight = 1.75 },
	{ name = "River Otter", rarity = "Rare", baseWeight = 2200, minDepth = 18, mult = 0.5, luckGain = 0.1, color = Color3.fromRGB(80, 141, 157), accent = Color3.fromRGB(119, 236, 255), visual = "Pup", artKey = "RiverOtter", templateName = "Sanitized_MinerCatPet", packModel = "Catmouse", companionHeight = 1.72 },
	{ name = "Crystal Fox", rarity = "Epic", baseWeight = 1500, minDepth = 24, mult = 0.75, luckGain = 0.14, color = Color3.fromRGB(168, 103, 219), accent = Color3.fromRGB(221, 174, 255), visual = "Fox", artKey = "CrystalFox", templateName = "Sanitized_CrystalFoxPet", packModel = "Ocelot", companionHeight = 1.95 },
	{ name = "Moss Guardian", rarity = "Epic", baseWeight = 1050, minDepth = 30, mult = 1.05, luckGain = 0.18, color = Color3.fromRGB(70, 132, 76), accent = Color3.fromRGB(145, 255, 112), visual = "Golem", artKey = "MossGuardian", templateName = "Sanitized_SecretTitanGolemPet", packModel = "Dark Guardian", companionHeight = 2.02 },
	{ name = "Ember Lynx", rarity = "Epic", baseWeight = 760, minDepth = 36, mult = 1.45, luckGain = 0.22, color = Color3.fromRGB(186, 75, 42), accent = Color3.fromRGB(255, 183, 72), visual = "Cat", artKey = "EmberLynx", templateName = "Sanitized_CrystalFoxPet", packModel = "Ocelot", companionHeight = 2.0 },
	{ name = "Lava Dragon", rarity = "Legendary", baseWeight = 520, minDepth = 42, mult = 2.1, luckGain = 0.28, color = Color3.fromRGB(238, 91, 36), accent = Color3.fromRGB(255, 216, 66), visual = "Dragon", artKey = "LavaDragon", templateName = "Sanitized_LavaDragonPet", packModel = "Mythic Autumn Dragon", companionHeight = 2.25 },
	{ name = "Frost Hydra", rarity = "Legendary", baseWeight = 360, minDepth = 48, mult = 3.2, luckGain = 0.34, color = Color3.fromRGB(73, 137, 205), accent = Color3.fromRGB(144, 242, 255), visual = "Dragon", artKey = "FrostHydra", templateName = "Sanitized_StormWyvernPet", packModel = "Electra Hydra", companionHeight = 2.3 },
	{ name = "Thunder Roc", rarity = "Legendary", baseWeight = 250, minDepth = 54, mult = 4.8, luckGain = 0.42, color = Color3.fromRGB(175, 114, 36), accent = Color3.fromRGB(255, 238, 82), visual = "Phoenix", artKey = "ThunderRoc", templateName = "Sanitized_CrimsonPhoenixPet", packModel = "Enraged Phoenix", companionHeight = 2.28 },
	{ name = "Void Hound", rarity = "Secret", baseWeight = 165, minDepth = 60, mult = 7, luckGain = 0.52, color = Color3.fromRGB(76, 50, 126), accent = Color3.fromRGB(211, 103, 255), visual = "Pup", artKey = "VoidHound", templateName = "Sanitized_ForestPupPet", packModel = "Dowodle", companionHeight = 2.15 },
	{ name = "Secret Titan Golem", rarity = "Secret", baseWeight = 105, minDepth = 64, mult = 10, luckGain = 0.62, color = Color3.fromRGB(225, 59, 65), accent = Color3.fromRGB(255, 185, 69), visual = "Golem", artKey = "SecretTitanGolem", templateName = "Sanitized_SecretTitanGolemPet", packModel = "Dark Guardian", companionHeight = 2.55 },
	{ name = "Solar Kirin", rarity = "Secret", baseWeight = 66, minDepth = 68, mult = 15, luckGain = 0.74, color = Color3.fromRGB(213, 147, 34), accent = Color3.fromRGB(255, 249, 143), visual = "Celestial", artKey = "SolarKirin", templateName = "Sanitized_CelestialGuardianPet", packModel = "Mythic Radiant One", companionHeight = 2.5 },
	{ name = "Nebula Fox", rarity = "Secret", baseWeight = 40, minDepth = 71, mult = 22, luckGain = 0.88, color = Color3.fromRGB(95, 69, 178), accent = Color3.fromRGB(255, 106, 230), visual = "Fox", artKey = "NebulaFox", templateName = "Sanitized_CrystalFoxPet", packModel = "Ocelot", companionHeight = 2.35 },
	{ name = "Chrono Dragon", rarity = "Secret", baseWeight = 22, minDepth = 73, mult = 32, luckGain = 1.05, color = Color3.fromRGB(45, 125, 145), accent = Color3.fromRGB(255, 207, 102), visual = "Dragon", artKey = "ChronoDragon", templateName = "Sanitized_LavaDragonPet", packModel = "Mythic Autumn Dragon", companionHeight = 2.55 },
	{ name = "Omega Guardian", rarity = "Secret", baseWeight = 11, minDepth = 75, mult = 48, luckGain = 1.25, color = Color3.fromRGB(44, 37, 91), accent = Color3.fromRGB(120, 236, 255), visual = "Golem", artKey = "OmegaGuardian", templateName = "Sanitized_SecretTitanGolemPet", packModel = "Dark Guardian", companionHeight = 2.6 },
}

-- The generated source files are project-owned upload candidates. Runtime uses
-- exact model-matched ViewportFrame previews until the corresponding image IDs
-- are approved and filled in, so pets never collapse to one generic picture.
GameConfig.PetInventoryArt = {
	version = "CreatorStorePackViewportV2",
	entries = {
		ForestPup = { source = "work/assets/generated/pet-inventory-icons-v1/runtime-512/forest-pup.png", assetId = "" },
		MinerCat = { source = "work/assets/generated/pet-inventory-icons-v1/runtime-512/miner-cat.png", assetId = "" },
		CrystalFox = { source = "work/assets/generated/pet-inventory-icons-v1/runtime-512/crystal-fox.png", assetId = "" },
		LavaDragon = { source = "work/assets/generated/pet-inventory-icons-v1/runtime-512/lava-dragon.png", assetId = "" },
		SecretTitanGolem = { source = "work/assets/generated/pet-inventory-icons-v1/runtime-512/secret-titan-golem.png", assetId = "" },
		CrimsonPhoenix = { source = "work/assets/generated/pet-inventory-icons-v1/runtime-512/crimson-phoenix.png", assetId = "" },
		StormWyvern = { source = "work/assets/generated/pet-inventory-icons-v1/runtime-512/storm-wyvern.png", assetId = "" },
		CelestialGuardian = { source = "work/assets/generated/pet-inventory-icons-v1/runtime-512/celestial-guardian.png", assetId = "" },
	},
}

GameConfig.PetDrops = {
	BaseChance = 0.012,
	ChancePerDepth = 0.00028,
	MaxChance = 0.035,
	PityBreaks = 45,
	LifetimeSeconds = 24,
	PickupArmSeconds = 0.65,
	PickupDistance = 14,
	SpawnCooldownSeconds = 8,
	MaxActivePerPlayer = 1,
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

-- New-player onboarding is deliberately short and action-led. Completion is
-- persisted separately from the current step so future copy/layout revisions
-- can never reopen the tutorial for a player who already finished it.
GameConfig.TutorialVersion = 2
GameConfig.TutorialCompleteStep = 4
GameConfig.Tutorial = {
	[1] = { id = "PunchWall", title = "Punch The Wall", detail = "Follow the arrow and punch a front wall block", target = "Depth Course Entrance", icon = "Punch" },
	[2] = { id = "OpenShop", title = "Open The Shop", detail = "Tap SHOP and find the Street Boxing Fist", target = "Boxing Glove Stand", icon = "Shop" },
	[3] = { id = "BuyStarterFist", title = "Buy Your First Fist", detail = "Buy the Street Boxing Fist for 180 Coins", target = "Boxing Glove Stand", icon = "BoxingFist" },
	[4] = { id = "Complete", title = "Ready To Smash", detail = "Tutorial complete", target = "", icon = "Success" },
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
	RebirthCoin = "rbxassetid://135091225093305",
	Wall = "rbxassetid://71796534980277",
	Daily = "rbxassetid://140223386174801",
	Spin = "rbxassetid://107739720698002",
	Rebirth = "rbxassetid://129503393018469",
	Shop = "rbxassetid://104281527974467",
	Inventory = "rbxassetid://123409223461276",
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
