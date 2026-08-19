# Punch Wall RPG Full-Game Playtest, Fix, and Retest Loop

Date: 2026-07-19  
Integration branch: `codex/feature/inventory-integration`  
Integration owner: Agent 4 / Coordinator

## Requested Outcome

Play the current integrated game from the real Studio runtime, exercise every
reachable player function, review every visible UI, scene, and gameplay model,
record detailed defects and unfinished areas, fix every reproducible in-scope
finding, and repeat independent tester passes until the acceptance gates pass.

This document is the issue register and evidence ledger for that loop. A prior
checkmark or historical screenshot is not accepted as current evidence.

Baseline status: **complete at `fb73c57`**. The three serialized testers have
released Studio in Edit/default-device state, and the implementation phase is
active with exclusive server, Inventory, and automation ownership.

## Risk and Constraints

- Risk: release-level gameplay, economy, UI, map, model, camera, persistence,
  performance, and final-artifact validation.
- Roblox Studio is a serialized shared resource. Only one tester may control it
  at a time.
- `work/punch-wall-rpg/src/` is the gameplay source of truth.
- Player-visible changes require matching recorded-flow coverage.
- Rewards, damage, purchases, save data, and progression remain server
  authoritative.
- Creator Store content remains visual-only and sanitized.
- Live DataStore, analytics ingestion, and real Robux checkout require a
  published test universe and are reported as external gates, never as local
  passes.
- Unrelated working-tree changes must be preserved.

## Acceptance Criteria

The loop may close only when all of the following are true on the same
integrated commit:

1. A fresh player can complete the natural loop:
   `spawn -> train -> break -> upgrade fist -> obtain/equip pet -> Titan -> rebirth`.
2. Every reachable HUD control, menu tab, card action, close/back action,
   gameplay action, and settings toggle has a successful real-input or recorded
   runtime path, plus clear unavailable feedback where applicable.
3. Positive, negative, boundary, gated, insufficient-currency, owned/equipped,
   cooldown, reset, and persistence paths pass.
4. Damage, rewards, purchases, progression, and save mutations are validated by
   the server.
5. Desktop, phone, tablet, and supported console/VR layouts have no blocking
   clipping, overlap, unreadable text, unsafe touch target, or hidden action.
6. The player camera remains readable through training, punch motion, confined
   tunnels, teleports, vertical movement, destruction, and reduced-motion mode.
7. Wall, fist, pet, NPC, portal, boss, rubble, and environment models have
   correct orientation, scale, collision, attachment, silhouette, and material
   identity from the player camera.
8. Scene and runtime profiling show no reproducible leak, runaway effect,
   console error, or material frame-time regression introduced by the fixes.
9. Targeted flows for every changed behavior pass repeatedly, followed by the
   complete affected regression.
10. Studio returns to Edit mode and the Device Simulator returns to `default`.
11. No known reproducible in-scope P0, P1, or P2 defect remains.

## Serialized Tester Order

| Order | Owner | Runtime scope | Dependency |
| ---: | --- | --- | --- |
| 1 | Agent 1 | Functional, economy, progression, interaction, authority | none |
| 2 | Agent 2 | Visual design, world, UI, model, motion, readability | Agent 1 releases Studio |
| 3 | Agent 3 | Device matrix, camera, performance, persistence, regression | Agent 2 releases Studio |
| 4 | Coordinator | Issue triage, implementation ownership, integration, final gates | all tester handoffs |

## Functional Coverage Ledger

| Area | Required runtime paths | Baseline | Post-fix |
| --- | --- | --- | --- |
| Onboarding | loading, spawn facing, first objective, waypoint, collapse/help | PASS automation | Pending |
| Training | current single Power Bag station, enter/exit, offline grant | PASS automation | Pending |
| Punch | forward/up/down, hold, cooldown, lunge, collision, recovery | PASS automation + real mouse/F | Pending |
| Destruction | damage, crit, crack, collapse, rubble, reward, reset, route | PASS automation + real punch authority | Pending |
| Progression | XP/level, gates, depth, rank, district/world transition | PASS automation | Pending |
| Fists | browse, unaffordable, buy, owned, equip, premium prompt, rebirth | PASS core; premium feedback FAIL | Pending |
| Pets | drop/hatch, duplicate, equip, unequip, lock, delete, fusion, premium | FAIL Delete/premium feedback; fresh legacy Fuse PASS | Pending |
| Inventory | open/close, search, filter, select, equip/use, capacity, persistence | FAIL Delete callback; fresh isolated legacy Fuse PASS | Pending |
| Tasks/rewards | quest, daily, playtime, claim, already-claimed, progress | PASS available baseline paths | Pending |
| Boosts/Spin | open, free/cooldown, bonus/product prompt, reward, close | PASS Spin/core shop; product IDs external | Pending |
| Settings | music/SFX, reduced motion, camera shake, UI scale, More | PASS rebuilt Motion toggle in fresh retry; scale contract/coverage gaps remain | Pending |
| Long loop | Titan phases/reward, rebirth fail/success, world reset | PASS automation; rejection feedback FAIL | Pending |
| Input/device | mouse, keyboard, touch, gamepad paths and safe areas | HUD Jump PASS; virtual Space harness gap; Inventory device matrix PASS; generic phone GameMenu FAIL 38 px/truncation | Pending |
| Production | save retry/migration, receipt contracts, final RBXLX | FAIL load/save/receipt/build safety and stale final artifact; published services remain external | Pending |

## Issue Register

Severity contract:

- `P0`: prevents play, corrupts/duplicates state, security/authority defect, or
  makes the release unusable.
- `P1`: breaks a primary function, progression path, or required device.
- `P2`: visible/reproducible quality, model, camera, performance, or resilience
  defect that must be fixed for this accepted scope.
- `P3`: optional enhancement outside the current completion gate.

| ID | Sev | Area | Finding | Reproduction and evidence | Owner/files | State |
| --- | --- | --- | --- | --- | --- | --- |
| REL-001 | P1 | Final artifact | The committed final RBXLX predates the Inventory integration and does not embed `InventoryUI`, `InventoryViewModel`, the runtime-mode marker, or the supplied Inventory icon ID. The prior final-place flow selected the already-synced main Studio when its named validation-copy Studio was absent, so that result did not validate the file on disk. | `outputs/PunchWallRPGPlayable_v1_final.rbxlx`, SHA-256 `1A772E92646C8E35B6EBB852DA92ABAD35851E5A97EC5116C5D3A869FF3643B8`; marker scan on 2026-07-19; aggregate `selectedStudio` mismatch | Build/validation owner; output serialized to Coordinator | Open |
| REL-002 | P1 | Build completeness | The RBXLX embed and production-build scripts know only the six pre-Inventory scripts. If run against the current client, they would embed a client that requires `InventoryUI` without embedding `InventoryUI` or `InventoryViewModel`, producing an incomplete place. | `embed-source-into-rbxlx.ps1` source map and `build-production.ps1` required/embedded lists | Build owner | Open |
| REL-003 | P1 | Client compilation | The integrated client exceeds Luau's 200-local-register limit. Official compilation fails at the Studio test-harness locals under O0, O1, and O2, so green JavaScript/static contracts do not prove that any client feature can start. | `luau-compile.exe --null -O0/-O1/-O2`; failures at `PunchWallClient.client.lua:5081` and `:5089`; 24/27 mapped-source compile cases pass | Client runtime owner | Open |
| QA-001 | P1 | Test infrastructure | Three regression wrappers and the source-sync wrapper resolve paths from `F:\Roblox\PuchWall` instead of their current worktree. An agent can therefore sync or test `develop` files while reporting results for a feature branch. | Static path scan: `run-existing-flows.ps1`, `run-fast-regression.ps1`, `run-video-qc-regression.ps1`, `sync-source-to-studio.ps1`; current testers use explicit integration flow paths as a containment | Automation owner | Open |
| QA-002 | P1 | Artifact validation | `flow_runner.mjs` falls back to the first connected Studio when a flow's requested `studioName` is absent. `final-rbxlx-build-validation` can therefore pass without opening `PunchWallRPGPlayable_v1_final_validation.rbxlx`. | Historical aggregate selected `PunchWallRPGPlayable_v1_final.rbxlx` for the validation-copy flow; wrapper has no selected-name assertion | Automation owner | Open |
| QA-004 | P1 | Worktree-safe build | `embed-source-into-rbxlx.ps1` and `build-production.ps1` hardcode the main checkout as their allowed root/defaults. A feature worktree cannot safely rebuild and validate its own artifact without editing the script or writing into another task's checkout. | Static path and guard inspection on 2026-07-19 | Build/automation owner | Open |
| QA-003 | P1 candidate | Action coverage | Several authoritative player actions have no dedicated real-remote/real-input flow assertion, including premium product prompt, owned fist equip, pet equip/unequip/lock, daily/quest/playtime claim, settings update, and contextual Use. Existing direct automation commands do not prove the same player-facing path. | Static action-to-flow coverage scan; Agent 1 real-input ledger pending | Automation owner | Needs runtime confirmation |
| ECON-001 | P1 | Developer products | `ProcessReceipt` grants the product and immediately returns `PurchaseGranted` without persisting or checking `PurchaseId`. A retry after a server failure between those operations can grant coins, spins, or boosts more than once. | Static server-authority audit at `PunchWallBootstrap.server.lua:4064`; live checkout remains an external gate, but local idempotency is required before release | Server/economy owner | Open |
| ECON-002 | P1 release gate | Commerce configuration | Every premium game-pass/product ID is currently zero. Studio correctly shows unavailable/setup feedback, but no live purchase can complete until real Creator Dashboard IDs are configured and verified in a published test universe. | `GameConfig.lua` premium fist, pet, and developer-product definitions; local negative/setup paths only | Product owner; configuration is external | Open external configuration |
| ECON-003 | P1 | Timed products/rewards | Coin, damage, speed, and training boost expiry timestamps exist only as runtime player attributes. Bought or won time disappears on reconnect because none of the four timestamps is loaded or collected for save. | Attribute writes/reads in the shop, spin, training, reward, and premium-product paths; absent from `collectPlayerData` and `ensureStats` restore | Server/economy owner | Open |
| ECON-004 | P1 | Game-pass durability | Premium callbacks can grant before the profile is fully ready, and access is not reconciled from Marketplace ownership after a crash/rejoin. A successful external purchase can therefore become a lost or partially persisted local grant. | Independent persistence/commerce cross-review of callback, profile-init, and save ordering | Server/economy owner | Open |
| SAVE-001 | P0 | Profile safety | A live `GetAsync` failure falls through to an empty profile. That player can then autosave defaults over an existing profile because load success/failure is not distinguished. | `loadPlayerData` performs one current-store read and returns `{}` after an error; `ensureStats` continues and `savePlayerData` later writes it | Server/persistence owner | Open |
| SAVE-002 | P1 | Shutdown persistence | `savePlayerData` silently returns whenever the same player already has a save in flight. A `PlayerRemoving` or `BindToClose` request racing an autosave can therefore skip the final state, and shutdown does not wait for the in-flight save. | `savingPlayers[player]` early return plus sequential `BindToClose` loop | Server/persistence owner | Open |
| SAVE-003 | P0 | Profile readiness | The session becomes writable before `RPGStats` and `leaderstats` finish initialization. A receipt, remote action, click detector, or premium callback during that yield window can collect missing fields as defaults and overwrite valid progression, or partially mutate gameplay state. | Independent cross-review of Bootstrap profile-ready ordering and every direct authoritative mutator | Server/persistence owner | Open |
| SAVE-004 | P0 | Cross-server fencing | Saves and receipts have no session lease/revision fence. An old server can write stale progression after a newer server, while retaining the durable receipt marker and permanently erasing the receipt's value. | Pure-Luau stale-merge reproduction: newer `100`, stale `10`, result `50`; persistence cross-review | Server/persistence owner | Open |
| SAVE-005 | P1 | Schema/receipt normalization | Malformed authoritative fields can be defaulted and saved instead of failing closed. `ProcessedReceipts.Seen` also accepts mixed array/map shapes but the array branch can discard keyed purchase IDs, allowing a duplicate grant after migration/corruption. | Independent schema and receipt-ledger audit; mixed-shape fixture | Server/persistence owner | Open |
| RUN-001 | P1 | Character animation | Current Play sessions can leave the default `Animate` LocalScript without its `PlayEmote` BindableFunction long enough to produce an infinite-yield warning. The existing client repair waits for `Animate` only once and can miss a late partial bootstrap. | Baseline Pet flow and isolated collision-flow rerun both logged `Workspace.<player>.Animate:WaitForChild("PlayEmote")`; `C:\Temp\functional-full-game-reruns-fb73c57-20260719-065144\04-rerun1-punch-collision-state-restoration.stdout.json` | Client runtime owner | Open |
| RUN-002 | P2 | Console/runtime configuration | Every current Play session logs `Insufficent permissions to set DevCameraOcclusionMode` because the LocalScript attempts to assign a protected player property inside `pcall`. The catch prevents a crash but does not prevent the engine warning. | Current flow console output; assignment at the top of `PunchWallClient.client.lua` | Client runtime owner | Open |
| QA-005 | P2 | Stale flow selector | `iteration04-armory-pets-feedback` deterministically aborts before its assertions because it still selects `Boxing Glove Gauntlet Palm`, a removed Armory fixture. | Both isolated reruns failed at the same selector: `07-rerun1-...stdout.json` and `14-rerun2-...stdout.json` under `C:\Temp\functional-full-game-reruns-fb73c57-20260719-065144` | Automation owner | Open |
| QA-006 | P2 | Play-state harness | Sequential flow startup can report `Server datamodel is not available in Edit mode` after the flow requested Play, making valid gameplay checks sequence-sensitive. | Baseline timing/collision/progression/harness failures and isolated natural-progression rerun 2; clean reruns recover | Automation owner | Open |
| QA-008 | P2 | Automation portability | Flow wrappers hardcode both the current developer's `.codex` runner path and absolute asset/flow output paths. Even after fixing the worktree root, another checkout or Windows profile cannot use the documented commands without editing scripts. | Static scan of PowerShell wrappers and asset builders | Automation owner | Open |
| UI-001 | P1 | Generic mobile menu | Inventory is independently safe at 44 px, but the phone 740 runtime confirms the legacy GameMenu uses six undersized controls on each affected page: `Close=38x38` plus five tabs at `73x38`. Pets, Honor, Tasks, and Settings also show `1/2/1/2` visible text truncations respectively. Fists has 11 buttons at 44 px and no truncation; no page escapes the safe viewport. | Agent 3 phone 740 captures and exact runtime bounds for Fists/Pets/Honor/Tasks/Settings | Client UI owner | Open; confirmed |
| UI-002 | Closed | Inventory responsive layout | Inventory compact Drawer mode remained within the real device safe viewport at 740x360 and 844x390, with three columns, 44 px minimum targets, all text fitting, and no overlap. | `device-performance/agent3-baseline-fb73c57/DEVICE_PERFORMANCE_BASELINE.md` | none | Closed: baseline pass |
| UI-003 | Closed | Settings interaction | The original rapid sequence appeared to leave rebuilt Settings controls stale. In a fresh isolated pass, a real Motion click changed `true -> false`, rebuilt the visible control to `OFF`, and a second real click on that rebuilt instance after 550 ms changed `false -> true` and rebuilt to `ON`. The claimed permanent no-op state did not reproduce. | Agent 3 fresh isolated real-click transition | none | Closed: timing-sensitive tester sequence |
| UI-004 | P1 candidate | Tasks/rewards interaction | An initial Daily/Playtime click appeared to do nothing, but this did not reproduce in the controlled retry: Daily awarded 600 authoritative Coins and changed to `CLAIMED`; not-ready Quest and Playtime correctly stayed `WAIT`. | `work/docs/evidence/full-game-qc/functional_full_game_matrix.md` and `player_tasks_claim_state.png` | none | Closed: not reproduced |
| UI-005 | P2 | UI scale contract | Settings offers and persists 120%, but `InventoryUI:ApplyResponsive` silently clamps its internal scale to 115%. Agent 3's 120% desktop result confirms a 50.6 px target (`44 * 1.15`), so Inventory does not render at the selected scale even though it remains in bounds. | `InventoryUI.lua` scale clamp and Agent 3 desktop 120% diagnostics | Inventory responsive owner | Open |
| INV-001 | P1 | Pet inventory action | `FunctionalInventory/.../DetailActions/ActionDelete` emits `Activated`, but the Inventory UI does not arm confirmation, change its label, or mutate the authoritative pet inventory. `InventoryDeleteConfirmationScheduled` remains false and the last action remains the preceding Unlock. | Seeded real-input baseline at `fb73c57`; exact path and attributes in `work/docs/evidence/full-game-qc/functional_full_game_matrix.md` | Inventory UI owner | Open |
| INV-002 | Closed | Legacy Pets action | The original fusion attempt did not mutate state. A fresh isolated pass scrolled the row into view, waited 450 ms, and clicked the active `FUSE 2` once. Authoritative inventory changed from two `Crystal Fox` entries to exactly `["Crystal Fox#2"]`, equipped the result, set multiplier `1.4875`, and emitted `PetFusion/Crystal Fox#2`. | Agent 3 fresh isolated real-click transition | none | Closed: prior timing/visibility-sensitive attempt |
| INPUT-001 | Closed product / QA gap | Jump | Fresh isolated state proved the character was unanchored, healthy, Running on Slate, not seated or PlatformStand, with `UseJumpPower=true`, `JumpPower=50`, and `JumpHeight=7.2`. Internal jump and a real HUD ActionJump click each rose `7.2663` studs and traversed Jumping -> Freefall -> Landed -> Running. Studio `user_keyboard_input` reported success but generated no client `InputBegan` in two controlled attempts, so Space remains a harness-delivery gap rather than a reproduced game failure. | Agent 3 fresh-session transition baseline | Automation/input test owner | Product candidate closed; keyboard harness coverage open |
| UX-001 | P2 | Rebirth feedback | A real click on the gated Rebirth action correctly preserves zero rebirths and shows the static requirement, but produces no dynamic denial toast/feedback. | Controlled real-input baseline at `fb73c57`; `work/docs/evidence/full-game-qc/functional_full_game_matrix.md` | Client/server feedback owner | Open |
| UX-002 | External/local coverage | Premium branch | The current authored unpublished-Studio contract has `StudioTestGrantPremium=true`; a settled visible premium-pet click correctly grants Crimson Phoenix and emits grant telemetry. The bootstrap caches that configuration, so mutating a separately required table cannot truthfully exercise the unavailable `PremiumSetup` branch in the same session. Live prompting/receipt remains a published-universe gate; missing visible local feedback is tracked independently by `UX-003`. | Agent 3 fresh premium action and configuration-cache probe | Product configuration/test owner | Studio grant pass; unavailable/live branch external |
| UX-003 | P1 | Feedback visibility | `toastHolder` and `rewardHolder` are created with `Visible=false` and no code ever makes either holder visible when children are added. Server feedback can increment telemetry and construct toast/reward children while every child remains visually suppressed; the default non-center branch also omits `Fail` from its toast routing. | Static lifecycle audit at `PunchWallClient.client.lua:1254-1283,1488-1753`, plus missing feedback in real-input baseline | Client feedback owner | Open |
| QA-009 | P2 | Real-input harness | UI Scale controls named `Scale0.8` and `Scale1.2` cannot be addressed by the current instance-path parser, and the coordinate fallback did not change selection. The 80%/120% real-click paths therefore remain unproven rather than passed. | Agent 1 real-input baseline; exact gap recorded in `functional_full_game_matrix.md` | Automation owner | Open |
| CAM-002 | P1 candidate | Camera/clearance | Runtime config uses `DevCameraOcclusionMode.Zoom` while the camera QC contract describes Invisicam; deep tunnel, teleport, rubble, and 20-punch evidence must determine whether this is an accepted behavior or a visibility defect. | Source/config mismatch plus historical sequence-sensitive camera flow; current runtime evidence pending | Client camera owner | Needs runtime confirmation |
| ART-001 | P1 visual | Inventory fidelity | The real Inventory opens correctly and the Inventory icon aligns with Shop, but runtime reports `ArtMode=NativeFallback`. Chrome density, right-detail composition, card finish, spacing, typography hierarchy, and visual depth remain materially simpler than the supplied reference; this is not near-100% parity. | `work/docs/evidence/full-game-qc/visual/12_inventory_real_click_player_view.jpg` and `runtime_diagnostics.json` | Inventory UI/art owner | Open |
| ART-002 | P1 | Character/fist model | Starter R15 hides the entire `RightHand` (`Transparency=1`) and produces a rough/disconnected wrist transition. R6 likewise has an unclean sleeve/arm-to-gauntlet transition. Higher tiers often dominate the face/torso in active pose; scale fixes must use exact bounds and clean idle frames because some authored matrix frames retain a preceding animation phase. | Clean R15/R6 front/side captures, all tier matrices, and exact bounds in `work/docs/evidence/full-game-qc/visual/runtime_diagnostics.json` | Client/fist visual owner | Open |
| ART-010 | P1 safety | Imported visual sanitization | The fist and pet import paths use incomplete blacklists, then trust a missing/false-open sanitization attestation and weld or follow surviving content near the player. Audio, bindables, animation actors, constraints, forces, and other behavior-capable descendants can survive despite a `SanitizedVisualOnly` label. | Independent source cross-review of `FistVisualBuilder.lua:89-115` and client clone/use paths around `PunchWallClient.client.lua:2987-3008,3291,3427-3452` | Client/model visual owner | Open |
| ART-003 | P1 | Pet model/motion | Three premium pets obscure the avatar and play corridor at idle/follow and after teleport. Storm Wyvern bounds are `13.583 x 2.55 x 8.701` while its target is only about `4.35` studs from the root; the target formation itself is camera-unsafe. Base pets also use near-identical low-detail sphere silhouettes. | `visual/09_premium_pets_three_idle_player_view.jpg` through `11_premium_pets_post_teleport_player_view.jpg`, plus `08`, `21`, `22` | Client/pet visual owner | Open |
| CAM-001 | P1 | Real player camera | The normal and reduced-motion paths both keep all three premium pets inside the center gameplay projection. In a fresh real-player camera pass, Storm Wyvern alone covered `87,316 px²` with motion on and `85,215 px²` with motion off; Crimson Phoenix covered about `22k px²`. Slot three is authored at center X and forward local Z, while the screen-area budget only records telemetry and does not reposition, rescale, or cull. Depth-entry and cleared-corridor cameras themselves remained `Custom`, `12.551` studs from the avatar, outside geometry, with zero obscurers. | Agent 3 captures `agent3_realplayer_premium3_normal` and `agent3_realplayer_premium3_reduced`; device/performance baseline camera diagnostics; client source cross-review | Client pet/camera owner | Open |
| ART-004 | P2 | VFX/readability | Impact, debris, and recovery effects work and remain visible, but rubble, pets, the tutorial waypoint/toast, and HUD layers crowd the center during active punching. Reduced Motion still executes full joint punch transforms, trails, and debris/coin travel despite its UI promise, so visual parity is not satisfied. | `visual/21_depth_impact_vfx_real_input_player_view.jpg`, `22_depth_recovery_real_input_player_view.jpg`, fist punch/recovery matrices; client source cross-review | Client/server visual owner | Open |
| ART-005 | P2 | Inventory layer pipeline | The previous 19-piece kit is opaque RGB and unusable. A replacement V2 atlas plus eight cropped chrome components has now been generated in this worktree, converted to RGBA, and validated with transparent corners. Runtime integration remains gated by project-owned Roblox image uploads; native reference chrome must remain the functional fallback until those IDs are rendered in Studio. | `work/assets/generated/inventory-ui-reference-v2/README.md`; selected alpha atlas SHA-256 `F3C5C1C84061F04FB67523DF6000A226A10673A95C01F1DB402F4B4C768BB9E5` | Inventory art/asset owner plus external upload | Local asset replacement complete; runtime upload/integration open |
| ART-006 | P1 visual | World cohesion | World 1 combines low-detail green planes, large plain boundary masses, low-poly imported trees, flat signs, scattered primitive props, and a high-gloss Hero City HUD. The world and UI do not share a finished visual language. Runtime proves the weak tree silhouettes are the active imported asset (44 `CreatorStoreTemplateUsed=true`), not a procedural fallback. | `visual/01_spawn_player_view.jpg`, `03_armory_petlab_player_view.jpg`, `05_world1_forest_overview.jpg`, `runtime_diagnostics.json` | World visual owner | Open |
| ART-007 | P1 visual | HUD layering | Objective, Daily Breaker, tutorial waypoint/toast, large world labels, depth bar, right navigation, and action controls compete for the same screen space. Captions merge or occlude each other at the default viewport. | `visual/01_spawn_player_view.jpg`, `02_training_camp_player_view.jpg`, `04_honor_rebirth_player_view.jpg` | Client HUD/world-sign owner | Open |
| ART-008 | P1 visual | Depth readability | The intact course reads as an opaque wall; long diagnostic angles are swallowed by solid block/material planes. Once opened, the confined tunnel is repetitive and dominated by large material surfaces. A fresh real-player-camera pass is still required to separate scene design from camera behavior. | `visual/06_depth_corridor_entry.jpg`, `07_depth_corridor_long_read.jpg`, `21_depth_impact_vfx_real_input_player_view.jpg` | World/camera owner | Open |
| ART-009 | P1 visual | Titan destination | Titan HQ remains a dark, flat prototype dominated by black mass, hard red glowing rectangles, and a pasted city image. It lacks readable building depth, boss identity, and final-destination focal hierarchy. | `visual/23_titan_hq_authored_overview.jpg` | World/boss visual owner | Open |
| QA-010 | P2 candidate | CoreGui lifecycle | The People list appeared after Spin close plus teleport/training although the visual tester did not intentionally open it. Studio Assistant VirtualInput also struck CoreGui, and permanently bound `Tab` could not be controlled, so this is classified as a harness-leak candidate rather than a confirmed modal-close defect until a native reproduction succeeds. | `visual/20_training_motion_real_input_player_view.jpg` and `visual/studio_console_exact.txt` | Client runtime/automation owner | Needs native confirmation |
| QA-011 | P2 | Keyboard input harness | Studio `user_keyboard_input` returned success for Space in two fresh targeted attempts but the client observed no `UserInputService.InputBegan`. The same grounded character jumps correctly through the HUD and internal request path, so the tool cannot currently certify the physical Space path. | Agent 3 fresh isolated input probes | Automation owner | Open coverage gap |
| HUD-001 | P2 polish | Phone safe-area decoration | On both supported phone orientations the Roblox CoreGui cluster touches or partly overlays the decorative outer edge of the Power card. Text remains readable and controls remain reachable, so this is not a blocking layout failure, but the HUD edge should reserve a clearer inset. | Agent 3 phone HUD captures at 740x360 LandscapeLeft and 844x390 LandscapeRight | Client HUD owner | Open |
| PERF-001 | P2 watch | Runtime memory | Two independent 200-break stress batches returned debris and exact instance/hierarchy counts to baseline. The first batch still reached a `+38.4 MB` memory high-water while the warm second batch added only `+2.7 MB`, consistent with allocator/cache warm-up rather than a retained-instance leak. The post-fix soak must prove the warm plateau remains bounded. | Agent 3 300-frame and 2x200-action profile; device/performance baseline | Performance/test owner | Watch; no retained-instance leak confirmed |
| PERF-002 | P2 | Punch hot path | The same punch transform is evaluated by a spawned ~60 Hz loop plus `PreSimulation` and `Heartbeat`, producing redundant CFrame construction and Motor6D/constraint writes during the hottest player action. | Independent client cross-review around `PunchWallClient.client.lua:3882-3886,4106-4107` | Client runtime owner | Open |

## Baseline Automation Triage

The pre-loop aggregate at commit `3759138` reported `62 PASS / 22 FAIL`.
Each failure must be reclassified using current real-runtime evidence:

- product defect;
- stale expectation after an accepted product change;
- deterministic test defect;
- sequence-sensitive harness defect;
- external release-only gate.

No failed flow may be silently counted as passing.

Current functional evidence:

- `work/docs/evidence/full-game-qc/functional_full_game_matrix.md`
- `work/docs/evidence/full-game-qc/player_tasks_claim_state.png`
- `work/docs/evidence/full-game-qc/studio_console_exact.txt`
- main flow root: `C:\Temp\functional-full-game-fb73c57-20260719-063154`
- targeted rerun root:
  `C:\Temp\functional-full-game-reruns-fb73c57-20260719-065144`

Current visual/model evidence:

- `work/docs/evidence/full-game-qc/visual/visual_baseline_report.md`
- `work/docs/evidence/full-game-qc/visual/runtime_diagnostics.json`
- `work/docs/evidence/full-game-qc/visual/studio_console_exact.txt`
- 23 indexed world/UI/player-camera captures
- complete authored R15 and R6 front/side/punch/recovery matrix for all eight
  fist tiers

The visual pass used real click/input for menus, movement, training, punching,
and Spin. Authored overview/test cameras are explicitly marked in the visual
report and are not treated as player-camera defects by themselves.

Current device/runtime evidence:

- `work/docs/evidence/full-game-qc/device-performance/agent3-baseline-fb73c57/DEVICE_PERFORMANCE_BASELINE.md`
- desktop: 1366x768 and 1920x1080 at 80%, 100%, and 120% UI scale;
- phone: 740x360 LandscapeLeft and 844x390 LandscapeRight;
- tablet: 1024x768 LandscapeLeft.

All Inventory-specific device cases report safe-area containment, no rectangle
overlap, fitting text, and a minimum active target of 44 px. The separate
legacy GameMenu phone pass confirms 38 px tabs/close controls and text
truncation on Pets, Honor, Tasks, and Settings. The fresh depth camera remained
outside geometry with zero obscurers, while a real three-premium-pet pass
independently confirmed center-camera occlusion. Focused 300-frame timing
measured `16.847/18.325/19.405 ms` p50/p95/p99 with no frame over `33.3 ms`; a
second profile after two 200-action stress batches remained
`16.742/18.616/19.471 ms`. Both batches cleaned debris and exact instance
counts back to baseline. Final classification and Studio cleanup remain in
progress.

## Dev Ownership and Integration Order

The source remains frozen until Agent 3 finishes the independent
device/camera/performance baseline. After that handoff, implementation is
serialized at shared-file boundaries:

| Phase | Owner | Exclusive files/scope | Dependency |
| ---: | --- | --- | --- |
| 1 | Agent 1 | profile safety, save queue, receipt idempotency, persisted boosts; `PunchWallBootstrap.server.lua`, new server persistence module, `GameConfig.lua` DataVersion | baseline complete |
| 2 | Agent 2 | Inventory action lifecycle and reference chrome; `InventoryUI.lua` and, only if required, `InventoryViewModel.lua` | Phase 1 freezes shared contract |
| 3 | Agent 2 | client runtime, Settings, feedback, Animate/camera, fist/pet/HUD visuals; exclusive ownership of `PunchWallClient.client.lua` | Phase 2 |
| 4 | Agent 1 | world/forest/depth/Titan presentation; exclusive server handoff plus `ForestVisualBuilder.lua`/`PolishConfig.lua` | Phase 1 server handoff |
| 5 | Agent 3 | worktree-safe build/sync/regression wrappers, stale expectations, and new targeted flows | source contracts frozen |
| 6 | Coordinator | integration review, evidence ledger, final artifact rebuild and exact-file validation | all owners released files |

No second agent may edit `PunchWallBootstrap.server.lua`,
`PunchWallClient.client.lua`, or the same flow file concurrently. Visual-only
changes must preserve gameplay collision, rewards, authority, and the exact
5,400-block depth contract.

Implementation gates include:

- no silent action drop, stale button callback, or synchronous destruction of
  the control currently dispatching `Activated`;
- no default-profile overwrite after ambiguous load, no skipped final save,
  and no duplicate durable developer-product grant for the same `PurchaseId`;
- no new unbounded task, connection, per-item frame listener, particle, or
  debris allocation;
- Inventory/Shop centerline within 4 px, all actions at least 44 px, no clipped
  text or unsafe-area escape at the accepted viewport/scale matrix;
- normal-mode graphics/motion preserved or improved, with reduced-motion paths
  retaining readable feedback;
- world decorations remain visual-only, non-queryable, non-touching, and
  non-colliding unless they are an existing gameplay barrier.

## Validation Rounds

| Round | Integrated commit | Targeted result | Full result | Visual/device result | Decision |
| ---: | --- | --- | --- | --- | --- |
| 0 | `fb73c57` | Real-input functional/device/camera/persistence equivalents complete; confirmed findings recorded above | Historical aggregate `62/84`; a safe current full run is blocked by `QA-002` duplicate-name Studio selection and must not be misreported | Visual/model matrix, phone/tablet/desktop matrix, 300-frame profile, and 2x200-action cleanup complete | Fix required |

## External Publish-Time Gates

These cannot be truthfully closed while the local place has no published test
universe or configured live product IDs:

- live DataStore persistence/retry across real servers;
- analytics ingestion;
- real Robux prompt, purchase, and receipt delivery;
- Creator Dashboard icon, thumbnails, content settings, server configuration,
  and production publication.

Local UI, ownership, prompt, receipt, migration, and deterministic Studio test
contracts remain in scope and must pass.
