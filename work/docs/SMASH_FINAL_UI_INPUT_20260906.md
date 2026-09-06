# Generic menu input stability — 2026-09-06

The generic Pets and Tasks pages now preserve their native buttons across unrelated player snapshots. Playtime and spin countdown text updates in place. Changes that affect ownership, exact pet slots, locks, fusion readiness, Delete confirmation, premium prices, claim state, or reward readiness still update the page.

Source handoff: `e2f1c862e73add68f868f8f3548df5e51a2e01f7`, integrated by the Coordinator as `ad0ff88`. Mainclient ownership was released before completing this test/document handoff. The source comparison is `f6202ce7c2da48de6a943ddcd8fa53aeaa2643b4`.

## Observed cause

Coordinator evidence `work/docs/evidence/smash-input-diagnostic2-20260906.json` records the first legacy Equip gesture:

| Event | Monotonic time | Equip2 instance ID |
| --- | --- | --- |
| Native ButtonDown | 11781.085554 | 2 |
| StatsChanged | 11781.467863 | 2 |
| Destroyed | 11781.476224 | 2 |
| ButtonCreated | 11781.498960 | 3 |
| Native ButtonUp | 11781.508928 | 3 |

No Activated event occurred; the callback sequence remained 0 instead of 1. The gesture reached the intended Equip2 control on both press and release, but the original button was destroyed between them. The earlier tick also reset CanvasPosition from 1565 through 0 to 1509 and moved selection to Equip3.

The source chain matches that observation: the server increments PlaytimeSeconds each second, its NumberValue change queues StatsChanged, the client receives the snapshot and calls renderOpenPanel, and the previous generic renderer destroyed every current GuiObject row before recreating the page.

Raw GetMouseLocation included a 58 px inset; the actual input Position matched the intended button. That difference is not evidence of a coordinate bug. The Tasks failure separately retained a button reference across a layout wait and then reported topmost=false. Its fixture now reacquires the current row/button after waiting. The diagnostic above proves native click cancellation for legacy Equip; it is not a second recorded Tasks click trace.

## Source behavior

- Pets signatures include ordered inventory, equipped tokens, locks, discovery, pity, permanent premium ownership, Delete generation, game-pass configuration, and cached regional price state. Power, Coins, Score, training, and playtime alone retain the existing page.
- Tasks signatures include tutorial text, UTC daily eligibility, quest progress/claim status, playtime eligibility/claim status, spin credits/readiness, and the layout profile. Playtime and spin countdown labels update only when their text changes.
- Exact-slot Delete arming, timeout, validation, and second-click dispatch remain the existing production functions. Their generation invalidates the retained page so CONFIRM and expired DEL states remain accurate.
- A content clear invalidates the retained signature, anchor, and clock references. Missing anchors/clocks rebuild the page. Deferred canvas restoration also checks the content generation, so an older job cannot overwrite a later page's scroll position.

`GenericPanelStructuralRenderCount` and `GenericPanelRetainedRefreshCount` count actual renderer branches for diagnostics. They are not frame-time or FPS measurements.

## Durable verification

Run from the repository root:

```powershell
node work/automation/scripts/generic-panel-stability-contract.mjs
node work/automation/scripts/fist-pet-safety-contract.mjs
node work/automation/scripts/full-game-real-ui-controls-contract.mjs
```

The generic contract supports `--source-root`, `--baseline-ref`, and `--luau`; `LUAU_COMMAND` overrides its default existing Luau 0.737 executable. It executes extracted production makeMenuCommand, Delete functions, addRow/addSection, renderPets, renderTasks, clearContent, generic helpers, and renderOpenPanel in independent deterministic mocks. It compiles the full current client and writes no files.

| Check | Result |
| --- | --- |
| Complete client compile | PASS |
| Executed production cases | PASS, 23 |
| Exact previous-source lifetime failures | PASS, 2 reproduced |
| Compiled producer weakening controls | PASS, 13 rejected at their expected assertions |
| Luau snippets in both updated flows | PASS, 54 compiled |
| Shared exact idle-evidence verifier | PASS, 1 valid and 8 invalid states |
| Compiled idle-verifier weakening controls | PASS, 6 rejected |
| Fist/pet safety contract | PASS, 53/53 |
| Full real UI control contract | PASS, 33/33 |
| Updated Studio flows | Pending Coordinator integration/runtime |

The production cases include held-button lifetime and scroll preservation, unrelated stats, inventory order, duplicate equip/unequip identity, locking, fusion, discovery/pity, premium ownership/price, Delete first-click safety/second-click identity/timeout/slot removal, reward readiness and claims, UTC rollover, countdown changes, tutorial changes, navigation, missing content, compact layout/UI scale, and obsolete canvas jobs. Each changed producer control must compile before it runs; syntax failures do not count as rejected behavior. Baseline failures must reach the specific button-lifetime assertion rather than an unrelated mock error.

Normalized source SHA-256 at source handoff: `d912b1d6b093083da935c1ade5cf059ed9a18fe06283bfb0c45b768b1c21e690`.
Extracted producer SHA-256: `241df948e4dc29f4487586de3e7c4c473db95e0b4bc61eef63cd2a1f7ab4f8d5`.

## Real-input flow changes and limits

Before the first legacy Equip gesture and the Tasks Daily claim, each flow now subscribes to the actual StatsChanged event and waits at most three seconds for increasing PlaytimeSeconds. It verifies that the original button survived, CanvasPosition stayed stable, no structural render or tracked server request occurred, and the current button remains fully contained, visible, active, selectable, interactable, and topmost. Both temporary listeners disconnect on success or failure. Only serializable evidence crosses tool calls.

The six legacy gestures and twenty-five full UI gestures remain unchanged. There are no additional clicks, retries, injected Activated calls, remote replacements for UI actions, or fixture changes to authority. Existing exact-slot request/result checks, locked Delete, first-click safety, timeout, second-click deletion, exact claim rewards, and Settings request sequence remain mandatory.

These mocks prove the listed source contracts; they do not reproduce Roblox physics, every device's input scheduling, or a measured performance improvement. The observed native before-trace is Coordinator evidence. The updated flows must run against the integrated source in Studio before this runtime gate can be marked passing.
