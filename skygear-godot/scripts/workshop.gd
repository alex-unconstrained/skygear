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
	## QUARTERMASTER AND FORESIGHT ARE NOT HERE, and the design lists both.
	##
	## Quartermaster — "the opening draft always holds a new skill" — is a no-op
	## against the draft as built: below four skills `open_draft` offers ONLY
	## weapons, so the guarantee already holds and buying it would change nothing.
	## Foresight — "one card of each draft, shown a wave early" — needs the next
	## draft pre-rolled without disturbing the seeded stream, which is real work
	## and not started.
	##
	## Shipping either as a table entry with no reader is the exact trap that put
	## thirteen inert fields in the previous commit. `shop · every talent field is
	## read by something` now fails the build if one comes back unwired.
	"watch_bill": {"branch": "log", "tier": 1, "name": "Watch Bill",
		"text": "the lane readout counts who is still coming", "cost": 60,
		"ranks": 1, "field": "show_queue", "per": 1.0},
	"fourth_card": {"branch": "log", "tier": 2, "name": "Fourth Card",
		"text": "the opening draft offers four", "cost": 160, "ranks": 1,
		"field": "fourth_card", "per": 1.0},
}

## THE ARTICLES. Nine were designed; all nine are here now — The Opening Bid and
## The Second Hand arrived last (SG-26), and each carries its trade IN THE RUN
## rather than only on the price tag, because an Article that is nothing but a
## bonus is a stat node wearing a wax seal:
##
##   * THE OPENING BID opens the whole 32-cell matrix to every weapon draft —
##     you name the cell instead of taking the deal — and in exchange the bid is
##     final: no rerolls, all run, not even bought ones (Deep Pockets and SPARE
##     PARTS both defer to it). Certainty up front, zero flexibility after.
##   * THE SECOND HAND grants a fifth slot, and pays for it where it hurts: the
##     fifth weapon is dealt IN PLACE OF the draft that would have been your
##     first upgrade card, so the compounding half of the run starts a wave
##     late. And no fifth key exists — the keyed-Article rule against inventing
##     a binding nobody remembers holds here too — so the fifth hand takes only
##     the shapes that fight on their own (Field, Pulse).
##
## Sixteen sigils to own the nine against fewer in existence, so you can never
## have the whole side — which is the point. A meta layer you finish is a meta
## layer that stops being a decision.
##
## THREE MUTUAL EXCLUSIONS. Brace and Recall answer the two things the game has
## no answer for — the hit you saw coming, and the lane that broke on the far
## side of the deck — and owning both would make `F` a context-sensitive guess.
## Same key, different game. The Bid and the Second Hand exclude each other for
## a different reason: one narrows the run to a plan and the other widens it to
## a wave more of dealing, and a captain who owned both would have bought back
## the flexibility the Bid is priced on.
##
## THE BOILERWRIGHT CANNOT TAKE THE KEYED ONES. His `F` is Tap Main and his `V`
## is Blowdown; they are the class, not a binding. Rather than rebind his
## signature or invent a third key nobody will remember, the keyed Articles are
## the captain's. He gets the passives, and the Workshop says so on the node.
const ARTICLES := {
	"keel_hauling": {"name": "Keel Hauling", "cost": 1, "captain_only": true,
		"text": "your dash drags what it hits along",
		"field": "keel_hauling"},
	"press_gang": {"name": "Press-Gang", "cost": 1,
		"text": "close kills sometimes raise the body as a crewman",
		"field": "press_gang"},
	"brace": {"name": "Brace", "cost": 1, "key": "F", "captain_only": true,
		"excludes": "recall",
		"text": "F · 0.35s untouchable, 18s",
		"field": "brace"},
	"recall": {"name": "Recall", "cost": 2, "key": "F", "captain_only": true,
		"excludes": "brace",
		"text": "F · back to the Boiler at once, 45s",
		"field": "recall"},
	"scuttle": {"name": "Scuttle", "cost": 2, "key": "V", "captain_only": true,
		"text": "V · every keg on the deck at once, once a wave",
		"field": "scuttle"},
	"second_shift": {"name": "Second Shift", "cost": 2,
		"text": "the first killing blow leaves you at 1, once a run",
		"field": "second_shift"},
	"deadmans_switch": {"name": "Deadman's Switch", "cost": 2,
		"text": "below a quarter the Boiler vents itself, once a wave",
		"field": "deadmans_switch"},
	"opening_bid": {"name": "The Opening Bid", "cost": 2,
		"excludes": "second_hand",
		"text": "name your weapons from the open matrix — no rerolls, ever",
		"field": "opening_bid"},
	"second_hand": {"name": "The Second Hand", "cost": 3,
		"excludes": "opening_bid",
		"text": "a fifth hand that fights alone, dealt in place of your first card",
		"field": "second_hand"},
}


static func owns(state: Dictionary, id: String) -> bool:
	return bool((state.get("bought_articles", {}) as Dictionary).get(id, false))


## Sigils are spent, not held: `sigils` is the running balance and every purchase
## is permanent. There is no refund, deliberately — scrip buys experiments and
## sigils buy commitments, and a side you can respec is not a commitment.
static func can_take(state: Dictionary, id: String) -> bool:
	if not ARTICLES.has(id) or not bool(state.unlocked) or owns(state, id):
		return false
	var article: Dictionary = ARTICLES[id]
	if article.has("excludes") and owns(state, str(article.excludes)):
		return false
	return int(state.sigils) >= int(article.cost)


static func take(state: Dictionary, id: String) -> bool:
	if not can_take(state, id):
		return false
	state.sigils = int(state.sigils) - int(ARTICLES[id].cost)
	if not state.has("bought_articles"):
		state["bought_articles"] = {}
	(state.bought_articles as Dictionary)[id] = true
	save_state(state)
	return true


## Which Articles are live for this class. Kept here rather than at the call
## site, so "the Boilerwright cannot Brace" is stated once.
static func articles_for(state: Dictionary, class_id: String) -> Dictionary:
	var out := {}
	for id in ARTICLES.keys():
		if not owns(state, id):
			continue
		if bool(ARTICLES[id].get("captain_only", false)) and class_id != "captain":
			continue
		out[str(ARTICLES[id].field)] = true
	return out


## HEAT. A permanently stronger captain makes twelve waves permanently easier,
## and the answer is not to take the power back — it is an earned, opt-in,
## per-run difficulty chosen at the title, unlocked by the same first victory
## that opens the tree.
##
## So there is exactly ONE difficulty until you have beaten the game, and every
## balance claim the harness makes is against that one. That is the property
## worth having: a moving baseline makes every check in this project ambiguous.
##
## REJECTED: scaling enemies to talent points spent. It removes exactly what it
## grants, makes buying a talent ambiguous, and hands the harness a target that
## moves whenever the player shops.
##
## Each step is one NAMED modifier rather than a multiplier, because "Rust" is
## something a player can hold in their head and "difficulty 3" is not.
##
## THE STACK IS CUMULATIVE, AND IT SAYS SO IN THE DATA. A rung is not "the one
## new thing at this level" — it is the whole set of modifiers that are live at
## it, its own plus every rung below, re-listed. That is why Heat 5 carries
## `hp_scaling` even though Heat 1 introduced it: the reader for any field asks
## ONE rung, `heat_data(level)`, and gets the complete answer, so nothing has to
## walk the ladder adding things up and there is no second place for the sum to
## disagree with itself (failure mode two). The harness proves the re-listing is
## monotone — each rung at least as hard as the one below, on every field — so a
## rung that forgot to carry a lower modifier fails the build rather than
## silently making a high Heat easier than a low one.
##
## Each blurb is ONE sentence a player reads before committing the run, and 2–5
## open with "and" because that is what cumulative reads like out loud: Rust,
## and Short Fuse on top of it, and Cold Deck on top of that.
const HEAT := [
	{"name": "STOKED", "blurb": "the deck as it was built."},
	{"name": "RUST", "blurb": "boarders harden faster — wave 12 at twice their opening health.",
		"hp_scaling": 0.09},
	{"name": "SHORT FUSE", "blurb": "and they wind up 15% quicker. Still readable, but only just.",
		"hp_scaling": 0.09, "windup": 0.85},
	{"name": "COLD DECK", "blurb": "and the draft deals two cards, not three, on one reroll instead of two.",
		"hp_scaling": 0.09, "windup": 0.85, "draft_offers": 2, "start_rerolls": 1},
	{"name": "BOARDERS ALOFT", "blurb": "and a hulk grapples on every second wave — 4, 6, 8 and 10, not only 4 and 8.",
		"hp_scaling": 0.09, "windup": 0.85, "draft_offers": 2, "start_rerolls": 1,
		"extra_pushes": [6, 10]},
	{"name": "SKELETON CREW", "blurb": "and you hold it alone — no crew musters, and the deck cannons start at half health.",
		"hp_scaling": 0.09, "windup": 0.85, "draft_offers": 2, "start_rerolls": 1,
		"extra_pushes": [6, 10], "no_muster": true, "turret_hp_scale": 0.5},
]

## THE DIRECTION OF EACH KNOB, so the harness can prove the ladder only ever
## gets harder and a rung never drops a modifier it inherited. `+1` means a
## bigger number is harder (scaling, extra pushes); `-1` means a smaller one is
## (windup, cards dealt, rerolls, cannon health); a `set` flag is a latch that,
## once true, may never go back to false. Kept beside the table it describes.
const HEAT_HARDER := {
	"hp_scaling": 1, "extra_pushes": 1, "no_muster": "set",
	"windup": -1, "draft_offers": -1, "start_rerolls": -1, "turret_hp_scale": -1,
}

## The scaling every run used before Heat existed, and the number Heat 0 must
## still be. A difficulty ladder whose bottom rung is not the shipped game is a
## rebalance wearing a ladder's clothes.
const BASE_HP_SCALING := 0.06


static func heat_data(level: int) -> Dictionary:
	return HEAT[clampi(level, 0, HEAT.size() - 1)]


static func hp_scaling_for(level: int) -> float:
	return float(heat_data(level).get("hp_scaling", BASE_HP_SCALING))


static func windup_for(level: int) -> float:
	return float(heat_data(level).get("windup", 1.0))


## COLD DECK · how many cards the draft is allowed to deal, capped against
## whatever it wanted to. Passed the base so a talent that WIDENS the draft
## (Fourth Card) is capped rather than overridden — Heat can only ever take a
## card away, never hand one back.
static func draft_offers_for(level: int, base: int) -> int:
	return mini(base, int(heat_data(level).get("draft_offers", base)))


## COLD DECK · rerolls you begin the run with, capped the same way. Talents add
## on top of what this returns, so the ladder sets the floor and the tree lifts
## off it.
static func start_rerolls_for(level: int, base: int) -> int:
	return mini(base, int(heat_data(level).get("start_rerolls", base)))


## BOARDERS ALOFT · does a hulk grapple on this wave? True if the wave carries a
## push in the data, OR if this Heat adds one. The one place the question is
## asked, so the three call sites in `game.gd` cannot drift apart.
static func pushes_on(level: int, wave_number: int, base_push: bool) -> bool:
	if base_push:
		return true
	return wave_number in (heat_data(level).get("extra_pushes", []) as Array)


## SKELETON CREW · whether your own crew still musters onto the lanes. Off at the
## top of the ladder — you hold the deck with what you brought.
static func musters(level: int) -> bool:
	return not bool(heat_data(level).get("no_muster", false))


## SKELETON CREW · what the deck cannons start with, as a fraction of their full
## health. 1.0 everywhere but the top rung, where they come up half-dead.
static func turret_hp_scale_for(level: int) -> float:
	return float(heat_data(level).get("turret_hp_scale", 1.0))


## You may pick any Heat up to one above your best clear, so the ladder is
## climbed rather than skipped — and never at all before the first victory.
##
## THIS FUNCTION IS THE PROGRESSION RULE AND IT NEVER MOVES. `heat_ceiling`
## below is what the UI is allowed to OFFER; this is what has been EARNED, and
## keeping them as two functions is the whole reason OPEN ALL HEATS can exist
## without the ladder quietly becoming decoration (board SG-160).
static func heat_available(state: Dictionary) -> int:
	if not bool(state.unlocked):
		return 0
	return mini(HEAT.size() - 1, int(state.best_heat) + 1)


## OPEN ALL HEATS (board SG-160, owner: *"if you're able to just unlock it so I
## can jump to any heat, that would be better for my testing"*). The highest rung
## the title screen may hand out — the earned one normally, the whole ladder when
## the settings sheet's bypass is on.
##
## A SETTING, NOT A SAVE FIELD. It lives in `user://settings.cfg` beside
## fullscreen and the volumes (`scripts/audio.gd`), never in `workshop.json`, so
## turning it on cannot touch, migrate or invalidate a single byte of what the
## player has earned — and `fresh()`'s key list stays the whole schema.
static func heat_ceiling(state: Dictionary, open_heats: bool) -> int:
	if open_heats:
		return HEAT.size() - 1
	return heat_available(state)


## Is this run being played above the rung its save has earned? The one place the
## question is asked — `bank()` reads it to decide the run pays nothing, and the
## HUD reads it to say so on the rung, on the ladder's strip and on the results
## sheet. Note it does NOT ask whether the bypass is switched on: a Heat 0 run
## with OPEN ALL HEATS enabled is not bypassed and banks exactly as it always
## has. What voids a run is where it was played, never which switches were set.
static func heat_bypassed(state: Dictionary, level: int) -> bool:
	return level > heat_available(state)


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
	## `articles` records which one-time FIRSTS have been claimed; the ones you
	## have BOUGHT are `bought_articles`. Two dictionaries because they answer
	## different questions and merging them once cost an afternoon.
	##
	## `fittings` is what the SHIP has earned and `berths` which of those it
	## sails with (board SG-56, `scripts/fittings.gd`) — the ship's side of the
	## same save, behind the same first-victory latch as everything else here.
	return {"unlocked": false, "scrip": 0, "sigils": 0, "spent_sigils": 0,
		"nodes": {}, "articles": {}, "bought_articles": {}, "seeds": [],
		"fittings": {}, "berths": [],
		"heat": 0, "best_heat": 0, "ephemeral": ephemeral}


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
	## MIGRATION, once — the wreck predates the berth system (SG-15 shipped it
	## gated on `unlocked` alone; SG-56 moved it into the berths). A save that
	## has already downed the Colossus keeps its trophy: the wreck's earn rule
	## IS the first victory, applied here retroactively. After this the
	## `fittings` dictionary carries the answer, so a wreck the player chooses
	## to UN-berth stays un-berthed across loads — the `has` check is the latch.
	if bool(out.unlocked) and not (out.fittings as Dictionary).has("wreck"):
		(out.fittings as Dictionary)["wreck"] = true
		if not SkyGearFittings.is_berthed(out, "wreck"):
			SkyGearFittings.berth(out, "wreck")
	## TABLED fittings (board SG-68): a save that berthed THE WINCH before the
	## crate-verb family was tabled un-berths it gracefully here — the fitting
	## stays EARNED, so nothing is lost the day the interaction pass lifts the
	## flag and it can be berthed again.
	SkyGearFittings.reconcile_tabled(out)
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
	## THE BYPASS PAYS NOTHING (board SG-160), and it is decided FIRST, against the
	## state as it stands on the way in — before the first-win latch below flips,
	## so a bypassed clear cannot open the Workshop by unlocking itself.
	##
	## THE DECISION, stated once so it is not ambiguous: a run played above the
	## rung you have earned banks NOTHING AT ALL — no scrip, no sigil, no fitting,
	## no `best_heat`, and it does not count as the first victory. Not "no heat
	## sigil" and the rest as usual: partial credit is what would make every
	## balance claim in this repo ambiguous, because "the tree was bought at Heat
	## 5" is not a sentence the harness can reason about, and because the ladder
	## has to stay a thing you CLIMB for other players. The switch buys the owner
	## a seat at any rung; it does not buy the save a shortcut. It also means the
	## bypass is unconditionally safe to leave on — the only thing it can do to a
	## save is nothing.
	if heat_bypassed(state, int(row.get("heat", 0))):
		return {"scrip": 0, "sigils": 0, "unlocked": bool(state.unlocked),
			"first_win": false, "fitting": "", "bypassed": true}
	## THE GATE. Nothing accrues before the first victory — not banked-and-hidden,
	## not retroactive. A player who has not won has no Workshop and no scrip,
	## and the run they just played was exactly the shipped game.
	if was_locked and not won:
		return {"scrip": 0, "sigils": 0, "unlocked": false, "first_win": false,
			"fitting": "", "bypassed": false}
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
	## And the rung is recorded, which is what opens the next one.
	if won:
		state.best_heat = maxi(int(state.best_heat), int(row.get("heat", 0)))
	## THE SHIP'S OWN PAY (board SG-56). At most one fitting per run, decided
	## here because this is already "the one place that knows the rule", from
	## the same row fields — and behind the same latch, which the first win
	## flipped just above, so the unlocking run keeps the wreck it earned.
	var kept := SkyGearFittings.award_in(state, row)
	save_state(state)
	return {"scrip": gained, "sigils": sigils, "unlocked": true,
		"first_win": was_locked, "fitting": kept, "bypassed": false}


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
	## A first clear at each rung pays a sigil — once, like every other sigil, so
	## the ladder is content rather than a farm. HEAT 5 IS THE EXCEPTION: it pays
	## only the record, never a sigil, so the top of the ladder cannot be climbed
	## FOR power. It is the one rung you take because you want to, and §5 of the
	## design is emphatic that the summit is not a reward.
	var at: int = int(row.get("heat", 0))
	if won and at > 0 and at < HEAT.size() - 1 and not had.has("heat_%d" % at):
		out.append("heat_%d" % at)
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
