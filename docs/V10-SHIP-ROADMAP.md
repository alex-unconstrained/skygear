# SKYGEAR v10 — public test release plan

**Status:** proposed scope, to be revised once the v9 playtest is complete  
**Purpose:** make v10 the first build we can confidently put in front of people  
**Supersedes:** the sequencing assumptions in `ROADMAP.md` where they conflict  
**Companion documents:** `AUDIO-SPEC.md`, `ANIMATION-BRIEF.md`,
`skygear-visual-asset-spec-v1.md`, `LEVEL-KIT-BRIEF.md`

---

## 0. The decision

v10 should not be “v9 plus the longest possible feature list.” It should be the
moment SKYGEAR becomes coherent.

The game already has enough systemic surface area to support a strong public
test:

- one captain with a free automatic Ember Cleave;
- eight draftable skill shapes, including three passive shapes;
- four elements, producing 32 draftable shape × element combinations;
- four skill slots and a card draft that changes those skills;
- three lanes, allied crew, friendly cannons and an objective at the stern;
- twelve authored waves, with push waves at 4, 8 and 12;
- five boarder archetypes, a boarding hulk and a finale boss;
- a painted storm-dusk visual direction, procedural fallbacks and a sample-over-
  synth audio system.

The opportunity is not another major system. The opportunity is to make the
systems above read, feel and sound like one deliberate game.

### The v10 promise

Within the first minute, a new player should understand:

1. **I am the captain.**
2. **The Boiler is what I defend.**
3. **The three lanes show where the ship is failing.**
4. **My basic attack is automatic; my choices are movement, aim, dash, active
   skills and the build I draft.**
5. **When a push ship opens, leaving the Boiler to destroy it is the objective.**

Within one run, the player should experience:

- a captain who feels precise and forceful;
- a ship that feels alive and under siege;
- a build that becomes recognisably theirs;
- three clear escalation beats at waves 4, 8 and 12;
- a finale that feels authored rather than merely more crowded;
- a failure they understand and a restart they want to click.

### What “public test” means

v10 is ready when we can share one URL without coaching the player, explain away
no known rough edges, identify the exact build from a screenshot, collect useful
feedback from a complete run, and reproduce failures.

It is not a commercial 1.0. It does not need accounts, monetisation, a second
captain or months of meta-progression.

---

## 1. Evidence from the v9 baseline

This plan is based on the v9 source and repository as of 26 July 2026.

### What is solid

| Area | Current strength |
|---|---|
| Build discipline | Only the live build is regenerated; six shipped builds are hash-frozen. URLs carry deterministic build IDs. |
| Core combat | 120 Hz simulation, input buffering, automatic basic attack, hit-stop, trauma shake, knockback, crits and responsive dash. |
| Build system | Active and passive skills use the same shape × element model and the same draft/card machinery. |
| Lane game | Three authored lanes, friendly cannons, allied crew, cross-passages, push hulks and off-screen lane information. |
| Failure structure | Captain death and Boiler destruction are explicit loss conditions; boss death ends the campaign. |
| Degradation | Missing art and audio fall back cue-by-cue rather than breaking the game. |
| Performance guards | 64 live-enemy throttle, 400-particle fixed pool and an F3 frame-time display. |

### What is provisional

| Area | Audit result |
|---|---|
| Still art | **32 of 67** manifest images are delivered. **35 are missing**, concentrated in ground readability, VFX, UI and secondary props/environment. |
| Animation | Two run cycles exist: captain (13 frames) and Scrapper (15). The other 17 planned cycles are absent. The existing 28 loose PNGs cost about **3.9 MB**. |
| SFX | **5 SFX cue families** and one music track are delivered against a 55-entry audio manifest. |
| SFX quality | Every delivered WAV is exactly at its duration cap. `cannon_fire`, `cannon_down` and `crew_muster` clip; `crew_muster` ends mid-sound; `hit` and `cannon_hurt` require about +13 dB and +18 dB of rescue gain. |
| VFX | The procedural language is feature-complete, but the declared ground/VFX art is missing, effect priority is implicit, and full-screen flashes/shake have no reduced-effects controls. |
| Onboarding | The title screen is a two-column instruction panel. There is no playable first-minute tutorial. |
| Settings | Master volume is keyboard-only. There are no music, active-SFX, ambience, UI, mono, reduced-motion or reduced-flash controls. |
| Test evidence | End-screen stats exist, but runs are not seeded, persisted or copyable. There is no public feedback path. |
| QA | The build freeze is tested, but there is no checked-in simulation smoke suite, browser flow test, audio stress capture or visual regression set. |

### What v9 must answer before v10 scope locks

The v9 test is not a ceremonial milestone. It decides what v10 keeps.

1. Do passive shapes reduce input burden while preserving interesting choices,
   or do they feel like invisible damage?
2. Does the one combat track increase momentum, or create fatigue over a full
   run?
3. Can a new player understand the push objective without explanation?
4. Can the player read which lane is failing while fighting somewhere else?
5. Are four eventual skill slots exciting or cognitively expensive?
6. Does the first run fail at a fair point? Is the cause understood?
7. Does the finale feel like a culmination or just a dense wave?
8. Does painted art improve the game consistently, or do procedural/painted
   transitions pull the player out of it?

---

## 2. The v9 test protocol

Do not tune v10 from survey adjectives alone. Observe behaviour, record the run,
then ask why.

### Cohorts

- **Cold players:** have not seen SKYGEAR and receive only the URL.
- **Returning players:** know an earlier build and can compare.
- **Internal stress run:** deliberately creates the busiest legal wave state,
  low Boiler health, multiple cooldowns and a push.

Five cold sessions are more useful than fifty coached clicks. Ten is enough to
show repeated onboarding failures.

### What to capture

| Moment | Measure |
|---|---|
| Page open → run start | Time and hesitation on the title screen |
| Run start → first move | Whether WASD is discovered without help |
| First active available → first cast | Whether aim/key model is understood |
| Dash | First use; whether it is understood as mobility and invulnerability |
| First draft | Time to choose, rereads, whether the player can explain the choice |
| Wave 4 push | Time to notice the hulk, whether the player leaves the Boiler, whether the objective is understood |
| Lane loss | Whether the player identifies which lane and why it matters |
| Failure | Wave, cause, last 30 seconds, whether the player predicted the loss |
| End screen | Immediate restart, pause, or exit |

### Questions after the run

Ask these in order; do not teach through the question.

1. “What were you trying to protect?”
2. “What changed on the push wave?”
3. “What was your build?”
4. “Which sounds or effects gave you useful information?”
5. “What killed the run?”
6. “What would you try differently next time?”
7. “Was there a point where the screen or sound became unreadable?”

### Proposed evidence targets

These are tuning targets, not marketing claims.

- At least 80% of cold players can state the objective after one minute.
- At least 80% use dash by the end of wave 3.
- At least 70% identify the open hulk as the push target within five seconds on
  their second push encounter.
- First-run median reaches waves 5–8.
- A player familiar with the controls wins roughly 25–40% of runs.
- At least half of completed sessions choose to restart or explicitly say what
  they would build next.
- No critical event is communicated only through colour, sound or off-screen
  world geometry.

### Required run report

Before broad testing, make the end screen able to copy:

```text
SKYGEAR v10 <build>
seed=<seed> result=<victory|captain|boiler> wave=<n> time=<seconds>
kills=<n> damage=<n> best_chain=<n> dashes=<n>
loadout=<shape/element per slot>
cards=<ordered card ids>
boiler=<remaining/max> captain=<remaining/max>
fps_p50=<ms> fps_p95=<ms> worst=<ms>
```

Store the last ten reports in `localStorage`. A server is not required for v10.
Add a visible feedback link next to “copy report”; do not silently collect
personal data.

---

## 3. v10 product pillars

Every v10 task must serve at least one pillar.

### P1 — Readable battle

The player can identify threat, ownership, target area and consequence while the
screen is busy. Telegraphs and objectives win over decoration.

### P2 — Captain agency

Movement, aim, dash and active casts feel immediate. Automatic and passive
damage never make the player feel like a spectator.

### P3 — A ship under pressure

Brass, timber, iron, steam, storm and strain form one sensory world. The deck is
not an abstract arena with steampunk pictures on it.

### P4 — A run with an arc

Waves 1–3 teach, 4 tests the push, 5–7 combine, 8 escalates, 9–11 compress, and
12 resolves. The draft creates a build story between those acts.

### P5 — Public-test trust

The build loads, runs smoothly, exposes settings, survives missing assets,
reports its version, and produces useful failure evidence.

---

## 4. Scope: must, should, could, will not

### Must ship in v10

- A tested 12-wave campaign with a legible three-act difficulty curve.
- First-minute contextual onboarding.
- Clear wave 4/8/12 push-objective communication.
- A finale with authored phases and a clean victory beat.
- Balance pass over all eight draftable shapes × four elements.
- Complete feedback contract for cast → contact → consequence.
- Production-quality critical SFX set and a corrected audio pipeline.
- VFX hierarchy, element grammar and reduced-effects settings.
- No procedural/painted snapping on the captain, crew, common enemies or
  interactive lane objects.
- Separate master/music/gameplay/ambience/UI volume controls plus mute and mono.
- Reduced camera shake, reduced flashes and low-VFX settings.
- Seeded runs, copyable reports and last-run persistence.
- Automated simulation smoke tests and asset/audio validation.
- Desktop browser performance and compatibility sign-off.
- Release checklist, feedback link and frozen v9.

### Should ship

- Captain, Scrapper and crew idle/run/attack animation sets.
- Remaining enemy attack/idle animation where frequency justifies payload.
- Storm and ship ambience beds.
- Push and boss music treatment derived from the same musical identity.
- Difficulty choice between intended and assisted play.
- UI scale option and remappable action keys.
- Low-health and Boiler-critical presentation that is urgent without flashing.

### Could ship if all musts are green

- Short captain barks with an eight-second global floor.
- One or two wave modifiers using existing enemies.
- A post-victory “try another build” recommendation.
- Optional controller support.
- A lightweight codex showing discovered shapes/elements.

### Explicitly not v10

- Multiplayer or co-op.
- Accounts, cloud saves or a global leaderboard.
- Mobile/touch controls.
- A second captain.
- Endless mode.
- Meta-progression, currencies or unlock trees.
- A relic system.
- Procedural maps.
- Full narrative voice-over.
- Seven independently generated music tracks.

These are not bad ideas. They are ways to postpone the moment the existing game
becomes excellent.

---

## 5. The combat feedback contract

SFX and VFX should be authored together against one event sheet. A cue is not
done because its WAV is attractive or its particles look good in isolation.

Every combat action has five possible stages:

| Stage | Player question | Required feedback |
|---|---|---|
| Anticipation | What is about to happen? | Telegraph shape, charge motion, readable enemy mechanism |
| Commit | What did I do? | Shape body SFX, cast pose, muzzle/weapon VFX |
| Contact | Did it connect, where and how hard? | Impact transient, hit-stop, flash/rim, sparks, damage number |
| Consequence | What state changed? | Knockback, death, burn/slow/stun/steam state, HP change |
| Recovery | When can it happen again? | Animation recovery, cooldown ring, ready tick |

No stage should accidentally fire twice. “Cast” and “hit” are different; a miss
gets commit without contact.

### Event priority

| Priority | Events | Rule |
|---|---|---|
| 0 — survival | Captain hurt/low, Boiler hurt/critical, cannon down, push objective, boss telegraph | Never culled; remains perceptible off-screen |
| 1 — agency | Player cast, crit, successful dash timing, draft/slot unlock | Dominant near the captain |
| 2 — tactical | Enemy wind-up, cannon fire, heavy enemy death, status application | Voice/effect limited by threat and distance |
| 3 — texture | Crew chatter, routine deaths, debris, idle steam, distant mechanisms | First to thin under load |
| 4 — ambience | Storm bed, decorative sparks, background motion | Never competes with a survival cue |

When everything is loud or bright, nothing is important. Priority is a mix and
rendering rule, not a label in a spreadsheet.

---

## 6. VFX direction

### 6.1 Visual thesis

**Hand-painted mechanical magic against a dark storm deck.**

The world is muted and weighty. Gameplay light is saturated, graphic and brief.
Effects use the same flat fields, inked edges and two-source lighting as the
sprites. Avoid photoreal smoke simulations, soft bloom soup and undirected
particle fountains.

Riot’s VFX guidance frames the central trade correctly: satisfaction and
gameplay clarity must coexist, and every effect must be identifiable both as a
game action and as belonging to its source. See
[Riot Games — Visual Effects](https://www.riotgames.com/en/artedu/visual-effects).

### 6.2 Information order

Render and thin VFX in this order:

1. Enemy danger area and timing edge.
2. Objective state and lane-loss indicator.
3. Player target/cast geometry.
4. Impact point and consequence.
5. Persistent status.
6. Debris, smoke, embers and atmosphere.

Low VFX removes rows 6 then 5. It never removes rows 1–4. Riot applies the same
principle in performance scaling: cosmetic wisps can change by quality, but the
gameplay boundary must remain stable
([VALORANT gameplay clarity](https://www.riotgames.com/en/news/valorant-shaders-and-gameplay-clarity)).

### 6.3 Shape grammar

Element colour changes the material; shape must remain readable without colour.

| Shape | Silhouette and timing |
|---|---|
| Cleave | One hard 140° leading arc, narrow bright edge, fast taper. Contact sparks occur at targets, not along the whole sweep. |
| Lance | Straight rail with a bright travelling head and a terminal punch. Width remains honest to collision. |
| Gale | Broad wedge built from two pressure fronts. Interior stays transparent enough to see enemies. |
| Mortar | Ground reticle during travel, descending tick/marker, compact radial impact. The reticle and damage radius are identical. |
| Whip | Discrete target nodes joined by one angular chain. Do not turn the whole route into a thick lightning cloud. |
| Beam | Stable core/body/edge stack. Contact blooms only at the endpoint/targets; the sustained body does not strobe. |
| Field | Faint persistent perimeter with slow circulation. Damage ticks create local contacts; the whole field does not flash. |
| Pulse | Quiet inward charge ring, one outward detonation, clean fade. Timing teaches the autonomous cadence. |
| Sentry | Permanent footprint and readable barrel direction. Short muzzle/contact events; expiry is a fade and mechanical wind-down. |

### 6.4 Element grammar

| Element | Visual material | Persistent state |
|---|---|---|
| Ember | Burnt orange body, pale-hot core, sparse square/inked embers | Up to three small stack marks; no full-body fire blanket |
| Frost | Aether-teal crystalline edge, hard facets, cold vapour only at contact | Thin slowed ring and occasional facet glint |
| Arc | Blue-white hairline forks, abrupt angular branching, minimal glow body | Three orbiting cog/spark marks for stun |
| Steam | Lavender-white pressure ribbon, wet edge, directional venting | Short shove vector and dissipating joint vapour |

Friendly/hostile identity may not rely on hue. Hostile telegraphs use broken,
outward-toothed edges and danger-red timing marks; player areas use continuous
brass/element rims. This preserves meaning for colour-vision differences.

### 6.5 Impact tiers

| Tier | Example | Hit-stop | VFX |
|---|---|---|---|
| Light | crew hit, burn tick, swarm contact | none | 2–4 sparks, tiny rim flash |
| Standard | basic cleave, Scrapper hit | current threshold rules | contact burst, short silhouette flash |
| Heavy | mortar, cannon, Armored death | 30–55 ms | deck ring, debris, directional smoke |
| Event | hulk grapple/break, boss phase, victory | bespoke | authored composition, controlled screen treatment |

Do not scale every effect linearly with damage. Event effects need different
composition, not merely more particles.

### 6.6 Screen-space safety and settings

The current full-screen white flash can cover the entire viewport at high
opacity. v10 should replace routine full-screen flashes with local radial light
and reserve any screen wash for a single major event.

Ship:

- camera shake: 0 / 50 / 100%;
- reduced flashes;
- low VFX;
- opaque UI-panel backgrounds;
- no pulsing low-health treatment above three luminance changes per second.

Xbox’s guidance recommends avoiding camera shake or providing a way to disable
it, and allowing moving/flashing distractions to be reduced
([XAG 117](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/117)).
Photosensitivity guidance flags large-area flashes occurring more than about
three times per second and gives saturated red a stricter threshold
([XAG 118](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/118)).

### 6.7 VFX asset and engineering backlog

**Gameplay-bearing painted assets currently missing:**

- `ground/rune_enemy.png`
- `ground/rune_enemy_filled.png`
- `ground/rune_player.png`
- `ground/shadow_blob.png`
- `fx/puff_steam.png`
- `fx/puff_smoke_dark.png`
- `fx/burst_impact.png`
- `fx/bolt_tesla.png`
- `fx/slash_arc.png`
- `fx/ember_particle.png`

The three decorative decals are useful but lower priority than telegraphs:
`decal_scorch`, `decal_oil`, `decal_gear_scatter`.

Engineering work:

- assign every `fx.kind` a priority and low-VFX behaviour;
- enforce per-kind and global spawn budgets;
- coalesce repeated contact effects inside a short time/spatial window;
- expose live particle counts and dropped effects in F3;
- separate screen wash, camera trauma and world particles into independent
  settings;
- add screenshot fixtures for each shape × element at cast/contact/state;
- test VFX with art enabled, art disabled and low VFX.

### 6.8 VFX acceptance

- Collision area and rendered area agree at near and far deck depth.
- A screenshot in greyscale still distinguishes shape and ownership.
- Telegraph remains visible beneath player effects and crowds.
- Four simultaneous builds do not hide the captain or Boiler.
- Low VFX preserves every gameplay boundary.
- No effect causes a repeated large-area flash.
- Wave 12 stays above the performance floor on target hardware.

---

## 7. SFX and mix direction

### 7.1 Sonic thesis

**A working brass airship fighting for pressure.**

SKYGEAR should sound handmade, close and material:

- brass mechanisms for friendly agency;
- iron strain and furnace mass for boarders;
- timber body for the ship beneath every heavy event;
- pressure and steam for motion;
- aether accents for element identity;
- storm air for scale and negative space.

The visual direction is painted rather than photographic. The audio equivalent
is designed rather than documentary: recognisable real materials, simplified
into bold transients, bodies and tails.

### 7.2 The three-layer recipe

Most important cues should be designed as:

1. **Identity transient** — what happened, audible in the first 20–40 ms.
2. **Scale/body** — how heavy and close it was.
3. **Material tail** — brass, timber, iron, steam or aether; short enough not to
   mask the next action.

Examples:

- friendly cannon = valve snap + low body + timber/steam recoil;
- Scrapper death = spring break + small metal body + two or three gear drops;
- Boiler hit = hard onset + resonant brass body + pressure warning tail;
- crit = normal contact plus one bright, pitch-stable confirmation accent.

Do not put all three layers into every routine crew hit. Density is part of
scale.

### 7.3 Friendly, hostile and objective grammar

| Source | Grammar |
|---|---|
| Captain | Closest, driest, fastest transient; brass and pressure; stable centre image |
| Crew/cannons | Timber-supported friendly metal; lighter than captain; spatial |
| Boarders | Iron, grinding starts, furnace/noise components; less pitch-stable |
| Hulk/boss | Structural hull resonance, chain strain and sub weight; wide event tail |
| Boiler | A unique pitched brass resonance and pressure alarm; never shared |
| UI | Miniature dry brass mechanisms, short and pitch-consistent |

Off-screen danger remains audible. Off-screen routine texture may fall away.

### 7.4 Stop generating to the final duration

The first batch shows why. Every WAV is exactly at its cap; several clip or end
mid-event. The duration table in `AUDIO-SPEC.md` should remain an **edited final
budget**, not a generation instruction.

New production method:

1. Generate or record a clean natural master with 0.5–1.0 seconds of safe tail
   beyond the expected edit.
2. Ask for dry, isolated material and no music.
3. Generate 4–6 candidates; reject identity drift before editing.
4. Edit the onset, body and tail manually.
5. Apply 3–8 ms onset/exit fades only where they do not soften the transient.
6. Deliver at least three true variants for the highest-frequency cues.
7. Loudness-match the edited result, not the raw generation.
8. Listen in a captured wave, not only in isolation.

Never rescue a master by adding +18 dB in the runtime. That raises generation
noise and teaches the mix around a bad source.

### 7.5 Intake and loudness

Masters:

- 48 kHz, 24-bit;
- mono for positioned one-shots, stereo for ambience/music;
- no leading silence;
- no sample clipping;
- at least 3 dB peak headroom before encoding;
- source prompt/model/date and edit notes retained in sidecar metadata.

Do not normalize every 80–200 ms one-shot to the same LUFS value. Loudness
integration is not a useful equality rule for radically different short
transients. Use peak, RMS/short-term loudness, crest factor and listening
against category references during intake.

Measure the **whole game output** over a representative run. Sony’s game-audio
recommendation specifies -24 ±2 LKFS for home systems, -18 ±2 for portable
systems, no more than -1 dBTP, and at least 30 minutes of representative
measurement; it explicitly says to measure the title as a whole rather than
music/SFX/dialogue independently
([ASWG-R001](https://gameaudiopodcast.com/ASWG-R001.pdf)).

For this browser game, start with an inferred compromise target of **-20 LUFS
±2, maximum -1 dBTP** for the default mix, then verify it on laptop speakers,
headphones and a living-room output. The number is a calibration point, not a
substitute for the mix.

### 7.6 Mixer changes

Current:

```text
master
├── music
├── sfx
├── ui
└── voice
```

v10:

```text
master
├── music
├── gameplay
│   ├── survival/objective
│   ├── player
│   ├── enemy
│   └── lane
├── ambience
├── ui
└── voice
```

Player controls:

- master;
- music;
- gameplay SFX;
- ambience;
- UI;
- mono output;
- mute.

Xbox audio accessibility guidance specifically recommends separate controls for
music, active gameplay effects and background/ambient effects, plus spatial and
mono options
([XAG 105](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/105)).

Use the master compressor as a peak guard, not the thing making the game loud.
The current -14 dB threshold at 8:1 is likely doing mix work continuously during
crowds. Tune from representative captures and expose compressor reduction in
the debug display. Aim for less than 3 dB of gain reduction during normal
combat; major events may touch more briefly.

### 7.7 Voice limiting and threat priority

The current per-cue caps are a good start but cannot control aggregate clutter.

Add:

- global gameplay voice budget: start at 24 physical one-shots;
- category budgets;
- priority from the event table in §5;
- quietest/farthest/lowest-priority stealing;
- no-immediate-repeat shuffle for variant pools;
- 30–120 ms retrigger floors by cue;
- hit aggregation for multi-target actions;
- explicit stop/fade for every loop.

Commercial middleware uses playback limits, priority and virtual/culled voices
for exactly this reason
([Wwise voice limiting](https://www.audiokinetic.com/en/library/edge/?id=concept_virtualvoices.html&source=SDK),
[FMOD max instances and stealing](https://www.fmod.com/docs/2.03/studio/mixing.html)).
FMOD’s multi-instrument guidance also defaults to shuffled variants to reduce
obvious repetition
([FMOD instruments](https://www.fmod.com/docs/2.03/studio/working-with-instruments.html)).

The current `vary` field should be made unambiguous. It is described as a
fraction but converted to cents by multiplying by 1200; `0.06` therefore
produces ±72 cents, about ±4.2% frequency. Rename it to `pitchCents`, and use
small category-specific ranges:

- routine metal/crew: ±35–55 cents;
- impacts/deaths: ±20–40 cents;
- UI/critical objective cues: 0–15 cents;
- musical confirmations: no random pitch.

### 7.8 Dynamic mix

Mix priority should respond to threat, not raw event count:

- captain hurt and Boiler/cannon loss briefly lower routine enemy/crew texture;
- push grapple and hulk break lower music by 3–4 dB;
- critical telegraphs receive space by attenuating low-priority transients, not
  by making the telegraph painfully loud;
- UI and survival cues stay outside SFX crowd compression;
- ambience yields first;
- no per-hit music ducking.

Wwise’s current HDR guidance describes volume as an importance relationship and
specifically recommends using threat variables so less relevant enemies affect
the mix less
([Wwise HDR mixing](https://www.audiokinetic.com/en/blog/wwise-hdr-overview-and-best-practices-for-game-mixing/)).
We do not need Wwise to apply the principle.

### 7.9 v10 SFX production order

Do not commission all 48 SFX slots at once.

**Batch A — one combat vertical slice**

- `shape_cleave`
- `elem_ember`
- `hit` (five clean variants)
- `crit` (three)
- `hurt`
- `dash`
- `death_light` (three)
- `telegraph`

Exit: one minute of basic combat sounds finished, varied and fatigue-tested.

**Batch B — lane comprehension**

- regenerated `cannon_fire`, `cannon_hurt`, `cannon_down`
- regenerated `crew_muster`
- `crew_attack`, `crew_down`
- `boiler_hurt`, `boiler_critical`
- `hulk_grapple`, `hulk_hit`, `hulk_break`

Exit: the player can understand a lane crisis with the camera elsewhere.

**Batch C — build identity**

- remaining five active shape bodies;
- Field, Pulse and Sentry bodies;
- Frost, Arc and Steam tails;
- mortar landing;
- beam start/loop/end.

Exit: every shape is identifiable before the element tail and every element is
identifiable across shapes.

**Batch D — world/UI**

- storm and ship beds;
- wave start/clear;
- pickup, ready, hover, click, card deal/pick, slot unlock;
- heavy death, drone shot, slam, boss roar, climb/crossing.

### 7.10 Music for v10

Use the v9 test to decide whether the current track belongs.

Recommended v10 scope:

- one corrected core combat composition;
- one push intensity layer or closely related push version;
- one boss/finale treatment;
- victory and defeat stings.

All share key, motif, instrumentation and mix space. Do not independently prompt
seven unrelated tracks and ask crossfades to create coherence afterward.

### 7.11 SFX acceptance

- A 20-minute run creates no obvious repeated variant pattern.
- Routine contact remains satisfying with music and ambience muted or enabled.
- Wave 11 never clips and survival cues remain intelligible.
- A cannon loss is locatable with the camera in another lane.
- Mono mode preserves all critical information.
- No loop survives title/restart/tab suspension.
- Master output passes the agreed loudness/true-peak capture target.
- Every delivered cue falls back cleanly when its file is removed.

---

## 8. Art and animation completion

### 8.1 Critical still-art rule

v10 does not require every decorative prop to be painted before testing. It does
require zero style snapping on:

- captain;
- crew;
- Scrapper, Swarm, Gunner, Armored and boss;
- cannon intact/destroyed;
- hulk sealed/open/destroyed;
- cargo walls/cross-passages;
- every gameplay telegraph and HUD skill icon.

Missing distant clouds or a rope coil is survivable. A captain changing art
style every attack is not.

### 8.2 Still priority

1. Ground runes, shadow and all skill icons.
2. VFX textures from §6.7.
3. Remaining gameplay props.
4. Portrait/HUD frame/gauge.
5. Secondary deck dressing.
6. Clouds/distant ship.

### 8.3 Animation

Follow `ANIMATION-BRIEF.md`:

- horizontal atlas strips, not loose frames;
- 384 × 384 frames, 512 for boss;
- common crop/foot row per strip;
- engine-side rate;
- still fallback retained.

Priority:

1. captain attack and idle;
2. Scrapper attack and idle;
3. crew run/attack/idle;
4. Armored and Swarm;
5. Gunner;
6. boss.

Convert the two loose run cycles into strips before adding new cycles. Target
12–14 MB for the full 19-cycle set, with critical/common cycles in the initial
load and boss cycles lazy-loaded before wave 12.

### 8.4 Asset loading

Current art loads as one broad set. v10 should stage it:

- **boot:** captain, first-wave enemies, Boiler, common deck/lanes, HUD;
- **during waves 1–3:** crew, cannon states, common animations;
- **before push:** hulk states and push SFX;
- **before later archetype:** heavy/boss art and animation;
- **always optional:** decorative environment.

Show a short in-world loading state only if critical assets are not ready.
Never start a run with the captain still changing between fallback and painted
art.

### 8.5 Visual acceptance

- No white/magenta fringe against `#14121B`.
- Feet and contact shadows remain stable across animation frames.
- Lighting direction does not swim.
- Front/back/attack transitions retain identity and scale.
- A greyscale screenshot keeps captain, crew and hostile silhouettes separable.
- Critical assets fit the agreed initial-transfer budget.

---

## 9. Gameplay and content

### 9.1 First-minute onboarding

Replace the title instruction wall with three ideas:

```text
MOVE — WASD
AIM + CAST — mouse / LMB / RMB / Q / E
DEFEND THE BOILER — cross lanes to stop boarders
```

Teach in play:

1. Spawn in the stern with a short movement prompt.
2. First two boarders enter centre lane; auto-cleave demonstrates itself.
3. First active prompt appears only when a target is in useful range.
4. A harmless incoming telegraph teaches dash.
5. First lane warning points from minimap to world.
6. First draft explains shape × element in one comparison, not a paragraph.
7. Wave 4 introduces the push with objective marker, voice/SFX/VFX and one-line
   instruction.

Prompts disappear once demonstrated and never block input.

### 9.2 Skill/build pass

For every draftable shape × element:

- verify damage path, element application and card modifiers;
- measure single-target and four-target effective DPS;
- test best-case and realistic use;
- give passive power a discount relative to perfect active use;
- ensure each passive has a visible cadence/state;
- prevent draft offers that produce a nonfunctional or redundant early build;
- update title copy: the game no longer has only 24 combinations.

The v9 test decides whether all three passives remain. Do not defend a passive
because it is elegant in code.

### 9.3 Wave arc

| Act | Waves | Job |
|---|---|---|
| I — Boarded | 1–3 | Teach one threat at a time, establish lanes and first build decisions |
| I test | 4 | First hulk push; generous timing; unmistakable objective |
| II — Losing deck | 5–7 | Combine roles, force cross-lane decisions, introduce rail interruption |
| II test | 8 | Faster multi-lane push with heavier escorts |
| III — Last pressure | 9–11 | Shorter recovery, dangerous compositions, no new rules |
| Finale | 12 | Hulk breach → boss phase → clean resolution |

Add encounter identity through timing and composition before adding new enemy
types.

### 9.4 Finale

Recommended authored sequence:

1. Hulk grapples and seals the centre lane.
2. Player breaks plating while reinforcements continue.
3. Colossus boards with an arrival event, not an ordinary spawn.
4. At a health threshold, it changes attack pattern and damages/changes the
   arena presentation.
5. Death stops reinforcements, destroys the hulk and gives two seconds of clear
   sensory release before the victory screen.

The finale must not require a new system that appears only once. It may combine
existing telegraph, push, boss, cannon and lane rules.

### 9.5 Difficulty

Tune the intended curve first. If an assisted mode is needed, change a small set
of legible values:

- captain HP;
- Boiler HP;
- enemy damage;
- dash recharge;
- optional telegraph duration.

Do not secretly change ten systems. Display the selected mode in the run report.

### 9.6 Balance acceptance

- No draftable shape is a trap across all four elements.
- No passive exceeds a perfectly played active in its intended scenario.
- First push teaches; second push tests; final push culminates.
- Death cause matches player explanation in most observed sessions.
- First-time and returning-player target ranges in §2 are met.

---

## 10. UI, settings and accessibility

### Must-have settings

- master, music, gameplay SFX, ambience and UI volume;
- mono audio;
- camera shake 0/50/100;
- reduced flashes;
- low VFX;
- UI scale;
- key reminder and reset defaults.

Persist locally.

### HUD

- Boiler and lane crisis must remain the top information hierarchy.
- Passive slots say `AUTO` and show cadence/state, not a dead keycap.
- Active cooldown, ready and unavailable states use motion/shape/value, not
  hue alone.
- The minimap indicates lane direction, boarder depth, cannon health and push
  objective with redundant shape/icons.
- Damage numbers aggregate under extreme multi-hit density.

### Draft

- Compare current slot → offered replacement/upgrade.
- Show passive/active explicitly.
- Explain shape and element on separate lines.
- Show the actual changed stat, not only flavour text.
- Keyboard and mouse focus must be equally visible.

### End screen

- result/cause;
- ordered build;
- key cards;
- performance summary;
- seed and build;
- copy report;
- feedback link;
- restart and title as separate actions.

Microsoft recommends communicating critical cues through more than one sensory
channel, including spatial audio plus visual indication
([XAG 103](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/103)).
For SKYGEAR, every off-screen audio warning must therefore have a lane/minimap
counterpart, and every visual crisis must have a distinct sound.

---

## 11. Engineering and performance

### 11.1 Do not refactor for aesthetics

The build’s string substitution is brittle, but it currently produces a live
build while protecting frozen builds. A core rewrite is not automatically v10
work. Refactor only where it unlocks a must-ship item or test.

### 11.2 Required engineering

- deterministic gameplay RNG and `?seed=`;
- run report/persistence;
- audio category buses and settings;
- global audio priority/voice budget;
- VFX priority/budget/settings;
- animation strips and staged loading;
- global error capture with build ID and copyable debug text;
- asset/audio manifest validator;
- simulation smoke harness;
- hosted browser smoke flow;
- performance capture beyond instantaneous FPS.

### 11.3 Performance budgets

Proposed desktop min-spec target:

- 60 fps at 1366 × 768 on an integrated-GPU laptop;
- p95 frame time ≤16.7 ms in ordinary combat;
- no sustained frame above 33 ms in wave 12;
- 64 enemies and 400 particles remain hard safety caps unless measurement
  justifies lower values;
- no more than 24 routine physical one-shot audio voices;
- critical initial transfer ≤12 MB;
- total v10 transfer ≤30 MB where possible, with late-wave/decorative content
  deferred;
- decoded asset memory target <200 MB;
- run can begin while noncritical late-wave assets continue loading.

Numbers must be measured on the hosted build with cache cold and warm.

### 11.4 Browser matrix

Test current desktop versions of:

- Chrome;
- Edge;
- Firefox;
- Safari on macOS if available.

For each:

- first audio unlock;
- tab away/resume;
- context loss/reload;
- mouse buttons and context-menu suppression;
- high-DPI canvas;
- 16:9, 16:10 and ultrawide layout;
- slow network and failed optional asset;
- full run or accelerated deterministic smoke.

### 11.5 Automated checks

On every v10 candidate:

1. frozen build hashes unchanged;
2. live source assembles and JavaScript parses;
3. all manifest paths/case match;
4. all PNGs meet dimensions/alpha/budget;
5. all animation strips divide, anchor and loop;
6. all audio files decode and meet channel/rate/peak/tail rules;
7. all shapes × elements execute and apply expected effects;
8. every wave starts, clears and advances;
9. captain/Boiler losses and victory resolve;
10. no console error during title → wave → draft → pause → restart.

---

## 12. Production sequence and gates

### Gate 0 — v9 evidence

**Work**

- run the protocol in §2;
- fix only test blockers;
- collect clips/reports;
- decide passives, music and difficulty targets.

**Exit**

- repeated problems are distinguishable from one-person preference;
- v10 scope decisions are written, not implicit.

### Gate 1 — feedback vertical slice

**Work**

- one captain/Scrapper/crew encounter;
- Ember Cleave and one active;
- critical SFX Batch A;
- shape/element VFX grammar;
- first-minute tutorial;
- settings shell.

**Exit**

- one minute looks and sounds at v10 quality;
- the team agrees on reference quality before mass generation.

### Gate 2 — campaign content lock

**Work**

- tune shapes/passives;
- rewrite wave beats;
- author push and finale sequence;
- seed/report;
- lock collision and telegraph dimensions.

**Exit**

- full campaign works with procedural fallbacks;
- no major rule is still changing.

### Gate 3 — sensory production

Parallel tracks:

- art/animation strips;
- VFX textures and implementation;
- SFX B–D and mix;
- music decision;
- HUD/draft/end screens.

**Exit**

- no critical style snapping;
- full run has complete feedback;
- asset payload remains within staged budgets.

### Gate 4 — hardening

**Work**

- balance sessions;
- min-spec performance;
- accessibility modes;
- browser matrix;
- audio capture/loudness;
- photosensitivity review;
- missing/failed asset tests.

**Exit**

- no P0/P1 bugs;
- all must-ship acceptance criteria pass;
- candidate can run unattended.

### Gate 5 — release candidate

**Work**

- freeze v9;
- build/stamp v10;
- cold-cache hosted check;
- final smoke;
- changelog and feedback path;
- archive exact source/art/audio manifest.

**Exit**

- one URL, one build ID, one known-issues list;
- rollback is a link change, not a reconstruction.

---

## 13. Parallel work without collision

| Track | Owns | Must not change without coordination |
|---|---|---|
| Design/balance | shapes, cards, waves, difficulty, test interpretation | collision/timing after sensory production begins |
| Engine | state, loading, buses, budgets, settings, reports, tests | frozen HTML builds |
| Art/animation | stills, atlas strips, alpha/crop/style QA | manifest names/frame counts after ingest |
| VFX | event sheet, shape/element grammar, effect textures, low mode | gameplay boundary sizes |
| Audio | source palette, editing, variants, mix references, masters | runtime gain as a substitute for rejected masters |
| Release/QA | test plan, issue severity, browser/perf matrix, build archive | scope expansion after content lock |

One canonical event sheet should name each gameplay event and its SFX, VFX,
animation, camera, UI and accessibility response. That prevents five disciplines
from polishing five different interpretations of “heavy hit.”

---

## 14. Risk register

| Risk | Probability / impact | Mitigation |
|---|---|---|
| “v10 is big” becomes uncontrolled scope | High / critical | Must/should/could cut lines; no new system without replacing a must |
| AI art/animation drifts between batches | High / high | Reference strip, prompt/version metadata, review every small batch |
| Audio generation arrives clipped/truncated | Already happening / high | Natural-tail generation, manual edit, rejection instead of rescue gain |
| VFX makes depth/collision less readable | Medium / high | Shape contract, greyscale test, gameplay boundary never quality-scaled |
| Full art/animation payload delays start | High / high | strips, critical preload, late-wave lazy load, transfer budget |
| Passives remove agency | Unknown / high | v9 observation; cadence VFX; balance discount; cut if necessary |
| Music fatigue | Unknown / medium | one-track v9 test; related layers/stings, not seven unrelated tracks |
| Browser audio state/loops break on tab changes | Medium / medium | explicit loop lifecycle and browser matrix |
| Full-screen effects create accessibility risk | Present / high | local light, reduced flash/shake, photosensitivity check |
| Tuning changes after sensory production waste assets | High / medium | Gate 2 content lock before mass production |
| Public feedback is too vague to act on | High / high | seeded report, observed sessions, specific questions |
| Concurrent agents overwrite work | Present / high | track ownership, small commits, inspect dirty files before edits |

---

## 15. Definition of done

### Game

- [ ] New player reaches play without external instruction.
- [ ] Objective, lanes, push and failure cause are understood.
- [ ] All draftable shape × element combinations function.
- [ ] Passives have a visible cadence and acceptable agency trade-off.
- [ ] Twelve waves form an escalation arc.
- [ ] Finale has an authored beginning, phase change and ending.
- [ ] Restart is one clear action.

### VFX

- [ ] Every shape and element has a consistent grammar.
- [ ] Enemy telegraphs win the visual hierarchy.
- [ ] Rendered areas match collision.
- [ ] Statuses are visible without blanketing characters.
- [ ] Low VFX preserves all gameplay information.
- [ ] Reduced flash/shake works.
- [ ] Photosensitivity review passes.

### Audio

- [ ] Critical SFX batches pass edit and in-context review.
- [ ] No runtime rescue gain above a small correction.
- [ ] Variants shuffle without immediate repetition.
- [ ] Voice/global limits hold in wave 11/12.
- [ ] Off-screen lane events are locatable.
- [ ] Mono preserves critical information.
- [ ] Category sliders and mute persist.
- [ ] Whole-run mix meets agreed loudness/peak target.
- [ ] Tab/restart leaves no stuck loop.

### Art/animation

- [ ] No critical actor/object snaps to a different visual language.
- [ ] Animation strips pass size/anchor/loop validation.
- [ ] Captain, Scrapper and crew have complete common-state motion.
- [ ] Critical telegraph/UI art is delivered.
- [ ] Initial and total payload budgets pass.

### Engineering/QA

- [ ] Frozen builds remain byte-identical.
- [ ] Deterministic seed reproduces a run.
- [ ] Copyable run/debug report works.
- [ ] Simulation smoke covers all outcomes.
- [ ] Hosted browser smoke passes.
- [ ] Target hardware meets frame budget.
- [ ] Missing asset/audio fallback passes.
- [ ] No P0/P1 issue remains.

### Release

- [ ] v10 has a deterministic build ID and cache-busted link.
- [ ] Feedback link and known-issues note are visible.
- [ ] Exact source, manifests and candidate assets are archived.
- [ ] Rollback to v9 is verified.

---

## 16. Decisions to make after the v9 test

Recommended defaults are in **bold**.

1. **v10 is a polished public demo**, not an endless/retention update.
2. **One captain, one deck, twelve waves.**
3. Keep each passive only if players can explain its contribution and still feel
   responsible for success.
4. **One musical identity with layers/stings**, not seven isolated generations.
5. **No full voice-over.** Add sparse barks only after the mix works.
6. **Gameplay-bearing art first; decorative completeness second.**
7. **Local run reports plus explicit feedback link**, not silent analytics.
8. Default target: **desktop browser, keyboard/mouse**.
9. Assisted difficulty ships only if the intended curve excludes too many cold
   players.
10. v10 ships when the definition of done passes, not when every could-item is
    finished.

---

## 17. The shortest version

If the plan has to be compressed to ten lines:

1. Test v9 without coaching.
2. Lock passives, music and difficulty from evidence.
3. Teach the game in its first minute.
4. Make waves 4, 8 and 12 unmistakable authored beats.
5. Build SFX and VFX from one event/priority sheet.
6. Reject bad masters; do not rescue them in code.
7. Finish critical art/animation and stage the payload.
8. Add settings, accessibility and reproducible run reports.
9. Prove 60 fps, browser stability and full-run audio clarity.
10. Freeze, smoke-test and share one trustworthy URL.

