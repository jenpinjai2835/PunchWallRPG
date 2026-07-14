# Punch Camera Motion QC

## Target behavior

When the player punches, the server-authoritative character lunge begins first.
The player's existing camera angle and zoom remain untouched. After a short
`0.24` second delay, the local camera follows with a small eased
`Humanoid.CameraOffset` movement and returns to its original offset.

Motion feedback settings disable the camera follow together with punch pose
feedback. The implementation stores state in HUD attributes instead of adding
another large local state table, keeping the Roblox Luau client script below
the local-register limit.

## Automation

```powershell
node "C:\Users\Jennarong Pinjai\.codex\skills\roblox-studio-mcp-automation\scripts\flow_runner.mjs" --flow "F:\Roblox\PuchWall\work\automation\flows\punch-camera-smooth-follow.json"
```

The flow verifies character movement is observed before camera movement, the
follow peak is non-zero, the follow ends cleanly, and the Studio console has no
runtime errors.
