# World Boost Showcase QC — 2026-08-19

## Scope decision

Gate 3 of 8 is **PASS** for implementation, Studio runtime, desktop interaction,
phone-simulator touch, responsive presentation, bounded geometry, and clean
shutdown. The three world products are `CoinBoost`, `SpeedBoost`, and
`DamageBoost`; every interaction opens the authoritative Boosts catalog and
does not mutate currency by itself.

This gate does **not** claim a physical controller test. The hardware ButtonX
check below remains an explicit pre-release manual gate.

## Acceptance evidence

- `work/docs/evidence/world-boost-showcases-20260819/flow-result.json`
  - PASS against Studio instance `6d29b2d4-41ab-41fb-838f-3dfd8727c725`
  - exact place `PunchWallRPG_ManualPlaytest_20260818_FistAuraV10.rbxlx`
  - exact three models, 43 visual parts within the 48-part budget
  - all parts anchored, non-colliding, non-touching, and outside the depth lane
  - real keyboard E opens Coin Boost
  - real mouse world click opens Speed Boost
  - phone simulator reports touch enabled and a simulator tap opens Coin Boost
  - Damage prompt declares ButtonX and shares the verified Damage server route
  - 0.65-second per-player anti-spam throttle passes
  - runtime and post-stop console checks pass
- `work/docs/evidence/world-boost-showcases-20260819/capture-summary.json`
  - local SHA-256 values are recorded for server, client, and flow
  - normalized runtime Script.Source fingerprints match local source
  - desktop 1366x768, phone 844x390, and phone 740x360 captures are recorded
  - capture device cleanup must record `default: true` and `removed: 3`
- Visual acceptance:
  - all three titles and price/duration rows remain readable
  - signs do not overlap each other
  - HUD and touch controls do not cover product text
  - overview places the row beside the depth entrance without blocking the route
- Regression:
  - aggregate static suite PASS: Node 32, PowerShell 18, Luau 27, flow JSON 107,
    runner 11, infrastructure 25, economy 10, Batch-B fist 11, fist icons 7,
    world Boost 10, pet pack 8, persistence 28
  - `functional-hero-shop.json` PASS

## Required physical-controller gate — NOT RUN / BLOCKED until hardware is available

The Studio MCP input tool cannot create a connected gamepad device. It can
verify `GamepadKeyCode == Enum.KeyCode.ButtonX`, but sending a ButtonX key code
through the keyboard tool is not equivalent to a physical controller. Before
public release, run this exact manual test with an Xbox-compatible controller:

1. Start the current release candidate with the controller connected.
2. Walk within 16 studs of each Coin, Speed, and Damage kiosk.
3. Confirm the native prompt displays the controller X affordance.
4. Press X once for each kiosk and verify the Boosts tab opens with the expected
   target recorded as `CoinBoost`, `SpeedBoost`, then `DamageBoost`.
5. Press X repeatedly and verify the 0.65-second throttle prevents rebuild churn.
6. Confirm navigation, purchase buttons, and close/back work using only the
   controller.
7. Save video/screenshots plus runtime and post-stop console output.

Until that evidence exists, hardware gamepad support is **not certified** even
though the binding and authoritative route are verified.

## Non-blocking carry-forward

- Coin geometry is intentionally low-part and reads less richly than Shop card art.
- Pets can overlap the lower 3D product silhouette, but not the title or price.
- The 740px HUD still shows a separate Quests/Jump overlap risk; it is outside
  the kiosk gate and must remain on the final mobile HUD defect list.
- `punched-route-navigability.json` is selector-locked to the stale final
  artifact, and `punchwall-map-progression.json` retains an older spawn-location
  expectation. Neither was counted as passing; the current gate instead proves
  lane clearance directly in its exact-source runtime flow.

