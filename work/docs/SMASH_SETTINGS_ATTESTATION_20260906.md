# Settings control lifetime attestation — 2026-09-06

Owner: HQ agent-1. Branch `codex/test/smash-settings-attestation-20260906`, base `2fe4deada0efe8cbd3cab38a77c5d4edb992af7b`. Scope is the full-game native-input flow, its offline contract, and this document. No product source, Studio state, server fixture, registry, or other flow was changed.

## Proven failure and source dependency

Coordinator evidence `work/docs/evidence/smash-settings-event-diagnostic-20260906.json` in the integration tree records the original Motion button armed at 14990.5398, ancestry changes at 14990.8496, and destruction at 14990.8501 while Motion was still true. That button received no Down, Up, or Activated event. The later native gesture changed Motion through its replacement. The earlier targeted-10 failure therefore exposed a real control lifetime defect, not grounds to remove the original observer's Parent check.

The previous `renderStandaloneSettings` called `clearStandaloneBody(settingsBody)` on unrelated StatsChanged updates and again synchronously after an option selection. A2 owns the product fix, immutable source commit `2efa8b306c913ba2e304f65fcb1c38963736a8cd`, integrated by Coordinator as `aefa18c`. Read-only inspection confirms its seven options and Footer.Done are reused while valid; selected colors and state update in place. This handoff supplies consumer evidence for that source and does not claim a product-source implementation of its own.

Coordinator's subsequent `smash-settings-event-diagnostic-after-20260906.json` reports the same Motion button Armed at 15821.185, Down at 15821.777, Up/Activated at 15822.111, Parent Options throughout, no destruction, and final Motion false on `aefa18c`. This is focused actual producer evidence; the strengthened complete 25-gesture flow still requires its own run.

## Flow behavior

- Observe the actual seven option instances and Footer.Done, using a unique string identity plus original-instance Destroying and AncestryChanged listeners. A same-name replacement carrying copied identity attributes still fails through the original lifetime events. Deferred ancestry delivery compares its event parent, catching a transient reparent followed by restoration.
- Before arming Motion, allow initial geometry to settle for at least 0.5 seconds and remain stable for 0.2 seconds, bounded by two seconds. Then require a subsequent real StatsChanged payload with increasing PlaytimeSeconds within three seconds. All eight original instances and settled positions/sizes must survive, and the authoritative request sequence must remain unchanged. The observation does not invoke a snapshot hook, request action, or synthesize input.
- Recheck all eight controls after each of the five existing Settings selections. Scale-driven geometry changes are allowed between selections; original instance identity must remain intact. The idle geometry check applies only to the unrelated clock tick at the settled initial scale.
- Keep all 25 original Activated observers, including their Parent and exact action marker gates. Keep the original 25 native gestures, seven server chunks, nine exact authoritative requests, and CALM/OFF assertions byte-identical. No retries or extra actions were added.
- Disconnect all 18 bounded lifetime listeners before the existing Settings Close gesture, allowing up to 0.5 seconds for deferred signal delivery. HUD destruction also disconnects them. The temporary clock listener is disconnected on success and error. Cross-call state contains serializable attributes only; no shared Instances or functions are stored.

Only client steps 44, 46, 48, 50, 52, and 55 change. The existing duplicated Tasks idle helpers remain identical to the separate legacy-slot flow.

## Offline verification

Command: `node work/automation/scripts/full-game-real-ui-controls-contract.mjs`.

PASS: 56 contract checks, 94 executable Settings assertions, all 34 flow Luau chunks compiled with official Luau 0.737. The exact new flow helpers run under immediate and deferred event mocks. Cases cover stable idle snapshots and all five selections, the exact extracted production `clearStandaloneBody` operation causing the historical failure, post-selection copied-token replacement, destruction before detachment, transient reparenting, incorrect identity, absent/unchanged clock updates, changed authoritative request count, unstable or moved geometry, and actual listener cleanup on close/HUD destruction.

All nine compiled helper weakening controls were rejected: ignored lifetime loss, ignored identity, missing Destroying observer, missing ancestry observer, skipped lifetime disconnect, accepted absent clock update, accepted request mutation, accepted geometry movement, and leaked idle listener. These prove the consumer oracle catches the historical operation; executing the complete old/new Settings producer is covered separately by A2's source contract.

Existing validation remains PASS: 2,450 executable coordinate assertions across all 25 prechecks, six coordinate weakening controls, exact native-input/callback/request checks, and unchanged duplicated Tasks focus-settling helpers. A separate parsed baseline comparison verifies all 25 gesture steps, all seven server chunks, and all 25 original Activated+Parent blocks are byte-identical to `2fe4dea`. `git diff --check` passes.

## Integration status and limits

Checklist: source/setup diagnosis complete; strengthened flow and executable controls complete; isolated three-file handoff complete. Integrate after A2's stable Settings source. Required native Studio execution of all 25 gestures is **BLOCKED pending Coordinator runtime evidence**. Offline signal mocks do not establish real device input behavior, FPS, multiplayer behavior, or production persistence. No live purchases or publishing occurred.
