# START HERE — fresh session brief

**Point a new session at this file.** It assumes no memory of any previous
conversation. Read it, then read the three documents in §2, then work.

Repo: `C:\Users\alexr\OneDrive\Documents\GitHub\OneShot`
Live: https://alex-unconstrained.github.io/skygear/
Last live build: **v9** (`storm-dusk-v9.html`). v10 has not been cut yet.

---

## 1 · The standing order

Build **v10 in full**. Not a trimmed demo — everything in `V10-PLAN.md`,
including all 35 remaining stills, all 17 animation cycles, the complete audio
manifest and the engine work. Ship incrementally as pieces land.

**Do not stop to ask permission.** Approval is needed only for: spending that
looks wildly out of proportion to one asset, deleting or overwriting something
you did not create, anything outward-facing beyond the usual GitHub Pages push,
or a decision that contradicts a written decision in the docs.

Everything else — build it, verify it, commit it, push it, keep going.

### What v10 is for

The first build made for a stranger: someone who opens a link, reads nothing, is
on an unknown machine, and leaves the moment it feels broken. The test is that
they play with no coaching, finish a run, and can describe the game afterwards.

### What is explicitly not in v10

No second captain, no endless mode, no meta-progression, relics, currencies,
accounts, leaderboards, multiplayer, touch controls, procedural maps, renderer
rewrite. Full scope means **finishing what exists**, not adding systems.

---

## 2 · Read these, in this order

| # | File | What it gives you |
|---|---|---|
| 1 | `docs/V10-PLAN.md` | **The plan of record.** Seven blocks, acceptance criteria, ownership, and the reasoning behind every contested decision so you do not relitigate them. |
| 2 | `docs/ASSET-GENERATION.md` | **How to make art.** The Aether Loom tool, its API, chroma rules, the prompt constraints that are load-bearing, the ingest bridge, the queue, and a failure table. |
| 3 | `docs/AUDIO-SPEC.md` | **How to make sound.** Mix architecture, per-cue length budgets, ElevenLabs prompts, the shape × element layering trick. |

Then as needed: `ANIMATION-BRIEF.md` (strip format contract),
`LEVEL-KIT-BRIEF.md` (the camera lock — settled, do not reopen),
`CODEX-HANDOFF.md` (what the other agent is and is not doing).

Historical, superseded, do not follow: `V10-ROADMAP.md`,
`V10-SHIP-ROADMAP.md`, `SKYGEAR-V10-RELEASE-ROADMAP-CODEX-PROPOSAL.md`,
`V10-RECONCILED.md`, `ROADMAP.md`.

---

## 3 · The rules that will bite you if you miss them

**Shipped builds are frozen.** `build.py` writes only `LIVE` and refuses to
regenerate anything pinned in `FROZEN`. This exists because earlier versions
were being silently rewritten by edits meant for the current one. If it reports
drift, restore with the git command it prints — do not force past it.

**Cut v10 before changing anything.** v9 is being played. Clone the v9 preset to
`storm-dusk-v10`, set `LIVE = 'storm-dusk-v10'`, add v9's hash to `FROZEN`, add
a v10 card to `index.html`. `build.py --freeze` prints the pin line.

**Never edit a generated `.html`.** Edit `src/storm-dusk/*.js` and rebuild.

**Verify in the engine, not in your head.** There is a local server on
`127.0.0.1:8798` and Playwright is available. Every claim in this project that
turned out wrong was a claim nobody checked — audio that reported success while
silent, a wall tiling that left holes, a benchmark aimed at a fixed point while
the targets walked away. Run it and look.

**Assume your test harness is wrong before the game is.** It usually was.

---

## 4 · The loop

```bash
# make something
python src/storm-dusk/build.py            # only LIVE is written; frozen verified

# check it parses
node --check <(sed -n 's/.*<script>//p' storm-dusk-v10.html)   # or the extract used in history

# check assets
python src/optimize-assets.py --check
python src/check-animations.py

# look at it
#   http://127.0.0.1:8798/storm-dusk-v10.html
#   ?assets=0  procedural only     ?audio=0  silent     ?seed=  once seeding lands

# ship
git add -A && git commit && git push origin main
# then confirm live, and that the build stamp on the title matches
```

Asset generation:

```bash
curl -s http://127.0.0.1:8765/api/config          # is the Loom up?
python src/loom-ingest.py list                    # what is ready to bring in
python src/loom-ingest.py anim <job> hero_attack
python src/loom-ingest.py still <cand.png> hero_front_attack
```

---

## 5 · State as of this handoff

Verified 2026-07-27, not remembered:

| | |
|---|---|
| Stills | **32 of 67** — 35 missing: ui 12, props 8, ground 7, fx 6, colossus 3, env 3 |
| Animation | 2 run cycles (loose frames, want packing), **17 outstanding** |
| Audio | **6 of 55** cues, 1 music track |
| First load | **24 MB** — 19 s at 10 Mbit, 64 s at 3 Mbit |
| Perf | 1.9 ms/frame typical, 3 ms p95 at 37 enemies — fast dev box only |
| Determinism | none yet — no seed, no run log, no report |

Known-bad and unfixed: three UI assets load but are never drawn, inflating the
title's art counter; the README still describes a 6 × 4 matrix, 24 combinations
and 34 cards, all wrong; five of sixteen delivered audio masters clip and two
need large runtime rescue gain.

---

## 6 · Cost, and the one judgement call

Full scope is roughly **95 image generations**, **~27 video generations**
(17 cycles plus reruns — historically 3 of 5 loops came back too weak to use),
and **~180 audio generations** (~20k characters, comfortably inside the 300k
quota).

**Video is the dominant cost and the only thing worth pacing.** Four candidates
for anything a player looks at, one for props. Animate only after a still is
approved — regenerating a cycle from a bad source pays the expensive call twice.
Check a loop's match score before spending review time on it; above ~0.05 it
will visibly jump and should be regenerated, not shipped.

If a single asset starts costing many reruns, stop and write down why rather
than burning generations at it.

---

## 7 · Suggested order

Blocks 1–2 need nothing and change the game most.

1. **Cut v10**, freeze v9.
2. **Block 1** — instant start on procedural with streaming swap, seeded RNG,
   run report, delete `assets-49/`, fix the art counter.
3. **Block 2** — opening skill choice, contextual first-run prompts, title screen.
4. **Start generating in parallel** — `hero_attack` and `hero_idle` first; her
   attack is the most-seen frame in the game and currently snaps to procedural
   on every swing.
5. **Blocks 3–5** — settings and accessibility, results screen, fight legibility.
6. **Keep generating** down the queue in `ASSET-GENERATION.md` §6.
7. **Block 7** — harness, browser matrix, perf on real hardware.

Commit after each coherent piece. A long unpushed working tree is the one thing
that has repeatedly gone wrong here.
