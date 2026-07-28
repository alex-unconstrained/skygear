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
##   rarity  common | rare | epic
##   scope   which class of thing it touches; drives the card's colour band and
##           the row of affected-skill glyphs on the card face
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

## Colour per scope. The browser draws these as a band across the top of the
## card; the class of a card should be readable before any of its words are.
const SCOPE_COLOR := {
	SCOPE_NEW: Color("#ffd52e"),
	SCOPE_SKILL: Color("#37f0c8"),
	SCOPE_ELEMENT: Color("#c9b6e8"),
	SCOPE_CAPTAIN: Color("#e8542e"),
	SCOPE_SHIP: Color("#e8c376"),
	SCOPE_DECK: Color("#ff9a4a"),
	SCOPE_ALL: Color("#9be8d2"),
	SCOPE_META: Color("#8fa6c9"),
}
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
		"can": func(g): return g.mods.dash_cooldown_bonus < 0.5,
		"make": func(_g, _pick: Callable):
			return {"title": "SPRING COILS", "text": "Dash recharges 0.25s faster.",
				"apply": func(gg): gg.mods.dash_cooldown_bonus += 0.25},
	})
	cards.append({
		"id": "dashdmg", "rarity": "rare", "scope": SCOPE_CAPTAIN,
		"weight": func(_g): return 10.0,
		"can": func(g): return g.mods.dash_damage < 200.0,
		"make": func(_g, _pick: Callable):
			return {"title": "RAMMING GEAR", "text": "Dash deals 60 more damage to everything you pass through.",
				"apply": func(gg): gg.mods.dash_damage += 60.0},
	})
	cards.append({
		"id": "dashchg", "rarity": "epic", "scope": SCOPE_CAPTAIN,
		"weight": func(_g): return 8.0,
		"can": func(g): return g.mods.dash_charges < 3,
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
		var e: String = card.get("element", CARD_ELEMENT.get(card.get("id", ""), ""))
		var out: Array = []
		for i in game.skills.size():
			if e == "" or game.skills[i].element == e:
				out.append(i)
		return out
	if scope == SCOPE_ALL:
		return filled_slots(game)
	return []
