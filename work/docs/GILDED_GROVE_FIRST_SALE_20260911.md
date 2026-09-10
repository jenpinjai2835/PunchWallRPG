# Gilded Grove first paid listing

Published ordinary Model **122456766146790**, revision **2**, as **Gilded Grove - Merchant & Loot**, **US$5.99**. Owner: **jennarong2835 / 9158952231**.

Public storefront: https://create.roblox.com/store/asset/122456766146790/Gilded-Grove-Merchant-Loot

Delivery is 24 original base props in three palettes: 72 placements, 99 persistent MeshParts, 75,648 triangles. This is a visual asset collection, with named role pivots and anchored, non-colliding parts. No runtime scripts or gameplay systems are included. The native Store product does not promise delivery of the separate local Blender/FBX/GLB ZIP.

## Acceptance evidence

All evidence paths below are relative to `outputs/creator-packs/gilded-grove-native/`.

| Gate | Result | Evidence |
| --- | --- | --- |
| Aggregate isolated GLB reimport | PASS, 897 checks | `validation.json`, `contact-sheet.png` |
| Mesh and texture dependencies | PASS, 102 assets owned by seller and Approved | `dependency-audit.json` |
| Grounding regression | Revision 1 correctly FAILS; corrected source PASS | `verify-revision1.json`, `verify-corrected.json` |
| Native binary preservation | PASS, only CFrame/PivotOffset changed; 95 other chunks and header byte-identical | `binary-preservation.json` |
| Independent binary decoder | PASS, 2,376 exact transform components, 99 anchored parts, three textures | `independent-validation.json` |
| Native update | PASS, same ordinary Model, revision 2 Approved | `update-revision2.json`, `final-model-metadata.json` |
| Fresh engine reload | PASS, 72 props including authored bounds, role pivots, dimensions, hierarchy and persistent content | `fresh-revision2.json`, `verify-final.json` |
| Actual Studio visuals | PASS, native revision 2 palette colors, grounded forms and separated roles inspected | `studio-final-teal.png` |
| Paid listing after reload | PASS, distribution enabled at US$5.99 | `dashboard-sale.json` |
| Signed-out storefront | PASS, Buy For $5.99; technical details report 75,648 triangles and 99 MeshParts | `public-sale.json`, `store-public-paid.png` |
| Temporary credential cleanup | PASS, named key deleted and in-memory secret cleared | `key-revocation.json` |

The first native preparation incorrectly used the outer LoadAssetAsync wrapper's bounding-box pivot as the source origin. Geometry was 3.479 studs below its authored ground. Preparation now uses the authored aggregate root. Verification checks actual geometry bounds relative to each prop origin, so dimensions alone cannot conceal this defect.

Original revision-1 backup: `original-store-model.rbxm`, SHA256 `14872f48f5cb0d657b1a4f28fc1f275a5117ce3274033c3571143324c90133fb`. Corrected upload: `corrected-store-model.rbxm`, SHA256 `9772ab0eb298cbdb3637a1a85b9a6dbec5032139a9f06670f0e30d83603a86e4`.

## Reproduction and limitations

`work/creator-packs/gilded-grove/publishing/prepare-model.lua` prepares static native assets from owned imported meshes. `patch-transforms.py` applies the engine-produced map to the original native binary while preserving all unrelated chunks. `open-cloud.mjs` journals POST/PATCH operations and refuses uncertain duplicate operations. Secrets are supplied only in memory.

Run the passive native engine flow after loading the actual Store asset:

```powershell
node work/creator-packs/gilded-grove/publishing/build-verification-flow.mjs GildedGroveFinalVerification
node "C:/Users/Jennarong Pinjai/.codex/skills/roblox-studio-mcp-automation/scripts/flow_runner.mjs" --flow work/automation/flows/creator-packs/gilded-grove-native-model.json
```

The local `InsertService:LoadLocalAsset` route was BLOCKED by Studio capability restrictions; it was not counted as passing. Native engine verification instead loaded the authorized private revision-2 update through AssetService before opening sale. Historical console errors are recorded in `authoring-console-history.json`: one denied SourceAssetId probe, the intended revision-1 negative test, and the blocked local-import attempt and consequent missing-instance assertion. No asset code runs; this is edit-time model validation, not a gameplay or performance test. No buyer purchase transaction was executed.

The initial Open Cloud GLB import, asset **82732630458121**, is a private Package and is not the sellable product. The native ordinary Model was created through Studio's upload dialog; later content updates preserved that identity. Original game source and release place were untouched.

User authorization covered paid publication, the temporary restricted key and its deletion, and autonomous continuation. After the first paid link was verified and shown, remaining nine catalog packs resumed under their existing isolated owners. This first-pack result does not claim completion of the ten-pack catalog.
