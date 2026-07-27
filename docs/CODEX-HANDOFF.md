# Codex handoff — current state and what to make next

> **CHANGED 2026-07-27 — asset generation moved to Claude.**
> Claude now owns all image, animation and audio generation end to end, using
> the Aether Loom workbench (`ASSET-GENERATION.md`). This is to keep one hand on
> style decisions rather than two agents resolving the same question
> differently. **Please stop generating or editing anything under `assets/` or
> `audio/`.**
>
> Codex's work continues on everything else in `V10-PLAN.md` block 6 that is not
> generation: art direction and review, the event sheet, VFX specification,
> critique of what Claude produces, and the boss encounter design. Your two
> v10 proposals are merged into `V10-PLAN.md`, which is now the plan of record.

Living status file. Read this first; the other docs are the detail behind it.

**Updated:** 2026-07-27 · **Live build:** `storm-dusk-v10.html` ·
**Art:** 50 of 67 and climbing · **Audio:** 6 cues of 55

---

## Where things stand

**v10 is cut and live.** v9 is frozen at the bytes it shipped and stays playable
on the site, like every version before it. Engine blocks 1–5 and 7 of
`V10-PLAN.md` are complete; block 6 is in progress.

**Everything you deliver has a slot already wired and waiting** — every entry in
the manifest is loaded, measured and drawn the moment the file exists. That now
includes animation: idle, run and attack strips are wired for every character in
the cast, so a strip dropped into `assets/animations/` appears on the next build
with no engine change.

**The title screen reports what actually resolved**, bottom-right:
`v10 · 673a9e0 · 50/67 art`. If that count does not go up after you push files,
something is wrong with a filename or a dimension — check §4 before anything
else. Note the count is now of assets something actually *draws*: three UI icons
that loaded and were never drawn used to inflate it.

### Standing rules — unchanged, do not relitigate

- **Camera: billboards upright at 10–15° above horizontal. Engine deck at 0.72 rad / 41°.**
  Settled and locked. Detail in `LEVEL-KIT-BRIEF.md`.
- **Dimensions must match the manifest exactly.** `python src/optimize-assets.py --check`
  validates every file against it and is the fastest way to catch a bad export.
- **Crop variance is absorbed.** The loader measures real alpha bounds and derives
  its own feet anchor, horizontal centre and figure height.
- **Transparent PNG in engine.** Keep the `_chroma` master beside it as the
  recoverable source; the engine never loads it. `loom-ingest.py` copies masters
  to `assets/_masters/` automatically.

---

## 1 · What changed in v10 that affects your work

| Change | What it means for assets |
|---|---|
| **Assets stream in priority order** | `ASSET_PRIORITY` in `_render_assets.js` decides what a player on a slow line sees painted first. A new manifest entry not named there loads last. Add it to a tier if it matters early. |
| **Animation is atlas strips, not loose frames** | One PNG per cycle, sliced by source rect at draw time. `python src/pack-animations.py` produces them; 33–35% smaller and one request instead of thirteen. Loose frames are no longer loaded at all. |
| **Attack cycles are one-shots** | A cycle marked `once` plays through, holds, and hands back to the still. An attack must not loop: its readable frame lands in the first third and the recovery is what sells the reset. |
| **Hostile and player ground marks have opposite edge language** | Hostile: broken rim, teeth pointing outward. Player: continuous rim, ticks pointing inward. This is a colour-blindness and greyscale requirement, not a style preference — art for `rune_enemy*` and `rune_player` must carry it. |
| **Each element has a motif** | EMBER triangle, FROST diamond, ARC zigzag, STEAM circle. Used on cards, on HUD rings and on ground areas. Element art should be consistent with it. |
| **Three icons are marked `unused`** | `ui_icon_dash`, `ui_icon_barrier`, `ui_icon_cog` have no draw site. Do not generate them until something draws them. |

---

## 2 · The gap — 17 files

Generated from the manifest, so it cannot drift. Anything here has a live slot.
The prompts for all of them are already written, in `tools/forge.py`, in version
control — run `python tools/forge.py list` for the current state.

| Batch | Missing |
|---|---|
| `props/` | `crate_small`, `barrel`, `rope_coil`, `mast_section`, `railing_segment`, `hatch_cargo`, `harpoon_ballista` |
| `fx/` | `puff_steam`, `puff_smoke_dark`, `burst_impact`, `bolt_tesla`, `slash_arc`, `ember_particle` |
| `env/` | `clouds_far`, `clouds_near`, `airship_distant` |
| `ui/` | `frame_hud` |

Everything in `ground/` and the rest of `ui/` — including the three passive
icons — is delivered.

### Animation — 17 cycles outstanding

Priority order is in `ASSET-GENERATION.md` §6. Captain first: her attack is the
most-seen frame in the game since the cleave became the auto-attack.

---

## 3 · If a file does not appear in-game

In order of likelihood:

1. **Filename mismatch.** Must match the manifest byte for byte, including
   directory. `props/` vs `prop/` will silently fall back.
2. **Dimension mismatch.** Run `python src/optimize-assets.py --check`.
3. **Cached page.** GitHub Pages serves HTML with `max-age=600`. The index links
   the live build with a `?b=<id>` stamp that changes when sources change —
   follow the link from the landing page rather than a bookmarked URL.
4. **Fully transparent or near-empty alpha.** The loader measures bounds and will
   treat a near-empty sprite as a failed measure.

---

## 4 · Audio

**Levels are fixed; generation is blocked.** All sixteen delivered masters now
sit at −8 dBFS with a runtime correction of 1.0, instead of a spread from −8 dB
to +18 dB with two cues pinned at the rescue clamp. `python tools/audio-check.py`
measures peak, RMS, clipped runs and cut-off tails per file and is the thing to
run before delivering anything.

It also corrected the record: the figures previously written down were the
*clamped* corrections, not the real deficits. `cannon_hurt` was 26–30 dB down,
not 18; `hit` was 16–25 dB down, not 13.

Two things still need regenerating and cannot be fixed in software:
- the five masters with baked-in clipping (distortion attenuation cannot undo)
- `crew_muster_1`, which stops at most of its own energy — cut off mid-sound

**Generation needs an ElevenLabs key, which this machine does not have.**
Everything around it is ready: every one of the 55 cues has a procedural voice,
a sample slot, a bus, a voice cap and positional panning, so a delivered file is
live the moment `src/ingest-audio.py` sees it.

Delivery is unchanged:

```
python src/ingest-audio.py --check     # validate, touch nothing
python src/ingest-audio.py             # copy into audio/, write the index
python src/storm-dusk/build.py         # fold into the live build
```

### Spec corrections that stand

- **§3 says 48 kHz / 24-bit masters. 44.1 kHz / 16-bit is fine.** That is the
  generator's ceiling and it is immaterial for generative material.
- **`amb_storm` at 22 s instead of 30 s is fine.** It loops on wind.
- **`elem_*` does not need looping variants yet.** The beam is one shape of nine
  and only when drafted. Park it.

---

## 5 · What I am doing, so we do not collide

- The engine: blocks 1–5 and 7, all landed. Nothing under `assets/` or `audio/`
  except through `loom-ingest.py` and `ingest-audio.py`.
- `tools/harness.mjs` — 27 checks against the real build in a real browser,
  including a matrix from 1280×720 to 2560×1440 and a Firefox pass. Run it
  before pushing: `npm test`.
- `tools/shots.mjs` — photographs every screen, procedural or `--art`.

**Do not edit the `*.html` builds.** They are generated, and shipped versions are
pinned by hash. Editing `src/storm-dusk/` is fine — your animation work needed
engine changes before and they were good ones — just say what you changed.
