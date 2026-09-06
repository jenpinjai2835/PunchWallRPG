local FistVisualBuilder = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ASSET_ID = "1622087753"
local ASSET_CREATOR = "Penguin9805"
local FIST_MESH_ID = "rbxassetid://65322375"
local FIST_TEXTURE_ID = "rbxassetid://65322423"

local RIG_PROFILES = {
	R15 = {
		name = "R15RightHand",
		wristYScale = -0.08,
		cuffYScale = 0.43,
		minTargetRatio = 1.45,
		maxTargetRatio = 2.08,
		maxScale = 1.35,
		maxCenterOffset = 1.35,
	},
	R6 = {
		name = "R6DistalWrist",
		wristYScale = -0.34,
		cuffYScale = -0.12,
		minTargetRatio = 1.45,
		maxTargetRatio = 2.08,
		maxScale = 1.35,
		maxCenterOffset = 1.65,
	},
}

local HERO_GAUNTLET_STYLES = {
	Starter = {
		scale = 1.04,
		armorPattern = "PaddedStarter",
		plateCount = 0,
		finCount = 0,
		shopArtKey = "StarterGlove",
		signatureFeature = "PAD",
	},
	Boxing = {
		scale = 1.09,
		armorPattern = "BoxingWrap",
		plateCount = 1,
		finCount = 0,
		shopArtKey = "StarterGlove",
		signatureFeature = "WRAP",
	},
	Iron = {
		scale = 1.13,
		armorPattern = "RivetedIron",
		plateCount = 2,
		finCount = 0,
		shopArtKey = "ChampionGlove",
		signatureFeature = "RIVET",
	},
	Thunder = {
		scale = 1.16,
		armorPattern = "ThunderRails",
		plateCount = 2,
		finCount = 2,
		shopArtKey = "TitanGlove",
		signatureFeature = "RAIL",
	},
	Titan = {
		scale = 1.20,
		armorPattern = "SiegePlates",
		plateCount = 3,
		finCount = 2,
		shopArtKey = "TitanGlove",
		signatureFeature = "SIEGE",
	},
	Vanguard = {
		scale = 1.17,
		armorPattern = "VanguardShield",
		plateCount = 3,
		finCount = 0,
		shopArtKey = "StarterGlove",
		signatureFeature = "SHIELD",
	},
	Storm = {
		scale = 1.20,
		armorPattern = "StormBlades",
		plateCount = 3,
		finCount = 2,
		shopArtKey = "ChampionGlove",
		signatureFeature = "BLADE",
	},
	Celestial = {
		scale = 1.24,
		armorPattern = "CelestialCrown",
		plateCount = 4,
		finCount = 2,
		shopArtKey = "TitanGlove",
		signatureFeature = "CROWN",
	},
}

-- Uploaded silhouettes remain untinted. These short catalog motifs add one
-- immutable corner mark per fist so all normal and Premium offers stay
-- recognizable even when several entries share the same armor family.
local FIST_CATALOG_MOTIFS = {
	StarterFist = "HOME",
	BoxingFist = "K.O.",
	IronFist = "RVT",
	ThunderFist = "BOLT",
	TitanFist = "FORT",
	MagmaFist = "LAVA",
	GlacierFist = "ICE",
	ToxicFist = "TOX",
	VoidFist = "VOID",
	SolarFist = "SUN",
	NebulaFist = "NOVA",
	QuantumFist = "ATOM",
	ChronoFist = "TIME",
	GalaxyFist = "ORBIT",
	InfinityFist = "INF",
	AscendantFist = "ASC",
	CrimsonVanguardFist = "VGD",
	StormbreakerFist = "STORM",
	CelestialTitanFist = "CROWN",
}

function FistVisualBuilder.GetRigProfile(hand)
	local rigName = hand and hand.Name == "Right Arm" and "R6" or "R15"
	local source = RIG_PROFILES[rigName]
	return {
		rig = rigName,
		name = source.name,
		wristYScale = source.wristYScale,
		cuffYScale = source.cuffYScale,
		minTargetRatio = source.minTargetRatio,
		maxTargetRatio = source.maxTargetRatio,
		maxScale = source.maxScale,
		maxCenterOffset = source.maxCenterOffset,
	}
end

function FistVisualBuilder.GetHeroGauntletPresentation(definition)
	definition = definition or {}
	local style = HERO_GAUNTLET_STYLES[definition.style]
	assert(style, ("Unknown hero gauntlet style: %s"):format(tostring(definition.style)))
	local tier = math.max(1, math.floor(tonumber(definition.tier) or 1))
	local iconIdentity = tostring(definition.icon or "")
	assert(iconIdentity ~= "", ("Fist %s is missing a unique icon identity"):format(tostring(definition.name)))
	local catalogMotif = FIST_CATALOG_MOTIFS[iconIdentity]
	assert(catalogMotif ~= nil, ("Fist %s is missing a catalog motif"):format(tostring(definition.name)))
	return {
		version = "HeroGauntletV3",
		style = definition.style,
		tier = tier,
		armorPattern = style.armorPattern,
		plateCount = style.plateCount,
		finCount = style.finCount,
		shopArtKey = style.shopArtKey,
		iconIdentity = iconIdentity,
		signatureFeature = style.signatureFeature,
		catalogMotif = catalogMotif,
		catalogMotifVersion = "PerimeterCatalogMotifV1",
		variantKey = ("%s:T%02d"):format(iconIdentity, tier),
		imageTint = definition.color or Color3.fromRGB(166, 54, 45),
		accent = definition.accent or Color3.fromRGB(255, 197, 45),
	}
end

function FistVisualBuilder.GetHeroGauntletSpec(hand, definition)
	local profile = FistVisualBuilder.GetRigProfile(hand)
	local presentation = FistVisualBuilder.GetHeroGauntletPresentation(definition)
	local unit = hand and math.max(hand.Size.X, hand.Size.Z, 0.2) or 1
	local style = HERO_GAUNTLET_STYLES[presentation.style] or HERO_GAUNTLET_STYLES.Starter
	local scale = style.scale
	local palmSize = Vector3.new(unit * 1.28, unit * 0.92, unit * 1.22) * scale
	local wristY = hand and hand.Size.Y * profile.wristYScale or profile.wristYScale
	local cuffY = hand and hand.Size.Y * profile.cuffYScale or profile.cuffYScale
	local palmZ = hand and -hand.Size.Z * 0.30 or -0.30
	return {
		version = "HeroGauntletV2",
		rig = profile.rig,
		alignmentStandard = profile.name,
		unit = unit,
		scale = scale,
		palmSize = palmSize,
		palmCFrame = CFrame.new(0, wristY, palmZ),
		cuffSize = Vector3.new(unit * 0.64, unit * 1.16, unit * 1.12) * scale,
		cuffCFrame = CFrame.new(0, cuffY, 0) * CFrame.Angles(0, 0, math.rad(90)),
		backPlateSize = Vector3.new(palmSize.X * 0.78, palmSize.Y * 0.23, palmSize.Z * 0.64),
		backPlateCFrame = CFrame.new(0, wristY + palmSize.Y * 0.12, palmZ + palmSize.Z * 0.31),
		knuckleSize = Vector3.new(palmSize.X * 0.235, palmSize.Y * 0.38, palmSize.Z * 0.38),
		knuckleY = wristY - palmSize.Y * 0.08,
		knuckleZ = palmZ - palmSize.Z * 0.45,
		thumbSize = Vector3.new(palmSize.X * 0.31, palmSize.Y * 0.46, palmSize.Z * 0.42),
		thumbCFrame = CFrame.new(
			palmSize.X * 0.49,
			wristY - palmSize.Y * 0.18,
			palmZ - palmSize.Z * 0.12
		) * CFrame.Angles(math.rad(-8), 0, math.rad(-32)),
		coreSize = Vector3.new(palmSize.X * 0.28, palmSize.Y * 0.25, palmSize.Z * 0.16),
		coreCFrame = CFrame.new(0, wristY + palmSize.Y * 0.13, palmZ + palmSize.Z * 0.64),
		maxCenterOffset = profile.maxCenterOffset,
		maxVisualRatio = profile.maxTargetRatio,
		presentation = presentation,
	}
end

-- A catalog model is authored once in wrist-local space for equipment and
-- fixed-camera previews. Positive Y runs from cuff to knuckles; positive Z is
-- the backhand face. The caller owns scaling, welding, effects, and parenting.
-- Keep this first-five list keyed by saved item identity, not by reused style.
local CATALOG_GEOMETRY_VERSION = "SharedClosedFistV1"
local CATALOG_SHAPES = {
	["Starter Glove"] = { style = "Starter", icon = "StarterFist", tier = 1, width = 0.98, height = 0.94, depth = 0.7, cuffWidth = 0.82, cuffHeight = 0.3, silhouette = "LeatherWrap" },
	["Boxing Glove"] = { style = "Boxing", icon = "BoxingFist", tier = 2, width = 1.2, height = 1.08, depth = 0.86, cuffWidth = 0.99, cuffHeight = 0.36, silhouette = "PaddedBoxer" },
	["Iron Knuckle"] = { style = "Iron", icon = "IronFist", tier = 3, width = 1.1, height = 0.98, depth = 0.72, cuffWidth = 0.94, cuffHeight = 0.4, silhouette = "SteelKnuckles" },
	["Thunder Fist"] = { style = "Thunder", icon = "ThunderFist", tier = 4, width = 1.12, height = 1.06, depth = 0.78, cuffWidth = 0.98, cuffHeight = 0.42, silhouette = "TwinRailCore" },
	["Titan Gauntlet"] = { style = "Titan", icon = "TitanFist", tier = 5, width = 1.22, height = 1.06, depth = 0.86, cuffWidth = 1.22, cuffHeight = 0.58, silhouette = "SiegeCuff" },
}

function FistVisualBuilder.GetCatalogSpec(definition)
	if type(definition) ~= "table" then return nil, "invalid_definition" end
	local shape = CATALOG_SHAPES[definition.name]
	if not shape then return nil, "unsupported_catalog_fist" end
	if definition.style ~= shape.style or definition.icon ~= shape.icon
		or tonumber(definition.tier) ~= shape.tier then
		return nil, "catalog_identity_mismatch"
	end
	local presentation = FistVisualBuilder.GetHeroGauntletPresentation(definition)
	local primary = definition.color or Color3.fromRGB(166, 54, 45)
	local accent = definition.accent or Color3.fromRGB(255, 197, 45)
	local material = definition.material or Enum.Material.SmoothPlastic
	local dark = primary:Lerp(Color3.fromRGB(16, 22, 29), 0.64)
	local trim = primary:Lerp(accent, 0.22)
	local width, height, depth = shape.width, shape.height, shape.depth
	local palmY = 0.43 + height * 0.38
	local knuckleY = palmY + height * 0.31
	local parts = {}
	local function add(name, size, position, color, partMaterial, partShape, role, rotation)
		table.insert(parts, {
			name = name,
			size = size,
			cframe = CFrame.new(position) * (rotation or CFrame.identity),
			color = color,
			material = partMaterial,
			shape = partShape or Enum.PartType.Block,
			role = role or name,
		})
	end
	add("Catalog Closed Palm", Vector3.new(width, height, depth),
		Vector3.new(0, palmY, 0), primary, material, Enum.PartType.Ball, "ClosedPalm")
	add("Catalog Wrist Cuff", Vector3.new(shape.cuffHeight, shape.cuffWidth, depth * 0.94),
		Vector3.new(0, 0.19, 0), dark, material, Enum.PartType.Cylinder, "WristCuff",
		CFrame.Angles(0, 0, math.rad(90)))
	add("Catalog Backhand Guard", Vector3.new(width * (shape.tier <= 2 and 0.68 or 0.78), height * (shape.tier <= 2 and 0.46 or shape.style == "Iron" and 0.48 or 0.59), depth * (shape.tier <= 2 and 0.16 or 0.3)),
		Vector3.new(0, palmY + height * 0.02, depth * (shape.tier <= 2 and 0.4 or 0.38)), shape.tier <= 2 and primary:Lerp(accent, 0.04) or trim,
		shape.tier >= 3 and Enum.Material.Metal or material,
		shape.tier >= 3 and Enum.PartType.Block or Enum.PartType.Ball, "BackhandPlate")
	for finger = 1, 4 do
		local x = (finger - 2.5) * width * 0.225
		-- Distal knuckles and curled finger pads describe a closed hand from both
		-- front and back; no long fingers, blades, or detached decorative wedges.
		add("Catalog Knuckle " .. finger, Vector3.new(width * (shape.style == "Iron" and 0.205 or 0.26), height * 0.3, depth * 0.62),
			Vector3.new(x, knuckleY, -depth * 0.025),
			shape.style == "Iron" and accent:Lerp(primary, 0.58) or primary,
			shape.tier >= 3 and Enum.Material.Metal or material,
			shape.style == "Iron" and Enum.PartType.Block or Enum.PartType.Ball, "ClosedKnuckle")
		add("Catalog Curled Finger " .. finger, Vector3.new(width * 0.235, height * 0.39, depth * 0.35),
			Vector3.new(x, palmY + height * 0.035, -depth * 0.38),
			primary:Lerp(dark, 0.18), material, Enum.PartType.Ball, "CurledFinger")
	end
	add("Catalog Folded Thumb", Vector3.new(width * 0.3, height * 0.5, depth * 0.54),
		Vector3.new(width * 0.43, palmY - height * 0.18, -depth * 0.24),
		primary, material, Enum.PartType.Ball, "FoldedThumb", CFrame.Angles(0, 0, math.rad(-24)))

	if shape.style == "Starter" then
		for band = 1, 2 do
			add("Starter Leather Wrap " .. band, Vector3.new(width * 0.74, 0.105, depth * 0.25),
				Vector3.new(0, palmY - height * (0.14 + band * 0.15), depth * 0.32),
				band == 1 and accent:Lerp(primary, 0.3) or dark,
				material, Enum.PartType.Block, "LeatherWrap")
		end
	elseif shape.style == "Boxing" then
		add("Boxing Padded Crown", Vector3.new(width * 0.93, height * 0.4, depth * 0.8),
			Vector3.new(0, knuckleY - height * 0.045, depth * 0.14),
			primary:Lerp(accent, 0.09), material, Enum.PartType.Ball, "PaddedCrown")
		add("Boxing Wrist Strap", Vector3.new(shape.cuffWidth * 0.94, 0.19, 0.16),
			Vector3.new(0, 0.23, depth * 0.43), accent, material, Enum.PartType.Block, "WristStrap")
		add("Boxing Strap Fastener", Vector3.new(0.2, 0.22, 0.065),
			Vector3.new(-shape.cuffWidth * 0.25, 0.23, depth * 0.54),
			dark, Enum.Material.SmoothPlastic, Enum.PartType.Block, "StrapFastener")
	elseif shape.style == "Iron" then
		for side = -1, 1, 2 do
			add("Iron Side Guard " .. side, Vector3.new(0.14, height * 0.62, depth * 0.64),
				Vector3.new(side * width * 0.47, palmY, depth * 0.02),
				dark, Enum.Material.Metal, Enum.PartType.Block, "SteelSideGuard")
			add("Iron Backhand Rivet " .. side, Vector3.new(0.13, 0.13, 0.09),
				Vector3.new(side * width * 0.26, palmY + height * 0.16, depth * 0.56),
				accent:Lerp(Color3.fromRGB(185, 203, 209), 0.55),
				Enum.Material.Metal, Enum.PartType.Ball, "ArmorRivet")
		end
	elseif shape.style == "Thunder" then
		for side = -1, 1, 2 do
			add("Thunder Backhand Rail " .. side, Vector3.new(0.15, height * 0.82, 0.14),
				Vector3.new(side * width * 0.32, palmY + height * 0.04, depth * 0.51),
				dark, Enum.Material.Metal, Enum.PartType.Block, "BackhandRail")
			add("Thunder Rail Inset " .. side, Vector3.new(0.055, height * 0.65, 0.045),
				Vector3.new(side * width * 0.32, palmY + height * 0.04, depth * 0.61),
				accent, Enum.Material.Neon, Enum.PartType.Block, "RailInset")
		end
		add("Thunder Core Housing", Vector3.new(0.46, 0.44, 0.16),
			Vector3.new(0, palmY, depth * 0.5), dark,
			Enum.Material.Metal, Enum.PartType.Block, "CoreHousing")
		add("Catalog Energy Core", Vector3.new(0.24, 0.27, 0.08),
			Vector3.new(0, palmY, depth * 0.63), accent,
			Enum.Material.Neon, Enum.PartType.Ball, "EnergyCore")
	elseif shape.style == "Titan" then
		for side = -1, 1, 2 do
			add("Titan Siege Guard " .. side, Vector3.new(0.22, height * 0.71, depth * 0.63),
				Vector3.new(side * width * 0.47, palmY - height * 0.025, depth * 0.13),
				dark, Enum.Material.Metal, Enum.PartType.Block, "SiegeSideGuard")
			add("Titan Cuff Reinforcement " .. side, Vector3.new(0.23, 0.47, depth * 0.62),
				Vector3.new(side * shape.cuffWidth * 0.4, 0.2, depth * 0.04),
				primary, Enum.Material.Metal, Enum.PartType.Block, "CuffReinforcement")
		end
		add("Titan Backhand Containment", Vector3.new(width * 0.61, height * 0.54, 0.17),
			Vector3.new(0, palmY + height * 0.045, depth * 0.53),
			dark, Enum.Material.Metal, Enum.PartType.Block, "CoreHousing")
		add("Catalog Energy Core", Vector3.new(0.3, 0.3, 0.08),
			Vector3.new(0, palmY + height * 0.045, depth * 0.66), accent,
			Enum.Material.Neon, Enum.PartType.Block, "EnergyCore",
			CFrame.Angles(0, 0, math.rad(45)))
	end
	return {
		version = CATALOG_GEOMETRY_VERSION,
		name = definition.name,
		displayName = definition.displayName or definition.name,
		tier = shape.tier,
		style = shape.style,
		silhouette = shape.silhouette,
		wristOrigin = CFrame.identity,
		gripAxis = "LocalYToDistalForearm",
		previewDirection = Vector3.new(0.65, 0.28, 1),
		referenceHandWidth = 1,
		partBudget = 28,
		parts = parts,
		presentation = presentation,
	}
end

function FistVisualBuilder.BuildCatalogModel(definition)
	local spec, reason = FistVisualBuilder.GetCatalogSpec(definition)
	if not spec then return nil, reason end
	assert(#spec.parts >= 12 and #spec.parts <= spec.partBudget, "catalog fist exceeds visual part budget")
	local model = Instance.new("Model")
	model.Name = "Catalog Fist " .. spec.name
	-- No PrimaryPart: WorldPivot keeps the attachment origin at the wrist rather
	-- than moving it to the palm or to a bounding-box center when cloned.
	model.WorldPivot = spec.wristOrigin
	for _, item in ipairs(spec.parts) do
		local part = Instance.new("Part")
		part.Name = item.name
		part.Size = item.size
		part.CFrame = item.cframe
		part.Color = item.color
		part.Material = item.material
		part.Shape = item.shape
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
		part.CastShadow = false
		part:SetAttribute("FistShape", item.role)
		part.Parent = model
	end
	-- Compute from every final part, including cuffs and guards. Consumers must
	-- recompute after scaling/attachment before reporting a rig fit as verified.
	local boundsCFrame, boundsSize = model:GetBoundingBox()
	model:SetAttribute("FistCatalogVisual", true)
	model:SetAttribute("FistVisualKey", spec.name)
	model:SetAttribute("CatalogGeometryVersion", spec.version)
	model:SetAttribute("CatalogSilhouette", spec.silhouette)
	model:SetAttribute("DisplayName", spec.displayName)
	model:SetAttribute("Tier", spec.tier)
	model:SetAttribute("FistStyle", spec.style)
	model:SetAttribute("ClosedFist", true)
	model:SetAttribute("KnuckleCount", 4)
	model:SetAttribute("HasFoldedThumb", true)
	model:SetAttribute("HasWristCuff", true)
	model:SetAttribute("HasBackhandPlate", true)
	model:SetAttribute("HasEnergyCore", spec.tier >= 4)
	model:SetAttribute("VisualPartCount", #spec.parts)
	model:SetAttribute("VisualPartBudget", spec.partBudget)
	model:SetAttribute("WithinVisualPartBudget", #spec.parts <= spec.partBudget)
	model:SetAttribute("GripAxis", spec.gripAxis)
	model:SetAttribute("CatalogReferenceHandWidth", spec.referenceHandWidth)
	model:SetAttribute("CatalogBoundsCenter", boundsCFrame.Position)
	model:SetAttribute("CatalogBoundsSize", boundsSize)
	model:SetAttribute("CatalogGeometryBoundsFinal", true)
	model:SetAttribute("CatalogPreviewHasEffects", false)
	model:SetAttribute("IconIdentity", spec.presentation.iconIdentity)
	model:SetAttribute("FistVariantKey", spec.presentation.variantKey)
	model:SetAttribute("ShopArtVariant", spec.presentation.shopArtKey)
	FistVisualBuilder.SanitizeVisual(model)
	return model, spec
end

function FistVisualBuilder.ComputeImportedScale(sourceSize, hand, styleRatio)
	local profile = FistVisualBuilder.GetRigProfile(hand)
	local largestSource = math.max(sourceSize.X, sourceSize.Y, sourceSize.Z, 0.01)
	local handReference = hand and (profile.rig == "R6" and hand.Size.X or math.max(hand.Size.X, hand.Size.Y, hand.Size.Z)) or 1
	local boundedRatio = math.clamp(
		tonumber(styleRatio) or profile.minTargetRatio,
		profile.minTargetRatio,
		profile.maxTargetRatio
	)
	local scale = math.clamp((handReference * boundedRatio) / largestSource, 0.25, profile.maxScale)
	return scale, profile, boundedRatio
end

function FistVisualBuilder.EffectiveVisualSize(root)
	local baseSize
	if root:IsA("Model") then
		baseSize = select(2, root:GetBoundingBox())
	elseif root:IsA("BasePart") then
		baseSize = root.Size
	else
		return Vector3.new(1, 1, 1)
	end
	local maxX, maxY, maxZ = baseSize.X, baseSize.Y, baseSize.Z
	local candidates = root:IsA("BasePart") and { root } or root:GetDescendants()
	for _, descendant in ipairs(candidates) do
		if descendant:IsA("BasePart") then
			local size = descendant.Size
			local mesh = descendant:FindFirstChildWhichIsA("SpecialMesh")
			if mesh then
				size = Vector3.new(
					size.X * math.abs(mesh.Scale.X),
					size.Y * math.abs(mesh.Scale.Y),
					size.Z * math.abs(mesh.Scale.Z)
				)
			end
			maxX = math.max(maxX, size.X)
			maxY = math.max(maxY, size.Y)
			maxZ = math.max(maxZ, size.Z)
		end
	end
	return Vector3.new(maxX, maxY, maxZ)
end

local SANITIZER_VERSION = "StrictVisualAllowlistV1"
local ALLOWED_VISUAL_CLASSES = {
	Model = true,
	Folder = true,
	Part = true,
	WedgePart = true,
	CornerWedgePart = true,
	MeshPart = true,
	UnionOperation = true,
	TrussPart = true,
	Attachment = true,
	Bone = true,
	Decal = true,
	Texture = true,
	SurfaceAppearance = true,
	ParticleEmitter = true,
	Beam = true,
	Trail = true,
	SpecialMesh = true,
	BlockMesh = true,
	CylinderMesh = true,
	PointLight = true,
	SpotLight = true,
	SurfaceLight = true,
	Highlight = true,
	Shirt = true,
	Pants = true,
	ShirtGraphic = true,
	BodyColors = true,
	CharacterMesh = true,
	WrapLayer = true,
	WrapTarget = true,
}

local function isAllowedVisual(instance)
	return instance ~= nil and ALLOWED_VISUAL_CLASSES[instance.ClassName] == true
end

local function configureVisualInstance(instance)
	if instance:IsA("BasePart") then
		instance.Anchored = true
		instance.CanCollide = false
		instance.CanTouch = false
		instance.CanQuery = false
		instance.Massless = true
		instance.AssemblyLinearVelocity = Vector3.zero
		instance.AssemblyAngularVelocity = Vector3.zero
	elseif instance:IsA("ParticleEmitter") then
		instance.Rate = math.min(instance.Rate, 24)
	end
	instance:SetAttribute("SanitizedVisualOnly", true)
	instance:SetAttribute("VisualSanitizerVerified", true)
	instance:SetAttribute("VisualSanitizerVersion", SANITIZER_VERSION)
end

local function sanitizeVisualChildren(parent)
	local removed = 0
	for _, child in ipairs(parent:GetChildren()) do
		if isAllowedVisual(child) then
			removed += sanitizeVisualChildren(child)
			configureVisualInstance(child)
		else
			-- Creator Store tools and accessories sometimes wrap a valid mesh in a
			-- behavior-capable container. Preserve only directly contained,
			-- allowlisted visuals and discard the wrapper plus everything else.
			if child:IsA("Tool") or child:IsA("Accoutrement") then
				for _, visualChild in ipairs(child:GetChildren()) do
					if isAllowedVisual(visualChild) then
						visualChild.Parent = parent
						removed += sanitizeVisualChildren(visualChild)
						configureVisualInstance(visualChild)
					end
				end
			end
			child:Destroy()
			removed += 1
		end
	end
	return removed
end

function FistVisualBuilder.AssertSanitizedVisual(root)
	assert(root ~= nil and isAllowedVisual(root), "visual root must be an allowlisted visual instance")
	assert(root:GetAttribute("SanitizedVisualOnly") == true, "visual root is missing sanitized attestation")
	assert(root:GetAttribute("VisualSanitizerVerified") == true, "visual root sanitizer was not verified")
	assert(root:GetAttribute("VisualSanitizerVersion") == SANITIZER_VERSION, "visual root sanitizer version is stale")
	if root:IsA("BasePart") then
		assert(root.Anchored, "sanitized visual root part must remain anchored")
		assert(not root.CanCollide, "sanitized visual root part must not collide")
		assert(not root.CanTouch, "sanitized visual root part must not produce touch events")
		assert(not root.CanQuery, "sanitized visual root part must not participate in queries")
	end
	for _, descendant in ipairs(root:GetDescendants()) do
		assert(isAllowedVisual(descendant), ("disallowed visual descendant: %s"):format(descendant.ClassName))
		assert(descendant:GetAttribute("SanitizedVisualOnly") == true, "visual descendant is missing sanitized attestation")
		assert(descendant:GetAttribute("VisualSanitizerVerified") == true, "visual descendant sanitizer was not verified")
		assert(descendant:GetAttribute("VisualSanitizerVersion") == SANITIZER_VERSION, "visual descendant sanitizer version is stale")
		if descendant:IsA("BasePart") then
			assert(descendant.Anchored, "sanitized visual part must remain anchored")
			assert(not descendant.CanCollide, "sanitized visual part must not collide")
			assert(not descendant.CanTouch, "sanitized visual part must not produce touch events")
			assert(not descendant.CanQuery, "sanitized visual part must not participate in queries")
		end
	end
	return true
end

function FistVisualBuilder.IsSanitizedVisual(root)
	if root == nil
		or root:GetAttribute("SanitizedVisualOnly") ~= true
		or root:GetAttribute("VisualSanitizerVerified") ~= true
		or root:GetAttribute("VisualSanitizerVersion") ~= SANITIZER_VERSION then
		return false
	end
	local ok = pcall(FistVisualBuilder.AssertSanitizedVisual, root)
	return ok
end

function FistVisualBuilder.SanitizeVisual(root)
	assert(root ~= nil and isAllowedVisual(root), "visual root must be an allowlisted visual instance")
	local removed = sanitizeVisualChildren(root)
	configureVisualInstance(root)
	root:SetAttribute("UnsafeDescendantsRemoved", removed)
	FistVisualBuilder.AssertSanitizedVisual(root)
	return root, removed
end

local function createArmoredClosedFist(parent)
	local model = Instance.new("Model")
	model.Name = "CreatorStore_ArmoredClosedHeroFist"
	model:SetAttribute("AssetId", ASSET_ID)
	model:SetAttribute("Creator", ASSET_CREATOR)
	model:SetAttribute("GripStandard", "ArmoredClosedFist")
	model:SetAttribute("SanitizedVisualOnly", true)

	local part = Instance.new("Part")
	part.Name = "FistMesh"
	part.Size = Vector3.new(1.78, 2.68, 1.67)
	part.Color = Color3.fromRGB(163, 162, 165)
	part.Material = Enum.Material.Plastic
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Parent = model

	local mesh = Instance.new("SpecialMesh")
	mesh.Name = "Mesh"
	mesh.MeshType = Enum.MeshType.FileMesh
	mesh.MeshId = FIST_MESH_ID
	mesh.TextureId = FIST_TEXTURE_ID
	mesh.Scale = Vector3.new(2, 2, 3)
	mesh.Parent = part

	model.PrimaryPart = part
	model.Parent = parent
	return FistVisualBuilder.SanitizeVisual(model)
end

function FistVisualBuilder.Ensure()
	local folder = ReplicatedStorage:FindFirstChild("PunchWallFistAssets")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "PunchWallFistAssets"
		folder.Parent = ReplicatedStorage
	end
	local fist = folder:FindFirstChild("CreatorStore_ArmoredClosedHeroFist")
	if not fist or not fist:IsA("Model") then
		if fist then fist:Destroy() end
		fist = createArmoredClosedFist(folder)
	else
		FistVisualBuilder.SanitizeVisual(fist)
		fist:SetAttribute("AssetId", ASSET_ID)
		fist:SetAttribute("Creator", ASSET_CREATOR)
		fist:SetAttribute("GripStandard", "ArmoredClosedFist")
	end

	FistVisualBuilder.SanitizeVisual(folder)
	return folder, fist
end

return FistVisualBuilder
