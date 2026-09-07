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
const flowPath = path.join(repositoryRoot, "work/automation/flows/inventory-premium-readability.json");
const flow = JSON.parse(fs.readFileSync(flowPath, "utf8"));
const verification = flow.steps.find((step) => step.args?.code?.includes("local function verifyPupPresentation(")).args.code;
const pupFlowHelper = verification.slice(verification.indexOf("local function verifyPupPresentation("), verification.indexOf("local samples={}"));
assert(pupFlowHelper.startsWith("local function verifyPupPresentation("), "Missing actual Pup runtime verifier");
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
local V={}
local function vec(x,y,z)return setmetatable({X=x,Y=y,Z=z},V)end
V.__add=function(a,b)return vec(a.X+b.X,a.Y+b.Y,a.Z+b.Z)end
V.__sub=function(a,b)return vec(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end
V.__mul=function(a,b)if type(a)=='number'then a,b=b,a end return vec(a.X*b,a.Y*b,a.Z*b)end
V.__div=function(a,b)return vec(a.X/b,a.Y/b,a.Z/b)end
function V:Dot(b)return self.X*b.X+self.Y*b.Y+self.Z*b.Z end
function V:Cross(b)return vec(self.Y*b.Z-self.Z*b.Y,self.Z*b.X-self.X*b.Z,self.X*b.Y-self.Y*b.X)end
V.__index=function(a,k)if k=='Magnitude'then return math.sqrt(a:Dot(a))elseif k=='Unit'then return a/a.Magnitude else return V[k]end end
local Vector3={new=vec}
local function frame(position,right,up,back)
 local f={Position=position,RightVector=right,UpVector=up,LookVector=back*-1}
 function f:VectorToObjectSpace(v)return vec(v:Dot(self.RightVector),v:Dot(self.UpVector),-v:Dot(self.LookVector))end
 function f:PointToObjectSpace(v)return self:VectorToObjectSpace(v-self.Position)end
 function f:PointToWorldSpace(v)return self.Position+self.RightVector*v.X+self.UpVector*v.Y-self.LookVector*v.Z end
 return f
end
local CFrame={lookAt=function(from,to)
 local look=(to-from).Unit
 local right=look:Cross(vec(0,1,0)).Unit
 local up=right:Cross(look).Unit
 local f=frame(from,right,up,look*-1);f.From=from;f.To=to;return f
end}
local Enum={NormalId={Front='Front',Back='Back'}}
local function part(kind)
 local p={kind=kind}
 function p:IsA(name)return self.kind==name end
 function p:Destroy()self.destroyed=true end
 return p
end
local function model(isPup)
 local p={__kind='Instance',children={part('BasePart'),part('LuaSourceContainer'),part('ParticleEmitter'),part('Beam'),part('Trail'),part('Light'),part('Highlight')}}
 if isPup then
  local body=p.children[1];body.Name='AnimatedFace'
  body.CFrame=frame(vec(-191.152664,1.02385712,50.7515564),vec(-.214734972,3.7253e-9,-.976673365),vec(5.2639e-8,1,-1.5388e-8),vec(.976674259,5.4715e-8,-.214735135))
  body.Size=vec(1.35,1.41,1.11)
  local decal=part('Decal');decal.Name='CanInvert';decal.Face=Enum.NormalId.Front;decal.Transparency=0;decal.Texture='rbxassetid://2759037468';decal.Parent=body
  table.insert(p.children,decal)
 end
 function p:IsA(name)return name=='Model'end
 function p:Destroy()self.destroyed=true end
 function p:GetDescendants()return self.children end
 function p:GetBoundingBox()if isPup then return self.children[1].CFrame,vec(2.1,2.8,1.8)end return {Position=vec(0,.7,0)},vec(1.5,1.8,1.1)end
 function p:Clone()clones+=1;return model(isPup)end
 return setmetatable(p,{__newindex=function(t,k,v)rawset(t,k,v);if k=='Parent' and type(v)=='table' and v.children then table.insert(v.children,t)end end})
end
local function preview()
 local world={children={}}
 function world:GetChildren()return self.children end
 function world:ClearAllChildren()for _,child in ipairs(self.children)do child:Destroy()end;table.clear(self.children)end
 local viewport={attrs={},AbsoluteSize={X=76,Y=76}}
 function viewport:SetAttribute(k,v)self.attrs[k]=v end
 local camera={FieldOfView=34};viewport.CurrentCamera=camera
 return {world=world,viewport=viewport,camera=camera}
end
`+block('function InventoryUI:_getPetPreviewMaster(', 'function InventoryUI:_applyItemArt(')+block('function InventoryUI:Destroy()', 'return InventoryUI')+pupFlowHelper+String.raw`
local builds={}
local s=setmetatable({_petPreviewMasters={},_fistPreviewMasters={}},{__index=InventoryUI})
s.BuildFistPreview=function(name) builds[name]=(builds[name] or 0)+1;if name=='Unsupported'then return nil end;if name=='Broken'then error('failed')end;return model()end
s.BuildPetPreview=function(name)builds[name]=(builds[name] or 0)+1;return model(name=='Forest Pup')end
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
local function verifyPupGeometry(m,camera,viewport,expectFront)
 local body=m.children[1];local decal=m.children[#m.children]
 local faceCenter=body.CFrame.Position+body.CFrame.LookVector*body.Size.Z*.5
 local signed=body.CFrame.LookVector:Dot(camera.CFrame.Position-faceCenter)
 check((signed>.05)==expectFront,'Pup camera must face the retained decal')
 if not expectFront then return signed end
 local cf,size=m:GetBoundingBox()
 local tanV=math.tan(math.rad(camera.FieldOfView*.5))
 local maxX,maxY=0,0
 for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
  local corner=cf:PointToWorldSpace(vec(size.X*x,size.Y*y,size.Z*z)*.5)-camera.CFrame.Position
  local depth=corner:Dot(camera.CFrame.LookVector)
  local nx=math.abs(corner:Dot(camera.CFrame.RightVector))/(depth*tanV*viewport.AbsoluteSize.X/viewport.AbsoluteSize.Y)
  local ny=math.abs(corner:Dot(camera.CFrame.UpVector))/(depth*tanV)
  check(depth>.05 and nx<=1/1.12+.00001 and ny<=1/1.12+.00001,'Pup eight-corner projection retains inset')
  maxX,maxY=math.max(maxX,nx),math.max(maxY,ny)
 end end end
 check(decal.Texture=='rbxassetid://2759037468' and decal.Face==Enum.NormalId.Front and not decal.destroyed,'authored face identity preserved')
 check(math.abs(body.CFrame.Position.X+191.152664)<.000001 and body.Size.Y==1.41,'authored geometry stays unchanged')
 return signed
end
local pup=model(true);local pupBounds,pupSize=pup:GetBoundingBox()
local oldCamera={FieldOfView=34,CFrame=CFrame.lookAt(pupBounds.Position+vec(2.6*.48,2.6*.2,-2.6),pupBounds.Position)}
verifyPupGeometry(pup,oldCamera,{AbsoluteSize={X=76,Y=76}},false)
-- Independent XML-derived whole-model bounds in the retained PrimaryPart basis.
-- This is a finite serialized-asset fixture, not a Studio GetBoundingBox capture.
local recorded=model(true)
local authored=recorded.children[1].CFrame
local recordedBounds=frame(vec(-190.9620862569,.86443742249,50.7182839195),authored.RightVector,authored.UpVector,authored.LookVector*-1)
local recordedSize=vec(1.48320520172,1.72883956791,1.49655944927)
function recorded:GetBoundingBox()return recordedBounds,recordedSize end
local legacyPosition=recordedBounds.Position+vec(2.6*.48,2.6*.2,-2.6)
local recordedFace=authored.Position+authored.LookVector*recorded.children[1].Size.Z*.5
local recordedBefore=authored.LookVector:Dot(legacyPosition-recordedFace)
check(math.abs(recordedBefore-(-2.525480099))<.00001,'recorded authored Pup legacy behind-face defect reproduced')
local recordedViewport={AbsoluteSize={X=76,Y=76}}
local recordedCamera={FieldOfView=34}
recordedCamera.CFrame=forestPupPreviewCamera(recorded,recordedCamera,recordedViewport,recordedBounds,recordedSize,2.6)
local recordedAfter=verifyPupGeometry(recorded,recordedCamera,recordedViewport,true)
print('XML-derived Pup signed face distance: before='..recordedBefore..' after='..recordedAfter)
local pupItem={category='Pets',name='Forest Pup',previewPet='Forest Pup'}
local actualPup=preview();s:_applyModelPreview(actualPup,pupItem)
local pupClone=actualPup.world.children[1]
verifyPupGeometry(pupClone,actualPup.camera,actualPup.viewport,true)
local pupClones=clones;local pupCamera=actualPup.camera.CFrame
s:_applyModelPreview(actualPup,pupItem)
check(clones==pupClones and actualPup.world.children[1]==pupClone and actualPup.camera.CFrame==pupCamera,'Pup same-item camera and clone retained')
check(pcall(verifyPupPresentation,actualPup.viewport,pupClone),'actual viewport verifier accepts corrected camera')
actualPup.camera.CFrame=CFrame.lookAt(pupCamera.To-(pupCamera.From-pupCamera.To).Unit*20,pupCamera.To)
check(not pcall(verifyPupPresentation,actualPup.viewport,pupClone),'actual viewport rejects behind-face camera')
actualPup.camera.CFrame=CFrame.lookAt(pupCamera.To+(pupCamera.From-pupCamera.To).Unit*2.6,pupCamera.To)
check(not pcall(verifyPupPresentation,actualPup.viewport,pupClone),'actual viewport rejects under-fit camera')
actualPup.camera.CFrame=pupCamera
pupClone.children[#pupClone.children].Texture='rbxassetid://999'
check(not pcall(verifyPupPresentation,actualPup.viewport,pupClone),'actual viewport rejects changed face asset')
pupClone.children[#pupClone.children].Texture='rbxassetid://2759037468'
actualPup.viewport.AbsoluteSize.X=0
check(not pcall(verifyPupPresentation,actualPup.viewport,pupClone),'actual viewport rejects unmeasured size')
actualPup.viewport.AbsoluteSize.X=76
for _,aspect in ipairs({.55,1,1.8})do for _,fov in ipairs({25,34,60})do
 local v={AbsoluteSize={X=100*aspect,Y=100}};local camera={FieldOfView=fov}
 camera.CFrame=forestPupPreviewCamera(pup,camera,v,pupBounds,pupSize,2.6)
 verifyPupGeometry(pup,camera,v,true)
end end
local noFace=model(false)
check(forestPupPreviewCamera(noFace,{FieldOfView=34},{},pupBounds,pupSize,2.6)==nil,'missing intended face preserves legacy fallback')
pup.children[#pup.children].Transparency=1
check(forestPupPreviewCamera(pup,{FieldOfView=34},{},pupBounds,pupSize,2.6)==nil,'invisible face is not a presentation basis')
pup.children[#pup.children].Transparency=0;pup.children[#pup.children].Face=Enum.NormalId.Back
check(forestPupPreviewCamera(pup,{FieldOfView=34},{},pupBounds,pupSize,2.6)==nil,'different decal side preserves legacy fallback')
for _,name in ipairs({'_cancelPendingDetailRender','_cancelDeleteConfirmation','_stopTimedRefresh','_clearCards','_disconnectPool'})do s[name]=function()end end
for _,name in ipairs({'_connections','_actionConnections','_actionButtonRefsByKey','_activeActionButtons','_actionModelsByKey','_cardRefsByKey','_sparseSlotPool'})do s[name]={}end
local master=s._fistPreviewMasters['Default Fists']
s:Destroy()
check(master.destroyed and next(s._fistPreviewMasters)==nil and next(s._petPreviewMasters)==nil,'destroy frees both master caches')
print('Inventory production preview lifecycle: '..count..' assertions passed')
`;

const output = runProductionLuau("inventory-model-preview-contract", code);
assert.match(output, /Inventory production preview lifecycle: 159 assertions passed/);
let baselineProof;
const baselineIndex = process.argv.indexOf("--preview-baseline");
if (baselineIndex >= 0) {
  const ref = process.argv[baselineIndex + 1];
  assert(ref, "--preview-baseline requires a Git ref");
  const result = spawnSync("git", ["show", `${ref}:work/punch-wall-rpg/src/client/InventoryUI.lua`], {cwd: repositoryRoot, encoding: "utf8"});
  assert.equal(result.status, 0, result.stderr);
  const before = result.stdout.replace(/\r\n?/g, "\n");
  const start = before.indexOf("function InventoryUI:_applyPetPreview(");
  const end = before.indexOf("function InventoryUI:_getFistPreviewMaster(", start);
  assert(start >= 0 && end > start, "Missing baseline pet preview function");
  assert.throws(() => runProductionLuau("inventory-pup-baseline", code.replace(block("function InventoryUI:_applyPetPreview(", "function InventoryUI:_getFistPreviewMaster("), before.slice(start, end))), /Pup camera must face the retained decal/);
  baselineProof = {ref, intendedFailure: true};
}
const mutationChecks = [];
if (process.argv.includes("--self-test")) {
  for (const [name, original, replacement, failure] of [
    ["clone_on_every_render", "if previewRef.fistName ~= fistName or #previewRef.world:GetChildren() == 0 then", "if true then", /same preview clone retained/],
    ["missing_preview_physics_guard", "descendant.Anchored = true", "descendant.Anchored = false", /preview cannot participate in physics/],
    ["backhand_camera_reversed", "distance * 0.65, distance * 0.28, distance", "distance * 0.65, distance * 0.28, -distance", /camera faces backhand/],
    ["pup_camera_behind_face", "local normal = facePart.CFrame.LookVector", "local normal = facePart.CFrame.LookVector * -1", /Pup camera must face the retained decal/],
    ["pup_fit_ignored", "return CFrame.lookAt(center + direction * distance, center)", "return CFrame.lookAt(center + direction * minimumDistance, center)", /Pup eight-corner projection retains inset/],
    ["pup_legacy_camera", "previewRef.camera.CFrame = authoredFaceCamera or CFrame.lookAt(", "previewRef.camera.CFrame = CFrame.lookAt(", /Pup camera must face the retained decal/],
    ["runtime_front_guard_removed", "assert(signed>.05,'Pup camera is behind", "assert(true,'Pup camera is behind", /actual viewport rejects behind-face camera/],
    ["runtime_fit_guard_removed", "depth>.05 and nx<=1/1.12+.001 and ny<=1/1.12+.001", "true", /actual viewport rejects under-fit camera/],
  ]) {
    assert(code.includes(original), `Missing mutation target: ${name}`);
    const mutated = name === "missing_preview_physics_guard"
      ? code.replaceAll(original, replacement) : code.replace(original, replacement);
    assert.throws(() => runProductionLuau("inventory-preview-mutation", mutated), failure);
    mutationChecks.push(name);
  }
}
console.log(JSON.stringify({ ok: true, output, baselineProof, mutationChecks, files: [path.relative(repositoryRoot, sourcePath), path.relative(repositoryRoot, flowPath)], limitation: "Instance/math mocks establish cache/lifecycle and finite projection behavior; Studio owns actual mesh/decal rendering and aesthetic acceptance" }, null, 2));
