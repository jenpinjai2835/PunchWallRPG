# Camera failures in the frozen combined run — 2026-09-06

HQ agent-1, independent read-only review of source and flows at `6211b0075df92b38e0b5c13f4824968909a06b10`. Source/evidence read from `F:/Roblox/PuchWall-completion-20260906`; only this document is authored in the isolated settings-attestation worktree. No source, flow, script, Studio, HQ, registry, or output artifact was changed. Agent 2 owns the camera fix.

Verdict: **combined camera acceptance remains BLOCKED**. One actual stale-zoom defect is reproduced with the exact producer. A separate scheduling gap is reproduced with the exact producer and documented engine ordering; the four recorded physical-margin failures lack enough per-failure data to prove that every occurrence used that gap or that a rendered image clipped. Neither failure warrants weakening the existing gates.

## 1. P2: cached orbit overrides changed camera zoom limits

Evidence: `work/docs/evidence/smash-full-integrated-final-20260906/camera-teleport-scriptable-visibility.json`.

The failed predicate is **distance < 20**. Both baseline and final distance are `30.164321899414064`, despite the fixture setting both Player zoom limits to 12. The guard successfully rebased the teleport: rebase count 0 → 1, root displacement 63.259, zero distance change, Custom camera, no overlap or fading.

`scriptValid=true` and `scriptError=0` were captured while Scriptable and already passed the exact bypass requirement. The result's later `bypass=false` is read after switching back to Custom; that is expected. It is not an independent Scriptable ownership failure.

Frozen client lines 7993–8032 apply a cached `userOrbitDistance`. Initialization runs only when that cache is absent. Wheel/pinch updates clamp only to the local 2–80 range; the stored distance is never reconciled with changed `CameraMinZoomDistance` / `CameraMaxZoomDistance`. The Scriptable branch at 7978 preserves the cache. On return to Custom the old radius can override the default camera's newly constrained radius on every update. Waiting longer does not resolve that state.

An independent temporary fixture executes the exact frozen guard with the existing contract's vector/camera mocks:

1. Initialize an unobstructed cached orbit of 30.1643219.
2. Enter Scriptable and verify the supplied pose and bypass remain untouched.
3. Set minimum and maximum zoom to 12, return to Custom, and present an actual default-camera pose 12 studs from the target.
4. Run the guard: it forces that pose back to 30.1643219.
5. Move the root 63 studs and run the same guard: the rebase preserves the incorrect 30.1643219 radius. Final bypass is correctly false.

All five diagnostic assertions pass, reproducing the observed defect without changing production. Agent 2 received the fixture. The narrow correction should reconcile the stored orbit with legitimate changed player zoom constraints before correcting Custom-camera poses, while preserving valid user orbit and unconditional Scriptable ownership. Resetting or relaxing the flow's distance gate would conceal the defect. Existing selected-orbit and wheel/pinch behavior must remain covered.

## 2. Fresh physical-margin overlap is sampled before a later repair can run

Evidence: `work/docs/evidence/smash-full-integrated-final-20260906/camera-long-tunnel-regression.json`.

| Measurement | Recorded result |
| --- | --- |
| Actual punches | 18 |
| Fresh 0.55-cube physical failures | **4 / 164 samples**, fails zero requirement |
| Separate 0.3-cube inside samples | 0 |
| Maximum normal correction / overlap escape | 2.4000015 / 2.6380787, within existing bounds |
| Historical clear / readable ratios | 0.597561 / 1, pass 0.55 / 0.65 |
| Settled clear / readable ratios | 1 / 1, pass 0.9 / 0.9 |
| Fresh final overlap / obscurers / avatar fading | 0 / 0 / 0 |
| Final orbit difference / follow handoff | 0.006594 / false |

The current sampler at frozen client line 8330 directly calls `PunchWallCameraPositionBlocked(camera.CFrame.Position, character)`. It does **not** replay `PunchCameraSafetyUnresolved`, nor combine it with LOS. That helper uses a 0.55-stud cube; the separate `inside` test uses a 0.3-stud cube, and the outer final check uses 0.4. Four overlaps of the larger safety box with zero smaller-box hits are consistent. They establish a failure of the existing safety-margin contract, not proof that the camera's center entered a block. The historical LOS threshold already passes and must not be lowered.

Frozen guard installation at lines 8231–8245 repairs geometry in RenderStep and, for newly overlapping geometry, Heartbeat. The timed sampler resumes from `task.wait`. Roblox documents separate resumption points for PostSimulation, waiting task scripts, and Heartbeat, and cautions that scheduling depends on SignalBehavior. This permits a waiting script to inspect newly moved physics before the Heartbeat repair. [Deferred engine events](https://create.roblox.com/docs/scripting/events/deferred), [task scheduler](https://create.roblox.com/docs/performance-optimization/microprofiler/task-scheduler).

An independent exact-guard fixture starts with a clear rendered pose, moves a controlled obstruction over it during physics, fires PostSimulation, samples, then fires Heartbeat. The current guard reports `blocked=true` at the intervening sample and `false` after Heartbeat; the repair remains within 2.65 studs. Three assertions reproduce the missing observation boundary. Existing tests call Heartbeat before checking safety, so they do not cover this order.

Agent 2 proposes moving immediate post-physics overlap repair to PostSimulation, retaining suspended-render fallback on Heartbeat. That is a source-supported candidate, not a confirmed closure of these four particular runtime samples. Preserve the actual 0.55 probe, zero-failure requirement, final physical/LOS publication checks, and correction/escape budgets. Do not move the oracle later merely to skip the failing interval.

## Diagnostic gap and required follow-up

The failure records only successful first/largest escapes and failures of the smaller 0.3 probe. It does not retain the four failing 0.55-query poses or parts. The final `lastGuardPhase=render` and age about 0.05 seconds describe the final state, not those earlier failures. Therefore the current evidence cannot distinguish rendered overlap, an intervening physics update, or another late world mutation for each failure.

Requested bounded evidence: first failing 0.55 sample with camera/root pose, overlapping part identities/CFrames/sizes/velocities, current guard phase/time and previous publication; then a paired observation after the relevant repair. Retain an actual render-boundary observation without replacing the existing timed/fresh gates. Keep storage capped and serializable.

The same run also reports `sampleMaxStep=99.7955`, from camera `(-2, 7.2142, -180.6383)` to `(-0.1467, 4.2947, -80.9028)`. The maximum measured inherited root step is 21.6252. Existing acceptance uses authored follow/correction/escape distances, not this absolute sample delta. With no paired root/phase for that maximum, a rendered hundred-stud snap is not established. Agent 2 was notified to retain enough bounded context to explain that measurement rather than dismiss it or treat the smaller authored counters as its explanation.

## Verification and handoff

- PASS: read-only `node work/automation/scripts/camera-geometry-guard-contract.mjs`: 138 assertions and nine expected mutation failures; complete client and both long-tunnel chunks compile.
- PASS: read-only `node work/automation/scripts/camera-shop-stability-contract.mjs`: 17 assertions.
- PASS: independent exact frozen guard counterexamples, five stale-orbit assertions and three scheduling assertions; both generated Luau fixtures compile. Temporary runner: `C:/Users/Jennarong Pinjai/AppData/Local/Temp/smash-camera-combined-review-generated.mjs`.
- Sources checked against frozen `6211b00`; official scheduler documentation read on 2026-09-06. Existing passing mocks do not override the failed actual combined run.
- Checklist complete: failures parsed against exact predicates; producer paths and executable counterexamples inspected; findings and minimal diagnostics sent to Agent 2 and Coordinator; document-only handoff.

Fresh actual runs of both unchanged camera contracts after source integration remain required. No new source fix, physical-device frame-rate claim, multiplayer result, final artifact verification, or release approval is made here.
