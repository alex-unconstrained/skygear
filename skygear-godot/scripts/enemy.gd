class_name SkyGearEnemy
extends CharacterBody2D

var game: Node
var kind := "SCRAPPER"
## HOW HARD THIS IS TO SHOVE. Was a local inside `take_damage`, so knockback knew
## about it and nothing else could — Keel Hauling read `enemy.mass`, got a null,
## and towed a Colossus at the same rate as a gremlin.
var mass := 1.0
var lane := 1
var config: Dictionary
var hp := 1.0
var max_hp := 1.0
var radius := 22.0
var state := "climb"

## HOW LONG THE ARRIVAL LASTS, and it is named for the same reason `TURN_TIME`
## is. It was a bare `0.8` on the line below — fine while nothing outside the
## simulation needed to know how long a boarder takes to get aboard, and
## something does now: `view3d.gd` closes the landing ring over exactly this
## window, and reading `state_time` itself would not do, because it counts DOWN
## and a window that shrinks every frame is a ring that accelerates as it
## closes. Same number, named once, so 0.8 never becomes a literal two files
## each own (STATUS failure mode two; board SG-85 is what happens when it does).
const ARRIVAL_TIME := 0.8
var state_time := ARRIVAL_TIME
var attack_direction := Vector2.DOWN
var dead := false
## HOW HARD A SHOVE CAN EVER BE.
##
## `knock_velocity` ACCUMULATED with nothing bounding it, and decays at only
## 1050 a second — so any skill that hits more than once before that decay runs
## out stacks shove on top of shove. A beam, an aura ticking, a chain touching
## four boarders: each tick added its full `knock / mass` again. Reported as
## boarders "suddenly thrown right next to the boiler", and the arithmetic
## agrees — at 3000 a second the travel before it decays is about 4,300 units
## down a deck that is 2,320 long.
##
## Capped, a full shove carries about 386 units. That is a real displacement you
## can feel and use, and it is a sixth of the deck rather than all of it.
const KNOCK_MAX := 900.0

## And how hard it has to be to put someone over the rail. Well above a single
## hit from anything — going overboard should be something you SET UP, with a
## heavy shape or a stacked pair, not a thing that happens by accident to
## whoever is standing nearest the edge.
const OVERBOARD_SPEED := 520.0

## HOW FAR A SHOVE CAN EVER CARRY — in GROUND, not velocity. The July-31 cap
## bounded `knock_velocity` and asserted the distance it implies analytically
## (v²/2a = 386), but never measured the enemy's own frame. The frame betrayed
## it: `velocity += knock_velocity` folded the capped shove into the WALK
## velocity, and the walk lerp only bleeds ~10% a frame — so the shove was
## integrated a second time with a ninefold gain. Measured: ONE capped hit on
## a moving boarder carried 1,338 units, mid-deck to the stern wall, straight
## past the Boiler (board SG-62, the owner's "game breaking"). The walk keeps
## only the walk now (see the bottom of `_physics_process`), and this cap is
## POSITIONAL — anchored where the shove began, enforced after the move, so no
## stack of multipliers and no future integration slip can carry past it.
const KNOCK_TRAVEL_MAX := 390.0

## THE STERN LINE. Knockback may STOP a boarder; it may never DELIVER one.
## Spawn is at the bow (y = -1115), the Boiler at the stern (y = +850), so a
## hit taken from the bow side points `away` stern-ward — which made hitting a
## boarding party from behind the fastest way to hand it to the Boiler. While
## a shove is live, a boarder may not end a frame more than this many units
## stern-ward of where the shove began. Sideways and bow-ward stay free: the
## rail kill and pushing them back the way they came are the point of knockback.
const KNOCK_STERN_GIVE := 60.0

var knock_velocity := Vector2.ZERO
## Where the live shove began — the anchor `KNOCK_TRAVEL_MAX` and
## `KNOCK_STERN_GIVE` measure from. A hit landing while a shove is already
## live keeps the OLD anchor, so chained hits cannot ratchet the line forward;
## the anchor releases only when the shove has fully decayed.
var knock_anchor := Vector2.ZERO
var knock_live := false
## Past the rail and no longer the lane's problem. Kept as state rather than
## resolved on the spot because the clamp has to STOP running for them, and a
## boarder mid-fall is briefly outside every rule the deck has.
var overboard := false
var slow_time := 0.0
var slow_amount := 0.0
var stun_time := 0.0
var burn_time := 0.0
var burn_stacks := 0
var burn_tick := 0.25
var spawn_serial := 0
## The Colossus fights in two beats and the turn between them is a real moment:
## it cannot be burst through, it clears what it called, and the second beat
## reaches the whole deck. A phase change you can skip is not a phase change.
var beat := 0
var turn_time := 0.0

## How long that turn holds. It was a literal at the one place it is assigned,
## which is fine until something outside the simulation needs to know how long
## the beat lasts — and something does now: the segmented Colossus plays a
## `turn` clip through it (board SG-90), and a one-shot in `scripts/rig3d.gd` is
## fitted to the WINDOW it is given. Reading `turn_time` itself would not do, on
## the SG-85 lesson: it counts DOWN, and a window that shrinks every frame is a
## clip that accelerates as it plays. Same number, named once.
const TURN_TIME := 1.6

## --- MAY THIS BOARDER BE HURT? ONE FUNCTION, AND EVERY DAMAGE PATH ASKS IT ----
##
## THE OWNER'S RULE, 2026-08-03, over build 53: *"While they're jumping, they
## should be immune to all damage until they hit the deck and start moving."*
##
## `state == "climb"` IS "has not hit the deck and has not started moving" — it
## is the 0.8 s window a fresh boarder spends with its velocity zeroed before
## `state` becomes `"move"`. So the owner's sentence needs no new channel in the
## simulation; it needs the window that already exists to be believed by
## everything instead of by two things.
##
## WHY THIS IS A PREDICATE AND NOT A BRANCH IN EACH CALLER. Before this, the
## deck held two contradictory opinions about whether an arriving boarder was
## real: `game.gd`'s cannon and crew targeting loops skipped one by typing the
## string `"climb"` in two places, and every player skill, aura, fire pool, keg,
## steam tap, dash impact and the auto-attack hit it. Nobody noticed because a
## climbing boarder was drawn standing on the planking; the moment it is drawn
## falling out of a transport, damage numbers popping under a figure in mid-air
## is the bug report. Making it total rather than per-path is the whole point:
## a damage source added next month cannot forget a rule it never has to
## remember.
##
## `can_be_hit()` is therefore asked in exactly three places, and between them
## they are every way a boarder's hp has ever gone down:
##
##   1. `take_damage` — the sim's only entry to hp reduction, and the sole
##      production caller is `game.gd::damage_enemy`, the single funnel every
##      skill shape, circle, cone, line, bolt, crew swing and sentry goes
##      through.
##   2. the BURN TICK in `_update_statuses` — which decrements `hp` directly and
##      is the one path that has never gone through `take_damage`.
##   3. the two targeting loops in `game.gd`, which now ask this instead of
##      naming the state, so there is no longer a string literal outside this
##      file that anything reasons about.
##
## IT ALSO SUBSUMES THE COLOSSUS'S TURN, deliberately, and that closes a real
## hole rather than tidying one. `take_damage` refused damage during
## `state == "turn"` and the burn tick did not, so a Colossus WAS burnable
## through the beat that `scripts/rig3d.gd` says out loud "returns zero through
## it". One predicate, both readers, and the two can no longer disagree.
func airborne() -> bool:
	return state == "climb"


func can_be_hit() -> bool:
	return not dead and not airborne() and state != "turn"


func _windup_scale() -> float:
	if game == null or not ("heat" in game):
		return 1.0
	return SkyGearWorkshop.windup_for(int(game.heat))


## DOES THE SWING LAND — and the answer is the shape that was DRAWN.
##
## Board SG-3 made the reach one number instead of two: the wedge is drawn at
## `config.reach` and the sim connects at `config.reach + target_radius`. But it
## only ever unified the RADIUS. The connect test stayed a bare
## `distance_to(...) <= swing_reach` — a full 360° circle — while the telegraph
## on the deck is a 120° (knight), 95° (scrapper) or 80° (gremlin) FAN pointed
## along `attack_direction`. So a player who did the thing the picture asks for
## — step out of the lit wedge, sideways, around the flank — was still hit by a
## swing that visibly went the other way. That is STATUS failure mode two in the
## dimension nobody checked, and it is most of why "designed to be dodged"
## (build-44, the furnace knight) did not describe the game.
##
## The wedge is now the hitbox in BOTH dimensions. Two notes on the geometry:
##
##   * The test is against the target's BODY, not its centre — a disc of radius
##     `body` overlaps the fan if its centre is within `swing/2 + asin(body/d)`
##     of the swing's axis. Being clipped by the edge of the picture should
##     hurt; only getting clear should not.
##   * THERE IS NO LONGER A REACH-LESS PATH (board SG-119). It used to say here
##     that an enemy with no `swing` — the Colossus — "telegraphs with a phase
##     ring rather than a fan", and that was simply false: `view3d.gd` drew him
##     a 120° fan out of a fallback constant while this function returned true
##     unconditionally, so his hitbox was a full circle around a wedge-shaped
##     picture. He carries his own `reach` and `swing` now, and the two fallback
##     branches are GONE from both files, so there is no path left that answers
##     "no shape given" with "then everything hits".
##
##     `config.swing` is therefore read with no membership test. Be precise
##     about what that buys, because the obvious claim is wrong and was checked
##     rather than assumed: a missing key in Godot is a LOGGED error, not a
##     halt — the expression yields null and `float(null)` is 0.0 — so a melee
##     row added without a `swing` would get a zero-width wedge and console
##     noise, not a crash. What actually guards it is the harness, at
##     `telegraph · every melee windup has a reach and a swing arc to draw`,
##     whose roster is read off the ENEMIES table rather than typed out. That
##     matters: the roster WAS three typed names, and the one melee row missing
##     from the list was the one melee row that would have failed.
##
## Nothing that stands still notices this: `attack_direction` is locked pointing
## at the target when the windup trips, so the boiler, a cannon and a crewman are
## dead centre of the fan and connect exactly as before. It is a change to what
## a MOVING captain can do, which is the whole point.
func _swing_hits(point: Vector2, swing_reach: float, body: float) -> bool:
	var offset := point - global_position
	var distance := offset.length()
	if distance > swing_reach:
		return false
	if distance <= body or distance <= 0.001:
		return true
	var half: float = float(config.swing) * 0.5 + asin(clampf(body / distance, 0.0, 1.0))
	return absf(attack_direction.angle_to(offset)) <= half


## THE WEDGE THAT CONNECTS IS THE WEDGE THAT WAS DRAWN — one function, called by
## the sim below and by `view3d.gd`'s telegraph pass, because board SG-119 was
## caused by two files computing the same shape from the same table separately
## and drifting apart (STATUS failure mode two). The renderer draws the fan at
## `swing_wedge_reach()` spanning `swing_wedge_arc()`; the sim connects out to
## `swing_wedge_reach() + target_radius`, measured to the target's near edge.
## Anything that wants the shape asks HERE.
##
## The Colossus's second beat is the only phase term, and it is one constant.
const BOSS_SECOND_BEAT_REACH := 90.0


## THE COLOSSUS WALKS THE LANE, NOT THE CAPTAIN — COLOSSUS-DESIGN §2 graft 1,
## the root fix, and SET TO `false` TO PUT HIM BACK ON HER HEELS (board SG-146).
##
## FLIP THIS ONE LINE AND THE WHOLE CHANGE IS GONE. It is a constant and not a
## table field on purpose: the owner asked for more health, got it in its own
## commit, and this is the SEPARATE half he must be able to revert without
## touching that one. Nothing else in this file or in `game.gd` knows about the
## chase gate; it is exactly this boolean and the one `if` that reads it.
##
## WHY IT IS THE ROOT FIX, in the numbers COLOSSUS-DESIGN §1 measured. He trips
## his windup at `attack_range 120 + target radius 17 = 137` and then stands
## still for `windup 0.90 s`, in which a 260 u/s captain walks 234 units — to
## ~371, comfortably outside his 163-unit swing — and then stands still again for
## `recover 1.00 s`. **Every swing he aims at a moving captain costs him 1.9
## seconds of frozen uptime for a hit that geometrically cannot land**, and he
## closes at 95 u/s against her 260 plus two 265-unit dashes, so he never gets
## the initiative back. Chasing her is not a weak behaviour, it is a behaviour
## with negative value: it is the thing that makes him harmless.
##
## SO HE STOPS CHASING AND THE `else` BRANCH BELOW — WHICH ALREADY EXISTS AND IS
## ALREADY THE RIGHT ONE — takes over: lane cannon, then a crewman in the way,
## then the Boiler. He becomes a clock rather than a pursuer. 1,965 units at
## 95 u/s is 20.7 s to the Boiler and 26 damage per 1.9 s burns its 500 HP in
## 36 s, so ignoring him is no longer free — it is priced in the ship. Standing
## at her comfortable 260, where her Ember Cleave reaches his centre because
## player damage tests add the target's radius, now costs Boiler HP per second.
##
## THIS IS DELIBERATELY NOT THE WHOLE OF OPTION B. No furnace gauge, no wash, no
## cooling, no `on_boss_turn` rewrite. Those are the design's recommendation and
## they are not decided; this is the one line both independent judges converged
## on unprompted, which §7 records as "the real finding".
##
## IT APPLIES TO THE COLOSSUS ALONE. Every other boarder still turns on the
## captain inside 280 — that is what makes a lane feel defended, and gating it
## for everyone would be a different and much larger change.
##
## ---------------------------------------------------------------------------
## AND IT SHIPS **OFF**, BECAUSE IT WAS BUILT, MEASURED, AND FAILED ITS OWN
## PRE-COMMITTED KILL-TEST. This is the whole reason the flag exists rather than
## the change simply landing (SG-146).
##
## `tools/boss_probe.gd`, wave-12 segment, Heat 0, three arms off one base
## (c486000), n = 211 / 332 / 214 runs that reached wave 12:
##
##                              hp 900   hp 2900   hp 2900 + this gate ON
##   boss time-to-kill            9.7 s    22.0 s    24.0 s
##   damage taken in wave 12      45.5     131.5      13.4
##     ...OF THAT, BY HIM         29.9     123.4       0.00   (sd 0.00)
##   Boiler HP lost in wave 12     9.5       4.8      11.3    (t=0.51, UNRESOLVED)
##   runs held                    100%       66%       99%
##
## TWO THINGS THAT ARE BOTH FATAL TO SHIPPING IT ON:
##
## 1. **He stops being able to touch her AT ALL — not rarely, never.** 0.00 mean
##    with 0.00 spread over 214 runs is not a small number, it is a structural
##    zero, and the code says why: the victim chain below is if/elif, and
##    `target_turret`/`target_crew` are only populated in the `else` branch, so
##    when he is not targeting the captain she is never tested against his swing.
##    The owner asked for a Colossus who is SCARY. This one cannot hit him.
## 2. **The compensating threat never arrives.** COLOSSUS-DESIGN §2's amended
##    statistic (2) pre-committed the bar: *"Median Boiler HP lost during wave 12
##    must rise by >= 40 of 500 against a baseline of ~0."* Measured: 9.5 -> 11.3,
##    Welch t = 0.51, and the Boiler still takes nothing at all in 88% of runs.
##    The design's own rule for that outcome is written down and it is **CUT, not
##    tune**. The arithmetic behind the miss is worth keeping: he needs 20.7 s to
##    walk 1,965 units to the Boiler and he only lives 24 s, and he spends part of
##    that on the lane cannon he now meets first — so the clock the design is
##    built on barely fits inside the fight, and mostly does not.
##
## WHAT WOULD HAVE TO CHANGE FOR IT TO EARN ITS `true`: either he lives long
## enough to arrive (more health again, which is the thing that already tripled),
## or he starts much closer to the ship, or the swing gains the multi-victim
## resolve §4 costs at ~220 lines. All three are decisions, not tunings, and they
## belong to the owner and to the unbuilt half of COLOSSUS-DESIGN.
##
## FLIP IT TO `true` TO SEE IT. Nothing else needs editing; the harness pins the
## constant to the behaviour in both positions.
##
## ---------------------------------------------------------------------------
## IT IS `true` NOW, AND THE THING THAT EARNED IT IS THE STOMP BELOW (SG-166).
##
## The owner, 2026-08-03, unprompted and in his own words: *"The Colossus health
## is fine as it is... he's just a meat shield, just soaks and takes time, so we
## need to make him a little more dangerous. Maybe even just have him ignore the
## player and keep heading towards the middle, destroying the cannon and then
## attacking the main objective. Have the damage that he does just be damage
## around him so that it can hurt the player when the players try to kill him."*
##
## That is graft 1 above plus the exact repair for the reason it was cut. Reason
## 1 for shipping it OFF was that he could no longer touch her AT ALL — a
## structural zero, because the victim chain below is if/elif and a boss who is
## not targeting her is never tested against her. **The stomp does not go through
## the victim chain.** It is a circle centred on him that asks one question of
## the captain directly, so "he ignores you" and "standing next to him hurts" are
## no longer the same sentence. Reason 2 — the Boiler clock failing its
## pre-committed +40 — was a statistic written for a design whose whole danger
## budget was the ship's health bar; the owner has now put the danger somewhere
## else, and SG-166 pre-committed and measured a new one against the thing he
## actually asked for. Both are recorded on that row, including the honest cost.
const COLOSSUS_WALKS_THE_LANE := true


## THE SHIPPED DEFAULT, PER INSTANCE — and it is a `var` for a reason that cost
## a rewrite to find. With the constant shipped `false`, a check that could only
## read the shipped default was VACUOUS: deleting the call to `chases_captain()`
## from the targeting `if` below left the harness at 946/946, because with the
## gate off both branches behave identically. A mechanism whose wiring is only
## tested in the position it is not shipped in is not tested at all — that is
## STATUS's "a harness check that asserts the bug", one step earlier. Settable
## per instance, the harness drives BOTH positions and reverting that line turns
## it red.
var walks_the_lane := COLOSSUS_WALKS_THE_LANE


## Whether this boarder will break off toward the captain when she is close.
## One function rather than an inline `kind != "BOSS"` so that the harness can
## ask the question directly instead of inferring it from a velocity.
func chases_captain() -> bool:
	return not (walks_the_lane and kind == "BOSS")


## --- THE STOMP: HIS DAMAGE BECOMES GROUND RATHER THAN AIM (board SG-166) -----
##
## THE OWNER'S DESIGN, VERBATIM: *"Have the damage that he does just be damage
## around him so that it can hurt the player when the players try to kill him."*
##
## WHY IT IS A PLANTED, ANCHORED, TELEGRAPHED BEAT AND NOT AN AURA. An aura that
## chips you for standing near him is the cheapest way to write this and it is
## the wrong one twice over. It is UNREADABLE — there is no frame at which the
## player is told anything, so damage arrives as a mystery and the counterplay
## has to be learnt from a health bar. And it is UNFAIR by this game's own
## pillar 6, which says every attack is readable before it is dangerous. This
## deck's whole visual language is marks on the planking with a clock running in
## them; a stomp is that language applied to a circle instead of a wedge, and the
## renderer draws it in the same oxblood/orange family as every other hostile
## mark (board SG-158's vocabulary, not a third one).
##
## THE SHAPE IS A CIRCLE AND THE SWING IS A FAN, WHICH IS THE WHOLE READ. Both
## say DANGER in the same colours, and which one is on the deck tells you whether
## the answer is "step around him" or "get out". One frame, two shapes, no new
## palette — this is COLOSSUS-DESIGN §5's telegraph craft ("gold ring versus red
## fan is one-frame distinguishable") with the hue argument dropped, because gold
## is already the turn ring's and a mark that hurts you must be in the hostile
## family or the language stops meaning anything.
##
## ANCHORED AT THE FOOT HE PLANTS. `stomp_origin` is latched when the beat
## begins, drawn there and resolved there, so a Colossus shoved mid-telegraph
## leaves the mark where the blow lands rather than dragging it after him. The
## sim and the renderer read ONE radius from `stomp_radius()` for the same reason
## the wedge is `swing_wedge_reach()`: board SG-119 was two files deriving one
## shape and drifting, and this adds no second derivation.
##
## THE NUMBERS, AND EACH IS A DODGE BUDGET RATHER THAN A FEELING:
##
##   STOMP_RADIUS 240        His body is 70 and his swing wedge reaches 146. Her
##       free Ember Cleave reaches his CENTRE at 260 (every player damage test
##       adds the target's radius), so 240 + her body 17 = 257 leaves the
##       standoff she already knows about SAFE and prices only closing in. That
##       is exactly the owner's sentence: it hurts the player who comes to kill
##       him, and it does not tax the player who keeps her distance.
##   +80 IN BEAT 2 (320)     The escalation TAKES the safe standoff away — 320 +
##       17 = 337 against her 260 — which is what a second beat should do, and it
##       mirrors the swing's own +90 rather than inventing a second rule.
##   STOMP_WINDUP 0.80 s     At 260 u/s that is 208 units of walk. From the bot's
##       210-unit band she needs 47 units to clear 257; from POINT BLANK against
##       his 70-unit body she needs 187, which is 234 u/s — inside her walk, and
##       trivially inside one 265-unit dash. Escapable from anywhere in the
##       circle without a dash, and comfortably with one.
##   STOMP_PERIOD 2.40 / 1.40  Measured from the end of the last stomp, so the
##       true cadence is period + windup + recover: 4.2 s in beat 1, 3.2 s in
##       beat 2. **THIS IS THE ONLY NUMBER THAT WAS TUNED, IT TOOK THREE ARMS OF
##       n=480 EACH, AND THE BAR WAS WRITTEN BEFORE ANY OF THEM WERE RUN.**
##
##       ARM 1, cadence 5.0/4.0 s: the whole change measured as a SOFTENING —
##       his damage to the captain 123.97 -> 104.70 (Welch t = -4.94) and the
##       Heat 0 hold-rate 65.8% -> 82.9%. The diagnosis is the interesting half
##       and it is not "not enough damage", it is VARIANCE: the chase build's
##       mean was carried by a heavy tail (sd 70.3) of runs where he cornered a
##       kiting captain, and an anchored, telegraphed, escapable circle has no
##       tail at all (sd 32.0). That is why a 10% drop in the mean moved the
##       hold-rate 17 points, and it is the honest shape of what a READABLE
##       threat does to a distribution.
##       ARM 2, cadence 3.6/2.8 s: overshot in the other direction — damage
##       188.95 (+52%) and hold-rate 48.5%, below the pre-committed floor of the
##       chase build's own 95% interval. Dangerous, but that is a Heat rung
##       wearing a design's clothes.
##       ARM 3, THIS ONE, was interpolated in 1/cadence between those two points
##       rather than guessed, and it was the single retune the pre-commitment
##       allowed itself. The measured result is on board SG-166.
##   DAMAGE                  `config.damage`, his swing's own 26. One number for
##       what a Colossus blow costs, not two.
##
## IT RESOLVES INTO `recover`, ON PURPOSE. The stomp costs him the same 1.00 s of
## stationary punish window a whiffed swing does, and it inherits SG-158's teal
## opening ring for free — so the beat the player is invited to attack into is
## marked identically whichever attack he just spent.
##
## IT HITS EVERYTHING STANDING IN THE CIRCLE (board SG-185, and it did NOT until
## 2026-08-04). The owner, off his first full twelve-wave run: *"Collosus didnt
## seem to be able to damage turrets."*
##
## SG-166 shipped this resolve asking ONE question, of the captain, and calling
## ONE function, on the argument quoted above these lines: his structural damage
## was the swing's job and the stomp was not to move two things at once. That
## argument was sound when it was written and it was WRONG ABOUT THE SWING, for a
## reason nothing measured until SG-185 did — the stomp check sits at the head of
## `state == "move"` and PREEMPTS the swing whenever both are ready, so the beat
## that carried the whole victim chain almost never comes round. Measured with
## `tools/lane_probe.gd`, a Colossus walking lane 1 at Heat 2 for 60 s: with the
## stomp on he resolved **8 swings** and took **208** off a **760** cannon; with
## it off, **25 swings** and **650**. He was not unable to hurt the ship — he was
## slowed to 32% of the rate, against a cannon he must break in the ~23 s he
## lives, and 208 of 760 is a cannon he never once destroys. The owner reported
## the OUTCOME correctly.
##
## THE FIX IS NOT TO GIVE THE SWING ITS BEAT BACK. It is that a stomp is a circle
## on the planking and a cannon bolted inside that circle is standing in it. So
## the resolve asks `stomp_hits` — the SAME circle, no second shape, because
## board SG-119 was paid for by a drawn shape and a hit shape disagreeing — of
## every body on the deck: the captain, every live cannon, every live crewman,
## and the Boiler.
##
## AND THE STRUCTURAL ZERO IT WAS BUILT TO REPAIR IS UNTOUCHED. The point of the
## bypass was never "only the captain": it was that the victim chain above is
## `if/elif` and a boss walking at the ship is never `targets_player`, so the
## chain can never test her. This resolve still does not go through that chain.
## It goes through NONE of it — it is an area, and an area has no priority order.
##
## THREE CALLS THAT ARE BALANCE DECISIONS, MADE HERE AND MEASURED ON SG-185:
##
##   THE CANNONS: full damage, every one inside the rim, not the nearest. His
##       whole design is that he marches at the lane cannon and takes it away,
##       and a 240-unit circle centred on a 70-unit body reaches one cannon in
##       practice — the lanes are 560 apart. "Everything in the circle" is a
##       simpler rule than "the nearest one in the circle" and here they are the
##       same rule, so the simpler one is written.
##   THE CREW: full damage. A crewman is 68 HP against his 26, so a stomp is
##       three beats to put a sailor down and not a wipe; halving it would be a
##       special case earning nothing. And a crewman standing under the biggest
##       figure on the deck while it plants is a mistake the game already draws a
##       240-unit ring around.
##   THE BOILER: YES, and this is the one that changes a number the ledger has
##       been arguing about since COLOSSUS-DESIGN §2. He reaches the Boiler at
##       the END of a 1,965-unit walk with seconds to live, so this is not a new
##       tax on ignoring him — it is the first build in which arriving MEANS
##       anything. SG-166's Finding 4 recorded Boiler HP lost in wave 12 going
##       11.08 -> 6.00 and put it down to him spending 43% of his life planted;
##       that reading was half the story and the other half is that he could not
##       hurt the Boiler at all. The re-measurement is on SG-185.
##
## WHAT IS DELIBERATELY NOT IN THE CIRCLE: deployed SENTRIES. Nothing he has has
## ever damaged one — not the swing, not the chase build — so adding them here
## would be a second change wearing this one's clothes, which is the exact
## mistake the paragraph this replaces was trying to avoid.
const COLOSSUS_STOMPS := true

const STOMP_WINDUP := 0.80
const STOMP_PERIOD := 2.40
const STOMP_PERIOD_BEAT2 := 1.40
const STOMP_RADIUS := 240.0
const STOMP_SECOND_BEAT_RADIUS := 80.0

## Settable per instance for the reason `walks_the_lane` is (SG-146's hardest
## lesson): a check that can only read a shipped default is vacuous, and the
## harness has to be able to drive BOTH positions or deleting the gate leaves the
## run green.
var stomps := COLOSSUS_STOMPS
var stomp_cooldown := STOMP_PERIOD
## Where the foot came down. Latched at the plant, read by the sim's resolve and
## by the renderer's mark — one point, so the mark cannot promise ground the blow
## does not take.
var stomp_origin := Vector2.ZERO
## The full length of the telegraph this stomp was given, kept because
## `_windup_scale()` shortens it at Heat 2 and a renderer dividing by the
## constant would run a clock that does not match the one the sim is counting.
var stomp_wind := STOMP_WINDUP
## WHICH SHAPE THE RECOVERY IS RECOVERING FROM. `state == "recover"` is shared by
## the swing and the stomp, and SG-158's strike flash is drawn on the wedge's
## rim; flashing a fan after a circular blow would draw a mark in a place nothing
## happened. Set true on a stomp resolve, false on a swing resolve, so the flag
## can never be stale.
var stomp_struck := false


## Whether this boarder stomps at all. A function rather than an inline
## `kind == "BOSS"` for the same reason `chases_captain()` is one: the harness
## asks the question instead of inferring it.
func stomps_the_deck() -> bool:
	return stomps and kind == "BOSS"


## ONE RADIUS, ASKED HERE BY BOTH THE SIM AND THE RENDERER (the SG-119 rule).
func stomp_radius() -> float:
	var r := STOMP_RADIUS
	if beat == 1:
		r += STOMP_SECOND_BEAT_RADIUS
	return r


func stomp_period() -> float:
	return STOMP_PERIOD_BEAT2 if beat == 1 else STOMP_PERIOD


## Does the stomp reach this point? Measured from the ANCHOR to the target's near
## edge, the same convention `_swing_hits` uses, so a body clipped by the rim
## takes it and only getting clear does not.
func stomp_hits(point: Vector2, body: float) -> bool:
	return stomp_origin.distance_to(point) <= stomp_radius() + body


## EVERY BODY IN THE CIRCLE, ONE SHAPE, NO PRIORITY ORDER (board SG-185).
##
## The swing above is an `if/elif` chain that picks ONE victim, because a swing
## is a wedge pointed at the thing it was aimed at. A stomp is not aimed at
## anything — it is his weight arriving on the planking — so it has no nearest
## and no first. Everything standing on the ground it takes, takes it.
##
## `stomp_hits` is the only geometry in here, called once per candidate against
## that candidate's own body radius, which is `_swing_hits`'s convention and
## SG-119's rule: one function owns the shape, and the renderer asks the same
## one. Nothing in this function may grow a radius of its own.
##
## Returns what it touched, so a caller — the harness, a probe — can assert on
## the victims rather than on a health bar that has three other things draining
## it (SG-166's `landed` column is contaminated for exactly that reason, and
## SG-167 had to write the caveat down).
func _resolve_stomp() -> Dictionary:
	var hit := {"player": false, "turrets": 0, "crew": 0, "boiler": false}
	var damage := float(config.damage)
	if stomp_hits(game.player.global_position, 17.0):
		game.damage_player(damage, kind)
		hit.player = true
	for t in game.turrets:
		if not bool(t.dead) and stomp_hits(Vector2(t.position), float(t.radius)):
			game.damage_turret(t, damage)
			hit.turrets += 1
	for c in game.crew:
		if not bool(c.dead) and stomp_hits(Vector2(c.position), float(c.radius)):
			game.hurt_crew(c, damage)
			hit.crew += 1
	if stomp_hits(game.boiler_position, float(game.boiler_radius)):
		game.damage_boiler(damage)
		hit.boiler = true
	return hit

func swing_wedge_reach() -> float:
	var wedge: float = float(config.reach)
	if kind == "BOSS" and beat == 1:
		wedge += BOSS_SECOND_BEAT_REACH
	return wedge


func swing_wedge_arc() -> float:
	return float(config.swing)


func configure(owner_game: Node, enemy_kind: String, enemy_lane: int, wave: int) -> void:
	mass = 2.6 if enemy_kind == "ARMORED" else (24.0 if enemy_kind == "BOSS" else 1.0)
	game = owner_game
	kind = enemy_kind
	lane = enemy_lane
	config = SkyGearData.ENEMIES[kind]
	## HEAT 1 · RUST hardens this. The 0.06 was a literal here and nowhere else,
	## which is fine until a difficulty wants to move it.
	var per_wave: float = SkyGearWorkshop.BASE_HP_SCALING
	if game != null and "heat" in game:
		per_wave = SkyGearWorkshop.hp_scaling_for(int(game.heat))
	var scaling := 1.0 + per_wave * maxf(0.0, wave - 1.0)
	max_hp = float(config.hp) * scaling
	hp = max_hp
	radius = float(config.radius)
	$CollisionShape2D.shape.radius = radius
	$Sprite.texture = load(config.texture)
	$Sprite.scale = Vector2.ONE * float(config.scale)
	$Sprite.position.y = -radius * 1.8
	add_to_group("enemies")
	queue_redraw()

func _physics_process(delta: float) -> void:
	if game == null or dead or not game.is_playing():
		velocity = Vector2.ZERO
		return
	_update_statuses(delta)
	if dead:
		return
	# the turn, fired once, on the frame the second beat begins
	if kind == "BOSS" and beat == 0 and hp <= max_hp * 0.5:
		beat = 1
		state = "turn"
		turn_time = TURN_TIME
		velocity = Vector2.ZERO
		game.on_boss_turn(self)
	if state == "turn":
		turn_time -= delta
		velocity = Vector2.ZERO
		if turn_time <= 0.0:
			state = "move"
		queue_redraw()
		return
	if state == "climb":
		state_time -= delta
		velocity = Vector2.ZERO
		if state_time <= 0.0:
			state = "move"
		queue_redraw()
		return
	if stun_time > 0.0:
		velocity = knock_velocity
		knock_velocity = knock_velocity.move_toward(Vector2.ZERO, 900.0 * delta)
		move_and_slide()
		_rein_in_knock()
		if _went_over():
			return
		global_position = game.correct_enemy_position(global_position, lane, radius,
			knock_velocity.length() > OVERBOARD_SPEED)
		return

	## What this boarder is walking at, in priority order:
	##   the captain if she is close enough to be the problem,
	##   the deck cannon gating this lane while it still stands,
	##   a crewman in the way,
	##   otherwise the Boiler.
	## The cannon matters most: without it a lane is a stripe on the floor, and
	## boarders stroll past the thing that is supposed to be stopping them.
	var target_position: Vector2 = game.boiler_position
	var target_radius: float = float(game.boiler_radius)
	var targets_player := false
	var target_turret: Dictionary = {}
	var target_crew: Dictionary = {}
	if chases_captain() and global_position.distance_to(game.player.global_position) < 280.0:
		target_position = game.player.global_position
		target_radius = 17.0
		targets_player = true
	else:
		var gate: Dictionary = game.turret_in_lane(lane)
		if not gate.is_empty() and global_position.y < float(gate.position.y) + 40.0:
			target_position = gate.position
			target_radius = float(gate.radius)
			target_turret = gate
		else:
			var nearest_crew: Dictionary = game.nearest_crew(global_position, 220.0)
			if not nearest_crew.is_empty():
				target_position = nearest_crew.position
				target_radius = float(nearest_crew.radius)
				target_crew = nearest_crew
	var to_target := target_position - global_position
	var distance := to_target.length()
	var direction := to_target.normalized() if distance > 0.001 else Vector2.DOWN
	var attack_range: float = float(config.attack_range) + target_radius
	if kind == "BOSS" and beat == 1:
		attack_range += BOSS_SECOND_BEAT_REACH   # the second beat reaches the whole deck

	## THE STOMP CLOCK (SG-166). It runs in every state except the stomp itself,
	## so being mid-swing delays the next stomp rather than banking one — an
	## attack that queues up behind another attack arrives with no telegraph of
	## its own, which is the failure this whole beat is built to avoid.
	if stomps_the_deck() and state != "stomp":
		stomp_cooldown -= delta

	if state == "move":
		## THE STOMP PREEMPTS THE SWING WHEN BOTH ARE READY, and that is the point
		## of it under the lane walk: with `chases_captain()` false he is walking at
		## the cannon or the ship, so his swing is committed to structure and the
		## stomp is the only thing that ever asks about the captain at all.
		if stomps_the_deck() and stomp_cooldown <= 0.0:
			state = "stomp"
			stomp_wind = STOMP_WINDUP * _windup_scale()
			state_time = stomp_wind
			stomp_origin = global_position
			velocity = Vector2.ZERO
			game.play_sfx("enemy/telegraph.ogg", -6.0)
		elif distance <= attack_range:
			state = "windup"
			## HEAT 2 · SHORT FUSE. Faster to swing, not harder — the telegraph is
			## still there and still readable, which is the pillar this ladder is
			## not allowed to break.
			state_time = float(config.windup) * _windup_scale()
			attack_direction = direction
			velocity = Vector2.ZERO
			game.play_sfx("enemy/telegraph.ogg", -10.0)
		else:
			var speed_scale := 1.0 - slow_amount if slow_time > 0.0 else 1.0
			var desired := direction * float(config.speed) * speed_scale
			velocity = velocity.lerp(desired, 1.0 - pow(0.0015, delta))
	elif state == "windup":
		state_time -= delta
		velocity = Vector2.ZERO
		if state_time <= 0.0:
			if config.ai == "ranged":
				## A SHOOTER NEVER ASKS FOR A WEDGE. This branch is first, and the
				## reach is resolved INSIDE the melee branch below, because a
				## ranged row legitimately carries no `reach` — the harness pins
				## that at `telegraph · a ranged shooter is not handed a melee
				## swing`. Computing the wedge above this `if` reads `config.reach`
				## on the GUNNER and crashes its every shot; that is not a
				## hypothetical, it is what the first draft of SG-119 did, and the
				## whole harness stayed green while `tools/balance.gd` threw on
				## every bolt in all twelve waves.
				game.spawn_enemy_bolt(global_position, target_position, float(config.damage), float(config.bolt_speed))
				game.play_sfx("enemy/shoot_drone.ogg", -7.0)
			else:
				## The swing lands out to `reach` (the browser's tuned melee reach),
				## measured to the target's near edge — so `reach + target_radius`.
				## The telegraph wedge in view3d.gd is drawn at exactly this `reach`
				## because it calls the SAME function, so what is shown and what
				## connects are one shape rather than two derivations that drift
				## (STATUS failure mode two; board SG-119 is what happens when they
				## do).
				var swing_reach: float = swing_wedge_reach() + target_radius
				if targets_player and _swing_hits(game.player.global_position, swing_reach, 17.0):
					game.damage_player(float(config.damage), kind)
				elif not target_turret.is_empty() and _swing_hits(target_position, swing_reach, target_radius):
					game.damage_turret(target_turret, float(config.damage))
				elif not target_crew.is_empty() and _swing_hits(target_position, swing_reach, target_radius):
					game.hurt_crew(target_crew, float(config.damage))
				elif not targets_player and _swing_hits(game.boiler_position, swing_reach, float(game.boiler_radius)):
					game.damage_boiler(float(config.damage))
			stomp_struck = false
			state = "recover"
			state_time = float(config.recover)
	elif state == "stomp":
		## THE STOMP RESOLVE (SG-166, widened to the whole circle by SG-185). Asked
		## of every body on the deck directly and NOT through the victim chain
		## above — which is the whole repair to the structural zero that kept
		## `COLOSSUS_WALKS_THE_LANE` off. A boss walking at the ship is never
		## `targets_player`, so his swing can never test her; this does not care
		## what he is walking at, and since SG-185 it does not care who is standing
		## there either.
		state_time -= delta
		velocity = Vector2.ZERO
		if state_time <= 0.0:
			_resolve_stomp()
			stomp_struck = true
			stomp_cooldown = stomp_period()
			## The same stationary punish window a whiffed swing leaves, so the beat
			## the player is invited to attack into costs him the same second
			## whichever attack he just spent.
			state = "recover"
			state_time = float(config.recover)
	elif state == "recover":
		state_time -= delta
		velocity = Vector2.ZERO
		if state_time <= 0.0:
			state = "move"

	## THE SG-62 VECTOR LIVED ON THIS LINE. `velocity += knock_velocity` looks
	## like "add the shove for this frame", but `velocity` PERSISTS — the move
	## state's lerp keeps ~90% of it each frame — so every frame re-added the
	## whole shove on top of what the lerp still remembered of the last one.
	## A capped 900 shove integrated that way peaks near nine times itself and
	## carried 1,338 measured units. The walk keeps only the walk now: the shove
	## is added for the move and taken back off before the lerp can bank it.
	var walk := velocity
	velocity = walk + knock_velocity
	knock_velocity = knock_velocity.move_toward(Vector2.ZERO, 1050.0 * delta)
	move_and_slide()
	velocity = walk
	_rein_in_knock()
	if _went_over():
		return
	## The lane clamp is RELAXED while a real shove is on them, and that single
	## argument is the whole reason knocking someone off the ship was impossible
	## before. Every frame ended by pinning each boarder back inside a band 190
	## units either side of its lane centre — the outer bands stop at 750 and the
	## rail is at 840, so the ninety units where you would go over the side were
	## unreachable by construction, however hard you hit.
	global_position = game.correct_enemy_position(global_position, lane, radius,
		knock_velocity.length() > OVERBOARD_SPEED)
	queue_redraw()

## The two positional laws of a shove, enforced the frame it moved them —
## AFTER `move_and_slide`, BEFORE the rail and lane checks, in both the stunned
## and the walking paths:
##
##   1. `KNOCK_TRAVEL_MAX` — no shove carries more than this from its anchor,
##      whatever stack of multipliers or integration arithmetic produced it.
##   2. `KNOCK_STERN_GIVE` — no shove ends a frame more than this stern-ward of
##      its anchor. Stopped, never delivered to the Boiler.
##
## Positional on purpose: every earlier attempt capped a VELOCITY and was then
## beaten by whatever integrated that velocity (board SG-62's history, twice).
func _rein_in_knock() -> void:
	if not knock_live:
		return
	var offset := global_position - knock_anchor
	if offset.length() > KNOCK_TRAVEL_MAX:
		global_position = knock_anchor + offset.limit_length(KNOCK_TRAVEL_MAX)
	var stern_line := knock_anchor.y + KNOCK_STERN_GIVE
	if global_position.y > stern_line:
		global_position.y = stern_line
		## And stop pushing at the line, so the clamp is a wall rather than a
		## fight the shove keeps having every frame.
		knock_velocity.y = minf(knock_velocity.y, 0.0)
	if knock_velocity.length() <= 1.0:
		knock_live = false
		knock_velocity = Vector2.ZERO

## Are they past the rail? Called after the move and before the clamp, because
## the clamp is what would put them back.
##
## Only the SIDES count. The bow and the stern are where boarders arrive and
## where the Boiler stands, and a shove that deleted a boarder by pushing it off
## the front would make the safest thing you can do to a boarding party be to
## hit it back the way it came.
func _went_over() -> bool:
	if overboard or dead:
		return false
	var deck: Rect2 = SkyGearGame.DECK_RECT
	if global_position.x > deck.position.x and global_position.x < deck.end.x:
		return false
	overboard = true
	game.on_enemy_overboard(self)
	return true


func take_damage(amount: float, origin: Vector2, element: String, knock: float) -> float:
	## ONE GATE, and it is `can_be_hit()` above. It carries the Colossus's turn
	## (the second beat is the encounter's point and a phase you can skip is not
	## one) AND the arriving boarder's flight, so this function has no opinion of
	## its own about either and cannot drift from the one the burn tick and the
	## targeting loops read.
	if not can_be_hit() or amount <= 0.0:
		return 0.0
	var dealt := minf(hp, amount)
	hp -= amount
	var away := (global_position - origin).normalized()
	if away.length_squared() == 0.0:
		away = Vector2.UP
	knock_velocity = (knock_velocity + away * knock / mass).limit_length(KNOCK_MAX)
	## The shove's ground rules are measured from where it BEGAN. A fresh hit
	## on an already-flying boarder keeps the old anchor — that is what stops a
	## fast-ticking build (the SG-62 report: Frost Mortar + Pulse + the auto,
	## SLEDGE FORCE on top) from ratcheting the travel and stern lines forward
	## hit by hit.
	if not knock_live and knock_velocity.length() > 1.0:
		knock_live = true
		knock_anchor = global_position
	_apply_element(element)
	if hp <= 0.0:
		dead = true
		game.on_enemy_killed(self)
		queue_free()
	queue_redraw()
	return dealt

## One way to die, so a caller never has to remember the three steps.
func kill() -> void:
	if dead:
		return
	dead = true
	hp = 0.0
	game.on_enemy_killed(self)
	queue_free()


func _apply_element(element: String) -> void:
	match element:
		"EMBER":
			burn_stacks = mini(3, burn_stacks + 1)
			burn_time = 3.0
		"FROST":
			slow_time = 2.0
			slow_amount = 0.40
		"ARC":
			if game.rng.randf() < 0.20:
				stun_time = maxf(stun_time, 0.45)
		"STEAM":
			## A STOMP ONCE BEGUN CANNOT BE CANCELLED BY STEAM — the named rule
			## COLOSSUS-DESIGN §3 said had to be written down rather than discovered
			## in a playtest, now that the boss has an attack worth deleting
			## (SG-166). The Boilerwright's basic attack is a STEAM cone on a 0.60 s
			## period and the stomp's telegraph is 0.80 s, so without this line ONE
			## of the two classes deletes the Colossus's only means of touching a
			## captain, every time, for free — a class-specific hole in a boss
			## mechanic, arriving exactly the way §3 predicted.
			##
			## STEAM STILL CANCELS A SWING, unchanged and deliberately so: that is
			## the interrupt the element has always bought and every other boarder
			## still pays it. The asymmetry is the point — you can steam a Colossus
			## out of a swing, and you cannot steam your way out of standing in a
			## circle he has already put his weight behind.
			if state != "stomp":
				state = "move"

func _update_statuses(delta: float) -> void:
	slow_time = maxf(0.0, slow_time - delta)
	stun_time = maxf(0.0, stun_time - delta)
	if burn_time > 0.0:
		burn_time -= delta
		burn_tick -= delta
		## THE ONE PATH THAT NEVER WENT THROUGH `take_damage`, and so the one
		## path that has to ask the same question separately. It decrements `hp`
		## in place — no crit, no funnel, no telemetry — which is why a rule
		## written only inside `take_damage` would have a hole in it the size of
		## every burning boarder.
		if burn_tick <= 0.0:
			## The SCHEDULE advances whatever happens, and only the DAMAGE is
			## gated. Gating the whole branch would let the suppressed ticks pile
			## up behind a negative `burn_tick` and all land on the frame the
			## boarder became hittable again — an immunity window that pays
			## itself back with interest is not an immunity window. Same reason
			## SG-122 carries the overshoot rather than assigning it.
			burn_tick += 0.25
			if can_be_hit():
				var amount := 5.0 * burn_stacks * 0.25
				var dealt := minf(hp, amount)
				hp -= amount
				game.register_damage(dealt, global_position)
				if hp <= 0.0 and not dead:
					dead = true
					game.on_enemy_killed(self)
					queue_free()
	if burn_time <= 0.0:
		burn_stacks = 0

func _draw() -> void:
	_draw_flat_ellipse(Vector2(0, 7), radius * 1.25, radius * 0.48, Color(0.01, 0.01, 0.02, 0.50))
	if state == "turn":
		# the turn reads as a held moment: a bright ring, and nothing else
		draw_arc(Vector2.ZERO, radius + 26.0 + sin(turn_time * 9.0) * 6.0, 0.0, TAU, 48,
			Color("#ffd36b"), 7.0)
	if state == "climb":
		draw_arc(Vector2.ZERO, radius + 8.0, 0.0, TAU, 32, Color("#e8c376"), 3.0)
	if state == "windup":
		var reach := float(config.attack_range)
		draw_line(Vector2.ZERO, attack_direction * reach, Color(0.88, 0.20, 0.12, 0.72), 4.0)
	if hp < max_hp:
		draw_rect(Rect2(-radius, -radius * 2.3, radius * 2.0, 5), Color("#28131a"))
		draw_rect(Rect2(-radius, -radius * 2.3, radius * 2.0 * hp / max_hp, 5), Color("#e14f35"))

func _draw_flat_ellipse(center: Vector2, width: float, height: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 24:
		var angle := TAU * float(i) / 24.0
		points.append(center + Vector2(cos(angle) * width, sin(angle) * height))
	draw_colored_polygon(points, color)

