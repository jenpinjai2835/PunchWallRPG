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
const localAssetFiles = process.argv.slice(5, 8);

assertCondition(studioMcpPath, "StudioMCP.exe path is required");
assertCondition(studioInstanceId, "Studio instance id is required");
assertCondition(studioName, "Anchored Studio name regex is required");
assertCondition(
  localAssetFiles.length === 3 && localAssetFiles.every((file) => typeof file === "string" && file.length > 0),
  "Three local Premium pet asset files are required (Phoenix, Wyvern, Guardian)",
);

const localAssetLua = localAssetFiles.map((file) => JSON.stringify(file.replaceAll("\\", "/")));

const client = new McpClient(studioMcpPath, "punch-wall-detailed-premium-pet-installer");
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
local InsertService=game:GetService("InsertService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local history=game:GetService("ChangeHistoryService")
local builder=require(ReplicatedStorage:WaitForChild("FistVisualBuilder"))

local external=ReplicatedStorage:FindFirstChild("PunchWallExternalAssets")
if not external then
  external=Instance.new("Folder")
  external.Name="PunchWallExternalAssets"
  external.Parent=ReplicatedStorage
end

-- The v1.0.3 artifact stored three low-detail pack children under the Premium
-- template names. Preserve those useful models for late-game normal pets before
-- restoring the original detailed Premium assets to their canonical names.
for oldName,newName in pairs({
  Sanitized_CrimsonPhoenixPet="Sanitized_EnragedPhoenixPet",
  Sanitized_StormWyvernPet="Sanitized_ElectraHydraPet",
  Sanitized_CelestialGuardianPet="Sanitized_MythicRadiantOnePet",
}) do
  local old=external:FindFirstChild(oldName)
  if old and tostring(old:GetAttribute("CreatorStorePackAssetId") or "")=="70715599928632" then
    local existingNew=external:FindFirstChild(newName)
    if existingNew then existingNew:Destroy() end
    old.Name=newName
  end
end

local mappings={
  {definition="Crimson Phoenix",template="Sanitized_CrimsonPhoenixPet",asset=86478691482535,creator="IAmASwedishMale",localFile=${localAssetLua[0]}},
  {definition="Storm Wyvern",template="Sanitized_StormWyvernPet",asset=83562531232957,creator="XzG0ldeneJGlitchQJCy",localFile=${localAssetLua[1]}},
  {definition="Celestial Guardian",template="Sanitized_CelestialGuardianPet",asset=121956330907081,creator="SirRioter",localFile=${localAssetLua[2]}},
}

history:SetWaypoint("Before detailed Premium pet template install")
local rows={}
for index,mapping in ipairs(mappings) do
  local ok,loaded=pcall(function()
    return InsertService:LoadLocalAsset(mapping.localFile)
  end)
  assert(ok and loaded and loaded:IsA("Model"),"failed to load local Premium pet asset "..tostring(mapping.asset)..": "..tostring(loaded))
  local existing=external:FindFirstChild(mapping.template)
  if existing then existing:Destroy() end
  loaded.Name=mapping.template
  builder.SanitizeVisual(loaded)
  local parts,effects,unsafe=0,0,0
  for _,d in ipairs(loaded:GetDescendants()) do
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
    elseif d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("Tool")
      or d:IsA("RemoteEvent") or d:IsA("RemoteFunction")
      or d:IsA("BindableEvent") or d:IsA("BindableFunction")
      or d:IsA("ClickDetector") or d:IsA("ProximityPrompt")
      or d:IsA("Humanoid") or d:IsA("AnimationController") or d:IsA("Animator")
    then
      unsafe+=1
    end
  end
  assert(parts>=1,"Premium pet visual is unexpectedly empty "..mapping.definition)
  assert(unsafe==0,"unsafe Premium pet descendant remained "..mapping.definition)
  loaded:SetAttribute("AssetId",mapping.asset)
  loaded:SetAttribute("CreatorStoreAssetId",mapping.asset)
  loaded:SetAttribute("CreatorStorePackAssetId",tostring(mapping.asset))
  loaded:SetAttribute("CreatorStoreCreator",mapping.creator)
  loaded:SetAttribute("PetDefinitionName",mapping.definition)
  loaded:SetAttribute("PetRarity","Premium")
  loaded:SetAttribute("VisualPartCount",parts)
  loaded:SetAttribute("VisualEffectCount",effects)
  loaded:SetAttribute("TemplateVisualAttested",true)
  loaded:SetAttribute("PreloadedOnly",false)
  loaded:SetAttribute("TemplateAssetMode","DetailedStandaloneAsset")
  loaded:SetAttribute("TemplateAssetFetchMode","AuthenticatedChromeDownloadThenLocalStudioImport")
  loaded:SetAttribute("SourceFallback",false)
  assert(builder.IsSanitizedVisual(loaded),"Premium pet lost sanitizer attestation "..mapping.definition)
  loaded.Parent=external
  table.insert(rows,{definition=mapping.definition,template=mapping.template,asset=mapping.asset,parts=parts,effects=effects})
end

builder.SanitizeVisual(external)
external:SetAttribute("DetailedPremiumPetTemplateCount",#mappings)
external:SetAttribute("DetailedPremiumPetVersion","OriginalCreatorStoreModelsV1")
history:SetWaypoint("Installed detailed Premium pet templates")
return H:JSONEncode({ok=true,count=#rows,rows=rows})
`,
  }, 120000);
  assertCondition(!result.isError, `Detailed Premium pet install failed: ${result.text}`);
  console.log(JSON.stringify({ selectedStudio: selected, identity, result: result.text }, null, 2));
} finally {
  client.close();
}
