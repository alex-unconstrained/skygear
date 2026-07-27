# START HERE — fresh session brief

**Point a new session at this file.** It assumes no memory of any previous
conversation. Read it, then read the three documents in §2, then work.

Repo: `C:\Users\alexr\OneDrive\Documents\GitHub\OneShot`
Live: https://alex-unconstrained.github.io/skygear/
Live build: **v11** (`storm-dusk-v11.html`). v10 and everything before it are
frozen at the bytes they shipped and live on `archive.html`; the landing page
offers v11 alone.

---

## 1 · The standing order

Build **v11 in full**. Everything in `V11-PLAN.md`. Ship incrementally as
pieces land.

**Do not stop to ask permission.** Approval is needed only for: spending that
looks wildly out of proportion to one asset, deleting or overwriting something
you did not create, anything outward-facing beyond the usual GitHub Pages push,
or a decision that contradicts a written decision in the docs.

Everything else — build it, verify it, commit it, push it, keep going.

### What v11 is for

v10 was the first build made for a stranger, and a stranger played it end to
end. They won by standing at maximum range with 12% lifesteal and described
being unkillable; they asked for more space, more dashing and for the kegs on
the deck to do something; and they could not track enemy fire. v11 is the answer
to that message and to nothing else. The test is that the same player, on a
second run, fights close because it is the better way to play.

### What is explicitly not in v11

No second captain, no endless mode, no meta-progression, relics, currencies,
accounts, leaderboards, multiplayer, touch controls, procedural maps, renderer
rewrite. Full scope means **finishing what exists**, not adding systems.

---

## 2 · Read these, in this order

| # | File | What it gives you |
|---|---|---|
| 1 | `docs/V11-PLAN.md` | **The plan of record.** The tester message, the diagnosis, every number, the acceptance criteria, and the browser-vs-engine-port answer. `V10-PLAN.md` is the record behind it. |
| 2 | `docs/ASSET-GENERATION.md` | **How to make art.** The Aether Loom tool, its API, chroma rules, the prompt constraints that are load-bearing, the ingest bridge, the queue, and a failure table. |
| 3 | `docs/AUDIO-SPEC.md` | **How to make sound.** Mix architecture, per-cue length budgets, ElevenLabs prompts, the shape × element layering trick. |
| 4 | `docs/VOICE-BRIEF.md` | **How to make the voice.** The cast, the settings, the full line sheet, and what not to record. Engine side is done; every cue key is wired. |

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

#   http://127.0.0.1:8798/storm-dusk-v11.html
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
| Engine | **v11 blocks A–E complete.** Reactive deck props, the pressure gauge and vent, salvage, close-range lifesteal with a per-second ceiling, a wider deck with a third cross-passage, two dash charges with base dash damage, readable enemy fire with ground shadows and firing lines. On top of everything v10 shipped |
| Harness | **53 checks, all passing**: matrix, waves, boss beats, **deck ordnance**, **the close-quarters loop**, endings, seed, storage, slow start, real input, perf, layout matrix, Firefox, frozen hashes |
| Stills | **67 of 67** delivered. The two cloud bands that were blocked on billing are in, and `prop_barrel` was re-forged as a steam keg because its role changed |
| Animation | 3 strips: two run cycles and the captain's idle. 15 cycles outstanding, all wired |
| Audio | 11 of 60 cues, and **3 of 7 music tracks** — `combat_low`, `combat_high` and `boss_loop`, the last two delivered 2026-07-27 and crossfade-looped out of their sustained middles. `crew_muster_1` is still cut mid-sound and needs regenerating |
| Voice | **Nothing recorded, everything wired.** 19 cue keys, every call site live, a director with priority and per-key cooldowns. `VOICE-BRIEF.md` is the line sheet |
| Boss | Two beats and a real turn at half health, per the plan |
| First load | 28 MB of art and audio, streamed in priority order behind a playable procedural game. Title screen up in ~210 ms on a throttled 3 Mbit line |
| Determinism | done — `?seed=`, seed on the results screen and in the run report |

### What is blocked

**1 · Audio and voice generation need a key this machine does not have.**
`OPENAI_API_KEY` and `GOOGLE_API_KEY` are set; there is no ElevenLabs or Suno
key, so the 49 remaining SFX cues, the 19 voice keys and 4 music tracks cannot
be generated here. Everything around them is ready: every SFX cue has a
procedural voice, a sample slot, a bus, a voice cap and positional panning, and
voice has a director, so a delivered file is live the moment
`src/ingest-audio.py` sees it. Set `ELEVENLABS_API_KEY` and work
`VOICE-BRIEF.md` §7 in order.

**2 · Video generation works, but is paced on purpose.** Five calls went on the
captain and one shipped. What the other four taught is in
`ASSET-GENERATION.md` §6b and is worth reading before spending another: run
cycles close their loops and idles never do, so idles are `pingpong` in the
manifest and their match score is irrelevant; the attack came back with no
attack in it; and the chroma guidance is wrong for her — green in both stages,
not magenta for the animate pass.

**Image generation is unblocked** — the billing limit was raised on 2026-07-27
and the queue was worked to completion the same day.

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

1. **Voice** — 19 keys, nothing recorded, everything wired. `VOICE-BRIEF.md`
   is generation-ready and needs no engine work at all. Blocked on a key.
2. **Audio** — 49 SFX cues and 4 music tracks. Blocked on the same key. The
   five v11 cues (`keg_fuse`, `keg_blow`, `crate_break`, `lantern_break`,
   `vent`) are the highest-value ones because they belong to a system nobody
   has heard yet.
3. **Animation** — 15 cycles, the queue in `ASSET-GENERATION.md` §6. Read §6b
   first. The engine draws idle/run/attack strips for every character already,
   so a delivered strip needs no code at all.
4. **The human work**, which no agent can do: five cold playtests, a slow
   laptop, loudness on three output systems, photosensitivity review. This is
   now the largest remaining item by some distance — everything the engine can
   assert about itself, it asserts.
