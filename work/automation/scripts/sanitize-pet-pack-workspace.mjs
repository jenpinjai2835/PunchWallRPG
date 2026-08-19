import {
  McpClient,
  assertCondition,
  assertPlaceIdentity,
  inspectSelectedPlace,
  selectStudioStrict,
} from "./studio_mcp_client.mjs";

const studioMcpPath = process.argv[2];
const studioInstanceId = process.argv[3];
const studioName = process.argv[4];

assertCondition(studioMcpPath, "StudioMCP.exe path is required");
assertCondition(studioInstanceId, "Studio instance id is required");
assertCondition(studioName, "Anchored Studio name regex is required");

const client = new McpClient(studioMcpPath, "punch-wall-pet-pack-sanitizer");
try {
  await client.initialize();
  const selected = await selectStudioStrict(client, {
    studioInstanceId,
    studioName,
    pollAttempts: 3,
    pollMs: 250,
  });
  const identity = await inspectSelectedPlace(client, { datamodelTypes: ["Edit"] });
  assertPlaceIdentity(identity, { placeName: studioName });
  const result = await client.callTool("execute_luau", {
    datamodel_type: "Edit",
    code: `
local H=game:GetService("HttpService")
local history=game:GetService("ChangeHistoryService")
local source=workspace:FindFirstChild("Pet pack")
assert(source and source:IsA("Model"),"Workspace.Pet pack is missing")
history:SetWaypoint("Before Punch Wall pet-pack sanitation")

local removedLegacy={}
for _,item in ipairs(workspace:GetChildren()) do
  if item.Name=="Pets" or item.Name=="BGC Pets Pack" then
    table.insert(removedLegacy,item:GetFullName())
    item:Destroy()
  end
end

local unsafeClasses={
  LuaSourceContainer=true,
  Tool=true,
  RemoteEvent=true,
  RemoteFunction=true,
  BindableEvent=true,
  BindableFunction=true,
  ClickDetector=true,
  ProximityPrompt=true,
  Humanoid=true,
  AnimationController=true,
  Animator=true,
  Sound=true,
}
local removedUnsafe={}
for _,d in ipairs(source:GetDescendants()) do
  if d:IsA("LuaSourceContainer") or unsafeClasses[d.ClassName] then
    table.insert(removedUnsafe,{path=d:GetFullName(),className=d.ClassName})
    d:Destroy()
  elseif d:IsA("BasePart") then
    d.Anchored=true
    d.CanCollide=false
    d.CanTouch=false
    d.CanQuery=false
    d.Massless=true
  elseif d:IsA("ParticleEmitter") then
    d.Rate=math.min(d.Rate,8)
  elseif d:IsA("Trail") then
    d.Lifetime=math.min(d.Lifetime,.45)
  elseif d:IsA("Beam") then
    d.Segments=math.min(d.Segments,8)
  elseif d:IsA("Light") then
    d.Shadows=false
    d.Range=math.min(d.Range,8)
    d.Brightness=math.min(d.Brightness,2)
  end
end
source:SetAttribute("CreatorStoreAssetId","70715599928632")
source:SetAttribute("SanitizedVisualOnly",true)
source:SetAttribute("VisualSanitizerVerified",true)
source:SetAttribute("SanitizedFor","Punch Wall RPG pet selection")

local unsafeAfter=0
for _,d in ipairs(source:GetDescendants()) do
  if d:IsA("LuaSourceContainer") or unsafeClasses[d.ClassName] then unsafeAfter+=1 end
end
assert(unsafeAfter==0,"unsafe descendants remain after sanitation")
history:SetWaypoint("Sanitized Punch Wall pet pack")
return H:JSONEncode({
  ok=true,
  removedLegacy=removedLegacy,
  removedLegacyCount=#removedLegacy,
  removedUnsafe=removedUnsafe,
  removedUnsafeCount=#removedUnsafe,
  unsafeAfter=unsafeAfter,
  sourcePath=source:GetFullName(),
})
`,
  }, 60000);
  assertCondition(!result.isError, `Pet pack sanitation failed: ${result.text}`);
  console.log(JSON.stringify({ selectedStudio: selected, identity, result: result.text }, null, 2));
} finally {
  client.close();
}
