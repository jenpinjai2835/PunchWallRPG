# Character spawn lifecycle contract — 2026-09-06

The spawn binder now reads the current HumanoidRootPart again after discovery waits and accepts only a direct BasePart child of the current character with a living Humanoid. This prevents a dead character from being relocated and prevents an obsolete, detached root from being moved while the replacement root remains at its original position.

This handoff adds tests and documentation only. The Coordinator owns the production fix, Studio flow, registry, integration, and final verification.

## Source and reproduction

- Fixed source: `4654f205d704548d094c09eb8d84f63f4d9b1442`.
- Failing comparison: `781ff4b`.
- Production path: `work/punch-wall-rpg/src/server/PunchWallBootstrap.server.lua`.
- Normalized full-server SHA-256: `9b57a40143c81460e87c50abb754b512a52868c70b436b2b0af8f56edb1e238b`.
- Extracted binder SHA-256: `54aa4b850b4ac9b773d0f55f59c531e52de65f310b285c64f7bd8cecb9825789`.

The test executes the actual `do` block containing `shared.PunchWallBindPlayerSpawn` and the actual existing-player/future-player bootstrap registration. It does not substitute a second implementation of the binder. The scheduler, events, character children, clock, and vector/CFrame values are deterministic mocks; each scenario has a separate Luau VM.

Two exact failures reproduce on the previous source and pass on the fix:

1. The character dies while waiting for its root. The old binder later moves it and marks `PunchWallSpawnPlaced`. The fixed binder leaves the dead character untouched.
2. The root is replaced while the character waits to enter workspace. The old binder moves the captured, detached root and marks placement, leaving the current root unmoved. The fixed binder places the current root and leaves the detached root untouched.

The test requires the expected assertion message for each baseline failure. An unrelated mock error does not count as reproduction.

## Executed validation

Run from the repository root:

```powershell
node work/automation/scripts/character-spawn-lifecycle-contract.mjs
```

Optional arguments are `--source-root`, `--baseline-ref`, and `--luau`. `LUAU_QA_EXE` also overrides the executable. The default executable is the existing local Luau 0.737 runtime; no binaries are downloaded. The script writes no files and does not start Studio or access saved profiles.

| Check | Result |
| --- | --- |
| Complete fixed server compiles, including its local-register budget | PASS |
| Exact binder and bootstrap scenarios | PASS, 39 executions |
| Previous-source defects reproduced at the expected assertions | PASS, 2 |
| Behavioral weakening controls compile before execution and fail at the expected assertions | PASS, 14 |
| Studio verification of this handoff | Pending Coordinator |

The 39 executions cover fresh existing players, future players, future characters, duplicate binding and repeated same-character events, normal respawn, delayed root/Humanoid/workspace readiness, death during waits, root replacement/removal, invalid root class, current-character changes before deferred CharacterAdded delivery, PlayerRemoving cancellation and connection cleanup, plus bounded missing-component cases. Twenty scenarios run with immediate and 20 ms deferred delivery; the specifically deferred ordering runs only in deferred mode.

Successful placement requires the canonical `RespawnLocation`, the expected root pose four studs above the spawn and facing course direction −Z, a true placement marker, and zero linear and angular assembly velocities. The no-repeat checks move the player after placement and require that position to survive repeated binding/events.

The fourteen controls independently weaken living-Humanoid validation, root reacquisition, current-character validation, removed-player binding validation, workspace membership, once-per-character placement, once-per-player binding, connection cleanup, linear velocity reset, angular velocity reset, spawn height, facing, Humanoid discovery, and root class validation. Each altered binder must compile; syntax errors cannot satisfy a control. A retained captured root fails because its direct-parent guard rejects the obsolete root, leaving the new character unplaced; this is distinct from the older baseline, which incorrectly moved the detached root.

## Boundaries and remaining runtime gate

The waits are sequential and bounded: five seconds for the root, five seconds for Humanoid, then five seconds for workspace membership. With all three absent the mock finishes within 15.3 seconds. An unchanged character is not automatically retried after the task finishes; this is the existing bounded discovery policy, not an indefinitely active placement observer. Normal Roblox scheduling can add delay beyond the nominal intervals.

This contract checks source behavior under controlled scheduling. It does not prove real physics settling, replication timing, all custom rig behavior, or a mobile frame-time improvement. The current bootstrap re-reads a direct child without yielding before pose assignment; the mock follows direct-child lookup semantics and does not manufacture impossible nested `FindFirstChild` results to claim extra guard coverage.

The Coordinator's `punchwall-map-progression` flow covers native fresh spawn, normal respawn, course facing, canonical RespawnLocation, and no repeated relocation. Earlier targeted2 evidence passed those spawn checks, then failed at the separate retired `Cyber Gate` lookup. That entire flow must not be described as passing on the strength of its successful spawn steps. The integrated runtime rerun remains a Coordinator gate.
