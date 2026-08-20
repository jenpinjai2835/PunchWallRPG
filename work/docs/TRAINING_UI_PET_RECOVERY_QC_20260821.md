# Training, Action UI, Inventory, Robux, and Pet Recovery QC — 2026-08-21

## Result

PASS on the integrated source and the dedicated iPhone 17 landscape Studio candidate. No known in-scope defect remains in the six requested behaviors.

This result does not mean the public place has been updated. The public fix must be published from a full rebuilt artifact so the eight sanitized pet models are included; source-only publishing is not acceptable for this change.

## Fixed behavior

- Training now validates the exact trusted station selected by the contextual action against that station's own 18-stud range. An adjacent station can no longer make a qualified request fail after the client already selected the intended station.
- Target scanning compares only real Train and Use targets. Training receives a small intent margin so a nearby fist/shop stand cannot steal the training action.
- The Action affordance is a compact dark two-line card with a small icon, action title, exact target/rate detail, bounded text, and at least a 44-pixel touch target. Train remains disabled below its base-Power threshold; real non-training Use targets remain active.
- Compact Inventory cards use a slim status rail. Rarity, Equipped, Locked, and quantity no longer cover the item/pet art; the title, search field, card names, and tags use bounded phone typography.
- Robux price values use a green currency palette. Coin prices keep the gold Coin palette.
- The release gate requires all eight preloaded, sanitized Creator Store pet templates. Missing or rejected templates make `PetVisualReleaseReady=false` rather than silently approving clay/procedural fallbacks.
- Unsupported avatar shoulder rigs use a bounded visual-only clone of the equipped fist to strike the active training station. Normal compatible rigs keep the character punch animation.

## Runtime acceptance

Flow: `work/automation/flows/training-ui-pet-recovery.json`

Result: `work/docs/evidence/training-ui-pet-recovery-20260820/flow-result.json`

- PASS 26/26 on exact Studio instance `8e0ad201-e63b-44d9-b20c-38e9957106e0`.
- Exact place: `SmashWall_TrainingUIPetRecovery_QC.rbxlx`, `placeId=0`, Edit mode.
- iPhone 17 simulator envelope: 874x402 landscape.
- Power 1,499 with extreme fist/pet multipliers: Iron remains locked and no delayed payout occurs.
- Power 1,500: exact Iron station starts through the production request route and pays +40 Power/s.
- A deliberately unsupported shoulder rig produces the equipped-fist strike fallback; temporary strike models are cleaned.
- A real nearest non-training Use target remains active and follows the production request path.
- Eight pet definitions render eight exact preloaded model previews with zero tag/art overlap.
- Three Premium Shop cards use real pet previews and green Robux price text.
- Runtime and post-stop consoles are clean except for the expected unpublished-session warning.
- Device simulator cleanup restored `default=true` and removed the one custom device.

## Visual evidence

Manifest: `work/docs/evidence/training-ui-pet-recovery-20260820/capture-summary.json`

- `01_iphone17_training_action.jpg` — readable dark two-line training prompt over the live world.
- `02_iphone17_inventory_pets.jpg` — five-column compact pet inventory with unobscured model art.
- `03_iphone17_shop_premium.jpg` — Premium Shop with distinct Phoenix/Wyvern/Guardian previews and green Robux prices.
- `04_iphone17_premium_companions.jpg` — three distinct Premium companion silhouettes in the live formation.

The manifest records SHA-256 for five runtime sources, the focused flow, focused contract, capture script, flow result, and all four images. All five Studio source fingerprints match the local source. Runtime and post-stop consoles are clean, and simulator cleanup passed.

## Static regression

Command:

```powershell
powershell -ExecutionPolicy Bypass -File work/automation/run-automation-static-contracts.ps1 -LuauCompileCommand C:/Temp/codex-luau-0.730/luau-compile.exe
```

PASS:

- Node syntax: 49 files
- PowerShell syntax: 19 files
- Luau compile: 27 cases across 9 files and three optimization levels
- Flow JSON: 115 files
- Non-Studio static contracts: 26/26 executed, including `trainingUiPetRecoveryContract` 20/20
- `inventory-performance-contract.mjs` remains intentionally excluded from the non-Studio aggregate because it is a Studio-capable benchmark, not a static contract.

## Release requirement

Before updating the public place:

1. Rebuild the full canonical `.rbxlx` from this accepted source while preserving the eight sanitized `PunchWallExternalAssets` pet templates.
2. Verify exact source embedding and the global code-object allowlist.
3. Run the final artifact smoke/regression against the rebuilt file.
4. Publish the full artifact, then verify a fresh public server reports `PetVisualReleaseReady=true` and visually shows the Premium pets.
