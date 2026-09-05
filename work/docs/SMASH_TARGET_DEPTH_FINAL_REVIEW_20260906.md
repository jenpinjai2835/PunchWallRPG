# Independent target-depth review — 2026-09-06

Reviewed source commit: `f0bdeaef8f8c6c1d6ca3662de4b123876b26e8c0` in `F:/Roblox/PuchWall-target-scan-final-20260906`, integrated by the Coordinator as `6c0f848`. Scope: read-only review of the client selector and its existing cache/HUD consumers. This worker wrote only this document, used no Studio calls, and did not modify source, tests, flows, or Agent HQ.

Decision: no blocking defect found in the progressive selector change. A retained cache limitation is described below; integrated runtime verification remains the Coordinator's gate.

## Completeness and compatibility

The recorded original Iron diagnostic identifies the actual defect: root `(-4,30.25,-113)` looked straight down; the desired `DepthBlock_L020_C06_R06` center was eight studs away at `(-4,22.25,-113)`. The capped overlap returned 400 items and omitted that block. The HUD instead selected row five at twelve studs. The character was alive and anchored, training and menus were inactive, and HUD layout was ready. The unchanged iteration04 flow continues to require the exact nearer target.

The new `clientRuntime.SelectNearestDepthTarget` at client line 9190 queries radii 8, 16, 24, and 38 using the same cached include filter with `MaxParts=0`. Roblox's spatial query uses bounding-box overlap, and zero removes the result-count limit. See [WorldRoot spatial queries](https://create.roblox.com/docs/reference/engine/classes/WorldRoot#GetPartBoundsInRadius) and [Roblox's OverlapParams announcement](https://devforum.roblox.com/t/introducing-overlapparams-new-spatial-query-api/1435720).

The early-exit proof is sound for the existing block-center selection metric: after a complete radius-r query, every eligible block whose center is closer than a best center at distance d <= r must have intersected that query. A large block whose bounding box intersects radius r but whose center lies beyond r does not justify stopping. The implementation correctly expands in that case. No ordering guarantee is assumed. If no early exit applies, the complete 38-stud bounds query preserves the old final overlap domain, including a part whose center is slightly beyond 38 while its bounds overlap it.

The selector retains strict facing `> -0.1`, the zero-distance facing fallback of 1, and strict closer-than replacement of an ordinary wall. It adds BasePart/descendant checks and preserves the IsDepthBlock/not-Broken conditions. The downstream 24-stud HUD center-distance gate, wall/boss separation, HP and level presentation, contextual actions, and 0.15-second scan cadence are unchanged. This patch does not alter combat authority or add line-of-sight gating.

## Cache, work, and telemetry

The helper rejects a detached or renamed cached folder. Existing root replacement, child addition/removal, and cache refresh update the reused OverlapParams include list. The surrounding Heartbeat checks stale non-nil cached references before calling the helper. Each helper call uses a fresh `seen` table; duplicate results from expanded spheres undergo eligibility and distance work once. There are no yields between progressive queries, so this deduplication does not reuse state across simulation steps.

The number of native queries is bounded by four per target scan. Work is proportional to the returned local result arrays, with repeated membership checks across radii and one eligibility evaluation per unique item. It does not enumerate all 5,400 depth blocks. This is not a constant-cost or measured frame-rate guarantee: local density and large overlapping bounds can increase uncapped results. The tests' small query counts are fixture measurements, not native Studio timing.

Telemetry accurately separates query count, raw returned candidates, unique candidates, final searched radius, and selected distance. `TargetDepthSelectedDistance` can describe the retained ordinary-wall candidate passed into this helper. It records the last selector invocation; the surrounding early return when no character/world is available does not refresh those fields. Neither fact is a gameplay defect, but diagnostics must not interpret the values as current per-frame depth-only state.

## Retained P3 limitation

The existing folder cache does not discover an in-place rename back to `Depth Blocks` after an earlier rename caused its cached reference to become nil. The second rename does not emit ChildAdded, and the Heartbeat stale-reference checks only run for non-nil cached folders. An independent temporary execution of the exact cache refresh and Heartbeat cache-check fragments reproduced this. This behavior predates `f0bdeaef`; ordinary server reset/replacement uses hierarchy events and is covered by the existing path.

If in-place folder renaming is made a supported operation, the smallest targeted follow-up is bounded name-change observation for direct child folders, with connections owned by the current root and disconnected on replacement/removal. Do not restore a full depth-part scan or weaken the exact Iron fixture to address it. This follow-up was reported to the Coordinator; it is not silently counted as passing lifecycle coverage.

## Checks independently run

```powershell
node work/automation/scripts/target-depth-selection-contract.mjs
node work/automation/scripts/target-depth-selection-contract.mjs --baseline 05e15fa
node work/automation/scripts/client-runtime-performance-contract.mjs
```

- Current exact-source selector: 68 assertions PASS across unordered-cap, dense ordering, large-bounds early exit, eligibility, horizon/ordinary-wall precedence, stale cache, and local-work fixtures.
- Ten behavioral mutations fail at the named intended assertion; full client compilation PASS.
- Old source reproduces the intended eight-stud Iron omission assertion.
- Runtime performance contract: 28/28 PASS.
- Independent temporary check: the exact production helper matches a complete 38-stud reference across 500 deterministic randomized axis-aligned-box worlds, including translations, large bounds, broken/behind parts, and existing nearer ordinary walls. All 1,000 distance/completeness and query-count assertions PASS. This model checks algorithmic completeness; it does not emulate Roblox timing or network streaming.
- The in-place rename limitation above is independently reproduced and reported, not included among passing scenarios.

The actual revised iteration03/04 flows and native query timing are owned by the Coordinator and were still running at review handoff. No combined-runtime PASS or overall READY claim is made here.
