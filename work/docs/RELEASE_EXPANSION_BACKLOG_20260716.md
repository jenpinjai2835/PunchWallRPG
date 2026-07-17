# Smash Wall Release Expansion - 2026-07-16

## Goal

Ship the requested fist, progression, commerce, training, NPC, UI, rank, Honor,
and map-completion pass as one playable release. Gameplay remains server
authoritative and imported Creator Store content remains visual-only.

## Locked Requirements

- [x] Correct the equipped fist wrist angle and position for R6/R15.
- [x] Give every fist tier a readable aura and stronger visual silhouette.
- [x] Show and use effective Power after fist, pet, rebirth, mastery, Honor, and boosts.
- [x] Replace primitive premium displays with sanitized free Creator Store visuals.
- [x] Remove trees and shrubs that block fist podium sightlines.
- [x] Make the mobile JUMP button force a valid humanoid jump state.
- [x] Make physical premium fist podiums Robux-only with clear pricing.
- [x] Keep only one Power training station and use a proper punching-bag model.
- [x] Make one tap toggle continuous training and persist offline progress.
- [x] Add visual-only armory, pet-lab, and Honor merchant NPCs.
- [x] Polish Fists, Pets, Daily, Spin, and Rebirth interfaces.
- [x] Make Spin server-authoritative, animated, persistent, and rewarding.
- [x] Fully mask the legacy Daily Breaker progress art.
- [x] Add visible map boundaries and dimensional forest/rock scenery.
- [x] Replace the text rank box with an avatar depth-progress track.
- [x] Add a large in-world rank and score board beside the wall route.
- [x] Add persistent Honor earned at the World 1 final depth.
- [x] Add a separate Honor shop, collectible models, and useful bonuses.
- [x] Add permanent Robux fist offers and optional shortcut products.
- [x] Remove the unused eastern portal field and bring Rebirth into the hub.

## Acceptance Matrix

| Area | Acceptance |
| --- | --- |
| Fist fit | Knuckles face forward, cuff meets wrist, no floor/detached visual |
| Power | HUD effective Power changes immediately after equipping a stronger fist |
| Training | One tap toggles training; server ticks Power; offline grant is capped and persisted |
| Jump | Touch/click JUMP changes the Humanoid to Jumping/Freefall |
| Premium | Coin purchases cannot unlock Premium fists; configured passes prompt Robux purchase |
| Spin | Cooldown persists, one weighted result is granted exactly once, modal shows result |
| Honor | Final depth grants Honor once per world reset; purchases debit Honor server-side |
| Rank | Avatar markers show server players by depth; world board shows rank/depth/score |
| NPC/assets | Imported assets contain zero scripts/remotes/tools/prompts |
| Map | Hub edges are blocked by visible scenery and the unused east field is gone |
| Regression | Existing P0 flows plus new release-expansion flows return `ok: true` |

## External Dashboard Dependency

Robux buttons and receipt handling are implemented in source. The place owner must
publish the experience and replace the zero-valued Game Pass / Developer Product IDs
in `GameConfig` with IDs created in Creator Dashboard before live Robux checkout can
open. Studio automation uses an explicit test grant and never writes that grant to
DataStore.

## Completion Evidence

- `release-expansion-economy`: 10/10 checks passed.
- `release-expansion-ui`: 11/11 checks passed.
- `release-expansion-world`: 8/8 checks passed.
- Existing P0 regressions passed: smoke, mobile controls, hybrid physics/lunge,
  smooth camera follow, and five-minute world reset.
- Live Robux checkout remains intentionally disabled while every configured
  Game Pass and Developer Product ID is `0`; see `MONETIZATION_SETUP.md`.

## Feature Closure Addendum - 2026-07-17

- Completed the requested 15-item NPC, training, Pet, aura, directional punch,
  Studio test mode, vertical race HUD, Honor icon, reward VFX, tall wall, and
  supplied Spin UI matrix.
- Player-view QC rejected and replaced the sideways Premium merchant, corrected
  the Creator Store Power Bag orientation/scale, and fixed unreadable Premium
  Pet price surfaces.
- Fresh regression: 14 feature/full-game flows passed, followed by a passing
  `final-rbxlx-build-validation` from a byte-identical copy of the rebuilt
  delivery file.
- Detailed evidence: `FEATURE_COMPLETION_20260717.md`.
