# Camera handoff completion — 2026-09-06

Source-only commit: `099fe51977dcd0e2beeff8a1959155dcf854d8e8`, based on the accepted/held pet chain ending at `07e4009`. The Coordinator owns integration and Studio. This task did not alter a flow, launch Studio, or change the frozen full-suite source.

## Evidence and diagnosis

Frozen full-suite `punch-camera-smooth-follow.json` reported a settle timeout with public handoff active, geometry clamped, zero inside/physical failures, and a final radius about 0.026 studs beyond the selected radius. The recorded result lacked the cache/raw/requested pose stages and teleport count needed to identify its precise cause.

A3 independently demonstrated two reachable source defects using the actual resolver and guard from `6211b00`, `a5fea5d` and `521711b`:

1. A cached pose at `(0,0,12)` loses LOS. The current native pose at `(0,0,12.026091575622558)` is physically and visually clear. In the controlled sensor scene, LOS is blocked when `z < 12.02` and `abs(x) < 3`. The resolver finds a same-radius side destination, but the existing direct, vertical and combined-horizontal limited steps all cross the LOS edge. The invalid old cache cannot be published, and the valid nearby native pose never becomes a recovery origin. The handoff remains active after 81 × .05 seconds. Removing the obstruction permits exact arrival.
2. Successful teleport rebasing clears the internal handoff state but leaves `PunchCameraHandoffActive` true. That stale public flag survives subsequent ordinary clear frames and causes observers to report an unfinished handoff.

These are controlled production-code reproductions, not reconstructions of the actual L009 geometry from the failed Studio run. The new runtime diagnostics distinguish them; neither is claimed to be the sole proven cause of the recorded failure.

## Source change

The limiter adds independent X and Z waypoint attempts after its existing direct, vertical and combined-horizontal attempts (client line 8083). Every endpoint must pass the existing physical and LOS checks; every route retains the physical sweep. The camera rotation and focus offset are preserved.

During recovery, a nearby current native pose may replace an invalid carried cache as the local origin (line 8289) only when it passes the complete pose check, lies within the current correction budget, and the physical sweep from the previous origin is clear. Active punch follow retains its existing owner. The distance used to adopt the origin is deducted from `24 * min(deltaTime, .1)` before taking a waypoint, and the reported correction distance includes that origin change. The change adds no allowance above the original 2.4-stud correction or 2.65-stud ordinary physical escape gates.

The original `.001` arrival test remains. Handoff is not cleared just because the radius is within the regular `.08` native-camera tolerance, and no timeout is accepted as success. Successful teleport rebasing now synchronizes only the public handoff marker alongside the existing internal reset (line 8210); its eligibility and camera selection are unchanged.

Studio-only diagnostics retain three bounded records: last recovery response, first stalled response with a remaining route, and maximum remaining route distance (line 7881). They contain raw/cache/origin/requested/candidate/published positions, root displacement, phase and selected limiter reason, physical/LOS classifications, both internal recovery states, the public marker and teleport rebase count. Records clear on character reset and at automation sampling start. The automation result exports these fields (line 8723). Published games do not allocate the new records. This is a bounded storage claim, not a measured performance result.

## Executed checks

| Check | Result |
| --- | --- |
| `node work/automation/scripts/camera-geometry-guard-contract.mjs` | PASS: 198 assertions, 24 rejected mutations; complete client O0/O1/O2 and existing camera flow payloads compile. |
| `node work/automation/scripts/camera-geometry-guard-contract.mjs --baseline-settle 07e4009` | Both no-progress and stale-rebase-marker failures reproduced before the patch. |
| Same command with baseline `6211b00` and `a5fea5d` | Both defects reproduced in each source revision. |
| `node work/automation/scripts/camera-shop-stability-contract.mjs` | PASS: 17 existing production assertions. |
| `node work/automation/scripts/pet-size-position-contract.mjs` | PASS: 490 assertions, 10 rejected mutations, both affected pet flow payloads compile. |
| `node work/automation/scripts/power-avatar-growth-contract.mjs` | PASS: 18 existing checks, 18 executed flow assertions, 4 rejected mutations. |

The new exact-resolver/guard fixture reaches its actual same-radius endpoint in three bounded responses. Separate controls reject adopting an LOS-blocked raw pose, crossing a physical barrier to adopt a raw pose, or using a distant raw pose beyond the local budget. They preserve an already valid cache and active punch ownership. A tiny-frame fixture proves that a remaining error below .08 still cannot clear the original .001 arrival gate. Teleport marker verification isolates the branch with no available recovery path before the teleport, then requires exact-radius rebase and continued public release through the original timeout window. Diagnostics are checked for stable bounded storage, reset and absence in a published-game mock.

The nine new mutations remove raw-origin adoption, axis waypoints, origin-budget accounting, teleport marker synchronization, exact arrival, physical origin sweep, raw LOS validation, local-distance eligibility or Studio-only diagnostic allocation. Each fails its intended executed assertion. The fifteen existing camera safety mutations still fail their original checks.

## Remaining verification

**BLOCKED pending Coordinator runtime execution** after integration: `punch-camera-smooth-follow`, the long-tunnel/zoom/teleport camera flows, camera/shop stability and the affected pet/growth flows. The original physical `.55` probe, `.3` inside sample, LOS/readability/opacity requirements, zoom limits, Scriptable bypass, final fresh-pose assertions and settle timeout remain unchanged. No runtime pass or absolute camera-stability claim follows from these mocks.
