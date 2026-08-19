# Progressive Training Stations QC — 2026-08-19

## Verdict

Gate 5 is ready for independent review. The implementation and latest Studio evidence contain no known in-scope defect after the second visual iteration.

## Canonical balance

| Tier | Station | Required base Power | Power / second |
|---:|---|---:|---:|
| I | Rookie Power Bag | 0 | 4 |
| II | Iron Impact Dummy | 1,500 | 40 |
| III | Titan Reactor | 150,000 | 1,200 |
| IV | Celestial Power Core | 15,000,000 | 50,000 |

Online ticks are one second. Offline efficiency is 35% and is capped at eight hours. Expected ten-second offline projections are 14, 140, 4,200, and 175,000 Power respectively.

## Implemented safeguards

- The server checks base Power, not fist/pet/effective multipliers, both on entry and every recurring tick.
- Starting, repeating the same station, and switching stations never grant an immediate free tick.
- A station switch resets the authoritative tick anchor and the next payout uses only the new station rate.
- Rebirth stops training before resetting Power.
- A world reset preserves an eligible active session, reanchors it, and does not pay twice.
- Selected station identity is persisted and drives online and offline rates.
- Online and offline gains are clamped to the persistence maximum.
- The player is movement-locked only while training; Stop restores movement and no later tick leaks.
- The contextual TRAIN control is hidden while a session is active; the active EXIT overlay remains.
- Pet Lab is separated into its own annex. The scientist is at `(-102, 4, 12)`, at least 12 studs from Premium Offer boards and the egg machine.

## Verification

- Full static suite: PASS
  - Node syntax: 36 files
  - PowerShell syntax: 18 files
  - Luau: 9 sources × O0/O1/O2 = 27 cases
  - Flow JSON: 109 files
  - Training contract: 21/21
  - Persistence contract: 28/28
- Runtime flow: PASS, 25/25 checks, exact Studio instance and place, one attempt after final gameplay-source sync.
- Visual/device capture: PASS for Desktop 1366×768, Phone 844×390, and Phone 740×360.
- Runtime and post-stop console: clean except the expected unpublished Studio ephemeral-session warning.
- Device simulator cleanup: default device restored; 3/3 temporary devices removed.
- Capture manifest verifies local-to-Studio fingerprints for GameConfig, ProfilePersistence, server bootstrap, and client source.

## Evidence

- `work/docs/evidence/training-stations-20260819/flow-result.json`
- `work/docs/evidence/training-stations-20260819/capture-summary.json`
- `work/docs/evidence/training-stations-20260819/console.txt`
- `work/docs/evidence/training-stations-20260819/01_desktop_four_station_overview.jpg`
- `work/docs/evidence/training-stations-20260819/02_phone_844_starter_route.jpg`
- `work/docs/evidence/training-stations-20260819/03_phone_740_celestial_active.jpg`

## Known limitation outside this gate

The current Studio place is unpublished, so the runtime correctly disables real DataStore reads/writes. Persistence schema, migration/default behavior, offline projection, and authoritative maximum were covered by executable/static contracts; a published-session reconnect remains part of final release certification.
