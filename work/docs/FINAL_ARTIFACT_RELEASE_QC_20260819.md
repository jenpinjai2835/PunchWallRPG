# Final Artifact Release QC — 2026-08-19

## Scope

Release-artifact remediation on `codex/fix/qc-release`, based on
`develop@6dc441334f957d0fe6d9b086b5bb5cc3a65b1cd1`. No Roblox Studio session was
opened.

## Artifact identity

| File | Bytes | SHA-256 |
| --- | ---: | --- |
| `outputs/PunchWallRPGPlayable_v1_final.rbxlx` | 5,593,417 | `9EB3133E347D5632C3A844AE5627FD3511F7E1B8105B8C1C31641C46E390574E` |
| `outputs/PunchWallRPGPlayable_v1_final_validation.rbxlx` | 5,593,417 | `9EB3133E347D5632C3A844AE5627FD3511F7E1B8105B8C1C31641C46E390574E` |

The validation copy is byte-identical to the canonical final artifact.

## Code-object allowlist

The final artifact contains exactly nine code objects. Each object must match
its canonical path, Roblox class, and exact source text:

1. `ReplicatedStorage/GameConfig` — `ModuleScript`
2. `ReplicatedStorage/PolishConfig` — `ModuleScript`
3. `ReplicatedStorage/ForestVisualBuilder` — `ModuleScript`
4. `ReplicatedStorage/FistVisualBuilder` — `ModuleScript`
5. `ReplicatedStorage/InventoryViewModel` — `ModuleScript`
6. `ServerScriptService/ProfilePersistence` — `ModuleScript`
7. `ServerScriptService/PunchWallBootstrap` — `Script`
8. `StarterPlayer/StarterPlayerScripts/InventoryUI` — `ModuleScript`
9. `StarterPlayer/StarterPlayerScripts/PunchWallClient` — `LocalScript`

The build removed all 13 code objects found below `ServerStorage/CreatorStoreQC`.
The generated manifest records their classes and paths. Verification reports
`codeObjectCount=9` and `rejectedCodeObjectCount=0`; an injected tenth code
object is rejected by the release contract.

## Build safety and recoverability

`build-production.ps1` built a temporary candidate, embedded current canonical
source, verified exact source plus the global allowlist, and only then moved the
verified file over the output path. The pre-remediation artifact remains
recoverable from Git and had SHA-256
`1A772E92646C8E35B6EBB852DA92ABAD35851E5A97EC5116C5D3A869FF3643B8`.

## Checks run

- Both final files: exact-source verification passed for 9/9 objects; global
  code allowlist passed with 9 objects and zero rejected extras.
- Release build contract: passed; 13/13 injected imported behaviors sanitized;
  seven negative/guard checks passed, including rejection of an extra code
  object.
- Static-only final artifact regression: passed; both artifacts were
  byte-identical, source-exact, and allowlist-exact.
- Full non-Studio static aggregate: passed — Node syntax 44 files, PowerShell
  syntax 18 files, Luau compile 27 cases across 9 files and 3 optimization
  levels, 113 flow JSON files, 24 executed static contracts, and 450 reported
  contract assertions (the long-run contract does not expose an assertion
  count). The intentionally excluded Studio-capable inventory performance
  benchmark remains explicitly classified by the aggregate.

Commands:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File work/automation/verify-exact-rbxlx-sources.ps1 -PlacePath outputs/PunchWallRPGPlayable_v1_final.rbxlx -SourceRoot work/punch-wall-rpg/src
powershell -NoProfile -ExecutionPolicy Bypass -File work/automation/verify-exact-rbxlx-sources.ps1 -PlacePath outputs/PunchWallRPGPlayable_v1_final_validation.rbxlx -SourceRoot work/punch-wall-rpg/src
powershell -NoProfile -ExecutionPolicy Bypass -File work/automation/release-build-contract.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File work/automation/run-final-artifact-regression.ps1 -StaticOnly
powershell -NoProfile -ExecutionPolicy Bypass -File work/automation/run-automation-static-contracts.ps1 -LuauCompileCommand C:/Temp/codex-luau-0.730/luau-compile.exe
```

## Remaining gate

Runtime playtest regression is `NOT_RUN_STATIC_ONLY`. It requires the exact
validation copy to be opened in Roblox Studio and is intentionally not treated
as a pass. The artifact/static gate is complete; runtime release acceptance
remains a Coordinator/Studio gate.
