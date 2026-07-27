# SKYGEAR v12 — the plan of record

Supersedes `V11-PLAN.md` as the live plan. Written 2026-07-27 against v11
(`storm-dusk-v11.html`, build `f1d2241`) after the first full playthrough of it.

Running history: **[VERSIONS.md](VERSIONS.md)**.

---

## 0 · Where this came from

The first v11 run, in full:

```
DECK HELD — twelve waves repelled · 4:43 · seed 2HVIX4
kills 338 · damage 32,655 · best chain 19 · dashes 195
build: Ember Cleave (auto) / Arc Whip / Arc Gale / Arc Pulse / Ember Field
draft: ARC WHIP, ARC GALE, ARC PULSE, POWDER MONKEY, DETONATOR, EMBER FIELD,
       FIELD DRESSING, KEEN EYE, ARC CONVERGENCE, TWIN CAST, QUICK HANDS,
       SCRAPPER'S LUCK
```

and the notes with it: the level feels better, wider, with real movement between
lanes — **that part worked**. But the run was very easy, played entirely in
melee, and the healing meant health was never a threat. Separately: the overhead
envelope obscures the upper third of the screen; the game lagged when a lot was
happening; there are still missing animation assets; and — the sharpest question
of the four — *what am I supposed to be looking at to see that this ship is
moving and flying?*

**The v11 bet paid off and then paid too much.** Close range is now the better
way to play, which is what v11 was for. It is also now the only way to play, and
it is safe, which is not what anything was for.

---

## 1 · The run was easy, and no single number was wrong

This is worth writing out because the diagnosis is the interesting part.

Nothing in that draft is individually overtuned:

| Source | Per event | Over that run |
|---|---|---|
| The vent | 15 hp, 1.1s floor | fired constantly in permanent melee |
| Close-kill salvage | 8 hp on 16% of close kills | 338 kills, most of them close ≈ **430 hp** |
| SCRAPPER'S LUCK | 15 hp on 15% of kills, **stackable** | ≈ **760 hp** |
| FIELD DRESSING | 1.5/s above half pressure | melee means permanent pressure ≈ **400 hp** |
| Between waves | 4 hp × 12 | 48 hp |

Against a 100 hp captain, that is well over a thousand points of healing in
4:43, and each line of it looked defensible on its own. **The failure is
additive, so the fix has to be too.**

### What changes

- **One ceiling on all healing: 12 hp/s**, as a refilling budget. Vent,
  salvage, field dressing, cards — everything except the between-wave top-up
  draws from it. Lifesteal keeps its own tighter 9 hp/s budget inside that.
  This is the change that matters: it is the only version of this fix that does
  not need re-tuning every time a healing card is added.
- **The vent is less of a panic button**: 15 → 10 hp, floor 1.1 → 2.0s, radius
  215 → 200, knock 340 → 280. It still clears space; it no longer clears the
  deck twice a second.
- **Less supply, not just less throughput**: close-kill salvage 16% → 10% and
  8 → 6 hp; SCRAPPER'S LUCK is once-only and 12 hp.
- **FIELD DRESSING pays below 60% health only** (and 1.5 → 2/s when it does). A
  heal that cannot be banked at full health is a comeback; one that runs all run
  is a difficulty setting.

Walking over salvage while the budget is spent still consumes it. That is
deliberate — supply and throughput are different things, and the pickup should
not become a stored resource you farm before a push.

### What is deliberately NOT changed yet

Enemy damage. It is the obvious next lever and it is the wrong one to pull
blind: with a thousand points of healing removed, the existing damage may
already be lethal. Play it once more before touching it. If it is still easy,
the next moves in order are: melee reach enemies (SCRAPPER, ARMORED) get +25%
damage from wave 7, then the ARMORED windup shortens in the last third.

---

## 2 · The lag was ours, not the browser's

This matters for §4, so it is measured rather than asserted. A new tool,
`tools/profile.mjs`, counts every 2D-context call one frame makes and attributes
it to the subsystem that asked for it. Counting rather than timing is
deliberate: headless Chromium rasterises in software, so *timings* taken there
are confident and wrong, while the number of calls a frame asks for is the same
on every machine.

The first run of it found something absurd and then something real.

**The absurd one:** 200 million canvas calls in a single frame — 50 million each
of `beginPath`/`moveTo`/`lineTo`/`stroke`. All of it from one line in the health
bar, which drew a tick mark per 20 max HP with no ceiling; the profiler had set
`maxHp` to 1e9 to take health out of the measurement. No real run reaches that,
but nothing in a HUD should scale without a cap, so it is capped at 20 ticks.

**The real one**, from a saturated wave-11 frame — four skills firing, a keg
chain going off, kills landing:

| | calls in one frame |
|---|---|
| **Total** | **15,968** |
| `drawGroundFx` | **9,354 (59%)** — 225 live transient effects |
| particles | 1,583 |
| deck | 1,187 |
| HUD | 974 |
| enemy billboards | 968 |

`fx()` pushed onto `S.fx` with **no limit**, and each ground effect costs about
forty canvas calls because it draws its shape twice — once in colour, once in
additive glow.

### What changes

- **A cap on live effects** (76 at full VFX, scaling with the player's setting),
  evicting the oldest purely decorative one. `delayPop` and `stun` are never
  evicted because both mean something.
- **Level of detail above 26 effects**: the second, cosmetic glow pass is
  dropped. Shapes, radii and durations are untouched — the event sheet's rule
  that gameplay boundaries never scale with quality settings still holds.

**Result: 15,968 → 7,937 calls in the same frame, and `drawGroundFx` 9,354 →
1,383.** The harness now pins this: a saturated frame must stay under 11,000
calls, effects must be capped, and per-frame gradient allocation must stay under
200. That check is hardware-independent, which is the only kind of performance
check worth having in a repo.

---

## 3 · The two things you could not see

### The envelope

Our own gas bag drew across the upper 34% of the frame at full opacity. The top
of the frame is the **bow** — the direction boarders arrive from — so the thing
framing the shot was hiding the threat.

It is now tied to the camera: at the bow, where the envelope really is overhead,
it draws in full; as the camera moves toward the stern it thins to 20% of frame
height and drops to 28% opacity. At the far end of the deck it is a suggestion.
Pinning it to the bow entirely was the other option and reads worse — it
appearing and vanishing draws more attention than it saves.

### "What am I supposed to be looking at to see that it's flying?"

Nothing, was the honest answer. Two cloud bands drifting at 7 and 17 pixels per
second, and one distant escort airship. At a glance the deck is a room.

- **An airstream.** Streaks of vapour and grit blow along the keel from bow to
  stern, in screen space, over the planking — perspective-scaled so they are slow
  and short near the horizon and fast and long near the camera. A vehicle reads
  as moving because *things go past you*; this is that, and it costs one path and
  no allocation.
- **The clouds roughly double in speed** (7 → 16, 17 → 34) and now bob, so the
  horizon is never still.
- Both ride the VFX setting and stop under reduced motion, because a permanent
  full-screen drift is exactly what that setting exists for.

Still on the list for this: rigging sway on the mast lines, a slow ±0.4° roll on
the whole projected frame, and vapour tearing off the rails on a turn. The roll
is the strongest of the three and also the one most likely to hurt aiming, so it
wants a playtest of its own rather than a guess.

---

## 4 · Godot — the real answer, with the numbers

Asked twice, so this section is written to be argued with rather than to close
the question. Two things changed since `V11-PLAN.md` §6 said "stay in the
browser": there is now a measured lag report, and the measurement came back
saying **the lag was our own uncapped effects list, not Canvas 2D**. A frame
that asks for 7,937 calls with 46 enemies on screen is not a platform at its
limit.

That is evidence about *this* symptom. It is not an argument that Canvas 2D is
where this game should live forever, and the honest list of what the current
renderer cannot do is short and real:

| Canvas 2D cannot | Godot 4 gives you |
|---|---|
| Shaders of any kind | full 2D shader pipeline |
| Real lighting — every "light" here is a hand-painted radial gradient | `PointLight2D`, normal maps, occluders |
| GPU particles — ours are 400 CPU-drawn sprites with a hard cap | `GPUParticles2D`, tens of thousands |
| Skeletal or blended animation — ours are atlas strips | `AnimationPlayer`, `AnimationTree`, blend spaces |
| Native export, controllers, Steam | all first-class |
| A profiler | a real one, built in |

And the honest list of what a port **costs**, which is the part that usually
goes unsaid:

- **The renderer is a rewrite, not a translation.** ~3,500 lines of projection,
  billboard sorting, the x-ray occlusion pass, ground-projected shapes. Most of
  it becomes *simpler* in Godot (Y-sort, `Node2D`, `Light2D`) — but simpler is
  still rewritten and re-tuned, and the camera bake (41° project, 10–15° paint)
  is settled and would have to be re-settled.
- **The sim is a port, and mostly mechanical.** ~3,100 lines with no DOM
  dependencies to speak of. GDScript is the natural target; C# if performance
  ever matters, which on this sim it does not — a step costs 1.9 ms today.
- **The harness is a rewrite.** 61 checks that drive the real simulation through
  a browser seam. Godot has headless mode and GUT, so the checks survive as
  *ideas*, not as code. This is the single most valuable thing in the repo after
  the game itself, and it does not come along for free.
- **The asset and audio pipelines are re-pointed.** `forge.py` and
  `soundforge.py` produce PNGs and Vorbis, which Godot imports happily — but the
  manifest, the procedural fallback for every missing asset, and the streaming
  priority order are all engine-specific and would go.
- **The thing v10 was built for gets worse.** A single 400 KB HTML file that
  starts instantly on any desktop browser becomes a 10–25 MB WebAssembly bundle
  with a loading screen. Threads need `SharedArrayBuffer`, which needs COOP/COEP
  headers, which **GitHub Pages cannot set** — so the web export is
  single-threaded and hosted somewhere else. iOS Safari remains unreliable. "A
  stranger opens a link and is playing in 210 ms" does not survive that.

### The spike is already being built — and that changes the ask

`skygear-godot/` exists in this repo: an isolated Godot 4.5 project targeting
v11, with a living `DESIGN.md`, the runtime art copied in, `project.godot`, four
scenes and the data layer (`scripts/game_data.gd`) written. Its own README
describes milestone 1 as a playable combat vertical slice; on disk the design
document, scenes and data are in and most of the behaviour scripts
(`game.gd`, `player.gd`, `enemy.gd`, `prop.gd`, `hud.gd`) are not yet. It is
mid-flight, and it is not mine — I found it while committing and swept its
current state into a commit of my own, which is noted here so the history is not
confusing later.

So the question is no longer "should we spike it". It is **"what does that spike
have to show to win the argument"**, and the four numbers below are the answer.
Nothing else needs to be argued: measure these, put them next to the browser
build's, and the decision makes itself.

| # | Measure | Browser build today | Port has to beat / match |
|---|---|---|---|
| 1 | **Web bundle size** | 0.42 MB HTML + 34.7 MB streamed assets, playable before any of it arrives | a wasm bundle that is playable on a cold 3 Mbit line |
| 2 | **Cold start to interactive** | **210 ms** on a throttled 3 Mbit line | anything under ~3 s is a win; a loading bar is a real loss |
| 3 | **Frame time at 46 enemies + a keg chain** | 1.9 ms sim, 7,937 canvas calls, 60 fps on the dev box | 60 fps on the tester's machine, which is the one that reported lag |
| 4 | **Hours to parity** | — | honest count, including the harness |

And two conditions that are not numbers but decide it just as much:

- **Where does it host?** Threads need `SharedArrayBuffer`, which needs COOP/COEP
  headers, which GitHub Pages cannot set. Either the export is single-threaded or
  the game moves off Pages. Both are fine; neither is free, and it should be a
  decision rather than a discovery.
- **What replaces the 61 checks?** They survive as *ideas* — headless Godot with
  GUT can assert every one of them — but not as code. A port that reaches feature
  parity without them is a step backwards in the only thing that has reliably
  caught defects in this project.

**My position, plainly.** If the destination is Steam, controllers, real 2D
lighting or mobile, the port is right and the work already started should
continue. If the next milestone is five cold playtests, the browser build gets
there sooner and just got 50% cheaper per frame. These are not in conflict: the
browser build keeps taking playtests and the balance/animation work, and the port
proves itself on the four numbers rather than on enthusiasm. What I would not do
is stop shipping the browser build in the middle of a balance conversation — the
tester's next run is the only thing that tells us whether §1 worked.

---

## 5 · Animation — where the missing cycles come from

The pipeline exists and works; it has been paced rather than blocked. To be
concrete about the answer:

**Aether Loom → Gemini Omni.** `POST /api/jobs` with the approved still, a
motion prompt, an fps and a chroma key; it returns a job id, animates, keys the
plate, and hands back frames. `src/loom-ingest.py anim <job> <manifest_key>`
slices them into an atlas strip, measures the loop, and drops it into
`assets/animations/`. **No engine work is needed** — every character already has
idle/run/attack strips wired, so a delivered strip appears on the next build.

Two things learned the hard way and worth repeating (`ASSET-GENERATION.md` §6b):

- **Run cycles close their loops; idles never do.** Measured: `scrapper_run`
  0.014, `hero_run` 0.039 — against three `hero_idle` attempts at 0.194, 0.205
  and 0.413, which got *worse* as the loop language was hardened. Idles are
  `pingpong: true` in the manifest instead, which makes the boundary exact by
  construction. Do not spend reruns chasing a loop score on an idle.
- **Describe an attack as a change in position, not as an action.** "Performs one
  sabre attack" produced twelve frames of a combat-ready idle. "The blade starts
  high on her right and finishes low across her left hip" is a thing a video
  model can aim at.

Also fixed while doing this: the command in `ASSET-GENERATION.md` §2 was
`-F "motion_prompt=$(cat motion.txt)"`, and every motion prompt in this project
starts with `<FIRST_FRAME>` — which curl reads as *"the value is in a file called
FIRST_FRAME"*. It fails with exit 26 and no explanation. The working form is
`-F "motion_prompt=<tools/motion/scrapper_idle.txt"`.

**The queue, in priority order** (15 cycles): `scrapper_attack`/`idle` (most
numerous enemy, run cycle already exists) → crew (three cycles, six on screen at
once) → `armored_*` and `swarm_*` → `gunner_*` → the Colossus at 512px. One
video generation each, plus reruns for weak loops; budget ~1.8 calls per cycle
from the history so far.

---

## 6 · Acceptance for v12

The harness asserts everything not marked.

**Balance**
- no healing path, alone or stacked, exceeds 12 hp in any one second
- lifesteal alone stays inside 9 hp/s
- FIELD DRESSING pays nothing at full health
- *(needs a tester)* a competent melee run can lose

**Frame**
- a saturated wave-11 frame stays under 11,000 canvas calls
- live transient effects never exceed the cap
- fewer than 200 gradient allocations per frame
- gameplay boundaries identical at every VFX setting

**Presentation**
- the envelope never covers more than 20% of frame height away from the bow
- the airstream is off under reduced motion
- *(needs a tester)* the deck reads as a moving vehicle within ten seconds

**Carried from v11**
- 15 animation cycles; five music slots (hand-made, `MUSIC-BRIEF.md`)
- total payload 34.7 MB against a 30 MB target — art is 24 MB and has never had
  a compression pass
- five cold playtests, a slow laptop, loudness on three systems,
  photosensitivity review of the keg chains
