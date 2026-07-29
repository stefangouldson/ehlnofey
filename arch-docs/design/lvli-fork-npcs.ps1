# Of the 749 NPCs with a direct Items: reference to a shared boundary list, WHICH lists drive it?
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$roots = @('reference/Base/01Skyrim','reference/Base/02Update',
           'reference/Base/03Dawnguard','reference/Base/05Dragonborn')

$b = Import-Csv 'arch-docs/design/lvli-boundary.csv'
$fork = @{}
foreach ($r in $b) { if ($r.Action -eq 'fork') { $fork[$r.FormKey] = $r.EditorID } }

$hits = @{}
foreach ($k in $fork.Keys) { $hits[$k] = 0 }
foreach ($p in $roots) {
  $dir = Join-Path $p 'Npcs'; if (-not (Test-Path $dir)) { continue }
  foreach ($f in Get-ChildItem $dir -Filter *.yaml) {
    $seen = New-Object System.Collections.Generic.HashSet[string]
    foreach ($line in [System.IO.File]::ReadLines($f.FullName)) {
      if ($line -match '^\s+Item:\s*([0-9A-Fa-f]{6}):(\S+)\s*$') {
        $k = $Matches[1].ToUpper()+':'+$Matches[2]
        if ($fork.ContainsKey($k)) { [void]$seen.Add($k) }
      }
    }
    foreach ($k in $seen) { $hits[$k]++ }
  }
}
"=== NPCs referencing each shared boundary list, directly ==="
$hits.GetEnumerator() | Where-Object { $_.Value -gt 0 } | Sort-Object Value -Descending |
  ForEach-Object { "{0,5}  {1}" -f $_.Value, $fork[$_.Key] }
""
"lists with zero direct NPC refs: {0} of {1}" -f @($hits.GetEnumerator()|Where-Object{$_.Value -eq 0}).Count, $fork.Count
