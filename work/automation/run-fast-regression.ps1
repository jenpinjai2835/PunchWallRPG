param(
    [ValidateSet("Visual", "Gameplay", "UI", "Full")]
    [string]$Profile = "Visual"
)

$ErrorActionPreference = "Stop"

$runner = "C:\Users\Jennarong Pinjai\.codex\skills\roblox-studio-mcp-automation\scripts\flow_runner.mjs"
$flowsDir = "F:\Roblox\PuchWall\work\automation\flows"

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
    & "F:\Roblox\PuchWall\work\automation\run-existing-flows.ps1"
    exit $LASTEXITCODE
}

$results = @()
foreach ($flowName in $profiles[$Profile]) {
    $flowPath = Join-Path $flowsDir ($flowName + ".json")
    $started = Get-Date
    $output = & node $runner --flow $flowPath 2>&1
    $exitCode = $LASTEXITCODE
    $results += [pscustomobject]@{
        flow = $flowName
        ok = $exitCode -eq 0
        seconds = [math]::Round(((Get-Date) - $started).TotalSeconds, 1)
    }
    if ($exitCode -ne 0) {
        $output | Write-Output
        throw "Fast regression failed: $flowName"
    }
}

[pscustomobject]@{
    ok = $true
    profile = $Profile
    totalSeconds = [math]::Round(($results | Measure-Object -Property seconds -Sum).Sum, 1)
    results = $results
} | ConvertTo-Json -Depth 5
