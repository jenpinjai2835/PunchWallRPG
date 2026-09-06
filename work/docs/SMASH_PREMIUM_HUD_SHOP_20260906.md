# Shop and HUD visual refinement — September 6

Owner: Coordinator, isolated branch `codex/fix/smash-premium-hud-shop-20260906`.
Scope: main client Shop/HUD visual construction, its device-contract assertion,
and `premium-hud-shop-readability` runtime flow. InventoryUI is owned separately
by Agent 1. No economy, camera, networking or model geometry changes here.

The current source screenshots in `smash-current-source-visual-review-r2-20260906`
show many competing outlines and a large green EQUIPPED state that resembles
an available action. The Inventory image also retains bright scenery behind
the modal. These are actual Studio captures. The file named fresh-hud is an
entitlement-bearing startup, not a no-entitlement new-player example.

Changes use a shared navy menu surface, one subdued outer border, invisible
extra header/edge rails, a quiet equipped status, and the existing shared rarity
colors. Premium keeps its gold fallback; unknown rarities use muted text.
Item model accents and all purchase/equip callbacks are preserved. Catalog
names have a 14px minimum on desktop as well as compact rows. Inventory now
uses the same full-viewport dimmer as Shop, which disappears on close.

The objective shows the next action with a 14px floor instead of duplicating
the objective prefix and detailed instruction in a small card. The waypoint
still supplies navigation, while the underlying tutorial information remains
available to the existing UI. Phone objective width reserves space for side
controls; full runtime bounds and readable text remain required.

Local validation: full client O2 compilation; device matrix contract 8/8;
camera/shop/depth/boost contract 17 assertions; client runtime performance
contract 28/28; onboarding contract 32 assertions and seven negative controls;
`git diff --check`. Updated exact source-string contract now requires the
stronger 14px minimum across both layouts. No runtime pass or aesthetic
acceptance is claimed by these static checks.

Required combined verification: the new actual-rendered-text/control flow,
existing device matrix/onboarding/Inventory routes, fresh current screenshots,
and the frozen full flow suite before rebuilding the final artifact. The
visual flow also checks genuine EQUIPPED versus EQUIP states, rarity semantics,
44px targets and Inventory dimmer lifetime.
