-- Authoring validation only; this command is never included in the product.
assert(game.PlaceId == 0, 'Expected isolated local authoring place')
assert(game:GetService('StudioService'):GetUserId() == 9158952231, 'Wrong creator')
local assetId = __ASSET_ID__
local old = workspace:FindFirstChild('GildedGroveStoreQA')
assert(not old or old:GetAttribute('OwnedStoreQA'), 'Unexpected instance with QA name')
if old then old:Destroy() end
local loaded = game:GetService('AssetService'):LoadAssetAsync(assetId)
loaded.Name = 'GildedGroveStoreQA'
loaded:SetAttribute('OwnedStoreQA', true)
loaded:SetAttribute('UploadedAssetId', assetId)
loaded.Parent = workspace
local function vector(v) return {v.X,v.Y,v.Z} end
local function frame(cf) return {cf:GetComponents()} end
local report = {assetId=assetId,modelNames={},parts={},appearances={},classCounts={},forbidden={},unanchored=0,nonPersistent=0}
for _, obj in loaded:GetDescendants() do
    report.classCounts[obj.ClassName]=(report.classCounts[obj.ClassName] or 0)+1
    if obj:IsA('LuaSourceContainer') then table.insert(report.forbidden,obj:GetFullName()) end
    if obj:IsA('Model') then
        table.insert(report.modelNames,{name=obj.Name,parent=obj.Parent.Name,pivot=frame(obj:GetPivot()),size=vector(obj:GetExtentsSize())})
    elseif obj:IsA('MeshPart') then
        if not obj.Anchored then report.unanchored+=1 end
        if obj.MeshContent.SourceType~=Enum.ContentSourceType.Uri then report.nonPersistent+=1 end
        table.insert(report.parts,{name=obj.Name,parent=obj.Parent.Name,meshId=obj.MeshId,textureId=obj.TextureID,size=vector(obj.Size),cframe=frame(obj.CFrame),pivot=frame(obj:GetPivot()),pivotOffset=frame(obj.PivotOffset),anchored=obj.Anchored,canCollide=obj.CanCollide})
    elseif obj:IsA('SurfaceAppearance') then
        table.insert(report.appearances,{parent=obj.Parent:GetFullName(),colorMap=obj.ColorMap,alphaMode=tostring(obj.AlphaMode)})
    end
end
report.size=vector(loaded:GetExtentsSize())
report.pivot=frame(loaded:GetPivot())
report.status=(#report.parts==99 and #report.forbidden==0 and report.nonPersistent==0) and 'STRUCTURE_PASS' or 'FAIL'
-- Move only the QA instance after recording all original transforms.
loaded:PivotTo(CFrame.new(0,0,100))
workspace.CurrentCamera.CameraType=Enum.CameraType.Scriptable
workspace.CurrentCamera.FieldOfView=40
workspace.CurrentCamera.CFrame=CFrame.lookAt(Vector3.new(80,85,220),Vector3.new(0,5,100))
return game:GetService('HttpService'):JSONEncode(report)
