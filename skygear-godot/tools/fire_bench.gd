extends SceneTree
## THE INSTRUMENT FOR BOARD SG-164/SG-264 — measured on a body, not read off the
## table (`pool_shot.gd:17`'s fifth failure mode: a number that equals itself).
##
## `tools/balance.gd` CANNOT be used for this. `grep -n 'class_id\|set_class'
## tools/balance.gd tools/bot.gd` returns nothing — no balance run ever calls
## `set_class`, so the Boilerwright's scald trail can never occur in a balance
## run at any sample size, and RESIDUE only enters by accident, because
## `bot.gd:160` gives upgrade cards no ranking at all. A null result from that
## rig would be true and meaningless; this tool exists so the before/after
## tables in the SG-264 commit are a measurement rather than an assertion.
##
## THE RIG, lifted from `parity_test.gd`'s `_fire_stack_damage` (the check
## behind `hazard · RESIDUE's stacks are worth what they cost, measured on a
## body`), which already integrates 600 real steps at the game's own 1/60 frame
## and reads an HP delta: one `SkyGearGame` (`scenes/main.tscn`), one fire pool
## planted directly with `_field()` so no cast path or renderer is in the loop,
## one landed boarder and the captain both standing inside its radius, ten
## seconds of `_update_fire_fields(1/60)`, HP lost on each side divided by 10.
## Deterministic — no bot, no seed, no sampling error, because nothing here
## calls `move_and_slide()`.
##
##   godot --path . --headless --script res://tools/fire_bench.gd

const POOL_AT := Vector2(0.0, 600.0)
const FRAME := 1.0 / 60.0
const STEPS := 600 ## 10 s at 1/60


func _initialize() -> void: call_deferred("_run")


func _run() -> void:
	print("source          stacks   boarder dps   captain dps")
	print("--------------  ------   -----------   -----------")
	for source in SkyGearData.FIRE_SOURCES.keys():
		var row: Dictionary = SkyGearData.FIRE_SOURCES[source]
		var stack_list: Array[float] = [1.0]
		## RESIDUE gets a second row at two stacks — the whole point of the
		## table change. Every other source is `per_stack` false, so a second
		## stack would print the same number twice and say nothing.
		if bool(row.get("per_stack", false)):
			stack_list.append(2.0)
		for stacks in stack_list:
			var measured := _measure(source, stacks)
			## `quit()` only requests the tree stop AFTER this call stack
			## returns to idle — it does not unwind execution here — so an
			## empty dict (the failed-spawn sentinel `_measure` returns
			## alongside its own `quit(1)`) has to be caught explicitly or
			## the very next line nil-derefs on a missing key instead of the
			## exit code this tool already asked for.
			if measured.is_empty():
				return
			print("%-14s  %-6.1f   %-11.2f   %-11.2f"
				% [source, stacks, measured.boarder, measured.captain])
	quit(0)


## One pool, one landed boarder, one captain, both standing inside it. Returns
## {"boarder": dps, "captain": dps} — HP lost on each side over 10 s, divided
## by 10.
func _measure(source: String, stacks: float) -> Dictionary:
	var game := _new_game()
	_begin(game)
	game.spawn_queue.clear()

	game.player.global_position = POOL_AT
	game.player.invulnerability_left = 0.0
	game.player.max_hp = 1e9
	game.player.hp = 1e9

	game.spawn_enemy("SCRAPPER", 1)
	var boarder: SkyGearEnemy = null
	for e in game.get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e.game == game and not e.dead:
			boarder = e
	## A FAILED SPAWN MUST DIE LOUD, NOT PRINT A PARTIAL TABLE. Without this,
	## a `null` boarder nil-derefs on the next line mid-run, after some rows
	## have already printed — output that reads like a result but is not one.
	if boarder == null:
		push_error("fire_bench: spawn_enemy(\"SCRAPPER\", 1) produced no live boarder for source=%s stacks=%s" % [source, stacks])
		game.queue_free()
		quit(1)
		return {}
	## A FRESH BOARDER CANNOT BE HIT (board SG-134): `spawn_enemy` lands him in
	## `climb`, the arrival window, which is total immunity everywhere in the
	## damage path. `state = "move"` is `_landed()`'s own fixture line, inlined
	## because this tool has no access to `parity_test.gd`'s helpers.
	boarder.state = "move"
	boarder.state_time = 0.0
	boarder.global_position = POOL_AT
	boarder.max_hp = 1e9
	boarder.hp = 1e9

	game.fire_fields.clear()
	game._field({"position": POOL_AT, "source": source, "stacks": stacks,
		"time": 999.0, "tick": 0.0})

	var boarder_before: float = boarder.hp
	var captain_before: float = game.player.hp
	for _tick in STEPS:
		game.state = SkyGearGame.State.PLAY
		game._update_fire_fields(FRAME)
		game.player.invulnerability_left = maxf(0.0, game.player.invulnerability_left - FRAME)
	var boarder_dealt: float = boarder_before - boarder.hp
	var captain_dealt: float = captain_before - game.player.hp

	game.queue_free()
	return {"boarder": boarder_dealt / 10.0, "captain": captain_dealt / 10.0}


## Lifted from `parity_test.gd:_new_game` — no workshop, no berthed set off a
## real save, so this tool measures the table rather than the developer's own
## progress.
func _new_game() -> SkyGearGame:
	var scene: PackedScene = load("res://scenes/main.tscn")
	var game: SkyGearGame = scene.instantiate()
	root.add_child(game)
	if game.impact != null:
		game.impact.enabled = false
	game.workshop = SkyGearWorkshop.fresh(true)
	game.refresh_berthed()
	return game


## Lifted from `parity_test.gd:_begin`.
func _begin(game: SkyGearGame, seed_text: String = "FIREBENCH") -> void:
	game.set_seed_text(seed_text)
	game.begin_run()
	game.choose_draft(0)
