param(
    [string]$PlacePath = "F:\Roblox\PuchWall\outputs\PunchWallRPGPlayable_v1_final.rbxlx",
    [string]$SourceRoot = "F:\Roblox\PuchWall\work\punch-wall-rpg\src"
)

$ErrorActionPreference = "Stop"

$resolvedPlace = [System.IO.Path]::GetFullPath($PlacePath)
$allowedRoot = [System.IO.Path]::GetFullPath("F:\Roblox\PuchWall")
if (-not $resolvedPlace.StartsWith($allowedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Place path must remain under $allowedRoot"
}
if (-not (Test-Path -LiteralPath $resolvedPlace -PathType Leaf)) {
    throw "Place file not found: $resolvedPlace"
}

$sources = [ordered]@{
    GameConfig = Join-Path $SourceRoot "shared\GameConfig.lua"
    PolishConfig = Join-Path $SourceRoot "shared\PolishConfig.lua"
    PunchWallBootstrap = Join-Path $SourceRoot "server\PunchWallBootstrap.server.lua"
    PunchWallClient = Join-Path $SourceRoot "client\PunchWallClient.client.lua"
}

$document = [System.Xml.XmlDocument]::new()
$document.PreserveWhitespace = $true
$document.Load($resolvedPlace)

$updated = @()
foreach ($entry in $sources.GetEnumerator()) {
    $sourcePath = [System.IO.Path]::GetFullPath($entry.Value)
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Source file not found: $sourcePath"
    }

    $item = $document.SelectSingleNode("//Item[Properties/string[@name='Name' and text()='$($entry.Key)']]")
    if ($null -eq $item) {
        throw "Script item not found in place: $($entry.Key)"
    }
    $sourceNode = $item.SelectSingleNode("Properties/ProtectedString[@name='Source']")
    if ($null -eq $sourceNode) {
        throw "Source property not found for script: $($entry.Key)"
    }

    $sourceText = [System.IO.File]::ReadAllText($sourcePath)
    if ($sourceText.Contains("]]>") ) {
        throw "CDATA terminator found in source: $sourcePath"
    }
    $sourceNode.RemoveAll()
    $sourceNode.SetAttribute("name", "Source")
    [void]$sourceNode.AppendChild($document.CreateCDataSection($sourceText))
    $updated += $entry.Key
}

$temporaryPath = "$resolvedPlace.codex-tmp"
$settings = [System.Xml.XmlWriterSettings]::new()
$settings.Encoding = [System.Text.UTF8Encoding]::new($false)
$settings.Indent = $false
$settings.NewLineHandling = [System.Xml.NewLineHandling]::None
$writer = [System.Xml.XmlWriter]::Create($temporaryPath, $settings)
try {
    $document.Save($writer)
}
finally {
    $writer.Dispose()
}

$validation = [System.Xml.XmlDocument]::new()
$validation.Load($temporaryPath)
Move-Item -LiteralPath $temporaryPath -Destination $resolvedPlace -Force

[pscustomobject]@{
    ok = $true
    place = $resolvedPlace
    updated = $updated
    bytes = (Get-Item -LiteralPath $resolvedPlace).Length
} | ConvertTo-Json -Depth 4
