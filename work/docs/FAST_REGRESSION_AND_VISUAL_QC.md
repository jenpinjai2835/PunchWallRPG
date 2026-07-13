# Fast Regression And Visual QC

## Test Policy

- Run `Visual` after HUD, camera, lighting, map-art, or VFX changes.
- Run `UI` after responsive layout, modal, touch-control, or safe-area changes.
- Run `Gameplay` after economy, wall, pet, fist, rebirth, or boss changes.
- Run `Full` only before a final deliverable, after shared architecture changes, or when a fast profile finds a regression.
- Do not rerun unchanged flows during an art iteration.

## Commands

```powershell
F:\Roblox\PuchWall\work\automation\run-fast-regression.ps1 -Profile Visual
F:\Roblox\PuchWall\work\automation\run-fast-regression.ps1 -Profile UI
F:\Roblox\PuchWall\work\automation\run-fast-regression.ps1 -Profile Gameplay
F:\Roblox\PuchWall\work\automation\run-fast-regression.ps1 -Profile Full
```

## Visual Gate

1. Run the `Visual` profile.
2. Capture the real player view, active wall combat, wall impact/break, and mobile HUD.
3. Compare captures against the supplied Hero City design.
4. Record visible gaps only; do not infer a pass from object counts.
5. Fix the highest-impact visual gaps.
6. Repeat the `Visual` profile and capture cycle.
7. Run `Full` only when the visual gate is accepted and a final file will be rebuilt.

## Acceptance Dimensions

- Gameplay focal point and camera composition.
- Avatar/fist/wall scale relationship.
- HUD hierarchy and safe-area placement.
- City density, material quality, and depth.
- Wall damage, debris, impact, and reward readability.
- Mobile touch ergonomics.
