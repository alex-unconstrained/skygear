# SKYGEAR

A single-player top-down steampunk hero-defense. You are a sky-pirate captain
defending the deck of your airship; mechanical boarders swarm over the rails in
waves, you fight them off with a hand of magic-industrial skills, and between
waves you draft upgrades that reshape those skills.

Every skill is a **shape** (how it delivers) crossed with an **element** (what it
does) — 6 × 4 = 24 combinations, implemented as a real matrix. Twelve waves,
a boss, 34 draft cards. Keep the Boiler alive.

## Play

Open `index.html`, or either build directly:

| Build | File | Look |
|---|---|---|
| **Storm-Dusk v3** | `storm-dusk-v3.html` | three-quarter, follow camera, long deck, see-through occlusion (newest) |
| **Classic** | `classic.html` | straight top-down, daylight brass-and-khaki (still the benchmark) |
| **Storm-Dusk v2** | `storm-dusk.html` | the first three-quarter attempt — superseded, kept for comparison |

All three are single self-contained HTML files — no build step, no dependencies, no
network calls. Everything (art, audio, data) is generated in code.

`W A S D` move · mouse aim · `LMB`/`RMB` skills 1–2 · `Space`/`Shift` skills 3–4 ·
`E` dash · `Esc` pause · `M` mute · `F3` frame stats

## Layout

```
index.html            landing page / build chooser
classic.html          the original build (hand-written, single file)
storm-dusk.html       the restyled build (generated — edit src/, not this)
assets/               drop point for the visual-spec art, loaded with ?assets=1
src/storm-dusk/       renderer sources + build.py
docs/                 specs, roadmap, restyle notes
frames/               the 2011 pitch deck this grew out of
```

Rebuild the Storm-Dusk build after editing `src/storm-dusk/`:

```
python src/storm-dusk/build.py
```

## Status

Classic is complete against its spec and verified: 24/24 shape×element combos,
34/34 draft cards, a headless run clearing all 12 waves to victory, both loss
conditions. The Storm-Dusk builds run the same simulation under the new
renderer, with procedural stand-ins in place of the 66 art assets.

The first playtest preferred Classic. The cause was occlusion — the Boiler hid
roughly a third of the deck behind it, including the far side of the objective
that boarders attack. **v3** answers that with a see-through pass, a follow
camera, a longer deck and a steeper pitch.

**Camera bake: settled at 40°.** The first four trial assets were judged in
engine and 41° won — the steeper 49° experiment was only ever compensating for
occlusion, which the see-through pass now fixes properly. The remaining 62
assets are unblocked at the briefed angle. Details and the three pipeline
findings are in **[docs/ROADMAP.md](docs/ROADMAP.md)**.

Run with art: `storm-dusk-v3.html?assets=1` (needs a server — browsers block
`file://` image reads). Compare angles live with `?pitch=0.72` or the `[` `]`
keys.
