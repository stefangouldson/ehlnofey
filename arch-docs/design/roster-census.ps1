# Does place topography survive list flattening?
# For every Skyrim.esm interior cell: its EncounterZone and the multiset of PlacedNpc bases.
# If different dungeons place DIFFERENT leveled bases, flattening keeps some place variation.
# If they all place the same handful, flattening makes every dungeon of a type identical.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$base = 'reference/Base/01Skyrim'

# --- index: FormID -> EditorID, from Spriggit filenames (CLAUDE.md: filename matching, not grep -rl)
$idx = @{}
foreach ($t in @('Npcs','LeveledNpcs')) {
  foreach ($f in Get-ChildItem (Join-Path $base $t) -Filter *.yaml) {
    if ($f.Name -match '^(.*) - ([0-9A-Fa-f]{6})_Skyrim\.esm\.yaml$') {
      $idx[$Matches[2].ToUpper()] = $Matches[1]
    }
  }
}
Write-Host "index: $($idx.Count) NPC/LVLN records"

$rows = New-Object System.Collections.ArrayList
foreach ($cellDir in Get-ChildItem (Join-Path $base 'Cells') -Directory -Recurse |
                     Where-Object { Test-Path (Join-Path $_.FullName 'RecordData.yaml') }) {
  $name = $cellDir.Name -replace ' - [0-9A-Fa-f]{6}_Skyrim\.esm$',''
  $zone = ''
  $cur  = ''
  $bases = New-Object System.Collections.ArrayList
  foreach ($line in [System.IO.File]::ReadLines((Join-Path $cellDir.FullName 'RecordData.yaml'))) {
    if     ($line -match 'MutagenObjectType:\s*(\w+)')            { $cur = $Matches[1] }
    elseif ($line -match '^\s*EncounterZone:\s*([0-9A-Fa-f]{6}):') { if ($zone -eq '') { $zone = $Matches[1].ToUpper() } }
    elseif ($cur -eq 'PlacedNpc' -and $line -match '^\s*Base:\s*([0-9A-Fa-f]{6}):Skyrim\.esm') {
      [void]$bases.Add($Matches[1].ToUpper())
    }
  }
  if ($bases.Count -eq 0) { continue }
  # keep only bases whose EditorID looks leveled (Lvl* placed refs, or a direct LChar* list)
  $lvl = @($bases | ForEach-Object { $e = $idx[$_]; if ($e -and ($e -like 'Lvl*' -or $e -like 'LChar*')) { $e } })
  [void]$rows.Add([pscustomobject]@{
    Cell = $name; Zone = $zone; Placed = $bases.Count
    LvlRefs = $lvl.Count; LvlSet = (@($lvl | Sort-Object -Unique) -join '|')
  })
}

$rows | Export-Csv -Path "$PSScriptRoot\rosters.csv" -NoTypeInformation -Encoding utf8
"cells with placed NPCs : {0}" -f $rows.Count
"…with leveled refs     : {0}" -f @($rows | Where-Object { $_.LvlRefs -gt 0 }).Count
"…zoned                 : {0}" -f @($rows | Where-Object { $_.Zone -ne '' }).Count
"distinct leveled bases : {0}" -f @($rows | ForEach-Object { $_.LvlSet -split '\|' } | Where-Object { $_ } | Sort-Object -Unique).Count
"distinct roster-sets   : {0}" -f @($rows | Where-Object { $_.LvlRefs -gt 0 } | Select-Object -ExpandProperty LvlSet | Sort-Object -Unique).Count
