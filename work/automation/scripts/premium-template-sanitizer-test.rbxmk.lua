local sourcePath = ...
local builder = rbxmk.runFile(path.join(path.expand('$sd'), 'load-production-visual-sanitizer.rbxmk.lua'), sourcePath)
local descriptor = assert(rbxmk.globalDesc)
local checks = {}
local function check(value, message) assert(value, message); checks[#checks+1] = message end
local model = Instance.new('Model'); model.Name = 'VisualFixture'; model[sym.Desc] = descriptor
model:SetAttribute('PetDefinitionName', 'Fixture Pet')
local body = Instance.new('Part'); body.Name = 'Body'; body.Size = Vector3.new(1,2,3); body.CFrame = CFrame.new(4,5,6); body.Color = Color3.new(.2,.4,.6); body.Parent = model
local beforeSize, beforeFrame, beforeColor = body.Size, body.CFrame, body.Color
local tool = Instance.new('Tool'); tool.Name='UnsafeWrapper'; tool.Parent=model
local mesh = Instance.new('Part'); mesh.Name='PreservedVisual'; mesh.Parent=tool
for _, className in ipairs({'Script','ModuleScript','RemoteEvent','UnreliableRemoteEvent','Motor6D','Weld','VectorForce','ProximityPrompt','Sound','Animator'}) do
 local item=Instance.new('Folder'); item.ClassName=className; item.Parent=model
end
check(builder.PrepareAttributesForRbxmk(model)==0,'valid metadata changed')
check(not builder.IsSanitizedVisual(model),'unsanitized model passed')
local _, removed=builder.SanitizeVisual(model)
check(removed==11,'unsafe class removal count mismatch')
check(builder.IsSanitizedVisual(model),'sanitized model failed')
check(mesh.Parent==model and tool.Parent==nil,'visual-only Tool unwrap failed')
check(body.Size==beforeSize and body.CFrame==beforeFrame and body.Color==beforeColor,'visible geometry changed')
check(model:GetAttribute('PetDefinitionName')=='Fixture Pet','identity attribute lost')
check(body.Anchored and not body.CanCollide and not body.CanTouch and not body.CanQuery and body.Massless,'physics flags unsafe')
body.CanQuery=true; check(not builder.IsSanitizedVisual(model),'query-enabled mutation passed'); body.CanQuery=false
body.Anchored=false; check(not builder.IsSanitizedVisual(model),'unanchored mutation passed'); body.Anchored=true
body:SetAttribute('VisualSanitizerVerified',false); check(not builder.IsSanitizedVisual(model),'missing child attestation passed'); body:SetAttribute('VisualSanitizerVerified',true)
model:SetAttribute('VisualSanitizerVersion','obsolete'); check(not builder.IsSanitizedVisual(model),'stale root version passed'); model:SetAttribute('VisualSanitizerVersion','StrictVisualAllowlistV1')
local joint=Instance.new('Motor6D'); joint.Parent=model; check(not builder.IsSanitizedVisual(model),'new joint mutation passed'); joint:Destroy()
check(builder.IsSanitizedVisual(model),'restored positive baseline failed')
local function badAttributes(encoded)
 local xml='<roblox version="4"><Item class="Model" referent="0"><Properties><string name="Name">BadAttributes</string><BinaryString name="AttributesSerialize">'..encoded..'</BinaryString></Properties></Item></roblox>'
 local root=rbxmk.decodeFormat('rbxmx',xml)
 return root:GetChildren()[1]
end
local empty=badAttributes('')
check(builder.PrepareAttributesForRbxmk(empty)==1,'empty malformed buffer was not repaired')
check(next(empty:GetAttributes())==nil,'empty repair added invented attributes')
check(rbxmk.globalDesc==descriptor and empty:IsA('Instance'),'empty repair lost descriptor')
local corrupt=badAttributes('YQ==')
local ok,err=pcall(builder.PrepareAttributesForRbxmk,corrupt)
check(not ok and tostring(err):find('nonempty malformed attributes',1,true)~=nil,'nonempty corrupt metadata was silently discarded')
check(rbxmk.globalDesc==descriptor and corrupt:IsA('Instance'),'failed repair lost descriptor')
check(not pcall(function() return corrupt:GetAttributes() end),'corrupt metadata was changed after rejection')
assert(#checks==20,'sanitizer test did not execute every required check')
print('PASS production premium-template sanitizer',#checks,'checks')
