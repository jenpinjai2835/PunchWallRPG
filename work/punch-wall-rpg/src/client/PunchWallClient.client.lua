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
local FistVisualBuilder = require(ReplicatedStorage:WaitForChild("FistVisualBuilder"))
FistVisualBuilder.Ensure()
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
local applyResponsiveLayout = function() end
local gui

local function requestAction(action)
	actionRemote:FireServer(action)
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

shared.PunchWallSetModalCoreGuiHidden = function(hidden)
	pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, not hidden) end)
	pcall(function() StarterGui:SetCore("TopbarEnabled", not hidden) end)
	if gui then gui:SetAttribute("ModalCoreGuiHidden", hidden == true) end
end
shared.PunchWallUpdateTierAtmosphere = function(depth)
	local lighting = game:GetService("Lighting")
	local normalizedDepth = math.max(0, tonumber(depth) or 0)
	local tier = math.clamp(math.floor(math.max(0, normalizedDepth - 1) / 8) + 1, 1, 10)
	local colors = {
		Color3.fromRGB(225, 246, 226), Color3.fromRGB(231, 239, 242),
		Color3.fromRGB(211, 226, 239), Color3.fromRGB(201, 242, 249),
		Color3.fromRGB(255, 222, 207), Color3.fromRGB(203, 234, 250),
		Color3.fromRGB(224, 226, 239), Color3.fromRGB(255, 207, 188),
		Color3.fromRGB(216, 211, 251), Color3.fromRGB(195, 228, 249),
	}
	local colorEffect = lighting:FindFirstChild("Hero City Color")
	if colorEffect and colorEffect:IsA("ColorCorrectionEffect") then
		TweenService:Create(colorEffect, TweenInfo.new(0.8), {
			TintColor = colors[tier],
			Saturation = 0.12 + math.min(tier, 6) * 0.012,
		}):Play()
	end
	local atmosphere = lighting:FindFirstChild("Hero City Atmosphere")
	if atmosphere and atmosphere:IsA("Atmosphere") then
		TweenService:Create(atmosphere, TweenInfo.new(0.8), { Color = colors[tier] }):Play()
	end
	backgroundMusic.PlaybackSpeed = 1 + (tier - 1) * 0.012
	backgroundMusic.Volume = clientSettings.sound and ((GameConfig.Audio.MusicVolume or 0.22) + math.min(tier - 1, 5) * 0.008) or 0
	local gameRoot = workspace:FindFirstChild("PunchWallRPG")
	local landmarks = gameRoot and gameRoot:FindFirstChild("Depth Tier Landmarks")
	local activeLandmarks = 0
	if landmarks then
		for _, landmark in ipairs(landmarks:GetChildren()) do
			local active = landmark:GetAttribute("MaterialTier") == tier
			landmark:SetAttribute("ClientActiveTier", active)
			if active then activeLandmarks += 1 end
			for _, descendant in ipairs(landmark:GetDescendants()) do
				if descendant:IsA("ParticleEmitter") and descendant.Name == "TierParticles" then
					descendant.Enabled = active and clientSettings.motion
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
	gui:SetAttribute("TierMusicVariant", tier)
	gui:SetAttribute("TierAtmosphereApplied", true)
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
	elseif payload.type == "PetFusion" then
		return tostring(payload.message or ("Fused " .. tostring(payload.target or "Sidekick")))
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

local function showFeedback(payload)
	if typeof(payload) ~= "table" then
		return
	end
	if payload.type == "OpenMenu" then
		task.defer(function() openGameTab(tostring(payload.tab or payload.target or "Fists")) end)
		return
	elseif payload.type == "SpinResult" and shared.PunchWallShowSpinResult then
		shared.PunchWallShowSpinResult(payload)
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
		elseif payload.type == "SpinResult" or payload.type == "Honor" or payload.type == "HonorShop" or payload.type == "Pet" or payload.type == "PetFusion"
			or payload.type == "PremiumPurchase" or payload.type == "OfflineTraining" or payload.type == "TrainingState"
			or payload.type == "PremiumSetup" then
			shared.PunchWallPlayRewardSound()
			if shared.PunchWallShowToast then
				shared.PunchWallShowToast(feedbackText(payload), payload.color or palette.Reward, feedbackIcon(payload.type))
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
end)

notifyRemote.OnClientEvent:Connect(shared.PunchWallShowToast)
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
closeButton.ZIndex = 10
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

for order, tabName in ipairs({ "Fists", "Pets", "Honor", "Tasks", "Settings" }) do
	local tab = makeMenuCommand(tabBar, tabName .. "Tab", string.upper(tabName), palette.PanelSoft, function()
		activeTab = tabName
		renderOpenPanel()
	end)
	tab.Size = UDim2.fromOffset(108, 44)
	tab.LayoutOrder = order
	tab.TextSize = 11
	tab.TextXAlignment = Enum.TextXAlignment.Right
	local tabPadding = Instance.new("UIPadding")
	tabPadding.PaddingLeft = UDim.new(0, 36)
	tabPadding.PaddingRight = UDim.new(0, 8)
	tabPadding.Parent = tab
	local tabIcon = tabName == "Fists" and "StarterFist"
		or tabName == "Pets" and "Pet"
		or tabName == "Honor" and "Success"
		or tabName == "Tasks" and "Quest"
		or "Settings"
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
		or isHonor and "CLEAR WORLD 1 | CLAIM RELICS"
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
	addSection("PREMIUM HERO FISTS  |  PERMANENT GAME PASSES", palette.Reward)
	for _, item in ipairs(GameConfig.PremiumFists) do
		local isOwned = table.find(ownedPremium, item.name) ~= nil
		local equipped = latestStats.EquippedFist == item.name
		local _, actions = addRow(
			item.displayName,
			("R$ %d  |  Permanent x%.1f Power  |  Tier %d Aura"):format(item.robux, item.mult, item.tier),
			item.accent,
			item.icon
		)
		local button = makeMenuCommand(actions, item.name .. "PremiumAction", equipped and "EQUIPPED" or isOwned and "EQUIP" or ("R$ " .. item.robux), equipped and palette.Reward or item.accent, function()
			if equipped then return end
			actionRemote:FireServer({ action = isOwned and "EquipFist" or "BuyPremiumFist", target = item.name })
		end)
		button.Size = UDim2.fromOffset(112, 44)
		button.Active = not equipped
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
		local _, actions = addRow(pet.name, ("R$ %d  |  Permanent Power +%.0f%%  |  Premium Aura"):format(pet.robux, pet.mult * 100), pet.accent, "Pet")
		local button = makeMenuCommand(actions, pet.name .. "PremiumPet", owned and "EQUIP" or ("R$ " .. pet.robux), pet.accent, function()
			actionRemote:FireServer({ action = "BuyPremiumPet", target = pet.name })
		end)
		button.Size = UDim2.fromOffset(112, 44)
	end
	addSection("INVENTORY", palette.Text)
	local inventory = decodeJSON(latestStats.PetInventoryJSON, {})
	local equipped = decodeJSON(latestStats.EquippedPetsJSON, {})
	local locked = decodeJSON(latestStats.LockedPetsJSON, {})
	local equippedCounts = countNames(equipped)
	local unlockedInventoryCounts = {}
	for slot, token in ipairs(inventory) do
		if table.find(locked, token) == nil and table.find(locked, "slot:" .. slot) == nil then
			unlockedInventoryCounts[token] = (unlockedInventoryCounts[token] or 0) + 1
		end
	end
	for index, petToken in ipairs(inventory) do
		local petName, stars = GameConfig.ParsePetToken(petToken)
		local pet = GameConfig.PetDefinition(petName)
		pet = pet or { rarity = "Unknown", mult = 0, color = palette.MutedText }
		local starText = string.rep("*", stars)
		local multiplier = GameConfig.PetMultiplierForToken(petToken)
		local row, actions, titleLabel, descLabel = addRow(("#%02d  [%s] %s  %s"):format(index, pet.rarity, petName, starText), ("Power +%.0f%%  |  %d Star"):format(multiplier * 100, stars), pet.color)
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
		local equippedNow = (equippedCounts[petToken] or 0) > 0
		if equippedNow then equippedCounts[petToken] -= 1 end
		makeMenuCommand(actions, "Equip" .. index, equippedNow and "UNEQUIP" or "EQUIP", equippedNow and palette.Train or palette.Use, function()
			actionRemote:FireServer({ action = equippedNow and "UnequipPet" or "EquipPet", target = petToken })
		end).Size = UDim2.fromOffset(70, 44)
		local slotToken = "slot:" .. index
		local isLocked = table.find(locked, slotToken) ~= nil or table.find(locked, petToken) ~= nil
		local required = stars < GameConfig.MaxPetStars and GameConfig.PetFusionRequirement(stars) or 0
		local canFuse = required > 0 and (unlockedInventoryCounts[petToken] or 0) >= required and not isLocked
		local fuseButton = makeMenuCommand(actions, "Fuse" .. index, required > 0 and ("FUSE " .. required) or "MAX", canFuse and palette.Reward or palette.PanelSoft, function()
			if canFuse then actionRemote:FireServer({ action = "FusePet", target = petToken }) end
		end)
		fuseButton.Size = UDim2.fromOffset(64, 44)
		fuseButton.Active = canFuse
		makeMenuCommand(actions, "Lock" .. index, isLocked and "UNLOCK" or "LOCK", isLocked and palette.Train or palette.PanelSoft, function()
			actionRemote:FireServer({ action = "LockPet", target = petToken, value = not isLocked, index = index })
		end).Size = UDim2.fromOffset(62, 44)
		makeMenuCommand(actions, "Delete" .. index, "DEL", isLocked and palette.PanelSoft or palette.Fail, function()
			if isLocked then return end
			actionRemote:FireServer({ action = "DeletePet", target = petToken, index = index })
		end).Size = UDim2.fromOffset(54, 44)
	end
	if #inventory == 0 then addSection("No sidekicks yet. Smash depth blocks until a hidden egg drops.", palette.MutedText) end
end

local function renderHonor()
	addSection(("WORLD HONOR  |  %s AVAILABLE"):format(formatNumber(latestStats.Honor or 0)), palette.Reward)
	addRow(
		"HOW TO EARN HONOR",
		("Break the final Depth %d block in World 1. Each world-clear cycle awards %d Honor."):format(GameConfig.WorldProgressTarget, GameConfig.HonorPerWorldClear),
		palette.Use,
		"Wall"
	)
	local owned = decodeJSON(latestStats.OwnedHonorItemsJSON, {})
	for _, item in ipairs(GameConfig.HonorItems) do
		local isOwned = table.find(owned, item.name) ~= nil
		local equipped = latestStats.EquippedHonorItem == item.name
		local _, actions = addRow(
			item.displayName,
			("%d HONOR  |  +%d%% total Power  |  Permanent relic"):format(item.cost, math.floor(item.powerBonus * 100 + 0.5)),
			item.color,
			item.icon or "Success"
		)
		local caption = equipped and "EQUIPPED" or isOwned and "EQUIP" or (item.cost .. " HONOR")
		local button = makeMenuCommand(actions, item.name .. "HonorAction", caption, equipped and palette.Reward or item.color, function()
			if not equipped then actionRemote:FireServer({ action = "BuyHonorItem", target = item.name }) end
		end)
		button.Size = UDim2.fromOffset(118, 44)
		button.Active = not equipped
	end
	addSection("NEXT RELEASE: Honor will also unlock the next world. Your relics and Honor balance are already saved.", palette.MutedText)
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
	local _, rebirthActions = addRow("Hero Rebirth", ("Need Wall Lv 55 + 1M coins  |  Next permanent bonus x%.2f"):format((latestStats.RebirthBonus or 1) + 0.25), Color3.fromRGB(171, 133, 219), "Rebirth")
	makeMenuCommand(rebirthActions, "RebirthNow", "REBIRTH", Color3.fromRGB(142, 88, 203), function()
		actionRemote:FireServer({ action = "Rebirth" })
	end).Size = UDim2.fromOffset(100, 44)
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

renderOpenPanel = function()
	if not mainPanel.Visible then return end
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
	task.defer(applyResponsiveLayout)
end

local function toggleMenu()
	setMenuVisible(not mainPanel.Visible)
end

menuButton.Activated:Connect(toggleMenu)
closeButton.Activated:Connect(function() setMenuVisible(false) end)
mainPanel:GetPropertyChangedSignal("Visible"):Connect(function()
	local visible = mainPanel.Visible
	shared.PunchWallSetModalCoreGuiHidden(visible)
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
local companionMotionVersion = "DampedFollowV2"
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
	part.CanQuery = false
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

local function premiumCompanionTemplate(definition)
	if definition.rarity ~= "Premium" or not definition.templateName then return nil, nil end
	local externalAssets = ReplicatedStorage:FindFirstChild("PunchWallExternalAssets")
	local externalTemplate = externalAssets and externalAssets:FindFirstChild(definition.templateName)
	if externalTemplate and externalTemplate:IsA("Model") then
		return externalTemplate, "ExternalTemplate"
	end
	local gameRoot = workspace:FindFirstChild("PunchWallRPG")
	if gameRoot then
		for _, candidate in ipairs(gameRoot:GetDescendants()) do
			if candidate:IsA("Model")
				and candidate:GetAttribute("VisualRole") == "PremiumPetShowcase"
				and candidate:GetAttribute("PetTemplate") == definition.templateName then
				return candidate, "ShowcaseClone"
			end
		end
	end
	return nil, nil
end

local function initialCompanionBoundsCFrame(rootPart, index, followHeight)
	local side = index % 2 == 0 and 1 or -1
	local row = math.floor((index - 1) / 2)
	return rootPart.CFrame
		* CFrame.new(side * (2.65 + row * 0.85), followHeight or 1.05, 3.0 + row * 1.3)
		* CFrame.Angles(0, math.pi, 0)
end

local function registerCompanion(model, token, index, definition, stars, visualSource)
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
		if descendant:IsA("LuaSourceContainer")
			or descendant:IsA("RemoteEvent") or descendant:IsA("RemoteFunction")
			or descendant:IsA("ClickDetector") or descendant:IsA("ProximityPrompt")
			or descendant:IsA("Tool") or descendant:IsA("Humanoid") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
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
	if initialSize.Y > 0.01 then
		pcall(function()
			model:ScaleTo(model:GetScale() * (targetHeight / initialSize.Y))
		end)
	end
	local boundsCFrame, boundsSize = model:GetBoundingBox()
	local pivotToBounds = model:GetPivot():ToObjectSpace(boundsCFrame)
	local assetId = tonumber(model:GetAttribute("AssetId")) or 0
	local premiumParity = definition.rarity == "Premium"
		and definition.templateName ~= nil
		and visualSource ~= "ProceduralFallback"
	model:SetAttribute("PremiumVisualParity", premiumParity)
	model:SetAttribute("SourceAssetId", assetId)
	model:SetAttribute("VisualPartCount", partCount)
	model:SetAttribute("CompanionTargetHeight", targetHeight)
	model:SetAttribute("FollowResponsiveness", tonumber(definition.followResponsiveness) or 8)
	model:SetAttribute("FollowSmoothing", "ExponentialCFrame")
	model:SetAttribute("ModelBoundsHeight", boundsSize.Y)
	addCompanionAura(model, primaryPart, definition, stars)

	local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local initialBounds = rootPart
		and initialCompanionBoundsCFrame(rootPart, index, definition.followHeight)
		or boundsCFrame
	model:PivotTo(initialBounds * pivotToBounds:Inverse())
	table.insert(companionModels, {
		model = model,
		pivotToBounds = pivotToBounds,
		currentBoundsCFrame = initialBounds,
		followHeight = tonumber(definition.followHeight) or 1.05,
		followResponsiveness = tonumber(definition.followResponsiveness) or 8,
		hoverAmplitude = tonumber(definition.hoverAmplitude) or 0.22,
		phase = index * 1.73,
		premium = definition.rarity == "Premium",
		motionFrames = 0,
	})
	return model
end

local function buildCompanion(token, index)
	local name, stars = GameConfig.ParsePetToken(token)
	local definition = petDefinition(name)
	if definition.rarity == "Premium" then
		local premiumTemplate, visualSource = premiumCompanionTemplate(definition)
		if premiumTemplate then
			local premiumClone = premiumTemplate:Clone()
			local registered = registerCompanion(premiumClone, token, index, definition, stars, visualSource)
			if registered then return registered end
		end
	end
	local curated = workspace:FindFirstChild("CuratedVisualAssets")
	local dragonTemplate = curated and curated:FindFirstChild("Sanitized Crimson Dragon Companion")
	if dragonTemplate and (definition.rarity == "Legendary" or definition.rarity == "Secret") then
		local clone = dragonTemplate:Clone()
		clone:ScaleTo(clone:GetScale() * (definition.rarity == "Premium" and 0.42 or definition.rarity == "Secret" and 0.36 or 0.28))
		local registered = registerCompanion(clone, token, index, definition, stars, "CuratedDragon")
		if registered then return registered end
	end
	local model = Instance.new("Model")
	if definition.rarity == "Premium" then
		local body = visualPart(model, "Fallback Pet Body", Vector3.new(3.4, 3.0, 4.0), definition.color, Enum.Material.Metal, Enum.PartType.Ball)
		local head = visualPart(model, "Fallback Pet Head", Vector3.new(2.4, 2.2, 2.5), definition.accent or definition.color, Enum.Material.Neon, Enum.PartType.Ball)
		head.CFrame = body.CFrame * CFrame.new(0, 1.5, -1.6)
		model.PrimaryPart = body
		return registerCompanion(model, token, index, definition, stars, "ProceduralFallback")
	end
	local body = visualPart(model, "Body", Vector3.new(1.55, 1.1, 1.9), definition.color, definition.rarity == "Secret" and Enum.Material.Metal or Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	local head = visualPart(model, "Head", Vector3.new(1.15, 1.15, 1.15), definition.color:Lerp(Color3.new(1, 1, 1), 0.08), definition.rarity == "Epic" and Enum.Material.Glass or Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	head.CFrame = body.CFrame * CFrame.new(0, 0.25, -1.05)
	for side = -1, 1, 2 do
		local ear = visualPart(model, "Ear", Vector3.new(0.3, 0.62, 0.24), definition.color, Enum.Material.Metal)
		ear.CFrame = head.CFrame * CFrame.new(side * 0.35, 0.52, 0)
		local eye = visualPart(model, "Eye", Vector3.new(0.18, 0.18, 0.12), Color3.fromRGB(15, 25, 31), Enum.Material.Neon, Enum.PartType.Ball)
		eye.CFrame = head.CFrame * CFrame.new(side * 0.25, 0.13, -0.54)
		if definition.rarity == "Legendary" or definition.rarity == "Secret" or definition.rarity == "Premium" then
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
	return registerCompanion(model, token, index, definition, stars, "ProceduralPet")
end

local function buildGauntlet(fistName)
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
	local function addTierAura(targetPart)
		if not targetPart then return end
		local rateByTier = { 1.5, 3, 5, 8, 10, 12, 15, 18 }
		local aura = Instance.new("ParticleEmitter")
		aura.Name = (definition.displayName or fistName) .. " Aura"
		aura.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		aura.Color = ColorSequence.new(primary, accent)
		aura.LightEmission = math.clamp(0.3 + definition.tier * 0.08, 0.35, 1)
		aura.Rate = rateByTier[math.clamp(definition.tier or 1, 1, 8)]
		aura.Lifetime = NumberRange.new(0.22, 0.48 + math.min(definition.tier, 8) * 0.025)
		aura.Speed = NumberRange.new(0.18, 0.6 + definition.tier * 0.08)
		aura.Drag = 3
		aura.SpreadAngle = Vector2.new(180, 180)
		aura.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1 + definition.tier * 0.018),
			NumberSequenceKeypoint.new(0.35, 0.16 + definition.tier * 0.025),
			NumberSequenceKeypoint.new(1, 0),
		})
		aura.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, definition.tier <= 2 and 0.42 or 0.18),
			NumberSequenceKeypoint.new(1, 1),
		})
		aura.Parent = targetPart
		if definition.tier >= 3 then
			local auraLight = Instance.new("PointLight")
			auraLight.Name = "Fist Aura Light"
			auraLight.Color = accent
			auraLight.Brightness = 0.25 + definition.tier * 0.09
			auraLight.Range = 3 + definition.tier * 0.65
			auraLight.Shadows = false
			auraLight.Parent = targetPart
		end
		if definition.tier >= 5 then
			local energy = Instance.new("ParticleEmitter")
			energy.Name = (definition.displayName or fistName) .. " Energy Arcs"
			energy.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			energy.Color = ColorSequence.new(accent, Color3.new(1, 1, 1))
			energy.LightEmission = 1
			energy.Rate = 4 + definition.tier * 1.5
			energy.Lifetime = NumberRange.new(0.16, 0.34)
			energy.Speed = NumberRange.new(0.4, 1.4)
			energy.Drag = 4
			energy.SpreadAngle = Vector2.new(180, 180)
			energy.Rotation = NumberRange.new(0, 360)
			energy.RotSpeed = NumberRange.new(-180, 180)
			energy.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.24 + definition.tier * 0.025),
				NumberSequenceKeypoint.new(0.45, 0.12 + definition.tier * 0.012),
				NumberSequenceKeypoint.new(1, 0),
			})
			energy.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.08),
				NumberSequenceKeypoint.new(1, 1),
			})
			energy.Parent = targetPart

			local highlight = Instance.new("Highlight")
			highlight.Name = "Hero Fist Tier Glow"
			highlight.Adornee = model
			highlight.DepthMode = Enum.HighlightDepthMode.Occluded
			highlight.FillColor = primary
			highlight.OutlineColor = accent
			highlight.FillTransparency = math.clamp(0.94 - definition.tier * 0.025, 0.68, 0.86)
			highlight.OutlineTransparency = math.clamp(0.82 - definition.tier * 0.07, 0.18, 0.55)
			highlight.Parent = model
		end
		model:SetAttribute("TierAura", aura.Name)
		model:SetAttribute("AuraRate", aura.Rate)
	end

	-- Use sanitized Creator Store visuals when available. The gameplay punch, input,
	-- animation, and damage remain owned by this client/server code.
	local importedSource
	local assetFolder = ReplicatedStorage:FindFirstChild("PunchWallFistAssets")
	local externalAssetFolder = ReplicatedStorage:FindFirstChild("PunchWallExternalAssets")
	local visualAssetFolder = assetFolder
	if definition.model == "Gold" and externalAssetFolder then
		importedSource = externalAssetFolder:FindFirstChild("Sanitized_PowerFistGoldKnuckle")
			or externalAssetFolder:FindFirstChild("Sanitized_TitanGoldFist")
		visualAssetFolder = externalAssetFolder
	end
	if assetFolder then
		-- A glove can only be aligned well if its source mesh actually reads as a
		-- closed punch. Use the approved closed-fist silhouette for every tier and
		-- layer tier-specific armor below; the rejected ring/cuff assets remain in
		-- the place only as documented fallbacks.
		importedSource = importedSource
			or assetFolder:FindFirstChild("CreatorStore_ArmoredClosedHeroFist")
			or assetFolder:FindFirstChild("CreatorStore_SmoothClosedHeroFist")
		if not importedSource and (definition.style == "Starter" or definition.style == "Boxing") then
			-- Prefer a closed-fist mesh with a clean wrist silhouette. The older
			-- fitted boxing glove is retained only as a place-file fallback.
			importedSource = assetFolder:FindFirstChild("CreatorStore_ArmoredClosedHeroFist")
				or assetFolder:FindFirstChild("CreatorStore_SmoothClosedHeroFist")
				or assetFolder:FindFirstChild("CreatorStore_FittedHeroBoxingGlove")
			if not importedSource then
				local pair = assetFolder:FindFirstChild("CreatorStore_RedBoxingGloves")
				local glovePair = pair and pair:FindFirstChild("Glove pair")
				importedSource = glovePair and glovePair:FindFirstChild("glove R")
			end
		elseif not importedSource and definition.style == "Iron" then
			local source = assetFolder:FindFirstChild("CreatorStore_PowerBoxingGloves")
			importedSource = source and source:FindFirstChild("RightGlove", true)
		elseif not importedSource and definition.style == "Thunder" then
			local source = assetFolder:FindFirstChild("CreatorStore_VoidPowerGloves")
			importedSource = source and source:FindFirstChild("R", true)
		elseif not importedSource and definition.style == "Titan" then
			local source = assetFolder:FindFirstChild("CreatorStore_VargasGauntlets")
			local gloves = source and source:FindFirstChild("Vargas's gloves")
			importedSource = gloves and gloves:FindFirstChild("Right")
		end
	end
	if importedSource and importedSource.Parent and visualAssetFolder and visualAssetFolder:GetAttribute("SanitizedVisualOnly") ~= false then
		local imported = importedSource:Clone()
		imported.Name = "Creator Store Fist Visual"
		imported.Parent = model
		local isArmoredClosedFist = importedSource.Name == "CreatorStore_ArmoredClosedHeroFist"
		local isClosedHeroFist = importedSource.Name == "CreatorStore_SmoothClosedHeroFist"
		local isGoldFist = importedSource.Name == "Sanitized_PowerFistGoldKnuckle"
			or importedSource.Name == "Sanitized_TitanGoldFist"
		local isImportedClosedFist = isArmoredClosedFist or isClosedHeroFist or isGoldFist
		-- Creator Store meshes have unrelated authoring scales. Normalize the
		-- largest visual dimension against the actual RightHand before welding,
		-- otherwise a glove can appear as a detached box beside the arm.
		local sourceSize = imported:IsA("Model") and select(2, imported:GetBoundingBox()) or imported.Size
		local styleScale = definition.style == "Celestial" and 2.08
			or definition.style == "Storm" and 1.95
			or definition.style == "Vanguard" and 1.82
			or definition.style == "Titan" and 2.02
			or definition.style == "Thunder" and 1.88
			or definition.style == "Iron" and 1.76
			or definition.style == "Boxing" and 1.72
			or 1.62
		local sourceLargest = math.max(sourceSize.X, sourceSize.Y, sourceSize.Z)
		local handReference = hand.Name == "Right Arm" and hand.Size.X or hand.Size.Y
		local importedScale = math.clamp((handReference * styleScale) / math.max(sourceLargest, 0.01), 0.25, 2.2)
		if imported:IsA("Model") then imported:ScaleTo(importedScale) else imported.Size *= importedScale end
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
		-- The approved armored fist's authored Y axis runs from cuff to knuckles.
		-- Map that axis to character-forward and its Z axis to world-up so the
		-- model sits on the wrist instead of hanging vertically beside the hand.
		local closedFistRotation = CFrame.fromMatrix(
			Vector3.zero,
			Vector3.new(1, 0, 0),
			Vector3.new(0, 0, -1),
			Vector3.new(0, 1, 0)
		)
		local gripRotation = (isArmoredClosedFist or isGoldFist or isClosedHeroFist) and closedFistRotation
			or (isFittedHeroGlove and CFrame.new() or CFrame.Angles(0, math.rad(180), 0))
		local wristY = isImportedClosedFist
			and (hand.Name == "Right Arm" and -hand.Size.Y * 0.48 or -hand.Size.Y * 0.05)
			or isFittedHeroGlove
			and (hand.Name == "Right Arm" and -hand.Size.Y * 0.365 or -hand.Size.Y * 0.08)
			or (hand.Name == "Right Arm" and -hand.Size.Y * 0.42 or -hand.Size.Y * 0.03)
		local forwardOffset = (isArmoredClosedFist or isGoldFist)
			and (scaledBoundsSize.Y * 0.06 + hand.Size.Z * 0.22)
			or isClosedHeroFist
			and (scaledBoundsSize.X * 0.18 + hand.Size.Z * 0.05)
			or isFittedHeroGlove
			and hand.Size.Z * 0.06
			or (hand.Size.Z * 0.18 + scaledBoundsSize.Z * 0.22)
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
		model:SetAttribute("AlignmentStandard", hand.Name == "Right Arm" and "R6Wrist" or "R15RightHand")
		model:SetAttribute("GripProfile", isGoldFist and "GoldFistWristAligned"
			or isArmoredClosedFist and "ArmoredFistWristAligned"
			or isClosedHeroFist and "ClosedFistForward"
			or (isFittedHeroGlove and "FittedHeroArm" or "LegacyCreatorStore"))
		model:SetAttribute("GripForwardOffset", forwardOffset)
		model:SetAttribute("GripAxis", isImportedClosedFist and "LocalYToPunchDirection" or "Legacy")
		model:SetAttribute("VisualBoundsX", scaledBoundsSize.X)
		model:SetAttribute("VisualBoundsY", scaledBoundsSize.Y)
		model:SetAttribute("VisualBoundsZ", scaledBoundsSize.Z)
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
			if isImportedClosedFist and descendant.Name ~= "Tier Color Shell" then
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
		if isImportedClosedFist then
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
			local cuffColor = definition.tier >= 5 and primary:Lerp(Color3.fromRGB(75, 43, 14), 0.36)
				or definition.tier >= 3 and primary:Lerp(Color3.new(0, 0, 0), 0.28)
				or primary:Lerp(Color3.new(0, 0, 0), 0.18)
			local cuff = addTierArmor(
				"Tier Wrist Cuff",
				Vector3.new(hand.Size.Y * 0.22, hand.Size.X * 1.16, hand.Size.Z * 1.12),
				hand.CFrame * CFrame.new(0, hand.Size.Y * 0.43, 0) * CFrame.Angles(0, 0, math.rad(90)),
				cuffColor,
				definition.tier >= 3 and Enum.Material.Metal or definition.material,
				Enum.PartType.Cylinder
			)
			cuff:SetAttribute("FistShape", "WristBridge")
			local characterRoot = character:FindFirstChild("HumanoidRootPart")
			local fistCenter = desiredBounds.Position
			local facing = characterRoot and characterRoot.CFrame.LookVector or Vector3.new(0, 0, -1)
			local up = characterRoot and characterRoot.CFrame.UpVector or Vector3.yAxis
			local right = characterRoot and characterRoot.CFrame.RightVector or Vector3.xAxis
			local forwardLength = (isArmoredClosedFist or isGoldFist) and scaledBoundsSize.Y or scaledBoundsSize.X
			local knuckleWidth = math.clamp(scaledBoundsSize.X * 0.2, 0.2, 0.34)
			for knuckle = 1, 4 do
				local across = (knuckle - 2.5) * knuckleWidth * 0.86
				local knucklePosition = fistCenter
					+ facing * (forwardLength * 0.43)
					+ right * across
					+ up * (scaledBoundsSize.Z * 0.12)
				local plate = addTierArmor(
					"Hero Knuckle Plate " .. knuckle,
					Vector3.new(knuckleWidth, math.clamp(scaledBoundsSize.Z * 0.24, 0.2, 0.34), 0.13),
					CFrame.lookAt(knucklePosition, knucklePosition + facing, up),
					knuckle % 2 == 0 and accent or primary:Lerp(accent, 0.38),
					definition.tier >= 4 and Enum.Material.Neon or Enum.Material.Metal
				)
				plate:SetAttribute("FistShape", "KnuckleArmor")
			end
			if definition.tier >= 3 then
				local plateCenter = fistCenter + facing * (forwardLength * 0.33 + 0.045) - up * (scaledBoundsSize.Z * 0.13)
				local plateCFrame = CFrame.lookAt(plateCenter, plateCenter + facing, up)
				local plateColor = definition.tier == 5 and primary:Lerp(Color3.new(0, 0, 0), 0.62) or accent
				local coreSize = math.clamp(math.min(scaledBoundsSize.X, scaledBoundsSize.Y) * 0.28, 0.22, 0.42)
				local plate = addTierArmor(
					"Hero Core Gem",
					Vector3.new(coreSize, coreSize, coreSize),
					plateCFrame,
					plateColor,
					definition.tier >= 4 and Enum.Material.Neon or Enum.Material.Metal,
					Enum.PartType.Ball
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
			model:SetAttribute("SilhouetteFamily", "ClosedHeroFist")
			model:SetAttribute("ShopArtMatchedTier", definition.tier)
		end
		if firstVisualPart then
			if isImportedClosedFist and hand.Name == "RightHand" then
				shared.PunchWallHiddenHandTransparency = hand.Transparency
				hand.Transparency = 1
				hand.LocalTransparencyModifier = 1
				shared.PunchWallHiddenFistHand = hand
			end
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
				local rightAura = voidSource and voidSource:FindFirstChild("R", true)
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
	addTierAura(palm)
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
	model:SetAttribute("HonorItem", definition.name)
	model:SetAttribute("PowerBonus", definition.powerBonus)
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
		trail.Parent = anchor
	elseif definition.visual == "Storm" then
		local attachment = Instance.new("Attachment")
		attachment.Parent = anchor
		local external = ReplicatedStorage:FindFirstChild("PunchWallExternalAssets")
		local source = external and external:FindFirstChild("Sanitized_VoidFistAura")
		local auraPart = source and source:FindFirstChild("R", true)
		local copied = 0
		if auraPart then
			for _, descendant in ipairs(auraPart:GetDescendants()) do
				if descendant:IsA("ParticleEmitter") and copied < 8 then
					local emitter = descendant:Clone()
					emitter.Rate = math.clamp(emitter.Rate, 1, 8)
					emitter.Lifetime = NumberRange.new(math.min(emitter.Lifetime.Min, 0.7), math.min(emitter.Lifetime.Max, 1.1))
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
			aura.Parent = attachment
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
		light.Brightness = 1.2
		light.Range = 8
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

refreshCharacterVisuals = function()
	local equippedPets = decodeJSON(latestStats.EquippedPetsJSON, {})
	local signature = tostring(latestStats.EquippedFist or "Starter Glove")
		.. "|" .. table.concat(equippedPets, ",")
		.. "|" .. tostring(latestStats.EquippedHonorItem or "None")
		.. "|" .. tostring(player.Character)
	if signature == visualSignature and currentGauntlet and currentGauntlet.Parent then return end
	if not buildGauntlet(latestStats.EquippedFist or "Starter Glove") then
		visualSignature = ""
		task.delay(0.4, refreshCharacterVisuals)
		return
	end
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
	gui:SetAttribute("PremiumCompanionCount", premiumCount)
	gui:SetAttribute("PremiumPetVisualParity", premiumCount == premiumParityCount)
end

-- Apply the pose after Animator updates so Motor6D and AnimationConstraint rigs both move.
local punchMotionState
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
	if currentTrail then
		local trailForPunch = currentTrail
		trailForPunch.Enabled = false
		task.delay(0.16, function()
			if trailForPunch and trailForPunch.Parent then trailForPunch.Enabled = true end
		end)
		task.delay(0.4, function()
			if trailForPunch and trailForPunch.Parent then trailForPunch.Enabled = false end
		end)
	end
	if not clientSettings.motion then
		gui:SetAttribute("CharacterPunchMotionSuppressed", true)
		return true
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid then return false end
	directionName = tostring(directionName or "Forward")
	if latestStats.TrainingActive ~= 1 then humanoid.AutoRotate = true end
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
	}
	gui:SetAttribute("CharacterPunchMotionActive", true)
	gui:SetAttribute("CharacterPunchMotionSuppressed", false)
	gui:SetAttribute("CharacterPunchRig", humanoid.RigType == Enum.HumanoidRigType.R15 and "R15" or "R6")
	gui:SetAttribute("PunchMotionPhase", "Windup")
	gui:SetAttribute("PunchContactAt", now + 0.2)
	gui:SetAttribute("CharacterPunchCount", (gui:GetAttribute("CharacterPunchCount") or 0) + 1)
	return true
end

local trainingAnimationGeneration = 0
shared.PunchWallSetTrainingAnimation = function(active)
	trainingAnimationGeneration += 1
	local generation = trainingAnimationGeneration
	gui:SetAttribute("ContinuousTrainingAnimation", active == true)
	if shared.PunchWallTrainingOverlay then shared.PunchWallTrainingOverlay.Visible = active == true end
	if not active then return end
	task.spawn(function()
		while generation == trainingAnimationGeneration and latestStats.TrainingActive == 1 do
			local character = player.Character
			local rootPart = character and character:FindFirstChild("HumanoidRootPart")
			local world = workspace:FindFirstChild("PunchWallRPG")
			local interactables = world and world:FindFirstChild("Interactables")
			local bag = interactables and interactables:FindFirstChild("Power Bag")
			if rootPart and bag and (rootPart.Position - bag.Position).Magnitude <= 18 then
				performPunchAnimation()
				gui:SetAttribute("LastTrainingAnimationAt", os.clock())
			end
			task.wait(1)
		end
	end)
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
		-- Damage lands after the 0.2 second wind-up. Holding the camera for a few
		-- frames beyond contact lets the avatar visibly lead the dash before the
		-- translation-only follow catches up.
		delay = 0.24,
		followSpeed = 24,
		maximumFollowSpeed = 72,
		maximumLead = 12,
		followSharpness = 8,
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
		if not shared.PunchWallCameraBaselineCFrame
			or shared.PunchWallCameraPositionBlocked(shared.PunchWallCameraBaselineCFrame.Position, character) then
			shared.PunchWallCameraBaselineCFrame = camera.CFrame
			shared.PunchWallCameraBaselineFocus = camera.Focus
		end
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

RunService.PreSimulation:Connect(function()
	local state = punchMotionState
	if not state then return end
	local elapsed = os.clock() - state.startedAt
	local progress = math.clamp(elapsed / state.duration, 0, 1)
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
	if state.rightShoulder.Parent then state.rightShoulder.Transform = punchPose(rightWindup, rightStrike, progress) end
	if state.leftShoulder and state.leftShoulder.Parent then state.leftShoulder.Transform = punchPose(leftWindup, leftStrike, progress) end
	if state.waist and state.waist.Parent then state.waist.Transform = punchPose(waistWindup, waistStrike, progress) end
	if state.neck and state.neck.Parent then state.neck.Transform = punchPose(neckWindup, neckStrike, progress) end
	if state.rightHip and state.rightHip.Parent then state.rightHip.Transform = punchPose(rightHipWindup, rightHipStrike, progress) end
	if state.leftHip and state.leftHip.Parent then state.leftHip.Transform = punchPose(leftHipWindup, leftHipStrike, progress) end
	gui:SetAttribute("PunchMotionPhase", progress < 0.28 and "Windup" or progress < 0.66 and "Contact" or "Recovery")
	gui:SetAttribute("CharacterPunchMotionPeak", math.max(gui:GetAttribute("CharacterPunchMotionPeak") or 0, math.sin(progress * math.pi)))
	if progress >= 1 then
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
	end
end)

shared.PunchWallCameraPositionBlocked = function(position, character)
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { character, localDebrisFolder, companionsFolder }
	overlap.MaxParts = 32
	for _, part in ipairs(workspace:GetPartBoundsInBox(CFrame.new(position), Vector3.new(0.55, 0.55, 0.55), overlap)) do
		if part:IsA("BasePart") and part.CanCollide and part.Transparency < 0.95 then return true end
	end
	return false
end

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

-- Studio automation and minimized clients can temporarily suspend rendering.
-- Keep the same bounded translation moving on Heartbeat only while no render
-- callback has run recently; active gameplay continues to use RenderStep.
RunService.Heartbeat:Connect(function(deltaTime)
	local renderSuspended = os.clock() - lastPunchCameraRenderAt > 0.08
	if activePunchCamera and renderSuspended then
		updatePunchCameraFollow(math.min(deltaTime, 1 / 30))
	end
	if renderSuspended then
		local camera = workspace.CurrentCamera
		local character = player.Character
		if camera and character then
			if shared.PunchWallCameraPositionBlocked(camera.CFrame.Position, character) then
				if shared.PunchWallHeartbeatLastClearCFrame and shared.PunchWallHeartbeatLastClearFocus then
					local clearCFrame = shared.PunchWallHeartbeatLastClearCFrame
					local clearFocus = shared.PunchWallHeartbeatLastClearFocus
					if shared.PunchWallCameraPositionBlocked(clearCFrame.Position, character) then
						clearCFrame = shared.PunchWallCameraBaselineCFrame
						clearFocus = shared.PunchWallCameraBaselineFocus
					end
					if clearCFrame and clearFocus and not shared.PunchWallCameraPositionBlocked(clearCFrame.Position, character) then
						camera.CFrame = clearCFrame
						camera.Focus = clearFocus
					end
				end
			else
				shared.PunchWallHeartbeatLastClearCFrame = camera.CFrame
				shared.PunchWallHeartbeatLastClearFocus = camera.Focus
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
	RunService:BindToRenderStep("PunchWallCameraGeometryGuard", Enum.RenderPriority.Camera.Value + 2, function(deltaTime)
		lastPunchCameraRenderAt = os.clock()
		local camera = workspace.CurrentCamera
		local character = player.Character
		if not camera or not character then return end
		local desiredCFrame = camera.CFrame
		local desiredFocus = camera.Focus
		local desiredPosition = desiredCFrame.Position
		local activeFollow = gui:GetAttribute("PunchCameraFollowActive") == true
		if wasActiveFollow and not activeFollow then
			recoveringFromFollowHandoff = true
			gui:SetAttribute("PunchCameraHandoffActive", true)
		end
		wasActiveFollow = activeFollow
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
		if shared.PunchWallCameraPositionBlocked(desiredPosition, character) then
			cameraGeometryClampFrames += 1
			recoveringFromGeometryClamp = true
			local clearCFrame = lastClearCameraCFrame or shared.PunchWallHeartbeatLastClearCFrame
			local clearFocus = lastClearCameraFocus or shared.PunchWallHeartbeatLastClearFocus
			if clearCFrame and shared.PunchWallCameraPositionBlocked(clearCFrame.Position, character) then
				clearCFrame = shared.PunchWallCameraBaselineCFrame
				clearFocus = shared.PunchWallCameraBaselineFocus
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
		task.wait(0.35)
		local startLook = camera.CFrame.LookVector
		local selectedDistance = (camera.CFrame.Position - camera.Focus.Position).Magnitude
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
		local insideFrames = 0
		local sampledFrames = 0
		local actions = 0
		local insideNames = {}
		local maximumLead = 0
		local currentPunch = 0
		gui:SetAttribute("PunchCameraMaxAppliedStep", 0)
		local function sampleCamera()
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
			if onScreen and math.abs(headPoint.Y - feetPoint.Y) >= 18 then readableCharacterFrames += 1 end
			local obscured = false
			for _, part in ipairs(camera:GetPartsObscuringTarget({ head.Position, rootPart.Position }, { character, localDebrisFolder, companionsFolder })) do
				if part:IsA("BasePart") and part.Transparency < 0.95 then
					obscured = true
					break
				end
			end
			if onScreen and not obscured then clearCharacterFrames += 1 end
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
			if automation:Invoke("Punch") then actions += 1 end
			for _ = 1, 24 do
				-- Device Simulator can suspend RenderStepped while its viewport is not
				-- actively painting. A timed client sample still yields to the render
				-- scheduler, while guaranteeing that automation cannot deadlock.
				task.wait(1 / 30)
				sampleCamera()
			end
			task.wait(0.65)
			task.wait(1 / 30)
			sampleCamera()
		end
		task.wait(0.2)
		local finishDistance = (camera.CFrame.Position - camera.Focus.Position).Magnitude
		local angle = math.deg(math.acos(math.clamp(startLook:Dot(camera.CFrame.LookVector), -1, 1)))
		local visibility = visibleFrames / math.max(1, sampledFrames)
		local clearVisibility = clearCharacterFrames / math.max(1, sampledFrames)
		local readableVisibility = readableCharacterFrames / math.max(1, sampledFrames)
		local lead = maximumLead
		local appliedStep = gui:GetAttribute("PunchCameraMaxAppliedStep") or 0
		local requested = math.max(1, math.floor(tonumber(punchCount) or 1))
		local valid = actions == requested
			and appliedStep <= 2.65
			and math.abs(finishDistance - selectedDistance) < 0.08
			and angle < 0.25
			and visibility >= 0.9
			and insideFrames == 0
			and camera.CameraType == Enum.CameraType.Custom
			and gui:GetAttribute("PunchCameraFollowActive") == false
			and lead > 1
		local visualValid = valid and clearVisibility >= 0.8 and readableVisibility >= 0.8
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
			zoomDelta = math.abs(finishDistance - selectedDistance),
			angle = angle,
			visibleRatio = visibility,
			clearRatio = clearVisibility,
			readableRatio = readableVisibility,
			inside = insideFrames,
			insideNames = insideNames,
			lead = lead,
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
	local automation = gui:FindFirstChild("PunchWallClientAutomation")
	if automation then
		local harnessConfig = GameConfig.StudioTestHarness or {}
		local harnessVersion = tostring(harnessConfig.Version or "1.0.0")
		local maxHarnessSequenceSteps = math.clamp(tonumber(harnessConfig.MaxSequenceSteps) or 50, 1, 100)
		local clientCommandNames = {
			"Describe", "Sequence", "Snapshot", "Punch", "Jump", "SpinNow", "OpenSpin",
			"OpenTab", "OpenShopPage", "InvokeShopAction", "CloseMenus", "ToggleSound",
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
			return {
				ok = true,
				menuVisible = mainPanel.Visible,
				activeTab = activeTab,
				shopVisible = shop and shop.Visible or false,
				shopPage = shared.PunchWallHeroShopPage,
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
			if action == "ToggleSound" then return shared.PunchWallApplySoundSetting(not clientSettings.sound, true) end
			if action == "OpenMore" then openGameTab("Tasks") return true end
			if action == "OpenShopPage" then
				shared.PunchWallHeroShopPage = tostring(value or "Fists")
				if shared.PunchWallHeroShopRefresh then shared.PunchWallHeroShopRefresh() end
				return true
			end
			if action == "InvokeShopAction" then
				local callback = shared.PunchWallShopActions and shared.PunchWallShopActions[tostring(value or "")]
				if callback then callback() return true end
				return false
			end
			if action == "CloseMenus" then
				setMenuVisible(false)
				local spinModal = gui:FindFirstChild("HeroSpinModal")
				if spinModal then spinModal.Visible = false end
				shared.PunchWallSetModalCoreGuiHidden(false)
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
				if options.motion ~= nil then clientSettings.motion = options.motion == true end
				if options.uiScale ~= nil then clientSettings.uiScale = math.clamp(tonumber(options.uiScale) or 1, 0.8, 1.2) end
				actionRemote:FireServer({ action = "UpdateSettings", value = clientSettings })
				applyResponsiveLayout()
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
end

player.CharacterAdded:Connect(function()
	punchMotionState = nil
	activePunchCamera = nil
	shared.PunchWallCameraBaselineCFrame = nil
	shared.PunchWallCameraBaselineFocus = nil
	visualSignature = ""
	task.delay(1, refreshCharacterVisuals)
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
	for index, state in ipairs(companionModels) do
		local model = state.model
		if model and model.Parent and model.PrimaryPart then
			local side = index % 2 == 0 and 1 or -1
			local row = math.floor((index - 1) / 2)
			local hover = math.sin(now * (state.premium and 2.25 or 2.8) + state.phase) * state.hoverAmplitude
			local sway = math.sin(now * 1.35 + state.phase * 0.7) * 0.14
			local pitch = math.rad(math.clamp(-forwardSpeed * 0.16, -6, 6))
			local roll = math.rad(math.clamp(-sideSpeed * 0.2, -8, 8))
				+ math.rad(math.sin(now * 1.8 + state.phase) * 1.7)
			local targetBounds = rootPart.CFrame
				* CFrame.new(
					side * (2.65 + row * 0.85) + sway,
					state.followHeight + hover,
					3.0 + row * 1.3
				)
				* CFrame.Angles(pitch, math.pi, roll)
			local distance = (state.currentBoundsCFrame.Position - targetBounds.Position).Magnitude
			if distance > 36 then
				state.currentBoundsCFrame = targetBounds
			else
				local alpha = 1 - math.exp(-state.followResponsiveness * deltaTime)
				state.currentBoundsCFrame = state.currentBoundsCFrame:Lerp(targetBounds, alpha)
			end
			model:PivotTo(state.currentBoundsCFrame * state.pivotToBounds:Inverse())
			state.motionFrames += 1
			if state.motionFrames >= 3 and model:GetAttribute("SmoothFollowReady") ~= true then
				model:SetAttribute("SmoothFollowReady", true)
			end
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
shared.PunchWallClientFinalize = function()
local referenceHUD = Instance.new("Frame")
referenceHUD.Name = "PixelPerfectHeroCityHUD"
referenceHUD.BackgroundTransparency = 1
referenceHUD.Size = UDim2.fromScale(1, 1)
referenceHUD.ZIndex = 30
referenceHUD.Parent = gui

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
	shared.PunchWallHUDWidgets.HonorValue = honorValue
end
shared.PunchWallBuildHonorHUD()
local referenceJoystick = referenceImage("MovementJoystick", pixel.Joystick, 57, 640, 270, 270)
referenceJoystick.Active = true
shared.PunchWallSoundToolButton = referenceButton("SoundTool", pixel.SoundTool, 1465, 22, 60, 64, function()
	shared.PunchWallApplySoundSetting(not clientSettings.sound, true)
end)
shared.PunchWallSoundToolButton:SetAttribute("ToolAction", "ToggleSound")
referenceButton("SettingsTool", pixel.SettingsTool, 1526, 22, 60, 64, function() openGameTab("Settings") end)
shared.PunchWallMoreToolButton = referenceButton("MoreTool", pixel.MoreTool, 1587, 22, 64, 64, function()
	openGameTab("Tasks")
end)
shared.PunchWallMoreToolButton:SetAttribute("ToolAction", "OpenGameMenu")
shared.PunchWallApplySoundSetting(clientSettings.sound, false)

referenceHUD:SetAttribute("StudioTestControlLocation", RunService:IsStudio() and "SettingsOnly" or "Unavailable")

referenceButton("DailyButton", pixel.Daily, 16, 201, 82, 111, function() openGameTab("Tasks") end)
referenceButton("SpinButton", pixel.Spin, 16, 316, 82, 111, function()
	if shared.PunchWallOpenSpin then shared.PunchWallOpenSpin() else requestAction("Spin") end
end)
referenceButton("RebirthButton", pixel.Rebirth, 16, 429, 82, 111, function() openGameTab("Tasks") end)
referenceButton("ShopButton", pixel.Shop, 1570, 296, 87, 111, function() openGameTab("Fists") end)
referenceButton("PetsButton", pixel.Pets, 1570, 410, 87, 104, function() openGameTab("Pets") end)
referenceButton("QuestsButton", pixel.Quests, 1570, 515, 87, 103, function() openGameTab("Tasks") end)

local referencePunch = referenceButton("ActionPunch", pixel.Punch, 1211, 669, 250, 250)
referencePunch.MouseButton1Down:Connect(function() setPunchHeld(true) end)
referencePunch.MouseButton1Up:Connect(function() setPunchHeld(false) end)
referencePunch.MouseLeave:Connect(function() setPunchHeld(false) end)
local referenceJump = referenceButton("ActionJump", pixel.Jump, 1460, 694, 211, 211, function()
	requestHumanoidJump()
end)

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
trainingOverlay.Visible = false
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
	buySpins.Text = "3 BONUS SPINS  |  R$39"
	buySpins.TextColor3 = Color3.new(1, 1, 1)
	buySpins.TextSize = 13
	buySpins.ZIndex = 184
	buySpins.Parent = panel
	setRounded(buySpins, 6)
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
		shared.PunchWallSetModalCoreGuiHidden(true)
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
	buySpins.Activated:Connect(function()
		actionRemote:FireServer({ action = "BuyPremiumProduct", target = "SpinPack" })
	end)
	close.Activated:Connect(function()
		spinOverlay.Visible = false
		gui:SetAttribute("SpinModalVisible", false)
		shared.PunchWallSetModalCoreGuiHidden(false)
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
		shared.PunchWallSetModalCoreGuiHidden(true)
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
	buySpins.Activated:Connect(function() actionRemote:FireServer({ action = "BuyPremiumProduct", target = "SpinPack" }) end)
	close.Activated:Connect(function()
		spinOverlay.Visible = false
		gui:SetAttribute("SpinModalVisible", false)
		shared.PunchWallSetModalCoreGuiHidden(false)
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
	shared.PunchWallHeroShopRefresh = function()
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
		header.Position = UDim2.fromScale(0.018, 0.018)
		header.Size = UDim2.fromScale(0.964, 0.155)
		header.ZIndex = 102
		header.Parent = shopReference
		addCorner(header, 4)
		addStroke(header, Color3.fromRGB(17, 35, 45), 3)
		local headerGradient = Instance.new("UIGradient")
		headerGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(142, 12, 18)),
			ColorSequenceKeypoint.new(0.62, Color3.fromRGB(88, 7, 13)),
			ColorSequenceKeypoint.new(0.72, Color3.fromRGB(8, 75, 128)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(4, 24, 61)),
		})
		headerGradient.Parent = header
		for index = 1, 12 do
			local slash = Instance.new("Frame")
			slash.Name = "HeaderSlash" .. index
			slash.BackgroundColor3 = index <= 7 and Color3.fromRGB(225, 21 + index * 3, 24) or Color3.fromRGB(21, 133 + index * 4, 224)
			slash.BackgroundTransparency = 0.16
			slash.BorderSizePixel = 0
			slash.Position = UDim2.fromScale(0.018 + (index - 1) * 0.078, -0.42 + (index % 3) * 0.05)
			slash.Size = UDim2.fromScale(0.03 + (index % 3) * 0.009, 1.85 - (index % 2) * 0.12)
			slash.Rotation = 21 + (index % 2) * 3
			slash.ZIndex = 103
			slash.Parent = header
		end
		label(header, "TitleShadow", "SHOP MENU", UDim2.fromScale(0.192, 0.055), UDim2.fromScale(0.62, 0.9), Color3.fromRGB(0, 0, 0), 48, Enum.Font.GothamBlack, Enum.TextXAlignment.Center)
		local title = label(header, "Title", "SHOP MENU", UDim2.fromScale(0.19, 0), UDim2.fromScale(0.62, 0.9), Color3.fromRGB(255, 249, 237), 48, Enum.Font.GothamBlack, Enum.TextXAlignment.Center)
		title.TextStrokeTransparency = 0.08
		title.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)

		local close = Instance.new("TextButton")
		close.Name = "CloseShop"
		close.BackgroundColor3 = Color3.fromRGB(157, 19, 22)
		close.BorderSizePixel = 0
		close.AnchorPoint = Vector2.new(1, 0.5)
		close.Position = UDim2.fromScale(0.975, 0.5)
		close.Size = UDim2.fromScale(0.075, 0.72)
		close.Font = Enum.Font.GothamBlack
		close.Text = "X"
		close.TextColor3 = Color3.fromRGB(255, 247, 238)
		close.TextSize = 25
		close.TextStrokeTransparency = 0.15
		close.ZIndex = 106
		close.Parent = header
		addCorner(close, 3)
		addStroke(close, Color3.fromRGB(9, 12, 15), 3)
		local closeSize = Instance.new("UISizeConstraint")
		closeSize.MinSize = Vector2.new(44, 44)
		closeSize.Parent = close
		bindButtonMotion(close, close.BackgroundColor3)
		close.Activated:Connect(function() setMenuVisible(false) end)

		local owned = decodeJSON(latestStats.OwnedFistsJSON, { "Starter Glove" })
		local ownedPremium = decodeJSON(latestStats.OwnedPremiumFistsJSON, {})
		local requestedPage = shared.PunchWallHeroShopPage
		local pages = { "Fists", "Premium", "Boosts", "Robux" }
		local page = table.find(pages, requestedPage) and requestedPage or "Fists"
		local tabBand = Instance.new("Frame")
		tabBand.Name = "ShopTabs"
		tabBand.BackgroundTransparency = 1
		tabBand.Position = UDim2.fromScale(0.025, 0.175)
		tabBand.Size = UDim2.fromScale(0.95, 0.075)
		tabBand.ZIndex = 102
		tabBand.Parent = shopReference
		for index, pageName in ipairs(pages) do
			local selected = page == pageName
			local tab = Instance.new("TextButton")
			tab.Name = pageName .. "ShopTab"
			tab.BackgroundColor3 = selected and Color3.fromRGB(20, 134, 205) or Color3.fromRGB(25, 35, 42)
			tab.BorderSizePixel = 0
			tab.Position = UDim2.fromScale((index - 1) * 0.252, 0)
			tab.Size = UDim2.fromScale(0.238, 1)
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
			bindButtonMotion(tab, tab.BackgroundColor3)
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
		elseif page == "Premium" then
			for _, source in ipairs(GameConfig.PremiumFists) do
				local item = table.clone(source)
				item.isPremium = true
				table.insert(products, item)
			end
		elseif page == "Boosts" then
			products = {
				{ name = "CoinBoost", displayName = "COIN BOOST x2", rarity = "EPIC", cost = 5000, art = GameConfig.ShopArt.CoinBoost, accent = Color3.fromRGB(202, 71, 230), detail = "Earn 2x more Coins for 15 minutes.", endsAt = boostInfo.CoinEndsAt or 0 },
				{ name = "SpeedBoost", displayName = "SPEED BOOST", rarity = "RARE", cost = 8000, art = GameConfig.ShopArt.SpeedBoost, accent = Color3.fromRGB(58, 201, 248), detail = "Move faster through the Hero City course.", endsAt = boostInfo.SpeedEndsAt or 0 },
				{ name = "DamageBoost", displayName = "DAMAGE BOOST", rarity = "EPIC", cost = 12000, art = GameConfig.ShopArt.DamageBoost, accent = Color3.fromRGB(239, 112, 51), detail = "Deal 2x wall damage for 15 minutes.", endsAt = boostInfo.DamageEndsAt or 0 },
			}
		else
			for index, source in ipairs(GameConfig.PremiumProducts) do
				local item = table.clone(source)
				item.name = item.name or item.id
				item.isRobuxProduct = true
				item.rarity = "HERO OFFER"
				item.accent = ({ Color3.fromRGB(255, 190, 40), Color3.fromRGB(57, 199, 249), Color3.fromRGB(190, 80, 244), Color3.fromRGB(59, 218, 150) })[index]
				item.detail = item.coins and ("Receive " .. formatNumber(item.coins) .. " Coins instantly.")
					or item.spins and ("Receive " .. item.spins .. " Hero Spins.")
					or item.boost == "TrainingBoostExpiresAt" and "Train Power 2x faster for 15 minutes."
					or "Earn 2x more Coins for 15 minutes."
				item.icon = item.spins and "Success" or item.boost == "TrainingBoostExpiresAt" and "Train" or "Coin"
				item.art = item.id == "CoinPack" and GameConfig.ShopArt.ShopCoinIcon
					or item.id == "SpinPack" and GameConfig.ShopArt.SpinPack
					or item.id == "CoinBoost" and GameConfig.ShopArt.CoinBoost
					or item.id == "TrainingBoost" and GameConfig.ShopArt.SpeedBoost
					or nil
				table.insert(products, item)
			end
		end

		local camera = workspace.CurrentCamera
		local compactCards = UserInputService.TouchEnabled or (camera and camera.ViewportSize.Y < 520)
		if compactCards then
			tabBand.Size = UDim2.new(0.95, 0, 0, 44)
		end
		local rowCount = math.max(1, math.ceil(#products / 2))
		local cardsTop = compactCards and 0.315 or 0.27
		local cardsBottom = compactCards and 0.835 or 0.902
		local rowGap = compactCards and 0.01 or 0.014
		local cardHeight = (cardsBottom - cardsTop - rowGap * (rowCount - 1)) / rowCount
		local compactProductNames = {
			["Boxing Glove"] = "STREET FIST",
			["Iron Knuckle"] = "IRON FIST",
			["Thunder Fist"] = "THUNDER FIST",
			["Crimson Vanguard Fist"] = "VANGUARD FIST",
			["Stormbreaker Fist"] = "STORM FIST",
			["Celestial Titan Fist"] = "TITAN FIST",
			CoinPack = "COIN PACK",
			SpinPack = "SPIN PACK",
			CoinBoost = "2X COINS",
			TrainingBoost = "2X TRAINING",
		}
		for index, item in ipairs(products) do
			local column = (index - 1) % 2
			local row = math.floor((index - 1) / 2)
			local wideCard = index == #products and #products % 2 == 1
			local card = Instance.new("Frame")
			card.Name = item.name .. "ShopCard"
			card.BackgroundColor3 = Color3.fromRGB(10, 18, 23)
			card.BorderSizePixel = 0
			card.Position = UDim2.fromScale(wideCard and 0.03 or 0.03 + column * 0.485, cardsTop + row * (cardHeight + rowGap))
			card.Size = UDim2.fromScale(wideCard and 0.94 or 0.455, cardHeight)
			card.ZIndex = 102
			card.ClipsDescendants = true
			card.Parent = shopReference
			addCorner(card, 5)
			local equippedCard = latestStats.EquippedFist == item.name
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

			local art
			if item.art then
				art = item.art
			elseif item.style == "Vanguard" then
				art = GameConfig.ShopArt.StarterGlove
			elseif item.style == "Storm" then
				art = GameConfig.ShopArt.ChampionGlove
			elseif item.style == "Celestial" then
				art = GameConfig.ShopArt.TitanGlove
			else
				art = item.tier == 1 and GameConfig.ShopArt.StarterGlove
					or item.tier and item.tier >= 5 and GameConfig.ShopArt.TitanGlove
					or item.tier and GameConfig.ShopArt.ChampionGlove
					or ""
			end
			local iconX, iconWidth = 0.025, wideCard and 0.18 or 0.275
			local icon = Instance.new("ImageLabel")
			icon.Name = "ProductArt"
			icon.BackgroundTransparency = 1
			icon.Image = art
			icon.ScaleType = Enum.ScaleType.Fit
			icon.Position = UDim2.fromScale(iconX, 0.06)
			icon.Size = UDim2.fromScale(iconWidth, 0.88)
			icon.ZIndex = 105
			icon.Parent = card
			local fallbackName = item.icon or (item.name == "CoinBoost" and "Coin" or item.name == "SpeedBoost" and "Train" or "Punch")
			local fallback = createThemeIcon(card, fallbackName, icon.Position, icon.Size, "ProductArtFallback")
			fallback.ZIndex = 104
			-- A visible atlas placeholder bleeds old labels through transparent product art.
			fallback.Visible = art == ""

			local textX = wideCard and 0.215 or 0.32
			local rarity = item.rarity or (item.tier == 1 and "COMMON" or item.tier >= 5 and "LEGENDARY" or item.tier >= 4 and "EPIC" or "RARE")
			local productName = compactCards and compactProductNames[item.name] or nil
			productName = productName or string.upper(item.displayName)
			label(card, "Name", productName, UDim2.fromScale(textX, 0.07), UDim2.fromScale(wideCard and 0.48 or 0.41, 0.22), Color3.fromRGB(250, 248, 239), compactCards and 12 or 17, Enum.Font.GothamBlack)
			label(card, "Rarity", rarity, UDim2.fromScale(textX, 0.27), UDim2.fromScale(0.36, 0.15), item.accent, 11, Enum.Font.GothamBlack)
			local detailText = item.detail or ("Built for deeper walls.  " .. compactStat(item.mult) .. "x Power.")
			local detail = label(card, "Detail", detailText, UDim2.fromScale(textX, 0.42), UDim2.fromScale(wideCard and 0.47 or 0.39, 0.34), Color3.fromRGB(210, 221, 226), 11, Enum.Font.Gotham, Enum.TextXAlignment.Left, true)
			detail.TextYAlignment = Enum.TextYAlignment.Top
			detail.Visible = not compactCards

			local priceX = wideCard and 0.755 or 0.735
			local priceIcon
			if item.robux then
				priceIcon = createThemeIcon(card, "Shop", UDim2.fromScale(priceX, 0.08), UDim2.fromScale(wideCard and 0.035 or 0.06, 0.22), "PriceIcon")
			else
				priceIcon = Instance.new("ImageLabel")
				priceIcon.Name = "PriceIcon"
				priceIcon.BackgroundTransparency = 1
				priceIcon.BorderSizePixel = 0
				priceIcon.Image = GameConfig.ShopArt.ShopCoinIcon
				priceIcon.ScaleType = Enum.ScaleType.Fit
				priceIcon.Position = UDim2.fromScale(priceX, 0.08)
				priceIcon.Size = UDim2.fromScale(wideCard and 0.035 or 0.06, 0.22)
				priceIcon.Parent = card
			end
			priceIcon.ZIndex = 105
			local priceText = item.robux and ("R$ " .. item.robux) or ((item.cost or 0) <= 0 and "FREE" or formatNumber(item.cost))
			local priceLabel = label(card, "Price", priceText, UDim2.fromScale(priceX + (wideCard and 0.04 or 0.065), 0.07), UDim2.fromScale(wideCard and 0.18 or 0.18, 0.24), Color3.fromRGB(255, 207, 58), 14, Enum.Font.GothamBlack)
			if compactCards then
				priceIcon.Position = UDim2.fromScale(textX, 0.57)
				priceIcon.Size = UDim2.fromScale(wideCard and 0.035 or 0.06, 0.26)
				priceLabel.Position = UDim2.fromScale(textX + (wideCard and 0.04 or 0.065), 0.54)
				priceLabel.Size = UDim2.fromScale(wideCard and 0.25 or 0.28, 0.3)
				priceLabel.TextSize = 10
			end

			local actionColor = Color3.fromRGB(232, 157, 22)
			local actionText = "BUY"
			local actionCallback
			if page == "Fists" then
				local equipped = latestStats.EquippedFist == item.name
				local isOwned = table.find(owned, item.name) ~= nil
				actionText = equipped and "EQUIPPED" or isOwned and "EQUIP" or "BUY"
				actionColor = equipped and Color3.fromRGB(45, 145, 60) or isOwned and Color3.fromRGB(53, 159, 63) or actionColor
				actionCallback = function()
					if not equipped then actionRemote:FireServer({ action = isOwned and "EquipFist" or "BuyFist", target = item.name }) end
				end
			elseif page == "Premium" then
				local equipped = latestStats.EquippedFist == item.name
				local isOwned = table.find(ownedPremium, item.name) ~= nil
				actionText = equipped and "EQUIPPED" or isOwned and "EQUIP" or ("R$ " .. item.robux)
				actionColor = equipped and Color3.fromRGB(45, 145, 60) or isOwned and Color3.fromRGB(53, 159, 63) or item.accent
				actionCallback = function()
					if not equipped then actionRemote:FireServer({ action = isOwned and "EquipFist" or "BuyPremiumFist", target = item.name }) end
				end
			elseif page == "Boosts" then
				local seconds = math.max(0, math.floor((item.endsAt or 0) - now))
				actionText = seconds > 0 and ("ACTIVE %02d:%02d"):format(math.floor(seconds / 60), seconds % 60) or "BUY"
				actionColor = seconds > 0 and Color3.fromRGB(45, 145, 60) or actionColor
				actionCallback = function() actionRemote:FireServer({ action = "BuyShopBoost", target = item.name }) end
			else
				actionText = "R$ " .. item.robux
				actionColor = item.accent
				actionCallback = function() actionRemote:FireServer({ action = "BuyPremiumProduct", target = item.id }) end
			end

			local actionShadow = Instance.new("Frame")
			actionShadow.Name = "ActionShadow"
			actionShadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
			actionShadow.BackgroundTransparency = 0.1
			actionShadow.BorderSizePixel = 0
			actionShadow.AnchorPoint = Vector2.new(1, 1)
			actionShadow.Position = UDim2.fromScale(0.97, 0.92)
			actionShadow.Size = compactCards and UDim2.new(wideCard and 0.18 or 0.25, 0, 0, 44) or UDim2.fromScale(wideCard and 0.18 or 0.25, 0.38)
			actionShadow.ZIndex = 104
			actionShadow.Parent = card
			addCorner(actionShadow, 4)
			local action = Instance.new("TextButton")
			action.Name = item.name .. "Action"
			action.BackgroundColor3 = actionColor
			action.BorderSizePixel = 0
			action.AnchorPoint = Vector2.new(1, 1)
			action.Position = UDim2.fromScale(0.962, 0.89)
			action.Size = compactCards and UDim2.new(wideCard and 0.18 or 0.25, 0, 0, 44) or UDim2.fromScale(wideCard and 0.18 or 0.25, 0.38)
			action.Font = Enum.Font.GothamBlack
			action.Text = actionText
			action.TextColor3 = Color3.fromRGB(255, 255, 255)
			action.TextSize = compactCards and 10 or 14
			action.TextStrokeTransparency = 0.2
			action.ZIndex = 106
			action.Parent = card
			local actionSize = Instance.new("UISizeConstraint")
			actionSize.Name = "MinimumTouchTarget"
			actionSize.MinSize = Vector2.new(44, 44)
			actionSize.Parent = action
			addCorner(action, 4)
			addStroke(action, Color3.fromRGB(5, 9, 11), 2)
			bindButtonMotion(action, actionColor)
			shared.PunchWallShopActions[item.name] = actionCallback
			action.Activated:Connect(actionCallback)
		end

		local footerBand = Instance.new("Frame")
		footerBand.Name = "ShopFooter"
		footerBand.BackgroundColor3 = Color3.fromRGB(8, 15, 19)
		footerBand.BorderSizePixel = 0
		footerBand.Position = compactCards and UDim2.fromScale(0.018, 0.85) or UDim2.fromScale(0.018, 0.91)
		footerBand.Size = compactCards and UDim2.new(0.964, 0, 0, 46) or UDim2.fromScale(0.964, 0.075)
		footerBand.ZIndex = 102
		footerBand.Parent = shopReference
		addCorner(footerBand, 4)
		addStroke(footerBand, Color3.fromRGB(40, 61, 70), 1.5)
		label(footerBand, "SecureLabel", "HERO INVENTORY SYNCED", UDim2.fromScale(0.025, 0), UDim2.fromScale(0.34, 1), Color3.fromRGB(184, 201, 209), 11, Enum.Font.GothamBold)
		local bottomClose = Instance.new("TextButton")
		bottomClose.Name = "CloseShopBottom"
		bottomClose.BackgroundColor3 = Color3.fromRGB(192, 24, 22)
		bottomClose.BorderSizePixel = 0
		bottomClose.AnchorPoint = Vector2.new(0.5, 0.5)
		bottomClose.Position = UDim2.fromScale(0.5, 0.5)
		bottomClose.Size = compactCards and UDim2.new(0.24, 0, 0, 44) or UDim2.fromScale(0.24, 0.94)
		bottomClose.Font = Enum.Font.GothamBlack
		bottomClose.Text = "CLOSE"
		bottomClose.TextColor3 = Color3.fromRGB(255, 250, 240)
		bottomClose.TextSize = 16
		bottomClose.TextStrokeTransparency = 0.18
		bottomClose.ZIndex = 106
		bottomClose.Parent = footerBand
		local bottomCloseSize = Instance.new("UISizeConstraint")
		bottomCloseSize.Name = "MinimumTouchTarget"
		bottomCloseSize.MinSize = Vector2.new(44, 44)
		bottomCloseSize.Parent = bottomClose
		addCorner(bottomClose, 4)
		addStroke(bottomClose, Color3.fromRGB(4, 8, 10), 3)
		bindButtonMotion(bottomClose, bottomClose.BackgroundColor3)
		bottomClose.Activated:Connect(function() setMenuVisible(false) end)
		label(footerBand, "ServerLabel", "SERVER VERIFIED PURCHASES", UDim2.fromScale(0.64, 0), UDim2.fromScale(0.335, 1), Color3.fromRGB(81, 190, 235), 11, Enum.Font.GothamBold, Enum.TextXAlignment.Right)
	end
	shared.PunchWallHeroShopRefresh()
	return shopReference
end
shared.PunchWallShopReference = shared.PunchWallBuildShopUI()
shared.PunchWallBuildShopUI = nil

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
	if shared.PunchWallHeroShopRefresh then shared.PunchWallHeroShopRefresh() end
	if shared.PunchWallRefreshSpin then shared.PunchWallRefreshSpin() end
	if shared.PunchWallSetTrainingAnimation then shared.PunchWallSetTrainingAnimation((payload.TrainingActive or 0) >= 1) end
end)

mainPanel:GetPropertyChangedSignal("Visible"):Connect(function()
	referenceHUD.Visible = not mainPanel.Visible
	shared.PunchWallShopReference.Visible = mainPanel.Visible and activeTab == "Fists"
	shared.PunchWallShopDimmer.Visible = shared.PunchWallShopReference.Visible
	task.defer(applyResponsiveLayout)
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
	shared.PunchWallShopReference.Visible = mainPanel.Visible and activeTab == "Fists"
	shared.PunchWallShopDimmer.Visible = shared.PunchWallShopReference.Visible
	closeButton.Visible = mainPanel.Visible and not shared.PunchWallShopReference.Visible
	mainPanel.BackgroundTransparency = shared.PunchWallShopReference.Visible and 1 or 0.03
	local touchGui = player.PlayerGui:FindFirstChild("TouchGui")
	if touchGui and touchGui:IsA("ScreenGui") then
		touchGui.Enabled = true
		local touchControlFrame = touchGui:FindFirstChild("TouchControlFrame")
		if touchControlFrame then touchControlFrame.Visible = false end
	end
	if shared.PunchWallJoystickVector.Magnitude > 0 then
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then humanoid:Move(Vector3.new(shared.PunchWallJoystickVector.X, 0, shared.PunchWallJoystickVector.Y), true) end
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

applyResponsiveLayout = function()
	local camera = workspace.CurrentCamera
	if not camera then return end
	local viewport = camera.ViewportSize
	local compact = UserInputService.TouchEnabled or viewport.Y < 520
	local userScale = math.clamp(tonumber(clientSettings.uiScale) or 1, 0.8, 1.2)
	local shopOpen = mainPanel.Visible and activeTab == "Fists"
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
		mainPanel.AnchorPoint = Vector2.new(0.5, 0.5)
		if shopOpen then
			local shopHeight = math.max(280, math.min(viewport.Y - 12, (viewport.X - 20) / 1.58))
			mainPanel.Size = UDim2.fromOffset(shopHeight * 1.58, shopHeight)
		else
			local panelHeight = math.max(210, math.min(viewport.Y - 16, (viewport.X - 24) * 408 / 677))
			local panelWidth = panelHeight * 677 / 408
			mainPanel.Size = UDim2.fromOffset(panelWidth, panelHeight)
			closeButton.Position = UDim2.new(1, -8, 0, 8)
			closeButton.Size = UDim2.fromOffset(38, 38)
			-- Roblox's mandatory mobile system cluster occupies the top-left even
			-- when CoreGui is disabled. Reserve that area so the first tab remains
			-- fully readable and tappable in landscape device simulation.
			tabBar.Position = UDim2.fromOffset(90, 8)
			tabBar.Size = UDim2.new(1, -138, 0, 42)
			content.Position = UDim2.fromOffset(10, 58)
			content.Size = UDim2.new(1, -20, 1, -68)
			local tabWidth = math.max(54, math.floor((panelWidth - 90 - 48 - 28) / 5))
			local compactLabels = { Fists = "FIST", Pets = "PETS", Honor = "HONOR", Tasks = "TASKS", Settings = "SET" }
			for tabName, tab in pairs(tabButtons) do
				tab.Size = UDim2.fromOffset(tabWidth, 38)
				tab.Text = compactLabels[tabName] or string.upper(tabName)
				tab.TextSize = 9
				local padding = tab:FindFirstChildOfClass("UIPadding")
				if padding then
					padding.PaddingLeft = UDim.new(0, 29)
					padding.PaddingRight = UDim.new(0, 4)
				end
				local icon = tab:FindFirstChild("TabIcon")
				if icon then
					icon.Position = UDim2.fromOffset(-26, 7)
					icon.Size = UDim2.fromOffset(24, 24)
				end
			end
		end
		mainPanel.Position = UDim2.fromScale(0.5, 0.5)
		if rankWidgets.Root then
			rankWidgets.Root.Position = UDim2.fromOffset(74, 92)
			rankWidgets.Root.Size = UDim2.fromOffset(100, 228)
		end
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
		if shopOpen then
			local shopHeight = math.max(460, math.min(viewport.Y - 36, 860, (viewport.X - 48) / 1.5))
			mainPanel.Size = UDim2.fromOffset(shopHeight * 1.5, shopHeight)
			mainPanel.Position = UDim2.fromScale(0.5, 0.5)
		else
			mainPanel.Size = UDim2.fromOffset(677, 408)
			mainPanel.Position = UDim2.fromScale(0.5, 0.52)
			closeButton.Position = UDim2.new(1, -10, 0, 10)
			closeButton.Size = UDim2.fromOffset(44, 44)
			tabBar.Position = UDim2.fromOffset(12, 12)
			tabBar.Size = UDim2.new(1, -72, 0, 48)
			content.Position = UDim2.fromOffset(12, 68)
			content.Size = UDim2.new(1, -24, 1, -80)
			for tabName, tab in pairs(tabButtons) do
				tab.Size = UDim2.fromOffset(108, 44)
				tab.Text = string.upper(tabName)
				tab.TextSize = 11
				local padding = tab:FindFirstChildOfClass("UIPadding")
				if padding then
					padding.PaddingLeft = UDim.new(0, 36)
					padding.PaddingRight = UDim.new(0, 8)
				end
				local icon = tab:FindFirstChild("TabIcon")
				if icon then
					icon.Position = UDim2.fromOffset(-31, 8)
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
	panel.Visible = false
	menuButton.Visible = false
	statusDeck.Visible = false
	mobileControls.Visible = false
	contextLabel.Visible = false
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
