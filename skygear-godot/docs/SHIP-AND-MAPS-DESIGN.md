# The deck, the ship, and the ground between runs

Status: **NOTHING HERE IS BUILT.** This is a design document and one design
document only. No `.gd`, no `.tscn`, no asset was touched writing it.

Written against the port as it stands 2026-07-31, after reading `game_data.gd`,
`game.gd`, `view3d.gd`, `lanes.gd`, `enemy.gd`, `prop.gd`, `deckwork.gd`,
`workshop.gd`, `parity_test.gd` and the two design documents that already own
neighbouring ground.

## 0. Four asks, one question

> "Begin working on how we build out new maps and add run diversity through
> level changes… for persistent runs we should be looking at adding ways to
> improve/change/modify the ship — as this is the other 'character'… as the
> player defeats more runs their ship should become more 'theirs'."
>
> "Even maybe add downtime where the player can explore the ship between runs."

Four things: **variety inside a run**, **persistence across runs**, **the ship
as a character**, and **somewhere to stand between runs**. They are one
question, and it is not "what else can we add?" It is:

**Does the ground mean anything, and is it yours?**

Every existing system answers the captain. The draft is her build, the Workshop
is her kit, the Articles are her verbs, Heat is her difficulty. The deck is the
only thing in the project that is not about her, and it is currently one
hardcoded rectangle with one hardcoded prop list that is rebuilt identically
twelve times a run. That is the gap, and it is the same gap all four asks point
at from different sides.

The Workshop already has a branch called **THE SHIP** — Shot Locker, Spare
Plate, Gun Crew, Rivet Gun, Powder Store, Muster Roll. Every one of them is a
number. Nothing below may move any of those numbers, and I have used the word
**refit** for the new layer and **fittings** for its objects so that the two are
never confused in a commit message.

## 1. The constraint surface

The brief warns that a map which changes the deck's dimensions "may break the
camera solve, the lane maths and every telegraph radius." Two of those three are
right and one is not, and the difference matters, so here is what the code
actually couples.

**The camera does not read the deck, except through two lines.** `camera_back()`
solves purely from `PITCH` 0.72, `CAM_HEIGHT` 760, `CAM_NEAR` 460, `FOCAL` 1320,
`REF_HEIGHT` 860 and `STAND_FRAC` 0.60 — nothing about the deck enters it. The
only places `DECK_RECT` reaches the camera are the follow leash in
`_update_camera`: an x clamp of `deck_rect.size.x * 0.22` either side of centre
(±369.6 today) and a y clamp of `position.y + 300` to `end.y + 200`. Change the
rectangle and those two move; the projection does not.

**Telegraph radii do not break either.** `CLOSE.range` 210, `CLOSE.vent_radius`
200, `TAP.radius` 130, the keg's 175, the hulk's 190 — all absolute ground units
projected by a camera that has not moved. A 210-unit circle occupies the same
pixels on a deck of any size. What *does* change is the **ratio**: on a wider
deck every ability is relatively shorter-ranged and the whole close-quarters
argument v11 exists to make gets quietly re-tuned by a geometry edit. That is
the real coupling and it is a balance coupling, not a rendering one.

**What actually breaks is the frame.** Deriving from the constants above (my
arithmetic, at 16:9, and worth re-measuring before anyone relies on it): the
lens is 36.07° vertical, which the harness already pins to within 0.01 of a
hardcoded 36.1; the focus point sits ~300 units astern of the captain; the
visible strip of deck runs from about `focus.y + 9` to `focus.y − 1312`, roughly
**1320 ground units of a 2320-unit deck**, and you see about three times as far
toward the bow as toward the stern. At the captain's own depth the frame is
about **±622 units wide against a deck half-width of 840** — the deck is
*already wider than the frame*, and the ±370 leash is what lets the camera reach
a rail at all. And `OUTSTANDING.md` has an open, undiagnosed item saying the
framing is wrong in the first place: *"Godot shows materially less of the deck."*

So:

| | May vary | Why |
|---|---|---|
| Prop kinds and positions | **Yes, freely** | pure data; `restow_props()` already rebuilds the whole set at every `start_wave` |
| Which cross-passages are open | **Yes** | `CARGO_RECTS` is read in exactly four places: `correct_player_position`, the 2D debug draw, and twice in `view3d.gd` |
| Deck length in ±y | **Cautiously** | the camera only shows 1320 of 2320 already; more depth is nearly free to frame and expensive to fill |
| Deck width | **No** | the deck is already wider than the frame; widening it pushes the rails past the leash and re-scales every ability's reach |
| `PITCH`, `FOCAL`, `STAND_FRAC`, `WORLD_SCALE` | **No** | `FOCAL` pinned by `camera · the lens is the browser's focal length`, `STAND_FRAC` by `camera · the captain stands where the art was framed for`; `PITCH` and `WORLD_SCALE` are **UNVERIFIED — no check pins either by itself** (only implied through those two projection checks), and every sprite in `assets/art/` was painted for 41° |
| Lane count and `LANE_CENTERS` | **No** | see §2 — the ±190 clamp is load-bearing in a way that is not obvious |
| Boiler at (0, 850), spawn line at y = −1115, `BOW_Y` −1000, `BASE_Y` 730 | **No, not yet** | the wave tables, the hulk, the cannon line and the push logic all assume them |

**One deck, differently stowed.** That is the whole shape of the recommendation
and it falls out of the table above rather than being chosen for flavour: the
only axis where variation is cheap is *what is standing on the planking*, and
happily it is also the axis the fiction wants, because a ship that becomes yours
has to be the same ship.

## 2. The finding that reorders everything: boarders are on rails

`correct_enemy_position` is three lines and it is the most important three lines
in this document:

```gdscript
clampf(position.x, LANE_CENTERS[lane] - 190.0 + radius, LANE_CENTERS[lane] + 190.0 - radius)
```

Called unconditionally at the end of every enemy `_physics_process`, including
during knockback. Every boarder is confined for its whole life to a 380-wide
band: `[−750, −370]`, `[−190, 190]`, `[370, 750]`. And the eight `CARGO_RECTS`
sit at x `[−340, −220]` and `[220, 340]` — **exactly inside the two dead strips
between the bands**. The cargo runs are the lane dividers, but not by collision.
By a clamp. Only the player collides with cargo, in `correct_player_position`.

Four consequences, and they are all load-bearing:

1. **No object on the deck can funnel a boarder.** Not a crate, not a
   barricade, not a wall. Nothing you could ever place will change where a
   boarder walks, because boarders do not path — they beeline at the captain
   within 280 units, else the lane's cannon, else a crewman within 220, else the
   Boiler, and then get clamped back into their stripe. Any proposal that says
   "the player shapes where the fight happens by blocking a route" is describing
   a game this one is not, and turning the clamp into real geometry is the
   single most expensive item this document could contain. I would not pay it.
2. **The ship changes the *player's* ground, and only the player's.** Cover,
   crossings, refill points, blast lines, where salvage falls. That is a
   narrower claim than the brief's "the ship changes the GROUND", and it is
   still enough — `CLASS-2-DESIGN.md` §4 already argues the cargo gaps *are* the
   map, and every one of those gaps is a player-side fact.
3. **A boarder in lane 0 or 2 can never damage the Boiler.** It is clamped no
   closer than x = ±370, the Boiler is at (0, 850) with radius 62, and a
   SCRAPPER's `attack_range` is 66 — the check at `enemy.gd:158` needs 156 and
   the geometry gives 370. Only lane 1 can hurt the objective directly. I am
   reading this, not measuring it in play, and it may be intentional; either way
   it means "the middle lane is the one that matters" is a fact of the geometry
   that nobody wrote down, and any map change that moves the Boiler or the lanes
   changes the game's win condition without appearing to.
4. **It makes generated layouts safe.** The classic procedural failure is a
   layout that blocks the only path and makes a wave unwinnable. There is no
   path to block. The clamp is a guardrail we did not know we had, and it is why
   §4 can recommend seeded generation at all.

## 3. What a "map" is here

Not a level. **A stowage.**

Rejected first, and explicitly:

- **A second deck** (a different ship, different dimensions). Every number in §1
  says no, `parity.py` poses both builds on the same deck to make the only
  evidence this project has for a parity claim, and the deck geometry is
  currently hand-built in `_build_world` at fixed sizes — planking UVs at
  `Vector3(1.8, 7.0, 1.0)`, a hull box at 94% × 98% of the rect, rails at the
  four edges. A second deck is renderer work, art work, a second camera
  calibration and the loss of the parity baseline, and it buys variety that a
  crate can buy.
- **More lanes, or lanes that move.** `LANE_CENTERS.size()` is read as the
  turret count, the crew muster loop, the spawn loop and the lane readout, and
  the ±190 clamp is arithmetic around three fixed centres. Four lanes is a
  rebalance of all twelve waves wearing a map's clothes.
- **A vertical layer** (rigging, a second deck level). Every figure is a
  billboard or a rig standing on `y = 0`; `_to_screen(ground, height)` takes a
  height but the simulation is strictly 2D. This is a new game.

What is left, and it is more than it sounds: **three axes of variation on one
deck**, each with a hook that already exists.

**a · The crossings.** The four `CARGO_RECTS` per side leave exactly three
cross-passages, at y ∈ `[−570, −370]`, `[−100, 130]` and `[410, 620]` — the
`−470 / +15 / +515` that `CLASS-2-DESIGN.md` §4 calls "learning the class". They
are the player's entire lateral movement graph. Closing one, opening a fourth,
or shortening one from 200 units to 90 changes where you can be, how long a
lane-change costs you, and whether the far lane is reachable before it breaks.
This is the highest-value knob on the ship because it is the only thing that
changes movement rather than decoration.

**b · The stowage.** Thirty entries in `PROP_LAYOUT`, twelve prop kinds in
`SkyGearProp.TEXTURES`, four of them targetable (`keg`, `crate`, `crates`,
`lantern`). A keg is a bomb you position yourself next to; a crate is salvage
and 26 HP of cover; a lantern is a fire field waiting to happen; `crates` is 38
radius of hard cover the player cannot shoot through but can hide behind. That
is already a vocabulary with four verbs in it, and it is re-instantiated from
scratch at every `start_wave`.

**c · What has happened to this ship before.** §5.

## 4. How variety is generated

**Rejected: free procedural placement over the deck rectangle.** Three reasons,
in order of weight. It would move the three deck vents, and the Boilerwright's
entire class is "learn where the three vents are" — `parity_test.gd:1969` asserts
*"every lane has a vent to refill at"*, which exists because a starved middle
lane is a lane nobody holds. It would break `tools/parity.py`, which poses both
builds at the same seed and wave and stitches them: a Godot deck the browser
cannot reproduce makes every future parity shot incomparable, and parity is an
open item. And unbounded generation has no upper bound on weirdness, which means
the review cost per seed never goes down.

**Rejected: N hand-authored alternative decks.** Thirty placements each, a
screenshot review each, and after five of them run 6 has seen everything. It is
the most expensive variety per unit of variety on offer. (Not rejected as a
*test*: one alternative layout is the cheapest possible experiment and is in the
cost table.)

**Accepted: seeded arrangement over authored slots.** A `STOWAGE` table beside
`PROP_LAYOUT` in `game_data.gd`, where each entry is either **fixed** or a
**slot**:

```
{"type": "vent",  "position": Vector2(40, 15), "fixed": true}
{"slot": "waist_port", "position": Vector2(-520, 480), "jitter": 70,
 "of": ["keg", "crate", "crates", null], "weight": [3, 3, 2, 2]}
```

The positions come from `PROP_LAYOUT` as it stands, because it is already a good
layout that someone looked at. What varies is *what stands in each slot*,
whether the slot is empty at all, and a small jitter. Fixed forever: the mast at
(0, −180), the two hatches, the four railings, the two ballistae at the bow, and
all three vents. Those are the ship; the rest is cargo.

**The seed is not negotiable, and there is already a precedent for how to do it
right.** `restow_props()` places POWDER STORE's extra kegs from `visual_rng`
with the comment *"placed with the cosmetic stream, or a talent would move every
seeded roll after it."* That is exactly the trap, and it applies here with more
force: if stowage draws from `rng`, then owning a talent, or a fitting, or
playing a different class shifts every crit roll and draft offer for the rest of
the run, and the seed stops being a seed.

So: a **third stream**, `layout_rng`, seeded `hash(seed_text) ^ (wave *
2654435761)`, reseeded at each `start_wave`, consuming nothing from either
existing stream. Deterministic in the seed, independent of wave order,
independent of the player's entire history. Same seed, same twelve decks,
forever, for everyone. One new harness check: run seed "STOW" twice and assert
the twelve stowages are byte-identical, and assert that rolling the stowage
leaves `rng.state` untouched.

**Per wave, not per run.** This is the free lunch and it is worth stating
plainly, because it is the reason the whole recommendation is cheap:
`restow_props()` is *already* called at every `start_wave`, already frees every
prop and rebuilds the set. Twelve stowages per run costs the same as one. A run
where wave 5 puts the powder amidships and wave 9 clears it is twelve small
variations rather than one, at zero additional structural cost, and it gives the
draft screen something to be about — the Manifest talent already shows the next
wave's composition, and showing the next wave's *stowage* beside it is the same
screen.

**Seeded variety is not meta-progression, and is therefore not gated.**
`META-PROGRESSION-DESIGN.md`'s first hard constraint is that nothing exists
before the first victory, because the shipped baseline must be pinned. Seeded
stowage does not violate it: the draft is already seeded and varies wildly run
to run, and nobody argues that unpins the baseline. The line is *whether the
player's history is an input*. A stowage rolled from the seed is not; a fitting
earned in a previous run is, and is gated (§5).

One real cost: `tools/balance.gd` plays six fixed seeds and reports whether
twelve waves is a curve. With per-seed stowage its answer acquires a new source
of variance, so either the seed count rises or the acceptance band widens. Say
which before the first stowage lands, not after balance goes noisy.

## 5. The ship as the second character

> **BUILT 2026-08-02 (board SG-56), with two departures this section should
> own.** The owner's midnight direction (docs/OUTSTANDING.md) reframed the
> mechanism: the stowage table this section says fittings change was CUT by
> §7.1's own kill-test (SG-48), so a fitting changes the DECK DIRECTLY, once,
> at run start, from the berthed set — never mid-run (`fittings · the ship
> never changes mid-run — a berth signed mid-run waits for the next run`).
> And two earn rules named data the run row does not record (cannon losses,
> repair counts); under the no-new-tracking constraint they read `wave >= 9`
> (both pushes held) and `salvage >= 12` instead — the mapping is on the
> SG-56 board row. The hard rule below is enforced verbatim by `fittings ·
> no fitting names a forbidden field`; the bare-ship baseline by `fittings ·
> a ship with nothing berthed sails today's deck exactly — byte for byte`;
> the WINCH shipped as the SG-37-corrected tap-to-haul, not this section's
> 2.0-second channel. The wreck sits off the bow (SG-15's placement), not in
> lane 1 as written below.

The Workshop makes the captain better. If the ship layer also makes numbers
bigger it is a second Workshop with a different noun, and the game will have two
trees that have to be balanced against each other forever. The rule that
prevents it should be stated once, in the same form as
`META-PROGRESSION-DESIGN.md` §7's gate:

> **If a ship upgrade can be expressed as a change to `mods`, to `player`, or to
> a starting value, it is a Workshop talent and it goes in the Workshop. A
> fitting may only change the stowage table or the deckwork verb table.**

That makes the two layers mutually exclusive by construction rather than by
taste, which is the only version that survives the twelfth person adding to it.
Corollary, written down here because the first person to add a fitting will want
to break it: **no fitting may move `boiler_hp`, `turret_hp`, `turret_rate`,
`extra_kegs`, `extra_crew`, or any field in `SkyGearWorkshop.NODES`.**

### Earned, not bought

I considered making fittings a third currency and rejected it. Two currencies
exist, and META-PROGRESSION's argument for them is precise: scrip buys
experiments, sigils buy commitments, and sigils come only from firsts so the
impactful currency is unfarmable *by shape*. A third currency needs its own
earn rate, its own farm-resistance argument, and its own screen. It also puts
the ship in competition with the Workshop for the player's attention at exactly
the moment the meta doc warns the front door is at risk.

**Fittings are not bought at all. They are what the ship kept.** At the end of a
run, the ship gains at most one fitting, and which one is a function of what the
run row already records — `won`, `wave`, `close_share`, `vents`, `heat`,
`class_id`, `cards`. No new tracking, exactly as the Workshop needed none.

- Kill the Colossus → **THE WRECK.** `SkyGearProp.TEXTURES` already contains
  `"wreck": "res://assets/art/props/colossus_wreck.png"`, `PROP_HEIGHT` already
  gives it 210, `SCALES` already gives it 0.34, and **no `PROP_LAYOUT` entry has
  ever placed one.** The art is on disk, sized, and unused. Its corpse stays on
  your deck: 210 units of hard cover in lane 1, in front of the Boiler, forever.
  This is the whole design in one line of data.
- Hold both pushes without losing a cannon → **THE BOW BARRICADE.** Two `crates`
  across the bow gap in lane 1.
- Win at Heat 1 → **THE SPARE GUN.** A fourth cannon on the stern line, which
  starts `dead: true` and has to be repaired with the deckwork verb that already
  exists before it fires at all.
- Repair five cannons across a run → **THE WINCH.** Not an object: a *verb*. See
  below.
- Win as the Boilerwright → **THE FOURTH VENT**, placed in a cross-passage of
  your choosing. The only fitting that moves a refill point, and it is his.
- Win without healing → **THE SCUPPER GRATING.** Closes one cross-passage to the
  player and puts a vent in it. A cost with a benefit, which is the shape every
  fitting should aspire to and most will not manage.

### Where it meets deckwork

`deckwork.gd` is a verb table with one verb in it, written as a table from day
one *precisely so that the second verb is one entry*. `OUTSTANDING.md` already
owes the verbs the original ask was about: "dragging a crate to close a lane,
funnelling, shaping where the fight happens."

Note §2: **funnelling boarders is not available**, and the outstanding item is
describing something the simulation cannot do. What *is* available, and is worth
as much, is the player moving their own cover. THE WINCH — `"id": "drag_crate",
"verb": "HAUL THE CRATE", "at": "prop", "reach": 96, "seconds": 2.0` — moves a
`crates` prop 200 units along the deck, at the cost of two seconds of standing
still, which `deckwork.gd`'s own header argues is already the sharpest cost in
the game. That is the ship's ability, drafted the way the captain drafts hers:
**the deckwork table is to the ship what the 36-cell matrix is to the captain.**
Fittings that grant verbs are the ones worth having; fittings that are only
scenery are the filler tier, and there should be few of them.

### The berth cap

Fittings accumulate forever, and a deck that only ever gains cover is a deck
that gets easier every run — which is the Rogue Legacy failure arriving through
a side door. So: **six berths.** You own every fitting you have earned; you sail
with six. Chosen between runs, never mid-run, free to change, exactly like the
Workshop respec and for the same reason.

And the gate: fittings are meta-progression, so they live behind
`state.unlocked` and are awarded in `SkyGearWorkshop.bank()`, which is already
*"the one place that knows the rule."* Not a parallel gate. The same one.

**The run log has to record them.** (The bug this paragraph originally named
is fixed: `SkyGearRunLog.record` writes `heat` since e32210d beside `seed`,
`build`, `cards`, `class_id`, and board SG-53 pinned the round-trip —
`log · and the row carries the class and the heat that reproduce the run` —
and surfaced heat on the report line and the title readout.) Fittings would
open the same hole again, so one field when they exist: `"ship": [ids]`.

## 6. Downtime — walking the ship

This is the most interesting of the four asks and the most dangerous, and I want
to be unsentimental about it, because `META-PROGRESSION-DESIGN.md` §8 already
named this exact failure before anyone proposed it:

> *"It is that the between-run screen becomes the game's front door, and the
> front door is worse than the game. Today you press Enter and are fighting in
> four seconds."*

A walkable hub is that risk in its strongest available form.

**What can walking do that a menu cannot?** For the Workshop: nothing. A tree of
24 nodes in four branches is faster and clearer as a tree, and walking to a
node's physical location is a tax on reading it. If a hub existed only to house
the Workshop, the honest answer is "nothing, but it feels better," and I would
not build it.

For the ship: **one thing, and it is real.** Choosing which six fittings to
berth is a *spatial* choice — you are choosing where cover is, which
cross-passage is closed, where you can refill. A list can tell you "BOW
BARRICADE"; it cannot tell you that berthing it and the Wreck together leaves
lane 1 with no clear firing line from the Boiler. Standing on the deck and
looking at it can. That is a genuine argument for a walkable space, and it is
conditional on §5 existing. **Downtime must not ship before the refit does**,
or it is a lobby in front of a menu, which is the failure verbatim.

**Can it be skipped?** Yes. Unconditionally, from the first run, with one key,
and the key is the one that already starts a run. Two reasons. The project's
proven virtue is that you press Enter and are fighting in four seconds, and
nothing in this document is worth four seconds of that. And a hub that cannot be
skipped is a hub that every experienced player resents, which converts an
optional pleasure into a recurring tax. The corollary is the test: **if the hub
can be skipped and nothing is lost, the hub is optional content — which is
exactly the correct status for it.** It should also never be entered
automatically. `Enter` deploys; a separate key walks.

**The minimum version already exists and nobody has noticed.** `main3d.tscn`
puts `view3d.gd` above `main.tscn`, and `view3d.gd` never reads `game.state` at
all — it mirrors the simulation into 3D every frame regardless of what the
simulation is doing. Meanwhile `hud.gd:91` opens `_draw_title` with
`draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.025, 0.045, 0.72))`. **The
title screen is the ship, at the shipped camera, with the captain standing on
it, behind a 72% scrim.** The minimum version is: drop the scrim, give her back
`controls_enabled` with an empty `spawn_queue`, and let the existing deckwork
prompt fire on the fittings. No new scene, no new camera, no new art, no new
load, zero export bytes.

Its real cost is not the camera. It is that `state == State.PLAY` appears
thirteen times in `game.gd` as the gate on input, movement, skills, coach hints,
voice and the deckwork key. A `State.WALK` means auditing all thirteen and being
sure that none of them was the thing keeping the simulation from ticking. That
is an afternoon and it is the whole bill.

**Rejected: a below-decks interior.** A room is not a camera change, it is a
projection change, and this project has exactly one projection with roughly 350
harness checks standing on it. `PROP_HEIGHT` is a table of ground-unit heights
solved for 41°; every character is a billboard or a rig oriented for 41°; the
decal effects lie flat on the deck plane; `_occluded()` x-rays a boarder behind
cargo using a ray from the camera's own position; `hud.gd:_to_screen` unprojects
through the same matrix; `parity.py` poses both builds through it. A second
camera mode is the first thing in this project to need one, and I would not
spend it on a corridor.

**Rejected: a camera pull-back between waves.** Between waves *is* the draft,
the draft is the best moment the game has, and putting a stroll inside it dilutes
a decision with a walk.

**Load and export.** The Windows executable is currently **242 MB**
(`builds/windows/SkyGear-Godot.exe`), the itch zip **162 MB**, and
`assets/models` is **163 MB of the 200 MB asset tree** — the models are already
four fifths of the download, and the Meshy pipeline has generated maybe a
quarter of the props it is going to. A hub on the existing deck adds **zero
bytes and zero load**: the scene is already resident, the props are already
instanced, the deck mesh is already built. An interior adds a mesh set that
nobody fights in, for a space walked through once per session, onto a download
that is already at the edge of what an itch page should ask for.

## 7. Failure modes

**1 · Variety that is noise rather than decision.** A stowage roll that does not
change where you would stand changed nothing, and the game is now less
predictable without being more interesting. The measurable version exists
already: `SkyGearTelemetry.note_range` buckets time by distance to the nearest
boarder and `_close_share()` reduces a run to the number the project judges
itself by. Run `tools/balance.gd` over its six seeds with the stowage table flat
and with it live; **if the close-share distribution is indistinguishable, the
variety is cosmetic and should be cut rather than tuned.** Decide the threshold
before building, not after looking at the numbers.

**2 · A ship so customised that balance claims mean nothing.** Three guards, all
structural. The berth cap of six. The rule that no fitting touches a number.
And a **bare-ship baseline**: `parity_test.gd` runs `plain` against `kitted` on
seed "NOSHOP" — that is `shop · and a bought tree actually changes the run`, which
proves the tree DOES something, not that it is small. The "worth less than three
cards" claim is a SEPARATE check, `shop · the whole tree is worth less than three
cards` (×1.31 tree vs ×2.28 cards, both measured since SG-11). The same shape
applies here, with a run on the bare deck required to reproduce today's numbers
exactly, and every Heat claim measured on the bare deck. If a fitting cannot be added without moving the bare-deck run, it is not a
fitting.

**3 · Generated layouts that are unwinnable or trivial.** Largely foreclosed by
§2 — a boarder has no path, so no layout can block one. Three residual risks,
all with numbers:

- **Keg chains.** `explode_keg` calls `_damage_props_circle(center, 175.0,
  78.0)`; a keg has `radius` 25 and `max_hp` 34, so any keg whose centre is
  within **200 units** of a detonation detonates too, for 78 damage into
  everything in a 175 radius. Four kegs in a line is a lane-clearing bomb the
  player did not design. Minimum keg separation of 200 units is a hard
  invariant, and note it can already be violated today: POWDER STORE drops extra
  kegs anywhere in x ∈ [−640, 640], y ∈ [−300, 500].
- **Too much cover.** v11 exists because range-kiting healed faster than three
  lanes could hurt you, and a deck dense with `crates` (radius 38, hard collision
  for the player, no collision for boarders) is a kiting course. Cap total
  targetable props and total cover area in a band around today's values.
- **Too little.** A stowage that rolls all four kegs into lane 2 leaves lanes 0
  and 1 with no ordnance, which is not variety, it is a bad hand dealt by the
  floor rather than the draft.

**4 · Heat.** Heat is the existing difficulty ladder and `best_heat` is a
permanent record. If the deck varies, a Heat 2 clear stops being comparable
between players. The fix comes free from §4's construction and should be stated
as the reason for it: **stowage is a function of the seed alone**, so two
players on the same seed at the same Heat fought the same twelve decks, and a
Heat clear remains a fact about a specific seed. Fittings are the danger here,
not stowage — a Heat 2 clear on a six-fitting deck is not the same achievement
as one on a bare deck. Either the Heat rung records the fitting count in the log
row, or Heat runs sail bare. I lean toward recording it, because forbidding
fittings at Heat makes the two systems enemies.

**5 · The front door.** §6. It is the reason the hub is last in the build order
and skippable in the first version.

## 8. What it costs, and the order I would build it

| Item | Kind | Touches | Return |
|---|---|---|---|
| **THE WRECK as a permanent fitting** | data | one `PROP_LAYOUT`-shaped entry, one award in `bank()` | highest in the document per byte: art already on disk, unused, and it is a trophy that changes lane 1 |
| `layout_rng` + `STOWAGE` table + seeded `restow_props` | data + ~60 lines sim | `game_data.gd`, `restow_props()` | the entire variety spine, and the seed guarantee |
| Stowage invariants + 3 harness checks | test | `parity_test.gd` | what stops §7.3 from being discovered in a playtest |
| `tools/stow.gd` (§9) | tool | new file, registered in `tools/hub.gd` | makes this and every future layout change cheap |
| Fittings 2–6, berths, the `ship` field in the run log | data + ~120 lines | `workshop.gd`, `runlog.gd`, results screen | the "becomes theirs" ask, properly |
| THE WINCH (`drag_crate`) | sim, ~40 lines | `deckwork.gd`, and the prompt `OUTSTANDING.md` already owes | the verb the original deckwork ask was about |
| Variable cross-passages | data + small sim | `CARGO_RECTS` becomes per-run data, read in 4 places | the highest-value knob, and the one most likely to need re-tuning |
| A berth screen | UI | `ui.gd` widgets, as the Workshop screen does | needed before the hub is worth anything |
| **The hub — walk the existing deck** | sim + audit | 13 `state == State.PLAY` gates, a `State.WALK` | the ask's most requested and least necessary piece |
| ~~A below-decks interior~~ | **cut** | second camera, interior art, +MB | §6 |
| ~~Enemy collision / pathing~~ | **cut** | the clamp, every wave's balance | §2 |
| ~~A second deck~~ | **cut** | renderer, camera, parity baseline | §3 |
| ~~A third currency~~ | **cut** | — | §5 |

**Ship first: the Wreck, `layout_rng`, and the stowage table over the eight
dressing slots that `PROP_LAYOUT` already labels `# dressing`.** It is data plus
about sixty lines plus two checks. It proves the entire spine — that the deck
can vary, that a seed still reproduces a run, and that the ship can keep
something — in under a day, and every later item builds on exactly those three
facts. If the close-share numbers come back unmoved by it (§7.1), the rest of
this document should be cut rather than continued.

**Cut first if time is short: the hub.** It is the ask I would most enjoy
building and the one the game least needs, and the version that costs nothing is
already sitting behind a 72% scrim.

## 9. The tool this needs before it needs code

`tools/balance.gd` already plays twelve waves headless across six fixed seeds
and prints a damage split, and it is the reason the crew rebalance was answered
with numbers instead of three runs and a feeling. The equivalent here is
**`tools/stow.gd`**, registered as a `check` in `tools/hub.gd`: roll N seeds ×
12 waves of stowage without launching a renderer, and assert the invariants —
a vent in every lane, no two kegs within 200 units, every cross-passage
passable, at least 24 pieces (**UNVERIFIED — no "24 pieces" check exists**; the
`parity_test.gd:855` reference is stale, and the nearest surviving prop-count
check `view · the deck is dressed` asserts only ≥ 4), cover area inside its band — then print the worst offender per invariant with its seed
and wave.

That is what makes the fiftieth fitting as cheap to add as the second, which is
the only test of whether this was designed or merely written down.

## 10. Where I am guessing

Said plainly, because half of the above is arithmetic off constants and the
other half is judgement.

- The visible-deck figures in §1 (1320 units of depth, ±622 of width, 36.07°)
  are my derivation from the camera constants at 16:9. They agree with the one
  number the harness pins (36.1°) and with the open "camera is zoomed in"
  finding, but nobody has put a ruler on the screen. **Measure before relying on
  any of them.**
- §2.3 — that lanes 0 and 2 cannot reach the Boiler — is read from the clamp and
  the attack ranges, not observed in a run. It should be trivial to confirm and
  it changes what "the map" means if I am wrong.
- Everything about how a stowage *feels* is unevidenced. The project has close to
  zero cold playtests, `META-PROGRESSION-DESIGN.md` says so, and that has not
  changed. §7.1 is the cheapest way to find out and it costs one afternoon with
  `balance.gd` before a single fitting is designed.
- I have not proposed numbers for how often a slot rolls empty, how much jitter,
  or how many kegs a deck should carry. Those are playtest numbers and inventing
  them here would make them look decided.
