#!/usr/bin/env node
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const sourcePath=path.join(root,'work/punch-wall-rpg/src/client/PunchWallClient.client.lua');
const source=fs.readFileSync(sourcePath,'utf8').replace(/\r\n?/g,'\n');
function extract(text,start,end){const a=text.indexOf(start),b=text.indexOf(end,a+start.length);assert(a>=0&&b>a,'Missing production block '+start);return text.slice(a,b);}
const style=extract(source,'function companionRuntime.StyleNormalCatalogPet(','function companionRuntime.AttestedCatalogPetTemplate(');
const inventory=fs.readFileSync(path.join(root,'work/punch-wall-rpg/src/client/InventoryUI.lua'),'utf8').replace(/\r\n?/g,'\n');
const fit=extract(inventory,'local function forestPupPreviewCamera(','function InventoryUI:_applyPetPreview(');
const flow=JSON.parse(fs.readFileSync(path.join(root,'work/automation/flows/forest-pup-silhouette.json'),'utf8'));
const runtimeCode=flow.steps.find(x=>x.label==='verify actual Pup feature geometry and preview follower parity').args.code;
const runtimeAudit=extract(runtimeCode,'local function verifyPupModel(','local function verifyPreview(');
const dirs=[process.env.PUNCH_WALL_LUAU_TOOL_DIR,path.join(root,'.tools/luau'),...fs.readdirSync(os.tmpdir(),{withFileTypes:true}).filter(x=>x.isDirectory()&&x.name.startsWith('codex-luau-')).map(x=>path.join(os.tmpdir(),x.name))].filter(Boolean);
const toolDir=dirs.find(x=>fs.existsSync(path.join(x,process.platform==='win32'?'luau.exe':'luau')));assert(toolDir,'BLOCKED: official Luau runtime unavailable');
function run(code,expectSuccess=true){const dir=fs.mkdtempSync(path.join(os.tmpdir(),'pup-silhouette-'));try{const p=path.join(dir,'test.luau');fs.writeFileSync(p,code);const compile=spawnSync(path.join(toolDir,process.platform==='win32'?'luau-compile.exe':'luau-compile'),[p],{encoding:'utf8',timeout:30000});assert.equal(compile.status,0,compile.stderr);const r=spawnSync(path.join(toolDir,process.platform==='win32'?'luau.exe':'luau'),[p],{encoding:'utf8',timeout:30000});assert.ifError(r.error);if(expectSuccess)assert.equal(r.status,0,r.stderr||r.stdout);return r;}finally{fs.unlinkSync(path.join(dir,'test.luau'));fs.rmdirSync(dir);}}
const setup=String.raw`
local count=0
local function check(x,m)count+=1;assert(x,m)end
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
local F={};F.__index=F
local function frame(p,r,u,b)return setmetatable({Position=p,RightVector=r,UpVector=u,LookVector=b*-1},F)end
function F:VectorToWorldSpace(v)return self.RightVector*v.X+self.UpVector*v.Y-self.LookVector*v.Z end
function F:VectorToObjectSpace(v)return vec(v:Dot(self.RightVector),v:Dot(self.UpVector),-v:Dot(self.LookVector))end
function F:PointToWorldSpace(v)return self.Position+self:VectorToWorldSpace(v)end
function F:PointToObjectSpace(v)return self:VectorToObjectSpace(v-self.Position)end
F.__mul=function(a,b)return frame(a:PointToWorldSpace(b.Position),a:VectorToWorldSpace(b.RightVector),a:VectorToWorldSpace(b.UpVector),a:VectorToWorldSpace(b.LookVector)*-1)end
local CFrame={new=function(x,y,z)return frame(vec(x or 0,y or 0,z or 0),vec(1,0,0),vec(0,1,0),vec(0,0,1))end,
 Angles=function(x,y,z)assert(x==0 and y==0);return frame(vec(0,0,0),vec(math.cos(z),math.sin(z),0),vec(-math.sin(z),math.cos(z),0),vec(0,0,1))end,
 lookAt=function(p,to)local n=(to-p).Unit;local r=n:Cross(vec(0,1,0)).Unit;return frame(p,r,r:Cross(n),n*-1)end}
local C={};C.__index=C
local function color(r,g,b)return setmetatable({R=r,G=g,B=b},C)end
function C:Lerp(b,t)return color(self.R+(b.R-self.R)*t,self.G+(b.G-self.G)*t,self.B+(b.B-self.B)*t)end
local Color3={new=color,fromRGB=function(r,g,b)return color(r/255,g/255,b/255)end}
local Enum={NormalId={Front='Front',Back='Back'},Material={SmoothPlastic='SmoothPlastic',Neon='Neon',Metal='Metal',DiamondPlate='DiamondPlate'},PartType={Ball='Ball',Block='Block'}}
local function obj(kind)
 local o={kind=kind,attrs={},children={}}
 function o:IsA(k)return k==self.kind or (k=='BasePart' and (self.kind=='Part' or self.kind=='MeshPart'))end
 function o:GetAttribute(k)return self.attrs[k]end
 function o:SetAttribute(k,v)self.attrs[k]=v end
 function o:GetDescendants()local result={} local function walk(x)for _,c in ipairs(x.children)do table.insert(result,c);walk(c)end end walk(self);return result end
 return setmetatable(o,{__index=function(t,k)if k=='Position' and rawget(t,'CFrame')then return t.CFrame.Position end end,__newindex=function(t,k,v)rawset(t,k,v);if k=='Parent' and v then table.insert(v.children,t)end end})
end
local Instance={new=obj}
local function sourcePart(model,name,kind,size,cf,mesh,transparency)
 local p=obj(kind);p.Name=name;p.Size=size;p.CFrame=cf;p.MeshId=mesh;p.TextureID='';p.Transparency=transparency or 0;p.Color=Color3.fromRGB(220,220,220);p.Material=Enum.Material.SmoothPlastic;p.Parent=model;return p
end
local function fixture(scale,rotate)
 local model=obj('Model')
 model:SetAttribute('PetDefinitionName','Forest Pup');model:SetAttribute('SourcePackModelName','Dowodle')
 local base=frame(vec(-191.152664,1.02385712,50.7515564),vec(-.214734972,3.7253e-9,-.976673365),vec(5.2639e-8,1,-1.5388e-8),vec(.976674259,5.4715e-8,-.214735135))
 if rotate then base=CFrame.Angles(0,0,.4)*base end
 local face=sourcePart(model,'AnimatedFace','Part',vec(1.35,1.41,1.11)*scale,base,nil,1)
 local a=sourcePart(model,'Stone','MeshPart',vec(1.48320222,1.48320234,1.48320234)*scale,base*CFrame.new(0,-.038*scale,.20*scale),'rbxassetid://1461040253')
 local b=sourcePart(model,'Stone','MeshPart',vec(1.12831676,.35637936,1.11219299)*scale,base*CFrame.new(0,-.846*scale,.20*scale),'rbxassetid://1461041563')
 sourcePart(model,'Root','Part',vec(1,.05,1)*scale,base*CFrame.new(0,-.95*scale,.20*scale),nil,1)
 local decal=obj('Decal');decal.Name='CanInvert';decal.Face=Enum.NormalId.Front;decal.Texture='rbxassetid://2759037468';decal.Transparency=0;decal.Parent=face
 function model:GetBoundingBox()
  local low=vec(math.huge,math.huge,math.huge);local high=low*-1
  for _,part in ipairs(self:GetDescendants())do if part:IsA('BasePart')then
   for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
    local v=base:PointToObjectSpace(part.CFrame:PointToWorldSpace(vec(part.Size.X*x,part.Size.Y*y,part.Size.Z*z)*.5))
    low=vec(math.min(low.X,v.X),math.min(low.Y,v.Y),math.min(low.Z,v.Z));high=vec(math.max(high.X,v.X),math.max(high.Y,v.Y),math.max(high.Z,v.Z))
   end end end
  end end
  return base*CFrame.new((low.X+high.X)*.5,(low.Y+high.Y)*.5,(low.Z+high.Z)*.5),high-low
 end
 return model,face,a,b,decal
end
local companionRuntime={}
`;
const checks=String.raw`
local roles={EarLeft=true,EarRight=true,MuzzleLeft=true,MuzzleRight=true,PawLeft=true,PawRight=true,Collar=true,Tag=true}
local function audit(model,face,originals)
 local featureCount=0;local actualParts=0;local found={};local colors={};local size=face.Size
 for _,p in ipairs(model:GetDescendants())do if p:IsA('BasePart')then actualParts+=1 end if p:GetAttribute('ForestPupFeature')then
  featureCount+=1;local role=p:GetAttribute('ForestPupFeature');check(roles[role] and not found[role],'unique bounded feature roles');found[role]=p
  check(p:IsA('BasePart') and p.Anchored and not p.CanCollide and not p.CanTouch and not p.CanQuery,'new features cannot participate in physics')
  check(p.Shape==Enum.PartType.Ball and p.Material==Enum.Material.SmoothPlastic and #p:GetDescendants()==0,'new features remain matte native geometry without effects or joints')
  check(p.Size.X>0 and p.Size.Y>0 and p.Size.Z>0 and p.Size.X<=size.X*.87 and p.Size.Y<=size.Y*.59 and p.Size.Z<=size.Z*.31,'feature dimensions stay finite and bounded')
  local center=face.CFrame:PointToObjectSpace(p.CFrame.Position)
  local lo,hi=vec(math.huge,math.huge,math.huge),vec(-math.huge,-math.huge,-math.huge)
  for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
   local q=face.CFrame:PointToObjectSpace(p.CFrame:PointToWorldSpace(vec(p.Size.X*x,p.Size.Y*y,p.Size.Z*z)*.5))
   lo=vec(math.min(lo.X,q.X),math.min(lo.Y,q.Y),math.min(lo.Z,q.Z));hi=vec(math.max(hi.X,q.X),math.max(hi.Y,q.Y),math.max(hi.Z,q.Z))
  end end end
  local crossesFace=lo.X<size.X*.38 and hi.X>-size.X*.38 and lo.Y<size.Y*.30 and hi.Y>-size.Y*.23 and lo.Z<=-size.Z*.5
  check(not crossesFace,'retained central OWO face zone remains unobstructed')
  if role:find('Ear',1,true)then check(math.abs(center.X)>=size.X*.59 and (lo.X<-size.X*.5 or hi.X>size.X*.5),'ears extend beyond the old block silhouette')end
  if role:find('Muzzle',1,true)then check(center.Z<-size.Z*.5 and hi.Y<-size.Y*.23,'muzzle is on the authored front below the retained face')end
  if role:find('Paw',1,true)then check(lo.Y<-size.Y*.72,'paws extend beneath retained body')end
  colors[string.format('%.3f/%.3f/%.3f',p.Color.R,p.Color.G,p.Color.B)]=true
 end end
 check(featureCount==8 and featureCount<=9,'eight-part source budget')
 check(actualParts==12,'total model budget includes unlabeled parts')
 local colorCount=0;for _ in pairs(colors)do colorCount+=1 end
 check(colorCount>=4,'recognizable warm muzzle and forest collar palette')
 check(model:GetAttribute('ForestPupSilhouetteVersion')=='AuthoredPupV1' and model:GetAttribute('ForestPupSilhouettePartCount')==featureCount,'actual feature count matches diagnostics')
 for _,original in ipairs(originals)do
  local p=original.part
  check(p.Parent==original.parent and p.Size==original.size and p.CFrame==original.cf and p.Transparency==original.transparency,'retained geometry pose size and visibility untouched')
  check(p.MeshId==original.mesh and p.TextureID==original.texture,'retained mesh and texture identity unchanged')
 end
 return found
end
for _,scale in ipairs({.5,1,2})do for _,rotate in ipairs({false,true})do
 local model,face,a,b,decal=fixture(scale,rotate)
 local originals={}
 for _,p in ipairs(model:GetDescendants())do if p:IsA('BasePart')then table.insert(originals,{part=p,parent=p.Parent,size=p.Size,cf=p.CFrame,transparency=p.Transparency,mesh=p.MeshId,texture=p.TextureID})end end
 local d={name='Forest Pup',rarity='Common',color=Color3.fromRGB(112,178,92)}
 companionRuntime.StyleNormalCatalogPet(model,d)
 local refs=audit(model,face,originals)
 local actualRows=verifyPupModel(model)
 check(actualRows.count==8,'actual runtime helper accepts source geometry')
 check(decal.Parent==face and decal.Texture=='rbxassetid://2759037468' and decal.Face==Enum.NormalId.Front and decal.Transparency==0,'retained real decal unchanged')
 local beforeColor=refs.EarLeft.Color;companionRuntime.StyleNormalCatalogPet(model,d)
 local after=audit(model,face,originals)
 check(after.EarLeft==refs.EarLeft and after.Tag==refs.Tag and after.EarLeft.Color==beforeColor,'repeat styling retains parts and does not retint features')
 local cf,size=model:GetBoundingBox()
 local camera={FieldOfView=34};local viewport={AbsoluteSize={X=76,Y=76}}
 camera.CFrame=forestPupPreviewCamera(model,camera,viewport,cf,size,2.6)
 local faceCenter=face.CFrame.Position+face.CFrame.LookVector*face.Size.Z*.5
 check(face.CFrame.LookVector:Dot(camera.CFrame.Position-faceCenter)>.05,'existing Inventory camera still sees retained face')
 for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
  local p=camera.CFrame:PointToObjectSpace(cf:PointToWorldSpace(vec(size.X*x,size.Y*y,size.Z*z)*.5));local depth=-p.Z;local tanV=math.tan(math.rad(17))
  check(depth>.05 and math.abs(p.X)/(depth*tanV)<=1/1.12+.00001 and math.abs(p.Y)/(depth*tanV)<=1/1.12+.00001,'new silhouette retains full eight-corner Inventory fit')
 end end end
end end
for _,kind in ipairs({'Missing','Hidden','Back'})do
 local m,face,_,_,decal=fixture(1,false)
 if kind=='Missing'then face.Name='NotTheAuthoredFace'elseif kind=='Hidden'then decal.Transparency=1 else decal.Face=Enum.NormalId.Back end
 companionRuntime.StyleNormalCatalogPet(m,{name='Forest Pup',rarity='Common',color=Color3.fromRGB(112,178,92)})
 check(#m:GetDescendants()==5 and m:GetAttribute('ForestPupSilhouetteVersion')==nil,'unusable authored face safely retains imported model '..kind)
end
for _,entry in ipairs({{name='Meadow Bunny',rarity='Common'},{name='Void Hound',rarity='Secret'},{name='Premium Control',rarity='Premium'}})do
 local m=fixture(1,false);companionRuntime.StyleNormalCatalogPet(m,entry)
 check(#m:GetDescendants()==5 and m:GetAttribute('ForestPupSilhouetteVersion')==nil,'other pet does not acquire Pup geometry '..entry.name)
end
local m,face,_,_,decal=fixture(1,false)
local definition={name='Forest Pup',rarity='Common',color=Color3.fromRGB(112,178,92)}
m:SetAttribute('ForestPupSilhouetteVersion','AuthoredPupV1');m:SetAttribute('ForestPupSilhouettePartCount',8)
check(not pcall(verifyPupModel,m),'actual runtime rejects metadata without features')
m:SetAttribute('ForestPupSilhouetteVersion',nil);companionRuntime.StyleNormalCatalogPet(m,definition)
local valid,features=verifyPupModel(m)
decal.Texture='rbxassetid://999';check(not pcall(verifyPupModel,m),'actual runtime rejects changed decal');decal.Texture='rbxassetid://2759037468'
features.Tag.CanQuery=true;check(not pcall(verifyPupModel,m),'actual runtime rejects queryable feature');features.Tag.CanQuery=false
local oldRole=features.Tag:GetAttribute('ForestPupFeature');features.Tag:SetAttribute('ForestPupFeature','EarLeft')
check(not pcall(verifyPupModel,m),'actual runtime rejects duplicate feature role');features.Tag:SetAttribute('ForestPupFeature',oldRole)
face.Transparency=0;check(not pcall(verifyPupModel,m),'actual runtime rejects opaque face carrier');face.Transparency=1
local unsafe=obj('ParticleEmitter');unsafe.Parent=features.Tag
check(not pcall(verifyPupModel,m),'actual runtime rejects added effect');table.clear(features.Tag.children)
local changed=verifyPupModel(m);changed.features.PawLeft.position[1]+=.01
check(not pcall(sameGeometry,valid,changed),'actual runtime rejects geometry parity drift')
local extra=obj('Part');extra.Parent=m
check(not pcall(verifyPupModel,m),'actual runtime rejects unlabeled extra part')
print('Forest Pup exact production controls: '..count)
`;
const code=setup+style+fit+runtimeAudit+checks;
const result=run(code);assert.match(result.stdout,/Forest Pup exact production controls: 782/);
const mutations=[];
if(process.argv.includes('--self-test'))for(const [name,needle,replacement,expected] of [
 ['unanchored','part.Anchored = true','part.Anchored = false',/cannot participate in physics/],
 ['collidable','part.CanCollide = false','part.CanCollide = true',/cannot participate in physics/],
 ['eye-zone-covered','side * 0.12, -0.35, 0.055','side * 0.12, 0, 0.055',/central OWO face zone/],
 ['world-basis','part.CFrame = facePart.CFrame * CFrame.new(','part.CFrame = CFrame.new(0,0,0) * CFrame.new(',/ears extend|muzzle is|paws extend|central OWO face zone/],
 ['effects','part.Material = Enum.Material.SmoothPlastic','part.Material = Enum.Material.Neon',/matte native geometry/],
 ['repeat-duplicates','model:GetAttribute("ForestPupSilhouetteVersion") == "AuthoredPupV1"','false',/unique bounded feature roles/],
 ['all-pets','if definition.name == "Forest Pup" then','if definition.name ~= "Premium Control" then',/other pet does not acquire/],
 ['unlabeled-part','featureCount += 1','local extra=Instance.new("Part");extra.Parent=model;featureCount += 1',/total model budget/],
 ['runtime-budget-guard','assert(actualParts==12,','assert(true,',/actual runtime rejects unlabeled extra part/],
 ['runtime-safety-guard',"x.Anchored and not x.CanCollide and not x.CanTouch and not x.CanQuery and #x:GetDescendants()==0",'true',/actual runtime rejects queryable feature/],
 ['runtime-parity-guard','math.abs(value-actual.features[role][key][index])<.004','true',/actual runtime rejects geometry parity drift/],
]){assert(code.includes(needle),'Missing mutation '+name);const changed=name==='unanchored'||name==='collidable'?code.replaceAll(needle,replacement):code.replace(needle,replacement);const r=run(changed,false);assert.notEqual(r.status,0,'Weakening survived '+name);assert.match(r.stderr+r.stdout,expected);mutations.push(name);}
const baselineIndex=process.argv.indexOf('--baseline');let baselineProof;
if(baselineIndex>=0){const ref=process.argv[baselineIndex+1];assert(ref);const r=spawnSync('git',['show',`${ref}:work/punch-wall-rpg/src/client/PunchWallClient.client.lua`],{cwd:root,encoding:'utf8'});assert.equal(r.status,0,r.stderr);const old=extract(r.stdout.replace(/\r\n?/g,'\n'),'function companionRuntime.StyleNormalCatalogPet(','function companionRuntime.AttestedCatalogPetTemplate(');const before=run(setup+old+fit+runtimeAudit+checks,false);assert.notEqual(before.status,0);assert.match(before.stderr+before.stdout,/eight-part source budget/);baselineProof={ref,intendedFailure:true};}
console.log(JSON.stringify({ok:true,output:result.stdout.trim(),mutations,baselineProof,limitation:'Exact producer and conservative math fixtures; native mesh rendering, rig movement, thumbnail quality and device performance need Studio evidence.'},null,2));
