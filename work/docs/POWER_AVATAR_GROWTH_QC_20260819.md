# Power Avatar Growth QC — 2026-08-19

## Decision

**PASS — Gate 4 of 8.** Hero body size now follows base `Power`, remains below the restrictive gameplay opening, survives punch/respawn transitions, and does not enlarge equipped pets. No known in-scope defect remains after the recorded regression.

## Shipped policy

- Curve: logarithmic from `Power 15` to `1,500,000,000`.
- Visual multiplier: quantized in `0.025` steps from `1.00x` through `1.25x`.
- Geometry cap: core body height is at most `min(11 - 1.25, 8 - 0.8) = 7.2 studs`.
- Inputs excluded from growth: `WallLevel`, fist multiplier, pet multiplier, accessories, Tools, and visual attachments.
- Pets: keep their normalized target size and existing camera-safe LOD/formation; hero growth is never applied to companion models.
- Lifecycle: coalesced Power updates, appearance-loaded generation guard, grounded resize, server network ownership during resize, punch-state deferral, and respawn reapplication.

| Base Power | Requested scale |
| ---: | ---: |
| 15 | 1.000x |
| 1,500 | 1.075x |
| 150,000 | 1.125x |
| 15,000,000 | 1.200x |
| 1,500,000,000+ | 1.250x |

The final applied scale may be lower only when the rig-specific `7.2 studs` core-body ceiling requires it, and it never falls below that avatar's baseline scale.

## Runtime acceptance

Exact Studio instance:

- ID: `6d29b2d4-41ab-41fb-838f-3dfd8727c725`
- Place: `PunchWallRPG_ManualPlaytest_20260818_FistAuraV10.rbxlx`
- Place ID: `0` (unpublished/Edit source-sync candidate)

The final one-attempt `power-avatar-growth` flow passed all 23 recorded checks:

1. R6 default, R15 default, and tall R15 obey the body cap; an oversized accessory is ignored by core-body measurement.
2. Power matrix `15 → 1.5K → 150K → 15M → 1.5B → 1e15` is monotonic, grounded, and wall-safe.
3. Setting `WallLevel=99` does not change scale.
4. An unanchored punch and simultaneous Power increase restore collision/network ownership and leave zero intersecting depth blocks.
5. Forest Pup, Miner Cat, and Crystal Fox are present exactly once and retain their pre-growth model scale, height, and target height.
6. Reducing Power to 15 returns to baseline; restoring Power to 1.5B grows the same character again.
7. At maximum size, the live camera sees all `8/8` character bounding-box corners, follows the current Humanoid, remains `Custom`, and records zero inside-geometry frames.
8. Hero/pet and pet/pet projected overlap remain within the accepted limits; all three pets remain inside the camera safe frame. The normal third slot was moved farther rear-left after the first fail-fast run detected `20.4%` pet/pet overlap.
9. Respawn creates a new character, reapplies the high-Power scale, rebinds the camera to the new Humanoid, and rebuilds the same three pet identities without duplicates.
10. Boot, runtime, and post-stop consoles contain no unexpected warning or error. The unpublished-session persistence notice is expected.

Durable result: [`flow-result.json`](evidence/power-avatar-growth-20260819/flow-result.json)

## Visual acceptance

- [`01_power_15_baseline.jpg`](evidence/power-avatar-growth-20260819/01_power_15_baseline.jpg)
- [`02_power_1500000000_three_pets.jpg`](evidence/power-avatar-growth-20260819/02_power_1500000000_three_pets.jpg)
- [`capture-summary.json`](evidence/power-avatar-growth-20260819/capture-summary.json)

The comparison shows a visible but proportionate maximum-size hero. The head remains below the top HUD; feet remain clear of the Next World tile; Punch, Jump, and the right menu rail remain unobstructed. All three pets stay visibly smaller than the hero and remain inside the camera frame.

## Static regression

`run-automation-static-contracts.ps1` passed on the accepted snapshot:

- Node syntax: `34/34`
- PowerShell syntax: `18/18`
- Luau compilation: `27/27` across O0/O1/O2
- Flow JSON: `108/108`
- Runner self-test: `11/11`
- Infrastructure: `25/25`
- Economy boundary: `10/10`
- Fist flow: `11/11`
- Fist icon identity: `7/7`
- World Boost showcase: `10/10`
- Power avatar growth: `18/18`
- Client runtime/performance contract: `26/26`
- Creator Store pet pack: `8/8`
- Persistence: `28/28`

Independent visual QC passed. Server and automation re-audits are recorded through Agent HQ; any future change to the curve, character lifecycle, camera framing, punch ownership, wall geometry, or companion sizing must rerun this gate.

## Evidence limits

- This is an unpublished Studio session, so persistent profile reads/writes are intentionally disabled.
- The rig contract creates both R6 and R15 models programmatically; the captured live player avatar is the current R15 account avatar.
- The older `punch-camera-device-20-result.json` in this evidence folder is a selector-mismatch attempt against a final-artifact-only flow. It is superseded for this gate by the successful live 8-corner camera step in `flow-result.json` and must not be cited as a product failure.
