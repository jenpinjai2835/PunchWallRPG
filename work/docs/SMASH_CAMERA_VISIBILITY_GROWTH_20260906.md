# Camera visibility and growth investigation — 2026-09-06

Status: **diagnostic-only handoff; runtime visibility failures are not fixed or waived.** The Coordinator owns the next Studio run. This patch preserves the camera guard, player zoom, punch behavior, and every existing visibility/safety acceptance threshold.

## Actual evidence and uncertainty

The `camera-long-tunnel-regression` result in `smash-post-full-targeted-camera-pets-20260906` completed 18 punches with physical intersections/unresolved frames zero, settled LOS/readability ratios 1, restored native ownership, and selected orbit preserved at approximately 23.2628 studs. Its sampled clear ratio was `0.49390243902439026`: 83 of 164 samples were obscured. The existing minimum remains 0.55. Reported obscurers include a pet egg and depth blocks; the final fresh scene was clear.

The growth flow passed its actual size, grounding, pet identity/size, and downscale checks. Its final camera had all eight bounding-box corners visible, the current humanoid subject, and physical intersections zero, but the aggregate camera `visualValid` was false. The original flow omitted the sampler metrics needed to explain that failure. A body-framing adjustment is not supported by this evidence.

The runner truncates each error/context string above **4000 characters** (`flow_runner.mjs`), so the original nested camera result lost its middle in both the error and saved context. Changing that shared runner is outside this task. The camera sampler observes current LOS at `task.wait` resumption; ordinary LOS correction occurs during rendering, while PostSimulation repairs physical overlap. Blocked samples could therefore involve later physics, current query/render visibility differences, or actual limited recovery. The existing evidence does not prove which dominates. The selected radius is retained rather than forcing the previously tested smaller radius.

## Diagnostic-only changes

- The Studio-only `__RunCamera` observer counts samples and obstructions separately for active follow, handoff, geometry recovery, and native control. It records the longest consecutive obstructed run and fresh ray/query mismatch counts without changing any acceptance counter.
- Three first-obstruction records span the beginning, middle, and end of the requested punch sequence; one additional record retains the last obstruction. They include actual camera/look/root/head positions, orbit, guard age/phase/previous result, current head/body ray results, and the selected obscurer's identity, CFrame, size, velocity, query/collision flags, and structural state. Positional display vectors use three decimals; acceptance still uses original full-precision values.
- The flow's main result retains all scalar camera measurements, failed visibility gate names, and per-phase counts. Large nested records no longer crowd out the primary result.
- On failure, four client cleanup reads save individual diagnostic pages before the original stop-play cleanup. Each page explicitly requires fewer than 3900 characters and cannot prevent stop cleanup. This preserves evidence without adding ordinary-run waits or changing the punch count.
- The growth error now includes the same compact sampler metrics. Its exact original validity expression and expected regex gates are preserved.

All observation code is inside the existing Studio-only camera automation region. Published gameplay gains no visibility observer or diagnostic query. No camera behavior change is included in this handoff.

## Validation and next run

`camera-geometry-guard-contract.mjs` passes **213 executed assertions and 27 rejected mutations**, including fresh LOS versus previous guard state, finite stage storage, uncapped failure counters, and preservation of false acceptance values in compact evidence. The complete client compiles normally and at O0/O2; both long-tunnel payloads and all four failure-detail pages compile.

`camera-shop-stability-contract.mjs` passes its existing 17 assertions. `power-avatar-growth-contract.mjs` passes its 18 source checks, 18 actual flow assertions, four mutation controls, and compiles all 16 growth flow/cleanup snippets. Additional structural checks compare the revised flows to base `532e03c`, preserving unrelated steps, every existing expected regex, original growth-camera validity, and stop cleanup.

Run the two exact revised flows after source sync: `camera-long-tunnel-regression` (18 punches) and `power-avatar-growth` (six camera punches within the complete growth sequence). Preserve the old evidence. If either fails, its primary result should expose exact failing ratios and its `cameraVisibilityDetail1`–`4` contexts should distinguish current LOS from the last guard response. A production camera change will be proposed only after that evidence is read.

For API interpretation, Roblox documents [Camera:GetPartsObscuringTarget](https://create.roblox.com/docs/reference/engine/classes/Camera#GetPartsObscuringTarget) as a camera LOS query with arbitrary result order, and documents [raycasting](https://create.roblox.com/docs/workspace/raycasting) as excluding parts with CanQuery disabled. The diagnostic records both mechanisms rather than assuming identical eligibility. No third-party claim or hypothetical engine issue is treated as the actual root cause.
