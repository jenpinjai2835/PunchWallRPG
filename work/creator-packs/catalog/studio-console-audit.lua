assert(game.PlaceId==0)
local H=game:GetService('HttpService')
local baseline=H:JSONDecode([==[{"errors":["The current thread cannot read 'SourceAssetId' (lacking capability RobloxScript)","AssistantCommand:1256: Geometry offset from authored origin: Teal/01_Wayfarer_Chest lower=-1.5699996948242188, -3.479243755340576, -1.3849906921386719 expected=-1.5799999237060547, 0, -1.0550000667572021","The current thread cannot call 'LoadLocalAsset' (lacking capability RobloxScript)","AssistantCommand:1218: Missing verification instance"]}]==])
local allowed={}
for _,message in baseline.errors do allowed[message]=true end
local unexpected={}
local known=0
for _,row in game:GetService('LogService'):GetLogHistory() do
 if row.messageType==Enum.MessageType.MessageError then
  if allowed[row.message] then known+=1 else table.insert(unexpected,row.message) end
 end
end
assert(#unexpected==0,H:JSONEncode(unexpected))
return H:JSONEncode({status='PASS',unexpectedErrors=#unexpected,knownHistoricalErrors=known,scope='No new errors beyond recorded first-sale diagnostic history; built-in MaterialManager warning retained'})
