param(
    [string]$StudioInstanceId = "",
    [string]$ExpectedPlaceName = ""
)

$ErrorActionPreference = "Stop"

$script = Join-Path $PSScriptRoot "scripts\flow_runner.mjs"
$flow = Join-Path $PSScriptRoot "flows\punchwall-smoke.json"
$invokeFlow = Join-Path $PSScriptRoot "invoke-recorded-flow.ps1"

$result = & $invokeFlow -FlowPath $flow -Runner $script -StudioInstanceId $StudioInstanceId -ExpectedPlaceName $ExpectedPlaceName -MaxAttempts 2
$result | ConvertTo-Json -Depth 8
if (-not $result.ok) { exit 1 }
