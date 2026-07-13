# Gamer QC Loop - 2026-07-13

## Evidence

Play mode was run against `PunchWallRPGPlayable_v1_final.rbxlx`. Captures covered spawn, depth-course entrance, a partial punch, and a completed first breach. The initial block had 15 HP while the default 15 Power punch dealt about 8.4 damage, so the intended first-hit payoff did not occur. This has been corrected to 8 HP.

## Findings

### P0 - First minute

- [x] A new player did not break the first Forest Stone block with one punch. Fixed: first-tier block HP is now 8.
- [x] The player reaches a grey wall before understanding that it is the beginning of the long shared excavation route. Added a visible `WORLD 1: FOREST BREAKTHROUGH` gateway, grassy trail threshold, and forest posts at the entrance without altering camera control.
- [x] Spawn originally faced the training plaza while the depth course was behind the player. Corrected the initial spawn facing toward the course; this does not auto-rotate or zoom the camera after spawn.
- [x] Even after facing correction, the old spawn view was visually blocked by shop signage. Moved the spawn pad/ring to the clear approach before the World 1 gateway and shifted the gateway forward toward the first wall.
- [x] The first gateway version created a wide sign across the player camera. Converted it into a compact, player-facing roadside World 1 marker so it labels the area without obscuring the wall.
- [ ] The spawn view contains the training objects, leaderboard, route markers, and floating labels in the same visual band. Establish one primary objective at spawn; move secondary labels lower or hide them until the player approaches.

### P1 - Destruction Readability

- [ ] A damaged block only changes subtly in the captured frame. Add three low-cost damage states that are readable at third-person distance: dark impact crater, expanding cracks, and loose-chip particles.
- [ ] The breach reads like a narrow corridor cut from a uniform slab. Improve depth readability with tier gate frames, a floor centreline, and stronger material/color shifts every tier.
- [ ] The first Forest Stone texture repeats too uniformly across the entire face. Introduce controlled material/color variation per block and distinct visual kits for concrete, metal, crystal, lava, cyber, and titan tiers.
- [ ] Structural rubble is physically present but its short-lived impact moment is easy to miss from the player camera. Add a contained dust ring, rock-chip burst, and a brief screen-space hit flash only on a successful break.

### P1 - Hero City HUD / Mobile

- [ ] The HUD needs a clean first-minute composition: rank and leaderboard at the left, objective card at the right, and no world labels visible through either panel. Test at 16:9 desktop, 4:3 tablet, and narrow phone safe areas.
- [ ] `TEST POWER` is intentionally Studio-only and must never appear in a published build. Keep it visible in Studio playtests near the top-right tools and assert it is absent outside Studio.
- [ ] The in-world training signs are too close to the top HUD in the spawn camera. Reposition/shorten the signs so their silhouettes do not compete with Power, Coins, or Wall Level.

### P2 - World Polish

- [ ] World 1's forest props exist along the corridor sides, but the spawn-to-wall sightline still reads as a hard urban/industrial plaza. Create a stronger forest transition around the course entrance: grass verge, rock clusters, tall trees beyond the side rails, and a forest landmark.
- [ ] The course has no visible shared-progress presence in a solo test. Add optional ghost/recent-break markers or player name depth beacons that remain useful with one player and do not imply fake multiplayer.

### P2 - Technical / QA

- [ ] Record a visual regression flow for the first-hit Forest Stone breach, including `MaxHP <= default punch damage`, broken state, debris count, coin reward increase, and no Power increase.
- [ ] Add screenshot checkpoints for Spawn, Forest Entrance, First Breach, Tier 2 transition, and high-power penetration. Compare every checkpoint to the Hero City reference composition, not only to individual UI crops.
- [ ] Run the full existing flow suite only after visual/static checks pass; keep fast targeted flows for each local visual or interaction change.

## This Iteration's Verification Target

1. Fresh player has 15 Power.
2. First `DepthBlock_L001_C06_R02` has 8 HP.
3. One punch breaks it, pays Coins, does not grant Power, and creates fragments.
4. Existing combat, collision, structural-rubble, and Studio high-power flows remain green.

## Functional Shop - 2026-07-13

- [x] Replaced the visual-only shop atlas and invisible card hitboxes with an assembled `FunctionalHeroShop`.
- [x] Added `FISTS` and `BOOSTS` pages, a close command, five real glove purchase/equip actions, and supplied transparent product art.
- [x] Added server-authoritative timed boosts: Coin x2, Damage x2, and walk-speed boost, each for 15 minutes.
- [x] Added `functional-hero-shop` regression flow for UI presence, purchase/equip state, coin deduction, timed damage boost, and boosted block damage.
- [x] Desktop/mobile runtime bounds were inspected. Expanded each purchase/equip hit target to at least half the product-card height and preloaded all six uploaded product images.
- [x] Added atlas fallbacks while newly uploaded art is still loading/moderating, preserved Speed Boost through character respawn, and applied Coin x2 to boss rewards as well as wall rewards.
- [x] Replaced the procedural-only fist visual with sanitized Creator Store models matched to Starter/Boxing, Iron, Thunder, and Titan tiers. Added `creator-store-fist-visuals` flow and documented IDs/sanitization in `FREE_ASSET_MANIFEST.md`.
