# Archetype tiers — the roster table

**Phase 4, step 2** of `requiem-method.md` §6. Under the Requiem-method architecture the tier ladder
stops indexing *places* and starts indexing *creature families*: a flattened list has one fixed
roster, and that roster is what a player meets everywhere the list is placed.

This document assigns that roster, for every archetype, once.

Read `requiem-method.md` first. Inputs: `tiers.md` (the ladder), `enemy-taxonomy.md` §2 (the vanilla
ladders, `[verified]`), `lore-constraints.md` §1 (the display-name hierarchy, `[verified]`).

**The ladder, unchanged:** `T1 = 4 · T2 = 8 · T3 = 14 · T4 = 21 · T5 = 30 · T6 = 40 · T7 = 50`.

---

## 1. Four rules that generate every row

### Rule 1 — keep vanilla's tier records exactly as they are

**Do not re-level the tier NPCs.** `enemy-taxonomy.md` §3 measured why: level and capability are
welded into the same record. `EncBandit01TemplateMelee` (L=1) is 35 health and one perk that
*reduces* its damage; `EncBandit06TemplateMelee` (L=25) is 489 health and eleven perks including the
skill-60 ranks. `[verified]` Editing a level without re-perking produces an incoherent actor, and
re-perking 300 records is a combat overhaul — an explicit non-goal.

So Ehlnofey never writes a level onto a tier record. **The only decision is which rungs stay in the
pool.** Everything Bethesda tuned is preserved, and the tier label is descriptive: it names the
nearest rung on the ladder.

### Rule 2 — flatten the gate, keep a *weighted* pool

Every surviving rung goes in at `Level: 1` with `CalculateFromAllLevelsLessThanOrEqualPlayer` set, so
all rungs are always eligible and one is drawn at random. Weight by **repeating the entry**:
`Bandit ×3` means the entry appears three times.

> **Correction to `requiem-method.md` §4.4.** Weighting is *literal entry duplication*, not a `Count`
> field. `Count` is how many actors the entry spawns; `CalculateForEachItemInCount` rolls each of
> them separately. Requiem's `_CLI_` convention writes `Count: 5` as authoring shorthand and its
> **patcher unrolls it into five entries** (`lessons-for-ehlnofey.md` §4) — the engine has no weight
> field. Ehlnofey has no patcher, so it writes the duplicates out. Costs bytes, needs nothing.

### Rule 3 — a roster spans at most three adjacent tiers, and the top rung is rare

This is the bone-2 constraint doing real work. A pool spanning the whole ladder is not a fixed
difficulty, it is *random* difficulty, and a camp whose danger cannot be predicted is illegible
however fixed its distribution. Narrow band, weighted toward the middle, one visible top rung for
texture. **The archetype's tier is the band's centre**, and that is the number the player learns.

### Rule 4 — the name must match the tier

`lore-constraints.md` §1: the display names *are* the legibility mechanism. A rung stays in the pool
under its vanilla name or not at all. Where a name implies a rung above the band — Valkynaz, Volkihar
Master, Arch Conjurer — the rung is **reserved for named, summoned or boss placements**, never
dropped and never demoted.

---

## 2. The calibration check — three ladders land 1:1 on the ladder

`lore-constraints.md` §5.2 set the test: *"if a proposed tier system cannot express the Dremora ladder
cleanly, the tier system is wrong."* It expresses it exactly. `[verified]`

| Tier | `N` | **Dremora** | **Warlock** | **Vampire** |
|---|---|---|---|---|
| T1 | 4 | — | Wizard (1) | Fledgling (1) |
| T2 | 8 | **Churl** (6) | Apprentice Conjurer (6) | Vampire (6) |
| T3 | 14 | **Caitiff** (12) | Conjurer Adept (12) | Blooded (12) |
| T4 | 21 | **Kynval** (19) | Conjurer (19) | Mistwalker (20) |
| T5 | 30 | **Kynreeve** (27) | Ascendant Conjurer (27) | Nightstalker (28) |
| T6 | 40 | **Markynaz** (36) | Master Conjurer (36) | Ancient (38) |
| T7 | 50 | **Valkynaz** (46) | Arch Conjurer (46) | Volkihar (48) |

Three independent vanilla ladders, one of them documented in an in-game book, all seven rungs, no
collisions. The draugr ladder does the same across T1–T5 — unsurprising, since `tiers.md` §3 derived
the steps from it, but the Dremora and Vampire agreement is a genuine external check.

**Consequence:** the tier number is a real cross-archetype currency. That closes
`lore-constraints.md` §6.1's open question — *"is a Draugr Scourge more dangerous than a Forsworn
Ravager?"* Under this table, **yes-or-no is answerable: they are both T5, so they are equals.**
Vanilla could not answer it because the ladders were indexed by player level, not by a shared scale.

---

## 3. Class A — the tier ladders

The main table. `Vanilla rungs` are name (level) from `lore-constraints.md` §1 and
`enemy-taxonomy.md` §2, all `[verified]`. `Roster` is the flattened pool with weights.
**Bold** = the band centre, i.e. the archetype's tier.

### 3.1 Humanoid factions

| Archetype | List | Vanilla rungs | **Ehlnofey roster** | Band |
|---|---|---|---|---|
| **Bandit** | `LCharBanditMelee1H` 039CFC &c. | Bandit 1 · Outlaw 5 · Thug 9 · Highwayman 14 · Plunderer 19 · Marauder 25 | Bandit ×3 · **Outlaw ×3** · Thug ×2 · Highwayman ×1 | **T2** (T1–T3) |
| Bandit boss | `LCharBanditBoss` 03DF16 | 6 · 10 · 16 · 21 · 28 | 16 ×2 · **21 ×2** · 28 ×1 | **T4** (T3–T5) |
| **Orc stronghold** | `LCharOrcMelee` 01E780 | reuses bandit records | Outlaw ×1 · Thug ×3 · **Highwayman ×3** · Plunderer ×1 | **T3** (T2–T4) |
| **Forsworn** | `LCharForswornMelee1H` 01E792 | Forsworn 1 · Forager 6 · Looter 14 · Pillager 24 · Ravager 34 · Warlord 46 | Forsworn ×2 · Forager ×3 · **Looter ×3** · Pillager ×1 | **T3** (T1–T4) |
| Forsworn boss | `LCharForswornBossMelee1H` 0442F2 | Briarheart 7 · 16 · 27 · 38 · 51 | 16 ×2 · **27 ×2** · 38 ×1 | **T5** (T3–T6) |
| **Warlock** (all five) | `LCharWarlockFire` 01E7D1 &c. | Wizard 1 · Appr. Conjurer 6 · Conjurer Adept 12 · Conjurer 19 · Ascendant 27 · Master 36 · Arch 46 | Appr. Conjurer ×2 · **Conjurer Adept ×3** · Conjurer ×3 · Ascendant ×1 | **T3** (T2–T5) |
| Warlock boss | `LCharWarlockBossFire` 0E1018 | 7 · 14 · 21 · 30 · 40 | 21 ×2 · **30 ×2** · 40 ×1 | **T5** (T4–T6) |
| **Thalmor** | `LCharThalmorMelee1H` 02B129 | 4 · 12 · 20 · 28 · 36 | 12 ×2 · **20 ×3** · 28 ×2 | **T4** (T3–T5) |
| Thalmor boss | `LCharThalmorMagicBoss` 07DCA9 | 14 · 23 · 32 · 40 · 50 | 23 ×2 · **32 ×2** · 40 ×1 | **T5** (T4–T6) |
| **Alik'r** | `LCharAlikrMelee1H` 06766F | 1 · 6 · 14 · 24 · 34 · 44 | Forager-tier 6 ×2 · **14 ×3** · 24 ×1 | **T3** (T2–T4) |
| **Vampire** | `LCharVampire` 033973 | Fledgling 1 · Vampire 6 · Blooded 12 · Mistwalker 20 · Nightstalker 28 · Ancient 38 · Volkihar 48 (+60 DLC1) | Vampire ×2 · **Blooded ×3** · Mistwalker ×3 · Nightstalker ×1 | **T4** (T2–T5) |
| Vampire boss | `LCharVampireBoss` 0339A9 | 14 · 23 · 31 · 42 · 53 | 23 ×2 · **31 ×2** · 42 ×1 | **T5** (T4–T6) |
| **Werewolf** | `LCharWerewolf` 01E791 | 1 · 6 · 12 · 20 · 28 · 38 | 12 ×2 · **20 ×3** · 28 ×1 | **T4** (T3–T5) |
| **Penitus Oculatus** | `LCharPenitusOculatus` 07D99F | 1 · 4 · 8 · 13 · 18 · 23 | 8 ×2 · **13 ×3** · 18 ×1 | **T3** (T2–T4) |
| **Ghost** | `LCharGhostWizard` 104B62 | 1 · 5 · 9 · 14 · 19 · 25 | 5 ×2 · **9 ×3** · 14 ×1 | **T2** (T2–T3) |
| **Witch** | `LCharWitchAny` 074F9D | 4 · 8 | 4 ×1 · **8 ×1** | **T2** (T1–T2) |
| **Vigilant of Stendarr** | `LCharVigilantOfStendarr` 0BFB53 | 5 — single gate | *(unchanged — already flat)* | **T2** |
| **Dawnguard** | `LCharDawnguardMelee1H` 014281 | 1 · 5 · 9 · 14 · 19 · 25 | 9 ×2 · **14 ×3** · 19 ×1 | **T3** (T2–T4) |

**Vigilants are the precedent, not the bug.** `enemy-taxonomy.md` §2.1 flags them as the one vanilla
humanoid faction that already satisfies bone 1. They need no edit and they are proof the shape works.

**Penitus Oculatus fixes itself.** Vanilla's ladder is inverted — gates reach 46 but the top tier is
level 23, so they get *relatively weaker* as the player levels `[verified]`. Flattening deletes the
inversion; no special handling.

### 3.2 Draugr — the anchor ladder

| List | Vanilla rungs | **Ehlnofey roster** | Band |
|---|---|---|---|
| `LCharDraugrMelee1HMale` 055936, `Melee2H` 01E772, `Missile` 0A6844 | Draugr 1 · Restless 6 · Wight 13 · Scourge 21 · Deathlord 30 | Draugr ×2 · Restless ×3 · **Wight ×3** · Scourge ×2 · Deathlord ×1 | **T3** (T1–T5) |
| `LCharDraugrWarlockMale` 0BF7BB | 6 · 13 · 21 | 6 ×1 · **13 ×3** · 21 ×2 | **T3** (T2–T4) |
| `LCharDraugrBoss` 042480 | Overlord 7 · Wight Lord 15 · Scourge Lord 24 · Death Overlord 34 · 45 · 50 | Wight Lord ×2 · **Scourge Lord ×3** · Death Overlord ×2 · 45 ×1 | **T4** (T3–T6) |
| `LCharDraugrBossNoDragonPriest` 0DD9D8 | 7 · 15 · 24 · 34 · 45 | same as above, minus the priest attachment | **T4** |

Draugr get the **widest band in the table (T1–T5)**, deliberately: they are the most-placed archetype
in the game, they carry the deepest named ladder, and `lore-constraints.md` requires draugr power to
track the tomb. The tomb is gone as an input, so the *spread* has to carry the texture instead. This
is the row most likely to need retuning after step 7 play-testing.

**Lore invariant preserved:** the Dragon Priest (fixed 50, T7) outranks every draugr in his barrow —
the boss band tops at 45. `[verified]` against `lore-constraints.md` §3.

### 3.3 Falmer, Dwemer, Dremora

| Archetype | List | Vanilla rungs | **Ehlnofey roster** | Band |
|---|---|---|---|---|
| **Falmer** (melee/missile) | `LCharFalmerMelee` 01E77D | Falmer 9 · Skulker 15 · Gloomlurker 22 · Nightprowler 30 · Shadowmaster 38 | Falmer ×2 · **Skulker ×3** · Gloomlurker ×2 · Nightprowler ×1 | **T3** (T2–T5) |
| Falmer (shaman) | `LCharFalmerShaman` 01E77F | 5 · 8 · 14 · 19 · 25 | 14 ×2 · **19 ×2** · 25 ×1 | **T4** (T3–T5) |
| Falmer (boss) | `LCharFalmerBoss` 05238F | 18 · 26 · 35 · 44 | 26 ×2 · **35 ×2** · 44 ×1 | **T5** (T4–T6) |
| **Dwarven spider** | `LCharDwarvenSpider` 10EC90 | 6 · 12 · 16 | 12 ×2 · **16 ×2** | **T3** (T3–T4) |
| **Dwarven sphere** | `LCharDwarvenSphere` 10EC8F | 16 · 24 · 30 | 16 ×1 · **24 ×3** · 30 ×1 | **T4** (T4–T5) |
| **Dwarven centurion** | `LCharDwarvenCenturion` 10FCE5 | 24 · 30 · 36 | **30 ×2** · 36 ×1 | **T5** (T5–T6) |
| Dwarven mixed | `LCharDwarvenAutomaton` 01E783 | 6 · 12 · 16 · 24 · 30 · 36 | spider 16 ×3 · **sphere 24 ×3** · centurion 30 ×1 | **T4** (T4–T5) |
| **Dremora** | `LCharDremoraMelee` 01E79B | Churl 6 · Caitiff 12 · Kynval 19 · Kynreeve 27 · Markynaz 36 · Valkynaz 46 | Churl ×2 · **Caitiff ×3** · Kynval ×3 · Kynreeve ×1 | **T3** (T2–T5) |

**The Falmer shaman defect is closed by construction.** Vanilla caps shamans at 25 while melee Falmer
reach 38 `[verified]`; `lore-constraints.md` permits closing it. The rosters above put shamans at T4
and melee at T3, so the caster is now the *stronger* of the pair — which is what a hive's spellcaster
should be, and it costs nothing but rung selection.

**Automatons are the safest hard-fix in the game** (`lore-constraints.md` §3): machines in a sealed
ruin, fictionally static, with a clean Spider < Sphere < Centurion order that vanilla already honours.

**Markynaz (T6) and Valkynaz (T7) are reserved**, per rule 4 and the in-game book's *"the Valkynaz are
rarely encountered on Tamriel"* `[verified]`. They appear only via conjuration and named placements —
which also satisfies `lore-constraints.md` §4 item 5: a Master Conjurer (T6) summons a Markynaz (T6),
in step.

### 3.4 Dragons and the DLC families

| Archetype | List | Vanilla rungs | **Ehlnofey roster** | Band |
|---|---|---|---|---|
| **Dragon** | `LCharDragonAny` 05EACF | Dragon 10 · Blood 20 · Frost 30 · Elder 40 · Ancient 50 | Dragon ×2 · **Blood ×3** · Frost ×2 · Elder ×1 | **T4** (T3–T6) |
| Dragon (Solstheim) | `DLC2LCharDragonAny` 036135 | + 58 | as above · Elder ×2 · 58 ×1 | **T5** (T4–T6) |
| **Riekling** | `DLC2LCharRieklingMelee` 01B653 | 6 · 11 · 16 · 23 | 6 ×2 · **11 ×3** · 16 ×2 | **T2** (T2–T4) |
| **Ash Spawn** | `DLC2LCharAshSpawnAll` 0322BD | 20 — single gate | *(unchanged — already flat)* | **T4** |
| **Cultist** | `DLC2LCharCultist` 030CDC | 12 · 19 · 27 · 36 · 46 | 19 ×2 · **27 ×3** · 36 ×1 | **T5** (T4–T6) |
| **Seeker** | `DLC2LCharSeeker` 028E87 | 21 · 32 · 42 | 21 ×1 · **32 ×3** · 42 ×1 | **T5** (T4–T6) |
| **Lurker** | `DLC2LCharLurker` 01B64D | 24 · 34 · 44 · 54 | 34 ×2 · **44 ×2** | **T6** (T5–T6) |
| **Gargoyle** | `LCharGargoyle` 017704 | 13 · 25 · 43 | 13 ×1 · **25 ×3** · 43 ×1 | **T4** (T3–T6) |
| **Chaurus Hunter** | `DLC1LCharChaurusHunter` 0029A2 | 16 · 32 | 16 ×2 · **32 ×1** | **T4** (T4–T5) |
| **Armored Troll** | `DLC1LCharTrollArmored` 00D0BB | 14 · 22 | 14 ×2 · **22 ×1** | **T3** (T3–T4) |
| **Solstheim bandit** | `DLC2LCharBanditMelee1H` 01E8A9 | parallel records, 1–25 | **mirror §3.1's mainland bandit exactly** | **T2** |

**Apocrypha stays flat and high** — `lore-constraints.md` §3 explicitly permits it: *"one realm,
entered by one means, and Mora's servants have no reason to be graded by which book you opened."*
Seekers T5, Lurkers T6, no internal gradient.

**Solstheim's higher ceiling is kept** (`lore-constraints.md` §5.5), not normalised away: its dragons,
Lurkers and Acolytes all sit above their mainland equivalents.

---

## 4. Class B — species substitution and the biome lists

Different mechanism, different fix. `enemy-taxonomy.md` §2.3: **creature levels are already fixed on
the record**; the leveled list substitutes a *species* as the player levels. Flattening therefore does
not set a level — it fixes **which animals live where**.

| List | Vanilla substitution | **Ehlnofey roster** |
|---|---|---|
| `LCharFrostbiteSpider` 01E77C | Spider 1 → Large 6 → Giant 14 | Spider ×3 · **Large ×3** · Giant ×1 |
| `LCharBearAll` 042266 | Bear 12 → Cave 16 → Snow 20 | **Bear ×3** · Cave ×2 · Snow ×1 |
| `LCharBearPlainsForestHills` 01E796 | Bear 12 → Cave 16 | **Bear ×3** · Cave ×1 |
| `LCharSabrecat` 0FE2D5 | Sabre Cat 6 → Snowy 11 | **Sabre Cat ×3** · Snowy ×1 |
| `LCharChaurus` 01FA27 | Chaurus 12 → Reaper 20 | **Chaurus ×3** · Reaper ×1 |
| `LCharSpriggan` 10EC84 | Spriggan 8 → Matron 18 | **Spriggan ×3** · Matron ×1 |
| `LCharAtronach` 01E77A | Flame 5 → Frost 16 → Storm 30 | **Flame ×2 · Frost ×2 · Storm ×1** — summon-tier, keep the spread |
| `LCharMudcrab` 02183E | Medium 1 → Large → Giant | **Medium ×3** · Large ×2 · Giant ×1 |
| `LCharCustomIceWraithFrostTroll` 106386 | Ice Wraith 9 → Frost Troll 22 | **Ice Wraith ×2** · Frost Troll ×1 |

### 4.1 The biome ambient lists — flatten in place, keep the geography

`requiem-method.md` §5.4: Bethesda **already partitions wilderness by biome** `[verified]`, so
flattening each list in place yields fixed *and* regionally varied wildlife with zero new records.

The rosters are the vanilla species already on each list, weighted to their biome's identity:

| List | Roster | Reads as |
|---|---|---|
| `LCharAnimalForestPredator` 042297 | Wolf ×4 · Skeever ×2 · **Frostbite Spider ×2** · Bear ×1 · Troll ×1 | pine forest — T1–T3 |
| `LCharAnimalMountainSnowPredator` 04229D | Ice Wolf ×3 · **Snow Sabre Cat ×2** · Ice Wraith ×2 · Snow Bear ×1 · Frost Troll ×1 | high country — T2–T4 |
| `…PlainsPredator` · `…CanyonPredator` · `…MarshPredator` · `…CoastSnowPredator` · `…ForestSnowPredator` · `LCharAnimalHills` · `LCharAnimalSnowFields` | same treatment, per biome | — |
| prey counterparts (`…Prey`, `LCharDeer`, `LCharElk`) | already flat — **leave alone** | T1 |

> **This is where the pivot pays off most.** `enemy-taxonomy.md` §2.3 found the wilderness is *already*
> effectively deleveled above ~level 20 — forest predators cap at a level-16 cave bear, mountain
> predators at a level-22 frost troll — *"the danger gradient Ehlnofey wants for the overworld largely
> exists, it just stops mattering because the player outgrows it."* `[verified]` Flattening keeps the
> gradient and removes the outgrowing. **No zones, no new records, 18 rules.**

**Hard lore constraint, carried:** giants, mammoths and most `PredatorFaction` wildlife are
**passive** and must stay passive (`lore-constraints.md` §4 item 1). Difficulty comes from what they
are, never from making them aggressive. A level-32 giant standing peacefully in a T1 meadow *is* the
design working.

---

## 5. Class C — already fixed, verify and leave

No edit. Listed so the audit script knows they are deliberate. `[verified]`

| Archetype | Level | ≈ Tier |
|---|---|---|
| Skeleton · Deer · Elk · Wolf | 1–2 | T1 |
| Death Hound | 5 | T2 |
| Vigilant of Stendarr | 5 | T2 |
| Ash Spawn | 20 | T4 |
| Giant | 32 | T5 |
| Dragon Priest (all 8 Skyrim, + Vahlok) | 50 | **T7** |

---

## 6. Class D — the `PcLevelMult` actors, including followers

`tiers.md` §7 assigned the world-facing clusters and they are unchanged by the pivot — these actors
never honoured zones anyway (`engine-behaviour.md` §1), so flattening changes nothing about them.

| Cluster | Vanilla | **Ehlnofey** |
|---|---|---|
| City guards | ×1 [20–50] | **21 (T4)** |
| Imperial / Stormcloak soldiers | ×0.25 [1–50] | **14 (T3)** |
| Hunters | ×0.5 [5–15] | **8 (T2)** |
| Nightingales | ×1 [15–45] | **30 (T5)** |
| `WE*` world encounters | various | **8 (T2)** default |
| Zahkriisos | ×1 [25–60] | **60** — matches his fixed siblings |

**Lever:** SkyPatcher `filterByPCLevelMult=true` + `setPcLevelMult=false=<N>` + `level=<N>`. Both
halves or it fails (`implementation-strategy.md` §4).

### 6.1 Followers — deleveled, by role, by hand

Decided in `requiem-method.md` §4.3: Ehlnofey **rejects** Requiem's ally exception. The roster is
Requiem's own retained-68 list (`plugin-analysis.md` §1a), verdict inverted. These are hand-set, not
rule-set — hand-setting is the point.

| Group | **Tier** | Reasoning |
|---|---|---|
| Standard followers — Faendal, Sven, Golldir, Annekke, Benor, Cosnach, Borgakh, Ghorbash, Lob, Ogol, J'zargo, Derkeethus | **T2–T3** (8–14) | Villagers and drifters who agreed to come along |
| Hirelings — Belrand, Jenassa, Marcurio, Stenvar, Vorstag, Erik | **T3** (14) | Working professionals who charge 500 gold |
| Junior Companions — Athis, Njada, Ria, Torvar | **T3** (14) | Whelps |
| Housecarls (incl. Hearthfire) | **T4** (21) | Hold-appointed warriors — **equal to a city guard**, which is exactly what they are |
| Senior Companions — Aela, Farkas, Vilkas | **T5** (30) | Circle members, veterans |
| Dawnguard followers — Agmaer, Beleval, Celann, Durak, Ingjard, Florentius | **T4** (21) | Trained order, mid-campaign |
| Serana | **T6** (40) | Pure-blood Volkihar. Must sit above the generic vampire band (T4) and below Harkon |

**The design consequence, stated so it is chosen and not discovered:** a follower now has a *place* on
the same ladder as the world. A T3 hireling is a real asset to a character clearing T2 bandit camps
and a liability in a T5 barrow. Choosing and changing companions becomes a decision with
consequences — the fixed-world contract applied to allies.

**Flagged as untested** (`requiem-method.md` §8.4): nobody has played this. Revisit after step 9.

---

## 7. Named capstones — above the ladder

From `tiers.md` §8 and `enemy-taxonomy.md` §2.2/§2.5. These are the documented bone-1 exceptions and
the T7-and-above set.

| Record | FormKey | Vanilla | **Ehlnofey** |
|---|---|---|---|
| `AlduinBase` | 08E4F1 | ×1.2 [10–100] | **60** |
| `DLC1Harkon` | 003BA7:Dawnguard | ×1.2 [10–60] | **55** |
| `DLC1HarkonCombat` | 01A93D:Dawnguard | ×1.4 [10–60] | **60** — both records or the transformation is a downgrade |
| `DLC2Miraak` | 017F7D:Dragonborn | ×1 [35–**200**] | **65** |
| `DLC2MiraakMQ06` | 01FB98:Dragonborn | ×1.1 [35–150] | **65** |
| Dragon Priests ×8 + Vahlok | — | fixed 50 | **50 (T7)** — unchanged |
| Ahzidal, Dukaan | 0248E9, 0248E1 | fixed 60 | **60** — unchanged |
| `EncBandit04TemplateMelee` | 01E60D | **level 0** (vanilla bug) | **14** |

Harkon at 55/60 clears his own court (Volkihar 48 / Volkihar Master 53), satisfying
`lore-constraints.md` §3's purity requirement `[verified]`.

---

## 8. What this hands to the build

| | count |
|---|---|
| Class A lists to flatten (§3) | **~40** |
| Class B lists to flatten (§4, incl. 18 biome lists) | **~27** |
| Class C — verify only | 8 families, **0 edits** |
| Class D — SkyPatcher rules (§6) | **~6 lines** |
| Followers — hand-set `NPC_` overrides (§6.1) | **~68** |
| Named capstones (§7) | **8 records** |

**~67 leveled lists and ~76 NPC records** for the entire actor half — against `requiem-method.md`
§5.5's ~450 for the loot half. The actors were never the expensive part; `enemy-taxonomy.md` §6 said
so in Phase 1 (*"the dominant cost is E, not the actors at all"*) and the pivot has not changed it.

---

## 9. Open questions

1. **The draugr band (T1–T5) is the widest in the table and the least defended.** It is carrying
   texture that the zone used to carry. If step 7 play-testing says barrows feel random rather than
   fixed, narrow it to T2–T4 and push Deathlords to boss placements only. **Most likely row to move.**
2. **Bandits become trivial after ~T3, and they are ~40% of the placed world.** That is the honest
   cost of a fixed world and Requiem accepts it. The alternative — widening the bandit band — trades
   legibility for relevance. Do not decide this on paper; decide it after walking into three camps.
3. **Weights are guesses.** The rungs are `[verified]`; the ×3/×2/×1 ratios are design judgement with
   no vanilla precedent to copy, because vanilla never needed weights. Expect to retune.
4. **Follower tiers are untested as a design** (§6.1).
5. **Ambient biome rosters (§4.1) are sketched, not enumerated.** The nine `LCharAnimal*` lists need
   their actual entries read out of `reference/` before authoring — this table gives the shape and two
   worked examples, not the full membership.

---

## Sources

`design/tiers.md` §§3, 6, 7, 8 (the ladder, home bands, class D, exceptions) ·
`design/requiem-method.md` §§4.2, 4.3, 4.4, 5.4 · `world/enemy-taxonomy.md` §§1, 2.1–2.7, 3, 6
(every vanilla rung, `[verified]`) · `world/lore-constraints.md` §§1, 2, 3, 4, 5 (the name hierarchy
and the fictional constraints) · `prior-art/requiem/plugin-analysis.md` §§1a, 2 ·
`prior-art/requiem/lessons-for-ehlnofey.md` §4 (the `_CLI_` weighting correction in §1).
