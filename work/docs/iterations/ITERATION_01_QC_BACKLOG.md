# Iteration 01 - Fresh QC And Backlog

Source under review:

- `F:\Roblox\PuchWall\outputs\PunchWallRPGPlayable_v1_final.rbxlx`
- Baseline SHA-256:
  `BF59059F1FBE58E4207B3B48CF4171DA9CC78416914B99829272428513960477`

## Audit Status

Fresh audit complete. The place was entered as a reset Level 1 player and
reviewed at spawn, training, the first wall, the Armory, DNA Lab, mobile menu,
wall lane, and Titan approach.

Captured Studio views:

- `iteration01_fresh_spawn`
- `iteration01_train_feedback`
- `iteration01_shop_lab`
- `iteration01_wall_lane_close`
- `iteration01_wall_break_feedback`
- `iteration01_boss_approach`
- `iteration01_menu`

## Findings

| ID | Priority | Fresh player finding | Required fix | Status |
| --- | --- | --- | --- | --- |
| I01-001 | P1 | DNA Lab and Rebirth instructions are drawn across large transparent hitboxes, creating floating oversized text and overlap from training/spawn sightlines. | Replace both with compact dedicated physical signs and keep interaction hitboxes text-free. | Closed |
| I01-002 | P1 | Mobile shows the objective in the top card and repeats it in a center context strip over the avatar. | Context strip should describe only a nearby actionable target; tutorial distance stays in the top objective card and world waypoint. | Closed |
| I01-003 | P1 | Normal walls have no persistent target HP/requirement/reward HUD, so repeated punching lacks readable progress. | Add a compact contextual wall HUD with HP bar, lock level, and reward summary. | Closed |
| I01-004 | P1 | Titan reads as a pair of vertical panels with a red strip, not a large boss landmark or contained kaiju-defense structure. | Build a stronger Titan HQ silhouette, energy core, crown/frame, warning beacons, arena markings, and clearer weak points. | Closed |
| I01-005 | P1 | The game has materials and models but no authored Kaiju City key art, warning poster, or in-world graphic identity. | Generate original Kaiju City Smash artwork with GPT image generation, upload it through Studio, and use it on world billboards. | Closed |
| I01-006 | P1 | The main menu is clean but entirely text-based; Fists/Pets/Tasks/Settings have no thematic visual anchor. | Add a generated-art banner/header without reducing list space or mobile readability. | Closed |
| I01-007 | P2 | The main road and wall lane remain visually empty between buildings, reading as a test lane. | Add restrained emergency barricades, impact/scorch markers, road closure props, and district dressing within the part budget. | Closed |
| I01-008 | P1 | At Level 1 the player still reads mostly as their normal avatar; the Kaiju fantasy begins too late and the Starter Gauntlet is easy to miss from behind. | Add a lightweight starter mutation silhouette and improve gauntlet visibility without hiding the avatar. | Closed |
| I01-009 | P1 | The repeated Brick objective says to earn Wall XP but does not estimate how many more breaks are needed. | Add dynamic remaining-XP and approximate-break guidance to tutorial data shown in the objective card. | Closed |
| I01-010 | P1 | A wall can disappear in one strong hit before a player visually reads impact, HP change, and collapse. | Add a short local hit flash/target pulse while preserving server authority and current respawn timing. | Closed |
| I01-011 | P2 | Boss and late-game surfaces use material contrast, but city districts lack consistent generated warning graphics tying them together. | Reuse the generated graphic in a limited billboard system with district-specific code overlays. | Closed |
| I01-012 | P0 | New UI, signs, boss visuals, generated assets, and scene-cost changes need repeatable regression coverage. | Record iteration-specific automation and rerun the complete matrix after fixes. | Closed |

## External Release Findings

These were reconfirmed but are not locally closable in this iteration:

- The place remains unpublished (`PlaceId=0`), so live DataStore and Analytics
  ingestion cannot be validated.
- Creator Dashboard icon/thumbnail/content metadata cannot be accepted from the
  local place alone.
- Real-device profiler capture still requires a published test session.

## Fix Status

All twelve locally actionable findings were implemented.

## AI Graphic Deliverables

Built-in GPT image generation produced original Kaiju City guardian key art.
The first destructive prompt was rejected by image safety; the accepted prompt
uses a heroic guardian and containment gate with no combat or damage.

Workspace files:

- `work/assets/generated/iteration-01/kaiju-city-guardian-master.png`
- `work/assets/generated/iteration-01/kaiju-city-billboard.png`
- `work/assets/generated/iteration-01/kaiju-city-billboard-spawn.png`
- `work/assets/generated/iteration-01/kaiju-city-menu-banner.png`
- `work/assets/generated/iteration-01/kaiju-guardian-icon.png`

Uploaded Roblox assets:

- Spawn billboard: `rbxassetid://125153703372122`
- District billboard: `rbxassetid://82590428870038`
- Menu banner: `rbxassetid://88173613852029`
- Guardian icon source: `rbxassetid://108499712320512`

World billboards use both Decal and SurfaceGui paths. Decal is the verified
fallback when Studio delays workspace ImageLabel loading.

## Re-QC Evidence

Implemented and reviewed.

Post-fix screenshots:

- `iteration01_after_spawn_final`
- `iteration01_after_menu_final`
- `iteration01_billboard_decal`
- `iteration01_after_titan_front`

Acceptance:

- Iteration-specific flow `iteration01-complete-polish`: passed.
- Complete automation matrix: 18/18 flows passed, `ok: true`.
- Console assertions: clean.
- Runtime core BaseParts: 1,417.
- iPhone 17 Pro menu retains a visible first inventory row below the generated
  banner.
- Spawn no longer shows wall HP or shop context until the player approaches an
  actionable target.

Finalized deliverable:

- Iteration snapshot:
  `F:\Roblox\PuchWall\outputs\iterations\PunchWallRPG_iteration01.rbxl`
- Current final:
  `F:\Roblox\PuchWall\outputs\PunchWallRPGPlayable_v1_final.rbxlx`
- Size: `186769` bytes
- SHA-256:
  `95750B661EBBCE80D85E72C8B304AF40427234A342A3AA84900E7B7DB0B1769A`
- Post-reopen iteration flow and smoke flow: passed.
