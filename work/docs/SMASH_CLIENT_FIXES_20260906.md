# Smash Wall client stability fixes — 2026-09-06

Agent HQ task: `SMASH-20260906`, Agent 2. Worker branch:
`codex/fix/smash-client-20260906`, base `4094e51`.
Integration and Studio validation belong to the Coordinator.

## Confirmed defects and changes

1. **Fists remain depth-locked after progress.** Shop card rendering and action
   bindings read `latestStats.Depth`, but the cache signature omitted it. An
   ordinary Shop close/reopen reused the previous locked cards when only Depth
   changed. The Fists signature now includes normalized authoritative Depth.
   The new flow advances Depth with unchanged ownership/equipment and reopens
   through `OpenTab`; it never calls the force-refresh `OpenShopPage` helper
   used by older catalog flows. Resetting Depth also relocks a visible offer.

2. **Punch feedback overwrites live camera input.** Every follow frame replayed
   the punch-start CFrame, discarding rotation and zoom applied by Roblox's
   camera controller. Feedback now offsets the current camera and focus by the
   remaining translation lag. The camera's current orientation and orbit stay
   intact. The suspended-render Heartbeat path advances the last unmodified
   pose by root displacement, preventing repeated application of the same lag.
   Starting with a Scriptable camera does not steal it; switching to Scriptable
   during a punch cancels follow without restoring the former camera owner.
   Existing translation limits and geometry guard remain in place.

3. **Boost countdown repeatedly destroys the Shop.** Remaining seconds were
   structural cache inputs, so each displayed-second tick rebuilt all buttons
   and the ScrollingFrame. The signature now tracks authoritative expiry
   timestamps. A bounded registry updates the existing two action labels and
   colors. Expiry restores `BUY`, including its hover color, and stops the
   scheduler. Hidden and stale-generation callbacks do no work. A same-page
   structural refresh preserves the scroll position; changing pages starts
   at the top.

These changes do not alter reward, purchase, ownership, damage, or progression
authority. They do not constitute the requested Shop/Inventory art redesign.

## Executable worker validation

Run from the worker or integrated repository:

```powershell
node work/automation/scripts/camera-shop-stability-contract.mjs --baseline 4094e51
node work/automation/scripts/camera-shop-stability-contract.mjs
node work/automation/scripts/client-runtime-performance-contract.mjs
node work/automation/scripts/long-run-content-contract.mjs
git diff --check
```

The new test extracts and executes the actual production Luau functions using
small camera, clock, scheduler, and UI adapters. It finds `LUAU_COMMAND`, a
restored `%TEMP%/codex-luau-*` CLI, or `luau` on PATH. A missing interpreter
fails with an explicit blocker. No Roblox client or external service is used.

| Check | Result |
| --- | --- |
| Baseline `4094e51` camera input | Expected failure reproduced: `camera_input_preserved` |
| Baseline `4094e51` Depth cache | Expected failure reproduced: `depth_invalidates` |
| Baseline `4094e51` ticking boost signature | Expected failure reproduced: `boost_without_rebuild` |
| Current extracted production functions | PASS 17: camera 6, Depth 4, Boost 7 |
| Existing client runtime/performance contract | PASS 26/26 |
| Existing long-run catalog contract | PASS 30/30 |
| Full client Luau 0.737 compilation (`luau-compile --null`) | PASS |
| New flow embedded Luau compilation | PASS, all 10 snippets |
| New script Node syntax and flow JSON parsing | PASS |
| Diff whitespace check | PASS |

Camera cases include changed angle and zoom during a punch, retained translation
feedback, 90 normal frames without accumulation, 90 suspended-render frames
without accumulation, and Scriptable ownership transfer. Boost cases include
unchanged structure over time, changed expiry invalidation, countdown updates,
expiry, hidden-page cancellation, and stale-generation cancellation.

## Runtime integration gate

Recorded flow: `work/automation/flows/camera-shop-stability.json`. It contains
unforced Depth lock/unlock checks, a real mouse gesture on the Boosts tab,
scroll and button-identity assertions while the countdown advances, hidden
work cancellation, Scriptable handoff, runtime/post-stop console gates, and
cleanup of its own temporary phone profile.

**PENDING COORDINATOR:** Sync the integrated source and run this flow plus
`punch-camera-smooth-follow`, `punch-camera-device-20`,
`camera-tunnel-zoom-preservation`, relevant Shop/device flows, and the required
combined regression. Studio was unavailable to this worker; the Coordinator
has since recovered access. This worker has made no Studio or visual-pass
claim. Standalone mocks do not prove Roblox camera-controller interaction,
wall occlusion, real touch input, frame pacing, or phone visual readability.

July camera/Inventory failures are historical checkpoints. August closure and
mobile/pet-recovery evidence supersede many of them. This handoff identifies
the three source defects above; it does not reclassify every old failure as a
current defect or claim overall release readiness.

Peer review correction: runtime and extracted fixtures use the actual SpeedBoost/DamageBoost catalog. Structural scroll retention is exercised separately on the 16-item Fists page.
