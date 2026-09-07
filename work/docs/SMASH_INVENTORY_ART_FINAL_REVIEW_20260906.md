# Inventory and fist art independent review, 2026-09-06

Agent 1; document-only review in `codex/review/smash-inventory-art-final-20260906`. The assigned worktree was confirmed clean at `3a4544654209cb1f7954bc7078ff7e850f6232ed` before work. No source, tests, Studio, HQ, registry or output artifact was changed.

No new actionable P1/P2 defect was established in the reviewed Inventory, Shop preview, fist geometry or equipment lifecycle. This is qualified source/test review, not fresh full-runtime or final visual approval. The Coordinator owns the next combined Studio run and release decision.

## Exact scope

Compared `4094e51..35fbdf4`, including InventoryUI, InventoryViewModel, FistVisualBuilder and relevant main-client Shop, safe viewport, preview, equipment and character-growth sections. The three modules below are identical between the assigned worktree and `35fbdf4`. The intervening main-client change adds generic Pets/Tasks retention plus the separately reviewed Scriptable guard correction; it does not change the reviewed Shop/Inventory/model functions. Modern Inventory and reference Shop still return before generic-panel retention is applied.

SHA-256 of the LF-normalized UTF-8 source at reviewed integration commit `35fbdf4`:

| Source under `work/punch-wall-rpg/src/` | SHA-256 |
| --- | --- |
| `client/InventoryUI.lua` | `b240a035847f74bc5e7301d05506cc768dc953bcd1f602dd60ff4d6b3da38d06` |
| `shared/InventoryViewModel.lua` | `a696c37178f9a582276a5953df798757862912b36b0ff0e5beebe028235f2d1c` |
| `shared/FistVisualBuilder.lua` | `634170d5fd2a0827c4c2144d9feaac3ac916783fc83ce7dc658d5734a56d81be` |
| `client/PunchWallClient.client.lua` | `8089410b1ad3207df8156b3c451025765e098868ef7bff68c97a1958e0a7c7d2` |

## Source review

Inventory master caches are keyed by catalog name. A successful preview is built once, with per-card/detail clones reused while identity remains the same. Pet/fist switches clear the old world and identity before applying the next model. Unsupported first-five callback results retain existing image fallback; invalid Instance returns are destroyed. Successful fist clones preserve shared geometry attributes, are anchored/noncolliding/nonqueryable, and lose scripts and visual effects. The production pet callback sanitizes its source and final model before Inventory receives it.

Card pools retain the largest observed snapshot and deactivate hidden cards; their callbacks read the current binding instead of a stale captured item. Action controls likewise use the current item/action binding and reject destroyed, hidden or inactive controls. Selection updates the old/new card visuals without rebuilding the grid. Authoritative data changes and filters still rebuild bindings. Closing Inventory cancels pending detail/delete work and stops timed work; destruction disconnects listeners, destroys all pooled cards, releases both master caches, and destroys the root. Hidden Inventory models remain cached deliberately; this is bounded reuse, not offscreen model disposal or proof of a specific memory budget.

The ViewModel's typed, length-framed signature includes inventory, equipped and timed-endpoint data. Relevant scalar/table replacement invalidates the configuration cache. Catalog tables are treated as immutable; intentional in-place test/hot-reload changes require `InvalidateSignatureCache`. Current-time changes are handled by visible countdown updates and cancellable expiry rebuilds rather than a new full snapshot every second. No new invalidation failure was found for the current static catalog and local native preview builder. Late replacement of externally supplied preview assets is not implemented as a live hot-reload feature.

Compact Inventory fills the already safe, unscaled modal host once. Rendered width selects one or two columns, with a 600 px two-column threshold, 92 px rows, 76 px previews, and primary/secondary text floors of 14/12 px through 0.8–1.2 UI scale. Actions retain at least 44 px targets. The compact drawer hides the grid while open, has a separate close lane in landscape, and places actions below information on narrow portrait layouts. Responsive changes preserve search, selected keys, scroll position, cards and actions. Desktop placement is restored when leaving compact mode.

Shop creates first-five models only when their cards intersect the visible scroll region. Closing/hiding the host or scrolling away destroys those models; returning recreates only the visible models. Six property listeners cover visibility, scroll/card position and actual viewport size and are disconnected on viewport destruction. No preview animation/render loop was introduced. The camera fit projects all eight model bounds corners through the preview orientation and uses both horizontal and vertical FOV, then refits on real viewport-size changes. Existing loaded fallback image art remains available for unsupported catalog entries. Authoritative page signatures and incremental boost countdown handling preserve same-page scroll and stable controls.

The first five fists use the same `BuildCatalogModel` in Shop, Inventory and equipment. Their actual part specifications are distinct closed-hand shapes with four knuckles, curled fingers, folded thumb, cuff and backhand feature. Current specifications contain 14, 15, 16, 18 and 18 parts respectively. Native preview models contain only visual parts and no imported behavior, joints or effects. Equipment scales the wrist-origin model to the actual hand width, applies the R6/R15 wrist profile, welds every part to the current hand, and measures final bounds after scaling/attachment. Aura/trail behavior stays in the equipment consumer and remains motion-aware.

The size observer handles delayed PowerGrowth and equal-sized hand replacement. A 0.05-second pending window combines a replication burst; actual dimensions plus observation/hand revisions invalidate the visual signature. Old character signals are disconnected, and deferred work checks both current observation state and current Player.Character. The existing retry remains for a missing hand. Rebuilding all companions after hand growth is a bounded existing consequence of the shared visual refresh; a separate optimization could reduce that work, but no new P1/P2 failure or measured performance regression was established here.

Imported Creator Store paths remain after the native-first-five branch. Remaining catalog fists retain the sanitized armored/smooth/fitted fallback chain; normal/premium pets retain their actual catalog template routes and procedural fallback. Sanitization checks real descendants before cloning and checks the clone again. No GameConfig asset ID or asset-manifest change occurs in this comparison, and the native branch does not delete the source asset folders. Preservation is supported by both source inspection and the recorded complete-catalog/imported-pet runs below.

## Focused offline verification

Inspected scripts before execution; no Studio/MCP or network driver was run. Commands executed in the clean assigned worktree with official Luau 0.737. Source sections exercised there are identical to the reviewed integration sections described above.

| Script under `work/automation/scripts/` | Result |
| --- | --- |
| `inventory-visual-responsive-contract.mjs --self-test` | PASS: 11 structural checks, 2,173 production-Luau layout assertions, four weakening mutations rejected |
| `inventory-model-preview-contract.mjs --self-test` | PASS: 27 production-Luau lifecycle assertions, three weakening mutations rejected |
| `inventory-card-render-contract.mjs` | PASS: 17 structural/lifecycle-simulation checks |
| `inventory-visual-fidelity-contract.mjs` | PASS: 20 structural/palette checks |
| `inventory-runtime-cache-contract.mjs` | PASS: 16 structural cache/dispatch checks |
| `fist-icon-identity-contract.mjs` | PASS: 11 checks, exact five-spec geometry execution, 17 actual flow chunks compile |
| `batch-b-fist-flow-contract.mjs` | PASS: 14 checks, six flow mutations rejected; exact hazard helper accepts eight safe fixtures and rejects 27 hazards; three helper weakenings rejected |
| `fist-growth-lifecycle-contract.mjs` | PASS: 25 production observer/lifecycle assertions |
| `fist-growth-lifecycle-contract.mjs --baseline fd845d3` | PASS: both old-source late-growth and equal-sized replacement failures reproduced |
| `fist-pet-safety-contract.mjs` | PASS: 49 checks, five fist-source and two legacy-route mutations rejected; feedback helper accepts two valid cases and rejects 14 faults, three helper weakenings rejected |
| `mobile-iphone17-layout-contract.mjs` | PASS: 28 structural and 18 measurement-helper checks |
| `device-matrix-hud-shop-contract.mjs` | PASS: eight structural device/flow checks |
| Complete four source files from immutable `35fbdf4` | PASS: Luau compilation |

These checks distinguish production execution from source assertions and simulations. They do not prove Roblox text rasterization, input hit testing, live memory consumption or frame rate. The existing Inventory performance wrapper invokes Studio, so it was not run by this worker; its separately recorded actual signature run was read instead.

## Recorded runtime and historical visuals

Read actual JSON artifacts in `F:/Roblox/PuchWall-completion-20260906/work/docs/evidence/`:

| Artifact | Recorded result |
| --- | --- |
| `smash-camera-hud-targeted3-20260906/inventory-menu-ui.json` | PASS, 51 checks |
| `smash-integrated-targeted2-20260906/first-five-rig-parity.json` | PASS, 16 checks including actual R6/R15 matrices and restoration |
| `smash-targeted-camera-20260906/creator-store-pet-pack-visuals.json` | PASS, 15 checks |
| `smash-full-suite-20260906/first-five-fist-presentation.json` | PASS, 14 checks |
| `smash-full-suite-20260906/item-matched-fist-visuals.json` | PASS, 10 checks |
| `smash-full-suite-20260906/inventory-visual-responsive.json` | PASS, 20 checks |
| `smash-full-suite-20260906/inventory-persistence.json` | PASS, seven checks |
| `smash-full-suite-20260906/inventory-pet-icons-fusion.json` | PASS, 13 checks |
| `smash-inventory-signature-runtime-20260906.json` | PASS, actual signature contract and warmed benchmark gate |

Those are previously recorded runs, not reruns by this worker or a substitute for the Coordinator's fresh combined suite. Earlier source notes documenting a growth/readiness blocker are superseded only where the later implementation and passing runtime evidence actually cover it.

Inspected `smash-new-shop-phone-20260906.png` and `smash-new-inventory-phone-20260906.png` as historical design evidence. The 874 × 402 Shop capture shows readable full-width product rows, separate title/power/price/action regions, visible tabs/close button and clipped next-row content indicating scrolling. The Inventory capture shows two horizontal columns, distinguishable fist previews and readable item names, rarity and equipped status; its search/category controls are inside the modal. Neither image shows an expanded detail drawer or proves every narrow-width/action state. They precede later geometry refinements and are not labeled final fresh screenshots.

## Handoff and remaining gates

Checklist: clean worktree and exact source/diff review complete; focused offline checks and historical evidence review complete; document-only handoff complete. No new source defect is requested from this review. Required fresh combined Studio verification remains with the Coordinator and must be reported BLOCKED if unavailable or failing. Real phone performance, sustained crowded/maximum-inventory behavior, two-player visual/network interaction, live commerce/persistence and final published-place appearance are not established by this review.
