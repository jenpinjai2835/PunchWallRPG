-- Export only the three repaired models; the caller preserves the rest of the place.
local inputPlace, outputModels, sourcePath = ...
assert(type(inputPlace) == 'string' and inputPlace ~= '', 'input place required')
assert(type(outputModels) == 'string' and outputModels ~= '' and outputModels ~= inputPlace, 'distinct output models required')
local builder = rbxmk.runFile(path.join(path.expand('$sd'), 'load-production-visual-sanitizer.rbxmk.lua'), sourcePath)
local place = fs.read(inputPlace, 'rbxlx')
place[sym.Desc] = rbxmk.globalDesc
local storage = assert(place:FindFirstChild('ReplicatedStorage'), 'ReplicatedStorage missing')
local external = assert(storage:FindFirstChild('PunchWallExternalAssets'), 'external visuals missing')
local output = Instance.new('Folder')
output[sym.Desc] = rbxmk.globalDesc
output.Name = 'RepairedPremiumPetTemplates'
local specs = {
 {'Sanitized_CrimsonPhoenixPet', 'Crimson Phoenix', '86478691482535'},
 {'Sanitized_StormWyvernPet', 'Storm Wyvern', '83562531232957'},
 {'Sanitized_CelestialGuardianPet', 'Celestial Guardian', '121956330907081'},
}
for _, spec in ipairs(specs) do
 local model = assert(external:FindFirstChild(spec[1]), 'required template missing: ' .. spec[1])
 assert(model:GetAttribute('PetDefinitionName') == spec[2], 'pet identity mismatch')
 assert(tostring(model:GetAttribute('CreatorStoreAssetId')) == spec[3], 'asset identity mismatch')
 local clone = model:Clone()
 clone[sym.Desc] = rbxmk.globalDesc
 local emptyBuffers = builder.PrepareAttributesForRbxmk(clone)
 local beforeParts, beforeEffects, beforeJoints = 0, 0, 0
 for _, item in ipairs(clone:GetDescendants()) do
  if item:IsA('BasePart') then beforeParts = beforeParts + 1 end
  if item:IsA('ParticleEmitter') or item:IsA('Trail') or item:IsA('Beam') or item:IsA('Light') then beforeEffects = beforeEffects + 1 end
  if item:IsA('JointInstance') or item:IsA('Constraint') then beforeJoints = beforeJoints + 1 end
 end
 local _, removed = builder.SanitizeVisual(clone)
 assert(builder.IsSanitizedVisual(clone), 'strict sanitizer failed')
 local afterParts, afterEffects = 0, 0
 for _, item in ipairs(clone:GetDescendants()) do
  assert(not item:IsA('JointInstance') and not item:IsA('Constraint'), 'behavior joint survived')
  if item:IsA('BasePart') then afterParts = afterParts + 1 end
  if item:IsA('ParticleEmitter') or item:IsA('Trail') or item:IsA('Beam') or item:IsA('Light') then afterEffects = afterEffects + 1 end
 end
 assert(afterParts == beforeParts and afterEffects == beforeEffects, 'repair changed visual part/effect population')
 assert(afterParts > 0, 'empty visual')
 clone.Parent = output
 print(spec[1], 'parts', afterParts, 'effects', afterEffects, 'removed', removed, 'previousJoints', beforeJoints, 'emptyAttributeBuffers', emptyBuffers)
end
fs.write(outputModels, output, 'rbxmx')
print('wrote', outputModels)
