# Smash Wall Release v1.0.3

Status: **Published to Public**

- Universe: `10490793155`
- Root place: `125255969070601`
- Public place version: `16` (previously `14`)
- Public URL: <https://www.roblox.com/games/125255969070601/Smash-Wall>
- Source commit: `a28605dacb9d3596fe2443543b1fee08856732e4`
- Release package commit: `db6d8f6`
- Release artifact: `outputs/releases/v1.0.3/SmashWall_v1.0.3.rbxlx`
- SHA-256: `FB6497BE01C3DF9947F41A7B618E296E75ADA400C8083147406000ABC15B0B5E`

## Player-facing fixes

- Qualified players can start the exact nearby Power training station without an adjacent station invalidating the request.
- The contextual Action prompt is a compact, readable two-line card; non-training Use actions remain clickable.
- Compact Inventory titles, Search, status tags, names, and model art are rebalanced so tags no longer cover the content.
- Robux values use a green palette distinct from gold Coin values.
- All eight approved normal/Premium pet templates are packaged and release-attested; missing templates fail closed instead of approving round procedural fallbacks.
- Unsupported avatar rigs use the currently equipped fist as a visual training strike fallback.

## Acceptance

- Focused iPhone 17 runtime: PASS 26/26.
- Focused training/UI/pet static contract: PASS 20/20.
- Four current iPhone 17 visual captures: PASS with source/runtime fingerprints and clean console.
- Full static aggregate: PASS.
- Rebuilt final artifact exact-source/global-allowlist verification: PASS.
- Rebuilt final artifact Studio runtime: PASS, including exact eight-pet release attestation.

## Public verification

- Creator version history: PASS, version 16 created at `2026-08-20T17:22:08.377607Z`.
- Public experience API: PASS, universe `10490793155` resolves to root place `125255969070601` as `Smash Wall`.
- Published Studio source attestation: PASS, all 9 normalized source fingerprints match `develop`.
- Published pet package: PASS, 8/8 approved templates, 8/8 visual attestations, 0 embedded Lua source objects.
- Active public servers at verification: 0; no old server restart was required.
- Published cloud Play smoke: BLOCKED because Studio API access is intentionally disabled, so the test profile failed closed and was kicked before gameplay assertions. This is not reported as PASS. The byte-identical local release artifact completed its final Studio runtime regression before publish.

Machine-readable evidence is under `work/docs/evidence/release-v1.0.3/`.
