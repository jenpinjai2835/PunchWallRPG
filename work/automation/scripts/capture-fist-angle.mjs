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
    studioName: "PunchWallRPGPlayable",
    outDir: path.join(REPOSITORY_ROOT, "work", "qc-fist-angle"),
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

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const client = new McpClient(findStudioMcp(args.studioMcp), "punch-wall-fist-angle-qc");
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
    assertCondition(!start.isError, `Could not start play: ${start.text}`);
    started = true;
    await waitForDataModels(client, ["Server", "Client"], 60000);
    await sleep(6500);
    fs.mkdirSync(args.outDir, { recursive: true });
    const preparation = await client.callTool("execute_luau", {
      datamodel_type: "Server",
      code: "local c=game.ServerStorage.PunchWallAutomation c:Invoke('Reset') c:Invoke('SetStats',{Coins=1000000,Power=1000,WallLevel=99}) for _,name in ipairs({'Boxing Glove','Iron Knuckle','Thunder Fist','Titan Gauntlet'}) do local r=c:Invoke('BuyFist',name) assert(r.ok==true,name) end for _,name in ipairs({'Crimson Vanguard Fist','Stormbreaker Fist','Celestial Titan Fist'}) do local r=c:Invoke('GrantPremiumFist',name) assert(r.ok==true,name) end return 'ready'",
    });
    assertCondition(!preparation.isError, `Could not prepare fist inventory: ${preparation.text}`);
    // The first equip can coincide with the one-time hero-gear loading veil.
    // Let it clear so the baseline capture records the avatar, not the veil.
    await sleep(4500);
    const items = [
      ["Starter Glove", "starter"],
      ["Iron Knuckle", "iron"],
      ["Thunder Fist", "thunder"],
      ["Titan Gauntlet", "titan"],
      ["Celestial Titan Fist", "celestial"],
    ];
    for (const [item, label] of items) {
      const prepare = await client.callTool("execute_luau", {
        datamodel_type: "Client",
        code: `local RS=game:GetService('ReplicatedStorage') local p=game.Players.LocalPlayer RS.PunchWallEvents.ActionRequest:FireServer({action='EquipFist',target='${item}'}) local m local deadline=os.clock()+5 repeat task.wait(.05) m=p.Character and p.Character:FindFirstChild('Equipped Kaiju Gauntlet') until os.clock()>=deadline or (p.RPGStats.EquippedFist.Value=='${item}' and m and m:GetAttribute('ItemVisualReady')==true) task.wait(.45) local ch=p.Character local root=ch and ch:FindFirstChild('HumanoidRootPart') local hand=ch and (ch:FindFirstChild('RightHand') or ch:FindFirstChild('Right Arm')) assert(root and hand and m,'fist visual not ready') local cam=workspace.CurrentCamera local pos=root.Position+root.CFrame.LookVector*4.7+root.CFrame.RightVector*1.55+Vector3.new(0,1.35,0) cam.CameraType=Enum.CameraType.Scriptable cam.CFrame=CFrame.lookAt(pos,hand.Position+Vector3.new(0,.08,0)) cam.Focus=CFrame.new(hand.Position) return m:GetAttribute('VisualTemplate')`,
      });
      assertCondition(!prepare.isError, `Could not prepare ${item}: ${prepare.text}`);
      await sleep(450);
      const shot = await client.callTool("screen_capture", {
        capture_id: `FistAngleQC_${label}`,
      }, 60000);
      assertCondition(!shot.isError, `Could not capture ${item}: ${shot.text}`);
      const image = imageContent(shot);
      assertCondition(image, `No image returned for ${item}`);
      fs.writeFileSync(path.join(args.outDir, `${label}.jpg`), Buffer.from(image.data, "base64"));
      const sideCamera = await client.callTool("execute_luau", {
        datamodel_type: "Client",
        code: "local p=game.Players.LocalPlayer local ch=p.Character local root=ch and ch:FindFirstChild('HumanoidRootPart') local hand=ch and (ch:FindFirstChild('RightHand') or ch:FindFirstChild('Right Arm')) assert(root and hand,'side camera target missing') local cam=workspace.CurrentCamera local pos=root.Position+root.CFrame.RightVector*5.5+root.CFrame.LookVector*2.5+Vector3.new(0,1.6,0) cam.CameraType=Enum.CameraType.Scriptable cam.CFrame=CFrame.lookAt(pos,hand.Position+Vector3.new(0,.02,0)) cam.Focus=CFrame.new(hand.Position) return true",
      });
      assertCondition(!sideCamera.isError, `Could not position side camera for ${item}: ${sideCamera.text}`);
      await sleep(250);
      const sideShot = await client.callTool("screen_capture", {
        capture_id: `FistAngleQC_${label}_side`,
      }, 60000);
      assertCondition(!sideShot.isError, `Could not capture side view for ${item}: ${sideShot.text}`);
      const sideImage = imageContent(sideShot);
      assertCondition(sideImage, `No side image returned for ${item}`);
      fs.writeFileSync(path.join(args.outDir, `${label}-side.jpg`), Buffer.from(sideImage.data, "base64"));
      if (label === "starter" || label === "titan" || label === "celestial") {
        const punchPose = await client.callTool("execute_luau", {
          datamodel_type: "Client",
          code: "local RunService=game:GetService('RunService') local p=game.Players.LocalPlayer local ch=p.Character local root=ch and ch:FindFirstChild('HumanoidRootPart') local hand=ch and (ch:FindFirstChild('RightHand') or ch:FindFirstChild('Right Arm')) local gui=p.PlayerGui:WaitForChild('PunchWallHUD') local a=gui:WaitForChild('PunchWallClientAutomation') assert(root and hand and a:Invoke('Punch')==true,'punch pose unavailable') task.wait(.1) local key='PunchWallFistCaptureCamera' RunService:UnbindFromRenderStep(key) RunService:BindToRenderStep(key,Enum.RenderPriority.Camera.Value+1000,function() local currentHand=ch:FindFirstChild('RightHand') or ch:FindFirstChild('Right Arm') if not currentHand or not root.Parent then return end local cam=workspace.CurrentCamera local target=currentHand.Position local pos=root.Position+root.CFrame.LookVector*5.8+root.CFrame.RightVector*2.1+Vector3.new(0,1.55,0) cam.CameraType=Enum.CameraType.Scriptable cam.CFrame=CFrame.lookAt(pos,target) cam.Focus=CFrame.new(target) end) return true",
        }, 35000);
        assertCondition(!punchPose.isError, `Could not stage punch pose for ${item}: ${punchPose.text}`);
        const punchShot = await client.callTool("screen_capture", {
          capture_id: `FistAngleQC_${label}_punch`,
        }, 60000);
        assertCondition(!punchShot.isError, `Could not capture punch pose for ${item}: ${punchShot.text}`);
        const punchImage = imageContent(punchShot);
        assertCondition(punchImage, `No punch image returned for ${item}`);
        fs.writeFileSync(path.join(args.outDir, `${label}-punch.jpg`), Buffer.from(punchImage.data, "base64"));
        await client.callTool("execute_luau", {
          datamodel_type: "Client",
          code: "game:GetService('RunService'):UnbindFromRenderStep('PunchWallFistCaptureCamera') return true",
        }, 35000);
        await sleep(800);
      }
    }
    console.log(JSON.stringify({
      ok: true,
      selectedStudio,
      selectedPlace,
      outDir: args.outDir,
    }, null, 2));
  } finally {
    if (started) await client.callTool("start_stop_play", { is_start: false }, 60000).catch(() => {});
    client.close();
  }
}
main().catch((error) => {
  console.error(error.stack ?? error.message);
  process.exitCode = 1;
});
