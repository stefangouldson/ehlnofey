# Phase 4 - author display names.
#
# Runs LAST, after author-constants.ps1 -> extract-requiem.ps1 -> author-bucket-d.ps1, because it
# writes NPC_ records the extract may also touch. Nothing here changes a level or a list; the only
# field written is Name.
#
# Guardrail 3: copy the source record VERBATIM from reference/ and edit only the field that differs.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$dst = 'src/Ehlnofey/EhlnofeyESP'
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

# ---------------------------------------------------------------- Bandit Runt
#
# The level-1 bandit rung is the only one vanilla leaves unnamed, so it falls through the template
# chain to EncBandit00Template 039CF4 = "Bandit" - the shared root of the whole family. Naming the
# rung's own three templates intercepts that fallback one hop earlier, which is exactly the slot
# EncBandit02TemplateMelee already uses to say "Bandit Outlaw":
#
#   EncBandit01Melee1H<race><sex>   no FULL, no Traits flag
#     -> EncBandit01TemplateMelee   <-- the name goes HERE
#       -> EncBandit00Template      "Bandit"   (left alone: still the family default)
#
# Dependents were censused before writing (archetype-tiers.md 3.1). All 25 bandit leaves are caught,
# which is the point. Three non-bandits also template off these records:
#   encGhost01Magic            carries its own FULL "Ghost"  -> unaffected
#   dunLiarsRetreatWenchCorpse no FULL -> becomes "Bandit Runt". It is a dead level-1 bandit in a
#                              bandit dungeon and today reads "Bandit", so this is correct, if drier.
#   DEMO_Bandit1HNordM / WarehouseNPCWebActorSit   dev-only records, not placed in the playable world
#
# Name goes between Class: and PlayerSkills: - Spriggit's canonical order, confirmed against
# EncBandit02TemplateMelee 01BCD9. The round-trip re-serialize is what guarantees it.
$runts = @(
  'reference/Base/01Skyrim/Npcs/EncBandit01TemplateMelee - 039CFD_Skyrim.esm.yaml',
  'reference/Base/01Skyrim/Npcs/EncBandit01TemplateMagic - 039D31_Skyrim.esm.yaml',
  'reference/Base/01Skyrim/Npcs/EncBandit01TemplateMissile - 037C2C_Skyrim.esm.yaml'
)

$n = 0
foreach ($src in $runts) {
  if (-not (Test-Path -LiteralPath $src)) { throw "missing source record: $src" }
  $lines = @(Get-Content -LiteralPath $src)

  if ($lines -match '^Name:') { throw "$src already has a Name - the fallback assumption is wrong" }

  $out = New-Object System.Collections.ArrayList
  $placed = $false
  foreach ($l in $lines) {
    if ($l -eq 'PlayerSkills:' -and -not $placed) {
      [void]$out.Add('Name:')
      [void]$out.Add('  TargetLanguage: English')
      [void]$out.Add('  Value: Bandit Runt')
      $placed = $true
    }
    [void]$out.Add($l)
  }
  if (-not $placed) { throw "no PlayerSkills: anchor in $src" }

  $dir = Join-Path $dst 'Npcs'
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
  $path = Join-Path $dir (Split-Path $src -Leaf)
  [System.IO.File]::WriteAllLines($path, $out.ToArray(), $utf8NoBom)
  $n++
}

"names: $n records -> `"Bandit Runt`""
