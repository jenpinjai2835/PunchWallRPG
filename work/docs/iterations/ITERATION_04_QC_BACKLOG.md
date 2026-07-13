# Iteration 04 - Fresh QC And Backlog

This iteration starts only after Iteration 03 passed 20/20 flows, was
serialized, closed, reopened, and passed post-reopen iteration plus smoke gates.

Source under review:

- `F:\Roblox\PuchWall\outputs\PunchWallRPGPlayable_v1_final.rbxlx`
- Baseline SHA-256:
  `9CB7E41D01B66D4D535A28FA1D22ED9101DF36960B4FAD88E10149D56C175EE0`

## Audit Status

Fresh gameplay inspection complete against the reopened Iteration 03 output.

Captured or measured evidence:

- `iteration04_hatch_three_menu`
- `iteration04_wall_lane_progression`
- `iteration04_armory_after_move`
- `iteration04_armory_player_view`
- Hatch x3 economy/inventory state probe
- Duplicate-pet lock UI probe
- Iron Wall and Titan HUD simultaneous-visibility probe

## Findings

| ID | Priority | Fresh player finding | Required fix | Status |
| --- | --- | --- | --- | --- |
| I04-001 | P0 | At Iron, Crystal, and Lava approaches, TargetWallHUD and BossHUD can both be visible at the exact same position because the 85-stud boss radius overlaps the regular wall lane. | Hide the boss panel while a regular target HUD or menu is active and reduce idle boss proximity to the actual encounter approach. | Closed |
| I04-002 | P1 | After Hatch x3 equips three pets, the stats panel says only `Pets: Miner Cat x3.05`, hiding that three companions are equipped and implying the multiplier comes from one pet. | Show equipped count plus combined multiplier in the compact stats summary. | Closed |
| I04-003 | P1 | Fist Mastery, Break Speed, and Crit Chance improve through gameplay/training but disappear after feedback fades; players cannot compare the value of Speed Dummy and Focus Stone training. | Add a compact Combat Profile row to the Fists tab with Power, mastery multiplier, break speed, and crit. | Closed |
| I04-004 | P1 | Train, shop, hatch, rebirth, requirement failures, and proximity failures send both Notify and Feedback for the same action, creating duplicate messages and unnecessary screen traffic. | Keep one feedback channel per action; reserve toast notifications for global/system or critical messages. | Closed |
| I04-005 | P1 | The remaining mobile toast holder occupies the same top-center region as Menu and combat UI. | Move compact toasts below the combat lane, constrain them to the center gap, and assert they do not overlap action controls. | Closed |
| I04-006 | P1 | The moved Armory is correctly separated but reads dark and generic; every display gauntlet uses the same hard-coded red instead of its tier color, and the world sign still says Click. | Generate original GPT Armory/gauntlet artwork, use it in Fists and the world sign, color each display from its catalog tier, improve emissive accents, and use input-neutral copy. | Closed |
| I04-007 | P1 | Duplicate pets are shown as indexed inventory rows, but locking one species name locks every duplicate row, so the action does not match the per-row UI. | Add backward-compatible slot lock tokens, send inventory index from UI, delete the selected slot, and shift slot locks after deletion while preserving legacy species locks. | Closed |
| I04-008 | P0 | Hatch x3, pet summary, per-slot lock/delete, Combat Profile, notification de-duplication, Armory identity, and HUD exclusivity lack one integrated regression. | Record a dedicated Iteration 04 flow covering all new contracts. | Closed |
| I04-009 | P0 | Shared pet inventory and feedback behavior changes can affect persistence, rebirth, and mobile interaction flows. | Rerun the complete matrix, serialize, reopen, and rerun iteration plus smoke gates. | Closed |
| I04-010 | P1 | Post-fix Armory screenshot from the spawn approach showed the unthemed Back face while generated art was only on Front. | Put the generated Armory surface and input-neutral overlay on both sign faces. | Closed |
| I04-011 | P1 | Stand name/cost labels faced away from the spawn approach, leaving only colored block silhouettes visible. | Render tier name/cost labels on both faces while keeping the interaction hitbox transparent. | Closed |
| I04-012 | P2 | Post-fix Armory screenshot showed the generated image compressed into a 22x3.2-stud strip, losing the five-tier artwork at player distance. | Enlarge and raise the existing sign to a 36x10-stud landmark without adding scene parts. | Closed |
| I04-013 | P2 | The older City Alert Billboard sat directly behind the enlarged Armory sign, appearing as a second unrelated image strip through the shop opening. | Move the existing city alert graphic behind the training district where its guidance belongs. | Closed |

## External Release Findings

- Published DataStore/Analytics and real-device profiler capture remain external.
- Creator Dashboard icon/thumbnail publication remains external.

## Fix Status

All 13 findings are closed. Gameplay balance was not changed.

## AI Graphic Deliverables

- Master: `work/assets/generated/iteration-04/kaiju-armory-master.png`
- Integrated banner: `work/assets/generated/iteration-04/kaiju-fist-armory-banner.png`
- Roblox image: `rbxassetid://105049638464832`
- Use: two-sided world Armory landmark and responsive Fists menu banner.

## Re-QC Evidence

- Dedicated flow: `iteration04-armory-pets-feedback` passed all 31 steps.
- Full matrix: 21/21 passed in 324.4 seconds; raw result is
  `work/automation/results/iteration04-full-matrix.json`.
- Player-view captures reviewed: `iteration04_after_armory_landmark` and
  `iteration04_armory_final`; the final capture has one readable Armory
  landmark and no duplicate City Alert strip.
- Final file saved, Studio closed, and the exact final file reopened.
- Post-reopen `iteration04-armory-pets-feedback` and `punchwall-smoke` passed.
- Snapshot: `outputs/iterations/PunchWallRPG_iteration04.rbxl`
- Final size: `1,399,208` bytes
- Final SHA-256:
  `FADE193B31772D36D8559A89A13A5E27B3696BDACBE6C49FF51C721477BC6AF1`
