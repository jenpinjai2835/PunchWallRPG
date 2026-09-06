# Shop and HUD visual refinement — September 6

Owner: Coordinator, isolated branch `codex/fix/smash-premium-hud-shop-20260906`.
Scope: main client Shop/HUD visual construction, its device-contract assertion,
and `premium-hud-shop-readability` runtime flow. InventoryUI is owned separately
by Agent 1. No economy, camera, networking or model geometry changes here.

The current source screenshots in `smash-current-source-visual-review-r2-20260906`
show many competing outlines and a large green EQUIPPED state that resembles
an available action. The Inventory image also retains bright scenery behind
the modal. These are actual Studio captures. The file named fresh-hud is an
entitlement-bearing startup, not a no-entitlement new-player example.

Changes use a shared navy menu surface, one subdued outer border, invisible
extra header/edge rails, a quiet equipped status, and the existing shared rarity
colors. Premium keeps its gold fallback; unknown rarities use muted text.
Item model accents and all purchase/equip callbacks are preserved. Catalog
names have a 14px minimum on desktop as well as compact rows. Inventory now
uses the same full-viewport dimmer as Shop, which disappears on close.

The objective shows the next action with a 14px floor instead of duplicating
the objective prefix and detailed instruction in a small card. The waypoint
still supplies navigation, while the underlying tutorial information remains
available to the existing UI. Phone objective width reserves space for side
controls; full runtime bounds and readable text remain required.

Local validation: full client O2 compilation; device matrix contract 8/8;
camera/shop/depth/boost contract 17 assertions; client runtime performance
contract 28/28; onboarding contract 32 assertions and seven negative controls;
`git diff --check`. Updated exact source-string contract now requires the
stronger 14px minimum across both layouts. No runtime pass or aesthetic
acceptance is claimed by these static checks.

Required combined verification: the new actual-rendered-text/control flow,
existing device matrix/onboarding/Inventory routes, fresh current screenshots,
and the frozen full flow suite before rebuilding the final artifact. The
visual flow also checks genuine EQUIPPED versus EQUIP states, rarity semantics,
44px targets and Inventory dimmer lifetime.

The subsequent actual built-in phone capture (`smash-phone-native-area-20260906`)
confirmed that the combat panel occupied too much of the scene. Its compact
base size is now 300×64 instead of 380×86, with the same 14/12 text floors and
obstacle-aware positioning. Desktop height is 72; user scale still applies.
The health, title and detail have distinct vertical rows. The new visual flow
checks its actual text bounds and maximum height when shown; the existing
combat flow remains required for target/boss states. Exact combat helper tests
pass 382 assertions and eight semantic mutations with full client and 17 flow
chunks compiling. Actual post-integration combat text checks remain pending.

## Independent review and deterministic fixture guards

Agent 3 reviewed immutable UI changes `eb4afe2` + `3906ea9` and found no new
P1/P2 product callback or ownership defect. The existing combat contract was
independently rerun: 382 production assertions, eight semantic mutations, full
client and 17 runtime snippets pass. The device matrix contract also passes
8/8. These checks do not substitute for rendered glyph and native input tests.

Two concrete defects were found in the new readability flow and corrected
without changing any original objective, combat, catalog, action, rarity,
touch-target, menu/dimmer or cleanup acceptance condition:

1. The original seven-second wait followed by Reset could race the actual
   asynchronous GamePass ownership reconciliation. A late premium-fist grant
   could replace Starter Glove after seeding and invalidate its EQUIPPED label.
   The server fixture now requires one Studio player, strict default ephemeral
   world/player state and both live-data opt-outs. It waits at most 25 seconds
   for ownership reconciled=true, failed=false and pending grants nil/zero
   before any Reset. It then resets/seeds the same original four requested
   fields and reads the authoritative Snapshot and stat Instances to verify
   Starter Glove, the exact two owned fists, base Power/Coins/Depth, multipliers,
   and empty premium/pet lists. Failed or incomplete reconciliation aborts
   before Reset. The seed result is saved as `readabilitySeed`.
2. The old matrix recorded requested sizes and scales without observing them.
   Each row now verifies the exact selected owned custom preset, actual preset
   dimensions, actual resolution, FitToWindow, and client Snapshot.uiScale.
   It reads independent native full/device-safe rectangles, requires their
   containment and positive dimensions, checks full UI dimensions against the
   preset within the observed single-unit integer-boundary rounding, and
   requires both Camera.ViewportSize and actual HUD geometry to match the
   device-safe rectangle exactly. A bounded six-second settlement loop allows
   actual layout propagation; mismatches still fail. The same values are
   checked again after the unchanged UI gates. `renderedReadabilityMatrix`
   records actual resolution, scale, camera, and native safe/full geometry.

The distinction between a configured device resolution, a safe UI viewport,
and a scaled capture raster is grounded in the Coordinator's saved
`smash-phone-native-area-20260906.json`. This matrix continues using its
original owned custom size fixtures; the separate final-capture tool is
responsible for the exact built-in iPhone preset and original image evidence.

Offline validation of the exact modified flow compiles all five Luau payloads
and executes 35 fixture/observer controls, including four weakened-source
controls. Successful cases include delayed completed reconciliation and the
legitimate nil empty queue. Failures cover permanent pending/failed ownership,
writable/live profiles, multiple players, stale authoritative ownership/power,
wrong selected device, ignored resolution/scale changes, inconsistent native
safe geometry and rounding outside the accepted bound. Removing queue,
UI-scale, device-identity or actual camera-area checks demonstrably admits
their corresponding rejected cases. An independent structural comparison with
`3906ea9` confirms every original UI acceptance block and cleanup is unchanged.
The local executable check is
`$env:TEMP/smash-premium-readability-fixture-check-20260906.mjs`; run it with
Node and the task checkout as its sole argument. `git diff --check` also passes.

Agent 3 also reviewed Inventory source `1290a1b` without finding a new P1/P2
product defect. It preserves callback/cache identity and the retained model;
the Forest Pup fit uses its actual front decal orientation and eight bounds
corners. Both new card/detail art stages are square. Independent checks passed
159 preview assertions/eight mutations and 2,893 layout + 20 semantic
assertions/eight mutations, including their intended older-source failures.
The separately reported, subsequently fixed pre-existing empty-state font
floor was outside that immutable source review. Actual text rendering and Pup
appearance still require the Coordinator's native capture/replay.

This follow-up changes only the readability flow and this document. It does
not operate Studio, modify gameplay or image assets, weaken a UI threshold,
or claim a native or final-artifact pass. The revised runtime matrix and the
existing actual wall/boss HUD flow remain required integration checks.
