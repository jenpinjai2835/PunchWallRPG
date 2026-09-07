---
name: punch-wall-rpg-development
description: Implement, review, test, or document a Punch Wall RPG change. Use for Roblox gameplay, map, UI, economy, destruction, mobile controls, Creator Store visual assets, Rojo source, automation flows, or final-place release work in this repository.
---

# Punch Wall RPG Development

Use the project source and recorded automation as the source of truth. Preserve the playable train-to-destruction progression loop while making every change reproducible and testable.

## Start Here

1. Read `AGENTS.md` and the relevant existing documentation in `work/docs/`.
2. Read `references/gameplay-and-scope.md` for player-loop, progression, and content decisions.
3. Read `references/quality-and-release.md` before changing visuals, imported assets, automation, output places, or release documentation.
4. Inspect `git status` and keep the change isolated from unrelated in-progress work.

## Implementation Rules

- Make gameplay changes in `work/punch-wall-rpg/src/`; use Roblox Studio only to sync, run, inspect, and validate the source.
- Keep game authority on the server. Client code may drive input, camera, HUD, and local feedback but must not decide rewards, damage, purchases, or progression.
- Add or update a flow in `work/automation/flows/` for every changed player-visible path. Do not rely on a manual click sequence as the only proof.
- Make mobile controls use the same validated gameplay path as world interaction. Keep gameplay and UI readable at touch-device sizes.
- Treat `outputs/PunchWallRPGPlayable_v1_final.rbxlx` as a deliberately rebuilt artifact, never a substitute for source changes.

## Visual Asset Rule

Use Creator Store imports for decoration only. Remove all imported code and behavior objects, keep only approved visual objects, anchor decor, and document every retained asset and its fallback in `work/docs/FREE_ASSET_MANIFEST.md`.

## Verify And Record

Run the smallest relevant regression while iterating. Run the full flow suite for gameplay, UI, map, progression, or final-place changes. Update the appropriate QC, build, or release note with commands run, results, and known limitations before handing off.

## References

- `references/gameplay-and-scope.md`: canonical game loop, content boundaries, and feature acceptance.
- `references/quality-and-release.md`: source, asset, automation, mobile, output, and release gates.
