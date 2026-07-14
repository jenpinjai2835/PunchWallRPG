# Camera Occlusion QC

## Goal

Objects between the camera and the player must stay visually solid. The camera must not fade or hide scenery when the player enters a tight space, and the player-controlled zoom must remain unchanged.

## Implementation

- Keep Roblox `Invisicam` so Roblox does not force the camera to zoom into enclosed spaces.
- Bind a client render step at the final render priority so it runs after Roblox's built-in occlusion pass.
- Query the parts obscuring the camera against the camera focus, head, root, and torso points.
- Set every returned part's `LocalTransparencyModifier` to `0` so scenery stays fully opaque.
- Do not change gameplay collision, server physics, or the character model.

## Punch Camera Motion

During the punch wind-up and lunge, the camera temporarily switches to `Scriptable`:

- Hold the camera at its pre-punch transform while the character starts moving.
- Interpolate the camera position toward the character's actual displacement.
- Restore the original camera type and subject after the follow window.

Flow: `F:\Roblox\PuchWall\work\automation\flows\punch-camera-smooth-follow.json`

The flow verifies the character moves during the punch, the camera is held during the opening window, the camera follows afterward, and the camera returns to `Custom` without console errors.

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
