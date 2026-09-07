# Settings final peer review

Agent 3, 2026-09-06. Read-only review of the main client at source commit `2efa8b306c913ba2e304f65fcb1c38963736a8cd`, integrated by the Coordinator as `aefa18c`. The reviewed source is unchanged in the worker's later contract commit `3e64e732824e68c95565565b774d3cc205e81bdc`. This assignment changes only this review document; the Coordinator owns Studio, integration, and release verification.

## Outcome

No concrete P1 or P2 defect was found in the Settings control-lifetime change. The eight native controls retain their Instances during idle snapshots, option selection, authoritative Settings table replacement, and close/reopen. The Coordinator's complete native gesture flow now also passes, including the strengthened Settings lifetime checks. This review approves the change for the combined runtime gate; it does not mark the full regression or final artifact as passing.

## Source findings

The reviewed paths are `work/punch-wall-rpg/src/client/PunchWallClient.client.lua:4379` through the standalone-window functions, the actual button factory at line 3002, the sound helper at line 797, StatsChanged at line 2781, and the existing responsive layout at line 13235.

| Area | Evidence and conclusion |
| --- | --- |
| Native identity | `ControlsCurrent` validates seven options plus Done, their option/row/footer hierarchy, and the body parent. Valid refreshes update attributes and selection colors without `clearStandaloneBody`. No replacement callback is connected during reuse. |
| Current authoritative values | StatsChanged replaces the `clientSettings` upvalue before refreshing the panel. Retained callbacks read that current upvalue, rather than a Settings table captured at construction. Sound uses the existing production helper; motion retains its aura/honor refreshes. Each valid activation sends one `UpdateSettings` request. Authoritative refresh itself sends none. |
| Obsolete callbacks | A structural repair increments generation before destroying old controls. Both option and Done callbacks check generation, visibility, panel ownership, and the complete relevant parent chain. They reject obsolete, hidden, and detached controls. Close/reopen deliberately retains the valid generation and Instances. |
| Focus | Ordinary refreshes do not move focus. Deferred open focus checks visibility, panel ownership, generation, and current controls; it preserves an active, selectable descendant already selected in the body. A callback queued before close cannot select a hidden panel. A callback from the previous structural generation cannot select its destroyed button. |
| Selection and input chrome | All seven options refresh `SettingSelected` and their selected/unselected colors in place. Existing 44-pixel option heights, 48-pixel Done height, option Z-index one above its parent, and horizontal selection links remain intact. The existing compact row layout is unchanged. |
| Deferred work | Unchanged snapshots schedule no additional layout work from the Settings renderer. An actual scale change schedules one pass; repeated rapid changes therefore schedule one pass per change, not a single coalesced pass. Layout reads current global settings when it executes. Initial opening retains the existing open-window layout pass plus a build pass; reopening a valid unchanged panel adds the ordinary open-window pass and guarded focus task. No recurring task is added. |

The sound and motion callbacks still use the existing server-authoritative request path. This change is presentation and control lifetime; it neither changes server normalization nor proves persistence independently.

## Independently executed checks

Run from `F:/Roblox/PuchWall-settings-stability-20260906`:

```powershell
node work/automation/scripts/settings-panel-stability-contract.mjs
node work/automation/scripts/settings-panel-stability-contract.mjs --baseline 2fe4dea
```

- Current production contract: **PASS, 87 assertions** across idle continuity, five native callback dispatches, repair/close/reopen lifecycle, and authoritative replacement. These execute extracted production renderer, button factory, and sound helper with deterministic Roblox boundary mocks.
- All **11 compile-valid semantic mutations** fail at their intended assertions: replacement, stale selection, duplicate requests, hidden/detached/obsolete handlers, missing scale layout, reduced touch size, wrong Z-order, and broken selection navigation.
- Full client compiles with Luau 0.737 at **O0, O1, and O2**.
- Baseline `2fe4dea` reproduces both original defects: unchanged clock snapshots replace `SoundOn`, and selecting an option destroys the activated control.
- A separate scratch-only peer fixture executed the same extracted production code with **21 additional assertions**. It dispatches all seven options including 80% and 100%, checks exact payloads and unchanged Instances, rejects deferred focus after closing, checks three rapid scale changes schedule exactly three passes, verifies 100 unchanged Settings table replacements add no deferred work, repairs a destroyed Options container once, rejects its obsolete callback, and preserves Done focus on reopen. No repository test or source file was edited by this review.

The mocks do not reproduce Roblox hit testing, physical touch dimensions, rendered clipping, or server persistence. Existing runtime layout and authority gates remain required.

## Actual event evidence and remaining release gates

The Coordinator's recorded evidence was read directly:

- `work/docs/evidence/smash-settings-event-diagnostic-20260906.json`: original MotionCalm observer armed at `14990.5397848`; its button received Destroying at `14990.8501191` while motion remained true, before it could observe the gesture.
- `work/docs/evidence/smash-settings-event-diagnostic-after-20260906.json`: the observed MotionCalm received Down at `15821.7775335`, Up at `15822.1115721`, and Activated at `15822.1117441`, all with `Parent=Options`; the capture contains no Destroying event and its result reports `newMotion=CALM`.

The complete native flow subsequently passed in `work/docs/evidence/smash-settings-stable-targeted11-20260906` with all original 25 gesture gates retained. The strengthened run also passed in `work/docs/evidence/smash-settings-complete-targeted12-20260906`: it adds original-eight-control lifetime observation across an actual idle Playtime tick and five Settings selections. Both result files and manifests were read directly and report `ok=true` with no manifest errors; the latter records 65 completed checks and flow SHA256 `299555173298C4ED19DF065FE60569897FDFFC5E93AE4DEB93C5877613DAB158`.

At this review's handoff, the Coordinator has started the frozen 124-flow integrated run at `6211b00` in `work/docs/evidence/smash-full-integrated-final-20260906`. Its completion and rebuilt/reopened artifact validation remain **BLOCKED pending completed Coordinator execution and evidence**. No new source correction is requested by this review.
