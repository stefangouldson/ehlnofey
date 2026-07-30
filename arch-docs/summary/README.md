# summary/ — presentation material

Talk-ready summaries of the design, for audiences who will not read `arch-docs/design/`.

| File | What it is |
|---|---|
| `ehlnofey-tier-ladders.pptx` | 16-slide deck on the tier ladders. **Generated — do not hand-edit.** |
| `build-deck.py` | The generator. Edit this, then re-run. |

## The deck

**Audience: no Skyrim modding knowledge at all.** Every mechanic is built up from scratch and the
deck never uses a term it has not defined on an earlier slide — "leveled list" is introduced as *a
menu*, "gate" as *the number that hides a row*. Keep that constraint if you edit it.

Running order: the problem (1–3) → the three rules (4) → how spawning actually works (5–6) → the
ladder and where its numbers come from (7–8) → why tiers moved onto creatures (9–10) → bandits
worked end to end (11–12) → wildlife (13) → costs and status (14–16).

Slide 12 is the one worth rehearsing: it is the naming test from `design/archetype-tiers.md` §3.1.1,
and it is the only slide that reports an open decision rather than a settled one.

## Rebuilding

```
pip install python-pptx
python build-deck.py
```

`python-pptx` is the only dependency and it is **not** part of the plugin toolchain — nothing in
`build/build.ps1` or `.claude/config/tools.json` needs it. A throwaway venv is fine.

## Target renderer is LibreOffice Impress

The deck is presented from Impress, not PowerPoint, so `build-deck.py` avoids everything the two
render differently: no SmartArt, no gradients, no shadows, no theme colours, and **no table styles**
— the generator strips the `tableStyleId` element and colours every cell individually, because
otherwise Impress paints its own borders over the design.

Two layout rules learned the hard way, both of which produce text spilling *outside* its panel with
no warning at build time:

- **Neither tool auto-fits text**, and python-pptx will not tell you a run overflowed its shape.
  `card()` reserves a fixed 0.36" for the heading; a heading that wraps to two lines lands on top of
  the body. Keep card headings short enough not to wrap at their column width.
- **Impress honours requested row heights closely but not exactly.** A table sized to end flush
  against a following element will overlap it. Leave ~0.15" of slack.

Verify by rendering, never by reading the code:

```
soffice --headless --convert-to pdf --outdir <tmp> ehlnofey-tier-ladders.pptx
```

then page through the PDF. Every layout bug found so far was invisible in the source and obvious in
the render.

## Sources

Figures are lifted from, and should be kept in step with:

- `design/tiers.md` §3 — the T1–T7 ladder and why the steps widen
- `design/archetype-tiers.md` §3.1 — the bandit roster; §3.1.1 — the naming test; §4.1.2 — biomes
- `design/requiem-method.md` §2 — the encounter-zone measurements behind the pivot
- `CLAUDE.md` "Current phase" — the record counts on the status slide
