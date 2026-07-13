# Fist Item and Icon UI Redesign

## Product Contract

- Preserve the player's original Roblox avatar. Cosmetic progression may add
  equipment but must not replace the body, add mutation spines, or add a tail.
- Every fist is a closed-fist equipment item attached to the right hand. No
  blade, knife, long finger, or WedgePart silhouette is allowed.
- A new player owns and equips `Starter Glove`, displayed to players as
  `Starter Fist`.
- Destroying buildings awards coins. Coins buy the next fist tier in the City
  Fist Armory; a successful purchase equips the new fist immediately.
- Internal item names remain stable for saved-data compatibility. Player-facing
  names, icons, tier styling, and materials may evolve independently.

## Fist Progression

| Tier | Internal save key | Player-facing name | Price | Identity |
| --- | --- | --- | ---: | --- |
| 1 | `Starter Glove` | Starter Fist | 0 | leather starter hand wrap |
| 2 | `Boxing Glove` | Street Boxing Fist | 180 | red city boxing glove |
| 3 | `Iron Knuckle` | Iron Crusher Fist | 1,100 | diamond-plate industrial fist |
| 4 | `Thunder Fist` | Thunder Core Fist | 8,200 | blue energized metal fist |
| 5 | `Titan Gauntlet` | Titan Siege Fist | 90,000 | dark containment gauntlet with amber core |

Each runtime fist contains one rounded palm, one cuff, one backhand plate, four
rounded knuckles, one folded thumb, and one energy core. Tier 4 and 5 add a
local core light. The existing procedural full-body punch pose moves shoulders,
waist, and neck and supports `AnimationConstraint`, R15 `Motor6D`, and R6 rigs.

## Icon System

The current system uses the user-supplied Hero City reference as a non-uniform
sprite sheet: `rbxassetid://104014193600358`. Exact crop regions are recorded
in `HERO_CITY_REFERENCE_UI.md`.

The earlier project-original 4x4 atlas remains archived at
`work/assets/generated/fist-ui-redesign/kaiju-city-icon-atlas-4x4.png` but is no
longer loaded by runtime UI.

HUD stats, objective, target wall, mobile actions, menu tabs, Armory items,
tasks, settings, notifications, and feedback use cropped atlas icons. Text
remains as a concise accessible label beside the icon rather than acting as the
entire visual design.

## Responsive Rules

- Desktop displays all six status rows and the `HERO STATUS` title.
- Compact/touch layouts display Power, Coins, and Wall Level only.
- Mobile `PUNCH`, `TRAIN`, and `USE` controls retain text labels but use large
  visual icons and press feedback.
- Opening the game menu hides gameplay HUD, objective, mobile actions, and the
  menu trigger so the menu behaves as one clean modal layer.
- Desktop and touch layouts use the same source UI and icon atlas.

## Automation Matrix

The recorded flow `work/automation/flows/fist-items-icon-ui.json` verifies:

- four Armory displays have ball palms, four closed knuckles, two-sided icon
  nameplates, and no WedgePart blades;
- the original avatar has no mutation or tail and receives a tiered fist item;
- starter ownership, a 500-to-320 coin purchase, save-key compatibility, and
  immediate Tier 2 equip behavior;
- correct icon atlas crops for HUD and equipped fist;
- responsive title/menu behavior and themed notification feedback;
- clean Studio console output.

Final acceptance on 2026-07-12: all 24 recorded flows passed in one matrix run
with `ok: true`.

The final `.rbxlx` was then serialized from the source-first scripts, reopened
in a new Studio process, source-audited, and passed both `fist-items-icon-ui`
and `punchwall-smoke` again. Final SHA-256:
`4A92B896CA4E82D1E5198AEDFED78F2CB9B2FD30BA1D3145656B008CAD4AD92B`.

## Visual QC Evidence

- Mobile: `work/docs/qc-screenshots/fist-item-icon-ui-mobile`
- Desktop: `work/docs/qc-screenshots/fist-item-icon-ui-desktop`

Each directory contains 11 captures covering spawn, wall lane, facade detail,
Armory/lab, Titan, long progression, and all four menu tabs, plus clean console
and capture metadata files.
