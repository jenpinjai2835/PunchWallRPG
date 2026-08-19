param(
    [Parameter(Mandatory = $true)]
    [string]$FlowPath,
    [string]$Runner = "",
    [string]$StudioInstanceId = "",
    [string]$ExpectedStudioName = "",
    [string]$ExpectedPlaceName = "",
    [ValidateRange(1, 5)]
    [int]$MaxAttempts = 2,
    [ValidateRange(0, 30)]
    [int]$RetryDelaySeconds = 4
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($Runner)) {
    $Runner = Join-Path $PSScriptRoot "scripts\flow_runner.mjs"
}
$resolvedFlow = [System.IO.Path]::GetFullPath($FlowPath)
$resolvedRunner = [System.IO.Path]::GetFullPath($Runner)
if (-not (Test-Path -LiteralPath $resolvedFlow -PathType Leaf)) {
    throw "Flow file not found: $resolvedFlow"
}
if (-not (Test-Path -LiteralPath $resolvedRunner -PathType Leaf)) {
    throw "Local flow runner not found: $resolvedRunner"
}

$flow = Get-Content -Raw -LiteralPath $resolvedFlow | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace($StudioInstanceId) -and [string]::IsNullOrWhiteSpace([string]$flow.studioInstanceId) -and [string]::IsNullOrWhiteSpace([string]$flow.studioName)) {
    throw "Flow must declare studioName/studioInstanceId, or caller must pass -StudioInstanceId"
}
if ([string]::IsNullOrWhiteSpace($ExpectedStudioName)) {
    $ExpectedStudioName = [string]$flow.studioName
}

$attempt = 0
$output = @()
$exitCode = 1
$transient = $false
$verified = $null

do {
    $attempt += 1
    $resultFile = [System.IO.Path]::GetTempFileName()
    try {
        $arguments = @($resolvedRunner, "--flow", $resolvedFlow, "--result-file", $resultFile)
        if (-not [string]::IsNullOrWhiteSpace($StudioInstanceId)) {
            $arguments += @("--studio-instance-id", $StudioInstanceId)
        }
        if (-not [string]::IsNullOrWhiteSpace($ExpectedPlaceName)) {
            $arguments += @("--place-name", $ExpectedPlaceName)
        }
        $output = @(& node @arguments 2>&1)
        $exitCode = $LASTEXITCODE
        if ($exitCode -eq 0) {
            if (-not (Test-Path -LiteralPath $resultFile -PathType Leaf)) {
                throw "Runner exited successfully without writing its verified result file"
            }
            $parsed = Get-Content -Raw -LiteralPath $resultFile | ConvertFrom-Json
            $result = @($parsed.results)[0]
            if (-not $parsed.ok -or -not $result.ok) {
                throw "Runner returned an unsuccessful flow result"
            }
            if ([string]::IsNullOrWhiteSpace([string]$result.selectedStudio.id) -or [string]::IsNullOrWhiteSpace([string]$result.selectedStudio.name)) {
                throw "Runner did not prove the selected Studio identity"
            }
            if (-not [string]::IsNullOrWhiteSpace($StudioInstanceId) -and [string]$result.selectedStudio.id -ne $StudioInstanceId) {
                throw "Runner selected Studio id $($result.selectedStudio.id), expected $StudioInstanceId"
            }
            if (-not [string]::IsNullOrWhiteSpace($ExpectedStudioName) -and [string]$result.selectedStudio.name -notmatch $ExpectedStudioName) {
                throw "Runner selected Studio '$($result.selectedStudio.name)', expected match '$ExpectedStudioName'"
            }
            if ([string]::IsNullOrWhiteSpace([string]$result.selectedPlace.name)) {
                throw "Runner did not prove the selected place identity"
            }
            if (-not [string]::IsNullOrWhiteSpace($ExpectedPlaceName) -and [string]$result.selectedPlace.name -notmatch $ExpectedPlaceName) {
                throw "Runner selected place '$($result.selectedPlace.name)', expected match '$ExpectedPlaceName'"
            }
            $verified = $result
        }
    }
    finally {
        Remove-Item -LiteralPath $resultFile -Force -ErrorAction SilentlyContinue
    }
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
    selectedStudio = $verified.selectedStudio
    selectedPlace = $verified.selectedPlace
    checks = $verified.checks
}
