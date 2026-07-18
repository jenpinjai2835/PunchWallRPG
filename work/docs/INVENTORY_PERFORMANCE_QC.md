# Inventory Performance And Reference UI QC

## Scope

This gate covers the Inventory performance, dedicated HUD action, and visual
restyle requested on 2026-07-18. The accepted result must:

- preserve server-authoritative ownership, equip, lock, delete, purchase, and
  progression behavior;
- preserve or improve gameplay, graphics, camera, animation, and motion;
- perform no recurring work while the Inventory is hidden unless required to
  receive authoritative state;
- avoid unbounded per-frame work, periodic full-hierarchy/full-state scans,
  repeated hierarchy searches, duplicate connections, and unbounded UI
  instance growth;
- use the user-supplied Inventory icon beside Shop without changing Shop;
- retain the desktop and compact functional acceptance in
  `INVENTORY_MODULE_QC.md`;
- reproduce the supplied reference's visual hierarchy with live game data
  rather than baked sample items.

## Baseline

The evidence in this document spans explicit checkpoints. A result applies
only to the commit named for that checkpoint; a later commit is not implied to
have passed an earlier build or full-suite gate.

| Checkpoint | Commit | Purpose |
| --- | --- | --- |
| Recorded baseline | `2baaae84b7cf7662624a8e388ad3a569d8b0e006` | Pre-Inventory performance record and complete-suite comparison |
| Inventory optimization/UI | `e7bd9bb4d5da9107074e0102cd7c0c81fa54eaed` | Measured microbenchmarks, frame capture, bounded-instance checks, and reference-style visual checks |
| Supported Inventory harness | `06b40ca7c5373c62cef8b1026ee421f609ea6342` | Supported public HUD action and targeted Inventory regression |
| Bounded Animate bootstrap fix | `6c671724ab334736ff5f31a9a80a9b64203e44fb` | Default `Animate.PlayEmote` repair and reset regression |
| Focus-independent final tests | `20ceda4a0f12751bcdb75794de0adccbd8dc68af` | Deterministic camera and character-motion validation without render-focus races |
| Final Inventory P2 lifecycle hardening | `4616106e81511434c07153f2aa7afeea9bc1b62e` | Adaptive rarity scrolling, bounded timed-expiry and delete-confirmation lifecycles, and final targeted runtime/performance evidence |
| Hidden timed-detail churn fix | `375913872fff9cb351b0d2ca550ba9d55f74ce23` | Prevent hidden compact details and nonselected timed items from receiving countdown mutations while preserving expiry scans and rebuilds |

Studio place: `PunchWallRPGPlayable_v1_final.rbxlx`.
Instance `597f195a-a442-457a-8e13-6627c44e58bf` was used for the earlier
Inventory, motion, timing, reset, and complete-suite sessions. Instance
`c0b2fe28-e907-428f-bf4e-d489f293e6e9` was used for the final camera
preflights and the later Inventory and frozen complete-suite checkpoints.

Device Simulator: custom desktop 1366x768, observed runtime viewport 1366x767.
The deterministic Inventory fixture contained eight visible entries.

### Client Microbenchmarks

The numbers below are one Studio session and are comparison evidence, not
cross-machine budgets.

| Operation | Iterations | Baseline total | Baseline per call |
| --- | ---: | ---: | ---: |
| `InventoryViewModel.Build` | 1,000 | 1,612.48 ms | 1.6125 ms |
| `InventoryViewModel.Filter` | 5,000 | 38.53 ms | 0.0077 ms |
| `InventoryViewModel.Signature` | 10,000 | 22,678.72 ms | 2.2679 ms |
| Search-driven Inventory rerender | 20 | 105.49 ms | 5.2743 ms |

The baseline signature was 8,979 bytes. The Inventory window had 202
descendants before the first alternating-search warm-up and 209 afterward.
After that warm-up, five consecutive batches of 20 alternating searches all
remained at exactly 209 descendants. Twenty close/open cycles also remained at
209 descendants. The five search batches took 85.72-100.61 ms, and the 20
close/open cycles took 380.57 ms. Final validation must warm the UI first and
prove subsequent repeated cycles remain bounded.

### Frame Capture

MicroProfiler captured 128 Inventory-open frames:

| Sample | Baseline |
| --- | ---: |
| CPU frame average | 17.0523 ms |
| CPU frame p50 | 16.9307 ms |
| CPU frame p95 | 17.9903 ms |
| CPU frame maximum | 36.4331 ms |
| Frame IDs | 1-128 |
| Absolute frame IDs | 1197186-1197313 |

The final comparison must use the same device, deterministic fixture, open
Inventory state, iteration counts, and a 128-frame capture. A one-session frame
capture is noise-sensitive, so accept it only alongside microbenchmarks,
bounded instances, clean console, and unchanged player behavior.

### Scene Health

The baseline player view was already inexpensive to render:

- 9,171 client instances: 6,896 3D objects and 1,192 UI instances;
- 45,629 triangles and 55 draw calls from the sampled camera;
- opaque pass: 27,141 triangles / 32 draws;
- UI pass: 16,608 triangles / 13 draws;
- 43 client and 32 server unparented instances, all attributed to Roblox
  PlayerModule/chat scripts in the returned summaries;
- 139,803 bytes of animation clips and 3,693,012 bytes of audio assets.

`GetScriptMemoryAsync` was unavailable because this Studio build did not expose
the `STUDIOPLAT37936` flag. This check is recorded as unavailable, not a pass.
The low render counts provide no evidence-based reason to remove visible
geometry, textures, particles, audio, or motion.

## User-Supplied HUD Icon

Source (raw UTF-8 filename):
`C:\Temp\RMBG\ChatGPT Image 18 ก.ค. 2569 16_18_20.png`

- dimensions: 500x500;
- format: 32-bit ARGB PNG with alpha;
- SHA-256:
  `06E7F1F97D3EDBB9E5638D7CF2A72C4935BFBC8C299D8FCBBF6230E0573A497A`;
- authenticated Roblox upload:
  `rbxassetid://123409223461276`.

The `inventory-menu-ui` flow at `06b40ca` verified that the dedicated
Inventory action is aligned beside Shop, has a minimum 44px target, does not
overlap Punch or Jump, uses the uploaded image, and opens the authoritative
Inventory modal through the supported public action.

## Signature Hot-Path Result

The `InventoryViewModel.Signature` optimization was validated in the active
Studio place before combined UI integration. Its 18 contract assertions cover
all nine authoritative state fields, duplicate pets, byte-length framing,
delimiter-collision resistance, ignored unrelated fields, config root/scalar/
catalog replacement, and explicit invalidation after an intentional in-place
config mutation.

| Scenario | Iterations | Result | Improvement |
| --- | ---: | ---: | ---: |
| Identical warmed state | 10,000 | 14.4358 ms total / 0.00144358 ms per call | 1,571x |
| Alternating `ShopBoosts` state every call | 10,000 | 208.2218 ms total / 0.0208222 ms per call | 108.9x |

The warmed signature is 8,919 bytes and is returned from cache without
`JSONDecode`, a config canonical rebuild, or a new signature allocation.
Dynamic fields use type- and byte-length-framed raw values, so a byte change
cannot be hidden by a separator collision. Runtime `GameConfig` is constructed
once and remains immutable; replacing a relevant scalar or catalog reference
invalidates automatically, while intentional nested in-place mutation must
call the tested `InvalidateSignatureCache` hook.

## Integrated Desktop Visual Check At `e7bd9bb`

The combined HUD, reference UI, and signature changes were synced from the
integration worktree into the exact active Studio place and checked at the same
custom 1366x768 device (runtime viewport 1366x767).

- capture `Inventory_Integrated_1366x768_ReferenceStyle_Final` shows the red
  industrial header, cyan/steel frame, external gold-selected category rail,
  five-column live-item grid, and right-side live detail panel;
- capture `Inventory_HUD_Icon_Beside_Shop_1366x768_Final` shows the supplied
  Inventory icon loaded immediately beside Shop;
- the uploaded icon reported `IsLoaded=true`, exact image
  `rbxassetid://123409223461276`, and a 61.95x61.95 px runtime target;
- the Inventory window measured 934x616 px at (216, 17.5), the category rail
  172x504 px at (42, 117.5), the grid pane 632x504 px at (228, 117.5), and the
  detail pane 270x504 px at (868, 117.5);
- the runtime snapshot reported five columns, 44 px minimum touch target, all
  text fitting, safe placement, and no category/grid/detail overlap;
- the Inventory tree stabilized at 415 descendants after warm-up. Five
  consecutive batches of 20 alternating searches remained exactly 415, and 20
  close/open cycles also remained exactly 415.

The richer reference styling uses more bounded static native UI instances than
the baseline. It has no animated decoration or hidden recurring timer: the
countdown Heartbeat exists only while the modal is visible and contains an
active timed item, then disconnects on hide, expiry, or destroy.

## Runtime Optimizations At `e7bd9bb`

The optimization-checkpoint client was synchronized to the same Studio place and
compiled in Play mode. An initial integration exposed Luau's 200-local-register
limit in the monolithic client script. The cache and training state were moved
into bounded closure scopes, then the checkpoint source compiled and ran with
no new game error. In the cleared manual Play session, the remaining
game-console messages were the expected unpublished-place DataStore warning
and Studio's `DevCameraOcclusionMode` permission warning. Separate
AssistantCommand errors produced while developing the test harness were
harness errors, not game-script errors, and were excluded from that cleared
session.

The behavior-preserving runtime changes are:

- warmed `InventoryViewModel.Signature` values are cached with explicit config
  invalidation and collision-safe field framing;
- hidden HUD visibility writes are event-driven instead of an idle render-loop
  workload;
- production Inventory callbacks skip the full diagnostic hierarchy snapshot,
  while the public Studio automation API remains backward compatible and
  returns a complete snapshot by default;
- selecting another visible item updates only the previous and next card
  visuals instead of destroying and rebuilding the entire grid;
- repeated authoritative training states do not restart the animation task;
- tier atmosphere work is keyed by tier, motion, and sound and re-applies only
  after a relevant change or coalesced hierarchy invalidation;
- the visible Shop compares a relevant-state/layout signature before rebuilding
  its UI and maintains its Boost countdown at displayed-second boundaries;
- ambient pulse discovery performs one initial scene scan per bound/replaced
  PunchWallRPG root and then maintains a bounded event-driven registry;
- the 0.15-second target interaction cadence is unchanged, while stable scene
  folders and one `OverlapParams` object are reused.

### Runtime Cache Evidence

The deterministic runtime fixture reported:

- twelve repeated depth/training state updates left tier applications and
  landmark scans unchanged at `4/4`;
- the first real depth-tier transition advanced both counters exactly once to
  `5/5`; five duplicate updates did not advance them again;
- four repeated training-on and four repeated training-off updates produced
  one loop start and only the two real state transitions;
- Inventory diagnostic snapshots advanced only for explicit automation reads,
  while production skips increased from 2 to 32 during repeated authoritative
  refresh traffic;
- 100 alternating Inventory selections kept `gridRebuilds=4`,
  `liveCards=7`, and `cardConnections=21`, while
  `selectionVisualUpdates` advanced to 100 and
  `cardConnectionBounded=true`;
- 61 Shop refresh requests caused only two builds while unrelated stats
  changed. Changing the owned-fist state caused exactly one additional build;
- ambient discovery reported `EventDrivenV1`, one initial root scan, nine live
  pulse parts, and observable transparency changes across frames;
- target discovery reported `EventDrivenFoldersV1` and exactly one
  `OverlapParams` construction.

Static lifecycle contracts additionally alternated 10,000 item selections with
one grid build and a constant 36 connections for twelve cards. At the
`e7bd9bb` checkpoint, the signature, Inventory runtime, client runtime, and
card-render contracts passed 18/18, 16/16, 19/19, and 10/10 assertions
respectively. The `4616106` card-render contract expanded that historical
10/10 coverage to 16/16, and the final `3759138` mutation-gate contract
expands it to 17/17.

## Performance Comparison At `e7bd9bb`

The optimization-checkpoint comparison used the same 1366x768 desktop device, eight-item
deterministic state, visible Inventory, and iteration counts.

| Operation | Baseline | `e7bd9bb` checkpoint | Result |
| --- | ---: | ---: | ---: |
| `InventoryViewModel.Build`, 1,000 | 1,612.48 ms | 1,635.33 ms | observed +1.4% in this single run; no statistical conclusion |
| `InventoryViewModel.Filter`, 5,000 | 38.53 ms | 19.17 ms | 50.2% lower |
| warmed `InventoryViewModel.Signature`, 10,000 | 22,678.72 ms | 12.22 ms | about 1,856x lower |
| five warm 20-search batches | 85.72-100.61 ms | 71.16-85.81 ms | lower range with stable descendants |
| 20 close/open cycles | 380.57 ms | 349.09 ms | 8.3% lower |

The checkpoint open/close check remained at exactly 382 descendants before and
after twenty cycles. After the first search warm-up, all five search batches
remained at exactly 391 descendants. The richer reference UI therefore remains
bounded even though it intentionally uses more static native UI objects than
the original basic layout.

The observed 1.4% increase in `InventoryViewModel.Build` time is explicitly not
an improvement claim and is too small to support a statistical conclusion from
this single-session benchmark.

### Optimization-Checkpoint 128-Frame Capture

| Sample | Baseline | `e7bd9bb` checkpoint |
| --- | ---: | ---: |
| CPU frame average | 17.0523 ms | 16.6617 ms |
| CPU frame p50 | 16.9307 ms | 16.9408 ms |
| CPU frame p95 | 17.9903 ms | 17.9938 ms |
| CPU frame maximum | 36.4331 ms | 30.4517 ms |
| Frame IDs | 1-128 | 386-513 |
| Absolute frame IDs | 1197186-1197313 | 1721237-1721364 |

The average is 2.3% lower and the sampled maximum is 16.4% lower. The p50 and
p95 remain at the display-frame cadence, so these results are interpreted
alongside the much larger hot-path reductions and bounded-object evidence
rather than as a standalone framerate claim.

### Optimization-Checkpoint Scene Health

The checkpoint player camera with the Inventory open reported:

- 9,465 client instances: 6,911 3D objects and 1,467 UI instances;
- 38,371 triangles and 42 draw calls;
- opaque pass: 22,705 triangles / 27 draws;
- transparent pass: 1,819 triangles / 1 draw;
- UI pass: 13,810 triangles / 10 draws;
- 43 client and 32 server unparented instances, unchanged from baseline and
  still attributed to Roblox player/chat modules;
- 139,803 bytes of animation clips and 3,914,196 bytes of loaded audio.

The additional UI instances are the bounded chrome, cards, labels, and detail
controls required by the supplied reference. The sampled checkpoint view reported
15.9% fewer triangles and 23.6% fewer draw calls than the sampled baseline
view. This is descriptive evidence only: small camera/viewpoint differences
mean the reductions cannot be attributed solely to this change. No task change
removed or downgraded world geometry, graphics, audio, particles, or motion.
Script memory remained unavailable because this Studio build still does not
expose `STUDIOPLAT37936`.

## Responsive Visual Check At `e7bd9bb`

The Studio capture labels are:

- `Inventory_Final_Desktop_1366x768_Reference_Optimized`;
- `Inventory_Final_HUD_Icon_Beside_Shop_1366x768`;
- `Inventory_Final_740x360_CompactGrid_ResponsiveFixed`;
- `Inventory_Final_740x360_CompactDetail_ResponsiveFixed`.

These are Studio capture labels only. No exported or persisted image files
were found for these labels. The unsupported physical-input diagnostic label
`Inventory_HUD_Physical_Click_QC_PreInput_Unsupported` likewise identifies a
Studio capture, not an exported image file.

Desktop retains the five-column grid, external category rail, right detail
pane, and uploaded Inventory icon beside Shop. The 740x360 landscape layout
uses three readable columns, reserves the upper-left system-control lane for
the title, contains the detail drawer and both 44px actions, and remains inside
the ScreenGui device-safe bounds. The checkpoint HUD icon reported
`IsLoaded=true`, exact image `rbxassetid://123409223461276`, a 61.95px square
target, a 21.39px gap before Shop, and a 0.41px vertical-center delta.

## Targeted Regression At `06b40ca`

The post-`e7bd9bb` targeted run exercised fifteen flows. After replacing the
invalid test-only `GuiButton:Activate()` calls with the supported public
automation action at validation commit `06b40ca`, the full
`inventory-menu-ui` flow passed all 40 labels at desktop 1366x768 and compact
740x360. It covered:

- the dedicated Inventory button contract and its shared `openGameTab` action
  path;
- the exact uploaded icon, placement beside Shop, 44px minimum target, and no
  Punch/Jump overlap;
- authoritative owned-item filters, fist equip, duplicate-pet lock/unlock/
  delete boundaries, and invalid/stale-key fail-closed behavior;
- desktop centered layout and compact drawer geometry;
- HUD restoration, default-device restoration, and both console-clean gates.

Twelve of the original fifteen targeted flow invocations passed directly:
`inventory-persistence`, `luck-distribution`,
`pet-wall-drops-and-fusion`, `functional-hero-shop`,
`punchwall-shop-and-pet`, `hero-city-pixel-perfect-hud`,
`responsive-ui-inputs`, `device-matrix-hud-shop`,
`punchwall-mobile-controls`, `release-expansion-ui`,
`full-game-tester-critical-ui-and-models`, and
`final-rbxlx-build-validation`. The two diagnostic failures were the same
known stale-fixture assertions as baseline: `fist-items-icon-ui` expected four
closed-fist objects and `iteration04-armory-pets-feedback` expected the absent
`Boxing Glove Gauntlet Palm`.

Roblox rejects `VirtualInputManager:SendMouseButtonEvent` from the Studio MCP
client with a missing `RobloxScript` capability, and the Windows capture helper
failed with `No such interface supported` before it could safely identify a
window-relative click coordinate. Physical mouse injection is therefore
recorded as unavailable rather than passed. The source callback, the shared
public action path, the resulting authoritative modal state, and a pre-input
runtime capture (`Inventory_HUD_Physical_Click_QC_PreInput_Unsupported`) were
all verified. That cleared Play session contained only the expected
unpublished DataStore and `DevCameraOcclusionMode` permission warnings.

## Final Runtime And Focus-Independent Regression

### Bounded Default Animate Repair At `6c67172`

The initial complete-suite run exposed an infinite-yield warning from the
default character `Animate` script waiting for a missing `PlayEmote` child.
Commit `6c671724ab334736ff5f31a9a80a9b64203e44fb` adds a bounded,
duplicate-safe bootstrap repair:

- it schedules one repair task for the current character and each subsequent
  `CharacterAdded` character;
- it allows up to four seconds for the default `Animate` script to appear and
  then gives Roblox's own `PlayEmote` child a 0.25-second grace period;
- only when the child is still absent does it create one fallback
  `BindableFunction` whose invocation returns immediately;
- it rechecks character ownership and existing children before creating
  anything, and its `ChildAdded` guard prevents duplicate fallback instances;
- it has no frame loop, periodic scan, or persistent retry task.

The updated `world-wall-reset` flow verifies one `Animate` script, exactly one
`PlayEmote` `BindableFunction`, bounded successful invocation, preservation
after reset, and a clean console. Three consecutive runs passed 10/10 checks:

- `C:\Temp\final-synced-025-world-wall-reset-run1.stdout.json`;
- `C:\Temp\final-synced-025-world-wall-reset-run2.stdout.json`;
- `C:\Temp\final-synced-025-world-wall-reset-run3.stdout.json`.

All three files have SHA-256
`1BD963D93B8266A2E2BAB4A711C049B8F8883335D6C80C9E2AC9F9CDE6461FD0`
and were recorded against Studio
`597f195a-a442-457a-8e13-6627c44e58bf`.

### Focus-Independent Tests At `20ceda4`

Commit `20ceda4a0f12751bcdb75794de0adccbd8dc68af` changes only the
camera/motion automation flows. It removes render-focus races without changing
gameplay implementation:

- smooth-camera sampling uses the existing bounded Studio camera sampler after
  settling prior Play state and restoring the default viewport, while retaining
  no-snap, distance, angle, visibility, geometry-clear, camera type, and camera
  mode assertions;
- device coverage explicitly settles each desktop, tablet, and phone Play/Edit
  transition and restores the default viewport;
- character-motion coverage uses `PunchMotionPhase` state changes and
  `PostSimulation` sampling with a three-second deadline, and verifies visible
  hand displacement through windup, contact, and recovery;
- reduced-motion coverage still requires the punch action while suppressing
  camera follow.

| Flow | Result | Studio | Artifact(s) | SHA-256 |
| --- | --- | --- | --- | --- |
| `punch-camera-smooth-follow` | 3 consecutive runs, 10/10 each | `c0b2fe28-e907-428f-bf4e-d489f293e6e9` | `C:\Temp\camera-preflight-final-punch-camera-smooth-follow-run1.stdout.json`, `run2`, `run3` | `D76F36D17190482CDB4E61B46302079D59CF073425F0DB63616FDD073B67A35D` |
| `punch-camera-device-20` | 27/27 | `c0b2fe28-e907-428f-bf4e-d489f293e6e9` | `C:\Temp\camera-preflight-final-punch-camera-device-20-run1.stdout.json` | `B36C7F5BF4768409F9BA5EE3CD919087AA5919963349138F7AF6BCE88C4051D5` |
| `punch-character-motion` | 3 consecutive runs, 11/11 each | `597f195a-a442-457a-8e13-6627c44e58bf` | `C:\Temp\focus-independent-punch-character-motion-run1.stdout.json`, `run2`, `run3` | `8487A92CAD10E782F3B070A1DAD9BA76DCDD73F7041C192A59168829377C4B7E` |
| `punch-action-timing` | 7/7 | `597f195a-a442-457a-8e13-6627c44e58bf` | `C:\Temp\focus-independent-punch-action-timing-run1.stdout.json` | `57A9B233EBC9B5E7B26A5164507DF537BDE8618970A334DE30B7FDC7C8993919` |
| `world-wall-reset` after Animate fix | 3 consecutive runs, 10/10 each | `597f195a-a442-457a-8e13-6627c44e58bf` | `C:\Temp\final-synced-025-world-wall-reset-run1.stdout.json`, `run2`, `run3` | `1BD963D93B8266A2E2BAB4A711C049B8F8883335D6C80C9E2AC9F9CDE6461FD0` |

Every result above includes its flow's console-clean gate. These targeted
passes close the two newly observed camera/reset symptoms from the initial
integration suite, but they do not substitute for a complete suite at current
HEAD.

## Final Inventory P2 Hardening At `4616106`

Commit `4616106e81511434c07153f2aa7afeea9bc1b62e` hardens compact-menu
accessibility and transient Inventory UI lifecycle behavior without changing
server authority.

### Lifecycle And Compact-Menu Behavior

- The compact rarity menu is an adaptive, clipped `ScrollingFrame`. The
  supported `SetInventoryRarityMenuOpen` command exercises the same controller
  used by the UI. Runtime coverage verifies all seven rarity actions remain
  available with a minimum 44-pixel target, scrolls to `Premium`, applies the
  filter through the supported action, restores `All`, and closes the menu
  through the supported command.
- Timed boosts use one keyed, cancellable `task.delay` scheduled for the
  earliest expiry. A second-level heartbeat is limited to selected-item detail
  text while that detail is visible; it is not used to rebuild the item grid.
  Resync, hide, and destroy paths invalidate generation-scoped work. The
  multiple-boost fixture uses a short Coin boost and a later Damage boost,
  verifies exactly one expiry-driven rebuild, and verifies that the later
  timer remains armed as `ExpiryDelay` with stable card and connection counts.
- Delete confirmation uses one generation-scoped, cancellable three-second
  expiry task. The first action changes the control to `CONFIRM DELETE` without
  dispatching a delete, then expiry restores `DELETE`. Selection, filter, hide,
  and destroy paths cancel stale confirmation work. The supported single-call
  runtime fixture verifies both the missing first-click dispatch and automatic
  label restoration.

### Static And Targeted Runtime Evidence

| Check | Result |
| --- | --- |
| Inventory runtime cache contract | 16/16 |
| Client runtime performance contract | 19/19 |
| Inventory card-render contract | 16/16 |

The final supported Inventory runtime flow passed 49/49 checks in three
consecutive runs:

| Run | Artifact | SHA-256 |
| --- | --- | --- |
| 1 | `C:\Temp\inventory-final49-menu-run1.stdout.json` | `B3A50B7950B04A8687E235F5F6C706BD6BBC932964979AF4CE6D1AFA1EAB7FBB` |
| 2 | `C:\Temp\inventory-final49-menu-run2.stdout.json` | `B3A50B7950B04A8687E235F5F6C706BD6BBC932964979AF4CE6D1AFA1EAB7FBB` |
| 3 | `C:\Temp\inventory-final49-menu-run3.stdout.json` | `B3A50B7950B04A8687E235F5F6C706BD6BBC932964979AF4CE6D1AFA1EAB7FBB` |

This targeted flow covers the supported adaptive rarity-menu actions, timed
boost expiry scheduling, delete-confirmation expiry, desktop/compact
Inventory behavior, and its console gates. It does not substitute for the
complete 84-flow regression.

### Signature Benchmark At `4616106`

The signature performance contract passed 18/18 at 10,000 iterations. The
measured run was 16.5111 ms total, 0.00165111 ms per call, and 1373.54x the
recorded baseline throughput:

- wrapper artifact:
  `C:\Temp\inventory-final49-performance-contract-10000.stdout.json`;
- wrapper SHA-256:
  `4A1CB45A5042B22BD9F9D88D40997B39C4E5A2CAA1813B2CF88AEE5F2AC6C9E0`;
- benchmark artifact:
  `C:\Temp\inventory-final49-performance-contract-10000-benchmark.json`;
- benchmark SHA-256:
  `D2F16CD89ED84DE13410444DE61D6C55E21B126B17034BA4EEB7BCA92CD6BD4E`.

This is a same-session checkpoint comparison, not a universal cross-machine
performance guarantee. The targeted P2 evidence also does not establish
pixel-perfect identity or release readiness.

## Hidden Compact Timed-Detail Churn Fix At `3759138`

Additional runtime coverage exposed a production P2 issue after the
`4616106` aggregate. In short compact mode, the selected timed boost correctly
reported `ExpiryDelay` and `DetailDescription.Visible=false`, but periodic
authoritative `StatsUpdate` refreshes still changed the hidden selected detail
and advanced `timedDetailUpdates` from 0 to 2 over 2.2 seconds. Grid rebuilds,
live cards, card connections, and expiry rebuilds remained stable.

The retained exploratory artifact is
`C:\Temp\inventory-final51-menu-run1.stdout.json`, with SHA-256
`39F286128BEE6071795901F9E81C74509141ADC6432A811E40EF30D776C1D02A`.
It failed before the new compact assertion label was appended and was not
counted as a successful regression run.

Commit `375913872fff9cb351b0d2ca550ba9d55f74ce23` keeps the complete
timed-item expiry and next-expiry scan, but the only periodic
`_updateTimedItemDetail` call inside `_refreshTimedItems` is now gated by all
three conditions:

- the timed item is the selected item;
- the detail pane is visible;
- the detail description is visible.

The single expiry scheduler and expiry-driven snapshot rebuild are unchanged.
Server-authoritative ownership, boost timing, actions, and state mutation
paths are unchanged. A structural contract asserts that the only periodic
detail mutation inside `_refreshTimedItems` is enclosed by the three guards.

The first version of the desktop runtime assertion required two scheduler
ticks inside a fixed 2.2-second window. Two runs passed, while one retained
diagnostic run failed at the new desktop step because the threshold depended
on the scheduler's second boundary:
`C:\Temp\inventory-final51-menu-pass-run3.stdout.json`, SHA-256
`77AB5C9780392ACD48A1D31F670502576AEDE052C0DF846BF0C092B5A6AFAB17`.
The assertion was made deterministic with a bounded three-second poll that
still requires a visible targeted update, changed countdown text, heartbeat
mode, and unchanged grid/card/connection counters.

Final targeted evidence:

| Check | Result |
| --- | --- |
| Inventory card-render contract | 17/17 |
| Inventory runtime cache contract | 16/16 |
| Client runtime performance contract | 19/19 |
| Signature performance contract | 18/18 at 10,000 iterations |
| `punchwall-smoke` | 12/12 |

The final Inventory flow contains 51 unique labels and no cross-context
`shared` state. Three fresh consecutive runs passed 51/51:

| Run | Artifact | SHA-256 |
| --- | --- | --- |
| 1 | `C:\Temp\inventory-final51-menu-stable-run1.stdout.json` | `64F37632B20F6CEF47205ACAA34E508B244C2B9393EB8D63ABABE2BE340A6166` |
| 2 | `C:\Temp\inventory-final51-menu-stable-run2.stdout.json` | `64F37632B20F6CEF47205ACAA34E508B244C2B9393EB8D63ABABE2BE340A6166` |
| 3 | `C:\Temp\inventory-final51-menu-stable-run3.stdout.json` | `64F37632B20F6CEF47205ACAA34E508B244C2B9393EB8D63ABABE2BE340A6166` |

Each run passed desktop and compact console-clean checks and restored the
default viewport. The smoke artifact is
`C:\Temp\inventory-final51-punchwall-smoke.stdout.json`, SHA-256
`98486B39832536F7F3F33E74BF65A102B607FAF0AA6452053C0DD82D518469A1`.
An independent final review reported no P0, P1, or P2 finding in the scoped
production and regression diff.

## Complete Existing-Flow Regression

The recorded baseline at `2baaae84b7cf7662624a8e388ad3a569d8b0e006`
was 63 PASS / 21 FAIL across 84 flows. The first complete integration run
recorded 61 PASS / 23 FAIL across the same 84 flows:

- artifact:
  `C:\Temp\inventory-full-regression-20260718-201513.stdout.json`;
- SHA-256:
  `A3F175F98A4497C23C86D81B12D2104626111D861650494329ED595F534E60C5`;
- `inventory-menu-ui`: PASS, 40/40 checks.

The 21 failures already present in the recorded baseline were:

- `ai-material-assets`;
- `camera-tunnel-zoom-preservation`;
- `destruction-boss-phases`;
- `fist-items-icon-ui`;
- `hero-city-design-alignment`;
- `hero-city-reference-ui`;
- `hero-city-theme`;
- `hero-shop-reference-polish`;
- `iteration01-complete-polish`;
- `iteration02-companion-tasks-boss`;
- `iteration03-safearea-destruction`;
- `iteration04-armory-pets-feedback`;
- `iteration05-final-depth-motion`;
- `power-scaled-penetration`;
- `punchwall-free-aim-combat-polish`;
- `punchwall-map-progression`;
- `punchwall-motion-feedback`;
- `punchwall-radius-damage-shake`;
- `punchwall-shared-excavation-field`;
- `punchwall-visual-polish-smoke`;
- `reduced-motion-performance`.

The two newly observed failures relative to that recorded baseline were:

- `punch-camera-smooth-follow`: `geometryClear=false`, 18 inside frames,
  sampled maximum step `2.400001764`, and internal maximum step
  `2.400001526`; other no-snap, visibility, angle, and distance checks were
  true;
- `world-wall-reset`: functional reset checks passed, but the console gate
  detected the default `Animate:WaitForChild("PlayEmote")` infinite-yield
  warning at line 939.

The targeted evidence above demonstrates that both symptoms were addressed at
`6c67172`/`20ceda4`.

### Completed Aggregate And Targeted Reruns At `20ceda4`

The completed 84-flow rerun at
`20ceda4a0f12751bcdb75794de0adccbd8dc68af` recorded 61 PASS / 23 FAIL:

- artifact:
  `C:\Temp\inventory-final-full-regression-20ceda4-20260719-013545.stdout.json`;
- SHA-256:
  `94B0E63D51DE31789A89241894BC1C99662620100409128BD04838FB4317B7E3`.

The previously observed `punch-camera-smooth-follow` and `world-wall-reset`
failures were absent from this aggregate. The remaining 21 failures matched
the recorded baseline list above. The two additional aggregate failures were
then rerun individually at the same checkpoint:

| Flow | Targeted result | Artifact | SHA-256 |
| --- | --- | --- | --- |
| `camera-teleport-scriptable-visibility` | PASS, 12/12 including console-clean gate | `C:\Temp\inventory-final-targeted-camera-teleport-scriptable-visibility-20ceda4.stdout.json` | `AD6432EE057B44EE80B817BD58699EBDE0B498B0D702A500B6B68B9B186C9F93` |
| `release-expansion-economy` | PASS, 10/10 including console-clean gate | `C:\Temp\inventory-final-targeted-release-expansion-economy-20ceda4.stdout.json` | `8418B4CFCB217AE8D2FA07A4819BEE8E2352AFDD1671752E910B3968ACE2BC31` |

These targeted reruns do not retroactively change the recorded 61/23
aggregate. They establish that neither additional failure reproduced in its
targeted flow at `20ceda4`. The later complete aggregate at `4616106` is
recorded below.

### Final Complete-Suite Result At `4616106`

The frozen 84-flow regression at
`4616106e81511434c07153f2aa7afeea9bc1b62e` completed with 63 PASS / 21 FAIL:

- artifact:
  `C:\Temp\inventory-final-full-regression-4616106-20260719-033253.stdout.json`;
- size: 53,553 bytes;
- SHA-256:
  `DD5E7163FA54E497EA5ED7CC31811532DAB2B36F70159362D48EBB49AD169A0B`;
- stderr: 0 bytes;
- `inventory-menu-ui`: PASS, 49/49 checks.

The failed set exactly matches the 21-flow recorded baseline list above.
There were no new non-baseline failures and no baseline recoveries. Compared
with the earlier `20ceda4` aggregate, the result improved from 61/23 to 63/21:
`camera-teleport-scriptable-visibility` and
`release-expansion-economy` both passed in the aggregate, consistent with
their earlier targeted reruns. No additional targeted rerun was required.

Cleanup verification left Studio in Edit mode on
`PunchWallRPGPlayable_v1_final.rbxlx`, restored the default device, and left
the custom-device list empty.

### Final Complete-Suite Result At `3759138`

The frozen 84-flow regression at
`375913872fff9cb351b0d2ca550ba9d55f74ce23` completed with 62 PASS / 22 FAIL:

- artifact:
  `C:\Temp\inventory-final-full-regression-3759138-20260719-050947.stdout.json`;
- size: 56,108 bytes;
- SHA-256:
  `699A5D3F0DCD0BF8B6417FCE02A6E1050A6FFEAFDFD769D78784A5434EF14FE0`;
- stderr: 0 bytes;
- `inventory-menu-ui`: PASS, 51/51 checks.

The 21 recorded-baseline failures remained. The only additional aggregate
failure was `punch-camera-device-20`; the aggregate tablet sample reported
`initialOrbitSettled=false` and `visualValid=false` while retaining
`inside=0`, `visibleRatio=1`, and `settledReadableRatio=1`.

Three clean targeted diagnostic repetitions were retained and did not pass:

| Run | Failed sample | Artifact | SHA-256 |
| --- | --- | --- | --- |
| 1 | Phone; `readableRatio=0.7976`, `inside=0`, `visibleRatio=1`, `maxBack=0.9706` | `C:\Temp\inventory-final-punch-camera-device-20-rerun-3759138-20260719-060201.stdout.json` | `8BCD5E3FD171E97E93E23E70AAFC5EE5C75C32590C2190A3E8F70593307CB311` |
| 2 | Desktop; `readableRatio=1`, `inside=0`, `visibleRatio=1`, `maxBack=1.1873` | `C:\Temp\inventory-final-punch-camera-device-20-rerun2-3759138-20260719-060726.stdout.json` | `C8FEC8A264F40A9BB5B90D7B9550571B489E9C9C576FCBB30584E92CB288AD02` |
| 3 | Phone; `readableRatio=0.9639`, `inside=0`, `visibleRatio=1`, `maxBack=3.0655` | `C:\Temp\inventory-final-punch-camera-device-20-rerun3-3759138-20260719-061011.stdout.json` | `45153DAFF2D6736B9D51DAA191344D95D490ECA64F5489F9E5193FAD709282E7` |

The camera flow and camera implementation are unchanged between `20ceda4`
and `3759138`; the post-`4616106` production diff is confined to Inventory
timed-detail mutation. The failing device and predicate varied across the
aggregate and targeted runs. The evidence therefore classifies this as a
known P2 camera test/sequence/physics-sampling instability rather than an
Inventory-caused production regression. It is not counted as a pass and keeps
the repository release gate open. Recommended follow-up is test-only
hardening that waits for several stable orbit/root samples before measuring
and reports each camera predicate independently without weakening thresholds.
Final cleanup left Studio in Edit mode, restored the default device, and left
the custom-device list empty.

## Release Gate Status

| Gate | Status | Evidence / remaining action |
| --- | --- | --- |
| Commit traceability | PASS | Baseline, optimization, harness, runtime fix, and focus-independent test commits are identified above |
| Inventory performance and bounded instances | PASS AT CHECKPOINT | Measured at `e7bd9bb`; single-session results do not establish a cross-machine statistical guarantee |
| Reference-style desktop and compact UI | PASS AT CHECKPOINT | Studio visual/runtime geometry checks at `e7bd9bb`; capture names are labels only, not exported files |
| Dedicated Inventory HUD action and authority boundaries | PASS TARGETED | `inventory-menu-ui` 40/40 at `06b40ca`, 49/49 at `4616106`, and 51/51 in three fresh consecutive runs at `3759138`; Shop behavior retained |
| Final Inventory P2 lifecycle hardening | PASS TARGETED | Static contracts 17/17, 16/16, and 19/19; adaptive menu, one expiry scheduler, visible-detail mutation gate, and confirmation expiry are covered at `3759138` |
| Default Animate bootstrap and wall reset | PASS TARGETED | Three 10/10 runs after `6c67172` |
| Camera, device, character motion, and action timing | MIXED / OPEN | Smooth camera, character motion, and action timing passed the listed targeted gates; the final camera-device flow remains open because of the device-varying instability recorded above |
| Complete 84-flow suite at `20ceda4` | COMPLETE WITH FAILURES | 61 PASS / 23 FAIL; the 21 recorded-baseline failures remained, and both additional failures passed their targeted reruns |
| Physical mouse injection | UNAVAILABLE | Studio MCP lacks `RobloxScript` capability; Windows helper returned `No such interface supported` |
| Script memory | UNAVAILABLE | This Studio build does not expose `STUDIOPLAT37936` |
| Complete 84-flow suite at `4616106` | COMPLETE WITH BASELINE FAILURES | 63 PASS / 21 FAIL; the failure set exactly matches the recorded baseline, with no new non-baseline failure |
| Complete 84-flow suite at `3759138` | COMPLETE WITH FAILURES | 62 PASS / 22 FAIL; baseline 21 plus one repeatable but device-varying camera test/sequence instability; Inventory passed 51/51 |
| Rebuilt release `.rbxlx` from `3759138` | NOT RUN / PENDING | The earlier `final-rbxlx-build-validation` pass predates the final timed-detail fix; rebuild and validate `outputs/PunchWallRPGPlayable_v1_final.rbxlx` |
| Overall release | **NOT READY** | Requires camera-device test hardening/triage, the recorded baseline failures to be repaired or explicitly re-baselined, and a rebuilt current-HEAD release artifact |

The measured Inventory acceptance is satisfied at its named checkpoints, and
there is no known in-scope Inventory defect in the final targeted evidence.
The camera-device instability and recorded baseline failures remain explicit
repository-wide limitations. This does not claim bug-free software,
statistical certainty, absolute 100% pixel identity, or release readiness.
Expected unpublished-place DataStore and `DevCameraOcclusionMode` permission
warnings remain documented limitations; any new game error must fail the
applicable console gate.
