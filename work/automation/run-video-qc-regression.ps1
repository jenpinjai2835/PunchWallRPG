param(
    [ValidateSet("P0", "P1", "P2", "Full")]
    [string]$Profile = "Full"
)

$ErrorActionPreference = "Stop"

$runner = "C:\Users\Jennarong Pinjai\.codex\skills\roblox-studio-mcp-automation\scripts\flow_runner.mjs"
$flowsDir = "F:\Roblox\PuchWall\work\automation\flows"
$invokeFlow = Join-Path $PSScriptRoot "invoke-recorded-flow.ps1"

$profiles = @{
    P0 = @(
        "studio-high-power-test-mode",
        "punch-safe-endpoint",
        "punch-no-snapback",
        "punch-collision-state-restoration",
        "punch-200-stress",
        "punch-camera-device-20",
        "camera-long-tunnel-regression",
        "support-loss-matrix",
        "structural-rubble-solidity",
        "structural-character-clearance",
        "punchwall-depth-corridor"
    )
    P1 = @(
        "punch-action-timing",
        "punch-character-motion",
        "impact-destruction-feedback",
        "creator-store-fist-visuals",
        "fist-arm-alignment-qc",
        "authoritative-progression-hud",
        "depth-tier-materials",
        "punched-route-navigability",
        "natural-progression",
        "first-hit-forest-stone"
    )
    P2 = @(
        "forest-world-visual-qc",
        "device-matrix-hud-shop",
        "hero-city-pixel-perfect-hud",
        "branded-loading-onboarding",
        "milestone-world-transition",
        "functional-hero-shop",
        "center-feedback-suppression",
        "world-wall-reset",
        "inventory-persistence"
    )
}

$selected = if ($Profile -eq "Full") {
    @($profiles.P0 + $profiles.P1 + $profiles.P2)
} else {
    @($profiles[$Profile])
}

$results = @()
foreach ($flowName in $selected) {
    $flowPath = Join-Path $flowsDir ($flowName + ".json")
    $started = Get-Date
    $run = & $invokeFlow -FlowPath $flowPath -Runner $runner -MaxAttempts 2
    $result = [pscustomobject]@{
        flow = $flowName
        ok = $run.ok
        attempts = $run.attempts
        seconds = [math]::Round(((Get-Date) - $started).TotalSeconds, 1)
    }
    $results += $result
    if (-not $run.ok) {
        $run.output | Write-Output
        throw "Video QC regression failed: $flowName"
    }
}

[pscustomobject]@{
    ok = $true
    profile = $Profile
    totalSeconds = [math]::Round(($results | Measure-Object -Property seconds -Sum).Sum, 1)
    results = $results
} | ConvertTo-Json -Depth 5
