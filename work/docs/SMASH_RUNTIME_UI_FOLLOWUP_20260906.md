# Runtime UI flow follow-up — 2026-09-06

Scope: `premium-pet-gamepass-configuration.json` and `punch-character-motion.json`, based on `a6fc6ee`. No gameplay source changed. The Coordinator owns Studio reruns and integration.

## Evidence and source basis

- Initial full-suite Premium failure occurred in the client purchase UI step: all three live lookups and world prices were valid, but legacy menu buttons were absent. Current `PunchWallClient.client.lua:4449` routes `OpenTab("Pets")` to owned Inventory. Premium offers are under `FunctionalHeroShop`; compact cards are descendants of `ShopCatalogScroll` (`:11457`). The flow now opens the Fists Shop host and Premium page and resolves each exact pet card/action recursively.
- Initial motion suite passed the full-motion hand-movement check. Only reduced motion failed: `reduced=true`, `suppressed=true`, `active=false`, `recovered=false`, four samples and approximately 0.0014 hand displacement. Current source deliberately sets `StaticFeedback`, suppresses the authored pose, and returns to `Idle` after 0.12 seconds (`:6779–6793`). The old flow stopped as soon as `CharacterPunchMotionActive` was false, before that recovery interval. Rig discovery supports both Motor6D and AnimationConstraint (`:6725`).
- Stats snapshots decode server `SettingsJSON` into local settings (`:2617`). The reduced-motion fixture now sets the authoritative setting before invoking the actual client punch, so a combat reward snapshot cannot replace the test's local setting with the previous full-motion value.

## Assertions retained and added

Premium keeps both server steps unchanged: exact production Game Pass IDs and configured base prices, live metadata, availability, and world purchase mappings. The client still verifies live regional prices and world-board text. It additionally requires matching IDs on the real card and action, a bound active/selectable action, a visible unclipped numeric price equal to the live lookup, and the active Premium page. Scrollable cards are brought into view. No purchase prompt is opened.

The original full-motion step is unchanged, including root-relative hand movement greater than 0.75 studs, authored angle/offset ranges, Windup/Contact/Recovery phases, animation peak, neutral recovery, and R6/R15 Motor6D or AnimationConstraint acceptance.

Reduced motion now observes StaticFeedback followed by Idle within a bounded three-second wait, one actual punch, no authored angle/offset, no camera follow, and inactive/recovered flags. It continues to report actual hand displacement; default avatar idle movement is not an authored punch pose. Both observation connections are disconnected on success or failure. A following server check requires damage to the fresh real target and increased authoritative coins while motion remains disabled, then restores the original setting.

## Offline verification

- PASS: both JSON documents parse and all nine actual Luau payloads compile with official Luau 0.737.
- PASS: structural comparison against `a6fc6ee` confirms the two Premium server steps and full-motion client step are unchanged.
- PASS: 12 Luau controls extracted the actual Premium lookup helpers and row predicate. Controls cover nested lookup, absent/wrong cards, valid regional pricing, swapped card/action IDs, stale displayed price, hidden/clipped price, unbound/inactive action, and stale world-board price.
- PASS: eight Luau controls executed the complete reduced-motion client payload with a simulated phase clock and attribute events. They cover successful recovery, waiting through the 0.12-second interval, cleanup after success, missing Idle rejection, bounded timeout, cleanup after failure, unexpected authored angle rejection, and unexpected camera follow rejection.
- PASS: `git diff --check`.

Temporary control/compile files were removed after execution. These checks validate the payload logic; actual Studio UI geometry, Marketplace resolution, joint movement, and authoritative damage still require the Coordinator's runtime rerun. Runtime status at this handoff: **PENDING**, not a runtime pass.
