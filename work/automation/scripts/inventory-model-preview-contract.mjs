#!/usr/bin/env node
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
const repositoryRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../../..");
const sourcePath = path.join(repositoryRoot, "work/punch-wall-rpg/src/client/InventoryUI.lua");
const source = fs.readFileSync(sourcePath, "utf8").replace(/\r\n?/g, "\n");
function block(start, end) {
  const first = source.indexOf(start), last = source.indexOf(end, first + start.length);
  assert(first >= 0 && last > first, "Missing production source boundary: " + start);
  return source.slice(first, last);
}

function runProductionLuau(name, code) {
  const optionIndex = process.argv.indexOf("--luau-tool-dir");
  const explicitDirectory = optionIndex >= 0
    ? process.argv[optionIndex + 1] : process.env.PUNCH_WALL_LUAU_TOOL_DIR;
  const directories = explicitDirectory ? [explicitDirectory] : [
    path.join(repositoryRoot, ".tools/luau"),
    ...String(process.env.PATH || "").split(path.delimiter),
    ...fs.readdirSync(os.tmpdir(), { withFileTypes: true })
      .filter((entry) => entry.isDirectory() && /^codex-luau-/i.test(entry.name))
      .map((entry) => path.join(os.tmpdir(), entry.name)),
  ];
  const executable = directories.filter(Boolean)
    .map((directory) => path.join(directory, process.platform === "win32" ? "luau.exe" : "luau"))
    .find((candidate) => fs.existsSync(candidate));
  assert(executable, "BLOCKED: Luau runtime unavailable; pass --luau-tool-dir or PUNCH_WALL_LUAU_TOOL_DIR");
  const temporaryDirectory = fs.mkdtempSync(path.join(os.tmpdir(), name + "-"));
  const temporaryFile = path.join(temporaryDirectory, "contract.luau");
  try {
    fs.writeFileSync(temporaryFile, code);
    const result = spawnSync(executable, [temporaryFile], { encoding: "utf8", timeout: 30000 });
    assert.ifError(result.error);
    assert.equal(result.status, 0, result.stderr || result.stdout || "Luau contract failed without output");
    return result.stdout.trim();
  } finally {
    if (fs.existsSync(temporaryFile)) fs.unlinkSync(temporaryFile);
    fs.rmdirSync(temporaryDirectory);
  }
}

let code=String.raw`
local InventoryUI={}
local count,clones=0,0
local function check(ok,m)count+=1;assert(ok,m)end
local function typeof(x)return type(x)=='table' and x.__kind or type(x)end
local function safeName(x)return x end
local function warn()end
local function vec(x,y,z)return setmetatable({X=x,Y=y,Z=z},{__add=function(a,b)return vec(a.X+b.X,a.Y+b.Y,a.Z+b.Z)end})end
local Vector3={new=vec}
local CFrame={lookAt=function(from,to)return {From=from,To=to}end}
local function part(kind)
 local p={kind=kind}
 function p:IsA(name)return self.kind==name end
 function p:Destroy()self.destroyed=true end
 return p
end
local function model()
 local p={__kind='Instance',children={part('BasePart'),part('LuaSourceContainer'),part('ParticleEmitter'),part('Beam'),part('Trail'),part('Light'),part('Highlight')}}
 function p:IsA(name)return name=='Model'end
 function p:Destroy()self.destroyed=true end
 function p:GetDescendants()return self.children end
 function p:GetBoundingBox()return {Position=vec(0,.7,0)},vec(1.5,1.8,1.1)end
 function p:Clone()clones+=1;return model()end
 return setmetatable(p,{__newindex=function(t,k,v)rawset(t,k,v);if k=='Parent' and type(v)=='table' and v.children then table.insert(v.children,t)end end})
end
local function preview()
 local world={children={}}
 function world:GetChildren()return self.children end
 function world:ClearAllChildren()for _,child in ipairs(self.children)do child:Destroy()end;table.clear(self.children)end
 local viewport={attrs={}}
 function viewport:SetAttribute(k,v)self.attrs[k]=v end
 return {world=world,viewport=viewport,camera={FieldOfView=34}}
end
`+block('function InventoryUI:_getPetPreviewMaster(', 'function InventoryUI:_applyItemArt(')+block('function InventoryUI:Destroy()', 'return InventoryUI')+String.raw`
local builds={}
local s=setmetatable({_petPreviewMasters={},_fistPreviewMasters={}},{__index=InventoryUI})
s.BuildFistPreview=function(name) builds[name]=(builds[name] or 0)+1;if name=='Unsupported'then return nil end;if name=='Broken'then error('failed')end;return model()end
s.BuildPetPreview=function(name)builds[name]=(builds[name] or 0)+1;return model()end
local p=preview()
local fist={category='Fists',name='Default Fists'}
local ok,mode=s:_applyModelPreview(p,fist)
check(ok and mode=='SharedFistViewportV1','fist uses shared preview')
check(builds['Default Fists']==1 and clones==1,'build and clone once')
local first=p.world.children[1]
check(first.children[1].Anchored and not first.children[1].CanCollide and not first.children[1].CanTouch and not first.children[1].CanQuery,'preview cannot participate in physics')
check(first.children[2].destroyed and first.children[3].destroyed,'scripts and emitters removed')
for _,index in ipairs({4,5,6,7}) do check(first.children[index].destroyed,'preview effect removed: '..first.children[index].kind) end
check(p.camera.CFrame.From.Z>p.camera.CFrame.To.Z,'camera faces backhand')
check(p.camera.CFrame.To.Y==.7,'camera targets bounds center')
s:_applyModelPreview(p,fist)
check(clones==1 and p.world.children[1]==first,'same preview clone retained')
s:_applyModelPreview(p,{category='Fists',name='Default Fists',locked=true})
check(clones==1 and p.viewport.ImageTransparency==.34,'locked treatment does not rebuild')
local q=preview();s:_applyModelPreview(q,fist)
check(builds['Default Fists']==1 and clones==2,'card and detail share master')
local pet={category='Pets',name='Cat',previewPet='Cat'}
s:_applyModelPreview(p,pet)
check(first.destroyed and p.fistName==nil and p.petName=='Cat','fist to pet clears old clone and identity')
check(p.viewport.attrs.PreviewFistName=='' and p.viewport.attrs.PreviewPetName=='Cat','pet identity attrs reset')
s:_applyModelPreview(p,fist)
check(p.petName==nil and p.fistName=='Default Fists' and builds['Default Fists']==1,'pet to fist reuses master')
check(not s:_applyModelPreview(p,{category='Fists',name='Unsupported'}),'unsupported falls back')
check(not p.viewport.Visible and #p.world.children==0 and p.fistName==nil,'unsupported clears stale geometry')
s:_applyModelPreview(p,{category='Fists',name='Unsupported'})
check(builds.Unsupported==1,'unsupported cache bounded')
check(not s:_applyModelPreview(p,{category='Fists',name='Broken'}),'callback failure falls back')
s:_applyModelPreview(p,{category='Fists',name='Broken'})
check(builds.Broken==1,'failure cache bounded')
check(not s:_applyModelPreview(p,{category='Boosts',name='Speed Boost'}),'other categories retain art fallback')
check(not s:_applyModelPreview(nil,fist),'missing viewport safely ignored')
local bare=setmetatable({_petPreviewMasters={},_fistPreviewMasters={}},{__index=InventoryUI})
check(not bare:_applyModelPreview(preview(),fist),'optional callback absent is safe')
local invalid=part('BasePart');invalid.__kind='Instance'
bare.BuildFistPreview=function()return invalid end
check(not bare:_applyModelPreview(preview(),fist),'non-model callback result falls back')
check(invalid.destroyed and bare._fistPreviewMasters['Default Fists']==false,'invalid instance destroyed and failure cached')
for _,name in ipairs({'_cancelPendingDetailRender','_cancelDeleteConfirmation','_stopTimedRefresh','_clearCards','_disconnectPool'})do s[name]=function()end end
for _,name in ipairs({'_connections','_actionConnections','_actionButtonRefsByKey','_activeActionButtons','_actionModelsByKey','_cardRefsByKey','_sparseSlotPool'})do s[name]={}end
local master=s._fistPreviewMasters['Default Fists']
s:Destroy()
check(master.destroyed and next(s._fistPreviewMasters)==nil and next(s._petPreviewMasters)==nil,'destroy frees both master caches')
print('Inventory production preview lifecycle: '..count..' assertions passed')
`;

const output = runProductionLuau("inventory-model-preview-contract", code);
assert.match(output, /Inventory production preview lifecycle: 27 assertions passed/);
const mutationChecks = [];
if (process.argv.includes("--self-test")) {
  for (const [name, original, replacement, failure] of [
    ["clone_on_every_render", "if previewRef.fistName ~= fistName or #previewRef.world:GetChildren() == 0 then", "if true then", /same preview clone retained/],
    ["missing_preview_physics_guard", "descendant.Anchored = true", "descendant.Anchored = false", /preview cannot participate in physics/],
    ["backhand_camera_reversed", "distance * 0.65, distance * 0.28, distance", "distance * 0.65, distance * 0.28, -distance", /camera faces backhand/],
  ]) {
    assert(code.includes(original), `Missing mutation target: ${name}`);
    const mutated = name === "missing_preview_physics_guard"
      ? code.replaceAll(original, replacement) : code.replace(original, replacement);
    assert.throws(() => runProductionLuau("inventory-preview-mutation", mutated), failure);
    mutationChecks.push(name);
  }
}
console.log(JSON.stringify({ ok: true, output, mutationChecks, files: [path.relative(repositoryRoot, sourcePath)], limitation: "Instance mocks establish cache/lifecycle behavior; Studio owns visual geometry acceptance" }, null, 2));
