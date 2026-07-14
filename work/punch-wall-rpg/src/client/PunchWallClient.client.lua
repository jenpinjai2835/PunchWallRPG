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

local player = Players.LocalPlayer
local PolishConfig = require(ReplicatedStorage:WaitForChild("PolishConfig"))
local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local palette = PolishConfig.Palette
local remotes = ReplicatedStorage:WaitForChild("PunchWallEvents")
local notifyRemote = remotes:WaitForChild("Notify")
local statRemote = remotes:WaitForChild("StatsChanged")
local actionRemote = remotes:WaitForChild("ActionRequest")
local feedbackRemote = remotes:WaitForChild("Feedback")

local latestStats = {}
local clientSettings = { motion = true, sound = true, uiScale = 1 }
local tutorialObjectiveText = "OBJECTIVE  |  Train at the Power Bag"
local openGameTab = function() end

task.spawn(function()
	pcall(function()
		ContentProvider:PreloadAsync({
			GameConfig.GeneratedGraphics.Iteration01Billboard,
			GameConfig.GeneratedGraphics.Iteration01SpawnBillboard,
			GameConfig.GeneratedGraphics.Iteration01MenuBanner,
			GameConfig.GeneratedGraphics.Iteration01GuardianIcon,
			GameConfig.GeneratedGraphics.Iteration02DNABanner,
			GameConfig.GeneratedGraphics.Iteration02PetIcon,
			GameConfig.GeneratedGraphics.Iteration03TasksBanner,
			GameConfig.GeneratedGraphics.Iteration03SettingsBanner,
			GameConfig.GeneratedGraphics.Iteration04ArmoryBanner,
			GameConfig.GeneratedGraphics.Iteration05TitanBanner,
			GameConfig.GeneratedGraphics.HeroCityHUDAtlas,
			GameConfig.GeneratedGraphics.FistUIIconAtlas,
			GameConfig.HeroCityPixelUI.SoundTool,
			GameConfig.HeroCityPixelUI.SettingsTool,
			GameConfig.HeroCityPixelUI.MoreTool,
			GameConfig.HeroCityPixelUI.SmashBillboard,
			GameConfig.ShopArt.StarterGlove,
			GameConfig.ShopArt.ChampionGlove,
			GameConfig.ShopArt.TitanGlove,
			GameConfig.ShopArt.CoinBoost,
			GameConfig.ShopArt.SpeedBoost,
			GameConfig.ShopArt.DamageBoost,
		})
	end)
end)

local function requestAction(action)
	actionRemote:FireServer(action)
end

local function decodeJSON(raw, fallback)
	if type(raw) ~= "string" then return fallback end
	local ok, value = pcall(function() return HttpService:JSONDecode(raw) end)
	return ok and value or fallback
end

local function applyThemeIcon(imageLabel, iconName)
	local atlas = GameConfig.UIIconAtlas
	local region = atlas.regions[iconName] or atlas.regions.Warning
	imageLabel.Image = atlas.image
	imageLabel.ImageRectOffset = Vector2.new(region[1], region[2])
	imageLabel.ImageRectSize = Vector2.new(region[3], region[4])
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

local gui = Instance.new("ScreenGui")
gui.Name = "PunchWallHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ScreenInsets = Enum.ScreenInsets.None
gui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None
gui.ClipToDeviceSafeArea = true
gui:SetAttribute("Theme", PolishConfig.StyleName)
gui.Parent = player:WaitForChild("PlayerGui")

local backgroundMusic = Instance.new("Sound")
backgroundMusic.Name = "Hero Forest Music"
backgroundMusic.SoundId = GameConfig.Audio.Music
backgroundMusic.Volume = 0.16
backgroundMusic.Looped = true
backgroundMusic.Parent = SoundService
backgroundMusic:Play()
gui:SetAttribute("FreeAimPunch", true)
gui:SetAttribute("TargetBlockHUDEnabled", false)
gui:SetAttribute("PunchSoundMode", "SingleChannel")
gui:SetAttribute("PunchAnimationDuration", 0.72)
gui:SetAttribute("PunchWindupSeconds", 0.2)
gui:SetAttribute("PunchLungeStuds", 10.5)
gui:SetAttribute("PunchAttackInterval", 1)
gui:SetAttribute("CenterActionFeedbackEnabled", false)

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
spawnReveal.BackgroundTransparency = 0.18
spawnReveal.BorderSizePixel = 0
spawnReveal.Size = UDim2.fromScale(1, 1)
spawnReveal.ZIndex = 80
spawnReveal.Parent = gui
local revealTitle = Instance.new("TextLabel")
revealTitle.BackgroundTransparency = 1
revealTitle.AnchorPoint = Vector2.new(0.5, 0.5)
revealTitle.Position = UDim2.fromScale(0.5, 0.44)
revealTitle.Size = UDim2.new(0.8, 0, 0, 80)
revealTitle.Font = Enum.Font.GothamBlack
revealTitle.Text = "HERO CITY"
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
revealSubtitle.Text = "POWER UP  |  PUNCH THROUGH DOWNTOWN"
revealSubtitle.TextColor3 = palette.Reward
revealSubtitle.TextSize = 16
revealSubtitle.ZIndex = 81
revealSubtitle.Parent = spawnReveal
task.delay(1.1, function()
	gui:SetAttribute("SpawnRevealPlayed", true)
	TweenService:Create(spawnReveal, TweenInfo.new(0.45), { BackgroundTransparency = 1 }):Play()
	TweenService:Create(revealTitle, TweenInfo.new(0.35), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	TweenService:Create(revealSubtitle, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
	task.delay(0.5, function() if spawnReveal.Parent then spawnReveal:Destroy() end end)
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
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid then humanoid.Jump = true end
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

local rewardLayout = Instance.new("UIListLayout")
rewardLayout.Padding = UDim.new(0, 6)
rewardLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
rewardLayout.VerticalAlignment = Enum.VerticalAlignment.Center
rewardLayout.SortOrder = Enum.SortOrder.LayoutOrder
rewardLayout.Parent = rewardHolder

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
		return ("Equipped %s"):format(GameConfig.FistDefinition(payload.target).displayName)
	elseif payload.type == "Pet" then
		return ("Recruited %s!"):format(tostring(payload.target or "Sidekick"))
	elseif payload.type == "Rebirth" then
		return "REBIRTH COMPLETE"
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
	elseif payload.type == "LevelUp" then
		return ("WALL LEVEL %s"):format(tostring(payload.target or "?"))
	elseif payload.type == "Fail" then
		return tostring(payload.message or "Locked")
	end
	return tostring(payload.type or "Feedback")
end

local function feedbackIcon(payloadType)
	local icons = {
		Punch = "Punch", WeakPoint = "Punch", Reward = "Coin", Train = "Train",
		Shop = "StarterFist", Pet = "Pet", Rebirth = "Rebirth", Boss = "Wall",
		BossPhase = "Warning", BossAttack = "Warning", StructuralCollapse = "Wall", WorldReset = "Wall", LevelUp = "Success", Fail = "Warning",
	}
	return icons[payloadType] or "Success"
end

local performPunchAnimation = function() end
local lastPunchFeedbackAt = 0

local localDebrisFolder = Instance.new("Folder")
localDebrisFolder.Name = "Local Punch Debris"
localDebrisFolder.Parent = workspace

local function spawnLocalBreakDebris(target)
	if not target or not target:IsA("BasePart") then return end
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local offset = rootPart and (rootPart.Position - target.Position) or Vector3.new(0, 0, 1)
	local outward = offset.Magnitude > 0.01 and offset.Unit or Vector3.new(0, 0, 1)
	for index = 1, 8 do
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
	gui:SetAttribute("LastLocalDebrisCount", 8)
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

local function showFeedback(payload)
	if typeof(payload) ~= "table" then
		return
	end
	local count = (gui:GetAttribute("FeedbackCount") or 0) + 1
	gui:SetAttribute("FeedbackCount", count)
	gui:SetAttribute("LastFeedbackType", tostring(payload.type or "Unknown"))
	gui:SetAttribute("LastFeedbackTarget", tostring(payload.target or ""))
	gui:SetAttribute("LastMotionApplied", clientSettings.motion)
	showWorldDamage(payload)
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
		elseif payload.type == "Reward" or payload.type == "LevelUp" then
			playUISound(GameConfig.Audio.Reward, 0.38, payload.type == "LevelUp" and 1.1 or 1)
		elseif payload.type == "Boss" or payload.type == "BossAttack" then
			pulseHaptic(0.65, 0.14)
			playUISound(GameConfig.Audio.BossRoar, 0.45, 0.92)
		elseif payload.type == "StructuralCollapse" then
			pulseHaptic(0.5, 0.11)
			playUISound(GameConfig.Audio.Collapse, 0.32, 0.92)
		end
		return
	end
	if payload.type == "Punch" then
		local feedbackNow = os.clock()
		if feedbackNow - lastPunchFeedbackAt < 0.12 then return end
		lastPunchFeedbackAt = feedbackNow
		local rays = Instance.new("Frame")
		rays.Name = "CombatSparkRays"
		rays.AnchorPoint = Vector2.new(0.5, 0.5)
		rays.Position = UDim2.fromScale(0.545, 0.505)
		rays.Size = UDim2.fromOffset(380, 300)
		rays.BackgroundTransparency = 1
		rays.ZIndex = 44
		rays.Parent = gui
		local impactCore = Instance.new("Frame")
		impactCore.Name = "CombatImpactCore"
		impactCore.AnchorPoint = Vector2.new(0.5, 0.5)
		impactCore.Position = UDim2.fromScale(0.545, 0.505)
		impactCore.Size = UDim2.fromOffset(118, 118)
		impactCore.Rotation = 45
		impactCore.BackgroundColor3 = Color3.fromRGB(255, 218, 72)
		impactCore.BackgroundTransparency = 0.12
		impactCore.BorderSizePixel = 0
		impactCore.ZIndex = 43
		impactCore.Parent = gui
		local impactCorner = Instance.new("UICorner")
		impactCorner.CornerRadius = UDim.new(0.28, 0)
		impactCorner.Parent = impactCore
		local impactScale = Instance.new("UIScale")
		impactScale.Scale = 0.42
		impactScale.Parent = impactCore
		TweenService:Create(impactScale, TweenInfo.new(0.1, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
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
		local burst = Instance.new("TextLabel")
		burst.Name = "CombatDamageBurst"
		burst.AnchorPoint = Vector2.new(0.5, 0.5)
		burst.Position = UDim2.fromScale(0.545, 0.505)
		burst.Size = UDim2.fromOffset(320, 140)
		burst.BackgroundTransparency = 1
		burst.BorderSizePixel = 0
		burst.Font = Enum.Font.GothamBlack
		burst.Text = payload.critical and ("CRITICAL!  %s"):format(formatNumber(payload.damage or 0)) or formatNumber(payload.damage or 0)
		burst.TextColor3 = Color3.new(1, 1, 1)
		burst.TextSize = payload.critical and 76 or 96
		burst.TextStrokeColor3 = Color3.fromRGB(12, 13, 15)
		burst.TextStrokeTransparency = 0
		burst.Rotation = -2
		burst.ZIndex = 46
		burst.Parent = gui
		local burstScale = Instance.new("UIScale")
		burstScale.Scale = 0.45
		burstScale.Parent = burst
		TweenService:Create(burstScale, TweenInfo.new(0.1, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		task.delay(0.28, function()
			if burst.Parent then
				TweenService:Create(burst, TweenInfo.new(0.28), { TextTransparency = 1, TextStrokeTransparency = 1, Position = burst.Position - UDim2.fromOffset(0, 28) }):Play()
			end
			if rays.Parent then TweenService:Create(rays, TweenInfo.new(0.22), { Size = UDim2.fromOffset(470, 370) }):Play() end
		end)
		Debris:AddItem(burst, 0.65)
		Debris:AddItem(rays, 0.5)
		TweenService:Create(impactCore, TweenInfo.new(0.34), { BackgroundTransparency = 1, Rotation = 70 }):Play()
		Debris:AddItem(impactCore, 0.4)
		hitFlash.BackgroundColor3 = payload.color or palette.Punch
		hitFlash.BackgroundTransparency = 0.93
		hitFlash.Visible = true
		TweenService:Create(hitFlash, TweenInfo.new(clientSettings.motion and 0.16 or 0.05), { BackgroundTransparency = 1 }):Play()
		task.delay(0.18, function() if hitFlash.Parent then hitFlash.Visible = false end end)
		pulseHaptic(0.28, 0.05)
		local materialPitch = ({ Brick = 0.96, Concrete = 0.88, Metal = 1.16, Glass = 1.28, ForceField = 1.38 })[tostring(payload.material)] or 1.04
		playPunchImpact(materialPitch)
	elseif payload.type == "Reward" or payload.type == "LevelUp" then
		playUISound(GameConfig.Audio.Reward, 0.38, payload.type == "LevelUp" and 1.1 or 1)
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

	task.delay(PolishConfig.Motion.RewardPopSeconds + 0.08, function()
		if pop.Parent then
			pop:Destroy()
		end
	end)
end

local function showToast(message, color)
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
	addHeroAccent(toast, color or palette.Train)
	local toastPadding = Instance.new("UIPadding")
	toastPadding.PaddingLeft = UDim.new(0, 50)
	toastPadding.PaddingRight = UDim.new(0, 10)
	toastPadding.Parent = toast
	createThemeIcon(toast, "Warning", UDim2.fromOffset(-44, 5), UDim2.fromOffset(34, 34), "ToastIcon")

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

	task.delay(3, function()
		if toast.Parent then
			if clientSettings.motion then
				local tween = TweenService:Create(toast, TweenInfo.new(0.22), {
					TextTransparency = 1,
					BackgroundTransparency = 1,
				})
				tween:Play()
				tween.Completed:Wait()
			end
			toast:Destroy()
		end
	end)
end

local refreshCharacterVisuals = function() end
local renderOpenPanel = function() end

statRemote.OnClientEvent:Connect(function(payload)
	latestStats = payload
	clientSettings = decodeJSON(payload.SettingsJSON, clientSettings)
	backgroundMusic.Volume = clientSettings.sound and 0.16 or 0
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
	renderOpenPanel()
end)

notifyRemote.OnClientEvent:Connect(showToast)
feedbackRemote.OnClientEvent:Connect(showFeedback)

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
closeButton.Parent = mainPanel

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 7)
closeCorner.Parent = closeButton

local tabBar = Instance.new("Frame")
tabBar.Name = "Tabs"
tabBar.Position = UDim2.fromOffset(12, 12)
tabBar.Size = UDim2.new(1, -72, 0, 48)
tabBar.BackgroundTransparency = 1
tabBar.Parent = mainPanel

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
local tabButtons = {}

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

for order, tabName in ipairs({ "Fists", "Pets", "Tasks", "Settings" }) do
	local tab = makeMenuCommand(tabBar, tabName .. "Tab", string.upper(tabName), palette.PanelSoft, function()
		activeTab = tabName
		renderOpenPanel()
	end)
	tab.Size = UDim2.fromOffset(116, 44)
	tab.LayoutOrder = order
	tab.TextSize = 11
	tab.TextXAlignment = Enum.TextXAlignment.Right
	local tabPadding = Instance.new("UIPadding")
	tabPadding.PaddingLeft = UDim.new(0, 36)
	tabPadding.PaddingRight = UDim.new(0, 8)
	tabPadding.Parent = tab
	local tabIcon = tabName == "Fists" and "StarterFist" or tabName == "Pets" and "Pet" or tabName == "Tasks" and "Quest" or "Settings"
	createThemeIcon(tab, tabIcon, UDim2.fromOffset(-31, 8), UDim2.fromOffset(28, 28), "TabIcon")
	tabButtons[tabName] = tab
end

local function clearContent()
	for _, child in ipairs(content:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end
end

local function addGeneratedBanner()
	local compactBanner = UserInputService.TouchEnabled or (workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.Y < 520)
	local isPets = activeTab == "Pets"
	local isTasks = activeTab == "Tasks"
	local isSettings = activeTab == "Settings"
	local bannerImage = isPets and GameConfig.GeneratedGraphics.Iteration02DNABanner
		or isTasks and GameConfig.GeneratedGraphics.Iteration03TasksBanner
		or isSettings and GameConfig.GeneratedGraphics.Iteration03SettingsBanner
		or GameConfig.GeneratedGraphics.HeroCityHUDAtlas
	local bannerTitle = isPets and "HERO SIDEKICK LAB"
		or isTasks and "HERO MISSIONS"
		or isSettings and "HERO CONTROL"
		or "HERO FIST HQ"
	local bannerSubtitle = isPets and "RECRUIT | EQUIP | TEAM UP"
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

local function addSection(textValue, color)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -4, 0, 30)
	label.Font = Enum.Font.GothamBold
	label.Text = textValue
	label.TextColor3 = color or palette.Text
	label.TextSize = 14
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = content
	return label
end

local function addRow(name, description, accent, iconName)
	local row = Instance.new("Frame")
	row.Name = name
	row.Size = UDim2.new(1, -4, 0, 64)
	row.BackgroundColor3 = Color3.fromRGB(27, 38, 49)
	row.BorderSizePixel = 0
	row.Parent = content
	setRounded(row, 6)
	local stripe = Instance.new("Frame")
	stripe.Size = UDim2.fromOffset(5, 64)
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
	titleLabel.Size = UDim2.new(1, -(textLeft + 255), 0, 23)
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
	descLabel.Size = UDim2.new(1, -(textLeft + 255), 0, 22)
	descLabel.Font = Enum.Font.Gotham
	descLabel.Text = description
	descLabel.TextColor3 = palette.MutedText
	descLabel.TextSize = 12
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.TextTruncate = Enum.TextTruncate.AtEnd
	descLabel.Parent = row
	local actions = Instance.new("Frame")
	actions.Name = "Actions"
	actions.AnchorPoint = Vector2.new(1, 0.5)
	actions.Position = UDim2.new(1, -8, 0.5, 0)
	actions.Size = UDim2.fromOffset(238, 44)
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
	addSection("HERO FISTS  |  POWER PROGRESSION", palette.RoadLine)
	local masteryMultiplier = 1 + math.min(latestStats.FistMastery or 1, 500) * 0.001
	addRow("COMBAT PROFILE", ("Power %s  |  Mastery x%.3f  |  Speed %.2f  |  Crit %.1f%%"):format(formatNumber(latestStats.Power or 0), masteryMultiplier, latestStats.BreakSpeed or 1, latestStats.CritChance or 0), palette.Train, "Punch")
	local owned = decodeJSON(latestStats.OwnedFistsJSON, { "Starter Glove" })
	local shelf = Instance.new("Frame")
	shelf.Name = "FistProductCards"
	shelf.Size = UDim2.new(1, -4, 0, 342)
	shelf.BackgroundTransparency = 1
	shelf.Parent = content
	local grid = Instance.new("UIGridLayout")
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.CellSize = UDim2.new(0.333, -6, 0, 165)
	grid.FillDirectionMaxCells = 3
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
		button.Size = UDim2.new(1, -12, 0, 24)
		button.TextSize = 10
		button.Active = not equipped
	end
end

local function renderPets()
	addSection(("HERO SIDEKICKS  |  Equipped %d/%d"):format(#decodeJSON(latestStats.EquippedPetsJSON, {}), GameConfig.MaxEquippedPets), palette.Use)
	local hatchRow, hatchActions = addRow("SIDEKICK CAPSULE", ("Cost %s coins each  |  Luck %.2f"):format(formatNumber(350), latestStats.Luck or 1), palette.Reward, "Pet")
	makeMenuCommand(hatchActions, "HatchOne", "HATCH x1", palette.Reward, function() actionRemote:FireServer({ action = "HatchPet", value = 1 }) end)
	makeMenuCommand(hatchActions, "HatchThree", "HATCH x3", palette.Use, function() actionRemote:FireServer({ action = "HatchPet", value = 3 }) end)
	local chances = GameConfig.PetChances(latestStats.Luck or 1)
	for _, pet in ipairs(GameConfig.Pets) do
		local discovered = table.find(decodeJSON(latestStats.DiscoveredPetsJSON, {}), pet.name) ~= nil
		local status = discovered and "DISCOVERED" or "UNKNOWN"
		addRow(("[%s] %s"):format(pet.rarity, pet.name), ("%s  |  Power +%.0f%%  |  Chance %.2f%%"):format(status, pet.mult * 100, (chances[pet.name] or 0) * 100), pet.color, "Pet")
	end
	addSection("INVENTORY", palette.Text)
	local inventory = decodeJSON(latestStats.PetInventoryJSON, {})
	local equipped = decodeJSON(latestStats.EquippedPetsJSON, {})
	local locked = decodeJSON(latestStats.LockedPetsJSON, {})
	local equippedCounts = countNames(equipped)
	for index, petName in ipairs(inventory) do
		local pet
		for _, candidate in ipairs(GameConfig.Pets) do if candidate.name == petName then pet = candidate break end end
		pet = pet or { rarity = "Unknown", mult = 0, color = palette.MutedText }
		local row, actions, titleLabel, descLabel = addRow(("#%02d  [%s] %s"):format(index, pet.rarity, petName), ("Power +%.0f%%"):format(pet.mult * 100), pet.color)
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
		titleLabel.Size = UDim2.new(1, -319, 0, 23)
		descLabel.Size = UDim2.new(1, -319, 0, 22)
		local equippedNow = (equippedCounts[petName] or 0) > 0
		if equippedNow then equippedCounts[petName] -= 1 end
		makeMenuCommand(actions, "Equip" .. index, equippedNow and "UNEQUIP" or "EQUIP", equippedNow and palette.Train or palette.Use, function()
			actionRemote:FireServer({ action = equippedNow and "UnequipPet" or "EquipPet", target = petName })
		end).Size = UDim2.fromOffset(78, 44)
		local slotToken = "slot:" .. index
		local isLocked = table.find(locked, slotToken) ~= nil or table.find(locked, petName) ~= nil
		makeMenuCommand(actions, "Lock" .. index, isLocked and "UNLOCK" or "LOCK", isLocked and palette.Train or palette.PanelSoft, function()
			actionRemote:FireServer({ action = "LockPet", target = petName, value = not isLocked, index = index })
		end).Size = UDim2.fromOffset(68, 44)
		makeMenuCommand(actions, "Delete" .. index, "DELETE", isLocked and palette.PanelSoft or palette.Fail, function()
			if isLocked then return end
			actionRemote:FireServer({ action = "DeletePet", target = petName, index = index })
		end).Size = UDim2.fromOffset(68, 44)
	end
	if #inventory == 0 then addSection("No sidekicks yet. Recruit one at the Sidekick Lab.", palette.MutedText) end
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
	addRow("Rebirth Preview", ("Need Wall Lv 55 + 1M coins  |  Permanent bonus x%.2f"):format((latestStats.RebirthBonus or 1) + 0.25), Color3.fromRGB(171, 133, 219), "Rebirth")
end

local function renderSettings()
	addSection("ACCESSIBILITY AND FEEDBACK", palette.RoadLine)
	local function settingRow(name, description, key)
		local _, actions = addRow(name, description, palette.Use, "Settings")
		makeMenuCommand(actions, key, clientSettings[key] and "ON" or "OFF", clientSettings[key] and palette.Reward or palette.Fail, function()
			clientSettings[key] = not clientSettings[key]
			actionRemote:FireServer({ action = "UpdateSettings", value = clientSettings })
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

renderOpenPanel = function()
	if not mainPanel.Visible then return end
	clearContent()
	addGeneratedBanner()
	for name, button in pairs(tabButtons) do
		button.BackgroundColor3 = name == activeTab and palette.RoadLine or palette.PanelSoft
	end
	if activeTab == "Fists" then renderFists()
	elseif activeTab == "Pets" then renderPets()
	elseif activeTab == "Tasks" then renderTasks()
	else renderSettings() end
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
createDockButton(leftDock, "SpinButton", "SPIN", "Success", palette.Use, function() requestAction("Spin") end)
createDockButton(leftDock, "RebirthButton", "REBIRTH", "Rebirth", palette.Train, function() openGameTab("Tasks") end)
createDockButton(rightDock, "ShopButton", "SHOP", "Shop", palette.Reward, function() openGameTab("Fists") end)
createDockButton(rightDock, "PetsButton", "PETS", "Pet", palette.Use, function() openGameTab("Pets") end)
createDockButton(rightDock, "QuestsButton", "QUESTS", "Quest", palette.Reward, function() openGameTab("Tasks") end)

local function setMenuVisible(visible)
	mainPanel.Visible = visible
	mobileControls.Visible = not visible
	statusDeck.Visible = not visible
	leftDock.Visible = not visible
	rightDock.Visible = not visible
	nextWorld.Visible = not visible
	panel.Visible = false
	help.Visible = not visible
	menuButton.Visible = false
	contextLabel.Visible = false
	if visible then
		targetHUD.Visible = false
		bossHUD.Visible = false
	end
	if visible then renderOpenPanel() end
end

openGameTab = function(tabName)
	if tabButtons[tabName] then activeTab = tabName end
	setMenuVisible(true)
end

local function toggleMenu()
	setMenuVisible(not mainPanel.Visible)
end

menuButton.Activated:Connect(toggleMenu)
closeButton.Activated:Connect(function() setMenuVisible(false) end)
mainPanel:GetPropertyChangedSignal("Visible"):Connect(function()
	local visible = mainPanel.Visible
	panel.Visible = false
	statusDeck.Visible = not visible
	leftDock.Visible = not visible
	rightDock.Visible = not visible
	nextWorld.Visible = not visible
	help.Visible = not visible
	menuButton.Visible = false
	mobileControls.Visible = not visible
	if visible then
		targetHUD.Visible = false
		bossHUD.Visible = false
	end
end)

local companionsFolder = Instance.new("Folder")
companionsFolder.Name = player.Name .. " Client Companions"
companionsFolder.Parent = workspace
local companionModels = {}
local visualSignature = ""
local currentGauntlet
local currentTrail

local function visualPart(parent, name, size, color, material, shape)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.Metal
	part.Shape = shape or Enum.PartType.Block
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CastShadow = true
	part.Parent = parent
	return part
end

local function petDefinition(name)
	for _, pet in ipairs(GameConfig.Pets) do if pet.name == name then return pet end end
	return GameConfig.Pets[1]
end

local function buildCompanion(name, index)
	local definition = petDefinition(name)
	local curated = workspace:FindFirstChild("CuratedVisualAssets")
	local dragonTemplate = curated and curated:FindFirstChild("Sanitized Crimson Dragon Companion")
	if dragonTemplate and (definition.rarity == "Legendary" or definition.rarity == "Secret") then
		local clone = dragonTemplate:Clone()
		clone.Name = name .. " Companion " .. index
		clone.Parent = companionsFolder
		clone:ScaleTo(clone:GetScale() * (definition.rarity == "Secret" and 0.36 or 0.28))
		clone.PrimaryPart = clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart", true)
		for _, descendant in ipairs(clone:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
				descendant.CanCollide = false
			end
		end
		table.insert(companionModels, clone)
		return clone
	end
	local model = Instance.new("Model")
	model.Name = name .. " Companion " .. index
	model.Parent = companionsFolder
	local body = visualPart(model, "Body", Vector3.new(1.55, 1.1, 1.9), definition.color, definition.rarity == "Secret" and Enum.Material.Metal or Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	local head = visualPart(model, "Head", Vector3.new(1.15, 1.15, 1.15), definition.color:Lerp(Color3.new(1, 1, 1), 0.08), definition.rarity == "Epic" and Enum.Material.Glass or Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	head.CFrame = body.CFrame * CFrame.new(0, 0.25, -1.05)
	for side = -1, 1, 2 do
		local ear = visualPart(model, "Ear", Vector3.new(0.3, 0.62, 0.24), definition.color, Enum.Material.Metal)
		ear.CFrame = head.CFrame * CFrame.new(side * 0.35, 0.52, 0)
		local eye = visualPart(model, "Eye", Vector3.new(0.18, 0.18, 0.12), Color3.fromRGB(15, 25, 31), Enum.Material.Neon, Enum.PartType.Ball)
		eye.CFrame = head.CFrame * CFrame.new(side * 0.25, 0.13, -0.54)
		if definition.rarity == "Legendary" or definition.rarity == "Secret" then
			local wing = visualPart(model, "Wing", Vector3.new(0.2, 0.95, 1.35), definition.color:Lerp(Color3.new(1, 1, 1), 0.22), Enum.Material.Neon)
			wing.CFrame = body.CFrame * CFrame.new(side * 0.82, 0.22, 0.1) * CFrame.Angles(0, 0, math.rad(side * 24))
		end
	end
	for side = -1, 1, 2 do
		for front = -1, 1, 2 do
			local foot = visualPart(model, "Foot", Vector3.new(0.34, 0.25, 0.48), definition.color:Lerp(Color3.new(0, 0, 0), 0.18), Enum.Material.Metal, Enum.PartType.Ball)
			foot.CFrame = body.CFrame * CFrame.new(side * 0.48, -0.58, front * 0.56)
		end
	end
	local tail = visualPart(model, "Tail", Vector3.new(0.34, 0.34, 1.25), definition.color:Lerp(Color3.new(0, 0, 0), 0.12), Enum.Material.Metal)
	tail.CFrame = body.CFrame * CFrame.new(0, 0.05, 1.35) * CFrame.Angles(math.rad(-18), 0, 0)
	local core = visualPart(model, "Rarity Core", Vector3.new(0.38, 0.38, 0.38), definition.color, Enum.Material.Neon, Enum.PartType.Ball)
	core.CFrame = body.CFrame * CFrame.new(0, 0.18, -0.9)
	model.PrimaryPart = body
	table.insert(companionModels, model)
	return model
end

local function buildGauntlet(fistName)
	if currentGauntlet then currentGauntlet:Destroy() end
	currentGauntlet = nil
	currentTrail = nil
	local character = player.Character
	local hand = character and (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm"))
	if not hand or not hand:IsA("BasePart") then return false end
	local definition = GameConfig.FistDefinition(fistName)
	local model = Instance.new("Model")
	model.Name = "Equipped Kaiju Gauntlet"
	model:SetAttribute("ItemType", "Fist")
	model:SetAttribute("DisplayName", definition.displayName)
	model:SetAttribute("Tier", definition.tier)
	model:SetAttribute("FistStyle", definition.style)
	model:SetAttribute("ClosedFist", true)
	model.Parent = character
	local scale = definition.style == "Titan" and 1.34
		or definition.style == "Thunder" and 1.25
		or definition.style == "Iron" and 1.18
		or definition.style == "Boxing" and 1.12
		or 1.05
	local primary = definition.color
	local accent = definition.accent or primary:Lerp(Color3.new(1, 1, 1), 0.25)

	-- Use sanitized Creator Store visuals when available. The gameplay punch, input,
	-- animation, and damage remain owned by this client/server code.
	local importedSource
	local assetFolder = ReplicatedStorage:FindFirstChild("PunchWallFistAssets")
	if assetFolder then
		if definition.style == "Starter" or definition.style == "Boxing" then
			local pair = assetFolder:FindFirstChild("CreatorStore_RedBoxingGloves")
			local glovePair = pair and pair:FindFirstChild("Glove pair")
			importedSource = glovePair and glovePair:FindFirstChild("glove R")
		elseif definition.style == "Iron" then
			local source = assetFolder:FindFirstChild("CreatorStore_PowerBoxingGloves")
			importedSource = source and source:FindFirstChild("RightGlove", true)
		elseif definition.style == "Thunder" then
			local source = assetFolder:FindFirstChild("CreatorStore_VoidPowerGloves")
			importedSource = source and source:FindFirstChild("R", true)
		elseif definition.style == "Titan" then
			local source = assetFolder:FindFirstChild("CreatorStore_VargasGauntlets")
			local gloves = source and source:FindFirstChild("Vargas's gloves")
			importedSource = gloves and gloves:FindFirstChild("Right")
		end
	end
	if importedSource and importedSource.Parent and assetFolder:GetAttribute("SanitizedVisualOnly") ~= false then
		local imported = importedSource:Clone()
		imported.Name = "Creator Store Fist Visual"
		imported.Parent = model
		-- Creator Store meshes have unrelated authoring scales. Normalize the
		-- largest visual dimension against the actual RightHand before welding,
		-- otherwise a glove can appear as a detached box beside the arm.
		local sourceSize = imported:IsA("Model") and select(2, imported:GetBoundingBox()) or imported.Size
		local styleScale = definition.style == "Titan" and 1.48
			or definition.style == "Thunder" and 1.28
			or definition.style == "Iron" and 1.16
			or definition.style == "Boxing" and 1.04
			or 0.96
		local sourceLargest = math.max(sourceSize.X, sourceSize.Y, sourceSize.Z)
		local importedScale = math.clamp((hand.Size.Y * styleScale) / math.max(sourceLargest, 0.01), 0.38, 1.05)
		if imported:IsA("Model") then imported:ScaleTo(importedScale) else imported.Size *= importedScale end
		-- Imported Creator Store meshes use a different authoring axis than the
		-- character rig. Keep the wrist centered in the glove and turn the
		-- knuckles forward instead of leaving the asset's authoring direction
		-- attached to the side or back of the hand.
		local gripRotation = CFrame.Angles(0, math.rad(180), 0)
		local gripOffset = CFrame.new(0, -hand.Size.Y * 0.06, -hand.Size.Z * 0.20)
		local visualCFrame = hand.CFrame * gripOffset * gripRotation
		if imported:IsA("Model") then imported:PivotTo(visualCFrame) else imported.CFrame = visualCFrame end
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
	local palmOffset = -hand.Size.Z * 0.78
	local palm = weldedPart("Gauntlet Palm", palmSize, primary, definition.material, Enum.PartType.Ball, CFrame.new(0, 0, palmOffset))
	palm:SetAttribute("FistShape", "ClosedPalm")
	local cuff = weldedPart("Gauntlet Tapered Cuff", Vector3.new(hand.Size.Y * 0.42, hand.Size.X * 1.38, hand.Size.Z * 1.42) * scale, primary:Lerp(Color3.new(0, 0, 0), 0.34), Enum.Material.Metal, Enum.PartType.Cylinder, CFrame.new(0, hand.Size.Y * 0.58, 0) * CFrame.Angles(0, 0, math.rad(90)))
	cuff:SetAttribute("FistShape", "WristCuff")
	local backPlate = weldedPart("Fist Backhand Plate", Vector3.new(palmSize.X * 0.82, palmSize.Y * 0.34, palmSize.Z * 0.72), primary:Lerp(accent, 0.18), Enum.Material.Metal, Enum.PartType.Ball, CFrame.new(0, palmSize.Y * 0.18, palmOffset + palmSize.Z * 0.28))
	backPlate:SetAttribute("FistShape", "BackhandPlate")
	for finger = 1, 4 do
		local x = (finger - 2.5) * palmSize.X * 0.215
		local knuckle = weldedPart("Closed Knuckle " .. finger, Vector3.new(palmSize.X * 0.26, palmSize.Y * 0.5, palmSize.Z * 0.38), primary:Lerp(accent, definition.tier >= 4 and 0.34 or 0.12), definition.tier >= 4 and Enum.Material.Metal or definition.material, Enum.PartType.Ball, CFrame.new(x, palmSize.Y * 0.3, palmOffset - palmSize.Z * 0.38))
		knuckle:SetAttribute("FistShape", "RoundedKnuckle")
	end
	local thumb = weldedPart("Closed Fist Thumb", Vector3.new(palmSize.X * 0.34, palmSize.Y * 0.5, palmSize.Z * 0.48), primary, definition.material, Enum.PartType.Ball, CFrame.new(palmSize.X * 0.5, -palmSize.Y * 0.03, palmOffset - palmSize.Z * 0.18) * CFrame.Angles(0, 0, math.rad(-28)))
	thumb:SetAttribute("FistShape", "FoldedThumb")
	local core = weldedPart("Fist Energy Core", Vector3.new(palmSize.X * 0.3, palmSize.Y * 0.3, palmSize.Z * 0.18), accent, definition.tier >= 4 and Enum.Material.Neon or Enum.Material.Metal, Enum.PartType.Ball, CFrame.new(0, palmSize.Y * 0.2, palmOffset + palmSize.Z * 0.58))
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
	currentGauntlet = model
	currentTrail = trail
	return true
end

refreshCharacterVisuals = function()
	local equippedPets = decodeJSON(latestStats.EquippedPetsJSON, {})
	local signature = tostring(latestStats.EquippedFist or "Starter Glove") .. "|" .. table.concat(equippedPets, ",") .. "|" .. tostring(player.Character)
	if signature == visualSignature and currentGauntlet and currentGauntlet.Parent then return end
	if not buildGauntlet(latestStats.EquippedFist or "Starter Glove") then
		visualSignature = ""
		task.delay(0.4, refreshCharacterVisuals)
		return
	end
	visualSignature = signature
	companionsFolder:ClearAllChildren()
	companionModels = {}
	for index, petName in ipairs(equippedPets) do buildCompanion(petName, index) end
end

-- Apply the pose after Animator updates so Motor6D and AnimationConstraint rigs both move.
local punchMotionState
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

performPunchAnimation = function()
	local now = os.clock()
	local interval = tonumber(gui:GetAttribute("PunchAttackInterval")) or 1
	if now - lastPunchMotionAt < interval then return false end
	lastPunchMotionAt = now
	if currentTrail then
		currentTrail.Enabled = true
		task.delay(0.18, function() if currentTrail then currentTrail.Enabled = false end end)
	end
	if not clientSettings.motion then
		gui:SetAttribute("CharacterPunchMotionSuppressed", true)
		return true
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid then return false end
	humanoid.AutoRotate = true
	local rightShoulder = findRigMotor(character, { "RightShoulder", "Right Shoulder" }, { "RightUpperArm", "Right Arm" })
	if not rightShoulder then return false end
	local leftShoulder = findRigMotor(character, { "LeftShoulder", "Left Shoulder" }, { "LeftUpperArm", "Left Arm" })
	local waist = findRigMotor(character, { "Waist", "RootJoint", "Root Joint" }, { "UpperTorso", "Torso" })
	local neck = findRigMotor(character, { "Neck" }, { "Head" })
	punchMotionState = {
		startedAt = now,
		duration = 0.72,
		rightShoulder = rightShoulder,
		leftShoulder = leftShoulder,
		waist = waist,
		neck = neck,
	}
	gui:SetAttribute("CharacterPunchMotionActive", true)
	gui:SetAttribute("CharacterPunchMotionSuppressed", false)
	gui:SetAttribute("CharacterPunchRig", humanoid.RigType == Enum.HumanoidRigType.R15 and "R15" or "R6")
	gui:SetAttribute("CharacterPunchCount", (gui:GetAttribute("CharacterPunchCount") or 0) + 1)
	return true
end

local function tryPunchAction()
	local now = os.clock()
	local interval = tonumber(gui:GetAttribute("PunchAttackInterval")) or 1
	if now - lastPunchActionAt < interval then
		gui:SetAttribute("PunchActionCooldownBlocked", true)
		return false
	end
	lastPunchActionAt = now
	gui:SetAttribute("PunchActionCooldownBlocked", false)
	gui:SetAttribute("LastPunchActionAt", now)
	performPunchAnimation()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if clientSettings.motion and humanoid then
		gui:SetAttribute("PunchCameraBaseOffset", humanoid.CameraOffset)
		gui:SetAttribute("PunchCameraFollowEnabled", true)
		gui:SetAttribute("PunchCameraFollowDelaySeconds", 0.24)
		gui:SetAttribute("PunchCameraFollowPeakStuds", 0.36)
		gui:SetAttribute("PunchCameraFollowActive", true)
		gui:SetAttribute("LastPunchCameraFollowAt", now)
	else
		gui:SetAttribute("PunchCameraFollowEnabled", false)
		gui:SetAttribute("PunchCameraFollowActive", false)
	end
	actionRemote:FireServer("Punch")
	return true
end

RunService.PreSimulation:Connect(function()
	local state = punchMotionState
	if not state then return end
	local elapsed = os.clock() - state.startedAt
	local progress = math.clamp(elapsed / state.duration, 0, 1)
	local rightWindup = CFrame.new(0.12, 0.08, 0.18) * CFrame.Angles(math.rad(34), math.rad(58), math.rad(30))
	local rightStrike = CFrame.new(0.08, 0.02, -1.35) * CFrame.Angles(math.rad(-104), math.rad(-12), math.rad(-8))
	local leftWindup = CFrame.new(-0.05, 0.02, -0.06) * CFrame.Angles(math.rad(-52), math.rad(-18), math.rad(-24))
	local leftStrike = CFrame.new(0, 0, -0.16) * CFrame.Angles(math.rad(-72), math.rad(18), math.rad(-28))
	local waistWindup = CFrame.new(0, -0.03, 0.08) * CFrame.Angles(math.rad(-7), math.rad(-38), math.rad(-7))
	local waistStrike = CFrame.new(0, -0.08, -0.42) * CFrame.Angles(math.rad(14), math.rad(38), math.rad(9))
	local neckWindup = CFrame.Angles(math.rad(4), math.rad(17), math.rad(3))
	local neckStrike = CFrame.Angles(math.rad(-8), math.rad(-16), math.rad(-4))
	if state.rightShoulder.Parent then state.rightShoulder.Transform = punchPose(rightWindup, rightStrike, progress) end
	if state.leftShoulder and state.leftShoulder.Parent then state.leftShoulder.Transform = punchPose(leftWindup, leftStrike, progress) end
	if state.waist and state.waist.Parent then state.waist.Transform = punchPose(waistWindup, waistStrike, progress) end
	if state.neck and state.neck.Parent then state.neck.Transform = punchPose(neckWindup, neckStrike, progress) end
	gui:SetAttribute("CharacterPunchMotionPeak", math.max(gui:GetAttribute("CharacterPunchMotionPeak") or 0, math.sin(progress * math.pi)))
	if progress >= 1 then
		if state.rightShoulder and state.rightShoulder.Parent then state.rightShoulder.Transform = CFrame.new() end
		if state.leftShoulder and state.leftShoulder.Parent then state.leftShoulder.Transform = CFrame.new() end
		if state.waist and state.waist.Parent then state.waist.Transform = CFrame.new() end
		if state.neck and state.neck.Parent then state.neck.Transform = CFrame.new() end
		punchMotionState = nil
		gui:SetAttribute("CharacterPunchMotionActive", false)
	end
end)

RunService.RenderStepped:Connect(function()
	if gui:GetAttribute("PunchCameraFollowActive") ~= true then return end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	local elapsed = os.clock() - (gui:GetAttribute("LastPunchCameraFollowAt") or os.clock())
	local delay = gui:GetAttribute("PunchCameraFollowDelaySeconds") or 0.24
	local baseOffset = gui:GetAttribute("PunchCameraBaseOffset") or Vector3.zero
	if elapsed < delay then
		humanoid.CameraOffset = baseOffset
		return
	end
	local progress = math.clamp((elapsed - delay) / 0.58, 0, 1)
	local eased = math.sin(progress * math.pi)
	local peakOffset = Vector3.new(0, 0, gui:GetAttribute("PunchCameraFollowPeakStuds") or 0.36)
	humanoid.CameraOffset = baseOffset + peakOffset * eased
	if progress >= 1 then
		humanoid.CameraOffset = baseOffset
		gui:SetAttribute("PunchCameraFollowActive", false)
	end
end)

if RunService:IsStudio() then
	local automation = gui:FindFirstChild("PunchWallClientAutomation")
	if automation then
		automation.OnInvoke = function(action)
			if action == "Punch" then return tryPunchAction() end
			requestAction(action)
			return true
		end
	end
end

player.CharacterAdded:Connect(function()
	punchMotionState = nil
	visualSignature = ""
	task.delay(1, refreshCharacterVisuals)
end)

task.defer(function()
	requestAction("RequestSync")
	task.wait(0.2)
	refreshCharacterVisuals()
end)

RunService.RenderStepped:Connect(function()
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end
	local now = os.clock()
	for index, model in ipairs(companionModels) do
		if model.PrimaryPart then
			local side = index % 2 == 0 and 1 or -1
			local row = math.floor((index - 1) / 2)
			local offset = CFrame.new(side * (2.5 + row * 0.8), 0.95 + math.sin(now * 3 + index) * 0.22, 2.8 + row * 1.2)
			model:PivotTo(rootPart.CFrame * offset * CFrame.Angles(0, math.rad(180), 0))
		end
	end
end)

local ambientPulseParts = {}
task.spawn(function()
	while gui.Parent do
		table.clear(ambientPulseParts)
		local root = workspace:FindFirstChild("PunchWallRPG")
		if root then
			for _, descendant in ipairs(root:GetDescendants()) do
				if descendant:IsA("BasePart") and descendant:GetAttribute("AmbientMotion") == "Pulse" then
					table.insert(ambientPulseParts, descendant)
				end
			end
		end
		gui:SetAttribute("AmbientPulseCount", #ambientPulseParts)
		task.wait(2)
	end
end)

local ambientPhase = 0
local lastAmbientActive
RunService.RenderStepped:Connect(function(deltaTime)
	ambientPhase += deltaTime
	local active = clientSettings.motion and #ambientPulseParts > 0
	if active ~= lastAmbientActive then
		lastAmbientActive = active
		gui:SetAttribute("AmbientMotionActive", active)
	end
	for index, part in ipairs(ambientPulseParts) do
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
tutorialWaypoint.MaxDistance = 500
tutorialWaypoint.Size = UDim2.fromOffset(190, 52)
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
tutorialWaypointLabel.TextSize = 15
tutorialWaypointLabel.TextWrapped = true
tutorialWaypointLabel.Parent = tutorialWaypoint

local tutorialWaypointCorner = Instance.new("UICorner")
tutorialWaypointCorner.CornerRadius = UDim.new(0, 7)
tutorialWaypointCorner.Parent = tutorialWaypointLabel

local tutorialWaypointStroke = Instance.new("UIStroke")
tutorialWaypointStroke.Color = Color3.fromRGB(255, 244, 166)
tutorialWaypointStroke.Thickness = 2
tutorialWaypointStroke.Parent = tutorialWaypointLabel
local targetTimer = 0
RunService.Heartbeat:Connect(function(delta)
	targetTimer += delta
	if targetTimer < 0.15 then return end
	targetTimer = 0
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local gameRoot = workspace:FindFirstChild("PunchWallRPG")
	if not rootPart or not gameRoot then return end
	local nearest
	local nearestDistance = 44
	local nearestWall
	local nearestWallDistance = 50
	for _, folderName in ipairs({ "Walls", "Interactables" }) do
		local folder = gameRoot:FindFirstChild(folderName)
		if folder then
			for _, candidate in ipairs(folder:GetChildren()) do
				if candidate:IsA("BasePart") then
					local distance = (candidate.Position - rootPart.Position).Magnitude
					if distance < nearestDistance then nearest, nearestDistance = candidate, distance end
					if folderName == "Walls" and distance < nearestWallDistance then nearestWall, nearestWallDistance = candidate, distance end
				end
			end
		end
	end
	local depthBlocks = gameRoot:FindFirstChild("Depth Blocks")
	if depthBlocks then
		local overlap = OverlapParams.new()
		overlap.FilterType = Enum.RaycastFilterType.Include
		overlap.FilterDescendantsInstances = { depthBlocks }
		overlap.MaxParts = 400
		for _, block in ipairs(workspace:GetPartBoundsInRadius(rootPart.Position, 38, overlap)) do
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
		local walls = gameRoot:FindFirstChild("Walls")
		local interactables = gameRoot:FindFirstChild("Interactables")
		tutorialTarget = (walls and walls:FindFirstChild(tutorial.target)) or (interactables and interactables:FindFirstChild(tutorial.target))
	end
	if tutorialTarget and tutorialTarget:IsA("BasePart") then
		local distance = math.floor((tutorialTarget.Position - rootPart.Position).Magnitude + 0.5)
		tutorialWaypoint.Adornee = tutorialTarget
		tutorialWaypoint.Enabled = true
		tutorialWaypointLabel.Text = ("NEXT: %s\n%d studs"):format(string.upper(tostring(tutorial.title or tutorial.target)), distance)
		help.Text = tutorialObjectiveText .. ("  |  %d studs"):format(distance)
	else
		tutorialWaypoint.Adornee = nil
		tutorialWaypoint.Enabled = false
		help.Text = tutorialObjectiveText
	end
	local tutorialStep = latestStats.TutorialStep or 1
	local isTutorialAction = tutorial and nearest and nearest.Name == tutorial.target
	local nearbyAction = not focusedWall and nearest and nearestDistance <= 12 and (tutorialStep > 1 or isTutorialAction)
	trainButton.Visible = nearbyAction and (nearest.Name == "Power Bag" or nearest.Name == "Speed Dummy" or nearest.Name == "Focus Stone")
	useButton.Visible = nearbyAction and not trainButton.Visible
	contextLabel.Visible = nearbyAction and not mainPanel.Visible
	if nearbyAction then
		contextLabel.Text = nearest.Name
	end
	targetHUD.Visible = false
end)

gui:SetAttribute("CombatCameraActive", false)
if workspace.CurrentCamera and workspace.CurrentCamera.CameraType == Enum.CameraType.Scriptable then
	workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
end
local cameraOcclusionApplied = player.DevCameraOcclusionMode == Enum.DevCameraOcclusionMode.Invisicam
gui:SetAttribute("CameraOcclusionMode", cameraOcclusionApplied and "Invisicam" or "Unavailable")
gui:SetAttribute("PreservePlayerZoomInTunnels", cameraOcclusionApplied)

local bossHudTimer = 0
RunService.Heartbeat:Connect(function(delta)
	bossHudTimer += delta
	if bossHudTimer < 0.2 then return end
	bossHudTimer = 0
	local gameRoot = workspace:FindFirstChild("PunchWallRPG")
	local walls = gameRoot and gameRoot:FindFirstChild("Walls")
	local boss = walls and walls:FindFirstChild("Titan Server Wall")
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not boss or not rootPart then bossHUD.Visible = false help.Visible = not mainPanel.Visible return end
	local hp = boss:GetAttribute("HP") or 0
	local maxHP = math.max(1, boss:GetAttribute("MaxHP") or 1)
	local broken = boss:GetAttribute("Broken") == true
	local nearby = (boss.Position - rootPart.Position).Magnitude <= 55
	bossHUD.Visible = (broken or nearby or hp < maxHP) and not targetHUD.Visible and not mainPanel.Visible
	help.Visible = not mainPanel.Visible
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
local referenceHUD = Instance.new("Frame")
referenceHUD.Name = "PixelPerfectHeroCityHUD"
referenceHUD.BackgroundTransparency = 1
referenceHUD.Size = UDim2.fromScale(1, 1)
referenceHUD.ZIndex = 30
referenceHUD.Parent = gui

local function designRect(x, y, width, height)
	return UDim2.fromScale(x / 1672, y / 941), UDim2.fromScale(width / 1672, height / 941)
end

local rankWidgets = {}
do
	local rankHUD = Instance.new("Frame")
	rankHUD.Name = "DepthRankHUD"
	rankHUD.Position, rankHUD.Size = designRect(108, 132, 290, 156)
	rankHUD.BackgroundColor3 = Color3.fromRGB(8, 15, 20)
	rankHUD.BackgroundTransparency = 0.04
	rankHUD.BorderSizePixel = 0
	rankHUD.ZIndex = 34
	rankHUD.Parent = referenceHUD
	local rankCorner = Instance.new("UICorner")
	rankCorner.CornerRadius = UDim.new(0, 5)
	rankCorner.Parent = rankHUD
	local rankStroke = Instance.new("UIStroke")
	rankStroke.Color = Color3.fromRGB(36, 194, 241)
	rankStroke.Thickness = 2
	rankStroke.Transparency = 0.08
	rankStroke.Parent = rankHUD
	local rankAccent = Instance.new("Frame")
	rankAccent.Name = "RankAccent"
	rankAccent.Size = UDim2.new(0, 7, 1, 0)
	rankAccent.BackgroundColor3 = Color3.fromRGB(228, 46, 37)
	rankAccent.BorderSizePixel = 0
	rankAccent.ZIndex = 35
	rankAccent.Parent = rankHUD

	local function rankText(name, y, height, size, color)
		local label = Instance.new("TextLabel")
		label.Name = name
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromOffset(17, y)
		label.Size = UDim2.new(1, -25, 0, height)
		label.Font = Enum.Font.GothamBold
		label.Text = ""
		label.TextColor3 = color
		label.TextSize = size
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextTruncate = Enum.TextTruncate.AtEnd
		label.ZIndex = 35
		label.Parent = rankHUD
		return label
	end

	rankWidgets.Title = rankText("RankTitle", 8, 25, 18, Color3.fromRGB(255, 211, 64))
	rankWidgets.Stats = rankText("RankStats", 34, 22, 15, Color3.fromRGB(237, 242, 244))
	local leaderboardTitle = rankText("LeaderboardTitle", 59, 18, 12, Color3.fromRGB(43, 199, 244))
	leaderboardTitle.Text = "SERVER TOP 3"
	rankWidgets.Lines = {
		rankText("Leaderboard1", 78, 21, 12, Color3.fromRGB(255, 224, 98)),
		rankText("Leaderboard2", 99, 21, 12, Color3.fromRGB(220, 227, 232)),
		rankText("Leaderboard3", 120, 21, 12, Color3.fromRGB(198, 142, 86)),
	}
end

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

local pixel = GameConfig.HeroCityPixelUI
local referencePowerCard = referenceImage("PowerCard", pixel.Power, 415, 23, 279, 103)
local referenceCoinsCard = referenceImage("CoinsCard", pixel.Coins, 702, 22, 330, 104)
local referenceWallCard = referenceImage("WallCard", pixel.Wall, 1041, 23, 252, 103)
referenceImage("QuestCard", pixel.QuestCard, 1368, 117, 294, 134)
referenceImage("NextWorldCard", pixel.NextWorld, 1020, 778, 194, 145)
local referenceJoystick = referenceImage("MovementJoystick", pixel.Joystick, 57, 640, 270, 270)
referenceJoystick.Active = true
referenceImage("SoundTool", pixel.SoundTool, 1465, 22, 60, 64)
referenceButton("SettingsTool", pixel.SettingsTool, 1526, 22, 60, 64, function() openGameTab("Settings") end)
referenceImage("MoreTool", pixel.MoreTool, 1587, 22, 64, 64)

if RunService:IsStudio() then
	local studioTestButton = Instance.new("TextButton")
	studioTestButton.Name = "StudioTestModeButton"
	studioTestButton.BackgroundColor3 = Color3.fromRGB(122, 30, 20)
	studioTestButton.BorderSizePixel = 0
	studioTestButton.Font = Enum.Font.GothamBlack
	studioTestButton.Text = latestStats.StudioTestMode and "RESTORE" or "TEST POWER"
	studioTestButton.TextColor3 = Color3.fromRGB(255, 239, 190)
	studioTestButton.TextSize = 14
	studioTestButton.Position, studioTestButton.Size = designRect(1304, 27, 150, 52)
	studioTestButton.ZIndex = 35
	studioTestButton.Parent = referenceHUD
	local studioTestCorner = Instance.new("UICorner")
	studioTestCorner.CornerRadius = UDim.new(0, 5)
	studioTestCorner.Parent = studioTestButton
	local studioTestStroke = Instance.new("UIStroke")
	studioTestStroke.Color = Color3.fromRGB(255, 182, 53)
	studioTestStroke.Thickness = 2
	studioTestStroke.Parent = studioTestButton
	studioTestButton.Activated:Connect(function()
		actionRemote:FireServer({ action = "ToggleStudioHighPowerTest", value = not (latestStats.StudioTestMode == true) })
	end)
	statRemote.OnClientEvent:Connect(function(payload)
		if typeof(payload) == "table" then
			studioTestButton.Text = payload.StudioTestMode and "RESTORE" or "TEST POWER"
			studioTestButton.BackgroundColor3 = payload.StudioTestMode and Color3.fromRGB(31, 91, 52) or Color3.fromRGB(122, 30, 20)
		end
	end)
end

referenceButton("DailyButton", pixel.Daily, 16, 201, 82, 111, function() openGameTab("Tasks") end)
referenceButton("SpinButton", pixel.Spin, 16, 316, 82, 111, function() requestAction("Spin") end)
referenceButton("RebirthButton", pixel.Rebirth, 16, 429, 82, 111, function() openGameTab("Tasks") end)
referenceButton("ShopButton", pixel.Shop, 1570, 296, 87, 111, function() openGameTab("Fists") end)
referenceButton("PetsButton", pixel.Pets, 1570, 410, 87, 104, function() openGameTab("Pets") end)
referenceButton("QuestsButton", pixel.Quests, 1570, 515, 87, 103, function() openGameTab("Tasks") end)

local referencePunch = referenceButton("ActionPunch", pixel.Punch, 1211, 669, 250, 250)
referencePunch.MouseButton1Down:Connect(function() setPunchHeld(true) end)
referencePunch.MouseButton1Up:Connect(function() setPunchHeld(false) end)
referencePunch.MouseLeave:Connect(function() setPunchHeld(false) end)
local referenceJump = referenceButton("ActionJump", pixel.Jump, 1460, 694, 211, 211, function()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid.Jump = true end
end)

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
	sizeLimit.MinTextSize = 12
	sizeLimit.MaxTextSize = maxTextSize or 30
	sizeLimit.Parent = value
	return value
end

dynamicMask("Power", 98, 39, 101, 50, referencePowerCard, 279, 103)
dynamicMask("Coins", 96, 39, 132, 51, referenceCoinsCard, 330, 104)
dynamicMask("Wall", 147, 39, 52, 51, referenceWallCard, 252, 103)
local referencePowerValue = dynamicValue("PowerValue", 103, 41, 78, 44, Color3.fromRGB(244, 244, 239), referencePowerCard, 279, 103, 30)
local referenceCoinsValue = dynamicValue("CoinsValue", 101, 42, 104, 44, Color3.fromRGB(244, 244, 239), referenceCoinsCard, 330, 104, 30)
local referenceWallValue = dynamicValue("WallValue", 151, 42, 38, 44, Color3.fromRGB(39, 199, 247), referenceWallCard, 252, 103, 30)

-- Functional shop: the old single atlas was visual-only. This panel is assembled
-- from the supplied transparent art and every button makes a server-validated request.
local shopReference = Instance.new("Frame")
shopReference.Name = "FunctionalHeroShop"
shopReference.BackgroundColor3 = Color3.fromRGB(7, 13, 18)
shopReference.BackgroundTransparency = 0.02
shopReference.BorderSizePixel = 0
shopReference.Size = UDim2.fromScale(1, 1)
shopReference.ZIndex = 100
shopReference.Visible = false
shopReference.Parent = mainPanel
local shopCorner = Instance.new("UICorner")
shopCorner.CornerRadius = UDim.new(0, 8)
shopCorner.Parent = shopReference
local shopStroke = Instance.new("UIStroke")
shopStroke.Color = Color3.fromRGB(45, 181, 237)
shopStroke.Thickness = 2
shopStroke.Parent = shopReference

shared.PunchWallHeroShopPage = "Fists"
shared.PunchWallHeroShopRefresh = function()
	for _, child in ipairs(shopReference:GetChildren()) do
		if child ~= shopCorner and child ~= shopStroke then child:Destroy() end
	end
	local function label(parent, name, text, position, size, color, textSize, font)
		local value = Instance.new("TextLabel")
		value.Name = name
		value.BackgroundTransparency = 1
		value.Position = position
		value.Size = size
		value.Font = font or Enum.Font.GothamBold
		value.Text = text
		value.TextColor3 = color
		value.TextSize = textSize
		value.TextXAlignment = Enum.TextXAlignment.Left
		value.TextYAlignment = Enum.TextYAlignment.Center
		value.TextTruncate = Enum.TextTruncate.AtEnd
		value.ZIndex = 103
		value.Parent = parent
		return value
	end
	local header = Instance.new("Frame")
	header.Name = "ShopHeader"
	header.BackgroundColor3 = Color3.fromRGB(42, 8, 11)
	header.BorderSizePixel = 0
	header.Position = UDim2.fromScale(0.02, 0.02)
	header.Size = UDim2.fromScale(0.96, 0.12)
	header.ZIndex = 101
	header.Parent = shopReference
	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = UDim.new(0, 6)
	headerCorner.Parent = header
	local headerGradient = Instance.new("UIGradient")
	headerGradient.Color = ColorSequence.new(Color3.fromRGB(142, 20, 20), Color3.fromRGB(5, 38, 75))
	headerGradient.Parent = header
	label(header, "Title", "HERO FIST SHOP", UDim2.fromScale(0.04, 0), UDim2.fromScale(0.58, 1), Color3.fromRGB(255, 247, 230), 24, Enum.Font.GothamBlack)
	local close = Instance.new("TextButton")
	close.Name = "CloseShop"
	close.BackgroundColor3 = Color3.fromRGB(160, 30, 26)
	close.BorderSizePixel = 0
	close.AnchorPoint = Vector2.new(1, 0.5)
	close.Position = UDim2.fromScale(0.97, 0.5)
	close.Size = UDim2.fromScale(0.12, 0.7)
	close.Font = Enum.Font.GothamBlack
	close.Text = "X"
	close.TextColor3 = Color3.new(1, 1, 1)
	close.TextSize = 22
	close.ZIndex = 104
	close.Parent = header
	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 5)
	closeCorner.Parent = close
	close.Activated:Connect(function() setMenuVisible(false) end)
	local owned = decodeJSON(latestStats.OwnedFistsJSON, { "Starter Glove" })
	local page = shared.PunchWallHeroShopPage == "Boosts" and "Boosts" or "Fists"
	for index, pageName in ipairs({ "Fists", "Boosts" }) do
		local tab = Instance.new("TextButton")
		tab.Name = pageName .. "ShopTab"
		tab.BackgroundColor3 = page == pageName and Color3.fromRGB(20, 125, 201) or Color3.fromRGB(31, 42, 50)
		tab.BorderSizePixel = 0
		tab.Position = UDim2.fromScale(0.03 + (index - 1) * 0.15, 0.15)
		tab.Size = UDim2.fromScale(0.135, 0.06)
		tab.Font = Enum.Font.GothamBlack
		tab.Text = string.upper(pageName)
		tab.TextColor3 = Color3.new(1, 1, 1)
		tab.TextSize = 12
		tab.ZIndex = 103
		tab.Parent = shopReference
		local tabCorner = Instance.new("UICorner")
		tabCorner.CornerRadius = UDim.new(0, 4)
		tabCorner.Parent = tab
		tab.Activated:Connect(function()
			shared.PunchWallHeroShopPage = pageName
			shared.PunchWallHeroShopRefresh()
		end)
	end
	local boostInfo = latestStats.ShopBoosts or {}
	local now = workspace:GetServerTimeNow()
	local products = {}
	if page == "Fists" then
		for _, item in ipairs(GameConfig.Fists) do table.insert(products, item) end
	else
		products = {
			{ name = "CoinBoost", displayName = "COIN BOOST x2", rarity = "EPIC", cost = 5000, art = GameConfig.ShopArt.CoinBoost, accent = Color3.fromRGB(202, 71, 230), detail = "Earn 2x coins for 15 minutes.", endsAt = boostInfo.CoinEndsAt or 0 },
			{ name = "SpeedBoost", displayName = "SPEED BOOST", rarity = "RARE", cost = 8000, art = GameConfig.ShopArt.SpeedBoost, accent = Color3.fromRGB(58, 201, 248), detail = "Move faster for 15 minutes.", endsAt = boostInfo.SpeedEndsAt or 0 },
			{ name = "DamageBoost", displayName = "DAMAGE BOOST", rarity = "EPIC", cost = 12000, art = GameConfig.ShopArt.DamageBoost, accent = Color3.fromRGB(239, 112, 51), detail = "Deal 2x damage for 15 minutes.", endsAt = boostInfo.DamageEndsAt or 0 },
		}
	end
	for index, item in ipairs(products) do
		local column = (index - 1) % 2
		local row = math.floor((index - 1) / 2)
		local card = Instance.new("Frame")
		card.Name = item.name .. "ShopCard"
		card.BackgroundColor3 = Color3.fromRGB(14, 24, 31)
		card.BorderSizePixel = 0
		card.Position = UDim2.fromScale(0.03 + column * 0.48, 0.23 + row * 0.245)
		card.Size = UDim2.fromScale(0.46, 0.22)
		card.ZIndex = 101
		card.Parent = shopReference
		local cardCorner = Instance.new("UICorner")
		cardCorner.CornerRadius = UDim.new(0, 6)
		cardCorner.Parent = card
		local cardStroke = Instance.new("UIStroke")
		cardStroke.Color = item.accent
		cardStroke.Thickness = latestStats.EquippedFist == item.name and 3 or 1.5
		cardStroke.Parent = card
		local art = item.art or (item.tier == 1 and GameConfig.ShopArt.StarterGlove or item.tier >= 5 and GameConfig.ShopArt.TitanGlove or GameConfig.ShopArt.ChampionGlove)
		local icon = Instance.new("ImageLabel")
		icon.Name = "ProductArt"
		icon.BackgroundTransparency = 1
		icon.Image = art
		icon.ScaleType = Enum.ScaleType.Fit
		icon.Position = UDim2.fromScale(0.02, 0.06)
		icon.Size = UDim2.fromScale(0.29, 0.82)
		icon.ZIndex = 102
		icon.Parent = card
		local fallbackName = page == "Fists" and item.icon or (item.name == "CoinBoost" and "Coin" or item.name == "SpeedBoost" and "Train" or "Punch")
		local fallback = createThemeIcon(card, fallbackName, icon.Position, icon.Size, "ProductArtFallback")
		fallback.ZIndex = 101
		local function updateArtFallback()
			fallback.Visible = not icon.IsLoaded
		end
		icon:GetPropertyChangedSignal("IsLoaded"):Connect(updateArtFallback)
		updateArtFallback()
		local rarity = item.rarity or (item.tier == 1 and "COMMON" or item.tier >= 5 and "LEGENDARY" or item.tier >= 4 and "EPIC" or "RARE")
		label(card, "Name", string.upper(item.displayName), UDim2.fromScale(0.33, 0.08), UDim2.fromScale(0.62, 0.22), Color3.fromRGB(248, 249, 246), 14, Enum.Font.GothamBlack)
		label(card, "Rarity", rarity, UDim2.fromScale(0.33, 0.29), UDim2.fromScale(0.62, 0.16), item.accent, 10, Enum.Font.GothamBlack)
		label(card, "Detail", item.detail or ("x%.1f power  |  +%.1f speed"):format(item.mult, item.speed), UDim2.fromScale(0.33, 0.45), UDim2.fromScale(0.34, 0.20), Color3.fromRGB(206, 216, 222), 10, Enum.Font.Gotham)
		label(card, "Price", formatNumber(item.cost) .. " COINS", UDim2.fromScale(0.33, 0.68), UDim2.fromScale(0.34, 0.22), Color3.fromRGB(255, 202, 56), 11, Enum.Font.GothamBlack)
		local action = Instance.new("TextButton")
		action.Name = item.name .. "Action"
		action.BackgroundColor3 = Color3.fromRGB(238, 164, 26)
		action.BorderSizePixel = 0
		action.AnchorPoint = Vector2.new(1, 1)
		action.Position = UDim2.fromScale(0.96, 0.95)
		action.Size = UDim2.fromScale(0.29, 0.55)
		action.Font = Enum.Font.GothamBlack
		action.TextColor3 = Color3.fromRGB(255, 255, 255)
		action.TextSize = 11
		action.ZIndex = 104
		action.Parent = card
		local actionCorner = Instance.new("UICorner")
		actionCorner.CornerRadius = UDim.new(0, 5)
		actionCorner.Parent = action
		if page == "Fists" then
			local equipped = latestStats.EquippedFist == item.name
			local isOwned = table.find(owned, item.name) ~= nil
			action.Text = equipped and "EQUIPPED" or isOwned and "EQUIP" or "BUY"
			action.BackgroundColor3 = equipped and Color3.fromRGB(47, 150, 65) or Color3.fromRGB(238, 164, 26)
			action.Active = not equipped
			action.Activated:Connect(function()
				if not equipped then actionRemote:FireServer({ action = isOwned and "EquipFist" or "BuyFist", target = item.name }) end
			end)
		else
			local seconds = math.max(0, math.floor((item.endsAt or 0) - now))
			action.Text = seconds > 0 and ("ACTIVE %02d:%02d"):format(math.floor(seconds / 60), seconds % 60) or "BUY"
			action.BackgroundColor3 = seconds > 0 and Color3.fromRGB(47, 150, 65) or Color3.fromRGB(238, 164, 26)
			action.Activated:Connect(function() actionRemote:FireServer({ action = "BuyShopBoost", target = item.name }) end)
		end
	end
	local footer = label(shopReference, "Refresh", "SHOP REFRESHES DAILY  |  ALL PURCHASES ARE SERVER-VALIDATED", UDim2.fromScale(0.03, 0.94), UDim2.fromScale(0.94, 0.04), Color3.fromRGB(170, 190, 199), 9, Enum.Font.GothamBold)
	footer.TextXAlignment = Enum.TextXAlignment.Center
end
shared.PunchWallHeroShopRefresh()

local joystickTouch
local joystickVector = Vector2.zero
local function updateJoystick(input)
	local center = referenceJoystick.AbsolutePosition + referenceJoystick.AbsoluteSize * 0.5
	local radius = math.max(1, math.min(referenceJoystick.AbsoluteSize.X, referenceJoystick.AbsoluteSize.Y) * 0.36)
	local delta = Vector2.new(input.Position.X, input.Position.Y) - center
	joystickVector = delta.Magnitude > radius and delta.Unit or delta / radius
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
		joystickVector = Vector2.zero
	end
end)

statRemote.OnClientEvent:Connect(function(payload)
	referencePowerValue.Text = formatNumber(payload.Power or 0)
	referenceCoinsValue.Text = formatNumber(payload.Coins or 0)
	referenceWallValue.Text = formatNumber(payload.WallLevel or 1)
	rankWidgets.Title.Text = ("#%d  %s"):format(tonumber(payload.RankPosition) or 1, tostring(payload.Rank or "ROOKIE"))
	rankWidgets.Stats.Text = ("DEPTH %d  |  SCORE %s"):format(tonumber(payload.Depth) or 0, formatNumber(payload.Score or 0))
	for index, label in ipairs(rankWidgets.Lines) do
		local entry = type(payload.Leaderboard) == "table" and payload.Leaderboard[index] or nil
		label.Text = entry and ("%d. %s  D%d  %s"):format(index, tostring(entry.name), tonumber(entry.depth) or 0, formatNumber(entry.score or 0)) or ("%d. ---"):format(index)
	end
	if shared.PunchWallHeroShopRefresh then shared.PunchWallHeroShopRefresh() end
end)

mainPanel:GetPropertyChangedSignal("Visible"):Connect(function()
	referenceHUD.Visible = not mainPanel.Visible
	shopReference.Visible = mainPanel.Visible and activeTab == "Fists"
end)

RunService.RenderStepped:Connect(function()
	statusDeck.Visible = false
	leftDock.Visible = false
	rightDock.Visible = false
	nextWorld.Visible = false
	help.Visible = false
	mobileControls.Visible = false
	bossHUD.Visible = false
	contextLabel.Visible = false
	referenceHUD.Visible = not mainPanel.Visible
	shopReference.Visible = mainPanel.Visible and activeTab == "Fists"
	mainPanel.BackgroundTransparency = shopReference.Visible and 1 or 0.03
	local touchGui = player.PlayerGui:FindFirstChild("TouchGui")
	if touchGui and touchGui:IsA("ScreenGui") then
		touchGui.Enabled = true
		local touchControlFrame = touchGui:FindFirstChild("TouchControlFrame")
		if touchControlFrame then touchControlFrame.Visible = false end
	end
	if joystickVector.Magnitude > 0 then
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then humanoid:Move(Vector3.new(joystickVector.X, 0, joystickVector.Y), true) end
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
	if state == Enum.UserInputState.Begin then toggleMenu() end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.B, Enum.KeyCode.ButtonSelect)

local function applyResponsiveLayout()
	local camera = workspace.CurrentCamera
	if not camera then return end
	local viewport = camera.ViewportSize
	local compact = UserInputService.TouchEnabled or viewport.Y < 520
	local userScale = math.clamp(tonumber(clientSettings.uiScale) or 1, 0.8, 1.2)
	if compact then
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
		menuButton.Position = UDim2.new(0.5, 0, 0, 8)
		menuButton.Size = UDim2.fromOffset(78, 44)
		local shopHeight = math.max(210, math.min(viewport.Y - 16, (viewport.X - 24) * 408 / 677))
		mainPanel.AnchorPoint = Vector2.new(0.5, 0.5)
		mainPanel.Size = UDim2.fromOffset(shopHeight * 677 / 408, shopHeight)
		mainPanel.Position = UDim2.fromScale(0.5, 0.5)
		toastHolder.Position = UDim2.new(0.23, 0, 0, 60)
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
		menuButton.Position = UDim2.new(1, -18, 0, 18)
		menuButton.Size = UDim2.fromOffset(92, 42)
		mainPanel.AnchorPoint = Vector2.new(0.5, 0.5)
		mainPanel.Size = UDim2.fromOffset(677, 408)
		mainPanel.Position = UDim2.fromScale(0.5, 0.52)
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
	panel.Visible = false
	menuButton.Visible = false
	mobileControls.Visible = not mainPanel.Visible
	contextLabel.Visible = false
end

if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(applyResponsiveLayout)
end
task.defer(function()
	applyResponsiveLayout()
	actionRemote:FireServer({ action = "RequestSync" })
end)
