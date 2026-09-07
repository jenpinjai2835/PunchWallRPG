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

const client = new McpClient(studioMcpPath, "punch-wall-pet-pack-template-installer");
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
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local history=game:GetService("ChangeHistoryService")
local sourceRoot=workspace:FindFirstChild("Pet pack")
assert(sourceRoot and sourceRoot:IsA("Model"),"sanitized Workspace.Pet pack is missing")
assert(sourceRoot:GetAttribute("SanitizedVisualOnly")==true,"raw pack sanitation attestation missing")

local mappings={
  {definition="Forest Pup",rarity="Common",source="Dowodle",template="Sanitized_ForestPupPet"},
  {definition="Miner Cat",rarity="Rare",source="Catmouse",template="Sanitized_MinerCatPet"},
  {definition="Crystal Fox",rarity="Epic",source="Ocelot",template="Sanitized_CrystalFoxPet"},
  {definition="Lava Dragon",rarity="Legendary",source="Mythic Autumn Dragon",template="Sanitized_LavaDragonPet"},
  {definition="Secret Titan Golem",rarity="Secret",source="Dark Guardian",template="Sanitized_SecretTitanGolemPet"},
  {definition="Thunder Roc",rarity="Legendary",source="Enraged Phoenix",template="Sanitized_EnragedPhoenixPet"},
  {definition="Frost Hydra",rarity="Legendary",source="Electra Hydra",template="Sanitized_ElectraHydraPet"},
  {definition="Solar Kirin",rarity="Secret",source="Mythic Radiant One",template="Sanitized_MythicRadiantOnePet"},
}

-- Assistant/InsertService wraps this Creator Store model in an extra Model
-- named "Pet pack", while a manual Toolbox insert may expose the pets directly.
-- Resolve the one container that owns every mapped source so both reproducible
-- import paths install the same eight children.
local source=sourceRoot
if not source:FindFirstChild(mappings[1].source) then
  local candidates={}
  for _,candidate in ipairs(sourceRoot:GetDescendants()) do
    if candidate:IsA("Model") then
      local complete=true
      for _,mapping in ipairs(mappings) do
        if not candidate:FindFirstChild(mapping.source) then
          complete=false
          break
        end
      end
      if complete then table.insert(candidates,candidate) end
    end
  end
  assert(#candidates==1,"expected one nested pet-pack source container, found "..tostring(#candidates))
  source=candidates[1]
end

local external=ReplicatedStorage:FindFirstChild("PunchWallExternalAssets")
if not external then
  external=Instance.new("Folder")
  external.Name="PunchWallExternalAssets"
  external.Parent=ReplicatedStorage
end
local builder=require(ReplicatedStorage:WaitForChild("FistVisualBuilder"))
history:SetWaypoint("Before Punch Wall pet-pack template install")

local rows={}
for index,mapping in ipairs(mappings) do
  local sourceModel=source:FindFirstChild(mapping.source)
  assert(sourceModel and sourceModel:IsA("Model"),"missing source model "..mapping.source)
  local existing=external:FindFirstChild(mapping.template)
  if existing then existing:Destroy() end
  local clone=sourceModel:Clone()
  clone.Name=mapping.template
  clone.Parent=external
  builder.SanitizeVisual(clone)
  local parts=0
  local effects=0
  for _,d in ipairs(clone:GetDescendants()) do
    if d:IsA("BasePart") then
      parts+=1
      d.Anchored=true
      d.CanCollide=false
      d.CanTouch=false
      d.CanQuery=false
      d.Massless=true
    elseif d:IsA("ParticleEmitter") then
      effects+=1
      d.Rate=math.min(d.Rate,8)
      d.Lifetime=NumberRange.new(math.min(d.Lifetime.Min,.8),math.min(d.Lifetime.Max,1.1))
    elseif d:IsA("Trail") then
      effects+=1
      d.Lifetime=math.min(d.Lifetime,.45)
    elseif d:IsA("Beam") then
      effects+=1
      d.Segments=math.min(d.Segments,8)
    elseif d:IsA("Light") then
      effects+=1
      d.Shadows=false
      d.Range=math.min(d.Range,8)
      d.Brightness=math.min(d.Brightness,2)
    end
  end
  clone:SetAttribute("AssetId",70715599928632)
  clone:SetAttribute("CreatorStoreAssetId",70715599928632)
  clone:SetAttribute("CreatorStorePackAssetId","70715599928632")
  clone:SetAttribute("SourcePackModelName",mapping.source)
  clone:SetAttribute("PetDefinitionName",mapping.definition)
  clone:SetAttribute("PetRarity",mapping.rarity)
  clone:SetAttribute("PetPackMappingIndex",index)
  clone:SetAttribute("VisualPartCount",parts)
  clone:SetAttribute("VisualEffectCount",effects)
  clone:SetAttribute("TemplateVisualAttested",true)
  clone:SetAttribute("PreloadedOnly",true)
  assert(builder.IsSanitizedVisual(clone),"template lost sanitizer attestation "..mapping.template)
  table.insert(rows,{definition=mapping.definition,rarity=mapping.rarity,source=mapping.source,template=mapping.template,parts=parts,effects=effects})
end
builder.SanitizeVisual(external)
external:SetAttribute("PetPackAssetId","70715599928632")
external:SetAttribute("PetPackTemplateCount",#mappings)
external:SetAttribute("PetPackVersion","CuteFurryBundleV1")

sourceRoot:Destroy()
assert(not workspace:FindFirstChild("Pet pack"),"raw pet pack remained in Workspace")
local unsafe=0
for _,d in ipairs(external:GetDescendants()) do
  if d:IsA("LuaSourceContainer") or d:IsA("Tool") or d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d:IsA("BindableEvent") or d:IsA("BindableFunction") or d:IsA("ClickDetector") or d:IsA("ProximityPrompt") or d:IsA("Sound") or d:IsA("Humanoid") or d:IsA("AnimationController") or d:IsA("Animator") then
    unsafe+=1
  end
end
assert(unsafe==0,"unsafe descendant remained in PunchWallExternalAssets")
history:SetWaypoint("Installed sanitized Punch Wall pet-pack templates")
return H:JSONEncode({ok=true,count=#rows,unsafe=unsafe,rawPackRemoved=true,rows=rows})
`,
  }, 60000);
  assertCondition(!result.isError, `Pet pack template install failed: ${result.text}`);
  console.log(JSON.stringify({ selectedStudio: selected, identity, result: result.text }, null, 2));
} finally {
  client.close();
}
