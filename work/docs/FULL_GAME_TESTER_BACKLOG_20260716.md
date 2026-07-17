# Smash Wall - Full Game Tester Backlog (2026-07-16)

## Test scope

This backlog records issues reproduced in the final `.rbxlx` during a real Play session, using an iPhone 17 Pro landscape viewport (`749 x 361`) plus free-camera inspection of the world. It supplements the existing automated flows, which currently verify structure and state more reliably than visible presentation.

Acceptance requires all P0 and P1 items below to pass in the rebuilt final place, no unexpected console errors, and no regression in the release economy/world/gameplay flows.

## P0 - Blocks normal use

- [x] **UI-01 Generic menu content is hidden behind its own panel.** Pets, Honor, Tasks, and Settings initially render as a nearly black window because `GameMenu.ZIndex = 100` while its content remains at ZIndex 1-5 under `ZIndexBehavior.Global`.
  - Pass: every tab has visible content, title, close button, and actions above the panel on desktop and mobile.
- [x] **UI-02 Generic menu mobile tabs and close control overlap or leave the viewport.** Five fixed-width tabs exceed the available width and the close button is covered.
  - Pass: all tabs fit without overlap, the close button is fully visible and clickable, and no tab sits under Roblox CoreGui.
- [x] **UI-03 Spin modal is clipped on mobile.** Header, close button, reward wheel, and bonus-spin purchase control extend beyond the 749x361 viewport.
  - Pass: the entire modal and every control fit inside safe bounds at 749x361 and remain readable/clickable.
- [x] **UI-04 Sound and More icons are decorative ImageLabels.** They look interactive but cannot be pressed.
  - Pass: Sound toggles music/SFX state and persists through the server setting event; More opens a useful menu surface. Both provide pressed/selected feedback.
- [x] **GAME-01 Every primary menu route must be functionally exercisable.** Fists, Robux products, boosts, Pets, Honor, Tasks, Settings, Daily, Spin, Rebirth, Jump, Punch, and training must each open/execute/close without dead controls.
  - Pass: an automation action and a real input path both work for every route, with expected state change or clear unavailable feedback.

## P1 - Visible release quality or model defects

- [x] **HUD-01 Mobile HUD collides with CoreGui and clips text.** Rank panel occupies the Roblox menu region; `DepthLabel`, leaderboard labels, quest text, and next-world progress report `TextFits = false`.
  - Pass: no HUD/control overlap, important labels fit, and long compact values remain readable at 749x361.
- [x] **HUD-02 Tutorial waypoint is too large and blocks gameplay.** The 190x52 always-visible `NEXT` card covers the training target and other landmarks.
  - Pass: use a compact mobile card; hide or collapse it near the target and never cover the punch/training interaction.
- [x] **SHOP-01 Robux product art is incorrect.** Coin Pack reuses x2 boost art and Spin Pack uses an unrelated square COINS atlas tile.
  - Pass: Coin Pack uses the supplied standalone coin art; Spin Pack uses a wheel/spin image; each product is visually distinct.
- [x] **FIST-01 Equipped fist does not align with the wrist.** The current closed-fist model hangs beside the hand with its long axis vertical and knuckles facing the wrong direction.
  - Pass: cuff meets the right wrist, knuckles face character-forward, no floor drop, no hand clipping, and alignment survives R6/R15-compatible hand selection.
- [x] **FIST-02 Equipped fist silhouette/material looks like a soft blob.** The source texture and shell do not read as a powerful Hero City gauntlet.
  - Pass: closed fist silhouette is readable from front/side, tier armor colors are distinct, knuckle/cuff details are visible, and aura intensity scales by tier without obscuring the hand.
- [x] **FIST-03 Premium display fists are oversized and wrongly oriented.** Stand models look like giant floating torso/mug shapes, with noisy inaccessible textures.
  - Pass: all premium displays face the approach, fit their plinths, read as fists, use sanitized visual-only geometry, and match the purchased/equipped tier.
- [x] **WORLD-01 Honor displays are primitive and overexposed.** Wide neon discs and glowing balls dominate the east area instead of presenting desirable relics.
  - Pass: each Honor item has a distinct readable model, restrained glow, correctly oriented rings, and matching UI icon.
- [x] **WORLD-02 Rebirth portal ring is horizontal.** Cylinder orientation produces a giant glowing pool instead of a vertical portal.
  - Pass: portal is vertical, centered at the interaction, framed, and does not look like unused terrain.
- [x] **WORLD-03 Pet lab is visually unfinished.** A dark box and giant cyan sphere do not read as a hatchery/NPC station; signage and interaction hierarchy are weak.
  - Pass: clear NPC/terminal, vertical containment capsule with visible sample, readable sign, and unobstructed approach.
- [x] **WORLD-04 Training zone reads as a prototype.** Random gray/yellow floor rectangles, oversized wooden surfaces, and competing signs weaken the Power Bag focal point.
  - Pass: a clean training deck, one dominant Power station, restrained signage, and no stray-looking floor pieces.
- [x] **WORLD-05 Rank board sightline is obstructed.** Bright repeated foliage blocks the board from a common approach.
  - Pass: landmark exclusion zones keep tree canopies clear of rank/shop/pet/training approaches.
- [x] **WORLD-06 Map overview exposes unfinished negative space.** Large flat green pads, repeated neon trees, black slab stands, and oversized billboard/camp elements make the hub look incomplete.
  - Pass: hub boundaries are intentional, empty pads are removed/filled, scale hierarchy is consistent, and no billboard dominates multiple gameplay zones.
- [x] **WORLD-07 NPC fallbacks look like block mannequins.** Shop/pet/honor roles lack polished character models where external assets fail.
  - Pass: each role has a sanitized free NPC or a deliberate Hero City procedural fallback with readable role icon and pose.
- [x] **AUDIO-01 Music must be audible and controllable.** Existing session had no unexpected console errors, but the user previously reported silence and the visible sound icon currently has no action.
  - Pass: a valid loaded sound plays at a comfortable volume, mute/unmute works, and music failure degrades without console spam.

## P2 - Polish and resilience

- [x] **UI-05 Generic menu page art and item icons must be semantically correct.** Honor currently repeats a coin/success icon for unrelated relics.
- [x] **UI-06 Press, selected, disabled, owned, equipped, insufficient-funds, and purchase-pending states need consistent feedback.**
- [x] **UI-07 Long values and localized labels need overflow coverage.** Test power/coins/depth at 1, 4, 7, and 10+ character display lengths.
- [x] **WORLD-08 Repeated foliage needs controlled variation.** Reduce neon saturation and vary scale/yaw/canopy while preserving navigation clarity.
- [x] **WORLD-09 Visual effects need a brightness budget.** Premium fists, Honor items, portal, and particles must remain readable when viewed together.
- [x] **PERF-01 Validate debris, particles, and UI under repeated punching.** Keep the existing 200-punch and structural physics regressions passing and check mobile frame stability.

## Functional test matrix

| Area | Real-player checks | Automated assertions |
| --- | --- | --- |
| Punch/depth | Wind-up, 1 s cooldown, lunge, destruction, rubble, collision, camera | Existing punch/camera/physics flows plus console clean |
| Training/offline | Start, stop/leave area, power gain, reconnect grant | State delta, persistence fallback, no duplicate loop |
| Fist shop | Open, page tabs, buy/equip, insufficient funds, premium prompt | Correct cards/art/state and equipped multiplier/model |
| Pets | Open, hatch, equip/lock/delete, capacity/error states | Visible layered page and state mutations |
| Daily/Tasks | Open, claim available/unavailable, progress update | Claim idempotency and readable progress |
| Spin | Open/close, free spin, cooldown, Robux prompt | All bounds inside viewport and reward/cooldown state |
| Honor | Open, insufficient/owned/equip, visual matching | Distinct icon/model and state result |
| Rebirth | Open, requirement fail/success, world response | State reset/multiplier behavior and portal presentation |
| Settings/tools | Sound toggle, motion toggle, More menu | Buttons are interactive and settings persist |
| Mobile input | joystick, Punch, Jump, menu controls | Tap targets >= 44 px, no clipping/overlap |
| World reset | warning, five-minute reset, teleport, rebuilt blocks | Existing reset flow and player-safe respawn |
| Presentation | hub/shop/training/pet/honor/rank/wall screenshots | Landmark bounds, no occlusion, mobile/desktop captures |

## Required new regression

- `full-game-tester-critical-ui-and-models`: validates menu layer order, mobile tab/close bounds, Spin bounds, functional Sound/More controls, correct product art, fist forward-axis/alignment, premium display size, Honor/portal orientation, landmark tree clearance, and console cleanliness.
- Extend `release-expansion-ui` to verify actual on-screen bounds and Z-order, rather than text existence alone.

## Exit criteria

- [x] All P0 and P1 items checked off with evidence from the rebuilt final `.rbxlx`.
- [x] New targeted regression returns `ok: true`.
- [x] Existing release UI/economy/world flows and high-risk punch/camera/physics flows pass.
- [x] Desktop and iPhone landscape screenshots show no clipping, overlap, wrong model orientation, or landmark occlusion.
- [x] Studio console has no unexpected errors.
- [x] Device Simulator is returned to its default state after final mobile QA.

## Completion evidence - 2026-07-16

### Tester findings resolved

- Fixed hidden generic-menu content, mobile safe areas, clipped Spin layout, and decorative Sound/More controls.
- Rebuilt the mobile Hero Shop layout with 44 px tabs, purchase controls, and footer action at 844x390 and 740x360.
- Kept long Power, Coins, Depth, quest, rank, avatar-depth, and next-world values authoritative and icon-safe.
- Corrected equipped and showcase fist orientation, starter coloration, tier aura, and premium stand presentation.
- Replaced prototype Honor silhouettes, the horizontal Rebirth disc, and the training cylinder with readable Hero City models.
- Cleared landmark sightlines, reduced premium ad obstruction, moved the rank board, and upgraded the Honor Keeper armor silhouette.
- Preserved free-aim punching with no block target highlight, one-second action timing, safe lunge endpoints, smooth camera lag, persistent rubble, and player-safe structural overlap handling.

### Automated acceptance

- Core full-game matrix: **15/15 PASS**.
- Supplemental collision, camera, stress, feedback, HUD, and route matrix: **13/13 PASS**.
- Rebuilt delivery-file validation: **1/1 PASS** using a fresh Studio process and a byte-for-byte copy of the final RBXLX.
- The 200-punch stress flow, five-device HUD/shop matrix, world reset, 2,700-block reset, route navigability, and console checks all passed.
- Console contained only the expected unpublished-place DataStore notice.
- Studio ended in Edit mode with Device Simulator set to `default`.

### Visual evidence reviewed

- `FullTester_Round5_MobileShop844`: mobile shop hierarchy, readable product cards, and 44 px controls.
- `FullTester_Round5_HonorKeeperArmored`: armored Honor NPC silhouette and plaza presentation.
- `FullTester_Round4_RankBoardOtherFace`: avatar/depth/score world board.
- `FullTester_Round3_TrainingBag`, `FullTester_Round3_PremiumFistStands`, and `FullTester_Round3_RebirthPortal`.

### Delivery artifact

- Place: `F:\Roblox\PuchWall\outputs\PunchWallRPGPlayable_v1_final.rbxlx`
- Size: `4,389,835` bytes.
- SHA-256: `2C2917D67A71F37E2F7A24FCBBA2C78F5B53B88FD7A051FCF5B727ADED4402D7`.
- XML version: `4`; parse validation passed.

Live DataStore persistence and real Robux checkout remain external publish-time checks because the local place has no live experience/product IDs. Their UI, ownership, prompt, and receipt paths are implemented and covered by deterministic Studio grants.
