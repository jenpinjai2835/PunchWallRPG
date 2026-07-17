# Smash Wall Monetization Setup

## Current State

The game contains the complete UI, world advertisements, server ownership
checks, Game Pass purchase prompts, Developer Product receipt handling, and
Studio-only deterministic test grants. The local place is not published, so all
dashboard IDs intentionally remain `0` and no live checkout prompt is issued.

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

| Config entry | Suggested price | Grant |
| --- | ---: | --- |
| `CoinPack` | 29 Robux | 7,500 Coins |
| `SpinPack` | 39 Robux | 3 Spin credits |
| `CoinBoost` | 49 Robux | 2x Coins for 15 minutes |
| `TrainingBoost` | 59 Robux | 2x Training for 15 minutes |

Create one Developer Product per row, then set its ID in
`GameConfig.PremiumProducts[*].productId`. Receipt grants are server-side and
idempotent through Roblox `ProcessReceipt`; never grant these from a client
button callback.

## Publish Checklist

1. Publish the place into the intended Smash Wall experience.
2. Create the three Game Passes and four Developer Products in Creator Dashboard.
3. Put the seven IDs into `src/shared/GameConfig.lua` without changing prices or grants.
4. Rebuild the final `.rbxlx` with `embed-source-into-rbxlx.ps1`.
5. Test purchases in a private published server with a low-value test account.
6. Confirm permanent fists restore after rejoin and each consumable receipt grants exactly once.

Do not enable live ads that promise a purchase until every corresponding ID is
non-zero and its dashboard item is on sale.
