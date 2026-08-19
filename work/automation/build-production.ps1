param(
    [string]$SourcePlace = "",
    [string]$OutputPlace = "",
    [string]$SourceRoot = "",
    [string]$ManifestPath = "",
    [switch]$AllowCanonicalFinalOutput
)

$ErrorActionPreference = "Stop"

$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
if ([string]::IsNullOrWhiteSpace($SourcePlace)) {
    $SourcePlace = Join-Path $projectRoot "outputs\PunchWallRPGPlayable_v1_final.rbxlx"
}
if ([string]::IsNullOrWhiteSpace($OutputPlace)) {
    $OutputPlace = Join-Path $projectRoot "outputs\SmashWall_Production.rbxlx"
}
if ([string]::IsNullOrWhiteSpace($SourceRoot)) {
    $SourceRoot = Join-Path $projectRoot "work\punch-wall-rpg\src"
}
if ([string]::IsNullOrWhiteSpace($ManifestPath)) {
    $ManifestPath = Join-Path $projectRoot "outputs\SmashWall_Production.build.json"
}
$outputsRoot = [System.IO.Path]::GetFullPath((Join-Path $projectRoot "outputs"))
$canonicalFinal = [System.IO.Path]::GetFullPath(
    (Join-Path $outputsRoot "PunchWallRPGPlayable_v1_final.rbxlx")
)
$resolvedSource = [System.IO.Path]::GetFullPath($SourcePlace)
$resolvedOutput = [System.IO.Path]::GetFullPath($OutputPlace)
$resolvedManifest = [System.IO.Path]::GetFullPath($ManifestPath)
$resolvedSourceRoot = [System.IO.Path]::GetFullPath($SourceRoot)

foreach ($path in @($resolvedSource, $resolvedOutput, $resolvedManifest, $resolvedSourceRoot)) {
    if (-not ($path.Equals($projectRoot, [System.StringComparison]::OrdinalIgnoreCase) -or $path.StartsWith($projectRoot.TrimEnd("\") + "\", [System.StringComparison]::OrdinalIgnoreCase))) {
        throw "Production build paths must remain under $projectRoot"
    }
}

$outputsPrefix = $outputsRoot.TrimEnd("\") + "\"
if (-not $resolvedOutput.StartsWith($outputsPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Production output must remain under $outputsRoot"
}
if ([System.IO.Path]::GetExtension($resolvedSource) -ine ".rbxlx") {
    throw "SourcePlace must use the .rbxlx extension: $resolvedSource"
}
if ([System.IO.Path]::GetExtension($resolvedOutput) -ine ".rbxlx") {
    throw "OutputPlace must use the .rbxlx extension: $resolvedOutput"
}
if (
    $resolvedOutput.Equals($canonicalFinal, [System.StringComparison]::OrdinalIgnoreCase) -and
    -not $AllowCanonicalFinalOutput
) {
    throw "Refusing to overwrite the canonical final RBXLX without -AllowCanonicalFinalOutput"
}
if (-not $resolvedManifest.StartsWith($outputsPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Production manifest must remain under $outputsRoot"
}
$expectedSourceRoot = [System.IO.Path]::GetFullPath((Join-Path $projectRoot "work\punch-wall-rpg\src"))
if (-not $resolvedSourceRoot.Equals($expectedSourceRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Production SourceRoot must be current worktree source: $expectedSourceRoot"
}
if (-not (Test-Path -LiteralPath $resolvedSource -PathType Leaf)) {
    throw "Source place not found: $resolvedSource"
}
if (-not (Test-Path -LiteralPath $resolvedSourceRoot -PathType Container)) {
    throw "Rojo source root not found: $resolvedSourceRoot"
}
if ($resolvedSource.Equals($resolvedOutput, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "SourcePlace and OutputPlace must be different files"
}
if (
    $resolvedManifest.Equals($resolvedSource, [System.StringComparison]::OrdinalIgnoreCase) -or
    $resolvedManifest.Equals($resolvedOutput, [System.StringComparison]::OrdinalIgnoreCase)
) {
    throw "ManifestPath must be distinct from SourcePlace and OutputPlace"
}
foreach ($parentPath in @(
    [System.IO.Path]::GetDirectoryName($resolvedOutput),
    [System.IO.Path]::GetDirectoryName($resolvedManifest)
)) {
    if (-not (Test-Path -LiteralPath $parentPath -PathType Container)) {
        throw "Build destination directory does not exist: $parentPath"
    }
}

$requiredSources = @(
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
$expectedEmbeddedNames = @(
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
foreach ($relativePath in $requiredSources) {
    $sourcePath = Join-Path $resolvedSourceRoot $relativePath
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Required production source missing: $sourcePath"
    }
}

$serverSource = [System.IO.File]::ReadAllText(
    (Join-Path $resolvedSourceRoot "server\PunchWallBootstrap.server.lua")
)
if (-not $serverSource.Contains("if RunService:IsStudio() then")) {
    throw "Studio-only test harness guard is missing from the server source"
}

$embedScript = Join-Path $PSScriptRoot "embed-source-into-rbxlx.ps1"
$verifyScript = Join-Path $PSScriptRoot "verify-exact-rbxlx-sources.ps1"
$temporaryOutput = "$resolvedOutput.codex-$([Guid]::NewGuid().ToString('N')).tmp.rbxlx"
try {
    Copy-Item -LiteralPath $resolvedSource -Destination $temporaryOutput

    $embedResultText = & $embedScript -PlacePath $temporaryOutput -SourceRoot $resolvedSourceRoot
    $embedResult = $embedResultText | ConvertFrom-Json
    if (-not $embedResult.ok) {
        throw "Source embedding did not report a successful production build"
    }
    if (
        [int]$embedResult.sourceMapCount -ne $expectedEmbeddedNames.Count -or
        $embedResult.cdataPreserved -ne $true
    ) {
        throw "Embedder did not prove the complete CDATA-preserving source map"
    }
    $embeddedNames = @($embedResult.updated)
    if (
        $embeddedNames.Count -ne $expectedEmbeddedNames.Count -or
        @(Compare-Object -ReferenceObject $expectedEmbeddedNames -DifferenceObject $embeddedNames).Count -ne 0
    ) {
        throw "Embedded source set does not match the canonical nine-module map"
    }

    $temporaryContract = (& $verifyScript -PlacePath $temporaryOutput -SourceRoot $resolvedSourceRoot) |
        ConvertFrom-Json
    if (
        -not $temporaryContract.ok -or
        [int]$temporaryContract.moduleCount -ne $expectedEmbeddedNames.Count -or
        $temporaryContract.cdataPreserved -ne $true
    ) {
        throw "Independent exact-source verification failed for the temporary build"
    }
    foreach ($name in $expectedEmbeddedNames) {
        $embeddedHash = [string]$embedResult.exactSources.$name
        $verifiedModule = $temporaryContract.modules.PSObject.Properties[$name]
        if ($null -eq $verifiedModule) {
            throw "Independent verifier did not return module: $name"
        }
        $verifiedHash = [string]$verifiedModule.Value.normalizedSha256
        $sourceFileHash = [string]$verifiedModule.Value.sourceFileSha256
        if (
            [string]::IsNullOrWhiteSpace($embeddedHash) -or
            $embeddedHash -ne $verifiedHash -or
            [string]$embedResult.sourceFileSha256.$name -ne $sourceFileHash
        ) {
            throw "Embedder/verifier source hash disagreement for $name"
        }
    }

    $temporaryInfo = Get-Item -LiteralPath $temporaryOutput
    if ($temporaryInfo.Length -lt 1000000) {
        throw "Production place is unexpectedly small: $($temporaryInfo.Length) bytes"
    }
    $hash = [string]$temporaryContract.rbxlxSha256
    $templateHash = (Get-FileHash -LiteralPath $resolvedSource -Algorithm SHA256).Hash
    Move-Item -LiteralPath $temporaryOutput -Destination $resolvedOutput -Force
}
finally {
    if (Test-Path -LiteralPath $temporaryOutput -PathType Leaf) {
        Remove-Item -LiteralPath $temporaryOutput -Force
    }
}
$mappedSourcePaths = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase
)
foreach ($relativePath in $requiredSources) {
    [void]$mappedSourcePaths.Add(
        [System.IO.Path]::GetFullPath((Join-Path $resolvedSourceRoot $relativePath))
    )
}
$actualSourcePaths = @(
    Get-ChildItem -LiteralPath $resolvedSourceRoot -Recurse -File -Filter "*.lua" |
        ForEach-Object { [System.IO.Path]::GetFullPath($_.FullName) }
)
if ($actualSourcePaths.Count -ne $mappedSourcePaths.Count) {
    throw "Production source map must cover exactly $($mappedSourcePaths.Count) Lua files; found $($actualSourcePaths.Count)"
}
foreach ($actualSourcePath in $actualSourcePaths) {
    if (-not $mappedSourcePaths.Contains($actualSourcePath)) {
        throw "Unmapped production source file: $actualSourcePath"
    }
}

$outputInfo = Get-Item -LiteralPath $resolvedOutput
$publishedHash = (Get-FileHash -LiteralPath $resolvedOutput -Algorithm SHA256).Hash
if ($publishedHash -ne $hash) {
    throw "Published production output hash differs from the verified temporary build"
}
$publishedContract = (& $verifyScript -PlacePath $resolvedOutput -SourceRoot $resolvedSourceRoot) |
    ConvertFrom-Json
if (
    -not $publishedContract.ok -or
    [int]$publishedContract.moduleCount -ne $expectedEmbeddedNames.Count -or
    [string]$publishedContract.rbxlxSha256 -ne $hash
) {
    throw "Published production output failed post-write exact-source verification"
}
$gameConfig = [System.IO.File]::ReadAllText(
    (Join-Path $resolvedSourceRoot "shared\GameConfig.lua")
)
$configuredGamePasses = ([regex]::Matches($gameConfig, "gamePassId\s*=\s*(?!0\b)\d+")).Count
$configuredProducts = ([regex]::Matches($gameConfig, "productId\s*=\s*(?!0\b)\d+")).Count

$manifest = [ordered]@{
    ok = $true
    game = "Smash Wall"
    branch = (git -C $projectRoot branch --show-current).Trim()
    sourceCommit = (git -C $projectRoot rev-parse HEAD).Trim()
    sourcePlace = $resolvedSource
    outputPlace = $resolvedOutput
    sourceRoot = $resolvedSourceRoot
    bytes = $outputInfo.Length
    sha256 = $hash
    templateSha256 = $templateHash
    sourceMapVersion = 1
    embeddedModuleCount = $expectedEmbeddedNames.Count
    embeddedScripts = $embeddedNames
    exactSourceSha256 = $embedResult.exactSources
    sourceFileSha256 = $embedResult.sourceFileSha256
    cdataPreserved = $true
    configuredGamePasses = $configuredGamePasses
    configuredDeveloperProducts = $configuredProducts
    studioHarnessGuarded = $true
    generatedAtUtc = [DateTime]::UtcNow.ToString("o")
}

$manifestJson = $manifest | ConvertTo-Json -Depth 4
$temporaryManifest = "$resolvedManifest.codex-$([Guid]::NewGuid().ToString('N')).tmp"
try {
    [System.IO.File]::WriteAllText(
        $temporaryManifest,
        $manifestJson + [Environment]::NewLine,
        [System.Text.UTF8Encoding]::new($false)
    )
    Move-Item -LiteralPath $temporaryManifest -Destination $resolvedManifest -Force
}
finally {
    if (Test-Path -LiteralPath $temporaryManifest -PathType Leaf) {
        Remove-Item -LiteralPath $temporaryManifest -Force
    }
}

$manifestJson
