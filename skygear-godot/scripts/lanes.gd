class_name SkyGearLanes
extends RefCounted

## The lane layer: deck cannons, crew, and the boarding hulk.
##
## Ported from the browser build's `_lanes.js`, and it is the reason the deck is
## a map rather than an arena. Without it the port had three lanes drawn on the
## floor and nothing that made committing to one mean anything: no gate for the
## boarders to break, no allies pushing the other way, and no push waves.
##
## Kept as plain dictionaries drawn by the game rather than as scene nodes, for
## the same reason the browser keeps them as plain objects: there are at most
## three cannons, a dozen crew and one hulk, they have no physics worth the name,
## and a Node2D each buys nothing but a lifetime to get wrong.
##
## Tuning is the browser's, which was itself tuned down hard after the first v5
## playtest — crew were arriving nine at a time and the lanes held themselves.

## ALLIES HOLD LANES. THEY DO NOT CLEAR THEM.
##
## Measured over three full runs with `tools/balance.gd`: crew and cannons were
## doing 67% of all damage in the game. A real playtest put it at 46% with a
## better player at the controls. Either way the deck was largely defending
## itself, which makes the twelve waves a spectator sport and makes every
## upgrade the player drafts matter less than the two cannons they did not.
##
## So their damage comes down hard and their health goes up. A cannon is a gate
## a boarder has to break, and crew are bodies in the way — both of them buy the
## player TIME to be somewhere else, which is the decision the lane layer exists
## to create. Neither should be the reason a wave died.
##
## Crew `siege` is untouched: breaking the boarding hulk is their actual job and
## the one thing they are supposed to be better at than you.
## `shot_speed` is fast enough that a boarder walking at 150 cannot cross the
## 400-unit range before the ball arrives — the shot is there to be SEEN, not to
## be dodged, so making it visible must not quietly nerf the guns.
const TURRET := {"hp": 760.0, "range": 400.0, "damage": 4.0, "cooldown": 1.9,
	"radius": 34.0, "shot_speed": 900.0}
const CREW := {
	"hp": 68.0, "damage": 1.5, "siege": 22.0, "speed": 118.0, "radius": 15.0,
	"reach": 52.0, "windup": 0.40, "recover": 0.5,
	"every": 14.0, "push_every": 9.0, "per_wave": 2,
}
const HULK := {"hp": 1500.0, "radius": 190.0}


## --- THE ASSIST (board SG-187) -----------------------------------------------
##
## Owner, after a full twelve-wave run: *"Dont have crew standing around and
## auto attacking at the end of their lane - we can improve their AI to run
## towards available enemies if their lane is clear."*
##
## TWO FAULTS, ONE CAUSE. `game._update_crew` sends a crewman with nothing to
## fight to a fixed point at the head of his lane, and the arrival test there is
## `distance <= reach` — a test with no clause about whether anything is
## STANDING inside that reach. So he arrives, enters `windup`, swings at bare
## planking, recovers, and does it again for the rest of the wave, while a
## boarder walks down the lane beside his. Both halves of the owner's sentence
## are that one line.
##
## FOUR RULES. The first is the feature; the other three are what stop the fix
## being worse than the fault, because twelve lane defenders that all run at the
## loudest fight are not lane defenders, and the lane is the structure this
## whole ship is built on — it is what the note at the top of this file means by
## "the reason the deck is a map rather than an arena".
##
## 1. HIS OWN LANE OUTRANKS EVERYTHING, RE-ASKED EVERY TICK. Targeting is
##    recomputed from scratch each frame and the own-lane scan runs first, so
##    the instant a boarder enters his lane the assist is dropped mid-stride.
##    No commitment timer, no hysteresis, no "chasing" flag — nothing that can
##    get stuck holding a man away from his post. *Does he come back when a
##    boarder arrives in his lane?* is answered by the ORDER OF TWO LOOPS
##    rather than by a rule that has to remember to fire.
##
## 2. THE LEASH, AND IT IS ONE LANE. He will consider a boarder in an ADJACENT
##    lane, and only while that boarder is within `ASSIST_LEASH` of his own
##    station. 560 is the lane spacing — `SkyGearGame.LANE_CENTERS` are 560
##    apart — so the rule reads "as far as the next lane's centre line and not a
##    unit past it", and the far half of the neighbour's lane is somebody else's
##    problem. It is a bound on the TARGET rather than a clamp on the walk,
##    which is why it needs no clamp: he walks in a straight line at a point
##    inside a circle he is already inside, so he cannot leave the circle, and a
##    boarder that walks OUT of it stops qualifying on the next tick and the man
##    turns for home. One test, in one place, doing both jobs.
##
##    THE ARITHMETIC IT WAS PICKED ON. Recall from the far edge of the leash
##    costs 560 / 118 = 4.7 s at crew `speed`. The quickest thing that boards is
##    the gremlin at 230 units a second, and the deck cannon it is walking at
##    stands 1520 units down the lane from the bow — 6.6 s away; a scrapper at
##    150 takes 10.1 s and a furnace knight at 75 takes 20.3. So a man at the
##    very end of his leash is home before the fastest boarder in the game
##    reaches the gun he was standing in front of, and rule 4 means his lane was
##    never actually empty while he was gone.
##
## 3. ONE MAN PER BOARDER. An assisting crewman CLAIMS his target, and no second
##    man may pick a claimed one — so eight idle sailors cannot collapse into a
##    scrum around one gremlin. The number that can leave for a neighbouring
##    lane is bounded above by the number of boarders in it that are inside
##    somebody's leash, which is the anti-clump guarantee stated as arithmetic
##    rather than as a hope. Claims are handed out in MUSTER order, which is
##    `game.crew` order: no RNG, stable frame to frame, and independent of who
##    happens to be nearest — a nearest-first rule changes its mind every time
##    two men swap distances, and that is a rule you can watch flickering.
##
## 4. THE ANCHOR. The longest-serving unengaged hand in each lane never leaves
##    it. `game.crew` is muster order, so this is a stable choice and the man it
##    picks is that lane's veteran. It is the answer to the worst version of
##    this feature: a deck where everyone has drifted to one side is worse than
##    one where they hold station, and with an anchor per lane there is no
##    arrangement of boarders anywhere on the deck that can empty a lane of its
##    crew.
##
## WHAT IS DELIBERATELY NOT IN HERE. The crew's four `strafe` clips are wired up
## and unused, and they stay that way: `view3d.figure_heading` explains why (a
## strafe sells advancing while facing somewhere else, and this mover always
## faces where it is going, assist included). Whether the owner wants them is
## his open question and not this change's to answer.
const ASSIST_LEASH := 560.0

## WHERE A CREWMAN WITH NOTHING TO FIGHT STANDS, aft of the bow line.
##
## This was an inline `BOW_Y + 260.0` inside `_update_crew`'s goal expression.
## It is a function now because three things have to agree about where a man's
## post IS — the walk home, the leash that is measured from it, and the harness
## check that the leash is respected — and three copies of one number is the
## failure STATUS lists second.
const POST_AFT := 260.0

## THE WATCH STANDS ON ONE SPOT, AND THAT IS DELIBERATE — THE MOST EXPENSIVE
## THING THIS ROW LEARNED, AND THE ONLY MEASURED COST IN IT.
##
## Every hand in a lane holds the SAME station, so four sailors of radius 15
## stand inside one another. That is not pretty, and it becomes visible the day
## they stop milling through a swing cycle and start standing still — which is
## exactly what SG-187 did. So the first version of this work gave each man a
## post offset off the muster jitter he already carries, +-120 either side of
## his lane's centre line, costing no extra RNG and looking a great deal better.
##
## IT WAS A BALANCE CHANGE WEARING A VISUAL ONE, and four arms of 120 and 240
## runs each say so plainly (Heat 0, `tools/balance.gd`, baseline n=240):
##
##     arm                                    crew share     damage taken
##     baseline, none of this row              6.02%          346
##     hold-station only, posts fanned         4.71%          387
##     assist + posts fanned ACROSS the lane   4.55%          406
##     assist + posts fanned DOWN the lane     4.85%          387
##     assist, posts NOT fanned  (shipped)     6.31%          360
##
## The roaming — the thing the owner actually asked for — costs nothing that can
## be resolved. THE FAN COSTS ALL OF IT, and it costs the same whichever axis it
## is on, which is what rules out the first explanation (a roadblock with a hole
## in it) and leaves the real one: a stacked watch is FOUR SWINGS ON ONE BOARDER
## WITH NO WALKING. Spread the men by 120 units and every time one of them
## engages, the other three have to cross that gap at 118 units a second before
## they can join — about a second of not swinging, per man, per boarder, for the
## whole run. Crew are bodies in the way and their damage is a rate; a rate is
## what a walk costs.
##
## So the fan is REFUSED and this constant is gone rather than set to zero: a
## knob whose only correct value is zero is a knob somebody turns. `station()`
## is a function of the LANE alone, and `crew · every hand in a lane holds the
## same station` is the check that says so, with this number in its name.
##
## If the owner wants the watch to look like a watch rather than like one man,
## the honest ways to buy it are a renderer-side nudge that does not move the
## simulation, or paying for it somewhere — not this line, quietly.
##
## (The same lesson, one system over, is already written in `view3d`'s
## `FIGURE_SCALE`: *"`radius` is the footprint a boarder swings at and moving it
## is a balance change wearing a visual one."* It is no less true of where a
## figure stands than of how big he is.)

## How close to his station counts as AT it, in ground units.
##
## It exists to stop a man oscillating across his own post: the walk step is
## `speed * delta` and at the simulation's own 0.05 that is 5.9 units, so a
## tolerance under one step would have him overshoot, turn round, overshoot the
## other way and jitter on the spot for the rest of the wave — a different way
## of standing around, which is not the fix the owner asked for. Ten is a step
## and a half at 0.05 and five steps at 1/60, and the last step is clamped to the
## distance remaining as well, so this is a belt beside that brace.
const POST_SLACK := 10.0


## A crewman's own station: one definition, for the simulation, the leash and
## the harness alike — and a function of his LANE and nothing else. The block
## headed "THE WATCH STANDS ON ONE SPOT" above is why there is no per-man term
## in here, and what it cost to find out.
static func station(lane_centers: Array, lane: int, bow_y: float) -> Vector2:
	return Vector2(float(lane_centers[clampi(lane, 0, lane_centers.size() - 1)]),
		bow_y + POST_AFT)


static func make_turrets(lane_centers: Array, base_y: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in lane_centers.size():
		out.append({
			"lane": i,
			"position": Vector2(float(lane_centers[i]), base_y - 210.0),
			"hp": TURRET.hp, "max_hp": TURRET.hp,
			"cooldown": 0.0, "radius": TURRET.radius,
			"angle": -PI * 0.5, "flash": 0.0, "fire_flash": 0.0, "dead": false,
		})
	return out


## `rng` is the run's SEEDED stream, deliberately. This used the global
## `randf_range`, so two runs on the same seed mustered their crew in different
## places — a small thing that makes a seed not a seed.
static func make_crew(lane: int, lane_centers: Array, base_y: float,
		rng: RandomNumberGenerator = null) -> Dictionary:
	var jitter: float = rng.randf_range(-40.0, 40.0) if rng != null else 0.0
	return {
		"lane": lane,
		"position": Vector2(float(lane_centers[lane]) + jitter, base_y + 120.0),
		"hp": CREW.hp, "max_hp": CREW.hp,
		"state": "move", "state_time": 0.0,
		"radius": CREW.radius, "flash": 0.0, "dead": false,
		## The two fields a boarder has always had, on the ally side of the deck
		## at last (board SG-103) — where he is looking and where he is going.
		## `_update_crew` rewrites both every tick off the goal he is walking at;
		## these are only the values he musters holding, and up-deck is where a
		## fresh hand comes aboard facing.
		"attack_direction": Vector2(0.0, -1.0), "velocity": Vector2.ZERO,
	}


## A fresh vessel grapples on for every push. Each is a little tougher than the
## last, but only a little: the first one already reads as long.
static func make_hulk(bow_y: float, toughness: float) -> Dictionary:
	return {
		"position": Vector2(0.0, bow_y),
		"hp": HULK.hp * toughness, "max_hp": HULK.hp * toughness,
		"radius": HULK.radius, "vulnerable": false, "dead": false, "flash": 0.0,
	}
