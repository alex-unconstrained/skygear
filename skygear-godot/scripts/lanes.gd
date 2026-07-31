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
const TURRET := {"hp": 760.0, "range": 400.0, "damage": 4.0, "cooldown": 1.9, "radius": 34.0}
const CREW := {
	"hp": 68.0, "damage": 1.5, "siege": 22.0, "speed": 118.0, "radius": 15.0,
	"reach": 52.0, "windup": 0.40, "recover": 0.5,
	"every": 14.0, "push_every": 9.0, "per_wave": 2,
}
const HULK := {"hp": 1500.0, "radius": 190.0}


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
	}


## A fresh vessel grapples on for every push. Each is a little tougher than the
## last, but only a little: the first one already reads as long.
static func make_hulk(bow_y: float, toughness: float) -> Dictionary:
	return {
		"position": Vector2(0.0, bow_y),
		"hp": HULK.hp * toughness, "max_hp": HULK.hp * toughness,
		"radius": HULK.radius, "vulnerable": false, "dead": false, "flash": 0.0,
	}
