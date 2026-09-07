local importerPath = ...
local source = fs.read(importerPath, 'txt')
local first = assert(source:find('for _, inputPath in ipairs({inputPlace, phoenixFile, wyvernFile, guardianFile}) do', 1, true))
local last = assert(source:find('local strictBuilder = ', first, true))
local guard = rbxmk.runString('return function(inputPlace, phoenixFile, wyvernFile, guardianFile) local fs = {read=function(value) return value end}\n' .. source:sub(first,last-1) .. '\nreturn true end')
local empty = '<roblox><Content name="MeshContent"><null/></Content></roblox>'
local safe = '<roblox><Content name="MeshId"><url>rbxassetid://123</url></Content></roblox>'
assert(guard(empty,empty,empty,empty))
assert(guard(safe,safe,safe,safe))
assert(guard('<roblox><Content><uri> \n </uri></Content></roblox>',empty,empty,empty))
local count = 3
for index=1,4 do
 local inputs={empty,empty,empty,empty}
 inputs[index]='<roblox><Content name="AnyFutureProperty"><uri>rbxassetid://123</uri></Content></roblox>'
 local ok,err=pcall(guard,unpack(inputs))
 assert(not ok and tostring(err):find('cannot preserve Content URI',1,true),'URI accepted at input '..index)
 count=count+1
end
local ok,err=pcall(guard,'<roblox><Content><uri><![CDATA[rbxassetid://456]]></uri></Content></roblox>',empty,empty,empty)
assert(not ok and tostring(err):find('cannot preserve Content URI',1,true))
count=count+1
print('PASS '..count..' exact importer guard controls')
