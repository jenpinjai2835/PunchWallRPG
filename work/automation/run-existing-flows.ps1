$ErrorActionPreference = "Stop"

$script = "C:\Users\Jennarong Pinjai\.codex\skills\roblox-studio-mcp-automation\scripts\flow_runner.mjs"
$flowsDir = "F:\Roblox\PuchWall\work\automation\flows"
$invokeFlow = Join-Path $PSScriptRoot "invoke-recorded-flow.ps1"

$results = @()
foreach ($flowFile in Get-ChildItem -LiteralPath $flowsDir -Filter "*.json" | Sort-Object Name) {
    $started = Get-Date
    $run = & $invokeFlow -FlowPath $flowFile.FullName -Runner $script -MaxAttempts 2
    $results += [pscustomobject]@{
        flow = $flowFile.BaseName
        ok = $run.ok
        attempts = $run.attempts
        seconds = [math]::Round(((Get-Date) - $started).TotalSeconds, 1)
    }
    if (-not $run.ok) {
        $run.output | Write-Output
        throw "Recorded flow failed: $($flowFile.BaseName)"
    }
}

[pscustomobject]@{
    ok = $true
    totalSeconds = [math]::Round(($results | Measure-Object -Property seconds -Sum).Sum, 1)
    results = $results
} | ConvertTo-Json -Depth 5
