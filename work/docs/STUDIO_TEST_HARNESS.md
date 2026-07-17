# Smash Wall Studio Test Harness

## Purpose

`PunchWallTestHarness` and `PunchWallClientTestHarness` let MCP automation control gameplay and UI without operating the Windows mouse, keyboard, or Roblox Studio panels.

The harness is created only while `RunService:IsStudio()` is true. It is not a `RemoteEvent` or `RemoteFunction`, is not parented to `ReplicatedStorage`, and has no production network surface.

## Safety Contract

- Server harness: `ServerStorage.PunchWallTestHarness`
- Client harness: `Players.LocalPlayer.PlayerGui.PunchWallHUD.PunchWallClientTestHarness`
- Legacy API remains available at `ServerStorage.PunchWallAutomation`.
- Both new harnesses expose `StudioOnly = true`, `ProductionSurface = false`, `Ready = true`, and a version attribute.
- The source guard is `if RunService:IsStudio() then`.
- Test mode state is never saved by the normal high-power test path.
- Server commands remain authoritative for stats, inventory, rewards, wall state, and character position.
- Client commands only control local UI, camera, settings, and input-facing actions.
- A sequence is limited to 50 steps by default.

## Server Usage

```lua
local harness = game.ServerStorage.PunchWallTestHarness

local description = harness:Invoke({ command = "Describe" })
local snapshot = harness:Invoke({ command = "Snapshot" })

local result = harness:Invoke({
	command = "Sequence",
	steps = {
		{ command = "Reset" },
		{ command = "ApplyPreset", target = "Midgame" },
		{ command = "Teleport", target = "Training" },
		{ command = "SetSpinReady", amount = 2 },
		{ command = "ForcePetEggDrop", target = 30 },
	},
})
```

Optional player selectors are accepted as a player name, user ID, player instance, or `{ name = ... }`, `{ userId = ... }`, and `{ index = ... }`.

## Server Commands

Core state:

- `Describe`, `Catalog`, `Snapshot`, `Sequence`
- `Reset`, `ResetWorld`, `SetWorldResetEnabled`
- `SetStats`, `ApplyPreset`, `SetPlayerAttribute`
- `Teleport`, `Respawn`, `SetCharacterState`, `ClearCooldowns`
- `SetLighting`, `EmitFeedback`

Progression and commerce:

- `BuyFist`, `EquipFist`, `GrantAllFists`
- `GrantPremiumFist`, `GrantPremiumProduct`, `GrantAllPremium`
- `GrantPet`, `GrantAllPets`, `GrantPremiumPet`
- `HatchPet`, `ForcePetEggDrop`, `FusePet`, `EquipPet`, `UnequipPet`, `DeletePet`, `LockPet`
- `BuyHonorItem`, `BuyShopBoost`
- `SetSpinReady`, `Spin`, `ClaimDaily`, `ClaimQuest`, `ClaimPlaytime`, `Rebirth`

Combat and world:

- `Train`, `StopTraining`
- `HitWall`, `BreakWall`, `BreakWallCycles`
- `HitDepthBlock`, `BreakDepthBlock`, `BreakDepthRegion`
- `PunchRadius`, `PunchWithCooldown`, `StressPunchCase`
- `HitBoss`, `HitBossWeakPoint`

Named teleport targets:

- `Spawn`
- `DepthStart`
- `Training`
- `Armory`
- `PetLab`
- `Honor`
- `Rebirth`

Presets:

- `Starter`
- `Midgame`
- `Endgame`
- `Stress`

## Client Usage

```lua
local gui = game.Players.LocalPlayer.PlayerGui.PunchWallHUD
local harness = gui.PunchWallClientTestHarness

local result = harness:Invoke({
	command = "Sequence",
	steps = {
		{ command = "SetSettings", value = { sound = false, motion = false, uiScale = 0.8 } },
		{ command = "OpenTab", value = "Fists" },
		{ command = "OpenShopPage", value = "Premium" },
		{
			command = "SetCamera",
			value = {
				position = { -26, 11, 43 },
				lookAt = { -42, 4, 24 },
			},
		},
		{ command = "Snapshot" },
	},
})
```

Client commands:

- `Describe`, `Snapshot`, `Sequence`
- `Punch`, `Jump`, `SpinNow`, `RequestAction`
- `OpenSpin`, `OpenTab`, `OpenShopPage`, `InvokeShopAction`, `OpenMore`, `CloseMenus`
- `SetCamera`, `ResetCamera`
- `SetSettings`, `ToggleSound`, `ClearMarkers`
- `SetGuiVisible`, `SetGuiAttribute`, `GetGuiSummary`
- `__ReplayLoading`, `__HideLoading`, `__RunCamera`

## Regression

Run both harness suites:

```powershell
F:\Roblox\PuchWall\work\automation\run-studio-test-harness.ps1
```

Run one suite:

```powershell
F:\Roblox\PuchWall\work\automation\run-studio-test-harness.ps1 -Suite Control
F:\Roblox\PuchWall\work\automation\run-studio-test-harness.ps1 -Suite Full
```

Recorded flows:

- `studio-test-harness-control.json`
- `studio-test-harness-full-control.json`

Every new gameplay or UI flow should use these harness commands first. Add a new harness command only when the behavior cannot be represented by the existing command set.
