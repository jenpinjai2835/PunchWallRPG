# Premium Fist Game Pass configuration — 2026-08-19

Experience: Smash Wall (`10490793155`)

| Game Pass | ID | Base price | Permanent grant |
| --- | ---: | ---: | --- |
| Crimson Vanguard Fist | `1947838143` | 49 Robux | x2.5 Fist Power |
| Stormbreaker Fist | `1951036123` | 129 Robux | x12 Fist Power |
| Celestial Titan Fist | `1951054054` | 299 Robux | x60 Fist Power |

Creator Dashboard verification:

- All three passes were created under the Smash Wall experience.
- All three sale switches were enabled.
- The displayed names and base prices matched the table above.
- No existing premium-pet Game Pass or Developer Product ID was reused.

The source configuration is `GameConfig.PremiumFists`. The client resolves the
current MarketplaceService Game Pass price and shows that live value instead of
treating the configured base price as a regional player price. Server and client
configuration helpers reject missing, fractional, or duplicate IDs across the
combined premium-fist and premium-pet catalogs.

External release gate: run a controlled purchase and rejoin in a published
private server. Confirm each pass grants once, ownership restores after rejoin,
and cancellation causes no ownership mutation.
