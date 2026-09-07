local ForestVisualBuilder = {}

local PRIMARY_TREE_ASSET_ID = "10042451801"
local PRIMARY_TREE_CREATOR = "ScriptedNex"
local FALLBACK_TREE_ASSET_ID = "95555308270103"
local FALLBACK_TREE_CREATOR = "SwitchpmPixeld111933"
local TRUNK_MESH_ID = "rbxassetid://16460201079"
local LEAF_MESH_ID = "rbxassetid://16460182102"
local LEAF_TEXTURE_ID = "rbxassetid://16460182437"
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FistVisualBuilder = require(ReplicatedStorage:WaitForChild("FistVisualBuilder"))
local HARD_PRESENTATION_PART_BUDGET = 128
local MAX_IMPORTED_TREE_BASE_PARTS = 8
local MAX_IMPORTED_TREE_DESCENDANTS = 32
local HARD_FOREST_VISUAL_PART_BUDGET = 448

local function isImportedBehavior(instance)
	return instance:IsA("LuaSourceContainer")
		or instance:IsA("RemoteEvent")
		or instance:IsA("RemoteFunction")
		or instance:IsA("BindableEvent")
		or instance:IsA("BindableFunction")
		or instance:IsA("ClickDetector")
		or instance:IsA("ProximityPrompt")
		or instance:IsA("TouchTransmitter")
end

local function sanitizeImportedTree(model)
	local ok, sanitizedRoot, removedUnsafe = pcall(FistVisualBuilder.SanitizeVisual, model)
	if not ok or sanitizedRoot ~= model or not FistVisualBuilder.IsSanitizedVisual(model) then
		return false, 0, 0
	end
	local removedEffects = 0
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("Light")
			or descendant:IsA("ParticleEmitter")
			or descendant:IsA("Beam")
			or descendant:IsA("Trail")
		then
			removedEffects += 1
			descendant:Destroy()
		end
	end
	if not FistVisualBuilder.IsSanitizedVisual(model) then
		return false, removedUnsafe or 0, removedEffects
	end
	model:SetAttribute("ImportedBehaviorRemoved", removedUnsafe or 0)
	model:SetAttribute("ImportedUnsafeDescendantsRemoved", removedUnsafe or 0)
	model:SetAttribute("ImportedEffectsRemoved", removedEffects)
	model:SetAttribute("ImportedScriptsKept", 0)
	model:SetAttribute("AssetSanitized", true)
	model:SetAttribute("StrictVisualAllowlistVerified", true)
	return true, removedUnsafe or 0, removedEffects
end

local function importedTreeWithinBudget(template)
	if not template or not template:IsA("Model") then
		return false, 0, 0
	end
	local descendants = template:GetDescendants()
	local basePartCount = 0
	for _, descendant in ipairs(descendants) do
		if descendant:IsA("BasePart") then
			basePartCount += 1
		end
	end
	return basePartCount > 0
			and basePartCount <= MAX_IMPORTED_TREE_BASE_PARTS
			and #descendants <= MAX_IMPORTED_TREE_DESCENDANTS,
		basePartCount,
		#descendants
end

local function activeTreeMetadata()
	local externalAssets = ReplicatedStorage:FindFirstChild("PunchWallExternalAssets")
	local external = externalAssets and externalAssets:FindFirstChild("Sanitized_ForestTreeSingle")
	if external and external:IsA("Model") then
		local accepted, basePartCount, descendantCount = importedTreeWithinBudget(external)
		if accepted then
			return PRIMARY_TREE_ASSET_ID, PRIMARY_TREE_CREATOR, external, true, basePartCount, descendantCount
		end
	end
	local legacyAssets = ReplicatedStorage:FindFirstChild("PunchWallVisualAssets")
	local legacy = legacyAssets and legacyAssets:FindFirstChild("StylizedForestTreeTemplate")
	local accepted, basePartCount, descendantCount = importedTreeWithinBudget(legacy)
	if accepted then
		return FALLBACK_TREE_ASSET_ID, FALLBACK_TREE_CREATOR, legacy, true, basePartCount, descendantCount
	end
	return FALLBACK_TREE_ASSET_ID, FALLBACK_TREE_CREATOR, nil, false, basePartCount, descendantCount
end

local function markVisual(part, role, assetId, creator)
	if not assetId or not creator then
		assetId, creator = activeTreeMetadata()
	end
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = true
	part:SetAttribute("VisualRole", role)
	part:SetAttribute("CreatorStoreAssetId", assetId)
	part:SetAttribute("CreatorStoreCreator", creator)
	part:SetAttribute("AssetSanitized", true)
	return part
end

local function meshPart(name, parent, meshId, textureId, size, cframe, color, role, assetId, creator)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = meshId == TRUNK_MESH_ID and Vector3.new(size.X * 0.34, size.Y, size.Z * 0.34) or size
	part.Shape = meshId == TRUNK_MESH_ID and Enum.PartType.Cylinder or Enum.PartType.Ball
	part.CFrame = cframe
	part.Color = color
	part.Material = meshId == TRUNK_MESH_ID and Enum.Material.Wood or Enum.Material.LeafyGrass
	part:SetAttribute("ProceduralFallback", true)
	markVisual(part, role, assetId, creator)
	part.Parent = parent
	return part
end

local function detailedTree(parent, name, groundPosition, height, yaw, leafColor, trunkRole, canopyRole)
	local assetId, creator, template = activeTreeMetadata()
	if template and template:IsA("Model") then
		local model = template:Clone()
		model.Name = name
		model:SetAttribute("CreatorStoreAssetId", assetId)
		model:SetAttribute("CreatorStoreCreator", creator)
		model:SetAttribute("CreatorStoreTemplateUsed", true)
		model:SetAttribute("VisualRole", "SanitizedForestTreeModel")
		local sanitized = sanitizeImportedTree(model)
		local withinBudget = importedTreeWithinBudget(model)
		if sanitized and withinBudget then
			model.Parent = parent
			local _, templateSize = model:GetBoundingBox()
			model:ScaleTo(height / math.max(1, templateSize.Y))
			local boundsCFrame, boundsSize = model:GetBoundingBox()
			local pivotToBounds = model:GetPivot():ToObjectSpace(boundsCFrame)
			local targetBounds = CFrame.new(groundPosition)
				* CFrame.Angles(0, math.rad(yaw), 0)
				* CFrame.new(0, boundsSize.Y * 0.5, 0)
			model:PivotTo(targetBounds * pivotToBounds:Inverse())

			local leafIndex = 0
			for _, part in ipairs(model:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Anchored = true
					part.CanCollide = false
					part.CanTouch = false
					part.CanQuery = false
					part.CastShadow = true
					part:SetAttribute("CreatorStoreAssetId", assetId)
					part:SetAttribute("CreatorStoreCreator", creator)
					part:SetAttribute("AssetSanitized", true)
					local lowerName = string.lower(part.Name)
					if not string.find(lowerName, "trunk") and not string.find(lowerName, "branch") and not string.find(lowerName, "stem") then
						leafIndex += 1
						part.Color = part.Color:Lerp(leafColor, 0.35)
						part:SetAttribute("VisualRole", leafIndex <= 3 and canopyRole or canopyRole .. "Detail")
					else
						part:SetAttribute("VisualRole", trunkRole)
						if not model.PrimaryPart then model.PrimaryPart = part end
					end
				end
			end
			assert(
				FistVisualBuilder.IsSanitizedVisual(model),
				"Imported forest tree lost its strict sanitizer attestation"
			)
			return model
		end
		model:Destroy()
		assetId = FALLBACK_TREE_ASSET_ID
		creator = FALLBACK_TREE_CREATOR
	end

	local model = Instance.new("Model")
	model.Name = name
	model:SetAttribute("CreatorStoreAssetId", assetId)
	model:SetAttribute("CreatorStoreCreator", creator)
	model:SetAttribute("AssetSanitized", true)
	model:SetAttribute("VisualRole", "SanitizedForestTreeModel")
	model.Parent = parent

	local scale = height / 15
	local rotation = CFrame.Angles(0, math.rad(yaw), 0)
	local trunk = meshPart(
		name .. " Trunk",
		model,
		TRUNK_MESH_ID,
		nil,
		Vector3.new(6.8, 10.9, 7.3) * scale,
		CFrame.new(groundPosition + Vector3.new(0, 5.45 * scale, 0)) * rotation,
		Color3.fromRGB(91, 63, 40),
		trunkRole,
		assetId,
		creator
	)
	model.PrimaryPart = trunk

	local leafData = {
		{ Vector3.new(-2.8, 10.9, 0.8), Vector3.new(7.2, 6.3, 7.8), -18 },
		{ Vector3.new(2.6, 11.7, 0.2), Vector3.new(7.6, 6.7, 8.1), 23 },
		{ Vector3.new(0.2, 14.1, -1.0), Vector3.new(7.1, 6.4, 7.7), 57 },
	}
	for index, info in ipairs(leafData) do
		meshPart(
			name .. " Canopy " .. index,
			model,
			LEAF_MESH_ID,
			LEAF_TEXTURE_ID,
			info[2] * scale,
			CFrame.new(groundPosition + info[1] * scale) * CFrame.Angles(0, math.rad(yaw + info[3]), 0),
			leafColor,
			canopyRole,
			assetId,
			creator
		)
	end
	return model
end

local function setDecor(part, role)
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part:SetAttribute("VisualRole", role)
	return part
end

function ForestVisualBuilder.Build(forestFolder, makePart, makeBall, makeText)
	local activeAssetId, activeCreator, _, templateAccepted, templatePartCount, templateDescendantCount =
		activeTreeMetadata()
	forestFolder:SetAttribute("ForestVisualVersion", 2)
	forestFolder:SetAttribute("PrimaryTreeAssetId", activeAssetId)
	forestFolder:SetAttribute("PrimaryTreeAssetCreator", activeCreator)
	forestFolder:SetAttribute("ImportedScriptsKept", 0)
	forestFolder:SetAttribute("TreeTemplateAccepted", templateAccepted)
	forestFolder:SetAttribute("TreeTemplateBasePartCount", templatePartCount)
	forestFolder:SetAttribute("TreeTemplateDescendantCount", templateDescendantCount)
	forestFolder:SetAttribute("TreeTemplateBasePartLimit", MAX_IMPORTED_TREE_BASE_PARTS)
	forestFolder:SetAttribute("TreeTemplateDescendantLimit", MAX_IMPORTED_TREE_DESCENDANTS)
	forestFolder:SetAttribute("ForestVisualBasePartBudget", HARD_FOREST_VISUAL_PART_BUDGET)

	local clearing = makePart("Forest Spawn Clearing", forestFolder, Vector3.new(60, 0.3, 150), Vector3.new(-2, -0.16, 0), Color3.fromRGB(70, 124, 65), Enum.Material.Grass)
	setDecor(clearing, "ForestSpawnClearing")

	for index = 1, 8 do
		local z = -20 - index * 2.05
		local x = -2 + math.sin(index * 1.7) * 1.1
		local paver = makePart("Forest Objective Paver " .. index, forestFolder, Vector3.new(6.8 + index % 2, 0.18, 1.55), Vector3.new(x, 0.43, z), Color3.fromRGB(114 + index % 3 * 5, 119 + index % 2 * 4, 111), Enum.Material.Slate)
		paver.Orientation = Vector3.new(0, math.sin(index * 2.1) * 6, 0)
		setDecor(paver, "ForestObjectivePath")
	end

	for _, side in ipairs({ -1, 1 }) do
		local x = -2 + side * 27
		local post = makePart("Forest Spawn Lantern Post " .. side, forestFolder, Vector3.new(0.55, 5.2, 0.55), Vector3.new(x, 2.8, -27), Color3.fromRGB(78, 54, 35), Enum.Material.Wood)
		setDecor(post, "ForestEntryLantern")
		local cap = makePart("Forest Spawn Lantern Cap " .. side, forestFolder, Vector3.new(1.7, 0.35, 1.7), Vector3.new(x, 5.15, -27), Color3.fromRGB(31, 39, 35), Enum.Material.Metal)
		setDecor(cap, "ForestEntryLantern")
		local lamp = makeBall("Forest Spawn Lantern " .. side, forestFolder, Vector3.new(1.2, 1.2, 1.2), Vector3.new(x, 5.65, -27), Color3.fromRGB(255, 194, 68), Enum.Material.Neon)
		setDecor(lamp, "ForestEntryLantern")
		lamp:SetAttribute("LightingMode", "EmissiveOnly")
	end

	local spawnTrees = {
		{ Vector3.new(-99, 0, -9), 16, -12, Color3.fromRGB(72, 139, 69) },
		-- Keep the rank-board approach open; this tree previously sat directly in
		-- the most common sightline from spawn/armory to the board.
		{ Vector3.new(58, 0, 55), 17, 21, Color3.fromRGB(63, 130, 62) },
		{ Vector3.new(-34, 0, -36), 19, 37, Color3.fromRGB(57, 123, 59) },
		{ Vector3.new(78, 0, -10), 17, -29, Color3.fromRGB(76, 145, 70) },
		{ Vector3.new(-78, 0, 17), 16, 55, Color3.fromRGB(67, 137, 65) },
		-- Keep the rebirth portal silhouette clear; the former position intersected
		-- the portal center and made the landmark look like a glowing tree canopy.
		{ Vector3.new(72, 0, 51), 20, -48, Color3.fromRGB(60, 128, 61) },
		{ Vector3.new(-12, 0, 52), 17, 14, Color3.fromRGB(73, 143, 67) },
		{ Vector3.new(-73, 0, -37), 18, -35, Color3.fromRGB(56, 124, 59) },
	}
	for index, info in ipairs(spawnTrees) do
		detailedTree(forestFolder, "Forest Hero Tree " .. index, info[1], info[2], info[3], info[4], "ForestSpawnTree", "ForestSpawnCanopy")
	end

	local shrubSpots = {
		Vector3.new(-21, 0.9, -4), Vector3.new(18, 0.9, -2),
		Vector3.new(-25, 0.9, -30), Vector3.new(22, 0.9, -33),
		Vector3.new(-18, 0.9, 13), Vector3.new(20, 0.9, 16),
		Vector3.new(-77, 0.9, 7), Vector3.new(-8, 0.9, 8),
	}
	for index, position in ipairs(shrubSpots) do
		local shrub = makeBall("Forest Hero Shrub " .. index, forestFolder, Vector3.new(4.4 + index % 2, 2.0, 3.5), position, index % 2 == 0 and Color3.fromRGB(69, 139, 65) or Color3.fromRGB(52, 121, 58), Enum.Material.LeafyGrass)
		setDecor(shrub, "ForestSpawnShrub")
	end

	for index, position in ipairs({
		Vector3.new(-17, 0.7, -12), Vector3.new(14, 0.7, -10),
		Vector3.new(-18, 0.7, 7), Vector3.new(15, 0.7, 9),
		Vector3.new(-77, 0.7, 35), Vector3.new(-7, 0.7, 35),
	}) do
		local rock = makePart("Forest Trail Marker Rock " .. index, forestFolder, Vector3.new(2.4 + index % 3, 1.4 + index % 2 * 0.5, 2.1), position, Color3.fromRGB(89 + index % 3 * 5, 98, 91), Enum.Material.Rock)
		rock.Orientation = Vector3.new(index * 7 % 18, index * 31 % 90, index * 5 % 14)
		setDecor(rock, "ForestTrailEdge")
	end

	for _, groundInfo in ipairs({
		{ "Forest Ground West", Vector3.new(76, 1.2, 390), Vector3.new(-68, -0.8, -165) },
		{ "Forest Ground East", Vector3.new(76, 1.2, 390), Vector3.new(64, -0.8, -165) },
	}) do
		local ground = makePart(groundInfo[1], forestFolder, groundInfo[2], groundInfo[3], Color3.fromRGB(66, 116, 61), Enum.Material.Grass)
		setDecor(ground, "ForestGround")
	end

	local threshold = makePart("World 1 Forest Trail Threshold", forestFolder, Vector3.new(52, 0.14, 11), Vector3.new(-2, 0.36, -27), Color3.fromRGB(72, 128, 60), Enum.Material.Grass)
	setDecor(threshold, "ForestWorldEntry")
	for _, sideX in ipairs({ -23, 19 }) do
		local post = makePart("Forest Gateway Post " .. sideX, forestFolder, Vector3.new(2.1, 11, 2.1), Vector3.new(sideX, 5.5, -29), Color3.fromRGB(91, 64, 40), Enum.Material.Wood)
		setDecor(post, "ForestWorldEntry")
		local cap = makePart("Forest Gateway Timber Cap " .. sideX, forestFolder, Vector3.new(4.2, 0.65, 3.2), Vector3.new(sideX, 10.85, -29), Color3.fromRGB(111, 78, 44), Enum.Material.WoodPlanks)
		setDecor(cap, "ForestWorldEntry")
	end
	local crownBeam = makePart("Forest Gateway Crown Beam", forestFolder, Vector3.new(44, 0.9, 1.6), Vector3.new(-2, 10.7, -29), Color3.fromRGB(105, 74, 42), Enum.Material.WoodPlanks)
	setDecor(crownBeam, "ForestWorldEntry")

	for _, signX in ipairs({ -15.5, -4.5 }) do
		local signPost = makePart("World 1 Sign Post " .. signX, forestFolder, Vector3.new(0.55, 6.2, 0.55), Vector3.new(signX, 3.1, -28.2), Color3.fromRGB(78, 54, 35), Enum.Material.Wood)
		setDecor(signPost, "ForestWorldEntry")
	end
	local header = makePart("World 1 Forest Gateway", forestFolder, Vector3.new(10.5, 3.0, 0.6), Vector3.new(-10, 5.8, -27.8), Color3.fromRGB(20, 46, 31), Enum.Material.WoodPlanks)
	setDecor(header, "ForestWorldEntry")
	makeText(header, "WORLD 1", "FOREST BREAKTHROUGH", Enum.NormalId.Back)

	for index = 1, 18 do
		local z = -18 - index * 18
		for _, side in ipairs({ -1, 1 }) do
			local x = -2 + side * (39 + index % 3 * 8)
			if side == 1 and index <= 3 then x = 82 end
			local height = 14.5 + index % 4 * 1.6
			local color = index % 2 == 0 and Color3.fromRGB(62, 132, 64) or Color3.fromRGB(52, 121, 59)
			detailedTree(forestFolder, ("Forest Tree %02d %d"):format(index, side), Vector3.new(x, 0, z), height, index * 29 + side * 17, color, "ForestTree", "ForestCanopy")
			if index % 3 == 0 then
				for rockIndex = 1, 3 do
					local rock = makePart(("Forest Rock %02d %d %d"):format(index, side, rockIndex), forestFolder, Vector3.new(2.1 + rockIndex * 0.55, 1.4 + rockIndex * 0.35, 2.0 + rockIndex * 0.35), Vector3.new(x + side * (3 + rockIndex), 0.7, z + (rockIndex - 2) * 2.2), Color3.fromRGB(84 + rockIndex * 4, 94 + index % 2 * 4, 88), Enum.Material.Rock)
					rock.Orientation = Vector3.new(rockIndex * 7, index * 19 % 90, side * rockIndex * 6)
					setDecor(rock, "ForestRock")
				end
			end
		end
	end

	for index, x in ipairs({ -78, -64, -45, -26, -8 }) do
		local divider = makeBall("Forest Zone Divider Shrub " .. index, forestFolder, Vector3.new(8.5, 2.2, 3.2), Vector3.new(x, 1.0, 7.5), index % 2 == 0 and Color3.fromRGB(54, 122, 57) or Color3.fromRGB(68, 139, 64), Enum.Material.LeafyGrass)
		setDecor(divider, "ForestZoneDivider")
	end
	for _, x in ipairs({ -80.5, -5.5 }) do
		local log = makePart("Forest Training Boundary " .. x, forestFolder, Vector3.new(1.0, 1.0, 31), Vector3.new(x, 0.65, 25), Color3.fromRGB(91, 64, 40), Enum.Material.Wood)
		setDecor(log, "ForestTrainingBoundary")
	end

	local forestVisualPartCount = 0
	for _, descendant in ipairs(forestFolder:GetDescendants()) do
		if descendant:IsA("BasePart") then
			forestVisualPartCount += 1
		end
	end
	assert(
		forestVisualPartCount <= HARD_FOREST_VISUAL_PART_BUDGET,
		"Forest visuals exceeded their hard BasePart budget"
	)
	forestFolder:SetAttribute("ForestVisualBasePartCount", forestVisualPartCount)
	forestFolder:SetAttribute("ForestVisualBudgetValidated", true)
end

function ForestVisualBuilder.BuildPresentation(parent, context)
	context = context or {}
	local settings = context.settings or {}
	local configuredBudget = math.floor(tonumber(settings.MaxDecorativeParts) or HARD_PRESENTATION_PART_BUDGET)
	assert(configuredBudget > 0 and configuredBudget <= HARD_PRESENTATION_PART_BUDGET, "World presentation budget must be within 1..128 parts")
	assert(parent and parent:IsA("Instance"), "World presentation requires a valid parent")
	assert(not parent:FindFirstChild("World Presentation"), "World presentation can only be built once")

	local courseEntrance = context.courseEntrance
	local powerBag = context.powerBag
	local boss = context.boss
	local weakPoints = context.weakPoints or {}
	local tierConfigs = context.tierConfigs or {}
	assert(courseEntrance and courseEntrance:IsA("BasePart"), "World presentation requires the depth course entrance")
	assert(powerBag and powerBag:IsA("BasePart"), "World presentation requires the Power Bag target")
	assert(boss and boss:IsA("BasePart"), "World presentation requires the Titan boss target")
	assert(#weakPoints == (boss:GetAttribute("WeakPointCount") or 0), "Titan weak-point presentation must match gameplay targets")

	local presentation = Instance.new("Folder")
	presentation.Name = "World Presentation"
	presentation:SetAttribute("PresentationVersion", tonumber(settings.Version) or 1)
	presentation:SetAttribute("DecorativePartBudget", configuredBudget)
	presentation:SetAttribute("UsesNativeGeometryOnly", true)
	presentation:SetAttribute("ContainsRuntimeLoops", false)
	presentation:SetAttribute("ContainsLightsOrParticles", false)
	presentation.Parent = parent

	local groups = {}
	local groupCounts = {}
	local roleCounts = {}
	local breakLinked = {}
	local partCount = 0

	local function group(name)
		if groups[name] then
			return groups[name]
		end
		local folder = Instance.new("Folder")
		folder.Name = name
		folder:SetAttribute("VisualRole", name .. "Presentation")
		folder.Parent = presentation
		groups[name] = folder
		groupCounts[name] = 0
		return folder
	end

	local function part(groupName, name, size, cframe, color, material, role, linksToBoss)
		assert(partCount < configuredBudget, "World presentation exceeded its decorative BasePart budget")
		local visual = Instance.new("Part")
		visual.Name = name
		visual.Anchored = true
		visual.Locked = true
		visual.Massless = true
		visual.Size = size
		visual.CFrame = cframe
		visual.Color = color
		visual.Material = material or Enum.Material.SmoothPlastic
		visual.TopSurface = Enum.SurfaceType.Smooth
		visual.BottomSurface = Enum.SurfaceType.Smooth
		visual.CanCollide = false
		visual.CanTouch = false
		visual.CanQuery = false
		visual.CastShadow = visual.Material ~= Enum.Material.Neon
		visual:SetAttribute("VisualRole", role)
		visual:SetAttribute("WorldPresentationDecor", true)
		visual:SetAttribute("PresentationGroup", groupName)
		visual.Parent = group(groupName)
		partCount += 1
		groupCounts[groupName] += 1
		roleCounts[role] = (roleCounts[role] or 0) + 1
		if linksToBoss then
			table.insert(breakLinked, { part = visual, transparency = visual.Transparency })
		end
		return visual
	end

	local forestWood = settings.ForestWood or Color3.fromRGB(101, 70, 40)
	local forestAccent = settings.ForestAccent or Color3.fromRGB(255, 194, 68)
	local depthMetal = settings.DepthMetal or Color3.fromRGB(27, 35, 40)
	local trainingAccent = settings.TrainingAccent or Color3.fromRGB(218, 66, 48)
	local titanInset = settings.TitanInset or Color3.fromRGB(30, 38, 52)
	local titanPanel = settings.TitanPanel or Color3.fromRGB(52, 62, 77)
	local titanMetal = settings.TitanMetal or Color3.fromRGB(76, 87, 103)
	local titanSeam = settings.TitanSeam or Color3.fromRGB(96, 109, 126)
	local titanEdge = settings.TitanEdge or Color3.fromRGB(128, 142, 158)
	local titanAccent = settings.TitanAccent or Color3.fromRGB(244, 66, 52)
	local titanWeakPointAccent = settings.TitanWeakPointAccent or Color3.fromRGB(255, 180, 68)

	local function luminance(color)
		return color.R * 0.2126 + color.G * 0.7152 + color.B * 0.0722
	end

	local bossLuminance = luminance(boss.Color)
	local insetLuminance = luminance(titanInset)
	local panelLuminance = luminance(titanPanel)
	local metalLuminance = luminance(titanMetal)
	local seamLuminance = luminance(titanSeam)
	local edgeLuminance = luminance(titanEdge)
	local accentLuminance = luminance(titanAccent)
	local weakPointLuminance = luminance(titanWeakPointAccent)
	assert(bossLuminance >= 0.20, "Titan wall base is too dark for the runtime HQ lighting")
	assert(panelLuminance - insetLuminance >= 0.07, "Titan inset-to-panel contrast is too low")
	assert(metalLuminance - panelLuminance >= 0.07, "Titan panel-to-frame contrast is too low")
	assert(seamLuminance > metalLuminance, "Titan seams must read above the structural frame")
	assert(edgeLuminance - metalLuminance >= 0.18, "Titan edge highlights need stronger separation")
	assert(accentLuminance - insetLuminance >= 0.20, "Titan emergency accent is too close to the inset tone")
	assert(weakPointLuminance - panelLuminance >= 0.35, "Titan weak-point brackets need focal contrast")

	-- The forest gate remains the readable zone header; these pieces give its
	-- visible silhouette a deliberate base and a low-cost visual route inward.
	local entryCenter = Vector3.new(courseEntrance.Position.X, 0, courseEntrance.Position.Z - 4)
	for _, side in ipairs({ -1, 1 }) do
		local x = entryCenter.X + side * 21
		part("ForestEntry", "Forest Entry Stone Foot " .. side, Vector3.new(5.2, 1.0, 4.8), CFrame.new(x, 0.5, entryCenter.Z), Color3.fromRGB(77, 87, 78), Enum.Material.Rock, "ForestEntryFoundation")
		part("ForestEntry", "Forest Entry Amber Inset " .. side, Vector3.new(0.34, 8.8, 0.32), CFrame.new(x, 5.7, entryCenter.Z + 1.08), forestAccent, Enum.Material.Neon, "ForestEntryAccent")
		part("ForestEntry", "Forest Entry Timber Cap " .. side, Vector3.new(3.8, 0.34, 0.72), CFrame.new(x, 10.7, entryCenter.Z + 1.03), forestWood, Enum.Material.WoodPlanks, "ForestEntryCrown")
		for step = 1, 2 do
			local ribbonX = entryCenter.X + side * (5.5 + (step - 1) * 9)
			part("ForestEntry", ("Forest Entry Route Ribbon %d %d"):format(side, step), Vector3.new(6.5, 0.12, 0.55), CFrame.new(ribbonX, 0.48, entryCenter.Z + 3.5), forestAccent, Enum.Material.Metal, "ForestEntryRoute")
		end
	end
	part("ForestEntry", "Forest Entry Crown Inset", Vector3.new(42, 0.25, 0.32), CFrame.new(entryCenter.X, 10.7, entryCenter.Z + 1.1), forestAccent, Enum.Material.Neon, "ForestEntryAccent")

	-- Keep the actual Power Bag and click target intact. The surrounding frame
	-- communicates where to stand without introducing another interactable.
	local bagCenter = Vector3.new(powerBag.Position.X, 0, powerBag.Position.Z)
	for _, zSide in ipairs({ -1, 1 }) do
		part("PowerBag", "Power Bag Deck Edge Z " .. zSide, Vector3.new(18.6, 0.34, 0.46), CFrame.new(bagCenter + Vector3.new(0, 0.34, zSide * 9.05)), Color3.fromRGB(58, 63, 64), Enum.Material.Metal, "PowerBagDeckFrame")
	end
	for _, xSide in ipairs({ -1, 1 }) do
		part("PowerBag", "Power Bag Deck Edge X " .. xSide, Vector3.new(0.46, 0.34, 17.7), CFrame.new(bagCenter + Vector3.new(xSide * 9.05, 0.34, 0)), Color3.fromRGB(58, 63, 64), Enum.Material.Metal, "PowerBagDeckFrame")
	end
	for _, xSide in ipairs({ -1, 1 }) do
		for _, zSide in ipairs({ -1, 1 }) do
			part("PowerBag", ("Power Bag Corner Plate %d %d"):format(xSide, zSide), Vector3.new(1.65, 0.16, 1.65), CFrame.new(bagCenter + Vector3.new(xSide * 8.35, 0.56, zSide * 8.35)), trainingAccent, Enum.Material.Metal, "PowerBagCornerAccent")
		end
		part("PowerBag", "Power Bag Approach Mark " .. xSide, Vector3.new(3.5, 0.12, 0.55), CFrame.new(bagCenter + Vector3.new(xSide * 2.35, 0.5, -7.2)), trainingAccent, Enum.Material.Neon, "PowerBagApproach")
		part("PowerBag", "Power Bag Sign Bracket " .. xSide, Vector3.new(0.34, 3.8, 0.55), CFrame.new(bagCenter + Vector3.new(xSide * 6.45, 7.0, -4.2)), Color3.fromRGB(48, 54, 57), Enum.Material.Metal, "PowerBagSignFrame")
	end
	part("PowerBag", "Power Bag Sign Underline", Vector3.new(12.9, 0.3, 0.56), CFrame.new(bagCenter + Vector3.new(0, 9.08, -4.2)), trainingAccent, Enum.Material.Neon, "PowerBagSignFrame")

	-- One native frame at the entry, then three pieces per material tier:
	-- two low side ribbons and one header underline. This reinforces the
	-- existing tier landmarks without adding more text surfaces.
	local depthEntryZ = courseEntrance.Position.Z - 7.5
	for _, side in ipairs({ -1, 1 }) do
		local x = courseEntrance.Position.X + side * 25.4
		part("Depth", "Depth Entry Pillar " .. side, Vector3.new(1.4, 11, 1.4), CFrame.new(x, 5.5, depthEntryZ), depthMetal, Enum.Material.Metal, "DepthEntryFrame")
		part("Depth", "Depth Entry Pillar Inset " .. side, Vector3.new(0.24, 8.5, 1.48), CFrame.new(x, 5.4, depthEntryZ + 0.12), forestAccent, Enum.Material.Neon, "DepthEntryAccent")
	end
	part("Depth", "Depth Entry Beam", Vector3.new(52, 1.2, 1.4), CFrame.new(courseEntrance.Position.X, 10.8, depthEntryZ), depthMetal, Enum.Material.Metal, "DepthEntryFrame")
	part("Depth", "Depth Entry Beam Inset", Vector3.new(48.5, 0.24, 1.48), CFrame.new(courseEntrance.Position.X, 10.8, depthEntryZ + 0.12), forestAccent, Enum.Material.Neon, "DepthEntryAccent")

	local layersPerTier = math.max(1, math.floor(tonumber(context.layersPerTier) or 8))
	local depthBlockSize = context.depthBlockSize or Vector3.new(4, 4, 4)
	for tier, config in ipairs(tierConfigs) do
		local layer = (tier - 1) * layersPerTier + 1
		local z = -34 - (layer - 1) * depthBlockSize.Z
		local color = config.color or forestAccent
		for _, side in ipairs({ -1, 1 }) do
			part("Depth", ("Depth Tier %02d Ribbon %d"):format(tier, side), Vector3.new(0.62, 0.16, 6.5), CFrame.new(courseEntrance.Position.X + side * 27.1, 0.42, z + 2.1), color, Enum.Material.Neon, "DepthTierRibbon")
		end
		part("Depth", ("Depth Tier %02d Header Underline"):format(tier), Vector3.new(52, 0.2, 0.5), CFrame.new(courseEntrance.Position.X, 12.48, z), color, Enum.Material.Neon, "DepthTierHeader")
	end

	-- These layers sit around, and never replace, the server-owned boss and
	-- weak-point targets. Thin nested panels establish depth, seams explain the
	-- construction, and high-value edges keep the silhouette readable without
	-- adding lights, particles, collisions, or a runtime update loop.
	local bossFrontZ = boss.Position.Z - boss.Size.Z * 0.5 - 1.95
	local bossPanelZ = bossFrontZ + 0.24
	for _, xSide in ipairs({ -1, 1 }) do
		for _, ySide in ipairs({ -1, 1 }) do
			local panelCenter = Vector3.new(
				boss.Position.X + xSide * 12.7,
				boss.Position.Y + 0.5 + ySide * 6.3,
				bossPanelZ
			)
			part(
				"TitanHQ",
				("Titan Facade Panel %d %d"):format(xSide, ySide),
				Vector3.new(7.2, 8.2, 0.46),
				CFrame.new(panelCenter),
				titanPanel,
				Enum.Material.Metal,
				"TitanFacadePanel",
				true
			)
			part(
				"TitanHQ",
				("Titan Facade Panel Inset %d %d"):format(xSide, ySide),
				Vector3.new(5.65, 6.55, 0.30),
				CFrame.new(panelCenter + Vector3.new(0, 0, -0.31)),
				titanInset,
				Enum.Material.SmoothPlastic,
				"TitanFacadeInset",
				true
			)
		end
	end
	for _, side in ipairs({ -1, 1 }) do
		part(
			"TitanHQ",
			"Titan Facade Vertical Seam " .. side,
			Vector3.new(0.28, 17.2, 0.38),
			CFrame.new(boss.Position.X + side * 8.15, boss.Position.Y + 0.5, bossFrontZ - 0.12),
			titanSeam,
			Enum.Material.Metal,
			"TitanFacadeSeam",
			true
		)
		part(
			"TitanHQ",
			"Titan Facade Horizontal Seam " .. side,
			Vector3.new(27.8, 0.28, 0.38),
			CFrame.new(boss.Position.X, boss.Position.Y + 0.5 + side * 8.15, bossFrontZ - 0.12),
			titanSeam,
			Enum.Material.Metal,
			"TitanFacadeSeam",
			true
		)
	end
	for _, side in ipairs({ -1, 1 }) do
		part("TitanHQ", "Titan Facade Vertical Bracket " .. side, Vector3.new(1.1, 27, 0.7), CFrame.new(boss.Position.X + side * 18.6, boss.Position.Y + 0.5, bossFrontZ), titanMetal, Enum.Material.CorrodedMetal, "TitanFacadeBracket", true)
		part("TitanHQ", "Titan Facade Horizontal Bracket " .. side, Vector3.new(38, 1.1, 0.7), CFrame.new(boss.Position.X, boss.Position.Y + 0.5 + side * 13.5, bossFrontZ), titanMetal, Enum.Material.CorrodedMetal, "TitanFacadeBracket", true)
		part("TitanHQ", "Titan Facade Vertical Edge " .. side, Vector3.new(0.22, 24.6, 0.78), CFrame.new(boss.Position.X + side * 18.08, boss.Position.Y + 0.5, bossFrontZ - 0.10), titanEdge, Enum.Material.Metal, "TitanFacadeEdge", true)
		part("TitanHQ", "Titan Facade Horizontal Edge " .. side, Vector3.new(35.6, 0.22, 0.78), CFrame.new(boss.Position.X, boss.Position.Y + 0.5 + side * 12.98, bossFrontZ - 0.10), titanEdge, Enum.Material.Metal, "TitanFacadeEdge", true)
		for _, ySide in ipairs({ -1, 1 }) do
			part("TitanHQ", ("Titan Corner Horizontal %d %d"):format(side, ySide), Vector3.new(5.4, 0.42, 0.82), CFrame.new(boss.Position.X + side * 16.2, boss.Position.Y + 0.5 + ySide * 11.8, bossFrontZ - 0.08), titanAccent, Enum.Material.Neon, "TitanFacadeAccent", true)
			part("TitanHQ", ("Titan Corner Vertical %d %d"):format(side, ySide), Vector3.new(0.42, 5.4, 0.82), CFrame.new(boss.Position.X + side * 17.5, boss.Position.Y + 0.5 + ySide * 10.5, bossFrontZ - 0.08), titanAccent, Enum.Material.Neon, "TitanFacadeAccent", true)
		end
	end
	for index, weakPoint in ipairs(weakPoints) do
		local center = weakPoint.Position + Vector3.new(0, 0, -0.52)
		for _, side in ipairs({ -1, 1 }) do
			part("TitanHQ", ("Titan Weak Point %d Horizontal Bracket %d"):format(index, side), Vector3.new(5.8, 0.28, 0.42), CFrame.new(center + Vector3.new(0, side * 2.75, 0)), titanAccent, Enum.Material.Neon, "TitanWeakPointBracket", true)
			part("TitanHQ", ("Titan Weak Point %d Vertical Bracket %d"):format(index, side), Vector3.new(0.28, 5.8, 0.42), CFrame.new(center + Vector3.new(side * 2.75, 0, 0)), titanAccent, Enum.Material.Neon, "TitanWeakPointBracket", true)
		end
		for _, xSide in ipairs({ -1, 1 }) do
			for _, ySide in ipairs({ -1, 1 }) do
				part(
					"TitanHQ",
					("Titan Weak Point %d Corner %d %d"):format(index, xSide, ySide),
					Vector3.new(0.72, 0.72, 0.48),
					CFrame.new(center + Vector3.new(xSide * 2.35, ySide * 2.35, -0.08)),
					titanWeakPointAccent,
					Enum.Material.Neon,
					"TitanWeakPointCorner",
					true
				)
			end
		end
	end

	for _, descendant in ipairs(presentation:GetDescendants()) do
		assert(not isImportedBehavior(descendant), "World presentation contains forbidden behavior")
		assert(not descendant:IsA("Light") and not descendant:IsA("ParticleEmitter") and not descendant:IsA("Beam") and not descendant:IsA("Trail"), "World presentation must not create lights or particles")
		if descendant:IsA("BasePart") then
			assert(not descendant.CanCollide and not descendant.CanTouch and not descendant.CanQuery, "Decorative world presentation parts must be non-interactive")
		end
	end

	local expectedWeakPointFrames = #weakPoints * 4
	local expectedTitanParts = 28 + #weakPoints * 8
	assert((roleCounts.TitanFacadePanel or 0) == 4, "Titan facade needs four structural panels")
	assert((roleCounts.TitanFacadeInset or 0) == 4, "Titan facade needs four nested insets")
	assert((roleCounts.TitanFacadeSeam or 0) == 4, "Titan facade needs four construction seams")
	assert((roleCounts.TitanFacadeEdge or 0) == 4, "Titan facade needs four edge highlights")
	assert(
		(roleCounts.TitanWeakPointBracket or 0) == expectedWeakPointFrames,
		"Titan weak-point outer brackets do not match gameplay targets"
	)
	assert(
		(roleCounts.TitanWeakPointCorner or 0) == expectedWeakPointFrames,
		"Titan weak-point focal corners do not match gameplay targets"
	)
	assert(
		(groupCounts.TitanHQ or 0) == expectedTitanParts,
		"Titan HQ presentation hierarchy has an unexpected part count"
	)

	presentation:SetAttribute("DecorativePartCount", partCount)
	presentation:SetAttribute("ForestEntryPartCount", groupCounts.ForestEntry or 0)
	presentation:SetAttribute("PowerBagPartCount", groupCounts.PowerBag or 0)
	presentation:SetAttribute("DepthPartCount", groupCounts.Depth or 0)
	presentation:SetAttribute("TitanHQPartCount", groupCounts.TitanHQ or 0)
	presentation:SetAttribute("TitanFacadePanelCount", roleCounts.TitanFacadePanel or 0)
	presentation:SetAttribute("TitanFacadeInsetCount", roleCounts.TitanFacadeInset or 0)
	presentation:SetAttribute("TitanFacadeSeamCount", roleCounts.TitanFacadeSeam or 0)
	presentation:SetAttribute("TitanFacadeEdgeCount", roleCounts.TitanFacadeEdge or 0)
	presentation:SetAttribute("TitanWeakPointBracketCount", roleCounts.TitanWeakPointBracket or 0)
	presentation:SetAttribute("TitanWeakPointCornerCount", roleCounts.TitanWeakPointCorner or 0)
	presentation:SetAttribute("TitanTonalContractVersion", 2)
	presentation:SetAttribute("TitanBossLuminance", bossLuminance)
	presentation:SetAttribute("TitanInsetPanelContrast", panelLuminance - insetLuminance)
	presentation:SetAttribute("TitanPanelFrameContrast", metalLuminance - panelLuminance)
	presentation:SetAttribute("TitanFrameEdgeContrast", edgeLuminance - metalLuminance)
	presentation:SetAttribute("TitanWeakPointContrast", weakPointLuminance - panelLuminance)
	presentation:SetAttribute("TitanTonalContrastValidated", true)
	presentation:SetAttribute("ContractValidated", true)
	return {
		folder = presentation,
		partCount = partCount,
		budget = configuredBudget,
		groupCounts = groupCounts,
		breakLinked = breakLinked,
	}
end

return ForestVisualBuilder
