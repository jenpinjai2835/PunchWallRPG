#!/usr/bin/env node
import {
  McpClient,
  assertPlaceIdentity,
  findStudioMcp,
  inspectSelectedPlace,
  normalizeMouseInputArgs,
  selectStudioStrict,
  sleep,
  waitForDataModels,
} from "./studio_mcp_client.mjs";

const studioInstanceId = process.argv[2] || "03d68549-ed19-438d-bb8c-922b03f9d7b1";
const action = process.argv[3] || "setup";
const studioName = "^SmashWall_v1[.]0[.]1[.]rbxlx$";
const deviceName = "PunchWall iPhone 17 Visual 874x402";

function requireTool(result, label) {
  if (result?.isError) throw new Error(`${label}: ${result.text}`);
  return result;
}

async function invoke(client, type, code, label) {
  return requireTool(await client.callTool("execute_luau", {
    datamodel_type: type,
    code,
  }, 60000), label);
}

async function main() {
  const client = new McpClient(findStudioMcp(), "punch-wall-iphone17-state-driver");
  await client.initialize();
  try {
    await selectStudioStrict(client, { studioInstanceId, studioName, pollAttempts: 10, pollMs: 2000 });
    const place = await inspectSelectedPlace(client);
    if (action !== "stop" && action !== "console" && action !== "inspect_settings" && action !== "test_hud_click") assertPlaceIdentity(place, { placeName: studioName });

    if (action === "console") {
      const output = requireTool(await client.callTool("get_console_output", {}, 30000), "read Studio console");
      console.log(output.text || "");
      return;
    }

    if (action === "setup") {
      await invoke(client, "Edit", `local H=game:GetService('HttpService') local S=game:GetService('StudioDeviceSimulatorService') local n=${JSON.stringify(deviceName)} local id for _,candidate in ipairs(S:GetDeviceListAsync()) do if S:GetDeviceInfoAsync(candidate).Name==n then id=candidate break end end local config={Name=n,Width=874,Height=402,PixelDensity=460,DeviceForm=Enum.DeviceForm.Phone} if id then S:UpdateDeviceAsync(id,config) else id=S:CreateDeviceAsync(config) end S:SetDeviceAsync(id) S:SetOrientationAsync(Enum.ScreenOrientation.LandscapeLeft) S:SetScalingModeAsync(Enum.DeviceSimulatorScalingMode.FitToWindow) task.wait(.4) return H:JSONEncode({id=id,resolution=S:GetResolutionAsync(),active=S:GetDeviceAsync()==id})`, "configure iPhone 17 visual device");
      requireTool(await client.callTool("start_stop_play", { is_start: true }, 60000), "start visual inspection");
      await waitForDataModels(client, ["Server", "Client"], 60000);
      await sleep(7000);
      await invoke(client, "Server", `local H=game:GetService('HttpService') local a=game.ServerStorage.PunchWallAutomation a:Invoke('Reset') return H:JSONEncode(a:Invoke('SetStats',{Coins=50000,Power=1000,Honor=500,Depth=75,WallLevel=55,WallXP=0,Rebirths=0,SpinCredits=1,OwnedFistsJSON='["Starter Glove","Boxing Glove"]',EquippedFist='Starter Glove',PetInventoryJSON='["Forest Pup","Miner Cat","Crystal Fox","Crimson Phoenix","Storm Wyvern","Celestial Guardian"]',EquippedPetsJSON='["Crimson Phoenix","Storm Wyvern","Celestial Guardian"]',DiscoveredPetsJSON='["Forest Pup","Miner Cat","Crystal Fox","Crimson Phoenix","Storm Wyvern","Celestial Guardian"]',LockedPetsJSON='[]',OwnedHonorItemsJSON='["vanguard_trail"]',EquippedHonorItem='vanguard_trail',SettingsJSON=H:JSONEncode({motion=true,sound=true,uiScale=1})}))`, "seed visual state");
      await invoke(client, "Client", "local a=game.Players.LocalPlayer.PlayerGui.PunchWallHUD.PunchWallClientAutomation a:Invoke('CloseMenus') return true", "close windows");
      console.log(JSON.stringify({ ok: true, action, state: "HUD" }));
      return;
    }

    if (action === "stop") {
      requireTool(await client.callTool("start_stop_play", { is_start: false }, 60000), "stop visual inspection");
      await waitForDataModels(client, ["Edit"], 60000);
      await invoke(client, "Edit", `local H=game:GetService('HttpService') local S=game:GetService('StudioDeviceSimulatorService') pcall(function() S:StopSimulationAsync() end) local removed=0 for _,id in ipairs(S:GetDeviceListAsync()) do local info=S:GetDeviceInfoAsync(id) if info.Name==${JSON.stringify(deviceName)} and info.IsCustom then S:RemoveDeviceAsync(id) removed+=1 end end return H:JSONEncode({default=S:GetDeviceAsync()=='default',removed=removed})`, "cleanup visual device");
      console.log(JSON.stringify({ ok: true, action }));
      return;
    }

    if (action === "inspect_settings") {
      const result = await invoke(client, "Client", "local H=game:GetService('HttpService') local g=game.Players.LocalPlayer.PlayerGui.PunchWallHUD local a=g.PunchWallClientAutomation a:Invoke('CloseMenus') a:Invoke('OpenSettings','iphone17_inspect') task.wait(.4) local rows={} for _,name in ipairs({'SoundOn','SoundOff','MotionOn','MotionCalm','Scale80','Scale100','Scale120'}) do local b=g.SettingsWindow:FindFirstChild(name,true) rows[name]=b and {visible=b.Visible,z=b.ZIndex,text=b.Text,textTransparency=b.TextTransparency,backgroundTransparency=b.BackgroundTransparency,background=tostring(b.BackgroundColor3),position=tostring(b.AbsolutePosition),size=tostring(b.AbsoluteSize),parentZ=b.Parent.ZIndex} or false end return H:JSONEncode(rows)", "inspect Settings options");
      console.log(result.text);
      return;
    }

    if (action === "test_hud_click") {
      await invoke(client, "Client", "local a=game.Players.LocalPlayer.PlayerGui.PunchWallHUD.PunchWallClientAutomation a:Invoke('CloseMenus') return true", "prepare HUD click");
      const args = await normalizeMouseInputArgs(client, {
        datamodel_type: "Client",
        actions: [
          { action: "moveTo", instance_path_segments: ["LocalPlayer", "PlayerGui", "PunchWallHUD", "PixelPerfectHeroCityHUD", "InventoryButton"] },
          { action: "mouseButtonDown", mouse_button: "left", instance_path_segments: ["LocalPlayer", "PlayerGui", "PunchWallHUD", "PixelPerfectHeroCityHUD", "InventoryButton"] },
          { action: "wait", wait_time_ms: 60 },
          { action: "mouseButtonUp", mouse_button: "left", instance_path_segments: ["LocalPlayer", "PlayerGui", "PunchWallHUD", "PixelPerfectHeroCityHUD", "InventoryButton"] },
        ],
      });
      requireTool(await client.callTool("user_mouse_input", args, 60000), "click Inventory HUD");
      await sleep(350);
      const result = await invoke(client, "Client", "local H=game:GetService('HttpService') local g=game.Players.LocalPlayer.PlayerGui.PunchWallHUD return H:JSONEncode({menu=g.GameMenu.Visible,inventory=g.GameMenu.FunctionalInventory.Visible})", "verify HUD click");
      console.log(result.text);
      return;
    }

    const clientActions = {
      hud: "a:Invoke('CloseMenus')",
      inventory_all: "a:Invoke('OpenInventory','All'); a:Invoke('SelectInventoryCategory','All')",
      inventory_pets: "a:Invoke('OpenInventory','Pets'); a:Invoke('SelectInventoryCategory','Pets')",
      inventory_honor: "a:Invoke('OpenInventory','Honor'); a:Invoke('SelectInventoryCategory','Honor')",
      shop_fists: "a:Invoke('OpenShopPage','Fists')",
      shop_premium: "a:Invoke('OpenShopPage','Premium')",
      shop_boosts: "a:Invoke('OpenShopPage','Boosts')",
      shop_honor: "a:Invoke('OpenShopPage','Honor')",
      shop_robux: "a:Invoke('OpenShopPage','Robux')",
      missions: "a:Invoke('OpenMore')",
      rebirth_locked: "a:Invoke('OpenRebirth','iphone17_visual')",
      rebirth_confirm: "a:Invoke('OpenRebirth','iphone17_visual'); task.wait(.2); a:Invoke('InvokeRebirthAction','Review')",
      settings: "a:Invoke('OpenSettings','iphone17_visual')",
      spin: "a:Invoke('OpenSpin')",
    };
    const code = clientActions[action];
    if (!code) throw new Error(`Unknown action ${action}`);
    await invoke(client, "Client", `local a=game.Players.LocalPlayer.PlayerGui.PunchWallHUD.PunchWallClientAutomation a:Invoke('CloseMenus') task.wait(.1) ${code} task.wait(.35) return true`, `open ${action}`);
    console.log(JSON.stringify({ ok: true, action }));
  } finally {
    client.close();
  }
}

main().catch((error) => {
  console.error(JSON.stringify({ ok: false, error: error.message }));
  process.exitCode = 1;
});
