# Hero City Reference Gap List

Reference: `codex-clipboard-bd92603a-d62a-4f52-b48e-46594fb538c8.png`

Compared capture: `qc-screenshots/hero-city-pixel-perfect-2026-07-12/09_combat_break.jpg`

## P0 Composition And Combat

- [x] Character is fully framed; R15 `AnimationConstraint` shoulder axis was corrected and the strike pose is held for capture.
- [x] Wide combat camera now separates the avatar left from the wall at center-right.
- [x] Live `WALL LV.` and HP bar render below the top status deck.
- [x] QC now uses live client key input instead of server-only HP mutation.
- [x] Damage/break captures include number, spark, dust, pose, breach, and rubble state.

## P0 Destruction

- [x] Staged masonry removal creates an irregular stepped crater.
- [x] Rubble increased to 30 smaller block/wedge concrete fragments.
- [x] Debris spreads toward the player and remains visible around the breach.
- [x] Break adds a dedicated 34-particle dust burst plus spark rays.

## P1 Environment

- [x] Seven midground city buildings were added behind the progression lane.
- [x] Added facade geometry, window color variation, roofs, and stronger skyline layering.
- [x] Exact `SMASH!` pixels from the reference render on the combat-facing shop billboard.
- [x] Added 72 staggered pavement tiles to the combat plaza.
- [x] Existing lights, barricades, roads, cars, signs, and rubble now read against a denser midground.

## P1 Lighting And Readability

- [x] Exposure and ambient lighting were reduced to preserve avatar detail.
- [x] Combat outline transparency was reduced from 0.05 to 0.45.
- [x] Contrast and saturation were raised while bloom was reduced.
- [x] Starter wall changed to concrete gray with a dark breach and orange accent.

## P1 HUD Completeness

- [x] Top status cards use approved source pixels.
- [x] Side menu icons use approved source pixels.
- [x] Punch, Jump, joystick, Quest, Next World, and Fist Shop use approved source pixels.
- [x] Exact bottom comic texture and colored edges were extracted from the reference with transparent control cutouts.
- [x] Live combat capture now records the same-moment punch pose and feedback.

## Remaining Non-Code Differences

- The player avatar intentionally remains the user's Roblox avatar, not the red
  reference hero.
- The current Studio mobile emulator is wider than the 1672x941 reference, so
  responsive spacing differs while every widget keeps its source aspect ratio.
- The reference is an offline cinematic render; runtime city mesh density and
  physically simulated rubble are still lower. Whole-frame 97% is therefore
  not claimed.

## Acceptance Rule

Do not mark whole-frame fidelity as passed until a same-aspect combat capture
shows the complete avatar, readable wall sign, detailed city, irregular rubble,
live punch pose, and simultaneous impact feedback.

## Same-Aspect Audit 2026-07-12

Comparison artifact: `work/docs/qc-screenshots/hero-city-reference-density-final-2026-07-12/design-vs-game-side-by-side.jpg`

- [x] QC now runs at the reference resolution `1672x941` through a custom Studio device profile.
- [x] HUD source pixels, edge masks, aspect ratios, and major anchor positions match the supplied design.
- [x] Combat camera shows the unchanged player avatar and the enlarged wall in one frame.
- [x] Starter wall now uses 56 masonry pieces, a concrete frame, 30 damage-stage fragments, front-surface spark particles, and persistent plaza rubble.
- [x] Focused `--combat-only` capture mode cuts visual regression time from about 36 seconds to about 16 seconds.
- [ ] Whole-frame 97% is not passed. The unchanged user avatar has a different silhouette/scale, and the live city still has substantially less mesh/material/render density than the offline design render.
- [ ] Impact art remains a runtime comic burst rather than the dense cinematic explosion in the design.
