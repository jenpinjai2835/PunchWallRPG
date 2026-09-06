# Power-scaled penetration final observation

Agent 3, 2026-09-06. This task changes only `power-scaled-penetration.json`, its new offline contract, and this document. It does not change gameplay source or Studio. The previous profiler/visual-tool handoffs remain immutable. The Coordinator owns integration and the actual rerun after the frozen suite.

## Cause and evidence

The frozen full run's flow 68 failed only the high-power `maxSpeed >= 30` assertion: `21.75751304626465` studs/second. Other reported values passed: 120 fragments, all 120 server owned, InitialForwardSpeed `137.36000061035157`, 48-stud requested/travel distance, 44 hits/broken blocks, power scale 1, penetration limit 48, and force scale 3.4. Source: `work/docs/evidence/smash-full-integrated-final-20260906/power-scaled-penetration.json`.

The old sample ran after `PunchRadius` returned and then `task.wait(0.15)`. That is not a 0.15-second launch observation. In the actual server:

- `depthPunch.Punch` waits the 0.2-second windup, calls `hitDepthBlock`/`spawnDepthBlockFragments` for the swept candidates, and only then calls `depthPunch.Lunge`.
- `spawnDepthBlockFragments` applies the actual mass-scaled impulse, separately records InitialForwardSpeed, and leaves the chunks collidable. Their friction is 0.78 and elasticity is 0.12. Collision is disabled only after 2.25 seconds; removal is scheduled at 4.5 seconds.
- Lunge creates a tween using `LungeSeconds = 0.42` and yields on `tween.Completed:Wait()`. `PunchRadius` returns only after that completion and the automation snapshot.

The old read therefore occurs nominally at least **0.42 + 0.15 = 0.57 seconds after the fragment impulse**, plus scheduling and snapshot work. The source has no requirement that collidable chunks retain their initial speed that long. This establishes a sampling defect in the test's launch-speed interpretation. The recorded late snapshot alone does **not** identify which contacts slowed the actual chunks or prove that every launch was correct. No gameplay physics change is justified by that evidence alone; the revised actual observation must still pass.

## Revised flow

The high-power step installs its observer **before** invoking PunchRadius. It records first-observed and deferred-after-add actual `AssemblyLinearVelocity`, then actual velocity and displacement during `RunService.PostSimulation`. ChildAdded can run before the producer's SetNetworkOwner call; ownership is judged after initialization and at every physics sample, plus the final all-fragment check. First-observed velocity is reported honestly even when it precedes ApplyImpulse.

The revised test keeps every original high-power regex and all cadence, starter, penetration, force, fragment-cap, and ownership gates. All other step objects and cleanup are unchanged. Additional assertions require:

- Exactly 120 physical fragments observed; all 120 server owned at the end and no ownership failure during initialized/deferred/physics samples.
- No anchored fragment, at least two actual PostSimulation observations per fragment, and at least 240 actual fragment physics reads.
- Actual measured speed **at least 30**, including a PostSimulation peak **at least 30**. InitialForwardSpeed metadata cannot satisfy either physical-speed assertion.
- At least one fast fragment observed on two physics steps with displacement of at least **0.1 stud** from its first observed position. This small motion floor rejects a velocity-only/no-movement fixture; it is below the displacement expected from one 30-stud/second interval at ordinary Studio cadence.
- No observer errors, incomplete deadline, or sample-cap stop.

The observer is bounded by two seconds and 240 physics callbacks containing fragments. It retains only five early trace points, the latest point, peak time/name, counts and extrema. Each trace peak is cumulative to that point. It disconnects both signals and cancels its deadline after success or a failing/yielding PunchRadius call; deferred callbacks check stopped state. Deadline and sample-cap exhaustion fail the observation instead of claiming a complete pass. Existing flow cleanup still stops Play.

The response separates immediate/deferred/PostSimulation peaks, elapsed and first-fragment times, return-to-read duration, ownership counts, displacement, and initial-speed metadata. `PENETRATION_OBSERVATION` prints the bounded real result so the existing console capture can retain it on success; failed physical guards include the measured speeds, movement, counts, duration and completion flags in their error. `saveAs=penetrationObservation` also preserves the returned response in failure context when available.

## Offline verification

```powershell
node --check work/automation/scripts/power-scaled-penetration-contract.mjs
node work/automation/scripts/power-scaled-penetration-contract.mjs
git diff --check
```

PASS: **21 source/unchanged-gate checks, 23 Luau snippet/control compilations, 30 executed assertions, and 14 rejected compile-valid mutations**. The contract extracts and executes the actual production PowerProfile and fragment producer with the exact flow observer. Its deterministic contact-loss schedule shows a legitimate early physical launch while the legacy late read is below 30. This tests observation timing; the mocked contact loss is not a simulation or measurement of Roblox contacts.

Rejected mutations remove the real impulse while keeping metadata, reduce the actual impulse, leave client ownership, anchor fragments, start observation only after launch, report velocity without physical displacement, or remove each of the eight observation guards. Failure and timeout controls prove signal/deadline cleanup. The complete flow still compiles, and every original penetration/force regex is present.

**Actual Studio rerun: BLOCKED pending Coordinator execution.** No new live pass is claimed. The revised observer must demonstrate real launch speed, physics movement and ownership in the frozen source before this specific flow is accepted. No source edit is requested by this handoff.
