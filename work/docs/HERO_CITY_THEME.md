# Hero City Theme

## Direction

Hero City is the locked visual direction for Punch Wall RPG. It combines a
child-friendly Roblox simulator with shonen anime action energy. It must feel
bold, readable, and adventurous without becoming photorealistic, pastel-sweet,
or horror-dark.

The selected concept is preserved at
`work/assets/generated/theme-exploration/hero-city-theme-comparison.png`.

## Visual Language

| Role | Color | RGB |
| --- | --- | --- |
| Hero action | Red | `226, 48, 43` |
| Energy and technology | Cyan | `36, 178, 224` |
| Reward and navigation | Yellow | `255, 197, 45` |
| Interface ink | Near-black navy | `9, 14, 22` |
| Primary text | Warm white | `252, 250, 239` |

- UI uses dark ink panels, strong two-pixel borders, Gotham Black/Bold type,
  icon-led controls, and a red-to-yellow-to-cyan comic accent rail.
- World lighting is bright afternoon with a blue sky, moderate contrast,
  positive saturation, light atmosphere, and restrained bloom.
- City materials remain concrete, brick, asphalt, metal, and glass. Hero color
  is applied to navigation, energy, signage, windows, spawn, and landmarks
  instead of flattening all buildings into one palette.
- Fists remain closed gauntlets. Starter uses red leather with a yellow accent;
  higher tiers retain their own readable progression identity.

## World Language

- Spawn billboard: `HERO CITY` and `HERO DEFENSE NETWORK`
- Fist shop: `HERO FIST HQ`
- Pet system: `HERO SIDEKICK LAB`
- Task menu: `HERO MISSIONS`
- Boss district: `HERO RAID: TITAN`
- Rebirth: `HERO REBIRTH GATE`

Internal saved-data keys such as `Boxing Glove`, `Pet`, and
`Equipped Kaiju Gauntlet` remain unchanged for backward compatibility. Only
player-facing language and visual identity changed.

## HUD Contract

- Desktop title is `HERO STATUS`; compact/touch layouts intentionally hide the
  title and keep Power, Coins, and Wall Level.
- Punch, Train, Use, Menu, target health, boss health, tabs, shop rows,
  missions, and feedback retain themed icons.
- Opening a menu hides gameplay HUD controls and presents one clean modal.
- Hero accent rails must exist on core HUD cards, action buttons, menus, and
  feedback surfaces.

## QC And Automation

- Dedicated flow: `work/automation/flows/hero-city-theme.json`
- Mobile captures: `work/docs/qc-screenshots/hero-city-mobile`
- Desktop captures: `work/docs/qc-screenshots/hero-city-desktop`
- Runtime BasePart count remains `1,437`; no gameplay hitbox or map-cost growth
  was introduced by the theme pass.
- Final pre-serialization matrix on 2026-07-12: 26/26 flows passed in one run
  with overall `ok: true` and clean console gates.

The selected HUD and shop reference is integrated directly as
`rbxassetid://104014193600358`; see `HERO_CITY_REFERENCE_UI.md` for crop and QC
details.

## Final Delivery

- Place: `outputs/PunchWallRPGPlayable_v1_final.rbxlx`
- Snapshot: `outputs/iterations/PunchWallRPG_hero_city_final.rbxlx`
- SHA-256: `1FA4F334606CF023C1F839A6488B77A74F29193CB0507D4148627A56DC7141F0`
- The serialized place was opened in a new Studio process, source-audited, and
  passed `hero-city-theme` plus `punchwall-smoke` again.
