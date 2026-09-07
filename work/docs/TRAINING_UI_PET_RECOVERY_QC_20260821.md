# Training, Action UI, Inventory, Robux, and Pet Recovery QC — 2026-08-21

## Result

PASS on the integrated source and rebuilt final artifact at the iPhone 17 landscape envelope. No known in-scope defect remains in the requested training and Premium-pet behavior.

## Training qualification fix

- Training qualification now comes from the server-authored `TrainingQualificationPower`, derived from the canonical effective-Power policy used by the HUD.
- Station start, periodic tick, profile load, and world-reset restoration all resolve the same selected station and qualification value.
- Client contextual actions consume the replicated server qualification rather than reinterpreting raw `leaderstats.Power`.
- Raw Power 1,400 remains correctly locked. The public repro case — raw Power 1,499 with a fist multiplier and displayed effective Power above 1.5K — starts Iron and pays exactly +40 Power/s.

## Premium pet recovery

The original detailed visual-only Creator Store models are restored:

- Crimson Phoenix — asset `86478691482535`, creator `IAmASwedishMale`.
- Storm Wyvern — asset `83562531232957`, creator `XzG0ldeneJGlitchQJCy`.
- Celestial Guardian — asset `121956330907081`, creator `SirRioter`.

All imported behavior was removed: Script, LocalScript, ModuleScript, Sound, Tool, Remote/Bindable objects, ClickDetector, ProximityPrompt, Humanoid, AnimationController, Animator, and Camera. Remaining visual parts are anchored and non-colliding. The Wyvern invisible root was collapsed and its mesh content was restored for the release builder.

The former blocky Premium stand-ins remain only as distinct normal long-play pets under the names Thunder Roc, Frost Hydra, and Solar Kirin. They no longer substitute for the three paid Premium companions.

## Runtime acceptance

- Flow: `work/automation/flows/training-ui-pet-recovery.json`
- Result: `work/docs/evidence/training-ui-pet-recovery-20260821/flow-result.json`
- PASS 26/26 on exact Studio instance `dfcfb094-1c97-4365-81d8-22f53bafd763`.
- Exact place: `PunchWallRPGPlayable_v1_final.rbxlx`, Edit mode.
- iPhone 17 simulator envelope: 874x402 landscape.
- Inventory proves 8 requested pet previews; release attestation proves 11 sanitized templates including all 3 detailed Premium models.
- Unsupported avatar shoulder rigs visibly strike with the equipped-fist fallback.
- Runtime and post-stop consoles are clean except for the expected unpublished-session warning.
- Device simulator cleanup restored `default=true` and removed the custom device.

## Visual evidence

Manifest: `work/docs/evidence/training-ui-pet-recovery-20260821/capture-summary.json`

- `01_iphone17_training_action.jpg` — eligible Iron training action using displayed effective Power.
- `02_iphone17_inventory_pets.jpg` — compact pet Inventory with unobscured model previews.
- `03_iphone17_shop_premium.jpg` — Premium Shop with original detailed Phoenix/Wyvern/Guardian previews and green Robux prices.
- `04_iphone17_premium_companions.jpg` — the three distinct Premium models in live companion formation.

The manifest binds all four images, five runtime source fingerprints, the focused flow, contract, capture runner, and exact final-artifact Studio instance. All runtime sources match local files and consoles are clean.

## Player profile reset

The requested profile reset is recorded in `work/docs/evidence/profile-reset-20260821/reset-summary.json`. Gameplay progression was reset to a new-player state while the durable receipt ledger was preserved. Platform Game Pass ownership was intentionally not revoked and will reconcile normally on join.
