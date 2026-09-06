# Complete nearest depth target selection

Agent 2, 2026-09-06. Branch `codex/fix/smash-target-scan-final-20260906`, base `05e15fa`; source-only handoff `f0bdeaef8f8c6c1d6ca3662de4b123876b26e8c0`. Coordinator owns integration and Studio; Agent 3 owns the strict runtime target flows. No Settings, camera, server, or other source changes were made.

The actual evidence `work/docs/evidence/smash-settings-iron-diagnostic-20260906.json` shows the character at `(-4,30.25,-113)` looking down. The expected Iron top block `DepthBlock_L020_C06_R06` is at `(-4,22.25,-113)`, eight studs away, and its visible top face is clear. The old 38-stud query returned exactly 400 results and omitted that block. The HUD instead selected row 5, twelve studs away. Spatial query result order is not distance order, so choosing the nearest of a truncated set cannot establish the nearest target.

`clientRuntime.SelectNearestDepthTarget` now reuses the cached overlap parameters with `MaxParts=0`. It queries radii 8, 16, 24 and 38, and stops only when the best center distance is within the radius already searched. A part's bounds may touch a small query while its center remains outside it; merely finding a result is insufficient to stop. The producer deduplicates repeated results before eligibility and distance work, rejects broken/non-depth/foreign/non-part results, and skips stale or missing depth folders. The original event-driven cache refresh still updates the shared filter when the folder changes.

The final query sphere remains 38 studs, including its original bounds-intersection semantics. Facing remains strictly greater than -0.1, ordinary-wall comparisons are preserved, target updates remain every 0.15 seconds, and HUD focus still uses 24 studs. No full enumeration of the 5,400 depth blocks was added. A nearby grid target uses one complete 8-stud query; an empty distant region uses four spatial queries and processes zero results. Radius, query count and raw/unique result counts are published as `TargetDepth*` attributes for runtime evidence.

Local checks completed:

| Check | Result |
| --- | --- |
| `node work/automation/scripts/target-depth-selection-contract.mjs` | PASS: 68 executable assertions against extracted production selector, parameter setup and cache refresh |
| `--baseline 05e15fa` | PASS: old producer reproduces the omitted eight-stud Iron result using the actual root/target coordinates |
| Semantic mutation controls | PASS: all 10 rejected for intended behavioral failures |
| `node work/automation/scripts/client-runtime-performance-contract.mjs` | PASS: all 28 checks, with obsolete capped-query assertions updated |
| Luau 0.737 full client compile | PASS; part of the executable target contract |
| `git diff --check` | PASS |

The executable controls include unordered capped results, 401 dense local hits, a bounds-only first-radius result hiding a nearer unsearched center, exact facing thresholds, coincident centers, broken/non-depth/foreign/non-part results, ordinary-wall priority, empty/far queries, original horizon behavior, replaced/renamed/detached folders, repeated-query work and a 5,400-part spatial-query workload. Mock folder enumeration throws, so a producer that scans the entire depth folder fails. Mutations restore the cap, stop too early, loosen facing, select invalid blocks, repeat eligibility work, scan the full folder, extend the horizon, replace a nearer ordinary wall, or use a detached folder; all are caught.

These checks measure the producer's query and result workload with deterministic spatial-query mocks. They do not claim a measured Roblox frame-time improvement. The strict real Iron target observation and combined runtime remain **BLOCKED pending Coordinator Studio verification**. Source is immutable during that runtime handoff.
