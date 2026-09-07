# Long-Run Fist And Pet Catalog QC — 2026-08-19

## Scope

Serial Gate 1 of 8 adds enough normal fists and drop pets for the complete
75-depth journey. This gate does not resolve the duplicate fist artwork; that
is the explicitly ordered Gate 2.

## Implemented content

- Normal fists: 5 -> 16, from Starter Fist (1x) through Ascendant Hero
  (2,800,000x).
- Fist coin prices: free through 180T Coins with strictly increasing costs.
- Fist server gates: Depth 0, 1, 9, 17, 25, 31, 37, 43, 49, 55, 60, 64,
  68, 71, 73, and 75.
- Normal drop pets: 5 -> 16, from Forest Pup (+15%) through Omega Guardian
  (+4,800%).
- Pet unlocks span Depth 1 through 75 and runtime keeps the current two-pet
  depth band for each roll.
- Pet inventory capacity: 60 -> 150; equipped slots remain three and fusion
  remains five stars.
- Every new pet definition points to an already extracted, sanitized visual
  template from Creator Store pack `70715599928632`; runtime applies its own
  catalog palette and keeps imported behavior removed.
- The large Fists page now uses a scrollable, fixed-height two-column catalog
  instead of shrinking sixteen rows into an unreadable panel.
- Luck is granted only on first discovery. Duplicate drops and permanent-pet
  reclaims remain usable as pets/fusion material but cannot farm Luck.

## QC iterations

1. Runtime correctly stacked two Omega Guardians to 96x pet power; the first
   assertion incorrectly expected one-pet power. The contract now separately
   verifies stackable pet power and non-stackable discovery Luck.
2. Shop test incorrectly expected every action to be active. It now verifies
   disabled Depth-locked cards, enabled unlocked cards, and disabled equipped
   actions as separate valid states.
3. Screenshot inspection found overflow in Quantum Breaker Fist and Chrono
   Sovereign Fist. Long product names now scale within a bounded text range.
4. Existing Pet Egg flow expected the old Depth-62 two-pet pool. It now proves
   the new `Thunder Roc -> Void Hound` progression band.
5. Independent QA found that `WallLevel` could bypass a fist's tunnel Depth
   gate. Server authority and the Shop display now use `Depth` only. The
   adversarial runtime case `Depth=74 / WallLevel=99` remains locked, while
   `Depth=75 / WallLevel=1` unlocks the final offer.
6. The standalone client performance contract still searched for the previous
   literal three-pet formation formula. Its assertion now recognizes the
   equivalent bounded variable-based formation and passes 26/26.
7. A first all-pet preview check treated raw source-model stud size as a UI
   bound and failed 4/16. The corrected test measures the actual adaptive
   ViewportFrame camera-fit contract; all 16 previews are exact, framed, and
   behavior-free.

## Passed evidence

- `long-run-content-contract.mjs`: 30/30 checks.
- `client-runtime-performance-contract.mjs`: 26/26 checks.
- `inventory-card-render-contract.mjs`: 17/17 checks after replacing its stale
  pre-Viewport sentinel with the current pet-preview fidelity contract.
- `run-automation-static-contracts.ps1`: Node 29, PowerShell 18, Luau 27,
  flow JSON 106, runner 11, infrastructure 25, economy 10, fist 11, pet pack
  8, persistence 28.
- `long-run-catalog-progression`: PASS including final-fist Depth/cost
  boundaries, duplicate-Luck prevention, sanitized Omega Guardian model,
  all sixteen exact sanitized pet-card previews, exact Shop lock transitions
  at Depth 0/74/75, sixteen readable Shop cards, scroll-to-endgame, and clean
  pre/post-stop console. The post-fix run passed 24 named steps in the exact
  `PunchWallRPG_ManualPlaytest_20260818_FistAuraV10.rbxlx` Studio instance.
- `full-game-economy-boundaries`: PASS after the depth-only authority change.
- `functional-hero-shop`: PASS after the depth-only authority change.
- `inventory-persistence`: PASS after the depth-only authority change.
- `hero-shop-reference-polish`: PASS with the sixteen-card Shop contract and
  authoritative UI purchase.
- `pet-egg-world-pickup`: PASS including cooldown, full-inventory hold,
  24-second expiry, and the stronger Depth-62 pool.
- `inventory-pet-icons-fusion`: PASS.
- `normal-pet-visual-models`: PASS.
- Screenshot diagnostics: 16 Fists cards, zero text failures, Desktop safe
  margin; Premium remains 3/3 safely framed. The summary records current
  UTC capture time, exact Studio identity, and SHA-256 fingerprints for the
  source, flow, and content contract; console is captured before and after
  stopping Play.

## Evidence files

- `work/automation/flows/long-run-catalog-progression.json`
- `work/automation/scripts/long-run-content-contract.mjs`
- `work/docs/evidence/long-run-catalog-20260819/shop/fists.jpg`
- `work/docs/evidence/long-run-catalog-20260819/shop/fists-endgame.jpg`
- `work/docs/evidence/long-run-catalog-20260819/shop/capture-summary.json`
- `work/docs/evidence/long-run-catalog-20260819/runtime-long-run-result.json`
- `work/docs/evidence/long-run-catalog-20260819/runtime-full-game-economy-boundaries.json`
- `work/docs/evidence/long-run-catalog-20260819/runtime-functional-hero-shop.json`
- `work/docs/evidence/long-run-catalog-20260819/runtime-inventory-persistence.json`

## Gate decision

PASS for expanded long-run catalog behavior. The known repeated fist artwork is
not accepted as finished visual identity and remains the next ordered gate.
Direct wheel/touch scrolling and final economy pacing are intentionally owned
by the later Shop/device and economy gates in this same ordered request; they
are not being represented as completed here.
