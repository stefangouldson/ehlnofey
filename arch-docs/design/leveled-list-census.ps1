# Census: how many vanilla+DLC LVLN / LVLI lists carry a real player-level gate?
# A "real gate" = more than one DISTINCT entry Level across the record.
Set-StrictMode -Version Latest

$roots = @('reference/Base/01Skyrim','reference/Base/02Update',
           'reference/Base/03Dawnguard','reference/Base/05Dragonborn')

foreach ($type in @('LeveledNpcs','LeveledItems')) {
  $tot = 0; $multi = 0; $entriesTot = 0; $gatedEntries = 0; $maxGate = 0
  foreach ($p in $roots) {
    $dir = Join-Path $p $type
    if (-not (Test-Path $dir)) { continue }
    foreach ($f in Get-ChildItem $dir -Filter *.yaml) {
      $tot++
      $levels = New-Object System.Collections.ArrayList
      foreach ($line in [System.IO.File]::ReadLines($f.FullName)) {
        if ($line -match '^\s+Level:\s*(\d+)\s*$') { [void]$levels.Add([int]$Matches[1]) }
      }
      $entriesTot += $levels.Count
      $d = @($levels | Sort-Object -Unique)
      if ($d.Count -gt 1) {
        $multi++
        $gatedEntries += $levels.Count
        if ($d[-1] -gt $maxGate) { $maxGate = $d[-1] }
      }
    }
  }
  "{0,-13} records={1,5}  REAL-GATED={2,5}  entries={3,6}  entries-in-gated={4,6}  highest-gate={5}" -f `
    $type, $tot, $multi, $entriesTot, $gatedEntries, $maxGate
}
