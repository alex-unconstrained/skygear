# START HERE — fresh session brief

**Point a new session at this file.** It assumes no memory of any previous
conversation. Read it, then read the three documents in §2, then work.

Repo: `C:\Users\alexr\OneDrive\Documents\GitHub\OneShot`
Live: https://alex-unconstrained.github.io/skygear/
Live build: **v10** (`storm-dusk-v10.html`). v9 is frozen at the bytes it shipped.

---

## 1 · The standing order

Build **v10 in full**. Not a trimmed demo — everything in `V10-PLAN.md`.
Ship incrementally as pieces land.

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

**Never edit a generated `.html`.** Edit `src/storm-dusk/*.js` and rebuild.

**Verify in the engine, not in your head.** `npm test` runs the headless
harness against the real build; `node tools/shots.mjs` photographs every screen.
Every claim in this project that turned out wrong was a claim nobody checked —
audio that reported success while silent, a wall tiling that left holes, a
benchmark aimed at a fixed point while the targets walked away. Run it and look.

**Assume your test harness is wrong before the game is.** It usually was. The
first two failures the harness reported in the v10 work were both the harness:
`spawnEnemy(type, forced)` takes a spawn *point*, not a boolean, and zeroing
`hp` never reaches the code that decides a run is over.

---

## 4 · The loop

```bash
python src/storm-dusk/build.py            # only LIVE is written; frozen verified
npm test                                  # the harness, ~90 s including Firefox
node tools/shots.mjs                      # every screen -> .shots/
node tools/shots.mjs --art                # ... with the delivered art on

#   http://127.0.0.1:8798/storm-dusk-v10.html
#   ?assets=0  procedural only   ?audio=0  silent   ?seed=K3F9QZ  replay a run

git add -A && git commit && git push origin main
# then confirm live, and that the build stamp on the title matches
```

Asset generation:

```bash
curl -s http://127.0.0.1:8765/api/config          # is the Loom up?
python tools/forge.py list                        # what is missing, by batch
python tools/forge.py run ui                      # forge a batch
python tools/forge.py ingest ui                   # poll, key, resize, validate
python src/loom-ingest.py anim <job> hero_attack  # an animation strip
python tools/audio-check.py                       # levels and clipping
```

---

## 5 · State as of this handoff

Verified 2026-07-27 by running it, not remembered.

| | |
|---|---|
| Engine | **Blocks 1–5 and 7 complete.** Seeded runs, streaming art, opening draft, contextual prompts, title screen, settings, rebindable keys, reduced motion, results screen, run report, lane readout, before→after cards |
| Harness | 21 checks, all passing: matrix, waves, endings, seed, perf, layout matrix, Firefox, frozen hashes |
| Stills | **50 of 67** delivered and climbing — 17 outstanding: props 7, fx 6, env 3, `ui_frame` |
| Animation | 2 run cycles as packed strips; idle/run/attack wired for the whole cast, 17 cycles outstanding |
| Audio | 6 of 55 cues. **All 16 delivered masters now at −8 dBFS with no runtime rescue**; one (`crew_muster_1`) is cut mid-sound and needs regenerating |
| First load | **25 MB** of art and audio, but streamed in priority order behind a playable procedural game — there is no loading screen at any speed |
| Determinism | done — `?seed=`, seed on the results screen and in the run report |

### The one thing that is blocked

**Audio generation needs a key this machine does not have.** `OPENAI_API_KEY`
and `GOOGLE_API_KEY` are set; there is no ElevenLabs or Suno key, so the 49
remaining SFX cues and 6 music tracks cannot be generated here. Everything
around them is ready: every cue has a procedural voice, a sample slot, a bus, a
voice cap and positional panning, so a delivered file is live the moment
`src/ingest-audio.py` sees it. Set `ELEVENLABS_API_KEY` and the queue in
`AUDIO-SPEC.md` §7 can be worked straight through.

---

## 6 · Cost, and the one judgement call

**Video generation is the dominant cost and the only thing worth pacing.** Four
candidates for anything a player looks at, one for props. Animate only after a
still is approved — regenerating a cycle from a bad source pays the expensive
call twice. Check a loop's match score before spending review time on it; above
~0.05 it will visibly jump and should be regenerated, not shipped.

If a single asset starts costing many reruns, stop and write down why rather
than burning generations at it.

---

## 7 · What is left

1. **Finish the stills** — `python tools/forge.py run props` etc., then
   `ingest`. The prompts are already written and in version control.
2. **Animation** — the queue in `ASSET-GENERATION.md` §6, captain first. The
   engine already draws idle/run/attack strips for every character, so a
   delivered strip needs no code.
3. **Audio** — blocked on a key. See §5.
4. **The human work**, which no agent can do: five cold playtests, a slow
   laptop, loudness on three output systems, photosensitivity review.
