# Studio console classification — 2026-09-06

Agent HQ: SMASH-20260906, Agent 2. Branch `codex/fix/smash-console-qa-20260906`; base `80319ce`.

## Behavior

The camera/Shop behavior checks passed, but the final console assertion rejected a known Roblox Studio Assistant warning because its tool stack contained Stack Begin and Stack End. The recorded case is `work/docs/evidence/smash-camera-shop-stability-repeat2-20260906.json` in the integration worktree.

`flow_runner.mjs` now exports `classifyStudioConsole` and the production `runAssertion` function. The classifier recognizes only a complete top-level block with this exact structure:

1. The exact Roblox/sabuiltin_Assistant TestAutomationUtils header for `VirtualInput::SendMousePosition: position (numericX, numericY) hits CoreGUI.`
2. An immediate `Stack Begin` line.
3. One or more exact Script lines belonging solely to `sabuiltin_Assistant.rbxm.Assistant.Packages._Index.AssistantUI.AssistantUI.Util.TestAutomationUtils`, with positive integer line numbers.
4. An immediate `Stack End` line.

No generic CoreGUI, Assistant, Script or stack filter was added. Other console lines continue through the existing error-pattern rules. Mixed game/helper stacks, another helper, changed messages, blank/interleaved frames, nested stacks, incomplete blocks and lone recognized headers are not exempted. A recognized block nested inside an unclassified stack is retained as part of that stack.

The original context string is never changed. Every console assertion appends a `consoleClassifications` record to both successful and failed flow results. It contains the original untruncated text, retained lines with original line numbers, suspicious lines, and identified warning spans/frame counts. `identifiedToolWarningCount` is reported per assertion/capture, not as a deduplicated count across separate console captures. Successful console check labels also report the count.

## Validation

PASS: `node work/automation/scripts/studio-console-classification-contract.mjs` — 28 fixtures execute the exported classifier and actual assertion path. Each fixture checks expected acceptance/counts, unchanged original text, complete line accounting and evidence retention on both success and failure.

Coverage includes the exact recorded warning and game notice; LF/CRLF; repeated known warnings; ordinary/empty logs; game errors before or after the warning; mixed/unknown/similarly named helper frames; unrelated, nested, missing or empty stacks; unexpected frame annotations; changed method/header/coordinates; an extra Stack End; custom error patterns; and console text longer than 4,000 characters.

PASS: direct replay of the actual repeat2 evidence through the production assertion: one identified tool-warning block, zero remaining suspicious lines, original console preserved. This replay reads recorded evidence; it is not a new Studio run.

PASS: `node work/automation/scripts/flow_runner.mjs --self-test` (all 12 existing selection/input checks), Node syntax validation, and git diff --check.

## Integration

Only the runner, this new contract and this document changed. No Studio operation, game source, flow JSON, registry or HQ mutation was performed. The Coordinator owns static-contract registration and the next combined runtime execution. New or changed Studio warning formats remain unclassified until separately reviewed; they must not be handled by broadening the filter indiscriminately.
