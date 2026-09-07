-- Execute the authoritative sanitizer in rbxmk after only Lua syntax adaptation.
-- Call with --desc-file or --desc-latest so IsA uses the Roblox class hierarchy.
local sourcePath = ...
assert(rbxmk.globalDesc ~= nil, "Roblox API descriptor is required")
assert(type(sourcePath) == "string" and sourcePath ~= "", "FistVisualBuilder source path is required")
local source = fs.read(sourcePath, "txt")
local first = assert(source:find('local SANITIZER_VERSION = ', 1, true), "sanitizer start missing")
local last = assert(source:find('local function createArmoredClosedFist', first, true), "sanitizer end missing")
local fragment = source:sub(first, last - 1)
assert(fragment:find('function FistVisualBuilder.SanitizeVisual(root)', 1, true), "production entrypoint missing")
fragment = fragment:gsub('removed%s*%+=', 'removed = removed +')
fragment = fragment:gsub('Vector3%.zero', 'Vector3.new(0, 0, 0)')
-- Assembly velocities are runtime properties and are not serialized in templates.
fragment = fragment:gsub('[\t ]*instance%.AssemblyLinearVelocity = [^\n]+\n', '')
fragment = fragment:gsub('[\t ]*instance%.AssemblyAngularVelocity = [^\n]+\n', '')
local builder = rbxmk.runString('local FistVisualBuilder = {}\n' .. fragment .. '\nreturn FistVisualBuilder')
function builder.PrepareAttributesForRbxmk(root)
 local descriptor = assert(rbxmk.globalDesc, 'Roblox API descriptor is required')
 root[sym.Desc] = descriptor
 local items = root:GetDescendants()
 table.insert(items, 1, root)
 local repaired = 0
 for _, item in ipairs(items) do
  local valid = pcall(function() return item:GetAttributes() end)
  if not valid then
   -- Some imported files contain an invalid zero-byte attribute buffer.
   -- Refuse nonempty corrupt metadata; only an actually empty buffer is repaired.
   rbxmk.globalDesc = nil
   root[sym.Desc] = false
   item[sym.Desc] = false
   local raw = item[sym.Properties].AttributesSerialize
   local empty = raw ~= nil and rbxmk.encodeFormat('txt', raw) == ''
   if empty then item:SetAttributes({}) end
   item[sym.Desc] = nil
   root[sym.Desc] = descriptor
   rbxmk.globalDesc = descriptor
   assert(empty, 'nonempty malformed attributes must be investigated: ' .. item:GetFullName())
   repaired = repaired + 1
  end
 end
 return repaired
end
return builder
