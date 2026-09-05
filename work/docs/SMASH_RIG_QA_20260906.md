# Actual R6/R15 first-five fist QA — 2026-09-06

The new `work/automation/flows/first-five-rig-parity.json` checks the first five regular fists on actual R6 and R15 player characters. It requires one isolated Studio player and leaves normal character loading enabled.

## Fixture and acceptance checks

1. Reset the isolated test profile and buy Starter Glove, Boxing Glove, Iron Knuckle, Thunder Fist and Titan Gauntlet through the server automation purchase path. Check their names in `OwnedFistsJSON`; this flow does not treat premium ownership as regular ownership.
2. Create a blank `HumanoidDescription`, call `Players:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R6)` and later the R15 equivalent, then destroy the temporary description. Assign the returned model to the real `Player.Character`. Only the exact captured previous character of this player is destroyed after ownership moves successfully. The fixture is identified by a GUID and owner UserId attributes.
3. Assert actual `Humanoid.RigType`, a living Humanoid, native R6/R15 arm/torso parts, an unanchored root and an enabled shoulder Motor6D with actual torso/upper-arm endpoints. A rig metadata string cannot satisfy this check.
4. For all five fists on each rig, reuse the established geometry, hazard and wrist checks: actual primitive shapes, colors, dimensions, relative orientation, anatomy roles, hand-width scaling, every part's physical flags, exact enabled hand weld endpoints, visible avatar hand, one equipped outer model and the complete eight-corner hand-local envelope. The reference envelope uses matching primitive geometry; it does not equate conservative rotated primitive corners with engine-tight `GetBoundingBox` results.
5. Wait until the current punch cooldown expires plus 0.06 seconds, then invoke exactly one punch per observed fist. Observe the real shoulder Transform in PostSimulation. Require actual movement and measure wrist geometry while that motion is active, followed by recovery. Every temporary observation connection is disconnected in the same execute call, including failed assertions.
6. After each rig, call `Player:LoadCharacterAsync()`. Require a distinct normal character, release of the prior fixture and client equipped model, one restored fist model with the saved Titan identity, and valid actual wrist geometry after the normal character settles. Record the normal avatar's actual rig separately; normal loading follows the place's configured avatar type.
7. Require both completed rig matrices and both respawn checks. Clear owned markers, assert a clean console and stop Play. Failure cleanup attempts normal loading only for this player's marked fixture, then stops Play even if loading fails.

Cross-execute state consists only of serializable attributes. No Instance, connection or function is stored in a shared VM table. Native joints belong to the avatar; the copied visual hazard audit still rejects joints, behavior objects and unauthorized constraints inside equipped visual models.

## Official API verification

Roblox documents explicit `HumanoidRigType` input and a default-description creation example for [Players:CreateHumanoidModelFromDescriptionAsync](https://create.roblox.com/docs/reference/engine/classes/Players#CreateHumanoidModelFromDescriptionAsync). Normal character restoration uses the documented yielding [Player:LoadCharacterAsync](https://create.roblox.com/docs/reference/engine/classes/Player#LoadCharacterAsync). These API references were checked on 2026-09-06. API/asset-service unavailability must fail the runtime check; there is no metadata-only fallback.

## Offline validation

- PASS: all 12 embedded Luau chunks compile with the verified official Luau 0.737 compiler.
- PASS: the exact new `verifyRig` function extracted from the flow executes 22 controls: two valid native rigs and 20 rejected invalid cases. Negative cases include correct-looking metadata with the wrong actual enum, a string enum spoof, dead or missing Humanoid, missing/anchored/non-part anatomy, and missing, disabled or wrong-endpoint native shoulder joints.
- PASS: all three mutations that weaken enum validation, anchoring validation or shoulder Enabled validation are detected by those controls.
- PASS: `git diff --check`.

The extracted harness and compiled chunks for the final run are in `C:/Users/Jennarong Pinjai/AppData/Local/Temp/smash-rig-qa-check-cZASC7/`; the temporary launchers are `smash-rig-offline-check.cjs` and `smash-rig-mutation-check.cjs` in the same user's Temp directory. The launchers only parse local JSON, write temporary Luau and execute the official CLI; they do not connect to Studio.

## Runtime handoff

Live Studio execution is pending the Coordinator, who owns the Studio session. Offline checks do not prove actual avatar creation, replication, animation, equipment restoration or a clean game console. No production source, existing flow, registry or release artifact was changed in this task.

Coordinator command, with the currently selected task Studio ID substituted:

```powershell
node work/automation/scripts/flow_runner.mjs --flow work/automation/flows/first-five-rig-parity.json --studio-instance-id <task-studio-id> --result-file work/docs/evidence/first-five-rig-parity-20260906.json
```

Expected saved reports are `matrixR6`, `matrixR15`, `restoreR6`, `restoreR15` and `rigParitySummary`. The summary must contain `actualR6`, `actualR15`, `firstFiveEach`, `normalCharacterRestored` and `serializedLifecycle`, all true. A failed or unavailable runtime check remains BLOCKED until corrected and rerun.
