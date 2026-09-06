# Pet safe frame and growth lifetime — 2026-09-06

Source handoffs: `521711b5aa76e98b4faf9678fbb5afdda429d640`, then projection correction `efa90fc492d5ad134363c0ac2db9203ff50adc1b` and near-plane guard `4033e884315ae759fe2c0ab10dca83973856ba88` (initial tests/docs `8d1a273`), after the held camera commits `a5fea5d` and `2ddecc6`. Coordinator owns integration and Studio verification. This work did not run Studio or change the frozen full-suite source.

## Recorded defects

- `smash-full-integrated-final-20260906/pet-size-position-qc.json`: Celestial Guardian at distance 6, viewport 1277 × 780, bounds x=63..382 / y=1..281. Its top edge was outside the original 7.8-pixel (1%) inset. The follower previously constrained approximate screen area but did not constrain every projected corner after bob, roll and smoothing.
- `smash-full-integrated-final-20260906/power-avatar-growth.json`: the three normal pets had baseline height/scale 0 on the later queried models, while their current measurements were nonzero. Hand growth changed the combined visual signature and destroyed/rebuilt companions. This proves instance churn and missing baseline metadata; it does **not** establish that the pets physically enlarged.

## Source behavior

`companionRuntime.BoundsCorners` and `KeepBoundsInSafeFrame` (client lines 5307 and 5319) cache eight local OBB corners and intersect the permitted camera-plane translations for their actual projections. The existing heartbeat follower applies the result after bob, roll and smoothing, before `PivotTo` (line 9282). The original 1% inset is retained with an additional half pixel numerical reserve. Model scale, orientation, depth and camera pose remain unchanged. The conversion from screen offsets to camera-plane offsets is calibrated with three actual `WorldToViewportPoint` calls at a fixed reference depth, independently on X and Y. This follows the actual projection when the device-safe viewport differs from the fullscreen render area. A corner at or behind `max(0.05, abs(Camera.NearPlaneZ))`, an uninitialized viewport or an impossible interval returns an unsuccessful result without shrinking the pet. `CompanionSafeFrameValid` and `CompanionSafeFrameShift` are published at the existing telemetry cadence.

The render path performs eleven projections per updated pet: three calibration points and eight corners. It reuses model bounds and corner vectors until bounds size changes; it does not add per-frame `GetDescendants` or `GetBoundingBox` work. This is a bounded workload description, not a measured FPS claim.

The pet cache (line 7048) separates companion identity from the hand/fist/Honor visual signature. Ordinary hand-size bursts and fist/Honor refreshes retain the existing companion models and motion state. Character and equipped-token/order changes rebuild them; when this cache block is reached, missing models or changed template instances also invalidate it. The existing early return for a completely unchanged combined signature remains. This is **not** an independent hot-reload/template/lifetime observer, and this patch does not claim recovery from arbitrary external destruction with no other visual change.

## Projection follow-up from independent peer review

The first source handoff incorrectly derived pixels per world unit from the safe viewport height. Roblox documents that FOV uses the fullscreen render area while `ViewportSize` excludes cutouts ([official Camera source documentation](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/Camera.yaml)). A1 provided a counterexample with a 390 × 750 safe area and an 844-high projection, FOV 70, a 1.8 × .054 × .054 box at x=.15 / depth=2.88. The old source reports a valid fit but moves its opposite edge to x=1.45008, outside the original 3.9 inset. The corrected source derives both scale factors from the same projection API used for every corner.

`node work/automation/scripts/pet-size-position-contract.mjs --projection-baseline 521711b` reproduces that exact-source failure. The current fixture passes, preserves depth/size, retains the half-pixel reserve, and reports an impossible cropped fit without shrinking. A mutation that restores the FOV/safe-height assumption is rejected. An ordinary-size 1.8 × 1.1 × .95 box at depth 3.328 also passes. This is a documented projection counterexample, not measured Studio device evidence.

The final small guard additionally refuses to label positive-depth corners inside the actual hardware near plane as safe. A tiny centered box at depth .3 with NearPlaneZ=-.5 is rejected; the mutation restoring a fixed .05 threshold fails. The caller retains its existing no-fit behavior, so this guard alone does not hide or reposition a clipped model.

## Runtime flow changes

- `pet-size-position-qc` retains all earlier readable-size, world separation, overlap, culling and identity checks. Its safe-frame phase measures all eight actual OBB corners at distances 6, 12 and 18, with twenty observations per distance after the existing settle. This covers the slow premium bob cycle. It retains the exact 1% inset, requires a real viewport, and verifies that the Scriptable camera stays at the requested pose. A unique top-level `contractValid` gate rejects a partially passing matrix; at most six failed-corner records are retained.
- `power-avatar-growth` waits at most four seconds for the exact three pets to have real primary parts, positive measured geometry/scale/target height and `SmoothFollowReady`. Baselines are stored centrally and the original models receive per-run identity tags and native `Destroying` observers. The final check distinguishes missing baseline data from measured scale/height growth, proves original-model continuity, and retains the original +0.012 scale / +0.035 height bounds and exact fixed target. It disconnects all three observers and removes its tags/state before asserting either success or failure. There are no added progression requests.

## Offline evidence

Commands run from the task worktree:

| Command | Result |
| --- | --- |
| `node work/automation/scripts/pet-size-position-contract.mjs` | PASS: 441 actual geometry/publication assertions, 38 full production-refresh lifetime assertions, 5 cropped-projection assertions, 6 actual safe-frame flow assertions; 10 weakening mutations rejected; complete source and all payloads in both changed flows compile. |
| `node work/automation/scripts/pet-size-position-contract.mjs --baseline 2ddecc6` | Both historical failures reproduced by extracted old source: one-pixel top edge remains outside inset; hand growth replaces actual companion instances. |
| `node work/automation/scripts/power-avatar-growth-contract.mjs` | PASS: existing 18 source/coverage checks plus 18 executed assertions against both exact flow payloads; 4 weakening mutations rejected. Includes delayed readiness, absent baseline, copied-tag replacement, real height/scale growth, changed target, missing pet and watcher cleanup. |
| `node work/automation/scripts/fist-growth-lifecycle-contract.mjs` | PASS: 25 production lifecycle assertions. |
| `node work/automation/scripts/training-ui-pet-recovery-contract.mjs` | PASS: 23 existing checks. |
| `node work/automation/scripts/camera-geometry-guard-contract.mjs` | PASS: 166 assertions, 15 mutations and full-client O0/O1/O2 compilation. |
| `node work/automation/scripts/camera-shop-stability-contract.mjs` | PASS: 17 production assertions. |

The historical geometry fixture reconstructs an oriented box whose projection has the recorded y=1 upper edge, then checks it with an independent eight-corner projection oracle. The old evidence did not contain the actual asset OBB pose, so this is a source-grounded reproduction of the measured defect, not a replay of unavailable asset geometry. The matrix varies three aspect ratios, three FOVs, three depths and sixteen bob/roll phases. Impossible fits are tested as unsuccessful; no tolerance is relaxed to label them safe.

## Integration gate

Runtime verification remains **BLOCKED pending Coordinator execution** after the frozen suite ends and these immutable source changes are integrated. Required affected runs are `pet-size-position-qc`, `power-avatar-growth`, companion/fist lifecycle recovery, and the held camera regressions. No visual pass, mobile-device pass, FPS improvement or absolute bug-free claim is made from offline mocks. The independent peer review is separate from these implementation checks.
