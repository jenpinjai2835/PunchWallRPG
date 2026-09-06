# Starter pet actual visual review — 2026-09-06

Status: **P2 confirmed: Forest Pup Inventory preview faces away from its retained face decal.** A1 owns the correction. This read-only audit does not claim a fixed visual result, successful texture fetch, or rebuilt final release.

## Evidence identity

- Actual native Studio capture: `work/docs/evidence/smash-current-source-visual-review-r2-20260906/desktop-inventory-pets.jpg`, 1277 x 780, SHA256 `585aa0d0fdd0770049387b1551497e5063dc7e9512c103456f3849ee88c84290`. Its manifest explicitly labels the capture **current source, NOT rebuilt or reopened final artifact**, source commit `7630dd4ef38841f84ee6d0c2e26242b88ab95910`.
- Read source from integration `acdfeb0d674498c23f5e0a3bb33dfdea0fc2dadb`; `git diff 7630dd4..acdfeb0` is empty for both the main client and InventoryUI, so the preview producer matches the captured revision.
- Read embedded model data from `outputs/PunchWallRPGPlayable_v1_final.rbxlx`, SHA256 `605a4f70169fd0c7c86635b20171576dc4a81c46b10a4e28c8744f4f29a40208`. This is carried asset data, not proof that the current source has been rebuilt into that output.
- Independently viewed historical `work/docs/evidence/pet-pack-70715599928632/inventory-eight-pack-pets.jpg`: Forest Pup already has the same blank-block presentation. The old candidate capture page 1 is obscured by the loading overlay and is not useful proof of the chosen pet's appearance.

## Confirmed cause

The actual current screenshot shows plain pale block bodies in both Forest Pup cards and its detail preview; Miner Cat retains a visible face and protrusions. The embedded Forest Pup is a real retained catalog model, not an empty object: it contains two visible MeshParts named Stone, one invisible Root, and an invisible AnimatedFace carrying a visible Front decal. Its body mesh IDs are `1461040253` and `1461041563`; both also occur in Miner Cat. Both models intentionally have empty MeshPart TextureID properties, so empty mesh textures do not establish a Forest Pup loading failure.

Forest Pup's decal is present at output line 93963: `rbxassetid://2759037468`, Face=5, Transparency=0. Miner Cat has Front decals `2552066096` and `2544156220` on two parts facing opposite directions. [Roblox NormalId](https://create.roblox.com/docs/reference/engine/enums/NormalId) identifies 5 as Front; the [official Decal examples](https://create.roblox.com/docs/reference/engine/classes/Decal) also demonstrate a decal on a fully transparent parent part. Parent transparency alone therefore does not explain this blank preview.

`InventoryUI:_applyPetPreview` at `src/client/InventoryUI.lua:2088–2096` preserves the model's authored pose, then positions its camera at bounding-center plus **world** `(0.48d, 0.2d, -d)`. It never uses the pet's actual face direction. An XML-derived oriented-box calculation using every BasePart corner and the actual Root primary-part basis gives:

| Quantity | Forest Pup value |
| --- | --- |
| Bounding-box size | `(1.483205, 1.728840, 1.496559)` |
| Actual formula's distance d | `2.6` |
| Camera position | `(-189.714086, 1.384437, 48.118284)` |
| Face outward normal | `(-0.976674259, -0.0000000547, 0.214735135)` |
| Front face center | `(-191.694718, 1.023857, 50.870734)` |
| normal dot (camera minus face center) | **-2.525480 studs** |

The negative signed distance proves this camera lies behind the only face plane. Miner Cat's opposite-facing second decal explains why that model can show a face with the same generic world-space camera direction. This is a concrete authored-orientation mismatch; it does not require attributing a missing texture or an engine loading defect.

## Expected asset, fallback and readiness trace

- `src/shared/GameConfig.lua:417` maps Forest Pup to `Sanitized_ForestPupPet` / Dowodle. `PolishConfig.lua:206` records pack `70715599928632`, preloaded-only source child Dowodle. The manifest's retained-child table is at `work/docs/FREE_ASSET_MANIFEST.md:236`.
- `install-pet-pack-templates.mjs:39, 89–132` clones that child, sanitizes it and records source/part-count attestation. It does not replace its face texture or orient its preview.
- `src/shared/FistVisualBuilder.lua:460, 486–522` preserves allowlisted Decal/Texture objects; sanitization changes collision/anchoring/effect limits and removes behavior, not retained decal URIs.
- `src/client/PunchWallClient.client.lua:4962, 5129, 5156` verifies container provenance, sanitizer state, model presence and part count. This is structural readiness, not proof that each texture fetched or faces the camera.
- `StyleNormalCatalogPet` at line 5038 lightly tints Common geometry; it adds no Forest Pup silhouette or face. `BuildInventoryPetPreview` at line 5768 uses the attested catalog clone first. Only absent/rejected catalog content falls through to the procedural pet (or eligible curated dragon). No observed evidence establishes that this screenshot used fallback.
- `InventoryUI.lua:2028–2048` caches a preview master. At line 2102 it marks PreviewReady after cloning/framing; it does not await content-fetch success. The main client's preload at lines 1260–1276 does not explicitly include PunchWallExternalAssets; generated Inventory previews may not exist at that initial preload. URI fetch success remains unmeasured, but that uncertainty does not remove the proven back-facing geometry defect.

## Narrow correction and acceptance handoff

A1 was sent the exact part CFrame, face normal and signed-distance proof. Derive the preview direction from the retained face's **actual part CFrame**, for example `part.CFrame:VectorToWorldSpace(Vector3.FromNormalId(decal.Face)).Unit`, with a small side/elevation offset in that same basis. Do not rotate the model or apply the bounding-box rotation a second time. Preserve existing geometry, size, fit, cached model identity, cleanup and the separate fist-preview direction. A narrow Forest Pup rule avoids arbitrarily picking between Miner Cat's two opposite faces; any broader face-selection policy needs deterministic semantic selection and its own review.

Required evidence after correction: native card and detail captures with a readable retained face, positive camera-to-face plane distance, unchanged mesh/decal IDs and model identity, existing projection/fit and mobile checks, plus no preview render loop or idle rebuild. Query the exact face URI fetch status if the correctly facing native image remains blank. The present audit does not assert that texture data loaded successfully or that the original block-shaped source meets every desired species/art preference.

## Optional root UI diff review

Read-only review of root's immutable `1604d1567c4e997a89df28f005d298ca5cc8ba7e` found no introduced callback or ownership defect in the viewed main-client diff. Purchase action predicates/callbacks remain intact; the new Inventory dimmer stays at ZIndex 89 below InventoryRoot/Backdrop at 140. Raised text floors and simplified objective copy still need the root's actual rendered-fit flow, especially narrow product names. No native visual pass is inferred from source review.

No production source, automation, Studio state, raw asset, or release artifact was changed by this audit. Only this document is the audit deliverable; separately registered pet-camera diagnostic commits retain their own evidence and pending runtime status.
