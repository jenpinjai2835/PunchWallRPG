# Camera overlap recovery and selected orbit, 2026-09-06

Scope: Agent 2, isolated `codex/fix/smash-camera-runtime2-20260906` at `781ff4b`. Coordinator owns Studio, integration, runtime validation and release. Source-only handoff: `2308a979aa8ee0db849a163473603f120444f7a3`.

The integrated runtime evidence `work/docs/evidence/smash-integrated-targeted2-20260906/camera-long-tunnel-regression.json` recorded seven inside samples in `DepthBlock_L019_C07_R04`, selected orbit 22.62099, final distance 11.99341 and an unfinished handoff. The earlier large follow backlog had been removed. Two remaining causes were identified: every swept step rejected an origin newly enclosed by falling geometry, and the automation fixed engine zoom at 12 while checking the existing 22.62 selection.

The guard now searches for a small clear exit when moving geometry encloses its previous pose. Its sweep permits the initially occupied segment until the first clear sample, then rejects any re-entry. Each candidate must pass both physical occupancy and character line of sight. The same recovery handles a blocked current camera with no valid cache; accepted fallback poses refresh the camera history. Heartbeat also handles a newly overlapped Custom camera between fresh renders. Scriptable ownership, ordinary swept movement, root transport, camera rotation, focus distance and subsequent orbit recovery remain covered.

Local recovery first searches at most 2.4 studs. A larger enclosing object can require a longer emergency exit; its actual distance is reported as `PunchCameraMaxEscapeStep`. The runtime acceptance gate rejects an escape over 2.65, so an exceptional safety relocation cannot silently pass as smooth movement. An artificial world with no available safe pose reports `PunchCameraSafetyUnresolved`; it is not marked clear. Normal successful publication resets that state.

The Studio-only camera setup reads the actual selected orbit (or the current measured distance when uncached), initializes exactly that radius, and sets matching temporary engine bounds. It retains the final radius tolerance of 0.08 and restores the original bounds. The flow independently compares configured, selected, cached and final radii; the former 12-versus-22.62 mismatch cannot pass. Full sampled results still return through the durable top-level `contractValid` result without truncating an assertion message. New diagnostics include overlap escape count, maximum escape distance, unresolved safety samples and configured orbit.

Validation completed locally:

| Check | Result |
| --- | --- |
| `node work/automation/scripts/camera-geometry-guard-contract.mjs` | PASS: 94 extracted-production assertions and 11 executed flow acceptance controls |
| `--baseline-runtime2 781ff4b` | PASS: four expected failures reproduced before the change—cached overlap, overlap between renders, blocked camera without history, selected-radius setup |
| `--baseline-los ef9b5f8` | PASS: six prior LOS/root-follow failures still reproduced |
| `--baseline b521dea` | PASS: seven prior physical/lifecycle/occlusion failures still reproduced |
| `node work/automation/scripts/camera-shop-stability-contract.mjs` | PASS: 17 orbit, countdown and Depth eligibility assertions |
| Luau 0.737 compile | PASS: complete client and both actual long-tunnel flow payloads; compile is now part of the geometry contract |
| `git diff --check` | PASS |

The contract executes extracted production guard/setup code with deterministic geometry and lifecycle mocks. Its controls include a separate wall after initial egress, opaque candidate rejection, idle motion, Scriptable ownership, selected zoom recovery, an enclosing object that exceeds the smoothness budget, and an impossible geometry fixture which must report failure. These are offline checks; Roblox physics, projection and render timing require the Coordinator's actual runtime run. Runtime gate remains **BLOCKED pending combined Studio verification**, not a claimed visual pass.

The separately observed hand-growth-triggered pet rebuild is deferred as an optional P3 optimization per Coordinator direction. This source patch makes no pet, Honor, Animate, HUD, or Shop changes.
