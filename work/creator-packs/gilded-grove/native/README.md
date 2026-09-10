# Gilded Grove native upload bundle

`outputs/creator-packs/gilded-grove-native/GildedGrove_24Models_3Palettes.glb` is one aggregate model upload containing the existing 24 original Gilded Grove props in Teal, Ember and Amethyst.

The three palettes create **72 placements, not 72 distinct base models**. There are 33 semantic meshes per palette and 99 meshes in the complete bundle. The bundle contains 75,648 triangles. No showcase floor, labels, lights, cameras, animations or runtime scripts are exported.

The hierarchy is package → palette → named prop → semantic mesh role. Each prop is laid out on an eight-unit grid; palette banks are 36 units apart. The prop's local origin and each lid/wheel pivot are preserved from the original exports. Individual dimensions are unchanged. One source unit is intended to be one Roblox stud; confirm the native upload's resulting scale during the fresh Studio load check.

## Rebuild and check

Run Blender from the repository root:

```powershell
blender --background --factory-startup --python-exit-code 1 --python work/creator-packs/gilded-grove/native/build_native_pack.py -- --source outputs/creator-packs/gilded-grove --out outputs/creator-packs/gilded-grove-native
```

The builder imports the existing verified GLBs, applies the exact original palette PNGs, exports one GLB, then reimports a copy from an isolated folder. `validation.json` checks the complete hierarchy, role counts, triangles, dimensions, pivots, atlas coordinates, shader UV selection, authored palette RGB values and embedded PNG bytes. The embedded textures make the GLB self-contained.

`contact-sheet.png` renders the actual aggregate reimport with two CPU threads. Its background and lights exist only in the temporary render scene. To render again without rewriting the GLB, pass `--render-only`. Use `--no-render` to run export and structural checks alone.

This folder does not itself upload or publish the product. Open Cloud upload, a fresh Roblox Studio load and paid Creator Store listing verification remain separate Coordinator checks.
