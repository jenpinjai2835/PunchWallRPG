# Punch Wall RPG - Game Completion Backlog

Date: 2026-07-11
Target: `F:\Roblox\PuchWall\outputs\PunchWallRPGPlayable_v1_final.rbxlx`

## Quality Gate

The game is accepted only when a new player can complete the natural loop without seeded stats:

`spawn -> tutorial -> train -> break walls -> level up -> buy/equip fist -> hatch/equip pet -> defeat Titan -> rebirth`

All required automation flows must return `ok: true`, Studio console must contain no runtime errors, desktop and mobile screenshots must pass human review, and the final rebuilt `.rbxlx` must be the file used for the last test.

Status values: `[ ] Pending`, `[-] In progress`, `[x] Complete`, `[!] Blocked or external release task`.

## P0 - Release Blockers

- [x] `CORE-001` Replace one-time wall level increments with repeatable Wall XP and deterministic level-up progression.
- [x] `CORE-002` Verify a fresh player can naturally unlock every wall tier without seeded stats.
- [x] `CORE-003` Correct pet luck weighting so higher Luck improves rare outcomes rather than forcing Common pets.
- [x] `UI-001` Rebuild mobile HUD around safe areas and Roblox touch controls.
- [x] `UI-002` Verify Android and iPhone landscape layouts with screenshots and pixel bounds.

## Core Progression And Economy

- [x] `CORE-004` Expose Power, Wall Level/XP, Crit, Speed, Luck, fist multiplier, pet multiplier, Coins, and Rebirth bonus in readable UI.
- [x] `CORE-005` Make Fist Mastery meaningful or remove it from the saved schema.
- [x] `CORE-006` Clamp Crit Chance and combat cooldowns to documented limits.
- [x] `CORE-007` Add hold-to-punch and optional auto-punch unlock while keeping server authority.
- [x] `CORE-008` Add contextual target selection and highlighting for Punch, Train, and Use.
- [x] `CORE-009` Rebalance wall HP, XP, rewards, shop prices, egg cost, and rebirth target around measured time-to-upgrade.
- [x] `CORE-010` Add objective tracking and a first-session tutorial that advances from real player actions.
- [x] `CORE-011` Add repeatable quests, daily rewards, and playtime rewards without blocking the core loop.
- [x] `CORE-012` Add clear locked/unlocked state and next-zone guidance.

## Fists

- [x] `FIST-001` Create a visible equipped gauntlet on the character.
- [x] `FIST-002` Add punch animation, recovery, trail, and per-tier impact style.
- [x] `FIST-003` Track fist ownership separately from equipped fist.
- [x] `FIST-004` Add shop UI with price, multiplier, speed, owned, equipped, and unaffordable states.
- [x] `FIST-005` Define and display which fist data survives Rebirth.

## Pets

- [x] `PET-001` Create visible pet companions that follow the player.
- [x] `PET-002` Add hatch reveal with rarity color, probability display, and duplicate result.
- [x] `PET-003` Add pet inventory, equip/unequip, lock/delete, and multiple equip slots.
- [x] `PET-004` Add pet index and discovered rarity tracking.
- [x] `PET-005` Add multi-hatch hooks while keeping the free single-hatch loop complete.

## Combat, Destruction, And Boss

- [x] `VFX-001` Add world-space damage numbers, hit marker, critical feedback, camera impulse, and mobile haptics.
- [x] `VFX-002` Add punch, crack, collapse, reward, hatch, rebirth, alarm, and boss sound layers.
- [x] `VFX-003` Replace fade-only destruction with staged cracks, debris, collapse chunks, dust, and respawn reconstruction.
- [x] `BOSS-001` Add Titan intro, health HUD, attack telegraphs, phases, weak points, and arena danger zones.
- [x] `BOSS-002` Track boss contribution and require participation for rewards.
- [x] `BOSS-003` Prevent regular-wall last-hit reward stealing with per-player contribution rewards.
- [x] `BOSS-004` Scale boss health/reward for active participants and show respawn timer.

## UI, Controls, And Accessibility

- [x] `UI-003` Support mouse, keyboard, touch, and gamepad with the same contextual action model.
- [x] `UI-004` Add responsive HUD modes for desktop, phone, and tablet.
- [x] `UI-005` Add inventory, shop, pet index, quests, daily reward, settings, and rebirth preview panels.
- [x] `UI-006` Replace the permanent help strip with tutorial/objective UI that can collapse.
- [-] `UI-007` Add Thai/English localization-ready strings. UI structure is ready; Thai copy review remains.
- [x] `UI-008` Add reduced motion, volume, camera shake, and UI scale settings.
- [x] `UI-009` Verify text contrast, color-independent rarity cues, safe areas, and minimum touch target size.

## Map And Art

- [x] `MAP-001` Make the player read as a growing kaiju through scale, aura, footsteps, or transformation milestones.
- [x] `MAP-002` Replace repeated facade boxes with curated reusable city modules and documented sanitized visual assets.
- [x] `MAP-003` Add distinct districts: Downtown, Industrial, Reactor, Defense Grid, and Titan HQ.
- [x] `MAP-004` Add cars, signs, lamps with real lights, props, smoke, fire, skyline, and environmental motion.
- [x] `MAP-005` Add map boundaries, fall recovery, checkpoints, and safe boss arena collision.
- [x] `MAP-006` Fix sign occlusion, clipped text, spawn sightline, and shop/lab/training silhouettes.
- [x] `MAP-007` Ensure each wall tier has a unique silhouette, material language, destruction debris, and landmark.
- [x] `MAP-008` Keep optional Creator Store assets visual-only, sanitized, documented, and reproducible with fallbacks.

## Performance And Production

- [x] `PERF-001` Reduce separate facade parts and transparent glass overdraw; establish mobile instance budgets.
- [x] `PERF-002` Enable/test Streaming or keep the map within a documented non-streaming budget.
- [-] `PERF-003` Profile low-end mobile frame time, memory, instance count, particles, and network traffic. Instance/glass budgets and device screenshots complete; published-device profiler run remains.
- [x] `PROD-001` Replace direct `SetAsync` saves with versioned `UpdateAsync`, retries, validation, and shutdown budgeting.
- [x] `PROD-002` Add data schema migration and corruption fallback.
- [!] `PROD-003` Add live analytics markers after a test universe exists; local `PlaceId=0` cannot validate Analytics ingestion.
- [!] `PROD-004` Publish to a test universe and validate DataStore/API behavior there.
- [!] `PROD-005` Prepare icon, thumbnails, description, age/content settings, max players, and private-server configuration in Creator Dashboard.
- [x] `PROD-006` Record the final asset manifest and verify no third-party scripts survive sanitation.

## Automation Matrix

- [x] `TEST-001` Existing nine flows pass before changes.
- [x] `TEST-002` Natural progression: fresh player reaches every wall requirement without `SetStats`.
- [x] `TEST-003` Economy timing: first fist, first egg, each tier, Titan, and Rebirth are reachable within target ranges.
- [x] `TEST-004` Luck distribution: deterministic weighted tests prove rare-or-better and Secret chances improve with Luck.
- [x] `TEST-005` Fist ownership/equip/rebirth persistence matrix.
- [x] `TEST-006` Pet inventory/equip/duplicate/delete/lock/index matrix.
- [x] `TEST-007` Wall and boss contribution/reward curve matrix.
- [x] `TEST-008` Desktop mouse/keyboard and gamepad action matrix.
- [x] `TEST-009` Android/iPhone/tablet safe-area and control overlap checks.
- [!] `TEST-010` Save/load/retry/migration tests require a published test universe.
- [x] `TEST-011` Scene/performance budgets and console-clean checks.
- [x] `TEST-012` Screenshot QC: spawn, tutorial, training, wall tiers, destruction, shop, hatch, inventory, boss, rebirth, and mobile HUD.

## Baseline Evidence

- Existing automation result: 9/9 flows pass.
- Natural progression manual automation: Level `1 -> 2 -> 2`; Concrete remains locked at required Level 3.
- Samsung Galaxy S25 Ultra viewport: `685x338`; stats panel starts at `Y=-40`; help and Use controls overlap Roblox touch controls.
- iPhone 17 Pro shows the same overlap pattern.
- Current scene: 2,073 BaseParts, 525 Glass parts, 0 MeshParts, 0 retained Models, 0 Sounds, 0 Animations, and Streaming disabled.
- Current local place: `PlaceId=0`, `GameId=0`; DataStore cannot be live-validated until publication.

## Five-Pass Completion Update

- [x] Runtime remotes are idempotent; no destroyed-folder client race.
- [x] Mobile actions use a deterministic Studio client bridge that invokes the
  same dispatcher as the visible buttons.
- [x] Spawn orientation, tutorial waypoint, and objective distance guide the
  first session toward training.
- [x] Three AI PBR material families replace flat urban surfaces with source
  fallbacks.
- [x] Reduced Motion now covers camera, haptic, reward pop, toast, and button
  press feedback.
- [x] Character gauntlet build retries until the avatar rig is ready.
- [x] Training signage is compact and readable from the iPhone spawn view.
- [x] Final post-polish automation matrix passes 17/17 flows.

Publication-only items remain `PROD-003`, `PROD-004`, `PROD-005`,
`PERF-003`, and `TEST-010`; these cannot be truthfully closed while the place
has `PlaceId=0`.
