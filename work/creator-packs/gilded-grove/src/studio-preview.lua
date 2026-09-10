-- Local authoring/QA command, not a runtime script or uploaded asset.
assert(game.PlaceId == 0, "Use an isolated unsaved local place")
local data = game:GetService("HttpService"):JSONDecode([==[__ASSET_JSON__]==])
local service = game:GetService("AssetService")
local pack = workspace:FindFirstChild("GildedGrovePreview")
if not pack then
    pack = Instance.new("Folder")
    pack.Name = "GildedGrovePreview"
    pack:SetAttribute("LocalGeometryPreview", true)
    pack.Parent = workspace
end
assert(pack:GetAttribute("LocalGeometryPreview"), "Unexpected preview owner")
local old = pack:FindFirstChild(data.id)
if old then old:Destroy() end
local model = Instance.new("Model")
model.Name = data.id
model:SetAttribute("SourceGLBSHA256", data.source_sha256)
model:SetAttribute("Triangles", data.expected_triangles)
model:SetAttribute("PreviewOnly", true)
local offset = Vector3.new((data.index % 6 - 2.5) * 8, 0, -(math.floor(data.index / 6) - 1.5) * 8)
local total = 0
local function vector(v) return Vector3.new(v[1], v[2], v[3]) end
for _, source in data.meshes do
    local mesh = assert(service:CreateEditableMesh(), "EditableMesh allocation failed")
    local vertices, colors = {}, {}
    local lo,hi = Vector3.new(math.huge,math.huge,math.huge),Vector3.new(-math.huge,-math.huge,-math.huge)
    for _, v in source.vertices do lo=lo:Min(vector(v));hi=hi:Max(vector(v)) end
    local center=(lo+hi)/2
    -- EditableMesh renders its raw coordinates about the part origin. Center
    -- every role explicitly so separated lids retain their source placement.
    for _, v in source.vertices do table.insert(vertices, mesh:AddVertex(vector(v)-center)) end
    for _, code in data.palette do
        table.insert(colors, mesh:AddColor(Color3.fromHex(code), 1))
    end
    for _, f in source.faces do
        local face = mesh:AddTriangle(vertices[f[1]], vertices[f[2]], vertices[f[3]])
        local a,b,c = vector(source.vertices[f[1]]),vector(source.vertices[f[2]]),vector(source.vertices[f[3]])
        local cross = (b-a):Cross(c-a)
        assert(cross.Magnitude > 1e-9, "Degenerate triangle")
        local n = mesh:AddNormal(cross.Unit)
        mesh:SetFaceNormals(face, {n,n,n})
        local color = colors[f[4]]
        mesh:SetFaceColors(face, {color,color,color})
    end
    assert(mesh:GetCenter().Magnitude < 0.0001, "Mesh not centered")
    local part = service:CreateMeshPartAsync(Content.fromObject(mesh))
    part.Name = source.name:match("__(.+)$") or source.name
    part.Size = mesh:GetSize()
    part.CFrame = CFrame.new(offset + center)
    part.PivotOffset = CFrame.new(vector(source.pivot) - center)
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.Color = Color3.new(1,1,1)
    part.Material = Enum.Material.SmoothPlastic
    part:SetAttribute("Triangles", #source.faces)
    assert(#mesh:GetFaces() == #source.faces, "Triangle loss")
    assert(#mesh:GetVertices() == #source.vertices, "Vertex loss")
    part.Parent = model
    total += #source.faces
end
model.WorldPivot = CFrame.new(offset)
model.Parent = pack
assert(total == data.expected_triangles, "Asset triangle mismatch")
return game:GetService("HttpService"):JSONEncode({status="PASS",id=data.id,mesh_count=#data.meshes,triangles=total,source_sha256=data.source_sha256})
