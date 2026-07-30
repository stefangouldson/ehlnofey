# How expensive is forking the 76 shared boundary lists?
# Cost = every OTFT and every NPC_ that points at one of them and must be repointed.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$roots = @('reference/Base/01Skyrim','reference/Base/02Update',
           'reference/Base/03Dawnguard','reference/Base/05Dragonborn')

$b = Import-Csv 'arch-docs/design/lvli-boundary.csv'
$forkSet = New-Object System.Collections.Generic.HashSet[string]
foreach ($r in $b) { if ($r.Action -eq 'fork') { [void]$forkSet.Add($r.FormKey) } }
"fork list count: {0}" -f $forkSet.Count

# --- outfits pointing at a fork list
$outfitsHit = New-Object System.Collections.Generic.HashSet[string]
$outfitItems = @{}
foreach ($p in $roots) {
  $dir = Join-Path $p 'Outfits'; if (-not (Test-Path $dir)) { continue }
  foreach ($f in Get-ChildItem $dir -Filter *.yaml) {
    if ($f.Name -notmatch '^(.*) - ([0-9A-Fa-f]{6})_(.+)\.yaml$') { continue }
    $ofk = $Matches[2].ToUpper()+':'+$Matches[3]
    $items = New-Object System.Collections.ArrayList
    $in = $false
    foreach ($line in [System.IO.File]::ReadLines($f.FullName)) {
      if ($line -match '^Items:') { $in = $true; continue }
      if ($in -and $line -match '^- ([0-9A-Fa-f]{6}):(\S+)\s*$') {
        $k = $Matches[1].ToUpper()+':'+$Matches[2]; [void]$items.Add($k)
        if ($forkSet.Contains($k)) { [void]$outfitsHit.Add($ofk) }
      } elseif ($in -and $line -notmatch '^\s') { $in = $false }
    }
    $outfitItems[$ofk] = @($items)
  }
}
"outfits referencing a fork list : {0}  (of {1} total)" -f $outfitsHit.Count, $outfitItems.Count

# --- NPCs: direct Items: hit, and NPCs wearing a hit outfit
$npcDirect = 0; $npcViaOutfit = 0; $npcTotal = 0
foreach ($p in $roots) {
  $dir = Join-Path $p 'Npcs'; if (-not (Test-Path $dir)) { continue }
  foreach ($f in Get-ChildItem $dir -Filter *.yaml) {
    $npcTotal++; $d = $false; $v = $false
    foreach ($line in [System.IO.File]::ReadLines($f.FullName)) {
      if ($line -match '^\s+Item:\s*([0-9A-Fa-f]{6}):(\S+)\s*$') {
        if ($forkSet.Contains($Matches[1].ToUpper()+':'+$Matches[2])) { $d = $true }
      } elseif ($line -match '^(?:Default|Sleeping)Outfit:\s*([0-9A-Fa-f]{6}):(\S+)\s*$') {
        if ($outfitsHit.Contains($Matches[1].ToUpper()+':'+$Matches[2])) { $v = $true }
      }
    }
    if ($d) { $npcDirect++ }
    if ($v) { $npcViaOutfit++ }
  }
}
"NPCs with a DIRECT Items: fork ref : {0}  (of {1})" -f $npcDirect, $npcTotal
"NPCs wearing an affected outfit    : {0}   <- these need NO edit; the outfit is repointed" -f $npcViaOutfit

# --- characterise the 177 unreached gated lists
"";"=== the 177 unreached gated lists - name families ==="
$all = Import-Csv 'arch-docs/design/lvli-reachability.csv'
$un = @($all | Where-Object { $_.Gated -eq 'True' -and $_.Class -eq 'unreached' })
$un | ForEach-Object { $_.EditorID -replace '^(DLC\d|LItem|Lvl|Treas|Death)?.*?([A-Z][a-z]+).*$','$1$2' } |
  Group-Object | Sort-Object Count -Descending | Select-Object -First 15 Count, Name | Format-Table -AutoSize | Out-String -Width 100
"sample:"; ($un | Select-Object -First 20 -ExpandProperty EditorID) -join ', '
