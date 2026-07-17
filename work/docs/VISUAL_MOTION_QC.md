# Phase QC - Graphic Design And Motion

## Goal

Raise Punch Wall RPG from a playable systems prototype into a visually clear, satisfying, mobile-friendly game feel pass.

This QC phase checks whether the game looks appealing, communicates progression clearly, feels responsive when tapped or clicked, and stays readable on desktop, Android, and iOS.

## Deliverables

- Visual and motion QC report with P0/P1/P2 priorities.
- Screenshot audit for spawn, training, wall lane, shop, pet egg, rebirth, and Titan boss.
- Motion/feedback checklist for punch, train, reward, shop, pet hatch, rebirth, and boss actions.
- Polish backlog with concrete implementation tasks.
- Automation or smoke checks for every repeatable visual/game-feel flow that can be validated through Roblox Studio MCP.

## QC Matrix

| ID | Area | What To Check | Pass Criteria |
| --- | --- | --- | --- |
| QC-01 | Art Direction | Theme, mood, visual identity | The first screen clearly reads as a Punch Wall RPG, not a blockout map |
| QC-02 | Map Composition | Spawn, lane, landmarks, focal points | A new player understands the main direction within 3 seconds |
| QC-03 | Lighting | Brightness, contrast, readability | No key object is too dark, washed out, or hard to read |
| QC-04 | Materials | Wall tiers, shop props, training props | Each wall tier feels visually stronger and distinct from the previous tier |
| QC-05 | UI/HUD | Hierarchy, spacing, contrast | Main stats are readable without covering important gameplay |
| QC-06 | Mobile Controls | `PUNCH`, `TRAIN`, `USE` buttons | Buttons are thumb-friendly, high contrast, and do not fight the HUD |
| QC-07 | Punch Feedback | Hit response timing and impact | Feedback appears within 0.1 seconds after input |
| QC-08 | Wall Damage | HP, signs, crack/damage/break states | The player can tell a wall is taking damage |
| QC-09 | Reward Feedback | Coins, power, reward pop/toast | Breaking a wall clearly feels rewarding |
| QC-10 | Progression Clarity | Gate levels, shop, pet, rebirth | The player knows what is locked and what to do next |
| QC-11 | Performance | Part count, particles, UI, mobile load | Visual polish does not cause console errors or obvious frame drops |
| QC-12 | Final Feel | 5-minute play loop | The loop feels clear, responsive, and not visually flat |

## Motion And Feedback Checklist

### Punch Impact

- Wall should pulse or compress immediately on hit.
- Add a brief color flash or spark for contact feedback.
- Keep the timing sharp: fast impact, quick recovery.
- Avoid long animations that delay repeat punching.

### Wall Damage

- Add visible damage stages around 75%, 50%, and 25% HP.
- Use cracks, glow intensity, smoke, or surface changes per tier.
- Keep HP/sign text readable after damage effects.

### Wall Break Moment

- Add burst feedback when the wall breaks.
- Use a short reward pop for coins and power.
- Make broken state obvious through transparency, collision off, or debris-like visual state.
- Respawn should feel clean and readable.

### Training Feedback

- Power Bag should bounce or squash when trained.
- Speed Dummy and Focus Stone should have distinct feedback colors.
- Stat gain should appear quickly through toast or small pop text.

### Shop Feedback

- Purchase success should clearly show equipped state.
- Purchase fail should show why: not enough coins or already owned.
- Stronger fists should feel like real progression through name, color, and multiplier messaging.

### Pet Hatch

- Add anticipation before reveal.
- Use rarity color coding.
- Reveal should clearly show pet name and multiplier value.
- Higher rarity should feel more special without blocking gameplay too long.

### Rebirth

- Rebirth should feel like a major event.
- Use stronger light, sound-ready timing, or shrine pulse.
- Reset feedback must clearly explain the reward and what changed.

### Titan Boss

- Titan Wall should feel larger and more dangerous than normal walls.
- Hits should have heavier impact feedback.
- Break reward should feel like a server-wide moment.

## Priority Rules

| Priority | Meaning | Examples |
| --- | --- | --- |
| P0 | Blocks clarity or usability | UI blocks mobile controls, action feedback missing, player cannot tell what to do |
| P1 | Weakens quality or retention | Motion feels stiff, wall tiers look too similar, reward feedback feels flat |
| P2 | Extra polish | Additional particles, richer rarity animation, sound layering, secondary motion |

## Work Plan

1. Snapshot Audit

   Capture or inspect the main locations: spawn, training stations, wall lane, fist shop, egg machine, rebirth shrine, and Titan boss.

2. Visual Pass

   Improve lighting, material contrast, wall tier identity, signs, landmarks, and player path readability.

3. UI And Mobile Pass

   Check HUD hierarchy, stat readability, toast placement, touch button size, safe area, and thumb reach.

4. Motion Pass

   Implement and tune punch impact, wall break, training bounce, reward pop, shop feedback, pet hatch reveal, rebirth event, and Titan feedback.

5. Feedback Playtest

   Play the core loop: train > break Brick Wall > buy first fist > hatch pet > test gate > rebirth/boss setup.

6. Performance And Regression

   Run all existing automation flows and add a visual/motion smoke flow where possible.

7. Final QC Report

   Record before/after notes, remaining P0/P1/P2 issues, and recommended next polish tasks.

## First Targets For This Game

Prioritize these first because they affect the first minute of play:

| Rank | Target | Reason |
| --- | --- | --- |
| 1 | Spawn readability | New players must instantly understand where to go |
| 2 | Wall lane visual tiering | Progression must look stronger at each level |
| 3 | Mobile HUD and controls | Android/iOS usability is core for Roblox players |
| 4 | Punch and break feedback | The main action must feel satisfying |
| 5 | Reward pop and shop feedback | Players need clear short-loop motivation |

## Automation Expectations

- Existing gameplay flows must continue to pass after every polish step.
- Any repeatable new visual or motion flow should be recorded under `F:\Roblox\PuchWall\work\automation\flows`.
- Visual checks that cannot be fully automated should be documented with screenshots and P0/P1/P2 notes.

Current required regression command:

```powershell
powershell -ExecutionPolicy Bypass -File "F:\Roblox\PuchWall\work\automation\run-existing-flows.ps1"
```

## Implemented QC Pass

Date: 2026-07-11

Implemented:

- Kaiju City Smash visual config and palette.
- City lighting polish with Bloom, ColorCorrection, and Atmosphere.
- Asphalt road guide, skyline buildings, wall tier frames, city decor, facade window textures, damage stages, and VFX anchors.
- Feedback RemoteEvent for client-local punch, train, reward, shop, pet, rebirth, and boss feedback.
- Reward pop HUD layer and mobile button press animation.
- Optional visual-only Creator Store city asset candidates documented in `FREE_ASSET_MANIFEST.md`.

New automation:

- `punchwall-visual-polish-smoke`
- `punchwall-motion-feedback`

Screenshot automation:

- `F:\Roblox\PuchWall\work\automation\scripts\capture_qc_screenshots.mjs`
- Latest final screenshots: `F:\Roblox\PuchWall\work\docs\qc-screenshots\kaiju-city-final-qc`

Reports:

- `F:\Roblox\PuchWall\work\docs\FREE_ASSET_MANIFEST.md`
- `F:\Roblox\PuchWall\work\docs\QC_POLISH_REPORT.md`

## Completion Screenshot Passes

- `F:\Roblox\PuchWall\work\docs\qc-screenshots\game-completion-pass-1`
- `F:\Roblox\PuchWall\work\docs\qc-screenshots\game-completion-pass-2`
- `F:\Roblox\PuchWall\work\docs\qc-screenshots\game-completion-pass-3`

Pass 3 is the accepted local visual baseline. Any future map or UI change must rerun the screenshot script plus Android/iPhone device checks before delivery.

Current motion stack includes procedural punch arm motion, equipped gauntlet trail, world-space damage values, camera FOV impulse, touch/gamepad haptics where supported, staged wall cracks, collapse chunks, reconstruction, boss weak points, shockwave telegraph, and rarity/reward pops.
## Five-Pass Acceptance Addendum

- Kaiju City surfaces now use embedded AI PBR variants with built-in material
  fallbacks.
- Curated models are embedded, anchored, non-collidable, and contain no scripts.
- Tutorial guidance has a world waypoint and distance.
- Reduced Motion covers camera, haptic, reward pop, toast, and button feedback.
- Training signage was resized after final iPhone player-view review.
- Final automation: 17/17 flows pass with clean console checks.

## Fist Item and Icon UI Addendum

Date: 2026-07-12

- Original Roblox avatar is preserved; fist progression no longer mutates the
  character body or adds a tail.
- Five closed-fist item tiers use distinct materials, colors, accent cores,
  player-facing names, and atlas icons. Blade silhouettes are prohibited.
- The procedural full-body punch pose remains the combat motion source and is
  covered by `punch-character-motion`.
- HUD, mobile actions, target bars, shop, quests, notifications, and menu tabs
  use `rbxassetid://134314320646796` instead of text-only visual treatment.
- Desktop and mobile screenshot baselines are stored in
  `qc-screenshots/fist-item-icon-ui-desktop` and
  `qc-screenshots/fist-item-icon-ui-mobile`.
- Final automation: 24/24 flows pass in one run; post-reopen fist and smoke
  gates pass from the delivered `.rbxlx`.

## Hero City Theme Addendum

Date: 2026-07-12

- Final style changed from Kaiju City Smash to Hero City.
- Bright anime-action lighting and the red/cyan/yellow/ink palette now drive
  world landmarks, progression signage, HUD, menus, and feedback.
- Player-facing language now uses Hero Fist HQ, Hero Sidekick Lab, Hero
  Missions, Hero Raid, and Hero Rebirth Gate.
- Gameplay motion remains unchanged and continues to use the procedural
  full-body punch pose, trails, hit flash, particles, and reduced-motion path.
- Hero City visual captures pass on iPhone landscape and desktop.
- Dedicated Hero City flow plus the complete 25-flow matrix pass with clean
  console output.

## Supplied Hero City UI Art Addendum

- Current HUD/shop sprite source: `rbxassetid://104014193600358`.
- The exact user-supplied image now drives icons, fist cards, mobile actions,
  tabs, feedback, Armory nameplates, shop menu header, and world shop billboard.
- Non-uniform `ImageRectOffset`/`ImageRectSize` crops preserve the source art
  while live stats and prices remain dynamic.
- Mobile and desktop screenshots passed visual review; Menu and Settings use
  glyph-only crops to avoid conflicting embedded labels.
- `hero-city-reference-ui` and the complete 26-flow matrix pass with clean
  console output.

## Video QC 16-Task Final Acceptance

Date: 2026-07-14

- Closed all VQC-001 through VQC-016 tasks in
  `VIDEO_QC_FIX_BACKLOG_20260714.md`.
- Rebuilt and reopened the actual delivery
  `F:\Roblox\PuchWall\outputs\PunchWallRPGPlayable_v1_final.rbxlx`.
- Final-file P0 result: 11/11 pass, including 200-punch stress, safe endpoint,
  no snapback, collision restoration, device camera, long tunnel camera,
  support loss, structural clearance, rubble solidity, and depth corridor.
- Final-file P1 result: 10/10 pass, including one-second action timing,
  full-body motion, destruction feedback, all five fist visuals, progression,
  material tiers, route navigation, and normal starter balance.
- Final-file P2 result: 9/9 pass, including forest assets, five-viewport
  HUD/shop matrix, onboarding, world transition, functional shop, center
  feedback suppression, five-minute reset, and inventory persistence.
- Fresh final-file recording contains 25 timeline frames over 24.5 seconds,
  with zero capture errors and zero console warnings. Contact sheet:
  `F:\Roblox\PuchWall\work\qc\video-review\20260714-final-file\contact-sheet.jpg`.
- No P0 or P1 visual/motion finding remains open.

## Studio Test Harness Addendum

Date: 2026-07-17

- Added a Studio-only deterministic test-control layer for server gameplay,
  client UI, camera, settings, motion triggers, rewards, and visual state.
- Added bounded sequence execution so full scenarios run through one MCP call
  instead of slow Windows input automation.
- Added snapshots and GUI summaries for assertion-based QC without relying on
  cursor position or OCR.
- Mobile regression found and fixed undersized Shop tab, product action, and
  Close touch targets; all now enforce at least 44 by 44 pixels.
- Gameplay and UI fast profiles plus both dedicated harness flows pass with a
  clean console.

## NPC, Training, Pet, And Spin Addendum

Date: 2026-07-17

- Replaced the sprawled Premium merchant with a sanitized upright bionic Hero
  NPC and retained the sanitized Rad Robo Armory merchant.
- Replaced the mannequin landmark with a Creator Store freestanding Power Bag,
  corrected its source axis and world-ground alignment, and retained impact
  burst, audio, light, shake, continuous training motion, and the Exit state.
- Premium Pet plinths now retain readable front/back Robux price surfaces under
  every lighting angle. Their high-tier particles, lights, and outlines remain
  active.
- Supplied Honor and Spin layers render as the approved nine-image composition
  at the tested mobile and desktop layouts.
- Final player-view captures and all targeted automation are recorded in
  `FEATURE_COMPLETION_20260717.md`.
