# Implementation strategy — the decision

**Phase 3, document 5.** How Ehlnofey is actually built. This is the decision CLAUDE.md has carried as
open since Phase 0, and it gates Phase 4.

Read `tiers.md`, `difficulty-map.md` and `loot-model.md` first — this document costs out what they
specify and does not re-argue any of it.

---

## 1. The verdict

**A hybrid, split by *what kind of thing* is being edited rather than by convenience:**

> **Places and constants go in the plugin. Actors go in rules.**
>
> `Ehlnofey.esp` — **~376 override records**: the 355 encounter-zone bands, 3 game settings, 12
> globals, 5 capstone bosses and 1 vanilla bug fix. No new records, therefore **no FormIDs
> consumed**, therefore ESL-flaggable.
>
> **SkyPatcher INI rules** — the ~454 `PcLevelMult` actors and the ambient leveled lists: work that is
> filter-shaped, open-ended, and expensive to express as overrides.

This is a **revision of the working recommendation** in CLAUDE.md, which had rules doing "the broad
per-NPC/per-list/per-zone distribution" with the plugin reduced to "the handful of things rules cannot
reach". Phase 3 moved the zone work across the line, and §3 explains why.

Option A (plugin overrides for everything) and option B (rules for everything) are both rejected, in
§4 and §5.

---

## 2. The plugin — every record, enumerated

`Ehlnofey.esp`. Masters: `Skyrim.esm`, `Update.esm`, `Dawnguard.esm`, `Dragonborn.esm`
(`difficulty-map.md` scope decision). **ESL-flagged** — see §2.5.

### 2.1 Encounter zones — 355 records

The whole of `difficulty-map.md` §7. Two fields per record:

```yaml
MinLevel: 21
MaxLevel: 21
```

Preserve `Flags` exactly — 91 carry `NeverResets`, one `DisableCombatBoundary`. Clear
`MatchPcBelowMinimumLevel` on `WinterholdCollegeMiddenZone` (`10D415`), the only vanilla zone that
sets it (`engine-behaviour.md` §2).

### 2.2 Game settings — 3 records

Overrides of existing records; SkyPatcher has **no GMST module** (`skypatcher.md` §5.1), so these can
only be a plugin.

| GMST | FormKey | Vanilla | Ehlnofey | Source |
|---|---|---|---|---|
| `fLeveledActorMultEasy` | `01A1D9:Skyrim.esm` | 0.33 | **0.70** | `tiers.md` §4 |
| `fLeveledActorMultMedium` | `01A1DB:Skyrim.esm` | 0.67 | **0.85** | `tiers.md` §4 |
| `fSpecialLootMinPCLevelMult` | `10FEDE:Skyrim.esm` | 0.6 | **0** | `loot-model.md` §4 |

`fLeveledActorMultHard` and `…VeryHard` keep their vanilla 1.0 / 1.25 and therefore need **no record**
— the deliberate consequence of `tiers.md` §4's decision to hold Hard at 1.0.

### 2.3 Globals — 12 records

The `LevelGate*` set, each set to **1** (`tiers.md` §8). Also plugin-only: SkyPatcher has no `global`
module — the 28 supported types (`skypatcher.md` §2) do not include it.

`LevelGateSpriggan` · `IceWraith` · `Bear` · `TrollCave` · `Wisp` · `WispMother` · `BearCave` ·
`TrollFrost` · `BearSnow` · `Falmer` · `Hagraven` · `Giant`.

### 2.4 Named records — 6

| Record | FormKey | Change | Why |
|---|---|---|---|
| `AlduinBase` | `08E4F1:Skyrim.esm` | `PcLevelMult` ×1.2 [10–100] → **fixed 60** | `tiers.md` §8 |
| `DLC1Harkon` | `003BA7:Dawnguard.esm` | ×1.2 [10–60] → **fixed 55** | must clear his own court (48/53) |
| `DLC1HarkonCombat` | `01A93D:Dawnguard.esm` | ×1.4 [10–60] → **fixed 60** | separate record; **both** or the transformation is a downgrade |
| `DLC2Miraak` | `017F7D:Dragonborn.esm` | ×1 [35–**200**] → **fixed 65** | highest `CalcMaxLevel` in the game |
| `DLC2MiraakMQ06` | `01FB98:Dragonborn.esm` | ×1.1 [35–150] → **fixed 65** | the final-fight record |
| `EncBandit04TemplateMelee` | `01E60D:Skyrim.esm` | level **0 → 14** | the vanilla bug, `tiers.md` §10 |

These six *could* be rules (`skypatcher.md` §4.1 does NPC levels natively). They are in the plugin
because they are a fixed, named, six-item list where an override is more legible than a filter, and
because putting them here means they are covered by `xedit-audit` and the Spriggit round-trip.

### 2.5 FormID budget — zero

**Every record above is an override.** Overrides keep the original master's FormKey suffix and consume
no new FormIDs. So:

- **CLAUDE.md's "FormID usage: none. Next free `0x800`" remains true after Phase 4.** No block needs
  claiming and `/formkey-check` has nothing to audit.
- **ESL-flagging is viable**, because the `0x800–0xFFF` constraint binds only new records. `Ehlnofey.esp`
  can be ESPFE and cost no load-order slot. This resolves CLAUDE.md's open "ESL decision".

If a later phase adds new records — most likely region-scoped leveled lists for the overworld problem
(§6) — the ESL decision reopens and a block gets claimed then, not now.

---

## 3. Why the zones moved into the plugin

CLAUDE.md assumed the zone work belonged in rules because option A's *ceiling* is frightening: Requiem
is 108 MB / 26,620 records, MLU 22 MB / 4,751. But that ceiling is set by **NPC and leveled-list**
overrides, not by zones. `morrowloot.md` §8.3 measured the zone slice directly:

> *"360 `ECZN` records is ~1 MB of YAML — a hand-authorable, reviewable, diffable core."*

355 two-field records is a **small** plugin, and once that is true the balance inverts:

| | Zones as plugin overrides | Zones as SkyPatcher rules |
|---|---|---|
| Authoring cost | 355 YAML records | 355 enumerated INI lines — **the same**, because `encounterzone/` has no keyword or location filter (`skypatcher.md` §5.3) |
| Verification | `xedit-audit`, `formkey-check`, Spriggit round-trip, `Test-RecordYaml.ps1` — **all apply** | **none apply.** A typo'd FormID fails silently |
| Conflicts | record-level; last plugin wins | none |
| Dependency | none | **SKSE**, version-bound |
| Uninstall | zone keeps its stored level until reset | same (engine property, `engine-behaviour.md` §5.2) |

The authoring cost is a wash — **SkyPatcher would have to enumerate the same 355 zones by FormID
anyway**, because the chain `LCTN keyword → ECZN level` is broken at both ends. So the rules route
buys conflict-freedom and pays with the entire verification toolchain.

**Guardrail 6 decides it.** *"A clean build is not a working mod"* is a warning that building proves
less than running — but under option B for the zones there is **no build to be clean at all**
(`skypatcher.md` §5.5). For the mod's *spine* — the one artefact that, if wrong, makes everything
wrong — giving up xEdit, Spriggit diffs and FormKey auditing in exchange for conflict-freedom with a
small number of other encounter-zone mods is a bad trade.

---

## 4. Why not option A (everything in the plugin)

The ~454 `PcLevelMult` actors are the reason.

| | Overrides | Rules |
|---|---|---|
| Guards, soldiers, hunters, Nightingales, `WE*` | ~454 `NPC_` records, the largest record type in the game | **~6 lines** |
| Catches NPCs from *other* mods | no | **yes** — `filterByPCLevelMult=true` is a predicate over whatever is loaded |
| Catches NPCs from future DLC/patches | no | **yes** |
| Follower exception | manual | `filterByFactionsExcluded` |

`skypatcher.md` §4.1 gives the primitive, and it needs **both** halves or it fails badly:

```ini
; class D -> fixed. setPcLevelMult=false alone leaves them at level 1000; level= alone leaves the flag set.
filterByPCLevelMult=true:filterByEditorIdContainsOr=Guard:setPcLevelMult=false=21:level=21
```

An enumeration of 454 records is a *snapshot*; a filter is a *rule*. For a category defined by "uses
player scaling", the rule is the correct expression of the intent, and it is the single place where
option B is clearly better rather than merely cheaper.

The same argument covers the ambient leveled lists (`difficulty-map.md` §4.1 option b):
`clear` + `addToLLs` + `calcLevelAndEachItem` expresses a flattening in one line per list.

---

## 5. Why not option B (everything in rules)

1. **GMSTs and globals are unreachable** — 15 of the 376 plugin records simply have no rule form
   (`skypatcher.md` §5.1; no `global` module at all). A plugin is required regardless, so the question
   was only ever *how big*, never *whether*.
2. **`LevelModifier` is unreachable** — the string does not appear anywhere in SkyPatcher's source
   (`skypatcher.md` §5.2). Ehlnofey does not need to *edit* it, but if `tiers.md` §4's `None` test goes
   the wrong way, **only a plugin can do it** (§7). Note this argument carries far less weight than it
   was originally given: the exposure is **9 records, not ~1,928** (§7.1).
3. **Verification** — §3.
4. **SKSE dependency on the core.** Under the chosen split, SKSE is required for the *actor* half; if
   SkyPatcher breaks on a game update, the world still has its fixed places and its GMSTs. Under
   option B a broken DLL means the mod does nothing at all. **Graceful degradation is a real benefit
   of the split** and it was not part of the original argument.

---

## 6. The unsolved problem, stated honestly

**The overworld cannot be tiered by this architecture**, and Phase 3 did not solve it
(`tiers.md` §8, `difficulty-map.md` §4.1–4.2).

Most wilderness has no encounter zone, so there is nothing to write a tier into, and the ambient
lists still gate on player level. The three options and what Phase 3 learned about each:

| Option | Verdict after costing |
|---|---|
| **(a)** author wilderness `ECZN` and attach them to exterior cells | **not tractable.** New zones are fine (plugin), but attaching them needs `cell/encounterZone=`, and cell rules have **no keyword, location or region filter** (`skypatcher.md` §4.4) — Skyrim's exterior cells would have to be enumerated in the thousands. |
| **(b)** flatten the ambient `LCharAnimal*` lists so they stop scaling | **tractable, and partial.** One rule per list. But with no way to bind a list to a region, it yields **one wilderness mix for the whole province** — bone 1 satisfied, bone 2's regional legibility not. |
| **(c)** accept a scaling overworld as a documented bone-1 exception | honest, but it is the largest exception in the mod. |

**Decision: ship (b) in Phase 4, and say so in the mod description.** The mitigating fact is real —
`enemy-taxonomy.md` §2.3 shows the ambient ladders already cap out (forest predators at a level-16
cave bear, mountain predators at a level-22 frost troll), so **Skyrim's wilderness is already
effectively deleveled above ~level 20**; flattening it makes that true from level 1 instead.
Regional wilderness variation is deferred, needs new records, and reopens the ESL decision (§2.5).

The **8 unzoned dragon lairs** (`difficulty-map.md` §4.2) get the same treatment: fix
`LCharDragonAny` selection by rule rather than author twelve zones.

---

## 7. What could still change this

Three tests, all cheap, all in one dungeon visit, and **two of them can move work across the
plugin/rules line**. They should be run before Phase 4 authoring starts, not after.

| Test | Source | If it goes the wrong way |
|---|---|---|
| **`LevelModifier: None`** — do unmodified placed refs honour the zone, or the player's level? | `tiers.md` §4, `engine-behaviour.md` §7, **`probe-test-protocol.md` §4** | **9** interior `PlacedNpc` refs need an explicit modifier. **Plugin-only** (§5.2), but 9 records is noise against 376. **Downgraded** — see the census below. |
| **NPC gear resolution** — NPC's level or player's level? | `loot-model.md` §3 | up to 1,378 `LVLI` need truncation. Rules can do it (`removeFromLLs`), so it lands in the rules half — but it stops being a handful of lines. |
| **`fSpecialLootMinPCLevelMult` = 0** — zone-locks special loot, or disables it? | `loot-model.md` §4 | revert to 0.6 and document the exception; the plugin loses one record. |

Everything else `engine-behaviour.md` set out to answer is settled: clamp scope, the `PcLevelMult`
exemption, zero-width bands, `LevelModifier` composition, and SkyPatcher's `kDataLoaded` timing and
save behaviour.

### 7.1 Correction — the `LevelModifier: None` exposure is 9 records, not ~1,928

**This section previously sized the `None` test as "~1,928 interior `PlacedNpc` refs need an explicit
modifier… roughly *sextuples* the plugin… the single highest-value test in the project". That is
wrong, and the error is a sizing error, not an engine one.** The open question in §4 of
`engine-behaviour.md` stands exactly as posed; only its cost does not.

`LevelModifier` multiplies the **leveled-list lookup level** (`engine-behaviour.md` §4). It therefore
does nothing at all unless the placed ref's base resolves — through its template chain — to an
`LVLN`. A fixed-level `NPC_` has no lookup to modify, and a `PcLevelMult` actor ignores encounter
zones outright (`engine-behaviour.md` §1) and is already the rules half's job. The ~1,928 figure came
from counting *unmodified placed refs* without asking whether any of them had a leveled ladder
behind them.

Census over all **291 zoned interior cells** of `Skyrim.esm`, resolving every `PlacedNpc` base to a
terminal class. `[verified]` — `reference/Base/01Skyrim/Cells/`, method and full listing in
`probe-test-protocol.md` §4:

| Base resolves to | no `LevelModifier` | modifier set | total |
|---|---|---|---|
| **`LVLN`** — the only class the modifier affects | **9** | 2,138 | 2,147 |
| `NPC_` with a fixed level | 1,014 | 190 | 1,204 |
| `NPC_` with `PcLevelMult` | 83 | 45 | 128 |
| | **1,106** | 2,373 | **3,479** |

Vanilla is, in other words, **99.6% consistent**: of 2,147 placed refs backed by a leveled ladder in
a zoned interior, all but 9 carry a modifier. The 1,014 unmodified fixed-level refs are corpses,
skeletons, skeevers and quest NPCs — inert to this question either way.

All nine, should the test go the wrong way: `Ustengrav01` `02137C` `02137D` `02137E` `0213C6` (four
bandits), `WolfSkullCave02` `09DA1F`–`09DA22` (`MS06NecromancerCultist1–4`), `SnaplegCave01`
`0694D1` (`LvlDeer`).

**Consequences for this document:**

1. **The test is downgraded from schedule-defining to routine.** Still run it — it is free, it is one
   `getlevel`, and it fixes the semantics for any ref Ehlnofey places itself — but §9 step 1 no longer
   gates on it in the way it was written to.
2. **§2's ~376-record estimate stands** in both branches. The worst case adds 9 placed-ref overrides
   (~385), not ~2,300.
3. **§5.2's argument is unchanged but its stakes shrink.** `LevelModifier` is still unreachable from
   SkyPatcher and still plugin-only; the slice that would move is simply 9 records, so it is no longer
   an argument of any weight against option B.
4. **The gear-resolution test (row 2) is now the largest live risk in the table** — up to 1,378 `LVLI`.
   It is the one to run first.

**Scope caveat:** `Skyrim.esm` interiors only. `Worldspaces/` and the DLC were not censused, and per
CLAUDE.md's DLC trap (b) they must be checked separately rather than extrapolated. The overworld is
in any case already the acknowledged unsolved problem of §6.

---

## 8. What Phase 4 has to build that this workspace does not have

`skypatcher.md` §6 is blunt about the cost and it is the one genuinely new engineering task:

> *"The workspace's whole verification toolchain does not apply. Rules are unverifiable except
> in-game. Ehlnofey would need a new kind of check."*

**Deliverable: a SkyPatcher rule linter**, run in CI alongside `build.ps1`. Minimum viable scope,
taken from the two failure modes `skypatcher.md` actually documents:

1. **Resolve every `Plugin.esp|FormID` in every INI against `reference/`** — a typo'd FormID logs
   `logger::critical` and is otherwise silent.
2. **Validate every key name against the parser's regexes**, not against the author's articles. §3.4
   of `skypatcher.md` found *two* documented keys that do not work as written
   (`calcForLevelAndEachItem`, and `minLevelMult`'s `stoi` truncation), both failing silently.
3. **Warn on `filterBy*` stacking**, which *widens* the match (union) where `restrictTo*` narrows it
   (intersection) — the mistake that silently patches more NPCs than intended.
4. **Check `int8` bounds** on every `minLevel`/`maxLevel` — out-of-range values are rejected and
   ignored.

Note (1) needs `reference/`, which is gitignored, so it cannot run in CI as-is; the practical form is
a committed FormID→EditorID index built once from `reference/` and validated against in CI. That index
is worth having anyway — CLAUDE.md's gotchas already recommend it.

**Also required:** ship the rules under a mod-specific subfolder —
`SKSE/Plugins/SkyPatcher/npc/Ehlnofey/…`, never `SkyPatcher/npc/Skyrim.esm.ini`, which collides with
every other mod in the mod manager (`skypatcher.md` §3.3). And use the plugin-conditional filename
mechanism for DLC rules (`Ehlnofey_Dawnguard.esm.ini` loads only if Dawnguard is present) — free
compatibility, no scripting.

---

## 9. Phase 4 order of work

1. **Run the three tests** (§7), using `EhlnofeyProbe.esp` — the instrument and the script are in
   `probe-test-protocol.md`. Do not author against an assumption. **Run the gear-resolution test
   first**: since §7.1 it is the only one of the three that can still move a large amount of work
   (up to 1,378 `LVLI`).
2. **Delete `src/ExampleMod/`.** CLAUDE.md marks it as a template artefact to remove before first
   release.
3. **Scaffold `Ehlnofey.esp`** via the `mod-new-plugin` skill — header, masters, `build/manifest.json`
   entry, FOMOD stub.
4. **The 15 constants first** (§2.2, §2.3). Smallest possible slice that is verifiable end-to-end:
   deserialize → `xedit-audit` → `package-mod` → `mod-deploy` → launch. Proves the pipeline before
   355 records ride on it.
5. **The 355 zones** (§2.1), generated from `difficulty-map.md` rather than hand-typed — guardrail 3,
   *copy records verbatim, never retype hex*.
6. **The 6 named records** (§2.4).
7. **The rule linter** (§8), then the rules: `npc/` first (class D is where bone 1 actually lives),
   then `leveledList/` for the ambient flattening.
8. **Launch and walk into a zone.** Guardrail 6: a clean build proves it builds. Phase 4 is done when
   a character has walked into a T5 crypt and been correctly killed by it.

---

## 10. Summary of the decision

| Question | Verdict |
|---|---|
| Architecture | **Hybrid — places and constants in the plugin, actors in rules** |
| Plugin size | **~376 records**, all overrides, ~1–2 MB YAML |
| New records | **none** — FormID usage stays at zero, next free `0x800` |
| ESL | **viable and taken** (ESPFE), reopens only if new records are added |
| Masters | `Skyrim.esm`, `Update.esm`, `Dawnguard.esm`, `Dragonborn.esm` |
| Rules | SkyPatcher `npc/` + `leveledList/`, under `SkyPatcher/<type>/Ehlnofey/` |
| Hard dependency | **SKSE + SkyPatcher**, for the actor half only; the plugin half degrades gracefully |
| Bash tags | none needed by default — Ehlnofey edits no leveled item lists (`loot-model.md` §6) |
| Save games | **new game recommended** (`engine-behaviour.md` §5.2) |
| Synthesis | **ruled out**, per CLAUDE.md. Not revisited. |

---

## Sources

Design inputs: `design/tiers.md` · `design/difficulty-map.md` · `design/loot-model.md` ·
`design/engine-behaviour.md`. Prior art: `prior-art/skypatcher.md` §§2–5 (the capability and limit
tables, all `[verified]` from source) · `prior-art/morrowloot.md` §§0, 8 (the cost measurements) ·
`prior-art/requiem/` (option A's ceiling). Workspace constraints: `CLAUDE.md` guardrails 3 and 6,
FormKey discipline, and the skills inventory.
