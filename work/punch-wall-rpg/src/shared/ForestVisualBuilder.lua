local ForestVisualBuilder = {}

local TREE_ASSET_ID = "10042451801"
local TREE_CREATOR = "ScriptedNex"
local TRUNK_MESH_ID = "rbxassetid://16460201079"
local LEAF_MESH_ID = "rbxassetid://16460182102"
local LEAF_TEXTURE_ID = "rbxassetid://16460182437"
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function markVisual(part, role)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = true
	part:SetAttribute("VisualRole", role)
	part:SetAttribute("CreatorStoreAssetId", TREE_ASSET_ID)
	part:SetAttribute("CreatorStoreCreator", TREE_CREATOR)
	part:SetAttribute("AssetSanitized", true)
	return part
end

local function meshPart(name, parent, meshId, textureId, size, cframe, color, role)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = meshId == TRUNK_MESH_ID and Vector3.new(size.X * 0.34, size.Y, size.Z * 0.34) or size
	part.Shape = meshId == TRUNK_MESH_ID and Enum.PartType.Cylinder or Enum.PartType.Ball
	part.CFrame = cframe
	part.Color = color
	part.Material = meshId == TRUNK_MESH_ID and Enum.Material.Wood or Enum.Material.LeafyGrass
	part:SetAttribute("ProceduralFallback", true)
	markVisual(part, role)
	part.Parent = parent
	return part
end

local function detailedTree(parent, name, groundPosition, height, yaw, leafColor, trunkRole, canopyRole)
	local externalAssets = ReplicatedStorage:FindFirstChild("PunchWallExternalAssets")
	local legacyAssets = ReplicatedStorage:FindFirstChild("PunchWallVisualAssets")
	local template = (externalAssets and externalAssets:FindFirstChild("Sanitized_ForestTreeSingle"))
		or (legacyAssets and legacyAssets:FindFirstChild("StylizedForestTreeTemplate"))
	if template and template:IsA("Model") then
		local model = template:Clone()
		model.Name = name
		model:SetAttribute("CreatorStoreAssetId", TREE_ASSET_ID)
		model:SetAttribute("CreatorStoreCreator", TREE_CREATOR)
		model:SetAttribute("AssetSanitized", true)
		model:SetAttribute("CreatorStoreTemplateUsed", true)
		model:SetAttribute("VisualRole", "SanitizedForestTreeModel")
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
				part:SetAttribute("CreatorStoreAssetId", TREE_ASSET_ID)
				part:SetAttribute("CreatorStoreCreator", TREE_CREATOR)
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
		return model
	end

	local model = Instance.new("Model")
	model.Name = name
	model:SetAttribute("CreatorStoreAssetId", TREE_ASSET_ID)
	model:SetAttribute("CreatorStoreCreator", TREE_CREATOR)
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
		trunkRole
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
			canopyRole
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
	forestFolder:SetAttribute("ForestVisualVersion", 2)
	forestFolder:SetAttribute("PrimaryTreeAssetId", TREE_ASSET_ID)
	forestFolder:SetAttribute("PrimaryTreeAssetCreator", TREE_CREATOR)
	forestFolder:SetAttribute("ImportedScriptsKept", 0)

	local clearing = makePart("Forest Spawn Clearing", forestFolder, Vector3.new(60, 0.3, 150), Vector3.new(-2, -0.16, 0), Color3.fromRGB(70, 124, 65), Enum.Material.Grass)
	clearing:SetAttribute("VisualRole", "ForestSpawnClearing")

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
		local lamp = makeBall("Forest Spawn Lantern " .. side, forestFolder, Vector3.new(1.1, 1.1, 1.1), Vector3.new(x, 5.65, -27), Color3.fromRGB(255, 194, 68), Enum.Material.Neon)
		setDecor(lamp, "ForestEntryLantern")
		local light = Instance.new("PointLight")
		light.Color = lamp.Color
		light.Brightness = 1.05
		light.Range = 12
		light.Shadows = true
		light.Parent = lamp
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
		ground.CanCollide = false
		ground:SetAttribute("VisualRole", "ForestGround")
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
end

return ForestVisualBuilder
