# Legacy fist flow alignment — 2026-09-06

Owner: Agent 3; isolated branch `codex/test/smash-legacy-fist-qa-20260906`, base `965b6d14ef876e37966b4f15ec832b3e436f94f0`. Scope is these three flows and this document. No game source, commerce configuration, Studio, registry, or persistence implementation was changed.

## Coverage retained and corrected

- `fist-items-icon-ui.json` inspects all 16 regular Shop cards by scrolling each into view. The first five require actual shared catalog geometry, matching identity, camera projection, a static pose, and no raster/chrome overlay. The other 11 require the expected loaded raster image, identity, tier, motif, bounded perimeter chrome, and non-interactive decoration. Existing avatar, HUD atlas/crops, 500-coin → 320-coin Boxing purchase, modal restoration, and exact toast icon coverage remain. The toast feedback Luau chunk is byte-for-byte unchanged.
- `hero-city-reference-ui.json` retains world-sign, HUD action-button, atlas, and native Inventory window checks. Its old five direct-child static-card expectation is replaced with the actual 16-card descendant catalog and five-native/11-fallback split. The selected Starter Inventory preview must contain matching physical geometry that fits its viewport.
- `creator-store-fist-visuals.json` tests the actual imported fallback route with Magma Breaker and all three premium fists. The first five no longer use Creator Store meshes. Existing approved mesh identity, material/color, cuff, plates/fins, hand fit, part budget, weld endpoints, and visual-only hazards remain checked against real descendants. The flow compares native Boxing Shop art with fallback Magma art, then checks respawn cleanup, saved item restoration, and a released punch. It does not claim to prove native shoulder recovery; the dedicated rig flow owns that check.
- Every reset/seed refuses live-data Studio: world and player must report `EphemeralStudio`, the profile must be non-writable and ready, and both opt-in indicators must prohibit live access. Premium fixture grants do not invoke commerce purchases. Lifecycle markers contain serialized strings only; no Instance references are shared between execution calls.

`ImageLabel.IsLoaded` is used for the fallback route so an assigned asset ID alone cannot pass the art check. Its client-side meaning is documented in the [official Roblox API reference](https://create.roblox.com/docs/reference/engine/classes/ImageLabel/IsLoaded). A missing or moderated image intentionally fails the bounded loading check.

## Validation and integration gate

- PASS: all 15 embedded Luau snippets compile with Luau 0.737.
- PASS: `node work/automation/scripts/fist-pet-safety-contract.mjs` — 38/38 checks.
- PASS: feedback chunk equivalence against the branch base; JSON parse and `git diff --check`.
- PASS: the exact `inspectShopCard` helper accepts all three valid fixtures and rejects all 14 faults below (`SHOP_ROUTE_HELPER_PASS safe=3 rejected=14`). Geometry/projection are deliberately stubbed in this narrow test; actual geometry checks remain in the Studio flows.
- **BLOCKED — Studio validation pending Coordinator integration.** Run all three changed flows against the integrated source and record their artifacts. Syntax, stubs, and source contracts are not rendering, network, or engine-runtime evidence. Existing all-19 equipment and first-five parity results belong to their original flows and do not certify these revised flows.

The helper fixture accepts a native Starter, compact-title Boxing card, and fallback Magma card. It must reject 14 faults: wrong native model identity, wrong viewport identity, raster coverage, visible native fallback, legacy chrome on a native card, idle rotation, wrong fallback image, unloaded image, active chrome, wrong tier, wrong motif, missing pip, excessive chrome count, and wrong displayed item title.

## Reproducible narrow helper fixture

Read the following `luau` block, replace its `-- INSERT_EXACT_SHOP_HELPER` line with the substring from `local function inspectShopCard` up to `local function inspectRegularShop` in the `shopFistChromePresentation` flow step, and execute with Luau. Require the final marker and no error output. If feeding the interactive CLI, concatenate quoted source chunks into one global string and call `loadstring`; direct multiline REPL input has a continuation limit.

```luau
local function object(class,props)
 local item=props or {} item.ClassName=class item.attrs=item.attrs or {} item.children=item.children or {}
 function item:IsA(expected) return self.ClassName==expected end
 function item:GetAttribute(name) return self.attrs[name] end
 function item:FindFirstChild(name) return self.children[name] end
 function item:GetChildren() local out={} for _,child in pairs(self.children) do table.insert(out,child) end return out end
 return item
end
local function add(parent,name,child)
 child.Name=name child.Parent=parent parent.children[name]=child if name~='Name' then parent[name]=child end return child
end
local function untilReady(fn,message) local value=fn() assert(value,message) return value end
local function visible(item) return item.Visible~=false end
local function catalogModels(viewport) return viewport.models or {} end
local function verifyGeometry(model,def,preview) assert(preview and model:GetAttribute('FistVisualKey')==def.name) return 14 end
local function verifyPreviewProjection() return {insideViewport=true} end
local onWait
local task={wait=function() if onWait then onWait() end end}
local Vector2={new=function(x,y) return {X=x,Y=y} end}
local Color3={new=function(r,g,b) return tostring(r)..','..tostring(g)..','..tostring(b) end}
local G={ShopArt={TitanGlove='gold'}}
local B={GetCatalogSpec=function(def) return def.native and {} or nil end,GetHeroGauntletPresentation=function(def) return def.pr end}
local function fixture(native,compact)
 local def={name=native and (compact and 'Boxing Glove' or 'Starter Glove') or 'Magma Breaker',displayName=native and (compact and 'Boxing Glove' or 'Starter Glove') or 'Magma Breaker',tier=native and (compact and 2 or 1) or 6,icon=native and 'NativeIcon' or 'MagmaFist',native=native}
 def.pr={variantKey=def.icon..':variant',shopArtKey='TitanGlove',catalogMotif='LAVA',version='Presentation',signatureFeature='SIEGE'}
 local shop=object('Frame')
 add(shop,'ShopCatalogScroll',object('ScrollingFrame',{AbsoluteSize={Y=500},AbsolutePosition={Y=0},CanvasPosition={Y=0}}))
 local card=add(shop,def.name..'ShopCard',object('Frame',{AbsoluteSize={Y=100},AbsolutePosition={Y=0}}))
 add(card,'Name',object('TextLabel',{Text=compact and 'STREET FIST' or string.upper(def.displayName)}))
 local art=add(card,'ProductArt',object('ImageLabel',{IsLoaded=true,Image='gold',ImageTransparency=native and 1 or 0,ImageColor3='1,1,1',Visible=true,attrs={LoadedArtUnobscured=true,HeroGauntletTintMatched=false}}))
 local fallback=add(card,'ProductArtFallback',object('ImageLabel',{Visible=false}))
 local model,viewport,palm,chrome
 if native then
  model=object('Model',{attrs={IconIdentity=def.icon,FistVisualKey=def.name,FistVariantKey=def.pr.variantKey}})
  palm=add(model,'Catalog Closed Palm',object('Part',{CFrame='pose'}))
  viewport=add(art,'FistCatalogPreview',object('ViewportFrame',{Visible=true,attrs={RenderLoop=false,FistVisualKey=def.name},CurrentCamera={CFrame='camera'},models={model}}))
 else
  card.attrs={ShopFistIconIdentity=def.icon,ShopFistVariantKey=def.pr.variantKey,ShopFistCatalogMotif='LAVA',ShopFistArtVariant='TitanGlove',ShopFistTier=6,ShopFistPresentation='PresentationStaticChrome',StaticPreviewIdentityVersion='UniqueFistPerimeterV2',StaticPreviewStyleVersion='PerimeterCatalogIdentityV2',StaticPreviewRenderLoop=false,StaticPreviewChromeOnly=true,StaticPreviewChromeCoverage='PerimeterOnlyV1',StaticPreviewPartCount=12}
  chrome=add(card,'HeroGauntletTierChrome',object('Frame',{Active=false,Selectable=false}))
  add(chrome,'StaticTierOutline',object('UIStroke')) add(chrome,'StaticTierRail',object('Frame'))
  local badge=add(chrome,'StaticTierBadge',object('Frame')) add(badge,'StaticTierNumber',object('TextLabel',{Text='T06'}))
  add(chrome,'StaticSignatureFeature',object('TextLabel',{Text='SIEGE'})) add(chrome,'StaticCatalogMotif',object('TextLabel',{Text='LAVA'}))
  add(chrome,'StaticTierPip1',object('Frame')) add(chrome,'StaticTierPip2',object('Frame'))
 end
 return {shop=shop,card=card,art=art,fallback=fallback,model=model,viewport=viewport,palm=palm,chrome=chrome,def=def}
end
-- INSERT_EXACT_SHOP_HELPER
local passed,rejected=0,0
local function test(name,native,compact,mutation)
 local case=fixture(native,compact) onWait=nil if mutation then mutation(case) end
 local ok,err=pcall(inspectShopCard,case.shop,case.def)
 assert(ok==(mutation==nil),name..': '..tostring(err))
 if ok then passed+=1 else rejected+=1 end
end
test('native starter',true,false)
test('native compact title',true,true)
test('fallback magma',false,false)
test('wrong native identity',true,false,function(c)c.model.attrs.IconIdentity='wrong'end)
test('wrong viewport identity',true,false,function(c)c.viewport.attrs.FistVisualKey='wrong'end)
test('raster covers model',true,false,function(c)c.art.ImageTransparency=0 end)
test('visible native fallback',true,false,function(c)c.fallback.Visible=true end)
test('native legacy chrome',true,false,function(c)add(c.card,'HeroGauntletTierChrome',object('Frame'))end)
test('native idle rotation',true,false,function(c)onWait=function()c.palm.CFrame='moved'end end)
test('wrong fallback image',false,false,function(c)c.art.Image='wrong'end)
test('unloaded fallback image',false,false,function(c)c.art.IsLoaded=false end)
test('fallback input interception',false,false,function(c)c.chrome.Active=true end)
test('wrong tier',false,false,function(c)c.card.attrs.ShopFistTier=1 end)
test('wrong motif',false,false,function(c)c.chrome.StaticCatalogMotif.Text='wrong'end)
test('missing pip',false,false,function(c)c.chrome.children.StaticTierPip2=nil end)
test('unbounded chrome',false,false,function(c)c.card.attrs.StaticPreviewPartCount=99 end)
test('wrong visible item title',true,false,function(c)c.card.children.Name.Text='wrong'end)
assert(passed==3 and rejected==14)
print('SHOP_ROUTE_HELPER_PASS safe='..passed..' rejected='..rejected)
```
