# Which side of the 76 shared boundary lists is cheaper to fork?
#   ACTOR side  : flatten a copy, repoint 16 outfits + 749 NPC Items: blocks (no rule can do the latter)
#   CONTAINER side: flatten the ORIGINAL in place (749 NPCs fixed for free), give chests a gated copy
# Cost of the container side = every CONT that points at one of the 76, directly or transitively.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$roots = @('reference/Base/01Skyrim','reference/Base/02Update',
           'reference/Base/03Dawnguard','reference/Base/05Dragonborn')

$b = Import-Csv 'arch-docs/design/lvli-boundary.csv'
$forkSet = New-Object System.Collections.Generic.HashSet[string]
foreach ($r in $b) { if ($r.Action -eq 'fork') { [void]$forkSet.Add($r.FormKey) } }

# parents: which LVLI hold an entry pointing at X
$parents = @{}
foreach ($p in $roots) {
  $dir = Join-Path $p 'LeveledItems'; if (-not (Test-Path $dir)) { continue }
  foreach ($f in Get-ChildItem $dir -Filter *.yaml) {
    if ($f.Name -notmatch '^(.*) - ([0-9A-Fa-f]{6})_(.+)\.yaml$') { continue }
    $me = $Matches[2].ToUpper()+':'+$Matches[3]
    foreach ($line in [System.IO.File]::ReadLines($f.FullName)) {
      if ($line -match '^\s+Reference:\s*([0-9A-Fa-f]{6}):(\S+)\s*$') {
        $c = $Matches[1].ToUpper()+':'+$Matches[2]
        if (-not $parents.ContainsKey($c)) { $parents[$c] = New-Object System.Collections.Generic.HashSet[string] }
        [void]$parents[$c].Add($me)
      }
    }
  }
}

# upward closure: every LVLI that can reach a fork list
$up = New-Object System.Collections.Generic.HashSet[string]
$q  = New-Object System.Collections.Generic.Queue[string]
foreach ($k in $forkSet) { if ($up.Add($k)) { $q.Enqueue($k) } }
while ($q.Count -gt 0) {
  $n = $q.Dequeue()
  if (-not $parents.ContainsKey($n)) { continue }
  foreach ($pp in $parents[$n]) { if ($up.Add($pp)) { $q.Enqueue($pp) } }
}
"LVLI in the upward cone of the 76: {0}" -f $up.Count

# containers that reference anything in that cone
$contHit = New-Object System.Collections.Generic.HashSet[string]
$contDirect = New-Object System.Collections.Generic.HashSet[string]
$contTotal = 0
foreach ($p in $roots) {
  $dir = Join-Path $p 'Containers'; if (-not (Test-Path $dir)) { continue }
  foreach ($f in Get-ChildItem $dir -Filter *.yaml) {
    if ($f.Name -notmatch '^(.*) - ([0-9A-Fa-f]{6})_(.+)\.yaml$') { continue }
    $cfk = $Matches[2].ToUpper()+':'+$Matches[3]; $contTotal++
    foreach ($line in [System.IO.File]::ReadLines($f.FullName)) {
      if ($line -match '^\s+Item:\s*([0-9A-Fa-f]{6}):(\S+)\s*$') {
        $k = $Matches[1].ToUpper()+':'+$Matches[2]
        if ($forkSet.Contains($k)) { [void]$contDirect.Add($cfk) }
        if ($up.Contains($k))      { [void]$contHit.Add($cfk) }
      }
    }
  }
}
""
"containers total                      : {0}" -f $contTotal
"…referencing a fork list DIRECTLY     : {0}" -f $contDirect.Count
"…reaching one through sublists        : {0}" -f $contHit.Count
