# Detailed premium template repair — 2026-09-06

Owner: Coordinator, SMASH-20260906. Three existing templates needed the same strict sanitation already applied to their runtime clones. No assets were downloaded or replaced with different artwork.

| Template | Creator Store ID | Retained parts / effects | Removed joints |
| --- | --- | --- | --- |
| Crimson Phoenix | 86478691482535 | 1 / 0 | 0 |
| Storm Wyvern | 83562531232957 | 35 / 4 | 34 |
| Celestial Guardian | 121956330907081 | 10 / 0 | 9 |

The generator executes the actual `FistVisualBuilder.SanitizeVisual` implementation, adapting Luau syntax for rbxmk 0.9.1 and omitting only nonserialized assembly velocity writes. A loaded Roblox API descriptor is mandatory. Only malformed *empty* attribute buffers are repaired; nonempty corrupt attributes fail closed.

The XML applicator replaces exactly these three subtrees in a distinct staging place. It matches each retained original instance by unique path and class, preserves its original properties except the fields intentionally changed by sanitation, and remaps references. This avoids rbxmk 0.9.1 silently dropping modern `Content/uri` mesh properties. Unrelated XML and shared-string values are verified before and after serialization. References to discarded objects, duplicate referents, ambiguous instance paths, and the canonical output path are rejected.

Reproduction from the isolated integration worktree (absolute input paths required):

```powershell
& 'F:/Roblox/PuchWall/work/tools/rbxmk/rbxmk.exe' run --desc-latest --include-root $taskRoot work/automation/scripts/repair-premium-pet-templates.rbxmk.lua $normalizedInput $repairedModels $builderSource
& work/automation/apply-premium-template-repair.ps1 -InputPlace $originalPlace -RepairedModels $repairedModels -OutputPlace $stagingPlace
& 'F:/Roblox/PuchWall/work/tools/rbxmk/rbxmk.exe' run --desc-latest --include-root $taskRoot work/automation/scripts/premium-template-sanitizer-test.rbxmk.lua $builderSource
& 'F:/Roblox/PuchWall/work/tools/rbxmk/rbxmk.exe' run --include-root $taskRoot work/automation/scripts/premium-import-content-guard-test.rbxmk.lua $legacyImporter
```

`$normalizedInput` is an owned temporary copy with only the optional leading XML declaration/BOM removed, because this rbxmk parser rejects an XML declaration. The original place is not modified. The final production builder must use the verified staging template and embed the separately accepted nine source files. Staging is not the delivery artifact.

Validation:

- Actual production sanitizer: **PASS 20 controls**, including harmful descendants, mutated attestation/physics state, empty-buffer repair and nonempty-buffer rejection.
- Legacy whole-place importer preflight: **PASS 8 controls**. Every incoming XML file is scanned for any nonempty `Content/uri`; such input is rejected before DataModel deserialization or output. Legacy binary import fidelity is not claimed; this task uses the preserving repair pipeline.
- Applicator negative controls: **PASS 3**, rejecting canonical output, missing template, and references to a discarded wrapper without overwriting a sentinel or the original place. Evidence: `evidence/smash-asset-repair-negative-20260906.json`.
- Independent Agent 3 review: **86 retained nodes and 2,722 visual properties match**, including all **34 Wyvern mesh URIs**; all **44 shared strings** and unrelated content match; no duplicate/dangling refs or unsafe retained classes.
- Actual Studio Edit before/after: strict templates **8/11 → 11/11**, unsafe joints **43 → 0**, visual totals remain **126 parts / 16 effects**. `smash-pet-edit-before`, `smash-pet-edit-repair`, and `smash-pet-edit-after` evidence records preserve results. Runtime `creator-store-pet-pack-visuals` also passed in the targeted camera/asset run.

Original canonical SHA-256: `605A4F70169FD0C7C86635B20171576DC4A81C46B10A4E28C8744F4F29A40208`.

Reviewed staging SHA-256: `22406EFE5CFFCE2B6A4FC6669D99E1AC094BFDB8EAE7CDC59B760B86EC00191E`.

Final combined runtime, rendered visual review, rebuilt artifact checks and release remain separate required gates. This record does not claim the original canonical place has been rebuilt.
