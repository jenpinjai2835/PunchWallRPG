local inputPlace, outputPlace, phoenixFile, wyvernFile, guardianFile = ...

assert(type(inputPlace) == "string" and inputPlace ~= "", "input place is required")
assert(type(outputPlace) == "string" and outputPlace ~= "", "output place is required")
assert(inputPlace ~= outputPlace, "input and output place must differ")
-- rbxmk 0.9.1 silently drops modern Content<uri> values during whole-place
-- serialization. Refuse every XML input that would lose a URI, including newly
-- imported assets, before reading a DataModel or writing any output.
for _, inputPath in ipairs({inputPlace, phoenixFile, wyvernFile, guardianFile}) do
	assert(type(inputPath) == "string" and inputPath ~= "", "every asset path is required")
	local raw = fs.read(inputPath, "txt")
	if raw:find("<roblox", 1, true) then
		for content in raw:gmatch("<Content[^>]*>(.-)</Content>") do
			for uri in content:gmatch("<uri[^>]*>(.-)</uri>") do
				assert(not uri:find("%S"), "Legacy rbxmk importer cannot preserve Content URI in " .. inputPath .. "; use native Studio import or the preserving premium-template repair pipeline")
			end
		end
	end
end
local strictBuilder = rbxmk.runFile(
	path.join(path.expand('$sd'), 'load-production-visual-sanitizer.rbxmk.lua'),
	path.join(path.expand('$sd'), '../../punch-wall-rpg/src/shared/FistVisualBuilder.lua')
)

local place = fs.read(inputPlace, "rbxlx")
local replicatedStorage = assert(place:FindFirstChild("ReplicatedStorage"), "ReplicatedStorage missing")
local external = assert(
	replicatedStorage:FindFirstChild("PunchWallExternalAssets"),
	"PunchWallExternalAssets missing"
)

local forbiddenClasses = {
	Script = true,
	LocalScript = true,
	ModuleScript = true,
	Sound = true,
	Tool = true,
	RemoteEvent = true,
	RemoteFunction = true,
	UnreliableRemoteEvent = true,
	BindableEvent = true,
	BindableFunction = true,
	ClickDetector = true,
	ProximityPrompt = true,
	Humanoid = true,
	AnimationController = true,
	Animator = true,
	Camera = true,
}

local function isForbidden(instance)
	return forbiddenClasses[instance.ClassName] == true
end

local basePartClasses = {
	Part = true,
	MeshPart = true,
	UnionOperation = true,
	WedgePart = true,
	CornerWedgePart = true,
	TrussPart = true,
	Seat = true,
	VehicleSeat = true,
	SpawnLocation = true,
}

local lightClasses = {
	PointLight = true,
	SpotLight = true,
	SurfaceLight = true,
}

local function sanitize(model)
	strictBuilder.PrepareAttributesForRbxmk(model)
	strictBuilder.SanitizeVisual(model)
	local descendants = model:GetDescendants()
	for index = #descendants, 1, -1 do
		local descendant = descendants[index]
		if isForbidden(descendant) then
			descendant:Destroy()
		end
	end

	local parts = 0
	local effects = 0
	local unsafe = 0
	for _, descendant in ipairs(model:GetDescendants()) do
		if isForbidden(descendant) then
			unsafe = unsafe + 1
		elseif basePartClasses[descendant.ClassName] then
			parts = parts + 1
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
			-- NPC-style Creator Store pets can have an invisible root whose
			-- authoring size is much larger than the creature. The release clone
			-- is visual-only, so collapse that helper before bounds are measured.
			if descendant.Name == "HumanoidRootPart" and descendant.Transparency >= 0.99 then
				descendant.Size = Vector3.new(0.1, 0.1, 0.1)
			end
		elseif descendant.ClassName == "ParticleEmitter" then
			effects = effects + 1
			descendant.Rate = 8
		elseif descendant.ClassName == "Trail" then
			effects = effects + 1
			descendant.Lifetime = 0.45
		elseif descendant.ClassName == "Beam" then
			effects = effects + 1
			descendant.Segments = 8
		elseif lightClasses[descendant.ClassName] then
			effects = effects + 1
			descendant.Shadows = false
			descendant.Range = 8
			descendant.Brightness = 2
		end
	end
	assert(parts >= 1, "detailed Premium model has no BasePart")
	assert(unsafe == 0, "unsafe descendant survived sanitization")
	assert(strictBuilder.IsSanitizedVisual(model), "strict production visual attestation failed")
	return parts, effects
end

local function loadVisual(path, format)
	assert(type(path) == "string" and path ~= "", "Premium asset path is required")
	local root = fs.read(path, format)
	for _, child in ipairs(root:GetChildren()) do
		if child.ClassName == "Model" then
			child.Parent = nil
			-- Imported Creator Store files commonly serialize an empty
			-- AttributesSerialize buffer that rbxmk correctly treats as malformed.
			-- Keep the untouched visual tree below a clean wrapper so release
			-- attestations are encoded on a valid, tool-created Model.
			local wrapper = Instance.new("Model")
			child.Name = "DetailedVisual"
			child.Parent = wrapper
			return wrapper
		end
	end
	error("Premium asset has no root Model: " .. path)
end

for oldName, migration in pairs({
	Sanitized_CrimsonPhoenixPet = {
		name = "Sanitized_EnragedPhoenixPet",
		definition = "Thunder Roc",
		sourceModel = "Enraged Phoenix",
	},
	Sanitized_StormWyvernPet = {
		name = "Sanitized_ElectraHydraPet",
		definition = "Frost Hydra",
		sourceModel = "Electra Hydra",
	},
	Sanitized_CelestialGuardianPet = {
		name = "Sanitized_MythicRadiantOnePet",
		definition = "Solar Kirin",
		sourceModel = "Mythic Radiant One",
	},
}) do
	local old = external:FindFirstChild(oldName)
	if old then
		local existing = external:FindFirstChild(migration.name)
		if existing then
			existing:Destroy()
		end
		old.Name = migration.name
		old:SetAttribute("PetDefinitionName", migration.definition)
		old:SetAttribute("SourcePackModelName", migration.sourceModel)
	end
end

local mappings = {
	{
		definition = "Crimson Phoenix",
		template = "Sanitized_CrimsonPhoenixPet",
		asset = 86478691482535,
		creator = "IAmASwedishMale",
		file = phoenixFile,
		format = "rbxm",
	},
	{
		definition = "Storm Wyvern",
		template = "Sanitized_StormWyvernPet",
		asset = 83562531232957,
		creator = "XzG0ldeneJGlitchQJCy",
		file = wyvernFile,
		format = "rbxmx",
	},
	{
		definition = "Celestial Guardian",
		template = "Sanitized_CelestialGuardianPet",
		asset = 121956330907081,
		creator = "SirRioter",
		file = guardianFile,
		format = "rbxm",
	},
}

for _, mapping in ipairs(mappings) do
	local existing = external:FindFirstChild(mapping.template)
	if existing then
		existing:Destroy()
	end
	local model = loadVisual(mapping.file, mapping.format)
	model.Name = mapping.template
	local parts, effects = sanitize(model)
	model:SetAttribute("AssetId", mapping.asset)
	model:SetAttribute("CreatorStoreAssetId", mapping.asset)
	model:SetAttribute("CreatorStorePackAssetId", tostring(mapping.asset))
	model:SetAttribute("CreatorStoreCreator", mapping.creator)
	model:SetAttribute("PetDefinitionName", mapping.definition)
	model:SetAttribute("PetRarity", "Premium")
	model:SetAttribute("VisualPartCount", parts)
	model:SetAttribute("VisualEffectCount", effects)
	model:SetAttribute("TemplateVisualAttested", true)
	model:SetAttribute("PreloadedOnly", false)
	model:SetAttribute("TemplateAssetMode", "DetailedStandaloneAsset")
	model:SetAttribute("TemplateAssetFetchMode", "AuthenticatedChromeDownloadThenSanitizedRbxmkEmbed")
	model:SetAttribute("SourceFallback", false)
	model.Parent = external
	print(mapping.definition, mapping.asset, parts, effects)
end

external:SetAttribute("DetailedPremiumPetTemplateCount", #mappings)
external:SetAttribute("DetailedPremiumPetVersion", "OriginalCreatorStoreModelsV2RigBounds")
fs.write(outputPlace, place, "rbxlx")
print("wrote", outputPlace)
