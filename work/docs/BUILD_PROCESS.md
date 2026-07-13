# Punch Wall RPG Build Process

## Goal

Create a playable Roblox Studio place for a Punch Wall RPG loop:

1. Train punching stats.
2. Break walls gated by wall level.
3. Earn coins and power.
4. Buy stronger fists.
5. Hatch pets for multipliers.
6. Push toward rebirth and the Titan Server Wall.

The build is considered done when the exported place can be opened and played in Roblox Studio, the main loop works from a fresh player, the HUD reflects player state, and all recorded automation flows pass without console errors.

## Automation Rules

- Run all existing flows before and after gameplay-affecting changes.
- New gameplay paths must get a JSON flow under `F:\Roblox\PuchWall\work\automation\flows`.
- Run flows sequentially through Studio MCP; do not run parallel tests against the same Studio instance.
- Use matrix cases for every dev phase. A phase is not complete until its required cases are run or explicitly marked blocked with a reason.
- Prefer direct MCP flow calls over manual Studio clicking. Manual findings must be converted into flow JSON before final delivery.

## Phase 0 - Baseline And Harness

Dev tasks:

- Confirm Studio MCP can select the active Punch Wall place.
- Run the existing smoke flow.
- Keep the flow runner usable as the central test tool.

Matrix:

| ID | Area | Case | Automation | Expected |
| --- | --- | --- | --- | --- |
| P0-01 | MCP | Studio registers and can enter play mode | `punchwall-smoke` | Flow selects Studio and reaches Play mode |
| P0-02 | Map | Runtime folders exist | `punchwall-smoke` | `Walls` and `Interactables` exist |
| P0-03 | Content | Wall and interactable counts are correct | `punchwall-smoke` | At least 7 walls and 9 interactables |
| P0-04 | Runtime | Console is clean | `punchwall-smoke` | No obvious Luau/runtime errors |

## Phase 1 - Core Player State And HUD

Dev tasks:

- Ensure `StatsChanged` sends both `leaderstats` and `RPGStats`.
- Ensure HUD shows fresh player values for `Power`, `Coins`, `WallLevel`, `EquippedFist`, `Pet`, and `Rebirths`.
- Add recorded flow coverage for initial player stat/HUD sync.

Matrix:

| ID | Area | Case | Automation | Expected |
| --- | --- | --- | --- | --- |
| P1-01 | Player state | Fresh player gets default stats | `punchwall-player-state` | Power 15, Coins 0, WallLevel 1, Rebirths 0 |
| P1-02 | HUD | HUD receives leaderstats values | `punchwall-player-state` | HUD labels show non-placeholder stat values |
| P1-03 | Console | No stat sync errors | `punchwall-player-state` | Console remains clean |

## Phase 2 - Core Gameplay Loop

Dev tasks:

- Validate training station interaction.
- Validate breaking the first wall from a fresh player path.
- Validate rewards and wall progression.

Matrix:

| ID | Area | Case | Automation | Expected |
| --- | --- | --- | --- | --- |
| P2-01 | Training | Click Power Bag once | `punchwall-train-and-break` | Power increases above 15 |
| P2-02 | Wall combat | Break Brick Wall | `punchwall-train-and-break` | Brick Wall becomes broken or rewards are granted |
| P2-03 | Rewards | First break grants progress | `punchwall-train-and-break` | Coins increase and WallLevel reaches at least 2 |
| P2-04 | Console | Training and combat have no runtime errors | `punchwall-train-and-break` | Console remains clean |

## Phase 3 - Economy, Shop, And Pets

Dev tasks:

- Validate first fist purchase with sufficient coins.
- Validate egg hatch with sufficient coins.
- Ensure multipliers and equipped labels update.

Matrix:

| ID | Area | Case | Automation | Expected |
| --- | --- | --- | --- | --- |
| P3-01 | Shop | Buy Boxing Glove | `punchwall-shop-and-pet` | Coins decrease, `EquippedFist` becomes `Boxing Glove`, multiplier increases |
| P3-02 | Pets | Hatch one egg | `punchwall-shop-and-pet` | Coins decrease, pet/luck/multiplier state changes |
| P3-03 | HUD | Economy updates reach UI | `punchwall-shop-and-pet` | HUD no longer shows stale values |
| P3-04 | Console | Shop and hatch have no runtime errors | `punchwall-shop-and-pet` | Console remains clean |

## Phase 4 - Map And Progression Polish

Dev tasks:

- Verify player starts on the training island.
- Verify all wall tiers have signs, click detectors, and required level attributes.
- Verify high-tier gates remain blocked for weak players.

Matrix:

| ID | Area | Case | Automation | Expected |
| --- | --- | --- | --- | --- |
| P4-01 | Spawn | Player spawns near the training lane | `punchwall-map-progression` | Character and root map are present |
| P4-02 | Gates | High-tier wall blocks low-level player | `punchwall-map-progression` | Required level is higher than fresh player wall level |
| P4-03 | Content | Signs/click detectors exist on walls and stations | `punchwall-smoke` | Inspected wall/station objects contain interaction UI |

## Phase 4A - Mobile Controls

Dev tasks:

- Add touch-first HUD controls for Android and iOS.
- Route touch buttons through server-validated gameplay actions.
- Validate that Train, Punch, and Use buttons call the same gameplay logic as the world interactables.

Matrix:

| ID | Area | Case | Automation | Expected |
| --- | --- | --- | --- | --- |
| P4A-01 | Mobile UI | Touch controls exist | `punchwall-mobile-controls` | `ActionPunch`, `ActionTrain`, and `ActionUse` buttons exist |
| P4A-02 | Mobile train | Tap Train near Power Bag | `punchwall-mobile-controls` | Power increases from 15 to 19 |
| P4A-03 | Mobile punch | Tap Punch near Brick Wall | `punchwall-mobile-controls` | Brick Wall breaks and rewards are granted |
| P4A-04 | Mobile use | Tap Use near Boxing Glove Stand | `punchwall-mobile-controls` | Boxing Glove is bought and equipped |
| P4A-05 | Security | Server validates distance | code inspection + flow setup | Buttons only act on nearby interactables |

## Phase 5 - Rebirth And Boss

Dev tasks:

- Validate rebirth requirements and reset behavior.
- Validate Titan Server Wall gates and rewards.
- Keep test setup deterministic by using Studio-only automation commands, not live player shortcuts.

Matrix:

| ID | Area | Case | Automation | Expected |
| --- | --- | --- | --- | --- |
| P5-01 | Rebirth gate | Fresh player cannot rebirth | `punchwall-rebirth-boss` | Stats remain unchanged and no errors occur |
| P5-02 | Rebirth success | Qualified player rebirths | `punchwall-rebirth-boss` | Rebirths increases, core stats reset |
| P5-03 | Boss gate | Low-level player cannot damage Titan | `punchwall-rebirth-boss` | Titan HP remains unchanged |
| P5-04 | Boss reward | Qualified high-power player can break Titan | `punchwall-rebirth-boss` | Boss breaks and rewards are granted |

## Phase 6 - Final Build

Dev tasks:

- Run the full flow suite.
- Build the final `.rbxlx` place through Rojo.
- Save a short delivery note with test results and known limitations.

Matrix:

| ID | Area | Case | Automation | Expected |
| --- | --- | --- | --- | --- |
| P6-01 | Regression | All recorded flows pass | `run-existing-flows.ps1` | Overall `ok: true` |
| P6-02 | Build | Rojo exports final place | `rojo build` | `.rbxlx` output exists |
| P6-03 | Delivery | README/test notes updated | file inspection | Output docs identify how to open and test |

## Phase QC - Graphic Design And Motion

Detailed plan:

`F:\Roblox\PuchWall\work\docs\VISUAL_MOTION_QC.md`

Purpose:

- Upgrade the playable v1 from functional prototype to polished visual/game-feel pass.
- QC art direction, map readability, lighting, materials, UI, mobile controls, hit feedback, reward feedback, progression clarity, and performance.
- Track findings as P0/P1/P2 before implementing visual and motion polish.

Required regression:

```powershell
powershell -ExecutionPolicy Bypass -File "F:\Roblox\PuchWall\work\automation\run-existing-flows.ps1"
```

## Current Flow Registry

| Flow | Purpose |
| --- | --- |
| `punchwall-smoke` | Existing map/runtime smoke test |
| `punchwall-player-state` | Fresh player default stat and HUD sync |
| `punchwall-train-and-break` | Training and first wall break loop |
| `punchwall-shop-and-pet` | First economy upgrade and egg hatch |
| `punchwall-map-progression` | Spawn/map gate checks |
| `punchwall-mobile-controls` | Android/iOS touch button checks |
| `punchwall-visual-polish-smoke` | Kaiju City lighting, road/city decor, building facade texture, and HUD polish checks |
| `punchwall-motion-feedback` | Client feedback pop and motion marker checks |
| `punchwall-rebirth-boss` | Rebirth and Titan boss progression |

Screenshot QC automation:

```powershell
node "F:\Roblox\PuchWall\work\automation\scripts\capture_qc_screenshots.mjs" --out-dir "F:\Roblox\PuchWall\work\docs\qc-screenshots\kaiju-city-final-qc"
```

## Latest Verification

Date: 2026-07-11

Final place tested:

`F:\Roblox\PuchWall\outputs\PunchWallRPGPlayable_v1_final.rbxlx`

Command:

```powershell
powershell -ExecutionPolicy Bypass -File "F:\Roblox\PuchWall\work\automation\run-existing-flows.ps1"
```

Result:

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

Overall: `ok: true`

## Completion Gate

The source sync script includes `GameConfig.lua`. Do not run a final Studio test from stale scripts; always run:

```powershell
node "F:\Roblox\PuchWall\work\automation\scripts\sync_rojo_source_to_studio.mjs"
```

New mandatory flows are `natural-progression`, `luck-distribution`, `inventory-persistence`, `responsive-ui-inputs`, and `destruction-boss-phases`. The final place must also pass Android/iPhone screenshot review and retain the sanitized `CuratedVisualAssets` folder after the last Rojo build.
## Five-Pass Final Gate

Before delivery, run:

```powershell
powershell -ExecutionPolicy Bypass -File "F:\Roblox\PuchWall\work\automation\run-existing-flows.ps1"
```

Current gate: 17/17 flows pass. The embedded final place must additionally
contain 3 curated asset packs, 49 MeshParts, 12 AI MaterialVariants, and 0
LuaSourceContainer descendants under `Workspace.CuratedVisualAssets`.
