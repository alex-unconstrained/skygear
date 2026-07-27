# Asset generation — the operator's manual

**Asset generation is Claude's job alone from 2026-07-27.** Codex does not
generate, edit or move anything under `assets/` or `audio/`. One hand on the
pipeline, no cross-contamination, no two agents resolving the same style
question differently.

This document assumes no memory of the conversation that produced it. Everything
needed to generate, validate and ship an asset is here or linked from here.

---

## 1 · The tool

**Aether Loom** — a local FastAPI server with a browser workbench.

| | |
|---|---|
| Location | `C:/Users/alexr/Documents/Codex/2026-07-26/done-66-images-fully-specced-for` |
| Start | `.\run_aether_loom.ps1` (PowerShell, from that directory) |
| URL | http://127.0.0.1:8765 |
| Image model | OpenAI `gpt-image-2` |
| Video model | Google `gemini-omni-flash-preview` |
| Prompt enhancer | `gpt-5.6-sol` |
| Keys | `OPENAI_API_KEY`, `GOOGLE_API_KEY` in **user** environment variables |

**Keys never reach the browser.** Provider calls happen in the local server. Do
not print, echo or commit a key.

### Is it running?

```bash
curl -s http://127.0.0.1:8765/api/config | head -c 200
```

Expect `{"keys": {"openai": true, "google": true}, ...}`. If the port is dead,
start it with the PowerShell script above and wait ~5 s.

### Three stages

1. **Forge** — `gpt-image-2` renders a character or prop onto a flat chroma
   plate. Output: `output/forge_jobs/<id>/candidate_NN.png`.
2. **Animate** — Gemini Omni animates that plate into a 1280×720, 10 s, 24 fps
   locked-off shot. Output: `output/studio_jobs/<id>/omni_animation.mp4`.
3. **Cut loop** — finds the strongest repeating cycle, keys the chroma out,
   exports transparent numbered frames at 512×512 plus a manifest with the loop
   score. Output: `output/studio_jobs/<id>/loop/`.

Stage 1 alone gives a still. All three give an animation cycle.

---

## 2 · Which surface to drive

Both are the same server and the same code paths.

**Use the HTTP API for generation.** It is reliable unattended, returns job ids
you can poll, and does not depend on clicking through screenshots. This is the
right choice for batch work and overnight runs.

**Use the GUI at http://127.0.0.1:8765 for looking at results.** Judging whether
a candidate is *good* requires seeing it, and the workbench shows candidates,
the Omni mp4 and the cut loop side by side with the asset library. Reviewing
four candidates in the browser is the fastest way to pick one.

Generate headless, review visually, ingest with the bridge.

### API

```
GET  /api/config                 keys, models, chroma options, asset library, default prompts

POST /api/forge-jobs             image_prompt, quality=high, candidate_count=1|4, chroma_key
GET  /api/forge-jobs/{id}        status, progress, candidates[]

POST /api/jobs                   source_mode=existing|generate, image_prompt, motion_prompt,
                                 quality, output_fps=6..24, chroma_key,
                                 approved_asset | source_file (multipart)
GET  /api/jobs/{id}              status, stage, progress, result
```

`candidate_count` is **1 or 4 only**. Four candidates uses four generations and
gives four different directions (faithful / silhouette / material / personality)
— worth it for a hero frame, wasteful for a barrel.

Forging four candidates:

```bash
curl -s -X POST http://127.0.0.1:8765/api/forge-jobs \
  -F "image_prompt=$(cat prompt.txt)" -F quality=high \
  -F candidate_count=4 -F chroma_key='#00FF00'
# -> {"id":"abc123"}
curl -s http://127.0.0.1:8765/api/forge-jobs/abc123
```

Animating an approved asset:

```bash
curl -s -X POST http://127.0.0.1:8765/api/jobs \
  -F source_mode=existing -F approved_asset=/library/heroes/captain_front_idle.png \
  -F "motion_prompt=$(cat motion.txt)" -F output_fps=12 -F chroma_key='#FF00FF'
```

---

## 3 · Chroma — pick against the subject

Getting this wrong produces a halo or eats part of the character.

| Key | Use for |
|---|---|
| `#FF00FF` magenta | teal, green, brass, brown, neutral — **most SKYGEAR subjects** |
| `#00FF00` green | magenta, red, violet, black, white — **the captain's red coat** |
| `#006BFF` blue | orange, yellow, red, warm metal — furnace/ember subjects |

The captain wears oxblood and teal: forge her on **green**, animate on
**magenta**. The default prompts already do exactly this; keep it.

---

## 4 · The prompts that work

Full working templates live in `GET /api/config` → `defaults`. Do not rewrite
them from scratch — they encode hard-won constraints. Change the subject
description and leave the structure alone.

**The still prompt must keep:** 40° high three-quarter view facing lower-left;
complete silhouette with every extremity visible; subject ≤68% of canvas height
with ≥15% margin; centred; nothing touching an edge; painterly cel rendering
with near-black irregular ink outline; two-source lighting, steel-blue moon rim
upper-left and amber lantern fill lower-right; deep indigo / teal / brass /
oxblood palette; **no ground, no contact shadow, no cast shadow**; flat uniform
chroma field edge to edge.

**The motion prompt must keep:** `<FIRST_FRAME>` identity lock; one continuous
locked-off shot, no cuts; preserve face, proportions, materials, weapon, ink
outline, angle and scale; hand-authored 12 fps timing, not cinematic
interpolation; feet's average contact point fixed — **no foot sliding**; loop
boundary poses matching in silhouette, foot placement, blade angle, hair, coat
and effect state, with no crossfade or speed ramp; 16:9 static camera, subject
≤58% of frame height, ≥15% chroma margin above and below; explicit ban list
(no redesign, face drift, costume change, duplicate limb, style drift, camera
drift, motion blur, sparkles, attack effects, audio).

Per-cycle motion notes to swap in:

| Cycle | Motion |
|---|---|
| idle | Breathing, small weight shift, one restrained equipment tic. ~2 s. Returns exactly to the source pose. |
| run | Two-foot cycle ~1.1 s, two contacts, a passing pose, rhythmic bob, opposed arm swing. |
| attack | Wind-up → strike → recover, **plays once, does not loop**. The readable strike lands in the first third. |

---

## 5 · Getting output into the game

`src/loom-ingest.py` is the only sanctioned route. It keys chroma, resizes to
what the engine asks for, keeps the master, and runs the validators.

```bash
python src/loom-ingest.py list                                # what is ready
python src/loom-ingest.py anim <job_id> hero_attack           # -> 384px strip
python src/loom-ingest.py anim <job_id> colossus_attack --size 512
python src/loom-ingest.py still <candidate.png> hero_front_attack
python src/loom-ingest.py still <c.png> prop_barrel --chroma '#FF00FF' --fill 0.8
```

`list` reports each loop's **match score** — how closely the first and last
poses agree. Below ~0.05 is good; above that the loop will visibly jump and the
cycle should be regenerated rather than shipped.

`still` fits the subject inside the manifest box by its own alpha bounds, so
framing variance between generations does not matter. `--fill` sets how much of
the box the figure occupies and `--anchor` where it sits vertically (0.92 =
near the bottom, right for characters; use ~0.5 for icons and ground art).

Masters are copied to `assets/_masters/` — never delete those, they are the only
way to re-cut an asset without paying to regenerate it.

### Then validate

```bash
python src/optimize-assets.py --check     # every still matches manifest dimensions
python src/check-animations.py            # frame count, uniform size, no net drift
python src/storm-dusk/build.py            # fold into the live build
```

A strip that reports **net drift** slides across the deck a little further every
loop. Swing is fine — feet alternate by design. Drift is not.

---

## 6 · The queue

Priority order. Each row is useful on its own; do not batch ahead.

### Animation — 17 cycles (`ANIMATION-BRIEF.md` for the format contract)

| # | Cycles | Why here |
|---|---|---|
| 1 | `hero_attack`, `hero_idle` | Her attack is the most-seen frame in the game since the cleave became the auto-attack |
| 2 | `scrapper_attack`, `scrapper_idle` | Most numerous enemy; its run cycle already exists |
| 3 | `crew_idle`, `crew_run`, `crew_attack` | Six on screen at once and currently the least animated thing in frame |
| 4 | `armored_*` (3), `swarm_run`, `swarm_attack` | Armoured lingers; swarm never stops |
| 5 | `gunner_idle`, `gunner_attack` | Hovers, changes least |
| 6 | `colossus_idle`, `colossus_attack` (512px) | Wave 12 only, but it is the finale |

Also: pack the two existing loose run cycles into strips
(`python src/pack-animations.py`) — 33–35% smaller, measured.

### Stills — 35 missing

| Priority | Category | n | Why |
|---|---|---|---|
| 1 | `ground/` | 7 | Telegraphs, runes and AoE markers are read every second of combat and are still pure code |
| 2 | `ui/` icons | 12 | Includes the three **passive** icons (`icon_skill_field`, `icon_skill_pulse`, `icon_skill_sentry`) which now have slots waiting |
| 3 | `fx/` | 6 | Impacts, bolts, steam, embers |
| 4 | `enemies/colossus_*` | 3 | The finale should look like one |
| 5 | `props/` | 8 | Deck dressing |
| 6 | `env/` | 3 | Clouds and the distant escort |

`python src/loom-ingest.py still --help` lists manifest keys if you pass a
partial name.

---

## 7 · Standing rules

- **Camera is locked.** Billboards upright, 10–15° above horizontal; the engine
  projects the deck at 0.72 rad. Settled in `LEVEL-KIT-BRIEF.md`. Do not reopen
  it without a reproducible in-engine readability failure.
- **Dimensions must match the manifest exactly.** The validator enforces it.
- **Crop variance is absorbed** — the loader measures real alpha bounds for its
  own anchor, centre and figure height. Aim for consistency; it is not fatal.
- **Keep `_chroma` and `_master` sources.** Ship the transparent PNG.
- **Stills stay as animation fallback.** Never delete a still because a cycle
  exists; it is what draws before a strip decodes.
- Every asset has a procedural fallback, so a missing file degrades one sprite
  rather than breaking the game. Ship incrementally and often.

---

## 8 · Cost and pacing

Every forge is an image generation; every animate is a video generation, which
is the expensive one. Four candidates costs four images.

- Forge **4 candidates** for heroes, enemies and anything a player looks at.
- Forge **1** for props, decals and background dressing.
- Animate **once per cycle**, and only after the still is approved. Regenerating
  a cycle because the source was wrong wastes the expensive call.
- Check the loop match score before ingesting. A weak loop wastes the next
  step's review time.

---

## 9 · When it goes wrong

| Symptom | Cause and fix |
|---|---|
| Ingest refuses: "entirely transparent" | Wrong `--chroma`. Match the plate that was actually used. |
| Halo or fringe around the subject | Chroma too close to a subject colour — reforge on a different plate. |
| Loop match score > 0.05 | The cycle does not return to its start. Regenerate; do not ship it. |
| Validator reports net drift | The character translates across the cycle. Regenerate with the foot-contact clause emphasised. |
| Asset ingested but invisible in game | Filename or dimension mismatch — run `optimize-assets.py --check`; then confirm the title's art counter went up. |
| Title art count did not move | The page is cached. GitHub Pages serves HTML for 10 minutes; follow the `?b=` link from the landing page and check the build stamp. |
| Job stuck at "running" | Check `output/aether_loom_server.log`. A provider error surfaces there, not in the GUI. |

---

## 10 · Definition of done for one asset

1. Generated with the standing prompt structure and the right chroma.
2. Reviewed **by eye** in the GUI or by opening the file — not by trusting a
   validator.
3. Ingested through `loom-ingest.py`, master retained.
4. `optimize-assets.py --check` and `check-animations.py` pass.
5. Built, and confirmed visible in-engine at the size it actually renders.
6. Committed with what it is and which job produced it.
