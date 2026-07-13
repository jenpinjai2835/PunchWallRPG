# Hero City Pixel Fidelity QC

## Acceptance Contract

- Reference: `C:\Users\JENNAR~1\AppData\Local\Temp\codex-clipboard-bd92603a-d62a-4f52-b48e-46594fb538c8.png`
- The main player avatar remains unchanged.
- Passing the whole frame requires a human viewer to read the game and the
  reference as the same finished product, with a minimum target of 97%.
- Similar component inventory is not a pass.

## Implemented Pixel Source

- Uploaded the full 1672x941 reference as `rbxassetid://122009159493035`.
- Extracted transparent pixel crops for Power, Coins, Wall, Daily, Spin,
  Rebirth, Shop, Pets, Quests, Quest card, Punch, Jump, Next World, joystick,
  and top tools.
- Runtime crops use the exact approved pixels, not reconstructed Frames.
- Every widget preserves its source aspect ratio on wide Android/iOS screens.
- Power, Coins, and Wall Level retain live gameplay values.
- The exact 677x408 Fist Shop design remains `rbxassetid://104014193600358`,
  with three functional fist-card hitboxes and nine functional menu hitboxes.
- Roblox gray touch controls are hidden; the approved joystick and Jump button
  handle live input.
- The old draft status deck, side docks, action controls, objective panel, and
  duplicate target HUD are suppressed.
- Combat camera v2 uses a closer 8-stud shoulder view, right offset 4.8, and a
  left-shifted aim point so the avatar sits left of the wall without changing
  the avatar model.

## Latest Evidence

- Capture set: `F:\Roblox\PuchWall\work\docs\qc-screenshots\hero-city-gap-fix-v8-final-2026-07-12`
- Combat break: `09_combat_break.jpg`
- Fist Shop: `07_menu_fists.jpg`
- Capture automation now discards a warm-up frame and saves the second frame so
  ScreenGui timing does not produce false HUD-free evidence.

## Human-Eye Review

| Area | Current verdict | Notes |
| --- | --- | --- |
| HUD graphic source | Pass | Approved source pixels are used directly. |
| HUD hierarchy and anchors | Pass at design aspect | Exact normalized positions at 1672x941; aspect-preserving adaptation on wide mobile. |
| Fist Shop visual | Pass against supplied shop sheet | Full source image, no legacy panel leakage. |
| Mobile controls | Pass | Approved joystick/Punch/Jump visuals; native controls hidden. |
| Punch feedback | Pass for runtime | Live key-input capture contains held punch pose, damage number, and spark rays. |
| Wall destruction | Pass for runtime | Gray starter wall, staged crater, dust burst, and 30 persistent block/wedge fragments. |
| Combat composition | Improved, not 97% | Full avatar is left of a center-right wall with live HP sign; unchanged avatar still differs from the reference hero. |
| City environment | Improved, not 97% | Seven midground buildings, 72 pavers, facade depth, and exact SMASH billboard were added. |
| Whole-frame fidelity | Not passed | Do not claim 97% yet. |

The visual source fidelity of the HUD and Fist Shop is effectively exact before
runtime scaling. The whole-frame image is still materially below 97% because
the 3D environment, wall rubble density, lighting, and avatar composition do
not yet read as the same rendered scene.

## Automated Gates

- `hero-city-pixel-perfect-hud`: final edge-cleanup pass in 12.2 seconds.
  - Exact asset IDs and aspect constraints
  - Live value labels
  - Draft UI hidden
  - Native touch controls hidden
  - 30 rubble chunks visible after wall break
  - Exact shop-facing and SMASH-facing billboard images
  - Exact Fist Shop source and 12 functional hitboxes
  - Transparent damage number and 20 spark rays
  - Clean console
- `punchwall-smoke`: final pass in 11.6 seconds.
- Full regression intentionally skipped for this visual-only iteration.

## Edge Cleanup

- Removed the two bottom-shell overlays that left diagonal panel fragments around the controls.
- Re-cropped Joystick, Punch, and Jump against their actual circular outer edges and preserved transparent corners.
- Split Sound, Settings, and More into three independently masked assets; no shared sky/background strip remains.
- Disabled the world-space wall combat billboard so the single client target HUD is not duplicated.
- Final screenshots: `work/docs/qc-screenshots/hero-city-edge-cleanup-final-2026-07-12`.

## HUD Alpha Cleanup V2

- Rebuilt all 17 live HUD crops with a 4x supersampled alpha mask and antialiased downsampling; interior pixels remain unblurred.
- Removed source-scene remnants from Daily, Spin, Rebirth, Shop, Pets, and Quests.
- Preserved the complete Coins card silhouette after in-game QC showed its brown lower-right area is part of the designed frame shadow.
- Expanded `hero-city-pixel-perfect-hud` to validate all six side-menu asset IDs in addition to the status cards and action controls.
- Alpha contact sheet: `work/docs/qc-screenshots/hero-city-hud-alpha-contact-sheet-v2.png`.
- Final runtime capture: `work/docs/qc-screenshots/hero-city-hud-edge-final-v2-2026-07-12/08_combat_damaged.jpg`.

## Top Status Cleanup V3

- Re-traced Power, Coins, and Wall LV against their primary black/cyan frames instead of the source-image drop shadows.
- Removed the Coins lower-right brown remnant and the Wall LV lower shadow extension.
- Verified the three cards together on a cyan/magenta alpha sheet and in the live `1672x941` device profile.
- Alpha sheet: `work/docs/qc-screenshots/hero-city-top-status-alpha-v3.png`.
- Runtime capture: `work/docs/qc-screenshots/hero-city-top-status-final-2026-07-12/08_combat_damaged.jpg`.

## Delivery

- Final place: `F:\Roblox\PuchWall\outputs\PunchWallRPGPlayable_v1_final.rbxlx`
- Size: 2,790,028 bytes
- SHA-256: `AD677F262D9BE54D16027EA104644115EDC05C54725AF4FDAD6C78ADAE03DB05`
