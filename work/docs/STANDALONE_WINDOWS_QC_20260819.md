# Standalone Rebirth and Settings QC — 2026-08-19

## Scope

- Remove the player-facing five-tab combined menu.
- Move Rebirth into a dedicated child-friendly icon-led window.
- Move Settings into a dedicated window.
- Preserve Inventory, Shop, Missions, and the full Honor acquisition catalog.

## Implemented behavior

- `RebirthWindow` is a dedicated modal with reward, Wall Level, Coins, reset, and retained-progress cards.
- `SettingsWindow` is a dedicated modal with Sound, Motion, and UI Size controls.
- The old five-tab bar is hidden and cannot be reached through player routes.
- Missions remains reachable without an embedded Rebirth row.
- Shop and Inventory retain their stable neutral modal host to avoid breaking their existing controllers.
- Rebirth confirmation defaults focus to Cancel and sends only the expected Rebirth count and policy version; the server recomputes all requirements and mutations.
- Compact layout falls back to the full-screen HUD size when Studio Device Simulator temporarily reports a `1x1` camera viewport.
- Compact headers reserve at least 90 px for the Roblox top-left system cluster.
- Compact reward icon, title, and multiplier use a non-overlapping vertical stack verified by rectangle diagnostics.
- READY copy now says `READY • REVIEW BEFORE RESET`; RESET explicitly says `WALL LV 1` and `TRAINING STOPS`.
- Settings uses the Sound icon for Sound and Punch icon for Motion instead of unrelated Rebirth artwork.
- The icon resolver now distinguishes atlas regions from standalone uploaded assets, so `SoundTool` cannot silently fall back to the Warning icon.

## Generated visual assets

The generated transparent icon masters are stored in:

- `work/assets/generated/rebirth-ui-v1/rebirth-core.png`
- `work/assets/generated/rebirth-ui-v1/wall-level.png`
- `work/assets/generated/rebirth-ui-v1/coins.png`

They are source assets, not fabricated Roblox asset IDs. Runtime uses the existing uploaded atlas icons until these masters are uploaded and approved in Creator Dashboard.

## Passed checks

- Full static aggregate: PASS (`Node 43`, `PowerShell 18`, `Luau 27`, `flow JSON 113`).
- Standalone player-window contract: PASS `18/18`.
- Rebirth progression contract: PASS `19/19`.
- `standalone-player-windows` exact-Studio runtime flow: PASS `26/26`.
- `rebirth-progression` exact-Studio runtime flow: PASS `42/42`.
- Runtime and post-stop console: clean except the expected unpublished/ephemeral Studio notice.
- Current source, flow, contract, result SHA-256 values and the exact Studio runtime source fingerprints are recorded in `work/docs/evidence/standalone-windows-20260819/local-validation-summary.json`.

## Blocked evidence (not counted as PASS)

- The capture harness now uses the real HUD → Review → Cancel → Review → Confirm mouse path. Studio MCP `user_mouse_input` still timed out at the first real HUD click, recorded precisely in `work/docs/evidence/standalone-windows-20260819/capture-blocker.json`. Route/callback automation passed, but physical mouse/touch input is not claimed as passing in this run.
- Studio MCP `screen_capture` timed out during the first warm-up capture. Current image evidence could not be generated, so visual screenshot approval remains blocked by tooling. Runtime layout diagnostics at 740px did pass: one exclusive window, no overflowing text, and all visible buttons at least 44px.

## Remaining release gate

When Studio MCP input/capture recovers, repeat desktop 1366, phone 844, and phone 740 captures plus one real mouse/touch Rebirth open/review/cancel/confirm path. Upload the generated icon masters separately before switching runtime image IDs.
