# Smash Wall Monetization Setup

## Current State

The game contains the complete UI, world advertisements, server ownership
checks, Game Pass purchase prompts, Developer Product receipt handling, and
Studio-only deterministic test grants. All three premium-fist Game Passes,
three premium-pet Game Passes, and eight consumable Developer Products are
configured from the Smash Wall Creator Dashboard.

## Permanent Fist Game Passes

| Config entry | Game Pass ID | Dashboard price | Benefit |
| --- | ---: | ---: | --- |
| `Crimson Vanguard Fist` | `1947838143` | 49 Robux | Permanent x2.5 fist multiplier |
| `Stormbreaker Fist` | `1951036123` | 129 Robux | Permanent x12 fist multiplier |
| `Celestial Titan Fist` | `1951054054` | 299 Robux | Permanent x60 fist multiplier |

These are permanent Game Passes. Never reuse their IDs for Developer Products
or premium pets. Player-facing prices must come from MarketplaceService so
regional pricing remains truthful.

## Consumable Developer Products

| Config entry | Dashboard product | Product ID | Base price | Grant |
| --- | --- | ---: | ---: | --- |
| `CoinPack` | Hero Coin Pack | `3708736246` | 29 Robux | 7,500 Coins |
| `SpinPack` | 3 Hero Spins | `3708736283` | 49 Robux | 3 Spin credits |
| `CoinBoost` | 2X Coins 15 Minutes | `3708736312` | 49 Robux | 2x Coins for 15 minutes |
| `TrainingBoost` | 2X Training 15 Minutes | `3708736344` | 59 Robux | 2x Training for 15 minutes |

The base prices above are retained for configuration auditing. Player-facing
custom UI must display the live `PriceInRobux` returned by MarketplaceService,
because Roblox regional pricing can differ from the dashboard base price.
Receipt grants are server-side and idempotent through Roblox `ProcessReceipt`;
never grant these from a client button callback.

## Publish Checklist

1. Publish the place into the intended Smash Wall experience.
2. Verify the configured Game Passes and Developer Products remain on sale in Creator Dashboard.
3. Verify every ID in `src/shared/GameConfig.lua` is unique and matches its dashboard item.
4. Rebuild the final `.rbxlx` with `embed-source-into-rbxlx.ps1`.
5. Test purchases in a private published server with a low-value test account.
6. Confirm permanent fists restore after rejoin and each consumable receipt grants exactly once.

Do not enable live ads that promise a purchase until every corresponding ID is
non-zero and its dashboard item is on sale.
