param(
    [ValidateSet("Commerce", "Combat", "Meta", "Full")]
    [string]$Profile = "Full"
)

$runner = "C:\Users\Jennarong Pinjai\.codex\skills\roblox-studio-mcp-automation\scripts\flow_runner.mjs"
$flowsDir = Join-Path $PSScriptRoot "flows"
$invokeFlow = Join-Path $PSScriptRoot "invoke-recorded-flow.ps1"

$profiles = @{
    Commerce = @(
        "full-game-tester-critical-ui-and-models",
        "creator-store-commerce-npcs",
        "training-lock-motion-feedback",
        "pet-wall-drops-and-fusion",
        "premium-pet-studio-test-mode",
        "premium-pet-visual-parity-motion",
        "layered-spin-reference-ui",
        "functional-hero-shop",
        "shop-coin-and-music",
        "creator-store-fist-visuals",
        "fist-arm-alignment-qc",
        "coin-burst-reward-feedback"
    )
    Combat = @(
        "directional-punch-controls",
        "punchwall-free-aim-combat-polish",
        "punchwall-hybrid-physics-lunge",
        "punchwall-shared-excavation-field",
        "punchwall-radius-damage-shake",
        "power-scaled-penetration",
        "tall-multiplayer-depth-wall",
        "camera-teleport-scriptable-visibility",
        "camera-tunnel-zoom-preservation",
        "reduced-motion-performance",
        "destruction-boss-phases"
    )
    Meta = @(
        "vertical-depth-race-hud",
        "responsive-ui-inputs",
        "punchwall-mobile-controls",
        "punchwall-motion-feedback",
        "punchwall-visual-polish-smoke",
        "release-expansion-economy",
        "release-expansion-ui",
        "release-expansion-world",
        "studio-test-harness-control",
        "studio-test-harness-full-control",
        "onboarding-waypoint",
        "luck-distribution"
    )
}

$selected = if ($Profile -eq "Full") {
    @($profiles.Commerce + $profiles.Combat + $profiles.Meta)
} else {
    @($profiles[$Profile])
}

$results = @()
foreach ($flowName in $selected) {
    $flowPath = Join-Path $flowsDir ($flowName + ".json")
    $started = Get-Date
    $run = & $invokeFlow -FlowPath $flowPath -Runner $runner -MaxAttempts 2
    $results += [pscustomobject]@{
        flow = $flowName
        ok = $run.ok
        attempts = $run.attempts
        seconds = [math]::Round(((Get-Date) - $started).TotalSeconds, 1)
        diagnostics = if ($run.ok) { $null } else { $run.output -join "`n" }
    }
}

$failures = @($results | Where-Object { -not $_.ok })
[pscustomobject]@{
    ok = $failures.Count -eq 0
    profile = $Profile
    passed = @($results | Where-Object { $_.ok }).Count
    failed = $failures.Count
    totalSeconds = [math]::Round(($results | Measure-Object -Property seconds -Sum).Sum, 1)
    results = $results
} | ConvertTo-Json -Depth 8

if ($failures.Count -gt 0) { exit 1 }
