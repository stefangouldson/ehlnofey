# Stage 1 - extract Requiem's deleveling layer into Ehlnofey.esp.
#
# Requiem has already done the flattening ("flatten the gate, keep the pool") and most of its flat
# records are built from VANILLA FormKeys only, so they lift straight across. Overrides keep the
# defining master's FormKey suffix, so nothing needs renumbering - for most records this is a file
# copy. See the plan in arch-docs/design/requiem-method.md.
#
# Buckets:
#   A  copy verbatim          - LVLN/LVLI whose every FormKey belongs to one of our four masters
#   B  strip foreign entries  - LVLI that also reference Requiem-only gear; drop those entries
#   C  vanilla flatten        - Requiem never covered it, or B emptied it: take vanilla, Level -> 1
#   D  provisional flatten    - the 66 LVLN built on Requiem's REQ_LChar_VoiceSpawns_* sublists.
#                               Those sublists are Requiem-only AND still gated, so nothing is
#                               copyable. C's rule is applied as a placeholder; these are the lists
#                               archetype-tiers.md 4/4.1 must author by hand.
#   E  graft the level field  - NPC_: copy the VANILLA record, replace only Configuration.Level.
#                               Requiem's HealthOffset / dropped AutoCalcStats are its capability
#                               overhaul, not deleveling, and are deliberately left behind.
#
# Idempotent: re-run freely. Everything it writes, it overwrites.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$req     = 'reference/mods/RequiemYaml'
$base    = 'reference/Base'
$dst     = 'src/Ehlnofey/EhlnofeyESP'
$masters = @('Skyrim.esm', 'Update.esm', 'Dawnguard.esm', 'Dragonborn.esm')
# reference/Base is laid out in load order; last assignment wins (CLAUDE.md: base+DLC index rule)
$loadOrder = @('01Skyrim', '02Update', '03Dawnguard', '04HearthFires', '05Dragonborn')

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
function Write-Yaml($path, $lines) {
    $d = Split-Path $path -Parent
    if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Force $d | Out-Null }
    [System.IO.File]::WriteAllLines((Resolve-Path -LiteralPath $d).Path + '\' + (Split-Path $path -Leaf), $lines, $utf8NoBom)
}

# FormKey -> path, for one record-type folder, resolved in load order.
function New-VanillaIndex($type) {
    $ix = @{}
    foreach ($d in $loadOrder) {
        $p = Join-Path $base "$d/$type"
        if (-not (Test-Path -LiteralPath $p)) { continue }
        foreach ($f in Get-ChildItem -LiteralPath $p -Filter '*.yaml') {
            if ($f.Name -match '- ([0-9A-F]+)_(.+)\.yaml$') { $ix["$($Matches[1]):$($Matches[2])"] = $f.FullName }
        }
    }
    return $ix
}

# Every FormKey master mentioned anywhere in the file that is NOT one of ours.
function Get-ForeignMasters($lines) {
    $found = @{}
    foreach ($l in $lines) {
        foreach ($m in [regex]::Matches($l, '[0-9A-Fa-f]{6}:([^\s,}\]''"]+)')) {
            $mk = $m.Groups[1].Value
            if ($masters -notcontains $mk) { $found[$mk] = $true }
        }
    }
    return ,@($found.Keys)   # comma-wrap: a bare array return unrolls, and 0/1 elements lose .Count
}

# Version noise differs between a Requiem record and a vanilla one for reasons that are not edits.
function Get-Comparable($lines) { ,@($lines | Where-Object { $_ -notmatch '^(VersionControl|FormVersion|Version2):' }) }

# Leveled-list entries are col-0 '- Data:' blocks; children are indented. Returns the file split
# into (before, entry blocks, after) so blocks can be dropped without touching anything else.
# The trailer matters: some records carry a Model: block AFTER Entries:, and appending the rebuilt
# entries instead of splicing them back in place produces invalid YAML.
function Split-Entries($lines) {
    $pre = New-Object System.Collections.ArrayList
    $post = New-Object System.Collections.ArrayList
    $blocks = New-Object System.Collections.ArrayList
    $cur = $null
    $seen = $false
    $doneEntries = $false
    foreach ($l in $lines) {
        if ($l -eq '- Data:' -and -not $doneEntries) {
            if ($cur) { [void]$blocks.Add($cur) }
            $cur = New-Object System.Collections.ArrayList
            [void]$cur.Add($l); $seen = $true; continue
        }
        if ($cur -ne $null) {
            if ($l -match '^\S') { [void]$blocks.Add($cur); $cur = $null; $doneEntries = $true }  # col-0 key ends the run
            else { [void]$cur.Add($l); continue }
        }
        if ($doneEntries) { [void]$post.Add($l) } else { [void]$pre.Add($l) }
    }
    if ($cur) { [void]$blocks.Add($cur) }
    return [pscustomobject]@{ Pre = $pre; Post = $post; Blocks = $blocks; HasEntries = $seen }
}

# Rebuild a list file from its preamble, a filtered set of entry blocks, and its trailer.
function Join-Entries($split, $blocks) {
    $out = New-Object System.Collections.ArrayList
    foreach ($l in $split.Pre) { [void]$out.Add($l) }
    foreach ($b in $blocks) { foreach ($l in $b) { [void]$out.Add($l) } }
    foreach ($l in $split.Post) { [void]$out.Add($l) }
    return $out
}

# Set every entry's Level: to 1 - the flatten rule, applied to a vanilla record.
function Set-EntriesFlat($lines) {
    ,@($lines | ForEach-Object { if ($_ -match '^    Level: \d+$') { '    Level: 1' } else { $_ } })
}

# Configuration.Level is a discriminated union; TemplateFlags: Stats makes the NPC's own level inert.
function Get-NpcLevel($lines) {
    $type = ''; $value = ''; $owns = $true; $s = 0; $tf = $false; $from = -1; $to = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $l = $lines[$i]
        if ($l -eq 'Configuration:') { $s = 1; continue }
        if ($s -eq 0) { continue }
        if ($l -match '^\S') { break }                       # left the Configuration block
        if ($l -eq '  Level:') { $from = $i; $tf = $false; continue }
        if ($l -eq '  TemplateFlags:') { $tf = $true; continue }
        if ($from -ge 0 -and $to -lt 0) {
            if ($l -match '^    MutagenObjectType: (\S+)') { $type = $Matches[1]; continue }
            if ($l -match '^    (Level|LevelMult): (\S+)') { $value = $Matches[2]; continue }
            $to = $i - 1
        }
        if ($tf) { if ($l -eq '  - Stats') { $owns = $false } elseif ($l -notmatch '^  - ') { $tf = $false } }
    }
    if ($from -ge 0 -and $to -lt 0) { $to = $lines.Count - 1 }
    return [pscustomobject]@{ Type = $type; Value = $value; Owns = $owns; From = $from; To = $to }
}

# ---------------------------------------------------------------- run

$stats = [ordered]@{
    'A copied verbatim'   = 0
    'B stripped'          = 0
    'C vanilla flatten'   = 0
    'D provisional LVLN'  = 0
    'E level graft'       = 0
    'skipped, ITM'        = 0
    'skipped, sentinel'   = 0   # Requiem's Level: 999 placeholder
    'skipped, not ours'   = 0   # Requiem's own new records, HearthFires, CC, USSEP
    'skipped, no vanilla' = 0
}
$provisional = New-Object System.Collections.ArrayList

# Only this script writes the leveled-list folders, so clear them - otherwise a record that moves
# bucket (or leaves the set) survives as a stale file. Npcs/ is left alone: it also holds the
# hand-authored capstones from author-constants.ps1, and bucket E overwrites what it owns.
foreach ($t in @('LeveledNpcs', 'LeveledItems')) {
    $p = Join-Path $dst $t
    if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force }
}

foreach ($type in @('LeveledNpcs', 'LeveledItems')) {
    $vix = New-VanillaIndex $type
    $isLvln = ($type -eq 'LeveledNpcs')
    $covered = @{}

    foreach ($f in Get-ChildItem -LiteralPath (Join-Path $req $type) -Filter '*.yaml') {
        # Records Requiem has disconnected from its world, one way or another. REQ_NULL_ is gutted;
        # REQ_LEGACY_ is redirected to point at a different list; REQ_BashedPatch_TestList hijacks a
        # vanilla vendor list as a marker and empties it. None of that is deleveling - leave them
        # unmarked so the uncovered pass below flattens the vanilla record if it is gated.
        if ($f.Name -match '^REQ_(NULL|LEGACY|BashedPatch)_') { continue }
        if ($f.Name -notmatch '- ([0-9A-F]+)_(.+)\.yaml$') { continue }
        $key = "$($Matches[1]):$($Matches[2])"
        if ($masters -notcontains $Matches[2]) { $stats['skipped, not ours']++; continue }   # HearthFires / CC / USSEP
        $covered[$key] = $true

        $lines = @(Get-Content -LiteralPath $f.FullName)
        $foreign = Get-ForeignMasters $lines
        $vpath = $vix[$key]
        # Requiem renames ~150 vanilla lists into its own taxonomy (LItemWeaponSword ->
        # REQ_LI_Loot_Weapon_Sword). A rename is not deleveling, and it makes the record
        # unrecognisable in xEdit, so put the vanilla EditorID back.
        $name = $f.Name
        if ($vpath) {
            $vname = (Split-Path $vpath -Leaf) -replace ' - [0-9A-F]+_.+\.yaml$', ''
            $lines = @($lines | ForEach-Object { if ($_ -match '^EditorID: ') { "EditorID: $vname" } else { $_ } })
            $name = Split-Path $vpath -Leaf
        }

        # Requiem empties some vanilla lists outright (LootDraugrGold, DeathItemDraugrGold, the
        # Forsworn jewellery lists...) because it removes gold and trinkets from those sources.
        # That is its ECONOMY design, not deleveling - copying it verbatim would delete loot from
        # the game. Fall through to the vanilla flatten instead.
        $reqEntries = @($lines | Where-Object { $_ -match '^    Level: \d+$' }).Count
        $vanEntries = 0
        if ($vpath) { $vanEntries = @(Get-Content -LiteralPath $vpath | Where-Object { $_ -match '^    Level: \d+$' }).Count }
        $emptied = ($reqEntries -eq 0 -and $vanEntries -gt 0)

        if ($foreign.Count -eq 0 -and -not $emptied) {
            if ($vpath -and -not (Compare-Object (Get-Comparable $lines) (Get-Comparable @(Get-Content -LiteralPath $vpath)))) {
                $stats['skipped, ITM']++; continue                                          # bucket A, but an ITM
            }
            Write-Yaml (Join-Path $dst "$type/$name") $lines                    # bucket A
            $stats['A copied verbatim']++; continue
        }

        # A leveled-NPC list that leans on Requiem's own spawn records cannot be salvaged by
        # stripping - what is left is not the archetype. Fall through to the vanilla flatten and
        # mark it for hand-authoring.
        if (-not $isLvln -and -not $emptied) {
            $split = Split-Entries $lines
            $keep = @($split.Blocks | Where-Object { (Get-ForeignMasters $_).Count -eq 0 })
            if ($keep.Count -gt 0) {
                Write-Yaml (Join-Path $dst "$type/$name") (Join-Entries $split $keep)   # bucket B
                $stats['B stripped']++; continue
            }
        }

        if (-not $vpath) { $stats['skipped, no vanilla']++; continue }
        Write-Yaml (Join-Path $dst "$type/$(Split-Path $vpath -Leaf)") (Set-EntriesFlat @(Get-Content -LiteralPath $vpath))
        if ($isLvln) { $stats['D provisional LVLN']++; [void]$provisional.Add($f.BaseName) } else { $stats['C vanilla flatten']++ }
    }

    # Gated vanilla lists Requiem never overrode at all (LVLN: 8; LVLI: the 7 residual gates).
    foreach ($key in $vix.Keys) {
        if ($covered.ContainsKey($key)) { continue }
        $lines = @(Get-Content -LiteralPath $vix[$key])
        $levels = @($lines | Where-Object { $_ -match '^    Level: (\d+)$' } | ForEach-Object { $Matches[1] } | Sort-Object -Unique)
        if ($levels.Count -le 1) { continue }                                   # already flat
        Write-Yaml (Join-Path $dst "$type/$(Split-Path $vix[$key] -Leaf)") (Set-EntriesFlat $lines)
        $stats['C vanilla flatten']++
    }
}

# ---- residual gates: Requiem itself keeps a handful of live player-level gates. Bone 1 does not
# allow them. Level: 9999 is exempt - that is Requiem's (and Twist 4's) disable-an-entry-in-place
# idiom, not a gate the player can grow into.
$degated = New-Object System.Collections.ArrayList
foreach ($type in @('LeveledNpcs', 'LeveledItems')) {
    foreach ($f in Get-ChildItem -LiteralPath (Join-Path $dst $type) -Filter '*.yaml') {
        $lines = @(Get-Content -LiteralPath $f.FullName)
        $gates = @($lines | Where-Object { $_ -match '^    Level: (\d+)$' -and $Matches[1] -ne '1' -and $Matches[1] -ne '9999' } |
                            ForEach-Object { if ($_ -match '(\d+)$') { $Matches[1] } } | Sort-Object -Unique)
        if ($gates.Count -eq 0) { continue }
        Write-Yaml (Join-Path $dst "$type/$($f.Name)") @($lines | ForEach-Object {
            if ($_ -match '^    Level: (\d+)$' -and $Matches[1] -ne '9999') { '    Level: 1' } else { $_ } })
        [void]$degated.Add(('{0,-14} {1}  gates: {2}' -f $type, $f.BaseName, ($gates -join ',')))
    }
}

# ---- bucket E: NPC_ level graft
$vnpc = New-VanillaIndex 'Npcs'
foreach ($f in Get-ChildItem -LiteralPath (Join-Path $req 'Npcs') -Filter '*.yaml') {
    if ($f.Name -like 'REQ_NULL_*') { continue }
    if ($f.Name -notmatch '- ([0-9A-F]+)_(.+)\.yaml$') { continue }
    $key = "$($Matches[1]):$($Matches[2])"
    if ($masters -notcontains $Matches[2]) { $stats['skipped, not ours']++; continue }

    $ri = Get-NpcLevel @(Get-Content -LiteralPath $f.FullName)
    if ($ri.Type -ne 'NpcLevel') { continue }     # Requiem left it scaling - stage 2 decides
    if (-not $ri.Owns) { continue }               # TemplateFlags: Stats - its own level is inert
    # 999 is Requiem's "unreachable" sentinel (the SummonAtronach*ThrallPotent conjures), not a
    # tier - prior-art/requiem/plugin-analysis.md 1c. Vanilla has them at 35, and with vanilla
    # AutoCalcStats behind it a level-999 summon is meaningless. Keep vanilla.
    if ([int]$ri.Value -ge 999) { $stats['skipped, sentinel']++; continue }
    $vpath = $vnpc[$key]
    if (-not $vpath) { $stats['skipped, no vanilla']++; continue }

    $vlines = @(Get-Content -LiteralPath $vpath)
    $vi = Get-NpcLevel $vlines
    if ($vi.From -lt 0) { $stats['skipped, no vanilla']++; continue }
    if ($vi.Type -eq 'NpcLevel' -and $vi.Value -eq $ri.Value) { $stats['skipped, ITM']++; continue }

    $out = New-Object System.Collections.ArrayList
    for ($i = 0; $i -lt $vlines.Count; $i++) {
        if ($i -eq $vi.From) {
            [void]$out.Add('  Level:')
            [void]$out.Add('    MutagenObjectType: NpcLevel')
            [void]$out.Add('    Level: ' + $ri.Value)
            continue
        }
        if ($i -gt $vi.From -and $i -le $vi.To) { continue }
        [void]$out.Add($vlines[$i])
    }
    Write-Yaml (Join-Path $dst "Npcs/$(Split-Path $vpath -Leaf)") $out
    $stats['E level graft']++
}

# ---- master-leak assertion: nothing under EhlnofeyESP may reference a fifth master
$leaks = @{}
foreach ($f in Get-ChildItem -LiteralPath $dst -Recurse -Filter '*.yaml') {
    if ($f.Name -eq 'RecordData.yaml') { continue }
    # assign before enumerating: foreach over a comma-wrapped empty array iterates once with $m = @()
    $fm = Get-ForeignMasters @(Get-Content -LiteralPath $f.FullName)
    if ($fm.Count -eq 0) { continue }
    foreach ($m in $fm) { $leaks["$m <- $($f.Name)"] = $true }
}

''
foreach ($k in $stats.Keys) { '{0,-10} {1}' -f $k, $stats[$k] }
'records    ' + (Get-ChildItem -LiteralPath $dst -Recurse -Filter '*.yaml' | Where-Object { $_.Name -ne 'RecordData.yaml' }).Count
''
if ($leaks.Count -gt 0) {
    @($leaks.Keys) | Sort-Object | ForEach-Object { "LEAK  $_" }
    throw "$($leaks.Count) master leak(s) - see above"
}
'no master leaks: Skyrim / Update / Dawnguard / Dragonborn only'

if ($degated.Count -gt 0) {
    ''
    "de-gated (Requiem kept a live player gate; bone 1 does not):"
    $degated | Sort-Object | ForEach-Object { "  $_" }
}

if ($provisional.Count -gt 0) {
    $rep = 'arch-docs/design/bucket-d-provisional.txt'
    [System.IO.File]::WriteAllLines((Join-Path (Get-Location) $rep), (@(
        "# Bucket D - $($provisional.Count) LVLN written as a naive vanilla flatten, PROVISIONAL.",
        "# Requiem's versions are unusable: they delegate to REQ_LChar_VoiceSpawns_* sublists that are",
        "# Requiem-only AND still player-gated (1/2/5/8/9/10). These are the lists archetype-tiers.md",
        "# 4/4.1 must author by hand - in particular the LCharAnimal* biome rosters, where a naive",
        "# flatten inherits the level-35 density-ramp mix (BearCave x7 dominant) instead of freezing",
        "# each biome at the reference level of its assigned tier."
    ) + @($provisional | Sort-Object)), $utf8NoBom)
    "bucket D written to $rep"
}
