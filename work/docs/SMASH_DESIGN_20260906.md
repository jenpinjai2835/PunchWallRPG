# Smash Wall: mobile quality and progression design

Date: 2026-09-06. Agent HQ: `SMASH-20260906`, Agent 3 DESIGN.
Baseline: `4094e51acdcaf7703986597ddd585eadfb4c37a1`.
Owner: Coordinator integrates this handoff after review.

## Decision and scope

The accepted direction is satisfying wall destruction with friends, supported by
fists, pets, and upgrades. The immediate work is usable mobile Shop/Inventory,
complete item presentation, predictable camera behavior, and smoother gameplay.
New modes, menus, currencies, and retention systems are deferred until those
foundations pass. This document proposes changes; it does not claim they are
implemented, measured in production, or capable of guaranteeing virality.

The accompanying `smash-mobile-shop-inventory.html` is an interactive design
preview. Its purchases and equipment changes affect local sample state only.
Sample names, prices, and multipliers use the current configuration. Model stages
are explicitly reserved spaces, not proposed finished fist or pet artwork.

## Evidence and current limitations

- `src/shared/GameConfig.lua:540` defines a three-action tutorial: hit a wall,
  open Shop, buy the 180-coin Street Boxing Fist. Training, pets, and cooperation
  are not taught by this tutorial.
- `src/server/PunchWallBootstrap.server.lua:2812` advances the first hit to the
  Shop prompt without an affordability check or tutorial coin grant. Forest
  blocks pay 11 coins each (`floor(45 / 4)`). Seventeen full solo block rewards
  fund the first fist if no other income is claimed. Actual first-punch block
  count needs runtime reproduction; this is an affordability risk, not a
  measured first-session failure.
- Material HP changes from 8 to 900 at the first transition, while the first
  bought fist changes its multiplier from 1 to 1.8. This 112.5-times HP jump
  needs a fresh-profile pacing check before changing values.
- Contributor rewards already exist on the server: each actual contributor
  receives 50-100% of the base wall coin reward according to damage share.
  Cooperation should first become legible through this existing behavior.
- The historical 874x402 emulated-phone inventory capture at
  `work/docs/evidence/training-ui-pet-recovery-20260821/02_iphone17_inventory_pets.jpg`
  shows five small columns and a largely clipped lower row. This supports
  reviewing density and hierarchy; it is not current physical-phone evidence.
- Historical Shop images repeat fist artwork across items. Later fixes exist;
  the current build must be captured before reopening a particular art defect.
- Canonical source has no matches for `AnalyticsService`,
  `LogOnboardingFunnelStepEvent`, `LogFunnelStepEvent`, `LogCustomEvent`, or
  `LogEconomyEvent`. Production dashboards were not accessed for this handoff.

Paths above are repository-relative. Canonical source is under
`work/punch-wall-rpg/`; historical evidence is under `work/docs/`.

## Independently verified economy calculation

Agent 3 parsed `GameConfig.Walls` independently of Agent 1's calculation.
The source creates 12 columns x 6 rows x 75 layers. Each of tiers 1-9 has
8 layers; tier 10 has 3. Per-block coins are `floor(config.coins / 4)`.

| Tier | Layers | Coins per block | Coins for all tier blocks |
| --- | ---: | ---: | ---: |
| Forest Stone | 8 | 11 | 6,336 |
| Concrete | 8 | 45 | 25,920 |
| Iron | 8 | 245 | 141,120 |
| Crystal | 8 | 1,300 | 748,800 |
| Lava | 8 | 7,000 | 4,032,000 |
| Cyber | 8 | 40,000 | 23,040,000 |
| Titan Alloy | 8 | 105,000 | 60,480,000 |
| Meteor Core | 8 | 350,000 | 201,600,000 |
| Void Crystal | 8 | 1,250,000 | 720,000,000 |
| Omega | 3 | 4,500,000 | 972,000,000 |
| Total | 75 | | 1,982,074,176 |

`WORLD_RESET_INTERVAL = 300` in the server. Titan rewards 60,000,000 coins
for full solo contribution and respawns after 20 seconds. An optimistic model
grants one full 5,400-block clear plus 15 instantaneous boss defeats per 300
seconds, giving 2,882,074,176 coins per cycle. The final fist costs
180,000,000,000,000 coins.

```text
180,000,000,000,000 / 2,882,074,176 x 300 / 86,400
= 216.8577079676 continuous days
```

This is a conditional calculation for unboosted repeated depth/boss income in
one server, not measured playtime or a universal fastest-possible bound. It
ignores acquisition and gate time, attack and travel time, previous purchases,
other income, boosts, and alternative server/rejoin behavior. Realistic combat
and the need to buy earlier equipment make that particular route slower; other
income can change the result. The result is sufficient to flag a major mismatch
between displayed final-tier prices and the existing main reward loop.

Do not apply a uniform price division without testing the complete curve.
First specify intended active play time between purchases for early, middle,
and late progression, then simulate reachable damage, wall gates, coin sources,
and upgrade costs together. Preserve ownership and internal save keys. Existing
players require an explicit migration review if prices or prerequisites change.
Economy work is a separate server-authoritative change after the UI foundation.

## Mobile Shop and Inventory contract

Use one visual language: opaque navy surfaces, cyan selection, gold currency,
and small rarity markers. The preview explores a readable list plus a selected
detail view. It deliberately avoids squeezing a five-column desktop catalog
onto a phone. It is an alternative to evaluate, not a pixel-perfect Roblox spec.

- Shop items show a recognizable name, multiplier, price, and owned/equipped
  state. A single selected-item action says `Buy & Equip`, `Equip`, or the
  missing coin amount. Purchase failures remain understandable.
- Inventory provides Fists and Pets, readable item names, equipped status, and
  equipment capacity. Selecting an item opens its separate detail surface.
  Buying an owned fist again never subtracts coins.
- On narrow screens, opening item details replaces the list and provides a
  visible Back action. On wider screens, the list and details sit side by side.
  Short landscape screens keep readable rows and move through list/detail
  states; implementation must retain proper scroll behavior and safe areas.
- Selected item and scroll position survive a round trip into details.
  Long names and numbers wrap or abbreviate predictably, without decreasing
  primary labels to tiny text. Errors never require hovering.
- Real implementation must also handle loading, empty results, stale purchase
  responses, full inventory, maximum equipped pets, and request retries.
  The preview demonstrates selection, affordability, buy/equip, and pet capacity;
  it does not simulate server or persistence failures.
- Proposed internal targets: 48-pixel primary touch targets, at least 44-pixel
  secondary targets, and ordinary item text at least 14 rendered pixels. These
  are project targets, not universal Roblox requirements.
- Validate 320/360-pixel narrow widths, 740x360 and 844x390 landscape phones,
  tablet, and desktop, including actual Roblox safe areas and touch controls.

Roblox's current [UI positioning guidance](https://create.roblox.com/docs/ui/position-and-size)
recommends keeping controls out of reserved zones, within comfortable thumb
reach, and showing contextual information during active gameplay.

## Item art and motion contract

Start with the first five fists before extending the same quality standard
across all 16. Preserve the existing closed-fist, right-hand equipment contract
and original avatar appearance. Suggested identities: compact leather Starter,
rounded red Street Boxing, square steel Iron Crusher, blue Thunder core, and
broad amber Titan cuff. These are concepts, not completed assets.

Each item must read at phone thumbnail size and match across its catalog image,
selected preview, and equipped form. Verify R6/R15 wrist alignment through idle,
run, jump, punch, and respawn. Avoid using generic category icons as finished
fist art. Imported content stays visual-only and follows the asset manifest and
sanitation rules. A static thumbnail plus one selected 3D preview is an option
to profile, not a claimed optimization before measurement.

Impact should communicate anticipation, contact, visible damage, and recovery.
Put force into the fist, target, sound, and directional debris. Aggregate rewards
per punch so a multi-block break does not bury the view. Camera feedback should
be bounded and restore state when a menu opens, the character respawns, training
starts, or motion settings change. Reduced motion retains useful hit feedback.

## First ten minutes: testable proposal

These times are hypotheses to test with fresh profiles, not current metrics.
Do not add a ten-minute mandatory tutorial.

| Time | Intended action | Acceptance |
| --- | --- | --- |
| 0:00-0:30 | Spawn facing the wall and punch | Visible damage without a large instruction panel |
| 0:30-1:30 | Open a small route and fund the first fist | Shop prompt appears when purchase is affordable |
| 1:30-3:00 | Buy/equip and return to punching | Improvement is visible on a comparable target |
| 3:00-5:00 | Try training when a tougher material requires it | Player understands where Power comes from |
| 5:00-8:00 | Equip an earned pet and continue with nearby players | Inventory is understandable; actual contributions are recognized |
| 8:00-10:00 | Reach a material milestone and choose the next upgrade | Clear attainable goal, saved progress, natural stopping point |

Keep the first-loop adjustment small: condition the Shop prompt, make the
training explanation contextual, and ensure the existing item/equip flow is
usable. First-pet timing and any new cooperative encounter require later
economy/design review. Do not gate solo progression on server population.

## Delivery order and validation

1. **UI and stability:** fix current mobile layout, camera cancellation, and
   confirmed frame-time hotspots. Run the affected flows and fresh real-view
   captures before visual expansion.
2. **Item presentation:** integrate accepted fist/pet art, alignment, fallbacks,
   and catalog preview behavior. Compare all states on desktop and phones.
3. **Pacing and economy:** reproduce affordability and material-gate paths;
   simulate the entire price/reward curve; implement an approved bounded change
   with server, save, boundary, failure, and regression evidence.
4. **Cooperation and audience measurement:** improve feedback for existing
   contributions first. Consider new encounters only after core fixes pass.
   Evaluate retention using real cohorts instead of inventing success rates.

Proposed reference budgets, subject to choosing a physical baseline device:
p95 frame time <=33.3 ms and p99 <=50 ms on the mobile scenario after warm-up;
desktop p95 <=16.7 ms; no reproducible game-caused >100 ms stall in the recorded
route. Attach device, build, graphics level, population, and network conditions.
These are proposed budgets and have not passed. Studio emulation cannot prove
physical-phone performance or memory behavior.

Roblox explains why [frame-time consistency](https://create.roblox.com/docs/performance-optimization/microprofiler)
matters even at a high average FPS. Its [performance design guidance](https://create.roblox.com/docs/performance-optimization/design)
distinguishes emulator layout checks from actual device memory measurement.
Streaming is already enabled in `default.project.json`; identify actual
hotspots before treating an existing setting as a new fix.

## Measurement after the core fixes

Use confirmed server milestones for onboarding and economy measurements.
Suggested milestones are first break, first fist affordability, first purchase,
first training gain, first equipped pet, first shared break, and first material
milestone. Optional actions need separate events or funnels: Roblox fills
earlier skipped funnel steps, so treating branches as one strict sequence can
overstate completion. [Funnel events](https://create.roblox.com/docs/production/analytics/funnel-events)
are emitted by servers in published experiences; Studio cannot verify arrival
in the live analytics dashboard.

Compare first-loop completion and time, material-gate exits, cooperative
participation, D1/D7/D30 cohorts, and [performance by platform and place version](https://create.roblox.com/docs/production/analytics/performance).
Report cohort sizes and wait for retention windows to mature. No dashboard
benchmark, retention percentage, or uplift is available for this handoff.
Roblox recommends focusing on the [core loop, onboarding, and performance](https://create.roblox.com/docs/production/analytics/retention)
when improving early retention.

The [June 15, 2026 discovery update](https://about.roblox.com/newsroom/2026/06/optimizing-discovery-great-games-reach-millions-players-roblox)
expanded recommendation evaluation to a 28-day view and separated the former
qualified-play-through signal into more granular measures. Build lasting player
value and enjoyable co-play; do not promise global virality or add pressured
spending, forced invitations, or punishment for taking breaks.

## Handoff checks

- PASS: current configuration parsed independently; arithmetic above reproduced.
- PASS: source paths and historical evidence inspected against the stated base.
- PASS: current official Roblox sources reviewed on 2026-09-06.
- Pending Coordinator: interactive preview runtime and 360/736-pixel visual QA.
- Not performed by this documentation task: gameplay implementation, Roblox
  Studio tests, physical-device profiling, production analytics, or publishing.

The Coordinator records final preview validation and combined game checks in
the parent task. This design handoff does not close gameplay quality gates.
