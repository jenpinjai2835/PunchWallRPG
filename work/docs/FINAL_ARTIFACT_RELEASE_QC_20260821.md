# Final Artifact Release QC — 2026-08-21

## Result

PASS for the rebuilt Smash Wall v1.0.3 artifact from `develop@a28605dacb9d3596fe2443543b1fee08856732e4`.

| File | Bytes | SHA-256 |
| --- | ---: | --- |
| `outputs/PunchWallRPGPlayable_v1_final.rbxlx` | 6,118,711 | `FB6497BE01C3DF9947F41A7B618E296E75ADA400C8083147406000ABC15B0B5E` |
| `outputs/PunchWallRPGPlayable_v1_final_validation.rbxlx` | 6,118,711 | `FB6497BE01C3DF9947F41A7B618E296E75ADA400C8083147406000ABC15B0B5E` |
| `outputs/releases/v1.0.3/SmashWall_v1.0.3.rbxlx` | 6,118,711 | `FB6497BE01C3DF9947F41A7B618E296E75ADA400C8083147406000ABC15B0B5E` |
| `outputs/releases/v1.0.3/SmashWall_v1.0.3_validation.rbxlx` | 6,118,711 | `FB6497BE01C3DF9947F41A7B618E296E75ADA400C8083147406000ABC15B0B5E` |

All four files are byte-identical.

## Build and static gates

- Exact embedded source: PASS for all 9 canonical code objects.
- Global code allowlist: PASS, exactly 9 canonical code objects and 0 extras.
- Creator Store behavior sanitizer contract: PASS, including 13 injected unsafe code objects removed and all negative guards.
- CDATA source preservation: PASS.
- Configured commerce: 6 Game Passes and 8 Developer Products.
- Full non-Studio aggregate: PASS — Node 49 files, PowerShell 19 files, Luau 27 compile cases, 115 flow files, and all 26 non-Studio contracts. The Studio-capable Inventory performance benchmark remains explicitly excluded from the static aggregate.

## Final artifact runtime

`run-final-artifact-regression.ps1` PASS against exact Studio instance `97d0f1b1-2440-48d6-83ef-273225e0181a` and exact local validation copy `PunchWallRPGPlayable_v1_final_validation.rbxlx`.

Runtime checks passed:

1. Exact nine-module source map.
2. Complete world bootstrap.
3. Client HUD, Inventory, Shop, Spin, controls, and music bootstrap.
4. Approved NPC, Power Bag, training payout, and Premium pet displays.
5. Exact eight sanitized preloaded pet templates, zero Lua source descendants, release gate ready.
6. Supplied Spin layers, vertical race HUD, and directional controls.
7. Clean runtime console and clean stop.

## Recovery

The previous canonical final, validation copy, and manifest were copied to `C:/Temp/punchwall-release-before-training-ui-pets` before replacement. Temporary QC and release-candidate builds remain recoverable under `C:/Temp/punchwall-qc-training-ui-pets` until the public publish is confirmed.
