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

## Follow-up: retain non-LOS growth failures

The next actual growth run had clear/readable ratios 1, no transient obstruction or physical intersection, and no settle timeout. Its underlying `valid` remained false. Consequently there were no obstruction records to recover, while its inline assertion caused Studio's error serialization to truncate the only scalar summary before the runner could save it.

The growth camera payload now returns that same bounded summary before the runner validates it. Its original combined validity expression and every original regex gate remain unchanged. An additional required `growthCameraContractValid=true` marker carries the actual combined decision. This unique marker is necessary because the old generic `"valid":true` regex could otherwise match a successful nested sampler result when overall growth framing failed. Executed regex controls accept a complete valid result, reject false overall validity despite true nested metrics, and reject a missing marker; the old regex-only false pass is reproduced as a control.

This follow-up changes only the growth flow, its contract, and this document. It does not change source, camera behavior, or acceptance thresholds. Actual complete scalar evidence is still required before a gameplay fix can be selected.

## Follow-up: distinguish accepted combat from client intent

The complete actual result in `smash-post-full-growth-use-maximized-20260906/power-avatar-growth.json` now identifies the single failed motion term: measured `lead=0.6420499682426453` against the unchanged `lead>1` prerequisite. All LOS/readability ratios are 1, all eight avatar corners are visible, physical/unresolved frames are zero, the camera settled, and selected orbit error is approximately 0.0261 studs. This does not establish a camera safety or framing defect.

Source inspection explains the missing evidence. `tryPunchAction` returns true once the client cooldown permits an animation attempt and `FireServer` request; it does not wait for a server hit or lunge, and it also does not require either animation/follow initializer to return true. The sampler counts these returns as six actions. Follow lead is measured from actual root displacement minus the delayed translation, rather than an unconditional effect amplitude. The later pet preparation calls `Reset`, whose world reset returns the character to spawn; it does not restore the preceding combat placement. Nevertheless, full Power requests a 48-stud lunge with a 55-stud trace, while the first wall is only 19 studs ahead of spawn. Spawn distance alone therefore does not prove an air punch. Equal `maxBackFrom`/`maxBackTo` values also do not prove a stationary root: those fields change only when a backward step exceeds the prior maximum.

The flow now reads bounded server and client state immediately before the original six-punch call and immediately after it succeeds. Failure cleanup independently reads both states before any stop, respawn, or other cleanup. Six distinct saved contexts preserve `growthCameraServerBefore`, `growthCameraClientBefore`, `growthCameraServerAfter`, `growthCameraClientAfter`, `growthCameraServerCleanup`, and `growthCameraClientCleanup`; cleanup cannot overwrite the baseline or prevent stop-play cleanup.

The server observation retains current pose, velocity, health, anchoring, Power/WallLevel, profile readiness, actual accepted-action/hit/lunge timestamps, hit counts, ownership token, planned travel/barrier, and actual lunge travel. A separately labeled **48-stud current-pose ray diagnostic** uses the production lunge's horizontal direction and exclusion list; it is not a claimed historical ray result or actual lunge distance. The client observation retains current pose/subject, native rig, animation count/suppression, actual follow flags, measured peak lead, cooldown, and phase. Both record shared server time; the client also labels its local clock. Clock values from distinct time domains must not be subtracted. Latest hit/travel attributes may predate the measured six punches, so conclusions require the before/after pair rather than the last value alone.

These observations perform only reads and a local ray query, contain no waits or game actions, and each enforces an encoded length below 3900 characters. The entire camera payload and every acceptance gate remain byte-identical to `40d9390`; all other original steps remain structurally identical to `532e03c`. No gameplay or source change is included, and no threshold is relaxed.

Validation: `node work/automation/scripts/power-avatar-growth-contract.mjs` passes 18 source checks, 18 existing flow assertions, **15 executed assertions against the exact new observation payloads**, six rejected mutations, and compilation of all **22** flow/cleanup Luau snippets. New controls retain real zero/false/low-lead values, distinguish missing actors/UI/subjects, verify current ray filters and no-hit handling, and reject either removed context bound. Structural checks enforce read-only probes, unchanged acceptance, distinct evidence names, immediate pre/post ordering, and independent failure cleanup. Node syntax also passes. The Coordinator must replay the complete growth flow and compare these observations before a fixture or production fix is justified; that runtime result remains pending.

## Confirmed cause and minimal server fix

The subsequent paired observations in `smash-post-full-punch-pet-exclusion-20260906/power-avatar-growth.json` prove six accepted requests: the ownership token advances from 5 to 11, server action/hit/lunge timestamps advance, and the native R15 client records six unsuppressed punches with follow enabled. The server plans 48 studs with no body-sweep barrier but publishes actual/safe travel approximately 0.000174 studs. The full sequence moves the root only about 1.57 studs forward. This explains the small camera lead; neither the lead threshold nor camera feedback needs amplification.

The Coordinator's **actual native** comparison, preserved in `smash-growth-native-ray-compare-20260906.json`, captures one origin near `(-2,4.515,-19.5667)` and identical directions/exclusions. The original query hits `PetDropEgg`, with `CanCollide=false` and `CanQuery=true`, at approximately 2.600321 studs. Subtracting the unchanged 2.6-stud lunge clearance leaves approximately 0.000321 studs. Changing only the local query parameter `RespectCanCollide` to true returns no hit and therefore a full 48-stud ray allowance. The remembered depth primary is already broken, HP zero, and noncollidable/nonqueryable. That comparison confirms the blocker rather than inferring it merely from the egg's presence.

`hitDepthBlock` synchronously creates a dropped egg before `depthPunch.Punch` computes its cleared path and calls `depthPunch.Lunge`. The egg remains queryable for pickup. Previously the final lunge ray treated every returned object as a physical blocker, using the default `RespectCanCollide=false`; it never inspected the object's collision property. Consequently a successful punch's own reward could stop that same punch's movement. Roblox's [WorldRoot API](https://create.roblox.com/docs/reference/engine/classes/WorldRoot) documents that default ray parameter.

The server change sets **`params.RespectCanCollide = true`** only on `depthPunch.Lunge`'s final ray. Its exclusion list, clearance, locked-depth pass, full character sweep, damage planning, ownership token checks, tween, and cleanup are unchanged. The pickup retains its query flag and interactions. No client code, growth fixture, camera threshold, economy rule, or imported asset changes.

The new `punch-lunge-collision-filter` flow creates an owned elevated floor in strictly ephemeral Studio and executes three native server punches: clear path, an actual production query-only egg, and a solid collider behind that egg. It positions the production egg on the test ray while preserving its pickup properties; this is controlled collision geometry, distinct from the naturally spawned egg in the confirmed failure. It first verifies actual native ray eligibility, then invokes the real server punch and records actual root travel, at least two PostSimulation observations, server network ownership, new punch timestamp/token, endpoint clearance, and zero body overlap. The clear/egg paths require the complete configured 10.5-stud lunge; the solid case requires the actual native hit distance minus the existing clearance. Because this isolated scene has no depth targets, the expected combat outcome is `no_block`; that does not waive real movement or authority checks. Coins and pet inventory must remain unchanged. Protected cleanup resets the player, destroys only its owned fixture, and returns bounded evidence even on failure; the independent flow cleanup also runs before stop.

Offline validation passes:

- `node work/automation/scripts/punch-lunge-collision-contract.mjs`: **64 assertions executing the exact production Lunge**, 17 assertions executing the native flow's actual verifier, six rejected source mutations, and three compilations (server plus both flow payloads). Baseline `f10dfc5` fails on the query-only egg. Controls retain real solid clearance, zero-travel clamping, locked/broken/unlocked depth behavior, stale-character/token rejection, interrupted tween rejection, and ownership restoration. The existing body-sweep, full Punch, and pickup producer are byte-equal to the baseline.
- `node work/automation/scripts/power-scaled-penetration-contract.mjs`: 21 source checks, 30 executed assertions, 14 rejected mutations, 23 compiled snippets/controls.
- `node work/automation/scripts/power-avatar-growth-contract.mjs`: existing 18 source checks, 33 executed flow/observation assertions, six rejected mutations, 22 compiled snippets.
- Node syntax and complete server compilation at O0/O2 pass.

The updated-source native flow and complete growth replay remain **pending** Coordinator integration and Studio verification. Run those first, followed by the existing power-scaled penetration and hybrid lunge/collision regression. The new contract requires registration by the Coordinator; no shared registry was edited here. The prior growth-camera acceptance expression and six-punch count remain unchanged.

## Native lunge verification and showcase preflight follow-up

The Coordinator subsequently recorded all four relevant native flows as passing: `punch-lunge-collision-filter`, `power-avatar-growth`, and `power-scaled-penetration` in `work/docs/evidence/smash-lunge-solid-filter-runtime-20260906`, followed by `punchwall-hybrid-physics-lunge` in `smash-lunge-solid-filter-hybrid-20260906`. The worker reviewed those saved manifest results without operating Studio. This supersedes the preceding pending status for these four targeted checks; it does not claim a rebuilt artifact or full final suite has passed.

The next assignment changes only `studio-final-visual-capture.mjs` and this document. The profiler, its latest phase guards, gameplay code, existing evidence, image decoder, artifact manifest checks, exact nine-source checks, native reopen identity/proof, and cleanup ownership remain intact.

### A starter fixture must follow entitlement reconciliation

The genuine `desktop-fresh-hud.jpg` from `smash-current-source-visual-review-r2-20260906` shows approximately **22.8K** effective power and premium companions. Its old preflight checked only base Power 15 and Coins 0. The same client evidence records six premium feedback events ending with Celestial Titan. That image is an entitlement-bearing startup, not a verified starter profile.

The server sets `ProfileReady` before its asynchronous ownership reconciliation finishes. `reconcileOwnedGamePasses` calls the real configured GamePass ownership route even in ephemeral Studio. That route restores legitimately owned fists and pets; `StudioTestGrantPremium=false` does not disable it. The configured last fist multiplier 60 and all three premium pet multipliers totaling 24.3 produce `15 * 60 * (1 + 24.3) * 1.001 = 22792.77`. This explains the real HUD without a stale image or base-Power mutation.

The capture tool now waits at most 25 seconds for `GamePassOwnershipReconciled=true`, `GamePassOwnershipReconciliationFailed=false`, and an empty pending queue **before** calling Reset. A nil pending-count attribute is accepted only with those completion flags: the producer never creates a queue attribute when no grants were queued. Failed, still-pending, or timed-out reconciliation aborts without Reset. Strict non-writable `EphemeralStudio` and both live-data opt-out guards run first.

It then invokes the existing ephemeral Reset and verifies server readback: base Power/Coins, mastery and all power multipliers, exact Starter Glove ownership/equipment, empty premium/pet/honor lists, no training, and initial tutorial state. EffectivePower comes from the actual loaded `GameConfig.EffectivePower(15,1,0,0,1,0)`, currently **15.015**, while the displayed starter HUD rounds to **15**. Setting mastery to zero merely to obtain an exact numeric 15 would be the wrong fixture and is rejected.

The client waits at most eight seconds for replicated stats, the actual shared Starter Glove model, zero companion models, visible Power/Coins text, and initial onboarding. Once settled, it records old entitlement feedback, clears existing toasts/markers exactly once through the existing client controller, waits another half second, and requires no later feedback or stale toast. Both authoritative server state and actual client/HUD state are checked again before and after the original image. The manifest explicitly labels this a **reset starter fixture after entitlement reconciliation**, preserving the account's legitimate production entitlement behavior.

### Device resolution, safe UI area, and image raster are different measurements

The Coordinator's native `smash-phone-native-area-20260906.json` and unmodified JPEG establish this exact built-in iPhone 17 Pro landscape session:

| Measurement | Native value |
| --- | --- |
| Built-in device ID / configured resolution | `iphone_17_pro` / 874 × 402 |
| Preset resolution scale / preset DPI / active DPI | 3 / 460 / approximately 153.3333 |
| Full UI area from `GetInsetArea(None)` | 873 × 401, minimum (-62, -78) |
| Device-safe area from `GetInsetArea(DeviceSafeInsets)` | 749 × 361, minimum (0, -58) |
| `Camera.ViewportSize` | 749 × 361, exactly matching the native device-safe area |
| Core-safe area | 749 × 303, minimum (0, 0) |
| Original MCP JPEG raster | 1204 × 553 |

All observed native rectangles and configuration values remain identical before and after the image. The JPEG aspect matches the full UI area scaled by FitToWindow. Roblox documents [Camera.ViewportSize](https://create.roblox.com/docs/reference/engine/classes/Camera#ViewportSize) as device-safe dimensions in UI offset units, which may differ from display pixels; the full rendering area includes the notch/cutout region. [GuiService:GetInsetArea](https://create.roblox.com/docs/reference/engine/classes/GuiService#GetInsetArea) exposes the corresponding rectangles, and [StudioDeviceSimulatorService](https://create.roblox.com/docs/reference/engine/classes/StudioDeviceSimulatorService) exposes the selected preset and scaling configuration.

The corrected tool configures and verifies the same built-in preset in both Edit and Client. Every phone capture requires its exact ID/name, non-custom status, 874 × 402 configuration, LandscapeLeft, and FitToWindow. It independently reads all three native rectangles, checks containment, requires camera dimensions **exactly** equal the device-safe area, and checks that the production HUD root and inset settings match that same area. The full UI dimensions may differ from the configured resolution by at most the measured one-unit integer-boundary rounding. No hardcoded 749 × 361 camera size is substituted, and no phone layout or touch gate is relaxed.

Every original image retains its actual encoded dimensions, bytes, MIME type, and SHA-256. Before/after device configuration and rectangles must remain identical, and its raster aspect must match the independently read full area within one raster-edge rounding unit. The manifest records full UI units, safe UI units, configured device resolution, and actual raster separately. Image bytes are written before post-capture verification, so a later check failure preserves the original failed image with `verified=false`. Any incomplete capture, failed guard, changed artifact/source/binding, or cleanup error leaves the run nonzero and not passed.

### Offline verification and remaining runtime gate

`node work/automation/scripts/studio-final-visual-capture.mjs --self-test` passes **67 checks**, compiles all **16** production Luau snippets, and executes **147** native-state/fixture guard controls in the Luau CLI. These include pending/failed/never-completing reconciliation with zero Reset calls, nil empty queues, actual premium state reset, corrupt authoritative lists/power, stale HUD/companions/equipped fist, missing onboarding, late feedback/grants, wrong device/resolution/orientation, inconsistent safe rectangles, native rounding bounds, and original raster mismatch. Four intentionally weakened production guards demonstrably admit the corresponding bad inputs, confirming the controls distinguish missing safeguards. The unchanged shared profiler contract also passes 66 checks, eight compiled snippets, 53 executed Luau assertions, and seven rejected mutations. Node syntax and `git diff --check` pass.

No Studio session was operated by this worker. The Coordinator must run the updated fresh and five-screen desktop/phone capture against the current verified source, then repeat its normal rebuilt-and-reopened artifact verification and capture. Those new tool/runtime and final artifact outcomes are **pending**, not inferred from these offline controls or the earlier source-only images.
