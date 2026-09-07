# Agent 3 Device, Runtime, and Performance Baseline

- Source commit: `fb73c57baa0049e7e3ca284adf4b439f81571fc1`
- Source policy: frozen; this run does not edit gameplay code or automation flows.
- Fresh Studio process: PID `25464`
- Pinned Studio MCP instance: `84cec529-f3c9-4c74-8cbf-90a0de71541a`
- Source sync: all eight authoritative Rojo mappings completed successfully.
- Game orientation: `LandscapeSensor`
- Runtime GUI policy: `DeviceSafeInsets`, `ClipToDeviceSafeArea=true`,
  `SafeAreaCompatibility=FullscreenExtension`.

## Device matrix checkpoint

| Device | Runtime viewport | UI scale | Inventory mode | Columns | Minimum target | Off-screen inventory nodes | Text-not-fit | Visual capture |
| --- | ---: | ---: | --- | ---: | ---: | ---: | ---: | --- |
| Average Laptop | 1366x767 | 80% | Pane | 5 | 44 px | 0 | 0 | `agent3_desktop1366_inventory_scale80` |
| Average Laptop | 1366x767 | 100% | Pane | 5 | 44 px | 0 | 0 | `agent3_desktop1366_inventory_scale100` |
| Average Laptop | 1366x767 | 120% | Pane | 3 | 50.6 px | 0 | 0 | `agent3_desktop1366_inventory_scale120` |
| HD 1080 | 1920x1078 | 80% | Pane | 5 | 44 px | 0 | 0 | `agent3_desktop1920_inventory_scale80` |
| HD 1080 | 1920x1078 | 100% | Pane | 5 | 44 px | 0 | 0 | `agent3_desktop1920_inventory_scale100` |
| HD 1080 | 1920x1078 | 120% | Pane | 5 | 50.6 px | 0 | 0 | `agent3_desktop1920_inventory_scale120` |

Desktop inventory snapshots also reported `insideSafeArea=true`,
`noOverlap=true`, `allTextFits=true`, and no active target below 44 px.
HUD captures: `agent3_desktop1366_hud_scale80` and
`agent3_desktop1920_hud_scale100`.

The exact simulator resolutions are 1366x768 and 1920x1080. Roblox runtime
reported viewports one and two pixels shorter respectively after Studio/CoreGui
insets. This is recorded as observed runtime behavior rather than normalized.

### Phone and tablet checkpoint

| Simulator device | Exact simulator resolution | Runtime viewport | Orientation | Touch | Inventory layout | Minimum target | Snapshot assertions | Visual captures |
| --- | ---: | ---: | --- | --- | --- | ---: | --- | --- |
| Samsung Galaxy A06 with exact override | 740x360 | 645x338 | LandscapeLeft | true | compact Drawer, 3 columns | 44 px | safe, no overlap, all text fits | `agent3_phone740_hud_landscapeleft`, `agent3_phone740_inventory_landscapeleft`, `agent3_phone740_inventory_drawer_landscapeleft` |
| iPhone 13 | 844x390 | 749x368 | LandscapeRight | true | compact Drawer, 3 columns | 44 px | safe, no overlap, all text fits | `agent3_phone844_hud_landscaperight`, `agent3_phone844_inventory_landscaperight` |
| iPad 6th Generation | 1024x768 | 1023x767 | LandscapeLeft | true | compact Drawer, 5 columns | 44 px | safe, no overlap, all text fits | `agent3_tablet1024_hud_landscapeleft`, `agent3_tablet1024_inventory_landscapeleft`, `agent3_tablet1024_inventory_drawer_landscapeleft` |

The generic GameMenu was also rebuilt and measured page-by-page on the exact
740x360 Samsung profile. Its runtime viewport was `645x338`; because
`IgnoreGuiInset=true` and the top GUI inset is 58 px, the correct absolute
coordinate bounds are `x=0..645`, `y=-58..280`. ScrollingFrame content below
the fold was excluded unless it actually intersected the clipped viewport.

| GameMenu page | Actually visible buttons | Minimum target | Targets below 44 px | Visible text-not-fit | Viewport-offscreen controls/text | Capture |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| Fists custom shop | 11 | 44 px | 0 | 0 | 0 | `agent3_phone740_gamemenu_fists` |
| Pets | 6 | 38 px | 6 | 1 | 0 | `agent3_phone740_gamemenu_pets` |
| Honor | 7 | 38 px | 6 | 2 | 0 | `agent3_phone740_gamemenu_honor` |
| Tasks | 7 | 38 px | 6 | 1 | 0 | `agent3_phone740_gamemenu_tasks` |
| Settings | 8 | 38 px | 6 | 2 | 0 | `agent3_phone740_gamemenu_settings` |

On each legacy page, the 38 px controls are the `38x38` Close button and five
`73x38` top tabs. The measured visible descriptions also render with ellipses:
Pets `HIDDEN WALL EGGS`; Honor `HOW TO EARN HONOR` and `Vanguard Trail`;
Tasks `Tutorial`; Settings `Motion Feedback` and `Sound Feedback`. The custom
Fists shop meets 44 px and has no truncation/off-screen finding. This confirms
`UI-001` for the legacy 740x360 GameMenu only; it is independent of the
Inventory module, whose compact controls meet 44 px.

`ScreenOrientation=LandscapeSensor`, so portrait is outside the authored
orientation contract. Both supported landscape directions were exercised across
the phone cases. The smaller phone runtime widths are the simulator's device
safe viewport, not a requested-resolution mismatch.

Phone HUD captures show the Roblox CoreGui cluster touching/partially overlaying
the decorative outer edge of the Power card. Power text remains readable and
gameplay controls remain reachable. Inventory mode reserves enough header space
for the same CoreGui cluster. Treat the HUD contact as a minor polish watch item,
not an Inventory acceptance failure.

## Fresh isolated functional confirmations

### Jump

Fresh precondition:

- `HumanoidRootPart.Anchored=false`
- Humanoid `Running` on `Slate`
- `PlatformStand=false`, `Sit=false`, health `100`
- `UseJumpPower=true`, `JumpPower=50`, `JumpHeight=7.2`

The internal Jump command and a real `PixelPerfectHeroCityHUD.ActionJump`
click each produced:

- maximum vertical delta `7.266329` studs
- state sequence `Jumping -> Freefall -> Landed -> Running`
- return to the original grounded Y position

This rejects the earlier fresh-state product-failure hypothesis for the HUD
path. Studio MCP `user_keyboard_input` returned `Success` for Space but neither
targeted attempt reached a temporary `UserInputService.InputBegan` observer.
Space therefore remains a virtual-input harness-delivery gap, not evidence of
a broken game keyboard handler.

### Inventory Delete

Fresh seed: one unequipped, unlocked Crystal Fox with key `pet:slot:1`.
`ActionDelete` was visible and active at `118x44`.

After a correct-path click and a 450 ms observation window:

- `InventoryDeleteConfirmationScheduled=false`
- `InventoryDeleteConfirmationKey=""`
- button text remained `DELETE`
- no `LastInventoryAction` or `LastInventoryActionKey` was written

One instrumented retry attached an independent listener to the same button.
It recorded `Activated` exactly once (`os.clock=2787.6460698`), while the
controller attributes remained unchanged. This independently confirms
`INV-001`: the visible button receives activation but its scoped Inventory
callback is stale/disconnected. The first incorrect diagnostic instance path
was rejected before input and is classified as a tester-path error; it is not
counted as a product attempt.

### Legacy pet fusion

Fresh seed:

- `PetInventoryJSON=["Crystal Fox","Crystal Fox"]`
- `EquippedPetsJSON=[]`
- `LockedPetsJSON=[]`

After the legacy Pets content was scrolled into view and allowed to settle for
450 ms, one real click on the active `FUSE 2` control produced:

- `PetInventoryJSON=["Crystal Fox#2"]`
- `EquippedPetsJSON=["Crystal Fox#2"]`
- `PetMultiplier=1.4875`
- feedback telemetry `PetFusion / Crystal Fox#2`
- rebuilt control `FUSE 3`, inactive

`INV-002` did not reproduce in this controlled fresh-state path. The earlier
failure is consistent with attempting the control before it was visibly
scrolled and its rebuilt row had settled.

### Settings rebuild

The Settings page was allowed to settle before each input:

1. first real Motion click after 550 ms changed `motion=true -> false` and
   rebuilt the button as `OFF`;
2. a second real click on the newly rebuilt button after another 550 ms changed
   `motion=false -> true` and rebuilt it as `ON`.

`UI-003` did not reproduce with the required post-rebuild wait.

### Premium and rebirth feedback

The current authored local contract has `PlaceId=0`,
`StudioTestGrantPremium=true`, and all premium-pet game-pass IDs at zero. A
settled visible premium-pet click granted Crimson Phoenix authoritatively:

- `OwnedPremiumPetsJSON=["Crimson Phoenix"]`
- `PetInventoryJSON=["Crimson Phoenix"]`
- `EquippedPetsJSON=["Crimson Phoenix"]`
- client telemetry observed `Pet / Crimson Phoenix`

An attempted runtime mutation of a separately required config table did not
change the bootstrap script's already-cached `StudioTestGrantPremium=true`
contract, so this run does **not** claim that it exercised the unpublished
`PremiumSetup` branch. A subsequent explicit player remote was observed once
on the server and granted the same Studio pet path, while the client had no
feedback attributes and both `Toasts` and `RewardPops` were invisible with zero
children. This confirms inconsistent/missing visible premium feedback locally,
but not a live purchase or unavailable-branch result.

For a fresh gated rebirth (`WallLevel=1`, `Coins=0`, `Rebirths=0`), the player
remote preserved `Rebirths=0` and the client received telemetry
`FeedbackCount=1`, `LastFeedbackType=Fail`, `LastFeedbackTarget=Rebirth`.
Nevertheless, `Toasts.Visible=false` and `RewardPops.Visible=false`, both with
zero visible children. `UX-001` is therefore confirmed specifically as a
presentation defect: the rejection reaches the client but is not rendered.

## Camera, player motion, and companion occlusion

The server reset and stress helpers were used only to establish an isolated
runtime state. World auto-reset was disabled, and 128 depth blocks were cleared
(layers 1-8, columns 5-8, rows 1-4; block size `4x4x4`) before entering the
depth corridor.

Real-player camera observations:

| Player position | Camera position | Root-to-camera | Inside geometry | Obscurers | Capture |
| --- | --- | ---: | --- | ---: | --- |
| Depth entrance `(-2, 3, -27)` | `(-2, 9.055, -14.926)` | 12.551 studs | false | 0 | `agent3_realplayer_depth_entry_normal` |
| Cleared corridor `(-2, 4, -57)` | `(-2, 8.799, -44.926)` | 12.551 studs | false | 0 | `agent3_realplayer_depth_corridor_normal` |

The live player camera remained `Custom`, did not enter geometry, and reported
no obscuring parts in either position.

The authored `__RunCamera` diagnostic was then run three times for 20 actions:

| Mode | Actions | Clear ratio | HUD readable ratio | Avatar visible ratio | Inside geometry | Max applied step | Lead | Authored result |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Motion on | 20 | 0.92308 | 1.00000 | 1.00000 | 0 | 2.4000 | 45.517 | valid |
| Motion off | 20 | 1.00000 | 1.00000 | 1.00000 | 0 | 0.0000 | 0.002874 | invalid |
| Motion on repeat | 20 | 1.00000 | 0.71226 | 1.00000 | 0 | 2.40001 | 35.169 | valid |

The reduced-motion run is visually and mechanically valid: it has a fully
clear camera, readable HUD, visible avatar, zero geometry entry, and zero
applied motion. The diagnostic marked it invalid only because its validator
unconditionally requires lead greater than one stud. That is a stale test
expectation for intentionally suppressed motion, not a reduced-motion product
failure.

### Three-premium-pet camera parity

The server authoritatively equipped Crimson Phoenix, Storm Wyvern, and
Celestial Guardian. The client rendered exactly three companion models in both
motion modes. Their observed world-space bounds and screen overlap with the
player character were:

| Companion | Bounds (studs) | Distance from root | Character-overlap projection, motion on | Character-overlap projection, motion off |
| --- | --- | ---: | ---: | ---: |
| Crimson Phoenix | `5.19 x 3.00 x 1.81` | 4.4-4.5 studs | 21,705 px² | 22,276 px² |
| Storm Wyvern | `13.58 x 2.55 x 8.70` | 4.0-4.1 studs | 87,316 px² | 85,215 px² |
| Celestial Guardian | `1.99 x 2.85 x 3.11` | 5.6 studs | 0 px² | 0 px² |

Captures `agent3_realplayer_premium3_normal` and
`agent3_realplayer_premium3_reduced` show Storm Wyvern's wing spanning the
center of the gameplay view and the Phoenix also covering the avatar. Motion
off does not materially reduce the obstruction. `CAM-001` is therefore
confirmed as a player-visible companion scale/formation defect. Roblox camera
geometry occluder count remained zero because the companion folder was excluded
from `GetPartsObscuringTarget`; the screen-space projection and captures are the
relevant visual evidence.

## Runtime and performance

Performance measurements used the Average Laptop simulator at the runtime
viewport `1366x767`, Motion Feedback on, and the three premium companions
equipped. Studio PID `25464` was explicitly brought to the foreground before
timing samples.

### Frame timing

| Sample | Frames | p50 | p95 | p99 | Maximum | Frames >33.3 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Focused steady state | 300 | 16.847 ms | 18.325 ms | 19.405 ms | 21.981 ms | 0 |
| Focused after two 200-break stress batches | 300 | 16.742 ms | 18.616 ms | 19.471 ms | 20.179 ms | 0 |
| LibMP focused snapshot | 128 | 16.927 ms | 17.927 ms | 17.980 ms | 18.162 ms | 0 |

The first unattended sample measured an almost constant 66.7 ms/frame. A
focused repeat immediately returned to the values above. The 15 FPS result is
therefore classified as Studio background throttling and excluded from product
performance conclusions.

The LibMP snapshot covered frame IDs `1-128`, absolute frame IDs
`373006-373133`, with zero paused or incomplete frames. It contained 65 threads,
1,008 timers, and 594 counters in an 8,563,896-byte snapshot. The LibMP session
was disposed after analysis; its WASM allocation returned from 566,728 bytes to
4,280 bytes.

### Effect cleanup and allocation plateau

With `Power=1e12`, `WallLevel=99`, and critical chance disabled, the server
completed 200 real `Brick Wall` break/reset cycles in 0.280 seconds. This
produced 200 authoritative daily breaks and temporarily reached the authored
`Depth Physics Debris` cap of 120 objects. After the cleanup window:

- server and client `Depth Physics Debris` returned to `0`;
- `LocalDamageNumber` and `LocalBreakDebris` returned to `0`;
- client DataModel/workspace/root/PlayerGui descendant counts returned exactly
  to `14095 / 7850 / 7399 / 904`;
- server DataModel/workspace/root descendant counts returned exactly to
  `10834 / 7725 / 7399`;
- client/server Stats instance counts returned exactly to `48422 / 45111`.

A second 200-cycle batch was run as a plateau check. It also cleaned back to the
same exact instance and hierarchy counts, and focused frame timing did not
degrade.

| Memory tag | Before first 200 | 15 s after first 200 | 15 s after second 200 |
| --- | ---: | ---: | ---: |
| Total process memory | 1779.133 MB | 1817.551 MB | 1820.227 MB |
| LuaHeap | 571.788 MB | 574.424 MB | 574.773 MB |
| Signals | 16.293 MB | 16.455 MB | 16.621 MB |
| Instances | 56.264 MB | 56.484 MB | 56.613 MB |
| BaseParts | 97.519 MB | 98.046 MB | 98.419 MB |
| Internal | 1350.450 MB | 1352.945 MB | 1354.567 MB |

The exact hierarchy and effect counts reject a retained-instance/effect leak in
this stress path. Memory rose about 38.4 MB on the first batch and only another
2.7 MB on the second, consistent with a process allocator/cache high-water
plateau. It did not return during the 15-second observation windows, so this is
recorded as a memory watch item rather than claimed leak-free memory behavior.
Absolute memory is from a Studio Play process, not a standalone production
client.

Roblox does not expose a supported runtime connection-count enumerator. The
`Signals` memory tag above is used as the connection/allocation proxy; exact
instance and effect counts are the primary cleanup evidence.

### Scene composition and rendering

`SceneAnalysisService` reported 9,442 scanned client instances:

- 6,950 3D objects
- 1,371 UI instances
- 448 physics instances
- 172 values
- 149 script/remote/bindable instances
- 147 particle instances

The largest individual classes were 6,309 `Part`, 395 `MeshPart`, 387
`Attachment`, 359 `Frame`, 240 `TextLabel`, and 146 `ParticleEmitter`. The
server has exactly 5,400 authored depth blocks. Workspace streaming is enabled,
but the compact map remained fully resident in this Studio client. The depth
grid is therefore the main instance-count optimization opportunity even though
view culling keeps rendering cost low.

All triangle/draw figures below exclude the engine-driven Shadows pass:

| Authored view | Triangles | Draw calls |
| --- | ---: | ---: |
| Spawn | 60,097 | 52 |
| Depth start | 14,602 | 24 |
| Training | 95,916 | 142 |
| Armory | 97,360 | 123 |
| Pet Lab | 71,849 | 129 |
| Honor | 81,880 | 120 |
| Rebirth | 66,377 | 67 |

The default player view was 66,408 adjusted triangles and 64 adjusted draw
calls. The sampled views remain well below the SceneAnalysisService contextual
reference point of roughly 800k triangles and 600 draw calls for broad 60 FPS
device coverage. Training had the highest sampled draw count; Armory had the
highest triangle count. UI contributed roughly 14k-20.6k triangles per view.

Scene memory queries found:

- client animation clip memory: 139,803 bytes across two clips;
- client loaded audio memory: 5,341,902 bytes, led by the standard falling
  sound (1,764,000), boss roar (753,664), and glove Zap1 (651,264);
- server animation clip memory: 139,803 bytes and loaded audio memory `0`;
- 43 client and 32 server unparented instances, all attributed to Roblox
  Chat/PlayerModule/Freecam scripts in the returned top hosts; no custom
  Punch Wall script appeared in the host list;
- per-script VM attribution was unavailable because this Studio build lacks
  the required `STUDIOPLAT37936` flag. This check is explicitly blocked rather
  than treated as passing.

## Persistence, reset, and receipt contracts

The local place reports `PlaceId=0`, `GameId=0`. Studio prints the expected
unpublished-place DataStore-disabled message, so this run cannot perform a real
cross-server reconnect, DataStore retry/failure, or Robux receipt delivery.
Local results below are deterministic contract checks; they do not replace the
published-universe release gate.

### Manual-equivalent regression assertions

The standard flow runner cannot be safely used while two Studio processes have
the same place name: it has no `--studio-id` option and selects the first regex
name match. Every step below was therefore executed directly against the pinned
MCP instance `84cec529-f3c9-4c74-8cbf-90a0de71541a`.

`inventory-persistence` equivalent:

- Boxing Glove purchase: true
- pet hatch: true
- rebirth: true
- owned Boxing Glove retained: true
- pet inventory/equipped counts after rebirth: `1 / 1`
- rebirth reset equipped fist to Starter Glove: true
- Boxing Glove re-equip: true
- contribution reward curve: `100 / 75 / 55`, strictly ordered

A subsequent harness `Respawn` preserved Boxing Glove ownership/equip and the
`1 / 1` pet inventory/equipped counts. This is a same-Player character respawn
pass, **not** evidence of reconnect persistence.

`world-wall-reset` equivalent:

- interval `300`, reset count `6`
- one player teleported; spawn distance `5` studs
- Power/Coins/Depth/Score preserved as `987 / 654 / 12 / 3456`
- `5400` intact depth blocks; broken/detached/fragments `0 / 0 / 0`
- client feedback telemetry `WorldReset / Spawn`

`release-expansion-economy` equivalent passed all five authored assertions:

- Celestial Titan Fist multiplier `60`, effective power
  `30.03 -> 1801.80`
- continuous training active with gain `16`
- weighted spin returned `Coins500`; SpinPack left `3` credits
- Honor purchase/bonus `35 / 0.25`; final-world award stayed `5` after a
  second block in the same cycle
- rebirth result `1` rebirth and `0` coins

### Open production contracts

All four runtime boost timestamps were approximately 899 seconds in the future
after purchase/grant and remained identical across same-Player `Respawn`.
However, `collectPlayerData` serializes only named leaderstat/RPG number/text
values, and `ensureStats` does not restore
`CoinBoostExpiresAt`, `DamageBoostExpiresAt`, `SpeedBoostExpiresAt`, or
`TrainingBoostExpiresAt`. `ECON-003` therefore remains confirmed for a real
reconnect; the Respawn pass does not mitigate it.

Two direct deterministic CoinPack grants changed coins
`0 -> 7500 -> 15000`. This is supporting evidence that the grant operation
itself is intentionally non-idempotent. The production `ProcessReceipt`
implementation grants immediately and returns `PurchaseGranted` without
persisting/checking `PurchaseId`, so `ECON-001` remains confirmed by static
server-authority audit. Roblox exposes `ProcessReceipt` as a set-only callback,
so supported Luau cannot read/invoke it for a local duplicate-receipt probe.
Real receipt retry/delivery remains a published-universe gate.

`SAVE-001` remains confirmed statically: a failed current-store `GetAsync`
returns `{}` and allows normal initialization/save to continue, so defaults can
overwrite a previously valid profile. `SAVE-002` remains confirmed statically:
`savePlayerData` returns immediately when `savingPlayers[player]` is already
set, while final leave/shutdown requests neither queue nor await that in-flight
save. Both failure modes require the server persistence implementation to
change; the unpublished local session cannot safely simulate the production
failure boundary.

`QA-002` also covers this run's duplicate-name ambiguity: the runner's fallback
to the first Studio applies both when an expected name is absent and when more
than one Studio matches. Development should require an exact
`studioInstanceId` or strict one-match cardinality.

## Final classification

### Confirmed product findings

- `INV-001`: the visible Inventory Delete button receives `Activated`, but its
  scoped controller callback is stale/disconnected.
- `UX-001`: gated rebirth rejection reaches client telemetry but renders no
  Toast/RewardPop.
- `CAM-001`: Crimson Phoenix and especially Storm Wyvern materially obscure
  the player/center view in both motion modes.
- `UI-001`: the 740x360 legacy GameMenu uses 38 px Close/tab targets and shows
  visible description truncation. The custom Fists shop and Inventory module
  do not share this finding.
- `ECON-001`, `ECON-003`, `SAVE-001`, and `SAVE-002`: confirmed production
  receipt/persistence contract gaps described above.
- Premium Studio grants show inconsistent/missing visible feedback despite
  authoritative grant telemetry. The unpublished purchase/setup branch remains
  unverified.

### Passed or not reproduced

- Inventory safe-area/layout assertions passed on all tested device/scale
  combinations with 44 px minimum controls.
- Fresh real HUD Jump passed with the expected 7.266-stud arc and state
  sequence.
- Legacy pet fusion passed after the row was scrolled into view and settled;
  the earlier `INV-002` report did not reproduce.
- Settings Motion toggled ON/OFF through rebuilt controls with the required
  settle wait; the earlier `UI-003` report did not reproduce.
- Real player camera did not enter geometry at the depth entrance or cleared
  corridor.
- Focused frame timings remained stable after stress, and temporary gameplay
  effects/hierarchy counts returned exactly to baseline.
- Direct equivalents of Inventory persistence-through-rebirth, world reset,
  and release-expansion economy flows passed on the pinned integration Studio.

### Harness/tooling classifications

- Studio virtual Space returned success but did not reach
  `UserInputService.InputBegan`; real HUD Jump is the authoritative product
  result.
- The reduced-motion camera diagnostic's unconditional `lead > 1` expectation
  is stale for intentionally suppressed motion.
- The initial 66.7 ms frame sample is Studio background throttling; focused
  timing is authoritative.
- `QA-002`: name-only flow selection is unsafe for absent or duplicate Studio
  names.
- `SceneAnalysisService:GetScriptMemoryAsync()` is blocked by this Studio
  build's missing `STUDIOPLAT37936` flag.
- AssistantCommand diagnostic errors for unavailable Workspace streaming
  properties, reading the set-only `ProcessReceipt` callback, setting mobile
  orientation before a device was active, and restricted GuiService methods
  were tester/tool-path errors. They are not gameplay script exceptions.

### External release gates

- real DataStore load/save/migration/retry and cross-server reconnect;
- non-zero Creator Dashboard Game Pass/Developer Product IDs;
- real Robux prompts, receipt delivery, and retry;
- analytics ingestion and published-device profiler runs.

The final phone session console contained only the expected unpublished
DataStore-disabled message and Studio's `DevCameraOcclusionMode` permission
message. No game-script exception was present.

## Final cleanup and handoff

- Fresh Studio instance
  `84cec529-f3c9-4c74-8cbf-90a0de71541a` is in `Edit` mode.
- Device simulation changed from `samsung_galaxy_a06` to `default`.
- Stored orientation is `LandscapeLeft`; the custom-device list is empty.
- The co-resident same-name Studio instance was not closed or modified because
  its unsaved state could not be disproved.
- Source commit remains
  `fb73c57baa0049e7e3ca284adf4b439f81571fc1`; no source, flow, branch, index,
  commit, or push was changed by Agent 3.
- Only this isolated evidence report was authored. All unrelated untracked
  assets, Coordinator report, and other agents' evidence were preserved.

Agent 3's baseline is complete and eligible for Coordinator integration. Known
in-scope defects and external/tooling gates are explicitly listed above; no
claim of absolutely bug-free software is made.
