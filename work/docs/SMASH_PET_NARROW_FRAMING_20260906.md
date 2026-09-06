# Companion framing around the avatar — 2026-09-06

Owner: Agent 2. Source-only handoff: `052f8c6794fb682ed744927630cb7d48165fcba8`, based on `39d3c40`. Only companion helper and formation regions changed. Coordinator owns Studio, integration and final acceptance.

## Observed defect

The Coordinator's `smash-post-full-visibility-oracles-20260906/pet-size-position-qc.json` records a real 637×654 viewport. At camera distance six, premium pets had maximum avatar overlap 0.279863, above the original 0.08 limit, while pair overlap was zero and minimum world separation was 2.01747 studs. Twelve and eighteen passed. A separate run at verified 1277×780, `smash-post-full-growth-use-maximized-20260906/pet-size-position-qc.json`, recorded an intermittent 0.105413 avatar overlap at six, with the other distances passing.

The old helper independently translated each eight-corner pet box into the safe frame. It had no knowledge of the avatar or other pets. Moving a pet away from a screen edge could therefore push it onto the animated avatar. An executed production-source control reproduces that failure on `39d3c40`; this is not merely a changed fixture tolerance.

## Source behavior

The calibrated camera-plane interval solver now excludes the actual projected avatar rectangle and rectangles of previously placed companions. For each blocker it intersects the four possible separating directions with all eight corners' safe-frame intervals, then selects the nearest feasible translation. Pet blockers also preserve the original 1.45-stud minimum center separation. The world-distance requirement is enforced conservatively along the selected camera-plane axis, accounting for the existing difference in depth.

Three equipped pets create at most three blockers for the final slot and 64 candidate interval regions. The companion update queries the animated character's native bounding box once when at least one companion is due to update; it reuses the avatar corner array until its size changes. Pet bounding boxes and corner arrays remain cached. There is no added descendant traversal or work on intervening LOD frames.

Model scale, orientation, camera-plane depth and Scriptable camera ownership are unchanged by this correction. The original 1% safe inset plus half-pixel reserve, near-plane validation, projection calibration, motion smoothing, LOD and companion identity behavior remain. The solver uses a two-pixel screen gap and preserves the existing 0.08 acceptance limits; it does not increase those limits.

This is a bounded sequential layout, not a proof that every possible set of models can be packed into every viewport. If its conservative feasible region is empty, the helper returns `false` and preserves the requested pose rather than shrinking a model, changing depth, moving the camera or inventing a successful fit. A deliberately demanding 402×874 close-camera arrangement is retained as an explicit no-fit control. It does not establish that the actual game assets cannot fit there, nor does it claim a portrait runtime pass.

## Flow and diagnostics

The existing normal/premium size, world spacing, smooth-follow and reduced-motion checks remain. The separation oracle now samples twenty times over the bob window at each original distance 6/12/18, retaining the exact avatar/pair overlap and world-distance gates. Failures return complete JSON with a unique top-level `contractValid`, at most six records of actual avatar/pet rectangles, world positions/sizes, current viewport, helper fit state and camera ownership/pose checks. A later passing distance cannot erase an earlier failure.

The flow preserves the original current-viewport phase and appends focused premium size/separation/eight-corner phases at custom desktop resolutions 637×654 and 874×402. It checks actual camera dimensions separately from device metadata, rejects 1×1 viewports, and restores the simulator/removes only its two named QC presets on normal completion and cleanup. Desktop presets intentionally have no phone-notch assumption; any unexpected actual viewport mismatch remains a failed check with recorded requested and measured dimensions.

## Verification

- `node work/automation/scripts/pet-size-position-contract.mjs`: PASS all 3,155 executed assertions, including all 491 preceding assertions, 2,645 added narrow/portrait/landscape/motion geometry assertions, four cache/update wiring assertions and fifteen actual separation-payload assertions. Twenty-two compiled weakening mutations are rejected.
- `node work/automation/scripts/pet-size-position-contract.mjs --narrow-baseline 39d3c40`: PASS fail-before reproduction at `narrow_layout_preserves_safe_frame_and_clears_actual_avatar`.
- Complete client Luau 0.737 compilation at O0, O1 and O2: PASS. Updated flow and cleanup payloads compile.
- Existing power/avatar growth, fist growth lifecycle, camera geometry guard and camera/shop stability contracts: PASS.
- `git diff --check`: PASS.

Runtime status: **PENDING Coordinator verification of the synchronized immutable source and updated flow.** No measured performance improvement, device runtime pass or final artifact acceptance is claimed by this offline handoff.

## Follow-up: preserve and diagnose camera ownership gates

The Coordinator's later `smash-post-full-punch-pet-exclusion-20260906/pet-size-position-qc.json` records zero avatar and pair overlap and world pair separation above 1.55 studs at all three distances, but `cameraUnchanged=false`. That aggregate cannot identify the failed camera condition. The oracle does not compare CFrame identity; it requires Scriptable ownership, position delta below 0.001 studs, LookVector dot product above 0.999999, and Focus delta below 0.001 studs.

The diagnostic follow-up preserves all four predicates exactly. Before evaluating them it records current camera type, actual/requested camera and Focus positions, position/Focus deltas, the raw LookVector dot product, vector-length product and normalized angular delta. Each distance retains maximum position, Focus and angular deltas; only the first detailed failure is retained to avoid losing the cause to runner output truncation.

The actual flow payload is executed against independent one-stud camera translation, one-stud Focus movement, one-degree look rotation and owner-switch controls. Each fails and identifies its corresponding diagnostic field. Mutations that discard the Focus, angle or owner gate, or expand the first-failure record bound, are rejected. All original geometry and earlier flow checks remain: 3,165 executed assertions and 26 rejected mutations pass; all payloads compile.

The `a49221b` handoff was diagnostic-only. It retained the failed camera gate pending the native results below.

## Qualified Focus reference for the observed Studio environment

The actual `smash-pet-camera-native-components-20260906/pet-size-position-qc.json` result isolates Focus as the failed condition: all camera position/angular deltas are zero and ownership stays Scriptable. Focus deltas from the requested avatar target are about 13.9593, 7.9796 and 1.9864 studs at the three distances. The observed point is exactly twenty studs along the unchanged camera's LookVector.

The Coordinator's independent `smash-native-scriptable-focus-20260906.json` probe assigns the same Scriptable pose and seven-stud Focus to the current camera and a temporary non-current camera. Both immediately report seven. After rendering, only the current camera reports twenty. Reassigning Focus repeats the result, so a one-frame transition wait does not solve it. The probe restores the original camera and destroys its temporary instance.

All nine authored sources and the installed PlayerModule for the running Studio version were inspected. No fixed twenty-stud Focus writer was identified. The installed `CameraModule.lua` disables its controller for Scriptable at lines 345–350 and guards its Focus write with an active controller at lines 553–568. Its public module returns an empty table, so a missing controller in that public return is not runtime proof about the internal object. Attribution to a specific live owner or native subsystem remains unknown. This is documented as observed behavior of this Studio/MCP environment, not universal engine behavior. Roblox documents that Scriptable owners normally update Focus themselves and that Focus is separate from the camera pose: [Camera customization](https://create.roblox.com/docs/workspace/camera).

The Coordinator authorized a narrow fixture policy after these probes. Following the existing settle wait, Focus is eligible only when within the original 0.001 studs of either the requested target or the independently computed `desired.Position + desired.LookVector * 20`. The fixture records `RequestedFocus`, `ObservedStudio20StudPlane` or `UnexpectedFocus`, including the requested-to-observed delta and accepted point. It freezes the eligible reference for all twenty samples. Any arbitrary initial offset, later Focus drift of 0.001 studs or more, changed camera position, changed look direction or changed Scriptable owner still fails. Production code does not overwrite Focus.

The exact updated flow passes requested-Focus and observed-twenty-plane controls, rejects a nineteen-stud plane, a lateral initial offset, a later 0.002-stud Focus drift and camera movement, and retains the original physical/readability gates. Mutations accepting any initial Focus or refreshing the reference each sample are rejected. `node work/automation/scripts/pet-size-position-contract.mjs --focus-baseline a49221b` passes all 3,176 assertions and 28 mutation controls and proves the historical exact flow fails with the measured twenty-plane behavior. All flow/cleanup payloads compile.

Current status: offline fixture repair complete; **runtime acceptance remains pending Coordinator execution** of the committed flow against the unchanged production source.
