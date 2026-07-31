class_name SkyGearDeckwork
extends RefCounted

## Things you can do TO the deck, rather than to the boarders on it.
##
## Asked for as "repair broken turrets", and framed as the seed of something
## larger — the player eventually shaping the ground: laning, funnelling, moving
## the fight somewhere they chose. So this is a VERB TABLE from the first day
## rather than a repair button with a comment promising to generalise later. The
## difference is that adding "drag a crate into a lane" is one entry here, and
## adding it to a repair button is a rewrite.
##
## THE CURRENCY IS TIME, and only time.
##
## Not salvage, not health, not the gauge. On a deck where three lanes are
## walking toward the Boiler, the cost of standing still for two seconds is
## already the sharpest cost in the game — it is measured in whatever those
## lanes did while you were busy. A second resource on top would make deckwork a
## budgeting decision when it should be a positional one, which is the whole
## reason the class layer and the draft layer are kept apart.
##
## Interrupted by taking a hit, by moving, and by casting. That is not a
## punishment, it is what makes the choice real: you commit or you fight, and
## the wrong lane breaking while you commit is the game working.

## An action is: who it applies to, how long it takes, and what it does.
##
##   at        which family of thing it targets
##   reach     how close you have to stand, in ground units
##   seconds   how long you are out of the fight
##   can       is this target valid right now
##   apply     do it
##
## `verb` is what the prompt says. Deliberately a verb rather than a noun, so
## the prompt reads "REPAIR THE CANNON" rather than "CANNON".
const REPAIR_SECONDS := 2.4
const REPAIR_REACH := 96.0
## What a repaired cannon comes back at. NOT full: a cannon you can restore to
## new is a cannon that never really broke, and the lane pressure that broke it
## stops meaning anything. Enough to matter, little enough that losing one still
## hurts.
const REPAIR_FRACTION := 0.55

## Boarders standing on it stop you. Repairing a gun with a scrapper swinging at
## your back is not a decision, it is a free action with extra steps.
const CONTESTED := 150.0


static func actions() -> Array[Dictionary]:
	return [
		{
			"id": "repair_turret", "verb": "REPAIR THE CANNON",
			"at": "turret", "reach": REPAIR_REACH, "seconds": REPAIR_SECONDS,
			"blocked": "boarders are on it",
		},
	]


## What you are standing next to that you could work on, or {}. One target, the
## nearest — a prompt that offers a choice is a prompt you have to read.
static func available(game) -> Dictionary:
	var best := {}
	var nearest := INF
	for spec in actions():
		for target in _targets(game, str(spec.at)):
			var gap: float = game.player.global_position.distance_to(
				Vector2(target.position))
			if gap > float(spec.reach) or gap >= nearest:
				continue
			if not _valid(game, spec, target):
				continue
			nearest = gap
			best = {"spec": spec, "target": target,
				"contested": _contested(game, target)}
	return best


static func _targets(game, family: String) -> Array:
	match family:
		"turret":
			return game.turrets
	return []


static func _valid(game, spec: Dictionary, target: Dictionary) -> bool:
	match str(spec.id):
		"repair_turret":
			## Only a dead one. A damaged gun still shoots, and letting you top it
			## up mid-wave turns deckwork into a maintenance chore you perform
			## constantly rather than a decision you make occasionally.
			return bool(target.get("dead", false))
	return false


## Is something standing over it? Checked separately from validity so the prompt
## can say WHY it is refusing rather than simply not appearing — a prompt that
## vanishes teaches nothing.
static func _contested(game, target: Dictionary) -> bool:
	for enemy in game.get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.dead:
			continue
		if enemy.global_position.distance_to(Vector2(target.position)) <= CONTESTED:
			return true
	return false


static func perform(game, spec: Dictionary, target: Dictionary) -> void:
	match str(spec.id):
		"repair_turret":
			target.dead = false
			target.hp = float(target.max_hp) * REPAIR_FRACTION
			target.flash = 0.6
