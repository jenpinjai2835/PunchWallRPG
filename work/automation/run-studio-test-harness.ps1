param(
    [ValidateSet("Control", "Full", "All")]
    [string]$Suite = "All",
    [string]$StudioInstanceId = "",
    [string]$ExpectedPlaceName = ""
)

$ErrorActionPreference = "Stop"

$runner = Join-Path $PSScriptRoot "scripts\flow_runner.mjs"
$flowDirectory = Join-Path $PSScriptRoot "flows"
$invokeFlow = Join-Path $PSScriptRoot "invoke-recorded-flow.ps1"
$flows = switch ($Suite) {
    "Control" { @("studio-test-harness-control.json") }
    "Full" { @("studio-test-harness-full-control.json") }
    default {
        @(
            "studio-test-harness-control.json",
            "studio-test-harness-full-control.json"
        )
    }
}

$results = @()
foreach ($flowName in $flows) {
    $flowPath = Join-Path $flowDirectory $flowName
    $run = & $invokeFlow -FlowPath $flowPath -Runner $runner -StudioInstanceId $StudioInstanceId -ExpectedPlaceName $ExpectedPlaceName -MaxAttempts 2
    if (-not $run.ok) {
        throw "Studio test harness flow failed: $flowName"
    }
    $results += $flowName
}

[pscustomobject]@{
    ok = $true
    suite = $Suite
    flows = $results
} | ConvertTo-Json -Depth 4
