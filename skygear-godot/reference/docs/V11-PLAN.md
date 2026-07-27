# SKYGEAR v11 — the plan of record

**Supersedes `V10-PLAN.md` as the live plan.** V10-PLAN stays as the record of
what v10 was for and what it shipped; everything still outstanding from it is
carried forward in §8 rather than restated.

Written 2026-07-27 against v10 (`storm-dusk-v10.html`, frozen at
`d023e211…`). v11 is `storm-dusk-v11.html` and is the only build offered on the
landing page; every earlier build moves to `archive.html`.

---

## 0 · Where this came from

One person who had never seen the game played v10 start to finish and said
this:

> yeah beat it with steam mortooooooor steam i guess gives the healing one idk
> but i had like 12% healing of damage and was unkillable. its fun, i wish it
> was more open, more dashing, more environmental stuff. like the kegs are
> there but dont do anything.

and, separately:

> enemy projectiles also feel hard to track and avoid as a player

That is the entire brief for v11. It contains, in order: a balance failure, a
comprehension failure about which element does what, three requests for more
space and more motion, one dead object, and a legibility failure. Nothing in
this document is here for any other reason.

**The test for v11:** the same player, on a second run, fights at close range
because it is the better way to play — not because they were told to.

### What v11 is not

No new campaign, no second captain, no endless mode, no meta-progression,
relics, currencies, accounts, leaderboards, multiplayer, touch controls,
procedural maps. The §0 cut list from V10-PLAN stands unchanged. v11 adds one
system, changes one number that was wrong, and fixes one thing you could not
see.

---

## 1 · The diagnosis, in order

### 1.1 "12% healing and unkillable" — the balance failure

v10's BLOODSTEAM healed 3% of *all* damage dealt, stacking to 9%, with no
distance condition and no rate limit. Combined with a Steam Mortar — a
long-range AoE that hits six things at once — the optimal play was to stand at
maximum range, hit crowds, and heal more per second than three lanes of
boarders could remove. The tester was right, and they found it by playing
normally rather than by trying to break it.

Two things were wrong, and only one of them is the number:

1. **Healing did not care about risk.** Damage at 600 units healed exactly as
   much as damage at 60.
2. **Healing had no ceiling.** A build that doubles your damage doubles your
   healing, so the moment incoming damage per second stops growing faster than
   your damage, the fail state is gone for the rest of the run.

### 1.2 "I wish it was more open, more dashing"

Measured on v10's deck: 1560 units across, three lanes, cargo runs 120 units
thick, two gaps in 2320 units of depth. A lane's walkable width was 388 units —
about two and a half body-lengths — and a captain committed to the bow of one
lane had to walk 900 units to answer a push two lanes over. One dash charge, on
a 1.15s cooldown, with a dash that did nothing on contact unless you had drafted
an epic card for it.

### 1.3 "the kegs are there but dont do anything"

Literally true. `PROP_LAYOUT` put barrels, crates and lanterns on the deck, and
`SOLID_PROPS` made them walls. That was their entire behaviour, in eleven
versions.

### 1.4 "enemy projectiles feel hard to track"

Three separate causes, all of them ours:

- Enemy bolts were drawn in `PAL.tesla` (#7ADCFF) — the same colour family as
  the player's own teal. Everything hostile in this game is oxblood-to-orange
  and this was the one thing shooting at you that was not.
- No ground shadow. In a three-quarter projection an object drawn in the air
  with no mark on the deck has no position: you cannot tell whether it passes in
  front of you or through you.
- No trail. A 7px dot at 300 units/second reads as a flicker.

---

## 2 · What v11 does

### Block A — the deck fights back

Three prop types get hit points and a death, and every player shape, the dash,
and *enemy fire* can damage them.

| Prop | HP | What it does |
|---|---|---|
| **Steam keg** (was `barrel`) | 34 | Lights a 0.45s fuse — hissing, shaking, rimmed in steam-white with the blast radius drawn on the deck — then detonates: 78 damage and 380 knock in a 175 radius, to **everything**, including you (26). |
| **Crate** / **crates** | 26 / 40 | Bursts into salvage: one 12hp pickup, half the time a second at 8. |
| **Lantern** | 12 | Spills a burning field: 30 dps over 78 units for 6s. And the deck goes dark where it stood. |

Decisions inside this that are not obvious:

- **The fuse is the design.** A keg that detonates on the frame it dies is a
  trap; a keg with 0.45s of fuse is a weapon you aim by moving. It also makes
  chain reactions resolve without recursion — a keg caught in a blast lights its
  own fuse and goes on the next frame — and it gives a player standing next to
  one a fair chance to leave.
- **Kegs hurt you.** 26 damage on a 100hp captain, and dash i-frames make it
  free if you are moving. A weapon with no downside is scenery with a bigger
  particle budget.
- **Kegs do not hurt the Boiler.** The objective you lose by is not allowed to
  be destroyed by the ordnance stacked next to it; the prop layout already keeps
  props 190 units clear of it, and this closes the last 15 units of that gap.
- **The crew re-stow the deck between waves.** Every destroyed prop is restored
  on `startWave`. Without it, the whole system is a wave-1 novelty and the deck
  is bare furniture by wave 4.

### Block B — pressure, the vent, and healing that means something

One new gauge, shown under the health bar and as a ring at the captain's feet.

- It fills from damage you deal **inside your own reach** (210 units — the
  Cleave's range plus slack), at 0.85 points per point of damage.
- It also fills at 6/s whenever two or more boarders are crowding you, so it is
  legible before a new player has connected it to their own hits, and so wading
  in with everything on cooldown is still worth something.
- It bleeds off at 14/s, 1.2s after you leave.
- **At 100 it vents**: 40 damage and 340 knock in a 215 radius, and **it heals
  you 15**. Then it resets, with a 1.1s floor between vents.

That is the answer to both halves of §1.1 at once. Healing is now something you
walk into a crowd to earn, on a fixed cadence that does not scale with your
damage stat, and the reward for closing is that the thing trying to kill you is
thrown off you.

Everything else in the healing economy is rebuilt around it:

| | v10 | v11 |
|---|---|---|
| BLOODSTEAM | 3% of all damage, cap 9% | **4.5% of damage dealt inside 210 units**, cap 13.5% |
| Lifesteal ceiling | none | **9 hp/second**, as a refilling budget rather than a stack cap |
| Close kills | nothing | 16% chance of 8hp salvage, +9 pressure, and 0.30s off the dash cooldown |
| Slow healing | `regenPerWave: 4` only | plus FIELD DRESSING: 1.5/s while pressure is above half |

The rate limit is a budget, not a stack cap, deliberately: stacking cards is
supposed to be how you get stronger. What is not allowed is healing faster than
the deck can hurt you, forever, from safety.

**Five new cards**, all of them levers on systems that run without any card, so
a run that never sees one plays the same game: SAFETY VALVE (+8 vent heal),
OVERPRESSURE (+50% vent damage, +15% radius), HAIR TRIGGER (+30% pressure
gain), FIELD DRESSING (1.5/s above half), POWDER MONKEY (+40% keg damage, and
their blast stops hurting you).

### Block C — more open, more dashing

| | v10 | v11 |
|---|---|---|
| Deck width | 1560 | **1680** |
| Cargo run thickness | 120 | **96** |
| Walkable lane width | 388 | **452** |
| Cross-passages | 2 | **3** (a new one aft, between the mid passage and the open base) |
| Passage depth | 190 / 210 | **230 / 250 / 210** |
| Dash charges | 1 | **2**, from the first second of the run |
| Dash cooldown | 1.15s | **1.00s**, minus 0.30s per close kill |
| Dash damage | 0 (60 with an epic card) | **30 base** |
| Dash through a keg | walks into a wall | **lights it** |

Boarders and crew remain lane-clamped. The extra space and the extra passage are
the player's mobility budget and nobody else's — the lane structure is what
makes committing to a lane mean something and it is not being loosened.

### Block D — enemy fire you can read

- Bolts are hostile-coloured (oxblood core, ember body, hot rim), 10px instead
  of 7, and **18% slower**. Damage is unchanged.
- Every bolt casts a **ground shadow** — the single biggest legibility win
  available in a three-quarter view.
- Every bolt carries a **nine-sample trail** that fades from ember to hot gold,
  so its direction is readable in one glance rather than two frames.
- A shooter's windup now draws its **firing line** on the deck: dashed, broken,
  travelling, in danger red, for the whole 0.4s telegraph. Every hostile
  telegraph in this game is broken-edged and outward-toothed; this one was
  missing.

### Block E — audio and VFX

Audio delivered with v11:

- **Two new music tracks.** `The Final Stand` becomes the boss loop (113.0s) and
  its sparser variant becomes waves 9–11 (88.7s), so the finale arrives as the
  full arrangement of the theme the last three waves have been playing. Both are
  crossfade-looped out of their sustained middles like `combat_low`, because
  neither is authored to loop. `Brass Skies Up (Remix)` turned out to be
  byte-identical to the `combat_low` already shipped, so it is already in.
- **Five new SFX cues**, each with a procedural voice now and a sample slot for
  later: `keg_fuse`, `keg_blow`, `crate_break`, `lantern_break`, `vent`. The
  keg blast is deliberately duller and lower than the player's own STEAM cue so
  a Steam build setting off a chain does not mask itself.
- The remaining 49 SFX cues and the voice work are specified in
  **`VOICE-BRIEF.md`**, which is generation-ready the moment an ElevenLabs key
  exists on the machine.

VFX, against the §4 event sheet — anticipation, commit, contact, consequence,
recovery:

| Beat | What v11 adds |
|---|---|
| Anticipation | keg fuse: strobe, shake, rising plume, and the blast radius drawn on the deck; the shooter's firing line |
| Commit | vent: a ground ring that expands at the speed the damage did, so what you see is exactly what was hit |
| Contact | prop hit flash reuses the same white tint every damageable thing in the game already gets |
| Consequence | lantern fire pools; the deck goes dark where a lantern stood; salvage that reads green-brass, never violet, because violet promises a card |
| Recovery | the pressure ring at the captain's feet tightens as it fills and flashes white at full |

Deferred deliberately: heat shimmer over fire pools (a full-screen displacement
pass for one prop type), per-bolt light on the deck (needs a light buffer the
renderer does not have), and dash afterimage smearing (the afterimages exist;
smearing them needs a second sprite pass and buys less than the bolt trail did).

---

## 3 · Numbers, in one place

All in `TUNING` at the top of `_core_patched.js`, all behind `PRESET.reactive`
so the ten builds before this one still describe exactly what they shipped as.

```
close.range              210     what counts as close (Cleave range + slack)
close.pressurePerDmg     0.85    gauge points per point of close damage
close.pressureIdle       6/s     while two or more boarders crowd you
close.pressureDecay      14/s    after 1.2s of grace
close.vent               15 heal · 40 dmg · 215 radius · 340 knock · 1.1s floor
close.scrapChance        0.16    a close kill drops 8hp salvage this often
close.dashRefund         0.30s   off the dash cooldown, per close kill
close.lifestealCapPerSec 9       hard ceiling on healing from damage
props.keg                34hp · 0.45s fuse · 78 dmg · 175 radius · 26 to you
props.crate              26hp
props.lantern            12hp · 30dps · 78 radius · 6s
```

---

## 4 · The feedback contract

Unchanged from V10-PLAN §4 and still the shared sheet: five stages
(anticipation, commit, contact, consequence, recovery), five event tiers
(survival, agency, tactical, texture, ambience), culling from the bottom,
gameplay boundaries never scaling with quality settings.

Two v11 additions to the tier table:

| Tier | Event | Rule |
|---|---|---|
| 0 survival | **a lit keg** | never culled, audible off-screen, radius always drawn |
| 1 agency | **the vent** | dominant near the captain; ducks the mix 2dB for 0.35s |

---

## 5 · Acceptance — what "done" means

Runnable checks. The harness (`npm test`) asserts everything not marked.

**The close-quarters loop**
- pressure builds from a close hit and does not build from a distant one
- pressure decays to zero when you disengage
- reaching 100 vents, heals, damages in a radius, and resets
- lifesteal heals on a close hit and heals nothing at range
- healing from damage never exceeds 9 hp in any one second

**The deck**
- every destructible prop can be destroyed by a player shape, by a dash, and by
  enemy fire
- a keg lights a fuse rather than detonating instantly, and detonating damages
  enemies, the player and other kegs
- a lantern leaves a burning field; a crate leaves salvage
- every destroyed prop is back at the start of the next wave
- a destroyed prop stops blocking movement and stops being drawn

**Carried forward from v10, still asserted**
- all 36 shape × element cells execute and deal damage
- twelve waves start and clear; both loss conditions and victory resolve
- a fixed seed reproduces a run; restart is clean
- 42 checks including layout 1280×720–2560×1440 at DPR 1 and 2, Firefox, frozen
  hashes, storage denial, slow line, real input

**Needs a person** *(unchanged, and still the largest item)*
- five cold playtests, a slow laptop, loudness on three output systems,
  photosensitivity review
- specifically for v11: does a second run get played closer than the first?

---

## 6 · Browser, or a port to Godot?

Asked directly, so answered directly: **stay in the browser, and revisit only
when a specific wall is hit.** The reasoning, so it is not relitigated monthly:

**What a port would cost.** Everything in `src/storm-dusk/` is a single
simulation with its own renderer, 11 shipped builds pinned by hash, a headless
harness that drives the real sim, an asset pipeline keyed to a manifest, and an
audio layer with procedural fallbacks for every cue. A port is not "port the
game"; it is re-authoring all six of those and then re-testing what was already
verified. Best case it is weeks; realistically it is the entire remaining budget
for the thing that is actually short — content and playtesting.

**What a port would buy, honestly.** A real editor and scene tree. Physics and
collision you do not maintain. Native export. Better profiling. Skeletal
animation instead of atlas strips. These are genuine, and none of them is what
is currently limiting this game.

**What is currently limiting this game**: 49 unmade SFX cues, 15 unmade
animation cycles, zero cold playtests, and one balance note from one tester.
None of those get shorter in Godot; the animation one gets *longer*, because the
strips already produced target this renderer.

**The thing the browser is uniquely good at is the thing this project needs
most.** The whole point of v10 was "a stranger opens a link and plays". A single
self-contained HTML file with no install, no download, no store page and no
runtime dependency is the reason a tester played it at all. That is worth more
right now than a better editor.

**When to revisit — concrete triggers, not vibes:**

1. Frame budget breaks on real hardware at real crowd sizes and the fix is no
   longer a draw-call change. (Today: 1.9ms typical, 3ms p95, 40 enemies.)
2. The renderer needs lighting or shaders that Canvas 2D cannot express — the
   deferred VFX in §2E are the first hint of this.
3. Multiplayer, controller support or a store release becomes a goal.
4. Somebody other than an agent has to work in the codebase daily.

None of the four is true today. If one becomes true, the port target is Godot 4
with the simulation lifted first (it is already renderer-agnostic where it
matters) and the renderer rewritten rather than translated.

---

## 7 · Ownership

Unchanged from V10-PLAN §6. Engine, blocks A–E and the harness: me. Art
direction, the event sheet, VFX specification and encounter design: Codex. All
image, animation and audio generation: me, through Aether Loom
(`ASSET-GENERATION.md`) and `VOICE-BRIEF.md`. Playtests, low-spec hardware,
loudness and photosensitivity: human.

---

## 8 · Carried forward from v10

Closed by v11:
- ~~two cloud bands blocked on the image billing limit~~ — **delivered**, stills
  are 67 of 67

Still open:
- **49 SFX cues and 5 music tracks.** Blocked on an ElevenLabs/Suno key on this
  machine. Every cue has a procedural voice, a sample slot, a bus, a voice cap
  and positional panning, so a delivered file is live the moment
  `src/ingest-audio.py` sees it. `VOICE-BRIEF.md` is the queue.
- **15 animation cycles.** Not blocked — paced. Read `ASSET-GENERATION.md` §6b
  before spending another video generation.
- **`crew_muster_1` is cut mid-sound** and needs regenerating; `audio-check.py`
  flags it, and it is 1 of 16 masters.
- **The human work.** Still the largest single item in the project.
