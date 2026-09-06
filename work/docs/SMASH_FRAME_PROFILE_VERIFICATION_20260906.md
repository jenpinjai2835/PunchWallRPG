# Final artifact frame-profile verification

Agent 3, 2026-09-06. Base `6211b00`, isolated branch `codex/test/smash-frame-profile-final-20260906`. This assignment owns only `work/automation/scripts/studio-frame-profile.mjs` and this document. The Coordinator owns Studio, the artifact build, native reopen verification, integration, and release decisions. Do not integrate this infrastructure script while the frozen full suite is running.

The new tracked tool addresses the six findings in `SMASH_FRAME_PROFILE_REVIEW_20260906.md`. It has not been run against Studio. **No measured performance result or physical-phone claim is available from this assignment.**

## Artifact identity before measurement

The CLI requires an explicit Studio id, the exact validation-copy Studio name, a fresh evidence leaf, the canonical build manifest path, and the JSON output of the completed native final-artifact regression. A static-only result is insufficient. The tool does not reopen, save, publish, or sync a place itself.

Before spawning an MCP client, the tool:

1. Requires the exact nine current local Lua paths and hashes their raw and normalized bytes.
2. Requires this repository's canonical build manifest, canonical output, and byte-identical validation copy. Manifest module inventory, allowlist/CDATA flags, byte count, all nine raw/normalized source hashes, source root, canonical path, and artifact SHA256 must match current files.
3. Binds the saved successful native reopen proof to the same canonical/validation paths, artifact SHA256, nine-code contract, explicit Studio id/name, local place id zero, and nonempty completed runtime checks.
4. Runs `verify-exact-rbxlx-sources.ps1` against the actual canonical XML, rather than trusting only manifest claims. The validation copy is already required to have identical bytes.

It then runs the tracked `verify-studio-source.mjs` against the same explicit Studio id and exact name, requiring its actual in-Studio normalized source equality for every module. After measurement and owned Play cleanup it repeats that read-only live check and all disk binding checks. Canonical bytes, validation bytes, source hashes, manifest, reopen proof, and the profiler/verifier/MCP helper scripts must remain unchanged. `repositoryCommit` and `artifactBuildCommit` are separate metadata; neither is used as a substitute for actual artifact/source equality.

The saved reopen proof is an explicit prerequisite established by the Coordinator's independent reopen workflow. A filename or equal source alone cannot prove that all non-code DataModel contents were reopened from disk. Do not sync between that native reopen and this measurement. This tool binds and rechecks that prior artifact evidence; it does not infer opening history from a Studio title.

## Fixture and measured phases

Every destructive server fixture call requires a single Studio player, `PersistenceMode=EphemeralStudio`, `PersistenceStudioDefaultEphemeral=true`, explicit world live-opt-in false, ServerStorage live opt-in not true, and a ready, ephemeral, non-writable player profile.

Seed names are checked against the actual loaded GameConfig catalogs before Reset. Reset and SetStats must return successful tables; the seed is checked through actual RPGStats values and a fresh server Snapshot. The client must receive those exact values, show all five owned fists and all three pet copies in the real Inventory snapshot, and build two equipped companion models before sampling.

The seed is five ordinary fists (Starter Glove, Boxing Glove, Iron Knuckle, Thunder Fist, Titan Gauntlet), three pet copies (Forest Pup twice, Miner Cat once), and two equipped pets (Forest Pup and Miner Cat). It is not a three-companion fixture.

| Phase | Meaning |
| --- | --- |
| `idle-two-seeded-companions` | Six seconds with menus closed and the two observed companions; no gameplay input. |
| `shop-visible` | Six seconds with the real Shop snapshot asserting its visibility and Fists tab. |
| `inventory-automation-navigation` | Three rounds of All/Fists/Pets/Honor; every navigation command and actual Snapshot must report the requested state. Each command includes OpenInventory, category selection, and diagnostic Snapshot work. |
| `four-world-reset-twenty-direct-server-punch-stress` | Actual `StressPunchCase`, four cycles by five attempts. Includes four world resets, teleports, destruction, direct authoritative server punches and collision diagnostics. The first reset clears seeded equipment/inventory. Requires valid=true, exactly 20 punches/total, no overlaps or stuck results. |

All phases report Studio `RenderStepped` delta milliseconds including MCP boundary/transport scheduling and harness overhead. They are not ordinary native-input punch FPS or physical-phone performance. Inventory automation does more diagnostic work than native category callbacks. The stress phase is deliberately separate from the seeded UI phases.

The collector records elapsed seconds, sample count, total observed intervals, cap (36,000), dropped/invalid counts, saturation, nearest-rank p50/p95/p99, maximum, and counts above 50/100 ms. Saturated or invalid phases cannot pass. At least 30 valid intervals are required. `lastTargetScan` is explicitly a final selector snapshot, not phase totals/maxima. Memory values are total client-reported MB at boundaries and do not establish allocations or a memory leak. Command timestamps and phase Begin/Finish request/response boundaries are preserved.

## Failure and cleanup

The profiler disconnects its RenderStepped connection on explicit Destroy, external Instance destruction, and a 300-second maximum lifetime. The CLI independently attempts profiler Destroy, owned Play stop/Edit readiness, and MCP close. A failed earlier cleanup step cannot skip later ones. Every tool `isError` result is checked; any primary, cleanup, binding, sampling, or evidence-write failure produces a nonzero exit.

Evidence writing occurs after cleanup and uses exclusive creation (`wx`), preserving existing files. Its failure cannot bypass Play stop or MCP close. The primary error and each cleanup result are retained separately. Postflight verification runs after owned Play has stopped. A process forcibly killed by the OS cannot promise asynchronous cleanup; the bounded in-Studio collector lifetime and ordinary Studio Stop remain the recovery mechanisms.

## Offline verification

```powershell
node --check work/automation/scripts/studio-frame-profile.mjs
node work/automation/scripts/studio-frame-profile.mjs --self-test
git diff --check
```

PASS: 52 Node checks, eight production Luau snippet compilations, and 31 assertions executing the exact guard/collector snippets with deterministic boundary mocks; Studio was not used. Negative controls reject stale artifact/source/raw hashes, wrong module sets, missing native reopen evidence, wrong Studio/local-place identity, and false live byte comparisons. Cleanup tests inject Destroy and Stop failures and prove remaining cleanup still executes. The 16 exact ephemeral controls cover ordinary safe defaults and denied Studio/player/default/live/profile/harness states. The 15 collector assertions check actual nearest-rank milliseconds, frame counts, cap/drop accounting, invalid/short phases, phase mismatch, and explicit/external/deadline cleanup. No mock timing is a performance measurement.

## Coordinator run after the rebuild and independent reopen

First save the successful JSON output of `run-final-artifact-regression.ps1` using the actual reopened Studio id/name. Keep that proof and the build manifest with the release evidence. Then run from the integration repository (replace the explicit id and fresh evidence name):

```powershell
node work/automation/scripts/studio-frame-profile.mjs `
  --studio-id 'ACTUAL_REOPENED_STUDIO_ID' `
  --studio-name 'PunchWallRPGPlayable_v1_final_validation.rbxlx' `
  --evidence-leaf 'smash-rebuilt-artifact-frame-profile-20260906' `
  --manifest 'outputs/PunchWallRPGPlayable_v1_final.build.json' `
  --reopen-proof 'work/docs/evidence/smash-final-artifact-native-reopen-20260906.json'
if ($LASTEXITCODE -ne 0) { throw 'Frame profiling failed; inspect its evidence and cleanup status' }
```

The old manifest from a different worktree/commit is expected to fail preflight. Actual artifact-bound execution, interpretation of measured intervals, and the full release gate remain **BLOCKED pending Coordinator rebuild/reopen/runtime evidence**. No threshold or FPS target has been invented to turn the forthcoming measurement into a pass claim.
