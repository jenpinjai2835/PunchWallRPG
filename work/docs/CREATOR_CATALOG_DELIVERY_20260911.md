# Creator catalog: one live listing and nine further collections

Task `CREATOR-CATALOG-10-20260910` covers ten total collections. The first real paid listing is [Gilded Grove — Merchant & Loot](https://create.roblox.com/store/asset/122456766146790/Gilded-Grove-Merchant-Loot), ordinary Model122456766146790 revision2 at US$5.99. Its paid public page, native persisted geometry, dependency permissions and temporary-key deletion are recorded in [the first-sale handoff](GILDED_GROVE_FIRST_SALE_20260911.md).

The other nine collections add 108 original base models, with three palettes each. Their intended price is US$4.99 per collection. Palette variants are not counted as extra original models. No new model is claimed as uploaded or on sale until its native persistence and public paid page are verified.

## Local delivery and acceptance

Open [the visual catalog and ZIP index](../../outputs/creator-packs/catalog/CATALOG.md). Each ZIP includes 12 FBX files, 12 GLB files, three PNG palettes, an editable Blender scene, five actual product renders, a three-palette aggregate GLB, the manifest, README and three validation reports: exactly39 files. Internal drafts, build logs, developer geometry JSON and local Studio previews stay outside buyer ZIPs. The separate local source ZIP is not automatically delivered by a Creator Store purchase.

The authoritative final machine-readable result is [final-validation.json](../../outputs/creator-packs/catalog/final-validation.json). It binds current source-module hashes to exported files, three-palette aggregate checks, reopened editable source, local Studio geometry/flow assertions and exact ZIP payload hashes. The original batch report is historical: Harvest and Moonwell were regenerated after their metadata notes were corrected, and the earliest two ZIPs preceded the stronger packaging gate. Final acceptance uses the current per-pack evidence, not those superseded archive hashes.

All nine local artifact gates passed. [The review index](../../outputs/creator-packs/catalog/reviews/review-index.json) binds all45 inspected final product images and nine ZIPs to the three independent handoffs. Final grounding has no unsupported gaps, and the stale same-name Studio-flow negative case was rejected by the actual finalizer. Overall publication remains1/10 and BLOCKED.

| Check | Required evidence |
| --- | --- |
| Original source geometry and actual visual review | Worker source handoffs and final reviews in `outputs/creator-packs/catalog/reviews/` |
| 216 isolated imports, 24 per pack | Each `evidence/export-roundtrip.json`: names, triangles, pivots, bounds, finite geometry, atlas UVs and embedded intended RGB |
| Nine aggregate GLBs, 36 placements each | Each `evidence/native-roundtrip.json`: isolated reload status, counts, triangles, authored root, layout and payload SHA; independent reviewers also check embedded PNG bytes and palette assignment |
| Nine editable sources reopened | Each `evidence/source-reopen.json`; worker inspections check asset geometry and packed palettes |
| Nine local Studio previews and recorded flows | Each `evidence/studio-preview.json`, `studio-flow.json`, `studio-preview.png`; execution-time flow and manifest SHA hashes bind matching flows in `work/automation/flows/creator-packs/` |
| Exact39-file archives | Each `evidence/package-validation.json`; current bytes and CRC compared against the full allowlist and SHA ledger |
| Packaging failure paths | Worker3 negative follow-up: empty fake PASS fixture, altered GLB and missing GLB rejected; unlisted probe excluded |

The Studio preview reconstructs the actual exported GLB geometry using EditableMesh and verifies all108 models, semantic role pivots, bounds, grounding and anchoring. It is local edit-time evidence. It does not prove uploaded mesh ownership, native persistence, a live listing, gameplay behavior, mobile UI or performance. These visual-only products contain no runtime scripts, simulated liquid, crafting or interactive systems.

`reviews/studio-console-audit.json` compares error history to the four recorded first-sale diagnostics: zero unexpected errors. The built-in MaterialManager profiling warning and historical diagnostics remain visible; the console was not cleared or described as empty.

## Corrections made during verification

- Initialized the empty Blender scene's World before lighting setup; a full exporter smoke rerun passed.
- Ordered collection displays by height and raised the camera so tall props no longer cover rear labels.
- Strengthened package validation to reject missing/changed files even if an old report says PASS. Added the explicit39-file payload allowlist and checked four independent negative cases.
- Made separate-role wording conditional on actual exported role meshes.
- Clarified that Moonwell's brew surface can be removed in editable Blender source; its portable export joins it into Body.
- Corrected Harvest's garden-bed note to the measured3.84×2.54-stud footprint.
- Final close-up review identified above-ground feet on the pinball table, cafe chair and menu easel. Added level foot pads, verified12 separate flat contact faces and positive leg overlap, rebuilt both packs and reran export/Studio/image checks. The final exporter and acceptance gate reject unsupported positive floor gaps; the explicitly documented0.01-stud carrot-tip clearance is the sole exception.
- Moved cauldron handles outward0.10 studs, retaining lug/shell attachment and at least0.02 studs of inner-cavity clearance. Rebuilt Moonwell and reinspected the final detail image.
- Bound Studio results to execution-time flow and manifest hashes, and checked inner flow success. A later same-name flow edit cannot reuse an older successful execution report.

## Publication blocker and next dependency

Automatic approval review rejected the combined command to opt into the documented Studio `CreateAssetAsync Luau API` beta and restart the task-owned authoring Studio, reporting **“blocked by policy.”** The command did not execute: no Studio preference was changed and no Studio process was stopped by that attempt. The denied operation was not retried through another mechanism. The unused settings helper is kept only in ignored diagnostic scratch.

Nine persistent native uploads, owned/approved mesh dependency checks and paid listing verifications therefore remain **BLOCKED**. Resumption requires the documented Studio upload API to be available through an approved route. After that, import each aggregate as persistent owned assets, create an ordinary Model, validate a fresh native load, then set its truthful Store copy/images and verify its paid public page. Do not list a Package as if it were the sellable ordinary Model, or upload local EditableMesh preview objects as a persistent deliverable.

The first-sale temporary Open Cloud key was deleted and its in-memory secret cleared. No further credential, financial onboarding, identity/tax submission, purchase or spending is part of this local delivery.

## Reproduction and integration

Source: `work/creator-packs/catalog/packs/`. Shared exporters reuse the already verified original geometry/atlas helpers from `work/creator-packs/gilded-grove/src/`. Source and evidence line endings are pinned for reproducible hashes.

```powershell
python work/creator-packs/catalog/batch.py --blender PATH_TO_BLENDER --out outputs/creator-packs/catalog
node work/creator-packs/catalog/studio-batch.mjs STUDIO_ID outputs/creator-packs/catalog PATH_TO_FLOW_RUNNER
python work/creator-packs/catalog/finalize.py outputs/creator-packs/catalog
python work/creator-packs/catalog/verify_reviews.py outputs/creator-packs/catalog
```

The batch limits rendering to two Blender processes, two CPU threads each. Studio checks run serially against exactly the isolated `Place1` instance, PlaceId0. Gameplay source, the live Smash Wall experience and final game place were not edited.

Coordinator integration order: natural source c24a14f→87998fb, fantasy3eb7bb1→549565c, modern38ad8d4→766343c. Shared tooling and corrected metadata are committed at553cd70. Independent corrective handoffs followed: modern feet334e41b→93e2460, then cauldron handlesc3d76d7→6deb885. Subsequent delivery commits contain stronger acceptance gates, final evidence and artifacts. The catalog remains on `codex/feature/creator-catalog-ten` with the overall Agent HQ task BLOCKED until all ten paid listings are verified.

Delivery commit `c094d04617d5b1df6c1a862bb3aee4c0ca55ae22` was pushed and independently matched against the remote branch. Draft PR creation through the GitHub connector returned403, `Resource not accessible by integration`; no PR was created and no merge occurred. The pushed branch is available for review. This GitHub integration permission is a separate delivery limitation from the Studio publication blocker.
