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
# The level-1 bandit rung is the only one vanilla leaves unnamed. Every other rung carries its FULL
# on a per-weapon "template" record (EncBandit02TemplateMelee = "Bandit Outlaw", &c.), and the rung's
# per-race leaves carry no FULL at all - so the obvious fix was to name the three EncBandit01Template*
# records and let the leaves inherit, exactly as rung 2 appears to.
#
# THAT DID NOT WORK IN GAME (2026-07-31). Named all three, shipped it, and level-1 bandits still read
# "Bandit". The build was verified deployed byte-identical and Ehlnofey.esp loads last in the test
# bed, so it was not a conflict or a stale file - the assumption about how a nameless leaf resolves
# its FULL is simply wrong, and this workspace has no way to test the engine directly.
#
# So: stop depending on the rule. Name **every** record in the rung - all 44 - so that whichever one
# the engine actually reads, it finds the same string. 3 templates + 41 leaves (1H, 2H, Tank,
# Berserk, Magic, Missile, per race and sex). Redundant under the inheritance model, correct under
# every model. Records are cheap; another failed in-game test cycle is not.
#
# Not renamed on purpose: EncBandit00Template 039CF4 "Bandit" stays the family default, so anything
# outside this rung that falls through to it is untouched.
#
# Name goes between Class: and PlayerSkills: - Spriggit's canonical order, confirmed against
# EncBandit02TemplateMelee 01BCD9. The round-trip re-serialize is what guarantees it.

$srcDir = 'reference/Base/01Skyrim/Npcs'
$runts = @(Get-ChildItem -LiteralPath $srcDir -Filter 'EncBandit01*.yaml' | Sort-Object Name)
if ($runts.Count -lt 40) { throw "expected ~44 EncBandit01* records, found $($runts.Count)" }

$dir = Join-Path $dst 'Npcs'
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
$dirAbs = (Resolve-Path -LiteralPath $dir).Path

$n = 0
foreach ($src in $runts) {
  $lines = @(Get-Content -LiteralPath $src.FullName)

  # A vanilla record here must be nameless; if one ever ships a FULL, stop rather than clobber it.
  if ($lines -match '^Name:') { throw "$($src.Name) already has a Name - re-check the rung" }

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
  if (-not $placed) { throw "no PlayerSkills: anchor in $($src.Name)" }

  # Absolute path required: [System.IO.File] resolves relative paths against .NET's current
  # directory, which PowerShell does NOT keep in sync with Set-Location.
  [System.IO.File]::WriteAllLines((Join-Path $dirAbs $src.Name), $out.ToArray(), $utf8NoBom)
  $n++
}

"names: $n records -> `"Bandit Runt`""
