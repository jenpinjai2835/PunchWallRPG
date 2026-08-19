[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Version,

    [string]$SourcePlace = "",
    [string]$OutputDirectory = ""
)

$ErrorActionPreference = "Stop"

$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
$outputsRoot = [System.IO.Path]::GetFullPath((Join-Path $repositoryRoot "outputs"))
$sourceRoot = [System.IO.Path]::GetFullPath(
    (Join-Path $repositoryRoot "work\punch-wall-rpg\src")
)
$versionPattern = '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$'

if ($Version -cnotmatch $versionPattern) {
    throw "Version must be a valid SemVer value such as 1.0.0: $Version"
}
if ([string]::IsNullOrWhiteSpace($SourcePlace)) {
    $SourcePlace = Join-Path $outputsRoot "SmashWall_Production.rbxlx"
}
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $outputsRoot ("releases\v" + $Version)
}

$resolvedSource = [System.IO.Path]::GetFullPath($SourcePlace)
$resolvedOutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)
$outputsPrefix = $outputsRoot.TrimEnd("\") + "\"
if (-not $resolvedSource.StartsWith($outputsPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Release source must remain under $outputsRoot"
}
if (-not $resolvedOutputDirectory.StartsWith($outputsPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Release output must remain under $outputsRoot"
}
if (-not (Test-Path -LiteralPath $resolvedSource -PathType Leaf)) {
    throw "Release source is missing: $resolvedSource"
}
if ([System.IO.Path]::GetExtension($resolvedSource) -ine ".rbxlx") {
    throw "Release source must be an .rbxlx file: $resolvedSource"
}

$verifyScript = Join-Path $PSScriptRoot "verify-exact-rbxlx-sources.ps1"
$sourceContract = (& $verifyScript -PlacePath $resolvedSource -SourceRoot $sourceRoot) |
    ConvertFrom-Json
if (
    -not $sourceContract.ok -or
    [int]$sourceContract.moduleCount -ne 9 -or
    [int]$sourceContract.codeObjectCount -ne 9 -or
    [int]$sourceContract.codeAllowlistVersion -ne 1 -or
    $sourceContract.cdataPreserved -ne $true
) {
    throw "Release source failed the exact nine-code-object contract"
}

$productionManifestPath = Join-Path $outputsRoot "SmashWall_Production.build.json"
if (-not (Test-Path -LiteralPath $productionManifestPath -PathType Leaf)) {
    throw "Production build manifest is missing: $productionManifestPath"
}
$productionManifest = Get-Content -Raw -LiteralPath $productionManifestPath | ConvertFrom-Json
$sourceHash = (Get-FileHash -LiteralPath $resolvedSource -Algorithm SHA256).Hash
if (
    -not $productionManifest.ok -or
    [string]$productionManifest.sha256 -cne $sourceHash -or
    [string]$productionManifest.outputPlace -cne $resolvedSource -or
    [int]$productionManifest.codeObjectCount -ne 9
) {
    throw "Production manifest does not attest the selected release source"
}

if (-not (Test-Path -LiteralPath $resolvedOutputDirectory -PathType Container)) {
    [void](New-Item -ItemType Directory -Path $resolvedOutputDirectory)
}

$releaseName = "SmashWall_v$Version"
$releasePlace = Join-Path $resolvedOutputDirectory ($releaseName + ".rbxlx")
$validationPlace = Join-Path $resolvedOutputDirectory ($releaseName + "_validation.rbxlx")
$manifestPath = Join-Path $resolvedOutputDirectory ($releaseName + ".manifest.json")
$temporaryRelease = Join-Path $resolvedOutputDirectory (
    "." + $releaseName + ".codex-" + [Guid]::NewGuid().ToString("N") + ".tmp.rbxlx"
)
$temporaryValidation = Join-Path $resolvedOutputDirectory (
    "." + $releaseName + "_validation.codex-" + [Guid]::NewGuid().ToString("N") + ".tmp.rbxlx"
)
$temporaryManifest = "$manifestPath.codex-$([Guid]::NewGuid().ToString('N')).tmp"

try {
    Copy-Item -LiteralPath $resolvedSource -Destination $temporaryRelease
    Copy-Item -LiteralPath $resolvedSource -Destination $temporaryValidation

    $releaseHash = (Get-FileHash -LiteralPath $temporaryRelease -Algorithm SHA256).Hash
    $validationHash = (Get-FileHash -LiteralPath $temporaryValidation -Algorithm SHA256).Hash
    if ($releaseHash -cne $sourceHash -or $validationHash -cne $sourceHash) {
        throw "Versioned release copies are not byte-identical to the verified production source"
    }

    $releaseContract = (& $verifyScript -PlacePath $temporaryRelease -SourceRoot $sourceRoot) |
        ConvertFrom-Json
    $validationContract = (& $verifyScript -PlacePath $temporaryValidation -SourceRoot $sourceRoot) |
        ConvertFrom-Json
    if (
        -not $releaseContract.ok -or
        -not $validationContract.ok -or
        [string]$releaseContract.rbxlxSha256 -cne [string]$validationContract.rbxlxSha256 -or
        [int]$releaseContract.codeObjectCount -ne 9 -or
        [int]$validationContract.codeObjectCount -ne 9
    ) {
        throw "Versioned release verification failed"
    }

    $releaseInfo = Get-Item -LiteralPath $temporaryRelease
    $manifest = [ordered]@{
        ok = $true
        game = "Smash Wall"
        releaseVersion = $Version
        releaseChannel = "Release"
        sourceCommit = (git -C $repositoryRoot rev-parse HEAD).Trim()
        branch = (git -C $repositoryRoot branch --show-current).Trim()
        sourceArtifact = $resolvedSource
        sourceArtifactSha256 = $sourceHash
        releaseArtifact = $releasePlace
        validationArtifact = $validationPlace
        bytes = $releaseInfo.Length
        sha256 = $releaseHash
        validationSha256 = $validationHash
        sourceMapVersion = [int]$releaseContract.sourceMapVersion
        codeAllowlistVersion = [int]$releaseContract.codeAllowlistVersion
        embeddedModuleCount = [int]$releaseContract.moduleCount
        codeObjectCount = [int]$releaseContract.codeObjectCount
        configuredGamePasses = [int]$productionManifest.configuredGamePasses
        configuredDeveloperProducts = [int]$productionManifest.configuredDeveloperProducts
        exactSourceSha256 = $productionManifest.exactSourceSha256
        sourceFileSha256 = $productionManifest.sourceFileSha256
        generatedAtUtc = [DateTime]::UtcNow.ToString("o")
    }
    $manifestJson = $manifest | ConvertTo-Json -Depth 5
    [System.IO.File]::WriteAllText(
        $temporaryManifest,
        $manifestJson + [Environment]::NewLine,
        [System.Text.UTF8Encoding]::new($false)
    )

    Move-Item -LiteralPath $temporaryRelease -Destination $releasePlace -Force
    Move-Item -LiteralPath $temporaryValidation -Destination $validationPlace -Force
    Move-Item -LiteralPath $temporaryManifest -Destination $manifestPath -Force
}
finally {
    foreach ($temporaryPath in @($temporaryRelease, $temporaryValidation, $temporaryManifest)) {
        if (Test-Path -LiteralPath $temporaryPath -PathType Leaf) {
            Remove-Item -LiteralPath $temporaryPath -Force
        }
    }
}

Get-Content -Raw -LiteralPath $manifestPath
