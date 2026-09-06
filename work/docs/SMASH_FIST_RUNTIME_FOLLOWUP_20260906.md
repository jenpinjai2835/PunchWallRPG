# Fist runtime observation follow-up — 2026-09-06

Base: `0b061fb`. Scope is four existing flows only. No source or Studio operations were performed by this worker.

## Failure reconciliation

The initial actual R6 and R15 first-five matrices both passed, including actual shoulder motion, release-frame recovery, geometry, scale, and wrist attachment. One final normal respawn failed its strict hand-width scale assertion. The subsequent complete rig-parity rerun passed. This does not establish that the source is correct under late appearance growth.

The source has a concrete delayed-size trigger: `PunchWallBootstrap.server.lua:2126` applies character growth after appearance readiness, records `PowerGrowthPower`, and is scheduled 0.65 seconds after CharacterAdded (`:2558–2574`). Client catalog construction uses the current hand width once (`PunchWallClient.client.lua:5664`). Its visual signature (`:6652–6656`) does not include hand size, and there is no size/growth-completion observer. This possible persistent stale scale was reported to the Coordinator for a separate source repair. The flow continues to reject a wrong scale after growth completes.

The old Shop idle assertion could observe initial camera fitting or offscreen preview disposal. `AddCatalogFistPreview` (`PunchWallClient.client.lua:10909–10973`) refits when actual viewport size changes and recreates geometry when visibility changes. The Creator Store flow called `inspectShopCard` directly, bypassing the 0.45-second wait added inside `inspectRegularShop`; it still failed after the full imported-equipment matrix had passed.

## Updated observations

- Shop readiness now observes actual host, Shop, scroll, card, and viewport bounds instead of a fixed host sleep. It requires a stable, nonzero layout within six seconds.
- Native preview readiness observes exact model/camera/part identities, every part's pose and size, camera pose/FOV, and actual corner projection. A separate 0.3-second idle interval begins after 0.2 seconds of stable readiness. A real resize restarts the layout observation; rotation, replacement, disposal, or non-palm movement during idle with unchanged layout fails. Continuous resize/rebuild/camera loops time out rather than being accepted.
- `RenderLoop=false`, native/fallback routing, item identity, complete geometry, and projection checks remain in place. Readiness records show layout, camera, and model changes separately.
- Normal respawn observes current server `PowerGrowthPower`, completed appearance/growth flags, stable real hand dimensions and model identity, then runs the unchanged strict scale/bounds/weld checks. There is no forced refresh or re-equip. A permanently wrong scale still fails within ten seconds with scale/growth diagnostics.

## Offline verification

- PASS: all 27 actual Luau payloads compile with official Luau 0.737.
- PASS: all twelve server steps and both actual R6/R15 punch matrices compare unchanged against `0b061fb`.
- PASS: twelve controls execute the exact shared preview observation functions extracted from the three flows. They cover legitimate initial/late resize, idle duration, continuous camera loop, model/camera replacement, non-palm movement, clipping, disposal, zero area, and continuously changing host layout.
- PASS: eight controls execute the exact normal-respawn observation function extracted from both restore steps. They cover delayed growth plus repair, stable body/model observation, permanent bad scale, bounded deadlines, missing growth readiness, wrong identity, and character replacement.
- PASS: helper equality checks prevent the duplicated flow implementations from drifting; strict scale and bounds assertions are retained.
- PASS: `git diff --check`.

Actual Studio reruns are **PENDING Coordinator integration**. The separately reported late hand-size source issue remains a source-validation dependency; these readiness changes are not evidence that it is fixed.
