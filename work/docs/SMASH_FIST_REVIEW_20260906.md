# Fist review regression handoff — 2026-09-06

Owner: HQ agent-1. Base: `47fdf52`. Branch: `codex/test/smash-fist-review-20260906`.

## Checklist

- [x] Replace cross-execute Instance state, strengthen visual hazard checks, and cover actual projection and narrow desktop resizing.
- [x] Validate JSON, compile every embedded Luau snippet, execute focused helper controls, and complete peer contract review.
- [x] Commit only the three owned flows and this handoff for coordinator integration.

## Changes

`first-five-fist-presentation.json` now projects all eight corners of every actual BasePart through the preview camera using the measured viewport aspect and vertical FOV. Shop and Inventory parity rows include `shopProjection` and `inventoryProjection`, with sample count, normalized horizontal/vertical extents and `insideViewport`.

The flow sets an owned desktop simulation to 1277 × 720 before play, then resizes the active simulation to 900 × 600. It verifies all five actual Shop previews at the narrow desktop aspect. Within one client call, each viewport is reduced to 72% width; the check requires the existing model to survive, the camera to refit, and geometry to remain inside the viewport. Its size is restored even when the nested check fails. Output markers: `narrowDesktopProjection = true`, `resizeRefit = true`, five per-item rows with before/resized/restored projections and `sameModel = true`.

Cleanup stops play, restores the previously selected simulator device where available, removes only the owned `Smash Fist QA Desktop Resize` custom device, and clears the temporary editor attribute. Stale `FistCatalogScroll` lookups were corrected to the actual `ShopCatalogScroll` instance name.

`fist-arm-alignment-qc.json` no longer stores character/model Instances in `shared`. The earlier client call tags the old character and outer gauntlet with a GUID and stores only that GUID plus the equipped name in Player attributes. After the server respawns the player, a fresh client call verifies a new untagged character/model, scans Workspace for any surviving old tags, checks restored geometry and saved identity, then clears the Player attributes. Existing `characterReplaced`, `oldModelReleased`, and `savedIdentityRestored` markers remain; `serializedLifecycle = true` identifies the new handoff.

All three flows, including `item-matched-fist-visuals.json`, use the standalone `verifyVisualHazards(model,preview,hand)` helper directly before `verifyGeometry`. It rejects scripts, tools, remotes, bindables, prompts/click detectors, sounds, Humanoids, Animators, AnimationControllers, BodyMovers and all JointInstances. Equipped geometry permits only enabled, exact WeldConstraints joining an in-model BasePart to the current hand. Other constraints are rejected. Previews also reject welds and all particle/trail/beam/light/highlight effects. Both the nested catalog and the outer equipped model are inspected, including the retained imported tiers.

The wrist flow retains actual eight-corner bounds, expected cuff-relative transforms, weld endpoints, idle/punch/recovery verification, current rig reporting, and one authoritative equip request per tested tier. No retry or force-equip bypass was added.

## Verification

- JSON parsing and `git diff --check`: PASS.
- Official Luau 0.737 compilation: **17/17 embedded snippets** across steps and cleanup.
- Extracted actual `verifyPreviewProjection`: **4 executable controls PASS** — square fit, narrow clipping rejection, farther-camera refit, behind-camera rejection.
- Independent agent-3 review against this worktree: batch-b **14/14 PASS**; extracted exact hazard helper accepted two safe cases and rejected **27 unsafe cases** (19 behavior/physics hazards, six preview hazards, wrong endpoint and disabled weld). Agent-3 owns the durable batch contract and its mutation tests.

## Coordinator gate

No Studio operation or source edit was performed by this worker. Actual 900 × 600 rendering, simulator switching while playing, preview resizing and respawn behavior remain pending coordinator execution. Projection tests deliberately inspect conservative part bounding corners rather than screenshot pixels; current camera fitting must contain those corners. Simulator API cleanup failures remain visible through the runner's cleanup output.
