# Camera visibility and follow backlog — 2026-09-06

Base: `ef9b5f8`. Source scope is the camera geometry guard and its diagnostics, plus the Coordinator's explicit handoff of two missing combat HUD scan publications. No Studio operations were performed by this worker.

## Confirmed failures

The Coordinator's old-source long-tunnel rerun recorded root Z -212.8626 and camera Z -91.64675. The final orbit was 121.2419 studs against a requested 12.47449, with a timed-out handoff and zero settled samples. The camera stayed outside geometry, but the clear-character ratio was 0.0742. This confirmed accumulated follow delay rather than a missing opacity reset.

An extracted production-guard replay independently reproduced two defects:

- A clear destination was replaced by a physically clear but opaque-obscured intermediate position. The guard published and cached that position while reporting `GeometryClamped=false` because the limiter, final check, and fallback acceptance only tested overlap.
- Ten clear updates at 5 FPS, with a five-stud root displacement each update and a requested 12-stud orbit, ended with a 38-stud orbit. The fixed correction budget was also limiting ordinary root-follow movement.

## Change

Every limiter candidate and held position now passes the complete camera pose check, including sight lines to the character. The final published pose and cached/baseline fallbacks receive that same validation. An independently verified intermediate pose can advance recovery even when the more distant requested endpoint has no valid solution.

The guard first carries its previous clear position by the current root displacement if the complete physical route is clear. It then applies the existing `24 * min(deltaTime, 0.1)` correction budget from that carried position. This preserves the physical sweep and avoids spending the correction allowance on ordinary character movement. Root displacements above 30 studs continue through the existing teleport path. Live camera rotation and focus offset are retained.

Diagnostics distinguish inherited root movement from corrective movement. The original punch-follow step bound remains; the long-tunnel sampler additionally requires corrective steps at or below 2.65 studs. The runtime flow retains zoom, rotation, readability, zero-inside, opacity, follow completion, and eighteen real punches. A fresh independent `GetPartsObscuringTarget` query now also rejects opaque obscurers and records their actual properties. The flow preserves full returned JSON and the unique top-level `contractValid` gate added by the Coordinator.

The authorized HUD wiring publishes the focused wall and Titan boss to `PunchWallCombatHUD.Refresh()` at the end of the existing target scan. The missing-character/world path clears both targets and refreshes before returning. No other HUD behavior changed.

## Verification

- PASS: main client and both actual long-tunnel Luau payloads compile with official Luau 0.737.
- PASS: `node work/automation/scripts/camera-geometry-guard-contract.mjs` — 58 executed production-guard assertions, covering physical sweeps, alternative steps, cache/fallback validation, lifecycle, Scriptable ownership, late Invisicam, distinct LOS-only obstacles, low-FPS root following, and partial recovery.
- PASS: `node work/automation/scripts/camera-geometry-guard-contract.mjs --baseline-los ef9b5f8` — six new failure cases reproduced before the patch; existing controls still pass on that baseline.
- PASS: `node work/automation/scripts/camera-geometry-guard-contract.mjs --baseline b521dea` — all seven earlier camera/lifecycle failure cases still reproduced.
- PASS: unchanged `camera-shop-stability-contract.mjs` — 17 production behavior assertions.
- PASS: eleven transient Luau controls extracted the actual long-tunnel acceptance predicates; opaque obscurers, inside geometry, fading, wrong camera ownership, unfinished follow/handoff, failed zoom restore, oversized corrections, failed sampled visibility, and unreadable characters are rejected.
- PASS: Agent 1 independently ran its combat HUD contract against this source: 382 executed production assertions, eight semantic mutations, and required scan/event wiring. Its compile check covered the client and seventeen owned HUD flow payloads.
- PASS: `git diff --check`.

Actual Studio validation is **PENDING Coordinator integration and rerun**. The geometry probes are bounded by the existing 30-stud teleport threshold for ordinary root movement; runtime performance and visibility under actual falling tunnel blocks still require the affected camera flows and combined suite. No runtime or visual pass is claimed by these offline checks.
