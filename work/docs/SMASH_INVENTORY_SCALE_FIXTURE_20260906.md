# Inventory scale fixture correction — 2026-09-06

Status: flow-only correction, source unchanged. The Coordinator owns native desktop/phone acceptance. Source basis `0262ad6`; flow handoff `6667eb6`.

## Cause and actual evidence

The actual `smash-inventory-premium-two-devices-20260906/desktop.json` failed before collecting any readability row: the fixture's requested 0.8 did not remain in the next client Snapshot. The old helper called `SetSettings({uiScale=requested,persist=false})` and immediately demanded a persistent observed setting.

That conflicts with the actual producer. `PunchWallClient.client.lua:9351–9366` updates local `clientSettings`, but explicitly skips the ordinary `UpdateSettings` server request when `persist=false`. `StatsChanged` at line 2781 replaces those local settings from every authoritative `payload.SettingsJSON`. The server's `UpdateSettings` branch at `PunchWallBootstrap.server.lua:9107–9114` normalizes and writes `RPGStats.SettingsJSON`, whose changed value is included in the normal coalesced UI snapshot. Thus a local-only test override can be overwritten by the next correct server snapshot. A longer sleep alone cannot reliably repair this fixture.

The Coordinator's native `smash-inventory-scale-timeline-20260906.json` corroborates the normal path: a single default-persistence request returned 0.8; immediate and subsequent .05/.2/.5/1-second observation steps all reported 0.8. Restoring the original 1 returned and retained 1. Cleanup stopped Play and restored the default device. This probe does not constitute the full Inventory readability flow passing.

## Corrected observation policy

The flow already proves a ready, non-writable, ephemeral Studio profile with live DataStore opt-in disabled before any seed or setting action. Each intended scale call now makes exactly one ordinary `SetSettings({uiScale=requested})` invocation. Polling does not repeat or force the request.

For at most six seconds, observations require all of the following to match the requested value within the original .001 tolerance:

- Decoded replicated `player.RPGStats.SettingsJSON.Value.uiScale`.
- A successful current client `Snapshot.uiScale`.
- The actual `InventoryWindow.InventoryScale.Scale`.

Agreement must hold continuously for .3 seconds; any mismatch resets that observation window. The SetSettings return still has to be successful and report the requested local value, but that optimistic response cannot replace the authoritative/actual-layout proof. Subsequent existing scale assertions check all three sources again, so a later reversion still fails. Failure retains a bounded final observation; successful rows retain requested/authoritative/Snapshot/rendered values, elapsed time and sample count. There are no event watchers to leak.

The original authoritative scale is read from SettingsJSON and restored through the same one-request settlement helper. The three requested scales, explicit same-state refresh per scale, and restoration yield seven intended calls; this is not a retry loop. Existing menu text floors, real TextBounds, semantic colors, dimensions, selection/scroll/search retention, card/model identity, four pet actions, contrast and Forest Pup retained-face/eight-corner projection gates are unchanged. No source, asset, economy, inventory action, Studio or device state was edited by this worker.

## Executable controls

`node work/automation/scripts/inventory-visual-responsive-contract.mjs --self-test --scale-baseline 0262ad6` passes 13 structural checks, the existing 2,953 real ApplyResponsive assertions and 20 semantic/text assertions, plus 1,518 checks executing the **actual current SetSettings producer** and the **actual new flow observation helpers** with a controlled clock/replication schedule. The observations cover all .8/1/1.2 values, an intervening stale snapshot, delayed authority, a transient mismatch, permanent authority/client/render disagreement, malformed authority/Snapshot, later reversion, explicit same-state requests and restoration. Each polling scenario enforces one actual producer request; the bounded-clock checks remain active during every wait.

The actual old flow helpers from `0262ad6`, with the same current producer and an intervening old authoritative snapshot, reproduce the precise intended failure `actual client Snapshot.uiScale did not retain requested scale 0.8`. This failure is semantic, not a compile error. The local-only producer control also demonstrates that its immediate 0.8 response sends zero server requests and is replaced by 1 on the next authoritative snapshot.

All 17 semantic mutations are rejected: the nine prior layout/text/color mutations plus eight new cases restoring local-only mode, omitting any authority/client/render source, ignoring an unstable interval, accepting an optimistic response immediately, repeatedly sending settings while polling, and removing the bounded timeout. Both actual flow Luau payloads compile with Luau 0.737, and `git diff --check` passes. Mocked timing does not establish physical-device latency, aesthetics or performance. The complete native desktop/phone flow remains the Coordinator's acceptance gate.
