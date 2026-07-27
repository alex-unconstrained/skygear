# Codex handoff — current state and what to make next

Living status file. Read this first; the other docs are the detail behind it.

**Updated:** 2026-07-26 · **Live build:** `storm-dusk-v6.html` · **Art:** 15 of 67

---

## Where things stand

**You own assets and audio. I own the engine.** Everything you deliver has a
slot already wired and waiting — every entry in the manifest is loaded, measured
and drawn the moment the file exists. Nothing needs an engine change from you,
and nothing you make sits unused.

**Painted art is on by default as of v6.** It used to be behind `?assets=1`,
which meant nothing you delivered was ever visible on the site. That is fixed —
open the live build and you see your work. `?assets=0` forces the all-procedural
look if you want an A/B.

**The title screen shows what actually resolved**, bottom-right:
`v6 · f95527b · 15/67 art`. If that count does not go up after you push files,
something is wrong with a filename or a dimension — check §4 before anything else.

### Standing rules — unchanged, do not relitigate

- **Camera: billboards upright at 10–15° above horizontal. Engine deck at 0.72 rad / 41°.**
  Settled and locked. The archived literal-49° set is comparison-only. Detail in
  `LEVEL-KIT-BRIEF.md`.
- **Dimensions must match the manifest exactly.** `python src/optimize-assets.py --check`
  validates every file against it and is the fastest way to catch a bad export.
- **Crop variance is absorbed.** The loader measures real alpha bounds and derives
  its own feet anchor, horizontal centre and figure height. Aim for consistency,
  but it is not load-bearing.
- **Transparent PNG in engine.** Keep the `_chroma` master beside it as the
  recoverable source; the engine never loads it.

---

## 1 · What changed in v6 that affects your work

| Change | What it means for assets |
|---|---|
| **The basic attack is now the Ember Cleave** — a real 140° sweep swung automatically | `corsair_front_attack.png` is now the *most-seen* frame in the game, not an occasional one. It fires every 0.36 s. Priority 1. |
| **A second cargo-run passage opened forward** | More wall ends are visible at once. The wall module needs to look deliberate when its run stops, not sheared off. |
| **Every push wave now grapples a fresh hulk** (waves 4, 8, 12) | The hulk's three states are all seen in a single run now. Previously the wreck state was reachable only once. |
| **8 lane assets wired into the manifest** | `cargo_wall_module`, 3 crew poses, 3 hulk states, destroyed cannon. Specced in `SKYGEAR_V5_LANE_ASSET_AMENDMENT.md`, now actually loadable. |

### The cargo wall module — engine contract

It is **tiled as billboards**, not stretched. The engine steps down each wall run
and draws one module per step:

- Authored footprint **120 world units wide × 150 deep**, drawn **118 units tall**
- Stepped every 150 units along the run, far to near, painter-sorted
- **Alternate modules are mirrored** so one module does not read as a stamp —
  avoid strongly asymmetric detail unless you accept seeing it flipped
- Registers as an **x-ray occluder**, so it needs a solid readable silhouette
- Runs stop at passages. **Paint the module so a run reading as "cut off" is
  acceptable** — the engine does not have a separate end-cap.

---

## 2 · The gap — 52 files

Generated from the manifest, so it cannot drift. Anything here has a live slot.

### `heroes/` — 1 missing

| file | size |
|---|---|
| `assets/heroes/corsair_front_attack.png` | 512×512 |

### `enemies/` — 7 missing

| file | size |
|---|---|
| `assets/enemies/automaton_front_attack.png` | 512×512 |
| `assets/enemies/colossus_back_idle.png` | 1024×1024 |
| `assets/enemies/colossus_front_attack.png` | 1024×1024 |
| `assets/enemies/colossus_front_idle.png` | 1024×1024 |
| `assets/enemies/drone_front_attack.png` | 448×448 |
| `assets/enemies/furnace_knight_front_attack.png` | 640×640 |
| `assets/enemies/gremlin_front_attack.png` | 384×384 |

### `allies/` — 3 missing

| file | size |
|---|---|
| `assets/allies/crew_back_idle.png` | 384×384 |
| `assets/allies/crew_front_attack.png` | 384×384 |
| `assets/allies/crew_front_idle.png` | 384×384 |

### `props/` — 13 missing

| file | size |
|---|---|
| `assets/props/barrel.png` | 320×384 |
| `assets/props/boarding_hulk_destroyed.png` | 1024×640 |
| `assets/props/boarding_hulk_open.png` | 1024×640 |
| `assets/props/boarding_hulk_sealed.png` | 1024×640 |
| `assets/props/cannon_deck_destroyed.png` | 640×512 |
| `assets/props/cargo_wall_module.png` | 512×512 |
| `assets/props/colossus_wreck.png` | 1024×768 |
| `assets/props/crate_small.png` | 384×384 |
| `assets/props/harpoon_ballista.png` | 640×512 |
| `assets/props/hatch_cargo.png` | 512×384 |
| `assets/props/mast_section.png` | 512×1024 |
| `assets/props/railing_segment.png` | 512×384 |
| `assets/props/rope_coil.png` | 320×256 |

### `env/` — 3 missing

| file | size |
|---|---|
| `assets/env/airship_distant.png` | 512×256 |
| `assets/env/clouds_far.png` | 2048×512 |
| `assets/env/clouds_near.png` | 2048×512 |

### `ground/` — 7 missing

| file | size |
|---|---|
| `assets/ground/decal_gear_scatter.png` | 384×384 |
| `assets/ground/decal_oil.png` | 384×384 |
| `assets/ground/decal_scorch.png` | 384×384 |
| `assets/ground/rune_enemy.png` | 512×512 |
| `assets/ground/rune_enemy_filled.png` | 512×512 |
| `assets/ground/rune_player.png` | 512×512 |
| `assets/ground/shadow_blob.png` | 256×256 |

### `fx/` — 6 missing

| file | size |
|---|---|
| `assets/fx/bolt_tesla.png` | 256×128 |
| `assets/fx/burst_impact.png` | 320×320 |
| `assets/fx/ember_particle.png` | 64×64 |
| `assets/fx/puff_smoke_dark.png` | 256×256 |
| `assets/fx/puff_steam.png` | 256×256 |
| `assets/fx/slash_arc.png` | 384×256 |

### `ui/` — 12 missing

| file | size |
|---|---|
| `assets/ui/frame_hud.png` | 1024×256 |
| `assets/ui/gauge_ring.png` | 256×256 |
| `assets/ui/icon_currency_cog.png` | 128×128 |
| `assets/ui/icon_skill_aoe.png` | 256×256 |
| `assets/ui/icon_skill_barrier.png` | 256×256 |
| `assets/ui/icon_skill_cone.png` | 256×256 |
| `assets/ui/icon_skill_dash.png` | 256×256 |
| `assets/ui/icon_skill_hook.png` | 256×256 |
| `assets/ui/icon_skill_slash.png` | 256×256 |
| `assets/ui/icon_skill_turret.png` | 256×256 |
| `assets/ui/icon_skill_ult.png` | 256×256 |
| `assets/ui/portrait_corsair.png` | 512×512 |

---

## 3 · Priority order

Not the order the manifest lists them. This is by how much each buys.

| # | What | Why now |
|---|---|---|
| **1** | `corsair_front_attack` | The captain swings every 0.36 s and currently snaps to procedural on every swing. Biggest single visual defect in the game. |
| **2** | The 3 crew poses + `cargo_wall_module` | Your own side and the lane structure are wholly procedural, standing next to painted enemies. The mismatch is most visible exactly where the fight is. |
| **3** | The 3 boarding-hulk states | Now seen three times a run, and it is the set-piece. |
| **4** | Remaining `*_front_attack` for enemies | Same snap-to-procedural problem as the captain, less often. |
| **5** | The Colossus (3 files) | Wave 12 only, but it is the finale. |
| **6** | `ground/` — runes, decals, shadow | Telegraphs and AoE markers are read constantly and are pure code today. |
| **7** | `fx/`, `ui/` | Real, but the procedural versions hold up best here. |

---

## 4 · If a file does not appear in-game

In order of likelihood:

1. **Filename mismatch.** Must match the manifest byte for byte, including
   directory. `props/` vs `prop/` will silently fall back.
2. **Dimension mismatch.** Run `python src/optimize-assets.py --check`.
3. **Cached page.** GitHub Pages serves HTML with `max-age=600`. The index links
   the live build with a `?b=<id>` stamp that changes when sources change —
   follow the link from the landing page rather than a bookmarked URL, and check
   the id bottom-right matches.
4. **Fully transparent or near-empty alpha.** The loader measures bounds and will
   treat a near-empty sprite as a failed measure.

Assets are fetched relative to the page, so they must live under `assets/` in
the repo root, committed and pushed. There is no build step for art.

---

## 5 · Audio

Full spec in **`AUDIO-SPEC.md`** — 7 Suno prompts, ~45 ElevenLabs prompts, exact
length budgets, loudness targets and naming.

Two things to know before starting:

- **Length discipline is the main risk.** The cleave swings every 0.36 s. A cast
  sound with a 900 ms tail is mud within two seconds. The per-cue caps in the
  spec are limits, not suggestions.
- **Do not author 24 cast sounds.** The game is a 6 × 4 shape × element matrix.
  Author **6 shape bodies + 4 element tails** and the engine layers them. Ten
  files, twenty-four combinations. §6 of the spec.

I am building the engine side — manifest, loader, buses, positional panning,
voice-stealing caps, music director — against the procedural fallback, so it
will be ready before the files are. You do not need to wait for me and I do not
need to wait for you.

---

## 6 · What I am doing, so we do not collide

- Audio engine plumbing (§9 of `AUDIO-SPEC.md`) — **no asset files touched**
- Balance validation via a headless bot driving the real sim
- Performance measurement as the sprite count climbs toward 67

**I do not edit anything under `assets/`.** The one exception was a one-off
downsample of the archived `assets-49/` comparison set to match manifest
dimensions. If I ever need an asset changed I will ask rather than edit it.

**Do not edit anything under `src/storm-dusk/` or the `*.html` builds.** Shipped
builds are pinned by hash in `build.py` and it will refuse to regenerate them —
that pin exists because previous versions were being silently rewritten.
