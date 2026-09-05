# Independent final camera safety review — 2026-09-06

HQ agent-1 reviewed immutable source `a5fea5d3b57dfa85393f8c4c8735ab5bf8c90004` and tests/document `2ddecc6eb90abcb1dbaad97572079662335fe74b` from `F:/Roblox/PuchWall-camera-final-safety-20260906`. Only this document is authored in the clean settings-attestation worktree. No source, flow, script, Studio, HQ, registry or output artifact was changed. The Coordinator owns integration after the frozen combined run.

**Verdict: no new actionable P1/P2 defect established in this patch.** The two previously reproduced producer cases now behave correctly, and the strict existing acceptance gates remain intact. This is a qualified source/test review, not closure of the actual four safety samples or final release approval. Required fresh Studio validation remains **BLOCKED pending Coordinator integration and runtime**.

## Zoom constraints and camera ownership

The guard now reconciles its stored orbit with current player zoom bounds before applying Custom-camera orbit correction. Initialization, mouse-wheel delta, and pinch updates use the same helper. Narrowing bounds from an existing 30.1643219 orbit to 12 therefore preserves the engine's new 12-stud pose; teleport rebasing retains 12. Widening bounds later leaves the current choice at 12. The helper retains the pre-existing supported 2–80 range rather than claiming support for arbitrary first-person or farther camera configurations.

The unconditional Scriptable return remains before orbit clamping and publication. The new PostSimulation callback also excludes Scriptable. The suspended Heartbeat guard reaches that same unconditional return. The source tests exercise late Scriptable ownership while old punch state remains truthy, including all new guard phases, and preserve the actual position/focus. No CameraType assignment was introduced by this patch.

I reran the independent scene from the preceding review against the exact new guard: prior orbit 30.1643219, Scriptable ownership, constrained default pose 12, then root teleport 63. Actual results are `12 → 12 → 12`; all five checks pass. On frozen `6211b00`, the same scene produced `12 → 30.1643219 → 30.1643219`. A final `bypass=false` after returning to Custom remains correct and is not the failed teleport predicate.

## Physics phase, ordinary following and cache lifetime

Fresh overlap detection retains the same 0.55-stud query but now runs in PostSimulation. The callback invokes geometry correction only when that actual query is blocked. It does not call or advance the authored delayed punch follower. In a clear scene it leaves the camera, guard timestamp and ordinary follow state alone. A current-render Heartbeat does not repeat the repair; the existing suspended-render handoff remains enabled after its unchanged 0.35-second grace period.

The documented resumption ordering supports repairing physics changes before waiting-task observations. The patch does not move or delay the timed sampler to skip its old failure. [Deferred engine events](https://create.roblox.com/docs/scripting/events/deferred), [task scheduler](https://create.roblox.com/docs/performance-optimization/microprofiler/task-scheduler).

My independent simple-overlap scene now samples `false` immediately after PostSimulation and remains `false` after Heartbeat, with an escape inside the original 2.65 bound; all three checks pass. The new durable control also replays the recorded rotated L038 block with the independent box-overlap oracle. That pose came from the previous successful largest escape, not one of the four uncaptured failing samples, so it is useful geometry/scheduling coverage without pretending to reconstruct those missing events.

Ordinary translation correction still uses `24 * min(deltaTime, 0.1)`, at most 2.4 per response. Root transport remains separately swept and measured. An exceptional newly overlapping physical scene can require a distinct repair as well as the ordinary render/suspended response; new cumulative diagnostics expose those publications. This is not a new exemption from the existing measured escape/correction gates.

The existing guard is installed once. PostSimulation reads the current camera and character; the shared reset on character replacement still invalidates last-clear poses, follow handoff, orbit/input state and shared caches. It also clears the newly added publication records and counters. No character-capturing per-respawn event loop was added. Existing reset/lifecycle, no-history, cached-overlap, blocked-fallback and final-pose validations continue to execute successfully.

## Strict gates and bounded diagnostics

Both `camera-long-tunnel-regression.json` and `camera-teleport-scriptable-visibility.json` are byte-unchanged from `6211b00`. The player-visible runtime oracle retains:

- The actual 0.55 physical query with zero unresolved samples; separate 0.3 sampled-inside and 0.4 fresh-inside checks.
- Actual escape/correction maxima at most 2.65 and the unchanged ordinary 2.4 response budget. A larger unavoidable egress still records its full distance and fails acceptance.
- Historical clarity/readability of at least 0.55/0.65, settled clarity/readability of at least 0.9/0.9, and fresh unobscured, readable, unfaded Custom-camera output.
- Exact selected/configured/cached orbit agreement, final distance tolerance, completed follow handoff, and original Scriptable/teleport/cleanup checks.

The sampler's physical failure counter is uncapped. Only its detailed storage is capped at four samples and two part records each; total overlap count remains visible. Records retain actual camera/root position, punch, physical box size, guard/render age, phase, prior guard outcome, and blocker geometry/velocity. They contain serializable values, not Instances or executable cross-VM state.

The largest sampled camera movement now retains both root positions, guard phase/age and last guard publication. This addresses the missing context around the old `sampleMaxStep=99.7955`. A last-publication record is the latest guard write, not automatic attribution of every intervening engine/follower movement to that guard; its timestamp and before/after positions must be compared with the new runtime sample. The patch does not claim the old hundred-stud sample was visually harmless or already solved.

Guard-published travel, escape-associated travel and write counts accumulate within the defined publication cycle. A render callback starts the cycle; suspended rendering starts a cycle at the next physics step. They measure publication movement, separately from the established correction and egress distances, and do not replace any acceptance threshold. Retained records are last/max only. Detailed publication allocation exits immediately outside Studio, while actual collision correction remains active. The exact-source release-mode control and weakening mutation verify this separation.

## Executed verification

| Read-only check | Result |
| --- | --- |
| Current geometry contract | PASS: 166 exact-producer assertions, 15 meaningful weakening mutations rejected |
| `--baseline-final 6211b00` | PASS: both stale-radius and pre-wait-overlap failures reproduced on old source |
| Historical baseline modes `4d23e28`, `781ff4b`, `ef9b5f8`, `b521dea` | PASS: all 21 expected historical failures reproduced |
| Camera/shop stability contract | PASS: 17 existing camera, Depth and Boost assertions |
| Full client and actual long-tunnel chunks | PASS: full client O0/O1/O2 and both payloads compile with official Luau 0.737 |
| Independent preceding-review scenes | PASS: five zoom/ownership/rebase and three phase/safety assertions against new source |

LF-normalized SHA-256 identities verified against the immutable commits:

- Full client: `e051b95177ab36632f5ae38f62e6440e07c6705ca7fc3fc41db7adac2d96f5c7` (619,053 bytes).
- Geometry contract: `8bc6a8d7969169aae597916304702455a3a19cafddd3e62c37b38f70312f4870` (49,293 bytes).

Temporary independent runner: `C:/Users/Jennarong Pinjai/AppData/Local/Temp/smash-camera-final-safety-review-generated.mjs`. Existing strict flows and product source were not edited for review. Checklist complete: immutable source review; focused positive/baseline/mutation/compile verification; qualified document-only handoff.

The Coordinator still needs actual reruns of the two failed camera flows and the appropriate combined regression after integration. The four prior physical samples and unexplained maximum sampled movement require that fresh evidence. This review makes no physical-phone FPS, multiplayer, production analytics, final artifact, or publishing claim.
