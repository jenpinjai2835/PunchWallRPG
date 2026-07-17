param(
    [string]$SourcePlace = "F:\Roblox\PuchWall\outputs\PunchWallRPGPlayable_v1_final.rbxlx",
    [string]$OutputPlace = "F:\Roblox\PuchWall\outputs\SmashWall_Production.rbxlx",
    [string]$SourceRoot = "F:\Roblox\PuchWall\work\punch-wall-rpg\src",
    [string]$ManifestPath = "F:\Roblox\PuchWall\outputs\SmashWall_Production.build.json"
)

$ErrorActionPreference = "Stop"

$projectRoot = [System.IO.Path]::GetFullPath("F:\Roblox\PuchWall")
$outputsRoot = [System.IO.Path]::GetFullPath((Join-Path $projectRoot "outputs"))
$resolvedSource = [System.IO.Path]::GetFullPath($SourcePlace)
$resolvedOutput = [System.IO.Path]::GetFullPath($OutputPlace)
$resolvedManifest = [System.IO.Path]::GetFullPath($ManifestPath)
$resolvedSourceRoot = [System.IO.Path]::GetFullPath($SourceRoot)

foreach ($path in @($resolvedSource, $resolvedOutput, $resolvedManifest, $resolvedSourceRoot)) {
    if (-not $path.StartsWith($projectRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Production build paths must remain under $projectRoot"
    }
}

if (-not $resolvedOutput.StartsWith($outputsRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Production output must remain under $outputsRoot"
}
if (-not $resolvedManifest.StartsWith($outputsRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Production manifest must remain under $outputsRoot"
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

$requiredSources = @(
    "shared\GameConfig.lua",
    "shared\PolishConfig.lua",
    "shared\ForestVisualBuilder.lua",
    "shared\FistVisualBuilder.lua",
    "server\PunchWallBootstrap.server.lua",
    "client\PunchWallClient.client.lua"
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

Copy-Item -LiteralPath $resolvedSource -Destination $resolvedOutput -Force

$embedScript = Join-Path $projectRoot "work\automation\embed-source-into-rbxlx.ps1"
$embedResultText = & $embedScript -PlacePath $resolvedOutput -SourceRoot $resolvedSourceRoot
$embedResult = $embedResultText | ConvertFrom-Json
if (-not $embedResult.ok) {
    throw "Source embedding did not report a successful production build"
}

$document = [System.Xml.XmlDocument]::new()
$document.Load($resolvedOutput)

$embeddedNames = @(
    "GameConfig",
    "PolishConfig",
    "ForestVisualBuilder",
    "FistVisualBuilder",
    "PunchWallBootstrap",
    "PunchWallClient"
)
foreach ($name in $embeddedNames) {
    $item = $document.SelectSingleNode(
        "//Item[Properties/string[@name='Name' and text()='$name']]"
    )
    if ($null -eq $item) {
        throw "Embedded production script missing: $name"
    }
    $sourceNode = $item.SelectSingleNode("Properties/ProtectedString[@name='Source']")
    if ($null -eq $sourceNode -or [string]::IsNullOrWhiteSpace($sourceNode.InnerText)) {
        throw "Embedded production script has no source: $name"
    }
}

$outputInfo = Get-Item -LiteralPath $resolvedOutput
if ($outputInfo.Length -lt 1000000) {
    throw "Production place is unexpectedly small: $($outputInfo.Length) bytes"
}

$hash = (Get-FileHash -LiteralPath $resolvedOutput -Algorithm SHA256).Hash
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
    embeddedScripts = $embeddedNames
    configuredGamePasses = $configuredGamePasses
    configuredDeveloperProducts = $configuredProducts
    studioHarnessGuarded = $true
    generatedAtUtc = [DateTime]::UtcNow.ToString("o")
}

$manifestJson = $manifest | ConvertTo-Json -Depth 4
[System.IO.File]::WriteAllText(
    $resolvedManifest,
    $manifestJson + [Environment]::NewLine,
    [System.Text.UTF8Encoding]::new($false)
)

$manifestJson
