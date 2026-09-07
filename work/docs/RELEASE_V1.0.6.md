# Smash Wall v1.0.6

Status: release preparation. **Not published.**

September 7 checkpoint: the user supplied an authenticated Chrome CDP session.
Target/history preflight now succeeds. The Open Cloud route is paused because
visual representation differences need native Studio handling. The user has
been asked to perform the native Publish to Roblox As action; the Coordinator
will then verify the new version and downloaded payload. The earlier key
creation question is superseded. No key or upload was created by the agent.

The user explicitly requested pushing the accepted improvements and updating the
existing live game on September 6, 2026. Development code is already pushed and
reviewed in PR #1, merged at `aebbb2b409ca77be2367881f1b55e7936fd6a9b1`.
This release branch packages that accepted result; it does not change gameplay.

## Intended existing target

- Universe: `10490793155`.
- Place: `125255969070601`.
- Game: https://www.roblox.com/games/125255969070601/Smash-Wall
- Latest historical publish record: v1.0.5, place version 19, August 21.
- Fresh authenticated Creator history on September 7 shows latest published
  version **20**, with saved versions **21 and 22** marked unpublished.
- Recheck current history immediately before publication and use the actual
  server-assigned version. Do not assume the next version number.

Git `production` at `2a873cbd` is older than the last recorded live release and
must not be used as the live source baseline. `GameConfig` and
`ProfilePersistence` are unchanged from actual v1.0.5 source `e1ba44d`.
Existing player data, DataVersion 8, stores and commerce IDs are preserved.

## Accepted artifact and changes

The canonical artifact was built at `de8ffeb` and accepted before packaging:

- SHA256: `F61B80E722041A526FB965CC6173CEB1BE37BE35E5F9FD1310B5E4CA503D5781`.
- Bytes: 6,492,145.
- Exact nine embedded code objects, no additional code; CDATA preserved.
- Complete native regression: 131/131, zero exclusions, 57.69 minutes.
- Combined static checks: 61 executed contracts passed; one identified
  Studio-only benchmark is outside that static count.
- Native artifact open and runtime: 11 checks passed without source sync.
- Fourteen desktop/emulated-phone/narrow screenshots were independently viewed.

Shop and Inventory are quieter and responsive, narrow item details use larger
previews, the first five fists and Forest Pup have improved presentation, and
camera/startup/server update fixes are integrated. This is not a new cooperative
mode or a full economy rebalance.

Measured desktop idle/Shop/Inventory p95 is below 18.4 ms. The unchanged 18-punch
tunnel p95 is 19.430 ms, with two of 1,159 intervals above 50 ms and none above
100 ms. Artificial repeated world-reset stress still has real hitches, maximum
147.585 ms. Initial focus is unknown and diagnostics add overhead. Physical-phone
performance, real two-player networking, live paid checkout and production
account rejoin are not established by the ephemeral test run.

The production and versioned XML copies must retain the accepted F61 hash.
Packaging provenance distinguishes the inherited build commit from the release
checkout commit. See `evidence/release-v1.0.6/package-summary.json` and the
versioned manifest under `outputs/releases/v1.0.6/`.

## Historical publication access gate (September 6)

The inspected Chrome instance exposes only the Codex extension. No running
Chrome process has a remote-debugging-port or remote-debugging-pipe flag.
`http://127.0.0.1:9222/json/version` and port 9223 timed out. Studio MCP exposes
no publish, save or export tool. The prior temporary Open Cloud key was deleted;
current publish authentication has not been established.

Repository `AGENTS.md` requires Creator Dashboard work through Chrome CDP and
says to stop when no CDP endpoint is available. No extension fallback, browser
cookie extraction, new credential or upload was attempted.

The package and release preparation were pushed in draft PR #2:
https://github.com/jenpinjai2835/PunchWallRPG/pull/2
Independent review of `dcee9ce` found no actionable P1/P2 issue in packaging
and documentation; all thirteen referenced package/proof hashes matched.
The user then explicitly authorized opening a separate Chrome CDP window.
Automatic approval review rejected that launch before execution, reporting
only `blocked by policy`. No browser process was created by the attempt and
no alternate launch was attempted. A user-established CDP connection is the
remaining access prerequisite; publication and current live-version
verification remain blocked.

## Resumed publication preflight (September 7)

Chrome CDP `127.0.0.1:9222` now responds and Creator is authenticated as
`jennarong2835`. The observed game/place links match the intended IDs.
The browser's version-history response confirms published version 20 and
saved version 22; see `evidence/release-v1.0.6/live-history-before-20260907.json`.

Version 20 was downloaded using the documented version-specific Asset Delivery
endpoint through Chrome CDP and Chrome's own download. No browser cookies were
read or exported. Its retained binary is `outputs/releases/v1.0.6/rollback-place-v20.rbxl`,
755,367 bytes, SHA256
`4E7BDADE10DFECB5F0548CD91178FD191B9BF91DD0868D6894E7E3E24930FB8F`.
The decoder initially rejected modern ZSTD chunks; decompression of all 1,941
chunks subsequently passed length/boundary checks without changing the source
file. The nine extracted source objects match the retained version-19 binary;
`GameConfig` and `ProfilePersistence` also match accepted v1.0.6.

The existing local Studio remains in Edit mode. The recorded source verifier
passed all nine normalized source comparisons at 00:55:44 UTC without syncing.
Native Studio screenshot capture failed with `SetIsBorderRequired` / `0x80004002`,
and menu input did not expose a usable publish dialog. No native publish was
attempted. The official Open Cloud publishing route is prepared instead.

The prepared form named the key `SmashWall_v1_0_6_Publish_20260907`, restricted
`universe-places:write` to Smash Wall, and expires on September 8, 2026.
Creation was not performed. That form was discarded after the visual audit;
the previous key approval question is no longer actionable. No key secret was
created, printed or saved. See `evidence/release-v1.0.6/resumed-preflight-20260907.json`.
An optional form screenshot timed out; the reviewed visible form text is
recorded instead.

The completed baseline audit is `evidence/release-v1.0.6/live-baseline-audit-20260907.json`
(SHA256 `71DEA4C10F9CD21756D2A800565C54ACBF291580638245DD23DB8A0729DDAB98`).
All nine source files match version 19. Union geometry shared payloads match
for all 42 instances, and explicit SurfaceAppearance maps remain unchanged.
However, six TexturePack entries changed from empty to
`rbxassetid://97235821140819` in actual version 20, while F61 retains version-19
values. Default physics flag encoding also changed from 00 to 02; new Content
representation remains opaque to the legacy decoder. These differences are
not established as bugs, but source equality does not prove API visual
equivalence. Native publication is the required next route rather than
silently assuming these fields are unchanged.

Studio's Ctrl+Shift+S shortcut also failed to expose a save dialog. The user
was asked to use File > Publish to Roblox As, select the existing Smash Wall
game and start place, and Overwrite from the already-open verified validation
file. After that action, re-read the published history and download its exact
new version to verify source, visual payload and release identity before
closing the task or merging the release PR.

Before upload: establish the permitted authenticated CDP workflow, freshly
verify the universe/place/current version, and prepare narrowly scoped
`universe-places:write` authorization if the Open Cloud route is used. Record
the returned version number and independently verify the published payload and
history before marking publication complete. Existing servers can retain their
previous version until replaced; restarting them is a separate explicit action.

Official publishing guidance supports XML and binary files and identifies
limitations for certain visual instance types:
https://create.roblox.com/docs/cloud/guides/usage-place-publishing

## Rollback

Retain v1.0.5 XML `605A4F70...40208` and its previously uploaded binary, 1,115,965
bytes, SHA256 `0681883022FA98C1F7C132C215E9BE629AC789D5F4834A90E7D58E6B63CC07C8`.
The binary was hash-verified in this release audit. Revert/republish only if
required after a real deployment issue; no rollback action has been taken.
