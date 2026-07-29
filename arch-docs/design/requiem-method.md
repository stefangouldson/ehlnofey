# The Requiem method, with Ehlnofey's twists — a Phase 4 architecture proposal

**Status: PROPOSAL, not yet ratified.** Written on branch `design/requiem-method` (2026-07-29) after
the probe results came in. It re-opens the Phase 3 architecture decision recorded in
`implementation-strategy.md` §1. Nothing in `src/` changes until this is accepted.

Read first: `prior-art/requiem/plugin-analysis.md` (what Requiem actually does),
`probe-test-protocol.md` §§5–6 (what we measured in-game), `implementation-strategy.md` §6 (the
overworld census).

---

## 1. Why this is being reopened

Two objections to the zone-first architecture, both of which our own evidence supports — but not
equally.

### 1.1 "Encounter zones don't apply to the entire world" — **true**

`[verified]`, `implementation-strategy.md` §6.1, from a full scan of the Tamriel worldspace:

| | count |
|---|---|
| Tamriel exterior cell files | 12,148 |
| …carrying an `EncounterZone` | **40 (0.3%)** |
| unzoned leveled actor refs | **3,512** vs 367 zoned |

A zone-first design governs **interiors and 0.3% of the outdoors**. Everything the player meets
walking between dungeons is outside the mechanism. §6 costs the fix at 65 lists + 238 cells, which is
tractable — but note *what* that fix is: **flattening lists**, plus bolting zones onto cells that
never had them. The remedy for the zone architecture's biggest gap is already Requiem's method.

### 1.2 "The loot still scales with the player" — **true where it counts, but narrower than stated**

The probe separated the two loot tracks and they came back **opposite**:

| Track | Resolves against | Evidence |
|---|---|---|
| **Containers** — chests, urns, boss chests | **the zone** ✅ | Test 3. Bleak Falls pinned to 4, player 45: vanilla arm produced a **glass dagger**; with `fSpecialLootMinPCLevelMult = 0` the same chest produced low-tier loot, **identical at player 1 and player 45** |
| **NPC-worn gear** — outfits and inventories | **the player** ❌ | Test 2b. The Swindler's Den chief was **level 28 in both runs** but wore **iron at player 5 and Nordic at player 45** |

So container loot is already place-bound and one GMST closes it. **It is worn gear that scales, and
nothing in the zone architecture can reach it** — there is no zone operand anywhere on an outfit's
material list (`probe-test-protocol.md` §6.1, mechanism traced end to end).

That is the real finding. `loot-model.md` §1's headline — *"the tier ladder IS the material ladder, no
truncation pass needed"* — is dead, and with it the claim that bone 3 falls out of the difficulty map
for free.

### 1.3 What is *not* wrong with the zone architecture

Stated plainly so the pivot is made on the real balance sheet, not on momentum:

- **Test 2a passed outright.** Swindler's Den pinned to 30, observed at player 5 **and** player 45,
  **identical both times** — levels 1 / 5 / 9 / 19 / 28. A level-5 character and a level-45 character
  met the same fixed dungeon. `[verified]` That is the mod's thesis working, and it works *because* of
  the zone clamp.
- **Test 1 passed.** `LevelModifier: None` honours the zone, not the player. Zero records to fix.
- **Test 3 passed.** Zeroing the PC floor zone-locks special loot instead of disabling it.

Three of four gating tests came back in favour of the current design. The pivot below is therefore a
**re-weighting, not a repudiation** — and §7 keeps every part of it that earned its place.

---

## 2. What Requiem's method actually is

Four moves, all `[verified]` in `prior-art/requiem/plugin-analysis.md`:

1. **Flatten the `LVLN` gate, keep the pool.** All 328 vanilla lists it overrides become
   single-gate; 518 of 571 gate at `Level: 1`. Entry count only falls to 81.6% of vanilla, so the
   list stops being a ladder and becomes a **uniform random draw over variants**.
   `LCharDraugrBoss`: 13 entries across 7 gates → **one entry**.
2. **Same for `LVLI`.** 2,034 of 2,125 overrides single-gate; only **5 live lists** keep any player
   gating at all.
3. **Convert enemy `PcLevelMult` → fixed; leave allies scaling.** 261 converted, 68 retained, the 68
   being followers, housecarls and hirelings.
4. **Do not use encounter zones.** 8 records out of vanilla's 358, none for levelling. Its one `ECZN`
   transformer only sets `DisableCombatBoundary`.

**Why (4) follows from (1).** A zone *clamps the level the leveled-list machinery computes*. Flatten
the lists and there is nothing left to clamp. Requiem removed scaling rather than bounding it — which
is exactly why its method needs no zones and therefore covers the overworld for free.

### 2.1 The scope, measured in our own reference decompile

Base game + Dawnguard + Dragonborn, Hearthfire excluded per `difficulty-map.md` scope.
"Real gate" = more than one *distinct* entry `Level` on the record (CLAUDE.md's "count the entries,
not the flag" rule). `[verified]`, this branch:

| | records | **real-gated** | entries | entries in gated lists |
|---|---|---|---|---|
| `LeveledNpcs` | 681 | **269** | 4,022 | 1,836 |
| `LeveledItems` | 3,824 | **1,756** | 25,438 | 13,325 |

**~2,025 lists is the whole job at its ceiling** — and the ceiling is not the target, see §5.1.
For comparison Requiem, a total overhaul, touched 328 `LVLN` + 2,125 `LVLI`. Ehlnofey's deleveling
core is the same order of magnitude as Requiem's *while excluding everything else Requiem does* —
the 4,340 weapons, 3,106 armors, 2,263 recipes, 2,050 magic effects and 599 perks that make up its
108 MB.

---

## 3. The one thing Requiem's method costs, and it is the thing Ehlnofey is named after

**Flattening destroys place granularity.**

Once `LCharBanditMelee1H` is one flat pool, every bandit camp in Skyrim draws from the same pool.
Bleak Falls Barrow, Dustman's Cairn and Volunruud become the same difficulty. Requiem accepts this:
its difficulty comes from *which archetype vanilla hand-placed where*, plus a very wide fixed-level
ladder (0–250), plus thirteen years of manual curation — `Changelog.md` is 2,491 lines of entries like
*"Delevels Fjola, Umana and Sulla Trebatius"*.

For Ehlnofey that is a direct hit on two of three bones:

| Bone | Under pure flattening |
|---|---|
| 1. The world does not scale | ✅ **fully satisfied**, and more completely than zones manage |
| 2. Danger is legible | ⚠️ weakened — a legible tier ladder needs *tiers*, and 355 zones collapse to ~8 archetype levels |
| 3. Reward follows **place** | ❌ **broken** — reward would follow archetype, not place |

It also writes off `difficulty-map.md` in its entirety: 355 zones, generated from rules, the single
largest artefact Phase 3 produced.

**So the question is not "Requiem or zones".** It is: *can we take Requiem's technique — which is
correct, and which is the only thing that reaches worn gear and the overworld — without giving up the
place topography that the mod is named for?*

Yes. §4.

---

## 4. Twist 1 — the tier-selector ladder (**the core proposal**)

Requiem flattens the ladder. Ehlnofey **re-purposes** it: the vanilla ladder stops being an index on
*player level* and becomes an index on *tier*, and the encounter zone is what reads the index.

```
                      ┌── the ONE gated record left, gates = the tier ladder ──┐
zone level 30 (T5) ──►│ LCharBanditMelee1H  (override, re-gated 4/8/14/21/30/40/50)
                      │   L4  → EHL_LChar_Bandit_T1  ─┐
                      │   L8  → EHL_LChar_Bandit_T2   │  each leaf is a FLAT pool
                      │   L14 → EHL_LChar_Bandit_T3   │  (Requiem's "flatten the gate,
                      │   L21 → EHL_LChar_Bandit_T4   │   keep the pool", applied here)
                      │   L30 → EHL_LChar_Bandit_T5 ◄─┤  ← selected
                      │   L40 → EHL_LChar_Bandit_T6   │
                      │   L50 → EHL_LChar_Bandit_T7  ─┘
                      └────────────────────────────────────────────────────────┘
```

**What this buys:**

- **Player level drops out entirely below the selector.** Everything from the leaf down is flat, so
  worn gear, inventories and sub-pools are all deterministic — the fix test 2b demands.
- **The place still chooses the tier**, so `difficulty-map.md`'s 355 zones stay load-bearing and bone 3
  survives.
- **Variety survives inside the tier**, exactly as Requiem's measurement showed (342 of 571 lists kept
  4+ entries).
- **The tier is legible** — the leaf pool holds the display names `lore-constraints.md` requires
  (Draugr → Restless → Wight → Scourge → Deathlord), and now those names are *pinned to a tier* rather
  than to a rung the player's level happens to unlock.
- **It is one gated record per archetype, not 269.** The gates only have to be right on the selector;
  everything below is flat.

### 4.1 The flag that decides whether this works — **must be tested first**

`LCharBanditMelee1H` carries `CalculateFromAllLevelsLessThanOrEqualPlayer`. With that flag set, **all
rungs ≤ the lookup level are eligible and one is drawn uniformly** — the ladder is a *pool up to a
ceiling*, not a rung selector.

Our own test 2a data says so: Swindler's Den at zone 30 produced levels **1 / 5 / 9 / 19 / 28**, a
spread, not a single rung. `[verified]`

That is fine — arguably desirable, a camp with grunts and a chief — but it means a T5 zone under the
selector gives **T1–T5 mixed**, not T5. Two usable readings, and the choice is a design decision:

| Flag on the selector | Behaviour | Reads as |
|---|---|---|
| `CalculateFromAllLevelsLessThanOrEqualPlayer` **set** | uniform draw over T1…T*n* | the zone is a **ceiling**; every camp has a mix, apex zones have apex enemies *sometimes* |
| flag **cleared** | only the highest qualifying rung | the zone is a **level**; a T5 crypt is uniformly T5 |

**Cleared-flag behaviour is `[community]`, not `[verified]` here** — the CK's documented meaning is
"otherwise use only the highest applicable level", but this workspace has not tested it and CLAUDE.md's
guardrail 2 says an invented mechanism costs a full test cycle to disprove. **It is one flag on one
record in `EhlnofeyProbe.esp` and one `coc`.** Run it before authoring anything (§8 step 0).

Recommendation pending that test: **clear the flag on the selector, keep it set inside the leaf
pools.** Ceiling-semantics reintroduces player-independent randomness *across tiers*, which reads to
the player as "this dungeon is inconsistent" and undermines bone 2. Mixed rosters are better bought
deliberately, via `LevelModifier` on the placed refs — which vanilla already tuned on 5,685 actors and
test 1 proved is honoured.

### 4.2 What it costs

New records, and this is the first time Ehlnofey needs a real FormID block:

| | count | note |
|---|---|---|
| Selector overrides (re-gated vanilla lists) | ~30–60 | only the archetypes the map actually tiers, not all 269 |
| New flat leaf pools `EHL_LChar_*_T<n>` | ~150–350 | ~5–7 tiers × ~30–50 archetype families |
| **FormID block needed** | **~350–500** | ESL's `0x800–0xFFF` holds 2,048 — **still comfortable**, but no longer "free" |

`/formkey-check` before claiming the block, per CLAUDE.md.

---

## 5. Twist 2 — flatten in place where there is no zone to read

Requiem's method applied **verbatim**, because where there is no zone it is the only thing that works,
and vanilla did the hard part already.

`implementation-strategy.md` §6.2(a), `[verified]`: Bethesda **already partitions wilderness spawns by
biome** — `LCharAnimalForestPredator`, `…PlainsPredator`, `…CanyonPredator`, `…MarshPredator`,
`…MountainSnowPredator`, `…CoastSnowPredator`, `…ForestSnowPredator`, `LCharAnimalHills`,
`LCharAnimalSnowFields`, each with a prey counterpart, plus `LCharMudcrab` (209 refs), `LCharSpriggan`,
`LCharWitchAny`.

**Flatten each biome list to its own fixed roster and you get fixed *and* regionally varied wildlife
with zero new records and zero zones.** The place is encoded in *which list vanilla placed there*.
This is precisely Requiem's method being better than the zone architecture, on the population where it
is better — and it retires the 238-cell / ~7-new-zone bolt-on in §6.4 for the wildlife half.

The humanoid half still needs zones (those lists are shared with the dungeons, §6.2(b)), and under
Twist 1 they become selectors — so the ~238 cells and ~7 wilderness `ECZN` stay, unchanged.

### 5.1 The 2,025-list ceiling is not the target

Two large subtractions, and taking them is the difference between a tractable mod and Requiem's 108 MB:

1. **Container lists are already fixed** (§1.2, test 3). Every `LVLI` reached only through a chest,
   urn or sack resolves at the zone level and needs **no edit**. Only lists reachable from an
   **outfit or an NPC `Items:` block** are broken.
2. **The 23 already-flat overworld lists** need nothing (`LCharSoldierImperial`, `LCharSoldierSons`
   — all 943 Civil War refs — and `LCharAmbientCreatures`).

**Deliverable, step 1 of the work:** a census that partitions the 1,756 gated `LVLI` into
*outfit-reachable* vs *container-only*. That number is unmeasured today and it sizes the entire loot
half of the mod. It is a `reference/` parse, no game launch, and it should be done before anything is
authored.

---

## 6. Twist 3 — adopt Requiem's three record conventions now

Free, and they are pure record technique with no patcher needed
(`prior-art/requiem/lessons-for-ehlnofey.md` §4):

| Convention | Use |
|---|---|
| **`Level: 9999`** | disable an entry in place. The entry stays in the record so diffs and merges still see it, but it can never roll. Better than deletion for a truncation pass |
| **`EHL_NULL_` rename** | retire a record without deleting it — deletion breaks every reference. Requiem has 197 such `LVLI`, 63 `LVLN` |
| **`Count` as a weight** | Skyrim has no weight field; a flat pool makes every variant equally likely. `Count: 5` on one entry with `CalculateForEachItemInCount` is the workaround for "everything is equally likely now" — the cost Requiem paid for flattening and had to build a generator to pay back |

The third matters more here than it looks: **flattening costs variety**, and Twist 1's leaf pools are
where that bill lands. Weighting is how a T5 bandit pool stays mostly Marauders with the occasional
Chief instead of a coin flip.

---

## 7. What survives from the current design, unchanged

The pivot keeps everything the probe validated:

| Component | Status |
|---|---|
| 355 encounter-zone bands, `MinLevel == MaxLevel` (`difficulty-map.md` §7) | **kept** — now the tier index for the selectors, and still governing container loot |
| The T1–T7 ladder 4/8/14/21/30/40/50 (`tiers.md`) | **kept**, and now literally the gate values on every selector list |
| `fSpecialLootMinPCLevelMult = 0` | **kept** — verified working, fixes container loot outright |
| `fLeveledActorMult*` = 0.70 / 0.85 / 1.00 / 1.25 | **kept** — test 1 confirmed the modifier layer is live and zone-bound |
| 12 `LevelGate*` globals → 1 | **kept** |
| 6 named records (Alduin, Harkon ×2, Miraak ×2, the `EncBandit04` L=0 bug) | **kept** |
| SkyPatcher rules for the ~454 `PcLevelMult` actors | **kept** — Requiem's move 3, expressed as a predicate rather than 454 overrides |
| Requiem's follower exception (allies keep scaling) | **adopt explicitly**, as `lessons-for-ehlnofey.md` §5 recommends, recorded as an argued bone-1 exception rather than an accident |
| `loot-model.md` §1 "no truncation pass needed" | ❌ **dead** (§1.2). This proposal replaces it |
| `implementation-strategy.md` §2.5 "no new records" | ❌ **dead** — §4.2 needs a block of ~350–500 |
| `implementation-strategy.md` §6.2(a)'s 238-cell bolt-on for wildlife | ❌ **superseded** by §5; the humanoid half stands |

**Requiem's difficulty-slider move is *not* adopted.** It sets all ten `fDiffMultHPBy/ToPC*` and both
`fDiffMultXP*` to 1.0, removing the player's only difficulty control. Requiem is a total overhaul and
can afford that; Ehlnofey is not a combat overhaul (explicit non-goal) and taking a player's slider
away is out of scope. Leave them vanilla.

---

## 8. Order of work

**Step 0 — one probe test, before anything is authored.** `EhlnofeyProbe.esp` already exists and
already pins Swindler's Den to 30. Add one record: an override of `LCharBanditMelee1H` (`039CFC`) with
`CalculateFromAllLevelsLessThanOrEqualPlayer` **cleared**, gates untouched. `coc SwindlersDen01` at any
player level and read `getlevel` on the four modifier classes. If every actor in a class reads one
rung, §4.1 is settled and Twist 1 is buildable. **If it does not, Twist 1 must be redesigned before a
single leaf pool is authored** — this is guardrail 2 in its cheapest possible form.

**Step 1 — the outfit-reachability census** (§5.1). Partition the 1,756 gated `LVLI` into
outfit-reachable and container-only. Pure `reference/` parse. This number decides whether the loot half
is 50 lists or 900, and nothing should be costed until it exists.

**Step 2 — pick the archetype families** that get selectors. Start from `enemy-taxonomy.md`'s
archetype table intersected with `difficulty-map.md`'s tier assignments; anything placed in fewer than
~5 zones does not need seven tiers.

**Step 3 — claim the FormID block.** `/formkey-check`, then one contiguous block per feature per
CLAUDE.md: leaf `LVLN` pools, then leaf `LVLI` pools, then outfits.

**Step 4 — build the smallest end-to-end vertical slice: bandits only.** Selector + 7 leaf pools +
per-tier outfits + the truncated gear lists, for one archetype. Deserialize → `xedit-audit` →
`package-mod` → `mod-deploy` → **launch and walk into a T2 camp and a T5 camp**. Guardrail 6: this is
the only thing that proves the architecture, and it must happen before archetype #2 is authored.

**Step 5 — generate the rest.** Guardrail 3 (*copy records verbatim, never retype hex*): the leaf
pools are mechanical transforms of vanilla records and must be produced by a script, the way
`build-difficulty-map.py` produces the zone map.

**Step 6 — wildlife flattening** (§5), then the ~238 humanoid cells + ~7 wilderness zones.

**Step 7 — SkyPatcher rules** for the `PcLevelMult` actors, plus the rule linter
(`implementation-strategy.md` §8).

---

## 9. The alternative that was considered and not taken

**Pure Requiem — flatten everything, ship no zones, delete the difficulty map.**

In its favour, honestly: it is *simpler*, it needs **no new records at all**, it covers the overworld
for free, it drops the SkyPatcher `cell/` dependency, and it is the only one of the two that is proven
to ship — Requiem has done it for thirteen years.

Against: it deletes `difficulty-map.md`, collapses 355 places into ~8 archetype levels, and makes
reward a property of *what* you fight rather than *where* you are. That is bone 3 by name, and the mod
is called Ehlnofey because places are supposed to have fixed, indifferent laws. A deleveled Skyrim with
no topography of danger is a different mod, and a smaller one.

**It stays on the table** as the fallback if §8 step 0 fails and the selector ladder turns out not to
be buildable.

---

## Sources

`prior-art/requiem/plugin-analysis.md` §§1–5 · `prior-art/requiem/lessons-for-ehlnofey.md` §§2–6 ·
`design/probe-test-protocol.md` §§5, 6, 6.1, 6.3 (the in-game results) ·
`design/implementation-strategy.md` §§6.1, 6.2, 7.1 · `design/loot-model.md` §§1–4 ·
`design/tiers.md` §4 · `design/difficulty-map.md` §7 ·
`reference/Base/{01Skyrim,02Update,03Dawnguard,05Dragonborn}/{LeveledNpcs,LeveledItems}/`
(the §2.1 census, run on this branch).
