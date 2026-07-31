class_name SkyGearCards
extends RefCounted

## The draft catalogue, ported from the browser build's CARDS table.
##
## Milestone 1 shipped three hardcoded upgrade cards, which meant the port had a
## combat loop but not the roguelite the combat loop exists to serve. This is the
## real list: forty-one cards across seven scopes, each one declaring what it can
## do, how much the draft should want to offer it, and what a concrete instance
## of it says and does.
##
## Structure matches the browser deliberately, because a difference that is not
## deliberate is a bug nobody will find:
##
##   id      stable identifier, same string as the browser card
##   rarity  common | rare | epic; drives the frame's metal on the card face
##   scope   which class of thing it touches; drives the word in the card's band
##           and the row of affected-skill glyphs under it
##   weight  how badly the draft wants to offer it right now, given the build
##   can     may it be offered at all
##   make    build a concrete instance: title, text, target slot, apply()
##
## `apply` receives the game and mutates it. Everything a card can touch lives in
## `game.mods`, `game.skills` or on the player, so a card is never allowed to
## reach into the simulation directly.

const SCOPE_NEW := "new"
const SCOPE_SKILL := "skill"
const SCOPE_ELEMENT := "element"
const SCOPE_CAPTAIN := "captain"
const SCOPE_SHIP := "ship"
const SCOPE_DECK := "deck"
const SCOPE_ALL := "all"
const SCOPE_META := "meta"

## SCOPE HAS NO COLOUR ANY MORE, and the table that gave it one is deleted
## rather than left unread.
##
## It had one — a per-scope hue for the band — and the opening draft painted
## its weapons by ELEMENT instead, so the same channel meant "this is a Frost
## weapon" on one screen and "this affects the Boiler" on the next. Reported
## as element and rarity and role having been lost, and the reason they were
## lost is that the one channel that carries a category at a glance was already
## spent on a fourth category the player had not asked to see.
##
## Scope keeps SCOPE_LABEL, which is a word, in the band where it always was.
## A word is the right shape for it: there are eight scopes and eight hues no
## one can learn, where CAPTAIN and THE BOILER need no learning at all.
const SCOPE_LABEL := {
	SCOPE_NEW: "NEW SKILL",
	SCOPE_SKILL: "SKILL UPGRADE",
	SCOPE_ELEMENT: "ELEMENT",
	SCOPE_CAPTAIN: "CAPTAIN",
	SCOPE_SHIP: "THE BOILER",
	SCOPE_DECK: "THE DECK",
	SCOPE_ALL: "EVERY SKILL",
	SCOPE_META: "THE DRAFT",
}

## Element a card is fixed to, where it is not chosen at roll time. Used for the
## affected-skill row: BRITTLE touches every Frost skill and nothing else.
const CARD_ELEMENT := {
	"burnDmg": "EMBER", "burnDur": "EMBER",
	"slowAmt": "FROST", "brittle": "FROST",
	"stun": "ARC",
	"knock": "STEAM", "scald": "STEAM",
}


## --- THE THREE THINGS A CARD IS ----------------------------------------------
##
## Reported: "the browser did a great job of visually colouring and marking card
## choices to convey the ELEMENT, RARITY, and ACTIVE/PASSIVE role. This feels
## lost." It was not faded, it was absent, and each one failed differently:
##
##   RARITY  `game.gd` writes `instance["rarity"]` on every drafted card and no
##           reader has ever existed. Three rarities in this file, none of them
##           on screen. Same shape of bug as the Workshop's unread talent
##           fields, which is why the harness now guards this one too.
##   ELEMENT the colour channel was already spent, and spent on two different
##           things: a drafted card was tinted by SCOPE and an opening-draft
##           weapon by ELEMENT, so the same channel meant two things depending
##           on which draft you were looking at. Worse than conveying neither.
##   ROLE    `SHAPES` marks AURA and PULSE `passive: true` and the card face
##           never said so. You could draft a Field and not learn until the
##           fight that it has no key.
##
## ONE AXIS PER CHANNEL, and each one resolved here so the card face, the audit
## and the harness cannot disagree:
##
##   element -> HUE. Everywhere, both drafts, and brass when a card has none —
##              a colour that means "Frost" on one card must not mean "affects
##              the Boiler" on the next.
##   rarity  -> METAL. Ring weight and corner rivets in a value ramp, because
##              hue is taken. Iron, brass, steel.
##   role    -> A WORD. It is binary and binary things read as a mark, not a
##              shade — and a shade cannot be read by someone who is colour-blind
##              while a word can.
##
## Every one of the three is ALSO written out in the tag row, because the test
## the player set is "can you tell them apart at a glance" and a glance that
## needs a legend is not a glance.
const RARITY_LOOK := {
	## Pewter rather than the dull brass it started as. The contrast pass measured
	## "COMMON" at 4.35 against the housing it is written on, which is under the
	## floor — a tier that means "unremarkable" still has to be a word you can
	## read, and this is still obviously the dullest of the three.
	"common": {"rank": 0, "name": "COMMON", "metal": Color("#b3a68f"),
		"ring": 0.0, "rivets": 0},
	"rare": {"rank": 1, "name": "RARE", "metal": Color("#e8c376"),
		"ring": 2.4, "rivets": 0},
	## Warm steel, not white. #f4eee1 at three pixels read as a SELECTION ring
	## rather than as a material, which is a different message and one the card
	## under the cursor is already using.
	"epic": {"rank": 2, "name": "EPIC", "metal": Color("#e4dac2"),
		"ring": 3.0, "rivets": 4},
}
const RARITY_DEFAULT := "common"


## What rarity this card is, always one of RARITY_LOOK. The opening draft hands
## out starting weapons and never set the field; defaulting here rather than at
## the one call site that noticed is the difference between a default and a
## coincidence.
static func rarity_of(card: Dictionary) -> String:
	var r := str(card.get("rarity", RARITY_DEFAULT))
	return r if RARITY_LOOK.has(r) else RARITY_DEFAULT


static func rarity_look(card: Dictionary) -> Dictionary:
	return RARITY_LOOK[rarity_of(card)]


## The element this card IS, or "" for the ones that are not about an element.
##
## Deliberately not "the element of the slot it happens to target": a card that
## makes slot 2 hit harder is a slot upgrade, and painting it Frost because slot
## 2 is Frost today is a lie the moment the player retunes it. `affects` reads
## this too, so the row of lit skill glyphs and the card's hue can never point at
## different things.
static func element_of(card: Dictionary) -> String:
	if str(card.get("kind", "")) == "skill" and card.has("skill"):
		return str((card.skill as Dictionary).get("element", ""))
	var direct := str(card.get("element", ""))
	if direct != "":
		return direct
	return str(CARD_ELEMENT.get(str(card.get("id", "")), ""))


## The hue of the card, which is its element's or brass. Brass is a real answer
## rather than a fallback: it says "this card is not about an element", and that
## is a thing a player needs to be able to see at a glance too.
const NO_ELEMENT := Color("#e8c376")


static func hue_of(card: Dictionary) -> Color:
	var e := element_of(card)
	return SkyGearData.ELEMENTS[e].color if SkyGearData.ELEMENTS.has(e) else NO_ELEMENT


## The element's name, or "NO ELEMENT". Written out next to the swatch, because
## the test is a glance and a glance at a colour alone fails for one man in
## twelve.
static func element_label(card: Dictionary) -> String:
	var e := element_of(card)
	if not SkyGearData.ELEMENTS.has(e):
		return "NO ELEMENT"
	return str(SkyGearData.ELEMENTS[e].name).to_upper()


## ACTIVE, PASSIVE, or "" when the card is not about a weapon at all. A Field and
## a Pulse fire by themselves; everything else waits for a key.
static func role_of(card: Dictionary) -> String:
	var shape := ""
	if str(card.get("kind", "")) == "skill" and card.has("skill"):
		shape = str((card.skill as Dictionary).get("shape", ""))
	elif card.has("shape"):
		shape = str(card.shape)
	if shape == "" or not SkyGearData.SHAPES.has(shape):
		return ""
	return "PASSIVE" if bool(SkyGearData.SHAPES[shape].get("passive", false)) \
		else "ACTIVE"


## WHAT WOULD THIS CARD ACTUALLY DO?
##
## The card face said "Ember Cleave hits harder" and left the player to guess by
## how much, against what it currently is. Both numbers exist; neither was shown.
## Reported against the browser in these words: it is not visually clear whether
## an upgrade enhances a skill you have or hands you a new one.
##
## Computed by RUNNING THE CARD, not by describing it. A hand-written blurb per
## card is forty-one chances to say 25% where the code says 20%, and the first
## one to drift is the one nobody notices. This applies the real `apply` to a
## copy of the state and diffs the result, so the preview cannot disagree with
## the effect — if it is wrong, the card is wrong.
##
## Safe because of what cards are allowed to touch: `mods`, `skills`, `rng`,
## `rerolls`, the boiler's two numbers, and four fields on the captain. The module
## docstring says a card may never reach into the simulation and the code holds
## to it, so a Dictionary carrying those is a complete stand-in — GDScript
## resolves `g.mods` against a Dictionary key, so `apply` runs unmodified and
## cannot tell the difference.
##
## The captain is a NODE, so it cannot be duplicated; the stand-in carries the
## four numbers cards move. `preview` swept the whole catalogue and found these
## by crashing on them, which is the only reliable way to find out what a
## forty-one-entry table of closures actually reaches for.
const PLAYER_FIELDS := ["hp", "max_hp", "dash_charges", "max_dash_charges"]
const PREVIEW_ROWS := 3


static func preview(game, card: Dictionary) -> Array:
	var apply = card.get("apply")
	if not (apply is Callable):
		return []

	## A DEEP copy. A shallow one shares the nested dictionaries `apply` mutates,
	## so previewing a card would silently apply it — the worst possible bug in a
	## function whose whole job is to not change anything.
	var sandbox := {
		"mods": game.mods.duplicate(true),
		"skills": game.skills.duplicate(true),
		"rng": game.rng,
		"rerolls": int(game.rerolls),
		"boiler_hp": float(game.boiler_hp),
		"boiler_max_hp": float(game.boiler_max_hp),
	}
	var captain := {}
	for field in PLAYER_FIELDS:
		captain[field] = game.player.get(field) if game.player != null else 0.0
	sandbox["player"] = captain
	var before_mult: float = float(game.damage_multiplier)
	sandbox["damage_multiplier"] = before_mult
	var before_skills: Array = game.skills

	## The RNG is shared rather than copied, so a card that rolls during `apply`
	## would advance the real stream and change the run. None do today; the guard
	## is that we restore the state afterwards.
	var rng_state: int = game.rng.state if game.rng != null else 0
	@warning_ignore("unsafe_call_argument")
	apply.call(sandbox)
	if game.rng != null:
		game.rng.state = rng_state

	var after_mult: float = float(sandbox.get("damage_multiplier", before_mult))
	var rows: Array = []

	## Per-skill, and only where something moved. A card that changes one number
	## on one skill should print one line, not a table of unchanged ones.
	var slots: Array = card.get("affects", [])
	if slots.is_empty():
		slots = range(before_skills.size())
	for i in slots:
		var index := int(i)
		if index < 0 or index >= before_skills.size() or index >= sandbox.skills.size():
			continue
		var was: Dictionary = game.stats_with(before_skills[index], game.mods, before_mult)
		var now: Dictionary = game.stats_with(sandbox.skills[index], sandbox.mods, after_mult)
		var name: String = SkyGearData.skill_name(before_skills[index])
		for field in [["damage", "dmg", 1.0, true], ["cooldown", "cd", 1.0, false],
				["range", "rng", 1.0, true], ["radius", "area", 1.0, true],
				["multi", "shots", 1.0, true], ["jumps", "jumps", 1.0, true],
				["pierce", "pierce", 1.0, true]]:
			var key := str(field[0])
			var a := float(was.get(key, 0.0))
			var b := float(now.get(key, 0.0))
			if absf(a - b) < 0.005:
				continue
			rows.append({"label": "%s %s" % [name, str(field[1])],
				"before": _num(a), "after": _num(b), "better": (b > a) == bool(field[3])})

	## And every global that moved, found by diffing rather than listed. A
	## whitelist means the next card to touch a new modifier previews as blank and
	## nobody notices for a month; a diff means a preview exists the moment the
	## card does.
	for key in game.mods.keys():
		var a = game.mods[key]
		var b = sandbox.mods.get(key)
		if a is Dictionary and b is Dictionary:
			## Per-element tables: BRITTLE moves Frost and nothing else, and
			## "elem_damage" as one line would have to lie about which.
			for sub in (a as Dictionary).keys():
				var ea := float((a as Dictionary)[sub])
				var eb := float((b as Dictionary).get(sub, ea))
				if absf(ea - eb) < 0.0005:
					continue
				rows.append(_row("%s %s" % [str(sub).to_lower(),
					_pretty(str(key))], ea, eb, _higher_is_better(str(key))))
			continue
		if not ((a is float or a is int) and (b is float or b is int)):
			continue
		if absf(float(a) - float(b)) < 0.0005:
			continue
		rows.append(_row(_pretty(str(key)), float(a), float(b),
			_higher_is_better(str(key)), str(key) in PLAIN_NUMBERS))

	if absf(float(sandbox.boiler_max_hp) - float(game.boiler_max_hp)) > 0.5:
		rows.append({"label": "Boiler HP", "before": _num(float(game.boiler_max_hp)),
			"after": _num(float(sandbox.boiler_max_hp)), "better": true})

	## The captain's own numbers, same rule: only the ones that moved.
	for pair in [["max_hp", "max health"], ["max_dash_charges", "dashes"]]:
		var field := str(pair[0])
		if game.player == null:
			break
		var a := float(game.player.get(field))
		var b := float(captain.get(field, a))
		if absf(a - b) < 0.005:
			continue
		rows.append({"label": str(pair[1]), "before": _num(a), "after": _num(b),
			"better": b > a})

	if int(sandbox.rerolls) != int(game.rerolls):
		rows.append({"label": "rerolls", "before": str(int(game.rerolls)),
			"after": str(int(sandbox.rerolls)), "better": true})

	## One line per thing. A dash card moves BOTH `mods.dash_charges` and the
	## captain's own `max_dash_charges` — the same fact stored twice — and printing
	## "dashes 2 -> 3" twice makes the preview look broken rather than thorough.
	var seen := {}
	var unique: Array = []
	for r in rows:
		var key := str(r.label)
		if seen.has(key):
			continue
		seen[key] = true
		unique.append(r)
	return unique


## Names a player would use. Anything not here falls back to the field name with
## its underscores knocked out, which is readable for `crit_chance` and honest
## about the ones nobody has bothered to name yet.
const MOD_NAMES := {
	"crit_chance": "crit", "crit_damage": "crit damage", "lifesteal": "lifesteal",
	"move_speed": "speed", "knock_multiplier": "knockback",
	"pressure_gain": "pressure", "salvage_rate": "salvage",
	"burn_damage": "burn", "burn_duration": "burn time",
	"slow_amount": "slow", "slow_damage": "damage vs slowed",
	"stun_chance": "stun", "scrap_chance": "scrap",
	"vent_radius": "vent size", "vent_heal": "vent heal", "vent_damage": "vent hit",
	"dash_charges": "dashes", "elem_damage": "damage", "elem_cooldown": "cooldown",
	"residue": "residue", "pierce": "pierce", "multi": "shots",
	"heal_on_kill": "heal per kill", "draft_size": "cards offered",
}

## The few where UP is worse. Everything else in `mods` is a bonus, so listing
## the exceptions is shorter and does not go stale when a bonus is added.
const LOWER_IS_BETTER := ["elem_cooldown", "cooldown"]

## Fields that are a COUNT or a flat AMOUNT rather than a scale. Without this
## `dash_charges` prints "2.00x -> 3.00x", which is two dashes becoming three
## dressed up as a multiplier, and `vent_heal` prints a heal of eight points as
## "8.00x". Both are numbers a player cannot act on.
const PLAIN_NUMBERS := ["dash_charges", "vent_heal", "vent_damage", "vent_radius",
	"draft_size", "pierce", "multi", "jumps", "heal_on_kill", "burn_duration"]


static func _pretty(key: String) -> String:
	return str(MOD_NAMES.get(key, key.replace("_", " ")))


static func _higher_is_better(key: String) -> bool:
	return not (key in LOWER_IS_BETTER)


## A percentage where the value reads as one, a multiplier where it does not.
## `crit_chance` at 0.15 is "15%"; `burn_damage` at 1.4 is "1.40x", and printing
## either in the other's clothes is a number a player cannot act on.
static func _row(label: String, a: float, b: float, up_is_good: bool,
		plain: bool = false) -> Dictionary:
	if plain:
		return {"label": label, "before": _num(a), "after": _num(b),
			"better": (b > a) == up_is_good}
	var as_percent: bool = maxf(absf(a), absf(b)) <= 1.001
	var before := ("%d%%" % roundi(a * 100.0)) if as_percent else ("%.2fx" % a)
	var after := ("%d%%" % roundi(b * 100.0)) if as_percent else ("%.2fx" % b)
	return {"label": label, "before": before, "after": after,
		"better": (b > a) == up_is_good}


static func _num(v: float) -> String:
	if absf(v - roundf(v)) < 0.005:
		return "%d" % roundi(v)
	return "%.2f" % v


static func fresh_mods() -> Dictionary:
	## Every global modifier a card can move, at its starting value. Mirrors
	## freshMods() in the browser core.
	return {
		"elem_damage": {"EMBER": 1.0, "FROST": 1.0, "ARC": 1.0, "STEAM": 1.0},
		"elem_cooldown": {"EMBER": 1.0, "FROST": 1.0, "ARC": 1.0, "STEAM": 1.0},
		"burn_damage": 1.0, "burn_duration": 0.0,
		"slow_amount": 0.40, "slow_damage": 0.0,
		"stun_chance": 0.20,
		"knock_multiplier": 1.0, "scald": 0.0,
		"crit_chance": 0.12, "crit_explode": 0.0,
		"move_multiplier": 1.0,
		"dash_cooldown_bonus": 0.0, "dash_charges": 2, "dash_damage": 30.0,
		"scrap_chance": 0.0, "lifesteal": 0.0,
		"pressure_rate": 1.0, "vent_heal": 0.0, "vent_damage": 1.0,
		"vent_radius": 1.0, "dressing": 0.0,
		"keg_damage": 1.0, "keg_safe": 0.0,
		"fifth_gear": false, "residue": 0.0, "kill_autofire": 0.0,
		"kill_explode": 0.0, "boiler_dr": 0.0,
	}


static func filled_slots(game) -> Array:
	var out: Array = []
	for i in game.skills.size():
		out.append(i)
	return out


## Does whoever is aboard have a dash at all? One place, because three cards ask
## and three copies of a class check is three chances for one to drift.
static func _has_dash(game) -> bool:
	return int(game.class_data().get("dashes", 2)) > 0


static func slots_where(game, predicate: Callable) -> Array:
	var out: Array = []
	for i in game.skills.size():
		if predicate.call(game.skills[i]):
			out.append(i)
	return out


static func has_element(game, element: String) -> bool:
	for skill in game.skills:
		if skill.element == element:
			return true
	return false


## Build weighting: the draft leans toward the colour you are already running,
## so committing to one element across several shapes is a build rather than a
## consolation prize.
static func element_tag(game, element: String) -> float:
	return 3.0 if has_element(game, element) else 0.45


static func catalogue() -> Array:
	var cards: Array = []

	# --- shape mods: one skill in one slot ---------------------------------
	cards.append({
		"id": "aoe", "rarity": "common", "scope": SCOPE_SKILL,
		"weight": func(_g): return 10.0,
		"can": func(g): return slots_where(g, func(sk): return sk.shape != "LINE_BURST" and sk.shape != "CHAIN").size() > 0,
		"make": func(g, pick_slot: Callable):
			var i: int = pick_slot.call(slots_where(g, func(sk): return sk.shape != "LINE_BURST" and sk.shape != "CHAIN"))
			return {"title": "WIDE BLAST", "slot": i,
				"text": "+35%% area on %s." % SkyGearData.skill_name(g.skills[i]),
				"apply": func(gg): gg.skills[i].mods.area *= 1.35},
	})
	cards.append({
		"id": "range", "rarity": "common", "scope": SCOPE_SKILL,
		"weight": func(_g): return 10.0,
		"can": func(g): return g.skills.size() > 0,
		"make": func(g, pick_slot: Callable):
			var i: int = pick_slot.call(filled_slots(g))
			return {"title": "LONG REACH", "slot": i,
				"text": "+30%% range on %s." % SkyGearData.skill_name(g.skills[i]),
				"apply": func(gg): gg.skills[i].mods.range *= 1.30},
	})
	cards.append({
		"id": "cd", "rarity": "common", "scope": SCOPE_SKILL,
		"weight": func(_g): return 12.0,
		"can": func(g): return g.skills.size() > 0,
		"make": func(g, pick_slot: Callable):
			var i: int = pick_slot.call(filled_slots(g))
			return {"title": "QUICK HANDS", "slot": i,
				"text": "-22%% cooldown on %s." % SkyGearData.skill_name(g.skills[i]),
				"apply": func(gg): gg.skills[i].mods.cooldown *= 0.78},
	})
	cards.append({
		"id": "dmg", "rarity": "common", "scope": SCOPE_SKILL,
		"weight": func(_g): return 12.0,
		"can": func(g): return g.skills.size() > 0,
		"make": func(g, pick_slot: Callable):
			var i: int = pick_slot.call(filled_slots(g))
			return {"title": "HEAVY HIT", "slot": i,
				"text": "+30%% damage on %s." % SkyGearData.skill_name(g.skills[i]),
				"apply": func(gg): gg.skills[i].mods.damage *= 1.30},
	})
	cards.append({
		"id": "pierce", "rarity": "rare", "scope": SCOPE_SKILL,
		"weight": func(g): return 9.0 if slots_where(g, func(sk): return sk.shape == "LINE_BURST").size() > 0 else 0.0,
		"can": func(g): return slots_where(g, func(sk): return sk.shape == "LINE_BURST").size() > 0,
		"make": func(g, pick_slot: Callable):
			var i: int = pick_slot.call(slots_where(g, func(sk): return sk.shape == "LINE_BURST"))
			return {"title": "PUNCH THROUGH", "slot": i,
				"text": "+2 targets pierced on %s." % SkyGearData.skill_name(g.skills[i]),
				"apply": func(gg): gg.skills[i].mods.pierce += 2},
	})
	cards.append({
		"id": "jump", "rarity": "rare", "scope": SCOPE_SKILL,
		"weight": func(g): return 9.0 if slots_where(g, func(sk): return sk.shape == "CHAIN").size() > 0 else 0.0,
		"can": func(g): return slots_where(g, func(sk): return sk.shape == "CHAIN").size() > 0,
		"make": func(g, pick_slot: Callable):
			var i: int = pick_slot.call(slots_where(g, func(sk): return sk.shape == "CHAIN"))
			return {"title": "FORKED CURRENT", "slot": i,
				"text": "+1 chain jump on %s." % SkyGearData.skill_name(g.skills[i]),
				"apply": func(gg): gg.skills[i].mods.jumps += 1},
	})
	cards.append({
		"id": "widecone", "rarity": "rare", "scope": SCOPE_SKILL,
		"weight": func(g): return 8.0 if slots_where(g, func(sk): return sk.shape == "CONE").size() > 0 else 0.0,
		"can": func(g): return slots_where(g, func(sk): return sk.shape == "CONE" and not sk.mods.get("wide_cone", false)).size() > 0,
		"make": func(g, pick_slot: Callable):
			var i: int = pick_slot.call(slots_where(g, func(sk): return sk.shape == "CONE" and not sk.mods.get("wide_cone", false)))
			return {"title": "FLARED NOZZLE", "slot": i,
				"text": "%s opens to a 95-degree cone." % SkyGearData.skill_name(g.skills[i]),
				"apply": func(gg): gg.skills[i].mods.wide_cone = true},
	})
	cards.append({
		"id": "knockskill", "rarity": "common", "scope": SCOPE_SKILL,
		"weight": func(_g): return 8.0,
		"can": func(g): return g.skills.size() > 0,
		"make": func(g, pick_slot: Callable):
			var i: int = pick_slot.call(filled_slots(g))
			return {"title": "SLEDGE FORCE", "slot": i,
				"text": "+60%% knockback on %s." % SkyGearData.skill_name(g.skills[i]),
				"apply": func(gg): gg.skills[i].mods.knock *= 1.60},
	})
	cards.append({
		"id": "twin", "rarity": "epic", "scope": SCOPE_SKILL,
		"weight": func(_g): return 7.0,
		"can": func(g): return slots_where(g, func(sk): return sk.mods.multi < 2 and not SkyGearData.SHAPES[sk.shape].get("passive", false)).size() > 0,
		"make": func(g, pick_slot: Callable):
			var i: int = pick_slot.call(slots_where(g, func(sk): return sk.mods.multi < 2 and not SkyGearData.SHAPES[sk.shape].get("passive", false)))
			return {"title": "TWIN CAST", "slot": i,
				"text": "%s fires twice, each at 70%% damage." % SkyGearData.skill_name(g.skills[i]),
				"apply": func(gg): gg.skills[i].mods.multi = 2},
	})
	cards.append({
		"id": "reelem", "rarity": "rare", "scope": SCOPE_SKILL,
		"weight": func(_g): return 6.0,
		"can": func(g): return g.skills.size() > 0,
		"make": func(g, pick_slot: Callable):
			var i: int = pick_slot.call(filled_slots(g))
			var current: String = g.skills[i].element
			var options: Array = []
			for key in SkyGearData.ELEMENTS.keys():
				if key != current:
					options.append(key)
			var to: String = options[g.rng.randi_range(0, options.size() - 1)]
			return {"title": "RETUNE CORE", "slot": i,
				"text": "%s becomes %s." % [SkyGearData.skill_name(g.skills[i]), SkyGearData.ELEMENTS[to].name],
				"apply": func(gg): gg.skills[i].element = to},
	})

	# --- element cards: every skill of one colour --------------------------
	cards.append({
		"id": "elemdmg", "rarity": "rare", "scope": SCOPE_ELEMENT,
		"weight": func(g): return 9.0 * (2.0 if g.skills.size() > 1 else 1.0),
		"can": func(g): return _any_element(g),
		"make": func(g, _pick: Callable):
			var e: String = _roll_owned_element(g)
			var n: int = slots_where(g, func(sk): return sk.element == e).size()
			return {"title": "%s CONVERGENCE" % SkyGearData.ELEMENTS[e].name.to_upper(), "element": e,
				"text": "+30%% damage on every %s skill%s" % [SkyGearData.ELEMENTS[e].name, (" — you run %d." % n) if n > 1 else "."],
				"apply": func(gg): gg.mods.elem_damage[e] *= 1.30},
	})
	cards.append({
		"id": "elemcd", "rarity": "rare", "scope": SCOPE_ELEMENT,
		"weight": func(_g): return 8.0,
		"can": func(g): return _any_element(g),
		"make": func(g, _pick: Callable):
			var e: String = _roll_owned_element(g)
			return {"title": "%s CADENCE" % SkyGearData.ELEMENTS[e].name.to_upper(), "element": e,
				"text": "-20%% cooldown on every %s skill." % SkyGearData.ELEMENTS[e].name,
				"apply": func(gg): gg.mods.elem_cooldown[e] *= 0.80},
	})
	cards.append({
		"id": "burnDmg", "rarity": "common", "scope": SCOPE_ELEMENT,
		"weight": func(g): return 6.0 * element_tag(g, "EMBER"),
		"can": func(g): return g.mods.burn_damage < 3.0,
		"make": func(_g, _pick: Callable):
			return {"title": "ACCELERANT", "text": "Burning deals 50% more.",
				"apply": func(gg): gg.mods.burn_damage += 0.5},
	})
	cards.append({
		"id": "burnDur", "rarity": "common", "scope": SCOPE_ELEMENT,
		"weight": func(g): return 5.0 * element_tag(g, "EMBER"),
		"can": func(g): return g.mods.burn_duration < 4.0,
		"make": func(_g, _pick: Callable):
			return {"title": "SLOW COMBUSTION", "text": "Burns last 2s longer.",
				"apply": func(gg): gg.mods.burn_duration += 2.0},
	})
	cards.append({
		"id": "slowAmt", "rarity": "common", "scope": SCOPE_ELEMENT,
		"weight": func(g): return 6.0 * element_tag(g, "FROST"),
		"can": func(g): return g.mods.slow_amount < 0.72,
		"make": func(_g, _pick: Callable):
			return {"title": "DEEP CHILL", "text": "Frost slows 15% harder.",
				"apply": func(gg): gg.mods.slow_amount = minf(0.75, gg.mods.slow_amount + 0.15)},
	})
	cards.append({
		"id": "brittle", "rarity": "rare", "scope": SCOPE_ELEMENT,
		"weight": func(g): return 5.0 * element_tag(g, "FROST"),
		"can": func(g): return g.mods.slow_damage < 0.5,
		"make": func(_g, _pick: Callable):
			return {"title": "BRITTLE", "text": "Slowed targets take 25% more damage.",
				"apply": func(gg): gg.mods.slow_damage += 0.25},
	})
	cards.append({
		"id": "stun", "rarity": "rare", "scope": SCOPE_ELEMENT,
		"weight": func(g): return 5.0 * element_tag(g, "ARC"),
		"can": func(g): return g.mods.stun_chance < 0.6,
		"make": func(_g, _pick: Callable):
			return {"title": "OVERLOAD", "text": "+15% chance for Arc to stun.",
				"apply": func(gg): gg.mods.stun_chance += 0.15},
	})
	cards.append({
		"id": "knock", "rarity": "common", "scope": SCOPE_ELEMENT,
		"weight": func(g): return 5.0 * element_tag(g, "STEAM"),
		"can": func(_g): return true,
		"make": func(_g, _pick: Callable):
			return {"title": "PRESSURE SPIKE", "text": "+40% knockback from every source.",
				"apply": func(gg): gg.mods.knock_multiplier += 0.4},
	})
	cards.append({
		"id": "scald", "rarity": "rare", "scope": SCOPE_ELEMENT,
		"weight": func(g): return 5.0 * element_tag(g, "STEAM"),
		"can": func(g): return g.mods.scald < 1.0,
		"make": func(_g, _pick: Callable):
			return {"title": "SCALDING", "text": "Steam leaves targets burning.",
				"apply": func(gg): gg.mods.scald = 1.0},
	})

	# --- the captain -------------------------------------------------------
	cards.append({
		"id": "hp", "rarity": "common", "scope": SCOPE_CAPTAIN,
		"weight": func(_g): return 10.0,
		"can": func(_g): return true,
		"make": func(_g, _pick: Callable):
			return {"title": "REINFORCED RIBS", "text": "+20 max health, and heal 20.",
				"apply": func(gg):
					gg.player.max_hp += 20.0
					gg.player.hp += 20.0},
	})
	cards.append({
		"id": "spd", "rarity": "common", "scope": SCOPE_CAPTAIN,
		"weight": func(_g): return 9.0,
		"can": func(g): return g.mods.move_multiplier < 1.9,
		"make": func(_g, _pick: Callable):
			return {"title": "LIGHT BOOTS", "text": "+12% movement speed.",
				"apply": func(gg): gg.mods.move_multiplier *= 1.12},
	})
	cards.append({
		"id": "dashcd", "rarity": "common", "scope": SCOPE_CAPTAIN,
		"weight": func(_g): return 9.0,
		"can": func(g): return g.mods.dash_cooldown_bonus < 0.5 and _has_dash(g),
		"make": func(_g, _pick: Callable):
			return {"title": "SPRING COILS", "text": "Dash recharges 0.25s faster.",
				"apply": func(gg): gg.mods.dash_cooldown_bonus += 0.25},
	})
	cards.append({
		"id": "dashdmg", "rarity": "rare", "scope": SCOPE_CAPTAIN,
		"weight": func(_g): return 10.0,
		"can": func(g): return g.mods.dash_damage < 200.0 and _has_dash(g),
		"make": func(_g, _pick: Callable):
			return {"title": "RAMMING GEAR", "text": "Dash deals 60 more damage to everything you pass through.",
				"apply": func(gg): gg.mods.dash_damage += 60.0},
	})
	cards.append({
		"id": "dashchg", "rarity": "epic", "scope": SCOPE_CAPTAIN,
		"weight": func(_g): return 8.0,
		"can": func(g): return g.mods.dash_charges < 3 and _has_dash(g),
		"make": func(_g, _pick: Callable):
			return {"title": "SECOND WIND", "text": "+1 dash charge.",
				"apply": func(gg):
					gg.mods.dash_charges += 1
					gg.player.max_dash_charges = gg.mods.dash_charges
					gg.player.dash_charges += 1},
	})
	cards.append({
		"id": "crit", "rarity": "common", "scope": SCOPE_CAPTAIN,
		"weight": func(_g): return 10.0,
		"can": func(g): return g.mods.crit_chance < 0.75,
		"make": func(_g, _pick: Callable):
			return {"title": "KEEN EYE", "text": "+8% critical hit chance.",
				"apply": func(gg): gg.mods.crit_chance += 0.08},
	})
	cards.append({
		"id": "critx", "rarity": "rare", "scope": SCOPE_CAPTAIN,
		"weight": func(_g): return 9.0,
		"can": func(g): return g.mods.crit_explode < 1.0,
		"make": func(_g, _pick: Callable):
			return {"title": "OVERKILL", "text": "Crits detonate for 20 damage around the target.",
				"apply": func(gg): gg.mods.crit_explode = 1.0},
	})
	cards.append({
		"id": "scrap", "rarity": "common", "scope": SCOPE_CAPTAIN,
		"weight": func(_g): return 9.0,
		"can": func(g): return g.mods.scrap_chance < 0.15,
		"make": func(_g, _pick: Callable):
			return {"title": "SCRAPPER'S LUCK", "text": "Kills have a 15% chance to drop 12 health.",
				"apply": func(gg): gg.mods.scrap_chance += 0.15},
	})
	cards.append({
		"id": "lifesteal", "rarity": "rare", "scope": SCOPE_CAPTAIN,
		"weight": func(_g): return 8.0,
		"can": func(g): return g.mods.lifesteal < 0.13,
		"make": func(_g, _pick: Callable):
			return {"title": "BLOODSTEAM", "text": "Heal for 4.5% of damage you deal INSIDE your own reach.",
				"apply": func(gg): gg.mods.lifesteal += 0.045},
	})
	cards.append({
		"id": "ventheal", "rarity": "rare", "scope": SCOPE_CAPTAIN,
		"weight": func(_g): return 10.0,
		"can": func(g): return g.mods.vent_heal < 24.0,
		"make": func(_g, _pick: Callable):
			return {"title": "SAFETY VALVE", "text": "Venting heals 8 more.",
				"apply": func(gg): gg.mods.vent_heal += 8.0},
	})
	cards.append({
		"id": "ventdmg", "rarity": "rare", "scope": SCOPE_CAPTAIN,
		"weight": func(_g): return 9.0,
		"can": func(g): return g.mods.vent_damage < 2.5,
		"make": func(_g, _pick: Callable):
			return {"title": "OVERPRESSURE", "text": "+50% vent damage and +15% vent radius.",
				"apply": func(gg):
					gg.mods.vent_damage += 0.5
					gg.mods.vent_radius += 0.15},
	})
	cards.append({
		"id": "pressrate", "rarity": "common", "scope": SCOPE_CAPTAIN,
		"weight": func(_g): return 10.0,
		"can": func(g): return g.mods.pressure_rate < 2.2,
		"make": func(_g, _pick: Callable):
			return {"title": "HAIR TRIGGER", "text": "Pressure builds 30% faster.",
				"apply": func(gg): gg.mods.pressure_rate += 0.30},
	})
	cards.append({
		"id": "dressing", "rarity": "common", "scope": SCOPE_CAPTAIN,
		"weight": func(_g): return 9.0,
		"can": func(g): return g.mods.dressing < 4.0,
		"make": func(_g, _pick: Callable):
			return {"title": "FIELD DRESSING", "text": "Below 60% health, heal 2/s while your pressure is above half.",
				"apply": func(gg): gg.mods.dressing += 2.0},
	})

	# --- the objective, the deck, the draft ---------------------------------
	cards.append({
		"id": "boilerhp", "rarity": "common", "scope": SCOPE_SHIP,
		"weight": func(g): return 22.0 if g.boiler_hp < g.boiler_max_hp * 0.8 else 9.0,
		"can": func(_g): return true,
		"make": func(_g, _pick: Callable):
			return {"title": "SPARE TANK", "text": "Boiler gains 150 max HP and repairs 150.",
				"apply": func(gg):
					gg.boiler_max_hp += 150.0
					gg.boiler_hp = minf(gg.boiler_max_hp, gg.boiler_hp + 150.0)},
	})
	cards.append({
		"id": "boilerdr", "rarity": "rare", "scope": SCOPE_SHIP,
		"weight": func(_g): return 10.0,
		"can": func(g): return g.mods.boiler_dr < 0.5,
		"make": func(_g, _pick: Callable):
			return {"title": "BOILER PLATING", "text": "The Boiler takes 25% less damage.",
				"apply": func(gg): gg.mods.boiler_dr += 0.25},
	})
	cards.append({
		"id": "kegs", "rarity": "epic", "scope": SCOPE_DECK,
		"weight": func(_g): return 8.0,
		"can": func(g): return g.mods.keg_safe < 1.0,
		"make": func(_g, _pick: Callable):
			return {"title": "POWDER MONKEY", "text": "+40% keg damage, and their blast no longer hurts you.",
				"apply": func(gg):
					gg.mods.keg_damage += 0.4
					gg.mods.keg_safe = 1.0},
	})
	cards.append({
		"id": "spares", "rarity": "common", "scope": SCOPE_META,
		"weight": func(_g): return 7.0,
		"can": func(g): return g.rerolls < 6,
		"make": func(_g, _pick: Callable):
			return {"title": "SPARE PARTS", "text": "+2 rerolls, for any future draft.",
				"apply": func(gg): gg.rerolls += 2},
	})

	# --- everything you hold ------------------------------------------------
	cards.append({
		"id": "fifth", "rarity": "epic", "scope": SCOPE_ALL,
		"weight": func(_g): return 8.0,
		"can": func(g): return not g.mods.fifth_gear,
		"make": func(_g, _pick: Callable):
			return {"title": "FIFTH GEAR", "text": "Every 5th cast of a skill is free and deals double.",
				"apply": func(gg): gg.mods.fifth_gear = true},
	})
	cards.append({
		"id": "residue", "rarity": "epic", "scope": SCOPE_ALL,
		"weight": func(_g): return 8.0,
		"can": func(g): return g.mods.residue < 2.0,
		"make": func(_g, _pick: Callable):
			return {"title": "RESIDUE", "text": "Skills leave a burning field for 2s where they land.",
				"apply": func(gg): gg.mods.residue += 1.0},
	})
	cards.append({
		"id": "autofire", "rarity": "epic", "scope": SCOPE_ALL,
		"weight": func(_g): return 8.0,
		"can": func(g): return g.mods.kill_autofire < 0.4,
		"make": func(_g, _pick: Callable):
			return {"title": "DEAD MAN'S TRIGGER", "text": "On kill, 10% chance to fire slot 1 at a random enemy.",
				"apply": func(gg): gg.mods.kill_autofire += 0.10},
	})
	cards.append({
		"id": "killboom", "rarity": "rare", "scope": SCOPE_ALL,
		"weight": func(_g): return 9.0,
		"can": func(g): return g.mods.kill_explode < 60.0,
		"make": func(_g, _pick: Callable):
			return {"title": "DETONATOR", "text": "Kills burst for 18 damage nearby.",
				"apply": func(gg): gg.mods.kill_explode += 18.0},
	})

	return cards


static func _any_element(game) -> bool:
	for key in SkyGearData.ELEMENTS.keys():
		if has_element(game, key):
			return true
	return false


static func _roll_owned_element(game) -> String:
	var owned: Array = []
	for key in SkyGearData.ELEMENTS.keys():
		if has_element(game, key):
			owned.append(key)
	if owned.is_empty():
		return "EMBER"
	return owned[game.rng.randi_range(0, owned.size() - 1)]


## Which slots a card lands on. Empty means it touches no skill at all, which is
## itself the useful thing to show on the card face.
static func affects(game, card: Dictionary) -> Array:
	var scope: String = card.get("scope", SCOPE_CAPTAIN)
	if scope == SCOPE_NEW or scope == SCOPE_SKILL:
		return [] if not card.has("slot") else [card.slot]
	if scope == SCOPE_ELEMENT:
		## Through `element_of`, so the row of lit skill glyphs and the hue the
		## card is painted in cannot point at two different elements.
		var e: String = element_of(card)
		var out: Array = []
		for i in game.skills.size():
			if e == "" or game.skills[i].element == e:
				out.append(i)
		return out
	if scope == SCOPE_ALL:
		return filled_slots(game)
	return []
