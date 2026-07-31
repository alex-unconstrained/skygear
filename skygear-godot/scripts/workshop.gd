class_name SkyGearWorkshop
extends RefCounted

## What you keep between runs.
##
## `docs/META-PROGRESSION-DESIGN.md` is the argument; this is the machine. The
## short version of the argument is that `V10-PLAN.md` cut meta-progression as
## "a way to postpone the moment this game becomes excellent", that the park was
## correct when written, and that three things have since changed — the thing it
## postponed is built, the per-run tracking exists and is harness-covered, and
## winning produces a `DECK HELD` line and nothing else, which is a content gap
## at the TOP of the curve rather than a retention gap at the bottom.
##
## THREE HARD CONSTRAINTS, and the first is doing most of the work:
##
##  1. NONE OF THIS EXISTS UNTIL YOU HAVE WON. Not unlocked, not shown, not
##     earned. Every run up to your first `DECK HELD` is exactly the game that
##     ships today at today's numbers, pinned by the harness. That is not
##     decoration — it is what structurally forecloses the Rogue Legacy failure,
##     because you cannot be behind a curve that has not started.
##  2. No talent restores power removed from the baseline. If a talent ever looks
##     necessary, the baseline was wrong and the baseline gets fixed.
##  3. The whole Workshop, fully bought, is worth less than three draft cards.
##     The draft moves rates and multipliers DURING a run; the tree moves what
##     you begin with, plus flat capped amounts and out-of-combat information.
##     Talents front-load and decay across twelve waves; cards back-load and
##     compound. A check asserts it rather than trusting me.
##
## One JSON file in `user://`. Accounts, cloud saves, leaderboards and relics
## stay parked — the draft is already the relic system.

const PATH := "user://workshop.json"

## SCRIP comes from four fields `runlog.gd` already writes, so this adds no new
## tracking whatsoever. Quartered on a seed you have already played, because a
## currency you can farm by replaying your best seed is a currency that makes
## the run log a spreadsheet.
const SCRIP_PER_WAVE := 8
const SCRIP_FOR_WIN := 60
const SCRIP_PER_VENT := 1
const SCRIP_CLOSE_WEIGHT := 0.4
const REPEAT_SEED_SHARE := 0.25

## The nodes. `field` is what it moves and `per` is how much one rank moves it;
## `ranks` is how many times it can be bought and `cost` is per rank.
##
## FLAT AND CAPPED, never a multiplier, and never a card's exclusive — Fifth
## Gear, Residue, Twin Cast, the wide cone, pierce and chain jumps stay the
## draft's. A talent handing you an epic on run 1 deletes the best moment the
## game has.
const BRANCHES := ["kit", "gauge", "ship", "log"]
const BRANCH_NAMES := {
	"kit": "THE CAPTAIN'S KIT", "gauge": "THE GAUGE",
	"ship": "THE SHIP", "log": "THE LOG",
}

const NODES := {
	## A · what she carries.
	"bootblacking": {"branch": "kit", "tier": 0, "name": "Bootblacking",
		"text": "+4% move speed", "cost": 40, "ranks": 2,
		"field": "move_speed", "per": 0.04},
	"padded_coat": {"branch": "kit", "tier": 0, "name": "Padded Coat",
		"text": "+8 max health", "cost": 40, "ranks": 3,
		"field": "max_hp", "per": 8.0},
	"sea_legs": {"branch": "kit", "tier": 1, "name": "Sea Legs",
		"text": "dash recharges 0.08s sooner", "cost": 40, "ranks": 2,
		"field": "dash_recharge", "per": -0.08},
	"deep_pockets": {"branch": "kit", "tier": 1, "name": "Deep Pockets",
		"text": "+1 reroll at the start of a run", "cost": 60, "ranks": 2,
		"field": "rerolls", "per": 1.0},
	"steady_hand": {"branch": "kit", "tier": 1, "name": "Steady Hand",
		"text": "+3% critical chance", "cost": 60, "ranks": 2,
		"field": "crit_chance", "per": 0.03},
	"long_arms": {"branch": "kit", "tier": 2, "name": "Long Arms",
		"text": "+5% range on every skill", "cost": 100, "ranks": 2,
		"field": "range", "per": 0.05},
	"wound_kit": {"branch": "kit", "tier": 2, "name": "Wound Kit",
		"text": "restore 6 health at each wave start", "cost": 100, "ranks": 1,
		"field": "wave_heal", "per": 6.0},

	## B · the gauge.
	"hair_spring": {"branch": "gauge", "tier": 0, "name": "Hair Spring",
		"text": "+6% pressure gain", "cost": 40, "ranks": 2,
		"field": "pressure_rate", "per": 0.06},
	"salvager": {"branch": "gauge", "tier": 0, "name": "Salvager",
		"text": "salvage heals +2", "cost": 40, "ranks": 2,
		"field": "salvage_heal", "per": 2.0},
	"relief_valve": {"branch": "gauge", "tier": 1, "name": "Relief Valve",
		"text": "venting heals +2", "cost": 60, "ranks": 2,
		"field": "vent_heal", "per": 2.0},
	"wide_blow": {"branch": "gauge", "tier": 1, "name": "Wide Blow",
		"text": "+6% vent radius", "cost": 60, "ranks": 2,
		"field": "vent_radius", "per": 0.06},
	"cold_start": {"branch": "gauge", "tier": 2, "name": "Cold Start",
		"text": "begin each wave at 15 pressure", "cost": 100, "ranks": 1,
		"field": "wave_pressure", "per": 15.0},

	## C · the ship. The only branch that touches something you can lose.
	"shot_locker": {"branch": "ship", "tier": 0, "name": "Shot Locker",
		"text": "+15% cannon health", "cost": 40, "ranks": 2,
		"field": "turret_hp", "per": 0.15},
	"spare_plate": {"branch": "ship", "tier": 0, "name": "Spare Plate",
		"text": "+60 Boiler max health", "cost": 60, "ranks": 3,
		"field": "boiler_hp", "per": 60.0},
	"gun_crew": {"branch": "ship", "tier": 1, "name": "Gun Crew",
		"text": "cannons fire 8% faster", "cost": 60, "ranks": 2,
		"field": "turret_rate", "per": 0.08},
	"rivet_gun": {"branch": "ship", "tier": 2, "name": "Rivet Gun",
		"text": "the Boiler repairs 25 between waves", "cost": 100, "ranks": 2,
		"field": "boiler_repair", "per": 25.0},
	"powder_store": {"branch": "ship", "tier": 2, "name": "Powder Store",
		"text": "one extra keg stowed each wave", "cost": 100, "ranks": 1,
		"field": "extra_kegs", "per": 1.0},
	"muster_roll": {"branch": "ship", "tier": 2, "name": "Muster Roll",
		"text": "one extra crewman per wave", "cost": 160, "ranks": 1,
		"field": "extra_crew", "per": 1.0},

	## D · information. THE BEST BRANCH, and the strongest argument for building
	## any of this: these widen the draft rather than replace it.
	"manifest": {"branch": "log", "tier": 0, "name": "Manifest",
		"text": "the next wave's make-up, shown during the draft", "cost": 40,
		"ranks": 1, "field": "show_manifest", "per": 1.0},
	"tally": {"branch": "log", "tier": 0, "name": "Tally",
		"text": "enemy health bars carry numbers", "cost": 40, "ranks": 1,
		"field": "show_numbers", "per": 1.0},
	"ledger": {"branch": "log", "tier": 1, "name": "Ledger",
		"text": "results shown against your best three", "cost": 40, "ranks": 1,
		"field": "show_ledger", "per": 1.0},
	"quartermaster": {"branch": "log", "tier": 1, "name": "Quartermaster",
		"text": "the opening draft always holds a new skill", "cost": 60,
		"ranks": 1, "field": "opening_skill", "per": 1.0},
	"foresight": {"branch": "log", "tier": 2, "name": "Foresight",
		"text": "one card of each draft, shown a wave early", "cost": 100,
		"ranks": 1, "field": "foresight", "per": 1.0},
	"fourth_card": {"branch": "log", "tier": 2, "name": "Fourth Card",
		"text": "the opening draft offers four", "cost": 160, "ranks": 1,
		"field": "fourth_card", "per": 1.0},
}

## A tier opens once two nodes in its branch are bought. Gating on COUNT rather
## than on specific parents keeps the tree a shape you can read off a screen
## instead of a graph you have to trace.
const TIER_STEP := 2


## `ephemeral` is the harness's. Every mutation here writes to disk, which is
## correct for a player and catastrophic in a test — the parity run buys the
## entire tree four times over to check the balance claim, and without this it
## would hand a real player a maxed Workshop and wipe what they had earned.
## Opt-IN rather than opt-out, so a test that forgets it fails loudly by
## clobbering nothing rather than quietly by clobbering everything.
static func fresh(ephemeral: bool = false) -> Dictionary:
	return {"unlocked": false, "scrip": 0, "sigils": 0, "spent_sigils": 0,
		"nodes": {}, "articles": {}, "seeds": [], "heat": 0, "best_heat": 0,
		"ephemeral": ephemeral}


static func load_state() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return fresh()
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return fresh()
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is not Dictionary:
		return fresh()
	## Merged onto a fresh state rather than used raw, so a file written by an
	## older build is missing keys rather than fatal.
	var out := fresh()
	for key in out.keys():
		if parsed.has(key):
			out[key] = parsed[key]
	out.ephemeral = false
	return out


static func save_state(state: Dictionary) -> bool:
	if bool(state.get("ephemeral", false)):
		return true
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(state))
	f.close()
	return true


## What a finished run is worth. Four fields the run log already writes.
static func scrip_for(row: Dictionary, seen_seed: bool) -> int:
	var earned: float = SCRIP_PER_WAVE * int(row.get("wave", 0))
	if bool(row.get("won", false)):
		earned += SCRIP_FOR_WIN
	earned += SCRIP_PER_VENT * int(row.get("vents", 0))
	earned += SCRIP_CLOSE_WEIGHT * float(row.get("close_share", 0))
	if seen_seed:
		earned *= REPEAT_SEED_SHARE
	return maxi(0, roundi(earned))


## Bank a finished run. Returns what changed, so the results screen can say so
## rather than the player discovering it two screens later.
static func bank(state: Dictionary, row: Dictionary) -> Dictionary:
	var won: bool = bool(row.get("won", false))
	var was_locked: bool = not bool(state.unlocked)
	## THE GATE. Nothing accrues before the first victory — not banked-and-hidden,
	## not retroactive. A player who has not won has no Workshop and no scrip,
	## and the run they just played was exactly the shipped game.
	if was_locked and not won:
		return {"scrip": 0, "sigils": 0, "unlocked": false, "first_win": false}
	if was_locked:
		state.unlocked = true

	var seed_text := str(row.get("seed", ""))
	var seen: bool = seed_text != "" and seed_text in (state.seeds as Array)
	var gained := scrip_for(row, seen)
	state.scrip = int(state.scrip) + gained
	if seed_text != "" and not seen:
		(state.seeds as Array).append(seed_text)

	## SIGILS COME ONLY FROM FIRSTS, so the impactful currency is unfarmable by
	## construction. A scrip grind is a slow afternoon; a sigil grind would be
	## the game asking you to replay content you have finished.
	var sigils := 0
	for first in firsts_in(state, row):
		(state.articles as Dictionary)[first] = true
		sigils += 1
	state.sigils = int(state.sigils) + sigils
	save_state(state)
	return {"scrip": gained, "sigils": sigils, "unlocked": true,
		"first_win": was_locked}


## Which one-time achievements this run completed. Named `firsts` because that is
## exactly what they are — each can happen once, ever.
static func firsts_in(state: Dictionary, row: Dictionary) -> Array[String]:
	var had: Dictionary = state.articles
	var out: Array[String] = []
	var won: bool = bool(row.get("won", false))
	if won and not had.has("first_win"):
		out.append("first_win")
	if won and str(row.get("class_id", "captain")) == "boilerwright" 			and not had.has("win_boilerwright"):
		out.append("win_boilerwright")
	if int(row.get("wave", 0)) >= 8 and not had.has("reach_eight"):
		out.append("reach_eight")
	if won and int(row.get("close_share", 0)) >= 60 and not had.has("won_close"):
		out.append("won_close")
	if won and int(row.get("healed", 0)) <= 0 and not had.has("won_unhealed"):
		out.append("won_unhealed")
	return out


## --- reading a bought tree ----------------------------------------------------

static func rank(state: Dictionary, id: String) -> int:
	return int((state.nodes as Dictionary).get(id, 0))


## How many nodes have been bought in a branch, for the tier gate.
static func bought_in(state: Dictionary, branch: String) -> int:
	var n := 0
	for id in NODES.keys():
		if str(NODES[id].branch) == branch and rank(state, id) > 0:
			n += 1
	return n


static func tier_open(state: Dictionary, branch: String, tier: int) -> bool:
	return bought_in(state, branch) >= tier * TIER_STEP


static func can_buy(state: Dictionary, id: String) -> bool:
	if not NODES.has(id) or not bool(state.unlocked):
		return false
	var node: Dictionary = NODES[id]
	if rank(state, id) >= int(node.ranks):
		return false
	if not tier_open(state, str(node.branch), int(node.tier)):
		return false
	return int(state.scrip) >= int(node.cost)


static func buy(state: Dictionary, id: String) -> bool:
	if not can_buy(state, id):
		return false
	state.scrip = int(state.scrip) - int(NODES[id].cost)
	(state.nodes as Dictionary)[id] = rank(state, id) + 1
	save_state(state)
	return true


## FREE, and never mid-run. Charging for a respec taxes experimenting, which is
## the only thing a tree this small has to offer; forbidding it mid-run is what
## stops it being a fifth ability button.
static func respec(state: Dictionary) -> void:
	var refund := 0
	for id in (state.nodes as Dictionary).keys():
		refund += int(NODES[id].cost) * int(state.nodes[id])
	state.scrip = int(state.scrip) + refund
	state.nodes = {}
	save_state(state)


## Everything the tree grants, resolved into one flat dictionary. The game reads
## this once at the start of a run and never again — a talent that could change
## mid-run would be a card, and cards are the draft's job.
static func resolved(state: Dictionary) -> Dictionary:
	var out := {}
	for id in NODES.keys():
		var have := rank(state, id)
		if have <= 0:
			continue
		var node: Dictionary = NODES[id]
		var field := str(node.field)
		out[field] = float(out.get(field, 0.0)) + float(node.per) * have
	return out
