extends SceneTree
## The stowage never deals an unfair deck.
##
## SHIP-AND-MAPS §9: the deck is dealt per wave from the seed now (board
## SG-48), and a generated layout's classic failure is the hand nobody
## authored — four kegs in a chain, a doorway stood full of cargo, a deck so
## covered it plays as a kiting course. The clamp means no deal can strand a
## boarder (§2), so what is left to audit is the player's ground, and this
## audits it the way `tools/balance.gd` audits the curve: many seeds, no
## renderer, numbers instead of a feeling.
##
##   godot --path . --headless --script tools/stow.gd            40 seeds
##   godot --path . --headless --script tools/stow.gd -- 100     N seeds
##
## N seeds × 12 waves, four invariants per deck:
##   · a vent in every lane — the Boilerwright's class is "learn the vents"
##   · no two kegs within KEG_SPACING (200) — §7.3's chain: one detonation
##     within 200 units of another keg is all of them
##   · every cross-passage passable — no rolled prop stands in one of the six
##     openings between the cargo runs, the player's whole lateral graph
##   · hard-cover area inside its band — 1..5 crate stacks, around today's 3
##     (plus the movable crate, which is not part of the deal)
##
## The worst offender per invariant prints WITH ITS SEED AND WAVE, pass or
## fail, so a tightening table change can see how much margin it spent.
## Exit code is the count of violated decks, so the hub can gate on it.
func _initialize() -> void: call_deferred("_run")

const DEFAULT_SEEDS := 40
const COVER_MIN_STACKS := 1
const COVER_MAX_STACKS := 5


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_count: int = int(args[0]) if args.size() > 0 else DEFAULT_SEEDS

	var game: SkyGearGame = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)

	## One radius table, read off `prop.gd` itself rather than copied into this
	## file — two functions disagreeing about one number is STATUS failure mode
	## two, and a copied 38 here would drift the day someone rebalances cover.
	var radii := {}
	var prop_scene: PackedScene = load("res://scenes/prop.tscn")
	for kind in SkyGearProp.TEXTURES.keys():
		var probe: SkyGearProp = prop_scene.instantiate()
		root.add_child(probe)
		probe.configure(game, str(kind))
		radii[str(kind)] = float(probe.radius)
		probe.dead = true
		probe.queue_free()
	var stack_area: float = PI * radii["crates"] * radii["crates"]
	var band_low: float = COVER_MIN_STACKS * stack_area
	var band_high: float = COVER_MAX_STACKS * stack_area

	var openings: Array[Rect2] = _openings()

	## The passable invariant audits THE DEAL — the cargo kinds a slot can
	## roll — never the fixed ship. The aft hatch has stood flat in the +515
	## crossing since the deck was first dressed (it is walk-over furniture,
	## like every prop: only `CARGO_RECTS` collides with the captain), and an
	## invariant that flags the hand-authored ship is flagging its own
	## baseline. Derived from the table so a new slot kind is audited the day
	## it is added.
	var rollable := {}
	for entry in SkyGearData.STOWAGE:
		for kind in entry.get("of", []):
			if str(kind) != "":
				rollable[str(kind)] = true

	var bad_decks := 0
	var decks := 0
	var fail_vents := 0
	var fail_kegs := 0
	var fail_pass := 0
	var fail_cover := 0
	## Worst offenders, tracked pass or fail: the nearest keg pair, the deepest
	## intrusion into an opening, and both edges of the cover band.
	var keg_worst := {"d": INF, "seed": "", "wave": 0}
	## `margin` is signed distance from the footprint's edge to the opening:
	## positive is clearance, negative is a prop standing in a doorway.
	var pass_worst := {"margin": INF, "seed": "", "wave": 0, "kind": ""}
	var cover_low := {"area": INF, "seed": "", "wave": 0, "stacks": 0}
	var cover_high := {"area": 0.0, "seed": "", "wave": 0, "stacks": 0}

	for s in seed_count:
		var seed_text := "STOW%d" % (s + 1)
		game.set_seed_text(seed_text)
		for w in 12:
			var wave_number: int = w + 1
			var deal: Array = game.roll_stowage(wave_number)
			decks += 1
			var deck_bad := false

			## A VENT PER LANE.
			var vent_lanes := {}
			for entry in deal:
				if str(entry.type) == "vent":
					var x: float = Vector2(entry.position).x
					vent_lanes[0 if x < -240.0 else (2 if x > 240.0 else 1)] = true
			if vent_lanes.size() != 3:
				fail_vents += 1
				deck_bad = true

			## KEG SPACING.
			var kegs: Array[Vector2] = []
			for entry in deal:
				if str(entry.type) == "keg":
					kegs.append(Vector2(entry.position))
			for i in kegs.size():
				for j in range(i + 1, kegs.size()):
					var d := kegs[i].distance_to(kegs[j])
					if d < float(keg_worst.d):
						keg_worst = {"d": d, "seed": seed_text, "wave": wave_number}
					if d < SkyGearData.KEG_SPACING:
						fail_kegs += 1
						deck_bad = true

			## PASSABLE CROSSINGS: no rolled cargo's footprint reaches into
			## an opening.
			for entry in deal:
				if not rollable.has(str(entry.type)):
					continue
				var radius: float = float(radii.get(str(entry.type), 0.0))
				var at := Vector2(entry.position)
				for opening in openings:
					var nearest := Vector2(
						clampf(at.x, opening.position.x, opening.end.x),
						clampf(at.y, opening.position.y, opening.end.y))
					var margin: float = nearest.distance_to(at) - radius
					if margin < float(pass_worst.margin):
						pass_worst = {"margin": margin, "seed": seed_text,
							"wave": wave_number, "kind": str(entry.type)}
					if margin < 0.0:
						fail_pass += 1
						deck_bad = true

			## COVER IN ITS BAND.
			var stacks := 0
			for entry in deal:
				if str(entry.type) == "crates":
					stacks += 1
			var area: float = stacks * stack_area
			if area < float(cover_low.area):
				cover_low = {"area": area, "seed": seed_text,
					"wave": wave_number, "stacks": stacks}
			if area > float(cover_high.area):
				cover_high = {"area": area, "seed": seed_text,
					"wave": wave_number, "stacks": stacks}
			if area < band_low or area > band_high:
				fail_cover += 1
				deck_bad = true

			if deck_bad:
				bad_decks += 1

	print("")
	print("  STOWAGE · %d seeds × 12 waves = %d decks" % [seed_count, decks])
	print("")
	_verdict("a vent in every lane", fail_vents,
		"all three, every deck")
	_verdict("no two kegs within %.0f" % SkyGearData.KEG_SPACING, fail_kegs,
		"nearest pair %.0f units  (%s wave %d)"
		% [float(keg_worst.d), str(keg_worst.seed), int(keg_worst.wave)])
	var pass_detail := "no prop ever came near one"
	if str(pass_worst.seed) != "":
		pass_detail = "tightest clearance %.0f units — a %s (%s wave %d)" % [
			float(pass_worst.margin), str(pass_worst.kind),
			str(pass_worst.seed), int(pass_worst.wave)]
	_verdict("every cross-passage passable", fail_pass, pass_detail)
	_verdict("cover area in its band [%.0f, %.0f]" % [band_low, band_high], fail_cover,
		"leanest %d stacks (%s wave %d) · heaviest %d stacks (%s wave %d)"
		% [int(cover_low.stacks), str(cover_low.seed), int(cover_low.wave),
			int(cover_high.stacks), str(cover_high.seed), int(cover_high.wave)])
	print("")
	if bad_decks == 0:
		print("  every deck dealt fair")
	else:
		print("  %d of %d decks violated an invariant" % [bad_decks, decks])
	print("")
	game.queue_free()
	## Windows truncates exit codes to a byte; 480 bad decks must not read 224.
	quit(mini(bad_decks, 200))


func _verdict(what: String, fails: int, worst: String) -> void:
	if fails == 0:
		print("  ok   %-42s %s" % [what, worst])
	else:
		print("  FAIL %-42s %d violations · %s" % [what, fails, worst])


## The six openings between the cargo runs, derived from `CARGO_RECTS` rather
## than hardcoded at −470/+15/+515 — if the walls ever become per-run data
## (POST-PARITY-PLAN item 8) this keeps auditing the real ones.
func _openings() -> Array[Rect2]:
	var columns := {}
	for r: Rect2 in SkyGearGame.CARGO_RECTS:
		var key := r.position.x
		if not columns.has(key):
			columns[key] = []
		columns[key].append(r)
	var out: Array[Rect2] = []
	for key in columns.keys():
		var rects: Array = columns[key]
		rects.sort_custom(func(p: Rect2, q: Rect2) -> bool:
			return p.position.y < q.position.y)
		for i in rects.size() - 1:
			var top: Rect2 = rects[i]
			var bottom: Rect2 = rects[i + 1]
			out.append(Rect2(top.position.x, top.end.y,
				top.size.x, bottom.position.y - top.end.y))
	return out
