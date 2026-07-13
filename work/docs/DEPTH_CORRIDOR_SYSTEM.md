# Depth Corridor Progression

## Shared Excavation Field - 2026-07-12

- The discrete regular gates were replaced by one solid shared wall volume aligned with the downtown road.
- Field dimensions: 48 studs wide, 12 studs high, and 300 studs deep.
- Structure: 75 depth layers, 12 columns, and 3 rows; 2,700 adjacent `4 x 4 x 4` cubic blocks with no physical gaps.
- Every block owns server-authoritative HP, required Wall Level, material tier, score, coins, XP, and contribution data.
- Punches use a server-authoritative body-direction ray and a 3.25-stud impact radius; block highlights, target locking, and block HP HUD are disabled.
- The directly struck block receives full snapshot damage. Nearby forward-facing blocks receive progressively less damage by surface distance and facing angle, with a maximum of 8 affected blocks per punch.
- A punch snapshots Power, fist, pet, rebirth, mastery, and critical state once, so rewards from an early block cannot increase damage to later blocks in the same attack.
- Blocks that survive a hit visibly recoil and elastically shake for about 0.3 seconds, then return to their exact grid `BaseCFrame`.
- Breaking a block disables its collision/query state, leaves a persistent traversable tunnel, and ejects four replicated physics chunks from the front face toward the open player side.
- Hybrid destruction now keeps four large impact chunks and unsupported wall blocks server-owned (`SetNetworkOwner(nil)`) while each client adds eight non-colliding visual shards locally.
- The localized support solver checks the two rows above a destroyed base. A block with no direct base must have supported bridges on both sides or it becomes an unanchored structural fall.
- Structural physics is capped at 60 simultaneously falling blocks. Detached pieces keep their natural physics position, collision, query state, and 35% material HP after settling; they never return to the grid or disappear on a timer.
- Punching detached rubble before its HP reaches zero launches it again with server-authoritative linear/angular velocity. Only a finishing punch changes it to `Destroyed`, disables collision/query, and replaces it with break chunks.
- A punch winds up for 0.2 seconds, checks forward clearance on the server, lunges up to 10.5 studs without changing facing, then applies radial damage. Obstacles stop the lunge 2.6 studs before contact.
- The field is shared by all players in the server. Damage contributions and rewards are split per block.
- Every eight depth layers advance to a harder tier. Ten tiers use different built-in textures/materials and colors.
- World 1 uses a natural forest environment with grass terrain, 36 trees, 108 canopy clusters, and roadside rock groups; course-side city buildings are not generated.
- Tier 1 uses Forest Stone with 15 HP, allowing the default 15 Power fist to break every starter block in one punch.
- A practical player passage is formed by two vertically adjacent blocks, producing a `4 x 8` stud tunnel.
- Depth now ranges from 1-75; Titan is Depth 76 and requires Depth 75 plus Wall Level 99.
- Breaking walls grants Coins, Score, Wall XP, and progression only. It does not increase Power or Fist Mastery; combat strength comes from training, equipped fists, and pets.
- The Training Area, fist shop, pets, mobile controls, Rank/Score HUD, and player-controlled camera remain active.
- Automation: `punchwall-radius-damage-shake.json` validates radial falloff, body-facing direction, no damage while facing away, multi-hit block vibration, exact position restore, and clean console output.
- Automation: `punchwall-hybrid-physics-lunge.json` validates lunge distance and facing, client-only shards, server network ownership, persistent detached rubble, re-impact motion, finishing destruction, and clean console output.
- Regression: `punchwall-shared-excavation-field.json`, `punchwall-mobile-controls.json`, and `punchwall-rebirth-boss.json` remain passing.

## Long Wall Course Revision - 2026-07-12

- Regular gates are uniformly `28 x 11 x 3.2` studs, approximately two Roblox characters tall.
- Depth 1-10 are spaced every 30 studs from Z `-32` to Z `-302`; Titan is at Z `-340`.
- Removed regular-wall rear building masses, deep roofs, reinforced backplates, overhead checkpoint arches, and pre-existing rubble piles.
- Widened the course to 36 studs and replaced tall corridor boundaries with 1.2-stud roadside curbs.
- Depth markers now sit beside the course so the full line of walls remains visible.
- Moved city buildings that crossed the course to the outer sides while preserving the Training/Shop hub.
- Removed combat auto-focus completely: no Scriptable camera, CFrame steering, or FOV punch tween. The client keeps Roblox `Custom` camera control.

## Player Loop

1. Train Power in the existing Training Area.
2. Enter the corridor and punch Depth 1.
3. Breaking a block awards Coins, Wall XP, Score, and unlocks that Depth without increasing Power.
4. Walk through the destroyed center opening to the next gate.
5. A gate requires both its Wall Level and every previous Depth.
6. Buy stronger fist items, equip pets, train, and return when a gate is too strong.
7. Clear Depth 10 to unlock the Titan encounter at Depth 11.

## Progression Contract

- `Depth`: furthest gate cleared. Persistent and shown in leaderstats/HUD.
- `Score`: cumulative contribution-weighted wall and boss score. Persistent.
- `Rank`: derived from furthest Depth with `GameConfig.RankForDepth`.
- Server placement: sorted by Depth descending, Score descending, then UserId.
- HUD: current placement, named rank, Depth, Score, and server Top 3.
- Gate order: Level requirement is reported first; once met, previous Depth is required.
- Regular gates rebuild after 8 seconds. The root wall and center masonry do not collide while broken, leaving a traversable opening.

## World Layout

- Training/shop/pets/rebirth remain in the existing Hero City hub.
- The run starts at Z `-27` and extends to Z `-450`.
- Titan is at Z `-515`.
- Corridor boundaries, checkpoint pads, structural arches, guide lights, and physical Depth/Level labels make direction and difficulty readable.

## Test Matrix

| Area | Case | Expected |
| --- | --- | --- |
| Layout | Regular gate count | 10 |
| Layout | Gate ordering | Depth increments by 1 and Z moves continuously deeper |
| Layout | Corridor affordance | Floor, two boundaries, 10 arches, 20 guide lights |
| Gate | Under-level attack | `level_gate` with required level |
| Gate | Skip previous depth | `depth_gate` with required depth |
| Break | First gate destroyed | Depth 1, Score 120, wall root non-collidable |
| Break | Destruction shape | Hidden center pieces and visible perimeter pieces coexist |
| Traversal | Move behind broken gate | Character can occupy the deeper side |
| Progression | Second gate destroyed | Depth 2, cumulative Score 620 |
| HUD | Rank sync | `STREET HERO`, Depth 2, Score 620, server list visible |
| Boss | Fresh player | Blocked |
| Boss | Depth 10 and Level 99 | Damage allowed; clear awards Depth 11 and boss score |
| Regression | Training Area | Existing train flow remains passing |
| Regression | Mobile controls | Existing mobile flow remains passing |
| Runtime | Console | No errors during each flow |

## Automation

- New flow: `work/automation/flows/punchwall-depth-corridor.json`
- Updated flows: `punchwall-smoke.json`, `punchwall-rebirth-boss.json`
- Run focused flow:

```powershell
node "C:\Users\Jennarong Pinjai\.codex\skills\roblox-studio-mcp-automation\scripts\flow_runner.mjs" --flow "F:\Roblox\PuchWall\work\automation\flows\punchwall-depth-corridor.json"
```
