# The Requiem method, with Ehlnofey's twists — Phase 4 architecture

**Status: DECIDED (2026-07-29), on branch `design/requiem-method`.** This supersedes
`implementation-strategy.md` §1's zone-first hybrid. Nothing in `src/` has changed yet.

Read first: `prior-art/requiem/plugin-analysis.md` (what Requiem actually does),
`probe-test-protocol.md` §§5–6 (what we measured in-game), `implementation-strategy.md` §6 (the
overworld census).

---

## 1. The decision

> **Delevel by flattening the leveled lists, as Requiem does — not by clamping encounter zones.**
> Difficulty becomes a property of the **archetype**, fixed once and legible from its name.
> Encounter zones survive in one role only: **container loot**, the one thing they are verified to
> govern and the one place bone 3 still lives.

| Layer | Mechanism | Scales with player? |
|---|---|---|
| **Actors** — who spawns | flatten the 269 gated `LVLN` to fixed rosters | **no** — anywhere, including the overworld |
| **Worn gear** — what they carry | truncate/flatten the outfit-reachable `LVLI` | **no** |
| **Container loot** — chests, urns, hoards | **keep vanilla gating + the 355 zone bands** | **no** — verified, zone-bound |
| **NPC levels** | all `PcLevelMult` → fixed, **followers included** | **no** |

Four moves, one exception, and the exception is the twist that keeps the mod's name honest.

---

## 2. Why — the evidence for the pivot

### 2.1 Encounter zones govern 0.3% of the outdoors

`[verified]`, `implementation-strategy.md` §6.1, full scan of the Tamriel worldspace:

| | count |
|---|---|
| Tamriel exterior cell files | 12,148 |
| …carrying an `EncounterZone` | **40 (0.3%)** |
| unzoned leveled actor refs | **3,512** vs 367 zoned |

A zone-first design governs interiors and almost nothing else. The remedy §6 proposed — flatten 65
lists, bolt zones onto 238 cells — is already half Requiem's method. Doing it everywhere is simpler
than doing it in one population and clamping in the other.

### 2.2 Worn gear scales with the player, and no zone can reach it

The probe separated the two loot tracks and they came back **opposite** `[verified]`:

| Track | Resolves against | Evidence |
|---|---|---|
| **Containers** | **the zone** ✅ | Test 3. Bleak Falls pinned to 4, player 45: vanilla arm gave a **glass dagger**; with `fSpecialLootMinPCLevelMult = 0` the same chest gave low-tier loot, **identical at player 1 and 45** |
| **NPC-worn gear** | **the player** ❌ | Test 2b. The Swindler's Den chief was **level 28 in both runs** but wore **iron at player 5, Nordic at player 45** |

There is no zone operand anywhere on an outfit's material list (`probe-test-protocol.md` §6.1,
mechanism traced end to end). Flattening the list is the only fix, and flattening the list is
Requiem's method.

**This kills `loot-model.md` §1's headline** — *"the tier ladder IS the material ladder, no truncation
pass needed"* — and with it the claim that bone 3 falls out of the difficulty map for free.

### 2.3 What the pivot costs, measured on this branch

Stated plainly, because it is real and it was not free. **Vanilla's dungeon rosters vary by *role*,
not by *tier*.** Census of all `Skyrim.esm` interior cells, resolving `PlacedNpc` bases through the
filename index `[verified]`, this branch:

| | |
|---|---|
| interior cells with placed NPCs | 498 |
| …placing leveled bases | 182 |
| distinct leveled bases in the vocabulary | 207 |
| distinct roster-sets across those 182 cells | **172** |

172 near-unique rosters looks like place topography — but the vocabulary says otherwise. The entire
draugr vocabulary is **role-shaped**: `Melee1H` · `Melee2H` · `Missile` · `Warlock` · `Berserker` ·
`Defender` · `Ambush` · `Boss` · male/female · helmet/no-helmet. There is no `LvlDraugrElite`, no
tier axis at all. **All tier information lives in the `LChar*` gate ladder — precisely what
flattening deletes.**

So under this architecture Bleak Falls Barrow and Volunruud get the same draugr. They differ in
*role mix*, not in danger. That is the price, it is paid knowingly, and §4.1–§4.2 are how it is
partly bought back.

### 2.4 Why the price cannot simply be bought back with rules

The obvious rescue is to fork each list per tier and repoint the placed references. SkyPatcher's
`reference/` module looked like the lever. **It is not, and the reason is in its source.**

`reference.cpp:15–19` exposes exactly three keys — `filterByRefs`, `filterByRefsExcluded`,
`replaceBaseObject`, `disable`. The swap is applied from a `Load3DREFR` hook
(`main.cpp:938–977`) `[verified]`:

```cpp
SKSE::GetTaskInterface()->AddTask([a_this, boundobj]() {
    if (a_this) {
        a_this->SetObjectReference(boundobj);
        a_this->Enable(false);          // ← force-enables the reference
    }
});
```

Two disqualifying problems for mass use:

1. **It force-enables every ref it touches.** Vanilla disables spawns deliberately and re-enables
   them through quest enable-parents — the four Ustengrav bandits in `probe-test-protocol.md` §4 are
   parented to `MQ105EnableDungeonMarker`. Applied to thousands of refs this turns on content the
   player has not unlocked.
2. **It fires at 3D load, not at reference init**, so whether it re-rolls a leveled actor at all is
   `[unverified]` and structurally doubtful — the list is resolved long before.

There is also no filter but the FormID list, so all ~2,147 LVLN-backed interior refs plus 3,512
overworld refs would need enumerating. **Repointing placed refs is therefore a plugin `ACHR` job or
nothing** — thousands of overrides with a heavy conflict surface, which is the option A ceiling this
project has rejected since Phase 2.

Conclusion: **archetype-level difficulty is not a shortcut, it is the architecture.** Plan around it
rather than budgeting to undo it.

### 2.5 What is *not* wrong with the design being replaced

Three of the four gating tests passed, and the parts they validated are kept in §4.1 rather than
discarded:

- **Test 2a passed outright.** Swindler's Den pinned to 30, observed at player 5 **and** 45,
  **identical both times** — levels 1 / 5 / 9 / 19 / 28. `[verified]`
- **Test 1 passed.** `LevelModifier: None` honours the zone. Zero records to fix.
- **Test 3 passed.** Zeroing the PC floor zone-locks special loot instead of disabling it.

---

## 3. The four moves, as Requiem does them

All `[verified]` in `prior-art/requiem/plugin-analysis.md`:

1. **Flatten the `LVLN` gate, keep the pool.** All 328 vanilla lists Requiem overrides become
   single-gate; 518 of 571 gate at `Level: 1`. Entry count only falls to **81.6%** of vanilla, so the
   list stops being a ladder and becomes a uniform random draw over variants.
   `LCharDraugrBoss`: 13 entries across 7 gates → **one entry**.
2. **Same for `LVLI`.** 2,034 of 2,125 overrides single-gate; only **5 live lists** keep any player
   gating at all.
3. **Convert `PcLevelMult` → fixed.** 261 converted. (Requiem retains 68; Ehlnofey does not — §4.3.)
4. **Do not use encounter zones for actors.** 8 records out of 358, none for levelling. Once the
   lists are flat there is nothing left for a zone to clamp.

### 3.1 The job, sized in our own decompile

Base + Dawnguard + Dragonborn, Hearthfire excluded per `difficulty-map.md` scope. "Real gate" = more
than one *distinct* entry `Level` on the record — CLAUDE.md's *count the entries, not the flag* rule.
`[verified]`, this branch:

| | records | **real-gated** | entries | entries in gated lists |
|---|---|---|---|---|
| `LeveledNpcs` | 681 | **269** | 4,022 | 1,836 |
| `LeveledItems` | 3,824 | **1,756** | 25,438 | 13,325 |

**269 `LVLN` is the actor job in full.** The 1,756 `LVLI` is a *ceiling*, not a target — see §5.1.

---

## 4. Ehlnofey's twists

### 4.1 Twist 1 — keep the 355 zones, for container loot only

Requiem drops encounter zones because they are inert once actor lists are flat. **They are not inert
for containers**, and test 3 is our own primary-source proof of it.

So Ehlnofey keeps the zone half of `implementation-strategy.md` §2 exactly as specified — the 355
`MinLevel == MaxLevel` bands from `difficulty-map.md` §7, plus `fSpecialLootMinPCLevelMult = 0` —
and **leaves container leveled-item lists gated**. The result:

```
actors   :  flat list           → fixed by ARCHETYPE, everywhere, no zone needed
worn gear:  flat list           → fixed by ARCHETYPE
containers: gated list + zone   → fixed by PLACE        ← bone 3 lives here
```

Why this is the right asymmetry:

- **It is free.** The zones are already specified and generated; `build-difficulty-map.py` needs no
  change. `difficulty-map.md` stops being dead work.
- **It is verified**, which is more than can be said for any alternative bone-3 mechanism.
- **Containers are where "reward follows place" is actually legible to a player.** A Nordic tomb's
  boss chest is the thing you remember; the exact tier of the third draugr in a corridor is not.
- **The overworld objection does not apply.** Unzoned exterior containers are a rounding error next
  to unzoned exterior *actors*, which this architecture fixes by flattening anyway.

**Consequence to accept:** `fLeveledActorMult*` (Easy/Medium/Hard/VeryHard, `tiers.md` §4) becomes
**inert for actors** — the modifier multiplies a leveled-list lookup level, and flat lists have
nothing to look up. Those two GMST overrides are **dropped from the plugin**. Vanilla's hand-tuning
layer on 5,685 placed actors is a casualty of flattening; that is Requiem's trade too.

### 4.2 Twist 2 — the tier ladder moves from places to archetypes, and the lore already wrote it

`tiers.md`'s **T1–T7 = 4 / 8 / 14 / 21 / 30 / 40 / 50** survives intact. What changes is what it
indexes: **a creature family's rung, not a dungeon's.**

This is the one place the pivot makes the mod *more* legible, not less, and `lore-constraints.md`
already identified the mechanism: **vanilla's display names are a lore-ordered power hierarchy.**

| Family | The ladder vanilla already ships |
|---|---|
| Draugr | Draugr → Restless Draugr → Wight → Scourge → Deathlord |
| Dremora | Churl → Caitiff → Kynval → Kynreeve → Markynaz → Valkynaz |

Under the zone architecture those names were only *correlated* with power — the player met a Wight
because a zone was tier 4. **Under flattening the name becomes the fact.** A Draugr Scourge is
level 30 in Bleak Falls Barrow, in Labyrinthian, and in a random barrow at the edge of the map,
forever. Bone 2 (*danger is legible*) is served by the enemy's name rather than by the dungeon's, and
a name travels with the enemy in a way a zone never did.

**Authoring rule:** every flattened `LVLN` leaf is assigned a tier, and the tier must agree with the
display name of everything in the pool. Where vanilla's ladder has more rungs than the pool needs,
collapse; where a name implies a rung the pool does not hold, the pool is wrong. `lore-constraints.md`
is the arbiter, not convenience.

### 4.3 Twist 3 — followers are deleveled too, at hand-set lore levels

Requiem retains 68 `PcLevelMult` NPCs, almost all followers, housecarls and hirelings. **Ehlnofey does
not take that exception.** Bone 1 applies literally: nothing in the world scales, and a companion is
in the world.

This is a real departure and it has a real consequence — a follower fixed at 30 trivialises the early
game, and one fixed at 15 is dead weight late. **Turn that into the design rather than absorbing it:**

- Set each follower's level from **role and lore**, not from balance. A Whiterun housecarl is a
  competent hold soldier; Aela is a veteran of the Companions; Marcurio is a working mage for hire.
- **Choosing a follower becomes a decision with consequences** — an early-game character genuinely
  benefits from a strong companion, and outgrows them. That is the same "fixed world, legible
  danger" contract applied to allies.
- The roster is small and already enumerated: `prior-art/requiem/plugin-analysis.md` §1a lists the
  68 by name. Use it as the work list, then invert the verdict.

Everything else in the `PcLevelMult` population (~454 actors: guards, soldiers, hunters, Nightingales,
`WE*` adventurers) converts by **SkyPatcher rule**, not by override — `filterByPCLevelMult=true` is a
predicate that also catches NPCs from other mods and future patches, where 454 overrides would only
be a snapshot. That argument from `implementation-strategy.md` §4 is unaffected by the pivot and
stands. The follower set is the part done by hand, because hand-set levels are the point.

### 4.4 Twist 4 — adopt Requiem's three record conventions now

Free, pure record technique, no patcher (`prior-art/requiem/lessons-for-ehlnofey.md` §4):

| Convention | Use |
|---|---|
| **`Level: 9999`** | disable an entry in place. It stays in the record so diffs and merges still see it, but can never roll. Better than deletion for the truncation pass |
| **`EHL_NULL_` rename** | retire a record without deleting it — deletion breaks every reference. Requiem has 197 such `LVLI`, 63 `LVLN` |
| **`Count` as a weight** | Skyrim has no weight field, and a flat pool makes every variant equally likely. `Count: 5` with `CalculateForEachItemInCount` is the workaround |

The third is not optional here. **Flattening costs variety** — Requiem had to build a whole actor
variation generator to pay it back. Weighting is how a flattened bandit pool stays mostly grunts with
the occasional chief instead of a coin flip. Budget for it in the first archetype, not the last.

---

## 5. Scope control — the 2,025-list ceiling is not the target

### 5.1 The census that has to happen before anything is costed

Under Twist 1, **container-only lists keep their gates and need no edit.** Only lists reachable from
an **outfit or an NPC `Items:` block** are broken. Nobody has measured that split.

**Deliverable, step 1:** partition the 1,756 gated `LVLI` into *outfit-reachable* and
*container-only*. Pure `reference/` parse, no game launch. This single number decides whether the
loot half is ~50 lists or ~900, and **nothing downstream should be estimated until it exists.**

Expect it to be small. The Swindler's Den trace (`probe-test-protocol.md` §6.1) found the whole
bandit-chief wardrobe reached through **five** lists — `LItemBanditCuirass` `037C22`,
`LItemBanditBoots` `037C23`, `LItemBanditGauntlets50` `037C25`, `LItemBanditShield20` `0C0196`,
plus the already-flat `LItemBanditWeapon1H` `037C1B` — and `BanditArmorMeleeShield20Outfit`
(`0C0197`) is shared by **90 NPCs** `[verified]`. Sharing cuts both ways: it is why vanilla tiers
leak, and it is why the fix is cheap.

### 5.2 Two more subtractions

- **The 23 already-flat overworld lists** need nothing — `LCharSoldierImperial`, `LCharSoldierSons`
  (all 943 Civil War refs) and `LCharAmbientCreatures` (623 refs). The single biggest block of
  overworld actors was never a scaling problem `[verified]`.
- **Biome partitioning is already done.** `LCharAnimalForestPredator`, `…MountainSnowPredator`,
  `…CoastSnowPredator`, `LCharAnimalHills`, `LCharMudcrab` (209 refs) and kin already split wildlife
  by biome, so flattening each list *in place* yields fixed **and** regionally varied wildlife with
  zero new records `[verified]`. This is the population where Requiem's method is strictly better
  than the zone architecture, and it retires §6.4's 238-cell bolt-on for the wildlife half outright.

---

## 6. Order of work

**Step 1 — the outfit-reachability census** (§5.1). Nothing is authored or costed before this.

**Step 2 — assign every archetype family its tier** (§4.2), from `enemy-taxonomy.md`'s archetype table
cross-checked against `lore-constraints.md`'s name hierarchy. This is the design work the pivot
creates, and it replaces `difficulty-map.md`'s role for actors. Output: a table, reviewed, before a
record is touched.

**Step 3 — delete `src/ExampleMod/` and `src/EhlnofeyProbe/`.** Both are marked throwaway; the probe
has served its purpose.

**Step 4 — scaffold `Ehlnofey.esp`** via `mod-new-plugin`. Masters `Skyrim.esm`, `Update.esm`,
`Dawnguard.esm`, `Dragonborn.esm`; ESL-flagged.

**Step 5 — the constants.** `fSpecialLootMinPCLevelMult = 0`, the 12 `LevelGate*` globals → 1, the 6
named records. Smallest slice verifiable end-to-end: deserialize → `xedit-audit` → `package-mod` →
`mod-deploy` → launch. Proves the pipeline before volume rides on it. **Note the two
`fLeveledActorMult*` overrides are dropped** (§4.1).

**Step 6 — the 355 zones**, generated from `difficulty-map.md` as already planned. They now serve
container loot only, but nothing about the records or the generator changes.

**Step 7 — one archetype, end to end: bandits.** Flatten its `LVLN` leaves, truncate its five gear
lists, weight the pools. Then **launch and walk into two different bandit camps at player 5 and
player 45**. Guardrail 6: this is the only thing that proves the architecture. Do not author
archetype #2 until a character has been correctly killed by archetype #1.

**Step 8 — generate the rest.** Guardrail 3 (*copy records verbatim, never retype hex*): flattening
is a mechanical transform of vanilla records and must be produced by a script, the way
`build-difficulty-map.py` produces the zone map.

**Step 9 — followers by hand** (§4.3), then the SkyPatcher `npc/` rules for the remaining ~454
`PcLevelMult` actors, then the rule linter (`implementation-strategy.md` §8).

---

## 7. What this supersedes

| Document | Effect |
|---|---|
| `implementation-strategy.md` §1 | ❌ the zone-first hybrid is replaced. §§2.2–2.4, §4, §8 survive |
| `implementation-strategy.md` §2.1 (355 zones) | ✅ **kept**, re-purposed to container loot (§4.1) |
| `implementation-strategy.md` §2.2 (`fLeveledActorMult*`) | ❌ **dropped** — inert once lists are flat |
| `implementation-strategy.md` §6 (overworld) | ⚠️ wildlife half **superseded** by §5.2; humanoid half moot — flattening covers it |
| `loot-model.md` §1 "no truncation pass needed" | ❌ **dead** (§2.2) |
| `difficulty-map.md` §7 (the 355 assignments) | ✅ **kept in full** — now the loot map |
| `tiers.md` T1–T7 ladder | ✅ **kept**, re-indexed from places to archetypes (§4.2) |
| `lessons-for-ehlnofey.md` §5 (ally exception) | ❌ **explicitly rejected** (§4.3) |
| Requiem's `fDiffMult*` → 1.0 | ❌ **not adopted** — removing the player's difficulty slider is out of scope for a mod that is not a combat overhaul |
| CLAUDE.md *Implementation strategy* + *Current phase* | needs rewriting once this lands |

---

## 8. Open risks

1. **Variety collapse.** The measured cost of flattening is that every draw becomes identical.
   Requiem's entry count held at 81.6%, but it also built a generator to restore variation. Twist 4's
   weighting is the mitigation; whether it is sufficient is only answerable in-game at step 7.
2. **Archetype tiering is curation, not an algorithm.** `Changelog.md` is 2,491 lines of one-off
   delevels and Requiem *still* leaves 114 NPCs scaling after thirteen years. Plan for a long tail and
   a coverage-audit script; do not plan for a clean sweep.
3. **Container gating assumes zone-bound resolution holds for ordinary chests**, not just the
   `SpecialLoot`-flagged boss roll that test 3 exercised. `[community]`, worth one cheap confirmation
   at step 6 — open an ordinary urn in a pinned zone at two player levels.
4. **Deleveled followers are untested as a design.** §4.3 argues it is a feature; nobody has played
   it. Revisit after step 9 with actual play, and treat reverting to Requiem's exception as a live
   option rather than a defeat.

---

## Sources

`prior-art/requiem/plugin-analysis.md` §§1–5 · `prior-art/requiem/lessons-for-ehlnofey.md` §§2–6 ·
`prior-art/skypatcher.md` §§2, 4.2, 5 · `design/probe-test-protocol.md` §§4, 5, 6, 6.1 (in-game
results) · `design/implementation-strategy.md` §§2, 4, 6, 7.1 · `design/loot-model.md` §§1–4 ·
`design/tiers.md` §4 · `design/difficulty-map.md` §7 · `world/lore-constraints.md` ·
`reference/mods/SkyPatcherSrc/reference.cpp`, `main.cpp:938–977` (§2.4, read this branch) ·
`reference/Base/01Skyrim/Cells/` (§2.3 roster census, run this branch) ·
`reference/Base/{01Skyrim,02Update,03Dawnguard,05Dragonborn}/{LeveledNpcs,LeveledItems}/` (§3.1).
