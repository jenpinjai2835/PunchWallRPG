# Final release verification review — 2026-09-06

Review baseline: integration `2fe4deada0efe8cbd3cab38a77c5d4edb992af7b`, with the Coordinator's newly added read-only live-source checker inspected during this review. Scope was read-only except this document. No Studio, build, output-file mutation, or HQ operation was performed by the reviewer. The worker worktree was clean at `1e45d78` before this assignment.

**Release remains BLOCKED pending final integrated fixes, the complete 124-flow run, build, independent reopening, evidence and Git gates.** Earlier targeted passes do not satisfy these gates.

## Findings

1. **P2 — the original full-suite wrapper does not close its freeze at completion.** `work/tools/smash-verified-full-suite.ps1` checks nine disk sources before each flow and checks only the next flow's hash. A change during the last flow, an already-run flow changing, an added flow, or a runner/helper edit can escape `manifest.ok`. The source-sync JSON is historical evidence, not a live Studio check. The Coordinator is upgrading this wrapper; that upgrade was not yet reviewed as complete here. Require exact source, all-flow and infrastructure file inventories/hashes before and after each flow and again at finalization, including additions/removals. Save the initial manifest before the first flow, record failure/interruption explicitly, and never count exclusions or partial execution as full PASS. Hash the wrapper itself, sync/live checker, `flow_runner.mjs`, `studio_mcp_client.mjs`, and console-classification support files used by the runner.

2. **P2 — the existing final-artifact wrapper alone does not prove the live place came from the rebuilt bytes.** `run-final-artifact-regression.ps1` verifies canonical/validation disk equality, exact embedded sources, Studio id/name, behavior and unchanged disk hashes afterward. It neither opens the file nor compares live Edit source bytes with the artifact. A same-named stale or resynced in-memory place can otherwise pass. The new `smash-live-source-check.mjs` provides the missing source comparison when run after a genuinely new open and before/after runtime, without sync. Opening evidence and the actual selected validation-copy id are still required. Retain fresh Edit template/property checks as well: source identity alone does not identify non-code assets or settings.

3. **P2 — freeze and verify the approved asset template explicitly.** The build default input is the old canonical place, not the reviewed premium-template staging place. Independently read hashes still match: canonical `605A4F70169FD0C7C86635B20171576DC4A81C46B10A4E28C8744F4F29A40208`; reviewed staging `22406EFE5CFFCE2B6A4FC6669D99E1AC094BFDB8EAE7CDC59B760B86EC00191E`. Pass `-SourcePlace work/tools/smash-asset-template.rbxlx` explicitly and assert its hash against `smash-premium-template-repair-20260906.json` before/after build. Runtime sanitation could hide an old unsanitized template, so runtime attestation alone is insufficient proof that the approved staging file was used. Preserve the known repair recipe, original hash and staging hash in final evidence.

4. **P2 — preserve the verification procedure durably.** The three new verification helpers are under ignored `work/tools`; a clean clone cannot reproduce the recorded command merely from their paths. Before final handoff, promote the reviewed helper contents to tracked automation paths or preserve their exact contents and SHA-256 in a tracked evidence/release record. Do not describe an ignored, unrecorded local helper as a repository gate. Current source/flow fixes, all final evidence and final artifacts must be traceable to reviewed commits; the integration tree currently contains many untracked evidence files and a completion note, which still need explicit disposition.

## What the existing checks do prove

The build and independent XML verifier enforce the exact nine Lua source files and global nine code-object allowlist, expected class and parent paths, normalized source equality/SHA-256, and one CDATA node per source. The embedder checks source inventory before mutation; the builder verifies a temporary artifact before publishing, verifies the published file again, and records source/template/output hashes. Its canonical overwrite guard and separate template/output paths are appropriate. The `studioHarnessGuarded` flag is only a substring check; actual server harness/persistence contracts and runtime authority remain the meaningful safeguard.

The final-artifact wrapper correctly requires a byte-identical canonical validation copy, restricts the validation Studio filename, runs once, and rechecks disk hashes after runtime. `-StaticOnly` explicitly reports `NOT_RUN_STATIC_ONLY`; it must not be promoted into a runtime PASS. Its native flow checks nine-module topology, world bootstrap, HUD/Inventory/Shop/Spin/music, training, supplied visuals and eleven attested pet templates. It is a useful reopened-artifact smoke check, not a replacement for the integrated 124-flow suite or device/camera regressions.

The new live checker sends safely delimited expected source into Edit and performs actual normalized byte equality in Studio; it does not trust a truncated source dump or a weak checksum as exact identity. Its sentinel prevents Lua long-string leading-newline removal. Nine global LuaSourceContainers plus unique expected name/class/parent matches reject extra or relocated code. The recorded `smash-readonly-live-source-preflight-20260906.json` contains nine successful exact comparisons and is valid source preflight evidence for that moment. It is not rebuilt-artifact evidence. Two small additions were reported to the Coordinator: match the actual DataModel `live.name` against the expected name, and record/validate the two BaseScripts' enabled state and RunContext against the artifact. The current canonical XML has both scripts `Disabled=false`, `RunContext=0` (Legacy).

## Minimal execution plan for the Coordinator

Run these only after A1/A2 fixes and their tests are integrated, Studio ownership is exclusive, and the wrapper freeze changes above are verified. Commands are based on actual available scripts; they were reviewed but not executed here.

```powershell
Set-Location -LiteralPath 'F:/Roblox/PuchWall-completion-20260906'
$releaseStudioId = '0103740f-e1f7-4401-978a-bf2c80d66bde'
$releaseSync = 'work/docs/evidence/smash-source-sync-release-20260906.json'
git diff --check
git status --short
node work/automation/scripts/sync_rojo_source_to_studio.mjs --studio-instance-id $releaseStudioId --studio-name '^PunchWallRPGPlayable_v1_final[.]rbxlx$' --place-name '^PunchWallRPGPlayable_v1_final[.]rbxlx$' > $releaseSync
if ($LASTEXITCODE -ne 0) { throw 'Release source sync failed' }
node work/tools/smash-live-source-check.mjs $releaseStudioId '^PunchWallRPGPlayable_v1_final[.]rbxlx$' > work/docs/evidence/smash-live-release-before-20260906.json
if ($LASTEXITCODE -ne 0) { throw 'Live release source check failed' }
& work/tools/smash-verified-full-suite.ps1 -EvidenceDirectory 'smash-verified-full-release-20260906' -SourceSync $releaseSync
```

Require the frozen manifest's exact 124 distinct expected flows, zero exclusions, zero failed/interrupted checks, complete per-flow evidence, unchanged inventories and final live proof. Do not use this integrated run's overridden `final-rbxlx-build-validation` Studio name as artifact evidence. Any source change invalidates the release candidate; rerun the appropriate checks and combined gate against the new frozen candidate.

After that gate, run build tooling controls and deliberately replace only the task-owned canonical output:

```powershell
& work/automation/release-build-contract.ps1
$repair = Get-Content -LiteralPath work/docs/evidence/smash-premium-template-repair-20260906.json -Raw | ConvertFrom-Json
$template = 'work/tools/smash-asset-template.rbxlx'
if ((Get-FileHash -LiteralPath $template -Algorithm SHA256).Hash -ne $repair.outputSha256) { throw 'Reviewed template changed' }
& work/automation/build-production.ps1 -SourcePlace $template -OutputPlace outputs/PunchWallRPGPlayable_v1_final.rbxlx -ManifestPath outputs/SmashWall_Production.build.json -AllowCanonicalFinalOutput
Copy-Item -LiteralPath outputs/PunchWallRPGPlayable_v1_final.rbxlx -Destination outputs/PunchWallRPGPlayable_v1_final_validation.rbxlx -Force
& work/automation/run-final-artifact-regression.ps1 -StaticOnly
```

Before those writes, reconcile both output files' Git status to avoid overwriting unrelated work. Compare the build manifest's source hashes to the passing suite's freeze, its template hash to the reviewed repair hash, and both final file hashes to the build output hash. Capture the command output and keep the generated build manifest.

Close the prior Play/Edit session as appropriate and open the canonical validation copy from disk using the Coordinator's native Studio/file-opening workflow. Record the opening action, exact path, new observed Studio id/name and local place identity. **Do not run source sync after this open.** With `$validationStudioId` set to the actual newly observed id:

```powershell
node work/tools/smash-live-source-check.mjs $validationStudioId '^PunchWallRPGPlayable_v1_final_validation[.]rbxlx$' > work/docs/evidence/smash-artifact-live-before-20260906.json
if ($LASTEXITCODE -ne 0) { throw 'Reopened artifact source mismatch' }
& work/automation/run-final-artifact-regression.ps1 -StudioInstanceId $validationStudioId -ExpectedPlaceName 'PunchWallRPGPlayable_v1_final_validation.rbxlx' | Set-Content -LiteralPath work/docs/evidence/smash-artifact-runtime-20260906.json -Encoding utf8
node work/tools/smash-live-source-check.mjs $validationStudioId '^PunchWallRPGPlayable_v1_final_validation[.]rbxlx$' > work/docs/evidence/smash-artifact-live-after-20260906.json
if ($LASTEXITCODE -ne 0) { throw 'Artifact changed during runtime verification' }
```

The actual observed DataModel name must be used if Studio reports a different concrete name; do not guess or broaden patterns. Before Play, inspect the three repaired templates' strict hazards, retained model/mesh identity, settings and script execution properties against the staged/output XML. After the embedded bootstrap flow, run the existing relevant device/Shop/Inventory, first-five fist parity, camera/target and fresh-player flows on that same reopened id without sync; retain native evidence. Recheck canonical/copy hashes and frozen source/flow/tool inventories at the end.

Finally, update the completion/QC record to one coherent final source commit, full-suite manifest, artifact SHA and reopened-copy evidence. Review/stage only intended sources, tests, durable helpers, evidence, build manifest and final outputs. Run `git diff --check`, inspect the staged diff and hashes, commit the deliberate artifact handoff, and follow the repository's reviewed integration/PR/merge gates. Keep historical failures identified as historical; report any remaining failed or unavailable required gate as BLOCKED. No publish, merge or bug-free claim follows merely from a build script returning `ok=true`.
