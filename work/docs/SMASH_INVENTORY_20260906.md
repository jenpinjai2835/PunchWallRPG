# Smash Wall Inventory mobile completion — 2026-09-06

Owner: HQ agent-1. Base: `1e1fed1`. Worktree: `F:/Roblox/PuchWall-inventory-20260906`.

## Implemented

- Compact Inventory fills the already-safe, unscaled modal host. `Window.Size = viewport / UIScale`; the former extra 40 × 48 inset and minimum-size squeeze are removed. The main client owns the outer 12 px margin and safe viewport selection.
- Compact items use 92 px horizontal rows with a 76 px preview. The actual rendered grid content width selects two columns at 600 px or above, otherwise one column. Names have a 14 px rendered minimum, secondary labels 12 px; selection targets retain the 44 px minimum through 80–120% UI scaling.
- Name, rarity, state and quantity occupy separate regions. Narrow category buttons omit the decorative icon and show `BOOST` for the Boosts category. Narrow search fields hide their glyph, reclaim padding and use the short `Search` placeholder.
- Compact details use up to two action columns. Landscape layouts reserve a separate close-button column; portrait layouts place actions across the bottom. Names and action labels retain readable font sizes. The internal/server identifier line is hidden in compact detail. Desktop settings are restored when returning to a wide layout.
- Existing item/action pools, event callbacks, search/filter data, selection keys and grid canvas position remain in place. Responsive changes do not recreate cards or reset scrolling.
- Optional `BuildFistPreview(fistName)` returns a Model or nil. Successful models are cached per catalog name and cloned into the existing card/detail viewport; unsupported names and errors retain existing art. The camera targets the model bounding-box center from its +Z backhand side. Clones are anchored, noncolliding and stripped of scripts/effects. Switching pets/fists clears the previous clone and identity; destruction releases both master caches.

## Integration contract

The main client supplies `mainPanel.AbsoluteSize` from the safe modal host and the user UI scale. Agent-2's host change is `f46015a`. The coordinator supplies `BuildFistPreview`, resolving `GameConfig.FistDefinition(name)` and returning `FistVisualBuilder.BuildCatalogModel(definition)`'s first result. Shared builder change: `07783bf02da29c65c5025b48524b3c701fc45d55`. Unsupported catalog entries intentionally use the existing image/atlas fallback.

Diagnostic attributes now identify `PhoneReadableRowsV6` / `HorizontalPreviewV5`, the rendered grid width, and the primary/secondary rendered font sizes. The grid/card viewport retains its existing instance name to preserve pooled references.

## Worker verification

- [x] Source implementation and focused review: host bounds, scale transitions, compact action placement, card/quantity separation, preview lifecycle and cache cleanup.
- [x] Luau 0.737 full compilation at `-O0`, `-O1` and `-O2`; `git diff --check`.
- [x] Extracted production `ApplyResponsive` executed under Luau with UI-value mocks: **1,920 assertions**, ten supplied-host sizes (including 296 × 716 and 716 × 260), scales 0.8/1/1.2, and one through four actions. Checks cover exact host fill, 92 px rows, breakpoint, font floors, state/scroll preservation, action bounds/targets and desktop restoration.
- [x] Extracted production preview/cache/destruction methods executed under Luau: **21 assertions** for master reuse, clone reuse, card/detail sharing, physics/script/effect cleanup, camera target/side, pet/fist switches, unsupported/error fallback and destruction.
- [x] Existing offline `inventory-runtime-cache-contract.mjs`: **16/16**.

Temporary executable harnesses are `C:/Users/Jennarong Pinjai/AppData/Local/Temp/smash-inventory-layout-check.mjs` and `smash-inventory-preview-check.mjs`. They extract the current production Luau; they do not emulate font rendering or Roblox UI layout itself. Shared automation files were outside this worker's allowed write scope.

## Required coordinator checks / limitations

- **BLOCKED pending shared test update and combined run:** `inventory-visual-responsive-contract.mjs` still asserts removed compact minimum/inset source strings; `inventory-card-render-contract.mjs` still asserts the old direct `_applyPetPreview` call rather than `_applyModelPreview`. Those old tests currently fail and must be updated to the accepted new contract, not counted as passing.
- **Pending coordinator runtime:** real Studio mobile rendering, text bounds/long labels, drawer actions, search/filter, selected-card/scroll persistence, pet/fist preview and pool counts. The worker's attempted legacy performance wrapper was stopped after discovering it calls Studio; no runtime result is claimed. Coordinator was notified immediately.
- Description visibility remains bounded by available drawer height. Extremely short/narrow dimensions beyond the tested host matrix have not been established as usable. Real device frame rate, model appearance and final UI visual acceptance require runtime evidence.

This commit is eligible for integration after dependency handoff; overall release readiness belongs to the coordinator's combined verification.
