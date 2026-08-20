[CmdletBinding()]
param(
    [string]$NodeCommand = "node",
    [string]$LuauCompileCommand = ""
)

$ErrorActionPreference = "Stop"
$automationRoot = $PSScriptRoot
$scriptsRoot = Join-Path $automationRoot "scripts"
$flowsRoot = Join-Path $automationRoot "flows"
$node = Get-Command -Name $NodeCommand -ErrorAction Stop
$checks = [ordered]@{}

function Resolve-LuauCompiler {
    if (-not [string]::IsNullOrWhiteSpace($LuauCompileCommand)) {
        if (Test-Path -LiteralPath $LuauCompileCommand -PathType Leaf) {
            return [System.IO.Path]::GetFullPath($LuauCompileCommand)
        }
        $explicitCommand = Get-Command -Name $LuauCompileCommand -ErrorAction SilentlyContinue
        if ($null -ne $explicitCommand) { return $explicitCommand.Source }
        throw "Luau compiler not found: $LuauCompileCommand"
    }
    foreach ($name in @("luau-compile", "luau-compile.exe")) {
        $command = Get-Command -Name $name -ErrorAction SilentlyContinue
        if ($null -ne $command) { return $command.Source }
    }
    $temporaryRoot = [System.IO.Path]::GetTempPath()
    $bundledCandidates = @(
        Get-ChildItem -LiteralPath $temporaryRoot -Directory -Filter "codex-luau-*" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            ForEach-Object { Join-Path $_.FullName "luau-compile.exe" } |
            Where-Object { Test-Path -LiteralPath $_ -PathType Leaf }
    )
    if ($bundledCandidates.Count -gt 0) { return $bundledCandidates[0] }
    throw "luau-compile is required. Put it on PATH or pass -LuauCompileCommand <path>."
}

$luauCompiler = Resolve-LuauCompiler

function Invoke-CheckedNode {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,

        [Parameter(Mandatory = $true)]
        [string]$Label
    )

    $output = @(& $node.Source @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "$Label failed:`n$($output -join [Environment]::NewLine)"
    }
    return $output
}

$javascriptFiles = @(
    Get-ChildItem -LiteralPath $automationRoot -Recurse -File |
        Where-Object { $_.Extension -eq ".mjs" } |
        Sort-Object FullName
)
foreach ($file in $javascriptFiles) {
    $null = Invoke-CheckedNode -Arguments @("--check", $file.FullName) -Label "Node syntax: $($file.FullName)"
}
$checks.nodeSyntax = @{
    passed = $true
    files = $javascriptFiles.Count
}

$powershellFiles = @(
    Get-ChildItem -LiteralPath $automationRoot -Recurse -File |
        Where-Object { $_.Extension -eq ".ps1" } |
        Sort-Object FullName
)
$parseErrors = @()
foreach ($file in $powershellFiles) {
    $tokens = $null
    $errors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile(
        $file.FullName,
        [ref]$tokens,
        [ref]$errors
    )
    foreach ($error in @($errors)) {
        $parseErrors += "$($file.FullName):$($error.Extent.StartLineNumber): $($error.Message)"
    }
}
if ($parseErrors.Count -gt 0) {
    throw "PowerShell parse failed:`n$($parseErrors -join [Environment]::NewLine)"
}
$checks.powerShellSyntax = @{
    passed = $true
    files = $powershellFiles.Count
}

$sourceRoot = [System.IO.Path]::GetFullPath((Join-Path $automationRoot "..\punch-wall-rpg\src"))
$luauSourcePaths = @(
    "shared\GameConfig.lua",
    "shared\PolishConfig.lua",
    "shared\ForestVisualBuilder.lua",
    "shared\FistVisualBuilder.lua",
    "shared\InventoryViewModel.lua",
    "server\ProfilePersistence.lua",
    "server\PunchWallBootstrap.server.lua",
    "client\InventoryUI.lua",
    "client\PunchWallClient.client.lua"
)
$luauCompileCases = 0
foreach ($relativePath in $luauSourcePaths) {
    $sourcePath = Join-Path $sourceRoot $relativePath
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Mapped Luau source missing: $sourcePath"
    }
    foreach ($optimization in 0..2) {
        $compilerOutput = @(& $luauCompiler "--null" "-O$optimization" $sourcePath 2>&1)
        if ($LASTEXITCODE -ne 0) {
            throw "Luau compile O$optimization failed for $relativePath`:`n$($compilerOutput -join [Environment]::NewLine)"
        }
        $luauCompileCases += 1
    }
}
$checks.luauCompile = @{
    passed = $true
    compiler = $luauCompiler
    files = $luauSourcePaths.Count
    optimizationLevels = 3
    cases = $luauCompileCases
}

$flowFiles = @(Get-ChildItem -LiteralPath $flowsRoot -Filter "*.json" -File | Sort-Object Name)
$invalidFlows = @()
foreach ($file in $flowFiles) {
    try {
        $flow = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
        if (-not $flow.steps -or (-not $flow.studioName -and -not $flow.studioInstanceId)) {
            $invalidFlows += $file.Name
        }
    }
    catch {
        $invalidFlows += "$($file.Name): $($_.Exception.Message)"
    }
}
if ($invalidFlows.Count -gt 0) {
    throw "Flow validation failed:`n$($invalidFlows -join [Environment]::NewLine)"
}
$checks.flowJson = @{
    passed = $true
    files = $flowFiles.Count
}

$runnerSelfTest = Invoke-CheckedNode `
    -Arguments @((Join-Path $scriptsRoot "flow_runner.mjs"), "--self-test") `
    -Label "Local runner self-test"
$runnerResult = $runnerSelfTest -join [Environment]::NewLine | ConvertFrom-Json
if (-not $runnerResult.ok) {
    throw "Local runner self-test did not report ok=true."
}
$checks.runnerSelfTest = @{
    passed = $true
    checks = @($runnerResult.checks).Count
}

$infrastructureOutput = Invoke-CheckedNode `
    -Arguments @((Join-Path $scriptsRoot "automation-infrastructure-contract.mjs")) `
    -Label "Automation infrastructure contract"
$infrastructureResult = $infrastructureOutput -join [Environment]::NewLine | ConvertFrom-Json
if (-not $infrastructureResult.ok) {
    throw "Automation infrastructure contract did not report ok=true."
}
$checks.infrastructureContract = @{
    passed = $true
    checks = $infrastructureResult.passed
}

$economyBoundaryOutput = Invoke-CheckedNode `
    -Arguments @((Join-Path $scriptsRoot "full-game-economy-boundaries-contract.mjs")) `
    -Label "Full-game economy boundaries contract"
$economyBoundaryResult = $economyBoundaryOutput -join [Environment]::NewLine | ConvertFrom-Json
if (-not $economyBoundaryResult.ok) {
    throw "Full-game economy boundaries contract did not report ok=true."
}
$checks.economyBoundaryContract = @{
    passed = $true
    checks = $economyBoundaryResult.passed
    realSpinCalls = $economyBoundaryResult.realSpinCalls
}

$batchBFistOutput = Invoke-CheckedNode `
    -Arguments @((Join-Path $scriptsRoot "batch-b-fist-flow-contract.mjs")) `
    -Label "Batch B fist flow contract"
$batchBFistResult = $batchBFistOutput -join [Environment]::NewLine | ConvertFrom-Json
if (-not $batchBFistResult.ok) {
    throw "Batch B fist flow contract did not report ok=true."
}
$checks.batchBFistFlowContract = @{
    passed = $true
    checks = $batchBFistResult.passed
    fistTiers = $batchBFistResult.fistTiers
    creatorStoreTiers = $batchBFistResult.creatorStoreTiers
}

$fistIconIdentityOutput = Invoke-CheckedNode `
    -Arguments @((Join-Path $scriptsRoot "fist-icon-identity-contract.mjs")) `
    -Label "Fist icon identity contract"
$fistIconIdentityResult = $fistIconIdentityOutput -join [Environment]::NewLine | ConvertFrom-Json
if (-not $fistIconIdentityResult.ok) {
    throw "Fist icon identity contract did not report ok=true."
}
$checks.fistIconIdentityContract = @{
    passed = $true
    checks = $fistIconIdentityResult.passed
    normalIcons = $fistIconIdentityResult.normalIcons
    premiumIcons = $fistIconIdentityResult.premiumIcons
}

$worldBoostShowcaseOutput = Invoke-CheckedNode `
    -Arguments @((Join-Path $scriptsRoot "world-boost-showcase-contract.mjs")) `
    -Label "World boost showcase contract"
$worldBoostShowcaseResult = $worldBoostShowcaseOutput -join [Environment]::NewLine | ConvertFrom-Json
if (-not $worldBoostShowcaseResult.ok) {
    throw "World boost showcase contract did not report ok=true."
}
$checks.worldBoostShowcaseContract = @{
    passed = $true
    checks = $worldBoostShowcaseResult.passed
    showcases = $worldBoostShowcaseResult.showcases
}

$powerGrowthOutput = Invoke-CheckedNode `
    -Arguments @((Join-Path $scriptsRoot "power-avatar-growth-contract.mjs")) `
    -Label "Power avatar growth contract"
$powerGrowthResult = $powerGrowthOutput -join [Environment]::NewLine | ConvertFrom-Json
if (-not $powerGrowthResult.ok) {
    throw "Power avatar growth contract did not report ok=true."
}
$checks.powerAvatarGrowthContract = @{
    passed = $true
    checks = $powerGrowthResult.passed
    curve = $powerGrowthResult.curve
    maxScaleMultiplier = $powerGrowthResult.maxScaleMultiplier
}

$trainingStationOutput = Invoke-CheckedNode `
    -Arguments @((Join-Path $scriptsRoot "training-station-progression-contract.mjs")) `
    -Label "Training station progression contract"
$trainingStationResult = $trainingStationOutput -join [Environment]::NewLine | ConvertFrom-Json
if (-not $trainingStationResult.ok) {
    throw "Training station progression contract did not report ok=true."
}
$checks.trainingStationProgressionContract = @{
    passed = $true
    checks = $trainingStationResult.passed
    stations = $trainingStationResult.stations
}

$honorProgressionOutput = Invoke-CheckedNode `
    -Arguments @((Join-Path $scriptsRoot "honor-progression-contract.mjs")) `
    -Label "Honor progression contract"
$honorProgressionResult = $honorProgressionOutput -join [Environment]::NewLine | ConvertFrom-Json
if (-not $honorProgressionResult.ok) {
    throw "Honor progression contract did not report ok=true."
}
$checks.honorProgressionContract = @{
    passed = $true
    checks = $honorProgressionResult.passed
    depthMilestones = $honorProgressionResult.depthMilestones
    rebirthMilestones = $honorProgressionResult.rebirthMilestones
    relics = $honorProgressionResult.relics
}

$rebirthProgressionOutput = Invoke-CheckedNode `
    -Arguments @((Join-Path $scriptsRoot "rebirth-progression-contract.mjs")) `
    -Label "Rebirth progression contract"
$rebirthProgressionResult = $rebirthProgressionOutput -join [Environment]::NewLine | ConvertFrom-Json
if (-not $rebirthProgressionResult.ok) {
    throw "Rebirth progression contract did not report ok=true."
}
$checks.rebirthProgressionContract = @{
    passed = $true
    checks = $rebirthProgressionResult.passed
    checkpoints = $rebirthProgressionResult.checkpoints
}

$standaloneWindowsOutput = Invoke-CheckedNode `
    -Arguments @((Join-Path $scriptsRoot "standalone-player-windows-contract.mjs")) `
    -Label "Standalone player windows contract"
$standaloneWindowsResult = $standaloneWindowsOutput -join [Environment]::NewLine | ConvertFrom-Json
if (-not $standaloneWindowsResult.ok) {
    throw "Standalone player windows contract did not report ok=true."
}
$checks.standalonePlayerWindowsContract = @{
    passed = $true
    checks = $standaloneWindowsResult.passed
}

$honorProductOutput = Invoke-CheckedNode `
    -Arguments @((Join-Path $scriptsRoot "honor-product-receipts-contract.mjs")) `
    -Label "Honor product receipt contract"
$honorProductResult = $honorProductOutput -join [Environment]::NewLine | ConvertFrom-Json
if (-not $honorProductResult.ok) {
    throw "Honor product receipt contract did not report ok=true."
}
$checks.honorProductReceiptContract = @{
    passed = $true
    checks = $honorProductResult.passed
    packs = $honorProductResult.packs
}

$petPackOutput = Invoke-CheckedNode `
    -Arguments @((Join-Path $scriptsRoot "creator-store-pet-pack-contract.mjs")) `
    -Label "Creator Store pet pack contract"
$petPackResult = $petPackOutput -join [Environment]::NewLine | ConvertFrom-Json
if (-not $petPackResult.ok) {
    throw "Creator Store pet pack contract did not report ok=true."
}
$checks.creatorStorePetPackContract = @{
    passed = $true
    checks = $petPackResult.passed
    assetId = "70715599928632"
}

$persistenceOutput = Invoke-CheckedNode `
    -Arguments @((Join-Path $scriptsRoot "persistence-contract.mjs")) `
    -Label "Persistence executable contract"
$persistenceResult = $persistenceOutput -join [Environment]::NewLine | ConvertFrom-Json
if (-not $persistenceResult.ok) {
    throw "Persistence executable contract did not report ok=true."
}
$checks.persistenceContract = @{
    passed = $true
    checks = $persistenceResult.passed
    contractVersion = $persistenceResult.contractVersion
    dataVersion = $persistenceResult.dataVersion
}

$additionalStaticContracts = @(
    @{ file = "client-runtime-performance-contract.mjs"; key = "clientRuntimePerformanceContract" },
    @{ file = "device-matrix-hud-shop-contract.mjs"; key = "deviceMatrixHudShopContract" },
    @{ file = "fist-pet-safety-contract.mjs"; key = "fistPetSafetyContract" },
    @{ file = "full-game-real-ui-controls-contract.mjs"; key = "fullGameRealUiControlsContract" },
    @{ file = "inventory-card-render-contract.mjs"; key = "inventoryCardRenderContract" },
    @{ file = "inventory-runtime-cache-contract.mjs"; key = "inventoryRuntimeCacheContract" },
    @{ file = "inventory-visual-fidelity-contract.mjs"; key = "inventoryVisualFidelityContract" },
    @{ file = "inventory-visual-responsive-contract.mjs"; key = "inventoryVisualResponsiveContract" },
    @{ file = "long-run-content-contract.mjs"; key = "longRunContentContract" },
    @{ file = "mobile-iphone17-layout-contract.mjs"; key = "mobileIphone17LayoutContract" },
    @{ file = "product-completeness-contract.mjs"; key = "productCompletenessContract" },
    @{ file = "titan-hq-visual-contract.mjs"; key = "titanHqVisualContract" },
    @{ file = "training-ui-pet-recovery-contract.mjs"; key = "trainingUiPetRecoveryContract" }
)
foreach ($contract in $additionalStaticContracts) {
    $output = Invoke-CheckedNode -Arguments @((Join-Path $scriptsRoot $contract.file)) -Label "Static contract: $($contract.file)"
    $joinedOutput = $output -join [Environment]::NewLine
    $result = $null
    try {
        $result = $joinedOutput | ConvertFrom-Json
    }
    catch {
        # A successful text-only contract is valid; Invoke-CheckedNode already
        # made a nonzero exit fail closed.
    }
    if ($null -ne $result -and $null -ne $result.PSObject.Properties["ok"] -and -not $result.ok) {
        throw "$($contract.file) did not report ok=true."
    }
    $reportedChecks = $null
    if ($null -ne $result -and $null -ne $result.PSObject.Properties["passed"] -and $result.passed -isnot [System.Management.Automation.PSCustomObject]) {
        $reportedChecks = $result.passed
    }
    elseif ($null -ne $result -and $null -ne $result.PSObject.Properties["checks"] -and $result.checks -is [ValueType]) {
        $reportedChecks = $result.checks
    }
    $checks[$contract.key] = @{
        passed = $true
        reportedChecks = $reportedChecks
    }
}

$manuallyInvokedContracts = @(
    "automation-infrastructure-contract.mjs",
    "batch-b-fist-flow-contract.mjs",
    "creator-store-pet-pack-contract.mjs",
    "fist-icon-identity-contract.mjs",
    "full-game-economy-boundaries-contract.mjs",
    "honor-product-receipts-contract.mjs",
    "honor-progression-contract.mjs",
    "persistence-contract.mjs",
    "power-avatar-growth-contract.mjs",
    "rebirth-progression-contract.mjs",
    "standalone-player-windows-contract.mjs",
    "training-station-progression-contract.mjs",
    "world-boost-showcase-contract.mjs"
)
$excludedStudioCapableContracts = @(
    @{
        file = "inventory-performance-contract.mjs"
        reason = "Studio-capable runtime benchmark; run explicitly with flow_runner instead of the non-Studio aggregate."
    }
)
$registeredContracts = @($manuallyInvokedContracts) + @($additionalStaticContracts | ForEach-Object { $_.file }) + @($excludedStudioCapableContracts | ForEach-Object { $_.file })
$allContractFiles = @(
    Get-ChildItem -LiteralPath $scriptsRoot -Filter "*-contract.mjs" -File |
        Sort-Object Name |
        ForEach-Object { $_.Name }
)
$unregisteredContracts = @($allContractFiles | Where-Object { $_ -notin $registeredContracts })
$missingContracts = @($registeredContracts | Where-Object { $_ -notin $allContractFiles })
if ($unregisteredContracts.Count -gt 0 -or $missingContracts.Count -gt 0) {
    throw "Static contract registry mismatch. Unregistered: $($unregisteredContracts -join ', '); missing: $($missingContracts -join ', ')"
}
$checks.staticContractCoverage = @{
    passed = $true
    executed = $manuallyInvokedContracts.Count + $additionalStaticContracts.Count
    discovered = $allContractFiles.Count
    excluded = $excludedStudioCapableContracts
}

[ordered]@{
    ok = $true
    automationRoot = $automationRoot
    studioUsed = $false
    checks = $checks
} | ConvertTo-Json -Depth 8
