# Post-full pet frame and penetration oracle correction — 2026-09-06

Scope: tests and this record only, based on `532e03c89fc7655672e4c5040db5d6495e1fa113`. No gameplay source, Studio state, registry, rewards, damage, limits, or imported assets changed. Agent 1 owns the two flows, their two existing contracts, and this document. Coordinator owns integration and actual Studio reruns.

## Diagnosis grounded in actual evidence

The Coordinator's `work/docs/evidence/smash-post-full-targeted-camera-pets-20260906/pet-size-position-qc.json` failed only because the expected top-level `safe:true` field was absent. Its returned `contractValid:true`, `valid:true`, empty failures, and all three distance records contained 20 valid samples each. The existing flow already tested every model's eight bounding corners, original one-percent inset, exact three-model count, Scriptable camera ownership, and stationary camera. The correction publishes `safe=allValid` from that same accumulated result. Every one of the 60 poses and every existing regex remain required.

The sibling `power-scaled-penetration.json` evidence returned a real PostSimulation peak of 218.360855 studs/second, 120 observed/server-owned fragments, seven physics observations, 120 fast fragments that moved, maximum displacement 32.83263, requested/travel/limit 48, hit count 44, and cumulative broken count 50. It failed the old `broken:40–48` regex. That payload did not record per-block attribution or the direct returned break count; it does not prove that its six additional blocks were structural collateral.

Source establishes why cumulative world breaks are the wrong quantity for the direct punch limit:

- `PunchWallBootstrap.server.lua:5335` counts successful direct hits and direct broken outcomes in the bounded candidate loop; `brokenCount` and `hitCount` are returned separately from the world snapshot.
- The damage loop precedes the yielding 0.42-second `depthPunch.Lunge`. `ResolveCharacterOverlaps` (`:4823`) can call `ShatterDetached` during that interval.
- `ShatterDetached` (`:4667`) records current structural/overlap shatter times and changes actual HP, anchoring, collision, visibility, and detached state. `DropStructural` records the preceding collapse.
- `automationSnapshot` counts every currently broken depth block, then adds the returned punch fields. Its `BrokenDepthBlocks` is neither direct damage nor a per-punch delta.

## Corrected actual runtime oracle

The high-power flow still performs the same guarded ephemeral Reset, Power 1,500,000,000 / WallLevel 99 seed, placement, and single PunchRadius invocation. All original regexes, 120-fragment ownership/motion gates, bounded observation lifetime, starter-power and cooldown steps remain unchanged.

`broken` now reports `r.brokenCount`, retaining the original 40–48 direct-break gate. `worldBroken` separately reports `r.BrokenDepthBlocks`. New mandatory `deltaValid:true` requires the exact actual-state proof:

1. Capture the original depth-part identities and state before the punch and immediately at Invoke return, before the observer's unchanged final 0.15-second wait.
2. Preserve the full original part population and all pre-existing broken identities. Count fresh actual HP decreases, unique bounded candidate indices, and current punch timestamps; match the exact returned/published hit count.
3. Every newly broken part must actually have HP zero, be anchored, invisible, noncolliding/nonqueryable, and no longer detached/falling. Direct breaks require current direct damage; collateral requires current collapse and structural/overlap-shatter provenance, including StructuralFailure. Stale or unknown breaks fail.
4. Require direct count equal returned `brokenCount` and published predicted breaks. Require actual cumulative count equal returned `BrokenDepthBlocks`, with exact delta equal direct plus proven collateral. No larger accepted threshold or arbitrary collateral allowance exists.

Snapshots and Instance references stay within one execute call. Failure diagnostics include bounded counts and the offending identity; successful evidence includes time bounds, full counts, and at most eight example names per category. There are two bounded scene scans, no per-frame scan or added gameplay listener. The callback is inside the observer's existing exception/connection cleanup.

## Executed offline validation

Using official Luau 0.737:

- `node work/automation/scripts/pet-size-position-contract.mjs`: PASS 491 executed assertions, 13 rejected compiling mutations, 17 compiled fixture/mutation programs; client and all existing selected flow snippets also compile. New controls reject an omitted aggregate (exact fail-before), a fabricated `safe:true`, and a first-distance failure masked by later passing distances. Existing geometry, near-plane, cropped viewport, lifetime, and full 60-pose controls remain.
- `node work/automation/scripts/pet-size-position-contract.mjs --baseline 2ddecc6`: reproduces both historical geometry/lifetime failures. `--projection-baseline 521711b`: reproduces the cropped-projection failure.
- `node work/automation/scripts/power-scaled-penetration-contract.mjs`: PASS 25 source/preservation checks, 78 executed assertions, 21 rejected compiling mutations, 31 compiled snippets/programs including all five executable flow payloads.

The penetration harness executes the exact production fragment producer, power profile, `hitDepthBlock`, candidate counting loop, `DropStructural`, `ShatterDetached`, and `automationSnapshot`, plus the exact new flow helpers and output expressions. It schedules 44 direct breaks, six production structural shatters, and two existing world breaks. The old exact output produces `broken:52` and fails its direct 40–48 range; the corrected output preserves direct 44 and independently accounts for world 52. An additional production shatter during the final 0.15-second wait makes the later count 53 and proves that a delayed capture must fail.

Twenty-five malformed-state/result cases plus published-count and late-snapshot controls reject wrong result counts, stale/future/fake structural metadata, no preceding collapse, physically undestroyed blocks, missing/replaced identities, resurrected baseline blocks, no real HP loss, duplicate/out-of-range indices, nonfinite counts, and incorrect cumulative totals. Seven new mutations remove exact accounting/provenance/physical checks or move the capture after the wait; all fail intentionally. The previous 14 impulse, ownership, movement, observer-timing and guard mutations still fail.

## Limits and handoff

These deterministic mocks exercise production state changes and observer ordering; they do not simulate Roblox contacts or prove the attribution of the already-recorded 50-block Studio run. Spatial candidate discovery, engine contacts, contributor reward side effects, networking, and the corrected flows' actual runtime remain the Coordinator's combined validation responsibility. No new source defect is established by these two failures. Required corrected Studio reruns are pending, not recorded as passing here.

Checklist: diagnosis complete; robust oracles and executable counterexamples complete; focused offline checks and diff review complete; eligible for Coordinator integration and actual rerun.
