param(
    [Parameter(Mandatory = $true)]
    [string]$FlowPath,
    [string]$Runner = "C:\Users\Jennarong Pinjai\.codex\skills\roblox-studio-mcp-automation\scripts\flow_runner.mjs",
    [ValidateRange(1, 5)]
    [int]$MaxAttempts = 2,
    [ValidateRange(0, 30)]
    [int]$RetryDelaySeconds = 4
)

$attempt = 0
$output = @()
$exitCode = 1
$transient = $false

do {
    $attempt += 1
    $output = @(& node $Runner --flow $FlowPath 2>&1)
    $exitCode = $LASTEXITCODE
    if ($exitCode -eq 0) { break }

    $combined = $output -join "`n"
    $transient = $combined -match (
        "Timed out waiting for response|" +
        "No Roblox Studio instances registered|" +
        "No studio available|" +
        "datamodel is not available in Edit mode"
    )
    if (-not $transient -or $attempt -ge $MaxAttempts) { break }
    Start-Sleep -Seconds $RetryDelaySeconds
} while ($true)

[pscustomobject]@{
    ok = $exitCode -eq 0
    exitCode = $exitCode
    attempts = $attempt
    transientFailure = $transient
    output = $output
}
