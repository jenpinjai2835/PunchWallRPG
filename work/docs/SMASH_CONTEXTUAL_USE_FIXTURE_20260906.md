# Contextual Use fixture repair — 2026-09-06

Owner: Agent 2. Coordinator owns Studio and combined verification. Scope is the training/pet recovery flow and its contract; gameplay source remains unchanged at the accepted camera-settle implementation `099fe519`.

## Evidence and diagnosis

The initial full-suite `training-ui-pet-recovery` failure expected the Armory after placing an anchored root at the Armory position plus `(-6, 0, 0)`, waiting 0.25 seconds and releasing it. The nominal point `(-75, 4, -14)` does select Armory in both exact production selectors.

The Coordinator's retained runtime diagnostic, `work/docs/evidence/smash-use-position-diagnostic-event-ready-20260906.json` in the integration worktree, measured the client root at `(-66.5359, 4.3942, -8.69315)` and server root at `(-66.5383, 4.38957, -8.69041)`. Crimson was approximately 4.922 studs away; Armory was approximately 5.864 studs away. The actual production selection was correct for the displaced position. No target-selection source defect was established. Character-box overlaps and the deliberately disconnected test shoulder do not establish the physical cause of the drift.

A separate retained diagnostic stopped at the old 2.6-second training gate with Iron active, gain 40 and Power 1539 from the 1499 seed: one actual tick. The old `Power >= 1540` expectation assumed two ticks from elapsed wall time. The new gate waits at most six seconds for two actual session ticks and Power at least 1579, while preserving the exact station, active state and 40-point rate.

## Fixture behavior

- Keep the unsupported-rig fallback proof, then restore each exact original shoulder instance, connection reference and name. Register restoration before disconnecting the shoulder; the normal proof checks restoration and the failure cleanup attempts it before stopping play. The temporary BindableFunction is destroyed after restoration.
- Approach Armory from the open-plaza offset `(-6, 0, +6)`. Derive root height from the actual core body and foot corners and a real collidable floor. Check the proposed core against uncapped collision queries. Move the character as a whole, without anchoring it, then require 0.3 seconds of stable normal physics, core clearance, less than 0.6 studs of drift, speed below 0.5 studs/second and at least a two-stud advantage over other actionable Use targets.
- Independently wait for the actual client contextual control to show active `Use` for exactly `Hero Armory Merchant Interaction`, with stable unanchored position, before sending one production `InvokeContextualAction`. No target attribute is written and no direct tab-opening command substitutes for Use.
- Observe a fresh native server `Feedback` event for exactly `OpenMenu/Fists/Fists`, exactly one matching menu reply and the real visible Fists Shop snapshot. Disconnect the observer on success and on invocation, reply or snapshot failure. Existing training, mobile typography, pet identity, Robux palette and console checks remain.

Raycast and overlap parameters use the documented collision filters and `RespectCanCollide` properties: [RaycastParams](https://create.roblox.com/docs/reference/engine/datatypes/RaycastParams), [OverlapParams](https://create.roblox.com/docs/reference/engine/datatypes/OverlapParams). The core query removes 0.05 studs from each face to avoid treating mere contact as overlap; it does not use the detached arm/accessory box as the body's floor height.

## Offline validation

`node work/automation/scripts/training-ui-pet-recovery-contract.mjs` passes:

- All 23 existing source/catalog checks, including eleven expected pet templates.
- Eight assertions executing the current source-authored interaction positions and both production selectors, including the retained runtime displacement and the new discriminatory point.
- Seventeen assertions executing the actual Use payload, six for actual training readiness, sixteen for original-joint restoration and eighteen for actual placement: 65 executed assertions in total.
- Twelve compiled semantic weakening mutations rejected: original name/reference restoration, core collision, stable motion, competitor margin, actual tick count, two-tick Power, pre-request exact readiness, physics readiness, server menu identity, visible page and observer cleanup.
- All sixteen Luau payloads in the flow and cleanup compile with the verified Luau 0.737 toolchain.

The placement fixture uses an independent floor/pillar intersection oracle and actual R6/R15 core dimensions; it covers missing/noncollidable/sloped floor, obstacles, missing body, anchoring, drift, movement and closer competitors. It does not simulate Roblox physics or claim that this candidate has passed in Studio.

Runtime status: **PENDING Coordinator execution** of the committed flow against the synchronized source. This handoff establishes offline fixture correctness, not a runtime pass or final artifact acceptance.
