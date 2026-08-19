# QC Backlog Closure — 2026-08-19

## Integrated fixes

- Inventory now owns the complete eight-item Honor catalog, including locked,
  insufficient, affordable, owned, and equipped states. World relic selection
  opens and focuses the exact Inventory item.
- The mobile HUD uses real 44 px minimum constraints. Quests clears Jump at
  both 844x390 and 740x360, and Honor plus directional punch targets no longer
  shrink under Studio Device Simulator Fit-to-Window scaling.
- The Shop validates all 16 cards at five viewports. Long names and prices use
  bounded text scaling and remain inside their cards.
- Fist catalog art uses 19 distinct perimeter identities while keeping loaded
  product art unobscured.
- Rebirth and Settings remain standalone, mutually exclusive windows. Rebirth
  keeps its server-authoritative review/cancel/confirm/reset/retain contract.
- The static aggregate executes every non-Studio contract and explicitly
  excludes only the Studio-capable inventory performance benchmark.
- The release builder enforces an exact nine-code-object allowlist and removes
  imported CreatorStore behavior before accepting an artifact.

## Current Studio evidence

All flows selected Studio instance
`6d29b2d4-41ab-41fb-838f-3dfd8727c725`, place
`PunchWallRPG_ManualPlaytest_20260818_FistAuraV10.rbxlx`, PlaceId 0/Edit.

| Flow | Result |
| --- | --- |
| Device HUD + Shop matrix | PASS, 47/47 checks across 1920, 1366, 1024, 844, and 740 |
| Standalone Rebirth + Settings | PASS, 26/26 |
| Rebirth progression | PASS, 42/42 |
| Honor progression + Inventory purchase | PASS, 40/40 |
| Full economy boundaries | PASS, 18/18 |
| Fist item/icon UI | PASS, 14/14 |

The device matrix includes runtime and cleanup console gates. The Rebirth,
standalone-window, Honor, and economy flows include runtime/post-stop clean
console gates where defined.

Current source fingerprint:

- `PunchWallClient.client.lua` SHA-256
  `F78A50E680B90A83DECC768318F1B6A70635DA4CC981DB1F61152A6FA6529FEA`
- Device matrix result SHA-256
  `DB5C14AF10E21D213F2212DD9E71863A141BB0BC59447F222130FAE80BC6FFAE`
- Standalone result SHA-256
  `71E52700D66D481F84DFC7D69023EF0C24256F1D01B65EB71E88C2E98956C302`
- Rebirth result SHA-256
  `68983C6B0582A18890F2884747F9A41A683CEB7FCF4E6887E1AF23B1291FE351`

## Static aggregate

PASS without Studio: Node syntax 44 files, PowerShell syntax 18 files, Luau
compile 27 cases across nine files and three optimization levels, 113 flow JSON
files, runner self-test 12/12, and 24/25 discovered static contracts. The sole
exclusion is `inventory-performance-contract.mjs`, because it intentionally
opens Studio and must be run as an explicit runtime benchmark.

## Remaining external release gates

- The three `PremiumFists` Game Passes are configured and on sale: Crimson
  Vanguard `1947838143`, Stormbreaker `1951036123`, and Celestial Titan
  `1951054054`. Published private-server purchase/rejoin UAT remains required.
- The generated Rebirth coin master still requires upload/moderation before a
  runtime asset ID can replace the approved fallback.
- PlaceId 0 cannot prove production DataStore leave/rejoin durability, real
  Robux checkout/cancel/receipt delivery, or live Game Pass ownership. These
  remain published-private UAT gates and are not reported as passes.
- Physical controller coverage remains a manual device gate.
