# Quality And Release Reference

## Source And Output

- Author gameplay in `work/punch-wall-rpg/src/` and sync it into Studio before testing.
- Keep automation flows under `work/automation/flows/` and documentation under `work/docs/`.
- Rebuild and commit the final `.rbxlx` only with the source, flow, and verification evidence that produced it.
- Keep Studio-only commands and developer controls out of the player release UI.

## Asset Safety

- Imported Creator Store assets are visual-only.
- Remove imported `Script`, `LocalScript`, `ModuleScript`, unsafe prompts, and behavior objects.
- Keep only necessary visual content such as parts, meshes, attachments, particles, beams, trails, decals, and textures.
- Anchor non-gameplay decoration and disable collision where appropriate.
- Record asset ID, creator, purpose, retained objects, and procedural fallback in `work/docs/FREE_ASSET_MANIFEST.md`.

## Test Gates

Use fast regression while iterating:

```powershell
powershell -ExecutionPolicy Bypass -File "F:\Roblox\PuchWall\work\automation\run-fast-regression.ps1"
```

Use full regression before merging gameplay, UI, map, progression, or output-place changes:

```powershell
powershell -ExecutionPolicy Bypass -File "F:\Roblox\PuchWall\work\automation\run-existing-flows.ps1"
```

Before a Studio test of source changes, sync the current source:

```powershell
node "F:\Roblox\PuchWall\work\automation\scripts\sync_rojo_source_to_studio.mjs"
```

## Visual And Mobile QA

- Test a fresh player flow, normal-balance destruction, and relevant failure/gate cases; do not use boosted test power as the only evidence.
- Confirm camera behavior through attacks, vertical movement, and confined spaces.
- Confirm touch controls, HUD readability, safe areas, and no overlap at Android/iPhone layouts.
- For feedback and motion changes, capture evidence for training, punch/hit, wall break, reward, shop, pet, rebirth, and boss paths as applicable.
- Track P0/P1/P2 findings in the relevant QC document and keep claimed release quality aligned with current evidence.
