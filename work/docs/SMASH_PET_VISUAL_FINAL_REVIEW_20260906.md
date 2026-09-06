# Pet visual peer review — 2026-09-06

Reviewer: HQ Agent 1. Source was read from immutable Git commits; no source, flow, script, Studio or HQ changes were made by this reviewer. The only repository write is this document.

Initial source: `521711b5aa76e98b4faf9678fbb5afdda429d640`. Projection correction: `efa90fc492d5ad134363c0ac2db9203ff50adc1b`. Final source reviewed: `4033e884315ae759fe2c0ab10dca83973856ba88`; final test handoff: `07e4009e811d638d66c441ba5f1acc4d9363fdff`. The Git-extracted client SHA-256 is `d9942ce0a8200d8a9598032d63130cbe415d79226980767e6d086c4c3f143fff`. This review remains conditional on Coordinator integration and actual runtime verification.

## Findings and disposition

**P2 found in 521711b, corrected in efa90fc: safe-frame conversion assumed fullscreen and device-safe heights were equal.** `KeepBoundsInSafeFrame` divided the vertical frustum by `Camera.ViewportSize.Y`, while projecting corners with `WorldToViewportPoint`. Official [Camera documentation](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/Camera.yaml) describes `FieldOfView` as using the fullscreen render area and `ViewportSize` as excluding device cutouts (lines 504–525). `FieldOfViewMode` only determines which FOV remains invariant during resize; `FieldOfView` is still the current vertical FOV (lines 245–292).

The independent exact-source counterexample uses a 390 × 750 safe viewport, fullscreen render height 844, vertical FOV 70°, an identity camera, box size `(1.8, 1.1, 0.95)` and box center `(0.15, 0, -3.328)`. The documented perspective projection has focal length `844 / (2 * tan(35°))`. The required horizontal interval is `[4.4, 385.6]`.

| Source | Reported fit | Translation magnitude | Actual projected X interval |
| --- | --- | --- | --- |
| `521711b` | true | 0.166239691997 | **[1.450078687, 381.688853984]**, outside even the original 1% inset |
| `efa90fc`, `4033e88` | true | 0.147724844784 | **[5.361224703, 385.6]**, within the unchanged inset |

This is an executable reproduction using the documented projection geometry, not a claim that a physical iPhone or current Studio emulator returned those dimensions. Coordinator's current emulator observations may have equal render and camera viewport dimensions. The correction removes the assumption by calibrating independent horizontal and vertical projection scales from three actual projected points at camera depth 10. Corner projection and translation now use the same coordinate system.

**Near-plane validity corrected in 4033e88.** The former 0.05 front-depth threshold could label positive-depth geometry safe while it was inside the platform's actual near clipping plane. The same official Camera documentation gives a platform-dependent `NearPlaneZ` (lines 475–486). The final helper requires every corner to exceed `max(0.05, abs(Camera.NearPlaneZ))`. The independent positive-depth box at depth 0.25 with near plane −0.5 is now rejected. The caller still leaves an infeasible model unchanged; this validity correction does not claim to move, hide or restore visibility of every clipped model.

No further introduced P1/P2 was established in the final source by this review. The pre-existing early combined-signature return is explicitly retained as a limitation below.

## Source and lifecycle review

- `BoundsCorners` computes eight local corners once per distinct `state.boundsSize`. Scale changes already refresh cached bounds; the new corner cache follows that change. No new per-update descendant or bounding-box scan was added.
- `KeepBoundsInSafeFrame` intersects every corner's permitted X/Y translation intervals. Choosing the nearest permitted value to zero minimizes camera-plane translation. It changes neither the box's orientation nor any corner's camera depth. Missing/uninitialized cameras, degenerate projection, near-plane intersections and impossible intervals return the unchanged frame with `false`.
- The heartbeat applies the correction after bob, pitch/roll and exponential interpolation, immediately before the model's existing pivot-to-bounds conversion and `PivotTo`. Subsequent budget/culling and motion-setting logic still runs. The result uses the actual current camera on each update, including resized or replaced cameras.
- The final path performs at most eleven projections per updated pet: three calibration points and eight corners. Existing 20/30/60 Hz scheduling remains. For three pets at 60 Hz this is at most 1,980 projection calls/second; this is a work bound, not a measured FPS result. Telemetry remains on the existing 0.25-second cadence.
- The full `refreshCharacterVisuals` function preserves actual pet models and motion state across hand-size, fist and Honor refreshes, while rebuilding their gloves/attached cosmetics as before. Character identity and equipped tokens/order invalidate the pet set. Empty lists clear old models. Initial uninitialized cache fields short-circuit safely.
- When execution reaches the new pet-cache block, a detached model or different selected template instance invalidates the set. The earlier combined-signature return can bypass this block when all player visual inputs and the gauntlet are unchanged. Exact-source controls reproduce both an externally removed pet remaining absent and a replacement template remaining unused until another visual signature changes. Coordinator classified this as a pre-existing external-lifetime/hot-reload limitation, not a regression to widen this patch around. This patch is not an independent template or model lifetime observer.
- Creator Store selection, attestation, sanitization, clone construction, normalized sizes, pet definitions, effects and server economy paths are unchanged. Normal and premium pets share the final projection correction. It constrains individual boxes; it does not independently solve pet-to-pet or avatar overlap. Existing actual size, overlap, separation, culling and identity gates remain required.

## Independent evidence

The temporary reviewer harness extracts `BoundsCorners`, `KeepBoundsInSafeFrame` and the **entire** `refreshCharacterVisuals` from the requested immutable commit. It uses an independently authored 3D CFrame/vector and perspective model, including arbitrary camera rotation and model pitch/yaw/roll. Its files are `C:/Users/Jennarong Pinjai/AppData/Local/Temp/smash-pet-independent-review.py` and the corresponding `smash-pet-independent-review-<commit>.luau`.

Commands:

```powershell
python 'C:/Users/Jennarong Pinjai/AppData/Local/Temp/smash-pet-independent-review.py' 4033e884315ae759fe2c0ab10dca83973856ba88
& 'C:/Users/Jennarong Pinjai/AppData/Local/Temp/codex-luau-smash-0.737/luau.exe' 'C:/Users/Jennarong Pinjai/AppData/Local/Temp/smash-pet-independent-review-4033e88.luau'
```

PASS: 1,929 assertions: 432 geometry cases across three aspect ratios, three FOVs, three depths and sixteen orientations/phases, plus explicit unavailable/invalid/impossible/near-plane, cropped-projection and lifecycle controls. Of the matrix cases, 230 required translation. Shortening each successful nonzero translation by 0.1% breaks containment, checking minimality independently. Rotation, camera depth and measured shift are also checked. Repeating the cropped-projection test on `521711b` fails specifically at `actual cropped projection preserves opposite-edge safe inset`.

Immutable implementation tests `8d1a273` were read and executed against its source snapshot: pet contract 440 geometry/publication + 38 full-refresh + 6 actual flow assertions, eight rejected mutations; growth contract 18 existing checks + 18 actual flow assertions, four rejected mutations. The test's camera model assumed equal render and viewport heights, explaining why it did not detect the cropped-projection defect.

The final immutable files were extracted into a temporary review tree, with no reads from the worker's mutable source. The following commands were rerun against final source `4033e88` and contract `07e4009`:

| Command under `work/automation/scripts/` | Reviewer result |
| --- | --- |
| `node pet-size-position-contract.mjs` | PASS: 441 geometry/publication, 38 full-refresh, 5 cropped-projection and 6 actual-flow assertions; 10 rejected mutations; complete client and every payload in both changed flows compile. |
| `node pet-size-position-contract.mjs --baseline 2ddecc6` | PASS: both intended historical source failures reproduced, with specific assertion failures rather than syntax errors. |
| `node pet-size-position-contract.mjs --projection-baseline 521711b` | PASS: intended opposite-edge cropped-projection failure reproduced. |
| `node power-avatar-growth-contract.mjs` | PASS: 18 existing checks, 18 exact-flow assertions, 4 rejected mutations. |
| `node fist-growth-lifecycle-contract.mjs` | PASS: 25 actual production lifecycle assertions. |
| `node camera-geometry-guard-contract.mjs` | PASS: 166 assertions, 15 rejected mutations, complete-client O0/O1/O2 and both long-tunnel payloads compile. |
| `node camera-shop-stability-contract.mjs` | PASS: 17 actual production assertions. |

These are offline checks, not substitutes for the actual held camera and pet regressions. `git diff --check` and the final allowed-path review passed for this one-document handoff.

## Integration limits

Actual runtime checks remain **BLOCKED pending Coordinator execution** after the frozen full-suite run and source integration. Required affected evidence includes the final pet-size-position and power-avatar-growth flows, normal/premium visual parity, body/hand/respawn recovery, desktop/mobile projected bounds and overlap, and the held camera checks. The frozen failures were inspected only as baseline evidence; this review does not relabel them passing or claim a final place artifact or measured performance improvement.
