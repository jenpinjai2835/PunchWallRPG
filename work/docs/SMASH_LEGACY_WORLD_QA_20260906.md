# Smash legacy world and progression QA — 2026-09-06

Owner: HQ agent-1. Isolated branch `codex/test/smash-legacy-world-20260906`, baseline `9943d91`. Scope: the six listed flow files and this note only. No gameplay source, registry, output place, Studio, or HQ writes were performed by this worker.

## Checklist

- [x] Reconcile initial full-suite failures and downstream fixtures against current production source.
- [x] Modernize actual world/UI/economy assertions; compile every Luau chunk and execute negative controls.
- [x] Record the remaining source defect and hand off the isolated commit.
- [ ] Coordinator integration and Studio reruns: **BLOCKED / pending**. Offline checks are not runtime passes.

## Proven stale assumptions corrected

| Flow | Current behavior now exercised |
| --- | --- |
| `iteration01-complete-polish` | Grass Forest ground, five visible colliding ridges, two-face DNA artwork and current training signs, native avatar plus shared catalog starter fist, actual Shop, partially damaged depth-block HP, current first-fist purchase objective. |
| `iteration02-companion-tasks-boss` | DNA artwork on both faces; actual imported companion identity and safe geometry; Pets routes to FunctionalInventory; Fists/Tasks/Settings route to their current surfaces; single-call real Quest failure observation; server Titan phase/countdown and weak-point authority. |
| `iteration03-safearea-destruction` | Configured PremiumFists stands/showcases/nameplates replace four retired regular stands. Actual visible HUD/Settings rectangles and button sizes replace hidden legacy dock measurements. Shared block/debris/reset and strict combat HUD checks remain. |
| `iteration04-armory-pets-feedback` | Shop front HUD atlas and distinct rear SMASH artwork; actual Forest training sign; real Inventory duplicate selection/card lock state; real paid-hatch rejection with unchanged economy; three actual hidden-egg spawn/arm/claim cycles, each adding exactly one companion; current continuous TrainingState acknowledgement, rate overlay and exit control. |
| `iteration05-final-depth-motion` | Configured premium nameplates, current visible Power/Coins/Depth values, actual tutorial objective text and three-action progress, bounded depth/presentation geometry, existing reduced-motion restoration and physics collapse checks. |
| `natural-progression` | Wait for at least 13 **credited** training ticks, then verify exact power gain, stable session/rate, payout serial and last batch before stopping. The fresh Power-15 route and ten-tier gate matrix retain their authority checks. |

The first five flows previously counted city billboards/barricades or regular fist stands removed by the accepted Forest hub. `makeGraphicSurface` creates one visible image plus one decal per face (server1160); DNA uses the same configured image twice (7109–7110), while the Shop deliberately uses two different configured images (6900–6902). Premium stands and actual title labels derive from `GameConfig.PremiumFists` (6909–6958). The checks verify visible children and actual model parts as well as catalog attributes; they do not manufacture attestation attributes.

Pets now open `GameMenu.FunctionalInventory`; duplicate keys are `pet:slot:N`, with selected slot/lock state and actual card state verified independently. Fists open `FunctionalHeroShop`; Settings open `SettingsWindow.Body`. The former procedural pet eye/foot/tail counts and legacy generated menu banners no longer describe the presented product.

Paid `HatchPet` is explicitly rejected by `hatchPet` (server7615–7624) with `wall_drops_only`; automation `HatchPet` intentionally grants a free fixture egg (10032–10033). The updated real-remote check therefore requires Fail / SIDEKICK LAB and the actual hidden-depth-block guidance. Coins and both pet collections must remain unchanged. Three subsequent controlled hidden drops use the production spawn/arming/claim path and prove one item per claim, no remaining active pickup, three equipped pets, positive multiplier, and no coin charge. Visible surviving reward pops must still exist and must not overlap; a fixed three-pop count was invalid because the first popup can expire during three separate pickup arming delays.

Every fixture that resets a player first requires Studio, `EphemeralStudio`, no live-data opt-in, ready ephemeral profile, and nonwritable persistence. All remote observers are connected and disconnected inside one execute call, including failure cleanup. No cross-VM Instance or callback state was introduced.

## Training failure: scheduling, not a lower target

The initial natural-progression evidence reported Power15 → 63: exactly 48 gain, or 12 valid Rookie Bag ticks. The old 13.2-second sleep was not synchronized with the once-per-second server loop. That loop credits whole elapsed intervals from `TrainingTickAnchor` and supports batched catch-up; stopping does not flush the partial interval.

The flow now observes `TrainingSnapshot` until at least 13 credited ticks, with a 25-second bounded deadline. `verifyTrainingCredits` requires unchanged active session and station rate, integer credited ticks, positive integer payout batches no greater than ticks, exact `basePower` delta equal to ticks × gain, and exact last batch payment. Train itself must return zero immediate gain. Stop must actually deactivate training. At the current four-power rate, the retained requirement is still at least 52 gained power.

Production references: `grantTrainingTick` server5737–5776, `trainPlayer`5778 onward, `TrainingSnapshot`9661–9697, periodic due-tick loop10248 onward. The test does not assume every heartbeat pays exactly one tick.

## Unresolved source defect: combat information is suppressed

The new fixture work revealed required behavior that cannot pass through fixture changes alone:

- Client8955 unconditionally sets `targetHUD.Visible = false` on every target scan. `TargetTitle.Text`, `TargetDetail.Text`, and the health fill are only initialized (1636,1686,1657); no update routine remains.
- Client9008–9012 hides BossHUD and returns when `PixelReferenceHUDActive` is true. The production reference HUD sets that flag true at9067. Existing code9020–9042 would otherwise display real HP, phase, weak-point multiplier, and shockwave countdown.
- The reference HUD provides no replacement wall HP/hit estimate or Titan HP/countdown widget. This is source evidence, not a Studio observation from this worker.

Strict live HP, hits-remaining, boss countdown, visibility and safe-bounds assertions are intentionally retained in iterations01–04. These flows must stay **BLOCKED** until the Coordinator restores the visible behavior or explicitly accepts a changed feature requirement. Server HP/phase/countdown checks remain separately meaningful. This handoff does not claim that those display checks pass.

## Offline evidence

Executed with official Luau0.737 already verified by the Coordinator:

- **PASS: 60 flow Luau chunks compiled**, all six JSON files parsed, expected regexes compiled, and no Client chunk references ServerStorage.
- **PASS: 52 executed helper/production controls.** Actual extracted flow helpers verify face-specific artwork, both-face visible text, current premium display geometry, and exact training credit accounting. Negative cases cover missing/hidden/wrong/duplicate artwork, wrong sign face/text, missing or unsafe stand, empty/hidden/wrong-tier showcase, changed session/rate, insufficient/fractional ticks, invalid payout serial, under/overpayment and incorrect last batch.
- Three controls execute the **actual production `grantTrainingTick`** with native Luau mocks for thirteen individual payments, catch-up batches5+8, and a single13-tick batch. A boosted payment is rejected by the unboosted fixture proof.
- **PASS: six semantic weakening mutations rejected**: invisible image accepted, missing reverse sign face, missing PremiumOnly requirement, missing exact payment, missing payout-serial validation, and missing minimum/integer tick validation.
- **PASS: `git diff --check`.** No Studio runner was invoked.

Commands run (temporary harnesses, read before execution):

```powershell
node "$env:TEMP/smash-legacy-world-check.cjs"
node "$env:TEMP/smash-legacy-world-mutations.cjs"
git diff --check
```

Temporary evidence: `$env:TEMP/smash-legacy-world-offline-result.json`; extracted Luau harness `$env:TEMP/smash-legacy-world-contract.luau`. The tests extract the committed flow helpers and current server grant function; the temporary harness is not a shipped gameplay dependency.

The Coordinator owns combined regression and runtime evidence under `work/docs/evidence/`. Initial evidence inspected: `smash-full-suite-20260906/{iteration01-complete-polish,iteration02-companion-tasks-boss,iteration03-safearea-destruction,iteration04-armory-pets-feedback,iteration05-final-depth-motion,natural-progression}.json`. Initial Studio source was20f34cd; this worktree additionally includes9943d91 camera source but does not synchronize it.
