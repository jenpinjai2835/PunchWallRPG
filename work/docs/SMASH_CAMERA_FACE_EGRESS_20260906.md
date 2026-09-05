# Camera face egress and physical/LOS attribution

Agent 2 scope, 2026-09-06. Isolated branch `codex/fix/smash-camera-face-egress-20260906`, base `4d23e28`. Source-only handoff `124d9cab10dacba22badb8e6395162dea2d9c36b` is immutable while the Coordinator runs Studio. This worker did not use Studio or change other owned paths.

Actual preceding runtime evidence: `work/docs/evidence/smash-camera-hud-targeted3-20260906/camera-long-tunnel-regression.json`. Camera inside samples were zero, selected orbit delta was 0.00659, handoff finished, and fresh visibility/opacity/zoom checks passed. The remaining failure had maximum escape 3.6 and 25 combined safety/LOS flags; sampled clear ratio was 0.79878 and settled clear ratio was 1.

The former search tried 2.4 then 3.6 studs. For a single 4×4×4 block rotated 60 degrees about `(1,1,1)`, an independent separating-axis oracle shows all 26 direction probes at 2.4 still overlap the 0.55 camera box. A face-normal exit at 2.46833, including a 0.01 margin, is clear. The source now collects the actual collidable overlaps and adds their six oriented-face exits. Each face accounts for the camera box support `0.275 × (abs(nx)+abs(ny)+abs(nz))`; candidates are sorted by distance and checked against all overlapping geometry and the swept exit path. This handles an adjacent block obstructing one face instead of accepting that face in isolation.

Ordinary movement retains its 2.4-stud maximum correction. Overlap recovery uses the existing 2.65-stud safety ceiling, with a 2.64 fallback probe to avoid the former discrete gap. An unusually large or compound enclosure can still require a longer emergency correction. The actual selected step remains visible in the maximum-distance counter and fails the existing runtime bound; tests explicitly reject a mutation that masks that distance.

The previous `unresolvedSafetyFrames=0` gate unintentionally counted `cameraPoseBlocked`, which combines physical overlap with rays to the avatar. That imposed zero transient LOS failures in addition to the existing sampled and settled visibility ratios. A queryable, non-collidable Mystery Pet Egg can block a ray without containing the camera. FallingStructural blocks are also non-collidable with player characters and may temporarily intersect the avatar, preventing clear head/body rays from any camera position. Chasing that temporary obstruction with a larger camera jump cannot guarantee readability.

This patch explicitly corrects that overconstraint. The sampler checks fresh physical occupancy rather than replaying a previous guard flag. `physicalUnresolvedFrames` and the compatibility alias `unresolvedSafetyFrames` both count physical overlap; `transientLineOfSightFrames` records actual sampled opaque obscurers separately. A bounded, physically clear egress may be used when all nearby LOS candidates are temporarily blocked; LOS recovery continues through the normal bounded guard. This exception is diagnosed and does not silently disappear from the visibility measurements.

The flow retains sampled clear ratio ≥0.55, settled clear ratio ≥0.9, sampled readability ≥0.65, settled readability ≥0.9, zero inside samples, zero fresh opaque obscurers, zero fresh avatar fading, and the original angle and final radius checks. It now asserts those ratios independently as well as the source result, requires zero physical unresolved samples, and verifies compatibility-counter agreement. A transient LOS count with passing original ratios is allowed; lower ratios, opaque fresh obstruction, or physical overlap still fail.

Diagnostics keep only first and largest escape snapshots, each with at most two overlapping part records. They record render/postphysics/suspended-heartbeat phase, current/cached origin, raw position, selected step and distance, face/grid candidate, total overlap count, nearer LOS-rejected candidate count, final LOS status, and part names, sizes, CFrames, velocities and falling state. The final sample includes the most recent guard phase and age. Searches are finite but their worst-case geometry-query cost has not been measured in Studio; no performance or visual pass is claimed from offline mocks.

Validation:

| Check | Result |
| --- | --- |
| Geometry contract, current source | PASS: 138 executable assertions, including 17 actual flow acceptance controls |
| Semantic mutations | PASS: all 9 rejected for their intended behavioral failures |
| `--baseline-face 4d23e28` | PASS: oriented exit distance, discrete gap, physical-vs-LOS classification and stale sampled flag failures reproduced |
| `--baseline-runtime2 781ff4b` | PASS: four earlier failures remain reproducible |
| `--baseline-los ef9b5f8` | PASS: six prior LOS/root-follow failures remain reproducible |
| `--baseline b521dea` | PASS: seven prior geometry/lifecycle/occlusion failures remain reproducible |
| Camera/shop stability contract | PASS: 17 assertions |
| Luau 0.737 compilation | PASS: complete client and both actual long-tunnel flow payloads |
| `git diff --check` | PASS |

The geometry oracle uses the full 15 separating axes for oriented boxes; it supplies collisions to the extracted production guard rather than duplicating its face-exit algorithm. Controls also cover compound overlaps, query-only eggs, postphysics attribution, fresh physical observations, preserved swept-path rejection, and unmasked emergency distance. Three durable controls reproduce the late Scriptable-owner interleaving identified by Agent 1; the Coordinator's unconditional guard bypass is preserved.

Run `node work/automation/scripts/camera-geometry-guard-contract.mjs`; add one of the baseline options above for fail-before verification. The contract discovers the Luau toolchain, supports `LUAU_COMMAND`/`LUAU_COMPILE_COMMAND`, and compiles the actual client and flow payloads. Required combined runtime remains **BLOCKED pending Coordinator Studio verification**.
