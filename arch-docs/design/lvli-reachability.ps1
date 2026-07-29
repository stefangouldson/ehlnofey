# requiem-method.md §5.1 - partition the gated LVLI into outfit-reachable vs container-only.
#
# Under the Requiem-method architecture, container lists KEEP their gates (the encounter zone
# supplies the level, verified by probe test 3) and need no edit. Only lists reachable from an
# NPC's worn/carried inventory are bone-1 leaks. This script measures that split.
#
# Roots:
#   ACTOR      = NPC_ `Items:` entries, plus DefaultOutfit/SleepingOutfit -> OTFT `Items:`
#   CONTAINER  = CONT `Items:` entries
# Edges: LVLI `Entries: - Data: Reference:` -> child form (followed only when the child is an LVLI)
#
# Load order matters: later plugins re-override the same FormKey, so assignments must be
# last-wins (CLAUDE.md, "a base+DLC index has duplicate keys").
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$roots = @('reference/Base/01Skyrim','reference/Base/02Update',
           'reference/Base/03Dawnguard','reference/Base/05Dragonborn')

function Get-FormKey([string]$fileName) {
  if ($fileName -match '^(.*) - ([0-9A-Fa-f]{6})_(.+)\.yaml$') {
    return @{ ed = $Matches[1]; fk = ($Matches[2].ToUpper() + ':' + $Matches[3]) }
  }
  return $null
}

# ---------------------------------------------------------------- 1. LVLI: nodes, edges, gating
$lvli     = @{}   # formkey -> editorid
$children = @{}   # formkey -> [child formkeys]
$gated    = @{}   # formkey -> $true when >1 distinct entry Level
foreach ($p in $roots) {
  $dir = Join-Path $p 'LeveledItems'
  if (-not (Test-Path $dir)) { continue }
  foreach ($f in Get-ChildItem $dir -Filter *.yaml) {
    $id = Get-FormKey $f.Name
    if (-not $id) { continue }
    $kids = New-Object System.Collections.ArrayList
    $lv   = New-Object System.Collections.ArrayList
    foreach ($line in [System.IO.File]::ReadLines($f.FullName)) {
      if     ($line -match '^\s+Level:\s*(\d+)\s*$')                          { [void]$lv.Add([int]$Matches[1]) }
      elseif ($line -match '^\s+Reference:\s*([0-9A-Fa-f]{6}):(\S+)\s*$')     { [void]$kids.Add($Matches[1].ToUpper()+':'+$Matches[2]) }
    }
    $lvli[$id.fk]     = $id.ed          # last-wins
    $children[$id.fk] = @($kids)
    $gated[$id.fk]    = (@($lv | Sort-Object -Unique).Count -gt 1)
  }
}
Write-Host ("LVLI nodes: {0}   gated: {1}" -f $lvli.Count, @($gated.GetEnumerator()|Where-Object{$_.Value}).Count)

# ---------------------------------------------------------------- 2. Outfits: OTFT -> its items
$outfit = @{}
foreach ($p in $roots) {
  $dir = Join-Path $p 'Outfits'
  if (-not (Test-Path $dir)) { continue }
  foreach ($f in Get-ChildItem $dir -Filter *.yaml) {
    $id = Get-FormKey $f.Name
    if (-not $id) { continue }
    $items = New-Object System.Collections.ArrayList
    $inItems = $false
    foreach ($line in [System.IO.File]::ReadLines($f.FullName)) {
      if ($line -match '^Items:')                                  { $inItems = $true; continue }
      if ($inItems -and $line -match '^- ([0-9A-Fa-f]{6}):(\S+)\s*$') { [void]$items.Add($Matches[1].ToUpper()+':'+$Matches[2]) }
      elseif ($inItems -and $line -notmatch '^\s')                 { $inItems = $false }
    }
    $outfit[$id.fk] = @($items)
  }
}
Write-Host ("Outfits: {0}" -f $outfit.Count)

# ---------------------------------------------------------------- 3. Roots
$actorRoot = New-Object System.Collections.Generic.HashSet[string]
$contRoot  = New-Object System.Collections.Generic.HashSet[string]

foreach ($p in $roots) {
  $dir = Join-Path $p 'Npcs'
  if (-not (Test-Path $dir)) { continue }
  foreach ($f in Get-ChildItem $dir -Filter *.yaml) {
    foreach ($line in [System.IO.File]::ReadLines($f.FullName)) {
      if ($line -match '^\s+Item:\s*([0-9A-Fa-f]{6}):(\S+)\s*$') {
        [void]$actorRoot.Add($Matches[1].ToUpper()+':'+$Matches[2])
      }
      elseif ($line -match '^(?:Default|Sleeping)Outfit:\s*([0-9A-Fa-f]{6}):(\S+)\s*$') {
        $k = $Matches[1].ToUpper()+':'+$Matches[2]
        if ($outfit.ContainsKey($k)) { foreach ($i in $outfit[$k]) { [void]$actorRoot.Add($i) } }
      }
    }
  }
}
foreach ($p in $roots) {
  $dir = Join-Path $p 'Containers'
  if (-not (Test-Path $dir)) { continue }
  foreach ($f in Get-ChildItem $dir -Filter *.yaml) {
    foreach ($line in [System.IO.File]::ReadLines($f.FullName)) {
      if ($line -match '^\s+Item:\s*([0-9A-Fa-f]{6}):(\S+)\s*$') {
        [void]$contRoot.Add($Matches[1].ToUpper()+':'+$Matches[2])
      }
    }
  }
}
Write-Host ("root forms  actor: {0}   container: {1}" -f $actorRoot.Count, $contRoot.Count)

# ---------------------------------------------------------------- 4. Transitive closure over LVLI
function Close-Over($seeds) {
  $seen  = New-Object System.Collections.Generic.HashSet[string]
  $queue = New-Object System.Collections.Generic.Queue[string]
  foreach ($s in $seeds) { if ($lvli.ContainsKey($s) -and $seen.Add($s)) { $queue.Enqueue($s) } }
  while ($queue.Count -gt 0) {
    $n = $queue.Dequeue()
    if (-not $children.ContainsKey($n)) { continue }
    foreach ($c in $children[$n]) { if ($lvli.ContainsKey($c) -and $seen.Add($c)) { $queue.Enqueue($c) } }
  }
  return $seen
}
$fromActor = Close-Over $actorRoot
$fromCont  = Close-Over $contRoot

# ---------------------------------------------------------------- 5. Partition
$rows = New-Object System.Collections.ArrayList
foreach ($k in $lvli.Keys) {
  $a = $fromActor.Contains($k); $c = $fromCont.Contains($k)
  $cls = if ($a -and $c) { 'both' } elseif ($a) { 'actor-only' } elseif ($c) { 'container-only' } else { 'unreached' }
  [void]$rows.Add([pscustomobject]@{ FormKey=$k; EditorID=$lvli[$k]; Gated=$gated[$k]; Class=$cls })
}
$rows | Export-Csv -Path (Join-Path $PSScriptRoot 'lvli-reachability.csv') -NoTypeInformation -Encoding utf8

"";"=== ALL LVLI ==="
$rows | Group-Object Class | Sort-Object Count -Descending | Format-Table Count, Name -AutoSize
"=== GATED LVLI ONLY  (the job) ==="
$g = @($rows | Where-Object { $_.Gated })
$g | Group-Object Class | Sort-Object Count -Descending | Format-Table Count, Name -AutoSize
"gated total: {0}" -f $g.Count
"MUST FIX (actor-only + both): {0}" -f @($g | Where-Object { $_.Class -eq 'actor-only' -or $_.Class -eq 'both' }).Count
"NO EDIT   (container-only)  : {0}" -f @($g | Where-Object { $_.Class -eq 'container-only' }).Count
"UNREACHED (check separately): {0}" -f @($g | Where-Object { $_.Class -eq 'unreached' }).Count

# ---------------------------------------------------------------- 6. The BOUNDARY
# The actor side does not need every reachable list rewritten - only the ones an outfit or an
# NPC inventory points at DIRECTLY. Everything below that is subtree, and is fixed implicitly
# once the entry point is flattened. Lists that are ALSO container-reachable must be FORKED
# (a flat copy for the actor, the gated original left alone for chests); lists reached only
# from actors can be flattened in place.
$direct = @($actorRoot | Where-Object { $lvli.ContainsKey($_) -and $gated[$_] })
$fork   = @($direct | Where-Object { $fromCont.Contains($_) })
$inPlace= @($direct | Where-Object { -not $fromCont.Contains($_) })

"";"=== THE BOUNDARY - gated lists an actor points at DIRECTLY ==="
"direct actor entry points, gated : {0}" -f $direct.Count
"  -> FORK (also in containers)   : {0}" -f $fork.Count
"  -> flatten in place            : {0}" -f $inPlace.Count

$dir2 = New-Object System.Collections.ArrayList
foreach ($k in $direct) {
  [void]$dir2.Add([pscustomobject]@{
    FormKey=$k; EditorID=$lvli[$k]
    Action= $(if ($fromCont.Contains($k)) { 'fork' } else { 'flatten-in-place' }) })
}
$dir2 | Sort-Object Action, EditorID |
  Export-Csv -Path (Join-Path $PSScriptRoot 'lvli-boundary.csv') -NoTypeInformation -Encoding utf8

"";"=== top 25 boundary lists by EditorID family ==="
$dir2 | ForEach-Object { ($_.EditorID -replace '(Boots|Cuirass|Gauntlets|Helmet|Shield|Sword|Axe|Mace|Dagger|Bow|Greatsword|Warhammer|Battleaxe|Weapon|Armor).*$','$1') } |
  Group-Object | Sort-Object Count -Descending | Select-Object -First 25 Count, Name | Format-Table -AutoSize
