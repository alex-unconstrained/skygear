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
| **Storm-Dusk** | `storm-dusk.html` | three-quarter camera, dark painted world (current direction) |
| **Classic** | `classic.html` | straight top-down, daylight brass-and-khaki (control) |

Both are single self-contained HTML files — no build step, no dependencies, no
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
conditions. Storm-Dusk is the same simulation under the new renderer, with
procedural stand-ins in place of the 66 art assets.

See **[docs/ROADMAP.md](docs/ROADMAP.md)** for the path to a testable MVP and the
open risks — the frame rate at full crowd is the one genuinely unresolved item.
