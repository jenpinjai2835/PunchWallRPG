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
const compact = process.argv.includes("--compact");

assertCondition(studioMcpPath, "StudioMCP.exe path is required");
assertCondition(studioInstanceId, "Studio instance id is required");
assertCondition(studioName, "Anchored Studio name regex is required");

const client = new McpClient(studioMcpPath, "punch-wall-pet-pack-inspector");

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
local Selection=game:GetService("Selection")

local function summarize(root)
  local row={
    path=root:GetFullName(),
    name=root.Name,
    className=root.ClassName,
    children=#root:GetChildren(),
    descendants=0,
    parts=0,
    meshParts=0,
    scripts=0,
    joints=0,
    effects=0,
    sounds=0,
    unsafe=0,
    size={x=0,y=0,z=0},
  }
  for _,d in ipairs(root:GetDescendants()) do
    row.descendants+=1
    if d:IsA("BasePart") then
      row.parts+=1
      if d:IsA("MeshPart") then row.meshParts+=1 end
    elseif d:IsA("LuaSourceContainer") then
      row.scripts+=1
      row.unsafe+=1
    elseif d:IsA("JointInstance") or d:IsA("Constraint") then
      row.joints+=1
    elseif d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") or d:IsA("Light") then
      row.effects+=1
    elseif d:IsA("Sound") then
      row.sounds+=1
      row.unsafe+=1
    elseif d:IsA("Humanoid") or d:IsA("AnimationController") or d:IsA("Animator") or d:IsA("Tool") or d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d:IsA("BindableEvent") or d:IsA("BindableFunction") or d:IsA("ClickDetector") or d:IsA("ProximityPrompt") then
      row.unsafe+=1
    end
  end
  if root:IsA("Model") then
    local _,size=root:GetBoundingBox()
    row.size={x=size.X,y=size.Y,z=size.Z}
  elseif root:IsA("BasePart") then
    row.size={x=root.Size.X,y=root.Size.Y,z=root.Size.Z}
  end
  return row
end

local selectedRows={}
local selectedChildren={}
local selectedInteresting={}
local selectedScripts={}
local selectedNames={}
for _,item in ipairs(Selection:Get()) do
  table.insert(selectedRows,summarize(item))
  for _,d in ipairs(item:GetDescendants()) do
    if d:IsA("LuaSourceContainer") then
      table.insert(selectedScripts,{
        path=d:GetFullName(),
        className=d.ClassName,
        disabled=(d:IsA("Script") or d:IsA("LocalScript")) and d.Disabled or nil,
        source=d.Source:sub(1,240),
      })
    end
  end
  for _,child in ipairs(item:GetChildren()) do
    if child:IsA("Model") or child:IsA("Folder") or child:IsA("BasePart") then
      table.insert(selectedNames,child.Name)
      local row=summarize(child)
      table.insert(selectedChildren,row)
      if child.Name:lower():match("cat") or child.Name:lower():match("kitty") or child.Name:lower():match("dog") or child.Name:lower():match("pup") or child.Name:lower():match("fox") or child.Name:lower():match("dragon") or child.Name:lower():match("phoenix") or child.Name:lower():match("wyvern") or child.Name:lower():match("guardian") or child.Name:lower():match("golem") or child.Name:lower():match("wolf") or child.Name:lower():match("titan") then
        table.insert(selectedInteresting,row)
      end
    end
  end
end
table.sort(selectedChildren,function(a,b)
  if a.parts==b.parts then return a.path<b.path end
  return a.parts<b.parts
end)
table.sort(selectedNames)

local workspaceRows={}
for _,item in ipairs(workspace:GetChildren()) do
  if item:IsA("Model") or item:IsA("Folder") then table.insert(workspaceRows,summarize(item)) end
end
table.sort(workspaceRows,function(a,b) return a.path<b.path end)

local storageRows={}
for _,serviceName in ipairs({"ReplicatedStorage","ServerStorage"}) do
  local service=game:GetService(serviceName)
  for _,item in ipairs(service:GetChildren()) do
    if item:IsA("Model") or item:IsA("Folder") then table.insert(storageRows,summarize(item)) end
  end
end
table.sort(storageRows,function(a,b) return a.path<b.path end)

local globalScripts={}
for _,d in ipairs(game:GetDescendants()) do
  if d:IsA("LuaSourceContainer") then
    local source=d.Source
    if source:find("Model Parse Error",1,true) or source:find("122845407827531",1,true) or source:find("GetObjects",1,true) then
      table.insert(globalScripts,{path=d:GetFullName(),className=d.ClassName,source=source:sub(1,500)})
    end
  end
end

return H:JSONEncode({
  selected=selectedRows,
  selectedChildren=selectedChildren,
  selectedInteresting=selectedInteresting,
  selectedScripts=selectedScripts,
  selectedNames=selectedNames,
  workspace=workspaceRows,
  storage=storageRows,
  globalScripts=globalScripts,
})
`,
  }, 30000);
  assertCondition(!result.isError, `Pet pack inspection failed: ${result.text}`);
  if (compact) {
    const parsed = JSON.parse(result.text);
    console.log(JSON.stringify({
      selectedStudio: selected,
      identity,
      selected: parsed.selected,
      selectedInteresting: parsed.selectedInteresting,
      selectedScripts: parsed.selectedScripts,
      globalScripts: parsed.globalScripts,
      selectedNames: parsed.selectedNames,
    }, null, 2));
  } else {
    console.log(JSON.stringify({ selectedStudio: selected, identity, payload: result.text }, null, 2));
  }
} finally {
  client.close();
}
