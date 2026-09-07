# Stable native Settings controls

Agent 2, 2026-09-06. Branch `codex/fix/smash-settings-stability-20260906`, base `2fe4dea`; source-only handoff `2efa8b306c913ba2e304f65fcb1c38963736a8cd`. The Coordinator owns integration and Studio verification. Agent 1 owns the native full-UI gesture flow and its independent lifetime observers. Only the main client, this document, and `settings-panel-stability-contract.mjs` were changed in this assignment.

The actual diagnostic `work/docs/evidence/smash-settings-event-diagnostic-20260906.json` recorded an observer on `MotionCalm`, followed by destruction of that button before mouse-down while the motion setting was still true. An unrelated StatsChanged snapshot had called the Settings renderer, which cleared and rebuilt the entire body. The eventual gesture hit the replacement button, so the setting changed while the original event observer had already disappeared. A second defect cleared the body synchronously inside each option's Activated callback, destroying the active button before later observers ran.

The renderer now retains `SoundOn`, `SoundOff`, `MotionOn`, `MotionCalm`, `Scale80`, `Scale100`, `Scale120`, and `Footer.Done`. Clock snapshots, authoritative Settings table replacement, setting selections, and close/reopen update the existing controls. Selected colors, `SettingSelected`, and the panel's sound/motion/scale attributes change in place. Only an invalid button, options container, row, footer, or body hierarchy triggers a structural rebuild. Generation and hierarchy checks prevent obsolete, hidden, or detached callbacks from changing settings or closing a replacement panel.

Every valid option selection retains its original single authoritative `UpdateSettings` request, including the sound helper and motion side effects. Existing keyboard focus and selection links are preserved. Initial/open focus is deferred with visibility, parent, generation, and current-control checks. An unchanged clock snapshot schedules no responsive-layout work; a changed UI scale schedules one layout pass. Existing names, 44-pixel option heights, 48-pixel Done height, Z-order, and responsive row layout remain available to the ordinary native UI.

`SettingsControlsVersion=StableNativeControlsV1`, `SettingsBuildCount`, `SettingsRefreshCount`, and `SettingsReuseCount` expose bounded counters. Runtime identity proof does not depend on these counters: Agent 1's flow watches the original eight Instances through Destroying and AncestryChanged, retains the original 25 Activated/Parent gates, observes actual increasing Playtime before the first Settings gesture, and checks continuity across the five selections.

Local validation:

| Check | Result |
| --- | --- |
| `node work/automation/scripts/settings-panel-stability-contract.mjs` | PASS: 87 assertions executing extracted production renderer, factories, and sound helper |
| `node work/automation/scripts/settings-panel-stability-contract.mjs --baseline 2fe4dea` | PASS: independently reproduces clock-snapshot replacement and selection-time destruction in the original producer |
| Semantic mutations | PASS: all 11 remain valid Luau and fail at their intended behavioral assertions |
| Luau 0.737 full-client compile | PASS at `-O0`, `-O1`, and `-O2` |
| `git diff --check` | PASS |
| Coordinator's actual post-fix Motion diagnostic | PASS: the same original Motion button receives Armed, Down, Up, and Activated with `Parent=Options`, no Destroying event, and final motion=false |

The deterministic controls cover 12 unchanged snapshots with Settings table replacement; all five native callback dispatches with exactly five payloads; all eight original control identities; callback observer lifetimes; selected colors and attributes; current focus; scale-layout scheduling; motion and sound effects; invalid-control repair; obsolete, hidden, and detached callbacks; Done behavior; close/reopen; and an authoritative value update that later callbacks must read from the current Settings table. Mutations disable reuse or selection refresh, duplicate requests, accept hidden/detached/obsolete callbacks, omit scale layout, shrink touch targets, lower button Z-order, or break keyboard navigation. These are changes to extracted production code, not replacement implementations of the renderer.

The Coordinator integrated the source as `aefa18c` and reported the post-fix native result in `work/docs/evidence/smash-settings-event-diagnostic-after-20260906.json`. The before/after diagnostic isolates the original premature destruction, but does not replace the entire gesture suite.

The mock environment provides deterministic Instance hierarchy, event, selection, remote, and deferred-task behavior. It does not simulate Roblox hit testing, rendered mobile geometry, or the server persistence path. The complete strict native gesture run and combined runtime are **BLOCKED pending Coordinator Studio verification**. This handoff does not claim those broader runtime checks passed. The source commit is immutable during the Coordinator's runtime run.
