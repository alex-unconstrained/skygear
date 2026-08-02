class_name SkyGearTelemetry
extends RefCounted

## What the player actually did, as opposed to what the game offered them.
## Ported from browser v11.2. Two uses, and the second is the reason it is worth
## the bookkeeping:
##
##   1. The run report can say which skill did the work.
##   2. The DRAFT can stop guessing. Every slot-targeted upgrade used to pick its
##      target slot uniformly at random, so LONG REACH landed on the skill you
##      never press as often as the one you live on.
##
## Attribution is by SLOT, not by shape or element, because a slot is what the
## player presses and what an upgrade targets.

## `slots` is how many attribution buckets the run needs — four, or five when
## THE SECOND HAND is signed. Passed in rather than read from a game, because
## this module is static and the harness builds fixtures without one; sized here
## rather than grown on demand, because `note_cast` DROPS a slot it has no row
## for, and a fifth slot whose damage silently vanished from the report is the
## data-with-no-reader failure inverted (a reader with no data).
static func fresh(slots: int = 4) -> Dictionary:
	var per: Array = []
	for _i in maxi(4, slots):
		per.append({"casts": 0, "damage": 0.0, "kills": 0, "hits": 0,
			"shape": "", "element": ""})
	return {
		"per": per,
		"basic": {"casts": 0, "damage": 0.0, "kills": 0, "hits": 0},
		"deck": {"damage": 0.0, "kills": 0, "kegs": 0, "crates": 0, "lanterns": 0},
		# The crew and the deck cannons fight too, and on a lane map they do
		# real work — a third of a run's damage in one measured browser case.
		"allies": {"damage": 0.0, "kills": 0},
		# Engagement distance, sampled every frame against the nearest live
		# boarder. Three buckets rather than a mean: a captain who alternates
		# between point blank and the far rail has the same mean as one who never
		# leaves mid-range, and they are not playing the same game.
		"range_time": {"close": 0.0, "mid": 0.0, "far": 0.0, "none": 0.0},
		"vents": 0, "healed": 0.0, "salvage": 0, "rerolls": 0,
		# Damage the captain actually TOOK, total and per wave — the two-line
		# telemetry idiom from ENEMY-VARIETY-DESIGN §2.5, shipped with the first
		# system that reads it (tempo's §2.2 kill-test, via tools/balance.gd).
		"taken": 0.0, "taken_by_wave": {},
	}


## A passive claims its row without claiming a cast. It has no button, so
## counting presses would be a lie, but it still has to appear in the report or
## its damage is invisible and every share on the sheet is wrong.
static func note_passive(tel: Dictionary, slot: int, skill: Dictionary) -> void:
	if slot < 0 or slot >= tel.per.size():
		return
	tel.per[slot].shape = skill.shape
	tel.per[slot].element = skill.element


static func note_cast(tel: Dictionary, slot: int, skill: Dictionary) -> void:
	if slot < 0:
		tel.basic.casts += 1
		return
	if slot >= tel.per.size():
		return
	tel.per[slot].casts += 1
	tel.per[slot].shape = skill.get("shape", "")
	tel.per[slot].element = skill.get("element", "")


static func note_damage(tel: Dictionary, slot: int, amount: float, killed: bool) -> void:
	var bucket: Dictionary
	if slot == -3:
		bucket = tel.allies
	elif slot == -2:
		bucket = tel.deck
	elif slot < 0:
		bucket = tel.basic
	elif slot < tel.per.size():
		bucket = tel.per[slot]
	else:
		return
	bucket.damage += amount
	if bucket.has("hits"):
		bucket.hits += 1
	if killed:
		bucket.kills += 1


static func note_range(tel: Dictionary, delta: float, distance: float, close_range: float) -> void:
	if distance < 0.0:
		tel.range_time.none += delta
	elif distance <= close_range:
		tel.range_time.close += delta
	elif distance <= close_range * 2.6:
		tel.range_time.mid += delta
	else:
		tel.range_time.far += delta


## Share of the run's damage a slot is responsible for. With no data yet it
## returns an even split, so the first upgrade of a run is not biased by noise.
static func share(tel: Dictionary, slot: int) -> float:
	var total := 0.0
	for row in tel.per:
		total += row.damage
	if total < 200.0 or slot < 0 or slot >= tel.per.size():
		return 0.25
	return tel.per[slot].damage / total


## How much the player LEANS on a slot: damage share and press count, mixed.
## Casts matter on their own because a slow, heavy, rarely-pressed skill and a
## spammed one with the same total damage are not the same thing to upgrade.
static func use(tel: Dictionary, slot: int) -> float:
	var casts_total := 0
	for row in tel.per:
		casts_total += row.casts
	var cast_share := 0.25
	if casts_total >= 12 and slot >= 0 and slot < tel.per.size():
		cast_share = float(tel.per[slot].casts) / float(casts_total)
	return 0.5 * share(tel, slot) + 0.5 * cast_share
