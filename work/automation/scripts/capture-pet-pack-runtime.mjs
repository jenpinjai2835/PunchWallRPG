import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import {
  McpClient,
  assertCondition,
  assertPlaceIdentity,
  findStudioMcp,
  inspectSelectedPlace,
  selectStudioStrict,
  sleep,
  waitForDataModels,
} from "./studio_mcp_client.mjs";

const SCRIPT_DIRECTORY = path.dirname(fileURLToPath(import.meta.url));
const REPOSITORY_ROOT = path.resolve(SCRIPT_DIRECTORY, "..", "..", "..");

function parseArgs(argv) {
  const args = {
    outDir: path.join(REPOSITORY_ROOT, "work", "docs", "evidence", "pet-pack-70715599928632"),
  };
  for (let index = 0; index < argv.length; index += 1) {
    const key = argv[index];
    const value = argv[index + 1];
    if (key === "--studio-name") args.studioName = value;
    else if (key === "--studio-instance-id") args.studioInstanceId = value;
    else if (key === "--place-name") args.placeName = value;
    else if (key === "--out-dir") args.outDir = path.resolve(value);
    else if (key === "--studio-mcp") args.studioMcp = value;
    else throw new Error(`Unknown argument: ${key}`);
    index += 1;
  }
  return args;
}

function imageContent(result) {
  return result.content.find((item) => item.type === "image" && item.data);
}

async function saveCapture(client, outputPath, captureId) {
  const shot = await client.callTool("screen_capture", { capture_id: captureId }, 60000);
  assertCondition(!shot.isError, `Could not capture ${captureId}: ${shot.text}`);
  const image = imageContent(shot);
  assertCondition(image, `No image returned for ${captureId}`);
  fs.writeFileSync(outputPath, Buffer.from(image.data, "base64"));
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const client = new McpClient(findStudioMcp(args.studioMcp), "punch-wall-pet-pack-runtime-capture");
  let started = false;
  try {
    await client.initialize();
    const selectedStudio = await selectStudioStrict(client, {
      studioInstanceId: args.studioInstanceId,
      studioName: args.studioName,
      pollAttempts: 15,
      pollMs: 3000,
    });
    const selectedPlace = await inspectSelectedPlace(client);
    assertPlaceIdentity(selectedPlace, { placeName: args.placeName });
    const start = await client.callTool("start_stop_play", { is_start: true }, 60000);
    assertCondition(!start.isError, `Could not start Play: ${start.text}`);
    started = true;
    await waitForDataModels(client, ["Server", "Client"], 60000);
    await sleep(6500);
    fs.mkdirSync(args.outDir, { recursive: true });

    const inventorySetup = await client.callTool("execute_luau", {
      datamodel_type: "Server",
      code: "local H=game:GetService('HttpService') local a=game.ServerStorage.PunchWallAutomation local names={'Forest Pup','Miner Cat','Crystal Fox','Lava Dragon','Secret Titan Golem','Crimson Phoenix','Storm Wyvern','Celestial Guardian'} a:Invoke('Reset') local r=a:Invoke('SetStats',{PetInventoryJSON=H:JSONEncode(names),EquippedPetsJSON='[]',LockedPetsJSON='[]',DiscoveredPetsJSON=H:JSONEncode(names)}) assert(r.ok,'pet inventory setup failed') return true",
    });
    assertCondition(!inventorySetup.isError, `Could not stage Inventory pets: ${inventorySetup.text}`);
    const openInventory = await client.callTool("execute_luau", {
      datamodel_type: "Client",
      code: "local p=game.Players.LocalPlayer local g=p.PlayerGui:WaitForChild('PunchWallHUD') local a=g:WaitForChild('PunchWallClientAutomation') a:Invoke('OpenInventory') a:Invoke('SelectInventoryCategory','Pets') a:Invoke('SetInventorySearch','') a:Invoke('SetInventoryRarity','All') a:Invoke('RequestAction',{action='RequestSync'}) task.wait(1) local grid=g.GameMenu.FunctionalInventory.InventoryWindow.InventoryBody.InventoryGridPane.InventoryGrid local ready=0 for _,card in ipairs(grid:GetChildren()) do if card:IsA('GuiObject') and card.Visible and card:GetAttribute('InventoryCategory')=='Pets' then local vp=card:FindFirstChild('ItemPetPreview',true) if vp and vp:GetAttribute('PreviewReady')==true then ready+=1 end end end assert(ready==8,'expected 8 model-matched pet previews, got '..ready) return true",
    });
    assertCondition(!openInventory.isError, `Could not open pet Inventory: ${openInventory.text}`);
    await sleep(500);
    await saveCapture(
      client,
      path.join(args.outDir, "inventory-eight-pack-pets.jpg"),
      "PetPack70715599928632_InventoryEight"
    );

    const premiumSetup = await client.callTool("execute_luau", {
      datamodel_type: "Server",
      code: "local a=game.ServerStorage.PunchWallAutomation a:Invoke('Reset') local n=0 for _,name in ipairs({'Crimson Phoenix','Storm Wyvern','Celestial Guardian'}) do local r=a:Invoke('GrantPremiumPet',name) if r.ok then n+=1 end end assert(n==3,'premium grant failed') return true",
    });
    assertCondition(!premiumSetup.isError, `Could not stage premium pets: ${premiumSetup.text}`);
    const premiumCamera = await client.callTool("execute_luau", {
      datamodel_type: "Client",
      code: "local p=game.Players.LocalPlayer local g=p.PlayerGui:WaitForChild('PunchWallHUD') local a=g:WaitForChild('PunchWallClientAutomation') a:Invoke('CloseInventory') local root=p.Character and p.Character:FindFirstChild('HumanoidRootPart') local folder=workspace:FindFirstChild(p.Name..' Client Companions') local deadline=os.clock()+5 repeat task.wait(.05) until os.clock()>deadline or (folder and #folder:GetChildren()==3) assert(root and folder and #folder:GetChildren()==3,'premium formation unavailable') local cam=workspace.CurrentCamera local pos=root.Position-root.CFrame.LookVector*10+root.CFrame.RightVector*.4+Vector3.new(0,3.1,0) cam.CameraType=Enum.CameraType.Scriptable cam.CFrame=CFrame.lookAt(pos,root.Position+Vector3.new(0,1.6,0)) cam.Focus=CFrame.new(root.Position+Vector3.new(0,1.6,0)) task.wait(1) return true",
    });
    assertCondition(!premiumCamera.isError, `Could not stage premium formation: ${premiumCamera.text}`);
    await saveCapture(
      client,
      path.join(args.outDir, "premium-pack-pets-formation.jpg"),
      "PetPack70715599928632_PremiumFormation"
    );

    const consoleResult = await client.callTool("get_console_output", {});
    assertCondition(!consoleResult.isError, `Could not read console: ${consoleResult.text}`);
    assertCondition(!/(infinite yield|stack begin|server script error|client script error|model parse error)/i.test(consoleResult.text),
      `Runtime console contains a blocking error: ${consoleResult.text}`);
    console.log(JSON.stringify({ ok: true, selectedStudio, selectedPlace, outDir: args.outDir }, null, 2));
  } finally {
    if (started) await client.callTool("start_stop_play", { is_start: false }, 60000).catch(() => {});
    client.close();
  }
}

main().catch((error) => {
  console.error(error.stack ?? error.message);
  process.exitCode = 1;
});
