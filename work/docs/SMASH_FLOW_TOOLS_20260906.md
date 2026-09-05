# Recorded flow identity forwarding — 2026-09-06

Agent HQ: SMASH-20260906, Agent 2. Branch `codex/fix/smash-flow-tools-20260906`; base `47fdf52`.

## Problem and change

An explicit ExpectedStudioName was previously checked only after execution by `invoke-recorded-flow.ps1`. The helper omitted `--studio-name`, so flow_runner could still select using the flow's stale Studio name. `run-existing-flows.ps1` also had no ExpectedStudioName parameter to forward.

The suite now accepts ExpectedStudioName and passes it with ExpectedPlaceName to the actual helper, `work/automation/invoke-recorded-flow.ps1`. The helper forwards both names independently as `--studio-name` and `--place-name` to flow_runner. The suite appends its new parameter after the existing parameters to preserve their positional order.

An explicit Studio name can serve as the selector when a flow has none. A Place name alone still cannot select a Studio. Caller UUID overrides, flow UUID defaults, flow name defaults, and returned identity verification remain intact. ExpectedPlaceName never implicitly becomes ExpectedStudioName; callers must specify each intended override.

No gameplay source, flow JSON, flow_runner implementation, other suite wrappers or registry changed.

## Validation

Fail-before: the new executable fixture ran the original helper against a mock runner and failed with `explicit Studio regex was not forwarded intact` because `--studio-name` was absent.

PASS after the fix: `node work/automation/scripts/automation-infrastructure-contract.mjs` — 27 contract groups, including 26 executable forwarding cases across `pwsh` and Windows `powershell`, plus the existing runner self-test. All 121 flow JSON files parse and retain fail-closed selectors.

Each shell executes 13 cases using copies of the production suite/helper and an inert temporary mock runner: explicit names plus UUID; propagation through every flow in a two-flow suite; helper and suite defaults; a name-only selector; selectorless rejection; Place-only rejection; mismatched returned UUID, Studio and Place; independent Place override; blank-name fallback; and missing returned identity. Regex arguments include spaces and escaped punctuation. Tests assert exact recorded argument values, invocation counts and failure outcomes.

The fixture never loads the MCP client or contacts Studio. It requires an available PowerShell and fails explicitly if none is present. POWERSHELL_COMMAND can select a specific shell. Temporary cleanup is restricted to the verified task-created directory under the system temp directory.

PASS: git diff --check. No Studio/runtime run was needed or performed for this argument-forwarding fix. The Coordinator owns integration and combined gameplay verification.
