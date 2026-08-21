# Final Artifact Release QC — 2026-08-21

## Result

PASS for the rebuilt Smash Wall v1.0.4 artifact from source commit `67d46d02014b538d5da12e34ee0ceb828d1aab6b`.

| File | Bytes | SHA-256 |
| --- | ---: | --- |
| `outputs/PunchWallRPGPlayable_v1_final.rbxlx` | 6,499,801 | `FC6AFC0616A739D074AF030D37FA0D2396568A75925D31841F09D47ACB613264` |
| `outputs/PunchWallRPGPlayable_v1_final_validation.rbxlx` | 6,499,801 | `FC6AFC0616A739D074AF030D37FA0D2396568A75925D31841F09D47ACB613264` |
| `outputs/releases/v1.0.4/SmashWall_v1.0.4.rbxlx` | 6,499,801 | `FC6AFC0616A739D074AF030D37FA0D2396568A75925D31841F09D47ACB613264` |
| `outputs/releases/v1.0.4/SmashWall_v1.0.4_validation.rbxlx` | 6,499,801 | `FC6AFC0616A739D074AF030D37FA0D2396568A75925D31841F09D47ACB613264` |

All four files are byte-identical.

## Build and static gates

- Exact embedded source: PASS for all 9 canonical code objects.
- Global code allowlist: PASS, exactly 9 canonical code objects and 0 extras.
- Imported asset sanitizer and release negative guards: PASS.
- CDATA source preservation: PASS.
- Configured commerce: 6 Game Passes and 8 Developer Products.
- Full non-Studio aggregate: PASS — Node 54 files, PowerShell 19 files, Luau 27 compile cases, 116 flow files, and all 27 safe static contracts. The Studio-capable Inventory performance benchmark remains explicitly excluded.
- Focused contracts: training progression 21/21, training/pet recovery 23/23, Creator Store pets 12/12.

## Final artifact runtime

Focused flow `training-ui-pet-recovery` PASS 26/26 against exact Studio instance `dfcfb094-1c97-4365-81d8-22f53bafd763` and exact final artifact `PunchWallRPGPlayable_v1_final.rbxlx`.

Runtime checks passed:

1. Training eligibility uses the same effective Power displayed to the player.
2. A truly under-qualified player remains locked with no delayed payout.
3. The reported public repro — raw Power 1,499 plus fist multiplier — qualifies for Iron and earns exactly +40 Power/s.
4. Unsupported avatar rigs use the equipped-fist visual strike fallback.
5. Inventory shows all 8 requested pet definitions.
6. Premium Shop and companion formation use the 3 original detailed Phoenix, Wyvern, and Guardian models.
7. Release contains 11 sanitized pet templates, with clean runtime and post-stop consoles.

`run-final-artifact-regression.ps1 -StaticOnly` also passed against the rebuilt validation copy.

## Recovery

The previous published place version remains available in Roblox version history. The superseded local training/pet candidate was moved recoverably to `C:/Temp/PunchWallRPGPlayable_v1_candidate_training_pets.superseded.rbxlx`.
