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
	"SENTRY": {"name": "Sentry", "kind": "sentry", "damage": 14.0, "cooldown": 9.0, "range": 420.0, "passive": true},
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

const PROP_LAYOUT := [
	{"type": "keg", "position": Vector2(-520, -650)},
	{"type": "keg", "position": Vector2(520, -560)},
	{"type": "crate", "position": Vector2(-80, -360)},
	{"type": "lantern", "position": Vector2(-610, -100)},
	{"type": "keg", "position": Vector2(100, 50)},
	{"type": "crate", "position": Vector2(590, 300)},
	{"type": "keg", "position": Vector2(-520, 480)},
	{"type": "lantern", "position": Vector2(130, 610)},
]

static func skill_name(skill: Dictionary) -> String:
	return "%s %s" % [ELEMENTS[skill.element].name, SHAPES[skill.shape].name]

static func make_skill(shape: String, element: String) -> Dictionary:
	return {"shape": shape, "element": element, "cooldown_left": 0.0, "level": 1}

