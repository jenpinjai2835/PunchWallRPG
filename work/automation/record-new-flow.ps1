param(
  [Parameter(Mandatory = $true)]
  [string]$Name,

  [string]$Description = "",
  [string]$StudioName = "PunchWallRPGPrototype",
  [string]$Root = "Workspace.PunchWallRPG"
)

$ErrorActionPreference = "Stop"
$script = "C:\Users\Jennarong Pinjai\.codex\skills\roblox-studio-mcp-automation\scripts\record_flow.mjs"
$flowsDir = "F:\Roblox\PuchWall\work\automation\flows"

$args = @(
  $script,
  "--name", $Name,
  "--flows-dir", $flowsDir,
  "--studio-name", $StudioName,
  "--root", $Root
)

if ($Description -ne "") {
  $args += @("--description", $Description)
}

node @args
