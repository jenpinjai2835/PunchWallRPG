# Independent camera review, 2026-09-06

Agent 1 reviewed `af415b0220014b6da73be40a058f645536ab987d` in the isolated `codex/review/smash-camera-final-20260906` worktree. This assignment permits this document only; no source, automation, Studio, HQ, registry or output artifact was changed. The Coordinator owns integration and actual runtime verification.

Reviewed camera source is the source-only `2308a979aa8ee0db849a163473603f120444f7a3` change integrated as `f6202ce7c2da48de6a943ddcd8fa53aeaa2643b4`. The complete client SHA-256 after LF normalization is `c130d9acf6837337dd1584bb40d06a75e38ab663aa965acfd91a9021d06e5cbe`. It is identical in the review worktree and Agent 2's immutable `08c873989bad621bd43cae41ec6dfc1ed050aa40` test handoff in `F:/Roblox/PuchWall-camera-runtime2-20260906`.

Verdict: **BLOCKED for combined camera acceptance.** Existing offline tests pass, but the latest actual long-tunnel run fails the unchanged safety/smoothness gates. Two focused counterexamples identify missing guard cases. This is not a full game or release approval.

## Findings

### P2: a new Scriptable owner can be overwritten during active punch follow

At reviewed client line 7761, `updateCameraGeometryGuard` bypasses Scriptable only when `not activePunchCamera`. A different camera owner can select Scriptable after the punch follow callback but before the geometry callback, leaving the punch state truthy until the next follower observation. In that interval the geometry callback changes the new owner's position and focus, even with entirely clear geometry.

The existing inactive-Scriptable and follower-first cases do not exercise this order. An additional fixture executing the exact production guard with the existing Luau mocks reproduces it:

```lua
seed()
activePunchCamera = {}
attrs.PunchCameraFollowActive = true
camera.CameraType = Enum.CameraType.Scriptable
pose(10, 3, 0)
local ownedPosition = camera.CFrame.Position
local ownedFocus = camera.Focus.Position
update(1 / 60)
check((camera.CFrame.Position - ownedPosition).Magnitude < 0.00001,
    "active_punch_guard_must_preserve_new_scriptable_position")
check((camera.Focus.Position - ownedFocus).Magnitude < 0.00001,
    "active_punch_guard_must_preserve_new_scriptable_focus")
check(attrs.PunchCameraScriptableBypass == true,
    "active_punch_scriptable_owner_must_bypass")
```

Observed current-source result: position changes from `(10,3,0)` to approximately `(0.3831305,0.1149392,0)`, bypass is false, and the first assertion fails. Removing only `and not activePunchCamera` from the extracted geometry-guard bypass makes all three controls pass. The follower already releases active state on seeing Scriptable, so the geometry guard should respect the new owner immediately.

Follow-up: the Coordinator's pending integration source now has an unconditional Scriptable bypass. The same three controls were rerun against that actual file and passed, together with complete-client and two flow-chunk compilation. This is a read-only follow-up on pending source, not a claim that the immutable reviewed commit contains the fix. Agent 2 received the exact fixture for durable coverage.

### P2: the egress search can skip a safe exit inside the accepted movement budget

At reviewed client lines 7690–7699, candidate distances jump from `2.4` directly to `3.6`. The runtime gate allows at most `2.65`. The search can therefore choose an excessive emergency correction without testing a feasible shorter exit within the accepted budget. Its finite world-axis directions also omit actual rotated blocking-part face normals.

An independent production-guard control demonstrates the distance gap without changing the implementation:

```lua
blocked = function(p) return p.Magnitude < 2.5 end
resolver = function() return nil, nil, nil, nil end
pose(0, 0, 0)
check(not blocked(Vector3.new(2.6, 0, 0)), "smooth_budget_has_physical_exit")
update(1 / 60)
check(not blocked(camera.CFrame.Position), "chosen_exit_physically_clear")
check(camera.CFrame.Position.Magnitude <= 2.65,
    "available_smooth_exit_must_precede_long_escape")
```

The known `2.6` candidate is physically clear and has clear mocked LOS, but the exact guard selects `3.6` and fails the final assertion. This controlled volume proves search incompleteness; it does **not** establish the minimum exit for the particular moving block in Studio.

The smallest principled fix should test actual nearby blocker geometry and the complete small correction budget before taking a longer exit. Keep the original sweep requirement: leave the initial occupied region once, reject later re-entry, and validate final physical occupancy and both character LOS targets. A longer escape must continue to fail the smoothness gate. Agent 2 is deriving rotated-box face candidates and owns the implementation; no source changes were made here.

## Actual runtime evidence and its limits

Evidence: `work/docs/evidence/smash-camera-hud-targeted3-20260906/camera-long-tunnel-regression.json` in the Coordinator's integration worktree. The run performs 18 actual punch actions and reports:

| Measurement | Actual result |
| --- | --- |
| Physical inside samples | 0 |
| Maximum normal follow / correction | 2.4000006 / 2.3999996 |
| Maximum overlap escape | **3.6**, fails the 2.65 gate |
| Unresolved safety samples | **25 / 164**, fails the zero gate |
| Selected / configured / cached orbit | 12.474494, mutually consistent |
| Final orbit distance / difference | 12.467900 / 0.006594, passes 0.08 |
| Follow handoff / settle timeout | false / false |
| Historical clear / readable ratios | 0.798780 / 1 |
| Settled clear / readable ratios | 1 / 1 across 11 settled samples |
| Fresh projection / LOS / physical overlap | visible and readable / clear / 0 |
| Zoom and fixture cleanup | restored |

The `0.798780` clear ratio already exceeds the unchanged `0.55` historical threshold. `visualValid` is false because it incorporates the failing overall validity result. Do not misreport historical clarity as a separate failed threshold or relax the safety gates to make this run pass.

`PunchCameraSafetyUnresolved` is set from `cameraPoseBlocked`, which combines physical overlap **or** opaque LOS to either head or upper-root target. It does not mean the camera remained inside a part. The existing inside counter is a separate, fresh query. Also, the guard uses a 0.55-stud box while the automation's inside query uses a 0.3-stud box; a guard overlap can precede a zero smaller-box sample.

The larger-than-2.4 escape is possible only in the fallback path beginning at reviewed line 7954 after the **current** camera position is confirmed physically blocked. The cached-origin limiter caps its own escape search at 2.4. Thus 3.6 records an actual overlap at a guard call, not merely a stale cached position. The evidence does not identify whether that call ran immediately before rendering or in Heartbeat after physics.

The callback at camera priority +2 updates before rendering. Heartbeat also invokes it after a newly overlapping Custom camera even when rendering is fresh. The automation samples with `task.wait` and counts the last stored unresolved attribute. It can therefore observe physics state or a previous guard result between render callbacks. The current evidence is insufficient to attribute all 25 samples to an actually rendered unresolved pose; it is equally insufficient to dismiss them as harmless timing.

Minimal additional runtime observation requested from the Coordinator, while retaining all original gates:

1. Record a bounded sample immediately after the geometry guard at camera priority +3 and a distinct post-physics observation.
2. Include current camera/target positions, sample phase, render age, current 0.55/0.3 occupancy, both LOS results, and the stored unresolved flag.
3. For actual blockers, record name, CFrame, Size, CanQuery, CanCollide and Transparency. Record each escape origin, distance and callback phase, allowing reconstruction of a shorter valid exit.
4. Keep fresh render validation and current timer/physics diagnostics separate. Do not reduce any existing gate or remove opaque blockers to manufacture a pass.

The sampled obscurer list contains an actual `Mystery Pet Egg` and intact/transient `DepthBlock` instances. At this reviewed source, the main egg explicitly has `CanQuery = true` (server line 7445 at the camera handoff source); only its glow and spots have it false. No client egg-specific query mutation was found. Consequently, a CanQuery-false main egg is not established by this evidence. Roblox documents that CanQuery-false parts are excluded from raycasts ([official raycasting documentation](https://create.roblox.com/docs/workspace/raycasting)); actual per-part runtime flags are needed before alleging a query mismatch.

If a required target point is itself enclosed by an opaque object, zero obstruction from every external camera pose may be geometrically impossible for that instant. The current artifact has no blocker transforms or target containment observations, so that explanation remains unproved and is not a waiver.

## Completed checks

All commands below ran read-only against the immutable Agent 2 handoff, using official Luau 0.737. Generated temporary fixtures were outside the repository.

| Check | Result |
| --- | --- |
| `node work/automation/scripts/camera-geometry-guard-contract.mjs` | PASS: 94 exact-production and 11 actual flow-acceptance assertions |
| `node work/automation/scripts/camera-shop-stability-contract.mjs` | PASS: 6 camera, 4 Depth eligibility and 7 boost expiry assertions |
| `camera-geometry-guard-contract.mjs --baseline-runtime2 781ff4b` | PASS: four expected old-source failures reproduced |
| Complete client + both long-tunnel chunks | PASS: compile via the geometry contract |
| New Scriptable interleaving control | Expected FAIL on reviewed source; three assertions PASS with minimal extracted fix and pending integration source |
| New bounded-egress search control | Expected FAIL on reviewed source; clear 2.6 candidate skipped in favor of 3.6 |

The two new review fixtures are provided verbatim above and use the existing contract's `guardSetup` mocks. Local runners are `%TEMP%/smash-camera-final-scriptable-review.mjs` and `%TEMP%/smash-camera-final-coarse-egress-review.mjs`; `--proposed-guard` on the first changes only the extracted bypass for the counterfactual. Neither runner edits product source. Their expected failures are findings, not passing acceptance checks.

Reviewed fallback checks correctly revalidate both physical occupancy and LOS before publishing a cache, and the controlled tests cover no-history recovery, fresh-Heartbeat overlap, initial-overlap exit followed by another obstruction, respawn cleanup, low-FPS root carry, and selected-radius setup/restoration. No additional actionable defect was established in those paths. Query/search cost under simultaneous real physics and mobile frame budgets remains unprofiled.

Checklist: source and evidence review complete; applicable offline checks and independent negative controls complete; document-only handoff prepared. Required combined camera runtime remains BLOCKED pending the Coordinator's fix and rerun. Real device performance, actual two-player sessions, production publishing, live purchases and persistence are not established by this camera review.
