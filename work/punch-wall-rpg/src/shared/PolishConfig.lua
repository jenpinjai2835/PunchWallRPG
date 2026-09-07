local PolishConfig = {}

PolishConfig.StyleName = "Hero City"

PolishConfig.Palette = {
	Sky = Color3.fromRGB(100, 183, 224),
	Ground = Color3.fromRGB(37, 42, 49),
	GroundDark = Color3.fromRGB(15, 20, 27),
	Path = Color3.fromRGB(255, 197, 45),
	PathEdge = Color3.fromRGB(246, 246, 236),
	Panel = Color3.fromRGB(14, 20, 29),
	PanelSoft = Color3.fromRGB(28, 39, 51),
	Text = Color3.fromRGB(252, 250, 239),
	MutedText = Color3.fromRGB(181, 204, 216),
	Punch = Color3.fromRGB(226, 48, 43),
	Train = Color3.fromRGB(255, 197, 45),
	Use = Color3.fromRGB(36, 178, 224),
	Reward = Color3.fromRGB(72, 219, 137),
	Fail = Color3.fromRGB(239, 67, 61),
	Crit = Color3.fromRGB(255, 217, 74),
	Glass = Color3.fromRGB(54, 174, 216),
	Concrete = Color3.fromRGB(120, 132, 140),
	Asphalt = Color3.fromRGB(24, 29, 36),
	RoadLine = Color3.fromRGB(255, 197, 45),
	Rubble = Color3.fromRGB(91, 94, 96),
	HeroRed = Color3.fromRGB(226, 48, 43),
	HeroCyan = Color3.fromRGB(36, 178, 224),
	HeroYellow = Color3.fromRGB(255, 197, 45),
	Ink = Color3.fromRGB(9, 14, 22),
}

PolishConfig.WallTiers = {
	["Brick Wall"] = {
		color = Color3.fromRGB(148, 153, 158),
		accent = Color3.fromRGB(238, 161, 46),
		pad = Color3.fromRGB(55, 61, 68),
		crack = Color3.fromRGB(50, 54, 59),
		material = Enum.Material.Concrete,
		label = "Training Stone Gate",
		window = Color3.fromRGB(50, 148, 190),
	},
	["Concrete Wall"] = {
		color = Color3.fromRGB(126, 137, 145),
		accent = Color3.fromRGB(219, 225, 226),
		pad = Color3.fromRGB(48, 54, 61),
		crack = Color3.fromRGB(44, 47, 50),
		material = Enum.Material.Concrete,
		label = "Parking Tower",
		window = Color3.fromRGB(54, 143, 180),
	},
	["Iron Wall"] = {
		color = Color3.fromRGB(72, 82, 94),
		accent = Color3.fromRGB(184, 197, 204),
		pad = Color3.fromRGB(38, 46, 56),
		crack = Color3.fromRGB(29, 33, 38),
		material = Enum.Material.Metal,
		label = "Steel Office",
		window = Color3.fromRGB(50, 166, 207),
	},
	["Crystal Wall"] = {
		color = Color3.fromRGB(48, 126, 165),
		accent = Color3.fromRGB(95, 219, 247),
		pad = Color3.fromRGB(49, 56, 62),
		crack = Color3.fromRGB(24, 57, 76),
		material = Enum.Material.Glass,
		label = "Glass Highrise",
		window = Color3.fromRGB(141, 231, 250),
	},
	["Lava Wall"] = {
		color = Color3.fromRGB(126, 54, 43),
		accent = Color3.fromRGB(255, 103, 43),
		pad = Color3.fromRGB(56, 45, 40),
		crack = Color3.fromRGB(52, 25, 21),
		material = Enum.Material.Basalt,
		label = "Burning Factory",
		window = Color3.fromRGB(255, 136, 57),
	},
	["Cyber Gate"] = {
		color = Color3.fromRGB(25, 43, 65),
		accent = Color3.fromRGB(36, 204, 238),
		pad = Color3.fromRGB(34, 41, 51),
		crack = Color3.fromRGB(12, 23, 35),
		material = Enum.Material.Metal,
		label = "Defense Grid",
		window = Color3.fromRGB(67, 198, 230),
	},
	["Titan Alloy Gate"] = {
		color = Color3.fromRGB(82, 92, 105),
		accent = Color3.fromRGB(229, 189, 79),
		pad = Color3.fromRGB(44, 48, 54),
		crack = Color3.fromRGB(28, 31, 36),
		material = Enum.Material.DiamondPlate,
		label = "Titan Alloy Rampart",
		window = Color3.fromRGB(229, 189, 79),
	},
	["Meteor Core Gate"] = {
		color = Color3.fromRGB(185, 66, 42),
		accent = Color3.fromRGB(255, 159, 58),
		pad = Color3.fromRGB(54, 39, 36),
		crack = Color3.fromRGB(61, 24, 19),
		material = Enum.Material.Basalt,
		label = "Meteor Core Bastion",
		window = Color3.fromRGB(255, 139, 53),
	},
	["Void Crystal Gate"] = {
		color = Color3.fromRGB(88, 118, 212),
		accent = Color3.fromRGB(179, 116, 255),
		pad = Color3.fromRGB(39, 43, 62),
		crack = Color3.fromRGB(33, 29, 69),
		material = Enum.Material.Glacier,
		label = "Void Crystal Citadel",
		window = Color3.fromRGB(157, 113, 245),
	},
	["Omega Barrier"] = {
		color = Color3.fromRGB(83, 63, 153),
		accent = Color3.fromRGB(80, 222, 247),
		pad = Color3.fromRGB(35, 35, 53),
		crack = Color3.fromRGB(25, 20, 49),
		material = Enum.Material.Foil,
		label = "Omega Command Barrier",
		window = Color3.fromRGB(80, 222, 247),
	},
	["Titan Server Wall"] = {
		-- Keep the final wall dark, but retain enough value separation for its
		-- panels, damage seams, and weak points to survive the HQ lighting pass.
		color = Color3.fromRGB(50, 60, 75),
		accent = Color3.fromRGB(244, 66, 52),
		pad = Color3.fromRGB(63, 69, 79),
		crack = Color3.fromRGB(20, 24, 32),
		material = Enum.Material.Metal,
		label = "Titan HQ Core",
		window = Color3.fromRGB(255, 91, 72),
	},
}

PolishConfig.RarityColors = {
	Common = Color3.fromRGB(158, 189, 160),
	Rare = Color3.fromRGB(88, 159, 210),
	Epic = Color3.fromRGB(164, 106, 215),
	Legendary = Color3.fromRGB(233, 169, 61),
	Secret = Color3.fromRGB(225, 59, 65),
}

PolishConfig.Motion = {
	HitPulseSeconds = 0.08,
	HitRecoverSeconds = 0.1,
	TrainBounceSeconds = 0.1,
	ButtonPressSeconds = 0.08,
	RewardPopSeconds = 1.15,
	BreakEmit = 44,
	HitEmit = 26,
	TrainEmit = 12,
}

PolishConfig.Environment = {
	CityBuildings = false,
	CityGroundOverlays = false,
}

-- Native, deterministic world accents only. The presentation builder enforces
-- this cap at runtime so polish cannot quietly grow into an expensive second
-- map layer.
PolishConfig.WorldPresentation = {
	Version = 2,
	MaxDecorativeParts = 128,
	ForestWood = Color3.fromRGB(101, 70, 40),
	ForestAccent = Color3.fromRGB(255, 194, 68),
	DepthMetal = Color3.fromRGB(27, 35, 40),
	TrainingAccent = Color3.fromRGB(218, 66, 48),
	-- Ordered darkest-to-lightest so the Titan facade remains dark sci-fi
	-- without collapsing into one near-black silhouette at runtime.
	TitanInset = Color3.fromRGB(30, 38, 52),
	TitanPanel = Color3.fromRGB(52, 62, 77),
	TitanMetal = Color3.fromRGB(76, 87, 103),
	TitanSeam = Color3.fromRGB(96, 109, 126),
	TitanEdge = Color3.fromRGB(128, 142, 158),
	TitanAccent = Color3.fromRGB(244, 66, 52),
	TitanWeakPointAccent = Color3.fromRGB(255, 180, 68),
}

PolishConfig.FreeAssetCandidates = {
	{ use = "Sanitized stylized forest trees", assetId = "95555308270103", name = "Stylized Anime Tree Cartoon Plant Forest Nature", creator = "SwitchpmPixeld111933", hasScripts = true, fallback = "Source-built wood trunks and leafy canopies; imported scripts are never retained" },
	{ use = "Sanitized detailed Hero City skyline", assetId = "3346479763", name = "City Buildings", creator = "Zackgamer_awesome1", hasScripts = false, fallback = "Existing source-built skyline remains when runtime insertion is unavailable" },
	{ use = "Modular downtown buildings", assetId = "6418277837", name = "City Building Pack", creator = "Roblox", hasScripts = false, fallback = "Source-built city facade blocks with windows" },
	{ use = "Skyscraper decor", assetId = "44147935", name = "skyscraper", creator = "coolman104531", hasScripts = false, fallback = "Source-built background skyscraper blocks" },
	{ use = "Destroyed building decor", assetId = "7935361972", name = "ATF: destroyed building", creator = "Jacob_hosker", hasScripts = false, fallback = "Source-built rubble pile and cracked facade" },
	{ use = "Large city district candidate", assetId = "74343734530879", name = "City Buildings Skyscraper Apartment Town RP", creator = "XxOwenRoguexX201481", hasScripts = false, fallback = "Source-built street grid and facade blocks" },
	{ use = "Destroyed city candidate", assetId = "146162368", name = "destroyed city", creator = "544457", hasScripts = true, fallback = "Source-built rubble only; candidate requires full script/audio removal" },
	{ use = "Textured wrecked city vehicles", assetId = "74466546814963", name = "Abandoned car pack vehicle city roleplay RP", creator = "benr3al2015", hasScripts = true, fallback = "Source-built road barricades; all scripts removed when kept" },
	{ use = "Legendary kaiju companion display", assetId = "5618903358", name = "Crimson Claw Dragon Ally", creator = "Josegamer941", hasScripts = true, fallback = "Client-built companion geometry; all scripts and behavior removed when kept" },
	{ use = "Detailed city landmark", assetId = "135834344041946", name = "Buildings 3", creator = "TenTsuDev", hasScripts = false, fallback = "Source-built distant skyline blocks" },
}

-- Exact Creator Store models used by core interaction landmarks. These are
-- loaded through AssetService's sandbox and sanitized to visual classes only.
PolishConfig.ExternalVisualTemplates = {
	{ templateName = "Sanitized_VoidFistAura", assetId = 116284795259865, name = "Void Fist Aura", creator = "MysticHvNightO1592", use = "Premium void-fist showcase aura" },
	{ templateName = "Sanitized_HeroPowerBag", assetId = 140653091179998, name = "Hero Power Bag", creator = "Lucy896Miner", use = "Power training landmark" },
	{ templateName = "Sanitized_ArmoryMerchantNPC", assetId = 2841100862, name = "Rad Robo", creator = "L4UNDRY_BE4R", use = "Fist shop NPC" },
	{ templateName = "Sanitized_PremiumBionicHeroNPC", assetId = 3162411898, name = "Bionic Ninja Size Corrected", creator = "Mario5697", use = "Premium Robux fist and pet merchant NPC" },
	{ templateName = "Sanitized_PetLabScientistNPC", assetId = 103629315510813, name = "Pet Lab Scientist", creator = "XxWillowV3nomxX2016", use = "Pet shop NPC" },
	{ templateName = "Sanitized_ForestTreeSingle", assetId = 10042451801, name = "low poly tree", creator = "ScriptedNex", use = "Single-tree forest scenery without pack-sized canopies" },
	-- These eight templates are extracted from one user-approved free pack in
	-- Studio, sanitized, and retained in PunchWallExternalAssets. Never load the
	-- complete 3,000-part pack at runtime when a preloaded child is absent.
	{ templateName = "Sanitized_ForestPupPet", assetId = 70715599928632, name = "pet pack pets animals cute furry bundle", creator = "Creator Store listing owner", use = "Forest Pup from Dowodle", sourceModel = "Dowodle", petDefinitionName = "Forest Pup", preloadedOnly = true },
	{ templateName = "Sanitized_MinerCatPet", assetId = 70715599928632, name = "pet pack pets animals cute furry bundle", creator = "Creator Store listing owner", use = "Miner Cat from Catmouse", sourceModel = "Catmouse", petDefinitionName = "Miner Cat", preloadedOnly = true },
	{ templateName = "Sanitized_CrystalFoxPet", assetId = 70715599928632, name = "pet pack pets animals cute furry bundle", creator = "Creator Store listing owner", use = "Crystal Fox from Ocelot", sourceModel = "Ocelot", petDefinitionName = "Crystal Fox", preloadedOnly = true },
	{ templateName = "Sanitized_LavaDragonPet", assetId = 70715599928632, name = "pet pack pets animals cute furry bundle", creator = "Creator Store listing owner", use = "Lava Dragon from Mythic Autumn Dragon", sourceModel = "Mythic Autumn Dragon", petDefinitionName = "Lava Dragon", preloadedOnly = true },
	{ templateName = "Sanitized_SecretTitanGolemPet", assetId = 70715599928632, name = "pet pack pets animals cute furry bundle", creator = "Creator Store listing owner", use = "Secret Titan Golem from Dark Guardian", sourceModel = "Dark Guardian", petDefinitionName = "Secret Titan Golem", preloadedOnly = true },
	{ templateName = "Sanitized_EnragedPhoenixPet", assetId = 70715599928632, name = "pet pack pets animals cute furry bundle", creator = "Creator Store listing owner", use = "Thunder Roc from Enraged Phoenix", sourceModel = "Enraged Phoenix", petDefinitionName = "Thunder Roc", preloadedOnly = true },
	{ templateName = "Sanitized_ElectraHydraPet", assetId = 70715599928632, name = "pet pack pets animals cute furry bundle", creator = "Creator Store listing owner", use = "Frost Hydra from Electra Hydra", sourceModel = "Electra Hydra", petDefinitionName = "Frost Hydra", preloadedOnly = true },
	{ templateName = "Sanitized_MythicRadiantOnePet", assetId = 70715599928632, name = "pet pack pets animals cute furry bundle", creator = "Creator Store listing owner", use = "Solar Kirin from Mythic Radiant One", sourceModel = "Mythic Radiant One", petDefinitionName = "Solar Kirin", preloadedOnly = true },
	-- Premium companions intentionally use the original detailed standalone
	-- Creator Store models. They must never be replaced by the blocky pack
	-- children above merely because both represent a phoenix/dragon/guardian.
	{ templateName = "Sanitized_CrimsonPhoenixPet", assetId = 86478691482535, name = "Mythical Phoenix pet", creator = "IAmASwedishMale", use = "Detailed Crimson Phoenix premium companion", petDefinitionName = "Crimson Phoenix", minVisualParts = 1 },
	{ templateName = "Sanitized_StormWyvernPet", assetId = 83562531232957, name = "Adopt Me! Wyvern Dragon Pet Fantasy Roleplay", creator = "XzG0ldeneJGlitchQJCy", use = "Detailed Storm Wyvern premium companion", petDefinitionName = "Storm Wyvern", minVisualParts = 8 },
	{ templateName = "Sanitized_CelestialGuardianPet", assetId = 121956330907081, name = "Innovation Robot Dog", creator = "SirRioter", use = "Detailed Celestial Guardian premium companion", petDefinitionName = "Celestial Guardian", minVisualParts = 8 },
}

return PolishConfig
