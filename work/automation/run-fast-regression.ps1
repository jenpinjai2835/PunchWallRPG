param(
    [ValidateSet("Visual", "Gameplay", "UI", "Full")]
    [string]$Profile = "Visual",
    [string]$StudioInstanceId = "",
    [string]$ExpectedPlaceName = ""
)

$ErrorActionPreference = "Stop"

$runner = Join-Path $PSScriptRoot "scripts\flow_runner.mjs"
$flowsDir = Join-Path $PSScriptRoot "flows"
$invokeFlow = Join-Path $PSScriptRoot "invoke-recorded-flow.ps1"

$profiles = @{
    Visual = @(
        "punchwall-smoke",
        "hero-city-pixel-perfect-hud"
    )
    Gameplay = @(
        "punchwall-smoke",
        "punchwall-train-and-break",
        "punchwall-shop-and-pet",
        "punchwall-rebirth-boss"
    )
    UI = @(
        "hero-city-pixel-perfect-hud",
        "responsive-ui-inputs",
        "punchwall-mobile-controls"
    )
}

if ($Profile -eq "Full") {
    & (Join-Path $PSScriptRoot "run-existing-flows.ps1") -StudioInstanceId $StudioInstanceId -ExpectedPlaceName $ExpectedPlaceName
    exit $LASTEXITCODE
}

$results = @()
foreach ($flowName in $profiles[$Profile]) {
    $flowPath = Join-Path $flowsDir ($flowName + ".json")
    $started = Get-Date
    $run = & $invokeFlow -FlowPath $flowPath -Runner $runner -StudioInstanceId $StudioInstanceId -ExpectedPlaceName $ExpectedPlaceName -MaxAttempts 2
    $results += [pscustomobject]@{
        flow = $flowName
        ok = $run.ok
        attempts = $run.attempts
        seconds = [math]::Round(((Get-Date) - $started).TotalSeconds, 1)
    }
    if (-not $run.ok) {
        $run.output | Write-Output
        throw "Fast regression failed: $flowName"
    }
}

[pscustomobject]@{
    ok = $true
    profile = $Profile
    totalSeconds = [math]::Round(($results | Measure-Object -Property seconds -Sum).Sum, 1)
    results = $results
} | ConvertTo-Json -Depth 5
