local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ContentProvider = game:GetService("ContentProvider")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local HttpService = game:GetService("HttpService")
local HapticService = game:GetService("HapticService")
local StarterGui = game:GetService("StarterGui")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
do
	local repairGeneration = 0
	local activeConnections = {}

	local function disconnectAnimateRepair()
		for _, connection in ipairs(activeConnections) do
			connection:Disconnect()
		end
		table.clear(activeConnections)
	end

	local function scheduleDefaultAnimateRepair(character)
		repairGeneration += 1
		local generation = repairGeneration
		disconnectAnimateRepair()
		if not character then return end

		local animate
		local fallback
		local fallbackCallback = function()
			return false
		end
		local finished = false
		local function isCurrent()
			return not finished
				and generation == repairGeneration
				and player.Character == character
				and character.Parent ~= nil
		end
		local function finish(reason)
			if finished then return end
			finished = true
			disconnectAnimateRepair()
			if character.Parent then
				character:SetAttribute("PunchWallAnimateRepairState", reason)
			end
		end
		local function acceptPlayEmote(playEmote, reason)
			if not isCurrent() or not playEmote then return end
			if not playEmote:IsA("BindableFunction") then
				character:SetAttribute("PunchWallPlayEmoteHookClassMismatch", playEmote.ClassName)
				finish("ClassMismatch")
				return
			end
			if fallback and playEmote ~= fallback and fallback.Parent == animate then
				-- Prefer the late engine-owned hook and remove only the fallback
				-- we own. BindableFunction.OnInvoke is write-only to game scripts,
				-- so its callback must never be read or copied here.
				fallback:Destroy()
				character:SetAttribute("PunchWallAdoptedLatePlayEmoteHook", true)
			end
			finish(reason)
		end
		local function bindAnimate(candidate)
			if not isCurrent() or animate then return end
			if not candidate:IsA("LocalScript") then
				character:SetAttribute("PunchWallAnimateClassMismatch", candidate.ClassName)
				finish("AnimateClassMismatch")
				return
			end
			animate = candidate
			local existing = animate:FindFirstChild("PlayEmote")
			if existing then
				acceptPlayEmote(existing, "EngineHookReady")
				return
			end
			table.insert(activeConnections, animate.ChildAdded:Connect(function(child)
				if child.Name == "PlayEmote" and child:GetAttribute("PunchWallOwnedFallback") ~= true then
					acceptPlayEmote(child, fallback and "LateEngineHookAdopted" or "EngineHookReady")
				end
			end))
			-- One short, bounded grace window lets the default Animate hierarchy
			-- finish parenting before we repair a partial character bootstrap.
			task.delay(0.35, function()
				if not isCurrent() or animate.Parent ~= character or animate:FindFirstChild("PlayEmote") then return end
				fallback = Instance.new("BindableFunction")
				fallback.Name = "PlayEmote"
				fallback.OnInvoke = fallbackCallback
				fallback:SetAttribute("PunchWallOwnedFallback", true)
				fallback.Parent = animate
				character:SetAttribute("PunchWallRepairedPlayEmoteHook", true)
				character:SetAttribute("PunchWallAnimateRepairState", "FallbackInstalled")
			end)
		end

		local existingAnimate = character:FindFirstChild("Animate")
		if existingAnimate then
			bindAnimate(existingAnimate)
		else
			table.insert(activeConnections, character.ChildAdded:Connect(function(child)
				if child.Name == "Animate" then bindAnimate(child) end
			end))
		end
		-- The listener is never allowed to survive the bootstrap window. A future
		-- respawn increments the generation and disconnects it immediately.
		task.delay(6, function()
			if isCurrent() then
				finish(animate and (fallback and "FallbackBoundedComplete" or "HookMissing") or "AnimateMissing")
			end
		end)
	end
	player.CharacterAdded:Connect(scheduleDefaultAnimateRepair)
	scheduleDefaultAnimateRepair(player.Character)
end
local PolishConfig = require(ReplicatedStorage:WaitForChild("PolishConfig"))
local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local FistVisualBuilder = require(ReplicatedStorage:WaitForChild("FistVisualBuilder"))
local InventoryUI = require(script.Parent:WaitForChild("InventoryUI"))
FistVisualBuilder.Ensure()
local palette = PolishConfig.Palette
local gui

shared.PunchWallPurchaseRuntime = {}

shared.PunchWallPurchaseRuntime.GamePassPriceCache = {}
shared.PunchWallPurchaseRuntime.GamePassPricePending = {}
shared.PunchWallPurchaseRuntime.GamePassPriceCallbacks = {}

shared.PunchWallPurchaseRuntime.ApplyPremiumPetWorldPrice = function(item, displayPrice, resolved, state)
	local root = workspace:FindFirstChild("PunchWallRPG")
	if not root or not item then return end
	local text = resolved
		and ("R$ %d | PERMANENT | x%.1f"):format(displayPrice, item.mult)
		or state == "Loading" and "CHECKING LOCAL PRICE..."
		or "PRICE SHOWN AT CHECKOUT | PERMANENT"
	for _, objectName in ipairs({
		item.name .. " Premium Pet Stand",
		item.name .. " Premium Pet Price",
	}) do
		local object = root:FindFirstChild(objectName, true)
		if object then
			object:SetAttribute("DefaultRobuxPrice", item.robux)
			object:SetAttribute("DisplayedRobuxPrice", resolved and displayPrice or 0)
			object:SetAttribute("RegionalPriceResolved", resolved)
			object:SetAttribute("RegionalPriceState", state)
			if objectName:find(" Price$", 1, false) then
				for _, descendant in ipairs(object:GetDescendants()) do
					if descendant:IsA("TextLabel") and descendant.Name == "Subtitle" then
						descendant.Text = text
					end
				end
			end
		end
	end
end

shared.PunchWallPurchaseRuntime.HasConfiguredGamePass = function(item)
	local gamePassId = item and tonumber(item.gamePassId)
	return gamePassId ~= nil and gamePassId > 0
end

shared.PunchWallPurchaseRuntime.HasConfiguredDeveloperProduct = function(product)
	local productId = product and tonumber(product.productId)
	if productId == nil or productId <= 0 or productId % 1 ~= 0 then
		return false
	end
	local matches = 0
	for _, candidate in ipairs(GameConfig.PremiumProducts) do
		if tonumber(candidate.productId) == productId then
			matches += 1
		end
	end
	return matches == 1
end

shared.PunchWallPurchaseRuntime.GetGamePassDisplayPrice = function(item, onResolved)
	local gamePassId = item and tonumber(item.gamePassId)
	local fallbackPrice = math.max(0, math.floor(tonumber(item and item.robux) or 0))
	if not gamePassId or gamePassId <= 0 then
		return fallbackPrice, false, "Unconfigured"
	end

	local cached = shared.PunchWallPurchaseRuntime.GamePassPriceCache[gamePassId]
	if cached then
		shared.PunchWallPurchaseRuntime.ApplyPremiumPetWorldPrice(item, cached.price, cached.resolved, cached.state)
		return cached.price, cached.resolved, cached.state
	end

	if onResolved then
		local callbacks = shared.PunchWallPurchaseRuntime.GamePassPriceCallbacks[gamePassId]
		if not callbacks then
			callbacks = {}
			shared.PunchWallPurchaseRuntime.GamePassPriceCallbacks[gamePassId] = callbacks
		end
		callbacks[onResolved] = true
	end
	shared.PunchWallPurchaseRuntime.ApplyPremiumPetWorldPrice(item, fallbackPrice, false, "Loading")

	if not shared.PunchWallPurchaseRuntime.GamePassPricePending[gamePassId] then
		shared.PunchWallPurchaseRuntime.GamePassPricePending[gamePassId] = true
		task.spawn(function()
			local marketplaceService = game:GetService("MarketplaceService")
			local lookupOk, info = pcall(
				marketplaceService.GetProductInfoAsync,
				marketplaceService,
				gamePassId,
				Enum.InfoType.GamePass
			)
			local livePrice = lookupOk and type(info) == "table" and tonumber(info.PriceInRobux) or nil
			local resolved = livePrice ~= nil and livePrice > 0 and info.IsForSale == true
			local result = {
				price = resolved and math.floor(livePrice) or fallbackPrice,
				resolved = resolved,
				state = resolved and "Resolved" or "CheckoutOnly",
			}
			shared.PunchWallPurchaseRuntime.GamePassPriceCache[gamePassId] = result
			shared.PunchWallPurchaseRuntime.GamePassPricePending[gamePassId] = nil
			shared.PunchWallPurchaseRuntime.ApplyPremiumPetWorldPrice(item, result.price, result.resolved, result.state)
			-- The replicated world board can arrive after MarketplaceService. One
			-- bounded re-apply keeps it truthful without adding a polling loop.
			task.delay(3, function()
				shared.PunchWallPurchaseRuntime.ApplyPremiumPetWorldPrice(item, result.price, result.resolved, result.state)
			end)
			local callbacks = shared.PunchWallPurchaseRuntime.GamePassPriceCallbacks[gamePassId]
			shared.PunchWallPurchaseRuntime.GamePassPriceCallbacks[gamePassId] = nil
			if callbacks then
				for callback in pairs(callbacks) do
					task.defer(callback)
				end
			end
		end)
	end

	return fallbackPrice, false, "Loading"
end

task.defer(function()
	for _, item in ipairs(GameConfig.PremiumPets) do
		if shared.PunchWallPurchaseRuntime.HasConfiguredGamePass(item) then
			shared.PunchWallPurchaseRuntime.GetGamePassDisplayPrice(item)
		end
	end
end)

shared.PunchWallPurchaseRuntime.DeveloperProductPriceCache = {}
shared.PunchWallPurchaseRuntime.DeveloperProductPricePending = {}
shared.PunchWallPurchaseRuntime.DeveloperProductPriceCallbacks = {}
shared.PunchWallPurchaseRuntime.DeveloperProductPriceRevision = 0
shared.PunchWallPurchaseRuntime.ProductUiState = {}
shared.PunchWallPurchaseRuntime.ActivePromptProductId = nil

shared.PunchWallPurchaseRuntime.SetProductUiState = function(productKey, state, message)
	productKey = tostring(productKey or "")
	if productKey == "" then return end
	shared.PunchWallPurchaseRuntime.ProductUiState[productKey] = {
		state = tostring(state or "Idle"),
		message = tostring(message or ""),
		updatedAt = workspace:GetServerTimeNow(),
	}
	shared.PunchWallPurchaseRuntime.DeveloperProductPriceRevision += 1
	if gui then
		gui:SetAttribute("PurchaseUiProduct", productKey)
		gui:SetAttribute("PurchaseUiState", tostring(state or "Idle"))
		gui:SetAttribute("PurchaseUiMessage", tostring(message or ""))
	end
	if shared.PunchWallHeroShopRefresh then
		shared.PunchWallHeroShopRefresh({ force = true, reason = "purchase-ui-state" })
	end
end

shared.PunchWallPurchaseRuntime.ApplyDeveloperProductWorldPrice = function(product, displayPrice, resolved, state)
	local root = workspace:FindFirstChild("PunchWallRPG")
	if not root or not product then return end
	local board = root:FindFirstChild(product.displayName .. " Premium Offer", true)
	if not board then return end
	board:SetAttribute("DefaultRobuxPrice", product.robux)
	board:SetAttribute("DisplayedRobuxPrice", resolved and displayPrice or 0)
	board:SetAttribute("RegionalPriceResolved", resolved)
	board:SetAttribute("RegionalPriceState", state)
	local text = resolved
		and ("%s  |  R$ %d"):format(product.displayName, displayPrice)
		or state == "Loading" and (product.displayName .. "  |  CHECKING LOCAL PRICE...")
		or state == "CheckoutOnly" and (product.displayName .. "  |  PRICE SHOWN AT CHECKOUT")
		or state == "OffSale" and (product.displayName .. "  |  OFF SALE")
		or (product.displayName .. "  |  PRICE UNAVAILABLE")
	for _, descendant in ipairs(board:GetDescendants()) do
		local surface = descendant.Parent
		if descendant:IsA("TextLabel")
			and descendant.Name == "Subtitle"
			and surface
			and surface:IsA("SurfaceGui")
			and surface.Face == Enum.NormalId.Front then
			descendant.Text = text
		end
	end
end

shared.PunchWallPurchaseRuntime.GetDeveloperProductDisplayPrice = function(product, onResolved)
	local productId = product and tonumber(product.productId)
	local fallbackPrice = math.max(0, math.floor(tonumber(product and product.robux) or 0))
	if not productId or productId <= 0 then
		return fallbackPrice, false, "Unconfigured"
	end

	local cached = shared.PunchWallPurchaseRuntime.DeveloperProductPriceCache[productId]
	if cached then
		shared.PunchWallPurchaseRuntime.ApplyDeveloperProductWorldPrice(product, cached.price, cached.resolved, cached.state)
		return cached.price, cached.resolved, cached.state
	end

	if onResolved then
		local callbacks = shared.PunchWallPurchaseRuntime.DeveloperProductPriceCallbacks[productId]
		if not callbacks then
			callbacks = {}
			shared.PunchWallPurchaseRuntime.DeveloperProductPriceCallbacks[productId] = callbacks
		end
		callbacks[onResolved] = true
	end
	shared.PunchWallPurchaseRuntime.ApplyDeveloperProductWorldPrice(product, fallbackPrice, false, "Loading")

	if not shared.PunchWallPurchaseRuntime.DeveloperProductPricePending[productId] then
		shared.PunchWallPurchaseRuntime.DeveloperProductPricePending[productId] = true
		task.spawn(function()
			local marketplaceService = game:GetService("MarketplaceService")
			local lookupOk, info = pcall(
				marketplaceService.GetProductInfoAsync,
				marketplaceService,
				productId,
				Enum.InfoType.Product
			)
			local validInfo = lookupOk and type(info) == "table"
			local identityValid = validInfo and tostring(info.Name or "") == tostring(product.displayName or "")
			local livePrice = validInfo and tonumber(info.PriceInRobux) or nil
			local state = not validInfo and "LookupFailed"
				or not identityValid and "WrongProduct"
				or info.IsForSale ~= true and "OffSale"
				or livePrice ~= nil and livePrice > 0 and "Resolved"
				or "CheckoutOnly"
			local resolved = state == "Resolved"
			local result = {
				price = resolved and math.floor(livePrice) or fallbackPrice,
				resolved = resolved,
				state = state,
			}
			shared.PunchWallPurchaseRuntime.DeveloperProductPriceCache[productId] = result
			shared.PunchWallPurchaseRuntime.DeveloperProductPricePending[productId] = nil
			shared.PunchWallPurchaseRuntime.DeveloperProductPriceRevision += 1
			shared.PunchWallPurchaseRuntime.ApplyDeveloperProductWorldPrice(product, result.price, result.resolved, result.state)
			task.delay(3, function()
				shared.PunchWallPurchaseRuntime.ApplyDeveloperProductWorldPrice(product, result.price, result.resolved, result.state)
			end)
			local callbacks = shared.PunchWallPurchaseRuntime.DeveloperProductPriceCallbacks[productId]
			shared.PunchWallPurchaseRuntime.DeveloperProductPriceCallbacks[productId] = nil
			if callbacks then
				for callback in pairs(callbacks) do
					task.defer(callback, result)
				end
			end
		end)
	end

	return fallbackPrice, false, "Loading"
end

shared.PunchWallPurchaseRuntime.ApplyDeveloperProductControlPrice = function(product, control, prefix)
	local function update()
		if not control.Parent then return end
		local displayPrice, resolved, state =
			shared.PunchWallPurchaseRuntime.GetDeveloperProductDisplayPrice(product)
		local priceCopy = resolved and ("R$ %d"):format(displayPrice)
			or state == "Loading" and "CHECKING PRICE"
			or state == "CheckoutOnly" and "PRICE AT CHECKOUT"
			or state == "OffSale" and "OFF SALE"
			or state == "WrongProduct" and "PRODUCT UNAVAILABLE"
			or "PRICE UNAVAILABLE"
		control:SetAttribute("ProductId", tonumber(product.productId) or 0)
		control:SetAttribute("DefaultRobuxPrice", tonumber(product.robux) or 0)
		control:SetAttribute("DisplayedRobuxPrice", resolved and displayPrice or 0)
		control:SetAttribute("RegionalPriceResolved", resolved)
		control:SetAttribute("RegionalPriceState", state)
		if control:IsA("TextButton") then
			control.Text = prefix .. "  |  " .. priceCopy
		elseif control:IsA("ImageButton") then
			local label = control:FindFirstChild("RegionalPriceLabel")
			if not label then
				label = Instance.new("TextLabel")
				label.Name = "RegionalPriceLabel"
				label.AnchorPoint = Vector2.new(1, 1)
				label.Position = UDim2.fromScale(0.98, 0.98)
				label.Size = UDim2.fromScale(0.58, 0.38)
				label.BackgroundColor3 = Color3.fromRGB(5, 14, 22)
				label.BackgroundTransparency = 0.08
				label.BorderSizePixel = 0
				label.Font = Enum.Font.GothamBlack
				label.TextColor3 = Color3.fromRGB(255, 223, 83)
				label.TextScaled = true
				label.ZIndex = control.ZIndex + 2
				label.Parent = control
				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(0, 4)
				corner.Parent = label
			end
			label.Text = priceCopy
		end
	end
	local _, _, state = shared.PunchWallPurchaseRuntime.GetDeveloperProductDisplayPrice(product, update)
	update()
	return state
end

task.defer(function()
	for _, product in ipairs(GameConfig.PremiumProducts) do
		if shared.PunchWallPurchaseRuntime.HasConfiguredDeveloperProduct(product) then
			shared.PunchWallPurchaseRuntime.GetDeveloperProductDisplayPrice(product)
		end
	end
end)

shared.PunchWallPurchaseRuntime.FindPremiumProduct = function(productKey)
	for _, product in ipairs(GameConfig.PremiumProducts) do
		if product.id == productKey then return product end
	end
	return nil
end

shared.PunchWallPurchaseRuntime.MarkControlUnavailable = function(button, message, reason)
	button.Active = false
	button.Selectable = false
	button.AutoButtonColor = false
	button:SetAttribute("PurchaseConfigured", false)
	button:SetAttribute("PurchaseUnavailable", true)
	button:SetAttribute("UnavailableReason", reason or "PurchaseIdNotConfigured")
	if button:IsA("TextButton") then
		button.Text = message or "UNAVAILABLE"
		button.BackgroundColor3 = Color3.fromRGB(61, 68, 73)
		button.TextColor3 = Color3.fromRGB(205, 211, 214)
	elseif button:IsA("ImageButton") then
		button.ImageTransparency = math.max(button.ImageTransparency, 0.58)
		local unavailable = Instance.new("TextLabel")
		unavailable.Name = "UnavailableLabel"
		unavailable.BackgroundColor3 = Color3.fromRGB(20, 25, 29)
		unavailable.BackgroundTransparency = 0.08
		unavailable.BorderSizePixel = 0
		unavailable.Size = UDim2.fromScale(1, 1)
		unavailable.Font = Enum.Font.GothamBlack
		unavailable.Text = message or "UNAVAILABLE"
		unavailable.TextColor3 = Color3.fromRGB(225, 229, 231)
		unavailable.TextScaled = true
		unavailable.TextWrapped = true
		unavailable.ZIndex = button.ZIndex + 1
		unavailable.Parent = button
		local textConstraint = Instance.new("UITextSizeConstraint")
		textConstraint.MinTextSize = 8
		textConstraint.MaxTextSize = 16
		textConstraint.Parent = unavailable
	end
end

shared.PunchWallPurchaseRuntime.MarkControlConfigured = function(button)
	button:SetAttribute("PurchaseConfigured", true)
	button:SetAttribute("PurchaseUnavailable", false)
end

local remotes = ReplicatedStorage:WaitForChild("PunchWallEvents")
local notifyRemote = remotes:WaitForChild("Notify")
local statRemote = remotes:WaitForChild("StatsChanged")
local actionRemote = remotes:WaitForChild("ActionRequest")
local feedbackRemote = remotes:WaitForChild("Feedback")

local latestStats = {}
local clientSettings = { motion = true, sound = true, uiScale = 1 }
local tutorialObjectiveText = "OBJECTIVE  |  Train at the Power Bag"
local openGameTab = function() end
local applyResponsiveLayout = function() end
shared.PunchWallOpenRebirthPanel = function() end
shared.PunchWallRebirthRuntime = {
	armed = false,
	pending = false,
	expiresAt = 0,
	signature = "",
	generation = 0,
	origin = "",
}

local function requestAction(action)
	if action == "Train" and gui then
		actionRemote:FireServer({ action = action, target = gui:GetAttribute("ContextualActionTarget") })
	else
		actionRemote:FireServer(action)
	end
end

local function requestHumanoidJump()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return false end
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
	if humanoid.UseJumpPower then
		humanoid.JumpPower = math.max(humanoid.JumpPower, 50)
	else
		humanoid.JumpHeight = math.max(humanoid.JumpHeight, 7.2)
	end
	humanoid.Jump = true
	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	gui:SetAttribute("LastJumpRequestedAt", os.clock())
	return true
end

local function decodeJSON(raw, fallback)
	if type(raw) ~= "string" then return fallback end
	local ok, value = pcall(function() return HttpService:JSONDecode(raw) end)
	return ok and value or fallback
end

local function applyThemeIcon(imageLabel, iconName)
	local atlas = GameConfig.UIIconAtlas
	local region = atlas.regions[iconName]
	local standaloneAsset = GameConfig.HeroCityPixelUI and GameConfig.HeroCityPixelUI[iconName]
	if region then
		imageLabel.Image = atlas.image
		imageLabel.ImageRectOffset = Vector2.new(region[1], region[2])
		imageLabel.ImageRectSize = Vector2.new(region[3], region[4])
		imageLabel:SetAttribute("ThemeIconSource", "Atlas")
	elseif type(standaloneAsset) == "string" and standaloneAsset ~= "" then
		imageLabel.Image = standaloneAsset
		imageLabel.ImageRectOffset = Vector2.zero
		imageLabel.ImageRectSize = Vector2.zero
		imageLabel:SetAttribute("ThemeIconSource", "StandaloneAsset")
	else
		local fallback = atlas.regions.Warning
		imageLabel.Image = atlas.image
		imageLabel.ImageRectOffset = Vector2.new(fallback[1], fallback[2])
		imageLabel.ImageRectSize = Vector2.new(fallback[3], fallback[4])
		imageLabel:SetAttribute("ThemeIconSource", "WarningFallback")
	end
	imageLabel.ScaleType = Enum.ScaleType.Fit
	imageLabel.BackgroundTransparency = 1
	imageLabel.BorderSizePixel = 0
	imageLabel:SetAttribute("ThemeIcon", iconName)
	return imageLabel
end

local function createThemeIcon(parent, iconName, position, size, name)
	local icon = Instance.new("ImageLabel")
	icon.Name = name or (iconName .. "Icon")
	icon.Position = position or UDim2.fromOffset(0, 0)
	icon.Size = size or UDim2.fromOffset(32, 32)
	icon.ZIndex = (parent.ZIndex or 1) + 1
	icon.Parent = parent
	return applyThemeIcon(icon, iconName)
end

local function playUISound(soundId, volume, speed)
	if not clientSettings.sound then return end
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 0.45
	sound.PlaybackSpeed = speed or 1
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, 6)
end

local punchImpactSound = Instance.new("Sound")
punchImpactSound.Name = "Punch Impact Channel"
punchImpactSound.SoundId = GameConfig.Audio.Punch
punchImpactSound.Volume = 0.32
punchImpactSound.Parent = SoundService

local function playPunchImpact(speed)
	if not clientSettings.sound then return end
	punchImpactSound:Stop()
	punchImpactSound.TimePosition = 0
	punchImpactSound.PlaybackSpeed = speed or 1
	punchImpactSound:Play()
end

local function pulseHaptic(strength, duration)
	if not clientSettings.motion then return end
	for _, inputType in ipairs({ Enum.UserInputType.Touch, Enum.UserInputType.Gamepad1 }) do
		pcall(function()
			if HapticService:IsMotorSupported(inputType, Enum.VibrationMotor.Small) then
				HapticService:SetMotor(inputType, Enum.VibrationMotor.Small, strength or 0.35)
				task.delay(duration or 0.06, function()
					pcall(function() HapticService:SetMotor(inputType, Enum.VibrationMotor.Small, 0) end)
				end)
			end
		end)
	end
end

gui = Instance.new("ScreenGui")
gui.Name = "PunchWallHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
gui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.FullscreenExtension
gui.ClipToDeviceSafeArea = true
gui:SetAttribute("Theme", PolishConfig.StyleName)
gui.Parent = player:WaitForChild("PlayerGui")

local backgroundMusic = Instance.new("Sound")
backgroundMusic.Name = "Hero Forest Music"
backgroundMusic.SoundId = GameConfig.Audio.Music
backgroundMusic.Volume = GameConfig.Audio.MusicVolume or 0.22
backgroundMusic.Looped = true
backgroundMusic.Parent = SoundService
backgroundMusic:SetAttribute("MusicRequested", true)
backgroundMusic:Play()
task.spawn(function()
	local loaded, loadError = pcall(function()
		ContentProvider:PreloadAsync({ backgroundMusic })
	end)
	backgroundMusic:SetAttribute("MusicLoaded", loaded and backgroundMusic.IsLoaded)
	if not loaded then backgroundMusic:SetAttribute("MusicLoadError", tostring(loadError)) end
	if clientSettings.sound and not backgroundMusic.IsPlaying then backgroundMusic:Play() end
end)

shared.PunchWallApplySoundSetting = function(enabled, persist)
	clientSettings.sound = enabled == true
	local currentTier = tonumber(gui and gui:GetAttribute("ActiveMaterialTier")) or 1
	backgroundMusic.Volume = clientSettings.sound
		and ((GameConfig.Audio.MusicVolume or 0.22) + math.min(currentTier - 1, 5) * 0.008)
		or 0
	if clientSettings.sound and not backgroundMusic.IsPlaying then backgroundMusic:Play() end
	if shared.PunchWallSoundToolButton then
		shared.PunchWallSoundToolButton.ImageColor3 = clientSettings.sound and Color3.new(1, 1, 1) or Color3.fromRGB(104, 112, 118)
		shared.PunchWallSoundToolButton.ImageTransparency = clientSettings.sound and 0 or 0.18
		shared.PunchWallSoundToolButton:SetAttribute("SoundEnabled", clientSettings.sound)
	end
	if gui then
		gui:SetAttribute("SoundEnabled", clientSettings.sound)
		gui:SetAttribute("MusicPlaying", backgroundMusic.IsPlaying)
		gui:SetAttribute("MusicSoundId", backgroundMusic.SoundId)
	end
	if persist then
		actionRemote:FireServer({ action = "UpdateSettings", value = clientSettings })
	end
	return clientSettings.sound
end

do
local modalCoreGuiRuntime = {
	owners = {},
	snapshot = nil,
}

local function captureCoreGuiSnapshot()
	local snapshot = {
		types = {},
		topbarKnown = false,
		topbarEnabled = false,
	}
	for _, coreGuiType in ipairs(Enum.CoreGuiType:GetEnumItems()) do
		if coreGuiType ~= Enum.CoreGuiType.All then
			local ok, enabled = pcall(function()
				return StarterGui:GetCoreGuiEnabled(coreGuiType)
			end)
			if ok then snapshot.types[coreGuiType] = enabled == true end
		end
	end
	local ok, enabled = pcall(function()
		return StarterGui:GetCore("TopbarEnabled")
	end)
	if ok then
		snapshot.topbarKnown = true
		snapshot.topbarEnabled = enabled == true
	end
	return snapshot
end

local function coreGuiOwnerCount()
	local count = 0
	for _ in pairs(modalCoreGuiRuntime.owners) do count += 1 end
	return count
end

local function applyModalCoreGuiState()
	local ownerCount = coreGuiOwnerCount()
	if ownerCount > 0 then
		pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false) end)
		pcall(function() StarterGui:SetCore("TopbarEnabled", false) end)
	elseif modalCoreGuiRuntime.snapshot then
		for coreGuiType, enabled in pairs(modalCoreGuiRuntime.snapshot.types) do
			pcall(function() StarterGui:SetCoreGuiEnabled(coreGuiType, enabled) end)
		end
		if modalCoreGuiRuntime.snapshot.topbarKnown then
			pcall(function()
				StarterGui:SetCore("TopbarEnabled", modalCoreGuiRuntime.snapshot.topbarEnabled)
			end)
		end
		modalCoreGuiRuntime.snapshot = nil
	end
	if gui then
		gui:SetAttribute("ModalCoreGuiHidden", ownerCount > 0)
		gui:SetAttribute("ModalCoreGuiOwnerCount", ownerCount)
		gui:SetAttribute("ModalCoreGuiRestoreMode", "ExactPerTypeSnapshotV1")
	end
end

shared.PunchWallSetModalCoreGuiHidden = function(hidden, owner)
	local ownerKey = tostring(owner or "DefaultModal")
	if hidden == true then
		if coreGuiOwnerCount() == 0 then
			modalCoreGuiRuntime.snapshot = captureCoreGuiSnapshot()
		end
		modalCoreGuiRuntime.owners[ownerKey] = true
	else
		modalCoreGuiRuntime.owners[ownerKey] = nil
	end
	applyModalCoreGuiState()
end
end

do
local Lighting = game:GetService("Lighting")
local TIER_ATMOSPHERE_COLORS = {
	Color3.fromRGB(225, 246, 226), Color3.fromRGB(231, 239, 242),
	Color3.fromRGB(211, 226, 239), Color3.fromRGB(201, 242, 249),
	Color3.fromRGB(255, 222, 207), Color3.fromRGB(203, 234, 250),
	Color3.fromRGB(224, 226, 239), Color3.fromRGB(255, 207, 188),
	Color3.fromRGB(216, 211, 251), Color3.fromRGB(195, 228, 249),
}
local tierAtmosphereCache = {
	tier = nil,
	motion = nil,
	sound = nil,
	colorEffect = nil,
	atmosphere = nil,
	gameRoot = nil,
	landmarks = nil,
	dirty = true,
	rootConnections = {},
	landmarkConnections = {},
}
local tierAtmosphereApplyCount = 0
local tierAtmosphereLandmarkScanCount = 0
local latestTierAtmosphereDepth = nil
local tierAtmosphereRefreshScheduled = false

local function invalidateTierAtmosphere(reason, scheduleRefresh)
	local becameDirty = not tierAtmosphereCache.dirty
	tierAtmosphereCache.dirty = true
	if becameDirty then
		gui:SetAttribute("TierAtmosphereCacheDirty", true)
		gui:SetAttribute("TierAtmosphereInvalidationReason", tostring(reason or "manual"))
	end
	if scheduleRefresh == false
		or latestTierAtmosphereDepth == nil
		or tierAtmosphereRefreshScheduled
	then
		return
	end
	tierAtmosphereRefreshScheduled = true
	gui:SetAttribute("TierAtmosphereRefreshScheduled", true)
	task.defer(function()
		tierAtmosphereRefreshScheduled = false
		gui:SetAttribute("TierAtmosphereRefreshScheduled", false)
		if shared.PunchWallUpdateTierAtmosphere then
			shared.PunchWallUpdateTierAtmosphere(latestTierAtmosphereDepth)
		end
	end)
end

local function disconnectTierAtmosphereConnections(connections)
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	table.clear(connections)
end

local function useTierAtmosphereRoot(gameRoot)
	if tierAtmosphereCache.gameRoot == gameRoot then return end
	disconnectTierAtmosphereConnections(tierAtmosphereCache.rootConnections)
	tierAtmosphereCache.gameRoot = gameRoot
	invalidateTierAtmosphere("game_root_changed", false)
	if not gameRoot then return end
	local function invalidateForLandmarkFolder(child)
		if child.Name == "Depth Tier Landmarks" then
			invalidateTierAtmosphere("landmark_source_replaced")
		end
	end
	table.insert(tierAtmosphereCache.rootConnections, gameRoot.ChildAdded:Connect(invalidateForLandmarkFolder))
	table.insert(tierAtmosphereCache.rootConnections, gameRoot.ChildRemoved:Connect(invalidateForLandmarkFolder))
	table.insert(tierAtmosphereCache.rootConnections, gameRoot.AncestryChanged:Connect(function(_, parent)
		if not parent then
			invalidateTierAtmosphere("game_root_removed")
		end
	end))
end

local function useTierAtmosphereLandmarks(landmarks)
	if tierAtmosphereCache.landmarks == landmarks then return end
	disconnectTierAtmosphereConnections(tierAtmosphereCache.landmarkConnections)
	tierAtmosphereCache.landmarks = landmarks
	invalidateTierAtmosphere("landmark_source_changed", false)
	if not landmarks then return end
	table.insert(tierAtmosphereCache.landmarkConnections, landmarks.DescendantAdded:Connect(function()
		invalidateTierAtmosphere("landmark_descendant_added")
	end))
	table.insert(tierAtmosphereCache.landmarkConnections, landmarks.DescendantRemoving:Connect(function()
		invalidateTierAtmosphere("landmark_descendant_removing")
	end))
	table.insert(tierAtmosphereCache.landmarkConnections, landmarks.AncestryChanged:Connect(function(_, parent)
		if not parent then
			invalidateTierAtmosphere("landmark_source_removed")
		end
	end))
end

workspace.ChildAdded:Connect(function(child)
	if child.Name == "PunchWallRPG" then
		invalidateTierAtmosphere("game_root_added")
	end
end)
workspace.ChildRemoved:Connect(function(child)
	if child.Name == "PunchWallRPG" then
		invalidateTierAtmosphere("game_root_removed")
	end
end)
Lighting.ChildAdded:Connect(function(child)
	if child.Name == "Hero City Color" or child.Name == "Hero City Atmosphere" then
		invalidateTierAtmosphere("lighting_effect_added")
	end
end)
Lighting.ChildRemoved:Connect(function(child)
	if child.Name == "Hero City Color" or child.Name == "Hero City Atmosphere" then
		invalidateTierAtmosphere("lighting_effect_removed")
	end
end)

shared.PunchWallInvalidateTierAtmosphere = invalidateTierAtmosphere
shared.PunchWallUpdateTierAtmosphere = function(depth)
	local normalizedDepth = math.max(0, tonumber(depth) or 0)
	latestTierAtmosphereDepth = normalizedDepth
	local tier = math.clamp(math.floor(math.max(0, normalizedDepth - 1) / 8) + 1, 1, 10)
	local motionEnabled = clientSettings.motion == true
	local soundEnabled = clientSettings.sound == true
	local colorEffect = Lighting:FindFirstChild("Hero City Color")
	local atmosphere = Lighting:FindFirstChild("Hero City Atmosphere")
	local gameRoot = workspace:FindFirstChild("PunchWallRPG")
	local landmarks = gameRoot and gameRoot:FindFirstChild("Depth Tier Landmarks")
	useTierAtmosphereRoot(gameRoot)
	useTierAtmosphereLandmarks(landmarks)
	if not tierAtmosphereCache.dirty
		and tierAtmosphereCache.tier == tier
		and tierAtmosphereCache.motion == motionEnabled
		and tierAtmosphereCache.sound == soundEnabled
		and tierAtmosphereCache.colorEffect == colorEffect
		and tierAtmosphereCache.atmosphere == atmosphere
	then
		return false
	end

	tierAtmosphereCache.tier = tier
	tierAtmosphereCache.motion = motionEnabled
	tierAtmosphereCache.sound = soundEnabled
	tierAtmosphereCache.colorEffect = colorEffect
	tierAtmosphereCache.atmosphere = atmosphere
	tierAtmosphereCache.dirty = false
	tierAtmosphereApplyCount += 1
	gui:SetAttribute("TierAtmosphereApplyCount", tierAtmosphereApplyCount)
	gui:SetAttribute("TierAtmosphereCacheDirty", false)
	gui:SetAttribute(
		"TierAtmosphereCacheKey",
		("%d:%s:%s"):format(tier, motionEnabled and "motion" or "reduced", soundEnabled and "sound" or "muted")
	)

	if colorEffect and colorEffect:IsA("ColorCorrectionEffect") then
		TweenService:Create(colorEffect, TweenInfo.new(0.8), {
			TintColor = TIER_ATMOSPHERE_COLORS[tier],
			Saturation = 0.12 + math.min(tier, 6) * 0.012,
		}):Play()
	end
	if atmosphere and atmosphere:IsA("Atmosphere") then
		TweenService:Create(atmosphere, TweenInfo.new(0.8), { Color = TIER_ATMOSPHERE_COLORS[tier] }):Play()
	end
	backgroundMusic.PlaybackSpeed = 1 + (tier - 1) * 0.012
	backgroundMusic.Volume = soundEnabled and ((GameConfig.Audio.MusicVolume or 0.22) + math.min(tier - 1, 5) * 0.008) or 0
	local activeLandmarks = 0
	if landmarks then
		tierAtmosphereLandmarkScanCount += 1
		for _, landmark in ipairs(landmarks:GetChildren()) do
			local active = landmark:GetAttribute("MaterialTier") == tier
			landmark:SetAttribute("ClientActiveTier", active)
			if active then activeLandmarks += 1 end
			for _, descendant in ipairs(landmark:GetDescendants()) do
				if descendant:IsA("ParticleEmitter") and descendant.Name == "TierParticles" then
					descendant.Enabled = active and motionEnabled
				elseif descendant:IsA("BasePart") and descendant:GetAttribute("TierLandmarkPart") then
					local baseColor = descendant:GetAttribute("BaseColor")
					if typeof(baseColor) == "Color3" then
						descendant.Color = active and baseColor:Lerp(Color3.new(1, 1, 1), 0.18) or baseColor
					end
				end
			end
		end
	end
	gui:SetAttribute("ActiveMaterialTier", tier)
	gui:SetAttribute("ActiveTierLandmarkCount", activeLandmarks)
	gui:SetAttribute("TierAtmosphereLandmarkScanCount", tierAtmosphereLandmarkScanCount)
	gui:SetAttribute("TierMusicVariant", tier)
	gui:SetAttribute("TierAtmosphereApplied", true)
	return true
end
end
gui:SetAttribute("FreeAimPunch", true)
gui:SetAttribute("TargetBlockHUDEnabled", false)
gui:SetAttribute("PunchSoundMode", "SingleChannel")
gui:SetAttribute("PunchAnimationDuration", 0.72)
gui:SetAttribute("PunchWindupSeconds", 0.2)
gui:SetAttribute("PunchLungeStuds", 10.5)
gui:SetAttribute("PunchAttackInterval", 1)
gui:SetAttribute("CenterActionFeedbackEnabled", false)
gui:SetAttribute("PunchCameraHandoffActive", false)

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
end)

local function addHeroAccent(parent, primary)
	local accent = Instance.new("Frame")
	accent.Name = "HeroAccent"
	accent.Position = UDim2.fromOffset(0, 0)
	accent.Size = UDim2.new(1, 0, 0, 4)
	accent.BackgroundColor3 = primary or palette.Punch
	accent.BorderSizePixel = 0
	accent.ZIndex = parent.ZIndex + 4
	accent.Parent = parent
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, primary or palette.Punch),
		ColorSequenceKeypoint.new(0.62, palette.Train),
		ColorSequenceKeypoint.new(1, palette.Use),
	})
	gradient.Parent = accent
	return accent
end

local hitFlash = Instance.new("Frame")
hitFlash.Name = "HitFlash"
hitFlash.BackgroundColor3 = palette.Punch
hitFlash.BackgroundTransparency = 1
hitFlash.BorderSizePixel = 0
hitFlash.Size = UDim2.fromScale(1, 1)
hitFlash.Visible = false
hitFlash.ZIndex = 50
hitFlash.Parent = gui

local spawnReveal = Instance.new("Frame")
spawnReveal.Name = "HeroCitySpawnReveal"
spawnReveal.BackgroundColor3 = palette.Ink
spawnReveal.BackgroundTransparency = 0.04
spawnReveal.BorderSizePixel = 0
spawnReveal.Size = UDim2.fromScale(1, 1)
spawnReveal.ZIndex = 80
spawnReveal.Parent = gui
shared.PunchWallRevealGradient = Instance.new("UIGradient")
shared.PunchWallRevealGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(8, 16, 23)),
	ColorSequenceKeypoint.new(0.48, Color3.fromRGB(29, 38, 47)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 31, 45)),
})
shared.PunchWallRevealGradient.Rotation = 12
shared.PunchWallRevealGradient.Parent = spawnReveal
shared.PunchWallRevealSlash = Instance.new("Frame")
shared.PunchWallRevealSlash.Name = "HeroSlash"
shared.PunchWallRevealSlash.AnchorPoint = Vector2.new(0.5, 0.5)
shared.PunchWallRevealSlash.Position = UDim2.fromScale(0.5, 0.48)
shared.PunchWallRevealSlash.Size = UDim2.new(0.86, 0, 0, 8)
shared.PunchWallRevealSlash.Rotation = -4
shared.PunchWallRevealSlash.BackgroundColor3 = palette.Punch
shared.PunchWallRevealSlash.BackgroundTransparency = 0.08
shared.PunchWallRevealSlash.BorderSizePixel = 0
shared.PunchWallRevealSlash.ZIndex = 80
shared.PunchWallRevealSlash.Parent = spawnReveal
local revealTitle = Instance.new("TextLabel")
revealTitle.BackgroundTransparency = 1
revealTitle.AnchorPoint = Vector2.new(0.5, 0.5)
revealTitle.Position = UDim2.fromScale(0.5, 0.44)
revealTitle.Size = UDim2.new(0.8, 0, 0, 80)
revealTitle.Font = Enum.Font.GothamBlack
revealTitle.Text = "SMASH WALL"
revealTitle.TextColor3 = palette.Text
revealTitle.TextStrokeColor3 = palette.Punch
revealTitle.TextStrokeTransparency = 0.15
revealTitle.TextScaled = true
revealTitle.ZIndex = 81
revealTitle.Parent = spawnReveal
local revealSubtitle = Instance.new("TextLabel")
revealSubtitle.BackgroundTransparency = 1
revealSubtitle.AnchorPoint = Vector2.new(0.5, 0)
revealSubtitle.Position = UDim2.fromScale(0.5, 0.54)
revealSubtitle.Size = UDim2.new(0.8, 0, 0, 34)
revealSubtitle.Font = Enum.Font.GothamBlack
revealSubtitle.Text = "WORLD 1  |  FOREST BREAKTHROUGH"
revealSubtitle.TextColor3 = palette.Reward
revealSubtitle.TextSize = 16
revealSubtitle.ZIndex = 81
revealSubtitle.Parent = spawnReveal
shared.PunchWallRevealStatus = Instance.new("TextLabel")
shared.PunchWallRevealStatus.Name = "LoadingStatus"
shared.PunchWallRevealStatus.BackgroundTransparency = 1
shared.PunchWallRevealStatus.AnchorPoint = Vector2.new(0.5, 0)
shared.PunchWallRevealStatus.Position = UDim2.fromScale(0.5, 0.645)
shared.PunchWallRevealStatus.Size = UDim2.new(0.68, 0, 0, 24)
shared.PunchWallRevealStatus.Font = Enum.Font.GothamBold
shared.PunchWallRevealStatus.Text = "PREPARING HERO GEAR..."
shared.PunchWallRevealStatus.TextColor3 = Color3.fromRGB(205, 225, 236)
shared.PunchWallRevealStatus.TextSize = 12
shared.PunchWallRevealStatus.ZIndex = 81
shared.PunchWallRevealStatus.Parent = spawnReveal
shared.PunchWallRevealFist = Instance.new("ImageLabel")
shared.PunchWallRevealFist.Name = "LoadingFist"
shared.PunchWallRevealFist.AnchorPoint = Vector2.new(0.5, 1)
shared.PunchWallRevealFist.BackgroundTransparency = 1
shared.PunchWallRevealFist.Position = UDim2.fromScale(0.5, 0.39)
shared.PunchWallRevealFist.Size = UDim2.fromOffset(126, 126)
shared.PunchWallRevealFist.Image = GameConfig.ShopArt.StarterGlove
shared.PunchWallRevealFist.ScaleType = Enum.ScaleType.Fit
shared.PunchWallRevealFist.ZIndex = 81
shared.PunchWallRevealFist.Parent = spawnReveal
shared.PunchWallRevealTrack = Instance.new("Frame")
shared.PunchWallRevealTrack.Name = "LoadingTrack"
shared.PunchWallRevealTrack.AnchorPoint = Vector2.new(0.5, 0)
shared.PunchWallRevealTrack.Position = UDim2.fromScale(0.5, 0.61)
shared.PunchWallRevealTrack.Size = UDim2.new(0.34, 0, 0, 9)
shared.PunchWallRevealTrack.BackgroundColor3 = Color3.fromRGB(31, 42, 51)
shared.PunchWallRevealTrack.BorderSizePixel = 0
shared.PunchWallRevealTrack.ZIndex = 81
shared.PunchWallRevealTrack.Parent = spawnReveal
shared.PunchWallRevealFill = Instance.new("Frame")
shared.PunchWallRevealFill.Name = "Fill"
shared.PunchWallRevealFill.Size = UDim2.fromScale(0.08, 1)
shared.PunchWallRevealFill.BackgroundColor3 = palette.HeroCyan
shared.PunchWallRevealFill.BorderSizePixel = 0
shared.PunchWallRevealFill.ZIndex = 82
shared.PunchWallRevealFill.Parent = shared.PunchWallRevealTrack

shared.PunchWallSetSpawnRevealVisible = function(visible)
	spawnReveal.Visible = visible
	spawnReveal.Active = visible
	spawnReveal.BackgroundTransparency = visible and 0.04 or 1
	shared.PunchWallRevealSlash.BackgroundTransparency = visible and 0.08 or 1
	revealTitle.TextTransparency = visible and 0 or 1
	revealTitle.TextStrokeTransparency = visible and 0.15 or 1
	revealSubtitle.TextTransparency = visible and 0 or 1
	shared.PunchWallRevealStatus.TextTransparency = visible and 0 or 1
	shared.PunchWallRevealFist.ImageTransparency = visible and 0 or 1
	shared.PunchWallRevealTrack.BackgroundTransparency = visible and 0 or 1
	shared.PunchWallRevealFill.BackgroundTransparency = visible and 0 or 1
end

shared.PunchWallReplayLoading = function()
	shared.PunchWallRevealFill.Size = UDim2.fromScale(1, 1)
	shared.PunchWallRevealStatus.Text = "HERO SYSTEMS READY"
	shared.PunchWallSetSpawnRevealVisible(true)
	gui:SetAttribute("LoadingReplayVisible", true)
	return true
end
shared.PunchWallHideLoading = function()
	shared.PunchWallSetSpawnRevealVisible(false)
	gui:SetAttribute("LoadingReplayVisible", false)
	return true
end

task.spawn(function()
	local startedAt = os.clock()
	TweenService:Create(shared.PunchWallRevealFill, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.fromScale(0.82, 1) }):Play()
	-- Preload the live instances, not raw private asset IDs. ContentProvider can
	-- resolve every image, mesh, texture, and sound referenced by these trees and
	-- reports reliable fetch status for the exact content the player will see.
	task.wait(0.05)
	local shopCoinPreload = Instance.new("ImageLabel")
	shopCoinPreload.Name = "ShopCoinPreload"
	shopCoinPreload.BackgroundTransparency = 1
	shopCoinPreload.Image = GameConfig.ShopArt.ShopCoinIcon
	shopCoinPreload.ImageTransparency = 1
	shopCoinPreload.Size = UDim2.fromOffset(1, 1)
	shopCoinPreload.Visible = false
	shopCoinPreload.Parent = gui
	local preloadTargets = { gui, punchImpactSound, backgroundMusic, shopCoinPreload }
	local visualAssets = ReplicatedStorage:FindFirstChild("PunchWallVisualAssets")
	if visualAssets then table.insert(preloadTargets, visualAssets) end
	local gameRoot = workspace:WaitForChild("PunchWallRPG", 5)
	local forestVisuals = gameRoot and gameRoot:FindFirstChild("World 1 Forest")
	if forestVisuals then table.insert(preloadTargets, forestVisuals) end
	local failedAssets = 0
	local loadedAssets = 0
	local loaded = pcall(function()
		ContentProvider:PreloadAsync(preloadTargets, function(_, status)
			if status == Enum.AssetFetchStatus.Failure then
				failedAssets += 1
			elseif status == Enum.AssetFetchStatus.Success then
				loadedAssets += 1
			end
		end)
	end)
	shopCoinPreload:Destroy()
	local elapsed = os.clock() - startedAt
	local minimumDisplay = 1.65 - elapsed
	if minimumDisplay > 0 then task.wait(minimumDisplay) end
	shared.PunchWallRevealFill.Size = UDim2.fromScale(1, 1)
	shared.PunchWallRevealStatus.Text = loaded and "HERO SYSTEMS READY" or "STARTING WITH SAFE VISUALS"
	gui:SetAttribute("CriticalAssetCount", loadedAssets + failedAssets)
	gui:SetAttribute("CriticalAssetSuccesses", loadedAssets)
	gui:SetAttribute("CriticalAssetFailures", failedAssets)
	gui:SetAttribute("CriticalPreloadDuration", os.clock() - startedAt)
	gui:SetAttribute("CriticalAssetsPreloaded", loaded and failedAssets == 0)
	gui:SetAttribute("SpawnRevealPlayed", true)
	TweenService:Create(spawnReveal, TweenInfo.new(0.38), { BackgroundTransparency = 1 }):Play()
	for _, item in ipairs({ shared.PunchWallRevealSlash, revealTitle, revealSubtitle, shared.PunchWallRevealStatus, shared.PunchWallRevealFist, shared.PunchWallRevealTrack }) do
		if item:IsA("TextLabel") then
			TweenService:Create(item, TweenInfo.new(0.3), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		elseif item:IsA("ImageLabel") then
			TweenService:Create(item, TweenInfo.new(0.3), { ImageTransparency = 1 }):Play()
		else
			TweenService:Create(item, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
		end
	end
	task.delay(0.42, function()
		if spawnReveal.Parent then
			spawnReveal.Visible = false
			spawnReveal.Active = false
		end
	end)
end)

if RunService:IsStudio() then
	local automation = Instance.new("BindableFunction")
	automation.Name = "PunchWallClientAutomation"
	automation.OnInvoke = function(action)
		requestAction(action)
		return true
	end
	automation.Parent = gui
end

local panel = Instance.new("Frame")
panel.Name = "StatsPanel"
panel.AnchorPoint = Vector2.new(0, 0)
panel.Position = UDim2.fromOffset(18, 18)
panel.Size = UDim2.fromOffset(310, 196)
panel.BackgroundColor3 = palette.Panel
panel.BackgroundTransparency = 0.03
panel.BorderSizePixel = 0
panel.Parent = gui
addHeroAccent(panel, palette.Punch)

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 8)
panelCorner.Parent = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = palette.RoadLine
panelStroke.Thickness = 2
panelStroke.Parent = panel

local panelScale = Instance.new("UIScale")
panelScale.Name = "ResponsiveScale"
panelScale.Parent = panel

local title = Instance.new("TextLabel")
title.Name = "Title"
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(14, 10)
title.Size = UDim2.new(1, -28, 0, 30)
title.Font = Enum.Font.GothamBlack
title.Text = "HERO STATUS"
title.TextColor3 = palette.Text
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = panel

local statsList = Instance.new("Frame")
statsList.BackgroundTransparency = 1
statsList.Position = UDim2.fromOffset(14, 46)
statsList.Size = UDim2.new(1, -28, 1, -58)
statsList.Parent = panel

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 4)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = statsList

local labels = {}
local order = {
	"Power",
	"Coins",
	"WallLevel",
	"EquippedFist",
	"Pet",
	"Rebirths",
}

local statIcons = {
	Power = "Power",
	Coins = "Coin",
	WallLevel = "Wall",
	EquippedFist = "StarterFist",
	Pet = "Pet",
	Rebirths = "Rebirth",
}

local function formatNumber(value)
	value = tonumber(value) or 0
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

for index, key in ipairs(order) do
	local label = Instance.new("TextLabel")
	label.Name = key
	label.BackgroundColor3 = palette.PanelSoft
	label.BackgroundTransparency = 0.12
	label.Size = UDim2.new(1, 0, 0, 20)
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = palette.Text
	label.TextSize = 14
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.LayoutOrder = index
	label.Text = key .. ": ..."
	label.Parent = statsList
	local rowCorner = Instance.new("UICorner")
	rowCorner.CornerRadius = UDim.new(0, 4)
	rowCorner.Parent = label
	local rowPadding = Instance.new("UIPadding")
	rowPadding.PaddingLeft = UDim.new(0, 27)
	rowPadding.PaddingRight = UDim.new(0, 5)
	rowPadding.Parent = label
	createThemeIcon(label, statIcons[key], UDim2.fromOffset(-25, 1), UDim2.fromOffset(18, 18), "StatIcon")
	labels[key] = label
end

panel.Visible = false

local statusDeck = Instance.new("Frame")
statusDeck.Name = "HeroStatusDeck"
statusDeck.AnchorPoint = Vector2.new(0.5, 0)
statusDeck.Position = UDim2.new(0.5, 0, 0, 14)
statusDeck.Size = UDim2.fromOffset(820, 78)
statusDeck.BackgroundTransparency = 1
statusDeck.Parent = gui
local statusDeckScale = Instance.new("UIScale")
statusDeckScale.Name = "ResponsiveScale"
statusDeckScale.Parent = statusDeck

local statusLayout = Instance.new("UIListLayout")
statusLayout.FillDirection = Enum.FillDirection.Horizontal
statusLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
statusLayout.Padding = UDim.new(0, 12)
statusLayout.SortOrder = Enum.SortOrder.LayoutOrder
statusLayout.Parent = statusDeck

local statusValues = {}
local function createStatusCard(key, caption, iconName, width, accent)
	local card = Instance.new("Frame")
	card.Name = key .. "Card"
	card.Size = UDim2.fromOffset(width, 72)
	card.BackgroundColor3 = palette.Ink
	card.BackgroundTransparency = 0.03
	card.BorderSizePixel = 0
	card.Parent = statusDeck
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 7)
	corner.Parent = card
	local stroke = Instance.new("UIStroke")
	stroke.Color = accent
	stroke.Thickness = 3
	stroke.Parent = card
	local slash = Instance.new("Frame")
	slash.Name = "ComicSlash"
	slash.Position = UDim2.new(1, -16, 0, 7)
	slash.Size = UDim2.fromOffset(6, 58)
	slash.Rotation = 12
	slash.BackgroundColor3 = accent
	slash.BorderSizePixel = 0
	slash.Parent = card
	createThemeIcon(card, iconName, UDim2.fromOffset(10, 9), UDim2.fromOffset(54, 54), "StatusIcon")
	local captionLabel = Instance.new("TextLabel")
	captionLabel.BackgroundTransparency = 1
	captionLabel.Position = UDim2.fromOffset(70, 8)
	captionLabel.Size = UDim2.new(1, -88, 0, 20)
	captionLabel.Font = Enum.Font.GothamBlack
	captionLabel.Text = caption
	captionLabel.TextColor3 = Color3.fromRGB(242, 244, 247)
	captionLabel.TextSize = 13
	captionLabel.TextXAlignment = Enum.TextXAlignment.Left
	captionLabel.Parent = card
	local valueLabel = Instance.new("TextLabel")
	valueLabel.Name = "Value"
	valueLabel.BackgroundTransparency = 1
	valueLabel.Position = UDim2.fromOffset(70, 27)
	valueLabel.Size = UDim2.new(1, -88, 0, 36)
	valueLabel.Font = Enum.Font.GothamBlack
	valueLabel.Text = "0"
	valueLabel.TextColor3 = accent
	valueLabel.TextSize = 27
	valueLabel.TextXAlignment = Enum.TextXAlignment.Left
	valueLabel.Parent = card
	statusValues[key] = valueLabel
	return card
end

createStatusCard("Power", "POWER", "Power", 248, palette.Train)
createStatusCard("Coins", "COINS", "Coin", 248, palette.Reward)
createStatusCard("WallLevel", "WALL LV.", "Wall", 248, palette.Use)
statusDeck.PowerCard.LayoutOrder = 1
statusDeck.CoinsCard.LayoutOrder = 2
statusDeck.WallLevelCard.LayoutOrder = 3

local help = Instance.new("TextLabel")
help.Name = "ObjectiveCard"
help.AnchorPoint = Vector2.new(1, 0)
help.Position = UDim2.new(1, -18, 0, 112)
help.Size = UDim2.fromOffset(286, 98)
help.BackgroundColor3 = palette.PanelSoft
help.BackgroundTransparency = 0.04
help.BorderSizePixel = 0
help.Font = Enum.Font.GothamBold
help.Text = "OBJECTIVE  |  Train at the Power Bag"
help.TextColor3 = palette.Text
help.TextSize = 14
help.TextXAlignment = Enum.TextXAlignment.Left
help.TextWrapped = true
help.Parent = gui
addHeroAccent(help, palette.Punch)

local helpCorner = Instance.new("UICorner")
helpCorner.CornerRadius = UDim.new(0, 8)
helpCorner.Parent = help

local helpPadding = Instance.new("UIPadding")
helpPadding.PaddingLeft = UDim.new(0, 56)
helpPadding.PaddingRight = UDim.new(0, 12)
helpPadding.PaddingTop = UDim.new(0, 9)
helpPadding.PaddingBottom = UDim.new(0, 15)
helpPadding.Parent = help
createThemeIcon(help, "Quest", UDim2.fromOffset(-49, 13), UDim2.fromOffset(42, 42), "ObjectiveIcon")

local objectiveProgress = Instance.new("Frame")
objectiveProgress.Name = "ObjectiveProgress"
objectiveProgress.Position = UDim2.new(0, 10, 1, -12)
objectiveProgress.Size = UDim2.new(1, -20, 0, 7)
objectiveProgress.BackgroundColor3 = Color3.fromRGB(65, 72, 78)
objectiveProgress.BorderSizePixel = 0
objectiveProgress.Parent = help
local objectiveProgressCorner = Instance.new("UICorner")
objectiveProgressCorner.CornerRadius = UDim.new(1, 0)
objectiveProgressCorner.Parent = objectiveProgress
local objectiveProgressFill = Instance.new("Frame")
objectiveProgressFill.Name = "Fill"
objectiveProgressFill.Size = UDim2.fromScale(0.2, 1)
objectiveProgressFill.BackgroundColor3 = palette.Train
objectiveProgressFill.BorderSizePixel = 0
objectiveProgressFill.Parent = objectiveProgress
local objectiveProgressFillCorner = Instance.new("UICorner")
objectiveProgressFillCorner.CornerRadius = UDim.new(1, 0)
objectiveProgressFillCorner.Parent = objectiveProgressFill

local mobileControls = Instance.new("Frame")
mobileControls.Name = "MobileControls"
mobileControls.AnchorPoint = Vector2.new(1, 1)
mobileControls.BackgroundTransparency = 1
mobileControls.Position = UDim2.new(1, -18, 1, -18)
mobileControls.Size = UDim2.fromOffset(330, 170)
mobileControls.Visible = true
mobileControls.Parent = gui

local mobileLayout = Instance.new("UIGridLayout")
mobileLayout.CellPadding = UDim2.fromOffset(8, 8)
mobileLayout.CellSize = UDim2.fromOffset(92, 46)
mobileLayout.FillDirectionMaxCells = 2
mobileLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
mobileLayout.VerticalAlignment = Enum.VerticalAlignment.Center
mobileLayout.SortOrder = Enum.SortOrder.LayoutOrder
mobileLayout.Parent = mobileControls

local function makeActionButton(name, text, action, orderIndex, color)
	local button = Instance.new("TextButton")
	button.Name = name
	button.LayoutOrder = orderIndex
	button.Size = UDim2.fromOffset(92, 46)
	button.BackgroundColor3 = palette.Ink
	button.BackgroundTransparency = 0.06
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBlack
	button.Text = text
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 12
	button.TextXAlignment = Enum.TextXAlignment.Right
	button.AutoButtonColor = true
	button.Parent = mobileControls
	local buttonPadding = Instance.new("UIPadding")
	buttonPadding.PaddingLeft = UDim.new(0, 38)
	buttonPadding.PaddingRight = UDim.new(0, 8)
	buttonPadding.Parent = button
	local iconName = action == "Punch" and "Punch" or action == "Train" and "Train" or "Use"
	createThemeIcon(button, iconName, UDim2.fromOffset(-33, 6), UDim2.fromOffset(34, 34), "ActionIcon")

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button

	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Transparency = 0.08
	stroke.Thickness = 2
	stroke.Parent = button
	addHeroAccent(button, color)

	local scale = Instance.new("UIScale")
	scale.Name = "PressScale"
	scale.Scale = 1
	scale.Parent = button

	button.MouseButton1Click:Connect(function()
		if clientSettings.motion then
			TweenService:Create(scale, TweenInfo.new(PolishConfig.Motion.ButtonPressSeconds), { Scale = 0.92 }):Play()
			task.delay(PolishConfig.Motion.ButtonPressSeconds, function()
				if scale.Parent then
					TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1 }):Play()
				end
			end)
		end
		if action == "Jump" then
			requestHumanoidJump()
		else
			requestAction(action)
		end
	end)

	return button
end

local punchButton = makeActionButton("ActionPunch", "PUNCH", "Punch", 1, palette.Punch)
local trainButton = makeActionButton("ActionTrain", "TRAIN", "Train", 2, palette.Train)
local useButton = makeActionButton("ActionUse", "USE", "Use", 3, palette.Use)
local jumpButton = makeActionButton("ActionJump", "JUMP", "Jump", 4, palette.Use)

mobileLayout:Destroy()
for _, button in ipairs({ punchButton, jumpButton }) do
	button.AnchorPoint = Vector2.new(1, 1)
	button.Size = UDim2.fromOffset(126, 126)
	button.TextSize = 18
	button.TextXAlignment = Enum.TextXAlignment.Center
	local padding = button:FindFirstChildOfClass("UIPadding")
	if padding then padding:Destroy() end
	local icon = button:FindFirstChild("ActionIcon")
	if icon then
		icon.Position = UDim2.new(0.5, -34, 0, 12)
		icon.Size = UDim2.fromOffset(68, 68)
	end
	local corner = button:FindFirstChildOfClass("UICorner")
	if corner then corner.CornerRadius = UDim.new(1, 0) end
end
punchButton.Position = UDim2.new(1, 0, 1, 0)
jumpButton.Position = UDim2.new(1, -136, 1, -4)
jumpButton.Size = UDim2.fromOffset(108, 108)
local jumpIcon = jumpButton:FindFirstChild("ActionIcon")
if jumpIcon then jumpIcon.Visible = false end
jumpButton.TextXAlignment = Enum.TextXAlignment.Center
jumpButton.TextYAlignment = Enum.TextYAlignment.Center
trainButton.AnchorPoint = Vector2.new(1, 0)
trainButton.Position = UDim2.new(1, -141, 0, 0)
trainButton.Size = UDim2.fromOffset(88, 42)
useButton.AnchorPoint = Vector2.new(1, 0)
useButton.Position = UDim2.new(1, -48, 0, 0)
useButton.Size = UDim2.fromOffset(88, 42)

local nextWorld = Instance.new("Frame")
nextWorld.Name = "NextWorldProgress"
nextWorld.AnchorPoint = Vector2.new(0.5, 1)
nextWorld.Position = UDim2.new(0.5, 0, 1, -18)
nextWorld.Size = UDim2.fromOffset(250, 76)
nextWorld.BackgroundColor3 = palette.Ink
nextWorld.BackgroundTransparency = 0.05
nextWorld.BorderSizePixel = 0
nextWorld.Parent = gui
local nextCorner = Instance.new("UICorner")
nextCorner.CornerRadius = UDim.new(0, 7)
nextCorner.Parent = nextWorld
local nextStroke = Instance.new("UIStroke")
nextStroke.Color = palette.Use
nextStroke.Thickness = 2
nextStroke.Parent = nextWorld
local nextTitle = Instance.new("TextLabel")
nextTitle.BackgroundTransparency = 1
nextTitle.Position = UDim2.fromOffset(12, 7)
nextTitle.Size = UDim2.new(1, -24, 0, 18)
nextTitle.Font = Enum.Font.GothamBlack
nextTitle.Text = "NEXT WORLD  |  DOWNTOWN"
nextTitle.TextColor3 = palette.Text
nextTitle.TextSize = 12
nextTitle.TextXAlignment = Enum.TextXAlignment.Left
nextTitle.Parent = nextWorld
local nextTrack = Instance.new("Frame")
nextTrack.Position = UDim2.fromOffset(12, 35)
nextTrack.Size = UDim2.new(1, -24, 0, 22)
nextTrack.BackgroundColor3 = Color3.fromRGB(30, 35, 41)
nextTrack.BorderSizePixel = 0
nextTrack.Parent = nextWorld
local nextFill = Instance.new("Frame")
nextFill.Name = "Fill"
nextFill.Size = UDim2.fromScale(0.02, 1)
nextFill.BackgroundColor3 = palette.Reward
nextFill.BorderSizePixel = 0
nextFill.Parent = nextTrack
local nextPercent = Instance.new("TextLabel")
nextPercent.Name = "Percent"
nextPercent.BackgroundTransparency = 1
nextPercent.Size = UDim2.fromScale(1, 1)
nextPercent.Font = Enum.Font.GothamBlack
nextPercent.Text = "2%"
nextPercent.TextColor3 = Color3.new(1, 1, 1)
nextPercent.TextSize = 13
nextPercent.ZIndex = 3
nextPercent.Parent = nextTrack

local contextLabel = Instance.new("TextLabel")
contextLabel.Name = "ContextTarget"
contextLabel.AnchorPoint = Vector2.new(0.5, 1)
contextLabel.Position = UDim2.new(0.5, 0, 1, -92)
contextLabel.Size = UDim2.fromOffset(220, 30)
contextLabel.BackgroundColor3 = palette.Panel
contextLabel.BackgroundTransparency = 0.08
contextLabel.BorderSizePixel = 0
contextLabel.Font = Enum.Font.GothamBold
contextLabel.Text = "Move near a target"
contextLabel.TextColor3 = palette.Text
contextLabel.TextSize = 13
contextLabel.TextTruncate = Enum.TextTruncate.AtEnd
contextLabel.Parent = gui

local contextCorner = Instance.new("UICorner")
contextCorner.CornerRadius = UDim.new(0, 6)
contextCorner.Parent = contextLabel

local targetHUD = Instance.new("Frame")
targetHUD.Name = "TargetWallHUD"
targetHUD.AnchorPoint = Vector2.new(0.5, 0)
targetHUD.Position = UDim2.new(0.5, 0, 0, 82)
targetHUD.Size = UDim2.fromOffset(370, 62)
targetHUD.BackgroundColor3 = palette.Panel
targetHUD.BackgroundTransparency = 1
targetHUD.BorderSizePixel = 0
targetHUD.Visible = false
targetHUD.ZIndex = 35
targetHUD.Parent = gui
addHeroAccent(targetHUD, palette.Punch)

local targetCorner = Instance.new("UICorner")
targetCorner.CornerRadius = UDim.new(0, 8)
targetCorner.Parent = targetHUD
createThemeIcon(targetHUD, "Wall", UDim2.fromOffset(6, 10), UDim2.fromOffset(40, 40), "TargetIcon")
targetHUD.TargetIcon.Visible = false
targetHUD.HeroAccent.Visible = false

local targetTitle = Instance.new("TextLabel")
targetTitle.Name = "TargetTitle"
targetTitle.BackgroundColor3 = Color3.fromRGB(13, 16, 20)
targetTitle.BackgroundTransparency = 0.02
targetTitle.Position = UDim2.fromOffset(0, 0)
targetTitle.Size = UDim2.new(1, 0, 0, 28)
targetTitle.Font = Enum.Font.GothamBlack
targetTitle.Text = "TARGET"
targetTitle.TextColor3 = palette.Text
targetTitle.TextSize = 18
targetTitle.TextXAlignment = Enum.TextXAlignment.Center
targetTitle.ZIndex = 36
targetTitle.Parent = targetHUD

local targetTrack = Instance.new("Frame")
targetTrack.Name = "HealthTrack"
targetTrack.Position = UDim2.fromOffset(0, 32)
targetTrack.Size = UDim2.new(1, 0, 0, 28)
targetTrack.BackgroundColor3 = palette.Ink
targetTrack.BorderSizePixel = 0
targetTrack.ZIndex = 36
targetTrack.Parent = targetHUD
local targetTrackCorner = Instance.new("UICorner")
targetTrackCorner.CornerRadius = UDim.new(0, 5)
targetTrackCorner.Parent = targetTrack

local targetFill = Instance.new("Frame")
targetFill.Name = "HealthFill"
targetFill.Size = UDim2.fromScale(1, 1)
targetFill.BackgroundColor3 = palette.Punch
targetFill.BorderSizePixel = 0
targetFill.ZIndex = 36
targetFill.Parent = targetTrack
local targetGradient = Instance.new("UIGradient")
targetGradient.Color = ColorSequence.new(Color3.fromRGB(255, 80, 62), Color3.fromRGB(255, 183, 62))
targetGradient.Parent = targetFill
local targetFillCorner = Instance.new("UICorner")
targetFillCorner.CornerRadius = UDim.new(0, 5)
targetFillCorner.Parent = targetFill
for segment = 1, 9 do
	local notch = Instance.new("Frame")
	notch.Name = "SegmentNotch"
	notch.Position = UDim2.new(segment / 10, -1, 0, 0)
	notch.Size = UDim2.fromOffset(2, 12)
	notch.BackgroundColor3 = palette.Ink
	notch.BackgroundTransparency = 0.35
	notch.BorderSizePixel = 0
	notch.ZIndex = 3
	notch.Parent = targetTrack
end

local targetDetail = Instance.new("TextLabel")
targetDetail.Name = "TargetDetail"
targetDetail.BackgroundTransparency = 1
targetDetail.Position = UDim2.fromOffset(0, 34)
targetDetail.Size = UDim2.new(1, 0, 0, 24)
targetDetail.Font = Enum.Font.GothamBlack
targetDetail.Text = ""
targetDetail.TextColor3 = Color3.new(1, 1, 1)
targetDetail.TextSize = 14
targetDetail.TextStrokeTransparency = 0.2
targetDetail.TextXAlignment = Enum.TextXAlignment.Center
targetDetail.ZIndex = 38
targetDetail.Parent = targetHUD

local bossHUD = Instance.new("Frame")
bossHUD.Name = "BossHUD"
bossHUD.AnchorPoint = Vector2.new(0.5, 0)
bossHUD.Position = UDim2.new(0.5, 0, 0, 82)
bossHUD.Size = UDim2.fromOffset(420, 58)
bossHUD.BackgroundColor3 = palette.Panel
bossHUD.BackgroundTransparency = 0.04
bossHUD.BorderSizePixel = 0
bossHUD.Visible = false
bossHUD.Parent = gui
addHeroAccent(bossHUD, palette.Punch)

local bossCorner = Instance.new("UICorner")
bossCorner.CornerRadius = UDim.new(0, 8)
bossCorner.Parent = bossHUD

local bossArt = Instance.new("ImageLabel")
bossArt.Name = "TitanContainmentArt"
bossArt.Position = UDim2.fromOffset(6, 6)
bossArt.Size = UDim2.fromOffset(46, 46)
bossArt.BackgroundTransparency = 1
bossArt.Image = GameConfig.GeneratedGraphics.Iteration05TitanBanner
bossArt.ScaleType = Enum.ScaleType.Crop
bossArt.Parent = bossHUD
local bossArtCorner = Instance.new("UICorner")
bossArtCorner.CornerRadius = UDim.new(0, 6)
bossArtCorner.Parent = bossArt

local bossTitle = Instance.new("TextLabel")
bossTitle.Name = "BossTitle"
bossTitle.BackgroundTransparency = 1
bossTitle.Position = UDim2.fromOffset(60, 5)
bossTitle.Size = UDim2.new(1, -70, 0, 20)
bossTitle.Font = Enum.Font.GothamBlack
bossTitle.Text = "TITAN HQ"
bossTitle.TextColor3 = palette.Text
bossTitle.TextSize = 15
bossTitle.TextXAlignment = Enum.TextXAlignment.Left
bossTitle.Parent = bossHUD

local bossTrack = Instance.new("Frame")
bossTrack.Position = UDim2.fromOffset(60, 29)
bossTrack.Size = UDim2.new(1, -70, 0, 13)
bossTrack.BackgroundColor3 = palette.Ink
bossTrack.BorderSizePixel = 0
bossTrack.Parent = bossHUD
local bossTrackCorner = Instance.new("UICorner")
bossTrackCorner.CornerRadius = UDim.new(0, 5)
bossTrackCorner.Parent = bossTrack

local bossFill = Instance.new("Frame")
bossFill.Name = "BossHealthFill"
bossFill.Size = UDim2.fromScale(1, 1)
bossFill.BackgroundColor3 = palette.Punch
bossFill.BorderSizePixel = 0
bossFill.Parent = bossTrack
local bossGradient = Instance.new("UIGradient")
bossGradient.Color = ColorSequence.new(Color3.fromRGB(255, 61, 46), Color3.fromRGB(81, 224, 244))
bossGradient.Parent = bossFill
local bossFillCorner = Instance.new("UICorner")
bossFillCorner.CornerRadius = UDim.new(0, 5)
bossFillCorner.Parent = bossFill
for segment = 1, 9 do
	local notch = Instance.new("Frame")
	notch.Name = "SegmentNotch"
	notch.Position = UDim2.new(segment / 10, -1, 0, 0)
	notch.Size = UDim2.fromOffset(2, 13)
	notch.BackgroundColor3 = palette.Ink
	notch.BackgroundTransparency = 0.3
	notch.BorderSizePixel = 0
	notch.ZIndex = 3
	notch.Parent = bossTrack
end

local bossSubtitle = Instance.new("TextLabel")
bossSubtitle.Name = "BossSubtitle"
bossSubtitle.BackgroundTransparency = 1
bossSubtitle.Position = UDim2.new(0, 60, 1, -15)
bossSubtitle.Size = UDim2.new(1, -70, 0, 13)
bossSubtitle.Font = Enum.Font.Gotham
bossSubtitle.Text = ""
bossSubtitle.TextColor3 = palette.MutedText
bossSubtitle.TextSize = 10
bossSubtitle.TextXAlignment = Enum.TextXAlignment.Right
bossSubtitle.Parent = bossHUD

local toastHolder = Instance.new("Frame")
toastHolder.Name = "Toasts"
toastHolder.AnchorPoint = Vector2.new(0.5, 0)
toastHolder.BackgroundTransparency = 1
toastHolder.Position = UDim2.new(0.5, 0, 0, 24)
toastHolder.Size = UDim2.fromOffset(460, 160)
toastHolder.Visible = false
toastHolder.Parent = gui
toastHolder:SetAttribute("PresentationMode", "BoundedVisibleQueueV1")
toastHolder:SetAttribute("MaxVisibleItems", 3)

local toastLayout = Instance.new("UIListLayout")
toastLayout.Padding = UDim.new(0, 8)
toastLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
toastLayout.SortOrder = Enum.SortOrder.LayoutOrder
toastLayout.Parent = toastHolder

local rewardHolder = Instance.new("Frame")
rewardHolder.Name = "RewardPops"
rewardHolder.AnchorPoint = Vector2.new(0.5, 0.5)
rewardHolder.BackgroundTransparency = 1
rewardHolder.Position = UDim2.fromScale(0.5, 0.48)
rewardHolder.Size = UDim2.fromOffset(520, 220)
rewardHolder.Visible = false
rewardHolder.Parent = gui
rewardHolder:SetAttribute("PresentationMode", "BoundedVisibleQueueV1")
rewardHolder:SetAttribute("MaxVisibleItems", 3)

local rewardLayout = Instance.new("UIListLayout")
rewardLayout.Padding = UDim.new(0, 6)
rewardLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
rewardLayout.VerticalAlignment = Enum.VerticalAlignment.Center
rewardLayout.SortOrder = Enum.SortOrder.LayoutOrder
rewardLayout.Parent = rewardHolder

local feedbackPresentation = {
	maxToasts = 3,
	maxRewards = 3,
	toasts = {},
	rewards = {},
	retireTasks = setmetatable({}, { __mode = "k" }),
}

function feedbackPresentation.CompactList(list)
	for index = #list, 1, -1 do
		if not list[index].Parent or not list[index].Visible then
			table.remove(list, index)
		end
	end
end

function feedbackPresentation.CancelRetirement(item)
	local retireThread = feedbackPresentation.retireTasks[item]
	feedbackPresentation.retireTasks[item] = nil
	if retireThread and retireThread ~= coroutine.running() then
		pcall(task.cancel, retireThread)
	end
end

function feedbackPresentation.UpdateHolder(holder, list)
	feedbackPresentation.CompactList(list)
	local visibleCount = 0
	for _, child in ipairs(holder:GetChildren()) do
		if child:IsA("GuiObject") and child.Visible then visibleCount += 1 end
	end
	holder.Visible = visibleCount > 0
	holder:SetAttribute("VisibleItemCount", visibleCount)
end

function feedbackPresentation.Present(holder, list, item, limit)
	feedbackPresentation.CompactList(list)
	while #list >= limit do
		local oldest = table.remove(list, 1)
		if oldest then
			feedbackPresentation.CancelRetirement(oldest)
			if oldest.Parent then oldest:Destroy() end
		end
	end
	table.insert(list, item)
	item.LayoutOrder = (holder:GetAttribute("PresentationSequence") or 0) + 1
	holder:SetAttribute("PresentationSequence", item.LayoutOrder)
	feedbackPresentation.UpdateHolder(holder, list)
end

function feedbackPresentation.Retire(holder, list, item)
	feedbackPresentation.CancelRetirement(item)
	local index = table.find(list, item)
	if index then table.remove(list, index) end
	if item and item.Parent then item:Destroy() end
	feedbackPresentation.UpdateHolder(holder, list)
end

local function feedbackText(payload)
	if payload.type == "Punch" then
		return ("-%s HP"):format(formatNumber(payload.damage or 0))
	elseif payload.type == "WeakPoint" then
		return ("WEAK POINT x1.5  -%s HP"):format(formatNumber(payload.damage or 0))
	elseif payload.type == "Reward" then
		if payload.wallBreak then
			local xp = payload.xp and ("  +%s XP"):format(formatNumber(payload.xp)) or ""
			return ("WALL BREAK!  +%s COINS%s"):format(formatNumber(payload.coins or 0), xp)
		end
		local xp = payload.xp and ("  +%s XP"):format(formatNumber(payload.xp)) or ""
		return ("+%s coins  +%s power%s"):format(formatNumber(payload.coins or 0), formatNumber(payload.power or 0), xp)
	elseif payload.type == "Train" then
		return ("+%s %s"):format(tostring(payload.gain or ""), tostring(payload.stat or "Stat"))
	elseif payload.type == "Shop" then
		local message = tostring(payload.message or "")
		if message ~= "" then
			return string.upper(message)
		end
		local target = tostring(payload.target or "")
		if target == "" then
			return "SHOP"
		end
		local fist = GameConfig.FistDefinition(target)
		if fist and fist.name == target then
			return ("EQUIPPED | %s"):format(string.upper(tostring(fist.displayName or target)))
		end
		return ("SHOP | %s"):format(string.upper(target))
	elseif payload.type == "Pet" then
		return ("Recruited %s!"):format(tostring(payload.target or "Sidekick"))
	elseif payload.type == "PetFusion" then
		return tostring(payload.message or ("Fused " .. tostring(payload.target or "Sidekick")))
	elseif payload.type == "Rebirth" then
		return tostring(payload.message or "REBIRTH COMPLETE")
	elseif payload.type == "Boss" then
		return "TITAN WALL SHATTERED"
	elseif payload.type == "BossPhase" then
		return ("TITAN PHASE %s"):format(tostring(payload.target or "?"))
	elseif payload.type == "BossAttack" then
		return "SHOCKWAVE INCOMING"
	elseif payload.type == "StructuralCollapse" then
		return ("STRUCTURE COLLAPSE!  %d BLOCKS"):format(tonumber(payload.count) or 0)
	elseif payload.type == "WorldReset" then
		return "WORLD RESET | RETURN TO SPAWN"
	elseif payload.type == "DepthRecord" then
		return ("NEW DEPTH RECORD  %s"):format(tostring(payload.depth or payload.target or "?"))
	elseif payload.type == "RankChange" then
		return ("RANK UP  |  %s"):format(tostring(payload.target or "HERO"))
	elseif payload.type == "TierEntry" then
		return ("ENTERED %s"):format(tostring(payload.target or "NEW MATERIAL"))
	elseif payload.type == "QuestComplete" then
		return ("QUEST COMPLETE  |  %s COINS READY"):format(formatNumber(payload.coins or 0))
	elseif payload.type == "LevelUp" then
		return ("WALL LEVEL %s"):format(tostring(payload.target or "?"))
	elseif payload.type == "SpinResult" then
		return ("HERO SPIN  |  %s"):format(tostring(payload.target or "REWARD"))
	elseif payload.type == "TrainingState" then
		return tostring(payload.target or (payload.active and "POWER TRAINING ACTIVE" or "POWER TRAINING PAUSED"))
	elseif payload.type == "OfflineTraining" then
		return ("OFFLINE TRAINING  |  +%s POWER"):format(formatNumber(payload.gain or 0))
	elseif payload.type == "Honor" then
		return ("WORLD CLEARED  |  +%s HONOR"):format(formatNumber(payload.honor or 0))
	elseif payload.type == "HonorShop" or payload.type == "PremiumPurchase" or payload.type == "PremiumSetup" then
		return tostring(payload.message or payload.target or "PURCHASE UPDATED")
	elseif payload.type == "Fail" then
		return tostring(payload.message or "Locked")
	end
	return tostring(payload.type or "Feedback")
end

local function feedbackIcon(payloadType)
	local icons = {
		Punch = "Punch", WeakPoint = "Punch", Reward = "Coin", Train = "Train",
		Shop = "StarterFist", Pet = "Pet", PetFusion = "Pet", Rebirth = "Rebirth", Boss = "Wall",
		BossPhase = "Warning", BossAttack = "Warning", StructuralCollapse = "Wall", WorldReset = "Wall", LevelUp = "Success", Fail = "Warning",
		DepthRecord = "Wall", RankChange = "Success", TierEntry = "Wall", QuestComplete = "Quest",
		SpinResult = "Success", TrainingState = "Train", OfflineTraining = "Train", Honor = "Success",
		HonorShop = "Success", PremiumPurchase = "Shop", PremiumSetup = "Warning",
	}
	return icons[payloadType] or "Success"
end

local performPunchAnimation = function() end
local lastPunchFeedbackAt = 0
shared.PunchWallLastRewardSoundAt = 0

local localDebrisFolder = Instance.new("Folder")
localDebrisFolder.Name = "Local Punch Debris"
localDebrisFolder.Parent = workspace
local localCoinFolder = Instance.new("Folder")
localCoinFolder.Name = "Local Coin Rewards"
localCoinFolder.Parent = workspace

local function spawnLocalBreakDebris(target)
	if not target or not target:IsA("BasePart") then return end
	if not clientSettings.motion then
		gui:SetAttribute("LastLocalDebrisCount", 0)
		gui:SetAttribute("ReducedMotionDebrisSuppressed", true)
		return
	end
	gui:SetAttribute("ReducedMotionDebrisSuppressed", false)
	local available = math.max(0, 64 - #localDebrisFolder:GetChildren())
	local fragmentCount = math.min(8, available)
	if fragmentCount <= 0 then return end
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local offset = rootPart and (target.Position - rootPart.Position) or Vector3.new(0, 0, -1)
	local outward = offset.Magnitude > 0.01 and offset.Unit or Vector3.new(0, 0, 1)
	for index = 1, fragmentCount do
		local shard = Instance.new(index % 3 == 0 and "WedgePart" or "Part")
		shard.Name = "Local Impact Shard " .. index
		shard.Size = Vector3.new(0.22 + (index % 3) * 0.12, 0.18 + (index % 2) * 0.14, 0.25 + ((index + 1) % 3) * 0.13)
		shard.CFrame = target.CFrame * CFrame.new(((index - 1) % 3 - 1) * 0.55, (math.floor((index - 1) / 3) - 0.5) * 0.48, target.Size.Z * 0.52) * CFrame.Angles(index * 0.31, index * 0.47, index * 0.23)
		shard.Color = target:GetAttribute("OriginalColor") or target.Color
		shard.Material = target.Material
		shard.Anchored = false
		shard.CanCollide = false
		shard.CanTouch = false
		shard.CanQuery = false
		shard.CastShadow = false
		shard:SetAttribute("LocalVisualDebris", true)
		shard.Parent = localDebrisFolder
		local side = target.CFrame.RightVector * ((index % 2 == 0 and 1 or -1) * (8 + index))
		shard.AssemblyLinearVelocity = outward * (34 + index * 3) + side + Vector3.new(0, 14 + (index % 3) * 5, 0)
		shard.AssemblyAngularVelocity = Vector3.new(index * 5, index * 6, index * 4)
		Debris:AddItem(shard, 1.6)
	end
	gui:SetAttribute("LastLocalDebrisCount", fragmentCount)
end

local function spawnCoinCollectVFX(payload)
	if not payload.wallBreak or (tonumber(payload.coins) or 0) <= 0 then return end
	if not clientSettings.motion then
		playUISound(GameConfig.Audio.CoinCollect, 0.28, 1.06)
		gui:SetAttribute("LastCoinBurstCount", 0)
		gui:SetAttribute("ReducedMotionCoinTravelSuppressed", true)
		return
	end
	gui:SetAttribute("ReducedMotionCoinTravelSuppressed", false)
	local root = workspace:FindFirstChild("PunchWallRPG")
	local depthBlocks = root and root:FindFirstChild("Depth Blocks")
	local walls = root and root:FindFirstChild("Walls")
	local target = (depthBlocks and depthBlocks:FindFirstChild(tostring(payload.target or "")))
		or (walls and walls:FindFirstChild(tostring(payload.target or "")))
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not target or not target:IsA("BasePart") or not rootPart then return end
	local available = math.max(0, 30 - #localCoinFolder:GetChildren())
	local count = math.min(7, available)
	for index = 1, count do
		local coin = Instance.new("Part")
		coin.Name = "Reward Coin " .. index
		coin.Shape = Enum.PartType.Cylinder
		coin.Size = Vector3.new(0.18, 0.72, 0.72)
		coin.Color = Color3.fromRGB(255, 190, 35)
		coin.Material = Enum.Material.Neon
		coin.Anchored = true
		coin.CanCollide = false
		coin.CanTouch = false
		coin.CanQuery = false
		coin.CastShadow = false
		local angle = (index / math.max(1, count)) * math.pi * 2
		local burstOffset = Vector3.new(math.cos(angle) * (2.2 + index * 0.12), 1.2 + (index % 3) * 0.7, math.sin(angle) * 1.8)
		coin.CFrame = CFrame.new(target.Position) * CFrame.Angles(math.rad(90), 0, angle)
		coin.Parent = localCoinFolder
		TweenService:Create(coin, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			CFrame = CFrame.new(target.Position + burstOffset) * CFrame.Angles(math.rad(90), angle * 2, 0),
		}):Play()
		task.delay(0.18 + index * 0.018, function()
			if not coin.Parent or not rootPart.Parent then return end
			local tween = TweenService:Create(coin, TweenInfo.new(0.34, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				CFrame = CFrame.new(rootPart.Position + Vector3.new(0, 1.2, 0)) * CFrame.Angles(math.rad(90), angle * 4, 0),
				Transparency = 0.35,
			})
			tween:Play()
			tween.Completed:Connect(function() if coin.Parent then coin:Destroy() end end)
		end)
		Debris:AddItem(coin, 1.2)
	end
	playUISound(GameConfig.Audio.CoinCollect, 0.28, 1.06)
	gui:SetAttribute("LastCoinBurstCount", count)
	gui:SetAttribute("CoinBurstTotal", (gui:GetAttribute("CoinBurstTotal") or 0) + count)
end

shared.PunchWallPlayRewardSound = function()
	local now = os.clock()
	if now - shared.PunchWallLastRewardSoundAt < 0.24 then return end
	shared.PunchWallLastRewardSoundAt = now
	playUISound(GameConfig.Audio.Reward, 0.34, 1)
end

local function showWorldDamage(payload)
	if payload.type ~= "Punch" then return end
	local root = workspace:FindFirstChild("PunchWallRPG")
	local walls = root and root:FindFirstChild("Walls")
	local depthBlocks = root and root:FindFirstChild("Depth Blocks")
	local target = (walls and walls:FindFirstChild(tostring(payload.target or "")))
		or (depthBlocks and depthBlocks:FindFirstChild(tostring(payload.target or "")))
	if not target or not target:IsA("BasePart") then return end
	if payload.broken then spawnLocalBreakDebris(target) end
	if not gui:GetAttribute("CenterActionFeedbackEnabled") then return end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "LocalDamageNumber"
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Size = UDim2.fromOffset(150, 48)
	billboard.StudsOffsetWorldSpace = Vector3.new(math.random(-3, 3), math.random(2, 5), -4.5)
	billboard.Parent = target
	local textLabel = Instance.new("TextLabel")
	textLabel.BackgroundTransparency = 1
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.Font = Enum.Font.GothamBlack
	textLabel.Text = payload.critical and ("CRITICAL!  %s"):format(formatNumber(payload.damage or 0))
		or formatNumber(payload.damage or 0)
	textLabel.TextColor3 = payload.color or palette.Crit
	textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	textLabel.TextStrokeTransparency = 0.25
	textLabel.TextScaled = true
	textLabel.Parent = billboard
	if clientSettings.motion then
		TweenService:Create(billboard, TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			StudsOffsetWorldSpace = billboard.StudsOffsetWorldSpace + Vector3.new(0, 3, 0),
		}):Play()
		TweenService:Create(textLabel, TweenInfo.new(0.65), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end
	Debris:AddItem(billboard, 0.72)
end

local combatFeedbackRuntime = {
	pool = {},
	nextIndex = 0,
	maxPoolSize = 3,
}

function combatFeedbackRuntime.CreateRecord()
	local rays = Instance.new("Frame")
	rays.Name = "PooledCombatSparkRays"
	rays.AnchorPoint = Vector2.new(0.5, 0.5)
	rays.Position = UDim2.fromScale(0.545, 0.505)
	rays.Size = UDim2.fromOffset(380, 300)
	rays.BackgroundTransparency = 1
	rays.ZIndex = 44
	rays.Visible = false
	rays.Parent = gui
	for index = 1, 20 do
		local ray = Instance.new("Frame")
		ray.Name = "SparkRay"
		ray.AnchorPoint = Vector2.new(0.5, 1)
		ray.Position = UDim2.fromScale(0.5, 0.5)
		ray.Size = UDim2.fromOffset(index % 3 == 0 and 11 or 7, 132 + (index % 5) * 19)
		ray.Rotation = (index - 1) * (360 / 20)
		ray.BackgroundColor3 = index % 2 == 0 and Color3.fromRGB(255, 183, 38) or Color3.fromRGB(255, 99, 27)
		ray.BorderSizePixel = 0
		ray.ZIndex = 44
		ray.Parent = rays
	end

	local impactCore = Instance.new("Frame")
	impactCore.Name = "PooledCombatImpactCore"
	impactCore.AnchorPoint = Vector2.new(0.5, 0.5)
	impactCore.Position = UDim2.fromScale(0.545, 0.505)
	impactCore.Size = UDim2.fromOffset(118, 118)
	impactCore.Rotation = 45
	impactCore.BackgroundColor3 = Color3.fromRGB(255, 218, 72)
	impactCore.BackgroundTransparency = 1
	impactCore.BorderSizePixel = 0
	impactCore.ZIndex = 43
	impactCore.Visible = false
	impactCore.Parent = gui
	local impactCorner = Instance.new("UICorner")
	impactCorner.CornerRadius = UDim.new(0.28, 0)
	impactCorner.Parent = impactCore
	local impactScale = Instance.new("UIScale")
	impactScale.Scale = 1
	impactScale.Parent = impactCore

	local burst = Instance.new("TextLabel")
	burst.Name = "PooledCombatDamageBurst"
	burst.AnchorPoint = Vector2.new(0.5, 0.5)
	burst.Position = UDim2.fromScale(0.545, 0.505)
	burst.Size = UDim2.fromOffset(320, 140)
	burst.BackgroundTransparency = 1
	burst.BorderSizePixel = 0
	burst.Font = Enum.Font.GothamBlack
	burst.TextColor3 = Color3.new(1, 1, 1)
	burst.TextStrokeColor3 = Color3.fromRGB(12, 13, 15)
	burst.TextStrokeTransparency = 1
	burst.Rotation = -2
	burst.ZIndex = 46
	burst.Visible = false
	burst.Parent = gui
	local burstScale = Instance.new("UIScale")
	burstScale.Scale = 1
	burstScale.Parent = burst

	local record = {
		rays = rays,
		impactCore = impactCore,
		impactScale = impactScale,
		burst = burst,
		burstScale = burstScale,
		tweens = {},
		generation = 0,
		active = false,
	}
	table.insert(combatFeedbackRuntime.pool, record)
	gui:SetAttribute("CombatVfxPoolSize", #combatFeedbackRuntime.pool)
	gui:SetAttribute("CombatVfxPoolLimit", combatFeedbackRuntime.maxPoolSize)
	gui:SetAttribute("CombatVfxPoolMode", "BoundedReuseV1")
	return record
end

function combatFeedbackRuntime.ActiveCount()
	local count = 0
	for _, record in ipairs(combatFeedbackRuntime.pool) do
		if record.active then count += 1 end
	end
	return count
end

function combatFeedbackRuntime.Acquire()
	local record
	if #combatFeedbackRuntime.pool < combatFeedbackRuntime.maxPoolSize then
		record = combatFeedbackRuntime.CreateRecord()
	else
		combatFeedbackRuntime.nextIndex = combatFeedbackRuntime.nextIndex % #combatFeedbackRuntime.pool + 1
		record = combatFeedbackRuntime.pool[combatFeedbackRuntime.nextIndex]
	end
	if record.retireThread then
		pcall(task.cancel, record.retireThread)
		record.retireThread = nil
	end
	for _, tween in ipairs(record.tweens) do pcall(function() tween:Cancel() end) end
	table.clear(record.tweens)
	record.generation += 1
	record.active = true
	return record
end

function combatFeedbackRuntime.Play(payload)
	local record = combatFeedbackRuntime.Acquire()
	local generation = record.generation
	local reducedMotion = clientSettings.motion ~= true
	record.rays.Name = "CombatSparkRays"
	record.impactCore.Name = "CombatImpactCore"
	record.burst.Name = "CombatDamageBurst"
	record.rays.Visible = not reducedMotion
	record.rays.Size = UDim2.fromOffset(380, 300)
	record.impactCore.Visible = true
	record.impactCore.Size = UDim2.fromOffset(reducedMotion and 72 or 118, reducedMotion and 72 or 118)
	record.impactCore.Rotation = 45
	record.impactCore.BackgroundColor3 = payload.color or Color3.fromRGB(255, 218, 72)
	record.impactCore.BackgroundTransparency = reducedMotion and 0.25 or 0.12
	record.impactScale.Scale = reducedMotion and 1 or 0.42
	record.burst.Visible = true
	record.burst.Position = UDim2.fromScale(0.545, 0.505)
	record.burst.Text = payload.critical and ("CRITICAL!  %s"):format(formatNumber(payload.damage or 0))
		or formatNumber(payload.damage or 0)
	record.burst.TextSize = reducedMotion and (payload.critical and 48 or 54) or (payload.critical and 76 or 96)
	record.burst.TextTransparency = 0
	record.burst.TextStrokeTransparency = 0
	record.burstScale.Scale = reducedMotion and 1 or 0.45

	if not reducedMotion then
		local impactIn = TweenService:Create(record.impactScale, TweenInfo.new(0.1, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		local burstIn = TweenService:Create(record.burstScale, TweenInfo.new(0.1, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		local coreOut = TweenService:Create(record.impactCore, TweenInfo.new(0.34), { BackgroundTransparency = 1, Rotation = 70 })
		table.insert(record.tweens, impactIn)
		table.insert(record.tweens, burstIn)
		table.insert(record.tweens, coreOut)
		impactIn:Play()
		burstIn:Play()
		coreOut:Play()
		task.delay(0.28, function()
			if record.generation ~= generation or not record.active then return end
			local burstOut = TweenService:Create(record.burst, TweenInfo.new(0.28), {
				TextTransparency = 1,
				TextStrokeTransparency = 1,
				Position = record.burst.Position - UDim2.fromOffset(0, 28),
			})
			local raysOut = TweenService:Create(record.rays, TweenInfo.new(0.22), { Size = UDim2.fromOffset(470, 370) })
			table.insert(record.tweens, burstOut)
			table.insert(record.tweens, raysOut)
			burstOut:Play()
			raysOut:Play()
		end)
	else
		task.delay(0.16, function()
			if record.generation ~= generation or not record.active then return end
			local burstOut = TweenService:Create(record.burst, TweenInfo.new(0.12), {
				TextTransparency = 1,
				TextStrokeTransparency = 1,
			})
			local coreOut = TweenService:Create(record.impactCore, TweenInfo.new(0.12), {
				BackgroundTransparency = 1,
			})
			table.insert(record.tweens, burstOut)
			table.insert(record.tweens, coreOut)
			burstOut:Play()
			coreOut:Play()
		end)
	end

	local lifetime = reducedMotion and 0.32 or 0.65
	record.retireThread = task.delay(lifetime, function()
		if record.generation ~= generation then return end
		record.active = false
		record.rays.Visible = false
		record.impactCore.Visible = false
		record.burst.Visible = false
		record.rays.Name = "PooledCombatSparkRays"
		record.impactCore.Name = "PooledCombatImpactCore"
		record.burst.Name = "PooledCombatDamageBurst"
		record.retireThread = nil
		table.clear(record.tweens)
		gui:SetAttribute("CombatVfxActiveCount", combatFeedbackRuntime.ActiveCount())
	end)
	gui:SetAttribute("CombatVfxActiveCount", combatFeedbackRuntime.ActiveCount())
	gui:SetAttribute("CombatVfxPresentation", reducedMotion and "ReducedStaticReadable" or "FullMotion")
end

local function showFeedback(payload)
	if typeof(payload) ~= "table" then
		return
	end
	if payload.type == "PremiumPrompt" and payload.product then
		shared.PunchWallPurchaseRuntime.ActivePromptProductId = tonumber(payload.productId)
		shared.PunchWallPurchaseRuntime.SetProductUiState(payload.product, "CheckoutOpen", payload.message or "CHECKOUT OPEN")
	elseif payload.type == "PremiumSetup" and payload.product then
		shared.PunchWallPurchaseRuntime.ActivePromptProductId = nil
		shared.PunchWallPurchaseRuntime.SetProductUiState(payload.product, "Rejected", payload.message or "PURCHASE UNAVAILABLE")
	elseif payload.type == "PremiumPurchase" and payload.product then
		shared.PunchWallPurchaseRuntime.ActivePromptProductId = nil
		if gui then
			gui:SetAttribute("PurchaseUiHonor", tonumber(payload.honor) or 0)
			gui:SetAttribute("PurchaseUiBalance", tonumber(payload.newHonorBalance) or 0)
		end
		shared.PunchWallPurchaseRuntime.SetProductUiState(payload.product, "Granted", payload.message or "PURCHASE GRANTED")
		task.delay(2, function()
			local entry = shared.PunchWallPurchaseRuntime.ProductUiState[payload.product]
			if entry and entry.state == "Granted" then
				shared.PunchWallPurchaseRuntime.SetProductUiState(payload.product, "Idle", "")
			end
		end)
	end
	if payload.type == "OpenMenu" then
		local requested = tostring(payload.tab or payload.target or "Fists")
		if requested == "Rebirth" or tostring(payload.selected or payload.target or "") == "Rebirth" then
			task.defer(function() shared.PunchWallOpenRebirthPanel(tostring(payload.source or "world")) end)
			return
		end
		if requested == "Honor" and payload.selected ~= nil then
			-- World relic displays are previews, not instant purchases. The complete
			-- relic catalog now lives in Inventory; never route a relic click to the
			-- optional Robux Honor-pack shop.
			local definition = GameConfig.HonorItemDefinition(tostring(payload.selected))
			local selectedId = definition and tostring(definition.id) or ""
			if selectedId ~= "" then
				shared.PunchWallSelectedHonorItemId = selectedId
				gui:SetAttribute("RequestedHonorItemId", selectedId)
				task.defer(function()
					if shared.PunchWallOpenInventoryHonorItem then
						shared.PunchWallOpenInventoryHonorItem(selectedId, "world_relic")
					end
				end)
			end
			return
		end
		if table.find({ "Fists", "Premium", "Boosts", "Honor", "Robux" }, requested) then
			local menu = gui:FindFirstChild("GameMenu")
			local shop = menu and menu:FindFirstChild("FunctionalHeroShop")
			local samePageOpen = menu ~= nil
				and menu.Visible
				and shop ~= nil
				and shop.Visible
				and shared.PunchWallHeroShopPage == requested
			gui:SetAttribute("LastWorldBoostShowcase", tostring(payload.target or ""))
			-- World commerce showcases enter through the same modal and page state
			-- as the HUD shop.  Set the requested page before opening the Fists host
			-- so keyboard, gamepad, touch and click interactions all land on the
			-- intended catalog instead of silently falling back to Fists.
			shared.PunchWallHeroShopPage = requested
			task.defer(function()
				openGameTab("Fists")
				if shared.PunchWallHeroShopRefresh then
					if shop then
						shop:SetAttribute("RefreshReason", "world-commerce-showcase")
					end
					shared.PunchWallHeroShopRefresh({
						force = not samePageOpen,
						reason = "world-commerce-showcase",
					})
				end
			end)
		else
			task.defer(function() openGameTab(requested) end)
		end
		return
	elseif payload.type == "SpinResult" and shared.PunchWallShowSpinResult then
		shared.PunchWallShowSpinResult(payload)
	end
	if (payload.type == "Fail" and payload.target == "Rebirth") or payload.type == "Rebirth" then
		shared.PunchWallRebirthRuntime.armed = false
		shared.PunchWallRebirthRuntime.pending = false
		shared.PunchWallRebirthRuntime.expiresAt = 0
		shared.PunchWallRebirthRuntime.signature = ""
		shared.PunchWallRebirthRuntime.generation += 1
		if gui then
			gui:SetAttribute("RebirthConfirmationState", payload.type == "Rebirth" and "Complete" or "Rejected")
			gui:SetAttribute("RebirthPending", false)
			if payload.type == "Rebirth" and shared.PunchWallCloseStandaloneWindows then
				shared.PunchWallCloseStandaloneWindows("Complete")
			elseif payload.type == "Fail" then
				task.defer(function() shared.PunchWallOpenRebirthPanel("server_reject") end)
			end
		end
	end
	local count = (gui:GetAttribute("FeedbackCount") or 0) + 1
	gui:SetAttribute("FeedbackCount", count)
	gui:SetAttribute("LastFeedbackType", tostring(payload.type or "Unknown"))
	gui:SetAttribute("LastFeedbackTarget", tostring(payload.target or ""))
	gui:SetAttribute("LastMotionApplied", clientSettings.motion)
	showWorldDamage(payload)
	if payload.type == "Reward" and payload.wallBreak then spawnCoinCollectVFX(payload) end
	local milestoneFeedback = payload.type == "DepthRecord"
		or payload.type == "RankChange"
		or payload.type == "TierEntry"
		or payload.type == "QuestComplete"
	if milestoneFeedback then
		local attributeName = "MilestoneSeen" .. tostring(payload.type)
		gui:SetAttribute(attributeName, (gui:GetAttribute(attributeName) or 0) + 1)
		gui:SetAttribute("LastMilestoneType", tostring(payload.type))
		gui:SetAttribute("LastMilestoneAt", os.clock())
	end
	if not gui:GetAttribute("CenterActionFeedbackEnabled") then
		if payload.type == "Punch" then
			local feedbackNow = os.clock()
			if feedbackNow - lastPunchFeedbackAt < 0.12 then return end
			lastPunchFeedbackAt = feedbackNow
			hitFlash.BackgroundColor3 = payload.color or palette.Punch
			hitFlash.BackgroundTransparency = 0.93
			hitFlash.Visible = true
			TweenService:Create(hitFlash, TweenInfo.new(clientSettings.motion and 0.16 or 0.05), { BackgroundTransparency = 1 }):Play()
			task.delay(0.18, function() if hitFlash.Parent then hitFlash.Visible = false end end)
			pulseHaptic(0.28, 0.05)
			local materialPitch = ({ Brick = 0.96, Concrete = 0.88, Metal = 1.16, Glass = 1.28, ForceField = 1.38 })[tostring(payload.material)] or 1.04
			playPunchImpact(materialPitch)
		elseif payload.type == "Reward" or payload.type == "LevelUp" or payload.type == "DepthRecord"
			or payload.type == "RankChange" or payload.type == "TierEntry" or payload.type == "QuestComplete" then
			shared.PunchWallPlayRewardSound()
		elseif payload.type == "Boss" or payload.type == "BossAttack" then
			pulseHaptic(0.65, 0.14)
			playUISound(GameConfig.Audio.BossRoar, 0.45, 0.92)
		elseif payload.type == "StructuralCollapse" then
			pulseHaptic(0.5, 0.11)
			playUISound(GameConfig.Audio.Collapse, 0.32, 0.92)
		elseif payload.type == "SpinResult" or payload.type == "Honor" or payload.type == "HonorShop" or payload.type == "Pet" or payload.type == "PetFusion" or payload.type == "Rebirth"
			or payload.type == "PremiumPurchase" or payload.type == "OfflineTraining" or payload.type == "TrainingState"
			or payload.type == "PremiumPrompt" or payload.type == "PremiumSetup" or payload.type == "Fail" or payload.type == "Shop" then
			if payload.type ~= "Fail" and payload.type ~= "PremiumSetup" and payload.type ~= "PremiumPrompt" and payload.type ~= "Shop" then
				shared.PunchWallPlayRewardSound()
			end
			if shared.PunchWallShowToast then
				local presentationColor = payload.color
					or payload.type == "Fail" and palette.Fail
					or payload.type == "PremiumSetup" and palette.Train
					or palette.Reward
				shared.PunchWallShowToast(feedbackText(payload), presentationColor, feedbackIcon(payload.type))
			end
		end
		if milestoneFeedback and shared.PunchWallShowToast then
			gui:SetAttribute("MilestoneToastCount", (gui:GetAttribute("MilestoneToastCount") or 0) + 1)
			shared.PunchWallShowToast(feedbackText(payload), payload.color or palette.Reward, feedbackIcon(payload.type))
		end
		return
	end
	if payload.type == "Punch" then
		local feedbackNow = os.clock()
		if feedbackNow - lastPunchFeedbackAt < 0.12 then return end
		lastPunchFeedbackAt = feedbackNow
		combatFeedbackRuntime.Play(payload)
		hitFlash.BackgroundColor3 = payload.color or palette.Punch
		hitFlash.BackgroundTransparency = 0.93
		hitFlash.Visible = true
		TweenService:Create(hitFlash, TweenInfo.new(clientSettings.motion and 0.16 or 0.05), { BackgroundTransparency = 1 }):Play()
		task.delay(0.18, function() if hitFlash.Parent then hitFlash.Visible = false end end)
		pulseHaptic(0.28, 0.05)
		local materialPitch = ({ Brick = 0.96, Concrete = 0.88, Metal = 1.16, Glass = 1.28, ForceField = 1.38 })[tostring(payload.material)] or 1.04
		playPunchImpact(materialPitch)
	elseif payload.type == "Reward" or payload.type == "LevelUp" or payload.type == "DepthRecord"
		or payload.type == "RankChange" or payload.type == "TierEntry" or payload.type == "QuestComplete" then
		shared.PunchWallPlayRewardSound()
	elseif payload.type == "Boss" or payload.type == "BossAttack" then
		pulseHaptic(0.65, 0.14)
		playUISound(GameConfig.Audio.BossRoar, 0.45, 0.92)
	elseif payload.type == "StructuralCollapse" then
		pulseHaptic(0.5, 0.11)
		playUISound(GameConfig.Audio.Collapse, 0.32, 0.92)
	end
	if payload.type == "Punch" or payload.type == "LevelUp" or (payload.type == "Reward" and payload.wallBreak) then
		return
	end

	local color = payload.color or palette.Reward
	local pop = Instance.new("TextLabel")
	pop.Name = "FeedbackPop"
	pop.AnchorPoint = Vector2.new(0.5, 0.5)
	pop.BackgroundColor3 = palette.Panel
	pop.BackgroundTransparency = 0.08
	pop.BorderSizePixel = 0
	pop.Font = Enum.Font.GothamBlack
	pop.Text = feedbackText(payload)
	pop.TextColor3 = color
	pop.TextSize = UserInputService.TouchEnabled and 15 or payload.type == "Boss" and 22 or 18
	pop.TextWrapped = true
	pop.TextXAlignment = Enum.TextXAlignment.Left
	pop.LayoutOrder = count
	pop.Position = UDim2.fromScale(0.5, 0.5)
	pop.Size = UDim2.fromOffset(UserInputService.TouchEnabled and 300 or 320, UserInputService.TouchEnabled and 44 or 50)
	pop.Parent = rewardHolder
	feedbackPresentation.Present(rewardHolder, feedbackPresentation.rewards, pop, feedbackPresentation.maxRewards)
	addHeroAccent(pop, color)
	local popPadding = Instance.new("UIPadding")
	popPadding.PaddingLeft = UDim.new(0, 52)
	popPadding.PaddingRight = UDim.new(0, 10)
	popPadding.Parent = pop
	createThemeIcon(pop, feedbackIcon(payload.type), UDim2.fromOffset(-46, 5), UDim2.fromOffset(40, 40), "FeedbackIcon")

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = pop

	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Transparency = 0.18
	stroke.Thickness = 2
	stroke.Parent = pop

	local scale = Instance.new("UIScale")
	scale.Scale = 0.72
	scale.Parent = pop

	if clientSettings.motion then
		TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		TweenService:Create(pop, TweenInfo.new(PolishConfig.Motion.RewardPopSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 1,
			TextTransparency = 1,
		}):Play()
		TweenService:Create(stroke, TweenInfo.new(PolishConfig.Motion.RewardPopSeconds), { Transparency = 1 }):Play()
	else
		scale.Scale = 1
	end

	feedbackPresentation.retireTasks[pop] = task.delay(PolishConfig.Motion.RewardPopSeconds + 0.08, function()
		feedbackPresentation.Retire(rewardHolder, feedbackPresentation.rewards, pop)
	end)
end

shared.PunchWallShowToast = function(message, color, iconName)
	local toast = Instance.new("TextLabel")
	toast.BackgroundColor3 = palette.Panel
	toast.BackgroundTransparency = 0.05
	toast.BorderSizePixel = 0
	toast.Font = Enum.Font.GothamBold
	toast.Text = message
	toast.TextColor3 = color or Color3.fromRGB(255, 235, 140)
	toast.TextSize = 14
	toast.TextWrapped = true
	toast.TextXAlignment = Enum.TextXAlignment.Left
	toast.Size = UDim2.fromOffset(UserInputService.TouchEnabled and 300 or 440, UserInputService.TouchEnabled and 44 or 46)
	toast.Parent = toastHolder
	feedbackPresentation.Present(toastHolder, feedbackPresentation.toasts, toast, feedbackPresentation.maxToasts)
	addHeroAccent(toast, color or palette.Train)
	local toastPadding = Instance.new("UIPadding")
	toastPadding.PaddingLeft = UDim.new(0, 50)
	toastPadding.PaddingRight = UDim.new(0, 10)
	toastPadding.Parent = toast
	createThemeIcon(toast, iconName or "Warning", UDim2.fromOffset(-44, 5), UDim2.fromOffset(34, 34), "ToastIcon")

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = toast

	local stroke = Instance.new("UIStroke")
	stroke.Color = toast.TextColor3
	stroke.Transparency = 0.35
	stroke.Thickness = 1
	stroke.Parent = toast

	if clientSettings.motion then
		toast.TextTransparency = 1
		toast.BackgroundTransparency = 1
		TweenService:Create(toast, TweenInfo.new(0.18), {
			TextTransparency = 0,
			BackgroundTransparency = 0.05,
		}):Play()
	end

	feedbackPresentation.retireTasks[toast] = task.delay(3, function()
		if toast.Parent then
			if clientSettings.motion then
				local tween = TweenService:Create(toast, TweenInfo.new(0.22), {
					TextTransparency = 1,
					BackgroundTransparency = 1,
				})
				tween:Play()
				tween.Completed:Wait()
			end
		end
		feedbackPresentation.Retire(toastHolder, feedbackPresentation.toasts, toast)
	end)
end

local refreshCharacterVisuals = function() end
local renderOpenPanel = function() end
local applyReferenceHUDState = function() end

statRemote.OnClientEvent:Connect(function(payload)
	local previousRebirths = tonumber(latestStats.Rebirths) or 0
	latestStats = payload
	if shared.PunchWallRebirthRuntime.pending and (tonumber(payload.Rebirths) or 0) ~= previousRebirths then
		shared.PunchWallRebirthRuntime.armed = false
		shared.PunchWallRebirthRuntime.pending = false
		shared.PunchWallRebirthRuntime.expiresAt = 0
		shared.PunchWallRebirthRuntime.signature = ""
		shared.PunchWallRebirthRuntime.generation += 1
		gui:SetAttribute("RebirthConfirmationState", "Complete")
		gui:SetAttribute("RebirthPending", false)
	end
	clientSettings = decodeJSON(payload.SettingsJSON, clientSettings)
	shared.PunchWallApplySoundSetting(clientSettings.sound, false)
	statusValues.Power.Text = formatNumber(payload.Power or 0)
	statusValues.Coins.Text = formatNumber(payload.Coins or 0)
	statusValues.WallLevel.Text = formatNumber(payload.WallLevel or 1)
	local worldProgress = math.clamp((tonumber(payload.Depth) or 0) / 76, 0.02, 1)
	nextFill.Size = UDim2.fromScale(worldProgress, 1)
	nextPercent.Text = ("%d%%"):format(math.floor(worldProgress * 100 + 0.5))
	for _, key in ipairs(order) do
		if labels[key] then
			local value = payload[key]
			if key == "WallLevel" then
				labels[key].Text = ("Wall Lv: %s  XP %s/%s"):format(formatNumber(value), formatNumber(payload.WallXP or 0), formatNumber(payload.WallXPNeeded or 1))
			elseif key == "EquippedFist" then
				local fistDefinition = GameConfig.FistDefinition(value)
				labels[key].Text = "Fist: " .. tostring(fistDefinition.displayName)
				local statIcon = labels[key]:FindFirstChild("StatIcon")
				if statIcon then applyThemeIcon(statIcon, fistDefinition.icon) end
			elseif key == "Pet" then
				local equippedCount = #decodeJSON(payload.EquippedPetsJSON, {})
				labels[key].Text = equippedCount > 0 and ("Pets: %d equipped  x%.2f"):format(equippedCount, 1 + (payload.PetMultiplier or 0))
					or "Pets: None  x1.00"
			elseif key == "Rebirths" then
				labels[key].Text = ("Rebirths: %s  x%.2f"):format(formatNumber(value), payload.RebirthBonus or 1)
			elseif typeof(value) == "number" then
				labels[key].Text = key .. ": " .. formatNumber(value)
			else
				labels[key].Text = key .. ": " .. tostring(value or "None")
			end
		end
	end
	local tutorial = payload.Tutorial
	if type(tutorial) == "table" then
		tutorialObjectiveText = ("OBJECTIVE  |  %s\n%s"):format(tostring(tutorial.title or "Keep smashing"), tostring(tutorial.detail or ""))
		help.Text = tutorialObjectiveText
	end
	objectiveProgressFill.Size = UDim2.fromScale(math.clamp((tonumber(payload.TutorialStep) or 1) / 5, 0.2, 1), 1)
	refreshCharacterVisuals()
	if shared.PunchWallSetTrainingAnimation then shared.PunchWallSetTrainingAnimation((payload.TrainingActive or 0) >= 1) end
	renderOpenPanel()
	if shared.PunchWallRefreshStandaloneWindows then shared.PunchWallRefreshStandaloneWindows("StatsChanged") end
end)

notifyRemote.OnClientEvent:Connect(shared.PunchWallShowToast)
feedbackRemote.OnClientEvent:Connect(showFeedback)

game:GetService("MarketplaceService").PromptProductPurchaseFinished:Connect(function(userId, productId, wasPurchased)
	if tonumber(userId) ~= player.UserId then return end
	local product
	for _, candidate in ipairs(GameConfig.PremiumProducts) do
		if tonumber(candidate.productId) == tonumber(productId) then
			product = candidate
			break
		end
	end
	if not product then return end
	shared.PunchWallPurchaseRuntime.ActivePromptProductId = nil
	if wasPurchased then
		-- Prompt closure is not a grant. ProcessReceipt is authoritative and will
		-- replace this state with Granted only after durable persistence succeeds.
		shared.PunchWallPurchaseRuntime.SetProductUiState(product.id, "Verifying", "VERIFYING PURCHASE...")
	else
		shared.PunchWallPurchaseRuntime.SetProductUiState(product.id, "Canceled", "PURCHASE CANCELED • NO CHARGE")
		if shared.PunchWallShowToast then
			shared.PunchWallShowToast("PURCHASE CANCELED • NO CHARGE", palette.Train, feedbackIcon("PremiumSetup"))
		end
	end
end)

local menuButton = Instance.new("TextButton")
menuButton.Name = "MenuButton"
menuButton.AnchorPoint = Vector2.new(1, 0)
menuButton.Position = UDim2.new(1, -18, 0, 18)
menuButton.Size = UDim2.fromOffset(92, 42)
menuButton.BackgroundColor3 = palette.Panel
menuButton.BorderSizePixel = 0
menuButton.Font = Enum.Font.GothamBlack
menuButton.Text = "MENU"
menuButton.TextColor3 = palette.Text
menuButton.TextSize = 12
menuButton.TextXAlignment = Enum.TextXAlignment.Right
menuButton.Parent = gui
menuButton.Visible = false
addHeroAccent(menuButton, palette.Use)
local menuPadding = Instance.new("UIPadding")
menuPadding.PaddingLeft = UDim.new(0, 34)
menuPadding.PaddingRight = UDim.new(0, 8)
menuPadding.Parent = menuButton
createThemeIcon(menuButton, "Menu", UDim2.fromOffset(-29, 6), UDim2.fromOffset(30, 30), "MenuIcon")

local menuCorner = Instance.new("UICorner")
menuCorner.CornerRadius = UDim.new(0, 8)
menuCorner.Parent = menuButton

local mainPanel = Instance.new("Frame")
mainPanel.Name = "GameMenu"
mainPanel.AnchorPoint = Vector2.new(0.5, 0.5)
mainPanel.Position = UDim2.fromScale(0.5, 0.52)
mainPanel.Size = UDim2.fromOffset(660, 430)
mainPanel.BackgroundColor3 = palette.Panel
mainPanel.BackgroundTransparency = 0.02
mainPanel.BorderSizePixel = 0
mainPanel.Visible = false
mainPanel.Parent = gui
addHeroAccent(mainPanel, palette.Punch)

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 8)
mainCorner.Parent = mainPanel

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = palette.RoadLine
mainStroke.Thickness = 2
mainStroke.Parent = mainPanel

local closeButton = Instance.new("TextButton")
closeButton.Name = "Close"
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.Position = UDim2.new(1, -10, 0, 10)
closeButton.Size = UDim2.fromOffset(44, 44)
closeButton.BackgroundColor3 = palette.Fail
closeButton.BorderSizePixel = 0
closeButton.Font = Enum.Font.GothamBlack
closeButton.Text = "X"
closeButton.TextColor3 = Color3.new(1, 1, 1)
closeButton.TextSize = 18
closeButton.ZIndex = 10
closeButton.Parent = mainPanel

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 7)
closeCorner.Parent = closeButton

local tabBar = Instance.new("ScrollingFrame")
tabBar.Name = "Tabs"
tabBar.Position = UDim2.fromOffset(12, 12)
tabBar.Size = UDim2.new(1, -72, 0, 48)
tabBar.BackgroundTransparency = 1
tabBar.BorderSizePixel = 0
tabBar.CanvasSize = UDim2.new()
tabBar.AutomaticCanvasSize = Enum.AutomaticSize.X
tabBar.ScrollingDirection = Enum.ScrollingDirection.X
tabBar.ScrollBarThickness = 0
tabBar.ElasticBehavior = Enum.ElasticBehavior.Never
tabBar.SelectionGroup = true
tabBar:SetAttribute("GamepadFocusMode", "CyclicTabsV1")
tabBar:SetAttribute("LegacyCombinedNavigationRemoved", true)
tabBar.Visible = false
tabBar.Parent = mainPanel

shared.PunchWallStandaloneHostTitle = Instance.new("TextLabel")
shared.PunchWallStandaloneHostTitle.Name = "StandaloneHostTitle"
shared.PunchWallStandaloneHostTitle.Position = UDim2.fromOffset(18, 12)
shared.PunchWallStandaloneHostTitle.Size = UDim2.new(1, -86, 0, 44)
shared.PunchWallStandaloneHostTitle.BackgroundTransparency = 1
shared.PunchWallStandaloneHostTitle.Font = Enum.Font.GothamBlack
shared.PunchWallStandaloneHostTitle.Text = ""
shared.PunchWallStandaloneHostTitle.TextColor3 = palette.Text
shared.PunchWallStandaloneHostTitle.TextSize = 22
shared.PunchWallStandaloneHostTitle.TextXAlignment = Enum.TextXAlignment.Left
shared.PunchWallStandaloneHostTitle.Visible = false
shared.PunchWallStandaloneHostTitle.Parent = mainPanel

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 7)
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Parent = tabBar

local content = Instance.new("ScrollingFrame")
content.Name = "Content"
content.Position = UDim2.fromOffset(12, 68)
content.Size = UDim2.new(1, -24, 1, -80)
content.BackgroundColor3 = palette.PanelSoft
content.BackgroundTransparency = 0.35
content.BorderSizePixel = 0
content.ScrollBarThickness = 6
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.CanvasSize = UDim2.new()
content.Parent = mainPanel

local contentCorner = Instance.new("UICorner")
contentCorner.CornerRadius = UDim.new(0, 7)
contentCorner.Parent = content

local contentPadding = Instance.new("UIPadding")
contentPadding.PaddingTop = UDim.new(0, 10)
contentPadding.PaddingBottom = UDim.new(0, 10)
contentPadding.PaddingLeft = UDim.new(0, 10)
contentPadding.PaddingRight = UDim.new(0, 10)
contentPadding.Parent = content

local contentLayout = Instance.new("UIListLayout")
contentLayout.Padding = UDim.new(0, 7)
contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
contentLayout.Parent = content

local activeTab = "Fists"
mainPanel:SetAttribute("SurfaceRole", "NeutralModalHost")
mainPanel:SetAttribute("LegacyCombinedMenuRemoved", true)
local tabButtons = {}
local orderedTabButtons = {}
local legacyPetMenuRuntime = {
	deleteKey = nil,
	deleteToken = nil,
	deleteIndex = nil,
	deleteExpiresAt = 0,
	deleteGeneration = 0,
	deleteConfirmationSeconds = 3,
}

local function setRounded(instance, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 6)
	corner.Parent = instance
end

local function makeMenuCommand(parent, name, textValue, color, callback)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UDim2.fromOffset(112, 44)
	button.BackgroundColor3 = color or palette.Use
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.Text = textValue
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextSize = 13
	button.Parent = parent
	setRounded(button, 6)
	button.Activated:Connect(callback)
	return button
end

function legacyPetMenuRuntime.DeleteKey(index, token)
	return ("slot:%d:%s"):format(math.max(1, math.floor(tonumber(index) or 1)), tostring(token or ""))
end

function legacyPetMenuRuntime.ClearDelete(reason)
	legacyPetMenuRuntime.deleteKey = nil
	legacyPetMenuRuntime.deleteToken = nil
	legacyPetMenuRuntime.deleteIndex = nil
	legacyPetMenuRuntime.deleteExpiresAt = 0
	legacyPetMenuRuntime.deleteGeneration += 1
	gui:SetAttribute("LegacyPetDeleteConfirmationScheduled", false)
	gui:SetAttribute("LegacyPetDeleteConfirmationKey", "")
	gui:SetAttribute("LegacyPetDeleteConfirmationIndex", 0)
	gui:SetAttribute("LegacyPetDeleteConfirmationToken", "")
	gui:SetAttribute("LegacyPetDeleteConfirmationReason", tostring(reason or "cleared"))
end

function legacyPetMenuRuntime.ValidateDelete(inventory)
	if legacyPetMenuRuntime.deleteKey == nil then return false end
	local index = legacyPetMenuRuntime.deleteIndex
	local token = legacyPetMenuRuntime.deleteToken
	local valid = type(inventory) == "table"
		and type(index) == "number"
		and legacyPetMenuRuntime.deleteKey == legacyPetMenuRuntime.DeleteKey(index, token)
		and legacyPetMenuRuntime.deleteExpiresAt > os.clock()
		and inventory[index] == token
	if not valid then
		legacyPetMenuRuntime.ClearDelete("expired_or_slot_changed")
	end
	return valid
end

function legacyPetMenuRuntime.IsDeleteArmed(index, token, inventory)
	if not legacyPetMenuRuntime.ValidateDelete(inventory) then return false end
	local normalizedIndex = math.max(1, math.floor(tonumber(index) or 1))
	-- Rendering another row is only a query, never an invalidation. The armed
	-- record is cleared exclusively when its stored exact slot expires or no
	-- longer contains the same token.
	return legacyPetMenuRuntime.deleteIndex == normalizedIndex
		and legacyPetMenuRuntime.deleteToken == token
		and legacyPetMenuRuntime.deleteKey == legacyPetMenuRuntime.DeleteKey(normalizedIndex, token)
end

function legacyPetMenuRuntime.ArmDelete(index, token)
	index = math.max(1, math.floor(tonumber(index) or 1))
	legacyPetMenuRuntime.deleteGeneration += 1
	local generation = legacyPetMenuRuntime.deleteGeneration
	legacyPetMenuRuntime.deleteKey = legacyPetMenuRuntime.DeleteKey(index, token)
	legacyPetMenuRuntime.deleteToken = token
	legacyPetMenuRuntime.deleteIndex = index
	legacyPetMenuRuntime.deleteExpiresAt = os.clock() + legacyPetMenuRuntime.deleteConfirmationSeconds
	gui:SetAttribute("LegacyPetDeleteConfirmationScheduled", true)
	gui:SetAttribute("LegacyPetDeleteConfirmationKey", legacyPetMenuRuntime.deleteKey)
	gui:SetAttribute("LegacyPetDeleteConfirmationIndex", index)
	gui:SetAttribute("LegacyPetDeleteConfirmationToken", tostring(token))
	gui:SetAttribute("LegacyPetDeleteConfirmationReason", "armed")
	gui:SetAttribute("LegacyPetDeleteConfirmationSeconds", legacyPetMenuRuntime.deleteConfirmationSeconds)
	gui:SetAttribute("LegacyPetDeleteFirstClickMutationGuard", true)
	gui:SetAttribute("LegacyPetExactSlotDispatch", true)
	task.delay(legacyPetMenuRuntime.deleteConfirmationSeconds, function()
		if generation ~= legacyPetMenuRuntime.deleteGeneration
			or legacyPetMenuRuntime.deleteExpiresAt > os.clock() then
			return
		end
		legacyPetMenuRuntime.ClearDelete("timeout")
		if mainPanel.Visible and activeTab == "Pets" then
			renderOpenPanel()
		end
	end)
end

for order, tabName in ipairs({ "Fists", "Pets", "Honor", "Tasks", "Settings" }) do
	local tab = makeMenuCommand(tabBar, tabName .. "Tab", string.upper(tabName), palette.PanelSoft, function()
		activeTab = tabName
		renderOpenPanel()
	end)
	tab.Size = UDim2.fromOffset(108, 44)
	tab.LayoutOrder = order
	tab.TextSize = 11
	tab.TextXAlignment = Enum.TextXAlignment.Right
	tab.Selectable = true
	local tabPadding = Instance.new("UIPadding")
	tabPadding.PaddingLeft = UDim.new(0, 36)
	tabPadding.PaddingRight = UDim.new(0, 8)
	tabPadding.Parent = tab
	local tabIcon = tabName == "Fists" and "StarterFist"
		or tabName == "Pets" and "Pet"
		or tabName == "Honor" and "Success"
		or tabName == "Tasks" and "Quest"
		or "Settings"
	createThemeIcon(tab, tabIcon, UDim2.fromOffset(6, 8), UDim2.fromOffset(28, 28), "TabIcon")
	tabButtons[tabName] = tab
	table.insert(orderedTabButtons, tab)
end

for index, tab in ipairs(orderedTabButtons) do
	tab.NextSelectionLeft = orderedTabButtons[index == 1 and #orderedTabButtons or index - 1]
	tab.NextSelectionRight = orderedTabButtons[index == #orderedTabButtons and 1 or index + 1]
end
closeButton.Selectable = true
closeButton.NextSelectionLeft = orderedTabButtons[#orderedTabButtons]

local function clearContent()
	for _, child in ipairs(content:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end
end

local function addGeneratedBanner()
	local compactBanner = UserInputService.TouchEnabled or (workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.Y < 520)
	local isPets = activeTab == "Pets"
	local isHonor = activeTab == "Honor"
	local isTasks = activeTab == "Tasks"
	local isSettings = activeTab == "Settings"
	local bannerImage = isPets and GameConfig.GeneratedGraphics.Iteration02DNABanner
		or isHonor and GameConfig.GeneratedGraphics.Iteration05TitanBanner
		or isTasks and GameConfig.GeneratedGraphics.Iteration03TasksBanner
		or isSettings and GameConfig.GeneratedGraphics.Iteration03SettingsBanner
		or GameConfig.GeneratedGraphics.HeroCityHUDAtlas
	local bannerTitle = isPets and "HERO SIDEKICK LAB"
		or isHonor and "HALL OF HONOR"
		or isTasks and "HERO MISSIONS"
		or isSettings and "HERO CONTROL"
		or "HERO FIST HQ"
	local bannerSubtitle = isPets and "RECRUIT | EQUIP | TEAM UP"
		or isHonor and "DEPTH • REBIRTH • TITAN | EQUIP ONE RELIC"
		or isTasks and "SMASH | CLAIM | RANK UP"
		or isSettings and "MOTION | SOUND | ACCESS"
		or "BUILD | EQUIP | POWER UP"
	local banner = Instance.new("ImageLabel")
	banner.Name = "Hero City Generated Banner"
	banner.Size = UDim2.new(1, -4, 0, compactBanner and 64 or 92)
	banner.BackgroundColor3 = palette.Ink
	banner.BorderSizePixel = 0
	banner.Image = bannerImage
	banner.ScaleType = activeTab == "Fists" and Enum.ScaleType.Fit or Enum.ScaleType.Crop
	if activeTab == "Fists" then
		local shopHeader = GameConfig.UIIconAtlas.regions.ShopHeader
		banner.ImageRectOffset = Vector2.new(shopHeader[1], shopHeader[2])
		banner.ImageRectSize = Vector2.new(shopHeader[3], shopHeader[4])
	end
	banner.LayoutOrder = -100
	banner.Parent = content
	setRounded(banner, 6)
	banner:SetAttribute("Theme", PolishConfig.StyleName)
	addHeroAccent(banner, palette.Punch)

	local shade = Instance.new("Frame")
	shade.BackgroundColor3 = palette.Ink
	shade.BackgroundTransparency = 0.3
	shade.BorderSizePixel = 0
	shade.Size = UDim2.fromScale(0.48, 1)
	shade.Parent = banner

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(12, compactBanner and 7 or 12)
	title.Size = UDim2.new(0.43, -12, 0, compactBanner and 26 or 38)
	title.Font = Enum.Font.GothamBlack
	title.Text = bannerTitle
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextSize = compactBanner and 14 or 18
	title.TextWrapped = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = banner

	local subtitle = Instance.new("TextLabel")
	subtitle.BackgroundTransparency = 1
	subtitle.Position = UDim2.fromOffset(12, compactBanner and 35 or 54)
	subtitle.Size = UDim2.new(0.43, -12, 0, compactBanner and 19 or 25)
	subtitle.Font = Enum.Font.GothamBold
	subtitle.Text = bannerSubtitle
	subtitle.TextColor3 = palette.Use
	subtitle.TextSize = compactBanner and 9 or 11
	subtitle.TextXAlignment = Enum.TextXAlignment.Left
	subtitle.Parent = banner
end

local function genericMenuIsCompact()
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(800, 600)
	return UserInputService.TouchEnabled or viewport.Y < 520
end

local function addSection(textValue, color)
	local compactSection = genericMenuIsCompact()
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -4, 0, compactSection and 44 or 30)
	label.Font = Enum.Font.GothamBold
	label.Text = textValue
	label.TextColor3 = color or palette.Text
	label.TextSize = compactSection and 12 or 14
	label.TextWrapped = compactSection
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = content
	return label
end

local function addRow(name, description, accent, iconName, layoutMode)
	local compactRow = genericMenuIsCompact() and layoutMode ~= "CompactInline"
	local rebirthLayout = layoutMode == "Rebirth"
	local rowHeight = rebirthLayout and (compactRow and 148 or 94) or compactRow and 116 or 64
	local row = Instance.new("Frame")
	row.Name = name
	row.Size = UDim2.new(1, -4, 0, rowHeight)
	row.BackgroundColor3 = Color3.fromRGB(27, 38, 49)
	row.BorderSizePixel = 0
	row.Parent = content
	row:SetAttribute("GenericPhoneLayout", compactRow and "StackedActionsV1" or "InlineActionsV1")
	setRounded(row, 6)
	local stripe = Instance.new("Frame")
	stripe.Size = UDim2.fromOffset(5, rowHeight)
	stripe.BackgroundColor3 = accent or palette.Use
	stripe.BorderSizePixel = 0
	stripe.Parent = row
	local textLeft = iconName and 62 or 15
	if iconName then
		createThemeIcon(row, iconName, UDim2.fromOffset(11, 11), UDim2.fromOffset(42, 42), "RowIcon")
		row:SetAttribute("ThemeIcon", iconName)
	end
	local titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.Position = UDim2.fromOffset(textLeft, 7)
	titleLabel.Size = UDim2.new(1, -(textLeft + (compactRow and 10 or 255)), 0, 23)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Text = name
	titleLabel.TextColor3 = palette.Text
	titleLabel.TextSize = 15
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
	titleLabel.Parent = row
	local descLabel = Instance.new("TextLabel")
	descLabel.BackgroundTransparency = 1
	descLabel.Position = UDim2.fromOffset(textLeft, 31)
	descLabel.Size = UDim2.new(1, -(textLeft + (compactRow and 10 or 255)), 0, rebirthLayout and (compactRow and 62 or 48) or compactRow and 34 or 22)
	descLabel.Font = Enum.Font.Gotham
	descLabel.Text = description
	descLabel.TextColor3 = palette.MutedText
	descLabel.TextSize = 12
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.TextWrapped = compactRow or rebirthLayout
	descLabel.TextTruncate = (compactRow or rebirthLayout) and Enum.TextTruncate.None or Enum.TextTruncate.AtEnd
	descLabel.Parent = row
	local actions = Instance.new("Frame")
	actions.Name = "Actions"
	actions.AnchorPoint = compactRow and Vector2.new(0, 1)
		or rebirthLayout and Vector2.new(1, 1)
		or Vector2.new(1, 0.5)
	actions.Position = compactRow and UDim2.new(0, 10, 1, -6)
		or rebirthLayout and UDim2.new(1, -8, 1, -6)
		or UDim2.new(1, -8, 0.5, 0)
	actions.Size = compactRow and UDim2.new(1, -18, 0, 44) or UDim2.fromOffset(238, 44)
	actions.BackgroundTransparency = 1
	actions.Parent = row
	local actionsLayout = Instance.new("UIListLayout")
	actionsLayout.FillDirection = Enum.FillDirection.Horizontal
	actionsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	actionsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	actionsLayout.Padding = UDim.new(0, 6)
	actionsLayout.Parent = actions
	return row, actions, titleLabel, descLabel
end

local function countNames(list)
	local counts = {}
	for _, name in ipairs(list) do counts[name] = (counts[name] or 0) + 1 end
	return counts
end

local function renderFists()
	local compactCards = genericMenuIsCompact()
	addSection("HERO FISTS  |  POWER PROGRESSION", palette.RoadLine)
	addRow(
		"COMBAT POWER",
		("Base %s  |  Equipped Fist x%.1f  |  Total %s"):format(
			formatNumber(latestStats.BasePower or latestStats.Power or 0),
			tonumber(latestStats.FistMultiplier) or 1,
			formatNumber(latestStats.EffectivePower or latestStats.Power or 0)
		),
		palette.Train,
		"Punch"
	)
	local owned = decodeJSON(latestStats.OwnedFistsJSON, { "Starter Glove" })
	local ownedPremium = decodeJSON(latestStats.OwnedPremiumFistsJSON, {})
	local shelf = Instance.new("Frame")
	shelf.Name = "FistProductCards"
	local cardColumns = compactCards and 2 or 3
	local cardHeight = 190
	local cardRows = math.ceil(#GameConfig.Fists / cardColumns)
	shelf.Size = UDim2.new(1, -4, 0, cardRows * cardHeight + math.max(0, cardRows - 1) * 8)
	shelf.BackgroundTransparency = 1
	shelf.Parent = content
	local grid = Instance.new("UIGridLayout")
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.CellSize = UDim2.new(1 / cardColumns, -6, 0, cardHeight)
	grid.FillDirectionMaxCells = cardColumns
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = shelf
	for _, item in ipairs(GameConfig.Fists) do
		local isOwned = table.find(owned, item.name) ~= nil
		local equipped = latestStats.EquippedFist == item.name
		local price = item.cost == 0 and "STARTER" or (formatNumber(item.cost) .. " COINS")
		local card = Instance.new("Frame")
		card.Name = item.displayName
		card.LayoutOrder = item.tier
		card.BackgroundColor3 = Color3.fromRGB(22, 29, 37)
		card.BorderSizePixel = 0
		card.Parent = shelf
		setRounded(card, 7)
		local stroke = Instance.new("UIStroke")
		stroke.Color = item.accent
		stroke.Thickness = equipped and 3 or 2
		stroke.Parent = card
		local tier = Instance.new("TextLabel")
		tier.BackgroundColor3 = item.accent
		tier.BorderSizePixel = 0
		tier.Position = UDim2.fromOffset(6, 6)
		tier.Size = UDim2.fromOffset(54, 20)
		tier.Font = Enum.Font.GothamBlack
		tier.Text = ("TIER %d"):format(item.tier)
		tier.TextColor3 = Color3.new(1, 1, 1)
		tier.TextSize = 10
		tier.Parent = card
		setRounded(tier, 4)
		createThemeIcon(card, item.icon, UDim2.new(0.5, -38, 0, 24), UDim2.fromOffset(76, 78), "ProductIcon")
		local nameLabel = Instance.new("TextLabel")
		nameLabel.BackgroundTransparency = 1
		nameLabel.Position = UDim2.fromOffset(6, 98)
		nameLabel.Size = UDim2.new(1, -12, 0, 22)
		nameLabel.Font = Enum.Font.GothamBlack
		nameLabel.Text = item.displayName
		nameLabel.TextColor3 = palette.Text
		nameLabel.TextSize = 12
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		nameLabel.Parent = card
		local detail = Instance.new("TextLabel")
		detail.BackgroundTransparency = 1
		detail.Position = UDim2.fromOffset(6, 119)
		detail.Size = UDim2.new(1, -12, 0, 18)
		detail.Font = Enum.Font.GothamBold
		detail.Text = ("x%.1f  |  %s"):format(item.mult, price)
		detail.TextColor3 = item.cost == 0 and palette.MutedText or palette.Reward
		detail.TextSize = 9
		detail.Parent = card
		local textValue = equipped and "EQUIPPED" or isOwned and "EQUIP" or "BUY"
		local button = makeMenuCommand(card, item.name .. "Action", textValue, equipped and palette.Reward or item.accent, function()
			if equipped then return end
			actionRemote:FireServer({ action = isOwned and "EquipFist" or "BuyFist", target = item.name })
		end)
		button.AnchorPoint = Vector2.new(0.5, 1)
		button.Position = UDim2.new(0.5, 0, 1, -6)
		button.Size = UDim2.new(1, -12, 0, 44)
		button.TextSize = 10
		button.Active = not equipped
	end
	addSection("PREMIUM HERO FISTS  |  PERMANENT GAME PASSES", palette.Reward)
	for _, item in ipairs(GameConfig.PremiumFists) do
		local isOwned = table.find(ownedPremium, item.name) ~= nil
		local equipped = latestStats.EquippedFist == item.name
		local purchaseConfigured = shared.PunchWallPurchaseRuntime.HasConfiguredGamePass(item)
		local purchaseUnavailable = not isOwned and not purchaseConfigured
		local _, actions = addRow(
			item.displayName,
			purchaseUnavailable
				and ("UNAVAILABLE  |  Permanent x%.1f Power  |  Pass ID not configured"):format(item.mult)
				or isOwned and not purchaseConfigured
					and ("OWNED  |  Permanent x%.1f Power  |  Equip anytime"):format(item.mult)
				or ("R$ %d  |  Permanent x%.1f Power  |  Tier %d Aura"):format(item.robux, item.mult, item.tier),
			item.accent,
			item.icon
		)
		local button = makeMenuCommand(actions, item.name .. "PremiumAction", equipped and "EQUIPPED" or isOwned and "EQUIP" or purchaseConfigured and ("R$ " .. item.robux) or "UNAVAILABLE", equipped and palette.Reward or purchaseUnavailable and palette.MutedText or item.accent, function()
			if equipped then return end
			if isOwned then
				actionRemote:FireServer({ action = "EquipFist", target = item.name })
			elseif purchaseConfigured then
				actionRemote:FireServer({ action = "BuyPremiumFist", target = item.name })
			end
		end)
		button.Size = UDim2.fromOffset(112, 44)
		button.Active = not equipped and (isOwned or purchaseConfigured)
		button.Selectable = button.Active
		button.AutoButtonColor = button.Active
		if purchaseUnavailable then
			shared.PunchWallPurchaseRuntime.MarkControlUnavailable(
				button,
				"UNAVAILABLE",
				"GamePassIdNotConfigured"
			)
		else
			shared.PunchWallPurchaseRuntime.MarkControlConfigured(button)
		end
	end
end

local function renderPets()
	addSection(("HERO SIDEKICKS  |  Equipped %d/%d"):format(#decodeJSON(latestStats.EquippedPetsJSON, {}), GameConfig.MaxEquippedPets), palette.Use)
	local pity = tonumber(latestStats.PetDropPity) or 0
	addRow(
		"HIDDEN WALL EGGS",
		("Break depth blocks to discover pets. Deeper layers unlock stronger species. Pity %d/%d."):format(pity, GameConfig.PetDrops.PityBreaks),
		palette.Reward,
		"Wall"
	)
	addSection("DEPTH DISCOVERY", palette.Use)
	for _, pet in ipairs(GameConfig.Pets) do
		local discovered = table.find(decodeJSON(latestStats.DiscoveredPetsJSON, {}), pet.name) ~= nil
		local status = discovered and "DISCOVERED" or "UNKNOWN"
		addRow(("[%s] %s"):format(pet.rarity, pet.name), ("%s  |  Depth %d+  |  Power +%.0f%%"):format(status, pet.minDepth or 1, pet.mult * 100), pet.color, "Pet")
	end
	addSection("PREMIUM SIDEKICKS  |  PERMANENT", palette.Reward)
	local ownedPremiumPets = decodeJSON(latestStats.OwnedPremiumPetsJSON, {})
	for _, pet in ipairs(GameConfig.PremiumPets) do
		local owned = table.find(ownedPremiumPets, pet.name) ~= nil
		local purchaseConfigured = shared.PunchWallPurchaseRuntime.HasConfiguredGamePass(pet)
		local purchaseUnavailable = not owned and not purchaseConfigured
		local displayPrice, regionalPriceResolved, regionalPriceState =
			shared.PunchWallPurchaseRuntime.GetGamePassDisplayPrice(pet, renderOpenPanel)
		local priceCopy = regionalPriceResolved and ("R$ %d"):format(displayPrice)
			or regionalPriceState == "Loading" and "CHECKING PRICE"
			or "PRICE AT CHECKOUT"
		local _, actions = addRow(
			pet.name,
			purchaseUnavailable
				and ("UNAVAILABLE  |  Permanent Power +%.0f%%  |  Pass ID not configured"):format(pet.mult * 100)
				or owned and not purchaseConfigured
					and ("OWNED  |  Permanent Power +%.0f%%  |  Equip anytime"):format(pet.mult * 100)
				or ("%s  |  Permanent Power +%.0f%%  |  Premium Aura"):format(priceCopy, pet.mult * 100),
			pet.accent,
			"Pet"
		)
		local button = makeMenuCommand(actions, pet.name .. "PremiumPet", owned and "EQUIP" or purchaseConfigured and priceCopy or "UNAVAILABLE", purchaseUnavailable and palette.MutedText or pet.accent, function()
			if owned or purchaseConfigured then
				actionRemote:FireServer({ action = "BuyPremiumPet", target = pet.name })
			end
		end)
		button:SetAttribute("GamePassId", tonumber(pet.gamePassId) or 0)
		button:SetAttribute("DefaultRobuxPrice", tonumber(pet.robux) or 0)
		button:SetAttribute("DisplayedRobuxPrice", regionalPriceResolved and displayPrice or 0)
		button:SetAttribute("RegionalPriceResolved", regionalPriceResolved)
		button:SetAttribute("RegionalPriceState", regionalPriceState)
		button.Size = UDim2.fromOffset(112, 44)
		button.Active = owned or purchaseConfigured
		button.Selectable = button.Active
		button.AutoButtonColor = button.Active
		if purchaseUnavailable then
			shared.PunchWallPurchaseRuntime.MarkControlUnavailable(
				button,
				"UNAVAILABLE",
				"GamePassIdNotConfigured"
			)
		else
			shared.PunchWallPurchaseRuntime.MarkControlConfigured(button)
		end
	end
	addSection("INVENTORY", palette.Text)
	local inventory = decodeJSON(latestStats.PetInventoryJSON, {})
	local equipped = decodeJSON(latestStats.EquippedPetsJSON, {})
	local locked = decodeJSON(latestStats.LockedPetsJSON, {})
	if legacyPetMenuRuntime.deleteKey ~= nil then
		legacyPetMenuRuntime.ValidateDelete(inventory)
	end
	local equippedCounts = countNames(equipped)
	local unlockedInventoryCounts = {}
	for slot, token in ipairs(inventory) do
		if table.find(locked, token) == nil and table.find(locked, "slot:" .. slot) == nil then
			unlockedInventoryCounts[token] = (unlockedInventoryCounts[token] or 0) + 1
		end
	end
	for index, petToken in ipairs(inventory) do
		-- Snapshot the exact occurrence for every callback. Duplicate tokens are
		-- intentionally distinguished by slot index and must never inherit the
		-- loop's next/final control values.
		local slotIndex = index
		local slotPetToken = petToken
		local petName, stars = GameConfig.ParsePetToken(slotPetToken)
		local pet = GameConfig.PetDefinition(petName)
		pet = pet or { rarity = "Unknown", mult = 0, color = palette.MutedText }
		local starText = string.rep("*", stars)
		local multiplier = GameConfig.PetMultiplierForToken(slotPetToken)
		local row, actions, titleLabel, descLabel = addRow(("#%02d  [%s] %s  %s"):format(slotIndex, pet.rarity, petName, starText), ("Power +%.0f%%  |  %d Star"):format(multiplier * 100, stars), pet.color)
		local thumbnail = Instance.new("ImageLabel")
		thumbnail.Name = "Pet Rarity Thumbnail"
		thumbnail.Position = UDim2.fromOffset(12, 10)
		thumbnail.Size = UDim2.fromOffset(44, 44)
		thumbnail.BackgroundColor3 = pet.color
		thumbnail.BackgroundTransparency = 0.12
		thumbnail.BorderSizePixel = 0
		thumbnail.Image = GameConfig.GeneratedGraphics.Iteration02PetIcon
		thumbnail.ScaleType = Enum.ScaleType.Crop
		thumbnail.Parent = row
		setRounded(thumbnail, 6)
		titleLabel.Position = UDim2.fromOffset(64, 7)
		descLabel.Position = UDim2.fromOffset(64, 31)
		local compactPetRow = genericMenuIsCompact()
		if not compactPetRow then
			actions.Size = UDim2.fromOffset(286, 44)
		end
		titleLabel.Size = UDim2.new(1, compactPetRow and -74 or -319, 0, 23)
		descLabel.Size = UDim2.new(1, compactPetRow and -74 or -319, 0, compactPetRow and 34 or 22)
		local equippedNow = (equippedCounts[slotPetToken] or 0) > 0
		if equippedNow then equippedCounts[slotPetToken] -= 1 end
		makeMenuCommand(actions, "Equip" .. slotIndex, equippedNow and "UNEQUIP" or "EQUIP", equippedNow and palette.Train or palette.Use, function()
			local petAction = equippedNow and "UnequipPet" or "EquipPet"
			if RunService:IsStudio() then
				-- Studio-only callback attestation lets real-input automation
				-- distinguish a delivered click from a tool-level no-op when a
				-- scrolling row was recreated or clipped before activation.
				gui:SetAttribute(
					"LegacyPetActionCallbackSequence",
					(gui:GetAttribute("LegacyPetActionCallbackSequence") or 0) + 1
				)
				gui:SetAttribute("LegacyPetActionCallback", petAction)
				gui:SetAttribute("LegacyPetActionCallbackIndex", slotIndex)
				gui:SetAttribute("LegacyPetActionCallbackToken", slotPetToken)
			end
			actionRemote:FireServer({
				action = petAction,
				target = slotPetToken,
				index = slotIndex,
			})
		end).Size = UDim2.fromOffset(70, 44)
		local slotToken = "slot:" .. slotIndex
		local isLocked = table.find(locked, slotToken) ~= nil or table.find(locked, slotPetToken) ~= nil
		local required = stars < GameConfig.MaxPetStars and GameConfig.PetFusionRequirement(stars) or 0
		local canFuse = required > 0 and (unlockedInventoryCounts[slotPetToken] or 0) >= required and not isLocked
		local fuseButton = makeMenuCommand(actions, "Fuse" .. slotIndex, required > 0 and ("FUSE " .. required) or "MAX", canFuse and palette.Reward or palette.PanelSoft, function()
			if canFuse then actionRemote:FireServer({ action = "FusePet", target = slotPetToken }) end
		end)
		fuseButton.Size = UDim2.fromOffset(64, 44)
		fuseButton.Active = canFuse
		makeMenuCommand(actions, "Lock" .. slotIndex, isLocked and "UNLOCK" or "LOCK", isLocked and palette.Train or palette.PanelSoft, function()
			actionRemote:FireServer({ action = "LockPet", target = slotPetToken, value = not isLocked, index = slotIndex })
		end).Size = UDim2.fromOffset(62, 44)
		local deleteArmed = not isLocked and legacyPetMenuRuntime.IsDeleteArmed(slotIndex, slotPetToken, inventory)
		local deleteButton = makeMenuCommand(
			actions,
			"Delete" .. slotIndex,
			isLocked and "LOCKED" or deleteArmed and "CONFIRM" or "DEL",
			isLocked and palette.PanelSoft or deleteArmed and palette.Reward or palette.Fail,
			function()
				if isLocked then
					legacyPetMenuRuntime.ClearDelete("locked_guard")
					return
				end
				if legacyPetMenuRuntime.IsDeleteArmed(slotIndex, slotPetToken, inventory) then
					legacyPetMenuRuntime.ClearDelete("confirmed")
					actionRemote:FireServer({ action = "DeletePet", target = slotPetToken, index = slotIndex })
					return
				end
				-- The first click only arms a short-lived, exact-slot confirmation.
				-- It deliberately performs no remote mutation.
				legacyPetMenuRuntime.ArmDelete(slotIndex, slotPetToken)
				task.defer(renderOpenPanel)
			end
		)
		deleteButton.Size = UDim2.fromOffset(isLocked and 64 or deleteArmed and 72 or 54, 44)
		deleteButton.Active = not isLocked
		deleteButton.Selectable = not isLocked
		deleteButton.AutoButtonColor = not isLocked
		deleteButton:SetAttribute("ExactInventoryIndex", slotIndex)
		deleteButton:SetAttribute("PetToken", slotPetToken)
		deleteButton:SetAttribute("ConfirmationArmed", deleteArmed)
		deleteButton:SetAttribute("FirstClickMutatesServer", false)
	end
	if #inventory == 0 then addSection("No sidekicks yet. Smash depth blocks until a hidden egg drops.", palette.MutedText) end
end

local function renderHonor()
	local honorBalance = math.max(0, tonumber(latestStats.Honor) or 0)
	local compactHonor = genericMenuIsCompact()
	local requestedItemId = tostring(shared.PunchWallSelectedHonorItemId or "")
	local highlightedItemId = requestedItemId ~= "" and requestedItemId
		or tostring(gui:GetAttribute("SelectedHonorItemId") or "")
	local selectedRow
	local selectedButton
	addSection(("WORLD HONOR  |  %s AVAILABLE  |  ONE RELIC ACTIVE"):format(formatNumber(honorBalance)), palette.Reward)
	if compactHonor then
		addSection("EARN: DEPTH + REBIRTH MILESTONES • TITAN CLEARS 12/5/5 • HERO SPIN: NO HONOR", palette.MutedText)
	else
		addRow(
			"HOW TO EARN HONOR",
			"Reach Depth milestones • Rebirth milestones • Defeat Titan after Depth 75 (first clear today 12 Honor, then 5, max 3/day)",
			palette.Use,
			"Wall"
		)
		addSection("HONOR IS PRESTIGE CURRENCY • HERO SPIN DOES NOT AWARD HONOR", palette.MutedText)
	end
	local _, honorPackActions = addRow(
		"OPTIONAL HONOR PACKS",
		"Currency only • relic Depth and Rebirth gates still apply",
		palette.Reward,
		"Honor"
	)
	local getHonorButton = makeMenuCommand(honorPackActions, "GetHonorPacks", "GET HONOR", palette.Reward, function()
		shared.PunchWallHeroShopPage = "Honor"
		openGameTab("Fists")
		if shared.PunchWallHeroShopRefresh then
			shared.PunchWallHeroShopRefresh({ force = true, reason = "honor-catalog-get-honor" })
		end
	end)
	getHonorButton.Size = UDim2.fromOffset(118, 44)
	getHonorButton:SetAttribute("ShopPage", "Honor")
	local owned = decodeJSON(latestStats.OwnedHonorItemsJSON, {})
	for _, item in ipairs(GameConfig.HonorItems) do
		local isOwned = table.find(owned, item.id) ~= nil or table.find(owned, item.name) ~= nil
		local equipped = latestStats.EquippedHonorItem == item.id or latestStats.EquippedHonorItem == item.name
		local unlocked = GameConfig.HonorItemUnlocked(item, latestStats.Depth, latestStats.Rebirths)
		local requirement = ("REQ DEPTH %d"):format(item.requiredDepth or 0)
		if (item.requiredRebirths or 0) > 0 then
			requirement ..= (" • REBIRTH %d"):format(item.requiredRebirths)
		end
		local row, actions = addRow(
			item.displayName,
			("%s • %d HONOR • +%d%% EQUIPPED POWER • %s"):format(item.rarity or "RELIC", item.cost, math.floor(item.powerBonus * 100 + 0.5), requirement),
			item.color,
			item.icon or "Success",
			compactHonor and "CompactInline" or nil
		)
		local canAfford = honorBalance >= item.cost
		local caption = equipped and "EQUIPPED"
			or isOwned and "EQUIP"
			or not unlocked and "LOCKED"
			or not canAfford and ("NEED %s"):format(formatNumber(item.cost - honorBalance))
			or ("UNLOCK %s"):format(formatNumber(item.cost))
		local actionable = not equipped and (isOwned or (unlocked and canAfford))
		local button = makeMenuCommand(actions, item.name .. "HonorAction", caption, equipped and palette.Reward or item.color, function()
			if actionable then actionRemote:FireServer({ action = "BuyHonorItem", target = item.id }) end
		end)
		button.Size = UDim2.fromOffset(118, 44)
		button.Active = actionable
		button.AutoButtonColor = actionable
		button:SetAttribute("HonorItemId", item.id)
		button:SetAttribute("HonorState", equipped and "Equipped" or isOwned and "Owned" or not unlocked and "Locked" or canAfford and "Affordable" or "Insufficient")
		if highlightedItemId ~= "" and item.id == highlightedItemId then
			row:SetAttribute("HonorWorldSelection", item.id)
			row.BackgroundColor3 = Color3.fromRGB(42, 49, 58):Lerp(item.color, 0.18)
			local selectionStroke = Instance.new("UIStroke")
			selectionStroke.Name = "HonorWorldSelectionStroke"
			selectionStroke.Color = item.color
			selectionStroke.Thickness = 2
			selectionStroke.Transparency = 0.08
			selectionStroke.Parent = row
			if requestedItemId ~= "" then
				selectedRow = row
				selectedButton = button
			end
		end
	end
	if selectedRow and selectedButton then
		task.defer(function()
			if not selectedRow.Parent or not selectedButton.Parent or not mainPanel.Visible or activeTab ~= "Honor" then return end
			-- AutomaticCanvasSize settles one or more frames after the rows are
			-- parented, especially on compact phone layouts. Wait boundedly for the
			-- real canvas before clamping, otherwise a bottom relic can remain at Y=0.
			local layoutDeadline = os.clock() + 1.25
			repeat
				RunService.Heartbeat:Wait()
			until content.AbsoluteCanvasSize.Y > content.AbsoluteSize.Y or os.clock() >= layoutDeadline
			local rowCenter = selectedRow.AbsolutePosition.Y + selectedRow.AbsoluteSize.Y * 0.5
			local viewportCenter = content.AbsolutePosition.Y + content.AbsoluteSize.Y * 0.5
			local maxY = math.max(0, content.AbsoluteCanvasSize.Y - content.AbsoluteSize.Y)
			content.CanvasPosition = Vector2.new(0, math.clamp(content.CanvasPosition.Y + rowCenter - viewportCenter, 0, maxY))
			GuiService.SelectedObject = selectedButton
			gui:SetAttribute("SelectedHonorItemId", requestedItemId)
			gui:SetAttribute("SelectedHonorCanvasY", content.CanvasPosition.Y)
			-- Clear only after the final live render consumed the request. Responsive
			-- layout may rebuild Content after openGameTab; clearing before that
			-- rebuild made compact selection intermittently snap back to the top.
			if shared.PunchWallSelectedHonorItemId == requestedItemId then
				shared.PunchWallSelectedHonorItemId = nil
			end
		end)
	end
	addSection(
		"OWNED RELICS ARE PERMANENT • EQUIPPING AN OWNED RELIC COSTS 0 HONOR",
		palette.MutedText
	)
end

local function renderTasks()
	addSection("HERO MISSIONS AND REWARDS", palette.RoadLine)
	local tutorial = latestStats.Tutorial or {}
	addRow("Tutorial", ("%s  |  %s"):format(tostring(tutorial.title or "Complete"), tostring(tutorial.detail or "")), palette.Train, "Quest")
	local _, dailyActions = addRow("Daily Supply", "Claim once per UTC day", palette.Reward, "Coin")
	local dailyClaimed = latestStats.LastDailyDate == os.date("!%Y-%m-%d")
	local dailyButton = makeMenuCommand(dailyActions, "ClaimDaily", dailyClaimed and "CLAIMED" or "CLAIM", dailyClaimed and palette.PanelSoft or palette.Reward, function() actionRemote:FireServer({ action = "ClaimDaily" }) end)
	dailyButton.Active = not dailyClaimed
	dailyButton.Size = UDim2.fromOffset(100, 44)
	local breaks = latestStats.DailyBreaks or 0
	local questClaimed = (latestStats.DailyQuestClaimed or 0) >= 1
	local questReady = breaks >= GameConfig.Rewards.QuestBreakTarget
	local _, questActions = addRow("City Cleanup", ("Break buildings %d/%d  |  Reward %s coins"):format(breaks, GameConfig.Rewards.QuestBreakTarget, formatNumber(GameConfig.Rewards.QuestCoins)), palette.Punch, "Wall")
	local questButton = makeMenuCommand(questActions, "ClaimQuest", questClaimed and "CLAIMED" or questReady and "CLAIM" or "WAIT", questReady and not questClaimed and palette.Reward or palette.PanelSoft, function() actionRemote:FireServer({ action = "ClaimQuest" }) end)
	questButton.Active = questReady and not questClaimed
	questButton.Size = UDim2.fromOffset(100, 44)
	local played = latestStats.PlaytimeSeconds or 0
	local playtimeClaimed = (latestStats.PlaytimeClaimed or 0) >= 1
	local playtimeReady = played >= GameConfig.Rewards.PlaytimeSeconds
	local _, playActions = addRow("Five Minute Supply", ("Playtime %d/%d sec  |  Reward %s coins"):format(math.min(played, GameConfig.Rewards.PlaytimeSeconds), GameConfig.Rewards.PlaytimeSeconds, formatNumber(GameConfig.Rewards.PlaytimeCoins)), palette.Use, "Success")
	local playButton = makeMenuCommand(playActions, "ClaimPlaytime", playtimeClaimed and "CLAIMED" or playtimeReady and "CLAIM" or "WAIT", playtimeReady and not playtimeClaimed and palette.Reward or palette.PanelSoft, function() actionRemote:FireServer({ action = "ClaimPlaytime" }) end)
	playButton.Active = playtimeReady and not playtimeClaimed
	playButton.Size = UDim2.fromOffset(100, 44)
	local spinReady = (tonumber(latestStats.SpinCredits) or 0) > 0 or os.time() >= (tonumber(latestStats.SpinReadyAt) or 0)
	local spinDescription = (tonumber(latestStats.SpinCredits) or 0) > 0
		and (("%d bonus spin%s ready"):format(latestStats.SpinCredits, latestStats.SpinCredits == 1 and "" or "s"))
		or spinReady and "Free Hero Spin ready now"
		or ("Next free spin in %dh %02dm"):format(math.floor(math.max(0, latestStats.SpinReadyAt - os.time()) / 3600), math.floor(math.max(0, latestStats.SpinReadyAt - os.time()) % 3600 / 60))
	local _, spinActions = addRow("Hero Prize Spin", spinDescription, palette.Use, "Success")
	makeMenuCommand(spinActions, "OpenSpin", spinReady and "SPIN" or "VIEW", spinReady and palette.Reward or palette.PanelSoft, function()
		if shared.PunchWallOpenSpin then shared.PunchWallOpenSpin() end
	end).Size = UDim2.fromOffset(100, 44)
	-- Rebirth moved to its own child-friendly modal. Missions intentionally end
	-- here so the old combined Tasks/Rebirth presentation can never render.
	if false then -- retained temporarily for selector compatibility; never player-visible
	local currentRebirths = math.max(0, math.floor(tonumber(latestStats.Rebirths) or 0))
	local requirement = GameConfig.RebirthRequirement(currentRebirths)
	local currentLevel = math.max(1, math.floor(tonumber(latestStats.WallLevel) or 1))
	local currentCoins = math.max(0, math.floor(tonumber(latestStats.Coins) or 0))
	local ready = not requirement.maxed
		and currentLevel >= requirement.requiredLevel
		and currentCoins >= requirement.requiredCoins
	local signature = ("%d:%d:%d:%d:%d"):format(
		currentRebirths,
		currentLevel,
		currentCoins,
		requirement.requiredLevel,
		requirement.requiredCoins
	)
	if shared.PunchWallRebirthRuntime.armed and (shared.PunchWallRebirthRuntime.expiresAt <= os.clock() or shared.PunchWallRebirthRuntime.signature ~= signature or not ready) then
		shared.PunchWallRebirthRuntime.armed = false
		shared.PunchWallRebirthRuntime.pending = false
		shared.PunchWallRebirthRuntime.signature = ""
		shared.PunchWallRebirthRuntime.expiresAt = 0
		shared.PunchWallRebirthRuntime.generation += 1
	end
	local stateName = requirement.maxed and "MAXED"
		or ready and (shared.PunchWallRebirthRuntime.pending and "PENDING" or shared.PunchWallRebirthRuntime.armed and "CONFIRM" or "READY")
		or "LOCKED"
	local description
	if requirement.maxed then
		description = ("MAX %d REBIRTHS • PERMANENT POWER x%.2f"):format(GameConfig.Rebirth.MaxRebirths, GameConfig.RebirthBonus(currentRebirths))
	elseif ready then
		description = ("GAIN REBIRTH %d • PERMANENT POWER x%.2f\nRESET POWER→%s • COINS→0 • WALL LV→1 • FIST→STARTER | KEEP DEPTH • GEAR • PETS • HONOR"):format(
			requirement.nextRebirths,
			requirement.permanentMultiplier,
			formatNumber(GameConfig.Rebirth.StartingPower)
		)
	else
		local missingLevel = math.max(0, requirement.requiredLevel - currentLevel)
		local missingCoins = math.max(0, requirement.requiredCoins - currentCoins)
		local missingLevelUnit = missingLevel == 1 and "LEVEL" or "LEVELS"
		description = ("WALL LV %d/%d • COINS %s/%s\nNEED %d %s + %s COINS • NEXT POWER x%.2f"):format(
			currentLevel,
			requirement.requiredLevel,
			formatNumber(currentCoins),
			formatNumber(requirement.requiredCoins),
			missingLevel,
			missingLevelUnit,
			formatNumber(missingCoins),
			requirement.permanentMultiplier
		)
	end
	local rebirthRow, rebirthActions = addRow(
		("HERO REBIRTH • %s"):format(stateName),
		description,
		ready and Color3.fromRGB(205, 164, 63) or Color3.fromRGB(126, 83, 160),
		"Rebirth",
		"Rebirth"
	)
	rebirthRow:SetAttribute("RebirthState", stateName)
	rebirthRow:SetAttribute("CurrentRebirths", currentRebirths)
	rebirthRow:SetAttribute("RequiredLevel", requirement.requiredLevel)
	rebirthRow:SetAttribute("RequiredCoins", requirement.requiredCoins)
	rebirthRow:SetAttribute("NextPermanentMultiplier", requirement.permanentMultiplier)
	rebirthRow:SetAttribute("ResetContract", "PowerCoinsWallLevelWallXPEquippedFistTraining")
	rebirthRow:SetAttribute("RetainContract", "DepthScoreOwnedGearPetsHonorPremiumSettingsBoosts")
	local function cancelRebirthConfirmation()
		shared.PunchWallRebirthRuntime.armed = false
		shared.PunchWallRebirthRuntime.signature = ""
		shared.PunchWallRebirthRuntime.expiresAt = 0
		shared.PunchWallRebirthRuntime.generation += 1
		gui:SetAttribute("RebirthConfirmationState", "Canceled")
		shared.PunchWallSelectedTaskItem = "Rebirth"
		renderOpenPanel()
	end
	local function confirmRebirth()
		if shared.PunchWallRebirthRuntime.pending or not shared.PunchWallRebirthRuntime.armed or shared.PunchWallRebirthRuntime.signature ~= signature or shared.PunchWallRebirthRuntime.expiresAt <= os.clock() then return end
		shared.PunchWallRebirthRuntime.pending = true
		gui:SetAttribute("RebirthConfirmationState", "Pending")
		gui:SetAttribute("RebirthPending", true)
		gui:SetAttribute("RebirthRequestCount", (gui:GetAttribute("RebirthRequestCount") or 0) + 1)
		shared.PunchWallSelectedTaskItem = "Rebirth"
		actionRemote:FireServer({
			action = "Rebirth",
			value = { confirmed = true, expectedRebirths = currentRebirths },
		})
		renderOpenPanel()
	end
	local function reviewRebirth()
		shared.PunchWallRebirthRuntime.armed = true
		shared.PunchWallRebirthRuntime.pending = false
		shared.PunchWallRebirthRuntime.signature = signature
		shared.PunchWallRebirthRuntime.expiresAt = os.clock() + GameConfig.Rebirth.ConfirmationSeconds
		shared.PunchWallRebirthRuntime.generation += 1
		local generation = shared.PunchWallRebirthRuntime.generation
		gui:SetAttribute("RebirthConfirmationState", "Armed")
		gui:SetAttribute("RebirthFirstActivationMutationGuard", true)
		shared.PunchWallSelectedTaskItem = "Rebirth"
		task.delay(GameConfig.Rebirth.ConfirmationSeconds, function()
			if generation ~= shared.PunchWallRebirthRuntime.generation or shared.PunchWallRebirthRuntime.expiresAt > os.clock() then return end
			shared.PunchWallRebirthRuntime.armed = false
			shared.PunchWallRebirthRuntime.signature = ""
			shared.PunchWallRebirthRuntime.expiresAt = 0
			gui:SetAttribute("RebirthConfirmationState", "Expired")
			if mainPanel.Visible and activeTab == "Tasks" then renderOpenPanel() end
		end)
		renderOpenPanel()
	end
	shared.PunchWallRebirthActionCallbacks = {
		Cancel = cancelRebirthConfirmation,
		Confirm = confirmRebirth,
		Review = reviewRebirth,
	}
	local focusButton
	if requirement.maxed or not ready then
		focusButton = makeMenuCommand(rebirthActions, "RebirthLocked", requirement.maxed and "MAXED" or "LOCKED", palette.PanelSoft, function() end)
		focusButton.Active = false
		focusButton.Selectable = false
		focusButton.AutoButtonColor = false
	elseif shared.PunchWallRebirthRuntime.pending then
		focusButton = makeMenuCommand(rebirthActions, "RebirthPending", "REBIRTHING…", palette.PanelSoft, function() end)
		focusButton.Active = false
		focusButton.Selectable = false
		focusButton.AutoButtonColor = false
	elseif shared.PunchWallRebirthRuntime.armed then
		local cancelButton = makeMenuCommand(rebirthActions, "CancelRebirth", "CANCEL", palette.PanelSoft, cancelRebirthConfirmation)
		cancelButton.Size = UDim2.fromOffset(112, 44)
		cancelButton:SetAttribute("MinimumTouchTarget", 44)
		focusButton = makeMenuCommand(rebirthActions, "ConfirmRebirth", "CONFIRM", Color3.fromRGB(142, 88, 203), confirmRebirth)
		cancelButton.NextSelectionRight = focusButton
		focusButton.NextSelectionLeft = cancelButton
	else
		focusButton = makeMenuCommand(rebirthActions, "ReviewRebirth", "REVIEW", Color3.fromRGB(142, 88, 203), reviewRebirth)
	end
	if focusButton then
		focusButton.Size = UDim2.fromOffset(112, 44)
		focusButton:SetAttribute("MinimumTouchTarget", 44)
		focusButton:SetAttribute("RebirthSemanticAction", stateName)
	end
	if shared.PunchWallSelectedTaskItem == "Rebirth" then
		task.defer(function()
			local deadline = os.clock() + 1.25
			repeat RunService.Heartbeat:Wait()
			until content.AbsoluteCanvasSize.Y > 0 or os.clock() >= deadline
			if not mainPanel.Visible or activeTab ~= "Tasks" or not rebirthRow.Parent then return end
			local rowCenter = rebirthRow.AbsolutePosition.Y - content.AbsolutePosition.Y + content.CanvasPosition.Y + rebirthRow.AbsoluteSize.Y / 2
			local maxY = math.max(0, content.AbsoluteCanvasSize.Y - content.AbsoluteSize.Y)
			content.CanvasPosition = Vector2.new(0, math.clamp(rowCenter - content.AbsoluteSize.Y / 2, 0, maxY))
			if focusButton and focusButton.Active and focusButton.Selectable then
				local lastInput = UserInputService:GetLastInputType()
				local usesSelection = lastInput == Enum.UserInputType.Keyboard
					or string.find(lastInput.Name, "Gamepad", 1, true) == 1
				GuiService.SelectedObject = usesSelection and focusButton or nil
			end
			gui:SetAttribute("SelectedTaskItem", "Rebirth")
			gui:SetAttribute("SelectedRebirthCanvasY", content.CanvasPosition.Y)
			shared.PunchWallSelectedTaskItem = nil
		end)
	end
	end
end

local function renderSettings()
	addSection("ACCESSIBILITY AND FEEDBACK", palette.RoadLine)
	local function settingRow(name, description, key)
		local _, actions = addRow(name, description, palette.Use, "Settings")
		makeMenuCommand(actions, key, clientSettings[key] and "ON" or "OFF", clientSettings[key] and palette.Reward or palette.Fail, function()
			if key == "sound" then
				shared.PunchWallApplySoundSetting(not clientSettings.sound, true)
			else
				clientSettings[key] = not clientSettings[key]
				if key == "motion" and shared.PunchWallApplyFistAuraMotion then
					shared.PunchWallApplyFistAuraMotion()
				end
				if key == "motion" and shared.PunchWallRefreshHonorMotion then
					shared.PunchWallRefreshHonorMotion()
				end
				actionRemote:FireServer({ action = "UpdateSettings", value = clientSettings })
			end
			renderOpenPanel()
		end)
	end
	settingRow("Motion Feedback", "Camera impulse, pop movement, and punch motion", "motion")
	settingRow("Sound Feedback", "Punch, reward, collapse, and boss audio", "sound")
	local _, scaleActions = addRow("UI Scale", ("Current %.0f%%"):format((clientSettings.uiScale or 1) * 100), palette.Train, "Settings")
	for _, value in ipairs({ 0.8, 1, 1.2 }) do
		makeMenuCommand(scaleActions, "Scale" .. value, ("%.0f%%"):format(value * 100), value == clientSettings.uiScale and palette.Reward or palette.Use, function()
			clientSettings.uiScale = value
			actionRemote:FireServer({ action = "UpdateSettings", value = clientSettings })
			renderOpenPanel()
		end).Size = UDim2.fromOffset(70, 44)
	end
	if RunService:IsStudio() then
		local active = latestStats.StudioTestMode == true
		local _, testActions = addRow("Studio High-Power Test", active and "Power 1.5B | Wall Lv.99 | Coins 1B" or "Temporary test values. Restores your current values when disabled.", active and palette.Reward or palette.Train, "Punch")
		makeMenuCommand(testActions, "ToggleStudioHighPowerTest", active and "RESTORE" or "ENABLE", active and palette.Fail or palette.Reward, function()
			actionRemote:FireServer({ action = "ToggleStudioHighPowerTest", value = not active })
		end).Size = UDim2.fromOffset(112, 44)
	end
end

-- Standalone player windows -------------------------------------------------
-- Shop and Inventory still share the neutral modal host for compatibility,
-- but the old five-tab launcher is no longer a player-facing surface.
(function()
local standaloneWindows = {}
shared.PunchWallStandaloneWindows = standaloneWindows
local standaloneDimmer = Instance.new("TextButton")
standaloneDimmer.Name = "StandaloneWindowDimmer"
standaloneDimmer.Size = UDim2.fromScale(1, 1)
standaloneDimmer.BackgroundColor3 = Color3.fromRGB(2, 5, 9)
standaloneDimmer.BackgroundTransparency = 0.28
standaloneDimmer.BorderSizePixel = 0
standaloneDimmer.Text = ""
standaloneDimmer.AutoButtonColor = false
standaloneDimmer.Active = true
standaloneDimmer.Visible = false
standaloneDimmer.ZIndex = 70
standaloneDimmer.Parent = gui

local function createStandalonePanel(name, titleText, accent, iconName)
	local root = Instance.new("Frame")
	root.Name = name
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromOffset(720, 468)
	root.BackgroundColor3 = Color3.fromRGB(8, 15, 23)
	root.BorderSizePixel = 0
	root.Visible = false
	root.ZIndex = 71
	root.Parent = gui
	root:SetAttribute("StandaloneWindow", true)
	root:SetAttribute("MinimumTouchTarget", 44)
	setRounded(root, 12)
	local stroke = Instance.new("UIStroke")
	stroke.Name = "StandaloneStroke"
	stroke.Color = accent
	stroke.Thickness = 3
	stroke.Transparency = 0.08
	stroke.Parent = root
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 70)
	header.BackgroundColor3 = Color3.fromRGB(18, 26, 38)
	header.BorderSizePixel = 0
	header.ZIndex = 72
	header.Parent = root
	setRounded(header, 12)
	createThemeIcon(header, iconName, UDim2.fromOffset(16, 11), UDim2.fromOffset(48, 48), "HeaderIcon").ZIndex = 73
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Position = UDim2.fromOffset(76, 8)
	titleLabel.Size = UDim2.new(1, -148, 0, 34)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.Text = titleText
	titleLabel.TextColor3 = palette.Text
	titleLabel.TextSize = 26
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.ZIndex = 73
	titleLabel.Parent = header
	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.Position = UDim2.fromOffset(77, 40)
	subtitle.Size = UDim2.new(1, -152, 0, 20)
	subtitle.BackgroundTransparency = 1
	subtitle.Font = Enum.Font.GothamBold
	subtitle.Text = ""
	subtitle.TextColor3 = accent
	subtitle.TextSize = 12
	subtitle.TextScaled = true
	subtitle.TextXAlignment = Enum.TextXAlignment.Left
	subtitle.ZIndex = 73
	subtitle.Parent = header
	local subtitleTextSize = Instance.new("UITextSizeConstraint")
	subtitleTextSize.MinTextSize = 8
	subtitleTextSize.MaxTextSize = 12
	subtitleTextSize.Parent = subtitle
	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -10, 0, 10)
	close.Size = UDim2.fromOffset(48, 48)
	close.BackgroundColor3 = palette.Fail
	close.BorderSizePixel = 0
	close.Font = Enum.Font.GothamBlack
	close.Text = "X"
	close.TextColor3 = Color3.new(1, 1, 1)
	close.TextSize = 19
	close.ZIndex = 74
	close.Parent = root
	setRounded(close, 8)
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.Position = UDim2.fromOffset(12, 82)
	body.Size = UDim2.new(1, -24, 1, -94)
	body.BackgroundTransparency = 1
	body.ZIndex = 72
	body.Parent = root
	return root, body, close, subtitle
end

local rebirthPanel, rebirthBody, rebirthClose, rebirthSubtitle = createStandalonePanel(
	"RebirthWindow",
	"REBIRTH",
	Color3.fromRGB(181, 111, 239),
	"Rebirth"
)
local settingsPanel, settingsBody, settingsClose, settingsSubtitle = createStandalonePanel(
	"SettingsWindow",
	"SETTINGS",
	Color3.fromRGB(46, 205, 255),
	"Settings"
)
settingsPanel.Size = UDim2.fromOffset(640, 420)

local function setDescendantZIndex(root, zIndex)
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("GuiObject") and descendant.ZIndex < zIndex then
			descendant.ZIndex = zIndex
		end
	end
end

local function clearStandaloneBody(body)
	for _, child in ipairs(body:GetChildren()) do
		if child:IsA("GuiObject") or child:IsA("UIComponent") then
			child:Destroy()
		end
	end
end

local function standaloneLabel(parent, name, textValue, position, size, color, textSize, font, alignment)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Position = position
	label.Size = size
	label.BackgroundTransparency = 1
	label.Font = font or Enum.Font.GothamBold
	label.Text = textValue
	label.TextColor3 = color or palette.Text
	label.TextSize = textSize or 14
	label.TextScaled = true
	label.TextWrapped = true
	label.TextXAlignment = alignment or Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.ZIndex = 74
	label.Parent = parent
	local textConstraint = Instance.new("UITextSizeConstraint")
	textConstraint.MinTextSize = math.min(7, textSize or 14)
	textConstraint.MaxTextSize = textSize or 14
	textConstraint.Parent = label
	return label
end

local function standaloneCard(parent, name, position, size, accent)
	local card = Instance.new("Frame")
	card.Name = name
	card.Position = position
	card.Size = size
	card.BackgroundColor3 = Color3.fromRGB(17, 27, 39)
	card.BorderSizePixel = 0
	card.ZIndex = 73
	card.Parent = parent
	setRounded(card, 9)
	local stroke = Instance.new("UIStroke")
	stroke.Color = accent
	stroke.Thickness = 2
	stroke.Transparency = 0.18
	stroke.Parent = card
	return card
end

local function shortReadyText(current, required, formatter)
	formatter = formatter or tostring
	return ("%s / %s"):format(formatter(math.min(current, required)), formatter(required))
end

local function rebirthUiRequirement()
	local currentRebirths = math.max(0, math.floor(tonumber(latestStats.Rebirths) or 0))
	local canonical = GameConfig.RebirthRequirement(currentRebirths)
	local requiredLevel = math.max(1, math.floor(tonumber(latestStats.RebirthRequiredLevel) or canonical.requiredLevel))
	local requiredCoins = math.max(0, math.floor(tonumber(latestStats.RebirthRequiredCoins) or canonical.requiredCoins))
	local nextRebirths = math.max(currentRebirths, math.floor(tonumber(latestStats.RebirthNextCount) or canonical.nextRebirths))
	local nextBonus = tonumber(latestStats.RebirthNextBonus) or canonical.permanentMultiplier
	local maxed = latestStats.RebirthMaxed == true or canonical.maxed
	local currentLevel = math.max(1, math.floor(tonumber(latestStats.WallLevel) or 1))
	local currentCoins = math.max(0, math.floor(tonumber(latestStats.Coins) or 0))
	local ready = not maxed and currentLevel >= requiredLevel and currentCoins >= requiredCoins
	return {
		currentRebirths = currentRebirths,
		nextRebirths = nextRebirths,
		currentBonus = GameConfig.RebirthBonus(currentRebirths),
		nextBonus = nextBonus,
		requiredLevel = requiredLevel,
		requiredCoins = requiredCoins,
		currentLevel = currentLevel,
		currentCoins = currentCoins,
		maxed = maxed,
		ready = ready,
		policyVersion = GameConfig.Rebirth.Version,
	}
end

local function resetRebirthConfirmation(state)
	shared.PunchWallRebirthRuntime.armed = false
	shared.PunchWallRebirthRuntime.pending = false
	shared.PunchWallRebirthRuntime.signature = ""
	shared.PunchWallRebirthRuntime.expiresAt = 0
	shared.PunchWallRebirthRuntime.generation += 1
	gui:SetAttribute("RebirthConfirmationState", state or "Closed")
	gui:SetAttribute("RebirthPending", false)
end

local renderStandaloneRebirth
local renderStandaloneSettings
local closeStandaloneWindows
renderStandaloneRebirth = function()
	if not rebirthPanel.Visible then return end
	clearStandaloneBody(rebirthBody)
	local q = rebirthUiRequirement()
	local signature = ("%s:%d:%d:%d:%d:%d"):format(q.policyVersion, q.currentRebirths, q.currentLevel, q.currentCoins, q.requiredLevel, q.requiredCoins)
	if shared.PunchWallRebirthRuntime.armed and (
		shared.PunchWallRebirthRuntime.expiresAt <= os.clock()
		or shared.PunchWallRebirthRuntime.signature ~= signature
		or not q.ready
	) then
		resetRebirthConfirmation("Expired")
	end
	local stateName = q.maxed and "MAXED"
		or q.ready and (shared.PunchWallRebirthRuntime.pending and "PENDING" or shared.PunchWallRebirthRuntime.armed and "CONFIRM" or "READY")
		or "LOCKED"
	rebirthPanel:SetAttribute("RebirthState", stateName)
	rebirthPanel:SetAttribute("CurrentRebirths", q.currentRebirths)
	rebirthPanel:SetAttribute("RequiredLevel", q.requiredLevel)
	rebirthPanel:SetAttribute("RequiredCoins", q.requiredCoins)
	rebirthPanel:SetAttribute("NextPermanentMultiplier", q.nextBonus)
	rebirthPanel:SetAttribute("PolicyVersion", q.policyVersion)
	rebirthPanel:SetAttribute("UsesServerPreviewFields", true)
	rebirthPanel:SetAttribute("LegacyCombinedTabsVisible", false)
	rebirthSubtitle.Text = q.maxed and ("MAX %d • POWER x%.2f"):format(GameConfig.Rebirth.MaxRebirths, q.currentBonus)
		or ("REBIRTH #%d → #%d • PERMANENT POWER"):format(q.currentRebirths, q.nextRebirths)

	local reward = standaloneCard(rebirthBody, "RewardCard", UDim2.fromScale(0, 0), UDim2.fromScale(0.28, 0.48), Color3.fromRGB(181, 111, 239))
	createThemeIcon(reward, "Rebirth", UDim2.new(0.5, -39, 0, 10), UDim2.fromOffset(78, 78), "RewardIcon")
	local rewardTitle = standaloneLabel(reward, "RewardTitle", "POWER", UDim2.fromScale(0.08, 0.54), UDim2.fromScale(0.84, 0.18), Color3.fromRGB(218, 184, 255), 12, Enum.Font.GothamBlack, Enum.TextXAlignment.Center)
	rewardTitle.TextWrapped = false
	local rewardValue = standaloneLabel(reward, "RewardValue", ("x%.2f → x%.2f"):format(q.currentBonus, q.nextBonus), UDim2.fromScale(0.04, 0.71), UDim2.fromScale(0.92, 0.25), Color3.fromRGB(255, 222, 89), 18, Enum.Font.GothamBlack, Enum.TextXAlignment.Center)
	rewardValue.TextWrapped = false

	local levelMet = q.currentLevel >= q.requiredLevel
	local levelCard = standaloneCard(rebirthBody, "WallLevelRequirement", UDim2.fromScale(0.30, 0), UDim2.fromScale(0.335, 0.48), levelMet and palette.Reward or palette.Fail)
	createThemeIcon(levelCard, "Wall", UDim2.fromOffset(12, 14), UDim2.fromOffset(64, 64), "RequirementIcon")
	standaloneLabel(levelCard, "RequirementTitle", "WALL LEVEL", UDim2.fromOffset(82, 9), UDim2.new(1, -92, 0, 28), palette.Text, 13, Enum.Font.GothamBlack)
	standaloneLabel(levelCard, "RequirementValue", shortReadyText(q.currentLevel, q.requiredLevel, formatNumber), UDim2.fromOffset(82, 34), UDim2.new(1, -92, 0, 32), levelMet and palette.Reward or palette.Text, 19, Enum.Font.GothamBlack)
	standaloneLabel(levelCard, "RequirementState", levelMet and "READY" or ("NEED %s"):format(formatNumber(q.requiredLevel - q.currentLevel)), UDim2.new(0, 12, 1, -42), UDim2.new(1, -24, 0, 30), levelMet and palette.Reward or palette.Fail, 12, Enum.Font.GothamBlack, Enum.TextXAlignment.Center)
	levelCard:SetAttribute("Met", levelMet)

	local coinsMet = q.currentCoins >= q.requiredCoins
	local coinCard = standaloneCard(rebirthBody, "CoinsRequirement", UDim2.fromScale(0.65, 0), UDim2.fromScale(0.35, 0.48), coinsMet and palette.Reward or palette.Fail)
	createThemeIcon(coinCard, "Coin", UDim2.fromOffset(12, 14), UDim2.fromOffset(64, 64), "RequirementIcon")
	standaloneLabel(coinCard, "RequirementTitle", "COINS", UDim2.fromOffset(82, 9), UDim2.new(1, -92, 0, 28), palette.Text, 13, Enum.Font.GothamBlack)
	standaloneLabel(coinCard, "RequirementValue", shortReadyText(q.currentCoins, q.requiredCoins, formatNumber), UDim2.fromOffset(82, 34), UDim2.new(1, -92, 0, 32), coinsMet and palette.Reward or palette.Text, 18, Enum.Font.GothamBlack)
	standaloneLabel(coinCard, "RequirementState", coinsMet and "READY" or ("NEED %s"):format(formatNumber(q.requiredCoins - q.currentCoins)), UDim2.new(0, 12, 1, -42), UDim2.new(1, -24, 0, 30), coinsMet and palette.Reward or palette.Fail, 12, Enum.Font.GothamBlack, Enum.TextXAlignment.Center)
	coinCard:SetAttribute("Met", coinsMet)

	local resetCard = standaloneCard(rebirthBody, "ResetContract", UDim2.fromScale(0, 0.51), UDim2.fromScale(0.49, 0.23), Color3.fromRGB(224, 70, 66))
	createThemeIcon(resetCard, "Warning", UDim2.fromOffset(12, 10), UDim2.fromOffset(44, 44), "ContractIcon")
	standaloneLabel(resetCard, "ContractTitle", "RESET", UDim2.fromOffset(64, 5), UDim2.new(1, -72, 0, 24), Color3.fromRGB(255, 117, 107), 12, Enum.Font.GothamBlack)
	standaloneLabel(resetCard, "ContractValue", "POWER 25 • COINS 0 • WALL LV 1\nSTARTER FIST • TRAINING STOPS", UDim2.fromOffset(64, 24), UDim2.new(1, -72, 0, 40), palette.Text, 10, Enum.Font.GothamBold)
	resetCard:SetAttribute("ResetContract", "PowerCoinsWallLevelWallXPEquippedFistTraining")

	local keepCard = standaloneCard(rebirthBody, "KeepContract", UDim2.fromScale(0.51, 0.51), UDim2.fromScale(0.49, 0.23), palette.Reward)
	createThemeIcon(keepCard, "Success", UDim2.fromOffset(12, 10), UDim2.fromOffset(44, 44), "ContractIcon")
	standaloneLabel(keepCard, "ContractTitle", "KEEP", UDim2.fromOffset(64, 5), UDim2.new(1, -72, 0, 24), palette.Reward, 12, Enum.Font.GothamBlack)
	standaloneLabel(keepCard, "ContractValue", "DEPTH • GEAR • PETS • HONOR • BOOSTS", UDim2.fromOffset(64, 26), UDim2.new(1, -72, 0, 34), palette.Text, 11, Enum.Font.GothamBold)
	keepCard:SetAttribute("RetainContract", "DepthScoreOwnedGearPetsHonorPremiumSettingsBoosts")

	local actionBand = Instance.new("Frame")
	actionBand.Name = "Actions"
	actionBand.Position = UDim2.fromScale(0, 0.77)
	actionBand.Size = UDim2.fromScale(1, 0.23)
	actionBand.BackgroundTransparency = 1
	actionBand.ZIndex = 73
	actionBand.Parent = rebirthBody
	local focusButton
	local function cancelReview()
		resetRebirthConfirmation("Canceled")
		renderStandaloneRebirth()
	end
	local function confirmRebirth()
		if shared.PunchWallRebirthRuntime.pending
			or not shared.PunchWallRebirthRuntime.armed
			or shared.PunchWallRebirthRuntime.signature ~= signature
			or shared.PunchWallRebirthRuntime.expiresAt <= os.clock() then return end
		shared.PunchWallRebirthRuntime.pending = true
		gui:SetAttribute("RebirthConfirmationState", "Pending")
		gui:SetAttribute("RebirthPending", true)
		gui:SetAttribute("RebirthRequestCount", (gui:GetAttribute("RebirthRequestCount") or 0) + 1)
		actionRemote:FireServer({
			action = "Rebirth",
			value = {
				confirmed = true,
				expectedRebirths = q.currentRebirths,
				policyVersion = q.policyVersion,
			},
		})
		renderStandaloneRebirth()
	end
	local function reviewRebirth()
		shared.PunchWallRebirthRuntime.armed = true
		shared.PunchWallRebirthRuntime.pending = false
		shared.PunchWallRebirthRuntime.signature = signature
		shared.PunchWallRebirthRuntime.expiresAt = os.clock() + GameConfig.Rebirth.ConfirmationSeconds
		shared.PunchWallRebirthRuntime.generation += 1
		local generation = shared.PunchWallRebirthRuntime.generation
		gui:SetAttribute("RebirthConfirmationState", "Armed")
		gui:SetAttribute("RebirthFirstActivationMutationGuard", true)
		task.delay(GameConfig.Rebirth.ConfirmationSeconds, function()
			if generation ~= shared.PunchWallRebirthRuntime.generation or shared.PunchWallRebirthRuntime.expiresAt > os.clock() then return end
			resetRebirthConfirmation("Expired")
			renderStandaloneRebirth()
		end)
		renderStandaloneRebirth()
	end
	shared.PunchWallRebirthActionCallbacks = { Cancel = cancelReview, Confirm = confirmRebirth, Review = reviewRebirth }
	if q.maxed or not q.ready then
		focusButton = makeMenuCommand(actionBand, "RebirthLocked", q.maxed and "MAX REBIRTH" or "NOT READY", palette.PanelSoft, function() end)
		focusButton.Active = false
		focusButton.Selectable = false
		focusButton.AutoButtonColor = false
	elseif shared.PunchWallRebirthRuntime.pending then
		focusButton = makeMenuCommand(actionBand, "RebirthPending", "REBIRTHING…", palette.PanelSoft, function() end)
		focusButton.Active = false
		focusButton.Selectable = false
		focusButton.AutoButtonColor = false
	elseif shared.PunchWallRebirthRuntime.armed then
		standaloneLabel(actionBand, "ConfirmQuestion", ("RESET NOW? • %ds"):format(math.max(0, math.ceil(shared.PunchWallRebirthRuntime.expiresAt - os.clock()))), UDim2.fromScale(0, 0), UDim2.fromScale(0.48, 1), Color3.fromRGB(255, 222, 89), 15, Enum.Font.GothamBlack)
		local cancel = makeMenuCommand(actionBand, "CancelRebirth", "CANCEL", palette.PanelSoft, cancelReview)
		cancel.AnchorPoint = Vector2.new(1, 0.5)
		cancel.Position = UDim2.fromScale(0.75, 0.5)
		cancel.Size = UDim2.fromOffset(112, 48)
		focusButton = makeMenuCommand(actionBand, "ConfirmRebirth", "REBIRTH NOW", Color3.fromRGB(142, 88, 203), confirmRebirth)
		focusButton.AnchorPoint = Vector2.new(1, 0.5)
		focusButton.Position = UDim2.fromScale(1, 0.5)
		focusButton.Size = UDim2.fromOffset(140, 48)
		cancel.NextSelectionRight = focusButton
		focusButton.NextSelectionLeft = cancel
		-- Safe default: gamepad/keyboard lands on Cancel, never destructive Confirm.
		focusButton = cancel
	else
		standaloneLabel(actionBand, "ReadyHint", "READY • REVIEW BEFORE RESET", UDim2.fromScale(0, 0), UDim2.fromScale(0.63, 1), palette.Reward, 12, Enum.Font.GothamBold)
		focusButton = makeMenuCommand(actionBand, "ReviewRebirth", "REVIEW REBIRTH", Color3.fromRGB(142, 88, 203), reviewRebirth)
		focusButton.AnchorPoint = Vector2.new(1, 0.5)
		focusButton.Position = UDim2.fromScale(1, 0.5)
		focusButton.Size = UDim2.fromOffset(180, 48)
	end
	if focusButton then
		focusButton:SetAttribute("MinimumTouchTarget", 44)
		focusButton:SetAttribute("RebirthSemanticAction", stateName)
	end
	setDescendantZIndex(rebirthPanel, 72)
	task.defer(function()
		if not rebirthPanel.Visible then return end
		local lastInput = UserInputService:GetLastInputType()
		local selectionInput = lastInput == Enum.UserInputType.Keyboard or string.find(lastInput.Name, "Gamepad", 1, true) == 1
		GuiService.SelectedObject = selectionInput and (focusButton and focusButton.Selectable and focusButton or rebirthClose) or nil
	end)
	task.defer(applyResponsiveLayout)
end

renderStandaloneSettings = function()
	if not settingsPanel.Visible then return end
	clearStandaloneBody(settingsBody)
	settingsSubtitle.Text = "SOUND • MOTION • UI SIZE"
	settingsPanel:SetAttribute("SoundEnabled", clientSettings.sound == true)
	settingsPanel:SetAttribute("MotionEnabled", clientSettings.motion == true)
	settingsPanel:SetAttribute("UiScale", tonumber(clientSettings.uiScale) or 1)
	settingsPanel:SetAttribute("LegacyCombinedTabsVisible", false)
	local firstControl
	local function makeSettingRow(rowIndex, iconName, titleText, helperText, options, selectedValue, onSelect)
		local row = standaloneCard(settingsBody, titleText .. "Setting", UDim2.new(0, 0, 0, (rowIndex - 1) * 82), UDim2.new(1, 0, 0, 72), Color3.fromRGB(46, 205, 255))
		createThemeIcon(row, iconName, UDim2.fromOffset(12, 12), UDim2.fromOffset(48, 48), "SettingIcon")
		standaloneLabel(row, "SettingTitle", titleText, UDim2.fromOffset(70, 7), UDim2.fromOffset(130, 25), palette.Text, 14, Enum.Font.GothamBlack)
		standaloneLabel(row, "SettingHelper", helperText, UDim2.fromOffset(70, 31), UDim2.fromOffset(170, 28), palette.MutedText, 10, Enum.Font.GothamBold)
		local optionArea = Instance.new("Frame")
		optionArea.Name = "Options"
		optionArea.AnchorPoint = Vector2.new(1, 0.5)
		optionArea.Position = UDim2.new(1, -10, 0.5, 0)
		optionArea.Size = UDim2.fromOffset(math.min(318, 86 * #options), 48)
		optionArea.BackgroundTransparency = 1
		optionArea.ZIndex = 74
		optionArea.Parent = row
		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.Padding = UDim.new(0, 6)
		layout.Parent = optionArea
		local previous
		for _, option in ipairs(options) do
			local selected = option.value == selectedValue
			local button = makeMenuCommand(optionArea, option.name, option.label, selected and palette.Reward or palette.PanelSoft, function()
				onSelect(option.value)
				renderStandaloneSettings()
			end)
			button.Size = UDim2.fromOffset(option.width or 78, 44)
			button:SetAttribute("MinimumTouchTarget", 44)
			button:SetAttribute("SettingValue", tostring(option.value))
			if not firstControl then firstControl = button end
			if previous then previous.NextSelectionRight = button button.NextSelectionLeft = previous end
			previous = button
		end
	end
	makeSettingRow(1, "SoundTool", "SOUND", "MUSIC + SFX", {
		{ name = "SoundOn", label = "ON", value = true },
		{ name = "SoundOff", label = "OFF", value = false },
	}, clientSettings.sound == true, function(value)
		shared.PunchWallApplySoundSetting(value, true)
	end)
	makeSettingRow(2, "Punch", "MOTION", "CAMERA + PUNCH FX", {
		{ name = "MotionOn", label = "ON", value = true },
		{ name = "MotionCalm", label = "CALM", value = false },
	}, clientSettings.motion == true, function(value)
		clientSettings.motion = value
		if shared.PunchWallApplyFistAuraMotion then shared.PunchWallApplyFistAuraMotion() end
		if shared.PunchWallRefreshHonorMotion then shared.PunchWallRefreshHonorMotion() end
		actionRemote:FireServer({ action = "UpdateSettings", value = clientSettings })
	end)
	makeSettingRow(3, "Menu", "UI SIZE", "TEXT + BUTTONS", {
		{ name = "Scale80", label = "80%", value = 0.8, width = 72 },
		{ name = "Scale100", label = "100%", value = 1, width = 72 },
		{ name = "Scale120", label = "120%", value = 1.2, width = 72 },
	}, tonumber(clientSettings.uiScale) or 1, function(value)
		clientSettings.uiScale = value
		actionRemote:FireServer({ action = "UpdateSettings", value = clientSettings })
		task.defer(applyResponsiveLayout)
	end)
	local footer = Instance.new("Frame")
	footer.Name = "Footer"
	footer.Position = UDim2.new(0, 0, 1, -56)
	footer.Size = UDim2.new(1, 0, 0, 56)
	footer.BackgroundTransparency = 1
	footer.ZIndex = 73
	footer.Parent = settingsBody
	standaloneLabel(footer, "ApplyHint", "CHANGES APPLY NOW", UDim2.fromScale(0, 0), UDim2.fromScale(0.62, 1), palette.MutedText, 11, Enum.Font.GothamBold)
	local done = makeMenuCommand(footer, "Done", "DONE", Color3.fromRGB(31, 148, 206), function() closeStandaloneWindows("SettingsDone") end)
	done.AnchorPoint = Vector2.new(1, 0.5)
	done.Position = UDim2.fromScale(1, 0.5)
	done.Size = UDim2.fromOffset(130, 48)
	done:SetAttribute("MinimumTouchTarget", 44)
	setDescendantZIndex(settingsPanel, 72)
	task.defer(function()
		if not settingsPanel.Visible then return end
		local lastInput = UserInputService:GetLastInputType()
		local selectionInput = lastInput == Enum.UserInputType.Keyboard or string.find(lastInput.Name, "Gamepad", 1, true) == 1
		GuiService.SelectedObject = selectionInput and firstControl or nil
	end)
	task.defer(applyResponsiveLayout)
end

closeStandaloneWindows = function(reason)
	if shared.PunchWallRebirthRuntime.armed or shared.PunchWallRebirthRuntime.pending then
		resetRebirthConfirmation(reason == "Escape" and "Canceled" or "Closed")
	end
	rebirthPanel.Visible = false
	settingsPanel.Visible = false
	standaloneDimmer.Visible = false
	gui:SetAttribute("ActiveStandaloneWindow", "")
	gui:SetAttribute("StandaloneModalVisible", false)
	if GuiService.SelectedObject and (GuiService.SelectedObject:IsDescendantOf(rebirthPanel) or GuiService.SelectedObject:IsDescendantOf(settingsPanel)) then
		GuiService.SelectedObject = nil
	end
	shared.PunchWallSetModalCoreGuiHidden(false, "StandaloneWindow")
	applyReferenceHUDState(true)
end
shared.PunchWallCloseStandaloneWindows = closeStandaloneWindows

local function openStandaloneWindow(windowName, origin)
	mainPanel.Visible = false
	rebirthPanel.Visible = windowName == "Rebirth"
	settingsPanel.Visible = windowName == "Settings"
	standaloneDimmer.Visible = true
	gui:SetAttribute("ActiveStandaloneWindow", windowName)
	gui:SetAttribute("StandaloneModalVisible", true)
	gui:SetAttribute(windowName .. "OpenOrigin", tostring(origin or "hud"))
	shared.PunchWallSetModalCoreGuiHidden(true, "StandaloneWindow")
	applyReferenceHUDState(true)
	task.defer(applyResponsiveLayout)
	if windowName == "Rebirth" then renderStandaloneRebirth() else renderStandaloneSettings() end
end

shared.PunchWallOpenSettingsPanel = function(origin)
	openStandaloneWindow("Settings", origin or "settings_tool")
end
shared.PunchWallRefreshStandaloneWindows = function()
	if rebirthPanel.Visible then renderStandaloneRebirth() end
	if settingsPanel.Visible then renderStandaloneSettings() end
end
standaloneWindows.RebirthPanel = rebirthPanel
standaloneWindows.RebirthBody = rebirthBody
standaloneWindows.SettingsPanel = settingsPanel
standaloneWindows.SettingsBody = settingsBody
standaloneWindows.Open = openStandaloneWindow
standaloneWindows.Close = closeStandaloneWindows
standaloneWindows.Refresh = shared.PunchWallRefreshStandaloneWindows

rebirthClose.Activated:Connect(function() closeStandaloneWindows("RebirthClose") end)
settingsClose.Activated:Connect(function() closeStandaloneWindows("SettingsClose") end)
standaloneDimmer.Activated:Connect(function()
	if shared.PunchWallRebirthRuntime.armed then
		resetRebirthConfirmation("Canceled")
		renderStandaloneRebirth()
	else
		closeStandaloneWindows("Dimmer")
	end
end)
end)()

renderOpenPanel = function()
	applyReferenceHUDState()
	if not mainPanel.Visible then
		return
	end
	tabBar.Visible = false
	local standaloneHostPage = activeTab == "Tasks" or activeTab == "Honor"
	shared.PunchWallStandaloneHostTitle.Visible = standaloneHostPage
	shared.PunchWallStandaloneHostTitle.Text = activeTab == "Tasks" and "MISSIONS" or activeTab == "Honor" and "HALL OF HONOR" or ""
	content.Position = UDim2.fromOffset(12, standaloneHostPage and 62 or 12)
	content.Size = UDim2.new(1, -24, 1, standaloneHostPage and -74 or -24)
	local previouslyRenderedTab = tostring(gui:GetAttribute("RenderedGenericTab") or "")
	local preserveCanvasY = previouslyRenderedTab == activeTab and content.CanvasPosition.Y or 0
	local selectedObject = GuiService.SelectedObject
	local preserveHonorFocusId = activeTab == "Honor" and selectedObject
		and tostring(selectedObject:GetAttribute("HonorItemId") or "") or ""
	if activeTab == "Inventory" then
		clearContent()
		for _, button in pairs(tabButtons) do button.BackgroundColor3 = palette.PanelSoft end
		return
	end
	if activeTab == "Fists" and shared.PunchWallShopReference then
		clearContent()
		gui:SetAttribute("ReferenceShopLegacyRenderSuppressed", true)
		return
	end
	clearContent()
	addGeneratedBanner()
	for name, button in pairs(tabButtons) do
		button.BackgroundColor3 = name == activeTab and palette.RoadLine or palette.PanelSoft
	end
	if activeTab == "Fists" then renderFists()
	elseif activeTab == "Pets" then renderPets()
	elseif activeTab == "Honor" then renderHonor()
	elseif activeTab == "Tasks" then renderTasks()
	else renderSettings() end
	gui:SetAttribute("RenderedGenericTab", activeTab)
	if preserveCanvasY > 0 then
		task.defer(function()
			local deadline = os.clock() + 1.25
			repeat RunService.Heartbeat:Wait()
			until content.AbsoluteCanvasSize.Y > content.AbsoluteSize.Y or os.clock() >= deadline
			if not mainPanel.Visible or activeTab ~= previouslyRenderedTab then return end
			local maxY = math.max(0, content.AbsoluteCanvasSize.Y - content.AbsoluteSize.Y)
			content.CanvasPosition = Vector2.new(0, math.clamp(preserveCanvasY, 0, maxY))
			if preserveHonorFocusId ~= "" then
				for _, descendant in ipairs(content:GetDescendants()) do
					if descendant:IsA("GuiButton") and tostring(descendant:GetAttribute("HonorItemId") or "") == preserveHonorFocusId then
						GuiService.SelectedObject = descendant
						break
					end
				end
			end
		end)
	end
end

if RunService:IsStudio() then
	gui:GetAttributeChangedSignal("AutomationTab"):Connect(function()
		local requestedTab = gui:GetAttribute("AutomationTab")
		if tabButtons[requestedTab] then
			activeTab = requestedTab
			mainPanel.Visible = true
			renderOpenPanel()
		end
	end)
end

local function createSideDock(name, anchorPoint, position)
	local dock = Instance.new("Frame")
	dock.Name = name
	dock.AnchorPoint = anchorPoint
	dock.Position = position
	dock.Size = UDim2.fromOffset(76, 240)
	dock.BackgroundTransparency = 1
	dock.Parent = gui
	local dockLayout = Instance.new("UIListLayout")
	dockLayout.Padding = UDim.new(0, 8)
	dockLayout.SortOrder = Enum.SortOrder.LayoutOrder
	dockLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	dockLayout.Parent = dock
	return dock
end

local leftDock = createSideDock("LeftHeroNavigation", Vector2.new(0, 0.5), UDim2.new(0, 18, 0.5, 10))
local rightDock = createSideDock("RightHeroNavigation", Vector2.new(1, 0.5), UDim2.new(1, -18, 0.5, 74))

local function createDockButton(parent, name, caption, iconName, accent, callback)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UDim2.fromOffset(70, 70)
	button.BackgroundColor3 = palette.Ink
	button.BackgroundTransparency = 0.04
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBlack
	button.Text = caption
	button.TextColor3 = palette.Text
	button.TextSize = 10
	button.TextYAlignment = Enum.TextYAlignment.Bottom
	button.Parent = parent
	local padding = Instance.new("UIPadding")
	padding.PaddingBottom = UDim.new(0, 6)
	padding.Parent = button
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 7)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Color = accent
	stroke.Thickness = 2
	stroke.Parent = button
	createThemeIcon(button, iconName, UDim2.new(0.5, -22, 0, 6), UDim2.fromOffset(44, 44), "DockIcon")
	button.Activated:Connect(callback)
	return button
end

createDockButton(leftDock, "DailyButton", "DAILY", "Coin", palette.Reward, function() openGameTab("Tasks") end)
createDockButton(leftDock, "SpinButton", "SPIN", "Success", palette.Use, function()
	if shared.PunchWallOpenSpin then shared.PunchWallOpenSpin() else requestAction("Spin") end
end)
createDockButton(leftDock, "RebirthButton", "REBIRTH", "Rebirth", palette.Train, function() shared.PunchWallOpenRebirthPanel("legacy_dock") end)
createDockButton(rightDock, "ShopButton", "SHOP", "Shop", palette.Reward, function() openGameTab("Fists") end)
createDockButton(rightDock, "PetsButton", "PETS", "Pet", palette.Use, function() openGameTab("Pets") end)
createDockButton(rightDock, "QuestsButton", "QUESTS", "Quest", palette.Reward, function() openGameTab("Tasks") end)

local function setMenuVisible(visible)
	if visible and shared.PunchWallCloseStandaloneWindows then shared.PunchWallCloseStandaloneWindows("OpenHost") end
	mainPanel.Visible = visible
	panel.Visible = false
	menuButton.Visible = false
	applyReferenceHUDState()
	if visible then
		renderOpenPanel()
		if string.find(UserInputService:GetLastInputType().Name, "Gamepad", 1, true) then
			task.defer(function()
				if mainPanel.Visible then
					GuiService.SelectedObject = tabButtons[activeTab] or orderedTabButtons[1]
				end
			end)
		end
	elseif GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(mainPanel) then
		GuiService.SelectedObject = nil
	end
end

openGameTab = function(tabName)
	if tabName == "Settings" then
		shared.PunchWallOpenSettingsPanel("legacy_route")
		return
	elseif tabName == "Rebirth" then
		shared.PunchWallOpenRebirthPanel("legacy_route")
		return
	elseif tabName == "Pets" then
		activeTab = "Inventory"
	elseif tabName == "Honor" then
		activeTab = "Inventory"
	elseif tabButtons[tabName] or tabName == "Inventory" then
		activeTab = tabName
	end
	setMenuVisible(true)
	if tabName == "Pets" and shared.PunchWallInventoryController then
		shared.PunchWallInventoryController:SetCategory("Pets")
	elseif tabName == "Honor" and shared.PunchWallInventoryController then
		shared.PunchWallInventoryController:SetSearch("", false)
		shared.PunchWallInventoryController:SetRarity("All", false)
		shared.PunchWallInventoryController:SetCategory("Honor", false)
	end
	task.defer(applyResponsiveLayout)
end

shared.PunchWallOpenRebirthPanel = function(origin)
	shared.PunchWallRebirthRuntime.origin = tostring(origin or "hud")
	gui:SetAttribute("RebirthOpenOrigin", shared.PunchWallRebirthRuntime.origin)
	shared.PunchWallStandaloneWindows.Open("Rebirth", shared.PunchWallRebirthRuntime.origin)
end

local function toggleMenu()
	setMenuVisible(not mainPanel.Visible)
end

menuButton.Activated:Connect(toggleMenu)
closeButton.Activated:Connect(function() setMenuVisible(false) end)
mainPanel:GetPropertyChangedSignal("Visible"):Connect(function()
	local visible = mainPanel.Visible
	shared.PunchWallSetModalCoreGuiHidden(visible, "GameMenu")
	panel.Visible = false
	menuButton.Visible = false
	applyReferenceHUDState()
	task.defer(applyResponsiveLayout)
end)

local companionsFolder = Instance.new("Folder")
companionsFolder.Name = player.Name .. " Client Companions"
companionsFolder.Parent = workspace
local companionModels = {}
local companionMotionVersion = "DampedFollowV2"
local companionRuntime = {
	cameraPolicy = "CameraSafeThreePetLOD1",
	formationPolicy = "BoundsAwarePremiumFormationV2",
	perPetScreenAreaBudget = 0.18,
	combinedScreenAreaBudget = 0.35,
	visualAttestationCache = setmetatable({}, { __mode = "k" }),
	visualAttestationWatch = setmetatable({}, { __mode = "k" }),
	visualRetryGeneration = 0,
	visualRetryScheduled = false,
	visualRetryAttempt = 0,
	visualRetryMaxAttempts = 3,
	visualRetryDeadlineSeconds = 0.8,
	visualRetryCoalescedCount = 0,
	visualRetryConnection = nil,
}

function companionRuntime.UpdateVisualRetryAttributes(state)
	gui:SetAttribute("HeroGauntletRetryState", state)
	gui:SetAttribute("HeroGauntletRetryGeneration", companionRuntime.visualRetryGeneration)
	gui:SetAttribute("HeroGauntletRetryScheduled", companionRuntime.visualRetryScheduled)
	gui:SetAttribute("HeroGauntletRetryAttempt", companionRuntime.visualRetryAttempt)
	gui:SetAttribute("HeroGauntletRetryMaxAttempts", companionRuntime.visualRetryMaxAttempts)
	gui:SetAttribute("HeroGauntletRetryCoalescedCount", companionRuntime.visualRetryCoalescedCount)
	gui:SetAttribute("HeroGauntletRetryDeadlineSeconds", companionRuntime.visualRetryDeadlineSeconds)
	gui:SetAttribute("HeroGauntletRetrySingleFlight", true)
	gui:SetAttribute("HeroGauntletRetryEventDriven", true)
end

function companionRuntime.CancelVisualRetry(reason)
	companionRuntime.visualRetryGeneration += 1
	companionRuntime.visualRetryScheduled = false
	companionRuntime.visualRetryAttempt = 0
	if companionRuntime.visualRetryConnection then
		companionRuntime.visualRetryConnection:Disconnect()
		companionRuntime.visualRetryConnection = nil
	end
	companionRuntime.UpdateVisualRetryAttributes(reason or "Cancelled")
end

function companionRuntime.ScheduleVisualRetry()
	if companionRuntime.visualRetryScheduled then
		companionRuntime.visualRetryCoalescedCount += 1
		companionRuntime.UpdateVisualRetryAttributes("Coalesced")
		return false
	end
	if companionRuntime.visualRetryAttempt >= companionRuntime.visualRetryMaxAttempts then
		companionRuntime.UpdateVisualRetryAttributes("Exhausted")
		return false
	end
	local character = player.Character
	if not character then
		companionRuntime.UpdateVisualRetryAttributes("WaitingForCharacter")
		return false
	end

	companionRuntime.visualRetryScheduled = true
	companionRuntime.visualRetryAttempt += 1
	local generation = companionRuntime.visualRetryGeneration
	local finished = false
	local function finish(state)
		if finished or generation ~= companionRuntime.visualRetryGeneration then return end
		finished = true
		companionRuntime.visualRetryScheduled = false
		if companionRuntime.visualRetryConnection then
			companionRuntime.visualRetryConnection:Disconnect()
			companionRuntime.visualRetryConnection = nil
		end
		companionRuntime.UpdateVisualRetryAttributes(state)
		task.defer(function()
			if generation == companionRuntime.visualRetryGeneration then
				refreshCharacterVisuals()
			end
		end)
	end

	companionRuntime.visualRetryConnection = character.ChildAdded:Connect(function(child)
		if child.Name == "RightHand" or child.Name == "Right Arm" then
			finish("HandReady")
		end
	end)
	companionRuntime.UpdateVisualRetryAttributes("WaitingForHand")
	if character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm") then
		finish("HandAlreadyReady")
	else
		task.delay(companionRuntime.visualRetryDeadlineSeconds, function()
			finish("DeadlineRetry")
		end)
	end
	return true
end

local visualSignature = ""
local currentGauntlet
local currentTrail
local currentHonorCosmetic

local function visualPart(parent, name, size, color, material, shape)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.Metal
	part.Shape = shape or Enum.PartType.Block
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.CastShadow = true
	part.Parent = parent
	return part
end

function companionRuntime.VisualWedge(parent, name, size, color, material, targetCFrame)
	local part = Instance.new("WedgePart")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.Metal
	part.CFrame = targetCFrame
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.CastShadow = true
	part.Parent = parent
	return part
end

local function petDefinition(name)
	return GameConfig.PetDefinition(name) or GameConfig.Pets[1]
end

local function addCompanionAura(model, targetPart, definition, stars)
	if not targetPart or (stars <= 1 and definition.rarity ~= "Premium") then return end
	local accent = definition.accent or definition.color:Lerp(Color3.new(1, 1, 1), 0.35)
	local aura = Instance.new("ParticleEmitter")
	aura.Name = "Sidekick Star Aura"
	aura.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	aura.Color = ColorSequence.new(definition.color, accent)
	aura.LightEmission = definition.rarity == "Premium" and 1 or 0.72
	aura.Rate = math.min(22, 3 + stars * 2 + (definition.rarity == "Premium" and 8 or 0))
	aura.Lifetime = NumberRange.new(0.35, 0.75)
	aura.Speed = NumberRange.new(0.25, 1.2)
	aura.SpreadAngle = Vector2.new(180, 180)
	aura.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18 + stars * 0.035), NumberSequenceKeypoint.new(1, 0) })
	aura.Parent = targetPart
	local light = Instance.new("PointLight")
	light.Name = "Sidekick Aura Light"
	light.Color = accent
	light.Brightness = 0.35 + stars * 0.16 + (definition.rarity == "Premium" and 0.9 or 0)
	light.Range = 4 + stars + (definition.rarity == "Premium" and 4 or 0)
	light.Shadows = false
	light.Parent = targetPart
	model:SetAttribute("AuraTier", stars + (definition.rarity == "Premium" and 5 or 0))
end

function companionRuntime.PrepareVisualAsset(container, asset)
	if not container or not asset or not asset.Parent then return false end
	if asset ~= container and not asset:IsDescendantOf(container) then return false end
	if companionRuntime.visualAttestationCache[container] == true
		and companionRuntime.visualAttestationCache[asset] == true
		and container:GetAttribute("SanitizedVisualOnly") == true
		and container:GetAttribute("VisualSanitizerVerified") == true
		and asset:GetAttribute("SanitizedVisualOnly") == true
		and asset:GetAttribute("VisualSanitizerVerified") == true
		and FistVisualBuilder.IsSanitizedVisual(asset) then
		return true
	end
	local containerOk = pcall(FistVisualBuilder.SanitizeVisual, container)
	if not containerOk or not asset.Parent then return false end
	local assetOk = pcall(FistVisualBuilder.SanitizeVisual, asset)
	if not assetOk then return false end
	local verified = container:GetAttribute("SanitizedVisualOnly") == true
		and container:GetAttribute("VisualSanitizerVerified") == true
		and asset:GetAttribute("SanitizedVisualOnly") == true
		and asset:GetAttribute("VisualSanitizerVerified") == true
		and FistVisualBuilder.IsSanitizedVisual(container)
		and FistVisualBuilder.IsSanitizedVisual(asset)
	if verified then
		companionRuntime.visualAttestationCache[container] = true
		companionRuntime.visualAttestationCache[asset] = true
		if not companionRuntime.visualAttestationWatch[container] then
			local added = container.DescendantAdded:Connect(function()
				companionRuntime.visualAttestationCache[container] = nil
			end)
			local removing = container.DescendantRemoving:Connect(function()
				companionRuntime.visualAttestationCache[container] = nil
			end)
			companionRuntime.visualAttestationWatch[container] = { added, removing }
		end
	end
	return verified
end

function companionRuntime.CloneSanitizedVisual(source)
	if not source or not FistVisualBuilder.IsSanitizedVisual(source) then return nil end
	local clone = source:Clone()
	local ok = pcall(FistVisualBuilder.SanitizeVisual, clone)
	if not ok or not FistVisualBuilder.IsSanitizedVisual(clone) then
		clone:Destroy()
		return nil
	end
	return clone
end

function companionRuntime.CloneSanitizedCatalogVisual(visualAssetFolder, importedSource)
	if not visualAssetFolder
		or not importedSource
		or not importedSource.Parent
		or not companionRuntime.PrepareVisualAsset(visualAssetFolder, importedSource)
	then
		return nil
	end
	return companionRuntime.CloneSanitizedVisual(importedSource)
end

function companionRuntime.StyleNormalCatalogPet(model, definition)
	if not model or definition.rarity == "Premium" then return model end
	local primary = definition.color or Color3.fromRGB(120, 170, 210)
	local accent = primary:Lerp(Color3.new(1, 1, 1), 0.38)
	local shadow = primary:Lerp(Color3.fromRGB(20, 27, 34), 0.48)
	local boundsCFrame, boundsSize = model:GetBoundingBox()
	local tintStrength = definition.rarity == "Secret" and 0.5
		or definition.rarity == "Legendary" and 0.42
		or definition.rarity == "Epic" and 0.34
		or definition.rarity == "Rare" and 0.28
		or 0.2
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local brightness = (descendant.Color.R + descendant.Color.G + descendant.Color.B) / 3
			local target = brightness < 0.32 and shadow or brightness > 0.78 and accent or primary
			-- Preserve the authored pack texture and silhouette. A bounded tint is
			-- enough to match the inventory rarity palette without flattening the
			-- model into a single material-colored blob.
			descendant.Color = descendant.Color:Lerp(target, tintStrength)
			if definition.rarity == "Legendary" or definition.rarity == "Secret" then
				descendant.Material = descendant.Material == Enum.Material.Neon
					and Enum.Material.Neon
					or Enum.Material.Metal
			end
		end
	end

	local function styledPart(name, sizeScale, offsetScale, color, material, shape)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = Vector3.new(
			math.max(0.08, boundsSize.X * sizeScale.X),
			math.max(0.08, boundsSize.Y * sizeScale.Y),
			math.max(0.08, boundsSize.Z * sizeScale.Z)
		)
		part.CFrame = boundsCFrame * CFrame.new(
			boundsSize.X * offsetScale.X,
			boundsSize.Y * offsetScale.Y,
			boundsSize.Z * offsetScale.Z
		)
		part.Color = color
		part.Material = material
		part.Shape = shape or Enum.PartType.Block
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = material ~= Enum.Material.Neon
		part.Parent = model
		return part
	end

	if definition.name == "Miner Cat" then
		styledPart("Miner Helmet", Vector3.new(0.42, 0.2, 0.72), Vector3.new(-0.26, 0.46, 0), shadow, Enum.Material.Metal, Enum.PartType.Ball)
		local lamp = styledPart("Miner Lamp", Vector3.new(0.13, 0.24, 0.32), Vector3.new(-0.44, 0.5, -0.3), Color3.fromRGB(255, 214, 62), Enum.Material.Neon, Enum.PartType.Ball)
		local light = Instance.new("PointLight")
		light.Name = "Miner Lamp Glow"
		light.Color = lamp.Color
		light.Brightness = 0.45
		light.Range = 3
		light.Shadows = false
		light.Parent = lamp
	elseif definition.name == "Crystal Fox" then
		for side = -1, 1, 2 do
			local shard = styledPart(
				"Crystal Fox Shard " .. side,
				Vector3.new(0.18, 0.72, 0.18),
				Vector3.new(side * 0.34, 0.48, 0.12),
				accent,
				Enum.Material.Neon
			)
			shard.CFrame *= CFrame.Angles(0, 0, math.rad(side * 16))
		end
		styledPart("Crystal Tail Core", Vector3.new(0.34, 0.34, 0.28), Vector3.new(0, 0.05, 0.54), accent, Enum.Material.Neon, Enum.PartType.Ball)
	elseif definition.name == "Lava Dragon" then
		styledPart("Lava Dragon Ember Core", Vector3.new(0.24, 0.3, 0.18), Vector3.new(0, 0.04, -0.5), Color3.fromRGB(255, 218, 71), Enum.Material.Neon, Enum.PartType.Ball)
		for side = -1, 1, 2 do
			styledPart("Lava Wing Core " .. side, Vector3.new(0.12, 0.5, 0.12), Vector3.new(side * 0.48, 0.34, 0.08), accent, Enum.Material.Neon)
		end
	elseif definition.name == "Secret Titan Golem" then
		styledPart("Titan Golem Core", Vector3.new(0.38, 0.28, 0.16), Vector3.new(0, 0.02, -0.5), Color3.fromRGB(255, 82, 62), Enum.Material.Neon, Enum.PartType.Ball)
		for side = -1, 1, 2 do
			styledPart("Titan Shoulder " .. side, Vector3.new(0.42, 0.26, 0.46), Vector3.new(side * 0.46, 0.28, 0), shadow, Enum.Material.DiamondPlate, Enum.PartType.Ball)
		end
	end
	model:SetAttribute("CatalogPetStyleVersion", "CreatorStorePackMatchedV2")
	model:SetAttribute("CatalogPetThemeMatched", true)
	model:SetAttribute("CatalogPetColorMatched", true)
	return model
end

local function catalogCompanionTemplate(definition)
	if not definition.templateName then return nil, nil end
	local externalAssets = ReplicatedStorage:FindFirstChild("PunchWallExternalAssets")
	local externalTemplate = externalAssets and externalAssets:FindFirstChild(definition.templateName)
	if externalTemplate
		and externalTemplate:IsA("Model")
		and companionRuntime.PrepareVisualAsset(externalAssets, externalTemplate) then
		return externalTemplate, "ExternalTemplate"
	end
	local gameRoot = definition.rarity == "Premium" and workspace:FindFirstChild("PunchWallRPG") or nil
	if gameRoot then
		for _, candidate in ipairs(gameRoot:GetDescendants()) do
			if candidate:IsA("Model")
				and candidate:GetAttribute("VisualRole") == "PremiumPetShowcase"
				and candidate:GetAttribute("PetTemplate") == definition.templateName
				and companionRuntime.PrepareVisualAsset(candidate, candidate) then
				return candidate, "ShowcaseClone"
			end
		end
	end
	return nil, nil
end

function companionRuntime.CameraDistance(rootPart)
	local camera = workspace.CurrentCamera
	return camera and math.clamp((camera.CFrame.Position - rootPart.Position).Magnitude, 6, 18) or 12
end

function companionRuntime.BoundsCFrame(
	rootPart,
	index,
	followHeight,
	cameraDistance,
	distanceScale,
	boundsSize,
	isPremium
)
	local zoomAlpha = math.clamp(((cameraDistance or 12) - 6) / 12, 0, 1)
	local boundedDistanceScale = math.clamp(tonumber(distanceScale) or 1, 1, 1.65)
	local visualHalfWidth = boundsSize
		and math.max(boundsSize.X, boundsSize.Z * 0.55) * 0.5
		or 0
	local avatarClearance = isPremium and (1.55 + visualHalfWidth + 0.65) or 0
	local sideSpacing = (isPremium
		and avatarClearance
		or (2.65 + zoomAlpha * 0.55)) * boundedDistanceScale
	local rearSpacing = isPremium
		and 0.65
		or math.max(0.35, (0.45 + zoomAlpha * 1.1) / boundedDistanceScale)
	local resolvedHeight = tonumber(followHeight) or 1.05
	if isPremium then
		-- Premium models are wider and their authored follow heights can put their
		-- silhouette over the avatar's head. Preserve their hero scale while
		-- moving the formation outward and slightly below the face line.
		resolvedHeight = math.clamp(resolvedHeight, 1.15, 1.45)
	end
	local offset
	if index == 1 then
		offset = Vector3.new(-sideSpacing, resolvedHeight, rearSpacing)
	elseif index == 2 then
		offset = Vector3.new(sideSpacing, resolvedHeight, rearSpacing)
	elseif index == 3 then
		-- Slot three must clear slot one by at least one full premium-model width.
		-- Keep it in the rear row rather than stacking it above the avatar.
		-- Pull the wide premium rear slot slightly toward center at close zoom so
		-- even the broad Celestial wings remain inside the camera safe frame.
		-- Restore a little lateral spacing as the camera zooms out, where there is
		-- enough screen room and the extra separation improves silhouette clarity.
		-- Normal companions also need a distinct rear-left silhouette once the
		-- hero reaches maximum Power growth. The wider offset prevents slot three
		-- from merging with slot one without scaling either pet.
		local thirdSlotMultiplier = isPremium and (1.12 + zoomAlpha * 0.1) or 1.65
		local thirdSlotLift = isPremium and 2.1 or 0.55
		local thirdSlotRear = isPremium and 0.5 or 1.25
		offset = Vector3.new(
			-sideSpacing * thirdSlotMultiplier,
			resolvedHeight + thirdSlotLift,
			rearSpacing + thirdSlotRear / boundedDistanceScale
		)
	else
		local side = index % 2 == 0 and 1 or -1
		local row = math.floor((index - 1) / 2)
		offset = Vector3.new(side * (sideSpacing + row * 0.6), resolvedHeight, rearSpacing + row * 0.8)
	end
	return rootPart.CFrame * CFrame.new(offset) * CFrame.Angles(0, math.pi, 0)
end

function companionRuntime.ScreenArea(boundsSize, worldPosition)
	local camera = workspace.CurrentCamera
	if not camera then return 0 end
	local viewport = camera.ViewportSize
	local aspect = math.max(viewport.X / math.max(viewport.Y, 1), 0.5)
	local distance = math.max((camera.CFrame.Position - worldPosition).Magnitude, 1)
	local halfFrustum = math.tan(math.rad(math.clamp(camera.FieldOfView, 35, 100) * 0.5))
	local largest = math.max(boundsSize.X, boundsSize.Y, boundsSize.Z)
	local heightFraction = largest / math.max(2 * distance * halfFrustum, 0.01)
	local widthFraction = heightFraction / aspect
	return math.clamp(widthFraction * heightFraction, 0, 1)
end

function companionRuntime.ResolveVisualPolicy(state, rootPart, cameraDistance, availableBudget)
	local budget = math.min(
		companionRuntime.perPetScreenAreaBudget,
		math.max(tonumber(availableBudget) or 0, 0)
	)
	local normalTarget = companionRuntime.BoundsCFrame(
		rootPart,
		state.index,
		state.followHeight,
		cameraDistance,
		1,
		state.normalizedBoundsSize,
		state.premium
	)
	local normalArea = companionRuntime.ScreenArea(state.normalizedBoundsSize, normalTarget.Position)
	if normalArea <= budget then
		return normalTarget, 1, "Normal", normalArea
	end

	local repositionedTarget = companionRuntime.BoundsCFrame(
		rootPart,
		state.index,
		state.followHeight,
		cameraDistance,
		1.55,
		state.normalizedBoundsSize,
		state.premium
	)
	local repositionedArea = companionRuntime.ScreenArea(state.normalizedBoundsSize, repositionedTarget.Position)
	if repositionedArea <= budget then
		return repositionedTarget, 1, "Repositioned", repositionedArea
	end

	local scale = math.clamp(
		math.sqrt(budget / math.max(repositionedArea, 0.000001)) * 0.96,
		0.58,
		0.92
	)
	local scaledArea = repositionedArea * scale * scale
	if scaledArea <= budget then
		local policy = scale <= 0.72 and "BudgetLOD" or "Scaled"
		return repositionedTarget, scale, policy, scaledArea
	end

	-- Secondary effects enter the budget LOD before the lowest-priority visual
	-- is culled. Geometry still exceeds the hard bound at minimum scale, so
	-- keeping it visible would only report the budget rather than enforce it.
	return repositionedTarget, 0.58, "CulledAfterBudgetLOD", 0
end

function companionRuntime.ApplyVisualScale(state, visualScale)
	visualScale = math.clamp(tonumber(visualScale) or 1, 0.58, 1)
	if math.abs((state.currentVisualScale or 1) - visualScale) <= 0.005 then return true end
	local ok = pcall(function()
		state.model:ScaleTo(state.baseModelScale * visualScale)
	end)
	if not ok then return false end
	local boundsCFrame, boundsSize = state.model:GetBoundingBox()
	state.currentVisualScale = visualScale
	state.pivotToBounds = state.model:GetPivot():ToObjectSpace(boundsCFrame)
	state.boundsSize = boundsSize
	return true
end

function companionRuntime.ApplyRenderPolicy(state, policy, lod, motionEnabled)
	local renderKey = table.concat({ tostring(policy), tostring(lod), tostring(motionEnabled) }, ":")
	if state.renderPolicyKey == renderKey then return end
	state.renderPolicyKey = renderKey
	state.budgetPolicy = policy
	local culled = policy == "CulledAfterBudgetLOD"
	local budgetLOD = policy == "BudgetLOD" or culled
	local rateScale = not motionEnabled and 0.25
		or lod == "Near60" and 1
		or lod == "Mid30" and 0.72
		or 0.45
	if budgetLOD then rateScale = 0 end
	for _, partState in ipairs(state.renderParts) do
		if partState.part.Parent then
			partState.part.LocalTransparencyModifier = culled and 1 or partState.baseLocalTransparency
		end
	end
	for _, emitterState in ipairs(state.renderEmitters) do
		if emitterState.emitter.Parent then
			emitterState.emitter.Enabled = not budgetLOD and emitterState.baseEnabled
			emitterState.emitter.Rate = emitterState.baseRate * rateScale
		end
	end
	for _, effectState in ipairs(state.renderEffects) do
		if effectState.effect.Parent then
			effectState.effect.Enabled = not budgetLOD and effectState.baseEnabled
		end
	end
	state.model:SetAttribute("CompanionLOD", lod)
	state.model:SetAttribute("CompanionBudgetPolicy", policy)
	state.model:SetAttribute("CompanionBudgetCulled", culled)
	state.model:SetAttribute("CompanionVisualScale", state.currentVisualScale or 1)
end

local function registerCompanion(model, token, index, definition, stars, visualSource)
	local sanitized = pcall(FistVisualBuilder.SanitizeVisual, model)
	if not sanitized or not FistVisualBuilder.IsSanitizedVisual(model) then
		model:Destroy()
		return nil
	end
	model.Name = token .. " Companion " .. index
	model:SetAttribute("PetStars", stars)
	model:SetAttribute("PetDefinitionName", definition.name)
	model:SetAttribute("PetTemplate", definition.templateName or "")
	model:SetAttribute("PetVisualIdentity", definition.templateName or ("Procedural:" .. definition.name))
	model:SetAttribute("VisualRole", "EquippedPetCompanion")
	model:SetAttribute("VisualSource", visualSource)
	model:SetAttribute("MotionSystem", companionMotionVersion)
	model:SetAttribute("MotionClock", "Heartbeat")
	model.Parent = companionsFolder

	local primaryPart = model.PrimaryPart
	local partCount = 0
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			partCount += 1
			primaryPart = primaryPart or descendant
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
			descendant.AssemblyLinearVelocity = Vector3.zero
			descendant.AssemblyAngularVelocity = Vector3.zero
		elseif descendant:IsA("ParticleEmitter") then
			descendant.Enabled = definition.rarity == "Premium" or descendant.Enabled
			descendant.Rate = math.min(descendant.Rate, 14)
		elseif descendant:IsA("Trail") or descendant:IsA("Beam") then
			descendant.Enabled = definition.rarity == "Premium" or descendant.Enabled
		end
	end
	if not primaryPart or not primaryPart.Parent then
		model:Destroy()
		return nil
	end
	model.PrimaryPart = primaryPart

	local _, initialSize = model:GetBoundingBox()
	local targetHeight = tonumber(definition.companionHeight)
		or (definition.rarity == "Premium" and 2.8)
		or (definition.rarity == "Secret" and 2.55)
		or (definition.rarity == "Legendary" and 2.35)
		or 2.1
	local targetMaxDimension = definition.rarity == "Premium" and 1.8
		or definition.rarity == "Secret" and 1.75
		or definition.rarity == "Legendary" and 1.72
		or 1.65
	local initialLargest = math.max(initialSize.X, initialSize.Y, initialSize.Z)
	if initialSize.Y > 0.01 and initialLargest > 0.01 then
		local normalizedScale = math.min(targetHeight / initialSize.Y, targetMaxDimension / initialLargest)
		pcall(function()
			model:ScaleTo(model:GetScale() * normalizedScale)
		end)
	end
	local boundsCFrame, boundsSize = model:GetBoundingBox()
	local pivotToBounds = model:GetPivot():ToObjectSpace(boundsCFrame)
	local assetId = tonumber(model:GetAttribute("AssetId")) or 0
	local premiumParity = definition.rarity == "Premium"
		and definition.templateName ~= nil
		and string.find(visualSource, "ProceduralFallback", 1, true) == nil
	model:SetAttribute("PremiumVisualParity", premiumParity)
	model:SetAttribute("SourceAssetId", assetId)
	model:SetAttribute("VisualPartCount", partCount)
	model:SetAttribute("CompanionTargetHeight", targetHeight)
	model:SetAttribute("CompanionTargetMaxDimension", targetMaxDimension)
	model:SetAttribute("FollowResponsiveness", tonumber(definition.followResponsiveness) or 8)
	model:SetAttribute("FollowSmoothing", "ExponentialCFrame")
	model:SetAttribute("ModelBoundsHeight", boundsSize.Y)
	model:SetAttribute("ModelBoundsWidth", boundsSize.X)
	model:SetAttribute("ModelBoundsDepth", boundsSize.Z)
	model:SetAttribute("NormalizedMaxDimension", math.max(boundsSize.X, boundsSize.Y, boundsSize.Z))
	model:SetAttribute("BoundsCacheMode", "NormalizedOnceV1")
	model:SetAttribute("CameraPolicy", companionRuntime.cameraPolicy)
	model:SetAttribute("FormationPolicy", companionRuntime.formationPolicy)
	model:SetAttribute("PerPetScreenAreaBudget", companionRuntime.perPetScreenAreaBudget)
	model:SetAttribute("BudgetEnforcementOrder", "Reposition>Scale>LOD>Cull")
	addCompanionAura(model, primaryPart, definition, stars)
	FistVisualBuilder.SanitizeVisual(model)
	FistVisualBuilder.AssertSanitizedVisual(model)

	local renderEmitters = {}
	local renderParts = {}
	local renderEffects = {}
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			table.insert(renderEmitters, {
				emitter = descendant,
				baseEnabled = descendant.Enabled,
				baseRate = descendant.Rate,
			})
		elseif descendant:IsA("BasePart") then
			table.insert(renderParts, {
				part = descendant,
				baseLocalTransparency = descendant.LocalTransparencyModifier,
			})
		elseif descendant:IsA("Trail")
			or descendant:IsA("Beam")
			or descendant:IsA("PointLight")
			or descendant:IsA("SpotLight")
			or descendant:IsA("SurfaceLight")
			or descendant:IsA("Highlight") then
			table.insert(renderEffects, {
				effect = descendant,
				baseEnabled = descendant.Enabled,
			})
		end
	end

	local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local initialBounds = rootPart
		and companionRuntime.BoundsCFrame(
			rootPart,
			index,
			definition.followHeight,
			companionRuntime.CameraDistance(rootPart),
			1,
			boundsSize,
			definition.rarity == "Premium"
		)
		or boundsCFrame
	model:PivotTo(initialBounds * pivotToBounds:Inverse())
	table.insert(companionModels, {
		index = index,
		model = model,
		pivotToBounds = pivotToBounds,
		boundsSize = boundsSize,
		normalizedBoundsSize = boundsSize,
		baseModelScale = model:GetScale(),
		currentVisualScale = 1,
		currentBoundsCFrame = initialBounds,
		followHeight = tonumber(definition.followHeight) or 1.05,
		followResponsiveness = tonumber(definition.followResponsiveness) or 8,
		hoverAmplitude = tonumber(definition.hoverAmplitude) or 0.22,
		phase = index * 1.73,
		premium = definition.rarity == "Premium",
		motionFrames = 0,
		updateAccumulator = 0,
		lod = "",
		budgetPolicy = "Normal",
		renderParts = renderParts,
		renderEmitters = renderEmitters,
		renderEffects = renderEffects,
		lastScreenArea = companionRuntime.ScreenArea(boundsSize, initialBounds.Position),
	})
	return model
end

function companionRuntime.BuildProceduralPet(definition)
	local model = Instance.new("Model")
	local species = tostring(definition.visual or definition.name or "Hero Sidekick")
	local primary = definition.color or Color3.fromRGB(112, 178, 92)
	local accent = definition.accent or primary:Lerp(Color3.new(1, 1, 1), 0.34)
	local shadow = primary:Lerp(Color3.new(0, 0, 0), 0.28)
	local featureCount = 0
	local body
	local function part(name, size, color, material, shape, targetCFrame)
		local created = visualPart(model, name, size, color, material, shape)
		created.CFrame = targetCFrame or CFrame.new()
		featureCount += 1
		return created
	end
	local function wedge(name, size, color, material, targetCFrame)
		featureCount += 1
		return companionRuntime.VisualWedge(model, name, size, color, material, targetCFrame)
	end
	local function eyes(headCFrame, spacing, y, z)
		for side = -1, 1, 2 do
			part(
				"Readable Eye " .. side,
				Vector3.new(0.18, 0.22, 0.14),
				Color3.fromRGB(10, 20, 27),
				Enum.Material.Neon,
				Enum.PartType.Ball,
				headCFrame * CFrame.new(side * spacing, y, z)
			)
		end
	end

	local isGuardian = string.find(species, "Golem", 1, true)
		or string.find(species, "Celestial", 1, true)
	local isDragon = string.find(species, "Dragon", 1, true)
		or string.find(species, "Wyvern", 1, true)
	local isPhoenix = string.find(species, "Phoenix", 1, true)
	local isFox = string.find(species, "Fox", 1, true)
	local isCat = string.find(species, "Cat", 1, true)

	if isGuardian then
		body = part("Guardian Armored Torso", Vector3.new(1.65, 1.55, 1.35), shadow, Enum.Material.Metal, Enum.PartType.Block, CFrame.new())
		local head = part("Guardian Helmet", Vector3.new(1.05, 0.88, 1.02), primary, Enum.Material.Metal, Enum.PartType.Block, CFrame.new(0, 1.15, -0.08))
		eyes(head.CFrame, 0.25, 0.04, -0.52)
		part("Guardian Visor", Vector3.new(0.72, 0.2, 0.12), accent, Enum.Material.Neon, Enum.PartType.Block, head.CFrame * CFrame.new(0, 0.03, -0.55))
		for side = -1, 1, 2 do
			part("Guardian Shoulder " .. side, Vector3.new(0.72, 0.72, 0.72), primary, Enum.Material.Metal, Enum.PartType.Ball, CFrame.new(side * 1.08, 0.42, 0))
			part("Guardian Fist " .. side, Vector3.new(0.62, 0.66, 0.62), shadow, Enum.Material.DiamondPlate, Enum.PartType.Ball, CFrame.new(side * 1.12, -0.44, -0.12))
			part("Guardian Foot " .. side, Vector3.new(0.62, 0.48, 0.8), shadow, Enum.Material.Metal, Enum.PartType.Block, CFrame.new(side * 0.48, -1.02, 0.12))
			wedge("Guardian Crown " .. side, Vector3.new(0.3, 0.7, 0.48), accent, Enum.Material.Neon, head.CFrame * CFrame.new(side * 0.38, 0.68, 0.1) * CFrame.Angles(0, 0, math.rad(side * 12)))
		end
		part("Guardian Rune Core", Vector3.new(0.68, 0.68, 0.24), accent, Enum.Material.Neon, Enum.PartType.Ball, body.CFrame * CFrame.new(0, 0.18, -0.74))
	elseif isPhoenix then
		body = part("Phoenix Feather Body", Vector3.new(1.35, 1.55, 1.55), primary, Enum.Material.SmoothPlastic, Enum.PartType.Ball, CFrame.new())
		local head = part("Phoenix Head", Vector3.new(0.92, 0.92, 0.94), accent, Enum.Material.SmoothPlastic, Enum.PartType.Ball, CFrame.new(0, 0.86, -0.72))
		eyes(head.CFrame, 0.22, 0.08, -0.43)
		wedge("Phoenix Beak", Vector3.new(0.44, 0.34, 0.72), Color3.fromRGB(255, 190, 47), Enum.Material.Metal, head.CFrame * CFrame.new(0, -0.06, -0.68) * CFrame.Angles(math.rad(-90), 0, 0))
		for side = -1, 1, 2 do
			wedge("Phoenix Wing " .. side, Vector3.new(0.36, 1.65, 1.75), accent, Enum.Material.Neon, CFrame.new(side * 1.03, 0.18, 0.18) * CFrame.Angles(0, math.rad(side * 14), math.rad(side * 24)))
			wedge("Phoenix Crest " .. side, Vector3.new(0.2, 0.78, 0.42), primary, Enum.Material.Neon, head.CFrame * CFrame.new(side * 0.22, 0.65, 0.1) * CFrame.Angles(0, 0, math.rad(side * 16)))
		end
		for plume = -1, 1 do
			wedge("Phoenix Tail Plume " .. plume, Vector3.new(0.28, 0.55, 1.65), plume == 0 and accent or primary, Enum.Material.Neon, body.CFrame * CFrame.new(plume * 0.38, -0.2, 1.35) * CFrame.Angles(math.rad(-18), 0, math.rad(plume * 12)))
		end
		part("Phoenix Heart Core", Vector3.new(0.42, 0.42, 0.2), accent, Enum.Material.Neon, Enum.PartType.Ball, body.CFrame * CFrame.new(0, 0.18, -0.78))
	elseif isDragon then
		body = part("Dragon Armored Body", Vector3.new(1.45, 1.05, 2.05), primary, Enum.Material.Metal, Enum.PartType.Ball, CFrame.new())
		local head = part("Dragon Head", Vector3.new(1.12, 0.9, 1.12), primary:Lerp(accent, 0.12), Enum.Material.Metal, Enum.PartType.Ball, CFrame.new(0, 0.38, -1.16))
		part("Dragon Muzzle", Vector3.new(0.72, 0.46, 0.72), shadow, Enum.Material.Metal, Enum.PartType.Block, head.CFrame * CFrame.new(0, -0.16, -0.66))
		eyes(head.CFrame, 0.26, 0.12, -0.5)
		for side = -1, 1, 2 do
			wedge("Dragon Wing " .. side, Vector3.new(0.28, 1.25, 1.65), accent, Enum.Material.Neon, body.CFrame * CFrame.new(side * 0.92, 0.34, 0.12) * CFrame.Angles(0, math.rad(side * 15), math.rad(side * 28)))
			wedge("Dragon Horn " .. side, Vector3.new(0.22, 0.64, 0.48), accent, Enum.Material.Metal, head.CFrame * CFrame.new(side * 0.32, 0.58, 0.08) * CFrame.Angles(0, 0, math.rad(side * 18)))
			part("Dragon Foot " .. side, Vector3.new(0.42, 0.34, 0.62), shadow, Enum.Material.Metal, Enum.PartType.Ball, body.CFrame * CFrame.new(side * 0.5, -0.62, -0.25))
		end
		for segment = 1, 3 do
			part(
				"Dragon Tail Segment " .. segment,
				Vector3.new(0.48 - segment * 0.07, 0.42 - segment * 0.05, 0.72),
				segment == 3 and accent or shadow,
				segment == 3 and Enum.Material.Neon or Enum.Material.Metal,
				Enum.PartType.Ball,
				body.CFrame * CFrame.new(0, 0.05 + segment * 0.04, 1.02 + segment * 0.55) * CFrame.Angles(math.rad(-12), 0, 0)
			)
		end
		part("Dragon Ember Core", Vector3.new(0.46, 0.46, 0.2), accent, Enum.Material.Neon, Enum.PartType.Ball, body.CFrame * CFrame.new(0, 0.14, -1.02))
	else
		body = part("Companion Body", Vector3.new(isFox and 1.38 or 1.55, 1.05, isFox and 2.05 or 1.85), primary, Enum.Material.SmoothPlastic, Enum.PartType.Ball, CFrame.new())
		local head = part("Companion Head", Vector3.new(isFox and 1.02 or 1.15, 1.12, isFox and 1.16 or 1.08), primary:Lerp(Color3.new(1, 1, 1), 0.08), definition.rarity == "Epic" and Enum.Material.Glass or Enum.Material.SmoothPlastic, Enum.PartType.Ball, CFrame.new(0, 0.3, -1.08))
		eyes(head.CFrame, 0.25, 0.12, -0.51)
		if isCat or isFox then
			for side = -1, 1, 2 do
				wedge(
					(isFox and "Fox Pointed Ear " or "Cat Pointed Ear ") .. side,
					Vector3.new(0.38, isFox and 0.78 or 0.66, 0.34),
					isFox and accent or primary,
					Enum.Material.SmoothPlastic,
					head.CFrame * CFrame.new(side * 0.34, 0.68, 0.04) * CFrame.Angles(0, 0, math.rad(side * 8))
				)
			end
		else
			for side = -1, 1, 2 do
				part("Pup Floppy Ear " .. side, Vector3.new(0.34, 0.62, 0.3), shadow, Enum.Material.SmoothPlastic, Enum.PartType.Ball, head.CFrame * CFrame.new(side * 0.5, 0.18, 0.05) * CFrame.Angles(0, 0, math.rad(side * 20)))
			end
		end
		part(
			isCat and "Cat Muzzle" or isFox and "Fox Muzzle" or "Pup Muzzle",
			Vector3.new(isFox and 0.52 or 0.64, 0.4, isFox and 0.68 or 0.52),
			primary:Lerp(Color3.new(1, 1, 1), 0.35),
			Enum.Material.SmoothPlastic,
			Enum.PartType.Ball,
			head.CFrame * CFrame.new(0, -0.16, -0.55)
		)
		part("Readable Nose", Vector3.new(0.2, 0.17, 0.14), Color3.fromRGB(18, 24, 29), Enum.Material.SmoothPlastic, Enum.PartType.Ball, head.CFrame * CFrame.new(0, -0.13, -0.9))
		for side = -1, 1, 2 do
			for front = -1, 1, 2 do
				part("Companion Paw " .. side .. " " .. front, Vector3.new(0.36, 0.27, 0.5), shadow, Enum.Material.SmoothPlastic, Enum.PartType.Ball, body.CFrame * CFrame.new(side * 0.48, -0.58, front * 0.52))
			end
		end
		if isCat then
			part("Miner Helmet", Vector3.new(1.28, 0.38, 1.2), Color3.fromRGB(57, 65, 72), Enum.Material.Metal, Enum.PartType.Ball, head.CFrame * CFrame.new(0, 0.48, 0))
			part("Miner Lamp", Vector3.new(0.34, 0.34, 0.22), accent, Enum.Material.Neon, Enum.PartType.Ball, head.CFrame * CFrame.new(0, 0.54, -0.56))
			part("Cat Tail Base", Vector3.new(0.3, 0.3, 1.05), shadow, Enum.Material.SmoothPlastic, Enum.PartType.Ball, body.CFrame * CFrame.new(0.48, 0.1, 1.22) * CFrame.Angles(math.rad(-24), math.rad(-12), 0))
			part("Cat Tail Tip", Vector3.new(0.26, 0.26, 0.72), accent, Enum.Material.SmoothPlastic, Enum.PartType.Ball, body.CFrame * CFrame.new(0.68, 0.42, 1.84) * CFrame.Angles(math.rad(28), math.rad(-18), 0))
		elseif isFox then
			part("Fox Tail", Vector3.new(0.62, 0.62, 1.5), primary, Enum.Material.SmoothPlastic, Enum.PartType.Ball, body.CFrame * CFrame.new(0.18, 0.18, 1.55) * CFrame.Angles(math.rad(-20), math.rad(-12), 0))
			part("Fox Tail Crystal Tip", Vector3.new(0.52, 0.52, 0.84), accent, Enum.Material.Neon, Enum.PartType.Ball, body.CFrame * CFrame.new(0.36, 0.48, 2.42) * CFrame.Angles(math.rad(28), math.rad(-12), 0))
			for shard = -1, 1 do
				wedge("Fox Crystal Shard " .. shard, Vector3.new(0.24, 0.7, 0.34), accent, Enum.Material.Neon, body.CFrame * CFrame.new(shard * 0.38, 0.74, 0.18) * CFrame.Angles(0, 0, math.rad(shard * 10)))
			end
		else
			part("Pup Collar", Vector3.new(0.34, 1.18, 1.18), accent, Enum.Material.Metal, Enum.PartType.Cylinder, head.CFrame * CFrame.new(0, -0.34, 0.42) * CFrame.Angles(0, 0, math.rad(90)))
			part("Pup Tail", Vector3.new(0.34, 0.34, 1.15), shadow, Enum.Material.SmoothPlastic, Enum.PartType.Ball, body.CFrame * CFrame.new(0, 0.28, 1.3) * CFrame.Angles(math.rad(-32), 0, 0))
		end
		part("Rarity Identity Core", Vector3.new(0.38, 0.38, 0.18), accent, Enum.Material.Neon, Enum.PartType.Ball, body.CFrame * CFrame.new(0, 0.16, -0.96))
	end

	model.PrimaryPart = body
	model:SetAttribute("PetSilhouetteVersion", "SpeciesReadableV2")
	model:SetAttribute("PetSpeciesShape", species)
	model:SetAttribute("PetReadableFeatureCount", featureCount)
	model:SetAttribute("PetRarityIdentity", tostring(definition.rarity or "Common"))
	model:SetAttribute("ProceduralPrimitiveBlob", false)
	return model
end

function companionRuntime.BuildInventoryPetPreview(petName)
	local definition = GameConfig.PetDefinition(tostring(petName or ""))
	if not definition then return nil end

	local model
	local visualSource = "ProceduralPetV2"
	if definition.templateName then
		local catalogTemplate, catalogSource = catalogCompanionTemplate(definition)
		if catalogTemplate then
			model = companionRuntime.CloneSanitizedCatalogVisual(catalogTemplate.Parent, catalogTemplate)
			if model then
				companionRuntime.StyleNormalCatalogPet(model, definition)
				visualSource = catalogSource
			end
		end
	end
	if not model then
		local curated = workspace:FindFirstChild("CuratedVisualAssets")
		local dragonTemplate = curated and curated:FindFirstChild("Sanitized Crimson Dragon Companion")
		if dragonTemplate
			and (definition.rarity == "Legendary" or definition.rarity == "Secret")
			and companionRuntime.PrepareVisualAsset(dragonTemplate, dragonTemplate)
		then
			model = companionRuntime.CloneSanitizedVisual(dragonTemplate)
			visualSource = "CuratedDragon"
		end
	end
	if not model then
		model = companionRuntime.BuildProceduralPet(definition)
		visualSource = definition.rarity == "Premium" and "ProceduralFallbackV2" or "ProceduralPetV2"
	end

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("ParticleEmitter")
			or descendant:IsA("Beam")
			or descendant:IsA("Trail")
			or descendant:IsA("Light")
			or descendant:IsA("Highlight")
		then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
		end
	end
	local sanitized = pcall(FistVisualBuilder.SanitizeVisual, model)
	if not sanitized or not FistVisualBuilder.IsSanitizedVisual(model) then
		model:Destroy()
		return nil
	end
	model.Name = "InventoryPreview_" .. tostring(definition.name)
	model:SetAttribute("InventoryPreview", true)
	model:SetAttribute("PetDefinitionName", tostring(definition.name))
	model:SetAttribute("PetVisualIdentity", tostring(definition.visual or definition.name))
	model:SetAttribute("PetPreviewVisualSource", visualSource)
	return model
end

local function buildCompanion(token, index)
	local name, stars = GameConfig.ParsePetToken(token)
	local definition = petDefinition(name)
	if definition.templateName then
		local catalogTemplate, visualSource = catalogCompanionTemplate(definition)
		if catalogTemplate then
			local catalogClone = companionRuntime.CloneSanitizedCatalogVisual(catalogTemplate.Parent, catalogTemplate)
			if catalogClone then
				companionRuntime.StyleNormalCatalogPet(catalogClone, definition)
				local registered = registerCompanion(catalogClone, token, index, definition, stars, visualSource)
				if registered then return registered end
			end
		end
	end
	local curated = workspace:FindFirstChild("CuratedVisualAssets")
	local dragonTemplate = curated and curated:FindFirstChild("Sanitized Crimson Dragon Companion")
	if dragonTemplate
		and (definition.rarity == "Legendary" or definition.rarity == "Secret")
		and companionRuntime.PrepareVisualAsset(dragonTemplate, dragonTemplate) then
		local clone = companionRuntime.CloneSanitizedVisual(dragonTemplate)
		if clone then
			clone:ScaleTo(clone:GetScale() * (definition.rarity == "Premium" and 0.42 or definition.rarity == "Secret" and 0.36 or 0.28))
			local registered = registerCompanion(clone, token, index, definition, stars, "CuratedDragon")
			if registered then return registered end
		end
	end
	local model = companionRuntime.BuildProceduralPet(definition)
	local visualSource = definition.rarity == "Premium" and "ProceduralFallbackV2" or "ProceduralPetV2"
	return registerCompanion(model, token, index, definition, stars, visualSource)
end

-- The equipped item uses the sanitized closed-fist mesh as its silhouette.
-- Tier color, material, armor pattern, and effects remain data-driven so the
-- world model reads like the same item shown by the inventory/shop icon.
function companionRuntime.ApplyFistAuraMotionSetting()
	local enabled = clientSettings.motion == true
	local emitterCount = 0
	if currentGauntlet and currentGauntlet.Parent then
		for _, descendant in ipairs(currentGauntlet:GetDescendants()) do
			if descendant:IsA("ParticleEmitter") and descendant:GetAttribute("FistAuraEffect") == true then
				descendant.Enabled = enabled
				emitterCount += 1
			end
		end
		currentGauntlet:SetAttribute("AuraParticlesEnabled", enabled and emitterCount > 0)
		currentGauntlet:SetAttribute("AuraReducedMotionSuppressed", not enabled and emitterCount > 0)
	end
	return emitterCount
end
shared.PunchWallApplyFistAuraMotion = companionRuntime.ApplyFistAuraMotionSetting

function companionRuntime.BuildItemMatchedGauntlet(fistName)
	if shared.PunchWallHiddenFistHand and shared.PunchWallHiddenFistHand.Parent then
		shared.PunchWallHiddenFistHand.LocalTransparencyModifier = 0
		shared.PunchWallHiddenFistHand.Transparency = shared.PunchWallHiddenHandTransparency or 0
	end
	shared.PunchWallHiddenFistHand = nil
	shared.PunchWallHiddenHandTransparency = nil
	if currentGauntlet then currentGauntlet:Destroy() end
	currentGauntlet = nil
	currentTrail = nil
	local character = player.Character
	local hand = character and (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm"))
	if not hand or not hand:IsA("BasePart") then return false end
	local fallbackRigProfile = FistVisualBuilder.GetRigProfile(hand)
	local definition = GameConfig.FistDefinition(fistName)
	local presentation = FistVisualBuilder.GetHeroGauntletPresentation(definition)
	local model = Instance.new("Model")
	model.Name = "Equipped Kaiju Gauntlet"
	model:SetAttribute("ItemType", "Fist")
	model:SetAttribute("DisplayName", definition.displayName)
	model:SetAttribute("RequestedTier", definition.tier)
	model:SetAttribute("RequestedFistStyle", definition.style)
	model:SetAttribute("ClosedFist", true)
	model:SetAttribute("VisualSystem", "ItemMatchedClosedFistV3")
	model:SetAttribute("VisualSource", "ProceduralFallback")
	model:SetAttribute("ImportedRuntimeSilhouette", false)
	model:SetAttribute("SilhouetteFamily", "ClosedHeroFist")
	model:SetAttribute("ArmorPattern", presentation.armorPattern)
	model:SetAttribute("ShopArtVariant", presentation.shopArtKey)
	model:SetAttribute("IconIdentity", presentation.iconIdentity)
	model:SetAttribute("FistVariantKey", presentation.variantKey)
	model:SetAttribute("SignatureFeature", presentation.signatureFeature)
	model:SetAttribute("CatalogMotif", presentation.catalogMotif)
	model:SetAttribute("CatalogMotifVersion", presentation.catalogMotifVersion)
	model:SetAttribute("ShopArtMatchedTier", definition.tier)
	model:SetAttribute("ItemColorMatched", true)
	model:SetAttribute("ItemMaterialMatched", true)
	model:SetAttribute("ItemVisualReady", false)
	model:SetAttribute("WholeHandHidden", false)
	model:SetAttribute("HandTransparencyPreserved", true)
	model:SetAttribute("AuraTier", definition.tier)
	model:SetAttribute("AuraEnabled", false)
	model:SetAttribute("AuraEmitterCount", 0)
	model:SetAttribute("AuraTotalRate", 0)
	model:SetAttribute("AuraClass", "None")
	model:SetAttribute("FistAuraMotionAware", true)
	local requestedScale = definition.style == "Titan" and 1.34
		or definition.style == "Thunder" and 1.25
		or definition.style == "Iron" and 1.18
		or definition.style == "Boxing" and 1.12
		or 1.05
	local scale = math.clamp(requestedScale, 1, 1.25)
	local primary = definition.color
	local accent = definition.accent or primary:Lerp(Color3.new(1, 1, 1), 0.25)
	local function addTierAura(targetPart)
		if not targetPart then return end
		local tier = math.clamp(math.floor(tonumber(definition.tier) or 1), 1, 8)
		if tier < 3 then
			model:SetAttribute("TierAura", "")
			model:SetAttribute("AuraParticlesEnabled", false)
			model:SetAttribute("AuraReducedMotionSuppressed", false)
			return
		end
		local rateByTier = { [3] = 3, [4] = 5, [5] = 7, [6] = 8.5, [7] = 10, [8] = 12 }
		local auraRate = rateByTier[tier]
		local aura = Instance.new("ParticleEmitter")
		aura.Name = (definition.displayName or fistName) .. " Aura"
		aura:SetAttribute("FistAuraEffect", true)
		aura.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		aura.Color = ColorSequence.new(primary, accent)
		aura.LightEmission = math.clamp(0.3 + tier * 0.08, 0.35, 1)
		aura.Rate = auraRate
		aura.Lifetime = NumberRange.new(0.24, 0.42 + tier * 0.025)
		aura.Speed = NumberRange.new(0.2, 0.52 + tier * 0.07)
		aura.Drag = 3
		aura.SpreadAngle = Vector2.new(180, 180)
		aura.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.12 + tier * 0.018),
			NumberSequenceKeypoint.new(0.35, 0.18 + tier * 0.024),
			NumberSequenceKeypoint.new(1, 0),
		})
		aura.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, tier == 3 and 0.34 or 0.14),
			NumberSequenceKeypoint.new(1, 1),
		})
		aura.Enabled = clientSettings.motion == true
		aura.Parent = targetPart
		local emitterCount = 1
		local totalRate = auraRate
		if tier >= 4 then
			local auraLight = Instance.new("PointLight")
			auraLight.Name = "Fist Aura Light"
			auraLight.Color = accent
			auraLight.Brightness = 0.18 + tier * 0.08
			auraLight.Range = 2.8 + tier * 0.58
			auraLight.Shadows = false
			auraLight.Parent = targetPart

			local highlight = Instance.new("Highlight")
			highlight.Name = "Hero Fist Tier Glow"
			highlight.Adornee = model
			highlight.DepthMode = Enum.HighlightDepthMode.Occluded
			highlight.FillColor = primary
			highlight.OutlineColor = accent
			highlight.FillTransparency = math.clamp(0.96 - tier * 0.02, 0.78, 0.9)
			highlight.OutlineTransparency = math.clamp(0.86 - tier * 0.065, 0.28, 0.6)
			highlight.Parent = model
		end
		if tier >= 5 then
			local energy = Instance.new("ParticleEmitter")
			energy.Name = (definition.displayName or fistName) .. " Energy Arcs"
			energy:SetAttribute("FistAuraEffect", true)
			energy.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			energy.Color = ColorSequence.new(accent, Color3.new(1, 1, 1))
			energy.LightEmission = 1
			energy.Rate = 2 + tier
			energy.Lifetime = NumberRange.new(0.16, 0.34)
			energy.Speed = NumberRange.new(0.4, 1.4)
			energy.Drag = 4
			energy.SpreadAngle = Vector2.new(180, 180)
			energy.Rotation = NumberRange.new(0, 360)
			energy.RotSpeed = NumberRange.new(-180, 180)
			energy.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.24 + tier * 0.025),
				NumberSequenceKeypoint.new(0.45, 0.12 + tier * 0.012),
				NumberSequenceKeypoint.new(1, 0),
			})
			energy.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.08),
				NumberSequenceKeypoint.new(1, 1),
			})
			energy.Enabled = clientSettings.motion == true
			energy.Parent = targetPart
			emitterCount += 1
			totalRate += energy.Rate
		end
		model:SetAttribute("TierAura", aura.Name)
		model:SetAttribute("AuraRate", auraRate)
		model:SetAttribute("AuraEnabled", true)
		model:SetAttribute("AuraEmitterCount", emitterCount)
		model:SetAttribute("AuraTotalRate", totalRate)
		model:SetAttribute("AuraClass", tier >= 6 and "PremiumHeroic" or tier >= 5 and "LegendaryEnergy" or tier == 4 and "EpicGlow" or "RareSpark")
		model:SetAttribute("AuraParticlesEnabled", clientSettings.motion == true)
		model:SetAttribute("AuraReducedMotionSuppressed", clientSettings.motion ~= true)
	end

	-- Use sanitized Creator Store visuals when available. The gameplay punch, input,
	-- animation, and damage remain owned by this client/server code.
	local importedSource
	local assetFolder = ReplicatedStorage:FindFirstChild("PunchWallFistAssets")
	local externalAssetFolder = ReplicatedStorage:FindFirstChild("PunchWallExternalAssets")
	local visualAssetFolder = assetFolder
	if not importedSource and assetFolder then
		-- The approved armored closed-fist mesh is the stable item silhouette for
		-- every tier. Earlier red/power glove candidates were retained in the place
		-- as sanitized fallbacks, but their authored axes read as boxes/rings when
		-- welded to live R6/R15 hands. Color, material, plates, fins, and aura still
		-- come from the equipped catalog item so the world model matches its icon.
		importedSource = assetFolder:FindFirstChild("CreatorStore_ArmoredClosedHeroFist")
			or assetFolder:FindFirstChild("CreatorStore_SmoothClosedHeroFist")
			or assetFolder:FindFirstChild("CreatorStore_FittedHeroBoxingGlove")
	end
	local imported
	if importedSource
		and importedSource.Parent
		and visualAssetFolder
		and companionRuntime.PrepareVisualAsset(visualAssetFolder, importedSource) then
		imported = companionRuntime.CloneSanitizedVisual(importedSource)
	end
	if imported then
		imported.Name = "Creator Store Fist Visual"
		imported.Parent = model
		model:SetAttribute("VisualSource", "SanitizedCreatorStoreMesh")
		model:SetAttribute("ImportedRuntimeSilhouette", true)
		model:SetAttribute("VisualTemplate", importedSource.Name)
		model:SetAttribute("VisualTemplateAssetId", tostring(importedSource:GetAttribute("AssetId") or ""))
		model:SetAttribute("SanitizedVisualOnly", true)
		local isArmoredClosedFist = importedSource.Name == "CreatorStore_ArmoredClosedHeroFist"
		local isClosedHeroFist = importedSource.Name == "CreatorStore_SmoothClosedHeroFist"
		local isGoldFist = importedSource.Name == "Sanitized_PowerFistGoldKnuckle"
			or importedSource.Name == "Sanitized_TitanGoldFist"
		local isImportedClosedFist = isArmoredClosedFist or isClosedHeroFist or isGoldFist
		local isItemMeshFist = isImportedClosedFist
		-- Creator Store meshes have unrelated authoring scales. Normalize the
		-- largest visual dimension against the actual RightHand before welding,
		-- otherwise a glove can appear as a detached box beside the arm.
		local sourceSize = FistVisualBuilder.EffectiveVisualSize(imported)
		local styleScale = definition.style == "Celestial" and 2.08
			or definition.style == "Storm" and 1.95
			or definition.style == "Vanguard" and 1.82
			or definition.style == "Titan" and 2.02
			or definition.style == "Thunder" and 1.88
			or definition.style == "Iron" and 1.76
			or definition.style == "Boxing" and 1.76
			or 1.72
		local importedScale, rigProfile, boundedStyleRatio = FistVisualBuilder.ComputeImportedScale(
			sourceSize,
			hand,
			styleScale
		)
		if imported:IsA("Model") then imported:ScaleTo(importedScale) else imported.Size *= importedScale end
		if isArmoredClosedFist then
			-- The approved source is unusually narrow for layered-clothing avatars.
			-- Grow the molded fist as a coherent volume so it reads as hero gear,
			-- while keeping the cuff centered on the wrist. Higher tiers receive a
			-- slightly stronger silhouette without becoming face-sized.
			local prominenceScale = definition.tier >= 8 and 1.28
				or definition.tier >= 6 and 1.25
				or definition.tier >= 5 and 1.23
				or definition.tier >= 3 and 1.2
				or 1.18
			for _, descendant in ipairs(imported:GetDescendants()) do
				if descendant:IsA("BasePart") and descendant:FindFirstChildWhichIsA("SpecialMesh") then
					descendant.Size = Vector3.new(
						descendant.Size.X * 1.3 * prominenceScale,
						descendant.Size.Y * prominenceScale,
						descendant.Size.Z * 1.08 * prominenceScale
					)
				end
			end
			model:SetAttribute("ProminenceScale", prominenceScale)
			model:SetAttribute("ProminenceSystem", "TierHeroVolumeV4")
		end
		-- Imported Creator Store meshes use a different authoring axis than the
		-- character rig. Keep the wrist centered in the glove and turn the
		-- knuckles forward instead of leaving the asset's authoring direction
		-- attached to the side or back of the hand.
		local scaledBoundsCFrame, scaledBoundsSize
		if imported:IsA("Model") then
			scaledBoundsCFrame, scaledBoundsSize = imported:GetBoundingBox()
		else
			scaledBoundsCFrame, scaledBoundsSize = imported.CFrame, imported.Size
		end
		local isFittedHeroGlove = importedSource.Name == "CreatorStore_FittedHeroBoxingGlove"
		-- The approved mesh is authored lengthwise on local Y. Point that axis
		-- down the forearm instead of character-forward; the old forward mapping
		-- made the glove look like a detached sideways ornament in normal play.
		local closedFistRotation = CFrame.Angles(0, 0, math.rad(180))
		local gripRotation = (isArmoredClosedFist or isGoldFist or isClosedHeroFist) and closedFistRotation
			or (isFittedHeroGlove and CFrame.new() or CFrame.Angles(0, math.rad(180), 0))
		local wristY = isImportedClosedFist
			and hand.Size.Y * rigProfile.wristYScale
			or isFittedHeroGlove
			and (hand.Name == "Right Arm" and -hand.Size.Y * 0.365 or -hand.Size.Y * 0.08)
			or (hand.Name == "Right Arm" and -hand.Size.Y * 0.42 or -hand.Size.Y * 0.03)
		local rawForwardOffset = (isArmoredClosedFist or isGoldFist)
			and (scaledBoundsSize.Z * 0.08 + hand.Size.Z * 0.1)
			or isClosedHeroFist
			and (scaledBoundsSize.X * 0.18 + hand.Size.Z * 0.05)
			or isFittedHeroGlove
			and hand.Size.Z * 0.06
			or (hand.Size.Z * 0.18 + scaledBoundsSize.Z * 0.22)
		local forwardOffset = math.clamp(rawForwardOffset, hand.Size.Z * 0.04, hand.Size.Z * 0.62)
		local desiredBounds = hand.CFrame * CFrame.new(0, wristY, -forwardOffset) * gripRotation
		if imported:IsA("Model") then
			local pivotToBounds = imported:GetPivot():ToObjectSpace(scaledBoundsCFrame)
			imported:PivotTo(desiredBounds * pivotToBounds:Inverse())
		else
			imported.CFrame = desiredBounds
		end
		if isArmoredClosedFist then
			local texturedPart
			for _, descendant in ipairs(imported:GetDescendants()) do
				if descendant:IsA("BasePart") and descendant:FindFirstChildWhichIsA("SpecialMesh") then
					texturedPart = descendant
					break
				end
			end
			if texturedPart then
				local sourceMesh = texturedPart:FindFirstChildWhichIsA("SpecialMesh")
				-- The source texture is gold/white and overpowers catalog colors. Keep
				-- the approved molded mesh geometry but tint it from the equipped item.
				if sourceMesh then sourceMesh.TextureId = "" end
				texturedPart.Color = definition.tier <= 2 and Color3.fromRGB(191, 47, 39) or primary
				texturedPart.Material = definition.material
				local shell = texturedPart:Clone()
				shell.Name = "Tier Color Shell"
				for _, child in ipairs(shell:GetChildren()) do
					if not child:IsA("SpecialMesh") then child:Destroy() end
				end
				local shellMesh = shell:FindFirstChildWhichIsA("SpecialMesh")
				if shellMesh then
					shellMesh.TextureId = ""
					shellMesh.Scale *= 1.012
				end
				shell.Color = definition.tier <= 2 and primary:Lerp(Color3.new(1, 1, 1), 0.12) or accent
				shell.Material = definition.tier >= 4 and Enum.Material.Neon
					or definition.tier <= 2 and Enum.Material.SmoothPlastic
					or definition.material
				shell.Transparency = definition.tier == 1 and 0.88
					or definition.tier == 2 and 0.82
					or definition.tier == 3 and 0.68
					or definition.tier == 4 and 0.61
					or 0.56
				shell.CastShadow = false
				shell.CFrame = texturedPart.CFrame
				shell:SetAttribute("FistShape", "TierColorShell")
				shell.Parent = imported
				model:SetAttribute("DetailTexturePreserved", false)
			end
		end
		local effectiveVisualSize = scaledBoundsSize
		local handLargest = math.max(hand.Size.X, hand.Size.Y, hand.Size.Z, 0.01)
		local visualLargest = math.max(effectiveVisualSize.X, effectiveVisualSize.Y, effectiveVisualSize.Z)
		local visualToHandRatio = visualLargest / handLargest
		local wristCenterOffset = (desiredBounds.Position - hand.Position).Magnitude
		model:SetAttribute("AlignmentStandard", rigProfile.name)
		model:SetAttribute("GripProfile", isGoldFist and "GoldFistWristAligned"
			or isArmoredClosedFist and "ArmoredFistWristAligned"
			or isClosedHeroFist and "ClosedFistForward"
			or (isFittedHeroGlove and "FittedHeroArm" or "LegacyCreatorStore"))
		model:SetAttribute("GripForwardOffset", forwardOffset)
		model:SetAttribute("GripAxis", isImportedClosedFist and "LocalYToDistalForearm" or "Legacy")
		model:SetAttribute("ImportedScale", importedScale)
		model:SetAttribute("BoundedStyleRatio", boundedStyleRatio)
		model:SetAttribute("VisualToHandRatio", visualToHandRatio)
		model:SetAttribute("WristCenterOffset", wristCenterOffset)
		model:SetAttribute("WristAttachmentBounded", wristCenterOffset <= rigProfile.maxCenterOffset)
		model:SetAttribute("FaceOcclusionSafe", visualToHandRatio <= rigProfile.maxTargetRatio + 0.01)
		model:SetAttribute("WholeHandHidden", false)
		model:SetAttribute("HandTransparencyPreserved", true)
		model:SetAttribute("VisualBoundsX", scaledBoundsSize.X)
		model:SetAttribute("VisualBoundsY", scaledBoundsSize.Y)
		model:SetAttribute("VisualBoundsZ", scaledBoundsSize.Z)
		model:SetAttribute("EffectiveVisualBoundsX", effectiveVisualSize.X)
		model:SetAttribute("EffectiveVisualBoundsY", effectiveVisualSize.Y)
		model:SetAttribute("EffectiveVisualBoundsZ", effectiveVisualSize.Z)
		-- Creator Store assets can be a single MeshPart or a Model. Include the
		-- root part as well as descendants so every visual is actually attached.
		local visualParts = {}
		if imported:IsA("BasePart") then
			table.insert(visualParts, imported)
		end
		for _, descendant in ipairs(imported:GetDescendants()) do
			if descendant:IsA("BasePart") then
				table.insert(visualParts, descendant)
			end
		end
		local firstVisualPart = visualParts[1]
		for _, descendant in ipairs(visualParts) do
			if isItemMeshFist and descendant.Name ~= "Tier Color Shell" then
				descendant.Color = primary
				descendant.Material = definition.material
			end
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
			descendant.AssemblyLinearVelocity = Vector3.zero
			descendant.AssemblyAngularVelocity = Vector3.zero
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = descendant
			weld.Part1 = hand
			weld.Parent = descendant
		end
		if isItemMeshFist then
			local function addTierArmor(name, size, targetCFrame, color, material, shape)
				local part = Instance.new("Part")
				part.Name = name
				part.Size = size
				part.CFrame = targetCFrame
				part.Color = color
				part.Material = material
				part.Shape = shape or Enum.PartType.Block
				part.CanCollide = false
				part.CanTouch = false
				part.CanQuery = false
				part.Massless = true
				part.Parent = model
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = part
				weld.Part1 = hand
				weld.Parent = part
				return part
			end
			local function addTierFin(name, size, targetCFrame, color)
				local part = Instance.new("WedgePart")
				part.Name = name
				part.Size = size
				part.CFrame = targetCFrame
				part.Color = color
				part.Material = Enum.Material.Neon
				part.CanCollide = false
				part.CanTouch = false
				part.CanQuery = false
				part.Massless = true
				part.Parent = model
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = part
				weld.Part1 = hand
				weld.Parent = part
				return part
			end
			local cuffColor = definition.tier >= 5 and primary:Lerp(Color3.fromRGB(75, 43, 14), 0.36)
				or definition.tier >= 3 and primary:Lerp(Color3.new(0, 0, 0), 0.28)
				or primary:Lerp(Color3.new(0, 0, 0), 0.18)
			local cuff = addTierArmor(
				"Tier Wrist Cuff",
				Vector3.new(
					math.max(hand.Size.Y * 0.2, 0.06),
					scaledBoundsSize.X * 0.94,
					scaledBoundsSize.Z * 0.96
				),
				hand.CFrame * CFrame.new(0, hand.Size.Y * rigProfile.cuffYScale, 0) * CFrame.Angles(0, 0, math.rad(90)),
				cuffColor,
				definition.tier >= 3 and Enum.Material.Metal or definition.material,
				Enum.PartType.Cylinder
			)
			cuff:SetAttribute("FistShape", "WristBridge")
			local fistCenter = desiredBounds.Position
			local outward = -hand.CFrame.LookVector
			local up = hand.CFrame.UpVector
			local distal = -up
			local right = hand.CFrame.RightVector
			local fistLength = scaledBoundsSize.Y
			local fistDepth = scaledBoundsSize.Z
			if definition.tier >= 4 then
				local plateCenter = fistCenter
					+ outward * (fistDepth * 0.51 + 0.025)
					+ distal * (fistLength * 0.02)
				local plateCFrame = CFrame.lookAt(plateCenter, plateCenter + outward, up)
				local plateColor = definition.tier == 5 and primary:Lerp(Color3.new(0, 0, 0), 0.62) or accent
				local coreSize = math.clamp(math.min(scaledBoundsSize.X, scaledBoundsSize.Y) * 0.28, 0.22, 0.42)
				local plate = addTierArmor(
					"Hero Core Gem",
					Vector3.new(coreSize * 0.82, coreSize * 0.82, 0.12),
					plateCFrame * CFrame.Angles(0, 0, math.rad(45)),
					plateColor,
					definition.tier >= 4 and Enum.Material.Neon or definition.material,
					Enum.PartType.Block
				)
				plate:SetAttribute("FistShape", "TierCore")
				if definition.tier >= 4 then
					local light = Instance.new("PointLight")
					light.Color = accent
					light.Brightness = definition.tier == 5 and 1.25 or 0.85
					light.Range = definition.tier == 5 and 8 or 6
					light.Parent = plate
				end
			end
			for plateIndex = 1, presentation.plateCount do
				local offset = plateIndex - (presentation.plateCount + 1) * 0.5
				local platePosition = fistCenter
					+ right * (offset * math.clamp(scaledBoundsSize.X * 0.17, 0.14, 0.25))
					+ outward * (fistDepth * 0.5 + 0.018)
					+ distal * (fistLength * 0.16)
				local armorPlate = addTierArmor(
					("Item %s Plate %d"):format(presentation.armorPattern, plateIndex),
					Vector3.new(
						math.clamp(scaledBoundsSize.X * 0.13, 0.13, 0.22),
						math.clamp(scaledBoundsSize.Z * 0.18, 0.12, 0.24),
						0.11
					),
					CFrame.lookAt(platePosition, platePosition + outward, up),
					plateIndex % 2 == 0 and accent or primary:Lerp(accent, 0.38),
					definition.tier >= 4 and Enum.Material.Neon or Enum.Material.Metal
				)
				armorPlate:SetAttribute("FistShape", "ItemMatchedArmorPlate")
			end
			for finIndex = 1, presentation.finCount do
				local side = finIndex == 1 and -1 or 1
				local finPosition = fistCenter
					+ right * side * (scaledBoundsSize.X * 0.54)
					+ outward * (fistDepth * 0.08)
					+ distal * (fistLength * 0.08)
				local fin = addTierFin(
					("Item %s Energy Fin %d"):format(presentation.armorPattern, finIndex),
					Vector3.new(0.16, math.clamp(scaledBoundsSize.Z * 0.44, 0.3, 0.55), 0.3),
					CFrame.lookAt(finPosition, finPosition + outward, up)
						* CFrame.Angles(0, 0, math.rad(side * 18)),
					accent
				)
				fin:SetAttribute("FistShape", "ItemMatchedEnergyFin")
			end
			model:SetAttribute("SilhouetteFamily", "ClosedHeroFist")
			model:SetAttribute("ShopArtMatchedTier", definition.tier)
		end
		if firstVisualPart then
			local a0 = Instance.new("Attachment")
			a0.Position = Vector3.new(0, firstVisualPart.Size.Y * 0.5, 0)
			a0.Parent = firstVisualPart
			local a1 = Instance.new("Attachment")
			a1.Position = Vector3.new(0, -firstVisualPart.Size.Y * 0.5, 0)
			a1.Parent = firstVisualPart
			local trail = Instance.new("Trail")
			trail.Attachment0 = a0
			trail.Attachment1 = a1
			trail.Color = ColorSequence.new(accent, primary:Lerp(Color3.new(1, 1, 1), 0.35))
			trail.Lifetime = 0.16
			trail.Enabled = false
			trail.Parent = firstVisualPart
			addTierAura(firstVisualPart)
			if definition.model == "Void" and externalAssetFolder then
				local voidSource = externalAssetFolder:FindFirstChild("Sanitized_VoidFistAura")
				local rightAura = voidSource
					and companionRuntime.PrepareVisualAsset(externalAssetFolder, voidSource)
					and voidSource:FindFirstChild("R", true)
				if rightAura then
					local attachment = Instance.new("Attachment")
					attachment.Name = "Creator Store Storm Aura"
					attachment.Parent = firstVisualPart
					local copied = 0
					for _, descendant in ipairs(rightAura:GetDescendants()) do
						if descendant:IsA("ParticleEmitter") and copied < 8 then
							local emitter = descendant:Clone()
							emitter.Rate = math.clamp(emitter.Rate, 1, 10)
							emitter.Enabled = true
							emitter.Parent = attachment
							copied += 1
						end
					end
					model:SetAttribute("CreatorStoreAuraEmitters", copied)
				end
			end
			local visualPartCount = 0
			for _, descendant in ipairs(model:GetDescendants()) do
				if descendant:IsA("BasePart") then
					visualPartCount += 1
				end
			end
			model:SetAttribute("KnuckleCount", 4)
			model:SetAttribute("HasWristCuff", model:FindFirstChild("Tier Wrist Cuff", true) ~= nil)
			model:SetAttribute("HasBackhandPlate", true)
			model:SetAttribute("HasFoldedThumb", true)
			model:SetAttribute("HasEnergyCore", model:FindFirstChild("Hero Core Gem", true) ~= nil)
			model:SetAttribute("VisualPartCount", visualPartCount)
			model:SetAttribute("VisualPartBudget", 28)
			model:SetAttribute("WithinVisualPartBudget", visualPartCount <= 28)
			model:SetAttribute("Tier", definition.tier)
			model:SetAttribute("FistStyle", definition.style)
			model:SetAttribute("ItemVisualReady", true)
			model.Parent = character
			currentGauntlet = model
			currentTrail = trail
			return true
		end
		imported:Destroy()
	end

	local function weldedPart(name, size, color, material, shape, localCFrame)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Color = color
		part.Material = material
		part.Shape = shape or Enum.PartType.Block
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
		part.CFrame = hand.CFrame * localCFrame
		part.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = part
		weld.Part1 = hand
		weld.Parent = part
		return part
	end

	local palmSize = Vector3.new(hand.Size.X * 1.42, hand.Size.Y * 0.9, hand.Size.Z * 1.72) * scale
	local palmOffset = -hand.Size.Z * 0.62
	local proceduralWristY = hand.Size.Y * fallbackRigProfile.wristYScale
	local palm = weldedPart("Gauntlet Palm", palmSize, primary, definition.material, Enum.PartType.Ball, CFrame.new(0, proceduralWristY, palmOffset))
	palm:SetAttribute("FistShape", "ClosedPalm")
	local cuff = weldedPart("Gauntlet Tapered Cuff", Vector3.new(hand.Size.Y * 0.42, hand.Size.X * 1.38, hand.Size.Z * 1.42) * scale, primary:Lerp(Color3.new(0, 0, 0), 0.34), Enum.Material.Metal, Enum.PartType.Cylinder, CFrame.new(0, hand.Size.Y * fallbackRigProfile.cuffYScale, 0) * CFrame.Angles(0, 0, math.rad(90)))
	cuff:SetAttribute("FistShape", "WristCuff")
	local backPlate = weldedPart("Fist Backhand Plate", Vector3.new(palmSize.X * 0.82, palmSize.Y * 0.34, palmSize.Z * 0.72), primary:Lerp(accent, 0.18), Enum.Material.Metal, Enum.PartType.Ball, CFrame.new(0, proceduralWristY + palmSize.Y * 0.18, palmOffset + palmSize.Z * 0.28))
	backPlate:SetAttribute("FistShape", "BackhandPlate")
	for finger = 1, 4 do
		local x = (finger - 2.5) * palmSize.X * 0.215
		local knuckle = weldedPart("Closed Knuckle " .. finger, Vector3.new(palmSize.X * 0.26, palmSize.Y * 0.5, palmSize.Z * 0.38), primary:Lerp(accent, definition.tier >= 4 and 0.34 or 0.12), definition.tier >= 4 and Enum.Material.Metal or definition.material, Enum.PartType.Ball, CFrame.new(x, proceduralWristY + palmSize.Y * 0.3, palmOffset - palmSize.Z * 0.38))
		knuckle:SetAttribute("FistShape", "RoundedKnuckle")
	end
	local thumb = weldedPart("Closed Fist Thumb", Vector3.new(palmSize.X * 0.34, palmSize.Y * 0.5, palmSize.Z * 0.48), primary, definition.material, Enum.PartType.Ball, CFrame.new(palmSize.X * 0.5, proceduralWristY - palmSize.Y * 0.03, palmOffset - palmSize.Z * 0.18) * CFrame.Angles(0, 0, math.rad(-28)))
	thumb:SetAttribute("FistShape", "FoldedThumb")
	local core = weldedPart("Fist Energy Core", Vector3.new(palmSize.X * 0.3, palmSize.Y * 0.3, palmSize.Z * 0.18), accent, definition.tier >= 4 and Enum.Material.Neon or Enum.Material.Metal, Enum.PartType.Ball, CFrame.new(0, proceduralWristY + palmSize.Y * 0.2, palmOffset + palmSize.Z * 0.58))
	core:SetAttribute("FistShape", "EnergyCore")
	if definition.tier >= 4 then
		local light = Instance.new("PointLight")
		light.Color = accent
		light.Brightness = definition.tier == 5 and 1.3 or 0.9
		light.Range = 7
		light.Parent = core
	end
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, palm.Size.Y * 0.5, 0)
	a0.Parent = palm
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -palm.Size.Y * 0.5, 0)
	a1.Parent = palm
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(accent, primary:Lerp(Color3.new(1, 1, 1), 0.35))
	trail.Lifetime = 0.16
	trail.Enabled = false
	trail.Parent = palm
	addTierAura(palm)
	model:SetAttribute("AlignmentStandard", fallbackRigProfile.name)
	model:SetAttribute("GripProfile", "ProceduralWristAligned")
	model:SetAttribute("WristAttachmentBounded", true)
	model:SetAttribute("FaceOcclusionSafe", scale <= 1.25)
	model:SetAttribute("Tier", definition.tier)
	model:SetAttribute("FistStyle", definition.style)
	model:SetAttribute("ItemVisualReady", true)
	model.Parent = character
	currentGauntlet = model
	currentTrail = trail
	return true
end

function companionRuntime.BuildHeroGauntlet(fistName)
	if shared.PunchWallHiddenFistHand and shared.PunchWallHiddenFistHand.Parent then
		shared.PunchWallHiddenFistHand.LocalTransparencyModifier = 0
		shared.PunchWallHiddenFistHand.Transparency = shared.PunchWallHiddenHandTransparency or 0
	end
	shared.PunchWallHiddenFistHand = nil
	shared.PunchWallHiddenHandTransparency = nil
	if currentGauntlet then currentGauntlet:Destroy() end
	currentGauntlet = nil
	currentTrail = nil

	local character = player.Character
	local hand = character and (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm"))
	if not hand or not hand:IsA("BasePart") then return false end
	local definition = GameConfig.FistDefinition(fistName)
	local spec = FistVisualBuilder.GetHeroGauntletSpec(hand, definition)
	local presentation = spec.presentation
	local primary = definition.color
	local accent = definition.accent or primary:Lerp(Color3.new(1, 1, 1), 0.3)
	local shadow = primary:Lerp(Color3.new(0, 0, 0), 0.34)

	local model = Instance.new("Model")
	model.Name = "Equipped Kaiju Gauntlet"
	model:SetAttribute("ItemType", "Fist")
	model:SetAttribute("DisplayName", definition.displayName)
	model:SetAttribute("Tier", definition.tier)
	model:SetAttribute("FistStyle", definition.style)
	model:SetAttribute("ClosedFist", true)
	model:SetAttribute("VisualSystem", spec.version)
	model:SetAttribute("VisualSource", "ProceduralRuntime")
	model:SetAttribute("ImportedRuntimeSilhouette", false)
	model:SetAttribute("SilhouetteFamily", spec.version)
	model:SetAttribute("ArmorPattern", presentation.armorPattern)
	model:SetAttribute("ShopArtVariant", presentation.shopArtKey)
	model:SetAttribute("IconIdentity", presentation.iconIdentity)
	model:SetAttribute("FistVariantKey", presentation.variantKey)
	model:SetAttribute("SignatureFeature", presentation.signatureFeature)
	model:SetAttribute("CatalogMotif", presentation.catalogMotif)
	model:SetAttribute("CatalogMotifVersion", presentation.catalogMotifVersion)
	model:SetAttribute("ShopArtMatchedTier", definition.tier)
	model:SetAttribute("WholeHandHidden", false)
	model:SetAttribute("HandTransparencyPreserved", true)
	model.Parent = character

	local visualPartCount = 0
	local function weldedPart(name, size, color, material, shape, localCFrame, fistShape)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Color = color
		part.Material = material
		part.Shape = shape or Enum.PartType.Block
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
		part.CastShadow = true
		part.CFrame = hand.CFrame * localCFrame
		part:SetAttribute("FistShape", fistShape or name)
		part.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = part
		weld.Part1 = hand
		weld.Parent = part
		visualPartCount += 1
		return part
	end
	local function weldedWedge(name, size, color, material, localCFrame, fistShape)
		local part = Instance.new("WedgePart")
		part.Name = name
		part.Size = size
		part.Color = color
		part.Material = material
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
		part.CastShadow = true
		part.CFrame = hand.CFrame * localCFrame
		part:SetAttribute("FistShape", fistShape or name)
		part.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = part
		weld.Part1 = hand
		weld.Parent = part
		visualPartCount += 1
		return part
	end

	local palm = weldedPart(
		"Hero Gauntlet Palm Shell",
		spec.palmSize,
		primary,
		definition.material,
		Enum.PartType.Ball,
		spec.palmCFrame,
		"ClosedPalm"
	)
	local cuff = weldedPart(
		"Hero Gauntlet Wrist Cuff",
		spec.cuffSize,
		shadow,
		Enum.Material.Metal,
		Enum.PartType.Cylinder,
		spec.cuffCFrame,
		"WristCuff"
	)
	weldedPart(
		"Hero Gauntlet Wrist Bridge",
		Vector3.new(spec.palmSize.X * 0.9, spec.unit * 0.42, spec.palmSize.Z * 0.78),
		primary:Lerp(shadow, 0.22),
		Enum.Material.Metal,
		Enum.PartType.Block,
		spec.palmCFrame * CFrame.new(0, spec.palmSize.Y * 0.44, spec.palmSize.Z * 0.12),
		"WristBridge"
	)
	weldedPart(
		"Hero Gauntlet Backhand Plate",
		spec.backPlateSize,
		primary:Lerp(accent, 0.2),
		definition.tier >= 3 and Enum.Material.Metal or definition.material,
		Enum.PartType.Ball,
		spec.backPlateCFrame,
		"BackhandPlate"
	)

	for finger = 1, 4 do
		local x = (finger - 2.5) * spec.palmSize.X * 0.225
		weldedPart(
			"Hero Closed Knuckle " .. finger,
			spec.knuckleSize,
			finger % 2 == 0 and primary:Lerp(accent, 0.24) or primary,
			definition.tier >= 3 and Enum.Material.Metal or definition.material,
			Enum.PartType.Ball,
			CFrame.new(x, spec.knuckleY, spec.knuckleZ),
			"RoundedKnuckle"
		)
	end
	weldedPart(
		"Hero Folded Thumb",
		spec.thumbSize,
		primary:Lerp(accent, definition.tier >= 4 and 0.18 or 0.04),
		definition.material,
		Enum.PartType.Ball,
		spec.thumbCFrame,
		"FoldedThumb"
	)
	local core = weldedPart(
		"Hero Gauntlet Energy Core",
		spec.coreSize,
		accent,
		definition.tier >= 3 and Enum.Material.Neon or Enum.Material.Metal,
		Enum.PartType.Ball,
		spec.coreCFrame,
		"TierCore"
	)

	for plateIndex = 1, presentation.plateCount do
		local offset = plateIndex - (presentation.plateCount + 1) * 0.5
		weldedPart(
			("Hero %s Armor Plate %d"):format(presentation.armorPattern, plateIndex),
			Vector3.new(spec.palmSize.X * 0.14, spec.palmSize.Y * 0.18, spec.palmSize.Z * 0.5),
			plateIndex % 2 == 0 and accent or primary:Lerp(accent, 0.42),
			definition.tier >= 4 and Enum.Material.Neon or Enum.Material.Metal,
			Enum.PartType.Block,
			spec.backPlateCFrame * CFrame.new(offset * spec.palmSize.X * 0.18, 0.04, 0.04),
			"TierArmorPlate"
		)
	end
	for finIndex = 1, presentation.finCount do
		local side = finIndex == 1 and -1 or 1
		weldedWedge(
			"Hero Energy Fin " .. finIndex,
			Vector3.new(spec.unit * 0.22, spec.unit * 0.58, spec.unit * 0.52),
			accent,
			Enum.Material.Neon,
			spec.palmCFrame
				* CFrame.new(side * spec.palmSize.X * 0.62, spec.palmSize.Y * 0.12, spec.palmSize.Z * 0.22)
				* CFrame.Angles(0, math.rad(side * 14), math.rad(side * 18)),
			"TierEnergyFin"
		)
	end
	if presentation.armorPattern == "BoxingWrap" then
		for band = -1, 1, 2 do
			weldedPart(
				"Boxing Wrist Wrap " .. band,
				Vector3.new(spec.unit * 0.18, spec.unit * 1.2, spec.unit * 1.16),
				band == -1 and accent or Color3.fromRGB(236, 230, 213),
				Enum.Material.Fabric,
				Enum.PartType.Cylinder,
				spec.cuffCFrame * CFrame.new(band * spec.unit * 0.18, 0, 0),
				"BoxingWrapBand"
			)
		end
	elseif presentation.armorPattern == "RivetedIron" then
		for side = -1, 1, 2 do
			weldedPart(
				"Iron Backhand Rivet " .. side,
				Vector3.new(spec.unit * 0.14, spec.unit * 0.14, spec.unit * 0.12),
				accent,
				Enum.Material.Neon,
				Enum.PartType.Ball,
				spec.coreCFrame * CFrame.new(side * spec.palmSize.X * 0.28, 0, -spec.unit * 0.02),
				"ArmorRivet"
			)
		end
	elseif presentation.armorPattern == "SiegePlates"
		or presentation.armorPattern == "CelestialCrown" then
		for side = -1, 1, 2 do
			weldedWedge(
				"Siege Crown Plate " .. side,
				Vector3.new(spec.unit * 0.28, spec.unit * 0.5, spec.unit * 0.36),
				accent,
				Enum.Material.Metal,
				spec.backPlateCFrame
					* CFrame.new(side * spec.palmSize.X * 0.42, spec.palmSize.Y * 0.28, 0)
					* CFrame.Angles(0, 0, math.rad(side * 18)),
				"SiegeCrown"
			)
		end
	end

	local aura = Instance.new("ParticleEmitter")
	aura.Name = (definition.displayName or fistName) .. " Aura"
	aura.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	aura.Color = ColorSequence.new(primary, accent)
	aura.LightEmission = math.clamp(0.28 + definition.tier * 0.09, 0.35, 1)
	aura.Rate = math.min(18, 1.5 + definition.tier * 1.65)
	aura.Lifetime = NumberRange.new(0.22, 0.46)
	aura.Speed = NumberRange.new(0.16, 0.72)
	aura.Drag = 3
	aura.SpreadAngle = Vector2.new(180, 180)
	aura.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1 + definition.tier * 0.016),
		NumberSequenceKeypoint.new(1, 0),
	})
	aura.Parent = core
	model:SetAttribute("TierAura", aura.Name)
	model:SetAttribute("AuraRate", aura.Rate)
	if definition.tier >= 3 then
		local light = Instance.new("PointLight")
		light.Name = "Hero Gauntlet Core Light"
		light.Color = accent
		light.Brightness = 0.2 + definition.tier * 0.1
		light.Range = math.min(8, 2.8 + definition.tier * 0.62)
		light.Shadows = false
		light.Parent = core
	end
	if definition.tier >= 5 then
		local energy = aura:Clone()
		energy.Name = (definition.displayName or fistName) .. " Energy Arcs"
		energy.Color = ColorSequence.new(accent, Color3.new(1, 1, 1))
		energy.Rate = math.min(12, 2 + definition.tier)
		energy.Lifetime = NumberRange.new(0.14, 0.28)
		energy.Parent = core
		local highlight = Instance.new("Highlight")
		highlight.Name = "Hero Fist Tier Glow"
		highlight.Adornee = model
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.FillColor = primary
		highlight.OutlineColor = accent
		highlight.FillTransparency = 0.82
		highlight.OutlineTransparency = 0.28
		highlight.Parent = model
	end

	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(-palm.Size.X * 0.44, 0, 0)
	a0.Parent = palm
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(palm.Size.X * 0.44, 0, 0)
	a1.Parent = palm
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(accent, primary:Lerp(Color3.new(1, 1, 1), 0.35))
	trail.Lifetime = 0.16
	trail.Enabled = false
	trail.Parent = palm

	local boundsCFrame, boundsSize = model:GetBoundingBox()
	local maxPartCenterDistance = 0
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			maxPartCenterDistance = math.max(
				maxPartCenterDistance,
				(descendant.Position - hand.Position).Magnitude
			)
		end
	end
	local visualLargest = math.max(boundsSize.X, boundsSize.Y, boundsSize.Z)
	local visualToHandRatio = visualLargest / math.max(spec.unit, 0.01)
	local wristCenterOffset = (boundsCFrame.Position - hand.Position).Magnitude
	local wristBounded = wristCenterOffset <= spec.maxCenterOffset
		and maxPartCenterDistance <= spec.maxCenterOffset + spec.unit * 0.72
	local faceSafe = visualToHandRatio <= spec.maxVisualRatio + 0.12
		and maxPartCenterDistance <= spec.maxCenterOffset + spec.unit * 0.72
	model:SetAttribute("AlignmentStandard", spec.alignmentStandard)
	model:SetAttribute("GripProfile", spec.version .. ":" .. spec.rig)
	model:SetAttribute("GripAxis", "HandLocalNegativeZ")
	model:SetAttribute("VisualToHandRatio", visualToHandRatio)
	model:SetAttribute("WristCenterOffset", wristCenterOffset)
	model:SetAttribute("MaxPartCenterDistance", maxPartCenterDistance)
	model:SetAttribute("WristAttachmentBounded", wristBounded)
	model:SetAttribute("FaceOcclusionSafe", faceSafe)
	model:SetAttribute("HandCoverageRatioX", spec.palmSize.X / math.max(hand.Size.X, 0.01))
	model:SetAttribute("HandCoverageRatioZ", spec.palmSize.Z / math.max(hand.Size.Z, 0.01))
	model:SetAttribute("KnuckleCount", 4)
	model:SetAttribute("HasWristCuff", cuff ~= nil)
	model:SetAttribute("HasBackhandPlate", true)
	model:SetAttribute("HasFoldedThumb", true)
	model:SetAttribute("HasEnergyCore", true)
	model:SetAttribute("VisualPartCount", visualPartCount)
	model:SetAttribute("VisualPartBudget", 28)
	model:SetAttribute("WithinVisualPartBudget", visualPartCount <= 28)
	model:SetAttribute("VisualBoundsX", boundsSize.X)
	model:SetAttribute("VisualBoundsY", boundsSize.Y)
	model:SetAttribute("VisualBoundsZ", boundsSize.Z)

	currentGauntlet = model
	currentTrail = trail
	return true
end

local function buildHonorCosmetic(itemName)
	if currentHonorCosmetic then currentHonorCosmetic:Destroy() end
	currentHonorCosmetic = nil
	local definition = GameConfig.HonorItemDefinition(itemName)
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not definition or not rootPart then return end
	local model = Instance.new("Model")
	model.Name = "Equipped Honor Relic"
	model:SetAttribute("HonorItem", definition.id)
	model:SetAttribute("PowerBonus", definition.powerBonus)
	model:SetAttribute("MotionSuppressed", clientSettings.motion ~= true)
	model.Parent = character
	local anchor = Instance.new("Part")
	anchor.Name = "Honor Visual Anchor"
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.Massless = true
	anchor.CFrame = rootPart.CFrame
	anchor.Parent = model
	local anchorWeld = Instance.new("WeldConstraint")
	anchorWeld.Part0 = anchor
	anchorWeld.Part1 = rootPart
	anchorWeld.Parent = anchor
	if definition.visual == "Trail" then
		local top = Instance.new("Attachment")
		top.Position = Vector3.new(0, 1.8, 0.55)
		top.Parent = anchor
		local bottom = Instance.new("Attachment")
		bottom.Position = Vector3.new(0, -1.8, 0.55)
		bottom.Parent = anchor
		local trail = Instance.new("Trail")
		trail.Attachment0 = top
		trail.Attachment1 = bottom
		trail.Color = ColorSequence.new(Color3.new(1, 1, 1), definition.color)
		trail.LightEmission = 0.65
		trail.Lifetime = 0.45
		trail.MinLength = 0.1
		trail.Enabled = clientSettings.motion == true
		trail.Parent = anchor
		if clientSettings.motion ~= true then
			local badge = Instance.new("Part")
			badge.Name = "Static Trail Badge"
			badge.Size = Vector3.new(0.22, 2.8, 0.18)
			badge.Color = definition.color
			badge.Material = Enum.Material.Neon
			badge.CanCollide, badge.CanTouch, badge.CanQuery, badge.Massless = false, false, false, true
			badge.CFrame = rootPart.CFrame * CFrame.new(0, 0, 0.82)
			badge.Parent = model
			local weld = Instance.new("WeldConstraint")
			weld.Part0, weld.Part1, weld.Parent = badge, rootPart, badge
		end
	elseif definition.visual == "Storm" then
		local attachment = Instance.new("Attachment")
		attachment.Parent = anchor
		local external = ReplicatedStorage:FindFirstChild("PunchWallExternalAssets")
		local source = external and external:FindFirstChild("Sanitized_VoidFistAura")
		local auraPart = source
			and companionRuntime.PrepareVisualAsset(external, source)
			and source:FindFirstChild("R", true)
		local copied = 0
		if auraPart then
			for _, descendant in ipairs(auraPart:GetDescendants()) do
				if descendant:IsA("ParticleEmitter") and copied < 8 then
					local emitter = descendant:Clone()
					emitter.Rate = math.clamp(emitter.Rate, 1, 8)
					emitter.Lifetime = NumberRange.new(math.min(emitter.Lifetime.Min, 0.7), math.min(emitter.Lifetime.Max, 1.1))
					emitter.Enabled = clientSettings.motion == true
					emitter.Parent = attachment
					copied += 1
				end
			end
		end
		if copied == 0 then
			local aura = Instance.new("ParticleEmitter")
			aura.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			aura.Color = ColorSequence.new(definition.color, Color3.new(1, 1, 1))
			aura.Rate = 14
			aura.Lifetime = NumberRange.new(0.35, 0.7)
			aura.Speed = NumberRange.new(0.5, 1.4)
			aura.SpreadAngle = Vector2.new(180, 180)
			aura.Enabled = clientSettings.motion == true
			aura.Parent = attachment
		end
		if clientSettings.motion ~= true then
			local core = Instance.new("Part")
			core.Name = "Static Storm Core"
			core.Shape = Enum.PartType.Ball
			core.Size = Vector3.new(0.72, 0.72, 0.72)
			core.Color = definition.color
			core.Material = Enum.Material.Neon
			core.CanCollide, core.CanTouch, core.CanQuery, core.Massless = false, false, false, true
			core.CFrame = rootPart.CFrame * CFrame.new(0, 0.65, 0.85)
			core.Parent = model
			local weld = Instance.new("WeldConstraint")
			weld.Part0, weld.Part1, weld.Parent = core, rootPart, core
		end
	elseif definition.visual == "Relic" then
		local core = Instance.new("Part")
		core.Name = "Relic Sidekick Core"
		core.Shape = Enum.PartType.Ball
		core.Size = Vector3.new(1.15, 1.15, 1.15)
		core.Color = definition.color
		core.Material = Enum.Material.Neon
		core.CanCollide = false
		core.CanTouch = false
		core.CanQuery = false
		core.Massless = true
		core.CFrame = rootPart.CFrame * CFrame.new(1.55, 0.5, 0.8)
		core.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = core
		weld.Part1 = rootPart
		weld.Parent = core
		local light = Instance.new("PointLight")
		light.Color = definition.color
		light.Brightness = clientSettings.motion == true and 1.2 or 0.35
		light.Range = clientSettings.motion == true and 8 or 4
		light.Parent = core
	elseif definition.visual == "Crown" then
		local head = character:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			for index = -2, 2 do
				local spike = Instance.new("WedgePart")
				spike.Name = "Honor Crown Spike"
				spike.Size = Vector3.new(0.32, 0.85 + (2 - math.abs(index)) * 0.18, 0.32)
				spike.Color = definition.color
				spike.Material = Enum.Material.Neon
				spike.CanCollide = false
				spike.CanTouch = false
				spike.CanQuery = false
				spike.Massless = true
				spike.CFrame = head.CFrame * CFrame.new(index * 0.32, 0.82, 0)
				spike.Parent = model
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = spike
				weld.Part1 = head
				weld.Parent = spike
			end
		end
	end
	currentHonorCosmetic = model
end

shared.PunchWallRefreshHonorMotion = function()
	buildHonorCosmetic(latestStats.EquippedHonorItem)
end

refreshCharacterVisuals = function()
	local equippedPets = decodeJSON(latestStats.EquippedPetsJSON, {})
	local signature = tostring(latestStats.EquippedFist or "Starter Glove")
		.. "|" .. table.concat(equippedPets, ",")
		.. "|" .. tostring(latestStats.EquippedHonorItem or "None")
		.. "|" .. tostring(player.Character)
	if signature == visualSignature and currentGauntlet and currentGauntlet.Parent then return end
	if not companionRuntime.BuildItemMatchedGauntlet(latestStats.EquippedFist or "Starter Glove") then
		visualSignature = ""
		companionRuntime.ScheduleVisualRetry()
		return
	end
	companionRuntime.CancelVisualRetry("BuildSucceeded")
	visualSignature = signature
	buildHonorCosmetic(latestStats.EquippedHonorItem)
	companionsFolder:ClearAllChildren()
	companionModels = {}
	local premiumCount = 0
	local premiumParityCount = 0
	for index, petName in ipairs(equippedPets) do
		local petNameOnly = GameConfig.ParsePetToken(petName)
		local definition = GameConfig.PetDefinition(petNameOnly)
		local companion = buildCompanion(petName, index)
		if definition and definition.rarity == "Premium" then
			premiumCount += 1
			if companion and companion:GetAttribute("PremiumVisualParity") == true then
				premiumParityCount += 1
			end
		end
	end
	gui:SetAttribute("CompanionMotionSystem", companionMotionVersion)
	gui:SetAttribute("CompanionCameraPolicy", companionRuntime.cameraPolicy)
	gui:SetAttribute("CompanionFormationPolicy", companionRuntime.formationPolicy)
	gui:SetAttribute("CompanionPerPetScreenAreaBudget", companionRuntime.perPetScreenAreaBudget)
	gui:SetAttribute("CompanionCombinedScreenAreaBudget", companionRuntime.combinedScreenAreaBudget)
	gui:SetAttribute("PremiumCompanionCount", premiumCount)
	gui:SetAttribute("PremiumPetVisualParity", premiumCount == premiumParityCount)
end

-- Heartbeat drives normal gameplay; a scheduler loop keeps the key poses moving
-- when Studio or a low-end client throttles frame callbacks.
local punchMotionState
local updatePunchMotion
local activePunchCamera
local lastPunchMotionAt = 0
local lastPunchActionAt = 0

local function findRigMotor(character, motorNames, part1Names)
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("Motor6D") or descendant:IsA("AnimationConstraint") then
			if table.find(motorNames, descendant.Name) then return descendant end
			local connectedPart = descendant:IsA("Motor6D") and descendant.Part1
				or (descendant:IsA("AnimationConstraint") and descendant.Attachment1 and descendant.Attachment1.Parent)
			if connectedPart and table.find(part1Names, connectedPart.Name) then return descendant end
		end
	end
	return nil
end

local function punchPose(windup, strike, progress)
	if progress < 0.28 then
		return CFrame.new():Lerp(windup, math.sin((progress / 0.28) * math.pi * 0.5))
	elseif progress < 0.46 then
		local alpha = (progress - 0.28) / 0.18
		alpha = 1 - (1 - alpha) ^ 3
		return windup:Lerp(strike, alpha)
	elseif progress < 0.66 then
		return strike
	end
	local alpha = math.clamp((progress - 0.66) / 0.34, 0, 1)
	alpha = alpha * alpha * (3 - 2 * alpha)
	return strike:Lerp(CFrame.new(), alpha)
end

performPunchAnimation = function(directionName)
	local now = os.clock()
	local interval = tonumber(gui:GetAttribute("PunchAttackInterval")) or 1
	if now - lastPunchMotionAt < interval then return false end
	lastPunchMotionAt = now
	gui:SetAttribute("CharacterPunchAppliedAngle", 0)
	gui:SetAttribute("CharacterPunchAppliedOffset", 0)
	gui:SetAttribute("CharacterPunchAppliedMaxAngle", 0)
	gui:SetAttribute("CharacterPunchAppliedMaxOffset", 0)
	if currentTrail then
		local trailForPunch = currentTrail
		trailForPunch.Enabled = false
		if clientSettings.motion then
			gui:SetAttribute("ReducedMotionTrailSuppressed", false)
			task.delay(0.16, function()
				if trailForPunch and trailForPunch.Parent then trailForPunch.Enabled = true end
			end)
			task.delay(0.4, function()
				if trailForPunch and trailForPunch.Parent then trailForPunch.Enabled = false end
			end)
		else
			gui:SetAttribute("ReducedMotionTrailSuppressed", true)
		end
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid then return false end
	directionName = tostring(directionName or "Forward")
	if latestStats.TrainingActive ~= 1 then humanoid.AutoRotate = true end
	if not clientSettings.motion then
		if updatePunchMotion then updatePunchMotion() end
		gui:SetAttribute("CharacterPunchMotionActive", false)
		gui:SetAttribute("CharacterPunchMotionSuppressed", true)
		gui:SetAttribute("CharacterPunchReducedMotion", true)
		gui:SetAttribute("CharacterPunchRig", humanoid.RigType == Enum.HumanoidRigType.R15 and "R15" or "R6")
		gui:SetAttribute("PunchMotionPhase", "StaticFeedback")
		gui:SetAttribute("PunchContactAt", now)
		gui:SetAttribute("CharacterPunchCount", (gui:GetAttribute("CharacterPunchCount") or 0) + 1)
		task.delay(0.12, function()
			if not clientSettings.motion and not punchMotionState then
				gui:SetAttribute("PunchMotionPhase", "Idle")
			end
		end)
		return true
	end
	local rightShoulder = findRigMotor(character, { "RightShoulder", "Right Shoulder" }, { "RightUpperArm", "Right Arm" })
	if not rightShoulder then return false end
	local leftShoulder = findRigMotor(character, { "LeftShoulder", "Left Shoulder" }, { "LeftUpperArm", "Left Arm" })
	local waist = findRigMotor(character, { "Waist", "RootJoint", "Root Joint" }, { "UpperTorso", "Torso" })
	local neck = findRigMotor(character, { "Neck" }, { "Head" })
	local rightHip = findRigMotor(character, { "RightHip", "Right Hip" }, { "RightUpperLeg", "Right Leg" })
	local leftHip = findRigMotor(character, { "LeftHip", "Left Hip" }, { "LeftUpperLeg", "Left Leg" })
	punchMotionState = {
		startedAt = now,
		duration = 0.72,
		rightShoulder = rightShoulder,
		leftShoulder = leftShoulder,
		waist = waist,
		neck = neck,
		rightHip = rightHip,
		leftHip = leftHip,
		direction = directionName,
		phase = "Windup",
	}
	gui:SetAttribute("CharacterPunchMotionActive", true)
	gui:SetAttribute("CharacterPunchMotionSuppressed", false)
	gui:SetAttribute("CharacterPunchReducedMotion", not clientSettings.motion)
	gui:SetAttribute("CharacterPunchRig", humanoid.RigType == Enum.HumanoidRigType.R15 and "R15" or "R6")
	gui:SetAttribute("PunchMotionPhase", "Windup")
	gui:SetAttribute("PunchContactAt", now + 0.2)
	gui:SetAttribute("CharacterPunchCount", (gui:GetAttribute("CharacterPunchCount") or 0) + 1)
	return true
end

do
local trainingAnimationGeneration = 0
local trainingAnimationActive = nil
local trainingAnimationLoopStartCount = 0
shared.PunchWallSetTrainingAnimation = function(active)
	active = active == true
	local station = GameConfig.TrainingStation(latestStats.TrainingStationId)
		or GameConfig.TrainingStation(GameConfig.Training.DefaultStationId)
	if shared.PunchWallTrainingLabel and station then
		shared.PunchWallTrainingLabel.Text = ("%s\n+%s POWER / SEC"):format(
			string.upper(station.hudName or station.displayName),
			formatNumber(station.gain)
		)
	end
	gui:SetAttribute("ActiveTrainingStationId", station and station.id or "")
	gui:SetAttribute("ActiveTrainingPowerPerSecond", station and station.gain or 0)
	if gui:GetAttribute("ContinuousTrainingAnimation") ~= active then
		gui:SetAttribute("ContinuousTrainingAnimation", active)
	end
	if shared.PunchWallTrainingOverlay and shared.PunchWallTrainingOverlay.Visible ~= active then
		shared.PunchWallTrainingOverlay.Visible = active
	end
	if trainingAnimationActive == active then
		return false
	end
	trainingAnimationActive = active
	trainingAnimationGeneration += 1
	local generation = trainingAnimationGeneration
	gui:SetAttribute("TrainingAnimationGeneration", trainingAnimationGeneration)
	gui:SetAttribute("TrainingAnimationDesiredState", active)
	if not active then return true end
	trainingAnimationLoopStartCount += 1
	gui:SetAttribute("TrainingAnimationLoopStartCount", trainingAnimationLoopStartCount)
	task.spawn(function()
		while generation == trainingAnimationGeneration
			and trainingAnimationActive
			and latestStats.TrainingActive == 1
		do
			local character = player.Character
			local rootPart = character and character:FindFirstChild("HumanoidRootPart")
			local world = workspace:FindFirstChild("PunchWallRPG")
			local interactables = world and world:FindFirstChild("Interactables")
			local activeStation = GameConfig.TrainingStation(latestStats.TrainingStationId)
			local target = activeStation and interactables and interactables:FindFirstChild(activeStation.name)
			if rootPart and target and (rootPart.Position - target.Position).Magnitude <= 18 then
				performPunchAnimation()
				gui:SetAttribute("LastTrainingAnimationAt", os.clock())
				gui:SetAttribute("TrainingAnimationTarget", activeStation.id)
			end
			task.wait(1)
		end
	end)
	return true
end
end

local function beginPunchCamera(now)
	local camera = workspace.CurrentCamera
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not camera or not root then return false end
	local motionState = punchMotionState
	if not motionState then return false end
	local originalType = camera.CameraType
	if originalType == Enum.CameraType.Scriptable then originalType = Enum.CameraType.Custom end
	activePunchCamera = {
		startedAt = now,
		-- Let the avatar lead for a readable beat, then catch up quickly enough
		-- that intact tunnel layers do not sit between the camera and character.
		delay = 0.08,
		followSpeed = 48,
		maximumFollowSpeed = 96,
		maximumLead = 4,
		followSharpness = 12,
		settleDistance = 0.2,
		startPosition = root.Position,
		baseCFrame = camera.CFrame,
		baseFocus = camera.Focus,
		translation = Vector3.zero,
		cameraType = originalType,
		cameraSubject = camera.CameraSubject,
	}
	if shared.PunchWallCameraPositionBlocked
		and not shared.PunchWallCameraPositionBlocked(camera.CFrame.Position, character) then
		-- A previous punch or server teleport can leave a geometrically clear but
		-- spatially stale baseline behind. Always begin from the player's current
		-- orbit so a later safety fallback cannot jump back toward spawn.
		shared.PunchWallCameraBaselineCFrame = camera.CFrame
		shared.PunchWallCameraBaselineFocus = camera.Focus
		shared.PunchWallHeartbeatLastClearCFrame = camera.CFrame
		shared.PunchWallHeartbeatLastClearFocus = camera.Focus
	end
	-- Keep Roblox's player-controlled camera active. Our render-step layer only
	-- smooths translation, so there is no Scriptable -> Custom handoff that can
	-- teleport the camera when consecutive punches overlap.
	camera.CameraType = originalType
	gui:SetAttribute("PunchCameraFollowEnabled", true)
	gui:SetAttribute("PunchCameraFollowDelaySeconds", activePunchCamera.delay)
	gui:SetAttribute("PunchCameraLeadLimitStuds", activePunchCamera.maximumLead)
	gui:SetAttribute("PunchCameraFollowPeakStuds", 0)
	gui:SetAttribute("PunchCameraFollowActive", true)
	gui:SetAttribute("PunchCameraGeometryHoldSettled", false)
	gui:SetAttribute("PunchCameraScriptableActive", false)
	gui:SetAttribute("PunchCameraMode", "DetachedTranslationFollow")
	gui:SetAttribute("PunchCameraAutoFocus", false)
	gui:SetAttribute("LastPunchCameraFollowAt", now)
	return true
end

local function tryPunchAction(directionName)
	directionName = tostring(directionName or "Forward")
	local now = os.clock()
	local interval = tonumber(gui:GetAttribute("PunchAttackInterval")) or 1
	if now - lastPunchActionAt < interval then
		gui:SetAttribute("PunchActionCooldownBlocked", true)
		return false
	end
	lastPunchActionAt = now
	gui:SetAttribute("PunchActionCooldownBlocked", false)
	gui:SetAttribute("LastPunchActionAt", now)
	performPunchAnimation(directionName)
	if clientSettings.motion then
		beginPunchCamera(now)
	else
		gui:SetAttribute("PunchCameraFollowEnabled", false)
		gui:SetAttribute("PunchCameraFollowActive", false)
		gui:SetAttribute("PunchCameraScriptableActive", false)
	end
	actionRemote:FireServer({ action = "Punch", value = directionName })
	return true
end

updatePunchMotion = function()
	local state = punchMotionState
	if not state then return end
	if not clientSettings.motion then
		if state.rightShoulder and state.rightShoulder.Parent then state.rightShoulder.Transform = CFrame.new() end
		if state.leftShoulder and state.leftShoulder.Parent then state.leftShoulder.Transform = CFrame.new() end
		if state.waist and state.waist.Parent then state.waist.Transform = CFrame.new() end
		if state.neck and state.neck.Parent then state.neck.Transform = CFrame.new() end
		if state.rightHip and state.rightHip.Parent then state.rightHip.Transform = CFrame.new() end
		if state.leftHip and state.leftHip.Parent then state.leftHip.Transform = CFrame.new() end
		state.animationFinished = true
		punchMotionState = nil
		gui:SetAttribute("CharacterPunchMotionActive", false)
		gui:SetAttribute("CharacterPunchMotionSuppressed", true)
		gui:SetAttribute("CharacterPunchReducedMotion", true)
		gui:SetAttribute("PunchMotionPhase", "Idle")
		gui:SetAttribute("CharacterPunchAppliedAngle", 0)
		gui:SetAttribute("CharacterPunchAppliedOffset", 0)
		return
	end
	local now = os.clock()
	local elapsed = now - state.startedAt
	local progress = math.clamp(elapsed / state.duration, 0, 1)
	local finishAfterLateContact = false
	if state.contactHoldUntil then
		if now < state.contactHoldUntil then
			progress = 0.5
		else
			state.contactHoldUntil = nil
		end
	elseif state.phase == "Windup" and progress >= 0.66 then
		-- A throttled client may skip the full strike pose. Hold the impact
		-- keyframe briefly so the punch still reads as a powerful action.
		state.contactHoldUntil = math.min(now + 0.14, state.startedAt + 0.96)
		progress = 0.5
		if state.contactHoldUntil <= now then
			finishAfterLateContact = true
		end
	end
	local rightWindup = CFrame.new(0.18, 0.14, 0.38) * CFrame.Angles(math.rad(42), math.rad(72), math.rad(42))
	local rightStrike = CFrame.new(0.08, -0.02, -1.65) * CFrame.Angles(math.rad(-118), math.rad(-8), math.rad(-6))
	local leftWindup = CFrame.new(-0.08, 0.08, -0.12) * CFrame.Angles(math.rad(-60), math.rad(-24), math.rad(-30))
	local leftStrike = CFrame.new(0, 0.04, -0.28) * CFrame.Angles(math.rad(-78), math.rad(22), math.rad(-30))
	local waistWindup = CFrame.new(0, -0.06, 0.18) * CFrame.Angles(math.rad(-10), math.rad(-48), math.rad(-9))
	local waistStrike = CFrame.new(0, -0.1, -0.56) * CFrame.Angles(math.rad(18), math.rad(46), math.rad(11))
	local neckWindup = CFrame.Angles(math.rad(4), math.rad(17), math.rad(3))
	local neckStrike = CFrame.Angles(math.rad(-8), math.rad(-16), math.rad(-4))
	local rightHipWindup = CFrame.new(0, -0.08, 0.14) * CFrame.Angles(math.rad(-16), math.rad(12), math.rad(7))
	local rightHipStrike = CFrame.new(0, 0, -0.28) * CFrame.Angles(math.rad(18), math.rad(-12), math.rad(-8))
	local leftHipWindup = CFrame.new(0, 0.02, -0.08) * CFrame.Angles(math.rad(10), math.rad(-10), math.rad(-5))
	local leftHipStrike = CFrame.new(0, -0.05, 0.18) * CFrame.Angles(math.rad(-12), math.rad(10), math.rad(6))
	if state.direction == "Up" then
		rightWindup = CFrame.new(0.2, -0.18, 0.42) * CFrame.Angles(math.rad(72), math.rad(68), math.rad(38))
		rightStrike = CFrame.new(0.08, 0.9, -1.18) * CFrame.Angles(math.rad(-154), math.rad(-6), math.rad(-7))
		leftStrike = CFrame.new(0, 0.36, -0.18) * CFrame.Angles(math.rad(-105), math.rad(18), math.rad(-28))
		waistStrike = CFrame.new(0, 0.18, -0.42) * CFrame.Angles(math.rad(-24), math.rad(42), math.rad(10))
		neckStrike = CFrame.Angles(math.rad(-19), math.rad(-14), math.rad(-3))
	elseif state.direction == "Down" then
		rightWindup = CFrame.new(0.18, 0.55, 0.4) * CFrame.Angles(math.rad(22), math.rad(74), math.rad(46))
		rightStrike = CFrame.new(0.06, -0.92, -1.12) * CFrame.Angles(math.rad(-76), math.rad(-10), math.rad(-5))
		leftStrike = CFrame.new(0, -0.34, -0.16) * CFrame.Angles(math.rad(-52), math.rad(20), math.rad(-24))
		waistStrike = CFrame.new(0, -0.28, -0.48) * CFrame.Angles(math.rad(31), math.rad(43), math.rad(12))
		neckStrike = CFrame.Angles(math.rad(18), math.rad(-14), math.rad(-4))
	end
	local rightPose = punchPose(rightWindup, rightStrike, progress)
	if state.rightShoulder.Parent then state.rightShoulder.Transform = rightPose end
	local rightX, rightY, rightZ = rightPose:ToOrientation()
	local appliedAngle = math.max(math.abs(rightX), math.abs(rightY), math.abs(rightZ))
	local appliedOffset = rightPose.Position.Magnitude
	gui:SetAttribute("CharacterPunchAppliedAngle", appliedAngle)
	gui:SetAttribute("CharacterPunchAppliedOffset", appliedOffset)
	gui:SetAttribute("CharacterPunchAppliedMaxAngle", math.max(gui:GetAttribute("CharacterPunchAppliedMaxAngle") or 0, appliedAngle))
	gui:SetAttribute("CharacterPunchAppliedMaxOffset", math.max(gui:GetAttribute("CharacterPunchAppliedMaxOffset") or 0, appliedOffset))
	if state.leftShoulder and state.leftShoulder.Parent then state.leftShoulder.Transform = punchPose(leftWindup, leftStrike, progress) end
	if state.waist and state.waist.Parent then state.waist.Transform = punchPose(waistWindup, waistStrike, progress) end
	if state.neck and state.neck.Parent then state.neck.Transform = punchPose(neckWindup, neckStrike, progress) end
	if state.rightHip and state.rightHip.Parent then state.rightHip.Transform = punchPose(rightHipWindup, rightHipStrike, progress) end
	if state.leftHip and state.leftHip.Parent then state.leftHip.Transform = punchPose(leftHipWindup, leftHipStrike, progress) end
	local nextPhase = progress < 0.28 and "Windup" or progress < 0.66 and "Contact" or "Recovery"
	if state.phase == "Windup" and nextPhase == "Recovery" then
		-- A throttled client can jump across the entire contact window in one
		-- simulation callback. Emit the semantic phase in order so VFX, audio,
		-- and automation observers still receive the impact beat.
		gui:SetAttribute("PunchMotionPhase", "Contact")
	end
	gui:SetAttribute("PunchMotionPhase", nextPhase)
	state.phase = nextPhase
	gui:SetAttribute("CharacterPunchMotionPeak", math.max(gui:GetAttribute("CharacterPunchMotionPeak") or 0, math.sin(progress * math.pi)))
	if finishAfterLateContact then
		gui:SetAttribute("PunchMotionPhase", "Recovery")
		state.phase = "Recovery"
	end
	if progress >= 1 or finishAfterLateContact then
		if state.rightShoulder and state.rightShoulder.Parent then state.rightShoulder.Transform = CFrame.new() end
		if state.leftShoulder and state.leftShoulder.Parent then state.leftShoulder.Transform = CFrame.new() end
		if state.waist and state.waist.Parent then state.waist.Transform = CFrame.new() end
		if state.neck and state.neck.Parent then state.neck.Transform = CFrame.new() end
		if state.rightHip and state.rightHip.Parent then state.rightHip.Transform = CFrame.new() end
		if state.leftHip and state.leftHip.Parent then state.leftHip.Transform = CFrame.new() end
		state.animationFinished = true
		punchMotionState = nil
		gui:SetAttribute("CharacterPunchMotionActive", false)
		gui:SetAttribute("PunchMotionPhase", "Idle")
		gui:SetAttribute("CharacterPunchAppliedAngle", 0)
		gui:SetAttribute("CharacterPunchAppliedOffset", 0)
	end
end

-- Animator updates joint transforms during PreAnimation. PreSimulation is the
-- single deterministic owner of the authored punch pose; a second Heartbeat or
-- per-punch scheduler would advance and write the same state multiple times.
RunService.PreSimulation:Connect(updatePunchMotion)
gui:SetAttribute("CharacterPunchRenderOverride", true)
gui:SetAttribute("CharacterPunchSimulationOverride", true)

shared.PunchWallCameraPositionBlocked = function(position, character)
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	-- Debris is ignored for line-of-sight readability, but not here: an opaque
	-- chunk intersecting the camera still fills the whole screen.
	overlap.FilterDescendantsInstances = { character, localDebrisFolder, companionsFolder }
	overlap.MaxParts = 32
	for _, part in ipairs(workspace:GetPartBoundsInBox(CFrame.new(position), Vector3.new(0.55, 0.55, 0.55), overlap)) do
		if part:IsA("BasePart") and part.CanCollide and part.Transparency < 0.95 then return true end
	end
	return false
end

local function cameraCharacterTarget(character)
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if rootPart and rootPart:IsA("BasePart") then
		return rootPart.Position + Vector3.new(0, 1.5, 0)
	end
	local head = character and character:FindFirstChild("Head")
	return head and head:IsA("BasePart") and head.Position or nil
end

local function cameraCharacterTargets(character)
	local targets = {}
	local head = character and character:FindFirstChild("Head")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if head and head:IsA("BasePart") then table.insert(targets, head.Position) end
	if rootPart and rootPart:IsA("BasePart") then
		table.insert(targets, rootPart.Position + Vector3.new(0, 1.15, 0))
	end
	return targets
end

local function cameraLineOfSightBlocked(position, targetPosition, character)
	if not targetPosition then return false, nil end
	local direction = targetPosition - position
	if direction.Magnitude <= 0.5 then return false, nil end
	local gameRoot = workspace:FindFirstChild("PunchWallRPG")
	local physicsDebris = gameRoot and gameRoot:FindFirstChild("Depth Physics Debris")
	local ignored = { character, localDebrisFolder, companionsFolder, physicsDebris }
	local raycast = RaycastParams.new()
	raycast.FilterType = Enum.RaycastFilterType.Exclude
	raycast.IgnoreWater = true
	local origin = position
	for _ = 1, 8 do
		direction = targetPosition - origin
		if direction.Magnitude <= 0.2 then return false, nil end
		raycast.FilterDescendantsInstances = ignored
		local result = workspace:Raycast(origin, direction, raycast)
		if not result then return false, nil end
		local instance = result.Instance
		if instance:IsA("BasePart") and instance.Transparency < 0.95 then
			return true, instance
		end
		table.insert(ignored, instance)
		origin = result.Position + direction.Unit * 0.08
	end
	return false, nil
end

local function cameraPoseBlocked(cameraCFrame, character)
	if shared.PunchWallCameraPositionBlocked(cameraCFrame.Position, character) then
		return true, nil
	end
	for _, targetPosition in ipairs(cameraCharacterTargets(character)) do
		local blocked, blockingPart = cameraLineOfSightBlocked(cameraCFrame.Position, targetPosition, character)
		if blocked then return true, blockingPart end
	end
	return false, nil
end

local function resolveClearCameraPose(desiredCFrame, desiredFocus, character)
	local targetPosition = cameraCharacterTarget(character)
	if not targetPosition then return desiredCFrame, desiredFocus, Vector3.zero, nil end
	local initiallyBlocked, firstBlockingPart = cameraPoseBlocked(desiredCFrame, character)
	if not initiallyBlocked then
		-- Most frames should remain exactly as Roblox's camera controller (or the
		-- delayed punch follower) requested them. Reprojecting every clear frame
		-- onto a newly inferred orbit is what caused rare zoom drift.
		return desiredCFrame, desiredFocus, Vector3.zero, nil
	end
	local right = desiredCFrame.RightVector
	local orbitOffset = desiredCFrame.Position - targetPosition
	local flattenY = -orbitOffset.Y
	local orbitDistance = orbitOffset.Magnitude
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if rootPart and rootPart:IsA("BasePart") and orbitDistance > 0.5 then
		local look = rootPart.CFrame.LookVector
		local horizontalLook = Vector3.new(look.X, 0, look.Z)
		if horizontalLook.Magnitude > 0.01 then
			-- The destructible route is opened around the avatar's body line.
			-- When a high user orbit meets the intact upper rows, temporarily
			-- center the camera in that opened route while retaining the exact
			-- orbit radius and camera rotation.
			local candidatePosition = targetPosition - horizontalLook.Unit * orbitDistance
			local translation = candidatePosition - desiredCFrame.Position
			local candidateCFrame = desiredCFrame + translation
			local blocked, blockingPart = cameraPoseBlocked(candidateCFrame, character)
			firstBlockingPart = firstBlockingPart or blockingPart
			if not blocked then
				return candidateCFrame, desiredFocus + translation, translation, firstBlockingPart
			end
		end
	end
	local clearanceHints = {
		Vector3.new(0, flattenY, 0),
		Vector3.new(0, flattenY - 1.5, 0),
		Vector3.new(0, flattenY + 1.5, 0),
		right * 3 + Vector3.new(0, flattenY, 0),
		-right * 3 + Vector3.new(0, flattenY, 0),
		right * 6 + Vector3.new(0, flattenY, 0),
		-right * 6 + Vector3.new(0, flattenY, 0),
		Vector3.new(0, -1.5, 0),
		Vector3.new(0, -3, 0),
		Vector3.new(0, -4.5, 0),
		Vector3.new(0, -6, 0),
		right * 2,
		-right * 2,
		right * 4,
		-right * 4,
		right * 7,
		-right * 7,
		right * 9,
		-right * 9,
		right * 3 + Vector3.new(0, -2.5, 0),
		-right * 3 + Vector3.new(0, -2.5, 0),
		right * 5 + Vector3.new(0, -4.5, 0),
		-right * 5 + Vector3.new(0, -4.5, 0),
		right * 8 + Vector3.new(0, -3, 0),
		-right * 8 + Vector3.new(0, -3, 0),
		Vector3.new(0, 2, 0),
		Vector3.new(0, 4, 0),
	}
	for _, clearanceHint in ipairs(clearanceHints) do
		local hintedOffset = orbitOffset + clearanceHint
		local candidatePosition = desiredCFrame.Position
		if orbitDistance > 0.5 and hintedOffset.Magnitude > 0.1 then
			candidatePosition = targetPosition + hintedOffset.Unit * orbitDistance
		end
		local translation = candidatePosition - desiredCFrame.Position
		local candidateCFrame = desiredCFrame + translation
		local blocked, blockingPart = cameraPoseBlocked(candidateCFrame, character)
		firstBlockingPart = firstBlockingPart or blockingPart
		if not blocked then
			return candidateCFrame, desiredFocus + translation, translation, firstBlockingPart
		end
	end
	return nil, nil, nil, firstBlockingPart
end

shared.PunchWallCameraLineOfSightBlocked = cameraLineOfSightBlocked
shared.PunchWallResolveClearCameraPose = resolveClearCameraPose

local lastPunchCameraRenderAt = 0
local function updatePunchCameraFollow(deltaTime)
	local state = activePunchCamera
	if not state then return end
	local camera = workspace.CurrentCamera
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not camera or not root then
		if camera then
			camera.CameraType = state.cameraType
			camera.CameraSubject = state.cameraSubject
		end
		activePunchCamera = nil
		gui:SetAttribute("PunchCameraFollowActive", false)
		gui:SetAttribute("PunchCameraScriptableActive", false)
		return
	end
	local elapsed = os.clock() - state.startedAt
	local rootDelta = root.Position - state.startPosition
	local previousTranslation = state.translation
	local remaining = rootDelta - state.translation
	if elapsed >= state.delay or remaining.Magnitude > state.maximumLead then
		local alpha = 1 - math.exp(-state.followSharpness * math.min(deltaTime, 0.1))
		local step = remaining * alpha
		local followSpeed = state.followSpeed
		if remaining.Magnitude > state.maximumLead then
			followSpeed = math.min(state.maximumFollowSpeed, math.max(followSpeed, remaining.Magnitude * 4))
		end
		local maxStep = math.min(2.4, followSpeed * math.min(deltaTime, 0.1))
		if step.Magnitude > maxStep then step = step.Unit * maxStep end
		state.translation += step
	end
	local candidateCFrame = state.baseCFrame + state.translation
	local candidateFocus = state.baseFocus + state.translation
	local cameraBlocked = shared.PunchWallCameraPositionBlocked(candidateCFrame.Position, character)
	if cameraBlocked then
		state.translation = previousTranslation
		gui:SetAttribute("PunchCameraGeometryClamped", true)
		gui:SetAttribute("PunchCameraGeometryClampFrames", (gui:GetAttribute("PunchCameraGeometryClampFrames") or 0) + 1)
	else
		local previousCameraPosition = (state.baseCFrame + previousTranslation).Position
		local appliedStep = (candidateCFrame.Position - previousCameraPosition).Magnitude
		gui:SetAttribute("PunchCameraMaxAppliedStep", math.max(gui:GetAttribute("PunchCameraMaxAppliedStep") or 0, appliedStep))
		camera.CFrame = candidateCFrame
		camera.Focus = candidateFocus
		gui:SetAttribute("PunchCameraGeometryClamped", false)
	end
	local lag = (rootDelta - state.translation).Magnitude
	gui:SetAttribute("PunchCameraFollowPeakStuds", math.max(gui:GetAttribute("PunchCameraFollowPeakStuds") or 0, lag))
	if elapsed >= 0.72 and lag <= state.settleDistance and not cameraBlocked then
		camera.CFrame = state.baseCFrame + rootDelta
		camera.Focus = state.baseFocus + rootDelta
		camera.CameraSubject = state.cameraSubject
		camera.CameraType = state.cameraType
		activePunchCamera = nil
		gui:SetAttribute("PunchCameraFollowActive", false)
		gui:SetAttribute("PunchCameraScriptableActive", false)
		gui:SetAttribute("PunchCameraMode", "CustomPreserved")
	elseif elapsed >= 1.25 and cameraBlocked then
		-- The user's chosen camera height may intersect an intact tunnel ceiling.
		-- Finish at the last clear position instead of zooming, clipping, or
		-- accumulating a later catch-up jump.
		activePunchCamera = nil
		gui:SetAttribute("PunchCameraFollowActive", false)
		gui:SetAttribute("PunchCameraScriptableActive", false)
		gui:SetAttribute("PunchCameraGeometryHoldSettled", true)
		gui:SetAttribute("PunchCameraMode", "CustomPreserved")
	end
end

RunService:BindToRenderStep("PunchWallDelayedCameraFollow", Enum.RenderPriority.Camera.Value + 1, function(deltaTime)
	lastPunchCameraRenderAt = os.clock()
	updatePunchCameraFollow(deltaTime)
end)

shared.PunchWallStandaloneWindows.RebirthPanel:GetPropertyChangedSignal("Visible"):Connect(function()
	if shared.PunchWallStandaloneWindows.RebirthPanel.Visible then shared.PunchWallStandaloneWindows.Refresh() end
	applyReferenceHUDState(true)
end)
shared.PunchWallStandaloneWindows.SettingsPanel:GetPropertyChangedSignal("Visible"):Connect(function()
	if shared.PunchWallStandaloneWindows.SettingsPanel.Visible then shared.PunchWallStandaloneWindows.Refresh() end
	applyReferenceHUDState(true)
end)

-- Studio automation and minimized clients can temporarily suspend rendering.
-- Keep the same bounded translation moving on Heartbeat only while no render
-- callback has run recently; active gameplay continues to use RenderStep.
RunService.Heartbeat:Connect(function(deltaTime)
	-- Low-FPS Studio/device-simulator frames can be 0.1-0.25 seconds apart.
	-- Treat rendering as suspended only after a wider grace period so Heartbeat
	-- never advances the same follow state a second time between slow frames.
	local renderSuspended = os.clock() - lastPunchCameraRenderAt > 0.35
	if activePunchCamera and renderSuspended then
		updatePunchCameraFollow(math.min(deltaTime, 1 / 30))
	end
	if renderSuspended then
		local camera = workspace.CurrentCamera
		local character = player.Character
		if camera and character then
			if camera.CameraType == Enum.CameraType.Scriptable and not activePunchCamera then
				gui:SetAttribute("PunchCameraScriptableBypass", true)
				return
			end
			gui:SetAttribute("PunchCameraScriptableBypass", false)
			local clearCFrame, clearFocus, clearance = resolveClearCameraPose(camera.CFrame, camera.Focus, character)
			if not clearCFrame then
				if shared.PunchWallHeartbeatLastClearCFrame and shared.PunchWallHeartbeatLastClearFocus then
					local fallbackCFrame = shared.PunchWallHeartbeatLastClearCFrame
					local fallbackFocus = shared.PunchWallHeartbeatLastClearFocus
					if cameraPoseBlocked(fallbackCFrame, character) then
						fallbackCFrame = shared.PunchWallCameraBaselineCFrame
						fallbackFocus = shared.PunchWallCameraBaselineFocus
					end
					if fallbackCFrame and fallbackFocus and not cameraPoseBlocked(fallbackCFrame, character) then
						camera.CFrame = fallbackCFrame
						camera.Focus = fallbackFocus
					end
				end
			else
				camera.CFrame = clearCFrame
				camera.Focus = clearFocus
				shared.PunchWallHeartbeatLastClearCFrame = clearCFrame
				shared.PunchWallHeartbeatLastClearFocus = clearFocus
				gui:SetAttribute("PunchCameraLineOfSightAdjusted", clearance.Magnitude > 0.01)
				gui:SetAttribute("PunchCameraClearanceY", clearance.Y)
			end
		end
	end
end)

-- The default camera can cross the wall ceiling while a high-power punch moves
-- the character several layers in one burst. Preserve the player's rotation and
-- zoom, but hold translation at the latest clear point until the requested path
-- is physically open. This avoids both camera clipping and corrective snaps.
shared.PunchWallInstallCameraGeometryGuard = function()
	local lastClearCameraCFrame
	local lastClearCameraFocus
	local cameraGeometryClampFrames = 0
	local recoveringFromGeometryClamp = false
	local recoveringFromFollowHandoff = false
	local wasActiveFollow = false
	local lastRootPosition
	local userOrbitDistance
	local orbitCharacter
	local pendingOrbitDelta = 0
	local previousPinchScale
	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			pendingOrbitDelta -= input.Position.Z * 2
		end
	end)
	UserInputService.TouchPinch:Connect(function(_, scale, _, state)
		if state == Enum.UserInputState.Begin then
			previousPinchScale = scale
		elseif state == Enum.UserInputState.Change and userOrbitDistance and previousPinchScale then
			local ratio = math.max(0.1, scale / math.max(0.1, previousPinchScale))
			userOrbitDistance = math.clamp(userOrbitDistance / ratio, 2, 80)
			previousPinchScale = scale
			gui:SetAttribute("PunchCameraUserOrbitDistance", userOrbitDistance)
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			previousPinchScale = nil
		end
	end)
	local function updateCameraGeometryGuard(deltaTime)
		local camera = workspace.CurrentCamera
		local character = player.Character
		if not camera or not character then return end
		if orbitCharacter ~= character then
			orbitCharacter = character
			userOrbitDistance = nil
			lastRootPosition = nil
		end
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if camera.CameraType == Enum.CameraType.Scriptable and not activePunchCamera then
			lastRootPosition = rootPart and rootPart.Position or lastRootPosition
			gui:SetAttribute("PunchCameraScriptableBypass", true)
			return
		end
		gui:SetAttribute("PunchCameraScriptableBypass", false)
		local desiredCFrame = camera.CFrame
		local desiredFocus = camera.Focus
		local desiredPosition = desiredCFrame.Position
		local activeFollow = gui:GetAttribute("PunchCameraFollowActive") == true
		local targetPosition = cameraCharacterTarget(character)
		if userOrbitDistance and math.abs(pendingOrbitDelta) > 0.001 then
			userOrbitDistance = math.clamp(userOrbitDistance + pendingOrbitDelta, 2, 80)
			pendingOrbitDelta = 0
			gui:SetAttribute("PunchCameraUserOrbitDistance", userOrbitDistance)
		end
		if targetPosition
			and not userOrbitDistance
			and not activeFollow
			and not wasActiveFollow
			and not recoveringFromGeometryClamp
			and not recoveringFromFollowHandoff
			and os.clock() - lastPunchActionAt > 1.5
			and not cameraPoseBlocked(desiredCFrame, character) then
			local requestedOrbit = (desiredPosition - targetPosition).Magnitude
			if requestedOrbit >= 2 and requestedOrbit <= 80 then
				userOrbitDistance = requestedOrbit
				gui:SetAttribute("PunchCameraUserOrbitDistance", requestedOrbit)
			end
		end
		if targetPosition
			and userOrbitDistance
			and not activeFollow
			and not wasActiveFollow
			and not recoveringFromGeometryClamp
			and not recoveringFromFollowHandoff then
			local orbitOffset = desiredPosition - targetPosition
			if orbitOffset.Magnitude > 0.1
				and math.abs(orbitOffset.Magnitude - userOrbitDistance) > 0.08 then
				local orbitPosition = targetPosition + orbitOffset.Unit * userOrbitDistance
				local orbitTranslation = orbitPosition - desiredPosition
				local orbitCFrame = desiredCFrame + orbitTranslation
				local orbitFocus = desiredFocus + orbitTranslation
				local safeCFrame, safeFocus = resolveClearCameraPose(orbitCFrame, orbitFocus, character)
				if safeCFrame and safeFocus then
					desiredCFrame = safeCFrame
					desiredFocus = safeFocus
					desiredPosition = safeCFrame.Position
					gui:SetAttribute("PunchCameraOcclusionZoomPrevented", true)
				end
			else
				gui:SetAttribute("PunchCameraOcclusionZoomPrevented", false)
			end
		end
		if rootPart and lastRootPosition then
			local rootDisplacement = rootPart.Position - lastRootPosition
			if rootDisplacement.Magnitude > 30 then
				local rebasedCFrame = lastClearCameraCFrame and (lastClearCameraCFrame + rootDisplacement) or desiredCFrame
				local rebasedFocus = lastClearCameraFocus and (lastClearCameraFocus + rootDisplacement) or desiredFocus
				local safeCFrame, safeFocus, clearance = resolveClearCameraPose(rebasedCFrame, rebasedFocus, character)
				if safeCFrame and safeFocus then
					camera.CFrame = safeCFrame
					camera.Focus = safeFocus
					lastClearCameraCFrame = safeCFrame
					lastClearCameraFocus = safeFocus
					shared.PunchWallHeartbeatLastClearCFrame = safeCFrame
					shared.PunchWallHeartbeatLastClearFocus = safeFocus
					recoveringFromGeometryClamp = false
					recoveringFromFollowHandoff = false
					gui:SetAttribute("PunchCameraRebasedAfterTeleport", true)
					gui:SetAttribute(
						"PunchCameraTeleportRebaseCount",
						(gui:GetAttribute("PunchCameraTeleportRebaseCount") or 0) + 1
					)
					gui:SetAttribute("PunchCameraLineOfSightAdjusted", clearance.Magnitude > 0.01)
					gui:SetAttribute("PunchCameraClearanceY", clearance.Y)
					lastRootPosition = rootPart.Position
					return
				end
				lastClearCameraCFrame = nil
				lastClearCameraFocus = nil
				shared.PunchWallHeartbeatLastClearCFrame = nil
				shared.PunchWallHeartbeatLastClearFocus = nil
			end
		end
		lastRootPosition = rootPart and rootPart.Position or lastRootPosition
		local resolvedCFrame, resolvedFocus, clearance, blockingPart =
			resolveClearCameraPose(desiredCFrame, desiredFocus, character)
		if resolvedCFrame and resolvedFocus then
			desiredCFrame = resolvedCFrame
			desiredFocus = resolvedFocus
			desiredPosition = resolvedCFrame.Position
			gui:SetAttribute("PunchCameraLineOfSightAdjusted", clearance.Magnitude > 0.01)
			gui:SetAttribute("PunchCameraClearanceY", clearance.Y)
			gui:SetAttribute("PunchCameraLastBlockingPart", blockingPart and blockingPart.Name or "")
		end
		if wasActiveFollow and not activeFollow then
			recoveringFromFollowHandoff = true
			gui:SetAttribute("PunchCameraHandoffActive", true)
		end
		wasActiveFollow = activeFollow
		if targetPosition
			and userOrbitDistance
			and not activeFollow
			and (recoveringFromGeometryClamp or recoveringFromFollowHandoff) then
			local orbitOffset = desiredPosition - targetPosition
			if orbitOffset.Magnitude > 0.1 then
				local orbitPosition = targetPosition + orbitOffset.Unit * userOrbitDistance
				local orbitTranslation = orbitPosition - desiredPosition
				local orbitCFrame = desiredCFrame + orbitTranslation
				local orbitFocus = desiredFocus + orbitTranslation
				local safeCFrame, safeFocus, safeClearance, safeBlocker =
					resolveClearCameraPose(orbitCFrame, orbitFocus, character)
				if safeCFrame and safeFocus then
					resolvedCFrame = safeCFrame
					resolvedFocus = safeFocus
					clearance = safeClearance
					blockingPart = safeBlocker or blockingPart
					desiredCFrame = safeCFrame
					desiredFocus = safeFocus
					desiredPosition = safeCFrame.Position
				else
					resolvedCFrame = nil
					resolvedFocus = nil
				end
			end
		end
		if (activeFollow or recoveringFromGeometryClamp or recoveringFromFollowHandoff) and lastClearCameraCFrame then
			local displacement = desiredPosition - lastClearCameraCFrame.Position
			local maxStep = 24 * math.min(deltaTime, 0.1)
			if displacement.Magnitude > maxStep then
				local limitedPosition = lastClearCameraCFrame.Position + displacement.Unit * maxStep
				local translation = limitedPosition - desiredPosition
				desiredCFrame = desiredCFrame + translation
				desiredFocus = desiredFocus + translation
				desiredPosition = limitedPosition
			elseif recoveringFromGeometryClamp and not activeFollow then
				recoveringFromGeometryClamp = false
			end
			if recoveringFromFollowHandoff and not activeFollow and displacement.Magnitude <= maxStep then
				recoveringFromFollowHandoff = false
				gui:SetAttribute("PunchCameraHandoffActive", false)
			end
		end
		if not resolvedCFrame then
			cameraGeometryClampFrames += 1
			recoveringFromGeometryClamp = true
			local clearCFrame = lastClearCameraCFrame or shared.PunchWallHeartbeatLastClearCFrame
			local clearFocus = lastClearCameraFocus or shared.PunchWallHeartbeatLastClearFocus
			local maximumFallbackDistance = math.max(24, (userOrbitDistance or 12) * 2.5)
			if clearCFrame
				and (clearCFrame.Position - desiredPosition).Magnitude > maximumFallbackDistance then
				-- Never correct a blocked frame by teleporting to a stale camera
				-- pose. Holding the current frame is less disruptive and the guard
				-- will resume once the tunnel path becomes physically clear.
				clearCFrame = nil
				clearFocus = nil
			end
			if clearCFrame and cameraPoseBlocked(clearCFrame, character) then
				clearCFrame = shared.PunchWallCameraBaselineCFrame
				clearFocus = shared.PunchWallCameraBaselineFocus
			end
			if clearCFrame
				and (clearCFrame.Position - desiredPosition).Magnitude > maximumFallbackDistance then
				clearCFrame = nil
				clearFocus = nil
			end
			if clearCFrame and clearFocus then
				local focusDistance = math.max(0.5, (desiredPosition - desiredFocus.Position).Magnitude)
				camera.CFrame = CFrame.new(clearCFrame.Position) * desiredCFrame.Rotation
				camera.Focus = CFrame.new(clearCFrame.Position + desiredCFrame.LookVector * focusDistance)
			end
			gui:SetAttribute("PunchCameraGeometryClamped", true)
			gui:SetAttribute("PunchCameraGeometryClampFrames", cameraGeometryClampFrames)
			return
		end
		camera.CFrame = desiredCFrame
		camera.Focus = desiredFocus
		lastClearCameraCFrame = desiredCFrame
		lastClearCameraFocus = desiredFocus
		shared.PunchWallHeartbeatLastClearCFrame = desiredCFrame
		shared.PunchWallHeartbeatLastClearFocus = desiredFocus
		gui:SetAttribute("PunchCameraGeometryClamped", false)
		gui:SetAttribute("LastCameraInsideGeometry", false)
		gui:SetAttribute("PunchCameraRebasedAfterTeleport", false)
	end
	RunService:BindToRenderStep("PunchWallCameraGeometryGuard", Enum.RenderPriority.Camera.Value + 2, function(deltaTime)
		lastPunchCameraRenderAt = os.clock()
		updateCameraGeometryGuard(deltaTime)
	end)
	RunService.Heartbeat:Connect(function(deltaTime)
		if os.clock() - lastPunchCameraRenderAt > 0.35 then
			updateCameraGeometryGuard(math.min(deltaTime, 1 / 30))
		end
	end)
end
shared.PunchWallInstallCameraGeometryGuard()

if RunService:IsStudio() then
	shared.PunchWallRunCameraAutomation = function(punchCount)
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local head = character and character:FindFirstChild("Head")
		local camera = workspace.CurrentCamera
		local automation = gui:FindFirstChild("PunchWallClientAutomation")
		if not character or not rootPart or not humanoid or not head or not camera or not automation then
			return { valid = false, reason = "runtime_not_ready" }
		end
		-- Let the server-side test placement and zeroed velocity replicate before
		-- choosing the player's camera baseline.
		task.wait(0.3)
		local look = rootPart.CFrame.LookVector
		local horizontal = Vector3.new(look.X, 0, look.Z)
		if horizontal.Magnitude < 0.01 then return { valid = false, reason = "direction" } end
		local direction = horizontal.Unit
		local originalMinZoom = player.CameraMinZoomDistance
		local originalMaxZoom = player.CameraMaxZoomDistance
		player.CameraMinZoomDistance = 12
		player.CameraMaxZoomDistance = 12
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CameraSubject = humanoid
		camera.CFrame = CFrame.lookAt(rootPart.Position - direction * 12 + Vector3.new(0, 4, 0), rootPart.Position + Vector3.new(0, 1.5, 0))
		camera.Focus = CFrame.new(rootPart.Position + Vector3.new(0, 1.5, 0))
		task.wait(0.1)
		camera.CameraType = Enum.CameraType.Custom
		local initialOrbitSettled = false
		local initialOrbitDeadline = os.clock() + 2
		local selectedDistance = 0
		repeat
			task.wait(0.05)
			local actualDistance = (camera.CFrame.Position - (rootPart.Position + Vector3.new(0, 1.5, 0))).Magnitude
			local requestedDistance = tonumber(gui:GetAttribute("PunchCameraUserOrbitDistance"))
			selectedDistance = requestedDistance or actualDistance
			initialOrbitSettled = requestedDistance ~= nil
				and math.abs(actualDistance - requestedDistance) < 0.08
		until initialOrbitSettled or os.clock() >= initialOrbitDeadline
		local startLook = camera.CFrame.LookVector
		local lastCameraPosition = camera.CFrame.Position
		local lastRootPosition = rootPart.Position
		local maxCameraStep = 0
		local maxStepFrom = lastCameraPosition
		local maxStepTo = lastCameraPosition
		local maxBackwardStep = 0
		local maxBackFrom = lastRootPosition
		local maxBackTo = lastRootPosition
		local maxBackPunch = 0
		local visibleFrames = 0
		local clearCharacterFrames = 0
		local readableCharacterFrames = 0
		local settledSamples = 0
		local settledClearFrames = 0
		local settledReadableFrames = 0
		local insideFrames = 0
		local sampledFrames = 0
		local actions = 0
		local insideNames = {}
		local maximumLead = 0
		local currentPunch = 0
		local obscurerNames = {}
		gui:SetAttribute("PunchCameraMaxAppliedStep", 0)
		local function sampleCamera(settledSample)
			if shared.PunchWallCameraPositionBlocked(camera.CFrame.Position, character) then
				local clearCFrame = shared.PunchWallHeartbeatLastClearCFrame
				local clearFocus = shared.PunchWallHeartbeatLastClearFocus
				if clearCFrame and shared.PunchWallCameraPositionBlocked(clearCFrame.Position, character) then
					clearCFrame = shared.PunchWallCameraBaselineCFrame
					clearFocus = shared.PunchWallCameraBaselineFocus
				end
				if clearCFrame and clearFocus
					and not shared.PunchWallCameraPositionBlocked(clearCFrame.Position, character) then
					camera.CFrame = clearCFrame
					camera.Focus = clearFocus
				end
			end
			local cameraPosition = camera.CFrame.Position
			local cameraStep = (cameraPosition - lastCameraPosition).Magnitude
			if cameraStep > maxCameraStep then
				maxCameraStep = cameraStep
				maxStepFrom = lastCameraPosition
				maxStepTo = cameraPosition
			end
			lastCameraPosition = cameraPosition
			local rootStep = (rootPart.Position - lastRootPosition):Dot(direction)
			if -rootStep > maxBackwardStep then
				maxBackwardStep = -rootStep
				maxBackFrom = lastRootPosition
				maxBackTo = rootPart.Position
				maxBackPunch = currentPunch
			end
			lastRootPosition = rootPart.Position
			local headPoint, onScreen = camera:WorldToViewportPoint(head.Position)
			if onScreen then visibleFrames += 1 end
			local feetPoint = camera:WorldToViewportPoint(rootPart.Position - Vector3.new(0, 2.5, 0))
			local readable = onScreen and math.abs(headPoint.Y - feetPoint.Y) >= 18
			if readable then readableCharacterFrames += 1 end
			local obscured = false
			local gameRoot = workspace:FindFirstChild("PunchWallRPG")
			local physicsDebris = gameRoot and gameRoot:FindFirstChild("Depth Physics Debris")
			for _, part in ipairs(camera:GetPartsObscuringTarget(
				{ head.Position, rootPart.Position + Vector3.new(0, 1.15, 0) },
				{ character, localDebrisFolder, companionsFolder, physicsDebris }
			)) do
				if part:IsA("BasePart") and part.Transparency < 0.95 then
					obscured = true
					if #obscurerNames < 8 and not table.find(obscurerNames, part:GetFullName()) then
						table.insert(obscurerNames, part:GetFullName())
					end
					break
				end
			end
			local clear = onScreen and not obscured
			if clear then clearCharacterFrames += 1 end
			local orbitDistance = (cameraPosition - (rootPart.Position + Vector3.new(0, 1.5, 0))).Magnitude
			local settledNow = settledSample
				and gui:GetAttribute("PunchCameraFollowActive") == false
				and gui:GetAttribute("PunchCameraHandoffActive") ~= true
				and math.abs(orbitDistance - selectedDistance) < 0.12
			if settledNow then
				settledSamples += 1
				if clear then settledClearFrames += 1 end
				if readable then settledReadableFrames += 1 end
			end
			local blocked = false
			for _, part in ipairs(workspace:GetPartBoundsInBox(CFrame.new(cameraPosition), Vector3.new(0.3, 0.3, 0.3))) do
				if part:IsA("BasePart") and part.CanCollide and part.Transparency < 0.95 and not part:IsDescendantOf(character) then
					blocked = true
					if #insideNames < 8 then table.insert(insideNames, part:GetFullName()) end
					break
				end
			end
			if blocked then insideFrames += 1 end
			maximumLead = math.max(maximumLead, gui:GetAttribute("PunchCameraFollowPeakStuds") or 0)
			sampledFrames += 1
		end
		for punchIndex = 1, math.max(1, math.floor(tonumber(punchCount) or 1)) do
			currentPunch = punchIndex
			local attackInterval = tonumber(gui:GetAttribute("PunchAttackInterval")) or 1
			local cooldownRemaining = attackInterval + 0.03 - (os.clock() - lastPunchActionAt)
			if cooldownRemaining > 0 then task.wait(cooldownRemaining) end
			if automation:Invoke("Punch") then actions += 1 end
			for _ = 1, 8 do
				-- Device Simulator can suspend RenderStepped while its viewport is not
				-- actively painting. A timed client sample still yields to the render
				-- scheduler, while guaranteeing that automation cannot deadlock.
				task.wait(1 / 30)
				sampleCamera()
			end
			task.wait(0.55)
			task.wait(1 / 30)
			sampleCamera(true)
		end
		local settleDeadline = os.clock() + 4
		local settleTimedOut = false
		repeat
			task.wait(0.05)
			sampleCamera()
			local orbitDistance = (camera.CFrame.Position - (rootPart.Position + Vector3.new(0, 1.5, 0))).Magnitude
			local settled = gui:GetAttribute("PunchCameraFollowActive") == false
				and gui:GetAttribute("PunchCameraHandoffActive") ~= true
				and math.abs(orbitDistance - selectedDistance) < 0.08
			if settled then break end
			settleTimedOut = os.clock() >= settleDeadline
		until settleTimedOut
		sampleCamera(true)
		local finishDistance = (camera.CFrame.Position - (rootPart.Position + Vector3.new(0, 1.5, 0))).Magnitude
		local angle = math.deg(math.acos(math.clamp(startLook:Dot(camera.CFrame.LookVector), -1, 1)))
		local visibility = visibleFrames / math.max(1, sampledFrames)
		local clearVisibility = clearCharacterFrames / math.max(1, sampledFrames)
		local readableVisibility = readableCharacterFrames / math.max(1, sampledFrames)
		local settledClearVisibility = settledClearFrames / math.max(1, settledSamples)
		local settledReadableVisibility = settledReadableFrames / math.max(1, settledSamples)
		local lead = maximumLead
		local appliedStep = gui:GetAttribute("PunchCameraMaxAppliedStep") or 0
		local requested = math.max(1, math.floor(tonumber(punchCount) or 1))
		local valid = actions == requested
			and initialOrbitSettled
			and appliedStep <= 2.65
			and math.abs(finishDistance - selectedDistance) < 0.08
			and angle < 0.25
			and visibility >= 0.9
			and insideFrames == 0
			and maxBackwardStep < 0.5
			and camera.CameraType == Enum.CameraType.Custom
			and gui:GetAttribute("PunchCameraFollowActive") == false
			and lead > 1
		local visualValid = valid
			and clearVisibility >= 0.55
			and readableVisibility >= 0.65
			and settledClearVisibility >= 0.9
			and settledReadableVisibility >= 0.9
		local result = {
			valid = valid,
			visualValid = visualValid,
			actions = actions,
			maxStep = appliedStep,
			sampleMaxStep = maxCameraStep,
			maxStepFrom = tostring(maxStepFrom),
			maxStepTo = tostring(maxStepTo),
			maxBack = maxBackwardStep,
			maxBackFrom = tostring(maxBackFrom),
			maxBackTo = tostring(maxBackTo),
			maxBackPunch = maxBackPunch,
			settleTimedOut = settleTimedOut,
			zoomDelta = math.abs(finishDistance - selectedDistance),
			angle = angle,
			visibleRatio = visibility,
			clearRatio = clearVisibility,
			readableRatio = readableVisibility,
			settledSamples = settledSamples,
			settledClearRatio = settledClearVisibility,
			settledReadableRatio = settledReadableVisibility,
			obscurerNames = obscurerNames,
			inside = insideFrames,
			insideNames = insideNames,
			lead = lead,
			selectedDistance = selectedDistance,
			finishDistance = finishDistance,
			userOrbitDistance = gui:GetAttribute("PunchCameraUserOrbitDistance"),
			initialOrbitSettled = initialOrbitSettled,
			handoffActive = gui:GetAttribute("PunchCameraHandoffActive") == true,
			geometryClamped = gui:GetAttribute("PunchCameraGeometryClamped") == true,
			type = camera.CameraType.Name,
			mode = gui:GetAttribute("PunchCameraMode"),
		}
		gui:SetAttribute("CameraAutomationLastValid", valid)
		gui:SetAttribute("CameraAutomationVisualLastValid", visualValid)
		gui:SetAttribute("CameraAutomationLastPunches", actions)
		player.CameraMaxZoomDistance = originalMaxZoom
		player.CameraMinZoomDistance = originalMinZoom
		return result
	end
	(function()
	local automation = gui:FindFirstChild("PunchWallClientAutomation")
	if automation then
		local harnessConfig = GameConfig.StudioTestHarness or {}
		local harnessVersion = tostring(harnessConfig.Version or "1.0.0")
		local maxHarnessSequenceSteps = math.clamp(tonumber(harnessConfig.MaxSequenceSteps) or 50, 1, 100)
		local purchaseTestRuntime = {
			Active = false,
			Originals = {},
			MaxOverrides = 6,
			MaxTestId = 2147483647,
		}
		local clientCommandNames = {
			"Describe", "Sequence", "Snapshot", "Punch", "Jump", "SpinNow", "OpenSpin",
			"OpenTab", "OpenRebirth", "OpenSettings", "OpenHonorItem", "OpenShopPage", "SetPurchaseUiState", "ConfigurePurchaseTestIds", "InvokeShopAction", "InvokeRebirthAction", "CloseMenus", "ToggleSound",
			"OpenInventory", "CloseInventory", "SelectInventoryCategory", "SetInventorySearch",
			"SetInventoryRarity", "SetInventoryRarityMenuOpen", "SelectInventoryItem",
			"InvokeInventoryAction", "InventorySnapshot",
			"OpenMore", "SetCamera", "ResetCamera", "SetSettings", "ClearMarkers",
			"RequestAction", "SetGuiVisible", "SetGuiAttribute", "GetGuiSummary",
			"__ReplayLoading", "__HideLoading", "__RunCamera",
		}
		local function clientVector3(value)
			if typeof(value) == "Vector3" then return value end
			if typeof(value) ~= "table" then return nil end
			return Vector3.new(
				tonumber(value.x or value.X or value[1]) or 0,
				tonumber(value.y or value.Y or value[2]) or 0,
				tonumber(value.z or value.Z or value[3]) or 0
			)
		end
		local function clientSnapshot()
			local camera = workspace.CurrentCamera
			local character = player.Character
			local rootPart = character and character:FindFirstChild("HumanoidRootPart")
			local spinModal = gui:FindFirstChild("HeroSpinModal")
			local shop = shared.PunchWallShopReference
			local inventory = shared.PunchWallInventoryController
			return {
				ok = true,
				menuVisible = mainPanel.Visible or shared.PunchWallStandaloneWindows.RebirthPanel.Visible or shared.PunchWallStandaloneWindows.SettingsPanel.Visible,
				activeTab = activeTab,
				activeWindow = tostring(gui:GetAttribute("ActiveStandaloneWindow") or (mainPanel.Visible and activeTab or "")),
				rebirthVisible = shared.PunchWallStandaloneWindows.RebirthPanel.Visible,
				settingsVisible = shared.PunchWallStandaloneWindows.SettingsPanel.Visible,
				shopVisible = shop and shop.Visible or false,
				shopPage = shared.PunchWallHeroShopPage,
				inventoryVisible = inventory and inventory:IsVisible() or false,
				inventory = inventory and inventory:GetSnapshot() or nil,
				spinVisible = spinModal and spinModal.Visible or false,
				trainingVisible = shared.PunchWallTrainingOverlay and shared.PunchWallTrainingOverlay.Visible or false,
				sound = clientSettings.sound,
				motion = clientSettings.motion,
				uiScale = clientSettings.uiScale,
				cameraType = camera and camera.CameraType.Name or "Missing",
				cameraMode = gui:GetAttribute("PunchCameraMode"),
				viewport = camera and { x = camera.ViewportSize.X, y = camera.ViewportSize.Y } or nil,
				position = rootPart and { x = rootPart.Position.X, y = rootPart.Position.Y, z = rootPart.Position.Z } or nil,
				feedbackCount = gui:GetAttribute("FeedbackCount") or 0,
				lastFeedbackType = gui:GetAttribute("LastFeedbackType"),
				lastFeedbackTarget = gui:GetAttribute("LastFeedbackTarget"),
			}
		end
		function purchaseTestRuntime.ResolveCatalog(catalogName)
			if catalogName == "PremiumFists" then
				return GameConfig.PremiumFists, "name", "gamePassId"
			end
			if catalogName == "PremiumPets" then
				return GameConfig.PremiumPets, "name", "gamePassId"
			end
			if catalogName == "PremiumProducts" then
				return GameConfig.PremiumProducts, "id", "productId"
			end
			return nil
		end
		function purchaseTestRuntime.Refresh(reason)
			assert(shared.PunchWallHeroShopRefresh, "purchase test shop refresh is unavailable")
			shared.PunchWallHeroShopRefresh({
				force = true,
				reason = tostring(reason or "studio-purchase-test"),
			})
			renderOpenPanel()
			if shared.PunchWallRefreshSpin then
				shared.PunchWallRefreshSpin()
			end
		end
		function purchaseTestRuntime.Restore()
			local originals = purchaseTestRuntime.Originals
			purchaseTestRuntime.Originals = {}
			purchaseTestRuntime.Active = false
			for index = #originals, 1, -1 do
				local original = originals[index]
				original.item[original.idField] = original.value
			end
			local refreshed, refreshError = pcall(
				purchaseTestRuntime.Refresh,
				"studio-purchase-test-restore"
			)
			return {
				ok = refreshed,
				mode = "Restore",
				active = false,
				restored = #originals,
				reason = refreshed and nil or tostring(refreshError),
			}
		end
		function purchaseTestRuntime.Apply(options)
			if not RunService:IsStudio() then
				return { ok = false, reason = "studio_only" }
			end
			if purchaseTestRuntime.Active then
				return { ok = false, reason = "override_already_active" }
			end
			local overrides = typeof(options) == "table" and options.overrides or nil
			if typeof(overrides) ~= "table"
				or #overrides < 1
				or #overrides > purchaseTestRuntime.MaxOverrides
			then
				return { ok = false, reason = "invalid_override_count" }
			end

			local prepared = {}
			local seen = {}
			for index, override in ipairs(overrides) do
				if typeof(override) ~= "table" then
					return { ok = false, reason = "invalid_override_" .. index }
				end
				local catalogName = tostring(override.catalog or "")
				local key = tostring(override.key or "")
				local testId = tonumber(override.id)
				local catalog, keyField, idField = purchaseTestRuntime.ResolveCatalog(catalogName)
				if not catalog or key == "" or #key > 80 then
					return { ok = false, reason = "invalid_target_" .. index }
				end
				if not testId
					or testId <= 0
					or testId > purchaseTestRuntime.MaxTestId
					or math.floor(testId) ~= testId
				then
					return { ok = false, reason = "invalid_test_id_" .. index }
				end
				local identity = catalogName .. "\0" .. key
				if seen[identity] then
					return { ok = false, reason = "duplicate_target_" .. index }
				end
				seen[identity] = true
				local item
				for _, candidate in ipairs(catalog) do
					if tostring(candidate[keyField] or "") == key then
						item = candidate
						break
					end
				end
				if not item then
					return { ok = false, reason = "missing_target_" .. index }
				end
				table.insert(prepared, {
					item = item,
					idField = idField,
					value = item[idField],
					testId = testId,
				})
			end

			purchaseTestRuntime.Originals = prepared
			local applied, applyError = xpcall(function()
				for _, entry in ipairs(prepared) do
					entry.item[entry.idField] = entry.testId
				end
				purchaseTestRuntime.Active = true
				purchaseTestRuntime.Refresh("studio-purchase-test-apply")
			end, debug.traceback)
			if not applied then
				for index = #prepared, 1, -1 do
					local entry = prepared[index]
					entry.item[entry.idField] = entry.value
				end
				purchaseTestRuntime.Originals = {}
				purchaseTestRuntime.Active = false
				pcall(purchaseTestRuntime.Refresh, "studio-purchase-test-rollback")
				return { ok = false, reason = tostring(applyError) }
			end
			return {
				ok = true,
				mode = "Apply",
				active = true,
				applied = #prepared,
			}
		end
		automation.OnInvoke = function(action, value)
			if action == "Describe" then
				return {
					ok = true,
					version = harnessVersion,
					studioOnly = true,
					productionSurface = false,
					commands = clientCommandNames,
				}
			end
			if action == "Snapshot" then return clientSnapshot() end
			if action == "Punch" then return tryPunchAction(value) end
			if action == "SpinNow" and shared.PunchWallTriggerSpin then return shared.PunchWallTriggerSpin() end
			if action == "Jump" then return requestHumanoidJump() end
			if action == "OpenSpin" then
				if shared.PunchWallOpenSpin then
					shared.PunchWallOpenSpin()
					return true
				end
				return false
			end
			if action == "OpenTab" then openGameTab(tostring(value or "Fists")) return true end
			if action == "OpenRebirth" then shared.PunchWallOpenRebirthPanel(tostring(value or "automation")) return true end
			if action == "OpenSettings" then shared.PunchWallOpenSettingsPanel(tostring(value or "automation")) return true end
			if action == "InvokeRebirthAction" then
				local callbacks = shared.PunchWallRebirthActionCallbacks
				local callback = callbacks and callbacks[tostring(value or "")]
				if type(callback) ~= "function" then return false end
				callback()
				return true
			end
			if action == "OpenHonorItem" then
				local itemId = tostring(value or "")
				if not GameConfig.HonorItemDefinition(itemId) then return false end
				local succeeded = shared.PunchWallOpenInventoryHonorItem
					and shared.PunchWallOpenInventoryHonorItem(itemId, "automation")
				return succeeded == true
			end
			if action == "ToggleSound" then return shared.PunchWallApplySoundSetting(not clientSettings.sound, true) end
			if action == "OpenMore" then
				openGameTab("Tasks")
				return true
			end
			if action == "OpenInventory" then
				openGameTab("Inventory")
				return shared.PunchWallInventoryController and shared.PunchWallInventoryController:GetSnapshot() or true
			end
			if action == "CloseInventory" then
				setMenuVisible(false)
				return true
			end
			if action == "InventorySnapshot" then
				return shared.PunchWallInventoryController and shared.PunchWallInventoryController:GetSnapshot() or false
			end
			if action == "SelectInventoryCategory" then
				if not shared.PunchWallInventoryController then return false end
				return shared.PunchWallInventoryController:SetCategory(tostring(value or "All"))
			end
			if action == "SetInventorySearch" then
				if not shared.PunchWallInventoryController then return false end
				return shared.PunchWallInventoryController:SetSearch(tostring(value or ""))
			end
			if action == "SetInventoryRarity" then
				if not shared.PunchWallInventoryController then return false end
				return shared.PunchWallInventoryController:SetRarity(tostring(value or "All"))
			end
			if action == "SetInventoryRarityMenuOpen" then
				local controller = shared.PunchWallInventoryController
				if not controller then return false end
				controller:_setRarityMenu(value == true)
				return controller.RarityMenu.Visible == true
			end
			if action == "SelectInventoryItem" then
				if not shared.PunchWallInventoryController then return false end
				return shared.PunchWallInventoryController:SelectItem(tostring(value or ""))
			end
			if action == "InvokeInventoryAction" then
				if not shared.PunchWallInventoryController then return false end
				local succeeded, reason = shared.PunchWallInventoryController:InvokeAction(value)
				if type(value) == "table"
					and string.lower(tostring(value.action or "")) == "delete"
					and reason == "confirmation_required"
					and value.single ~= true
				then
					return shared.PunchWallInventoryController:InvokeAction(value)
				end
				return succeeded, reason
			end
			if action == "OpenShopPage" then
				local page = tostring(value or "Fists")
				if not table.find({ "Fists", "Premium", "Boosts", "Honor", "Robux" }, page) then
					return false
				end
				shared.PunchWallHeroShopPage = page
				if shared.PunchWallHeroShopRefresh then
					shared.PunchWallHeroShopRefresh({
						force = true,
						reason = "studio-automation-open-shop-page",
					})
				end
				return true
			end
			if action == "SetPurchaseUiState" then
				if not RunService:IsStudio() or typeof(value) ~= "table" then
					return false
				end
				local productKey = tostring(value.productKey or "")
				local state = tostring(value.state or "")
				local allowedStates = {
					Idle = true,
					Opening = true,
					CheckoutOpen = true,
					Verifying = true,
					Canceled = true,
					Rejected = true,
					Granted = true,
				}
				if not shared.PunchWallPurchaseRuntime.FindPremiumProduct(productKey)
					or allowedStates[state] ~= true
				then
					return false
				end
				shared.PunchWallShopFocusedProductId = productKey
				shared.PunchWallPurchaseRuntime.SetProductUiState(
					productKey,
					state,
					tostring(value.message or state)
				)
				return true
			end
			if action == "ConfigurePurchaseTestIds" then
				local options = typeof(value) == "table" and value or {}
				local mode = tostring(options.mode or "")
				if mode == "Apply" then
					return purchaseTestRuntime.Apply(options)
				end
				if mode == "Restore" then
					return purchaseTestRuntime.Restore()
				end
				return { ok = false, reason = "invalid_mode" }
			end
			if action == "InvokeShopAction" then
				local callback = shared.PunchWallShopActions and shared.PunchWallShopActions[tostring(value or "")]
				if callback then callback() return true end
				return false
			end
			if action == "CloseMenus" then
				setMenuVisible(false)
				shared.PunchWallStandaloneWindows.Close("AutomationClose")
				local spinModal = gui:FindFirstChild("HeroSpinModal")
				if spinModal then spinModal.Visible = false end
				shared.PunchWallSetModalCoreGuiHidden(false, "GameMenu")
				shared.PunchWallSetModalCoreGuiHidden(false, "SpinModal")
				return true
			end
			if action == "SetCamera" then
				local camera = workspace.CurrentCamera
				local options = typeof(value) == "table" and value or {}
				local position = clientVector3(options.position)
				local lookAt = clientVector3(options.lookAt)
				if not camera or not position then return false end
				camera.CameraType = Enum.CameraType.Scriptable
				camera.CFrame = lookAt and CFrame.lookAt(position, lookAt) or CFrame.new(position)
				camera.Focus = CFrame.new(lookAt or position + camera.CFrame.LookVector * 12)
				gui:SetAttribute("TestHarnessCameraMode", "Scriptable")
				return clientSnapshot()
			end
			if action == "ResetCamera" then
				local camera = workspace.CurrentCamera
				local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if not camera then return false end
				camera.CameraType = Enum.CameraType.Custom
				if humanoid then camera.CameraSubject = humanoid end
				gui:SetAttribute("TestHarnessCameraMode", "Player")
				return clientSnapshot()
			end
			if action == "SetSettings" then
				local options = typeof(value) == "table" and value or {}
				if options.sound ~= nil then shared.PunchWallApplySoundSetting(options.sound == true, false) end
				if options.motion ~= nil then
					clientSettings.motion = options.motion == true
					if shared.PunchWallApplyFistAuraMotion then shared.PunchWallApplyFistAuraMotion() end
					if shared.PunchWallRefreshHonorMotion then shared.PunchWallRefreshHonorMotion() end
				end
				if options.uiScale ~= nil then clientSettings.uiScale = math.clamp(tonumber(options.uiScale) or 1, 0.8, 1.2) end
				if options.persist ~= false then
					actionRemote:FireServer({ action = "UpdateSettings", value = clientSettings })
				end
				applyResponsiveLayout()
				if shared.PunchWallStandaloneWindows.SettingsPanel.Visible then shared.PunchWallStandaloneWindows.Refresh() end
				return clientSnapshot()
			end
			if action == "ClearMarkers" then
				for _, name in ipairs({
					"FeedbackCount", "LastFeedbackType", "LastFeedbackTarget", "LastSpinReward",
					"SpinResultCount", "CameraAutomationLastPunches",
				}) do gui:SetAttribute(name, nil) end
				return clientSnapshot()
			end
			if action == "RequestAction" then
				requestAction(value)
				return true
			end
			if action == "SetGuiVisible" then
				local options = typeof(value) == "table" and value or {}
				local object = type(options.name) == "string" and gui:FindFirstChild(options.name, true)
				if not object or not object:IsA("GuiObject") then return false end
				object.Visible = options.visible ~= false
				return { ok = true, name = object.Name, visible = object.Visible }
			end
			if action == "SetGuiAttribute" then
				local options = typeof(value) == "table" and value or {}
				local object = options.name and gui:FindFirstChild(tostring(options.name), true) or gui
				if not object or type(options.attribute) ~= "string" then return false end
				object:SetAttribute(options.attribute, options.value)
				return { ok = true, name = object.Name, attribute = options.attribute, value = object:GetAttribute(options.attribute) }
			end
			if action == "GetGuiSummary" then
				local visible, total = {}, 0
				for _, object in ipairs(gui:GetDescendants()) do
					if object:IsA("GuiObject") then
						total += 1
						if object.Visible and object.Parent == gui and #visible < 40 then table.insert(visible, object.Name) end
					end
				end
				table.sort(visible)
				return { ok = true, total = total, visibleRoots = visible, snapshot = clientSnapshot() }
			end
			if action == "__ReplayLoading" then return shared.PunchWallReplayLoading() end
			if action == "__HideLoading" then return shared.PunchWallHideLoading() end
			if action == "__RunCamera" then return shared.PunchWallRunCameraAutomation(value) end
			requestAction(action)
			return true
		end

		local oldHarness = gui:FindFirstChild("PunchWallClientTestHarness")
		if oldHarness then oldHarness:Destroy() end
		if harnessConfig.Enabled ~= false then
			local testHarness = Instance.new("BindableFunction")
			testHarness.Name = "PunchWallClientTestHarness"
			testHarness:SetAttribute("Ready", true)
			testHarness:SetAttribute("StudioOnly", true)
			testHarness:SetAttribute("ProductionSurface", false)
			testHarness:SetAttribute("Version", harnessVersion)
			testHarness:SetAttribute("MaxSequenceSteps", maxHarnessSequenceSteps)
			testHarness:SetAttribute("CommandCount", #clientCommandNames)
			local schema = Instance.new("StringValue")
			schema.Name = "CommandSchema"
			schema.Value = game:GetService("HttpService"):JSONEncode({
				version = harnessVersion,
				studioOnly = true,
				commands = clientCommandNames,
				request = { command = "Snapshot", value = "optional" },
				sequence = { command = "Sequence", steps = { { command = "OpenTab", value = "Fists" } } },
			})
			schema.Parent = testHarness
			testHarness.OnInvoke = function(request, legacyValue)
				if typeof(request) == "string" then request = { command = request, value = legacyValue } end
				assert(typeof(request) == "table", "Client harness request must be a table or command string")
				local command = tostring(request.command or request.action or "")
				if command == "Describe" then return automation:Invoke("Describe") end
				if command == "Sequence" then
					local steps = request.steps or request.sequence or {}
					assert(typeof(steps) == "table", "Client sequence steps must be a table")
					assert(#steps <= maxHarnessSequenceSteps, "Client sequence exceeds harness limit")
					local results = {}
					for index, step in ipairs(steps) do
						assert(typeof(step) == "table", "Invalid client sequence step " .. index)
						local ok, result = pcall(function()
							return automation:Invoke(step.command or step.action, step.value or step.target)
						end)
						results[index] = ok and { ok = true, result = result } or { ok = false, error = tostring(result) }
						if not ok and request.continueOnError ~= true then
							return { ok = false, failedStep = index, error = tostring(result), results = results }
						end
					end
					return { ok = true, action = command, count = #results, results = results, snapshot = clientSnapshot() }
				end
				local ok, result = pcall(function() return automation:Invoke(command, request.value or request.target) end)
				if not ok then return { ok = false, action = command, error = tostring(result) } end
				return { ok = true, action = command, result = result }
			end
			testHarness.Parent = gui
			gui:SetAttribute("StudioTestHarnessReady", true)
			gui:SetAttribute("StudioTestHarnessVersion", harnessVersion)
		end
	end
	end)()
end

player.CharacterAdded:Connect(function()
	punchMotionState = nil
	activePunchCamera = nil
	shared.PunchWallCameraBaselineCFrame = nil
	shared.PunchWallCameraBaselineFocus = nil
	companionRuntime.CancelVisualRetry("CharacterAdded")
	visualSignature = ""
	task.defer(refreshCharacterVisuals)
end)

task.defer(function()
	requestAction("RequestSync")
	task.wait(0.2)
	refreshCharacterVisuals()
end)

RunService.Heartbeat:Connect(function(deltaTime)
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end
	local now = os.clock()
	deltaTime = math.clamp(tonumber(deltaTime) or (1 / 60), 1 / 240, 0.1)
	local rootVelocity = rootPart.AssemblyLinearVelocity
	local forwardSpeed = rootVelocity:Dot(rootPart.CFrame.LookVector)
	local sideSpeed = rootVelocity:Dot(rootPart.CFrame.RightVector)
	local cameraDistance = companionRuntime.CameraDistance(rootPart)
	local lod = cameraDistance <= 8 and "Near60"
		or cameraDistance <= 14 and "Mid30"
		or "Far20"
	local updateInterval = clientSettings.motion
		and (lod == "Near60" and 0 or lod == "Mid30" and (1 / 30) or (1 / 20))
		or (1 / 20)
	local combinedScreenArea = 0
	for index, state in ipairs(companionModels) do
		local model = state.model
		if model and model.Parent and model.PrimaryPart then
			state.updateAccumulator += deltaTime
			if updateInterval == 0 or state.updateAccumulator >= updateInterval then
				local effectiveDelta = math.min(state.updateAccumulator, 0.1)
				state.updateAccumulator = 0
				local availableBudget = math.max(
					companionRuntime.combinedScreenAreaBudget - combinedScreenArea,
					0
				)
				local policyTarget, visualScale, budgetPolicy = companionRuntime.ResolveVisualPolicy(
					state,
					rootPart,
					cameraDistance,
					availableBudget
				)
				if not companionRuntime.ApplyVisualScale(state, visualScale) then
					budgetPolicy = "CulledAfterBudgetLOD"
					model:SetAttribute("CompanionScaleApplyFailed", true)
				else
					model:SetAttribute("CompanionScaleApplyFailed", false)
				end
				local hover = clientSettings.motion
					and math.sin(now * (state.premium and 2.25 or 2.8) + state.phase) * state.hoverAmplitude
					or 0
				local sway = clientSettings.motion and math.sin(now * 1.35 + state.phase * 0.7) * 0.14 or 0
				local pitch = clientSettings.motion and math.rad(math.clamp(-forwardSpeed * 0.16, -6, 6)) or 0
				local roll = clientSettings.motion
					and (math.rad(math.clamp(-sideSpeed * 0.2, -8, 8))
						+ math.rad(math.sin(now * 1.8 + state.phase) * 1.7))
					or 0
				local targetBounds = policyTarget
					* CFrame.new(sway, hover, 0)
					* CFrame.Angles(pitch, 0, roll)
				local distance = (state.currentBoundsCFrame.Position - targetBounds.Position).Magnitude
				if distance > 36 then
					state.currentBoundsCFrame = targetBounds
				else
					local alpha = 1 - math.exp(-state.followResponsiveness * effectiveDelta)
					state.currentBoundsCFrame = state.currentBoundsCFrame:Lerp(targetBounds, alpha)
				end
				model:PivotTo(state.currentBoundsCFrame * state.pivotToBounds:Inverse())
				state.motionFrames += 1
				local actualScreenArea = companionRuntime.ScreenArea(state.boundsSize, state.currentBoundsCFrame.Position)
				local effectiveBudget = math.min(companionRuntime.perPetScreenAreaBudget, availableBudget)
				if budgetPolicy == "CulledAfterBudgetLOD"
					or actualScreenArea > effectiveBudget + 0.0005 then
					budgetPolicy = "CulledAfterBudgetLOD"
					state.lastScreenArea = 0
				else
					state.lastScreenArea = actualScreenArea
				end
				state.lod = lod
				companionRuntime.ApplyRenderPolicy(state, budgetPolicy, lod, clientSettings.motion)
				local motionHz = updateInterval == 0 and 60 or math.floor(1 / updateInterval + 0.5)
				if state.motionHz ~= motionHz then
					state.motionHz = motionHz
					model:SetAttribute("CompanionMotionHz", motionHz)
				end
				if state.motionFrames >= 3 and model:GetAttribute("SmoothFollowReady") ~= true then
					model:SetAttribute("SmoothFollowReady", true)
				end
			end
			combinedScreenArea += state.lastScreenArea or 0
		end
	end
	companionRuntime.telemetryAccumulator = (companionRuntime.telemetryAccumulator or 0) + deltaTime
	if companionRuntime.telemetryAccumulator >= 0.25 then
		companionRuntime.telemetryAccumulator = 0
		for _, state in ipairs(companionModels) do
			if state.model and state.model.Parent then
				state.model:SetAttribute("EstimatedScreenArea", state.lastScreenArea or 0)
				state.model:SetAttribute(
					"ScreenAreaWithinBudget",
					(state.lastScreenArea or 0) <= companionRuntime.perPetScreenAreaBudget
				)
			end
		end
		gui:SetAttribute("CompanionLOD", lod)
		gui:SetAttribute("CompanionCameraDistance", cameraDistance)
		gui:SetAttribute("CompanionCombinedScreenAreaEstimate", combinedScreenArea)
		gui:SetAttribute(
			"CompanionCombinedScreenAreaWithinBudget",
			combinedScreenArea <= companionRuntime.combinedScreenAreaBudget
		)
	end
end)

do
local clientRuntime = {
	AmbientPulseParts = {},
	AmbientPulseIndices = {},
	AmbientPulseAddedCount = 0,
	AmbientPulseRemovedCount = 0,
	AmbientPulseInitialScanCount = 0,
	GameRoot = nil,
	WallsFolder = nil,
	InteractablesFolder = nil,
	DepthBlocksFolder = nil,
	GameRootConnections = {},
	GameRootBindCount = 0,
	TargetFolderCacheRefreshCount = 0,
	TargetCacheMissCount = 0,
	TargetDepthOverlap = OverlapParams.new(),
}
clientRuntime.TargetDepthOverlap.FilterType = Enum.RaycastFilterType.Include
clientRuntime.TargetDepthOverlap.FilterDescendantsInstances = {}
clientRuntime.TargetDepthOverlap.MaxParts = 400

gui:SetAttribute("AmbientPulseRegistryMode", "EventDrivenV1")
gui:SetAttribute("AmbientPulseCount", 0)
gui:SetAttribute("TargetHeartbeatCacheMode", "EventDrivenFoldersV1")
gui:SetAttribute("TargetOverlapParamsCreateCount", 1)

function clientRuntime.UpdateAmbientPulseAttributes()
	gui:SetAttribute("AmbientPulseCount", #clientRuntime.AmbientPulseParts)
	gui:SetAttribute("AmbientPulseAddedCount", clientRuntime.AmbientPulseAddedCount)
	gui:SetAttribute("AmbientPulseRemovedCount", clientRuntime.AmbientPulseRemovedCount)
end

function clientRuntime.RegisterAmbientPulsePart(candidate)
	if not candidate:IsA("BasePart")
		or candidate:GetAttribute("AmbientMotion") ~= "Pulse"
		or clientRuntime.AmbientPulseIndices[candidate]
	then
		return false
	end
	table.insert(clientRuntime.AmbientPulseParts, candidate)
	clientRuntime.AmbientPulseIndices[candidate] = #clientRuntime.AmbientPulseParts
	clientRuntime.AmbientPulseAddedCount += 1
	clientRuntime.UpdateAmbientPulseAttributes()
	return true
end

function clientRuntime.UnregisterAmbientPulsePart(candidate)
	local index = clientRuntime.AmbientPulseIndices[candidate]
	if not index then return false end
	clientRuntime.AmbientPulseIndices[candidate] = nil
	table.remove(clientRuntime.AmbientPulseParts, index)
	for shiftedIndex = index, #clientRuntime.AmbientPulseParts do
		clientRuntime.AmbientPulseIndices[clientRuntime.AmbientPulseParts[shiftedIndex]] = shiftedIndex
	end
	clientRuntime.AmbientPulseRemovedCount += 1
	clientRuntime.UpdateAmbientPulseAttributes()
	return true
end

function clientRuntime.DisconnectGameRoot()
	for _, connection in ipairs(clientRuntime.GameRootConnections) do
		connection:Disconnect()
	end
	table.clear(clientRuntime.GameRootConnections)
end

function clientRuntime.RefreshTargetFolderCache()
	local root = clientRuntime.GameRoot
	local walls = root and root:FindFirstChild("Walls") or nil
	local interactables = root and root:FindFirstChild("Interactables") or nil
	local depthBlocks = root and root:FindFirstChild("Depth Blocks") or nil
	if walls == clientRuntime.WallsFolder
		and interactables == clientRuntime.InteractablesFolder
		and depthBlocks == clientRuntime.DepthBlocksFolder
	then
		return false
	end
	clientRuntime.WallsFolder = walls
	clientRuntime.InteractablesFolder = interactables
	clientRuntime.DepthBlocksFolder = depthBlocks
	clientRuntime.TargetDepthOverlap.FilterDescendantsInstances = depthBlocks and { depthBlocks } or {}
	clientRuntime.TargetFolderCacheRefreshCount += 1
	gui:SetAttribute("TargetFolderCacheRefreshCount", clientRuntime.TargetFolderCacheRefreshCount)
	gui:SetAttribute("TargetWallsCached", walls ~= nil)
	gui:SetAttribute("TargetInteractablesCached", interactables ~= nil)
	gui:SetAttribute("TargetDepthBlocksCached", depthBlocks ~= nil)
	return true
end

function clientRuntime.BindGameRoot(root)
	if root == clientRuntime.GameRoot then return false end
	clientRuntime.DisconnectGameRoot()
	for index = #clientRuntime.AmbientPulseParts, 1, -1 do
		clientRuntime.UnregisterAmbientPulsePart(clientRuntime.AmbientPulseParts[index])
	end
	clientRuntime.GameRoot = root
	clientRuntime.GameRootBindCount += 1
	gui:SetAttribute("ClientGameRootBindCount", clientRuntime.GameRootBindCount)
	clientRuntime.RefreshTargetFolderCache()
	if not root then return true end

	clientRuntime.AmbientPulseInitialScanCount += 1
	gui:SetAttribute("AmbientPulseInitialScanCount", clientRuntime.AmbientPulseInitialScanCount)
	for _, descendant in ipairs(root:GetDescendants()) do
		clientRuntime.RegisterAmbientPulsePart(descendant)
	end

	table.insert(clientRuntime.GameRootConnections, root.DescendantAdded:Connect(function(descendant)
		if clientRuntime.RegisterAmbientPulsePart(descendant) or not descendant:IsA("BasePart") then return end
		-- Server builders parent parts before applying their visual attributes.
		-- One deferred check captures that synchronous construction path without
		-- retaining a property connection for every scene part.
		task.defer(function()
			if clientRuntime.GameRoot == root and descendant:IsDescendantOf(root) then
				clientRuntime.RegisterAmbientPulsePart(descendant)
			end
		end)
	end))
	table.insert(clientRuntime.GameRootConnections, root.DescendantRemoving:Connect(function(descendant)
		clientRuntime.UnregisterAmbientPulsePart(descendant)
	end))
	table.insert(clientRuntime.GameRootConnections, root.ChildAdded:Connect(function(child)
		if child.Name == "Walls" or child.Name == "Interactables" or child.Name == "Depth Blocks" then
			clientRuntime.RefreshTargetFolderCache()
		end
	end))
	table.insert(clientRuntime.GameRootConnections, root.ChildRemoved:Connect(function(child)
		if child == clientRuntime.WallsFolder
			or child == clientRuntime.InteractablesFolder
			or child == clientRuntime.DepthBlocksFolder
		then
			task.defer(clientRuntime.RefreshTargetFolderCache)
		end
	end))
	table.insert(clientRuntime.GameRootConnections, root:GetPropertyChangedSignal("Name"):Connect(function()
		task.defer(clientRuntime.RefreshGameRoot)
	end))
	return true
end

function clientRuntime.RefreshGameRoot()
	local root = workspace:FindFirstChild("PunchWallRPG")
	clientRuntime.BindGameRoot(root)
end

workspace.ChildAdded:Connect(function(child)
	if child.Name == "PunchWallRPG" then
		task.defer(clientRuntime.RefreshGameRoot)
	end
end)
workspace.ChildRemoved:Connect(function(child)
	if child == clientRuntime.GameRoot then
		clientRuntime.BindGameRoot(nil)
		task.defer(clientRuntime.RefreshGameRoot)
	end
end)
clientRuntime.RefreshGameRoot()

local ambientPhase = 0
local lastAmbientActive
RunService.RenderStepped:Connect(function(deltaTime)
	ambientPhase += deltaTime
	local active = clientSettings.motion and #clientRuntime.AmbientPulseParts > 0
	if active ~= lastAmbientActive then
		lastAmbientActive = active
		gui:SetAttribute("AmbientMotionActive", active)
	end
	for index, part in ipairs(clientRuntime.AmbientPulseParts) do
		if part.Parent then
			local base = tonumber(part:GetAttribute("AmbientBaseTransparency")) or 0
			part.Transparency = active and math.clamp(base + math.sin(ambientPhase * 2.6 + index * 0.7) * 0.1, 0, 0.85) or base
		end
	end
end)

local tutorialWaypoint = Instance.new("BillboardGui")
tutorialWaypoint.Name = "TutorialWaypoint"
tutorialWaypoint.AlwaysOnTop = true
tutorialWaypoint.LightInfluence = 0
tutorialWaypoint.MaxDistance = 240
tutorialWaypoint.Size = UserInputService.TouchEnabled and UDim2.fromOffset(136, 38) or UDim2.fromOffset(172, 46)
tutorialWaypoint.StudsOffsetWorldSpace = Vector3.new(0, 7, 0)
tutorialWaypoint.Enabled = false
tutorialWaypoint.Parent = gui

local tutorialWaypointLabel = Instance.new("TextLabel")
tutorialWaypointLabel.BackgroundColor3 = palette.Train
tutorialWaypointLabel.BackgroundTransparency = 0.05
tutorialWaypointLabel.BorderSizePixel = 0
tutorialWaypointLabel.Size = UDim2.fromScale(1, 1)
tutorialWaypointLabel.Font = Enum.Font.GothamBlack
tutorialWaypointLabel.Text = "NEXT OBJECTIVE"
tutorialWaypointLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
tutorialWaypointLabel.TextSize = UserInputService.TouchEnabled and 10 or 13
tutorialWaypointLabel.TextWrapped = true
tutorialWaypointLabel.Parent = tutorialWaypoint

local tutorialWaypointCorner = Instance.new("UICorner")
tutorialWaypointCorner.CornerRadius = UDim.new(0, 7)
tutorialWaypointCorner.Parent = tutorialWaypointLabel

local tutorialWaypointStroke = Instance.new("UIStroke")
tutorialWaypointStroke.Color = Color3.fromRGB(255, 244, 166)
tutorialWaypointStroke.Thickness = 2
tutorialWaypointStroke.Parent = tutorialWaypointLabel

function clientRuntime.IsTrainingTarget(candidate)
	if not candidate then return false end
	return candidate:GetAttribute("TrainingStationId") ~= nil
		and candidate:GetAttribute("PowerPerSecond") ~= nil
end

function clientRuntime.IsUseTarget(candidate)
	if not candidate then return false end
	if candidate:GetAttribute("PremiumOnly") == true then
		return candidate:GetAttribute("PurchaseConfigured") == true
	end
	return candidate.Name == "Pet Egg Machine"
		or candidate.Name == "Rebirth Shrine"
		or candidate:GetAttribute("InteractionMenu") ~= nil
end

function clientRuntime.SetContextualAction(actionName, target)
	clientRuntime.ContextualActionName = actionName
	clientRuntime.ContextualActionTarget = target
	local targetName = target and target.Name or ""
	local trainingAlreadyActive = actionName == "Train" and latestStats.TrainingActive == 1
	local available = actionName ~= nil and target ~= nil and not trainingAlreadyActive
	local trainingRequired = actionName == "Train" and tonumber(target:GetAttribute("RequiredPower")) or 0
	local trainingGain = actionName == "Train" and tonumber(target:GetAttribute("PowerPerSecond")) or 0
	local trainingEligible = actionName ~= "Train" or (tonumber(latestStats.BasePower or latestStats.Power) or 0) >= trainingRequired
	trainButton.Visible = available and actionName == "Train"
	trainButton.Active = trainButton.Visible and trainingEligible
	trainButton.AutoButtonColor = trainButton.Active
	trainButton.Text = trainingEligible and "TRAIN" or "LOCKED"
	useButton.Visible = available and actionName == "Use"
	contextLabel.Visible = gui:GetAttribute("PixelReferenceHUDActive") ~= true
		and available
		and not mainPanel.Visible
		and gui:GetAttribute("StandaloneModalVisible") ~= true
	if available then
		contextLabel.Text = actionName == "Train"
			and (trainingEligible and ("TRAIN +%s/s | %s"):format(formatNumber(trainingGain), targetName)
				or ("LOCKED | NEED %s POWER"):format(formatNumber(trainingRequired)))
			or targetName
	end

	local button = shared.PunchWallContextActionButton
	if button then
		button.Visible = available
			and gui:GetAttribute("PixelReferenceHUDActive") == true
			and not mainPanel.Visible
			and gui:GetAttribute("StandaloneModalVisible") ~= true
		button.Active = button.Visible and trainingEligible
		button.AutoButtonColor = button.Active
		button.Text = available and (actionName == "Train"
			and (trainingEligible
				and ("TRAIN +%s/s  |  %s"):format(formatNumber(trainingGain), string.upper(targetName))
				or ("LOCKED  |  NEED %s POWER"):format(formatNumber(trainingRequired)))
			or ("%s  |  %s"):format(string.upper(actionName), string.upper(targetName)))
			or "ACTION"
		button.BackgroundColor3 = actionName == "Train" and palette.Train or palette.Use
		button:SetAttribute("Action", actionName or "")
		button:SetAttribute("Target", targetName)
		button:SetAttribute("ExactRequestPayload", actionName or "")
		button:SetAttribute("TrainingEligible", trainingEligible)
		button:SetAttribute("TrainingRequiredPower", trainingRequired)
		button:SetAttribute("TrainingPowerPerSecond", trainingGain)
		local icon = button:FindFirstChild("ActionIcon")
		if icon then applyThemeIcon(icon, actionName == "Train" and "Train" or "Use") end
	end
	gui:SetAttribute("ContextualActionAvailable", available)
	gui:SetAttribute("ContextualActionName", actionName or "")
	gui:SetAttribute("ContextualActionTarget", targetName)
	gui:SetAttribute("ContextualTrainingEligible", trainingEligible)
	gui:SetAttribute("ContextualTrainingRequiredPower", trainingRequired)
	gui:SetAttribute("ContextualTrainingPowerPerSecond", trainingGain)
	gui:SetAttribute("ContextualActionScanInterval", 0.15)
	gui:SetAttribute("ContextualActionUsesExistingTargetScan", true)
end

local targetTimer = 0
RunService.Heartbeat:Connect(function(delta)
	targetTimer += delta
	if targetTimer < 0.15 then return end
	targetTimer = 0
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local gameRoot = clientRuntime.GameRoot
	if gameRoot and (gameRoot.Parent ~= workspace or gameRoot.Name ~= "PunchWallRPG") then
		clientRuntime.RefreshGameRoot()
		gameRoot = clientRuntime.GameRoot
	end
	if not rootPart or not gameRoot then
		clientRuntime.SetContextualAction(nil, nil)
		return
	end
	if (clientRuntime.WallsFolder and (clientRuntime.WallsFolder.Parent ~= gameRoot or clientRuntime.WallsFolder.Name ~= "Walls"))
		or (clientRuntime.InteractablesFolder and (clientRuntime.InteractablesFolder.Parent ~= gameRoot or clientRuntime.InteractablesFolder.Name ~= "Interactables"))
		or (clientRuntime.DepthBlocksFolder and (clientRuntime.DepthBlocksFolder.Parent ~= gameRoot or clientRuntime.DepthBlocksFolder.Name ~= "Depth Blocks"))
	then
		clientRuntime.TargetCacheMissCount += 1
		gui:SetAttribute("TargetCacheMissCount", clientRuntime.TargetCacheMissCount)
		clientRuntime.RefreshTargetFolderCache()
	end
	local nearest
	local nearestDistance = 44
	local nearestWall
	local nearestWallDistance = 50
	for folderIndex = 1, 2 do
		local folder = folderIndex == 1 and clientRuntime.WallsFolder or clientRuntime.InteractablesFolder
		if folder then
			for _, candidate in ipairs(folder:GetChildren()) do
				if candidate:IsA("BasePart") then
					local distance = (candidate.Position - rootPart.Position).Magnitude
					if distance < nearestDistance then nearest, nearestDistance = candidate, distance end
					if folderIndex == 1 and distance < nearestWallDistance then nearestWall, nearestWallDistance = candidate, distance end
				end
			end
		end
	end
	local depthBlocks = clientRuntime.DepthBlocksFolder
	if depthBlocks then
		for _, block in ipairs(workspace:GetPartBoundsInRadius(rootPart.Position, 38, clientRuntime.TargetDepthOverlap)) do
			if block:GetAttribute("IsDepthBlock") and not block:GetAttribute("Broken") then
				local offset = block.Position - rootPart.Position
				local distance = offset.Magnitude
				local facing = distance > 0 and rootPart.CFrame.LookVector:Dot(offset.Unit) or 1
				if facing > -0.1 and distance < nearestWallDistance then
					nearestWall, nearestWallDistance = block, distance
				end
				if facing > -0.1 and distance < nearestDistance then
					nearest, nearestDistance = block, distance
				end
			end
		end
	end
	local focusedWall = nearestWall and nearestWallDistance <= 24 and nearestWall.Name ~= "Titan Server Wall"
	gui:SetAttribute("CombatCameraActive", false)
	local tutorial = latestStats.Tutorial
	local tutorialTarget
	if type(tutorial) == "table" and tutorial.target and tutorial.target ~= "" then
		local walls = clientRuntime.WallsFolder
		local interactables = clientRuntime.InteractablesFolder
		tutorialTarget = (walls and walls:FindFirstChild(tutorial.target)) or (interactables and interactables:FindFirstChild(tutorial.target))
	end
	if tutorialTarget and tutorialTarget:IsA("BasePart") then
		local distance = math.floor((tutorialTarget.Position - rootPart.Position).Magnitude + 0.5)
		tutorialWaypoint.Adornee = tutorialTarget
		-- At interaction range the target itself is clearer than a large billboard
		-- covering it. Keep the objective state valid while collapsing the marker.
		tutorialWaypoint.Enabled = distance > 18
		tutorialWaypointLabel.Text = ("NEXT: %s\n%d studs"):format(string.upper(tostring(tutorial.title or tutorial.target)), distance)
		help.Text = tutorialObjectiveText .. ("  |  %d studs"):format(distance)
		gui:SetAttribute("OnboardingWaypointReady", true)
		gui:SetAttribute("OnboardingWaypointTarget", tutorialTarget.Name)
		gui:SetAttribute("OnboardingWaypointVisible", tutorialWaypoint.Enabled)
	else
		tutorialWaypoint.Adornee = nil
		tutorialWaypoint.Enabled = false
		help.Text = tutorialObjectiveText
		gui:SetAttribute("OnboardingWaypointReady", false)
		gui:SetAttribute("OnboardingWaypointTarget", "")
		gui:SetAttribute("OnboardingWaypointVisible", false)
	end
	local nearbyAction = not focusedWall
		and nearest
		and nearestDistance <= 18
	local contextualAction
	if nearbyAction and clientRuntime.IsTrainingTarget(nearest) then
		contextualAction = "Train"
	elseif nearbyAction and clientRuntime.IsUseTarget(nearest) then
		contextualAction = "Use"
	end
	clientRuntime.SetContextualAction(contextualAction, contextualAction and nearest or nil)
	targetHUD.Visible = false
end)
end

gui:SetAttribute("CombatCameraActive", false)
if workspace.CurrentCamera and workspace.CurrentCamera.CameraType == Enum.CameraType.Scriptable then
	workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
end
local cameraOcclusionApplied = player.DevCameraOcclusionMode == Enum.DevCameraOcclusionMode.Invisicam
gui:SetAttribute("CameraOcclusionMode", cameraOcclusionApplied and "OpaqueInvisicam" or "Unavailable")
gui:SetAttribute("CameraOcclusionOpaque", cameraOcclusionApplied)
gui:SetAttribute("PreservePlayerZoomInTunnels", cameraOcclusionApplied)

-- Roblox Invisicam normally fades parts between the camera and the character.
-- Keep the zoom-preserving occlusion mode, but restore the obscuring parts to
-- full local opacity after the camera update so the world stays visually solid.
if cameraOcclusionApplied then
	shared.PunchWallForcedOpaqueParts = setmetatable({}, { __mode = "k" })
	RunService:BindToRenderStep("PunchWallOpaqueOcclusion", Enum.RenderPriority.Last.Value, function()
		local camera = workspace.CurrentCamera
		local character = player.Character
		if not camera or not character then return end
		local targets = { camera.Focus.Position }
		local head = character:FindFirstChild("Head")
		local root = character:FindFirstChild("HumanoidRootPart")
		local upperTorso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
		if head then table.insert(targets, head.Position) end
		if root then table.insert(targets, root.Position) end
		if upperTorso then table.insert(targets, upperTorso.Position) end
		for part in pairs(shared.PunchWallForcedOpaqueParts) do
			if part.Parent then part.LocalTransparencyModifier = 0 else shared.PunchWallForcedOpaqueParts[part] = nil end
		end
		local obscuringParts = camera:GetPartsObscuringTarget(targets, { character })
		for _, part in ipairs(obscuringParts) do
			if part:IsA("BasePart") then
				part.LocalTransparencyModifier = 0
				shared.PunchWallForcedOpaqueParts[part] = true
			end
		end
	end)
end

local bossHudTimer = 0
RunService.Heartbeat:Connect(function(delta)
	bossHudTimer += delta
	if bossHudTimer < 0.2 then return end
	bossHudTimer = 0
	if gui:GetAttribute("PixelReferenceHUDActive") == true then
		bossHUD.Visible = false
		help.Visible = false
		return
	end
	local gameRoot = workspace:FindFirstChild("PunchWallRPG")
	local walls = gameRoot and gameRoot:FindFirstChild("Walls")
	local boss = walls and walls:FindFirstChild("Titan Server Wall")
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local modalVisible = mainPanel.Visible or gui:GetAttribute("StandaloneModalVisible") == true
	if not boss or not rootPart then bossHUD.Visible = false help.Visible = not modalVisible return end
	local hp = boss:GetAttribute("HP") or 0
	local maxHP = math.max(1, boss:GetAttribute("MaxHP") or 1)
	local broken = boss:GetAttribute("Broken") == true
	local nearby = (boss.Position - rootPart.Position).Magnitude <= 55
	bossHUD.Visible = (broken or nearby or hp < maxHP) and not targetHUD.Visible and not modalVisible
	help.Visible = not modalVisible
	if not bossHUD.Visible then return end
	local phase = boss:GetAttribute("BossPhase") or 1
	bossTitle.Text = UserInputService.TouchEnabled and ("TITAN P%d  |  WEAK x1.5"):format(phase)
		or ("TITAN HQ  |  PHASE %d  |  WEAK POINT x1.5"):format(phase)
	bossFill.Size = UDim2.fromScale(math.clamp(hp / maxHP, 0, 1), 1)
	if broken then
		local remaining = math.max(0, math.ceil((boss:GetAttribute("RespawnAt") or 0) - workspace:GetServerTimeNow()))
		bossSubtitle.Text = ("RECONSTRUCTING IN %ds"):format(remaining)
	else
		local nextAttackAt = boss:GetAttribute("NextAttackAt") or 0
		local remaining = math.max(0, math.ceil(nextAttackAt - workspace:GetServerTimeNow()))
		if UserInputService.TouchEnabled then
			bossSubtitle.Text = nextAttackAt > 0 and ("HP %s/%s  |  SHOCKWAVE %ds"):format(formatNumber(hp), formatNumber(maxHP), remaining)
				or ("HP %s/%s  |  TARGET RED CORES"):format(formatNumber(hp), formatNumber(maxHP))
		else
			local attackText = nextAttackAt > 0 and ("  |  SHOCKWAVE %ds"):format(remaining) or ""
			bossSubtitle.Text = ("HP %s / %s  |  %d participant(s)%s"):format(formatNumber(hp), formatNumber(maxHP), boss:GetAttribute("ParticipantCount") or 0, attackText)
		end
	end
end)

local punchHeld = false
local function setPunchHeld(value)
	if punchHeld == value then return end
	punchHeld = value
	if value then
			task.spawn(function()
				while punchHeld do
					tryPunchAction()
					task.wait(1)
				end
			end)
	end
end

-- The production HUD uses pixel crops from the approved 1672x941 design.
-- Gameplay values and hitboxes remain live while the visual shell stays exact.
shared.PunchWallClientFinalize = function()
local referenceHUD = Instance.new("Frame")
referenceHUD.Name = "PixelPerfectHeroCityHUD"
referenceHUD.BackgroundTransparency = 1
referenceHUD.Size = UDim2.fromScale(1, 1)
referenceHUD.ZIndex = 30
referenceHUD.Parent = gui
gui:SetAttribute("PixelReferenceHUDActive", true)

local function designRect(x, y, width, height)
	return UDim2.fromScale(x / 1672, y / 941), UDim2.fromScale(width / 1672, height / 941)
end

local rankWidgets = (function()
	local widgets = {}
	local rankHUD = Instance.new("Frame")
	rankHUD.Name = "DepthRankHUD"
	rankHUD.Position, rankHUD.Size = designRect(108, 154, 140, 322)
	rankHUD.BackgroundTransparency = 1
	rankHUD.BorderSizePixel = 0
	rankHUD.ZIndex = 34
	rankHUD.Parent = referenceHUD
	widgets.Root = rankHUD
	widgets.Title = Instance.new("TextLabel")
	widgets.Title.Name = "RankTitleData"
	widgets.Title.Visible = false
	widgets.Title.Parent = rankHUD
	widgets.Stats = widgets.Title:Clone()
	widgets.Stats.Name = "RankStatsData"
	widgets.Stats.Parent = rankHUD
	local track = Instance.new("Frame")
	track.Name = "DepthRaceTrack"
	track.AnchorPoint = Vector2.new(0.5, 0)
	track.Position = UDim2.fromScale(0.28, 0.04)
	track.Size = UDim2.fromScale(0.055, 0.92)
	track.BackgroundColor3 = Color3.fromRGB(29, 74, 94)
	track.BorderSizePixel = 0
	track.ZIndex = 35
	track.Parent = rankHUD
	setRounded(track, 8)
	local trackStroke = Instance.new("UIStroke")
	trackStroke.Color = Color3.fromRGB(41, 204, 247)
	trackStroke.Thickness = 2
	trackStroke.Transparency = 0.15
	trackStroke.Parent = track
	local trackFill = Instance.new("Frame")
	trackFill.Name = "PlayerDepthFill"
	trackFill.AnchorPoint = Vector2.new(0.5, 1)
	trackFill.Position = UDim2.fromScale(0.5, 1)
	trackFill.Size = UDim2.fromScale(1, 0)
	trackFill.BackgroundColor3 = Color3.fromRGB(38, 204, 247)
	trackFill.BorderSizePixel = 0
	trackFill.ZIndex = 36
	trackFill.Parent = track
	setRounded(trackFill, 8)
	widgets.TrackFill = trackFill
	widgets.Markers = {}
	for index = 1, 5 do
		local marker = Instance.new("ImageLabel")
		marker.Name = "HeroDepthMarker" .. index
		marker.AnchorPoint = Vector2.new(0.5, 0.5)
		marker.Position = UDim2.fromScale(0.5, 1)
		marker.Size = UDim2.fromOffset(34, 34)
		marker.BackgroundColor3 = Color3.fromRGB(25, 43, 54)
		marker.BorderSizePixel = 0
		marker.ScaleType = Enum.ScaleType.Crop
		marker.ZIndex = 38 + index
		marker.Visible = false
		marker.Parent = track
		setRounded(marker, 16)
		local markerStroke = Instance.new("UIStroke")
		markerStroke.Name = "MarkerStroke"
		markerStroke.Color = index == 1 and Color3.fromRGB(255, 210, 57) or Color3.fromRGB(46, 194, 242)
		markerStroke.Thickness = 2
		markerStroke.Parent = marker
		local markerName = Instance.new("TextLabel")
		markerName.Name = "HeroName"
		markerName.AnchorPoint = Vector2.new(0, 0.5)
		markerName.Position = UDim2.new(1, 7, 0.5, 0)
		markerName.Size = UDim2.fromOffset(78, 28)
		markerName.BackgroundTransparency = 1
		markerName.Font = Enum.Font.GothamBold
		markerName.Text = ""
		markerName.TextColor3 = Color3.fromRGB(238, 242, 244)
		markerName.TextSize = 8
		markerName.TextStrokeTransparency = 0.25
		markerName.TextWrapped = false
		markerName.TextTruncate = Enum.TextTruncate.AtEnd
		markerName.ZIndex = marker.ZIndex
		markerName.Parent = marker
		widgets.Markers[index] = { avatar = marker, name = markerName, stroke = markerStroke }
	end
	rankHUD:SetAttribute("Layout", "VerticalUnframed")
	return widgets
end)()

local function referenceImage(name, asset, x, y, width, height, parent)
	local imageLabel = Instance.new("ImageLabel")
	imageLabel.Name = name
	imageLabel.BackgroundTransparency = 1
	imageLabel.BorderSizePixel = 0
	imageLabel.Image = asset
	imageLabel.ScaleType = Enum.ScaleType.Stretch
	imageLabel.Position, imageLabel.Size = designRect(x, y, width, height)
	imageLabel.ZIndex = 31
	imageLabel.Parent = parent or referenceHUD
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = width / height
	aspect.DominantAxis = Enum.DominantAxis.Height
	aspect.Parent = imageLabel
	return imageLabel
end

local function referenceButton(name, asset, x, y, width, height, callback)
	local button = Instance.new("ImageButton")
	button.Name = name
	button.BackgroundTransparency = 1
	button.BorderSizePixel = 0
	button.Image = asset
	button.ScaleType = Enum.ScaleType.Stretch
	button.Position, button.Size = designRect(x, y, width, height)
	button.AutoButtonColor = false
	button.ZIndex = 31
	button.Parent = referenceHUD
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = width / height
	aspect.DominantAxis = Enum.DominantAxis.Height
	aspect.Parent = button
	if callback then button.Activated:Connect(callback) end
	return button
end

local function enforceReferenceTouchTarget(button)
	button:SetAttribute("MinimumTouchTarget", 44)
	local constraint = button:FindFirstChild("MinimumTouchTarget")
	if not constraint then
		constraint = Instance.new("UISizeConstraint")
		constraint.Name = "MinimumTouchTarget"
		constraint.MinSize = Vector2.new(44, 44)
		constraint.Parent = button
	end
	return button
end

local pixel = GameConfig.HeroCityPixelUI
local referencePowerCard = referenceImage("PowerCard", pixel.Power, 415, 23, 279, 103)
local referenceCoinsCard = referenceImage("CoinsCard", pixel.Coins, 702, 22, 330, 104)
local referenceWallCard = referenceImage("WallCard", pixel.Wall, 1041, 23, 252, 103)
shared.PunchWallHUDWidgets = {
	QuestCard = referenceImage("QuestCard", pixel.QuestCard, 1368, 117, 294, 134),
	NextWorldCard = referenceImage("NextWorldCard", pixel.NextWorld, 1020, 778, 194, 145),
}
shared.PunchWallBuildHonorHUD = function()
	local honorCard = Instance.new("Frame")
	honorCard.Name = "HonorCurrencyHUD"
	honorCard.Position, honorCard.Size = designRect(1218, 132, 137, 58)
	honorCard.BackgroundColor3 = Color3.fromRGB(8, 15, 20)
	honorCard.BackgroundTransparency = 0.03
	honorCard.BorderSizePixel = 0
	honorCard.ZIndex = 34
	honorCard.Parent = referenceHUD
	setRounded(honorCard, 5)
	local honorStroke = Instance.new("UIStroke")
	honorStroke.Color = Color3.fromRGB(255, 198, 43)
	honorStroke.Thickness = 2
	honorStroke.Parent = honorCard
	local honorIcon = Instance.new("ImageLabel")
	honorIcon.Name = "HonorIcon"
	honorIcon.BackgroundTransparency = 1
	honorIcon.Position = UDim2.fromScale(0.035, 0.08)
	honorIcon.Size = UDim2.fromScale(0.29, 0.84)
	honorIcon.Image = GameConfig.ShopArt.HonorIcon
	honorIcon.ScaleType = Enum.ScaleType.Fit
	honorIcon.ZIndex = 35
	honorIcon.Parent = honorCard
	local honorLabel = Instance.new("TextLabel")
	honorLabel.Name = "HonorLabel"
	honorLabel.BackgroundTransparency = 1
	honorLabel.Position = UDim2.fromScale(0.34, 0.08)
	honorLabel.Size = UDim2.fromScale(0.61, 0.32)
	honorLabel.Font = Enum.Font.GothamBold
	honorLabel.Text = "HONOR"
	honorLabel.TextColor3 = Color3.fromRGB(255, 214, 72)
	honorLabel.TextScaled = true
	honorLabel.TextXAlignment = Enum.TextXAlignment.Left
	honorLabel.ZIndex = 35
	honorLabel.Parent = honorCard
	local honorValue = honorLabel:Clone()
	honorValue.Name = "HonorValue"
	honorValue.Position = UDim2.fromScale(0.34, 0.38)
	honorValue.Size = UDim2.fromScale(0.61, 0.5)
	honorValue.Font = Enum.Font.GothamBlack
	honorValue.Text = "0"
	honorValue.TextColor3 = Color3.fromRGB(244, 246, 242)
	honorValue.Parent = honorCard
	local honorOpen = Instance.new("TextButton")
	honorOpen.Name = "OpenHonorMenu"
	honorOpen.BackgroundTransparency = 1
	honorOpen.Text = ""
	honorOpen.Size = UDim2.fromScale(1, 1)
	honorOpen.ZIndex = 36
	honorOpen.Active = true
	honorOpen.Selectable = true
	honorOpen.Parent = honorCard
	honorOpen.Activated:Connect(function()
		shared.PunchWallSelectedHonorItemId = nil
		gui:SetAttribute("SelectedHonorItemId", nil)
		openGameTab("Honor")
	end)
	honorCard:SetAttribute("OpensMenu", "Honor")
	shared.PunchWallHUDWidgets.HonorValue = honorValue
end
shared.PunchWallBuildHonorHUD()
local referenceJoystick = referenceImage("MovementJoystick", pixel.Joystick, 57, 640, 270, 270)
referenceJoystick.Active = true
shared.PunchWallSoundToolButton = referenceButton("SoundTool", pixel.SoundTool, 1465, 22, 60, 64, function()
	shared.PunchWallApplySoundSetting(not clientSettings.sound, true)
end)
shared.PunchWallSoundToolButton:SetAttribute("ToolAction", "ToggleSound")
shared.PunchWallSettingsToolButton = referenceButton("SettingsTool", pixel.SettingsTool, 1526, 22, 60, 64, function() shared.PunchWallOpenSettingsPanel("reference_settings") end)
shared.PunchWallSettingsToolButton:SetAttribute("ToolAction", "OpenSettings")
shared.PunchWallMoreToolButton = referenceButton("MoreTool", pixel.MoreTool, 1587, 22, 64, 64, function()
	openGameTab("Tasks")
end)
shared.PunchWallMoreToolButton:SetAttribute("ToolAction", "OpenGameMenu")
shared.PunchWallApplySoundSetting(clientSettings.sound, false)

referenceHUD:SetAttribute("StudioTestControlLocation", RunService:IsStudio() and "SettingsOnly" or "Unavailable")

local referenceDaily = referenceButton("DailyButton", pixel.Daily, 16, 201, 82, 111, function() openGameTab("Tasks") end)
referenceDaily:SetAttribute("ToolAction", "OpenDaily")
local referenceSpin = referenceButton("SpinButton", pixel.Spin, 16, 316, 82, 111, function()
	if shared.PunchWallOpenSpin then shared.PunchWallOpenSpin() else requestAction("Spin") end
end)
referenceSpin:SetAttribute("ToolAction", "OpenSpin")
shared.PunchWallReferenceRebirth = referenceButton("RebirthButton", pixel.Rebirth, 16, 429, 82, 111, function() shared.PunchWallOpenRebirthPanel("reference_hud") end)
shared.PunchWallReferenceRebirth:SetAttribute("ToolAction", "OpenRebirthReview")
local rightMenuIconWidth = 87
local rightMenuIconHeight = 111
local rightMenuIconGap = 3
local rightMenuTop = 296
local rightMenuColumnX = 1570
local inventoryMenuX = rightMenuColumnX - rightMenuIconWidth - rightMenuIconGap
referenceHUD:SetAttribute("RightMenuLayoutMode", "UniformIconGridV1")
referenceHUD:SetAttribute("RightMenuIconSize", string.format("%dx%d", rightMenuIconWidth, rightMenuIconHeight))
referenceHUD:SetAttribute("RightMenuIconGap", rightMenuIconGap)
referenceHUD:SetAttribute("RightMenuArtMode", "AspectSafeCropWithUniformFrameV2")
referenceHUD:SetAttribute("RightMenuOpticalBox", "81x86@3,0")
local uploadedInventoryIcon = type(pixel.Inventory) == "string"
	and string.match(pixel.Inventory, "^rbxassetid://%d+$") ~= nil
local inventoryIconAsset = uploadedInventoryIcon and pixel.Inventory or pixel.MoreTool
local inventoryIconSourceMode = uploadedInventoryIcon and "UploadedUserAsset" or "ApprovedAssetFallback"
local referenceInventory = referenceButton(
	"InventoryButton",
	inventoryIconAsset,
	inventoryMenuX,
	rightMenuTop,
	rightMenuIconWidth,
	rightMenuIconHeight,
	function()
	openGameTab("Inventory")
	end
)
referenceInventory:SetAttribute("ToolAction", "OpenInventory")
referenceInventory:SetAttribute("MenuRow", "Shop")
referenceInventory:SetAttribute("IconSourceMode", inventoryIconSourceMode)
referenceInventory:SetAttribute("IconSourcePath", "work/assets/user-supplied/inventory-hud-icon.png")
referenceInventory:SetAttribute("IconSourceSHA256", "06E7F1F97D3EDBB9E5638D7CF2A72C4935BFBC8C299D8FCBBF6230E0573A497A")
referenceInventory:SetAttribute("PendingAssetUpload", not uploadedInventoryIcon)
referenceInventory:SetAttribute("FallbackAssetId", pixel.MoreTool)
local inventoryMinTarget = Instance.new("UISizeConstraint")
inventoryMinTarget.Name = "MinimumTouchTarget"
inventoryMinTarget.MinSize = Vector2.new(44, 44)
inventoryMinTarget.Parent = referenceInventory
local inventoryFallbackLabel = Instance.new("TextLabel")
inventoryFallbackLabel.Name = "FallbackInventoryLabel"
inventoryFallbackLabel.AnchorPoint = Vector2.new(0.5, 1)
inventoryFallbackLabel.Position = UDim2.fromScale(0.5, 1)
inventoryFallbackLabel.Size = UDim2.new(1, 8, 0.22, 0)
inventoryFallbackLabel.BackgroundColor3 = Color3.fromRGB(7, 15, 23)
inventoryFallbackLabel.BackgroundTransparency = 0.08
inventoryFallbackLabel.BorderSizePixel = 0
inventoryFallbackLabel.Font = Enum.Font.GothamBlack
inventoryFallbackLabel.Text = "INVENTORY"
inventoryFallbackLabel.TextColor3 = Color3.fromRGB(235, 244, 249)
inventoryFallbackLabel.TextScaled = true
inventoryFallbackLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
inventoryFallbackLabel.TextStrokeTransparency = 0.15
inventoryFallbackLabel.Visible = not uploadedInventoryIcon
inventoryFallbackLabel.ZIndex = referenceInventory.ZIndex + 1
inventoryFallbackLabel.Parent = referenceInventory
local inventoryFallbackTextSize = Instance.new("UITextSizeConstraint")
inventoryFallbackTextSize.MinTextSize = 7
inventoryFallbackTextSize.MaxTextSize = 12
inventoryFallbackTextSize.Parent = inventoryFallbackLabel
referenceHUD:SetAttribute("InventoryIconSourceMode", inventoryIconSourceMode)
referenceHUD:SetAttribute("InventoryIconPendingUpload", not uploadedInventoryIcon)
local referenceShop = referenceButton("ShopButton", pixel.Shop, rightMenuColumnX, rightMenuTop, rightMenuIconWidth, rightMenuIconHeight, function() openGameTab("Fists") end)
local referencePets = referenceButton("PetsButton", pixel.Pets, rightMenuColumnX, rightMenuTop + rightMenuIconHeight + rightMenuIconGap, rightMenuIconWidth, rightMenuIconHeight, function() openGameTab("Pets") end)
local referenceQuests = referenceButton("QuestsButton", pixel.Quests, rightMenuColumnX, rightMenuTop + (rightMenuIconHeight + rightMenuIconGap) * 2, rightMenuIconWidth, rightMenuIconHeight, function() openGameTab("Tasks") end)

for _, touchTarget in ipairs({
	referenceDaily,
	referenceSpin,
	shared.PunchWallSoundToolButton,
	shared.PunchWallSettingsToolButton,
	shared.PunchWallMoreToolButton,
}) do
	enforceReferenceTouchTarget(touchTarget)
end

local function applyRightMenuOpticalArt(button, cropOffset, cropSize, displaySize)
	button.ImageTransparency = 1
	button:SetAttribute("ArtPresentation", "AspectSafeCropWithUniformFrameV2")
	button:SetAttribute("ArtCrop", string.format(
		"%d,%d,%d,%d",
		cropOffset.X,
		cropOffset.Y,
		cropSize.X,
		cropSize.Y
	))
	button:SetAttribute("ArtDisplaySize", string.format("%dx%d", displaySize.X, displaySize.Y))
	local opticalFrame = Instance.new("Frame")
	opticalFrame.Name = "RightMenuOpticalFrame"
	opticalFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	opticalFrame.Position = UDim2.fromScale(43.5 / rightMenuIconWidth, 43 / rightMenuIconHeight)
	opticalFrame.Size = UDim2.fromScale(81 / rightMenuIconWidth, 86 / rightMenuIconHeight)
	opticalFrame.BackgroundColor3 = Color3.fromRGB(5, 12, 19)
	opticalFrame.BackgroundTransparency = 0.38
	opticalFrame.BorderSizePixel = 0
	opticalFrame.Active = false
	opticalFrame.Selectable = false
	opticalFrame.ZIndex = button.ZIndex
	opticalFrame:SetAttribute("OpticalBox", "81x86@3,0")
	opticalFrame.Parent = button
	local opticalCorner = Instance.new("UICorner")
	opticalCorner.CornerRadius = UDim.new(0.1, 0)
	opticalCorner.Parent = opticalFrame
	local opticalStroke = Instance.new("UIStroke")
	opticalStroke.Name = "UniformBorder"
	opticalStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	opticalStroke.Color = Color3.fromRGB(61, 94, 116)
	opticalStroke.Thickness = 1.25
	opticalStroke.Transparency = 0.08
	opticalStroke.Parent = opticalFrame
	local art = Instance.new("ImageLabel")
	art.Name = "RightMenuArt"
	art.AnchorPoint = Vector2.new(0.5, 0.5)
	art.Position = UDim2.fromScale(0.5, 0.5)
	art.Size = UDim2.fromScale(displaySize.X / 81, displaySize.Y / 86)
	art.BackgroundTransparency = 1
	art.BorderSizePixel = 0
	art.Image = button.Image
	art.ImageRectOffset = cropOffset
	art.ImageRectSize = cropSize
	-- ImageRectSize changes the sampled region, but Roblox Fit still uses the full
	-- texture aspect ratio. The display boxes below match each crop's own aspect,
	-- so Stretch maps the crop 1:1 without the tall distortion of the old buttons.
	art.ScaleType = Enum.ScaleType.Stretch
	art.Active = false
	art.Selectable = false
	art.ZIndex = button.ZIndex + 1
	art:SetAttribute("OpticalBox", "81x86@3,0")
	art:SetAttribute("PreserveAspectRatio", true)
	art:SetAttribute("AspectSafeCrop", true)
	art.Parent = opticalFrame
end

applyRightMenuOpticalArt(referenceInventory, Vector2.new(51, 28), Vector2.new(395, 439), Vector2.new(72, 80))
applyRightMenuOpticalArt(referenceShop, Vector2.new(6, 3), Vector2.new(75, 80), Vector2.new(75, 80))
applyRightMenuOpticalArt(referencePets, Vector2.new(6, 2), Vector2.new(76, 76), Vector2.new(76, 76))
applyRightMenuOpticalArt(referenceQuests, Vector2.new(8, 2), Vector2.new(72, 71), Vector2.new(76, 75))

local referencePunch = referenceButton("ActionPunch", pixel.Punch, 1211, 669, 250, 250)
referencePunch.MouseButton1Down:Connect(function() setPunchHeld(true) end)
referencePunch.MouseButton1Up:Connect(function() setPunchHeld(false) end)
referencePunch.MouseLeave:Connect(function() setPunchHeld(false) end)
local referenceJump = referenceButton("ActionJump", pixel.Jump, 1460, 694, 211, 211, function()
	requestHumanoidJump()
end)

local responsiveHudDiagnosticsGeneration = 0
local function scheduleResponsiveHudDiagnostics(compact)
	responsiveHudDiagnosticsGeneration += 1
	local generation = responsiveHudDiagnosticsGeneration
	task.defer(function()
		RunService.Heartbeat:Wait()
		if generation ~= responsiveHudDiagnosticsGeneration then return end
		local questPosition, questSize = referenceQuests.AbsolutePosition, referenceQuests.AbsoluteSize
		local jumpPosition, jumpSize = referenceJump.AbsolutePosition, referenceJump.AbsoluteSize
		local gapX = math.max(
			jumpPosition.X - (questPosition.X + questSize.X),
			questPosition.X - (jumpPosition.X + jumpSize.X)
		)
		local gapY = math.max(
			jumpPosition.Y - (questPosition.Y + questSize.Y),
			questPosition.Y - (jumpPosition.Y + jumpSize.Y)
		)
		local noOverlap = gapX >= 0 or gapY >= 0
		referenceHUD:SetAttribute("ResponsivePairwiseGeometryVersion", "QuestsJumpV1")
		referenceHUD:SetAttribute("QuestsJumpPairwiseNoOverlap", noOverlap)
		referenceHUD:SetAttribute("QuestsJumpPairwiseGapX", gapX)
		referenceHUD:SetAttribute("QuestsJumpPairwiseGapY", gapY)
		referenceQuests:SetAttribute("PairwisePeer", "ActionJump")
		referenceQuests:SetAttribute("PairwiseNoOverlap", noOverlap)
		referenceJump:SetAttribute("PairwisePeer", "QuestsButton")
		referenceJump:SetAttribute("PairwiseNoOverlap", noOverlap)

		local minimumTarget = math.huge
		for _, button in ipairs({
			referenceDaily,
			referenceSpin,
			shared.PunchWallSoundToolButton,
			shared.PunchWallSettingsToolButton,
			shared.PunchWallMoreToolButton,
		}) do
			local actual = math.min(button.AbsoluteSize.X, button.AbsoluteSize.Y)
			minimumTarget = math.min(minimumTarget, actual)
			button:SetAttribute("RuntimeMinimumTouchTarget", actual)
			button:SetAttribute("RuntimeTouchTargetPass", actual >= 44)
		end
		referenceHUD:SetAttribute("CompactUtilityTouchTargets", "Daily,Spin,Sound,Settings,More")
		referenceHUD:SetAttribute("CompactUtilityMinimumTouchTarget", minimumTarget)
		referenceHUD:SetAttribute("CompactUtilityTouchTargetsPass", not compact or minimumTarget >= 44)

		local settingsPanel = shared.PunchWallStandaloneWindows.SettingsPanel
		local settingsBody = shared.PunchWallStandaloneWindows.SettingsBody
		local contained, rowCount = true, 0
		for _, rowName in ipairs({ "SOUNDSetting", "MOTIONSetting", "UI SIZESetting" }) do
			local row = settingsBody:FindFirstChild(rowName)
			if row and row:IsA("GuiObject") then
				rowCount += 1
				local rowPosition, rowSize = row.AbsolutePosition, row.AbsoluteSize
				local rowContained = true
				for _, descendant in ipairs(row:GetDescendants()) do
					if descendant:IsA("GuiObject") and descendant.Visible then
						local position, size = descendant.AbsolutePosition, descendant.AbsoluteSize
						local inside = position.X >= rowPosition.X - 0.5
							and position.Y >= rowPosition.Y - 0.5
							and position.X + size.X <= rowPosition.X + rowSize.X + 0.5
							and position.Y + size.Y <= rowPosition.Y + rowSize.Y + 0.5
						rowContained = rowContained and inside
					end
				end
				row:SetAttribute("CompactDescendantsContained", rowContained)
				contained = contained and rowContained
			end
		end
		settingsPanel:SetAttribute("CompactSettingsContainmentVersion", "RowContainedV1")
		settingsPanel:SetAttribute("CompactSettingsRowCount", rowCount)
		settingsPanel:SetAttribute("CompactSettingsRowsContained", not compact or (rowCount == 3 and contained))
	end)
end

shared.PunchWallContextActionButton = Instance.new("TextButton")
shared.PunchWallContextActionButton.Name = "ContextAction"
shared.PunchWallContextActionButton.AnchorPoint = Vector2.new(0.5, 1)
shared.PunchWallContextActionButton.Position = UDim2.fromScale(0.56, 0.79)
shared.PunchWallContextActionButton.Size = UDim2.fromScale(0.22, 0.078)
shared.PunchWallContextActionButton.BackgroundColor3 = palette.Use
shared.PunchWallContextActionButton.BackgroundTransparency = 0.04
shared.PunchWallContextActionButton.BorderSizePixel = 0
shared.PunchWallContextActionButton.AutoButtonColor = true
shared.PunchWallContextActionButton.Font = Enum.Font.GothamBlack
shared.PunchWallContextActionButton.Text = "ACTION"
shared.PunchWallContextActionButton.TextColor3 = Color3.fromRGB(255, 255, 255)
shared.PunchWallContextActionButton.TextScaled = true
shared.PunchWallContextActionButton.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
shared.PunchWallContextActionButton.TextStrokeTransparency = 0.22
shared.PunchWallContextActionButton.TextXAlignment = Enum.TextXAlignment.Right
shared.PunchWallContextActionButton.Visible = false
shared.PunchWallContextActionButton.Active = false
shared.PunchWallContextActionButton.Selectable = true
shared.PunchWallContextActionButton.ZIndex = 44
shared.PunchWallContextActionButton.Parent = referenceHUD
setRounded(shared.PunchWallContextActionButton, 8)
local contextActionStroke = Instance.new("UIStroke")
contextActionStroke.Color = Color3.fromRGB(255, 213, 67)
contextActionStroke.Thickness = 3
contextActionStroke.Transparency = 0.04
contextActionStroke.Parent = shared.PunchWallContextActionButton
local contextActionPadding = Instance.new("UIPadding")
contextActionPadding.PaddingLeft = UDim.new(0, 54)
contextActionPadding.PaddingRight = UDim.new(0, 12)
contextActionPadding.Parent = shared.PunchWallContextActionButton
local contextActionSize = Instance.new("UISizeConstraint")
contextActionSize.MinSize = Vector2.new(160, 44)
contextActionSize.MaxSize = Vector2.new(340, 74)
contextActionSize.Parent = shared.PunchWallContextActionButton
local contextActionTextSize = Instance.new("UITextSizeConstraint")
contextActionTextSize.MinTextSize = 10
contextActionTextSize.MaxTextSize = 18
contextActionTextSize.Parent = shared.PunchWallContextActionButton
createThemeIcon(
	shared.PunchWallContextActionButton,
	"Use",
	UDim2.fromOffset(8, 7),
	UDim2.fromOffset(40, 40),
	"ActionIcon"
)
shared.PunchWallContextActionButton:SetAttribute("MinimumTouchTarget", 44)
shared.PunchWallContextActionButton:SetAttribute("SafeAreaLane", "CenterAboveTraining")
shared.PunchWallContextActionButton:SetAttribute("ReusesTargetScan", true)
shared.PunchWallContextActionButton:SetAttribute("Action", "")
shared.PunchWallContextActionButton:SetAttribute("Target", "")
shared.PunchWallContextActionButton.Activated:Connect(function()
	local actionName = shared.PunchWallContextActionButton:GetAttribute("Action")
	if actionName ~= "Train" and actionName ~= "Use" then return end
	gui:SetAttribute("LastContextualActionRequested", actionName)
	gui:SetAttribute("LastContextualActionTarget", shared.PunchWallContextActionButton:GetAttribute("Target") or "")
	requestAction(actionName)
end)
referenceHUD:SetAttribute("ContextualActionAffordance", "TargetScanV1")
referenceHUD:SetAttribute("ContextualActionMinimumTouchTarget", 44)
referenceHUD:SetAttribute("ContextualActionSafeAreaLane", "CenterAboveTraining")

local function makeDirectionalPunchButton(name, label, x, y, direction)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Position, button.Size = designRect(x, y, 76, 76)
	button.BackgroundColor3 = Color3.fromRGB(11, 20, 27)
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Font = Enum.Font.GothamBlack
	button.Text = label
	button.TextColor3 = direction == "Up" and Color3.fromRGB(70, 213, 255) or Color3.fromRGB(255, 95, 65)
	button.TextScaled = true
	button.TextStrokeColor3 = Color3.new(0, 0, 0)
	button.TextStrokeTransparency = 0.15
	button.ZIndex = 34
	button.Parent = referenceHUD
	setRounded(button, 38)
	local stroke = Instance.new("UIStroke")
	stroke.Color = direction == "Up" and Color3.fromRGB(37, 190, 244) or Color3.fromRGB(233, 45, 38)
	stroke.Thickness = 4
	stroke.Parent = button
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = 12
	constraint.MaxTextSize = 34
	constraint.Parent = button
	button:SetAttribute("PunchDirection", direction)
	button:SetAttribute("Tooltip", "Punch " .. string.lower(direction))
	button.Activated:Connect(function() tryPunchAction(direction) end)
	return button
end

makeDirectionalPunchButton("PunchUp", utf8.char(0x2191), 1190, 590, "Up")
makeDirectionalPunchButton("PunchDown", utf8.char(0x2193), 1280, 590, "Down")

local trainingOverlay = Instance.new("Frame")
trainingOverlay.Name = "TrainingStateHUD"
trainingOverlay.Position, trainingOverlay.Size = designRect(570, 788, 440, 104)
trainingOverlay.BackgroundColor3 = Color3.fromRGB(7, 17, 24)
trainingOverlay.BackgroundTransparency = 0.03
trainingOverlay.BorderSizePixel = 0
trainingOverlay.Visible = gui:GetAttribute("ContinuousTrainingAnimation") == true
trainingOverlay.ZIndex = 40
trainingOverlay.Parent = referenceHUD
setRounded(trainingOverlay, 6)
local trainingStroke = Instance.new("UIStroke")
trainingStroke.Color = Color3.fromRGB(41, 205, 249)
trainingStroke.Thickness = 3
trainingStroke.Parent = trainingOverlay
local trainingLabel = Instance.new("TextLabel")
trainingLabel.Name = "TrainingStatus"
trainingLabel.BackgroundTransparency = 1
trainingLabel.Position = UDim2.fromScale(0.04, 0.12)
trainingLabel.Size = UDim2.fromScale(0.56, 0.76)
trainingLabel.Font = Enum.Font.GothamBlack
trainingLabel.Text = ("TRAINING\n+%d POWER / SEC"):format(GameConfig.Training.PowerPerTick)
trainingLabel.TextColor3 = Color3.fromRGB(244, 247, 249)
trainingLabel.TextScaled = true
trainingLabel.TextXAlignment = Enum.TextXAlignment.Left
trainingLabel.ZIndex = 41
trainingLabel.Parent = trainingOverlay
shared.PunchWallTrainingLabel = trainingLabel
local trainingTextLimit = Instance.new("UITextSizeConstraint")
trainingTextLimit.MinTextSize = 10
trainingTextLimit.MaxTextSize = 24
trainingTextLimit.Parent = trainingLabel
local exitTraining = Instance.new("TextButton")
exitTraining.Name = "ExitTraining"
exitTraining.AnchorPoint = Vector2.new(1, 0.5)
exitTraining.Position = UDim2.fromScale(0.96, 0.5)
exitTraining.Size = UDim2.fromScale(0.34, 0.62)
exitTraining.BackgroundColor3 = Color3.fromRGB(205, 38, 35)
exitTraining.BorderSizePixel = 0
exitTraining.Font = Enum.Font.GothamBlack
exitTraining.Text = "EXIT"
exitTraining.TextColor3 = Color3.new(1, 1, 1)
exitTraining.TextScaled = true
exitTraining.ZIndex = 41
exitTraining.Parent = trainingOverlay
setRounded(exitTraining, 5)
exitTraining.Activated:Connect(function() actionRemote:FireServer({ action = "StopTraining" }) end)
shared.PunchWallTrainingOverlay = trainingOverlay
gui:SetAttribute("TrainingExitButtonReady", true)

local function dynamicMask(name, x, y, width, height, parent, baseWidth, baseHeight)
	local mask = Instance.new("Frame")
	mask.Name = name .. "Mask"
	mask.BackgroundColor3 = Color3.fromRGB(8, 15, 20)
	mask.BorderSizePixel = 0
	if parent then
		mask.Position = UDim2.fromScale(x / baseWidth, y / baseHeight)
		mask.Size = UDim2.fromScale(width / baseWidth, height / baseHeight)
	else
		mask.Position, mask.Size = designRect(x, y, width, height)
	end
	mask.ZIndex = 32
	mask.Parent = parent or referenceHUD
	local maskGradient = Instance.new("UIGradient")
	maskGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(8, 15, 20)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(6, 19, 27)),
	})
	maskGradient.Parent = mask
	return mask
end

local function dynamicValue(name, x, y, width, height, color, parent, baseWidth, baseHeight, maxTextSize)
	local value = Instance.new("TextLabel")
	value.Name = name
	value.BackgroundTransparency = 1
	if parent then
		value.Position = UDim2.fromScale(x / baseWidth, y / baseHeight)
		value.Size = UDim2.fromScale(width / baseWidth, height / baseHeight)
	else
		value.Position, value.Size = designRect(x, y, width, height)
	end
	value.Font = Enum.Font.RobotoCondensed
	value.Text = "0"
	value.TextColor3 = color
	value.TextScaled = true
	value.TextStrokeColor3 = Color3.new(0, 0, 0)
	value.TextStrokeTransparency = 0.25
	value.TextXAlignment = Enum.TextXAlignment.Left
	value.ZIndex = 33
	value.Parent = parent or referenceHUD
	local sizeLimit = Instance.new("UITextSizeConstraint")
	-- The approved HUD art is proportionally small on landscape phones. A low
	-- minimum lets TextScaled preserve the icon-safe number area instead of
	-- spilling into the lightning/plus artwork.
	sizeLimit.MinTextSize = 6
	sizeLimit.MaxTextSize = maxTextSize or 30
	sizeLimit.Parent = value
	return value
end

shared.PunchWallBuildDynamicReferenceHUD = function()
	local widgets = shared.PunchWallHUDWidgets
	dynamicMask("Power", 98, 39, 101, 50, referencePowerCard, 279, 103)
	dynamicMask("Coins", 96, 39, 132, 51, referenceCoinsCard, 330, 104)
	dynamicMask("Wall", 110, 10, 108, 82, referenceWallCard, 252, 103)
	widgets.PowerValue = dynamicValue("PowerValue", 103, 41, 78, 44, Color3.fromRGB(244, 244, 239), referencePowerCard, 279, 103, 26)
	widgets.CoinsValue = dynamicValue("CoinsValue", 101, 42, 104, 44, Color3.fromRGB(244, 244, 239), referenceCoinsCard, 330, 104, 26)
	widgets.DepthLabel = dynamicValue("DepthLabel", 120, 15, 84, 22, Color3.fromRGB(244, 244, 239), referenceWallCard, 252, 103, 14)
	widgets.DepthLabel.Text = "DEPTH"
	widgets.DepthValue = dynamicValue("DepthValue", 136, 40, 66, 46, Color3.fromRGB(39, 199, 247), referenceWallCard, 252, 103, 27)

	-- Cover the legacy green progress strip baked into the supplied quest art.
	-- Without this mask it protrudes to the left of the live progress bar.
	dynamicMask("QuestLegacyProgress", 0, 58, 78, 66, widgets.QuestCard, 294, 134)
	dynamicMask("QuestDynamic", 68, 12, 218, 111, widgets.QuestCard, 294, 134)
	widgets.QuestTitle = dynamicValue("QuestTitle", 78, 16, 196, 25, Color3.fromRGB(255, 204, 52), widgets.QuestCard, 294, 134, 15)
	widgets.QuestTitle.Text = "DAILY BREAKER"
	widgets.QuestDetail = dynamicValue("QuestDetail", 78, 43, 196, 22, Color3.fromRGB(244, 244, 239), widgets.QuestCard, 294, 134, 12)
	widgets.QuestTrack = Instance.new("Frame")
	widgets.QuestTrack.Name = "QuestProgressTrack"
	widgets.QuestTrack.Position = UDim2.fromScale(78 / 294, 71 / 134)
	widgets.QuestTrack.Size = UDim2.fromScale(196 / 294, 24 / 134)
	widgets.QuestTrack.BackgroundColor3 = Color3.fromRGB(32, 46, 50)
	widgets.QuestTrack.BorderSizePixel = 0
	widgets.QuestTrack.ZIndex = 33
	widgets.QuestTrack.Parent = widgets.QuestCard
	widgets.QuestFill = Instance.new("Frame")
	widgets.QuestFill.Name = "Fill"
	widgets.QuestFill.Size = UDim2.fromScale(0, 1)
	widgets.QuestFill.BackgroundColor3 = Color3.fromRGB(48, 198, 61)
	widgets.QuestFill.BorderSizePixel = 0
	widgets.QuestFill.ZIndex = 34
	widgets.QuestFill.Parent = widgets.QuestTrack
	widgets.QuestProgress = dynamicValue("QuestProgress", 78, 71, 196, 24, Color3.fromRGB(255, 255, 255), widgets.QuestCard, 294, 134, 13)
	widgets.QuestProgress.TextXAlignment = Enum.TextXAlignment.Center
	widgets.QuestReward = dynamicValue("QuestReward", 78, 99, 196, 19, Color3.fromRGB(255, 206, 54), widgets.QuestCard, 294, 134, 11)
	widgets.QuestReward.TextXAlignment = Enum.TextXAlignment.Center

	dynamicMask("NextWorldDynamic", 13, 91, 169, 40, widgets.NextWorldCard, 194, 145)
	widgets.WorldTrack = Instance.new("Frame")
	widgets.WorldTrack.Name = "WorldProgressTrack"
	widgets.WorldTrack.Position = UDim2.fromScale(17 / 194, 99 / 145)
	widgets.WorldTrack.Size = UDim2.fromScale(160 / 194, 24 / 145)
	widgets.WorldTrack.BackgroundColor3 = Color3.fromRGB(28, 43, 48)
	widgets.WorldTrack.BorderSizePixel = 0
	widgets.WorldTrack.ZIndex = 33
	widgets.WorldTrack.Parent = widgets.NextWorldCard
	widgets.WorldFill = Instance.new("Frame")
	widgets.WorldFill.Name = "Fill"
	widgets.WorldFill.Size = UDim2.fromScale(0, 1)
	widgets.WorldFill.BackgroundColor3 = Color3.fromRGB(45, 202, 68)
	widgets.WorldFill.BorderSizePixel = 0
	widgets.WorldFill.ZIndex = 34
	widgets.WorldFill.Parent = widgets.WorldTrack
	widgets.WorldProgress = dynamicValue("WorldProgress", 17, 99, 160, 24, Color3.fromRGB(255, 255, 255), widgets.NextWorldCard, 194, 145, 12)
	widgets.WorldProgress.TextXAlignment = Enum.TextXAlignment.Center

	widgets.ObjectiveCard = Instance.new("Frame")
	widgets.ObjectiveCard.Name = "TutorialObjectiveHUD"
	widgets.ObjectiveCard.Position, widgets.ObjectiveCard.Size = designRect(682, 132, 340, 48)
	widgets.ObjectiveCard.BackgroundColor3 = Color3.fromRGB(8, 15, 20)
	widgets.ObjectiveCard.BackgroundTransparency = 0.04
	widgets.ObjectiveCard.BorderSizePixel = 0
	widgets.ObjectiveCard.ZIndex = 34
	widgets.ObjectiveCard.Parent = referenceHUD
	local objectiveStroke = Instance.new("UIStroke")
	objectiveStroke.Color = Color3.fromRGB(37, 191, 239)
	objectiveStroke.Thickness = 2
	objectiveStroke.Parent = widgets.ObjectiveCard
	createThemeIcon(widgets.ObjectiveCard, "Train", UDim2.fromScale(5 / 340, 4 / 48), UDim2.fromScale(40 / 340, 40 / 48), "ObjectiveIcon").ZIndex = 35
	widgets.ObjectiveText = Instance.new("TextLabel")
	widgets.ObjectiveText.Name = "ObjectiveText"
	widgets.ObjectiveText.BackgroundTransparency = 1
	widgets.ObjectiveText.Position = UDim2.fromScale(49 / 340, 3 / 48)
	widgets.ObjectiveText.Size = UDim2.fromScale((340 - 55) / 340, (48 - 6) / 48)
	widgets.ObjectiveText.Font = Enum.Font.GothamBold
	widgets.ObjectiveText.Text = "OBJECTIVE  |  TRAIN AT THE POWER DUMMY"
	widgets.ObjectiveText.TextColor3 = Color3.fromRGB(242, 246, 247)
	widgets.ObjectiveText.TextScaled = true
	widgets.ObjectiveText.TextWrapped = true
	widgets.ObjectiveText.TextXAlignment = Enum.TextXAlignment.Left
	widgets.ObjectiveText.ZIndex = 35
	widgets.ObjectiveText.Parent = widgets.ObjectiveCard
	local objectiveTextConstraint = Instance.new("UITextSizeConstraint")
	objectiveTextConstraint.MinTextSize = 7
	objectiveTextConstraint.MaxTextSize = 13
	objectiveTextConstraint.Parent = widgets.ObjectiveText
end
shared.PunchWallBuildDynamicReferenceHUD()

local function buildLegacySpinUI()
	local spinOverlay = Instance.new("Frame")
	spinOverlay.Name = "HeroSpinModal"
	spinOverlay.Size = UDim2.fromScale(1, 1)
	spinOverlay.BackgroundColor3 = Color3.fromRGB(2, 7, 11)
	spinOverlay.BackgroundTransparency = 0.18
	spinOverlay.BorderSizePixel = 0
	spinOverlay.ZIndex = 180
	spinOverlay.Visible = false
	spinOverlay.Parent = gui
	local panel = Instance.new("Frame")
	panel.Name = "SpinPanel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(620, 430)
	panel.BackgroundColor3 = Color3.fromRGB(8, 17, 24)
	panel.BorderSizePixel = 0
	panel.ZIndex = 181
	panel.Parent = spinOverlay
	setRounded(panel, 8)
	local panelConstraint = Instance.new("UISizeConstraint")
	panelConstraint.MinSize = Vector2.new(420, 330)
	panelConstraint.MaxSize = Vector2.new(620, 430)
	panelConstraint.Parent = panel
	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = Color3.fromRGB(43, 199, 244)
	panelStroke.Thickness = 3
	panelStroke.Parent = panel
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 68)
	header.BackgroundColor3 = Color3.fromRGB(173, 30, 30)
	header.BorderSizePixel = 0
	header.ZIndex = 182
	header.Parent = panel
	local headerGradient = Instance.new("UIGradient")
	headerGradient.Color = ColorSequence.new(Color3.fromRGB(196, 31, 31), Color3.fromRGB(10, 71, 118))
	headerGradient.Parent = header
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(20, 4)
	title.Size = UDim2.new(1, -90, 1, -8)
	title.Font = Enum.Font.GothamBlack
	title.Text = "HERO PRIZE SPIN"
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextSize = 26
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = 183
	title.Parent = header
	local close = Instance.new("TextButton")
	close.Name = "CloseSpin"
	close.AnchorPoint = Vector2.new(1, 0.5)
	close.Position = UDim2.new(1, -12, 0.5, 0)
	close.Size = UDim2.fromOffset(48, 48)
	close.BackgroundColor3 = Color3.fromRGB(118, 20, 22)
	close.BorderSizePixel = 0
	close.Font = Enum.Font.GothamBlack
	close.Text = "X"
	close.TextColor3 = Color3.new(1, 1, 1)
	close.TextSize = 19
	close.ZIndex = 184
	close.Parent = header
	setRounded(close, 5)
	local wheel = Instance.new("Frame")
	wheel.Name = "PrizeWheel"
	wheel.AnchorPoint = Vector2.new(0.5, 0.5)
	wheel.Position = UDim2.fromOffset(190, 245)
	wheel.Size = UDim2.fromOffset(294, 294)
	wheel.BackgroundColor3 = Color3.fromRGB(18, 28, 35)
	wheel.BorderSizePixel = 0
	wheel.ZIndex = 182
	wheel.Parent = panel
	setRounded(wheel, 147)
	local wheelStroke = Instance.new("UIStroke")
	wheelStroke.Color = Color3.fromRGB(255, 190, 39)
	wheelStroke.Thickness = 6
	wheelStroke.Parent = wheel
	local wheelGradient = Instance.new("UIGradient")
	wheelGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(182, 35, 38)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(16, 92, 146)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(182, 35, 38)),
	})
	wheelGradient.Rotation = 45
	wheelGradient.Parent = wheel
	local rewardWidgets = {}
	for index, reward in ipairs(GameConfig.Spin.Rewards) do
		local angle = math.rad(-90 + (index - 1) * (360 / #GameConfig.Spin.Rewards))
		local chip = Instance.new("TextLabel")
		chip.Name = reward.id
		chip.AnchorPoint = Vector2.new(0.5, 0.5)
		chip.Position = UDim2.fromOffset(147 + math.cos(angle) * 104, 147 + math.sin(angle) * 104)
		chip.Size = UDim2.fromOffset(92, 42)
		chip.BackgroundColor3 = Color3.fromRGB(7, 14, 20)
		chip.BackgroundTransparency = 0.08
		chip.BorderSizePixel = 0
		chip.Font = Enum.Font.GothamBlack
		chip.Text = reward.label
		chip.TextColor3 = reward.color
		chip.TextSize = 11
		chip.TextWrapped = true
		chip.ZIndex = 183
		chip.Parent = wheel
		setRounded(chip, 5)
		local chipStroke = Instance.new("UIStroke")
		chipStroke.Color = reward.color
		chipStroke.Thickness = 1.5
		chipStroke.Parent = chip
		rewardWidgets[index] = chip
	end
	local center = Instance.new("ImageLabel")
	center.Name = "WheelCenter"
	center.AnchorPoint = Vector2.new(0.5, 0.5)
	center.Position = UDim2.fromScale(0.5, 0.5)
	center.Size = UDim2.fromOffset(86, 108)
	center.BackgroundTransparency = 1
	center.Image = GameConfig.HeroCityPixelUI.Spin
	center.ScaleType = Enum.ScaleType.Fit
	center.ZIndex = 184
	center.Parent = wheel
	local pointer = Instance.new("TextLabel")
	pointer.Name = "PrizePointer"
	pointer.AnchorPoint = Vector2.new(0.5, 0)
	pointer.Position = UDim2.fromOffset(190, 80)
	pointer.Size = UDim2.fromOffset(50, 45)
	pointer.BackgroundTransparency = 1
	pointer.Font = Enum.Font.GothamBlack
	pointer.Text = "V"
	pointer.TextColor3 = Color3.fromRGB(255, 218, 57)
	pointer.TextStrokeTransparency = 0
	pointer.TextSize = 34
	pointer.ZIndex = 186
	pointer.Parent = panel
	local info = Instance.new("TextLabel")
	info.Name = "SpinInfo"
	info.Position = UDim2.fromOffset(365, 102)
	info.Size = UDim2.fromOffset(230, 84)
	info.BackgroundTransparency = 1
	info.Font = Enum.Font.GothamBold
	info.Text = "One free spin every 20 hours. Bonus spins do not consume the free timer."
	info.TextColor3 = Color3.fromRGB(194, 209, 217)
	info.TextSize = 14
	info.TextWrapped = true
	info.TextXAlignment = Enum.TextXAlignment.Left
	info.ZIndex = 183
	info.Parent = panel
	local status = Instance.new("TextLabel")
	status.Name = "SpinStatus"
	status.Position = UDim2.fromOffset(365, 194)
	status.Size = UDim2.fromOffset(230, 72)
	status.BackgroundColor3 = Color3.fromRGB(15, 27, 35)
	status.BorderSizePixel = 0
	status.Font = Enum.Font.GothamBlack
	status.Text = "READY"
	status.TextColor3 = Color3.fromRGB(255, 207, 47)
	status.TextSize = 18
	status.TextWrapped = true
	status.ZIndex = 183
	status.Parent = panel
	setRounded(status, 6)
	local spinButton = Instance.new("TextButton")
	spinButton.Name = "SpinNow"
	spinButton.Position = UDim2.fromOffset(365, 282)
	spinButton.Size = UDim2.fromOffset(230, 66)
	spinButton.BackgroundColor3 = Color3.fromRGB(226, 151, 20)
	spinButton.BorderSizePixel = 0
	spinButton.Font = Enum.Font.GothamBlack
	spinButton.Text = "SPIN NOW"
	spinButton.TextColor3 = Color3.new(1, 1, 1)
	spinButton.TextSize = 21
	spinButton.ZIndex = 184
	spinButton.Parent = panel
	setRounded(spinButton, 6)
	local buySpins = Instance.new("TextButton")
	buySpins.Name = "BuyBonusSpins"
	buySpins.Position = UDim2.fromOffset(365, 358)
	buySpins.Size = UDim2.fromOffset(230, 46)
	buySpins.BackgroundColor3 = Color3.fromRGB(23, 93, 146)
	buySpins.BorderSizePixel = 0
	buySpins.Font = Enum.Font.GothamBlack
	buySpins.Text = "3 BONUS SPINS  |  CHECKING PRICE"
	buySpins.TextColor3 = Color3.new(1, 1, 1)
	buySpins.TextSize = 13
	buySpins.ZIndex = 184
	buySpins.Parent = panel
	setRounded(buySpins, 6)
	local bonusSpinProduct = shared.PunchWallPurchaseRuntime.FindPremiumProduct("SpinPack")
	local bonusSpinPurchaseConfigured =
		shared.PunchWallPurchaseRuntime.HasConfiguredDeveloperProduct(bonusSpinProduct)
	if bonusSpinPurchaseConfigured then
		shared.PunchWallPurchaseRuntime.MarkControlConfigured(buySpins)
		shared.PunchWallPurchaseRuntime.ApplyDeveloperProductControlPrice(
			bonusSpinProduct,
			buySpins,
			"3 BONUS SPINS"
		)
	else
		shared.PunchWallPurchaseRuntime.MarkControlUnavailable(
			buySpins,
			"BONUS SPINS  |  UNAVAILABLE",
			"ProductIdNotConfigured"
		)
	end
	local spinScale = Instance.new("UIScale")
	spinScale.Name = "ResponsiveSpinScale"
	spinScale.Parent = panel
	local function applySpinLayout()
		local camera = workspace.CurrentCamera
		local available = spinOverlay.AbsoluteSize
		if available.X < 1 or available.Y < 1 then
			available = camera and camera.ViewportSize or Vector2.new(620, 430)
		end
		local compact = UserInputService.TouchEnabled or available.Y < 520
		local fitScale = math.min((available.X - 20) / 620, (available.Y - 16) / 430)
		spinScale.Scale = compact and math.clamp(fitScale, 0.58, 0.82) or math.clamp(fitScale, 0.82, 1)
		title.Position = compact and UDim2.fromOffset(76, 4) or UDim2.fromOffset(20, 4)
		title.Size = compact and UDim2.new(1, -146, 1, -8) or UDim2.new(1, -90, 1, -8)
		title.TextSize = compact and 22 or 26
		panel.Position = UDim2.fromScale(0.5, 0.5)
		gui:SetAttribute("SpinPanelScale", spinScale.Scale)
		gui:SetAttribute("SpinLayoutCompact", compact)
	end
	spinOverlay:GetPropertyChangedSignal("AbsoluteSize"):Connect(applySpinLayout)
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(applySpinLayout)
	end
	task.defer(applySpinLayout)
	local spinning = false
	shared.PunchWallRefreshSpin = function()
		local credits = math.max(0, math.floor(tonumber(latestStats.SpinCredits) or 0))
		local remaining = math.max(0, math.floor((tonumber(latestStats.SpinReadyAt) or 0) - os.time()))
		local ready = credits > 0 or remaining <= 0
		if not spinning then
			status.Text = credits > 0 and ("%d BONUS SPIN%s READY"):format(credits, credits == 1 and "" or "S")
				or ready and "FREE SPIN READY"
				or ("NEXT FREE SPIN\n%02dh %02dm"):format(math.floor(remaining / 3600), math.floor(remaining % 3600 / 60))
			spinButton.Text = ready and "SPIN NOW" or "COOLDOWN"
			spinButton.BackgroundColor3 = ready and Color3.fromRGB(226, 151, 20) or Color3.fromRGB(60, 70, 76)
			spinButton.Active = ready
		end
		gui:SetAttribute("SpinReady", ready)
		gui:SetAttribute("SpinCredits", credits)
	end
	shared.PunchWallOpenSpin = function()
		setMenuVisible(false)
		spinOverlay.Visible = true
		applySpinLayout()
		gui:SetAttribute("SpinModalVisible", true)
		shared.PunchWallSetModalCoreGuiHidden(true, "SpinModal")
		shared.PunchWallRefreshSpin()
	end
	shared.PunchWallShowSpinResult = function(payload)
		spinning = false
		local rewardIndex = math.clamp(tonumber(payload.index) or 1, 1, #rewardWidgets)
		for index, widget in ipairs(rewardWidgets) do
			widget.BackgroundColor3 = index == rewardIndex and Color3.fromRGB(84, 64, 16) or Color3.fromRGB(7, 14, 20)
		end
		status.Text = "YOU WON\n" .. tostring(payload.target or "HERO REWARD")
		status.TextColor3 = payload.color or Color3.fromRGB(255, 213, 58)
		spinButton.Text = "REWARD CLAIMED"
		spinButton.Active = false
		gui:SetAttribute("SpinResultCount", (gui:GetAttribute("SpinResultCount") or 0) + 1)
		gui:SetAttribute("LastSpinReward", tostring(payload.reward or payload.target or ""))
		task.delay(1.8, function() if status.Parent then shared.PunchWallRefreshSpin() end end)
	end
	shared.PunchWallTriggerSpin = function()
		if spinning or not spinButton.Active then return end
		spinning = true
		spinButton.Active = false
		spinButton.Text = "SPINNING..."
		status.Text = "THE WHEEL IS SPINNING"
		TweenService:Create(wheel, TweenInfo.new(1.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Rotation = wheel.Rotation + 1080 + math.random(0, 300) }):Play()
		actionRemote:FireServer({ action = "Spin" })
		task.delay(3, function()
			if spinning then spinning = false; shared.PunchWallRefreshSpin() end
		end)
	end
	if bonusSpinPurchaseConfigured then
		buySpins.Activated:Connect(function()
			actionRemote:FireServer({ action = "BuyPremiumProduct", target = "SpinPack" })
		end)
	end
	close.Activated:Connect(function()
		spinOverlay.Visible = false
		gui:SetAttribute("SpinModalVisible", false)
		shared.PunchWallSetModalCoreGuiHidden(false, "SpinModal")
	end)
end

shared.PunchWallBuildSpinUI = function()
	local spinOverlay = Instance.new("Frame")
	spinOverlay.Name = "HeroSpinModal"
	spinOverlay.Size = UDim2.fromScale(1, 1)
	spinOverlay.BackgroundColor3 = Color3.fromRGB(1, 6, 10)
	spinOverlay.BackgroundTransparency = 0.2
	spinOverlay.BorderSizePixel = 0
	spinOverlay.ZIndex = 180
	spinOverlay.Visible = false
	spinOverlay.Parent = gui

	local panel = Instance.new("ImageLabel")
	panel.Name = "SpinPanel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(760, 558)
	panel.BackgroundTransparency = 1
	panel.BorderSizePixel = 0
	panel.Image = GameConfig.SpinArt.Panel
	panel.ScaleType = Enum.ScaleType.Stretch
	panel.ZIndex = 181
	panel.Parent = spinOverlay

	local function imageLayer(className, name, asset, position, size, zIndex)
		local object = Instance.new(className)
		object.Name = name
		object.BackgroundTransparency = 1
		object.BorderSizePixel = 0
		object.Position = position
		object.Size = size
		object.Image = asset
		object.ScaleType = Enum.ScaleType.Fit
		object.ZIndex = zIndex
		object.Parent = panel
		if object:IsA("ImageButton") then object.AutoButtonColor = false end
		return object
	end

	imageLayer("ImageLabel", "SpinHeaderArt", GameConfig.SpinArt.Header, UDim2.fromScale(0.035, 0.025), UDim2.fromScale(0.79, 0.17), 183)
	local close = imageLayer("ImageButton", "CloseSpin", GameConfig.SpinArt.Close, UDim2.fromScale(0.875, 0.035), UDim2.fromScale(0.09, 0.125), 186)
	local wheel = imageLayer("ImageLabel", "PrizeWheel", GameConfig.SpinArt.Wheel, UDim2.fromScale(0.035, 0.20), UDim2.fromScale(0.55, 0.75), 183)
	imageLayer("ImageLabel", "PrizePointer", GameConfig.SpinArt.Pointer, UDim2.fromScale(0.255, 0.17), UDim2.fromScale(0.105, 0.12), 186)
	imageLayer("ImageLabel", "WheelCenter", GameConfig.SpinArt.Center, UDim2.fromScale(0.238, 0.48), UDim2.fromScale(0.145, 0.20), 186)
	local freeReady = imageLayer("ImageLabel", "FreeSpinReadyArt", GameConfig.SpinArt.FreeSpinReady, UDim2.fromScale(0.60, 0.38), UDim2.fromScale(0.35, 0.18), 184)
	local spinButton = imageLayer("ImageButton", "SpinNow", GameConfig.SpinArt.SpinNow, UDim2.fromScale(0.59, 0.60), UDim2.fromScale(0.37, 0.17), 185)
	local buySpins = imageLayer("ImageButton", "BuyBonusSpins", GameConfig.SpinArt.BonusSpins, UDim2.fromScale(0.59, 0.80), UDim2.fromScale(0.37, 0.12), 185)
	local bonusSpinProduct = shared.PunchWallPurchaseRuntime.FindPremiumProduct("SpinPack")
	local bonusSpinPurchaseConfigured =
		shared.PunchWallPurchaseRuntime.HasConfiguredDeveloperProduct(bonusSpinProduct)
	if bonusSpinPurchaseConfigured then
		shared.PunchWallPurchaseRuntime.MarkControlConfigured(buySpins)
		shared.PunchWallPurchaseRuntime.ApplyDeveloperProductControlPrice(
			bonusSpinProduct,
			buySpins,
			"3 BONUS SPINS"
		)
	else
		shared.PunchWallPurchaseRuntime.MarkControlUnavailable(
			buySpins,
			"BONUS SPINS\nUNAVAILABLE",
			"ProductIdNotConfigured"
		)
	end

	local info = Instance.new("TextLabel")
	info.Name = "SpinInfo"
	info.BackgroundTransparency = 1
	info.Position = UDim2.fromScale(0.61, 0.22)
	info.Size = UDim2.fromScale(0.33, 0.14)
	info.Font = Enum.Font.GothamBold
	info.Text = "One free spin every 20 hours.\nBonus spins keep the free timer."
	info.TextColor3 = Color3.fromRGB(238, 242, 245)
	info.TextScaled = true
	info.TextWrapped = true
	info.TextXAlignment = Enum.TextXAlignment.Left
	info.ZIndex = 184
	info.Parent = panel
	local infoLimit = Instance.new("UITextSizeConstraint")
	infoLimit.MinTextSize = 8
	infoLimit.MaxTextSize = 17
	infoLimit.Parent = info

	local status = Instance.new("TextLabel")
	status.Name = "SpinStatus"
	status.BackgroundTransparency = 1
	status.Position = UDim2.fromScale(0.615, 0.405)
	status.Size = UDim2.fromScale(0.32, 0.13)
	status.Font = Enum.Font.GothamBlack
	status.Text = ""
	status.TextColor3 = Color3.fromRGB(255, 214, 64)
	status.TextScaled = true
	status.TextWrapped = true
	status.ZIndex = 187
	status.Parent = panel
	local statusLimit = Instance.new("UITextSizeConstraint")
	statusLimit.MinTextSize = 9
	statusLimit.MaxTextSize = 22
	statusLimit.Parent = status

	local spinScale = Instance.new("UIScale")
	spinScale.Name = "ResponsiveSpinScale"
	spinScale.Parent = panel
	local function applySpinLayout()
		local available = spinOverlay.AbsoluteSize
		if available.X < 1 or available.Y < 1 then
			local camera = workspace.CurrentCamera
			available = camera and camera.ViewportSize or Vector2.new(760, 558)
		end
		local fitScale = math.min((available.X - 18) / 760, (available.Y - 14) / 558)
		spinScale.Scale = math.clamp(fitScale, 0.5, 1)
		gui:SetAttribute("SpinPanelScale", spinScale.Scale)
		gui:SetAttribute("SpinLayoutCompact", fitScale < 0.82)
	end
	spinOverlay:GetPropertyChangedSignal("AbsoluteSize"):Connect(applySpinLayout)
	task.defer(applySpinLayout)

	local spinning = false
	shared.PunchWallRefreshSpin = function()
		local credits = math.max(0, math.floor(tonumber(latestStats.SpinCredits) or 0))
		local remaining = math.max(0, math.floor((tonumber(latestStats.SpinReadyAt) or 0) - os.time()))
		local ready = credits > 0 or remaining <= 0
		if not spinning then
			freeReady.Visible = ready
			status.Text = ready and "" or ("NEXT FREE SPIN\n%02dh %02dm"):format(math.floor(remaining / 3600), math.floor(remaining % 3600 / 60))
			spinButton.Active = ready
			spinButton.ImageTransparency = ready and 0 or 0.55
		end
		gui:SetAttribute("SpinReady", ready)
		gui:SetAttribute("SpinCredits", credits)
	end

	shared.PunchWallOpenSpin = function()
		setMenuVisible(false)
		spinOverlay.Visible = true
		gui:SetAttribute("SpinModalVisible", true)
		shared.PunchWallSetModalCoreGuiHidden(true, "SpinModal")
		applySpinLayout()
		shared.PunchWallRefreshSpin()
	end

	shared.PunchWallShowSpinResult = function(payload)
		local rewardIndex = math.clamp(tonumber(payload.index) or 1, 1, #GameConfig.Spin.Rewards)
		local segment = 360 / #GameConfig.Spin.Rewards
		TweenService:Create(wheel, TweenInfo.new(0.7, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Rotation = wheel.Rotation + 720 + (rewardIndex - 1) * segment,
		}):Play()
		spinning = false
		freeReady.Visible = false
		status.Text = "YOU WON\n" .. tostring(payload.target or "HERO REWARD")
		status.TextColor3 = payload.color or Color3.fromRGB(255, 214, 64)
		spinButton.Active = false
		spinButton.ImageTransparency = 0.5
		gui:SetAttribute("SpinResultCount", (gui:GetAttribute("SpinResultCount") or 0) + 1)
		gui:SetAttribute("LastSpinReward", tostring(payload.reward or payload.target or ""))
		task.delay(2.1, function()
			if status.Parent then status.TextColor3 = Color3.fromRGB(255, 214, 64); shared.PunchWallRefreshSpin() end
		end)
	end

	shared.PunchWallTriggerSpin = function()
		if spinning or not spinButton.Active then return end
		spinning = true
		spinButton.Active = false
		spinButton.ImageTransparency = 0.35
		freeReady.Visible = false
		status.Text = "SPINNING..."
		TweenService:Create(wheel, TweenInfo.new(1.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Rotation = wheel.Rotation + 900 }):Play()
		actionRemote:FireServer({ action = "Spin" })
		task.delay(3, function() if spinning then spinning = false; shared.PunchWallRefreshSpin() end end)
		return true
	end
	spinButton.Activated:Connect(function()
		shared.PunchWallTriggerSpin()
	end)
	if bonusSpinPurchaseConfigured then
		buySpins.Activated:Connect(function()
			actionRemote:FireServer({ action = "BuyPremiumProduct", target = "SpinPack" })
		end)
	end
	close.Activated:Connect(function()
		spinOverlay.Visible = false
		gui:SetAttribute("SpinModalVisible", false)
		shared.PunchWallSetModalCoreGuiHidden(false, "SpinModal")
	end)
	gui:SetAttribute("SpinUsesSuppliedLayers", true)
	gui:SetAttribute("SpinLayerCount", 9)
end
shared.PunchWallBuildSpinUI()
shared.PunchWallBuildSpinUI = nil

-- Functional Hero City shop assembled from the supplied transparent product art.
-- The checkerboard-backed exports in C:\Temp\Shop are used as layout references only.
shared.PunchWallBuildShopUI = function()
	local shopDimmer = Instance.new("Frame")
	shopDimmer.Name = "HeroShopDimmer"
	shopDimmer.BackgroundColor3 = Color3.fromRGB(2, 7, 11)
	shopDimmer.BackgroundTransparency = 0.28
	shopDimmer.BorderSizePixel = 0
	shopDimmer.Size = UDim2.fromScale(1, 1)
	shopDimmer.Active = true
	shopDimmer.Visible = false
	shopDimmer.ZIndex = 89
	shopDimmer.Parent = gui
	local dimGradient = Instance.new("UIGradient")
	dimGradient.Color = ColorSequence.new(Color3.fromRGB(5, 14, 20), Color3.fromRGB(0, 0, 0))
	dimGradient.Rotation = 90
	dimGradient.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(1, 0.42) })
	dimGradient.Parent = shopDimmer

	-- The generic menu content uses the default Z layer. Raising the opaque root
	-- above its descendants hides every non-shop page when ZIndexBehavior is
	-- Global, so only the dedicated shop child receives the premium layer.
	mainPanel.ZIndex = 1
	local shopReference = Instance.new("Frame")
	shopReference.Name = "FunctionalHeroShop"
	shopReference.BackgroundColor3 = Color3.fromRGB(5, 11, 15)
	shopReference.BackgroundTransparency = 0
	shopReference.BorderSizePixel = 0
	shopReference.ClipsDescendants = false
	shopReference.Size = UDim2.fromScale(1, 1)
	shopReference.ZIndex = 100
	shopReference.Visible = false
	shopReference.Parent = mainPanel
	shopReference:SetAttribute("ReferenceStyle", "HeroCityShopMenu")
	shopReference:SetAttribute("LayerSource", "C:\\Temp\\Shop")

	local shopCorner = Instance.new("UICorner")
	shopCorner.CornerRadius = UDim.new(0, 6)
	shopCorner:SetAttribute("ShopRootDecoration", true)
	shopCorner.Parent = shopReference
	local shopStroke = Instance.new("UIStroke")
	shopStroke.Color = Color3.fromRGB(7, 18, 25)
	shopStroke.Thickness = 7
	shopStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	shopStroke:SetAttribute("ShopRootDecoration", true)
	shopStroke.Parent = shopReference
	local shopGradient = Instance.new("UIGradient")
	shopGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(15, 25, 31)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(4, 10, 14)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 17, 22)),
	})
	shopGradient.Rotation = 90
	shopGradient:SetAttribute("ShopRootDecoration", true)
	shopGradient.Parent = shopReference

	shared.PunchWallShopDimmer = shopDimmer
	shared.PunchWallHeroShopPage = shared.PunchWallHeroShopPage or "Fists"
	local shopRuntime = {
		Pages = { "Fists", "Premium", "Boosts", "Honor", "Robux" },
		LastSignature = nil,
		RefreshRequestCount = 0,
		RefreshBuildCount = 0,
		RefreshSkipCount = 0,
		RefreshForceCount = 0,
		BoostTickGeneration = 0,
		BoostTickCount = 0,
		BoostTickScheduled = false,
	}

	function shopRuntime.ResolvePage()
		local requestedPage = shared.PunchWallHeroShopPage
		return table.find(shopRuntime.Pages, requestedPage) and requestedPage or "Fists"
	end

	function shopRuntime.CanonicalOwnedList(raw, fallback)
		local values = decodeJSON(raw, fallback)
		local normalized = {}
		for _, value in ipairs(values) do
			table.insert(normalized, tostring(value))
		end
		table.sort(normalized)
		return table.concat(normalized, "\0")
	end

	function shopRuntime.BoostSecond(endsAt, now)
		return math.max(0, math.floor((tonumber(endsAt) or 0) - now))
	end

	function shopRuntime.StateSignature(now)
		local camera = workspace.CurrentCamera
		local viewport = camera and camera.ViewportSize or Vector2.zero
		local page = shopRuntime.ResolvePage()
		local fields = {
			"HeroShopStateV1",
			page,
			math.floor(viewport.X + 0.5),
			math.floor(viewport.Y + 0.5),
			UserInputService.TouchEnabled == true,
			math.floor((tonumber(clientSettings.uiScale) or 1) * 1000 + 0.5),
		}
		if page == "Fists" then
			table.insert(fields, shopRuntime.CanonicalOwnedList(latestStats.OwnedFistsJSON, { "Starter Glove" }))
			table.insert(fields, tostring(latestStats.EquippedFist or ""))
		elseif page == "Premium" then
			table.insert(fields, shopRuntime.CanonicalOwnedList(latestStats.OwnedPremiumPetsJSON, {}))
			table.insert(fields, shopRuntime.CanonicalOwnedList(latestStats.EquippedPetsJSON, {}))
		elseif page == "Boosts" then
			local boostInfo = latestStats.ShopBoosts or {}
			table.insert(fields, shopRuntime.BoostSecond(boostInfo.CoinEndsAt, now))
			table.insert(fields, shopRuntime.BoostSecond(boostInfo.SpeedEndsAt, now))
			table.insert(fields, shopRuntime.BoostSecond(boostInfo.DamageEndsAt, now))
		elseif page == "Honor" then
			table.insert(fields, math.max(0, math.floor(tonumber(latestStats.Honor) or 0)))
		end
		if page == "Honor" or page == "Robux" then
			table.insert(fields, shared.PunchWallPurchaseRuntime.DeveloperProductPriceRevision or 0)
			local uiState = shared.PunchWallPurchaseRuntime.ProductUiState or {}
			for _, product in ipairs(GameConfig.PremiumProducts) do
				if (product.shopPage or "Robux") == page then
					local entry = uiState[product.id]
					table.insert(fields, product.id .. ":" .. tostring(entry and entry.state or "Idle"))
				end
			end
		end
		return HttpService:JSONEncode(fields), page
	end

	function shopRuntime.AddStaticFistPresentation(card, icon, item)
		local presentation = FistVisualBuilder.GetHeroGauntletPresentation(item)
		card:SetAttribute("ShopFistPresentation", presentation.version .. "StaticChrome")
		card:SetAttribute("ShopFistTier", presentation.tier)
		card:SetAttribute("ShopFistStyle", presentation.style)
		card:SetAttribute("ShopFistArmorPattern", presentation.armorPattern)
		card:SetAttribute("ShopFistArtVariant", presentation.shopArtKey)
		card:SetAttribute("ShopFistIconIdentity", presentation.iconIdentity)
		card:SetAttribute("ShopFistVariantKey", presentation.variantKey)
		card:SetAttribute("ShopFistSignatureFeature", presentation.signatureFeature)
		card:SetAttribute("ShopFistCatalogMotif", presentation.catalogMotif)
		card:SetAttribute("ShopFistCatalogMotifVersion", presentation.catalogMotifVersion)
		card:SetAttribute("StaticPreviewRenderLoop", false)
		card:SetAttribute("StaticPreviewChromeOnly", true)
		card:SetAttribute("StaticPreviewChromeCoverage", "PerimeterOnlyV1")
		card:SetAttribute("StaticPreviewStyleVersion", "PerimeterCatalogIdentityV2")
		icon.ImageColor3 = Color3.new(1, 1, 1)
		icon.ImageTransparency = 0
		icon:SetAttribute("HeroGauntletArtVariant", presentation.shopArtKey)
		icon:SetAttribute("HeroGauntletTier", presentation.tier)
		icon:SetAttribute("HeroGauntletIconIdentity", presentation.iconIdentity)
		icon:SetAttribute("HeroGauntletVariantKey", presentation.variantKey)
		icon:SetAttribute("HeroGauntletTintMatched", false)
		icon:SetAttribute("LoadedArtUnobscured", icon.Image ~= "")

		-- The three uploaded silhouettes are deliberately reused as lightweight
		-- bases. Loaded pixels remain untouched; tier, family signature, immutable
		-- catalog motif, plates, and fins live only on the perimeter chrome.
		local chrome = Instance.new("Frame")
		chrome.Name = "HeroGauntletTierChrome"
		chrome.BackgroundTransparency = 1
		chrome.BorderSizePixel = 0
		chrome.Position = icon.Position
		chrome.Size = icon.Size
		chrome.ZIndex = icon.ZIndex + 1
		chrome.Active = false
		chrome.Selectable = false
		chrome.Parent = card
		local chromeCorner = Instance.new("UICorner")
		chromeCorner.CornerRadius = UDim.new(0, 6)
		chromeCorner.Parent = chrome
		local chromeStroke = Instance.new("UIStroke")
		chromeStroke.Name = "StaticTierOutline"
		chromeStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		chromeStroke.Color = presentation.accent
		chromeStroke.Thickness = presentation.tier >= 4 and 2 or 1
		chromeStroke.Transparency = presentation.tier >= 4 and 0.18 or 0.38
		chromeStroke.Parent = chrome

		local tierBadge = Instance.new("Frame")
		tierBadge.Name = "StaticTierBadge"
		tierBadge.AnchorPoint = Vector2.new(1, 0)
		tierBadge.Position = UDim2.new(1, -4, 0, 5)
		tierBadge.Size = UDim2.fromOffset(28, 17)
		tierBadge.BackgroundColor3 = presentation.accent
		tierBadge.BackgroundTransparency = 0.04
		tierBadge.BorderSizePixel = 0
		tierBadge.ZIndex = chrome.ZIndex + 1
		tierBadge.Parent = chrome
		local tierBadgeCorner = Instance.new("UICorner")
		tierBadgeCorner.CornerRadius = UDim.new(0, 4)
		tierBadgeCorner.Parent = tierBadge
		local tierText = Instance.new("TextLabel")
		tierText.Name = "StaticTierNumber"
		tierText.BackgroundTransparency = 1
		tierText.Size = UDim2.fromScale(1, 1)
		tierText.Font = Enum.Font.GothamBlack
		tierText.Text = ("T%02d"):format(presentation.tier)
		tierText.TextColor3 = Color3.fromRGB(2, 8, 12)
		tierText.TextSize = 9
		tierText.ZIndex = tierBadge.ZIndex + 1
		tierText.Parent = tierBadge

		local featureLabel = Instance.new("TextLabel")
		featureLabel.Name = "StaticSignatureFeature"
		featureLabel.AnchorPoint = Vector2.new(0, 1)
		featureLabel.Position = UDim2.new(0, 4, 1, -4)
		featureLabel.Size = UDim2.fromOffset(50, 14)
		featureLabel.BackgroundColor3 = Color3.fromRGB(2, 8, 12)
		featureLabel.BackgroundTransparency = 0.12
		featureLabel.BorderSizePixel = 0
		featureLabel.Font = Enum.Font.GothamBlack
		featureLabel.Text = presentation.signatureFeature
		featureLabel.TextColor3 = presentation.accent
		featureLabel.TextSize = 8
		featureLabel.ZIndex = chrome.ZIndex + 1
		featureLabel.Parent = chrome
		local featureCorner = Instance.new("UICorner")
		featureCorner.CornerRadius = UDim.new(0, 3)
		featureCorner.Parent = featureLabel

		local catalogMotif = Instance.new("TextLabel")
		catalogMotif.Name = "StaticCatalogMotif"
		catalogMotif.Position = UDim2.fromOffset(4, 15)
		catalogMotif.Size = UDim2.fromOffset(38, 13)
		catalogMotif.BackgroundColor3 = presentation.accent
		catalogMotif.BackgroundTransparency = 0.1
		catalogMotif.BorderSizePixel = 0
		catalogMotif.Font = Enum.Font.GothamBlack
		catalogMotif.Text = presentation.catalogMotif
		catalogMotif.TextColor3 = Color3.fromRGB(2, 8, 12)
		catalogMotif.TextSize = 7
		catalogMotif.ZIndex = chrome.ZIndex + 1
		catalogMotif.Parent = chrome
		local motifCorner = Instance.new("UICorner")
		motifCorner.CornerRadius = UDim.new(0, 3)
		motifCorner.Parent = catalogMotif

		local tierRail = Instance.new("Frame")
		tierRail.Name = "StaticTierRail"
		tierRail.AnchorPoint = Vector2.new(0.5, 0)
		tierRail.Position = UDim2.new(0.5, 0, 0, 2)
		tierRail.Size = UDim2.new(0.38, 0, 0, 3)
		tierRail.BackgroundColor3 = presentation.accent
		tierRail.BackgroundTransparency = 0.2
		tierRail.BorderSizePixel = 0
		tierRail.ZIndex = chrome.ZIndex
		tierRail.Parent = chrome
		local railCorner = Instance.new("UICorner")
		railCorner.CornerRadius = UDim.new(1, 0)
		railCorner.Parent = tierRail

		local previewParts = 5
		local tierPipCount = math.clamp(math.ceil(presentation.tier / 4), 1, 4)
		for tierIndex = 1, tierPipCount do
			local pip = Instance.new("Frame")
			pip.Name = "StaticTierPip" .. tierIndex
			pip.Position = UDim2.fromOffset(6 + (tierIndex - 1) * 7, 8)
			pip.Size = UDim2.fromOffset(4, 3)
			pip.BackgroundColor3 = presentation.accent
			pip.BackgroundTransparency = 0.14
			pip.BorderSizePixel = 0
			pip.ZIndex = chrome.ZIndex
			pip.Parent = chrome
			local pipCorner = Instance.new("UICorner")
			pipCorner.CornerRadius = UDim.new(1, 0)
			pipCorner.Parent = pip
			previewParts += 1
		end
		for plateIndex = 1, presentation.plateCount do
			local plate = Instance.new("Frame")
			plate.Name = "StaticArmorPlate" .. plateIndex
			plate.AnchorPoint = Vector2.new(1, 0.5)
			plate.Position = UDim2.new(1, -4, 0.38 + (plateIndex - 1) * 0.1, 0)
			plate.Size = UDim2.fromOffset(7, 3)
			plate.BackgroundColor3 = presentation.imageTint:Lerp(presentation.accent, 0.45)
			plate.BorderSizePixel = 0
			plate.Rotation = plateIndex % 2 == 0 and -18 or 18
			plate.ZIndex = chrome.ZIndex
			plate.Parent = chrome
			previewParts += 1
		end
		for finIndex = 1, presentation.finCount do
			local fin = Instance.new("Frame")
			fin.Name = "StaticArmorFin" .. finIndex
			fin.AnchorPoint = Vector2.new(0, 0.5)
			fin.Position = UDim2.new(0, 4, 0.42 + (finIndex - 1) * 0.18, 0)
			fin.Size = UDim2.fromOffset(10, 2)
			fin.BackgroundColor3 = presentation.accent
			fin.BorderSizePixel = 0
			fin.Rotation = finIndex == 1 and -28 or 28
			fin.ZIndex = chrome.ZIndex
			fin.Parent = chrome
			previewParts += 1
		end
		card:SetAttribute("StaticPreviewPartCount", previewParts)
		card:SetAttribute("StaticPreviewIdentityVersion", "UniqueFistPerimeterV2")
	end

	function shopRuntime.ScheduleBoostTick(page, now)
		shopRuntime.BoostTickGeneration += 1
		local generation = shopRuntime.BoostTickGeneration
		shopRuntime.BoostTickScheduled = false
		if page ~= "Boosts" or not shopReference.Visible then return end

		local boostInfo = latestStats.ShopBoosts or {}
		local nextDelay
		for _, key in ipairs({ "CoinEndsAt", "SpeedEndsAt", "DamageEndsAt" }) do
			local endsAt = boostInfo[key]
			local remaining = (tonumber(endsAt) or 0) - now
			if remaining > 0 then
				local delay = math.max(0.03, remaining - math.floor(remaining) + 0.02)
				nextDelay = nextDelay and math.min(nextDelay, delay) or delay
			end
		end
		if not nextDelay then return end

		shopRuntime.BoostTickScheduled = true
		task.delay(nextDelay, function()
			if generation ~= shopRuntime.BoostTickGeneration then return end
			shopRuntime.BoostTickScheduled = false
			if not shopReference.Parent
				or not shopReference.Visible
				or shopRuntime.ResolvePage() ~= "Boosts"
			then
				return
			end
			shopRuntime.BoostTickCount += 1
			shopReference:SetAttribute("BoostTickCount", shopRuntime.BoostTickCount)
			shared.PunchWallHeroShopRefresh()
		end)
	end

	shared.PunchWallHeroShopRefresh = function(options)
		local force = options == true or (type(options) == "table" and options.force == true)
		local reason = type(options) == "table" and tostring(options.reason or "") or ""
		local shopRefreshNow = workspace:GetServerTimeNow()
		local signature, page = shopRuntime.StateSignature(shopRefreshNow)
		shopRuntime.RefreshRequestCount += 1
		shopReference:SetAttribute("RefreshRequestCount", shopRuntime.RefreshRequestCount)
		if not force and signature == shopRuntime.LastSignature then
			shopRuntime.RefreshSkipCount += 1
			shopReference:SetAttribute("RefreshSkipCount", shopRuntime.RefreshSkipCount)
			if page == "Boosts" and shopReference.Visible and not shopRuntime.BoostTickScheduled then
				shopRuntime.ScheduleBoostTick(page, shopRefreshNow)
			end
			return false
		end

		if force then
			shopRuntime.RefreshForceCount += 1
			shopReference:SetAttribute("RefreshForceCount", shopRuntime.RefreshForceCount)
		end
		shopRuntime.LastSignature = signature
		shopRuntime.RefreshBuildCount += 1
		shopReference:SetAttribute("RefreshBuildCount", shopRuntime.RefreshBuildCount)
		shopReference:SetAttribute("RefreshSignature", signature)
		shopReference:SetAttribute("RefreshReason", reason)
		shopReference:SetAttribute("RefreshMode", "RelevantStateSignatureV1")
		shared.PunchWallShopActions = {}
		for _, child in ipairs(shopReference:GetChildren()) do
			if not child:GetAttribute("ShopRootDecoration") then child:Destroy() end
		end

		local function addCorner(parent, radius)
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, radius)
			corner.Parent = parent
			return corner
		end
		local function addStroke(parent, color, thickness)
			local stroke = Instance.new("UIStroke")
			stroke.Color = color
			stroke.Thickness = thickness
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.Parent = parent
			return stroke
		end
		local function label(parent, name, text, position, size, color, textSize, font, alignment, wrapped)
			local value = Instance.new("TextLabel")
			value.Name = name
			value.BackgroundTransparency = 1
			value.Position = position
			value.Size = size
			value.Font = font or Enum.Font.GothamBold
			value.Text = text
			value.TextColor3 = color
			value.TextSize = textSize
			value.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
			value.TextStrokeTransparency = 0.55
			value.TextXAlignment = alignment or Enum.TextXAlignment.Left
			value.TextYAlignment = Enum.TextYAlignment.Center
			value.TextWrapped = wrapped == true
			value.TextTruncate = wrapped and Enum.TextTruncate.None or Enum.TextTruncate.AtEnd
			value.ZIndex = parent.ZIndex + 2
			value.Parent = parent
			return value
		end
		local function bindButtonMotion(button, idleColor)
			local scale = Instance.new("UIScale")
			scale.Parent = button
			button.MouseEnter:Connect(function()
				TweenService:Create(button, TweenInfo.new(0.1), { BackgroundColor3 = idleColor:Lerp(Color3.new(1, 1, 1), 0.12) }):Play()
			end)
			button.MouseLeave:Connect(function()
				TweenService:Create(button, TweenInfo.new(0.1), { BackgroundColor3 = idleColor }):Play()
				TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1 }):Play()
			end)
			button.MouseButton1Down:Connect(function()
				TweenService:Create(scale, TweenInfo.new(0.06), { Scale = 0.95 }):Play()
			end)
			button.MouseButton1Up:Connect(function()
				TweenService:Create(scale, TweenInfo.new(0.1, Enum.EasingStyle.Back), { Scale = 1 }):Play()
			end)
		end
		local function compactStat(value)
			return value == math.floor(value) and tostring(math.floor(value)) or ("%.1f"):format(value)
		end
		local function addPetPreview(parent, item, position, size)
			local holder = Instance.new("Frame")
			holder.Name = "PremiumPetPreviewPlate"
			holder.BackgroundColor3 = item.accent:Lerp(Color3.fromRGB(5, 11, 15), 0.86)
			holder.BackgroundTransparency = 0.06
			holder.BorderSizePixel = 0
			holder.ClipsDescendants = true
			holder.Position = position
			holder.Size = size
			holder.ZIndex = parent.ZIndex + 2
			holder.Parent = parent
			addCorner(holder, 6)
			local holderStroke = addStroke(holder, item.accent, 1.5)
			holderStroke.Transparency = 0.32
			local holderGradient = Instance.new("UIGradient")
			holderGradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, item.color:Lerp(Color3.fromRGB(7, 14, 19), 0.74)),
				ColorSequenceKeypoint.new(0.55, Color3.fromRGB(8, 16, 22)),
				ColorSequenceKeypoint.new(1, item.accent:Lerp(Color3.fromRGB(3, 8, 12), 0.88)),
			})
			holderGradient.Rotation = 22
			holderGradient.Parent = holder

			local viewport = Instance.new("ViewportFrame")
			viewport.Name = "PremiumPetPreview"
			viewport.Ambient = Color3.fromRGB(165, 178, 191)
			viewport.BackgroundTransparency = 1
			viewport.BorderSizePixel = 0
			viewport.LightColor = Color3.fromRGB(255, 246, 224)
			viewport.LightDirection = Vector3.new(-1, -0.7, -0.45)
			viewport.Position = UDim2.fromScale(0.04, 0.04)
			viewport.Size = UDim2.fromScale(0.92, 0.92)
			viewport.ZIndex = holder.ZIndex + 1
			viewport.Parent = holder

			local camera = Instance.new("Camera")
			camera.Name = "PremiumPetPreviewCamera"
			camera.FieldOfView = 34
			camera.Parent = viewport
			viewport.CurrentCamera = camera
			local world = Instance.new("WorldModel")
			world.Name = "PremiumPetPreviewWorld"
			world.Parent = viewport

			local model
			local previewSource = "ProceduralPremiumFallbackV1"
			local gameRoot = workspace:FindFirstChild("PunchWallRPG")
			if gameRoot then
				for _, candidate in ipairs(gameRoot:GetDescendants()) do
					if candidate:IsA("Model")
						and candidate:GetAttribute("VisualRole") == "PremiumPetShowcase"
						and candidate:GetAttribute("PetTemplate") == item.templateName
						and FistVisualBuilder.IsSanitizedVisual(candidate)
					then
						model = companionRuntime.CloneSanitizedVisual(candidate)
						previewSource = "SanitizedWorldShowcaseCloneV1"
						break
					end
				end
			end
			if not model then
				model = companionRuntime.BuildProceduralPet(item)
				local sanitized = pcall(FistVisualBuilder.SanitizeVisual, model)
				if not sanitized or not FistVisualBuilder.IsSanitizedVisual(model) then
					model:Destroy()
					model = nil
				end
			end
			if not model then
				holder:Destroy()
				return nil
			end
			for _, descendant in ipairs(model:GetDescendants()) do
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
			model.Parent = world
			local boundsCFrame, boundsSize = model:GetBoundingBox()
			local radius = math.max(0.5, boundsSize.Magnitude * 0.5)
			-- Fit the complete bounding sphere, not just the largest axis. Imported
			-- companions have very different wing, tail, and height proportions.
			local fitPadding = item.name == "Celestial Guardian" and 0.82 or 0.66
			local distance = math.max(3.2, radius / math.sin(math.rad(camera.FieldOfView * 0.5)) * fitPadding)
			local center = boundsCFrame.Position
			camera.CFrame = CFrame.lookAt(
				center + Vector3.new(distance * 0.22, distance * 0.1, -distance),
				center + Vector3.new(0, boundsSize.Y * 0.04, 0)
			)
			viewport:SetAttribute("PreviewPetName", item.name)
			viewport:SetAttribute("PreviewReady", true)
			viewport:SetAttribute("PreviewSource", previewSource)
			viewport:SetAttribute("PreviewFit", "BoundingSphereSafeV2")
			viewport:SetAttribute("PreviewFitPadding", fitPadding)
			holder:SetAttribute("PreviewPetName", item.name)
			holder:SetAttribute("PreviewReady", true)
			return viewport
		end

		local innerBevel = Instance.new("Frame")
		innerBevel.Name = "ShopInnerBevel"
		innerBevel.BackgroundTransparency = 1
		innerBevel.Position = UDim2.fromOffset(7, 7)
		innerBevel.Size = UDim2.new(1, -14, 1, -14)
		innerBevel.ZIndex = 101
		innerBevel.Parent = shopReference
		addCorner(innerBevel, 4)
		addStroke(innerBevel, Color3.fromRGB(53, 78, 91), 2)

		local header = Instance.new("Frame")
		header.Name = "ShopHeader"
		header.BackgroundColor3 = Color3.fromRGB(11, 15, 19)
		header.BorderSizePixel = 0
		header.ClipsDescendants = true
		header.Position = UDim2.fromScale(0.018, 0.025)
		header.Size = UDim2.fromScale(0.964, 0.125)
		header.ZIndex = 102
		header.Parent = shopReference
		addCorner(header, 7)
		addStroke(header, Color3.fromRGB(49, 122, 154), 2)
		local headerGradient = Instance.new("UIGradient")
		headerGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(132, 13, 22)),
			ColorSequenceKeypoint.new(0.54, Color3.fromRGB(84, 8, 19)),
			ColorSequenceKeypoint.new(0.56, Color3.fromRGB(12, 44, 66)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(5, 25, 43)),
		})
		headerGradient.Parent = header
		local redRail = Instance.new("Frame")
		redRail.Name = "HeaderRedRail"
		redRail.BackgroundColor3 = Color3.fromRGB(255, 50, 47)
		redRail.BorderSizePixel = 0
		redRail.Position = UDim2.fromScale(0.018, 0.84)
		redRail.Size = UDim2.fromScale(0.42, 0.055)
		redRail.ZIndex = 103
		redRail.Parent = header
		addCorner(redRail, 4)
		local cyanRail = redRail:Clone()
		cyanRail.Name = "HeaderCyanRail"
		cyanRail.BackgroundColor3 = Color3.fromRGB(45, 205, 255)
		cyanRail.Position = UDim2.fromScale(0.445, 0.84)
		cyanRail.Size = UDim2.fromScale(0.42, 0.055)
		cyanRail.Parent = header
		label(header, "Eyebrow", "HERO CITY ARMORY", UDim2.fromScale(0.035, 0.18), UDim2.fromScale(0.3, 0.18), Color3.fromRGB(255, 196, 64), 11, Enum.Font.GothamBlack)
		local title = label(header, "Title", "SHOP", UDim2.fromScale(0.035, 0.34), UDim2.fromScale(0.38, 0.42), Color3.fromRGB(255, 249, 237), 32, Enum.Font.GothamBlack)
		title.TextStrokeTransparency = 0.08
		title.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		local compactHeader = UserInputService.TouchEnabled
			or (workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.Y < 520)
		local honorBalanceText = formatNumber(math.max(0, tonumber(latestStats.Honor) or 0))
		local headerSubtitle = page == "Honor"
			and ((compactHeader and "HONOR %s  •  CURRENCY ONLY  •  GATES APPLY"
				or "HONOR %s  •  CURRENCY ONLY  •  RELIC GATES STILL APPLY"):format(honorBalanceText))
			or "GEAR  •  COMPANIONS  •  BOOSTS"
		local headerSubtitleLabel = label(header, "Subtitle", headerSubtitle, UDim2.fromScale(0.4, 0.3), UDim2.fromScale(0.45, 0.38), Color3.fromRGB(190, 222, 235), 12, Enum.Font.GothamBold, Enum.TextXAlignment.Right)
		headerSubtitleLabel.TextScaled = page == "Honor"
		local headerSubtitleSize = Instance.new("UITextSizeConstraint")
		headerSubtitleSize.MinTextSize = 9
		headerSubtitleSize.MaxTextSize = 12
		headerSubtitleSize.Parent = headerSubtitleLabel

		local close = Instance.new("TextButton")
		close.Name = "CloseShop"
		close.BackgroundColor3 = Color3.fromRGB(157, 19, 22)
		close.BorderSizePixel = 0
		close.AnchorPoint = Vector2.new(1, 0.5)
		close.Position = UDim2.fromScale(0.975, 0.5)
		close.Size = UDim2.new(0, 50, 0, 50)
		close.Font = Enum.Font.GothamBlack
		close.Text = "X"
		close.TextColor3 = Color3.fromRGB(255, 247, 238)
		close.TextSize = 25
		close.TextStrokeTransparency = 0.15
		close.ZIndex = 106
		close.Parent = header
		addCorner(close, 7)
		addStroke(close, Color3.fromRGB(255, 102, 93), 2)
		local closeSize = Instance.new("UISizeConstraint")
		closeSize.MinSize = Vector2.new(44, 44)
		closeSize.Parent = close
		bindButtonMotion(close, close.BackgroundColor3)
		close.Activated:Connect(function() setMenuVisible(false) end)

		local owned = decodeJSON(latestStats.OwnedFistsJSON, { "Starter Glove" })
		local ownedPremium = decodeJSON(latestStats.OwnedPremiumPetsJSON, {})
		local equippedPets = decodeJSON(latestStats.EquippedPetsJSON, {})
		local tabBand = Instance.new("Frame")
		tabBand.Name = "ShopTabs"
		tabBand.BackgroundTransparency = 1
		tabBand.Position = UDim2.fromScale(0.025, 0.162)
		tabBand.Size = UDim2.fromScale(0.95, 0.085)
		tabBand.ZIndex = 102
		tabBand.Parent = shopReference
		local tabGap = 0.012
		local tabWidth = (1 - tabGap * (#shopRuntime.Pages - 1)) / #shopRuntime.Pages
		for index, pageName in ipairs(shopRuntime.Pages) do
			local selected = page == pageName
			local tab = Instance.new("TextButton")
			tab.Name = pageName .. "ShopTab"
			tab.BackgroundColor3 = selected and Color3.fromRGB(20, 134, 205) or Color3.fromRGB(25, 35, 42)
			tab.BorderSizePixel = 0
			tab.Position = UDim2.fromScale((index - 1) * (tabWidth + tabGap), 0)
			tab.Size = UDim2.fromScale(tabWidth, 1)
			tab.Font = Enum.Font.GothamBlack
			tab.Text = string.upper(pageName)
			tab.TextColor3 = selected and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(191, 205, 212)
			tab.TextSize = 14
			tab.TextStrokeTransparency = selected and 0.45 or 0.8
			tab.ZIndex = 104
			tab.Parent = tabBand
			local tabSize = Instance.new("UISizeConstraint")
			tabSize.Name = "MinimumTouchTarget"
			tabSize.MinSize = Vector2.new(44, 44)
			tabSize.Parent = tab
			addCorner(tab, 4)
			addStroke(tab, selected and Color3.fromRGB(71, 205, 255) or Color3.fromRGB(48, 67, 76), selected and 2 or 1)
			if selected then
				local selectedRail = Instance.new("Frame")
				selectedRail.Name = "SelectedRail"
				selectedRail.AnchorPoint = Vector2.new(0.5, 1)
				selectedRail.Position = UDim2.fromScale(0.5, 1)
				selectedRail.Size = UDim2.new(0.58, 0, 0, 4)
				selectedRail.BackgroundColor3 = Color3.fromRGB(255, 202, 48)
				selectedRail.BorderSizePixel = 0
				selectedRail.ZIndex = tab.ZIndex + 1
				selectedRail.Parent = tab
				addCorner(selectedRail, 3)
			end
			bindButtonMotion(tab, tab.BackgroundColor3)
			tab.Activated:Connect(function()
				shared.PunchWallHeroShopPage = pageName
				shared.PunchWallHeroShopRefresh()
			end)
		end

		local boostInfo = latestStats.ShopBoosts or {}
		local now = shopRefreshNow
		local products = {}
		if page == "Fists" then
			for _, item in ipairs(GameConfig.Fists) do table.insert(products, item) end
		elseif page == "Premium" then
			for _, source in ipairs(GameConfig.PremiumPets) do
				local item = table.clone(source)
				item.displayName = item.name
				item.isPremiumPet = true
				item.rarity = "PREMIUM COMPANION"
				item.detail = ("Permanent sidekick  •  +%d%% Power  •  +%d%% Luck"):format(
					math.floor(item.mult * 100 + 0.5),
					math.floor(item.luckGain * 100 + 0.5)
				)
				local displayPrice, regionalPriceResolved, regionalPriceState =
					shared.PunchWallPurchaseRuntime.GetGamePassDisplayPrice(
						item,
						shared.PunchWallHeroShopRefresh
					)
				item.displayRobuxPrice = displayPrice
				item.regionalPriceResolved = regionalPriceResolved
				item.regionalPriceState = regionalPriceState
				item.regionalPriceCopy = regionalPriceResolved and ("R$ %d"):format(displayPrice)
					or regionalPriceState == "Loading" and "CHECKING PRICE"
					or "PRICE AT CHECKOUT"
				table.insert(products, item)
			end
		elseif page == "Boosts" then
			products = {
				{ name = "CoinBoost", displayName = "COIN BOOST x2", rarity = "EPIC", cost = 5000, art = GameConfig.ShopArt.CoinBoost, accent = Color3.fromRGB(202, 71, 230), detail = "Earn 2x more Coins for 15 minutes.", endsAt = boostInfo.CoinEndsAt or 0 },
				{ name = "SpeedBoost", displayName = "SPEED BOOST", rarity = "RARE", cost = 8000, art = GameConfig.ShopArt.SpeedBoost, accent = Color3.fromRGB(58, 201, 248), detail = "Move faster through the Hero City course.", endsAt = boostInfo.SpeedEndsAt or 0 },
				{ name = "DamageBoost", displayName = "DAMAGE BOOST", rarity = "EPIC", cost = 12000, art = GameConfig.ShopArt.DamageBoost, accent = Color3.fromRGB(239, 112, 51), detail = "Deal 2x wall damage for 15 minutes.", endsAt = boostInfo.DamageEndsAt or 0 },
			}
		elseif page == "Honor" or page == "Robux" then
			local commercePalette = { Color3.fromRGB(255, 190, 40), Color3.fromRGB(57, 199, 249), Color3.fromRGB(190, 80, 244), Color3.fromRGB(59, 218, 150) }
			for _, source in ipairs(GameConfig.PremiumProducts) do
				if (source.shopPage or "Robux") ~= page then
					continue
				end
				local item = table.clone(source)
				item.name = item.name or item.id
				item.isRobuxProduct = true
				item.isHonorProduct = item.honor ~= nil
				item.honorPackTier = item.isHonorProduct and (#products + 1) or nil
				item.rarity = item.isHonorProduct
					and (("+%s HONOR  •  %s"):format(formatNumber(item.honor), item.valueBadge or "HONOR PACK"))
					or "HERO OFFER"
				item.accent = item.accent or commercePalette[(#products % #commercePalette) + 1]
				item.detail = item.honor and (("+%s Honor after Roblox confirms payment. Relic gates still apply."):format(formatNumber(item.honor)))
					or item.coins and ("Receive " .. formatNumber(item.coins) .. " Coins instantly.")
					or item.spins and ("Receive " .. item.spins .. " Hero Spins.")
					or item.boost == "TrainingBoostExpiresAt" and "Train Power 2x faster for 15 minutes."
					or "Earn 2x more Coins for 15 minutes."
				item.icon = item.honor and "Honor" or item.spins and "Success" or item.boost == "TrainingBoostExpiresAt" and "Train" or "Coin"
				item.art = item.honor and GameConfig.ShopArt.HonorIcon
					or item.id == "CoinPack" and GameConfig.ShopArt.ShopCoinIcon
					or item.id == "SpinPack" and GameConfig.ShopArt.SpinPack
					or item.id == "CoinBoost" and GameConfig.ShopArt.CoinBoost
					or item.id == "TrainingBoost" and GameConfig.ShopArt.SpeedBoost
					or nil
				item.displayRobuxPrice, item.regionalPriceResolved, item.regionalPriceState =
					shared.PunchWallPurchaseRuntime.GetDeveloperProductDisplayPrice(
						item,
						function()
							shared.PunchWallHeroShopRefresh({
								force = true,
								reason = "developer-product-price-resolved",
							})
						end
					)
				item.regionalPriceCopy = item.regionalPriceResolved and ("R$ %d"):format(item.displayRobuxPrice)
					or item.regionalPriceState == "Loading" and "CHECKING PRICE"
					or item.regionalPriceState == "CheckoutOnly" and "PRICE AT CHECKOUT"
					or item.regionalPriceState == "OffSale" and "OFF SALE"
					or "PRICE UNAVAILABLE"
				table.insert(products, item)
			end
		end

		local camera = workspace.CurrentCamera
		local compactCards = UserInputService.TouchEnabled or (camera and camera.ViewportSize.Y < 520)
		if compactCards then
			tabBand.Size = UDim2.new(0.95, 0, 0, 44)
		end
		local rowCount = math.max(1, math.ceil(#products / 2))
		-- Compact tabs have a fixed 44 px touch target, so proportional card
		-- placement must reserve enough room even on 270-336 px tall phones.
		local cardsTop = compactCards and 0.34 or 0.265
		local cardsBottom = compactCards and 0.88 or 0.89
		local rowGap = compactCards and 0.01 or 0.014
		local cardHeight = (cardsBottom - cardsTop - rowGap * (rowCount - 1)) / rowCount
		local catalogScrollable = page == "Fists" and #products > 6
		local scrollCardHeight = compactCards and 118 or 154
		local scrollRowGap = compactCards and 7 or 9
		local cardsHost = shopReference
		if catalogScrollable then
			local catalogScroll = Instance.new("ScrollingFrame")
			catalogScroll.Name = "FistCatalogScroll"
			catalogScroll.BackgroundTransparency = 1
			catalogScroll.BorderSizePixel = 0
			catalogScroll.Position = UDim2.fromScale(0, cardsTop)
			catalogScroll.Size = UDim2.fromScale(1, cardsBottom - cardsTop)
			catalogScroll.CanvasSize = UDim2.fromOffset(
				0,
				rowCount * scrollCardHeight + math.max(0, rowCount - 1) * scrollRowGap
			)
			catalogScroll.ScrollBarImageColor3 = Color3.fromRGB(45, 205, 255)
			catalogScroll.ScrollBarImageTransparency = 0.12
			catalogScroll.ScrollBarThickness = compactCards and 5 or 7
			catalogScroll.ScrollingDirection = Enum.ScrollingDirection.Y
			catalogScroll.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
			catalogScroll.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
			catalogScroll.ZIndex = 102
			catalogScroll.Parent = shopReference
			cardsHost = catalogScroll
			shopReference:SetAttribute("ShopCatalogScrollable", true)
			shopReference:SetAttribute("ShopCatalogItemCount", #products)
			shopReference:SetAttribute("ShopCatalogRowCount", rowCount)
			shopReference:SetAttribute("ShopCatalogScrollMode", "FixedReadableCardsV1")
		else
			shopReference:SetAttribute("ShopCatalogScrollable", false)
			shopReference:SetAttribute("ShopCatalogItemCount", #products)
			shopReference:SetAttribute("ShopCatalogRowCount", rowCount)
		end
		local compactProductNames = {
			["Boxing Glove"] = "STREET FIST",
			["Iron Knuckle"] = "IRON FIST",
			["Thunder Fist"] = "THUNDER FIST",
			["Crimson Vanguard Fist"] = "VANGUARD FIST",
			["Stormbreaker Fist"] = "STORM FIST",
			["Celestial Titan Fist"] = "TITAN FIST",
			["Crimson Phoenix"] = "PHOENIX",
			["Storm Wyvern"] = "WYVERN",
			["Celestial Guardian"] = "GUARDIAN",
			CoinPack = "COIN PACK",
			SpinPack = "SPIN PACK",
			CoinBoost = "2X COINS",
			TrainingBoost = "2X TRAINING",
			HonorPouch25 = "25 HONOR",
			HonorCache90 = "90 HONOR",
			HonorVault300 = "300 HONOR",
			HonorTreasury850 = "850 HONOR",
		}
		for index, item in ipairs(products) do
			local column = (index - 1) % 2
			local row = math.floor((index - 1) / 2)
			local featuredCard = index == #products and #products % 2 == 1
			local card = Instance.new("Frame")
			card.Name = item.name .. "ShopCard"
			card.BackgroundColor3 = Color3.fromRGB(10, 18, 23)
			card.BorderSizePixel = 0
			if catalogScrollable then
				card.Position = UDim2.new(
					featuredCard and 0.03 or 0.03 + column * 0.485,
					0,
					0,
					row * (scrollCardHeight + scrollRowGap)
				)
				card.Size = UDim2.new(featuredCard and 0.94 or 0.455, 0, 0, scrollCardHeight)
			else
				card.Position = UDim2.fromScale(
					featuredCard and 0.03 or 0.03 + column * 0.485,
					cardsTop + row * (cardHeight + rowGap)
				)
				card.Size = UDim2.fromScale(featuredCard and 0.94 or 0.455, cardHeight)
			end
			card:SetAttribute("ShopCardLayout", featuredCard and "FeaturedFullWidthV2" or "StandardHalfWidthV2")
			card:SetAttribute("CatalogScrollable", catalogScrollable)
			card.ZIndex = 102
			card.ClipsDescendants = true
			card.Parent = cardsHost
			addCorner(card, 5)
			local equippedCard = latestStats.EquippedFist == item.name
			local premiumOwned = item.isPremiumPet
				and table.find(ownedPremium, item.name) ~= nil
			local purchaseConfigured = true
			local purchaseReady = true
			local purchaseLoading = false
			local purchaseUiEntry = item.isRobuxProduct
				and shared.PunchWallPurchaseRuntime.ProductUiState[item.id]
				or nil
			local purchaseUiState = tostring(purchaseUiEntry and purchaseUiEntry.state or "Idle")
			local purchaseBusy = table.find({ "Opening", "CheckoutOpen", "Verifying", "Granted" }, purchaseUiState) ~= nil
			if item.isPremiumPet then
				purchaseConfigured =
					shared.PunchWallPurchaseRuntime.HasConfiguredGamePass(item)
			elseif item.isRobuxProduct then
				purchaseConfigured =
					shared.PunchWallPurchaseRuntime.HasConfiguredDeveloperProduct(item)
				purchaseLoading = purchaseConfigured and item.regionalPriceState == "Loading"
				purchaseReady = purchaseConfigured
					and (item.regionalPriceState == "Resolved" or item.regionalPriceState == "CheckoutOnly")
			end
			local purchaseUnavailable = false
			if item.isPremiumPet then
				purchaseUnavailable = not premiumOwned and not purchaseConfigured
			elseif item.isRobuxProduct then
				purchaseUnavailable = not purchaseConfigured
					or item.regionalPriceState == "OffSale"
					or item.regionalPriceState == "LookupFailed"
					or item.regionalPriceState == "WrongProduct"
			end
			card:SetAttribute("PurchaseConfigured", purchaseConfigured)
			card:SetAttribute("PurchaseReady", purchaseReady)
			card:SetAttribute("PurchaseLoading", purchaseLoading)
			card:SetAttribute("PurchaseUnavailable", purchaseUnavailable)
			card:SetAttribute("PurchaseUiState", purchaseUiState)
			if item.isRobuxProduct then
				card:SetAttribute("ProductId", tonumber(item.productId) or 0)
				card:SetAttribute("DefaultRobuxPrice", tonumber(item.robux) or 0)
				card:SetAttribute("DisplayedRobuxPrice", item.regionalPriceResolved and item.displayRobuxPrice or 0)
				card:SetAttribute("RegionalPriceResolved", item.regionalPriceResolved)
				card:SetAttribute("RegionalPriceState", item.regionalPriceState)
			end
			card:SetAttribute(
				"OfferKind",
				item.isPremiumPet and "GamePass" or item.isRobuxProduct and "DeveloperProduct" or "GameCurrency"
			)
			addStroke(card, item.accent, equippedCard and 3 or 1.5)
			local cardGradient = Instance.new("UIGradient")
			cardGradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, item.accent:Lerp(Color3.fromRGB(6, 12, 16), 0.72)),
				ColorSequenceKeypoint.new(0.32, Color3.fromRGB(13, 23, 29)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(4, 9, 12)),
			})
			cardGradient.Rotation = 10
			cardGradient.Parent = card
			local accentRail = Instance.new("Frame")
			accentRail.Name = "AccentRail"
			accentRail.BackgroundColor3 = item.accent
			accentRail.BorderSizePixel = 0
			accentRail.Position = UDim2.fromOffset(0, 4)
			accentRail.Size = UDim2.new(0, equippedCard and 7 or 4, 1, -8)
			accentRail.ZIndex = 103
			accentRail.Parent = card

			local fistPresentation = item.tier
				and FistVisualBuilder.GetHeroGauntletPresentation(item)
				or nil
			local art
			if item.art then
				art = item.art
			elseif fistPresentation then
				art = GameConfig.ShopArt[fistPresentation.shopArtKey] or ""
			else
				art = ""
			end
			local iconWidth = featuredCard and 0.18 or 0.25
			if item.isRobuxProduct then
				iconWidth = item.id == "SpinPack" and 0.17
					or item.id == "TrainingBoost" and 0.18
					or 0.2
			elseif page == "Boosts" then
				iconWidth = featuredCard and 0.18 or item.name == "SpeedBoost" and 0.2 or 0.22
			elseif item.isPremiumPet then
				iconWidth = featuredCard and 0.2 or 0.255
			end
			local visualColumnWidth = featuredCard and 0.22 or 0.285
			local iconX = 0.025 + math.max(0, (visualColumnWidth - iconWidth) * 0.5)
			local artPlate = Instance.new("Frame")
			artPlate.Name = "ProductArtPlate"
			artPlate.BackgroundColor3 = item.accent:Lerp(Color3.fromRGB(4, 10, 14), 0.9)
			artPlate.BackgroundTransparency = 0.12
			artPlate.BorderSizePixel = 0
			artPlate.Position = UDim2.fromScale(iconX, 0.07)
			artPlate.Size = UDim2.fromScale(iconWidth, 0.84)
			artPlate.ZIndex = 103
			artPlate.Parent = card
			addCorner(artPlate, 6)
			local artPlateStroke = addStroke(artPlate, item.accent, 1)
			artPlateStroke.Transparency = 0.48
			local icon = Instance.new("ImageLabel")
			icon.Name = "ProductArt"
			icon.BackgroundTransparency = 1
			icon.Image = art
			icon.ScaleType = Enum.ScaleType.Fit
			icon.Position = UDim2.fromScale(iconX + 0.012, 0.095)
			icon.Size = UDim2.fromScale(iconWidth - 0.024, 0.79)
			icon.ZIndex = 105
			icon.Parent = card
			if item.isPremiumPet then
				artPlate.Visible = false
				local petPreview = addPetPreview(card, item, UDim2.fromScale(iconX, 0.07), UDim2.fromScale(iconWidth, 0.84))
				icon.Visible = petPreview == nil
				card:SetAttribute("PremiumPetPreviewReady", petPreview ~= nil)
				card:SetAttribute("GamePassId", tonumber(item.gamePassId) or 0)
			end
			local fallbackName = item.icon or (item.name == "CoinBoost" and "Coin" or item.name == "SpeedBoost" and "Train" or "Punch")
			local fallback = createThemeIcon(card, fallbackName, icon.Position, icon.Size, "ProductArtFallback")
			fallback.ZIndex = 104
			-- A visible atlas placeholder bleeds old labels through transparent product art.
			fallback.Visible = art == "" and not item.isPremiumPet
			if fistPresentation then
				shopRuntime.AddStaticFistPresentation(card, icon, item)
			end
			if item.isHonorProduct then
				local pipHolder = Instance.new("Frame")
				pipHolder.Name = "HonorPackTierPips"
				pipHolder.AnchorPoint = Vector2.new(0.5, 1)
				pipHolder.Position = UDim2.new(iconX + iconWidth * 0.5, 0, 0.88, 0)
				pipHolder.Size = UDim2.fromOffset(58, 10)
				pipHolder.BackgroundTransparency = 1
				pipHolder.ZIndex = 108
				pipHolder.Parent = card
				local pipLayout = Instance.new("UIListLayout")
				pipLayout.FillDirection = Enum.FillDirection.Horizontal
				pipLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
				pipLayout.VerticalAlignment = Enum.VerticalAlignment.Center
				pipLayout.Padding = UDim.new(0, 4)
				pipLayout.Parent = pipHolder
				for pipIndex = 1, math.clamp(tonumber(item.honorPackTier) or 1, 1, 4) do
					local pip = Instance.new("Frame")
					pip.Name = ("TierPip%d"):format(pipIndex)
					pip.Size = UDim2.fromOffset(9, 6)
					pip.BackgroundColor3 = item.accent
					pip.BorderSizePixel = 0
					pip.ZIndex = pipHolder.ZIndex + 1
					pip.Parent = pipHolder
					addCorner(pip, 3)
				end
				card:SetAttribute("HonorPackPipCount", item.honorPackTier)
			end

			local textX = featuredCard and 0.24 or 0.31
			local rarity = compactCards and item.isHonorProduct and (item.valueBadge or "HONOR PACK")
				or compactCards and item.isPremiumPet and "PREMIUM"
				or item.rarity
				or (item.tier == 1 and "COMMON" or item.tier >= 5 and "LEGENDARY" or item.tier >= 4 and "EPIC" or "RARE")
			local productName = compactCards and compactProductNames[item.name] or nil
			productName = productName or string.upper(item.displayName)
			local productNameLabel = label(card, "Name", productName, UDim2.fromScale(textX, 0.08), UDim2.fromScale(featuredCard and 0.38 or 0.4, 0.2), Color3.fromRGB(250, 248, 239), compactCards and 12 or 17, Enum.Font.GothamBlack)
			if #productName > 18 then
				productNameLabel.TextScaled = true
				local productNameSize = Instance.new("UITextSizeConstraint")
				productNameSize.MinTextSize = compactCards and 8 or 10
				productNameSize.MaxTextSize = compactCards and 12 or 17
				productNameSize.Parent = productNameLabel
			end
			local rarityLabel = label(card, "Rarity", rarity, UDim2.fromScale(textX, 0.27), UDim2.fromScale(featuredCard and 0.3 or 0.35, 0.14), item.accent, 11, Enum.Font.GothamBlack)
			if compactCards and item.isHonorProduct then
				rarityLabel.TextScaled = true
				local raritySize = Instance.new("UITextSizeConstraint")
				raritySize.MinTextSize = 8
				raritySize.MaxTextSize = 11
				raritySize.Parent = rarityLabel
			end
			local requiredDepth = math.max(0, math.floor(tonumber(item.unlockDepth) or 0))
			-- Keep the client lock display aligned with the server-authoritative
			-- tunnel progression rule. WallLevel is deliberately not a fallback.
			local playerProgressDepth = math.max(0, math.floor(tonumber(latestStats.Depth) or 0))
			local fistOwnedForGate = page == "Fists" and table.find(owned, item.name) ~= nil
			local depthLocked = page == "Fists"
				and not fistOwnedForGate
				and playerProgressDepth < requiredDepth
			card:SetAttribute("RequiredDepth", requiredDepth)
			card:SetAttribute("DepthLocked", depthLocked)
			local detailText = purchaseUnavailable
				and (item.isHonorProduct and (("+%s Honor • Temporarily unavailable until Roblox product setup is verified."):format(formatNumber(item.honor)))
					or "This offer is unavailable until its purchase ID is configured.")
				or depthLocked and ("Reach Depth %d to unlock this fist."):format(requiredDepth)
				or item.detail
				or ("Built for deeper walls.  " .. compactStat(item.mult) .. "x Power.")
			local detailPosition = UDim2.fromScale(textX, 0.43)
			local detailSize = UDim2.fromScale(featuredCard and 0.43 or 0.38, 0.23)
			local detailBackdrop = Instance.new("Frame")
			detailBackdrop.Name = "DetailReadabilityPanel"
			detailBackdrop.BackgroundColor3 = Color3.fromRGB(3, 9, 13)
			detailBackdrop.BackgroundTransparency = 0.18
			detailBackdrop.BorderSizePixel = 0
			detailBackdrop.Position = UDim2.new(
				detailPosition.X.Scale - 0.008,
				detailPosition.X.Offset,
				detailPosition.Y.Scale - 0.025,
				detailPosition.Y.Offset
			)
			detailBackdrop.Size = UDim2.new(
				detailSize.X.Scale + 0.016,
				detailSize.X.Offset,
				detailSize.Y.Scale + 0.05,
				detailSize.Y.Offset
			)
			detailBackdrop.ZIndex = card.ZIndex + 1
			detailBackdrop.Visible = not compactCards
			detailBackdrop.Parent = card
			addCorner(detailBackdrop, 4)
			local detailStroke = addStroke(detailBackdrop, item.accent, 1)
			detailStroke.Transparency = 0.72
			local detail = label(card, "Detail", detailText, detailPosition, detailSize, Color3.fromRGB(236, 242, 244), 12, Enum.Font.GothamMedium, Enum.TextXAlignment.Left, true)
			detail.TextYAlignment = Enum.TextYAlignment.Top
			detail.TextStrokeTransparency = 0.35
			detail.LineHeight = 1.08
			detail.Visible = not compactCards
			detail:SetAttribute("DescriptionReadabilityMode", "HighContrastPanelV1")
			card:SetAttribute("DescriptionReadabilityMode", "HighContrastPanelV1")

			local priceX = featuredCard and 0.7 or 0.72
			local priceIcon
			if item.robux then
				priceIcon = Instance.new("TextLabel")
				priceIcon.Name = "PriceIcon"
				priceIcon.BackgroundColor3 = Color3.fromRGB(22, 121, 82)
				priceIcon.BackgroundTransparency = 0.08
				priceIcon.BorderSizePixel = 0
				priceIcon.Font = Enum.Font.GothamBlack
				priceIcon.Text = "R$"
				priceIcon.TextColor3 = Color3.fromRGB(220, 255, 231)
				priceIcon.TextSize = 10
				priceIcon.TextStrokeTransparency = 0.7
				priceIcon.Position = UDim2.fromScale(priceX, 0.1)
				priceIcon.Size = UDim2.fromScale(0.055, 0.18)
				priceIcon.Parent = card
				addCorner(priceIcon, 4)
				local priceIconStroke = addStroke(priceIcon, Color3.fromRGB(73, 226, 146), 1)
				priceIconStroke.Transparency = 0.28
			else
				priceIcon = Instance.new("ImageLabel")
				priceIcon.Name = "PriceIcon"
				priceIcon.BackgroundTransparency = 1
				priceIcon.BorderSizePixel = 0
				priceIcon.Image = GameConfig.ShopArt.ShopCoinIcon
				priceIcon.ScaleType = Enum.ScaleType.Fit
				priceIcon.Position = UDim2.fromScale(priceX, 0.08)
				priceIcon.Size = UDim2.fromScale(0.06, 0.22)
				priceIcon.Parent = card
			end
			priceIcon.ZIndex = 105
			local priceText = purchaseUnavailable and (item.regionalPriceState == "OffSale" and "OFF SALE"
				or item.isHonorProduct and "PRICE UNAVAILABLE"
				or "UNAVAILABLE")
				or purchaseLoading and "CHECKING PRICE"
				or depthLocked and ("DEPTH " .. tostring(requiredDepth))
				or item.isPremiumPet and premiumOwned and not purchaseConfigured and "OWNED"
				or item.robux and item.regionalPriceResolved and tostring(item.displayRobuxPrice)
				or item.robux and item.regionalPriceState == "CheckoutOnly" and "AT CHECKOUT"
				or item.robux and "PRICE UNAVAILABLE"
				or ((item.cost or 0) <= 0 and "FREE" or formatNumber(item.cost))
			local priceLabel = label(card, "Price", priceText, UDim2.fromScale(priceX + 0.065, 0.07), UDim2.fromScale(featuredCard and 0.13 or 0.18, 0.24), Color3.fromRGB(255, 207, 58), 14, Enum.Font.GothamBlack)
			if purchaseUnavailable then
				if priceIcon:IsA("ImageLabel") then
					priceIcon.ImageTransparency = 0.62
				else
					priceIcon.TextTransparency = 0.52
					priceIcon.BackgroundTransparency = 0.62
				end
				priceLabel.TextColor3 = Color3.fromRGB(185, 194, 199)
				priceLabel.TextScaled = true
				local unavailablePriceSize = Instance.new("UITextSizeConstraint")
				unavailablePriceSize.MinTextSize = 7
				unavailablePriceSize.MaxTextSize = 11
				unavailablePriceSize.Parent = priceLabel
			end
			if compactCards then
				priceIcon.Position = UDim2.fromScale(textX, 0.57)
				priceIcon.Size = UDim2.fromScale(0.06, 0.26)
				priceLabel.Position = UDim2.fromScale(textX + 0.065, 0.54)
				priceLabel.Size = UDim2.fromScale(0.28, 0.3)
				priceLabel.TextSize = 10
			end

			local actionColor = Color3.fromRGB(232, 157, 22)
			local actionText = "BUY"
			local actionCallback
			local actionEnabled = true
			if page == "Fists" then
				local equipped = latestStats.EquippedFist == item.name
				local isOwned = table.find(owned, item.name) ~= nil
				actionText = equipped and "EQUIPPED"
					or isOwned and "EQUIP"
					or depthLocked and ("DEPTH " .. tostring(requiredDepth))
					or "BUY"
				actionColor = equipped and Color3.fromRGB(45, 145, 60)
					or isOwned and Color3.fromRGB(53, 159, 63)
					or depthLocked and Color3.fromRGB(61, 68, 73)
					or actionColor
				actionEnabled = not equipped and not depthLocked
				actionCallback = function()
					if not equipped and not depthLocked then
						actionRemote:FireServer({ action = isOwned and "EquipFist" or "BuyFist", target = item.name })
					end
				end
			elseif page == "Premium" then
				local equipped = table.find(equippedPets, item.name) ~= nil
				local isOwned = premiumOwned
				actionText = equipped and "EQUIPPED"
					or isOwned and "EQUIP"
					or purchaseConfigured and "BUY"
					or "UNAVAILABLE"
				actionColor = equipped and Color3.fromRGB(45, 145, 60)
					or isOwned and Color3.fromRGB(53, 159, 63)
					or purchaseConfigured and Color3.fromRGB(31, 174, 102)
					or Color3.fromRGB(61, 68, 73)
				actionEnabled = not equipped and (isOwned or purchaseConfigured)
				actionCallback = function()
					if equipped then return end
					if isOwned or purchaseConfigured then
						actionRemote:FireServer({ action = "BuyPremiumPet", target = item.name })
					end
				end
			elseif page == "Boosts" then
				local seconds = math.max(0, math.floor((item.endsAt or 0) - now))
				actionText = seconds > 0 and ("ACTIVE %02d:%02d"):format(math.floor(seconds / 60), seconds % 60) or "BUY"
				actionColor = seconds > 0 and Color3.fromRGB(45, 145, 60) or actionColor
				actionCallback = function() actionRemote:FireServer({ action = "BuyShopBoost", target = item.name }) end
			else
				actionText = purchaseUiState == "Opening" and (compactCards and "OPEN" or "OPENING...")
					or purchaseUiState == "CheckoutOpen" and (compactCards and "ROBLOX" or "CHECKOUT OPEN")
					or purchaseUiState == "Verifying" and (compactCards and "VERIFY" or "VERIFYING...")
					or purchaseUiState == "Granted" and (compactCards and "ADDED" or "GRANTED")
					or purchaseLoading and "WAIT"
					or item.regionalPriceState == "CheckoutOnly" and "SEE PRICE"
					or purchaseReady and "BUY"
					or compactCards and item.isHonorProduct and "NOT READY"
					or "UNAVAILABLE"
				actionColor = purchaseReady and not purchaseBusy and Color3.fromRGB(31, 174, 102)
					or purchaseUiState == "Granted" and Color3.fromRGB(45, 145, 60)
					or Color3.fromRGB(61, 68, 73)
				actionEnabled = purchaseReady
					and not purchaseBusy
					and shared.PunchWallPurchaseRuntime.ActivePromptProductId == nil
				actionCallback = function()
					if not actionEnabled then return end
					shared.PunchWallPurchaseRuntime.ActivePromptProductId = tonumber(item.productId)
					shared.PunchWallShopFocusedProductId = item.id
					shared.PunchWallPurchaseRuntime.SetProductUiState(item.id, "Opening", "OPENING PURCHASE...")
					actionRemote:FireServer({ action = "BuyPremiumProduct", target = item.id })
				end
			end

			local actionShadow = Instance.new("Frame")
			actionShadow.Name = "ActionShadow"
			actionShadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
			actionShadow.BackgroundTransparency = 0.1
			actionShadow.BorderSizePixel = 0
			actionShadow.AnchorPoint = Vector2.new(1, 1)
			actionShadow.Position = UDim2.fromScale(0.97, 0.92)
			local actionWidth = featuredCard and 0.18 or 0.23
			actionShadow.Size = compactCards and UDim2.new(actionWidth, 0, 0, 44) or UDim2.fromScale(actionWidth, 0.32)
			actionShadow.ZIndex = 104
			actionShadow.Parent = card
			addCorner(actionShadow, 4)
			local action = Instance.new("TextButton")
			action.Name = item.name .. "Action"
			action.BackgroundColor3 = actionColor
			action.BorderSizePixel = 0
			action.AnchorPoint = Vector2.new(1, 1)
			action.Position = UDim2.fromScale(0.962, 0.89)
			action.Size = compactCards and UDim2.new(actionWidth, 0, 0, 44) or UDim2.fromScale(actionWidth, 0.32)
			action.Font = Enum.Font.GothamBlack
			action.Text = actionText
			action.TextColor3 = Color3.fromRGB(255, 255, 255)
			action.TextSize = compactCards and 10 or 14
			action.TextStrokeTransparency = 0.2
			action.ZIndex = 106
			action.Parent = card
			if item.isRobuxProduct and compactCards then
				-- Compact purchase-state labels must remain legible inside the 44px touch
				-- target while the card moves through opening/checkout/receipt states.
				action.TextScaled = true
				action.TextWrapped = false
				local compactActionTextConstraint = Instance.new("UITextSizeConstraint")
				compactActionTextConstraint.MinTextSize = 7
				compactActionTextConstraint.MaxTextSize = 10
				compactActionTextConstraint.Parent = action
			end
			if purchaseUnavailable then
				-- TextScaled enables wrapping internally on narrow mobile cards. Keep the
				-- unavailable state on one deliberate line so the disabled CTA still
				-- reads as a button instead of a broken two-line label.
				action.TextScaled = false
				action.TextWrapped = false
				action.TextTruncate = Enum.TextTruncate.AtEnd
				action.TextSize = compactCards and 8 or 12
			end
			if item.isRobuxProduct then
				action:SetAttribute("ProductKey", item.id)
				action:SetAttribute("ProductId", tonumber(item.productId) or 0)
				action:SetAttribute("DefaultRobuxPrice", tonumber(item.robux) or 0)
				action:SetAttribute("DisplayedRobuxPrice", item.regionalPriceResolved and item.displayRobuxPrice or 0)
				action:SetAttribute("RegionalPriceResolved", item.regionalPriceResolved)
				action:SetAttribute("RegionalPriceState", item.regionalPriceState)
				action:SetAttribute("PurchaseUiState", purchaseUiState)
				action.SelectionGained:Connect(function()
					shared.PunchWallShopFocusedProductId = item.id
				end)
			end
			if item.isPremiumPet then
				action:SetAttribute("GamePassId", tonumber(item.gamePassId) or 0)
				action:SetAttribute("DefaultRobuxPrice", tonumber(item.robux) or 0)
				action:SetAttribute("DisplayedRobuxPrice", item.regionalPriceResolved and item.displayRobuxPrice or 0)
				action:SetAttribute("RegionalPriceResolved", item.regionalPriceResolved)
				action:SetAttribute("RegionalPriceState", item.regionalPriceState)
			end
			local actionSize = Instance.new("UISizeConstraint")
			actionSize.Name = "MinimumTouchTarget"
			actionSize.MinSize = Vector2.new(44, 44)
			actionSize.Parent = action
			addCorner(action, 4)
			addStroke(action, Color3.fromRGB(5, 9, 11), 2)
			action.Active = actionEnabled
			action.Selectable = actionEnabled
			action.AutoButtonColor = actionEnabled
			action:SetAttribute("PurchaseConfigured", purchaseConfigured)
			action:SetAttribute("PurchaseUnavailable", purchaseUnavailable)
			if actionEnabled then
				bindButtonMotion(action, actionColor)
				shared.PunchWallShopActions[item.name] = actionCallback
				action.Activated:Connect(actionCallback)
				action:SetAttribute("ShopActionBound", true)
			else
				shared.PunchWallShopActions[item.name] = nil
				action:SetAttribute("ShopActionBound", false)
				if purchaseUnavailable then
					shared.PunchWallPurchaseRuntime.MarkControlUnavailable(
						action,
						compactCards and item.isHonorProduct and "NOT READY" or "UNAVAILABLE",
						item.isPremiumPet and "GamePassIdNotConfigured" or "ProductIdNotConfigured"
					)
					if item.isHonorProduct then
						action:SetAttribute("AvailabilityCopy", "TEMPORARILY UNAVAILABLE")
					end
				end
			end
		end
		local rememberedProductId = shared.PunchWallShopFocusedProductId
		local lastInput = UserInputService:GetLastInputType()
		if rememberedProductId
			and (lastInput == Enum.UserInputType.Gamepad1 or lastInput == Enum.UserInputType.Keyboard)
		then
			task.defer(function()
				if not shopReference.Parent then return end
				for _, descendant in ipairs(shopReference:GetDescendants()) do
					if descendant:IsA("GuiButton")
						and descendant:GetAttribute("ProductKey") == rememberedProductId
						and descendant.Selectable
					then
						GuiService.SelectedObject = descendant
						break
					end
				end
			end)
		end

		local footerBand = Instance.new("Frame")
		footerBand.Name = "ShopFooter"
		footerBand.BackgroundColor3 = Color3.fromRGB(8, 15, 19)
		footerBand.BorderSizePixel = 0
		footerBand.Position = UDim2.fromScale(0.018, 0.905)
		footerBand.Size = UDim2.fromScale(0.964, 0.07)
		footerBand.ZIndex = 102
		footerBand.Parent = shopReference
		addCorner(footerBand, 4)
		addStroke(footerBand, Color3.fromRGB(40, 61, 70), 1.5)
		local pageSummary = page == "Premium" and "PREMIUM COMPANIONS"
			or page == "Honor" and "HONOR PACKS"
			or page == "Robux" and "ROBUX OFFERS"
			or page == "Boosts" and "BOOSTS"
			or "HERO FISTS"
		label(footerBand, "SecureLabel", ("%s  •  %d ITEMS"):format(pageSummary, #products), UDim2.fromScale(0.025, 0), UDim2.fromScale(0.47, 1), Color3.fromRGB(184, 201, 209), 11, Enum.Font.GothamBold)
		label(footerBand, "ServerLabel", "SECURE • SERVER VERIFIED", UDim2.fromScale(0.51, 0), UDim2.fromScale(0.465, 1), Color3.fromRGB(81, 190, 235), 11, Enum.Font.GothamBold, Enum.TextXAlignment.Right)
		shopRuntime.ScheduleBoostTick(page, shopRefreshNow)
		return true
	end
	shared.PunchWallInvalidateHeroShop = function(reason, refreshWhenVisible)
		shopRuntime.LastSignature = nil
		shopRuntime.BoostTickGeneration += 1
		shopRuntime.BoostTickScheduled = false
		shopReference:SetAttribute("LastInvalidationReason", tostring(reason or "manual"))
		if refreshWhenVisible ~= false and shopReference.Visible then
			return shared.PunchWallHeroShopRefresh({ force = true, reason = reason or "invalidation" })
		end
		return true
	end
	shared.PunchWallHeroShopRefresh()
	return shopReference
end
shared.PunchWallShopReference = shared.PunchWallBuildShopUI()
shared.PunchWallBuildShopUI = nil

shared.PunchWallInventoryController = InventoryUI.new({
	Parent = mainPanel,
	GameConfig = GameConfig,
	ActionRemote = actionRemote,
	GetStats = function()
		return latestStats
	end,
	BuildPetPreview = companionRuntime.BuildInventoryPetPreview,
	GetHUDHidden = function()
		return not referenceHUD.Visible
			and not mobileControls.Visible
			and not targetHUD.Visible
			and not bossHUD.Visible
	end,
	OnClose = function()
		setMenuVisible(false)
	end,
	OpenSpin = function()
		if shared.PunchWallOpenSpin then shared.PunchWallOpenSpin() end
	end,
})
shared.PunchWallInventoryController:SetVisible(false)

shared.PunchWallOpenInventoryHonorItem = function(itemId, origin)
	local definition = GameConfig.HonorItemDefinition(tostring(itemId or ""))
	itemId = definition and tostring(definition.id) or ""
	if itemId == "" then
		return false, "item_not_found"
	end
	local controller = shared.PunchWallInventoryController
	if not controller then
		return false, "inventory_unavailable"
	end
	shared.PunchWallSelectedHonorItemId = itemId
	gui:SetAttribute("RequestedHonorItemId", itemId)
	gui:SetAttribute("HonorInventoryOpenOrigin", tostring(origin or "honor_catalog"))
	openGameTab("Inventory")
	local succeeded, result = controller:OpenSelection("Honor", "honor:" .. itemId, false)
	if not succeeded then
		return false, result
	end
	return true
end

local referenceHUDStateKey
local referenceHUDStateApplications = 0
local function setVisibleIfChanged(object, visible)
	if object and object.Visible ~= visible then
		object.Visible = visible
	end
end

applyReferenceHUDState = function(force)
	local hostVisible = mainPanel.Visible
	local standaloneVisible = shared.PunchWallStandaloneWindows.RebirthPanel.Visible
		or shared.PunchWallStandaloneWindows.SettingsPanel.Visible
	local menuVisible = hostVisible or standaloneVisible
	local shopVisible = hostVisible and activeTab == "Fists"
	local inventoryVisible = hostVisible and activeTab == "Inventory"
	local activeSurface = standaloneVisible and tostring(gui:GetAttribute("ActiveStandaloneWindow") or "Standalone") or tostring(activeTab)
	local stateKey = ("%s:%s"):format(menuVisible and "open" or "closed", activeSurface)
	if force ~= true and stateKey == referenceHUDStateKey then
		return false
	end
	referenceHUDStateKey = stateKey
	referenceHUDStateApplications += 1

	setVisibleIfChanged(statusDeck, false)
	setVisibleIfChanged(leftDock, false)
	setVisibleIfChanged(rightDock, false)
	setVisibleIfChanged(nextWorld, false)
	setVisibleIfChanged(help, false)
	setVisibleIfChanged(mobileControls, false)
	setVisibleIfChanged(bossHUD, false)
	setVisibleIfChanged(contextLabel, false)
	setVisibleIfChanged(referenceHUD, not menuVisible)
	local contextActionVisible = not menuVisible
		and gui:GetAttribute("ContextualActionAvailable") == true
	setVisibleIfChanged(shared.PunchWallContextActionButton, contextActionVisible)
	if shared.PunchWallContextActionButton then
		shared.PunchWallContextActionButton.Active = contextActionVisible
	end

	local shopWasVisible = shared.PunchWallShopReference.Visible
	setVisibleIfChanged(shared.PunchWallShopReference, shopVisible)
	setVisibleIfChanged(shared.PunchWallShopDimmer, shopVisible)
	if shopVisible and not shopWasVisible and shared.PunchWallHeroShopRefresh then
		shared.PunchWallHeroShopRefresh()
	end

	if shared.PunchWallInventoryController:IsVisible() ~= inventoryVisible then
		shared.PunchWallInventoryController:SetVisible(inventoryVisible)
	end
	setVisibleIfChanged(closeButton, menuVisible and not shopVisible and not inventoryVisible)
	local backgroundTransparency = (shopVisible or inventoryVisible) and 1 or 0.03
	if mainPanel.BackgroundTransparency ~= backgroundTransparency then
		mainPanel.BackgroundTransparency = backgroundTransparency
	end
	-- Inventory owns a complete modal frame. Suppress the generic GameMenu
	-- outline/accent while it is active so two unrelated frames do not stack.
	mainStroke.Transparency = inventoryVisible and 1 or 0
	local mainAccent = mainPanel:FindFirstChild("HeroAccent")
	if mainAccent then
		mainAccent.Visible = not inventoryVisible
	end
	mainPanel:SetAttribute("InventoryParentChromeSuppressed", inventoryVisible)

	gui:SetAttribute("HUDVisibilitySyncMode", "EventDrivenV2")
	gui:SetAttribute("HUDVisibilityApplyCount", referenceHUDStateApplications)
	gui:SetAttribute("HUDIdleRenderWrites", 0)
	return true
end

shared.PunchWallJoystickVector = Vector2.zero
shared.PunchWallBuildJoystickInput = function()
	local joystickTouch
	local function updateJoystick(input)
		local center = referenceJoystick.AbsolutePosition + referenceJoystick.AbsoluteSize * 0.5
		local radius = math.max(1, math.min(referenceJoystick.AbsoluteSize.X, referenceJoystick.AbsoluteSize.Y) * 0.36)
		local delta = Vector2.new(input.Position.X, input.Position.Y) - center
		shared.PunchWallJoystickVector = delta.Magnitude > radius and delta.Unit or delta / radius
	end
	referenceJoystick.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			joystickTouch = input
			updateJoystick(input)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if joystickTouch and input == joystickTouch then updateJoystick(input) end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input == joystickTouch then
			joystickTouch = nil
			shared.PunchWallJoystickVector = Vector2.zero
		end
	end)
end
shared.PunchWallBuildJoystickInput()
shared.PunchWallBuildJoystickInput = nil

statRemote.OnClientEvent:Connect(function(payload)
	local widgets = shared.PunchWallHUDWidgets
	widgets.PowerValue.Text = formatNumber(payload.EffectivePower or payload.Power or 0)
	widgets.CoinsValue.Text = formatNumber(payload.Coins or 0)
	widgets.DepthValue.Text = formatNumber(payload.Depth or 0)
	widgets.HonorValue.Text = formatNumber(payload.Honor or 0)
	local questTarget = math.max(1, tonumber(payload.Rewards and payload.Rewards.QuestBreakTarget) or GameConfig.Rewards.QuestBreakTarget)
	local questBreaks = math.clamp(tonumber(payload.DailyBreaks) or 0, 0, questTarget)
	widgets.QuestDetail.Text = ("BREAK %d FOREST BLOCKS"):format(questTarget)
	widgets.QuestProgress.Text = ("%d / %d"):format(questBreaks, questTarget)
	widgets.QuestReward.Text = ("REWARD  %s COINS"):format(formatNumber(payload.Rewards and payload.Rewards.QuestCoins or GameConfig.Rewards.QuestCoins))
	widgets.QuestFill.Size = UDim2.fromScale(questBreaks / questTarget, 1)
	local worldTarget = math.max(1, tonumber(payload.WorldProgressTarget) or 75)
	local depth = math.max(0, tonumber(payload.Depth) or 0)
	shared.PunchWallUpdateTierAtmosphere(depth)
	local worldRatio = math.clamp(depth / worldTarget, 0, 1)
	widgets.WorldFill.Size = UDim2.fromScale(worldRatio, 1)
	widgets.WorldProgress.Text = ("%d%%  |  D%d/%d"):format(math.floor(worldRatio * 100 + 0.5), math.min(depth, worldTarget), worldTarget)
	local tutorial = payload.Tutorial
	if type(tutorial) == "table" then
		widgets.ObjectiveText.Text = ("OBJECTIVE  |  %s\n%s"):format(string.upper(tostring(tutorial.title or "KEEP SMASHING")), tostring(tutorial.detail or ""))
		widgets.ObjectiveCard.Visible = (tonumber(payload.TutorialStep) or 1) < 8
		gui:SetAttribute("OnboardingObjectiveReady", widgets.ObjectiveCard.Visible and widgets.ObjectiveText.Text ~= "")
		gui:SetAttribute("OnboardingObjectiveStep", tonumber(payload.TutorialStep) or 1)
	else
		widgets.ObjectiveCard.Visible = false
		gui:SetAttribute("OnboardingObjectiveReady", false)
	end
	referenceHUD:SetAttribute("AuthoritativeDepth", depth)
	referenceHUD:SetAttribute("AuthoritativeQuestBreaks", questBreaks)
	referenceHUD:SetAttribute("AuthoritativeWorldProgress", worldRatio)
	rankWidgets.Title.Text = ("#%d  %s"):format(tonumber(payload.RankPosition) or 1, tostring(payload.Rank or "ROOKIE"))
	rankWidgets.Stats.Text = ("DEPTH %d  |  SCORE %s"):format(tonumber(payload.Depth) or 0, formatNumber(payload.Score or 0))
	rankWidgets.TrackFill.Size = UDim2.fromScale(1, worldRatio)
	for index, marker in ipairs(rankWidgets.Markers) do
		local entry = type(payload.Leaderboard) == "table" and payload.Leaderboard[index] or nil
		if entry then
			local ratio = math.clamp((tonumber(entry.depth) or 0) / worldTarget, 0, 1)
			marker.avatar.Position = UDim2.fromScale(0.5, 1 - ratio)
			marker.avatar.Image = ("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"):format(tonumber(entry.userId) or 0)
			marker.name.Text = ("%s D%d"):format(string.sub(tostring(entry.name or "Hero"), 1, 9), tonumber(entry.depth) or 0)
			marker.stroke.Color = tonumber(entry.userId) == player.UserId and Color3.fromRGB(255, 211, 64)
				or index == 1 and Color3.fromRGB(255, 76, 58)
				or Color3.fromRGB(46, 194, 242)
			marker.avatar.Visible = true
		else
			marker.avatar.Visible = false
		end
	end
	if shared.PunchWallHeroShopRefresh and shared.PunchWallShopReference.Visible then
		shared.PunchWallHeroShopRefresh()
	end
	if shared.PunchWallInventoryController and shared.PunchWallInventoryController:IsVisible() then
		shared.PunchWallInventoryController:Refresh(false, false)
	end
	if shared.PunchWallRefreshSpin then shared.PunchWallRefreshSpin() end
end)

applyReferenceHUDState(true)

local boundTouchGuis = setmetatable({}, { __mode = "k" })
local boundTouchControlFrames = setmetatable({}, { __mode = "k" })
local function bindTouchControlFrame(frame)
	if not frame or not frame:IsA("GuiObject") or boundTouchControlFrames[frame] then return end
	boundTouchControlFrames[frame] = true
	local function keepHidden()
		if frame.Parent and frame.Visible then
			frame.Visible = false
		end
	end
	keepHidden()
	frame:GetPropertyChangedSignal("Visible"):Connect(keepHidden)
end
local function bindTouchGui(touchGui)
	if not touchGui or not touchGui:IsA("ScreenGui") or boundTouchGuis[touchGui] then return end
	boundTouchGuis[touchGui] = true
	local function keepEnabled()
		if touchGui.Parent and not touchGui.Enabled then
			touchGui.Enabled = true
		end
	end
	keepEnabled()
	touchGui:GetPropertyChangedSignal("Enabled"):Connect(keepEnabled)
	for _, descendant in ipairs(touchGui:GetDescendants()) do
		if descendant.Name == "TouchControlFrame" then
			bindTouchControlFrame(descendant)
		end
	end
	touchGui.DescendantAdded:Connect(function(descendant)
		if descendant.Name == "TouchControlFrame" then
			bindTouchControlFrame(descendant)
		end
	end)
end
local existingTouchGui = player.PlayerGui:FindFirstChild("TouchGui")
if existingTouchGui then bindTouchGui(existingTouchGui) end
player.PlayerGui.ChildAdded:Connect(function(child)
	if child.Name == "TouchGui" then bindTouchGui(child) end
end)
gui:SetAttribute("TouchControlSuppressionMode", "EventDriven")

RunService.RenderStepped:Connect(function()
	if shared.PunchWallJoystickVector.Magnitude <= 0 then return end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:Move(Vector3.new(shared.PunchWallJoystickVector.X, 0, shared.PunchWallJoystickVector.Y), true)
	end
end)

punchButton.MouseButton1Down:Connect(function() setPunchHeld(true) end)
punchButton.MouseButton1Up:Connect(function() setPunchHeld(false) end)
punchButton.MouseLeave:Connect(function() setPunchHeld(false) end)

ContextActionService:BindAction("KaijuPunch", function(_, state)
	if state == Enum.UserInputState.Begin then setPunchHeld(true)
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then setPunchHeld(false) end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.F, Enum.KeyCode.ButtonR2)

ContextActionService:BindAction("KaijuTrain", function(_, state)
	if state == Enum.UserInputState.Begin then actionRemote:FireServer("Train") end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.R, Enum.KeyCode.ButtonX)

ContextActionService:BindAction("KaijuUse", function(_, state)
	if state == Enum.UserInputState.Begin then actionRemote:FireServer("Use") end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.E, Enum.KeyCode.ButtonY)

ContextActionService:BindAction("KaijuMenu", function(_, state)
	if state == Enum.UserInputState.Begin then
		if shared.PunchWallStandaloneWindows.RebirthPanel.Visible and shared.PunchWallRebirthRuntime.armed and shared.PunchWallRebirthActionCallbacks then
			shared.PunchWallRebirthActionCallbacks.Cancel()
		elseif shared.PunchWallStandaloneWindows.RebirthPanel.Visible or shared.PunchWallStandaloneWindows.SettingsPanel.Visible then
			shared.PunchWallStandaloneWindows.Close("Escape")
		elseif mainPanel.Visible then
			setMenuVisible(false)
		else
			shared.PunchWallOpenSettingsPanel("menu_key")
		end
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.B, Enum.KeyCode.Escape, Enum.KeyCode.ButtonSelect, Enum.KeyCode.ButtonB)

applyResponsiveLayout = function()
	local camera = workspace.CurrentCamera
	if not camera then return end
	local viewport = camera.ViewportSize
	-- Studio Device Simulator can transiently report a 1x1 camera viewport even
	-- while the player HUD is already rasterized at the selected device size.
	-- Use the full-screen reference HUD as the authoritative fallback so modal
	-- geometry never collapses to 1x1 during simulator/play transitions.
	if viewport.X < 320 or viewport.Y < 240 then
		local referenceRoot = gui:FindFirstChild("PixelPerfectHeroCityHUD")
		local referenceSize = referenceRoot and referenceRoot.AbsoluteSize
		if referenceSize and referenceSize.X >= 320 and referenceSize.Y >= 240 then
			viewport = referenceSize
		end
	end
	gui:SetAttribute("ResponsiveViewportWidth", math.floor(viewport.X + 0.5))
	gui:SetAttribute("ResponsiveViewportHeight", math.floor(viewport.Y + 0.5))
	local compact = UserInputService.TouchEnabled or viewport.Y < 520
	local coreGuiTopLeft = Vector2.zero
	local coreGuiBottomRight = Vector2.zero
	pcall(function()
		coreGuiTopLeft, coreGuiBottomRight = GuiService:GetGuiInset()
	end)
	gui:SetAttribute("CoreGuiInsetLeft", math.floor(coreGuiTopLeft.X + 0.5))
	gui:SetAttribute("CoreGuiInsetTop", math.floor(coreGuiTopLeft.Y + 0.5))
	gui:SetAttribute("CoreGuiInsetRight", math.floor(coreGuiBottomRight.X + 0.5))
	gui:SetAttribute("CoreGuiInsetBottom", math.floor(coreGuiBottomRight.Y + 0.5))
	local userScale = math.clamp(tonumber(clientSettings.uiScale) or 1, 0.8, 1.2)
	if compact then
		local rebirthWidth = math.min(820, math.max(1, viewport.X - 24))
		local rebirthHeight = math.min(350, math.max(1, viewport.Y - 24))
		shared.PunchWallStandaloneWindows.RebirthPanel.Size = UDim2.fromOffset(rebirthWidth, rebirthHeight)
		shared.PunchWallStandaloneWindows.SettingsPanel.Size = UDim2.fromOffset(math.min(700, math.max(1, viewport.X - 24)), math.min(326, math.max(1, viewport.Y - 24)))
		-- Keep standalone headers outside Roblox's top-left system cluster on
		-- compact devices. This reserve remains necessary even when CoreGui is
		-- temporarily hidden because the platform controls can overlay one frame.
		local compactHeaderLeft = math.max(90, math.floor(coreGuiTopLeft.X + 8))
		for _, panel in ipairs({ shared.PunchWallStandaloneWindows.RebirthPanel, shared.PunchWallStandaloneWindows.SettingsPanel }) do
			local header = panel:FindFirstChild("Header")
			local headerIcon = header and header:FindFirstChild("HeaderIcon")
			local title = header and header:FindFirstChild("Title")
			local subtitle = header and header:FindFirstChild("Subtitle")
			if headerIcon then headerIcon.Position = UDim2.fromOffset(compactHeaderLeft, 11) end
			if title then
				title.Position = UDim2.fromOffset(compactHeaderLeft + 60, 8)
				title.Size = UDim2.new(1, -(compactHeaderLeft + 132), 0, 34)
			end
			if subtitle then
				subtitle.Position = UDim2.fromOffset(compactHeaderLeft + 61, 40)
				subtitle.Size = UDim2.new(1, -(compactHeaderLeft + 136), 0, 20)
			end
			panel:SetAttribute("CompactHeaderSafeLeft", compactHeaderLeft)
		end
		-- The compact reward card is only ~116px tall. Use an explicit vertical
		-- stack so the icon, POWER label and multiplier never overlap.
		local reward = shared.PunchWallStandaloneWindows.RebirthBody:FindFirstChild("RewardCard")
		local rewardIcon = reward and reward:FindFirstChild("RewardIcon")
		local rewardTitle = reward and reward:FindFirstChild("RewardTitle")
		local rewardValue = reward and reward:FindFirstChild("RewardValue")
		if rewardIcon then
			rewardIcon.Position = UDim2.new(0.5, -24, 0, 6)
			rewardIcon.Size = UDim2.fromOffset(48, 48)
		end
		if rewardTitle then
			rewardTitle.Position = UDim2.new(0.08, 0, 0, 56)
			rewardTitle.Size = UDim2.new(0.84, 0, 0, 18)
		end
		if rewardValue then
			rewardValue.Position = UDim2.new(0.04, 0, 0, 76)
			rewardValue.Size = UDim2.new(0.92, 0, 0, 30)
		end
		for rowIndex, rowName in ipairs({ "SOUNDSetting", "MOTIONSetting", "UI SIZESetting" }) do
			local row = shared.PunchWallStandaloneWindows.SettingsBody:FindFirstChild(rowName)
			if row then
				row.Position = UDim2.fromOffset(0, (rowIndex - 1) * 56)
				row.Size = UDim2.new(1, 0, 0, 52)
				row.ClipsDescendants = true
				local icon = row:FindFirstChild("SettingIcon")
				local title = row:FindFirstChild("SettingTitle")
				local helper = row:FindFirstChild("SettingHelper")
				if icon then
					icon.Position = UDim2.fromOffset(6, 6)
					icon.Size = UDim2.fromOffset(40, 40)
				end
				if title then
					title.Position = UDim2.fromOffset(54, 3)
					title.Size = UDim2.fromOffset(132, 22)
				end
				if helper then
					helper.Position = UDim2.fromOffset(54, 26)
					helper.Size = UDim2.fromOffset(154, 20)
				end
				row:SetAttribute("ResponsiveRowProfile", "CompactContained52V1")
			end
		end
		local settingsFooter = shared.PunchWallStandaloneWindows.SettingsBody:FindFirstChild("Footer")
		if settingsFooter then
			settingsFooter.Position = UDim2.new(0, 0, 1, -52)
			settingsFooter.Size = UDim2.new(1, 0, 0, 52)
		end
		shared.PunchWallStandaloneWindows.RebirthPanel:SetAttribute("ResponsiveProfile", "StandaloneCompactSafeV1")
		shared.PunchWallStandaloneWindows.SettingsPanel:SetAttribute("ResponsiveProfile", "StandaloneCompactSafeV1")
	else
		shared.PunchWallStandaloneWindows.RebirthPanel.Size = UDim2.fromOffset(720, 468)
		shared.PunchWallStandaloneWindows.SettingsPanel.Size = UDim2.fromOffset(640, 420)
		for _, panel in ipairs({ shared.PunchWallStandaloneWindows.RebirthPanel, shared.PunchWallStandaloneWindows.SettingsPanel }) do
			local header = panel:FindFirstChild("Header")
			local headerIcon = header and header:FindFirstChild("HeaderIcon")
			local title = header and header:FindFirstChild("Title")
			local subtitle = header and header:FindFirstChild("Subtitle")
			if headerIcon then headerIcon.Position = UDim2.fromOffset(16, 11) end
			if title then
				title.Position = UDim2.fromOffset(76, 8)
				title.Size = UDim2.new(1, -148, 0, 34)
			end
			if subtitle then
				subtitle.Position = UDim2.fromOffset(77, 40)
				subtitle.Size = UDim2.new(1, -152, 0, 20)
			end
			panel:SetAttribute("CompactHeaderSafeLeft", 0)
		end
		local reward = shared.PunchWallStandaloneWindows.RebirthBody:FindFirstChild("RewardCard")
		local rewardIcon = reward and reward:FindFirstChild("RewardIcon")
		local rewardTitle = reward and reward:FindFirstChild("RewardTitle")
		local rewardValue = reward and reward:FindFirstChild("RewardValue")
		if rewardIcon then
			rewardIcon.Position = UDim2.new(0.5, -39, 0, 10)
			rewardIcon.Size = UDim2.fromOffset(78, 78)
		end
		if rewardTitle then
			rewardTitle.Position = UDim2.fromScale(0.08, 0.54)
			rewardTitle.Size = UDim2.fromScale(0.84, 0.18)
		end
		if rewardValue then
			rewardValue.Position = UDim2.fromScale(0.04, 0.71)
			rewardValue.Size = UDim2.fromScale(0.92, 0.25)
		end
		for rowIndex, rowName in ipairs({ "SOUNDSetting", "MOTIONSetting", "UI SIZESetting" }) do
			local row = shared.PunchWallStandaloneWindows.SettingsBody:FindFirstChild(rowName)
			if row then
				row.Position = UDim2.new(0, 0, 0, (rowIndex - 1) * 82)
				row.Size = UDim2.new(1, 0, 0, 72)
				row.ClipsDescendants = false
				local icon = row:FindFirstChild("SettingIcon")
				local title = row:FindFirstChild("SettingTitle")
				local helper = row:FindFirstChild("SettingHelper")
				if icon then
					icon.Position = UDim2.fromOffset(12, 12)
					icon.Size = UDim2.fromOffset(48, 48)
				end
				if title then
					title.Position = UDim2.fromOffset(70, 7)
					title.Size = UDim2.fromOffset(130, 25)
				end
				if helper then
					helper.Position = UDim2.fromOffset(70, 31)
					helper.Size = UDim2.fromOffset(170, 28)
				end
				row:SetAttribute("ResponsiveRowProfile", "Desktop72V1")
			end
		end
		local settingsFooter = shared.PunchWallStandaloneWindows.SettingsBody:FindFirstChild("Footer")
		if settingsFooter then
			settingsFooter.Position = UDim2.new(0, 0, 1, -56)
			settingsFooter.Size = UDim2.new(1, 0, 0, 56)
		end
		shared.PunchWallStandaloneWindows.RebirthPanel:SetAttribute("ResponsiveProfile", "StandaloneDesktopV1")
		shared.PunchWallStandaloneWindows.SettingsPanel:SetAttribute("ResponsiveProfile", "StandaloneDesktopV1")
	end
	local shopOpen = mainPanel.Visible and activeTab == "Fists"
	local inventoryOpen = mainPanel.Visible and activeTab == "Inventory"
	if compact then
		-- Device Simulator can rasterize logical UI units below one screen pixel.
		-- Use a compact offset grid large enough to preserve a real 44 px touch
		-- target while keeping all four menu actions optically identical.
		local compactMenuWidth = 58
		local compactMenuHeight = 72
		local compactMenuGap = 8
		local compactMenuRight = 10
		local compactMenuTop = math.max(54, math.floor(coreGuiTopLeft.Y + 46))
		local compactLeftColumnRight = compactMenuRight + compactMenuWidth + compactMenuGap + 20
		for _, button in ipairs({ referenceInventory, referenceShop, referencePets, referenceQuests, shared.PunchWallReferenceRebirth }) do
			button.AnchorPoint = Vector2.new(1, 0)
			button.Size = UDim2.fromOffset(compactMenuWidth, compactMenuHeight)
			button:SetAttribute("MinimumTouchTarget", 44)
		end
		referenceShop.Position = UDim2.new(1, -compactMenuRight, 0, compactMenuTop)
		referenceInventory.Position = UDim2.new(1, -compactLeftColumnRight, 0, compactMenuTop)
		referencePets.Position = UDim2.new(1, -compactMenuRight, 0, compactMenuTop + compactMenuHeight + compactMenuGap)
		shared.PunchWallReferenceRebirth.Position = UDim2.new(1, -compactLeftColumnRight, 0, compactMenuTop + compactMenuHeight + compactMenuGap)
		referenceQuests.Position = UDim2.new(1, -compactLeftColumnRight, 0, compactMenuTop + (compactMenuHeight + compactMenuGap) * 2)
		referenceHUD:SetAttribute("RightMenuResponsiveProfile", "CompactTouchGrid58x72QuestsJumpSafeV2")
		local compactUtilitySize = 48
		local compactUtilityTop = math.max(4, math.floor(coreGuiTopLeft.Y + 4))
		for utilityIndex, button in ipairs({
			shared.PunchWallMoreToolButton,
			shared.PunchWallSettingsToolButton,
			shared.PunchWallSoundToolButton,
		}) do
			button.AnchorPoint = Vector2.new(1, 0)
			button.Position = UDim2.new(1, -(8 + (utilityIndex - 1) * 52), 0, compactUtilityTop)
			button.Size = UDim2.fromOffset(compactUtilitySize, compactUtilitySize)
		end
		for utilityIndex, button in ipairs({ referenceDaily, referenceSpin }) do
			button.AnchorPoint = Vector2.zero
			button.Position = UDim2.fromOffset(10, compactMenuTop + (utilityIndex - 1) * (compactMenuHeight + compactMenuGap))
			button.Size = UDim2.fromOffset(compactMenuWidth, compactMenuHeight)
		end
		referenceJump.AnchorPoint = Vector2.new(1, 1)
		referenceJump.Position = UDim2.new(1, -8, 1, -8)
		referenceJump.Size = UDim2.fromOffset(86, 86)
		statusDeckScale.Scale = 0.62 * userScale
		statusDeck.AnchorPoint = Vector2.new(0, 0)
		statusDeck.Position = UDim2.fromOffset(math.max(6, (viewport.X - 820 * statusDeckScale.Scale) / 2), 6)
		panelScale.Scale = 0.68 * userScale
		panel.Size = UDim2.fromOffset(310, 102)
		title.Visible = false
		statsList.Position = UDim2.fromOffset(8, 6)
		statsList.Size = UDim2.new(1, -16, 1, -12)
		for _, key in ipairs(order) do labels[key].Visible = key == "Power" or key == "Coins" or key == "WallLevel" end
		panel.Position = UDim2.fromOffset(12, 8)
		help.AnchorPoint = Vector2.new(1, 0)
		help.Position = UDim2.new(1, -8, 0, 58)
		help.Size = UDim2.fromOffset(math.clamp(viewport.X * 0.38, 200, 240), 72)
		help.TextSize = 10
		mobileControls.Position = UDim2.new(1, -8, 1, -8)
		mobileControls.Size = UDim2.fromOffset(278, 136)
		punchButton.Size = UDim2.fromOffset(100, 100)
		punchButton.Position = UDim2.new(1, -92, 1, 0)
		jumpButton.Size = UDim2.fromOffset(86, 86)
		jumpButton.Position = UDim2.new(1, 0, 1, -4)
		trainButton.Position = UDim2.new(1, -100, 0, 0)
		trainButton.Size = UDim2.fromOffset(72, 36)
		useButton.Position = UDim2.new(1, -20, 0, 0)
		useButton.Size = UDim2.fromOffset(72, 36)
		contextLabel.Position = UDim2.new(1, -322, 1, -155)
		contextLabel.Size = UDim2.fromOffset(180, 30)
		shared.PunchWallContextActionButton.Position = UDim2.fromScale(0.56, 0.78)
		shared.PunchWallContextActionButton.Size = UDim2.fromScale(0.24, 0.1)
		shared.PunchWallContextActionButton:SetAttribute("ResponsiveProfile", "CompactCenterSafe")
		menuButton.Position = UDim2.new(0.5, 0, 0, math.max(8, math.floor(coreGuiTopLeft.Y + 8)))
		menuButton.Size = UDim2.fromOffset(78, 44)
		mainPanel.AnchorPoint = Vector2.new(0.5, 0.5)
		if inventoryOpen then
			local availableWidth = math.max(1, viewport.X - 20)
			local availableHeight = math.max(1, viewport.Y - 12)
			local compactAspect = math.clamp(availableWidth / availableHeight, 1.5, 2.1)
			local modalWidth = math.min(availableWidth, availableHeight * compactAspect)
			local modalHeight = math.min(availableHeight, modalWidth / compactAspect)
			mainPanel.Size = UDim2.fromOffset(modalWidth, modalHeight)
			mainPanel:SetAttribute("InventoryModalSizing", "CompactSafeFill")
		elseif shopOpen then
			local aspect = 1.58
			local modalHeight = math.max(270, math.min(viewport.Y - 24, (viewport.X - 24) / aspect))
			mainPanel.Size = UDim2.fromOffset(modalHeight * aspect, modalHeight)
			mainPanel:SetAttribute("ShopModalSizing", "CompactSafeMarginV2")
		else
			local panelHeight = math.max(210, math.min(viewport.Y - 16, (viewport.X - 24) * 408 / 677))
			local panelWidth = panelHeight * 677 / 408
			mainPanel.Size = UDim2.fromOffset(panelWidth, panelHeight)
			closeButton.Position = UDim2.new(1, -8, 0, 8)
			closeButton.Size = UDim2.fromOffset(44, 44)
			-- Roblox's mandatory mobile system cluster occupies the top-left even
			-- when CoreGui is disabled. Reserve that area so the first tab remains
			-- fully readable and tappable in landscape device simulation.
			local leftReserve = math.max(90, math.floor(coreGuiTopLeft.X + 8))
			tabBar.Position = UDim2.fromOffset(leftReserve, 8)
			tabBar.Size = UDim2.new(1, -(leftReserve + 60), 0, 46)
			tabBar.CanvasPosition = Vector2.zero
			tabLayout.Padding = UDim.new(0, 4)
			content.Position = UDim2.fromOffset(10, 62)
			content.Size = UDim2.new(1, -20, 1, -72)
			local availableTabWidth = panelWidth - leftReserve - 60
			local tabWidth = math.max(44, math.floor((availableTabWidth - 16) / 5))
			local compactLabels = { Fists = "FIST", Pets = "PETS", Honor = "HONOR", Tasks = "TASKS", Settings = "SET" }
			for tabName, tab in pairs(tabButtons) do
				local showTabIcon = tabWidth >= 76
				tab.Size = UDim2.fromOffset(tabWidth, 44)
				tab.Text = compactLabels[tabName] or string.upper(tabName)
				tab.TextSize = tabWidth <= 48 and 8 or 9
				tab.TextXAlignment = showTabIcon and Enum.TextXAlignment.Right or Enum.TextXAlignment.Center
				tab.TextTruncate = Enum.TextTruncate.None
				tab:SetAttribute("MinimumTouchTarget", 44)
				local padding = tab:FindFirstChildOfClass("UIPadding")
				if padding then
					padding.PaddingLeft = UDim.new(0, showTabIcon and 34 or 2)
					padding.PaddingRight = UDim.new(0, showTabIcon and 4 or 2)
				end
				local icon = tab:FindFirstChild("TabIcon")
				if icon then
					icon.Visible = showTabIcon
					icon.Position = UDim2.fromOffset(5, 10)
					icon.Size = UDim2.fromOffset(24, 24)
				end
			end
			mainPanel:SetAttribute("GenericPhoneMenuLayout", "InsetAwareScrollableTabsV1")
			mainPanel:SetAttribute("GenericPhoneLeftReserve", leftReserve)
			mainPanel:SetAttribute("GenericPhoneMinimumTouchTarget", 44)
		end
		mainPanel.Position = UDim2.fromScale(0.5, 0.5)
		if rankWidgets.Root then
			rankWidgets.Root.Position = UDim2.fromOffset(74, 92)
			rankWidgets.Root.Size = UDim2.fromOffset(100, 228)
		end
		toastHolder.Position = UDim2.new(0.23, 0, 0, math.max(60, math.floor(coreGuiTopLeft.Y + 8)))
		toastHolder.Size = UDim2.fromOffset(260, 110)
		rewardHolder.Position = UDim2.fromScale(0.5, 0.66)
		rewardHolder.Size = UDim2.fromOffset(320, 150)
		bossHUD.Position = UDim2.new(0.32, 0, 0, 66)
		bossHUD.Size = UDim2.fromOffset(250, 56)
		targetHUD.AnchorPoint = Vector2.new(0.5, 0)
		targetHUD.Position = UDim2.fromScale(0.61, 0.16)
		targetHUD.Size = UDim2.fromOffset(500, 86)
		leftDock.Position = UDim2.new(0, 7, 0.5, 12)
		rightDock.Position = UDim2.new(1, -7, 0.5, 44)
		local leftScale = leftDock:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", leftDock)
		local rightScale = rightDock:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", rightDock)
		leftScale.Scale = 0.68 * userScale
		rightScale.Scale = 0.68 * userScale
		nextWorld.Position = UDim2.new(0.6, 0, 1, -6)
		local nextScale = nextWorld:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", nextWorld)
		nextScale.Scale = 0.68 * userScale
	else
		for _, button in ipairs({ referenceInventory, referenceShop, referencePets, referenceQuests, shared.PunchWallReferenceRebirth }) do
			button.AnchorPoint = Vector2.zero
		end
		referenceInventory.Position, referenceInventory.Size = designRect(inventoryMenuX, rightMenuTop, rightMenuIconWidth, rightMenuIconHeight)
		referenceShop.Position, referenceShop.Size = designRect(rightMenuColumnX, rightMenuTop, rightMenuIconWidth, rightMenuIconHeight)
		referencePets.Position, referencePets.Size = designRect(rightMenuColumnX, rightMenuTop + rightMenuIconHeight + rightMenuIconGap, rightMenuIconWidth, rightMenuIconHeight)
		referenceQuests.Position, referenceQuests.Size = designRect(rightMenuColumnX, rightMenuTop + (rightMenuIconHeight + rightMenuIconGap) * 2, rightMenuIconWidth, rightMenuIconHeight)
		shared.PunchWallReferenceRebirth.Position, shared.PunchWallReferenceRebirth.Size = designRect(16, 429, 82, 111)
		shared.PunchWallSoundToolButton.AnchorPoint = Vector2.zero
		shared.PunchWallSoundToolButton.Position, shared.PunchWallSoundToolButton.Size = designRect(1465, 22, 60, 64)
		shared.PunchWallSettingsToolButton.AnchorPoint = Vector2.zero
		shared.PunchWallSettingsToolButton.Position, shared.PunchWallSettingsToolButton.Size = designRect(1526, 22, 60, 64)
		shared.PunchWallMoreToolButton.AnchorPoint = Vector2.zero
		shared.PunchWallMoreToolButton.Position, shared.PunchWallMoreToolButton.Size = designRect(1587, 22, 64, 64)
		referenceDaily.AnchorPoint = Vector2.zero
		referenceDaily.Position, referenceDaily.Size = designRect(16, 201, 82, 111)
		referenceSpin.AnchorPoint = Vector2.zero
		referenceSpin.Position, referenceSpin.Size = designRect(16, 316, 82, 111)
		referenceJump.AnchorPoint = Vector2.zero
		referenceJump.Position, referenceJump.Size = designRect(1460, 694, 211, 211)
		referenceHUD:SetAttribute("RightMenuResponsiveProfile", "ReferenceUniformIconGrid")
		statusDeckScale.Scale = userScale
		statusDeck.AnchorPoint = Vector2.new(0.5, 0)
		statusDeck.Position = UDim2.new(0.5, 0, 0, 14)
		panelScale.Scale = userScale
		panel.Size = UDim2.fromOffset(310, 196)
		title.Visible = true
		title.Text = "HERO STATUS"
		statsList.Position = UDim2.fromOffset(14, 46)
		statsList.Size = UDim2.new(1, -28, 1, -58)
		for _, key in ipairs(order) do labels[key].Visible = true end
		panel.Position = UDim2.fromOffset(18, 18)
		help.AnchorPoint = Vector2.new(1, 0)
		help.Position = UDim2.new(1, -18, 0, 112)
		help.Size = UDim2.fromOffset(286, 98)
		help.TextSize = 14
		mobileControls.Position = UDim2.new(1, -18, 1, -18)
		mobileControls.Size = UDim2.fromOffset(330, 170)
		punchButton.Size = UDim2.fromOffset(126, 126)
		punchButton.Position = UDim2.new(1, -116, 1, 0)
		jumpButton.Size = UDim2.fromOffset(108, 108)
		jumpButton.Position = UDim2.new(1, 0, 1, -4)
		trainButton.Position = UDim2.new(1, -141, 0, 0)
		trainButton.Size = UDim2.fromOffset(88, 42)
		useButton.Position = UDim2.new(1, -48, 0, 0)
		useButton.Size = UDim2.fromOffset(88, 42)
		contextLabel.Position = UDim2.new(0.5, 0, 1, -32)
		contextLabel.Size = UDim2.fromOffset(220, 30)
		shared.PunchWallContextActionButton.Position = UDim2.fromScale(0.56, 0.79)
		shared.PunchWallContextActionButton.Size = UDim2.fromScale(0.22, 0.078)
		shared.PunchWallContextActionButton:SetAttribute("ResponsiveProfile", "DesktopCenterSafe")
		menuButton.Position = UDim2.new(1, -18, 0, 18)
		menuButton.Size = UDim2.fromOffset(92, 42)
		mainPanel.AnchorPoint = Vector2.new(0.5, 0.5)
		if inventoryOpen then
			local referenceAspect = 1.5
			local availableWidth = math.max(1, viewport.X - 48)
			local availableHeight = math.max(1, viewport.Y - 36)
			local modalWidth = math.min(viewport.X * 0.72, viewport.Y * 0.84 * referenceAspect, availableWidth)
			local modalHeight = math.min(modalWidth / referenceAspect, availableHeight)
			modalWidth = modalHeight * referenceAspect
			mainPanel.Size = UDim2.fromOffset(modalWidth, modalHeight)
			mainPanel.Position = UDim2.fromScale(0.5, 0.5)
			mainPanel:SetAttribute("InventoryModalSizing", "CenteredReference1.50")
		elseif shopOpen then
			local aspect = 1.52
			local modalHeight = math.max(440, math.min(viewport.Y - 64, 820, (viewport.X - 64) / aspect))
			mainPanel.Size = UDim2.fromOffset(modalHeight * aspect, modalHeight)
			mainPanel.Position = UDim2.fromScale(0.5, 0.5)
			mainPanel:SetAttribute("ShopModalSizing", "DesktopSafeMarginV2")
		else
			mainPanel.Size = UDim2.fromOffset(677, 408)
			mainPanel.Position = UDim2.fromScale(0.5, 0.52)
			closeButton.Position = UDim2.new(1, -10, 0, 10)
			closeButton.Size = UDim2.fromOffset(44, 44)
			tabBar.Position = UDim2.fromOffset(12, 12)
			tabBar.Size = UDim2.new(1, -72, 0, 48)
			tabBar.CanvasPosition = Vector2.zero
			tabLayout.Padding = UDim.new(0, 7)
			content.Position = UDim2.fromOffset(12, 68)
			content.Size = UDim2.new(1, -24, 1, -80)
			for tabName, tab in pairs(tabButtons) do
				tab.Size = UDim2.fromOffset(108, 44)
				tab.Text = string.upper(tabName)
				tab.TextSize = 11
				tab.TextXAlignment = Enum.TextXAlignment.Right
				tab.TextTruncate = Enum.TextTruncate.AtEnd
				local padding = tab:FindFirstChildOfClass("UIPadding")
				if padding then
					padding.PaddingLeft = UDim.new(0, 36)
					padding.PaddingRight = UDim.new(0, 8)
				end
				local icon = tab:FindFirstChild("TabIcon")
				if icon then
					icon.Visible = true
					icon.Position = UDim2.fromOffset(6, 8)
					icon.Size = UDim2.fromOffset(28, 28)
				end
			end
		end
		if rankWidgets.Root then
			rankWidgets.Root.Position, rankWidgets.Root.Size = designRect(108, 154, 140, 322)
		end
		toastHolder.Position = UDim2.new(0.5, 0, 0, 24)
		toastHolder.Size = UDim2.fromOffset(460, 160)
		rewardHolder.Position = UDim2.fromScale(0.5, 0.48)
		rewardHolder.Size = UDim2.fromOffset(520, 220)
		bossHUD.Position = UDim2.new(0.5, 0, 0, 82)
		bossHUD.Size = UDim2.fromOffset(420, 58)
		targetHUD.AnchorPoint = Vector2.new(0.5, 0)
		targetHUD.Position = UDim2.fromScale(0.62, 0.14)
		targetHUD.Size = UDim2.fromOffset(340, 62)
		leftDock.Position = UDim2.new(0, 18, 0.5, 10)
		rightDock.Position = UDim2.new(1, -18, 0.5, 74)
		local leftScale = leftDock:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", leftDock)
		local rightScale = rightDock:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", rightDock)
		leftScale.Scale = userScale
		rightScale.Scale = userScale
		nextWorld.Position = UDim2.new(0.5, 0, 1, -18)
		local nextScale = nextWorld:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", nextWorld)
		nextScale.Scale = userScale
	end
	scheduleResponsiveHudDiagnostics(compact)
	if shopOpen and shared.PunchWallHeroShopRefresh then
		shared.PunchWallHeroShopRefresh()
	end
	if shared.PunchWallInventoryController then
		local inventoryViewport = mainPanel.AbsoluteSize
		if inventoryViewport.X < 1 or inventoryViewport.Y < 1 then inventoryViewport = viewport end
		shared.PunchWallInventoryController:ApplyResponsive(inventoryViewport, compact, userScale)
	end
	panel.Visible = false
	menuButton.Visible = false
	applyReferenceHUDState(true)
end

if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(applyResponsiveLayout)
end
task.defer(function()
	applyResponsiveLayout()
	actionRemote:FireServer({ action = "RequestSync" })
end)
end

shared.PunchWallClientFinalize()
