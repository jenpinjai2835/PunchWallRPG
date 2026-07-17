local FistVisualBuilder = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ASSET_ID = "1622087753"
local ASSET_CREATOR = "Penguin9805"
local FIST_MESH_ID = "rbxassetid://65322375"
local FIST_TEXTURE_ID = "rbxassetid://65322423"

local function removeUnsafeDescendants(root)
	local removed = 0
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("LuaSourceContainer")
			or descendant:IsA("ProximityPrompt")
			or descendant:IsA("ClickDetector")
			or descendant:IsA("TouchTransmitter") then
			descendant:Destroy()
			removed += 1
		end
	end
	return removed
end

local function sanitizeVisual(root)
	local removed = removeUnsafeDescendants(root)
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		end
	end
	root:SetAttribute("SanitizedVisualOnly", true)
	root:SetAttribute("UnsafeDescendantsRemoved", removed)
	return root
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
	return sanitizeVisual(model)
end

function FistVisualBuilder.Ensure()
	local folder = ReplicatedStorage:FindFirstChild("PunchWallFistAssets")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "PunchWallFistAssets"
		folder.Parent = ReplicatedStorage
	end
	folder:SetAttribute("SanitizedVisualOnly", true)

	local fist = folder:FindFirstChild("CreatorStore_ArmoredClosedHeroFist")
	if not fist or not fist:IsA("Model") then
		if fist then fist:Destroy() end
		fist = createArmoredClosedFist(folder)
	else
		sanitizeVisual(fist)
		fist:SetAttribute("AssetId", ASSET_ID)
		fist:SetAttribute("Creator", ASSET_CREATOR)
		fist:SetAttribute("GripStandard", "ArmoredClosedFist")
	end

	return folder, fist
end

return FistVisualBuilder
