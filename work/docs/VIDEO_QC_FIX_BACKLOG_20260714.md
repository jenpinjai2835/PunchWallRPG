# Smash Wall - Video QC Fix Backlog (2026-07-14)

Source evidence: `C:\Users\Jennarong Pinjai\Downloads\screen-capture.mp4`

This backlog supersedes any earlier "passed" result where the recorded player
experience contradicts the automated assertion. A task is complete only after
its targeted automation passes and a fresh real-play recording confirms the
visible result.

## Final Completion Evidence

Status: **16/16 tasks closed** on the rebuilt final place.

- Delivery tested: `F:\Roblox\PuchWall\outputs\PunchWallRPGPlayable_v1_final.rbxlx`
- Final-file regression: P0 `11/11`, P1 `10/10`, P2 `9/9` (`30/30` total).
- Final-file recording: `F:\Roblox\PuchWall\work\qc\videos\smash-wall-final-file-qc-20260714.mp4`
- Frame audit: `F:\Roblox\PuchWall\work\qc\video-review\20260714-final-file\contact-sheet.jpg`
- Recording metadata: 25 frames over 24.5 seconds, zero capture errors, zero console warnings.
- Temporal camera and collision behavior is additionally sampled by the 200-punch,
  20-device-punch, and long-tunnel automated flows; MCP image capture itself is
  approximately 1 fps and is used as visual timeline evidence.
- Open P0/P1 findings: **none**.

## P0 - Release Blockers

### VQC-001 Prevent punch penetration and snapback

- [x] Reproduce the 00:32.6 overlap with normal and test power.
- [x] Calculate the maximum cleared lunge distance before moving the character.
- [x] Include the full character collision box and glove reach in the sweep.
- [x] Damage/break eligible blocks first, then move only through confirmed clear space.
- [x] Remove every correction path that teleports or pulls the character back to the wall entrance.

Acceptance:

- The character never overlaps an intact depth block after a punch.
- No backward correction greater than 0.5 studs occurs after the lunge.
- Center, edge, corner, tunnel, rubble, and high-power punches all finish in valid walkable space.
- 200 automated punches complete without a stuck state, rollback, or server position correction.

Tests: `punch-safe-endpoint`, `punch-no-snapback`, and a recorded high-power tunnel run.

### VQC-002 Stabilize the punch camera

- [x] Preserve the player's yaw, pitch, and zoom before and after every punch.
- [x] Let the character lead, then follow with a bounded smooth delay.
- [x] Prevent the camera from entering wall, floor, rubble, or character geometry.
- [x] Prevent abrupt switches between high-wide and extreme low-angle framing.
- [x] Keep the avatar readable during maximum-distance penetration.

Acceptance:

- No camera teleport or single-frame distance jump above the agreed tolerance.
- Camera distance returns to the user's selected distance after the follow settles.
- The avatar remains visible in at least 90% of sampled combat frames.
- Rapid repeated punches remain comfortable at desktop, tablet, and phone aspect ratios.

Tests: replace the current camera flow with positional frame sampling plus a 20-punch video capture.

### VQC-003 Complete structural support and rubble states

- [x] Keep intact supported blocks anchored and collidable.
- [x] Recalculate local support after every destroyed block.
- [x] Detach unsupported blocks and apply gravity/impact impulse.
- [x] Keep fallen rubble collidable, visible, queryable, and punchable.
- [x] Shatter only detached rubble that overlaps the character; never alter intact blocks for overlap recovery.
- [x] Remove floating ceilings, unsupported columns, and blocks frozen in mid-air.

Acceptance:

- Unsupported blocks begin falling within 0.35 seconds.
- Settled rubble cannot be walked through and does not push or teleport the character.
- Fallen blocks remain until their remaining HP is destroyed by another punch.
- No unsupported block remains static for more than one physics audit interval.

Tests: support-loss matrix for ceiling, bridge, column, corner, rubble pile, and character overlap.

### VQC-004 Remove release-facing developer controls

- [x] Hide `TEST POWER` and `RESTORE` outside Studio/private QA sessions.
- [x] Move test-power control behind an explicit Studio-only flag.
- [x] Assert that production HUD contains no debug buttons or test labels.

Acceptance: published-build simulation contains neither control while Studio automation can still enable test power.

### VQC-005 Correct the World 1 wall dimensions and route

- [x] Rebuild the starting wall to approximately two Roblox characters high.
- [x] Preserve the requested large multiplayer width and long forward depth.
- [x] Keep blocks densely connected with no initial gaps.
- [x] Prevent players from bypassing progression by walking over the top or around the side.
- [x] Provide a clear floor corridor after blocks are destroyed.

Acceptance: a new player sees a long forward wall route, cannot bypass intact layers, and can walk continuously through a valid punched opening.

## P1 - Core Combat and Progression

### VQC-006 Make the punch animation readable and powerful

- [x] Add a clear wind-up, body rotation, planted anticipation, forward drive, contact pose, and recovery.
- [x] Keep the complete action inside the fixed one-second attack cycle.
- [x] Scale travel distance and body force from power without changing attack speed.
- [x] Synchronize animation contact with server damage and block impulse.

Acceptance: wind-up, contact, and recovery are distinguishable in 30 fps footage at normal camera distance.

### VQC-007 Improve impact and destruction feedback

- [x] Add directional large chunks, small chips, dust, contact flash, and a restrained shockwave.
- [x] Scale effect intensity by actual damage and destroyed block count.
- [x] Avoid repeated stacked punch sounds and cap concurrent debris audio.
- [x] Preserve gameplay visibility and mobile performance during multi-block breaks.

Acceptance: players can identify impact direction and force without reading numbers; effects stay within the performance budget.

### VQC-008 Re-rig and align every glove tier

- [x] Establish a wrist attachment and local orientation standard for R6 and R15.
- [x] Remove forearm penetration and visible wrist gaps.
- [x] Match Starter, Champion, Titan, and other 3D silhouettes to their shop art.
- [x] Verify idle, wind-up, contact, run, jump, and respawn poses.

Acceptance: the glove remains attached and correctly oriented through every tested animation and avatar rig.

### VQC-009 Connect progression HUD to authoritative state

- [x] Replace the primary `WALL LV.` label with `DEPTH`, or clearly define both values if both remain.
- [x] Update the wall quest from actual destroyed-block events.
- [x] Calculate `NEXT WORLD` percentage from real world progress.
- [x] Update rank title, score, depth, and leaderboard from the same server snapshot.
- [x] Handle large values without overlapping icon-safe areas.

Acceptance: quest, depth, score, rank, and next-world progress change correctly in one recorded run and survive respawn/rejoin.

### VQC-010 Replace temporary tier slabs with destructible materials

- [x] Replace cyan/orange neon planes with connected block layers.
- [x] Give each tier a distinct texture, color range, edge treatment, debris material, and impact effect.
- [x] Add readable transition gates without creating physical gaps.
- [x] Keep all tier assets sanitized and documented.

Acceptance: every tier reads as a stronger continuation of the same destructible wall rather than a colored floor panel.

### VQC-011 Make the damage path navigable

- [x] Bias radial damage toward a walkable forward opening.
- [x] Prevent isolated one-block shafts and impassable rubble plugs.
- [x] Keep damage falloff and physical break direction consistent with the avatar's facing direction.
- [x] Add subtle depth landmarks without target highlighting or camera auto-focus.

Acceptance: a player can identify and follow the punched route without climbing onto the wall or becoming trapped.

### VQC-012 Validate starter and normal progression balance

- [x] Test the default 15 Power experience without test power.
- [x] Confirm the first Forest block breaks in one punch.
- [x] Confirm wall punching grants Coins but never Power.
- [x] Confirm Training, Pets, and equipped gloves are the intended Power sources.
- [x] Test transition difficulty at each material tier.

Acceptance: a complete new-player progression run reaches the next tier without debug values or manual data edits.

## P2 - UI, World, and Presentation

### VQC-013 Finish the Forest spawn and training area

- [x] Replace prototype pedestals, white floor markers, black perimeter strips, and empty surfaces.
- [x] Improve the forest entrance with varied trees, rocks, terrain, lighting, and a clear landmark.
- [x] Keep Shop, Training, Pets, Rank, and the wall route visually separated.
- [x] Preserve a clean first-spawn sightline toward the wall objective.

### VQC-014 Recompose responsive HUD layouts

- [x] Reduce competition among top stats, rank, quest, side menus, world card, and mobile controls.
- [x] Increase readability of rank and side-menu labels.
- [x] Respect Roblox top bar and device safe areas.
- [x] Verify icon edges, text bounds, and long-number scaling at all target resolutions.

Viewports: 1920x1080 desktop, 1366x768 laptop, 1024x768 tablet, 844x390 phone, and 740x360 narrow phone.

### VQC-015 Add a branded loading and onboarding state

- [x] Replace the initial blurred frame with a Smash Wall loading screen.
- [x] Preload critical HUD, glove, wall, and spawn assets.
- [x] Show one clear first objective after loading without covering gameplay.

### VQC-016 Add milestone and world-transition feedback

- [x] Add readable feedback for depth records, rank changes, quest completion, and tier entry.
- [x] Change ambient lighting, particles, landmarks, and music by world/tier.
- [x] Avoid center-screen spam during normal block destruction.

## Required Regression Matrix

| Area | Automated checks | Real-play evidence |
| --- | --- | --- |
| Safe lunge | endpoint sweep, overlap, rollback, stuck watchdog | 200-punch high-power video |
| Camera | distance/offset samples, geometry exclusion | desktop and phone combat video |
| Structure | support graph, falling state, settled collision | ceiling/bridge collapse video |
| Combat | one-second cooldown, damage sync, impulse | normal and high-power footage |
| Glove | attachment/orientation attributes, respawn persistence | R6/R15 pose screenshots |
| Progression | coins, no punch Power, depth, quest, world percent | fresh-player progression video |
| HUD | bounds, safe areas, long values, debug absence | five viewport screenshots |
| Features | Shop, Training, Pets, Quest, Rebirth, reset, persistence | one end-to-end session recording |

## Definition of Done

- [x] Every task above has its acceptance criteria demonstrated.
- [x] Targeted automation passes before the slower full regression suite.
- [x] Existing functional flows remain green and Studio console is clean.
- [x] A fresh final `.rbxlx` is rebuilt from source and tested, not only the open Studio state.
- [x] A new full-screen gameplay recording is reviewed frame by frame.
- [x] No P0 or P1 finding remains open in the final QC report.
