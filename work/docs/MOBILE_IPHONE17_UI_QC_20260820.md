# Mobile UI / iPhone 17 Design QC — 2026-08-20

## Scope and target

- Primary reference: iPhone 17 landscape, 874 x 402 logical pixels (2622 x 1206 native at 3x).
- Required surfaces: idle HUD, Inventory All/Pets/Honor, Shop Fists/Premium/Boosts/Honor/Robux, Missions, Rebirth locked/confirm, Settings, and Hero Spin.
- Acceptance priority: unobstructed gameplay view, coherent visual hierarchy, no control-to-control overlap, no clipped text, and a minimum 44 x 44 logical-pixel active touch target.

## Before-remediation audit

The current-source Studio candidate was fingerprinted and all 14 states were opened through the production client callbacks. The structural device and standalone-window flows passed, but they did not detect the visual-density problems reported on a real phone.

Real-input and screenshot evidence is intentionally not marked as passed. Studio MCP timed out on the first `user_mouse_input` request and on `screen_capture`; Windows Graphics Capture then returned `No such interface supported`. The durable structured result is in `work/docs/evidence/mobile-iphone17-layout-20260820/before/capture-summary.json`. The user-provided public-phone screenshots remain the direct visual evidence for the HUD-density failure.

### Prioritized findings

1. **P1 — Main Punch control never receives the compact layout.** `ActionJump` is resized in the compact branch, but the active `referencePunch` remains the original 250 x 250 design proportion. This is the oversized red control visible in the public-phone screenshot.
2. **P1 — Movement joystick never receives the compact layout.** The active 270 x 270 reference joystick remains a desktop-derived proportion and consumes too much of the lower-left gameplay view.
3. **P1 — The phone HUD displays too many simultaneous information layers.** Rank track, detailed Quest card, tutorial objective, three stat cards, Honor, Next World, two left actions, five right-menu actions, three utilities, Jump, Punch, and directional punch controls compete on a screen only about 400 logical pixels high.
4. **P1 — The right-side phone menu is over-allocated.** Five 58 x 72 controls in a two-column/three-row layout consume roughly 232 logical pixels of vertical space before Punch/Jump are considered. Quests is redundant because Missions remains reachable from Daily and More.
5. **P1 — One touch flag selects the phone layout for every touch device.** `TouchEnabled or viewport.Y < 520` makes tablets and touch-capable desktop devices use phone geometry even when their short side is large. There is no phone/tablet/desktop profile boundary.
6. **P1 — Compact modal fitting leaves inconsistent edge reserves.** Inventory nearly fills the entire compact root while Shop, Rebirth, Settings, Missions, and Spin each use different ad-hoc margins. A single safe-area contract is needed so the Dynamic Island/system clusters and bottom gesture area never compete with modal controls.
7. **P2 — Hero Spin uses almost the full short side.** Its 760 x 558 art panel is fitted to within 14–18 pixels of the edge. The close control can fall below 44 effective pixels after scaling.
8. **P2 — User UI scale is not consistently bounded by available phone space.** Some legacy HUD layers multiply by the user setting while the active reference HUD does not, producing inconsistent apparent sizes and possible 120% overflow.
9. **P2 — Existing automated checks are too narrow.** They prove selected buttons are at least 44 pixels and only one historical overlap pair, but do not assert the active Punch/joystick footprint, total HUD coverage, safe lanes, modal bounds, or all-pairs overlap on an iPhone 17 profile.

## Remediation design contract

- Add explicit `PhoneLandscape`, `TabletTouch`, and `Desktop` responsive profiles based on the actual safe-root dimensions, not `TouchEnabled` alone.
- Phone HUD: 96 px maximum Punch, 112 px maximum joystick, 64 px maximum Jump, 44–52 px utility/menu targets, compact 2 x 2 primary menu, and no redundant Quests button.
- Hide the detailed rank track and Quest card on phone; retain their information through Next World, objective, Daily, and Missions.
- Keep Power/Coins/Wall plus the tutorial objective as the top hierarchy; keep Honor discoverable without competing with utilities.
- Use one compact safe-margin contract for every modal. Preserve at least 12 px inside the device-safe ScreenGui on iPhone 17 and at least 44 px for all active controls.
- Reduce Hero Spin to a comfortable inner frame and enlarge its close region before scaling.
- Add an exact iPhone 17 flow/contract that fails on oversized Punch/joystick, redundant phone Quests, unsafe modal bounds, small controls, clipped text, or overlapping primary controls.

## After-remediation result

Implemented `PhoneLandscapeV3` against the 874 x 402 iPhone 17 simulator profile (874 x 381 runtime viewport after the Studio top inset):

- The movement joystick is capped at 112 px, Punch at 96 px, Jump at 64 px, and both directional punch targets are 44 x 44.
- The right menu is now a sparse 2 x 2 cluster (Inventory, Shop, Pets, Rebirth). The redundant Quests tile is hidden on phones; Missions remains available from Daily and More.
- Sound, Settings, More, Daily, Spin, and the four primary menu controls now retain a measured touch floor of at least 44 px.
- The utility row and primary menu have an explicit gutter. The first runtime QC loop found `SoundTool:InventoryButton`; the second loop fixed that exact collision and reported no primary-control overlap.
- The first image-review loop found that Settings option hitboxes existed but their visuals were buried below the row chrome. The option controls now render one Z layer above their parent; the second capture visibly confirms ON/OFF, CALM, and 80/100/120% states.
- The phone information hierarchy now keeps Power, Coins, Wall/Depth, Objective, Honor, and Next World. The detailed Rank and Quest cards are removed from the gameplay view but remain accessible through Missions.
- Inventory, Shop, Missions, Rebirth, Settings, and Spin use bounded compact geometry. Spin hides the gameplay HUD while open and gives Close and Buy controls at least 44 px.
- Phone/tablet/desktop selection is driven by viewport dimensions rather than treating every touch device as a phone.

### Current QC evidence

- `after/flow-result.json`: PASS, 18/18 ordered runtime checks covering the HUD, all Inventory states, five Shop pages, Missions, Rebirth, Settings, Spin, runtime console, post-stop console, and simulator cleanup.
- `after/capture-summary.json`: all 14 requested surfaces opened and captured; the six top-level player routes (Inventory, Shop, Missions, Rebirth, Settings, Spin) each passed with one real `user_mouse_input` click. All 14 JPG hashes match; current local/runtime source fingerprints match; zero effective small targets; zero rendered-text failures on non-zero visible rectangles; clean runtime and post-stop console; simulator restored and the custom device removed.
- Manual review of the 14 current screenshots: PASS for design/layout. HUD lanes are separated, every modal remains readable, five Shop pages have stable 2 x 2/scroll presentation, Rebirth reset/keep hierarchy is clear, Settings controls are visible, and Spin is isolated from the HUD.
- Static mobile contract: PASS 17/17.
- Updated multi-device HUD/Shop contract: PASS 7/7, including the 844 x 390 and 740 x 360 phone policies.
- Full non-Studio aggregate: PASS — Node syntax 47, PowerShell syntax 19, Luau 27/27, flow JSON 114, and all 25 non-Studio contracts (the Studio performance benchmark is the sole declared exclusion).

The raw capture diagnostic intentionally does not use its generic `safe` flag as acceptance for `ScreenGui` descendants because Roblox reports those absolute coordinates relative to the CoreGui inset. Acceptance uses root-relative runtime bounds, pairwise overlap, coverage, and exact target assertions in `mobile-iphone17-layout.json`.

## Release status

- Responsive source and automated layout gate: **PASS**.
- Current iPhone 17 screenshot-based design/layout sign-off: **PASS** (14/14 current, hash-bound images reviewed).
- Studio player-input routing gate: **PASS** — all six top-level HUD routes opened on the first real click; the capture records `inputMode = REAL_MOUSE_INPUT`.
- Physical iPhone 17 touch/manual feel and hardware gamepad: **NOT RUN**. This is the remaining real-device confirmation, not a known source/layout defect.

## Follow-up density pass — compact HUD V4

The public-phone follow-up requested another approximately ten-percent optical reduction, a smaller Objective, and Honor aligned with the primary currencies. `PhoneLandscapeV4` now applies that exact hierarchy:

- Punch is reduced from the prior 92 px policy to 84 px (80 px measured at the iPhone 17 runtime scale), joystick from 110 to 100 (95 measured), and Jump from 62 to 56 (53 measured).
- Daily, Spin, Inventory, Shop, Pets, Rebirth, Sound, Settings, and More retain their measured 44 px minimum hit targets while their artwork is inset to 90%; this reduces visual weight without making real touch harder.
- Primary menu spacing is reduced from 6 px to 4 px; the utility row uses a 2 px optical gap while remaining non-overlapping.
- Power, Coins, Depth, and Honor now form one ordered 40 px-high stat row. The focused runtime gate asserts equal Y/height, zero adjacent overlap, and no overlap with Objective.
- Objective is reduced from up to 280 x 38 to at most 220 x 30, with phone text capped at 10 px. Desktop restores its original 340 x 48 / 13 px policy.
- The current iPhone 17 runtime gate passes 18/18. The recaptured 14-state bundle is current and source-fingerprint bound; all six top-level routes again opened with one real mouse-input click, all effective targets are at least 44 px, runtime/post-stop consoles are clean, and simulator cleanup is complete.

Manual visual review of `after/01_iphone17_hud.jpg` confirms the four-currency row reads as one system, the Objective no longer dominates the center, the left/right icon groups are visibly lighter and tighter, and the gameplay/avatar lane remains unobstructed. No new in-scope design/layout defect was found in the other 13 recaptured surfaces.
