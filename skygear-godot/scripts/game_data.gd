class_name SkyGearData
extends RefCounted

const ELEMENTS := {
	"EMBER": {"name": "Ember", "color": Color("#ff7a2f"), "blurb": "burns targets"},
	"FROST": {"name": "Frost", "color": Color("#37f0c8"), "blurb": "slows targets"},
	"ARC": {"name": "Arc", "color": Color("#7adcff"), "blurb": "can stun"},
	"STEAM": {"name": "Steam", "color": Color("#c9b6e8"), "blurb": "knocks back"},
}

const SHAPES := {
	"CLOSEHIT": {"name": "Cleave", "kind": "arc", "damage": 22.0, "cooldown": 0.45, "range": 190.0, "arc": 2.443, "knock": 150.0},
	"LINE_BURST": {"name": "Lance", "kind": "line", "damage": 30.0, "cooldown": 1.1, "range": 520.0, "width": 26.0, "knock": 190.0},
	"CONE": {"name": "Gale", "kind": "cone", "damage": 26.0, "cooldown": 1.4, "range": 300.0, "arc": 1.134, "knock": 210.0},
	"RANGED_AOE": {"name": "Mortar", "kind": "aoe", "damage": 40.0, "cooldown": 2.6, "range": 420.0, "radius": 110.0, "knock": 260.0},
	"CHAIN": {"name": "Whip", "kind": "chain", "damage": 26.0, "cooldown": 2.0, "range": 480.0, "jumps": 3, "jump_range": 200.0, "knock": 90.0},
	"AURA": {"name": "Field", "kind": "aura", "damage": 4.0, "cooldown": 0.0, "radius": 150.0, "tick_rate": 1.8, "passive": true},
	"PULSE": {"name": "Pulse", "kind": "pulse", "damage": 34.0, "cooldown": 4.4, "radius": 210.0, "knock": 220.0, "passive": true},
	## Deployable, not passive. It was marked `passive: true`, which routed it to
	## `_update_passives`, where "sentry" fired a beam out of the PLAYER at the
	## nearest boarder. Nothing was ever placed on the deck — you drafted a turret
	## and got an invisible one welded to your own ribs. It is an active now: the
	## press puts an object on the planking where you are pointing.
	"SENTRY": {"name": "Sentry", "kind": "sentry", "damage": 14.0, "cooldown": 9.0,
		"range": 420.0, "deploy_range": 520.0, "life": 14.0, "fire_rate": 1.4,
		"knock": 70.0, "auto_after": 2.5, "max_live": 2},
	"RAY": {"name": "Beam", "kind": "ray", "damage": 7.0, "cooldown": 0.6, "range": 480.0, "width": 24.0, "knock": 40.0},
}

const ENEMIES := {
	"SCRAPPER": {"hp": 60.0, "speed": 150.0, "damage": 12.0, "radius": 22.0, "attack_range": 66.0, "windup": 0.40, "recover": 0.42, "ai": "melee", "scale": 0.25, "texture": "res://assets/art/enemies/automaton_front_idle.png"},
	"GUNNER": {"hp": 35.0, "speed": 110.0, "damage": 10.0, "radius": 21.0, "attack_range": 340.0, "windup": 0.45, "recover": 0.80, "ai": "ranged", "bolt_speed": 352.0, "scale": 0.25, "texture": "res://assets/art/enemies/drone_front_idle.png"},
	"ARMORED": {"hp": 180.0, "speed": 75.0, "damage": 20.0, "radius": 32.0, "attack_range": 82.0, "windup": 0.55, "recover": 0.60, "ai": "melee", "scale": 0.20, "texture": "res://assets/art/enemies/furnace_knight_front_idle.png"},
	"SWARM": {"hp": 20.0, "speed": 230.0, "damage": 6.0, "radius": 15.0, "attack_range": 46.0, "windup": 0.40, "recover": 0.30, "ai": "melee", "scale": 0.22, "texture": "res://assets/art/enemies/gremlin_front_idle.png"},
	"BOSS": {"hp": 900.0, "speed": 95.0, "damage": 26.0, "radius": 70.0, "attack_range": 120.0, "windup": 0.90, "recover": 1.0, "ai": "melee", "scale": 0.22, "texture": "res://assets/art/enemies/colossus_front_idle.png"},
}

# batch = [time, type, count, lane]. Lane is 0/1/2, "all", or omitted.
## EVERY FOURTH WAVE IS AN EVENT.
##
## Waves 4, 8 and 12 already carried something — two boarding pushes and the
## Colossus — but a push arrives as an unannounced hulk at the bow and reads as
## "more boarders" rather than as the shape of the wave changing. Twelve waves
## with no punctuation is twelve of the same wave.
##
## Three rules, all of them about the event being READABLE:
##
##   * it is named, on screen, before it starts;
##   * it changes what you should DO, not only how many arrive — otherwise it is
##     a difficulty number wearing a title;
##   * it pays out, so choosing to engage with it is a choice rather than a tax.
##
## Wave 8 is deliberately not a second hulk. The same event twice is the problem
## this is fixing.
const EVENTS := {
	"grapple": {
		"name": "GRAPPLE RUN",
		"blurb": "A boarding hulk has locked on at the bow. Break it or it keeps unloading.",
		"voice": "push", "tint": "#ff9a4a",
	},
	"blackout": {
		"name": "BOILER BLACKOUT",
		"blurb": "The lamps are out and the gauge is cold. Salvage pays double while it lasts.",
		"voice": "push", "tint": "#8fa6c9",
		## Dark, and worth being out in. The lanterns dying is the whole picture:
		## you fight by the light of your own weapons, and the deck is suddenly
		## somewhere you have to remember rather than somewhere you can see.
		"darkness": 0.86, "salvage_bonus": 1.0, "pressure_bonus": 0.45,
	},
	"colossus": {
		"name": "THE COLOSSUS",
		"blurb": "It came aboard itself. Nothing else on this ship will matter for a while.",
		"voice": "boss", "tint": "#ff4d37",
	},
}

## Which wave gets which. Every fourth, and the table says so rather than the
## code doing arithmetic on the wave number — wave 16 is one line away.
const WAVE_EVENTS := {4: "grapple", 8: "blackout", 12: "colossus"}


const WAVES := [
	{"batches": [[0.0, "SCRAPPER", 2, 1], [4.0, "SCRAPPER", 2, 0], [8.0, "SCRAPPER", 2, 2]]},
	{"batches": [[0.0, "SCRAPPER", 2, "all"], [6.0, "GUNNER", 1, 1], [10.0, "SCRAPPER", 3, 1]]},
	{"batches": [[0.0, "SWARM", 4, "all"], [5.0, "SCRAPPER", 2, 0], [9.0, "GUNNER", 2, 2], [13.0, "SWARM", 4, 1]]},
	{"batches": [[0.0, "SCRAPPER", 3, "all"], [7.0, "GUNNER", 2, 1], [13.0, "SWARM", 5, "all"], [20.0, "SCRAPPER", 3, "all"]], "push": true},
	{"batches": [[0.0, "ARMORED", 1, 1], [4.0, "SWARM", 5, "all"], [9.0, "GUNNER", 2, 0], [13.0, "SCRAPPER", 3, 2]]},
	{"batches": [[0.0, "SCRAPPER", 3, "all"], [6.0, "ARMORED", 1, 0], [8.0, "ARMORED", 1, 2], [13.0, "GUNNER", 2, 1], [17.0, "SWARM", 5, "all"]]},
	{"batches": [[0.0, "SWARM", 6, "all"], [5.0, "ARMORED", 1, 1], [9.0, "GUNNER", 2, "all"], [15.0, "SCRAPPER", 3, "all"]]},
	{"batches": [[0.0, "SCRAPPER", 3, "all"], [6.0, "ARMORED", 1, "all"], [13.0, "GUNNER", 2, "all"], [19.0, "SWARM", 6, "all"]], "push": true},
	{"batches": [[0.0, "SWARM", 6, "all"], [5.0, "ARMORED", 2, 1], [10.0, "SCRAPPER", 3, "all"], [15.0, "GUNNER", 2, "all"]]},
	{"batches": [[0.0, "ARMORED", 1, "all"], [6.0, "GUNNER", 3, "all"], [12.0, "SCRAPPER", 4, "all"], [18.0, "SWARM", 6, "all"]]},
	{"batches": [[0.0, "SWARM", 7, "all"], [5.0, "SCRAPPER", 4, "all"], [11.0, "ARMORED", 2, "all"], [17.0, "GUNNER", 3, "all"], [26.0, "SWARM", 7, "all"]]},
	{"batches": [[0.0, "BOSS", 1, 1], [5.0, "SWARM", 4, "all"], [11.0, "SCRAPPER", 3, "all"]], "boss": true},
]

const STARTING_SKILLS := [
	{"shape": "RANGED_AOE", "element": "FROST"},
	{"shape": "CONE", "element": "EMBER"},
	{"shape": "LINE_BURST", "element": "ARC"},
]

## What is standing on the deck when a run starts.
##
## The eight interactive props were the whole layout, and a deck with eight
## objects on it looks like a test level. The browser dresses the same space
## with roughly twice that — braziers, crate stacks, coiled rope — none of which
## you fight, all of which is why the ship reads as a working ship. Everything
## added here is scenery: `is_targetable()` keeps braziers and rope off the
## enemy's and the bolt's list, so the fight is unchanged.
const PROP_LAYOUT := [
	{"type": "keg", "position": Vector2(-520, -650)},
	{"type": "keg", "position": Vector2(520, -560)},
	{"type": "crate", "position": Vector2(-80, -360)},
	{"type": "lantern", "position": Vector2(-610, -100)},
	{"type": "keg", "position": Vector2(100, 50)},
	{"type": "crate", "position": Vector2(590, 300)},
	{"type": "keg", "position": Vector2(-520, 480)},
	{"type": "lantern", "position": Vector2(130, 610)},
	# dressing
	{"type": "brazier", "position": Vector2(-120, -700)},
	{"type": "brazier", "position": Vector2(160, 330)},
	{"type": "brazier", "position": Vector2(-600, 160)},
	{"type": "crates", "position": Vector2(-150, -140)},
	{"type": "crates", "position": Vector2(430, -260)},
	{"type": "crates", "position": Vector2(-430, 760)},
	{"type": "crate", "position": Vector2(500, 680)},
	{"type": "rope", "position": Vector2(60, -520)},
	{"type": "rope", "position": Vector2(-155, 300)},
	{"type": "lantern", "position": Vector2(620, -420)},
	# the ship itself: a mast amidships, hatches, the rail, a vent, the ballista
	{"type": "mast", "position": Vector2(0, -180)},
	{"type": "hatch", "position": Vector2(-250, 520)},
	{"type": "hatch", "position": Vector2(300, -740)},
	{"type": "vent", "position": Vector2(-680, 620)},
	{"type": "vent", "position": Vector2(700, 120)},
	{"type": "ballista", "position": Vector2(-700, -820)},
	{"type": "ballista", "position": Vector2(700, -820)},
	{"type": "railing", "position": Vector2(-780, -300)},
	{"type": "railing", "position": Vector2(-780, 240)},
	{"type": "railing", "position": Vector2(780, -300)},
	{"type": "railing", "position": Vector2(780, 240)},
]

static func skill_name(skill: Dictionary) -> String:
	return "%s %s" % [ELEMENTS[skill.element].name, SHAPES[skill.shape].name]

static func make_skill(shape: String, element: String) -> Dictionary:
	## Per-skill modifiers live on the instance, exactly as they do in the
	## browser build: a card that says "+30% range on Frost Mortar" has to be
	## able to say it about ONE of your skills, not about the shape table.
	return {
		"shape": shape, "element": element, "cooldown_left": 0.0, "level": 1,
		"casts": 0,
		"mods": {
			"area": 1.0, "range": 1.0, "cooldown": 1.0, "damage": 1.0,
			"knock": 1.0, "multi": 1, "pierce": 0, "jumps": 0,
			"wide_cone": false,
		},
	}


## Base tuning for the close-quarters loop and the draft, matching browser
## v11.2. Kept in one block rather than scattered as literals, because the
## previous pass had 210 and 1.1 and 0.16 written inline in four files and the
## balance change that followed had to find all of them.
const CLOSE := {
	"range": 210.0,
	"pressure_per_damage": 0.85,
	"pressure_idle": 6.0,
	"pressure_decay": 14.0,
	"pressure_grace": 1.2,
	"vent_heal": 10.0,
	"vent_damage": 40.0,
	"vent_radius": 200.0,
	"vent_knock": 280.0,
	"vent_cooldown": 2.0,
	"scrap_chance": 0.10,
	"scrap_heal": 6.0,
	"dash_refund": 0.30,
	"heal_cap_per_sec": 12.0,
	"lifesteal_cap_per_sec": 9.0,
}
const DRAFT := {"rerolls": 2}

