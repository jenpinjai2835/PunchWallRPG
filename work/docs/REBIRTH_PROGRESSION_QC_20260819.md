# Rebirth Progression QC — 2026-08-19

## Outcome

The Rebirth button now uses one server-authoritative progression policy and a two-step `REVIEW` → `CONFIRM` interaction. The first activation cannot mutate progression. World shrine, HUD, keyboard/gamepad contextual use, and Tasks entry all converge on the same review screen; only a confirmed request may perform the reset.

## ScaledRebirthV1 policy

- Maximum Rebirths: `250`.
- Starting state after success: `Power 25`, `Coins 0`, `Wall Level 1`, `Wall XP 0`, `Starter Glove`, fist multiplier `1`, break speed `1`.
- Required level at current Rebirth count `R`: `min(99, 55 + 5 × floor(R / 5))`.
- Required Coins: `ceilTo1000(1,000,000 × 1.18^min(R, 50) × (1 + 0.08 × max(0, R - 50)))`.
- Permanent Power multiplier after `R` Rebirths: `1 + 0.25 × min(R, 250)`.

Representative boundaries:

| Current → next | Required Wall Lv | Required Coins | Multiplier after success |
|---|---:|---:|---:|
| 0 → 1 | 55 | 1,000,000 | 1.25x |
| 4 → 5 | 55 | 1,939,000 | 2.25x |
| 5 → 6 | 60 | 2,288,000 | 2.50x |
| 10 → 11 | 65 | 5,234,000 | 3.75x |
| 24 → 25 | 75 | 53,110,000 | 7.25x |
| 49 → 50 | 99 | 3,328,269,000 | 13.50x |
| 100 → 101 | 99 | 19,636,785,000 | 26.25x |
| 249 → 250 | 99 | 66,450,879,000 | 63.50x |
| 250 | — | — | MAXED |

## Reset and retain contract

Reset on success:

- Power, Coins, Wall Level, Wall XP.
- Equipped fist returns to Starter Glove; fist multiplier and break speed return to 1.
- Active training stops, its movement/tick state is cleared, and selected station returns to the rookie bag.

Retained:

- Depth and Score.
- Owned standard/premium fists; players may re-equip them after Rebirth.
- Pet inventory, discovered/locked/equipped state, pity, premium pets, and pet multiplier.
- Honor balance, relic ownership/equipment/bonus, milestone masks, and world-clear state.
- Mastery, crit chance, luck, daily/quest/playtime/spin state, boosts, settings, receipts, and session metadata.

## Authority and safety

- The client sends only `confirmed=true` plus the Rebirth count it reviewed. The server recalculates requirements and rejects stale confirmation, insufficient level/Coins, max count, non-writable profiles, and insufficient Honor milestone headroom.
- Honor reward and mask changes are atomic with the Rebirth reset; a full Honor balance rejects the whole operation instead of consuming the milestone.
- A per-player in-progress/cooldown gate prevents double submission.
- Successful Rebirth requests an immediate serialized persistence save.
- `CANCEL`, confirmation expiry, rejection, and repeated requests do not mutate progression.

## Verification

- Luau compile: GameConfig, server bootstrap, and client passed.
- Focused static contract: `19/19` passed.
- Focused Studio runtime flow: `42/42` labeled steps passed on exact Studio instance `6d29b2d4-41ab-41fb-838f-3dfd8727c725`, exact place, with clean runtime and post-stop console.
- The former desktop/phone screenshots under `work/docs/evidence/rebirth-20260819/` predate the standalone-window migration and are retained only as historical evidence. They are not current visual/input acceptance.
- Current standalone runtime evidence is `work/docs/evidence/standalone-windows-20260819/rebirth-progression-result.json`; current source/result hashes and Studio runtime fingerprints are recorded in `work/docs/evidence/standalone-windows-20260819/local-validation-summary.json`.
- Current real mouse/touch and screenshot acceptance remains blocked because Studio MCP `user_mouse_input` and `screen_capture` timed out. No physical-input or current visual PASS is claimed.

Evidence:

- `work/docs/evidence/standalone-windows-20260819/rebirth-progression-result.json`
- `work/docs/evidence/standalone-windows-20260819/standalone-player-windows-result.json`
- `work/docs/evidence/standalone-windows-20260819/local-validation-summary.json`

## External gate

The current Studio place is unpublished and explicitly runs in ephemeral-profile mode. The code and schema/runtime checks pass locally, but a true leave/rejoin DataStore durability check must still be run in a published private/UAT server before release. This external check is not represented as locally passed.
