> ## THE GODOT GAME HAS MOVED (2026-08-14)
>
> Active development is in **`../skygear-godot`** now — a clean repo carrying the
> Godot project, its tools and its three ledgers, without the browser build or the
> 15.8 GB of derived captures, exports and caches. Verified by a cold import and a
> full harness run there: 1315/1315.
>
> **THIS REPO IS NOT DELETED AND SHOULD NOT BE.** It keeps the browser build, and
> it keeps every commit hash that `BOARD-ARCHIVE.md` and the night logs cite —
> those resolve HERE and nowhere else. Read it, do not work in it.

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

Open `index.html`. **v11 is live, and it is the only build the landing page
offers** — every earlier one moved to `archive.html`, still playable, pinned at
the bytes it shipped with.

| Build | File | What it is |
|---|---|---|
| **v11** | `storm-dusk-v11.html` | the deck fights back: steam kegs that detonate, a pressure gauge that vents and heals, close-range healing, a wider deck, two dashes, readable enemy fire |
| **v10** | `storm-dusk-v10.html` | the build made for someone who has never seen it: instant start, chosen opening weapon, a results screen, settings, seeded runs |
| **v9** | `storm-dusk-v9.html` | music, and passive skills |
| **v2–v8** | `storm-dusk*.html` | the record of how it got here — every shipped build stays playable |
| **Classic** | `classic.html` | straight top-down, daylight brass-and-khaki — the original benchmark |

Every build is a single self-contained HTML file: no build step at runtime, no
dependencies, no network calls. Art and audio load from `assets/` and `audio/`
if they are there, and every one of them has a procedural fallback painted or
synthesised in code, so the game is fully playable with none of them.

`W A S D` move · mouse aim · `LMB` `RMB` skills 1–2 · `Q` `E` skills 3–4 ·
`Space` dash (two charges, and it lights kegs) · `1 2 3` pick a draft card ·
`Esc` pause and settings · `F3` frame stats. All of it rebindable in Settings.

Useful query parameters:

| | |
|---|---|
| `?seed=K3F9QZ` | replay an exact run. The seed is printed on the results screen and in the run report. |
| `?assets=0` | procedural art only |
| `?audio=0` | no sample layer, synth only |
| `?pitch=0.72` | camera pitch, also `[` and `]` while playing |

## Layout

```
index.html            landing page — the live build, and nothing else
archive.html          every earlier build, kept playable
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

**Development is now fully focused on the Godot port in
[`skygear-godot/`](skygear-godot/).** A fresh session starts at
**[skygear-godot/STATUS.md](skygear-godot/STATUS.md)**, then
**[skygear-godot/docs/OUTSTANDING.md](skygear-godot/docs/OUTSTANDING.md)** —
the ledger of what was asked for and whether it is done. The port is playable
end to end (twelve waves, two classes, a draft, persistent progression), holds
437 harness checks, and build 31 is on itch at
<https://alex-unconstrained.itch.io/skygear-godot-test>.

The browser build below is **frozen as the reference target** — v11 stays live
and playable, and everything else in this README describes it. Its own record:
v10 was the first build made for a stranger, and a stranger played it. What they
said is the whole of v11: healing scaled with damage and not with risk, so the
run had no fail state; the deck was full of kegs that did nothing; and you could
not see what was being shot at you. The browser plan of record was
**[docs/V11-PLAN.md](docs/V11-PLAN.md)**, superseded by
**[docs/V12-PLAN.md](docs/V12-PLAN.md)**, whose Godot spike proposal became the
port.

Verified by `npm test` on every build — 53 checks: all 36 shape × element cells
execute and deal damage, twelve waves start and clear, both loss conditions and
victory resolve, restart is clean, a fixed seed reproduces a run, every
destructible prop can be destroyed by a shape, a dash and enemy fire, a keg
lights a fuse rather than detonating and chains to the next one, the deck is
re-stowed between waves, pressure builds only inside your own reach and the vent
cannot refill itself, healing from damage is capped per second, simulation cost
with forty enemies stays inside budget, every screen fits and no controls
overlap from 1280×720 to 2560×1440 at DPR 1 and 2, the build runs in Firefox as
well as Chromium, and the frozen builds are byte-identical.

**Camera rule, settled: project the deck at 41° (`0.72 rad`), paint billboards
upright at 10–15°.** Do not bake the engine pitch literally into sprites — the
archived 49° set reads pitched over in the lane view. Details in
**[docs/LEVEL-KIT-BRIEF.md](docs/LEVEL-KIT-BRIEF.md)**.
