local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local InventoryViewModel = require(ReplicatedStorage:WaitForChild("InventoryViewModel"))

local InventoryUI = {}
InventoryUI.__index = InventoryUI

local CATEGORIES = { "All", "Fists", "Pets", "Boosts", "Honor" }
local RARITIES = { "All", "Common", "Rare", "Epic", "Legendary", "Secret", "Premium" }

local CATEGORY_ICONS = {
	All = "Menu",
	Fists = "StarterFist",
	Pets = "Pet",
	Boosts = "Power",
	Honor = "Success",
}

local PALETTE = {
	Backdrop = Color3.fromRGB(1, 6, 11),
	Ink = Color3.fromRGB(4, 10, 16),
	Panel = Color3.fromRGB(8, 18, 27),
	PanelSoft = Color3.fromRGB(14, 29, 40),
	PanelRaised = Color3.fromRGB(20, 38, 50),
	Card = Color3.fromRGB(8, 21, 31),
	CardHover = Color3.fromRGB(15, 37, 51),
	Cyan = Color3.fromRGB(43, 211, 255),
	CyanSoft = Color3.fromRGB(27, 118, 153),
	Red = Color3.fromRGB(199, 24, 27),
	RedDark = Color3.fromRGB(83, 10, 16),
	Gold = Color3.fromRGB(255, 193, 35),
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
	self._cards = {}
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
	self._layout = {
		compact = false,
		columns = 4,
		minTouchTarget = 44,
		detailMode = "Pane",
		viewport = Vector2.new(1280, 720),
		uiScale = 1,
	}

	self:_build(options.Parent)
	self:ApplyResponsive(self.Root.AbsoluteSize, false, 1)
	return self
end

function InventoryUI:_connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(self._connections, connection)
	return connection
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
		Color = ColorSequence.new(PALETTE.PanelSoft, Color3.new(0, 0, 0)),
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.12),
			NumberSequenceKeypoint.new(1, 0.36),
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
	addCorner(self.WindowShadow, 12)

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
	addCorner(self.Window, 10)
	self.WindowStroke = addStroke(self.Window, PALETTE.Cyan, 3)
	create("UIGradient", self.Window, {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(15, 31, 42)),
			ColorSequenceKeypoint.new(0.5, PALETTE.Ink),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(5, 15, 24)),
		}),
		Rotation = 90,
	})
	self.WindowScale = create("UIScale", self.Window, {
		Name = "InventoryScale",
		Scale = 1,
	})

	self.Header = create("Frame", self.Window, {
		Name = "InventoryHeader",
		BackgroundColor3 = PALETTE.Red,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.new(1, -16, 0, 72),
		ZIndex = 144,
	})
	addCorner(self.Header, 7)
	addStroke(self.Header, Color3.fromRGB(255, 72, 48), 2)
	create("UIGradient", self.Header, {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(115, 7, 13)),
			ColorSequenceKeypoint.new(0.34, Color3.fromRGB(218, 21, 20)),
			ColorSequenceKeypoint.new(0.78, Color3.fromRGB(126, 8, 14)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(44, 9, 14)),
		}),
		Rotation = 8,
	})

	self.Title = create("TextLabel", self.Header, {
		Name = "InventoryTitle",
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		Position = UDim2.fromOffset(24, 6),
		Size = UDim2.new(0.48, -24, 0, 42),
		Text = "INVENTORY",
		TextColor3 = PALETTE.Text,
		TextScaled = true,
		TextStrokeColor3 = Color3.fromRGB(24, 4, 7),
		TextStrokeTransparency = 0.05,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 145,
	})
	addTextLimit(self.Title, 22, 38)

	self.Subtitle = create("TextLabel", self.Header, {
		Name = "InventorySubtitle",
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Position = UDim2.fromOffset(26, 47),
		Size = UDim2.new(0.48, -26, 0, 17),
		Text = "FISTS  |  SIDEKICKS  |  BOOSTS  |  HONOR",
		TextColor3 = Color3.fromRGB(255, 196, 93),
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 145,
	})

	self.Capacity = create("TextLabel", self.Header, {
		Name = "InventoryCapacity",
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = Color3.fromRGB(20, 11, 14),
		BackgroundTransparency = 0.14,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBlack,
		Position = UDim2.new(1, -74, 0.5, 0),
		Size = UDim2.fromOffset(235, 38),
		Text = "ITEMS 0  |  PETS 0/0",
		TextColor3 = PALETTE.Text,
		TextSize = 12,
		ZIndex = 145,
	})
	addCorner(self.Capacity, 5)
	addStroke(self.Capacity, PALETTE.Gold, 1.5)

	self.Close = create("TextButton", self.Header, {
		Name = "InventoryClose",
		AnchorPoint = Vector2.new(1, 0.5),
		AutoButtonColor = false,
		BackgroundColor3 = Color3.fromRGB(143, 12, 20),
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBlack,
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(50, 50),
		Text = "X",
		TextColor3 = PALETTE.Text,
		TextSize = 24,
		ZIndex = 146,
	})
	addCorner(self.Close, 7)
	addStroke(self.Close, Color3.fromRGB(255, 58, 48), 2)

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
		Position = UDim2.fromOffset(4, 4),
		Size = UDim2.fromOffset(154, 570),
		ZIndex = 144,
	})
	addCorner(self.CategoryBar, 7)
	addStroke(self.CategoryBar, PALETTE.CyanSoft, 1.5)
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
			BackgroundColor3 = PALETTE.PanelRaised,
			BorderSizePixel = 0,
			Font = Enum.Font.GothamBlack,
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 54),
			Text = string.upper(category),
			TextColor3 = PALETTE.Text,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 145,
		})
		button:SetAttribute("InventoryCategory", category)
		addCorner(button, 5)
		local buttonStroke = addStroke(button, PALETTE.CyanSoft, 1.5, 0.2)
		local padding = create("UIPadding", button, {
			PaddingLeft = UDim.new(0, 44),
			PaddingRight = UDim.new(0, 9),
		})
		local icon = create("ImageLabel", button, {
			Name = "CategoryIcon",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(-38, 9),
			Size = UDim2.fromOffset(36, 36),
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 146,
		})
		self:_applyAtlasIcon(icon, CATEGORY_ICONS[category])
		self._categoryButtons[category] = {
			button = button,
			stroke = buttonStroke,
			padding = padding,
			icon = icon,
		}
		self:_connect(button.Activated, function()
			self:SetCategory(category)
		end)
	end

	self.GridPane = create("Frame", self.Body, {
		Name = "InventoryGridPane",
		BackgroundColor3 = PALETTE.Panel,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(168, 4),
		Size = UDim2.new(1, -484, 1, -8),
		ZIndex = 144,
	})
	addCorner(self.GridPane, 7)
	addStroke(self.GridPane, PALETTE.CyanSoft, 1.5)

	self.Toolbar = create("Frame", self.GridPane, {
		Name = "InventoryToolbar",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.new(1, -16, 0, 44),
		ZIndex = 146,
	})

	self.Search = create("TextBox", self.Toolbar, {
		Name = "InventorySearch",
		BackgroundColor3 = Color3.fromRGB(7, 18, 27),
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
	addCorner(self.Search, 5)
	addStroke(self.Search, PALETTE.CyanSoft, 1.5)
	create("UIPadding", self.Search, {
		PaddingLeft = UDim.new(0, 14),
		PaddingRight = UDim.new(0, 10),
	})

	self.RarityFilter = create("TextButton", self.Toolbar, {
		Name = "RarityFilter",
		AnchorPoint = Vector2.new(1, 0),
		AutoButtonColor = false,
		BackgroundColor3 = Color3.fromRGB(10, 31, 46),
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBlack,
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(154, 44),
		Text = "RARITY: ALL  v",
		TextColor3 = PALETTE.Text,
		TextSize = 11,
		ZIndex = 148,
	})
	addCorner(self.RarityFilter, 5)
	addStroke(self.RarityFilter, PALETTE.Cyan, 1.5)

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
			self:SetRarity(rarity)
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
	addCorner(self.Detail, 7)
	self.DetailStroke = addStroke(self.Detail, PALETTE.Gold, 2)

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
		BackgroundColor3 = Color3.fromRGB(5, 15, 24),
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(14, 14),
		Size = UDim2.new(1, -28, 0, 210),
		ZIndex = 151,
	})
	addCorner(self.DetailArtFrame, 6)
	self.DetailArtStroke = addStroke(self.DetailArtFrame, PALETTE.Gold, 2)
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
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		Position = UDim2.fromOffset(16, 234),
		Size = UDim2.new(1, -32, 0, 22),
		Text = "RARITY",
		TextColor3 = PALETTE.Gold,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 152,
	})
	self.DetailName = create("TextLabel", self.Detail, {
		Name = "DetailName",
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		Position = UDim2.fromOffset(16, 254),
		Size = UDim2.new(1, -32, 0, 44),
		Text = "SELECT AN ITEM",
		TextColor3 = PALETTE.Text,
		TextScaled = true,
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
		TextColor3 = PALETTE.Muted,
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
	addCorner(self.DetailStatus, 5)
	addStroke(self.DetailStatus, PALETTE.CyanSoft, 1)

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
			self:SetSearch(self.Search.Text)
		end
	end)
	self:_connect(self.Root:GetPropertyChangedSignal("AbsoluteSize"), function()
		local size = self.Root.AbsoluteSize
		if size.X > 0 and size.Y > 0 then
			self:ApplyResponsive(size, size.X < 900 or size.Y < 520, self._layout.uiScale)
		end
	end)
	self:_connect(RunService.Heartbeat, function()
		if not self.Root.Visible or not self._snapshot then
			return
		end
		local hasTimedItem = false
		for _, item in ipairs(self._snapshot.items or {}) do
			if tonumber(item.endsAt) and tonumber(item.endsAt) > 0 then
				hasTimedItem = true
				break
			end
		end
		if not hasTimedItem then
			return
		end
		local now = workspace:GetServerTimeNow()
		if math.floor(now) <= math.floor(self._lastTimedRefreshAt) then
			return
		end
		self._lastTimedRefreshAt = now
		self._snapshot = self:_buildSnapshot(self:_getStats())
		self:_applyFilter(false)
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
	self.RarityFilter.Text = "RARITY: " .. string.upper(self._rarity) .. (self._rarityMenuOpen and "  ^" or "  v")
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
		widgets.button.BackgroundColor3 = selected and Color3.fromRGB(30, 46, 54) or PALETTE.PanelRaised
		widgets.button.TextColor3 = selected and PALETTE.Gold or PALETTE.Text
		widgets.stroke.Color = selected and PALETTE.Gold or PALETTE.CyanSoft
		widgets.stroke.Thickness = selected and 2.5 or 1.5
	end
	for rarity, button in pairs(self._rarityButtons) do
		button.BackgroundTransparency = rarity == self._rarity and 0 or 1
		button.BackgroundColor3 = rarity == self._rarity and Color3.fromRGB(27, 45, 57) or PALETTE.PanelSoft
	end
	self:_setRarityMenu(self._rarityMenuOpen)
end

function InventoryUI:_clearCards()
	for _, card in ipairs(self._cards) do
		card:Destroy()
	end
	table.clear(self._cards)
end

function InventoryUI:_renderGrid()
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
			LayoutOrder = index,
			Text = "",
			ZIndex = 146,
		})
		card:SetAttribute("InventoryKey", key)
		card:SetAttribute("InventoryCategory", tostring(item.category or ""))
		card:SetAttribute("InventoryRarity", tostring(item.rarity or "Common"))
		card:SetAttribute("InventoryEquipped", item.equipped == true)
		card:SetAttribute("InventoryLocked", item.locked == true)
		addCorner(card, 6)
		local cardStroke = addStroke(card, selected and PALETTE.Gold or accent, selected and 3 or 1.5)

		local accentBar = create("Frame", card, {
			Name = "RarityAccent",
			BackgroundColor3 = accent,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.new(1, 0, 0, 5),
			ZIndex = 147,
		})
		addCorner(accentBar, 3)

		local artFrame = create("Frame", card, {
			Name = "ItemArtFrame",
			BackgroundColor3 = Color3.fromRGB(4, 14, 22),
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(7, 11),
			Size = UDim2.new(1, -14, 1, -50),
			ZIndex = 147,
		})
		addCorner(artFrame, 5)
		local art = create("ImageLabel", artFrame, {
			Name = "ItemArt",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(4, 4),
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.new(1, -8, 1, -8),
			ZIndex = 148,
		})
		local artMode = self:_applyItemArt(art, item)
		card:SetAttribute("ArtMode", artMode)

		local rarity = create("TextLabel", card, {
			Name = "ItemRarity",
			BackgroundColor3 = Color3.fromRGB(2, 9, 14),
			BackgroundTransparency = 0.2,
			BorderSizePixel = 0,
			Font = Enum.Font.GothamBlack,
			Position = UDim2.fromOffset(7, 13),
			Size = UDim2.new(1, -14, 0, 18),
			Text = string.upper(tostring(item.rarity or "Common")),
			TextColor3 = accent,
			TextSize = 9,
			ZIndex = 149,
		})
		addCorner(rarity, 3)

		local name = create("TextLabel", card, {
			Name = "ItemName",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Font = Enum.Font.GothamBlack,
			Position = UDim2.new(0, 6, 1, -35),
			Size = UDim2.new(1, -12, 0, 30),
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
				AnchorPoint = Vector2.new(1, 1),
				BackgroundColor3 = Color3.fromRGB(2, 8, 13),
				BackgroundTransparency = 0.1,
				BorderSizePixel = 0,
				Font = Enum.Font.GothamBlack,
				Position = UDim2.new(1, -7, 1, -39),
				Size = UDim2.fromOffset(38, 22),
				Text = "x" .. formatNumber(item.quantity),
				TextColor3 = PALETTE.Text,
				TextSize = 11,
				ZIndex = 151,
			})
			addCorner(quantity, 4)
		end

		if item.equipped == true then
			local equipped = create("TextLabel", card, {
				Name = "EquippedBadge",
				BackgroundColor3 = PALETTE.Green,
				BorderSizePixel = 0,
				Font = Enum.Font.GothamBlack,
				Position = UDim2.fromOffset(8, 34),
				Size = UDim2.fromOffset(62, 20),
				Text = "EQUIPPED",
				TextColor3 = Color3.fromRGB(4, 20, 8),
				TextSize = 8,
				ZIndex = 151,
			})
			addCorner(equipped, 3)
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
			addCorner(locked, 3)
		end

		self:_connect(card.MouseEnter, function()
			if key ~= self._selectedKey then
				card.BackgroundColor3 = PALETTE.CardHover
				cardStroke.Thickness = 2
			end
		end)
		self:_connect(card.MouseLeave, function()
			if key ~= self._selectedKey then
				card.BackgroundColor3 = PALETTE.Card
				cardStroke.Thickness = 1.5
			end
		end)
		self:_connect(card.Activated, function()
			self:SelectItem(key)
		end)
		table.insert(self._cards, card)
	end
end

function InventoryUI:_clearActionButtons()
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
		self.DetailInternalName.Text = ""
		self.DetailRarity.Text = "INVENTORY"
		self.DetailDescription.Text = "Choose an item to inspect its live server-backed state."
		self.DetailStatus.Text = "NO ITEM SELECTED"
		self.DetailArt.Image = ""
		self.DetailStroke.Color = PALETTE.CyanSoft
		self.DetailArtStroke.Color = PALETTE.CyanSoft
		self:_syncDetailVisibility()
		return
	end

	local accent = itemAccent(item)
	local displayName = tostring(item.displayName or item.name or "Unknown Item")
	local internalName = tostring(item.name or displayName)
	self.DetailRarity.Text = string.upper(tostring(item.rarity or "Common")) .. "  |  " .. string.upper(tostring(item.category or "Item"))
	self.DetailRarity.TextColor3 = accent
	self.DetailName.Text = displayName
	self.DetailInternalName.Text = internalName ~= displayName and ("SAVE KEY  |  " .. internalName) or ("ITEM KEY  |  " .. tostring(item.key or ""))
	self.DetailDescription.Text = tostring(item.description or item.detail or "No additional item details.")
	self.DetailStroke.Color = accent
	self.DetailArtStroke.Color = accent
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
			addCorner(button, 5)
			addStroke(button, destructive and Color3.fromRGB(255, 113, 83) or Color3.fromRGB(155, 236, 255), 1.5, 0.15)
			self:_connect(button.Activated, function()
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
		addCorner(label, 5)
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
		self:Refresh(true)
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
	self.Root:SetAttribute("InventoryVisible", visible)
end

function InventoryUI:IsVisible()
	return self.Root.Visible
end

function InventoryUI:Refresh(force)
	local stats = self:_getStats()
	local ok, signature = pcall(InventoryViewModel.Signature, self.GameConfig, stats)
	if not ok then
		signature = tostring(stats)
	end
	signature = tostring(signature)
	if force == true or not self._snapshot or signature ~= self._signature then
		self._signature = signature
		self._snapshot = self:_buildSnapshot(stats)
		self:_applyFilter(false)
	elseif self.Root.Visible then
		self:_applyFilter(false)
	end
	return self:GetSnapshot()
end

function InventoryUI:SetCategory(name)
	local requested = normalize(name)
	for _, category in ipairs(CATEGORIES) do
		if normalize(category) == requested then
			self._category = category
			self._deleteConfirmKey = nil
			self._deleteConfirmUntil = 0
			self:_applyFilter(true)
			self:ApplyResponsive(self._layout.viewport, self._layout.compact, self._layout.uiScale)
			return self:GetSnapshot()
		end
	end
	return self:GetSnapshot()
end

function InventoryUI:SetSearch(text)
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
	return self:GetSnapshot()
end

function InventoryUI:SetRarity(name)
	local requested = normalize(name)
	for _, rarity in ipairs(RARITIES) do
		if normalize(rarity) == requested then
			self._rarity = rarity
			self._deleteConfirmKey = nil
			self._deleteConfirmUntil = 0
			self:_applyFilter(true)
			self:ApplyResponsive(self._layout.viewport, self._layout.compact, self._layout.uiScale)
			return self:GetSnapshot()
		end
	end
	return self:GetSnapshot()
end

function InventoryUI:SelectItem(key)
	local item = self:_findItem(key)
	if not item then
		return self:GetSnapshot()
	end
	self._selectedKey = tostring(item.key)
	self._selectedItem = item
	self._deleteConfirmKey = nil
	self._deleteConfirmUntil = 0
	self._detailExpanded = true
	self:_renderGrid()
	self:_renderDetail()
	self:ApplyResponsive(self._layout.viewport, self._layout.compact, self._layout.uiScale)
	self.Root:SetAttribute("InventorySelectedKey", self._selectedKey)
	return self:GetSnapshot()
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
			self:SelectItem(request.key)
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
	local useCompact = compact == true or viewport.X < 900 or viewport.Y < 520
	local touchTarget = math.ceil(44 / math.min(scale, 1))
	local headerHeight = useCompact and math.max(58, touchTarget + 10) or math.max(72, touchTarget + 18)
	local availableWidth = viewport.X / scale
	local availableHeight = viewport.Y / scale
	local windowWidth = useCompact and math.max(480, availableWidth - 12) or math.min(1180, availableWidth - 32)
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
	local bodyTop = headerHeight + 16
	self.Body.Position = UDim2.fromOffset(8, bodyTop)
	self.Body.Size = UDim2.new(1, -16, 1, -(bodyTop + 8))
	self.Subtitle.Visible = not useCompact
	self.Title.Size = UDim2.new(useCompact and 0.46 or 0.48, -24, 0, useCompact and 44 or 42)
	self.Capacity.Position = UDim2.new(1, -68, 0.5, 0)
	self.Capacity.Size = UDim2.fromOffset(useCompact and 190 or 235, useCompact and 34 or 38)
	self.Capacity.TextSize = useCompact and 10 or 12
	self.Close.Size = UDim2.fromOffset(math.max(touchTarget, useCompact and 44 or 50), math.max(touchTarget, useCompact and 44 or 50))

	local bodyWidth = windowWidth - 16
	local bodyHeight = windowHeight - bodyTop - 8
	local toolbarHeight = touchTarget
	self.Toolbar.Size = UDim2.new(1, -16, 0, toolbarHeight)
	self.Search.Size = UDim2.new(1, -166, 0, toolbarHeight)
	self.RarityFilter.Size = UDim2.fromOffset(154, toolbarHeight)
	self.RarityMenu.Position = UDim2.new(1, -8, 0, toolbarHeight + 12)
	self.RarityMenu.Size = UDim2.fromOffset(154, #RARITIES * touchTarget + 12)
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
		end

		local categoryHeight = touchTarget + 8
		local minimumGridHeight = 58
		local drawerHeight = 0
		if self._detailExpanded and self._selectedItem then
			if shortCompact then
				drawerHeight = math.min(132, math.max(108, bodyHeight * 0.44))
			else
				drawerHeight = math.min(210, math.max(160, bodyHeight * 0.42, touchTarget + 112))
			end
			local maximumDrawerHeight = math.max(
				0,
				bodyHeight - categoryHeight - minimumGridHeight - 12
			)
			drawerHeight = math.min(drawerHeight, maximumDrawerHeight)
		end
		local gridHeight = bodyHeight - categoryHeight - 12 - (drawerHeight > 0 and drawerHeight + 8 or 0)
		self.GridPane.Position = UDim2.fromOffset(4, categoryHeight + 8)
		self.GridPane.Size = UDim2.new(1, -8, 0, math.max(minimumGridHeight, gridHeight))
		self.Detail.Position = UDim2.new(0, 4, 1, -drawerHeight - 4)
		self.Detail.Size = UDim2.new(1, -8, 0, drawerHeight)
		self.DetailClose.Size = UDim2.fromOffset(touchTarget, touchTarget)
		self.DetailClose.Visible = drawerHeight > 0
		self.CompactDetailDrawer.Visible = drawerHeight > 0
		self:_syncDetailVisibility()

		if shortCompact then
			self.DetailArtFrame.Position = UDim2.fromOffset(12, 14)
			self.DetailArtFrame.Size = UDim2.fromOffset(76, math.max(80, drawerHeight - 28))
			self.DetailRarity.Position = UDim2.fromOffset(98, 10)
			self.DetailRarity.Size = UDim2.new(0.48, -106, 0, 16)
			self.DetailName.Position = UDim2.fromOffset(98, 26)
			self.DetailName.Size = UDim2.new(0.48, -106, 0, 30)
			self.DetailInternalName.Position = UDim2.fromOffset(98, 57)
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
			self.DetailRarity.Size = UDim2.new(1, -202, 0, 18)
			self.DetailName.Position = UDim2.fromOffset(142, 33)
			self.DetailName.Size = UDim2.new(1, -202, 0, 34)
			self.DetailInternalName.Position = UDim2.fromOffset(142, 68)
			self.DetailInternalName.Size = UDim2.new(1, -202, 0, 16)
			self.DetailDescription.Visible = true
			self.DetailDescription.Position = UDim2.fromOffset(142, 88)
			self.DetailDescription.Size = UDim2.new(0.47, -28, 1, -98)
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
		local actionPanelWidth = shortCompact and (bodyWidth * 0.42 - touchTarget - 14) or (bodyWidth * 0.44 - 14)
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
		self.CategoryBar.Position = UDim2.fromOffset(4, 4)
		self.CategoryBar.Size = UDim2.fromOffset(154, bodyHeight - 8)
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
			widgets.button.Size = UDim2.new(1, 0, 0, math.max(54, touchTarget))
			widgets.button.TextSize = 12
			widgets.padding.PaddingLeft = UDim.new(0, 44)
			widgets.padding.PaddingRight = UDim.new(0, 9)
			widgets.icon.Position = UDim2.fromOffset(-38, 9)
			widgets.icon.Size = UDim2.fromOffset(36, 36)
		end

		local detailWidth = math.clamp(windowWidth * 0.27, 286, 322)
		local gridX = 168
		self.Detail.Position = UDim2.new(1, -detailWidth - 4, 0, 4)
		self.Detail.Size = UDim2.new(0, detailWidth, 1, -8)
		self.Detail.Visible = true
		self.DetailClose.Visible = false
		self.CompactDetailDrawer.Visible = false
		self.GridPane.Position = UDim2.fromOffset(gridX, 4)
		self.GridPane.Size = UDim2.new(1, -(gridX + detailWidth + 12), 1, -8)

		self.DetailArtFrame.Position = UDim2.fromOffset(14, 14)
		self.DetailArtFrame.Size = UDim2.new(1, -28, 0, math.clamp(bodyHeight * 0.34, 150, 220))
		local artBottom = 14 + math.clamp(bodyHeight * 0.34, 150, 220)
		self.DetailRarity.Position = UDim2.fromOffset(16, artBottom + 10)
		self.DetailRarity.Size = UDim2.new(1, -32, 0, 20)
		self.DetailName.Position = UDim2.fromOffset(16, artBottom + 30)
		self.DetailName.Size = UDim2.new(1, -32, 0, 42)
		self.DetailInternalName.Position = UDim2.fromOffset(16, artBottom + 74)
		self.DetailInternalName.Size = UDim2.new(1, -32, 0, 18)
		self.DetailDescription.Position = UDim2.fromOffset(16, artBottom + 98)
		self.DetailDescription.Size = UDim2.new(1, -32, 0, math.max(54, bodyHeight - artBottom - 250))
		self.DetailDescription.TextSize = 12
		local actionRows = math.ceil(math.max(1, #self._actionButtons) / 2)
		local actionAreaHeight = actionRows * touchTarget + math.max(0, actionRows - 1) * 6
		local statusY = bodyHeight - actionAreaHeight - 58
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

	local gridPaneWidth = useCompact and bodyWidth - 8 or windowWidth - 16 - 168 - math.clamp(windowWidth * 0.27, 286, 322) - 12
	local gridContentWidth = math.max(280, gridPaneWidth - 24)
	local columns
	if gridContentWidth >= 720 then
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
	local cellHeight = useCompact and math.max(112, math.min(132, cellWidth * 0.9)) or math.max(132, math.min(158, cellWidth * 1.05))
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
			if descendant.Visible and descendant.AbsoluteSize.X > 0 and descendant.AbsoluteSize.Y > 0 then
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
		if not self.Detail.Visible then
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
	}
end

function InventoryUI:Destroy()
	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
	table.clear(self._connections)
	if self.Root then
		self.Root:Destroy()
	end
end

return InventoryUI
