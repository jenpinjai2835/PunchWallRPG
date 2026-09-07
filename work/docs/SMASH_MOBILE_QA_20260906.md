# Mobile QA handoff — 2026-09-06

Agent HQ: SMASH-20260906, Agent 2. Branch: `codex/test/smash-mobile-qa-20260906`.
Base: `d87d7d0`. This change owns tests and this handoff only; no gameplay or UI source changed.

## Acceptance changes

- Replaced obsolete Shop 86-pixel / half-scale text and Inventory five-column / 6–8-pixel text requirements. Compact Shop now requires one 104–112-pixel row per product, four primary fields at an effective font floor of 14 pixels, 12-pixel rarity text, and 48-pixel purchase controls. Inventory checks actual 88–96-pixel rows, 14/12-pixel text, and one or two columns according to available width.
- Runtime checks use the safe HUD frame's actual `AbsoluteSize` and `AbsolutePosition`, then verify modal, window, grid, card, label and action rectangles against their real parents. They reject missing or degenerate viewports. The simulator's requested resolution is checked separately in Edit mode: a notched device's 874×402 raster need not equal its 750×362 safe GUI area.
- Text checks combine `TextFits`, measured `TextBounds`, and a conservative font floor. Fixed text uses TextSize multiplied by ancestor UIScales; TextScaled requires a UITextSizeConstraint and uses its minimum multiplied by the same scales. This proves the permitted size cannot drop below the floor; it does not report an unavailable engine-selected font size as measured.
- Catalogs must actually scroll to their final row. Idle Shop checks preserve the same scroll frame/card instances and CanvasPosition; Inventory checks card identity, selection and scroll through an idle update interval. Inventory's modal must fill the host without applying a second safe inset.
- The iPhone flow opens the Shop host with normal OpenTab('Fists'), then clicks the real Premium, Boosts, Honor and Robux tab controls through MCP user_mouse_input. Each page check first verifies ShopPage changed. OpenTab('Honor') is deliberately not used to select the Shop because that public route opens Inventory/Honor. The training/pet flow also clicks the real Premium tab.
- The five-device matrix opens its Shop host through OpenTab and measures bounds/scroll. Direct GameMenu.Visible / AutomationTab mutation and forced OpenShopPage refresh have been removed from these three flows.
- Removed stale Studio session UUIDs from the three changed flows. They target the named final artifact; the Coordinator must bind the verified live Studio instance at execution time.
- Existing server receipt authority, training range/qualification, eight pack plus three premium pet identities, and clean runtime/post-stop lifecycle checks remain. Unchanged HUD/toast presentation and the separate Honor runtime flow retain their existing scope.

## Offline evidence

PASS: mobile-iphone17-layout-contract: 46 checks (28 static and 18 executable Luau assertion fixtures).
The executable fixtures extract the exact runtime helper code and prove valid bounds, text and targets pass while clipped/empty text, undersized fonts after UIScale, unbounded TextScaled, off-parent or zero-size rectangles, and undersized touch targets fail. All 13 helper copies across the three flows must match the executed copy.

PASS: device-matrix-hud-shop-contract: 8 checks; training-ui-pet-recovery-contract: 23 checks; honor-product-receipts-contract: 14 checks. Combined: 91 counted checks.

PASS: all 58 embedded Luau snippets in the three changed flows and their cleanup steps compile using official Luau 0.737. PASS: git diff --check.

The executable assertion test supports LUAU_COMMAND, PATH, and discovered temporary codex-luau-* toolchains. Missing Luau fails explicitly rather than skipping execution.

## Integration gate

Required Studio/runtime/visual verification is BLOCKED pending Coordinator execution; it was outside this worker's scope. The Coordinator owns actual viewport runs, screenshots, real-click success, current source fingerprinting and combined regression. Offline results are not a visual pass. In particular, hardware scaling and device insets must be recorded from the actual run, and any TextBounds or real input failure must be investigated rather than bypassed.
