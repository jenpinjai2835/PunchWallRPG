# Camera Occlusion QC

## Goal

Objects between the camera and the player must stay visually solid. The camera must not fade or hide scenery when the player enters a tight space, and the player-controlled zoom must remain unchanged.

## Implementation

- Keep Roblox `Invisicam` so Roblox does not force the camera to zoom into enclosed spaces.
- Bind a client render step after the camera update.
- Query the parts obscuring the camera and set their `LocalTransparencyModifier` to `0`.
- Do not change gameplay collision, server physics, or the character model.

## Regression Test

Flow: `F:\Roblox\PuchWall\work\automation\flows\camera-tunnel-zoom-preservation.json`

The flow verifies:

- `DevCameraOcclusionMode` remains `Invisicam`.
- Camera type remains `Custom`.
- Tunnel zoom preservation remains enabled.
- A solid test shell remains at `LocalTransparencyModifier = 0`.
- Camera distance remains stable while the shell obscures the character.
- Studio console has no errors.

## Result

Passed in Roblox Studio after source sync. The final `.rbxlx` was rebuilt and re-tested after embedding the source changes.
