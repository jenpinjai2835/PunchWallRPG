# Gilded Grove local asset delivery — 2026-09-10

Task: ASSET-MERCHANT-20260910. Coordinator: Agent4. Scope: an original stylized merchant and loot collection, 24 base models, three palettes, editable source, individual portable exports, three samples, real product renders and a buyer guide. This task does not modify Smash gameplay, production publishing or the previously blocked v1.0.6 publication.

## Delivered locally

Source: `work/creator-packs/gilded-grove/`. Artifacts: `outputs/creator-packs/gilded-grove/`. Full and sample ZIP files are in its `delivery/` directory. The full collection has 25,216 triangles in 33 meshes; each asset has 140–2,464 triangles. All assets were authored with included geometry code; no third-party mesh or texture is included. There are no game scripts in the delivered models.

Workers supplied containers (953a7fb), fixtures (b4d7f53), bearing correction (2adec12), buyer packaging (55ae247) and independent export validation (691a35a,33ca78e). The Coordinator integrated those handoffs before final artifact checks. Source and output hashes are recorded in the acceptance evidence and ZIP ledgers.

## Verification and exact limits

| Gate | Result | Evidence / scope |
| --- | --- | --- |
| Blender FBX and GLB roundtrip | PASS | 48 isolated imports; 1,020 export checks, no failures. Mesh/triangle counts, finite transforms, dimensions, pivots, sole active palette UV and embedded textures. `evidence/exports-final.json`. |
| Authored color correctness | PASS | Three PNG palettes, each with all 16 cell centers matching authored sRGB bytes exactly. Independent PNG decoder rejects the previous dark-palette fixture. Included in the same final report. |
| Local Studio mesh construction | PASS | Actual GLB vertices/faces instantiated through documented EditableMesh APIs: 24 models /33 MeshParts /25,216 triangles. `evidence/studio-geometry-final.json`. Local Content objects are temporary preview data; this is not a persistent native asset delivery. |
| Recorded Studio authoring flow | PASS | `work/automation/flows/creator-packs/gilded-grove-assets.json`, three checks: isolated place, exact visual-only model structure, sample presence and reversible chest hinge rotation. `evidence/studio-flow-final.json`. |
| Native visual review | PASS | Actual Studio captures of collection, stall, pouch and upgrade station in `evidence/studio-*.png`; corrected badge and bearing are visible. Studio 0.737.0.7371584, viewport1277×801, Edit mode. |
| Blender visual review | PASS after fixes | All24 portraits and collection inspected. Badge intersection and floating axle corrected; cover type/lantern spacing adjusted. Final closure is recorded in acceptance evidence. These pictures are Blender renders, not Roblox performance screenshots. |
| Native File > Import | BLOCKED | Windows capture reports `SetIsBorderRequired: No such interface supported (0x80004002)`; indexed input lacks window geometry and keyboard shortcut attempts did not open the importer/save dialogs. User cleared Auto-Recovery, allowing MCP work. Do not interpret EditableMesh preview as an importer pass. |
| Persistent Roblox model and listing | NOT PERFORMED | No uploaded mesh IDs, persistent `.rbxm`, seller onboarding, priced listing or asset permissions have been created. Original meshes/textures must be imported/uploaded and tested under the intended creator before sale. |
| Console | Scoped result | No authored asset errors were returned by the final commands. Studio Output contains an existing built-in MaterialManager React profiling warning; the global console is not claimed clean. |
| Physical mobile/gameplay/FPS | NOT APPLICABLE to source-pack acceptance | No HUD, gameplay, game map or final Smash place changed. No target-device FPS, collision integration, multiplayer or sales claims are made. |

The overall sale-ready gate remains BLOCKED on native import/upload validation. The usable local source package is delivered with that limitation. Keep the feature PR in draft until the outstanding gate is resolved; do not merge or mark overall HQ READY on the basis of the local preview.

## Reproduction

Use Blender 4.5.9 LTS. The first build renders all24 portraits; presentation creates the full collection and three cover variants. The final source palette fix encodes authored sRGB bytes directly, then reloads packed source images. This avoids Blender generated-image buffer color conversion assumptions.

```text
blender --background --factory-startup --python work/creator-packs/gilded-grove/src/build.py -- --out outputs/creator-packs/gilded-grove
blender --background --factory-startup --python work/creator-packs/gilded-grove/src/presentation.py -- --package outputs/creator-packs/gilded-grove
blender --background --factory-startup --python work/creator-packs/gilded-grove/src/validate_exports.py -- --package outputs/creator-packs/gilded-grove --report outputs/creator-packs/gilded-grove/evidence/exports-final.json
blender --background --factory-startup --python work/automation/scripts/validate_gilded_source.py -- --package outputs/creator-packs/gilded-grove --source work/creator-packs/gilded-grove/src/geometry.py --report outputs/creator-packs/gilded-grove/evidence/source-structure-final.json
blender --background --factory-startup --python work/creator-packs/gilded-grove/src/studio_geometry.py -- --package outputs/creator-packs/gilded-grove --out work/tools/gilded-studio-geometry
node work/creator-packs/gilded-grove/src/studio-preview.mjs STUDIO_ID work/tools/gilded-studio-geometry outputs/creator-packs/gilded-grove/evidence/studio-geometry-final.json
node work/automation/scripts/flow_runner.mjs --flow work/automation/flows/creator-packs/gilded-grove-assets.json --studio-instance-id STUDIO_ID --result-file outputs/creator-packs/gilded-grove/evidence/studio-flow-final.json
python work/creator-packs/gilded-grove/src/package.py --package outputs/creator-packs/gilded-grove --source work/creator-packs/gilded-grove --out outputs/creator-packs/gilded-grove/delivery
```

The asset flow lives in a subfolder so normal Smash gameplay regression does not try to run it against a production game place. Select a separate local Place1/GildedGrove Studio instance, with placeId0, before preview construction. The scripts fail closed for other places. The ZIP packager uses explicit file allowlists, omits historic QA/diagnostic tools/backups, and verifies every archived byte, CRC and SHA256 ledger.

## Issues found and closed

1. Primitive UV maps were exported instead of PaletteUV. Export objects now have one UV layer; independent reimports inspect the material's selected UV route and every face's atlas cell.
2. Coin pouch badge intersected leather. Increased its relief and moved it outward; Blender and Studio images show one complete diamond.
3. Upgrade handwheel floated. Added a foot, upright and collar; visual and support-contact checks passed.
4. Generated PNGs contained linear color bytes interpreted as sRGB. Explicit PNG encoding plus independent authored-color checks correct this; previous self-consistency-only reports are historical, not final color acceptance.
5. Local preview placed mesh roles twice by their center. Centered raw vertices before MeshPart placement; separated lids and portal sections now align in actual Studio captures.
6. Unused palette image datablocks were dropped when saving the editable source. All three images now retain a fake user, are packed, and are checked after reopening both source scenes.

Official workflow references: [Roblox Importer](https://create.roblox.com/docs/studio/importer), [Blender workflow](https://create.roblox.com/docs/art/blender), [EditableMesh](https://create.roblox.com/docs/reference/engine/classes/EditableMesh), [Creator Store](https://create.roblox.com/docs/production/creator-store). Creator Store delivery does not automatically deliver this raw ZIP; confirm an appropriate delivery mechanism before advertising Blender/source files in a paid platform listing.
