# Smash Wall Release 1.0.0

Release date: 2026-08-19

Release channel: Release

Source branch: `develop`

Source commit: `65886940245772b7f336846f6da2a007f2d1d40f`

## Deliverables

| File | Purpose | Bytes | SHA-256 |
| --- | --- | ---: | --- |
| `outputs/releases/v1.0.0/SmashWall_v1.0.0.rbxlx` | Release place | 5,598,171 | `6D2630509244C0EF9F82B26987FE884ADAEFECFBC05DBDCD8FBEA10D6D2C8792` |
| `outputs/releases/v1.0.0/SmashWall_v1.0.0_validation.rbxlx` | Byte-identical validation copy | 5,598,171 | `6D2630509244C0EF9F82B26987FE884ADAEFECFBC05DBDCD8FBEA10D6D2C8792` |
| `outputs/releases/v1.0.0/SmashWall_v1.0.0_studio_serialized.rbxl` | Studio-serialized publish binary | 1,084,378 | `9D9BF7707A8B343A67B47EF69F1A820513A83760CFE30B5263273EEDC59F6AD0` |
| `outputs/releases/v1.0.0/SmashWall_v1.0.0.manifest.json` | Build provenance and source hashes | — | Recorded in Git |

The release place, validation copy, and `outputs/SmashWall_Production.rbxlx`
are byte-identical.

## Included product scope

- Train power at four progressive training stations.
- Break the 75-depth wall course and defeat the Titan destination.
- Progress through normal and Premium Fists, pets, boosts, Honor relics, and
  scalable Rebirths.
- Standalone Inventory, Shop, Rebirth, and Settings player windows with compact
  mobile layouts.
- Server-authoritative rewards, purchases, progression, receipt idempotency,
  profile fencing, and bounded persistence values.
- Six configured Game Passes and eight configured Developer Products.
- Approved Rebirth coin image asset `135091225093305`.

## Release verification

- Non-Studio static aggregate: PASS.
  - Node syntax: 44 files.
  - PowerShell syntax: 19 files.
  - Luau compile: 27 cases across 9 files and 3 optimization levels.
  - Flow JSON validation: 113 files.
  - Non-Studio contracts: 24/24 PASS.
- Versioned release exact-source verification: PASS for all 9 canonical code
  objects.
- Global code allowlist: PASS with exactly 9 code objects and 0 extras.
- Release build sanitizer contract: PASS.
- Canonical final artifact static regression: PASS.
- Versioned release and validation copy byte identity: PASS.
- Exact XML release runtime in Studio: PASS 10/10.
- Studio-serialized binary reopened and runtime-tested in Studio: PASS 10/10.
- Published as universe `10490793155`, place `125255969070601`, place
  version `11` at `2026-08-19T15:55:28.5836071Z`.
- Published download matches the local Studio binary byte-for-byte at SHA-256
  `9D9BF7707A8B343A67B47EF69F1A820513A83760CFE30B5263273EEDC59F6AD0`.
- Live Roblox Player joined version 11 with no kick. The production DataStore
  migrated the test account from DataVersion 3 to 7, retained Coins 1,849, and
  converted the legacy fractional FistMastery 6.25 to completed mastery 6.
- Live commerce prompt PASS for `Honor Pouch`: Roblox displayed the exact
  product and regional price of 25 Robux. Cancel PASS: Honor remained 0, the
  account balance remained 18 Robux, and all four BUY actions returned to the
  ready state without a receipt grant.

## Build command

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File work/automation/build-production.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File work/automation/package-versioned-release.ps1 -Version 1.0.0
```

## Remaining release gates

- Published private/UAT paid receipt delivery remains blocked because the test
  account has 18 Robux while the lowest pack costs 25 Robux. Roblox offered a
  500 Robux top-up for THB 200; do not confirm that charge without explicit
  action-time user approval. After sufficient balance exists, verify the exact
  +25 Honor grant, receipt replay safety, and leave/rejoin persistence.
- Live Game Pass ownership and physical controller coverage remain manual gates.
