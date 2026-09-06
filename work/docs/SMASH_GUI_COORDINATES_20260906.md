# Native GUI coordinate contract, 2026-09-06

Agent 1; base `0340f3c3fc6ebe17af27efb2d1dfe007c53d8f55`; isolated branch `codex/test/smash-gui-coordinates-final-20260906`. Allowed changes are the full-game real-control flow, its offline contract and this document. No product source, Studio, HQ, registry or other flow was changed.

The real-control flow previously compared `GuiObject.AbsolutePosition` directly with the raw viewport's nonnegative bounds. That mixed coordinate spaces. The Coordinator's actual diagnostic `work/docs/evidence/smash-settings-iron-diagnostic-20260906.json` reports:

| Observation | Value |
| --- | --- |
| ScreenGui root AbsolutePosition | `(0,-58)` |
| Settings button Absolute center | `(1236.52087,-13.6945419)` |
| GuiInset | `(0,58)` |
| Raw screen center after inset | `(1236.52087,44.3054581)` |
| Camera viewport | `(1277,780)` |
| Topmost GUI hit at Absolute center | Exact Settings button |
| Native gesture at `(1237,-14)` | Success; actual Activated observed; Settings visible |

The negative Absolute Y is valid in this observed configuration. The old `clickCenter.Y>=0` guard blocked a working control before the native gesture. The source layout is not changed to compensate for the fixture error.

## Change

All 25 prechecks now contain the same local `guiPointInViewport` helper. It adds the engine's top-left `GuiService:GetGuiInset()` value only for the raw-screen bounds comparison. Bounds include the top/left edge and exclude the right/bottom edge; zero or negative viewport dimensions fail.

The original `clickCenter` remains the input to `GetGuiObjectsAtPosition`. All actual `user_mouse_input` action objects retain the original segmented instance paths, letting the runner resolve and reuse Absolute coordinates for the balanced gesture. No transformed screen coordinates are sent to native input or GUI hit testing.

Every precheck result now reports `inputX/inputY`, `screenX/screenY` and `insetX/insetY` beside the existing visible-area/topmost/hittable evidence. The flow declares `GuiAbsoluteInputViewportInsetV1`. Existing real-input version, callback markers and authority checks remain unchanged.

The native-selection settling repair from `7314124` is preserved. Both copied `verifyIdleControlState` and `observeIdleControl` helpers are required to remain identical between this flow and the read-only legacy-slot flow. The observer waits at least 0.5 seconds and for 0.2 seconds of stable CanvasPosition, within a two-second deadline, before capturing the idle baseline. Its subsequent actual clock snapshot, original button identity, exact canvas, no structural rebuild, no request mutation and listener cleanup requirements remain intact.

## Offline validation

Command:

```powershell
node work/automation/scripts/full-game-real-ui-controls-contract.mjs
```

PASS with official Luau 0.737:

- 43 contract checks.
- 2,450 assertions execute the actual coordinate/hit-test block from all 25 flow copies across 22 geometry cases each. Cases include zero inset, actual negative-Y Settings, nonzero X/Y inset, top/left boundaries, excluded right/bottom boundaries, just-inside/outside points, empty/negative viewports, and phone dimensions.
- The executable checks capture actual `GetGuiObjectsAtPosition` arguments, proving the screen transform is not accidentally applied to native hit testing. Offscreen controls do not issue a hit query.
- Six targeted mutations are rejected: omit inset, subtract inset, apply it twice, include the outside right edge, include the outside bottom edge, or pass transformed coordinates to GUI hit testing.
- All 34 actual Luau flow chunks compile. Runtime and compile subprocesses have bounded timeouts and use temporary files outside the repository; tracked files and their temporary directory are removed afterwards.
- Both copied idle helpers remain equal and retain the original native-selection settling thresholds/order. Existing six rarity/Settings fixture and three idle-observation negative controls still pass.

Baseline comparison against `0340f3c` also confirms:

- Exactly 25 client prechecks changed; their labels, timeouts, result expectations and surrounding step metadata remain identical.
- All 25 native gesture steps remain byte-equivalent as parsed JSON, with 50 moves, 25 settle waits, 25 down/60 ms/up pairs, 25 callback attestations and no hidden retries.
- All seven server steps and cleanup remain identical; the nine expected authoritative requests are still one Equip, three claims and five Settings changes.
- `git diff --check` passes.

## Handoff

Checklist complete: exact coordinate-space cause verified from supplied actual evidence; all 25 guards corrected with executable negative controls; focused contract/compilation and baseline parity pass. The Coordinator owns the fresh complete real-input flow run. That combined runtime gate remains **BLOCKED pending rerun**; the earlier successful standalone Settings gesture is not represented as a full-flow pass.
