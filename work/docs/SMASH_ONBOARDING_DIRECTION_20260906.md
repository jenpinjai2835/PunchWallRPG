# Onboarding entrance direction and waypoint QA — 2026-09-06

HQ agent-1. Isolated branch `codex/fix/smash-onboarding-direction-20260906`, base `ad3e2bbc9cb69585d7d0c9de7a3fadaba8489f91`. Owned paths are the onboarding flow, its new offline contract, and this document. No production source, other flow, registry, Studio, HQ or output artifact was changed.

## Diagnosis

Frozen combined evidence `work/docs/evidence/smash-full-integrated-final-20260906/onboarding-waypoint.json` stopped at the old `spawnYaw=180` expectation. It received yaw 0 and TutorialStep 1. Current production places Punch Rookie Spawn at `(-2,2,-18)` and Depth Course Entrance at `(-2,4,-25)`. The entrance and subsequent course lie toward negative Z. The current spawn faces that direction; 180 degrees would face away.

This is an obsolete test assumption, not an indicated new production defect. History explains the mismatch: onboarding's `be9f261`/`4094e51` source used yaw 180; the accepted canonical spawn change `e2cbe34` corrected the SpawnLocation to zero and explicitly placed the character looking toward negative Z. Its flow update covered the near/far waypoint rule but retained the old yaw predicate. Current geometry is at server lines 3528–3570 and 4271.

The default project has an Edit-only Spawn Pad Preview at `(-42,2,0)`. It is not the authoritative generated runtime spawn. The canonical character binder handles characters that load during map construction and places them at the completed map's spawn.

## Changes

- Replace the angle constant with actual horizontal facing-dot checks for both runtime SpawnLocation and current character against the actual entrance position. Require dot >= 0.98, a valid nonzero horizontal direction, and character position within the runtime spawn footprint/height tolerance. Keep yaw only as diagnostic output. The executable oracle also accepts a relocated entrance when both frames correctly face it, so this is not a renamed yaw-zero assertion.
- Observe natural placement **before** invoking Reset. Production ResetWorld itself repositions existing characters, so checking only afterward could hide a broken natural spawn. Require a live current character, actual HumanoidRootPart, completed canonical placement, and exact Player.RespawnLocation identity. Observe geometry again after the normal Reset and retain the TutorialStep 1 requirement. Remove the flow's manual initial PivotTo.
- Guard Reset with actual isolated-player, Studio, ephemeral persistence and no-live-data-opt-in conditions.
- Preserve near/far policy: rounded distance <=18 collapses the large marker while the objective remains ready; distance >18 enables it. The existing far fixture remains 35 studs beyond the entrance. Both observations use bounded waits for actual state, exact Adornee identity and label distance.
- Verify the visible reference HUD's TutorialObjectiveHUD/ObjectiveText teaches PUNCH THE WALL. The old ObjectiveCard is intentionally hidden by current reference HUD code and is not sufficient visible-UI evidence. Keep the near legacy context hidden check and additionally require the actual ContextAction prompt to be hidden near the wall. Distance text is checked for correctness even when the near billboard is collapsed; no claim is made that this hidden label is visible near the entrance.
- Keep both console-error gates and stop-play cleanup. Remove stale instance-ID pinning and use the same two supported place-name patterns as current project flows.

## Executable verification

`node work/automation/scripts/onboarding-waypoint-contract.mjs` — **PASS**:

- 32 assertions execute the exact production spawn declaration, entrance creation, canonical character placement, waypoint policy and reference objective update with the actual new flow verification helpers.
- Actual negative-Z geometry and placement pass; the old `4094e51` yaw-180 source fails the entrance-facing check. Backward/sideways facing, incorrect character position/height, coincident target, and the old Edit preview position fail.
- Near/far producer boundaries cover 7, 18, 18.49, 18.5, 19 and 35 studs, preserving the source's rounded-distance threshold. Hidden/completed objective, wrong target instance, wrong tutorial step, stale distance and unrelated near action fail.
- Seven compiling weakening controls are rejected: accepting backward spawn, ignoring character direction, ignoring actual spawn footprint, reversing the production character direction, hiding the far marker, accepting a hidden objective, and permitting live-data Reset.
- All four execute_luau flow snippets compile with official Luau 0.737. Five structural/scope checks also pass.

Read-only existing `node work/automation/scripts/character-spawn-lifecycle-contract.mjs` — **PASS**: 39 actual producer scenarios, two old-source failures reproduced, 14 compiled mutations rejected, and complete server compilation. The server SHA-256 is `9b57a40143c81460e87c50abb754b512a52868c70b436b2b0af8f56edb1e238b`.

`git diff --check` passes. Checklist complete: source/history/evidence diagnosis; strengthened flow and executable controls; isolated three-file commit/handoff. The Coordinator owns registering the new contract and integration after the frozen run.

Actual onboarding execution remains **BLOCKED pending Coordinator Studio validation**. Geometry and signal mocks do not establish native rendering, physical-device performance, or final release readiness. No direction or tutorial production behavior was modified to satisfy the test.
