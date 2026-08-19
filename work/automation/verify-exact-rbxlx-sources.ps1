param(
    [string]$PlacePath = "",
    [string]$SourceRoot = ""
)

$ErrorActionPreference = "Stop"

$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
if ([string]::IsNullOrWhiteSpace($PlacePath)) {
    $PlacePath = Join-Path $repositoryRoot "outputs\PunchWallRPGPlayable_v1_final.rbxlx"
}
if ([string]::IsNullOrWhiteSpace($SourceRoot)) {
    $SourceRoot = Join-Path $repositoryRoot "work\punch-wall-rpg\src"
}
$resolvedPlace = [System.IO.Path]::GetFullPath($PlacePath)
$resolvedSourceRoot = [System.IO.Path]::GetFullPath($SourceRoot)
$repositoryPrefix = $repositoryRoot.TrimEnd("\") + "\"
$expectedSourceRoot = [System.IO.Path]::GetFullPath((Join-Path $repositoryRoot "work\punch-wall-rpg\src"))

if (-not $resolvedPlace.StartsWith($repositoryPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "PlacePath must remain under current worktree $repositoryRoot"
}
if ([System.IO.Path]::GetExtension($resolvedPlace) -ine ".rbxlx") {
    throw "PlacePath must use the .rbxlx extension: $resolvedPlace"
}
if (-not $resolvedSourceRoot.Equals($expectedSourceRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "SourceRoot must be current worktree source: $expectedSourceRoot"
}
if (-not (Test-Path -LiteralPath $resolvedPlace -PathType Leaf)) {
    throw "RBXLX place not found: $resolvedPlace"
}

$mappings = [ordered]@{
    GameConfig = [pscustomobject]@{ Path = "shared\GameConfig.lua"; Class = "ModuleScript"; Parent = "ReplicatedStorage"; ParentClass = "ReplicatedStorage"; Service = "ReplicatedStorage"; ServiceClass = "ReplicatedStorage" }
    PolishConfig = [pscustomobject]@{ Path = "shared\PolishConfig.lua"; Class = "ModuleScript"; Parent = "ReplicatedStorage"; ParentClass = "ReplicatedStorage"; Service = "ReplicatedStorage"; ServiceClass = "ReplicatedStorage" }
    ForestVisualBuilder = [pscustomobject]@{ Path = "shared\ForestVisualBuilder.lua"; Class = "ModuleScript"; Parent = "ReplicatedStorage"; ParentClass = "ReplicatedStorage"; Service = "ReplicatedStorage"; ServiceClass = "ReplicatedStorage" }
    FistVisualBuilder = [pscustomobject]@{ Path = "shared\FistVisualBuilder.lua"; Class = "ModuleScript"; Parent = "ReplicatedStorage"; ParentClass = "ReplicatedStorage"; Service = "ReplicatedStorage"; ServiceClass = "ReplicatedStorage" }
    InventoryViewModel = [pscustomobject]@{ Path = "shared\InventoryViewModel.lua"; Class = "ModuleScript"; Parent = "ReplicatedStorage"; ParentClass = "ReplicatedStorage"; Service = "ReplicatedStorage"; ServiceClass = "ReplicatedStorage" }
    ProfilePersistence = [pscustomobject]@{ Path = "server\ProfilePersistence.lua"; Class = "ModuleScript"; Parent = "ServerScriptService"; ParentClass = "ServerScriptService"; Service = "ServerScriptService"; ServiceClass = "ServerScriptService" }
    PunchWallBootstrap = [pscustomobject]@{ Path = "server\PunchWallBootstrap.server.lua"; Class = "Script"; Parent = "ServerScriptService"; ParentClass = "ServerScriptService"; Service = "ServerScriptService"; ServiceClass = "ServerScriptService" }
    InventoryUI = [pscustomobject]@{ Path = "client\InventoryUI.lua"; Class = "ModuleScript"; Parent = "StarterPlayerScripts"; ParentClass = "StarterPlayerScripts"; Service = "StarterPlayer"; ServiceClass = "StarterPlayer" }
    PunchWallClient = [pscustomobject]@{ Path = "client\PunchWallClient.client.lua"; Class = "LocalScript"; Parent = "StarterPlayerScripts"; ParentClass = "StarterPlayerScripts"; Service = "StarterPlayer"; ServiceClass = "StarterPlayer" }
}

function Assert-ExactSourceMap {
    $expectedPaths = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
    foreach ($definition in $mappings.Values) {
        $fullPath = [System.IO.Path]::GetFullPath((Join-Path $resolvedSourceRoot $definition.Path))
        if (-not $fullPath.StartsWith($resolvedSourceRoot.TrimEnd("\") + "\", [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Mapped source escaped current worktree: $fullPath"
        }
        if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
            throw "Mapped source missing: $fullPath"
        }
        if (-not $expectedPaths.Add($fullPath)) {
            throw "Duplicate source mapping: $fullPath"
        }
    }
    $actualPaths = @(
        Get-ChildItem -LiteralPath $resolvedSourceRoot -Recurse -File -Filter "*.lua" |
            ForEach-Object { [System.IO.Path]::GetFullPath($_.FullName) }
    )
    if ($actualPaths.Count -ne $expectedPaths.Count) {
        throw "Source map must cover exactly $($expectedPaths.Count) Lua files; found $($actualPaths.Count)"
    }
    foreach ($actualPath in $actualPaths) {
        if (-not $expectedPaths.Contains($actualPath)) {
            throw "Unmapped production source file: $actualPath"
        }
    }
}

function Read-SafeXmlDocument([string]$Path) {
    $readerSettings = [System.Xml.XmlReaderSettings]::new()
    $readerSettings.DtdProcessing = [System.Xml.DtdProcessing]::Prohibit
    $readerSettings.XmlResolver = $null
    $reader = [System.Xml.XmlReader]::Create($Path, $readerSettings)
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

function Normalize-SourceText([string]$Value) {
    return [regex]::Replace($Value, "\r\n?", "`n")
}

function Get-SourceTextHash([string]$Value) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes((Normalize-SourceText $Value))
        return ([System.BitConverter]::ToString($sha.ComputeHash($bytes))).Replace("-", "")
    }
    finally {
        $sha.Dispose()
    }
}

function Get-ItemName([System.Xml.XmlElement]$Item) {
    $node = $Item.SelectSingleNode("Properties/string[@name='Name']")
    if ($null -eq $node) { return "" }
    return $node.InnerText
}

function Resolve-ExpectedParent(
    [System.Xml.XmlDocument]$Document,
    [pscustomobject]$Definition
) {
    $serviceMatches = @($Document.DocumentElement.SelectNodes(
        "Item[@class='$($Definition.ServiceClass)'][Properties/string[@name='Name' and text()='$($Definition.Service)']]"
    ))
    if ($serviceMatches.Count -ne 1) {
        throw "Expected exactly one root service $($Definition.ServiceClass) '$($Definition.Service)', found $($serviceMatches.Count)"
    }
    $service = $serviceMatches[0]
    if ($Definition.Parent -eq $Definition.Service -and $Definition.ParentClass -eq $Definition.ServiceClass) {
        return $service
    }
    $parentMatches = @($service.SelectNodes(
        "Item[@class='$($Definition.ParentClass)'][Properties/string[@name='Name' and text()='$($Definition.Parent)']]"
    ))
    if ($parentMatches.Count -ne 1) {
        throw "Expected exactly one $($Definition.ParentClass) '$($Definition.Parent)' directly under $($Definition.Service), found $($parentMatches.Count)"
    }
    return $parentMatches[0]
}

Assert-ExactSourceMap
$document = Read-SafeXmlDocument $resolvedPlace
$verified = [ordered]@{}
foreach ($entry in $mappings.GetEnumerator()) {
    $name = $entry.Key
    $definition = $entry.Value
    $sourcePath = [System.IO.Path]::GetFullPath((Join-Path $resolvedSourceRoot $definition.Path))
    if (-not $sourcePath.StartsWith($resolvedSourceRoot.TrimEnd("\") + "\", [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Mapped source escaped current worktree: $sourcePath"
    }
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Mapped source missing: $sourcePath"
    }
    $items = @($document.SelectNodes("//Item[Properties/string[@name='Name' and text()='$name']]"))
    if ($items.Count -ne 1) {
        throw "Expected exactly one Item named $name, found $($items.Count)"
    }
    if ($items[0].GetAttribute("class") -ne $definition.Class) {
        throw "$name has class '$($items[0].GetAttribute("class"))', expected '$($definition.Class)'"
    }
    $expectedParent = Resolve-ExpectedParent $document $definition
    if (-not [object]::ReferenceEquals($items[0].ParentNode, $expectedParent)) {
        $parentName = Get-ItemName $items[0].ParentNode
        throw "$name is embedded under '$parentName' ($($items[0].ParentNode.GetAttribute('class'))), expected exact $($definition.Service)/$($definition.Parent) service path"
    }
    $sourceNode = $items[0].SelectSingleNode("Properties/ProtectedString[@name='Source']")
    if ($null -eq $sourceNode) {
        throw "Embedded Source property missing for $name"
    }
    if (
        $sourceNode.ChildNodes.Count -ne 1 -or
        $sourceNode.FirstChild.NodeType -ne [System.Xml.XmlNodeType]::CDATA
    ) {
        throw "Embedded Source must be represented by exactly one CDATA node: $name"
    }
    $expected = Normalize-SourceText ([System.IO.File]::ReadAllText($sourcePath))
    $actual = Normalize-SourceText $sourceNode.InnerText
    if (-not $actual.Equals($expected, [System.StringComparison]::Ordinal)) {
        throw "Embedded source differs from current worktree file: $name"
    }
    $verified[$name] = [ordered]@{
        source = $sourcePath
        service = $definition.Service
        parent = $definition.Parent
        parentClass = $definition.ParentClass
        characters = $expected.Length
        normalizedSha256 = Get-SourceTextHash $expected
        sourceFileSha256 = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
        cdata = $true
    }
}

[pscustomobject]@{
    ok = $true
    sourceMapVersion = 1
    repositoryRoot = $repositoryRoot
    place = $resolvedPlace
    fileName = [System.IO.Path]::GetFileName($resolvedPlace)
    rbxlxSha256 = (Get-FileHash -LiteralPath $resolvedPlace -Algorithm SHA256).Hash
    moduleCount = $verified.Count
    cdataPreserved = $true
    modules = $verified
} | ConvertTo-Json -Depth 6
