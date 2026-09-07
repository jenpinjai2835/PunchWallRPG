# Narrow companion framing peer review — 2026-09-06

Agent 1; source and tests are read-only. Reviewed source commit `052f8c6794fb682ed744927630cb7d48165fcba8`, client normalized SHA256 `629aa65f9f269acfaeb0362b2940d25700724b8aabb4a2adc61760141a6de361`, and immutable test/flow/document commit `a0b011e0dbbef1db6fa18c8b64dad8848d6dab13`. Only this review document changes. Coordinator owns Studio, integration, and runtime acceptance.

## Conclusion

No additional actionable P1/P2 defect was established within the stated bounded sequential-layout contract. Accepted placements passed independent full-box, screen separation, world separation, orientation and depth checks. This is a qualified source review, not proof of universal packing, current-device runtime success, or measured performance improvement. The updated actual flow remains required.

## Source reasoning

`ProjectedBoundsRect` (`PunchWallClient.client.lua:5319`) projects all eight corners and rejects a box crossing the hardware near plane. `KeepBoundsInSafeFrame` (`:5334`) retains the previously reviewed calibration against three actual WorldToViewportPoint projections. The same per-corner depths determine the exact safe-frame translation intervals, retaining the original one-percent inset plus half-pixel reserve. Translation uses only camera RightVector/UpVector, so accepted placement preserves world size, model orientation and camera-plane depth.

Each blocker contributes four possible separating interval regions with a two-pixel screen gap. The world-distance test computes the remaining required camera-plane separation after the existing depth difference and conservatively requires it along the selected separating axis. Thus every accepted pair retains at least 1.45 studs; the approximation can exclude otherwise feasible diagonal placements. Branch pruning uses the squared distance of the closest point in the current interval rectangle as a lower bound. Descendant intersections only restrict that rectangle, so pruning when this bound cannot improve the best solution is valid. The result is nearest within the enumerated conservative regions, not necessarily nearest among every geometrically possible layout.

GameConfig permits three equipped pets. The caller supplies the avatar plus earlier pet slots, producing at most three blockers at the final solve: 64 leaf regions, at most 85 recursive visits before pruning. Appending the third pet's rectangle occurs after its solve. Slot order is retained. The patch does not change token/model identity, imported-asset sanitization, visual construction, stats authority, or economy.

The due-update scan (`:9447`) avoids querying avatar bounds on intervening LOD frames. The native animated-character bounding box is read once per actual update (`:9459`); its returned CFrame is used each time, and the eight-corner array is refreshed when size changes. Reusing equal-size corners across a new pose or character is valid because these are local offsets, not world positions. The model API returns orientation and size together; projection uses the current camera. [Model bounds API](https://create.roblox.com/docs/reference/engine/classes/Model#GetBoundingBox), [Camera projection API](https://create.roblox.com/docs/reference/engine/classes/Camera#WorldToViewportPoint).

Earlier-slot rectangles and world centers are appended after their publication (`:9541`). Pet bounds/corner arrays stay cached; the new code does allocate bounded projected-corner/interval/rectangle tables. With all three pets updating and all boxes projectable, it adds 32 corner projections (eight avatar, eight per pet) beyond the existing 33 calibration/corner projections, plus one avatar GetBoundingBox. This is a bounded cost description, not a measured CPU budget. No new descendant scan or per-frame geometry rebuild appears in this patch.

## Independent executed checks

A temporary harness extracted the exact helpers from `git show 052f8c6`, with independently implemented three-axis CFrame transforms and perspective projection. It executed **5,182 assertions across 648 sequential slot attempts**: 578 accepted placements and 70 unchanged/false no-fit placements. The matrix uses 637×654, 874×402 and 402×874 viewports; FOV 55/70/90; distances 6/12/18; cropped projection height; rotated cameras; and eight animated/growing avatar phases.

Every accepted pose retained all eight corners inside the original inset and near plane, at least a two-pixel gap from every supplied blocker, at least 1.45 world separation from earlier slots, unchanged three-axis orientation and depth, and an accurate translation magnitude. Rejected poses remained identical to the input with zero reported shift. Additional controls cover missing camera, hardware-near-plane rejection, and an entirely blocked viewport.

The harness is `C:/Users/Jennarong Pinjai/AppData/Local/Temp/smash-pet-narrow-independent.luau`, SHA256 `e2aebb7ca9706f82cfbd2724ef9ad1adb011beb60d758e948238f59a6dc6ce9b`. It compiles and executes using official Luau 0.737. No Studio interaction or repository test modification occurred.

The immutable author's contract independently passes **3,155 assertions and 22 rejected compiling mutations**, including all prior 491 assertions, actual separation-payload negatives, and avatar query/cache wiring. `--narrow-baseline 39d3c40` reproduces the intended pre-fix avatar-overlap failure. Full client compilation at O0/O1/O2 passes; updated runtime and cleanup payloads compile.

## Explicit limits for acceptance

A finite counterexample demonstrates the intentional conservative boundary: camera 400×400, vertical FOV 70, box size 1.8×1.1×0.45 centered at camera-space depth three, with an identical earlier-pet blocker at that center. The helper returns unchanged/false. A separate translation of (0.76, 1.24) in the camera plane nevertheless fits the original inset, clears the blocker by two pixels, and gives center distance 1.4543727. Therefore an empty conservative region must not be described as globally impossible. This does not alter the reviewed acceptance decision or authorize widening the algorithm.

On failure, the caller publishes the pre-constraint smoothed/requested pose unchanged and exposes false fit state. It does not restore a stored last-safe pose, shrink geometry, change depth, move the camera, or guarantee non-overlap. The runtime flow's independent actual overlap and safe-frame gates remain authoritative; a helper flag cannot substitute for those measurements.

If an avatar box crosses the near plane, ProjectedBoundsRect returns nil and the caller omits that blocker. This is not a proof of avatar clearance in arbitrary first-person/near-plane arrangements. Likewise the avatar rectangle is current at its Heartbeat query, not a bound over all future Animator poses; a two-pixel margin is not a temporal motion envelope. Actual updated 20-pose bob-window runs at the specified camera distances/custom viewports must verify the rendered result. No runtime evidence for a newly failing required case was established by this review.

Checklist: immutable source/test review complete; independent exact-helper positive/negative checks complete; compile and focused contract checks complete; qualified handoff ready. Actual Studio and final artifact/device acceptance remain pending Coordinator verification.
