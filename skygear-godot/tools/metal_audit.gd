extends SceneTree
## EVERY METALLIC VALUE ON THE BUILT DECK, MEASURED RATHER THAN GREPPED
## (board SG-291).
##
##   godot --path . --headless --script tools/metal_audit.gd
##   godot --path . --headless --script tools/metal_audit.gd -- --all
##
## WHY THIS EXISTS. `LAMPLIT_METALLIC_MAX := 0.34` is the ceiling SG-179 produced
## — the owner looked at flat-albedo brass at 0.4 and called it "very
## placeholder", and under a lamp-only rig with no reflection probe and no SSR
## that is what metallic above the ceiling reads as. `tools/lamplit.py` clamps
## every shipped GLB to it. The harness check NAMED for the other half —
## `deck · the procedural deck obeys the same lamplit ceiling the models do` —
## parsed the float out of the Python file and compared it to the GDScript
## constant. Two literals. It never opened a material, so the deck's own
## procedural boxes could sit anywhere at all and the check that carries that
## sentence would stay green. It did, and they did.
##
## A grep is not the answer either: `grep "metallic ="` finds the assignments and
## cannot tell you which of them a player ever sees. `_boiler_primitive` only
## runs when the Boiler MESH fails to load, and `_build_legacy_gunwale` only runs
## when `tools/edge_place.gd` turns a trial path on. Both are real code with real
## materials that are not in the frame. So this walks the deck the renderer
## ACTUALLY BUILDS and reports what is on it.
##
## MODEL-BORNE MATERIALS ARE COUNTED SEPARATELY AND ARE NOT THE SAME QUESTION.
## A material that arrived inside an imported `.glb` or `.res` is `lamplit.py`'s
## jurisdiction and is fixed by clamping and re-importing the asset, not by
## editing GDScript. A material the RENDERER ITSELF created with
## `StandardMaterial3D.new()` is fixed by one line. Telling them apart is the
## whole reason this prints two tables: the resource path is empty for a material
## built in code and points into `assets/` for one that came off disk.
##
## AND ONLY THE FIRST TABLE CARRIES A VERDICT, WHICH IS THIS TOOL DECLARING WHAT
## IT CANNOT MEASURE. glTF's effective metallic is `metallicFactor` times the
## BLUE channel of the metallic-roughness map, and `BaseMaterial3D.metallic` is
## the FACTOR ALONE. Every code-built material here is flat — no map, so factor
## IS effective and the comparison is exact. Every model-borne one has a map, so
## a factor of 0.556 over a map peaking at 0.612 is an effective 0.34, which is
## EXACTLY CLAMPED and would print here as 63% over if this tool judged the
## factor. The first version of it did, for one run, and reported twelve
## correctly-clamped models as failures — a rig measuring the wrong number, which
## is the fifth failure mode arriving inside the instrument built to catch the
## seventh.
##
## Reading the real peak needs the map's pixels, and `lamplit.py` already does
## that with numpy over the full-resolution source. So the mapped table is
## REPORTED and its verdict is DEFERRED there by name rather than re-derived
## here at lower fidelity — one authority per number.
func _initialize() -> void: call_deferred("_run")

const CEILING := 0.34


func _origin(mat: Material) -> String:
	## Where this material came from. A material made in code has no
	## `resource_path`; one loaded from an imported scene keeps the path it was
	## imported to, and that is the only honest way to separate the two
	## jurisdictions without a hand-maintained list of node names.
	var path := str(mat.resource_path)
	if path == "":
		return "code"
	return path


func _run() -> void:
	var show_all := OS.get_cmdline_user_args().has("--all")
	var world: Node3D = load("res://scenes/main3d.tscn").instantiate()
	root.add_child(world)
	var game = world.get_node("SkyGear")
	game.log_runs = false
	game.workshop = SkyGearWorkshop.fresh(true)
	game.refresh_berthed()
	game.set_seed_text("METAL")
	game.begin_run()
	game.choose_draft(0)
	await process_frame
	await process_frame

	var seen := {}
	var code_rows: Array = []
	var asset_rows: Array = []
	var counted := 0
	for node in world.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var surfaces: int = maxi(1, mi.get_surface_override_material_count())
		for i in surfaces:
			var mat := mi.get_active_material(i)
			if mat == null or mat is not BaseMaterial3D:
				continue
			var base := mat as BaseMaterial3D
			## One ROW per distinct material, not per instance: `band_mat` is one
			## material shared across fifty-odd crate boxes and printing it fifty
			## times would say "fifty defects" about one line of code. The
			## instance count is carried on the row instead, because it is what
			## says how much of the frame this is.
			var id := base.get_instance_id()
			counted += 1
			if seen.has(id):
				seen[id].instances += 1
				continue
			var row := {
				"metallic": base.metallic,
				"roughness": base.roughness,
				"albedo": str(base.albedo_color.to_html(false)),
				"origin": _origin(base),
				"path": str(world.get_path_to(mi)),
				"instances": 1,
				"textured": base.albedo_texture != null,
				"metal_map": base.metallic_texture != null,
			}
			seen[id] = row
			if row.origin == "code":
				code_rows.append(row)
			else:
				asset_rows.append(row)

	var sorter := func(a, b): return float(a.metallic) > float(b.metallic)
	code_rows.sort_custom(sorter)
	asset_rows.sort_custom(sorter)

	print("METAL AUDIT — the built deck, seed METAL, wave 1")
	print("ceiling LAMPLIT_METALLIC_MAX = %.2f" % CEILING)
	print("%d surfaces walked, %d distinct materials (%d built in code, %d off disk)"
		% [counted, seen.size(), code_rows.size(), asset_rows.size()])

	## THE CODE TABLE IS JUDGED. Every material in it is flat — asserted below,
	## not assumed — so its factor is its effective metallic and the ceiling
	## applies to it directly.
	var over: Array = []
	var mapped_in_code: Array = []
	for row in code_rows:
		if bool(row.metal_map):
			mapped_in_code.append(row)
		elif float(row.metallic) > CEILING + 0.0001:
			over.append(row)
	print("")
	print("--- MATERIALS THE RENDERER BUILT IN CODE: %d over the ceiling of %d ---"
		% [over.size(), code_rows.size()])
	for row in (code_rows if show_all else over + mapped_in_code):
		## The map flag is PRINTED rather than assumed even here, because the
		## paragraph above only holds while it reads `flat` on every line, and a
		## table that hardcodes the thing it depends on cannot tell you when it
		## has stopped being true.
		print("  metallic %.3f  rough %.2f  x%-4d  %s%s  %s"
			% [float(row.metallic), float(row.roughness), int(row.instances),
				("map " if bool(row.metal_map) else "flat"),
				(" tex" if bool(row.textured) else "    "), str(row.path)])
	if not mapped_in_code.is_empty():
		## If this ever fires, the assumption above has stopped holding and the
		## verdict on those rows is not this tool's to give any more.
		print("  !! %d code-built material(s) carry a metallic MAP — factor is no"
			% mapped_in_code.size())
		print("     longer the effective value for them and this table's verdict")
		print("     does not cover them. Measure them the way lamplit.py does.")

	## THE DISK TABLE IS REPORTED, NOT JUDGED. See the header: the number printed
	## is the FACTOR, the effective value is factor x the map's blue channel, and
	## the authority on that is `python tools/lamplit.py audit`, which reads the
	## full-resolution pixels. Printed here so the two can be read side by side.
	print("")
	print("--- MATERIALS THAT CAME OFF DISK: %d, factor only, verdict deferred ---"
		% asset_rows.size())
	print("    (effective = factor x map blue; run `python tools/lamplit.py audit`)")
	for row in asset_rows:
		if not show_all and not bool(row.metal_map) \
				and float(row.metallic) <= CEILING + 0.0001:
			continue
		print("  factor %.3f  rough %.2f  x%-4d  %s%s  %s"
			% [float(row.metallic), float(row.roughness), int(row.instances),
				("map " if bool(row.metal_map) else "flat"),
				(" tex" if bool(row.textured) else "    "),
				str(row.path)])
		print("        <- %s" % str(row.origin))

	world.queue_free()
	quit(0)
