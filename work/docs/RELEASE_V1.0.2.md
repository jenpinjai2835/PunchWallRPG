# Smash Wall Release v1.0.2

Status: **Published to Public**

- Universe: `10490793155`
- Place: `125255969070601`
- Public place version: `14` (previously `11`)
- Public URL: <https://www.roblox.com/games/125255969070601/Smash-Wall>
- Gameplay source commit: `45b3a045f3cf2256f30c254d631f2ca4ba7cdbf6`
- Release artifact SHA-256: `CC26C8387B171A67F656B5FE00EB1331397F5D3DB18EEFE262E9F80BCB2A644C`

## Release gates

- Production and validation artifacts are byte-identical: PASS.
- Exact embedded source: PASS, 9/9 canonical scripts.
- Global executable allowlist: PASS, 9 canonical objects and 0 extras.
- Cloud Place pre-publish smoke: PASS, 12/12.
- Public version history: PASS, version 14 is published.
- Public experience API: PASS, universe and root Place resolve as `Smash Wall`.
- Existing public servers at verification: 0; no forced restart was required.

The dedicated cloud iPhone 17 rerun was blocked by a Studio MCP `start play` timeout before gameplay assertions. It is recorded as BLOCKED rather than PASS. The release uses the previously accepted mobile layout regression on the same source candidate, plus the passing cloud smoke. The user explicitly waived real-money Robux purchase UAT for this release. Published cross-session DataStore UAT was not run.

## Post-publish cleanup

- Temporary Studio API access was reverted to disabled.
- Temporary Open Cloud API key `Codex SmashWall v1.0.2 Publish 20260820` was deleted.
- Auto-Recovery files were moved to a recoverable backup folder; none were deleted.

Machine-readable evidence: [publish-summary.json](evidence/release-v1.0.2/publish-summary.json)
