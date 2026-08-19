# Pet Egg Drop and Normal Pet Visual QC — 2026-08-18

## Scope

- Replace direct wall-break pet grants with a server-owned egg pickup on the ground.
- Keep the reward hidden until the owning player claims the egg.
- Balance pickup arming, expiry, spawn cooldown, pity preservation, and one-active-drop limits.
- Increase the eligible normal-pet pool with wall depth.
- Use sanitized, item-matched Creator Store visuals only when they improve the real player view.

## Integrated Balance

| Setting | Value |
| --- | ---: |
| Egg lifetime | 24 seconds |
| Pickup arming delay | 0.65 seconds |
| Prompt distance | 14 studs |
| Per-player spawn cooldown | 8 seconds |
| Active eggs per player | 1 |
| Pity threshold | 45 eligible wall breaks |

Depth eligibility is server-authoritative: Forest Pup starts at depth 1, Miner Cat at 12,
Crystal Fox at 28, Lava Dragon at 44, and Secret Titan Golem at 62. Existing weighted
rarity selection still applies inside the eligible pool.

## Automated Evidence

Tested against exact Studio instance `6d29b2d4-41ab-41fb-838f-3dfd8727c725`, place
`PunchWallRPG_ManualPlaytest_20260818_FistAuraV10.rbxlx`.

| Check | Result |
| --- | --- |
| `pet-egg-world-pickup.json` | PASS — landed owner egg, arming rejection, single claim, cooldown/pity, depth pool, inventory-full recovery, 24-second expiry, clean console |
| `normal-pet-visual-models.json` | PASS — Miner Cat and Lava Dragon sanitized external visuals; Crystal Fox and Secret Titan Golem species-readable procedural fallbacks; bounded size; clean console |
| `pet-wall-drops-and-fusion.json` | PASS — pending egg, claim, inventory, equip/fusion path |
| `natural-progression.json` | PASS — pickup joins the normal progression and pet multiplier path |
| `studio-test-harness-control.json` | PASS — deterministic egg spawn and claim controls |
| `run-automation-static-contracts.ps1` | PASS — Node 21, PowerShell 18, Luau 27, flow JSON 100, runner 11, infrastructure 25, economy 10, fist 11, persistence 28 |
| Scoped `git diff --check` and JSON parse | PASS |

## Visual Evidence

Real player-view captures are stored in `C:\Temp\PunchWall_PetEgg_QC_20260818\final`:

- `pet-egg-owner-label.jpg`
- `miner-cat.jpg`
- `crystal-fox.jpg`
- `lava-dragon-final2.jpg`
- `secret-titan-golem.jpg`

The Studio screenshot tool did not rasterize BillboardGui/ProximityPrompt chrome in the
capture, so the client runtime was also queried directly. It confirmed the owner-only
billboard text and enabled pickup prompt while the egg was armed.

## Asset Decision

- Accepted: Creator Store `Low Poly Cat` (`7620836278`) and `dragon pet` (`2888641064`),
  visual-only after sanitation and recoloring.
- Rejected after real-view inspection: `Fox model` (`486458049`) and `MY Golem`
  (`8203577865`), because their silhouettes/textures did not match the current item art.
- Forest Pup, Crystal Fox, and Secret Titan Golem retain the project-authored procedural
  visuals. External loading failure changes visuals only and cannot affect reward stats.

## Known Out-of-Scope Finding

The broader `pet-size-position-qc.json` still reports a pre-existing Premium three-pet
screen-overlap threshold miss at camera distance 12 (`maxPairOverlap=0.0816478`,
`minWorldPair=1.37072`). The normal wall-drop pet path and this task's model selection do
not modify Premium formation. This is not counted as a pass and remains separate follow-up
work.
