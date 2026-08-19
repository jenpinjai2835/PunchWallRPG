param(
  [Parameter(Mandatory = $true)]
  [string]$Name,

  [string]$Description = "",
  [string]$StudioName = "PunchWallRPGPrototype",
  [string]$StudioInstanceId = "",
  [string]$PlaceName = "",
  [string]$Root = "Workspace.PunchWallRPG"
)

$ErrorActionPreference = "Stop"
$script = Join-Path $PSScriptRoot "scripts\record_flow.mjs"
$flowsDir = Join-Path $PSScriptRoot "flows"

$args = @(
  $script,
  "--name", $Name,
  "--flows-dir", $flowsDir,
  "--studio-name", $StudioName,
  "--root", $Root
)

if ($StudioInstanceId -ne "") {
  $args += @("--studio-instance-id", $StudioInstanceId)
}
if ($PlaceName -ne "") {
  $args += @("--place-name", $PlaceName)
}
if ($Description -ne "") {
  $args += @("--description", $Description)
}

node @args
