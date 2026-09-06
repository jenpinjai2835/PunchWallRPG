param(
    [string]$StudioInstanceId = "",
    [string]$ExpectedPlaceName = "",
    [string]$ExpectedStudioName = ""
)

$ErrorActionPreference = "Stop"

$script = Join-Path $PSScriptRoot "scripts\flow_runner.mjs"
$flowsDir = Join-Path $PSScriptRoot "flows"
$invokeFlow = Join-Path $PSScriptRoot "invoke-recorded-flow.ps1"

$results = @()
foreach ($flowFile in Get-ChildItem -LiteralPath $flowsDir -Filter "*.json" | Sort-Object Name) {
    $started = Get-Date
    $run = & $invokeFlow -FlowPath $flowFile.FullName -Runner $script -StudioInstanceId $StudioInstanceId -ExpectedStudioName $ExpectedStudioName -ExpectedPlaceName $ExpectedPlaceName -MaxAttempts 2
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
