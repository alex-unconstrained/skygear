# SKYGEAR — Storm-Dusk (Cinderia-style fork)

A fork of `../skygear.html` rebuilt against **`skygear-visual-asset-spec-v1.md`**.

Open `skygear.html` — it plays immediately, with no assets and no server.

---

## What changed

Everything in the spec that is **code** is done. The simulation is unchanged:
same 6 shapes × 4 elements, same 12 waves, same 34 draft cards, same boss.
What was rewritten is the presentation layer.

| Spec | Status |
|---|---|
| §2 · high three-quarter pinhole camera, pitch 0.72 rad, fixed yaw | done — `CAM.project()` |
| §2 · billboard sprites, depth-scaled, painter-sorted far → near | done |
| §2.2 · two facings per character, mirrored in code | done — `viewFor()` |
| §2.3 · static poses only, all animation code-side | done — bob, tilt, flash, squash |
| §2.4 · feet on the bottom-center anchor, engine draws the shadow | done — `ANCHOR`, `entityShadow()` |
| §2.5 · ground-flat art authored as circles, squashed to ellipses | done — `groundEllipsePath()`, `CAM.squash()` |
| §2.6 · deck code-drawn as projected quads, no ground texture | done — `buildDeck()` |
| §2.7 · sky / clouds / envelope as flat screen-space parallax | done |
| §2.9 · numbers, cones and beam telegraphs code-rendered | done — crits are `#FFD52E` with `!!` |
| §1.3 · storm-dusk palette | done — `PAL` |
| §1.2 · two-source lighting on every asset | done — `applyTwoSourceLight()` |
| §4 · 66 image assets | **pending art** — see below |

### The ported simulation needed almost no changes

The original game already ran on a flat 2D plane. Reinterpreting its `y` as
**depth** made the entire simulation — movement, collision, spawn points, AI,
all six skill geometries — correct in a projected view with no edits. The only
adaptations were the deck's proportions (long and narrow, like a ship) and
reading particle/damage-number motion as *height* rather than depth, so gibs
arc up and fall instead of drifting toward the camera.

### Element colours mapped onto the §1.3 "pop" palette

| Element | Was | Now |
|---|---|---|
| `EMBER` | `#E2691E` | `#FF7A2F` core `#FFE08A` (fire) |
| `FROST` | `#7FC7D9` | `#37F0C8` (aether-teal) |
| `ARC` | `#F2D14B` | `#7ADCFF` core `#FFFFFF` (tesla) |
| `STEAM` | `#B9A8C9` | `#C9B6E8` (pale violet) |

`#C77DFF` is reserved for pickups and `#FF3D2E` for enemy telegraphs, per §1.3.

---

## Dropping in the real art

Every asset in §4 already has a manifest entry and a call site. Put the PNGs at
their spec paths under `assets/` and turn loading on:

```
skygear.html?assets=1
```

Anything missing keeps its procedural stand-in, so you can land the art
**one file at a time** and watch each one replace its placeholder.

Loading is opt-in for two reasons: an asset-less checkout has a clean console,
and browsers block `file://` image reads — so once real PNGs are in place the
page needs to be served over http (`python -m http.server`), while the
procedural build needs nothing at all.

### Roster mapping (§6.1 — flavour swapped, structure kept)

| Spec archetype | SKYGEAR type | Files |
|---|---|---|
| H1 Sky-Corsair | player | `heroes/corsair_*` |
| E1 Boarding Automaton | `SCRAPPER` | `enemies/automaton_*` |
| E2 Cog-Gremlin | `SWARM` | `enemies/gremlin_*` |
| E3 Tesla Drone | `GUNNER` | `enemies/drone_*` |
| E4 Furnace Knight | `ARMORED` | `enemies/furnace_knight_*` |
| E6 Brass Colossus | `BOSS` | `enemies/colossus_*` |

E5 Rigging Wraith has no gameplay counterpart yet — add an entry to `ENEMIES`
and a wave batch and it will render with no renderer changes.

The six skill shapes map onto the spec's icon set as:
`CLOSEHIT → slash`, `LINE_BURST → hook`, `CONE → cone`, `RANGED_AOE → aoe`,
`CHAIN → ult`, `RAY → turret`.

---

## Building

`skygear.html` is generated — edit the parts, not the output:

```
python build.py
```

| File | Contents |
|---|---|
| `_core_patched.js` | the ported simulation (tuning, data, engine, systems, loop) |
| `_render_head.js` | camera, projection, ground-shape helpers, sprite caches |
| `_render_assets.js` | the §4 manifest and loader |
| `_render_chars.js` | procedural chibi billboard painters |
| `_render_world.js` | sky, clouds, envelope, bow, the baked deck |
| `_render_entities.js` | billboards, shadows, telegraphs, props |
| `_render_fx_hud.js` | skill VFX, particles, damage numbers |
| `_render_hud.js` | gauge-plate HUD |
| `_render_screens.js` | draft, title, pause, endings, `render()`, boot |

`_core_extracted.js` is the untouched slice taken from the parent game, kept so
the patch applied to it stays visible.

## Controls

`WASD` move · mouse aim · `LMB`/`RMB` skills 1–2 · `Space`/`Shift` skills 3–4 ·
`E` dash · `Esc` pause · `M` mute · `−`/`=` volume · `F3` frame stats
