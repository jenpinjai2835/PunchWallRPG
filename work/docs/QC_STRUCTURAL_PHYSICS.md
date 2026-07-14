# Structural Physics QC

## Acceptance behavior

- Intact depth blocks remain anchored and collidable when a character overlaps
  them. The overlap watchdog never opens a path by dropping an intact wall.
- Only blocks already marked as structural-detached, structural-falling, or
  structural-failure are eligible for overlap recovery.
- A detached block that overlaps a character shatters into debris. The server
  leaves the character's CFrame and velocity unchanged.
- Detached blocks remain visible, collidable, queryable, and punchable after
  they settle. They do not disappear on a timer.
- A settled block is moved to the `DepthRubble` collision group and the server
  watchdog applies gravity when it has no support, preventing floating rubble.
- Punching a settled block applies a server impulse and angular impulse. The
  block is removed only after its HP reaches zero from a later punch.

## Automated flows

```powershell
node "C:\Users\Jennarong Pinjai\.codex\skills\roblox-studio-mcp-automation\scripts\flow_runner.mjs" --flow "F:\Roblox\PuchWall\work\automation\flows\structural-overlap-ejection.json"
node "C:\Users\Jennarong Pinjai\.codex\skills\roblox-studio-mcp-automation\scripts\flow_runner.mjs" --flow "F:\Roblox\PuchWall\work\automation\flows\structural-rubble-solidity.json"
node "C:\Users\Jennarong Pinjai\.codex\skills\roblox-studio-mcp-automation\scripts\flow_runner.mjs" --flow "F:\Roblox\PuchWall\work\automation\flows\structural-character-clearance.json"
node "C:\Users\Jennarong Pinjai\.codex\skills\roblox-studio-mcp-automation\scripts\flow_runner.mjs" --flow "F:\Roblox\PuchWall\work\automation\flows\punchwall-hybrid-physics-lunge.json"
```

All four flows passed after the final source sync. Console assertions were
clean in each flow.
