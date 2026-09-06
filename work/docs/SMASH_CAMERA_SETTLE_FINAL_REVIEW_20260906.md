# Camera settle review — 2026-09-06

Status: **two source-proven P2 defects; actual failed flow remains BLOCKED pending the source fix and Studio rerun.** This review changes no source, flow, timeout, or acceptance gate. The Coordinator owns Studio and integration; Agent 2 owns the next camera change.

## Reviewed revisions and runtime evidence

- Frozen full-suite source: `6211b0075df92b38e0b5c13f4824968909a06b10`.
- Held camera patch: `a5fea5d3b57dfa85393f8c4c8735ab5bf8c90004`.
- Held companion patch: `521711b5aa76e98b4faf9678fbb5afdda429d640`.
- Actual failed result: `work/docs/evidence/smash-full-integrated-final-20260906/punch-camera-smooth-follow.json` in the Coordinator's integration worktree.
- Production code: `work/punch-wall-rpg/src/client/PunchWallClient.client.lua`; automation: `work/automation/flows/punch-camera-smooth-follow.json`.

The actual run reports `settleTimedOut=true`, `handoffActive=true`, `geometryClamped=true`, and zero settled samples. Selected/configured radius is `12.474493980407715`; final radius is `12.500585556030274`, a difference of `0.026091575622558595`. Physical intersections and unresolved physical samples are zero; angle, distance, step, and no-snap gates pass. The one recorded physical escape is only `0.04417518153786659` studs. These measurements do **not** prove that the requested recovery destination, its bounded route, or the last target sightlines were clear.

`geometryClear` in this flow is derived from `inside == 0`. The 78 samples include nine transient LOS-obstructed samples (`clearRatio=0.8846153846153846`). The recorded `DepthBlock_L009_C07_R03` is a sampled obscurer, not proof of the final blocker. Neither the final requested/held position nor teleport-rebase count is returned. The evidence therefore cannot select uniquely between the two proven modes below. In particular, `maxInheritedRootStep` only covers eligible small inherited steps and cannot exclude a separate greater-than-30-stud rebase.

## P2 — recovery can repeatedly reject an obsolete cache without adopting a valid current pose

Frozen-source references: `resolveClearCameraPose` near line 7526, bounded limiter near line 7931, recovery near lines 8080–8154, and fallback near lines 8162–8219.

The guard first resolves a desired pose, reprojects recovery to the selected radius, and then approaches that destination from `lastClearCameraCFrame`. Direct, vertical, and combined-horizontal corrections must end at a physically and visually clear pose. If the old cache loses LOS and every bounded candidate also loses LOS, the limiter returns nil. The fallback rejects that cache; when the actual native camera is physically clear, it can leave the actual camera unchanged without adopting it as a new cache. This repeats even if the actual native pose is both physically and visually clear and already satisfies the flow's radius tolerance.

The internal `recoveringFromFollowHandoff` remains true in this mode. It affects subsequent camera correction; this is not just a test label. Completing handoff still requires an actual bounded candidate within `0.001` studs of the requested destination. Removing the handoff gate or treating a radius error below `0.08` as completion would hide this defect.

An executed controlled scene proves the mode in all three revisions:

1. Start with selected radius 12, root at zero, and cached camera `(0, 0, 12)`. Observe one active-follow update.
2. End follow. Change the mocked LOS sensor to `p.Z < 12.02 and abs(p.X) < 3`; physical queries remain clear. Feed a clear native camera `(0, 0, 12.026091575622558)` on each update.
3. Execute 81 updates of `0.05` seconds. Every actual published pose stays physically and visually clear, the radius error is below `0.08`, but both `GeometryClamped` and `HandoffActive` remain true. The invalid old cache remains at Z=12.
4. Remove the controlled LOS obstruction. The next update genuinely reaches the exact selected radius and clears handoff. Subsequent ordinary native frames remain released under the existing regular zoom policy.

This is a controlled query-response scene using the **exact production resolver and guard**, not a reconstruction of Roblox raycasts or the captured L009 block. The causal result is source-proven; attribution of this specific live failure still needs the diagnostic below.

Recommended bounded fix: when the previous recovery origin is unusable, freshly validate the already-published native camera against the same `.55` physical probe and both target sightlines. If it is a local, eligible recovery origin, adopt it and continue the existing bounded arrival process. Keep the physical sweep, rotation/focus preservation, publication/correction budget, and `0.001` arrival requirement. Merely changing the origin may expose a second routing limitation: direct/vertical/combined-horizontal steps can all cut back across a LOS edge. A small bounded tangent or separate-axis waypoint can be considered, but it must satisfy the same physical/LOS and publication checks. Do not teleport to a distant clear candidate or declare an unreachable destination complete.

## P2 — successful teleport rebase leaves the handoff marker stale

Frozen-source reference: successful rebase near lines 8035–8063, specifically the internal clear at line 8049.

For a root displacement greater than 30 studs, a successful validated rebase writes the new camera/cache and clears both internal recovery flags. It does not clear `PunchCameraHandoffActive`. Later ordinary clear frames do not clear that marker, because the internal handoff flag is already false. The automation then times out even though native control has actually been released.

The second executed scene enters handoff, removes its obstacle, moves the root to `(0, 0, 40)`, and supplies camera `(0, 0, 52)`. All three revisions report one successful rebase and an exact radius of 12, but retain the public handoff marker after another 4.05 seconds of clear frames. Geometry recovery is false by that point. This distinguishes a stale oracle from the first defect's real internal recovery.

Minimal correction: set `PunchCameraHandoffActive=false` in the successful rebase branch alongside the internal clear. A scratch-only variant containing precisely that synchronization passes the same rebase scene with the marker false, exact radius unchanged, and native control still released after 4.05 seconds. This does not change teleport eligibility, movement, smoothing, or test tolerance. The first no-progress defect needs its own correction.

## Held patches and validation

`a5fea5d` changes zoom-bound handling, publication diagnostics, and post-physics overlap timing. `521711b` changes companion identity and projected safe-frame handling. Neither changes the resolver's clearance search, the recovery limiter, exact arrival condition, fallback cache adoption, or missing handoff clear in successful rebase. Better physics timing may change which live scene occurs; it is not proof that either lifecycle defect is fixed.

Executed offline checks using Luau 0.737:

| Check | 6211b00 | a5fea5d | 521711b |
|---|---:|---:|---:|
| Exact resolver/guard no-progress reproduction and obstacle-removal control | 171 assertions | 171 assertions | 171 assertions |
| Exact guard stale-rebase reproduction | 6 assertions | 6 assertions | 6 assertions |
| Scratch-only rebase marker synchronization | 6 assertions | 6 assertions | 6 assertions |
| Generated exact-source chunks compile | pass | pass | pass |

The assertion counts include per-update physical/LOS observations. They are diagnosis and focused control results, **not Studio passes or a completed source fix**. Temporary generated Luau files were removed after execution. No root/source/flow/tool changes or Studio calls were made for this review.

## Reproduction fixture for the camera contract

Use the frozen `camera-geometry-guard-contract.mjs` mock types, with the exact production resolver instead of its `resolver` stub. Supply `RunService.PostSimulation`, `RunService:IsStudio()` returning false, unary Vector3 negation, CFrame.RightVector, and root CFrame/IsA in the mock. Extract these exact production boundaries with `git show <revision>:work/punch-wall-rpg/src/client/PunchWallClient.client.lua`:

- `local function resolveClearCameraPose(desiredCFrame` through the boundary immediately before `local lastPunchCameraRenderAt`.
- `shared.PunchWallInstallCameraGeometryGuard = function()` through the boundary immediately before the Studio-only `shared.PunchWallRunCameraAutomation` block.

Append this fixture after the extracted resolver and guard:

```lua
local update = bound.PunchWallCameraGeometryGuard
lastPunchActionAt = 0
pose(0, 0, 12) update(1/60)
check(math.abs(attrs.PunchCameraUserOrbitDistance - 12) < .001, "selected_radius")
attrs.PunchCameraFollowActive = true update(1/60)
occluded = function(p) return p.Z < 12.02 and math.abs(p.X) < 3 end
attrs.PunchCameraFollowActive = false
for _ = 1, 81 do
    now += .05 pose(0, 0, 12.026091575622558) update(.05)
    check(not blocked(camera.CFrame.Position), "actual_physical_clear")
    check(not occluded(camera.CFrame.Position), "actual_LOS_clear")
end
check(attrs.PunchCameraGeometryClamped == true, "fallback_repeats")
check(attrs.PunchCameraHandoffActive == true, "recovery_still_active")
check(math.abs(camera.CFrame.Position.Magnitude - 12) < .08, "radius_already_passes")
check(shared.PunchWallHeartbeatLastClearCFrame.Position.Z == 12, "old_cache_retained")
check(shared.PunchWallResolveClearCameraPose(camera.CFrame, camera.Focus, character) ~= nil,
    "exact_resolver_accepts_current_native_pose")
occluded = function() return false end
now += .05 pose(0, 0, 12.026091575622558) update(.05)
check(attrs.PunchCameraHandoffActive == false, "obstacle_removal_releases")
check(math.abs(camera.CFrame.Position.Magnitude - 12) < .001, "actual_exact_arrival")
for _ = 1, 80 do now += .05 pose(0, 0, 12.026091575622558) update(.05) end
check(attrs.PunchCameraHandoffActive == false
    and math.abs(camera.CFrame.Position.Magnitude - 12) < .08, "native_stays_released")
print("PASS " .. count)
```

For the rebase scene, perform only one obstructed update, remove the obstruction, set `rootPart.Position=Vector3.new(0,0,40)`, and call `pose(0,0,52) update(.05)`. Assert `TeleportRebaseCount==1`, exact radius12, and the stale marker true; repeat 81 clear updates and assert the marker remains true while `GeometryClamped=false`. The fix control requires the marker false at both points. Agent 2 also received the executable scratch runner during handoff; promotion into a durable source contract belongs to its source-fix scope.

## Required live diagnosis and acceptance

Capture a bounded Studio-only record when handoff enters, changes recovery branch, or times out: raw/current published CFrame, previous cache, root and inherited displacement, selected radius, resolved requested position, chosen limiter origin/step, resolver/limiter/fallback reason, fresh physical and both LOS results, actual internal geometry/handoff flags, public follow/handoff flags, and teleport-rebase count. Preserve existing evidence. The missing count and internal flags are essential for identifying which demonstrated mode occurred; the historical obscurer name alone is insufficient.

Keep the original four-second settle deadline, exact source arrival, physical/LOS/readability ratios, selected distance, rotation, native Custom ownership, and correction/publication/escape limits. Source controls must reject adoption of a physically blocked or LOS-blocked native pose, travel across a thin physical blocker, false completion at an unreachable destination, stale character/cache reuse, and theft of Scriptable ownership. Test ordinary movement separately from successful teleport rebases.

After integration, rerun the unchanged `punch-camera-smooth-follow` flow and applicable long-tunnel, physical-overlap, orbit, and camera lifecycle contracts. The Coordinator's combined frozen regression and rebuilt/reopened artifact verification remain required. No actual rerun, artifact build, or release pass is claimed here.
