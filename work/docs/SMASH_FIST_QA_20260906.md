# First-five fist presentation QA — 2026-09-06

Owner: Agent 3, Coordinator-registered FIST QA scope. Authoring branch:
`codex/test/smash-fist-qa-20260906`, based on
`d4de5a2e6f14a92843a1cce12175e998f3a6087d`.

Only the three fist flows, the fist identity contract, and this document change.
No Studio calls, gameplay source, assets, prices, saves, or shared test runs were
performed by this worker. The Coordinator owns integration and runtime evidence.

## What this replaces

The previous complete-catalog flow prepared eight fists, iterated the current
19-item catalog, and still expected eight results. It also required the imported
mesh for every item. The old alignment flow required the inactive
`HeroGauntletV2` path. The icon contract primarily proved labels and perimeter
motifs, which could pass while Shop, Inventory, and equipped shapes disagreed.

The updated seed sums current normal-fist costs, buys every paid normal fist via
the authoritative automation command, grants each configured premium fist, and
checks every saved name is owned. The result count is derived from `AllFists()`;
current configuration contains 16 normal and 3 premium items. Native geometry
checks apply to the five canonical names only. The other 14 retain the existing
imported mesh, color, material, plate, fin, cuff, and attachment expectations.
No real-money purchase prompt is invoked.

## Required contracts

- `first-five-fist-presentation.json` builds each real catalog model in Roblox,
  validates four knuckles, four curled pads, folded thumb, cuff and backhand,
  actual geometry distinctness without labels/colors, and all final part
  corners against engine and recorded bounds. It then opens actual Shop and
  Inventory and equips each item through the action remote. All three surfaces
  must have the same named parts, shape, dimensions, local transforms, colors,
  materials, roles, and part counts after uniform-scale normalization.
- Preview comparison uses the actual `Catalog Closed Palm` frame as its local
  reference. It does not assume an unwelded Model pivot continues to follow its
  parts after character animation. Preview parts must be anchored, massless,
  noninteractive, shadow-free, and contain no effects, scripts, joints, or
  constraints. Equipped geometry must be unanchored and otherwise visual-only.
- Shop cards are scrolled into view individually. A visible `FistCatalogPreview`
  needs a real model and camera, identity attributes, and `RenderLoop=false`.
  Camera and palm pose must stay unchanged while idle. Closed and offscreen
  Shop cards must release their catalog model. Inventory repeated selection
  must preserve the exact existing preview clone. Five Shop/Inventory cycles
  must preserve live preview model and part counts after warmup.
- `fist-arm-alignment-qc.json` computes the eight corners of every actual part
  in current-hand space. It compares the complete envelope and actual palm pose
  with the shared wrist-origin geometry, hand-width scale, cuff Y offset and
  180-degree Z orientation. It verifies direct weld endpoints, one outer model,
  visible avatar hand, idle/punch/recovery attachment, and real respawn teardown
  followed by saved-identity restoration.
- `item-matched-fist-visuals.json` covers all configured equipped items and
  retains full-motion tier aura budgets, reduced-motion suppression/restoration,
  and the premium punch attachment check. New native shapes do not need the old
  imported-mesh prominence multiplier. Full-motion is explicitly set for the
  aura matrix so saved settings cannot produce a false negative.
- `fist-icon-identity-contract.mjs` runs actual Luau module geometry checks using
  minimal Roblox type/Instance doubles, compiles all embedded flow chunks, and
  checks complete catalog identity and coverage. Default mode also checks the
  integrated consumer source hooks. `--module-only` deliberately reports that
  consumer wiring was not checked.

The flow tolerances are test design choices: relative part positions 0.006
canonical studs; live wrist position 0.035 studs; live complete bounds 0.04
studs; geometry orientation dot product above 0.999. They are not measured
network, FPS, or visual-quality metrics. Canonical native geometry remains
12–22 parts per model and below the existing 28-part ceiling. Geometry-derived
expectations allow bounded shared-builder silhouette refinements without
freezing the original dimensions into the consumer tests.

## Evidence at authoring handoff

| Check | Status | Evidence |
| --- | --- | --- |
| Node syntax of the contract | PASS | `node --check work/automation/scripts/fist-icon-identity-contract.mjs` |
| Actual module pure geometry, anatomy, wrist origin, bounded connected AABBs, sanitizer compatibility, fresh specs and unsupported fallback | PASS | `node work/automation/scripts/fist-icon-identity-contract.mjs --module-only`; five geometrically distinct models, 14 / 15 / 16 / 18 / 18 parts |
| Embedded flow Luau syntax | PASS | Same command; 13 chunks compile with Luau 0.737 |
| Negative controls against in-memory mutated source | PASS | Missing folded-thumb role, oversized Starter palm, detached knuckles each rejected; no source files changed |
| Patch whitespace | PASS | `git diff --check` |
| Integrated consumer source contract | BLOCKED at this authoring base | Consumer wiring and Inventory callback implementation are independent Coordinator/Agent 1 work |
| Actual three Studio flows | BLOCKED pending integration run | Not run by this worker; no runtime result is inferred from syntax checks or source hooks |
| R6 and R15 screenshots, physical phone performance | BLOCKED pending Coordinator evidence | Current-rig flow reports only the rig it actually exercised |

The contract JSON preserves
`studioRuntimeStatus: BLOCKED_AWAITING_COORDINATOR_INTEGRATION_RUN` even when
source and module checks pass. A Coordinator runtime result artifact is required
to resolve that gate. Pure doubles cannot prove Roblox rendering, sphere/cylinder
surface intersections, frame time, hand fit, or visual appeal. Connected AABBs
are a mathematical envelope check and do not prove actual curved-surface contact.

## Coordinator integration order and runs

1. Integrate final shared builder, equipped/Shop wiring, and Inventory preview
   callback first. Preserve catalog attributes and part roles on clones.
2. Integrate this QA commit. Run the contract in default mode and resolve any
   failure instead of substituting `--module-only` as a full pass.
3. Sync exact committed sources into the verified Studio test place. Run each
   of the following with its own `--result-file` and the verified exact
   `--studio-instance-id`. Flows stop play and include cleanup on failure.
4. Run first-five presentation at desktop and short landscape phone sizes;
   run alignment once on a live R6 rig and once on a live R15 rig. Keep each
   result's reported rig. A single run never establishes both-rig coverage.
5. Capture first-five previews and equipped wrist/hand poses. Confirm complete
   closed silhouettes, readable silhouettes at phone-card size, and no face
   obstruction. If geometry changes, rerun module and relevant runtime checks.

```powershell
node work/automation/scripts/fist-icon-identity-contract.mjs
node work/automation/scripts/flow_runner.mjs --flow work/automation/flows/first-five-fist-presentation.json --studio-instance-id <verified-id> --result-file <evidence-file>
node work/automation/scripts/flow_runner.mjs --flow work/automation/flows/item-matched-fist-visuals.json --studio-instance-id <verified-id> --result-file <evidence-file>
node work/automation/scripts/flow_runner.mjs --flow work/automation/flows/fist-arm-alignment-qc.json --studio-instance-id <verified-id> --result-file <evidence-file>
```

Each flow authoritatively resets its Studio player and changes test ownership;
use the isolated verified test place. The displayed placeholders in these
commands must be replaced with actual verified IDs and distinct evidence paths.
No test player data or runtime metrics from these runs should be presented as
production-player results.

## Screenshot review passed to the Coordinator

The first actual desktop Shop and Inventory captures show the five native
models consistently. They also expose a remaining art-quality issue: the first
two backhand patches read as circular badges and the knuckle row reads as
separate beads; Iron's overlapping block knuckles read as one bar. Proposed
small refinements lower knuckles into the palm, blend the first-two patches
with the glove, increase Boxing crown intersection, and separate Iron's four
caps by narrowing them. These proposals add no parts. They require new actual
screenshots after the Coordinator changes shared geometry; they are not an art
approval or a reason to mark runtime gates passing.
