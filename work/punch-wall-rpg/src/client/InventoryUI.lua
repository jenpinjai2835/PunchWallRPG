local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local InventoryViewModel = require(ReplicatedStorage:WaitForChild("InventoryViewModel"))
local PolishConfig = require(ReplicatedStorage:WaitForChild("PolishConfig"))

local InventoryUI = {}
InventoryUI.__index = InventoryUI

local CATEGORIES = { "All", "Fists", "Pets", "Boosts", "Honor" }
local RARITIES = { "All", "Common", "Rare", "Epic", "Legendary", "Secret", "Premium" }
local WIDE_CATEGORY_WIDTH = 164
local WIDE_CATEGORY_GAP = 8
local SPARSE_SLOT_ROWS = 1
local MAX_SPARSE_SLOT_PLACEHOLDERS = 5

local PALETTE = {
	Backdrop = Color3.fromRGB(0, 5, 10),
	Ink = Color3.fromRGB(18, 26, 38),
	Panel = Color3.fromRGB(14, 20, 29),
	PanelSoft = Color3.fromRGB(18, 26, 38),
	PanelRaised = Color3.fromRGB(22, 32, 44),
	Card = Color3.fromRGB(14, 20, 29),
	CardHover = Color3.fromRGB(23, 43, 57),
	Steel = Color3.fromRGB(27, 50, 64),
	SteelLight = Color3.fromRGB(61, 88, 101),
	Cyan = Color3.fromRGB(22, 203, 255),
	CyanSoft = Color3.fromRGB(19, 103, 137),
	Red = Color3.fromRGB(204, 17, 20),
	RedBright = Color3.fromRGB(244, 34, 27),
	RedDark = Color3.fromRGB(74, 7, 13),
	Gold = Color3.fromRGB(255, 194, 24),
	GoldDark = Color3.fromRGB(121, 78, 3),
	Green = Color3.fromRGB(87, 231, 62),
	Purple = Color3.fromRGB(171, 67, 242),
	Text = Color3.fromRGB(246, 249, 250),
	Muted = Color3.fromRGB(157, 185, 201),
	Disabled = Color3.fromRGB(54, 69, 79),
	Danger = Color3.fromRGB(230, 47, 55),
}

-- UIGradient multiplies every rendered color on its parent, including text.
-- Text-bearing controls therefore use one neutral, high-luminance multiplier
-- and keep their semantic color on BackgroundColor3/TextColor3.
local TEXT_SAFE_GRADIENT_STOPS = {
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(239, 246, 249),
	Color3.fromRGB(211, 224, 230),
}
local TEXT_SAFE_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, TEXT_SAFE_GRADIENT_STOPS[1]),
	ColorSequenceKeypoint.new(0.52, TEXT_SAFE_GRADIENT_STOPS[2]),
	ColorSequenceKeypoint.new(1, TEXT_SAFE_GRADIENT_STOPS[3]),
})

local ACTION_STYLES = {
	Primary = {
		base = Color3.fromRGB(68, 211, 42),
		text = PALETTE.Ink,
		stroke = Color3.fromRGB(184, 255, 119),
	},
	Secondary = {
		base = Color3.fromRGB(12, 75, 151),
		text = PALETTE.Text,
		stroke = Color3.fromRGB(77, 205, 255),
	},
	Utility = {
		base = Color3.fromRGB(225, 149, 22),
		text = PALETTE.Ink,
		stroke = Color3.fromRGB(255, 228, 111),
	},
	Fusion = {
		base = Color3.fromRGB(113, 45, 171),
		text = PALETTE.Text,
		stroke = Color3.fromRGB(218, 132, 255),
	},
	Danger = {
		base = Color3.fromRGB(137, 22, 31),
		text = PALETTE.Text,
		stroke = Color3.fromRGB(255, 97, 82),
	},
	Disabled = {
		base = Color3.fromRGB(32, 44, 54),
		text = PALETTE.Muted,
		stroke = PALETTE.SteelLight,
	},
}

local RARITY_COLORS = {
	Common = Color3.fromRGB(79, 196, 112),
	Rare = Color3.fromRGB(50, 177, 255),
	Epic = Color3.fromRGB(178, 73, 244),
	Legendary = Color3.fromRGB(255, 179, 31),
	Secret = Color3.fromRGB(240, 55, 67),
	Premium = Color3.fromRGB(255, 211, 50),
}

local function create(className, parent, properties)
	local instance = Instance.new(className)
	for key, value in pairs(properties or {}) do
		instance[key] = value
	end
	instance.Parent = parent
	return instance
end

local function createPetViewport(parent, name, zIndex)
	local viewport = create("ViewportFrame", parent, {
		Name = name,
		Ambient = Color3.fromRGB(128, 143, 158),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ImageColor3 = Color3.new(1, 1, 1),
		ImageTransparency = 0,
		LightColor = Color3.fromRGB(255, 245, 224),
		LightDirection = Vector3.new(-1, -0.7, -0.45),
		Position = UDim2.fromOffset(3, 3),
		Size = UDim2.new(1, -6, 1, -6),
		Visible = false,
		ZIndex = zIndex,
	})
	local camera = Instance.new("Camera")
	camera.Name = "PetPreviewCamera"
	camera.FieldOfView = 34
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local world = Instance.new("WorldModel")
	world.Name = "PetPreviewWorld"
	world.Parent = viewport
	return {
		viewport = viewport,
		camera = camera,
		world = world,
		petName = nil,
	}
end

local function addCorner(parent, radius)
	return create("UICorner", parent, {
		CornerRadius = UDim.new(0, radius or 6),
	})
end

local function addStroke(parent, color, thickness, transparency)
	return create("UIStroke", parent, {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = color or PALETTE.Cyan,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
	})
end

local function addTextLimit(parent, minimum, maximum)
	return create("UITextSizeConstraint", parent, {
		MinTextSize = minimum,
		MaxTextSize = maximum,
	})
end

local function addGradient(parent, colors, rotation, transparency)
	return create("UIGradient", parent, {
		Color = colors,
		Rotation = rotation or 90,
		Transparency = transparency or NumberSequence.new(0),
	})
end

local function contrastText(color)
	local luminance = color.R * 0.299 + color.G * 0.587 + color.B * 0.114
	return luminance >= 0.54 and PALETTE.Ink or PALETTE.Text
end

local function linearizeChannel(channel)
	if channel <= 0.03928 then
		return channel / 12.92
	end
	return ((channel + 0.055) / 1.055) ^ 2.4
end

local function relativeLuminance(color)
	return linearizeChannel(color.R) * 0.2126
		+ linearizeChannel(color.G) * 0.7152
		+ linearizeChannel(color.B) * 0.0722
end

local function contrastRatio(first, second)
	local firstLuminance = relativeLuminance(first)
	local secondLuminance = relativeLuminance(second)
	local lighter = math.max(firstLuminance, secondLuminance)
	local darker = math.min(firstLuminance, secondLuminance)
	return (lighter + 0.05) / (darker + 0.05)
end

local function multiplyColor(first, second)
	return Color3.new(
		first.R * second.R,
		first.G * second.G,
		first.B * second.B
	)
end

local function minimumStyleContrast(style)
	local minimum = math.huge
	for _, multiplier in ipairs(TEXT_SAFE_GRADIENT_STOPS) do
		minimum = math.min(
			minimum,
			contrastRatio(
				multiplyColor(style.text, multiplier),
				multiplyColor(style.base, multiplier)
			)
		)
	end
	return minimum
end

local function normalize(value)
	return string.lower((tostring(value or ""):gsub("[^%w]", "")))
end

local function safeName(value)
	local result = tostring(value or "Unknown"):gsub("[^%w_%-]", "_")
	return result ~= "" and result or "Unknown"
end

local function formatNumber(value)
	value = tonumber(value) or 0
	if math.abs(value) >= 1e12 then
		return string.format("%.1fT", value / 1e12)
	elseif math.abs(value) >= 1e9 then
		return string.format("%.1fB", value / 1e9)
	elseif math.abs(value) >= 1e6 then
		return string.format("%.1fM", value / 1e6)
	elseif math.abs(value) >= 1e3 then
		return string.format("%.1fK", value / 1e3)
	end
	return tostring(math.floor(value + 0.5))
end

local function asColor(value, fallback)
	return typeof(value) == "Color3" and value or fallback
end

local function itemAccent(item)
	return asColor(item and item.accent, RARITY_COLORS[tostring(item and item.rarity)] or PALETTE.Cyan)
end

local function itemRarityColor(item)
	local rarity = tostring(item and item.rarity or "Common")
	return asColor(PolishConfig.RarityColors[rarity], RARITY_COLORS[rarity] or PALETTE.Muted)
end

local function actionName(action)
	if type(action) ~= "table" then
		return tostring(action or "")
	end
	local payload = action.payload
	local remoteAction = type(payload) == "table" and tostring(payload.action or "") or ""
	if remoteAction == "EquipFist" or remoteAction == "EquipPet" or remoteAction == "BuyHonorItem" then
		return "Equip"
	elseif remoteAction == "UnequipPet" then
		return "Unequip"
	elseif remoteAction == "LockPet" then
		return payload.value == true and "Lock" or "Unlock"
	elseif remoteAction == "FusePet" then
		return "Fuse"
	elseif remoteAction == "DeletePet" then
		return "Delete"
	elseif remoteAction == "BuyPremiumProduct" or remoteAction == "BuyShopBoost" then
		return "Use"
	end
	local providedName = tostring(action.name or "")
	local normalizedName = normalize(providedName)
	if normalizedName == "equip" or normalizedName == "unequip"
		or normalizedName == "lock" or normalizedName == "unlock"
		or normalizedName == "delete" or normalizedName == "use" or normalizedName == "fuse"
	then
		return providedName
	end
	return remoteAction ~= "" and remoteAction or providedName
end

local function actionEnabled(action)
	return type(action) == "table" and action.enabled ~= false
end

local function actionVisualStyle(semanticName, destructive, primary, enabled)
	if not enabled then
		return ACTION_STYLES.Disabled, "Disabled"
	end
	if destructive then
		return ACTION_STYLES.Danger, "Danger"
	end
	local semantic = normalize(semanticName)
	if semantic == "equip" then
		return ACTION_STYLES.Primary, "Primary"
	elseif semantic == "fuse" then
		return ACTION_STYLES.Fusion, "Fusion"
	elseif semantic == "lock" or semantic == "unlock" then
		return ACTION_STYLES.Utility, "Utility"
	elseif semantic == "use" or semantic == "unequip" then
		return ACTION_STYLES.Secondary, "Secondary"
	end
	if primary then
		return ACTION_STYLES.Primary, "Primary"
	end
	return ACTION_STYLES.Secondary, "Secondary"
end

local function itemActions(item)
	local actions = item and item.actions
	return type(actions) == "table" and actions or {}
end

local function rectsOverlap(firstPosition, firstSize, secondPosition, secondSize)
	return firstPosition.X < secondPosition.X + secondSize.X
		and firstPosition.X + firstSize.X > secondPosition.X
		and firstPosition.Y < secondPosition.Y + secondSize.Y
		and firstPosition.Y + firstSize.Y > secondPosition.Y
end

local function allocateToolbarWidths(totalWidth, useCompact, touchTarget)
	totalWidth = math.max(0, math.floor((tonumber(totalWidth) or 0) + 0.5))
	touchTarget = math.max(1, math.floor((tonumber(touchTarget) or 44) + 0.5))

	local gap = useCompact and totalWidth < 420 and 6 or 8
	local minimumSearchWidth = useCompact and touchTarget or 160
	local minimumCapacityWidth = math.max(touchTarget, useCompact and 78 or 86)
	local minimumRarityWidth = math.max(touchTarget, useCompact and 88 or 96)
	local requiredWidth = minimumSearchWidth
		+ minimumCapacityWidth
		+ minimumRarityWidth
		+ gap * 2

	-- Compact bounds are capped by the rendered safe area. Collapse the
	-- secondary labels before allowing any logical touch target to overlap.
	if totalWidth < requiredWidth then
		gap = 4
		minimumSearchWidth = touchTarget
		minimumCapacityWidth = touchTarget
		minimumRarityWidth = touchTarget
		requiredWidth = minimumSearchWidth
			+ minimumCapacityWidth
			+ minimumRarityWidth
			+ gap * 2
	end

	local distributable = math.max(0, totalWidth - requiredWidth)
	local searchExtra = math.floor(distributable * 0.60)
	local controlsExtra = distributable - searchExtra
	local capacityExtra = math.floor(controlsExtra * 0.55)
	local searchWidth = minimumSearchWidth + searchExtra
	local capacityWidth = minimumCapacityWidth + capacityExtra
	local rarityWidth = math.max(
		touchTarget,
		totalWidth - searchWidth - capacityWidth - gap * 2
	)

	local usedWidth = searchWidth + capacityWidth + rarityWidth + gap * 2
	if usedWidth > totalWidth then
		searchWidth = math.max(touchTarget, searchWidth - (usedWidth - totalWidth))
		usedWidth = searchWidth + capacityWidth + rarityWidth + gap * 2
	end

	return {
		search = searchWidth,
		capacity = capacityWidth,
		rarity = rarityWidth,
		gap = gap,
		minimumSearch = useCompact and touchTarget or 160,
		readable = useCompact or searchWidth >= 160,
		noOverlap = usedWidth <= totalWidth,
		total = totalWidth,
		used = usedWidth,
	}
end

local function hasTimedItem(snapshot)
	for _, item in ipairs(snapshot and snapshot.items or {}) do
		if tonumber(item.endsAt) and tonumber(item.endsAt) > 0 then
			return true
		end
	end
	return false
end

function InventoryUI.new(options)
	assert(type(options) == "table", "InventoryUI.new expects an options table")
	assert(typeof(options.Parent) == "Instance", "InventoryUI.new requires options.Parent")
	assert(type(options.GameConfig) == "table", "InventoryUI.new requires options.GameConfig")
	assert(type(options.GetStats) == "function", "InventoryUI.new requires options.GetStats")
	assert(options.ActionRemote ~= nil, "InventoryUI.new requires options.ActionRemote")

	local self = setmetatable({}, InventoryUI)
	self.GameConfig = options.GameConfig
	self.ActionRemote = options.ActionRemote
	self.GetStats = options.GetStats
	self.OnClose = options.OnClose
	self.OpenSpin = options.OpenSpin
	self.GetHUDHidden = options.GetHUDHidden
	self.BuildPetPreview = options.BuildPetPreview
	self.BuildFistPreview = options.BuildFistPreview

	self._connections = {}
	self._cardConnections = {}
	self._actionConnections = {}
	self._cards = {}
	self._cardPool = {}
	self._activeCardCount = 0
	self._sparseSlotPool = {}
	self._activeSparseSlotCount = 0
	self._sparseSlotCreateCount = 0
	self._cardRefsByKey = {}
	self._actionButtons = {}
	self._actionButtonRefsByKey = {}
	self._activeActionButtons = {}
	self._actionModelsByKey = {}
	self._petPreviewMasters = {}
	self._fistPreviewMasters = {}
	self._viewOnlyAction = nil
	self._categoryButtons = {}
	self._rarityButtons = {}
	self._category = "All"
	self._search = ""
	self._rarity = "All"
	self._selectedKey = nil
	self._selectedItem = nil
	self._visibleItems = {}
	self._snapshot = nil
	self._signature = nil
	self._deleteConfirmKey = nil
	self._deleteConfirmUntil = 0
	self._deleteConfirmThread = nil
	self._deleteConfirmGeneration = 0
	self._detailExpanded = false
	self._rarityMenuOpen = false
	self._updatingSearch = false
	self._lastTimedRefreshAt = 0
	self._hasTimedItem = false
	self._timerConnection = nil
	self._timerThread = nil
	self._timerGeneration = 0
	self._timerModeKey = nil
	self._timedDetailUpdateCount = 0
	self._timedExpiryRebuildCount = 0
	self._diagnosticSnapshotCount = 0
	self._diagnosticSnapshotSkipCount = 0
	self._gridRebuildCount = 0
	self._selectionVisualUpdateCount = 0
	self._selectionFocusGeneration = 0
	self._cardCreateCount = 0
	self._cardReuseCount = 0
	self._actionCreateCount = 0
	self._actionCallbackCount = 0
	self._detailRenderGeneration = 0
	self._detailRenderScheduled = false
	self._detailRenderReason = nil
	self._detailRenderCount = 0
	self._detailRenderCoalescedCount = 0
	self._destroyed = false
	self._layout = {
		compact = false,
		columns = 4,
		minTouchTarget = 44,
		detailMode = "Pane",
		viewport = Vector2.new(1280, 720),
		uiScale = 1,
	}

	self:_build(options.Parent)
	self.Root:SetAttribute("InventoryGridRebuildCount", 0)
	self.Root:SetAttribute("InventorySelectionVisualUpdateCount", 0)
	self.Root:SetAttribute("InventoryHonorSelectionContractVersion", "HonorInventoryWorldSelectionV1")
	self.Root:SetAttribute("InventoryHonorCatalogCount", 0)
	self.Root:SetAttribute("InventoryHonorVisibleCount", 0)
	self.Root:SetAttribute("InventoryHonorSelectedId", "")
	self.Root:SetAttribute("InventoryHonorCanvasY", 0)
	self.Root:SetAttribute("InventoryHonorSelectionInView", false)
	self.Root:SetAttribute("InventoryHonorSelectionFocused", false)
	self.Root:SetAttribute("InventoryLiveCardCount", 0)
	self.Root:SetAttribute("InventoryCardConnectionCount", 0)
	self.Root:SetAttribute("InventoryTimedRefreshMode", "Stopped")
	self.Root:SetAttribute("InventoryTimedDetailUpdateCount", 0)
	self.Root:SetAttribute("InventoryTimedExpiryRebuildCount", 0)
	self.Root:SetAttribute("InventoryDeleteConfirmationScheduled", false)
	self.Root:SetAttribute("InventoryDeleteConfirmationKey", "")
	self.Root:SetAttribute("InventoryCardCreateCount", 0)
	self.Root:SetAttribute("InventoryCardReuseCount", 0)
	self.Root:SetAttribute("InventoryCardConnectionsStable", true)
	self.Root:SetAttribute("InventorySparseSlotCreateCount", 0)
	self.Root:SetAttribute("InventoryActiveSparseSlotCount", 0)
	self.Root:SetAttribute("InventorySparseSlotListenerCount", 0)
	self.Root:SetAttribute("InventorySparseSlotsBounded", true)
	self.Root:SetAttribute("InventoryActionCreateCount", 0)
	self.Root:SetAttribute("InventoryActionConnectionCount", 0)
	self.Root:SetAttribute("InventoryActionConnectionsStable", true)
	self.Root:SetAttribute("InventoryActionCallbackCount", 0)
	self.Root:SetAttribute("InventoryDetailRenderCount", 0)
	self.Root:SetAttribute("InventoryDetailRenderCoalescedCount", 0)
	self.Root:SetAttribute("InventoryHoveredCategory", "")
	self.Root:SetAttribute("InventoryCategoryConnectionCount", #CATEGORIES * 5)
	self.Root:SetAttribute("InventoryToolbarAdaptive", true)
	self.Root:SetAttribute("InventoryToolbarNoOverlap", true)
	self.Root:SetAttribute("InventoryRarityMenuOpen", false)
	self.Root:SetAttribute("InventoryRarityMenuZLayer", 170)
	self.Root:SetAttribute("InventoryEmptyTreatment", "Hidden")
	self.Root:SetAttribute("InventoryEmptySlotCount", 3)
	self.Root:SetAttribute("InventoryActionContrastTarget", 4.5)
	self.Root:SetAttribute("InventoryMinimumEnabledActionContrast", 0)
	self.Root:SetAttribute("InventoryEnabledActionContrastPass", true)
	self.Root:SetAttribute("InventoryActionVisualContract", "SemanticNativeV3")
	self.Root:SetAttribute("InventoryTextGradientPolicy", "NeutralMultiplierV1")
	self.Root:SetAttribute("InventoryAuditedTextGradientControlCount", #CATEGORIES + 3)
	self:ApplyResponsive(self.Root.AbsoluteSize, false, 1)
	return self
end

function InventoryUI:_connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(self._connections, connection)
	return connection
end

function InventoryUI:_connectScoped(pool, signal, callback)
	local connection = signal:Connect(callback)
	table.insert(pool, connection)
	return connection
end

function InventoryUI:_disconnectPool(pool)
	for _, connection in ipairs(pool) do
		connection:Disconnect()
	end
	table.clear(pool)
end

function InventoryUI:_build(parent)
	self.Root = create("Frame", parent, {
		Name = "FunctionalInventory",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 140,
	})
	self.Root:SetAttribute("ArtMode", "ReferenceNativeV3")
	self.Root:SetAttribute("ChromeAssetMode", "Native")
	self.Root:SetAttribute("ItemArtFallback", "NativeFallback")
	self.Root:SetAttribute("InventoryCardChromeMode", "LayeredNativeV3")
	self.Root:SetAttribute("InventoryDetailChromeMode", "LayeredNativeV3")
	self.Root:SetAttribute("InventoryCompositionMode", "CleanThreePaneV4")
	self.Root:SetAttribute("InventoryFilteredPlaceholderPolicy", "HideSyntheticSlots")
	self.Root:SetAttribute("InventoryWideActionLayout", "ThreeSingleOrFourTwoByTwo")
	self.Root:SetAttribute("InventoryBackdropMode", "InputOnlyTransparent")
	self.Root:SetAttribute("MagentaFree", true)
	self.Root:SetAttribute("CheckerboardFree", true)

	self.CardPool = create("Frame", self.Root, {
		Name = "InventoryCardPool",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(0, 0),
		Visible = false,
	})
	self.ActionPool = create("Frame", self.Root, {
		Name = "InventoryActionPool",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(0, 0),
		Visible = false,
	})

	self.Backdrop = create("TextButton", self.Root, {
		Name = "InventoryBackdrop",
		AutoButtonColor = false,
		BackgroundColor3 = PALETTE.Backdrop,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		ZIndex = 140,
	})
	create("UIGradient", self.Backdrop, {
		Color = ColorSequence.new(Color3.fromRGB(6, 22, 34), Color3.new(0, 0, 0)),
		Rotation = 90,
		Transparency = NumberSequence.new(1),
	})

	self.WindowShadow = create("Frame", self.Root, {
		Name = "InventoryWindowShadow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.34,
		BorderSizePixel = 0,
		Position = UDim2.new(0.5, 8, 0.5, 10),
		Size = UDim2.fromOffset(1120, 680),
		ZIndex = 141,
	})
	addCorner(self.WindowShadow, 7)

	self.Window = create("Frame", self.Root, {
		Name = "InventoryWindow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = PALETTE.Ink,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(1120, 680),
		ZIndex = 142,
	})
	addCorner(self.Window, 8)
	self.WindowStroke = addStroke(self.Window, PALETTE.SteelLight, 1)
	self.Root:SetAttribute("InventoryVisualStyle", "QuietNavyV1")

	self.WindowInnerFrame = create("Frame", self.Window, {
		Name = "InventoryWindowInnerFrame",
		Visible = false,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.new(1, -12, 1, -12),
		ZIndex = 143,
	})
	addCorner(self.WindowInnerFrame, 4)
	addStroke(self.WindowInnerFrame, PALETTE.SteelLight, 1, 0.56)

	self.WindowTopRail = create("Frame", self.Window, {
		Name = "InventoryWindowTopRail",
		Visible = false,
		BackgroundColor3 = PALETTE.Cyan,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(36, -2),
		Size = UDim2.new(1, -72, 0, 2),
		ZIndex = 144,
	})
	addGradient(self.WindowTopRail, ColorSequence.new({
		ColorSequenceKeypoint.new(0, PALETTE.CyanSoft),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(147, 241, 255)),
		ColorSequenceKeypoint.new(1, PALETTE.CyanSoft),
	}), 0)

	self.WindowBottomRail = create("Frame", self.Window, {
		Name = "InventoryWindowBottomRail",
		Visible = false,
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = PALETTE.Cyan,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 36, 1, 2),
		Size = UDim2.new(1, -72, 0, 2),
		ZIndex = 144,
	})
	addGradient(self.WindowBottomRail, ColorSequence.new({
		ColorSequenceKeypoint.new(0, PALETTE.CyanSoft),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(147, 241, 255)),
		ColorSequenceKeypoint.new(1, PALETTE.CyanSoft),
	}), 0)

	for index, position in ipairs({
		UDim2.fromOffset(5, 5),
		UDim2.new(1, -5, 0, 5),
		UDim2.new(0, 5, 1, -5),
		UDim2.new(1, -5, 1, -5),
	}) do
		local brace = create("Frame", self.Window, {
			Name = "InventoryFrameBrace" .. index,
			Visible = false,
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = PALETTE.Cyan,
			BorderSizePixel = 0,
			Position = position,
			Rotation = 45,
			Size = UDim2.fromOffset(11, 11),
			ZIndex = 144,
		})
		addStroke(brace, Color3.fromRGB(165, 240, 255), 1, 0.25)
	end

	self.WindowScale = create("UIScale", self.Window, {
		Name = "InventoryScale",
		Scale = 1,
	})

	self.HeaderShadow = create("Frame", self.Window, {
		Name = "InventoryHeaderShadow",
		Visible = false,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.24,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(10, 12),
		Size = UDim2.new(1, -20, 0, 66),
		ZIndex = 143,
	})
	addCorner(self.HeaderShadow, 4)

	self.Header = create("Frame", self.Window, {
		Name = "InventoryHeader",
		BackgroundColor3 = PALETTE.Ink,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.new(1, -16, 0, 66),
		ZIndex = 144,
	})
	addCorner(self.Header, 8)

	create("Frame", self.Header, {
		Name = "HeaderTopHighlight",
		Visible = false,
		BackgroundColor3 = Color3.fromRGB(255, 81, 54),
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, 0, 0, 3),
		ZIndex = 145,
	})
	create("Frame", self.Header, {
		Name = "HeaderBottomRail",
		Visible = false,
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Color3.fromRGB(49, 3, 8),
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 7),
		ZIndex = 145,
	})
	create("Frame", self.Header, {
		Name = "HeaderGoldEdge",
		Visible = false,
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = PALETTE.GoldDark,
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 1, -7),
		Size = UDim2.new(1, 0, 0, 2),
		ZIndex = 145,
	})

	self.HeaderPattern = create("Frame", self.Header, {
		Name = "HeaderPattern",
		Visible = false,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0.61, 0, 0, 7),
		Size = UDim2.new(0.28, 0, 1, -16),
		ZIndex = 145,
	})
	for row = 0, 1 do
		for column = 0, 5 do
			local diamond = create("Frame", self.HeaderPattern, {
				Name = string.format("HeaderPattern_%d_%d", row, column),
				BackgroundColor3 = Color3.fromRGB(48, 2, 8),
				BackgroundTransparency = 0.5 + row * 0.14,
				BorderSizePixel = 0,
				Position = UDim2.new(0, column * 18 + (row % 2) * 9, 0, row * 17 + 2),
				Rotation = 45,
				Size = UDim2.fromOffset(9, 9),
				ZIndex = 145,
			})
			addCorner(diamond, 2)
		end
	end

	self.HeaderSlash = create("Frame", self.Header, {
		Name = "HeaderSlash",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = PALETTE.GoldDark,
		BackgroundTransparency = 0.18,
		BorderSizePixel = 0,
		Position = UDim2.new(0.67, 0, 0.5, 0),
		Rotation = 31,
		Size = UDim2.fromOffset(5, 108),
		Visible = false,
		ZIndex = 145,
	})

	self.Title = create("TextLabel", self.Header, {
		Name = "InventoryTitle",
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		Position = UDim2.fromOffset(30, 5),
		Rotation = 0,
		Size = UDim2.new(0.57, -30, 1, -13),
		Text = "INVENTORY",
		TextColor3 = PALETTE.Text,
		TextScaled = true,
		TextStrokeColor3 = Color3.fromRGB(13, 2, 5),
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 145,
	})
	self.TitleTextLimit = addTextLimit(self.Title, 22, 40)

	self.Subtitle = create("TextLabel", self.Header, {
		Name = "InventorySubtitle",
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Position = UDim2.fromOffset(32, 52),
		Size = UDim2.new(0.48, -32, 0, 13),
		Text = "LIVE LOADOUT  //  SERVER INVENTORY",
		TextColor3 = Color3.fromRGB(255, 196, 93),
		TextSize = 9,
		TextXAlignment = Enum.TextXAlignment.Left,
		Visible = false,
		ZIndex = 145,
	})

	self.Capacity = create("TextLabel", self.Header, {
		Name = "InventoryCapacity",
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = Color3.fromRGB(4, 14, 22),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBlack,
		Position = UDim2.new(1, -74, 0.5, 0),
		Size = UDim2.fromOffset(235, 38),
		Text = "ITEMS 0  |  PETS 0/0",
		TextColor3 = PALETTE.Text,
		TextSize = 12,
		TextTruncate = Enum.TextTruncate.None,
		TextWrapped = true,
		ZIndex = 145,
	})
	self.Capacity:SetAttribute("InventoryTextGradientMode", "NeutralMultiplier")
	addCorner(self.Capacity, 3)
	self.CapacityStroke = addStroke(self.Capacity, PALETTE.SteelLight, 1.5)
	addGradient(self.Capacity, TEXT_SAFE_GRADIENT, 90)

	self.Close = create("TextButton", self.Header, {
		Name = "InventoryClose",
		AnchorPoint = Vector2.new(1, 0.5),
		AutoButtonColor = false,
		BackgroundColor3 = PALETTE.PanelRaised,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBlack,
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(50, 50),
		Text = "X",
		TextColor3 = PALETTE.Text,
		TextSize = 24,
		ZIndex = 146,
	})
	self.Close:SetAttribute("InventoryTextGradientMode", "NeutralMultiplier")
	addCorner(self.Close, 8)
	addStroke(self.Close, PALETTE.SteelLight, 1)
	addGradient(self.Close, TEXT_SAFE_GRADIENT, 90)
	create("Frame", self.Close, {
		Name = "CloseInnerEdge",
		Visible = false,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(4, 4),
		Size = UDim2.new(1, -8, 1, -8),
		ZIndex = 147,
	})
	addStroke(self.Close.CloseInnerEdge, Color3.fromRGB(255, 142, 103), 1, 0.35)

	self.Body = create("Frame", self.Window, {
		Name = "InventoryBody",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(8, 78),
		Size = UDim2.new(1, -16, 1, -86),
		ZIndex = 143,
	})

	self.CategoryBar = create("Frame", self.Body, {
		Name = "CategoryBar",
		BackgroundColor3 = PALETTE.Panel,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		Position = UDim2.fromOffset(4, 4),
		Size = UDim2.fromOffset(WIDE_CATEGORY_WIDTH, 570),
		ZIndex = 144,
	})
	addCorner(self.CategoryBar, 4)
	addStroke(self.CategoryBar, PALETTE.SteelLight, 1, 0.5)
	self.CategoryPadding = create("UIPadding", self.CategoryBar, {
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		PaddingTop = UDim.new(0, 8),
	})
	self.CategoryLayout = create("UIListLayout", self.CategoryBar, {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Top,
	})

	for order, category in ipairs(CATEGORIES) do
		local button = create("TextButton", self.CategoryBar, {
			Name = "Category" .. category,
			AutoButtonColor = false,
			BackgroundColor3 = Color3.fromRGB(10, 27, 38),
			BorderSizePixel = 0,
			ClipsDescendants = false,
			Font = Enum.Font.GothamBlack,
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 56),
			Text = string.upper(category),
			TextColor3 = PALETTE.Text,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 145,
		})
		button:SetAttribute("InventoryCategory", category)
		button:SetAttribute("InventoryTextGradientMode", "NeutralMultiplier")
		addCorner(button, 3)
		local buttonStroke = addStroke(button, PALETTE.SteelLight, 1.5, 0.1)
		local buttonGradient = addGradient(button, TEXT_SAFE_GRADIENT, 90)
		local padding = create("UIPadding", button, {
			PaddingLeft = UDim.new(0, 50),
			PaddingRight = UDim.new(0, 13),
		})
		local icon = self:_createCategoryIcon(button, category)
		local indicator = create("Frame", button, {
			Name = "CategorySelectedIndicator",
			BackgroundColor3 = PALETTE.Gold,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(-50, 5),
			Size = UDim2.new(0, 4, 1, -10),
			Visible = false,
			ZIndex = 147,
		})
		addGradient(indicator, ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 239, 100)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 145, 8)),
		}), 90)
		local arrow = create("Frame", button, {
			Name = "CategorySelectedArrow",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = PALETTE.Gold,
			BorderSizePixel = 0,
			Position = UDim2.new(1, 12, 0.5, 0),
			Rotation = 45,
			Size = UDim2.fromOffset(16, 16),
			Visible = false,
			ZIndex = 148,
		})
		addStroke(arrow, Color3.fromRGB(255, 232, 91), 1.5)
		local widgets = {
			button = button,
			stroke = buttonStroke,
			gradient = buttonGradient,
			padding = padding,
			icon = icon,
			indicator = indicator,
			arrow = arrow,
			hovered = false,
			pointerHovered = false,
			selectionHovered = false,
		}
		self._categoryButtons[category] = widgets
		self:_connect(button.Activated, function()
			self:SetCategory(category, false)
		end)
		self:_connect(button.MouseEnter, function()
			widgets.pointerHovered = true
			self:_setCategoryInteractionState(category)
		end)
		self:_connect(button.MouseLeave, function()
			widgets.pointerHovered = false
			self:_setCategoryInteractionState(category)
		end)
		self:_connect(button.SelectionGained, function()
			widgets.selectionHovered = true
			self:_setCategoryInteractionState(category)
		end)
		self:_connect(button.SelectionLost, function()
			widgets.selectionHovered = false
			self:_setCategoryInteractionState(category)
		end)
	end
	self.Root:SetAttribute("InventoryCategoryConnectionCount", #CATEGORIES * 5)

	self.GridPane = create("Frame", self.Body, {
		Name = "InventoryGridPane",
		BackgroundColor3 = PALETTE.Panel,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(WIDE_CATEGORY_WIDTH + WIDE_CATEGORY_GAP, 4),
		Size = UDim2.new(1, -(WIDE_CATEGORY_WIDTH + WIDE_CATEGORY_GAP + 316), 1, -8),
		ZIndex = 144,
	})
	addCorner(self.GridPane, 4)
	addStroke(self.GridPane, PALETTE.SteelLight, 1, 0.5)
	create("Frame", self.GridPane, {
		Name = "GridPaneTopRail",
		Visible = false,
		BackgroundColor3 = PALETTE.CyanSoft,
		BackgroundTransparency = 0.46,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(6, 5),
		Size = UDim2.new(1, -12, 0, 2),
		ZIndex = 145,
	})

	self.Toolbar = create("Frame", self.GridPane, {
		Name = "InventoryToolbar",
		BackgroundColor3 = Color3.fromRGB(4, 14, 22),
		BackgroundTransparency = 0.06,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.new(1, -16, 0, 44),
		ZIndex = 146,
	})
	addCorner(self.Toolbar, 3)
	addStroke(self.Toolbar, PALETTE.Steel, 1, 0.42)

	self.Search = create("TextBox", self.Toolbar, {
		Name = "InventorySearch",
		BackgroundColor3 = Color3.fromRGB(3, 12, 19),
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		Font = Enum.Font.GothamMedium,
		PlaceholderColor3 = Color3.fromRGB(112, 142, 159),
		PlaceholderText = "Search items...",
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, -166, 1, 0),
		Text = "",
		TextColor3 = PALETTE.Text,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 147,
	})
	addCorner(self.Search, 3)
	self.SearchStroke = addStroke(self.Search, PALETTE.SteelLight, 1.5)
	self.SearchPadding = create("UIPadding", self.Search, {
		PaddingLeft = UDim.new(0, 35),
		PaddingRight = UDim.new(0, 10),
	})
	self.SearchGlyph = create("TextLabel", self.Toolbar, {
		Name = "InventorySearchGlyph",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.fromOffset(20, 44),
		Text = "Q",
		TextColor3 = PALETTE.Muted,
		TextSize = 14,
		ZIndex = 148,
	})
	local searchRing = addStroke(self.SearchGlyph, PALETTE.Muted, 1, 0.25)
	searchRing.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual

	self.RarityFilter = create("TextButton", self.Toolbar, {
		Name = "RarityFilter",
		AnchorPoint = Vector2.new(1, 0),
		AutoButtonColor = false,
		BackgroundColor3 = Color3.fromRGB(6, 24, 36),
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBlack,
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(154, 44),
		Text = "RARITY: ALL  v",
		TextColor3 = PALETTE.Text,
		TextSize = 12,
		TextWrapped = true,
		ZIndex = 148,
	})
	self.RarityFilter:SetAttribute("InventoryTextGradientMode", "NeutralMultiplier")
	addCorner(self.RarityFilter, 3)
	addStroke(self.RarityFilter, PALETTE.CyanSoft, 1.5)
	addGradient(self.RarityFilter, TEXT_SAFE_GRADIENT, 90)

	self.Capacity.Parent = self.Toolbar
	self.Capacity.AnchorPoint = Vector2.new(1, 0)
	self.Capacity.Position = UDim2.fromScale(1, 0)
	self.Capacity.ZIndex = 148

	self.RarityMenu = create("ScrollingFrame", self.GridPane, {
		Name = "RarityMenu",
		AnchorPoint = Vector2.new(1, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.fromRGB(5, 14, 22),
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		ClipsDescendants = true,
		ElasticBehavior = Enum.ElasticBehavior.Never,
		Active = true,
		Position = UDim2.new(1, -8, 0, 56),
		ScrollBarImageColor3 = PALETTE.Cyan,
		ScrollBarThickness = 5,
		ScrollingEnabled = false,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Size = UDim2.fromOffset(154, 7 * 44 + 12),
		Visible = false,
		ZIndex = 170,
	})
	addCorner(self.RarityMenu, 5)
	addStroke(self.RarityMenu, PALETTE.Cyan, 1.5)
	create("UIPadding", self.RarityMenu, {
		PaddingBottom = UDim.new(0, 6),
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
		PaddingTop = UDim.new(0, 6),
	})
	create("UIListLayout", self.RarityMenu, {
		Padding = UDim.new(0, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	for order, rarity in ipairs(RARITIES) do
		local option = create("TextButton", self.RarityMenu, {
			Name = "Rarity" .. rarity,
			AutoButtonColor = false,
			BackgroundColor3 = PALETTE.PanelSoft,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Font = Enum.Font.GothamBold,
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 44),
			Text = string.upper(rarity),
			TextColor3 = RARITY_COLORS[rarity] or PALETTE.Text,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 171,
		})
		addCorner(option, 2)
		addStroke(option, RARITY_COLORS[rarity] or PALETTE.Cyan, 1, 0.68)
		create("UIPadding", option, {
			PaddingLeft = UDim.new(0, 20),
			PaddingRight = UDim.new(0, 8),
		})
		create("Frame", option, {
			Name = "RarityMarker",
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = itemRarityColor({ rarity = rarity }),
			BorderSizePixel = 0,
			Position = UDim2.new(0, 9, 0.5, 0),
			Rotation = 45,
			Size = UDim2.fromOffset(7, 7),
			ZIndex = 172,
		})
		self._rarityButtons[rarity] = option
		self:_connect(option.Activated, function()
			self:SetRarity(rarity, false)
			self:_setRarityMenu(false)
		end)
	end

	self.Grid = create("ScrollingFrame", self.GridPane, {
		Name = "InventoryGrid",
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		Position = UDim2.fromOffset(8, 60),
		ScrollBarImageColor3 = PALETTE.Cyan,
		ScrollBarThickness = 6,
		Size = UDim2.new(1, -16, 1, -68),
		ZIndex = 145,
	})
	self.GridPadding = create("UIPadding", self.Grid, {
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 4),
		PaddingTop = UDim.new(0, 4),
	})
	self.GridLayout = create("UIGridLayout", self.Grid, {
		CellPadding = UDim2.fromOffset(8, 8),
		CellSize = UDim2.fromOffset(132, 148),
		FillDirectionMaxCells = 4,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})

	self.EmptyState = create("Frame", self.GridPane, {
		Name = "InventoryEmptyState",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(3, 13, 21),
		BackgroundTransparency = 0.36,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.5, 0.58),
		Size = UDim2.new(1, -48, 0, 132),
		Visible = false,
		ZIndex = 146,
	})
	addCorner(self.EmptyState, 4)
	addStroke(self.EmptyState, PALETTE.SteelLight, 1.5, 0.12)
	addGradient(self.EmptyState, ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(12, 31, 43)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(4, 15, 23)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(2, 9, 15)),
	}), 90)
	self.EmptySlotRow = create("Frame", self.EmptyState, {
		Name = "EmptySlotPreview",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(10, 9),
		Size = UDim2.new(1, -20, 0, 62),
		ZIndex = 147,
	})
	create("UIListLayout", self.EmptySlotRow, {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 7),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})
	self.EmptySlotLabels = {}
	for index = 1, 3 do
		local emptySlot = create("Frame", self.EmptySlotRow, {
			Name = "EmptySlot" .. index,
			BackgroundColor3 = Color3.fromRGB(5, 18, 28),
			BorderSizePixel = 0,
			LayoutOrder = index,
			Size = UDim2.new(1 / 3, -5, 1, 0),
			ZIndex = 147,
		})
		addCorner(emptySlot, 3)
		addStroke(emptySlot, index == 1 and PALETTE.GoldDark or PALETTE.Steel, 1.5, 0.12)
		create("Frame", emptySlot, {
			Name = "SlotTopRail",
			BackgroundColor3 = index == 1 and PALETTE.Gold or PALETTE.CyanSoft,
			BackgroundTransparency = 0.14,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(3, 3),
			Size = UDim2.new(1, -6, 0, 3),
			ZIndex = 148,
		})
		local label = create("TextLabel", emptySlot, {
			Name = "SlotState",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Font = Enum.Font.GothamBlack,
			Position = UDim2.fromOffset(4, 8),
			Size = UDim2.new(1, -8, 1, -12),
			Text = index == 1 and "LOCKED\nSLOT" or "EMPTY\nSLOT",
			TextColor3 = index == 1 and PALETTE.Gold or PALETTE.Muted,
			TextSize = 9,
			TextWrapped = true,
			ZIndex = 148,
		})
		self.EmptySlotLabels[index] = label
	end

	self.Empty = create("TextLabel", self.EmptyState, {
		Name = "InventoryEmpty",
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Position = UDim2.fromOffset(10, 76),
		Size = UDim2.new(1, -20, 1, -82),
		Text = "NO ITEMS MATCH THIS FILTER",
		TextColor3 = PALETTE.Muted,
		TextSize = 12,
		TextWrapped = true,
		ZIndex = 148,
	})

	self.Detail = create("Frame", self.Body, {
		Name = "InventoryDetail",
		BackgroundColor3 = PALETTE.Panel,
		BorderSizePixel = 0,
		Position = UDim2.new(1, -306, 0, 4),
		Size = UDim2.new(0, 302, 1, -8),
		ZIndex = 150,
	})
	addCorner(self.Detail, 4)
	self.DetailStroke = addStroke(self.Detail, PALETTE.SteelLight, 1, 0.4)
	self.DetailMetaStrip = create("Frame", self.Detail, {
		Name = "DetailMetaStrip",
		BackgroundColor3 = Color3.fromRGB(5, 18, 27),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(10, 12),
		Size = UDim2.new(1, -20, 0, 84),
		ZIndex = 151,
	})
	addCorner(self.DetailMetaStrip, 3)
	addStroke(self.DetailMetaStrip, PALETTE.SteelLight, 1, 0.3)
	addGradient(self.DetailMetaStrip, ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(16, 38, 49)),
		ColorSequenceKeypoint.new(0.4, Color3.fromRGB(6, 20, 29)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(3, 12, 19)),
	}), 90)
	for index, xPosition in ipairs({ 5, -5 }) do
		create("Frame", self.Detail, {
			Name = "DetailSideRail" .. index,
			Visible = false,
			AnchorPoint = Vector2.new(index == 2 and 1 or 0, 0),
			BackgroundColor3 = PALETTE.CyanSoft,
			BackgroundTransparency = 0.68,
			BorderSizePixel = 0,
			Position = index == 1 and UDim2.fromOffset(xPosition, 12)
				or UDim2.new(1, xPosition, 0, 12),
			Size = UDim2.new(0, 2, 1, -24),
			ZIndex = 151,
		})
	end
	self.DetailTopRail = create("Frame", self.Detail, {
		Name = "DetailTopRail",
		Visible = false,
		BackgroundColor3 = PALETTE.Gold,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(6, 5),
		Size = UDim2.new(1, -12, 0, 2),
		ZIndex = 151,
	})
	addGradient(self.DetailTopRail, ColorSequence.new({
		ColorSequenceKeypoint.new(0, PALETTE.GoldDark),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 235, 111)),
		ColorSequenceKeypoint.new(1, PALETTE.GoldDark),
	}), 0)

	self.CompactDetailDrawer = create("Frame", self.Detail, {
		Name = "CompactDetailDrawer",
		BackgroundColor3 = PALETTE.Cyan,
		BorderSizePixel = 0,
		Position = UDim2.new(0.5, -32, 0, 5),
		Size = UDim2.fromOffset(64, 4),
		Visible = false,
		ZIndex = 155,
	})
	addCorner(self.CompactDetailDrawer, 2)

	self.DetailClose = create("TextButton", self.Detail, {
		Name = "DetailDrawerClose",
		AnchorPoint = Vector2.new(1, 0),
		AutoButtonColor = false,
		BackgroundColor3 = PALETTE.PanelRaised,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBlack,
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(44, 44),
		Text = "X",
		TextColor3 = PALETTE.Text,
		TextSize = 22,
		Visible = false,
		ZIndex = 156,
	})
	addCorner(self.DetailClose, 8)
	addStroke(self.DetailClose, PALETTE.SteelLight, 1, 0)

	self.DetailArtFrame = create("Frame", self.Detail, {
		Name = "DetailArtFrame",
		BackgroundColor3 = PALETTE.Panel,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(14, 14),
		Size = UDim2.new(1, -28, 0, 210),
		ZIndex = 151,
	})
	addCorner(self.DetailArtFrame, 3)
	self.DetailArtStroke = addStroke(self.DetailArtFrame, PALETTE.SteelLight, 1, 0.6)
	self.DetailArtGlow = create("Frame", self.DetailArtFrame, {
		Name = "DetailArtGlow",
		Visible = false,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = PALETTE.Gold,
		BackgroundTransparency = 0.88,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.5, 0.54),
		Rotation = 45,
		Size = UDim2.fromScale(0.54, 0.54),
		ZIndex = 151,
	})
	addCorner(self.DetailArtGlow, 8)
	self.DetailArtCore = create("Frame", self.DetailArtFrame, {
		Name = "DetailArtCore",
		Visible = false,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.5, 0.52),
		Rotation = 45,
		Size = UDim2.fromScale(0.63, 0.63),
		ZIndex = 151,
	})
	addCorner(self.DetailArtCore, 5)
	self.DetailArtCoreStroke = addStroke(self.DetailArtCore, PALETTE.Gold, 1.5, 0.48)
	self.DetailArt = create("ImageLabel", self.DetailArtFrame, {
		Name = "DetailArt",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(10, 10),
		ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.new(1, -20, 1, -20),
		ZIndex = 152,
	})

	self.DetailRarity = create("TextLabel", self.Detail, {
		Name = "DetailRarity",
		BackgroundColor3 = PALETTE.Gold,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBlack,
		Position = UDim2.fromOffset(16, 234),
		Size = UDim2.fromOffset(104, 22),
		Text = "RARITY",
		TextColor3 = PALETTE.Ink,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 152,
	})
	addCorner(self.DetailRarity, 3)
	addStroke(self.DetailRarity, PALETTE.SteelLight, 1, 0.7)
	self.DetailCategoryTag = create("TextLabel", self.Detail, {
		Name = "DetailCategoryTag",
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Color3.fromRGB(8, 32, 22),
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBlack,
		Position = UDim2.new(1, -16, 0, 234),
		Size = UDim2.fromOffset(96, 22),
		Text = "ITEM",
		TextColor3 = PALETTE.Green,
		TextSize = 9,
		ZIndex = 152,
	})
	addCorner(self.DetailCategoryTag, 3)
	addStroke(self.DetailCategoryTag, PALETTE.Green, 1, 0.25)
	self.DetailName = create("TextLabel", self.Detail, {
		Name = "DetailName",
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		Position = UDim2.fromOffset(16, 254),
		Size = UDim2.new(1, -32, 0, 44),
		Text = "SELECT AN ITEM",
		TextColor3 = PALETTE.Text,
		TextScaled = true,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.35,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 152,
	})
	self.DetailNameTextLimit = addTextLimit(self.DetailName, 13, 21)
	self.DetailInternalName = create("TextLabel", self.Detail, {
		Name = "DetailInternalName",
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		Position = UDim2.fromOffset(16, 300),
		Size = UDim2.new(1, -32, 0, 18),
		Text = "",
		TextColor3 = Color3.fromRGB(255, 185, 41),
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 152,
	})
	self.DetailDescription = create("TextLabel", self.Detail, {
		Name = "DetailDescription",
		BackgroundColor3 = Color3.fromRGB(3, 13, 20),
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamMedium,
		Position = UDim2.fromOffset(16, 326),
		Size = UDim2.new(1, -32, 0, 94),
		Text = "Choose an item to inspect its live server-backed state.",
		TextColor3 = PALETTE.Muted,
		TextSize = 12,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 152,
	})
	self.DetailPetPreview = createPetViewport(self.DetailArtFrame, "DetailPetPreview", 153)
	addCorner(self.DetailDescription, 3)
	self.DetailDescriptionStroke = addStroke(self.DetailDescription, PALETTE.Steel, 1, 0.28)
	create("UIPadding", self.DetailDescription, {
		PaddingBottom = UDim.new(0, 4),
		PaddingLeft = UDim.new(0, 7),
		PaddingRight = UDim.new(0, 7),
		PaddingTop = UDim.new(0, 4),
	})
	self.DetailStats = create("Frame", self.Detail, {
		Name = "DetailStats",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(14, 394),
		Size = UDim2.new(1, -28, 0, 88),
		ZIndex = 152,
	})
	self.DetailStatRows = {}
	for order, definition in ipairs({
		{ "RARITY", PALETTE.Gold },
		{ "CATEGORY", PALETTE.Cyan },
		{ "STATE", PALETTE.Green },
	}) do
		local row = create("Frame", self.DetailStats, {
			Name = "DetailStat" .. definition[1],
			BackgroundColor3 = Color3.fromRGB(3, 13, 20),
			BackgroundTransparency = 0.08,
			BorderSizePixel = 0,
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 26),
			ZIndex = 152,
		})
		addCorner(row, 2)
		addStroke(row, PALETTE.Steel, 1, 0.2)
		local marker = create("Frame", row, {
			Name = "Marker",
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = definition[2],
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(7, 13),
			Rotation = 45,
			Size = UDim2.fromOffset(7, 7),
			ZIndex = 153,
		})
		local label = create("TextLabel", row, {
			Name = "Label",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Font = Enum.Font.GothamBold,
			Position = UDim2.fromOffset(20, 0),
			Size = UDim2.new(0.42, -20, 1, 0),
			Text = definition[1],
			TextColor3 = PALETTE.Muted,
			TextSize = 9,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 153,
		})
		local value = create("TextLabel", row, {
			Name = "Value",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Font = Enum.Font.GothamBlack,
			Position = UDim2.new(0.42, 0, 0, 0),
			Size = UDim2.new(0.58, -9, 1, 0),
			Text = "--",
			TextColor3 = definition[2],
			TextSize = 9,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 153,
		})
		self.DetailStatRows[order] = {
			row = row,
			marker = marker,
			label = label,
			value = value,
		}
	end
	create("UIListLayout", self.DetailStats, {
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	self.DetailStatus = create("TextLabel", self.Detail, {
		Name = "DetailStatus",
		BackgroundColor3 = Color3.fromRGB(6, 17, 25),
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		Position = UDim2.fromOffset(14, 426),
		Size = UDim2.new(1, -28, 0, 42),
		Text = "LIVE INVENTORY STATE",
		TextColor3 = PALETTE.Cyan,
		TextSize = 11,
		TextWrapped = true,
		ZIndex = 152,
	})
	addCorner(self.DetailStatus, 3)
	addStroke(self.DetailStatus, PALETTE.CyanSoft, 1.5)
	create("Frame", self.DetailStatus, {
		Name = "StatusSignal",
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = PALETTE.Cyan,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 8, 0.5, 0),
		Rotation = 45,
		Size = UDim2.fromOffset(7, 7),
		ZIndex = 153,
	})

	self.DetailActions = create("Frame", self.Detail, {
		Name = "DetailActions",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(14, 478),
		Size = UDim2.new(1, -28, 1, -492),
		ZIndex = 152,
	})
	self.DetailActionLayout = create("UIGridLayout", self.DetailActions, {
		CellPadding = UDim2.fromOffset(6, 6),
		CellSize = UDim2.fromOffset(120, 44),
		FillDirection = Enum.FillDirection.Vertical,
		FillDirectionMaxCells = 2,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
	})

	self:_connect(self.Backdrop.Activated, function()
		self:_requestClose()
	end)
	self:_connect(self.Close.Activated, function()
		self:_requestClose()
	end)
	self:_connect(self.DetailClose.Activated, function()
		self._detailExpanded = false
		self:ApplyResponsive(self._layout.viewport, true, self._layout.uiScale)
		self:_syncTimedRefresh()
	end)
	self:_connect(self.RarityFilter.Activated, function()
		self:_setRarityMenu(not self._rarityMenuOpen)
	end)
	self:_connect(self.Search:GetPropertyChangedSignal("Text"), function()
		if not self._updatingSearch then
			self:SetSearch(self.Search.Text, false)
		end
	end)
	self:_connect(self.Search.Focused, function()
		self:_setRarityMenu(false)
		self.SearchStroke.Color = PALETTE.Cyan
		self.SearchStroke.Thickness = 2
		self.Search:SetAttribute("InventoryFocusState", "Focused")
	end)
	self:_connect(self.Search.FocusLost, function()
		self.SearchStroke.Color = PALETTE.SteelLight
		self.SearchStroke.Thickness = 1.5
		self.Search:SetAttribute("InventoryFocusState", "Idle")
	end)
	self:_connect(self.Root:GetPropertyChangedSignal("AbsoluteSize"), function()
		local size = self.Root.AbsoluteSize
		if size.X > 0 and size.Y > 0 then
			self:ApplyResponsive(size, size.X < 900 or size.Y < 520, self._layout.uiScale)
			self:_syncTimedRefresh()
		end
	end)
	self:_connect(self.Root:GetPropertyChangedSignal("Visible"), function()
		self:_syncTimedRefresh()
	end)
	self:_connect(self.DetailPetPreview.viewport:GetPropertyChangedSignal("AbsoluteSize"), function()
		self:_refitDetailPreview()
	end)
end

function InventoryUI:_stopTimedRefresh()
	self._timerGeneration = self._timerGeneration + 1
	self._timerModeKey = nil
	if self._timerConnection then
		self._timerConnection:Disconnect()
		self._timerConnection = nil
	end
	if self._timerThread then
		local timerThread = self._timerThread
		self._timerThread = nil
		pcall(function()
			task.cancel(timerThread)
		end)
	end
	if self.Root then
		self.Root:SetAttribute("InventoryTimedRefreshMode", "Stopped")
	end
end

function InventoryUI:_updateTimedItemDetail(item, now)
	local endsAt = tonumber(item and item.endsAt)
	if not endsAt or endsAt <= 0 then
		return false
	end

	local currentDetail = tostring(item.detail or item.description or "")
	local baseDetail = item._inventoryTimedBaseDetail
	if type(baseDetail) ~= "string" then
		baseDetail = string.match(currentDetail, "^(.-)%s*|%s*%d+:%d%d remaining%s*$") or currentDetail
		item._inventoryTimedBaseDetail = baseDetail
	end
	local remaining = math.max(0, math.ceil(endsAt - now))
	local nextDetail = ("%s | %d:%02d remaining"):format(baseDetail, math.floor(remaining / 60), remaining % 60)
	local changed = nextDetail ~= currentDetail
	item.remainingSeconds = remaining
	item.detail = nextDetail
	item.description = nextDetail
	return changed
end

function InventoryUI:_refreshTimedItems(now)
	local snapshot = self._snapshot
	if not snapshot or type(snapshot.items) ~= "table" then
		self._hasTimedItem = false
		return false, nil
	end

	local expired = false
	local nextExpiry
	local selectedDetailChanged = false
	for _, item in ipairs(snapshot.items) do
		local endsAt = tonumber(item.endsAt)
		if endsAt and endsAt > 0 then
			if endsAt <= now then
				expired = true
			else
				nextExpiry = nextExpiry and math.min(nextExpiry, endsAt) or endsAt
				if item == self._selectedItem
					and self.Detail.Visible
					and self.DetailDescription.Visible
				then
					local changed = self:_updateTimedItemDetail(item, now)
					if changed then
						selectedDetailChanged = true
					end
				end
			end
		end
	end

	if expired then
		self._snapshot = self:_buildSnapshot(self:_getStats())
		self._hasTimedItem = hasTimedItem(self._snapshot)
		self:_applyFilter(false)
		if self.Root.Visible then
			self:ApplyResponsive(self._layout.viewport, self._layout.compact, self._layout.uiScale)
		end
		self._timedExpiryRebuildCount = self._timedExpiryRebuildCount + 1
		self.Root:SetAttribute("InventoryTimedExpiryRebuildCount", self._timedExpiryRebuildCount)
		return true, nil
	end

	self._hasTimedItem = nextExpiry ~= nil
	if selectedDetailChanged and self._selectedItem then
		self.DetailDescription.Text = tostring(self._selectedItem.description or self._selectedItem.detail or "")
		self._timedDetailUpdateCount = self._timedDetailUpdateCount + 1
		self.Root:SetAttribute("InventoryTimedDetailUpdateCount", self._timedDetailUpdateCount)
	end
	return false, nextExpiry
end

function InventoryUI:_syncTimedRefresh()
	if not self.Root or not self.Root.Parent or not self.Root.Visible or not self._snapshot or not self._hasTimedItem then
		self:_stopTimedRefresh()
		return
	end

	local now = workspace:GetServerTimeNow()
	local rebuilt, nextExpiry = self:_refreshTimedItems(now)
	if rebuilt then
		self:_syncTimedRefresh()
		return
	end
	if not nextExpiry then
		self:_stopTimedRefresh()
		return
	end

	local selectedEndsAt = tonumber(self._selectedItem and self._selectedItem.endsAt)
	local selectedTimedVisible = selectedEndsAt
		and selectedEndsAt > now
		and self.Detail.Visible
		and self.DetailDescription.Visible
	local modeKey
	if selectedTimedVisible then
		modeKey = ("detail:%s:%.6f"):format(tostring(self._selectedItem.key or ""), selectedEndsAt)
		if self._timerModeKey == modeKey and self._timerConnection then
			return
		end
	else
		modeKey = ("expiry:%.6f"):format(nextExpiry)
		if self._timerModeKey == modeKey and self._timerThread then
			return
		end
	end

	self:_stopTimedRefresh()
	self._timerModeKey = modeKey
	local generation = self._timerGeneration
	if selectedTimedVisible then
		self._lastTimedRefreshAt = now
		self.Root:SetAttribute("InventoryTimedRefreshMode", "SelectedDetailHeartbeat")
		self._timerConnection = RunService.Heartbeat:Connect(function()
			if generation ~= self._timerGeneration then
				return
			end
			if not self.Root or not self.Root.Parent or not self.Root.Visible or not self._hasTimedItem then
				self:_stopTimedRefresh()
				return
			end
			local tickNow = workspace:GetServerTimeNow()
			if math.floor(tickNow) <= math.floor(self._lastTimedRefreshAt) then
				return
			end
			self._lastTimedRefreshAt = tickNow
			local tickRebuilt = self:_refreshTimedItems(tickNow)
			if tickRebuilt or not self._hasTimedItem then
				self:_syncTimedRefresh()
			end
		end)
		return
	end

	self.Root:SetAttribute("InventoryTimedRefreshMode", "ExpiryDelay")
	self._timerThread = task.delay(math.max(0.03, nextExpiry - now + 0.03), function()
		if generation ~= self._timerGeneration then
			return
		end
		self._timerThread = nil
		if not self.Root or not self.Root.Parent or not self.Root.Visible then
			self:_stopTimedRefresh()
			return
		end
		self:_refreshTimedItems(workspace:GetServerTimeNow())
		self:_syncTimedRefresh()
	end)
end

function InventoryUI:_refreshDeleteConfirmationLabel()
	local item = self._selectedItem
	if not item then
		return
	end
	local awaitingConfirmation = self._deleteConfirmKey == tostring(item.key)
		and os.clock() <= self._deleteConfirmUntil
	for _, button in ipairs(self._activeActionButtons) do
		if button:IsA("TextButton") and button:GetAttribute("Destructive") == true then
			local semanticName = tostring(button:GetAttribute("InventoryAction") or "")
			local normalLabel = semanticName
			for _, action in ipairs(itemActions(item)) do
				if normalize(actionName(action)) == normalize(semanticName) then
					normalLabel = tostring(action.label or semanticName)
					break
				end
			end
			button.Text = string.upper(awaitingConfirmation and "CONFIRM DELETE" or normalLabel)
		end
	end
end

function InventoryUI:_cancelDeleteConfirmation(refreshLabel)
	self._deleteConfirmGeneration = self._deleteConfirmGeneration + 1
	if self._deleteConfirmThread then
		local confirmThread = self._deleteConfirmThread
		self._deleteConfirmThread = nil
		pcall(function()
			task.cancel(confirmThread)
		end)
	end
	self._deleteConfirmKey = nil
	self._deleteConfirmUntil = 0
	if self.Root then
		self.Root:SetAttribute("InventoryDeleteConfirmationScheduled", false)
		self.Root:SetAttribute("InventoryDeleteConfirmationKey", "")
	end
	if refreshLabel == true then
		self:_refreshDeleteConfirmationLabel()
	end
end

function InventoryUI:_armDeleteConfirmation(key)
	self:_cancelDeleteConfirmation(false)
	self._deleteConfirmKey = tostring(key)
	self._deleteConfirmUntil = os.clock() + 3
	local generation = self._deleteConfirmGeneration
	self.Root:SetAttribute("InventoryDeleteConfirmationScheduled", true)
	self.Root:SetAttribute("InventoryDeleteConfirmationKey", self._deleteConfirmKey)
	self._deleteConfirmThread = task.delay(3, function()
		if generation ~= self._deleteConfirmGeneration
			or self._deleteConfirmKey ~= tostring(key)
		then
			return
		end
		self._deleteConfirmThread = nil
		self._deleteConfirmKey = nil
		self._deleteConfirmUntil = 0
		if self.Root and self.Root.Parent then
			self.Root:SetAttribute("InventoryDeleteConfirmationScheduled", false)
			self.Root:SetAttribute("InventoryDeleteConfirmationKey", "")
			self:_refreshDeleteConfirmationLabel()
		end
	end)
	self:_refreshDeleteConfirmationLabel()
end

function InventoryUI:_cancelPendingDetailRender()
	self._detailRenderGeneration = self._detailRenderGeneration + 1
	self._detailRenderScheduled = false
	self._detailRenderReason = nil
end

function InventoryUI:_requestDetailRender(reason)
	if self._destroyed or not self.Root or not self.Root.Parent then
		return
	end
	self._detailRenderReason = tostring(reason or "unspecified")
	if self._detailRenderScheduled then
		self._detailRenderCoalescedCount = self._detailRenderCoalescedCount + 1
		self.Root:SetAttribute("InventoryDetailRenderCoalescedCount", self._detailRenderCoalescedCount)
		return
	end

	self._detailRenderScheduled = true
	local generation = self._detailRenderGeneration
	task.defer(function()
		if self._destroyed
			or generation ~= self._detailRenderGeneration
			or not self.Root
			or not self.Root.Parent
		then
			return
		end
		self._detailRenderScheduled = false
		self._detailRenderCount = self._detailRenderCount + 1
		self.Root:SetAttribute("InventoryDetailRenderCount", self._detailRenderCount)
		self.Root:SetAttribute("InventoryDetailRenderReason", self._detailRenderReason or "")
		self._detailRenderReason = nil
		self:_renderDetail()
		self:ApplyResponsive(self._layout.viewport, self._layout.compact, self._layout.uiScale)
		self:_syncTimedRefresh()
	end)
end

function InventoryUI:_createCategoryIcon(parent, category)
	local accent = PALETTE.Text
	local icon = create("Frame", parent, {
		Name = "CategoryIcon",
		BackgroundColor3 = Color3.fromRGB(5, 17, 26),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(-41, 8),
		Size = UDim2.fromOffset(40, 40),
		ZIndex = 146,
	})
	icon:SetAttribute("InventoryCategoryIconStyle", "UnifiedProceduralGlyphV1")
	icon:SetAttribute("InventoryCategoryIconCategory", category)
	icon:SetAttribute("InventoryCategoryIconEmbeddedText", false)
	addCorner(icon, 6)
	local iconStroke = addStroke(icon, PALETTE.SteelLight, 1, 0.5)
	iconStroke.Name = "CategoryIconStroke"
	addGradient(icon, ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(17, 39, 51)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(3, 12, 19)),
	}), 90)
	create("UIAspectRatioConstraint", icon, {
		AspectRatio = 1,
		AspectType = Enum.AspectType.FitWithinMaxSize,
		DominantAxis = Enum.DominantAxis.Width,
	})
	local glyph = create("Frame", icon, {
		Name = "CategoryGlyph",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.08, 0.08),
		Size = UDim2.fromScale(0.84, 0.84),
		ZIndex = 147,
	})

	local function shape(name, position, size, color, radius, rotation)
		local part = create("Frame", glyph, {
			Name = name,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Position = position,
			Rotation = rotation or 0,
			Size = size,
			ZIndex = 148,
		})
		if radius then addCorner(part, radius) end
		return part
	end

	if category == "All" then
		for index, position in ipairs({
			UDim2.fromScale(0.13, 0.13),
			UDim2.fromScale(0.55, 0.13),
			UDim2.fromScale(0.13, 0.55),
			UDim2.fromScale(0.55, 0.55),
		}) do
			local tile = shape("GridTile" .. index, position, UDim2.fromScale(0.32, 0.32), accent, 3)
			addGradient(tile, ColorSequence.new(Color3.fromRGB(154, 247, 255), accent), 45)
		end
	elseif category == "Fists" then
		local palm = shape("GlovePalm", UDim2.fromScale(0.25, 0.31), UDim2.fromScale(0.53, 0.43), accent, 5, -5)
		addGradient(palm, ColorSequence.new(Color3.fromRGB(255, 109, 82), Color3.fromRGB(156, 21, 31)), 90)
		for index = 0, 3 do
			shape("GloveKnuckle" .. index, UDim2.fromScale(0.18 + index * 0.17, 0.14), UDim2.fromScale(0.2, 0.27), accent, 6, -5)
		end
		shape("GloveThumb", UDim2.fromScale(0.12, 0.43), UDim2.fromScale(0.25, 0.28), Color3.fromRGB(205, 35, 38), 5, 18)
		shape("GloveCuff", UDim2.fromScale(0.31, 0.69), UDim2.fromScale(0.46, 0.19), Color3.fromRGB(132, 20, 28), 3, -5)
	elseif category == "Pets" then
		local egg = shape("PetEgg", UDim2.fromScale(0.24, 0.08), UDim2.fromScale(0.52, 0.82), Color3.fromRGB(235, 244, 238), 12)
		addStroke(egg, accent, 1.3, 0.12)
		addGradient(egg, ColorSequence.new(Color3.fromRGB(255, 249, 221), Color3.fromRGB(176, 226, 238)), 90)
		shape("EggSpotA", UDim2.fromScale(0.38, 0.27), UDim2.fromScale(0.18, 0.18), accent, 6, -12)
		shape("EggSpotB", UDim2.fromScale(0.52, 0.51), UDim2.fromScale(0.15, 0.21), Color3.fromRGB(52, 146, 230), 6, 15)
		shape("EggSpotC", UDim2.fromScale(0.30, 0.61), UDim2.fromScale(0.13, 0.14), Color3.fromRGB(76, 187, 231), 5)
	elseif category == "Boosts" then
		local bolt = create("TextLabel", glyph, {
			Name = "BoostBolt",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.05, -0.04),
			Size = UDim2.fromScale(0.9, 1.05),
			Font = Enum.Font.GothamBlack,
			Text = "⚡",
			TextColor3 = accent,
			TextScaled = true,
			TextStrokeColor3 = Color3.fromRGB(128, 62, 4),
			TextStrokeTransparency = 0.18,
			ZIndex = 148,
		})
		bolt:SetAttribute("SemanticGlyph", "Boost")
	elseif category == "Honor" then
		shape("MedalRibbonLeft", UDim2.fromScale(0.26, 0.59), UDim2.fromScale(0.22, 0.34), Color3.fromRGB(39, 132, 210), 2, 12)
		shape("MedalRibbonRight", UDim2.fromScale(0.52, 0.59), UDim2.fromScale(0.22, 0.34), Color3.fromRGB(25, 94, 176), 2, -12)
		local medal = shape("HonorMedal", UDim2.fromScale(0.18, 0.08), UDim2.fromScale(0.64, 0.64), accent, 12)
		addStroke(medal, Color3.fromRGB(255, 239, 145), 1.4, 0.08)
		addGradient(medal, ColorSequence.new(Color3.fromRGB(255, 242, 124), Color3.fromRGB(201, 112, 5)), 90)
		local core = shape("HonorCore", UDim2.fromScale(0.32, 0.22), UDim2.fromScale(0.36, 0.36), Color3.fromRGB(17, 70, 126), 8)
		addStroke(core, Color3.fromRGB(196, 238, 255), 1, 0.18)
		shape("HonorDiamond", UDim2.fromScale(0.43, 0.33), UDim2.fromScale(0.14, 0.14), Color3.fromRGB(225, 247, 255), 2, 45)
	end

	return icon
end

function InventoryUI:_applyAtlasIcon(image, iconName)
	image.Image = ""
	image.ImageRectOffset = Vector2.zero
	image.ImageRectSize = Vector2.zero
	local atlas = self.GameConfig.UIIconAtlas
	local region = atlas and atlas.regions and atlas.regions[iconName]
	if atlas and atlas.image and region then
		image.Image = atlas.image
		image.ImageRectOffset = Vector2.new(region[1], region[2])
		image.ImageRectSize = Vector2.new(region[3], region[4])
		return true
	end
	return false
end

function InventoryUI:_getPetPreviewMaster(petName)
	petName = tostring(petName or "")
	if petName == "" or type(self.BuildPetPreview) ~= "function" then
		return nil
	end
	local cached = self._petPreviewMasters[petName]
	if cached ~= nil then
		return cached ~= false and cached or nil
	end
	local ok, model = pcall(self.BuildPetPreview, petName)
	if not ok or typeof(model) ~= "Instance" or not model:IsA("Model") then
		if typeof(model) == "Instance" then model:Destroy() end
		self._petPreviewMasters[petName] = false
		warn("InventoryUI could not build pet preview for " .. petName)
		return nil
	end
	model.Name = "InventoryPetPreviewMaster_" .. safeName(petName)
	model.Parent = nil
	self._petPreviewMasters[petName] = model
	return model
end

function InventoryUI:_clearPetPreview(previewRef)
	if not previewRef then return end
	previewRef.world:ClearAllChildren()
	previewRef.petName = nil
	previewRef.fistName = nil
	previewRef.viewport.Visible = false
	previewRef.viewport:SetAttribute("PreviewPetName", "")
	previewRef.viewport:SetAttribute("PreviewFistName", "")
	previewRef.viewport:SetAttribute("PreviewReady", false)
end

local function forestPupPreviewCamera(clone, camera, viewport, boundsCFrame, boundsSize, minimumDistance)
	-- This imported pet has one authored front-face decal. Keep its geometry and
	-- texture intact; the generic world-space camera was looking at its back.
	local facePart
	for _, descendant in ipairs(clone:GetDescendants()) do
		local parent = descendant.Parent
		if descendant:IsA("Decal") and descendant.Face == Enum.NormalId.Front
			and descendant.Transparency < 1 and parent and parent:IsA("BasePart")
			and parent.Name == "AnimatedFace" then
			facePart = parent
			break
		end
	end
	if not facePart then return nil end
	local normal = facePart.CFrame.LookVector
	local direction = (normal + facePart.CFrame.RightVector * 0.25 + facePart.CFrame.UpVector * 0.18).Unit
	local center = boundsCFrame.Position
	local basis = CFrame.lookAt(center + direction, center)
	local size = viewport.AbsoluteSize
	local aspect = size.X > 0 and size.Y > 0 and size.X / size.Y or 1
	local tanVertical = math.tan(math.rad(camera.FieldOfView * 0.5))
	local tanHorizontal = tanVertical * aspect
	local distance = minimumDistance
	for x = -1, 1, 2 do
		for y = -1, 1, 2 do
			for z = -1, 1, 2 do
				local worldCorner = boundsCFrame:PointToWorldSpace(Vector3.new(boundsSize.X * x, boundsSize.Y * y, boundsSize.Z * z) * 0.5)
				local corner = basis:VectorToObjectSpace(worldCorner - center)
				distance = math.max(distance, corner.Z + math.max(math.abs(corner.X) / tanHorizontal, math.abs(corner.Y) / tanVertical) * 1.12)
			end
		end
	end
	return CFrame.lookAt(center + direction * distance, center)
end

function InventoryUI:_applyPetPreview(previewRef, item)
	if not previewRef then return false end
	local petName = item and item.category == "Pets" and tostring(item.previewPet or "") or ""
	if petName == "" then
		self:_clearPetPreview(previewRef)
		return false
	end
	if previewRef.petName ~= petName or #previewRef.world:GetChildren() == 0 then
		self:_clearPetPreview(previewRef)
		local master = self:_getPetPreviewMaster(petName)
		if not master then return false end
		local clone = master:Clone()
		clone.Name = "PetPreview_" .. safeName(petName)
		for _, descendant in ipairs(clone:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
				descendant.CanCollide = false
				descendant.CanQuery = false
				descendant.CanTouch = false
			elseif descendant:IsA("ParticleEmitter")
				or descendant:IsA("Beam")
				or descendant:IsA("Trail")
				or descendant:IsA("Light")
			then
				descendant:Destroy()
			end
		end
		clone.Parent = previewRef.world
		local boundsCFrame, boundsSize = clone:GetBoundingBox()
		local radius = math.max(boundsSize.X, boundsSize.Y, boundsSize.Z) * 0.5
		local distance = math.max(2.6, radius / math.tan(math.rad(previewRef.camera.FieldOfView * 0.62)))
		local center = boundsCFrame.Position
		local authoredFaceCamera = petName == "Forest Pup" and forestPupPreviewCamera(
			clone, previewRef.camera, previewRef.viewport, boundsCFrame, boundsSize, distance
		) or nil
		previewRef.camera.CFrame = authoredFaceCamera or CFrame.lookAt(
			center + Vector3.new(distance * 0.48, distance * 0.2, -distance),
			center + Vector3.new(0, boundsSize.Y * 0.04, 0)
		)
		previewRef.petName = petName
	end
	previewRef.viewport.ImageTransparency = item.locked == true and 0.34 or 0
	previewRef.viewport.Visible = true
	previewRef.viewport:SetAttribute("PreviewPetName", petName)
	previewRef.viewport:SetAttribute("PreviewReady", true)
	previewRef.viewport:SetAttribute("PreviewSource", "ExactEquippedModel")
	return true
end

function InventoryUI:_getFistPreviewMaster(fistName)
	if fistName == "" or type(self.BuildFistPreview) ~= "function" then return nil end
	local cached = self._fistPreviewMasters[fistName]
	if cached ~= nil then return cached ~= false and cached or nil end
	local ok, model = pcall(self.BuildFistPreview, fistName)
	if not ok or typeof(model) ~= "Instance" or not model:IsA("Model") then
		if typeof(model) == "Instance" then model:Destroy() end
		self._fistPreviewMasters[fistName] = false
		-- Unsupported catalog entries deliberately retain their existing art.
		if not ok then warn("InventoryUI could not build fist preview for " .. fistName) end
		return nil
	end
	model.Name = "InventoryFistPreviewMaster_" .. safeName(fistName)
	model.Parent = nil
	self._fistPreviewMasters[fistName] = model
	return model
end

function InventoryUI:_applyModelPreview(previewRef, item)
	if not item or item.category ~= "Fists" then
		return self:_applyPetPreview(previewRef, item), "ModelMatchedViewportV1"
	end
	if not previewRef then return false end
	local fistName = tostring(item.name or "")
	if previewRef.fistName ~= fistName or #previewRef.world:GetChildren() == 0 then
		self:_clearPetPreview(previewRef)
		local master = self:_getFistPreviewMaster(fistName)
		if not master then return false end
		local clone = master:Clone()
		clone.Name = "FistPreview_" .. safeName(fistName)
		for _, descendant in ipairs(clone:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
				descendant.CanCollide = false
				descendant.CanQuery = false
				descendant.CanTouch = false
			elseif descendant:IsA("LuaSourceContainer")
				or descendant:IsA("ParticleEmitter") or descendant:IsA("Beam")
				or descendant:IsA("Trail") or descendant:IsA("Light")
				or descendant:IsA("Highlight") then
				descendant:Destroy()
			end
		end
		clone.Parent = previewRef.world
		local boundsCFrame, boundsSize = clone:GetBoundingBox()
		local radius = math.max(boundsSize.X, boundsSize.Y, boundsSize.Z) * 0.5
		local distance = math.max(2.6, radius / math.tan(math.rad(previewRef.camera.FieldOfView * 0.5)) * 1.2)
		local center = boundsCFrame.Position
		previewRef.camera.CFrame = CFrame.lookAt(
			center + Vector3.new(distance * 0.65, distance * 0.28, distance), center
		)
		previewRef.fistName = fistName
	end
	previewRef.viewport.ImageTransparency = item.locked == true and 0.34 or 0
	previewRef.viewport.Visible = true
	previewRef.viewport:SetAttribute("PreviewFistName", fistName)
	previewRef.viewport:SetAttribute("PreviewReady", true)
	previewRef.viewport:SetAttribute("PreviewSource", "SharedCatalogFistModel")
	return true, "SharedFistViewportV1"
end

function InventoryUI:_refitDetailPreview()
	local preview = self.DetailPetPreview
	if not preview then return end
	local model = preview.world:FindFirstChildWhichIsA("Model")
	if not model then
		preview.detailFitModel = nil
		preview.detailBaseCamera = nil
		preview.detailFitSize = nil
		preview.viewport:SetAttribute("PreviewFitMode", "Unavailable")
		return
	end
	if not self._layout.tallDetail then
		if model and preview.detailFitModel == model and preview.detailBaseCamera then
			preview.camera.CFrame = preview.detailBaseCamera
		end
		preview.detailFitModel = nil
		preview.detailBaseCamera = nil
		preview.detailFitSize = nil
		preview.viewport:SetAttribute("PreviewFitMode", "Original")
		return
	end
	local size = preview.viewport.AbsoluteSize
	if size.X < 1 or size.Y < 1 then return end
	if preview.detailFitModel == model and preview.detailFitSize == size then return end
	if preview.detailFitModel ~= model then
		preview.detailFitModel = model
		preview.detailBaseCamera = preview.camera.CFrame
	end
	local bounds, boundsSize = model:GetBoundingBox()
	local center = bounds.Position
	local base = preview.detailBaseCamera
	local direction = base.Position - center
	if direction.Magnitude < 0.001 then return end
	direction = direction.Unit
	local basis = CFrame.lookAt(center + direction, center, base.UpVector)
	local tanY = math.tan(math.rad(preview.camera.FieldOfView * 0.5))
	local tanX = tanY * size.X / size.Y
	local distance = 2.6
	-- Fit the existing clone, preserving its front/backhand direction. Only the
	-- selected detail viewport is refitted, on layout/model changes, never a loop.
	for x = -1, 1, 2 do
		for y = -1, 1, 2 do
			for z = -1, 1, 2 do
				local world = bounds:PointToWorldSpace(Vector3.new(boundsSize.X * x, boundsSize.Y * y, boundsSize.Z * z) * 0.5)
				local corner = basis:VectorToObjectSpace(world - center)
				distance = math.max(distance, corner.Z + math.max(math.abs(corner.X) / tanX, math.abs(corner.Y) / tanY) * 1.12)
			end
		end
	end
	preview.camera.CFrame = CFrame.lookAt(center + direction * distance, center, base.UpVector)
	preview.detailFitSize = size
	preview.viewport:SetAttribute("PreviewFitMode", "TallDetailEightCornersV1")
	preview.viewport:SetAttribute("PreviewFitWidth", size.X)
	preview.viewport:SetAttribute("PreviewFitHeight", size.Y)
end

function InventoryUI:_applyItemArt(image, item)
	image.Image = ""
	image.ImageRectOffset = Vector2.zero
	image.ImageRectSize = Vector2.zero
	image.ImageColor3 = Color3.new(1, 1, 1)
	local art = item and item.art
	if type(art) == "string" and art ~= "" then
		image.Image = art
		return "UploadedItemArt"
	end
	local icon = item and item.icon
	if type(icon) == "string" and string.find(icon, "rbxassetid://", 1, true) == 1 then
		image.Image = icon
		return "UploadedItemArt"
	end
	if type(icon) == "string" and self:_applyAtlasIcon(image, icon) then
		return "Atlas"
	end
	local category = tostring(item and item.category or "All")
	if self:_applyAtlasIcon(image, CATEGORY_ICONS[category] or "Menu") then
		return "Atlas"
	end
	return "NativeFallback"
end

function InventoryUI:_setRarityMenu(visible)
	local opening = visible == true and not self._rarityMenuOpen
	self._rarityMenuOpen = visible == true
	self.RarityMenu.Visible = self._rarityMenuOpen
	self.RarityMenu.Active = self._rarityMenuOpen
	self.RarityMenu.ScrollingEnabled = self._rarityMenuOpen
	if opening then
		self.RarityMenu.CanvasPosition = Vector2.zero
	end
	local rarityName = string.upper(self._rarity)
	local arrow = self._rarityMenuOpen and "^" or "v"
	if (tonumber(self._toolbarRarityWidth) or 154) < 132 then
		self.RarityFilter.Text = "RARITY\n" .. rarityName .. "  " .. arrow
	else
		self.RarityFilter.Text = "RARITY  " .. rarityName .. "  " .. arrow
	end
	self.RarityFilter:SetAttribute("InventoryExpanded", self._rarityMenuOpen)
	self.RarityFilter:SetAttribute("InventoryRarityAccessibleText", "RARITY " .. rarityName)
	self.RarityMenu:SetAttribute("InventoryZLayerIntent", "OverlayAboveGrid")
	self.Root:SetAttribute("InventoryRarityMenuOpen", self._rarityMenuOpen)
	self.Root:SetAttribute("InventoryRarityMenuZLayer", self.RarityMenu.ZIndex)
end

function InventoryUI:_requestClose()
	self:SetVisible(false)
	if type(self.OnClose) == "function" then
		self.OnClose()
	end
end

function InventoryUI:_getStats()
	local ok, stats = pcall(self.GetStats)
	if not ok then
		warn("InventoryUI GetStats failed: " .. tostring(stats))
		return {}
	end
	return type(stats) == "table" and stats or {}
end

function InventoryUI:_buildSnapshot(stats)
	local ok, snapshot = pcall(InventoryViewModel.Build, self.GameConfig, stats, workspace:GetServerTimeNow())
	if not ok then
		warn("InventoryViewModel.Build failed: " .. tostring(snapshot))
		return {
			items = {},
			itemCount = 0,
			capacity = {
				used = 0,
				total = tonumber(self.GameConfig.MaxPetInventory) or 0,
			},
		}
	end
	return type(snapshot) == "table" and snapshot or { items = {} }
end

function InventoryUI:_filterSnapshot()
	local snapshot = self._snapshot or { items = {} }
	local ok, result = pcall(
		InventoryViewModel.Filter,
		snapshot,
		self._category,
		self._search,
		self._rarity
	)
	if not ok then
		warn("InventoryViewModel.Filter failed: " .. tostring(result))
		return {}
	end
	if type(result) ~= "table" then
		return {}
	end
	return type(result.items) == "table" and result.items or result
end

function InventoryUI:_findItem(key)
	if not key or not self._snapshot then
		return nil
	end
	local ok, result = pcall(InventoryViewModel.Find, self._snapshot, key)
	if ok and type(result) == "table" then
		return result
	end
	for _, item in ipairs(self._snapshot.items or {}) do
		if tostring(item.key) == tostring(key) then
			return item
		end
	end
	return nil
end

function InventoryUI:_updateCapacity()
	local snapshot = self._snapshot or {}
	local capacity = snapshot.capacity or {}
	local itemCount = tonumber(snapshot.itemCount) or #(snapshot.items or {})
	local used = tonumber(capacity.used or snapshot.petUsed) or 0
	local maximum = tonumber(capacity.total or capacity.max or snapshot.petCapacity)
		or tonumber(self.GameConfig.MaxPetInventory)
		or 0
	local itemText = formatNumber(itemCount)
	local usedText = formatNumber(used)
	local maximumText = formatNumber(maximum)
	local availableWidth = tonumber(self._toolbarCapacityWidth) or WIDE_CATEGORY_WIDTH
	local fullText = string.format("ITEMS %s  |  PETS %s/%s", itemText, usedText, maximumText)
	if availableWidth < 116 then
		self.Capacity.Text = string.format("ITEM %s\nPET %s/%s", itemText, usedText, maximumText)
		self.Capacity:SetAttribute("InventoryCapacityTextMode", "Compact")
	elseif availableWidth < 154 then
		self.Capacity.Text = string.format("ITEMS %s\nPETS %s/%s", itemText, usedText, maximumText)
		self.Capacity:SetAttribute("InventoryCapacityTextMode", "Condensed")
	else
		self.Capacity.Text = fullText
		self.Capacity:SetAttribute("InventoryCapacityTextMode", "Full")
	end
	self.Capacity:SetAttribute("InventoryCapacityFullText", fullText)
	self.Capacity:SetAttribute("InventoryCapacityRenderedText", self.Capacity.Text)
	self.Capacity:SetAttribute("InventoryCapacityReadable", true)
	self.Capacity:SetAttribute("Used", used)
	self.Capacity:SetAttribute("Maximum", maximum)
end

function InventoryUI:_applyCategoryVisual(category)
	local widgets = self._categoryButtons[category]
	if not widgets then
		return
	end

	local selected = category == self._category
	local hovered = widgets.hovered == true
	local state = selected and "Selected" or hovered and "Hovered" or "Idle"
	widgets.button:SetAttribute("InventoryVisualState", state)
	widgets.button:SetAttribute("InventoryHovered", hovered)
	widgets.button.BackgroundColor3 = selected and PALETTE.CardHover
		or hovered and Color3.fromRGB(10, 43, 57)
		or PALETTE.PanelRaised
	widgets.button.TextColor3 = PALETTE.Text
	widgets.stroke.Color = selected and PALETTE.Cyan
		or hovered and PALETTE.SteelLight
		or PALETTE.SteelLight
	widgets.stroke.Thickness = selected and 2 or hovered and 1.5 or 1
	widgets.gradient.Color = TEXT_SAFE_GRADIENT
	widgets.icon.BackgroundColor3 = selected and Color3.fromRGB(29, 35, 31)
		or hovered and Color3.fromRGB(7, 34, 46)
		or Color3.fromRGB(5, 17, 26)
	local iconStroke = widgets.icon:FindFirstChild("CategoryIconStroke")
	if iconStroke and iconStroke:IsA("UIStroke") then
		iconStroke.Thickness = selected and 2 or hovered and 1.7 or 1.25
		iconStroke.Transparency = selected and 0 or hovered and 0.08 or 0.22
	end
	widgets.indicator.BackgroundColor3 = selected and PALETTE.Cyan or PALETTE.SteelLight
	widgets.arrow.BackgroundColor3 = PALETTE.Cyan
	widgets.indicator.Visible = selected or hovered
	widgets.arrow.Visible = selected and not self._layout.compact
end

function InventoryUI:_setCategoryInteractionState(category)
	local widgets = self._categoryButtons[category]
	if not widgets then
		return
	end
	widgets.hovered = widgets.pointerHovered == true or widgets.selectionHovered == true
	if widgets.hovered then
		self.Root:SetAttribute("InventoryHoveredCategory", category)
	elseif self.Root:GetAttribute("InventoryHoveredCategory") == category then
		self.Root:SetAttribute("InventoryHoveredCategory", "")
	end
	self:_applyCategoryVisual(category)
end

function InventoryUI:_renderCategories()
	for category in pairs(self._categoryButtons) do
		self:_applyCategoryVisual(category)
	end
	for rarity, button in pairs(self._rarityButtons) do
		local selected = rarity == self._rarity
		button.BackgroundTransparency = selected and 0 or 0.32
		button.BackgroundColor3 = selected and Color3.fromRGB(27, 45, 57) or PALETTE.PanelSoft
		button:SetAttribute("InventoryRaritySelected", selected)
		button:SetAttribute("InventoryRarityValue", rarity)
	end
	self:_setRarityMenu(self._rarityMenuOpen)
end

function InventoryUI:_clearCards()
	table.clear(self._cardRefsByKey)
	self._activeCardCount = 0
	for _, cardRef in ipairs(self._cardPool) do
		cardRef.hovered = false
		cardRef.key = nil
		cardRef.item = nil
		cardRef.card.Active = false
		cardRef.card.Selectable = false
		cardRef.card.Visible = false
		cardRef.card.Parent = self.CardPool
	end
	if self._destroyed then
		self:_disconnectPool(self._cardConnections)
		for _, card in ipairs(self._cards) do
			card:Destroy()
		end
		table.clear(self._cards)
		table.clear(self._cardPool)
	end
end

function InventoryUI:_applyCardSelectionVisual(key, selected)
	local refs = self._cardRefsByKey[tostring(key or "")]
	if type(refs) ~= "table" then
		return 0
	end
	local updated = 0
	for _, ref in ipairs(refs) do
		local card = ref.card
		local stroke = ref.stroke
		if card and card.Parent and stroke and stroke.Parent then
			if selected then
				card.BackgroundColor3 = PALETTE.CardHover
				stroke.Color = PALETTE.Cyan
				stroke.Thickness = 2
			elseif ref.hovered then
				card.BackgroundColor3 = PALETTE.CardHover
				stroke.Color = PALETTE.SteelLight
				stroke.Thickness = 1.5
			else
				card.BackgroundColor3 = PALETTE.Card
				stroke.Color = PALETTE.SteelLight
				stroke.Thickness = 1
			end
			updated = updated + 1
		end
	end
	return updated
end

function InventoryUI:_createSparseSlot(index)
	local slot = create("Frame", self.CardPool, {
		Name = "SparseSlot_Pooled",
		Active = false,
		BackgroundColor3 = PALETTE.Card,
		BackgroundTransparency = 0.42,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 146,
	})
	slot:SetAttribute("InventoryPlaceholder", true)
	slot:SetAttribute("InventoryOwnsItem", false)
	slot:SetAttribute("InventoryInteractive", false)
	addCorner(slot, 3)
	local stroke = addStroke(slot, PALETTE.Steel, 1, 0.58)
	addGradient(slot, ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(10, 25, 35)),
		ColorSequenceKeypoint.new(0.48, Color3.fromRGB(4, 15, 23)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(2, 8, 13)),
	}), 90)
	local topRail = create("Frame", slot, {
		Name = "PlaceholderTopRail",
		BackgroundColor3 = PALETTE.SteelLight,
		BackgroundTransparency = 0.62,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(5, 5),
		Size = UDim2.new(1, -10, 0, 3),
		ZIndex = 147,
	})
	local label = create("TextLabel", slot, {
		Name = "PlaceholderState",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBlack,
		Position = UDim2.fromOffset(7, 12),
		Size = UDim2.new(1, -14, 1, -20),
		Text = "EMPTY",
		TextColor3 = PALETTE.Muted,
		TextSize = 8,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.35,
		TextWrapped = true,
		ZIndex = 148,
	})
	local ref = {
		slot = slot,
		stroke = stroke,
		topRail = topRail,
		label = label,
		index = index,
	}
	self._sparseSlotPool[index] = ref
	self._sparseSlotCreateCount = self._sparseSlotCreateCount + 1
	self.Root:SetAttribute("InventorySparseSlotCreateCount", self._sparseSlotCreateCount)
	return ref
end

function InventoryUI:_renderSparseSlots()
	for _, ref in ipairs(self._sparseSlotPool) do
		ref.slot.Visible = false
		ref.slot.Parent = self.CardPool
	end
	self._activeSparseSlotCount = 0

	local columns = math.clamp(math.floor(tonumber(self._layout.columns) or 1), 1, 5)
	local targetSlots = math.min(
		MAX_SPARSE_SLOT_PLACEHOLDERS,
		columns * SPARSE_SLOT_ROWS
	)
	local filterActive = self._category ~= "All"
		or normalize(self._search) ~= ""
		or self._rarity ~= "All"
	local placeholderCount = self._activeCardCount > 0 and not filterActive
			and math.clamp(
				targetSlots - self._activeCardCount,
				0,
				MAX_SPARSE_SLOT_PLACEHOLDERS
			)
			or 0
	for index = 1, placeholderCount do
		local ref = self._sparseSlotPool[index] or self:_createSparseSlot(index)
		local displaySlot = self._activeCardCount + index
		local locked = not filterActive and displaySlot % 5 == 0
		local state = locked and "Locked" or "Empty"
		ref.slot.Name = "InventoryPlaceholderSlot_" .. displaySlot
		ref.slot.LayoutOrder = displaySlot
		ref.slot.Parent = self.Grid
		ref.slot.Visible = true
		ref.slot:SetAttribute("InventoryPlaceholderState", state)
		ref.slot:SetAttribute("InventoryDisplaySlot", displaySlot)
		ref.stroke.Color = locked and PALETTE.GoldDark or PALETTE.Steel
		ref.topRail.BackgroundColor3 = locked and PALETTE.Gold or PALETTE.CyanSoft
		ref.label.Text = locked and "LOCKED" or "EMPTY"
		ref.label.TextColor3 = locked and PALETTE.Gold
			or PALETTE.Muted
		self._activeSparseSlotCount = self._activeSparseSlotCount + 1
	end
	self.Root:SetAttribute("InventoryActiveSparseSlotCount", self._activeSparseSlotCount)
	self.Root:SetAttribute(
		"InventoryDisplayedSlotCount",
		self._activeCardCount + self._activeSparseSlotCount
	)
	self.Root:SetAttribute("InventorySparseSlotListenerCount", 0)
	self.Root:SetAttribute("InventorySparseSlotMode", filterActive and "FilteredHidden" or "InventoryQuiet")
	self.Root:SetAttribute("InventoryFilteredPlaceholderCount", filterActive and self._activeSparseSlotCount or 0)
	self.Root:SetAttribute(
		"InventorySparseSlotsBounded",
		self._activeSparseSlotCount <= MAX_SPARSE_SLOT_PLACEHOLDERS
	)
end

function InventoryUI:_renderGrid()
	self._gridRebuildCount = self._gridRebuildCount + 1
	self:_clearCards()
	local isEmpty = #self._visibleItems == 0
	local inventoryHasItems = #(self._snapshot and self._snapshot.items or {}) > 0
	self.EmptyState.Visible = isEmpty
	if isEmpty and inventoryHasItems then
		self.Empty.Text = "NO ITEMS MATCH THIS FILTER\nCHANGE RARITY OR CLEAR SEARCH"
		self.EmptySlotLabels[1].Text = "NO\nMATCH"
		self.EmptySlotLabels[2].Text = "CHANGE\nFILTER"
		self.EmptySlotLabels[3].Text = "CLEAR\nSEARCH"
		self.Root:SetAttribute("InventoryEmptyTreatment", "FilterEmpty")
	elseif isEmpty then
		self.Empty.Text = "YOUR INVENTORY IS EMPTY\nEARN OR BUY ITEMS TO FILL THESE SLOTS"
		self.EmptySlotLabels[1].Text = "LOCKED\nSLOT"
		self.EmptySlotLabels[2].Text = "EMPTY\nSLOT"
		self.EmptySlotLabels[3].Text = "EARN\nITEMS"
		self.Root:SetAttribute("InventoryEmptyTreatment", "InventoryEmpty")
	else
		self.Root:SetAttribute("InventoryEmptyTreatment", "Hidden")
	end
	for index, item in ipairs(self._visibleItems) do
		local key = tostring(item.key or ("item:" .. index))
		local accent = itemAccent(item)
		local selected = key == self._selectedKey
		local cardRef = self._cardPool[index]
		if not cardRef then
			local card = create("TextButton", self.CardPool, {
				Name = "ItemCard_Pooled",
				AutoButtonColor = false,
				BackgroundColor3 = PALETTE.Card,
				BorderSizePixel = 0,
				ClipsDescendants = true,
				Text = "",
				Visible = false,
				ZIndex = 146,
			})
			addCorner(card, 3)
			local cardStroke = addStroke(card, PALETTE.SteelLight, 1)
			local cardGradient = addGradient(card, ColorSequence.new(Color3.new(1, 1, 1)), 90)
			local depthInset = create("Frame", card, {
				Name = "CardDepthInset",
				Visible = false,
				BackgroundColor3 = Color3.fromRGB(0, 4, 8),
				BackgroundTransparency = 0.18,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(5, 7),
				Size = UDim2.new(1, -10, 1, -13),
				ZIndex = 146,
			})
			addCorner(depthInset, 2)
			addStroke(depthInset, PALETTE.Steel, 1, 0.52)

			local innerFrame = create("Frame", card, {
				Name = "CardInnerFrame",
				Visible = false,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(4, 4),
				Size = UDim2.new(1, -8, 1, -8),
				ZIndex = 147,
			})
			addCorner(innerFrame, 2)
			local innerStroke = addStroke(innerFrame, accent, 1, 0.62)

			local accentBar = create("Frame", card, {
				Name = "RarityAccent",
				Visible = false,
				BackgroundColor3 = accent,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.new(1, 0, 0, 4),
				ZIndex = 147,
			})
			local accentGradient = addGradient(accentBar, ColorSequence.new({
				ColorSequenceKeypoint.new(0, accent:Lerp(Color3.new(1, 1, 1), 0.15)),
				ColorSequenceKeypoint.new(0.5, accent),
				ColorSequenceKeypoint.new(1, accent:Lerp(Color3.new(0, 0, 0), 0.28)),
			}), 0)

			local artFrame = create("Frame", card, {
				Name = "ItemArtFrame",
				BackgroundColor3 = PALETTE.Panel,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(6, 8),
				Size = UDim2.new(1, -12, 1, -45),
				ZIndex = 147,
			})
			addCorner(artFrame, 2)
			local artFrameStroke = addStroke(artFrame, PALETTE.Steel, 1, 0.18)
			local artFrameGradient = addGradient(artFrame, ColorSequence.new({
				ColorSequenceKeypoint.new(0, accent:Lerp(Color3.fromRGB(5, 14, 21), 0.88)),
				ColorSequenceKeypoint.new(0.55, Color3.fromRGB(3, 12, 19)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(1, 7, 11)),
			}), 90)
			local artBloom = create("Frame", artFrame, {
				Name = "ItemArtBloom",
				Visible = false,
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = accent,
				BackgroundTransparency = 0.9,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.5, 0.52),
				Rotation = 45,
				Size = UDim2.fromScale(0.54, 0.54),
				ZIndex = 147,
			})
			addCorner(artBloom, 5)
			local art = create("ImageLabel", artFrame, {
				Name = "ItemArt",
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(3, 3),
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.new(1, -6, 1, -6),
				ZIndex = 148,
			})
			local petPreview = createPetViewport(artFrame, "ItemPetPreview", 149)
			local lockedVeil = create("Frame", artFrame, {
				Name = "LockedArtVeil",
				BackgroundColor3 = Color3.fromRGB(1, 5, 9),
				BackgroundTransparency = 0.24,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(2, 2),
				Size = UDim2.new(1, -4, 1, -4),
				Visible = false,
				ZIndex = 149,
			})
			addCorner(lockedVeil, 2)
			local lockedMessage = create("TextLabel", lockedVeil, {
				Name = "LockedArtMessage",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = PALETTE.RedDark,
				BackgroundTransparency = 0.04,
				BorderSizePixel = 0,
				Font = Enum.Font.GothamBlack,
				Position = UDim2.fromScale(0.5, 0.56),
				Size = UDim2.new(1, -14, 0, 28),
				Text = "[ LOCKED ]",
				TextColor3 = PALETTE.Text,
				TextSize = 9,
				TextWrapped = true,
				ZIndex = 150,
			})
			addCorner(lockedMessage, 2)
			addStroke(lockedMessage, Color3.fromRGB(255, 94, 75), 1, 0.12)

			local rarity = create("TextLabel", card, {
				Name = "ItemRarity",
				BackgroundColor3 = accent,
				BackgroundTransparency = 0.02,
				BorderSizePixel = 0,
				Font = Enum.Font.GothamBlack,
				Position = UDim2.fromOffset(7, 10),
				Size = UDim2.new(0.62, -7, 0, 18),
				Text = "",
				TextSize = 9,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 149,
			})
			addCorner(rarity, 2)
			create("UIPadding", rarity, {
				PaddingLeft = UDim.new(0, 6),
				PaddingRight = UDim.new(0, 4),
			})

			local name = create("TextLabel", card, {
				Name = "ItemName",
				BackgroundColor3 = Color3.fromRGB(2, 9, 14),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Font = Enum.Font.GothamBold,
				Position = UDim2.new(0, 6, 1, -36),
				Size = UDim2.new(1, -12, 0, 30),
				Text = "",
				TextColor3 = PALETTE.Text,
				TextScaled = true,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextWrapped = true,
				ZIndex = 149,
			})
			local nameTextLimit = addTextLimit(name, 8, 12)
			local footerRail = create("Frame", card, {
				Name = "CardFooterRail",
				AnchorPoint = Vector2.new(0, 1),
				BackgroundColor3 = accent,
				BackgroundTransparency = 0.18,
				BorderSizePixel = 0,
				Position = UDim2.new(0, 6, 1, -5),
				Size = UDim2.new(1, -12, 0, 2),
				ZIndex = 150,
			})

			local quantity = create("TextLabel", card, {
				Name = "ItemQuantity",
				AnchorPoint = Vector2.new(1, 0),
				BackgroundColor3 = Color3.fromRGB(2, 8, 13),
				BackgroundTransparency = 0.02,
				BorderSizePixel = 0,
				Font = Enum.Font.GothamBlack,
				Position = UDim2.new(1, -7, 0, 9),
				Size = UDim2.fromOffset(38, 22),
				Text = "",
				TextColor3 = PALETTE.Text,
				TextSize = 11,
				Visible = false,
				ZIndex = 151,
			})
			addCorner(quantity, 2)
			local quantityStroke = addStroke(quantity, accent, 1, 0.25)

			local equipped = create("TextLabel", card, {
				Name = "EquippedBadge",
				BackgroundColor3 = Color3.fromRGB(25, 47, 38),
				BorderSizePixel = 0,
				Font = Enum.Font.GothamBlack,
				Position = UDim2.fromOffset(8, 34),
				Size = UDim2.fromOffset(62, 20),
				Text = "EQUIPPED",
				TextColor3 = PALETTE.Text,
				TextSize = 8,
				Visible = false,
				ZIndex = 151,
			})
			addCorner(equipped, 2)
			addStroke(equipped, PALETTE.SteelLight, 1, 0.6)

			local locked = create("TextLabel", card, {
				Name = "LockedBadge",
				AnchorPoint = Vector2.new(1, 0),
				BackgroundColor3 = PALETTE.RedDark,
				BorderSizePixel = 0,
				Font = Enum.Font.GothamBlack,
				Position = UDim2.new(1, -8, 0, 34),
				Size = UDim2.fromOffset(72, 20),
				Text = "LOCKED",
				TextColor3 = PALETTE.Text,
				TextSize = 8,
				Visible = false,
				ZIndex = 151,
			})
			addCorner(locked, 2)
			addStroke(locked, Color3.fromRGB(255, 105, 83), 1, 0.18)

			cardRef = {
				card = card,
				stroke = cardStroke,
				gradient = cardGradient,
				innerStroke = innerStroke,
				accentBar = accentBar,
				accentGradient = accentGradient,
				artFrame = artFrame,
				artFrameStroke = artFrameStroke,
				artFrameGradient = artFrameGradient,
				artBloom = artBloom,
				art = art,
				petPreview = petPreview,
				lockedVeil = lockedVeil,
				lockedMessage = lockedMessage,
				footerRail = footerRail,
				rarity = rarity,
				name = name,
				nameTextLimit = nameTextLimit,
				quantity = quantity,
				quantityStroke = quantityStroke,
				equipped = equipped,
				locked = locked,
				accent = accent,
				hovered = false,
			}
			self._cardPool[index] = cardRef
			table.insert(self._cards, card)
			self._cardCreateCount = self._cardCreateCount + 1

			self:_connectScoped(self._cardConnections, card.MouseEnter, function()
				local boundKey = cardRef.key
				if not boundKey or not card.Visible then
					return
				end
				cardRef.hovered = true
				self:_applyCardSelectionVisual(boundKey, boundKey == self._selectedKey)
			end)
			self:_connectScoped(self._cardConnections, card.MouseLeave, function()
				local boundKey = cardRef.key
				if not boundKey or not card.Visible then
					return
				end
				cardRef.hovered = false
				self:_applyCardSelectionVisual(boundKey, boundKey == self._selectedKey)
			end)
			self:_connectScoped(self._cardConnections, card.Activated, function()
				local key = cardRef.key
				if key and card.Visible and card.Active then
					self:SelectItem(key, false)
				end
			end)
		else
			self._cardReuseCount = self._cardReuseCount + 1
		end

		local card = cardRef.card
		local accentChanged = cardRef.accent ~= accent
		cardRef.key = key
		cardRef.item = item
		cardRef.accent = accent
		cardRef.hovered = false
		card.Name = "ItemCard_" .. safeName(key)
		card.Active = true
		card.BackgroundColor3 = selected and PALETTE.CardHover or PALETTE.Card
		card.LayoutOrder = index
		card.Parent = self.Grid
		card.Selectable = true
		card.Visible = true
		card:SetAttribute("InventoryKey", key)
		card:SetAttribute("InventoryCategory", tostring(item.category or ""))
		card:SetAttribute("InventoryRarity", tostring(item.rarity or "Common"))
		card:SetAttribute("InventoryEquipped", item.equipped == true)
		card:SetAttribute("InventoryLocked", item.locked == true)
		local honorItem = tostring(item.kind or "") == "Honor"
		local honorState = honorItem and tostring(item.state or "Locked") or ""
		local honorId = honorItem and string.match(key, "^honor:(.+)$") or nil
		card:SetAttribute("HonorItemId", honorId or "")
		card:SetAttribute("HonorState", honorState)
		card:SetAttribute("HonorOwned", honorItem and item.owned == true or false)
		card:SetAttribute("HonorUnlocked", honorItem and item.unlocked == true or false)
		card:SetAttribute("HonorAffordable", honorItem and item.affordable == true or false)
		card:SetAttribute("HonorEquipped", honorItem and item.equipped == true or false)
		card:SetAttribute("HonorCost", honorItem and (tonumber(item.cost) or 0) or 0)
		card:SetAttribute("HonorMissing", honorItem and (tonumber(item.missingHonor) or 0) or 0)
		card:SetAttribute("InventoryWorldSelection", selected and honorId or "")
		card:SetAttribute(
			"InventoryLockedTreatment",
			item.locked == true and (honorItem and "HonorStateBadgeOnly" or "ArtVeilOnly") or "Unlocked"
		)
		cardRef.stroke.Color = selected and PALETTE.Cyan or PALETTE.SteelLight
		cardRef.stroke.Thickness = selected and 2 or 1
		if accentChanged then
			cardRef.gradient.Color = ColorSequence.new(Color3.new(1, 1, 1))
			cardRef.innerStroke.Color = accent
			cardRef.accentBar.BackgroundColor3 = accent
			cardRef.accentGradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, accent:Lerp(Color3.new(1, 1, 1), 0.15)),
				ColorSequenceKeypoint.new(0.5, accent),
				ColorSequenceKeypoint.new(1, accent:Lerp(Color3.new(0, 0, 0), 0.28)),
			})
			cardRef.artFrameStroke.Color = PALETTE.SteelLight
			cardRef.artFrameGradient.Color = ColorSequence.new(Color3.new(1, 1, 1))
			cardRef.artBloom.BackgroundColor3 = accent
			cardRef.footerRail.BackgroundColor3 = accent
		end
		local art = cardRef.art
		local usesModelPreview, previewMode = self:_applyModelPreview(cardRef.petPreview, item)
		local artMode = usesModelPreview and previewMode or self:_applyItemArt(art, item)
		card:SetAttribute("ArtMode", artMode)
		card:SetAttribute("PreviewPetName", usesModelPreview and tostring(item.previewPet or "") or "")
		card:SetAttribute("PreviewFistName", usesModelPreview and item.category == "Fists" and tostring(item.name) or "")
		art.Visible = not usesModelPreview
		art.ImageTransparency = item.locked == true and 0.34
			or honorState == "Insufficient" and 0.12
			or 0
		local rarityColor = itemRarityColor(item)
		cardRef.rarity.BackgroundColor3 = rarityColor
		cardRef.rarity.Text = string.upper(tostring(item.rarity or "Common"))
		cardRef.rarity.TextColor3 = contrastText(rarityColor)
		cardRef.name.Text = tostring(item.displayName or item.name or "Unknown Item")
		local quantityValue = tonumber(item.quantity) or 1
		cardRef.quantity.Visible = quantityValue > 1
		cardRef.quantity.Text = "x" .. formatNumber(quantityValue)
		cardRef.quantityStroke.Color = accent
		cardRef.equipped.Visible = item.equipped == true
		local showHonorState = honorState == "Locked"
			or honorState == "Insufficient"
			or honorState == "Affordable"
		-- One state label per card. Standard locked items use the centered art
		-- veil; Honor relics use their actionable LOCKED/NEED/READY badge.
		cardRef.locked.Visible = honorItem and showHonorState
		cardRef.locked.Text = honorState == "Insufficient" and ("NEED " .. formatNumber(item.missingHonor or 0))
			or honorState == "Affordable" and "READY"
			or "LOCKED"
		cardRef.locked.BackgroundColor3 = honorState == "Affordable" and PALETTE.Green
			or honorState == "Insufficient" and PALETTE.GoldDark
			or PALETTE.RedDark
		cardRef.locked.TextColor3 = honorState == "Affordable" and PALETTE.Ink or PALETTE.Text
		cardRef.lockedVeil.Visible = item.locked == true and not honorItem
		card:SetAttribute(
			"InventoryLockedLabelCount",
			(cardRef.locked.Visible and 1 or 0) + (cardRef.lockedVeil.Visible and 1 or 0)
		)

		local keyedRefs = self._cardRefsByKey[key]
		if not keyedRefs then
			keyedRefs = {}
			self._cardRefsByKey[key] = keyedRefs
		end
		table.insert(keyedRefs, cardRef)
		self._activeCardCount = self._activeCardCount + 1
	end
	self:_renderSparseSlots()
	self.Root:SetAttribute("InventoryGridRebuildCount", self._gridRebuildCount)
	self.Root:SetAttribute("InventoryLiveCardCount", self._activeCardCount)
	self.Root:SetAttribute("InventoryCardConnectionCount", #self._cardConnections)
	self.Root:SetAttribute("InventoryCardCreateCount", self._cardCreateCount)
	self.Root:SetAttribute("InventoryCardReuseCount", self._cardReuseCount)
	self.Root:SetAttribute(
		"InventoryCardConnectionsStable",
		#self._cardConnections == (#self._cards * 3)
	)
end

function InventoryUI:_clearActionButtons()
	table.clear(self._activeActionButtons)
	table.clear(self._actionModelsByKey)
	for _, button in ipairs(self._actionButtons) do
		button.Visible = false
		button.Parent = self.ActionPool
		if button:IsA("TextButton") then
			button.Active = false
			button.Selectable = false
			button:SetAttribute("BoundInventoryKey", "")
		end
	end
	self.Root:SetAttribute("InventoryActiveActionCount", 0)
	self.Root:SetAttribute("InventoryEnabledActionCount", 0)
	self.Root:SetAttribute("InventoryMinimumEnabledActionContrast", 0)
	self.Root:SetAttribute("InventoryEnabledActionContrastPass", true)
end

function InventoryUI:_createActionButton(controlKey)
	local initialStyle = ACTION_STYLES.Disabled
	local button = create("TextButton", self.ActionPool, {
		Name = "Action" .. safeName(controlKey),
		AutoButtonColor = false,
		BackgroundColor3 = initialStyle.base,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBlack,
		Size = UDim2.new(1, 0, 0, 44),
		Text = "",
		TextColor3 = initialStyle.text,
		TextSize = 12,
		Visible = false,
		ZIndex = 153,
	})
	button:SetAttribute("InventoryActionControlKey", controlKey)
	button:SetAttribute("InventoryActionVisualState", "Disabled")
	button:SetAttribute("InventoryTextGradientMode", "NeutralMultiplier")
	addCorner(button, 3)
	local stroke = addStroke(button, initialStyle.stroke, 1.5, 0.15)
	local gradient = addGradient(button, TEXT_SAFE_GRADIENT, 90)

	local buttonRef = {
		button = button,
		stroke = stroke,
		gradient = gradient,
		controlKey = controlKey,
	}
	self._actionButtonRefsByKey[controlKey] = buttonRef
	table.insert(self._actionButtons, button)
	self:_connectScoped(self._actionConnections, button.Activated, function()
		local boundModel = self._actionModelsByKey[controlKey]
		if self._destroyed
			or not button.Visible
			or not button.Active
			or type(boundModel) ~= "table"
		then
			return
		end
		self._actionCallbackCount = self._actionCallbackCount + 1
		self.Root:SetAttribute("InventoryActionCallbackCount", self._actionCallbackCount)
		self:InvokeAction({
			key = boundModel.itemKey,
			action = boundModel.semanticName,
		})
	end)
	self._actionCreateCount = self._actionCreateCount + 1
	self.Root:SetAttribute("InventoryActionCreateCount", self._actionCreateCount)
	self.Root:SetAttribute(
		"InventoryAuditedTextGradientControlCount",
		#CATEGORIES + 3 + self._actionCreateCount + (self._viewOnlyAction and 1 or 0)
	)
	self.Root:SetAttribute("InventoryActionConnectionCount", #self._actionConnections)
	self.Root:SetAttribute(
		"InventoryActionConnectionsStable",
		#self._actionConnections == self._actionCreateCount
	)
	return buttonRef
end

function InventoryUI:_ensureViewOnlyAction()
	if self._viewOnlyAction and self._viewOnlyAction.Parent then
		return self._viewOnlyAction
	end
	local label = create("TextLabel", self.ActionPool, {
		Name = "ActionViewOnly",
		BackgroundColor3 = ACTION_STYLES.Disabled.base,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBlack,
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 44),
		Text = "VIEW ONLY",
		TextColor3 = PALETTE.Muted,
		TextSize = 11,
		Visible = false,
		ZIndex = 153,
	})
	label:SetAttribute("InventoryActionVisualState", "Disabled")
	label:SetAttribute("InventoryActionStyle", "Disabled")
	label:SetAttribute("InventoryActionContrastRatio", minimumStyleContrast(ACTION_STYLES.Disabled))
	label:SetAttribute("InventoryTextGradientMode", "NeutralMultiplier")
	addCorner(label, 3)
	addStroke(label, PALETTE.SteelLight, 1.5, 0.25)
	addGradient(label, TEXT_SAFE_GRADIENT, 90)
	self._viewOnlyAction = label
	table.insert(self._actionButtons, label)
	self.Root:SetAttribute(
		"InventoryAuditedTextGradientControlCount",
		#CATEGORIES + 4 + self._actionCreateCount
	)
	return label
end

function InventoryUI:_renderDetail()
	self:_clearActionButtons()
	local item = self._selectedItem
	if not item then
		self.DetailName.Text = "SELECT AN ITEM"
		self.DetailInternalName.Text = "SERVER-BACKED INVENTORY"
		self.DetailRarity.Text = "INVENTORY"
		self.DetailRarity.BackgroundColor3 = PALETTE.CyanSoft
		self.DetailRarity.TextColor3 = PALETTE.Text
		self.DetailCategoryTag.Text = "LIVE ITEMS"
		self.DetailCategoryTag.TextColor3 = PALETTE.Cyan
		self.DetailCategoryTag.BackgroundColor3 = Color3.fromRGB(5, 26, 36)
		self.DetailDescription.Text = "Choose an item to inspect its live server-backed state."
		self.DetailStatus.Text = "NO ITEM SELECTED"
		self.DetailStatus.Visible = true
		self.Root:SetAttribute("InventoryDetailStatusTreatment", "EmptyPrompt")
		self.DetailArt.Image = ""
		self.DetailArt.Visible = true
		self:_clearPetPreview(self.DetailPetPreview)
		self.DetailArtFrame:SetAttribute("ArtMode", "NativeFallback")
		self.DetailArtGlow.BackgroundColor3 = PALETTE.Cyan
		self.DetailStroke.Color = PALETTE.CyanSoft
		self.DetailArtStroke.Color = PALETTE.CyanSoft
		self.DetailArtCoreStroke.Color = PALETTE.CyanSoft
		self.DetailDescriptionStroke.Color = PALETTE.Steel
		self.DetailStatus.StatusSignal.BackgroundColor3 = PALETTE.Cyan
		for _, widgets in ipairs(self.DetailStatRows) do
			widgets.value.Text = "--"
			widgets.value.TextColor3 = PALETTE.Muted
			widgets.marker.BackgroundColor3 = PALETTE.SteelLight
		end
		self:_syncDetailVisibility()
		return
	end
	self:_updateTimedItemDetail(item, workspace:GetServerTimeNow())

	local accent = itemAccent(item)
	local displayName = tostring(item.displayName or item.name or "Unknown Item")
	local rarityName = tostring(item.rarity or "Common")
	local categoryName = tostring(item.category or item.kind or "Item")
	self.DetailRarity.Text = string.upper(rarityName)
	local rarityColor = itemRarityColor(item)
	self.DetailRarity.BackgroundColor3 = rarityColor
	self.DetailRarity.TextColor3 = contrastText(rarityColor)
	self.DetailCategoryTag.Text = string.upper(categoryName)
	self.DetailCategoryTag.TextColor3 = PALETTE.Text
	self.DetailCategoryTag.BackgroundColor3 = PALETTE.PanelRaised
	self.DetailName.Text = string.upper(displayName)
	self.DetailInternalName.Text = item.slot
		and ("OWNED ITEM  //  SLOT " .. tostring(item.slot))
		or tostring(item.kind or "") == "Honor" and (
			item.owned == true and "YOUR RELIC"
			or "EARN HONOR TO UNLOCK"
		)
		or "YOUR EQUIPMENT"
	self.DetailDescription.Text = tostring(item.description or item.detail or "No additional item details.")
	self.DetailStatus.Visible = false
	self.Root:SetAttribute("InventoryDetailStatusTreatment", "StateRowAndAction")
	self.DetailStroke.Color = PALETTE.SteelLight
	self.DetailArtStroke.Color = PALETTE.SteelLight
	self.DetailArtCoreStroke.Color = accent
	self.DetailDescriptionStroke.Color = PALETTE.SteelLight
	self.DetailArtGlow.BackgroundColor3 = accent
	local usesModelPreview, previewMode = self:_applyModelPreview(self.DetailPetPreview, item)
	local detailArtMode = usesModelPreview and previewMode or self:_applyItemArt(self.DetailArt, item)
	self.DetailArt.Visible = not usesModelPreview
	self.DetailArtFrame:SetAttribute("ArtMode", detailArtMode)
	self.DetailArtFrame:SetAttribute("PreviewPetName", usesModelPreview and tostring(item.previewPet or "") or "")
	self.DetailArtFrame:SetAttribute("PreviewFistName", usesModelPreview and item.category == "Fists" and tostring(item.name) or "")

	local statusParts = {}
	if item.equipped == true then
		table.insert(statusParts, "EQUIPPED")
	end
	if item.locked == true then
		table.insert(statusParts, "LOCKED")
	end
	if (tonumber(item.quantity) or 1) > 1 then
		table.insert(statusParts, "QUANTITY " .. formatNumber(item.quantity))
	end
	if item.slot then
		table.insert(statusParts, "SLOT " .. tostring(item.slot))
	end
	if tostring(item.kind or "") == "Honor" and item.equipped ~= true then
		table.insert(statusParts, string.upper(tostring(item.state or "Locked")))
	end
	if #statusParts == 0 then
		table.insert(statusParts, item.viewOnly == true and "VIEW ONLY" or "AVAILABLE")
	end
	self.DetailStatus.Text = table.concat(statusParts, "  |  ")
	self.DetailStatus.TextColor3 = item.locked == true and PALETTE.Gold or item.equipped == true and PALETTE.Green or PALETTE.Cyan
	self.DetailStatus.StatusSignal.BackgroundColor3 = self.DetailStatus.TextColor3
	local stateName = tostring(item.kind or "") == "Honor" and string.upper(tostring(item.state or "Locked"))
		or item.locked == true and "LOCKED"
		or item.equipped == true and "EQUIPPED"
		or item.viewOnly == true and "VIEW ONLY"
		or "AVAILABLE"
	local statValues = { string.upper(rarityName), string.upper(categoryName), stateName }
	local statColors = { rarityColor, PALETTE.Text, PALETTE.Text }
	for index, widgets in ipairs(self.DetailStatRows) do
		widgets.value.Text = statValues[index]
		widgets.value.TextColor3 = statColors[index]
		widgets.marker.BackgroundColor3 = statColors[index]
	end

	local renderedCount = 0
	local enabledCount = 0
	local minimumEnabledContrast = math.huge
	local actionKeyOccurrences = {}
	for order, action in ipairs(itemActions(item)) do
		local actionModel = type(action) == "table" and action or {
			name = tostring(action or "Action"),
			enabled = false,
		}
		local enabled = actionEnabled(actionModel)
		renderedCount = renderedCount + 1
		if enabled then
			enabledCount = enabledCount + 1
		end
		local semanticName = actionName(actionModel)
		local semanticKey = normalize(semanticName)
		if semanticKey == "" then
			semanticKey = "action"
		end
		actionKeyOccurrences[semanticKey] = (actionKeyOccurrences[semanticKey] or 0) + 1
		local controlKey = actionKeyOccurrences[semanticKey] == 1
			and semanticKey
			or string.format("%s:%d", semanticKey, actionKeyOccurrences[semanticKey])
		local destructive = actionModel.destructive == true
			or actionModel.confirm == true
			or normalize(semanticName) == "delete"
		local awaitingConfirmation = enabled
			and destructive
			and self._deleteConfirmKey == tostring(item.key)
			and os.clock() <= self._deleteConfirmUntil
		local label = awaitingConfirmation
			and "CONFIRM DELETE"
			or tostring(actionModel.label or semanticName)
		local style, styleName = actionVisualStyle(
			semanticName,
			destructive,
			actionModel.primary == true,
			enabled
		)
		local styleContrast = minimumStyleContrast(style)
		local buttonRef = self._actionButtonRefsByKey[controlKey]
			or self:_createActionButton(controlKey)
		local button = buttonRef.button
		button.Name = "Action" .. safeName(controlKey)
		button.Active = enabled
		button.BackgroundColor3 = style.base
		button.BackgroundTransparency = enabled and 0 or 0.08
		button.LayoutOrder = actionModel.primary == true and 0 or order
		button.Parent = self.DetailActions
		button.Selectable = enabled
		button.Text = string.upper(label)
		button.TextColor3 = style.text
		button.TextStrokeColor3 = style.text == PALETTE.Ink and Color3.fromRGB(255, 255, 255)
			or Color3.fromRGB(0, 0, 0)
		button.TextStrokeTransparency = enabled and 0.82 or 1
		button.Visible = true
		button:SetAttribute("InventoryAction", semanticName)
		button:SetAttribute("InventoryActionEnabled", enabled)
		button:SetAttribute("InventoryActionVisualState", enabled and "Enabled" or "Disabled")
		button:SetAttribute("InventoryActionStyle", styleName)
		button:SetAttribute("InventoryActionBaseColor", style.base)
		button:SetAttribute("InventoryActionContrastRatio", styleContrast)
		button:SetAttribute("Destructive", destructive)
		button:SetAttribute("BoundInventoryKey", tostring(item.key))
		buttonRef.stroke.Color = style.stroke
		buttonRef.stroke.Transparency = enabled and 0.05 or 0.38
		buttonRef.stroke.Thickness = enabled and 2 or 1.25
		buttonRef.gradient.Color = TEXT_SAFE_GRADIENT
		if enabled then
			minimumEnabledContrast = math.min(minimumEnabledContrast, styleContrast)
			self._actionModelsByKey[controlKey] = {
				itemKey = tostring(item.key),
				semanticName = semanticName,
			}
		end
		table.insert(self._activeActionButtons, button)
	end

	if renderedCount == 0 then
		local label = self:_ensureViewOnlyAction()
		label.Parent = self.DetailActions
		label.Visible = true
		table.insert(self._activeActionButtons, label)
	end
	self.Root:SetAttribute("InventoryEnabledActionCount", enabledCount)
	self.Root:SetAttribute(
		"InventoryMinimumEnabledActionContrast",
		minimumEnabledContrast < math.huge and minimumEnabledContrast or 0
	)
	self.Root:SetAttribute(
		"InventoryEnabledActionContrastPass",
		enabledCount == 0 or minimumEnabledContrast >= 4.5
	)
	self.Root:SetAttribute("InventoryActiveActionCount", #self._activeActionButtons)
	self.Root:SetAttribute("InventoryActionConnectionCount", #self._actionConnections)
	self.Root:SetAttribute(
		"InventoryActionConnectionsStable",
		#self._actionConnections == self._actionCreateCount
	)
	self:_syncDetailVisibility()
end

function InventoryUI:_syncDetailVisibility()
	local hasItem = self._selectedItem ~= nil
	if self._layout.compact then
		self.Detail.Visible = hasItem and self._detailExpanded
		self.CompactDetailDrawer.Visible = self.Detail.Visible
	else
		self.Detail.Visible = true
		self.CompactDetailDrawer.Visible = false
	end
end

function InventoryUI:_updateHonorDiagnostics()
	local catalogCount = 0
	for _, item in ipairs(self._snapshot and self._snapshot.items or {}) do
		if tostring(item.kind or "") == "Honor" then
			catalogCount += 1
		end
	end
	local visibleCount = 0
	for _, item in ipairs(self._visibleItems) do
		if tostring(item.kind or "") == "Honor" then
			visibleCount += 1
		end
	end
	local selectedId = string.match(tostring(self._selectedKey or ""), "^honor:(.+)$") or ""
	self.Root:SetAttribute("InventoryHonorCatalogCount", catalogCount)
	self.Root:SetAttribute("InventoryHonorVisibleCount", visibleCount)
	self.Root:SetAttribute("InventoryHonorSelectedId", selectedId)
	if selectedId == "" then
		self.Root:SetAttribute("InventoryHonorCanvasY", 0)
		self.Root:SetAttribute("InventoryHonorSelectionInView", false)
		self.Root:SetAttribute("InventoryHonorSelectionFocused", false)
	end
end

function InventoryUI:_focusSelectedHonorCard()
	self._selectionFocusGeneration += 1
	local generation = self._selectionFocusGeneration
	local selectedKey = tostring(self._selectedKey or "")
	local selectedId = string.match(selectedKey, "^honor:(.+)$")
	self.Root:SetAttribute("InventoryHonorSelectionInView", false)
	self.Root:SetAttribute("InventoryHonorSelectionFocused", false)
	if not selectedId then
		return
	end

	task.defer(function()
		local cardRef
		for _ = 1, 4 do
			if generation ~= self._selectionFocusGeneration
				or self._destroyed
				or not self.Root.Visible
				or tostring(self._selectedKey or "") ~= selectedKey
			then
				return
			end
			local refs = self._cardRefsByKey[selectedKey]
			cardRef = refs and refs[1] or nil
			if cardRef and cardRef.card.Visible and self.Grid.Visible and self.Grid.AbsoluteSize.Y > 0 then
				break
			end
			RunService.Heartbeat:Wait()
		end
		local card = cardRef and cardRef.card
		if not card or not card.Visible or not self.Grid.Visible or self.Grid.AbsoluteSize.Y <= 0 then
			return
		end

		local cardCenter = card.AbsolutePosition.Y + card.AbsoluteSize.Y * 0.5
		local viewCenter = self.Grid.AbsolutePosition.Y + self.Grid.AbsoluteSize.Y * 0.5
		local maxY = math.max(0, self.Grid.AbsoluteCanvasSize.Y - self.Grid.AbsoluteSize.Y)
		self.Grid.CanvasPosition = Vector2.new(
			self.Grid.CanvasPosition.X,
			math.clamp(self.Grid.CanvasPosition.Y + cardCenter - viewCenter, 0, maxY)
		)
		RunService.Heartbeat:Wait()
		if generation ~= self._selectionFocusGeneration
			or not card.Parent
			or tostring(self._selectedKey or "") ~= selectedKey
		then
			return
		end
		local cardTop = card.AbsolutePosition.Y
		local cardBottom = cardTop + card.AbsoluteSize.Y
		local viewTop = self.Grid.AbsolutePosition.Y
		local viewBottom = viewTop + self.Grid.AbsoluteSize.Y
		local inView = cardTop >= viewTop - 2 and cardBottom <= viewBottom + 2
		local lastInput = UserInputService:GetLastInputType()
		local selectionInput = lastInput == Enum.UserInputType.Keyboard
			or string.find(lastInput.Name, "Gamepad", 1, true) == 1
		if selectionInput and inView and card.Selectable then
			GuiService.SelectedObject = card
		end
		self.Root:SetAttribute("InventoryHonorSelectedId", selectedId)
		self.Root:SetAttribute("InventoryHonorCanvasY", self.Grid.CanvasPosition.Y)
		self.Root:SetAttribute("InventoryHonorSelectionInView", inView)
		self.Root:SetAttribute("InventoryHonorSelectionFocused", GuiService.SelectedObject == card)
		local screen = self.Root:FindFirstAncestorWhichIsA("ScreenGui")
		if screen then
			screen:SetAttribute("SelectedHonorItemId", selectedId)
			screen:SetAttribute("SelectedHonorCanvasY", self.Grid.CanvasPosition.Y)
		end
	end)
end

function InventoryUI:_applyFilter(resetDrawer)
	self:_cancelDeleteConfirmation(false)
	self._visibleItems = self:_filterSnapshot()
	local selectedStillVisible = false
	for _, item in ipairs(self._visibleItems) do
		if tostring(item.key) == tostring(self._selectedKey) then
			selectedStillVisible = true
			break
		end
	end
	if not selectedStillVisible then
		self._selectedKey = self._visibleItems[1] and tostring(self._visibleItems[1].key) or nil
	end
	self._selectedItem = self:_findItem(self._selectedKey)
	if resetDrawer and self._layout.compact then
		self._detailExpanded = false
	end
	self:_updateCapacity()
	self:_renderCategories()
	self:_renderGrid()
	self:_clearActionButtons()
	self:_requestDetailRender("filter")
	self.Root:SetAttribute("InventoryCategory", self._category)
	self.Root:SetAttribute("InventorySearch", self._search)
	self.Root:SetAttribute("InventoryRarity", self._rarity)
	self.Root:SetAttribute("InventoryVisibleCount", #self._visibleItems)
	self.Root:SetAttribute("InventorySelectedKey", self._selectedKey or "")
	self:_updateHonorDiagnostics()
end

function InventoryUI:SetVisible(visible)
	visible = visible == true
	if visible then
		self:Refresh(true, false)
		self:_setRarityMenu(false)
		local viewport = self.Root.AbsoluteSize
		if viewport.X < 1 or viewport.Y < 1 then
			viewport = self._layout.viewport
		end
		self:ApplyResponsive(viewport, viewport.X < 900 or viewport.Y < 520, self._layout.uiScale)
	else
		self._selectionFocusGeneration += 1
		self:_cancelDeleteConfirmation(false)
		self:_cancelPendingDetailRender()
		self:_setRarityMenu(false)
	end
	self.Root.Visible = visible
	self:_syncTimedRefresh()
	self.Root:SetAttribute("InventoryVisible", visible)
end

function InventoryUI:IsVisible()
	return self.Root.Visible
end

function InventoryUI:_snapshotResult(includeDiagnostics)
	-- Public calls keep the full automation snapshot by default; native callbacks
	-- explicitly pass false because they do not consume diagnostic layout scans.
	if includeDiagnostics == false then
		self._diagnosticSnapshotSkipCount = self._diagnosticSnapshotSkipCount + 1
		return nil
	end
	return self:GetSnapshot()
end

function InventoryUI:Refresh(force, includeDiagnostics)
	local stats = self:_getStats()
	local ok, signature = pcall(InventoryViewModel.Signature, self.GameConfig, stats)
	if not ok then
		signature = tostring(stats)
	end
	signature = tostring(signature)
	if force == true or not self._snapshot or signature ~= self._signature then
		self._signature = signature
		self._snapshot = self:_buildSnapshot(stats)
		self._hasTimedItem = hasTimedItem(self._snapshot)
		self:_applyFilter(false)
		if self.Root.Visible then
			self:ApplyResponsive(self._layout.viewport, self._layout.compact, self._layout.uiScale)
		end
	end
	self:_syncTimedRefresh()
	return self:_snapshotResult(includeDiagnostics)
end

function InventoryUI:OpenSelection(category, key, includeDiagnostics)
	local requestedCategory = normalize(category)
	local matchedCategory
	for _, candidate in ipairs(CATEGORIES) do
		if normalize(candidate) == requestedCategory then
			matchedCategory = candidate
			break
		end
	end
	if not matchedCategory then
		return false, "category_not_found"
	end
	self:Refresh(true, false)
	local requestedKey = tostring(key or "")
	local item = self:_findItem(requestedKey)
	if not item or normalize(item.category) ~= normalize(matchedCategory) then
		return false, "item_not_found"
	end
	self:_setRarityMenu(false)
	self._category = matchedCategory
	self._search = ""
	self._rarity = "All"
	if self.Search.Text ~= "" then
		self._updatingSearch = true
		self.Search.Text = ""
		self._updatingSearch = false
	end
	self._selectedKey = requestedKey
	self._detailExpanded = false
	self:_applyFilter(false)
	if not self._selectedItem or tostring(self._selectedItem.key or "") ~= requestedKey then
		return false, "item_not_found"
	end
	self:ApplyResponsive(self._layout.viewport, self._layout.compact, self._layout.uiScale)
	self:_focusSelectedHonorCard()
	return true, self:_snapshotResult(includeDiagnostics)
end

function InventoryUI:SetCategory(name, includeDiagnostics)
	local requested = normalize(name)
	for _, category in ipairs(CATEGORIES) do
		if normalize(category) == requested then
			if self._rarityMenuOpen then
				self:_setRarityMenu(false)
			end
			self._category = category
			self:_applyFilter(true)
			self:ApplyResponsive(self._layout.viewport, self._layout.compact, self._layout.uiScale)
			self:_syncTimedRefresh()
			return self:_snapshotResult(includeDiagnostics)
		end
	end
	return self:_snapshotResult(includeDiagnostics)
end

function InventoryUI:SetSearch(text, includeDiagnostics)
	if self._rarityMenuOpen then
		self:_setRarityMenu(false)
	end
	self._search = tostring(text or "")
	if self.Search.Text ~= self._search then
		self._updatingSearch = true
		self.Search.Text = self._search
		self._updatingSearch = false
	end
	self:_applyFilter(true)
	self:ApplyResponsive(self._layout.viewport, self._layout.compact, self._layout.uiScale)
	self:_syncTimedRefresh()
	return self:_snapshotResult(includeDiagnostics)
end

function InventoryUI:SetRarity(name, includeDiagnostics)
	local requested = normalize(name)
	for _, rarity in ipairs(RARITIES) do
		if normalize(rarity) == requested then
			if self._rarityMenuOpen then
				self:_setRarityMenu(false)
			end
			self._rarity = rarity
			self:_applyFilter(true)
			self:ApplyResponsive(self._layout.viewport, self._layout.compact, self._layout.uiScale)
			self:_syncTimedRefresh()
			return self:_snapshotResult(includeDiagnostics)
		end
	end
	return self:_snapshotResult(includeDiagnostics)
end

function InventoryUI:SelectItem(key, includeDiagnostics)
	local item = self:_findItem(key)
	if not item then
		return self:_snapshotResult(includeDiagnostics)
	end
	if self._rarityMenuOpen then
		self:_setRarityMenu(false)
	end
	local previousKey = self._selectedKey
	self:_cancelDeleteConfirmation(false)
	self._selectedKey = tostring(item.key)
	self._selectedItem = item
	self._detailExpanded = true
	if tostring(previousKey or "") ~= self._selectedKey then
		self:_applyCardSelectionVisual(previousKey, false)
		self:_applyCardSelectionVisual(self._selectedKey, true)
		self._selectionVisualUpdateCount = self._selectionVisualUpdateCount + 1
		self.Root:SetAttribute("InventorySelectionVisualUpdateCount", self._selectionVisualUpdateCount)
	end
	self:_clearActionButtons()
	self:_requestDetailRender("selection")
	self:ApplyResponsive(self._layout.viewport, self._layout.compact, self._layout.uiScale)
	self:_syncTimedRefresh()
	self.Root:SetAttribute("InventorySelectedKey", self._selectedKey)
	self:_updateHonorDiagnostics()
	return self:_snapshotResult(includeDiagnostics)
end

function InventoryUI:_findAction(item, requestedName)
	local requested = normalize(requestedName)
	for _, action in ipairs(itemActions(item)) do
		local semantic = actionName(action)
		if actionEnabled(action)
			and (normalize(semantic) == requested or normalize(action.label) == requested or normalize(action.name) == requested)
		then
			return action, semantic
		end
	end
	return nil, nil
end

function InventoryUI:InvokeAction(request)
	local requestedName = request
	if type(request) == "table" then
		if request.key then
			local requestedKey = tostring(request.key)
			if not self:_findItem(requestedKey) then
				return false, "item_not_found"
			end
			if requestedKey ~= tostring(self._selectedKey) then
				self:SelectItem(requestedKey, false)
			end
		end
		requestedName = request.action or request.name
	end
	local item = self._selectedItem
	if not item or not requestedName then
		return false, "no_selection"
	end

	local action, semanticName = self:_findAction(item, requestedName)
	if not action then
		if normalize(requestedName) == "spin" and type(self.OpenSpin) == "function" then
			self.OpenSpin()
			return true
		end
		return false, "action_unavailable"
	end

	local destructive = action.destructive == true or action.confirm == true or normalize(semanticName) == "delete"
	if destructive then
		local key = tostring(item.key)
		local now = os.clock()
		if self._deleteConfirmKey ~= key or now > self._deleteConfirmUntil then
			self:_armDeleteConfirmation(key)
			return false, "confirmation_required"
		end
		self:_cancelDeleteConfirmation(true)
	end

	local payload = action.payload
	if type(payload) ~= "table" then
		return false, "missing_payload"
	end
	local ok, errorMessage = pcall(function()
		self.ActionRemote:FireServer(payload)
	end)
	if not ok then
		warn("InventoryUI action dispatch failed: " .. tostring(errorMessage))
		return false, "dispatch_failed"
	end
	self.Root:SetAttribute("LastInventoryAction", tostring(semanticName))
	self.Root:SetAttribute("LastInventoryActionKey", tostring(item.key))
	self:_requestDetailRender("action_dispatch")
	return true
end

function InventoryUI:ApplyResponsive(viewport, compact, uiScale)
	if typeof(viewport) ~= "Vector2" or viewport.X < 1 or viewport.Y < 1 then
		viewport = self.Root.AbsoluteSize
	end
	if viewport.X < 1 or viewport.Y < 1 then
		viewport = Vector2.new(1280, 720)
	end
	local scale = math.clamp(tonumber(uiScale) or 1, 0.75, 1.20)
	local availableWidth = viewport.X / scale
	local availableHeight = viewport.Y / scale
	local useCompact = compact == true or viewport.X < 900 or viewport.Y < 520 or availableWidth < 900
	local touchTarget = math.ceil(44 / scale)
	local primaryTextSize = math.ceil(14 / scale)
	local secondaryTextSize = math.ceil(12 / scale)
	local headerHeight = useCompact and (52 / scale) or math.max(68, touchTarget + 16)
	-- The modal host has already applied the viewport safe area and outer margin.
	-- Counteract UIScale here so compact content fills that host exactly once.
	local windowWidth = useCompact
			and availableWidth
		or math.max(320, math.min(1180, availableWidth - 32))
	local windowHeight = useCompact
			and availableHeight
		or math.max(280, math.min(720, availableHeight - 28))

	self._layout.viewport = viewport
	self._layout.compact = useCompact
	self._layout.uiScale = scale
	self._layout.detailMode = useCompact and "Drawer" or "Pane"
	self.WindowScale.Scale = scale
	self.Window.Size = UDim2.fromOffset(windowWidth, windowHeight)
	self.WindowShadow.Size = UDim2.fromOffset(windowWidth * scale, windowHeight * scale)
	self.Header.Size = UDim2.new(1, -16, 0, headerHeight)
	self.HeaderShadow.Size = UDim2.new(1, -20, 0, headerHeight)
	local bodyTop = headerHeight + (useCompact and 12 / scale or 12)
	local bodyBottom = useCompact and 8 / scale or 8
	self.Body.Position = UDim2.fromOffset(8, bodyTop)
	self.Body.Size = UDim2.new(1, -16, 1, -(bodyTop + bodyBottom))
	self.Subtitle.Visible = false
	local titleLeft = useCompact and 16 / scale or 30
	self.Title.Position = UDim2.fromOffset(titleLeft, 5)
	self.Title.Size = UDim2.new(1, -(titleLeft + math.max(touchTarget, useCompact and 44 or 50) + 30), 1, -13)
	if self.TitleTextLimit then
		self.TitleTextLimit.MinTextSize = useCompact and math.ceil(18 / scale) or 22
		self.TitleTextLimit.MaxTextSize = useCompact and math.ceil(22 / scale) or math.ceil(28 / scale)
	end
	self.HeaderPattern.Visible = false
	self.HeaderSlash.Visible = false
	local closeSize = useCompact and touchTarget or math.max(touchTarget, 50)
	self.Close.Size = UDim2.fromOffset(closeSize, closeSize)

	local bodyWidth = windowWidth - 16
	local bodyHeight = windowHeight - bodyTop - bodyBottom
	local wideCategoryWidth = math.clamp(windowWidth * 0.145, 152, WIDE_CATEGORY_WIDTH)
	local detailWidth = math.clamp(windowWidth * 0.285, 282, 320)
	local gridPaneWidth = useCompact and bodyWidth - 8
		or bodyWidth
			- (4 + wideCategoryWidth + WIDE_CATEGORY_GAP)
			- detailWidth
			- 12
	local toolbarHeight = touchTarget
	local toolbarContentWidth = math.max(0, gridPaneWidth - 16)
	local toolbarWidths = allocateToolbarWidths(toolbarContentWidth, useCompact, touchTarget)
	local capacityWidth = toolbarWidths.capacity
	local rarityWidth = toolbarWidths.rarity
	local searchWidth = toolbarWidths.search
	local toolbarGap = toolbarWidths.gap
	self._toolbarCapacityWidth = capacityWidth
	self._toolbarRarityWidth = rarityWidth
	self.Toolbar.Size = UDim2.new(1, -16, 0, toolbarHeight)
	self.Search.Size = UDim2.fromOffset(searchWidth, toolbarHeight)
	self.Search.TextSize = primaryTextSize
	self.Search.PlaceholderText = useCompact and "Search" or "Search items..."
	local showSearchGlyph = not useCompact or searchWidth * scale >= 140
	self.SearchGlyph.Visible = showSearchGlyph
	self.SearchPadding.PaddingLeft = UDim.new(0, showSearchGlyph and 35 or 8 / scale)
	self.SearchPadding.PaddingRight = UDim.new(0, useCompact and 8 / scale or 10)
	self.SearchGlyph.Size = UDim2.fromOffset(20, toolbarHeight)
	self.RarityFilter.AnchorPoint = Vector2.zero
	self.RarityFilter.Position = UDim2.fromOffset(searchWidth + toolbarGap, 0)
	self.RarityFilter.Size = UDim2.fromOffset(rarityWidth, toolbarHeight)
	self.Capacity.AnchorPoint = Vector2.zero
	self.Capacity.Position = UDim2.fromOffset(
		searchWidth + toolbarGap + rarityWidth + toolbarGap,
		0
	)
	self.Capacity.Size = UDim2.fromOffset(capacityWidth, toolbarHeight)
	self.Capacity.TextSize = secondaryTextSize
	self.RarityFilter.TextSize = secondaryTextSize
	self:_updateCapacity()
	self:_setRarityMenu(self._rarityMenuOpen)
	self.Toolbar:SetAttribute("InventoryToolbarContentWidth", toolbarWidths.total * scale)
	self.Toolbar:SetAttribute("InventoryToolbarUsedWidth", toolbarWidths.used * scale)
	self.Toolbar:SetAttribute("InventoryToolbarNoOverlap", toolbarWidths.noOverlap)
	self.Search:SetAttribute("InventoryAdaptiveMinimumWidth", toolbarWidths.minimumSearch * scale)
	self.Search:SetAttribute("InventoryExpectedWidth", searchWidth * scale)
	self.Search:SetAttribute("InventoryReadableWidth", toolbarWidths.readable)
	self.RarityFilter:SetAttribute("InventoryExpectedWidth", rarityWidth * scale)
	self.Capacity:SetAttribute("InventoryExpectedWidth", capacityWidth * scale)
	local rarityMenuTop = toolbarHeight + 12
	local desiredRarityMenuHeight = #RARITIES * touchTarget + 12
	local availableRarityMenuHeight = bodyHeight - rarityMenuTop - 12
	if useCompact then
		local compactContentHeight = math.max(0, bodyHeight - (touchTarget + 8) - 12)
		availableRarityMenuHeight = compactContentHeight - rarityMenuTop - 4
	end
	local rarityMenuHeight = math.max(
		touchTarget + 12,
		math.min(desiredRarityMenuHeight, math.max(touchTarget + 12, availableRarityMenuHeight))
	)
	self.RarityMenu.AnchorPoint = Vector2.zero
	self.RarityMenu.Position = UDim2.fromOffset(8 + searchWidth + toolbarGap, rarityMenuTop)
	self.RarityMenu.Size = UDim2.fromOffset(rarityWidth, rarityMenuHeight)
	self.RarityMenu.ScrollBarThickness = rarityMenuHeight < desiredRarityMenuHeight and 5 or 0
	self.RarityMenu:SetAttribute("InventoryRarityEntryHeight", touchTarget * scale)
	self.RarityMenu:SetAttribute("InventoryRarityMenuBounded", useCompact)
	self.RarityMenu:SetAttribute("InventoryRarityMenuHeight", rarityMenuHeight * scale)
	for _, button in pairs(self._rarityButtons) do
		button.Size = UDim2.new(1, 0, 0, touchTarget)
		button.TextSize = secondaryTextSize
	end
	local gridTop = toolbarHeight + 16
	self.Grid.Position = UDim2.fromOffset(8, gridTop)
	self.Grid.Size = UDim2.new(1, -16, 1, -(gridTop + 8))
	local gridPaneHeightForEmpty = useCompact
			and math.max(0, bodyHeight - (touchTarget + 8) - 12)
			or math.max(0, bodyHeight - 8)
	local availableEmptyHeight = math.max(48, gridPaneHeightForEmpty - gridTop - 16)
	local emptyHeight = math.min(useCompact and 104 or 132, availableEmptyHeight)
	local emptyCenterY = gridTop + math.max(0, gridPaneHeightForEmpty - gridTop) * 0.5
	self.EmptyState.Position = UDim2.new(0.5, 0, 0, math.floor(emptyCenterY))
	self.EmptyState.Size = UDim2.new(1, useCompact and -24 or -48, 0, emptyHeight)
	self.EmptySlotRow.Visible = emptyHeight >= 88
	if self.EmptySlotRow.Visible then
		local emptySlotHeight = math.clamp(math.floor(emptyHeight * 0.47), 42, 62)
		self.EmptySlotRow.Size = UDim2.new(1, -20, 0, emptySlotHeight)
		self.Empty.Position = UDim2.fromOffset(10, emptySlotHeight + 14)
		self.Empty.Size = UDim2.new(1, -20, 1, -(emptySlotHeight + 20))
	else
		self.Empty.Position = UDim2.fromOffset(8, 5)
		self.Empty.Size = UDim2.new(1, -16, 1, -10)
	end
	self.Empty.TextSize = secondaryTextSize
	self.DetailMetaStrip.Visible = false
	self._layout.tallDetail = false
	self.DetailDescription.BackgroundTransparency = 0.12
	self.DetailDescriptionStroke.Transparency = 0.28
	self.Root:SetAttribute("InventoryCompactDetailLayout", "Original")
	self.Root:SetAttribute("InventoryDetailHeroSize", 0)
	if useCompact then
		self.DetailArtFrame.AnchorPoint = Vector2.zero
		self.Root:SetAttribute("InventoryWideActionColumns", 0)
		self.CategoryBar.Position = UDim2.fromOffset(4, 4)
		self.CategoryBar.Size = UDim2.new(1, -8, 0, touchTarget + 4)
		self.CategoryPadding.PaddingTop = UDim.new(0, 2)
		self.CategoryPadding.PaddingBottom = UDim.new(0, 2)
		self.CategoryPadding.PaddingLeft = UDim.new(0, 4)
		self.CategoryPadding.PaddingRight = UDim.new(0, 4)
		self.CategoryLayout.FillDirection = Enum.FillDirection.Horizontal
		self.CategoryLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		self.CategoryLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		self.CategoryLayout.Padding = UDim.new(0, 3)
		local categoryWidth = math.max(
			touchTarget,
			math.floor((bodyWidth - 8 - 8 - 12) / #CATEGORIES)
		)
		for _, category in ipairs(CATEGORIES) do
			local widgets = self._categoryButtons[category]
			widgets.button.Size = UDim2.fromOffset(categoryWidth, touchTarget)
			widgets.button.TextSize = secondaryTextSize
			local showIcon = categoryWidth * scale >= 90
			widgets.button.Text = not showIcon and category == "Boosts" and "BOOST" or string.upper(category)
			widgets.button.TextXAlignment = showIcon and Enum.TextXAlignment.Right or Enum.TextXAlignment.Center
			widgets.icon.Visible = showIcon
			widgets.padding.PaddingLeft = UDim.new(0, showIcon and 24 or 2 / scale)
			widgets.padding.PaddingRight = UDim.new(0, 2 / scale)
			widgets.icon.Position = UDim2.fromOffset(-21, 10)
			widgets.icon.Size = UDim2.fromOffset(20, 20)
			widgets.indicator.Position = UDim2.fromOffset(showIcon and -28 or 0, 4)
			widgets.indicator.Size = UDim2.new(0, 3, 1, -8)
			widgets.arrow.Visible = false
		end

		local categoryHeight = touchTarget + 4
		local drawerOpen = self._detailExpanded and self._selectedItem ~= nil
		local contentHeight = math.max(0, bodyHeight - categoryHeight - 12)
		local drawerHeight = drawerOpen and contentHeight or 0
		self.GridPane.Position = UDim2.fromOffset(4, categoryHeight + 8)
		self.GridPane.Size = UDim2.new(1, -8, 0, drawerOpen and 0 or contentHeight)
		self.GridPane.Visible = not drawerOpen
		self.Toolbar.Visible = not drawerOpen
		self.Grid.Visible = not drawerOpen
		if drawerOpen then
			self.Grid.Size = UDim2.new(1, -16, 0, 0)
		end
		self.Detail.Position = UDim2.fromOffset(4, categoryHeight + 8)
		self.Detail.Size = UDim2.new(1, -8, 0, drawerHeight)
		self.DetailClose.Size = UDim2.fromOffset(touchTarget, touchTarget)
		self.DetailClose.Visible = drawerOpen
		self.CompactDetailDrawer.Visible = drawerOpen
		self.DetailStats.Visible = false
		self:_syncDetailVisibility()
		local actionCount = math.max(1, #self._activeActionButtons)
		local actionColumns = math.min(2, actionCount)
		local actionRows = math.ceil(actionCount / actionColumns)
		local actionGap = 6 / scale
		local actionAreaHeight = actionRows * touchTarget + math.max(0, actionRows - 1) * actionGap
		local detailPanelWidth = bodyWidth - 8
		local horizontalDrawer = detailPanelWidth * scale >= 480
		local edge = 12 / scale
		local artSize = 96 / scale
		local infoLeft = 120 / scale
		local actionPanelWidth
		self.DetailArtFrame.Position = UDim2.fromOffset(edge, edge)
		self.DetailArtFrame.Size = UDim2.fromOffset(artSize, artSize)
		self.DetailCategoryTag.Visible = false
		self.DetailInternalName.Visible = false
		self.DetailName.TextScaled = false
		self.DetailName.TextSize = primaryTextSize
		self.DetailNameTextLimit.MinTextSize = 1
		self.DetailNameTextLimit.MaxTextSize = primaryTextSize
		self.DetailNameTextLimit.MinTextSize = primaryTextSize
		self.DetailRarity.TextSize = secondaryTextSize
		self.DetailDescription.TextSize = secondaryTextSize
		self.DetailStatus.TextSize = secondaryTextSize
		local physicalWidth, physicalHeight = detailPanelWidth * scale, drawerHeight * scale
		local physicalActions = actionAreaHeight * scale
		local informationHeight = 20 + 8 + 40 + 8 + 64 + 12 + physicalActions
		local tallColumns = drawerOpen and physicalWidth >= 440 and physicalHeight >= math.max(360, informationHeight + 72)
		local tallPortrait = drawerOpen and physicalWidth >= 280 and physicalWidth < 440 and physicalHeight >= 480
		if tallColumns or tallPortrait then
			local heroSize, heroX, heroY, infoX, infoY, infoWidth
			if tallColumns then
				heroSize = math.min(280, physicalWidth * 0.44, physicalHeight - 72)
				infoWidth = math.min(320, physicalWidth - heroSize - 20 - 24)
				local groupWidth = heroSize + 20 + infoWidth
				local groupHeight = math.max(heroSize, informationHeight)
				local top = math.max(60, (physicalHeight - groupHeight) * 0.5)
				heroX = (physicalWidth - groupWidth) * 0.5
				heroY = top + (groupHeight - heroSize) * 0.5
				infoX = heroX + heroSize + 20
				infoY = top + (groupHeight - informationHeight) * 0.5
			else
				-- Keep the top-right close target clear even in a narrow portrait.
				heroSize = math.min(240, physicalWidth - 120, physicalHeight - informationHeight - 40)
				infoWidth = math.min(320, physicalWidth - 24)
				heroX = (physicalWidth - heroSize) * 0.5
				heroY = (physicalHeight - heroSize - 16 - informationHeight) * 0.5
				infoX = (physicalWidth - infoWidth) * 0.5
				infoY = heroY + heroSize + 16
			end
			self._layout.tallDetail = true
			self.Root:SetAttribute("InventoryCompactDetailLayout", tallColumns and "TallHeroColumnsV1" or "TallHeroPortraitV1")
			self.Root:SetAttribute("InventoryDetailHeroSize", heroSize)
			self.DetailArtFrame.Position = UDim2.fromOffset(heroX / scale, heroY / scale)
			self.DetailArtFrame.Size = UDim2.fromOffset(heroSize / scale, heroSize / scale)
			self.DetailRarity.Position = UDim2.fromOffset(infoX / scale, infoY / scale)
			self.DetailRarity.Size = UDim2.fromOffset(math.min(infoWidth, 120) / scale, 20 / scale)
			self.DetailName.Position = UDim2.fromOffset(infoX / scale, (infoY + 28) / scale)
			self.DetailName.Size = UDim2.fromOffset(infoWidth / scale, 40 / scale)
			local titleSize = math.ceil((infoWidth >= 220 and 18 or 16) / scale)
			self.DetailName.TextSize = titleSize
			self.DetailNameTextLimit.MinTextSize = 1
			self.DetailNameTextLimit.MaxTextSize = titleSize
			self.DetailNameTextLimit.MinTextSize = titleSize
			self.DetailDescription.Visible = true
			self.DetailDescription.BackgroundTransparency = 1
			self.DetailDescriptionStroke.Transparency = 1
			self.DetailDescription.Position = UDim2.fromOffset(infoX / scale, (infoY + 76) / scale)
			self.DetailDescription.Size = UDim2.fromOffset(infoWidth / scale, 64 / scale)
			self.DetailStatus.Size = UDim2.fromOffset(0, 0)
			actionPanelWidth = infoWidth / scale
			self.DetailActions.Position = UDim2.fromOffset(infoX / scale, (infoY + 152) / scale)
		elseif horizontalDrawer then
			-- Keep a separate close-button column so two action rows remain usable
			-- even in a short landscape drawer.
			local closeLane = touchTarget + 8 / scale
			actionPanelWidth = math.min(300 / scale, detailPanelWidth * 0.43) - closeLane
			local actionLeft = detailPanelWidth - edge - closeLane - actionPanelWidth
			local infoWidth = math.max(1, actionLeft - infoLeft - edge)
			self.DetailRarity.Position = UDim2.fromOffset(infoLeft, edge)
			self.DetailRarity.Size = UDim2.fromOffset(math.min(infoWidth, 120 / scale), 20 / scale)
			self.DetailName.Position = UDim2.fromOffset(infoLeft, 38 / scale)
			self.DetailName.Size = UDim2.fromOffset(infoWidth, 36 / scale)
			local descriptionY = 80 / scale
			local statusHeight = self.DetailStatus.Visible and 36 / scale or 0
			local descriptionHeight = math.max(0, drawerHeight - descriptionY - edge - statusHeight)
			self.DetailDescription.Visible = descriptionHeight >= 32 / scale
			self.DetailDescription.Position = UDim2.fromOffset(infoLeft, descriptionY)
			self.DetailDescription.Size = UDim2.fromOffset(infoWidth, descriptionHeight)
			self.DetailStatus.Position = UDim2.fromOffset(infoLeft, drawerHeight - edge - statusHeight)
			self.DetailStatus.Size = UDim2.fromOffset(infoWidth, statusHeight)
			self.DetailActions.Position = UDim2.fromOffset(actionLeft, math.max(edge, drawerHeight - actionAreaHeight - edge))
		else
			actionPanelWidth = detailPanelWidth - edge * 2
			self.DetailRarity.Position = UDim2.fromOffset(infoLeft, 64 / scale)
			self.DetailRarity.Size = UDim2.new(1, -(infoLeft + edge), 0, 20 / scale)
			self.DetailName.Position = UDim2.fromOffset(edge, 120 / scale)
			self.DetailName.Size = UDim2.new(1, -edge * 2, 0, 38 / scale)
			local actionY = drawerHeight - actionAreaHeight - edge
			local statusHeight = self.DetailStatus.Visible and 40 / scale or 0
			local descriptionY = 168 / scale
			local descriptionHeight = math.max(0, actionY - descriptionY - edge - statusHeight)
			self.DetailDescription.Visible = descriptionHeight >= 32 / scale
			self.DetailDescription.Position = UDim2.fromOffset(edge, descriptionY)
			self.DetailDescription.Size = UDim2.new(1, -edge * 2, 0, descriptionHeight)
			self.DetailStatus.Position = UDim2.fromOffset(edge, actionY - edge - statusHeight)
			self.DetailStatus.Size = UDim2.new(1, -edge * 2, 0, statusHeight)
			self.DetailActions.Position = UDim2.fromOffset(edge, actionY)
		end
		self.DetailActions.Size = UDim2.fromOffset(actionPanelWidth, actionAreaHeight)
		self.DetailActionLayout.FillDirection = Enum.FillDirection.Horizontal
		self.DetailActionLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
		self.DetailActionLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		local actionWidth = math.max(touchTarget, math.floor((actionPanelWidth - (actionColumns - 1) * actionGap) / actionColumns))
		self.DetailActionLayout.FillDirectionMaxCells = actionColumns
		self.DetailActionLayout.CellPadding = UDim2.fromOffset(actionGap, actionGap)
		self.DetailActionLayout.CellSize = UDim2.fromOffset(actionWidth, touchTarget)
		for _, button in ipairs(self._activeActionButtons) do
			if button:IsA("TextButton") or button:IsA("TextLabel") then
				button.TextSize = secondaryTextSize
				button.TextWrapped = true
			end
		end
	else
		self.DetailInternalName.Visible = true
		self.DetailName.TextScaled = true
		self.DetailNameTextLimit.MinTextSize = 1
		self.DetailNameTextLimit.MaxTextSize = math.ceil(21 / scale)
		self.DetailNameTextLimit.MinTextSize = primaryTextSize
		self.DetailDescription.Visible = true
		self.GridPane.Visible = true
		self.Toolbar.Visible = true
		self.Grid.Visible = true
		self.CategoryBar.Position = UDim2.fromOffset(4, 4)
		self.CategoryBar.Size = UDim2.fromOffset(wideCategoryWidth, bodyHeight - 8)
		self.CategoryPadding.PaddingTop = UDim.new(0, 8)
		self.CategoryPadding.PaddingBottom = UDim.new(0, 8)
		self.CategoryPadding.PaddingLeft = UDim.new(0, 8)
		self.CategoryPadding.PaddingRight = UDim.new(0, 8)
		self.CategoryLayout.FillDirection = Enum.FillDirection.Vertical
		self.CategoryLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		self.CategoryLayout.VerticalAlignment = Enum.VerticalAlignment.Top
		self.CategoryLayout.Padding = UDim.new(0, 6)
		for _, category in ipairs(CATEGORIES) do
			local widgets = self._categoryButtons[category]
			widgets.button.Size = UDim2.new(1, 0, 0, math.max(56, touchTarget))
			widgets.button.TextSize = secondaryTextSize
			widgets.button.Text = string.upper(category)
			widgets.button.TextXAlignment = Enum.TextXAlignment.Right
			widgets.icon.Visible = true
			widgets.padding.PaddingLeft = UDim.new(0, 50)
			widgets.padding.PaddingRight = UDim.new(0, 13)
			widgets.icon.Position = UDim2.fromOffset(-41, 8)
			widgets.icon.Size = UDim2.fromOffset(40, 40)
			widgets.indicator.Position = UDim2.fromOffset(-50, 5)
			widgets.indicator.Size = UDim2.new(0, 4, 1, -10)
			widgets.arrow.Visible = category == self._category
		end

		local gridX = 4 + wideCategoryWidth + WIDE_CATEGORY_GAP
		self.Detail.Position = UDim2.new(1, -detailWidth - 4, 0, 4)
		self.Detail.Size = UDim2.new(0, detailWidth, 1, -8)
		self.Detail.Visible = true
		self.DetailClose.Visible = false
		self.CompactDetailDrawer.Visible = false
		self.GridPane.Position = UDim2.fromOffset(gridX, 4)
		self.GridPane.Size = UDim2.new(1, -(gridX + detailWidth + 12), 1, -8)

		local detailHeight = bodyHeight - 8
		self.DetailRarity.Position = UDim2.fromOffset(14, 16)
		self.DetailRarity.Size = UDim2.fromOffset(104, 22)
		self.DetailRarity.TextSize = secondaryTextSize
		self.DetailCategoryTag.AnchorPoint = Vector2.new(1, 0)
		self.DetailCategoryTag.Position = UDim2.new(1, -14, 0, 16)
		self.DetailCategoryTag.Size = UDim2.fromOffset(98, 22)
		self.DetailCategoryTag.TextSize = secondaryTextSize
		self.DetailCategoryTag.Visible = true
		self.DetailName.Position = UDim2.fromOffset(14, 43)
		self.DetailName.Size = UDim2.new(1, -28, 0, 36)
		self.DetailInternalName.Position = UDim2.fromOffset(14, 79)
		self.DetailInternalName.Size = UDim2.new(1, -28, 0, 16)
		self.DetailInternalName.TextSize = secondaryTextSize

		local artY = 102
		local artSize = math.clamp(detailHeight * 0.245, 124, 154)
		self.DetailArtFrame.AnchorPoint = Vector2.new(0.5, 0)
		self.DetailArtFrame.Position = UDim2.new(0.5, 0, 0, artY)
		self.DetailArtFrame.Size = UDim2.fromOffset(artSize, artSize)
		local artBottom = artY + artSize
		local wideActionCount = math.max(1, #self._activeActionButtons)
		local actionColumns = wideActionCount == 4 and 2 or math.min(3, wideActionCount)
		self.Root:SetAttribute("InventoryWideActionColumns", actionColumns)
		local actionRows = math.ceil(wideActionCount / actionColumns)
		local actionAreaHeight = actionRows * touchTarget + math.max(0, actionRows - 1) * 6
		local actionY = detailHeight - actionAreaHeight - 8
		local statusY = actionY - (self.DetailStatus.Visible and 50 or 0)
		local statsHeight = 86
		local statsY = statusY - statsHeight - 8
		local descriptionY = artBottom + 10
		local showStats = detailHeight >= 430 and statsY >= descriptionY + 46
		local descriptionBottom = showStats and statsY - 8 or statusY - 8
		self.DetailDescription.Position = UDim2.fromOffset(16, descriptionY)
		self.DetailDescription.Size = UDim2.new(1, -32, 0, math.max(42, descriptionBottom - descriptionY))
		self.DetailDescription.TextSize = secondaryTextSize
		self.DetailStats.Visible = showStats
		self.DetailStats.Position = UDim2.fromOffset(14, statsY)
		self.DetailStats.Size = UDim2.new(1, -28, 0, statsHeight)
		self.DetailStatus.Position = UDim2.fromOffset(14, statusY)
		self.DetailStatus.Size = UDim2.new(1, -28, 0, 42)
		self.DetailStatus.TextSize = secondaryTextSize
		self.DetailActions.Position = UDim2.fromOffset(14, actionY)
		self.DetailActions.Size = UDim2.new(1, -28, 0, actionAreaHeight)
		self.DetailActionLayout.FillDirection = Enum.FillDirection.Horizontal
		self.DetailActionLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		self.DetailActionLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
		local actionWidth = math.floor((detailWidth - 28 - math.max(0, actionColumns - 1) * 6) / actionColumns)
		self.DetailActionLayout.FillDirectionMaxCells = actionColumns
		self.DetailActionLayout.CellPadding = UDim2.fromOffset(6, 6)
		self.DetailActionLayout.CellSize = UDim2.fromOffset(actionWidth, touchTarget)
		for _, button in ipairs(self._activeActionButtons) do
			if button:IsA("TextButton") or button:IsA("TextLabel") then
				button.TextSize = secondaryTextSize
			end
		end
		for _, widgets in ipairs(self.DetailStatRows) do
			widgets.label.TextSize = secondaryTextSize
			widgets.value.TextSize = secondaryTextSize
		end
	end

	local gridContentWidth = math.max(1, gridPaneWidth - 24)
	local preferredColumns
	if useCompact then
		preferredColumns = gridContentWidth * scale >= 600 and 2 or 1
	else
		preferredColumns = 2
	end
	local padding = 8 / scale
	local minimumCellWidth = math.max(touchTarget, 280 / scale)
	local fittingColumns = math.max(
		1,
		math.floor((gridContentWidth + padding) / (minimumCellWidth + padding))
	)
	local columns = math.min(preferredColumns, fittingColumns)
	local cellWidth = math.max(
		touchTarget,
		math.floor((gridContentWidth - (columns - 1) * padding) / columns)
	)
	local cellHeight = (useCompact and 92 or 104) / scale
	local artSize = useCompact and 76 or 88
	local contentLeft = useCompact and 92 or 104
	for _, cardRef in ipairs(self._cardPool) do
		cardRef.rarity.TextSize = secondaryTextSize
		cardRef.quantity.TextSize = secondaryTextSize
		cardRef.equipped.TextSize = secondaryTextSize
		cardRef.locked.TextSize = secondaryTextSize
		cardRef.lockedMessage.TextSize = secondaryTextSize
		cardRef.footerRail.Visible = false
		local stateWidth = math.min(116, cellWidth * scale - contentLeft - 8 - (cardRef.quantity.Visible and 60 or 0)) / scale
		cardRef.artFrame.Position = UDim2.fromOffset(8 / scale, 8 / scale)
		cardRef.artFrame.Size = UDim2.fromOffset(artSize / scale, artSize / scale)
		cardRef.rarity.Position = UDim2.fromOffset(contentLeft / scale, 46 / scale)
		cardRef.rarity.Size = UDim2.fromOffset(120 / scale, 18 / scale)
		cardRef.equipped.AnchorPoint = Vector2.zero
		cardRef.equipped.Position = UDim2.fromOffset(contentLeft / scale, 68 / scale)
		cardRef.equipped.Size = UDim2.fromOffset(math.min(94 / scale, stateWidth), 18 / scale)
		cardRef.locked.AnchorPoint = Vector2.zero
		cardRef.locked.Position = UDim2.fromOffset(contentLeft / scale, 68 / scale)
		cardRef.locked.Size = UDim2.fromOffset(stateWidth, 18 / scale)
		cardRef.quantity.Position = UDim2.new(1, -8 / scale, 0, 68 / scale)
		cardRef.quantity.Size = UDim2.fromOffset(54 / scale, 18 / scale)
		cardRef.name.Position = UDim2.fromOffset(contentLeft / scale, 8 / scale)
		cardRef.name.Size = UDim2.new(1, -(contentLeft + 8) / scale, 0, 36 / scale)
		cardRef.name.TextScaled = false
		cardRef.name.TextSize = primaryTextSize
		cardRef.name.TextXAlignment = Enum.TextXAlignment.Left
		cardRef.name.TextYAlignment = Enum.TextYAlignment.Top
		cardRef.nameTextLimit.MinTextSize = 1
		cardRef.nameTextLimit.MaxTextSize = primaryTextSize
		cardRef.nameTextLimit.MinTextSize = primaryTextSize
	end
	for _, label in ipairs(self.EmptySlotLabels) do
		label.TextSize = secondaryTextSize
	end
	self._layout.columns = columns
	self.GridLayout.FillDirectionMaxCells = columns
	self.GridLayout.CellPadding = UDim2.fromOffset(padding, padding)
	self.GridLayout.CellSize = UDim2.fromOffset(cellWidth, cellHeight)
	if self._snapshot then
		self:_renderSparseSlots()
	end
	for _, ref in ipairs(self._sparseSlotPool) do
		ref.label.TextSize = secondaryTextSize
	end
	self.Root:SetAttribute("InventoryCompact", useCompact)
	self.Root:SetAttribute("InventoryColumns", columns)
	self.Root:SetAttribute("InventoryMobileLayout", useCompact and "PhoneReadableRowsV6" or "DesktopReadableRowsV4")
	self.Root:SetAttribute("InventoryCardHeight", cellHeight * scale)
	self.Root:SetAttribute("InventoryCardMaximumCompactHeight", useCompact and 96 or 0)
	self.Root:SetAttribute("InventoryCompactCardContentVersion", useCompact and "HorizontalPreviewV5" or "DesktopV3")
	self.Root:SetAttribute("InventoryPrimaryRenderedTextSize", primaryTextSize * scale)
	self.Root:SetAttribute("InventorySecondaryRenderedTextSize", secondaryTextSize * scale)
	self.Root:SetAttribute("InventoryAvailableGridWidth", gridContentWidth * scale)
	self.Root:SetAttribute("InventoryMinimumTouchTarget", touchTarget * scale)
	self.Root:SetAttribute("InventoryDetailMode", self._layout.detailMode)
	self.Root:SetAttribute("InventoryUIScale", scale)
	self.Root:SetAttribute("InventoryUIScaleContractMax", 1.20)
	self.Root:SetAttribute("InventoryRenderedWindowWidth", windowWidth * scale)
	self.Root:SetAttribute("InventoryRenderedWindowHeight", windowHeight * scale)
	self.Root:SetAttribute("InventoryViewportWidth", viewport.X)
	self.Root:SetAttribute("InventoryViewportHeight", viewport.Y)
	self.Root:SetAttribute(
		"InventoryWindowBoundsSafe",
		windowWidth * scale <= viewport.X + 0.5
			and windowHeight * scale <= viewport.Y + 0.5
	)
	self.Root:SetAttribute("InventoryToolbarNoOverlap", toolbarWidths.noOverlap)
	self.Root:SetAttribute("InventorySearchReadable", toolbarWidths.readable)
	self.Root:SetAttribute("InventorySearchExpectedWidth", searchWidth * scale)
	self.Root:SetAttribute("InventorySearchMinimumWidth", toolbarWidths.minimumSearch * scale)
	if typeof(self.DetailPetPreview.viewport) == "Instance" then
		self:_refitDetailPreview()
	end
end

function InventoryUI:_enabledActionNames(item)
	local result = {}
	for _, action in ipairs(itemActions(item)) do
		if actionEnabled(action) then
			table.insert(result, actionName(action))
		end
	end
	return result
end

function InventoryUI:_textFits()
	if not self.Root.Visible or self.Root.AbsoluteSize.X < 1 then
		return true
	end
	for _, descendant in ipairs(self.Window:GetDescendants()) do
		if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
			local effectivelyVisible = descendant.Visible
			local ancestor = descendant.Parent
			while effectivelyVisible and ancestor and ancestor ~= self.Root do
				if ancestor:IsA("GuiObject") and not ancestor.Visible then
					effectivelyVisible = false
				end
				ancestor = ancestor.Parent
			end
			if effectivelyVisible and descendant.AbsoluteSize.X > 0 and descendant.AbsoluteSize.Y > 0 then
				local managed = descendant.TextScaled
					or descendant.TextWrapped
					or descendant.TextTruncate ~= Enum.TextTruncate.None
				if not managed and (
					descendant.TextBounds.X > descendant.AbsoluteSize.X + 2
					or descendant.TextBounds.Y > descendant.AbsoluteSize.Y + 2
				) then
					return false
				end
			end
		end
	end
	return true
end

function InventoryUI:_insideSafeArea()
	if not self.Root.Visible or self.Root.AbsoluteSize.X < 1 or self.Window.AbsoluteSize.X < 1 then
		return true
	end
	local rootPosition = self.Root.AbsolutePosition
	local rootSize = self.Root.AbsoluteSize
	local position = self.Window.AbsolutePosition
	local size = self.Window.AbsoluteSize
	return position.X >= rootPosition.X - 1
		and position.Y >= rootPosition.Y - 1
		and position.X + size.X <= rootPosition.X + rootSize.X + 1
		and position.Y + size.Y <= rootPosition.Y + rootSize.Y + 1
end

function InventoryUI:_layoutHasNoOverlap()
	if not self.Root.Visible or self.Body.AbsoluteSize.X < 1 then
		return true
	end
	if self._layout.compact then
		if not self.Detail.Visible or not self.GridPane.Visible then
			return true
		end
		return not rectsOverlap(
			self.GridPane.AbsolutePosition,
			self.GridPane.AbsoluteSize,
			self.Detail.AbsolutePosition,
			self.Detail.AbsoluteSize
		)
	end
	return not rectsOverlap(
		self.CategoryBar.AbsolutePosition,
		self.CategoryBar.AbsoluteSize,
		self.GridPane.AbsolutePosition,
		self.GridPane.AbsoluteSize
	) and not rectsOverlap(
		self.GridPane.AbsolutePosition,
		self.GridPane.AbsoluteSize,
		self.Detail.AbsolutePosition,
		self.Detail.AbsoluteSize
	)
end

function InventoryUI:_minimumTouchTarget()
	if not self.Root.Visible or self.Root.AbsoluteSize.X < 1 then
		return tonumber(self.Root:GetAttribute("InventoryMinimumTouchTarget")) or 44
	end
	local minimum = math.huge
	for _, descendant in ipairs(self.Window:GetDescendants()) do
		if descendant:IsA("TextButton") or descendant:IsA("TextBox") then
			local effectivelyVisible = descendant.Visible
			local ancestor = descendant.Parent
			while effectivelyVisible and ancestor and ancestor ~= self.Root do
				if ancestor:IsA("GuiObject") and not ancestor.Visible then
					effectivelyVisible = false
				end
				ancestor = ancestor.Parent
			end
			if effectivelyVisible and descendant.AbsoluteSize.X > 0 and descendant.AbsoluteSize.Y > 0 then
				minimum = math.min(minimum, descendant.AbsoluteSize.X, descendant.AbsoluteSize.Y)
			end
		end
	end
	return minimum < math.huge and minimum or 44
end

function InventoryUI:GetSnapshot()
	self._diagnosticSnapshotCount = self._diagnosticSnapshotCount + 1
	local visibleKeys = {}
	local visibleNames = {}
	for _, item in ipairs(self._visibleItems) do
		table.insert(visibleKeys, tostring(item.key or ""))
		table.insert(visibleNames, tostring(item.name or item.displayName or ""))
	end

	local snapshot = self._snapshot or {}
	local rawCapacity = snapshot.capacity or {}
	local capacity = {
		used = tonumber(rawCapacity.used or snapshot.petUsed) or 0,
		max = tonumber(rawCapacity.total or rawCapacity.max or snapshot.petCapacity)
			or tonumber(self.GameConfig.MaxPetInventory)
			or 0,
	}

	local selected
	local item = self._selectedItem
	if item then
		selected = {
			key = tostring(item.key or ""),
			kind = tostring(item.kind or item.category or ""),
			name = tostring(item.name or ""),
			displayName = tostring(item.displayName or item.name or ""),
			description = tostring(item.description or item.detail or "No additional item details."),
			rarity = tostring(item.rarity or "Common"),
			slot = tonumber(item.slot),
			equipped = item.equipped == true,
			locked = item.locked == true,
			owned = item.owned == true,
			unlocked = item.unlocked == true,
			affordable = item.affordable == true,
			state = tostring(item.state or ""),
			cost = tonumber(item.cost) or 0,
			missingHonor = tonumber(item.missingHonor) or 0,
			artKey = tostring(item.artKey or ""),
			previewPet = tostring(item.previewPet or ""),
			fusionOwned = tonumber(item.fusionOwned) or 0,
			fusionRequired = tonumber(item.fusionRequired) or 0,
			fusionNextStars = tonumber(item.fusionNextStars) or 0,
			fusionEnabled = item.fusionEnabled == true,
			actions = self:_enabledActionNames(item),
		}
	end

	local hudHidden = self.Root.Visible
	if type(self.GetHUDHidden) == "function" then
		local ok, result = pcall(self.GetHUDHidden)
		if ok then
			hudHidden = result == true
		end
	end
	local actionVisuals = {}
	for _, control in ipairs(self._activeActionButtons) do
		table.insert(actionVisuals, {
			action = tostring(control:GetAttribute("InventoryAction") or control.Name),
			enabled = control:GetAttribute("InventoryActionEnabled") == true,
			state = tostring(control:GetAttribute("InventoryActionVisualState") or ""),
			style = tostring(control:GetAttribute("InventoryActionStyle") or ""),
			contrast = tonumber(control:GetAttribute("InventoryActionContrastRatio")) or 0,
		})
	end
	local hasUploadedArt = item and type(item.art) == "string" and item.art ~= ""
	return {
		ok = self._snapshot ~= nil,
		visible = self.Root.Visible,
		category = self._category,
		search = self._search,
		rarity = self._rarity,
		visibleKeys = visibleKeys,
		visibleNames = visibleNames,
		selected = selected,
		capacity = capacity,
		hudHidden = hudHidden,
		layout = {
			compact = self._layout.compact,
			columns = self._layout.columns,
			uiScale = self._layout.uiScale,
			minTouchTarget = self:_minimumTouchTarget(),
			detailMode = self._layout.detailMode,
			renderedWindowWidth = tonumber(self.Root:GetAttribute("InventoryRenderedWindowWidth")) or 0,
			renderedWindowHeight = tonumber(self.Root:GetAttribute("InventoryRenderedWindowHeight")) or 0,
			viewportWidth = tonumber(self.Root:GetAttribute("InventoryViewportWidth")) or 0,
			viewportHeight = tonumber(self.Root:GetAttribute("InventoryViewportHeight")) or 0,
			boundsSafe = self.Root:GetAttribute("InventoryWindowBoundsSafe") == true,
			searchWidth = tonumber(self.Root:GetAttribute("InventorySearchExpectedWidth")) or 0,
			searchMinimum = tonumber(self.Root:GetAttribute("InventorySearchMinimumWidth")) or 0,
			searchReadable = self.Root:GetAttribute("InventorySearchReadable") == true,
			toolbarNoOverlap = self.Root:GetAttribute("InventoryToolbarNoOverlap") == true,
			hoveredCategory = tostring(self.Root:GetAttribute("InventoryHoveredCategory") or ""),
			capacityMode = tostring(self.Capacity:GetAttribute("InventoryCapacityTextMode") or ""),
			capacityText = tostring(self.Capacity:GetAttribute("InventoryCapacityRenderedText") or ""),
			capacityFullText = tostring(self.Capacity:GetAttribute("InventoryCapacityFullText") or ""),
			capacityReadable = self.Capacity:GetAttribute("InventoryCapacityReadable") == true,
			rarityMenuOpen = self.Root:GetAttribute("InventoryRarityMenuOpen") == true,
			rarityMenuZLayer = tonumber(self.Root:GetAttribute("InventoryRarityMenuZLayer")) or 0,
			rarityMenuBounded = self.RarityMenu:GetAttribute("InventoryRarityMenuBounded") == true,
			rarityMenuHeight = tonumber(self.RarityMenu:GetAttribute("InventoryRarityMenuHeight")) or 0,
			rarityEntryHeight = tonumber(self.RarityMenu:GetAttribute("InventoryRarityEntryHeight")) or 0,
			allTextFits = self:_textFits(),
			insideSafeArea = self:_insideSafeArea(),
			noOverlap = self:_layoutHasNoOverlap(),
		},
		art = {
			mode = hasUploadedArt and "UploadedItemArt" or "NativeFallback",
			chromeMode = tostring(self.Root:GetAttribute("ArtMode") or "ReferenceNativeV3"),
			cardChromeMode = tostring(self.Root:GetAttribute("InventoryCardChromeMode") or ""),
			detailChromeMode = tostring(self.Root:GetAttribute("InventoryDetailChromeMode") or ""),
			emptyTreatment = tostring(self.Root:GetAttribute("InventoryEmptyTreatment") or "Hidden"),
			magentaFree = true,
			checkerboardFree = true,
		},
		accessibility = {
			actionContrastTarget = tonumber(self.Root:GetAttribute("InventoryActionContrastTarget")) or 4.5,
			minimumEnabledActionContrast = tonumber(
				self.Root:GetAttribute("InventoryMinimumEnabledActionContrast")
			) or 0,
			enabledActionContrastPass = self.Root:GetAttribute(
				"InventoryEnabledActionContrastPass"
			) == true,
			textGradientPolicy = tostring(
				self.Root:GetAttribute("InventoryTextGradientPolicy") or ""
			),
			auditedTextGradientControls = tonumber(
				self.Root:GetAttribute("InventoryAuditedTextGradientControlCount")
			) or 0,
			actionVisuals = actionVisuals,
		},
		performance = {
			diagnosticSnapshots = self._diagnosticSnapshotCount,
			diagnosticSnapshotSkips = self._diagnosticSnapshotSkipCount,
			gridRebuilds = self._gridRebuildCount,
			selectionVisualUpdates = self._selectionVisualUpdateCount,
			liveCards = #self._cards,
			activeCards = self._activeCardCount,
			pooledCards = math.max(0, #self._cards - self._activeCardCount),
			cardCreates = self._cardCreateCount,
			cardReuses = self._cardReuseCount,
			sparseSlots = self._activeSparseSlotCount,
			sparseSlotCreates = self._sparseSlotCreateCount,
			sparseSlotListeners = 0,
			sparseSlotsBounded = self._activeSparseSlotCount <= MAX_SPARSE_SLOT_PLACEHOLDERS,
			cardConnections = #self._cardConnections,
			cardConnectionBounded = #self._cardConnections <= (#self._cards * 3),
			actionControls = self._actionCreateCount,
			activeActions = #self._activeActionButtons,
			actionConnections = #self._actionConnections,
			actionCallbacks = self._actionCallbackCount,
			actionConnectionBounded = #self._actionConnections == self._actionCreateCount,
			detailRenders = self._detailRenderCount,
			detailRendersCoalesced = self._detailRenderCoalescedCount,
			timedRefreshMode = tostring(self.Root:GetAttribute("InventoryTimedRefreshMode") or "Stopped"),
			timedDetailUpdates = self._timedDetailUpdateCount,
			timedExpiryRebuilds = self._timedExpiryRebuildCount,
			deleteConfirmationScheduled = self.Root:GetAttribute("InventoryDeleteConfirmationScheduled") == true,
		},
	}
end

function InventoryUI:Destroy()
	self._destroyed = true
	self:_cancelPendingDetailRender()
	self:_cancelDeleteConfirmation(false)
	self:_stopTimedRefresh()
	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
	table.clear(self._connections)
	self:_clearCards()
	self:_disconnectPool(self._actionConnections)
	table.clear(self._actionButtonRefsByKey)
	table.clear(self._activeActionButtons)
	table.clear(self._actionModelsByKey)
	table.clear(self._cardRefsByKey)
	table.clear(self._sparseSlotPool)
	for _, master in pairs(self._petPreviewMasters) do
		if typeof(master) == "Instance" then master:Destroy() end
	end
	table.clear(self._petPreviewMasters)
	for _, master in pairs(self._fistPreviewMasters) do
		if typeof(master) == "Instance" then master:Destroy() end
	end
	table.clear(self._fistPreviewMasters)
	if self.Root then
		self.Root:Destroy()
	end
end

return InventoryUI
