# Iteration 05 - Fresh QC And Backlog

Iteration 05 starts only after Iteration 04 passed 21/21 flows, was saved,
snapshotted, closed, reopened from the exact final file, and passed its
iteration plus smoke gates.

Source under review:

- `F:\Roblox\PuchWall\outputs\PunchWallRPGPlayable_v1_final.rbxlx`
- Baseline SHA-256:
  `FADE193B31772D36D8559A89A13A5E27B3696BDACBE6C49FF51C721477BC6AF1`

## Fresh Player Audit

The reopened final was played in the persisted iPhone 17 Pro landscape
simulator (`750x361`). World and UI evidence is stored in:

- `work/docs/qc-screenshots/iteration-05-baseline`
- `work/docs/qc-screenshots/iteration-05-baseline-ui`

The audit covered spawn, first objective, training, close and long wall-lane
reads, Armory/DNA district, Titan approach, and all four menu tabs.

## Findings

| ID | Priority | Fresh player finding | Required fix | Status |
| --- | --- | --- | --- | --- |
| I05-001 | P1 | The persistent six-line StatsPanel occupies roughly the left quarter of the 750px mobile viewport and repeats equipment/pet details already available in Menu. | Use a compact mobile status card with only Power, Coins, and Wall Level while retaining the full desktop panel and data labels. | Closed |
| I05-002 | P1 | Regular smashable buildings are only six studs deep. Side and long-lane captures expose them as decorated facade slabs against empty black road space. | Add break-linked rear building mass and roof volume to every regular wall without changing its combat hitbox or balance. | Closed |
| I05-003 | P1 | Titan is 38x34 but only eight studs deep. Side approach reads as a thin red panel and close approach becomes a flat red screen instead of a boss headquarters. | Add a deep break-linked Titan tower core, side structural ribs, and a readable front containment header. | Closed |
| I05-004 | P1 | Armory stand labels overlap visually at mobile distance and copy spends space on `Cost`; the four products do not scan as a clean tier sequence. | Spread stands evenly within the Armory and shorten both-face labels to item name plus `$price | POWER xN`. | Closed |
| I05-005 | P2 | The onboarding card describes the current action and distance but gives no visual indication that the player is advancing through a finite tutorial sequence. | Add a thin five-step objective progress track that updates with TutorialStep and remains clear of combat HUDs. | Closed |
| I05-006 | P2 | Outside punch/break events, the city and Titan district are visually static; emergency beacons and energy elements do not communicate an active containment emergency. | Add restrained client-local ambient pulses to tagged beacons/energy elements, honor Motion Feedback off, and avoid gameplay authority. | Closed |
| I05-007 | P1 | Titan has no dedicated current-pass graphic identity; the existing generated billboards are distant and do not help the boss facade read at encounter range. | Generate original Kaiju City Titan containment artwork and integrate it as a two-sided/header world graphic plus a compact boss HUD image cue. | Closed |
| I05-008 | P1 | Automated screenshot QC captures three menu tabs but misses Fists when the requested AutomationTab already equals the current value. | Force an explicit attribute transition before every menu capture and require ten saved screenshots plus a clean console. | Closed |
| I05-009 | P0 | Compact status, building depth, Titan identity, objective progress, and reduced-motion ambient behavior need one deterministic regression. | Record an Iteration 05 flow with structural, client-layout, motion-on, motion-off, and console assertions. | Closed |
| I05-010 | P0 | Final-round world and client changes can affect all existing gameplay and responsive contracts. | Pass the complete current matrix, save and snapshot Iteration 05, close/reopen the exact final file, then rerun Iteration 05 plus smoke gates. | Closed |
| I05-011 | P1 | Post-fix spawn capture still showed Armory text filling the foreground because each label occupies the full five-stud invisible interaction volume. | Move copy onto short fixed metal nameplates in front of each plinth while preserving the larger invisible interaction target. | Closed |
| I05-012 | P2 | The standard Titan QC camera sees the tower side and cannot prove that the new containment artwork reads from the actual encounter approach. | Add a dedicated front-approach Titan capture to every automated screenshot pass. | Closed |

## External Release Findings

- Published DataStore/Analytics verification remains external.
- Creator Dashboard icon/thumbnail publication remains external.
- Physical low-end Android/iOS profiler capture remains external.

## Fix Status

All 12 fresh and post-fix findings are closed. Gameplay balance and combat
hitboxes remain unchanged.

## AI Graphic Deliverables

- Master: `work/assets/generated/iteration-05/kaiju-titan-containment-master.png`
- Integrated banner: `work/assets/generated/iteration-05/kaiju-titan-containment-banner.png`
- Roblox image: `rbxassetid://93552182756522`
- Use: two-sided Titan containment header and compact BossHUD image cue.

## Re-QC Evidence

- Final screenshot set: `work/docs/qc-screenshots/iteration-05-final-qc`
  contains 11 world/UI captures plus clean console output.
- Dedicated flow: `iteration05-final-depth-motion` passed all 12 checks.
- Full matrix: 22/22 passed in 345.1 seconds; raw result is
  `work/automation/results/iteration05-full-matrix.json`.
- Final file saved, Studio closed, and the exact final file reopened.
- Edit-mode serialized-source audit confirmed Titan asset, deep tower,
  nameplates, compact status, and ambient-motion source.
- Post-reopen `iteration05-final-depth-motion` and `punchwall-smoke` passed.
- Snapshot: `outputs/iterations/PunchWallRPG_iteration05.rbxl`
- Post-acceptance punch-motion patch supports modern Roblox
  `AnimationConstraint`, legacy R15 `Motor6D`, and R6 shoulder rigs. The pose
  drives the striking arm, guard arm, waist, and neck after Animator updates.
- New flow `punch-character-motion` verifies measurable joint rotation and
  reach, recovery to idle, and Reduced Motion suppression. Related motion,
  mobile, reduced-motion/performance, and smoke regressions passed; the exact
  serialized final then passed motion plus smoke again after reopen.
- Final size: `1,409,352` bytes
- Final SHA-256:
  `88F4F78E6D2EB1E54392E57C934FBFB0019BDADE37839E665C6136FEA322B208`
