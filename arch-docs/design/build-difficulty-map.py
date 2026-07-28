#!/usr/bin/env python3
"""
Regenerate the tier assignment tables in difficulty-map.md from reference/.

    python arch-docs/design/build-difficulty-map.py [--check]

Reads  : reference/Base/{01Skyrim,02Update,03Dawnguard,05Dragonborn}/{EncounterZones,Locations,Keywords}
Writes : the block between the GENERATED markers in arch-docs/design/difficulty-map.md
--check: print the distribution and exit without writing.

The pipeline is documented in difficulty-map.md S1 and the ladder in tiers.md S3. To re-calibrate
the whole world, change TIER below and re-run -- that is the promise tiers.md S9 makes.

reference/ is gitignored, so this cannot run in CI. It is a local re-derivation tool.
"""
import os, re, sys, json, collections

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
REF = os.path.join(ROOT, 'reference', 'Base')
DOC = os.path.join(ROOT, 'arch-docs', 'design', 'difficulty-map.md')
# load order matters: later masters override earlier under the same FormKey (CLAUDE.md, last-wins)
PLUGINS = ['01Skyrim', '02Update', '03Dawnguard', '04HearthFire', '05Dragonborn']

# --- the ladder (tiers.md S3). Change these seven numbers to recalibrate the world. -------------
TIER = {1: 4, 2: 8, 3: 14, 4: 21, 5: 30, 6: 40, 7: 50}

# --- step 1: type -> base tier (difficulty-map.md S1.1) ----------------------------------------
TYPE_TIER = {
    'AnimalDen': 1, 'GiantCamp': 1,
    'BanditCamp': 2, 'Shipwreck': 2, 'SprigganGrove': 2, 'Mine': 2, 'OrcStronghold': 2,
    'DraugrCrypt': 3, 'VampireLair': 3, 'WarlockLair': 3, 'MilitaryFort': 3,
    'WerewolfLair': 3, 'WerebearLair': 3,
    'DragonLair': 4, 'ForswornCamp': 4, 'HagravenNest': 4, 'DwarvenAutomatons': 4,
    'FalmerHive': 5, 'DragonPriestLair': 5,
}
SETTLEMENT = {'Dwelling', 'Habitation', 'Town', 'Settlement', 'House', 'Store', 'Jail', 'Guild',
              'Temple', 'Ship', 'Farm', 'Inn', 'Castle', 'Barracks', 'Cemetery', 'LumberMill',
              'MilitaryCamp', 'PlayerHouse', 'Smelter', 'StewardsDwelling'}

# --- step 3: region floor/ceiling (difficulty-map.md S1.3) -------------------------------------
REGION = {
    'WhiterunHoldLocation': (1, 4), 'FalkreathHoldLocation': (1, 5), 'RiftHoldLocation': (1, 5),
    'EastmarchHoldLocation': (1, 5), 'HjaalmarchHoldLocation': (1, 5),
    'HaafingarHoldLocation': (1, 5), 'PaleHoldLocation': (2, 5),
    'WinterholdHoldLocation': (2, 6), 'ReachHoldLocation': (3, 6),
    'DLC2SolstheimLocation': (2, 6),
}
HOLDNAME = {'WhiterunHoldLocation': 'Whiterun', 'FalkreathHoldLocation': 'Falkreath',
            'RiftHoldLocation': 'the Rift', 'EastmarchHoldLocation': 'Eastmarch',
            'HjaalmarchHoldLocation': 'Hjaalmarch', 'HaafingarHoldLocation': 'Haafingar',
            'PaleHoldLocation': 'the Pale', 'WinterholdHoldLocation': 'Winterhold',
            'ReachHoldLocation': 'the Reach', 'DLC2SolstheimLocation': 'Solstheim'}
HOLD_ORDER = ['Whiterun', 'Falkreath', 'the Rift', 'Eastmarch', 'Hjaalmarch', 'Haafingar',
              'the Pale', 'Winterhold', 'the Reach', 'Solstheim', 'Unparented / no hold']

# --- step 4: explicit overrides (difficulty-map.md S3) -----------------------------------------
OVERRIDE = {
    # tutorial corridor -- protection is a LOW TIER, not a ceiling (S3.2)
    'EmbershardMineZone': (1, 'tutorial corridor'),
    'HaltedStreamCampZone': (1, 'tutorial corridor'),
    'WhiteRiverWatchZone': (1, 'tutorial corridor'),
    'BleakFallsBarrowZone': (2, 'tutorial corridor / MQ103'),
    # main quest, re-sequenced (S3.1) -- vanilla runs 6-6-2-16-18-10
    'UstengravZone': (3, 'MQ105'), 'ThalmorEmbassyZone': (3, 'MQ201'),
    'AlftandZone': (4, 'MQ205'), 'BlackreachZone': (5, 'MQ205'),
    'SkuldafnZone': (6, 'MQ303 - vanilla 10 is the anticlimax this fixes'),
    # Dragon Priest lairs and apex Nordic ruins
    'LabyrinthianZone': (6, 'Morokei / MG capstone, NeverResets'),
    'ForelhostZone': (5, 'Rahgot'), 'RagnvaldZone': (5, 'Otar'),
    'ValthumeZone': (5, 'Hevnoraak'), 'HighGateRuinsZone': (5, 'Vokun'),
    'KilkreathRuinsZone': (5, 'Meridia / DA09'),
    # Dawnguard -- untagged regions, named explicitly (S3.3)
    'DLC1_VCDungeonZone': (7, 'Castle Volkihar - the only T7; needs the gate-60 vampire rung'),
    'DLC1_SoulCairnZone': (5, 'Soul Cairn - untagged'),
    'DLC1FalmerValleyZone': (5, 'Forgotten Vale - untagged'),
    'DLC1FalmerValleyTempleZone': (6, 'Vale temple - untagged'),
    'DLC1zFalmerValley01Zone': (5, 'Vale - untagged'),
    'DLC1zFalmerValley02Zone': (5, 'Vale - untagged'),
    'DLC1zFalmerValley03Zone': (5, 'Vale - untagged'),
    'DLC1DarkfallCaveZone': (4, 'Darkfall - untagged'),
    'DLC1DarkfallPassageZone': (5, 'Darkfall - untagged'),
    'DLC1GlacialCreviceZone': (5, 'untagged'), 'DLC1ArkngthamzZone': (4, 'Dwemer'),
    'DLC1RuunvaldZone': (4, ''), 'DLC1DimhollowCryptZone': (3, 'DG entry dungeon'),
    'DLC1MolderingRuinsZone': (3, ''), 'DLC1RedwaterDenZone': (3, ''),
    'DLC1LDBthalftAetheriumForgeZone': (5, ''),
    'DLC1_AncestorsGladeZone': (2, 'non-hostile'), 'DLC1ForebearsHoldoutZone': (3, ''),
    # Dragonborn / Apocrypha -- lore-constraints.md S3 says keep Apocrypha flat
    'DLC2Book01DungeonZone': (6, 'Apocrypha - flat'), 'DLC2Book02DungeonZone': (6, 'Apocrypha - flat'),
    'DLC2Book03DungeonZone': (6, 'Apocrypha - flat'), 'DLC2Book04DungeonZone': (6, 'Apocrypha - flat'),
    'DLC2Book06DungeonZone': (6, 'Apocrypha - flat'), 'DLC2Book07DungeonZone': (6, 'Apocrypha - flat'),
    'DLC2MiscBookLevel1Zone': (6, 'Apocrypha - flat (Book05)'),
    'DLC2DremoraShopZone': (6, 'Apocrypha'),
    'DLC2TempleOfMiraakZone': (6, 'MQ capstone'),
    'DLC2GyldenhulBarrowZone': (6, 'vanilla 40, highest in game'),
    'DLC2KolbjornBarrowZone': (6, 'Ahzidal, fixed 60'), 'DLC2VahlokTombZone': (5, 'Vahlok'),
}

HOLD_KW = '016771:Skyrim.esm'
WORDWALL = '0E7520:Skyrim.esm'


def field(text, name):
    m = re.search(r'^' + name + r':[ \t]*(.*)$', text, re.M)
    return m.group(1).strip() if m else None


def listfield(text, name):
    m = re.search(r'^' + name + r':[ \t]*\n((?:- .*\n?)+)', text, re.M)
    return re.findall(r'- (\S+)', m.group(1)) if m else []


def load():
    kw, loc, ecz = {}, {}, {}
    for plugin in PLUGINS:                      # load order: later assignments win
        base = os.path.join(REF, plugin)
        if not os.path.isdir(base):
            continue
        d = os.path.join(base, 'Keywords')
        if os.path.isdir(d):
            for f in os.listdir(d):
                if ' - ' in f:
                    eid, rest = f.split(' - ', 1)
                    kw[rest.replace('.yaml', '').replace('_', ':')] = eid
        d = os.path.join(base, 'Locations')
        if os.path.isdir(d):
            for f in os.listdir(d):
                t = open(os.path.join(d, f), encoding='utf-8', errors='replace').read()
                fk = field(t, 'FormKey')
                if fk:
                    loc[fk] = {'eid': field(t, 'EditorID'), 'kw': listfield(t, 'Keywords'),
                               'parent': field(t, 'ParentLocation'), 'ww': WORDWALL in t}
        d = os.path.join(base, 'EncounterZones')
        if os.path.isdir(d):
            for f in os.listdir(d):
                t = open(os.path.join(d, f), encoding='utf-8', errors='replace').read()
                fk = field(t, 'FormKey')
                if fk:
                    ecz[fk] = {'eid': field(t, 'EditorID'),
                               'min': int(field(t, 'MinLevel') or 0),
                               'loc': field(t, 'Location'),
                               'flags': field(t, 'Flags') or ''}
    return kw, loc, ecz


def hold_of(fk, loc, depth=0):
    while fk and fk in loc and depth < 12:
        if HOLD_KW in loc[fk]['kw']:
            return loc[fk]['eid']
        fk = loc[fk]['parent']
        depth += 1
    return None


def fallback(minlevel):
    for bound, tier in ((2, 1), (6, 2), (10, 3), (16, 4), (25, 5)):
        if minlevel <= bound:
            return tier
    return 6


def assign(kw, loc, ecz):
    rows = []
    for fk, z in ecz.items():
        lk = loc.get(z['loc']) if z['loc'] else None
        types = [kw.get(k, '').replace('LocType', '') for k in (lk['kw'] if lk else [])
                 if kw.get(k, '').startswith('LocType')]
        types = [t for t in types if t not in ('Clearable', 'Dungeon')]
        real = [t for t in types if t in TYPE_TIER]
        settle = [t for t in types if t in SETTLEMENT]

        bump = clamped = ''
        if z['eid'] in OVERRIDE:                                    # step 4 wins outright
            tier, why = OVERRIDE[z['eid']]
            step = 'explicit'
        elif real:                                                  # step 1
            tier, why, step = max(TYPE_TIER[t] for t in real), ' + '.join(real), 'type'
        elif settle:
            tier, why, step = 2, 'settlement (' + ' '.join(settle) + ')', 'settlement'
        else:
            tier, why, step = fallback(z['min']), \
                f"no LocType - fallback from vanilla min {z['min']}", 'fallback'

        if step in ('type', 'fallback'):                            # step 2: word-wall bump
            if lk and lk['ww'] and tier < 6:
                tier, bump = tier + 1, 'word wall'

        hold = hold_of(z['loc'], loc) if z['loc'] else None
        if step != 'explicit' and hold in REGION:                   # step 3: region clamp
            lo, hi = REGION[hold]
            if tier < lo:
                tier, clamped = lo, f'region floor {lo}'
            elif tier > hi:
                tier, clamped = hi, f'region ceiling {hi}'

        rows.append(dict(fk=fk, eid=z['eid'], min=z['min'], flags=z['flags'], hold=hold,
                         tier=tier, N=TIER[tier], why=why, step=step, bump=bump, clamped=clamped))
    return rows


def render(rows):
    by = collections.defaultdict(list)
    for r in rows:
        by[HOLDNAME.get(r['hold'], 'Unparented / no hold')].append(r)
    out = []
    for h in HOLD_ORDER:
        group = sorted(by.get(h, []), key=lambda r: (-r['tier'], r['eid']))
        if not group:
            continue
        c = collections.Counter(r['tier'] for r in group)
        out.append(f"\n#### {h}  — {len(group)} zones · "
                   + " · ".join(f"T{t}×{c[t]}" for t in sorted(c)))
        out.append("")
        out.append("| Encounter zone | FormKey | van. Min | **Tier** | `N` | Rule |")
        out.append("|---|---|---|---|---|---|")
        for r in group:
            rule = r['why']
            if r['bump']:
                rule += f" +{r['bump']}"
            if r['clamped']:
                rule += f" → {r['clamped']}"
            out.append(f"| `{r['eid']}` | `{r['fk']}` | {r['min'] or '—'} | "
                       f"**T{r['tier']}** | {r['N']} | {rule} |")
    return "\n".join(out)


def main():
    if not os.path.isdir(REF):
        sys.exit(f"reference/ not found at {REF} — it is gitignored; decompile it first "
                 f"(see the spriggit-decompile-reference skill).")
    kw, loc, ecz = load()
    rows = assign(kw, loc, ecz)

    dist = collections.Counter(r['tier'] for r in rows)
    print(f"{len(ecz)} unique zone FormKeys, {len(loc)} locations, {len(kw)} keywords")
    for t in sorted(dist):
        print(f"  T{t} (N={TIER[t]}): {dist[t]}")
    print("  by step:", collections.Counter(r['step'] for r in rows).most_common())
    print(f"  mean vanilla MinLevel {sum(r['min'] for r in rows)/len(rows):.1f}"
          f"  ->  mean N {sum(r['N'] for r in rows)/len(rows):.1f}")
    if '--check' in sys.argv:
        return

    doc = open(DOC, encoding='utf-8').read()
    new = re.sub(r'(<!-- BEGIN GENERATED TABLES -->\n).*?(\n<!-- END GENERATED TABLES -->)',
                 lambda m: m.group(1) + render(rows) + m.group(2), doc, flags=re.S)
    open(DOC, 'w', encoding='utf-8').write(new)
    print(f"wrote {len(rows)} rows into {os.path.relpath(DOC, ROOT)}")


if __name__ == '__main__':
    main()
