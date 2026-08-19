param(
    [string]$StudioName = "PunchWallRPGPrototype",
    [string]$StudioInstanceId = "",
    [string]$ExpectedPlaceName = ""
)

$ErrorActionPreference = "Stop"

$script = Join-Path $PSScriptRoot "scripts\sync_rojo_source_to_studio.mjs"
$arguments = @($script, "--studio-name", $StudioName)
if (-not [string]::IsNullOrWhiteSpace($StudioInstanceId)) {
    $arguments += @("--studio-instance-id", $StudioInstanceId)
}
if (-not [string]::IsNullOrWhiteSpace($ExpectedPlaceName)) {
    $arguments += @("--place-name", $ExpectedPlaceName)
}

node @arguments
if ($LASTEXITCODE -ne 0) {
    throw "Rojo source sync failed"
}
