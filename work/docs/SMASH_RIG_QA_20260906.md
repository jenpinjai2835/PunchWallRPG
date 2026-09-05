# Actual R6/R15 first-five fist QA — 2026-09-06

The new `work/automation/flows/first-five-rig-parity.json` checks the first five regular fists on actual R6 and R15 player characters. It requires one isolated Studio player and leaves normal character loading enabled.

## Fixture and acceptance checks

1. Before Reset, require the world's `EphemeralStudio` mode, explicit false live-data opt-in, no `ServerStorage.PunchWallAllowLiveDataStoreAccess` opt-in, and a ready, non-writable ephemeral player profile. Then reset the isolated test profile and buy Starter Glove, Boxing Glove, Iron Knuckle, Thunder Fist and Titan Gauntlet through the server automation purchase path. Check their names in `OwnedFistsJSON`; this flow does not treat premium ownership as regular ownership.
2. Create a blank `HumanoidDescription`, call `Players:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R6)` and later the R15 equivalent, then destroy the temporary description. Assign the returned model to the real `Player.Character`. Only the exact captured previous character of this player is destroyed after ownership moves successfully. The fixture is identified by a GUID and owner UserId attributes.
3. Observe readiness for at most eight seconds, then require actual `Humanoid.RigType`, a living Humanoid, native R6/R15 arm/torso parts, an unanchored root and an enabled native shoulder. Motor6D uses exact Part0/Part1 endpoints; AnimationConstraint uses actual Attachment0/Attachment1 objects whose parents are the torso and upper arm. Both native joint types expose the Transform used by production punch animation. A rig metadata string cannot satisfy this check, and the fixture never forces a legacy rig conversion. Reports include `nativeJointClass`.
4. For all five fists on each rig, reuse the established geometry, hazard and wrist checks: actual primitive shapes, colors, dimensions, relative orientation, anatomy roles, hand-width scaling, every part's physical flags, exact enabled hand weld endpoints, visible avatar hand, one equipped outer model and the complete eight-corner hand-local envelope. The reference envelope uses matching primitive geometry; it does not equate conservative rotated primitive corners with engine-tight `GetBoundingBox` results.
5. Wait until the current punch cooldown expires plus 0.06 seconds, then invoke exactly one punch per observed fist. Observe the real shoulder Transform in PostSimulation. Require actual movement and measure wrist geometry while that motion is active, followed by recovery. After the Idle state, require the actual shoulder to return within 0.15 radians and 0.08 studs of its pre-punch Transform within two seconds. A held extended arm fails even if motion attributes report Idle. Every temporary observation connection is disconnected in the same execute call, including failed assertions.
6. After each rig, call `Player:LoadCharacterAsync()`. Require a distinct normal character, release of the prior fixture and client equipped model, one restored fist model with the saved Titan identity, and valid actual wrist geometry after the normal character settles. Observe actual living Humanoid/body/root readiness for up to eight seconds, without imposing the synthetic fixture's joint schema on the user's restored avatar. Record the normal avatar's actual rig separately; normal loading follows the place's configured avatar type.
7. Require both completed rig matrices and both respawn checks. Clear owned markers, assert a clean console and stop Play. Failure cleanup attempts normal loading only for this player's marked fixture, then stops Play even if loading fails.

Cross-execute state consists only of serializable attributes. No Instance, connection or function is stored in a shared VM table. Native joints belong to the avatar; the copied visual hazard audit still rejects joints, behavior objects and unauthorized constraints inside equipped visual models.

## Official API verification

Roblox documents explicit `HumanoidRigType` input and a default-description creation example for [Players:CreateHumanoidModelFromDescriptionAsync](https://create.roblox.com/docs/reference/engine/classes/Players#CreateHumanoidModelFromDescriptionAsync). Normal character restoration uses the documented yielding [Player:LoadCharacterAsync](https://create.roblox.com/docs/reference/engine/classes/Player#LoadCharacterAsync). These API references were checked on 2026-09-06. API/asset-service unavailability must fail the runtime check; there is no metadata-only fallback.

The official [AnimationConstraint reference](https://create.roblox.com/docs/reference/engine/classes/AnimationConstraint#Transform) documents its CFrame Transform and Constraint inheritance. The inherited [Constraint properties](https://create.roblox.com/docs/reference/engine/classes/Constraint) provide Enabled and Attachment0/Attachment1. The Coordinator observed that the actual normal R15 avatar uses these joints, and production `findRigMotor` already supports them; this is a test schema correction, not a gameplay joint conversion.

## Offline validation

- PASS: all 12 embedded Luau chunks compile with the verified official Luau 0.737 compiler.
- PASS: the exact new `verifyRig` function extracted from the flow executes 22 controls: two valid native rigs and 20 rejected invalid cases. Negative cases include correct-looking metadata with the wrong actual enum, a string enum spoof, dead or missing Humanoid, missing/anchored/non-part anatomy, and missing, disabled or wrong-endpoint native shoulder joints.
- PASS: all three mutations that weaken enum validation, anchoring validation or shoulder Enabled validation are detected by those controls.
- PASS: 18 additional native AnimationConstraint/restored-avatar controls, including wrong or missing attachment endpoints, non-Attachment objects, disabled or unrelated constraints, and an actual normal body with no synthetic Motor6D.
- PASS: nine ephemeral guard controls, ten actual shoulder recovery controls and four bounded readiness controls. These execute the exact helpers extracted from the flow with local mocks.
- PASS: six additional mutations that weaken attachment validation, live opt-in rejection or actual recovery angle/position checks are detected.
- PASS: `git diff --check`.

The final extracted harness/compiled chunks are in `C:/Users/Jennarong Pinjai/AppData/Local/Temp/smash-rig-qa-check-XO9oFP/`, with guard/recovery/readiness evidence in `smash-rig-followup-check-HBh2Xr/` under the same Temp directory. Temporary launchers are `smash-rig-offline-check.cjs`, `smash-rig-mutation-check.cjs`, `smash-rig-followup-check.cjs` and `smash-rig-native-check.cjs`. They only parse local JSON, write temporary Luau and execute the official CLI; they do not connect to Studio.

## Runtime handoff

The Coordinator's initial runtime run passed all five actual R6 motion cases, then exposed the overly strict Motor6D assumption during normal R15 restoration. This followup fixes that fixture assumption and the two peer review gaps above. A complete runtime rerun is pending the Coordinator, who owns the Studio session. Offline checks do not prove actual avatar creation, replication, animation, equipment restoration or a clean game console. No production source, existing flow, registry or release artifact was changed in this task.

Coordinator command, with the currently selected task Studio ID substituted:

```powershell
node work/automation/scripts/flow_runner.mjs --flow work/automation/flows/first-five-rig-parity.json --studio-instance-id <task-studio-id> --result-file work/docs/evidence/first-five-rig-parity-20260906.json
```

Expected saved reports are `matrixR6`, `matrixR15`, `restoreR6`, `restoreR15` and `rigParitySummary`. The summary must contain `actualR6`, `actualR15`, `firstFiveEach`, `normalCharacterRestored` and `serializedLifecycle`, all true. A failed or unavailable runtime check remains BLOCKED until corrected and rerun.
