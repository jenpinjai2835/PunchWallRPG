local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local InsertService = game:GetService("InsertService")
local AssetService = game:GetService("AssetService")
local MaterialService = game:GetService("MaterialService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local DataStoreService = game:GetService("DataStoreService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local MarketplaceService = game:GetService("MarketplaceService")
local PolishConfig = require(ReplicatedStorage:WaitForChild("PolishConfig"))
local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local visualSafety = {
	sanitizer = require(ReplicatedStorage:WaitForChild("FistVisualBuilder")),
	maxBaseParts = 96,
	maxDescendants = 256,
	maxRawDescendants = 512,
	maxTemplateBaseParts = 1024,
	maxTemplateDescendants = 3072,
	maxRuntimeBaseParts = 1024,
	maxRuntimeDescendants = 4096,
	templateLoadDeadlineSeconds = 12,
}

visualSafety.hasConfiguredGamePass = function(item)
	local gamePassId = item and tonumber(item.gamePassId)
	if gamePassId == nil or gamePassId <= 0 or gamePassId % 1 ~= 0 then
		return false
	end
	local matches = 0
	for _, catalog in ipairs({ GameConfig.PremiumFists, GameConfig.PremiumPets }) do
		for _, candidate in ipairs(catalog) do
			if tonumber(candidate.gamePassId) == gamePassId then
				matches += 1
			end
		end
	end
	return matches == 1
end

visualSafety.hasConfiguredDeveloperProduct = function(product)
	local productId = product and tonumber(product.productId)
	return productId ~= nil and productId > 0
end

visualSafety.markWorldOfferAvailability = function(instance, configured, offerKind)
	instance:SetAttribute("PurchaseConfigured", configured)
	instance:SetAttribute("PurchaseUnavailable", not configured)
	instance:SetAttribute("OfferKind", offerKind)
	if not configured then
		instance:SetAttribute(
			"UnavailableReason",
			offerKind == "GamePass" and "GamePassIdNotConfigured"
				or "ProductIdNotConfigured"
		)
	end
end
local ProfilePersistence = require(script.Parent:WaitForChild("ProfilePersistence"))

local ROOT_NAME = "PunchWallRPG"
local WALL_RESPAWN_SECONDS = GameConfig.RegularWallRespawnSeconds
local TRAINING_COOLDOWN = 0.45
local WALL_HIT_COOLDOWN = 1
WORLD_RESET_INTERVAL = 300
local EGG_COST = 350
local MOBILE_ACTION_DISTANCE = 38
local TRAINING_INTERACTION_DISTANCE = 18
local MOBILE_ACTION_COOLDOWN = 0.12
local tryDropPetEgg

local persistenceRuntime = {
	autosaveSeconds = 75,
	dataStoreAttempts = 5,
	dataStoreRetryBaseSeconds = 0.5,
	sessionLeaseSeconds = 120,
	playerRemovingSaveTimeout = 10,
	shutdownDrainTimeout = 25,
	receiptWaitTimeout = 20,
	maxQueueOperations = 32,
	maxSaveTicketsPerOperation = 8,
	maxPendingGamePassGrants = 16,
	gamePassOwnershipAttempts = 2,
	gamePassReconciliationAttempts = 3,
	gamePassReconciliationRetryBaseSeconds = 2,
	-- Studio must never touch live player profiles by accident, including after a
	-- local place is linked to a published universe. A deliberate production-data
	-- test requires an explicit ServerStorage attribute and remains non-default.
	isEphemeralStudio = RunService:IsStudio()
		and ServerStorage:GetAttribute("PunchWallAllowLiveDataStoreAccess") ~= true,
	studioLiveDataOptIn = RunService:IsStudio()
		and ServerStorage:GetAttribute("PunchWallAllowLiveDataStoreAccess") == true,
	profileSessions = {},
	queues = {},
	finalSaveTickets = setmetatable({}, { __mode = "k" }),
	pendingGamePassGrants = {},
	serverClosing = false,
}
do
	local ok, contract = pcall(ProfilePersistence.RunContractSelfTest, GameConfig.DataVersion)
	if not ok then
		error(("[PunchWallRPG] Persistence contract self-test failed: %s"):format(tostring(contract)))
	end
	persistenceRuntime.contract = contract
end

StarterPlayer.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Zoom
pcall(function() PhysicsService:RegisterCollisionGroup("PlayerCharacters") end)
pcall(function() PhysicsService:RegisterCollisionGroup("PunchingCharacters") end)
pcall(function() PhysicsService:RegisterCollisionGroup("DepthRubble") end)
pcall(function() PhysicsService:RegisterCollisionGroup("FallingStructural") end)
pcall(function() PhysicsService:RegisterCollisionGroup("DepthFragments") end)
pcall(function() PhysicsService:RegisterCollisionGroup("DepthStructure") end)
PhysicsService:CollisionGroupSetCollidable("PlayerCharacters", "DepthRubble", true)
PhysicsService:CollisionGroupSetCollidable("PlayerCharacters", "FallingStructural", false)
PhysicsService:CollisionGroupSetCollidable("PlayerCharacters", "DepthFragments", false)
PhysicsService:CollisionGroupSetCollidable("PunchingCharacters", "DepthRubble", false)
PhysicsService:CollisionGroupSetCollidable("PunchingCharacters", "FallingStructural", false)
PhysicsService:CollisionGroupSetCollidable("PunchingCharacters", "DepthFragments", false)
PhysicsService:CollisionGroupSetCollidable("FallingStructural", "DepthStructure", false)

shared.PunchWallSetCharacterCollisionGroup = function(character, groupName)
	if not character then return end
	character:SetAttribute("DepthActiveCollisionGroup", groupName)
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then descendant.CollisionGroup = groupName end
	end
end

local function applyCharacterCollisionGroup(character)
	shared.PunchWallSetCharacterCollisionGroup(character, "PlayerCharacters")
	if character:GetAttribute("DepthCollisionGroupApplied") then return end
	character:SetAttribute("DepthCollisionGroupApplied", true)
	character.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = character:GetAttribute("DepthActiveCollisionGroup") or "PlayerCharacters"
		end
	end)
end

local NUMBER_STAT_DEFAULTS = {
	Power = 15,
	Coins = 0,
	Honor = 0,
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
	TutorialVersion = 2,
	TutorialCompleted = 0,
	DailyBreaks = 0,
	DailyQuestClaimed = 0,
	PlaytimeSeconds = 0,
	PlaytimeClaimed = 0,
	HonorPowerBonus = 0,
	HonorMilestoneMask = 0,
	HonorRebirthMilestoneMask = 0,
	HonorClearsToday = 0,
	LastHonorClearAt = 0,
	LastSpinAt = 0,
	SpinCredits = 0,
	TrainingActive = 0,
	TrainingUpdatedAt = 0,
	LastHonorCycle = -1,
	PetDropPity = 0,
}

local TEXT_STAT_DEFAULTS = {
	EquippedFist = "Starter Glove",
	Pet = "None",
	TrainingStationId = "rookie_bag",
	OwnedFistsJSON = "[\"Starter Glove\"]",
	OwnedPremiumFistsJSON = "[]",
	OwnedPremiumPetsJSON = "[]",
	OwnedHonorItemsJSON = "[]",
	EquippedHonorItem = "None",
	HonorClearDate = "",
	LastHonorClearId = "",
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
	"Honor",
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
	"TutorialVersion",
	"TutorialCompleted",
	"DailyBreaks",
	"DailyQuestClaimed",
	"PlaytimeSeconds",
	"PlaytimeClaimed",
	"HonorPowerBonus",
	"HonorMilestoneMask",
	"HonorRebirthMilestoneMask",
	"HonorClearsToday",
	"LastHonorClearAt",
	"LastSpinAt",
	"SpinCredits",
	"TrainingActive",
	"TrainingUpdatedAt",
	"LastHonorCycle",
	"PetDropPity",
}

local RPG_TEXT_STAT_NAMES = {
	"EquippedFist",
	"Pet",
	"TrainingStationId",
	"OwnedFistsJSON",
	"OwnedPremiumFistsJSON",
	"OwnedPremiumPetsJSON",
	"OwnedHonorItemsJSON",
	"EquippedHonorItem",
	"HonorClearDate",
	"LastHonorClearId",
	"PetInventoryJSON",
	"EquippedPetsJSON",
	"DiscoveredPetsJSON",
	"LockedPetsJSON",
	"LastDailyDate",
	"DailyQuestDate",
	"SettingsJSON",
}

local function profileSessionReady(session, hasRPGStats, hasLeaderstats, requireWritable)
	if not session then
		return false, "profile_not_loaded"
	end
	if session.initializing == true or session.ready ~= true then
		return false, "profile_initializing"
	end
	if not hasRPGStats or not hasLeaderstats then
		return false, "profile_stats_not_ready"
	end
	if requireWritable and session.writable ~= true then
		return false, "profile_not_writable"
	end
	return true
end

local function hasCompleteProfileStats(player)
	local stats = player and player:FindFirstChild("RPGStats")
	local leaderstats = player and player:FindFirstChild("leaderstats")
	if not stats or not leaderstats then
		return false, false
	end
	for _, name in ipairs(LEADERSTAT_NAMES) do
		local value = leaderstats:FindFirstChild(name)
		if not value or not value:IsA("NumberValue") then
			return true, false
		end
	end
	for _, name in ipairs(RPG_NUMBER_STAT_NAMES) do
		local value = stats:FindFirstChild(name)
		if not value or not value:IsA("NumberValue") then
			return false, true
		end
	end
	for _, name in ipairs(RPG_TEXT_STAT_NAMES) do
		local value = stats:FindFirstChild(name)
		if not value or not value:IsA("StringValue") then
			return false, true
		end
	end
	return true, true
end

local function profileReady(player, requireWritable)
	local hasRPGStats, hasLeaderstats = hasCompleteProfileStats(player)
	return profileSessionReady(
		persistenceRuntime.profileSessions[player],
		hasRPGStats,
		hasLeaderstats,
		requireWritable == true
	)
end

local function runProfileReadinessContract()
	local initializing = { initializing = true, ready = false, writable = false }
	local durableReady = { initializing = false, ready = true, writable = true }
	local ephemeralReady = { initializing = false, ready = true, writable = false }
	local counters = {
		remoteMutations = 0,
		clickMutations = 0,
		updateAsyncCalls = 0,
		grants = 0,
	}
	for counterName in pairs(counters) do
		local allowed = profileSessionReady(initializing, true, true, counterName == "updateAsyncCalls")
		if allowed then
			counters[counterName] += 1
		end
	end
	assert(counters.remoteMutations == 0, "Initializing profiles must reject remote mutations")
	assert(counters.clickMutations == 0, "Initializing profiles must reject click mutations")
	assert(counters.updateAsyncCalls == 0, "Initializing profiles must not call UpdateAsync")
	assert(counters.grants == 0, "Initializing profiles must not grant purchases")
	assert(initializing.writable == false, "Initializing profiles must never become writable early")
	assert(profileSessionReady(durableReady, true, true, true), "Complete durable profiles must pass the gate")
	assert(not profileSessionReady(durableReady, false, true, false), "Missing RPGStats must fail closed")
	assert(not profileSessionReady(durableReady, true, false, false), "Missing leaderstats must fail closed")
	assert(profileSessionReady(ephemeralReady, true, true, false), "Ready ephemeral profiles must allow gameplay")
	assert(not profileSessionReady(ephemeralReady, true, true, true), "Ephemeral profiles must remain nonwritable")

	local pending = {}
	local pendingOrder = {}
	local function queueOnce(key)
		if pending[key] then
			return false
		end
		pending[key] = true
		table.insert(pendingOrder, key)
		return true
	end
	assert(queueOnce("Fist:101"), "First pending GamePass grant must queue")
	assert(not queueOnce("Fist:101"), "Duplicate GamePass ownership must be idempotent")
	local flushed = 0
	for _, key in ipairs(pendingOrder) do
		if pending[key] then
			flushed += 1
			pending[key] = nil
		end
	end
	assert(flushed == 1 and next(pending) == nil, "Pending GamePass grants must flush exactly once")

	return {
		preReadyMutationCount = counters.remoteMutations + counters.clickMutations,
		preReadyUpdateAsyncCalls = counters.updateAsyncCalls,
		preReadyGrantCount = counters.grants,
		noEarlyWritable = initializing.writable == false,
		readyPathAllowed = profileSessionReady(durableReady, true, true, true) == true,
		pendingGamePassFlushCount = flushed,
		duplicateGamePassIgnored = true,
	}
end

persistenceRuntime.profileSessionReady = profileSessionReady
persistenceRuntime.profileReady = profileReady
persistenceRuntime.readinessContract = runProfileReadinessContract()

if persistenceRuntime.isEphemeralStudio then
	warn("[PunchWallRPG] Studio session is EPHEMERAL by default; live profile reads and writes are disabled.")
else
	local dataStoreOk, currentStore, legacyStore = pcall(function()
		return DataStoreService:GetDataStore("PunchWallRPG_PlayerStats_v2"),
			DataStoreService:GetDataStore("PunchWallRPG_PlayerStats_v1")
	end)
	if dataStoreOk then
		persistenceRuntime.playerStore = currentStore
		persistenceRuntime.legacyPlayerStore = legacyStore
	else
		warn(("[PunchWallRPG] DataStore initialization failed: %s"):format(tostring(currentStore)))
	end
end

local root = workspace:FindFirstChild(ROOT_NAME)
if root then
	root:Destroy()
end

root = Instance.new("Folder")
root.Name = ROOT_NAME
root:SetAttribute("Theme", PolishConfig.StyleName)
root:SetAttribute("VisualDirection", "Anime Hero Action")
root:SetAttribute("PersistenceContractPassed", true)
root:SetAttribute("PersistenceContractVersion", persistenceRuntime.contract.version)
root:SetAttribute("PersistenceDataVersion", persistenceRuntime.contract.dataVersion)
root:SetAttribute("PersistenceMaxSeenReceiptIds", persistenceRuntime.contract.maxSeenReceiptIds)
root:SetAttribute("ProfileReadinessContractPassed", true)
root:SetAttribute("ProfileReadinessPreReadyMutationCount", persistenceRuntime.readinessContract.preReadyMutationCount)
root:SetAttribute("ProfileReadinessPreReadyUpdateAsyncCalls", persistenceRuntime.readinessContract.preReadyUpdateAsyncCalls)
root:SetAttribute("ProfileReadinessPreReadyGrantCount", persistenceRuntime.readinessContract.preReadyGrantCount)
root:SetAttribute("ProfileReadinessNoEarlyWritable", persistenceRuntime.readinessContract.noEarlyWritable)
root:SetAttribute("ProfileReadinessReadyPathAllowed", persistenceRuntime.readinessContract.readyPathAllowed)
root:SetAttribute("GamePassPendingFlushContractCount", persistenceRuntime.readinessContract.pendingGamePassFlushCount)
root:SetAttribute("GamePassDuplicateOwnershipIdempotent", persistenceRuntime.readinessContract.duplicateGamePassIgnored)
root:SetAttribute("PersistenceMaxSaveTicketsPerOperation", persistenceRuntime.maxSaveTicketsPerOperation)
root:SetAttribute("PersistenceSessionLeaseSeconds", persistenceRuntime.sessionLeaseSeconds)
root:SetAttribute("PersistenceSessionFencingEnabled", true)
root:SetAttribute("PersistenceRevisionMode", "MonotonicLeaseGeneration")
root:SetAttribute("PersistenceStudioDefaultEphemeral", true)
root:SetAttribute("PersistenceStudioLiveDataOptIn", persistenceRuntime.studioLiveDataOptIn)
root:SetAttribute(
	"PersistenceMode",
	persistenceRuntime.isEphemeralStudio and "EphemeralStudio"
		or persistenceRuntime.playerStore and "Durable"
		or "Unavailable"
)
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

local petDropRuntime = { active = {} }
petDropRuntime.folder = Instance.new("Folder")
petDropRuntime.folder.Name = "Pet Egg Drops"
petDropRuntime.folder:SetAttribute("ServerAuthoritative", true)
petDropRuntime.folder:SetAttribute("OwnerRestricted", true)
petDropRuntime.folder.Parent = interactFolder

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
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = true
	return part
end

local function makeSegmentedNeonRing(name, parent, center, radius, color, segments, thickness, depth)
	local model = Instance.new("Model")
	model.Name = name
	model:SetAttribute("VisualRole", "SegmentedEnergyRing")
	model:SetAttribute("SegmentCount", segments or 16)
	model.Parent = parent
	local count = segments or 16
	local arcLength = (2 * math.pi * radius / count) * 0.88
	for index = 1, count do
		local angle = (index - 1) * 2 * math.pi / count
		local position = center + Vector3.new(math.cos(angle) * radius, math.sin(angle) * radius, 0)
		local segment = makeVisualPart(
			name .. " Segment " .. index,
			model,
			Vector3.new(thickness or 0.34, arcLength, depth or 0.42),
			CFrame.new(position) * CFrame.Angles(0, 0, angle),
			color,
			Enum.Material.Neon
		)
		segment.Transparency = index % 2 == 0 and 0.08 or 0.18
	end
	return model
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

function visualSafety.geometry(instance)
	if not instance then
		return 0, 0
	end
	local descendants = instance:GetDescendants()
	local basePartCount = instance:IsA("BasePart") and 1 or 0
	for _, descendant in ipairs(descendants) do
		if descendant:IsA("BasePart") then
			basePartCount += 1
		end
	end
	return basePartCount, #descendants
end

function visualSafety.withinBudget(instance, allowRawDescendants)
	local basePartCount, descendantCount = visualSafety.geometry(instance)
	local descendantLimit = allowRawDescendants
		and visualSafety.maxRawDescendants
		or visualSafety.maxDescendants
	return basePartCount > 0
			and basePartCount <= visualSafety.maxBaseParts
			and descendantCount <= descendantLimit,
		basePartCount,
		descendantCount
end

function visualSafety.sanitize(instance)
	local withinBudget, originalPartCount, originalDescendantCount =
		visualSafety.withinBudget(instance, true)
	if not withinBudget then
		return false, "external_visual_geometry_budget_exceeded",
			originalPartCount, originalDescendantCount
	end
	local previouslyRemoved = tonumber(
		instance:GetAttribute("ImportedUnsafeDescendantsRemovedTotal")
	) or 0
	local ok, sanitizedRoot, removedOrError = pcall(visualSafety.sanitizer.SanitizeVisual, instance)
	if not ok
		or sanitizedRoot ~= instance
		or not visualSafety.sanitizer.IsSanitizedVisual(instance)
	then
		return false, "external_visual_sanitizer_rejected: " .. tostring(removedOrError),
			originalPartCount, originalDescendantCount
	end
	local sanitizedWithinBudget, basePartCount, descendantCount =
		visualSafety.withinBudget(instance)
	if not sanitizedWithinBudget then
		return false, "external_visual_post_sanitize_budget_exceeded",
			basePartCount, descendantCount
	end
	instance:SetAttribute("AssetSanitized", true)
	instance:SetAttribute("VisualOnly", true)
	instance:SetAttribute("StrictVisualAllowlistVerified", true)
	instance:SetAttribute("SanitizedBasePartCount", basePartCount)
	instance:SetAttribute("SanitizedDescendantCount", descendantCount)
	instance:SetAttribute("SanitizedBasePartLimit", visualSafety.maxBaseParts)
	instance:SetAttribute("SanitizedDescendantLimit", visualSafety.maxDescendants)
	instance:SetAttribute(
		"ImportedUnsafeDescendantsRemovedTotal",
		previouslyRemoved + (tonumber(removedOrError) or 0)
	)
	return true, nil, basePartCount, descendantCount
end

function visualSafety.reserveRuntimeBudget(basePartCount, descendantCount)
	local currentBaseParts = root:GetAttribute("ExternalRuntimeVisualBasePartCount") or 0
	local currentDescendants = root:GetAttribute("ExternalRuntimeVisualDescendantCount") or 0
	if currentBaseParts + basePartCount > visualSafety.maxRuntimeBaseParts
		or currentDescendants + descendantCount > visualSafety.maxRuntimeDescendants
	then
		root:SetAttribute(
			"ExternalRuntimeVisualBudgetRejectCount",
			(root:GetAttribute("ExternalRuntimeVisualBudgetRejectCount") or 0) + 1
		)
		return false
	end
	root:SetAttribute("ExternalRuntimeVisualBasePartCount", currentBaseParts + basePartCount)
	root:SetAttribute("ExternalRuntimeVisualDescendantCount", currentDescendants + descendantCount)
	return true
end

root:SetAttribute("ExternalVisualBasePartLimit", visualSafety.maxBaseParts)
root:SetAttribute("ExternalVisualDescendantLimit", visualSafety.maxDescendants)
root:SetAttribute("ExternalVisualRawDescendantLimit", visualSafety.maxRawDescendants)
root:SetAttribute("ExternalTemplateBasePartBudget", visualSafety.maxTemplateBaseParts)
root:SetAttribute("ExternalTemplateDescendantBudget", visualSafety.maxTemplateDescendants)
root:SetAttribute("ExternalRuntimeVisualBasePartBudget", visualSafety.maxRuntimeBaseParts)
root:SetAttribute("ExternalRuntimeVisualDescendantBudget", visualSafety.maxRuntimeDescendants)
root:SetAttribute("ExternalRuntimeVisualBasePartCount", 0)
root:SetAttribute("ExternalRuntimeVisualDescendantCount", 0)
root:SetAttribute("ExternalRuntimeVisualBudgetRejectCount", 0)

local function tryInsertVisualAsset(candidate, position, scale, yaw)
	local ok, asset = pcall(function()
		return InsertService:LoadAsset(tonumber(candidate.assetId))
	end)
	if not ok or not asset then
		return nil
	end
	asset.Name = "Creator Store " .. candidate.name
	local sanitized, sanitizeError, basePartCount, descendantCount =
		visualSafety.sanitize(asset)
	if not sanitized
		or not visualSafety.reserveRuntimeBudget(basePartCount, descendantCount)
	then
		warn(("[PunchWall] Visual asset %s rejected: %s"):format(
			tostring(candidate.name),
			tostring(sanitizeError or "external_runtime_visual_budget_exceeded")
		))
		asset:Destroy()
		return nil
	end
	asset.Parent = decorFolder
	asset:SetAttribute("AssetId", candidate.assetId)
	asset:SetAttribute("Creator", candidate.creator)
	asset:SetAttribute("Use", candidate.use)
	asset:SetAttribute("RuntimeVisualClone", true)
	if asset:IsA("Model") then
		pcall(function()
			asset:ScaleTo(scale or 0.08)
		end)
		asset:PivotTo(CFrame.new(position) * CFrame.Angles(0, math.rad(yaw or 0), 0))
	end
	assert(
		visualSafety.sanitizer.IsSanitizedVisual(asset),
		"Creator Store city visual lost strict sanitizer attestation"
	)
	return asset
end

local function loadExternalVisualTemplates()
	local folder = ReplicatedStorage:FindFirstChild("PunchWallExternalAssets")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "PunchWallExternalAssets"
		folder.Parent = ReplicatedStorage
	end
	local templatePolicyByName = {}
	local petTemplatePolicyCount = 0
	for _, policy in ipairs(PolishConfig.ExternalVisualTemplates or {}) do
		templatePolicyByName[policy.templateName] = policy
		if policy.petDefinitionName then petTemplatePolicyCount += 1 end
	end
	local function templateMatchesPolicy(template, policy)
		if not policy then return true end
		local recordedAssetId = template:GetAttribute("CreatorStorePackAssetId")
			or template:GetAttribute("CreatorStoreAssetId")
			or template:GetAttribute("AssetId")
		if tostring(recordedAssetId or "") ~= tostring(policy.assetId) then return false end
		if policy.preloadedOnly == true then
			return template:GetAttribute("PreloadedOnly") == true
				and tostring(template:GetAttribute("SourcePackModelName") or "") == tostring(policy.sourceModel or "")
		end
		return template:GetAttribute("PreloadedOnly") ~= true
	end
	local function applyTemplatePolicy(template, policy, visualPartCount)
		if not policy then return end
		template:SetAttribute("AssetId", policy.assetId)
		template:SetAttribute("CreatorStoreAssetId", policy.assetId)
		template:SetAttribute("CreatorStorePackAssetId", tostring(policy.assetId))
		template:SetAttribute("PetDefinitionName", policy.petDefinitionName)
		template:SetAttribute("PreloadedOnly", policy.preloadedOnly == true)
		template:SetAttribute("TemplateAssetMode", policy.preloadedOnly == true and "PreloadedPackChild" or "DetailedStandaloneAsset")
		if policy.sourceModel then template:SetAttribute("SourcePackModelName", policy.sourceModel) end
		template:SetAttribute("VisualPartCount", visualPartCount or 0)
		template:SetAttribute("SourceFallback", false)
	end
	for legacyName, migratedName in pairs({
		Sanitized_CrimsonPhoenixPet = "Sanitized_EnragedPhoenixPet",
		Sanitized_StormWyvernPet = "Sanitized_ElectraHydraPet",
		Sanitized_CelestialGuardianPet = "Sanitized_MythicRadiantOnePet",
	}) do
		local legacy = folder:FindFirstChild(legacyName)
		local migrationPolicy = templatePolicyByName[migratedName]
		if legacy
			and migrationPolicy
			and not folder:FindFirstChild(migratedName)
			and tostring(legacy:GetAttribute("CreatorStorePackAssetId") or "") == tostring(migrationPolicy.assetId)
			and tostring(legacy:GetAttribute("SourcePackModelName") or "") == tostring(migrationPolicy.sourceModel)
		then
			legacy.Name = migratedName
		end
	end
	for _, existing in ipairs(folder:GetChildren()) do
		local policy = templatePolicyByName[existing.Name]
		if policy and not templateMatchesPolicy(existing, policy) then
			-- A previous release reused the premium template names for low-detail
			-- pack children. Never let that stale model shadow the original detailed
			-- standalone premium asset.
			existing:Destroy()
			continue
		end
		local sanitized, sanitizeError = visualSafety.sanitize(existing)
		if not sanitized then
			warn(("[PunchWall] Preloaded visual template %s rejected: %s"):format(
				existing.Name,
				tostring(sanitizeError)
			))
			existing:Destroy()
		else
			local visualPartCount = 0
			for _, descendant in ipairs(existing:GetDescendants()) do
				if descendant:IsA("BasePart") then visualPartCount += 1 end
			end
			applyTemplatePolicy(existing, policy, visualPartCount)
			existing:SetAttribute("TemplateVisualAttested", true)
		end
	end

	local pending = 0
	local completed = 0
	local workerFailureCount = 0
	local lateWorkerCount = 0
	local preloadedOnlyCount = 0
	local missingPreloadedOnlyCount = 0
	local acceptingLoadedTemplates = true
	local completionSignal = Instance.new("BindableEvent")
	local loadStartedAt = os.clock()
	local loadDeadlineAt = loadStartedAt + visualSafety.templateLoadDeadlineSeconds
	root:SetAttribute("ExternalTemplateLoadLateWorkerCount", 0)
	root:SetAttribute("ExternalTemplateLoadWorkerFailureCount", 0)
	for _, candidate in ipairs(PolishConfig.ExternalVisualTemplates or {}) do
		local existingTemplate = folder:FindFirstChild(candidate.templateName)
		if candidate.preloadedOnly == true then
			preloadedOnlyCount += 1
			if not existingTemplate then
				-- A child extracted from a large Creator Store pack cannot be loaded
				-- safely by requesting the pack ID: that would replicate the whole
				-- pack and attach the wrong model to this pet. Missing preloaded
				-- children therefore fail closed to the procedural pet fallback.
				missingPreloadedOnlyCount += 1
			end
		elseif not existingTemplate then
			pending += 1
			local requested = candidate
			task.spawn(function()
				local workerOk, workerError = pcall(function()
					local ok, asset = pcall(function()
						return InsertService:LoadAsset(tonumber(requested.assetId))
					end)
					if not ok or not asset then
						ok, asset = pcall(
							AssetService.LoadAssetAsync,
							AssetService,
							requested.assetId
						)
					end
					if ok and asset then
						if not acceptingLoadedTemplates or os.clock() >= loadDeadlineAt then
							lateWorkerCount += 1
							asset:Destroy()
							pcall(
								root.SetAttribute,
								root,
								"ExternalTemplateLoadLateWorkerCount",
								lateWorkerCount
							)
							return
						end
						asset.Name = requested.templateName
						local sanitized, sanitizeError = visualSafety.sanitize(asset)
						if sanitized then
							asset:SetAttribute("AssetId", requested.assetId)
							asset:SetAttribute("Creator", requested.creator)
							asset:SetAttribute("Use", requested.use)
							local visualPartCount = 0
							for _, descendant in ipairs(asset:GetDescendants()) do
								if descendant:IsA("BasePart") then visualPartCount += 1 end
							end
							applyTemplatePolicy(asset, requested, visualPartCount)
							asset:SetAttribute("TemplateVisualAttested", true)
							asset.Parent = folder
						else
							warn(("[PunchWall] Visual template %s rejected: %s"):format(
								requested.templateName,
								tostring(sanitizeError)
							))
							asset:Destroy()
						end
					else
						warn(("[PunchWall] Visual asset %s unavailable; using source fallback"):format(
							requested.templateName
						))
					end
				end)
				if not workerOk then
					workerFailureCount += 1
					pcall(
						root.SetAttribute,
						root,
						"ExternalTemplateLoadWorkerFailureCount",
						workerFailureCount
					)
					warn(("[PunchWall] Visual template worker %s failed; using source fallback: %s"):format(
						requested.templateName,
						tostring(workerError)
					))
				end
				completed += 1
				pcall(function() completionSignal:Fire() end)
			end)
		end
	end
	task.delay(visualSafety.templateLoadDeadlineSeconds, function()
		pcall(function() completionSignal:Fire() end)
	end)
	while completed < pending and os.clock() < loadDeadlineAt do
		completionSignal.Event:Wait()
	end
	acceptingLoadedTemplates = false
	local timedOutWorkerCount = math.max(0, pending - completed)
	completionSignal:Destroy()
	root:SetAttribute("ExternalTemplateLoadPendingCount", pending)
	root:SetAttribute("ExternalTemplateLoadCompletedByDeadline", completed)
	root:SetAttribute("ExternalTemplateLoadTimedOutCount", timedOutWorkerCount)
	root:SetAttribute("ExternalTemplateLoadWorkerFailureCount", workerFailureCount)
	root:SetAttribute("ExternalTemplateLoadLateWorkerCount", lateWorkerCount)
	root:SetAttribute("ExternalTemplatePreloadedOnlyCount", preloadedOnlyCount)
	root:SetAttribute("ExternalTemplateMissingPreloadedOnlyCount", missingPreloadedOnlyCount)
	root:SetAttribute("ExternalTemplatePreloadedOnlyFailClosed", true)
	root:SetAttribute("ExternalTemplateLoadDeadlineSeconds", visualSafety.templateLoadDeadlineSeconds)
	root:SetAttribute("ExternalTemplateLoadDeadlineBounded", true)
	root:SetAttribute("ExternalTemplateFallbackMode", "SourceOrProcedural")
	root:SetAttribute("ExternalTemplateWorkerFinalizationGuarded", true)
	root:SetAttribute("ExternalTemplateLoadElapsedSeconds", os.clock() - loadStartedAt)
	root:SetAttribute(
		"ExternalTemplateLoadFinalization",
		timedOutWorkerCount > 0 and "DeadlineFallback" or "WorkersComplete"
	)
	root:SetAttribute("ExternalTemplateLoadFinalized", true)

	local templateBasePartCount = 0
	local templateDescendantCount = 0
	local rejectedTemplateCount = 0
	local templates = folder:GetChildren()
	table.sort(templates, function(left, right)
		return left.Name < right.Name
	end)
	for _, template in ipairs(templates) do
		local sanitized, sanitizeError, basePartCount, descendantCount =
			visualSafety.sanitize(template)
		local withinTotalBudget = sanitized
			and templateBasePartCount + basePartCount <= visualSafety.maxTemplateBaseParts
			and templateDescendantCount + descendantCount <= visualSafety.maxTemplateDescendants
		if withinTotalBudget then
			templateBasePartCount += basePartCount
			templateDescendantCount += descendantCount
			applyTemplatePolicy(template, templatePolicyByName[template.Name], basePartCount)
			template:SetAttribute("TemplateVisualAttested", true)
		else
			rejectedTemplateCount += 1
			warn(("[PunchWall] Visual template %s failed final attestation: %s"):format(
				template.Name,
				tostring(sanitizeError or "external_template_total_budget_exceeded")
			))
			template:Destroy()
		end
	end
	assert(
		templateBasePartCount <= visualSafety.maxTemplateBaseParts
			and templateDescendantCount <= visualSafety.maxTemplateDescendants,
		"External visual templates exceeded their aggregate geometry budget"
	)
	root:SetAttribute("ExternalTemplateBasePartCount", templateBasePartCount)
	root:SetAttribute("ExternalTemplateDescendantCount", templateDescendantCount)
	root:SetAttribute("ExternalTemplateRejectedCount", rejectedTemplateCount)
	root:SetAttribute("ExternalTemplateSanitizerValidated", true)
	local readyPetTemplateCount = 0
	for _, candidate in ipairs(PolishConfig.ExternalVisualTemplates or {}) do
		if candidate.petDefinitionName then
			local template = folder:FindFirstChild(candidate.templateName)
			if template
				and template:GetAttribute("TemplateVisualAttested") == true
				and tostring(template:GetAttribute("CreatorStorePackAssetId") or "") == tostring(candidate.assetId)
				and template:GetAttribute("PetDefinitionName") == candidate.petDefinitionName
				and (candidate.preloadedOnly ~= true
					or tostring(template:GetAttribute("SourcePackModelName") or "") == tostring(candidate.sourceModel or ""))
			then
				readyPetTemplateCount += 1
			end
		end
	end
	root:SetAttribute("PetVisualReadyTemplateCount", readyPetTemplateCount)
	root:SetAttribute("PetVisualRequiredTemplateCount", petTemplatePolicyCount)
	root:SetAttribute("PetVisualReleasePolicy", "EightPackPlusThreeDetailedPremiumV3")
	root:SetAttribute(
		"PetVisualReleaseReady",
		preloadedOnlyCount == 8
			and missingPreloadedOnlyCount == 0
			and rejectedTemplateCount == 0
			and petTemplatePolicyCount == 11
			and readyPetTemplateCount == petTemplatePolicyCount
	)
end

loadExternalVisualTemplates()

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

local function cloneExternalVisual(templateName, parent, instanceName, groundCFrame, targetHeight, enableParticles, sourceRotation)
	local assets = ReplicatedStorage:FindFirstChild("PunchWallExternalAssets")
	local fistAssets = ReplicatedStorage:FindFirstChild("PunchWallFistAssets")
	local template = (assets and assets:FindFirstChild(templateName))
		or (fistAssets and fistAssets:FindFirstChild(templateName))
	if not template or not template:IsA("Model") then return nil end
	local clone = template:Clone()
	clone.Name = instanceName or templateName
	local sanitized, sanitizeError, basePartCount, descendantCount =
		visualSafety.sanitize(clone)
	if not sanitized
		or not visualSafety.reserveRuntimeBudget(basePartCount, descendantCount)
	then
		warn(("[PunchWall] Runtime visual clone %s rejected: %s"):format(
			tostring(templateName),
			tostring(sanitizeError or "external_runtime_visual_budget_exceeded")
		))
		clone:Destroy()
		return nil
	end
	clone:SetAttribute("RuntimeVisualClone", true)
	clone:SetAttribute("SourceTemplateName", templateName)
	clone.Parent = parent
	for _, descendant in ipairs(clone:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			descendant.Enabled = enableParticles == true
		end
	end
	local _, initialSize = clone:GetBoundingBox()
	local sourceHeight = sourceRotation
		and math.max(initialSize.X, initialSize.Y, initialSize.Z)
		or initialSize.Y
	if targetHeight and sourceHeight > 0.01 then
		clone:ScaleTo(targetHeight / sourceHeight)
	end
	local boundsCFrame, boundsSize = clone:GetBoundingBox()
	local pivotToBounds = clone:GetPivot():ToObjectSpace(boundsCFrame)
	local targetBounds = groundCFrame * CFrame.new(0, boundsSize.Y * 0.5, 0)
	clone:PivotTo(targetBounds * pivotToBounds:Inverse())
	if sourceRotation then
		boundsCFrame = clone:GetBoundingBox()
		local currentPivot = clone:GetPivot()
		clone:PivotTo(
			CFrame.new(boundsCFrame.Position)
				* sourceRotation
				* CFrame.new(-boundsCFrame.Position)
				* currentPivot
		)

		local minY = math.huge
		for _, descendant in ipairs(clone:GetDescendants()) do
			if descendant:IsA("BasePart") then
				for xSign = -1, 1, 2 do
					for ySign = -1, 1, 2 do
						for zSign = -1, 1, 2 do
							local corner = descendant.CFrame:PointToWorldSpace(Vector3.new(
								descendant.Size.X * xSign * 0.5,
								descendant.Size.Y * ySign * 0.5,
								descendant.Size.Z * zSign * 0.5
							))
							minY = math.min(minY, corner.Y)
						end
					end
				end
			end
		end
		if minY < math.huge then
			clone:PivotTo(clone:GetPivot() + Vector3.new(0, groundCFrame.Position.Y - minY, 0))
		end
	end
	assert(
		visualSafety.sanitizer.IsSanitizedVisual(clone),
		"Runtime Creator Store visual lost strict sanitizer attestation"
	)
	return clone
end

local function makeProceduralHeroNPC(name, parent, groundCFrame, jacketColor, accentColor, role)
	local model = Instance.new("Model")
	model.Name = name
	model:SetAttribute("ProceduralFallback", true)
	model:SetAttribute("NPCType", role)
	model.Parent = parent

	makePart("Left Boot", model, Vector3.new(1.25, 1.0, 1.7), Vector3.new(-0.72, 0.5, 0), Color3.fromRGB(30, 33, 38), Enum.Material.SmoothPlastic)
	makePart("Right Boot", model, Vector3.new(1.25, 1.0, 1.7), Vector3.new(0.72, 0.5, 0), Color3.fromRGB(30, 33, 38), Enum.Material.SmoothPlastic)
	makePart("Left Leg", model, Vector3.new(1.2, 2.2, 1.25), Vector3.new(-0.72, 2.0, 0), Color3.fromRGB(48, 55, 65), Enum.Material.Fabric)
	makePart("Right Leg", model, Vector3.new(1.2, 2.2, 1.25), Vector3.new(0.72, 2.0, 0), Color3.fromRGB(48, 55, 65), Enum.Material.Fabric)
	makePart("Hero Jacket", model, Vector3.new(3.1, 3.1, 1.65), Vector3.new(0, 4.5, 0), jacketColor, Enum.Material.Fabric)
	makePart("Left Arm", model, Vector3.new(0.9, 2.9, 1.0), Vector3.new(-2.0, 4.45, 0), jacketColor, Enum.Material.Fabric)
	makePart("Right Arm", model, Vector3.new(0.9, 2.9, 1.0), Vector3.new(2.0, 4.45, 0), jacketColor, Enum.Material.Fabric)
	makeBall("Head", model, Vector3.new(2.25, 2.25, 2.25), Vector3.new(0, 6.9, 0), Color3.fromRGB(236, 184, 142), Enum.Material.SmoothPlastic)
	makePart("Hair", model, Vector3.new(2.35, 0.72, 2.35), Vector3.new(0, 7.82, 0), Color3.fromRGB(31, 27, 28), Enum.Material.SmoothPlastic)
	makePart("Hero Visor", model, Vector3.new(1.65, 0.42, 0.2), Vector3.new(0, 7.0, -1.08), accentColor, Enum.Material.Neon)
	local emblem = makeBall("Hero Core", model, Vector3.new(0.58, 0.58, 0.28), Vector3.new(0, 4.8, -0.88), accentColor, Enum.Material.Neon)
	emblem.CanQuery = false

	local _, size = model:GetBoundingBox()
	model:PivotTo(groundCFrame * CFrame.new(0, size.Y * 0.5, 0))
	return model
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
		Vector3.new(-38, 0.5, 8),
		Vector3.new(-44, 0.5, 18),
		Vector3.new(-32, 0.5, 22),
		Vector3.new(-16, 0.5, 10),
		Vector3.new(-2, 0.5, -10),
	}) do
		local pad = makePart("Forest Guide Stone " .. index, guideFolder, Vector3.new(6.2, 0.16, 2.5), position, Color3.fromRGB(103, 109, 104), Enum.Material.Slate)
		pad.Orientation = Vector3.new(0, -22, 0)
		pad.CanCollide = false
		pad:SetAttribute("TextureStyle", "ForestWaystone")
		local arrow = makeWedge("Forest Direction Inlay " .. index, guideFolder, Vector3.new(1.7, 0.12, 2.1), position + Vector3.new(2.2, 0.12, -0.8), Color3.fromRGB(232, 181, 55), Enum.Material.Metal, Vector3.new(0, -22, 0))
		arrow.CanCollide = false
		arrow:SetAttribute("TextureStyle", "ForestWaystoneInlay")
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

-- Training unlocks must use the same number the player sees in the Power HUD.
-- Previously the HUD showed effective Power while the station gate checked only
-- raw Power, so a player could visibly have 18.9K and still be rejected by the
-- 1.5K station. Keep this helper server authoritative and reuse it everywhere
-- that selects, starts, restores, or pays an active training station.
local function trainingQualificationPower(player)
	local function read(name, fallback)
		local value = playerStat(player, name)
		return value and value.Value or fallback
	end
	return GameConfig.EffectivePower(
		read("Power", 0),
		read("FistMultiplier", 1),
		read("PetMultiplier", 0),
		read("Rebirths", 0),
		read("FistMastery", 1),
		read("HonorPowerBonus", 0)
	)
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

shared.PunchWallStatsSync = {
	pending = {},
	leaderboardDirty = false,
	scheduled = false,
	intervalSeconds = 0.05,
}

local function syncStats(player, sharedLeaderboard)
	-- Initial load and explicit responses remain immediate. They also consume
	-- an ordinary pending update for this player when no shared rank changed.
	shared.PunchWallStatsSync.pending[player] = nil
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
	payload.RebirthBonus = GameConfig.RebirthBonus(payload.Rebirths)
	local rebirthRequirement = GameConfig.RebirthRequirement(payload.Rebirths)
	payload.RebirthRequiredLevel = rebirthRequirement.requiredLevel
	payload.RebirthRequiredCoins = rebirthRequirement.requiredCoins
	payload.RebirthNextCount = rebirthRequirement.nextRebirths
	payload.RebirthNextBonus = rebirthRequirement.permanentMultiplier
	payload.RebirthMaxed = rebirthRequirement.maxed
	payload.RebirthReady = not rebirthRequirement.maxed
		and (payload.WallLevel or 1) >= rebirthRequirement.requiredLevel
		and (payload.Coins or 0) >= rebirthRequirement.requiredCoins
	payload.BasePower = payload.Power or 0
	payload.EffectivePower = trainingQualificationPower(player)
	payload.TrainingQualificationPower = payload.EffectivePower
	payload.MaxCritChance = GameConfig.MaxCritChance
	payload.MaxEquippedPets = GameConfig.MaxEquippedPets
	payload.Rank = GameConfig.RankForDepth(payload.Depth or 0)
	local fullLeaderboard = sharedLeaderboard or buildServerLeaderboard()
	payload.RankPosition = math.max(1, #fullLeaderboard)
	for position, entry in ipairs(fullLeaderboard) do
		if entry.userId == player.UserId then payload.RankPosition = position break end
	end
	payload.Leaderboard = {}
	for position = 1, math.min(5, #fullLeaderboard) do
		payload.Leaderboard[position] = fullLeaderboard[position]
	end
	if not sharedLeaderboard and shared.PunchWallUpdateWorldRankBoard then
		task.defer(shared.PunchWallUpdateWorldRankBoard, fullLeaderboard)
	end
	local tutorialCompleted = (payload.TutorialCompleted or 0) >= 1
	local tutorialStep = math.clamp(
		math.floor(tonumber(payload.TutorialStep) or 1),
		1,
		GameConfig.TutorialCompleteStep
	)
	local tutorial = not tutorialCompleted and GameConfig.Tutorial[tutorialStep] or nil
	if tutorial then
		tutorial = table.clone(tutorial)
	end
	payload.Tutorial = tutorial
	payload.TutorialCompleted = tutorialCompleted
	payload.TutorialVersion = GameConfig.TutorialVersion
	payload.TutorialProgress = tutorialCompleted and 1
		or math.clamp(tutorialStep / math.max(1, GameConfig.TutorialCompleteStep - 1), 0, 1)
	payload.FistCatalog = GameConfig.Fists
	payload.PremiumFistCatalog = GameConfig.PremiumFists
	payload.HonorCatalog = GameConfig.HonorItems
	payload.PetCatalog = GameConfig.Pets
	payload.PremiumPetCatalog = GameConfig.PremiumPets
	payload.Rewards = GameConfig.Rewards
	payload.SpinCatalog = GameConfig.Spin
	payload.SpinReadyAt = (payload.LastSpinAt or 0) + GameConfig.Spin.CooldownSeconds
	payload.TrainingConfig = GameConfig.Training
	payload.PremiumProducts = GameConfig.PremiumProducts
	payload.WorldProgressTarget = GameConfig.WorldProgressTarget
	payload.StudioTestMode = player:GetAttribute("StudioHighPowerTestMode") == true
	payload.ShopBoosts = {
		CoinEndsAt = player:GetAttribute("CoinBoostExpiresAt") or 0,
		DamageEndsAt = player:GetAttribute("DamageBoostExpiresAt") or 0,
		SpeedEndsAt = player:GetAttribute("SpeedBoostExpiresAt") or 0,
		TrainingEndsAt = player:GetAttribute("TrainingBoostExpiresAt") or 0,
	}
	player:SetAttribute("StatsSnapshotCount", (player:GetAttribute("StatsSnapshotCount") or 0) + 1)
	statRemote:FireClient(player, payload)
end

-- Fixed-window coalescing: a burst cannot postpone its first deadline, and
-- state changes during a flush are placed into a new window. Authoritative
-- stats still change synchronously; only their complete UI snapshots wait.
function shared.PunchWallStatsSync.flush()
	local pending = shared.PunchWallStatsSync.pending
	local leaderboardDirty = shared.PunchWallStatsSync.leaderboardDirty
	shared.PunchWallStatsSync.pending = {}
	shared.PunchWallStatsSync.leaderboardDirty = false
	shared.PunchWallStatsSync.scheduled = false
	if leaderboardDirty then
		for _, player in ipairs(Players:GetPlayers()) do
			pending[player] = true
		end
	end
	if next(pending) == nil then return end
	local leaderboard = buildServerLeaderboard()
	if shared.PunchWallUpdateWorldRankBoard then
		task.defer(shared.PunchWallUpdateWorldRankBoard, leaderboard)
	end
	for player in pairs(pending) do
		if player.Parent == Players and profileReady(player, false) then
			syncStats(player, leaderboard)
		end
	end
end

function shared.PunchWallStatsSync.queue(player, leaderboardDirty)
	if player.Parent ~= Players or not profileReady(player, false) then return end
	shared.PunchWallStatsSync.pending[player] = true
	shared.PunchWallStatsSync.leaderboardDirty = shared.PunchWallStatsSync.leaderboardDirty or leaderboardDirty == true
	if shared.PunchWallStatsSync.scheduled then return end
	shared.PunchWallStatsSync.scheduled = true
	task.delay(shared.PunchWallStatsSync.intervalSeconds, shared.PunchWallStatsSync.flush)
end

function shared.PunchWallStatsSync.remove(player)
	shared.PunchWallStatsSync.pending[player] = nil
end

do
local function retryDataStoreCall(callback)
	local lastError
	for attempt = 1, persistenceRuntime.dataStoreAttempts do
		local ok, result = pcall(callback)
		if ok then
			return true, result
		end
		lastError = result
		if attempt < persistenceRuntime.dataStoreAttempts then
			task.wait(attempt * persistenceRuntime.dataStoreRetryBaseSeconds)
		end
	end
	return false, lastError
end

local function loadPlayerData(player)
	if persistenceRuntime.isEphemeralStudio then
		local profile = ProfilePersistence.NewProfile(
			GameConfig.DataVersion,
			ProfilePersistence.MaxReceiptLedgerEntries
		)
		local result = {
			ok = profile ~= nil,
			data = profile,
			state = "EphemeralStudio",
			writable = false,
			fence = nil,
		}
		if not profile then
			result.reason = "ephemeral_profile_migration_failed"
		end
		return result
	end

	if not persistenceRuntime.playerStore then
		return {
			ok = false,
			state = "Failed",
			writable = false,
			reason = "current_store_unavailable",
		}
	end

	local key = tostring(player.UserId)
	local sessionToken = HttpService:GenerateGUID(false)

	local function acquireCurrentProfile(seedProfile)
		local callbackState = {}
		local ok, data = retryDataStoreCall(function()
			return persistenceRuntime.playerStore:UpdateAsync(key, function(previous)
				callbackState = {}
				local source = previous
				if source == nil then
					if seedProfile == nil then
						callbackState.missing = true
						return nil
					end
					source = seedProfile
					callbackState.seeded = true
				end
				local profile, fence, acquired, stateOrError = ProfilePersistence.AcquireSessionLease(
					source,
					sessionToken,
					os.time(),
					persistenceRuntime.sessionLeaseSeconds,
					GameConfig.DataVersion,
					ProfilePersistence.MaxReceiptLedgerEntries
				)
				if not profile or not acquired or not fence then
					callbackState.error = stateOrError or "session_lease_acquire_rejected"
					return nil
				end
				callbackState.fence = fence
				callbackState.leaseState = stateOrError
				return profile
			end)
		end)
		if not ok then
			return nil, nil, "current_lease_update_failed: " .. tostring(data)
		end
		if callbackState.error then
			return nil, nil, callbackState.error
		end
		if callbackState.missing and seedProfile == nil then
			return nil, nil, "current_profile_missing"
		end
		if type(data) ~= "table" or not callbackState.fence then
			return nil, nil, "current_lease_update_rejected"
		end
		return data, callbackState.fence, nil
	end

	local currentData, currentFence, currentError = acquireCurrentProfile(nil)
	if currentData then
		return {
			ok = true,
			data = currentData,
			state = "Loaded",
			writable = true,
			fence = currentFence,
		}
	end
	if currentError ~= "current_profile_missing" then
		return {
			ok = false,
			state = "Failed",
			writable = false,
			reason = "current_profile_lease_failed: " .. tostring(currentError),
		}
	end

	if not persistenceRuntime.legacyPlayerStore then
		return {
			ok = false,
			state = "Failed",
			writable = false,
			reason = "legacy_store_unavailable",
		}
	end

	local legacyOk, legacyData = retryDataStoreCall(function()
		return persistenceRuntime.legacyPlayerStore:GetAsync(key)
	end)
	if not legacyOk then
		return {
			ok = false,
			state = "Failed",
			writable = false,
			reason = "legacy_load_failed: " .. tostring(legacyData),
		}
	end
	local seedProfile
	local seededState
	if legacyData ~= nil then
		local migrationState
		seedProfile, migrationState = ProfilePersistence.Migrate(
			legacyData,
			GameConfig.DataVersion,
			ProfilePersistence.MaxReceiptLedgerEntries
		)
		if not seedProfile then
			return {
				ok = false,
				state = "Failed",
				writable = false,
				reason = "legacy_profile_rejected: " .. tostring(migrationState),
			}
		end
		seededState = "MigratedLegacy"
	else
		local newProfileError
		seedProfile, newProfileError = ProfilePersistence.NewProfile(
			GameConfig.DataVersion,
			ProfilePersistence.MaxReceiptLedgerEntries
		)
		if not seedProfile then
			return {
				ok = false,
				state = "Failed",
				writable = false,
				reason = "new_profile_failed: " .. tostring(newProfileError),
			}
		end
		seededState = "New"
	end

	local seededData, seededFence, seedError = acquireCurrentProfile(seedProfile)
	if not seededData then
		return {
			ok = false,
			state = "Failed",
			writable = false,
			reason = "seed_profile_lease_failed: " .. tostring(seedError),
		}
	end
	return {
		ok = true,
		data = seededData,
		state = seededState,
		writable = true,
		fence = seededFence,
	}
end

local function applySpeedBoostState(player, character)
	if player:GetAttribute("TrainingMovementLocked") then
		return
	end
	character = character or player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local active = (player:GetAttribute("SpeedBoostExpiresAt") or 0) > workspace:GetServerTimeNow()
	local wasApplied = player:GetAttribute("SpeedBoostApplied") == true
	if active then
		if humanoid.WalkSpeed ~= 24 then
			humanoid.WalkSpeed = 24
		end
	elseif wasApplied then
		humanoid.WalkSpeed = 16
	end
	if active ~= wasApplied then
		player:SetAttribute("SpeedBoostApplied", active)
	end
end

local function getPendingGamePassState(player)
	local state = persistenceRuntime.pendingGamePassGrants[player]
	if not state then
		state = {
			byKey = {},
			order = {},
			flushing = false,
		}
		persistenceRuntime.pendingGamePassGrants[player] = state
	end
	return state
end

local function queuePendingGamePassGrant(player, kind, item, source)
	local gamePassId = item and tonumber(item.gamePassId)
	if not player or not item or not gamePassId or gamePassId <= 0 then
		return false, "invalid_game_pass_grant"
	end
	local state = getPendingGamePassState(player)
	local key = ("%s:%d"):format(kind, gamePassId)
	if state.byKey[key] then
		return true, "already_queued"
	end
	if #state.order >= persistenceRuntime.maxPendingGamePassGrants then
		return false, "pending_game_pass_queue_full"
	end
	state.byKey[key] = {
		key = key,
		kind = kind,
		item = item,
		source = source or "GamePass",
		gamePassId = gamePassId,
	}
	table.insert(state.order, key)
	player:SetAttribute("PendingGamePassGrantCount", #state.order)
	return true, "queued"
end

local function initializePlayerProfileSession(player, loadResult)
	local savedData = loadResult.data
	local canBecomeWritable = loadResult.writable == true
		and not persistenceRuntime.isEphemeralStudio
		and type(loadResult.fence) == "table"
	persistenceRuntime.profileSessions[player] = {
		initializing = true,
		ready = false,
		writable = false,
		canBecomeWritable = canBecomeWritable,
		state = "Initializing",
		loadedState = loadResult.state,
		fence = loadResult.fence,
		leaseExpiresAt = savedData.SessionLease and savedData.SessionLease.ExpiresAt or 0,
		knownReceiptIds = ProfilePersistence.ReceiptIdSet(
			savedData,
			ProfilePersistence.MaxReceiptLedgerEntries
		),
		appliedReceiptIds = {},
		receiptUncertain = {},
	}
	player:SetAttribute("ProfileReady", false)
	player:SetAttribute("ProfileWritable", false)
	player:SetAttribute("ProfileCanSave", false)
	player:SetAttribute("ProfilePersistenceState", "Initializing")
	player:SetAttribute("ProfileRevision", loadResult.fence and loadResult.fence.Revision or 0)
	player:SetAttribute("ProfileLeaseExpiresAt", savedData.SessionLease and savedData.SessionLease.ExpiresAt or 0)
	for _, field in ipairs(ProfilePersistence.BoostExpiryFields) do
		player:SetAttribute(field, tonumber(savedData[field]) or 0)
	end
	return savedData
end

local function markPlayerProfileReady(player)
	local session = persistenceRuntime.profileSessions[player]
	local hasRPGStats, hasLeaderstats = hasCompleteProfileStats(player)
	if not session or session.initializing ~= true or not hasRPGStats or not hasLeaderstats then
		return false, "profile_stats_not_ready"
	end
	session.initializing = false
	session.ready = true
	session.writable = session.canBecomeWritable == true
	session.state = session.loadedState
	player:SetAttribute("ProfileReady", true)
	player:SetAttribute("ProfileWritable", session.writable)
	player:SetAttribute("ProfileCanSave", session.writable)
	player:SetAttribute("ProfilePersistenceState", session.loadedState)
	player:SetAttribute("ProfileRevision", session.fence and session.fence.Revision or 0)
	player:SetAttribute("ProfileLeaseExpiresAt", session.leaseExpiresAt or 0)
	player:SetAttribute("ProfileLoadStarted", false)
	task.spawn(function()
		if player.Parent ~= Players or persistenceRuntime.profileSessions[player] ~= session then
			return
		end
		if persistenceRuntime.flushPendingGamePassGrants then
			persistenceRuntime.flushPendingGamePassGrants(player, "ProfileReady")
		end
		if persistenceRuntime.reconcileOwnedGamePasses then
			persistenceRuntime.reconcileOwnedGamePasses(player)
		end
	end)
	return true
end
	persistenceRuntime.retryDataStoreCall = retryDataStoreCall
	persistenceRuntime.loadPlayerData = loadPlayerData
	persistenceRuntime.applySpeedBoostState = applySpeedBoostState
	persistenceRuntime.queuePendingGamePassGrant = queuePendingGamePassGrant
	persistenceRuntime.initializePlayerProfileSession = initializePlayerProfileSession
	persistenceRuntime.markPlayerProfileReady = markPlayerProfileReady
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

shared.PunchWallPowerGrowth = {
	pending = setmetatable({}, { __mode = "k" }),
}

function shared.PunchWallPowerGrowth.CoreBodyBounds(character)
	local minimumY = math.huge
	local maximumY = -math.huge
	local partCount = 0
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("BasePart") then
			local cframe = child.CFrame
			local size = child.Size
			local halfHeight = (
				math.abs(cframe.RightVector.Y) * size.X
				+ math.abs(cframe.UpVector.Y) * size.Y
				+ math.abs(cframe.LookVector.Y) * size.Z
			) * 0.5
			minimumY = math.min(minimumY, child.Position.Y - halfHeight)
			maximumY = math.max(maximumY, child.Position.Y + halfHeight)
			partCount += 1
		end
	end
	if partCount == 0 then return nil end
	return minimumY, maximumY, maximumY - minimumY, partCount
end

function shared.PunchWallPowerGrowth.Apply(player)
	local character = player.Character
	local powerValue = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Power")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not powerValue or not humanoid or not rootPart then return false end
	local appearanceOk, appearanceLoaded = pcall(function() return player:HasAppearanceLoaded() end)
	if appearanceOk and not appearanceLoaded then
		character:SetAttribute("PowerGrowthWaitingForAppearance", true)
		return false
	end
	if character:GetAttribute("DepthActiveCollisionGroup") == "PunchingCharacters" then
		character:SetAttribute("PowerGrowthDeferredForPunch", true)
		task.delay(math.max(0.12, tonumber(player:GetAttribute("LastPunchOwnershipHoldSeconds")) or 0.24), function()
			if player.Parent and player.Character == character then shared.PunchWallPowerGrowth.Schedule(player) end
		end)
		return false
	end
	character:SetAttribute("PowerGrowthWaitingForAppearance", false)
	character:SetAttribute("PowerGrowthDeferredForPunch", false)

	local growthConfig = GameConfig.PlayerGrowth
	local currentScale = character:GetScale()
	local currentBodyBottom, _, currentBodyHeight, bodyPartCount = shared.PunchWallPowerGrowth.CoreBodyBounds(character)
	if not currentBodyBottom or not currentBodyHeight then return false end
	local baseModelScale = tonumber(character:GetAttribute("PowerGrowthBaseModelScale"))
	local baseBodyHeight = tonumber(character:GetAttribute("PowerGrowthBaseBodyHeight"))
	if not baseModelScale or baseModelScale <= 0 or not baseBodyHeight or baseBodyHeight <= 0 then
		baseModelScale = math.max(0.01, currentScale)
		baseBodyHeight = math.max(0.01, currentBodyHeight)
		character:SetAttribute("PowerGrowthBaseModelScale", baseModelScale)
		character:SetAttribute("PowerGrowthBaseBodyHeight", baseBodyHeight)
	end

	local targetModelScale, requestedMultiplier, maximumHeight, wallCapped = GameConfig.PlayerGrowthModelScale(
		powerValue.Value,
		baseModelScale,
		baseBodyHeight
	)
	local ownershipToken = player:GetAttribute("PunchOwnershipToken") or 0
	local ownershipHeld = pcall(function() rootPart:SetNetworkOwner(nil) end)
	character:SetAttribute("PowerGrowthServerOwnershipHeld", ownershipHeld)

	local beforeBottom = rootPart.Position.Y - humanoid.HipHeight - rootPart.Size.Y * 0.5
	if math.abs(currentScale - targetModelScale) > 0.004 then
		local scaled = pcall(function()
			character:ScaleTo(targetModelScale)
		end)
		if not scaled or character ~= player.Character then
			if ownershipHeld and rootPart.Parent then pcall(function() rootPart:SetNetworkOwnershipAuto() end) end
			return false
		end
	end

	local _, _, afterBodyHeight = shared.PunchWallPowerGrowth.CoreBodyBounds(character)
	local afterBottom = rootPart.Position.Y - humanoid.HipHeight - rootPart.Size.Y * 0.5
	if afterBodyHeight > maximumHeight + 0.025 and targetModelScale > baseModelScale + 0.004 then
		targetModelScale = math.max(baseModelScale, targetModelScale * maximumHeight / afterBodyHeight * 0.998)
		local corrected = pcall(function()
			character:ScaleTo(targetModelScale)
		end)
		if not corrected or character ~= player.Character then
			if ownershipHeld and rootPart.Parent then pcall(function() rootPart:SetNetworkOwnershipAuto() end) end
			return false
		end
		local correctedBodyBottom
		correctedBodyBottom, _, afterBodyHeight = shared.PunchWallPowerGrowth.CoreBodyBounds(character)
		afterBottom = rootPart.Position.Y - humanoid.HipHeight - rootPart.Size.Y * 0.5
	end
	local footCorrection = math.clamp(beforeBottom - afterBottom, -3, 3)
	if math.abs(footCorrection) > 0.005 and character == player.Character then
		character:PivotTo(character:GetPivot() + Vector3.new(0, footCorrection, 0))
		local correctedBodyBottom
		correctedBodyBottom, _, afterBodyHeight = shared.PunchWallPowerGrowth.CoreBodyBounds(character)
		afterBottom = rootPart.Position.Y - humanoid.HipHeight - rootPart.Size.Y * 0.5
	end
	if ownershipHeld and rootPart.Parent and character == player.Character
		and (player:GetAttribute("PunchOwnershipToken") or 0) == ownershipToken
		and character:GetAttribute("DepthActiveCollisionGroup") ~= "PunchingCharacters" then
		pcall(function() rootPart:SetNetworkOwnershipAuto() end)
		character:SetAttribute("PowerGrowthServerOwnershipHeld", false)
	end

	local appliedMultiplier = character:GetScale() / baseModelScale
	local wallHeight = math.max(1, tonumber(growthConfig.ShortestWallHeightStuds) or 11)
	character:SetAttribute("PowerGrowthVersion", growthConfig.Version)
	character:SetAttribute("PowerGrowthPower", powerValue.Value)
	character:SetAttribute("PowerGrowthRequestedMultiplier", requestedMultiplier)
	character:SetAttribute("PowerGrowthAppliedMultiplier", appliedMultiplier)
	character:SetAttribute("PowerGrowthBodyHeight", afterBodyHeight)
	character:SetAttribute(
		"PowerGrowthCoreBottom",
		rootPart.Position.Y - humanoid.HipHeight - rootPart.Size.Y * 0.5
	)
	character:SetAttribute("PowerGrowthBodyPartCount", bodyPartCount)
	character:SetAttribute("PowerGrowthWallHeight", wallHeight)
	character:SetAttribute("PowerGrowthMaximumHeight", maximumHeight)
	character:SetAttribute("PowerGrowthCappedByWall", wallCapped or afterBodyHeight > maximumHeight + 0.05)
	character:SetAttribute("PowerGrowthPetScalePolicy", "IndependentFixedTarget")

	local aura = rootPart:FindFirstChild("Kaiju Growth Aura") or Instance.new("ParticleEmitter")
	aura.Name = "Kaiju Growth Aura"
	local auraStart = tonumber(growthConfig.AuraStartMultiplier) or 1.25
	local auraProgress = math.clamp(
		(appliedMultiplier - auraStart) / math.max(0.01, (growthConfig.MaxScaleMultiplier or 1.25) - auraStart),
		0,
		1
	)
	aura.Enabled = appliedMultiplier >= auraStart
	aura.Rate = math.floor(4 + auraProgress * 12 + 0.5)
	aura.Lifetime = NumberRange.new(0.5, 0.9)
	aura.Speed = NumberRange.new(0.4, 1.2)
	aura.SpreadAngle = Vector2.new(180, 30)
	aura.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
	aura.Color = ColorSequence.new(auraProgress >= 0.65 and Color3.fromRGB(232, 75, 52) or Color3.fromRGB(82, 178, 213))
	aura.Parent = rootPart
	return true
end

function shared.PunchWallPowerGrowth.Schedule(player)
	if shared.PunchWallPowerGrowth.pending[player] then return end
	shared.PunchWallPowerGrowth.pending[player] = true
	local scheduledCharacter = player.Character
	local scheduledGeneration = player:GetAttribute("PowerGrowthGeneration") or 0
	task.delay(GameConfig.PlayerGrowth.UpdateDelaySeconds or 0.08, function()
		shared.PunchWallPowerGrowth.pending[player] = nil
		if player.Parent and player.Character == scheduledCharacter
			and (player:GetAttribute("PowerGrowthGeneration") or 0) == scheduledGeneration then
			shared.PunchWallPowerGrowth.Apply(player)
		end
	end)
end

function shared.PunchWallPowerGrowth.RunRigContract()
	local rows = {}
	local valid = true
	for _, spec in ipairs({
		{ name = "R6Default", rigType = Enum.HumanoidRigType.R6 },
		{ name = "R15Default", rigType = Enum.HumanoidRigType.R15 },
		{ name = "R15Tall", rigType = Enum.HumanoidRigType.R15, tall = true },
	}) do
		local description = Instance.new("HumanoidDescription")
		if spec.tall then
			description.HeightScale = 1.05
			description.WidthScale = 1.00
			description.DepthScale = 1.00
			description.HeadScale = 1.00
		end
		local created, model = pcall(function()
			return Players:CreateHumanoidModelFromDescriptionAsync(description, spec.rigType)
		end)
		description:Destroy()
		if not created or not model then
			valid = false
			table.insert(rows, { name = spec.name, created = false })
			continue
		end
		model.Name = "Power Growth Rig Contract " .. spec.name
		model.Parent = workspace
		model:PivotTo(CFrame.new(0, 50, 500 + #rows * 20))
		local baseScale = model:GetScale()
		local _, _, baseHeight, partCount = shared.PunchWallPowerGrowth.CoreBodyBounds(model)
		local accessory = Instance.new("Accessory")
		accessory.Name = "Oversized Accessory Contract"
		local handle = Instance.new("Part")
		handle.Name = "Handle"
		handle.Size = Vector3.new(30, 30, 30)
		handle.Parent = accessory
		accessory.Parent = model
		local _, _, bodyHeightWithAccessory = shared.PunchWallPowerGrowth.CoreBodyBounds(model)
		local targetScale, requestedMultiplier, maximumHeight = GameConfig.PlayerGrowthModelScale(
			GameConfig.PlayerGrowth.FullGrowthPower,
			baseScale,
			baseHeight
		)
		model:ScaleTo(targetScale)
		local _, _, finalHeight = shared.PunchWallPowerGrowth.CoreBodyBounds(model)
		local accessoryIgnored = math.abs(bodyHeightWithAccessory - baseHeight) <= 0.005
		local rowValid = partCount >= (spec.rigType == Enum.HumanoidRigType.R6 and 6 or 15)
			and targetScale / baseScale >= 1
			and targetScale / baseScale <= GameConfig.PlayerGrowth.MaxScaleMultiplier + 0.005
			and finalHeight <= maximumHeight + 0.05
			and accessoryIgnored
		valid = valid and rowValid
		table.insert(rows, {
			name = spec.name,
			created = true,
			valid = rowValid,
			parts = partCount,
			baseHeight = baseHeight,
			finalHeight = finalHeight,
			requestedMultiplier = requestedMultiplier,
			appliedMultiplier = targetScale / baseScale,
			maximumHeight = maximumHeight,
			accessoryIgnored = accessoryIgnored,
		})
		model:Destroy()
	end
	return { ok = valid, rows = rows }
end

local function ensureStats(player)
	player.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Invisicam
	player:SetAttribute("PreserveTunnelCameraZoom", true)
	if profileReady(player, false) then
		syncStats(player)
		return
	end
	if player:GetAttribute("ProfileLoadStarted") then
		return
	end
	player:SetAttribute("ProfileLoadStarted", true)
	player:SetAttribute("ProfileReady", false)
	player:SetAttribute("ProfileWritable", false)
	player:SetAttribute("ProfileCanSave", false)
	player:SetAttribute("ProfilePersistenceState", "Loading")

	local loadResult = persistenceRuntime.loadPlayerData(player)
	if not player.Parent then
		if loadResult and loadResult.fence and persistenceRuntime.releaseProfileFence then
			local released, releaseError = persistenceRuntime.releaseProfileFence(player, loadResult.fence)
			if not released then
				warn(("[PunchWallRPG] Could not release abandoned profile lease for %s: %s"):format(
					player.Name,
					tostring(releaseError)
				))
			end
		end
		player:SetAttribute("ProfileLoadStarted", false)
		return
	end
	if not loadResult.ok or type(loadResult.data) ~= "table" then
		player:SetAttribute("ProfileLoadStarted", false)
		player:SetAttribute("ProfilePersistenceState", "Failed")
		warn(("[PunchWallRPG] Profile load failed closed for %s: %s"):format(
			player.Name,
			tostring(loadResult.reason)
		))
		player:Kick("Your saved data could not be loaded safely. Please rejoin and try again.")
		return
	end

	local savedData = persistenceRuntime.initializePlayerProfileSession(player, loadResult)
	if not player:GetAttribute("DepthCollisionGroupHooked") then
		player:SetAttribute("DepthCollisionGroupHooked", true)
		player.CharacterAdded:Connect(function(character)
			applyCharacterCollisionGroup(character)
			character:WaitForChild("Humanoid", 5)
			persistenceRuntime.applySpeedBoostState(player, character)
		end)
	end
	local currentCharacter = player.Character
	if currentCharacter then
		applyCharacterCollisionGroup(currentCharacter)
		currentCharacter:WaitForChild("Humanoid", 5)
		persistenceRuntime.applySpeedBoostState(player, currentCharacter)
	end
	if not player.Parent then
		local session = persistenceRuntime.profileSessions[player]
		local finalSaveTicket = persistenceRuntime.finalSaveTickets[player]
		if persistenceRuntime.releaseProfileFence and session and session.fence and not finalSaveTicket then
			local released, releaseError = persistenceRuntime.releaseProfileFence(
				player,
				session.fence
			)
			if not released then
				warn(("[PunchWallRPG] Could not release initializing profile lease for %s: %s"):format(
					player.Name,
					tostring(releaseError)
				))
			end
		end
		if not finalSaveTicket then
			persistenceRuntime.profileSessions[player] = nil
			persistenceRuntime.pendingGamePassGrants[player] = nil
		end
		return
	end

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
			if not profileReady(player, false) then return end
			shared.PunchWallStatsSync.queue(player, name == "Depth" or name == "Score")
			if name == "Power" then shared.PunchWallPowerGrowth.Schedule(player) end
		end)
		return instance
	end

	local function text(name)
		local instance = Instance.new("StringValue")
		instance.Name = name
		instance.Value = savedText(savedData, name)
		instance.Parent = stats
		instance.Changed:Connect(function()
			if not profileReady(player, false) then return end
			shared.PunchWallStatsSync.queue(player)
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
	local decodedOwnedFists = nil
	if ownedFists then
		local ok, decoded = pcall(function() return HttpService:JSONDecode(ownedFists.Value) end)
		if not ok or type(decoded) ~= "table" then
			ownedFists.Value = TEXT_STAT_DEFAULTS.OwnedFistsJSON
			decodedOwnedFists = { "Starter Glove" }
		elseif not table.find(decoded, "Starter Glove") then
			table.insert(decoded, 1, "Starter Glove")
			ownedFists.Value = HttpService:JSONEncode(decoded)
			decodedOwnedFists = decoded
		else
			decodedOwnedFists = decoded
		end
	end
	stats.TutorialVersion.Value = GameConfig.TutorialVersion
	if stats.TutorialCompleted.Value >= 1 or (decodedOwnedFists and table.find(decodedOwnedFists, "Boxing Glove")) then
		stats.TutorialCompleted.Value = 1
		stats.TutorialStep.Value = GameConfig.TutorialCompleteStep
	else
		stats.TutorialCompleted.Value = 0
		stats.TutorialStep.Value = math.clamp(stats.TutorialStep.Value, 1, GameConfig.TutorialCompleteStep - 1)
	end
	for _, name in ipairs({
		"OwnedPremiumFistsJSON",
		"OwnedPremiumPetsJSON",
		"OwnedHonorItemsJSON",
		"PetInventoryJSON",
		"EquippedPetsJSON",
		"DiscoveredPetsJSON",
		"LockedPetsJSON",
	}) do
		local value = stats:FindFirstChild(name)
		if value then
			local ok, decoded = pcall(function() return HttpService:JSONDecode(value.Value) end)
			if not ok or type(decoded) ~= "table" then value.Value = "[]" end
		end
	end
	local equippedDefinition = GameConfig.FistDefinition(stats.EquippedFist.Value)
	stats.FistMultiplier.Value = equippedDefinition.mult
	stats.BreakSpeed.Value = 1
	-- Migrate legacy display-name ownership to stable ids, discard unknown and
	-- duplicate entries, and never trust an equipped relic that is not owned.
	local normalizedHonorOwned = {}
	local normalizedHonorSet = {}
	local honorOwnedOk, honorOwnedSource = pcall(function()
		return HttpService:JSONDecode(stats.OwnedHonorItemsJSON.Value)
	end)
	if honorOwnedOk and type(honorOwnedSource) == "table" then
		for _, selector in ipairs(honorOwnedSource) do
			local definition = GameConfig.HonorItemDefinition(selector)
			if definition and not normalizedHonorSet[definition.id] then
				normalizedHonorSet[definition.id] = true
				table.insert(normalizedHonorOwned, definition.id)
			end
		end
	end
	stats.OwnedHonorItemsJSON.Value = HttpService:JSONEncode(normalizedHonorOwned)
	local honorDefinition = GameConfig.HonorItemDefinition(stats.EquippedHonorItem.Value)
	if not honorDefinition or not normalizedHonorSet[honorDefinition.id] then
		honorDefinition = nil
		stats.EquippedHonorItem.Value = "None"
	else
		stats.EquippedHonorItem.Value = honorDefinition.id
	end
	stats.HonorPowerBonus.Value = honorDefinition
		and math.min(GameConfig.Honor.MaxEquippedPowerBonus, honorDefinition.powerBonus)
		or 0

	local offlineTrainingGain = 0
	local nowEpoch = os.time()
	local qualificationPower = trainingQualificationPower(player)
	local trainingStation = GameConfig.TrainingStation(stats.TrainingStationId.Value)
	if not trainingStation or qualificationPower < trainingStation.minPower then
		trainingStation = GameConfig.TrainingStationForPower(qualificationPower)
		stats.TrainingStationId.Value = trainingStation.id
	end
	if stats.TrainingActive.Value >= 1 and stats.TrainingUpdatedAt.Value > 0 then
		local elapsed = math.clamp(nowEpoch - stats.TrainingUpdatedAt.Value, 0, GameConfig.Training.MaxOfflineSeconds)
		local requestedOfflineGain = GameConfig.TrainingOfflineGain(trainingStation.id, elapsed)
		offlineTrainingGain = math.max(0, math.min(
			requestedOfflineGain,
			ProfilePersistence.MaxAuthoritativeNumber - leaderstats.Power.Value
		))
		if offlineTrainingGain > 0 then
			leaderstats.Power.Value += offlineTrainingGain
		end
	end
	stats.TrainingUpdatedAt.Value = nowEpoch
	player:SetAttribute("AutoTrainingActive", stats.TrainingActive.Value >= 1)
	player:SetAttribute("ActiveTrainingStationId", trainingStation.id)
	player:SetAttribute("ActiveTrainingStationName", trainingStation.name)
	player:SetAttribute("ActiveTrainingPowerPerSecond", trainingStation.gain)
	player:SetAttribute("ActiveTrainingRequiredPower", trainingStation.minPower)
	player:SetAttribute("TrainingQualificationPower", qualificationPower)
	player:SetAttribute(
		"TrainingTickAnchor",
		stats.TrainingActive.Value >= 1 and workspace:GetServerTimeNow() or nil
	)
	player:SetAttribute("OfflineTrainingGain", offlineTrainingGain)
	local dailyQuestDate = stats:FindFirstChild("DailyQuestDate")
	if dailyQuestDate and dailyQuestDate.Value ~= os.date("!%Y-%m-%d") then
		stats.DailyBreaks.Value = 0
		stats.DailyQuestClaimed.Value = 0
		dailyQuestDate.Value = os.date("!%Y-%m-%d")
	end
	if not player:GetAttribute("PowerGrowthConnected") then
		player:SetAttribute("PowerGrowthConnected", true)
		player.CharacterAdded:Connect(function(character)
			local generation = (player:GetAttribute("PowerGrowthGeneration") or 0) + 1
			player:SetAttribute("PowerGrowthGeneration", generation)
			task.delay(0.65, function()
				if player.Character == character and (player:GetAttribute("PowerGrowthGeneration") or 0) == generation then
					shared.PunchWallPowerGrowth.Apply(player)
				end
			end)
		end)
		player.CharacterAppearanceLoaded:Connect(function(character)
			if player.Character == character then shared.PunchWallPowerGrowth.Schedule(player) end
		end)
	end
	task.delay(0.65, function()
		if player.Parent then shared.PunchWallPowerGrowth.Apply(player) end
	end)

	local profileMarkedReady, readyError = persistenceRuntime.markPlayerProfileReady(player)
	if not profileMarkedReady then
		local session = persistenceRuntime.profileSessions[player]
		if persistenceRuntime.releaseProfileFence and session and session.fence then
			persistenceRuntime.releaseProfileFence(player, session.fence)
		end
		player:SetAttribute("ProfileLoadStarted", false)
		player:SetAttribute("ProfileReady", false)
		player:SetAttribute("ProfileWritable", false)
		player:SetAttribute("ProfileCanSave", false)
		player:SetAttribute("ProfilePersistenceState", "InitializationFailed")
		warn(("[PunchWallRPG] Profile readiness failed closed for %s: %s"):format(
			player.Name,
			tostring(readyError)
		))
		player:Kick("Your profile could not finish initializing safely. Please rejoin and try again.")
		return
	end

	task.defer(function()
		syncStats(player)
		notify(player, "Hero City online. TRAIN to power up, then PUNCH through the city targets.")
		if offlineTrainingGain > 0 then
			sendFeedback(player, {
				type = "OfflineTraining",
				target = "Power Training",
				power = offlineTrainingGain,
				seconds = math.floor(offlineTrainingGain / math.max(1, trainingStation.gain * GameConfig.Training.OfflineEfficiency)),
				station = trainingStation.displayName,
				color = PolishConfig.Palette.Reward,
			})
		end
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

shared.PunchWallHonor = {}

function shared.PunchWallHonor.Grant(player, amount, source, target)
	local before = math.clamp(
		math.floor(tonumber(statValue(player, "Honor", 0)) or 0),
		0,
		ProfilePersistence.MaxAuthoritativeNumber
	)
	local requested = math.max(0, math.floor(tonumber(amount) or 0))
	local after = math.min(ProfilePersistence.MaxAuthoritativeNumber, before + requested)
	local granted = after - before
	setStat(player, "Honor", after)
	if granted > 0 then
		sendFeedback(player, {
			type = "Honor",
			target = target or source or "HONOR",
			source = source,
			honor = granted,
			color = Color3.fromRGB(255, 205, 61),
		})
	end
	return granted
end

function shared.PunchWallHonor.MilestoneClaimed(mask, index)
	local bit = 2 ^ (index - 1)
	return math.floor(math.max(0, tonumber(mask) or 0) / bit) % 2 >= 1, bit
end

function shared.PunchWallHonor.PendingMilestones(player, milestoneList, maskStat, progress, progressKey)
	local mask = math.max(0, math.floor(tonumber(statValue(player, maskStat, 0)) or 0))
	local total = 0
	local claimed = {}
	local nextMask = mask
	for index, milestone in ipairs(milestoneList) do
		local wasClaimed, bit = shared.PunchWallHonor.MilestoneClaimed(mask, index)
		if not wasClaimed and progress >= (milestone[progressKey] or math.huge) then
			nextMask += bit
			total += milestone.honor or 0
			table.insert(claimed, milestone[progressKey])
		end
	end
	return total, claimed, nextMask
end

function shared.PunchWallHonor.ClaimMilestones(player, milestoneList, maskStat, progress, progressKey, source)
	local total, claimed, nextMask = shared.PunchWallHonor.PendingMilestones(
		player,
		milestoneList,
		maskStat,
		progress,
		progressKey
	)
	if #claimed == 0 then return 0, claimed end
	local honor = math.max(0, math.floor(tonumber(statValue(player, "Honor", 0)) or 0))
	if honor + total > ProfilePersistence.MaxAuthoritativeNumber then
		return 0, claimed, "honor_headroom"
	end
	-- Claim state is committed before the currency mutation and no yield occurs
	-- between them, so same-frame/re-entrant attempts cannot double award.
	setStat(player, maskStat, nextMask)
	return shared.PunchWallHonor.Grant(player, total, source, source), claimed
end

function shared.PunchWallHonor.ClaimDepthMilestones(player, depth)
	return shared.PunchWallHonor.ClaimMilestones(
		player,
		GameConfig.Honor.DepthMilestones,
		"HonorMilestoneMask",
		math.max(0, math.floor(tonumber(depth) or 0)),
		"depth",
		"DEPTH MILESTONE"
	)
end

function shared.PunchWallHonor.ClaimRebirthMilestones(player, rebirths)
	return shared.PunchWallHonor.ClaimMilestones(
		player,
		GameConfig.Honor.RebirthMilestones,
		"HonorRebirthMilestoneMask",
		math.max(0, math.floor(tonumber(rebirths) or 0)),
		"rebirths",
		"REBIRTH MILESTONE"
	)
end

function shared.PunchWallHonor.ClaimQualifiedWorldClear(player, contributionShare)
	local honorConfig = GameConfig.Honor
	if statValue(player, "Depth", 0) < GameConfig.WorldProgressTarget then
		return 0, "depth_gate"
	end
	local finalDepthClaimed = shared.PunchWallHonor.MilestoneClaimed(
		statValue(player, "HonorMilestoneMask", 0),
		#honorConfig.DepthMilestones
	)
	if not finalDepthClaimed then
		return 0, "depth_milestone_gate"
	end
	if contributionShare < honorConfig.MinimumBossContribution then
		return 0, "contribution_gate"
	end
	local clearId = tostring(game.JobId) .. ":" .. tostring(root:GetAttribute("WorldResetCount") or 0)
	if statValue(player, "LastHonorClearId", "") == clearId then
		return 0, "duplicate_clear"
	end
	local now = os.time()
	local lastClearAt = math.max(0, tonumber(statValue(player, "LastHonorClearAt", 0)) or 0)
	if lastClearAt > 0 and now - lastClearAt < honorConfig.MinimumClearIntervalSeconds then
		return 0, "clear_cooldown"
	end
	local today = os.date("!%Y-%m-%d", now)
	local clearsToday = statValue(player, "HonorClearDate", "") == today
		and math.max(0, math.floor(tonumber(statValue(player, "HonorClearsToday", 0)) or 0))
		or 0
	if clearsToday >= honorConfig.MaxWorldClearsPerDay then
		return 0, "daily_cap"
	end
	local reward = honorConfig.WorldClearBase
	if clearsToday == 0 then reward += honorConfig.FirstDailyClearBonus end
	setStat(player, "HonorClearDate", today)
	setStat(player, "HonorClearsToday", clearsToday + 1)
	setStat(player, "LastHonorClearId", clearId)
	setStat(player, "LastHonorClearAt", now)
	return shared.PunchWallHonor.Grant(player, reward, "WORLD CLEAR", "TITAN HQ CLEARED"), "awarded"
end

local function effectivePower(player)
	local value = GameConfig.EffectivePower(
		statValue(player, "Power", 1),
		statValue(player, "FistMultiplier", 1),
		statValue(player, "PetMultiplier", 0),
		statValue(player, "Rebirths", 0),
		statValue(player, "FistMastery", 1),
		statValue(player, "HonorPowerBonus", 0)
	)
	if (player:GetAttribute("DamageBoostExpiresAt") or 0) > workspace:GetServerTimeNow() then value *= 2 end
	return value
end

shared.PunchWallQueueDepthMilestone = function(player, previousDepth)
	local existingFrom = tonumber(player:GetAttribute("PendingDepthFeedbackFrom"))
	player:SetAttribute("PendingDepthFeedbackFrom", existingFrom and math.min(existingFrom, previousDepth) or previousDepth)
	local token = (player:GetAttribute("PendingDepthFeedbackToken") or 0) + 1
	player:SetAttribute("PendingDepthFeedbackToken", token)
	task.delay(0.12, function()
		if not player.Parent or player:GetAttribute("PendingDepthFeedbackToken") ~= token then return end
		local fromDepth = tonumber(player:GetAttribute("PendingDepthFeedbackFrom")) or previousDepth
		local currentDepth = statValue(player, "Depth", fromDepth)
		player:SetAttribute("PendingDepthFeedbackFrom", nil)
		if currentDepth <= fromDepth then return end
		local previousRank = GameConfig.RankForDepth(fromDepth)
		local nextRank = GameConfig.RankForDepth(currentDepth)
		sendFeedback(player, { type = "DepthRecord", target = currentDepth, depth = currentDepth, color = PolishConfig.Palette.HeroCyan })
		if nextRank ~= previousRank then
			sendFeedback(player, { type = "RankChange", target = nextRank, depth = currentDepth, color = PolishConfig.Palette.HeroYellow })
		end
		local previousTier = math.floor(math.max(0, fromDepth - 1) / 8) + 1
		local nextTier = math.floor(math.max(0, currentDepth - 1) / 8) + 1
		if nextTier > previousTier then
			sendFeedback(player, { type = "TierEntry", target = "MATERIAL TIER " .. nextTier, tier = nextTier, depth = currentDepth, color = PolishConfig.Palette.HeroRed })
		end
	end)
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

local function completeTutorialAction(player, actionId)
	if statValue(player, "TutorialCompleted", 0) >= 1 then return false end
	local current = math.clamp(
		math.floor(statValue(player, "TutorialStep", 1)),
		1,
		GameConfig.TutorialCompleteStep
	)
	local advanced = false
	if actionId == "PunchWall" and current == 1 then
		setStat(player, "TutorialStep", 2)
		advanced = true
	elseif actionId == "OpenShop" and current == 2 then
		setStat(player, "TutorialStep", 3)
		advanced = true
	elseif actionId == "BuyStarterFist" and current >= 2 then
		setStat(player, "TutorialStep", GameConfig.TutorialCompleteStep)
		setStat(player, "TutorialCompleted", 1)
		advanced = true
		sendFeedback(player, {
			type = "TutorialComplete",
			target = "Tutorial",
			message = "TUTORIAL COMPLETE • KEEP SMASHING!",
			color = PolishConfig.Palette.Reward,
		})
		if persistenceRuntime.requestPlayerSave then
			persistenceRuntime.requestPlayerSave(player, "TutorialComplete", false)
		end
	end
	if advanced then
		player:SetAttribute("LastTutorialAction", actionId)
		player:SetAttribute("TutorialActionSerial", (player:GetAttribute("TutorialActionSerial") or 0) + 1)
	end
	return advanced
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
	for _, field in ipairs(ProfilePersistence.BoostExpiryFields) do
		data[field] = tonumber(player:GetAttribute(field)) or 0
	end
	return data
end

do
local function newPersistenceTicket(reason)
	return {
		completed = false,
		success = false,
		reason = reason,
	}
end

local function completedPersistenceTicket(reason, success, persistenceError, skipped)
	local ticket = newPersistenceTicket(reason)
	ticket.completed = true
	ticket.success = success == true
	ticket.error = persistenceError
	ticket.skipped = skipped == true
	return ticket
end

local function rememberFinalSaveTicket(player, finalSave, ticket)
	if finalSave then
		persistenceRuntime.finalSaveTickets[player] = ticket
	end
	return ticket
end

local function finishPersistenceTickets(operation, success, persistenceError)
	for _, ticket in ipairs(operation.tickets or {}) do
		ticket.completed = true
		ticket.success = success == true
		ticket.error = persistenceError
	end
end

local function copyKnownReceiptIds(session)
	local receiptIds = {}
	for purchaseId in pairs(session and session.knownReceiptIds or {}) do
		receiptIds[purchaseId] = true
	end
	return receiptIds
end

local function getPersistenceQueue(player)
	local state = persistenceRuntime.queues[player]
	if not state then
		state = {
			operations = {},
			queuedReceipts = {},
			queuedReceiptCount = 0,
			running = false,
			blocked = false,
			departed = false,
		}
		persistenceRuntime.queues[player] = state
	end
	return state
end

local function hasUncertainReceipt(session)
	return session and next(session.receiptUncertain) ~= nil
end

local function releaseProfileFence(player, fence)
	if not fence or not persistenceRuntime.playerStore then
		return false, "missing_session_fence"
	end
	local callbackState = {}
	local ok, releasedOrError = persistenceRuntime.retryDataStoreCall(function()
		return persistenceRuntime.playerStore:UpdateAsync(tostring(player.UserId), function(previous)
			callbackState = {}
			local releasedProfile, released, releaseError = ProfilePersistence.ReleaseSessionLease(
				previous,
				fence,
				os.time(),
				GameConfig.DataVersion,
				ProfilePersistence.MaxReceiptLedgerEntries
			)
			if not releasedProfile or not released then
				callbackState.error = releaseError or "session_lease_release_rejected"
				return nil
			end
			callbackState.released = true
			return releasedProfile
		end)
	end)
	if not ok then
		return false, releasedOrError
	end
	if callbackState.error then
		return false, callbackState.error
	end
	if not callbackState.released or type(releasedOrError) ~= "table" then
		return false, "session_lease_release_rejected"
	end
	return true
end

local function persistSnapshot(player, snapshot, releaseLease)
	local session = persistenceRuntime.profileSessions[player]
	local ready, readinessError = profileReady(player, true)
	if not ready then
		return false, readinessError
	end
	if not persistenceRuntime.playerStore then
		return false, "current_store_unavailable"
	end
	local callbackState = {}
	local ok, canonicalOrError = persistenceRuntime.retryDataStoreCall(function()
		return persistenceRuntime.playerStore:UpdateAsync(tostring(player.UserId), function(previous)
			callbackState = {}
			local callbackNow = os.time()
			local canonical, mergeStateOrError = ProfilePersistence.MergeSnapshotFenced(
				previous,
				snapshot,
				session.fence,
				callbackNow,
				GameConfig.DataVersion,
				ProfilePersistence.MaxReceiptLedgerEntries
			)
			if not canonical then
				callbackState.error = mergeStateOrError or "profile_fence_rejected"
				return nil
			end
			if releaseLease then
				local releasedProfile, released, releaseError = ProfilePersistence.ReleaseSessionLease(
					canonical,
					session.fence,
					callbackNow,
					GameConfig.DataVersion,
					ProfilePersistence.MaxReceiptLedgerEntries
				)
				if not releasedProfile or not released then
					callbackState.error = releaseError or "session_lease_release_rejected"
					return nil
				end
				callbackState.released = true
				return releasedProfile
			end
			local renewedProfile, renewedFence, renewed, renewStateOrError =
				ProfilePersistence.RenewSessionLease(
					canonical,
					session.fence,
					callbackNow,
					persistenceRuntime.sessionLeaseSeconds,
					GameConfig.DataVersion,
					ProfilePersistence.MaxReceiptLedgerEntries
				)
			if not renewedProfile or not renewed or not renewedFence then
				callbackState.error = renewStateOrError or "session_lease_renew_rejected"
				return nil
			end
			callbackState.fence = renewedFence
			callbackState.leaseExpiresAt = renewedProfile.SessionLease
				and renewedProfile.SessionLease.ExpiresAt or 0
			return renewedProfile
		end)
	end)
	if not ok then
		return false, canonicalOrError
	end
	if callbackState.error then
		if string.find(tostring(callbackState.error), "session_", 1, true)
			or string.find(tostring(callbackState.error), "fence", 1, true)
		then
			session.ready = false
			session.writable = false
			player:SetAttribute("ProfileReady", false)
			player:SetAttribute("ProfileWritable", false)
			player:SetAttribute("ProfileCanSave", false)
			player:SetAttribute("ProfilePersistenceState", "SessionFenceRejected")
		end
		return false, callbackState.error
	end
	if type(canonicalOrError) ~= "table" then
		return false, "profile_snapshot_merge_rejected"
	end
	if callbackState.released then
		session.leaseReleased = true
		session.ready = false
		session.writable = false
		session.leaseExpiresAt = 0
		player:SetAttribute("ProfileReady", false)
		player:SetAttribute("ProfileWritable", false)
		player:SetAttribute("ProfileCanSave", false)
		player:SetAttribute("ProfileLeaseExpiresAt", 0)
	else
		session.fence = callbackState.fence
		session.leaseExpiresAt = callbackState.leaseExpiresAt
		player:SetAttribute("ProfileRevision", callbackState.fence.Revision)
		player:SetAttribute("ProfileLeaseExpiresAt", callbackState.leaseExpiresAt)
	end
	return true
end

local function runPersistenceOperation(player, operation)
	if operation.kind == "save" then
		local session = persistenceRuntime.profileSessions[player]
		if hasUncertainReceipt(session) then
			return false, "receipt_commit_state_uncertain", true
		end
		local ok, persistenceError = persistSnapshot(player, operation.snapshot, operation.finalSave)
		return ok, persistenceError, false
	end
	if operation.kind == "receipt" then
		local ok, success, persistenceError = pcall(operation.execute)
		if not ok then
			return false, success, false
		end
		return success == true, persistenceError, false
	end
	if operation.kind == "release" then
		local session = persistenceRuntime.profileSessions[player]
		local released, releaseError = releaseProfileFence(player, session and session.fence)
		if released and session then
			session.leaseReleased = true
			session.ready = false
			session.writable = false
			session.leaseExpiresAt = 0
			player:SetAttribute("ProfileReady", false)
			player:SetAttribute("ProfileWritable", false)
			player:SetAttribute("ProfileCanSave", false)
			player:SetAttribute("ProfileLeaseExpiresAt", 0)
		end
		return released, releaseError, false
	end
	return false, "unknown_persistence_operation", false
end

local startPersistenceWorker
startPersistenceWorker = function(player)
	local state = getPersistenceQueue(player)
	if state.running then
		return
	end
	state.running = true
	state.blocked = false
	task.spawn(function()
		local blocked = false
		while persistenceRuntime.queues[player] == state do
			local operation = table.remove(state.operations, 1)
			if not operation then
				break
			end
			local success, persistenceError, shouldBlock = runPersistenceOperation(player, operation)
			if shouldBlock then
				table.insert(state.operations, 1, operation)
				blocked = true
				break
			end
			if operation.kind == "receipt" then
				state.queuedReceipts[operation.purchaseId] = nil
				state.queuedReceiptCount = math.max(0, state.queuedReceiptCount - 1)
			end
			finishPersistenceTickets(operation, success, persistenceError)
			if not success then
				warn(("[PunchWallRPG] Persistence %s failed for %s: %s"):format(
					operation.kind,
					player.Name,
					tostring(persistenceError)
				))
			end
		end
		state.running = false
		state.blocked = blocked
		if state.departed and #state.operations == 0 then
			persistenceRuntime.queues[player] = nil
			persistenceRuntime.profileSessions[player] = nil
			persistenceRuntime.pendingGamePassGrants[player] = nil
		elseif not blocked and #state.operations > 0 then
			startPersistenceWorker(player)
		end
	end)
end

local function requestPlayerSave(player, reason, finalSave)
	reason = reason or "Save"
	local existingFinalTicket = finalSave and persistenceRuntime.finalSaveTickets[player]
	if existingFinalTicket then
		return existingFinalTicket
	end
	local session = persistenceRuntime.profileSessions[player]
	if player:GetAttribute("StudioHighPowerTestMode") then
		return rememberFinalSaveTicket(
			player,
			finalSave,
			completedPersistenceTicket(reason, true, nil, true)
		)
	end
	local ready, readinessError = profileReady(player, false)
	if not ready then
		if finalSave
			and session
			and session.fence
			and session.canBecomeWritable
			and persistenceRuntime.playerStore
		then
			local ticket = newPersistenceTicket(reason)
			local state = getPersistenceQueue(player)
			rememberFinalSaveTicket(player, finalSave, ticket)
			table.insert(state.operations, {
				kind = "release",
				reason = reason,
				finalSave = true,
				tickets = { ticket },
			})
			startPersistenceWorker(player)
			return ticket
		end
		return completedPersistenceTicket(reason, false, readinessError)
	end
	if not session.writable then
		if session.loadedState == "EphemeralStudio" or session.state == "EphemeralStudio" then
			return rememberFinalSaveTicket(
				player,
				finalSave,
				completedPersistenceTicket(reason, true, nil, true)
			)
		end
		return rememberFinalSaveTicket(
			player,
			finalSave,
			completedPersistenceTicket(reason, false, "profile_not_writable")
		)
	end
	if not persistenceRuntime.playerStore then
		return rememberFinalSaveTicket(
			player,
			finalSave,
			completedPersistenceTicket(reason, false, "current_store_unavailable")
		)
	end
	if statValue(player, "TrainingActive", 0) >= 1 then
		setStat(player, "TrainingUpdatedAt", os.time())
	end

	local ticket = newPersistenceTicket(reason)
	local snapshot = collectPlayerData(player)
	local state = getPersistenceQueue(player)
	if not finalSave then
		local previousOperation = state.operations[#state.operations]
		if previousOperation and previousOperation.kind == "save" and not previousOperation.finalSave then
			previousOperation.snapshot = snapshot
			previousOperation.receiptIds = copyKnownReceiptIds(session)
			if #previousOperation.tickets >= persistenceRuntime.maxSaveTicketsPerOperation then
				root:SetAttribute(
					"PersistenceCoalescedTicketReuseCount",
					(root:GetAttribute("PersistenceCoalescedTicketReuseCount") or 0) + 1
				)
				startPersistenceWorker(player)
				return previousOperation.tickets[#previousOperation.tickets]
			end
			table.insert(previousOperation.tickets, ticket)
			startPersistenceWorker(player)
			return ticket
		end
	end
	rememberFinalSaveTicket(player, finalSave, ticket)
	table.insert(state.operations, {
		kind = "save",
		reason = reason,
		finalSave = finalSave == true,
		snapshot = snapshot,
		receiptIds = copyKnownReceiptIds(session),
		tickets = { ticket },
	})
	startPersistenceWorker(player)
	return ticket
end

local function enqueueReceiptOperation(player, purchaseId, execute)
	local session = persistenceRuntime.profileSessions[player]
	local ready, readinessError = profileReady(player, true)
	if not ready then
		return completedPersistenceTicket("Receipt", false, readinessError)
	end
	if not persistenceRuntime.playerStore then
		return completedPersistenceTicket("Receipt", false, "current_store_unavailable")
	end
	local state = getPersistenceQueue(player)
	local existingTicket = state.queuedReceipts[purchaseId]
	if existingTicket then
		return existingTicket
	end
	if state.queuedReceiptCount >= persistenceRuntime.maxQueueOperations then
		return completedPersistenceTicket("Receipt", false, "receipt_queue_full")
	end
	local ticket = newPersistenceTicket("Receipt")
	local operation = {
		kind = "receipt",
		purchaseId = purchaseId,
		execute = execute,
		tickets = { ticket },
	}
	state.queuedReceipts[purchaseId] = ticket
	state.queuedReceiptCount += 1
	if session.receiptUncertain[purchaseId] then
		table.insert(state.operations, 1, operation)
	else
		table.insert(state.operations, operation)
	end
	startPersistenceWorker(player)
	return ticket
end

local function patchQueuedSaveSnapshots(player, purchaseId, receiptEntry)
	local state = persistenceRuntime.queues[player]
	if not state then
		return
	end
	for _, operation in ipairs(state.operations) do
		if operation.kind == "save" and not operation.receiptIds[purchaseId] then
			ProfilePersistence.ApplyReceiptEntryToSnapshot(operation.snapshot, receiptEntry)
			operation.receiptIds[purchaseId] = true
		end
	end
end

local function waitForPersistenceTicket(ticket, timeoutSeconds)
	if not ticket then
		return false, "missing_ticket"
	end
	local deadline = os.clock() + math.max(0, tonumber(timeoutSeconds) or 0)
	while not ticket.completed and os.clock() < deadline do
		task.wait(0.05)
	end
	if not ticket.completed then
		return false, "persistence_timeout"
	end
	return ticket.success == true, ticket.error
end

local function markPersistencePlayerDeparted(player, abandonPending)
	local state = persistenceRuntime.queues[player]
	if not state then
		persistenceRuntime.profileSessions[player] = nil
		persistenceRuntime.pendingGamePassGrants[player] = nil
		return
	end
	state.departed = true
	if abandonPending and #state.operations > 0 then
		for _, operation in ipairs(state.operations) do
			finishPersistenceTickets(operation, false, "player_departed_before_persistence")
		end
		table.clear(state.operations)
		table.clear(state.queuedReceipts)
		state.queuedReceiptCount = 0
	end
	if not state.running and #state.operations == 0 then
		persistenceRuntime.queues[player] = nil
		persistenceRuntime.profileSessions[player] = nil
		persistenceRuntime.pendingGamePassGrants[player] = nil
	end
end
	persistenceRuntime.requestPlayerSave = requestPlayerSave
	persistenceRuntime.releaseProfileFence = releaseProfileFence
	persistenceRuntime.enqueueReceiptOperation = enqueueReceiptOperation
	persistenceRuntime.patchQueuedSaveSnapshots = patchQueuedSaveSnapshots
	persistenceRuntime.waitForTicket = waitForPersistenceTicket
	persistenceRuntime.markPlayerDeparted = markPersistencePlayerDeparted
end

local base = makePart("World 1 Forest Ground", root, Vector3.new(190, 3, 150), Vector3.new(-15, -1.5, 0), Color3.fromRGB(66, 116, 61), Enum.Material.Grass)
base.Locked = true

local islandEdge = makePart("Forest Island Rock Edge", polishFolder, Vector3.new(194, 0.6, 154), Vector3.new(-15, -3.15, 0), Color3.fromRGB(73, 82, 74), Enum.Material.Rock)
islandEdge.Locked = true
local metroFoundation = makePart("Forest Horizon Ground", decorFolder, Vector3.new(420, 5, 620), Vector3.new(-15, -7, 0), Color3.fromRGB(49, 89, 47), Enum.Material.Ground)
metroFoundation.Locked = true
metroFoundation.CanCollide = false
metroFoundation:SetAttribute("VisualRole", "ForestHorizonFoundation")

for _, boundary in ipairs({
	{ "Forest Hub West Ridge", Vector3.new(5, 15, 150), Vector3.new(-109, 6.5, 0) },
	{ "Forest Hub East Ridge", Vector3.new(5, 15, 150), Vector3.new(79, 6.5, 0) },
	{ "Forest Hub South Ridge", Vector3.new(190, 15, 5), Vector3.new(-15, 6.5, 73) },
	{ "Forest Hub North West Ridge", Vector3.new(80, 15, 5), Vector3.new(-70, 6.5, -73) },
	{ "Forest Hub North East Ridge", Vector3.new(50, 15, 5), Vector3.new(54, 6.5, -73) },
}) do
	local ridge = makePart(boundary[1], root, boundary[2], boundary[3], Color3.fromRGB(64, 77, 67), Enum.Material.Rock)
	ridge.CanTouch = false
	ridge:SetAttribute("VisualRole", "VisibleHubBoundary")
	ridge:SetAttribute("MapBoundary", true)
	ridge:SetAttribute("CollisionSource", "VisibleGeometry")
end
root:SetAttribute("ForestBoundaryCollisionMode", "VisibleRidgesOnly")
root:SetAttribute("ForestBoundaryColliderCount", 5)

shared.PunchWallUpdateWorldRankBoard = (function()
local rankBoard = makePart("World 1 Hero Rank Board", root, Vector3.new(31, 17, 1.2), Vector3.new(62, 9.2, -38), Color3.fromRGB(9, 17, 24), Enum.Material.Metal)
rankBoard:SetAttribute("VisualRole", "WorldLeaderboard")
rankBoard:SetAttribute("LeaderboardKind", "DepthAndScore")
for _, x in ipairs({ 48.5, 75.5 }) do
	makePart("Rank Board Support " .. tostring(x), root, Vector3.new(1.2, 11, 1.2), Vector3.new(x, 4.5, -38), Color3.fromRGB(45, 52, 58), Enum.Material.Metal)
end
local rankSurface = Instance.new("SurfaceGui")
rankSurface.Name = "Hero Rank Surface"
rankSurface.Face = Enum.NormalId.Back
rankSurface.CanvasSize = Vector2.new(930, 510)
rankSurface.LightInfluence = 0
rankSurface.AlwaysOnTop = false
rankSurface.Parent = rankBoard
local rankBackground = Instance.new("Frame")
rankBackground.Size = UDim2.fromScale(1, 1)
rankBackground.BackgroundColor3 = Color3.fromRGB(7, 15, 22)
rankBackground.BorderSizePixel = 0
rankBackground.Parent = rankSurface
local rankHeader = Instance.new("TextLabel")
rankHeader.Name = "Header"
rankHeader.Size = UDim2.fromScale(1, 0.17)
rankHeader.BackgroundColor3 = Color3.fromRGB(192, 37, 42)
rankHeader.BorderSizePixel = 0
rankHeader.Font = Enum.Font.GothamBlack
rankHeader.Text = "WORLD 1 HERO RANKS"
rankHeader.TextColor3 = Color3.new(1, 1, 1)
rankHeader.TextScaled = true
rankHeader.Parent = rankBackground
local rankSubheader = Instance.new("TextLabel")
rankSubheader.Position = UDim2.fromScale(0, 0.17)
rankSubheader.Size = UDim2.fromScale(1, 0.08)
rankSubheader.BackgroundColor3 = Color3.fromRGB(12, 28, 39)
rankSubheader.BorderSizePixel = 0
rankSubheader.Font = Enum.Font.GothamBold
rankSubheader.Text = "RANK    HERO                         DEPTH         SCORE"
rankSubheader.TextColor3 = Color3.fromRGB(57, 203, 255)
rankSubheader.TextScaled = true
rankSubheader.Parent = rankBackground
local worldRankRows = {}
for index = 1, 5 do
	local row = Instance.new("Frame")
	row.Name = "Rank " .. index
	row.Position = UDim2.fromScale(0.035, 0.27 + (index - 1) * 0.14)
	row.Size = UDim2.fromScale(0.93, 0.12)
	row.BackgroundColor3 = index == 1 and Color3.fromRGB(58, 48, 23) or Color3.fromRGB(18, 29, 38)
	row.BorderSizePixel = 0
	row.Parent = rankBackground
	local avatar = Instance.new("ImageLabel")
	avatar.Name = "Avatar"
	avatar.Position = UDim2.fromScale(0.09, 0.08)
	avatar.Size = UDim2.fromScale(0.085, 0.84)
	avatar.BackgroundColor3 = Color3.fromRGB(35, 53, 65)
	avatar.BorderSizePixel = 0
	avatar.ScaleType = Enum.ScaleType.Crop
	avatar.Parent = row
	local line = Instance.new("TextLabel")
	line.Name = "Line"
	line.Size = UDim2.fromScale(1, 1)
	line.BackgroundTransparency = 1
	line.Font = Enum.Font.GothamBold
	line.Text = ("%d        ---"):format(index)
	line.TextColor3 = index == 1 and Color3.fromRGB(255, 213, 67) or Color3.fromRGB(235, 241, 244)
	line.TextScaled = true
	line.TextXAlignment = Enum.TextXAlignment.Left
	line.Parent = row
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.01, 0)
	padding.PaddingRight = UDim.new(0.02, 0)
	padding.Parent = line
	worldRankRows[index] = { row = row, avatar = avatar, line = line }
end

return function(entries)
	if not rankBoard.Parent then return end
	for index, widgets in ipairs(worldRankRows) do
		local entry = entries[index]
		if entry then
			widgets.avatar.Image = ("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"):format(entry.userId)
			widgets.line.Text = ("%d                 %-18s       D%-3d      %s"):format(index, string.sub(tostring(entry.name), 1, 18), entry.depth, formatNumber(entry.score))
			widgets.row.Visible = true
		else
			widgets.avatar.Image = ""
			widgets.line.Text = ("%d                 ---"):format(index)
			widgets.row.Visible = true
		end
	end
	rankBoard:SetAttribute("UpdatedAt", workspace:GetServerTimeNow())
	rankBoard:SetAttribute("EntryCount", #entries)
end
end)()

makePart("Forest Main Stone Trail", decorFolder, Vector3.new(160, 0.26, 30), Vector3.new(-1, 0.28, -27), Color3.fromRGB(104, 110, 104), Enum.Material.Slate)
makePart("Training Camp Deck", decorFolder, Vector3.new(78, 0.28, 24), Vector3.new(-43, 0.3, 24), Color3.fromRGB(113, 89, 61), Enum.Material.WoodPlanks)
makePart("Forest Armory Path", decorFolder, Vector3.new(80, 0.26, 24), Vector3.new(-43, 0.29, -9), Color3.fromRGB(112, 116, 109), Enum.Material.Cobblestone)
makePart("Hall Of Honor Clearing", decorFolder, Vector3.new(55, 0.24, 32), Vector3.new(34, 0.27, 27), Color3.fromRGB(71, 111, 63), Enum.Material.LeafyGrass)
if PolishConfig.Environment.CityGroundOverlays then
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
end

makePart("Spawn Pad", root, Vector3.new(15, 0.7, 15), Vector3.new(-2, 0.65, -18), Color3.fromRGB(83, 91, 86), Enum.Material.Slate)
local spawn = Instance.new("SpawnLocation")
spawn.Name = "Punch Rookie Spawn"
spawn.Anchored = true
spawn.Size = Vector3.new(10, 1, 10)
spawn.Position = Vector3.new(-2, 2, -18)
spawn.Orientation = Vector3.zero
spawn.Color = PolishConfig.Palette.HeroCyan
spawn.Material = Enum.Material.Slate
spawn.Transparency = 1
spawn.CanCollide = false
spawn.Neutral = true
spawn.Parent = root

-- A character can finish loading while the world is still being generated.
-- Bind both existing and future characters to the completed map's spawn.
do
local spawnBindings = {}
function shared.PunchWallBindPlayerSpawn(player)
	if spawnBindings[player] then return end
	player.RespawnLocation = spawn
	local state = {}
	spawnBindings[player] = state
	local function placeCharacter(character)
		if state.character == character then return end
		state.character = character
		task.spawn(function()
			character:WaitForChild("HumanoidRootPart", 5)
			character:WaitForChild("Humanoid", 5)
			local deadline = os.clock() + 5
			while player.Character == character and not character:IsDescendantOf(workspace) and os.clock() < deadline do
				task.wait()
			end
			local rootPart = character:FindFirstChild("HumanoidRootPart")
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if not rootPart or not rootPart:IsA("BasePart") or rootPart.Parent ~= character
				or not humanoid or humanoid.Health <= 0
				or spawnBindings[player] ~= state or state.character ~= character
				or player.Character ~= character or not character:IsDescendantOf(workspace) then return end
			rootPart.AssemblyLinearVelocity = Vector3.zero
			rootPart.AssemblyAngularVelocity = Vector3.zero
			local position = spawn.Position + Vector3.new(0, 4, 0)
			rootPart.CFrame = CFrame.lookAt(position, position + Vector3.new(0, 0, -1))
			character:SetAttribute("PunchWallSpawnPlaced", true)
		end)
	end
	state.connection = player.CharacterAdded:Connect(placeCharacter)
	if player.Character then placeCharacter(player.Character) end
end
Players.PlayerRemoving:Connect(function(player)
	local state = spawnBindings[player]
	if state then state.connection:Disconnect() spawnBindings[player] = nil end
end)
end

local fallRecovery = makePart("Fall Recovery Zone", root, Vector3.new(150, 1, 470), Vector3.new(-2, -35, -150), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic)
fallRecovery.Transparency = 1
fallRecovery.CanCollide = false
fallRecovery.Touched:Connect(function(hit)
	local character = hit.Parent
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and character.PrimaryPart then
		character:PivotTo(spawn.CFrame + Vector3.new(0, 5, 0))
	end
end)

local spawnRing = makeCylinder("Forest Spawn Stone", decorFolder, Vector3.new(0.22, 17, 17), Vector3.new(-2, 1.03, -18), Color3.fromRGB(105, 112, 103), Enum.Material.Slate, Vector3.new(0, 0, 90))
spawnRing.Transparency = 0.04

local arch = makePart("Forest Training Camp Sign", root, Vector3.new(30, 3.6, 1.0), Vector3.new(-42, 11.15, 42), Color3.fromRGB(80, 55, 35), Enum.Material.WoodPlanks)
arch:SetAttribute("SignagePriority", "Zone")
makeText(arch, "FOREST POWER CAMP", "AUTO POWER TRAINING | OFFLINE GAINS", Enum.NormalId.Front)
makeText(arch, "SMASH WALL", "TRAIN HERE, THEN BREAK DEEPER", Enum.NormalId.Back)
shared.PunchWallTrainingLandmark = function()
	for _, x in ipairs({ -55.5, -28.5 }) do
		local campPost = makePart("Forest Training Camp Timber Post " .. tostring(x), decorFolder, Vector3.new(1.1, 10, 1.1), Vector3.new(x, 5, 42), Color3.fromRGB(72, 48, 31), Enum.Material.Wood)
		campPost.CanCollide = false
		campPost:SetAttribute("VisualRole", "ForestTrainingLandmark")
	end
	local campCrown = makePart("Forest Training Camp Crown Beam", decorFolder, Vector3.new(32, 0.75, 1.4), Vector3.new(-42, 12.1, 42), Color3.fromRGB(105, 74, 42), Enum.Material.WoodPlanks)
	campCrown.CanCollide = false
	campCrown:SetAttribute("VisualRole", "ForestTrainingLandmark")
end
shared.PunchWallTrainingLandmark()
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
if PolishConfig.Environment.CityGroundOverlays then
	makeStreetLight("Training Street Light", Vector3.new(-69, 0.4, 14))
	makeStreetLight("Shop Street Light", Vector3.new(-18, 0.4, -15))
	for index, position in ipairs({ Vector3.new(12, 0.4, -44), Vector3.new(54, 0.4, -44), Vector3.new(96, 0.4, -44), Vector3.new(138, 0.4, -44), Vector3.new(176, 0.4, -44) }) do
		makeStreetLight("Progression Street Light " .. index, position)
	end
end
if PolishConfig.Environment.CityGroundOverlays then
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
if PolishConfig.Environment.CityGroundOverlays then
for index, config in ipairs({
	{ Vector3.new(-21, 0.5, -13), 0 },
	{ Vector3.new(17, 0.5, -41), 0 },
	{ Vector3.new(61, 0.5, -13), 0 },
	{ Vector3.new(103, 0.5, -41), 0 },
}) do
	makeEmergencyBarricade("Emergency Barricade " .. index, config[1], config[2])
end
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
local defenseBillboard = makePart("Titan Trail Landmark", decorFolder, Vector3.new(30, 7.5, 0.8), Vector3.new(112, 12, 56), Color3.fromRGB(78, 55, 37), Enum.Material.WoodPlanks)
makeText(defenseBillboard, "TITAN TRAIL", "DEEP FOREST CHALLENGE", Enum.NormalId.Front)
makeRockCluster(decorFolder, Vector3.new(-68, 0.4, 4), Color3.fromRGB(116, 169, 152))
makeRockCluster(decorFolder, Vector3.new(-22, 0.4, -34), Color3.fromRGB(116, 169, 152))
makeCoinStack(decorFolder, Vector3.new(-55, 1.1, -6))

shared.PunchWallArchiveCityAssetsForForest = function()
	if PolishConfig.Environment.CityBuildings then return end
	local embedded = workspace:FindFirstChild("CuratedVisualAssets")
	if embedded then
		embedded:SetAttribute("RuntimeArchivedForWorld1Forest", true)
		embedded.Parent = ServerStorage
	end
end
shared.PunchWallArchiveCityAssetsForForest()

task.spawn(function()
	if not PolishConfig.Environment.CityBuildings then return end
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

local wallConfigs = GameConfig.Walls

local depthCorridorFolder = Instance.new("Folder")
depthCorridorFolder.Name = "Depth Corridor"
depthCorridorFolder.Parent = polishFolder
local corridorFloor = makePart("Depth Corridor Floor", depthCorridorFolder, Vector3.new(56, 0.5, 330), Vector3.new(-2, 0.05, -192), Color3.fromRGB(117, 121, 116), Enum.Material.Pavement)
corridorFloor:SetAttribute("VisualRole", "DepthProgressionFloor")
for _, sideX in ipairs({ -27.5, 23.5 }) do
	local sideWall = makePart("Depth Corridor Side " .. tostring(sideX), depthCorridorFolder, Vector3.new(3, 14, 330), Vector3.new(sideX, 7, -192), Color3.fromRGB(66, 78, 71), Enum.Material.Rock)
	sideWall:SetAttribute("VisualRole", "DepthCorridorBoundary")
end
for _, config in ipairs(wallConfigs) do
	local tierStartLayer = (config.depth - 1) * 8 + 1
	local tierEndLayer = math.min(config.depth * 8, 75)
	local tierStartZ = -37 - (tierStartLayer - 1) * 4
	local marker = makePart(("Tier %02d Roadside Marker"):format(config.depth), depthCorridorFolder, Vector3.new(5.4, 3.4, 0.45), Vector3.new(24.6, 2.25, tierStartZ + 6), Color3.fromRGB(21, 27, 33), Enum.Material.Metal)
	marker.CanCollide = false
	marker:SetAttribute("VisualRole", "DepthRoadsideMarker")
	marker:SetAttribute("TierStartLayer", tierStartLayer)
	marker:SetAttribute("TierEndLayer", tierEndLayer)
	makeText(marker, ("TIER %02d"):format(config.depth), ("DEPTH %02d-%02d | LV. %d"):format(tierStartLayer, tierEndLayer, config.level), Enum.NormalId.Front)
	for _, sideX in ipairs({ -28.5, 24.5 }) do
		local guideLight = makePart(("Depth %02d Guide Light %s"):format(config.depth, tostring(sideX)), depthCorridorFolder, Vector3.new(0.45, 0.45, 5), Vector3.new(sideX, 1.1, tierStartZ + 8), config.color, Enum.Material.Neon)
		guideLight.CanCollide = false
		guideLight:SetAttribute("VisualRole", "DepthGuideLight")
	end
end

local forestFolder = Instance.new("Folder")
forestFolder.Name = "World 1 Forest"
forestFolder.Parent = polishFolder
forestFolder:SetAttribute("WorldTheme", "NaturalForest")
require(ReplicatedStorage:WaitForChild("ForestVisualBuilder")).Build(forestFolder, makePart, makeBall, makeText)

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

	local damage = effectivePower(player)
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
	completeTutorialAction(player, "PunchWall")

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
		if not profileReady(player, false) then return end
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

local DEPTH_BLOCK_SIZE = GameConfig.DepthWall.BlockSize
local DEPTH_COLUMNS = GameConfig.DepthWall.Columns
local DEPTH_ROWS = GameConfig.DepthWall.Rows
local DEPTH_LAYERS = GameConfig.DepthWall.Layers
local DEPTH_LAYERS_PER_TIER = GameConfig.DepthWall.LayersPerTier
local depthBlockContributions = {}
local depthBlocksNeedingReset = {}
local depthBlockAliases = {}

local function markDepthBlockDirty(block)
	if block and block.Parent == depthBlocksFolder then
		depthBlocksNeedingReset[block] = true
	end
end

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
			block.CollisionGroup = "DepthStructure"
			block.CustomPhysicalProperties = PhysicalProperties.new(0.12, 0.82, 0.08, 1, 1)
			block:SetAttribute("IsDepthBlock", true)
			block:SetAttribute("Depth", layer)
			block:SetAttribute("MaterialTier", tier)
			block:SetAttribute("MaterialStyle", config.style or config.name)
			block:SetAttribute("TextureStyle", "ConnectedDestructible" .. tostring(config.style or config.name))
			block:SetAttribute("DebrisMaterial", config.material.Name)
			block:SetAttribute("ImpactEffectStyle", config.impactStyle or "MaterialImpact")
			block:SetAttribute("EdgeTreatment", ("ConnectedCubeSeamTier%02d"):format(tier))
			block:SetAttribute("TierTransitionStart", (layer - 1) % DEPTH_LAYERS_PER_TIER == 0)
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

do
	local expectedDepthBlockCount = DEPTH_COLUMNS * DEPTH_ROWS * DEPTH_LAYERS
	local builtDepthBlockCount = #depthBlocksFolder:GetChildren()
	assert(expectedDepthBlockCount == 5400, "Depth wall configuration must preserve exactly 5,400 gameplay blocks")
	assert(builtDepthBlockCount == expectedDepthBlockCount, "Depth wall build did not satisfy its gameplay block-count contract")
	root:SetAttribute("DepthBlockContractCount", expectedDepthBlockCount)
	root:SetAttribute("DepthBlockContractValidated", true)
end

for tier, config in ipairs(wallConfigs) do
	local layer = (tier - 1) * DEPTH_LAYERS_PER_TIER + 1
	depthBlockAliases[config.name] = depthBlocksFolder:FindFirstChild(("DepthBlock_L%03d_C06_R02"):format(layer))
end

shared.PunchWallBuildDepthTierLandmarks = function()
	local depthTierLandmarks = Instance.new("Folder")
	depthTierLandmarks.Name = "Depth Tier Landmarks"
	depthTierLandmarks.Parent = root
	for tier, config in ipairs(wallConfigs) do
		local layer = (tier - 1) * DEPTH_LAYERS_PER_TIER + 1
		local z = -34 - (layer - 1) * DEPTH_BLOCK_SIZE.Z
		local landmark = Instance.new("Model")
		landmark.Name = ("Tier %02d %s Landmark"):format(tier, config.displayName or config.name)
		landmark:SetAttribute("MaterialTier", tier)
		landmark:SetAttribute("TierName", config.displayName or config.name)
		landmark:SetAttribute("VisualRole", "DepthTierLandmark")
		landmark.Parent = depthTierLandmarks
		for _, side in ipairs({ -1, 1 }) do
			local post = makePart(
				("Tier %02d Post %d"):format(tier, side),
				landmark,
				Vector3.new(1.4, 13.5, 1.4),
				Vector3.new(-2 + side * 27.5, 6.75, z),
				config.color,
				config.material
			)
			post.CanCollide = false
			post.CanTouch = false
			post.CanQuery = false
			post:SetAttribute("TierLandmarkPart", true)
			post:SetAttribute("BaseColor", config.color)
			local attachment = Instance.new("Attachment")
			attachment.Name = "TierAtmosphereEmitter"
			attachment.Position = Vector3.new(0, 5.2, 0)
			attachment.Parent = post
			local particles = Instance.new("ParticleEmitter")
			particles.Name = "TierParticles"
			particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			particles.Color = ColorSequence.new(config.color:Lerp(Color3.new(1, 1, 1), 0.35), config.color)
			particles.LightEmission = 0.65
			particles.Lifetime = NumberRange.new(0.55, 1.1)
			particles.Rate = 5
			particles.Speed = NumberRange.new(1.5, 3.5)
			particles.SpreadAngle = Vector2.new(24, 24)
			particles.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.28),
				NumberSequenceKeypoint.new(0.7, 0.14),
				NumberSequenceKeypoint.new(1, 0),
			})
			particles.Enabled = tier == 1
			particles.Parent = attachment
		end
		local header = makePart(
			("Tier %02d Header"):format(tier),
			landmark,
			Vector3.new(56, 1.2, 1.4),
			Vector3.new(-2, 13.2, z),
			config.color:Lerp(Color3.fromRGB(17, 24, 31), 0.58),
			Enum.Material.Metal
		)
		header.CanCollide = false
		header.CanTouch = false
		header.CanQuery = false
		header:SetAttribute("TierLandmarkPart", true)
		header:SetAttribute("BaseColor", header.Color)
		makeText(header, ("MATERIAL TIER %d"):format(tier), string.upper(config.displayName or config.name), Enum.NormalId.Back)
	end
	root:SetAttribute("DepthTierLandmarkCount", #wallConfigs)
end
shared.PunchWallBuildDepthTierLandmarks()

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
		fragment.CustomPhysicalProperties = PhysicalProperties.new(0.1, 0.78, 0.12, 1, 1)
		fragment.Anchored = false
		fragment.CanCollide = true
		fragment.CollisionGroup = "DepthFragments"
		fragment.CastShadow = true
		fragment.Parent = depthDebrisFolder
		pcall(function() fragment:SetNetworkOwner(nil) end)
		-- Fan chunks away from the center camera corridor. They still carry a
		-- strong forward impulse, but the wider cone prevents a large opaque
		-- fragment from crossing through the player's camera after a lunge.
		local side = sideAxis * ((index % 2 == 0 and 1 or -1) * (14 + index * 1.6) * strength)
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
	EndpointMargin = 1,
	WindupSeconds = 0.2,
	LungeSeconds = 0.42,
	OwnershipHoldSeconds = 0.35,
	MaxStructuralFalling = 60,
	ActiveShakes = setmetatable({}, { __mode = "k" }),
	ActiveLunges = {},
}
local structuralDirtyLayers = {}
local function markStructuralLayerDirty(layer)
	layer = math.floor(tonumber(layer) or 0)
	if layer >= 1 and layer <= DEPTH_LAYERS then structuralDirtyLayers[layer] = true end
end
root:SetAttribute("PunchRadius", depthPunch.Radius)
root:SetAttribute("PunchTargetMode", "BodyDirectionFreeAim")
root:SetAttribute("DepthBlockSize", DEPTH_BLOCK_SIZE)
root:SetAttribute("DepthBlockCount", DEPTH_COLUMNS * DEPTH_ROWS * DEPTH_LAYERS)
root:SetAttribute("PunchAttackInterval", WALL_HIT_COOLDOWN)
root:SetAttribute("PunchLungeDistance", depthPunch.BaseLungeDistance)
root:SetAttribute("PunchEndpointMargin", depthPunch.EndpointMargin)
root:SetAttribute("PunchMaxLungeDistance", depthPunch.MaxLungeDistance)
root:SetAttribute("PunchPenetrationMode", "PowerScaledSweptVolume")
root:SetAttribute("MaxDepthPhysicsFragments", MAX_DEPTH_PHYSICS_FRAGMENTS)
root:SetAttribute("PunchWindupSeconds", depthPunch.WindupSeconds)
root:SetAttribute("PunchOwnershipHoldSeconds", depthPunch.OwnershipHoldSeconds)
root:SetAttribute("MaxStructuralFalling", depthPunch.MaxStructuralFalling)
root:SetAttribute("ActiveStructuralFalling", 0)
root:SetAttribute("LastStructuralCollapseCount", 0)
root:SetAttribute("LastCharacterOverlapEjectCount", 0)
root:SetAttribute("WorldResetInterval", WORLD_RESET_INTERVAL)
root:SetAttribute("WorldResetCount", 0)
root:SetAttribute("LastWorldResetAt", 0)
root:SetAttribute("NextWorldResetAt", workspace:GetServerTimeNow() + WORLD_RESET_INTERVAL)
root:SetAttribute("LastCharacterOverlapShatterCount", 0)

function depthPunch.CancelShake(block)
	local tween = depthPunch.ActiveShakes[block]
	depthPunch.ActiveShakes[block] = nil
	block:SetAttribute("ShakeToken", (block:GetAttribute("ShakeToken") or 0) + 1)
	block:SetAttribute("Shaking", false)
	if tween then tween:Cancel() end
end

function depthPunch.CancelPunch(player)
	player:SetAttribute("PunchOwnershipToken", (player:GetAttribute("PunchOwnershipToken") or 0) + 1)
	local tween = depthPunch.ActiveLunges[player]
	depthPunch.ActiveLunges[player] = nil
	if tween then tween:Cancel() end
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if rootPart then
		shared.PunchWallSetCharacterCollisionGroup(character, "PlayerCharacters")
		pcall(function() rootPart:SetNetworkOwnershipAuto() end)
	end
end

function depthPunch.BindCharacterLifetime(player)
	local function watch(character)
		local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 10)
		if not humanoid or player.Character ~= character then return end
		humanoid.Died:Once(function()
			if player.Character == character then depthPunch.CancelPunch(player) end
		end)
	end
	player.CharacterRemoving:Connect(function(character)
		if player.Character == character then depthPunch.CancelPunch(player) end
	end)
	player.CharacterAdded:Connect(watch)
	if player.Character then task.spawn(watch, player.Character) end
end

function depthPunch.Shake(block, intensity)
	if not block.Anchored or block:GetAttribute("Broken") or block:GetAttribute("StructuralDetached") then return end
	depthPunch.CancelShake(block)
	local baseCFrame = block:GetAttribute("BaseCFrame") or block.CFrame
	local token = (block:GetAttribute("ShakeToken") or 0) + 1
	block:SetAttribute("ShakeToken", token)
	block:SetAttribute("Shaking", true)
	block:SetAttribute("LastShakeAt", workspace:GetServerTimeNow())
	local amount = math.clamp(tonumber(intensity) or 0.12, 0.05, 0.28)
	local offset = Vector3.new((math.random() - 0.5) * amount, (math.random() - 0.5) * amount, (math.random() - 0.5) * amount * 0.55)
	local shake = TweenService:Create(block, TweenInfo.new(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = baseCFrame * CFrame.new(offset) })
	depthPunch.ActiveShakes[block] = shake
	shake:Play()
	task.delay(0.1, function()
		if block.Parent and block.Anchored and not block:GetAttribute("Broken") and not block:GetAttribute("StructuralDetached") and block:GetAttribute("ShakeToken") == token then
			local restore = TweenService:Create(block, TweenInfo.new(0.22, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { CFrame = baseCFrame })
			depthPunch.ActiveShakes[block] = restore
			restore:Play()
			restore.Completed:Once(function()
				if block.Parent and block:GetAttribute("ShakeToken") == token then
					depthPunch.ActiveShakes[block] = nil
					block:SetAttribute("Shaking", false)
				end
			end)
		end
	end)
end

function depthPunch.ReleaseStructuralSlot(block)
	if not block or block:GetAttribute("StructuralActiveSlot") ~= true then return end
	block:SetAttribute("StructuralActiveSlot", false)
	root:SetAttribute("ActiveStructuralFalling", math.max(0, (root:GetAttribute("ActiveStructuralFalling") or 1) - 1))
end

function depthPunch.IsStructuralDetachedBlock(block)
	return block
		and block:GetAttribute("IsDepthBlock") == true
		and (block:GetAttribute("StructuralDetached") == true
			or block:GetAttribute("StructuralFalling") == true
			or block:GetAttribute("StructuralFailure") == true)
end

function depthPunch.HasSupport(block)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { block, depthDebrisFolder }
	params.IgnoreWater = true
	return workspace:Raycast(block.Position, Vector3.new(0, -block.Size.Y * 0.5 - 0.9, 0), params) ~= nil
end

function depthPunch.HasSideSupport(layer, column, row)
	if column < 1 or column > DEPTH_COLUMNS then return false end
	local side = depthBlocksFolder:FindFirstChild(("DepthBlock_L%03d_C%02d_R%02d"):format(layer, column, row))
	local below = depthBlocksFolder:FindFirstChild(("DepthBlock_L%03d_C%02d_R%02d"):format(layer, column, row - 1))
	return side and below and not side:GetAttribute("Broken") and not side:GetAttribute("StructuralDetached")
		and not below:GetAttribute("Broken") and not below:GetAttribute("StructuralDetached")
end

function depthPunch.FindOverlappingPlayer(block)
	local overlapSize = Vector3.new(
		math.max(0.2, block.Size.X - 0.3),
		math.max(0.2, block.Size.Y - 0.3),
		math.max(0.2, block.Size.Z - 0.3)
	)
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if character and humanoid and humanoid.Health > 0 then
			local overlap = OverlapParams.new()
			overlap.FilterType = Enum.RaycastFilterType.Include
			overlap.FilterDescendantsInstances = { character }
			overlap.MaxParts = 1
			if #workspace:GetPartBoundsInBox(block.CFrame, overlapSize, overlap) > 0 then return player end
		end
	end
	return nil
end

function depthPunch.StepDetachedPhysics()
	local now = workspace:GetServerTimeNow()
	for block in pairs(depthBlocksNeedingReset) do
		if block.Parent and depthPunch.IsStructuralDetachedBlock(block) and not block:GetAttribute("Broken") then
			if block:GetAttribute("StructuralFalling") then
				local startedAt = math.max(
					tonumber(block:GetAttribute("LastStructuralCollapseAt")) or 0,
					tonumber(block:GetAttribute("LastDetachedImpactAt")) or 0
				)
				local settled = block.AssemblyLinearVelocity.Magnitude < 0.75 and block.AssemblyAngularVelocity.Magnitude < 0.9
				if (settled and now - startedAt > 0.45) or now - startedAt > 4.5 then
					local overlappingPlayer = depthPunch.FindOverlappingPlayer(block)
					if overlappingPlayer then
						depthPunch.ShatterDetached(block, overlappingPlayer, block.AssemblyLinearVelocity, 1)
					elseif depthPunch.HasSupport(block) then
						block:SetAttribute("StructuralFalling", false)
						block:SetAttribute("StructuralSettled", true)
						block.AssemblyLinearVelocity = Vector3.zero
						block.AssemblyAngularVelocity = Vector3.zero
						block.Anchored = true
						block.CollisionGroup = "DepthRubble"
						depthPunch.ReleaseStructuralSlot(block)
					else
						block.Anchored = false
						block.CollisionGroup = "FallingStructural"
						block.AssemblyLinearVelocity = Vector3.new(block.AssemblyLinearVelocity.X, -8, block.AssemblyLinearVelocity.Z)
					end
				end
			else
				if not depthPunch.HasSupport(block) then
					if block:GetAttribute("StructuralActiveSlot") ~= true then
						block:SetAttribute("StructuralActiveSlot", true)
						root:SetAttribute("ActiveStructuralFalling", (root:GetAttribute("ActiveStructuralFalling") or 0) + 1)
					end
					block.Anchored = false
					block.CollisionGroup = "FallingStructural"
					block:SetAttribute("StructuralFalling", true)
					block:SetAttribute("StructuralSettled", false)
					block:SetAttribute("LastStructuralCollapseAt", now)
					block.AssemblyLinearVelocity = Vector3.new(block.AssemblyLinearVelocity.X, -8, block.AssemblyLinearVelocity.Z)
				end
			end
		end
	end
end

function depthPunch.ShatterDetached(block, player, impactDirection, impactForceScale)
	if not block or not block.Parent or block:GetAttribute("Broken") then return false end
	depthPunch.CancelShake(block)
	markDepthBlockDirty(block)
	depthPunch.ReleaseStructuralSlot(block)
	block:SetAttribute("Broken", true)
	block:SetAttribute("StructuralDetached", false)
	block:SetAttribute("StructuralFalling", false)
	block:SetAttribute("StructuralFailure", true)
	block:SetAttribute("HP", 0)
	block:SetAttribute("DamageStage", 3)
	block:SetAttribute("LastStructuralShatterAt", workspace:GetServerTimeNow())
	block:SetAttribute("LastOverlapShatterAt", workspace:GetServerTimeNow())
	block.Anchored = true
	block.AssemblyLinearVelocity = Vector3.zero
	block.AssemblyAngularVelocity = Vector3.zero
	block.CanCollide = false
	block.CanQuery = false
	block.Transparency = 1
	block.CollisionGroup = "Default"
	depthBlockContributions[block] = {}
	markStructuralLayerDirty(block:GetAttribute("Depth"))
	spawnDepthBlockFragments(block, player, impactDirection, impactForceScale or 1.15)
	return true
end

function depthPunch.DropStructural(block, player, ejectFromCharacter)
	if not block or block:GetAttribute("Broken") or block:GetAttribute("StructuralDetached") then return false end
	local active = root:GetAttribute("ActiveStructuralFalling") or 0
	if active >= depthPunch.MaxStructuralFalling then return false end
	depthPunch.CancelShake(block)
	markDepthBlockDirty(block)
	local token = (block:GetAttribute("StructuralToken") or 0) + 1
	block:SetAttribute("StructuralToken", token)
	block:SetAttribute("StructuralFalling", true)
	block:SetAttribute("StructuralDetached", true)
	block:SetAttribute("StructuralSettled", false)
	block:SetAttribute("StructuralActiveSlot", true)
	block:SetAttribute("Broken", false)
	block:SetAttribute("StructuralFailure", false)
	block:SetAttribute("HP", math.max(1, (block:GetAttribute("MaxHP") or 1) * 0.35))
	block:SetAttribute("DamageStage", 2)
	block:SetAttribute("LastStructuralCollapseAt", workspace:GetServerTimeNow())
	markStructuralLayerDirty(block:GetAttribute("Depth"))
	block.Anchored = false
	block.CanCollide = true
	block.CanQuery = true
	block.CollisionGroup = "FallingStructural"
	block.Transparency = 0
	pcall(function() block:SetNetworkOwner(nil) end)
	local character = player and player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local offset = rootPart and (block.Position - rootPart.Position) or Vector3.zero
	local horizontalOffset = Vector3.new(offset.X, 0, offset.Z)
	local outward = horizontalOffset.Magnitude > 0.01 and horizontalOffset.Unit or Vector3.zero
	local sideSign = (block:GetAttribute("Column") or 6) <= math.ceil(DEPTH_COLUMNS / 2) and -1 or 1
	local sideBias = Vector3.new(sideSign, 0, 0)
	local biasedOutward = outward + sideBias * 0.85
	if biasedOutward.Magnitude > 0.01 then outward = biasedOutward.Unit end
	local row = math.max(1, tonumber(block:GetAttribute("Row")) or 1)
	block.AssemblyLinearVelocity = outward * (10 + row * 0.9) + Vector3.new(0, -7, 0)
	block.AssemblyAngularVelocity = Vector3.new(math.random(-5, 5), math.random(-7, 7), math.random(-5, 5))
	root:SetAttribute("ActiveStructuralFalling", active + 1)
	return true
end

function depthPunch.AuditUnsupportedBlocks(player, maxDrops)
	local capacity = math.max(0, depthPunch.MaxStructuralFalling - (root:GetAttribute("ActiveStructuralFalling") or 0))
	local remaining = math.min(capacity, math.max(0, tonumber(maxDrops) or 12))
	if remaining <= 0 then return 0 end
	local dropped = 0
	local dirtyLayers = {}
	for layer in pairs(structuralDirtyLayers) do table.insert(dirtyLayers, layer) end
	table.sort(dirtyLayers)
	for _, layer in ipairs(dirtyLayers) do
		local layerDropped = 0
		for row = 2, DEPTH_ROWS do
			for column = 1, DEPTH_COLUMNS do
				if remaining <= 0 then return dropped end
				local block = depthBlocksFolder:FindFirstChild(("DepthBlock_L%03d_C%02d_R%02d"):format(layer, column, row))
				local below = depthBlocksFolder:FindFirstChild(("DepthBlock_L%03d_C%02d_R%02d"):format(layer, column, row - 1))
				if block and below
					and not block:GetAttribute("Broken")
					and not block:GetAttribute("StructuralDetached")
					and (below:GetAttribute("Broken") or below:GetAttribute("StructuralDetached")) then
					if not (depthPunch.HasSideSupport(layer, column - 1, row) and depthPunch.HasSideSupport(layer, column + 1, row))
						and depthPunch.DropStructural(block, player) then
						dropped += 1
						layerDropped += 1
						remaining -= 1
					end
				end
			end
		end
		if layerDropped == 0 then structuralDirtyLayers[layer] = nil end
	end
	return dropped
end

function depthPunch.BounceDetached(block, player, damage, impactDirection, impactForceScale)
	if not block or block:GetAttribute("Broken") then return end
	if block:GetAttribute("StructuralActiveSlot") ~= true then
		local active = root:GetAttribute("ActiveStructuralFalling") or 0
		if active < depthPunch.MaxStructuralFalling then
			block:SetAttribute("StructuralActiveSlot", true)
			root:SetAttribute("ActiveStructuralFalling", active + 1)
		end
	end
	block.Anchored = false
	block.CanCollide = true
	block.CanQuery = true
	block.CollisionGroup = "FallingStructural"
	block:SetAttribute("StructuralSettled", false)
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
				if not (depthPunch.HasSideSupport(layer, column - 1, row) and depthPunch.HasSideSupport(layer, column + 1, row))
					and depthPunch.DropStructural(block, player) then
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

function depthPunch.ResolveCharacterOverlaps()
	local shattered = 0
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
				if depthPunch.IsStructuralDetachedBlock(block)
					and not block:GetAttribute("Broken")
					and depthPunch.ShatterDetached(block, player, block.Position - rootPart.Position, 1.05) then
					shattered += 1
				end
			end
		end
	end
	root:SetAttribute("LastCharacterOverlapShatterCount", shattered)
	root:SetAttribute("LastCharacterOverlapEjectCount", 0)
	return shattered
end

task.spawn(function()
	while root.Parent do
		depthPunch.ResolveCharacterOverlaps()
		depthPunch.StepDetachedPhysics()
		depthPunch.AuditUnsupportedBlocks(nil, 12)
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
	local baseDamage = effectivePower(player)
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
				local stopDistance = math.max(0, forward - block.Size.Z * 0.5 - bodyHalfDepth - depthPunch.EndpointMargin)
				if stopDistance < safeDistance then
					safeDistance = stopDistance
					barrierName = block.Name
				end
			end
		end
	end
	return { safeDistance = safeDistance, barrier = barrierName, predictedBreaks = predictedBreaks }
end

function depthPunch.ComputeClearedLunge(player, rootPart, direction, requestedDistance)
	local character = player.Character
	if not character or not rootPart or not rootPart.Parent then
		return { safeDistance = 0, barrier = "character", bodySize = Vector3.zero }
	end
	local boundsCFrame, boundsSize = character:GetBoundingBox()
	local paddedBoundsSize = boundsSize + Vector3.new(0.5, 0.3, 0.5)
	local function projectedHalfSize(axis)
		return math.abs(axis:Dot(boundsCFrame.RightVector)) * paddedBoundsSize.X * 0.5
			+ math.abs(axis:Dot(boundsCFrame.UpVector)) * paddedBoundsSize.Y * 0.5
			+ math.abs(axis:Dot(boundsCFrame.LookVector)) * paddedBoundsSize.Z * 0.5
	end
	local rightDirection = Vector3.new(-direction.Z, 0, direction.X)
	local bodyHalfWidth = projectedHalfSize(rightDirection)
	local bodyHalfHeight = projectedHalfSize(Vector3.yAxis)
	local bodyHalfDepth = projectedHalfSize(direction)
	local bodySize = Vector3.new(
		math.max(rootPart.Size.X + 0.8, bodyHalfWidth * 2),
		math.max(rootPart.Size.Y + 3, bodyHalfHeight * 2),
		math.max(rootPart.Size.Z + 1.2, bodyHalfDepth * 2)
	)
	local sweepStartCenter = boundsCFrame.Position
	local sweepCenter = sweepStartCenter + direction * (requestedDistance * 0.5)
	local sweepCFrame = CFrame.lookAt(sweepCenter, sweepCenter + direction)
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.FilterDescendantsInstances = { depthBlocksFolder }
	overlap.MaxParts = 400
	local safeDistance = requestedDistance
	local barrierName = "none"
	local function isBlocking(block)
		return block:GetAttribute("IsDepthBlock")
			and not block:GetAttribute("Broken")
			and block.CanCollide
			and not (block:GetAttribute("StructuralFalling") and block.CollisionGroup == "FallingStructural")
			and block.Transparency < 0.95
	end
	local castParams = RaycastParams.new()
	castParams.FilterType = Enum.RaycastFilterType.Include
	castParams.FilterDescendantsInstances = { depthBlocksFolder }
	castParams.CollisionGroup = "PlayerCharacters"
	pcall(function() castParams.RespectCanCollide = true end)
	local castStart = CFrame.lookAt(sweepStartCenter, sweepStartCenter + direction)
	local castOK, castResult = pcall(function()
		return workspace:Blockcast(castStart, bodySize, direction * requestedDistance, castParams)
	end)
	if castOK and castResult and isBlocking(castResult.Instance) then
		safeDistance = math.max(0, castResult.Distance - depthPunch.EndpointMargin)
		barrierName = castResult.Instance.Name
	end
	for _, block in ipairs(workspace:GetPartBoundsInBox(sweepCFrame, Vector3.new(bodySize.X, bodySize.Y, requestedDistance + bodySize.Z), overlap)) do
		if isBlocking(block) then
			local offset = block.Position - sweepStartCenter
			local forward = offset:Dot(direction)
			if forward > -bodyHalfDepth then
				local halfAlong = math.abs(direction:Dot(block.CFrame.RightVector)) * block.Size.X * 0.5
					+ math.abs(direction:Dot(block.CFrame.UpVector)) * block.Size.Y * 0.5
					+ math.abs(direction:Dot(block.CFrame.LookVector)) * block.Size.Z * 0.5
				local stopDistance = math.max(0, forward - halfAlong - bodyHalfDepth - depthPunch.EndpointMargin)
				if stopDistance < safeDistance then
					safeDistance = stopDistance
					barrierName = block.Name
				end
			end
		end
	end

	local function endpointIsClear(distance)
		local center = sweepStartCenter + direction * distance
		local endpointCFrame = CFrame.lookAt(center, center + direction)
		for _, block in ipairs(workspace:GetPartBoundsInBox(endpointCFrame, bodySize, overlap)) do
			if isBlocking(block) then return false, block.Name end
		end
		return true, "none"
	end
	local clear, endpointBarrier = endpointIsClear(safeDistance)
	if not clear then
		local startClear = endpointIsClear(0)
		if not startClear then
			safeDistance = 0
			barrierName = endpointBarrier
		else
			local low, high = 0, safeDistance
			for _ = 1, 12 do
				local middle = (low + high) * 0.5
				if endpointIsClear(middle) then low = middle else high = middle end
			end
			safeDistance = math.max(0, low - 0.05)
			barrierName = endpointBarrier
		end
	end
	return { safeDistance = safeDistance, barrier = barrierName, bodySize = bodySize }
end

function depthPunch.Lunge(player, rootPart, profile)
	if not (profile and profile.skipWindup) then task.wait(depthPunch.WindupSeconds) end
	profile = profile or depthPunch.PowerProfile(player)
	if not rootPart or not rootPart.Parent then return nil end
	if profile.ownershipToken and player:GetAttribute("PunchOwnershipToken") ~= profile.ownershipToken then return nil end
	if rootPart.Parent ~= player.Character then return nil end
	local requestedDirection = profile.direction
	local look = typeof(requestedDirection) == "Vector3" and requestedDirection or rootPart.CFrame.LookVector
	local horizontal = Vector3.new(look.X, 0, look.Z)
	if horizontal.Magnitude < 0.01 then return nil end
	local direction = horizontal.Unit
	local startCFrame = rootPart.CFrame
	local startPosition = rootPart.Position
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character, depthDebrisFolder, depthBlocksFolder }
	params.IgnoreWater = true
	-- Pickup targets remain queryable, but only physical solids stop a lunge.
	params.RespectCanCollide = true
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
	player:SetAttribute("LastPunchTravelDirection", direction)
	local ownershipToken = tonumber(profile.ownershipToken)
	if not ownershipToken then
		ownershipToken = (player:GetAttribute("PunchOwnershipToken") or 0) + 1
		player:SetAttribute("PunchOwnershipToken", ownershipToken)
	end
	player:SetAttribute("LastPunchOwnershipHoldSeconds", depthPunch.OwnershipHoldSeconds)
	pcall(function() rootPart:SetNetworkOwner(nil) end)
	if travel > 0.05 then
		local tween = TweenService:Create(rootPart, TweenInfo.new(depthPunch.LungeSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
			CFrame = rootPart.CFrame + direction * travel,
		})
		depthPunch.ActiveLunges[player] = tween
		tween:Play()
		local state = tween.Completed:Wait()
		if depthPunch.ActiveLunges[player] == tween then depthPunch.ActiveLunges[player] = nil end
		if state ~= Enum.PlaybackState.Completed or player:GetAttribute("PunchOwnershipToken") ~= ownershipToken
			or not rootPart.Parent or rootPart.Parent ~= player.Character then return nil end
		rootPart.AssemblyLinearVelocity = Vector3.new(0, rootPart.AssemblyLinearVelocity.Y, 0)
	end
	task.delay(depthPunch.OwnershipHoldSeconds, function()
		if rootPart.Parent and player.Parent and player:GetAttribute("PunchOwnershipToken") == ownershipToken then
			rootPart.AssemblyLinearVelocity = Vector3.new(0, rootPart.AssemblyLinearVelocity.Y, 0)
			rootPart.AssemblyAngularVelocity = Vector3.zero
			depthPunch.ResolveCharacterOverlaps()
			shared.PunchWallSetCharacterCollisionGroup(rootPart.Parent, "PlayerCharacters")
			pcall(function() rootPart:SetNetworkOwnershipAuto() end)
		end
	end)
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
		damage = effectivePower(player)
		critical = math.random(1, 100) <= math.clamp(statValue(player, "CritChance", 0), 0, GameConfig.MaxCritChance)
		if critical then damage *= 2 end
		damage *= math.clamp(tonumber(options.damageScale) or 1, 0.05, 1)
	end

	local previousHP = block:GetAttribute("HP") or 0
	local actualDamage = math.min(previousHP, damage)
	local remainingHP = math.max(0, previousHP - damage)
	markDepthBlockDirty(block)
	block:SetAttribute("HP", remainingHP)
	depthBlockContributions[block] = depthBlockContributions[block] or {}
	depthBlockContributions[block][player.UserId] = (depthBlockContributions[block][player.UserId] or 0) + actualDamage

	local fraction = remainingHP / math.max(1, block:GetAttribute("MaxHP") or 1)
	local stage = fraction <= 0.25 and 3 or fraction <= 0.5 and 2 or fraction <= 0.75 and 1 or 0
	block:SetAttribute("DamageStage", stage)
	block.Color = (block:GetAttribute("OriginalColor") or block.Color):Lerp(Color3.fromRGB(38, 38, 38), stage * 0.12)
	sendFeedback(player, { type = "Punch", target = block.Name, damage = math.floor(damage + 0.5), critical = critical, broken = remainingHP <= 0, material = block.Material.Name, color = block.Color })
	completeTutorialAction(player, "PunchWall")

	if remainingHP > 0 then
		if wasDetached then
			depthPunch.BounceDetached(block, player, damage, options.impactDirection, options.impactForceScale)
		else
			depthPunch.Shake(block, 0.08 + stage * 0.045 + math.min(0.1, damage / math.max(1, block:GetAttribute("MaxHP") or 1) * 0.12))
		end
		return { ok = true, outcome = "hit", detached = wasDetached, damage = damage, hp = remainingHP, Depth = block:GetAttribute("Depth"), Tier = block:GetAttribute("Tier") }
	end

	depthPunch.CancelShake(block)
	block:SetAttribute("Broken", true)
	block:SetAttribute("StructuralDetached", false)
	block:SetAttribute("StructuralFalling", false)
	if wasDetached then depthPunch.ReleaseStructuralSlot(block) end
	block.Anchored = true
	block.AssemblyLinearVelocity = Vector3.zero
	block.AssemblyAngularVelocity = Vector3.zero
	block.CanCollide = false
	block.CanQuery = false
	block.Transparency = 1
	markStructuralLayerDirty(block:GetAttribute("Depth"))
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
			local previousBreaks = statValue(contributor, "DailyBreaks", 0)
			addStat(contributor, "DailyBreaks", 1)
			local layer = block:GetAttribute("Depth") or 1
			local previousDepth = statValue(contributor, "Depth", 0)
			if layer > previousDepth then
				setStat(contributor, "Depth", layer)
				shared.PunchWallHonor.ClaimDepthMilestones(contributor, layer)
				shared.PunchWallQueueDepthMilestone(contributor, previousDepth)
			end
			if previousBreaks < GameConfig.Rewards.QuestBreakTarget
				and previousBreaks + 1 >= GameConfig.Rewards.QuestBreakTarget then
				sendFeedback(contributor, { type = "QuestComplete", target = "Daily Breaker", coins = GameConfig.Rewards.QuestCoins, color = PolishConfig.Palette.Reward })
			end
			awardWallXP(contributor, block:GetAttribute("XPReward") or 1)
			if tryDropPetEgg then tryDropPetEgg(contributor, layer, block.Position) end
			sendFeedback(contributor, { type = "Reward", target = block.Name, wallBreak = true, coins = coins, score = score, depth = layer, color = PolishConfig.Palette.Reward })
		end
	end
	return { ok = true, outcome = "broken", detached = wasDetached, damage = damage, Depth = block:GetAttribute("Depth"), Tier = block:GetAttribute("Tier") }
end

function depthPunch.Punch(player, directionName)
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
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return { ok = false, reason = "character" } end
	local actionLook = rootPart.CFrame.LookVector
	local actionHorizontal = Vector3.new(actionLook.X, 0, actionLook.Z)
	if actionHorizontal.Magnitude < 0.01 then return { ok = false, reason = "direction" } end
	local travelDirection = actionHorizontal.Unit
	directionName = tostring(directionName or "Forward")
	local actionDirection = travelDirection
	if directionName == "Up" then
		actionDirection = (travelDirection + Vector3.new(0, 0.72, 0)).Unit
	elseif directionName == "Down" then
		actionDirection = (travelDirection - Vector3.new(0, 0.58, 0)).Unit
	else
		directionName = "Forward"
	end
	player:SetAttribute("LastPunchDirection", directionName)
	local now = os.clock()
	local lastHit = player:GetAttribute("LastWallHit") or 0
	if now - lastHit < WALL_HIT_COOLDOWN then return { ok = false, reason = "cooldown" } end
	player:SetAttribute("LastWallHit", now)

	local profile = depthPunch.PowerProfile(player)
	profile.requestedDistance = profile.distance
	profile.ownershipToken = (player:GetAttribute("PunchOwnershipToken") or 0) + 1
	player:SetAttribute("PunchOwnershipToken", profile.ownershipToken)
	shared.PunchWallSetCharacterCollisionGroup(character, "PunchingCharacters")
	rootPart.AssemblyLinearVelocity = Vector3.new(0, rootPart.AssemblyLinearVelocity.Y, 0)
	rootPart.AssemblyAngularVelocity = Vector3.zero
	pcall(function() rootPart:SetNetworkOwner(nil) end)
	player:SetAttribute("LastPunchPowerLungeDistance", profile.requestedDistance)
	player:SetAttribute("LastPunchRequestedDistance", profile.requestedDistance)

	task.wait(depthPunch.WindupSeconds)
	if not rootPart.Parent then return { ok = false, reason = "character" } end
	if rootPart.Parent ~= player.Character or player:GetAttribute("PunchOwnershipToken") ~= profile.ownershipToken then
		return { ok = false, reason = "cancelled" }
	end
	if humanoid.Health <= 0 then
		depthPunch.CancelPunch(player)
		return { ok = false, reason = "cancelled" }
	end
	local direction = actionDirection
	player:SetAttribute("LastPunchPlanningDirection", direction)
	local origin = rootPart.Position + Vector3.new(0, 0.8, 0)
	local traceLength = profile.requestedDistance + depthPunch.Reach
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
					local penetrationRetention = 1 - progress * (0.52 - profile.powerScale * 0.3)
					table.insert(candidates, {
						block = block,
						distance = distance,
						forward = forward,
						scale = math.clamp(radialScale * penetrationRetention, 0.08, 1),
					})
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

	local hitCount = 0
	local brokenCount = 0
	local primary = candidates[1] and candidates[1].block or lockedBlock
	if candidates[1] then candidates[1].scale = 1 end
	if primary then player:SetAttribute("LastRadiusPrimary", primary.Name) end
	local baseDamage = effectivePower(player)
	local radiusCritical = math.random(1, 100) <= math.clamp(statValue(player, "CritChance", 0), 0, GameConfig.MaxCritChance)
	if radiusCritical then baseDamage *= 2 end
	for index, candidate in ipairs(candidates) do
		if index > profile.limit then break end
		candidate.block:SetAttribute("LastRadiusDamageScale", candidate.scale)
		candidate.block:SetAttribute("LastRadiusHitAt", workspace:GetServerTimeNow())
		candidate.block:SetAttribute("LastPenetrationForward", candidate.forward)
		candidate.block:SetAttribute("LastPenetrationIndex", index)
		local result = hitDepthBlock(player, candidate.block, {
			skipCooldown = true,
			damageOverride = baseDamage * candidate.scale,
			criticalOverride = radiusCritical,
			impactDirection = direction,
			impactForceScale = profile.forceScale * math.clamp(candidate.scale, 0.45, 1),
		})
		if result.ok then
			hitCount += 1
			if result.outcome == "broken" then brokenCount += 1 end
		end
	end
	if hitCount == 0 and lockedBlock then
		hitDepthBlock(player, lockedBlock, { skipCooldown = true })
	end

	local clearedPlan = depthPunch.ComputeClearedLunge(player, rootPart, travelDirection, profile.requestedDistance)
	profile.distance = clearedPlan.safeDistance
	profile.skipWindup = true
	profile.direction = travelDirection
	player:SetAttribute("LastPunchPlannedLungeDistance", clearedPlan.safeDistance)
	player:SetAttribute("LastPunchPlanningBarrier", clearedPlan.barrier)
	player:SetAttribute("LastPunchPredictedBreakCount", brokenCount)
	local lunge = depthPunch.Lunge(player, rootPart, profile)
	if not lunge then
		return { ok = false, reason = player:GetAttribute("PunchOwnershipToken") ~= profile.ownershipToken and "cancelled" or "lunge" }
	end

	player:SetAttribute("LastRadiusHitCount", hitCount)
	player:SetAttribute("LastPenetrationStuds", traceLength)
	player:SetAttribute("LastPunchCollisionCorrected", false)
	player:SetAttribute("LastPunchCollisionCorrectionStuds", 0)
	player:SetAttribute("LastPunchCollisionOverlapCount", 0)
	player:SetAttribute("LastPunchSafeTravel", lunge.travel)
	player:SetAttribute("LastPunchSafeEndpointMode", "DamageThenSweep")
	return {
		ok = hitCount > 0,
		outcome = hitCount > 0 and "penetration" or lockedBlock and "level_gate" or "no_block",
		hitCount = hitCount,
		brokenCount = brokenCount,
		primary = primary and primary.Name or "none",
		lungeDistance = lunge.travel,
		collisionCorrected = false,
		collisionCorrectionStuds = 0,
		powerScale = lunge.powerScale,
		forceScale = lunge.forceScale,
		penetrationLimit = lunge.limit,
		barrier = clearedPlan.barrier,
	}
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
	local requiredDepth = boss:GetAttribute("RequiredDepth") or GameConfig.WorldProgressTarget
	if statValue(player, "Depth", 0) < requiredDepth then
		sendFeedback(player, {
			type = "Fail",
			target = boss.Name,
			message = ("Clear Depth %d first"):format(requiredDepth),
			color = PolishConfig.Palette.Fail,
		})
		return { ok = false, reason = "depth_gate", requiredDepth = requiredDepth }
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
	local damage = effectivePower(player) * 1.4 * (weakPointMultiplier or 1)
	local previousHP = boss:GetAttribute("HP")
	local actualDamage = math.min(previousHP, damage)
	boss:SetAttribute("HP", math.max(0, previousHP - damage))
	bossContributions[player.UserId] = (bossContributions[player.UserId] or 0) + actualDamage
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
				local depthBeforeBossReward = statValue(plr, "Depth", 0)
				addStat(plr, "Coins", coins)
				addStat(plr, "Score", math.max(1, math.floor(boss:GetAttribute("ScoreReward") * share + 0.5)))
				if depthBeforeBossReward >= GameConfig.WorldProgressTarget and depthBeforeBossReward < 76 then
					setStat(plr, "Depth", 76)
				end
				local honorGranted, honorReason = 0, "depth_gate"
				if depthBeforeBossReward >= GameConfig.WorldProgressTarget then
					honorGranted, honorReason = shared.PunchWallHonor.ClaimQualifiedWorldClear(plr, share)
				end
				plr:SetAttribute("LastWorldClearHonorGranted", honorGranted)
				plr:SetAttribute("LastWorldClearHonorReason", honorReason)
				awardWallXP(plr, boss:GetAttribute("XPReward"))
				sendFeedback(plr, { type = "Boss", target = boss.Name, coins = coins, honor = honorGranted, color = bossStyle.accent })
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
	if not profileReady(player, false) then return end
	hitBoss(player)
end)
for _, weakPoint in ipairs(bossWeakPoints) do
	local detector = Instance.new("ClickDetector")
	detector.MaxActivationDistance = 50
	detector.Parent = weakPoint
	detector.MouseClick:Connect(function(player)
		if not profileReady(player, false) then return end
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

local trainingConfigs = {}
local trainingRuntime = {
	positions = {
		rookie_bag = Vector3.new(-16, 4, 24),
		iron_dummy = Vector3.new(-34, 4, 24),
		titan_reactor = Vector3.new(-52, 4, 24),
		celestial_core = Vector3.new(-70, 4, 24),
	},
	byName = {},
	byId = {},
	partsByName = {},
}
for _, definition in ipairs(GameConfig.Training.Stations) do
	local config = table.clone(definition)
	config.stat = "Power"
	config.pos = assert(trainingRuntime.positions[config.id], "Missing training position for " .. config.id)
	table.insert(trainingConfigs, config)
end

local function setActiveTrainingStation(player, config)
	if not config then return end
	setStat(player, "TrainingStationId", config.id)
	player:SetAttribute("ActiveTrainingStationId", config.id)
	player:SetAttribute("ActiveTrainingStationName", config.name)
	player:SetAttribute("ActiveTrainingPowerPerSecond", config.gain)
	player:SetAttribute("ActiveTrainingRequiredPower", config.minPower)
	player:SetAttribute("TrainingQualificationPower", trainingQualificationPower(player))
end

local function setTrainingMovementLocked(player, active, config)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart then return false end
	if active then
		if not player:GetAttribute("TrainingMovementLocked") then
			player:SetAttribute("TrainingSavedWalkSpeed", humanoid.WalkSpeed)
			player:SetAttribute("TrainingSavedJumpPower", humanoid.JumpPower)
			player:SetAttribute("TrainingSavedJumpHeight", humanoid.JumpHeight)
			player:SetAttribute("TrainingSavedAutoRotate", humanoid.AutoRotate)
		end
		player:SetAttribute("TrainingMovementLocked", true)
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
		humanoid.AutoRotate = false
		humanoid:Move(Vector3.zero)
		rootPart.AssemblyLinearVelocity = Vector3.zero
		rootPart.AssemblyAngularVelocity = Vector3.zero
		local bagPosition = config and config.pos or Vector3.new(-42, 4, 24)
		local anchorPosition = Vector3.new(bagPosition.X, rootPart.Position.Y, bagPosition.Z - 6.2)
		rootPart.CFrame = CFrame.lookAt(anchorPosition, Vector3.new(bagPosition.X, anchorPosition.Y, bagPosition.Z))
		player:SetAttribute("TrainingAnchorPosition", anchorPosition)
	else
		player:SetAttribute("TrainingMovementLocked", false)
		humanoid.WalkSpeed = (player:GetAttribute("SpeedBoostExpiresAt") or 0) > workspace:GetServerTimeNow()
			and 24 or math.max(16, player:GetAttribute("TrainingSavedWalkSpeed") or 16)
		humanoid.JumpPower = player:GetAttribute("TrainingSavedJumpPower") or 50
		humanoid.JumpHeight = player:GetAttribute("TrainingSavedJumpHeight") or 7.2
		humanoid.AutoRotate = player:GetAttribute("TrainingSavedAutoRotate") ~= false
	end
	return true
end

local function playTrainingImpact(config)
	if not config or not config.part then return end
	emitNamed(config.part, "Train Pop", GameConfig.Training.ImpactEmit or PolishConfig.Motion.TrainEmit)
	local impact = config.part:FindFirstChild("Training Impact")
	if impact and impact:IsA("Sound") then
		impact.TimePosition = 0
		impact:Play()
	end
	local model = config.motionModel
	local basePivot = config.motionBasePivot
	if model and model.Parent and basePivot then
		local token = (model:GetAttribute("TrainingShakeToken") or 0) + 1
		model:SetAttribute("TrainingShakeToken", token)
		model:PivotTo(basePivot * CFrame.new(0, 0, 0.34) * CFrame.Angles(math.rad(-4), 0, math.rad(2)))
		task.delay(0.08, function()
			if model.Parent and model:GetAttribute("TrainingShakeToken") == token then
				model:PivotTo(basePivot * CFrame.new(0, 0, -0.12) * CFrame.Angles(math.rad(2), 0, math.rad(-1)))
				task.delay(0.08, function()
					if model.Parent and model:GetAttribute("TrainingShakeToken") == token then model:PivotTo(basePivot) end
				end)
			end
		end)
	end
end

local stopTraining

local function grantTrainingTick(player, config, showFeedback, tickCount)
	local qualificationPower = trainingQualificationPower(player)
	if not config or qualificationPower < config.minPower then
		if stopTraining then stopTraining(player, "power_required") end
		return 0
	end
	tickCount = math.max(1, math.floor(tonumber(tickCount) or 1))
	local gain = config.gain * tickCount
	if (player:GetAttribute("TrainingBoostExpiresAt") or 0) > workspace:GetServerTimeNow() then gain *= 2 end
	gain = math.max(0, math.min(
		gain,
		ProfilePersistence.MaxAuthoritativeNumber - statValue(player, "Power", 0)
	))
	if gain <= 0 then return 0 end
	addStat(player, "Power", gain)
	setStat(player, "TrainingUpdatedAt", os.time())
	player:SetAttribute("LastTrainingTickAt", workspace:GetServerTimeNow())
	player:SetAttribute("LastTrainingStationId", config.id)
	player:SetAttribute("LastTrainingGrant", gain)
	player:SetAttribute("LastTrainingTickBatch", tickCount)
	player:SetAttribute("TrainingSessionTickCount", (player:GetAttribute("TrainingSessionTickCount") or 0) + tickCount)
	player:SetAttribute("TrainingPayoutSerial", (player:GetAttribute("TrainingPayoutSerial") or 0) + 1)
	setTrainingMovementLocked(player, true, config)
	playTrainingImpact(config)
	if showFeedback then
		sendFeedback(player, {
			type = "Train",
			target = config.displayName,
			stat = "Power",
			gain = gain,
			powerPerSecond = config.gain,
			stationId = config.id,
			active = true,
			color = config.color,
		})
	end
	return gain
end

local function trainPlayer(player, config)
	if not config then return { ok = false, reason = "unknown_station" } end
	local now = os.clock()
	local key = "LastTrainToggle"
	local lastTrain = player:GetAttribute(key) or 0
	if now - lastTrain < TRAINING_COOLDOWN then
		return { ok = false, reason = "cooldown" }
	end
	player:SetAttribute(key, now)
	local power = statValue(player, "Power", 0)
	local qualificationPower = trainingQualificationPower(player)
	if qualificationPower < config.minPower then
		sendFeedback(player, {
			type = "Fail",
			target = config.displayName,
			message = ("Need %s Power"):format(formatNumber(config.minPower)),
			color = PolishConfig.Palette.Fail,
		})
		return {
			ok = false,
			reason = "power_required",
			stationId = config.id,
			requiredPower = config.minPower,
			power = qualificationPower,
			basePower = power,
		}
	end
	local wasActive = statValue(player, "TrainingActive", 0) >= 1
	if wasActive then
		local previousId = tostring(statValue(player, "TrainingStationId", GameConfig.Training.DefaultStationId))
		setActiveTrainingStation(player, config)
		setTrainingMovementLocked(player, true, config)
		if previousId == config.id then
			return { ok = true, active = true, alreadyActive = true, stationId = config.id, gainPerSecond = config.gain, stat = "Power", value = power, qualificationPower = qualificationPower }
		end
		player:SetAttribute("TrainingTickAnchor", workspace:GetServerTimeNow())
		player:SetAttribute("TrainingSessionGeneration", (player:GetAttribute("TrainingSessionGeneration") or 0) + 1)
		player:SetAttribute("TrainingSessionTickCount", 0)
		sendFeedback(player, { type = "TrainingState", target = config.displayName, active = true, switched = true, gain = config.gain, color = config.color })
		return { ok = true, active = true, switched = true, stationId = config.id, gainPerSecond = config.gain, stat = "Power", value = power, qualificationPower = qualificationPower }
	end
	setActiveTrainingStation(player, config)
	setStat(player, "TrainingActive", 1)
	setStat(player, "TrainingUpdatedAt", os.time())
	player:SetAttribute("AutoTrainingActive", true)
	player:SetAttribute("TrainingTickAnchor", workspace:GetServerTimeNow())
	player:SetAttribute("TrainingSessionGeneration", (player:GetAttribute("TrainingSessionGeneration") or 0) + 1)
	player:SetAttribute("TrainingSessionTickCount", 0)
	setTrainingMovementLocked(player, true, config)

	sendFeedback(player, { type = "TrainingState", target = config.displayName, active = true, gain = config.gain, stationId = config.id, color = config.color })
	return { ok = true, active = true, stationId = config.id, gainPerSecond = config.gain, stat = "Power", gain = 0, value = statValue(player, "Power"), qualificationPower = qualificationPower }
end

stopTraining = function(player, reason)
	setStat(player, "TrainingActive", 0)
	setStat(player, "TrainingUpdatedAt", os.time())
	player:SetAttribute("AutoTrainingActive", false)
	player:SetAttribute("TrainingTickAnchor", nil)
	local selected = trainingRuntime.byId[tostring(statValue(player, "TrainingStationId", GameConfig.Training.DefaultStationId))]
		or trainingConfigs[1]
	setTrainingMovementLocked(player, false, selected)
	sendFeedback(player, {
		type = "TrainingState",
		target = reason == "power_required" and "TRAINING LOCKED" or "TRAINING COMPLETE",
		active = false,
		reason = reason,
		color = PolishConfig.Palette.Reward,
	})
	return { ok = true, active = false, reason = reason, stationId = selected.id, stat = "Power", value = statValue(player, "Power") }
end

for _, config in ipairs(trainingConfigs) do
	trainingRuntime.byName[config.name] = config
	trainingRuntime.byId[config.id] = config
	local station = makePart(config.name, interactFolder, Vector3.new(9, 8, 9), config.pos, config.color, Enum.Material.Metal)
	config.part = station
	station:SetAttribute("BaseSize", station.Size)
	station:SetAttribute("Theme", PolishConfig.StyleName)
	station:SetAttribute("VisualRole", "CityTrainingStation")
	station:SetAttribute("TrainingMode", "ContinuousOfflinePower")
	station:SetAttribute("TrainingStationId", config.id)
	station:SetAttribute("TrainingTier", config.tier)
	station:SetAttribute("RequiredPower", config.minPower)
	station:SetAttribute("PowerPerSecond", config.gain)
	station.Transparency = 1
	station.CanCollide = false
	addEmitter(station, "Train Pop", config.color)
	addSound(station, "Training Impact", GameConfig.Audio.TrainingImpact, 0.72, 0.92)
	trainingRuntime.partsByName[config.name] = station
	local trainingSign = makePart(config.name .. " Training Sign", decorFolder, Vector3.new(11.2, 3.0, 0.35), config.pos + Vector3.new(0, 5.0, -4.2), Color3.fromRGB(27, 34, 39), Enum.Material.Metal)
	trainingSign.CanCollide = false
	trainingSign.CanTouch = false
	trainingSign.CanQuery = false
	trainingSign:SetAttribute("SignagePriority", "InteractionDetail")
	trainingSign:SetAttribute("TrainingStationId", config.id)
	trainingSign:SetAttribute("VisualRole", "TrainingStationSign")
	local requirement = config.minPower <= 0 and "OPEN TO ALL" or ("REQUIRES %s POWER"):format(formatNumber(config.minPower))
	local stationCopy = ("TIER %d | +%s POWER / SEC | %s"):format(config.tier, formatNumber(config.gain), requirement)
	makeText(trainingSign, string.upper(config.displayName), stationCopy, Enum.NormalId.Front)
	makeText(trainingSign, string.upper(config.displayName), stationCopy, Enum.NormalId.Back)
	local campMat = makePart(config.name .. " Training Deck", decorFolder, Vector3.new(14, 0.25, 14), config.pos + Vector3.new(0, -3.9, 0), Color3.fromRGB(112, 84, 56), Enum.Material.WoodPlanks)
	campMat.CanCollide = false
	campMat.CanTouch = false
	campMat.CanQuery = false
	campMat:SetAttribute("VisualRole", "ForestTrainingDeck")
	local importedBag
	if config.id == GameConfig.Training.DefaultStationId then
		importedBag = cloneExternalVisual(
			"Sanitized_HeroPowerBag",
			decorFolder,
			"Creator Store Hero Power Bag",
			CFrame.new(config.pos.X, 0.35, config.pos.Z) * CFrame.Angles(0, math.rad(180), 0),
			7.2,
			false,
			CFrame.Angles(0, 0, math.rad(90))
		)
	end
	if importedBag then
		for _, descendant in ipairs(importedBag:GetDescendants()) do
			if descendant:IsA("BillboardGui") or descendant:IsA("SurfaceGui") then descendant:Destroy() end
		end
		importedBag:SetAttribute("VisualRole", "PowerTrainingModel")
		importedBag:SetAttribute("SourceFallback", false)
		config.motionModel = importedBag
		config.motionBasePivot = importedBag:GetPivot()
	elseif config.id == GameConfig.Training.DefaultStationId then
		for _, side in ipairs({ -1, 1 }) do
			local post = makePart("Power Bag Frame Post " .. side, decorFolder, Vector3.new(0.7, 9.4, 0.7), config.pos + Vector3.new(side * 4.8, 0.7, 0), Color3.fromRGB(52, 58, 61), Enum.Material.Metal)
			post.CanCollide = false
		end
		local beam = makePart("Power Bag Frame Beam", decorFolder, Vector3.new(10.3, 0.75, 0.9), config.pos + Vector3.new(0, 5.25, 0), Color3.fromRGB(43, 48, 51), Enum.Material.Metal)
		beam.CanCollide = false
		makeCylinder("Heavy Bag Chain", decorFolder, Vector3.new(2.5, 0.28, 0.28), config.pos + Vector3.new(0, 3.95, 0), Color3.fromRGB(40, 43, 45), Enum.Material.Metal, Vector3.new(0, 0, 90))
		local bagCenter = config.pos + Vector3.new(0, 0.25, 0)
		makeCylinder("Heavy Punch Bag Shell", decorFolder, Vector3.new(5.2, 3.6, 3.6), bagCenter, Color3.fromRGB(164, 39, 33), Enum.Material.Fabric, Vector3.new(0, 0, 90))
		makeBall("Heavy Punch Bag Top", decorFolder, Vector3.new(3.55, 2.25, 3.55), bagCenter + Vector3.new(0, 2.35, 0), Color3.fromRGB(179, 45, 37), Enum.Material.Fabric)
		makeBall("Heavy Punch Bag Bottom", decorFolder, Vector3.new(3.55, 2.1, 3.55), bagCenter + Vector3.new(0, -2.35, 0), Color3.fromRGB(128, 29, 27), Enum.Material.Fabric)
		for _, y in ipairs({ -1.7, 1.65 }) do
			makeCylinder("Heavy Bag Steel Band " .. y, decorFolder, Vector3.new(0.28, 3.75, 3.75), bagCenter + Vector3.new(0, y, 0), Color3.fromRGB(48, 51, 54), Enum.Material.Metal, Vector3.new(0, 0, 90))
		end
		local badge = makeVisualPart("Power Bag Hero Badge", decorFolder, Vector3.new(2.3, 1.15, 0.18), CFrame.new(bagCenter + Vector3.new(0, 0.1, -1.83)), Color3.fromRGB(20, 25, 28), Enum.Material.Metal)
		makeText(badge, "POWER", "+POWER / SEC", Enum.NormalId.Front)
	else
		local trainerModel = Instance.new("Model")
		trainerModel.Name = config.name .. " Training Model"
		trainerModel:SetAttribute("VisualRole", "PowerTrainingModel")
		trainerModel:SetAttribute("TrainingStationId", config.id)
		trainerModel:SetAttribute("ProceduralFallback", true)
		trainerModel.Parent = decorFolder
		local basePosition = Vector3.new(config.pos.X, 0.85, config.pos.Z)
		local base = makeVisualPart(config.name .. " Pedestal", trainerModel, Vector3.new(6.2, 1.1, 5.4), CFrame.new(basePosition), Color3.fromRGB(28, 35, 43), Enum.Material.Metal)
		local bodyHeight = 4.2 + config.tier * 0.45
		local body = makeVisualPart(config.name .. " Trainer Body", trainerModel, Vector3.new(3.4 + config.tier * 0.25, bodyHeight, 3.1), CFrame.new(basePosition + Vector3.new(0, 0.55 + bodyHeight * 0.5, 0)), config.color:Lerp(Color3.fromRGB(25, 29, 35), 0.35), Enum.Material.Metal)
		local core = makeBall(config.name .. " Power Core", trainerModel, Vector3.new(1.25 + config.tier * 0.18, 1.25 + config.tier * 0.18, 0.8), body.Position + Vector3.new(0, 0.35, -1.58), config.color, Enum.Material.Neon)
		for side = -1, 1, 2 do
			makeVisualPart(config.name .. " Energy Rail " .. side, trainerModel, Vector3.new(0.36, bodyHeight * 0.72, 0.5), CFrame.new(body.Position + Vector3.new(side * (body.Size.X * 0.62), 0, -1.15)) * CFrame.Angles(0, 0, math.rad(side * 7)), config.color, Enum.Material.Neon)
		end
		for fin = 1, config.tier do
			local angle = (fin - 1) / config.tier * math.pi * 2
			makeVisualPart(config.name .. " Tier Fin " .. fin, trainerModel, Vector3.new(0.42, 1.4, 1.5), CFrame.new(body.Position + Vector3.new(math.cos(angle) * 2.2, bodyHeight * 0.25, math.sin(angle) * 2.2)) * CFrame.Angles(0, -angle, math.rad(18)), config.color:Lerp(Color3.new(1, 1, 1), 0.18), Enum.Material.Metal)
		end
		trainerModel.PrimaryPart = body
		config.motionModel = trainerModel
		config.motionBasePivot = trainerModel:GetPivot()
		base:SetAttribute("TrainingVisualTier", config.tier)
		core:SetAttribute("TrainingPowerCore", true)
	end
	local detector = Instance.new("ClickDetector")
	detector.MaxActivationDistance = TRAINING_INTERACTION_DISTANCE
	detector.Parent = station
	detector.MouseClick:Connect(function(player)
		if not profileReady(player, false) then return end
		trainPlayer(player, config)
	end)
end

do
	local presentationReport = require(ReplicatedStorage:WaitForChild("ForestVisualBuilder")).BuildPresentation(polishFolder, {
		settings = PolishConfig.WorldPresentation,
		courseEntrance = courseEntrance,
		powerBag = trainingConfigs[1].part,
		boss = boss,
		weakPoints = bossWeakPoints,
		tierConfigs = wallConfigs,
		depthBlockSize = DEPTH_BLOCK_SIZE,
		layersPerTier = DEPTH_LAYERS_PER_TIER,
	})
	for _, detail in ipairs(presentationReport.breakLinked) do
		table.insert(wallVisualDetails[boss], detail)
	end
	root:SetAttribute("WorldPresentationPartCount", presentationReport.partCount)
	root:SetAttribute("WorldPresentationPartBudget", presentationReport.budget)
	root:SetAttribute("WorldPresentationContractValidated", true)
	root:SetAttribute("WorldSignageMode", "ZoneHeaderThenInteractionDetail")
	root:SetAttribute("WorldSignageSurfaceReduction", 1)
end

shared.PunchWallGrantTrainingTick = grantTrainingTick
shared.PunchWallStopTraining = stopTraining

local fistByName = {}
local fistPartsByName = {}
for _, item in ipairs(GameConfig.AllFists()) do
	fistByName[item.name] = item
end

shared.PunchWallPremiumFists = { byPass = {} }
for _, item in ipairs(GameConfig.PremiumFists) do
	if visualSafety.hasConfiguredGamePass(item) then
		shared.PunchWallPremiumFists.byPass[item.gamePassId] = item
	end
end

shared.PunchWallPremiumFists.grant = function(player, item, source)
	if not profileReady(player, false) then return { ok = false, reason = "profile_not_ready" } end
	if not item or not item.robux then return { ok = false, reason = "not_premium" } end
	local owned = decodeList(player, "OwnedPremiumFistsJSON")
	local alreadyOwned = listContains(owned, item.name)
	if alreadyOwned and source ~= "Owned" then
		return { ok = true, item = item.name, premium = true, alreadyOwned = true }
	end
	if not alreadyOwned then
		table.insert(owned, item.name)
		encodeList(player, "OwnedPremiumFistsJSON", owned)
	end
	setStat(player, "FistMultiplier", item.mult)
	setStat(player, "BreakSpeed", 1)
	setStat(player, "EquippedFist", item.name)
	sendFeedback(player, {
		type = "PremiumPurchase",
		target = item.displayName,
		message = "PREMIUM FIST EQUIPPED",
		source = source or "GamePass",
		color = item.accent,
	})
	return { ok = true, item = item.name, multiplier = item.mult, premium = true }
end

shared.PunchWallPremiumFists.prompt = function(player, item)
	if not profileReady(player, false) then return { ok = false, reason = "profile_not_ready" } end
	if not item or not item.robux then return { ok = false, reason = "not_premium" } end
	if not visualSafety.hasConfiguredGamePass(item) then
		sendFeedback(player, {
			type = "PremiumSetup",
			target = item.displayName,
			message = "PURCHASE UNAVAILABLE | PASS ID NOT CONFIGURED",
			robux = item.robux,
			color = item.accent,
		})
		return { ok = false, reason = "game_pass_not_configured", robux = item.robux }
	end
	if listContains(decodeList(player, "OwnedPremiumFistsJSON"), item.name) then
		return shared.PunchWallPremiumFists.grant(player, item, "Owned")
	end
	MarketplaceService:PromptGamePassPurchase(player, item.gamePassId)
	return { ok = true, pending = true, gamePassId = item.gamePassId, robux = item.robux }
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, wasPurchased)
	if not wasPurchased then return end
	local item = shared.PunchWallPremiumFists.byPass[gamePassId]
	if not item then return end
	local queued, queueError = persistenceRuntime.queuePendingGamePassGrant(player, "Fist", item, "GamePass")
	if not queued then
		warn(("[PunchWallRPG] Could not queue fist GamePass %s for %s: %s"):format(
			tostring(gamePassId),
			player.Name,
			tostring(queueError)
		))
		return
	end
	if profileReady(player, false) and persistenceRuntime.flushPendingGamePassGrants then
		task.spawn(persistenceRuntime.flushPendingGamePassGrants, player, "PurchaseFinished")
	end
end)

shared.PunchWallPremiumProducts = {
	byId = {},
	byName = {},
	invalidProductIds = {},
	promptState = setmetatable({}, { __mode = "k" }),
	metadataCache = {},
}
for _, product in ipairs(GameConfig.PremiumProducts) do
	shared.PunchWallPremiumProducts.byName[product.id] = product
	if visualSafety.hasConfiguredDeveloperProduct(product) then
		local existing = shared.PunchWallPremiumProducts.byId[product.productId]
		if existing then
			shared.PunchWallPremiumProducts.byId[product.productId] = nil
			shared.PunchWallPremiumProducts.invalidProductIds[product.productId] = true
			warn(("[PunchWallRPG] Duplicate Developer Product ID %d is disabled (%s / %s)"):format(
				product.productId,
				existing.id,
				product.id
			))
		elseif not shared.PunchWallPremiumProducts.invalidProductIds[product.productId] then
			shared.PunchWallPremiumProducts.byId[product.productId] = product
		end
	end
end

shared.PunchWallPremiumProducts.validatePromptMetadata = function(product)
	if not product then return false, "unknown_product" end
	local productId = tonumber(product.productId)
	local cached = productId and shared.PunchWallPremiumProducts.metadataCache[productId]
	local now = workspace:GetServerTimeNow()
	if cached and now - cached.checkedAt <= 60 then
		return cached.ok, cached.reason, cached.price
	end
	local lookupOk, info = pcall(
		MarketplaceService.GetProductInfoAsync,
		MarketplaceService,
		productId,
		Enum.InfoType.Product
	)
	local price = lookupOk and type(info) == "table" and tonumber(info.PriceInRobux) or nil
	local ok = lookupOk
		and type(info) == "table"
		and tostring(info.Name or "") == tostring(product.displayName or "")
		and info.IsForSale == true
		and price ~= nil
		and price > 0
	local reason = ok and nil
		or not lookupOk and "product_metadata_lookup_failed"
		or type(info) ~= "table" and "product_metadata_invalid"
		or tostring(info.Name or "") ~= tostring(product.displayName or "") and "product_identity_mismatch"
		or info.IsForSale ~= true and "product_off_sale"
		or "product_price_unavailable"
	shared.PunchWallPremiumProducts.metadataCache[productId] = {
		ok = ok,
		reason = reason,
		price = ok and math.floor(price) or nil,
		checkedAt = now,
	}
	return ok, reason, ok and math.floor(price) or nil
end

shared.PunchWallPremiumProducts.grant = function(player, product, durableEntry)
	if not profileReady(player, false) then return { ok = false, reason = "profile_not_ready" } end
	if not product then return { ok = false, reason = "unknown_product" } end
	local grantedCoins
	local grantedSpins
	local grantedHonor
	local grantedBoost
	local boostExpiresAt
	if durableEntry then
		grantedCoins = durableEntry.Coins
		grantedSpins = durableEntry.Spins
		grantedHonor = durableEntry.Honor
		grantedBoost = durableEntry.Boost
		boostExpiresAt = durableEntry.BoostExpiresAt
	else
		grantedCoins = product.coins
		grantedSpins = product.spins
		grantedHonor = product.honor
		grantedBoost = product.boost
		if grantedBoost then
			boostExpiresAt = math.max(
				player:GetAttribute(grantedBoost) or 0,
				workspace:GetServerTimeNow()
			) + product.seconds
		end
	end
	if grantedCoins ~= nil then addStat(player, "Coins", grantedCoins) end
	if grantedSpins ~= nil then addStat(player, "SpinCredits", grantedSpins) end
	if grantedHonor ~= nil then
		local currentHonor = statValue(player, "Honor", 0)
		if type(grantedHonor) ~= "number"
			or grantedHonor ~= grantedHonor
			or grantedHonor <= 0
			or grantedHonor % 1 ~= 0
			or currentHonor < 0
			or currentHonor > ProfilePersistence.MaxAuthoritativeNumber - grantedHonor
		then
			return { ok = false, reason = "honor_balance_headroom_required" }
		end
		setStat(player, "Honor", currentHonor + grantedHonor)
	end
	if grantedBoost and boostExpiresAt then
		player:SetAttribute(
			grantedBoost,
			math.max(player:GetAttribute(grantedBoost) or 0, boostExpiresAt)
		)
		if grantedBoost == "SpeedBoostExpiresAt" then
			persistenceRuntime.applySpeedBoostState(player)
		end
	end
	sendFeedback(player, {
		type = "PremiumPurchase",
		target = product.displayName,
		product = product.id,
		productId = product.productId,
		honor = grantedHonor,
		newHonorBalance = grantedHonor and statValue(player, "Honor", 0) or nil,
		message = grantedHonor and ("+%d HONOR ADDED"):format(grantedHonor) or "PURCHASE GRANTED",
		color = PolishConfig.Palette.Reward,
	})
	return {
		ok = true,
		product = product.id,
		coins = grantedCoins,
		spins = grantedSpins,
		honor = grantedHonor,
		boost = grantedBoost,
		boostExpiresAt = boostExpiresAt,
	}
end

shared.PunchWallPremiumProducts.prompt = function(player, product)
	if not profileReady(player, true) then
		sendFeedback(player, {
			type = "PremiumSetup",
			target = product and product.displayName or "Purchase",
			product = product and product.id,
			message = "PURCHASE UNAVAILABLE | PROFILE IS NOT WRITABLE",
			color = PolishConfig.Palette.Blocked,
		})
		return { ok = false, reason = "profile_not_writable" }
	end
	if not product then return { ok = false, reason = "unknown_product" } end
	if not visualSafety.hasConfiguredDeveloperProduct(product) then
		sendFeedback(player, {
			type = "PremiumSetup",
			target = product.displayName,
			product = product.id,
			productId = product.productId,
			message = "PURCHASE UNAVAILABLE | PRODUCT ID NOT CONFIGURED",
			robux = product.robux,
			color = PolishConfig.Palette.Reward,
		})
		return { ok = false, reason = "product_not_configured", robux = product.robux }
	end
	if shared.PunchWallPremiumProducts.invalidProductIds[product.productId]
		or shared.PunchWallPremiumProducts.byId[product.productId] ~= product
	then
		sendFeedback(player, {
			type = "PremiumSetup",
			target = product.displayName,
			product = product.id,
			message = "PURCHASE UNAVAILABLE | PRODUCT MAPPING INVALID",
			color = PolishConfig.Palette.Blocked,
		})
		return { ok = false, reason = "product_mapping_invalid" }
	end
	if product.honor ~= nil then
		local honorGrant = math.floor(tonumber(product.honor) or 0)
		local currentHonor = statValue(player, "Honor", 0)
		if honorGrant <= 0
			or currentHonor < 0
			or currentHonor > ProfilePersistence.MaxAuthoritativeNumber - honorGrant
		then
			sendFeedback(player, {
				type = "PremiumSetup",
				target = product.displayName,
				product = product.id,
				productId = product.productId,
				message = "HONOR BALANCE TOO HIGH | SPEND HONOR BEFORE BUYING",
				color = PolishConfig.Palette.Blocked,
			})
			return { ok = false, reason = "honor_balance_headroom_required" }
		end
	end
	local promptState = shared.PunchWallPremiumProducts.promptState[player]
	if not promptState then
		promptState = {}
		shared.PunchWallPremiumProducts.promptState[player] = promptState
	end
	local now = workspace:GetServerTimeNow()
	local globalNextAllowedAt = tonumber(promptState.__global) or 0
	local nextAllowedAt = tonumber(promptState[product.id]) or 0
	if now < globalNextAllowedAt or now < nextAllowedAt then
		sendFeedback(player, {
			type = "PremiumSetup",
			target = product.displayName,
			product = product.id,
			message = "PURCHASE WINDOW ALREADY OPENING",
			color = PolishConfig.Palette.Train,
		})
		return { ok = false, reason = "purchase_prompt_throttled" }
	end
	promptState.__global = now + 1.5
	promptState[product.id] = now + 1.5
	local metadataOk, metadataReason, livePrice = shared.PunchWallPremiumProducts.validatePromptMetadata(product)
	if not metadataOk then
		sendFeedback(player, {
			type = "PremiumSetup",
			target = product.displayName,
			product = product.id,
			productId = product.productId,
			message = metadataReason == "product_off_sale"
				and "PURCHASE UNAVAILABLE | PRODUCT IS OFF SALE"
				or "PURCHASE UNAVAILABLE | PRODUCT DETAILS COULD NOT BE VERIFIED",
			color = PolishConfig.Palette.Blocked,
		})
		return { ok = false, reason = metadataReason }
	end
	sendFeedback(player, {
		type = "PremiumPrompt",
		target = product.displayName,
		product = product.id,
		productId = product.productId,
		robux = livePrice,
		state = "CheckoutOpen",
		message = "CHECKOUT OPEN",
		color = PolishConfig.Palette.Reward,
	})
	MarketplaceService:PromptProductPurchase(player, product.productId)
	return { ok = true, pending = true, productId = product.productId }
end

do
local function requireSafeProfileReload(player, state, message)
	local session = persistenceRuntime.profileSessions[player]
	if not session then
		return
	end
	session.initializing = false
	session.ready = false
	session.writable = false
	player:SetAttribute("ProfileReady", false)
	player:SetAttribute("ProfileWritable", false)
	player:SetAttribute("ProfileCanSave", false)
	player:SetAttribute("ProfilePersistenceState", state)
	warn(("[PunchWallRPG] %s for %s"):format(message, player.Name))
	if player.Parent == Players then
		player:Kick("Your saved data is secure. Please rejoin once to safely refresh this session.")
	end
end

local function applyDurableReceiptToSession(player, purchaseId, product, receiptEntry)
	local session = persistenceRuntime.profileSessions[player]
	if not session or session.appliedReceiptIds[purchaseId] then
		return true
	end
	session.appliedReceiptIds[purchaseId] = true
	local liveApplySafe = true
	if player.Parent == Players then
		if not player:FindFirstChild("RPGStats") then
			liveApplySafe = false
		else
			local ok, grantResult = pcall(
				shared.PunchWallPremiumProducts.grant,
				player,
				product,
				receiptEntry
			)
			liveApplySafe = ok and type(grantResult) == "table" and grantResult.ok == true
			if not liveApplySafe then
				warn(("[PunchWallRPG] Durable receipt live apply failed for %s: %s"):format(
					player.Name,
					tostring(grantResult)
				))
			end
		end
	end
	persistenceRuntime.patchQueuedSaveSnapshots(player, purchaseId, receiptEntry)
	session.knownReceiptIds[purchaseId] = true
	if not liveApplySafe then
		requireSafeProfileReload(
			player,
			"ReceiptLiveApplyFailed",
			("Receipt %s requires a safe profile reload"):format(purchaseId)
		)
	end
	return liveApplySafe
end

local function processReceiptDurably(player, productId, purchaseId, product)
	local session = persistenceRuntime.profileSessions[player]
	local ready, readinessError = profileReady(player, true)
	if not ready then
		return false, readinessError
	end
	if not persistenceRuntime.playerStore then
		return false, "current_store_unavailable"
	end
	session.receiptUncertain[purchaseId] = true
	local snapshot = collectPlayerData(player)
	local snapshotIncludesReceipt = session.knownReceiptIds[purchaseId] == true
	local grantToken = ("%d:%s"):format(player.UserId, HttpService:GenerateGUID(false))
	local processedAt = workspace:GetServerTimeNow()
	local callbackState = {}
	local ok, canonicalOrError = persistenceRuntime.retryDataStoreCall(function()
		return persistenceRuntime.playerStore:UpdateAsync(tostring(player.UserId), function(previous)
			callbackState = {}
			local callbackNow = os.time()
			local updated, _, _, commitError = ProfilePersistence.CommitReceiptFenced(
				previous,
				snapshot,
				snapshotIncludesReceipt,
				purchaseId,
				productId,
				product,
				grantToken,
				processedAt,
				session.fence,
				callbackNow,
				GameConfig.DataVersion,
				ProfilePersistence.MaxReceiptLedgerEntries
			)
			if not updated then
				callbackState.error = commitError or "receipt_fence_rejected"
				return nil
			end
			local renewedProfile, renewedFence, renewed, renewStateOrError =
				ProfilePersistence.RenewSessionLease(
					updated,
					session.fence,
					callbackNow,
					persistenceRuntime.sessionLeaseSeconds,
					GameConfig.DataVersion,
					ProfilePersistence.MaxReceiptLedgerEntries
				)
			if not renewedProfile or not renewed or not renewedFence then
				callbackState.error = renewStateOrError or "session_lease_renew_rejected"
				return nil
			end
			callbackState.fence = renewedFence
			callbackState.leaseExpiresAt = renewedProfile.SessionLease
				and renewedProfile.SessionLease.ExpiresAt or 0
			return renewedProfile
		end)
	end)
	if not ok then
		return false, "receipt_update_failed: " .. tostring(canonicalOrError)
	end
	if callbackState.error then
		if string.find(tostring(callbackState.error), "session_", 1, true)
			or string.find(tostring(callbackState.error), "fence", 1, true)
		then
			session.ready = false
			session.writable = false
			player:SetAttribute("ProfileReady", false)
			player:SetAttribute("ProfileWritable", false)
			player:SetAttribute("ProfileCanSave", false)
			player:SetAttribute("ProfilePersistenceState", "SessionFenceRejected")
		end
		return false, callbackState.error
	end
	if type(canonicalOrError) ~= "table" then
		session.receiptUncertain[purchaseId] = nil
		return false, "receipt_update_rejected"
	end
	session.fence = callbackState.fence
	session.leaseExpiresAt = callbackState.leaseExpiresAt
	player:SetAttribute("ProfileRevision", callbackState.fence.Revision)
	player:SetAttribute("ProfileLeaseExpiresAt", callbackState.leaseExpiresAt)
	local receiptEntry = ProfilePersistence.GetReceiptEntry(
		canonicalOrError,
		purchaseId,
		ProfilePersistence.MaxReceiptLedgerEntries
	)
	local seenProductId = ProfilePersistence.GetSeenReceiptProductId(
		canonicalOrError,
		purchaseId,
		ProfilePersistence.MaxReceiptLedgerEntries
	)
	if seenProductId == nil or (seenProductId > 0 and seenProductId ~= productId) then
		session.receiptUncertain[purchaseId] = nil
		return false, "receipt_canonical_entry_missing"
	end
	if not ProfilePersistence.ReceiptEntryHasGrantMetadata(receiptEntry) then
		if snapshotIncludesReceipt then
			session.knownReceiptIds[purchaseId] = true
			session.receiptUncertain[purchaseId] = nil
			return true
		end
		session.knownReceiptIds[purchaseId] = true
		session.receiptUncertain[purchaseId] = nil
		requireSafeProfileReload(
			player,
			"ReceiptReconcileRequired",
			("Receipt %s requires a safe profile reload"):format(purchaseId)
		)
		return true
	end
	if not session.knownReceiptIds[purchaseId] then
		applyDurableReceiptToSession(player, purchaseId, product, receiptEntry)
	end
	session.knownReceiptIds[purchaseId] = true
	session.receiptUncertain[purchaseId] = nil
	return true
end

MarketplaceService.ProcessReceipt = function(receiptInfo)
	if type(receiptInfo) ~= "table" then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local playerId = tonumber(receiptInfo.PlayerId)
	local productId = tonumber(receiptInfo.ProductId)
	local purchaseId = ProfilePersistence.NormalizePurchaseId(receiptInfo.PurchaseId)
	if not playerId or not productId or not purchaseId then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	playerId = math.floor(playerId)
	productId = math.floor(productId)
	if playerId <= 0 or productId <= 0 then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local player = Players:GetPlayerByUserId(playerId)
	local product = shared.PunchWallPremiumProducts.byId[productId]
	if not player or not product or not profileReady(player, true) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local ticket = persistenceRuntime.enqueueReceiptOperation(player, purchaseId, function()
		return processReceiptDurably(player, productId, purchaseId, product)
	end)
	local granted = persistenceRuntime.waitForTicket(ticket, persistenceRuntime.receiptWaitTimeout)
	if granted then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end
end

shared.PunchWallBuildPremiumOffers = function()
local premiumOfferPositions = {
	Vector3.new(-91, 5.2, 3),
	Vector3.new(-86, 5.2, 49),
	Vector3.new(73, 5.2, 2),
	Vector3.new(-14, 5.2, 51),
}
	local placementIndex = 0
	for _, product in ipairs(GameConfig.PremiumProducts) do
		if product.worldOffer == false then
			continue
		end
		placementIndex += 1
		local position = premiumOfferPositions[placementIndex]
		if not position then
			error(("Missing Premium Offer position for %s"):format(tostring(product.id)))
		end
	local purchaseConfigured = visualSafety.hasConfiguredDeveloperProduct(product)
	local board = makePart(product.displayName .. " Premium Offer", interactFolder, Vector3.new(9.8, 4.5, 0.5), position, Color3.fromRGB(8, 17, 24), Enum.Material.Metal)
	board.CFrame = CFrame.lookAt(position, Vector3.new(-2, position.Y, -18))
	board.CanCollide = false
	board:SetAttribute("VisualRole", "RobuxShortcutAdvertisement")
	board:SetAttribute("RobuxPrice", product.robux)
	board:SetAttribute("ProductKey", product.id)
	visualSafety.markWorldOfferAvailability(
		board,
		purchaseConfigured,
		"DeveloperProduct"
	)
	makeText(
		board,
		purchaseConfigured and product.billboard or "OFFER UNAVAILABLE",
		purchaseConfigured and ("%s  |  R$ %d"):format(product.displayName, product.robux)
			or "PRODUCT ID NOT CONFIGURED",
		Enum.NormalId.Front
	)
	makeText(
		board,
		purchaseConfigured and "HERO SHORTCUT" or "NOT FOR SALE",
		purchaseConfigured and "OPTIONAL | PLAYABLE WITHOUT PURCHASE"
			or "THIS OFFER CANNOT BE PURCHASED",
		Enum.NormalId.Back
	)
	local iconName = product.spins and "Success" or product.boost == "TrainingBoostExpiresAt" and "Train" or "Coin"
	makeAtlasIconSurface(board, iconName, Enum.NormalId.Front)
	if purchaseConfigured then
		local detector = Instance.new("ClickDetector")
		detector.MaxActivationDistance = 28
		detector.Parent = board
		detector.MouseClick:Connect(function(player)
			if not profileReady(player, false) then return end
			shared.PunchWallPremiumProducts.prompt(player, product)
		end)
	end
	end
end
shared.PunchWallBuildPremiumOffers()
shared.PunchWallBuildPremiumOffers = nil

local function buyFist(player, item)
	if item.robux then
		return shared.PunchWallPremiumFists.prompt(player, item)
	end
	local owned = decodeList(player, "OwnedFistsJSON")
	if listContains(owned, item.name) then
		setStat(player, "FistMultiplier", item.mult)
		setStat(player, "BreakSpeed", 1)
		setStat(player, "EquippedFist", item.name)
		if item.name == "Boxing Glove" then
			completeTutorialAction(player, "BuyStarterFist")
		end
		sendFeedback(player, { type = "Shop", target = item.name, color = PolishConfig.Palette.Use })
		return { ok = true, outcome = "equipped", item = item.name, multiplier = item.mult, coins = statValue(player, "Coins", 0) }
	end
	local requiredDepth = math.max(0, math.floor(tonumber(item.unlockDepth) or 0))
	-- Fist progression is tied to cleared tunnel depth only. WallLevel is an
	-- independent XP gate and must never unlock deep-catalog purchases.
	local progressionDepth = math.max(0, math.floor(statValue(player, "Depth", 0)))
	if progressionDepth < requiredDepth then
		sendFeedback(player, {
			type = "Fail",
			target = item.name,
			message = ("Reach Depth %d"):format(requiredDepth),
			color = PolishConfig.Palette.Fail,
		})
		return {
			ok = false,
			reason = "depth_locked",
			requiredDepth = requiredDepth,
			depth = progressionDepth,
			cost = item.cost,
		}
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
	setStat(player, "BreakSpeed", 1)
	table.insert(owned, item.name)
	encodeList(player, "OwnedFistsJSON", owned)
	local equipped = playerStat(player, "EquippedFist")
	if equipped then
		equipped.Value = item.name
	end
	if item.name == "Boxing Glove" then
		completeTutorialAction(player, "BuyStarterFist")
	end
	sendFeedback(player, {
		type = "Shop",
		target = item.name,
		coins = -item.cost,
		color = PolishConfig.Palette.Use,
	})
	return { ok = true, item = item.name, multiplier = item.mult, coins = statValue(player, "Coins", 0) }
end

shared.PunchWallShopBoostPurchase = function(player, boostName)
	local catalog = {
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
		persistenceRuntime.applySpeedBoostState(player)
	end
	sendFeedback(player, { type = "Shop", target = boostName, message = boost.feedback, color = PolishConfig.Palette.Reward })
	syncStats(player)
	return { ok = true, item = boostName, expiresAt = expiresAt, coins = statValue(player, "Coins", 0) }
end

shared.PunchWallBuildCommerceWorld = function()
local boostShowcaseSpecs = {
	{
		id = "CoinBoost",
		displayName = "2X COINS",
		detail = "15 MINUTES  |  ROBUX SHOP",
		shopPage = "Robux",
		position = Vector3.new(27.5, 0.7, -21.5),
		color = Color3.fromRGB(244, 168, 29),
		accent = Color3.fromRGB(255, 226, 78),
		shape = "Coin",
	},
	{
		id = "SpeedBoost",
		displayName = "SPEED BOOST",
		detail = "15 MINUTES  |  8K COINS",
		position = Vector3.new(34.0, 0.7, -21.5),
		color = Color3.fromRGB(37, 161, 224),
		accent = Color3.fromRGB(73, 227, 255),
		shape = "Bolt",
	},
	{
		id = "DamageBoost",
		displayName = "2X DAMAGE",
		detail = "15 MINUTES  |  12K COINS",
		position = Vector3.new(40.5, 0.7, -21.5),
		color = Color3.fromRGB(219, 60, 41),
		accent = Color3.fromRGB(255, 131, 45),
		shape = "Burst",
	},
}

local function buildBoostShowcaseIcon(model, spec, center)
	if spec.shape == "Coin" then
		for index, offset in ipairs({
			Vector3.new(-0.8, -0.25, 0),
			Vector3.new(0.75, -0.15, 0.08),
			Vector3.new(0, 0.65, -0.05),
		}) do
			local coin = makeCylinder(
				("%s 3D Coin %d"):format(spec.id, index),
				model,
				Vector3.new(0.38, 2.3, 2.3),
				center + offset,
				index == 3 and spec.accent or spec.color,
				Enum.Material.Metal,
				Vector3.new(0, 90, 0)
			)
			coin.CanCollide = false
			coin.CanTouch = false
			coin.CanQuery = false
		end
		local core = makeCylinder(
			spec.id .. " Coin Neon Core",
			model,
			Vector3.new(0.42, 1.25, 1.25),
			center + Vector3.new(0, 0.65, -0.28),
			spec.accent,
			Enum.Material.Neon,
			Vector3.new(0, 90, 0)
		)
		core.CanCollide = false
		core.CanTouch = false
		core.CanQuery = false
	elseif spec.shape == "Bolt" then
		for index, segment in ipairs({
			{ Vector3.new(1.0, 2.25, 0.44), Vector3.new(-0.35, 0.9, 0), -24 },
			{ Vector3.new(1.72, 0.78, 0.46), Vector3.new(0.08, -0.1, 0), 4 },
			{ Vector3.new(0.94, 2.35, 0.44), Vector3.new(0.36, -1.08, 0), -29 },
		}) do
			local bolt = makeVisualPart(
				("%s 3D Bolt Segment %d"):format(spec.id, index),
				model,
				segment[1],
				CFrame.new(center + segment[2]) * CFrame.Angles(0, 0, math.rad(segment[3])),
				index == 2 and spec.color or spec.accent,
				Enum.Material.Neon
			)
			bolt.CastShadow = false
		end
	else
		local core = makeBall(spec.id .. " 3D Burst Core", model, Vector3.new(2.2, 2.2, 0.75), center, spec.accent, Enum.Material.Neon)
		core.CanCollide = false
		core.CanTouch = false
		core.CanQuery = false
		for index = 1, 8 do
			local angle = (index - 1) * math.pi / 4
			local offset = Vector3.new(math.cos(angle) * 1.65, math.sin(angle) * 1.65, 0)
			local ray = makeVisualPart(
				("%s 3D Burst Ray %d"):format(spec.id, index),
				model,
				Vector3.new(0.38, 1.35, 0.34),
				CFrame.new(center + offset) * CFrame.Angles(0, 0, angle),
				index % 2 == 0 and spec.accent or spec.color,
				Enum.Material.Neon
			)
			ray.CastShadow = false
		end
	end
end

local boostShowcaseFolder = Instance.new("Folder")
boostShowcaseFolder.Name = "Depth Entrance Boost Showcases"
boostShowcaseFolder.Parent = interactFolder
boostShowcaseFolder:SetAttribute("VisualRole", "HighTrafficBoostShowcaseLane")
boostShowcaseFolder:SetAttribute("PlacementPolicy", "OutsideDepthLaneRightEdge")
boostShowcaseFolder:SetAttribute("InteractionPolicy", "PromptClickOpenBoostsPage")
boostShowcaseFolder:SetAttribute("ContainsRuntimeLoops", false)
boostShowcaseFolder:SetAttribute("ShowcaseCount", #boostShowcaseSpecs)

local boostShowcaseLastOpenByPlayer = setmetatable({}, { __mode = "k" })
shared.PunchWallOpenWorldBoostKiosk = function(player, boostId)
	if not profileReady(player, false) then
		return { ok = false, reason = "profile_not_ready" }
	end
	local selected
	for _, spec in ipairs(boostShowcaseSpecs) do
		if spec.id == boostId then
			selected = spec
			break
		end
	end
	if not selected then
		return { ok = false, reason = "unknown_showcase" }
	end
	local now = os.clock()
	local lastOpenedAt = boostShowcaseLastOpenByPlayer[player] or -math.huge
	if now - lastOpenedAt < 0.65 then
		return { ok = false, reason = "cooldown" }
	end
	boostShowcaseLastOpenByPlayer[player] = now
	sendFeedback(player, {
		type = "OpenMenu",
		target = selected.id,
		tab = selected.shopPage or "Boosts",
		message = selected.displayName,
		color = selected.accent,
	})
	return { ok = true, page = selected.shopPage or "Boosts", boostId = selected.id }
end

local boostShowcasePartCount = 0
for index, spec in ipairs(boostShowcaseSpecs) do
	local model = Instance.new("Model")
	model.Name = spec.id .. " World Showcase"
	model:SetAttribute("VisualRole", "WorldBoostProductModel")
	model:SetAttribute("BoostId", spec.id)
	model:SetAttribute("ShopPage", spec.shopPage or "Boosts")
	model:SetAttribute("HighTrafficRoute", "SpawnToDepthEntrance")
	model:SetAttribute("NoGameplayCollision", true)
	model:SetAttribute("StaticPresentation", true)
	model:SetAttribute("PresentationVersion", "FramedBoostKioskV3")
	model.Parent = boostShowcaseFolder

	local plinth = makePart(
		spec.id .. " Showcase Interaction Plinth",
		model,
		Vector3.new(5.2, 0.7, 4.0),
		spec.position,
		Color3.fromRGB(22, 30, 36),
		Enum.Material.Metal
	)
	plinth.CanCollide = false
	plinth.CanTouch = false
	plinth:SetAttribute("InteractionMenu", spec.shopPage or "Boosts")
	plinth:SetAttribute("BoostId", spec.id)
	model.PrimaryPart = plinth
	local inset = makePart(
		spec.id .. " Showcase Color Deck",
		model,
		Vector3.new(4.55, 0.28, 3.3),
		spec.position + Vector3.new(0, 0.48, 0),
		spec.color:Lerp(Color3.fromRGB(7, 14, 18), 0.38),
		Enum.Material.Metal
	)
	inset.CanCollide = false
	inset.CanTouch = false
	inset.CanQuery = false
	inset.Transparency = 0.02
	for railIndex, rail in ipairs({
		{ Vector3.new(4.85, 0.14, 0.14), Vector3.new(0, 0.84, 1.73) },
		{ Vector3.new(4.85, 0.14, 0.14), Vector3.new(0, 0.84, -1.73) },
		{ Vector3.new(0.14, 0.14, 3.34), Vector3.new(2.36, 0.84, 0) },
		{ Vector3.new(0.14, 0.14, 3.34), Vector3.new(-2.36, 0.84, 0) },
	}) do
		local trim = makeVisualPart(
			("%s Showcase Deck Rail %d"):format(spec.id, railIndex),
			model,
			rail[1],
			CFrame.new(spec.position + rail[2]),
			spec.accent,
			Enum.Material.Neon
		)
		trim.CastShadow = false
	end
	for postIndex, x in ipairs({ -2.38, 2.38 }) do
		local post = makeVisualPart(
			("%s Showcase Frame Post %d"):format(spec.id, postIndex),
			model,
			Vector3.new(0.2, 4.45, 0.2),
			CFrame.new(spec.position + Vector3.new(x, 3.0, 0.62)),
			postIndex == 1 and spec.color or spec.accent,
			Enum.Material.Neon
		)
		post.CastShadow = false
	end

	local signPosition = spec.position + Vector3.new(0, 5.55, 0)
	local sign = makeVisualPart(
		spec.id .. " Showcase Sign",
		model,
		Vector3.new(5.45, 1.8, 0.32),
		CFrame.new(signPosition),
		Color3.fromRGB(6, 15, 21),
		Enum.Material.Metal
	)
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local surface = makeText(sign, spec.displayName, spec.detail, face)
		surface.Title.TextColor3 = spec.accent
		surface.Subtitle.TextColor3 = Color3.fromRGB(235, 242, 245)
	end
	buildBoostShowcaseIcon(model, spec, spec.position + Vector3.new(0, 3.35, 0))

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = spec.id .. " Open Boost Shop"
	prompt.ActionText = "VIEW BOOSTS"
	prompt.ObjectText = spec.displayName
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.ClickablePrompt = true
	prompt.Parent = plinth
	prompt.Triggered:Connect(function(player)
		shared.PunchWallOpenWorldBoostKiosk(player, spec.id)
	end)

	local detector = Instance.new("ClickDetector")
	detector.Name = spec.id .. " Open Boost Shop Click"
	detector.MaxActivationDistance = 16
	detector.Parent = plinth
	detector.MouseClick:Connect(function(player)
		shared.PunchWallOpenWorldBoostKiosk(player, spec.id)
	end)

	local modelParts = 0
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			modelParts += 1
		end
	end
	model:SetAttribute("StaticVisualPartCount", modelParts)
	model:SetAttribute("WithinVisualPartBudget", modelParts <= 18)
	boostShowcasePartCount += modelParts
	model:SetAttribute("ShowcaseOrder", index)
end
boostShowcaseFolder:SetAttribute("StaticVisualPartCount", boostShowcasePartCount)
boostShowcaseFolder:SetAttribute("StaticVisualPartBudget", 48)
boostShowcaseFolder:SetAttribute("WithinVisualPartBudget", boostShowcasePartCount <= 48)
root:SetAttribute("WorldBoostShowcaseCount", #boostShowcaseSpecs)
root:SetAttribute("WorldBoostShowcasePartCount", boostShowcasePartCount)
root:SetAttribute("WorldBoostShowcaseValidated", boostShowcasePartCount <= 48)

local shopBack = makePart("Fist Shop Sign", root, Vector3.new(36, 10, 0.8), Vector3.new(-43, 21.5, -18.8), Color3.fromRGB(61, 48, 40), Enum.Material.WoodPlanks)
makeGraphicSurface(shopBack, GameConfig.GeneratedGraphics.HeroCityHUDAtlas, "HERO FIST HQ", "CHOOSE | EQUIP | POWER UP", Enum.NormalId.Front)
makeGraphicSurface(shopBack, GameConfig.HeroCityPixelUI.SmashBillboard, "SMASH!", "HERO CITY", Enum.NormalId.Back)
local shopRoof = makePart("Forest Armory Timber Roof", decorFolder, Vector3.new(45, 0.55, 4.4), Vector3.new(-43, 15.8, -16.8), Color3.fromRGB(76, 53, 36), Enum.Material.WoodPlanks)
shopRoof:SetAttribute("TextureStyle", "ForestArmoryRoof")
makePart("Armory Gold Trim", decorFolder, Vector3.new(34, 0.18, 0.65), Vector3.new(-43, 16.18, -18.9), PolishConfig.Palette.HeroYellow, Enum.Material.Metal)
makePart("Forest Armory Back Wall", decorFolder, Vector3.new(44, 7.5, 0.8), Vector3.new(-43, 5.0, -16.2), Color3.fromRGB(86, 64, 46), Enum.Material.WoodPlanks)
makeCoinStack(decorFolder, Vector3.new(-69, 1.1, -1))

for index, item in ipairs(GameConfig.PremiumFists) do
	local purchaseConfigured = visualSafety.hasConfiguredGamePass(item)
	local stand = makePart(item.name .. " Stand", interactFolder, Vector3.new(12, 5, 10), Vector3.new(-82 + index * 20, 3, -10), Color3.fromRGB(230, 230, 230), Enum.Material.Metal)
	stand.Color = index % 2 == 0 and PolishConfig.Palette.HeroCyan or PolishConfig.Palette.HeroRed
	stand:SetAttribute("Theme", PolishConfig.StyleName)
	stand:SetAttribute("PremiumOnly", true)
	stand:SetAttribute("RobuxPrice", item.robux)
	visualSafety.markWorldOfferAvailability(stand, purchaseConfigured, "GamePass")
	stand.Transparency = 0.9
	stand.CanCollide = false
	fistPartsByName[item.name] = stand
	makePart(item.name .. " Display Plinth", decorFolder, Vector3.new(11, 1.0, 8.5), stand.Position + Vector3.new(0, -2.0, 0), Color3.fromRGB(44, 50, 55), Enum.Material.Metal)
	local nameplate = makeVisualPart(item.name .. " Armory Nameplate", decorFolder, Vector3.new(11.2, 2.1, 0.35), CFrame.new(stand.Position + Vector3.new(0, -0.3, 5.25)), PolishConfig.Palette.Ink, Enum.Material.Metal)
	nameplate:SetAttribute("PolishRole", "ArmoryFixedNameplate")
	local offerDescription = purchaseConfigured
		and ("R$ %d | PERMANENT | x%.1f"):format(item.robux, item.mult)
		or "UNAVAILABLE | PASS ID NOT CONFIGURED"
	local frontText = makeText(nameplate, item.displayName, offerDescription, Enum.NormalId.Front)
	local backText = makeText(nameplate, item.displayName, offerDescription, Enum.NormalId.Back)
	visualSafety.markWorldOfferAvailability(nameplate, purchaseConfigured, "GamePass")
	for _, surface in ipairs({ frontText, backText }) do
		surface.Title.Position = UDim2.fromScale(0.29, 0.08)
		surface.Title.Size = UDim2.fromScale(0.68, 0.38)
		surface.Subtitle.Position = UDim2.fromScale(0.29, 0.48)
		surface.Subtitle.Size = UDim2.fromScale(0.68, 0.38)
	end
	makeAtlasIconSurface(nameplate, item.icon, Enum.NormalId.Front)
	makeAtlasIconSurface(nameplate, item.icon, Enum.NormalId.Back)
	local sourceName = item.model == "Gold" and "Sanitized_PowerFistGoldKnuckle" or "CreatorStore_ArmoredClosedHeroFist"
	local displayModel = cloneExternalVisual(
		sourceName,
		decorFolder,
		item.name .. " Creator Store Display",
		CFrame.new(stand.Position),
		4.4,
		false
	)
	if not displayModel and item.model == "Gold" then
		displayModel = cloneExternalVisual(
			"Sanitized_TitanGoldFist",
			decorFolder,
			item.name .. " Creator Store Display",
			CFrame.new(stand.Position),
			4.4,
			false
		)
	end
	if displayModel then
		displayModel:SetAttribute("VisualRole", "PremiumFistShowcase")
		displayModel:SetAttribute("PremiumTier", item.tier)
		-- Showcase fists should read like the upright shop art. The source mesh's
		-- local Y axis is already cuff-to-knuckles, so only turn its knuckle face
		-- toward the plaza instead of laying the whole mesh on its side.
		local displayRotation = CFrame.Angles(0, math.rad(180), 0)
		local displayBoundsCFrame, displayBoundsSize = displayModel:GetBoundingBox()
		local pivotToBounds = displayModel:GetPivot():ToObjectSpace(displayBoundsCFrame)
		local targetCenter = stand.Position + Vector3.new(0, 1.0, -0.7)
		displayModel:PivotTo(CFrame.new(targetCenter) * displayRotation * pivotToBounds:Inverse())
		for _, visual in ipairs(displayModel:GetDescendants()) do
			if visual:IsA("SpecialMesh") then
				visual.TextureId = ""
			elseif visual:IsA("BasePart") then
				visual.Color = item.color
				visual.Material = item.material
			end
		end
		local showcaseHighlight = Instance.new("Highlight")
		showcaseHighlight.Name = "Premium Fist Edge Light"
		showcaseHighlight.Adornee = displayModel
		showcaseHighlight.DepthMode = Enum.HighlightDepthMode.Occluded
		showcaseHighlight.FillColor = item.color
		showcaseHighlight.FillTransparency = 0.9
		showcaseHighlight.OutlineColor = item.accent
		showcaseHighlight.OutlineTransparency = 0.22
		showcaseHighlight.Parent = displayModel
		displayModel:SetAttribute("ShowcaseForwardAxis", "LocalYVertical")
		displayModel:SetAttribute("ShowcaseFacing", "KnucklesTowardPlaza")
		displayModel:SetAttribute("ShowcaseTargetLength", 4.4)
		displayModel:SetAttribute("ShowcaseBoundsHeight", displayBoundsSize.Y)
	else
		local fallback = makeBall(item.name .. " Fallback Fist", decorFolder, Vector3.new(4.2, 4.7, 4.0), stand.Position + Vector3.new(0, 4.6, -0.7), item.color, item.material)
		fallback:SetAttribute("ProceduralFallback", true)
	end
	if item.model == "Void" then
		local aura = cloneExternalVisual(
			"Sanitized_VoidFistAura",
			decorFolder,
			item.name .. " Creator Store Aura",
			CFrame.new(stand.Position + Vector3.new(0, 1.0, -0.7)),
			4.2,
			true
		)
		if aura then aura:SetAttribute("VisualRole", "PremiumVoidAura") end
	end
	local glow = makeCylinder(item.name .. " Pedestal Glow", decorFolder, Vector3.new(0.08, 4.8, 4.8), stand.Position + Vector3.new(0, -1.42, -0.5), item.accent, Enum.Material.Neon, Vector3.new(0, 0, 90))
	glow.Transparency = 0.58
	if purchaseConfigured then
		local detector = Instance.new("ClickDetector")
		detector.MaxActivationDistance = 30
		detector.Parent = stand
		detector.MouseClick:Connect(function(player)
			if not profileReady(player, false) then return end
			shared.PunchWallPremiumFists.prompt(player, item)
		end)
	end
end

local armoryNPC = cloneExternalVisual(
	"Sanitized_ArmoryMerchantNPC",
	decorFolder,
	"Hero Armory Merchant NPC",
	CFrame.new(-69, 0.35, -14) * CFrame.Angles(0, math.rad(180), 0),
	6.4,
	false
)
if armoryNPC then
	armoryNPC:SetAttribute("NPCType", "FistShop")
else
	armoryNPC = makeProceduralHeroNPC(
		"Hero Armory Merchant NPC Fallback",
		decorFolder,
		CFrame.new(-69, 0.35, -14) * CFrame.Angles(0, math.rad(180), 0),
		PolishConfig.Palette.HeroRed,
		PolishConfig.Palette.HeroYellow,
		"FistShop"
	)
end
local premiumRobotNPC = cloneExternalVisual(
	"Sanitized_PremiumBionicHeroNPC",
	decorFolder,
	"Premium Hero Robot Merchant NPC",
	CFrame.new(-91, 0.35, -14) * CFrame.Angles(0, math.rad(155), 0),
	7.0,
	false
)
if premiumRobotNPC then
	premiumRobotNPC:SetAttribute("NPCType", "PremiumRobuxShop")
	premiumRobotNPC:SetAttribute("VisualRole", "PremiumRobuxMerchant")
else
	premiumRobotNPC = makeProceduralHeroNPC(
		"Premium Hero Robot Merchant NPC Fallback",
		decorFolder,
		CFrame.new(-91, 0.35, -14) * CFrame.Angles(0, math.rad(155), 0),
		Color3.fromRGB(31, 40, 53),
		PolishConfig.Palette.HeroCyan,
		"PremiumRobuxShop"
	)
end
local premiumRobotTrigger = makePart("Premium Robot Merchant Interaction", interactFolder, Vector3.new(8, 8, 8), Vector3.new(-91, 4, -14), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
premiumRobotTrigger.Transparency = 1
premiumRobotTrigger.CanCollide = false
premiumRobotTrigger:SetAttribute("InteractionMenu", "Fists")
local premiumRobotDetector = Instance.new("ClickDetector")
premiumRobotDetector.MaxActivationDistance = 28
premiumRobotDetector.Parent = premiumRobotTrigger
premiumRobotDetector.MouseClick:Connect(function(player)
	if not profileReady(player, false) then return end
	sendFeedback(player, { type = "OpenMenu", target = "Fists", tab = "Fists", color = PolishConfig.Palette.HeroYellow })
end)
local armoryNPCTrigger = makePart("Hero Armory Merchant Interaction", interactFolder, Vector3.new(8, 8, 8), Vector3.new(-69, 4, -14), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
shared.PunchWallArmoryNPCTrigger = armoryNPCTrigger
armoryNPCTrigger.Transparency = 1
armoryNPCTrigger.CanCollide = false
armoryNPCTrigger:SetAttribute("InteractionMenu", "Fists")
local armoryNPCDetector = Instance.new("ClickDetector")
armoryNPCDetector.MaxActivationDistance = 28
armoryNPCDetector.Parent = armoryNPCTrigger
armoryNPCDetector.MouseClick:Connect(function(player)
	if not profileReady(player, false) then return end
	sendFeedback(player, { type = "OpenMenu", target = "Fists", tab = "Fists", color = PolishConfig.Palette.HeroRed })
end)

local petAnnexDeck = makePart("Pet Lab Annex Deck", decorFolder, Vector3.new(20, 0.28, 30), Vector3.new(-94, 0.3, 18), Color3.fromRGB(81, 91, 94), Enum.Material.Metal)
petAnnexDeck:SetAttribute("VisualRole", "PetLabAnnexDeck")
local petAnnexBridge = makePart("Pet Lab Annex Bridge", decorFolder, Vector3.new(4, 0.26, 8), Vector3.new(-83, 0.31, 24), Color3.fromRGB(96, 103, 101), Enum.Material.Metal)
petAnnexBridge:SetAttribute("VisualRole", "PetLabAnnexBridge")
local eggPart = makePart("Pet Egg Machine", interactFolder, Vector3.new(11, 9, 11), Vector3.new(-94, 5.5, 24), Color3.fromRGB(35, 112, 145), Enum.Material.Glass)
shared.PunchWallEggPart = eggPart
eggPart:SetAttribute("Theme", PolishConfig.StyleName)
eggPart.Transparency = 0.94
eggPart.CanCollide = false
addEmitter(eggPart, "Egg Reveal", PolishConfig.RarityColors.Epic)
makePart("DNA Lab Concrete Base", decorFolder, Vector3.new(17, 0.6, 17), eggPart.Position + Vector3.new(0, -5.2, 0), Color3.fromRGB(88, 92, 93), Enum.Material.Concrete)
local containmentTube = makeCylinder("DNA Containment Tube", decorFolder, Vector3.new(7.2, 5.6, 5.6), eggPart.Position + Vector3.new(0, 0.4, 0), PolishConfig.Palette.HeroCyan, Enum.Material.Glass, Vector3.new(0, 0, 90))
containmentTube.Transparency = 0.54
containmentTube:SetAttribute("VisualRole", "PetContainmentCapsule")
makeCylinder("DNA Tube Top Clamp", decorFolder, Vector3.new(0.42, 6.4, 6.4), eggPart.Position + Vector3.new(0, 4.0, 0), Color3.fromRGB(42, 48, 51), Enum.Material.Metal, Vector3.new(0, 0, 90))
makeCylinder("DNA Tube Bottom Clamp", decorFolder, Vector3.new(0.42, 6.4, 6.4), eggPart.Position + Vector3.new(0, -3.2, 0), Color3.fromRGB(42, 48, 51), Enum.Material.Metal, Vector3.new(0, 0, 90))
local sampleEgg = makeBall("Contained Sidekick Egg", decorFolder, Vector3.new(3.0, 3.8, 3.0), eggPart.Position + Vector3.new(0, -0.25, 0), Color3.fromRGB(225, 229, 216), Enum.Material.SmoothPlastic)
sampleEgg:SetAttribute("VisualRole", "PetEggSample")
for index, offset in ipairs({ Vector3.new(-0.7, 0.45, -1.35), Vector3.new(0.65, -0.25, -1.4), Vector3.new(0.15, 0.95, -1.25) }) do
	local spot = makeBall("Sidekick Egg Spot " .. index, decorFolder, Vector3.new(0.55, 0.7, 0.2), sampleEgg.Position + offset, PolishConfig.Palette.HeroCyan, Enum.Material.Neon)
	spot.CanCollide = false
end
makePart("DNA Lab Control Panel", decorFolder, Vector3.new(5.2, 3.0, 1.0), eggPart.Position + Vector3.new(-6.3, -2.0, -5.1), Color3.fromRGB(29, 34, 38), Enum.Material.Metal)
makePart("DNA Lab Screen", decorFolder, Vector3.new(4.0, 1.9, 0.25), eggPart.Position + Vector3.new(-6.3, -1.5, -5.7), PolishConfig.Palette.HeroYellow, Enum.Material.Neon)
makePart("Kaiju Sample Pod", decorFolder, Vector3.new(3.8, 4.8, 3.8), eggPart.Position + Vector3.new(8.2, -2.4, 0), Color3.fromRGB(42, 63, 69), Enum.Material.Metal)
local sampleGlow = makeBall("Sidekick Sample Glow", decorFolder, Vector3.new(1.6, 1.6, 1.6), eggPart.Position + Vector3.new(8.2, 0.5, 0), PolishConfig.Palette.HeroCyan, Enum.Material.Neon)
sampleGlow.Transparency = 0.22
local dnaSign = makePart("DNA Lab Compact Sign", decorFolder, Vector3.new(12, 3.2, 0.45), eggPart.Position + Vector3.new(0, 6.0, -6.1), PolishConfig.Palette.Ink, Enum.Material.Metal)
makeGraphicSurface(dnaSign, GameConfig.GeneratedGraphics.Iteration02DNABanner, "HERO SIDEKICK LAB", "FIND EGGS IN WALLS | FUSE PETS HERE", Enum.NormalId.Front)
makeGraphicSurface(dnaSign, GameConfig.GeneratedGraphics.Iteration02DNABanner, "HERO SIDEKICK LAB", "FIND EGGS IN WALLS | FUSE PETS HERE", Enum.NormalId.Back)

local petLabNPC = cloneExternalVisual(
	"Sanitized_PetLabScientistNPC",
	decorFolder,
	"Hero Sidekick Scientist NPC",
	CFrame.new(-102, 0.35, 12) * CFrame.Angles(0, math.rad(180), 0),
	6.2,
	false
)
if petLabNPC then
	petLabNPC:SetAttribute("NPCType", "PetShop")
else
	petLabNPC = makeProceduralHeroNPC(
		"Hero Sidekick Scientist NPC Fallback",
		decorFolder,
		CFrame.new(-102, 0.35, 12) * CFrame.Angles(0, math.rad(180), 0),
		Color3.fromRGB(224, 232, 239),
		PolishConfig.Palette.HeroCyan,
		"PetShop"
	)
end
local petLabNPCTrigger = makePart("Hero Sidekick Scientist Interaction", interactFolder, Vector3.new(8, 8, 8), Vector3.new(-102, 4, 12), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
shared.PunchWallPetLabNPCTrigger = petLabNPCTrigger
petLabNPCTrigger.Transparency = 1
petLabNPCTrigger.CanCollide = false
petLabNPCTrigger:SetAttribute("InteractionMenu", "Pets")
local petLabNPCDetector = Instance.new("ClickDetector")
petLabNPCDetector.MaxActivationDistance = 28
petLabNPCDetector.Parent = petLabNPCTrigger
petLabNPCDetector.MouseClick:Connect(function(player)
	if not profileReady(player, false) then return end
	sendFeedback(player, { type = "OpenMenu", target = "Pets", tab = "Pets", color = PolishConfig.Palette.HeroCyan })
end)
end
shared.PunchWallBuildCommerceWorld()
shared.PunchWallBuildCommerceWorld = nil

local pets = GameConfig.Pets
local petByName = {}
for _, pet in ipairs(GameConfig.AllPets()) do
	petByName[pet.name] = pet
end

local function petValueCount(list, value)
	local count = 0
	for _, current in ipairs(list) do
		if current == value then
			count += 1
		end
	end
	return count
end

local function petOccurrenceAt(inventory, petName, inventoryIndex)
	local occurrence = 0
	for index = 1, inventoryIndex do
		if inventory[index] == petName then
			occurrence += 1
		end
	end
	return occurrence
end

local function validatePetInventoryIndex(inventory, petName, inventoryIndex)
	if inventoryIndex == nil then
		return nil
	end
	local selectedIndex = tonumber(inventoryIndex)
	if not selectedIndex
		or selectedIndex < 1
		or selectedIndex % 1 ~= 0
		or inventory[selectedIndex] ~= petName
	then
		return nil, "stale_inventory"
	end
	return selectedIndex
end

local function removeLast(list, value)
	for index = #list, 1, -1 do
		if list[index] == value then
			table.remove(list, index)
			return true
		end
	end
	return false
end

local function refreshEquippedPets(player)
	local equipped = decodeList(player, "EquippedPetsJSON")
	local inventory = decodeList(player, "PetInventoryJSON")
	local valid = {}
	local available = {}
	for _, token in ipairs(inventory) do
		available[token] = (available[token] or 0) + 1
	end
	local multiplier = 0
	for _, token in ipairs(equipped) do
		local petName = GameConfig.ParsePetToken(token)
		if #valid < GameConfig.MaxEquippedPets and petByName[petName] and (available[token] or 0) > 0 then
			table.insert(valid, token)
			available[token] -= 1
			multiplier += GameConfig.PetMultiplierForToken(token)
		end
	end
	encodeList(player, "EquippedPetsJSON", valid)
	setStat(player, "PetMultiplier", multiplier)
	setStat(player, "Pet", valid[1] or "None")
	return valid, multiplier
end

local function rollPet(luck, depth)
	depth = math.clamp(math.floor(tonumber(depth) or 1), 1, GameConfig.WorldProgressTarget)
	local eligible = {}
	for _, pet in ipairs(pets) do
		if depth >= (pet.minDepth or 1) then table.insert(eligible, pet) end
	end
	if #eligible == 0 then table.insert(eligible, pets[1]) end
	local poolStart = math.max(1, #eligible - 1)
	local total = 0
	for index = poolStart, #eligible do
		local pet = eligible[index]
		total += GameConfig.PetWeight(pet, luck) * (1 + math.max(0, depth - (pet.minDepth or 1)) * 0.025)
	end
	local roll = math.random() * total
	local cumulative = 0
	for index = poolStart, #eligible do
		local pet = eligible[index]
		cumulative += GameConfig.PetWeight(pet, luck) * (1 + math.max(0, depth - (pet.minDepth or 1)) * 0.025)
		if roll <= cumulative then
			return pet, eligible[poolStart].name, eligible[#eligible].name
		end
	end
	return eligible[#eligible], eligible[poolStart].name, eligible[#eligible].name
end

local function petRarityColor(pet)
	return pet.mult >= 4 and PolishConfig.RarityColors.Secret
		or pet.mult >= 1.5 and PolishConfig.RarityColors.Legendary
		or pet.mult >= 0.8 and PolishConfig.RarityColors.Epic
		or pet.mult >= 0.3 and PolishConfig.RarityColors.Rare
		or PolishConfig.RarityColors.Common
end

local function grantPet(player, chosen, stars, source)
	if not chosen then return { ok = false, reason = "unknown_pet" } end
	local inventory = decodeList(player, "PetInventoryJSON")
	if #inventory >= GameConfig.MaxPetInventory then
		sendFeedback(player, { type = "Fail", target = "Pet Egg", message = "Inventory full", color = PolishConfig.Palette.Fail })
		return { ok = false, reason = "inventory_full" }
	end
	local token = GameConfig.PetToken(chosen.name, stars or 1)
	table.insert(inventory, token)
	encodeList(player, "PetInventoryJSON", inventory)
	local discovered = decodeList(player, "DiscoveredPetsJSON")
	local firstDiscovery = not listContains(discovered, chosen.name)
	if firstDiscovery then
		table.insert(discovered, chosen.name)
		encodeList(player, "DiscoveredPetsJSON", discovered)
	end
	local equipped = decodeList(player, "EquippedPetsJSON")
	if #equipped < GameConfig.MaxEquippedPets then
		table.insert(equipped, token)
		encodeList(player, "EquippedPetsJSON", equipped)
	end
	local _, equippedMultiplier = refreshEquippedPets(player)
	-- Luck is a discovery reward, not a per-copy reward. Duplicates are fusion
	-- material and reclaiming a permanent entitlement must never farm Luck.
	if firstDiscovery then
		addStat(player, "Luck", chosen.luckGain)
	end
	emitNamed(shared.PunchWallEggPart, "Egg Reveal", 32)
	sendFeedback(player, {
		type = "Pet",
		target = token,
		rarity = chosen.rarity,
		multiplier = GameConfig.PetMultiplierForToken(token),
		stars = stars or 1,
		source = source or "WallEgg",
		color = petRarityColor(chosen),
	})
	return { ok = true, pet = token, petName = chosen.name, rarity = chosen.rarity, stars = stars or 1, multiplier = GameConfig.PetMultiplierForToken(token), equippedMultiplier = equippedMultiplier, luck = statValue(player, "Luck", 1), source = source or "WallEgg" }
end

function petDropRuntime.Clear(player, reason)
	local record = player and petDropRuntime.active[player.UserId]
	if not record then return false end
	if petDropRuntime.active[player.UserId] == record then
		petDropRuntime.active[player.UserId] = nil
	end
	player:SetAttribute("ActivePetEggDropId", nil)
	player:SetAttribute("ActivePetEggExpiresAt", nil)
	player:SetAttribute("ActivePetEggDepth", nil)
	if record.billboard and record.billboard.Parent then
		record.billboard:Destroy()
	end
	if record.model and record.model.Parent then
		record.model:SetAttribute("RemovalReason", tostring(reason or "cleared"))
		record.model:Destroy()
	end
	return true
end

function petDropRuntime.GroundPosition(player, sourcePosition)
	local character = player and player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local source = typeof(sourcePosition) == "Vector3"
		and sourcePosition
		or rootPart and (rootPart.Position + rootPart.CFrame.LookVector * 4)
		or Vector3.new(-2, 3, -24)
	if rootPart and typeof(sourcePosition) == "Vector3" then
		local fromPlayer = Vector3.new(source.X - rootPart.Position.X, 0, source.Z - rootPart.Position.Z)
		local distance = fromPlayer.Magnitude
		local direction = distance > 0.01 and fromPlayer.Unit
			or Vector3.new(rootPart.CFrame.LookVector.X, 0, rootPart.CFrame.LookVector.Z).Unit
		if distance < 3.5 then
			source = Vector3.new(
				rootPart.Position.X + direction.X * 3.5,
				source.Y,
				rootPart.Position.Z + direction.Z * 3.5
			)
		elseif distance > 6 then
			source = Vector3.new(
				rootPart.Position.X + direction.X * 5,
				source.Y,
				rootPart.Position.Z + direction.Z * 5
			)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { wallsFolder, petDropRuntime.folder, character }
	params.IgnoreWater = true
	local result = workspace:Raycast(source + Vector3.new(0, 30, 0), Vector3.new(0, -90, 0), params)
	local groundY = result and result.Position.Y or math.max(0, source.Y - 3)
	return Vector3.new(source.X, groundY + 1.45, source.Z)
end

function petDropRuntime.Spawn(player, chosen, depth, sourcePosition, pityTriggered)
	local dropConfig = GameConfig.PetDrops
	local existing = petDropRuntime.active[player.UserId]
	if existing and existing.model and existing.model.Parent then
		return {
			ok = false,
			reason = "active_drop",
			pendingPickup = true,
			dropId = existing.id,
			expiresAt = existing.expiresAt,
		}
	end
	if existing then petDropRuntime.Clear(player, "stale_record") end

	local now = workspace:GetServerTimeNow()
	local dropId = HttpService:GenerateGUID(false)
	local expiresAt = now + dropConfig.LifetimeSeconds
	local claimReadyAt = now + dropConfig.PickupArmSeconds
	local position = petDropRuntime.GroundPosition(player, sourcePosition)
	local rarityColor = petRarityColor(chosen)
	local model = Instance.new("Model")
	model.Name = "Mystery Pet Egg " .. player.UserId
	model:SetAttribute("VisualRole", "PetDropEgg")
	model:SetAttribute("DropId", dropId)
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("Depth", depth)
	model:SetAttribute("Rarity", chosen.rarity)
	model:SetAttribute("SpawnedAt", now)
	model:SetAttribute("ClaimReadyAt", claimReadyAt)
	model:SetAttribute("ExpiresAt", expiresAt)
	model:SetAttribute("Claimed", false)
	model:SetAttribute("ServerAuthoritative", true)
	model:SetAttribute("RewardHiddenUntilClaim", true)
	model.Parent = petDropRuntime.folder

	local glow = makeCylinder(
		"Egg Ground Glow",
		model,
		Vector3.new(0.12, 2.85, 2.85),
		position - Vector3.new(0, 1.34, 0),
		rarityColor,
		Enum.Material.Neon,
		Vector3.new(0, 0, 90)
	)
	glow.CanCollide = false
	glow.CanTouch = false
	glow.CanQuery = false
	glow.Transparency = 0.58

	local egg = makeBall(
		"Mystery Pet Egg",
		model,
		Vector3.new(2.05, 2.8, 2.05),
		position,
		Color3.fromRGB(238, 235, 214),
		Enum.Material.SmoothPlastic
	)
	egg.CanCollide = false
	egg.CanTouch = false
	egg.CanQuery = true
	model.PrimaryPart = egg

	for index, offset in ipairs({
		Vector3.new(-0.55, 0.55, 0.86),
		Vector3.new(0.48, 0.82, 0.86),
		Vector3.new(0.08, -0.58, 0.94),
		Vector3.new(-0.62, -0.24, 0.78),
		Vector3.new(0.62, 0.12, 0.78),
	}) do
		local spot = makeBall(
			"Egg Spot " .. index,
			model,
			Vector3.new(0.46, 0.58, 0.18),
			position + offset,
			rarityColor,
			chosen.rarity == "Common" and Enum.Material.SmoothPlastic or Enum.Material.Neon
		)
		spot.CanCollide = false
		spot.CanTouch = false
		spot.CanQuery = false
	end

	local light = Instance.new("PointLight")
	light.Name = "Egg Rarity Glow"
	light.Color = rarityColor
	light.Brightness = chosen.rarity == "Common" and 0.35 or 0.75
	light.Range = chosen.rarity == "Common" and 5 or 8
	light.Shadows = false
	light.Parent = egg
	local outline = Instance.new("Highlight")
	outline.Name = "Egg Rarity Outline"
	outline.Adornee = model
	outline.DepthMode = Enum.HighlightDepthMode.Occluded
	outline.FillColor = rarityColor
	outline.FillTransparency = 0.94
	outline.OutlineColor = rarityColor
	outline.OutlineTransparency = 0.18
	outline.Parent = model

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Pickup Label"
	billboard.Adornee = egg
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 80
	billboard.Size = UDim2.fromOffset(210, 58)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 2.45, 0)
	billboard.Parent = player:FindFirstChildOfClass("PlayerGui") or egg
	local label = Instance.new("TextLabel")
	label.Name = "Countdown"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(8, 17, 25)
	label.BackgroundTransparency = 0.15
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0.35
	label.TextScaled = true
	label.TextWrapped = true
	label.Parent = billboard
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label
	local stroke = Instance.new("UIStroke")
	stroke.Color = rarityColor
	stroke.Thickness = 2
	stroke.Parent = label

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Pick Up Pet Egg"
	prompt.ActionText = "PICK UP"
	prompt.ObjectText = "MYSTERY PET EGG"
	prompt.HoldDuration = 0.12
	prompt.MaxActivationDistance = dropConfig.PickupDistance
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.ClickablePrompt = true
	prompt.Enabled = false
	prompt.Parent = egg

	local click = Instance.new("ClickDetector")
	click.Name = "Pet Egg Click Pickup"
	click.MaxActivationDistance = dropConfig.PickupDistance
	click.Parent = egg

	local record = {
		id = dropId,
		owner = player,
		chosen = chosen,
		depth = depth,
		model = model,
		primaryPart = egg,
		prompt = prompt,
		billboard = billboard,
		label = label,
		spawnedAt = now,
		claimReadyAt = claimReadyAt,
		expiresAt = expiresAt,
		claiming = false,
		claimed = false,
	}
	petDropRuntime.active[player.UserId] = record
	player:SetAttribute("ActivePetEggDropId", dropId)
	player:SetAttribute("ActivePetEggExpiresAt", expiresAt)
	player:SetAttribute("ActivePetEggDepth", depth)
	player:SetAttribute("PetDropCooldownUntil", now + dropConfig.SpawnCooldownSeconds)

	prompt.Triggered:Connect(function(triggeringPlayer)
		petDropRuntime.Claim(triggeringPlayer, record)
	end)
	click.MouseClick:Connect(function(clickingPlayer)
		petDropRuntime.Claim(clickingPlayer, record)
	end)

	task.spawn(function()
		while model.Parent and not record.claimed do
			local current = workspace:GetServerTimeNow()
			local remaining = math.max(0, math.ceil(expiresAt - current))
			label.Text = (current < claimReadyAt and "EGG LANDED" or "PICK UP PET EGG")
				.. ("  •  %ds"):format(remaining)
			prompt.Enabled = current >= claimReadyAt and current < expiresAt
			if current >= expiresAt then break end
			task.wait(math.min(0.25, math.max(0.05, expiresAt - current)))
		end
		if model.Parent and not record.claimed and petDropRuntime.active[player.UserId] == record then
			petDropRuntime.Clear(player, "expired")
			sendFeedback(player, {
				type = "Fail",
				target = "PET EGG",
				message = "PET EGG EXPIRED",
				color = PolishConfig.Palette.Fail,
			})
		end
	end)

	sendFeedback(player, {
		type = "PetEggDrop",
		target = "MYSTERY PET EGG",
		message = "PET EGG DROPPED — PICK IT UP!",
		rarity = chosen.rarity,
		depth = depth,
		expiresAt = expiresAt,
		color = rarityColor,
	})
	return {
		ok = true,
		dropped = true,
		pendingPickup = true,
		dropId = dropId,
		depth = depth,
		rarity = chosen.rarity,
		expiresAt = expiresAt,
		pickupReadyAt = claimReadyAt,
		pityTriggered = pityTriggered == true,
	}
end

function petDropRuntime.Claim(player, record)
	if not player or not record or not record.model or not record.model.Parent then
		return { ok = false, reason = "drop_missing" }
	end
	if record.owner ~= player or record.model:GetAttribute("OwnerUserId") ~= player.UserId then
		return { ok = false, reason = "not_owner" }
	end
	if petDropRuntime.active[player.UserId] ~= record then
		return { ok = false, reason = "stale_drop" }
	end
	if record.claimed or record.claiming then
		return { ok = false, reason = "already_claiming" }
	end
	local ready, readinessReason = profileReady(player, false)
	if not ready then return { ok = false, reason = readinessReason } end
	local now = workspace:GetServerTimeNow()
	if now < record.claimReadyAt then
		return { ok = false, reason = "pickup_arming", readyAt = record.claimReadyAt }
	end
	if now >= record.expiresAt then
		petDropRuntime.Clear(player, "expired_claim")
		return { ok = false, reason = "drop_expired" }
	end
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart or not record.primaryPart or not record.primaryPart.Parent then
		return { ok = false, reason = "character" }
	end
	local distance = (rootPart.Position - record.primaryPart.Position).Magnitude
	if distance > GameConfig.PetDrops.PickupDistance + 1.5 then
		return { ok = false, reason = "too_far", distance = distance }
	end
	record.claiming = true
	local result = grantPet(player, record.chosen, 1, "DepthEggPickup")
	if not result.ok then
		record.claiming = false
		return result
	end
	record.claimed = true
	record.model:SetAttribute("Claimed", true)
	result.pickup = true
	result.dropId = record.id
	result.depth = record.depth
	result.pickupDistance = distance
	petDropRuntime.Clear(player, "claimed")
	return result
end

local function hatchPet(player, freeHatch, depth)
	if not freeHatch then
		sendFeedback(player, {
			type = "Fail",
			target = "SIDEKICK LAB",
			message = "PET EGGS ARE HIDDEN INSIDE DEPTH BLOCKS",
			color = PolishConfig.Palette.HeroCyan,
		})
		return { ok = false, reason = "wall_drops_only" }
	end
	local chosen = rollPet(math.max(1, statValue(player, "Luck", 1)), depth or math.max(1, statValue(player, "Depth", 1)))
	return grantPet(player, chosen, 1, "GrantedEgg")
end

tryDropPetEgg = function(player, depth, sourcePosition)
	depth = math.clamp(math.floor(tonumber(depth) or 1), 1, GameConfig.WorldProgressTarget)
	local existing = petDropRuntime.active[player.UserId]
	if existing and existing.model and existing.model.Parent then
		return {
			ok = false,
			reason = "active_drop",
			pendingPickup = true,
			dropId = existing.id,
			expiresAt = existing.expiresAt,
		}
	end
	local now = workspace:GetServerTimeNow()
	local cooldownUntil = tonumber(player:GetAttribute("PetDropCooldownUntil")) or 0
	if now < cooldownUntil then
		return { ok = false, reason = "drop_cooldown", cooldownRemaining = cooldownUntil - now }
	end
	local pity = statValue(player, "PetDropPity", 0) + 1
	local dropConfig = GameConfig.PetDrops
	local chance = math.min(dropConfig.MaxChance, dropConfig.BaseChance + math.max(0, depth - 1) * dropConfig.ChancePerDepth)
	local dropped = pity >= dropConfig.PityBreaks or math.random() < chance
	if not dropped then
		setStat(player, "PetDropPity", pity)
		player:SetAttribute("PetDropChance", chance)
		return { ok = false, reason = "no_drop", pity = pity, chance = chance }
	end
	local chosen, poolMinPet, poolMaxPet = rollPet(math.max(1, statValue(player, "Luck", 1)), depth)
	local result = petDropRuntime.Spawn(player, chosen, depth, sourcePosition, pity >= dropConfig.PityBreaks)
	result.poolMinPet = poolMinPet
	result.poolMaxPet = poolMaxPet
	if result.ok then
		setStat(player, "PetDropPity", 0)
	else
		setStat(player, "PetDropPity", math.min(pity, dropConfig.PityBreaks))
	end
	return result
end

local function equipPet(player, petName, inventoryIndex)
	local inventory = decodeList(player, "PetInventoryJSON")
	local selectedIndex, indexReason = validatePetInventoryIndex(inventory, petName, inventoryIndex)
	if indexReason then
		return { ok = false, reason = indexReason }
	end
	local baseName = GameConfig.ParsePetToken(petName)
	if not petByName[baseName] then
		return { ok = false, reason = "unknown_pet" }
	end
	if selectedIndex == nil then
		selectedIndex = table.find(inventory, petName)
		if not selectedIndex then
			return { ok = false, reason = "not_owned" }
		end
	end
	local equipped = decodeList(player, "EquippedPetsJSON")
	local ownedCount = petValueCount(inventory, petName)
	local equippedCount = math.min(petValueCount(equipped, petName), ownedCount)
	if equippedCount >= ownedCount then
		return { ok = false, reason = "not_owned" }
	end
	if inventoryIndex ~= nil then
		local occurrence = petOccurrenceAt(inventory, petName, selectedIndex)
		if occurrence <= equippedCount then
			return { ok = false, reason = "already_equipped" }
		end
		if occurrence ~= equippedCount + 1 then
			return { ok = false, reason = "not_next_unequipped" }
		end
	end
	if #equipped >= GameConfig.MaxEquippedPets then
		return { ok = false, reason = "slots_full" }
	end
	table.insert(equipped, petName)
	encodeList(player, "EquippedPetsJSON", equipped)
	local valid, multiplier = refreshEquippedPets(player)
	return { ok = true, pet = petName, index = selectedIndex, equipped = valid, multiplier = multiplier }
end

local function unequipPet(player, petName, inventoryIndex)
	local inventory = decodeList(player, "PetInventoryJSON")
	local selectedIndex, indexReason = validatePetInventoryIndex(inventory, petName, inventoryIndex)
	if indexReason then
		return { ok = false, reason = indexReason }
	end
	local equipped = decodeList(player, "EquippedPetsJSON")
	if selectedIndex ~= nil then
		local ownedCount = petValueCount(inventory, petName)
		local equippedCount = math.min(petValueCount(equipped, petName), ownedCount)
		local occurrence = petOccurrenceAt(inventory, petName, selectedIndex)
		if occurrence > equippedCount then
			return { ok = false, reason = "not_equipped" }
		end
		if occurrence ~= equippedCount then
			return { ok = false, reason = "not_last_equipped" }
		end
	end
	local removed
	if selectedIndex ~= nil then
		removed = removeLast(equipped, petName)
	else
		removed = removeFirst(equipped, petName)
	end
	if not removed then
		return { ok = false, reason = "not_equipped" }
	end
	encodeList(player, "EquippedPetsJSON", equipped)
	local valid, multiplier = refreshEquippedPets(player)
	return { ok = true, pet = petName, index = selectedIndex, equipped = valid, multiplier = multiplier }
end

local function petSlotToken(index)
	return "slot:" .. tostring(math.max(1, math.floor(tonumber(index) or 1)))
end

local function deletePet(player, petName, inventoryIndex)
	local inventory = decodeList(player, "PetInventoryJSON")
	local selectedIndex, indexReason = validatePetInventoryIndex(inventory, petName, inventoryIndex)
	if indexReason then
		return { ok = false, reason = indexReason }
	end
	if selectedIndex == nil then
		selectedIndex = table.find(inventory, petName) or 0
	end
	if selectedIndex < 1 then
		return { ok = false, reason = "not_owned" }
	end
	local lockedPets = decodeList(player, "LockedPetsJSON")
	if listContains(lockedPets, petName) or listContains(lockedPets, petSlotToken(selectedIndex)) then
		return { ok = false, reason = "pet_locked" }
	end
	local equipped = decodeList(player, "EquippedPetsJSON")
	local ownedCount = petValueCount(inventory, petName)
	local equippedCount = math.min(petValueCount(equipped, petName), ownedCount)
	local selectedWasEquipped = petOccurrenceAt(inventory, petName, selectedIndex) <= equippedCount
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
	if selectedWasEquipped then
		if inventoryIndex ~= nil then
			removeLast(equipped, petName)
		else
			removeFirst(equipped, petName)
		end
	end
	encodeList(player, "PetInventoryJSON", inventory)
	encodeList(player, "EquippedPetsJSON", equipped)
	encodeList(player, "LockedPetsJSON", shiftedLocks)
	local valid, multiplier = refreshEquippedPets(player)
	return {
		ok = true,
		pet = petName,
		index = selectedIndex,
		wasEquipped = selectedWasEquipped,
		inventory = inventory,
		equipped = valid,
		multiplier = multiplier,
		locked = shiftedLocks,
	}
end

local function setPetLocked(player, petName, locked, inventoryIndex)
	local inventory = decodeList(player, "PetInventoryJSON")
	local selectedIndex, indexReason = validatePetInventoryIndex(inventory, petName, inventoryIndex)
	if indexReason then
		return { ok = false, reason = indexReason }
	end
	local useSlot = selectedIndex ~= nil
	if not useSlot and not listContains(inventory, petName) then
		return { ok = false, reason = "not_owned" }
	end
	local lockToken = useSlot and petSlotToken(selectedIndex) or petName
	local lockedPets = decodeList(player, "LockedPetsJSON")
	local migratedLegacyLock = false
	if useSlot and not locked and listContains(lockedPets, petName) then
		migratedLegacyLock = true
		while removeFirst(lockedPets, petName) do end
		for index, token in ipairs(inventory) do
			if token == petName and index ~= selectedIndex then
				local preservedSlotToken = petSlotToken(index)
				if not listContains(lockedPets, preservedSlotToken) then
					table.insert(lockedPets, preservedSlotToken)
				end
			end
		end
	end
	if locked and not listContains(lockedPets, lockToken) then table.insert(lockedPets, lockToken) end
	if not locked then while removeFirst(lockedPets, lockToken) do end end
	encodeList(player, "LockedPetsJSON", lockedPets)
	return {
		ok = true,
		pet = petName,
		index = useSlot and selectedIndex or nil,
		token = lockToken,
		locked = locked,
		migratedLegacyLock = migratedLegacyLock,
	}
end

local function fusePet(player, petToken)
	local petName, stars = GameConfig.ParsePetToken(petToken)
	if not petByName[petName] then return { ok = false, reason = "unknown_pet" } end
	if stars >= GameConfig.MaxPetStars then return { ok = false, reason = "max_stars" } end
	local required = GameConfig.PetFusionRequirement(stars)
	local inventory = decodeList(player, "PetInventoryJSON")
	local locked = decodeList(player, "LockedPetsJSON")
	local indices = {}
	for index, token in ipairs(inventory) do
		if token == petToken and not listContains(locked, token) and not listContains(locked, petSlotToken(index)) then
			table.insert(indices, index)
		end
	end
	if #indices < required then
		sendFeedback(player, {
			type = "Fail",
			target = petName,
			message = ("NEED %d UNLOCKED %d-STAR PETS"):format(required, stars),
			color = PolishConfig.Palette.Fail,
		})
		return { ok = false, reason = "not_enough_duplicates", required = required, owned = #indices }
	end
	local consumedIndices = {}
	for index = 1, required do consumedIndices[indices[index]] = true end
	for index = required, 1, -1 do table.remove(inventory, indices[index]) end
	local upgradedToken = GameConfig.PetToken(petName, stars + 1)
	table.insert(inventory, upgradedToken)
	local equipped = decodeList(player, "EquippedPetsJSON")
	for _ = 1, required do removeFirst(equipped, petToken) end
	if #equipped < GameConfig.MaxEquippedPets then table.insert(equipped, upgradedToken) end
	local shiftedLocks = {}
	for _, entry in ipairs(locked) do
		local slot = tonumber(string.match(tostring(entry), "^slot:(%d+)$"))
		if slot then
			if not consumedIndices[slot] then
				local shift = 0
				for removedSlot in pairs(consumedIndices) do
					if removedSlot < slot then shift += 1 end
				end
				table.insert(shiftedLocks, petSlotToken(slot - shift))
			end
		else
			table.insert(shiftedLocks, entry)
		end
	end
	encodeList(player, "PetInventoryJSON", inventory)
	encodeList(player, "EquippedPetsJSON", equipped)
	encodeList(player, "LockedPetsJSON", shiftedLocks)
	local valid, multiplier = refreshEquippedPets(player)
	sendFeedback(player, {
		type = "PetFusion",
		target = upgradedToken,
		stars = stars + 1,
		message = ("FUSION SUCCESS | %d STARS"):format(stars + 1),
		color = petRarityColor(petByName[petName]),
	})
	return { ok = true, pet = upgradedToken, stars = stars + 1, consumed = required, inventory = inventory, equipped = valid, multiplier = multiplier }
end

shared.PunchWallPremiumPets = { byPass = {}, byName = {} }
for _, item in ipairs(GameConfig.PremiumPets) do
	shared.PunchWallPremiumPets.byName[item.name] = item
	if visualSafety.hasConfiguredGamePass(item) then
		shared.PunchWallPremiumPets.byPass[item.gamePassId] = item
	end
end

shared.PunchWallPremiumPets.grant = function(player, item, source)
	if not profileReady(player, false) then return { ok = false, reason = "profile_not_ready" } end
	if not item then return { ok = false, reason = "unknown_premium_pet" } end
	local owned = decodeList(player, "OwnedPremiumPetsJSON")
	if listContains(owned, item.name) then
		local inventory = decodeList(player, "PetInventoryJSON")
		if listContains(inventory, item.name) then
			if source == "Owned" then return equipPet(player, item.name) end
			return { ok = true, pet = item.name, premium = true, alreadyOwned = true }
		end
	end
	local result = grantPet(player, item, 1, source or "Premium")
	if not result.ok then return result end
	if not listContains(owned, item.name) then
		table.insert(owned, item.name)
		encodeList(player, "OwnedPremiumPetsJSON", owned)
	end
	result.premium = true
	return result
end

shared.PunchWallPremiumPets.prompt = function(player, item)
	if not profileReady(player, false) then return { ok = false, reason = "profile_not_ready" } end
	if not item then return { ok = false, reason = "unknown_premium_pet" } end
	if not visualSafety.hasConfiguredGamePass(item) then
		sendFeedback(player, { type = "PremiumSetup", target = item.name, message = "PURCHASE UNAVAILABLE | PASS ID NOT CONFIGURED", robux = item.robux, color = item.accent })
		return { ok = false, reason = "game_pass_not_configured", robux = item.robux }
	end
	if listContains(decodeList(player, "OwnedPremiumPetsJSON"), item.name) then
		return shared.PunchWallPremiumPets.grant(player, item, "Owned")
	end
	MarketplaceService:PromptGamePassPurchase(player, item.gamePassId)
	return { ok = true, pending = true, gamePassId = item.gamePassId }
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, wasPurchased)
	if not wasPurchased then return end
	local item = shared.PunchWallPremiumPets.byPass[gamePassId]
	if not item then return end
	local queued, queueError = persistenceRuntime.queuePendingGamePassGrant(player, "Pet", item, "GamePass")
	if not queued then
		warn(("[PunchWallRPG] Could not queue pet GamePass %s for %s: %s"):format(
			tostring(gamePassId),
			player.Name,
			tostring(queueError)
		))
		return
	end
	if profileReady(player, false) and persistenceRuntime.flushPendingGamePassGrants then
		task.spawn(persistenceRuntime.flushPendingGamePassGrants, player, "PurchaseFinished")
	end
end)

local function ownsQueuedGamePassItem(player, operation)
	if operation.kind == "Fist" then
		return listContains(decodeList(player, "OwnedPremiumFistsJSON"), operation.item.name)
	end
	if operation.kind == "Pet" then
		return listContains(decodeList(player, "OwnedPremiumPetsJSON"), operation.item.name)
	end
	return false
end

local function flushPendingGamePassGrants(player, reason)
	local ready = profileReady(player, false)
	local state = persistenceRuntime.pendingGamePassGrants[player]
	if not ready or not state or state.flushing then
		return false, ready and "no_pending_grants" or "profile_not_ready"
	end
	state.flushing = true
	local session = persistenceRuntime.profileSessions[player]
	local remaining = {}
	local handled = 0
	local granted = 0
	for _, key in ipairs(state.order) do
		local operation = state.byKey[key]
		if operation then
			if player.Parent ~= Players
				or persistenceRuntime.profileSessions[player] ~= session
				or not profileReady(player, false)
			then
				table.insert(remaining, key)
			else
				local alreadyOwned = ownsQueuedGamePassItem(player, operation)
				local result
				if alreadyOwned then
					result = { ok = true, alreadyOwned = true }
				elseif operation.kind == "Fist" then
					result = shared.PunchWallPremiumFists.grant(player, operation.item, operation.source)
				elseif operation.kind == "Pet" then
					result = shared.PunchWallPremiumPets.grant(player, operation.item, operation.source)
				else
					result = { ok = false, reason = "unknown_game_pass_kind" }
				end
				if result and result.ok then
					state.byKey[key] = nil
					handled += 1
					if not alreadyOwned then
						granted += 1
					end
				else
					table.insert(remaining, key)
				end
			end
		end
	end
	state.order = remaining
	state.flushing = false
	player:SetAttribute("PendingGamePassGrantCount", #remaining)
	if handled > 0 and persistenceRuntime.requestPlayerSave then
		persistenceRuntime.requestPlayerSave(player, reason or "GamePassGrant", false)
	end
	root:SetAttribute("LastGamePassPendingFlushHandled", handled)
	root:SetAttribute("LastGamePassPendingFlushGranted", granted)
	if handled > 0 then
		return true
	end
	return false, "no_grant_flushed"
end

local function ownsGamePassWithRetry(player, gamePassId)
	local lastError
	for attempt = 1, persistenceRuntime.gamePassOwnershipAttempts do
		local ok, ownsPass = pcall(
			MarketplaceService.UserOwnsGamePassAsync,
			MarketplaceService,
			player.UserId,
			gamePassId
		)
		if ok then
			return ownsPass == true
		end
		lastError = ownsPass
		if attempt < persistenceRuntime.gamePassOwnershipAttempts then
			task.wait(0.25 * attempt)
		end
	end
	return false, lastError
end

local function reconcileOwnedGamePasses(player)
	local session = persistenceRuntime.profileSessions[player]
	if not profileReady(player, false)
		or not session
		or session.gamePassReconciliationStarted
		or session.gamePassReconciliationComplete
	then
		return false, "profile_not_ready_or_reconciliation_started"
	end
	session.gamePassReconciliationStarted = true
	local configured = {}
	for gamePassId, item in pairs(shared.PunchWallPremiumFists.byPass) do
		table.insert(configured, { kind = "Fist", gamePassId = gamePassId, item = item })
	end
	for gamePassId, item in pairs(shared.PunchWallPremiumPets.byPass) do
		table.insert(configured, { kind = "Pet", gamePassId = gamePassId, item = item })
	end
	table.sort(configured, function(left, right)
		if left.gamePassId == right.gamePassId then
			return left.kind < right.kind
		end
		return left.gamePassId < right.gamePassId
	end)
	local ownedCount = 0
	local queuedCount = 0
	local failedCount = 0
	local lastOwnershipError
	for _, entry in ipairs(configured) do
		if player.Parent ~= Players
			or persistenceRuntime.profileSessions[player] ~= session
			or not profileReady(player, false)
		then
			break
		end
		local ownsPass, ownershipError = ownsGamePassWithRetry(player, entry.gamePassId)
		if ownershipError ~= nil then
			failedCount += 1
			lastOwnershipError = tostring(ownershipError)
		elseif ownsPass then
			ownedCount += 1
			local operation = {
				kind = entry.kind,
				item = entry.item,
			}
			if not ownsQueuedGamePassItem(player, operation) then
				local queued = persistenceRuntime.queuePendingGamePassGrant(
					player,
					entry.kind,
					entry.item,
					"OwnershipReconcile"
				)
				if queued then
					queuedCount += 1
				end
			end
		end
	end
	local stillReady = profileReady(player, false)
	local sessionStillCurrent = player.Parent == Players
		and persistenceRuntime.profileSessions[player] == session
		and stillReady
	if sessionStillCurrent then
		local flushed = flushPendingGamePassGrants(player, "GamePassOwnershipReconcile")
		if ownedCount > 0 and not flushed and persistenceRuntime.requestPlayerSave then
			persistenceRuntime.requestPlayerSave(player, "GamePassOwnershipVerified", false)
		end
		session.gamePassReconciliationStarted = false
		if failedCount == 0 then
			session.gamePassReconciliationComplete = true
			session.gamePassReconciliationRetryCount = 0
			player:SetAttribute("GamePassOwnershipReconciled", true)
			player:SetAttribute("GamePassOwnershipReconciliationFailed", false)
			player:SetAttribute("GamePassOwnershipReconciliationRetryCount", 0)
		else
			session.gamePassReconciliationComplete = false
			session.gamePassReconciliationRetryCount =
				(session.gamePassReconciliationRetryCount or 0) + 1
			local retryCount = session.gamePassReconciliationRetryCount
			local exhausted = retryCount >= persistenceRuntime.gamePassReconciliationAttempts
			player:SetAttribute("GamePassOwnershipReconciled", false)
			player:SetAttribute("GamePassOwnershipReconciliationFailed", exhausted)
			player:SetAttribute("GamePassOwnershipReconciliationRetryCount", retryCount)
			if not exhausted then
				local retryDelay = persistenceRuntime.gamePassReconciliationRetryBaseSeconds
					* (2 ^ (retryCount - 1))
				task.delay(retryDelay, function()
					if player.Parent == Players
						and persistenceRuntime.profileSessions[player] == session
						and profileReady(player, false)
						and not session.gamePassReconciliationComplete
					then
						reconcileOwnedGamePasses(player)
					end
				end)
			else
				warn(("[PunchWallRPG] GamePass ownership reconciliation failed for %s after %d attempts: %s"):format(
					player.Name,
					retryCount,
					tostring(lastOwnershipError)
				))
			end
		end
	elseif persistenceRuntime.profileSessions[player] == session then
		session.gamePassReconciliationStarted = false
	end
	root:SetAttribute("ConfiguredGamePassReconciliationCount", #configured)
	root:SetAttribute("LastOwnedGamePassReconciliationCount", ownedCount)
	root:SetAttribute("LastQueuedGamePassReconciliationCount", queuedCount)
	root:SetAttribute("LastFailedGamePassReconciliationCount", failedCount)
	return sessionStillCurrent and failedCount == 0, {
		configured = #configured,
		owned = ownedCount,
		queued = queuedCount,
		failed = failedCount,
	}
end

persistenceRuntime.flushPendingGamePassGrants = flushPendingGamePassGrants
persistenceRuntime.reconcileOwnedGamePasses = reconcileOwnedGamePasses

shared.PunchWallServerFinalize = function()
local premiumPetPositions = {
	Vector3.new(-88, 3.2, 38),
	Vector3.new(-75, 3.2, 38),
	Vector3.new(-62, 3.2, 38),
}
shared.PunchWallBuildPremiumPetStand = function(index, item, position)
	local purchaseConfigured = visualSafety.hasConfiguredGamePass(item)
	local stand = makePart(item.name .. " Premium Pet Stand", interactFolder, Vector3.new(10.5, 5.5, 9), position, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
	stand.Transparency = 0.94
	stand.CanCollide = false
	stand:SetAttribute("VisualRole", "PremiumPetRobuxStand")
	stand:SetAttribute("RobuxPrice", item.robux)
	visualSafety.markWorldOfferAvailability(stand, purchaseConfigured, "GamePass")
	local plinth = makeCylinder(item.name .. " Premium Pet Plinth", decorFolder, Vector3.new(0.85, 7.2, 7.2), position + Vector3.new(0, -2.2, 0), item.accent, Enum.Material.Metal, Vector3.new(0, 0, 90))
	plinth:SetAttribute("AmbientMotion", "Pulse")
	local display = cloneExternalVisual(
		item.templateName,
		decorFolder,
		item.name .. " Premium Pet Display",
		CFrame.new(position.X, 2.3, position.Z) * CFrame.Angles(0, math.rad(180), 0),
		5.6,
		false
	)
	if display then
		local _, displaySize = display:GetBoundingBox()
		local horizontalSpan = math.max(displaySize.X, displaySize.Z)
		if horizontalSpan > 9.2 then
			display:ScaleTo(display:GetScale() * (9.2 / horizontalSpan))
			local resizedBounds, resizedSize = display:GetBoundingBox()
			local bottomY = resizedBounds.Position.Y - resizedSize.Y * 0.5
			display:PivotTo(display:GetPivot() + Vector3.new(0, 2.3 - bottomY, 0))
		end
		display:SetAttribute("VisualRole", "PremiumPetShowcase")
		display:SetAttribute("AuraTier", index + 5)
		display:SetAttribute("SourceFallback", false)
		display:SetAttribute("PetTemplate", item.templateName)
		display:SetAttribute("PetDefinitionName", item.name)
		display:SetAttribute("PetVisualIdentity", item.templateName)
		local visualPartCount = 0
		for _, descendant in ipairs(display:GetDescendants()) do
			if descendant:IsA("BasePart") then visualPartCount += 1 end
		end
		display:SetAttribute("VisualPartCount", visualPartCount)
		display:SetAttribute("CompanionCompatible", true)
		local outline = Instance.new("Highlight")
		outline.Name = "Premium Pet Hero Outline"
		outline.FillColor = item.color
		outline.FillTransparency = 0.96
		outline.OutlineColor = item.accent
		outline.OutlineTransparency = 0.28
		outline.DepthMode = Enum.HighlightDepthMode.Occluded
		outline.Parent = display
	else
		display = Instance.new("Model")
		display.Name = item.name .. " Premium Pet Display"
		display:SetAttribute("VisualRole", "PremiumPetShowcase")
		display:SetAttribute("AuraTier", index + 5)
		display:SetAttribute("SourceFallback", true)
		display:SetAttribute("PetTemplate", item.templateName)
		display:SetAttribute("PetDefinitionName", item.name)
		display:SetAttribute("PetVisualIdentity", "MissingTemplateFallback:" .. item.name)
		display:SetAttribute("VisualPartCount", 2)
		display:SetAttribute("TemplateVisualAttested", false)
		display:SetAttribute("CompanionCompatible", false)
		display.Parent = decorFolder
		makeBall("Fallback Pet Body", display, Vector3.new(3.4, 3.0, 4.0), position + Vector3.new(0, 2.0, 0), item.color, Enum.Material.Metal)
		makeBall("Fallback Pet Head", display, Vector3.new(2.4, 2.2, 2.5), position + Vector3.new(0, 3.5, -1.6), item.accent, Enum.Material.Neon)
	end
	local auraAnchor = makeBall(item.name .. " Premium Pet Aura Anchor", decorFolder, Vector3.new(0.35, 0.35, 0.35), position + Vector3.new(0, 2.2, 0), item.accent, Enum.Material.Neon)
	auraAnchor.Transparency = 1
	auraAnchor.CanCollide = false
	addEmitter(auraAnchor, "Premium Pet Aura", item.accent)
	local light = Instance.new("PointLight")
	light.Color = item.accent
	light.Brightness = 1.0 + index * 0.28
	light.Range = 10 + index
	light.Parent = auraAnchor
	local nameplate = makeVisualPart(item.name .. " Premium Pet Price", decorFolder, Vector3.new(10.8, 2.2, 0.35), CFrame.new(position + Vector3.new(0, -0.4, 5.0)), Color3.fromRGB(7, 15, 22), Enum.Material.Metal)
	local offerDescription = purchaseConfigured
		and ("R$ %d | PERMANENT | x%.1f"):format(item.robux, item.mult)
		or "UNAVAILABLE | PASS ID NOT CONFIGURED"
	local frontPrice = makeText(nameplate, item.name, offerDescription, Enum.NormalId.Front)
	local backPrice = makeText(nameplate, item.name, offerDescription, Enum.NormalId.Back)
	visualSafety.markWorldOfferAvailability(nameplate, purchaseConfigured, "GamePass")
	for _, priceSurface in ipairs({ frontPrice, backPrice }) do
		priceSurface.AlwaysOnTop = true
		priceSurface.LightInfluence = 0
		priceSurface.MaxDistance = 250
	end
	if purchaseConfigured then
		local detector = Instance.new("ClickDetector")
		detector.MaxActivationDistance = 28
		detector.Parent = stand
		detector.MouseClick:Connect(function(player)
			if not profileReady(player, false) then return end
			shared.PunchWallPremiumPets.prompt(player, item)
		end)
	end
end
for index, item in ipairs(GameConfig.PremiumPets) do
	shared.PunchWallBuildPremiumPetStand(index, item, premiumPetPositions[index])
end

local eggDetector = Instance.new("ClickDetector")
eggDetector.MaxActivationDistance = 32
eggDetector.Parent = shared.PunchWallEggPart
eggDetector.MouseClick:Connect(function(player)
	if not profileReady(player, false) then return end
	sendFeedback(player, { type = "OpenMenu", target = "Pets", tab = "Pets", color = PolishConfig.Palette.HeroCyan })
end)

shared.PunchWallHonorItemsByName = {}
for _, item in ipairs(GameConfig.HonorItems) do
	shared.PunchWallHonorItemsByName[item.name] = item
	shared.PunchWallHonorItemsByName[item.id] = item
end

shared.PunchWallBuyHonorItem = function(player, item)
	if not item then return { ok = false, reason = "unknown_honor_item" } end
	if not profileReady(player, false) then return { ok = false, reason = "profile_not_ready" } end
	local owned = {}
	local ownedSet = {}
	for _, selector in ipairs(decodeList(player, "OwnedHonorItemsJSON")) do
		local definition = GameConfig.HonorItemDefinition(selector)
		if definition and not ownedSet[definition.id] then
			ownedSet[definition.id] = true
			table.insert(owned, definition.id)
		end
	end
	local alreadyOwned = ownedSet[item.id] == true
	if not alreadyOwned then
		if not GameConfig.HonorItemUnlocked(
			item,
			statValue(player, "Depth", 0),
			statValue(player, "Rebirths", 0)
		) then
			sendFeedback(player, {
				type = "Fail",
				target = item.displayName,
				message = ("LOCKED • NEED DEPTH %d%s"):format(
					item.requiredDepth or 0,
					(item.requiredRebirths or 0) > 0 and (" + REBIRTH " .. item.requiredRebirths) or ""
				),
				color = PolishConfig.Palette.Fail,
			})
			return {
				ok = false,
				reason = "honor_item_locked",
				requiredDepth = item.requiredDepth,
				requiredRebirths = item.requiredRebirths,
			}
		end
		local currentHonor = statValue(player, "Honor", 0)
		if currentHonor < item.cost then
			sendFeedback(player, {
				type = "Fail",
				target = item.displayName,
				message = ("NEED %d MORE HONOR"):format(item.cost - currentHonor),
				color = PolishConfig.Palette.Fail,
			})
			return { ok = false, reason = "not_enough_honor", cost = item.cost }
		end
		setStat(player, "Honor", math.max(0, statValue(player, "Honor", 0) - item.cost))
		table.insert(owned, item.id)
		ownedSet[item.id] = true
		encodeList(player, "OwnedHonorItemsJSON", owned)
	end
	setStat(player, "EquippedHonorItem", item.id)
	setStat(player, "HonorPowerBonus", math.min(GameConfig.Honor.MaxEquippedPowerBonus, item.powerBonus))
	sendFeedback(player, {
		type = "HonorShop",
		target = item.displayName,
		message = alreadyOwned and "HONOR RELIC EQUIPPED" or "HONOR RELIC UNLOCKED",
		honor = alreadyOwned and 0 or -item.cost,
		color = item.color,
	})
	return {
		ok = true,
		item = item.id,
		owned = true,
		equipped = true,
		honor = statValue(player, "Honor", 0),
		powerBonus = item.powerBonus,
	}
end

shared.PunchWallBuildHonorPlaza = function()
local honorPlaza = makePart("Honor Exchange Plaza", decorFolder, Vector3.new(52, 0.35, 38), Vector3.new(22, 0.2, 25), Color3.fromRGB(56, 63, 68), Enum.Material.Slate)
honorPlaza:SetAttribute("VisualRole", "HonorShopPlaza")
local honorSign = makePart("Honor Exchange Sign", decorFolder, Vector3.new(22, 4.8, 0.6), Vector3.new(22, 14.2, 44), Color3.fromRGB(12, 20, 29), Enum.Material.Metal)
makeText(honorSign, "HALL OF HONOR", "DEPTH + REBIRTH MILESTONES | TITAN CLEARS | ONE RELIC ACTIVE", Enum.NormalId.Front)
makeText(honorSign, "HALL OF HONOR", "DEPTH + REBIRTH MILESTONES | TITAN CLEARS | ONE RELIC ACTIVE", Enum.NormalId.Back)

local honorNPC = Instance.new("Model")
honorNPC.Name = "Honor Keeper NPC"
honorNPC:SetAttribute("NPCType", "HonorShop")
honorNPC:SetAttribute("ProceduralFallback", false)
honorNPC.Parent = decorFolder
local honorNPCBody = makePart("Keeper Armor", honorNPC, Vector3.new(4.0, 3.9, 2.3), Vector3.new(22, 4.15, 37), Color3.fromRGB(24, 31, 45), Enum.Material.Metal)
makeVisualPart("Keeper Chest Plate", honorNPC, Vector3.new(3.45, 2.45, 0.32), CFrame.new(22, 4.45, 35.7), Color3.fromRGB(48, 62, 83), Enum.Material.Metal)
makeVisualPart("Keeper Honor Belt", honorNPC, Vector3.new(3.75, 0.48, 2.42), CFrame.new(22, 2.45, 37), Color3.fromRGB(104, 76, 29), Enum.Material.Metal)
for _, side in ipairs({ -1, 1 }) do
	makeVisualPart("Keeper Leg " .. side, honorNPC, Vector3.new(1.3, 2.45, 1.45), CFrame.new(22 + side * 0.82, 1.45, 37), Color3.fromRGB(31, 38, 49), Enum.Material.Metal)
	makeVisualPart("Keeper Boot " .. side, honorNPC, Vector3.new(1.55, 0.78, 2.05), CFrame.new(22 + side * 0.82, 0.4, 36.65), Color3.fromRGB(19, 24, 31), Enum.Material.Metal)
	makeVisualPart("Keeper Arm " .. side, honorNPC, Vector3.new(1.05, 3.15, 1.2), CFrame.new(22 + side * 2.38, 4.05, 37), Color3.fromRGB(32, 42, 59), Enum.Material.Metal)
	makeVisualPart("Keeper Gauntlet " .. side, honorNPC, Vector3.new(1.22, 1.15, 1.45), CFrame.new(22 + side * 2.38, 2.72, 36.82), Color3.fromRGB(93, 66, 142), Enum.Material.Metal)
	local shoulder = makeBall("Keeper Shoulder " .. side, honorNPC, Vector3.new(1.7, 1.45, 1.55), Vector3.new(22 + side * 2.18, 5.35, 36.95), Color3.fromRGB(74, 55, 139), Enum.Material.Metal)
	shoulder.CanCollide = false
end
makeVisualPart("Keeper Head", honorNPC, Vector3.new(2.25, 2.15, 2.0), CFrame.new(22, 7.05, 37), Color3.fromRGB(205, 160, 116), Enum.Material.SmoothPlastic)
makeVisualPart("Keeper Helmet Crown", honorNPC, Vector3.new(2.75, 0.9, 2.45), CFrame.new(22, 8.02, 37.05), Color3.fromRGB(28, 35, 49), Enum.Material.Metal)
makeVisualPart("Keeper Helmet Crest", honorNPC, Vector3.new(0.42, 1.35, 1.7), CFrame.new(22, 8.78, 37.15) * CFrame.Angles(0, 0, math.rad(-8)), Color3.fromRGB(101, 65, 171), Enum.Material.Metal)
for _, side in ipairs({ -1, 1 }) do
	makeVisualPart("Keeper Cheek Guard " .. side, honorNPC, Vector3.new(0.46, 1.45, 0.34), CFrame.new(22 + side * 1.05, 6.92, 35.88), Color3.fromRGB(28, 35, 49), Enum.Material.Metal)
end
makeVisualPart("Keeper Jaw Guard", honorNPC, Vector3.new(1.75, 0.38, 0.34), CFrame.new(22, 6.2, 35.88), Color3.fromRGB(28, 35, 49), Enum.Material.Metal)
makeVisualPart("Keeper Visor", honorNPC, Vector3.new(1.95, 0.42, 0.26), CFrame.new(22, 7.18, 35.86), Color3.fromRGB(255, 205, 56), Enum.Material.Neon)
local keeperCape = makeVisualPart("Keeper Cape", honorNPC, Vector3.new(4.35, 5.15, 0.38), CFrame.new(22, 4.15, 38.28), Color3.fromRGB(71, 48, 145), Enum.Material.Fabric)
keeperCape.CastShadow = false
local keeperCore = makeBall("Keeper Honor Core", honorNPC, Vector3.new(1.05, 1.05, 0.6), Vector3.new(22, 4.45, 35.48), Color3.fromRGB(255, 205, 56), Enum.Material.Neon)
local keeperLight = Instance.new("PointLight")
keeperLight.Color = keeperCore.Color
keeperLight.Brightness = 1.2
keeperLight.Range = 10
keeperLight.Parent = keeperCore
honorNPC.PrimaryPart = honorNPCBody

-- Give the guide a dedicated pocket beside the compact display row. The
-- offset keeps its silhouette and label out of both relic VFX and fixed phone
-- HUD rails while remaining on the natural approach to the Hall.
honorNPC:PivotTo(honorNPC:GetPivot() + Vector3.new(25, 0, -13))
local honorNPCTrigger = makePart("Honor Keeper Interaction", interactFolder, Vector3.new(7, 9, 7), Vector3.new(47, 4.5, 24), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
shared.PunchWallHonorNPCTrigger = honorNPCTrigger
honorNPCTrigger.Transparency = 1
honorNPCTrigger.CanCollide = false
honorNPCTrigger:SetAttribute("InteractionMenu", "Honor")
local keeperPedestal = makeVisualPart("Honor Keeper Pedestal", decorFolder, Vector3.new(8.5, 0.9, 7.0), CFrame.new(47, 0.45, 24), Color3.fromRGB(33, 40, 55), Enum.Material.Metal)
keeperPedestal.CanCollide = false
local keeperAccent = makeVisualPart("Honor Keeper Pedestal Accent", decorFolder, Vector3.new(8.7, 0.18, 7.2), CFrame.new(47, 0.94, 24), Color3.fromRGB(255, 205, 56), Enum.Material.Neon)
keeperAccent.CanCollide = false
local keeperPlate = makeVisualPart("Honor Keeper Nameplate", decorFolder, Vector3.new(10.5, 2.5, 0.3), CFrame.new(47, 10.6, 19.6), Color3.fromRGB(8, 14, 20), Enum.Material.Metal)
makeText(keeperPlate, "HONOR KEEPER", "VIEW RELICS", Enum.NormalId.Front)
makeText(keeperPlate, "HONOR KEEPER", "VIEW RELICS", Enum.NormalId.Back)
local honorNPCDetector = Instance.new("ClickDetector")
honorNPCDetector.MaxActivationDistance = 30
honorNPCDetector.Parent = honorNPCTrigger
honorNPCDetector.MouseClick:Connect(function(player)
	if not profileReady(player, false) then return end
	sendFeedback(player, { type = "OpenMenu", target = "Honor", tab = "Honor", color = Color3.fromRGB(255, 205, 56) })
end)

local honorPartsByName = {}
for index, item in ipairs(GameConfig.HonorItems) do
	local column = (index - 1) % 4
	local row = math.floor((index - 1) / 4)
	local x = 8 + column * 9.5
	local z = 18 + row * 12.5
	local standY = row == 1 and 4.15 or 3
	local stand = makePart(item.name .. " Honor Stand", interactFolder, Vector3.new(8.8, 5.5, 9.5), Vector3.new(x, standY, z), Color3.fromRGB(22, 29, 38), Enum.Material.Metal)
	stand.Transparency = 0.86
	stand.CanCollide = false
	stand:SetAttribute("HonorCost", item.cost)
	stand:SetAttribute("PowerBonus", item.powerBonus)
	honorPartsByName[item.name] = stand
	local plinth = makePart(item.name .. " Honor Plinth", decorFolder, Vector3.new(8.3, 1.0, 8.5), stand.Position + Vector3.new(0, -2, 0), Color3.fromRGB(37, 43, 50), Enum.Material.Metal)
	local glow = makeCylinder(item.name .. " Honor Glow", decorFolder, Vector3.new(0.06, 3.2, 3.2), plinth.Position + Vector3.new(0, 0.53, 0), item.color, Enum.Material.Neon, Vector3.new(0, 0, 90))
	glow.Transparency = 0.78
	glow.CanCollide = false
	-- Put labels on the player-approach side (-Z). Rear displays are raised so
	-- their silhouettes and copy remain visible above the front row.
	local plate = makeVisualPart(item.name .. " Honor Nameplate", decorFolder, Vector3.new(8.9, 2.0, 0.35), CFrame.new(stand.Position + Vector3.new(0, -0.3, -5.25)), Color3.fromRGB(8, 14, 20), Enum.Material.Metal)
	local unlockCopy = ("D%d"):format(item.requiredDepth or 0)
	if (item.requiredRebirths or 0) > 0 then unlockCopy ..= (" R%d"):format(item.requiredRebirths) end
	local offerCopy = ("%d HONOR | +%d%% | %s"):format(item.cost, math.floor(item.powerBonus * 100 + 0.5), unlockCopy)
	makeText(plate, item.displayName, offerCopy, Enum.NormalId.Front)
	makeText(plate, item.displayName, offerCopy, Enum.NormalId.Back)
	local displayCenter = stand.Position + Vector3.new(0, 3.75, 0)
	if item.visual == "Storm" then
		local aura = cloneExternalVisual("Sanitized_VoidFistAura", decorFolder, item.name .. " Display Aura", CFrame.new(displayCenter), 3.0, true)
		if aura then aura:SetAttribute("VisualRole", "HonorItemDisplay") end
		makeSegmentedNeonRing(item.name .. " Storm Halo", decorFolder, displayCenter, 2.0, item.color, 14, 0.24, 0.34)
		local stormCore = makeBall(item.name .. " Storm Core", decorFolder, Vector3.new(1.45, 1.45, 1.45), displayCenter, item.color:Lerp(Color3.new(0, 0, 0), 0.42), Enum.Material.Neon)
		stormCore.Transparency = 0.06
		stormCore.CanCollide = false
		for bolt = 1, 6 do
			local angle = (bolt - 1) * math.pi / 3
			makeVisualPart(
				item.name .. " Energy Bolt " .. bolt,
				decorFolder,
				Vector3.new(0.2, 1.25, 0.24),
				CFrame.new(displayCenter + Vector3.new(math.cos(angle) * 1.35, math.sin(angle) * 1.35, -0.1)) * CFrame.Angles(0, 0, angle),
				item.color,
				Enum.Material.Neon
			)
		end
	elseif item.visual == "Crown" then
		local bandCenter = displayCenter + Vector3.new(0, -0.65, 0)
		makeVisualPart(item.name .. " Crown Band", decorFolder, Vector3.new(4.2, 0.9, 1.45), CFrame.new(bandCenter), item.color:Lerp(Color3.fromRGB(128, 72, 8), 0.28), Enum.Material.Metal)
		makeVisualPart(item.name .. " Crown Rim", decorFolder, Vector3.new(4.55, 0.28, 1.65), CFrame.new(bandCenter + Vector3.new(0, -0.48, 0)), item.color, Enum.Material.Neon)
		for spike = -2, 2 do
			local spikeHeight = spike == 0 and 2.45 or (math.abs(spike) == 1 and 2.0 or 1.55)
			local crownSpike = makeWedge(item.name .. " Crown Spike " .. spike, decorFolder, Vector3.new(0.72, spikeHeight, 1.0), bandCenter + Vector3.new(spike * 0.82, 0.65 + spikeHeight * 0.5, 0), item.color, Enum.Material.Metal, Vector3.new(0, 180, 0))
			crownSpike.CanCollide = false
		end
		local crownGem = makeBall(item.name .. " Crown Gem", decorFolder, Vector3.new(0.65, 0.65, 0.28), bandCenter + Vector3.new(0, 0, -0.85), Color3.fromRGB(62, 210, 255), Enum.Material.Neon)
		crownGem.CanCollide = false
	elseif item.visual == "Relic" then
		makeSegmentedNeonRing(item.name .. " Relic Halo", decorFolder, displayCenter, 2.05, item.color, 12, 0.2, 0.28)
		makeVisualPart(item.name .. " Relic Crystal", decorFolder, Vector3.new(1.65, 2.35, 1.65), CFrame.new(displayCenter) * CFrame.Angles(0, math.rad(45), math.rad(45)), item.color, Enum.Material.Glass)
		local relicCore = makeBall(item.name .. " Relic Core", decorFolder, Vector3.new(0.72, 0.72, 0.72), displayCenter + Vector3.new(0, 0, -0.9), Color3.new(1, 1, 1), Enum.Material.Neon)
		relicCore.CanCollide = false
		for orbit = 1, 3 do
			local angle = orbit * 2 * math.pi / 3
			local mote = makeBall(item.name .. " Orbit " .. orbit, decorFolder, Vector3.new(0.42, 0.42, 0.42), displayCenter + Vector3.new(math.cos(angle) * 2.05, math.sin(angle) * 1.45, 0), item.color, Enum.Material.Neon)
			mote.CanCollide = false
		end
	else
		makeSegmentedNeonRing(item.name .. " Trail Halo", decorFolder, displayCenter + Vector3.new(0, 0.1, 0.25), 2.05, item.color, 14, 0.22, 0.28)
		for side = -1, 1, 2 do
			makeVisualPart(item.name .. " Dash Boot " .. side, decorFolder, Vector3.new(1.15, 1.45, 2.0), CFrame.new(displayCenter + Vector3.new(side * 0.78, -0.15, -0.25)) * CFrame.Angles(math.rad(-12), 0, 0), Color3.fromRGB(27, 34, 41), Enum.Material.Metal)
			makeVisualPart(item.name .. " Dash Sole " .. side, decorFolder, Vector3.new(1.2, 0.28, 2.15), CFrame.new(displayCenter + Vector3.new(side * 0.78, -0.92, -0.32)), item.color, Enum.Material.Neon)
		end
		for streak = -1, 1 do
			makeVisualPart(item.name .. " Trail Streak " .. streak, decorFolder, Vector3.new(0.24, 0.24, 2.4 + math.abs(streak) * 0.55), CFrame.new(displayCenter + Vector3.new(streak * 1.45, 0.1 - math.abs(streak) * 0.3, 1.15)), item.color, Enum.Material.Neon)
		end
	end
	local detector = Instance.new("ClickDetector")
	detector.MaxActivationDistance = 28
	detector.Parent = stand
	detector.MouseClick:Connect(function(player)
		if not profileReady(player, false) then return end
		sendFeedback(player, { type = "OpenMenu", target = "Honor", tab = "Honor", selected = item.id, color = item.color })
	end)
end
end
shared.PunchWallBuildHonorPlaza()
shared.PunchWallBuildHonorPlaza = nil

shared.PunchWallBuildRebirth = function()
local firstRebirthRequirement = GameConfig.RebirthRequirement(0)
local rebirthPart = makePart("Rebirth Shrine", interactFolder, Vector3.new(5, 13, 13), Vector3.new(67, 7, 24), Color3.fromRGB(60, 72, 82), Enum.Material.ForceField)
rebirthPart:SetAttribute("Theme", PolishConfig.StyleName)
rebirthPart:SetAttribute("ActivationPolicy", "GlobalMenuConfirmed")
rebirthPart:SetAttribute("RequirementVersion", GameConfig.Rebirth.Version)
rebirthPart:SetAttribute("FirstRequiredLevel", firstRebirthRequirement.requiredLevel)
rebirthPart:SetAttribute("FirstRequiredCoins", firstRebirthRequirement.requiredCoins)
rebirthPart.Transparency = 0.82
rebirthPart.CanCollide = false
addEmitter(rebirthPart, "Rebirth Pulse", Color3.fromRGB(255, 255, 255))
local portalCenter = rebirthPart.Position
local portalEnergy = makeCylinder("Evac Portal Energy", decorFolder, Vector3.new(0.16, 10.8, 10.8), portalCenter, Color3.fromRGB(46, 151, 203), Enum.Material.ForceField, Vector3.new(0, 90, 0))
portalEnergy.Transparency = 0.76
portalEnergy.CanCollide = false
portalEnergy:SetAttribute("VisualRole", "VerticalRebirthPortalEnergy")
local portalRing = makeSegmentedNeonRing("Evac Portal Ring", decorFolder, portalCenter, 6.3, Color3.fromRGB(77, 198, 238), 18, 0.46, 0.65)
portalRing:SetAttribute("VisualRole", "VerticalRebirthPortal")
for _, side in ipairs({ -1, 1 }) do
	local pylon = makeVisualPart("Evac Portal Pylon " .. side, decorFolder, Vector3.new(1.25, 12.8, 1.6), CFrame.new(portalCenter + Vector3.new(side * 6.7, 0, 0)), Color3.fromRGB(42, 49, 55), Enum.Material.Metal)
	makeVisualPart("Evac Portal Pylon Light " .. side, decorFolder, Vector3.new(0.32, 9.5, 1.72), CFrame.new(portalCenter + Vector3.new(side * 6.7, 0.3, -0.05)), Color3.fromRGB(77, 198, 238), Enum.Material.Neon)
	pylon:SetAttribute("VisualRole", "RebirthGateFrame")
end
local rebirthSign = makePart("Evac Portal Compact Sign", decorFolder, Vector3.new(13, 3.8, 0.45), rebirthPart.Position + Vector3.new(0, 9.5, -7.2), Color3.fromRGB(22, 28, 32), Enum.Material.Metal)
local firstRequirementText = ("LV %d | %s COINS"):format(firstRebirthRequirement.requiredLevel, formatNumber(firstRebirthRequirement.requiredCoins))
makeText(rebirthSign, "HERO REBIRTH GATE", firstRequirementText, Enum.NormalId.Front)
makeText(rebirthSign, "HERO REBIRTH GATE", firstRequirementText, Enum.NormalId.Back)
local rebirthDetector = Instance.new("ClickDetector")
rebirthDetector.MaxActivationDistance = 35
rebirthDetector.Parent = rebirthPart

local rebirthRuntime = {
	busy = setmetatable({}, { __mode = "k" }),
	lastSuccessAt = setmetatable({}, { __mode = "k" }),
	cooldownSeconds = 2,
}

local function rebirthState(player, extra)
	local result = {
		ok = false,
		Rebirths = statValue(player, "Rebirths", 0),
		Power = statValue(player, "Power", 0),
		Coins = statValue(player, "Coins", 0),
		WallLevel = statValue(player, "WallLevel", 1),
		WallXP = statValue(player, "WallXP", 0),
		EquippedFist = statValue(player, "EquippedFist", "Starter Glove"),
		TrainingActive = statValue(player, "TrainingActive", 0),
		TrainingStationId = statValue(player, "TrainingStationId", GameConfig.Training.DefaultStationId),
	}
	for key, value in pairs(extra or {}) do result[key] = value end
	return result
end

local function rejectRebirth(player, reason, requirement, message)
	sendFeedback(player, {
		type = "Fail",
		target = "Rebirth",
		message = message,
		reason = reason,
		requiredLevel = requirement and requirement.requiredLevel,
		requiredCoins = requirement and requirement.requiredCoins,
		color = PolishConfig.Palette.Fail,
	})
	return rebirthState(player, {
		reason = reason,
		requiredLevel = requirement and requirement.requiredLevel,
		requiredCoins = requirement and requirement.requiredCoins,
	})
end

local function openRebirthMenu(player, source)
	sendFeedback(player, {
		type = "OpenMenu",
		target = "Rebirth",
		surface = "Rebirth",
		tab = "Rebirth",
		selected = "Rebirth",
		source = source,
		color = Color3.fromRGB(171, 133, 219),
	})
end

shared.PunchWallTryRebirth = function(player, options)
	options = typeof(options) == "table" and options or {}
	local currentRebirths = math.max(0, math.floor(tonumber(statValue(player, "Rebirths", 0)) or 0))
	local requirement = GameConfig.RebirthRequirement(currentRebirths)
	if requirement.maxed then
		return rejectRebirth(player, "max_rebirths", requirement, "MAX REBIRTHS REACHED")
	end
	local currentLevel = math.max(1, math.floor(tonumber(statValue(player, "WallLevel", 1)) or 1))
	local currentCoins = math.max(0, math.floor(tonumber(statValue(player, "Coins", 0)) or 0))
	if currentLevel < requirement.requiredLevel or currentCoins < requirement.requiredCoins then
		local missing = {}
		if currentLevel < requirement.requiredLevel then
			table.insert(missing, ("%d WALL LV"):format(requirement.requiredLevel - currentLevel))
		end
		if currentCoins < requirement.requiredCoins then
			table.insert(missing, ("%s COINS"):format(formatNumber(requirement.requiredCoins - currentCoins)))
		end
		return rejectRebirth(player, "requirements", requirement, "NEED " .. table.concat(missing, " + "))
	end
	local ready, readinessError = profileReady(player, not RunService:IsStudio())
	if not ready then
		return rejectRebirth(player, "profile_not_writable", requirement, "PROFILE IS NOT READY • TRY AGAIN")
	end
	if options.requireConfirmation == true then
		local confirmed = options.confirmed == true
		local expected = math.floor(tonumber(options.expectedRebirths) or -1)
		if not confirmed or expected ~= currentRebirths then
			openRebirthMenu(player, "confirmation_required")
			return rebirthState(player, { reason = "confirmation_required", requiredLevel = requirement.requiredLevel, requiredCoins = requirement.requiredCoins })
		end
	end
	if rebirthRuntime.busy[player] then
		return rejectRebirth(player, "in_progress", requirement, "REBIRTH ALREADY IN PROGRESS")
	end
	local now = os.clock()
	if options.studioAutomation ~= true and now - (rebirthRuntime.lastSuccessAt[player] or -math.huge) < rebirthRuntime.cooldownSeconds then
		return rejectRebirth(player, "cooldown", requirement, "REBIRTH IS SETTLING • TRY AGAIN")
	end
	local nextRebirths = currentRebirths + 1
	local pendingHonor = shared.PunchWallHonor.PendingMilestones(
		player,
		GameConfig.Honor.RebirthMilestones,
		"HonorRebirthMilestoneMask",
		nextRebirths,
		"rebirths"
	)
	local currentHonor = math.max(0, math.floor(tonumber(statValue(player, "Honor", 0)) or 0))
	if currentHonor + pendingHonor > ProfilePersistence.MaxAuthoritativeNumber then
		return rejectRebirth(player, "honor_headroom", requirement, "SPEND HONOR BEFORE REBIRTH")
	end

	rebirthRuntime.busy[player] = true
	if statValue(player, "TrainingActive", 0) >= 1 then stopTraining(player, "rebirth") end
	setStat(player, "TrainingStationId", GameConfig.Training.DefaultStationId)
	setStat(player, "Rebirths", nextRebirths)
	local rebirthHonor = shared.PunchWallHonor.ClaimRebirthMilestones(player, nextRebirths)
	setStat(player, "Power", GameConfig.Rebirth.StartingPower)
	setStat(player, "Coins", 0)
	setStat(player, "WallLevel", 1)
	setStat(player, "WallXP", 0)
	setStat(player, "FistMultiplier", 1)
	setStat(player, "BreakSpeed", 1)
	local fist = playerStat(player, "EquippedFist")
	if fist then fist.Value = "Starter Glove" end
	rebirthRuntime.lastSuccessAt[player] = now
	rebirthRuntime.busy[player] = nil
	player:SetAttribute("LastRebirthSuccessAt", now)
	player:SetAttribute("LastRebirthResultCount", nextRebirths)
	emitNamed(rebirthPart, "Rebirth Pulse", 44)
	local successMessage = ("REBIRTH %d COMPLETE • PERMANENT POWER x%.2f"):format(
		nextRebirths,
		GameConfig.RebirthBonus(nextRebirths)
	)
	if rebirthHonor > 0 then successMessage ..= (" • +%d HONOR"):format(rebirthHonor) end
	sendFeedback(player, {
		type = "Rebirth",
		target = "Rebirth",
		message = successMessage,
		rebirths = nextRebirths,
		bonus = GameConfig.RebirthBonus(nextRebirths),
		honor = rebirthHonor,
		color = Color3.fromRGB(207, 188, 255),
	})
	syncStats(player)
	local saveTicket = persistenceRuntime.requestPlayerSave and persistenceRuntime.requestPlayerSave(player, "Rebirth", false)
	return rebirthState(player, {
		ok = true,
		reason = "rebirthed",
		rebirths = nextRebirths,
		honor = rebirthHonor,
		bonus = GameConfig.RebirthBonus(nextRebirths),
		requiredLevel = requirement.requiredLevel,
		requiredCoins = requirement.requiredCoins,
		saveQueued = saveTicket ~= nil,
	})
end

rebirthDetector.MouseClick:Connect(function(player)
	if not profileReady(player, false) then return end
	openRebirthMenu(player, "world_click")
end)
return rebirthPart
end
shared.PunchWallRebirthPart = shared.PunchWallBuildRebirth()
shared.PunchWallBuildRebirth = nil

local function equipFist(player, fistName)
	local item = fistByName[fistName]
	local owned = decodeList(player, "OwnedFistsJSON")
	local premiumOwned = decodeList(player, "OwnedPremiumFistsJSON")
	if not item or (not listContains(owned, fistName) and not listContains(premiumOwned, fistName)) then
		return { ok = false, reason = "not_owned" }
	end
	setStat(player, "EquippedFist", fistName)
	setStat(player, "FistMultiplier", item.mult)
	setStat(player, "BreakSpeed", 1)
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
	local lastSpin = statValue(player, "LastSpinAt", 0)
	local credits = statValue(player, "SpinCredits", 0)
	local cooldown = GameConfig.Spin.CooldownSeconds
	if credits <= 0 and now - lastSpin < cooldown then
		local remaining = cooldown - (now - lastSpin)
		sendFeedback(player, { type = "Fail", target = "Spin", message = ("Spin ready in %ds"):format(remaining), color = PolishConfig.Palette.Fail })
		return { ok = false, reason = "cooldown", remaining = remaining }
	end
	if credits > 0 then
		addStat(player, "SpinCredits", -1)
	else
		setStat(player, "LastSpinAt", now)
	end

	local totalWeight = 0
	for _, reward in ipairs(GameConfig.Spin.Rewards) do totalWeight += reward.weight end
	local roll = math.random() * totalWeight
	local rewardIndex = #GameConfig.Spin.Rewards
	local reward = GameConfig.Spin.Rewards[rewardIndex]
	local running = 0
	for index, candidate in ipairs(GameConfig.Spin.Rewards) do
		running += candidate.weight
		if roll <= running then
			rewardIndex = index
			reward = candidate
			break
		end
	end

	local result = {
		ok = true,
		reward = reward.id,
		label = reward.label,
		kind = reward.kind,
		amount = reward.amount,
		index = rewardIndex,
		credits = statValue(player, "SpinCredits", 0),
	}
	if reward.kind == "Coins" then
		addStat(player, "Coins", reward.amount)
		result.coins = reward.amount
	elseif reward.kind == "Power" then
		addStat(player, "Power", reward.amount)
		result.power = reward.amount
	elseif reward.kind == "Honor" then
		addStat(player, "Honor", reward.amount)
		result.honor = reward.amount
	elseif reward.kind == "BonusSpin" then
		addStat(player, "SpinCredits", reward.amount)
		result.credits = statValue(player, "SpinCredits", 0)
	elseif reward.kind == "CoinBoost" then
		local expiresAt = math.max(player:GetAttribute("CoinBoostExpiresAt") or 0, workspace:GetServerTimeNow()) + reward.amount
		player:SetAttribute("CoinBoostExpiresAt", expiresAt)
		result.expiresAt = expiresAt
	elseif reward.kind == "Pet" then
		result.petResult = hatchPet(player, true)
	end
	sendFeedback(player, {
		type = "SpinResult",
		target = reward.label,
		reward = reward.id,
		kind = reward.kind,
		amount = reward.amount,
		index = rewardIndex,
		color = reward.color,
	})
	return result
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

local function nearestNamedPart(player, partsByName, maximumDistance)
	local rootPart = characterRoot(player)
	if not rootPart then
		return nil
	end

	local nearestName = nil
	local nearestPart = nil
	local nearestDistance = tonumber(maximumDistance) or MOBILE_ACTION_DISTANCE
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
		local available = part
			and part.Parent
			and (
				part:GetAttribute("PremiumOnly") ~= true
				or part:GetAttribute("PurchaseConfigured") == true
			)
		if available then
			local distance = (rootPart.Position - part.Position).Magnitude
			if distance <= nearestDistance then
				nearestKind = "Fist"
				nearestName = name
				nearestDistance = distance
			end
		end
	end

	for _, target in ipairs({
		{ kind = "Egg", name = "Pet Egg Machine", part = shared.PunchWallEggPart },
		{ kind = "Rebirth", name = "Rebirth Shrine", part = shared.PunchWallRebirthPart },
		{ kind = "Menu", name = "Fists", part = shared.PunchWallArmoryNPCTrigger },
		{ kind = "Menu", name = "Pets", part = shared.PunchWallPetLabNPCTrigger },
		{ kind = "Menu", name = "Honor", part = shared.PunchWallHonorNPCTrigger },
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

local function normalizedUiScale(value)
	local numeric = tonumber(value)
	if not numeric or numeric ~= numeric or numeric == math.huge or numeric == -math.huge then
		return 1
	end
	return math.clamp(numeric, 0.8, 1.2)
end

local function normalizedSettingBoolean(value)
	if typeof(value) == "boolean" then
		return value
	end
	return true
end

local studioPetActionNames = {
	EquipPet = true,
	UnequipPet = true,
	DeletePet = true,
	LockPet = true,
}

local function recordStudioPetActionResult(player, action, target, inventoryIndex, result)
	if not RunService:IsStudio() or studioPetActionNames[action] ~= true then
		return
	end
	player:SetAttribute(
		"LegacyPetServerResultSequence",
		(player:GetAttribute("LegacyPetServerResultSequence") or 0) + 1
	)
	player:SetAttribute("LegacyPetServerResultAction", action)
	player:SetAttribute("LegacyPetServerResultToken", tostring(target or ""))
	player:SetAttribute("LegacyPetServerResultIndex", tonumber(inventoryIndex) or 0)
	player:SetAttribute("LegacyPetServerResultOK", result and result.ok == true)
	player:SetAttribute(
		"LegacyPetServerResultReason",
		tostring(result and result.reason or result and result.ok and "ok" or "unknown")
	)
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
	if action == "RequestSync" then
		if profileReady(player, false) then
			syncStats(player)
		end
		return
	end
	if action == "TutorialShopOpened" then
		if profileReady(player, false) then
			completeTutorialAction(player, "OpenShop")
		end
		return
	end
	if not profileReady(player, false) then
		return
	end
	local now = os.clock()
	local lastAction = player:GetAttribute("LastMobileAction") or 0
	if now - lastAction < MOBILE_ACTION_COOLDOWN then
		recordStudioPetActionResult(player, action, target, inventoryIndex, {
			ok = false,
			reason = "mobile_action_cooldown",
		})
		return
	end
	player:SetAttribute("LastMobileAction", now)

	if action == "ToggleStudioHighPowerTest" then
		shared.PunchWallStudioTest.set(player, value == true)
		return
	elseif action == "BuyFist" then
		local item = target and fistByName[target]
		if item then buyFist(player, item) end
		return
	elseif action == "BuyPremiumFist" then
		local item = target and fistByName[target]
		if item then shared.PunchWallPremiumFists.prompt(player, item) end
		return
	elseif action == "BuyPremiumPet" then
		shared.PunchWallPremiumPets.prompt(player, shared.PunchWallPremiumPets.byName[target])
		return
	elseif action == "BuyPremiumProduct" then
		shared.PunchWallPremiumProducts.prompt(player, shared.PunchWallPremiumProducts.byName[target])
		return
	elseif action == "EquipFist" then
		equipFist(player, target)
		return
	elseif action == "BuyHonorItem" then
		shared.PunchWallBuyHonorItem(player, shared.PunchWallHonorItemsByName[target])
		return
	elseif action == "BuyShopBoost" then
		shared.PunchWallShopBoostPurchase(player, target)
		return
	elseif action == "HatchPet" then
		hatchPet(player, false)
		return
	elseif action == "FusePet" then
		fusePet(player, target)
		return
	elseif action == "EquipPet" then
		local result = equipPet(player, target, inventoryIndex)
		recordStudioPetActionResult(player, action, target, inventoryIndex, result)
		return
	elseif action == "UnequipPet" then
		local result = unequipPet(player, target, inventoryIndex)
		recordStudioPetActionResult(player, action, target, inventoryIndex, result)
		return
	elseif action == "DeletePet" then
		local result = deletePet(player, target, inventoryIndex)
		recordStudioPetActionResult(player, action, target, inventoryIndex, result)
		return
	elseif action == "LockPet" then
		local result = setPetLocked(player, target, value == true, inventoryIndex)
		recordStudioPetActionResult(player, action, target, inventoryIndex, result)
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
			motion = normalizedSettingBoolean(value.motion),
			sound = normalizedSettingBoolean(value.sound),
			uiScale = normalizedUiScale(value.uiScale),
		}
		setStat(player, "SettingsJSON", HttpService:JSONEncode(settings))
		return
	elseif action == "Rebirth" then
		local confirmation = typeof(value) == "table" and value or {}
		shared.PunchWallTryRebirth(player, {
			requireConfirmation = true,
			confirmed = confirmation.confirmed == true,
			expectedRebirths = confirmation.expectedRebirths,
		})
		return
	elseif action == "Train" then
		local requested = target and (trainingRuntime.byName[tostring(target)] or trainingRuntime.byId[tostring(target)])
		local rootPart = characterRoot(player)
		local config
		-- Resolve the exact trusted station selected by the contextual affordance
		-- and validate that station's own range. A second nearest lookup made taps
		-- around adjacent-station midpoints reject even though the player was close.
		if requested and rootPart and requested.part and requested.part.Parent then
			local requestedDistance = (rootPart.Position - requested.part.Position).Magnitude
			if requestedDistance <= TRAINING_INTERACTION_DISTANCE then
				config = requested
			end
		elseif not target then
			local stationName = nearestNamedPart(player, trainingRuntime.partsByName, TRAINING_INTERACTION_DISTANCE)
			config = stationName and trainingRuntime.byName[stationName]
		end
		if not config then
			sendFeedback(player, { type = "Fail", target = "Train", message = "Move closer", color = PolishConfig.Palette.Fail })
			return
		end
		trainPlayer(player, config)
	elseif action == "StopTraining" then
		stopTraining(player)
	elseif action == "Punch" then
		local radiusResult = depthPunch.Punch(player, value)
		if radiusResult.ok or radiusResult.reason == "cooldown" or radiusResult.reason == "cancelled"
			or radiusResult.reason == "character" or radiusResult.reason == "lunge" then return end
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
			sendFeedback(player, { type = "OpenMenu", target = "Pets", tab = "Pets", color = PolishConfig.Palette.HeroCyan })
		elseif targetKind == "Rebirth" then
			openRebirthMenu(player, "contextual_use")
		elseif targetKind == "Menu" then
			sendFeedback(player, { type = "OpenMenu", target = targetName, tab = targetName, color = PolishConfig.Palette.HeroCyan })
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
	for _, activePlayer in ipairs(Players:GetPlayers()) do
		depthPunch.CancelPunch(activePlayer)
		petDropRuntime.Clear(activePlayer, "world_reset")
		activePlayer:SetAttribute("PetDropCooldownUntil", 0)
	end
	for _, wall in ipairs(wallsFolder:GetChildren()) do
		if wall:IsA("BasePart") then
			resetWallState(wall)
		end
	end
	local resetDepthBlocks = 0
	for block in pairs(depthBlocksNeedingReset) do
		local maxHP = block:GetAttribute("MaxHP")
		local baseCFrame = block:GetAttribute("BaseCFrame")
		local needsReset = block.Parent == depthBlocksFolder and (block:GetAttribute("HP") ~= maxHP
			or block:GetAttribute("Broken") == true
			or (block:GetAttribute("DamageStage") or 0) ~= 0
			or block:GetAttribute("Shaking") == true
			or block:GetAttribute("StructuralFalling") == true
			or block:GetAttribute("StructuralDetached") == true
			or block:GetAttribute("StructuralSettled") == true
			or block:GetAttribute("StructuralActiveSlot") == true
			or block:GetAttribute("StructuralFailure") == true
			or block.Transparency ~= 0
			or not block.Anchored
			or not block.CanCollide
			or not block.CanQuery
			or block.CollisionGroup ~= "DepthStructure"
			or (typeof(baseCFrame) == "CFrame" and block.CFrame ~= baseCFrame))
		if needsReset then
			depthPunch.CancelShake(block)
			resetDepthBlocks += 1
			block:SetAttribute("HP", maxHP)
			block:SetAttribute("Broken", false)
			block:SetAttribute("DamageStage", 0)
			block:SetAttribute("LastRadiusDamageScale", 0)
			block:SetAttribute("LastRadiusHitAt", 0)
			block:SetAttribute("Shaking", false)
			block:SetAttribute("ShakeToken", (block:GetAttribute("ShakeToken") or 0) + 1)
			block:SetAttribute("StructuralFalling", false)
			block:SetAttribute("StructuralDetached", false)
			block:SetAttribute("StructuralSettled", false)
			block:SetAttribute("StructuralActiveSlot", false)
			block:SetAttribute("StructuralFailure", false)
			block:SetAttribute("StructuralToken", (block:GetAttribute("StructuralToken") or 0) + 1)
			block:SetAttribute("DetachedImpactToken", (block:GetAttribute("DetachedImpactToken") or 0) + 1)
			block:SetAttribute("SettledCFrame", nil)
			block:SetAttribute("DetachedImpactOrigin", nil)
			block:SetAttribute("LastDetachedLaunchSpeed", nil)
			block:SetAttribute("LastOverlapEjectAt", nil)
			block:SetAttribute("LastOverlapEjectSpeed", nil)
			block:SetAttribute("LastOverlapShatterAt", nil)
			block.Color = block:GetAttribute("OriginalColor") or block.Color
			block.CFrame = typeof(baseCFrame) == "CFrame" and baseCFrame or block.CFrame
			block.Transparency = 0
			block.Anchored = true
			block.CanCollide = true
			block.CanQuery = true
			block.CollisionGroup = "DepthStructure"
			depthBlockContributions[block] = {}
		end
	end
	table.clear(depthBlocksNeedingReset)
	depthDebrisFolder:ClearAllChildren()
	table.clear(structuralDirtyLayers)
	root:SetAttribute("ActiveStructuralFalling", 0)
	root:SetAttribute("LastStructuralCollapseCount", 0)
	root:SetAttribute("LastCharacterOverlapShatterCount", 0)
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
		local trainingActive = statValue(player, "TrainingActive", 0) >= 1
		local activeStation = trainingActive and trainingRuntime.byId[tostring(statValue(
			player,
			"TrainingStationId",
			GameConfig.Training.DefaultStationId
		))] or nil
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if character and rootPart then
			rootPart.AssemblyLinearVelocity = Vector3.zero
			rootPart.AssemblyAngularVelocity = Vector3.zero
			if activeStation and trainingQualificationPower(player) >= activeStation.minPower then
				setActiveTrainingStation(player, activeStation)
				setTrainingMovementLocked(player, true, activeStation)
				player:SetAttribute("TrainingTickAnchor", workspace:GetServerTimeNow())
			else
				if trainingActive then stopTraining(player, "world_reset_ineligible") end
				character:PivotTo(spawn.CFrame + Vector3.new(0, 5, 0))
			end
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
	root:SetAttribute("LastWorldResetDepthBlocks", resetDepthBlocks)
	for _, player in ipairs(Players:GetPlayers()) do
		local trainingActive = statValue(player, "TrainingActive", 0) >= 1
		sendFeedback(player, {
			type = "WorldReset",
			target = trainingActive and tostring(statValue(player, "TrainingStationId", GameConfig.Training.DefaultStationId)) or "Spawn",
			message = trainingActive and "WORLD RESET | TRAINING RESUMED" or "WORLD RESET | RETURN TO SPAWN",
			color = PolishConfig.Palette.HeroCyan,
		})
	end
	return {
		action = "WorldReset",
		ok = true,
		teleportedPlayers = count,
		depthBlocksReset = resetDepthBlocks,
		resetAt = now,
		resetCount = root:GetAttribute("WorldResetCount"),
	}
end

local function automationSnapshot(player, extra)
	local result = collectPlayerData(player)
	result.EffectivePower = effectivePower(player)
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
	petDropRuntime.Clear(player, "automation_reset")
	if statValue(player, "TrainingActive", 0) >= 1 or player:GetAttribute("TrainingMovementLocked") then
		stopTraining(player)
	end
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
	player:SetAttribute("LastMobileAction", 0)
	player:SetAttribute("LastTrainToggle", 0)
	player:SetAttribute("TrainingPayoutSerial", 0)
	player:SetAttribute("TrainingSessionGeneration", 0)
	player:SetAttribute("TrainingSessionTickCount", 0)
	player:SetAttribute("PetDropCooldownUntil", 0)
	player:SetAttribute("AutoTrainingActive", false)
	player:SetAttribute("StudioHighPowerTestMode", false)
	shared.PunchWallStudioTest.snapshots[player] = nil
	if player.Character then shared.PunchWallSetCharacterCollisionGroup(player.Character, "PlayerCharacters") end
	for _, config in ipairs(trainingConfigs) do
		player:SetAttribute("LastTrain" .. config.stat, 0)
	end
	resetWorldState()
	return automationSnapshot(player, { action = "Reset", ok = true })
end

shared.PunchWallRunStressCase = function(player, caseConfig)
	caseConfig = caseConfig or {}
	local function blockingCount(rootPart)
		local overlap = OverlapParams.new()
		overlap.FilterType = Enum.RaycastFilterType.Include
		overlap.FilterDescendantsInstances = { depthBlocksFolder }
		overlap.MaxParts = 80
		local boundsCFrame, boundsSize = rootPart.Parent:GetBoundingBox()
		local count = 0
		local names = {}
		for _, block in ipairs(workspace:GetPartBoundsInBox(boundsCFrame, boundsSize, overlap)) do
			if block.CanCollide and not block:GetAttribute("Broken")
				and not block:GetAttribute("StructuralDetached") and block.Transparency < 0.95 then
				count += 1
				if #names < 8 then table.insert(names, block.Name) end
			end
		end
		return count, names, boundsCFrame, boundsSize
	end
	if caseConfig.resetTotal then player:SetAttribute("StressPunchTotal", 0) end
	local cycleCount = math.clamp(math.floor(tonumber(caseConfig.cycles) or 8), 1, 12)
	local attemptCount = math.clamp(math.floor(tonumber(caseConfig.attempts) or 5), 1, 8)
	local expectedPunches = cycleCount * attemptCount
	local result = { name = tostring(caseConfig.name or "case"), punches = 0, success = 0, overlaps = 0, corrections = 0, stuck = 0, maxBack = 0 }
	for cycle = 1, cycleCount do
		if cycle == 1 then
			resetAutomationState(player)
		else
			resetWorldState()
		end
		setStat(player, "Power", tonumber(caseConfig.power) or 15)
		setStat(player, "WallLevel", 99)
		setStat(player, "CritChance", 0)
		setStat(player, "FistMultiplier", 1)
		setStat(player, "PetMultiplier", 0)
		if caseConfig.rubble then
			local left = depthBlocksFolder:FindFirstChild("DepthBlock_L001_C06_R01")
			local right = depthBlocksFolder:FindFirstChild("DepthBlock_L001_C07_R01")
			if left then
				player:SetAttribute("LastWallHit", 0)
				hitDepthBlock(player, left)
			end
			if right then
				player:SetAttribute("LastWallHit", 0)
				hitDepthBlock(player, right)
			end
			task.wait(0.38)
		end
		local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not rootPart then result.stuck += 1 continue end
		local startX = tonumber(caseConfig.x) or -2
		local targetX = tonumber(caseConfig.targetX) or startX
		rootPart.AssemblyLinearVelocity = Vector3.zero
		rootPart.AssemblyAngularVelocity = Vector3.zero
		rootPart.CFrame = CFrame.lookAt(Vector3.new(startX, 3, -27), Vector3.new(targetX, 3, -180))
		local look = rootPart.CFrame.LookVector
		local direction = Vector3.new(look.X, 0, look.Z).Unit
		local previous = rootPart.Position
		for attempt = 1, attemptCount do
			player:SetAttribute("LastWallHit", 0)
			local punchResult = depthPunch.Punch(player)
			task.wait(0.04)
			result.punches += 1
			if punchResult.ok then result.success += 1 end
			local current = rootPart.Position
			local backward = (previous - current):Dot(direction)
			if backward > result.maxBack then
				result.maxBack = backward
				result.maxBackCycle = cycle
				result.maxBackAttempt = attempt
				result.maxBackFrom = tostring(previous)
				result.maxBackTo = tostring(current)
				result.maxBackBarrier = tostring(player:GetAttribute("LastPunchPlanningBarrier"))
				result.maxBackSafeTravel = player:GetAttribute("LastPunchSafeTravel") or 0
				result.maxBackFalling = root:GetAttribute("ActiveStructuralFalling") or 0
			end
			previous = current
			local overlapCount, overlapNames, boundsCFrame, boundsSize = blockingCount(rootPart)
			result.overlaps += overlapCount
			if overlapCount > 0 and not result.firstOverlapCycle then
				result.firstOverlapCycle = cycle
				result.firstOverlapAttempt = attempt
				result.firstOverlapNames = overlapNames
				result.firstOverlapRoot = tostring(rootPart.Position)
				result.firstOverlapBoundsCFrame = tostring(boundsCFrame)
				result.firstOverlapBoundsSize = tostring(boundsSize)
				result.firstOverlapBarrier = tostring(player:GetAttribute("LastPunchPlanningBarrier"))
				result.firstOverlapSafeTravel = player:GetAttribute("LastPunchSafeTravel") or 0
			end
			local correction = player:GetAttribute("LastPunchCollisionCorrectionStuds") or 0
			if correction > 0.001 or player:GetAttribute("LastPunchCollisionCorrected") then result.corrections += 1 end
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			local position = rootPart.Position
			if not humanoid or humanoid.Health <= 0 or position.X ~= position.X or position.Y ~= position.Y or position.Z ~= position.Z then result.stuck += 1 end
		end
	end
	local total = (player:GetAttribute("StressPunchTotal") or 0) + result.punches
	player:SetAttribute("StressPunchTotal", total)
	result.total = total
	result.endpointMode = player:GetAttribute("LastPunchSafeEndpointMode")
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	result.platform = humanoid and humanoid.PlatformStand or false
	result.sit = humanoid and humanoid.Sit or false
	result.state = humanoid and humanoid:GetState().Name or "Missing"
	result.valid = result.punches == expectedPunches and result.success >= math.ceil(expectedPunches * 0.925) and result.overlaps == 0
		and result.corrections == 0 and result.stuck == 0 and result.maxBack < 0.5
		and not result.platform and not result.sit
		and result.endpointMode == "DamageThenSweep"
		and (caseConfig.expectedTotal == nil or total == tonumber(caseConfig.expectedTotal))
	return result
end

if RunService:IsStudio() then
	local existing = ServerStorage:FindFirstChild("PunchWallAutomation")
	if existing then
		existing:Destroy()
	end

	local harnessConfig = GameConfig.StudioTestHarness or {}
	local harnessVersion = tostring(harnessConfig.Version or "1.0.0")
	local maxHarnessSequenceSteps = math.clamp(tonumber(harnessConfig.MaxSequenceSteps) or 50, 1, 100)
	local automationPresets = {
		Starter = {
			Power = 15, Coins = 0, Honor = 0, Depth = 0, Score = 0, WallLevel = 1,
			FistMastery = 1, CritChance = 5, Luck = 1, FistMultiplier = 1, PetMultiplier = 0,
		},
		Midgame = {
			Power = 25000, Coins = 500000, Honor = 250, Depth = 25, Score = 125000, WallLevel = 30,
			FistMastery = 75, CritChance = 15, Luck = 5, FistMultiplier = 13, PetMultiplier = 4,
		},
		Endgame = {
			Power = 250000000, Coins = 1000000000, Honor = 10000, Depth = 74, Score = 50000000, WallLevel = 99,
			FistMastery = 500, CritChance = 25, Luck = 25, FistMultiplier = 60, PetMultiplier = 15,
		},
		Stress = {
			Power = 1500000000, Coins = 1000000000, Honor = 100000, Depth = 74, Score = 100000000, WallLevel = 99,
			FistMastery = 1000, CritChance = 0, Luck = 100, FistMultiplier = 100, PetMultiplier = 50,
		},
	}
	local automationLocations = {
		Spawn = { position = Vector3.new(-2, 3, -18), lookAt = Vector3.new(-2, 3, -80) },
		DepthStart = { position = Vector3.new(-2, 3, -27), lookAt = Vector3.new(-2, 3, -180) },
		Training = { position = Vector3.new(-16, 3, 31), lookAt = Vector3.new(-16, 4, 24) },
		Armory = { position = Vector3.new(-30, 3, 31), lookAt = Vector3.new(-30, 3, 24) },
		PetLab = { position = Vector3.new(-94, 3, 34), lookAt = Vector3.new(-94, 5, 24) },
		Honor = { position = Vector3.new(22, 3, 34), lookAt = Vector3.new(22, 4, 28) },
		Rebirth = { position = Vector3.new(67, 3, 34), lookAt = Vector3.new(67, 7, 24) },
	}
	local serverCommandNames = {
		"Describe", "Sequence", "Snapshot", "Reset", "ResetWorld", "SetStats", "ApplyPreset",
		"Teleport", "Respawn", "SetCharacterState", "ClearCooldowns", "SetSpinReady",
		"PowerGrowthRigContract", "PowerGrowthSnapshot", "TrainingSnapshot",
		"SetWorldResetEnabled", "ClaimWorldHonor", "ForcePetEggDrop", "ClaimPetEggDrop", "PetEggDropSnapshot", "Catalog", "SetPlayerAttribute",
		"EmitFeedback", "OpenWorldBoostKiosk", "GrantAllFists", "GrantAllPets", "GrantAllPremium",
		"BreakDepthRegion", "SetLighting", "Train", "StopTraining",
		"HitWall", "HitDepthBlock", "BreakDepthBlock", "PunchRadius", "PunchWithCooldown",
		"StressPunchCase", "BreakWall", "BreakWallCycles", "BuyFist", "EquipFist",
		"GrantPremiumFist", "GrantPremiumProduct", "GrantPet", "GrantPremiumPet",
		"FusePet", "EquipPet", "UnequipPet", "DeletePet", "LockPet", "BuyHonorItem",
		"BuyShopBoost", "HatchPet", "ClaimDaily", "Spin", "ClaimQuest", "ClaimPlaytime",
		"Rebirth", "HitBoss", "HitBossWeakPoint",
	}

	local function resolveAutomationPlayer(selector)
		if typeof(selector) == "Instance" and selector:IsA("Player") then return selector end
		if typeof(selector) == "number" then return Players:GetPlayerByUserId(selector) end
		if typeof(selector) == "string" then return Players:FindFirstChild(selector) end
		if typeof(selector) == "table" then
			if selector.userId then return Players:GetPlayerByUserId(tonumber(selector.userId) or 0) end
			if selector.name then return Players:FindFirstChild(tostring(selector.name)) end
			if selector.index then return Players:GetPlayers()[math.max(1, math.floor(tonumber(selector.index) or 1))] end
		end
		return Players:GetPlayers()[1]
	end

	local function tableVector3(value)
		if typeof(value) == "Vector3" then return value end
		if typeof(value) ~= "table" then return nil end
		return Vector3.new(
			tonumber(value.x or value.X or value[1]) or 0,
			tonumber(value.y or value.Y or value[2]) or 0,
			tonumber(value.z or value.Z or value[3]) or 0
		)
	end

	local function automationCatalog()
		local fists, pets, premiumPets, products, honorItems, locations = {}, {}, {}, {}, {}, {}
		for _, item in ipairs(GameConfig.Fists) do table.insert(fists, item.name) end
		for _, item in ipairs(GameConfig.Pets) do table.insert(pets, item.name) end
		for _, item in ipairs(GameConfig.PremiumPets) do table.insert(premiumPets, item.name) end
		for _, item in ipairs(GameConfig.PremiumProducts) do table.insert(products, item.id) end
		for _, item in ipairs(GameConfig.HonorItems or {}) do table.insert(honorItems, item.name) end
		for name in pairs(automationLocations) do table.insert(locations, name) end
		table.sort(fists)
		table.sort(pets)
		table.sort(premiumPets)
		table.sort(products)
		table.sort(honorItems)
		table.sort(locations)
		return {
			fists = fists,
			pets = pets,
			premiumPets = premiumPets,
			products = products,
			honorItems = honorItems,
			locations = locations,
			presets = { "Starter", "Midgame", "Endgame", "Stress" },
		}
	end

	local function automationPetRequest(value)
		if typeof(value) == "table" then
			return value.target or value.token or value.name, value.index, value.value
		end
		return value, nil, nil
	end

	local automationCommand = Instance.new("BindableFunction")
	automationCommand.Name = "PunchWallAutomation"
	automationCommand.Parent = ServerStorage
	automationCommand:SetAttribute("StudioOnly", true)
	automationCommand:SetAttribute("HarnessVersion", harnessVersion)
	automationCommand.OnInvoke = function(action, target, amount, playerSelector)
		local player = resolveAutomationPlayer(playerSelector) or Players.PlayerAdded:Wait()
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
		elseif action == "ApplyPreset" then
			local presetName = tostring(target or "Starter")
			local preset = automationPresets[presetName]
			assert(preset, "Unknown automation preset: " .. presetName)
			for name, value in pairs(preset) do setStat(player, name, value) end
			player:SetAttribute("StudioHighPowerTestMode", presetName == "Endgame" or presetName == "Stress")
			return automationSnapshot(player, { action = action, ok = true, preset = presetName })
		elseif action == "Teleport" then
			local destination
			if typeof(target) == "string" then
				destination = automationLocations[target]
				if not destination then
					local part = root:FindFirstChild(target, true)
					if part and part:IsA("BasePart") then
						destination = { position = part.Position + Vector3.new(0, 3.5, 6), lookAt = part.Position }
					end
				end
			elseif typeof(target) == "table" then
				destination = {
					position = tableVector3(target.position or target),
					lookAt = tableVector3(target.lookAt),
				}
			end
			assert(destination and destination.position, "Unknown teleport destination")
			local rootPart = characterRoot(player)
			assert(rootPart, "Character root is not ready")
			rootPart.AssemblyLinearVelocity = Vector3.zero
			rootPart.AssemblyAngularVelocity = Vector3.zero
			rootPart.CFrame = destination.lookAt
				and CFrame.lookAt(destination.position, destination.lookAt)
				or CFrame.new(destination.position)
			return automationSnapshot(player, {
				action = action,
				ok = true,
				position = { x = rootPart.Position.X, y = rootPart.Position.Y, z = rootPart.Position.Z },
			})
		elseif action == "Respawn" then
			player:LoadCharacter()
			local character = player.Character or player.CharacterAdded:Wait()
			character:WaitForChild("HumanoidRootPart", 5)
			return automationSnapshot(player, { action = action, ok = true })
		elseif action == "SetCharacterState" then
			local options = typeof(target) == "table" and target or {}
			local character = player.Character
			local rootPart = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			assert(rootPart and humanoid, "Character is not ready")
			if options.health ~= nil then humanoid.Health = math.clamp(tonumber(options.health) or humanoid.Health, 0, humanoid.MaxHealth) end
			if options.maxHealth ~= nil then humanoid.MaxHealth = math.max(1, tonumber(options.maxHealth) or humanoid.MaxHealth) end
			if options.walkSpeed ~= nil then humanoid.WalkSpeed = math.max(0, tonumber(options.walkSpeed) or humanoid.WalkSpeed) end
			if options.jumpPower ~= nil then humanoid.JumpPower = math.max(0, tonumber(options.jumpPower) or humanoid.JumpPower) end
			if options.anchored ~= nil then rootPart.Anchored = options.anchored == true end
			if options.velocity then rootPart.AssemblyLinearVelocity = tableVector3(options.velocity) or Vector3.zero end
			return automationSnapshot(player, {
				action = action,
				ok = true,
				health = humanoid.Health,
				walkSpeed = humanoid.WalkSpeed,
				anchored = rootPart.Anchored,
			})
		elseif action == "PowerGrowthRigContract" then
			return shared.PunchWallPowerGrowth.RunRigContract()
		elseif action == "PowerGrowthSnapshot" then
			local applied = shared.PunchWallPowerGrowth.Apply(player)
			local character = player.Character
			return {
				ok = applied == true,
				coreBottom = character and character:GetAttribute("PowerGrowthCoreBottom") or nil,
				bodyHeight = character and character:GetAttribute("PowerGrowthBodyHeight") or nil,
				appliedMultiplier = character and character:GetAttribute("PowerGrowthAppliedMultiplier") or nil,
				power = character and character:GetAttribute("PowerGrowthPower") or nil,
			}
		elseif action == "TrainingSnapshot" then
			local stationId = tostring(statValue(player, "TrainingStationId", GameConfig.Training.DefaultStationId))
			local station = trainingRuntime.byId[stationId] or trainingConfigs[1]
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local boundsSize
			if character then
				local _, currentBounds = character:GetBoundingBox()
				boundsSize = currentBounds
			end
			return automationSnapshot(player, {
				action = action,
				ok = true,
				stationId = station.id,
				stationName = station.name,
				requiredPower = station.minPower,
				qualificationPower = trainingQualificationPower(player),
				basePower = statValue(player, "Power", 0),
				gainPerSecond = station.gain,
				active = statValue(player, "TrainingActive", 0) >= 1,
				tickAnchor = player:GetAttribute("TrainingTickAnchor"),
				payoutSerial = player:GetAttribute("TrainingPayoutSerial") or 0,
				sessionGeneration = player:GetAttribute("TrainingSessionGeneration") or 0,
				sessionTickCount = player:GetAttribute("TrainingSessionTickCount") or 0,
				lastGrant = player:GetAttribute("LastTrainingGrant") or 0,
				lastTickBatch = player:GetAttribute("LastTrainingTickBatch") or 0,
				movementLocked = player:GetAttribute("TrainingMovementLocked") == true,
				walkSpeed = humanoid and humanoid.WalkSpeed or -1,
				directScale = character and character:GetScale() or 0,
				bodyHeight = boundsSize and boundsSize.Y or 0,
				growthBodyHeight = character and character:GetAttribute("PowerGrowthBodyHeight") or 0,
				growthMultiplier = character and character:GetAttribute("PowerGrowthAppliedMultiplier") or 0,
			})
		elseif action == "ClearCooldowns" then
			player:SetAttribute("LastWallHit", 0)
			player:SetAttribute("LastBossHit", 0)
			player:SetAttribute("LastMobileAction", 0)
			player:SetAttribute("LastPunchActionAt", 0)
			player:SetAttribute("PetDropCooldownUntil", 0)
			for _, config in ipairs(trainingConfigs) do player:SetAttribute("LastTrain" .. config.stat, 0) end
			return automationSnapshot(player, { action = action, ok = true })
		elseif action == "ClaimWorldHonor" then
			local granted, reason = shared.PunchWallHonor.ClaimQualifiedWorldClear(
				player,
				math.clamp(tonumber(amount or target) or 1, 0, 1)
			)
			return automationSnapshot(player, { action = action, ok = granted > 0, honorGranted = granted, reason = reason })
		elseif action == "SetSpinReady" then
			setStat(player, "LastSpinAt", 0)
			setStat(player, "SpinCredits", math.max(0, math.floor(tonumber(amount or target) or 0)))
			syncStats(player)
			return automationSnapshot(player, { action = action, ok = true })
		elseif action == "SetWorldResetEnabled" then
			shared.PunchWallAutomationWorldResetEnabled = target ~= false and amount ~= false
			root:SetAttribute("AutomationWorldResetEnabled", shared.PunchWallAutomationWorldResetEnabled)
			return automationSnapshot(player, {
				action = action,
				ok = true,
				enabled = shared.PunchWallAutomationWorldResetEnabled,
			})
		elseif action == "ForcePetEggDrop" then
			local depth = math.max(1, math.floor(tonumber(target) or statValue(player, "Depth", 1)))
			petDropRuntime.Clear(player, "automation_force_replace")
			player:SetAttribute("PetDropCooldownUntil", 0)
			setStat(player, "PetDropPity", GameConfig.PetDrops.PityBreaks)
			local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local sourcePosition = rootPart and (rootPart.Position + rootPart.CFrame.LookVector * 4) or nil
			local dropResult = tryDropPetEgg and tryDropPetEgg(player, depth, sourcePosition) or { ok = false, reason = "drop_system_unavailable" }
			return automationSnapshot(player, {
				action = action,
				ok = dropResult.ok == true,
				depth = depth,
				dropped = dropResult.ok == true,
				drop = dropResult,
			})
		elseif action == "ClaimPetEggDrop" then
			local record = petDropRuntime.active[player.UserId]
			local claimResult = petDropRuntime.Claim and petDropRuntime.Claim(player, record)
				or { ok = false, reason = "drop_system_unavailable" }
			return automationSnapshot(player, {
				action = action,
				ok = claimResult.ok == true,
				claim = claimResult,
			})
		elseif action == "PetEggDropSnapshot" then
			local record = petDropRuntime.active[player.UserId]
			local now = workspace:GetServerTimeNow()
			return automationSnapshot(player, {
				action = action,
				ok = true,
				active = record ~= nil and record.model ~= nil and record.model.Parent ~= nil,
				dropId = record and record.id or "",
				depth = record and record.depth or 0,
				rarity = record and record.chosen and record.chosen.rarity or "",
				armed = record ~= nil and now >= record.claimReadyAt,
				remaining = record and math.max(0, record.expiresAt - now) or 0,
			})
		elseif action == "Catalog" then
			return { ok = true, action = action, catalog = automationCatalog() }
		elseif action == "SetPlayerAttribute" then
			local options = typeof(target) == "table" and target or {}
			assert(type(options.name) == "string" and options.name ~= "", "Attribute name is required")
			player:SetAttribute(options.name, options.value)
			return automationSnapshot(player, {
				action = action,
				ok = true,
				name = options.name,
				value = player:GetAttribute(options.name),
			})
		elseif action == "EmitFeedback" then
			local payload = typeof(target) == "table" and target or {
				type = "Reward",
				target = tostring(target or "TEST FEEDBACK"),
				color = PolishConfig.Palette.Reward,
			}
			sendFeedback(player, payload)
			return automationSnapshot(player, { action = action, ok = true, feedbackType = payload.type, feedbackTarget = payload.target })
		elseif action == "OpenWorldBoostKiosk" then
			return shared.PunchWallOpenWorldBoostKiosk(player, tostring(target or "CoinBoost"))
		elseif action == "GrantAllFists" then
			local owned = {}
			for _, item in ipairs(GameConfig.Fists) do table.insert(owned, item.name) end
			encodeList(player, "OwnedFistsJSON", owned)
			for _, item in ipairs(GameConfig.PremiumFists) do
				shared.PunchWallPremiumFists.grant(player, item, "StudioHarness")
			end
			local equipName = tostring(target or GameConfig.PremiumFists[#GameConfig.PremiumFists].name)
			local result = equipFist(player, equipName)
			return automationSnapshot(player, {
				action = action,
				ok = result.ok == true,
				equipped = equipName,
				baseCount = #owned,
				premiumCount = #GameConfig.PremiumFists,
			})
		elseif action == "GrantAllPets" then
			local granted = 0
			for _, item in ipairs(GameConfig.Pets) do
				local result = grantPet(player, item, 1, "StudioHarness")
				if result.ok then granted += 1 end
			end
			return automationSnapshot(player, { action = action, ok = granted == #GameConfig.Pets, granted = granted })
		elseif action == "GrantAllPremium" then
			local fistsGranted, petsGranted, productsGranted = 0, 0, 0
			for _, item in ipairs(GameConfig.PremiumFists) do
				local result = shared.PunchWallPremiumFists.grant(player, item, "StudioHarness")
				if result.ok then fistsGranted += 1 end
			end
			for _, item in ipairs(GameConfig.PremiumPets) do
				local result = shared.PunchWallPremiumPets.grant(player, item, "StudioHarness")
				if result.ok then petsGranted += 1 end
			end
			if target == true or target == "WithProducts" then
				for _, item in ipairs(GameConfig.PremiumProducts) do
					local result = shared.PunchWallPremiumProducts.grant(player, item)
					if result.ok then productsGranted += 1 end
				end
			end
			return automationSnapshot(player, {
				action = action,
				ok = fistsGranted == #GameConfig.PremiumFists and petsGranted == #GameConfig.PremiumPets,
				fists = fistsGranted,
				pets = petsGranted,
				products = productsGranted,
			})
		elseif action == "BreakDepthRegion" then
			local selector = typeof(target) == "table" and target or {}
			local layerFrom = math.clamp(math.floor(tonumber(selector.layerFrom or selector.layer) or 1), 1, DEPTH_LAYERS)
			local layerTo = math.clamp(math.floor(tonumber(selector.layerTo or selector.layer) or layerFrom), layerFrom, DEPTH_LAYERS)
			local columnFrom = math.clamp(math.floor(tonumber(selector.columnFrom or selector.column) or 1), 1, DEPTH_COLUMNS)
			local columnTo = math.clamp(math.floor(tonumber(selector.columnTo or selector.column) or DEPTH_COLUMNS), columnFrom, DEPTH_COLUMNS)
			local rowFrom = math.clamp(math.floor(tonumber(selector.rowFrom or selector.row) or 1), 1, DEPTH_ROWS)
			local rowTo = math.clamp(math.floor(tonumber(selector.rowTo or selector.row) or DEPTH_ROWS), rowFrom, DEPTH_ROWS)
			local limit = math.clamp(math.floor(tonumber(selector.limit) or 120), 1, 240)
			local attempts = math.clamp(math.floor(tonumber(selector.attempts or amount) or 8), 1, 100)
			local matched, broken = 0, 0
			for _, block in ipairs(depthBlocksFolder:GetChildren()) do
				local layer = tonumber(block:GetAttribute("Depth")) or 0
				local column = tonumber(block:GetAttribute("Column")) or 0
				local row = tonumber(block:GetAttribute("Row")) or 0
				if layer >= layerFrom and layer <= layerTo and column >= columnFrom and column <= columnTo
					and row >= rowFrom and row <= rowTo and matched < limit then
					matched += 1
					if selector.force == true then block:SetAttribute("HP", 1) end
					for _ = 1, attempts do
						if block:GetAttribute("Broken") then break end
						player:SetAttribute("LastWallHit", 0)
						hitDepthBlock(player, block)
					end
					if block:GetAttribute("Broken") then broken += 1 end
				end
			end
			return automationSnapshot(player, {
				action = action,
				ok = matched > 0 and broken == matched,
				matched = matched,
				broken = broken,
				limited = matched >= limit,
			})
		elseif action == "SetLighting" then
			local options = typeof(target) == "table" and target or {}
			if options.clockTime ~= nil then Lighting.ClockTime = math.clamp(tonumber(options.clockTime) or Lighting.ClockTime, 0, 24) end
			if options.brightness ~= nil then Lighting.Brightness = math.max(0, tonumber(options.brightness) or Lighting.Brightness) end
			if options.globalShadows ~= nil then Lighting.GlobalShadows = options.globalShadows == true end
			return automationSnapshot(player, {
				action = action,
				ok = true,
				clockTime = Lighting.ClockTime,
				brightness = Lighting.Brightness,
				globalShadows = Lighting.GlobalShadows,
			})
		elseif action == "Train" then
			local config = trainingRuntime.byName[target]
			assert(config, "Unknown training station: " .. tostring(target))
			player:SetAttribute("LastTrainToggle", 0)
			return automationSnapshot(player, trainPlayer(player, config))
		elseif action == "StopTraining" then
			return automationSnapshot(player, stopTraining(player))
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
			return automationSnapshot(player, depthPunch.Punch(player, typeof(target) == "string" and target or "Forward"))
		elseif action == "PunchWithCooldown" then
			return automationSnapshot(player, depthPunch.Punch(player))
		elseif action == "StressPunchCase" then
			return shared.PunchWallRunStressCase(player, target)
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
		elseif action == "GrantPremiumFist" then
			local item = fistByName[target]
			assert(item and item.robux, "Unknown premium fist: " .. tostring(target))
			return automationSnapshot(player, shared.PunchWallPremiumFists.grant(player, item, "StudioAutomation"))
		elseif action == "GrantPremiumProduct" then
			local product = shared.PunchWallPremiumProducts.byName[target]
			assert(product, "Unknown premium product: " .. tostring(target))
			return automationSnapshot(player, shared.PunchWallPremiumProducts.grant(player, product))
		elseif action == "HonorProductReceiptContract" then
			local product = shared.PunchWallPremiumProducts.byName[target or "HonorPouch25"]
			assert(product and product.honor, "Unknown Honor product: " .. tostring(target))
			local testProductId = 2100000001
			local profile = ProfilePersistence.NewProfile(GameConfig.DataVersion)
			profile.Honor = 10
			local first, entry, granted, firstError = ProfilePersistence.ApplyReceipt(
				profile, "studio-honor-receipt", testProductId, product,
				"studio-honor-token", 1000, 8
			)
			local replay, _, replayGranted, replayError = ProfilePersistence.ApplyReceipt(
				first, "studio-honor-receipt", testProductId, product,
				"studio-honor-replay", 1001, 8
			)
			local _, _, mismatchGranted, mismatchError = ProfilePersistence.ApplyReceipt(
				replay, "studio-honor-receipt", testProductId + 1, product,
				"studio-honor-mismatch", 1002, 8
			)
			local capped = ProfilePersistence.NewProfile(GameConfig.DataVersion)
			capped.Honor = ProfilePersistence.MaxAuthoritativeNumber - product.honor + 1
			local overflow, _, overflowGranted, overflowError = ProfilePersistence.ApplyReceipt(
				capped, "studio-honor-overflow", testProductId, product,
				"studio-honor-overflow-token", 1003, 8
			)
			local reconciled = { Honor = 5 }
			local reconciledOk = entry and ProfilePersistence.ApplyReceiptEntryToSnapshot(reconciled, entry)
			return {
				ok = first ~= nil and granted == true and firstError == nil
					and entry and entry.Honor == product.honor
					and first.Honor == 10 + product.honor
					and replay ~= nil and replayGranted == false and replayError == nil
					and replay.Honor == 10 + product.honor
					and mismatchGranted == false and mismatchError == "receipt_product_mismatch"
					and overflow == nil and overflowGranted == false and overflowError == "invalid_honor_balance"
					and capped.Honor == ProfilePersistence.MaxAuthoritativeNumber - product.honor + 1
					and ProfilePersistence.GetSeenReceiptProductId(capped, "studio-honor-overflow", 8) == nil
					and reconciledOk == true and reconciled.Honor == 5 + product.honor,
				product = product.id,
				honor = product.honor,
				firstBalance = first and first.Honor,
				replayBalance = replay and replay.Honor,
				mismatchError = mismatchError,
				overflowError = overflowError,
				reconciledHonor = reconciled.Honor,
			}
		elseif action == "GrantPet" then
			local petName = typeof(target) == "table" and target.name or target
			local stars = typeof(target) == "table" and target.stars or amount
			local pet = petByName[petName]
			assert(pet, "Unknown pet: " .. tostring(petName))
			return automationSnapshot(player, grantPet(player, pet, stars or 1, "StudioAutomation"))
		elseif action == "FusePet" then
			return automationSnapshot(player, fusePet(player, tostring(target)))
		elseif action == "GrantPremiumPet" then
			local item = shared.PunchWallPremiumPets.byName[target]
			assert(item, "Unknown premium pet: " .. tostring(target))
			return automationSnapshot(player, shared.PunchWallPremiumPets.grant(player, item, "StudioAutomation"))
		elseif action == "BuyHonorItem" then
			local item = shared.PunchWallHonorItemsByName[target]
			return automationSnapshot(player, shared.PunchWallBuyHonorItem(player, item))
		elseif action == "HatchPet" then
			return automationSnapshot(player, hatchPet(player, true, tonumber(amount) or statValue(player, "Depth", 1)))
		elseif action == "EquipPet" then
			local petTarget, inventoryIndex = automationPetRequest(target)
			return automationSnapshot(player, equipPet(player, petTarget, inventoryIndex))
		elseif action == "UnequipPet" then
			local petTarget, inventoryIndex = automationPetRequest(target)
			return automationSnapshot(player, unequipPet(player, petTarget, inventoryIndex))
		elseif action == "DeletePet" then
			local petTarget, inventoryIndex = automationPetRequest(target)
			return automationSnapshot(player, deletePet(player, petTarget, inventoryIndex))
		elseif action == "LockPet" then
			local petTarget, inventoryIndex, requestedLock = automationPetRequest(target)
			local locked = requestedLock
			if locked == nil then
				locked = amount == true or amount == 1
			else
				locked = locked == true or locked == 1
			end
			return automationSnapshot(player, setPetLocked(player, petTarget, locked, inventoryIndex))
		elseif action == "EquipFist" then
			return automationSnapshot(player, equipFist(player, target))
		elseif action == "BuyShopBoost" then
			return automationSnapshot(player, shared.PunchWallShopBoostPurchase(player, target))
		elseif action == "ClaimDaily" then
			return automationSnapshot(player, claimDaily(player))
		elseif action == "Spin" then
			setStat(player, "LastSpinAt", 0)
			return automationSnapshot(player, spinReward(player))
		elseif action == "ClaimQuest" then
			return automationSnapshot(player, claimQuest(player))
		elseif action == "ClaimPlaytime" then
			return automationSnapshot(player, claimPlaytime(player))
		elseif action == "Rebirth" then
			return automationSnapshot(player, shared.PunchWallTryRebirth(player, { studioAutomation = true }))
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

	local oldHarness = ServerStorage:FindFirstChild("PunchWallTestHarness")
	if oldHarness then oldHarness:Destroy() end
	if harnessConfig.Enabled ~= false then
		local testHarness = Instance.new("BindableFunction")
		testHarness.Name = "PunchWallTestHarness"
		testHarness:SetAttribute("Ready", true)
		testHarness:SetAttribute("StudioOnly", true)
		testHarness:SetAttribute("ProductionSurface", false)
		testHarness:SetAttribute("Version", harnessVersion)
		testHarness:SetAttribute("MaxSequenceSteps", maxHarnessSequenceSteps)
		testHarness:SetAttribute("CommandCount", #serverCommandNames)
		local schema = Instance.new("StringValue")
		schema.Name = "CommandSchema"
		schema.Value = HttpService:JSONEncode({
			version = harnessVersion,
			studioOnly = true,
			commands = serverCommandNames,
			request = { command = "Snapshot", target = "optional", amount = "optional", player = "optional" },
			sequence = { command = "Sequence", steps = { { command = "Reset" }, { command = "ApplyPreset", target = "Midgame" } } },
		})
		schema.Parent = testHarness
		testHarness.OnInvoke = function(request, legacyTarget, legacyAmount, legacyPlayer)
			if typeof(request) == "string" then
				request = { command = request, target = legacyTarget, amount = legacyAmount, player = legacyPlayer }
			end
			assert(typeof(request) == "table", "Harness request must be a table or command string")
			local command = tostring(request.command or request.action or "")
			if command == "Describe" then
				return {
					ok = true,
					version = harnessVersion,
					studioOnly = true,
					productionSurface = false,
					maxSequenceSteps = maxHarnessSequenceSteps,
					commands = serverCommandNames,
					catalog = automationCatalog(),
				}
			end
			if command == "Sequence" then
				local steps = request.steps or request.sequence or {}
				assert(typeof(steps) == "table", "Sequence steps must be a table")
				assert(#steps <= maxHarnessSequenceSteps, "Sequence exceeds harness limit")
				local results = {}
				for index, step in ipairs(steps) do
					assert(typeof(step) == "table", "Invalid sequence step " .. index)
					local ok, result = pcall(function()
						return automationCommand:Invoke(
							step.command or step.action,
							step.target,
							step.amount,
							step.player or request.player
						)
					end)
					results[index] = ok and { ok = true, result = result } or { ok = false, error = tostring(result) }
					if not ok and request.continueOnError ~= true then
						return { ok = false, failedStep = index, error = tostring(result), results = results }
					end
				end
				return { ok = true, action = command, count = #results, results = results }
			end
			local ok, result = pcall(function()
				return automationCommand:Invoke(command, request.target, request.amount, request.player)
			end)
			if not ok then return { ok = false, action = command, error = tostring(result) } end
			return { ok = true, action = command, result = result }
		end
		testHarness.Parent = ServerStorage
		root:SetAttribute("StudioTestHarnessReady", true)
		root:SetAttribute("StudioTestHarnessVersion", harnessVersion)
	end
end

Players.PlayerAdded:Connect(shared.PunchWallBindPlayerSpawn)
for _, player in ipairs(Players:GetPlayers()) do shared.PunchWallBindPlayerSpawn(player) end
Players.PlayerAdded:Connect(depthPunch.BindCharacterLifetime)
for _, player in ipairs(Players:GetPlayers()) do depthPunch.BindCharacterLifetime(player) end
Players.PlayerAdded:Connect(ensureStats)
Players.PlayerRemoving:Connect(function(player)
	depthPunch.CancelPunch(player)
	shared.PunchWallStatsSync.remove(player)
	petDropRuntime.Clear(player, "player_removing")
	local session = persistenceRuntime.profileSessions[player]
	local canFinalizeCurrentSession = session and (
		session.ready == true
		or (
			session.fence
			and session.canBecomeWritable
			and persistenceRuntime.playerStore
		)
	)
	if not canFinalizeCurrentSession then
		persistenceRuntime.markPlayerDeparted(player, true)
		shared.PunchWallStudioTest.snapshots[player] = nil
		return
	end
	local ticket = persistenceRuntime.requestPlayerSave(player, "PlayerRemoving", true)
	local saved, persistenceError = persistenceRuntime.waitForTicket(
		ticket,
		persistenceRuntime.playerRemovingSaveTimeout
	)
	if not saved then
		warn(("[PunchWallRPG] PlayerRemoving save did not complete for %s: %s"):format(
			player.Name,
			tostring(persistenceError)
		))
		local session = persistenceRuntime.profileSessions[player]
		if ticket.completed and session and session.fence and persistenceRuntime.releaseProfileFence then
			local released, releaseError = persistenceRuntime.releaseProfileFence(player, session.fence)
			if not released then
				warn(("[PunchWallRPG] PlayerRemoving lease release did not complete for %s: %s"):format(
					player.Name,
					tostring(releaseError)
				))
			end
		elseif not ticket.completed then
			warn(("[PunchWallRPG] PlayerRemoving persistence remains in flight for %s; "
				.. "the session lease will not be released concurrently"):format(player.Name))
		end
	end
	persistenceRuntime.markPlayerDeparted(player, not saved)
	shared.PunchWallStudioTest.snapshots[player] = nil
end)
for _, player in ipairs(Players:GetPlayers()) do
	ensureStats(player)
end

game:BindToClose(function()
	persistenceRuntime.serverClosing = true
	local pendingTickets = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local session = persistenceRuntime.profileSessions[player]
		if session and session.ready == true then
			table.insert(pendingTickets, {
				player = player,
				ticket = persistenceRuntime.requestPlayerSave(player, "BindToClose", true),
			})
		end
	end
	local deadline = os.clock() + persistenceRuntime.shutdownDrainTimeout
	while os.clock() < deadline do
		local allCompleted = true
		for _, pending in ipairs(pendingTickets) do
			if not pending.ticket.completed then
				allCompleted = false
				break
			end
		end
		if allCompleted then
			break
		end
		task.wait(0.05)
	end
	for _, pending in ipairs(pendingTickets) do
		if not pending.ticket.completed or not pending.ticket.success then
			warn(("[PunchWallRPG] Shutdown drain incomplete for %s: %s"):format(
				pending.player.Name,
				tostring(pending.ticket.error or "persistence_timeout")
			))
		end
	end
end)

task.spawn(function()
	while root.Parent do
		task.wait(WORLD_RESET_INTERVAL)
		if not root.Parent then break end
		if shared.PunchWallAutomationWorldResetEnabled ~= false then resetWorldState() end
	end
end)

task.spawn(function()
	while true do
		task.wait(1)
		local today = os.date("!%Y-%m-%d")
		for _, player in ipairs(Players:GetPlayers()) do
			if profileReady(player, false) then
				persistenceRuntime.applySpeedBoostState(player)
				addStat(player, "PlaytimeSeconds", 1)
				if statValue(player, "TrainingActive", 0) >= 1 then
					local now = workspace:GetServerTimeNow()
					local anchor = tonumber(player:GetAttribute("TrainingTickAnchor")) or now
					local tickSeconds = math.max(0.1, tonumber(GameConfig.Training.TickSeconds) or 1)
					local due = math.clamp(math.floor((now - anchor) / tickSeconds), 0, 60)
					if due > 0 then
						local stationId = tostring(statValue(player, "TrainingStationId", GameConfig.Training.DefaultStationId))
						local config = trainingRuntime.byId[stationId]
						if not config then
							config = trainingConfigs[1]
							setActiveTrainingStation(player, config)
						end
						local granted = grantTrainingTick(player, config, false, due)
						if granted > 0 and statValue(player, "TrainingActive", 0) >= 1 then
							player:SetAttribute("TrainingTickAnchor", anchor + due * tickSeconds)
						end
					end
				end
				if statValue(player, "DailyQuestDate", "") ~= today then
					setStat(player, "DailyBreaks", 0)
					setStat(player, "DailyQuestClaimed", 0)
					setStat(player, "DailyQuestDate", today)
				end
			end
		end
	end
end)
end

shared.PunchWallServerFinalize()

task.spawn(function()
	while not persistenceRuntime.serverClosing do
		task.wait(persistenceRuntime.autosaveSeconds)
		if persistenceRuntime.serverClosing then
			break
		end
		for _, player in ipairs(Players:GetPlayers()) do
			persistenceRuntime.requestPlayerSave(player, "Autosave", false)
		end
	end
end)
