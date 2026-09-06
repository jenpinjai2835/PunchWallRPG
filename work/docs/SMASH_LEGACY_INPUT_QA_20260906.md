# Legacy input and feedback flow repair — 2026-09-06

Agent 3 scope: three named flows, their two existing contracts, and this document. Worktree `F:/Roblox/PuchWall-legacy-input-20260906`, branch `codex/test/smash-legacy-input-20260906`, base `5c5367f`. No game source, Studio, HQ, registry, or other worker files were changed.

## Findings grounded in the failed suite and current source

| Failure / outdated expectation | Evidence and correction |
| --- | --- |
| `missing fresh Equip2` | The public `OpenTab('Pets')` route now sets `activeTab = 'Inventory'` and selects the modern Pets category. Legacy rows cannot appear through that route. The flow uses the already-existing, Studio-only `AutomationTab` hook to exercise the actual retained legacy callbacks. It proves the rendered tab is Pets, the host is open, and modern Inventory is hidden before locating any row. This is explicitly legacy callback coverage, not a claim about public navigation. |
| Rare-filtered `ItemCard_fist_Boxing_Glove` missing | Current GameConfig declares Boxing Common and Iron Knuckle Rare. The fixture now owns Starter, Boxing, and Iron, clicks the real Rare option, requires both Common keys to disappear, then selects and equips Iron. Wrong-item request/payload, ownership, and equipped-state assertions remain exact. |
| Later Settings controls still targeted `GameMenu.Content` | Current Settings uses `SettingsWindow.Body`, `MOTIONSetting.Options.MotionCalm`, `SOUNDSetting.Options.SoundOff`, and `UI SIZESetting.Options.Scale80/100/120`. The six existing Settings gestures now target these controls and `SettingsWindow.Close`; no extra clicks were added. Opening/closing asserts the standalone window state. |
| Feedback result has `delta=0` and the preceding `Fail/Rebirth` identity | The saved suite file lists the Rebirth assertion as passed and fails after the premium request. That request used `BuyPremiumPet`, a commerce-prompt route, while expecting a deterministic grant. This was an invalid fixture. The corrected step uses guarded server `GrantPremiumPet`, verifies ownership/inventory, and observes the real client Feedback event. The old evidence does not establish a production feedback-counter defect. |

Source locations inspected: `PunchWallClient.client.lua` public routing and Studio tab hook, standalone Settings construction and `showFeedback`; `GameConfig.lua` fist rarities; `PunchWallBootstrap.server.lua` premium prompt/grant and `grantPet` feedback paths. The root suite evidence was read from `work/docs/evidence/smash-full-suite-20260906/`; it was not modified.

## Assertions preserved and strengthened

- Legacy pet flow retains six balanced real gestures, fresh current-button hit checks, exact callback occurrence, raw remote request and authority result checks, wrong-order duplicate rejection, locked Delete, first-click no mutation, timeout, and exactly two gestures for confirmed deletion. No handler is called directly by the test.
- Full-game flow retains 25 balanced real gestures and all nine exact server mutation attestations. Daily/Quest/Playtime amounts, no-retry behavior, stale-button safeguards, callback observations, and final Settings authority remain.
- Every fixture Reset/SetStats and the premium grant first requires a single ready, non-writable `EphemeralStudio` profile, world ephemeral indicators, and no live-data opt-in. Premium commerce configuration and purchase APIs are untouched.
- Rebirth captures the numeric baseline, actual Feedback event, count increment, displayed identity, and visible instance/channel in one client call. Premium arms an observer before the server grant and captures the actual presentation while the event is fresh, avoiding a later tool call mistaking an expired toast for a rendering failure. Only serialized JSON/string markers cross execution calls; the bounded observer disconnects after 30 seconds and invalidates its token when verified.
- Both feedback paths require exactly one event, exactly one count increment, the exact expected type/target, an initially empty presentation, and exactly one visible instance in one channel. Missing, duplicate, stale, wrong-item, hidden, or unobserved feedback fails with before/after/event/presentation diagnostics. No count or application feedback attribute is changed to manufacture a pass.

## Offline verification

- PASS: 60 embedded Luau snippets compile using Luau 0.737.
- PASS: `node work/automation/scripts/fist-pet-safety-contract.mjs` — 49/49 checks. Its exact Lua feedback verifier accepts two valid channel fixtures and rejects 14 invalid inputs. Three weakened verifier versions are rejected. Two legacy route mutations and the prior five source safety mutations are also rejected.
- PASS: `node work/automation/scripts/full-game-real-ui-controls-contract.mjs` — 29/29 checks; 25 gestures and nine request attestations retained. Six mutations covering rarity, excluded Common items, wrong equipped identity, obsolete Settings host, and wrong scale option are rejected.
- PASS: JSON parsing and `git diff --check`.

The feedback helper contract uses `LUAU_COMMAND` when set, with the existing machine Luau location as its default. Missing Luau fails the check; it does not silently skip execution. The helper tests are data-contract evidence, not simulated Roblox rendering or network evidence.

**BLOCKED: required Studio reruns remain pending Coordinator integration.** Run `fist-pet-legacy-slot-safety`, `full-game-real-ui-controls`, and `feedback-holder-presentation` against the integrated source and record their outputs. No runtime success is claimed for these revised flows. In particular, actual pointer delivery, standalone control size after scale changes, and real grant feedback still require the engine runs.
