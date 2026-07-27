# SKYGEAR

A single-player top-down steampunk hero-defense. You are a sky-pirate captain
defending the deck of your airship; mechanical boarders swarm over the rails in
waves, you fight them off with a hand of magic-industrial skills, and between
waves you draft upgrades that reshape those skills.

Every skill is a **shape** (where the damage lands) crossed with an **element**
(what it does when it gets there), implemented as a real matrix: **9 shapes ×
4 elements**. Cleave is the fixed basic attack and is never offered in a draft,
so **32 combinations are draftable**. Twelve waves, a boss, 37 draft cards.
Keep the Boiler alive.

> Those numbers used to be wrong here, and were wrong on the title screen for
> three versions — "6 × 4 = 24 combinations, 34 cards" survived three shapes and
> three cards being added. The title screen now derives its count from
> `SHAPE_KEYS × ELEMENT_KEYS` rather than printing a string.

## Play

Open `index.html`, or a build directly. **v10 is live.**

| Build | File | What it is |
|---|---|---|
| **v10** | `storm-dusk-v10.html` | the build made for someone who has never seen it: instant start, chosen opening weapon, a results screen, settings, seeded runs |
| **v9** | `storm-dusk-v9.html` | music, and passive skills |
| **v3–v8** | `storm-dusk-v*.html` | the record of how it got here — every shipped build stays playable |
| **Classic** | `classic.html` | straight top-down, daylight brass-and-khaki — the original benchmark |

Every build is a single self-contained HTML file: no build step at runtime, no
dependencies, no network calls. Art and audio load from `assets/` and `audio/`
if they are there, and every one of them has a procedural fallback painted or
synthesised in code, so the game is fully playable with none of them.

`W A S D` move · mouse aim · `LMB` `RMB` skills 1–2 · `Q` `E` skills 3–4 ·
`Space` dash · `1 2 3` pick a draft card · `Esc` pause and settings ·
`F3` frame stats. All of it rebindable in Settings.

Useful query parameters:

| | |
|---|---|
| `?seed=K3F9QZ` | replay an exact run. The seed is printed on the results screen and in the run report. |
| `?assets=0` | procedural art only |
| `?audio=0` | no sample layer, synth only |
| `?pitch=0.72` | camera pitch, also `[` and `]` while playing |

## Layout

```
index.html            landing page / build chooser
classic.html          the original build (hand-written, single file)
storm-dusk-v*.html    generated — edit src/storm-dusk/, never these
assets/               art, by manifest path; anything missing falls back
audio/                delivered SFX and music masters
src/storm-dusk/       engine + renderer sources, and build.py
src/*.py              the asset and audio ingest bridges
tools/                the headless harness, the screenshot tool, the forge driver
docs/                 specs and the plan of record
frames/               the 2011 pitch deck this grew out of
```

## Working on it

```bash
python src/storm-dusk/build.py     # rebuild the live build (only LIVE is written)
npm install                        # once, for the harness
npm test                           # boot, matrix, waves, endings, seed, perf, layout, Firefox
node tools/shots.mjs               # screenshot every screen into .shots/
```

**Shipped builds are frozen.** `build.py` writes only `LIVE` and refuses to
regenerate anything pinned by hash in `FROZEN`. This exists because every build
comes off one shared core, so an engine edit aimed at the current version was
silently re-emitting all the older ones — which is how v2 and v3 ended up
carrying lane code they never ran, and how v4's controls changed months after
anyone played it. If the build reports drift, restore with the git command it
prints rather than forcing past it.

**Never edit a generated `.html`.** Edit `src/storm-dusk/*.js` and rebuild.

Assets are validated on the way in, not discovered in the game:

```bash
python src/optimize-assets.py --check    # every still matches manifest dimensions
python src/check-animations.py           # frame count, uniform size, no net drift
python tools/audio-check.py              # peak, clipping, and runtime rescue per master
```

## Status

v10 is the first build made for a stranger: someone who opens a link, reads
nothing, is on an unknown machine, and leaves the moment it feels broken. The
plan of record is **[docs/V10-PLAN.md](docs/V10-PLAN.md)**; a fresh session
should start at **[docs/START-HERE.md](docs/START-HERE.md)**.

Verified by `npm test` on every build: all 36 shape × element cells execute and
deal damage, twelve waves start and clear, both loss conditions and victory
resolve, restart is clean, a fixed seed reproduces a run, simulation cost with
forty enemies on the deck stays inside budget, every screen fits and no controls
overlap from 1280×720 to 2560×1440 at DPR 1 and 2, the build runs in Firefox as
well as Chromium, and the frozen builds are byte-identical.

**Camera rule, settled: project the deck at 41° (`0.72 rad`), paint billboards
upright at 10–15°.** Do not bake the engine pitch literally into sprites — the
archived 49° set reads pitched over in the lane view. Details in
**[docs/LEVEL-KIT-BRIEF.md](docs/LEVEL-KIT-BRIEF.md)**.
