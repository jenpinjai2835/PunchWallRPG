local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local InsertService = game:GetService("InsertService")
local MaterialService = game:GetService("MaterialService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local DataStoreService = game:GetService("DataStoreService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local PolishConfig = require(ReplicatedStorage:WaitForChild("PolishConfig"))
local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

local ROOT_NAME = "PunchWallRPG"
local WALL_RESPAWN_SECONDS = GameConfig.RegularWallRespawnSeconds
local TRAINING_COOLDOWN = 0.45
local WALL_HIT_COOLDOWN = 1
WORLD_RESET_INTERVAL = 300
local EGG_COST = 350
local AUTOSAVE_SECONDS = 75
local MOBILE_ACTION_DISTANCE = 38
local MOBILE_ACTION_COOLDOWN = 0.12

StarterPlayer.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Invisicam
pcall(function() PhysicsService:RegisterCollisionGroup("PlayerCharacters") end)
pcall(function() PhysicsService:RegisterCollisionGroup("DepthRubble") end)
pcall(function() PhysicsService:RegisterCollisionGroup("FallingStructural") end)
PhysicsService:CollisionGroupSetCollidable("PlayerCharacters", "DepthRubble", false)
PhysicsService:CollisionGroupSetCollidable("PlayerCharacters", "FallingStructural", false)

local function applyCharacterCollisionGroup(character)
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then descendant.CollisionGroup = "PlayerCharacters" end
	end
	if character:GetAttribute("DepthCollisionGroupApplied") then return end
	character:SetAttribute("DepthCollisionGroupApplied", true)
	character.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") then descendant.CollisionGroup = "PlayerCharacters" end
	end)
end

local NUMBER_STAT_DEFAULTS = {
	Power = 15,
	Coins = 0,
	Depth = 0,
	Score = 0,
	WallLevel = 1,
	WallXP = 0,
	Rebirths = 0,
	FistMastery = 1,
	BreakSpeed = 1,
	CritChance = 5,
	Luck = 1,
	FistMultiplier = 1,
	PetMultiplier = 0,
	TutorialStep = 1,
	DailyBreaks = 0,
	DailyQuestClaimed = 0,
	PlaytimeSeconds = 0,
	PlaytimeClaimed = 0,
}

local TEXT_STAT_DEFAULTS = {
	EquippedFist = "Starter Glove",
	Pet = "None",
	OwnedFistsJSON = "[\"Starter Glove\"]",
	PetInventoryJSON = "[]",
	EquippedPetsJSON = "[]",
	DiscoveredPetsJSON = "[]",
	LockedPetsJSON = "[]",
	LastDailyDate = "",
	DailyQuestDate = "",
	SettingsJSON = "{\"motion\":true,\"sound\":true,\"uiScale\":1}",
}

local LEADERSTAT_NAMES = {
	"Depth",
	"Score",
	"Power",
	"Coins",
	"WallLevel",
	"WallXP",
	"Rebirths",
}

local RPG_NUMBER_STAT_NAMES = {
	"FistMastery",
	"BreakSpeed",
	"CritChance",
	"Luck",
	"FistMultiplier",
	"PetMultiplier",
	"TutorialStep",
	"DailyBreaks",
	"DailyQuestClaimed",
	"PlaytimeSeconds",
	"PlaytimeClaimed",
}

local RPG_TEXT_STAT_NAMES = {
	"EquippedFist",
	"Pet",
	"OwnedFistsJSON",
	"PetInventoryJSON",
	"EquippedPetsJSON",
	"DiscoveredPetsJSON",
	"LockedPetsJSON",
	"LastDailyDate",
	"DailyQuestDate",
	"SettingsJSON",
}

local playerStore
local legacyPlayerStore
local dataStoreOk, dataStoreResult = pcall(function()
	return DataStoreService:GetDataStore("PunchWallRPG_PlayerStats_v2")
end)
if dataStoreOk then
	playerStore = dataStoreResult
	legacyPlayerStore = DataStoreService:GetDataStore("PunchWallRPG_PlayerStats_v1")
else
	warn(("[PunchWallRPG] DataStore disabled for this session: %s"):format(tostring(dataStoreResult)))
end
local savingPlayers = {}

local root = workspace:FindFirstChild(ROOT_NAME)
if root then
	root:Destroy()
end

root = Instance.new("Folder")
root.Name = ROOT_NAME
root:SetAttribute("Theme", PolishConfig.StyleName)
root:SetAttribute("VisualDirection", "Anime Hero Action")
root.Parent = workspace

do
	local curated = workspace:FindFirstChild("CuratedVisualAssets")
	if curated then
		for _, visual in ipairs(curated:GetChildren()) do
			if string.find(visual.Name, "City Landmark") or string.find(visual.Name, "Skyline") then
				visual:Destroy()
			end
		end
	end
end

local remotes = ReplicatedStorage:FindFirstChild("PunchWallEvents")
if remotes and not remotes:IsA("Folder") then
	remotes:Destroy()
	remotes = nil
end
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "PunchWallEvents"
	remotes.Parent = ReplicatedStorage
end

local function ensureRemoteEvent(name)
	local remote = remotes:FindFirstChild(name)
	if remote and not remote:IsA("RemoteEvent") then
		remote:Destroy()
		remote = nil
	end
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = remotes
	end
	return remote
end

local notifyRemote = ensureRemoteEvent("Notify")
local statRemote = ensureRemoteEvent("StatsChanged")
local actionRemote = ensureRemoteEvent("ActionRequest")
local feedbackRemote = ensureRemoteEvent("Feedback")

local wallsFolder = Instance.new("Folder")
wallsFolder.Name = "Walls"
wallsFolder.Parent = root

local interactFolder = Instance.new("Folder")
interactFolder.Name = "Interactables"
interactFolder.Parent = root

local polishFolder = Instance.new("Folder")
polishFolder.Name = "Polish"
polishFolder.Parent = root

local guideFolder = Instance.new("Folder")
guideFolder.Name = "Guide Path"
guideFolder.Parent = polishFolder

local tierFolder = Instance.new("Folder")
tierFolder.Name = "Wall Tier Frames"
tierFolder.Parent = polishFolder

local decorFolder = Instance.new("Folder")
decorFolder.Name = "City Decor"
decorFolder.Parent = polishFolder

local vfxFolder = Instance.new("Folder")
vfxFolder.Name = "VFX Anchors"
vfxFolder.Parent = polishFolder

local generatedMaterialVariants = {
	[Enum.Material.Concrete] = "KaijuDamagedConcrete",
	[Enum.Material.Asphalt] = "KaijuWornAsphalt",
	[Enum.Material.CorrodedMetal] = "KaijuContainmentMetal",
}

local function applyGeneratedMaterial(part)
	local variantName = generatedMaterialVariants[part.Material]
	if variantName and MaterialService:FindFirstChild(variantName, true) then
		part.MaterialVariant = variantName
	end
end

local function makePart(name, parent, size, position, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	if part.Material == Enum.Material.Metal and (string.find(name, "Titan") or string.find(name, "Cyber")) then
		part.Material = Enum.Material.CorrodedMetal
	end
	applyGeneratedMaterial(part)
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function makeVisualPart(name, parent, size, cframe, color, material)
	local part = makePart(name, parent, size, cframe.Position, color, material)
	part.CFrame = cframe
	part.CanCollide = false
	part.CastShadow = true
	return part
end

local function addFacadeGrid(part, rows, columns, windowColor, mullionColor)
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local surface = Instance.new("SurfaceGui")
		surface.Name = "WindowFacade"
		surface.Face = face
		surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		surface.PixelsPerStud = 28
		surface.LightInfluence = 0.55
		surface.Parent = part

		local backing = Instance.new("Frame")
		backing.Name = "FacadeBacking"
		backing.BackgroundColor3 = mullionColor or Color3.fromRGB(45, 48, 52)
		backing.BackgroundTransparency = 0.72
		backing.BorderSizePixel = 0
		backing.Size = UDim2.fromScale(1, 1)
		backing.Parent = surface

		local grid = Instance.new("UIGridLayout")
		grid.CellPadding = UDim2.fromScale(0.045, 0.055)
		grid.CellSize = UDim2.fromScale(1 / columns - 0.035, 1 / rows - 0.045)
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.Parent = backing

		for index = 1, rows * columns do
			local window = Instance.new("Frame")
			window.Name = "WindowTile"
			window.BackgroundColor3 = (index % 7 == 0) and Color3.fromRGB(247, 204, 99) or windowColor
			window.BackgroundTransparency = (index % 5 == 0) and 0.72 or 0.58
			window.BorderSizePixel = 0
			window.Parent = backing
		end
	end
	part:SetAttribute("TextureStyle", "BuildingFacadeWindows")
end

local function addFacadeGeometry(part, parent, rows, columns, windowColor, trimColor, prefix)
	local details = {}
	local function addDetail(name, size, localOffset, color, material, transparency, reflectance)
		local detail = makeVisualPart(name, parent, size, part.CFrame * CFrame.new(localOffset), color, material)
		detail.Transparency = transparency or 0
		detail.Reflectance = reflectance or 0
		detail:SetAttribute("TextureStyle", "ThreeDimensionalFacadeDetail")
		table.insert(details, { part = detail, transparency = detail.Transparency })
		return detail
	end

	local usableWidth = part.Size.X - 3.2
	local usableHeight = part.Size.Y - 5
	local startX = -usableWidth / 2
	local startY = -usableHeight / 2 + 1.2
	local cellW = usableWidth / columns
	local cellH = usableHeight / rows
	local glass = windowColor or PolishConfig.Palette.Glass
	local trim = trimColor or Color3.fromRGB(28, 31, 34)

	for _, face in ipairs({
		{ suffix = "Front", sign = -1 },
		{ suffix = "Back", sign = 1 },
	}) do
		local faceZ = face.sign * (part.Size.Z / 2 + 0.13)
		local protrude = face.sign * 0.12
		for row = 1, rows do
			local y = startY + (row - 0.5) * cellH
			addDetail(prefix .. " " .. face.suffix .. " Floor Ledge " .. row, Vector3.new(part.Size.X + 0.35, 0.16, 0.32), Vector3.new(0, y - cellH / 2, faceZ + protrude), trim, Enum.Material.Metal, 0.04, 0.02)
			for column = 1, columns do
				local x = startX + (column - 0.5) * cellW
				local lit = (row + column) % 7 == 0
				local pane = addDetail(prefix .. " " .. face.suffix .. " Glass Pane " .. row .. "-" .. column, Vector3.new(cellW * 0.58, cellH * 0.46, 0.16), Vector3.new(x, y, faceZ + face.sign * 0.08), lit and Color3.fromRGB(238, 190, 78) or glass, Enum.Material.Glass, lit and 0.12 or 0.28, lit and 0.04 or 0.16)
				pane.CastShadow = false
				addDetail(prefix .. " " .. face.suffix .. " Window Top Rail " .. row .. "-" .. column, Vector3.new(cellW * 0.68, 0.12, 0.2), Vector3.new(x, y + cellH * 0.27, faceZ + face.sign * 0.1), trim, Enum.Material.Metal, 0, 0.02)
				addDetail(prefix .. " " .. face.suffix .. " Window Sill " .. row .. "-" .. column, Vector3.new(cellW * 0.72, 0.14, 0.36), Vector3.new(x, y - cellH * 0.27, faceZ + face.sign * 0.18), Color3.fromRGB(58, 61, 63), Enum.Material.Concrete, 0, 0)
			end
		end
		for column = 0, columns do
			local x = -usableWidth / 2 + column * cellW
			addDetail(prefix .. " " .. face.suffix .. " Vertical Mullion " .. column, Vector3.new(0.18, usableHeight + 0.6, 0.28), Vector3.new(x, 0, faceZ + face.sign * 0.11), trim, Enum.Material.Metal, 0.02, 0.02)
		end
	end

	addDetail(prefix .. " Roof Parapet", Vector3.new(part.Size.X + 1.4, 1.2, part.Size.Z + 0.7), Vector3.new(0, part.Size.Y / 2 + 0.58, 0), Color3.fromRGB(25, 27, 30), Enum.Material.Metal, 0, 0.02)
	addDetail(prefix .. " Front Entrance Awning", Vector3.new(part.Size.X * 0.52, 0.36, 2.2), Vector3.new(0, -part.Size.Y / 2 + 3.1, -part.Size.Z / 2 - 0.85), Color3.fromRGB(31, 34, 36), Enum.Material.Metal, 0, 0.04)
	addDetail(prefix .. " Back Entrance Awning", Vector3.new(part.Size.X * 0.52, 0.36, 2.2), Vector3.new(0, -part.Size.Y / 2 + 3.1, part.Size.Z / 2 + 0.85), Color3.fromRGB(31, 34, 36), Enum.Material.Metal, 0, 0.04)
	addDetail(prefix .. " Utility AC Unit", Vector3.new(2.5, 1.2, 1.1), Vector3.new(part.Size.X / 2 - 2.3, 1.2, -part.Size.Z / 2 - 0.8), Color3.fromRGB(112, 119, 120), Enum.Material.Metal, 0.02, 0.03)
	addDetail(prefix .. " Fire Escape Rail", Vector3.new(0.22, part.Size.Y * 0.62, 0.22), Vector3.new(-part.Size.X / 2 - 0.25, 0, -0.3), Color3.fromRGB(22, 24, 26), Enum.Material.Metal, 0, 0.03)

	part:SetAttribute("FacadeDetailCount", #details)
	return details
end

local function addRoadMarking(name, position, size, color)
	local mark = makePart(name, decorFolder, size, position, color, Enum.Material.SmoothPlastic)
	mark:SetAttribute("TextureStyle", "RoadPaint")
	return mark
end

local function makeRubblePile(parent, basePosition, prefix)
	for index, offset in ipairs({
		Vector3.new(0, 0.35, 0),
		Vector3.new(2.2, 0.45, 0.8),
		Vector3.new(-1.8, 0.42, 1.2),
		Vector3.new(0.8, 0.5, -1.6),
	}) do
		local rubble = makeVisualPart((prefix or "Rubble") .. " Chunk " .. index, parent, Vector3.new(2.5, 0.8 + index * 0.15, 1.8), CFrame.new(basePosition + offset) * CFrame.Angles(0, math.rad(14 * index), math.rad(index * 7)), PolishConfig.Palette.Rubble, Enum.Material.Concrete)
		rubble:SetAttribute("PolishFallback", "Source-built rubble chunk")
	end
end

local function makeStreetLight(name, position)
	local pole = makePart(name .. " Pole", decorFolder, Vector3.new(0.35, 10, 0.35), position + Vector3.new(0, 5, 0), Color3.fromRGB(38, 40, 42), Enum.Material.Metal)
	pole.CanCollide = false
	local arm = makeVisualPart(name .. " Arm", decorFolder, Vector3.new(4.8, 0.28, 0.28), CFrame.new(position + Vector3.new(1.9, 9.4, 0)) * CFrame.Angles(0, 0, math.rad(-8)), Color3.fromRGB(38, 40, 42), Enum.Material.Metal)
	local lamp = makePart(name .. " Lamp", decorFolder, Vector3.new(1.4, 0.6, 1.4), position + Vector3.new(4.1, 9.15, 0), Color3.fromRGB(255, 221, 139), Enum.Material.Neon)
	lamp.CanCollide = false
	local light = Instance.new("PointLight")
	light.Name = name .. " Light"
	light.Color = lamp.Color
	light.Brightness = 1.4
	light.Range = 24
	light.Shadows = true
	light.Parent = lamp
	arm:SetAttribute("TextureStyle", "StreetFixture")
	lamp:SetAttribute("TextureStyle", "StreetLightGlow")
end

local function makeCityBuilding(name, position, size, color, windowColor, rotation)
	if position.Z < 0 then return nil end
	local building = makePart(name, decorFolder, size, position, color, Enum.Material.Concrete)
	building.CFrame = CFrame.new(position) * CFrame.Angles(0, math.rad(rotation or 0), 0)
	building.CanCollide = false
	building:SetAttribute("PolishFallback", "Source-built city building")
	building:SetAttribute("TextureStyle", "BuildingFacadeWindows")
	addFacadeGrid(building, math.max(3, math.floor(size.Y / 4)), math.max(3, math.floor(size.X / 4)), windowColor or PolishConfig.Palette.Glass, Color3.fromRGB(35, 38, 42))
	addFacadeGeometry(building, decorFolder, 3, 3, windowColor or PolishConfig.Palette.Glass, Color3.fromRGB(32, 35, 38), name)

	local roof = makeVisualPart(name .. " Roof Unit", decorFolder, Vector3.new(size.X * 0.42, 1.4, size.Z * 0.46), building.CFrame + Vector3.new(0, size.Y / 2 + 0.8, 0), Color3.fromRGB(46, 49, 53), Enum.Material.Metal)
	roof:SetAttribute("TextureStyle", "RooftopUnit")
	return building
end

local function makeSkylineBlock(name, position, size, color, windowColor)
	if position.Z < 0 then return nil end
	local building = makePart(name, decorFolder, size, position, color, Enum.Material.Concrete)
	building.CanCollide = false
	building.CastShadow = true
	building:SetAttribute("VisualRole", "DistantSkyline")
	addFacadeGrid(building, 6, 4, windowColor, Color3.fromRGB(24, 27, 30))
	local roof = makePart(name .. " Roof", decorFolder, Vector3.new(size.X * 0.7, 1.2, size.Z * 0.65), position + Vector3.new(0, size.Y / 2 + 0.6, 0), Color3.fromRGB(25, 28, 31), Enum.Material.Metal)
	roof.CanCollide = false
	return building
end

local allowedVisualClasses = {
	Model = true,
	Folder = true,
	Part = true,
	WedgePart = true,
	CornerWedgePart = true,
	MeshPart = true,
	UnionOperation = true,
	TrussPart = true,
	Attachment = true,
	Decal = true,
	Texture = true,
	SurfaceAppearance = true,
	ParticleEmitter = true,
	Beam = true,
	Trail = true,
}

local function sanitizeVisualAsset(instance)
	for _, child in ipairs(instance:GetChildren()) do
		if not allowedVisualClasses[child.ClassName] then
			child:Destroy()
		else
			sanitizeVisualAsset(child)
		end
	end
	if instance:IsA("BasePart") then
		instance.Anchored = true
		instance.CanCollide = false
		instance.CanTouch = false
		instance.CanQuery = false
	end
end

local function tryInsertVisualAsset(candidate, position, scale, yaw)
	local ok, asset = pcall(function()
		return InsertService:LoadAsset(tonumber(candidate.assetId))
	end)
	if not ok or not asset then
		return nil
	end
	asset.Name = "Creator Store " .. candidate.name
	sanitizeVisualAsset(asset)
	asset.Parent = decorFolder
	asset:SetAttribute("AssetId", candidate.assetId)
	asset:SetAttribute("Creator", candidate.creator)
	asset:SetAttribute("Use", candidate.use)
	asset:SetAttribute("SanitizedVisualOnly", true)
	if asset:IsA("Model") then
		pcall(function()
			asset:ScaleTo(scale or 0.08)
		end)
		asset:PivotTo(CFrame.new(position) * CFrame.Angles(0, math.rad(yaw or 0), 0))
	end
	return asset
end

local function makeText(part, title, subtitle, face)
	local surface = Instance.new("SurfaceGui")
	surface.Name = "Sign"
	surface.Face = face or Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 40
	surface.ZOffset = 2
	surface.Parent = part

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.BackgroundTransparency = 1
	titleLabel.Position = UDim2.fromScale(0.04, 0.08)
	titleLabel.Size = UDim2.fromScale(0.92, 0.38)
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.Text = title
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.TextScaled = true
	titleLabel.TextStrokeTransparency = 0.55
	titleLabel.Parent = surface

	local subLabel = Instance.new("TextLabel")
	subLabel.Name = "Subtitle"
	subLabel.BackgroundTransparency = 1
	subLabel.Position = UDim2.fromScale(0.06, 0.48)
	subLabel.Size = UDim2.fromScale(0.88, 0.38)
	subLabel.Font = Enum.Font.GothamBold
	subLabel.Text = subtitle
	subLabel.TextColor3 = PolishConfig.Palette.HeroCyan
	subLabel.TextScaled = true
	subLabel.TextStrokeTransparency = 0.65
	subLabel.Parent = surface

	local accent = Instance.new("Frame")
	accent.Name = "Hero Sign Accent"
	accent.Size = UDim2.fromScale(1, 0.06)
	accent.BackgroundColor3 = PolishConfig.Palette.HeroRed
	accent.BorderSizePixel = 0
	accent.Parent = surface
	local accentGradient = Instance.new("UIGradient")
	accentGradient.Color = ColorSequence.new(PolishConfig.Palette.HeroRed, PolishConfig.Palette.HeroCyan)
	accentGradient.Parent = accent

	return surface
end

local function makeGraphicSurface(part, imageId, title, subtitle, face)
	local decal = Instance.new("Decal")
	decal.Name = "Hero City Artwork Decal"
	decal.Face = face or Enum.NormalId.Front
	decal.Texture = imageId
	decal.Parent = part

	local surface = Instance.new("SurfaceGui")
	surface.Name = "Generated Graphic"
	surface.Face = face or Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 48
	surface.LightInfluence = 0.15
	surface.AlwaysOnTop = true
	surface.MaxDistance = 200
	surface.Parent = part

	local imageLabel = Instance.new("ImageLabel")
	imageLabel.Name = "Hero City Artwork"
	imageLabel.BackgroundColor3 = PolishConfig.Palette.Ink
	imageLabel.BackgroundTransparency = 1
	imageLabel.BorderSizePixel = 0
	imageLabel.Size = UDim2.fromScale(1, 1)
	imageLabel.Image = imageId
	imageLabel.ScaleType = Enum.ScaleType.Crop
	imageLabel.Parent = surface

	local caption = Instance.new("Frame")
	caption.Name = "Caption"
	caption.AnchorPoint = Vector2.new(0, 1)
	caption.Position = UDim2.fromScale(0, 1)
	caption.Size = UDim2.fromScale(1, 0.31)
	caption.BackgroundColor3 = PolishConfig.Palette.Ink
	caption.BackgroundTransparency = 0.12
	caption.BorderSizePixel = 0
	caption.Parent = imageLabel

	local titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.Position = UDim2.fromScale(0.035, 0.06)
	titleLabel.Size = UDim2.fromScale(0.93, 0.5)
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.Text = title
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.TextScaled = true
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = caption

	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Position = UDim2.fromScale(0.035, 0.55)
	subtitleLabel.Size = UDim2.fromScale(0.93, 0.35)
	subtitleLabel.Font = Enum.Font.GothamBold
	subtitleLabel.Text = subtitle
	subtitleLabel.TextColor3 = PolishConfig.Palette.HeroCyan
	subtitleLabel.TextScaled = true
	subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
	subtitleLabel.Parent = caption

	local heroAccent = Instance.new("Frame")
	heroAccent.Name = "Hero Graphic Accent"
	heroAccent.Position = UDim2.fromScale(0, 0)
	heroAccent.Size = UDim2.fromScale(1, 0.035)
	heroAccent.BackgroundColor3 = PolishConfig.Palette.HeroRed
	heroAccent.BorderSizePixel = 0
	heroAccent.Parent = imageLabel
	local heroGradient = Instance.new("UIGradient")
	heroGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, PolishConfig.Palette.HeroRed),
		ColorSequenceKeypoint.new(0.65, PolishConfig.Palette.HeroYellow),
		ColorSequenceKeypoint.new(1, PolishConfig.Palette.HeroCyan),
	})
	heroGradient.Parent = heroAccent
	return surface
end

local function makeAtlasIconSurface(part, iconName, face)
	local atlas = GameConfig.UIIconAtlas
	local region = atlas.regions[iconName] or atlas.regions.Warning
	local surface = Instance.new("SurfaceGui")
	surface.Name = "Theme Icon"
	surface.Face = face or Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 48
	surface.LightInfluence = 0.1
	surface.AlwaysOnTop = true
	surface.MaxDistance = 120
	surface.Parent = part
	local icon = Instance.new("ImageLabel")
	icon.Name = iconName .. " Icon"
	icon.Position = UDim2.fromScale(0.025, 0.08)
	icon.Size = UDim2.fromScale(0.25, 0.84)
	icon.BackgroundTransparency = 1
	icon.BorderSizePixel = 0
	icon.Image = atlas.image
	icon.ImageRectOffset = Vector2.new(region[1], region[2])
	icon.ImageRectSize = Vector2.new(region[3], region[4])
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Parent = surface
	return surface
end

local function makeEmergencyBarricade(name, position, yaw)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = decorFolder
	local pivot = CFrame.new(position) * CFrame.Angles(0, math.rad(yaw or 0), 0)
	local bar = makePart("Hazard Bar", model, Vector3.new(8, 1.1, 0.45), position, Color3.fromRGB(207, 72, 49), Enum.Material.Metal)
	bar.CFrame = pivot * CFrame.new(0, 2.1, 0)
	for side = -1, 1, 2 do
		local leg = makePart("Support", model, Vector3.new(0.55, 3.8, 0.55), position, Color3.fromRGB(45, 49, 53), Enum.Material.Metal)
		leg.CFrame = pivot * CFrame.new(side * 3.2, 0.55, 0)
		local lamp = makePart("Warning Lamp", model, Vector3.new(0.7, 0.7, 0.7), position, Color3.fromRGB(255, 82, 46), Enum.Material.Neon)
		lamp.Shape = Enum.PartType.Ball
		lamp.CFrame = pivot * CFrame.new(side * 3.2, 2.9, 0)
	end
	model:SetAttribute("VisualRole", "EmergencyRoadDressing")
	return model
end

local function makeBall(name, parent, size, position, color, material)
	local part = makePart(name, parent, size, position, color, material)
	part.Shape = Enum.PartType.Ball
	return part
end

local function makeCylinder(name, parent, size, position, color, material, orientation)
	local part = makePart(name, parent, size, position, color, material)
	part.Shape = Enum.PartType.Cylinder
	if orientation then
		part.Orientation = orientation
	end
	return part
end

local function makeWedge(name, parent, size, position, color, material, orientation)
	local part = Instance.new("WedgePart")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if orientation then
		part.Orientation = orientation
	end
	part.Parent = parent
	return part
end

local function applyLightingPolish()
	Lighting.Brightness = 2.25
	Lighting.ClockTime = 14.6
	Lighting.Ambient = Color3.fromRGB(108, 119, 132)
	Lighting.OutdoorAmbient = Color3.fromRGB(142, 154, 166)
	Lighting.ExposureCompensation = -0.08
	Lighting.EnvironmentDiffuseScale = 0.82
	Lighting.EnvironmentSpecularScale = 0.72
	Lighting.ColorShift_Top = Color3.fromRGB(230, 241, 244)
	Lighting.ColorShift_Bottom = Color3.fromRGB(84, 103, 117)

	local bloom = Lighting:FindFirstChild("Hero City Bloom") or Lighting:FindFirstChild("Kaiju City Bloom") or Instance.new("BloomEffect")
	bloom.Name = "Hero City Bloom"
	bloom.Intensity = 0.08
	bloom.Size = 16
	bloom.Threshold = 1.75
	bloom.Parent = Lighting

	local color = Lighting:FindFirstChild("Hero City Color") or Lighting:FindFirstChild("Kaiju City Color") or Instance.new("ColorCorrectionEffect")
	color.Name = "Hero City Color"
	color.Brightness = 0
	color.Contrast = 0.16
	color.Saturation = 0.18
	color.TintColor = Color3.fromRGB(239, 246, 248)
	color.Parent = Lighting

	local atmosphere = Lighting:FindFirstChild("Hero City Atmosphere") or Lighting:FindFirstChild("Kaiju City Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Name = "Hero City Atmosphere"
	atmosphere.Density = 0.22
	atmosphere.Offset = 0.08
	atmosphere.Color = PolishConfig.Palette.Sky
	atmosphere.Decay = Color3.fromRGB(92, 119, 138)
	atmosphere.Glare = 0.06
	atmosphere.Haze = 0.55
	atmosphere.Parent = Lighting
end

local function addEmitter(part, name, color, texture)
	local attachment = Instance.new("Attachment")
	attachment.Name = name .. " Attachment"
	attachment.Parent = part

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = name
	emitter.Enabled = false
	emitter.LightEmission = 0.35
	emitter.Lifetime = NumberRange.new(0.28, 0.58)
	emitter.Rate = 0
	emitter.Speed = NumberRange.new(8, 16)
	emitter.SpreadAngle = Vector2.new(55, 55)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.38),
		NumberSequenceKeypoint.new(0.45, 0.9),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.04),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Color = ColorSequence.new(color)
	if texture then
		emitter.Texture = texture
	end
	emitter.Parent = attachment
	return emitter
end

local function emitNamed(part, name, count)
	local attachment = part:FindFirstChild(name .. " Attachment")
	local emitter = attachment and attachment:FindFirstChild(name)
	if emitter then
		emitter:Emit(count)
	end
end

local function addSound(part, name, soundId, volume, playbackSpeed)
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = soundId
	sound.Volume = volume or 0.6
	sound.PlaybackSpeed = playbackSpeed or 1
	sound.RollOffMaxDistance = 90
	sound.RollOffMinDistance = 8
	sound.Parent = part
	return sound
end

local function playNamedSound(part, name, pitch)
	local sound = part and part:FindFirstChild(name)
	if sound and sound:IsA("Sound") then
		sound.PlaybackSpeed = pitch or sound.PlaybackSpeed
		sound.TimePosition = 0
		sound:Play()
	end
end

local function sendFeedback(player, payload)
	if player then
		feedbackRemote:FireClient(player, payload)
	end
end

local function broadcastFeedback(payload)
	for _, player in ipairs(Players:GetPlayers()) do
		sendFeedback(player, payload)
	end
end

local function createGuidePath()
	for index, position in ipairs({
		Vector3.new(-38, 0.18, 8),
		Vector3.new(-44, 0.18, 18),
		Vector3.new(-32, 0.18, 22),
		Vector3.new(-16, 0.18, 10),
		Vector3.new(-2, 0.18, -10),
	}) do
		local pad = makePart("Road Guide Stripe " .. index, guideFolder, Vector3.new(10, 0.12, 1.1), position, PolishConfig.Palette.RoadLine, Enum.Material.SmoothPlastic)
		pad.Orientation = Vector3.new(0, -22, 0)
		pad:SetAttribute("TextureStyle", "RoadPaint")
		local arrow = makeWedge("Road Direction Arrow " .. index, guideFolder, Vector3.new(4, 0.22, 5), position + Vector3.new(5, 0.16, -2), PolishConfig.Palette.PathEdge, Enum.Material.SmoothPlastic, Vector3.new(0, -22, 0))
		arrow:SetAttribute("TextureStyle", "RoadPaint")
	end
end

local function makeCoinStack(parent, position)
	for index = 1, 4 do
		local coin = makeCylinder("Bank Coin Stack " .. index, parent, Vector3.new(0.35, 3.2, 3.2), position + Vector3.new(0, 0.18 * index, 0), Color3.fromRGB(214, 166, 51), Enum.Material.Metal, Vector3.new(0, 0, 90))
		coin:SetAttribute("PolishFallback", "Source-built bank coin stack")
	end
end

local function makeRockCluster(parent, basePosition, color)
	makeRubblePile(parent, basePosition, "Street Rubble")
end

applyLightingPolish()

local function formatNumber(value)
	local abs = math.abs(value)
	if abs >= 1e12 then
		return string.format("%.1fT", value / 1e12)
	elseif abs >= 1e9 then
		return string.format("%.1fB", value / 1e9)
	elseif abs >= 1e6 then
		return string.format("%.1fM", value / 1e6)
	elseif abs >= 1e3 then
		return string.format("%.1fK", value / 1e3)
	end
	return tostring(math.floor(value + 0.5))
end

local function playerStat(player, name)
	local stats = player:FindFirstChild("RPGStats")
	local value = stats and stats:FindFirstChild(name)
	if value then
		return value
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	return leaderstats and leaderstats:FindFirstChild(name)
end

local function notify(player, message, color)
	notifyRemote:FireClient(player, message, color or Color3.fromRGB(255, 235, 140))
end

local function broadcast(message, color)
	for _, player in ipairs(Players:GetPlayers()) do
		notify(player, message, color)
	end
end

local function numericPlayerStat(player, name, fallback)
	for _, folderName in ipairs({ "RPGStats", "leaderstats" }) do
		local folder = player:FindFirstChild(folderName)
		local value = folder and folder:FindFirstChild(name)
		if value and value:IsA("NumberValue") then
			return value.Value
		end
	end
	return fallback or 0
end

local function buildServerLeaderboard()
	local entries = {}
	for _, candidate in ipairs(Players:GetPlayers()) do
		table.insert(entries, {
			userId = candidate.UserId,
			name = candidate.DisplayName,
			depth = math.floor(numericPlayerStat(candidate, "Depth", 0)),
			score = math.floor(numericPlayerStat(candidate, "Score", 0)),
		})
	end
	table.sort(entries, function(left, right)
		if left.depth ~= right.depth then return left.depth > right.depth end
		if left.score ~= right.score then return left.score > right.score end
		return left.userId < right.userId
	end)
	return entries
end

local function syncStats(player)
	local stats = player:FindFirstChild("RPGStats")
	local leaderstats = player:FindFirstChild("leaderstats")
	if not stats or not leaderstats then
		return
	end

	local payload = {}
	for _, folder in ipairs({ leaderstats, stats }) do
		for _, value in ipairs(folder:GetChildren()) do
			if value:IsA("NumberValue") or value:IsA("StringValue") then
				payload[value.Name] = value.Value
			end
		end
	end
	payload.WallXPNeeded = GameConfig.XPForLevel(payload.WallLevel or 1)
	payload.RebirthBonus = 1 + (payload.Rebirths or 0) * 0.25
	payload.MaxCritChance = GameConfig.MaxCritChance
	payload.MaxEquippedPets = GameConfig.MaxEquippedPets
	payload.Rank = GameConfig.RankForDepth(payload.Depth or 0)
	local fullLeaderboard = buildServerLeaderboard()
	payload.RankPosition = math.max(1, #fullLeaderboard)
	for position, entry in ipairs(fullLeaderboard) do
		if entry.userId == player.UserId then payload.RankPosition = position break end
	end
	payload.Leaderboard = {}
	for position = 1, math.min(5, #fullLeaderboard) do
		payload.Leaderboard[position] = fullLeaderboard[position]
	end
	local tutorial = GameConfig.Tutorial[payload.TutorialStep or 1]
	if tutorial then
		tutorial = table.clone(tutorial)
		if (payload.TutorialStep or 1) == 3 then
			local remainingXP = math.max(0, payload.WallXPNeeded - (payload.WallXP or 0))
			local brickXP = math.max(1, GameConfig.WallXP["Brick Wall"] or 1)
			local estimatedBreaks = math.max(1, math.ceil(remainingXP / brickXP))
			tutorial.detail = ("Earn %s more Wall XP | about %d Brick break%s"):format(formatNumber(remainingXP), estimatedBreaks, estimatedBreaks == 1 and "" or "s")
		end
	end
	payload.Tutorial = tutorial
	payload.FistCatalog = GameConfig.Fists
	payload.PetCatalog = GameConfig.Pets
	payload.Rewards = GameConfig.Rewards
	payload.StudioTestMode = player:GetAttribute("StudioHighPowerTestMode") == true
	payload.ShopBoosts = {
		CoinEndsAt = player:GetAttribute("CoinBoostExpiresAt") or 0,
		DamageEndsAt = player:GetAttribute("DamageBoostExpiresAt") or 0,
		SpeedEndsAt = player:GetAttribute("SpeedBoostExpiresAt") or 0,
	}
	statRemote:FireClient(player, payload)
end

local function loadPlayerData(player)
	if not playerStore then
		return {}
	end

	local ok, data = pcall(function()
		return playerStore:GetAsync(tostring(player.UserId))
	end)
	if ok and data == nil and legacyPlayerStore then
		local legacyOk, legacyData = pcall(function()
			return legacyPlayerStore:GetAsync(tostring(player.UserId))
		end)
		if legacyOk and type(legacyData) == "table" then
			data = legacyData
			data.DataVersion = 1
		end
	end

	if ok and type(data) == "table" then
		return data
	end

	if not ok then
		warn(("[PunchWallRPG] DataStore load failed for %s: %s"):format(player.Name, tostring(data)))
	end
	return {}
end

local function savedNumber(savedData, name)
	local value = savedData[name]
	if type(value) == "number" then
		return value
	end
	return NUMBER_STAT_DEFAULTS[name]
end

local function savedText(savedData, name)
	local value = savedData[name]
	if type(value) == "string" then
		return value
	end
	return TEXT_STAT_DEFAULTS[name]
end

local function applyKaijuGrowth(player)
	local character = player.Character
	local levelValue = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("WallLevel")
	if not character or not levelValue then return end
	local scale = 1 + math.min(math.max(levelValue.Value - 1, 0), 54) * 0.006
	pcall(function() character:ScaleTo(scale) end)
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart then
		local aura = rootPart:FindFirstChild("Kaiju Growth Aura") or Instance.new("ParticleEmitter")
		aura.Name = "Kaiju Growth Aura"
		aura.Enabled = levelValue.Value >= 8
		aura.Rate = math.clamp(levelValue.Value / 3, 3, 18)
		aura.Lifetime = NumberRange.new(0.5, 0.9)
		aura.Speed = NumberRange.new(0.4, 1.2)
		aura.SpreadAngle = Vector2.new(180, 30)
		aura.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
		aura.Color = ColorSequence.new(levelValue.Value >= 30 and Color3.fromRGB(232, 75, 52) or Color3.fromRGB(82, 178, 213))
		aura.Parent = rootPart
	end
end

local function ensureStats(player)
	player.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Invisicam
	player:SetAttribute("PreserveTunnelCameraZoom", true)
	if not player:GetAttribute("DepthCollisionGroupHooked") then
		player:SetAttribute("DepthCollisionGroupHooked", true)
		player.CharacterAdded:Connect(function(character)
			applyCharacterCollisionGroup(character)
			if (player:GetAttribute("SpeedBoostExpiresAt") or 0) > workspace:GetServerTimeNow() then
				local humanoid = character:WaitForChild("Humanoid", 5)
				if humanoid then humanoid.WalkSpeed = 24 end
			end
		end)
	end
	if player.Character then applyCharacterCollisionGroup(player.Character) end
	if player:FindFirstChild("RPGStats") and player:FindFirstChild("leaderstats") then
		syncStats(player)
		return
	end

	local savedData = loadPlayerData(player)

	local stats = Instance.new("Folder")
	stats.Name = "RPGStats"
	stats.Parent = player

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local function number(name, value, parent)
		local instance = Instance.new("NumberValue")
		instance.Name = name
		instance.Value = value
		instance.Parent = parent or stats
		instance.Changed:Connect(function()
			syncStats(player)
			if name == "WallLevel" then applyKaijuGrowth(player) end
			if name == "Depth" or name == "Score" then
				task.defer(function()
					for _, otherPlayer in ipairs(Players:GetPlayers()) do
						if otherPlayer ~= player then syncStats(otherPlayer) end
					end
				end)
			end
		end)
		return instance
	end

	local function text(name)
		local instance = Instance.new("StringValue")
		instance.Name = name
		instance.Value = savedText(savedData, name)
		instance.Parent = stats
		instance.Changed:Connect(function()
			syncStats(player)
		end)
		return instance
	end

	for _, name in ipairs(LEADERSTAT_NAMES) do
		number(name, savedNumber(savedData, name), leaderstats)
	end

	for _, name in ipairs(RPG_NUMBER_STAT_NAMES) do
		number(name, savedNumber(savedData, name))
	end

	for _, name in ipairs(RPG_TEXT_STAT_NAMES) do
		text(name)
	end

	local crit = stats:FindFirstChild("CritChance")
	if crit then crit.Value = math.clamp(crit.Value, 0, GameConfig.MaxCritChance) end
	local ownedFists = stats:FindFirstChild("OwnedFistsJSON")
	if ownedFists then
		local ok, decoded = pcall(function() return HttpService:JSONDecode(ownedFists.Value) end)
		if not ok or type(decoded) ~= "table" then
			ownedFists.Value = TEXT_STAT_DEFAULTS.OwnedFistsJSON
		elseif not table.find(decoded, "Starter Glove") then
			table.insert(decoded, 1, "Starter Glove")
			ownedFists.Value = HttpService:JSONEncode(decoded)
		end
	end
	for _, name in ipairs({ "PetInventoryJSON", "EquippedPetsJSON", "DiscoveredPetsJSON", "LockedPetsJSON" }) do
		local value = stats:FindFirstChild(name)
		if value then
			local ok, decoded = pcall(function() return HttpService:JSONDecode(value.Value) end)
			if not ok or type(decoded) ~= "table" then value.Value = "[]" end
		end
	end
	local dailyQuestDate = stats:FindFirstChild("DailyQuestDate")
	if dailyQuestDate and dailyQuestDate.Value ~= os.date("!%Y-%m-%d") then
		stats.DailyBreaks.Value = 0
		stats.DailyQuestClaimed.Value = 0
		dailyQuestDate.Value = os.date("!%Y-%m-%d")
	end
	if not player:GetAttribute("KaijuGrowthConnected") then
		player:SetAttribute("KaijuGrowthConnected", true)
		player.CharacterAdded:Connect(function()
			task.wait(0.5)
			applyKaijuGrowth(player)
		end)
	end
	task.defer(function() applyKaijuGrowth(player) end)

	task.defer(function()
		syncStats(player)
		notify(player, "Hero City online. TRAIN to power up, then PUNCH through the city targets.")
	end)
end

local function statValue(player, name, fallback)
	local value = playerStat(player, name)
	if value then
		return value.Value
	end
	return fallback or 0
end

local function setStat(player, name, amount)
	local value = playerStat(player, name)
	if value then
		value.Value = amount
	end
end

shared.PunchWallStudioTest = {
	snapshots = {},
	values = { Power = 1500000000, Coins = 1000000000, WallLevel = 99, FistMastery = 500, CritChance = 25 },
}

function shared.PunchWallStudioTest.set(player, enabled)
	if not RunService:IsStudio() then return false end
	if enabled and not shared.PunchWallStudioTest.snapshots[player] then
		local snapshot = {}
		for name in pairs(shared.PunchWallStudioTest.values) do snapshot[name] = statValue(player, name, 0) end
		shared.PunchWallStudioTest.snapshots[player] = snapshot
		for name, value in pairs(shared.PunchWallStudioTest.values) do setStat(player, name, value) end
		player:SetAttribute("StudioHighPowerTestMode", true)
		notify(player, "HIGH POWER TEST ENABLED", Color3.fromRGB(255, 191, 51))
	elseif not enabled and shared.PunchWallStudioTest.snapshots[player] then
		for name, value in pairs(shared.PunchWallStudioTest.snapshots[player]) do setStat(player, name, value) end
		shared.PunchWallStudioTest.snapshots[player] = nil
		player:SetAttribute("StudioHighPowerTestMode", false)
		notify(player, "HIGH POWER TEST RESTORED", Color3.fromRGB(73, 209, 255))
	else
		player:SetAttribute("StudioHighPowerTestMode", enabled == true)
	end
	syncStats(player)
	return player:GetAttribute("StudioHighPowerTestMode") == true
end

local function addStat(player, name, amount)
	setStat(player, name, statValue(player, name) + amount)
end

local function decodeList(player, statName)
	local raw = statValue(player, statName, "[]")
	if type(raw) ~= "string" then
		return {}
	end
	local ok, value = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	return ok and type(value) == "table" and value or {}
end

local function encodeList(player, statName, value)
	setStat(player, statName, HttpService:JSONEncode(value))
end

local function listContains(list, value)
	for _, current in ipairs(list) do
		if current == value then
			return true
		end
	end
	return false
end

local function removeFirst(list, value)
	for index, current in ipairs(list) do
		if current == value then
			table.remove(list, index)
			return true
		end
	end
	return false
end

local function advanceTutorial(player, completedStep)
	local current = math.floor(statValue(player, "TutorialStep", 1))
	if current == completedStep then
		setStat(player, "TutorialStep", math.min(#GameConfig.Tutorial, current + 1))
	end
end

local function awardWallXP(player, amount)
	local level = math.max(1, math.floor(statValue(player, "WallLevel", 1)))
	local xp = math.max(0, statValue(player, "WallXP", 0) + amount)
	local gained = 0
	while level < 99 do
		local needed = GameConfig.XPForLevel(level)
		if xp < needed then
			break
		end
		xp -= needed
		level += 1
		gained += 1
	end
	setStat(player, "WallXP", xp)
	setStat(player, "WallLevel", level)
	if level >= 3 then
		advanceTutorial(player, 3)
	end
	if gained > 0 then
		sendFeedback(player, {
			type = "LevelUp",
			target = tostring(level),
			color = PolishConfig.Palette.Reward,
		})
	end
	return gained
end

local function collectPlayerData(player)
	local data = { DataVersion = GameConfig.DataVersion }
	for _, name in ipairs(LEADERSTAT_NAMES) do
		data[name] = statValue(player, name, NUMBER_STAT_DEFAULTS[name])
	end
	for _, name in ipairs(RPG_NUMBER_STAT_NAMES) do
		data[name] = statValue(player, name, NUMBER_STAT_DEFAULTS[name])
	end
	for _, name in ipairs(RPG_TEXT_STAT_NAMES) do
		data[name] = tostring(statValue(player, name, TEXT_STAT_DEFAULTS[name]))
	end
	return data
end

local function savePlayerData(player)
	if not playerStore or savingPlayers[player] or player:GetAttribute("StudioHighPowerTestMode") or not player:FindFirstChild("RPGStats") then
		return
	end

	savingPlayers[player] = true
	local data = collectPlayerData(player)
	local ok = false
	local err
	for attempt = 1, 3 do
		ok, err = pcall(function()
			playerStore:UpdateAsync(tostring(player.UserId), function(previous)
				local merged = type(previous) == "table" and previous or {}
				for key, value in pairs(data) do
					merged[key] = value
				end
				merged.DataVersion = GameConfig.DataVersion
				return merged
			end)
		end)
		if ok then
			break
		end
		task.wait(attempt * 0.35)
	end
	savingPlayers[player] = nil

	if not ok then
		warn(("[PunchWallRPG] DataStore save failed for %s: %s"):format(player.Name, tostring(err)))
	end
end

local base = makePart("Downtown Smash Block", root, Vector3.new(280, 3, 150), Vector3.new(55, -1.5, 0), PolishConfig.Palette.Ground, Enum.Material.Asphalt)
base.Locked = true

local islandEdge = makePart("City Block Concrete Edge", polishFolder, Vector3.new(284, 0.6, 154), Vector3.new(55, -3.15, 0), PolishConfig.Palette.GroundDark, Enum.Material.Concrete)
islandEdge.Locked = true
local metroFoundation = makePart("Metro Foundation Horizon", decorFolder, Vector3.new(620, 5, 620), Vector3.new(55, -7, 0), PolishConfig.Palette.GroundDark, Enum.Material.Concrete)
metroFoundation.Locked = true
metroFoundation:SetAttribute("VisualRole", "CityHorizonFoundation")

makePart("Main Avenue Asphalt", decorFolder, Vector3.new(222, 0.18, 30), Vector3.new(48, 0.12, -27), PolishConfig.Palette.Asphalt, Enum.Material.Asphalt)
makePart("Training Sidewalk", decorFolder, Vector3.new(78, 0.22, 24), Vector3.new(-43, 0.18, 24), Color3.fromRGB(132, 142, 146), Enum.Material.Concrete)
makePart("Shop Sidewalk", decorFolder, Vector3.new(80, 0.22, 24), Vector3.new(-43, 0.19, -9), Color3.fromRGB(132, 142, 146), Enum.Material.Concrete)
makePart("Boss Service Road", decorFolder, Vector3.new(70, 0.18, 32), Vector3.new(138, 0.14, 27), PolishConfig.Palette.Asphalt, Enum.Material.Asphalt)
for x = -60, 174, 18 do
	addRoadMarking("Avenue Dashed Center " .. x, Vector3.new(x, 0.28, -27), Vector3.new(8, 0.08, 0.7), PolishConfig.Palette.RoadLine)
end
for index, x in ipairs({ -58, -28, 4, 36, 68, 100, 132, 164 }) do
	local curbAccent = addRoadMarking("Hero Curb Accent " .. index, Vector3.new(x, 0.31, -43.2), Vector3.new(12, 0.09, 0.38), index % 2 == 0 and PolishConfig.Palette.HeroCyan or PolishConfig.Palette.HeroRed)
	curbAccent:SetAttribute("VisualRole", "HeroCityRoadDetail")
end
for index, x in ipairs({ -50, -46, -42, -38, -34, -30 }) do
	addRoadMarking("Spawn Crosswalk " .. index, Vector3.new(x, 0.3, -9.5), Vector3.new(2.2, 0.08, 12), PolishConfig.Palette.PathEdge)
end

makePart("Spawn Pad", root, Vector3.new(18, 1, 18), Vector3.new(-2, 1, -18), Color3.fromRGB(34, 49, 65), Enum.Material.DiamondPlate)
local spawn = Instance.new("SpawnLocation")
spawn.Name = "Punch Rookie Spawn"
spawn.Anchored = true
spawn.Size = Vector3.new(10, 1, 10)
spawn.Position = Vector3.new(-2, 2, -18)
-- Face the initial character toward the depth course. This is only the spawn
-- facing direction; the camera remains player-controlled and uses Invisicam.
spawn.Orientation = Vector3.new(0, 0, 0)
spawn.Color = PolishConfig.Palette.HeroCyan
spawn.Material = Enum.Material.DiamondPlate
spawn.Neutral = true
spawn.Parent = root

for _, boundary in ipairs({
	{ name = "North Safety Barrier", size = Vector3.new(280, 3.2, 1), position = Vector3.new(55, 1.1, -74) },
	{ name = "South Safety Barrier", size = Vector3.new(280, 3.2, 1), position = Vector3.new(55, 1.1, 74) },
	{ name = "West Safety Barrier", size = Vector3.new(1, 3.2, 148), position = Vector3.new(-84, 1.1, 0) },
	{ name = "East Safety Barrier", size = Vector3.new(1, 3.2, 148), position = Vector3.new(194, 1.1, 0) },
}) do
	local barrier = makePart(boundary.name, decorFolder, boundary.size, boundary.position, Color3.fromRGB(67, 70, 72), Enum.Material.Concrete)
	barrier:SetAttribute("VisualRole", "CitySafetyBoundary")
end

local fallRecovery = makePart("Fall Recovery Zone", root, Vector3.new(420, 1, 320), Vector3.new(55, -35, 0), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic)
fallRecovery.Transparency = 1
fallRecovery.CanCollide = false
fallRecovery.Touched:Connect(function(hit)
	local character = hit.Parent
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and character.PrimaryPart then
		character:PivotTo(spawn.CFrame + Vector3.new(0, 5, 0))
	end
end)

local spawnRing = makeCylinder("Hero Spawn Ring", decorFolder, Vector3.new(0.35, 22, 22), Vector3.new(-2, 1.65, -18), PolishConfig.Palette.HeroYellow, Enum.Material.Metal, Vector3.new(0, 0, 90))
spawnRing.Transparency = 0.18

local arch = makePart("City Alert Billboard", root, Vector3.new(30, 7.5, 1.0), Vector3.new(-42, 8.2, 42), PolishConfig.Palette.Ink, Enum.Material.Metal)
makeGraphicSurface(arch, GameConfig.GeneratedGraphics.Iteration01SpawnBillboard, "HERO CITY", "TRAIN | POWER UP | DEFEND", Enum.NormalId.Front)
makeGraphicSurface(arch, GameConfig.GeneratedGraphics.Iteration01SpawnBillboard, "HERO DEFENSE NETWORK", "FOLLOW THE YELLOW HERO ROAD", Enum.NormalId.Back)
if PolishConfig.Environment.CityBuildings then
makeCityBuilding("Background Office A", Vector3.new(-76, 14, 48), Vector3.new(12, 28, 12), Color3.fromRGB(75, 94, 111), Color3.fromRGB(48, 166, 211), -8)
makeCityBuilding("Background Office B", Vector3.new(-12, 18, 50), Vector3.new(14, 36, 12), Color3.fromRGB(62, 79, 101), Color3.fromRGB(54, 182, 222), 7)
makeCityBuilding("Background Brick Tower", Vector3.new(35, 16, 50), Vector3.new(16, 32, 12), Color3.fromRGB(151, 65, 52), Color3.fromRGB(47, 139, 176), -4)
makeCityBuilding("Distant Glass Tower", Vector3.new(116, 22, 50), Vector3.new(16, 44, 14), Color3.fromRGB(46, 86, 113), Color3.fromRGB(81, 201, 235), 5)
makeCityBuilding("Midtown Hero Center", Vector3.new(158, 18, 55), Vector3.new(22, 36, 18), Color3.fromRGB(68, 78, 92), PolishConfig.Palette.HeroRed, -3)
makeCityBuilding("Metro News Building", Vector3.new(186, 25, -58), Vector3.new(20, 50, 18), Color3.fromRGB(49, 70, 88), PolishConfig.Palette.HeroCyan, 4)
makeCityBuilding("West Rescue Tower", Vector3.new(-78, 22, -58), Vector3.new(18, 44, 18), Color3.fromRGB(91, 62, 65), PolishConfig.Palette.HeroYellow, -5)
for _, building in ipairs({
	{ "West Comic Apartments", Vector3.new(-48, 20, -61), Vector3.new(22, 40, 20), Color3.fromRGB(55, 93, 132), Color3.fromRGB(255, 194, 54), -3 },
	{ "Rescue Media Tower", Vector3.new(-42, 27, -68), Vector3.new(24, 54, 22), Color3.fromRGB(145, 58, 53), Color3.fromRGB(69, 193, 238), 2 },
	{ "Central Hero Offices", Vector3.new(38, 22, -66), Vector3.new(22, 44, 20), Color3.fromRGB(58, 104, 143), Color3.fromRGB(255, 205, 72), -2 },
	{ "Metro Color Block", Vector3.new(49, 29, -72), Vector3.new(25, 58, 22), Color3.fromRGB(53, 75, 111), Color3.fromRGB(61, 201, 244), 3 },
	{ "Downtown Redline", Vector3.new(83, 24, -66), Vector3.new(24, 48, 20), Color3.fromRGB(151, 62, 57), Color3.fromRGB(255, 192, 55), -3 },
	{ "Hero Tech Plaza", Vector3.new(118, 31, -72), Vector3.new(26, 62, 23), Color3.fromRGB(47, 88, 127), Color3.fromRGB(74, 214, 247), 2 },
	{ "East Victory Homes", Vector3.new(151, 23, -64), Vector3.new(22, 46, 20), Color3.fromRGB(174, 82, 51), Color3.fromRGB(255, 211, 76), -2 },
}) do
	makeCityBuilding(building[1], building[2], building[3], building[4], building[5], building[6])
end
for index, config in ipairs({
	{ Vector3.new(-55, 17, -112), Vector3.new(18, 34, 18) },
	{ Vector3.new(-42, 24, -118), Vector3.new(22, 48, 20) },
	{ Vector3.new(50, 19, -114), Vector3.new(18, 38, 18) },
	{ Vector3.new(110, 28, -120), Vector3.new(24, 56, 22) },
	{ Vector3.new(170, 21, -110), Vector3.new(20, 42, 18) },
	{ Vector3.new(-35, 23, 112), Vector3.new(22, 46, 20) },
	{ Vector3.new(35, 18, 118), Vector3.new(18, 36, 18) },
	{ Vector3.new(105, 26, 116), Vector3.new(24, 52, 22) },
	{ Vector3.new(175, 20, 108), Vector3.new(20, 40, 18) },
}) do
	makeSkylineBlock("Distant Skyline " .. index, config[1], config[2], Color3.fromRGB(37 + index * 2, 46 + index * 2, 58 + index * 2), index % 3 == 0 and PolishConfig.Palette.HeroYellow or PolishConfig.Palette.HeroCyan)
end
end
makeStreetLight("Training Street Light", Vector3.new(-69, 0.4, 14))
makeStreetLight("Shop Street Light", Vector3.new(-18, 0.4, -15))
for index, position in ipairs({ Vector3.new(12, 0.4, -44), Vector3.new(54, 0.4, -44), Vector3.new(96, 0.4, -44), Vector3.new(138, 0.4, -44), Vector3.new(176, 0.4, -44) }) do
	makeStreetLight("Progression Street Light " .. index, position)
end
for index, car in ipairs({
	{ Vector3.new(18, 1.2, 7), Color3.fromRGB(220, 48, 43) },
	{ Vector3.new(72, 1.2, 7), Color3.fromRGB(35, 139, 219) },
	{ Vector3.new(145, 1.2, 6), Color3.fromRGB(238, 176, 38) },
}) do
	local body = makePart("Hero City Parked Car " .. index, decorFolder, Vector3.new(9, 2.2, 4.6), car[1], car[2], Enum.Material.Metal)
	body.CanCollide = false
	body:SetAttribute("VisualRole", "StreetVehicle")
	local cabin = makePart("Hero City Car Cabin " .. index, decorFolder, Vector3.new(4.8, 1.7, 4.1), car[1] + Vector3.new(0, 1.7, 0), Color3.fromRGB(47, 76, 93), Enum.Material.Glass)
	cabin.CanCollide = false
	for wheel = -1, 1, 2 do
		local frontWheel = makeCylinder("Hero Car Wheel " .. index .. "A" .. wheel, decorFolder, Vector3.new(0.8, 1.5, 1.5), car[1] + Vector3.new(wheel * 3, -0.8, -2.2), Color3.fromRGB(24, 26, 28), Enum.Material.Rubber, Vector3.new(90, 0, 0))
		frontWheel.CanCollide = false
		local rearWheel = makeCylinder("Hero Car Wheel " .. index .. "B" .. wheel, decorFolder, Vector3.new(0.8, 1.5, 1.5), car[1] + Vector3.new(wheel * 3, -0.8, 2.2), Color3.fromRGB(24, 26, 28), Enum.Material.Rubber, Vector3.new(90, 0, 0))
		rearWheel.CanCollide = false
	end
end
createGuidePath()
if PolishConfig.Environment.CityGroundOverlays then
for row, z in ipairs({ -18, -9, 0 }) do
	for column = 1, 24 do
		local x = -31 + (column - 1) * 9 + (row % 2 == 0 and 4.5 or 0)
		local shade = 148 + ((row + column) % 4) * 8
		local tile = makePart(("Hero Plaza Paver %02d_%02d"):format(row, column), decorFolder, Vector3.new(8.65, 0.16, 8.5), Vector3.new(x, 0.08, z), Color3.fromRGB(shade, shade + 3, shade + 5), Enum.Material.Concrete)
		tile.CanCollide = false
		tile:SetAttribute("VisualRole", "CombatPlazaPaver")
	end
end
end
for index, config in ipairs({
	{ Vector3.new(-21, 0.5, -13), 0 },
	{ Vector3.new(17, 0.5, -41), 0 },
	{ Vector3.new(61, 0.5, -13), 0 },
	{ Vector3.new(103, 0.5, -41), 0 },
}) do
	makeEmergencyBarricade("Emergency Barricade " .. index, config[1], config[2])
end
if PolishConfig.Environment.CityGroundOverlays then
for index, position in ipairs({
	Vector3.new(-4, 0.29, -27),
	Vector3.new(38, 0.29, -27),
	Vector3.new(80, 0.29, -27),
	Vector3.new(122, 0.29, -27),
}) do
	local scorch = makeCylinder("Hero Impact Scorch " .. index, decorFolder, Vector3.new(0.08, 8 + index, 8 + index), position, Color3.fromRGB(14, 16, 20), Enum.Material.Asphalt, Vector3.new(0, 0, 90))
	scorch.CanCollide = false
	scorch.Transparency = 0.12
end
end
local defenseBillboard = makePart("Titan District Generated Billboard", decorFolder, Vector3.new(30, 7.5, 0.8), Vector3.new(112, 12, 56), PolishConfig.Palette.Ink, Enum.Material.Metal)
makeGraphicSurface(defenseBillboard, GameConfig.GeneratedGraphics.Iteration01Billboard, "HERO ALERT: TITAN DISTRICT", "TEAM BATTLE | CONTAINMENT ACTIVE", Enum.NormalId.Front)
makeRockCluster(decorFolder, Vector3.new(-68, 0.4, 4), Color3.fromRGB(116, 169, 152))
makeRockCluster(decorFolder, Vector3.new(-22, 0.4, -34), Color3.fromRGB(116, 169, 152))
makeCoinStack(decorFolder, Vector3.new(-55, 1.1, -6))

task.spawn(function()
	if workspace:FindFirstChild("CuratedVisualAssets") then return end
	for _, candidate in ipairs(PolishConfig.FreeAssetCandidates) do
		if candidate.assetId == "3346479763" then
			tryInsertVisualAsset(candidate, Vector3.new(38, 8, -112), 0.105, 90)
			tryInsertVisualAsset(candidate, Vector3.new(122, 8, 112), 0.105, -90)
		elseif candidate.assetId == "7935361972" then
			tryInsertVisualAsset(candidate, Vector3.new(178, 0.4, 58), 0.11)
		elseif candidate.assetId == "44147935" then
			tryInsertVisualAsset(candidate, Vector3.new(180, 0.4, -58), 0.16)
		elseif candidate.assetId == "74466546814963" then
			tryInsertVisualAsset(candidate, Vector3.new(8, 1.3, 39), 0.08)
		elseif candidate.assetId == "5618903358" then
			tryInsertVisualAsset(candidate, Vector3.new(-58, 3.2, 31), 0.07)
		elseif candidate.assetId == "135834344041946" then
			tryInsertVisualAsset(candidate, Vector3.new(178, 20, 55), 0.29)
		end
	end
end)

local wallConfigs = {
	{
		name = "Brick Wall",
		displayName = "Forest Stone",
		depth = 1,
		-- The first excavation block is deliberately a one-hit teaching beat.
		-- A fresh player starts at 15 Power and should immediately see a breach.
		hp = 8,
		level = 1,
		coins = 45,
		power = 3,
		score = 120,
		pos = Vector3.new(-2, 6, -32),
		color = Color3.fromRGB(116, 122, 128),
		material = Enum.Material.Rock,
	},
	{
		name = "Concrete Wall",
		depth = 2,
		hp = 900,
		level = 3,
		coins = 180,
		power = 10,
		score = 500,
		pos = Vector3.new(-2, 6, -62),
		color = Color3.fromRGB(150, 154, 160),
		material = Enum.Material.Concrete,
	},
	{
		name = "Iron Wall",
		depth = 3,
		hp = 6500,
		level = 8,
		coins = 980,
		power = 45,
		score = 1800,
		pos = Vector3.new(-2, 6, -92),
		color = Color3.fromRGB(97, 109, 122),
		material = Enum.Material.Metal,
	},
	{
		name = "Crystal Wall",
		depth = 4,
		hp = 42000,
		level = 16,
		coins = 5200,
		power = 230,
		score = 6200,
		pos = Vector3.new(-2, 6, -122),
		color = Color3.fromRGB(88, 220, 245),
		material = Enum.Material.Glass,
	},
	{
		name = "Lava Wall",
		depth = 5,
		hp = 220000,
		level = 30,
		coins = 28000,
		power = 1100,
		score = 22000,
		pos = Vector3.new(-2, 6, -152),
		color = Color3.fromRGB(255, 96, 45),
		material = Enum.Material.Neon,
	},
	{
		name = "Cyber Gate",
		depth = 6,
		hp = 1200000,
		level = 48,
		coins = 160000,
		power = 5500,
		score = 80000,
		pos = Vector3.new(-2, 6, -182),
		color = Color3.fromRGB(75, 115, 255),
		material = Enum.Material.ForceField,
	},
	{
		name = "Titan Alloy Gate",
		style = "Iron Wall",
		depth = 7,
		hp = 4800000,
		level = 60,
		coins = 420000,
		power = 15000,
		score = 250000,
		xp = 12000,
		pos = Vector3.new(-2, 6, -212),
		color = Color3.fromRGB(82, 92, 105),
		material = Enum.Material.CorrodedMetal,
	},
	{
		name = "Meteor Core Gate",
		style = "Lava Wall",
		depth = 8,
		hp = 18000000,
		level = 70,
		coins = 1400000,
		power = 45000,
		score = 700000,
		xp = 30000,
		pos = Vector3.new(-2, 6, -242),
		color = Color3.fromRGB(185, 66, 42),
		material = Enum.Material.CrackedLava,
	},
	{
		name = "Void Crystal Gate",
		style = "Crystal Wall",
		depth = 9,
		hp = 65000000,
		level = 82,
		coins = 5000000,
		power = 150000,
		score = 2000000,
		xp = 70000,
		pos = Vector3.new(-2, 6, -272),
		color = Color3.fromRGB(88, 118, 212),
		material = Enum.Material.Glass,
	},
	{
		name = "Omega Barrier",
		style = "Cyber Gate",
		depth = 10,
		hp = 220000000,
		level = 94,
		coins = 18000000,
		power = 500000,
		score = 6000000,
		xp = 150000,
		pos = Vector3.new(-2, 6, -302),
		color = Color3.fromRGB(75, 115, 255),
		material = Enum.Material.ForceField,
	},
}

local depthCorridorFolder = Instance.new("Folder")
depthCorridorFolder.Name = "Depth Corridor"
depthCorridorFolder.Parent = polishFolder
local corridorFloor = makePart("Depth Corridor Floor", depthCorridorFolder, Vector3.new(56, 0.5, 380), Vector3.new(-2, 0.05, -165), Color3.fromRGB(117, 121, 116), Enum.Material.Pavement)
corridorFloor:SetAttribute("VisualRole", "DepthProgressionFloor")
for _, sideX in ipairs({ -31, 27 }) do
	local sideWall = makePart("Depth Corridor Side " .. tostring(sideX), depthCorridorFolder, Vector3.new(2, 1.2, 380), Vector3.new(sideX, 0.6, -165), Color3.fromRGB(47, 53, 60), Enum.Material.Concrete)
	sideWall:SetAttribute("VisualRole", "DepthCorridorBoundary")
end
for _, config in ipairs(wallConfigs) do
	local marker = makePart(("Tier %02d Roadside Marker"):format(config.depth), depthCorridorFolder, Vector3.new(5.4, 3.4, 0.45), Vector3.new(24.6, 2.25, config.pos.Z + 6), Color3.fromRGB(21, 27, 33), Enum.Material.Metal)
	marker.CanCollide = false
	marker:SetAttribute("VisualRole", "DepthRoadsideMarker")
	makeText(marker, ("TIER %02d"):format(config.depth), ("DEPTH %02d-%02d | LV. %d"):format((config.depth - 1) * 3 + 1, config.depth * 3, config.level), Enum.NormalId.Front)
	for _, sideX in ipairs({ -28.5, 24.5 }) do
		local guideLight = makePart(("Depth %02d Guide Light %s"):format(config.depth, tostring(sideX)), depthCorridorFolder, Vector3.new(0.45, 0.45, 5), Vector3.new(sideX, 1.1, config.pos.Z + 8), config.color, Enum.Material.Neon)
		guideLight.CanCollide = false
		guideLight:SetAttribute("VisualRole", "DepthGuideLight")
	end
end

local forestFolder = Instance.new("Folder")
forestFolder.Name = "World 1 Forest"
forestFolder.Parent = polishFolder
forestFolder:SetAttribute("WorldTheme", "NaturalForest")
for _, groundInfo in ipairs({
	{ name = "Forest Ground West", size = Vector3.new(76, 1.2, 390), position = Vector3.new(-68, -0.25, -165) },
	{ name = "Forest Ground East", size = Vector3.new(76, 1.2, 390), position = Vector3.new(64, -0.25, -165) },
}) do
	local ground = makePart(groundInfo.name, forestFolder, groundInfo.size, groundInfo.position, Color3.fromRGB(66, 116, 61), Enum.Material.Grass)
	ground:SetAttribute("VisualRole", "ForestGround")
end

-- Keep this in a separate function: the bootstrap chunk is intentionally close to
-- Luau's 200-local limit, while the entry itself should remain source reproducible.
shared.PunchWallForestEntry = function()
	local threshold = makePart("World 1 Forest Trail Threshold", forestFolder, Vector3.new(52, 0.14, 11), Vector3.new(-2, 0.36, -27), Color3.fromRGB(72, 128, 60), Enum.Material.Grass)
	threshold.CanCollide = false
	threshold:SetAttribute("VisualRole", "ForestWorldEntry")
	for _, sideX in ipairs({ -23, 19 }) do
		local post = makePart("Forest Gateway Post " .. tostring(sideX), forestFolder, Vector3.new(2.1, 11, 2.1), Vector3.new(sideX, 5.5, -29), Color3.fromRGB(91, 64, 40), Enum.Material.Wood)
		post.CanCollide = false
		post:SetAttribute("VisualRole", "ForestWorldEntry")
		local crown = makeBall("Forest Gateway Crown " .. tostring(sideX), forestFolder, Vector3.new(8.5, 6.8, 8.5), Vector3.new(sideX, 11.5, -29), Color3.fromRGB(54, 125, 61), Enum.Material.Grass)
		crown.CanCollide = false
		crown:SetAttribute("VisualRole", "ForestWorldEntry")
	end
	-- Keep the world label at the roadside so the first wall remains the focal point.
	local header = makePart("World 1 Forest Gateway", forestFolder, Vector3.new(13, 3.2, 0.6), Vector3.new(-22, 5.6, -28), Color3.fromRGB(20, 46, 31), Enum.Material.WoodPlanks)
	header.CanCollide = false
	header:SetAttribute("VisualRole", "ForestWorldEntry")
	makeText(header, "WORLD 1", "FOREST BREAKTHROUGH", Enum.NormalId.Back)
end
shared.PunchWallForestEntry()

for index = 1, 18 do
	local z = -18 - index * 18
	for _, side in ipairs({ -1, 1 }) do
		local x = -2 + side * (39 + (index % 3) * 8)
		local trunkHeight = 7 + (index % 4)
		local trunk = makePart(("Forest Tree %02d %d Trunk"):format(index, side), forestFolder, Vector3.new(2.2, trunkHeight, 2.2), Vector3.new(x, trunkHeight / 2, z), Color3.fromRGB(92, 65, 42), Enum.Material.Wood)
		trunk.CanCollide = false
		trunk:SetAttribute("VisualRole", "ForestTree")
		for crown = 1, 3 do
			local crownSize = 7.5 + ((index + crown) % 3) * 1.2
			local canopy = makeBall(("Forest Tree %02d %d Crown %d"):format(index, side, crown), forestFolder, Vector3.new(crownSize, crownSize * 0.78, crownSize), Vector3.new(x + (crown - 2) * 2.2, trunkHeight + 1.5 + (crown % 2) * 1.4, z + (crown - 2) * 1.4), index % 2 == 0 and Color3.fromRGB(47, 112, 57) or Color3.fromRGB(57, 128, 64), Enum.Material.Grass)
			canopy.CanCollide = false
			canopy:SetAttribute("VisualRole", "ForestCanopy")
		end
		if index % 3 == 0 then
			for rockIndex = 1, 3 do
				local rock = makeBall(("Forest Rock %02d %d %d"):format(index, side, rockIndex), forestFolder, Vector3.new(2.4 + rockIndex * 0.55, 1.7 + rockIndex * 0.35, 2.1 + rockIndex * 0.45), Vector3.new(x + side * (3 + rockIndex), 0.75, z + (rockIndex - 2) * 2.2), Color3.fromRGB(87, 96, 91), Enum.Material.Rock)
				rock.CanCollide = false
				rock:SetAttribute("VisualRole", "ForestRock")
			end
		end
	end
end

local wallDamageParts = {}
local wallVisualDetails = {}
local wallMasonryParts = {}
local wallContributions = {}
local wallDebris = {}

local function wallStyle(name)
	return PolishConfig.WallTiers[name] or {
		color = Color3.fromRGB(210, 210, 210),
		accent = PolishConfig.Palette.Reward,
		pad = PolishConfig.Palette.Path,
		crack = Color3.fromRGB(70, 70, 90),
	}
end

local function updateWallDamage(wall)
	local cracks = wallDamageParts[wall]
	if not cracks then
		return
	end
	local hp = wall:GetAttribute("HP") or 0
	local maxHp = wall:GetAttribute("MaxHP") or 1
	local ratio = hp / maxHp
	local stage = 0
	if ratio <= 0.25 then
		stage = 3
	elseif ratio <= 0.5 then
		stage = 2
	elseif ratio <= 0.75 then
		stage = 1
	end
	wall:SetAttribute("DamageStage", stage)
	for index, crack in ipairs(cracks) do
		crack.Transparency = index <= stage and 0.12 or 1
	end
	for _, brick in ipairs(wallMasonryParts[wall] or {}) do
		local row = brick:GetAttribute("MasonryRow") or 0
		local column = brick:GetAttribute("MasonryColumn") or 0
		local centerRow = ((wall:GetAttribute("MasonryRows") or 6) + 1) / 2
		local centerColumn = ((wall:GetAttribute("MasonryColumns") or 5) + 1) / 2
		local distance = math.abs(row - centerRow) + math.abs(column - centerColumn)
		local damaged = (stage == 1 and distance <= 0.65)
			or (stage == 2 and distance <= 1.7)
			or (stage >= 3 and distance <= 2.65)
		brick.Transparency = damaged and (stage == 1 and 0.48 or stage == 2 and 0.86 or 1) or 0
	end
	if wall:GetAttribute("Broken") ~= true then
		local visibleCount = stage == 3 and 30 or stage == 2 and 16 or stage == 1 and 6 or 0
		for index, debris in ipairs(wallDebris[wall] or {}) do
			if debris.part and debris.part.Parent then
				if index <= visibleCount then
					local angle = index * 2.25
					local radius = 1.4 + (index % 7) * 0.78
					local x = math.cos(angle) * radius
					local y = math.sin(angle) * radius * 0.92
					debris.part.CFrame = wall.CFrame * CFrame.new(x, y, wall.Size.Z / 2 + 1.05) * CFrame.Angles(index * 0.21, index * 0.37, index * 0.16)
					debris.part.Transparency = 0.04
				else
					debris.part.CFrame = debris.baseCFrame
					debris.part.Transparency = 1
				end
			end
		end
	end
end

local function setWallVisualDetailsBroken(wall, isBroken)
	for _, detail in ipairs(wallVisualDetails[wall] or {}) do
		if detail.part and detail.part.Parent then
			local role = detail.part:GetAttribute("PolishRole")
			if isBroken and role == "ModularDestructionBrick" then
				local row = detail.part:GetAttribute("MasonryRow") or 0
				local column = detail.part:GetAttribute("MasonryColumn") or 0
				local centerRow = ((wall:GetAttribute("MasonryRows") or 6) + 1) / 2
				local centerColumn = ((wall:GetAttribute("MasonryColumns") or 5) + 1) / 2
				local centralHole = math.abs(row - centerRow) <= 2.3 and math.abs(column - centerColumn) <= 1.7
				detail.part.Transparency = centralHole and 1 or 0.12
			elseif isBroken and role == "DestructionTargetFrame" then
				detail.part.Transparency = detail.transparency
			elseif isBroken and role == "BreachInterior" then
				detail.part.Transparency = 1
			elseif isBroken and role == "BreakLinkedBuildingDepth" then
				detail.part.Transparency = 1
			else
				detail.part.Transparency = isBroken and math.max(0.82, detail.transparency) or detail.transparency
			end
		end
	end
end

local function setWallLabelsEnabled(wall, enabled)
	for _, descendant in ipairs(wall:GetDescendants()) do
		if descendant:IsA("SurfaceGui") or descendant:IsA("BillboardGui") then
			descendant.Enabled = enabled
		end
	end
end

local function setWallDebrisState(wall, isBroken)
	for index, debris in ipairs(wallDebris[wall] or {}) do
		if debris.part and debris.part.Parent then
			debris.part.CFrame = debris.baseCFrame
			debris.part.Transparency = isBroken and 0 or 1
			if isBroken then
				local side = index % 2 == 0 and 1 or -1
				local direction = Vector3.new(side * (1.4 + (index % 7) * 0.72), -1.2 - (index % 5) * 0.42, 2.4 + (index % 6) * 0.68)
				TweenService:Create(debris.part, TweenInfo.new(0.54, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					CFrame = debris.baseCFrame * CFrame.new(direction) * CFrame.Angles(index * 0.2, index * 0.4, index * 0.13),
					Transparency = 0.08,
				}):Play()
			end
		end
	end
end

local function updateWallText(wall)
	local sign = wall:FindFirstChild("Sign")
	if not sign then
		return
	end
	local title = sign:FindFirstChild("Title")
	local subtitle = sign:FindFirstChild("Subtitle")
	local hp = wall:GetAttribute("HP") or 0
	local maxHp = wall:GetAttribute("MaxHP") or 1
	if title then
		title.Text = wall.Name
	end
	if subtitle then
		subtitle.Text = ("HP %s/%s | Lv %d"):format(formatNumber(hp), formatNumber(maxHp), wall:GetAttribute("RequiredLevel") or 1)
	end
	local physicalSign = wall:FindFirstChild("PhysicalCombatSign")
	local physicalSurface = physicalSign and physicalSign:FindFirstChild("Sign")
	if physicalSurface then
		local physicalTitle = physicalSurface:FindFirstChild("Title")
		local physicalSubtitle = physicalSurface:FindFirstChild("Subtitle")
		if physicalTitle then physicalTitle.Text = ("WALL LV. %d"):format(wall:GetAttribute("RequiredLevel") or 1) end
		if physicalSubtitle then physicalSubtitle.Text = ("HP %s / %s"):format(formatNumber(hp), formatNumber(maxHp)) end
	end
	local combatBillboard = wall:FindFirstChild("WallCombatBillboard")
	if combatBillboard then
		local combatTitle = combatBillboard:FindFirstChild("WallLevel")
		local combatHP = combatBillboard:FindFirstChild("HPText", true)
		local track = combatBillboard:FindFirstChild("HealthTrack")
		local fill = track and track:FindFirstChild("Fill")
		if combatTitle then combatTitle.Text = ("WALL LV. %d"):format(wall:GetAttribute("RequiredLevel") or 1) end
		if combatHP then combatHP.Text = ("%s / %s"):format(formatNumber(hp), formatNumber(maxHp)) end
		if fill then fill.Size = UDim2.fromScale(math.clamp(hp / math.max(1, maxHp), 0, 1), 1) end
	end
end

local function addWallCombatBillboard(wall, level, accent)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "WallCombatBillboard"
	billboard.Enabled = false
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 240
	billboard.Size = UDim2.fromOffset(260, 80)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, wall.Size.Y / 2 - 3.1, 4.1)
	billboard.Adornee = wall
	billboard.Parent = wall
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundColor3 = Color3.fromRGB(15, 19, 24)
	panel.BackgroundTransparency = 0.04
	panel.BorderSizePixel = 0
	panel.Parent = billboard
	local stroke = Instance.new("UIStroke")
	stroke.Color = accent
	stroke.Thickness = 3
	stroke.Parent = panel
	local title = Instance.new("TextLabel")
	title.Name = "WallLevel"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(8, 3)
	title.Size = UDim2.new(1, -16, 0, 27)
	title.Font = Enum.Font.GothamBlack
	title.Text = ("WALL LV. %d"):format(level)
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextSize = 21
	title.TextStrokeTransparency = 0.35
	title.Parent = billboard
	local track = Instance.new("Frame")
	track.Name = "HealthTrack"
	track.Position = UDim2.fromOffset(12, 34)
	track.Size = UDim2.new(1, -24, 0, 28)
	track.BackgroundColor3 = Color3.fromRGB(52, 56, 62)
	track.BorderSizePixel = 0
	track.Parent = billboard
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(235, 52, 46)
	fill.BorderSizePixel = 0
	fill.Parent = track
	local hpText = Instance.new("TextLabel")
	hpText.Name = "HPText"
	hpText.BackgroundTransparency = 1
	hpText.Size = UDim2.fromScale(1, 1)
	hpText.Font = Enum.Font.GothamBlack
	hpText.Text = "0 / 0"
	hpText.TextColor3 = Color3.new(1, 1, 1)
	hpText.TextSize = 16
	hpText.TextStrokeTransparency = 0.15
	hpText.ZIndex = 3
	hpText.Parent = track
	return billboard
end

local function hitWall(player, wall)
	if wall:GetAttribute("Broken") then
		return { ok = false, reason = "respawning" }
	end
	local now = os.clock()
	local lastHit = player:GetAttribute("LastWallHit") or 0
	local cooldown = WALL_HIT_COOLDOWN
	if now - lastHit < cooldown then
		return { ok = false, reason = "cooldown" }
	end
	player:SetAttribute("LastWallHit", now)

	local required = wall:GetAttribute("RequiredLevel") or 1
	if statValue(player, "WallLevel", 1) < required then
		sendFeedback(player, {
			type = "Fail",
			target = wall.Name,
			message = ("Need Lv %d"):format(required),
			color = PolishConfig.Palette.Fail,
		})
		return { ok = false, reason = "level_gate", requiredLevel = required }
	end

	local requiredDepth = wall:GetAttribute("RequiredDepth") or 0
	if statValue(player, "Depth", 0) < requiredDepth then
		sendFeedback(player, {
			type = "Fail",
			target = wall.Name,
			message = ("Clear Depth %d first"):format(requiredDepth),
			color = PolishConfig.Palette.Fail,
		})
		return { ok = false, reason = "depth_gate", requiredDepth = requiredDepth }
	end

	local power = statValue(player, "Power", 1)
	local fist = statValue(player, "FistMultiplier", 1)
	local pet = statValue(player, "PetMultiplier", 0)
	local rebirth = 1 + statValue(player, "Rebirths", 0) * 0.25
	local mastery = 1 + math.min(statValue(player, "FistMastery", 1), 500) * 0.001
	local damage = power * fist * (1 + pet) * rebirth * mastery
	if (player:GetAttribute("DamageBoostExpiresAt") or 0) > workspace:GetServerTimeNow() then damage *= 2 end
	local critChance = math.clamp(statValue(player, "CritChance", 0), 0, GameConfig.MaxCritChance)
	local isCritical = false
	if math.random(1, 100) <= critChance then
		damage *= 2
		isCritical = true
		notify(player, "Critical punch! x2 damage", Color3.fromRGB(255, 236, 94))
	end

	local previousHP = wall:GetAttribute("HP") or 0
	local actualDamage = math.min(previousHP, damage)
	wall:SetAttribute("HP", math.max(0, previousHP - damage))
	wallContributions[wall] = wallContributions[wall] or {}
	wallContributions[wall][player.UserId] = (wallContributions[wall][player.UserId] or 0) + actualDamage
	updateWallText(wall)
	updateWallDamage(wall)
	emitNamed(wall, "Hit Spark", PolishConfig.Motion.HitEmit)
	playNamedSound(wall, "Punch Impact", 0.94 + math.random() * 0.12)

	local originalColor = wall:GetAttribute("OriginalColor") or wall.Color
	local accent = wall:GetAttribute("AccentColor") or PolishConfig.Palette.Crit
	TweenService:Create(wall, TweenInfo.new(0.04), { Color = accent }):Play()
	task.delay(0.06, function()
		if wall.Parent and not wall:GetAttribute("Broken") then
			TweenService:Create(wall, TweenInfo.new(0.1), { Color = originalColor }):Play()
		end
	end)
	sendFeedback(player, {
		type = "Punch",
		target = wall.Name,
		damage = math.floor(damage + 0.5),
		critical = isCritical,
		material = wall.Material.Name,
		color = accent,
	})

	local pulse = TweenService:Create(wall, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = wall.Size + Vector3.new(0.4, 0.4, 0.08) })
	pulse:Play()
	pulse.Completed:Once(function()
		if wall.Parent then
			TweenService:Create(wall, TweenInfo.new(0.1), { Size = wall:GetAttribute("BaseSize") or wall.Size }):Play()
		end
	end)

	if wall:GetAttribute("HP") <= 0 and not wall:GetAttribute("Broken") then
		wall:SetAttribute("Broken", true)
		local reward = wall:GetAttribute("CoinReward") or 0
		local depthReward = wall:GetAttribute("Depth") or 0
		local scoreReward = wall:GetAttribute("ScoreReward") or 0
		local xpReward = wall:GetAttribute("XPReward") or GameConfig.WallXP[wall.Name] or 20
		local contributions = wallContributions[wall] or {}
		local totalContribution = 0
		for _, contribution in pairs(contributions) do
			totalContribution += contribution
		end
		for userId, contribution in pairs(contributions) do
			local contributor = Players:GetPlayerByUserId(userId)
			if contributor and contribution > 0 then
				local share = totalContribution > 0 and contribution / totalContribution or 1
				local contributorCoins = GameConfig.ContributionReward(reward, share)
				if (contributor:GetAttribute("CoinBoostExpiresAt") or 0) > workspace:GetServerTimeNow() then contributorCoins *= 2 end
				addStat(contributor, "Coins", contributorCoins)
				addStat(contributor, "DailyBreaks", 1)
				local contributorScore = math.max(1, math.floor(scoreReward * share + 0.5))
				addStat(contributor, "Score", contributorScore)
				if depthReward > statValue(contributor, "Depth", 0) then
					setStat(contributor, "Depth", depthReward)
				end
				awardWallXP(contributor, xpReward)
				if wall.Name == "Brick Wall" then
					advanceTutorial(contributor, 2)
				end
					sendFeedback(contributor, {
						type = "Reward",
						target = wall.Name,
						wallBreak = true,
					coins = contributorCoins,
					xp = xpReward,
					depth = depthReward,
					score = contributorScore,
					color = PolishConfig.Palette.Reward,
				})
			end
		end
		emitNamed(wall, "Break Burst", PolishConfig.Motion.BreakEmit)
		emitNamed(wall, "Break Dust", 34)
		playNamedSound(wall, "Building Collapse", 0.92 + math.random() * 0.1)

		wall.Transparency = 1
		setWallVisualDetailsBroken(wall, true)
		setWallDebrisState(wall, true)
		setWallLabelsEnabled(wall, false)
		wall.CanCollide = false
		wall:SetAttribute("RespawnAt", workspace:GetServerTimeNow() + WALL_RESPAWN_SECONDS)
		task.delay(WALL_RESPAWN_SECONDS, function()
			if wall.Parent then
				wallContributions[wall] = {}
				wall:SetAttribute("HP", wall:GetAttribute("MaxHP"))
				wall:SetAttribute("Broken", false)
				wall:SetAttribute("RespawnAt", 0)
					wall.Transparency = wall:GetAttribute("OriginalTransparency") or 0.08
					setWallVisualDetailsBroken(wall, false)
					setWallDebrisState(wall, false)
					setWallLabelsEnabled(wall, true)
					wall.CanCollide = true
					updateWallText(wall)
					updateWallDamage(wall)
					emitNamed(wall, "Respawn Shimmer", 14)
				end
			end)

		return { ok = true, outcome = "broken", damage = damage }
	end

	return { ok = true, outcome = "hit", damage = damage, hp = wall:GetAttribute("HP") }
end

local function buildWall(config)
	local style = wallStyle(config.style or config.name)
	local wallSize = Vector3.new(28, 11, 3.2)
	local wall = makePart(config.name, wallsFolder, wallSize, Vector3.new(config.pos.X, 5.75, config.pos.Z), style.color or config.color, style.material or config.material or Enum.Material.Concrete)
	wall:SetAttribute("MaxHP", config.hp)
	wall:SetAttribute("HP", config.hp)
	wall:SetAttribute("RequiredLevel", config.level)
	wall:SetAttribute("Depth", config.depth or 1)
	wall:SetAttribute("RequiredDepth", math.max(0, (config.depth or 1) - 1))
	wall:SetAttribute("ScoreReward", config.score or config.hp)
	wall:SetAttribute("CoinReward", config.coins)
	wall:SetAttribute("PowerReward", 0)
	wall:SetAttribute("XPReward", config.xp or GameConfig.WallXP[config.name] or math.max(20, math.floor((config.depth or 1) * 2500)))
	wall:SetAttribute("Theme", PolishConfig.StyleName)
	wall:SetAttribute("VisualRole", "LayeredDestructionTarget")
	wall:SetAttribute("BaseSize", wall.Size)
	wall:SetAttribute("OriginalColor", wall.Color)
	wall:SetAttribute("OriginalTransparency", 1)
	wall:SetAttribute("AccentColor", style.accent)
	wall:SetAttribute("RespawnAt", 0)
	wall.Transparency = 1
	wallVisualDetails[wall] = {}
	wallMasonryParts[wall] = {}
	local rows = 5
	local columns = 10
	wall:SetAttribute("MasonryRows", rows)
	wall:SetAttribute("MasonryColumns", columns)
	local brickWidth = (wall.Size.X - 1.2) / columns
	local brickHeight = (wall.Size.Y - 1.4) / rows
	for row = 1, rows do
		for column = 1, columns do
			local stagger = row % 2 == 0 and brickWidth * 0.18 or 0
			local x = -wall.Size.X / 2 + 0.6 + brickWidth * (column - 0.5) + stagger
			x = math.clamp(x, -wall.Size.X / 2 + brickWidth * 0.48, wall.Size.X / 2 - brickWidth * 0.48)
			local y = -wall.Size.Y / 2 + 0.7 + brickHeight * (row - 0.5)
			local brickColor = (row + column) % 3 == 0 and style.color:Lerp(Color3.new(0, 0, 0), 0.14) or style.color
			local brick = makeVisualPart(("%s Smash Brick %02d_%02d"):format(config.name, row, column), tierFolder, Vector3.new(brickWidth - 0.18, brickHeight - 0.18, 1.35), wall.CFrame * CFrame.new(x, y, wall.Size.Z / 2 + 0.55), brickColor, style.material or Enum.Material.Brick)
			brick:SetAttribute("PolishRole", "ModularDestructionBrick")
			brick:SetAttribute("MasonryRow", row)
			brick:SetAttribute("MasonryColumn", column)
			table.insert(wallMasonryParts[wall], brick)
			table.insert(wallVisualDetails[wall], { part = brick, transparency = brick.Transparency })
		end
	end
	for _, frameInfo in ipairs({
		{ "Left", Vector3.new(1.3, wall.Size.Y + 3.2, 2.2), Vector3.new(-wall.Size.X / 2 - 0.3, 0, wall.Size.Z / 2 + 0.15) },
		{ "Right", Vector3.new(1.3, wall.Size.Y + 3.2, 2.2), Vector3.new(wall.Size.X / 2 + 0.3, 0, wall.Size.Z / 2 + 0.15) },
		{ "Top", Vector3.new(wall.Size.X + 2, 1.5, 2.2), Vector3.new(0, wall.Size.Y / 2 + 0.85, wall.Size.Z / 2 + 0.15) },
	}) do
		local framePart = makeVisualPart(config.name .. " Destruction Frame " .. frameInfo[1], tierFolder, frameInfo[2], wall.CFrame * CFrame.new(frameInfo[3]), style.color:Lerp(Color3.new(0, 0, 0), 0.2), Enum.Material.Concrete)
		framePart:SetAttribute("PolishRole", "DestructionTargetFrame")
		table.insert(wallVisualDetails[wall], { part = framePart, transparency = framePart.Transparency })
	end
	local breachInterior = makeVisualPart(config.name .. " Breach Interior", tierFolder, Vector3.new(wall.Size.X - 2.1, wall.Size.Y - 2.1, 0.7), wall.CFrame * CFrame.new(0, 0, wall.Size.Z / 2 - 0.35), Color3.fromRGB(12, 15, 19), Enum.Material.Slate)
	breachInterior.Transparency = 0.03
	breachInterior:SetAttribute("PolishRole", "BreachInterior")
	table.insert(wallVisualDetails[wall], { part = breachInterior, transparency = breachInterior.Transparency })
	addWallCombatBillboard(wall, config.level, style.accent)
	updateWallText(wall)
	local hitSpark = addEmitter(wall, "Hit Spark", style.accent, "rbxasset://textures/particles/sparkles_main.dds")
	hitSpark.Parent.Position = Vector3.new(0, 0, wall.Size.Z / 2 + 1.15)
	hitSpark.Lifetime = NumberRange.new(0.34, 0.72)
	hitSpark.Speed = NumberRange.new(13, 25)
	hitSpark.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(0.35, 1.65), NumberSequenceKeypoint.new(1, 0) })
	local breakBurst = addEmitter(wall, "Break Burst", style.accent, "rbxasset://textures/particles/sparkles_main.dds")
	breakBurst.Parent.Position = Vector3.new(0, 0, wall.Size.Z / 2 + 1.15)
	breakBurst.Lifetime = NumberRange.new(0.42, 0.9)
	breakBurst.Speed = NumberRange.new(16, 30)
	local breakDust = addEmitter(wall, "Break Dust", Color3.fromRGB(154, 139, 122))
	breakDust.Parent.Position = Vector3.new(0, 0, wall.Size.Z / 2 + 0.8)
	breakDust.LightEmission = 0
	breakDust.Lifetime = NumberRange.new(0.45, 0.95)
	breakDust.Speed = NumberRange.new(3, 9)
	breakDust.SpreadAngle = Vector2.new(80, 80)
	breakDust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.8), NumberSequenceKeypoint.new(0.45, 4.2), NumberSequenceKeypoint.new(1, 0) })
	local respawnShimmer = addEmitter(wall, "Respawn Shimmer", Color3.fromRGB(255, 255, 255), "rbxasset://textures/particles/sparkles_main.dds")
	respawnShimmer.Parent.Position = Vector3.new(0, 0, wall.Size.Z / 2 + 0.8)
	addSound(wall, "Punch Impact", GameConfig.Audio.Punch, 0.52)
	addSound(wall, "Building Collapse", GameConfig.Audio.Collapse, 0.78)

	local frame = makePart(config.name .. " Street Foundation", tierFolder, Vector3.new(30, 1.1, 7), wall.Position + Vector3.new(0, -wall.Size.Y / 2 - 0.6, 0), style.pad, Enum.Material.Concrete)
	frame:SetAttribute("PolishRole", "WallTierFrame")
	local banner = makePart(config.name .. " Street Level Sign", tierFolder, Vector3.new(16, 3, 0.6), wall.Position + Vector3.new(0, wall.Size.Y / 2 + 2.4, 3.45), Color3.fromRGB(28, 32, 35), Enum.Material.Metal)
	banner.Name = "PhysicalCombatSign"
	banner.Parent = wall
	banner.Transparency = 1
	banner.CanCollide = false
	local debrisPieces = {}
	for index = 1, 30 do
		local x = -6.2 + ((index - 1) % 6) * 2.45
		local y = -wall.Size.Y * 0.34 + math.floor((index - 1) / 6) * 2.15
		local size = Vector3.new(1.1 + (index % 3) * 0.42, 0.9 + (index % 4) * 0.3, 0.78 + (index % 2) * 0.44)
		local baseCFrame = wall.CFrame * CFrame.new(x, y, 3.9) * CFrame.Angles(index * 0.17, index * 0.31, index * 0.11)
		local piece
		if index % 3 == 0 then
			piece = makeWedge(config.name .. " Collapse Chunk " .. index, tierFolder, size, baseCFrame.Position, style.color, style.material or Enum.Material.Concrete)
			piece.CFrame = baseCFrame
		else
			piece = makeVisualPart(config.name .. " Collapse Chunk " .. index, tierFolder, size, baseCFrame, style.color, style.material or Enum.Material.Concrete)
		end
		piece.Transparency = 1
		table.insert(debrisPieces, { part = piece, baseCFrame = piece.CFrame })
	end
	wallDebris[wall] = debrisPieces

	local cracks = {}
	for index, offset in ipairs({
		Vector3.new(-4, 1.5, wall.Size.Z / 2 + 0.12),
		Vector3.new(1, -1.6, wall.Size.Z / 2 + 0.12),
		Vector3.new(5, 2.7, wall.Size.Z / 2 + 0.12),
	}) do
		local crack = makeWedge(config.name .. " Facade Crack " .. index, tierFolder, Vector3.new(0.38, 5.1, 0.22), wall.Position + offset, style.crack, Enum.Material.Concrete, Vector3.new(0, 0, 25 * index))
		crack.Transparency = 1
		crack:SetAttribute("PolishRole", "WallDamageCrack")
		table.insert(cracks, crack)
	end
	wallDamageParts[wall] = cracks
	updateWallDamage(wall)

	local clickDetector = Instance.new("ClickDetector")
	clickDetector.MaxActivationDistance = 34
	clickDetector.Parent = wall

	clickDetector.MouseClick:Connect(function(player)
		hitWall(player, wall)
	end)
end

local depthBlocksFolder = Instance.new("Folder")
depthBlocksFolder.Name = "Depth Blocks"
depthBlocksFolder.Parent = root

local depthDebrisFolder = Instance.new("Folder")
depthDebrisFolder.Name = "Depth Physics Debris"
depthDebrisFolder.Parent = root

local courseEntrance = makePart("Depth Course Entrance", interactFolder, Vector3.new(48, 8, 2), Vector3.new(-2, 4, -25), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
courseEntrance.Transparency = 1
courseEntrance.CanCollide = false
courseEntrance.CanQuery = false
courseEntrance:SetAttribute("VisualRole", "DepthCourseWaypoint")

local DEPTH_BLOCK_SIZE = Vector3.new(4, 4, 4)
local DEPTH_COLUMNS = 12
local DEPTH_ROWS = 3
local DEPTH_LAYERS = 75
local DEPTH_LAYERS_PER_TIER = 8
local depthBlockContributions = {}
local depthBlockAliases = {}

for layer = 1, DEPTH_LAYERS do
	local tier = math.clamp(math.ceil(layer / DEPTH_LAYERS_PER_TIER), 1, #wallConfigs)
	local config = wallConfigs[tier]
	for row = 1, DEPTH_ROWS do
		for column = 1, DEPTH_COLUMNS do
			local x = -2 + (column - (DEPTH_COLUMNS + 1) / 2) * DEPTH_BLOCK_SIZE.X
			local y = (row - 0.5) * DEPTH_BLOCK_SIZE.Y + 0.25
			local z = -37 - (layer - 1) * DEPTH_BLOCK_SIZE.Z
			local shade = ((row + column + layer) % 3) * 0.07
			local color = config.color:Lerp(Color3.new(0, 0, 0), shade)
			local block = makePart(("DepthBlock_L%03d_C%02d_R%02d"):format(layer, column, row), depthBlocksFolder, DEPTH_BLOCK_SIZE, Vector3.new(x, y, z), color, config.material)
			block:SetAttribute("IsDepthBlock", true)
			block:SetAttribute("Depth", layer)
			block:SetAttribute("Tier", tier)
			block:SetAttribute("Column", column)
			block:SetAttribute("Row", row)
			block:SetAttribute("TierName", config.displayName or config.name)
			block:SetAttribute("RequiredLevel", config.level)
			block:SetAttribute("MaxHP", config.hp)
			block:SetAttribute("HP", config.hp)
			block:SetAttribute("ScoreReward", math.max(1, math.floor(config.score / 3)))
			block:SetAttribute("CoinReward", math.max(1, math.floor(config.coins / 4)))
			block:SetAttribute("PowerReward", 0)
			block:SetAttribute("XPReward", math.max(1, math.floor((config.xp or GameConfig.WallXP[config.name] or 20) / 3)))
			block:SetAttribute("OriginalColor", color)
			block:SetAttribute("BaseCFrame", block.CFrame)
			block:SetAttribute("DamageStage", 0)
			block:SetAttribute("Broken", false)
			block:SetAttribute("StructuralDetached", false)
			block:SetAttribute("StructuralFalling", false)
			block:SetAttribute("StructuralFailure", false)
			block:SetAttribute("VisualRole", "SharedExcavationBlock")
		end
	end
end

for tier, config in ipairs(wallConfigs) do
	local layer = (tier - 1) * DEPTH_LAYERS_PER_TIER + 1
	depthBlockAliases[config.name] = depthBlocksFolder:FindFirstChild(("DepthBlock_L%03d_C06_R02"):format(layer))
end

local MAX_DEPTH_PHYSICS_FRAGMENTS = 120

local function spawnDepthBlockFragments(block, player, impactDirection, forceScale)
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local fallback = rootPart and (block.Position - rootPart.Position) or block.CFrame.LookVector
	local outward = typeof(impactDirection) == "Vector3" and impactDirection.Magnitude > 0.01 and impactDirection.Unit
		or (fallback.Magnitude > 0.01 and fallback.Unit or Vector3.new(0, 0, -1))
	local strength = math.clamp(tonumber(forceScale) or 1, 0.7, 3.5)
	local sideAxis = Vector3.yAxis:Cross(outward)
	if sideAxis.Magnitude < 0.01 then sideAxis = block.CFrame.RightVector end
	sideAxis = sideAxis.Unit
	local fragmentCount = math.min(6, math.max(0, MAX_DEPTH_PHYSICS_FRAGMENTS - #depthDebrisFolder:GetChildren()))
	for index = 1, fragmentCount do
		local fragment = Instance.new(index % 3 == 0 and "WedgePart" or "Part")
		fragment.Name = block.Name .. " Server Physics Chunk " .. index
		fragment.Size = Vector3.new(0.78 + (index % 3) * 0.27, 0.72 + (index % 2) * 0.34, 0.82 + ((index + 1) % 3) * 0.28)
		fragment.CFrame = block.CFrame * CFrame.new(((index - 1) % 3 - 1) * 0.74, (math.floor((index - 1) / 3) - 0.5) * 0.72, 0) * CFrame.Angles(index * 0.29, index * 0.43, index * 0.18)
		fragment.CFrame += outward * (block.Size.Z * 0.5 + fragment.Size.Z * 0.5 + 0.08)
		fragment.Color = block.Color
		fragment.Material = block.Material
		fragment.Anchored = false
		fragment.CanCollide = true
		fragment.CollisionGroup = "DepthRubble"
		fragment.CastShadow = true
		fragment.Parent = depthDebrisFolder
		pcall(function() fragment:SetNetworkOwner(nil) end)
		local side = sideAxis * ((index % 2 == 0 and 1 or -1) * (6 + index * 0.9) * strength)
		local lift = Vector3.new(0, (8 + (index % 4) * 2.8) * (0.75 + strength * 0.25), 0)
		local launchVelocity = outward * ((26 + index * 2.4) * strength) + side + lift
		fragment:ApplyImpulse(launchVelocity * fragment.AssemblyMass)
		fragment:ApplyAngularImpulse(Vector3.new(index * 3.7, index * 4.3, index * 3.1) * fragment.AssemblyMass * strength)
		fragment:SetAttribute("InitialForwardSpeed", launchVelocity:Dot(outward))
		fragment:SetAttribute("SpawnFrontOffset", (fragment.Position - block.Position):Dot(outward))
		fragment:SetAttribute("ImpactForceScale", strength)
		task.delay(2.25, function()
			if fragment.Parent then fragment.CanCollide = false end
		end)
		Debris:AddItem(fragment, 4.5)
	end
end

local depthPunch = {
	Radius = 3.25,
	Reach = 7,
	BaseLimit = 8,
	MaxLimit = 48,
	BaseLungeDistance = 10.5,
	MaxLungeDistance = 48,
	LungeClearance = 2.6,
	WindupSeconds = 0.2,
	LungeSeconds = 0.16,
	MaxStructuralFalling = 60,
}
root:SetAttribute("PunchRadius", depthPunch.Radius)
root:SetAttribute("PunchTargetMode", "BodyDirectionFreeAim")
root:SetAttribute("DepthBlockSize", DEPTH_BLOCK_SIZE)
root:SetAttribute("DepthBlockCount", DEPTH_COLUMNS * DEPTH_ROWS * DEPTH_LAYERS)
root:SetAttribute("PunchAttackInterval", WALL_HIT_COOLDOWN)
root:SetAttribute("PunchLungeDistance", depthPunch.BaseLungeDistance)
root:SetAttribute("PunchMaxLungeDistance", depthPunch.MaxLungeDistance)
root:SetAttribute("PunchPenetrationMode", "PowerScaledSweptVolume")
root:SetAttribute("MaxDepthPhysicsFragments", MAX_DEPTH_PHYSICS_FRAGMENTS)
root:SetAttribute("PunchWindupSeconds", depthPunch.WindupSeconds)
root:SetAttribute("MaxStructuralFalling", depthPunch.MaxStructuralFalling)
root:SetAttribute("ActiveStructuralFalling", 0)
root:SetAttribute("LastStructuralCollapseCount", 0)
root:SetAttribute("LastCharacterOverlapEjectCount", 0)
root:SetAttribute("WorldResetInterval", WORLD_RESET_INTERVAL)
root:SetAttribute("WorldResetCount", 0)
root:SetAttribute("LastWorldResetAt", 0)
root:SetAttribute("NextWorldResetAt", workspace:GetServerTimeNow() + WORLD_RESET_INTERVAL)

function depthPunch.Shake(block, intensity)
	local baseCFrame = block:GetAttribute("BaseCFrame") or block.CFrame
	local token = (block:GetAttribute("ShakeToken") or 0) + 1
	block:SetAttribute("ShakeToken", token)
	block:SetAttribute("Shaking", true)
	block:SetAttribute("LastShakeAt", workspace:GetServerTimeNow())
	local amount = math.clamp(tonumber(intensity) or 0.12, 0.05, 0.28)
	local offset = Vector3.new((math.random() - 0.5) * amount, (math.random() - 0.5) * amount, (math.random() - 0.5) * amount * 0.55)
	TweenService:Create(block, TweenInfo.new(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = baseCFrame * CFrame.new(offset) }):Play()
	task.delay(0.1, function()
		if block.Parent and not block:GetAttribute("Broken") and block:GetAttribute("ShakeToken") == token then
			local restore = TweenService:Create(block, TweenInfo.new(0.22, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { CFrame = baseCFrame })
			restore:Play()
			restore.Completed:Once(function()
				if block.Parent and block:GetAttribute("ShakeToken") == token then block:SetAttribute("Shaking", false) end
			end)
		end
	end)
end

function depthPunch.ClearCharactersFromStructuralBlock(block)
	if not block or not block.Parent then return 0 end
	local totalPush = 0
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if character and rootPart then
			local characterOverlap = OverlapParams.new()
			characterOverlap.FilterType = Enum.RaycastFilterType.Include
			characterOverlap.FilterDescendantsInstances = { character }
			characterOverlap.MaxParts = 32
			local function overlapsCharacter()
				return #workspace:GetPartBoundsInBox(block.CFrame, block.Size + Vector3.new(0.2, 0.2, 0.2), characterOverlap) > 0
			end
			if overlapsCharacter() then
				local offset = block.Position - rootPart.Position
				local horizontal = Vector3.new(offset.X, 0, offset.Z)
				local direction = horizontal.Magnitude > 0.05 and horizontal.Unit or block.CFrame.RightVector
				for _ = 1, 10 do
					if not overlapsCharacter() then break end
					block.CFrame += direction * 0.65 + Vector3.new(0, 0.12, 0)
					totalPush += 0.65
				end
				if overlapsCharacter() then
					block.CFrame += Vector3.new(0, block.Size.Y + 1.5, 0)
					totalPush += block.Size.Y + 1.5
				end
			end
		end
	end
	block:SetAttribute("CharacterClearanceResolved", totalPush > 0)
	block:SetAttribute("LastCharacterClearancePushStuds", totalPush)
	return totalPush
end

function depthPunch.DropStructural(block, player, ejectFromCharacter)
	if not block or block:GetAttribute("Broken") or block:GetAttribute("StructuralDetached") then return false end
	local active = root:GetAttribute("ActiveStructuralFalling") or 0
	if active >= depthPunch.MaxStructuralFalling then return false end
	local token = (block:GetAttribute("StructuralToken") or 0) + 1
	block:SetAttribute("StructuralToken", token)
	block:SetAttribute("StructuralFalling", true)
	block:SetAttribute("StructuralDetached", true)
	block:SetAttribute("Broken", false)
	block:SetAttribute("StructuralFailure", ejectFromCharacter == true)
	block:SetAttribute("HP", math.max(1, (block:GetAttribute("MaxHP") or 1) * 0.35))
	block:SetAttribute("DamageStage", 2)
	block:SetAttribute("LastStructuralCollapseAt", workspace:GetServerTimeNow())
	block.Anchored = false
	block.CanCollide = true
	block.CanQuery = true
	-- Falling full blocks collide with the world but cannot shove a character out of position.
	block.CollisionGroup = "FallingStructural"
	block.Transparency = 0
	pcall(function() block:SetNetworkOwner(nil) end)
	local character = player and player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local offset = ejectFromCharacter and rootPart and (block.Position - rootPart.Position)
		or (rootPart and (rootPart.Position - block.Position) or Vector3.new(0, 0, 1))
	local outward = offset.Magnitude > 0.01 and offset.Unit or block.CFrame.LookVector
	block.CFrame = block.CFrame + outward * (block.Size.Z + (ejectFromCharacter and 1.0 or 0.3))
	if ejectFromCharacter then
		-- The character wins the overlap: eject the block with a readable, medium
		-- impact instead of moving or teleporting the player.
		block.AssemblyLinearVelocity = outward * 24 + Vector3.new(0, 8, 0)
		block.AssemblyAngularVelocity = Vector3.new(3, 5, 2)
		block:SetAttribute("LastOverlapEjectAt", workspace:GetServerTimeNow())
		block:SetAttribute("LastOverlapEjectSpeed", block.AssemblyLinearVelocity.Magnitude)
		depthPunch.ClearCharactersFromStructuralBlock(block)
	else
		block.AssemblyLinearVelocity = outward * 7 + Vector3.new(0, -5, 0)
		block.AssemblyAngularVelocity = Vector3.new(math.random(-5, 5), math.random(-7, 7), math.random(-5, 5))
	end
	root:SetAttribute("ActiveStructuralFalling", active + 1)
	task.delay(2.8, function()
		if block.Parent and block:GetAttribute("StructuralToken") == token and not block:GetAttribute("Broken") then
			depthPunch.ClearCharactersFromStructuralBlock(block)
			block:SetAttribute("StructuralFalling", false)
			block.CollisionGroup = "Default"
			block:SetAttribute("SettledCFrame", block.CFrame)
			block:SetAttribute("SettledAt", workspace:GetServerTimeNow())
		end
		root:SetAttribute("ActiveStructuralFalling", math.max(0, (root:GetAttribute("ActiveStructuralFalling") or 1) - 1))
	end)
	return true
end

function depthPunch.BounceDetached(block, player, damage, impactDirection, impactForceScale)
	if not block or block:GetAttribute("Broken") then return end
	block.Anchored = false
	block.CanCollide = true
	block.CanQuery = true
	block.CollisionGroup = "FallingStructural"
	pcall(function() block:SetNetworkOwner(nil) end)
	local character = player and player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local offset = rootPart and (block.Position - rootPart.Position) or Vector3.new(0, 0, -1)
	local outward = typeof(impactDirection) == "Vector3" and impactDirection.Magnitude > 0.01 and impactDirection.Unit
		or (offset.Magnitude > 0.01 and offset.Unit or Vector3.new(0, 0, -1))
	local forceScale = math.clamp((tonumber(damage) or 1) / math.max(1, block:GetAttribute("MaxHP") or 1), 0.2, 1)
	local powerForce = math.clamp(tonumber(impactForceScale) or 1, 0.7, 3.5)
	local launchVelocity = outward * ((20 + forceScale * 26) * powerForce) + Vector3.new(0, (14 + forceScale * 16) * (0.8 + powerForce * 0.2), 0)
	block:ApplyImpulse((launchVelocity - block.AssemblyLinearVelocity) * block.AssemblyMass)
	block:ApplyAngularImpulse(Vector3.new(4 + forceScale * 5, 7 + forceScale * 7, 3 + forceScale * 6) * block.AssemblyMass * powerForce)
	block:SetAttribute("LastDetachedLaunchSpeed", launchVelocity.Magnitude)
	block:SetAttribute("LastDetachedImpactForceScale", powerForce)
	block:SetAttribute("DetachedImpactOrigin", block.CFrame)
	local impactToken = (block:GetAttribute("DetachedImpactToken") or 0) + 1
	block:SetAttribute("DetachedImpactToken", impactToken)
	block:SetAttribute("StructuralFalling", true)
	block:SetAttribute("LastDetachedImpactAt", workspace:GetServerTimeNow())
	task.delay(1.8, function()
		if block.Parent and not block:GetAttribute("Broken") and block:GetAttribute("DetachedImpactToken") == impactToken then
			depthPunch.ClearCharactersFromStructuralBlock(block)
			block:SetAttribute("StructuralFalling", false)
			block.CollisionGroup = "Default"
			block:SetAttribute("SettledCFrame", block.CFrame)
		end
	end)
end

function depthPunch.StructuralCollapse(sourceBlock, player)
	local layer = sourceBlock:GetAttribute("Depth") or 1
	local centerColumn = sourceBlock:GetAttribute("Column") or 1
	local collapsed = 0
	for row = 2, DEPTH_ROWS do
		for column = math.max(1, centerColumn - 2), math.min(DEPTH_COLUMNS, centerColumn + 2) do
			local block = depthBlocksFolder:FindFirstChild(("DepthBlock_L%03d_C%02d_R%02d"):format(layer, column, row))
			local below = depthBlocksFolder:FindFirstChild(("DepthBlock_L%03d_C%02d_R%02d"):format(layer, column, row - 1))
			if block and below and not block:GetAttribute("Broken") and not block:GetAttribute("StructuralDetached") and (below:GetAttribute("Broken") or below:GetAttribute("StructuralDetached")) then
				local left = column > 1 and depthBlocksFolder:FindFirstChild(("DepthBlock_L%03d_C%02d_R%02d"):format(layer, column - 1, row))
				local leftBelow = column > 1 and depthBlocksFolder:FindFirstChild(("DepthBlock_L%03d_C%02d_R%02d"):format(layer, column - 1, row - 1))
				local right = column < DEPTH_COLUMNS and depthBlocksFolder:FindFirstChild(("DepthBlock_L%03d_C%02d_R%02d"):format(layer, column + 1, row))
				local rightBelow = column < DEPTH_COLUMNS and depthBlocksFolder:FindFirstChild(("DepthBlock_L%03d_C%02d_R%02d"):format(layer, column + 1, row - 1))
				local leftSupported = left and leftBelow and not left:GetAttribute("Broken") and not left:GetAttribute("StructuralDetached") and not leftBelow:GetAttribute("Broken") and not leftBelow:GetAttribute("StructuralDetached")
				local rightSupported = right and rightBelow and not right:GetAttribute("Broken") and not right:GetAttribute("StructuralDetached") and not rightBelow:GetAttribute("Broken") and not rightBelow:GetAttribute("StructuralDetached")
				if not (leftSupported and rightSupported) and depthPunch.DropStructural(block, player) then
					collapsed += 1
				end
			end
		end
	end
	root:SetAttribute("LastStructuralCollapseCount", collapsed)
	if collapsed > 0 then
		sendFeedback(player, { type = "StructuralCollapse", target = sourceBlock.Name, count = collapsed, color = Color3.fromRGB(255, 151, 48) })
	end
	return collapsed
end

-- A high-power lunge can place the character inside a block between physics
-- steps. Resolve that state on the server by failing the overlapping block,
-- while leaving the character's position and velocity untouched.
function depthPunch.ResolveCharacterOverlaps()
	local ejected = 0
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if rootPart and humanoid and humanoid.Health > 0 then
			local overlap = OverlapParams.new()
			overlap.FilterType = Enum.RaycastFilterType.Include
			overlap.FilterDescendantsInstances = { depthBlocksFolder }
			overlap.MaxParts = 48
			local boxCFrame, boxSize = character:GetBoundingBox()
			boxSize += Vector3.new(0.28, 0.28, 0.28)
			for _, block in ipairs(workspace:GetPartBoundsInBox(boxCFrame, boxSize, overlap)) do
				if block:GetAttribute("IsDepthBlock")
					and not block:GetAttribute("Broken")
					and not block:GetAttribute("StructuralDetached")
					and block.Anchored
					and depthPunch.DropStructural(block, player, true) then
					ejected += 1
				end
			end
		end
	end
	root:SetAttribute("LastCharacterOverlapEjectCount", ejected)
	return ejected
end

task.spawn(function()
	while root.Parent do
		depthPunch.ResolveCharacterOverlaps()
		task.wait(0.16)
	end
end)

function depthPunch.PowerProfile(player)
	local power = math.max(1, statValue(player, "Power", 1))
	local powerScale = math.clamp(math.log10(math.max(1, power / 15)) / 8, 0, 1)
	local distanceScale = powerScale ^ 0.82
	return {
		power = power,
		powerScale = powerScale,
		distance = depthPunch.BaseLungeDistance + (depthPunch.MaxLungeDistance - depthPunch.BaseLungeDistance) * distanceScale,
		forceScale = 1 + powerScale * 2.4,
		limit = math.floor(depthPunch.BaseLimit + (depthPunch.MaxLimit - depthPunch.BaseLimit) * powerScale + 0.5),
	}
end

function depthPunch.PlanSafeLunge(player, rootPart, profile)
	local look = rootPart.CFrame.LookVector
	local horizontal = Vector3.new(look.X, 0, look.Z)
	if horizontal.Magnitude < 0.01 then return { safeDistance = 0, barrier = "direction", predictedBreaks = 0 } end
	local direction = horizontal.Unit
	local origin = rootPart.Position + Vector3.new(0, 0.8, 0)
	local traceLength = profile.distance + depthPunch.Reach
	local traceMidpoint = origin + direction * (traceLength * 0.5)
	local traceCFrame = CFrame.lookAt(traceMidpoint, traceMidpoint + direction)
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.FilterDescendantsInstances = { depthBlocksFolder }
	overlap.MaxParts = 400
	local function distanceToSurface(point, block)
		local localPoint = block.CFrame:PointToObjectSpace(point)
		local half = block.Size * 0.5
		local closest = Vector3.new(math.clamp(localPoint.X, -half.X, half.X), math.clamp(localPoint.Y, -half.Y, half.Y), math.clamp(localPoint.Z, -half.Z, half.Z))
		return (block.CFrame:PointToWorldSpace(closest) - point).Magnitude
	end
	local candidates = {}
	for _, block in ipairs(workspace:GetPartBoundsInBox(traceCFrame, Vector3.new(depthPunch.Radius * 2, depthPunch.Radius * 2, traceLength), overlap)) do
		if block:GetAttribute("IsDepthBlock") and not block:GetAttribute("Broken") then
			local forward = (block.Position - origin):Dot(direction)
			local closestPoint = origin + direction * math.clamp(forward, 0, traceLength)
			local distance = distanceToSurface(closestPoint, block)
			if forward >= -block.Size.Z * 0.5 and forward <= traceLength + block.Size.Z * 0.5 and distance <= depthPunch.Radius then
				local radialScale = math.clamp(1 - distance / depthPunch.Radius, 0.12, 1)
				local progress = math.clamp(forward / math.max(1, traceLength), 0, 1)
				local retention = 1 - progress * (0.52 - profile.powerScale * 0.3)
				table.insert(candidates, { block = block, forward = forward, distance = distance, scale = math.clamp(radialScale * retention, 0.08, 1) })
			end
		end
	end
	table.sort(candidates, function(left, right)
		if left.forward ~= right.forward then return left.forward < right.forward end
		if left.distance ~= right.distance then return left.distance < right.distance end
		return left.block.Name < right.block.Name
	end)
	if candidates[1] then candidates[1].scale = 1 end
	local baseDamage = statValue(player, "Power", 1)
		* statValue(player, "FistMultiplier", 1)
		* (1 + statValue(player, "PetMultiplier", 0))
		* (1 + statValue(player, "Rebirths", 0) * 0.25)
		* (1 + math.min(statValue(player, "FistMastery", 1), 500) * 0.001)
	if (player:GetAttribute("DamageBoostExpiresAt") or 0) > workspace:GetServerTimeNow() then baseDamage *= 2 end
	local predictedBreak = {}
	local predictedBreaks = 0
	local wallLevel = statValue(player, "WallLevel", 1)
	for index, candidate in ipairs(candidates) do
		if index > profile.limit then break end
		local block = candidate.block
		if wallLevel >= (block:GetAttribute("RequiredLevel") or 1) and baseDamage * candidate.scale >= (block:GetAttribute("HP") or 0) then
			predictedBreak[block] = true
			predictedBreaks += 1
		end
	end

	local corridorOverlap = OverlapParams.new()
	corridorOverlap.FilterType = Enum.RaycastFilterType.Include
	corridorOverlap.FilterDescendantsInstances = { depthBlocksFolder }
	corridorOverlap.MaxParts = 240
	local corridorMidpoint = rootPart.Position + direction * (profile.distance * 0.5)
	local corridorCFrame = CFrame.lookAt(corridorMidpoint, corridorMidpoint + direction)
	local safeDistance = profile.distance
	local barrierName = "none"
	local bodyHalfDepth = math.max(1.4, rootPart.Size.Z * 0.5 + 0.9)
	for _, block in ipairs(workspace:GetPartBoundsInBox(corridorCFrame, Vector3.new(math.max(2.8, rootPart.Size.X + 0.8), math.max(5, rootPart.Size.Y + 3), profile.distance), corridorOverlap)) do
		if block:GetAttribute("IsDepthBlock") and not block:GetAttribute("Broken") and not block:GetAttribute("StructuralFalling") and block.CanCollide and not predictedBreak[block] then
			local forward = (block.Position - rootPart.Position):Dot(direction)
			if forward > 0 then
				local stopDistance = math.max(0, forward - block.Size.Z * 0.5 - bodyHalfDepth - 0.2)
				if stopDistance < safeDistance then
					safeDistance = stopDistance
					barrierName = block.Name
				end
			end
		end
	end
	return { safeDistance = safeDistance, barrier = barrierName, predictedBreaks = predictedBreaks }
end

function depthPunch.Lunge(player, rootPart, profile)
	task.wait(depthPunch.WindupSeconds)
	profile = profile or depthPunch.PowerProfile(player)
	if not rootPart or not rootPart.Parent then return nil end
	local look = rootPart.CFrame.LookVector
	local horizontal = Vector3.new(look.X, 0, look.Z)
	if horizontal.Magnitude < 0.01 then return nil end
	local direction = horizontal.Unit
	local startCFrame = rootPart.CFrame
	local startPosition = rootPart.Position
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character, depthDebrisFolder, depthBlocksFolder }
	params.IgnoreWater = true
	local ray = workspace:Raycast(startPosition, direction * profile.distance, params)
	local travel = ray and math.max(0, ray.Distance - depthPunch.LungeClearance) or profile.distance

	local lockOverlap = OverlapParams.new()
	lockOverlap.FilterType = Enum.RaycastFilterType.Include
	lockOverlap.FilterDescendantsInstances = { depthBlocksFolder }
	lockOverlap.MaxParts = 80
	local lockMidpoint = startPosition + direction * (profile.distance * 0.5)
	local lockBox = CFrame.lookAt(lockMidpoint, lockMidpoint + direction)
	local wallLevel = statValue(player, "WallLevel", 1)
	for _, block in ipairs(workspace:GetPartBoundsInBox(lockBox, Vector3.new(5.2, 6.5, profile.distance), lockOverlap)) do
		if block:GetAttribute("IsDepthBlock") and not block:GetAttribute("Broken") and wallLevel < (block:GetAttribute("RequiredLevel") or 1) then
			local offset = block.Position - startPosition
			local forward = offset:Dot(direction)
			if forward > 0 then
				travel = math.min(travel, math.max(0, forward - block.Size.Z * 0.5 - depthPunch.LungeClearance))
			end
		end
	end

	player:SetAttribute("LastPunchLungeDistance", travel)
	player:SetAttribute("LastPunchRawLungeDistance", travel)
	player:SetAttribute("LastPunchRequestedDistance", profile.requestedDistance or profile.distance)
	player:SetAttribute("LastPunchPowerScale", profile.powerScale)
	player:SetAttribute("LastPunchPenetrationLimit", profile.limit)
	player:SetAttribute("LastPunchImpactForceScale", profile.forceScale)
	player:SetAttribute("LastPunchLungeAt", workspace:GetServerTimeNow())
	if travel > 0.05 then
		pcall(function() rootPart:SetNetworkOwner(nil) end)
		local tween = TweenService:Create(rootPart, TweenInfo.new(depthPunch.LungeSeconds, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			CFrame = rootPart.CFrame + direction * travel,
		})
		tween:Play()
		tween.Completed:Wait()
		rootPart.AssemblyLinearVelocity = Vector3.new(0, rootPart.AssemblyLinearVelocity.Y, 0)
		pcall(function() rootPart:SetNetworkOwnershipAuto() end)
	end
	return {
		travel = travel,
		startCFrame = startCFrame,
		startPosition = startPosition,
		endPosition = startPosition + direction * travel,
		direction = direction,
		powerScale = profile.powerScale,
		forceScale = profile.forceScale,
		limit = profile.limit,
	}
end

function depthPunch.ResolveCharacterOverlap(player, rootPart, lunge)
	if not rootPart or not rootPart.Parent or not lunge then
		return { corrected = false, safeTravel = 0, overlapCount = 0 }
	end
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.FilterDescendantsInstances = { depthBlocksFolder }
	overlap.MaxParts = 40
	local boxSize = Vector3.new(math.max(2.8, rootPart.Size.X + 0.8), math.max(5, rootPart.Size.Y + 3), math.max(2.8, rootPart.Size.Z + 1.2))
	local function blockingPartsAt(testCFrame)
		local blocking = {}
		for _, block in ipairs(workspace:GetPartBoundsInBox(testCFrame, boxSize, overlap)) do
			if block:GetAttribute("IsDepthBlock") and not block:GetAttribute("Broken") and block.CanCollide and block.Transparency < 0.95 then
				table.insert(blocking, block)
			end
		end
		return blocking
	end

	local currentBlocking = blockingPartsAt(rootPart.CFrame)
	if #currentBlocking == 0 then
		player:SetAttribute("LastPunchCollisionCorrected", false)
		player:SetAttribute("LastPunchCollisionOverlapCount", 0)
		player:SetAttribute("LastPunchCollisionCorrectionStuds", 0)
		player:SetAttribute("LastPunchSafeTravel", lunge.travel)
		return { corrected = false, safeTravel = lunge.travel, overlapCount = 0 }
	end

	local safeTravel = 0
	local safeCFrame = lunge.startCFrame
	local foundSafe = false
	for candidateTravel = lunge.travel - 0.5, -8, -0.5 do
		local candidateCFrame = CFrame.new(lunge.startPosition + lunge.direction * candidateTravel) * lunge.startCFrame.Rotation
		if #blockingPartsAt(candidateCFrame) == 0 then
			safeTravel = math.max(0, candidateTravel)
			safeCFrame = candidateCFrame
			foundSafe = true
			break
		end
	end
	if not foundSafe then
		local fallbackPosition = Vector3.new(courseEntrance.Position.X, 3, courseEntrance.Position.Z + 6)
		safeCFrame = CFrame.new(fallbackPosition) * lunge.startCFrame.Rotation
	end

	local correctionDistance = (rootPart.Position - safeCFrame.Position).Magnitude
	rootPart.CFrame = safeCFrame
	rootPart.AssemblyLinearVelocity = Vector3.zero
	rootPart.AssemblyAngularVelocity = Vector3.zero
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.PlatformStand = false
		humanoid.Sit = false
		humanoid:ChangeState(Enum.HumanoidStateType.Running)
	end
	lunge.travel = safeTravel
	lunge.endPosition = rootPart.Position
	player:SetAttribute("LastPunchLungeDistance", safeTravel)
	player:SetAttribute("LastPunchSafeTravel", safeTravel)
	player:SetAttribute("LastPunchCollisionCorrected", true)
	player:SetAttribute("LastPunchCollisionCorrectionStuds", correctionDistance)
	player:SetAttribute("LastPunchCollisionOverlapCount", #currentBlocking)
	player:SetAttribute("LastPunchCollisionCorrectedAt", workspace:GetServerTimeNow())
	return { corrected = true, safeTravel = safeTravel, overlapCount = #currentBlocking, correctionDistance = correctionDistance }
end

local function hitDepthBlock(player, block, options)
	options = options or {}
	if not block or not block.Parent or block:GetAttribute("Broken") then
		return { ok = false, reason = "broken" }
	end
	local wasDetached = block:GetAttribute("StructuralDetached") == true
	if not options.skipCooldown then
		local now = os.clock()
		local lastHit = player:GetAttribute("LastWallHit") or 0
		local cooldown = WALL_HIT_COOLDOWN
		if now - lastHit < cooldown then return { ok = false, reason = "cooldown" } end
		player:SetAttribute("LastWallHit", now)
	end

	local required = block:GetAttribute("RequiredLevel") or 1
	if statValue(player, "WallLevel", 1) < required then
		sendFeedback(player, { type = "Fail", target = block.Name, message = ("Need Lv %d"):format(required), color = PolishConfig.Palette.Fail })
		return { ok = false, reason = "level_gate", requiredLevel = required }
	end

	local damage = tonumber(options.damageOverride)
	local critical = options.criticalOverride == true
	if not damage then
		damage = statValue(player, "Power", 1)
			* statValue(player, "FistMultiplier", 1)
			* (1 + statValue(player, "PetMultiplier", 0))
			* (1 + statValue(player, "Rebirths", 0) * 0.25)
			* (1 + math.min(statValue(player, "FistMastery", 1), 500) * 0.001)
		if (player:GetAttribute("DamageBoostExpiresAt") or 0) > workspace:GetServerTimeNow() then damage *= 2 end
		critical = math.random(1, 100) <= math.clamp(statValue(player, "CritChance", 0), 0, GameConfig.MaxCritChance)
		if critical then damage *= 2 end
		damage *= math.clamp(tonumber(options.damageScale) or 1, 0.05, 1)
	end

	local previousHP = block:GetAttribute("HP") or 0
	local actualDamage = math.min(previousHP, damage)
	local remainingHP = math.max(0, previousHP - damage)
	block:SetAttribute("HP", remainingHP)
	depthBlockContributions[block] = depthBlockContributions[block] or {}
	depthBlockContributions[block][player.UserId] = (depthBlockContributions[block][player.UserId] or 0) + actualDamage

	local fraction = remainingHP / math.max(1, block:GetAttribute("MaxHP") or 1)
	local stage = fraction <= 0.25 and 3 or fraction <= 0.5 and 2 or fraction <= 0.75 and 1 or 0
	block:SetAttribute("DamageStage", stage)
	block.Color = (block:GetAttribute("OriginalColor") or block.Color):Lerp(Color3.fromRGB(38, 38, 38), stage * 0.12)
	sendFeedback(player, { type = "Punch", target = block.Name, damage = math.floor(damage + 0.5), critical = critical, broken = remainingHP <= 0, material = block.Material.Name, color = block.Color })

	if remainingHP > 0 then
		if wasDetached then
			depthPunch.BounceDetached(block, player, damage, options.impactDirection, options.impactForceScale)
		else
			depthPunch.Shake(block, 0.08 + stage * 0.045 + math.min(0.1, damage / math.max(1, block:GetAttribute("MaxHP") or 1) * 0.12))
		end
		return { ok = true, outcome = "hit", detached = wasDetached, damage = damage, hp = remainingHP, Depth = block:GetAttribute("Depth"), Tier = block:GetAttribute("Tier") }
	end

	block:SetAttribute("Broken", true)
	block:SetAttribute("StructuralDetached", false)
	block:SetAttribute("StructuralFalling", false)
	block.CanCollide = false
	block.CanQuery = false
	block.Transparency = 1
	spawnDepthBlockFragments(block, player, options.impactDirection, options.impactForceScale)
	if not wasDetached then depthPunch.StructuralCollapse(block, player) end

	local contributions = depthBlockContributions[block] or {}
	local totalContribution = 0
	for _, contribution in pairs(contributions) do totalContribution += contribution end
	for userId, contribution in pairs(contributions) do
		local contributor = Players:GetPlayerByUserId(userId)
		if contributor and contribution > 0 then
			local share = totalContribution > 0 and contribution / totalContribution or 1
			local coins = GameConfig.ContributionReward(block:GetAttribute("CoinReward") or 0, share)
			if (contributor:GetAttribute("CoinBoostExpiresAt") or 0) > workspace:GetServerTimeNow() then coins *= 2 end
			local score = GameConfig.ContributionReward(block:GetAttribute("ScoreReward") or 0, share)
			addStat(contributor, "Coins", coins)
			addStat(contributor, "Score", score)
			addStat(contributor, "DailyBreaks", 1)
			local layer = block:GetAttribute("Depth") or 1
			if layer > statValue(contributor, "Depth", 0) then setStat(contributor, "Depth", layer) end
			awardWallXP(contributor, block:GetAttribute("XPReward") or 1)
			advanceTutorial(contributor, 2)
			sendFeedback(contributor, { type = "Reward", target = block.Name, wallBreak = true, coins = coins, score = score, depth = layer, color = PolishConfig.Palette.Reward })
		end
	end
	return { ok = true, outcome = "broken", detached = wasDetached, damage = damage, Depth = block:GetAttribute("Depth"), Tier = block:GetAttribute("Tier") }
end

function depthPunch.Punch(player)
	local function distanceToBlockSurface(point, block)
		local localPoint = block.CFrame:PointToObjectSpace(point)
		local half = block.Size * 0.5
		local closest = Vector3.new(
			math.clamp(localPoint.X, -half.X, half.X),
			math.clamp(localPoint.Y, -half.Y, half.Y),
			math.clamp(localPoint.Z, -half.Z, half.Z)
		)
		return (block.CFrame:PointToWorldSpace(closest) - point).Magnitude
	end

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return { ok = false, reason = "character" } end
	local now = os.clock()
	local lastHit = player:GetAttribute("LastWallHit") or 0
	local cooldown = WALL_HIT_COOLDOWN
	if now - lastHit < cooldown then return { ok = false, reason = "cooldown" } end
	player:SetAttribute("LastWallHit", now)
	local profile = depthPunch.PowerProfile(player)
	profile.requestedDistance = profile.distance
	local lungePlan = depthPunch.PlanSafeLunge(player, rootPart, profile)
	profile.distance = lungePlan.safeDistance
	player:SetAttribute("LastPunchPowerLungeDistance", profile.requestedDistance)
	player:SetAttribute("LastPunchPlannedLungeDistance", lungePlan.safeDistance)
	player:SetAttribute("LastPunchPlanningBarrier", lungePlan.barrier)
	player:SetAttribute("LastPunchPredictedBreakCount", lungePlan.predictedBreaks)
	local lunge = depthPunch.Lunge(player, rootPart, profile)
	if not lunge then return { ok = false, reason = "lunge" } end

	local direction = lunge.direction
	local origin = lunge.startPosition + Vector3.new(0, 0.8, 0)
	local traceLength = lunge.travel + depthPunch.Reach
	local traceMidpoint = origin + direction * (traceLength * 0.5)
	local traceCFrame = CFrame.lookAt(traceMidpoint, traceMidpoint + direction)
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.FilterDescendantsInstances = { depthBlocksFolder }
	overlap.MaxParts = 400
	local candidates = {}
	local lockedBlock
	local lockedForward = math.huge
	local wallLevel = statValue(player, "WallLevel", 1)
	for _, block in ipairs(workspace:GetPartBoundsInBox(traceCFrame, Vector3.new(depthPunch.Radius * 2, depthPunch.Radius * 2, traceLength), overlap)) do
		if block:GetAttribute("IsDepthBlock") and not block:GetAttribute("Broken") then
			local offset = block.Position - origin
			local forward = offset:Dot(direction)
			local closestPoint = origin + direction * math.clamp(forward, 0, traceLength)
			local distance = distanceToBlockSurface(closestPoint, block)
			if forward >= -block.Size.Z * 0.5 and forward <= traceLength + block.Size.Z * 0.5 and distance <= depthPunch.Radius then
				if wallLevel < (block:GetAttribute("RequiredLevel") or 1) then
					if forward < lockedForward then
						lockedBlock = block
						lockedForward = forward
					end
				else
					local radialScale = math.clamp(1 - distance / depthPunch.Radius, 0.12, 1)
					local progress = math.clamp(forward / math.max(1, traceLength), 0, 1)
					local penetrationRetention = 1 - progress * (0.52 - lunge.powerScale * 0.3)
					local scale = math.clamp(radialScale * penetrationRetention, 0.08, 1)
					table.insert(candidates, { block = block, distance = distance, forward = forward, scale = scale })
				end
			end
		end
	end
	table.sort(candidates, function(left, right)
		if left.forward ~= right.forward then return left.forward < right.forward end
		if left.distance ~= right.distance then return left.distance < right.distance end
		return left.block.Name < right.block.Name
	end)
	if lockedBlock then
		for index = #candidates, 1, -1 do
			if candidates[index].forward >= lockedForward then table.remove(candidates, index) end
		end
	end
	if #candidates == 0 then
		player:SetAttribute("LastPunchCollisionCorrected", false)
		player:SetAttribute("LastPunchCollisionCorrectionStuds", 0)
		player:SetAttribute("LastPunchCollisionOverlapCount", 0)
		player:SetAttribute("LastPunchSafeTravel", lunge.travel)
		if lockedBlock then
			local result = hitDepthBlock(player, lockedBlock, { skipCooldown = true })
			result.collisionCorrected = false
			result.lungeDistance = lunge.travel
			return result
		end
		return { ok = false, reason = "no_block", lungeDistance = lunge.travel, collisionCorrected = false }
	end

	candidates[1].scale = 1
	local primary = candidates[1].block
	player:SetAttribute("LastRadiusPrimary", primary.Name)

	player:SetAttribute("LastWallHit", now)
	local baseDamage = statValue(player, "Power", 1)
		* statValue(player, "FistMultiplier", 1)
		* (1 + statValue(player, "PetMultiplier", 0))
		* (1 + statValue(player, "Rebirths", 0) * 0.25)
		* (1 + math.min(statValue(player, "FistMastery", 1), 500) * 0.001)
	local radiusCritical = math.random(1, 100) <= math.clamp(statValue(player, "CritChance", 0), 0, GameConfig.MaxCritChance)
	if radiusCritical then baseDamage *= 2 end
	local hitCount = 0
	for index, candidate in ipairs(candidates) do
		if index > lunge.limit then break end
		candidate.block:SetAttribute("LastRadiusDamageScale", candidate.scale)
		candidate.block:SetAttribute("LastRadiusHitAt", workspace:GetServerTimeNow())
		candidate.block:SetAttribute("LastPenetrationForward", candidate.forward)
		candidate.block:SetAttribute("LastPenetrationIndex", index)
		hitDepthBlock(player, candidate.block, {
			skipCooldown = true,
			damageOverride = baseDamage * candidate.scale,
			criticalOverride = radiusCritical,
			impactDirection = direction,
			impactForceScale = lunge.forceScale * math.clamp(candidate.scale, 0.45, 1),
		})
		hitCount += 1
	end
	player:SetAttribute("LastRadiusHitCount", hitCount)
	player:SetAttribute("LastPenetrationStuds", traceLength)
	player:SetAttribute("LastPunchCollisionCorrected", false)
	player:SetAttribute("LastPunchCollisionCorrectionStuds", 0)
	player:SetAttribute("LastPunchCollisionOverlapCount", 0)
	player:SetAttribute("LastPunchSafeTravel", lunge.travel)
	return { ok = hitCount > 0, outcome = "penetration", hitCount = hitCount, primary = primary.Name, lungeDistance = lunge.travel, collisionCorrected = false, collisionCorrectionStuds = 0, powerScale = lunge.powerScale, forceScale = lunge.forceScale, penetrationLimit = lunge.limit }
end

local BOSS_BASE_HP = 800000000
local bossStyle = wallStyle("Titan Server Wall")
local boss = makePart("Titan Server Wall", wallsFolder, Vector3.new(34, 18, 6), Vector3.new(-2, 9.25, -340), bossStyle.color, bossStyle.material or Enum.Material.Metal)
boss:SetAttribute("MaxHP", BOSS_BASE_HP)
boss:SetAttribute("HP", BOSS_BASE_HP)
boss:SetAttribute("RequiredLevel", 99)
boss:SetAttribute("Depth", 76)
boss:SetAttribute("RequiredDepth", 75)
boss:SetAttribute("ScoreReward", 20000000)
boss:SetAttribute("CoinReward", 60000000)
boss:SetAttribute("PowerReward", 0)
boss:SetAttribute("XPReward", 300000)
boss:SetAttribute("Theme", PolishConfig.StyleName)
boss:SetAttribute("VisualRole", "KaijuBossTower")
boss:SetAttribute("BaseSize", boss.Size)
boss:SetAttribute("OriginalColor", boss.Color)
boss:SetAttribute("AccentColor", bossStyle.accent)
addSound(boss, "Punch Impact", GameConfig.Audio.Punch, 0.7, 0.82)
addSound(boss, "Building Collapse", GameConfig.Audio.Collapse, 1, 0.78)
addSound(boss, "Boss Roar", GameConfig.Audio.BossRoar, 0.9, 0.9)
addFacadeGrid(boss, 6, 5, bossStyle.window, Color3.fromRGB(16, 18, 22))
wallVisualDetails[boss] = addFacadeGeometry(boss, tierFolder, 5, 5, bossStyle.window, Color3.fromRGB(12, 15, 18), "Titan HQ")
boss:SetAttribute("TextureStyle", "TitanContainmentWall")
local bossTowerCore = makeVisualPart("Titan HQ Deep Tower Core", tierFolder, Vector3.new(38, 34, 22), boss.CFrame * CFrame.new(0, 0, 15), Color3.fromRGB(37, 41, 46), Enum.Material.Concrete)
bossTowerCore:SetAttribute("PolishRole", "BreakLinkedBossDepth")
table.insert(wallVisualDetails[boss], { part = bossTowerCore, transparency = bossTowerCore.Transparency })
for side = -1, 1, 2 do
	local rib = makeVisualPart("Titan HQ Structural Rib " .. side, tierFolder, Vector3.new(3.2, 37, 25), boss.CFrame * CFrame.new(side * 20, 1.5, 10), Color3.fromRGB(22, 27, 31), Enum.Material.CorrodedMetal)
	rib:SetAttribute("PolishRole", "BreakLinkedBossDepth")
	table.insert(wallVisualDetails[boss], { part = rib, transparency = rib.Transparency })
end
updateWallText(boss)
addEmitter(boss, "Hit Spark", bossStyle.accent)
addEmitter(boss, "Break Burst", bossStyle.accent)
addEmitter(boss, "Respawn Shimmer", Color3.fromRGB(255, 255, 255))
local bossPad = makePart("Titan Boss City Plaza", tierFolder, Vector3.new(48, 1.2, 18), boss.Position + Vector3.new(0, -17.6, 0), bossStyle.pad, Enum.Material.Concrete)
bossPad:SetAttribute("PolishRole", "BossArenaPad")
local bossDangerZone = makePart("Titan Danger Zone", tierFolder, Vector3.new(44, 0.18, 15), bossPad.Position + Vector3.new(0, 0.72, 0), bossStyle.accent, Enum.Material.Neon)
bossDangerZone.CanCollide = false
bossDangerZone.Transparency = 1
local bossDebrisPieces = {}
for index = 1, 10 do
	local x = -14 + ((index - 1) % 5) * 7
	local y = -9 + math.floor((index - 1) / 5) * 8
	local piece = makeVisualPart("Titan Collapse Chunk " .. index, tierFolder, Vector3.new(4.5, 3.4, 1.5), boss.CFrame * CFrame.new(x, y, -5), bossStyle.color, Enum.Material.Metal)
	piece.Transparency = 1
	table.insert(bossDebrisPieces, { part = piece, baseCFrame = piece.CFrame })
end
wallDebris[boss] = bossDebrisPieces
local titanEmergencyGlow = makePart("Titan HQ Emergency Glow", tierFolder, Vector3.new(42, 38, 0.8), boss.Position + Vector3.new(0, 0, 4.55), bossStyle.accent, Enum.Material.Neon)
titanEmergencyGlow.Transparency = 0.55
titanEmergencyGlow:SetAttribute("AmbientMotion", "Pulse")
titanEmergencyGlow:SetAttribute("AmbientBaseTransparency", 0.55)
makePart("Titan HQ Antenna Mast", tierFolder, Vector3.new(1.2, 16, 1.2), boss.Position + Vector3.new(0, boss.Size.Y / 2 + 8, 0), bossStyle.accent, Enum.Material.Metal)
makePart("Titan HQ Rooftop Core", tierFolder, Vector3.new(18, 3, 10), boss.Position + Vector3.new(0, boss.Size.Y / 2 + 2, 0), Color3.fromRGB(21, 24, 29), Enum.Material.Metal)
for side = -1, 1, 2 do
	makePart("Titan Containment Pylon " .. side, tierFolder, Vector3.new(6, 46, 7), boss.Position + Vector3.new(side * 23, 3, 0), Color3.fromRGB(31, 36, 42), Enum.Material.CorrodedMetal)
	local energy = makePart("Titan Pylon Energy " .. side, tierFolder, Vector3.new(1.1, 34, 7.4), boss.Position + Vector3.new(side * 23, 3, -0.2), bossStyle.accent, Enum.Material.Neon)
	energy.Transparency = 0.18
	energy:SetAttribute("AmbientMotion", "Pulse")
	energy:SetAttribute("AmbientBaseTransparency", 0.18)
	local beacon = makeBall("Titan Warning Beacon " .. side, tierFolder, Vector3.new(2.4, 2.4, 2.4), boss.Position + Vector3.new(side * 23, 27, 0), Color3.fromRGB(255, 72, 48), Enum.Material.Neon)
	beacon:SetAttribute("AmbientMotion", "Pulse")
	beacon:SetAttribute("AmbientBaseTransparency", 0)
end
makePart("Titan Containment Crown", tierFolder, Vector3.new(52, 6, 8), boss.Position + Vector3.new(0, 23, 0), Color3.fromRGB(27, 31, 36), Enum.Material.CorrodedMetal)
local titanCore = makeBall("Titan Reactor Core", tierFolder, Vector3.new(9, 9, 2.4), boss.Position + Vector3.new(0, 1, -5.1), Color3.fromRGB(65, 220, 242), Enum.Material.Neon)
titanCore.CanCollide = false
titanCore:SetAttribute("AmbientMotion", "Pulse")
titanCore:SetAttribute("AmbientBaseTransparency", 0)
table.insert(wallVisualDetails[boss], { part = titanCore, transparency = 0 })
local titanHeader = makePart("Titan Containment Graphic Header", tierFolder, Vector3.new(34, 8, 0.65), boss.Position + Vector3.new(0, boss.Size.Y / 2 + 6, -boss.Size.Z / 2 - 0.45), Color3.fromRGB(20, 24, 29), Enum.Material.Metal)
makeGraphicSurface(titanHeader, GameConfig.GeneratedGraphics.Iteration05TitanBanner, "HERO RAID: TITAN", "TEAM BOSS | WEAK POINTS x1.5", Enum.NormalId.Front)
makeGraphicSurface(titanHeader, GameConfig.GeneratedGraphics.Iteration05TitanBanner, "HERO CITY HQ", "FINAL DEFENSE ZONE", Enum.NormalId.Back)
for index, offset in ipairs({ -18, -6, 6, 18 }) do
	local stripe = makePart("Titan Arena Hazard Stripe " .. index, tierFolder, Vector3.new(5, 0.15, 15), bossPad.Position + Vector3.new(offset, 0.7, 0), index % 2 == 0 and Color3.fromRGB(244, 187, 48) or Color3.fromRGB(32, 35, 38), Enum.Material.Metal)
	stripe.CanCollide = false
end
makeRubblePile(tierFolder, boss.Position + Vector3.new(-16, -17.4, -4.5), "Titan Plaza Rubble")
wallDamageParts[boss] = {
	makeWedge("Titan Facade Crack 1", tierFolder, Vector3.new(0.5, 9, 0.25), boss.Position + Vector3.new(-8, 3, -4.08), bossStyle.crack, Enum.Material.Concrete, Vector3.new(0, 0, 28)),
	makeWedge("Titan Facade Crack 2", tierFolder, Vector3.new(0.5, 9, 0.25), boss.Position + Vector3.new(2, -2, -4.08), bossStyle.crack, Enum.Material.Concrete, Vector3.new(0, 0, -22)),
	makeWedge("Titan Facade Crack 3", tierFolder, Vector3.new(0.5, 9, 0.25), boss.Position + Vector3.new(9, 4, -4.08), bossStyle.crack, Enum.Material.Concrete, Vector3.new(0, 0, 18)),
}
updateWallDamage(boss)

local bossWeakPoints = {}
for index, offset in ipairs({ Vector3.new(-10, 7, -4.6), Vector3.new(0, -2, -4.6), Vector3.new(10, 6, -4.6) }) do
	local weakPoint = makePart("Titan Weak Point " .. index, tierFolder, Vector3.new(4.2, 4.2, 0.8), boss.Position + offset, bossStyle.accent, Enum.Material.Neon)
	weakPoint.CanCollide = false
	weakPoint:SetAttribute("WeakPointMultiplier", 1.5)
	table.insert(bossWeakPoints, weakPoint)
	table.insert(wallVisualDetails[boss], { part = weakPoint, transparency = 0 })
end
boss:SetAttribute("WeakPointCount", #bossWeakPoints)

local bossClick = Instance.new("ClickDetector")
bossClick.MaxActivationDistance = 50
bossClick.Parent = boss
local bossContributions = {}
local bossParticipants = {}
boss:SetAttribute("BossPhase", 1)
boss:SetAttribute("ParticipantCount", 0)
boss:SetAttribute("NextAttackAt", 0)

local function hitBoss(player, weakPointMultiplier)
	if boss:GetAttribute("Broken") then
		return { ok = false, reason = "respawning" }
	end
	if statValue(player, "WallLevel", 1) < 99 then
		sendFeedback(player, {
			type = "Fail",
			target = boss.Name,
			message = "Need Lv 99",
			color = PolishConfig.Palette.Fail,
		})
		return { ok = false, reason = "level_gate", requiredLevel = 99 }
	end
	if statValue(player, "Depth", 0) < 30 then
		sendFeedback(player, {
			type = "Fail",
			target = boss.Name,
			message = "Clear Depth 30 first",
			color = PolishConfig.Palette.Fail,
		})
		return { ok = false, reason = "depth_gate", requiredDepth = 30 }
	end
	local now = os.clock()
	local lastHit = player:GetAttribute("LastBossHit") or 0
	if now - lastHit < 0.2 then
		return { ok = false, reason = "cooldown" }
	end
	player:SetAttribute("LastBossHit", now)

	if not bossParticipants[player.UserId] then
		bossParticipants[player.UserId] = true
		local participantCount = 0
		for _ in pairs(bossParticipants) do participantCount += 1 end
		boss:SetAttribute("ParticipantCount", participantCount)
		if participantCount > 1 then
			local addedHP = BOSS_BASE_HP * 0.65
			boss:SetAttribute("MaxHP", boss:GetAttribute("MaxHP") + addedHP)
			boss:SetAttribute("HP", boss:GetAttribute("HP") + addedHP)
		end
	end
	local rebirth = 1 + statValue(player, "Rebirths", 0) * 0.25
	local mastery = 1 + math.min(statValue(player, "FistMastery", 1), 500) * 0.001
	local damage = statValue(player, "Power", 1) * statValue(player, "FistMultiplier", 1) * (1 + statValue(player, "PetMultiplier", 0)) * rebirth * mastery * 1.4 * (weakPointMultiplier or 1)
	local previousHP = boss:GetAttribute("HP")
	local actualDamage = math.min(previousHP, damage)
	boss:SetAttribute("HP", math.max(0, previousHP - damage))
	bossContributions[player.UserId] = (bossContributions[player.UserId] or 0) + actualDamage
	advanceTutorial(player, 6)
	local ratio = boss:GetAttribute("HP") / math.max(1, boss:GetAttribute("MaxHP"))
	local phase = ratio <= 0.25 and 4 or ratio <= 0.5 and 3 or ratio <= 0.75 and 2 or 1
	if phase ~= boss:GetAttribute("BossPhase") then
		boss:SetAttribute("BossPhase", phase)
		broadcastFeedback({ type = "BossPhase", target = tostring(phase), color = bossStyle.accent })
	end
	updateWallText(boss)
	updateWallDamage(boss)
	emitNamed(boss, "Hit Spark", PolishConfig.Motion.HitEmit + 8)
	playNamedSound(boss, "Punch Impact", 0.8 + math.random() * 0.08)
	sendFeedback(player, {
		type = "Punch",
		target = boss.Name,
		damage = math.floor(damage + 0.5),
		color = bossStyle.accent,
	})
	if (weakPointMultiplier or 1) > 1 then
		sendFeedback(player, {
			type = "WeakPoint",
			target = boss.Name,
			damage = math.floor(damage + 0.5),
			color = Color3.fromRGB(255, 224, 92),
		})
	end
	if boss:GetAttribute("HP") <= 0 and not boss:GetAttribute("Broken") then
		boss:SetAttribute("Broken", true)
		boss:SetAttribute("NextAttackAt", 0)
		broadcast("Titan HQ shattered! Contributors receive rewards.", Color3.fromRGB(120, 220, 255))
		emitNamed(boss, "Break Burst", PolishConfig.Motion.BreakEmit + 30)
		playNamedSound(boss, "Building Collapse", 0.76)
		local totalContribution = 0
		for _, contribution in pairs(bossContributions) do totalContribution += contribution end
		for userId, contribution in pairs(bossContributions) do
			local plr = Players:GetPlayerByUserId(userId)
			if plr and contribution / math.max(1, totalContribution) >= 0.01 then
				local share = contribution / math.max(1, totalContribution)
				local coins = math.max(1, math.floor(boss:GetAttribute("CoinReward") * (0.6 + share * 0.4)))
				if (plr:GetAttribute("CoinBoostExpiresAt") or 0) > workspace:GetServerTimeNow() then coins *= 2 end
				addStat(plr, "Coins", coins)
				addStat(plr, "Score", math.max(1, math.floor(boss:GetAttribute("ScoreReward") * share + 0.5)))
				if statValue(plr, "Depth", 0) < 76 then setStat(plr, "Depth", 76) end
				awardWallXP(plr, boss:GetAttribute("XPReward"))
				sendFeedback(plr, { type = "Boss", target = boss.Name, coins = coins, color = bossStyle.accent })
			end
		end
		boss.Transparency = 0.85
		setWallVisualDetailsBroken(boss, true)
		setWallDebrisState(boss, true)
		setWallLabelsEnabled(boss, false)
		boss.CanCollide = false
		boss:SetAttribute("RespawnAt", workspace:GetServerTimeNow() + GameConfig.BossRespawnSeconds)
		task.delay(GameConfig.BossRespawnSeconds, function()
			if boss.Parent then
				bossContributions = {}
				bossParticipants = {}
				boss:SetAttribute("MaxHP", BOSS_BASE_HP)
				boss:SetAttribute("HP", BOSS_BASE_HP)
				boss:SetAttribute("Broken", false)
				boss:SetAttribute("BossPhase", 1)
				boss:SetAttribute("ParticipantCount", 0)
				boss:SetAttribute("RespawnAt", 0)
				boss:SetAttribute("NextAttackAt", 0)
				boss.Transparency = 0
				setWallVisualDetailsBroken(boss, false)
				setWallDebrisState(boss, false)
				setWallLabelsEnabled(boss, true)
				boss.CanCollide = true
				updateWallText(boss)
				updateWallDamage(boss)
				emitNamed(boss, "Respawn Shimmer", 22)
			end
		end)
		return { ok = true, outcome = "broken", damage = damage }
	end
	return { ok = true, outcome = "hit", damage = damage, hp = boss:GetAttribute("HP") }
end

bossClick.MouseClick:Connect(function(player)
	hitBoss(player)
end)
for _, weakPoint in ipairs(bossWeakPoints) do
	local detector = Instance.new("ClickDetector")
	detector.MaxActivationDistance = 50
	detector.Parent = weakPoint
	detector.MouseClick:Connect(function(player)
		hitBoss(player, weakPoint:GetAttribute("WeakPointMultiplier") or 1.5)
	end)
end

task.spawn(function()
	while boss.Parent do
		local active = not boss:GetAttribute("Broken") and boss:GetAttribute("HP") < boss:GetAttribute("MaxHP") and (boss:GetAttribute("BossPhase") or 1) >= 2
		if not active then
			boss:SetAttribute("NextAttackAt", 0)
			task.wait(1)
		else
			boss:SetAttribute("NextAttackAt", workspace:GetServerTimeNow() + 10)
			task.wait(8)
			active = not boss:GetAttribute("Broken") and boss:GetAttribute("HP") < boss:GetAttribute("MaxHP") and (boss:GetAttribute("BossPhase") or 1) >= 2
			if not active then
				boss:SetAttribute("NextAttackAt", 0)
				continue
			end
			broadcastFeedback({ type = "BossAttack", target = "Shockwave", color = bossStyle.accent })
			playNamedSound(boss, "Boss Roar", 0.88 + (boss:GetAttribute("BossPhase") or 1) * 0.03)
			bossDangerZone.Transparency = 0.48
			TweenService:Create(bossDangerZone, TweenInfo.new(1.85), { Transparency = 0.12 }):Play()
			task.wait(2)
			for _, plr in ipairs(Players:GetPlayers()) do
				local character = plr.Character
				local rootPart = character and character:FindFirstChild("HumanoidRootPart")
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if rootPart and humanoid then
					local flatDistance = (Vector3.new(rootPart.Position.X, 0, rootPart.Position.Z) - Vector3.new(boss.Position.X, 0, boss.Position.Z)).Magnitude
					if flatDistance <= 29 then
						humanoid:TakeDamage(10 + (boss:GetAttribute("BossPhase") or 1) * 5)
					end
				end
			end
			bossDangerZone.Transparency = 1
			boss:SetAttribute("NextAttackAt", 0)
		end
	end
end)

local trainingConfigs = {
	{ name = "Power Bag", stat = "Power", gain = 4, pos = Vector3.new(-53, 4, 24), color = Color3.fromRGB(218, 66, 48) },
	{ name = "Speed Dummy", stat = "BreakSpeed", gain = 0.02, pos = Vector3.new(-34, 4, 24), color = Color3.fromRGB(57, 132, 180) },
	{ name = "Focus Stone", stat = "CritChance", gain = 0.05, pos = Vector3.new(-15, 4, 24), color = Color3.fromRGB(236, 178, 67) },
}

local trainingByName = {}
local trainingPartsByName = {}

local function trainPlayer(player, config)
	local now = os.clock()
	local key = "LastTrain" .. config.stat
	local lastTrain = player:GetAttribute(key) or 0
	if now - lastTrain < TRAINING_COOLDOWN then
		return { ok = false, reason = "cooldown" }
	end
	player:SetAttribute(key, now)
	addStat(player, config.stat, config.gain)
	if config.stat == "CritChance" then
		setStat(player, "CritChance", math.min(GameConfig.MaxCritChance, statValue(player, "CritChance", 0)))
	end
	addStat(player, "FistMastery", 0.03)
	if config.name == "Power Bag" then
		advanceTutorial(player, 1)
	end
	if config.part then
		emitNamed(config.part, "Train Pop", PolishConfig.Motion.TrainEmit)
		local baseSize = config.part:GetAttribute("BaseSize")
		local targetSize = baseSize or config.part.Size
		TweenService:Create(config.part, TweenInfo.new(PolishConfig.Motion.TrainBounceSeconds), { Size = targetSize + Vector3.new(0.7, 0.7, 0.7) }):Play()
		task.delay(PolishConfig.Motion.TrainBounceSeconds, function()
			if config.part and config.part.Parent then
				TweenService:Create(config.part, TweenInfo.new(0.12), { Size = targetSize }):Play()
			end
		end)
	end
	sendFeedback(player, {
		type = "Train",
		target = config.name,
		stat = config.stat,
		gain = config.gain,
		color = config.color,
	})
	return { ok = true, stat = config.stat, gain = config.gain, value = statValue(player, config.stat) }
end

for _, config in ipairs(trainingConfigs) do
	trainingByName[config.name] = config
	local station = makePart(config.name, interactFolder, Vector3.new(9, 8, 9), config.pos, config.color, Enum.Material.Metal)
	config.part = station
	station:SetAttribute("BaseSize", station.Size)
	station:SetAttribute("Theme", PolishConfig.StyleName)
	station:SetAttribute("VisualRole", "CityTrainingStation")
	station.Transparency = 0.88
	station.CanCollide = false
	addEmitter(station, "Train Pop", config.color)
	trainingPartsByName[config.name] = station
	local trainingSign = makePart(config.name .. " Training Sign", decorFolder, Vector3.new(7.5, 2.8, 0.35), config.pos + Vector3.new(0, 6.1, -4.2), Color3.fromRGB(25, 29, 32), Enum.Material.Metal)
	trainingSign.CanCollide = false
	makeText(trainingSign, string.upper(config.name), ("+%s %s"):format(config.gain, config.stat), Enum.NormalId.Front)
	makePart(config.name .. " Gym Mat", decorFolder, Vector3.new(13, 0.25, 13), config.pos + Vector3.new(0, -3.9, 0), Color3.fromRGB(43, 47, 50), Enum.Material.Fabric)
	if config.name == "Speed Dummy" then
		makeCylinder("Boxing Dummy Head", decorFolder, Vector3.new(2.4, 2.4, 2.4), config.pos + Vector3.new(0, 6.2, 0), Color3.fromRGB(174, 135, 91), Enum.Material.Fabric)
		makePart("Boxing Dummy Body", decorFolder, Vector3.new(3.8, 5.4, 1.7), config.pos + Vector3.new(0, 1.7, 0), Color3.fromRGB(122, 68, 48), Enum.Material.Fabric)
	elseif config.name == "Power Bag" then
		makeCylinder("Heavy Bag Chain", decorFolder, Vector3.new(0.35, 5, 0.35), config.pos + Vector3.new(0, 6.6, 0), Color3.fromRGB(34, 34, 34), Enum.Material.Metal)
		makeCylinder("Heavy Punch Bag Shell", decorFolder, Vector3.new(5.8, 2.6, 2.6), config.pos + Vector3.new(0, 2.4, 0), Color3.fromRGB(128, 36, 30), Enum.Material.Fabric, Vector3.new(0, 0, 90))
		makePart("Heavy Bag Steel Band", decorFolder, Vector3.new(3.2, 0.35, 3.2), config.pos + Vector3.new(0, 4.4, 0), Color3.fromRGB(48, 51, 54), Enum.Material.Metal)
	elseif config.name == "Focus Stone" then
		makePart("Cracked Focus Concrete", decorFolder, Vector3.new(6, 3, 6), config.pos + Vector3.new(0, -1.7, 0), Color3.fromRGB(111, 116, 114), Enum.Material.Concrete)
		makeWedge("Focus Concrete Broken Edge", decorFolder, Vector3.new(4.2, 2.4, 1.8), config.pos + Vector3.new(1.5, 1.0, -2.4), Color3.fromRGB(84, 87, 86), Enum.Material.Concrete, Vector3.new(0, 30, 0))
	end
	local detector = Instance.new("ClickDetector")
	detector.MaxActivationDistance = 32
	detector.Parent = station
	detector.MouseClick:Connect(function(player)
		trainPlayer(player, config)
	end)
end

local fistShop = {}
for index = 2, #GameConfig.Fists do
	table.insert(fistShop, GameConfig.Fists[index])
end

local fistByName = {}
local fistPartsByName = {}
for _, item in ipairs(GameConfig.Fists) do
	fistByName[item.name] = item
end

local function buyFist(player, item)
	local owned = decodeList(player, "OwnedFistsJSON")
	if listContains(owned, item.name) then
		setStat(player, "FistMultiplier", item.mult)
		setStat(player, "BreakSpeed", 1 + item.speed)
		setStat(player, "EquippedFist", item.name)
		sendFeedback(player, { type = "Shop", target = item.name, color = PolishConfig.Palette.Use })
		return { ok = true, outcome = "equipped", item = item.name, multiplier = item.mult, coins = statValue(player, "Coins", 0) }
	end
	if statValue(player, "Coins", 0) < item.cost then
		sendFeedback(player, {
			type = "Fail",
			target = item.name,
			message = "Need coins",
			color = PolishConfig.Palette.Fail,
		})
		return { ok = false, reason = "not_enough_coins", cost = item.cost }
	end
	addStat(player, "Coins", -item.cost)
	setStat(player, "FistMultiplier", item.mult)
	setStat(player, "BreakSpeed", 1 + item.speed)
	table.insert(owned, item.name)
	encodeList(player, "OwnedFistsJSON", owned)
	local equipped = playerStat(player, "EquippedFist")
	if equipped then
		equipped.Value = item.name
	end
	advanceTutorial(player, 4)
	sendFeedback(player, {
		type = "Shop",
		target = item.name,
		coins = -item.cost,
		color = PolishConfig.Palette.Use,
	})
	return { ok = true, item = item.name, multiplier = item.mult, coins = statValue(player, "Coins", 0) }
end

-- Timed shop boosts are server-authoritative. They are deliberately session-based:
-- no temporary modifier is saved into the player's long-term inventory.
shared.PunchWallShopBoostPurchase = function(player, boostName)
	local catalog = {
		CoinBoost = { cost = 5000, attribute = "CoinBoostExpiresAt", feedback = "COIN BOOST x2 ACTIVE" },
		SpeedBoost = { cost = 8000, attribute = "SpeedBoostExpiresAt", feedback = "SPEED BOOST ACTIVE" },
		DamageBoost = { cost = 12000, attribute = "DamageBoostExpiresAt", feedback = "DAMAGE BOOST x2 ACTIVE" },
	}
	local boost = catalog[boostName]
	if not boost then return { ok = false, reason = "unknown_boost" } end
	if statValue(player, "Coins", 0) < boost.cost then
		sendFeedback(player, { type = "Fail", target = boostName, message = "Need coins", color = PolishConfig.Palette.Fail })
		return { ok = false, reason = "not_enough_coins", cost = boost.cost }
	end
	addStat(player, "Coins", -boost.cost)
	local expiresAt = math.max(player:GetAttribute(boost.attribute) or 0, workspace:GetServerTimeNow()) + 900
	player:SetAttribute(boost.attribute, expiresAt)
	if boostName == "SpeedBoost" then
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then humanoid.WalkSpeed = 24 end
		task.delay(900, function()
			if player.Parent and (player:GetAttribute(boost.attribute) or 0) <= workspace:GetServerTimeNow() then
				local currentHumanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if currentHumanoid then currentHumanoid.WalkSpeed = 16 end
			end
		end)
	end
	sendFeedback(player, { type = "Shop", target = boostName, message = boost.feedback, color = PolishConfig.Palette.Reward })
	syncStats(player)
	return { ok = true, item = boostName, expiresAt = expiresAt, coins = statValue(player, "Coins", 0) }
end

local shopBack = makePart("Fist Shop Sign", root, Vector3.new(36, 10, 0.8), Vector3.new(-43, 21.5, -18.8), PolishConfig.Palette.Ink, Enum.Material.Metal)
makeGraphicSurface(shopBack, GameConfig.GeneratedGraphics.HeroCityHUDAtlas, "HERO FIST HQ", "CHOOSE | EQUIP | POWER UP", Enum.NormalId.Front)
makeGraphicSurface(shopBack, GameConfig.HeroCityPixelUI.SmashBillboard, "SMASH!", "HERO CITY", Enum.NormalId.Back)
local shopRoof = makePart("Armory Steel Roof", decorFolder, Vector3.new(45, 0.55, 4.4), Vector3.new(-43, 15.8, -16.8), Color3.fromRGB(49, 58, 67), Enum.Material.DiamondPlate)
shopRoof:SetAttribute("TextureStyle", "IndustrialRoof")
makePart("Armory Warning Stripe", decorFolder, Vector3.new(34, 0.18, 0.65), Vector3.new(-43, 16.18, -18.9), PolishConfig.Palette.RoadLine, Enum.Material.SmoothPlastic)
makePart("Armory Back Wall", decorFolder, Vector3.new(44, 7.5, 0.8), Vector3.new(-43, 5.0, -16.2), Color3.fromRGB(47, 59, 69), Enum.Material.Concrete)
makeCoinStack(decorFolder, Vector3.new(-69, 1.1, -1))

for index, item in ipairs(fistShop) do
	local stand = makePart(item.name .. " Stand", interactFolder, Vector3.new(9, 5, 9), Vector3.new(-75.5 + index * 13, 3, -10), Color3.fromRGB(230, 230, 230), Enum.Material.Metal)
	stand.Color = index % 2 == 0 and PolishConfig.Palette.HeroCyan or PolishConfig.Palette.HeroRed
	stand:SetAttribute("Theme", PolishConfig.StyleName)
	stand.Transparency = 0.9
	stand.CanCollide = false
	fistPartsByName[item.name] = stand
	makePart(item.name .. " Display Plinth", decorFolder, Vector3.new(8, 1.0, 7), stand.Position + Vector3.new(0, -2.0, 0), Color3.fromRGB(35, 43, 51), Enum.Material.DiamondPlate)
	local nameplate = makeVisualPart(item.name .. " Armory Nameplate", decorFolder, Vector3.new(8.2, 1.9, 0.35), CFrame.new(stand.Position + Vector3.new(0, -0.4, 4.65)), PolishConfig.Palette.Ink, Enum.Material.Metal)
	nameplate:SetAttribute("PolishRole", "ArmoryFixedNameplate")
	local frontText = makeText(nameplate, item.displayName, ("T%d | $%s | x%.1f"):format(item.tier, formatNumber(item.cost), item.mult), Enum.NormalId.Front)
	local backText = makeText(nameplate, item.displayName, ("T%d | $%s | x%.1f"):format(item.tier, formatNumber(item.cost), item.mult), Enum.NormalId.Back)
	for _, surface in ipairs({ frontText, backText }) do
		surface.Title.Position = UDim2.fromScale(0.29, 0.08)
		surface.Title.Size = UDim2.fromScale(0.68, 0.38)
		surface.Subtitle.Position = UDim2.fromScale(0.29, 0.48)
		surface.Subtitle.Size = UDim2.fromScale(0.68, 0.38)
	end
	makeAtlasIconSurface(nameplate, item.icon, Enum.NormalId.Front)
	makeAtlasIconSurface(nameplate, item.icon, Enum.NormalId.Back)
	local displayPalm = makeBall(item.name .. " Gauntlet Palm", decorFolder, Vector3.new(3.6, 2.8, 3.2), stand.Position + Vector3.new(0, 4.9, -1.5), item.color, item.material)
	displayPalm:SetAttribute("FistShape", "ClosedPalm")
	displayPalm:SetAttribute("FistTier", item.tier)
	local displayCuff = makeCylinder(item.name .. " Fist Cuff", decorFolder, Vector3.new(1.0, 3.1, 3.1), stand.Position + Vector3.new(0, 3.3, -1.1), item.color:Lerp(Color3.new(0, 0, 0), 0.42), Enum.Material.Metal, Vector3.new(0, 0, 90))
	displayCuff:SetAttribute("FistShape", "WristCuff")
	for finger = 1, 4 do
		local knuckle = makeBall(item.name .. " Closed Knuckle " .. finger, decorFolder, Vector3.new(0.92, 1.0, 1.15), stand.Position + Vector3.new(-2.25 + finger * 0.9, 6.1, 0.15), item.color:Lerp(item.accent, item.tier >= 4 and 0.32 or 0.1), item.material)
		knuckle:SetAttribute("FistShape", "RoundedKnuckle")
	end
	local displayCore = makeBall(item.name .. " Fist Core", decorFolder, Vector3.new(0.9, 0.9, 0.55), stand.Position + Vector3.new(0, 5.15, -3.15), item.accent, item.tier >= 4 and Enum.Material.Neon or Enum.Material.Metal)
	displayCore:SetAttribute("FistShape", "EnergyCore")
	local detector = Instance.new("ClickDetector")
	detector.MaxActivationDistance = 30
	detector.Parent = stand
	detector.MouseClick:Connect(function(player)
		buyFist(player, item)
	end)
end

local eggPart = makePart("Pet Egg Machine", interactFolder, Vector3.new(14, 11, 14), Vector3.new(-72, 6, 24), Color3.fromRGB(35, 112, 145), Enum.Material.Glass)
eggPart:SetAttribute("Theme", PolishConfig.StyleName)
eggPart.Transparency = 0.94
eggPart.CanCollide = false
addEmitter(eggPart, "Egg Reveal", PolishConfig.RarityColors.Epic)
makePart("DNA Lab Concrete Base", decorFolder, Vector3.new(19, 0.6, 19), eggPart.Position + Vector3.new(0, -5.7, 0), Color3.fromRGB(88, 92, 93), Enum.Material.Concrete)
makeCylinder("DNA Containment Tube", decorFolder, Vector3.new(9.5, 7, 7), eggPart.Position + Vector3.new(0, 2.1, 0), PolishConfig.Palette.HeroCyan, Enum.Material.Glass, Vector3.new(0, 0, 90)).Transparency = 0.28
makeCylinder("DNA Tube Top Clamp", decorFolder, Vector3.new(0.5, 8.4, 8.4), eggPart.Position + Vector3.new(0, 7.0, 0), Color3.fromRGB(42, 48, 51), Enum.Material.Metal, Vector3.new(0, 0, 90))
makeCylinder("DNA Tube Bottom Clamp", decorFolder, Vector3.new(0.5, 8.4, 8.4), eggPart.Position + Vector3.new(0, -2.5, 0), Color3.fromRGB(42, 48, 51), Enum.Material.Metal, Vector3.new(0, 0, 90))
makePart("DNA Lab Control Panel", decorFolder, Vector3.new(5.5, 3.2, 1.0), eggPart.Position + Vector3.new(-7.2, -1.3, -5.4), Color3.fromRGB(29, 34, 38), Enum.Material.Metal)
makePart("DNA Lab Screen", decorFolder, Vector3.new(4.2, 2.1, 0.25), eggPart.Position + Vector3.new(-7.2, -0.7, -6.0), PolishConfig.Palette.HeroYellow, Enum.Material.Neon)
makePart("Kaiju Sample Tank", decorFolder, Vector3.new(4, 6, 4), eggPart.Position + Vector3.new(10, -1.1, 0), Color3.fromRGB(42, 63, 69), Enum.Material.Metal)
makeBall("Sidekick Sample Glow", decorFolder, Vector3.new(3.2, 3.2, 3.2), eggPart.Position + Vector3.new(10, 2.3, 0), PolishConfig.Palette.HeroCyan, Enum.Material.Neon)
local dnaSign = makePart("DNA Lab Compact Sign", decorFolder, Vector3.new(12, 3.6, 0.45), eggPart.Position + Vector3.new(0, 8, -7.2), PolishConfig.Palette.Ink, Enum.Material.Metal)
makeGraphicSurface(dnaSign, GameConfig.GeneratedGraphics.Iteration02DNABanner, "HERO SIDEKICK LAB", ("RECRUIT %s COINS"):format(EGG_COST), Enum.NormalId.Front)

local pets = GameConfig.Pets
local petByName = {}
for _, pet in ipairs(pets) do
	petByName[pet.name] = pet
end

local function refreshEquippedPets(player)
	local equipped = decodeList(player, "EquippedPetsJSON")
	local inventory = decodeList(player, "PetInventoryJSON")
	local valid = {}
	local available = {}
	for _, name in ipairs(inventory) do
		available[name] = (available[name] or 0) + 1
	end
	local multiplier = 0
	for _, name in ipairs(equipped) do
		if #valid < GameConfig.MaxEquippedPets and petByName[name] and (available[name] or 0) > 0 then
			table.insert(valid, name)
			available[name] -= 1
			multiplier += petByName[name].mult
		end
	end
	encodeList(player, "EquippedPetsJSON", valid)
	setStat(player, "PetMultiplier", multiplier)
	setStat(player, "Pet", valid[1] or "None")
	return valid, multiplier
end

local function rollPet(luck)
	local total = 0
	for _, pet in ipairs(pets) do
		total += GameConfig.PetWeight(pet, luck)
	end
	local roll = math.random() * total
	local cumulative = 0
	for _, pet in ipairs(pets) do
		cumulative += GameConfig.PetWeight(pet, luck)
		if roll <= cumulative then
			return pet
		end
	end
	return pets[#pets]
end

local function hatchPet(player)
	local inventory = decodeList(player, "PetInventoryJSON")
	if #inventory >= GameConfig.MaxPetInventory then
		sendFeedback(player, { type = "Fail", target = "Pet Egg", message = "Inventory full", color = PolishConfig.Palette.Fail })
		return { ok = false, reason = "inventory_full" }
	end
	if statValue(player, "Coins", 0) < EGG_COST then
		sendFeedback(player, {
			type = "Fail",
			target = "Pet Egg",
			message = "Need coins",
			color = PolishConfig.Palette.Fail,
		})
		return { ok = false, reason = "not_enough_coins", cost = EGG_COST }
	end
	addStat(player, "Coins", -EGG_COST)

	local luck = math.max(1, statValue(player, "Luck", 1))
	local chosen = rollPet(luck)
	table.insert(inventory, chosen.name)
	encodeList(player, "PetInventoryJSON", inventory)
	local discovered = decodeList(player, "DiscoveredPetsJSON")
	if not listContains(discovered, chosen.name) then
		table.insert(discovered, chosen.name)
		encodeList(player, "DiscoveredPetsJSON", discovered)
	end
	local equipped = decodeList(player, "EquippedPetsJSON")
	if #equipped < GameConfig.MaxEquippedPets then
		table.insert(equipped, chosen.name)
		encodeList(player, "EquippedPetsJSON", equipped)
	end
	local _, equippedMultiplier = refreshEquippedPets(player)
	addStat(player, "Luck", chosen.luckGain)
	advanceTutorial(player, 5)
	emitNamed(eggPart, "Egg Reveal", 32)
	local rarityColor = chosen.mult >= 4 and PolishConfig.RarityColors.Secret
		or chosen.mult >= 1.5 and PolishConfig.RarityColors.Legendary
		or chosen.mult >= 0.8 and PolishConfig.RarityColors.Epic
		or chosen.mult >= 0.3 and PolishConfig.RarityColors.Rare
		or PolishConfig.RarityColors.Common
	sendFeedback(player, {
		type = "Pet",
		target = chosen.name,
		rarity = chosen.rarity,
		multiplier = chosen.mult,
		color = rarityColor,
	})
	return { ok = true, pet = chosen.name, rarity = chosen.rarity, multiplier = chosen.mult, equippedMultiplier = equippedMultiplier, coins = statValue(player, "Coins", 0), luck = statValue(player, "Luck", 1) }
end

local function hatchPets(player, count)
	count = math.clamp(math.floor(tonumber(count) or 1), 1, 3)
	local results = {}
	for _ = 1, count do
		local result = hatchPet(player)
		table.insert(results, result)
		if not result.ok then break end
	end
	return results
end

local function equipPet(player, petName)
	if not petByName[petName] then
		return { ok = false, reason = "unknown_pet" }
	end
	local inventory = decodeList(player, "PetInventoryJSON")
	local equipped = decodeList(player, "EquippedPetsJSON")
	local ownedCount = 0
	local equippedCount = 0
	for _, name in ipairs(inventory) do
		if name == petName then ownedCount += 1 end
	end
	for _, name in ipairs(equipped) do
		if name == petName then equippedCount += 1 end
	end
	if equippedCount >= ownedCount then
		return { ok = false, reason = "not_owned" }
	end
	if #equipped >= GameConfig.MaxEquippedPets then
		return { ok = false, reason = "slots_full" }
	end
	table.insert(equipped, petName)
	encodeList(player, "EquippedPetsJSON", equipped)
	local valid, multiplier = refreshEquippedPets(player)
	return { ok = true, pet = petName, equipped = valid, multiplier = multiplier }
end

local function unequipPet(player, petName)
	local equipped = decodeList(player, "EquippedPetsJSON")
	if not removeFirst(equipped, petName) then
		return { ok = false, reason = "not_equipped" }
	end
	encodeList(player, "EquippedPetsJSON", equipped)
	local valid, multiplier = refreshEquippedPets(player)
	return { ok = true, pet = petName, equipped = valid, multiplier = multiplier }
end

local function petSlotToken(index)
	return "slot:" .. tostring(math.max(1, math.floor(tonumber(index) or 1)))
end

local function deletePet(player, petName, inventoryIndex)
	local inventory = decodeList(player, "PetInventoryJSON")
	local selectedIndex = math.floor(tonumber(inventoryIndex) or 0)
	if selectedIndex < 1 or inventory[selectedIndex] ~= petName then
		selectedIndex = table.find(inventory, petName) or 0
	end
	if selectedIndex < 1 then
		return { ok = false, reason = "not_owned" }
	end
	local lockedPets = decodeList(player, "LockedPetsJSON")
	if listContains(lockedPets, petName) or listContains(lockedPets, petSlotToken(selectedIndex)) then
		return { ok = false, reason = "pet_locked" }
	end
	table.remove(inventory, selectedIndex)
	local shiftedLocks = {}
	for _, entry in ipairs(lockedPets) do
		local slot = tonumber(string.match(tostring(entry), "^slot:(%d+)$"))
		if slot then
			if slot < selectedIndex then table.insert(shiftedLocks, entry)
			elseif slot > selectedIndex then table.insert(shiftedLocks, petSlotToken(slot - 1)) end
		else
			table.insert(shiftedLocks, entry)
		end
	end
	local equipped = decodeList(player, "EquippedPetsJSON")
	removeFirst(equipped, petName)
	encodeList(player, "PetInventoryJSON", inventory)
	encodeList(player, "EquippedPetsJSON", equipped)
	encodeList(player, "LockedPetsJSON", shiftedLocks)
	local valid, multiplier = refreshEquippedPets(player)
	return { ok = true, pet = petName, index = selectedIndex, inventory = inventory, equipped = valid, multiplier = multiplier, locked = shiftedLocks }
end

local function setPetLocked(player, petName, locked, inventoryIndex)
	local inventory = decodeList(player, "PetInventoryJSON")
	local selectedIndex = math.floor(tonumber(inventoryIndex) or 0)
	local useSlot = selectedIndex >= 1 and inventory[selectedIndex] == petName
	if not useSlot and not listContains(inventory, petName) then
		return { ok = false, reason = "not_owned" }
	end
	local lockToken = useSlot and petSlotToken(selectedIndex) or petName
	local lockedPets = decodeList(player, "LockedPetsJSON")
	if locked and not listContains(lockedPets, lockToken) then table.insert(lockedPets, lockToken) end
	if not locked then while removeFirst(lockedPets, lockToken) do end end
	encodeList(player, "LockedPetsJSON", lockedPets)
	return { ok = true, pet = petName, index = useSlot and selectedIndex or nil, token = lockToken, locked = locked }
end

local eggDetector = Instance.new("ClickDetector")
eggDetector.MaxActivationDistance = 32
eggDetector.Parent = eggPart
eggDetector.MouseClick:Connect(function(player)
	hatchPet(player)
end)

local rebirthPart = makePart("Rebirth Shrine", interactFolder, Vector3.new(14, 13, 14), Vector3.new(160, 7, 24), Color3.fromRGB(60, 72, 82), Enum.Material.ForceField)
rebirthPart:SetAttribute("Theme", PolishConfig.StyleName)
rebirthPart.Transparency = 0.82
rebirthPart.CanCollide = false
addEmitter(rebirthPart, "Rebirth Pulse", Color3.fromRGB(255, 255, 255))
makeCylinder("Evac Portal Ring", decorFolder, Vector3.new(0.45, 22, 22), rebirthPart.Position + Vector3.new(0, -6.3, 0), Color3.fromRGB(77, 178, 214), Enum.Material.Neon, Vector3.new(0, 0, 90))
local rebirthSign = makePart("Evac Portal Compact Sign", decorFolder, Vector3.new(13, 3.8, 0.45), rebirthPart.Position + Vector3.new(0, 9.5, -7.2), Color3.fromRGB(22, 28, 32), Enum.Material.Metal)
makeText(rebirthSign, "HERO REBIRTH GATE", "LV 55 | 1M COINS", Enum.NormalId.Front)
local rebirthDetector = Instance.new("ClickDetector")
rebirthDetector.MaxActivationDistance = 35
rebirthDetector.Parent = rebirthPart

local function tryRebirth(player)
	if statValue(player, "WallLevel", 1) < 55 or statValue(player, "Coins", 0) < 1000000 then
		sendFeedback(player, {
			type = "Fail",
			target = "Rebirth",
			message = "Locked",
			color = PolishConfig.Palette.Fail,
		})
		return { ok = false, reason = "requirements" }
	end
	addStat(player, "Rebirths", 1)
	setStat(player, "Power", 25)
	setStat(player, "Coins", 0)
	setStat(player, "WallLevel", 1)
	setStat(player, "WallXP", 0)
	setStat(player, "FistMultiplier", 1)
	setStat(player, "BreakSpeed", 1)
	local fist = playerStat(player, "EquippedFist")
	if fist then
		fist.Value = "Starter Glove"
	end
	advanceTutorial(player, 7)
	emitNamed(rebirthPart, "Rebirth Pulse", 44)
	sendFeedback(player, {
		type = "Rebirth",
		target = "Rebirth",
		color = Color3.fromRGB(207, 188, 255),
	})
	return { ok = true, rebirths = statValue(player, "Rebirths", 0), power = statValue(player, "Power", 0), coins = statValue(player, "Coins", 0), wallLevel = statValue(player, "WallLevel", 0) }
end

rebirthDetector.MouseClick:Connect(function(player)
	tryRebirth(player)
end)

local function equipFist(player, fistName)
	local item = fistByName[fistName]
	local owned = decodeList(player, "OwnedFistsJSON")
	if not item or not listContains(owned, fistName) then
		return { ok = false, reason = "not_owned" }
	end
	setStat(player, "EquippedFist", fistName)
	setStat(player, "FistMultiplier", item.mult)
	setStat(player, "BreakSpeed", 1 + item.speed)
	sendFeedback(player, { type = "Shop", target = fistName, color = PolishConfig.Palette.Use })
	return { ok = true, item = fistName, multiplier = item.mult }
end

local function claimDaily(player)
	local today = os.date("!%Y-%m-%d")
	if statValue(player, "LastDailyDate", "") == today then
		sendFeedback(player, { type = "Fail", target = "Daily", message = "Already claimed", color = PolishConfig.Palette.Fail })
		return { ok = false, reason = "already_claimed" }
	end
	setStat(player, "LastDailyDate", today)
	addStat(player, "Coins", GameConfig.Rewards.DailyCoins)
	sendFeedback(player, { type = "Reward", target = "Daily", coins = GameConfig.Rewards.DailyCoins, power = 0, color = PolishConfig.Palette.Reward })
	return { ok = true, reward = GameConfig.Rewards.DailyCoins }
end

local function spinReward(player)
	local now = os.time()
	local lastSpin = tonumber(player:GetAttribute("LastHeroSpinAt")) or 0
	local cooldown = 60
	if now - lastSpin < cooldown then
		local remaining = cooldown - (now - lastSpin)
		sendFeedback(player, { type = "Fail", target = "Spin", message = ("Spin ready in %ds"):format(remaining), color = PolishConfig.Palette.Fail })
		return { ok = false, reason = "cooldown", remaining = remaining }
	end
	player:SetAttribute("LastHeroSpinAt", now)
	local roll = math.random(1, 100)
	local coins = roll <= 5 and 2500 or roll <= 25 and 800 or 250
	addStat(player, "Coins", coins)
	sendFeedback(player, { type = "Reward", target = "Hero Spin", coins = coins, color = PolishConfig.Palette.Reward })
	return { ok = true, coins = coins, roll = roll }
end

local function claimQuest(player)
	if statValue(player, "DailyQuestClaimed", 0) >= 1 then
		sendFeedback(player, { type = "Fail", target = "Quest", message = "Already claimed", color = PolishConfig.Palette.Fail })
		return { ok = false, reason = "already_claimed" }
	end
	if statValue(player, "DailyBreaks", 0) < GameConfig.Rewards.QuestBreakTarget then
		local remaining = GameConfig.Rewards.QuestBreakTarget - statValue(player, "DailyBreaks", 0)
		sendFeedback(player, { type = "Fail", target = "Quest", message = ("Break %d more building(s)"):format(remaining), color = PolishConfig.Palette.Fail })
		return { ok = false, reason = "not_ready" }
	end
	setStat(player, "DailyQuestClaimed", 1)
	addStat(player, "Coins", GameConfig.Rewards.QuestCoins)
	sendFeedback(player, { type = "Reward", target = "Quest", coins = GameConfig.Rewards.QuestCoins, power = 0, color = PolishConfig.Palette.Reward })
	return { ok = true, reward = GameConfig.Rewards.QuestCoins }
end

local function claimPlaytime(player)
	if statValue(player, "PlaytimeClaimed", 0) >= 1 then
		sendFeedback(player, { type = "Fail", target = "Playtime", message = "Already claimed", color = PolishConfig.Palette.Fail })
		return { ok = false, reason = "already_claimed" }
	end
	if statValue(player, "PlaytimeSeconds", 0) < GameConfig.Rewards.PlaytimeSeconds then
		local remaining = GameConfig.Rewards.PlaytimeSeconds - statValue(player, "PlaytimeSeconds", 0)
		sendFeedback(player, { type = "Fail", target = "Playtime", message = ("Play %d more second(s)"):format(remaining), color = PolishConfig.Palette.Fail })
		return { ok = false, reason = "not_ready" }
	end
	setStat(player, "PlaytimeClaimed", 1)
	addStat(player, "Coins", GameConfig.Rewards.PlaytimeCoins)
	sendFeedback(player, { type = "Reward", target = "Playtime", coins = GameConfig.Rewards.PlaytimeCoins, power = 0, color = PolishConfig.Palette.Reward })
	return { ok = true, reward = GameConfig.Rewards.PlaytimeCoins }
end

local function characterRoot(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function nearestNamedPart(player, partsByName)
	local rootPart = characterRoot(player)
	if not rootPart then
		return nil
	end

	local nearestName = nil
	local nearestPart = nil
	local nearestDistance = MOBILE_ACTION_DISTANCE
	for name, part in pairs(partsByName) do
		if part and part.Parent then
			local distance = (rootPart.Position - part.Position).Magnitude
			if distance <= nearestDistance then
				nearestName = name
				nearestPart = part
				nearestDistance = distance
			end
		end
	end

	return nearestName, nearestPart, nearestDistance
end

local function nearestWall(player)
	local rootPart = characterRoot(player)
	if not rootPart then
		return nil
	end

	local nearest = nil
	local nearestDistance = MOBILE_ACTION_DISTANCE
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.FilterDescendantsInstances = { depthBlocksFolder }
	overlap.MaxParts = 400
	for _, block in ipairs(workspace:GetPartBoundsInRadius(rootPart.Position, MOBILE_ACTION_DISTANCE, overlap)) do
		if block:GetAttribute("IsDepthBlock") and not block:GetAttribute("Broken") then
			local offset = block.Position - rootPart.Position
			local distance = offset.Magnitude
			local facing = distance > 0 and rootPart.CFrame.LookVector:Dot(offset.Unit) or 1
			if facing > -0.1 and distance < nearestDistance then
				nearest = block
				nearestDistance = distance
			end
		end
	end
	if nearest then return nearest, nearestDistance end
	local bossDistance = (rootPart.Position - boss.Position).Magnitude
	if bossDistance <= nearestDistance then return boss, bossDistance end

	return nearest, nearestDistance
end

local function nearestUseTarget(player)
	local rootPart = characterRoot(player)
	if not rootPart then
		return nil
	end

	local nearestKind = nil
	local nearestName = nil
	local nearestDistance = MOBILE_ACTION_DISTANCE

	for name, part in pairs(fistPartsByName) do
		if part and part.Parent then
			local distance = (rootPart.Position - part.Position).Magnitude
			if distance <= nearestDistance then
				nearestKind = "Fist"
				nearestName = name
				nearestDistance = distance
			end
		end
	end

	for _, target in ipairs({
		{ kind = "Egg", name = "Pet Egg Machine", part = eggPart },
		{ kind = "Rebirth", name = "Rebirth Shrine", part = rebirthPart },
	}) do
		if target.part and target.part.Parent then
			local distance = (rootPart.Position - target.part.Position).Magnitude
			if distance <= nearestDistance then
				nearestKind = target.kind
				nearestName = target.name
				nearestDistance = distance
			end
		end
	end

	return nearestKind, nearestName, nearestDistance
end

local function handleMobileAction(player, request)
	local action = request
	local target
	local value
	local inventoryIndex
	if typeof(request) == "table" then
		action = request.action
		target = request.target
		value = request.value
		inventoryIndex = request.index
	end
	if typeof(action) ~= "string" then
		return
	end
	local now = os.clock()
	local lastAction = player:GetAttribute("LastMobileAction") or 0
	if now - lastAction < MOBILE_ACTION_COOLDOWN then
		return
	end
	player:SetAttribute("LastMobileAction", now)

	if action == "RequestSync" then
		syncStats(player)
		return
	elseif action == "ToggleStudioHighPowerTest" then
		shared.PunchWallStudioTest.set(player, value == true)
		return
	elseif action == "BuyFist" then
		local item = target and fistByName[target]
		if item then buyFist(player, item) end
		return
	elseif action == "EquipFist" then
		equipFist(player, target)
		return
	elseif action == "BuyShopBoost" then
		shared.PunchWallShopBoostPurchase(player, target)
		return
	elseif action == "HatchPet" then
		hatchPets(player, value)
		return
	elseif action == "EquipPet" then
		equipPet(player, target)
		return
	elseif action == "UnequipPet" then
		unequipPet(player, target)
		return
	elseif action == "DeletePet" then
		deletePet(player, target, inventoryIndex)
		return
	elseif action == "LockPet" then
		setPetLocked(player, target, value == true, inventoryIndex)
		return
	elseif action == "ClaimDaily" then
		claimDaily(player)
		return
	elseif action == "Spin" then
		spinReward(player)
		return
	elseif action == "ClaimQuest" then
		claimQuest(player)
		return
	elseif action == "ClaimPlaytime" then
		claimPlaytime(player)
		return
	elseif action == "UpdateSettings" and typeof(value) == "table" then
		local settings = {
			motion = value.motion ~= false,
			sound = value.sound ~= false,
			uiScale = math.clamp(tonumber(value.uiScale) or 1, 0.8, 1.2),
		}
		setStat(player, "SettingsJSON", HttpService:JSONEncode(settings))
		return
	elseif action == "Rebirth" then
		tryRebirth(player)
		return
	elseif action == "Train" then
		local stationName = nearestNamedPart(player, trainingPartsByName)
		local config = stationName and trainingByName[stationName]
		if not config then
			sendFeedback(player, { type = "Fail", target = "Train", message = "Move closer", color = PolishConfig.Palette.Fail })
			return
		end
		trainPlayer(player, config)
	elseif action == "Punch" then
		local radiusResult = depthPunch.Punch(player)
		if radiusResult.ok or radiusResult.reason == "cooldown" then return end
		local wall = nearestWall(player)
		if not wall or wall:GetAttribute("IsDepthBlock") then
			sendFeedback(player, { type = "Fail", target = "Punch", message = "Move closer", color = PolishConfig.Palette.Fail })
			return
		end
		if wall == boss then
			hitBoss(player)
		else
			hitWall(player, wall)
		end
	elseif action == "Use" then
		local targetKind, targetName = nearestUseTarget(player)
		if targetKind == "Fist" then
			buyFist(player, fistByName[targetName])
		elseif targetKind == "Egg" then
			hatchPet(player)
		elseif targetKind == "Rebirth" then
			tryRebirth(player)
		else
			sendFeedback(player, { type = "Fail", target = "Use", message = "Move closer", color = PolishConfig.Palette.Fail })
		end
	end
end

actionRemote.OnServerEvent:Connect(function(player, action)
	if typeof(action) ~= "string" and typeof(action) ~= "table" then
		return
	end
	handleMobileAction(player, action)
end)

local function resetWallState(wall)
	if wall.Name == "Titan Server Wall" then wall:SetAttribute("MaxHP", BOSS_BASE_HP) end
	wall:SetAttribute("HP", wall:GetAttribute("MaxHP"))
	wall:SetAttribute("Broken", false)
	wall:SetAttribute("RespawnAt", 0)
	if wall:GetAttribute("OriginalColor") then
		wall.Color = wall:GetAttribute("OriginalColor")
	end
	wall.Transparency = wall:GetAttribute("OriginalTransparency") or 0
	wall.CanCollide = true
	setWallVisualDetailsBroken(wall, false)
	setWallDebrisState(wall, false)
	setWallLabelsEnabled(wall, true)
	wallContributions[wall] = {}
	updateWallText(wall)
	updateWallDamage(wall)
end

function resetWorldState()
	for _, wall in ipairs(wallsFolder:GetChildren()) do
		if wall:IsA("BasePart") then
			resetWallState(wall)
		end
	end
	for _, block in ipairs(depthBlocksFolder:GetChildren()) do
		block:SetAttribute("HP", block:GetAttribute("MaxHP"))
		block:SetAttribute("Broken", false)
		block:SetAttribute("DamageStage", 0)
		block:SetAttribute("LastRadiusDamageScale", 0)
		block:SetAttribute("LastRadiusHitAt", 0)
		block:SetAttribute("Shaking", false)
		block:SetAttribute("ShakeToken", (block:GetAttribute("ShakeToken") or 0) + 1)
		block:SetAttribute("StructuralFalling", false)
		block:SetAttribute("StructuralDetached", false)
		block:SetAttribute("StructuralFailure", false)
		block:SetAttribute("StructuralToken", (block:GetAttribute("StructuralToken") or 0) + 1)
		block:SetAttribute("DetachedImpactToken", (block:GetAttribute("DetachedImpactToken") or 0) + 1)
		block:SetAttribute("SettledCFrame", nil)
		block:SetAttribute("DetachedImpactOrigin", nil)
		block:SetAttribute("LastDetachedLaunchSpeed", nil)
		block:SetAttribute("LastOverlapEjectAt", nil)
		block:SetAttribute("LastOverlapEjectSpeed", nil)
		block.Color = block:GetAttribute("OriginalColor") or block.Color
		block.CFrame = block:GetAttribute("BaseCFrame") or block.CFrame
		block.Transparency = 0
		block.Anchored = true
		block.CanCollide = true
		block.CanQuery = true
		block.CollisionGroup = "Default"
		depthBlockContributions[block] = {}
	end
	depthDebrisFolder:ClearAllChildren()
	root:SetAttribute("ActiveStructuralFalling", 0)
	root:SetAttribute("LastStructuralCollapseCount", 0)
	root:SetAttribute("LastCharacterOverlapEjectCount", 0)
	resetWallState(boss)
	bossContributions = {}
	bossParticipants = {}
	boss:SetAttribute("BossPhase", 1)
	boss:SetAttribute("ParticipantCount", 0)
	boss:SetAttribute("RespawnAt", 0)
	boss:SetAttribute("NextAttackAt", 0)
	local count = 0
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if character and rootPart then
			rootPart.AssemblyLinearVelocity = Vector3.zero
			rootPart.AssemblyAngularVelocity = Vector3.zero
			character:PivotTo(spawn.CFrame + Vector3.new(0, 5, 0))
			if humanoid then
				humanoid.PlatformStand = false
				humanoid.Sit = false
				humanoid:ChangeState(Enum.HumanoidStateType.Running)
			end
			count += 1
		end
	end
	local now = workspace:GetServerTimeNow()
	root:SetAttribute("LastWorldResetAt", now)
	root:SetAttribute("NextWorldResetAt", now + WORLD_RESET_INTERVAL)
	root:SetAttribute("WorldResetCount", (root:GetAttribute("WorldResetCount") or 0) + 1)
	for _, player in ipairs(Players:GetPlayers()) do
		sendFeedback(player, {
			type = "WorldReset",
			target = "Spawn",
			message = "WORLD RESET | RETURN TO SPAWN",
			color = PolishConfig.Palette.HeroCyan,
		})
	end
	return {
		action = "WorldReset",
		ok = true,
		teleportedPlayers = count,
		resetAt = now,
		resetCount = root:GetAttribute("WorldResetCount"),
	}
end

local function automationSnapshot(player, extra)
	local result = collectPlayerData(player)
	local brickBlock = depthBlockAliases["Brick Wall"]
	result.BrickWallHP = brickBlock and brickBlock:GetAttribute("HP") or 0
	result.BrickWallBroken = brickBlock and brickBlock:GetAttribute("Broken") == true or false
	result.TitanHP = boss:GetAttribute("HP")
	result.TitanBroken = boss:GetAttribute("Broken") == true
	local intactBlocks = 0
	local brokenBlocks = 0
	local detachedBlocks = 0
	for _, block in ipairs(depthBlocksFolder:GetChildren()) do
		if block:GetAttribute("Broken") then
			brokenBlocks += 1
		elseif block:GetAttribute("StructuralDetached") then
			detachedBlocks += 1
		else
			intactBlocks += 1
		end
	end
	result.IntactDepthBlocks = intactBlocks
	result.BrokenDepthBlocks = brokenBlocks
	result.DetachedDepthBlocks = detachedBlocks
	result.PhysicsFragments = #depthDebrisFolder:GetChildren()
	if extra then
		for key, value in pairs(extra) do
			result[key] = value
		end
	end
	return result
end

local function resetAutomationState(player)
	for _, name in ipairs(LEADERSTAT_NAMES) do
		setStat(player, name, NUMBER_STAT_DEFAULTS[name])
	end
	for _, name in ipairs(RPG_NUMBER_STAT_NAMES) do
		setStat(player, name, NUMBER_STAT_DEFAULTS[name])
	end
	for _, name in ipairs(RPG_TEXT_STAT_NAMES) do
		setStat(player, name, TEXT_STAT_DEFAULTS[name])
	end
	player:SetAttribute("LastWallHit", 0)
	player:SetAttribute("LastBossHit", 0)
	for _, config in ipairs(trainingConfigs) do
		player:SetAttribute("LastTrain" .. config.stat, 0)
	end
	resetWorldState()
	return automationSnapshot(player, { action = "Reset", ok = true })
end

if RunService:IsStudio() then
	local existing = ServerStorage:FindFirstChild("PunchWallAutomation")
	if existing then
		existing:Destroy()
	end

	local automationCommand = Instance.new("BindableFunction")
	automationCommand.Name = "PunchWallAutomation"
	automationCommand.Parent = ServerStorage
	automationCommand.OnInvoke = function(action, target, amount)
		local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
		player:WaitForChild("leaderstats", 5)
		player:WaitForChild("RPGStats", 5)

		if action == "Reset" then
			return resetAutomationState(player)
		elseif action == "ResetWorld" then
			return automationSnapshot(player, resetWorldState())
		elseif action == "SetStats" then
			for name, value in pairs(target or {}) do
				setStat(player, name, value)
			end
			return automationSnapshot(player, { action = action, ok = true })
		elseif action == "Train" then
			local config = trainingByName[target]
			assert(config, "Unknown training station: " .. tostring(target))
			player:SetAttribute("LastTrain" .. config.stat, 0)
			return automationSnapshot(player, trainPlayer(player, config))
		elseif action == "HitWall" then
			local wall = wallsFolder:FindFirstChild(target) or depthBlockAliases[target]
			assert(wall, "Unknown wall: " .. tostring(target))
			player:SetAttribute("LastWallHit", 0)
			return automationSnapshot(player, wall:GetAttribute("IsDepthBlock") and hitDepthBlock(player, wall) or hitWall(player, wall))
		elseif action == "HitDepthBlock" or action == "BreakDepthBlock" then
			local selector = typeof(target) == "table" and target or { name = target }
			local block = selector.name and depthBlocksFolder:FindFirstChild(tostring(selector.name))
			if not block and selector.layer and selector.column and selector.row then
				for _, candidate in ipairs(depthBlocksFolder:GetChildren()) do
					if candidate:GetAttribute("Depth") == tonumber(selector.layer)
						and candidate:GetAttribute("Column") == tonumber(selector.column)
						and candidate:GetAttribute("Row") == tonumber(selector.row) then
						block = candidate
						break
					end
				end
			end
			if not block then
				local layer = math.clamp(math.floor(tonumber(selector.layer) or 1), 1, DEPTH_LAYERS)
				local column = math.clamp(math.floor(tonumber(selector.column) or 6), 1, DEPTH_COLUMNS)
				local row = math.clamp(math.floor(tonumber(selector.row) or 2), 1, DEPTH_ROWS)
				block = depthBlocksFolder:FindFirstChild(("DepthBlock_L%03d_C%02d_R%02d"):format(layer, column, row))
			end
			assert(block, "Unknown depth block")
			local result
			local attempts = action == "BreakDepthBlock" and (tonumber(amount) or 100) or 1
			for _ = 1, attempts do
				if block:GetAttribute("Broken") then break end
				player:SetAttribute("LastWallHit", 0)
				result = hitDepthBlock(player, block)
			end
			return automationSnapshot(player, result or { ok = false, reason = "not_hit" })
		elseif action == "PunchRadius" then
			player:SetAttribute("LastWallHit", 0)
			return automationSnapshot(player, depthPunch.Punch(player))
		elseif action == "PunchWithCooldown" then
			return automationSnapshot(player, depthPunch.Punch(player))
		elseif action == "BreakWall" then
			local wall = wallsFolder:FindFirstChild(target) or depthBlockAliases[target]
			assert(wall, "Unknown wall: " .. tostring(target))
			local result
			for _ = 1, amount or 20 do
				if wall:GetAttribute("Broken") then
					break
				end
				player:SetAttribute("LastWallHit", 0)
				result = wall:GetAttribute("IsDepthBlock") and hitDepthBlock(player, wall) or hitWall(player, wall)
			end
			return automationSnapshot(player, result or { ok = false, reason = "not_hit" })
		elseif action == "BreakWallCycles" then
			local wall = wallsFolder:FindFirstChild(target) or depthBlockAliases[target]
			assert(wall, "Unknown wall: " .. tostring(target))
			local cycles = math.clamp(tonumber(amount) or 1, 1, 200)
			local completed = 0
			for _ = 1, cycles do
				if statValue(player, "WallLevel", 1) < (wall:GetAttribute("RequiredLevel") or 1) then break end
				for _ = 1, 500 do
					if wall:GetAttribute("Broken") then break end
					player:SetAttribute("LastWallHit", 0)
					if wall:GetAttribute("IsDepthBlock") then hitDepthBlock(player, wall) else hitWall(player, wall) end
				end
				if not wall:GetAttribute("Broken") then break end
				completed += 1
				if wall:GetAttribute("IsDepthBlock") then
					wall:SetAttribute("HP", wall:GetAttribute("MaxHP"))
					wall:SetAttribute("Broken", false)
					wall:SetAttribute("DamageStage", 0)
					wall.Color = wall:GetAttribute("OriginalColor") or wall.Color
					wall.Transparency = 0
					wall.CanCollide = true
					wall.CanQuery = true
					depthBlockContributions[wall] = {}
				else
					resetWallState(wall)
					wallContributions[wall] = {}
				end
			end
			return automationSnapshot(player, { action = action, ok = completed > 0, completed = completed })
		elseif action == "BuyFist" then
			local item = fistByName[target]
			assert(item, "Unknown fist: " .. tostring(target))
			return automationSnapshot(player, buyFist(player, item))
		elseif action == "HatchPet" then
			return automationSnapshot(player, hatchPet(player))
		elseif action == "EquipPet" then
			return automationSnapshot(player, equipPet(player, target))
		elseif action == "UnequipPet" then
			return automationSnapshot(player, unequipPet(player, target))
		elseif action == "DeletePet" then
			return automationSnapshot(player, deletePet(player, target))
		elseif action == "LockPet" then
			return automationSnapshot(player, setPetLocked(player, target, amount == true or amount == 1))
		elseif action == "EquipFist" then
			return automationSnapshot(player, equipFist(player, target))
		elseif action == "BuyShopBoost" then
			return automationSnapshot(player, shared.PunchWallShopBoostPurchase(player, target))
		elseif action == "ClaimDaily" then
			return automationSnapshot(player, claimDaily(player))
		elseif action == "Spin" then
			player:SetAttribute("LastHeroSpinAt", 0)
			return automationSnapshot(player, spinReward(player))
		elseif action == "ClaimQuest" then
			return automationSnapshot(player, claimQuest(player))
		elseif action == "ClaimPlaytime" then
			return automationSnapshot(player, claimPlaytime(player))
		elseif action == "Rebirth" then
			return automationSnapshot(player, tryRebirth(player))
		elseif action == "HitBoss" then
			player:SetAttribute("LastBossHit", 0)
			return automationSnapshot(player, hitBoss(player))
		elseif action == "HitBossWeakPoint" then
			player:SetAttribute("LastBossHit", 0)
			return automationSnapshot(player, hitBoss(player, 1.5))
		elseif action == "Snapshot" then
			return automationSnapshot(player, { action = action, ok = true })
		end

		error("Unknown automation action: " .. tostring(action))
	end
end

Players.PlayerAdded:Connect(ensureStats)
Players.PlayerRemoving:Connect(function(player)
	savePlayerData(player)
	shared.PunchWallStudioTest.snapshots[player] = nil
end)
for _, player in ipairs(Players:GetPlayers()) do
	ensureStats(player)
end

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		savePlayerData(player)
	end
end)

task.spawn(function()
	while root.Parent do
		task.wait(WORLD_RESET_INTERVAL)
		if not root.Parent then break end
		resetWorldState()
	end
end)

task.spawn(function()
	while true do
		task.wait(1)
		local today = os.date("!%Y-%m-%d")
		for _, player in ipairs(Players:GetPlayers()) do
			if player:FindFirstChild("RPGStats") then
				addStat(player, "PlaytimeSeconds", 1)
				if statValue(player, "DailyQuestDate", "") ~= today then
					setStat(player, "DailyBreaks", 0)
					setStat(player, "DailyQuestClaimed", 0)
					setStat(player, "DailyQuestDate", today)
				end
			end
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(AUTOSAVE_SECONDS)
		for _, player in ipairs(Players:GetPlayers()) do
			savePlayerData(player)
		end
	end
end)
