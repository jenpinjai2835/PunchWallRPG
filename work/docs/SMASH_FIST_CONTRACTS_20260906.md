# Current fist safety contracts — 2026-09-06

Agent 3 owns only `batch-b-fist-flow-contract.mjs`,
`fist-pet-safety-contract.mjs`, and this document on
`codex/test/smash-fist-contracts-20260906`, based on
`47fdf5238a7752e889f15d887bc5a1773c8021e3`.
The Coordinator registered this isolated offline test-authoring scope.
No gameplay source, flows, registry, Studio, Agent HQ, or other worktrees were
modified by this worker.

## Why the contracts changed

The original Batch B check passed 4 of 11 checks on the base: its assumptions
still required four alignment tiers, eight Creator Store tiers, and the
inactive `HeroGauntletV2` model. The old fist/pet contract passed 34 of 34,
including checks that could be satisfied entirely by that inactive code and
legacy static artwork. Neither result established safety of the new native
first-five route.

The Batch B contract now targets the accepted three current flows:
`first-five-fist-presentation`, `item-matched-fist-visuals`, and
`fist-arm-alignment-qc`. It requires five canonical native items, the full
configured catalog (currently 16 normal plus 3 premium), authoritative ownership,
one equip dispatch followed by bounded observation, actual part/color/material
parity, all-corner hand-local bounds, direct hand weld endpoints, current-rig
reporting, and serialized respawn identity with old-object release.

`creator-store-fist-visuals.json` is no longer used as evidence for the active
first-five route. This change does not edit, register, retire, or mark that
historical flow passing; the Coordinator owns its suite disposition.

The fist/pet source contract preserves 27 existing pet, duplicate-slot/delete,
Shop feedback, static fallback, and contextual-action checks. Seven old fist
checks are replaced with eleven current-route checks, including five source
mutation controls. The new checks cover the shared builder before imported
fallback, native-only instance creation and part budget, cuff/wrist geometry,
noncollision, actual post-placement bounds, teardown, both rig profiles,
shared Shop/Inventory builder callbacks, static viewport behavior, offscreen
model removal, and connection cleanup. Imported fallback and bounded,
reduced-motion-aware aura checks remain required.

## Safety gaps surfaced and coordinated

The new flow requirements intentionally did not accept two weaknesses in the
first QA draft: live Instance references stored in `shared` across separate
observation calls, and missing explicit rejection of animation controllers,
body movers, extra joints and non-weld constraints. Agent 1 strengthened all
three flows in its registered review scope. The contract requires the updated
`verifyVisualHazards(model, preview, hand)` call inside every native verifier
and an outer-model audit for equipped native and imported paths.

The respawn contract uses a serializable token and saved name on the player,
with token tags on the old character/model. It reacquires the current character
and scans actual workspace descendants to prove old tags are absent. No
executable or Instance state is permitted through `shared`.

## Executed verification

These are offline results against the stated read-only snapshots. The consumer
source was inspected as uncommitted integration work based on `47fdf52`. Agent
1 has since committed the inspected flows as
`a82e36af7756faa8d1c780683969cabfa37e6c86`. These checks are not a combined
committed release result.

| Check | Result |
| --- | --- |
| Both updated Node scripts compile | PASS |
| Fist/pet source contract against `F:/Roblox/PuchWall-completion-20260906` | PASS, 38 / 38 |
| Five source mutations | All rejected: bypass active catalog, enable collision, inflate part budget, weld to wrong endpoint, leak preview connections |
| Batch B flow contract against `F:/Roblox/PuchWall-fist-review-20260906` | PASS, 14 / 14 |
| Five flow mutations | All rejected: remove cleanup, truncate catalog to eight, remove real corner audit, ignore material mismatch, retry equip during observation |
| Exact extracted flow hazard helper executed in Luau 0.737 | PASS: 8 safe cases accepted and 27 unsafe cases rejected |
| Three weakened hazard helper mutations | All rejected: allow body movers, ignore wrong weld endpoints, allow preview particles |
| Patch whitespace | PASS |
| Default checks on this unchanged authoring source/flow base | BLOCKED by missing dependency integration, as expected; source contract 31 / 38, flow contract 9 / 14 |
| Final integrated checks and actual Studio regression | BLOCKED pending Coordinator integration and evidence |

The helper's safe cases include a static preview part, correctly welded
unanchored equipped geometry, and the controlled attachments/effects permitted
on equipped fists. Negative cases include Script/LocalScript/ModuleScript,
Tool, remotes, bindables, input prompts, Sound, Humanoid/Animator/controller,
BodyVelocity, Motor6D/Weld, non-weld constraints, preview effects/welds,
wrong hand endpoint, and disabled weld. Each mutation needs a passing positive
baseline and must fail its specific guard; an already-failing baseline cannot
count as successful mutation coverage.

The exact helper is executed from the flow, using small class/ownership
`IsA`, `GetDescendants`, and `IsDescendantOf` doubles. This proves its decisions
for those inputs, not Roblox engine behavior, visual quality, physical phone
performance, or both-rig runtime fit. Other source/flow predicates are coverage
and integration guards, not substitutes for runtime tests. Both scripts keep
`studioRuntimeStatus: BLOCKED_PENDING_SEPARATE_COORDINATOR_RUNTIME_EVIDENCE` in
successful offline output.

The scripts report their source root and SHA-256 hashes of the source or parsed
flow snapshots they read. This avoids treating later dirty-tree edits as the
same checked artifact. The hashes are evidence identifiers, not authenticity
attestations.

## Reproduce and integrate

From this authoring worktree, the explicit read-only dependency checks are:

```powershell
node work/automation/scripts/fist-pet-safety-contract.mjs --source-root F:/Roblox/PuchWall-completion-20260906
node work/automation/scripts/batch-b-fist-flow-contract.mjs --source-root F:/Roblox/PuchWall-fist-review-20260906
```

After the Coordinator integrates the shared builder/consumer wiring and Agent
1's stronger three flows, integrate this commit and run the default commands
from the final integration worktree:

```powershell
node work/automation/scripts/fist-pet-safety-contract.mjs
node work/automation/scripts/batch-b-fist-flow-contract.mjs
```

The optional `--source-root` changes read paths only. It does not sync or edit
that tree. `LUAU_COMMAND` can point to an installed Luau CLI; missing CLI or
helper execution failure is a blocked required check, never a pass. Record
these outputs with the final commit, then run the actual three Studio flows
and the Coordinator's required combined regression. An offline pass cannot
resolve the known interrupted-punch runtime investigation.
