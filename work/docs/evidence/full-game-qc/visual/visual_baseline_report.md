# Full-game visual/model baseline

Date: 2026-07-19 (Asia/Bangkok)  
Baseline: `fb73c57`  
Studio: `PunchWallRPGPlayable_v1_final.rbxlx`  
Device: default, custom profiles `[]`  
Final Studio state: Edit  
Source edits: none

## Scope and method

This was a visual/model baseline, not an implementation pass. Runtime state was staged only through the Studio-only automation harness. Menus, movement, training, punching, and Spin were exercised through actual virtualized player input. No source file or Studio DataModel was authored.

Capture types are intentionally separated:

- Player-camera captures: `01`-`04`, `08`-`22`. These use the current `CameraType.Custom` player camera. `08` recovered to the hub before capture and is valid only as a base-pet formation capture, not as depth-course evidence.
- Authored overview cameras: `05`-`07` and `23`. These are composition/occlusion inspection angles and must not be treated as player-camera defects by themselves.
- Authored fist test cameras: all `r15_*` and `r6_*` files. They use fixed front/side cameras around the character. Punch input is real, but the files are not a neutral scale comparison: `front` was captured 350 ms after equip/teleport and some later tiers retained an animator phase from the preceding punch. Exact bounds and clean idle frames are the scale/alignment evidence.

One controlled retry was used after the first punch camera missed the character because punch targeting moved the character along the depth course. The retry followed the runtime root position. No further retry loop was used.

## Outcome

The Inventory button placement passes the requested row alignment: the Inventory and Shop button centers are aligned on the right navigation row, and the runtime Inventory image is `rbxassetid://123409223461276`.

The Inventory opens through a real click and is the closest UI in the current build to the supplied reference. It is not near-100% reference parity yet. Runtime reports `ArtMode=NativeFallback`; the right detail/action composition, chrome density, typography hierarchy, spacing, and item-card finish remain materially simpler than the reference.

The overall visual baseline is not release-ready. Confirmed in-scope visual defects remain in world fidelity, fist/hand integration, premium-pet camera clearance, depth readability, Titan presentation, and HUD layering.

## Confirmed findings

| ID | Severity | Area | Finding | Evidence |
| --- | --- | --- | --- | --- |
| VIS-WORLD-001 | P1 visual | World 1 | The hub mixes low-detail green planes, large plain boundary masses, low-poly trees, scattered flat signs, and glossy high-detail HUD art. The visual language is not cohesive and falls well short of the supplied UI/reference finish. | `01_spawn_player_view.jpg`, `03_armory_petlab_player_view.jpg`, `05_world1_forest_overview.jpg` |
| VIS-WORLD-002 | P2 | Tree identity | The ball/cylinder-like trees are not procedural fallback. Runtime contains 44 outer models with `CreatorStoreTemplateUsed=true`, zero `ProceduralFallback`, and the external/visual tree templates are present. The active imported low-poly asset itself creates the weak silhouette. | `runtime_diagnostics.json`, `05_world1_forest_overview.jpg` |
| VIS-HUD-001 | P1 visual | HUD layering | Objective, Daily Breaker, next-training toast, world labels, player depth bar, right navigation, and action controls compete for the same screen space. Several captions are occluded or visually merge at the default viewport. | `01_spawn_player_view.jpg`, `02_training_camp_player_view.jpg`, `04_honor_rebirth_player_view.jpg` |
| VIS-INVENTORY-001 | P1 visual | Inventory reference parity | Real click opens a functional, readable Inventory, but it uses `NativeFallback`. Compared with the supplied reference, the detail panel is sparse, the chrome and card hierarchy are flatter, and the window does not achieve near-100% visual parity. | `12_inventory_real_click_player_view.jpg`, `runtime_diagnostics.json` |
| VIS-FIST-001 | P1 | R15 fist/skin integration | Starter R15 hides the entire `RightHand` (`Transparency=1`). The fist covers the hand but produces a disconnected/rough wrist silhouette. Bounds are `1.142 x 1.719 x 1.516` versus hand `0.698 x 1.061 x 0.870`; this is a real integration defect, not only a camera angle. | `r15_starter_glove_front.jpg`, `r15_starter_glove_side.jpg`, `runtime_diagnostics.json` |
| VIS-FIST-002 | P1 | R6 fist/skin integration | Runtime R6 switch succeeded and reports `AlignmentStandard=R6Wrist`. Clean side captures show the arm/sleeve entering a large low gauntlet with an unclean wrist transition across base and premium tiers. | `r6_starter_glove_matrix_front.jpg`, `r6_starter_glove_matrix_side.jpg`, all `r6_*_matrix_*.jpg` |
| VIS-FIST-003 | P2 | Fist silhouette consistency | Higher-tier fists are visually much larger and often dominate the face/torso in active pose. Some authored matrix frames retain punch animation, so exact bounds—not cross-frame apparent size—must drive any scale fix. | `r15_titan_gauntlet_matrix_front.jpg`, `r15_crimson_vanguard_fist_matrix_front.jpg`, `r15_*_matrix_*.jpg` |
| VIS-PET-001 | P1 | Premium pet clearance | Three premium pets obscure the avatar and main play corridor at idle and while following. The Storm Wyvern is `13.583 x 2.55 x 8.701` while only about `4.35` studs from the root, so its wing cuts across the entire camera center. | `09_premium_pets_three_idle_player_view.jpg`, `10_premium_pets_follow_player_view.jpg`, `runtime_diagnostics.json` |
| VIS-PET-002 | P1 | Post-teleport formation | After teleport, the Celestial Guardian fills the camera and the group overlaps nearby world signs. The current catch-up rule snaps only above 36 studs; the target formation itself is too close for these imported bounds. | `11_premium_pets_post_teleport_player_view.jpg`, `runtime_diagnostics.json` |
| VIS-DEPTH-001 | P1 visual | Depth-course long read | The intact course reads as an opaque wall, while authored long-read angles are swallowed by solid blocks/material planes. Once opened, the narrow tunnel is highly repetitive and the large material surfaces dominate the camera. | `06_depth_corridor_entry.jpg`, `07_depth_corridor_long_read.jpg`, `21_depth_impact_vfx_real_input_player_view.jpg` |
| VIS-TITAN-001 | P1 visual | Titan destination | The authored front overview is very dark and dominated by flat black mass, hard red glowing rectangles, and a pasted city image. It lacks readable building depth and a polished final-boss focal hierarchy. | `23_titan_hq_authored_overview.jpg` |
| VIS-VFX-001 | P2 | Punch/debris readability | Punching and break debris are visibly active and the opening is readable, but rubble, pets, waypoint/toast copy, and HUD layers crowd the center during action. | `21_depth_impact_vfx_real_input_player_view.jpg`, `22_depth_recovery_real_input_player_view.jpg`, fist punch/recovery matrix files |
| VIS-MODAL-001 | Harness-limited | CoreGui lifecycle | The CoreGui People list appeared after Spin close/teleport/training even though the tester never intentionally sent `Tab`. A controlled `Tab` retry was blocked because VirtualInput cannot process permanently bound CoreGui keys. Console also records VirtualInput pointer hits on CoreGui, so this is a harness-leak candidate, not a confirmed product defect. | `20_training_motion_real_input_player_view.jpg`, `studio_console_exact.txt` |

## Passed observations

- Inventory and Shop are horizontally grouped with aligned visual centers on the right-side navigation.
- Inventory, Shop, Pets, Tasks, Honor, Settings, Fists, and Spin all opened from real click/key input during this session.
- Modal exclusivity held in the observed real-click pass: Inventory closed before Shop; Shop closed before the generic menu; Spin dimmed the world and owned focus.
- Spin visibly changed wheel orientation after the real `SPIN NOW` click (`17` to `18`) and displayed the next-free-spin state.
- R15 and runtime-created R6 both attached every tested fist tier without an anchored/collidable model being observed in the matrix.
- Premium pet templates were external sanitized templates, not procedural premium fallback.
- Runtime camera state at the end of play was `CameraType.Custom`, `DevCameraOcclusionMode.Invisicam`.
- No gameplay script exception was present in the final console snapshot.

## Gaps and limitations

- Reduced-motion visual parity was not re-run in this baseline before Coordinator-requested cleanup. It is not counted as passing.
- The Training screenshot does not prove the complete training animation cycle; the CoreGui overlay contaminated that frame.
- `08_depth_open_tunnel_player_view.jpg` is mislabeled from the attempted depth staging because fall/recovery returned the player to the hub. It is retained as honest evidence and used only for the base-pet formation.
- Authored overview camera occlusion is diagnostic evidence; a camera inside a solid part is not itself a player-camera defect.
- The final console contains an unpublished-place DataStore message, a camera-setting permission message, and Studio Assistant VirtualInput/CoreGui errors. Runtime still reported Invisicam. The VirtualInput errors are test-harness output, not gameplay-code exceptions.

## Evidence index

- World and zones: `01`-`07`, `23`
- Base and premium pets: `08`-`11`
- Real-click menus: `12`-`19`
- Real-input motion/VFX: `20`-`22`
- R15 fist matrix: `r15_*`
- R6 fist matrix: `r6_*`
- Exact diagnostics: `runtime_diagnostics.json`
- Exact final console: `studio_console_exact.txt`

## Handoff

Visual/model baseline is complete and eligible for Coordinator integration/triage. It does not certify release readiness. No known in-scope visual defect listed above was fixed because this assignment explicitly prohibited source edits.
