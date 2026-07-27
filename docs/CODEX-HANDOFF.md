# Codex handoff — current state and what to make next

Living status file. Read this first; the other docs are the detail behind it.

**Updated:** 2026-07-26 · **Live build:** `storm-dusk-v7.html` · **Art:** 15 of 67 · **Audio:** 5 cues of 55

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

## 4b · Audio delivery — how files get in

Different from art, and the difference matters. The loader cannot guess: probing
every manifest entry would mean a request and a 404 for every cue nobody has
made. So delivered audio is named in a generated index, and the step that copies
files also writes it:

```
python src/ingest-audio.py --check     # validate, touch nothing
python src/ingest-audio.py             # copy into audio/, write the index
python src/storm-dusk/build.py         # fold into the live build
```

Drop masters anywhere under the staging folder (`C:/Users/alexr/Dev/skygear-audio/out`
by default, `--from` to override) in the manifest's directory layout. The script
matches by path against `AUDIO_MANIFEST`, counts `_1.._N` takes on its own, and
reports anything that does not match a manifest key — so a misnamed file is loud
rather than silent.

**It also normalises delivery loudness.** The first batch spanned 37 dB of RMS,
with the most-heard cue 30 dB below the loudest, so the script measures each cue
and writes a correction factor to bring it to a common peak. That is a delivery
correction only; how loud a cue sits *relative to the others* is design intent
and lives in `AUDIO_MANIFEST.gain`. As deliveries get closer to spec the
correction converges on 1.0 and can be dropped.

### First batch — what the measurements said

Five cues, 16 takes, all distinct, all correctly mono 44.1k/16-bit. Findings
that are worth acting on:

| Finding | Detail |
|---|---|
| **Everything landed exactly on its cap** | All 16. The length limiter is doing real work, but nothing ended on its own terms — every one was cut to fit. |
| **`crew_muster` is cut mid-sound** | Still at 97% of its average energy when it stops. A 5 ms fade prevents a click, not the impression of a hard stop. Regenerate shorter rather than trimming longer. |
| **Real clipping in 5 files** | Runs of up to 10 consecutive samples at full scale — distortion baked into the master, which attenuation cannot undo. `crew_muster_2` has 124 full-scale samples. Generate with headroom. |
| **`cannon_hurt` needed +18 dB** | It hit the correction clamp. Amplifying that far lifts the generation noise floor with it; better regenerated louder than rescued in software. |
| **`hit` needed +13 dB** | Same, less severe. |

Nothing here blocks shipping — v7 is live with all five — but the level spread
and the clipping are worth fixing at the source in the next batch.

### Spec corrections

- **§3 says 48 kHz / 24-bit masters. Drop it to 44.1 kHz / 16-bit.** That is the
  generator's ceiling and it is immaterial for generative material; the
  requirement was written assuming recorded sources.
- **`amb_storm` at 22 s instead of 30 s is fine.** It loops on wind, which has no
  event structure to preserve. Take the 22 s.

### The RAY question — answered

`elem_*` does **not** need looping variants yet. The beam is one shape of six and
only when drafted, so four more files buy very little. The engine layers
`shape_beam_start` → `shape_beam_loop` → `shape_beam_end`, with the one-shot
element tail at onset to colour it. That reads correctly for a two-second beam.

If the beam later feels elementally colourless while held, the fix is four
looping element beds — not retriggering the one-shot, which would pulse.
Park it; it is not in the top three batches.

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

## 5b · Next up — approved direction for v9

**Animation, for the whole cast.** See `ANIMATION-BRIEF.md`. The one thing to
read before generating anything: **deliver atlas strips, not loose frames.** The
two existing cycles are 28 files and 3.9 MB — more than every still combined —
and the full cast in that shape is ~270 files and ~33 MB. One PNG per cycle at
384×384 lands 33–35% smaller, measured on your own frames.

`python src/check-animations.py` validates a strip: frame count divides the
canvas, frames are uniform, and the figure returns to where it started rather
than sliding a little further every loop. Your two existing cycles pass.

**Music — one track first, not seven.** Generate `music/combat_low` only. Live
with it under every wave and decide whether music is helping before committing
to the full set. Prompt is M2 in `AUDIO-SPEC.md`. The director is already built
and will pick it up the moment it lands.

**Audio stays WAV for now.** No encoding step; the loader prefers `.ogg`/`.m4a`
if they ever appear but decodes WAV fine. Revisit when the beds and music make
the payload heavy — which they will.

**Still wanted, unchanged priority:** the stalled cues from the first batch
(`amb_storm`, `amb_ship`, `crit`, `death_light`), regenerated versions of the
five clipped/quiet masters, and the 39 remaining stills — `ground/` first, since
telegraphs and AoE markers are read constantly and are still pure code.

**Boundary correction.** The handoff previously said not to touch
`src/storm-dusk/`. That was too strict — your animation system needed engine
changes and they were good ones. The build freeze already prevents shipped
versions from being altered, so engine edits only ever reach the live build.
Edit what you need; tell me what you changed so I can verify rather than
discover it.

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
