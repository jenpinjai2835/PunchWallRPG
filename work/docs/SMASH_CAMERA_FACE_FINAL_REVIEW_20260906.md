# Independent oriented camera egress review, 2026-09-06

Agent 1 reviewed exact source commit `124d9cab10dacba22badb8e6395162dea2d9c36b`, integrated by the Coordinator as `869f185`. Source was read from `F:/Roblox/PuchWall-camera-face-egress-20260906` and verified byte-equivalent to that commit after LF normalization. Only this document is authored, in the clean `codex/review/smash-inventory-art-final-20260906` worktree after `60f0bc6`. No source, tests, Studio, HQ or other files were changed.

No new actionable P1/P2 defect was established in this source review. The earlier Scriptable interleaving and skipped-small-exit counterexamples now pass. Acceptance remains qualified and **BLOCKED pending the Coordinator's actual combined camera run**: the earlier 3.6-stud runtime escape is not closed by offline proof alone.

Reviewed complete-client SHA-256, LF-normalized UTF-8: `dbd724ff48d9ee77e6d3bde8115a5223316818566d87f093d440de8e210eb67f` (608,751 bytes).

## Geometry and publication

The face distance uses the actual blocking part's oriented axes and half extent. For each face normal `n`, the 0.55-stud world-axis camera box contributes support `0.275 * (abs(n.X) + abs(n.Y) + abs(n.Z))`. Subtracting the origin's projection onto that normal, then adding 0.01 clearance, moves the camera box beyond that part's face. Both signs of all three axes are considered, so the LookVector sign convention does not change coverage.

The independently implemented test oracle checks 15 separating axes between each oriented block and the camera box; it does not reuse the production distance formula. The rotated four-stud fixture exits around 2.47 rather than the old 3.6, while the independent oracle verifies actual camera-box separation. The 2.5-radius control now chooses an available exit within 2.65, proving the former 2.4-to-3.6 search gap is addressed.

Every proposed endpoint is queried against the whole scene, not only the part used to generate it. The path retains the existing sampled sweep: an initially occupied segment may be left once, after which any occupied sample rejects re-entry. The differently positioned two-block fixture independently checks both final overlaps. This does not prove a mathematically shortest path or complete solution for every arbitrary compound collider. Candidate generation remains a finite face/grid search, and the sweep remains sampled rather than a continuous swept-volume proof.

Both cached-origin and current-camera overlap paths call the same egress helper. Cached-origin escape uses the 2.65 emergency budget; ordinary correction remains `24 * min(deltaTime, 0.1)`, at most 2.4. Root transport remains separately measured and swept, so movement does not silently consume the correction budget. The final publication path rechecks actual physical occupancy, including after a candidate was selected. No-history recovery uses the current camera and cannot publish an unchecked old cache.

Every accepted egress helper result records its actual `step.Magnitude`, count and source, including cached-origin escape. A larger enclosing object can still require a longer emergency exit; its measured distance is exposed and the runtime gate still rejects anything above 2.65. There is no exemption for face-generated, cached or emergency corrections. Tests retain an oversized enclosing object which must be safe physically but fail the smoothness criterion through its reported distance.

## Physical safety and visibility are explicitly separate

The new physical/LOS distinction is an intentional behavior and diagnostic change. `PunchCameraSafetyUnresolved` now represents physical camera overlap; `PunchCameraLineOfSightUnresolved` represents opaque character-ray obstruction. A physically clear exit may be published when every small safe candidate has blocked LOS. It is not called fully visible. Normal correction and ordinary cache fallback still require both physical clearance and LOS. The egress exception permits leaving a block without taking a larger jump solely to avoid a transient opaque ray.

The automation now samples the actual current 0.55-stud physical query instead of replaying the last stored guard flag. That removes the old conflation of stale LOS state with current physical penetration. It also reports actual historical obstruction separately using `GetPartsObscuringTarget`. This review does not claim zero transient occlusion or that every task-wait sample corresponds to a rendered frame.

The reviewed updated flow keeps all original visibility and fresh-scene requirements explicit:

- Historical clear ratio at least 0.55 and readable ratio at least 0.65.
- Settled clear and readable ratios at least 0.9.
- Fresh character visible/readable with no opaque obstruction, no overlap or avatar fading; Custom camera, no remaining follow/handoff, restored zoom.
- Physical unresolved samples equal zero, sampled inside count zero, actual escape and correction maxima at most 2.65.
- Eighteen actions, selected/configured/cached radius agreement within 0.001, and final radius within 0.08.

Executed flow controls reject historical clarity 0.54, settled clarity/readability 0.89, historical readability 0.64, physical unresolved samples, excessive escape, wrong radius, fading, fresh obstruction and fresh overlap. They accept measured transient obstruction only when the original historical/settled/fresh requirements still pass. No obstacle is removed from the visibility query to make the new behavior pass.

The unconditional Scriptable bypass remains before geometry mutation. Three controls reproduce the previously missing callback interleaving: a new Scriptable owner arrives while active punch state remains truthy; its position, focus and ownership marker are preserved immediately.

## Bounded work and diagnostics

The overlap collector preserves the existing 32-result query cap and returns only collidable, sufficiently opaque BaseParts. Boolean-only callers keep their earlier interface. Five executed collection controls cover relevant/irrelevant parts and filter/cap behavior.

With at most 32 blockers, the small search has at most 192 face candidates plus 168 grid candidates per helper invocation. The 80-stud emergency cap permits at most 612 total candidates. Each is endpoint-checked, and eligible paths are sampled at no more than 0.25-stud intervals. These are finite work bounds, not measured frame-time guarantees; several attempts can occur within one guard update. Crowded moving geometry and temporary obstruction still need actual runtime/performance observation.

Diagnostic retained storage is constant: first and maximum escape only, with no more than two serialized blocker records each. They contain callback phase, cached/current origin kind, actual pose/step/distance, blocker size/CFrame/velocity and LOS rejections. They contain no cross-VM Instance or executable state. Reset and new automation runs clear the retained samples. Post-physics and render callbacks are distinguished; actual elapsed guard age is reported.

## Verification run

Executed read-only in Agent 2's worktree with official Luau 0.737. Agent 2 still owned its dirty test/flow files during this review; the exact snapshot hashes below identify what was executed.

| Check | Result |
| --- | --- |
| `node work/automation/scripts/camera-geometry-guard-contract.mjs` | PASS: 138 assertions, including 17 flow-acceptance controls, oriented/compound geometry, coarse-gap, fresh-sample, overlap-collection and three Scriptable controls |
| `node work/automation/scripts/camera-shop-stability-contract.mjs` | PASS: 17 camera/Depth/boost assertions |
| `camera-geometry-guard-contract.mjs --baseline-face 4d23e28` | PASS: four expected old-source failures reproduced—rotated exit, physical/LOS conflation, coarse gap, stale physical sample |
| Full client and both actual long-tunnel payloads | PASS: Luau compilation through the geometry contract |

Executed snapshot SHA-256 after LF normalization:

- `camera-geometry-guard-contract.mjs`: `f0437160a69bf910489fa99254d7b478c444d36d3e72f4eb5166de643cfc12e5`.
- `camera-long-tunnel-regression.json`: `6b4bbaed268d04fcfcfc4e161aa1061accebcf381c80a689b822f48ffeab95bd`.

Checklist complete: exact-source review; independent oracle/behavior/gate verification; document-only handoff. The Coordinator's fresh Studio camera evidence, mobile frame pacing and combined regression remain required. Previous targeted3 failure metrics are historical and must not be presented as either a pass or a current failure of this new source until rerun.
