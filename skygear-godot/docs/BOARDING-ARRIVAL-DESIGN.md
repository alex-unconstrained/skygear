# BOARDING ARRIVAL — a ship pulls up and the wave gets off it

*Written 2026-08-03. Three designs, judged twice, one recommendation. Read-only
survey: no file in `skygear-godot/` was modified to produce this. The board rows
this proposes do not exist yet — filing them is step one, see §9.*

---

## 0 · The ask, in the owner's words, and the fact that it was never a ticket

First:

> "Perhaps we can have mobs jump across into the ship instead of pop-spawning
> in."

Then, expanded:

> "I was thinking more of having the sky ships be visible in the distance and
> below the player ship and then for each wave maybe just having a ship pull up
> to the front and a bunch of enemies jump off. What are your thoughts? I just
> think that ships in the distance can make the sky and the game feel more
> intense and lived in."

**This was asked twice and has never been filed.** It is not in
`docs/OUTSTANDING.md` and it has no board row. The nearest thing to it in the
repo is **NEEDS_ALEX §2 decision 5** — *"The skyships — which ship goes where,
and which is the arrival ship?"* — which records that an arrival ship is
expected to exist and asks which one it is, while nothing anywhere describes an
arrival. STATUS.md's first failure mode is *data with no reader*; this is the
inverse and it has been open longer: **an owner ask with no row.** Closing that
gap is what this document is for. It ends with a build order and two questions
only Alex can answer.

Note the second ask contains two separable features:

1. **ships in the distance, visible and below** — SG-102 built this; four
   transports fly in a wedge off the bow today;
2. **for each wave, a ship pulls up to the front and a bunch of enemies jump
   off** — nothing in the repo does this.

Everything below is about (2), and the build order is staged so that (2) splits
again into *a ship pulls up* and *enemies jump off*, in that order, with the
first shippable alone.

---

## 1 · How a boarder arrives today

**The call path**, all in `scripts/game.gd`:

`start_wave()` (2303) → `spawn_queue = _build_spawn_queue(wave)` (2324) → each
frame `_update_wave()` (2454) pops entries whose `time <= wave_time` while
`enemy_count() < 64` (2466) → `spawn_enemy(kind, lane)` (2724).

`_build_spawn_queue` (2430) expands `SkyGearData.WAVES[w-1].batches` —
`[time, type, count, lane_spec]`. When `lane_spec` is absent it consumes
`rng.randi_range(0, 2)` (2439), so **queue construction itself draws from the
seeded sim stream**. Tempo comes from an isolated stream keyed
`hash(seed_text) ^ (wave * 2654435761 + 7919)` (2377). Push waves append a
trickle in place while the hulk is `"open"` (2481–2491).

**The spawn position is one literal line** (2727):

```gdscript
enemy.global_position = Vector2(LANE_CENTERS[lane] + rng.randf_range(-58.0, 58.0), -1115.0)
```

`LANE_CENTERS := [-560.0, 0.0, 560.0]` (game.gd:16),
`DECK_RECT := Rect2(-840, -1160, 1680, 2320)` (game.gd:14). The spawn line is
**y = -1115, forty-five units inside the bow edge**, jitter ±58 in x, one
`randf_range` per spawn. `BOW_Y := -1000.0` (459) is where the push-wave hulk
grapples.

**What the player actually sees.** `configure()` (enemy.gd:176) sets hp, radius
and sprite and adds the enemy to group `enemies` — full size, full opacity,
instantly. The enemy starts in `state = "climb"` with `state_time = 0.8`
(enemy.gd:15–16, the declared defaults; `configure` never touches them). The
climb branch (enemy.gd:219–225) zeroes velocity for 0.8 s and returns.
`enemy.gd::_draw()` draws a gold ring (`#e8c376`) during climb — **the 2D scene
is hidden, so nobody has ever seen that ring.** `scripts/view3d.gd` has no
`climb` branch anywhere: the rig is asked for `moving = state == "move"`, so a
climbing boarder is a fully-lit figure standing at idle on the planking.

The only real signal is audio — `play_sfx("enemy/climb.ogg", -12.0)` at
game.gd:2729 — plus `view.cue("boss_arrival")` and voice lines for BOSS and the
first board.

**Net: a figure appears at full size, standing still, on the deck, for 0.8 s,
and then walks.** That is the whole of the arrival, and it is what the owner
noticed.

**One more fact that every design below has to live with.** Only two places in
the repo exempt a climbing boarder: `game.gd:4094` (cannon targeting) and
`game.gd:4232` (crew targeting). **Every player skill, aura, fire pool and the
auto-attack already damage a boarder during its 0.8 s climb.** Today nobody
notices, because the climber is standing on the deck.

---

## 2 · RECOMMENDATION — build **THE BERTH on the Bow Hold chassis, driven
reactively**

Decisively: **build C's picture on A's machinery, and drive it off what the sim
has already done rather than off what it is about to do.** Then take B's boss
exemption and B's shadow arithmetic, and do not take anything else from B.

Concretely, the thing to build is:

- **A's chassis.** Renderer-only. Zero lines in `scripts/game.gd`,
  `scripts/enemy.gd`, `scripts/game_data.gd`. The arc's clock is the enemy's own
  `state_time`, which `tools/still.gd` already freezes, so the probe's noise
  floor is zero by construction rather than by hope
  (STATUS.md failure mode five, four prior instances). Determinism needs no new
  instrument to believe: `tests/parity_test.gd:880/932/949/969` compare
  `var_to_str(_build_spawn_queue(w))` byte-for-byte across twelve waves and are
  untouched.
- **A's live endpoint.** The arc's landing point is **re-read from
  `enemy.global_position` every frame and never baked**, so a boarder shoved,
  Keel-Hauled or dash-knocked mid-flight has its arc bend to follow. The mesh
  cannot end up anywhere except on the sim's spot. This is bounded by
  construction rather than by a threshold, and it is the single best idea in any
  of the three. Take A's hurt-clip suppression with it.
- **C's picture.** Per-wave hull identity (`ARRIVAL_HULLS`), the hull coming
  forward to the bow hold, and — the free second reading nobody else proposed —
  **the ambient wedge visibly thinning**, because a hull that comes forward
  leaves its row in `SKYSHIPS` and its station is empty sky. That is the part
  that answers *"for each wave a ship pulls up"* and *"lived in"* at the same
  time.
- **C's ring**, promoted out of the hidden 2D scene: a gold `#e8c376` decal at
  the landing point closing from wide to the gameplay radius over the flight.
  A closing ring is a countdown; a tint on a shadow is a decoration. This is the
  strongest deck-level telegraph proposed and it is the one that works from
  mid-deck, where no hull is visible at all.
- **B's boss rule.** BOSS never leaps and never gets an arrival hull. Wave 12 is
  `{"boss": true}` and already owns a cutscene (`view.cue("boss_arrival")`,
  game.gd:2735; SG-119's fixed wedge; the SEGMENTED `_part_shadows` path). C's
  `ARRIVAL_HULLS` maps BOSS to `skyship_barge_heavy` and that collides head-on
  with all three. Delete the row.

**And one thing killed outright: C's `_build_berth_plan`.** It reads a deep copy
of the spawn queue and predicts, 2.2 s early, what the sim will pop. That is a
second implementation of the wave scheduler living in `view3d.gd` — failure mode
two at subsystem scale — and `_update_wave` gates popping on
`enemy_count() < 64` (game.gd:2466), so it desynchronises exactly when the deck
is fullest and the mistake is most visible. **Drive the hull swap reactively:
off the wave number for the approach, and off boarders that have already
spawned for everything else.** The renderer may read what just happened; it must
never own a second copy of when things will happen. Cost of reactivity: the hull
arrives with the first boarder rather than two seconds ahead of it, so the ship
is a *frame* for the wave rather than a *warning* of it. Given that half the
runtime cannot see the hull anyway (§7), that is a cheap price and it deletes
the desync class entirely.

**Why this and not the other two as written.**

- **A alone answers half the ask.** One barge parked at the bow for a whole run
  is not "for each wave a ship pulls up"; the fleet never changes and never
  means anything. Its gold-tint-on-the-shadow telegraph is the weakest of the
  three, and — see §8 — it is a colour change on a mark the renderer is already
  shrinking.
- **B is the most coherent design and the wrong purchase.** It is the only one
  that leaves the game more consistent than it found it: one rule, no
  exceptions, and it *deletes* the contradictory carve-outs at game.gd:4094 and
  4232 instead of inheriting them. But its own arithmetic makes a small picture:
  `BOARD_ALT_AT_RAIL = 60` with `BOW_INSET = 45` and `BOARD_LAUNCH_Y = -1490`
  peaks at `60 * sqrt(375/45) ≈ 173` units — one boarder-height — over 375 units
  of ground, **launching in mid-air 1,110 units short of the hull it is
  supposed to be leaping from**. Nobody jumps off a ship in it. It charges the
  full sim price (a new elevation channel, a `damage_enemy` gate, twelve
  call-site swaps, a named and uncompensated balance regression) for the
  smallest of the three pictures. Its genuinely new mechanic — flak cannons — is
  a combat feature invented to answer a request about atmosphere, on a rig
  SG-128 says resolves about a third of a change.

**What B is right about and must be carried forward regardless of which design
is built:** an airborne boarder that every player skill can still hit is a
contradiction, and this feature makes it visible on wave one. See §8.

---

## 3 · ALTERNATIVE A — "The Bow Hold Drop"

**Pitch.** The sim spawns a boarder on the deck exactly as it does today, at the
same coordinate from the same seeded draw; the renderer spends that boarder's
already-existing 0.8-second climb window flying its mesh down out of a transport
parked at the bow.

**Mechanics.**
- One row appended for `skyship_barge_heavy` — the sixth transport, ingested and
  deliberately banked from `SKYSHIPS`. It takes no ambient station and becomes
  the BOARDING TRANSPORT, parked at `SKYSHIP_BOW_HOLD := Vector3(0, -520, -2600)`
  (view3d.gd:295), **a constant nothing in the repo reads** — a live instance of
  failure mode one.
- `_sync_boarding_transport()`: a phase-clock glide in the shape
  `_sync_skyships()` (2590) already uses. Eases from z = -5200 to the hold over
  ~3 s at `wave_time == 0`, holds through the wave with the same bounded
  heave/roll every hull gets, peels off to port on wave clear. Reads `game.wave`,
  `game.wave_time`, `game.hulk_state()`; writes nothing.
- `_arrivals`: a Dictionary keyed by enemy instance, populated in the existing
  enemy sync loop (5841) when `enemy.state == "climb"`, storing only a rail-point
  index. Progress is `1.0 - enemy.state_time / 0.8`, read live off the sim's own
  countdown, so `tools/still.gd` freezes the arc and it needs no clock of its own.
- `_sync_arrivals()`: after `SkyGearRig3D.place()` hard-writes
  `Vector3(ground.x*ws, 0, ground.y*ws)` (rig3d.gd:635), overwrite the rig's
  x/y/z from a Bezier between the transport's near rail and the enemy's **live**
  ground position. This is `_fly()`'s exact pattern (view3d.gd:6856, overwriting
  `rig.position.y` from `hover_height` for the hovering GUNNER) widened to three
  axes. **The endpoint is re-read every frame, never baked.**
- The `_shadow` at 5841 stays exactly where it is, tinted `#e8c376` while
  `state == "climb"`.
- `scripts/rig3d.gd`: `"jump"` into `PRIORITY` between `"dash"` and `"plant"`,
  and into `ONE_SHOT`. `react_land()` (rig3d.gd:678) — written, called from
  nowhere in the repo — fires on touchdown.
- Arc lands at 0.65 s of the 0.8 s window, leaving 0.15 s for `react_land()`.
  Strong horizontal ease-out: the 1,485 units are mostly eaten in the first
  quarter-second while the figure is foreshortened to nothing; the readable
  portion is the last ~300 units.
- `hurt` one-shots suppressed for the duration of the arc (renderer-side `want()`
  only). Death mid-arc needs no code: `_age_corpses` (3561) picks the body up
  from wherever the mesh is via `corpse_drop`, so a boarder shot out of the air
  falls.

**What the player sees.** Wave banner. Dead ahead, filling the top edge, the
underside of a heavy barge slides in over the bow and settles — keel plating and
the bulge of the hull, its deck cropped away above the picture. Four seconds
later three gold rings light on the deck near the bow, one per lane, where
boarders have always appeared. Half a heartbeat after, figures drop out from
behind the top edge — small and fast, then slowing and swelling — each landing on
its own ring, absorbing the impact in a crouch, coming up walking. The barge sits
overhead the whole wave and boarders keep peeling off it. When the last one dies,
it rolls to port and slides out of frame.

**Sim impact.** Nothing, deliberately. `game.gd`, `enemy.gd` and `game_data.gd`
are not edited. The boarder is in group `enemies` and hittable from frame one,
`correct_enemy_position` clamps it exactly as before, no elevation channel is
added. The renderer reads two already-public fields — `enemy.state`,
`enemy.state_time` — and writes only `rig.position`. If `view3d.gd` were deleted
the wave would play out identically.

**Kill test, verbatim.**

> Extend `godot --path . --script tools/skyship_probe.gd -- check` with an ARC
> pass. It is analytic — it projects sampled arc points through the real camera
> solve exactly as `_on_screen` already does, no readback, so its noise floor is
> exactly zero, not small. Two pre-committed statistics, both over 3 lanes × 6
> `POSES` × 2 `ZOOMS`, 48 samples per arc:
>
> **(1) LANDING VISIBILITY.** Fraction of the final 0.45 s of the arc whose
> projected figure box (216 units tall, the Furnace Knight, the tallest boarder)
> lies fully inside the viewport. **Threshold: ≥ 0.95 for every lane at the
> `mid`, `fight` and `bow` poses at zoom 1.0.** Below that, the drop happens off
> the top of the frame from where the player actually stands and the feature is
> atmosphere nobody sees — CUT.
>
> **(2) THE SIZE OF THE LIE.** Over on-screen samples only, the maximum
> projected pixel distance between the figure's foot point and its ground
> shadow's centre — the mesh versus the spot the sim believes it occupies.
> **Threshold: ≤ 260 px on a 1600×900 frame (a quarter of frame height), at
> every lane × pose × zoom.** This is the one that kills it. It is Pillar 6
> measured directly: past a quarter of the screen the shadow stops reading as
> belonging to the figure, and a boarder the sim can already damage is being
> drawn somewhere the player does not associate with it. Blowing (2) does not
> get bargained down by shortening the arc's tail; the visible portion of the arc
> gets shorter until it passes or the design is CUT.
>
> Deliberately NOT a `tools/balance.gd` A/B: SG-128 says that rig resolves about
> a third of a change and this feature is meant to change balance by zero. The
> balance evidence is the parity queue check still passing.

**Two factual errors in the proposal as written, both verified against the
repo.** (a) It claims SWARM is a billboard with no model directory.
`assets/models/swarm/` exists with `swarm_mesh.res`, `swarm_skin.res`,
`swarm_anims.res`, and `tools/models.json` gives swarm `jump`, `jump2` **and**
`jump_attack` — swarm is the *best* case, not the worst. (b) It never mentions
BOSS, and it never mentions that GUNNER's `rig.position.y` is already owned by
`_fly()` (view3d.gd:6856, `ROTOR_MOTION` at 6572), which `_sync_arrivals` would
fight every frame. **SCRAPPER is the only real gap:** its clip list is
`idle, walk, run, swing, hurt` — no jump, and no die either.

---

## 4 · ALTERNATIVE B — "OVER THE RAIL", a boarding run the simulation believes in

**Pitch.** A transport swings to the bow hold before each wave and boarders leap
off it onto a real 0.8-second airborne timeline **the 2D sim owns** — same seed,
same landing spots, byte for byte — during which they cannot be touched and
cannot touch anything, except by the deck cannons, which become flak.

**Mechanics.**
- `enemy.gd`: `"climb"` renamed `"board"` and given a body. Four fields —
  `altitude: float` (the one new channel in the sim), `board_from`, `board_to`,
  `board_t`. Two predicates — `airborne()` and `can_be_hit()`. The climb branch
  becomes the flight integrator.
- The arc, pure and rng-free.
  `global_position = board_from.lerp(board_to, 1.0 - pow(1.0 - u, 3.0))`,
  `u = board_t / BOARD_TIME`, `BOARD_TIME = 0.8` — exactly the climb it replaces,
  so wave pacing and every balance number are untouched. Altitude is a function
  of remaining ground distance, not of time:
  `altitude = BOARD_ALT_AT_RAIL * sqrt(d / BOW_INSET)`, `BOW_INSET = 45.0`,
  `BOARD_ALT_AT_RAIL = 60.0`, pinning altitude to 60 at the frame the ground
  position crosses `DECK_RECT.position.y`.
- `spawn_enemy` keeps its `rng.randf_range(-58, 58)` in the same place in the
  same order; it now names `board_to`. `board_from = Vector2(LANE_CENTERS[lane],
  BOARD_LAUNCH_Y)`, new `const BOARD_LAUNCH_Y := -1490.0`, owned by the sim. When
  `hulk_state() == "open"` the trickle launches from `BOW_Y = -1000.0` instead.
- **`damage_enemy` is the choke point**: it refuses damage to `airborne()` unless
  the caller passes `flak := true`. The ~12 query sites swap `not enemy.dead` for
  `can_be_hit()`, but those are an optimisation, not the guarantee — a missed
  site still cannot hurt an airborne boarder.
- **The two carve-outs are deleted, and they are the argument.** game.gd:4094 and
  4232 are the only places that skip `state == "climb"`, which means the game
  today holds two contradictory beliefs about whether a fresh boarder is real.
  Crew take `can_be_hit()`; cannons take the opposite rule and become the one
  system that reaches the sky.
- `_update_turrets`: a lane cannon prefers a grounded boarder, but with none in
  reach fires on an airborne one with `flak = true`. Zero hp while airborne
  routes to `on_enemy_shot_down()` — full bounty, no deck contact, falls past the
  bow.
- `correct_enemy_position` (4507) and `_went_over()` (enemy.gd:386) early-return
  while airborne; both would drag a flying boarder onto the deck.
- **BOSS does not leap.** `board_time = 0`, `altitude = 0`, arrives at y = -1115
  exactly as today, keeping `boss_arrival` and SG-119's wedge untouched.
- `view3d.gd` passes `enemy.altitude * WORLD_SCALE` as a lift; `_sync_skyships`
  gains a `hold_u` so one of the four placed ships (chosen by `wave % 4`, no rng)
  lerps to `SKYSHIP_BOW_HOLD` and back. The ship is renderer-only; only the
  boarders are real.

**What the player sees.** Off the bow, low and to port, the cutter stops
drifting and comes about, growing for about four seconds until it sits square in
the top of the frame, deck a little under yours, close enough to read its rail.
Then three soft gold rings light on the planking, one per lane. Under each, a
wide pale shadow slides in from beyond the bow and starts shrinking and
darkening. A quarter-second before contact a figure drops into the top of the
frame — feet first, arms out, actually falling — and lands hard inside its ring
with a squash and a puff of dust, and the ring snuffs out. That is the frame it
becomes your problem and the frame it starts walking. If your port cannon is up
and has nothing closer to shoot, it swings **up**, and one of the three never
lands.

**Sim impact.** Everything load-bearing. One new scalar and one derived
predicate, read by `spawn_enemy`, `correct_enemy_position`, `_went_over`,
`damage_enemy`, `_update_turrets` and both targeting loops. What it unlocks that
no renderer trick can: **flak** — the deck cannon stops being a lane gate that
shoots things already past it and becomes the only weapon that reaches arrivals —
and a clean, honest immunity window that makes waves land as discrete boarding
parties instead of a drip.

**Kill test, verbatim.**

> A geometric on-screen check, not a balance A/B — the warning is right that the
> balance rig cannot see this. New `tools/board_probe.gd`, built directly on
> `tools/skyship_probe.gd`'s existing `_on_screen(camera, ground)` projection
> test and its `POSES` table (6 real play poses × ZOOMS [1.0, 1.55]) — the same
> rig that produced the 140-station SG-102 numbers, so its noise floor is already
> an argued quantity. It sweeps every arc: 7 kinds × 3 lanes × {bow-hold launch,
> hulk launch} = 42 arcs, sampled at 60 Hz over the 0.8 s, projecting
> `Vector3(x, altitude, y) * WORLD_SCALE` plus the kind's `boarder_height` band.
> PRIMARY STATISTIC: **continuous on-screen time immediately preceding touchdown,
> at zoom 1.0.** THRESHOLD: **every one of the 42 arcs must show ≥ 0.25 s of
> unbroken on-screen descent before touchdown from at least 5 of the 6 play
> poses. If any arc falls under 0.25 s, or if fewer than 5 poses clear it, the
> airborne state is cut back to a renderer-only drop-in and the sim work is not
> written.** 0.25 s is the line because under it the landing is a pop with extra
> steps, which is the exact thing the feature exists to delete. COMPANION PIN
> (cheap, runs in `tests/parity_test.gd`, headless, no frames): max `altitude`
> over every arc while the ground position lies inside `DECK_RECT` must be
> ≤ 65.0 units, DECK-DESIGN §1's measured bow budget, for 100% of arcs — true by
> construction today, which is precisely why it needs to be an assertion, so the
> day someone raises `BOARD_ALT_AT_RAIL` the harness says so instead of the
> picture.

**Corrections against the repo.** "7 kinds" — `game_data.gd::ENEMIES` has five
(SCRAPPER, GUNNER, ARMORED, SWARM, BOSS), so the sweep is 30 arcs, not 42. And
the arc being rng-free by design means three simultaneous same-lane drops are
three pixel-identical parabolas, which the sim cannot fan without a new draw.

---

## 5 · ALTERNATIVE C — "THE BERTH", a transport pulls in and unloads the batch

**Pitch.** The wave's spawn queue is already a list of boat-loads. One of the
five transports peels off its ambient station, pulls into the bow hold two
seconds before each batch, parks at the berth that matches the batch's lane,
throws that batch onto the deck as arcing figures over their own landing
shadows, and leaves — and the 2D sim never learns any of it.

**Mechanics.**
- `const BERTHS`: three stations derived from `SKYSHIP_BOW_HOLD` —
  `(-900, -520, -2600)`, `(0, -560, -2600)`, `(900, -520, -2600)`. x is
  `LANE_CENTERS` amplified 1.6×, because a 560-unit offset does not survive
  2,600 units of distance and a berth that cannot be told from its neighbour is
  not a telegraph.
- `const ARRIVAL_HULLS := {"SWARM": "skyship_skiff", "GUNNER": "skyship_cutter",
  "SCRAPPER": "skyship_tender", "ARMORED": "skyship_barge",
  "BOSS": "skyship_barge_heavy"}`. **Hull says what is coming, berth says which
  lane.** The skiff is already commented "there are lots of these" and carries
  the swarm; the cutter is the knife and carries the shooters; the scrap-built
  tender carries the scrappers; the 1,400-unit barge carries the armour.
- **The fleet visibly thins.** A hull that comes forward leaves its row in
  `SKYSHIPS` — `_sync_skyships()` skips the row whose model is on the berth. The
  gap where the barge was is a free second reading and costs one branch.
- `_build_berth_plan(wave)`: takes a deep copy of the built queue via a new
  read-only `SkyGearGame.spawn_manifest()`, clusters entries within 1.2 s of the
  same kind into MANIFESTS — one manifest is one boat-load — and emits
  `{hull, berth, open_at = first_time - 2.2, close_at = last_time + 1.4}`.
- `_sync_berth(delta)`: states `approach` / `hold` / `depart`, 2.2 s in and
  2.6 s out on `SkyGearCutscene`'s existing `inout` ease. At most one hull on the
  berth. **The hull departs on `close_at`, a timer — never on manifest
  exhaustion**, because `_update_wave` gates popping on `enemy_count() < 64` and
  a ship holding station over a full deck with nobody jumping reads as broken.
- `scripts/game.gd` gains **one** guarded line after `configure()`:
  `if view != null: view.boarder_launched(enemy)` — the same shape as the
  `view.cue("boss_arrival")` line three lines below it. Line 2727 is unchanged
  character for character.
- The enemy sync gets its first `climb` branch: `_arrival_arc(rail, ground, t)`
  with `t = 1.0 - enemy.state_time / <the enemy's own declared window>`, **read
  off the enemy rather than re-declared** — 0.8 must not become a number two
  files each own.
- `_shadow` is **not** touched. It keeps drawing at the sim's `global_position`
  at full gameplay radius from the first frame of the climb.
- `rig3d.gd`: `"jump"` into `PRIORITY` and `ONE_SHOT`; `react_land()` called on
  the climb→move edge. **SCRAPPER falls back EXPLICITLY to `run`, not through
  `_or_idle`** — a T-pose idle sailing through the air is the bug report.
- The gold climb ring becomes a real ground decal at the landing point, closing
  from wide to the gameplay radius over the flight.

**What the player sees.** Wave 6 clears. **T-2.2:** far off the bow and below,
the scrap-built tender — third ship out, the one she notices least — leaves its
station and swings forward and up. It parks port-of-centre, deck a little under
hers. **Its old station is now empty sky, and the fleet is four ships wide
instead of five.** **T-0.4:** three gold rings open on the port lane's planking,
wide and thin, and start closing. **T-0:** three figures come off the tender's
rail together, cross the gap in a real arc, and drop into frame descending, each
directly above its own ring. The rings finish closing as the boots land;
`react_land()` squashes; they stand up already walking. From wave 4 she has
learned it: the low broad barge means armour. From mid-deck she may never see the
tender — she sees three rings open in the port lane and three shapes fall into
them, which is the same information one channel down.

**Sim impact.** Explicitly nothing. `_build_spawn_queue` unchanged including its
`randi_range(0,2)`; the spawn line unchanged including its `randf_range` and its
`y = -1115.0`; `state = "climb"` and its window unchanged. A climbing boarder
remains hittable by every player skill, as it already is. The only new bytes in
`game.gd` are one null-guarded call and one accessor returning a deep copy. In
headless parity the feature does not exist and the run is bit-identical.

**Kill test, verbatim.**

> `godot --path . --script tools/skyship_probe.gd -- arrival`, a new mode built
> from the probe's existing `_pose`, `_on_screen` and `SkyGearStill.freeze` —
> geometric, not a balance A/B, because the balance rig resolves about a third of
> a change and has an 8% floor on damage-taken. **Headline statistic:
> `arc_visible_frac`** — the fraction of the LATE HALF of a boarder's flight
> (t in [0.5, 1.0], 32 samples) during which a boarder-sized box (the kind's real
> `radius`, 120 units tall) is inside the viewport, swept over 6 play poses × 2
> zooms × 3 berths × 5 kinds = 180 pairs. **Threshold: the WORST-CASE
> `arc_visible_frac` over all 180 pairs must be ≥ 0.55, and the landing point
> plus its shadow disc must project on screen in 180/180.** Below 0.55 the arc is
> too high, too long, or launched from a station the camera cannot reach, and the
> jump is CUT back to what ships today while the ship-arrival tier stays — the
> two halves are separable and this is the seam. Supporting check in the same
> run, reusing `_check`'s existing footprint arithmetic against the three new
> berths rather than the four ambient rows: each hull's plan footprint at its
> berth must not intersect `DECK_RECT` or any `CARGO_RECTS`, and its masthead
> must stay strictly below y = 0 — the 900-unit `bow_prow.png` died at the bow
> line against a measured 65-unit headroom budget, and a mast that clears the
> planking at the berth is that mistake at range. Any failure is non-zero exit.
> And per the fifth failure mode, `-- arrival` reports its own noise floor first:
> two identical frozen passes must differ by exactly zero, not by a little.

**Two holes it does not see, and one attributed to it wrongly.**
(a) **Berth-means-lane has no answer for an `"all"` batch, which is most
batches.** `game_data.gd::WAVES`: wave 1 is entirely single-lane, but from wave 2
onward `"all"` dominates — waves 9, 10 and 11 are `"all"` in every batch. Either
the centre berth absorbs every `"all"` (in which case the berth carries almost no
information after wave 2) or the manifest splits three ways (in which case at
most one hull on the berth breaks). This must be decided before it is written.
(b) **BOSS must come out of `ARRIVAL_HULLS`.** (c) The proposal's own risk list
says "wave 12 is both push and boss" — it is not. `WAVES[11]` is
`{"boss": true}` with no `push`; the push waves are 4 and 8
(`WAVE_EVENTS := {4: "grapple", 8: "blackout", 12: "colossus"}`). The hulk/berth
collision is real on waves 4 and 8 and does not exist on 12.

---

## 6 · What this needs from Alex before it can start

**1 · Which ship is the arrival ship — NEEDS_ALEX §2 decision 5, still open.**
This is the blocking one. The five are: `skyship_cutter`, `skyship_skiff`,
`skyship_barge`, `skyship_tender` (all four flying, in the wedge) and
`skyship_barge_heavy` (ingested, banked, has never taken a station). Three
answers are possible and they are genuinely different features:

- **(a) One dedicated arrival ship.** `skyship_barge_heavy` comes off the bench,
  takes no ambient station, and is the boarding transport for the whole run. The
  ambient wedge never changes. Cheapest, and the fleet stays decoration.
- **(b) The hull is the wave's telegraph** — one of the four flying ships comes
  forward per wave and its station goes empty. This is THE BERTH, and it is the
  reading of the second ask ("for each wave... a ship pull up"). Costs the
  `ARRIVAL_HULLS` table and the thinning branch.
- **(c) The hull says what is coming** — skiff/swarm, cutter/gunner,
  tender/scrapper, barge/armoured. Strictly more than (b): the same machinery
  plus a meaning. Risk: it makes the hull load-bearing information, and half the
  runtime cannot see the hull (§7).

**The recommendation is (b), with (c) as a later row** once the probe has said
the hull actually reads from the poses that matter. Building (c) first is
claiming a channel that has not been measured.

**2 · Do you accept a boarder being damaged while it is visibly in the air?**
Every player skill, aura, fire pool and the auto-attack already hit a climbing
boarder; only the cannons and the crew skip it. The renderer-only designs (A, C)
do not create that behaviour — they make it visible for the first time, and you
will see damage numbers pop on the planking under a figure that is plainly
falling. **If that is unacceptable, the answer is B**, and B costs a new sim
channel, a `damage_enemy` gate, twelve call-site swaps and a small uncompensated
balance change (a boarder no longer takes free chip damage during its 0.8 s). If
it is acceptable, the recommendation stands and the follow-up gets its own row.

**3 · Is `skyship_barge_heavy` allowed off the bench?** It is ingested, budgeted
and checked, and deliberately not in `SKYSHIPS`. Whichever design is built, using
it is a one-row change and a decision that was consciously deferred.

**One thing you should be told before anything is built, not after.** SG-102
measured it and it is not fixable by this feature: **from mid-deck at zoom 1.0 the
deck is 100% of the frame, edge to edge** (`.shots/skyships/probe/mid-z1.00.png`).
The four transports read from the bow, from the port rail at zoom 1.0, and from
anywhere at zoom 1.55. So *"a ship pulls up to the front"* is a picture you will
see when you are forward or zoomed out, and for a substantial share of play the
arrival will be carried entirely by rings on the deck and figures dropping in
from off the top of the frame. That is still much better than what ships today.
It is not the whole of what you described.

---

## 7 · Where the two judges disagreed

They agreed on the biggest risk and split on the purchase.

- **Judge 1 picked THE BERTH** — "closest to Alex's actual sentence" — and rated
  it feel 8, cost 6. It called the Bow Hold Drop "the least of what Alex asked
  for: no fleet language, no ship that means anything."
- **Judge 2 picked the Bow Hold Drop, but only as a chassis** — "THE BERTH is the
  better feature and the worse bet; if the berth planner were reactive instead of
  predictive I would flip." It rated THE BERTH feel 9 and honesty 5, on the
  grounds that `_build_berth_plan` is a second wave scheduler in the renderer.

**The recommendation in §2 is the flip Judge 2 named**: THE BERTH with a reactive
driver. That is not splitting the difference; it is taking Judge 2's stated
condition and satisfying it.

**They also disagreed on a fact, and one of them is wrong.** Judge 1 accepted
A's claim that SWARM is a billboard. Judge 2 said it is rigged with jump,
jump2 and jump_attack. **Judge 2 is right** — `assets/models/swarm/` contains
`swarm_mesh.res`, `swarm_skin.res` and `swarm_anims.res`, and `tools/models.json`
lists all three clips. Swarm is the best-equipped kind for this feature, not the
worst. The only kind with no jump clip is SCRAPPER (`idle, walk, run, swing,
hurt`), which is also the most common early boarder.

**And they disagreed on the shadow**, which turns out to be the whole game — §8.

Named worst ideas differed too. Judge 1: B's flak cannons and
`on_enemy_shot_down`, "the largest new mechanic in any of the three, invented to
answer a request about atmosphere." Judge 2: B's ≤65-units companion pin, "a
harness check asserting the feature is invisible." Both are in §9's do-not-build
list.

---

## 8 · The biggest risk: all three designs are wrong about the shadow

Every one of the three rests its Pillar-6 case on a contact mark, and all three
describe a renderer that does not exist. This was verified in
`scripts/view3d.gd` and it is the reason §9 has a Stage 0.

**(1) `shadow_pose()` (view3d.gd:4868) is the shipped authority on where a mark
goes, and it already declares the opposite of A's and C's core claim.** For any
non-projectile mark:

```gdscript
if kind != SHADOW_CENTRED:
    at += (flat / down) * lift
```

with `moon_track()` defaulting to `Vector3(-0.344, -0.788, -0.510)` — **0.437 to
port and 0.647 toward the bow per unit of height.** A's "the shadow is the truth
and it never moves" and C's "`_shadow` is NOT touched" both mean passing
`lift = 0` while the figure is 500 units up. That is not leaving the code alone;
it is contradicting the one function that owns the rule — failure mode two — and
it forfeits the widen-and-fade cue SG-107 built (`spread = 1.0 + lift /
SHADOW_LIFT_SPREAD`, `SHADOW_LIFT_SPREAD := 300.0`). **B is the only one that
gets this right**, and B's move — scale the mark's size up and its alpha down
with altitude — is exactly what `shadow_pose` was built for.

**(2) A rigged boarder casts a real moon shadow, and nobody named this.**
`moon.directional_shadow_max_distance = 34.0` m = 3,400 ground units
(view3d.gd:760), so an airborne figure is inside the shadow cascade. At 500 units
up its cast silhouette lands roughly 390 units from its landing ring — **a
second, darker, wrong mark**, which is the exact "two marks under one man,
pointing different ways" the owner already reported once.

**(3) Worst, and it is automatic.** The enemy sync at view3d.gd:5899 reads:

```gdscript
if not _part_shadows(key, _rigs.get(key), 1.0):
    _shadow(key, enemy.global_position, float(enemy.radius) * 2.6, 0.5,
        0.0, 0.0, SHADOW_CORE if _casts_own_shadow(key) else SHADOW_LEANS)
```

`_casts_own_shadow()` (4783) asks the built tree whether the mesh casts, and if
it does the blob drops to `SHADOW_CORE` — multiplied by `SHADOW_CORE_WIDTH 0.42`
and `SHADOW_CORE_ALPHA 0.62`. **So the landing mark is automatically shrunk to
42% and faded to 62% at precisely the moment it is the only thing telling the
player where a boarder will be** — and it is shrunk in favour of a cast shadow
that is no longer under the landing point. A's gold tint does not fix this; it
recolours a mark the system is already weakening.

**The rule that follows.** Whichever design is built, **the airborne case is
resolved inside `shadow_pose()` first, with a harness check that reads
`moon_track()` rather than a hand-typed vector**, before a single line of arc
code is written. A boarder in flight is a new case for a function that has three;
adding it there is one place, and every caller inherits it.

**Second-biggest risk, and it is the one to say out loud to Alex:** the ship is
barely seen. `SKYSHIP_BOW_HOLD`'s keel sits at y = -520 against a frame ceiling
of about -510 at that range, so the hull above the keel is cropped off the top.
What actually ships from any of these three is *"boarders fall in from off-screen
onto marks"* — a much better spawn, but not the picture in the second ask.

---

## 9 · What we are deliberately NOT doing

- **No flak cannons and no `on_enemy_shot_down`** (Judge 1's named worst idea).
  It is the largest new mechanic in any of the three, it changes what cannon
  uptime is worth, and it was invented to answer a request about atmosphere. If
  shooting a boarding party out of the air is wanted, it is its own ask and its
  own row.
- **No `altitude <= 65.0 inside DECK_RECT, for 100% of arcs` pin** (Judge 2's
  named worst idea). That is a harness check asserting the feature is invisible,
  written from the same misunderstanding as the code, green forever — STATUS.md's
  seventh mode in advance. The 65 units were measured for a **bulwark**: a static
  wall that occludes. Borrowing it for a figure that passes through the band in a
  third of a second is failure mode four.
- **No 260 px "size of the lie" threshold as A words it.** The statistic is the
  best-specified number in any of the three and it should be kept — but a quarter
  of frame height is a permission slip, and "the visible portion gets shorter
  until it passes" is a kill test that cannot kill. Whatever number is chosen is
  pre-committed with a hard CUT branch and no shortening escape.
- **No predictive berth planner and no `spawn_manifest()`.** The renderer never
  owns a second copy of when things will spawn.
- **No boss leap and no boss arrival hull.** Wave 12 has a cutscene, a fixed
  wedge and a SEGMENTED shadow path.
- **No sim elevation channel in stages 1–3.** If it is ever wanted, it is B, and
  B is a separate decision with a separate balance statement.
- **No new Meshy spend and no new clips.** Five transports ingested, a sixth
  banked; jump clips ingested for four of five kinds; `react_land()` and
  `SKYSHIP_BOW_HOLD` already written and read by nothing.
- **No `tools/balance.gd` A/B.** SG-128: it resolves about a third of a change,
  and this feature is meant to change balance by zero. The balance evidence is
  the parity queue check still passing byte-for-byte.

---

## 10 · Build order

Staged so that **Stage 1 is shippable alone and can be abandoned without
debris.** Board IDs are next-free from SG-133.

**Stage 0 — SG-134 · P1 · BUG. The airborne shadow case, in `shadow_pose()`.**
Before any arc code. `shadow_pose` learns what a mark does when its figure is in
the air, `_casts_own_shadow`'s automatic core-shrink is resolved for that case,
and the moon's cast-shadow contribution at altitude is measured rather than
assumed. Checks read `moon_track()`, never a literal. **This is a standalone
correctness row** — it is worth doing even if the whole feature is dropped,
because the same arithmetic already governs the hovering GUNNER (`_fly`,
view3d.gd:6856) and every corpse lifted by `corpse_drop`. No arrival code lands
until this is green.

**Stage 1 — SG-135 · P2 · FEATURE. A ship pulls up. No jumping.**
`ARRIVAL_HULLS` (BOSS omitted), the approach/hold/depart state machine off the
wave number, and the ambient row going empty while its hull is forward. Boarders
spawn exactly as they do today. **This is shippable on its own and it is half the
owner's second sentence.** Kill test: C's footprint arithmetic against
`DECK_RECT` and `CARGO_RECTS` at the hold, masthead strictly below y = 0, plus
re-photographing the hold from all six poses at both zooms with the noise floor
reported first and equal to zero. **If it is abandoned here, the debris is one
const table and one function** — delete three call sites and the fleet is back to
SG-102 exactly. Nothing in `game.gd` has been touched at all.

**Stage 2 — SG-136 · P2 · FEATURE. The ring.** The gold `#e8c376` landing marker,
promoted out of the hidden 2D `enemy.gd::_draw()` into the deck plane at the
boarder's live position, closing from wide to the gameplay radius over the climb
window — the window read from the enemy, never re-declared. **Also shippable
alone**, and on its own it is a readability improvement over today's unmarked
motionless spawn regardless of whether anything ever jumps. This is the channel
that works from mid-deck, where no hull is visible.

**Stage 3 — SG-137 · P2 · FEATURE. The drop.** `"jump"` into `rig3d.gd`'s
`PRIORITY` and `ONE_SHOT`, an explicit `jump → run` fallback for SCRAPPER (never
through `_or_idle`), `react_land()` finally called, `_arrivals` swept against
`is_instance_valid` in the loop that already sweeps at 5842, GUNNER excluded
because `_fly()` owns its `position.y`, BOSS excluded. The arc is a Bezier whose
**endpoint is re-read from `enemy.global_position` every frame and never baked**,
whose clock is `enemy.state_time`, and whose per-figure variation is hashed from
the rounded ground position the seeded stream already produced. `hurt` one-shots
suppressed for the arc's duration. Kill test: the arc pass, pre-committed, with a
hard CUT branch — and the cut lands back on Stages 1+2, which stay.

**Stage 4 — SG-138 · P3 · FOLLOW-UP, filed not built.** The contradiction Stage 3
makes visible: every player skill damages a boarder in its climb window while the
cannon and the crew skip it. This is B's territory and it is a sim change, a
balance change and an instrument problem. It gets its own row, its own before and
after, and its own conversation with the owner. **It is not compensated for
elsewhere**, per SG-119's precedent.

**Then, and only with a measured hull-visibility number in hand — SG-139 · P3.**
The hull *means* something: skiff/swarm, cutter/gunner, tender/scrapper,
barge/armoured, with a defined answer for `"all"` batches. Deferred on purpose:
`"all"` is most batches from wave 2 on, and a lane-coded berth that is at the
centre nine times out of ten is failure mode one wearing a table.
