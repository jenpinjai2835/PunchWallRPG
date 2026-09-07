# Honor Developer Products Setup

Status: **Creator Dashboard setup and local configured-product validation complete; current visual recapture and published private/UAT purchase verification are still required**.

The four products are now configured in source with the Creator Dashboard IDs below. Local validation must verify their live identity, sale state, regional display price, receipt durability, and responsive Shop controls. Real payment and reconnect durability remain blocked until the published private/UAT purchase matrix is completed.

## Create these Developer Products

Create all four under the same Roblox experience as Punch Wall RPG. They must be **Developer Products**, not Game Passes.

| Config key | Creator Dashboard name | Honor granted | Target base price | Product ID |
| --- | --- | ---: | ---: | --- |
| `HonorPouch25` | Honor Pouch | 25 | R$29 | `3708804891` |
| `HonorCache90` | Honor Cache | 90 | R$79 | `3708804911` |
| `HonorVault300` | Honor Vault | 300 | R$199 | `3708804933` |
| `HonorTreasury850` | Honor Treasury | 850 | R$499 | `3708804944` |

Do not reuse these existing Developer Product IDs:

- `3708736246` — Hero Coin Pack
- `3708736283` — 3 Hero Spins
- `3708736312` — 2X Coins 15 Minutes
- `3708736344` — 2X Training 15 Minutes

Premium pet IDs are Game Pass IDs and cannot be used for these consumable packs.

## Verification after configuring the IDs

1. Run the Honor product static contract and full automation aggregate.
2. Sync the exact source into the named Studio instance.
3. Verify exact Marketplace product name, price, type, sale state, uniqueness, and live regional price states for desktop, 844x390, and 740x360.
4. Run one real purchase per pack in a published private/UAT server.
5. Verify exact Honor grant, receipt replay idempotency, reconnect persistence, cancellation/no-charge behavior, insufficient headroom, and runtime/post-stop console.
6. Keep an individual Shop card disabled if its ID is missing, duplicated, unavailable, or resolves to the wrong product.

Unpublished Studio sessions are intentionally ephemeral and cannot certify a real Roblox checkout or cross-session DataStore durability.

## Local verification recorded on 2026-08-19

- Creator Dashboard evidence: `work/docs/evidence/honor-products-20260819/creator-dashboard-honor-products.png` (`SHA256 6CCFD98950F8828639A0262B5DB126E23528B489B44889C668D4EB0813390C63`).
- Exact Studio: `6d29b2d4-41ab-41fb-838f-3dfd8727c725`, `PunchWallRPG_ManualPlaytest_20260818_FistAuraV10.rbxlx`, unpublished place `0`, Edit mode.
- `honor-product-receipts` passed 15/15 at the deterministic 740x360 phone profile: exact eight-product uniqueness, four Honor IDs, durable first/replay/mismatch/overflow/reconcile behavior, live card binding, compact `OPEN` / `ROBLOX` / `VERIFY` / `ADDED` state fit, cancel recovery, clean runtime/post-stop console, and checked simulator cleanup.
- `developer-product-configuration` passed 11/11 and `product-completeness-purchase-availability` passed 11/11 against the current configured catalog.
- Static aggregate passed: Node 42, PowerShell 18, Luau 27, flow JSON 112, Honor product contract 14/14, product completeness 26/26, and persistence 28/28.
- Marketplace regional prices returned for the test account were Pouch `R$25`, Cache `R$59`, Vault `R$145`, and Treasury `R$359`. Raw live-name/price/sale-state evidence is stored in `work/docs/evidence/honor-products-20260819/marketplace-regional-price-probe.json`. The Shop must display these live prices instead of the Dashboard base prices.

## Required blocked gates

- **Current visual recapture is BLOCKED by tooling:** the Studio MCP `screen_capture` request repeatedly timed out after the live-ID change, and the Windows capture fallback failed with `SetIsBorderRequired failed: No such interface supported (0x80004002)`. The exact blocker is recorded in `work/docs/evidence/honor-products-20260819/current-visual-capture-blocker.txt`. The existing three Honor product JPGs and `capture-summary.json` were recorded before live IDs were configured and show `UNAVAILABLE` / `NOT READY`; they are stale and must not be used as current acceptance evidence.
- **Real commerce is NOT RUN:** no real Robux charge was initiated from this unpublished Studio place. Run the published private/UAT matrix for prompt identity and price, cancel/no-charge, exact 25/90/300/850 grants, receipt replay, insufficient-headroom rejection, rejoin persistence, and client/server console checks.
