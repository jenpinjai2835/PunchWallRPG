# Camera geometry and lifecycle correction — 2026-09-06

Owner: Agent 2, Coordinator-assigned scope. Branch: `codex/fix/smash-camera-guard-20260906`, base `b521dea`.

The combined runtime found two sampled camera intersections during the eighteen-punch tunnel flow and a separate false preservation flag after Invisicam reached the client. Final source review identified an unchecked smoothed camera position, unchecked baseline fallback, one-time occlusion initialization, and persistent follow flags/recovery caches surviving character replacement. These defects were present before this task's camera changes; the new tests reproduce them against the assigned pre-fix base.

## Changes

- Validate the actual camera position after smoothing and before writing or caching it. During follow/recovery, probe the bounded translation path with overlapping 0.55-stud position queries spaced at most 0.25 studs. A blocked diagonal tries bounded vertical and horizontal movement; otherwise the camera holds the clear origin. Each normal movement remains limited to `24 * min(deltaTime, 0.1)` studs. This avoids replacing a safe endpoint with an unsafe intermediate position.
- Validate fallback positions immediately before use. A physically clear recent position is retained even when its view is temporarily obscured; an invalid recent position may use only a physically checked nearby baseline. The existing maximum fallback-distance guard remains. A blocked cached pose is never republished as an unchecked escape.
- Bind opacity handling once and observe `DevCameraOcclusionMode` changes. Late replicated Invisicam updates the live policy and activates the same callback; switching away stops its writes.
- Clear persistent follow/motion flags, shared camera caches and the guard's local recovery/orbit state on character replacement. Scriptable camera ownership remains respected.
- Remove camera writes from the long-tunnel sampler. It now observes production output, retains the complete sampled result in failure diagnostics, and records each of the first eight collision samples with part, punch, camera/root positions, render age and active guard flags.
- Extend the existing flows with real server property replication and actual client `Punch` followed by server-triggered respawn. The respawn assertion checks the persistent GUI, flags, camera subject/type, orbit, zoom, readability and physical clearance. No zero-collision, opacity, zoom or readability gates were relaxed.

## Verification

- [x] `luau-compile.exe --null work/punch-wall-rpg/src/client/PunchWallClient.client.lua` — PASS.
- [x] `node work/automation/scripts/camera-geometry-guard-contract.mjs` — PASS, 27 executable assertions against the extracted production guard, CharacterAdded callback and occlusion binding.
- [x] `node work/automation/scripts/camera-geometry-guard-contract.mjs --baseline b521dea` — seven expected failures reproduced: unchecked limited position, thin-wall route crossing, blocked baseline, unchecked final publish, old-character recovery cache, persistent respawn flags and late Invisicam policy.
- [x] `node work/automation/scripts/camera-shop-stability-contract.mjs` — PASS, 17 assertions covering live orbit/zoom, suspended-render drift, Scriptable handoff, Depth eligibility and boost countdown identity.
- [x] All 26 actual Luau payloads in the four assigned camera flows compile. JSON parsed before compilation.
- [x] `git diff --check` — PASS.
- [ ] Coordinator integration, source sync, affected Studio camera flows and final combined runtime suite — pending Coordinator. This worker did not access Studio or rebuild the place artifact.

The isolated tests control geometry and scheduling; they do not claim rendered visibility or smoothness in Roblox. The runtime gate must still establish zero sampled intersections, readable settled avatars, preserved user zoom/orbit, opaque obscurers and successful client-follow interruption on respawn. Registration of the new contract in the shared static runner belongs to the Coordinator.
