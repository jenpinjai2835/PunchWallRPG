# Smash Wall v1.0.5

## Status

Published Public on 2026-08-21.

- Universe: `10490793155`
- Place: `125255969070601`
- Published place version: `19`
- Previous published version: `18`
- Public URL: `https://www.roblox.com/games/125255969070601/Smash-Wall`
- Source commit: `e1ba44d01a8c58a7e07f0cdfd51c482cb1ccf71d`
- Release artifact: `outputs/releases/v1.0.5/SmashWall_v1.0.5.rbxlx`
- Artifact SHA-256: `605A4F70169FD0C7C86635B20171576DC4A81C46B10A4E28C8744F4F29A40208`

## Hotfix

- Studio opened against the published place now uses an ephemeral profile by default instead of attempting a production DataStore lease.
- A deliberate Studio live-data test requires the explicit `PunchWallAllowLiveDataStoreAccess` opt-in.
- Public Roblox servers continue to use durable profiles and now retry transient DataStore failures up to five bounded attempts before failing closed.
- The affected production record was verified as valid DataVersion 8 data and was not deleted, reset, or rewritten.

## Acceptance

- Live-profile migration and lease executable repro: PASS.
- Focused linked-place Studio flow: PASS 7/7 with no DataStore access error or saved-data kick.
- Persistence contract: PASS 31/31.
- Full non-Studio aggregate: PASS — Node 54, PowerShell 19, Luau 27, flows 117, and all 27 safe static contracts.
- Exact-source/global code allowlist: PASS — 9 canonical code objects and 0 extras.
- Canonical final, validation, production, and versioned release XML artifacts are byte-identical.

## Public publish verification

The verified release was converted to Roblox binary format and published through the official Place Publishing API as version 19. Creator place history reports version 19 as published. The published download is byte-identical to the uploaded binary:

- Binary bytes: `1,115,965`
- Uploaded SHA-256: `0681883022FA98C1F7C132C215E9BE629AC789D5F4834A90E7D58E6B63CC07C8`
- Published download SHA-256: `0681883022FA98C1F7C132C215E9BE629AC789D5F4834A90E7D58E6B63CC07C8`

The temporary API key was restricted to the Smash Wall experience and only the required DataStore diagnosis/place-publish permissions, then deleted after verification.

Machine-readable evidence: `work/docs/evidence/release-v1.0.5/publish-summary.json`.
