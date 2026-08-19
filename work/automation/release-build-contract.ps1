[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$automationRoot = $PSScriptRoot
$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $automationRoot "..\.."))
$outputsRoot = [System.IO.Path]::GetFullPath((Join-Path $repositoryRoot "outputs"))
$sourceRoot = [System.IO.Path]::GetFullPath(
    (Join-Path $repositoryRoot "work\punch-wall-rpg\src")
)
$canonicalFinal = [System.IO.Path]::GetFullPath(
    (Join-Path $outputsRoot "PunchWallRPGPlayable_v1_final.rbxlx")
)
$contractRoot = [System.IO.Path]::GetFullPath(
    (Join-Path $outputsRoot (".codex-release-contract-" + [Guid]::NewGuid().ToString("N")))
)
$outputsPrefix = $outputsRoot.TrimEnd("\") + "\"
$contractLeaf = [System.IO.Path]::GetFileName($contractRoot)

if (
    -not $contractRoot.StartsWith($outputsPrefix, [System.StringComparison]::OrdinalIgnoreCase) -or
    -not $contractLeaf.StartsWith(".codex-release-contract-", [System.StringComparison]::Ordinal)
) {
    throw "Unsafe release-contract directory: $contractRoot"
}
if (-not (Test-Path -LiteralPath $canonicalFinal -PathType Leaf)) {
    throw "Canonical final template is missing: $canonicalFinal"
}

$buildScript = Join-Path $automationRoot "build-production.ps1"
$embedScript = Join-Path $automationRoot "embed-source-into-rbxlx.ps1"
$verifyScript = Join-Path $automationRoot "verify-exact-rbxlx-sources.ps1"
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

function Read-SafeXmlDocument([string]$Path) {
    $settings = [System.Xml.XmlReaderSettings]::new()
    $settings.DtdProcessing = [System.Xml.DtdProcessing]::Prohibit
    $settings.XmlResolver = $null
    $reader = [System.Xml.XmlReader]::Create($Path, $settings)
    try {
        $document = [System.Xml.XmlDocument]::new()
        $document.PreserveWhitespace = $true
        $document.XmlResolver = $null
        $document.Load($reader)
        return $document
    }
    finally {
        $reader.Dispose()
    }
}

function Save-XmlDocument([System.Xml.XmlDocument]$Document, [string]$Path) {
    $settings = [System.Xml.XmlWriterSettings]::new()
    $settings.Encoding = [System.Text.UTF8Encoding]::new($false)
    $settings.Indent = $false
    $settings.NewLineHandling = [System.Xml.NewLineHandling]::None
    $writer = [System.Xml.XmlWriter]::Create($Path, $settings)
    try {
        $Document.Save($writer)
    }
    finally {
        $writer.Dispose()
    }
}

function Assert-Throws([scriptblock]$Action, [string]$ExpectedPattern) {
    try {
        & $Action | Out-Null
    }
    catch {
        if ($_.Exception.Message -notmatch $ExpectedPattern) {
            throw "Expected failure '$ExpectedPattern', received: $($_.Exception.Message)"
        }
        return
    }
    throw "Expected action to fail with '$ExpectedPattern'"
}

$canonicalHashBefore = (Get-FileHash -LiteralPath $canonicalFinal -Algorithm SHA256).Hash
$contractResult = $null
try {
    [void](New-Item -ItemType Directory -Path $contractRoot)
    $builtPlace = Join-Path $contractRoot "PunchWallRPGPlayable_v1_contract_validation.rbxlx"
    $manifestPath = Join-Path $contractRoot "PunchWallRPGPlayable_v1_contract_validation.build.json"

    $buildResult = (& $buildScript `
        -SourcePlace $canonicalFinal `
        -OutputPlace $builtPlace `
        -SourceRoot $sourceRoot `
        -ManifestPath $manifestPath) | ConvertFrom-Json
    if (
        -not $buildResult.ok -or
        [int]$buildResult.embeddedModuleCount -ne $expectedModules.Count -or
        $buildResult.cdataPreserved -ne $true
    ) {
        throw "Disposable production build did not prove the exact source map"
    }

    $verification = (& $verifyScript -PlacePath $builtPlace -SourceRoot $sourceRoot) |
        ConvertFrom-Json
    if (
        -not $verification.ok -or
        [int]$verification.moduleCount -ne $expectedModules.Count -or
        $verification.cdataPreserved -ne $true
    ) {
        throw "Disposable production build failed exact-source verification"
    }
    $verifiedNames = @($verification.modules.PSObject.Properties.Name)
    if (
        $verifiedNames.Count -ne $expectedModules.Count -or
        @(Compare-Object -ReferenceObject $expectedModules -DifferenceObject $verifiedNames).Count -ne 0
    ) {
        throw "Disposable production build returned a non-canonical module set"
    }

    $manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
    if (
        [string]$manifest.sha256 -ne [string]$verification.rbxlxSha256 -or
        [int]$manifest.embeddedModuleCount -ne $expectedModules.Count -or
        $manifest.cdataPreserved -ne $true
    ) {
        throw "Build manifest does not match the verified disposable RBXLX"
    }

    $document = Read-SafeXmlDocument $builtPlace
    $cdataCount = 0
    foreach ($name in $expectedModules) {
        $items = @($document.SelectNodes(
            "//Item[Properties/string[@name='Name' and text()='$name']]"
        ))
        if ($items.Count -ne 1) {
            throw "Contract expected exactly one embedded Item named $name"
        }
        $sourceNode = $items[0].SelectSingleNode("Properties/ProtectedString[@name='Source']")
        if (
            $null -eq $sourceNode -or
            $sourceNode.ChildNodes.Count -ne 1 -or
            $sourceNode.FirstChild.NodeType -ne [System.Xml.XmlNodeType]::CDATA
        ) {
            throw "Contract source CDATA check failed for $name"
        }
        $cdataCount += 1
    }

    Assert-Throws {
        & $embedScript -PlacePath $canonicalFinal -SourceRoot $sourceRoot
    } "Refusing to overwrite the canonical final RBXLX"

    Assert-Throws {
        & $buildScript `
            -SourcePlace $builtPlace `
            -OutputPlace $canonicalFinal `
            -SourceRoot $sourceRoot `
            -ManifestPath (Join-Path $contractRoot "forbidden-final.build.json")
    } "Refusing to overwrite the canonical final RBXLX"

    Assert-Throws {
        & $buildScript `
            -SourcePlace $canonicalFinal `
            -OutputPlace (Join-Path $contractRoot "wrong-source-root.rbxlx") `
            -SourceRoot $automationRoot `
            -ManifestPath (Join-Path $contractRoot "wrong-source-root.build.json")
    } "SourceRoot must be current worktree source"

    $tamperedPlace = Join-Path $contractRoot "tampered-source.rbxlx"
    Copy-Item -LiteralPath $builtPlace -Destination $tamperedPlace
    $tamperedDocument = Read-SafeXmlDocument $tamperedPlace
    $tamperedSource = $tamperedDocument.SelectSingleNode(
        "//Item[Properties/string[@name='Name' and text()='GameConfig']]/Properties/ProtectedString[@name='Source']"
    )
    $tamperedSource.FirstChild.Value += "`n-- release contract tamper"
    Save-XmlDocument $tamperedDocument $tamperedPlace
    Assert-Throws {
        & $verifyScript -PlacePath $tamperedPlace -SourceRoot $sourceRoot
    } "Embedded source differs from current worktree file"

    $duplicatePlace = Join-Path $contractRoot "duplicate-module.rbxlx"
    Copy-Item -LiteralPath $builtPlace -Destination $duplicatePlace
    $duplicateDocument = Read-SafeXmlDocument $duplicatePlace
    $viewModel = $duplicateDocument.SelectSingleNode(
        "//Item[Properties/string[@name='Name' and text()='InventoryViewModel']]"
    )
    [void]$viewModel.ParentNode.AppendChild($viewModel.CloneNode($true))
    Save-XmlDocument $duplicateDocument $duplicatePlace
    Assert-Throws {
        & $verifyScript -PlacePath $duplicatePlace -SourceRoot $sourceRoot
    } "Expected exactly one Item named InventoryViewModel"

    $wrongParentPlace = Join-Path $contractRoot "wrong-parent.rbxlx"
    Copy-Item -LiteralPath $builtPlace -Destination $wrongParentPlace
    $wrongParentDocument = Read-SafeXmlDocument $wrongParentPlace
    $inventoryUi = $wrongParentDocument.SelectSingleNode(
        "//Item[Properties/string[@name='Name' and text()='InventoryUI']]"
    )
    $replicatedStorage = $wrongParentDocument.DocumentElement.SelectSingleNode(
        "Item[@class='ReplicatedStorage'][Properties/string[@name='Name' and text()='ReplicatedStorage']]"
    )
    [void]$replicatedStorage.AppendChild($inventoryUi)
    Save-XmlDocument $wrongParentDocument $wrongParentPlace
    Assert-Throws {
        & $verifyScript -PlacePath $wrongParentPlace -SourceRoot $sourceRoot
    } "expected exact StarterPlayer/StarterPlayerScripts service path"

    $canonicalHashAfterBuild = (Get-FileHash -LiteralPath $canonicalFinal -Algorithm SHA256).Hash
    if ($canonicalHashAfterBuild -ne $canonicalHashBefore) {
        throw "Canonical final RBXLX changed during disposable build verification"
    }

    $contractResult = [ordered]@{
        ok = $true
        studioUsed = $false
        sourceMapVersion = 1
        moduleCount = $verification.moduleCount
        cdataCount = $cdataCount
        disposableBytes = (Get-Item -LiteralPath $builtPlace).Length
        disposableSha256 = $verification.rbxlxSha256
        canonicalFinalSha256 = $canonicalHashBefore
        negativeChecks = @(
            "canonical_embed_guard",
            "canonical_build_guard",
            "worktree_source_root_guard",
            "tampered_source_rejected",
            "duplicate_module_rejected",
            "wrong_parent_rejected"
        )
    }
}
finally {
    $canonicalHashAfter = (Get-FileHash -LiteralPath $canonicalFinal -Algorithm SHA256).Hash
    if (
        $contractRoot.StartsWith($outputsPrefix, [System.StringComparison]::OrdinalIgnoreCase) -and
        [System.IO.Path]::GetFileName($contractRoot).StartsWith(
            ".codex-release-contract-",
            [System.StringComparison]::Ordinal
        ) -and
        (Test-Path -LiteralPath $contractRoot -PathType Container)
    ) {
        Remove-Item -LiteralPath $contractRoot -Recurse -Force
    }
    if ($canonicalHashAfter -ne $canonicalHashBefore) {
        throw "Canonical final RBXLX hash changed during release build contract"
    }
}

$contractResult | ConvertTo-Json -Depth 6
