# Smash Wall v1.0.4

## Status

Published Public on 2026-08-21.

- Universe: `10490793155`
- Place: `125255969070601`
- Published place version: `18`
- Previous published version: `16`
- Public URL: `https://www.roblox.com/games/125255969070601/Smash-Wall`
- Source commit: `67d46d02014b538d5da12e34ee0ceb828d1aab6b`
- Release artifact: `outputs/releases/v1.0.4/SmashWall_v1.0.4.rbxlx`
- Artifact SHA-256: `FC6AFC0616A739D074AF030D37FA0D2396568A75925D31841F09D47ACB613264`

## Player fixes

- Training unlocks from the same effective Power displayed by the HUD; the reported Iron-station false lock is fixed.
- Crimson Phoenix, Storm Wyvern, and Celestial Guardian use their original detailed sanitized models in Shop, Inventory, and companion formation.
- Unsupported avatar rigs use a visual equipped-fist strike while training.
- The requested player profile was reset to a new-player gameplay state while preserving receipt integrity and platform entitlement reconciliation.

## Acceptance

- Focused final-artifact runtime flow: PASS 26/26.
- Focused contracts: training progression 21/21, training/pet recovery 23/23, Creator Store pets 12/12.
- Full non-Studio aggregate: PASS — Node 54, PowerShell 19, Luau 27, flows 116, and all 27 safe contracts.
- Exact-source/global code allowlist: exactly 9 canonical code objects, 0 extras.
- Final, validation, and v1.0.4 release artifacts are byte-identical.

## Public publish verification

Studio saved the accepted final place as version 17. The exact Studio-serialized binary was then published through the official Roblox Place Publishing endpoint as version 18. Creator place history reports version 18 as published. The downloaded published payload is byte-identical to the uploaded payload:

- Serialized bytes: `734944`
- SHA-256: `F01FED983EF5A484BD97D9FB66DE38B32CD034B419BC6F4640A38A0422086D8E`

The temporary publishing API key was restricted to this universe and `universe-places:write`, then deleted after verification.

Machine-readable publish evidence: `work/docs/evidence/release-v1.0.4/publish-summary.json`.
