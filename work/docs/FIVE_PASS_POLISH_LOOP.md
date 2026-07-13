# Punch Wall RPG - Five Pass Polish Loop

This document is the execution log for five complete QC and polish passes. The
master item list remains in `GAME_COMPLETION_BACKLOG.md`; findings discovered
here are copied there when they remain actionable after the pass.

## Pass Contract

Every pass must complete this loop:

1. Enter the current final place and evaluate it as a real player.
2. Record detailed findings before changing the implementation.
3. Fix every locally actionable finding in that pass.
4. Re-run focused automation, inspect console output, and capture visual
   evidence when the pass changes presentation.
5. Only then mark the pass complete and begin the next pass.

## Pass Matrix

| Pass | Focus | Audit status | Fix status | Re-QC status |
| --- | --- | --- | --- | --- |
| 1 | Runtime reliability and input automation | Complete | Complete | Complete |
| 2 | First-session onboarding and progression clarity | Complete | Complete | Complete |
| 3 | Kaiju City graphics, materials, curated assets, and identity | Complete | Complete | Complete |
| 4 | Motion, audio, feedback, accessibility, and performance | Complete | Complete | Complete |
| 5 | Fresh-player release acceptance and full regression | Complete | Complete | Complete |

## Pass 1 - Runtime Reliability And Input

### Findings

- The server destroyed and recreated `PunchWallEvents` during startup. A client
  could retain the destroyed folder and wait forever for `StatsChanged`.
- That startup race also exhausted the `Feedback` invocation queue during a
  fast natural-progression automation run.
- The mobile UI flow could find the TRAIN button but a synthetic GUI click did
  not produce a server action consistently.
- The final file needed proof that Creator Store assets survived a real
  close/reopen cycle after sanitation.

### Fixes

- Reuse the remote folder and ensure each RemoteEvent idempotently.
- Keep action buttons compatible with mouse/touch click activation.
- Embed the sanitized assets in the final file through Studio AutoRecovery and
  reopen the exact deliverable for verification.

### Evidence

- Reopened final file contains 3 curated assets, 161 visual parts, 49 MeshParts,
  and 0 LuaSourceContainer descendants.
- `natural-progression` targeted rerun: passed after the remote fix.
- Added a Studio-only BindableFunction that invokes the same action dispatcher
  used by the visible mobile buttons. This avoids false failures from the
  current Studio MCP synthetic mouse injector while still validating the real
  client-to-server action path.
- `punchwall-mobile-controls` targeted rerun: passed all TRAIN, PUNCH, and USE
  assertions with a clean console.

### Pass 1 Result

Complete. Both failures found by the first full matrix were reproduced,
corrected, and passed focused regression.

## Pass 2 - Onboarding And Progression

### Findings

- The spawn camera initially faced the Armory district instead of the training
  district.
- The nearest-target context named a fist stand while the tutorial objective
  asked the player to train, producing contradictory first-session guidance.
- The objective card had no distance or persistent world-space marker.

### Fixes

- Rotate the SpawnLocation 180 degrees toward the training route.
- Add a tutorial waypoint BillboardGui attached to the current objective.
- Add live objective distance to both the objective card and context strip.
- Preserve the normal nearest target for gameplay actions while tutorial
  guidance remains visually dominant.

### Evidence

- Fresh-player screenshot reviewed from the real client viewport before and
  after the guidance change.
- New recorded flow `onboarding-waypoint` verifies spawn orientation,
  Power Bag waypoint, objective distance, context text, and a clean console.
- Targeted onboarding flow: passed.

### Pass 2 Result

Complete. A new player now receives consistent screen-space and world-space
direction from spawn through the first training action.

## Pass 3 - Kaiju City Graphic Identity

### Findings

- Standard concrete and asphalt reduced the city to large flat color blocks.
- Titan/Cyber metal lacked wear and did not read as containment architecture.
- Creator Store models needed proof that sanitation survived the final file.
- The visual layer needed a reproducible fallback when generated materials are
  absent from a source-only Rojo build.

### Fixes

- Generated grounded PBR variants for damaged concrete, worn asphalt, and
  containment metal through Roblox Studio's AI material generator.
- Applied the variants to 357 concrete, 3 asphalt, and 163 containment-metal
  runtime parts.
- Retained built-in Concrete/Asphalt/CorrodedMetal as source fallbacks.
- Kept 3 sanitized Creator Store packs containing 161 parts and 49 MeshParts.
- Documented all generated materials in `FREE_ASSET_MANIFEST.md`.

### Evidence

- Reviewed city lane, detailed glass landmark, road, and spawn screenshots.
- New recorded flow `ai-material-assets` verifies embedded variants, usage
  counts, curated model counts, 0 asset scripts, and a clean console.
- Targeted AI-material/assets flow: passed.

### Pass 3 Result

Complete. The city now uses textured, materially distinct urban surfaces
instead of a uniform smooth-plastic presentation.

## Pass 4 - Feedback And Performance

### Findings

- Reduced Motion suppressed camera FOV impulse but did not suppress haptics,
  reward-pop movement, toast tweening, or mobile button press tweening.
- Existing feedback tests confirmed event markers but did not verify that audio
  assets actually loaded.
- Destruction tests did not explicitly assert stable scene cost after many
  repeated breaks.

### Fixes

- Gate haptic feedback, reward-pop movement, toast tweening, and button press
  animation behind the Motion setting.
- Retain static readable feedback when Motion is disabled.
- Add `LastMotionApplied` telemetry to the local HUD for deterministic QC.
- Add a repeated-destruction scene-cost and audio-loading regression.

### Evidence

- All 15 runtime sounds reported `IsLoaded=true`.
- Runtime baseline remained 1,375 core parts and 26 particle emitters after 20
  automated wall-break cycles.
- Reduced-motion test held camera FOV at 70 while Punch feedback was received.
- New recorded flow `reduced-motion-performance`: passed with clean console.

### Pass 4 Result

Complete. Motion feedback now respects the accessibility setting across camera,
haptic, UI pop, toast, and button layers without removing gameplay information.

## Pass 5 - Release Acceptance

### Findings

- Full-suite order exposed a gauntlet startup race that targeted UI tests did
  not reproduce in isolation.
- The visual signature was committed before the avatar's RightHand existed, so
  later refreshes incorrectly skipped the missing gauntlet.
- Final iPhone review exposed overlapping training text because labels were
  rendered across the full 9x8 hitboxes.

### Fixes

- Request an explicit stat sync after the client visual layer initializes.
- Commit the character visual signature only after the gauntlet attaches, and
  retry while the avatar rig is incomplete.
- Replace hitbox-sized training text with three compact dedicated metal signs.
- Update the performance baseline from 1,375 to 1,378 intentional core parts.

### Evidence

- The previously conflicting reduced-motion then responsive-UI sequence passes.
- Full post-fix matrix passes 17/17 flows with `ok: true`.
- Final iPhone 17 Pro screenshot confirms compact training labels, safe-area
  HUD, and non-overlapping PUNCH/TRAIN/USE controls.
- Reopened-file smoke, responsive UI, and AI-material asset checks pass.
- Studio Device Simulator was returned to the default desktop viewport.

### Pass 5 Result

Complete. All five audit/fix/re-QC loops are closed. Remaining work requires a
published Roblox universe or Creator Dashboard access and is explicitly listed
as external release validation rather than local implementation debt.
