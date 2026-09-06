# Reduced-motion scene lifetime check — 2026-09-06

HQ Agent 1; branch `codex/test/smash-reduced-motion-scene-20260906`, base `ad3e2bb`. Only the reduced-motion flow, its new offline contract and this document changed. The Coordinator retains source, Studio and registry ownership.

## Diagnosis

The frozen full-suite result `work/docs/evidence/smash-full-integrated-final-20260906/reduced-motion-performance.json` failed its final scene check: parts increased from **6,690 to 6,697** after five seconds, while sounds stayed 7, loaded sounds 7, particles 111 and physics debris 0. The reduced-camera check passed. The old result did not record the added instances, so it does **not** prove those seven parts were an egg or rule out a leak.

The current source explains a legitimate scene lifetime the old fixture omitted:

- `GameConfig.PetDrops` has pity 45, lifetime **24 seconds** and one active drop per player (`GameConfig.lua:452`).
- The real depth-block contributor reward calls `tryDropPetEgg` (`PunchWallBootstrap.server.lua:5221`). That function uses pity and the active-owner cap (`:7671`).
- `petDropRuntime.Spawn` creates one owner/DropId/timestamp-tagged model containing **Egg Ground Glow, Mystery Pet Egg and five Egg Spot parts** (`:7391`). Its own scheduled loop clears the original record with reason `expired` at its deadline (`:7566`).
- `BreakWallCycles` resolves the legacy Brick Wall alias and resets the same depth-block instance after each completed cycle (`:9973`). It reports the actual completed count. The fixture therefore can retain original baseline-part identity while allowing a verified temporary egg.

This is a source-grounded reason to replace the arbitrary five-second final baseline assertion with actual lifetime observations. It is not a retrospective claim that the historical extra seven parts have been identified.

## Revised fixture

All original reduced-motion/feedback/camera steps and their strict acceptance gates remain byte-identical. Both fixture Reset sites now require one isolated Studio player with a ready, non-writable `EphemeralStudio` profile, default ephemeral mode and no live-data opt-in. The original Power 1 preparation and final Power 500 / WallLevel 1 / zero crit / fist multiplier 1 / pet multiplier 0 values remain.

The final server call seeds `PetDropPity = GameConfig.PetDrops.PityBreaks - 1` through `SetStats`, then invokes the original **20 BreakWallCycles once**. It requires `completed == 20`. Before destruction it records every baseline BasePart by actual instance and requires no old egg or physics debris.

Immediately after the cycles, it requires one actual egg model with the expected parent, owner, active DropId, primary part, unclaimed state, spawn time inside the observed destruction window and expiry exactly 24 seconds later. All seven unique direct Part children must have their source-defined names, shapes, dimensions and anchored/collision/query flags. Metadata and a matching count alone are insufficient.

At five seconds, every original baseline part must still exist. The added part set must consist **only of the original seven verified egg instances**; no other addition, missing baseline part or replacement with the same total count is accepted. Sounds and particles must remain at baseline counts, every sound must be loaded, and physics debris must be zero.

The call then waits for the original model to disappear naturally, bounded by its actual `ExpiresAt + 1` deadline and a configuration bound of 30 seconds. It requires `RemovalReason == 'expired'`, cleared owner/drop state and an empty egg folder. The final scene must contain exactly the original baseline parts, sounds and particles, with every sound loaded and no physics debris. No Reset, Destroy, collection, forced expiry, camera change or egg exclusion is performed after destruction.

Diagnostics record before/five-second/final counts and times, completed cycles, egg identity/owner/lifetime, removal reason and part-set differences. Counts are exhaustive; added/missing name lists are capped at 12 each. References stay local to this single server call. The final call timeout is 60 seconds; overall flow cleanup remains the existing stop-play action.

## Offline evidence

Command:

```powershell
node work/automation/scripts/reduced-motion-scene-contract.mjs
```

**PASS:** 12 positive assertions, 18 rejected negative scenarios, four compiling behavioral weakening mutations and two structural mutation guards. All six actual flow Luau payloads compile with official Luau 0.737.

The contract executes the exact final flow against extracted production `PetDrops`, `makePart`/ball/cylinder helpers, `Spawn`, `Clear`, `tryDropPetEgg` and `BreakWallCycles` code. An independently controlled finite coroutine scheduler runs the real expiry loop. The depth-hit stub marks the real loop's block broken and calls the extracted contributor drop decision; this does not claim to test server damage physics. The source's actual contributor call and alias/snapshot routes are checked separately.

Negative cases include wrong real egg geometry, wrong owner, fake expiry metadata, persistent and late part leaks, late particle leakage, missing/replaced baseline parts with unchanged counts, unloaded audio, physics debris, early removal, incomplete cycles, live-data opt-in, writable profiles, invalid/nonfinite lifetimes, invalid owner cap and an expired model whose production Clear was suppressed. The last case reaches its bounded deadline and fails; it cannot hang indefinitely or be cleaned up by the fixture.

The four behavioral mutations remove part-identity, shape, owner or natural-expiry checks and are rejected by their matching negative oracles. Separate mutations attempting manual model destruction or weakening the original camera impulse gate are rejected by the flow-shape contract. All original camera and reduced-motion steps are compared directly with the immutable base flow, not inferred from new source markers.

`git diff --check`, allowed-path review and final compilation passed. The Coordinator must register `reduced-motion-scene-contract.mjs` in the shared offline registry during integration.

## Remaining gate

Actual Studio verification is **BLOCKED pending Coordinator integration and targeted execution** after the frozen run. The targeted result must identify the real spawned egg and show its natural expiry with exact final baseline restoration. No source bug, runtime pass, FPS change or final artifact claim is inferred from offline mocks or the historical count-only failure.
