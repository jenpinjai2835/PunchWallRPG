#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
import {
  McpClient,
  findStudioMcp,
  inspectSelectedPlace,
  selectStudioStrict,
  waitForDataModels,
} from "./studio_mcp_client.mjs";

function parseArgs(argv) {
  const args = {
    outDir: path.resolve("work/docs/evidence/shop-visual-qc-20260819"),
    studioName: "PunchWallRPG",
  };
  for (let index = 0; index < argv.length; index += 1) {
    const key = argv[index];
    const value = argv[index + 1];
    if (key === "--out-dir") args.outDir = path.resolve(value);
    else if (key === "--studio-name") args.studioName = value;
    else if (key === "--studio-instance-id") args.studioInstanceId = value;
    else throw new Error(`Unknown argument: ${key}`);
    index += 1;
  }
  return args;
}

function imageFrom(result) {
  return result.content.find((item) => item.type === "image" && item.data);
}

function sha256(file) {
  return crypto.createHash("sha256").update(fs.readFileSync(file)).digest("hex");
}

async function call(client, name, args = {}, timeoutMs = 30000) {
  const result = await client.callTool(name, args, timeoutMs);
  if (result.isError) throw new Error(`${name} failed: ${result.text}`);
  return result;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  fs.mkdirSync(args.outDir, { recursive: true });
  const client = new McpClient(findStudioMcp(), "punch-wall-shop-visual-qc");
  const attestedFiles = [
    "work/punch-wall-rpg/src/shared/GameConfig.lua",
    "work/punch-wall-rpg/src/shared/FistVisualBuilder.lua",
    "work/punch-wall-rpg/src/server/ProfilePersistence.lua",
    "work/punch-wall-rpg/src/server/PunchWallBootstrap.server.lua",
    "work/punch-wall-rpg/src/client/PunchWallClient.client.lua",
    "work/automation/flows/long-run-catalog-progression.json",
    "work/automation/flows/fist-items-icon-ui.json",
    "work/automation/flows/honor-product-receipts.json",
    "work/automation/scripts/long-run-content-contract.mjs",
    "work/automation/scripts/fist-icon-identity-contract.mjs",
    "work/automation/scripts/honor-product-receipts-contract.mjs",
  ].map((file) => path.resolve(file));
  const summary = {
    ok: false,
    capturedAtUtc: new Date().toISOString(),
    captures: [],
    selectedStudio: null,
    selectedPlace: null,
    sourceFingerprints: Object.fromEntries(attestedFiles.map((file) => [file, sha256(file)])),
  };
  let started = false;
  try {
    await client.initialize();
    summary.selectedStudio = await selectStudioStrict(client, {
      studioInstanceId: args.studioInstanceId,
      studioName: args.studioName,
      pollAttempts: 15,
      pollMs: 3000,
    });
    summary.selectedPlace = await inspectSelectedPlace(client);
    await call(client, "start_stop_play", { is_start: true }, 35000);
    started = true;
    await waitForDataModels(client, ["Server", "Client"], 60000);
    await new Promise((resolve) => setTimeout(resolve, 7000));

    for (const page of ["Fists", "Premium", "Boosts", "Honor", "Robux"]) {
      const opened = await call(client, "execute_luau", {
        datamodel_type: "Client",
        code: `local H=game:GetService('HttpService')
local g=game.Players.LocalPlayer.PlayerGui:WaitForChild('PunchWallHUD')
local a=g:WaitForChild('PunchWallClientAutomation')
assert(a:Invoke('OpenTab','Fists')==true,'shop shell did not open')
assert(a:Invoke('OpenShopPage','${page}')==true,'shop page did not open')
task.wait(.55)
local s=g.GameMenu.FunctionalHeroShop
assert(g.GameMenu.Visible and s.Visible,'shop is not visible for capture')
local cards,textFailures,previewFits=0,{},0
for _,d in ipairs(s:GetDescendants()) do
  if d:IsA('Frame') and d.Name:match('ShopCard$') then cards+=1 end
  if (d:IsA('TextLabel') or d:IsA('TextButton')) and d.Visible and not d.TextFits then table.insert(textFailures,d:GetFullName()) end
  if d:IsA('ViewportFrame') and d.Name=='PremiumPetPreview' and d:GetAttribute('PreviewFit')=='BoundingSphereSafeV2' then previewFits+=1 end
end
return H:JSONEncode({page='${page}',cards=cards,textFailures=textFailures,previewFits=previewFits,modalSizing=g.GameMenu:GetAttribute('ShopModalSizing')})`,
      }, 30000);
		const diagnostics = JSON.parse(opened.text);
		if (diagnostics.textFailures.length > 0) {
			throw new Error(`${page} contains clipped or overflowing text: ${diagnostics.textFailures.join(", ")}`);
		}
		if (diagnostics.modalSizing !== "DesktopSafeMarginV2") {
			throw new Error(`${page} did not use the desktop safe-margin profile`);
		}
		if (page === "Premium" && diagnostics.previewFits !== 3) {
			throw new Error(`Premium preview fit count was ${diagnostics.previewFits}, expected 3`);
		}
      const captureId = `ShopQC_${page}_V2`;
      const captured = await call(client, "screen_capture", { capture_id: captureId }, 60000);
      const image = imageFrom(captured);
      if (!image) throw new Error(`screen_capture returned no image for ${page}`);
      const extension = image.mimeType === "image/jpeg" ? "jpg" : "png";
      const file = path.join(args.outDir, `${page.toLowerCase()}.${extension}`);
      fs.writeFileSync(file, Buffer.from(image.data, "base64"));
      summary.captures.push({ page, file, diagnostics });

      if (page === "Fists" && diagnostics.cards > 6) {
        await call(client, "execute_luau", {
          datamodel_type: "Client",
          code: `local g=game.Players.LocalPlayer.PlayerGui.PunchWallHUD
local scroll=g.GameMenu.FunctionalHeroShop:FindFirstChild('FistCatalogScroll')
assert(scroll,'missing fist catalog scroll')
scroll.CanvasPosition=Vector2.new(0,math.max(0,scroll.AbsoluteCanvasSize.Y-scroll.AbsoluteSize.Y))
task.wait(.35)
return scroll.CanvasPosition.Y>0`,
        });
        const endgameCapture = await call(client, "screen_capture", { capture_id: "ShopQC_Fists_Endgame_V1" }, 60000);
        const endgameImage = imageFrom(endgameCapture);
        if (!endgameImage) throw new Error("screen_capture returned no image for Fists endgame");
        const endgameExtension = endgameImage.mimeType === "image/jpeg" ? "jpg" : "png";
        const endgameFile = path.join(args.outDir, `fists-endgame.${endgameExtension}`);
        fs.writeFileSync(endgameFile, Buffer.from(endgameImage.data, "base64"));
        summary.captures.push({ page: "FistsEndgame", file: endgameFile, diagnostics });
      }
    }

    const consoleResult = await call(client, "get_console_output", {}, 30000);
    fs.writeFileSync(path.join(args.outDir, "console.txt"), consoleResult.text);
    await call(client, "start_stop_play", { is_start: false }, 35000);
    started = false;
    const postStopConsole = await call(client, "get_console_output", {}, 30000);
    fs.writeFileSync(path.join(args.outDir, "console-post-stop.txt"), postStopConsole.text);
    summary.ok = true;
    fs.writeFileSync(path.join(args.outDir, "capture-summary.json"), JSON.stringify(summary, null, 2));
    process.stdout.write(`${JSON.stringify(summary, null, 2)}\n`);
  } catch (error) {
    summary.error = error.message;
    fs.writeFileSync(path.join(args.outDir, "capture-summary.json"), JSON.stringify(summary, null, 2));
    process.stderr.write(`${JSON.stringify(summary, null, 2)}\n`);
    process.exitCode = 1;
  } finally {
    if (started) await client.callTool("start_stop_play", { is_start: false }, 35000).catch(() => {});
    client.close();
  }
}

main();
