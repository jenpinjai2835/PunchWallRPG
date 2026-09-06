# Shared first-five fist geometry

Agent HQ: `SMASH-20260906`, Agent 3 FIST. Date: 2026-09-06.
Base: `1e1fed11f1d9c168e253f42a65d5b5920d7d8925`.
Owned source: `work/punch-wall-rpg/src/shared/FistVisualBuilder.lua`.

## API and consumer handoff

`GetCatalogSpec(definition)` returns a fresh spec for the five canonical saved
names below. Unsupported names return `nil, "unsupported_catalog_fist"`;
invalid input or a mismatched style/icon/tier returns a reason and no spec.
All existing public APIs, sanitizer behavior, and static fallback-art metadata
remain available. Later items that reuse the same styles do not inherit these
models accidentally.

`BuildCatalogModel(definition)` returns `model, spec`, or `nil, reason`.
The unparented Model contains only native Parts. They are anchored, massless,
non-colliding, non-queryable, non-touchable, and do not cast shadows. There are
no scripts, welds, animations, sounds, emitters, lights, trails, or external
asset requests. The existing visual sanitizer verifies the returned model.

The model has no PrimaryPart. Its explicit WorldPivot is the wrist origin at
`CFrame.identity`. Local positive Y goes from wrist to knuckles, positive Z is
the backhand face, and local X spans the four knuckles. `spec.referenceHandWidth`
is 1 stud; `spec.previewDirection` is `(0.65, 0.28, 1)` relative to the bounds
center. Preview cameras must fit final bounds and actual viewport aspect ratio.

Consumers clone or build this exact geometry for Shop, Inventory, and equipment.
The equipment consumer owns scaling to the actual R6/R15 hand, pivot placement,
welding, and existing motion feedback. Start fit evaluation with the existing
profile's `cuffYScale` for the new cuff origin and a 180-degree Z rotation:
`hand.CFrame * CFrame.new(0, hand.Size.Y * profile.cuffYScale, 0) * CFrame.Angles(0, 0, math.rad(180))`.
The old `wristYScale` located an imported mesh center, so applying it directly
to the new wrist origin can shift the fist too far down the arm. Recompute
completed equipped bounds after scaling and attachment; this module does not
attest to face clearance or live-avatar wrist fit.

Each model exposes:

- `FistCatalogVisual = true`, `FistVisualKey` = stable saved item name.
- `CatalogGeometryVersion = "SharedClosedFistV1"`, `CatalogSilhouette`.
- `Tier`, `FistStyle`, `DisplayName`, `GripAxis`, `CatalogReferenceHandWidth`.
- Actual final `CatalogBoundsCenter`, `CatalogBoundsSize`, and part count/budget.
- Closed-fist anatomy flags and per-part `FistShape` roles.
- Existing icon identity, variant key, and fallback `ShopArtVariant`.
- `CatalogPreviewHasEffects = false` and sanitizer attestation.

## Geometry

All five contain one palm, one cuff, one backhand guard, four distal knuckles,
four curled finger pads, and one folded thumb. No WedgeParts or long fingers
are created. Their visible identities differ through geometry as well as
configuration colors/materials:

| Saved name | Identity | Parts |
| --- | --- | ---: |
| Starter Glove | Compact leather cuff and two wrapping bands | 14 |
| Boxing Glove | Larger padded crown, wide wrist strap and fastener | 15 |
| Iron Knuckle | Square metal knuckles, side guards and backhand rivets | 16 |
| Thunder Fist | Twin inset rails with a contained cyan core | 18 |
| Titan Gauntlet | Broad reinforced cuff, siege guards and amber core | 18 |

Final unscaled bounding envelopes from the pure geometry check, in studs:

| Saved name | Width | Height | Depth | Center X / Y / Z |
| --- | ---: | ---: | ---: | --- |
| Starter Glove | 1.1413 | 1.2736 | 0.7595 | 0.0806 / 0.6768 / -0.0088 |
| Boxing Glove | 1.3903 | 1.4352 | 0.9742 | 0.0951 / 0.7276 / 0.0098 |
| Iron Knuckle | 1.3104 | 1.3612 | 0.8478 | 0.0682 / 0.6706 / 0.0243 |
| Thunder Fist | 1.3029 | 1.4464 | 0.9643 | 0.0914 / 0.7032 / 0.0493 |
| Titan Gauntlet | 1.4830 | 1.5264 | 1.0849 | 0.0581 / 0.6632 / 0.0652 |

Each model is geometrically distinct before color, labels, or effects. Center X
is slightly positive because of the folded thumb. Model wrist origin is zero;
the positive Y bounds center is intentional and is not the attachment position.

No currency, price, power, ownership, or save-data field changes are included.
This module adds geometry; the Coordinator must wire the consumers before any
player-facing visual improvement can be claimed.

## Verification and limits

- Luau 0.737 compilation: PASS with `luau-compile.exe --null` against the source.
- Pure geometry check below: PASS for all five. It compares geometry independently of color or
  item labels; checks positive dimensions, required closed anatomy, actual
  final oriented-part bounding boxes, connected bounding-box envelopes, 12-22
  parts, wrist origin, fresh specs, unsupported identities, visual-only model
  construction, and sanitizer compatibility.
- Initial geometry check caught a 0.004-stud gap between Titan's core and its
  housing. The core was inset further before the final check.
- Engine rendering, actual sphere/cylinder surface contact, R6/R15 fit,
  purchases/equips, preview lifecycle, frame time, and mobile readability remain
  Coordinator integration gates. Bounding-box connectivity is a conservative
  mathematical check, not visual or physical-contact proof.
- Existing flow expectations for the old single imported mesh must be updated
  by their owner alongside consumer integration. Old attribute-only passes are
  insufficient evidence for these new shapes.

## Reproduce the pure check without Studio or temporary files

From this worktree, pipe the following Node runner to `node`. Set `LUAU_COMMAND`
to a local Luau CLI executable, or use the already installed 0.737 path shown.
The Roblox types and Instances are minimal test doubles: this checks the actual
spec/model-building code and final geometry arithmetic, not Roblox rendering.

```javascript
const fs = require('fs'), cp = require('child_process');
const source = fs.readFileSync('work/punch-wall-rpg/src/shared/FistVisualBuilder.lua', 'utf8');
const config = fs.readFileSync('work/punch-wall-rpg/src/shared/GameConfig.lua', 'utf8');
const doc = fs.readFileSync('work/docs/SMASH_FISTS_20260906.md', 'utf8');
const firstFive = config.match(/GameConfig\.Fists = \{([\s\S]*?)\n\}/)[1]
  .trim().split(/\r?\n/).slice(0, 5).join('\n');
const harness = doc.match(/```luau\r?\n([\s\S]*?)\r?\n```/)[1];
const program = harness.replace('SOURCE', JSON.stringify(source))
  .replace('DEFINITIONS', JSON.stringify('return {' + firstFive + '}'));
const command = process.env.LUAU_COMMAND ||
  'C:/Users/Jennarong Pinjai/AppData/Local/Temp/codex-luau-smash-0.737/luau.exe';
const result = cp.spawnSync(command, [], {
  input: 'do ' + program.replace(/\r?\n/g, ' ') + ' end\n', encoding: 'utf8'
});
process.stdout.write(result.stdout || '');
process.stderr.write(result.stderr || '');
if (result.status !== 0 || !result.stdout.includes('CATALOG_CHECK_PASS')) process.exit(1);
```

```luau
local V={} function V.new(x,y,z) return {X=x or 0,Y=y or 0,Z=z or 0} end V.zero=V.new()
local C={} local CM={} CM.__index=CM
function C.new(a,b,c) local p=type(a)=='table' and a or V.new(a,b,c) return setmetatable({Position=p,angle=0},CM) end
function C.Angles(x,y,z) assert(x==0 and y==0,'test expects planar part rotations') local c=C.new() c.angle=z return c end
function CM.__mul(a,b) local ca,sa=math.cos(a.angle),math.sin(a.angle) local p=b.Position return setmetatable({Position=V.new(a.Position.X+ca*p.X-sa*p.Y,a.Position.Y+sa*p.X+ca*p.Y,a.Position.Z+p.Z),angle=a.angle+b.angle},CM) end
C.identity=C.new()
local Colors={} local ColorMT={} ColorMT.__index=ColorMT
function Colors.fromRGB(r,g,b) return setmetatable({R=r/255,G=g/255,B=b/255},ColorMT) end
function Colors.new(r,g,b) return setmetatable({R=r,G=g,B=b},ColorMT) end
function ColorMT:Lerp(other,t) return Colors.new(self.R+(other.R-self.R)*t,self.G+(other.G-self.G)*t,self.B+(other.B-self.B)*t) end
local E={Material=setmetatable({},{__index=function(_,k)return k end}),PartType={Block='Block',Ball='Ball',Cylinder='Cylinder'}}
local function bounds(parts)
 local lo={math.huge,math.huge,math.huge} local hi={-math.huge,-math.huge,-math.huge}
 for _,p in ipairs(parts) do local size=p.size or p.Size local cf=p.cframe or p.CFrame local ca,sa=math.abs(math.cos(cf.angle)),math.abs(math.sin(cf.angle)) local half={(ca*size.X+sa*size.Y)/2,(sa*size.X+ca*size.Y)/2,size.Z/2} local center={cf.Position.X,cf.Position.Y,cf.Position.Z} for axis=1,3 do lo[axis]=math.min(lo[axis],center[axis]-half[axis]) hi[axis]=math.max(hi[axis],center[axis]+half[axis]) end end
 return lo,hi
end
local IM={} IM.__index=IM
function IM:SetAttribute(k,v) self.attributes[k]=v end function IM:GetAttribute(k) return self.attributes[k] end
function IM:IsA(k) return self.ClassName==k or self.ClassName=='Part' and k=='BasePart' end
function IM:GetChildren() return self.children end function IM:GetDescendants() local list={} local function walk(n) for _,c in ipairs(n.children)do table.insert(list,c) walk(c)end end walk(self) return list end
function IM:GetBoundingBox() local lo,hi=bounds(self:GetDescendants()) return C.new((lo[1]+hi[1])/2,(lo[2]+hi[2])/2,(lo[3]+hi[3])/2),V.new(hi[1]-lo[1],hi[2]-lo[2],hi[3]-lo[3]) end
function IM.__newindex(t,k,v) if k=='Parent' and v then table.insert(v.children,t) end rawset(t,k,v) end
local I={} function I.new(class) return setmetatable({ClassName=class,children={},attributes={}},IM) end
local env=setmetatable({Vector3=V,CFrame=C,Color3=Colors,Enum=E,Instance=I,game={GetService=function()return {} end}},{__index=getfenv()})
local loadBuilder=assert(loadstring(SOURCE)) setfenv(loadBuilder,env) local B=loadBuilder()
local loadDefinitions=assert(loadstring(DEFINITIONS)) setfenv(loadDefinitions,env) local definitions=loadDefinitions()
local fingerprints={}
for _,d in ipairs(definitions) do
 local spec=assert(B.GetCatalogSpec(d)) assert(#spec.parts>=12 and #spec.parts<=22,'budget '..d.name)
 local roles={} local names={} local fingerprint=''
 for _,p in ipairs(spec.parts)do assert(p.size.X>0 and p.size.Y>0 and p.size.Z>0,'positive geometry') assert(not names[p.name],'duplicate part name') names[p.name]=true roles[p.role]=(roles[p.role] or 0)+1 fingerprint..=string.format('%s:%.3f:%.3f:%.3f:%.3f:%.3f:%.3f;',p.shape,p.size.X,p.size.Y,p.size.Z,p.cframe.Position.X,p.cframe.Position.Y,p.cframe.Position.Z) end
 assert(roles.ClosedPalm==1 and roles.ClosedKnuckle==4 and roles.CurledFinger==4 and roles.FoldedThumb==1 and roles.WristCuff==1 and roles.BackhandPlate==1,'closed anatomy '..d.name)
 assert(not fingerprints[fingerprint],'identical geometry') fingerprints[fingerprint]=true
 local lo,hi=bounds(spec.parts) assert(lo[2]>=-0.11 and hi[2]<=1.6 and hi[1]-lo[1]<=1.5 and hi[3]-lo[3]<=1.3,'canonical dimensions '..d.name)
 local connected={[1]=true} local changed=true while changed do changed=false for i,p in ipairs(spec.parts) do if not connected[i] then local a,b=bounds({p}) for j,q in ipairs(spec.parts)do if connected[j]then local c,e=bounds({q}) local touch=true for axis=1,3 do if b[axis]<c[axis]-0.002 or e[axis]<a[axis]-0.002 then touch=false end end if touch then connected[i]=true changed=true break end end end end end end
 for i,p in ipairs(spec.parts)do assert(connected[i],'detached part '..d.name..':'..p.name)end
 local model=assert(B.BuildCatalogModel(d)) assert(model.WorldPivot.Position.X==0 and model.WorldPivot.Position.Y==0 and model.WorldPivot.Position.Z==0,'wrist pivot') assert(model:GetAttribute('FistVisualKey')==d.name and model:GetAttribute('VisualPartCount')==#spec.parts,'metadata')
 for _,p in ipairs(model:GetDescendants())do assert(p.ClassName=='Part' and p.Anchored and p.Massless and not p.CanCollide and not p.CanTouch and not p.CanQuery and p.CastShadow==false,'visual-only part')end
 assert(B.IsSanitizedVisual(model),'sanitizer compatibility')
 local again=assert(B.GetCatalogSpec(d)) assert(again.parts~=spec.parts and again.parts[1]~=spec.parts[1],'spec alias')
 print(string.format('CATALOG %s | parts=%d | bounds=%.4f,%.4f,%.4f | center=%.4f,%.4f,%.4f | minY=%.4f',d.name,#spec.parts,hi[1]-lo[1],hi[2]-lo[2],hi[3]-lo[3],(hi[1]+lo[1])/2,(hi[2]+lo[2])/2,(hi[3]+lo[3])/2,lo[2]))
end
assert(B.GetCatalogSpec(nil)==nil and B.BuildCatalogModel({name='Magma Breaker'})==nil,'unsupported fallback')
local wrong=table.clone(definitions[1]) wrong.icon='Wrong' assert(B.GetCatalogSpec(wrong)==nil,'identity mismatch')
print('CATALOG_CHECK_PASS firstFive=5 uniqueGeometry=5 anatomy=true connectedAABB=true wristOrigin=true visualOnly=true unsupported=true independentSpecs=true')
```
