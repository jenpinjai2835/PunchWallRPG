# Legacy Shop and Inventory flow reconciliation — 2026-09-06

Owner: Agent 2, Coordinator-assigned scope. Branch: `codex/test/smash-legacy-shop-20260906`, base `9943d91`. Only the five assigned flows and this note were changed. No gameplay source, shared contracts, registry, HQ or Studio was modified.

## Source and runtime basis

| Flow | Initial combined-suite failure | Current source and updated assertion |
| --- | --- | --- |
| `hero-city-pixel-perfect-hud` | Received 16 cards/actions/art and five tabs; expected five/four. | `GameConfig.Fists` has 16 entries; client line 10603 defines Fists/Premium/Boosts/Honor/Robux. The ordinary `OpenTab` route must expose all 16 exact item keys and all five named tabs. Touch checks now measure actual dimensions. |
| `hero-shop-reference-polish` | All 16 cards were present at height 154; obsolete scroll lookup returned nil. | Client line 11457 creates `ShopCatalogScroll`. Lines 11440–11535 define one-column 112-pixel mobile rows and desktop two-column cards. Premium/Robux lookups recurse into the compact scroll host. Lines 11390–11396 define only SpeedBoost and DamageBoost on Boosts; the four Robux offers are filtered from `PremiumProducts` by `shopPage`. Desktop Premium feature geometry remains required. |
| `long-run-catalog-progression` | 16 cards/actions and all gate states passed, but obsolete scroll name produced zero canvas/viewport. | Uses the live scroll host and measured positive scroll/canvas sizes. Scrolling to the end must bring the real Ascendant Hero card fully into the viewport with its authoritative action bound. Existing progression, cost, ownership and pet checks remain. |
| `inventory-menu-ui` | Actual safe bounds passed, but the sizing attribute was `PhoneSafeFill12V1`. | Client lines 12762–12769 fill the measured safe viewport minus 24 pixels, without aspect compression. InventoryUI lines 4021–4044 select two columns at an available rendered grid width of at least 600, otherwise one. Primary/secondary rendered floors remain 14/12. The timed-detail expectation follows actual description visibility: visible text uses `SelectedDetailHeartbeat`; hidden text uses `ExpiryDelay`. Card, connection and expiry stability assertions remain. |
| `honor-product-receipts` | Correct live prices and BUY controls, but each aggregate `exact` predicate failed. | Review found a real compact quantity omission: client lines 11992–12018 replaced the amount with the pack name, HONOR rarity and a gate reminder. Coordinator corrected the visible title in `eb2e184`. The flow still requires the exact visible quantity; it now checks each real card after scrolling it into view, actual numeric price text against live Roblox price, product identity, font/fit/touch properties and safe action state. Each predicate and its measured fields are reported separately. |

Honor's old requirement to repeat the quantity in a hidden/replaced description was removed because quantity is now carried by the visible title. The description must still show the relic-gate statement. The actual quantity, rendered price, live product IDs, sale/configuration status, action binding and exactly-once receipt checks were not weakened. Short purchase-state labels are checked through their actual text bounds and readable font, rather than the obsolete `TextWrapped=false` implementation setting.

## Verification

- [x] Parsed all five JSON flows and compiled all 71 actual Luau payloads with the restored Luau 0.737 compiler.
- [x] Compared all 22 Server payloads, including their labels, against `9943d91` using parsed JSON equality: unchanged. This includes first receipt, replay, mismatch, overflow, reconciliation, progression boundaries and authoritative inventory mutations.
- [x] Executed the actual `evaluateHonor` function extracted from the flow with four valid products and 16 negative controls: missing/wrong/hidden/clipped quantity, stale rendered/attribute price, wrong product ID/key, unresolved price, hidden price/action, disabled action, tiny font, undersized target, unavailable product and incorrect tier pips. All 20 controls passed.
- [x] Executed the actual safe-fill flow payload with five controlled geometries: valid safe fill passed; old aspect compression, duplicate inset, out-of-bounds position and 1×1 viewport were rejected.
- [x] Executed the actual Fists layout payload with seven controlled catalogs: valid desktop and mobile layouts passed; old compact geometry, missing scroll host, inaccessible overflow, zero viewport and missing final fist were rejected.
- [x] `git diff --check` passed.
- [ ] Coordinator integration and Studio reruns remain required. This worker did not run Studio. The Honor presentation assertion intentionally fails source that lacks the Coordinator's `eb2e184` quantity fix.

The 32 executable controls used the committed flow functions/payloads with temporary Luau mocks, then removed only their own temporary files. They validate that the rewritten predicates reject the old failures; they do not claim a rendered Roblox pass. Initial runtime evidence remains under `work/docs/evidence/smash-full-suite-20260906/` in the integration worktree.
