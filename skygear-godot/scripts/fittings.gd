class_name SkyGearFittings
extends RefCounted

## THE REFIT LAYER — what the SHIP keeps between runs (board SG-56).
##
## `docs/SHIP-AND-MAPS-DESIGN.md` §5 is the argument and the owner's midnight
## direction (docs/OUTSTANDING.md, 2026-08-02 00:30) is the frame: *"the ship
## itself shouldn't change during the playthrough … ship modification should
## happen in between runs. As you complete all twelve waves, you would want to
## see modifications and changes and upgrades that can be made to the ship
## itself."* So a fitting applies its deck change ONCE, at run start, from the
## berthed set chosen between runs — `SkyGearGame.begin_run` snapshots the set
## into `run_fittings` and nothing after that moment reads this state again.
## Berthing mid-run is not an error; it is simply next run's ship. Pinned by
## `fittings · the ship never changes mid-run — a berth signed mid-run waits
## for the next run`.
##
## THE HARD RULE, verbatim from the design and the plan, and enforced by
## `fittings · no fitting names a forbidden field`:
##
##   **No fitting touches `mods`, `player`, a starting value, or any
##   `SkyGearWorkshop.NODES` field. A fitting may only change the DECK
##   (props, walls, a landmark, a turret emplacement) or the deckwork
##   VERB TABLE.**
##
## If a ship upgrade can be expressed as a number, it is a Workshop talent and
## it goes in the Workshop. That is what keeps this from becoming a second
## Workshop with a different noun.
##
## EARNED, NEVER BOUGHT. At the end of a run the ship keeps AT MOST ONE
## fitting, decided in `SkyGearWorkshop.bank()` — the one place that already
## knows the meta-progression rule — from fields the run row already records
## (`won`, `wave`, `heat`, `class_id`, `healed`, `salvage`). No new tracking,
## no third currency, and nothing before the first victory: `award_for`
## refuses while `state.unlocked` is false, the same latch as everything else.
##
## SIX BERTHS. You own every fitting you have earned; you sail with six.
## A fitting berths itself when earned if there is room (the shipped wreck's
## behaviour, kept), and un-berthing is free, between runs, on the berth
## screen. The cap is what stops a deck that only ever gains cover from
## getting easier every run — the Rogue Legacy failure through a side door.
##
## This file deliberately does NOT reference `SkyGearWorkshop` (the workshop
## references us for the award, and a cycle between two `class_name` scripts
## is a load-order bug waiting for a stale cache). Mutators here change the
## state dictionary only; whoever owns persistence saves it.

const CAP := 6

## The first set. Keys are limited to the allowlist the harness enforces:
##   name    the object, as the berth screen says it
##   text    what berthing it changes on the deck, one sentence
##   earn    the rule, as the padlock states it on hover
##   props   deck geometry placed by `restow_props` every wave of the run
##   wall    a closed cross-passage — clamps the CAPTAIN only, never enemies
##   turret  a fourth deck cannon (built by `spare_gun_turret`)
##   verb    an entry in the deckwork verb table this fitting switches on
##
## Table order is award order: a run that satisfies several rules keeps the
## first unowned one, so the trophy comes before the toolkit.
const FITTINGS := {
	"wreck": {
		"name": "THE WRECK",
		"text": "the Colossus's corpse rides off the bow — the trophy the establishing crane frames",
		"earn": "hold the deck: bring the Colossus down",
	},
	"bow_barricade": {
		"name": "BOW BARRICADE",
		"text": "a fixed crate line across the bow of the middle lane — cover where the boarders land",
		"earn": "hold both boarding actions in one run: clear wave 8",
		"props": [
			{"type": "crates", "position": Vector2(-110.0, -940.0)},
			{"type": "crates", "position": Vector2(110.0, -940.0)},
		],
	},
	"spare_gun": {
		"name": "SPARE GUN",
		"text": "a fourth deck cannon on the stern line of the middle lane — shipped broken; repair it and it fires",
		"earn": "win at Heat 1 or above",
		"turret": true,
	},
	"fourth_vent": {
		"name": "FOURTH VENT",
		"text": "one more steam vent, standing in the bow cross-passage on the port side",
		"earn": "hold the deck as the Boilerwright",
		"props": [
			{"type": "vent", "position": Vector2(-280.0, -470.0)},
		],
	},
	## TABLED (board SG-68) — see `tabled()` below: while the crate-verb family
	## is down this row is unearnable, unberthable and never sails; it stays in
	## the table so THE BERTHS can say "TABLED" rather than making it vanish,
	## and so an already-earned one survives in saves for the revisit.
	"winch": {
		"name": "THE WINCH",
		"text": "grants a deck verb: tap to winch the nearest crate stack toward you — place your own cover",
		"earn": "gather 12 salvage in one run",
		"verb": "winch_crate",
	},
	"scupper_grating": {
		"name": "SCUPPER GRATING",
		"text": "seals the stern cross-passage to port and stands a vent on the grating — a cost with a benefit",
		"earn": "hold the deck without healing",
		"props": [
			{"type": "vent", "position": Vector2(-280.0, 515.0)},
		],
		## Fills the port stern crossing (y 410..620 between the cargo runs at
		## x -340..-220). The CAPTAIN clamps against it; boarders never see it —
		## it lives in the dead strip their lane clamp already forbids, and it is
		## deliberately NOT added to `cargo_rects()` (enemies provably untouched,
		## POST-PARITY-PLAN item 8's requirement).
		"wall": Rect2(-340.0, 410.0, 120.0, 210.0),
	},
}


## --- the tabled family ----------------------------------------------------------

## TABLED (board SG-68). The owner, 2026-08-02: "the current push crate
## mechanic is boring. table that feature for now we can revisit interactions
## like that later." A fitting whose whole grant is a crate verb would grant
## NOTHING while the family is down — a fitting that grants nothing is a lie —
## so THE WINCH is UNAVAILABLE while tabled: its award rule is skipped (the
## next rule in table order takes its place), it refuses to berth, it never
## sails, and the berth screen says TABLED instead of making it vanish. The
## answer is read from the VERB TABLE itself — a fitting is tabled exactly
## when the verb it grants has left `SkyGearDeckwork.actions()` — so this can
## never disagree with what the deck actually offers (STATUS failure mode
## two), and lifting `SkyGearGame.CRATE_VERBS_ENABLED` restores the fitting
## and the verb in the same breath. An EARNED winch stays earned throughout:
## nothing is lost when the interaction pass brings it back.
static func tabled(id: String) -> bool:
	var verb := str((FITTINGS.get(str(id), {}) as Dictionary).get("verb", ""))
	if verb == "":
		return false
	for spec in SkyGearDeckwork.actions():
		if str(spec.id) == verb:
			return false
	return true


## Un-berth every tabled fitting, keeping it EARNED — the graceful exit for a
## save that berthed the winch before the tabling. Called by
## `SkyGearWorkshop.load_state` (the file's one migration point); reports
## whether anything moved so a caller could save. Idempotent.
static func reconcile_tabled(state: Dictionary) -> bool:
	var changed := false
	for id in berthed_ids(state).duplicate():
		if tabled(str(id)):
			(state.berths as Array).erase(id)
			changed = true
	return changed


## --- reading the state --------------------------------------------------------

static func earned(state: Dictionary, id: String) -> bool:
	return bool((state.get("fittings", {}) as Dictionary).get(id, false))


static func berthed_ids(state: Dictionary) -> Array:
	return state.get("berths", []) as Array


static func is_berthed(state: Dictionary, id: String) -> bool:
	return str(id) in berthed_ids(state)


static func earned_count(state: Dictionary) -> int:
	var n := 0
	for id in FITTINGS.keys():
		if earned(state, str(id)):
			n += 1
	return n


## --- berthing -------------------------------------------------------------------

static func can_berth(state: Dictionary, id: String) -> bool:
	if not FITTINGS.has(id) or not bool(state.get("unlocked", false)):
		return false
	## A tabled fitting refuses the berth — it would grant a dead verb (SG-68).
	if tabled(id):
		return false
	if not earned(state, id) or is_berthed(state, id):
		return false
	return berthed_ids(state).size() < CAP


## Mutates the state and reports; the caller saves (see the header).
static func berth(state: Dictionary, id: String) -> bool:
	if not can_berth(state, id):
		return false
	(state.berths as Array).append(id)
	return true


static func unberth(state: Dictionary, id: String) -> bool:
	if not is_berthed(state, id):
		return false
	(state.berths as Array).erase(id)
	return true


## --- the award ------------------------------------------------------------------

## Which fitting this run earned, or "". AT MOST ONE per run — the first
## unowned rule the row satisfies, in table order — and nothing while the
## Workshop itself is locked (`bank()` flips the latch on the first win BEFORE
## asking, so the unlocking run keeps the wreck it just earned).
static func award_for(state: Dictionary, row: Dictionary) -> String:
	if not bool(state.get("unlocked", false)):
		return ""
	var won := bool(row.get("won", false))
	for id in FITTINGS.keys():
		if earned(state, str(id)):
			continue
		## A tabled fitting's award rule is SKIPPED (SG-68) — the next rule in
		## table order takes its place, exactly as if the row were already owned.
		if tabled(str(id)):
			continue
		if _rule_met(str(id), row, won):
			return str(id)
	return ""


## The rules, adapted from SHIP-AND-MAPS §5 to the fields the run row already
## records (the design's cannon-loss and repair-count rules named data no row
## carries; the reframe's constraint is NO NEW TRACKING, so those two read
## from `wave` and `salvage` instead — the board row records the mapping).
static func _rule_met(id: String, row: Dictionary, won: bool) -> bool:
	match id:
		"wreck":
			## §5 as written: kill the Colossus. A win IS a wave-12 Colossus kill.
			return won
		"bow_barricade":
			## §5 said "hold both pushes without losing a cannon"; cannon losses
			## are not in the row. Both boarding actions grapple on waves 4 and 8,
			## so reaching wave 9 means both were held.
			return int(row.get("wave", 0)) >= 9
		"spare_gun":
			## §5 as written: win at Heat 1.
			return won and int(row.get("heat", 0)) >= 1
		"fourth_vent":
			## §5 as written: win as the Boilerwright. His prize.
			return won and str(row.get("class_id", "")) == "boilerwright"
		"winch":
			## §5 said "repair five cannons across a run"; repairs are not in the
			## row. The winch is deck labour, so it is earned by deck labour the
			## row does record: a run that hauled twelve salvage off the planking.
			return int(row.get("salvage", 0)) >= 12
		"scupper_grating":
			## §5 as written: win without healing.
			return won and int(row.get("healed", 1)) <= 0
	return false


## Decide, record, and self-berth while there is room. Called by
## `SkyGearWorkshop.bank()` before it saves, so the award rides the same write.
static func award_in(state: Dictionary, row: Dictionary) -> String:
	var id := award_for(state, row)
	if id == "":
		return ""
	if not state.has("fittings"):
		state["fittings"] = {}
	(state.fittings as Dictionary)[id] = true
	if not state.has("berths"):
		state["berths"] = []
	## Earned fittings berth themselves while there is room — the shipped
	## wreck's behaviour (it appeared the run after the first victory, unasked),
	## kept for the whole set. Un-berthing stays a free between-runs choice.
	berth(state, id)
	return id


## --- what a run sails with -------------------------------------------------------

## The validated berthed set `begin_run` snapshots: known ids, actually earned,
## deduplicated, capped, and empty before the first victory. Everything the
## simulation does with fittings reads the SNAPSHOT, never this state again.
static func sailing(state: Dictionary) -> Array:
	var out: Array = []
	if not bool(state.get("unlocked", false)):
		return out
	for id in berthed_ids(state):
		## A tabled fitting never sails (SG-68) — even out of a stale save
		## whose berths array still carries it.
		if tabled(str(id)):
			continue
		if FITTINGS.has(str(id)) and earned(state, str(id)) \
				and not out.has(str(id)) and out.size() < CAP:
			out.append(str(id))
	return out


## Deck geometry the berthed set adds, placed by `restow_props` beside the
## authored layout — every wave of the run, identically, which is what "the
## ship never changes mid-run" means on a deck that re-stows per wave.
static func deck_props(ids: Array) -> Array:
	var out: Array = []
	for id in ids:
		var entry: Dictionary = FITTINGS.get(str(id), {})
		var placed: Array = entry.get("props", [])
		for piece in placed:
			out.append(piece)
	return out


## Cross-passage closures the berthed set adds. Clamp the CAPTAIN only
## (`correct_player_position`); never in `cargo_rects()`, so boarders and the
## x-ray pass are provably untouched.
static func walls(ids: Array) -> Array:
	var out: Array = []
	for id in ids:
		var entry: Dictionary = FITTINGS.get(str(id), {})
		if entry.has("wall"):
			out.append(entry.wall)
	return out


## THE SPARE GUN's emplacement: lane 1 — the one lane that can hurt the Boiler
## — on the stern line between the main gun (0, 520) and the Boiler (0, 850).
## Ships DEAD at zero health, exactly as §5 wrote it: the repair verb that
## already exists is how it ever fires. `begin_run` applies Shot Locker and
## the Heat scale to `max_hp` after this, same as the other three.
static func spare_gun_turret() -> Dictionary:
	return {
		"lane": 1,
		"position": Vector2(0.0, 640.0),
		"hp": 0.0, "max_hp": SkyGearLanes.TURRET.hp,
		"cooldown": 0.0, "radius": SkyGearLanes.TURRET.radius,
		"angle": -PI * 0.5, "flash": 0.0, "fire_flash": 0.0,
		"dead": true, "spare": true,
	}
