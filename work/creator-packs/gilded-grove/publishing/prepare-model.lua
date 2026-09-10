-- Native authoring helper shared by local QA and the final upload route.
-- Importer data is read from our uploaded package; no gameplay scripts run.
local manifest = game:GetService('HttpService'):JSONDecode([==[__MANIFEST_JSON__]==])
local source = __SOURCE_EXPRESSION__
-- LoadAssetAsync adds an outer wrapper whose pivot is the bounding-box center.
-- Use the authored aggregate origin so geometry stays grounded at each prop pivot.
local authoredRoot = assert(source:FindFirstChild('GildedGrove_MerchantLoot_24Models_3Palettes',true),'Missing authored origin')
local toOriginal = authoredRoot:GetPivot():Inverse()
local orientation = CFrame.Angles(0, math.pi, 0)
local result = Instance.new('Model')
result.Name = 'Gilded Grove - Merchant & Loot'
result:SetAttribute('UniqueBaseModels',24)
result:SetAttribute('PaletteVariants',3)
result:SetAttribute('TrianglesPerPalette',25216)
result:SetAttribute('VisualModelsOnly',true)
local variants = {'Teal','Ember','Amethyst'}
local function converted(v) return Vector3.new(v[1],v[3],-v[2]) end
local partCount = 0
for bank, variant in variants do
    local palette = Instance.new('Model')
    palette.Name = variant
    palette.Parent = result
    local bankX = (bank-2)*36
    for index, asset in manifest.assets do
        local base = Vector3.new(bankX+((index-1)%4-1.5)*8,0,-(math.floor((index-1)/4)-2.5)*8)
        local prop = Instance.new('Model')
        prop.Name = asset.id
        prop:SetAttribute('Description',asset.description)
        prop:SetAttribute('Triangles',asset.triangles)
        prop:SetAttribute('Palette',variant)
        prop.Parent = palette
        for _, spec in asset.meshes do
            local role = assert(spec.name:match('__(.+)$'))
            local importedRole = assert(source:FindFirstChild(variant..'__'..spec.name,true),'Missing uploaded role')
            local imported = assert(importedRole:FindFirstChildWhichIsA('MeshPart',true),'Missing uploaded mesh')
            assert(imported.MeshContent.SourceType==Enum.ContentSourceType.Uri,'Transient mesh')
            local part = imported:Clone()
            part.Name = role
            part.CFrame = orientation*toOriginal*imported.CFrame
            part.Anchored = true
            part.CanCollide = false
            part.CanTouch = false
            part.Material = Enum.Material.SmoothPlastic
            part.Color = Color3.new(1,1,1)
            part.PivotOffset = part.CFrame:ToObjectSpace(CFrame.new(base+converted(spec.pivot)))
            part:SetAttribute('Triangles',spec.triangles)
            part.Parent = prop
            partCount+=1
        end
        prop.WorldPivot = CFrame.new(base)
        local size = prop:GetExtentsSize()
        assert((size-Vector3.new(asset.size[1],asset.size[3],asset.size[2])).Magnitude<0.005,'Imported size mismatch: '..asset.id)
    end
    palette.WorldPivot = CFrame.new(bankX,0,0)
end
result.WorldPivot = CFrame.identity
assert(partCount==99,'Wrong native part count')
for _, obj in result:GetDescendants() do
    assert(obj:IsA('Model') or obj:IsA('MeshPart'),'Unexpected product instance')
end
__FINAL_ACTION__
