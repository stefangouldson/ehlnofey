# Phase 4 step 5 - author Ehlnofey's 19 constant records.
# Guardrail 3: copy the source record VERBATIM from reference/ and edit only the field that differs.
# Sources are the WINNING record for each FormKey (CLAUDE.md: resolve by master, last-wins).
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$dst = 'src/Ehlnofey/EhlnofeyESP'

function Copy-Record($srcPath, $subdir) {
  $d = Join-Path $dst $subdir
  if (-not (Test-Path $d)) { New-Item -ItemType Directory -Force $d | Out-Null }
  $out = Join-Path $d (Split-Path $srcPath -Leaf)
  Copy-Item $srcPath $out -Force
  return $out
}

# ---- 1. the GMST: fSpecialLootMinPCLevelMult 0.6 -> 0 (loot-model.md 4; probe test 3 verified)
$p = Copy-Record 'reference/Base/01Skyrim/GameSettings/fSpecialLootMinPCLevelMult - 10FEDE_Skyrim.esm.yaml' 'GameSettings'
(Get-Content $p) -replace '^Data: 0\.6$', 'Data: 0' | Set-Content $p -Encoding utf8
"GMST  fSpecialLootMinPCLevelMult -> 0"

# ---- 2. the 12 LevelGate* globals -> 1 (tiers.md 8: vanilla's only systematic player-level gate)
foreach ($f in Get-ChildItem 'reference/Base/01Skyrim/Globals' -Filter 'LevelGate*.yaml') {
  $p = Copy-Record $f.FullName 'Globals'
  (Get-Content $p) -replace '^Data: \d+$', 'Data: 1' | Set-Content $p -Encoding utf8
}
"GLOB  12 LevelGate* -> 1"

# ---- 3. the named capstones: PcLevelMult -> a fixed level (archetype-tiers.md 7)
$named = @(
  @{ f='reference/Base/01Skyrim/Npcs/AlduinBase - 08E4F1_Skyrim.esm.yaml';                 lvl=60 },
  @{ f='reference/Base/03Dawnguard/Npcs/DLC1Harkon - 003BA7_Dawnguard.esm.yaml';           lvl=55 },
  @{ f='reference/Base/03Dawnguard/Npcs/DLC1HarkonCombat - 01A93D_Dawnguard.esm.yaml';     lvl=60 },
  @{ f='reference/Base/05Dragonborn/Npcs/DLC2Miraak - 017F7D_Dragonborn.esm.yaml';         lvl=65 },
  @{ f='reference/Base/05Dragonborn/Npcs/DLC2MiraakMQ06 - 01FB98_Dragonborn.esm.yaml';     lvl=65 },
  @{ f='reference/Base/05Dragonborn/Npcs/DLC2AcolyteZahkriisos - 0248E8_Dragonborn.esm.yaml'; lvl=60 }
)
foreach ($n in $named) {
  $p = Copy-Record $n.f 'Npcs'
  $out = New-Object System.Collections.ArrayList
  # 0 = scanning, 1 = inside the Level: block. CalcMin/CalcMaxLevel are KEPT: they are inert once
  # the level is fixed, vanilla NpcLevel records carry them anyway, and Requiem keeps them too -
  # dropping them made these the only records that differ from vanilla outside the Level block.
  $state = 0
  foreach ($line in (Get-Content $p)) {
    if ($state -eq 0 -and $line -eq '  Level:') {
      [void]$out.Add('  Level:')
      [void]$out.Add('    MutagenObjectType: NpcLevel')
      [void]$out.Add('    Level: ' + $n.lvl)
      $state = 1; continue
    }
    if ($state -eq 1) {
      # drop the PcLevelMult payload lines (4-space indent under Level:)
      if ($line -match '^    (MutagenObjectType|LevelMult):') { continue }
      $state = 2
    }
    [void]$out.Add($line)
  }
  if ($state -lt 2) { throw "level block not found in $p" }
  $out | Set-Content $p -Encoding utf8
  "NPC_  {0,-26} -> fixed {1}" -f (($n.f -split '/')[-1] -replace ' - .*',''), $n.lvl
}

""
"total records: " + (Get-ChildItem $dst -Recurse -Filter '*.yaml' | Where-Object { $_.Name -ne 'RecordData.yaml' }).Count
