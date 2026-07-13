# Iteration 03 - Fresh QC And Backlog

This iteration starts only after Iteration 02 passed its complete automation
matrix, was serialized, closed, reopened, and passed post-reopen gates.

Source under review:

- `F:\Roblox\PuchWall\outputs\PunchWallRPGPlayable_v1_final.rbxlx`
- Baseline SHA-256:
  `F2282C79930274105EF3FCDF9B9118E14BF8A037508DF858383ECB04800A746B`

## Audit Status

Fresh player inspection complete against the reopened Iteration 02 deliverable.

Captured or measured views:

- `iteration03_fresh_spawn`
- `iteration03_wall_combat`
- `iteration03_fists_menu`
- `iteration03_wall_break`
- `iteration03_tasks_menu`
- `iteration03_boss_player_view`
- iPhone 17 Pro absolute GUI geometry and text-bound probes
- Settings touch-target probe
- Brick collapse runtime-state probe

## Findings

| ID | Priority | Fresh player finding | Required fix | Status |
| --- | --- | --- | --- | --- |
| I03-001 | P0 | On the iPhone simulator, the current DeviceSafeInsets plus FullscreenExtension combination produces negative absolute Y positions: Stats, Objective, Boss HUD, and Game Menu begin at y=-50. The boss HUD is effectively offscreen. | Use the recommended CoreUISafeInsets contract and disable legacy fullscreen compatibility transforms; assert all important UI starts inside the safe content area. | Closed |
| I03-002 | P1 | Mobile boss title text is 298px wide inside a 260px box, and the wall target HUD sits against/under the stats panel. | Add compact mobile boss copy, place combat HUDs in one safe lane below the top row, and assert text bounds and panel rectangles do not overlap. | Closed |
| I03-003 | P1 | At the Brick Apartments approach, the Titan Gauntlet Stand at x=-9 is closer than the wall center and steals the context label/highlight. End-game shop presentation intrudes into the first combat encounter. | Move the four Armory stands deeper into the Armory footprint and explicitly prioritize a live wall inside combat range over unrelated interactables. | Closed |
| I03-004 | P1 | Fist, hatch, motion, sound, and scale controls are 36px tall; menu tabs are 38px and the close button is 36px. These are below a dependable mobile touch target. | Standardize interactive menu controls, tabs, close, and compact Menu button to at least 44px without clipping rows. | Closed |
| I03-005 | P1 | Tasks and Settings still reuse the generic guardian banner and do not visually communicate mission tracking or control/accessibility settings. | Generate original GPT Kaiju City mission-control artwork and integrate distinct Tasks and Settings banner crops. | Closed |
| I03-006 | P1 | A broken regular wall keeps ordinary HP/reward wording and provides no reconstruction countdown. | Replicate a regular-wall RespawnAt timestamp and show REBUILDING with a live countdown in the target HUD. | Closed |
| I03-007 | P1 | Collapse chunks begin at 0.08 transparency in a facade-like grid; from normal view they briefly read as an intact opaque block still in front of the player. | Start chunks partially transparent, scatter/drop them more decisively, and stop targeting a wall once it is broken. | Closed |
| I03-008 | P2 | Context and target ownership are derived from one nearest-object pass, so an interaction hitbox can override the combat target even while the wall HUD is visible. | Split focused-wall ownership from nearest-use ownership and suppress the context strip while a live wall is focused. | Closed |
| I03-009 | P0 | No dedicated regression verifies safe-area geometry, compact text bounds, 44px menu targets, Armory separation, regular-wall rebuild state, or collapse readability. | Record an Iteration 03 flow with server/client geometry and state assertions. | Closed |
| I03-010 | P0 | This iteration changes shared HUD geometry and destruction state used by every progression tier. | Rerun the complete matrix, serialize the final DataModel, reopen it, and rerun iteration plus smoke gates. | Closed |
| I03-011 | P1 | Post-fix iPhone screenshot showed the newly safe-positioned Menu button covering Train, while the boss HUD touched Punch by 2px. | Put Menu in the unused top-center gap and constrain the combat lane between Stats and action controls with positive spacing. | Closed |
| I03-012 | P1 | Post-fix wall-break screenshot showed Level Up toast, Break toast, and Reward pop stacked over one another and the combat view. | Remove notification duplicates when a feedback event already exists and arrange simultaneous reward pops in a deterministic lower-center stack. | Closed |

## External Release Findings

- Published DataStore/Analytics and real-device profiler capture remain external.
- Creator Dashboard icon/thumbnail publication remains external.

## Fix Status

All twelve locally actionable findings, including two issues discovered during
post-fix screenshot review, were implemented.

## AI Graphic Deliverables

Built-in GPT image generation produced an original panoramic Kaiju City mission
control room with realistic concrete, steel, glass, city-map, reward-crate, and
accessibility-console details.

Workspace files:

- `work/assets/generated/iteration-03/kaiju-mission-control-master.png`
- `work/assets/generated/iteration-03/kaiju-tasks-banner.png`
- `work/assets/generated/iteration-03/kaiju-settings-banner.png`

Uploaded Roblox assets:

- Tasks banner: `rbxassetid://134754597904456`
- Settings banner: `rbxassetid://79786692712597`

## Re-QC Evidence

Post-fix player views:

- `iteration03_after_safe_spawn`
- `iteration03_after_tasks_banner`
- `iteration03_after_settings_banner`
- `iteration03_after_collapse_scatter`
- `iteration03_after_safe_boss`
- `iteration03_after_feedback_stack`

Acceptance:

- Iteration-specific flow `iteration03-safearea-destruction`: passed all 20
  recorded checks.
- Complete automation matrix: 20/20 flows passed in 307.7 seconds.
- Raw matrix result:
  `work/automation/results/iteration03-full-matrix.json`
- Runtime console assertions: clean.
- Runtime core BaseParts: 1,417.
- All important mobile UI has non-negative safe-area positions.
- Menu controls are at least 44px tall; compact boss title/subtitle fit bounds.
- Combat lane has positive clearance from Stats, Objective, Menu, and mobile
  action controls.
- Regular wall collapse, countdown, reconstruction, and reward-stack checks pass.
- Saved final was closed, reopened, and passed iteration plus smoke gates.

Finalized deliverable:

- Iteration snapshot:
  `F:\Roblox\PuchWall\outputs\iterations\PunchWallRPG_iteration03.rbxl`
- Current final:
  `F:\Roblox\PuchWall\outputs\PunchWallRPGPlayable_v1_final.rbxlx`
- Size: `1398470` bytes
- SHA-256:
  `9CB7E41D01B66D4D535A28FA1D22ED9101DF36960B4FAD88E10149D56C175EE0`
