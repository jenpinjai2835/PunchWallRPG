# Mobile Shop readability handoff — 2026-09-06

Agent HQ: `SMASH-20260906`, Agent 2 mobile Shop implementation.
Branch: `codex/feature/smash-shop-20260906`; base: `1e1fed1`.
Owned source: `work/punch-wall-rpg/src/client/PunchWallClient.client.lua`.

## Changed behavior

- HUD layout and Shop signature/header/cards resolve one viewport through
  `shared.PunchWallGetResponsiveViewport`. When Studio's Camera size disagrees
  with the safe ScreenGui root, both use the actual root dimensions.
- Compact Shop and Inventory modal hosts fill the available viewport with
  12 pixels on each edge. Shop no longer imposes a 1.72 aspect ratio, and the
  Inventory host no longer imposes the 1.5–2.1 aspect clamp. The Inventory worker
  owns removing the additional inset inside `InventoryUI`; this host change
  alone does not finish Inventory layout.
- All five compact Shop pages use one column of 112-pixel product rows. Art has
  a separate 64-pixel square below 520-pixel viewport width and a 76-pixel square
  on wider compact screens. Small perimeter labels over fist art are hidden in
  compact rows; actual fist asset replacement belongs to the Coordinator.
- Names retain their full configured display name, wrap onto two lines, and
  have a 14-pixel minimum/16-pixel maximum. A visible 14-pixel summary explains
  the item's power, currency, spin quantity, or boost duration. Rarity is 12
  pixels. Price and action labels are at least 14 pixels; actions are 112×48.
- Narrow rows give art, name, summary, rarity, price, and action separate
  rectangles. Wider compact rows keep name/summary in the middle and price/action
  on the right. These arrangements keep purchase state, Depth lock, owned,
  equipped, and boost countdown behavior on existing controls.
- Shop tabs keep readable 14-pixel labels and 48-pixel height. They scroll
  horizontally when the minimum 96-pixel tab widths cannot fit. The footer shows
  item count and a scroll hint.

## Preserved integration contracts

No camera code, purchase callbacks, RemoteEvent dispatch, product identifiers,
catalog item/control names, server progression, or persistence paths changed.
The integrated Depth signature and incremental Boost countdown fixes remain.
Same-page structural Shop refreshes still preserve the product scroll position.

The neutral Inventory host is unscaled and passes `mainPanel.AbsoluteSize`
to `InventoryUI:ApplyResponsive` as before. The module owns its internal scale,
text floors, content layout, cached cards, and selected drawer.

New diagnostics for runtime acceptance:

- `ShopCompactLayout` / `ShopCatalogScrollMode`: `MobileReadableRowsV1`;
- `ShopCardLayout`: `ReadableFullWidthRowV1`;
- `ShopCatalogColumns`: 1 in compact mode;
- `ShopCompactCardHeight`: 112;
- `ShopMinimumPrimaryTextSize`: 14;
- `ShopMinimumSecondaryTextSize`: 12;
- `ReadableTextRole=Primary` on item name, summary, price, and action;
- `ShopModalSizing` / compact `InventoryModalSizing`: `PhoneSafeFill12V1`.

## Worker checks and remaining gates

PASS: full client compilation with restored official Luau 0.737
`luau-compile.exe --null`; focused source review; `git diff --check`.
Worker ownership does not include tests or Studio, so no runtime or visual pass
is claimed. The Coordinator owns updates to old dense-layout assertions,
integrated flow runs, snapshots, actual rendered text/bounds checks, and final
desktop/mobile verification.

Old contracts intentionally requiring five Inventory columns, Shop row height
86, half-scale text, or 6–8-pixel primary labels must be replaced by current
readability/bounds requirements. The extracted camera/Shop function fixture also
needs `shared.PunchWallGetResponsiveViewport` available in its adapter because
the production state-signature function now uses the shared resolver.

The earlier `camera-shop-stability.json` fixture seeded `CoinBoostExpiresAt`
and searched for `CoinBoostAction`. The current coin-paid Boost catalog contains
only Speed and Damage; the Coordinator was notified to use `SpeedBoostExpiresAt`
and `SpeedBoostAction`. This is a fixture correction, not a catalog change.

Validate 320/360-pixel narrow widths, 740×360, 844×390 and iPhone17 landscape,
tablet and desktop, then all purchase availability states, long names/numbers,
scroll retention, countdown expiry, real tab/action input, safe areas, and
runtime/post-stop console. Model artwork and physical-device frame pacing are
separate gates and remain unproven by this source-only handoff.
