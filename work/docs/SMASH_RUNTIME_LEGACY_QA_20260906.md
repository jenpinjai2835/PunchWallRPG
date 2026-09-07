# Contextual authority and pet template QA — 2026-09-06

This task changes only `contextual-actions-settings-authority.json`, `creator-store-pet-pack-visuals.json` and this note. Production source, assets, Studio state, flow registry and release outputs were not changed by this worker.

## Contextual Use: confirmed stale fixture

The old flow teleported to Spawn at `(-2, 3, -18)` and assumed that point was outside every contextual interaction. The server defines `MOBILE_ACTION_DISTANCE = 38` at `PunchWallBootstrap.server.lua:71`. Its configured third Premium fist stand is at `(-22, 3, -10)`, only `sqrt(464) = 21.54` studs from Spawn. The exact production `nearestUseTarget` function selects Celestial Titan Fist there. A purchase response instead of `Fail/Use` is therefore consistent with the server's existing authority rules.

The corrected fixture uses `(0, 3, 70)`, inside the World 1 ground footprint. Before sending any Use request, it verifies the actual root position is more than the current server radius plus two studs from every Premium fist stand, egg machine, Rebirth Shrine, Armory NPC, Pet Lab NPC and Honor NPC used by `nearestUseTarget`. The fixture radius is checked against the production constant by the offline validation; a future range change requires updating this contract.

The client subscribes to the actual Feedback remote, sends exactly one Use request, and requires `Fail/Use` within four seconds. It ignores unrelated feedback and disconnects the observer on success, timeout, malformed response or remote failure. This replaces the stale global `LastFeedbackType` observation, which could be overwritten by another notification. Existing real Train, StopTraining, in-range Use and settings normalization assertions remain.

Reset now requires the actual ephemeral Studio persistence mode, explicit false live-data opt-in and a ready, non-writable ephemeral profile.

## Pet Edit attestation: safety failure remains visible

The old failure evidence omitted the returned diagnostic JSON, so it did not identify the failed template. Offline inspection of the unchanged baseline `outputs/PunchWallRPGPlayable_v1_final.rbxlx` found:

| Template | Strict sanitizer attribute names on root | Embedded joints |
| --- | --- | --- |
| Eight normal pack templates | Present | None |
| Crimson Phoenix | Absent | None |
| Storm Wyvern | Absent | 33 Motor6D and one Weld |
| Celestial Guardian | Absent | Nine Motor6D |

`embed-detailed-premium-pet-assets.rbxmk.lua` removes several behavior classes but does not remove these joints or apply the strict per-descendant sanitizer attestations. Runtime `loadExternalVisualTemplates` sanitizes and attests preloaded templates before use. That explains how runtime pet checks can pass while the Edit artifact fails the strict checker. This is evidence about the baseline XML and embedding path; the Coordinator must inspect the currently open Studio templates before confirming the current artifact state.

The flow retains `AssertSanitizedVisual`/`IsSanitizedVisual`, all eleven exact pet/template/asset mappings, the eight pack source-child identities, aggregate budgets and raw-pack absence checks. It does not sanitize a model during verification or accept the runtime cleanup as proof that the Edit artifact was safe.

The Edit report now includes each template's presence, actual asset/source/definition, strict sanitizer error and attestation status, plus unsafe class counts. Visual safety checks explicitly count JointInstance, Constraint and BodyMover hazards in Edit templates, Inventory previews and companion clones. A missing preview reports an identity mismatch without dereferencing a nil model. Pet profile fixtures also require ephemeral Studio before Reset.

The Edit audit evaluates disposable clones of the three authored ModuleScripts and destroys them even if require fails. This avoids a previously required module result hiding a newer source revision. Roblox documents that repeated require calls return the same cached module reference in [Reuse code](https://create.roblox.com/docs/scripting/module). No retained asset is changed by this diagnostic.

## Validation and limitations

- PASS: all 20 embedded Luau chunks compile with official Luau 0.737.
- PASS: eight controls execute the production nearest-use resolver and the exact new spatial fixture helper, proving the old Spawn failure, the new out-of-range point and rejection of invalid target data.
- PASS: nine controls execute the complete updated Edit pet audit against the actual production sanitizer with mocked models. Safe exact templates pass; missing attestation, joints, collisions, wrong asset/source/definition and missing templates fail.
- PASS: five disposable-module lifecycle controls and five actual-feedback observer controls, including error cleanup and exactly one remote send.
- PASS: four deliberate weakenings of distance, sanitation, asset identity or source-child identity are detected.
- PASS: `git diff --check`.

Temporary evidence is under `C:/Users/Jennarong Pinjai/AppData/Local/Temp/smash-legacy-qa-0BUVmO/` and `smash-legacy-lifecycle-hL1Z3w/`. Launchers `smash-runtime-legacy-check.cjs` and `smash-runtime-legacy-lifecycle-check.cjs` in the same Temp directory only read local source/JSON, write temporary Luau and run the official CLI.

Both live flow reruns remain pending the Coordinator's exclusive Studio session. The pet Edit check remains BLOCKED if any current template lacks strict safety or identity. The first Edit chunk alone provides the minimal diagnostic needed before an authorized artifact/setup correction. No gameplay source defect was confirmed by this task, and no live result is claimed from offline checks.
