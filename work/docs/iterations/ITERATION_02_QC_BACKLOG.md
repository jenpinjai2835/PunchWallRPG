# Iteration 02 - Fresh QC And Backlog

This iteration starts only after Iteration 01 passed its complete automation
matrix and post-reopen gates.

Source under review:

- `F:\Roblox\PuchWall\outputs\PunchWallRPGPlayable_v1_final.rbxlx`
- Baseline SHA-256:
  `95750B661EBBCE80D85E72C8B304AF40427234A342A3AA84900E7B7DB0B1769A`

## Audit Status

Fresh inspection complete against the reopened Iteration 01 deliverable.

Captured views:

- `iteration02_fresh_spawn`
- `iteration02_pet_companion`
- `iteration02_fist_pet`
- `iteration02_wall_target`
- `iteration02_boss_phase`

## Findings

| ID | Priority | Fresh player finding | Required fix | Status |
| --- | --- | --- | --- | --- |
| I02-001 | P1 | The procedural Miner Cat is nearly avatar-sized and reads as large blue spheres/rectangles from normal third-person view. | Reduce companion scale, add face/tail/feet detail, preserve rarity silhouette, and keep it outside the avatar footprint. | Closed |
| I02-002 | P1 | Starter mutation and gauntlet read as a cyan rectangular backpack from behind instead of an intentional kaiju mutation. | Refine the spine orientation, reduce the bright block silhouette, and add a tapered tail/cuff shape. | Closed |
| I02-003 | P1 | Normal wall HUD shows HP but not how many ordinary hits remain, so upgrade impact is still hard to estimate. | Calculate approximate current damage and show estimated hits remaining without exposing server authority. | Closed |
| I02-004 | P1 | Titan Phase 2/3 can launch a shockwave after a hidden ten-second loop; the 1.2-second telegraph is the first warning. | Replicate the next attack timestamp and show a countdown in the boss HUD before the danger-zone pulse. | Closed |
| I02-005 | P1 | Pets tab and DNA Lab reuse generic city presentation and do not visually communicate the five collectible companions. | Generate original GPT Kaiju DNA Lab/companion artwork and integrate it into the Pets tab and lab display. | Closed |
| I02-006 | P2 | The same guardian banner appears on every menu tab, reducing information value and using space without tab-specific context. | Select generated banner art per active tab while preserving the compact mobile height. | Closed |
| I02-007 | P1 | Pet inventory action buttons total slightly more width than their action frame, creating a small clipping risk. | Resize the action region/buttons and add a rarity thumbnail/swatch without reducing touch targets below 44px. | Closed |
| I02-008 | P1 | City Cleanup and Playtime show CLAIM before they are ready; failed claims return silently from the server. | Use WAIT/CLAIM/CLAIMED states, disable unavailable buttons, and send explicit fail feedback when invoked early. | Closed |
| I02-009 | P2 | Boss weak points are visible but the HUD does not explain the damage multiplier or which target was struck. | Add weak-point multiplier guidance and local weak-point hit feedback. | Closed |
| I02-010 | P1 | Pet companions and fist visuals have no dedicated regression around size, position, and inventory action layout. | Record an Iteration 02 flow and update scene/UI budget assertions. | Closed |
| I02-011 | P2 | Post-fix mobile screenshot exposed an unstable tab order (Fists, Pets, Settings, Tasks) because all menu tabs shared the default layout order. | Give each tab an explicit layout order and assert the left-to-right sequence. | Closed |

## External Release Findings

- Published DataStore/Analytics and real-device profiling remain external.
- Creator Dashboard icon/thumbnail publication remains external; generated
  sources are retained for that later step.

## Fix Status

All eleven locally actionable findings were implemented, including the tab-order
issue discovered during post-fix mobile screenshot review.

## AI Graphic Deliverables

Built-in GPT image generation produced an original wide Kaiju DNA laboratory
scene with five collectible companion silhouettes and no third-party marks or
text.

Workspace files:

- `work/assets/generated/iteration-02/kaiju-dna-companions-master.png`
- `work/assets/generated/iteration-02/kaiju-dna-menu-banner.png`
- `work/assets/generated/iteration-02/kaiju-dna-lab-billboard.png`
- `work/assets/generated/iteration-02/kaiju-dna-pet-icon.png`

Uploaded Roblox assets:

- DNA Lab/menu banner: `rbxassetid://80764015986038`
- Pet inventory icon: `rbxassetid://114585325653299`

## Re-QC Evidence

Post-fix player and staged views:

- `iteration02_after_pets_menu`
- `iteration02_reqc_companion_dna`
- `iteration02_reqc_dna_lab_graphic`
- `iteration02_reqc_pets_menu`
- `iteration02_reqc_titan_countdown`

Acceptance:

- Iteration-specific flow `iteration02-companion-tasks-boss`: passed all 22
  recorded checks.
- Complete automation matrix: 19/19 flows passed in 286.6 seconds.
- Runtime console assertions: clean.
- Runtime core BaseParts: 1,417.
- Companion procedural maximum dimension: 1.9 studs, with two eyes, four feet,
  and one tail.
- Pet inventory controls remain inside the action frame with 44px touch height.
- Titan Phase 2 exposes a replicated shockwave countdown and weak-point x1.5
  guidance.
- Saved final was closed, reopened, and passed the iteration flow plus smoke
  flow from the serialized file.

Finalized deliverable:

- Iteration snapshot:
  `F:\Roblox\PuchWall\outputs\iterations\PunchWallRPG_iteration02.rbxl`
- Current final:
  `F:\Roblox\PuchWall\outputs\PunchWallRPGPlayable_v1_final.rbxlx`
- Size: `1396219` bytes
- SHA-256:
  `F2282C79930274105EF3FCDF9B9118E14BF8A037508DF858383ECB04800A746B`
