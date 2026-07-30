# Dot-source from the repo root to load workspace tool paths:
#     . ".claude/config/tools.ps1"
#     & $Tools.spriggitCli serialize ...
#
# Reads .claude/config/tools.json (machine-specific, gitignored). Falls back to
# tools.example.json so a fresh clone still resolves. Populate/refresh tools.json
# with the `modlist-install` skill.

$cfgDir = Split-Path -Parent $PSCommandPath
$cfgPath = Join-Path $cfgDir 'tools.json'
if (-not (Test-Path $cfgPath)) {
    $cfgPath = Join-Path $cfgDir 'tools.example.json'
    Write-Warning "tools.json not found; using tools.example.json. Run the modlist-install skill to generate tools.json."
}
$Tools = Get-Content -Raw -LiteralPath $cfgPath | ConvertFrom-Json

# Verify the tools an operation needs before relying on them. Usage:
#     Assert-Tool $Tools.papyrusCompiler 'papyrusCompiler'
function Assert-Tool {
    param([string]$Path, [string]$Name)
    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw "Config key '$Name' is empty in $cfgPath. Set it (modlist-install skill) and retry."
    }
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "'$Name' points at a missing path: $Path  (config: $cfgPath)"
    }
    return $Path
}

# Build a data directory containing EVERY master, for tools that need them side by side.
#
# Why this exists: an MO2 modlist does not keep the DLC in the game folder. It keeps them as a mod
# (here 'Cleaned Masters') and virtualises them in at launch. So $Tools.gameDataDir holds only
# Skyrim.esm, and anything run OUTSIDE MO2 -- headless xEdit especially -- cannot resolve
# Update/Dawnguard/HearthFires/Dragonborn. xEdit's failure mode is a MODAL ERROR DIALOG, which reads
# as "the tool hung" when run non-interactively.
#
# Masters are HARD-LINKED, so this costs no disk space and is instant, provided the composite dir is
# on the same volume as the sources. Falls back to copying if not.
#
#     . ".claude/config/tools.ps1"
#     $d = New-MasterDataDir -Plugin "build/staging/Ehlnofey/Ehlnofey.esp"
#     & $Tools.sseeditQuickAutoClean -autoload "Ehlnofey.esp" -D:"$d"
function New-MasterDataDir {
    param(
        [string]$Plugin,                                             # optional: staged in alongside
        [string]$Path = (Join-Path $env:TEMP 'EhlnofeyMasterData')   # composite dir
    )
    if (-not (Test-Path -LiteralPath $Path)) { New-Item -ItemType Directory -Force $Path | Out-Null }

    $sources = @($Tools.gameDataDir)
    if (-not [string]::IsNullOrWhiteSpace($Tools.cleanedMastersDir)) { $sources += $Tools.cleanedMastersDir }

    $missing = @()
    foreach ($m in @('Skyrim.esm','Update.esm','Dawnguard.esm','HearthFires.esm','Dragonborn.esm')) {
        $dest = Join-Path $Path $m
        if (Test-Path -LiteralPath $dest) { continue }
        $src = $null
        foreach ($s in $sources) {
            $c = Join-Path $s $m
            if (Test-Path -LiteralPath $c) { $src = $c; break }   # first source wins = load order
        }
        if (-not $src) { $missing += $m; continue }
        try   { New-Item -ItemType HardLink -Path $dest -Target $src -ErrorAction Stop | Out-Null }
        catch { Copy-Item -LiteralPath $src $dest -Force }
    }
    if ($missing.Count -gt 0) {
        throw ("Masters not found: {0}. Checked: {1}. Set 'cleanedMastersDir' in {2}." -f `
               ($missing -join ', '), ($sources -join ' ; '), $cfgPath)
    }

    if (-not [string]::IsNullOrWhiteSpace($Plugin)) {
        Copy-Item -LiteralPath (Resolve-Path $Plugin) (Join-Path $Path (Split-Path $Plugin -Leaf)) -Force
    }
    return $Path
}
