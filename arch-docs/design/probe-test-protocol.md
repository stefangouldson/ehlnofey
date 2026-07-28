# Probe test protocol — the three gating in-game tests

`implementation-strategy.md` §9 step 1: *"Run the three tests. They can move a lot of work; do not
author against an assumption."* This document is the instrument and the script for that.

**The instrument is `src/EhlnofeyProbe/EhlnofeyProbeESP/` → `EhlnofeyProbe.esp`** — 4 records, all
overrides of `Skyrim.esm`, no new FormIDs, ESL-flagged. It is a **throwaway**: it is deliberately
not in `build/manifest.json`, and Phase 4 deletes it alongside `src/ExampleMod/`.

---

## 1. What the probe contains

| Record | FormKey | Vanilla | Probe | Why |
|---|---|---|---|---|
| `SwindlersDenZone` | `03EBE7:Skyrim.esm` | Min 6, no Max | **30 / 30** (T5) | Site A — low player, **high** zone |
| `UstengravZone` | `03EC83:Skyrim.esm` | Min 6, no Max, `NeverResets` | **4 / 4** (T1) | Site B — high player, **low** zone |
| `BleakFallsBarrowZone` | `038AB1:Skyrim.esm` | Min 6, Max 20 | **4 / 4** (T1) | Site C — loot A/B (this zone *does* reset) |
| `fSpecialLootMinPCLevelMult` | `10FEDE:Skyrim.esm` | 0.6 | **0** | Test 3 |

Levels are T1 and T5 from `tiers.md` (4 / 8 / 14 / 21 / 30 / 40 / 50).

**Deliberately *not* in the probe: the four `fLeveledActorMult*` GMSTs.** `tiers.md` §4 sets them to
0.70 / 0.85 / 1.00 / 1.25, but the probe leaves vanilla's **0.33 / 0.67 / 1.00 / 1.25** in place so
the tests measure *engine behaviour*, not Ehlnofey's tuning. Every predicted number below assumes
vanilla multipliers.

### Build it

```powershell
& $Tools.spriggitCli deserialize `
    --InputPath      "src/EhlnofeyProbe/EhlnofeyProbeESP" `
    --OutputPath     "dist/EhlnofeyProbe/EhlnofeyProbe.esp" `
    --PackageName    "Spriggit.Yaml.Skyrim" `
    --PackageVersion "0.40.0"
```

Then deploy with the `mod-deploy` skill, enable it **last** in the load order, and confirm it is
actually loaded before anything else (§2 step 0 — guardrail 5).

The YAML in `src/` **is** Spriggit's own canonical output, so a re-serialize round-trips on content.
Verify with `diff -r --strip-trailing-cr` — a plain `diff -r` reports every line changed, because
Spriggit writes CRLF and `.gitattributes` stores LF (see CLAUDE.md's gotchas).

---

## 2. The session

All three tests are one session, three `coc`s. Console commands are in `monospace`.

### Step 0 — prove the plugin is loaded (do not skip)

```
getgs fSpecialLootMinPCLevelMult
```

**Expect `0.00`.** If it returns `0.60`, the plugin is not loaded and *every* result below is a
vanilla reading that looks like a real answer. This is guardrail 5 in one line: rule out "never
loaded" before debugging "loaded but broken".

### Zone caching — why this needs a new game

`engine-behaviour.md` §0.3: a zone's level is computed on **first visit**, stored in the save, and
never recalculated until the zone resets. So:

- **Start a new game for each run.** From the main menu, `coc` skips character creation.
- **Ustengrav is `NeverResets`** — one save gets you exactly one Ustengrav reading, forever.
- Reach a *neutral* cell first, set the player level, and only then `coc` into the test dungeon.
  The zone attaches on that load, and it must attach at the level you intend.

---

## Test 1 — does `LevelModifier: None` honour the zone, or the player?

**Site: Ustengrav01. Player level 45, zone pinned to 4.**

```
coc WhiterunBanneredMare
player.setlevel 45
player.getlevel          ; confirm it took
coc Ustengrav01
```

Ustengrav01 is **the only cell in the base game with unmodified leveled humanoids** (§4). Four
bandits, no `LevelModifier`:

| Ref | `prid` | Base chain |
|---|---|---|
| `02137C` | `prid 0002137C` | `LvlBanditMelee2H` → `LCharBanditMelee2H` |
| `02137D` | `prid 0002137D` | `LvlBanditMeleeAny` → `LCharBanditMeleeAny` |
| `02137E` | `prid 0002137E` | `LvlBanditMissile` → `LCharBanditMissile` |
| `0213C6` | `prid 000213C6` | `LvlBanditMelee1H` → `LCharBanditMelee1H` |

Both bandit ladders are rungs at **L1 / L5 / L9 / L14 / L19 / L25**
(`LCharBanditMelee2H`, `LCharBanditMelee1H`), so the two outcomes are not subtle:

| If unmodified refs use… | Lookup level | Rung selected | You see |
|---|---|---|---|
| **the zone** (None ≙ Hard ×1.0) | 4 | **L1** | a plain *Bandit*, fur/hide, iron weapon, `getlevel` ≈ 1 |
| **the player** (docs read literally) | 45 | **L25** | a *Bandit Chief*-tier actor, high-tier gear, `getlevel` ≥ 25 |

```
prid 0002137C
getlevel
```

Compare against a modifier-tagged neighbour in the same cell, e.g. `0235FF` (Medium, draugr —
0.67 × 4 ≈ 2) or `023600` (Easy, draugr). If the bandits read ~25 while the draugr read ~1–2, the
documentation is literal and unmodified refs ignore the zone.

**Verdict to record:** `None` ≙ zone / `None` ≙ player.

> **But read §4 first.** This test was originally sized as *"the single highest-value test in the
> project"*, on the grounds that a bad result forces explicit modifiers onto ~1,928 interior refs and
> roughly sextuples the plugin. **That estimate does not survive a census** — the real exposure is
> **9 records**, and `implementation-strategy.md` §7.1 now carries the correction. Run the test
> anyway (it is free, and it settles the semantics for anything Ehlnofey places itself), but it is no
> longer the thing the schedule hangs on. **Test 2 is the one to run first.**

---

## Test 2 — what level does NPC gear resolve at?

**Site: Swindler's Den. Player level 5, zone pinned to 30.**

This is the *upward* direction, and it is the clean one: any gear better than a level-5 character
could otherwise meet must have come from the zone, not the player.

```
coc WhiterunBanneredMare
player.setlevel 5
coc SwindlersDen01
```

Swindler's Den holds **22 modifier-tagged leveled bandits** — the densest such cell in the game, and
the only one carrying all four modifier classes. Predicted lookup levels at zone 30 with vanilla
multipliers:

| Modifier | Lookup | Rung (ladder 1/5/9/14/19/25) | Example ref |
|---|---|---|---|
| Easy ×0.33 | 9 | **L9**, but Easy draws from *all* rungs ≤ 9, so L1/L5/L9 mixed | `042467` `LvlBanditMelee1H` |
| Medium ×0.67 | 20 | **L19**, uniform across all Medium refs | `04244C` `LvlBanditMeleeAny` |
| Hard ×1.00 | 30 | **L25** | `04246A` `LvlBanditMissile` |
| Very Hard ×1.25 | 37 | **L25** + the bump rule | `042469` `LvlBanditBoss` |

Kill the Hard ref (`prid 0004246A`) and read what it was wearing:

- **Gear matches a level-25 bandit** (banded iron / scaled / dwarven-ish tier) → outfit lists resolve
  at **the NPC's own level**. `loot-model.md`'s working assumption holds and **no truncation pass is
  needed** — ~0 lists to edit.
- **Gear matches a level-5 character** (fur, hide, iron) → outfit lists resolve at **the player's
  level**. All **1,378** gated `LVLI` become live bone-1 leaks and the rules half grows from a
  handful of lines to a real job (`removeFromLLs`).

`getlevel` on the same ref cross-checks that the actor itself came in at the zone level — if the
actor is level 5, the zone never applied and the gear reading is meaningless.

**Verdict to record:** gear ≙ NPC level / gear ≙ player level.

---

## Test 3 — does zeroing `fSpecialLootMinPCLevelMult` zone-lock special loot, or kill it?

**Site: Bleak Falls Barrow. Player level 45, zone pinned to 4.** Use this dungeon rather than
Ustengrav: it resets normally, so the A/B is repeatable.

The three settings (`loot-model.md` §4) make the boss-chest special-loot roll:

- zone floor `0.4 × zoneLevel` = 1.6, zone ceiling `1.0 × zoneLevel` = 4
- **PC floor `0.6 × playerLevel` = 27** ← the leak

`BleakFallsBarrow02` holds a `TreasDraugrChestBoss` (`020671:Skyrim.esm`), which reaches the 88
`SpecialLoot`-flagged lists through its sublists.

**Run A — vanilla baseline.** New game, then:

```
coc WhiterunBanneredMare
setgs fSpecialLootMinPCLevelMult 0.6
player.setlevel 45
coc BleakFallsBarrow02
```

Open the boss chest. With the PC floor active the roll lands near **27** — expect genuinely good
gear in a zone pinned to level 4. *That is the bug being fixed*, and seeing it is the point of run A.

**Run B — the probe's value.** New game, do **not** touch `setgs` (the plugin already ships 0):

```
coc WhiterunBanneredMare
player.setlevel 45
coc BleakFallsBarrow02
```

| Chest contents | Meaning |
|---|---|
| Low-tier but **non-empty** — appropriate to a level-4 dungeon | **The change works.** Zone-locked special loot. Ship `0`. |
| **Empty**, or no special-loot item at all | Zero degrades to "no special loot" rather than "zone-only". **Revert to 0.6** and record a documented bone-1 exception, per `loot-model.md` §4 — losing boss chests is worse than the leak. |

Contents are rolled when the container is first loaded, so each arm needs its own first visit. That
is why this test uses a resetting zone and two fresh games.

**Verdict to record:** `0` works / `0` disables special loot.

---

## 4. A census that changes test 1's stakes

Run while selecting the probe site, over all **291 zoned interior cells** of `Skyrim.esm`
(`reference/Base/01Skyrim/Cells/`), resolving every `PlacedNpc`'s base through its template chain to
a terminal class. `[verified]`

| Base resolves to | no `LevelModifier` | modifier set | total |
|---|---|---|---|
| **`LVLN`** (a leveled ladder) | **9** | 2,138 | 2,147 |
| `NPC_` with a fixed level | 1,014 | 190 | 1,204 |
| `NPC_` with `PcLevelMult` | 83 | 45 | 128 |
| | **1,106** | 2,373 | **3,479** |

**`LevelModifier` only does anything when the placed ref's base resolves to a leveled list** — it is
a multiplier on the *list lookup level* (`engine-behaviour.md` §4). For a fixed-level NPC there is no
lookup to modify, and a `PcLevelMult` actor ignores zones entirely (§1) and is already the rules
half's job.

So the population at risk from a bad test-1 result is **9 records, not ~1,928**. The larger figure
counted unmodified placed refs without asking whether they had a leveled list behind them; 1,014 of
them are fixed-level corpses, skeletons, skeevers and quest NPCs, and 83 are `PcLevelMult`.

All 9:

| Cell | Zone | Refs |
|---|---|---|
| `Ustengrav01` | `03EC83` | `02137C` `02137D` `02137E` `0213C6` — the four bandits above |
| `WolfSkullCave02` | `03EC8E` | `09DA1F` `09DA20` `09DA21` `09DA22` — `MS06NecromancerCultist1–4` |
| `SnaplegCave01` | `03EC73` | `0694D1` — `LvlDeer` |

Even in the worst case the fix is 9 placed-ref overrides, or simply accepting them.

**Scope of the census:** `Skyrim.esm` interiors only. `Worldspaces/` and the DLC are not covered, and
per CLAUDE.md's DLC trap (b) they must be checked separately rather than extrapolated.

**This supersedes the sizing of the `LevelModifier` test across the Phase 3 design docs** — the claim
that a bad result forces ~1,928 placed-ref edits and "roughly *sextuples* the plugin". All four
affected documents now carry the correction:

| Document | What changed |
|---|---|
| `implementation-strategy.md` | new **§7.1** holds the correction in full; §7's table row, §5.2 and §9 step 1 adjusted to match |
| `tiers.md` | §4 *"The unresolved `None` case"* gains a revision note and a rewritten contingency table; §11 item 3 and §12 item 1 downgraded |
| `engine-behaviour.md` | §7 item 1 gains a revision note; §4 implication 2's "second bone-1 leak" scoped to nine records |
| `CLAUDE.md` | *Current phase* no longer says two tests can move work across the plugin/rules line |

`enemy-taxonomy.md` §5's raw count of 1,928 unmodified interior refs is **correct as a count** and is
left alone — it is the inference drawn from it, not the census, that was wrong.

**The consistent verdict across all of them:** the `None` test is still open and still worth running,
but it is routine. The test that can still move a large amount of work is **gear resolution**
(test 2), and it should be run first.

---

## 5. Results

Fill in when run. Mark `[verified]` only for what was actually observed in-game.

| Test | Verdict | Date | Notes |
|---|---|---|---|
| 1 — `LevelModifier: None` | | | |
| 2 — NPC gear resolution | | | |
| 3 — `fSpecialLootMinPCLevelMult` = 0 | | | |

---

## Sources

`design/engine-behaviour.md` §0.3, §1, §3, §4, §7 · `design/tiers.md` §4 · `design/loot-model.md`
§3, §4 · `design/implementation-strategy.md` §7, §9 · `reference/Base/01Skyrim/EncounterZones/` ·
`reference/Base/01Skyrim/Cells/` · `reference/Base/01Skyrim/LeveledNpcs/` ·
`reference/Base/01Skyrim/GameSettings/`
