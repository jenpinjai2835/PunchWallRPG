# Smash Wall Release 1.0.0

Release date: 2026-08-19

Release channel: Release

Source branch: `develop`

Source commit: `a426d1bf0b50f8e7b63433b9f8c0279281180287`

## Deliverables

| File | Purpose | Bytes | SHA-256 |
| --- | --- | ---: | --- |
| `outputs/releases/v1.0.0/SmashWall_v1.0.0.rbxlx` | Release place | 5,597,130 | `DEE39AFF9D2196F1A776000B9F88D5018CF5073B735E5D8929E9FE7A4BF415AE` |
| `outputs/releases/v1.0.0/SmashWall_v1.0.0_validation.rbxlx` | Byte-identical validation copy | 5,597,130 | `DEE39AFF9D2196F1A776000B9F88D5018CF5073B735E5D8929E9FE7A4BF415AE` |
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

## Build command

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File work/automation/build-production.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File work/automation/package-versioned-release.ps1 -Version 1.0.0
```

## Remaining release gates

- The exact versioned file has not been opened for a final Roblox Studio runtime
  playtest; its artifact gate is `STATIC PASS`, not a runtime-file PASS.
- Published private/UAT testing remains required for real Robux prompt/cancel,
  paid receipt delivery, Game Pass ownership, and leave/rejoin DataStore
  persistence. Local PlaceId `0` evidence cannot prove those Roblox services.
- Physical controller coverage remains a manual-device gate.
