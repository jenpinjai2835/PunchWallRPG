# Final reward and pet feedback consumers — 2026-09-06

Status: offline checks PASS; integrated Studio regression remains PENDING with the Coordinator. This worker did not modify game source, use Studio, or update Agent HQ. Assigned base: `5fb723781b68414af8e5cfd01c16b77be2b187c8`; branch: `codex/test/smash-feedback-final-20260906`.

## Source-bound causes and changes

`PunchWallClient.client.lua` sets `CenterActionFeedbackEnabled=false`. Its actual `showFeedback` dispatches world damage and wall-break coin effects before the center-feedback branch. Wall rewards and level-ups call the debounced reward sound. Even when center feedback is enabled, the later explicit return suppresses center labels for wall-break rewards and level-ups. Milestones use one toast when center feedback is disabled. Therefore the old iteration03 assertion requiring at least two RewardPops and zero toasts contradicted both current branches. The Coordinator's targeted4 run observed zero pops and one toast; it was not proof of a missing reward.

Iteration03 now subscribes to the real Feedback remote before the existing break action. It observes actual newly created `Local Coin Rewards` parts and native SoundService sounds; audio identity includes volume and playback speed because Reward and CoinCollect share an asset ID. The check requires seven collision-free coin parts, one coin sound, and at least one reward sound, with the upper count bounded by actual eligible reward/level/milestone events. These observations prove dispatch and object creation, not that a device audibly played downloaded audio.

The existing guarded solo break fixture independently calculates current `GameConfig.ContributionReward` coin/score amounts, the active coin boost, and XP/level rollover using `XPForLevel`. It asserts exact server deltas and publishes only serialized evidence. The client requires exactly one matching wall Reward event, the derived LevelUp event count, replicated economy/XP, and actual visible, fitting Coins/Depth text. Zero center pops is checked only alongside those real consumers. Legitimate milestone toasts remain allowed; duplicate wall/level notices and overlapping notices fail. The added observation has a one-second maximum wait so the existing subsequent debris scatter/lifetime gates retain their timing purpose.

The root's previous iteration04 Pet observer already passed targeted4's three pickup steps. Its identity check could nevertheless reuse an earlier identical-species toast: `matching >= 1` did not require a new presentation. The revised observer captures each actual Pet event against the next `Toasts.PresentationSequence` and the matching label's actual `LayoutOrder`. It requires one fresh matching label, one bounded channel, safe bounds, nonoverlap, and no RewardPops sequence change. Duplicate pet species are deliberately covered by offline tests. Observers hold Instances only inside their original callback closure; cross-call evidence is JSON plus a run token. Token invalidation disconnects both event and token listeners; bounded timeouts also stop observers. They never invoke `showFeedback`, emit fake feedback, or overwrite production callbacks.

## Preserved failing target gate

The same targeted4 run reached all Pet feedback checks and later failed at the Iron HUD assertion, before the boss fixture. The Coordinator's `smash-settings-iron-diagnostic-20260906.json` confirmed that the eight-stud, top-face Iron target was absent from a 400-result depth overlap query, while the HUD selected a farther block. The character was alive, anchored, looking down; training and menus were inactive, and layout was ready. This is a target-search source defect, not evidence to weaken the fixture. Agent 2 owns that separate fix. The Iron pose, clear-ray check, exact target identity, HP/hit estimate, safe bounds, and all boss checks are unchanged here.

The offline contract compares 50 unrelated steps and all cleanup entries against the assigned base byte-for-byte at the decoded JSON level. This preserves paid-hatch rejection, guarded real egg pickup authority, independent duplicate-slot locks/deletion, actual training, wall/boss UI, server-owned debris, rebuild/reset, device safe area, and console gates.

## Validation

Commands run from this worktree:

```powershell
node work/automation/scripts/final-feedback-consumer-contract.mjs
node work/automation/scripts/combat-target-boss-hud-contract.mjs
git diff --check
```

Results:

- Full current client and 34 Luau flow snippets compile.
- 36 assertions execute the actual feedback routing, copy, bounded queue, toast constructor, and audio functions with controlled engine boundaries. Both center policies and motion settings are covered.
- Eight compile-valid producer mutations fail at their intended behavioral assertions: lost coin dispatch, duplicate wall text, lost pet route, unbounded queue, reused sequence, ignored mute preference, removed sound debounce, and duplicate milestone route.
- Nine controls execute the exact Pet capture helper against actual mock instance properties, including earlier identical text, hidden/transparent UI, overlap, clipping, duplicate labels, and duplicate channels.
- Two valid serialized fixtures pass the exact runtime verification helpers; 27 faulty variants fail. Four compile-valid verifier weakenings expose the intended faults.
- Existing combat HUD contract: 382 production behavioral assertions, eight semantic mutations, full client plus its 17 flow chunks compile, current scan/event wiring checks PASS.
- `git diff --check` PASS. Source SHA-256 after LF normalization: `8089410b1ad3207df8156b3c451025765e098868ef7bff68c97a1958e0a7c7d2`.

Studio rendering, replication, actual sound playback, the revised observer lifetime in Studio, and the separate Iron selection fix still require the Coordinator's integrated runs. This handoff is eligible for integration; it does not mark either full flow or the overall game READY.
