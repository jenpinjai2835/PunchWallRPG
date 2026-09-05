# Smash Wall server fixes — 6 September 2026

Agent HQ task `SMASH-20260906`, worker A1. Baseline `develop` at
`4094e51`; isolated branch `codex/fix/smash-server-20260906` in
`F:/Roblox/PuchWall-server-20260906`. Coordinator owns integration and
combined Studio regression. This worker handoff is eligible for integration;
it does not mark the overall request READY.

## Changes and acceptance

1. Coalesce ordinary stat changes into complete player snapshots on a fixed
   50 ms window. A destruction burst previously sent a full snapshot for
   every Coins/Score/XP/etc. update and another snapshot to every other player
   for every Score or Depth change. Each snapshot also rebuilt the leaderboard
   and included all item catalogs. The queue now emits once per pending player
   per window and builds the shared leaderboard once. Authoritative stat
   mutation remains synchronous. Initial load and explicit sync responses
   remain immediate; their complete payload shape remains compatible.
2. Keep the first scheduled deadline during continuing input. Retain mutations
   queued during a flush for a following window. Skip removed or unready
   profiles, and remove queued player references on PlayerRemoving.
3. Make Titan entry use the boss's declared `RequiredDepth`, with
   `GameConfig.WorldProgressTarget` as fallback. The declared depth was 75,
   but the old hit handler admitted Depth 30 and could grant final-boss coins
   and XP early. Depth 29, 30, and 74 now fail before health, participation,
   hit cooldown, contributions, or rewards change. Lv99 remains required.
4. Update the intentional legacy Honor test: two Depth-30 attempts must be
   rejected and preserve Coins, WallXP, Depth, and Honor. Previously this test
   permitted two early boss defeats while checking only the Honor/Depth gate.

The queue lives in the existing server `shared` namespace to avoid adding
another long-lived local register to the large bootstrap chunk. The initial
local-table implementation compiled at the default optimization but failed
the required `-O0` 200-register limit; the final implementation passes all
release optimization levels through the persistence contract.

`StatsSnapshotCount` on each player is a runtime observation counter used by
the new Studio flow. It does not alter persisted profile fields.

## Executed verification

Run from the isolated worktree:

```powershell
node work/automation/scripts/server-snapshot-coalescing-contract.mjs --luau-tool-dir 'C:/Users/Jennarong Pinjai/AppData/Local/Temp/codex-luau-smash-0.737'
node work/automation/scripts/persistence-contract.mjs --luau-tool-dir 'C:/Users/Jennarong Pinjai/AppData/Local/Temp/codex-luau-smash-0.737'
node work/automation/scripts/honor-progression-contract.mjs
node work/automation/scripts/long-run-content-contract.mjs
node work/automation/scripts/full-game-economy-boundaries-contract.mjs
node --check work/automation/scripts/server-snapshot-coalescing-contract.mjs
git diff --check
```

- Production Luau queue and complete `syncStats` function extracted and
  executed with deterministic scheduler, players, transport, and catalog mocks:
  **16/16 assertions passed**. Covers 480-update bursts, two contributors,
  one leaderboard build, continuously arriving changes, mutation during a
  flush, immediate explicit sync, removal, readiness failure, and recovery.
- The entire production `hitBoss` function extracted and executed with combat
  mocks: **17/17 assertions passed**. Covers Depth 0/29/30/74 rejection with
  no combat mutation, exact message and returned requirement, Lv98 rejection,
  Depth75/Lv99 success and contribution, configuration fallback, and a changed
  authoritative requirement.
- All **31 Luau snippets** in the two new flows and modified Honor flow parse
  and compile at `-O0`. This is syntax verification, not a Studio flow result.
- Persistence contract **31/31 passed**, including executable profile self-test,
  profile analysis, and source compile at all required optimization levels.
- Honor contract **19/19 passed**; long-run content **30/30 passed**;
  economy boundary contract **11/11 passed**.
- Node syntax and Git whitespace checks passed.

## Coordinator verification still required

Fresh Studio execution and combined regression are **pending Coordinator**.
The user opened Studio during this work; worker A1 did not operate that
shared session. Until these required checks pass, release verification is
BLOCKED and no FPS gain or overall game readiness is claimed.

Run after syncing integrated source:

- `server-snapshot-coalescing.json`: real Changed listeners, per-player
  transport count, full final state and catalogs received by the real client.
  Allows one additional idle one-second tick in the measurement window.
- `boss-depth-authority.json`: server boss rejection/success boundaries.
- Updated `honor-progression.json`, destruction/boss flows, authoritative HUD,
  fresh-player flow, training, persistence, and combined regression.

The change reduces redundant snapshots; catalogs still travel in complete
snapshots, and client rendering/physics costs still require separate work.
50 ms is the scheduled batching window, not a guaranteed wall-clock latency
under a stalled Roblox task scheduler.

## Unresolved audit findings outside this patch

**P1 candidate — shake/detach race.** `depthPunch.Shake` starts a CFrame tween
and delayed restore. `DropStructural` does not cancel that tween or invalidate
its ShakeToken, so an upper damaged cube that loses support within 100 ms can
be tweened toward its old grid location while detached. Reset invalidates a
future callback but does not cancel a restore already in flight. Source path
verified; runtime reproduction remains required. Reproduce by damaging an
upper cube, removing its support within 100 ms, and observing whether its
detached trajectory returns to the original grid. Fix should centralize
cancellation on detach, break, and reset.

**P1 candidate — reset during lunge.** `depthPunch.Lunge` tweens the character
root for 0.42 seconds. `resetWorldState` restores the wall and teleports the
character to spawn without cancelling that tween or invalidating punch
ownership. An in-flight tween can subsequently move the character toward its
old tunnel destination. Source path verified; runtime reproduction remains
required. Trigger reset during wind-up and during travel, then verify spawn
position, no solid-block overlap, collision group, and automatic ownership.

**Pacing concern, design decision required.** Current configured rewards sum
to 1,982,074,176 Coins for a perfect solo clear of all 5,400 blocks, while the
last regular fist costs 180,000,000,000,000 Coins. A deliberately optimistic
model of a perfect clear plus 15 instantaneous Titan wins every 300-second
cycle takes about 216.86 continuous days for that fist alone, ignoring other
spending and without coin boosts. This is a configuration-derived comparison,
not observed play time or a proof covering every earning route. Endgame costs,
earning loops, and desired milestones need a separate pacing pass.
