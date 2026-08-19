param(
    [string]$OutputPlace = "",
    [string]$ValidationPlace = "",

    [string]$StudioInstanceId = "",

    [string]$ExpectedPlaceName = "",

    [switch]$StaticOnly
)

$ErrorActionPreference = "Stop"

$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
$canonicalOutput = [System.IO.Path]::GetFullPath(
    (Join-Path $repositoryRoot "outputs\PunchWallRPGPlayable_v1_final.rbxlx")
)
$canonicalValidation = [System.IO.Path]::GetFullPath(
    (Join-Path $repositoryRoot "outputs\PunchWallRPGPlayable_v1_final_validation.rbxlx")
)
if ([string]::IsNullOrWhiteSpace($OutputPlace)) { $OutputPlace = $canonicalOutput }
if ([string]::IsNullOrWhiteSpace($ValidationPlace)) { $ValidationPlace = $canonicalValidation }
$resolvedOutput = [System.IO.Path]::GetFullPath($OutputPlace)
$resolvedValidation = [System.IO.Path]::GetFullPath($ValidationPlace)

if (-not $resolvedOutput.Equals($canonicalOutput, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Final validation only accepts the canonical output path: $canonicalOutput"
}
if (-not $resolvedValidation.Equals($canonicalValidation, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Final validation only accepts the canonical validation-copy path: $canonicalValidation"
}
if (-not (Test-Path -LiteralPath $resolvedOutput -PathType Leaf)) {
    throw "Canonical final output is missing: $resolvedOutput"
}
if (-not (Test-Path -LiteralPath $resolvedValidation -PathType Leaf)) {
    throw "Canonical validation copy is missing: $resolvedValidation"
}
if (-not $StaticOnly -and (
    [string]::IsNullOrWhiteSpace($StudioInstanceId) -or
    [string]::IsNullOrWhiteSpace($ExpectedPlaceName)
)) {
    throw "StudioInstanceId and ExpectedPlaceName are required unless -StaticOnly is used"
}

$verifyScript = Join-Path $PSScriptRoot "verify-exact-rbxlx-sources.ps1"
$flowPath = Join-Path $PSScriptRoot "flows\final-rbxlx-build-validation.json"
$runner = Join-Path $PSScriptRoot "scripts\flow_runner.mjs"
$invokeFlow = Join-Path $PSScriptRoot "invoke-recorded-flow.ps1"
$expectedModules = @(
    "GameConfig",
    "PolishConfig",
    "ForestVisualBuilder",
    "FistVisualBuilder",
    "InventoryViewModel",
    "ProfilePersistence",
    "PunchWallBootstrap",
    "InventoryUI",
    "PunchWallClient"
)
$expectedStudioName = "^PunchWallRPGPlayable_v1_final_validation[.]rbxlx$"

$flowDefinition = Get-Content -Raw -LiteralPath $flowPath | ConvertFrom-Json
if ([string]$flowDefinition.studioName -cne $expectedStudioName) {
    throw "Final artifact flow must require the exact validation-copy Studio name"
}

$outputContract = (& $verifyScript -PlacePath $resolvedOutput) | ConvertFrom-Json
$validationContract = (& $verifyScript -PlacePath $resolvedValidation) | ConvertFrom-Json
if (-not $outputContract.ok -or -not $validationContract.ok) {
    throw "Exact final-file source validation failed"
}
if ([string]$outputContract.fileName -cne "PunchWallRPGPlayable_v1_final.rbxlx") {
    throw "Canonical output filename assertion failed: $($outputContract.fileName)"
}
if ([string]$validationContract.fileName -cne "PunchWallRPGPlayable_v1_final_validation.rbxlx") {
    throw "Canonical validation filename assertion failed: $($validationContract.fileName)"
}
if ([string]$outputContract.rbxlxSha256 -ne [string]$validationContract.rbxlxSha256) {
    throw "Validation copy is not byte-for-byte identical to the canonical final output"
}

$outputModules = @($outputContract.modules.PSObject.Properties)
$validationModules = @($validationContract.modules.PSObject.Properties)
if (
    [int]$outputContract.moduleCount -ne $expectedModules.Count -or
    [int]$validationContract.moduleCount -ne $expectedModules.Count -or
    [int]$outputContract.codeObjectCount -ne $expectedModules.Count -or
    [int]$validationContract.codeObjectCount -ne $expectedModules.Count -or
    [int]$outputContract.codeAllowlistVersion -ne 1 -or
    [int]$validationContract.codeAllowlistVersion -ne 1 -or
    $outputContract.cdataPreserved -ne $true -or
    $validationContract.cdataPreserved -ne $true -or
    $outputModules.Count -ne $expectedModules.Count -or
    $outputModules.Count -ne $validationModules.Count
) {
    throw "Output and validation copy do not expose the same complete source-hash set"
}
if (
    @(Compare-Object -ReferenceObject $expectedModules -DifferenceObject @($outputModules.Name)).Count -ne 0 -or
    @(Compare-Object -ReferenceObject $expectedModules -DifferenceObject @($validationModules.Name)).Count -ne 0
) {
    throw "Output or validation copy exposes a non-canonical source module set"
}
foreach ($name in $expectedModules) {
    $property = $outputContract.modules.PSObject.Properties[$name]
    $outputHash = [string]$property.Value.normalizedSha256
    $outputFileHash = [string]$property.Value.sourceFileSha256
    $validationProperty = $validationContract.modules.PSObject.Properties[$name]
    if (
        [string]::IsNullOrWhiteSpace($outputHash) -or
        [string]::IsNullOrWhiteSpace($outputFileHash) -or
        $null -eq $validationProperty
    ) {
        throw "Missing exact source hash for $name"
    }
    $validationHash = [string]$validationProperty.Value.normalizedSha256
    $validationFileHash = [string]$validationProperty.Value.sourceFileSha256
    if ($outputHash -ne $validationHash -or $outputFileHash -ne $validationFileHash) {
        throw "Output and validation-copy source hashes differ for $name"
    }
}

if ($StaticOnly) {
    [pscustomobject]@{
        ok = $true
        studioUsed = $false
        runtimeStatus = "NOT_RUN_STATIC_ONLY"
        canonicalOutput = $resolvedOutput
        canonicalValidationCopy = $resolvedValidation
        rbxlxSha256 = $outputContract.rbxlxSha256
        moduleCount = $expectedModules.Count
        sourceMapVersion = 1
        codeAllowlistVersion = 1
        codeObjectCount = $outputContract.codeObjectCount
        cdataPreserved = $true
        exactSourceHashes = $outputContract.modules
    } | ConvertTo-Json -Depth 10
    return
}

$expectedPlacePattern = "^$([regex]::Escape($ExpectedPlaceName))$"
$flowResult = & $invokeFlow `
    -FlowPath $flowPath `
    -Runner $runner `
    -StudioInstanceId $StudioInstanceId `
    -ExpectedStudioName $expectedStudioName `
    -ExpectedPlaceName $expectedPlacePattern `
    -MaxAttempts 1
if (-not $flowResult.ok) {
    throw "Final artifact runtime flow failed"
}
if ([string]$flowResult.selectedStudio.id -ne $StudioInstanceId) {
    throw "Validation ran against Studio id '$($flowResult.selectedStudio.id)', expected '$StudioInstanceId'"
}
if ([string]$flowResult.selectedStudio.name -cne "PunchWallRPGPlayable_v1_final_validation.rbxlx") {
    throw "Validation ran against the wrong Studio file: $($flowResult.selectedStudio.name)"
}
if ([string]::IsNullOrWhiteSpace([string]$flowResult.selectedPlace.name)) {
    throw "Validation Studio did not return a concrete place identity"
}
if ([string]$flowResult.selectedPlace.name -cne $ExpectedPlaceName) {
    throw "Validation ran against place '$($flowResult.selectedPlace.name)', expected '$ExpectedPlaceName'"
}

$postOutputContract = (& $verifyScript -PlacePath $resolvedOutput) | ConvertFrom-Json
$postValidationContract = (& $verifyScript -PlacePath $resolvedValidation) | ConvertFrom-Json
if (
    [string]$postOutputContract.rbxlxSha256 -ne [string]$outputContract.rbxlxSha256 -or
    [string]$postValidationContract.rbxlxSha256 -ne [string]$validationContract.rbxlxSha256 -or
    [string]$postOutputContract.rbxlxSha256 -ne [string]$postValidationContract.rbxlxSha256
) {
    throw "Final artifact or validation copy changed during runtime validation"
}
foreach ($name in $expectedModules) {
    if (
        [string]$postOutputContract.modules.$name.normalizedSha256 -ne
            [string]$outputContract.modules.$name.normalizedSha256 -or
        [string]$postValidationContract.modules.$name.normalizedSha256 -ne
            [string]$validationContract.modules.$name.normalizedSha256
    ) {
        throw "Embedded source hash changed during runtime validation: $name"
    }
}

[pscustomobject]@{
    ok = $true
    canonicalOutput = $resolvedOutput
    canonicalValidationCopy = $resolvedValidation
    rbxlxSha256 = $outputContract.rbxlxSha256
    moduleCount = $expectedModules.Count
    sourceMapVersion = 1
    codeAllowlistVersion = 1
    codeObjectCount = $outputContract.codeObjectCount
    cdataPreserved = $true
    exactSourceHashes = $outputContract.modules
    selectedStudio = $flowResult.selectedStudio
    selectedPlace = $flowResult.selectedPlace
    checks = $flowResult.checks
} | ConvertTo-Json -Depth 10
