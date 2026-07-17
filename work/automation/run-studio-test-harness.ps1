param(
    [ValidateSet("Control", "Full", "All")]
    [string]$Suite = "All"
)

$ErrorActionPreference = "Stop"

$runner = "C:\Users\Jennarong Pinjai\.codex\skills\roblox-studio-mcp-automation\scripts\flow_runner.mjs"
$flowDirectory = Join-Path $PSScriptRoot "flows"
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
    & node $runner --flow $flowPath
    if ($LASTEXITCODE -ne 0) {
        throw "Studio test harness flow failed: $flowName"
    }
    $results += $flowName
}

[pscustomobject]@{
    ok = $true
    suite = $Suite
    flows = $results
} | ConvertTo-Json -Depth 4
