# Ehlnofey — Workspace Guide

> **This file is the most valuable thing in the repo.** It is what a future session reads instead of
> re-deriving your conventions from scratch. When you learn something the hard way — a FormID
> allocation, a record shape that didn't work, a compile import you needed — write it here.
>
> Everything above *[The mod](#the-mod-ehlnofey)* is generic workspace mechanics. Everything below it
> is Ehlnofey: what we are building, what phase we are in, and where the research lives.

## What this is

**Ehlnofey** is a **deleveling overhaul for SkyrimSE** — it replaces vanilla's player-level scaling
with fixed, hand-set rules so that difficulty and reward belong to *places*, not to the player's
level. See [The mod](#the-mod-ehlnofey) for the design thesis and current phase.

The repo it lives in is a Spriggit YAML workspace: plugins are decompiled to YAML, edited as text,
and re-packed to `.esp`/`.esm`. **Never hand-edit binary plugins — edit the YAML.**

- Spriggit package/source: `Spriggit.Yaml.Skyrim`
- Spriggit CLI version: `0.40.0`
- CLI path + all tool paths: `.claude/config/tools.json` (gitignored; see Tooling config below).

## Tooling config (no hardcoded paths)

All tool paths and per-machine settings live in **`.claude/config/tools.json`** (gitignored;
template at `tools.example.json`). Skills load it via `.claude/config/tools.ps1`, which exposes
`$Tools` (e.g. `$Tools.spriggitCli`, `$Tools.papyrusCompiler`, `$Tools.creationKit`,
`$Tools.gameSourceScripts`) and an `Assert-Tool` guard. **Never reintroduce a hardcoded path into a
skill — change the config instead.**

- **Modlists:** a Wabbajack `.wabbajack` list installs a full MO2 instance (game copy + mods +
  tools, often the **Creation Kit** and Papyrus compiler) that can be hundreds of GB. It is
  gitignored (`/modlist/`, `/downloads/`). Run the **`modlist-install`** skill to install one and
  auto-discover its tool paths into `tools.json`.
- Without a modlist, fill `tools.json` by hand from `tools.example.json`.

## Workflow (round-trip)

```
.esp/.esm  ──serialize──►  YAML (committed)  ──deserialize──►  .esp/.esm
                 ▲                                                  │
                 └──────────── you edit the YAML ◄──────────────────┘
```

Serialize/deserialize commands: see `README.md`. After editing YAML, deserialize and load the plugin
in xEdit/CK to verify before shipping.

## Folder map

```
src/                       # EVERY mod lives here — one folder per mod, add as many as you like
  <ModName>/
    <ModName>ESP/          # Spriggit YAML — COMMITTED, source of truth
    Scripts/source/*.psc   # Papyrus source — COMMITTED
    Scripts/compiled/*.pex # COMMITTED via a .gitignore exception (CI can't compile Papyrus)
build/                     # build.ps1 + manifest.json + committed FOMOD trees
arch-docs/                 # world research + design spec + record-pattern guide (see arch-docs map)
reference/                 # gitignored — vanilla/third-party decompiles, LOOKUP ONLY
                           #   already holds Skyrim.esm, Update.esm and the 3 DLCs: Phase 1's evidence
modlist/                   # gitignored — an installed MO2 instance, hundreds of GB
```

`src/` is the only place mod content goes. A repo can hold several mods side by side — a main
plugin and its compatibility patches, say — each its own `src/<ModName>/` folder with its own
`build/manifest.json` release entry. Only `src/`, `build/`, `arch-docs/`, `.claude/` and the root
configs are committed.

## Guardrails — how to work in this repo

These are distilled from real failures in this workspace's lineage. They cost test cycles to learn.

1. **Ground-truth before claiming.** Do not conclude a patch is or isn't needed, or that a record
   does what its name suggests, from the name alone. Read the serialized record, trace the
   FormKeys, and **show the evidence alongside the verdict**. If a mechanic depends on a third-party
   mod's compiled script, read that script's decompiled source — data-driven parts extend to your
   records, hardcoded index checks do not.
2. **Prefer a proven archetype to an invented mechanism.** Read
   `arch-docs/skyrim-record-patterns.md` first. Skyrim fails silently: an inert record produces no
   error, so an invented mechanism costs a full build-deploy-launch-test cycle to disprove.
3. **Copy records verbatim; never retype hex.** When basing a record on an existing one, copy the
   file and edit the fields that differ. Hand-transcribing `Data:` blobs has produced odd-length hex
   that fails the build, and dropped array entries that fail silently. Prefer a script over
   retyping. Re-check array lengths after any edit.
4. **Ask for paths; don't hunt for them.** Install locations, modlist names, MO2 folders and mod
   names live in `tools.json` or in the user's head. Read the config or ask — filesystem-searching
   for them wastes time and lands on the wrong candidate.
5. **Verify the deploy target before blaming the records.** A mod in a wrongly-named MO2 folder is
   invisible; the game runs fine and the change simply isn't there. The `mod-deploy` skill checks
   this. Rule out "never loaded" before debugging "loaded but broken".
6. **A clean build is not a working mod.** Deserialize, xEdit and the Papyrus compiler all passing
   proves it *builds*. Only launching the game proves it *runs*. Say which of the two you have
   actually established.
7. **Recompile and re-commit `.pex` whenever a `.psc` changes.** CI cannot run the Creation Kit
   compiler. `build/build.ps1` fails on a *missing* `.pex` but cannot detect a *stale* one.
8. **PowerShell 5.1 is the target** for build scripts and skills: `Set-StrictMode` is on, there is
   no `&&`/`||`, no ternary, no null-coalescing, and no built-in YAML parser. Write `-Encoding utf8`
   explicitly when a file will be read by other tools.

## FormKey discipline

- New records use this plugin's name as the FormKey suffix: `<hex>:<YourMod>.esp`.
  Records that **override** a base/third-party record keep the original suffix
  (e.g. `09BC43:Skyrim.esm`) — that is how you tell at a glance which records you invented.
- **ESL (`Small`) plugins are constrained to FormIDs `0x800–0xFFF`.** Confirm with the user before
  exceeding; there is headroom but it is finite.
- Allocate a **contiguous block per feature** for readable diffs.
- ALWAYS grep the whole workspace (your plugin folders + `reference/`) for a hex FormID before
  assigning it — use the `formkey-check` skill.

## Papyrus toolchain

Scripts go through extract → decompile → edit → compile → package. Use the matching skills; the
`papyrus-script-engineer` subagent handles decompiled-source cleanup and compile-error fixing.

**Tool paths:** all resolved from `.claude/config/tools.json` — do not hardcode.

| Step | Tool | Config key |
|------|------|------------|
| Extract `.bsa`/`.ba2` | `bsab.exe` | `$Tools.bsab` |
| Decompile `.pex`→`.psc` | `Champollion.exe` | `$Tools.champollion` |
| Compile `.psc`→`.pex` | `PapyrusCompiler.exe` | `$Tools.papyrusCompiler` |
| Open Creation Kit | `CreationKit.exe` | `$Tools.creationKit` |

**Compiler imports:** base-game source = `$Tools.gameSourceScripts` (extract
`<gameDataDir>/Scripts.zip` once, or use what the modlist ships). Flags file: `$Tools.papyrusFlags`.

**Per-project import dirs** — persist in `tools.json`'s `importDirs` array (the `papyrus-compile`
skill appends them to `-i`). Record each one here as you discover it:

| API / framework | Source `.psc` dir |
|-----------------|-------------------|
| _(base only)_ | Nothing in Ehlnofey compiles against anything but base-game source yet. Add SKSE/SkyUI/MCM/PapyrusUtil dirs here the first time a script needs them. |

**Testing:** MO2 modlists under `$Tools.modlistsRoot`, or a Wabbajack instance at
`$Tools.modlistRoot`. Use the `mod-deploy` skill rather than copying by hand.

## Workspace gotchas

- **FOMOD images that actually render in MO2** — a config can build clean, pass
  `build.ps1 -CheckFomod`, open its wizard normally, and still show *no image at all*. Nothing
  warns you. This recipe is confirmed working in MO2 (the template's `build/staging/Example Mod/fomod/`,
  which is still in the repo); copy its shape rather than re-deriving:
  1. `path=` is relative to the **archive root**, so an image at `fomod/images/foo.jpg` is
     referenced as `path="fomod\images\foo.jpg"` — *including* the `fomod` prefix.
  2. Use **backslashes** in `path=`, as the shipped configs do.
  3. Declare an `<installSteps>` block, even for a mod with no real choices (one
     `SelectExactlyOne` group holding a single `Recommended` plugin). A config with only
     `<requiredInstallFiles>` gives MO2 no wizard page to draw the banner on.
  4. Use a **baseline** JPEG or a PNG, not a progressive JPEG. Check with
     `od -A d -t x1 -v img.jpg | grep -oE 'ff c[0-9a-f]'`: `ff c0` is baseline (fine), `ff c2` is
     progressive. Re-encode progressive files via `System.Drawing` before shipping.

  These four were fixed **together** after several one-at-a-time attempts each failed, so which is
  individually decisive is unverified — treat the set as the known-good recipe, and do not drop one
  on the assumption it does not matter.

  `build/build.ps1 -CheckFomod` now enforces points 1, 2 and 4: an unresolvable `path=` or a
  progressive JPEG **fails** the check (with a "did you mean `fomod\…`?" hint for the missing
  prefix), and forward slashes warn. It cannot check point 3 — whether an `<installSteps>` block
  exists at all — because a config legitimately may not want one.
- **Decompiled `.psc` is a reconstruction** (Champollion): auto-named vars, reconstructed control
  flow, lost comments/flags. Always recompile and test in-game; a clean compile is not proof.
- **Missing-type compile errors** → the referenced API's source isn't on the import path; add its
  `Source\Scripts` dir to `importDirs` in `tools.json` and record it in the imports table above.
- **YAML comments do not survive a re-serialize.** Spriggit rewrites the folder from the binary
  plugin, so any `#` comment you add to a record file is lost the next time anyone runs
  `/spriggit-serialize`. Put durable explanation in this file, not in the record YAML.
- Edit `.psc`/YAML, never the binary `.pex`/`.esp`. Commit source, not build artifacts.
- See `arch-docs/skyrim-record-patterns.md` for the in-game failure modes that produce no build
  error — that list is the single highest-value read before authoring a new mechanic.

---

# The mod: Ehlnofey

## The idea, and the name

**Ehlnofey delevels Skyrim.** Vanilla scales the world to the player: bandits, draugr and loot are
generated relative to your level, so a dungeon cleared at level 5 is the same fight at level 40 and
the map has no topography of danger. Ehlnofey replaces that with **fixed, hand-set rules** — every
enemy, dungeon and hoard has a level and a loot profile that does not move — aiming at an
*immersive, lore-friendly and gameplay-optimised* result rather than a difficulty-slider mod.

The name is the thesis. The Ehlnofey were et'Ada who stopped wandering: instead of remaining free,
mutable spirits, they bound themselves into the substance of Nirn and became its fixed laws — the
Earth Bones, the unchanging structure under everything. That is exactly the operation this mod
performs on Skyrim: it takes a world that bends to the player and re-imprints static, indifferent
rules onto it. Docs and record names lean on that vocabulary (**bones** = the fixed structure).

## The three bones (design rules)

Every design decision has to answer to these. If a proposal violates one, it needs an explicit
exception recorded in `arch-docs/design/`, not a quiet pass.

1. **The world does not scale.** Difficulty and reward are properties of a place and a creature, set
   once. Nothing recalculates against the player's level.
2. **Danger is legible.** If the player can be killed by walking somewhere, the world must have told
   them first — geography, lore, faction, visual tier, NPC dialogue, quest gating. A fixed world is
   only fair if it can be read.
   > **This is the load-bearing bone.** `progression.md` found that vanilla gates content by level
   > essentially nowhere (30 conditions across 1,811 quests, none on any questline) and that 20 gold
   > buys a carriage ride to any hold capital from minute one. Legibility is not a nice-to-have — it
   > is the *only* protection a player has once the world stops scaling.
   > **The mechanism already exists: tier display names.** Draugr → Restless Draugr → Wight → Scourge
   > → Deathlord; Dremora Churl → Caitiff → Kynval → Kynreeve → Markynaz → Valkynaz. These are
   > lore-ordered, player-facing, and map 1:1 onto the level ladders. Keeping name aligned with power
   > is a hard constraint — see `lore-constraints.md`.
3. **Reward follows place, not level.** Good loot exists because of *where* it is (a Nordic tomb, a
   Dwemer ruin, a dragon's hoard, a named boss), never because the player happened to be level 40.

**Non-goals** (keep scope honest): not a combat overhaul, not a perk/skill overhaul, not a survival
mod, not a new-content mod. Ehlnofey changes *where the numbers come from*, and nothing else.

## Current phase

**Phase 1 — world research.** No Ehlnofey records exist yet. `src/` still holds the template's
`ExampleMod`, kept only as a worked pipeline example; it is not part of the mod and will be deleted
before first release. `reference/` already holds Spriggit decompiles of `Skyrim.esm`, `Update.esm`
and all three DLCs — that is the primary evidence source for Phase 1.

## Phase plan

| Phase | Output | Done when |
|---|---|---|
| **0 — Workspace** | Spriggit round-trip, skills, CI, base+DLC decompiles in `reference/` | ✅ complete |
| **1 — World research** | `arch-docs/world/*` — enemy taxonomy, factions, dungeons, regions, progression, lore constraints, DLC deltas | Every hostile archetype and every dungeon is in a table with its vanilla scaling behaviour cited from `reference/` |
| **2 — Prior art & method** | `arch-docs/prior-art/*` — how Requiem, MorrowLoot Ultimate, Open World Loot, SkyPatcher/SPID-driven delevelers and Synthesis patchers actually do it | Each approach has a verified mechanism, a cost, and a compatibility verdict |
| **3 — Design spec** | `arch-docs/design/*` — tier system, region difficulty map, loot model, and the **implementation-strategy decision** | A record-level spec exists that someone else could implement without re-deciding anything |
| **4 — Build** | `src/Ehlnofey/` — plugin YAML, any scripts/rule files, FOMOD, release | Deserializes clean, passes `xedit-audit`, **and has been launched in-game** |

Phases 1–3 are documentation work. **Do not start authoring records in `src/` before Phase 3 has a
written spec** — the whole point of the arch-docs is that a deleveling pass touches thousands of
records and reversing a bad taxonomy afterwards is far more expensive than deciding it on paper.

## arch-docs map

Research and design live here; this file stays the index. Create these as the phases produce them.

```
arch-docs/
  skyrim-record-patterns.md      # EXISTS — read before authoring any mechanic
  build-report.md                # EXISTS — CI-generated, do not hand-edit
  world/
    overview.md                  # EXISTS — bird's-eye census of the base game; read this first
    enemy-taxonomy.md            # EXISTS — every hostile archetype, its ladder, its scaling class
    unique-enemies.md            # EXISTS — named bosses + unique enemy races, base game + DLC
    factions.md                  # EXISTS — combat factions, membership counts, relation graph, filter viability
    dungeons.md                  # EXISTS — all 226 dungeons by hold: type, zone, level, boss, word wall
    regions.md                   # EXISTS — the nine holds: map position, composition, the real gradient
    progression.md               # EXISTS — routes, level gates (almost none), the carriage problem
    lore-constraints.md          # EXISTS — what the fiction permits; tier names ARE the lore hierarchy
    dlc-deltas.md                # Dawnguard / Hearthfire / Dragonborn additions and their zones
                                 #   (DLC coverage currently lives inline: taxonomy §2.7, dungeons §3,
                                 #    factions §6, regions §4 — consolidate here if it outgrows them)
  prior-art/
    requiem.md  morrowloot.md  open-world-loot.md  skypatcher-spid.md  synthesis-patchers.md
  design/
    tiers.md                     # the fixed tier ladder and what each tier means numerically
    difficulty-map.md            # region/dungeon → tier assignment
    loot-model.md                # rarity by place; what leaves the leveled lists
    implementation-strategy.md   # THE gating decision — see below
```

## Research rules (Phases 1–3)

The repo's guardrails apply with extra force here, because deleveling research is exactly where
plausible-sounding claims are cheapest to make and most expensive to act on:

- **Cite `reference/`, not memory.** A claim like "bandits use a level multiplier" must name the
  record and the field as serialized: `reference/Base/01Skyrim/…`. Grep the decompile; quote it.
- **Mark confidence** the same way `skyrim-record-patterns.md` does: `[verified]` = read in
  `reference/` or observed in-game here; `[community]` = established modding knowledge, not re-tested;
  `[unverified]` = plausible, needs checking. Never silently upgrade a mark.
- **Prior art gets read, not recalled.** Before writing that a mod "does X", read its plugin (via
  `/spriggit-decompile-reference` into `reference/mods/`), its INIs, or its documentation. Third-party
  behaviour that lives in a compiled script or SKSE DLL is not knowable from the record data alone.
- **Follow the template chain before concluding.** A leveled spawn's stats can come from an actor
  template rather than the NPC record you are looking at, so "this NPC is level 6" is a claim about
  whichever record actually owns the level. Trace it.

## The vanilla scaling machinery

The levers a deleveling mod has to touch. Field names below are concepts — **confirm the exact
Mutagen/Spriggit field name in `reference/` before writing YAML**, and record the confirmed name here.

| Mechanism | Record type | Why it matters to Ehlnofey |
|---|---|---|
| Static vs. player-relative level | `NPC_` (level is either a fixed number or a PC-level multiplier with calc-min/calc-max) | The core lever. "Delevel an NPC" mostly means replacing the multiplier with a fixed level. `[community]` |
| Actor templates | `NPC_` template + template flags | A spawn may inherit stats/traits from another record, so editing the visible NPC can do nothing. Trace before editing. `[community]` |
| Leveled actor lists | `LVLN` | Chooses which variant spawns, with per-entry level gates and chance-none. Deleveling means flattening or splitting these per tier. `[community]` |
| Leveled item lists | `LVLI` | The loot side of the same machinery — vanilla gates gear tiers by player level here. `[community]` |
| Encounter zones | `ECZN` | Per-location min/max level and flags. **Probably the single most important record type for this mod**: a fixed per-dungeon level is literally the "fixed law" the design asks for. `[community]` |
| Placed-actor difficulty | `ACHR` / `PlacedNpc` field `LevelModifier` (`Easy`/`Medium`/`Hard`/`VeryHard`) | Vanilla's hand-tuning layer, on **5,685 of 10,504** placed actors (2,524 of 4,452 interior); the four values map to `fLeveledActorMult*` = 0.33/0.67/1/1.25. Keep it. `[verified]` |
| Global knobs | `GMST` (level-scaling and difficulty multipliers) | Blunt but cheap; changes everything at once. Use deliberately, never as a substitute for tiering. `[community]` |
| Spawn gating by player level | 12 `LevelGate*` `GLOB` records (Spriggan 8 … Giant 24) | Vanilla's only systematic level gate — it withholds world-encounter *creatures* until the player is roughly their level. **This is a bone-1 violation that already exists**; delete or document as an exception. `[verified]` |
| Capability, not level | `PERK`, `SPEL`, `CSTY` (combat style) | A level-20 bandit's threat comes largely from perks/spells/AI. Deleveling levels without capability produces a flat, boring world. `[community]` |

## Implementation strategy — the open decision

This gates Phase 4 and belongs in `arch-docs/design/implementation-strategy.md`. Three candidates:

| Approach | Mechanism | Cost |
|---|---|---|
| **A. Plugin overrides** | Override vanilla records directly in Spriggit YAML | Total control, no dependencies. But thousands of override files: a huge repo, unreviewable diffs, and a hard conflict with every other mod touching the same records. |
| **B. Runtime rule engines** | SkyPatcher INI rules and/or SPID distribution, applied at load by SKSE | Few or no overrides, filter-based, very compatibility-friendly. Limited to what those engines expose — **their exact capabilities are `[unverified]` and are a Phase 2 deliverable** — and requires SKSE. |
| **C. Generated patch** | A Synthesis/Mutagen patcher that computes the overrides on the user's install | Rules live in code, same ecosystem as Spriggit, adapts to the user's load order. Requires users to run Synthesis. |

**Working recommendation (not yet a decision):** a hybrid — a small hand-authored `Ehlnofey.esp` for
the fixed skeleton that must be a record (encounter zones, new leveled lists, keywords, any config
quest) plus rule files for the broad per-NPC/per-item distribution. That keeps the committed YAML
small enough to review, which matters because option A's diff volume is the thing most likely to make
this project unmaintainable. Decide it in Phase 2 with evidence, then record the verdict here.

## Naming & FormKey conventions

Fixed now so Phase 4 does not have to argue about it:

- **Plugin:** `Ehlnofey.esp`. Masters: `Skyrim.esm` + `Update.esm`, plus whichever DLC masters the
  final scope requires (adding a DLC master makes it a hard requirement — decide per phase, in the
  design docs, not mid-edit).
- **EditorID prefix:** `EHL_`, then the domain, then the specific: `EHL_LVLI_DraugrBossHoard_T4`,
  `EHL_ECZN_BleakFalls`. Tier suffixes are `_T<n>` against the ladder in `design/tiers.md`.
- **New records** start at `0x800` and are allocated in a **contiguous block per feature** (one block
  for encounter zones, one for leveled lists, …). Record each block here as it is claimed.
- **Overrides keep the original master's suffix** (`09BC43:Skyrim.esm`), which is how you tell an
  invented record from a vanilla one at a glance. Ehlnofey will be override-heavy, so this matters
  more here than in a content mod.
- **ESL decision: open.** Overrides do not consume new FormIDs, so an ESL-flagged plugin stays viable
  as long as *new* records fit `0x800–0xFFF`. Confirm before exceeding.
- Always `/formkey-check` before claiming a block.

**FormID usage:** none yet. **Next free: `0x800`.**

## Useful FormKey constants

Add the encounter-zone, faction and leveled-list FormKeys here as Phase 1 confirms them — that table
is the payoff of the research phase.

| FormKey | Meaning |
|---|---|
| `000014:Skyrim.esm` | PlayerRef |
| `000038:Skyrim.esm` | GameHour global |
| `000039:Skyrim.esm` | GameDaysPassed global |
| `00003C:Skyrim.esm` | Tamriel worldspace |
| `038AB1:Skyrim.esm` | BleakFallsBarrowZone (ECZN) — one of only 5 vanilla zones with a `MaxLevel` |
| `039CFC:Skyrim.esm` | LCharBanditMelee1H (LVLN) — the worked example of vanilla's scaling chain |
| `0130DB:Skyrim.esm` | LocTypeDungeon keyword (202 locations) |
| `0F5E80:Skyrim.esm` | LocTypeClearable keyword (199 locations) |
| `039CFC:Skyrim.esm` | LCharBanditMelee1H — canonical level-gated LVLN ladder |
| `0E7B2C:Skyrim.esm` | LCharGuardImperial — canonical `PcLevelMult` cluster (guards, ×1, [20–50]) |
| `08E4F1:Skyrim.esm` | AlduinBase — the only fully player-scaled boss (`PcLevelMult` ×1.2, [10–100]) |
| `016771:Skyrim.esm` | LocTypeHold keyword — **10** holds, not 9: Skyrim's nine + `DLC2SolstheimLocation` |
| `016E2A:Dragonborn.esm` | DLC2SolstheimLocation — a tenth `LocTypeHold` root (levels 6–40) |
| `016E2B:Dragonborn.esm` | DLC2ApocryphaLocation — root with **no keywords**; 7 Black Books, all level 25 |
| `000013:Skyrim.esm` | CreatureFaction — the creature/humanoid divide (660 NPCs) |

The full primary-source list is `arch-docs/world/enemy-taxonomy.md` §8 — cite from there rather than
re-deriving.

## Ehlnofey gotchas

Fill this as the project teaches you things.

- **Mutagen omits default-valued scalars in the YAML.** An absent field means *the default*, not
  "not configured". `EncBandit04TemplateMelee` (01E60D) serializes its level as
  `Level: {MutagenObjectType: NpcLevel}` with no `Level:` line — that is level **0**. Never read
  absence as "unset". `[verified]`
- **`TemplateFlags` decides which record owns a stat.** If an NPC lists `Stats` in `TemplateFlags`,
  its own `Level:` is inert and the template's value wins. Read the flags before believing a number
  on an NPC record. `[verified]`
- **Follow the template chain all the way to an `LVLN`, not just one hop.** A named boss like
  `JyrikGauldurson` templates onto `LvlDraugrAmbushWarlock`, which templates onto `LvlDraugrWarlockMale`,
  which templates onto the **leveled list** `LCharDraugrWarlockMale`. Stopping at the first NPC hop
  reports `L=1` and is wrong — 21 of Skyrim's named bosses have no fixed level at all. A resolver must
  treat "template is a `LeveledNpcs` record" as a distinct terminal case. `[verified]`
- **NPC level is a discriminated union at `Configuration.Level`**, tagged by `MutagenObjectType`:
  `NpcLevel` (field `Level:`) or `PcLevelMult` (field `LevelMult:`, with `CalcMinLevel` /
  `CalcMaxLevel` as siblings on `Configuration`). Those are the confirmed Spriggit names. `[verified]`
- **`grep -rl` across `reference/` times out (>2 min).** Match on *filenames* instead: Spriggit names
  every file `<EditorID> - <FormID>_<master>.yaml`, so `ls Npcs | grep 039D26` resolves a FormKey
  instantly. For anything bigger, build a `FormID → EditorID → type` index from filenames once and
  join against it. `[verified]`
- **Never compare a hex FormID numerically in `awk`.** `awk -v i="02E893" '$1==i'` matches *eight*
  rows, because a `-v` value is a strnum: `02E893` parses as `2×10^893` → `+inf`, and every
  similarly-shaped FormID (`02E894`, `04E852`, …) is also `+inf`. Truncation is just as bad —
  `0130DB` numifies to `130`, colliding with the whole `0130xx` keyword block. Force string context
  with `$1""==i""`, or use FormIDs only as **array subscripts** (always strings). `[verified]`
- **Never census a field with `grep -c` — count records, not lines.** `grep -c 'LevelModifier:'` over
  `Cells/` returns 2,739 where the true `PlacedNpc` count is 2,524, because 215 `PlacedObject`
  *markers* (`PatrolIdleMarker`, `XMarker`, `GuardMarker`, …) carry the field inertly. Fields recur
  across record types; always parse to the record and filter by `MutagenObjectType`. `[verified]`
- **EditorIDs are not a reliable search key for a named set.** Only four of Skyrim's eight named
  Dragon Priests have "Priest" in their EditorID, and Vokun's is `Ianusu`. When enumerating a named
  group, match on the English `Name:` string; use EditorIDs only once you have the FormKeys.
  `[verified]`
- **DLC plugins have no display names in the decompile.** `Dawnguard.esm` and `Dragonborn.esm`
  records serialize as `Name:` / `TargetLanguage: English` with **no `Values:` block** — the strings
  live in external `.STRINGS` files that Spriggit did not inline. `Skyrim.esm` names *do* come
  through. So the "match on `Name:`" rule above works only for the base game; for DLC you must
  identify records by EditorID and FormKey. `[verified]`
- **Resolve FormKeys by master, not by bare FormID.** A six-hex FormID is only unique *within* a
  plugin: `01A345:Dawnguard.esm` (Harkon's combat style) collides with an unrelated `Skyrim.esm`
  leveled-NPC record. A lookup that searches the base-game index first will silently return the wrong
  record with a plausible name. Always key on `<hex>:<master>`. `[verified]`
- **Never cache a derived index behind an `if [ ! -f ]` guard.** A stale `index_<dlc>.tsv` built by an
  earlier script with a shorter record-type list silently returned empty for `Classes` and
  `CombatStyles`, which reads identically to "this record has no class". Rebuild derived indexes, or
  version them by the list they were built from. `[verified]`
- **Placed records nest at different indentations.** In `Cells/` a placed ref opens at column 0
  (`- MutagenObjectType: PlacedNpc`); in `Worldspaces/` it is indented two more spaces, and the block
  itself contains inner `- MutagenObjectType: ScriptObjectProperty` entries. A parser anchored on
  column 0, or one that treats any nested `MutagenObjectType` as a record boundary, **silently drops
  records** — that mistake undercounted placed NPCs by half (5,169 vs the true 10,504). Track the
  opening line's indent and close the record only at the same or lesser indent. `[verified]`

Candidates still to confirm:

- **Do not assume the DLC follow the base game's structure.** Three traps, all `[verified]`:
  **(a)** Solstheim is a **tenth `LocTypeHold`** — a hold-keyed rule written against `Skyrim.esm`
  silently excludes it. **(b)** **9 of Dawnguard's 19 encounter zones have no `Location:` field**
  (vs 270 of 280 in vanilla), so anything walking `ECZN.Location → LCTN → keywords` misses the Soul
  Cairn, Darkfall, Castle Volkihar and most of the Forgotten Vale. **(c)** Dawnguard's new-world
  locations and *all* of Apocrypha carry **no keywords at all** — invisible to both hold-keyed and
  type-keyed rules. Always test a rule against the DLC separately, never by extrapolation.
- **Hearthfire adds no worldspace, no region and no dungeon** — 22 locations and 141 factions of
  homestead bookkeeping. It is out of scope for world design; adding it as a master buys nothing.
  `[verified]`
- **Override volume vs. Spriggit.** A deleveling pass can generate thousands of override YAML files.
  Watch repo size, round-trip time and `Test-RecordYaml.ps1` runtime before committing to option A.
- **Deleveling levels without deleveling capability** produces a world that is fixed and dull.
  Threat is perks, spells and combat style as much as level.
- **A clean build proves nothing about balance.** Phase 4 is not done at "deserializes clean" — it is
  done when a character has actually walked into a zone and been correctly killed by it.
