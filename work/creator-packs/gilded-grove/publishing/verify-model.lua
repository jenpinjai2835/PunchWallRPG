-- Passive assertions against the actual native Model loaded from Roblox.
local manifest=game:GetService('HttpService'):JSONDecode([==[__MANIFEST_JSON__]==])
local container=assert(workspace:FindFirstChild('__MODEL_NAME__'),'Missing verification instance')
local root=container
if not root:GetAttribute('UniqueBaseModels') then
    root=nil
    for _,v in container:GetDescendants() do if v:GetAttribute('UniqueBaseModels')==24 then assert(not root,'Ambiguous product root');root=v end end
end
assert(root and root:GetAttribute('UniqueBaseModels')==24,'Wrong product')
local basis=root:GetPivot()
local checked,parts,triangles,meshes,textures=0,0,0,{},{}
for bank,variant in {'Teal','Ember','Amethyst'} do
    local group=assert(root:FindFirstChild(variant),'Missing palette')
    assert(#group:GetChildren()==24,'Palette prop count mismatch')
    for index,asset in manifest.assets do
        local prop=assert(group:FindFirstChild(asset.id),'Missing prop')
        local base=Vector3.new((bank-2)*36+((index-1)%4-1.5)*8,0,-(math.floor((index-1)/4)-2.5)*8)
        assert((basis:PointToObjectSpace(prop:GetPivot().Position)-base).Magnitude<0.002,'Prop origin moved: '..asset.id)
        assert((prop:GetExtentsSize()-Vector3.new(asset.size[1],asset.size[3],asset.size[2])).Magnitude<0.005,'Prop dimensions changed')
        assert(#prop:GetChildren()==asset.mesh_count,'Extra product contents')
        local lower=Vector3.new(math.huge,math.huge,math.huge)
        local upper=-lower
        for _,spec in asset.meshes do
            local role=spec.name:match('__(.+)$')
            local part=assert(prop:FindFirstChild(role),'Missing named role')
            assert(part:IsA('MeshPart') and part.Anchored and not part.CanCollide and not part.CanTouch,'Invalid static decor settings')
            assert(part.MeshContent.SourceType==Enum.ContentSourceType.Uri and part.MeshId:match('rbxassetid://%d+'),'Non-persistent mesh')
            assert(part.TextureID:match('rbxassetid://%d+'),'Missing persistent texture')
            local pivot=base+Vector3.new(spec.pivot[1],spec.pivot[3],-spec.pivot[2])
            assert((basis:PointToObjectSpace(part:GetPivot().Position)-pivot).Magnitude<0.002,'Role pivot moved: '..spec.name)
            assert(part:GetAttribute('Triangles')==spec.triangles,'Triangle metadata lost')
            for _,x in {-0.5,0.5} do for _,y in {-0.5,0.5} do for _,z in {-0.5,0.5} do
                local corner=basis:PointToObjectSpace(part.CFrame:PointToWorldSpace(part.Size*Vector3.new(x,y,z)))-base
                lower=Vector3.new(math.min(lower.X,corner.X),math.min(lower.Y,corner.Y),math.min(lower.Z,corner.Z))
                upper=Vector3.new(math.max(upper.X,corner.X),math.max(upper.Y,corner.Y),math.max(upper.Z,corner.Z))
            end end end
            parts+=1;triangles+=spec.triangles;meshes[part.MeshId]=true;textures[part.TextureID]=true
        end
        local expectedLower=Vector3.new(asset.bounds_min[1],asset.bounds_min[3],-asset.bounds_max[2])
        local expectedUpper=Vector3.new(asset.bounds_max[1],asset.bounds_max[3],-asset.bounds_min[2])
        assert((lower-expectedLower).Magnitude<0.005 and (upper-expectedUpper).Magnitude<0.005,
            'Geometry offset from authored origin: '..variant..'/'..asset.id..' lower='..tostring(lower)..' expected='..tostring(expectedLower))
        checked+=1
    end
end
for _,obj in root:GetDescendants() do assert(obj:IsA('Model') or obj:IsA('MeshPart'),'Unexpected non-visual content') end
local meshCount,textureCount=0,0
for _ in meshes do meshCount+=1 end
for _ in textures do textureCount+=1 end
assert(parts==99 and checked==72 and triangles==75648 and textureCount==3)
return game:GetService('HttpService'):JSONEncode({status='PASS',uniqueModels=24,palettes=3,placements=checked,meshParts=parts,triangles=triangles,persistentMeshes=meshCount,persistentTextures=textureCount,authoredBoundsChecked=checked})
