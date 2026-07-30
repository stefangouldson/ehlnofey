# archetype-tiers.md 4.1 - enumerate the ambient biome lists.
#
# Dumps every entry of the LCharAnimal* wilderness lists with its gate level and the RESOLVED
# level of the NPC behind it, following TemplateFlags: Stats up the template chain (CLAUDE.md:
# "follow the template chain all the way to an LVLN, not just one hop").
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$roots = @('reference/Base/01Skyrim','reference/Base/02Update',
           'reference/Base/03Dawnguard','reference/Base/05Dragonborn')

# ---- index every NPC_ and LVLN by FormKey
$ed = @{}; $npcFile = @{}; $isLvln = @{}
foreach ($p in $roots) {
  foreach ($t in @('Npcs','LeveledNpcs')) {
    $dir = Join-Path $p $t; if (-not (Test-Path $dir)) { continue }
    foreach ($f in Get-ChildItem $dir -Filter *.yaml) {
      if ($f.Name -notmatch '^(.*) - ([0-9A-Fa-f]{6})_(.+)\.yaml$') { continue }
      $k = $Matches[2].ToUpper()+':'+$Matches[3]
      $ed[$k] = $Matches[1]; $npcFile[$k] = $f.FullName      # last-wins = winning override
      $isLvln[$k] = ($t -eq 'LeveledNpcs')
    }
  }
}

# ---- resolve one NPC's owned level, honouring TemplateFlags: Stats
function Resolve-Level([string]$key, [int]$depth) {
  if ($depth -gt 8 -or -not $npcFile.ContainsKey($key)) { return 'deref?' }
  if ($isLvln[$key]) { return 'LVLN:'+$ed[$key] }
  $lvl = 0; $mult = ''; $tmpl = ''; $stats = $false
  $inCfg = $false; $inLvl = $false; $inFlags = $false
  foreach ($line in [System.IO.File]::ReadLines($npcFile[$key])) {
    if ($line -match '^Configuration:')                       { $inCfg = $true;  continue }
    if ($line -match '^[A-Za-z]')                             { $inCfg = $false; $inLvl = $false; $inFlags = $false }
    if ($line -match '^Template:\s*([0-9A-Fa-f]{6}):(\S+)')   { $tmpl = $Matches[1].ToUpper()+':'+$Matches[2]; continue }
    if ($inCfg -and $line -match '^  Level:')                 { $inLvl = $true;  continue }
    if ($inCfg -and $line -match '^  TemplateFlags:')         { $inFlags = $true; continue }
    if ($inCfg -and $line -match '^  \S')                     { $inLvl = $false; $inFlags = $false }
    if ($inLvl   -and $line -match '^\s+Level:\s*(\d+)')      { $lvl = [int]$Matches[1] }
    if ($inLvl   -and $line -match '^\s+LevelMult:\s*([\d.]+)') { $mult = $Matches[1] }
    if ($inFlags -and $line -match '^\s*-\s*Stats\s*$')       { $stats = $true }
  }
  if ($stats -and $tmpl -ne '') { return Resolve-Level $tmpl ($depth+1) }
  if ($mult -ne '') { return 'PcLevelMult x'+$mult }
  return [string]$lvl
}

# ---- dump the ambient lists
$lists = New-Object System.Collections.ArrayList
foreach ($p in $roots) {
  $dir = Join-Path $p 'LeveledNpcs'; if (-not (Test-Path $dir)) { continue }
  foreach ($f in Get-ChildItem $dir -Filter *.yaml) {
    if ($f.Name -match 'LCharAnimal|LCharMudcrab|LCharBearPlainsForestHills|LCharSpriggan|LCharWitchAny|LCharDeer|LCharElk') {
      [void]$lists.Add($f)
    }
  }
}

foreach ($f in ($lists | Sort-Object Name)) {
  $f.Name -match '^(.*) - ([0-9A-Fa-f]{6})_(.+)\.yaml$' | Out-Null
  $name = $Matches[1]; $fk = $Matches[2].ToUpper()+':'+$Matches[3]
  $flags = @(); $entries = New-Object System.Collections.ArrayList
  $curLvl = $null; $inFlags = $false
  foreach ($line in [System.IO.File]::ReadLines($f.FullName)) {
    if ($line -match '^Flags:')                                     { $inFlags = $true; continue }
    if ($inFlags) { if ($line -match '^-\s*(\S+)') { $flags += $Matches[1]; continue } else { $inFlags = $false } }
    if ($line -match '^\s+Level:\s*(\d+)\s*$')                      { $curLvl = [int]$Matches[1] }
    if ($line -match '^\s+Reference:\s*([0-9A-Fa-f]{6}):(\S+)\s*$') {
      $r = $Matches[1].ToUpper()+':'+$Matches[2]
      $nm = if ($ed.ContainsKey($r)) { $ed[$r] } else { $r }
      [void]$entries.Add([pscustomobject]@{ Gate=$curLvl; Ref=$nm; L=(Resolve-Level $r 0) })
    }
  }
  ""
  "### {0}  ({1}){2}" -f $name, $fk, $(if ($flags.Count) { '  flags: ' + ($flags -join ',') } else { '  NO FLAGS' })
  $grp = $entries | Group-Object Ref | Sort-Object { ($_.Group | Select-Object -First 1).Gate }
  foreach ($g in $grp) {
    $e = $g.Group | Select-Object -First 1
    "   gate {0,-3}  x{1,-2}  {2,-34} L={3}" -f $e.Gate, $g.Count, $e.Ref, $e.L
  }
  "   -- {0} entries, {1} distinct, gates: {2}" -f $entries.Count, $grp.Count,
     ((@($entries | Select-Object -ExpandProperty Gate | Sort-Object -Unique)) -join '/')
}
