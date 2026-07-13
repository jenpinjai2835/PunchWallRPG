# Punch Wall RPG Playable v1

## Final Place

`F:\Roblox\PuchWall\outputs\PunchWallRPGPlayable_v1_final.rbxlx`

Open this file in Roblox Studio and press Play.

## Gameplay Included

- Training stations: Power Bag, Speed Dummy, Focus Stone.
- Progressive wall lane: Brick, Concrete, Iron, Crystal, Lava, Cyber Gate.
- Titan Server Wall boss.
- Player stats: Power, Coins, WallLevel, Rebirths, FistMastery, BreakSpeed, CritChance, Luck, FistMultiplier, PetMultiplier.
- Fist shop: Boxing Glove, Iron Knuckle, Thunder Fist, Titan Gauntlet.
- Pet egg machine with pet multipliers and luck growth.
- Rebirth shrine with reset and permanent rebirth scaling.
- HUD with stat labels and toast notifications.
- Android/iOS touch controls: PUNCH, TRAIN, USE.
- Kaiju City Smash graphic polish with asphalt roads, skyline buildings, two-sided 3D facade detail, glass/brick/concrete/metal materials, rubble, city lighting, VFX, and reward pop feedback.
- DataStore save/load path with local unpublished-place fallback.
- Tutorial world waypoint and live objective distance.
- Persistent fist ownership and three-slot pet inventory/equip/lock/delete.
- Boss phases, weak points, contribution rewards, danger zone, and respawn HUD.
- Three embedded sanitized Creator Store visual packs with no retained scripts.
- AI-generated damaged concrete, worn asphalt, and containment-metal PBR materials.
- Reduced-motion, sound, and UI-scale settings.

## Automation

Run all recorded flows:

```powershell
powershell -ExecutionPolicy Bypass -File "F:\Roblox\PuchWall\work\automation\run-existing-flows.ps1"
```

Latest final-file result on 2026-07-11:

| Flow | Status |
| --- | --- |
| `punchwall-map-progression` | Pass |
| `punchwall-mobile-controls` | Pass |
| `punchwall-motion-feedback` | Pass |
| `punchwall-player-state` | Pass |
| `punchwall-rebirth-boss` | Pass |
| `punchwall-shop-and-pet` | Pass |
| `punchwall-smoke` | Pass |
| `punchwall-train-and-break` | Pass |
| `punchwall-visual-polish-smoke` | Pass |
| `natural-progression` | Pass |
| `luck-distribution` | Pass |
| `inventory-persistence` | Pass |
| `responsive-ui-inputs` | Pass |
| `destruction-boss-phases` | Pass |
| `onboarding-waypoint` | Pass |
| `ai-material-assets` | Pass |
| `reduced-motion-performance` | Pass |

Overall: `ok: true` (17/17 flows)

Final embedded place:

- Size: `181720` bytes
- SHA-256: `BF59059F1FBE58E4207B3B48CF4171DA9CC78416914B99829272428513960477`
- Post-reopen gates: `punchwall-smoke`,
  `reduced-motion-performance`, and `responsive-ui-inputs` all pass.

## Notes

- `ServerStorage.PunchWallAutomation` exists only while running in Studio and is used for deterministic tests.
- Local unpublished Roblox files cannot access DataStore. The game falls back safely; publish the place and enable Studio/API access when testing persistence.
- Build process and test matrix are documented at `F:\Roblox\PuchWall\work\docs\BUILD_PROCESS.md`.
- Five-pass audit/fix evidence is documented at `F:\Roblox\PuchWall\work\docs\FIVE_PASS_POLISH_LOOP.md`.
- Publication, live DataStore/Analytics, Creator Dashboard metadata, and a
  published-device profiler capture remain external release checks.
