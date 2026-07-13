# QC Polish Report

Date: 2026-07-11

## Free-Aim Forest Wall Revision - 2026-07-12

- Removed all runtime block Highlights, target lock references, and the regular block HP HUD.
- Reduced radial punch range from 6.5 to 3.25 studs and capped one punch at eight blocks.
- Rebuilt the excavation volume as 2,700 cubic `4 x 4 x 4` blocks while preserving the `48 x 12 x 300` field dimensions.
- Wall destruction now ejects ten fragments from the open face at high velocity; surviving blocks retain the elastic hit shake.
- Punch feedback uses one reusable audio channel, preventing stacked impact sounds from radial hits.
- Added a 0.72-second exaggerated wind-up, strike, follow-through, and recovery pose without changing character facing.
- Removed generated city buildings, curated skyline/landmark models, plaza pavers, checkpoint floor overlays, and lane-paint overlays from runtime.
- Wall rewards no longer increase Power or Fist Mastery. Coins, Score, Wall XP, and Depth progression remain.
- Added free APMOfficial background music and constrained HUD value text to avoid the lightning, plus, and wall artwork.
- New automation: `punchwall-free-aim-combat-polish.json`; focused regression flows pass with a clean console.

## Hybrid Physics And Hero Lunge - 2026-07-12

- Added a server-authoritative 0.2-second wind-up and clearance-aware 10.5-stud forward lunge while preserving body-facing free aim.
- Added a localized structural support solver: adjacent missing base blocks can release upper rows into server-owned physics.
- Limited active structural simulation to 60 blocks. Settled detached blocks now remain visible, unanchored, collidable, queryable, and at their natural physics positions with 35% HP.
- Detached rubble receives a fresh server-authoritative launch velocity when punched and disappears only after a finishing punch reduces its remaining HP to zero.
- Split destruction into four replicated server chunks plus eight local non-colliding shards per client.
- Added a readable `STRUCTURE COLLAPSE!` feedback event with collapse audio and haptics.
- `punchwall-hybrid-physics-lunge.json`, free-aim, shared-field, radius/shake, and mobile regressions pass with a clean console.

## Summary

Reworked the visual direction from Cute Low-Poly to Kaiju City Smash after screenshot QC. The map now reads as a downtown destruction lane: asphalt roads, concrete sidewalks, crosswalks, city skyline, facade window textures, smashable building walls, rubble, industrial shop, DNA pet lab, and Titan HQ boss tower.

Iteration 02 added a dedicated generated DNA-companion art set, reduced and
refined procedural pet silhouettes, a tapered starter mutation, per-tab menu
art, estimated wall hits, task readiness states, and a visible Titan shockwave
countdown with weak-point feedback. Mobile screenshot QC also found and fixed an
unstable tab order before the iteration was accepted.

Iteration 03 repaired the mobile safe-area contract, constrained combat HUDs
between top/status and action controls, standardized 44px menu targets, moved
the Armory out of the Brick encounter, added regular-wall rebuild countdowns,
improved collapse scatter, stacked simultaneous rewards, and added generated
mission-control art for Tasks and Settings.

Iteration 04 made the Armory a readable generated-art landmark, exposed a
compact combat profile, corrected multi-pet summary and per-slot duplicate-pet
actions, removed duplicate feedback channels, separated regular and Titan HUDs,
and moved mobile toasts out of the combat-control lane. Post-fix visual review
also caught and fixed the missing back face, reversed stand labels, compressed
banner scale, and an unrelated billboard visible through the Armory.

Second QC loop note: after gameplay screenshots still showed toy/clay-like buildings, the wall lane was upgraded again with real 3D facade depth: glass panes, mullions, floor ledges, window sills, roof parapets, entrance awnings, AC units, and fire-escape detail parts on both visible sides of each smashable building.

## Implemented

| Area | Result |
| --- | --- |
| Art direction | `PolishConfig.StyleName` changed to `Kaiju City Smash` |
| Creator Store candidates | Researched and documented free city/destroyed-building assets with script status |
| Asset safety | Added optional runtime visual-only InsertService sanitizer for selected city assets |
| Lighting | Replaced pastel lighting with `Kaiju City Bloom`, `Kaiju City Color`, and `Kaiju City Atmosphere` |
| Spawn/readability | Replaced green island with asphalt city block, helipad spawn, crosswalk, road arrows, and alert billboard |
| City environment | Added source-built skyline buildings, street lights, road markings, concrete sidewalks, bank coin stack, rubble piles |
| Wall lane | Converted walls into smashable city buildings with facade window grids, concrete/metal/glass materials, foundations, debris, and cracks |
| Wall lane pass 2 | Added 1,000+ 3D facade detail parts so walls no longer read as flat colored blocks |
| Boss | Converted Titan wall into Titan HQ boss tower with facade windows, rooftop core, antenna, emergency glow, and plaza rubble |
| Training | Changed stations to city gym/military training props with mats, heavy bag, dummy, and cracked concrete |
| Shop | Changed fist shop into City Fist Armory with steel roof, warning stripe, metal stands, and gauntlet displays |
| Pet egg | Changed pet machine into Kaiju DNA Lab with glass containment tube and sample tank |
| Rebirth | Changed shrine into Evac Portal |
| UI/HUD | Updated title and help copy to Kaiju City Smash while preserving mobile button sizing |
| Automation | Updated visual polish smoke flow to assert Kaiju lighting, city decor, facade textures, and HUD title |

## Screenshot Audit

Previous screenshots showed the Cute Low-Poly pass was too toy-like. A second screenshot pass showed the first Kaiju City version still looked like flat clay blocks. The current implementation directly addresses those findings by removing pastel wall slabs, green base dominance, clouds, low-poly awning, cute egg capsule styling, and flat 2D-only facade grids.

Existing screenshot folder:

- `F:\Roblox\PuchWall\work\docs\qc-screenshots`

Kaiju City screenshot passes:

- Baseline before depth fix: `F:\Roblox\PuchWall\work\docs\qc-screenshots\kaiju-city-baseline`
- After facade depth pass 1: `F:\Roblox\PuchWall\work\docs\qc-screenshots\kaiju-city-after-pass-1`
- After two-sided facade depth pass 2: `F:\Roblox\PuchWall\work\docs\qc-screenshots\kaiju-city-after-pass-2`
- Final QC screenshots: `F:\Roblox\PuchWall\work\docs\qc-screenshots\kaiju-city-final-qc`

Player-view assessment:

- Baseline: Failed. Buildings still looked like toy/clay blocks because they were mostly flat boxes with square window graphics.
- After pass 2: Passed for playable prototype quality. Buildings read as city blocks with visible depth, materials, glass, ledges, and progression.
- Remaining P2: first-screen shop/armory area can still be refined further, but it is no longer the main quality blocker.

## Findings

| Priority | Finding | Status |
| --- | --- | --- |
| P0 | Gameplay automation regression after theme change | Closed: all 9 flows pass |
| P0 | Console/runtime errors from new materials or facade UI | Closed: visual flow console clean |
| P1 | Cute Low-Poly looked too much like toy/clay and did not match requested quality | Fixed with Kaiju City Smash art pass |
| P1 | Wall lane needed real texture/readability, not flat pastel blocks | Fixed with facade window grids, concrete/metal/glass materials, foundations, and rubble |
| P1 | First Kaiju pass still read like clay boxes in player screenshots | Fixed with two-sided 3D facade detail pass |
| P1 | Need model-library direction while keeping scripts out | Addressed with researched Creator Store candidates and runtime visual sanitizer |
| P2 | Runtime Creator Store inserts did not appear as guaranteed kept assets in final local test | Closed: 3 sanitized packs are embedded in the final file |
| P2 | Optional inserted city assets should be manually screenshot-reviewed if Roblox loads them in a published experience | Closed for embedded assets; runtime insertion remains fallback-only |
| P2 | Add sound cues for kaiju smash, concrete crack, building collapse, and city alarm | Closed: 15/15 runtime sounds load in local QC |

## Automation Result

Command:

```powershell
powershell -ExecutionPolicy Bypass -File "F:\Roblox\PuchWall\work\automation\run-existing-flows.ps1"
```

Latest final-file result: `ok: true`

| Flow | Status |
| --- | --- |
| `punchwall-map-progression` | Pass |
| `punchwall-mobile-controls` | Pass |
| `punchwall-motion-feedback` | Pass |
| `punchwall-player-state` | Pass |
| `punchwall-rebirth-boss` | Pass |
| `punchwall-shop-and-pet` | Pass |
| `punchwall-smoke` | Pass |
| `punchwall-train-and-break` | Pass |
| `punchwall-visual-polish-smoke` | Pass |
| `natural-progression` | Pass |
| `luck-distribution` | Pass |
| `inventory-persistence` | Pass |
| `responsive-ui-inputs` | Pass |
| `destruction-boss-phases` | Pass |

## Remaining Recommendations

- Run a human screenshot review in Studio viewport for spawn, wall lane, shop/lab, and boss after any Creator Store asset loads successfully.
- Validate current free audio permissions again after publication.
- Consider manually importing `City Building Pack` pieces only after selecting a small subset, because the full asset is very heavy.

## Game Completion QC Pass

Completion work replaced the prototype-only loop with a playable simulator loop:

- Repeatable Wall XP removes the Level 2 progression lock and supports natural unlocks through Cyber and Rebirth.
- Luck now uses weighted rarity curves; Rare-or-better and Secret outcomes improve as Luck rises.
- Fists have ownership, equip state, character gauntlets, punch motion, trails, shop UI, and Rebirth persistence.
- Pets have inventory, multi-equip, lock/delete, index, rarity probabilities, multi-hatch hooks, and client companions.
- Walls use contribution rewards, staged cracks, collapse chunks, world damage numbers, audio, and reconstruction.
- Titan has contribution-gated rewards, participant scaling, phases, three weak points, a shockwave telegraph, health HUD, and respawn timer.
- HUD now respects mobile safe areas and supports keyboard, touch, and gamepad actions.

Screenshot review folders:

- `game-completion-pass-1`: baseline after systems; failed art review for large hitboxes and blocked sightlines.
- `game-completion-pass-2`: hitboxes/signage/foundation corrected; failed camera coverage for Shop and Titan.
- `game-completion-pass-3`: accepted local prototype presentation with skyline, unobstructed Shop/DNA/Titan views, responsive HUD, and curated textured assets.

Mobile screenshots were reviewed on Samsung Galaxy S25 Ultra (`685x338` viewport) and iPhone 17 Pro (`750x361` viewport). Gameplay controls no longer overlap Roblox movement/jump controls, and the modal menu stays above the Core control region.

Performance composition changed from 2,073 runtime BaseParts / 525 Glass parts to 1,372 runtime BaseParts / 292 Glass parts. Streaming is enabled. The curated Edit-mode asset folder contributes 49 sanitized MeshParts.

The only release-blocked checks are Creator Dashboard publication, live DataStore/Analytics ingestion, icon/thumbnail metadata, and a profiler capture on a published low-end device session.

## Five-Pass Final Acceptance

The earlier topic-based five-pass acceptance below is retained as historical
evidence and is superseded by `ITERATIVE_POLISH_5X.md`, where every iteration
repeats the complete audit/fix/graphic/re-QC instruction. Its findings included two startup races
(RemoteEvent replacement and early gauntlet signature commit), contradictory
spawn guidance, incomplete reduced-motion behavior, and overlapping training
signage on iPhone. All were fixed and reproduced with targeted tests before the
full matrix rerun.

Final visual composition:

- 3 embedded sanitized Creator Store packs
- 161 curated visual parts and 49 MeshParts
- 12 embedded AI-generated MaterialVariants
- 357 damaged-concrete, 3 worn-asphalt, and 163 containment-metal applications
- 1,378 core runtime BaseParts, 292 glass parts, 26 particle emitters, 15 loaded
  sounds, 2 lights, and Streaming enabled
- 0 LuaSourceContainer descendants in curated assets

Final screenshot review:

- Desktop spawn: textured asphalt/concrete, readable Armory landmark, no clay
  surface presentation.
- iPhone 17 Pro landscape: safe-area HUD and 92x46 action buttons do not overlap
  Roblox movement/jump controls.
- Training view: compact dedicated signs replace overlapping hitbox text.
- Wall lane and Titan: progression silhouettes remain readable with mobile HUD.

Final automation result after the visual sign fix: **17/17 flows passed** with
`ok: true` and clean console assertions.

The final AutoRecovery snapshot was copied to the delivery path, Studio was
closed and reopened from that exact file, and the smoke, reduced-motion/
performance, and responsive startup gates all passed again. Final SHA-256:
`BF59059F1FBE58E4207B3B48CF4171DA9CC78416914B99829272428513960477`.
## Full Iteration 01

The first complete repeat of the user-requested audit/fix/graphic/re-QC process
is logged in `docs/iterations/ITERATION_01_QC_BACKLOG.md`.

- 12 fresh findings recorded and closed.
- Original GPT-generated Kaiju City guardian art integrated into world
  billboards and the mobile/desktop menu.
- Normal wall HUD, compact DNA/Rebirth signs, starter mutation, Titan landmark,
  road dressing, dynamic break estimate, and hit flash added.
- Player-view QC required two follow-up adjustments: mobile menu banner height
  and mirrored/Decal world billboard fallback.
- Full result: 18/18 automation flows pass.

## Full Iteration 04

- 13 fresh and post-fix findings recorded and closed in
  `docs/iterations/ITERATION_04_QC_BACKLOG.md`.
- Original generated Armory artwork integrated on both world-sign faces and in
  the Fists menu as `rbxassetid://105049638464832`.
- Dedicated Iteration 04 flow passed all 31 steps.
- Complete current matrix passed 21/21 with clean console gates.
- Serialized final was closed, reopened, and passed Iteration 04 plus smoke.
- Snapshot: `outputs/iterations/PunchWallRPG_iteration04.rbxl`
- SHA-256:
  `FADE193B31772D36D8559A89A13A5E27B3696BDACBE6C49FF51C721477BC6AF1`

## Full Iteration 05 And Final Acceptance

- 12 fresh and post-fix findings recorded and closed in
  `docs/iterations/ITERATION_05_QC_BACKLOG.md`.
- Mobile status reduced to the three combat essentials while desktop retains
  the complete six-line panel.
- Regular buildings received break-linked rear mass and roofs without changing
  combat hitboxes; Titan received a 22-stud deep core and structural ribs.
- Original Titan containment artwork integrated as
  `rbxassetid://93552182756522` on the HQ header and BossHUD.
- Objective progress, fixed Armory nameplates, and reduced-motion-aware ambient
  containment pulses were added.
- Automated final screenshot QC produced 11 world/UI images with all four menu
  tabs visible and clean console output.
- Dedicated Iteration 05 flow passed all 12 checks.
- Complete final matrix passed 22/22 in one run.
- A post-acceptance character-motion patch replaced the ineffective
  single-Motor6D tween with a full procedural punch pose applied in
  `PreSimulation`. It supports modern `AnimationConstraint` avatars, legacy
  R15 `Motor6D`, and R6, while Reduced Motion disables the pose.
- New `punch-character-motion` automation measured real shoulder rotation and
  forward reach, then passed with motion/mobile/reduced-motion/smoke
  regressions and post-reopen motion plus smoke gates.
- Serialized final was closed, reopened, source-audited, and passed Iteration 05
  plus smoke gates.
- Delivery: `outputs/PunchWallRPGPlayable_v1_final.rbxlx`
- Snapshot: `outputs/iterations/PunchWallRPG_iteration05.rbxl`
- Final SHA-256:
  `88F4F78E6D2EB1E54392E57C934FBFB0019BDADE37839E665C6136FEA322B208`

## Original Avatar, Fist Items, and Icon UI Acceptance

- Restored the player's original Roblox avatar as the permanent character
  base. Removed mutation spines and tail equipment from fist progression.
- Rebuilt all five levels as recognizable closed-fist items with unique color,
  material, accent core, display name, tier, and icon identity. No fist uses a
  blade or WedgePart silhouette.
- Kept legacy internal keys (`Starter Glove`, `Boxing Glove`, and so on) so
  existing player data remains compatible while the HUD and shop display the
  new names.
- Added a project-original 4x4 icon atlas, published as
  `rbxassetid://134314320646796`, across status, actions, targets, menu tabs,
  shop items, tasks, notifications, and feedback.
- Verified the economy loop: starter is owned at no cost, building rewards
  remain active, and buying Street Boxing Fist for 180 coins immediately equips
  Tier 2 and updates its HUD icon.
- Added `fist-items-icon-ui` and revised affected historic flows to assert the
  current product contract across desktop and compact/touch layouts.
- Captured 11 mobile and 11 desktop QC views under
  `docs/qc-screenshots/fist-item-icon-ui-mobile` and
  `docs/qc-screenshots/fist-item-icon-ui-desktop`.
- Final pre-serialization matrix: 24/24 flows passed in one run with clean
  console gates and overall `ok: true` on 2026-07-12.
- The source-first serializer embedded all four current scripts into the final
  place with exact source equality. A newly opened Studio process passed
  `fist-items-icon-ui` and `punchwall-smoke` from that file.
- Delivery: `outputs/PunchWallRPGPlayable_v1_final.rbxlx`
- Snapshot: `outputs/iterations/PunchWallRPG_fist_item_icon_ui_final.rbxlx`
- Final SHA-256:
  `4A92B896CA4E82D1E5198AEDFED78F2CB9B2FD30BA1D3145656B008CAD4AD92B`

## Hero City Theme Conversion

- Locked the game-wide direction to Hero City: a child-friendly Roblox
  simulator with shonen anime action styling, without photorealism or an
  overly sweet palette.
- Replaced the prior theme contract with red action, cyan energy, yellow
  reward/navigation, dark ink panels, and warm-white text.
- Updated world lighting, atmosphere, skyline windows, spawn, roads, signs,
  Armory, Sidekick Lab, Titan raid, Rebirth gate, HUD typography, menu language,
  and feedback accents while preserving gameplay and saved-data keys.
- Desktop and mobile screenshot passes produced 11 views each under
  `docs/qc-screenshots/hero-city-desktop` and
  `docs/qc-screenshots/hero-city-mobile`.
- Visual QC caught and fixed a responsive title override and removed facade-
  occluded boss text before regression.
- Added `hero-city-theme`; the complete matrix passed 25/25 flows with overall
  `ok: true`, 1,437 BaseParts, and clean console gates.
- Serialized delivery was reopened in a new Studio process and passed Hero City
  plus smoke gates again.
- Snapshot: `outputs/iterations/PunchWallRPG_hero_city_final.rbxlx`
- Final SHA-256:
  `1FA4F334606CF023C1F839A6488B77A74F29193CB0507D4148627A56DC7141F0`

## User-Supplied Hero City HUD And Shop Art

- Uploaded the exact 677x408 user-supplied reference as
  `rbxassetid://104014193600358`.
- Replaced the generated 4x4 runtime atlas with pixel-accurate non-uniform crop
  regions from the supplied image.
- Applied the image to status, mobile actions, objective, target, tabs,
  settings, feedback, fist tiers, two-sided Armory nameplates, the Fist Shop
  header, and the full world shop billboard.
- Cropped Menu and Settings to symbol-only glyphs so embedded source labels do
  not conflict with live UI text.
- Captured complete mobile and desktop QC passes under
  `docs/qc-screenshots/hero-city-reference-ui-mobile` and
  `docs/qc-screenshots/hero-city-reference-ui-desktop`.
- Added `hero-city-reference-ui`; the full matrix passed 26/26 flows with
  overall `ok: true` and clean console gates.
- Serialized delivery was opened in a new Studio process and passed supplied-
  reference UI plus smoke gates again.
- Snapshot:
  `outputs/iterations/PunchWallRPG_hero_city_reference_ui_final.rbxlx`
- Final SHA-256:
  `7DDB9FCE4111415C22B41768D8AD0F6868C5FDB4B645C3294F3B9238615EC51B`
# Depth Corridor Conversion QC - 2026-07-12

## Implemented

- Replaced the lateral wall lineup with a ten-gate run from Z `-27` to Z `-450` and Titan at Z `-515`.
- Added sequential Level + Depth gates, persistent Depth and Score, named ranks, exact server placement, Top 3 HUD, checkpoint arches, and guide lights.
- Preserved the Training Area, fist shop, pets, rebirth, and existing Hero City HUD/mobile controls.
- Regular wall destruction now opens the center masonry, disables root collision, hides rear building mass and wall labels, leaves perimeter rubble, then rebuilds after 8 seconds.
- Titan requires Level 99 + Depth 10 and awards Depth 11.

## Defects Found And Fixed During Real Play

- Client failed to compile from exceeding 200 local registers after adding rank widgets. Rank widget construction is now scoped and keeps one persistent table reference.
- Titan automation reset silently restored old 5M HP. Reset now uses the shared 800M boss constant.
- Checkpoint header neon bloomed into a large white bar. The structural header is now dark metal with a thin neon accent.
- Rear building mass remained visually opaque after a breach. Break-linked depth geometry is now fully hidden while broken.
- Wall SurfaceGui/BillboardGui remained visible through transparent broken walls. Labels are disabled while broken and restored on rebuild/reset.

## Verification

- `punchwall-smoke`: pass, console clean.
- `punchwall-depth-corridor`: pass, including ten ordered gates, no depth skipping, mixed visible/hidden rubble, passable root wall, Depth 2, Score 620, Rank HUD, Top 3, and console clean.
- `punchwall-map-progression`: pass.
- `punchwall-train-and-break`: pass.
- `punchwall-mobile-controls`: pass.
- `punchwall-rebirth-boss`: pass after shared boss HP reset fix.

## Visual QC Notes

- Entrance capture verified Hero City HUD, Depth/Score rank panel, gate level/HP, mobile joystick, punch, jump, and side menus together in a live play viewport.
- The first visual pass exposed checkpoint bloom and the rear-mass camera obstruction; both were corrected in source and regression-tested.
- A later MCP screenshot request hung after a second Studio instance connected. It was terminated without modifying game state; geometry assertions remain the acceptance source for the breach opening.

## Top HUD Safe-Area Polish (2026-07-13)

- Reduced Power, Coins, and Wall value text constraints from 40 px to 30 px maximum while retaining automatic scaling for long values.
- Tightened each value mask so it ends before the Power lightning, Coins plus button, and Wall card right-side artwork.
- Added a subtle dark horizontal mask gradient to blend the dynamic value area into the source card artwork.
- Stress-tested `987.7M` Power/Coins and `10.0K` Wall Level on an iPhone 17 Pro landscape viewport; all text bounds remained inside their labels.
- Updated `punchwall-free-aim-combat-polish` with `hudSafe: true` geometry assertions; flow passed with a clean console.

## Power-Scaled Penetration (2026-07-13)

- Locked client hold cadence and server wall-hit cooldown to exactly 1 second; `BreakSpeed` no longer shortens attack cadence.
- Added a logarithmic Power profile: starter Power uses a 10.5-stud lunge, scaling to a capped 48-stud lunge at very high Power.
- Replaced single-impact damage with a forward swept-volume trace. Damage, penetration limit, fragment impulse, and detached-block bounce force now scale with Power and decay along the travel path.
- Locked-level blocks stop the lunge, preventing players from bypassing progression gates.
- Broken blocks spawn six server-owned collidable chunks using `ApplyImpulse`/`ApplyAngularImpulse`; total live server fragments are capped at 120 and expire after 4.5 seconds.
- Starter QC: Power 15 lunged 10.5 studs, hit 3-4 nearby blocks, and broke the front block.
- High-Power QC: Power 1.5B lunged 48 studs, carved 40-48 blocks, produced 120 server-owned fragments, and reached measured fragment speed above 70 studs/second.
- Visual capture confirmed a deep central tunnel with persistent structural rubble on the sides.
- Passing flows: `power-scaled-penetration`, `punchwall-hybrid-physics-lunge`, `punchwall-free-aim-combat-polish`, and `punchwall-mobile-controls`; console clean.

## Tunnel Camera Zoom Preservation (2026-07-13)

- Changed player camera occlusion from Roblox `Zoom` to `Invisicam` through `StarterPlayer` and per-player server initialization.
- Preserved `CameraType.Custom` and left `CameraMinZoomDistance`/`CameraMaxZoomDistance` untouched so each player keeps full manual zoom control.
- When a tunnel wall blocks the view, the wall now becomes locally transparent instead of forcing the camera toward the character.
- Automated enclosure test held the selected camera distance at 14.0000 studs before and after occlusion (0-stud difference) while applying 0.75 local obstruction transparency.
- Added and passed `camera-tunnel-zoom-preservation`; console clean.

## Punch Collision Recovery (2026-07-13)

- Added a post-damage safe-landing resolver for every depth-block lunge.
- The resolver checks a character-sized collision box against unbroken collidable depth blocks, then searches backward along the punch path in 0.5-stud steps.
- If the punch started while already embedded, recovery can search up to 8 studs behind the start; a course-entrance fallback remains available if no nearby point is clear.
- Recovery clears linear/angular velocity, disables Sit/PlatformStand, and restores the Humanoid to `Running`.
- Reproduction QC used Power 1 from 2 studs in front of an intact wall: raw lunge 10.5 studs, safe travel 0.5 studs, final blocking overlap 0, velocity 0, state Running.
- High-Power penetration still travels more than 35 studs but now stops at the deepest clear position instead of embedding at the requested 48-stud endpoint.
- Added and passed `punch-collision-recovery`; `power-scaled-penetration` and `punchwall-hybrid-physics-lunge` also pass with clean consoles.

## Preflight Lunge Planning (2026-07-13)

- Replaced normal post-lunge rollback with a preflight pass before every punch lunge.
- The server predicts non-critical damage, falloff, penetration limit, level gates, and the character-sized corridor. The lunge endpoint is set before the Tween begins at the deepest position guaranteed to be clear.
- Emergency overlap recovery remains only as a failsafe; normal weak and high-Power punch flows now complete with `collisionCorrected = false`.
- Depth rubble and persistent detached blocks keep their physics interactions with the world and other rubble, but use a separate collision group that does not collide with player characters.
- QC: Power 1 requested 10.5 studs and planned 0.337 studs before the first intact block; final overlap 0 and no rollback. Power 1.5B requested, planned, and travelled the full 48 studs with no correction and no intact-block overlap.
- Passing flows: `punch-collision-recovery`, `power-scaled-penetration`, and `punchwall-hybrid-physics-lunge`; console clean.

## Center Feedback Suppression (2026-07-13)

- Disabled the center-screen action-feedback layer for Punch, Reward, Train, Shop, Pet, Rebirth, collapse, boss, and failure events.
- Removed floating world damage numbers, central damage burst text, combat rays, reward/action cards, and their theme icons from gameplay.
- Kept event bookkeeping, hit flash, haptics, punch/reward/collapse audio, and physical debris intact.
- Added and passed `center-feedback-suppression`: a live punch generated a feedback event while zero central UI overlays and zero damage-number billboards were present.
- `punchwall-free-aim-combat-polish` remains passing with a clean console.

## Structural Rubble Solidity (2026-07-13)

- Full-size blocks detached by structural collapse now use the normal `Default` collision group and are solid to player characters.
- Preflight lunge planning and the failsafe overlap check treat detached full-size blocks as real obstacles.
- Small fracture chunks retain the `DepthRubble` group and do not collide with player characters, preventing particle-like debris from shoving or trapping the player.
- Added and passed `structural-rubble-solidity`: four detached blocks were solid and player-collidable; small chunks remained non-colliding with the character group.
- `punchwall-hybrid-physics-lunge` remains passing with a clean console.

## No Post-Lunge Teleport (2026-07-13)

- Removed all gameplay calls that reposition the player after a punch; the preflight lunge plan is now the sole authority for the punch endpoint.
- Full structural blocks use `FallingStructural` while moving: they remain physical against the world but temporarily do not collide with characters, so falling rubble cannot shove or warp a player.
- After 2.8 seconds of collapse settling, or 1.8 seconds after a detached-block bounce, they return to `Default` and become solid player obstacles.
- Passing flows: `structural-rubble-solidity` and `punch-collision-recovery`; console clean.

## Punch Animation Cooldown (2026-07-13)

- Unified client animation, trail, and Punch remote dispatch behind the same 1-second attack interval used by the server.
- Rapid press/release input cannot start a second punch pose, trail, or remote request during cooldown.
- The existing combat regression now verifies first input accepted, immediate second input rejected, and the next animation accepted only after the full interval.
- `punchwall-free-aim-combat-polish` passes with a clean console.

## Structural Character Clearance (2026-07-13)

- Before a falling or re-bounced full-size structural block returns to player collision, it now checks every character with an overlap volume.
- If overlapping, the block moves itself laterally and slightly upward until the character is clear; the character CFrame, velocity, and movement state are never modified.
- A final upward escape is used only if the lateral clearance cannot resolve the overlap.
- Added and passed `structural-character-clearance`: a forced overlap moved the block 3.9 studs, left character drift at 0, and left no overlap before the block became solid.
- `punchwall-hybrid-physics-lunge` remains passing with a clean console.

## Studio High-Power Test Mode (2026-07-13)

- Added a Studio-only `HIGH POWER TEST` toggle under Settings; it is not available in a published runtime.
- Enable grants temporary Power 1.5B, Coins 1B, Wall Level 99, Fist Mastery 500, and 25% Crit Chance.
- The server snapshots the original values and restores them on disable. Active test values are excluded from saves.
- Added and passed `studio-high-power-test-mode`: enabled values and all restored baseline values were verified with a clean console.
- Added a visible Studio-only `TEST POWER` HUD control near the top-right tools, and changed the Hero City gear icon into a clickable Settings button.
# Gamer QC loop - 2026-07-13

Live playtest captures exposed that the first Forest Stone block survived a default punch, contradicting the intended immediate break-and-reward onboarding. Its HP has been reduced from 15 to 8 so a fresh 15 Power player gets a successful first breach. The detailed remaining visual, UX, destruction, mobile, and regression backlog is tracked in `QC_GAMER_LOOP_20260713.md`.
