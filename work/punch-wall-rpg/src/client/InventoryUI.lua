local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local InventoryViewModel = require(ReplicatedStorage:WaitForChild("InventoryViewModel"))

local InventoryUI = {}
InventoryUI.__index = InventoryUI

local CATEGORIES = { "All", "Fists", "Pets", "Boosts", "Honor" }
local RARITIES = { "All", "Common", "Rare", "Epic", "Legendary", "Secret", "Premium" }
local WIDE_CATEGORY_WIDTH = 172
local WIDE_CATEGORY_GAP = 10

local CATEGORY_ICONS = {
	All = "Menu",
	Fists = "StarterFist",
	Pets = "Pet",
	Boosts = "Power",
	Honor = "Success",
}

local PALETTE = {
	Backdrop = Color3.fromRGB(0, 5, 10),
	Ink = Color3.fromRGB(2, 9, 15),
	Panel = Color3.fromRGB(6, 17, 26),
	PanelSoft = Color3.fromRGB(10, 25, 36),
	PanelRaised = Color3.fromRGB(13, 31, 43),
	Card = Color3.fromRGB(5, 16, 24),
	CardHover = Color3.fromRGB(11, 32, 45),
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
	elseif remoteAction == "DeletePet" then
		return "Delete"
	elseif remoteAction == "BuyPremiumProduct" or remoteAction == "BuyShopBoost" then
		return "Use"
	end
	local providedName = tostring(action.name or "")
	local normalizedName = normalize(providedName)
	if normalizedName == "equip" or normalizedName == "unequip"
		or normalizedName == "lock" or normalizedName == "unlock"
		or normalizedName == "delete" or normalizedName == "use"
	then
		return providedName
	end
	return remoteAction ~= "" and remoteAction or providedName
end

local function actionEnabled(action)
	return type(action) == "table" and action.enabled ~= false
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

	self._connections = {}
	self._cardConnections = {}
	self._actionConnections = {}
	self._cards = {}
	self._cardRefsByKey = {}
	self._actionButtons = {}
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
	self._detailExpanded = false
	self._rarityMenuOpen = false
	self._updatingSearch = false
	self._lastTimedRefreshAt = 0
	self._hasTimedItem = false
	self._timerConnection = nil
	self._diagnosticSnapshotCount = 0
	self._diagnosticSnapshotSkipCount = 0
	self._gridRebuildCount = 0
	self._selectionVisualUpdateCount = 0
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
	self.Root:SetAttribute("InventoryLiveCardCount", 0)
	self.Root:SetAttribute("InventoryCardConnectionCount", 0)
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
	self.Root:SetAttribute("ArtMode", "NativeFallback")
	self.Root:SetAttribute("MagentaFree", true)
	self.Root:SetAttribute("CheckerboardFree", true)

	self.Backdrop = create("TextButton", self.Root, {
		Name = "InventoryBackdrop",
		AutoButtonColor = false,
		BackgroundColor3 = PALETTE.Backdrop,
		BackgroundTransparency = 0.16,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		ZIndex = 140,
	})
	create("UIGradient", self.Backdrop, {
		Color = ColorSequence.new(Color3.fromRGB(6, 22, 34), Color3.new(0, 0, 0)),
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.08),
			NumberSequenceKeypoint.new(1, 0.28),
		}),
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
	addCorner(self.Window, 6)
	self.WindowStroke = addStroke(self.Window, PALETTE.Cyan, 3)
	addGradient(self.Window, ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(14, 31, 42)),
		ColorSequenceKeypoint.new(0.45, PALETTE.Ink),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(3, 12, 20)),
	}), 90)

	self.WindowInnerFrame = create("Frame", self.Window, {
		Name = "InventoryWindowInnerFrame",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.new(1, -12, 1, -12),
		ZIndex = 143,
	})
	addCorner(self.WindowInnerFrame, 4)
	addStroke(self.WindowInnerFrame, PALETTE.SteelLight, 1, 0.28)

	self.WindowTopRail = create("Frame", self.Window, {
		Name = "InventoryWindowTopRail",
		BackgroundColor3 = PALETTE.Cyan,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(36, -2),
		Size = UDim2.new(1, -72, 0, 4),
		ZIndex = 144,
	})
	addGradient(self.WindowTopRail, ColorSequence.new({
		ColorSequenceKeypoint.new(0, PALETTE.CyanSoft),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(147, 241, 255)),
		ColorSequenceKeypoint.new(1, PALETTE.CyanSoft),
	}), 0)

	self.WindowBottomRail = create("Frame", self.Window, {
		Name = "InventoryWindowBottomRail",
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = PALETTE.Cyan,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 36, 1, 2),
		Size = UDim2.new(1, -72, 0, 4),
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
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.24,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(10, 12),
		Size = UDim2.new(1, -20, 0, 72),
		ZIndex = 143,
	})
	addCorner(self.HeaderShadow, 4)

	self.Header = create("Frame", self.Window, {
		Name = "InventoryHeader",
		BackgroundColor3 = PALETTE.Red,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.new(1, -16, 0, 72),
		ZIndex = 144,
	})
	addCorner(self.Header, 3)
	addStroke(self.Header, PALETTE.RedBright, 2)
	addGradient(self.Header, ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(101, 3, 10)),
		ColorSequenceKeypoint.new(0.24, Color3.fromRGB(223, 15, 16)),
		ColorSequenceKeypoint.new(0.69, Color3.fromRGB(169, 8, 13)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(47, 5, 10)),
	}), 7)

	create("Frame", self.Header, {
		Name = "HeaderTopHighlight",
		BackgroundColor3 = Color3.fromRGB(255, 81, 54),
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, 0, 0, 3),
		ZIndex = 145,
	})
	create("Frame", self.Header, {
		Name = "HeaderBottomRail",
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Color3.fromRGB(49, 3, 8),
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 7),
		ZIndex = 145,
	})
	create("Frame", self.Header, {
		Name = "HeaderGoldEdge",
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
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0.61, 0, 0, 7),
		Size = UDim2.new(0.28, 0, 1, -16),
		ZIndex = 145,
	})
	for row = 0, 2 do
		for column = 0, 7 do
			local diamond = create("Frame", self.HeaderPattern, {
				Name = string.format("HeaderPattern_%d_%d", row, column),
				BackgroundColor3 = Color3.fromRGB(48, 2, 8),
				BackgroundTransparency = 0.28 + row * 0.1,
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
		ZIndex = 145,
	})

	self.Title = create("TextLabel", self.Header, {
		Name = "InventoryTitle",
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		Position = UDim2.fromOffset(30, 5),
		Rotation = -1,
		Size = UDim2.new(0.57, -30, 1, -13),
		Text = "INVENTORY",
		TextColor3 = PALETTE.Text,
		TextScaled = true,
		TextStrokeColor3 = Color3.fromRGB(13, 2, 5),
		TextStrokeTransparency = 0,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 145,
	})
	addTextLimit(self.Title, 24, 46)

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
		ZIndex = 145,
	})
	addCorner(self.Capacity, 3)
	self.CapacityStroke = addStroke(self.Capacity, PALETTE.SteelLight, 1.5)
	addGradient(self.Capacity, ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(245, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(145, 185, 205)),
	}), 90)

	self.Close = create("TextButton", self.Header, {
		Name = "InventoryClose",
		AnchorPoint = Vector2.new(1, 0.5),
		AutoButtonColor = false,
		BackgroundColor3 = Color3.fromRGB(139, 8, 17),
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBlack,
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(50, 50),
		Text = "X",
		TextColor3 = PALETTE.Text,
		TextSize = 24,
		ZIndex = 146,
	})
	addCorner(self.Close, 4)
	addStroke(self.Close, Color3.fromRGB(255, 70, 50), 2.5)
	addGradient(self.Close, ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 225, 215)),
		ColorSequenceKeypoint.new(0.52, Color3.fromRGB(225, 165, 160)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 110, 120)),
	}), 90)
	create("Frame", self.Close, {
		Name = "CloseInnerEdge",
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
		Position = UDim2.fromOffset(8, 88),
		Size = UDim2.new(1, -16, 1, -96),
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
	addStroke(self.CategoryBar, PALETTE.SteelLight, 2)
	addGradient(self.CategoryBar, ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(10, 27, 39)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(3, 12, 19)),
	}), 90)
	self.CategoryPadding = create("UIPadding", self.CategoryBar, {
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		PaddingTop = UDim.new(0, 8),
	})
	self.CategoryLayout = create("UIListLayout", self.CategoryBar, {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 8),
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
			Size = UDim2.new(1, 0, 0, 62),
			Text = string.upper(category),
			TextColor3 = PALETTE.Text,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 145,
		})
		button:SetAttribute("InventoryCategory", category)
		addCorner(button, 3)
		local buttonStroke = addStroke(button, PALETTE.SteelLight, 1.5, 0.1)
		local buttonGradient = addGradient(button, ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(240, 252, 255)),
			ColorSequenceKeypoint.new(0.66, Color3.fromRGB(190, 220, 235)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(145, 185, 205)),
		}), 0)
		local padding = create("UIPadding", button, {
			PaddingLeft = UDim.new(0, 50),
			PaddingRight = UDim.new(0, 13),
		})
		local icon = create("ImageLabel", button, {
			Name = "CategoryIcon",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(-43, 9),
			Size = UDim2.fromOffset(42, 42),
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 146,
		})
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
		self:_applyAtlasIcon(icon, CATEGORY_ICONS[category])
		self._categoryButtons[category] = {
			button = button,
			stroke = buttonStroke,
			gradient = buttonGradient,
			padding = padding,
			icon = icon,
			indicator = indicator,
			arrow = arrow,
		}
		self:_connect(button.Activated, function()
			self:SetCategory(category, false)
		end)
	end

	self.GridPane = create("Frame", self.Body, {
		Name = "InventoryGridPane",
		BackgroundColor3 = PALETTE.Panel,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(WIDE_CATEGORY_WIDTH + WIDE_CATEGORY_GAP, 4),
		Size = UDim2.new(1, -(WIDE_CATEGORY_WIDTH + WIDE_CATEGORY_GAP + 316), 1, -8),
		ZIndex = 144,
	})
	addCorner(self.GridPane, 4)
	addStroke(self.GridPane, PALETTE.SteelLight, 2)
	addGradient(self.GridPane, ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(10, 27, 38)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(3, 12, 19)),
	}), 90)
	create("Frame", self.GridPane, {
		Name = "GridPaneTopRail",
		BackgroundColor3 = PALETTE.CyanSoft,
		BackgroundTransparency = 0.1,
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
	addStroke(self.Toolbar, PALETTE.Steel, 1, 0.15)

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
	addStroke(self.Search, PALETTE.SteelLight, 1.5)
	create("UIPadding", self.Search, {
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
		TextSize = 11,
		ZIndex = 148,
	})
	addCorner(self.RarityFilter, 3)
	addStroke(self.RarityFilter, PALETTE.CyanSoft, 1.5)
	addGradient(self.RarityFilter, ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(240, 252, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(145, 190, 215)),
	}), 90)

	self.Capacity.Parent = self.Toolbar
	self.Capacity.AnchorPoint = Vector2.new(1, 0)
	self.Capacity.Position = UDim2.fromScale(1, 0)
	self.Capacity.ZIndex = 148

	self.RarityMenu = create("Frame", self.GridPane, {
		Name = "RarityMenu",
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Color3.fromRGB(5, 14, 22),
		BorderSizePixel = 0,
		Position = UDim2.new(1, -8, 0, 56),
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
			TextSize = 11,
			ZIndex = 171,
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

	self.Empty = create("TextLabel", self.GridPane, {
		Name = "InventoryEmpty",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Position = UDim2.fromScale(0.5, 0.54),
		Size = UDim2.new(1, -48, 0, 80),
		Text = "NO ITEMS MATCH THIS FILTER",
		TextColor3 = PALETTE.Muted,
		TextSize = 14,
		TextWrapped = true,
		Visible = false,
		ZIndex = 146,
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
	self.DetailStroke = addStroke(self.Detail, PALETTE.Gold, 2)
	addGradient(self.Detail, ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(12, 27, 36)),
		ColorSequenceKeypoint.new(0.56, Color3.fromRGB(4, 14, 22)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(2, 9, 14)),
	}), 90)
	self.DetailTopRail = create("Frame", self.Detail, {
		Name = "DetailTopRail",
		BackgroundColor3 = PALETTE.Gold,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(6, 5),
		Size = UDim2.new(1, -12, 0, 3),
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
		BackgroundColor3 = PALETTE.RedDark,
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
	addCorner(self.DetailClose, 5)

	self.DetailArtFrame = create("Frame", self.Detail, {
		Name = "DetailArtFrame",
		BackgroundColor3 = Color3.fromRGB(3, 12, 20),
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(14, 14),
		Size = UDim2.new(1, -28, 0, 210),
		ZIndex = 151,
	})
	addCorner(self.DetailArtFrame, 3)
	self.DetailArtStroke = addStroke(self.DetailArtFrame, PALETTE.Gold, 2)
	addGradient(self.DetailArtFrame, ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(13, 29, 41)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(3, 12, 20)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 7, 2)),
	}), 90)
	self.DetailArtGlow = create("Frame", self.DetailArtFrame, {
		Name = "DetailArtGlow",
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
	addStroke(self.DetailRarity, Color3.fromRGB(255, 238, 127), 1, 0.12)
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
	addTextLimit(self.DetailName, 13, 21)
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
		BackgroundTransparency = 1,
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
	end)
	self:_connect(self.RarityFilter.Activated, function()
		self:_setRarityMenu(not self._rarityMenuOpen)
	end)
	self:_connect(self.Search:GetPropertyChangedSignal("Text"), function()
		if not self._updatingSearch then
			self:SetSearch(self.Search.Text, false)
		end
	end)
	self:_connect(self.Root:GetPropertyChangedSignal("AbsoluteSize"), function()
		local size = self.Root.AbsoluteSize
		if size.X > 0 and size.Y > 0 then
			self:ApplyResponsive(size, size.X < 900 or size.Y < 520, self._layout.uiScale)
		end
	end)
	self:_connect(self.Root:GetPropertyChangedSignal("Visible"), function()
		self:_syncTimedRefresh()
	end)
end

function InventoryUI:_stopTimedRefresh()
	if self._timerConnection then
		self._timerConnection:Disconnect()
		self._timerConnection = nil
	end
end

function InventoryUI:_syncTimedRefresh()
	if not self.Root or not self.Root.Visible or not self._snapshot or not self._hasTimedItem then
		self:_stopTimedRefresh()
		return
	end
	if self._timerConnection then
		return
	end
	self._lastTimedRefreshAt = workspace:GetServerTimeNow()
	self._timerConnection = RunService.Heartbeat:Connect(function()
		if not self.Root or not self.Root.Visible or not self._hasTimedItem then
			self:_stopTimedRefresh()
			return
		end
		local now = workspace:GetServerTimeNow()
		if math.floor(now) <= math.floor(self._lastTimedRefreshAt) then
			return
		end
		self._lastTimedRefreshAt = now
		self._snapshot = self:_buildSnapshot(self:_getStats())
		self._hasTimedItem = hasTimedItem(self._snapshot)
		self:_applyFilter(false)
		self:ApplyResponsive(self._layout.viewport, self._layout.compact, self._layout.uiScale)
		if not self._hasTimedItem then
			self:_stopTimedRefresh()
		end
	end)
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
	self._rarityMenuOpen = visible == true
	self.RarityMenu.Visible = self._rarityMenuOpen
	self.RarityFilter.Text = "RARITY  " .. string.upper(self._rarity) .. (self._rarityMenuOpen and "  ^" or "  v")
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
	self.Capacity.Text = string.format(
		"ITEMS %s  |  PETS %s/%s",
		formatNumber(itemCount),
		formatNumber(used),
		formatNumber(maximum)
	)
	self.Capacity:SetAttribute("Used", used)
	self.Capacity:SetAttribute("Maximum", maximum)
end

function InventoryUI:_renderCategories()
	for category, widgets in pairs(self._categoryButtons) do
		local selected = category == self._category
		widgets.button.BackgroundColor3 = selected and Color3.fromRGB(34, 36, 28) or PALETTE.PanelRaised
		widgets.button.TextColor3 = selected and PALETTE.Gold or PALETTE.Text
		widgets.stroke.Color = selected and PALETTE.Gold or PALETTE.SteelLight
		widgets.stroke.Thickness = selected and 2.5 or 1.5
		widgets.gradient.Color = selected and ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 248, 205)),
			ColorSequenceKeypoint.new(0.58, Color3.fromRGB(220, 205, 140)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(175, 150, 85)),
		}) or ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(240, 252, 255)),
			ColorSequenceKeypoint.new(0.66, Color3.fromRGB(190, 220, 235)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(145, 185, 205)),
		})
		widgets.indicator.Visible = selected
		widgets.arrow.Visible = selected and not self._layout.compact
	end
	for rarity, button in pairs(self._rarityButtons) do
		button.BackgroundTransparency = rarity == self._rarity and 0 or 1
		button.BackgroundColor3 = rarity == self._rarity and Color3.fromRGB(27, 45, 57) or PALETTE.PanelSoft
	end
	self:_setRarityMenu(self._rarityMenuOpen)
end

function InventoryUI:_clearCards()
	self:_disconnectPool(self._cardConnections)
	table.clear(self._cardRefsByKey)
	for _, card in ipairs(self._cards) do
		card:Destroy()
	end
	table.clear(self._cards)
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
				stroke.Color = PALETTE.Gold
				stroke.Thickness = 3
			elseif ref.hovered then
				card.BackgroundColor3 = PALETTE.CardHover
				stroke.Color = ref.accent
				stroke.Thickness = 2
			else
				card.BackgroundColor3 = PALETTE.Card
				stroke.Color = ref.accent
				stroke.Thickness = 1.5
			end
			updated = updated + 1
		end
	end
	return updated
end

function InventoryUI:_renderGrid()
	self._gridRebuildCount = self._gridRebuildCount + 1
	self:_clearCards()
	self.Empty.Visible = #self._visibleItems == 0
	for index, item in ipairs(self._visibleItems) do
		local key = tostring(item.key or ("item:" .. index))
		local accent = itemAccent(item)
		local selected = key == self._selectedKey
		local card = create("TextButton", self.Grid, {
			Name = "ItemCard_" .. safeName(key),
			AutoButtonColor = false,
			BackgroundColor3 = selected and PALETTE.CardHover or PALETTE.Card,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			LayoutOrder = index,
			Text = "",
			ZIndex = 146,
		})
		card:SetAttribute("InventoryKey", key)
		card:SetAttribute("InventoryCategory", tostring(item.category or ""))
		card:SetAttribute("InventoryRarity", tostring(item.rarity or "Common"))
		card:SetAttribute("InventoryEquipped", item.equipped == true)
		card:SetAttribute("InventoryLocked", item.locked == true)
		addCorner(card, 3)
		local cardStroke = addStroke(card, selected and PALETTE.Gold or accent, selected and 3 or 1.5)
		local cardRef = {
			card = card,
			stroke = cardStroke,
			accent = accent,
			hovered = false,
		}
		local keyedRefs = self._cardRefsByKey[key]
		if not keyedRefs then
			keyedRefs = {}
			self._cardRefsByKey[key] = keyedRefs
		end
		table.insert(keyedRefs, cardRef)
		addGradient(card, ColorSequence.new({
			ColorSequenceKeypoint.new(0, accent:Lerp(Color3.fromRGB(7, 20, 29), 0.82)),
			ColorSequenceKeypoint.new(0.4, Color3.fromRGB(5, 17, 26)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(2, 9, 14)),
		}), 90)

		local innerFrame = create("Frame", card, {
			Name = "CardInnerFrame",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(4, 4),
			Size = UDim2.new(1, -8, 1, -8),
			ZIndex = 147,
		})
		addCorner(innerFrame, 2)
		addStroke(innerFrame, accent, 1, 0.62)

		local accentBar = create("Frame", card, {
			Name = "RarityAccent",
			BackgroundColor3 = accent,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.new(1, 0, 0, 3),
			ZIndex = 147,
		})
		addGradient(accentBar, ColorSequence.new({
			ColorSequenceKeypoint.new(0, accent:Lerp(Color3.new(1, 1, 1), 0.15)),
			ColorSequenceKeypoint.new(0.5, accent),
			ColorSequenceKeypoint.new(1, accent:Lerp(Color3.new(0, 0, 0), 0.28)),
		}), 0)

		local artFrame = create("Frame", card, {
			Name = "ItemArtFrame",
			BackgroundColor3 = Color3.fromRGB(2, 10, 16),
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(6, 7),
			Size = UDim2.new(1, -12, 1, -43),
			ZIndex = 147,
		})
		addCorner(artFrame, 2)
		addStroke(artFrame, PALETTE.Steel, 1, 0.18)
		addGradient(artFrame, ColorSequence.new({
			ColorSequenceKeypoint.new(0, accent:Lerp(Color3.fromRGB(5, 14, 21), 0.88)),
			ColorSequenceKeypoint.new(0.55, Color3.fromRGB(3, 12, 19)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(1, 7, 11)),
		}), 90)
		local art = create("ImageLabel", artFrame, {
			Name = "ItemArt",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(3, 3),
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.new(1, -6, 1, -6),
			ZIndex = 148,
		})
		local artMode = self:_applyItemArt(art, item)
		card:SetAttribute("ArtMode", artMode)

		local rarity = create("TextLabel", card, {
			Name = "ItemRarity",
			BackgroundColor3 = accent,
			BackgroundTransparency = 0.02,
			BorderSizePixel = 0,
			Font = Enum.Font.GothamBlack,
			Position = UDim2.fromOffset(7, 9),
			Size = UDim2.new(0.62, -7, 0, 18),
			Text = string.upper(tostring(item.rarity or "Common")),
			TextColor3 = contrastText(accent),
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
			BackgroundTransparency = 0.04,
			BorderSizePixel = 0,
			Font = Enum.Font.GothamBlack,
			Position = UDim2.new(0, 6, 1, -35),
			Size = UDim2.new(1, -12, 0, 29),
			Text = tostring(item.displayName or item.name or "Unknown Item"),
			TextColor3 = PALETTE.Text,
			TextScaled = true,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextWrapped = true,
			ZIndex = 149,
		})
		addTextLimit(name, 8, 12)

		if (tonumber(item.quantity) or 1) > 1 then
			local quantity = create("TextLabel", card, {
				Name = "ItemQuantity",
				AnchorPoint = Vector2.new(1, 0),
				BackgroundColor3 = Color3.fromRGB(2, 8, 13),
				BackgroundTransparency = 0.02,
				BorderSizePixel = 0,
				Font = Enum.Font.GothamBlack,
				Position = UDim2.new(1, -7, 0, 9),
				Size = UDim2.fromOffset(38, 22),
				Text = "x" .. formatNumber(item.quantity),
				TextColor3 = PALETTE.Text,
				TextSize = 11,
				ZIndex = 151,
			})
			addCorner(quantity, 2)
			addStroke(quantity, accent, 1, 0.25)
		end

		if item.equipped == true then
			local equipped = create("TextLabel", card, {
				Name = "EquippedBadge",
				BackgroundColor3 = PALETTE.Green,
				BorderSizePixel = 0,
				Font = Enum.Font.GothamBlack,
				Position = UDim2.fromOffset(8, 32),
				Size = UDim2.fromOffset(62, 20),
				Text = "EQUIPPED",
				TextColor3 = Color3.fromRGB(4, 20, 8),
				TextSize = 8,
				ZIndex = 151,
			})
			addCorner(equipped, 2)
			addStroke(equipped, Color3.fromRGB(173, 255, 138), 1, 0.28)
		end

		if item.locked == true then
			local locked = create("TextLabel", card, {
				Name = "LockedBadge",
				AnchorPoint = Vector2.new(1, 0),
				BackgroundColor3 = PALETTE.RedDark,
				BorderSizePixel = 0,
				Font = Enum.Font.GothamBlack,
				Position = UDim2.new(1, -8, 0, 34),
				Size = UDim2.fromOffset(48, 20),
				Text = "LOCKED",
				TextColor3 = PALETTE.Text,
				TextSize = 8,
				ZIndex = 151,
			})
			addCorner(locked, 2)
			addStroke(locked, Color3.fromRGB(255, 105, 83), 1, 0.18)
		end

		self:_connectScoped(self._cardConnections, card.MouseEnter, function()
			cardRef.hovered = true
			self:_applyCardSelectionVisual(key, key == self._selectedKey)
		end)
		self:_connectScoped(self._cardConnections, card.MouseLeave, function()
			cardRef.hovered = false
			self:_applyCardSelectionVisual(key, key == self._selectedKey)
		end)
		self:_connectScoped(self._cardConnections, card.Activated, function()
			self:SelectItem(key, false)
		end)
		table.insert(self._cards, card)
	end
	self.Root:SetAttribute("InventoryGridRebuildCount", self._gridRebuildCount)
	self.Root:SetAttribute("InventoryLiveCardCount", #self._cards)
	self.Root:SetAttribute("InventoryCardConnectionCount", #self._cardConnections)
end

function InventoryUI:_clearActionButtons()
	self:_disconnectPool(self._actionConnections)
	for _, button in ipairs(self._actionButtons) do
		button:Destroy()
	end
	table.clear(self._actionButtons)
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
		self.DetailArt.Image = ""
		self.DetailArtGlow.BackgroundColor3 = PALETTE.Cyan
		self.DetailStroke.Color = PALETTE.CyanSoft
		self.DetailArtStroke.Color = PALETTE.CyanSoft
		for _, widgets in ipairs(self.DetailStatRows) do
			widgets.value.Text = "--"
			widgets.value.TextColor3 = PALETTE.Muted
			widgets.marker.BackgroundColor3 = PALETTE.SteelLight
		end
		self:_syncDetailVisibility()
		return
	end

	local accent = itemAccent(item)
	local displayName = tostring(item.displayName or item.name or "Unknown Item")
	local rarityName = tostring(item.rarity or "Common")
	local categoryName = tostring(item.category or item.kind or "Item")
	self.DetailRarity.Text = string.upper(rarityName)
	self.DetailRarity.BackgroundColor3 = accent
	self.DetailRarity.TextColor3 = contrastText(accent)
	self.DetailCategoryTag.Text = string.upper(categoryName)
	self.DetailCategoryTag.TextColor3 = PALETTE.Green
	self.DetailCategoryTag.BackgroundColor3 = Color3.fromRGB(6, 31, 20)
	self.DetailName.Text = string.upper(displayName)
	self.DetailInternalName.Text = item.slot
		and ("OWNED ITEM  //  SLOT " .. tostring(item.slot))
		or "OWNED ITEM  //  SERVER VERIFIED"
	self.DetailDescription.Text = tostring(item.description or item.detail or "No additional item details.")
	self.DetailStroke.Color = accent
	self.DetailArtStroke.Color = accent
	self.DetailArtGlow.BackgroundColor3 = accent
	self:_applyItemArt(self.DetailArt, item)

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
	if #statusParts == 0 then
		table.insert(statusParts, item.viewOnly == true and "VIEW ONLY" or "AVAILABLE")
	end
	self.DetailStatus.Text = table.concat(statusParts, "  |  ")
	self.DetailStatus.TextColor3 = item.locked == true and PALETTE.Gold or item.equipped == true and PALETTE.Green or PALETTE.Cyan
	local stateName = item.locked == true and "LOCKED"
		or item.equipped == true and "EQUIPPED"
		or item.viewOnly == true and "VIEW ONLY"
		or "AVAILABLE"
	local statValues = { string.upper(rarityName), string.upper(categoryName), stateName }
	local statColors = { accent, PALETTE.Cyan, item.locked == true and PALETTE.Gold or item.equipped == true and PALETTE.Green or PALETTE.Cyan }
	for index, widgets in ipairs(self.DetailStatRows) do
		widgets.value.Text = statValues[index]
		widgets.value.TextColor3 = statColors[index]
		widgets.marker.BackgroundColor3 = statColors[index]
	end

	local enabledCount = 0
	for order, action in ipairs(itemActions(item)) do
		if actionEnabled(action) then
			enabledCount = enabledCount + 1
			local semanticName = actionName(action)
			local destructive = action.destructive == true or action.confirm == true or normalize(semanticName) == "delete"
			local awaitingConfirmation = destructive
				and self._deleteConfirmKey == tostring(item.key)
				and os.clock() <= self._deleteConfirmUntil
			local buttonColor = destructive and PALETTE.Danger or asColor(action.accent, order == 1 and PALETTE.Green or PALETTE.CyanSoft)
			local label = awaitingConfirmation and "CONFIRM DELETE" or tostring(action.label or semanticName)
			local button = create("TextButton", self.DetailActions, {
				Name = "Action" .. safeName(semanticName),
				AutoButtonColor = false,
				BackgroundColor3 = buttonColor,
				BorderSizePixel = 0,
				Font = Enum.Font.GothamBlack,
				LayoutOrder = action.primary == true and 0 or order,
				Size = UDim2.new(1, 0, 0, 44),
				Text = string.upper(label),
				TextColor3 = PALETTE.Text,
				TextSize = 12,
				ZIndex = 153,
			})
			button:SetAttribute("InventoryAction", semanticName)
			button:SetAttribute("Destructive", destructive)
			addCorner(button, 3)
			addStroke(button, destructive and Color3.fromRGB(255, 113, 83) or Color3.fromRGB(155, 236, 255), 1.5, 0.15)
			addGradient(button, ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
				ColorSequenceKeypoint.new(0.52, Color3.fromRGB(215, 235, 245)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 185, 205)),
			}), 90)
			self:_connectScoped(self._actionConnections, button.Activated, function()
				self:InvokeAction(semanticName)
			end)
			table.insert(self._actionButtons, button)
		end
	end

	if enabledCount == 0 then
		local label = create("TextLabel", self.DetailActions, {
			Name = "ActionViewOnly",
			BackgroundColor3 = PALETTE.Disabled,
			BorderSizePixel = 0,
			Font = Enum.Font.GothamBlack,
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, 44),
			Text = "VIEW ONLY",
			TextColor3 = PALETTE.Muted,
			TextSize = 11,
			ZIndex = 153,
		})
		addCorner(label, 3)
		addStroke(label, PALETTE.SteelLight, 1.5, 0.25)
		table.insert(self._actionButtons, label)
	end
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

function InventoryUI:_applyFilter(resetDrawer)
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
	self:_renderDetail()
	self.Root:SetAttribute("InventoryCategory", self._category)
	self.Root:SetAttribute("InventorySearch", self._search)
	self.Root:SetAttribute("InventoryRarity", self._rarity)
	self.Root:SetAttribute("InventoryVisibleCount", #self._visibleItems)
	self.Root:SetAttribute("InventorySelectedKey", self._selectedKey or "")
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
		self._deleteConfirmKey = nil
		self._deleteConfirmUntil = 0
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

function InventoryUI:SetCategory(name, includeDiagnostics)
	local requested = normalize(name)
	for _, category in ipairs(CATEGORIES) do
		if normalize(category) == requested then
			self._category = category
			self._deleteConfirmKey = nil
			self._deleteConfirmUntil = 0
			self:_applyFilter(true)
			self:ApplyResponsive(self._layout.viewport, self._layout.compact, self._layout.uiScale)
			return self:_snapshotResult(includeDiagnostics)
		end
	end
	return self:_snapshotResult(includeDiagnostics)
end

function InventoryUI:SetSearch(text, includeDiagnostics)
	self._search = tostring(text or "")
	if self.Search.Text ~= self._search then
		self._updatingSearch = true
		self.Search.Text = self._search
		self._updatingSearch = false
	end
	self._deleteConfirmKey = nil
	self._deleteConfirmUntil = 0
	self:_applyFilter(true)
	self:ApplyResponsive(self._layout.viewport, self._layout.compact, self._layout.uiScale)
	return self:_snapshotResult(includeDiagnostics)
end

function InventoryUI:SetRarity(name, includeDiagnostics)
	local requested = normalize(name)
	for _, rarity in ipairs(RARITIES) do
		if normalize(rarity) == requested then
			self._rarity = rarity
			self._deleteConfirmKey = nil
			self._deleteConfirmUntil = 0
			self:_applyFilter(true)
			self:ApplyResponsive(self._layout.viewport, self._layout.compact, self._layout.uiScale)
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
	local previousKey = self._selectedKey
	self._selectedKey = tostring(item.key)
	self._selectedItem = item
	self._deleteConfirmKey = nil
	self._deleteConfirmUntil = 0
	self._detailExpanded = true
	if tostring(previousKey or "") ~= self._selectedKey then
		self:_applyCardSelectionVisual(previousKey, false)
		self:_applyCardSelectionVisual(self._selectedKey, true)
		self._selectionVisualUpdateCount = self._selectionVisualUpdateCount + 1
		self.Root:SetAttribute("InventorySelectionVisualUpdateCount", self._selectionVisualUpdateCount)
	end
	self:_renderDetail()
	self:ApplyResponsive(self._layout.viewport, self._layout.compact, self._layout.uiScale)
	self.Root:SetAttribute("InventorySelectedKey", self._selectedKey)
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
			self._deleteConfirmKey = key
			self._deleteConfirmUntil = now + 3
			self:_renderDetail()
			return false, "confirmation_required"
		end
		self._deleteConfirmKey = nil
		self._deleteConfirmUntil = 0
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
	self:_renderDetail()
	return true
end

function InventoryUI:ApplyResponsive(viewport, compact, uiScale)
	if typeof(viewport) ~= "Vector2" or viewport.X < 1 or viewport.Y < 1 then
		viewport = self.Root.AbsoluteSize
	end
	if viewport.X < 1 or viewport.Y < 1 then
		viewport = Vector2.new(1280, 720)
	end
	local scale = math.clamp(tonumber(uiScale) or 1, 0.75, 1.15)
	local availableWidth = viewport.X / scale
	local availableHeight = viewport.Y / scale
	local useCompact = compact == true or viewport.X < 900 or viewport.Y < 520
	local touchTarget = math.ceil(44 / math.min(scale, 1))
	local headerHeight = useCompact and math.max(60, touchTarget + 12) or math.max(80, touchTarget + 24)
	local windowWidth = useCompact and math.max(480, availableWidth - 12)
		or math.min(1180, availableWidth - 32)
	local windowHeight = useCompact and math.max(300, availableHeight - 12) or math.min(720, availableHeight - 28)
	windowWidth = math.max(480, windowWidth)
	windowHeight = math.max(300, windowHeight)

	self._layout.viewport = viewport
	self._layout.compact = useCompact
	self._layout.uiScale = scale
	self._layout.detailMode = useCompact and "Drawer" or "Pane"
	self.WindowScale.Scale = scale
	self.Window.Size = UDim2.fromOffset(windowWidth, windowHeight)
	self.WindowShadow.Size = UDim2.fromOffset(windowWidth * scale, windowHeight * scale)
	self.Header.Size = UDim2.new(1, -16, 0, headerHeight)
	self.HeaderShadow.Size = UDim2.new(1, -20, 0, headerHeight)
	local bodyTop = headerHeight + 16
	self.Body.Position = UDim2.fromOffset(8, bodyTop)
	self.Body.Size = UDim2.new(1, -16, 1, -(bodyTop + 8))
	self.Subtitle.Visible = false
	local titleLeft = useCompact and 20 or 30
	self.Title.Position = UDim2.fromOffset(titleLeft, 5)
	self.Title.Size = UDim2.new(1, -(titleLeft + math.max(touchTarget, useCompact and 44 or 50) + 30), 1, -13)
	self.HeaderPattern.Visible = not useCompact
	self.HeaderSlash.Visible = not useCompact
	self.Close.Size = UDim2.fromOffset(math.max(touchTarget, useCompact and 44 or 50), math.max(touchTarget, useCompact and 44 or 50))

	local bodyWidth = windowWidth - 16
	local bodyHeight = windowHeight - bodyTop - 8
	local toolbarHeight = touchTarget
	local capacityWidth = useCompact and 150 or 172
	local rarityWidth = useCompact and 132 or 142
	local toolbarGap = 8
	self.Toolbar.Size = UDim2.new(1, -16, 0, toolbarHeight)
	self.Search.Size = UDim2.new(1, -(capacityWidth + rarityWidth + toolbarGap * 2), 0, toolbarHeight)
	self.SearchGlyph.Size = UDim2.fromOffset(20, toolbarHeight)
	self.RarityFilter.Position = UDim2.new(1, -(capacityWidth + toolbarGap), 0, 0)
	self.RarityFilter.Size = UDim2.fromOffset(rarityWidth, toolbarHeight)
	self.Capacity.Position = UDim2.fromScale(1, 0)
	self.Capacity.Size = UDim2.fromOffset(capacityWidth, toolbarHeight)
	self.Capacity.TextSize = useCompact and 9 or 10
	self.RarityMenu.Position = UDim2.new(1, -(8 + capacityWidth + toolbarGap), 0, toolbarHeight + 12)
	self.RarityMenu.Size = UDim2.fromOffset(rarityWidth, #RARITIES * touchTarget + 12)
	for _, button in pairs(self._rarityButtons) do
		button.Size = UDim2.new(1, 0, 0, touchTarget)
	end
	local gridTop = toolbarHeight + 16
	self.Grid.Position = UDim2.fromOffset(8, gridTop)
	self.Grid.Size = UDim2.new(1, -16, 1, -(gridTop + 8))
	if useCompact then
		local shortCompact = bodyHeight < 330
		self.CategoryBar.Position = UDim2.fromOffset(4, 4)
		self.CategoryBar.Size = UDim2.new(1, -8, 0, touchTarget + 8)
		self.CategoryPadding.PaddingTop = UDim.new(0, 4)
		self.CategoryPadding.PaddingBottom = UDim.new(0, 4)
		self.CategoryPadding.PaddingLeft = UDim.new(0, 4)
		self.CategoryPadding.PaddingRight = UDim.new(0, 4)
		self.CategoryLayout.FillDirection = Enum.FillDirection.Horizontal
		self.CategoryLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		self.CategoryLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		self.CategoryLayout.Padding = UDim.new(0, 5)
		local categoryWidth = math.max(78, math.floor((bodyWidth - 8 - 16 - 20) / #CATEGORIES))
		for _, category in ipairs(CATEGORIES) do
			local widgets = self._categoryButtons[category]
			widgets.button.Size = UDim2.fromOffset(categoryWidth, touchTarget)
			widgets.button.TextSize = 9
			widgets.padding.PaddingLeft = UDim.new(0, 28)
			widgets.padding.PaddingRight = UDim.new(0, 4)
			widgets.icon.Position = UDim2.fromOffset(-25, 8)
			widgets.icon.Size = UDim2.fromOffset(24, 24)
			widgets.indicator.Position = UDim2.fromOffset(-28, 4)
			widgets.indicator.Size = UDim2.new(0, 3, 1, -8)
			widgets.arrow.Visible = false
		end

		local categoryHeight = touchTarget + 8
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

		if shortCompact then
			self.DetailArtFrame.Position = UDim2.fromOffset(12, 14)
			self.DetailArtFrame.Size = UDim2.fromOffset(76, math.max(80, drawerHeight - 28))
			self.DetailRarity.Position = UDim2.fromOffset(98, 10)
			self.DetailRarity.Size = UDim2.fromOffset(92, 17)
			self.DetailRarity.TextSize = 8
			self.DetailCategoryTag.Visible = false
			self.DetailName.Position = UDim2.fromOffset(98, 29)
			self.DetailName.Size = UDim2.new(0.48, -106, 0, 30)
			self.DetailInternalName.Position = UDim2.fromOffset(98, 60)
			self.DetailInternalName.Size = UDim2.new(0.48, -106, 0, 14)
			self.DetailDescription.Visible = false
			self.DetailStatus.Position = UDim2.fromOffset(98, math.max(74, drawerHeight - 42))
			self.DetailStatus.Size = UDim2.new(0.48, -106, 0, 32)
			self.DetailActions.Position = UDim2.new(0.58, 0, 1, -(touchTarget + 8))
			self.DetailActions.Size = UDim2.new(0.42, -(touchTarget + 14), 0, touchTarget)
		else
			self.DetailArtFrame.Position = UDim2.fromOffset(12, 18)
			self.DetailArtFrame.Size = UDim2.fromOffset(118, math.max(112, drawerHeight - 30))
			self.DetailRarity.Position = UDim2.fromOffset(142, 15)
			self.DetailRarity.Size = UDim2.fromOffset(100, 19)
			self.DetailRarity.TextSize = 9
			self.DetailCategoryTag.AnchorPoint = Vector2.new(0, 0)
			self.DetailCategoryTag.Position = UDim2.fromOffset(250, 15)
			self.DetailCategoryTag.Size = UDim2.fromOffset(92, 19)
			self.DetailCategoryTag.Visible = true
			self.DetailName.Position = UDim2.fromOffset(142, 38)
			self.DetailName.Size = UDim2.new(1, -202, 0, 34)
			self.DetailInternalName.Position = UDim2.fromOffset(142, 73)
			self.DetailInternalName.Size = UDim2.new(1, -202, 0, 16)
			self.DetailDescription.Visible = true
			self.DetailDescription.Position = UDim2.fromOffset(142, 93)
			self.DetailDescription.Size = UDim2.new(0.47, -28, 1, -103)
			self.DetailDescription.TextSize = 10
			self.DetailStatus.Position = UDim2.new(0.56, 0, 0, 62)
			self.DetailStatus.Size = UDim2.new(0.44, -14, 0, 34)
			self.DetailActions.Position = UDim2.new(0.56, 0, 0, 102)
			self.DetailActions.Size = UDim2.new(0.44, -14, 1, -112)
		end
		self.DetailActionLayout.FillDirection = Enum.FillDirection.Horizontal
		self.DetailActionLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
		self.DetailActionLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		local actionCount = math.max(1, #self._actionButtons)
		local actionColumns = math.min(3, actionCount)
		local detailPanelWidth = bodyWidth - 8
		local actionPanelWidth = shortCompact
			and (detailPanelWidth * 0.42 - touchTarget - 14)
			or (detailPanelWidth * 0.44 - 14)
		local actionWidth = math.max(touchTarget, math.floor((actionPanelWidth - (actionColumns - 1) * 6) / actionColumns))
		self.DetailActionLayout.FillDirectionMaxCells = actionColumns
		self.DetailActionLayout.CellPadding = UDim2.fromOffset(6, 6)
		self.DetailActionLayout.CellSize = UDim2.fromOffset(actionWidth, touchTarget)
		for _, button in ipairs(self._actionButtons) do
			if button:IsA("TextButton") or button:IsA("TextLabel") then
				button.TextSize = actionWidth < 84 and 9 or 11
			end
		end
	else
		self.DetailDescription.Visible = true
		self.GridPane.Visible = true
		self.Toolbar.Visible = true
		self.Grid.Visible = true
		self.CategoryBar.Position = UDim2.fromOffset(-(WIDE_CATEGORY_WIDTH + WIDE_CATEGORY_GAP), 4)
		self.CategoryBar.Size = UDim2.fromOffset(WIDE_CATEGORY_WIDTH, bodyHeight - 8)
		self.CategoryPadding.PaddingTop = UDim.new(0, 8)
		self.CategoryPadding.PaddingBottom = UDim.new(0, 8)
		self.CategoryPadding.PaddingLeft = UDim.new(0, 8)
		self.CategoryPadding.PaddingRight = UDim.new(0, 8)
		self.CategoryLayout.FillDirection = Enum.FillDirection.Vertical
		self.CategoryLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		self.CategoryLayout.VerticalAlignment = Enum.VerticalAlignment.Top
		self.CategoryLayout.Padding = UDim.new(0, 8)
		for _, category in ipairs(CATEGORIES) do
			local widgets = self._categoryButtons[category]
			widgets.button.Size = UDim2.new(1, 0, 0, math.max(62, touchTarget))
			widgets.button.TextSize = 13
			widgets.padding.PaddingLeft = UDim.new(0, 50)
			widgets.padding.PaddingRight = UDim.new(0, 13)
			widgets.icon.Position = UDim2.fromOffset(-43, 10)
			widgets.icon.Size = UDim2.fromOffset(42, 42)
			widgets.indicator.Position = UDim2.fromOffset(-50, 5)
			widgets.indicator.Size = UDim2.new(0, 4, 1, -10)
			widgets.arrow.Visible = category == self._category
		end

		local detailWidth = math.clamp(windowWidth * 0.275, 270, 310)
		local gridX = 4
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
		self.DetailRarity.TextSize = 10
		self.DetailCategoryTag.AnchorPoint = Vector2.new(1, 0)
		self.DetailCategoryTag.Position = UDim2.new(1, -14, 0, 16)
		self.DetailCategoryTag.Size = UDim2.fromOffset(98, 22)
		self.DetailCategoryTag.Visible = true
		self.DetailName.Position = UDim2.fromOffset(14, 43)
		self.DetailName.Size = UDim2.new(1, -28, 0, 36)
		self.DetailInternalName.Position = UDim2.fromOffset(14, 79)
		self.DetailInternalName.Size = UDim2.new(1, -28, 0, 16)

		local artY = 102
		local artHeight = math.clamp(detailHeight * 0.28, 132, 174)
		self.DetailArtFrame.Position = UDim2.fromOffset(14, artY)
		self.DetailArtFrame.Size = UDim2.new(1, -28, 0, artHeight)
		local artBottom = artY + artHeight
		local actionRows = math.ceil(math.max(1, #self._actionButtons) / 2)
		local actionAreaHeight = actionRows * touchTarget + math.max(0, actionRows - 1) * 6
		local statusY = detailHeight - actionAreaHeight - 58
		local statsHeight = 86
		local statsY = statusY - statsHeight - 8
		local descriptionY = artBottom + 10
		local showStats = detailHeight >= 540 and statsY >= descriptionY + 46
		local descriptionBottom = showStats and statsY - 8 or statusY - 8
		self.DetailDescription.Position = UDim2.fromOffset(16, descriptionY)
		self.DetailDescription.Size = UDim2.new(1, -32, 0, math.max(42, descriptionBottom - descriptionY))
		self.DetailDescription.TextSize = 11
		self.DetailStats.Visible = showStats
		self.DetailStats.Position = UDim2.fromOffset(14, statsY)
		self.DetailStats.Size = UDim2.new(1, -28, 0, statsHeight)
		self.DetailStatus.Position = UDim2.fromOffset(14, statusY)
		self.DetailStatus.Size = UDim2.new(1, -28, 0, 42)
		self.DetailActions.Position = UDim2.fromOffset(14, statusY + 50)
		self.DetailActions.Size = UDim2.new(1, -28, 0, actionAreaHeight)
		self.DetailActionLayout.FillDirection = Enum.FillDirection.Horizontal
		self.DetailActionLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		self.DetailActionLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
		local actionColumns = math.min(2, math.max(1, #self._actionButtons))
		local actionWidth = math.floor((detailWidth - 28 - math.max(0, actionColumns - 1) * 6) / actionColumns)
		self.DetailActionLayout.FillDirectionMaxCells = actionColumns
		self.DetailActionLayout.CellPadding = UDim2.fromOffset(6, 6)
		self.DetailActionLayout.CellSize = UDim2.fromOffset(actionWidth, touchTarget)
		for _, button in ipairs(self._actionButtons) do
			if button:IsA("TextButton") or button:IsA("TextLabel") then
				button.TextSize = 12
			end
		end
	end

	local gridPaneWidth = useCompact and bodyWidth - 8
		or bodyWidth - 4 - math.clamp(windowWidth * 0.275, 270, 310) - 12
	local gridContentWidth = math.max(280, gridPaneWidth - 24)
	local columns
	if gridContentWidth >= 600 then
		columns = 5
	elseif gridContentWidth >= 555 then
		columns = 4
	elseif gridContentWidth >= 390 then
		columns = 3
	else
		columns = 2
	end
	local padding = 8
	local cellWidth = math.max(92, math.floor((gridContentWidth - (columns - 1) * padding) / columns))
	local cellHeight = useCompact and math.max(112, math.min(132, cellWidth * 0.9))
		or math.max(132, math.min(154, cellWidth))
	self._layout.columns = columns
	self.GridLayout.FillDirectionMaxCells = columns
	self.GridLayout.CellPadding = UDim2.fromOffset(padding, padding)
	self.GridLayout.CellSize = UDim2.fromOffset(cellWidth, cellHeight)
	self.Root:SetAttribute("InventoryCompact", useCompact)
	self.Root:SetAttribute("InventoryColumns", columns)
	self.Root:SetAttribute("InventoryMinimumTouchTarget", touchTarget * scale)
	self.Root:SetAttribute("InventoryDetailMode", self._layout.detailMode)
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
			minTouchTarget = self:_minimumTouchTarget(),
			detailMode = self._layout.detailMode,
			allTextFits = self:_textFits(),
			insideSafeArea = self:_insideSafeArea(),
			noOverlap = self:_layoutHasNoOverlap(),
		},
		art = {
			mode = hasUploadedArt and "UploadedItemArt" or "NativeFallback",
			magentaFree = true,
			checkerboardFree = true,
		},
		performance = {
			diagnosticSnapshots = self._diagnosticSnapshotCount,
			diagnosticSnapshotSkips = self._diagnosticSnapshotSkipCount,
			gridRebuilds = self._gridRebuildCount,
			selectionVisualUpdates = self._selectionVisualUpdateCount,
			liveCards = #self._cards,
			cardConnections = #self._cardConnections,
			cardConnectionBounded = #self._cardConnections <= (#self._cards * 3),
		},
	}
end

function InventoryUI:Destroy()
	self:_stopTimedRefresh()
	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
	table.clear(self._connections)
	self:_disconnectPool(self._cardConnections)
	self:_disconnectPool(self._actionConnections)
	table.clear(self._cardRefsByKey)
	table.clear(self._cards)
	if self.Root then
		self.Root:Destroy()
	end
end

return InventoryUI
