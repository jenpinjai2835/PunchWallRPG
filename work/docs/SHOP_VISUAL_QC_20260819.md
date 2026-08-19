# Shop Visual QC — 2026-08-19

## Scope

Four functional Shop pages in the exact Studio candidate:

- Fists
- Premium
- Boosts
- Robux

Studio instance: `6d29b2d4-41ab-41fb-838f-3dfd8727c725`

## Iteration record

### Round 1 — failed visual gate

- Premium companions were safely framed but too small to read as hero products.
- Compact phone layout placed the first card against/under the fixed 44 px tab target.
- The new common shell, feature-card geometry, one-location price display, and unified CTA system were otherwise readable.

### Round 2 — passed visual gate

- Premium preview distance is now bounded per silhouette: winged pets use a closer safe fit while the taller Guardian keeps more padding.
- Every premium model is fully inside a colored preview plate and remains visually distinct.
- Odd catalog rows use one intentional full-width featured card rather than an orphaned half card.
- Robux price appears once beside a compact `R$` mark; the action is consistently labeled `BUY`.
- Robux purchase actions share one green CTA language instead of unrelated rarity colors.
- Product art has a common framed area and item-specific optical sizing.
- Header content remains inside the safe margin; footer terminology is truthful (`BOOSTS`, not `COIN BOOSTS`).
- Fists, Premium, Boosts, and Robux captures contain zero visible `TextFits` failures.

## Evidence

- `work/docs/evidence/shop-visual-qc-20260819/fists.jpg`
- `work/docs/evidence/shop-visual-qc-20260819/premium.jpg`
- `work/docs/evidence/shop-visual-qc-20260819/boosts.jpg`
- `work/docs/evidence/shop-visual-qc-20260819/robux.jpg`
- `work/docs/evidence/shop-visual-qc-20260819/capture-summary.json`

## Runtime gates

- `hero-shop-reference-polish`: PASS
- `developer-product-configuration`: PASS
- `product-completeness-purchase-availability`: PASS
- `device-matrix-hud-shop`: PASS at 1920x1080, 1366x768, 1024x768, 844x390, and 740x360
- Runtime and post-stop console checks: PASS

## Decision

PASS for the Shop visual and interaction scope. The four pages now share one hierarchy, spacing system, product-art frame, price language, and action language. Real Robux charging remains a publish-time Marketplace checkout; Studio verifies configured IDs, regional prices, enabled controls, prompt routing, and authoritative grant mappings without performing a real charge.
