# Smash Wall Monetization Setup

## Current State

The game contains the complete UI, world advertisements, server ownership
checks, Game Pass purchase prompts, Developer Product receipt handling, and
Studio-only deterministic test grants. The three premium-pet Game Passes and
four consumable Developer Products below are configured from the Smash Wall
Creator Dashboard. Premium-fist Game Pass IDs remain `0` until those passes are
created, so their checkout controls stay unavailable.

## Permanent Fist Game Passes

| Config entry | Suggested price | Benefit |
| --- | ---: | --- |
| `Crimson Vanguard Fist` | 49 Robux | Permanent x2.5 fist multiplier |
| `Stormbreaker Fist` | 129 Robux | Permanent x12 fist multiplier |
| `Celestial Titan Fist` | 299 Robux | Permanent x60 fist multiplier |

Create one Game Pass per row, then set its ID in
`GameConfig.PremiumFists[*].gamePassId`. Keep these as Game Passes because the
ownership is permanent.

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
2. Create the three Game Passes and four Developer Products in Creator Dashboard.
3. Put each new ID into `src/shared/GameConfig.lua` and verify the dashboard base price and grant mapping.
4. Rebuild the final `.rbxlx` with `embed-source-into-rbxlx.ps1`.
5. Test purchases in a private published server with a low-value test account.
6. Confirm permanent fists restore after rejoin and each consumable receipt grants exactly once.

Do not enable live ads that promise a purchase until every corresponding ID is
non-zero and its dashboard item is on sale.
