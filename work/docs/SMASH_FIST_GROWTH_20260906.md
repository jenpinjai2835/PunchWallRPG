# Fist growth lifecycle repair — 2026-09-06

Base: `fd845d3`. Source-only handoff: `221b9f657671aaa785eff7923697ab9ec994935e`. Main-client ownership was returned to the Coordinator after that commit. This worker did not use Studio.

## Problem and change

Normal character appearance and the server's delayed PowerGrowth application can change hand dimensions after the fist is constructed. The old visual signature only contained equipment and character identity, so later refreshes could reuse a fist scaled to an earlier hand width. Replacing a hand with another instance of the same name and size could likewise leave the wrist welds attached to the old instance.

The client now observes actual `Size` changes on both R15 hands and both R6 arms. A 0.05-second pending window combines a burst of size events into one refresh; unchanged dimensions still exit through the existing signature cache. The signature includes both hands' dimensions, the character observation generation, and a hand-instance revision so equal-sized replacements cannot reuse old attachments.

Character child events support hands that arrive late or are replaced. CharacterRemoving and CharacterAdded disconnect the prior hand/character connections and invalidate queued work. Deferred callbacks verify the exact current observation state and current Player.Character before refreshing. Other body parts do not create size observers. Existing missing-hand retries are preserved.

The source change consists only of the observer/signature and lifecycle wiring. Animate, combat HUD, camera behavior, fist geometry, rewards, and purchases were not edited.

## Verification

- PASS: the entire main client compiles with official Luau 0.737.
- PASS: `node work/automation/scripts/fist-growth-lifecycle-contract.mjs` — 25 assertions execute the production observer functions, refresh/signature/build decision path, and CharacterAdded/CharacterRemoving callbacks with controlled instances, signals, and task scheduling.
- PASS: `node work/automation/scripts/fist-growth-lifecycle-contract.mjs --baseline fd845d3` reproduces both late-growth stale sizing and equal-sized hand replacement retaining the old attachment.
- Controls cover both hands, a hundred-event size burst, unchanged-size events, idle without rebuilds, idempotent binding, unrelated body parts, missing/late hands, hand replacement, pending old work during respawn, disconnected signals, manually delivered stale callbacks, late removal of an old character, and final teardown.
- PASS: unchanged camera/shop stability contract — seventeen behavior assertions.
- PASS: `git diff --check`.

The updated normal-respawn assertions in flow handoff `754c828` provide runtime coverage: they wait for real PowerGrowth completion and stable hand dimensions, then retain exact first-five geometry, measured scale, wrist bounds, weld endpoints, and saved fist identity. No forced refresh or re-equip is used to make those checks pass.

Actual Studio validation is **PENDING Coordinator integration and rerun**. The existing camera geometry contract's narrow lifecycle extraction boundary and mocks need the Coordinator's integration update for the newly added observer initialization/CharacterRemoving wiring; that separate check is not claimed as passing here. The growth contract supports `LUAU_COMMAND` and the discovered official temporary Luau toolchain.
