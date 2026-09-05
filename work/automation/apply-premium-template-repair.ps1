[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][string]$InputPlace,
 [Parameter(Mandatory=$true)][string]$RepairedModels,
 [Parameter(Mandatory=$true)][string]$OutputPlace
)
$ErrorActionPreference='Stop'
$projectRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$resolvedInput=[IO.Path]::GetFullPath($InputPlace)
$resolvedModels=[IO.Path]::GetFullPath($RepairedModels)
$resolvedOutput=[IO.Path]::GetFullPath($OutputPlace)
foreach($candidate in @($resolvedInput,$resolvedModels,$resolvedOutput)) {
 if(-not $candidate.StartsWith($projectRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw "Path outside task worktree: $candidate" }
}
$canonical=[IO.Path]::GetFullPath((Join-Path $projectRoot 'outputs/PunchWallRPGPlayable_v1_final.rbxlx'))
if($resolvedOutput -eq $resolvedInput -or $resolvedOutput -eq $canonical -or [IO.Path]::GetExtension($resolvedOutput) -ne '.rbxlx') { throw 'Use a distinct staging RBXLX; canonical release output is forbidden here.' }
function Read-TaskXml([string]$file) {
 $xml=[Xml.XmlDocument]::new(); $xml.PreserveWhitespace=$true; $xml.XmlResolver=$null; $xml.Load($file); return $xml
}
$original=Read-TaskXml $resolvedInput
$repair=Read-TaskXml $resolvedModels
$repairReferences=@{}
foreach($item in $repair.SelectNodes('//Item')) {
 $oldReference=$item.GetAttribute('referent')
 if($repairReferences.ContainsKey($oldReference)) { throw 'Duplicate reference in repaired models' }
 $repairReferences[$oldReference]='RBX'+[guid]::NewGuid().ToString('N')
 $item.SetAttribute('referent',$repairReferences[$oldReference])
}
foreach($ref in $repair.SelectNodes('//Ref')) {
 if($repairReferences.ContainsKey($ref.InnerText)) { $ref.InnerText=$repairReferences[$ref.InnerText] }
 elseif($ref.InnerText -ne 'null') { throw "Repaired model has an external reference: $($ref.InnerText)" }
}
$output=$original.CloneNode($true)
$names=@('Sanitized_CrimsonPhoenixPet','Sanitized_StormWyvernPet','Sanitized_CelestialGuardianPet')
$externalPath="/roblox/Item[Properties/string[@name='Name']='ReplicatedStorage']/Item[Properties/string[@name='Name']='PunchWallExternalAssets']"
$external=$output.SelectSingleNode($externalPath)
if($null -eq $external) { throw 'Exact external asset folder missing' }
$oldReferents=[Collections.Generic.HashSet[string]]::new()
$oldToNew=@{}
$nodePairs=[Collections.Generic.List[object]]::new()
function Get-VisualNodeMap([Xml.XmlElement]$root) {
 $map=@{}
 function Add-VisualNode([Xml.XmlElement]$node,[string]$parentKey) {
  $nameNode=$node.SelectSingleNode("Properties/string[@name='Name']")
  if($null -eq $nameNode) { throw 'Visual node is missing its explicit name' }
  $name=$nameNode.InnerText; $class=$node.GetAttribute('class')
  $key=$parentKey+'/'+$class+':'+$name.Length+':'+$name
  if($map.ContainsKey($key)) { throw "Ambiguous visual node path: $key" }
  $map[$key]=$node
  foreach($child in $node.SelectNodes('Item')) { Add-VisualNode $child $key }
 }
 Add-VisualNode $root ''
 return $map
}
foreach($name in $names) {
 $existing=$external.SelectNodes("Item[@class='Model'][Properties/string[@name='Name']='$name']")
 $replacements=$repair.SelectNodes("/roblox/Item/Item[@class='Model'][Properties/string[@name='Name']='$name']")
 if($existing.Count -ne 1 -or $replacements.Count -ne 1) { throw "Template must be unique in both inputs: $name" }
 foreach($item in $existing[0].SelectNodes('descendant-or-self::Item')) { [void]$oldReferents.Add($item.GetAttribute('referent')) }
 $originalNodes=Get-VisualNodeMap $existing[0]
 $repairedNodes=Get-VisualNodeMap $replacements[0]
 foreach($key in $repairedNodes.Keys) {
  if(-not $originalNodes.ContainsKey($key)) { throw "Repaired visual path has no exact original match: $key" }
  $oldNode=$originalNodes[$key]; $newNode=$repairedNodes[$key]
  $oldToNew[$oldNode.GetAttribute('referent')]=$newNode.GetAttribute('referent')
  $nodePairs.Add(@{original=$oldNode;repaired=$newNode})
 }
}
$importedReferences=[Collections.Generic.HashSet[string]]::new()
foreach($pair in $nodePairs) { [void]$importedReferences.Add($pair.repaired.GetAttribute('referent')) }
foreach($pair in $nodePairs) {
 foreach($ref in $pair.repaired.SelectNodes('Properties//Ref')) {
  if($ref.InnerText -ne 'null' -and -not $importedReferences.Contains($ref.InnerText)) { throw 'Repaired visual references a discarded wrapper or external model' }
 }
}
# rbxmk 0.9 cannot round-trip newer Roblox Content values. Keep original visual
# properties byte-for-byte in the XML DOM; take only verified sanitizer changes.
$sanitizerProperties=@('AttributesSerialize','Anchored','CanCollide','CanTouch','CanQuery','Massless','Rate')
foreach($pair in $nodePairs) {
 $properties=$repair.ImportNode($pair.original.SelectSingleNode('Properties'),$true)
 $verified=$pair.repaired.SelectSingleNode('Properties')
 if($null -eq $verified.SelectSingleNode("*[@name='AttributesSerialize']")) { throw 'Repaired node lacks sanitizer attributes' }
 foreach($propertyName in $sanitizerProperties) {
  $value=$verified.SelectSingleNode("*[@name='$propertyName']")
  if($value) {
   $previous=$properties.SelectSingleNode("*[@name='$propertyName']")
   if($previous) { [void]$properties.ReplaceChild($value.CloneNode($true),$previous) }
   else { [void]$properties.AppendChild($value.CloneNode($true)) }
  }
 }
 foreach($ref in $properties.SelectNodes('.//Ref')) { if($oldToNew.ContainsKey($ref.InnerText)) { $ref.InnerText=$oldToNew[$ref.InnerText] } }
 [void]$pair.repaired.ReplaceChild($properties,$verified)
}
foreach($name in $names) {
 $existing=$external.SelectSingleNode("Item[@class='Model'][Properties/string[@name='Name']='$name']")
 $replacement=$repair.SelectSingleNode("/roblox/Item/Item[@class='Model'][Properties/string[@name='Name']='$name']")
 [void]$external.ReplaceChild($output.ImportNode($replacement,$true),$existing)
}
# Existing cross-template references cannot silently point at replaced referents.
foreach($ref in $output.SelectNodes('//Ref')) { if($oldReferents.Contains($ref.InnerText)) { throw "Reference to replaced template remains: $($ref.InnerText)" } }
$shared=$output.SelectSingleNode('/roblox/SharedStrings')
if($null -eq $shared) { $shared=$output.CreateElement('SharedStrings'); [void]$output.DocumentElement.AppendChild($shared) }
$added=0
foreach($entry in $repair.SelectNodes('/roblox/SharedStrings/SharedString')) {
 $key=$entry.GetAttribute('md5')
 $matching=@($shared.SelectNodes('SharedString') | Where-Object {$_.GetAttribute('md5') -eq $key})
 if($matching.Count -gt 1) { throw "Duplicate shared-string key: $key" }
 if($matching.Count -eq 1) {
  if(($matching[0].InnerText -replace '\s','') -ne ($entry.InnerText -replace '\s','')) { throw "Shared-string hash collision: $key" }
 } else { [void]$shared.AppendChild($output.ImportNode($entry,$true)); $added++ }
}
function Unchanged-Content([Xml.XmlDocument]$xml) {
 $copy=$xml.CloneNode($true)
 foreach($name in $names) { $node=$copy.SelectSingleNode("$externalPath/Item[Properties/string[@name='Name']='$name']"); [void]$node.ParentNode.RemoveChild($node) }
 $strings=$copy.SelectSingleNode('/roblox/SharedStrings'); if($strings) { [void]$strings.ParentNode.RemoveChild($strings) }
 return $copy.OuterXml
}
if((Unchanged-Content $original) -cne (Unchanged-Content $output)) { throw 'Content outside the three templates changed' }
function Assert-InstanceReferences([Xml.XmlDocument]$xml) {
 $references=[Collections.Generic.HashSet[string]]::new()
 foreach($item in $xml.SelectNodes('//Item')) { if(-not $references.Add($item.GetAttribute('referent'))) { throw 'Duplicate instance referent after repair' } }
 foreach($ref in $xml.SelectNodes('//Ref')) {
  if($ref.InnerText -ne 'null' -and -not $references.Contains($ref.InnerText)) { throw "Dangling instance reference after repair: $($ref.InnerText)" }
 }
}
Assert-InstanceReferences $output
foreach($value in $output.SelectNodes('//SharedString[@name]')) { if(-not @($shared.SelectNodes('SharedString') | Where-Object {$_.GetAttribute('md5') -eq $value.InnerText}).Count) { throw "Missing shared string: $($value.InnerText)" } }
$temporary=$resolvedOutput+'.codex-'+[guid]::NewGuid().ToString('N')+'.tmp'
try {
 $settings=[Xml.XmlWriterSettings]::new(); $settings.Encoding=[Text.UTF8Encoding]::new($false); $settings.Indent=$false; $settings.NewLineHandling=[Xml.NewLineHandling]::None
 $writer=[Xml.XmlWriter]::Create($temporary,$settings)
 try { $output.Save($writer) } finally { $writer.Dispose() }
 $written=Read-TaskXml $temporary
 Assert-InstanceReferences $written
 $beforeContent=Unchanged-Content $original; $afterContent=Unchanged-Content $written
 if($beforeContent -cne $afterContent) {
  $index=0; while($index -lt [math]::Min($beforeContent.Length,$afterContent.Length) -and $beforeContent[$index] -ceq $afterContent[$index]) {$index++}
  throw "Post-write unrelated content changed at $index. Before: $($beforeContent.Substring($index,[math]::Min(100,$beforeContent.Length-$index))) After: $($afterContent.Substring($index,[math]::Min(100,$afterContent.Length-$index)))"
 }
 Move-Item -LiteralPath $temporary -Destination $resolvedOutput -Force
} finally { if(Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force } }
[ordered]@{ok=$true; input=$resolvedInput; inputSha256=(Get-FileHash -LiteralPath $resolvedInput -Algorithm SHA256).Hash; repairedModelsSha256=(Get-FileHash -LiteralPath $resolvedModels -Algorithm SHA256).Hash; output=$resolvedOutput; outputSha256=(Get-FileHash -LiteralPath $resolvedOutput -Algorithm SHA256).Hash; templates=$names; sharedStringsAdded=$added; unrelatedContentPreserved=$true; canonicalWritten=$false} | ConvertTo-Json -Depth 4
