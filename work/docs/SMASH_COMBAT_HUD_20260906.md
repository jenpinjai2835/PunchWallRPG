# Combat target and Titan HUD — 2026-09-06

HQ owner: agent-1. Initial source branch `codex/fix/smash-combat-hud-20260906`, baseline `0e6c0b5`. Authorized paths: main client source, `combat-target-boss-hud.json`, `combat-target-boss-hud-contract.mjs`, and this note. Studio, server authority, registry, and unrelated files remain Coordinator-owned.

## Checklist and dependency

- [x] Implement the wall/boss presentation owner, shared scan integration, safe placement, and cleanup.
- [x] Compile the client and runtime chunks; execute production helper checks and mutation controls.
- [x] Hand off source ownership before the camera changes; complete tests/documentation independently.
- [ ] Coordinator combined integration and actual Studio run: **BLOCKED / pending**. No runtime pass is claimed here.

Source-only commit `4a30997daa874bea348e571e2779c94ba9cfed72` was handed off and integrated as `ef9b5f8`. The focused contract then caught two missed scan wiring replacements caused by original CRLF boundaries. Agent-2, the subsequent main-client owner, applied those six required publication/cleanup lines. The contract keeps those call sites mandatory: the initial source commit alone correctly fails the wiring check. This worker made no further source writes after the ownership handoff.

The complete offline contract passed against Agent-2's corrected source at:

`F:/Roblox/PuchWall-camera-los-20260906/work/punch-wall-rpg/src/client/PunchWallClient.client.lua`

The exact tested source, normalized to LF, has SHA256:

`18396de92d7db099fb043e2ba0b48c673194d8293ab702a5275ca795a44121b2`

The Coordinator should record the final integrated source commit and runtime evidence after integrating Agent-2's changes. The contract supports `--source` for read-only verification during serialized source ownership; it never modifies that source.

## Behavior

`TargetWallHUD` now displays the current material's `TierName`/configured display name, actual replicated HP and HP fill, and an approximate noncritical hit count. The count uses the server-sent effective power and the replicated damage-boost expiry. Level-gated targets instead show their required level; zero power shows training guidance. Canonical names remain available separately through `CombatHUDCanonicalTarget`.

`BossHUD` displays actual Titan phase, weak-point multiplier, HP fill, HP totals, and the remaining time derived from replicated `NextAttackAt` and server time. The current regular wall takes precedence over a nearby boss. A distant damaged boss cannot keep the panel open globally. Broken, unavailable, dead-player, or out-of-range targets release their UI ownership.

The existing target scan supplies both displays every 0.15 seconds. The formerly separate boss heartbeat was removed. One local `Highlight` outlines the actual wall; it clears for menus, invalid targets, and boss ownership. Presentation writes are cached by displayed values, so unchanged wall information does not rewrite its labels or fill. No per-block listeners, additional world scans, render-step handler, damage requests, or server rewards were added.

Shop, Inventory, Tasks, Settings, Spin and continuous training suppress combat information. Existing object names remain stable: `TargetWallHUD.TargetTitle`, `TargetDetail`, `HealthTrack.HealthFill`, and `BossHUD.BossTitle`, `BossSubtitle`, `BossHealthTrack.BossHealthFill`.

Responsive placement observes actual rendered control rectangles after layout settles. It prefers the central upper lane and tries other clear positions or smaller readable widths when necessary. Both panels share the same rectangle, preserve at least 14 px primary / 12 px secondary text constraints, and remain noninteractive. If there is no clear lane, placement fails closed instead of covering a control; the actual runtime matrix must still confirm supported device layouts.

## Executable offline evidence

Command:

```powershell
node work/automation/scripts/combat-target-boss-hud-contract.mjs --source F:/Roblox/PuchWall-camera-los-20260906/work/punch-wall-rpg/src/client/PunchWallClient.client.lua
```

Results:

- **PASS — 382 production behavioral assertions.** The script extracts and executes the actual `Resolve`, `FindLayout`, `Apply`, and numeric-formatting code using official Luau0.737. It checks real HP fractions, canonical/display identities, boosted and expired damage estimates, level gates, zero power, invalid/broken/out-of-range targets, boss phase/deadlines, modal readiness, exact GUI/outline application, same-name Instance replacement, and unchanged-presentation caching.
- Placement checks cover eleven supplied viewport sizes and UI scales0.8/1/1.2 against actual-shaped control rectangles, including landscape phones, portrait-sized viewports, desktop, and tablet. They assert bounds, text floors and non-overlap; fully blocked or unready viewports must fail closed. These are executable placement tests, not a claim of actual Studio portrait verification.
- **PASS — eight semantic weakening mutations rejected:** modal suppression, broken wall rejection, boss range, boost expiry equality, real HP fill, outline release, render caching, and control clearance.
- **PASS — complete client plus 17 runtime-flow chunks compile.** JSON and regex parsing are included; no Studio runner is invoked by the offline script.
- **PASS — mandatory source wiring:** the shared target publication, missing-player/world clearing, existing0.15-second cadence, responsive scheduler and modal signal remain present; unconditional target hiding and the old separate boss loop remain absent.
- **PASS — `git diff --check`.**

## Runtime flow, pending Coordinator

`combat-target-boss-hud.json` creates one uniquely named owned simulator device and records the prior device using serializable workspace attributes. Normal completion and idempotent cleanup restore the previous simulation and remove only the owned device.

The flow requires a single ready ephemeral Studio profile with no live DataStore opt-in before resetting the fixture. It temporarily anchors the actual character root for deterministic target observation; no mock HUD values or fabricated success attributes are used. Stop-play cleanup bounds that fixture even when an assertion fails.

The actual scenarios are:

1. Server gameplay damages the real first depth block from8 to6HP with Power2 and explicitly zero fixture mastery. The client must display the configured title, exact fill, approximate3hits and the same actual outline target; unchanged information must not rewrite for0.65seconds.
2. Shop, Inventory, Tasks and Settings hide both panels and clear the outline; closing restores the actual nearby target.
3. Actual device transitions exercise874×402 at80% and120%,667×375 at100%, and900×600 desktop. Tests inspect rendered text and panel bounds and reject overlap with any visible active reference-HUD button.
4. Actual server damage breaks the displayed block. Its name cannot remain the HUD or outline owner.
5. Qualified Depth75/Lv99 gameplay enters Titan phase2. Actual phase, weak-point copy, HP fraction and deadline-derived countdown must display, update at most once per displayed second, avoid controls, and hide/restore around Shop.
6. Leaving the encounter must hide the damaged boss and clear the outline.

The Titan fixture deliberately observes from the clear negative-Z side of the boss. `ResetWorld` restores all75 solid layers throughZ=-333, while Titan isZ=-340; the old positive-Z fixture at approximately-321 stood inside the final live blocks and correctly triggered regular-wall precedence. The new observation point is within the actual boss range and outside the24-stud wall-focus range. It does not weaken target selection to force a boss result.

Player-facing wall titles follow current configured names such as **Forest Stone**; legacy checks for literal **BRICK WALL**/**IRON WALL** must use the configured display name while retaining the actual HP/visibility requirement. The current GUI uses `DeviceSafeInsets`; the new flow measures the rendered reference-HUD rectangle directly.

Required outstanding evidence: Coordinator Studio execution, captures on actual supported mobile/desktop layouts, and combined regressions after the camera/source handoff. The source and offline assertions do not establish visual quality or runtime success by themselves.
