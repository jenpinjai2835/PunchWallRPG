# Inventory mobile and preview QA — 2026-09-06

Owner: HQ agent-1. Base/source under test: `d87d7d0`. Branch: `codex/test/smash-inventory-qa-20260906`.

## Checklist

- [x] Replace obsolete responsive assumptions and port the temporary production-Luau layout/preview tests into durable offline scripts.
- [x] Run the four owned contracts, including mutation checks that prove representative regressions fail.
- [x] Commit the five owned files and hand off for coordinator integration and combined runtime validation.

## Changed contracts and results

| Script under `work/automation/scripts/` | Result | Scope |
| --- | --- | --- |
| `inventory-visual-responsive-contract.mjs` | 11 structural checks + 2,173 production-Luau assertions; 4 mutation checks | Removes the duplicate JavaScript layout implementation. Executes the current production toolbar allocator and `InventoryUI:ApplyResponsive` under Luau. |
| `inventory-model-preview-contract.mjs` | 27 production-Luau assertions; 3 mutation checks | New durable execution of the production pet/fist preview cache, render and destruction methods. |
| `inventory-card-render-contract.mjs` | 17 checks | Retains selection, pool, timer and state guards; updates preview dispatch expectations to `_applyModelPreview` with fallback art. Its existing JavaScript lifecycle simulation remains a simulation. |
| `inventory-visual-fidelity-contract.mjs` | 20 checks | Updates font/header and compact two-column action expectations while retaining palette, semantic state, pet identity and desktop hierarchy checks. |

The layout matrix covers ten supplied-host sizes, including 296 × 716 and 716 × 260, UI scales 0.8/1/1.2, and one through four actions. It checks exact host fill, 92 px cards, the rendered-width column rule, 14/12 px text floors, action bounds and touch targets, card/action pool counts, selected key/search/scroll preservation and desktop restoration. Additional tests exercise both sides of 600 px at each scale, the exact 600 px boundary at scale 1, and production desktop/compact toolbar allocation.

The preview tests check shared-master and same-clone reuse, card/detail sharing, physics flags, script/particle/beam/trail/light/highlight removal, camera side and bounding-box center, pet/fist identity switches, absent/unsupported/error/non-Model callback fallback and destruction of cached masters.

`--self-test` injects regressions only into temporary extracted code, without editing source: a duplicate 40 px inset, 10 px primary text, an early two-column breakpoint, oversized grid cells, cloning on every render, missing anchoring and a reversed preview camera. All seven were rejected by their relevant assertions.

## Reproduction

```powershell
node work/automation/scripts/inventory-visual-responsive-contract.mjs --self-test
node work/automation/scripts/inventory-model-preview-contract.mjs --self-test
node work/automation/scripts/inventory-card-render-contract.mjs
node work/automation/scripts/inventory-visual-fidelity-contract.mjs
```

The two executable contracts resolve Luau from `--luau-tool-dir`, `PUNCH_WALL_LUAU_TOOL_DIR`, repository `.tools/luau`, PATH, or installed `codex-luau-*` temporary tool directories. An explicit directory is authoritative. Missing Luau fails with a `BLOCKED` error. Each child has a 30-second timeout and its generated file/directory are removed after completion. There are no Studio/MCP/network calls.

Worker verification used official Luau 0.737. `git diff --check` passed. Source, Studio state, registries, other flows and generated release files were outside this worker's write scope and were not changed.

## Limits / coordinator gate

UI value mocks execute production placement logic but do not render text, simulate Roblox GUI pixel rounding, prove button hit testing or establish frame rate. Instance mocks establish preview lifecycle behavior; actual model geometry, art quality, full inventory actions and visual parity require coordinator Studio evidence. The existing referenced responsive flow is checked structurally, not executed here. Combined runtime verification remains pending the coordinator.
