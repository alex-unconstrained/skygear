extends SceneTree
## Who is actually killing things?
##
## A real run came back with crew and cannons on 46% of all damage — nearly half
## the fight, done by allies the player does not control. The reading was that
## they should soak and hold rather than kill. That is a tuning question, and a
## tuning question answered by playing three runs is answered by noise.
##
## This plays the whole twelve waves headless, several times, on fixed seeds, and
## reports the damage split. Same numbers as the run report, so a change here can
## be checked against a real run afterwards.
##
##   godot --path . --headless --script tools/balance.gd
##   godot --path . --headless --script tools/balance.gd -- 5     (runs)
func _initialize() -> void: call_deferred("_run")

const SEEDS := ["BAL1", "BAL2", "BAL3", "BAL4", "BAL5", "BAL6"]

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var count: int = int(args[0]) if args.size() > 0 else 3
	var ally_share := 0.0
	var player_share := 0.0
	var waves_reached := 0.0
	var wins := 0
	for i in mini(count, SEEDS.size()):
		var r := await _one(SEEDS[i])
		ally_share += float(r.ally)
		player_share += float(r.player)
		waves_reached += float(r.wave)
		wins += 1 if bool(r.won) else 0
		print("  %-6s wave %2d %-10s  player %3.0f%%  allies %3.0f%%  deck %3.0f%%"
			% [SEEDS[i], int(r.wave), "HELD" if bool(r.won) else "lost",
				float(r.player), float(r.ally), float(r.deck)])
	var n := float(mini(count, SEEDS.size()))
	print("")
	print("  across %d runs: %d held, average wave %.1f" % [int(n), wins, waves_reached / n])
	print("  player %.0f%%   allies %.0f%%" % [player_share / n, ally_share / n])
	print("")
	## The target the balance pass is aiming at, stated so a later run can be
	## judged against it rather than against a feeling.
	var allies: float = ally_share / n
	if allies > 30.0:
		print("  OVER TARGET — allies should hold lanes, not clear them. Want under 30%.")
	else:
		print("  allies at %.0f%%: holding rather than clearing." % allies)
	quit(0)


func _one(seed_text: String) -> Dictionary:
	var game: SkyGearGame = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	if game.impact != null:
		game.impact.enabled = false
	game.set_seed_text(seed_text)
	game.begin_run()
	game.choose_draft(0)
	## A competent-but-not-optimal player: casts what is off cooldown at whatever
	## is nearest, keeps moving, never kites to max range.
	var steps := 0
	while game.state_name == "PLAY" or game.state_name == "DRAFT":
		if game.state_name == "DRAFT":
			game.choose_draft(0)
		game._process(0.05)
		for e in game.get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(e):
				e._physics_process(0.05)
		if steps % 4 == 0:
			var target: SkyGearEnemy = game.nearest_enemy(game.player.global_position, 900.0)
			if target != null:
				for slot in game.skills.size():
					if float(game.skills[slot].cooldown_left) <= 0.0:
						game.cast_skill(slot, target.global_position)
						break
		steps += 1
		if steps % 200 == 0:
			await process_frame
		if steps > 40000:
			break

	var tel: Dictionary = game.tel
	var total: float = float(tel.basic.damage) + float(tel.deck.damage) + float(tel.allies.damage)
	for row in tel.per:
		total += float(row.damage)
	total = maxf(1.0, total)
	var player_dmg: float = float(tel.basic.damage)
	for row in tel.per:
		player_dmg += float(row.damage)
	var out := {
		"wave": game.wave,
		"won": game.state_name == "VICTORY",
		"player": player_dmg / total * 100.0,
		"ally": float(tel.allies.damage) / total * 100.0,
		"deck": float(tel.deck.damage) / total * 100.0,
	}
	game.queue_free()
	await process_frame
	return out
