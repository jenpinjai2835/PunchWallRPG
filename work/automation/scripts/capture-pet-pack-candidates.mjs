import fs from "node:fs";
import path from "node:path";
import {
  McpClient,
  assertCondition,
  assertPlaceIdentity,
  inspectSelectedPlace,
  selectStudioStrict,
  sleep,
  waitForDataModels,
} from "./studio_mcp_client.mjs";

const studioMcpPath = process.argv[2];
const studioInstanceId = process.argv[3];
const studioName = process.argv[4];
const outDir = path.resolve(process.argv[5]);
const pages = [
  ["Dowodle", "Catmouse", "Advocate", "Queen Kitty", "Pastel Dragon", "Autumn Dragon", "Dark Guardian", "Guardian Elemental"],
  ["Enraged Phoenix", "Light Phoenix", "Mythic Light Phoenix", "Rainbow Phoenix", "Electra Hydra", "Mythic Autumn Dragon", "Plasma Wolflord", "Guardian Angel"],
  ["Ocelot", "Mythic Ocelot", "Chocolate Bunny", "Rabbit Plushie", "Teddy Bear", "Zebra", "Mythic Zebra", "Axolotl Plushie"],
  ["Radiant Protector", "Radiant One", "Mythic Radiant One", "Galactic Paladin", "Mythic Galactic Paladin", "Immortal One", "The Keeper", "Luminance"],
];

assertCondition(studioMcpPath, "StudioMCP.exe path is required");
assertCondition(studioInstanceId, "Studio instance id is required");
assertCondition(studioName, "Anchored Studio name regex is required");
assertCondition(outDir, "Output directory is required");

function imageContent(result) {
  return result.content.find((item) => item.type === "image" && item.data);
}

const client = new McpClient(studioMcpPath, "punch-wall-pet-pack-candidate-capture");
let started = false;
try {
  await client.initialize();
  const selectedStudio = await selectStudioStrict(client, {
    studioInstanceId,
    studioName,
    pollAttempts: 3,
    pollMs: 250,
  });
  const identity = await inspectSelectedPlace(client, { datamodelTypes: ["Edit"] });
  assertPlaceIdentity(identity, { placeName: studioName });
  const start = await client.callTool("start_stop_play", { is_start: true }, 60000);
  assertCondition(!start.isError, `Could not start Play: ${start.text}`);
  started = true;
  await waitForDataModels(client, ["Server", "Client"], 60000);
  await sleep(2500);
  fs.mkdirSync(outDir, { recursive: true });

  for (let pageIndex = 0; pageIndex < pages.length; pageIndex += 1) {
    const names = pages[pageIndex];
    const encodedNames = JSON.stringify(names).replaceAll("\\", "\\\\").replaceAll("'", "\\'");
    const stage = await client.callTool("execute_luau", {
      datamodel_type: "Server",
      code: `
local H=game:GetService("HttpService")
local names=H:JSONDecode('${encodedNames}')
local source=workspace:FindFirstChild("Pet pack")
assert(source and source:IsA("Model"),"selected Pet pack is missing")
local old=workspace:FindFirstChild("Pet Pack Candidate Stage")
if old then old:Destroy() end
local stage=Instance.new("Folder")
stage.Name="Pet Pack Candidate Stage"
stage.Parent=workspace
local rows={}
for index,name in ipairs(names) do
  local sourceModel=source:FindFirstChild(name)
  assert(sourceModel and sourceModel:IsA("Model"),"missing candidate "..name)
  local clone=sourceModel:Clone()
  clone.Name=("%02d %s"):format(index,name)
  for _,d in ipairs(clone:GetDescendants()) do
    if d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("Humanoid") or d:IsA("AnimationController") or d:IsA("Animator") or d:IsA("Tool") or d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d:IsA("BindableEvent") or d:IsA("BindableFunction") or d:IsA("ClickDetector") or d:IsA("ProximityPrompt") then
      d:Destroy()
    elseif d:IsA("BasePart") then
      d.Anchored=true
      d.CanCollide=false
      d.CanTouch=false
      d.CanQuery=false
    elseif d:IsA("ParticleEmitter") then
      d.Rate=math.min(d.Rate,8)
    end
  end
  clone.Parent=stage
  local _,size=clone:GetBoundingBox()
  local largest=math.max(size.X,size.Y,size.Z)
  if largest>0 then clone:ScaleTo(clone:GetScale()*(3.2/largest)) end
  local column=(index-1)%4
  local row=math.floor((index-1)/4)
  clone:PivotTo(CFrame.new((column-1.5)*5,320-row*5,0))
  local box,sizeAfter=clone:GetBoundingBox()
  local anchor=Instance.new("Part")
  anchor.Name="Label Anchor"
  anchor.Anchored=true
  anchor.CanCollide=false
  anchor.CanTouch=false
  anchor.CanQuery=false
  anchor.Transparency=1
  anchor.Size=Vector3.new(.1,.1,.1)
  anchor.Position=box.Position+Vector3.new(0,sizeAfter.Y*.5+.8,0)
  anchor.Parent=clone
  local gui=Instance.new("BillboardGui")
  gui.Size=UDim2.fromOffset(220,34)
  gui.AlwaysOnTop=true
  gui.LightInfluence=0
  gui.Adornee=anchor
  gui.Parent=anchor
  local label=Instance.new("TextLabel")
  label.Size=UDim2.fromScale(1,1)
  label.BackgroundColor3=Color3.fromRGB(5,14,28)
  label.BackgroundTransparency=.12
  label.BorderSizePixel=0
  label.TextColor3=Color3.fromRGB(255,255,255)
  label.TextStrokeTransparency=.45
  label.Font=Enum.Font.GothamBold
  label.TextScaled=true
  label.Text=name
  label.Parent=gui
  table.insert(rows,{name=name,parts=#clone:GetDescendants(),size={sizeAfter.X,sizeAfter.Y,sizeAfter.Z}})
end
return H:JSONEncode({ok=true,count=#names,rows=rows})
`,
    }, 60000);
    assertCondition(!stage.isError, `Could not stage page ${pageIndex + 1}: ${stage.text}`);
    const camera = await client.callTool("execute_luau", {
      datamodel_type: "Client",
      code: "local cam=workspace.CurrentCamera cam.CameraType=Enum.CameraType.Scriptable cam.CFrame=CFrame.lookAt(Vector3.new(0,317.5,23),Vector3.new(0,317.5,0)) cam.Focus=CFrame.new(0,317.5,0) return true",
    }, 30000);
    assertCondition(!camera.isError, `Could not set candidate camera: ${camera.text}`);
    await sleep(800);
    const shot = await client.callTool("screen_capture", { capture_id: `PetPackCandidates_${pageIndex + 1}` }, 60000);
    assertCondition(!shot.isError, `Could not capture candidate page ${pageIndex + 1}: ${shot.text}`);
    const image = imageContent(shot);
    assertCondition(image, `No image returned for candidate page ${pageIndex + 1}`);
    fs.writeFileSync(path.join(outDir, `pet-pack-candidates-${pageIndex + 1}.jpg`), Buffer.from(image.data, "base64"));
  }
  console.log(JSON.stringify({ ok: true, selectedStudio, identity, outDir }, null, 2));
} finally {
  if (started) await client.callTool("start_stop_play", { is_start: false }, 60000).catch(() => {});
  client.close();
}
