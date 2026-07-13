# Hero City Reference UI Integration

## Source

- User-supplied source:
  `work/assets/generated/hero-city-hud-reference/hero-city-hud-icons-source.png`
- Source dimensions: `677x408`
- Roblox asset: `rbxassetid://104014193600358`

The source image is used directly as a non-uniform sprite sheet. Runtime values
such as Power, Coins, Wall Level, prices, and ownership are still rendered by
live UI text; static sample numbers in the reference are never used as player
data.

## Crop Regions

Coordinates use `x, y, width, height` in source pixels.

| Region | Crop |
| --- | --- |
| Power | `10,64,73,78` |
| Punch | `18,154,147,172` |
| Coin | `510,142,67,77` |
| Wall | `579,142,77,77` |
| Train | `442,222,66,78` |
| Pet | `510,222,67,78` |
| Quest | `579,222,77,78` |
| Shop | `442,303,66,80` |
| Warning | `510,303,67,80` |
| Rebirth | `579,303,77,80` |
| Menu/Use glyph | `449,307,52,46` |
| Settings glyph | `587,307,60,48` |
| Starter/Boxing Fist | `191,187,70,122` |
| Iron/Thunder Fist | `269,187,71,122` |
| Titan Fist | `347,179,78,134` |
| Fist Shop header | `174,134,271,66` |

Menu and Settings use symbol-only crops so the reference labels `SHOP` and
`REBIRTH` do not conflict with live button text.

## Runtime Uses

- Power, Coin, Wall, Fist, Pet, and Rebirth status icons
- Punch, Train, and Use touch actions
- Objective, target wall, menu, tabs, settings, and feedback
- Fist progression rows and equipped-fist status
- Two-sided Armory nameplates
- Full Hero City world shop billboard
- Cropped Fist Shop menu header

## QC

- Dedicated flow: `work/automation/flows/hero-city-reference-ui.json`
- Mobile captures: `work/docs/qc-screenshots/hero-city-reference-ui-mobile`
- Desktop captures: `work/docs/qc-screenshots/hero-city-reference-ui-desktop`
- Complete acceptance matrix: 26/26 flows passed with overall `ok: true` and
  clean console gates.

## Final Delivery

- Place: `outputs/PunchWallRPGPlayable_v1_final.rbxlx`
- Snapshot: `outputs/iterations/PunchWallRPG_hero_city_reference_ui_final.rbxlx`
- SHA-256: `7DDB9FCE4111415C22B41768D8AD0F6868C5FDB4B645C3294F3B9238615EC51B`
- A new Studio process opened the serialized file and passed
  `hero-city-reference-ui` plus `punchwall-smoke` again.
