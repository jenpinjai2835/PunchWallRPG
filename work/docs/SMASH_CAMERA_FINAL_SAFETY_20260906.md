# Camera zoom bounds and post-physics safety

Agent 2, 2026-09-06. Isolated branch `codex/fix/smash-camera-final-safety-20260906`, base `6211b00`; immutable source-only handoff `a5fea5d3b57dfa85393f8c4c8735ab5bf8c90004`. The Coordinator owns Studio and integration after the frozen full regression finishes. This change touches the main client, the geometry contract, and this document. Existing player-visible camera flows retain their original assertions; the camera/shop contract was run unchanged.

Two failures in `work/docs/evidence/smash-full-integrated-final-20260906/` were traced to different causes:

1. `camera-teleport-scriptable-visibility.json`: the Scriptable phase passed with `scriptValid=true` and zero pose error. Final `bypass=false` was correct after returning to Custom. The failed predicate was camera distance below 20 studs: baseline and post-teleport distance were both 30.1643219 despite new minimum and maximum zoom bounds of 12. The geometry guard retained a previously selected orbit and restored that stale radius after the engine moved the camera to its new bound.
2. `camera-long-tunnel-regression.json`: four direct physical safety samples overlapped the 0.55-stud camera box. The separate 0.3-stud inside counter remained zero, so these values do not contradict each other. Maximum egress was 2.63808, sampled clear ratio 0.59756, and settled/fresh/readability/zoom gates passed. The existing overlap repair ran on Heartbeat; waiting tasks can resume before its callback. The original four failing safety samples did not retain their blocker poses, so the exact runtime events cannot be reconstructed from that evidence alone.

The guard now clamps the preserved orbit against current player minimum/maximum zoom bounds within the existing 2–80-stud supported range. This applies when initializing the orbit, consuming mouse-wheel/pinch input, and returning to Custom with an existing orbit. Scriptable ownership still returns before any camera correction. Widening the bounds preserves the current choice instead of restoring the discarded old radius.

Fresh physical overlap repair now runs on PostSimulation; its callback invokes the guard only when the same 0.55-stud box is actually blocked. Heartbeat retains the existing suspended-render fallback. A clear post-physics scene does not advance ordinary camera following, and a fresh Heartbeat does not repeat the physics correction. Roblox documents PostSimulation before deferred waiting-task resumption and Heartbeat in [Workspace.SignalBehavior](https://create.roblox.com/docs/reference/engine/classes/Workspace#SignalBehavior); its [task scheduler guidance](https://create.roblox.com/docs/performance-optimization/microprofiler/task-scheduler) recommends PostSimulation for reactions to physics. The source-executing control models that documented order; it is not a measurement of the failed Studio run's event sequence.

The original per-response 2.4-stud correction budget, 2.65-stud actual escape gate, zero physical overlaps, selected zoom, Scriptable ownership, sampled/settled visibility and readability, and fresh no-fading checks remain unchanged. A physically impossible small egress still records its actual exceptional distance and fails the existing gate. No new cumulative acceptance budget or weaker physical predicate was introduced.

Diagnostics are bounded and separate from those acceptance gates:

- Up to four unresolved 0.55-stud samples retain camera/root position, punch, task-resume phase, guard/render age, previous guard outcome, overlap count, and at most two actual blocker names/sizes/CFrames/velocities. The physical failure counter continues beyond the diagnostic storage cap.
- The maximum sampled camera step now retains both root positions, guard phase/age and last guard publication. This is needed for the old 99.7955-stud sampled step: previous evidence lacked enough timing/root information to identify a rendered snap or its owner, and this review does not dismiss that observation.
- Actual guard-published travel, escape travel and write counts accumulate between render callbacks; suspended rendering starts a new cycle after each physics step. Last/max publication records include incoming and published positions, root, phase and reason (orbit/follow, clear fallback, overlap escape or teleport rebase). These totals expose multiple writes without rebranding ordinary root movement as corrective motion. They are diagnostics, not FPS or new smoothness thresholds. Detailed publication records allocate only in Studio; published-game collision behavior remains active.

Local validation:

| Check | Result |
| --- | --- |
| `node work/automation/scripts/camera-geometry-guard-contract.mjs` | PASS: 166 executed production assertions and 15 semantic mutations rejected |
| `--baseline-final 6211b00` | PASS: old source reproduces stale orbit after the 12-stud bound and overlap visible before the waiting-script boundary |
| Historical `--baseline-face 4d23e28`, `--baseline-runtime2 781ff4b`, `--baseline-los ef9b5f8`, `--baseline b521dea` | PASS: all 21 earlier expected failures remain reproducible |
| `node work/automation/scripts/camera-shop-stability-contract.mjs` | PASS: all 17 existing camera, Depth eligibility and Boost identity checks |
| Luau 0.737 full client | PASS at O0/O1/O2; actual long-tunnel payloads also compile |
| `git diff --check` | PASS |

The new geometry control replays the recorded L038_C07_R03 block position, rotation and 4×4×4 size from the failed run using the independent 15-axis box-overlap oracle. Physics introduces that overlap after a clear camera sample; the old guard remains blocked until Heartbeat, while the new guard resolves it within 2.65 before waiting-task sampling. This recorded block was the largest successful escape, not one of the four previously uncaptured unresolved samples. The controls also prove no second fresh Heartbeat correction, no ordinary follow on clear PostSimulation, preserved Scriptable pose/focus through all guard phases, current mouse/pinch limits, unchanged radius when bounds widen, bounded diagnostic storage and exact cumulative publication distance.

The actual affected camera rerun and subsequent combined regression are **BLOCKED pending Coordinator integration and Studio verification after the frozen suite**. Neither the scheduling control nor the geometric replay proves that all four original runtime samples are resolved. The new diagnostic fields make a repeated failure actionable without loosening any required gate. No runtime, rendered-smoothness, or FPS pass is claimed here.
