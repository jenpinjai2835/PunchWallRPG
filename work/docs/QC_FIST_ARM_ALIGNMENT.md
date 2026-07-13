# Fist / Arm Alignment QC

## Player-view captures

Captured from the same side camera after equipping each shop tier:

- `work/qc-fist-arm-starter-side.jpg`
- `work/qc-fist-arm-boxing-side.jpg`
- `work/qc-fist-arm-iron-side.jpg`
- `work/qc-fist-arm-thunder-side.jpg`
- `work/qc-fist-arm-titan-side.jpg`

## Findings and fix

The first capture showed the Creator Store mesh at roughly 1.4 studs while the
R15 RightHand was roughly 0.8 studs tall. It was welded, but visually read as a
floating box beside the arm. The client now measures each imported asset's
bounding box, normalizes the largest dimension against `RightHand`, and uses a
shorter wrist grip offset before creating the welds. The player character model
and the gameplay punch logic are unchanged.

The follow-up captures show the equipped mesh staying at the wrist with no
anchored visual parts and no visible gap between the hand and fist. Style color
and mesh silhouette remain asset-specific and are intentionally not used for
gameplay state.

## Automated acceptance

Run:

```powershell
node "C:\Users\Jennarong Pinjai\.codex\skills\roblox-studio-mcp-automation\scripts\flow_runner.mjs" --flow "F:\Roblox\PuchWall\work\automation\flows\fist-arm-alignment-qc.json"
```

Acceptance checks cover Starter/Boxing, Iron, Thunder, and Titan: visual exists,
all visual parts are unanchored, at least one hand weld exists, max hand offset
stays below 2.4 studs, console has no runtime error, and a screen capture is
requested for every tier.
