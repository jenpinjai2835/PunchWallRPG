# Tutorial and Action Notification Badges QC — 2026-08-21

## Outcome

The new-player tutorial is now a short, server-authoritative three-action journey:

1. Follow the objective and punch a front wall block.
2. Open the Shop.
3. Buy the Street Boxing Fist for 180 Coins.

The tutorial closes only after the exact fist purchase succeeds. Completion is stored independently at tutorial policy version 2. Players who completed the legacy tutorial remain completed after DataVersion 8 migration; unfinished legacy tutorials restart at the new first step. A player who already owns the Boxing Glove is also treated as complete, preventing an impossible repeated tutorial.

Reusable red action dots now appear on:

- Pets — at least one exact unlocked pet fusion is available.
- Spin — a free-spin credit exists or the cooldown is ready.
- Shop — an unowned, Depth-unlocked Coin fist is affordable.
- Daily — daily login, quest, or playtime reward is claimable.
- Quests — quest or playtime reward is claimable.

Each dot is driven by current authoritative stats and disappears automatically when its action has been exhausted. It is visual-only (`Active=false`, `Selectable=false`) and cannot intercept player input.

## Validation

- Focused static contract: 22/22 PASS.
- Persistence executable contract: 29/29 PASS (`ContractVersion 2.3.0`, `DataVersion 8`).
- Honor product receipt regression: 14/14 PASS.
- Full non-Studio aggregate: PASS — Node 50, PowerShell 19, Luau 27/27, 116 flow JSON files, 27 non-Studio contracts.
- Fresh Studio runtime: 33/33 PASS on `PunchWallRPGPlayable_v1_final.rbxlx`.
- Runtime covered real production remote routes for Punch, Shop open, fist purchase, pet fusion, Spin, and quest claim.
- Boot, runtime, and post-stop consoles were clean.

Evidence: [capture-summary.json](evidence/tutorial-notification-badges-20260821/capture-summary.json) and [flow-result.json](evidence/tutorial-notification-badges-20260821/flow-result.json).

## Release boundary

This pass used an unpublished local Studio place (`placeId 0`). The DataVersion migration and persistence round trip are executable-contract tested, but a published leave/rejoin DataStore check remains a release/UAT gate. No publish was performed as part of this task.
