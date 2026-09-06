param(
 [Parameter(Mandatory=$true)][string]$EvidenceDirectory,
 [Parameter(Mandatory=$true)][string]$SourceSync
)
$ErrorActionPreference='Stop'
$taskRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
Set-Location -LiteralPath $taskRoot
if($EvidenceDirectory -notmatch '^[a-zA-Z0-9-]+$'){throw 'Evidence directory must be one leaf name'}
$directory=Join-Path $taskRoot "work/docs/evidence/$EvidenceDirectory"
if(Test-Path -LiteralPath $directory){throw 'Use new evidence directory; preserve earlier runs'}
$sync=Get-Content -LiteralPath $SourceSync -Raw|ConvertFrom-Json
if(-not $sync.ok -or $sync.synced.Count -ne 9 -or [string]::IsNullOrWhiteSpace($sync.selectedStudio.id)){throw 'Source sync identity missing'}
function Get-FrozenInventory {
 $files=@(Get-ChildItem -LiteralPath 'work/punch-wall-rpg/src' -Recurse -File)
 $files+=@(Get-ChildItem -LiteralPath 'work/automation' -Recurse -File|Where-Object {$_.Extension -in @('.mjs','.ps1') -or ($_.Extension -eq '.json' -and $_.DirectoryName -eq (Join-Path $taskRoot 'work/automation/flows'))})
 $inventory=[ordered]@{}
 foreach($file in @($files|Sort-Object FullName -Unique)){$inventory[$file.FullName]=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash}
 return $inventory
}
$frozen=Get-FrozenInventory
function Assert-Frozen {
 $current=Get-FrozenInventory
 if($current.Count -ne $frozen.Count){throw 'Frozen source/flow/runner inventory count changed'}
 foreach($path in $frozen.Keys){if(-not $current.Contains($path) -or $current[$path] -ne $frozen[$path]){throw "Frozen file changed or removed: $path"}}
}
function Get-LiveProof {
 $proofText=& node work/automation/scripts/verify-studio-source.mjs $sync.selectedStudio.id '^PunchWallRPGPlayable_v1_final[.]rbxlx$'
 if($LASTEXITCODE -ne 0){throw 'Read-only live Studio source comparison failed'}
 $proof=$proofText|ConvertFrom-Json
 if(-not $proof.ok -or -not $proof.readOnly -or $proof.globalCodeObjectCount -ne 9){throw 'Live source proof incomplete'}
 return $proof
}
$flows=@(Get-ChildItem -LiteralPath 'work/automation/flows' -File -Filter '*.json'|Sort-Object Name)
if($flows.Count -lt 124){throw 'Required full flow inventory unexpectedly incomplete'}
New-Item -ItemType Directory -Path $directory|Out-Null
$manifest=[ordered]@{startedAt=(Get-Date).ToUniversalTime().ToString('o');completedAt=$null;sourceCommit=(& git rev-parse HEAD);sourceSync=$SourceSync;studioInstanceId=$sync.selectedStudio.id;runKind='Integrated source in Studio; canonical artifact not yet rebuilt';frozenFiles=$frozen;liveBefore=$null;liveAfter=$null;discovered=$flows.Count;excluded=@();results=@();ok=$false;interruption=$null}
$manifestPath=Join-Path $directory 'manifest.json'
function Save-Manifest {$manifest|ConvertTo-Json -Depth 14|Set-Content -LiteralPath $manifestPath -Encoding utf8}
try {
 Assert-Frozen
 $manifest.liveBefore=Get-LiveProof
 Assert-Frozen
 Save-Manifest
 foreach($f in $flows){
  Assert-Frozen
  $started=Get-Date;$resultPath=Join-Path $directory $f.Name
  $output=& node work/automation/scripts/flow_runner.mjs --flow $f.FullName --studio-instance-id $sync.selectedStudio.id --studio-name '^PunchWallRPGPlayable_v1_final[.]rbxlx$' --place-name '^PunchWallRPGPlayable_v1_final[.]rbxlx$' --result-file $resultPath 2>&1
  $code=$LASTEXITCODE;$parsed=$null
  if(Test-Path -LiteralPath $resultPath){try{$parsed=Get-Content -LiteralPath $resultPath -Raw|ConvertFrom-Json}catch{}}
  $errors=@($parsed.results|Where-Object {-not $_.ok}|ForEach-Object {$_.error})
  if($null -eq $parsed){$output|Set-Content -LiteralPath (Join-Path $directory "$($f.BaseName).log") -Encoding utf8}
  $manifest.results+=@{flow=$f.BaseName;ok=($code -eq 0 -and $null -ne $parsed -and $parsed.ok);exitCode=$code;seconds=[math]::Round(((Get-Date)-$started).TotalSeconds,1);flowSHA256=$frozen[$f.FullName];evidence=$resultPath;errors=$errors}
  Assert-Frozen
  Save-Manifest
  Write-Output ('{0}/{1} {2} {3} {4}s {5}' -f $manifest.results.Count,$flows.Count,$(if($manifest.results[-1].ok){'PASS'}else{'FAIL'}),$f.BaseName,$manifest.results[-1].seconds,($errors -join ' | '))
 }
 Assert-Frozen
 $manifest.liveAfter=Get-LiveProof
 Assert-Frozen
 $manifest.ok=$manifest.results.Count -eq $flows.Count -and @($manifest.results|Where-Object {-not $_.ok}).Count -eq 0
}catch{$manifest.interruption=$_.Exception.Message;throw}finally{$manifest.completedAt=(Get-Date).ToUniversalTime().ToString('o');Save-Manifest}
if(-not $manifest.ok){throw 'Full regression has failures; see preserved manifest and per-flow evidence'}
