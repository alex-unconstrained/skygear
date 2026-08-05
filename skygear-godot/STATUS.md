# SkyGear Godot port -- where things stand

Last updated 2026-08-04. **Read this first, then `docs/BOARD.md` — the work
queue agents claim items from and report evidence to. `docs/OUTSTANDING.md`
stays the ledger of owner asks; an ask lands there first and is mirrored to
the board as workable items.**

**THE GOAL CHANGED 2026-08-01, by the owner:** visual parity with browser v11
is retired — *"we build the Godot version to be better than the web one ever
was."* The browser is a reference and a regression yardstick now, not a
ceiling. Judge visual work by "is it better and legible," not "does it match."

**AND ON 2026-08-03 THAT WAS EXTENDED TO MECHANICS, BECAUSE A CHANGE SHIPPED
THAT BROKE IT (SG-148, reverted as SG-159).** SG-148 found the browser's
`noCrit` flag on six secondary damage sources, called the port's crit a
divergence, and took crit away from the kill explosion, the vent, fire pools,
the kegs, the lane cannon and the crew. The owner: *"Why are we getting rid of
CRIT? That's an important mechanic... We've moved so far beyond the browser
version of this game. I do not want you going back and trying to refer to the
browser game. We've transcended that."* All six crit again. **The rule that
follows, and it is now a standing one: "the browser does it this way" is not a
reason to change how this game plays.** A behavioural change needs a Godot-side
argument and a measurement. The browser is still a place to LOOK — it is where
SG-147's real crash fix came from — but a diff against it is a question, never
a verdict. Two live rows had browser fidelity as their whole rationale (SG-148,
SG-154) and both are struck.

Playable end to end: twelve waves, two classes, a draft, persistent progression,
a difficulty ladder, a sky, a cutscene system with all five cues filled —
a run-opening reveal, event-wave flourishes, the Colossus arrival, and victory
and defeat shots — and, since 2026-08-02, **the ship's own progression**: six
FITTINGS earned by finishing runs (at most one per run, `scripts/fittings.gd`),
chosen into six berths BETWEEN runs on the title's berth screen, applied to the
deck once at run start and never mid-run (the owner's rule, harness-pinned —
board SG-56). **1128 harness checks**; the text audit covers 25 screens at
4 widths and **is clean as of 2026-08-02, for the first time in a while** — the
sentence above it said so for days while the audit reported a BERTHS overflow on
every windowed run, filed under an ID (SG-68) that belongs to a different,
finished row. Board SG-92 has the whole of it, and the reason it was one finding
rather than four. Build 64 is on itch at
https://alex-unconstrained.itch.io/skygear-godot-test (butler pushes directly
from this machine now) and the source is at
https://github.com/alex-unconstrained/skygear

**THE CREW ARE BEING SLAUGHTERED AND NOBODY IS SWINGING AT THE CAPTAIN (SG-193
and SG-194, 2026-08-04, owner after build 62: *"Do enemies fight and kill crew
members? Furnace knights dont seem to do any damage to me or attack crew
members."*). Both halves of that sentence were measured and NEITHER was tuned.**
The crew half is FALSE and loudly so: over twelve full runs and **4,062 resolved
boarder swings**, **36.6% were aimed at a crewman**, 34.0% landed on one, and
**21.6 sailors are killed per run** out of 47.4 mustered — 1,714 crew HP, better
than 25 whole hands. The captain half is TRUE and is the same finding from the
other end: **0.2% of every swing on the deck is aimed at her.** The priority
chain in `enemy.gd` reads captain-inside-280, then the lane cannon while the
boarder is still ahead of it, then a crewman inside 220, then the Boiler — and
the cannon really does suppress crew targeting (destroy all three and the crew
share goes **36.6% → 89.1%**, kills **21.6 → 71.4**, intervals not touching) —
but only partially, because a boarder that walks PAST its gun is released. **And
the furnace knight is not broken, he is never in range**: against a pinned
captain he lands **180 of 180** resolved swings at 17.00 dps and kills her in
5.9 s; against `tools/bot.gd` he resolved **ZERO swings in six minutes** and
**closed to 100 units against a swing that trips at 99** — one unit short, for
the whole window, because the bot breaks contact at 90 and he walks at 75 against
her 260. **Two rig lessons came out of it.** SG-165's headline that the health
buff took his orbit arm to "10 resolved and 9 landed" is WITHDRAWN — it predates
SG-190 and on the corrected clock that arm is 0. And **SG-190 is not finished**:
a rig can set `physics_ticks_per_second = 20`, read back 20, sit inside a physics
frame, and STILL be handed 1/60 by `get_physics_process_delta_time()` while
`move_and_slide` integrates 0.05. `tools/crew_probe.gd` asks for no clock at all,
steps at the engine's own delta, and prints `ground / (|v| × DT)` above every
result — **1.011 and 0.988**. The one code change is a refactor with no behaviour
in it: the victim chain is `enemy.victim()` now and the swing writes
`enemy.last_swing`, so a rig reads the simulation's own answer instead of keeping
a second copy of 280/220/40 — proven neutral by `tools/balance.gd` coming back
**byte-identical on all six seeds**. Twelve `victim ·` checks, and the one that
had never existed in any form is `victim · and enough of them KILL him`.

**THE COLOSSUS COULD BARELY SCRATCH THE SHIP AND THE BOARDING HULK OUTLASTED THE
WAVE IT BELONGS TO — both from the owner's first full twelve-wave run, Heat 2,
seed YBWDW5, won 6:23 (SG-185 and SG-186, 2026-08-04).** *"Collosus didnt seem
to be able to damage turrets."* He was right about the outcome and the mechanism
is worth knowing: the STOMP sits at the head of the Colossus's move state and
PREEMPTS his swing, and the swing was the only beat that carried a victim other
than the captain. He was not unable — he was at **32% of the rate**, which at
23–31 s of life is the same thing: **8 swings and 208 HP off a 760 cannon in 60
seconds, against 25 swings and 650 with the stomp off**, so the cannon needs 219
s and he never once destroys one. The stomp is an area now and it hits
everything standing in it — captain, cannons, crew, Boiler, one circle, no
priority order, `stomp_hits` asked per candidate so nothing derives a second
shape. **Off the same cannon in the same 60 s, after: 390 at Heat 0 and 442 at
Heat 2 — +114% and +112%**, which is 62–68% of the chase build's rate while
keeping the telegraphed, escapable beat that earned the lane walk. **And the
Boiler statistic COLOSSUS-DESIGN §2 has been
arguing about since July is now settled the other way: 0.00, sd 0.00, over 181
wave-12 runs. He does not reach it.** The lever is his ARRIVAL, not his damage.
*"Boarding hulk took a long time to kill."* Also right, and it was a missing
line: `_resolve_cast` has ended in `hulk_splash` since it was written, under a
comment saying every shape must be able to bite the hulk — and the BASIC ATTACK,
36% of his own run's damage, never got it and **would not even swing at a hull
with the lane clear (2 auto swings in 28 seconds)**. Now 47, and the hull breaks
in **16.7 s** against a floor of 28.3. A boarder still wins the aim every time
one is in reach; the hull is a target of last resort.

**EVERY SIMULATED VERDICT IN THIS LEDGER WAS TAKEN WITH THE BOARDERS WALKING AT
ABOUT A SEVENTH OF THEIR SPEED, AND THE NUMBER CHANGED WITH HOW BUSY THE MACHINE
WAS (SG-190, 2026-08-04).** `CharacterBody2D.move_and_slide()` does not
integrate against the delta you hand `_physics_process`. It asks
`Engine.is_in_physics_frame()` and takes `get_physics_process_delta_time()` if
the answer is yes and **`get_process_delta_time()` — the idle frame's WALL-CLOCK
duration — if it is no.** A `_run` reached by `call_deferred` from
`_initialize` has never been inside a physics frame, and neither has anything
resumed after `await process_frame`. **So `Engine.physics_ticks_per_second = 20`
— written in `balance.gd`, `boss_probe.gd`, `melee_probe.gd` and `critx_probe.gd`,
correct, and load-bearing — was read by NOTHING.** Measured in a six-line probe:
that delta is **0.0000** before any await, **0.0500** after `await
physics_frame`, and the idle frame it was actually using was **0.0069**.
**This is most of the "still not deterministic" residual `balance.gd`'s own
header blames on the physics server, and that header was wrong** — the proof is
the fix: with the rigs stepping inside a physics frame, **twenty reps of one
seed now return bit-identical rows, across separate processes.** **The rig being
deterministic costs something that must be said out loud: `reps` BUYS NOTHING.**
`6 seeds x 20 reps` is n=6 printed 120 times, not n=120, and an interval off
that 120 is ~4.5x too narrow — SG-128's exact sin in a new hat. Buy n with
SEEDS; `boss_probe`'s list is 32 now and it prints a refusal in words when a
seed's reps come back identical. **Whether a given historical verdict survives
is a question per row, and re-running is cheap now** — start with anything that
turned on a boarder ARRIVING somewhere. One `bot ·` check pins the rule for the
next rig, and it reads the `tools/` roster rather than a list of names.

**EVERY BOARDER'S SWING WAS SPEEDING UP WHILE IT PLAYED, AND THE FILE HAD
WRITTEN THE RULE DOWN THREE TIMES (SG-188, 2026-08-04).** `_sync_rig` handed the
swing `enemy.state_time` — a COUNTDOWN — as the window to fit the clip to, and
`want()` recomputed `speed_scale` from it every frame, so as `state_time` ran
0.90 → 0 the rate climbed with it. Because `swinging` holds the rig in `swing`
for the windup AND the recovery, **the ramp ran twice per attack**, and `want`'s
`elif not anim.is_playing()` arm — there to restart a CYCLE the blend dropped —
dealt the finished one-shot a third time. Measured live over six consecutive
attacks on a real deck (`tools/swing_beat.gd`): **1.83x rising to the 4.00x clamp
in every one of them, and 2.50 full plays of the swing clip per single 34-damage
hit.** Two and a half swings for one hit is read as one swing at two and a half
times the speed, which is exactly what the owner reported. The second cause was
real and smaller: his pack rotates six swing variants from 1.27 s to **3.53** s,
and at the old window those played at 1.41x to 3.93x — a beat that changed by
2.8x shot to shot. **Three renderer-only changes and nothing else**: the window
is `SkyGearEnemy.attack_beat()`, asked of the SIMULATION rather than restated in
the renderer (because `_windup_scale()` shortens the wind at Heat 2, and a
renderer restating that is failure mode two with a difficulty ladder bolted on);
a one-shot latches its rate on the frame it STARTS; and a finished one-shot holds
its follow-through instead of being dealt again. **Worst rate 4.00x → 0.98x,
plays per attack 2.50 → 0.13, the simulation untouched, the captain and the
Boilerwright byte-identical.** The crew are NOT fixed and are filed rather than
folded in — their swing is still fitted to a countdown and nothing has measured
what it looks like (**SG-189**, open).

**AND THE CREW LEAVE A CLEARED LANE NOW (SG-187, 2026-08-04)**, on the owner's
own ask after his twelve-wave run: *"Dont have crew standing around and auto
attacking at the end of their lane."* **Two faults, one line**: `_update_crew`
sent a crewman with nothing to fight to a fixed point at the head of his lane and
tested arrival with `distance <= reach` — a test that asks how far away his GOAL
is and never asks whether anything is STANDING in it. So he arrived, wound up,
swung at bare planking, recovered, and repeated for the rest of the wave. Four
rules, written at `SkyGearLanes.ASSIST_LEASH`: his own lane outranks everything
and is re-asked every tick, so the recall is THE ORDER OF TWO LOOPS rather than a
timer that can run out; the leash is ONE adjacent lane, measured from his STATION
rather than his feet, because a leash measured from the feet lets a man walk the
deck one leash at a time (recall from the far edge is 4.7 s against 6.6 s for the
fastest boarder in the game to reach the gun from the bow); one man per boarder,
claimed in muster order, which makes the anti-clump guarantee arithmetic rather
than a hope; and the longest-serving unengaged hand in each lane never leaves it,
so no arrangement of boarders can empty a lane. **The roaming is free** — crew
damage share 6.02% → 6.30%, taken 346.0 → 358.5, held 80.0% → 80.4%, none of it
clearing what the sample resolves, and reported as *under the instrument* rather
than as "no effect". **The expensive finding is the one nobody asked for.** Every
hand in a lane holds the SAME station, so four sailors of radius 15 stand inside
one another — invisible while they mill through a swing cycle, obvious the day
they stand still. Fanning them out ±120 cost **crew damage −24% and damage taken
+17%**; fanned down the lane cost the same; holding station with no roaming cost
it too. That rules out "a roadblock with a hole in it" and leaves the mechanism:
**a stacked watch is four swings on one boarder with no walking, and 120 units of
separation is about a second of not swinging per man per boarder for the whole
run. Crew damage is a RATE, and a rate is what a walk costs.** So the fan is
REFUSED and `POST_SPREAD` is deleted rather than set to zero — a knob whose only
correct value is zero is a knob somebody turns.

**HIS THREE HAND-MADE WEAPONS ARE IN HANDS (SG-170).** The boarding pike, the
furnace axe and the scrap wrench were in `assets/models/`, loading through
`ResourceLoader`, registered in `weapons.json` — and on nobody. **The gap was not
a number, it was a call that did not exist**: the only `hold()` in the whole
renderer was the hero's, so table rows alone would have moved nothing. That is
the first failure mode in its largest coat — not a field with no reader, **a
whole asset class with no reader** — and every green signal around it stayed
green throughout. It is one function called from the one-time setup block of
`_sync_rig`, and the hero's own block was MOVED onto it rather than left beside
it so the 1.8 m-frame scaling exists once: `weapon · a weapon is scaled by the
figure holding it, not by the captain` mounts one row on a 1 m body and a 2 m
body and requires the reach to double (0.938 m against 1.875 m, ratio 2.000).
**The deliverable is the live check** — `weapon · a live deck puts the pike, the
axe and the wrench in the hands they were made for — the SG-170 regression` reads
`_rigs[key].held` off a real simulation rather than calling `mount_weapon`
itself, because a check that armed the deck would have passed every run of the
week the deck stood empty-handed. Proved by negative control: comment the one
line out and the run is 1067/1069. **The fits are the owner's**, finished by hand
in the lab.

**AND FOUR THINGS THAT WERE ALL THE SAME BUG — A PICTURE THAT DID NOT AGREE WITH
WHAT IT COSTS YOU.** *(a)* **The danger wedge's boundary was a gradient**
(SG-162), which is the one line in this game the player stands next to on
purpose: it peaked at 88% of the reach and had fallen through half its brightness
by 93.5%, so on the Colossus's 146 the brightest part of the kill zone was at 128
and the picture was over nine units short of the deck that kills you. The target
was `_ring_texture()`'s own principle, twenty lines up the same file and never
applied here — *a fill you can see through and an edge you cannot miss*. Now the
brightest pixel is at **99% of the reach**, fill 0.21 against an edge of 1.00.
**And the feathers are in TEXELS rather than in fractions of the shape**, which
fixed a second thing nobody had chosen: quoted as 16% of the half-arc, the
Colossus's boundary was **three times softer than a gremlin's** (`telegraph · and
the wide fan is no softer than the narrow one, which it used to be by 3x`). The
size did not move and that is pinned twice, because a rim pushed outward to look
bolder would have been SG-119's bug wearing this fix's clothes. *(b)* Beside it,
**the strike flash and the recovery ring** (SG-158, the owner said go): the blow
that LANDED gets its own mark over the first `STRIKE_FLASH_FRAC` 0.20 of the
recovery window — 200 ms at the Colossus, 130 at the furnace knight — so the
flash of one blow can never be read as the warning of the next. *(c)* **A fire
pool burned you from outside its own picture, by up to 70%** (SG-163). Three
numbers claimed to be one radius and the damage read none of them: the tick
burned at a literal 78.0 written twice, the renderer sized the pool off
`radius * 2.2` with per-site radii of 46, 62 and `62 + 22·residue`, and the
hidden 2D `_draw` had a FOURTH. The Sear trail's ring drew at about 41 against a
burn of 78 — **an 88% gap**, and the band of deck between them looked clear and
was not. Owner's decision, verbatim: *"For the fire hitbox, match the burn size.
Fix the picture to match the damage."* The picture moved and nothing else did:
`fire_pool_radius()` is the only place the number is written, `_field()` STAMPS
it so a caller cannot put a size into a pool the simulation will ignore, and the
decal is sized through `ring_span_for()` rather than by a multiplier — because
the ring's bright band peaks at 92% of its own half-size, so `burn * 2` would
have shipped the same bug one order smaller. `tools/pool_shot.gd` REFUSES to draw
a ring at `fire_pool_radius()`, since that photographs a number equalling itself;
it walks the captain to 48×20 spots and runs one real tick at each. Furthest
sample that burned 78.0, drawn line 78.0, **miss 0.0 units**. *(d)* **And every
model in the game was shinier than the lamp it stands under.** Against the
lamplit ceiling, **17 of 34 models were over on mean effective metallic and 0 are
now** — the owner picked it off the A/B pairs (*"Cutlass clamped looks better"*),
and the cutlass is the one in her hand every run: unclamped it was a black stick
where the clamped version is a steel blade with an edge highlight. The clamp
lowers the level rather than flattening the map, so the painted variation
survives. The agent went looking for a case where staying shiny wins — it chose
brass and two blades precisely because that is where such a case would live — and
**there wasn't one**; the honest range was "clearly better clamped" to "no
visible difference". **Then the deck's own boxes turned out never to have been in
the audit at all (SG-179):** `tools/lamplit.py` walks `assets/models/*.glb` and
nothing else, so the forty strake-capping boxes and the bow/stern end caps shipped
at metallic **0.40, above the 0.34 ceiling every model had just been brought
under** — literally shinier than everything standing on them, which is most of
why the owner called them placeholder. They are retinted, roughened and under the
ceiling, and the restatement in `view3d.gd` is held to its source by `deck · the
procedural deck obeys the same lamplit ceiling the models do`, which parses the
number out of `lamplit.py` and fails if the two drift. **It does NOT make them
textured, and the frames say so.**

**THE DECK EDGE IS PROTOTYPED HIS WAY AND IT IS WAITING ON HIS EYE (SG-180,
2026-08-04) — the switches default OFF and nothing is decided.** His own rail
module, reused at low profile in place of the flat brass capping, plus the
capping deleted outright shot as a third state. **The strongest frame on the
sheet is not the one the brief expected**: the brief ranked the strake capping
"the louder of the two", but at the STEM pose — the one his build-60 screenshot
is taken from — the capping is off both sides of the frame and the flat olive bar
across the middle is the BREAST RAIL, so the object he was actually looking at is
the one the brief ranked second. Restyled as 14 rail modules across the beam it
stops being a wall: the boundary line is unbroken strake to strake and **you see
the deck THROUGH it**, so DECK-IDENTITY §6's job is done better rather than
deleted. **The geometry was the risk and it resolved the good way for a reason
that is not luck**: the capping sits at `lift - 2.5` and the shipped rail stands
at `lift - 8`, the SAME BAND, so there is no "under" to put a second rail in — it
can only go outboard, which makes it a rail BESIDE a rail. What saves it from
reading as two rails stacked is the PITCH: at `div` 1 every post of the low run
stands directly under a post of the rail above and none falls between two. The
sweep is on the sheet and **it is the pitch, not the height, that decides** — div
2 reads busy, div 4 is under three pixels a post and has become a texture. Scale
and pitch are decoupled on purpose and both derive from `edge_rail_scale()` with
nothing typed. Sheets at `.shots/owner-review/5-deck-edge-rail/`.

**Builds 59, 60, 61 and 62 went to itch across the two days**, and build 60 is
the one the owner shot the deck-edge complaint from.

**ONE HARNESS CHECK WAS TESTING WHETHER THE OWNER HAD THE GAME OPEN (SG-181,
2026-08-04).** `audio · volume survives the session` wrote 0.42 into the
player's REAL `user://settings.cfg` and read it straight back — and the itch
build was running on this machine, rewriting that same file several times a
second, so the check reported the OTHER process's master volume and went red
about one run in six. Measured rather than reasoned: 200 save-then-read
iterations lost **53–79** of 200 on `user://settings.cfg` and **0 of 200** on
every other filename in the same directory, the write never became visible even
after 500 ms of polling, and the file's mtime advanced on its own with no Godot
of ours running. **`SkyGearAudio.store` is the SG-83 pointer**, diverted to a
scratch file before the first check and asserted byte-for-byte restored after
the last one. **The two lessons are bigger than the check.** A harness that
reads or writes real `user://` state is not testing the game, it is testing the
machine — and this one was also quietly writing the owner's volume down to 0.42
on every run. **The sweep for others found two more and one of them is
destroying data**: the harness wiped `user://runs.json` on every invocation
(his run log on this machine is five harness fixtures and is not recoverable)
and overwrote `user://keys.cfg` — **SG-182, FIXED 2026-08-04, and the sweep
that filed it was not exhaustive.** Both go through a `store` now, and so does
`user://workshop.json`, which that sweep recorded as CLEAN and which is not:
`_new_game` keeps the workshop in memory, but `_fittings()` §4 wrote a fixture
save to the real file twice and restored it from a string afterwards — his
scrip, sigils, fittings and berths riding on nothing raising in between. **All
five real `user://` files are diverted now** (`hud_layout.json`, `settings.cfg`,
`runs.json`, `keys.cfg`, `workshop.json`), **each with a named byte-compare guard
as the last thing the run does** — `editor · the harness never touches the
player's own saved layout`, `editor · and it never touches the player's own
settings either`, `editor · and it never wipes the player's own run history — the
SG-182 regression`, `editor · nor the keys he rebound`, and `editor · nor a byte
of what he has earned` — and the standard of proof is the tree rather than the
file: a recursive md5 manifest of the whole `user://` directory before and after
a harness run `diff`s empty. And the reason the collision was
constant rather than rare is a shipped bug of its own: the pause and settings
screens call `set_volume` from their DRAW, so either screen saves the config
file every frame (**SG-183**).

**THE OWNER HAS ONLY EVER PLAYED HEAT 1, AND THAT IS NOW A SETTING RATHER THAN A
RUN OF WINS (SG-160, 2026-08-03, owner: *"if you're able to just unlock it so I
can jump to any heat, that would be better for my testing"*).** SETTINGS →
**OPEN ALL HEATS** → ON, then pick any rung on the title. It persists in
`user://settings.cfg` beside fullscreen and the volumes, so it survives a
restart and works in the packaged Windows build; it is deliberately NOT in
`user://workshop.json`, which is why switching it on cannot touch a byte of what
has been earned. **The gate is not deleted and the ladder still climbs** — two
functions, not one: `heat_available` is the progression rule and never moves,
`heat_ceiling` is what the screen may OFFER. **THE DECISION, so it is not
ambiguous: a run played above the rung you have earned banks NOTHING** — no
scrip, no sigil, no fitting, no `best_heat`, and it does not count as the first
victory. Not partial credit: "the tree was bought at Heat 5" is not a sentence
this harness can reason about, and the ladder has to stay a thing other players
climb. **What voids a run is WHERE it was played, never which switches are set**
— a Heat 0 run with the bypass on banks in full, which is also what makes the
switch safe to leave on. It says so in three places (the settings caption, the
rung's own OPEN strip, the results sheet). Thirteen checks; the two that matter
are `heat · with the bypass off the ladder still climbs one rung at a time — the
SG-160 regression` and `heat · a run above the rung you have earned banks
nothing at all`. **And it found a fixture asserting the right answer for the
wrong reason:** the summit check banked a Heat 5 win onto a save with
`best_heat` 0 — a bypassed clear — and got its "no sigil" from that rather than
from §5's rule.
**THE TWO MELEE HEAVIES WERE MEAT SHIELDS AND ARE NOT ANY MORE — AND THE HONEST
HALF IS THAT MAKING THE COLOSSUS 21% MORE DANGEROUS MADE THE RUN 12.7 POINTS
EASIER (SG-165 + SG-166, 2026-08-03).** The furnace knight's `hp` is **360** — the
owner approved the doubling SG-156 measured the case for, and the cause was never
the hit path: 353 of 353 resolved swings land on a pinned captain. It was
LIFETIME. Measured before and after on `melee_probe`'s LETHAL arm, Heat 0, n=23
then n=47: he **lives 2.70 s → 5.79 s**, resolves **0.83 → 2.49 swings**, and
deals **26.6 → 84.6 damage — 27% → 85% of a captain's whole pool**, on
non-overlapping intervals. **The brief's "three swings" arithmetic did NOT hold
and it is 2.4**, because a 5.79 s life against a 1.90 s cycle starts and ends
mid-cycle; nothing else on his row moved, so his throughput against everything
that cannot dodge is 17.9 dps before and after. **And the COLOSSUS got the
owner's own design rather than a stat nudge:** `COLOSSUS_WALKS_THE_LANE` is **ON**
— *"have him ignore the player and keep heading towards the middle"* — and his
damage is a **STOMP**: an anchored 0.80 s telegraph resolving one circular hit at
240 (320 in beat 2) on a 4.2 s cadence, drawn as two hollow rings in SG-158's
oxblood/orange, hollow because a rim is the only part of a mark the body standing
in it cannot hide. That gate had shipped OFF because it took his damage to the
captain to a **structural zero**; the stomp does not go through the if/elif victim
chain, so **0.00 → 150.21**, and the zero is a harness check now, asserted from
both sides in one fixture. **THE FINDING THAT GENERALISES IS ABOUT VARIANCE.**
Four arms of ~~n=480 runs each~~ — **and BOTH halves of that sample claim were
corrected 2026-08-04 by SG-190.** *(a)* Those 480 are seeds multiplied by reps,
and on a deterministic rig reps buy nothing, so the honest n is the number of
distinct SEEDS in the arm and the intervals printed off 480 are roughly 4.5x too
narrow. *(b)* Worse, every four-arm number on that row was taken while
`move_and_slide()` was integrating the idle frame's wall clock, so **the
boarders in those arms walked at about a seventh of their table speed**. All
four arms were measured the same way, so their RANKING is probably intact and
the finding below is reported as a ranking; the ABSOLUTE figures are not
comparable to anything measured after the fix. At the
while the hold-rate ROSE 17 points, because the chase build's mean was carried by
a heavy tail of runs where he cornered a kiting captain, and **an anchored,
escapable circle has no tail at all — sd 70.3 → 36.9.** The shipped arm deals
**+21.2%** (95% CI of the difference +18.3..+34.2) and holds **78.5% [74.6–82.0]
against 65.8% [61.5–69.9]**: both sentences are true at once, and every future
telegraph design should expect it — **legibility does not only convert damage
into fairness, it deletes the outlier runs that were doing the killing.** Putting
the hold-rate back is one line and `docs/COLOSSUS-DESIGN.md` §1b has three
measured points to choose from. **What is still NOT true is the Boiler clock**:
with the gate on, Boiler HP lost in wave 12 went 11.08 → **6.00**, DOWN, because
he now spends 43% of his life planted — ~~§2's amended statistic has failed three
times~~ **FOUR times as of 2026-08-04, and that reading of WHY was half right:
he was also unable to touch the Boiler at all, because the stomp preempted the
swing that carried every victim but the captain. Re-measured with the Boiler
genuinely inside the circle it is 0.00, sd 0.00, over 181 wave-12 runs. The
statistic is retired at `docs/COLOSSUS-DESIGN.md` §2 and the lever is his
ARRIVAL, not his damage.** **And two measuring tools were broken
(SG-167, SG-168):** `melee_probe` read `game.wave` after `queue_free()`, and ONE
malformed row silenced THREE whole reports — the LETHAL arm, the only thing that
tool exists for, printed nothing at all in a run that exited 0; and
`_function_body()` splits on `"\n"` while every `.gd` here is CRLF, so **it has
been stopping at the first blank line of any function it reads**, with one
standing check auditing 38 lines of a 40-line function while printing a number
that made it look thorough.

**THE COLOSSUS DIED IN 9.7 SECONDS, AND THE DESIGN DOC'S EXPLANATION OF WHY HE
IS EASY WAS HALF WRONG (SG-146, 2026-08-03, owner: "still super easy... he also
just needs a lot more HP I think").** His `hp` is **2900** now, picked by
measurement: at 900 he was resolved in 9.7 s of a 19.4 s wave, which is five
swings of his 1.90 s cycle across a two-beat fight, so the half-health turn had
two and a half swings to escalate with. **The instrument had to be built first,
and building it found a live instance of failure mode one in the damage path**:
`damage_player` has taken a `source` string since it was written and NOTHING HAS
EVER READ IT — the parameter was spelled `_source` while `enemy.gd` passed the
boarder's `kind`. So "is it the Colossus, or the four gremlins standing next to
him?" was unanswerable from a total that had the answer in its argument list.
`tel.taken_by_source` reads it now, and `tools/boss_probe.gd` times the WAVE-12
SEGMENT rather than the whole run — because a whole-run mean is the wrong
instrument for one wave in twelve, which is what SG-119 paid for.
**COLOSSUS-DESIGN §1 said his swing "geometrically cannot land" on a moving
captain; at hp 900 he was already dealing 66% of all wave-12 damage**, because
his second-beat swing reaches 253 units and `tools/bot.gd` orbits at 210. He
cannot land on a captain who RETREATS and lands freely on one who ORBITS. **More
health did NOT buy a longer boring fight** — wave 12 got 24% longer while damage
taken in it rose 189%, so danger per second rose 157% — and the honest cost is
that the Heat 0 hold-rate fell from 100% to 66%. **The design's recommended root
fix was built, measured, and ships OFF** behind `COLOSSUS_WALKS_THE_LANE`: it
failed §2's own pre-committed statistic (Boiler HP lost 9.5 → 11.3 against a
required +40) and it takes his damage to the captain to a structural zero. §1a of
that doc is the whole measurement. **And two harness lessons were paid for: a
check that RAISES instead of failing takes the rest of its function's checks with
it, and a check that can only read a shipped default is vacuous — deleting the
line it guarded left the run green at 946/946 until the gate was made settable
per instance.**

**THE COLOSSUS'S HITBOX WAS A CIRCLE AND HIS TELEGRAPH WAS A WEDGE, AND THE
HARNESS HAD A CHECK PINNING IT THAT WAY (SG-119, 2026-08-03).** He was the only
melee row carrying no `reach` and no `swing`, so `_swing_hits` returned true
unconditionally — a **360° circle at 163** — while `view3d.gd` drew him a **120°
fan at 146** out of a fallback constant the simulation had never heard of.
Stepping behind the Colossus, the thing his own telegraph invites, had never
once worked. He carries the two fields now, **both carve-out branches are
deleted** so no enemy can take a reach-less path, and the wedge is ONE function
(`enemy.swing_wedge_reach/arc()`) that the renderer calls rather than
re-deriving. **His swing lands at exactly the same distance it always did** —
146 is precisely the `attack_range + 26` both fallbacks computed, so 163 to the
captain and 253 on the second beat, before and after; the ARC is the whole
change, and his damage, health, windup and recover are harness-pinned untouched.
**This makes him easier and nothing was compensated**, on purpose: his
difficulty is `docs/COLOSSUS-DESIGN.md`'s open question and a shape fix is not
the place to answer it. **The ugly part is that the harness was asserting the
bug**: `telegraph · a boarder that draws no wedge keeps its circle` passed every
run for weeks under a comment claiming he "telegraphs with a phase ring rather
than a fan" — a renderer that did not exist. That check is INVERTED, in place,
so the diff shows the assertion changing sides. The measurement that matters is
geometric and cannot be satisfied by a mismatched shape: sweep the connect test
over a full circle and the share that lands must equal the arc that is drawn —
**BOSS 0.335 against a drawn 0.333**, where it read 1.000 before.

**And two smaller ones that were both about a number nobody had measured.**
`visual_rng` was never seeded anywhere in the repo (SG-120) while
`set_seed_text` promised in its own comment that a seed reproduces a run — which
was cosmetic right up until the POWDER STORE talent placed real explosive kegs
from that stream, so two players on one seed got different decks. It is seeded
beside `rng` under its own salt now, consuming nothing from it. And a fire
pool's tick period was reset by ASSIGNMENT rather than carried (SG-122), so the
overshoot was discarded and the true period was `ceil(0.25 / delta) * delta`.
**The board row called that "harmless at 60 fps" and it was not**: 1/60 does not
divide 0.25 in binary floating point either, so the pool has been delivering
**11.4 dps against its authored 12.0 in every build that ever shipped** — which
also means SG-117's recorded "the authored 12 dps" was 11.4, and that row is
annotated rather than left standing. It is 12.0 at 1/60, 0.05 and 0.1 now.
**The same discard pattern is in three more places and is deliberately NOT
fixed here** — the steam taps and the player's aura and pulse passives, filed as
**SG-126**, because those are player-damage rates and want their own before and
after rather than a fourth change in one commit.

**THE SAFEST PLACE ON THE DECK WAS INSIDE THE FIRE, AND THE RIG THAT SHOULD
HAVE CAUGHT IT WAS MEASURING A CAPTAIN WHO NEVER MOVED (SG-117 + SG-118,
2026-08-03).** `invulnerability_left` is ONE global variable and a fire tick set
it to 0.55 s four times a second, so a captain standing in a pool was immune to
*everything* — a boarder's 26-damage swing included — while the pool itself
landed one tick in three. Measured directly, a captain being swung at every
1.5 s for a minute took **700 damage standing IN the fire against 1014 standing
CLEAR of it**: the hazard was a 31% damage shield. It is a `grants_invuln` flag
threaded `damage_player` → `take_damage`, default TRUE so every discrete hit is
byte-for-byte unchanged, FALSE from the tick — and the sweep for other periodic
sources was RUN rather than assumed: there is exactly one, because enemy burn
stacks drain the enemy and the steam taps' half-second accumulator calls
`_damage_circle`, which never iterates the captain. In fire now costs 1440.
Five `hazard ·` checks, the pre-committed one being `hazard · a fire tick never
buys immunity to a swing`.

**And the second half is the fifth failure mode again, one level deeper than it
has been found before.** `tools/balance.gd` — the source of every simulated-run
verdict in these docs — carried a comment saying its bot *"keeps moving"* beside
a loop that issued **no movement input at all**. It moves now, and its policy is
a file of its own (`tools/bot.gd`) that the harness drives directly, because a
policy buried in a loop is a policy nobody can test: it holds the captain's own
210-unit gauge band, strafes inside it, leaves a fire pool it is standing in
(but does not route around one it is clear of — a bot that dodged fire perfectly
would have made SG-117 look free), and dashes only to break contact, because
dash grants i-frames and a bot dashing on cooldown carries a background immunity
that flatters exactly what SG-117 measures. Two more things were ticking behind
the rig's back and are fixed: the engine was stepping the **captain** on real
frames (`set_process(false)` on the game never reached her — she is her own
node), and nothing had ever disabled the **props**, so a lit keg's 0.45 s fuse
burned on wall-clock time and a keg is 26 damage. **A moving captain is a
different game**: Heat 0, ~~n=120~~ — damage taken **34.6 → 241**, runs held
**38% → 92%**, close-range time **3–5% → ~22%**. **The SAMPLE was corrected
2026-08-04 (SG-190): that "n=120" is SIX SEEDS at twenty reps, so it is n=6 on
the axis that carries the variance you care about** — the reps differed only by
how busy the machine was, because the rig was integrating against the wall
clock. The DIRECTION here is not in doubt (a 7x change in damage taken is not a
sampling artifact at any n) but the intervals printed off that 120 are roughly
4.5x too narrow, and the same correction applies to every "n=120" in this file. Every balance number in these
docs predating this is a number about a stationary captain, and **SG-57's
held-rate observation — the one waiting on the owner's threshold — has flipped
sign and is no longer significant**; its own row had wondered aloud whether it
was "a bot fact", and it was.

~~**The rig is STILL not deterministic, and it now says so where it used to claim
otherwise.** The residual is below the scene tree — `move_and_slide()` queries a
physics space the server syncs on its own tick — so the header states plainly
that this tool reports a DISTRIBUTION and that **its floor is not zero: 8% on
damage-taken between two n=120 batches of identical code.**~~ **SUPERSEDED
TWICE — 2026-08-04.** Both halves of that paragraph are now known to be wrong,
and it is kept because the reasoning it encodes is the reasoning to stop
repeating. **The 8% was never a floor (SG-128):** it was sampling error at
n=120 read as a property of the instrument, and a floor does not shrink when you
run more runs. **And the residual was never the physics server (SG-190):**
`move_and_slide()` takes `get_process_delta_time()` — the idle frame's
WALL-CLOCK duration — whenever it is called outside a physics frame, which every
`call_deferred` rig was. Stepped inside a physics frame the rigs are
**bit-identical across separate processes**, so the "distribution" this header
described was the machine's load, and the paragraph blamed a subsystem it had
never measured. What survives is the *practice*: SG-117's run-level result
(−10%) was reported to the owner as *below the rig's resolution* rather than as
a finding — conservative, and by SG-128's later arithmetic it had actually
cleared its bar (t=2.43, p=0.015) — and the fix's real evidence is the direct
probe either way. Three `bot ·` checks; the one that matters is `bot · the
bot actually moves the captain — the SG-118 regression`.

**THE SHIP HAS A BOW ON IT NOW, AND THE STERN IS A REFUSAL WITH A ZERO IN IT
(SG-174, 2026-08-03).** The owner remade both pieces after SG-157 refused the
first pair (*"Bow and Stern look horrible here"*). `prow_ram` is **placed**, and
the placement is arithmetic rather than a coordinate: the free variable is where
the piece ENDS and its scale is derived from `hull_beam()` there, so its two aft
corners land on the strake lines by construction and there is no setting that
leaves the gap the old bow read as. It changes **9.1% of the frame** and does not
touch her. **`stern_counter_v2` is CUT, and the interesting half is that the
model is not the problem**: its seating — the exact thing SG-157 refused the
first stern for — is fixed by construction, and seated correctly the A/B pair
differs on **0.000% of its pixels, maximum single-channel delta 1**. Raising it
until it can be seen puts it between the lens and the captain, with frames.
**Two hand-made sterns of completely different proportion have now failed
identically, because this camera never sees the outside of the hull** — it sits
460 astern of a focus clamped at 1360 and looks DOWN at 41 degrees, so a transom
is either behind the deck it closes or below the bottom of the frame. **And the
delivery note was wrong about one heading**: Meshy normalises to 1.9 on the
longest axis, so "both are 1.9 wide" is not a statement about the ship — the
stern's mirror plane says 189 of it runs FORE-AND-AFT and only 90 goes across.
Four `edge ·` checks; the sheets are `.shots/owner-review/2-bow-stern-redo/`.

**AND THERE IS AN UPPER DECK OVER THE BOW (SG-178, 2026-08-03).** Alex asked for
*"an upper level that you can see from the deck but you don't actually go on
to"*, SG-176 measured which of it the camera can see and wrote the four-piece
brief, and he made all four: a platform bay, a support post, a staircase and a
corner post, ingested at budget with **no decimation at all** — he generates at
~3,000 now and `deck_trim.py` passes anything within 85% of budget straight
through, so trimming would only have cost UV accuracy. **The whole placement is
one derivation.** The platform's floor is **two of the SHIPPED rail's own
heights**, read off `edge_rail_scale()` and not typed, because the stair was
built to climb exactly that; the stair's scale follows from its own measured
TREADS rather than from its handrail-high bounding box; and **the platform's aft
edge is one stair-run forward of the bow line**, which is the only seat that
satisfies all three of the constraints that were in tension — a stair under the
platform cannot be found in the frame (SG-176), nothing may stand in the
rectangle she walks, and the stair's run is the model's own. Its beam is the
hull's beam where it seats, so the outer bays end on the strake lines and no post
stands in open air. **It is SET DRESSING**: sixteen instanced pieces, no
collision node anywhere, nothing in the play rectangle. **The frame share is
21.72% at the stem and 0.00% from mid-deck at the shipped zoom** — the second
number is forced rather than a failure, because SG-176's lattice found that
nothing forward of the bow line reads from there at all, and the only way to buy
it back is to stand in the rectangle. Four `edge ·` checks; the sheets are
`.shots/owner-review/3-upper-deck/`.

**THE MODELS CAN BE LIT NOW, AND THE LIGHTS ARE DATA (SG-81, owner ask:
"the models don't have baked lighting").** `assets/models/lights.json` is a
per-MODEL-KEY table — omni or spot, colour, strength, reach, falloff, offset in
ground units, a spot's cone and aim, an optional pulse or flicker — read by
`scripts/view3d.gd` at launch and worn by EVERY live instance of that model.
**The lab writes it**: `SkyGear Tools.bat lab`, the new **LIGHTS** mode, add a
light, dial every field on the SG-39 typed widget, see it on the real mesh with
a gizmo showing where it is and how far it reaches, DARK ROOM to kill the lab's
own lamps, SAVE. Not the clipboard — the renderer got the reader first. **Model
lights are ACCENTS and the budget is arithmetic:** every row is clamped to 2.0
energy over 460 ground units as it is read, at most 8 are live, and their summed
energy cannot pass 7.5 — which is the 7.39 the deck already carried, so the
table moves light around rather than adding it (a 40-row flood lights 3).
Figures are admitted before scenery, because a brazier that loses its light
keeps its painted floor pool and a boarder has nothing. Five seeded: the
brazier, the lantern post, the steam vent (a spot, up out of the grate), the
Boiler, and the furnace knight — whose chest light is SG-86's named candidate
and measurably lifts him (30.4 → 33.4 mean luminance, 10 → 276 hot pixels).
`.shots/sg81/` is the witness.

**AND THE FX DIALS HAVE A HOME TOO (SG-17), on exactly that pattern and with
the reader written first.** `assets/models/fx.json` carries the three FX dials
that are genuinely RENDERER constants — the bloom over emissives, a scale on the
impact particles' bodies, and how long one of them lives — read by
`scripts/view3d.gd` at launch, clamped as they are read, with per-KEY fallback
so a half-typed file costs you the dial you were half-typing. The lab's SAVE
writes it. **The other six dials go on going to the clipboard, and that is the
honest half:** `radius`, `arc`, `life` and `damage` are arguments the SIMULATION
picks per shape at the moment it fires, so their home is the `_fx({...})` call in
`game.gd`; `period` and `slowmo` are the lab's own controls and do not exist in a
run. **Two of the three were moving nothing at all before this** — GLOW wrote a
property this renderer has never set, and SPARK wrote `mesh.size` on a `QuadMesh`
that SG-63 replaced with real prisms and spheres, so it has been dialling a null
cast for weeks. A reader for dials that reach nothing would have been the failure
wearing the fix's clothes; `view · every dial in the fx table is read by the
renderer` and `view · and the renderer on screen is built out of those dials, not
out of literals beside them` are the two checks that say it is not.

**The deck's railings are geometry (SG-72), and the cargo hatches are NOT, on
purpose.** The railing won its second roll — v1 arrived standing on a solid
timber board, because the prompt asked for "base flanges" while the shared frame
refused a plinth, and on the deck it read as a bench lying at the rail. The
hatch was generated three times and REJECTED: it lies flat IN the planking, so at
the locked 41-degree camera nearly all of it that reaches the player is its own
top face, which is a texture either way — the rope coil's standing verdict, one
size up. All three verdicts are written where the prompts wait, in
`tools/meshy.py` and `tools/static_model.gd`.

**One trap, found the hard way:** `tools/static_model.gd` rebuilds the `.tscn`
for EVERY key in its table, including the RIGGED figures — so running it to wrap
one new static prop overwrote `scrapper.tscn` and its neighbours with dumb
static holders and took the harness to 725/729. It is silent. Revert the `.tscn`
files you did not mean to touch before you believe a green run.

**THE MENU IS HARDWARE NOW, NOT FOURTEEN HAIRLINE RECTANGLES (SG-91, owner ask:
"the header UI element feels on-theme but the rest are just simple text
boxes").** He was right, and the survey found the reason: the SKYGEAR banner is
painted brass carrying material, a bevel, corner ironwork and weight, while
every control under it was `SkyGearUI.button` — **two shape calls**, a flat tint
and a hairline, with its whole state carried by swapping two colours. The title
is a **board** now: a riveted iron bulkhead the plates are bolted to, each plate
a solid body with a bevel, four rivets and an **engraved channel** its label
stands in; the lit state is a LAMP rather than a tint (a wash down the plate, a
deepened shadow so it reads raised, rivets catching light on the fire fields'
own flicker clock); BEGIN RUN is **the door** — taller, teal, wearing the
banner's own corner brackets, never dark; QUIT is a small iron **hatch** off the
foot of the board; and the Heat chips are **rungs bolted across a rail**, with
the chosen one SEATED rather than merely tinted. **The flicker cannot reach a
glyph, mechanically**: the engraved channel is drawn opaque over every lit layer
beneath it, which is what keeps the legibility pass — it renders each screen
twice and samples the second — from measuring noise. `docs/MENU-DESIGN.md` is
the survey, the vocabulary and the ordered plan; the other screens are SG-93 and
are deliberately waiting on the owner's look. **Nine `menu ·` checks**, the text
audit clean at all four widths (and the pass turned a detector ON — nothing on
the title was inside any frame before, so containment had no opinion about the
menu at all). It also found and fixed a real bug: a `bare` widget drew at the
rect from BEFORE the F4 adjustment, so a nudged Heat rung moved its click target
and left its painted rung behind (`menu · a nudged Heat rung takes its own art
with it`). `.shots/sg91/` is the witness.

**F4 RESIZES NOW (SG-80, owner ask): a selected element has a size as well as
a position** — drag a grip, type into the w×h readout, or hold Ctrl and use the
arrows. It saves as a SIZE DELTA from the size the drawing code chose, beside
the offset in the same entry (`{"o":[dx,dy],"s":[dw,dh]}`); an entry with no
size stays the bare pair it has always been, so old layout files load and save
unchanged. Narrowing a box past its own words is allowed and the live verdict
says so the same frame; a box narrower than one `MIN_PT` glyph is refused.
**And Ctrl+S was genuinely broken (SG-83) — but not where anyone would look:**
the harness deleted `user://hud_layout.json` six times a run and wrote fixtures
over it, so a hand-alignment pass saved correctly and was wiped by the next
`SkyGear Tools.bat harness`. Test runs go to a scratch file now and the last
check of every run proves the player's own file is byte-identical; the editor
also says `SAVED ·` with the real path, or shouts if a write fails.

**AND THE LAST OF THE "2D READS" ARE GONE (SG-63, 2026-08-02).** He named three
things; two were VFX and both are geometry now. **The impact and explosion
particles have bodies** — every one of them was a flat card swung to face the
camera, so a steam plume was one painted cloud sprite stacked forty times. A
spark is a prism lying along its own velocity; a puff is a LIT low-poly sphere
that tumbles, so the deck's lamps travel across it as it rises. **And the
`burst` — every kill, every powder keg, the hulk coming apart — had nothing in
the air at all**: VFX-PLAN §3/§4 gave every other shape geometry in July and
this one was skipped, so a thing coming apart drew a painted cartoon star flat
on the planking. It is a shock ring, a dome of shell rings and a throw of real
debris now. **The SG-78 flooded-disc trap turned out to be under five more
effects** — the Pulse ring, the fire fields, the Colossus turn ring, the
Boilerwright's vent stand, and the aura edge a card WIDENS — because they all
drew through `rune_player.png`, which measures alpha-255 across its whole disc.
Every ring in the game draws through the generated rim now, and a harness check
keeps the two measurably-opaque plates out of the decal path for good.
**The cape was rebuilt and is STILL OFF**: it is a 3x6 lattice of eighteen bones
with blended weights, real folded normals, a garment's cut and a twill instead
of the deck-planking painter, and against SG-82's flat red signboard it is
plainly cloth (`.shots/sg63/cape-before-after.png`). What that proves is that
the GEOMETRY is no longer the reason it looked wrong; whether he wants a cape at
all is his call, and turning it on is still one commented line.

**Three corrections off the owner's 2026-08-02 screenshot are in** (SG-78/79/82).
The aim indicator lost its range ring: the small landing reticle, clamped at the
skill's reach and dimming past it, is now the whole feature — the ring drew as a
flooded opaque disc because it went through the painted `rune_player.png` plate,
which is a FILLED disc, so DESIGN §13e's premultiplied emission map lit the whole
projection box. The captain's cape is OFF by default and `HERO_CLOAKS` is empty
(two verdicts: "looks horrible", "atrocious") — the cloak code stays in the build
under harness for the SG-63 rebuild, and the SG-82 board row records exactly why
it read as a plank. And the prop ruler now measures what the CAMERA sees rather
than the model's AABB: a billboard is camera-facing and has no depth, so scaling a
solid to `PROP_HEIGHT` handed a squat deep prop up to 2.07x the screen height of
the painting it replaced. All ten wired prop rows are pinned within ±10% of intent.

**Alignment is FIXED in the game now, not filed from screenshots** (SG-42, the
owner's ask): press **F4 on the screen that is wrong** — any screen — and move
the thing itself: panels, and the elements INSIDE them (labels, readouts,
buttons, a card's emblem), by drag, arrow-nudge or typed offset, with the text
audit's own detectors as the live verdict. **And you no longer have to BE on
the screen** (SG-44, round two of the same ask): **P** inside the editor poses
any of the audit's screens on a sandbox — edit GAMEOVER without dying, the
results without winning — and Esc hands the game back exactly, mid-run
included (`editor · and leaving the pose hands the run back exactly`).
`docs/HUD-LAYOUT.md` is the how-to.

**The four tools you will reach for**, all behind `SkyGear Tools.bat`:
`harness` (1128 checks), `text` (the audit), `screens` (the BATCH-evidence mode:
photograph all 25 screens at all 4 widths as one page — for auditing everything
at once; fixing is F4), and `layout` (promote the F4 alignment — plates, items
and per-screen element offsets — out of `user://` and into the repo, which is
the step that makes a hand-alignment pass real).

---

## Three things to read before touching anything

**1. `docs/OUTSTANDING.md` is the ledger.** Only things the owner asked for,
never things anyone thought of. An item leaves it when it is done or when it is
dropped WITH A REASON -- not when it is partly done. `SkyGear Tools.bat todo`
prints the open half. The file exists because the skybox was reported twice and
slipped twice -- and then a third time, which is when it was measured instead of
guessed at and finally built.

**2. Run the tools before believing anything.** `SkyGear Tools.bat` lists them,
`all` runs every checker. Nearly every real bug found lately was found by a
tool, and several were things a confident commit message had already declared
fine.

**3. The seven recurring failure modes.** Each has happened more than once.
Assume you are about to commit one:

- **Data with no reader.** A table field nothing consumes, so a feature reads as
  done and does nothing. FIVE times. Two harness guards exist now
  (`shop - every talent field is read by something` and the article twin);
  extend them rather than trusting yourself.
- **Two functions disagreeing about one number.** Three visual bugs came from
  this. `SkyGearHUD.rail()` and `scripts/ink.gd` exist because of it.
- **A detector silenced to make a screen pass.** The harness once reported
  192/192 while skipping a quarter of itself. The text audit exempted every
  widget label and called 16 screens clean while 30 were broken.
- **Claims asserted from memory rather than measured.** "The camera was ported
  exactly" was said repeatedly and is false.
- **A measuring rig nobody measured — the newest one, and it cost the most.**
  FOUR times a tool has taken two photographs of "the same frozen scene", called
  the difference a result, and been wrong, because something in the scene was
  still moving: the brazier phase, then the renderer's own tick, then the GPU's
  particle clock, then — the largest — **every rigged figure's `AnimationPlayer`,
  which runs on the engine's clock and ignores both `set_process(false)` calls
  (SG-108).** Each was found by a different tool, fixed inside that tool alone,
  and rediscovered by the next one. Eight A/B answers were published against
  those floors and **three of them turned out to be the floor**, including the
  one that drove a shipped tuning change. There is one freeze now, `tools/still.gd`,
  and the rule that follows from all four: **a tool that reports a difference
  must first report its own noise floor, and that floor must be exactly zero** —
  not small, zero. A floor allowed to be 3% is a floor that can hide a 3%
  feature. `SkyGear Tools.bat still` is that assertion; the five `still ·` checks
  in the harness are what stop the next tool from skipping it.

- **A fact known in one place and contradicted in another — the newest, and the
  one that made the fifth so expensive.** On 2026-08-02 the SG-97 row wrote down
  *"balance.gd's bot never moves the captain"* and reasoned correctly from it,
  refusing to let its own numbers stand as a verdict. It did everything right.
  The fact then reached nothing else: the rig's own comment went on claiming the
  bot "keeps moving"; SG-57 wondered aloud whether its result was "a bot fact"
  without checking; SG-48 CUT a feature on a statistic the fact invalidates;
  SG-70 filed as an open mystery the very gap the fact explains; and a day later
  SG-118 rediscovered it from scratch. **The repository knew.** When you learn
  something that invalidates a measurement, the row you are working on is the
  LAST place it belongs — fix the tool's comment, and name the rows that
  depended on it. SG-125 is the audit that should not have been necessary.

  **And the cheapest possible version of it, SG-188, 2026-08-04: a comment that
  described the fix and sat six lines from the bug.** `view3d.gd` warns beside
  the Colossus's turn that *"a window that shrinks every frame is a one-shot
  that accelerates as it plays"*, and `enemy.gd` says the same thing twice more
  at `ARRIVAL_TIME` and `TURN_TIME`. The ATTACK was the one caller still handing
  `rig3d.want()` a countdown, so the furnace knight's swing accelerated into the
  4.00x clamp twice per attack and was dealt **2.50 times per single hit**. The
  comment beside the crossing even asserted the fix was already in place —
  *"`want` re-reads the window only on the frame the state changes"* — which was
  true of the CLIP and false of the RATE. **A rule written down three times and
  applied twice is not a rule; grep for the callers rather than trusting the
  paragraph.** The tool that existed to catch it, `anim_timing`, sampled the
  first frame of the moving window and reported 3.93x for a thing that ran at
  4.00x, which is why it took a playtest to find.
- **A harness check that asserts the bug.** Distinct from silencing a detector:
  here the detector is loud, green, and wrong. `telegraph · a boarder that draws
  no wedge keeps its circle` passed every run for weeks while pinning the exact
  defect SG-119 fixed, under a comment describing a phase ring this renderer has
  never drawn. Beside it, a roster check looped a hand-typed list of three names
  — and the one melee row missing from that list was the only row that could
  have failed it. A check written from the same misunderstanding as the code
  does not test the code. Prefer checks that read the table.

**AND THE ONE SENTENCE TO MEET BEFORE YOU TYPE "NO SIGNIFICANT DIFFERENCE" IN A
BOARD ROW (SG-128).** `tools/balance.gd` **can see about a third of a change and
cannot see a twentieth of one at any price.** On its own measured spread a 30%
difference costs 23 runs per arm, 10% costs 200, and 1% costs about twenty
thousand — 61 hours. So a small sample that comes back "no difference" is not
evidence of no effect; it is an instrument that could not have seen one, which is
the mistake SG-125 exists to catch. **The old rule this replaces — "the rig's
floor is 8%, disbelieve anything under it" — was wrong, and wrong in BOTH
directions:** the 8% was sampling error at n=120 mistaken for a property of the
instrument, so it shrinks with n rather than standing as a wall; quoted at n=120
it was roughly right by accident, and quoted at n=30 (SG-126) the real bar is
~26% and the gate was three times too permissive. There is no constant now. The
rig prints what THIS sample can resolve, and what the effect you care about would
cost, under every result. `n=6` — the default before SG-118 added `reps` — is
worth +-40 points on a held-count and is not a measurement at all.

---

## The code

| | |
|---|---|
| `scripts/game.gd` | the simulation: waves, damage, draft, classes, deckwork |
| `scripts/game_data.gd` | every table: shapes, elements, enemies, waves, events, classes |
| `scripts/view3d.gd` | the renderer; mirrors the hidden 2D sim into 3D |
| `scripts/hud.gd` | every screen. All text goes through `_say` / `_says` |
| `scripts/ink.gd` | one source of truth for point size, outline, contrast floors |
| `scripts/ui.gd` | the widget layer: immediate mode, retained focus |
| `scripts/cards.gd` | 41 draft cards. `preview()` runs a card on a sandbox copy |
| `scripts/workshop.gd` | persistent progression, gated behind a first victory |
| `scripts/deckwork.gd` | a verb table for acting on the deck. One live verb: repair (held); the crate shove/winch family is TABLED behind one flag (SG-68, owner: "boring") |
| `scripts/coach.gd` | one hint at a time, and mostly silence |
| `scripts/sky.gdshader` | the browser's painted sky, sampled by view direction |
| `tests/parity_test.gd` | 1128 checks; the closest thing to a specification |

A hidden 2D scene runs the simulation and `view3d.gd` mirrors it into 3D at
`WORLD_SCALE = 0.01`. The camera is the browser's `CAM.recompute()` solve locked
at 41 degrees -- and as of 2026-08-01 that is MEASURED, not asserted:
`tools/cam_measure.gd` projects known deck lengths through both builds' math
and they agree to the pixel (ratio 1.000). The earlier "framing tighter than
the browser, unexplained" impression was an artifact of a broken browser-side
render at a mismatched resolution. Three other systems are calibrated against
that solve; the real residual it was blamed for was the Boiler prop mesh,
since rescaled to the browser's boilerH 150 and pinned by its own check
(SG-27).

**One consequence of that solve is worth knowing before you judge any
screenshot.** At 41 degrees with a 36 degree vertical field, the top of the
frame looks 23 degrees BELOW horizontal, so the horizon is off the top of the
picture at every zoom and mid-deck shots contain no sky at all. That is why the
skybox was reported three times and missed three times. `SkyGear Tools.bat sky`
poses the four places sky is actually visible; judge it from those.

---

## The tools

`SkyGear Tools.bat <name>`, or `godot --path . --script tools/hub.gd -- <name>`.

| | |
|---|---|
| `harness` | 1128 checks. Green before anything ships |
| `text` | every string on 25 screens x 4 sizes: containment, overlap, overprint, drift, contrast |
| `parity` | browser against Godot, same seed and tick count, stitched |
| `sky` | the sky, from the four places on the deck it is actually visible |
| `lab` | any model: triangles, height in ground units, bones; mounts weapons |
| `balance` `timing` `motion` `model` | simulated runs; clip-vs-skill; root drift; rigs |
| `todo` | the open half of OUTSTANDING |
| `all` | every checker in sequence, one verdict |

**A third party works in this repo.** Codex runs side experiments on its own
branches (e.g. `codex/browser-2d-godot-parity`, an isolated browser 2D
project). Leave them alone — they are the owner's, they are not the port, and
they do not reopen the retired parity goal. But CHECK `git branch
--show-current` is `main` before you work: a Codex branch checked out over
the shared tree once made every agent read its own committed work as a mess.

**A THIRD GOTCHA, AND IT IS ABOUT COMMITTING RATHER THAN BUILDING (found the
hard way 2026-08-03).** Everyone follows the rule *commit with explicit
pathspecs, never* `git add -A`. **That is not enough when two agents are live in
one tree, because the unit git stages is the FILE, not your hunks.** SG-117/118
touched `tests/parity_test.gd`; another agent had in-progress SG-116 work sitting
uncommitted in the same file, and `git add tests/parity_test.gd` took all of it —
including a check referencing a constant that existed only in their unstaged
`tools/rune_read.gd`. The commit looked fine and the harness passed **in the
working tree**; a freshly extracted worktree of that HEAD would not PARSE. So the
clean-worktree verification is not a formality that confirms what you already
know — it is the only thing that catches this, and it caught it. If you share a
file with a live agent, diff your commit against its parent for that file before
you believe it, and rebuild the file from the parent plus your own additions if
it carries someone else's.

**Two build gotchas.** The Windows export template lives in a GITIGNORED
`skygear-godot/.templates/`, so a fresh clone cannot build. And when agents are
working, build from a clean `git worktree` of HEAD or you ship a half-written
file — **and that goes for the screenshot tools too**: `screens`/`text`/
`parity` run against the live tree, and a mid-edit `hud.gd` renders a deck
with no UI (bitten 2026-08-01, three times in one day). When agents are
active, run visual tools from a worktree of HEAD or wait for the next
verified push.

---

## Designed, not built

- `docs/SHIP-AND-MAPS-DESIGN.md` -- maps, run diversity, ship progression,
  between-run downtime. The Colossus wreck fitting was placed 2026-08-01
  (SG-15); the stowage spine was built and then CUT by its own §7.1 kill-test
  (SG-48); §5's fittings + berths + berth screen were BUILT 2026-08-02 under
  the owner's between-runs reframe (SG-56). Still unbuilt: §6's walkable
  downtime, gated behind the refit by its own rule.
- `docs/AUDIT-2026-07-31.md` -- an independent audit. Its top three findings are
  fixed; its documentation recommendations are not (board SG-11).
- `VFX-PLAN.md` §6, the blade-driven weapon trail (SG-18). The two remaining
  Articles — The Opening Bid and The Second Hand — were BUILT 2026-08-01
  (SG-26), each with its trade live in the sim. Heat 3-5 were built 2026-08-01; §5's chromatic/radial half was
  DROPPED by the owner the same day (recorded at the section).

## Generated assets

Meshy, via `tools/meshy.py`. **The key must never reach a committed file** --
read from `MESHY_API_KEY` or the gitignored `tools/.meshy_key`, and run
`git grep "msy_"` before committing.

**Character models — the owner's standing rules (2026-08-01).** These exist
because every character we generate will eventually be rigged and animated
(the Boilerwright, then enemies), and a model that fails them is credits spent
on an asset the animation pipeline cannot use:

- **Clean T-pose or A-pose only.** Prompt for it, and reject a generation that
  comes back posed — retargeting needs a neutral rest pose to work from.
- **No over-accessorizing.** Dangling pouches, straps, horns and ornaments
  become part of the skinned mesh and deform strangely under animation. Keep
  the silhouette clean; character identity can ride on texture and proportion.
- **Weapons are separate models**, mounted via `BoneAttachment3D` — the
  cutlass is the pattern (`assets/models/weapons.json`, fitted in the lab).
  Never prompt a character holding their weapon.
- **Capes, cloaks and loose cloth are separate too.** The captain's cape was
  removed from her model for exactly this reason; cloth gets added back as its
  own layer, never baked into the character mesh. **The payoff shipped
  2026-08-02 (board SG-23):** her cape is a four-bone chain (`scripts/cloak.gd`)
  on a chest mount — trails at a run, cracks on the dash, bitwise-still at
  rest when sway is off (`cloak ·` checks, seven of them; `.shots/cloak/`).
  Per-class rows in `view3d.HERO_CLOAKS`; the Boilerwright opts in with one
  row when his day comes.

**The Boilerwright moves on HIS OWN clips now (board SG-74, 2026-08-02).** The
owner ran his mesh through Mixamo and delivered the Great Sword Pack — his
native rig plus 51 clips — and the whole thing ingested as one `models.json`
entry through `tools/ingest_model.py` (the §13l axe-pack path, second use).
Five heavy slashes rotate as his attacks, and Tap Main plays a real kneel
(`figure · tapping a main plays the plant, and the kneel fits the tap window
like a swing fits its cast`); the borrowed captain-clip retarget is retired.
`.shots/clips/boilerwright.gif` is the witness.

**And the FURNACE KNIGHT is a mesh, on the owner's own rig (board SG-85,
2026-08-02) — the second rigged boarder, and the first figure in this game that
DIES on screen.** Same shape as SG-74 (his Emberforge Sentinel through Mixamo:
a native rig plus 51 clips, one `models.json` entry, one ingest run), which
closes SG-22 and empties the `handoff-3d/` queue. He stands 216 ground units —
the SIM's own number for the archetype, a head over the captain — and he WALKS,
because he is the first boarder slow enough to need one: the run cycle rated at
75 units a second fell under the playback floor and skated, so `gait()` picks
the cycle by ground speed and `AUTHORED_WALK_SPEED` rates a walk against a
walk. Death is presentation only: the simulation kills, pays out and frees the
enemy exactly as before, and the RENDERER keeps the body 1.6 s to play `die`
before it sinks (`figure · and the body does not start leaving until the death
has been played`). His furnace chest is the first emission map this pipeline
has ever read — and the honest note beside it is SG-86: on the deck he is about
a quarter darker than the painting he replaces, and his hands are empty where
the sprite carries an axe. `.shots/clips/knight.gif` against
`knight-before.gif` is the witness.

`prune` strips the 77 MB an asset arrives as down to the ~10 MB GLB actually
used, and refuses to run before the first import because extract-mode textures
leave a scene with no meshes and no error. The remesh pass took the props from
182 MB to 9 MB (the captain deliberately excluded — board SG-13); the itch zip
is 94.5 MB.
