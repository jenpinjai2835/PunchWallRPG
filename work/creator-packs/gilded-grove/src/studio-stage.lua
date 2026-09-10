assert(game.PlaceId == 0, "Only the isolated local preview place")
local pack = assert(workspace:FindFirstChild("GildedGrovePreview"))
assert(pack:GetAttribute("LocalGeometryPreview"))
local old = workspace:FindFirstChild("GildedGroveStage")
if old then old:Destroy() end
local stage = Instance.new("Folder")
stage.Name = "GildedGroveStage"
stage.Parent = workspace
local probe = workspace:FindFirstChild("GildedGroveMeshProbe")
if probe then probe:Destroy() end
local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
if spawn then spawn.Position = Vector3.new(0, 0.5, 80) end
local base = workspace:FindFirstChild("Baseplate")
if base then base.Transparency=1 end
local floor = Instance.new("Part")
floor.Name="PreviewFloor"
floor.Size=Vector3.new(200,0.3,200)
floor.Position=Vector3.new(0,-0.42,0)
floor.Color=Color3.fromRGB(44,62,68)
floor.Material=Enum.Material.SmoothPlastic
floor.Anchored=true
floor.Parent=stage
local light = game:GetService("Lighting")
light.ClockTime=10
light.Brightness=2
light.Ambient=Color3.fromRGB(145,145,145)
light.OutdoorAmbient=Color3.fromRGB(145,145,145)
workspace.CurrentCamera.FieldOfView = 40
workspace.CurrentCamera.CFrame = CFrame.lookAt(Vector3.new(28,36,48),Vector3.new(0,1,0))
workspace.CurrentCamera.Focus = CFrame.new(0,1,0)
local count,parts,tris=0,0,0
for _,model in pack:GetChildren() do
    count += 1
    local pivot=model:GetPivot().Position
    local slab=Instance.new("Part")
    slab.Name=model.Name.."_Display"
    slab.Size=Vector3.new(7.35,0.25,7.35)
    slab.Position=pivot+Vector3.new(0,-0.145,0)
    slab.Color=Color3.fromRGB(213,205,186)
    slab.Material=Enum.Material.SmoothPlastic
    slab.Anchored=true
    slab.Parent=stage
    for _,part in model:GetDescendants() do
        assert(not part:IsA("LuaSourceContainer"), "Unexpected script")
        if part:IsA("BasePart") then
            assert(part:IsA("MeshPart") and part.Anchored and not part.CanCollide and not part.CanTouch)
            assert(part.Size.X>0 and part.Size.Y>0 and part.Size.Z>0)
            parts+=1;tris+=part:GetAttribute("Triangles")
        end
    end
end
assert(count==24, "Wrong model count")
return game:GetService("HttpService"):JSONEncode({status="PASS",models=count,mesh_parts=parts,triangles=tris,viewport={workspace.CurrentCamera.ViewportSize.X,workspace.CurrentCamera.ViewportSize.Y},studio_version=version(),method="local EditableMesh preview; no uploaded assets"})
