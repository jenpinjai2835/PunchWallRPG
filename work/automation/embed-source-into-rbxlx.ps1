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
    GameConfig = [pscustomobject]@{ Path = Join-Path $SourceRoot "shared\GameConfig.lua"; Class = "ModuleScript"; Parent = "ReplicatedStorage" }
    PolishConfig = [pscustomobject]@{ Path = Join-Path $SourceRoot "shared\PolishConfig.lua"; Class = "ModuleScript"; Parent = "ReplicatedStorage" }
    ForestVisualBuilder = [pscustomobject]@{ Path = Join-Path $SourceRoot "shared\ForestVisualBuilder.lua"; Class = "ModuleScript"; Parent = "ReplicatedStorage" }
    FistVisualBuilder = [pscustomobject]@{ Path = Join-Path $SourceRoot "shared\FistVisualBuilder.lua"; Class = "ModuleScript"; Parent = "ReplicatedStorage" }
    PunchWallBootstrap = [pscustomobject]@{ Path = Join-Path $SourceRoot "server\PunchWallBootstrap.server.lua"; Class = "Script"; Parent = "ServerScriptService" }
    PunchWallClient = [pscustomobject]@{ Path = Join-Path $SourceRoot "client\PunchWallClient.client.lua"; Class = "LocalScript"; Parent = "StarterPlayerScripts" }
}

$script:document = [System.Xml.XmlDocument]::new()
$script:document.PreserveWhitespace = $true
$script:document.Load($resolvedPlace)

function Get-ItemName([System.Xml.XmlElement]$Item) {
    $node = $Item.SelectSingleNode("Properties/string[@name='Name']")
    if ($null -eq $node) { return $null }
    return $node.InnerText
}

function Find-Item([string]$Name, [string]$ClassName = "") {
    foreach ($item in $script:document.SelectNodes("//Item")) {
        if ($ClassName -and $item.GetAttribute("class") -ne $ClassName) { continue }
        if ((Get-ItemName $item) -eq $Name) { return $item }
    }
    return $null
}

function New-RobloxId {
    return [Guid]::NewGuid().ToString("N").ToLowerInvariant()
}

function Format-Number([double]$Value) {
    return $Value.ToString("R", [Globalization.CultureInfo]::InvariantCulture)
}

function Set-PropertyText([System.Xml.XmlElement]$Item, [string]$Name, [string]$Value) {
    $node = $Item.SelectSingleNode("Properties/*[@name='$Name']")
    if ($null -eq $node) { throw "Property '$Name' missing on $($Item.GetAttribute('class'))" }
    if ($node.LocalName -eq "Content") {
        $url = $node.SelectSingleNode("url")
        if ($null -eq $url) {
            $node.RemoveAll()
            $node.SetAttribute("name", $Name)
            $url = $script:document.CreateElement("url")
            [void]$node.AppendChild($url)
        }
        $url.InnerText = $Value
    }
    else {
        $node.InnerText = $Value
    }
}

function Set-Vector3([System.Xml.XmlElement]$Item, [string]$Name, [double[]]$Value) {
    $node = $Item.SelectSingleNode("Properties/*[@name='$Name']")
    if ($null -eq $node) { throw "Vector property '$Name' missing" }
    foreach ($component in @(@("X", 0), @("Y", 1), @("Z", 2))) {
        $node.SelectSingleNode($component[0]).InnerText = Format-Number $Value[$component[1]]
    }
}

function Set-CFrame([System.Xml.XmlElement]$Item, [double[]]$Value) {
    $node = $Item.SelectSingleNode("Properties/*[@name='CFrame']")
    if ($null -eq $node) { throw "CFrame property missing" }
    $names = @("X", "Y", "Z", "R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22")
    for ($index = 0; $index -lt $names.Count; $index++) {
        $node.SelectSingleNode($names[$index]).InnerText = Format-Number $Value[$index]
    }
}

function Set-Color([System.Xml.XmlElement]$Item, [double[]]$Color) {
    $red = [Math]::Round([Math]::Min(1, [Math]::Max(0, $Color[0])) * 255)
    $green = [Math]::Round([Math]::Min(1, [Math]::Max(0, $Color[1])) * 255)
    $blue = [Math]::Round([Math]::Min(1, [Math]::Max(0, $Color[2])) * 255)
    $encoded = [uint64]255 * 16777216 + [uint64]$red * 65536 + [uint64]$green * 256 + [uint64]$blue
    Set-PropertyText $Item "Color3uint8" $encoded.ToString([Globalization.CultureInfo]::InvariantCulture)
}

function Clear-ItemChildren([System.Xml.XmlElement]$Item) {
    foreach ($child in @($Item.SelectNodes("Item"))) {
        [void]$Item.RemoveChild($child)
    }
}

function Renew-Item([System.Xml.XmlElement]$Item) {
    $Item.SetAttribute("referent", "RBX$(([Guid]::NewGuid().ToString('N')).ToUpperInvariant())")
    $uniqueId = $Item.SelectSingleNode("Properties/*[@name='UniqueId']")
    if ($null -ne $uniqueId) { $uniqueId.InnerText = New-RobloxId }
    $historyId = $Item.SelectSingleNode("Properties/*[@name='HistoryId']")
    if ($null -ne $historyId) { $historyId.InnerText = "00000000000000000000000000000000" }
    $attributes = $Item.SelectSingleNode("Properties/*[@name='AttributesSerialize']")
    if ($null -ne $attributes) { $attributes.InnerText = "" }
    $sourceAssetId = $Item.SelectSingleNode("Properties/*[@name='SourceAssetId']")
    if ($null -ne $sourceAssetId) { $sourceAssetId.InnerText = "-1" }
    return $Item
}

function Clone-EmptyItem([System.Xml.XmlElement]$Template, [string]$Name) {
    $item = [System.Xml.XmlElement]$Template.CloneNode($true)
    Clear-ItemChildren $item
    [void](Renew-Item $item)
    Set-PropertyText $item "Name" $Name
    return $item
}

function Ensure-ScriptItem([string]$Name, [pscustomobject]$Definition) {
    $item = Find-Item $Name $Definition.Class
    if ($null -eq $item) {
        $template = $script:document.SelectSingleNode("//Item[@class='$($Definition.Class)']")
        if ($null -eq $template) { throw "No $($Definition.Class) template in place" }
        $parent = Find-Item $Definition.Parent
        if ($null -eq $parent) { throw "Parent item not found: $($Definition.Parent)" }
        $item = Clone-EmptyItem $template $Name
        $scriptGuid = $item.SelectSingleNode("Properties/*[@name='ScriptGuid']")
        if ($null -ne $scriptGuid) { $scriptGuid.InnerText = "{$(([Guid]::NewGuid()).ToString().ToUpperInvariant())}" }
        [void]$parent.AppendChild($item)
    }
    return $item
}

function New-StaticMeshPart(
    [System.Xml.XmlElement]$Template,
    [string]$Name,
    [string]$MeshId,
    [string]$TextureId,
    [double[]]$Size,
    [double[]]$CFrame,
    [double[]]$Color,
    [double]$Transparency = 0
) {
    $part = Clone-EmptyItem $Template $Name
    Set-PropertyText $part "MeshId" $MeshId
    Set-PropertyText $part "TextureID" $TextureId
    Set-Vector3 $part "InitialSize" $Size
    Set-Vector3 $part "size" $Size
    Set-CFrame $part $CFrame
    Set-Color $part $Color
    Set-PropertyText $part "Material" "256"
    Set-PropertyText $part "Anchored" "true"
    Set-PropertyText $part "CanCollide" "false"
    Set-PropertyText $part "CanTouch" "false"
    Set-PropertyText $part "CanQuery" "false"
    Set-PropertyText $part "Transparency" (Format-Number $Transparency)
    Set-PropertyText $part "PhysicsData" ""
    return $part
}

function Add-SurfaceAppearance([System.Xml.XmlElement]$Part, [System.Xml.XmlElement]$Template) {
    $surface = Clone-EmptyItem $Template "SurfaceAppearance"
    Set-PropertyText $surface "AlphaMode" "1"
    Set-PropertyText $surface "ColorMap" "rbxassetid://16460182437"
    Set-PropertyText $surface "MetalnessMap" ""
    Set-PropertyText $surface "NormalMap" ""
    Set-PropertyText $surface "RoughnessMap" ""
    Set-PropertyText $surface "TexturePack" ""
    [void]$Part.AppendChild($surface)
}

function Embed-VisualAssets {
    $replicatedStorage = Find-Item "ReplicatedStorage" "ReplicatedStorage"
    if ($null -eq $replicatedStorage) { throw "ReplicatedStorage item missing" }
    $folderTemplate = $script:document.SelectSingleNode("//Item[@class='Folder']")
    $modelTemplate = $script:document.SelectSingleNode("//Item[@class='Model']")
    $meshPartTemplate = $script:document.SelectSingleNode("//Item[@class='MeshPart']")
    $partTemplate = $script:document.SelectSingleNode("//Item[@class='Part']")
    $specialMeshTemplate = $script:document.SelectSingleNode("//Item[@class='SpecialMesh']")
    $surfaceTemplate = $script:document.SelectSingleNode("//Item[@class='SurfaceAppearance']")
    foreach ($required in @($folderTemplate, $modelTemplate, $meshPartTemplate, $partTemplate, $specialMeshTemplate, $surfaceTemplate)) {
        if ($null -eq $required) { throw "A visual XML template class is missing from the place" }
    }

    $oldVisualFolder = Find-Item "PunchWallVisualAssets" "Folder"
    if ($null -ne $oldVisualFolder) { [void]$oldVisualFolder.ParentNode.RemoveChild($oldVisualFolder) }
    $visualFolder = Clone-EmptyItem $folderTemplate "PunchWallVisualAssets"
    $tree = Clone-EmptyItem $modelTemplate "StylizedForestTreeTemplate"
    Set-PropertyText $tree "ScaleFactor" "1"
    Set-PropertyText $tree "SourceAssetId" "95555308270103"

    $trunk = New-StaticMeshPart $meshPartTemplate "Meshes/Jungle tree trunks_Plane.006" "rbxassetid://16460201079" "" `
        @(37.21770095825195, 59.92729187011719, 40.221397399902344) `
        @(23.338787078857422, -11.284446716308594, -15.61208724975586, 0.5239899754524231, 0, -0.8517323732376099, 0, 1.0000001192092896, 0, 0.8517323732376099, 0, 0.5239899754524231) `
        @(0.42352941632270813, 0.3450980484485626, 0.29411765933036804)
    [void]$tree.AppendChild($trunk)

    $leafDefinitions = @(
        @{ Size = @(30.840784072875977,31.283279418945312,33.85515594482422); CFrame = @(34.09400939941406,13.124801635742188,-8.260650634765625,-0.5239899754524231,0,0.8517323732376099,0,1.0000001192092896,0,-0.8517323732376099,0,-0.5239899754524231) },
        @{ Size = @(35.07712936401367,35.58041000366211,38.505558013916016); CFrame = @(21.06258201599121,23.457172393798828,-14.958989143371582,0.23174883425235748,0,0.9727826118469238,0,1.0000001192092896,0,-0.9727826118469238,0,0.23174883425235748) },
        @{ Size = @(30.840784072875977,31.283279418945312,33.85515594482422); CFrame = @(12.04350757598877,15.267044067382812,-20.502565383911133,0.9727826118469238,0,-0.23174887895584106,0,1.0000001192092896,0,0.23174887895584106,0,0.9727826118469238) },
        @{ Size = @(35.07712936401367,35.58041000366211,38.505558013916016); CFrame = @(27.296630859375,21.727752685546875,-27.65652847290039,0.9727826118469238,0,-0.23174883425235748,0,1.0000001192092896,0,0.23174883425235748,0,0.9727826118469238) },
        @{ Size = @(30.840784072875977,31.283279418945312,33.85515594482422); CFrame = @(29.89822006225586,11.30242919921875,-39.69831848144531,0.5239899754524231,0,-0.8517323732376099,0,1.0000001192092896,0,0.8517323732376099,0,0.5239899754524231) },
        @{ Size = @(30.840784072875977,31.283279418945312,33.85515594482422); CFrame = @(-0.30005836486816406,11.30242919921875,-21.120174407958984,0.8517323732376099,0,0.5239899754524231,0,1.0000001192092896,0,-0.5239899754524231,0,0.8517323732376099) }
    )
    foreach ($definition in $leafDefinitions) {
        $leaf = New-StaticMeshPart $meshPartTemplate "Leaves" "rbxassetid://16460182102" "rbxassetid://16460182437" $definition.Size $definition.CFrame @(0.6392157077789307,0.6352941393852234,0.6470588445663452) 0.2
        Add-SurfaceAppearance $leaf $surfaceTemplate
        [void]$tree.AppendChild($leaf)
    }
    [void]$visualFolder.AppendChild($tree)
    [void]$replicatedStorage.AppendChild($visualFolder)

    $fistFolder = Find-Item "PunchWallFistAssets" "Folder"
    if ($null -eq $fistFolder) {
        $fistFolder = Clone-EmptyItem $folderTemplate "PunchWallFistAssets"
        [void]$replicatedStorage.AppendChild($fistFolder)
    }
    $oldFist = Find-Item "CreatorStore_ArmoredClosedHeroFist" "Model"
    if ($null -ne $oldFist) { [void]$oldFist.ParentNode.RemoveChild($oldFist) }
    $fist = Clone-EmptyItem $modelTemplate "CreatorStore_ArmoredClosedHeroFist"
    Set-PropertyText $fist "ScaleFactor" "1"
    Set-PropertyText $fist "SourceAssetId" "1622087753"
    $fistPart = Clone-EmptyItem $partTemplate "FistMesh"
    Set-Vector3 $fistPart "size" @(1.7800005674362183,2.6800005435943604,1.669999599456787)
    Set-CFrame $fistPart @(0,0,0,1,0,0,0,1,0,0,0,1)
    Set-Color $fistPart @(0.6392157077789307,0.6352941393852234,0.6470588445663452)
    Set-PropertyText $fistPart "Material" "256"
    Set-PropertyText $fistPart "Anchored" "true"
    Set-PropertyText $fistPart "CanCollide" "false"
    Set-PropertyText $fistPart "CanTouch" "false"
    Set-PropertyText $fistPart "CanQuery" "false"
    $mesh = Clone-EmptyItem $specialMeshTemplate "Mesh"
    Set-PropertyText $mesh "MeshType" "5"
    Set-PropertyText $mesh "MeshId" "rbxassetid://65322375"
    Set-PropertyText $mesh "TextureId" "rbxassetid://65322423"
    Set-Vector3 $mesh "Offset" @(0,0,0)
    Set-Vector3 $mesh "Scale" @(2,2,3)
    [void]$fistPart.AppendChild($mesh)
    [void]$fist.AppendChild($fistPart)
    [void]$fistFolder.AppendChild($fist)

    $externalFolder = Find-Item "PunchWallExternalAssets" "Folder"
    if ($null -eq $externalFolder) {
        $externalFolder = Clone-EmptyItem $folderTemplate "PunchWallExternalAssets"
        [void]$replicatedStorage.AppendChild($externalFolder)
    }
    $oldPowerFist = Find-Item "Sanitized_PowerFistGoldKnuckle" "Model"
    if ($null -ne $oldPowerFist) { [void]$oldPowerFist.ParentNode.RemoveChild($oldPowerFist) }
    $powerFist = Clone-EmptyItem $modelTemplate "Sanitized_PowerFistGoldKnuckle"
    Set-PropertyText $powerFist "ScaleFactor" "1"
    Set-PropertyText $powerFist "SourceAssetId" "65566767"
    $powerFistPart = Clone-EmptyItem $partTemplate "Handle"
    Set-Vector3 $powerFistPart "size" @(1.7800005674362183,2.6800005435943604,1.669999599456787)
    Set-CFrame $powerFistPart @(0,0,0,1,0,0,0,1,0,0,0,1)
    Set-Color $powerFistPart @(0.6392157077789307,0.6352941393852234,0.6470588445663452)
    Set-PropertyText $powerFistPart "Material" "256"
    Set-PropertyText $powerFistPart "Anchored" "true"
    Set-PropertyText $powerFistPart "CanCollide" "false"
    Set-PropertyText $powerFistPart "CanTouch" "false"
    Set-PropertyText $powerFistPart "CanQuery" "false"
    $powerFistMesh = Clone-EmptyItem $specialMeshTemplate "Mesh"
    Set-PropertyText $powerFistMesh "MeshType" "5"
    Set-PropertyText $powerFistMesh "MeshId" "rbxassetid://65322375"
    Set-PropertyText $powerFistMesh "TextureId" "rbxassetid://65322423"
    Set-Vector3 $powerFistMesh "Offset" @(0,0,0)
    Set-Vector3 $powerFistMesh "Scale" @(2,2,3)
    [void]$powerFistPart.AppendChild($powerFistMesh)
    [void]$powerFist.AppendChild($powerFistPart)
    [void]$externalFolder.AppendChild($powerFist)

    return [pscustomobject]@{ TreeMeshParts = 7; TreeSurfaceAppearances = 6; FistParts = 1; PowerFistParts = 1 }
}

$assetService = Find-Item "AssetService" "AssetService"
if ($null -eq $assetService) { throw "AssetService item missing" }
Set-PropertyText $assetService "AllowInsertFreeAssets" "true"

$updated = @()
foreach ($entry in $sources.GetEnumerator()) {
    $sourcePath = [System.IO.Path]::GetFullPath($entry.Value.Path)
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Source file not found: $sourcePath"
    }

    $item = Ensure-ScriptItem $entry.Key $entry.Value
    $sourceNode = $item.SelectSingleNode("Properties/ProtectedString[@name='Source']")
    if ($null -eq $sourceNode) { throw "Source property not found for script: $($entry.Key)" }
    $sourceText = [System.IO.File]::ReadAllText($sourcePath)
    if ($sourceText.Contains("]]>") ) { throw "CDATA terminator found in source: $sourcePath" }
    $sourceNode.RemoveAll()
    $sourceNode.SetAttribute("name", "Source")
    [void]$sourceNode.AppendChild($script:document.CreateCDataSection($sourceText))
    $updated += $entry.Key
}

$visuals = Embed-VisualAssets
$temporaryPath = "$resolvedPlace.codex-tmp"
$settings = [System.Xml.XmlWriterSettings]::new()
$settings.Encoding = [System.Text.UTF8Encoding]::new($false)
$settings.Indent = $false
$settings.NewLineHandling = [System.Xml.NewLineHandling]::None
$writer = [System.Xml.XmlWriter]::Create($temporaryPath, $settings)
try {
    $script:document.Save($writer)
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
    visualAssets = $visuals
    bytes = (Get-Item -LiteralPath $resolvedPlace).Length
} | ConvertTo-Json -Depth 4
