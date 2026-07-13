# Hero City Design Alignment Backlog

## Goal

Rebuild the playable presentation so the live Roblox game matches the supplied Hero City gameplay design as closely as practical. Acceptance is based on the player's actual screen, not only automation markers.

Reference image:

`C:\Users\JENNAR~1\AppData\Local\Temp\codex-clipboard-ef0f9695-19bb-4c1e-825a-fb4428b1e924.png`

## Evidence Required

- Desktop spawn, approach, punch impact, wall break, shop, pets, quests, and next-world screenshots.
- Mobile spawn, punch controls, wall combat, side navigation, and modal screenshots.
- A capture sequence covering approach -> punch -> damage -> break -> reward -> respawn.
- Automated assertions for every new persistent UI element and feedback marker.
- Clean Studio console and a final test from the rebuilt final `.rbxlx`.

## P0 - Core Hero Smash Presentation

- [x] 01. Recompose gameplay around the avatar, fist, and wall target.
- [x] 02. Replace box-building walls with dedicated layered destruction targets.
- [x] 03. Add close combat camera framing near an active wall.
- [x] 04. Make the avatar/fist silhouette readable and heroic while preserving the player's avatar.
- [x] 05. Add prominent in-world wall level, current HP, max HP, and HP bar.
- [x] 06. Add anticipation, punch pose, hit stop, camera impulse, impact ring, sparks, chunks, and damage number.
- [x] 07. Add staged cracks, breach, debris, dust, collapse, and respawn reconstruction.
- [x] 08. Replace small mobile actions with large circular Punch and Jump controls.
- [x] 09. Replace the left Hero Status list with top Power, Coins, and Wall Level cards.
- [x] 10. Stop using the complete design mockup as a world billboard; use separated visual assets/components.

## P1 - UX And Art Direction

- [x] 11. Add left-side Daily, Spin, and Rebirth navigation.
- [x] 12. Add right-side Shop, Pets, and Quests navigation.
- [x] 13. Move the objective into a right-side quest card.
- [x] 14. Add a Next World progress widget with destination and percentage.
- [x] 15. Redesign the fist shop as visual product cards with clear states.
- [x] 16. Give every fist tier a distinct silhouette, material, color, and aura.
- [x] 17. Replace blurry enlarged source crops with higher-resolution separated UI assets where needed.
- [x] 18. Increase city density with background buildings, street props, signs, vehicles, and rooftop detail.
- [x] 19. Finish exposed building backs, edges, map boundaries, and empty sightlines.
- [x] 20. Correct wall texture scale and use modular destruction geometry.
- [x] 21. Improve road, curb, pavement, markings, cracks, and street debris.
- [x] 22. Apply consistent red action, blue navigation, and gold reward color language.
- [x] 23. Improve key light, rim light, contact shadow, and combat focus contrast.

## P2 - Completion And Retention

- [x] 24. Add Normal, Critical, Wall Break, and Boss damage-number treatments.
- [x] 25. Add distinct punch sounds for brick, concrete, metal, crystal, and boss armor.
- [x] 26. Add coin, purchase, equip, quest, break, and respawn audio feedback.
- [x] 27. Add configurable screen impulse and mobile haptic feedback.
- [x] 28. Build a first-minute tutorial: train -> wall -> coins -> fist -> pet.
- [x] 29. Tighten wall progression spacing and strengthen landmarks/navigation.
- [x] 30. Preview the next world and long-term destination from the first session.
- [x] 31. Add a Hero City spawn reveal and first-target presentation.
- [x] 32. Maintain separate desktop and mobile compositions instead of scaling one layout.

## Test Matrix

| Area | Desktop | Mobile | Automation | Visual Evidence |
| --- | --- | --- | --- | --- |
| Spawn and onboarding | Required | Required | Required | Screenshot/capture |
| HUD composition | Required | Required | Required | Screenshot |
| Wall approach/camera | Required | Required | Required | Capture sequence |
| Punch impact | Required | Required | Required | Capture sequence |
| Wall break/respawn | Required | Required | Required | Capture sequence |
| Side navigation | Required | Required | Required | Screenshot |
| Fist shop | Required | Required | Required | Screenshot |
| Quest/daily/next world | Required | Required | Required | Screenshot |
| Console/runtime | Required | Required | Required | Console log |

## Current Baseline

- Functional automation passes for Hero City UI, motion feedback, and mobile controls.
- Visual alignment remains below acceptance because composition, wall destruction, combat scale, and mobile HUD do not yet match the reference.

## Completion Evidence

- Aggregate automation: 27/27 flows passed with `ok: true`.
- Aggregate report: `F:\Roblox\PuchWall\work\docs\full-matrix-latest.json`.
- New alignment flow: `hero-city-design-alignment`.
- Runtime baseline: 1,291 parts, 30 modular destruction bricks on the starter target, clean console.
- Mobile overlap assertions cover combat HUD against status, quest, and action controls.
