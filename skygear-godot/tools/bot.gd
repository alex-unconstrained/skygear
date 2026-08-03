extends RefCounted
## THE BOT THAT PLAYS THE SIMULATED RUNS (SG-118).
##
## This used to be a few lines inside `tools/balance.gd`'s loop, and what those
## lines did was cast — the loop issued NO movement input at all while a comment
## beside it said the bot "keeps moving". Every balance verdict this project has
## ever recorded was therefore measured against a captain standing on her spawn
## point, SG-57's tempo half included.
##
## It is a file of its own now for one reason: **the bot's behaviour is a
## published fact, because things get measured against it.** A policy buried in
## a loop is a policy nobody can test, and an untested policy is how a rig ends
## up claiming a movement it does not perform. The harness drives THIS object,
## so the thing under test and the thing that produces the numbers are the same
## code — see `bot ·` in `tests/parity_test.gd`.
##
## WHAT SHE DOES
##
## She steers analog through the real input map — `Input.action_press` with a
## strength, read back by `Input.get_vector` inside `player._physics_process`,
## the same path a keyboard takes. It has to go through the input map because
## `input_direction` is a local inside `_physics_process` and is not a field
## anything can set; the mobility check learned that the hard way.
##
##   1. THE BAND. She holds `BAND` = 210 units from the nearest enemy, which is
##      `SkyGearData.CLOSE.range` — the radius the captain's PRESSURE gauge
##      fills inside. Past the band she closes; inside 0.55x it she backs off;
##      within it she CIRCLE-STRAFES, so she is moving whenever there is
##      anything on the deck to fight rather than standing at a nice distance.
##   2. OUT OF THE FIRE SHE IS STANDING IN, weighted 2x — and only that one. She
##      does not route around a pool she is clear of. The asymmetry is deliberate
##      and it is what "competent, not optimal" honestly means: a real player
##      walks out of a pool they are caught in; they do not plan around one they
##      are nowhere near. It also matters for SG-117 — a bot that dodged fire
##      perfectly would make a fire fix look free.
##   3. OFF THE WALLS within `EDGE`, so a retreat cannot park her in a corner
##      where the band is unreachable and she reads as stationary all over again.
##   4. THE DEFENSIVE DASH, and only that: something inside `DASH_AT` and a
##      charge up. Called through `_try_dash` rather than a synthesized keypress
##      because `is_action_just_pressed` is keyed to engine frames a hand-stepped
##      loop never runs. Kept rare on purpose — dash grants i-frames, and a bot
##      that dashed on cooldown would carry a background immunity that quietly
##      flatters anything measuring how often she is hittable.
##
## WHAT SHE STILL DOES NOT DO, stated because it is the first thing to suspect
## when a result surprises you: she never repairs, never shoves a crate, never
## works the deck, and never retreats from a wave she is losing. Those are the
## remaining bot facts.

## Named here rather than read from the table so the bot's policy cannot change
## silently underneath a recorded measurement when a tuning pass moves a number.
## `BAND` is `SkyGearData.CLOSE.range` as of 2026-08-03; the check
## `bot · the bot's band is the gauge's own range` fails if they ever diverge.
const BAND := 210.0
const BAND_NEAR := 0.55   ## inside this fraction of the band she backs off
const BAND_FAR := 1.00    ## beyond this fraction she closes
const EDGE := 140.0       ## steer off a deck wall this close
const DASH_AT := 90.0     ## dash defensively only when something is this close
const FIRE_RADIUS := 78.0 ## `_update_fire_fields`' own number

const ACTIONS := ["move_left", "move_right", "move_up", "move_down"]


## The direction she WANTS to travel this tick, as a unit vector, or ZERO for
## "no opinion". Split out from `steer` so the policy can be tested as
## arithmetic — without an input map, without a physics step, and without
## needing a frame to observe it.
func desired(game: SkyGearGame) -> Vector2:
	if game.player == null or not is_instance_valid(game.player):
		return Vector2.ZERO
	var here: Vector2 = game.player.global_position
	var want := Vector2.ZERO

	var target: SkyGearEnemy = game.nearest_enemy(here, 4000.0)
	if target != null:
		var to_them: Vector2 = target.global_position - here
		var span := to_them.length()
		if span > 1.0:
			var dir := to_them / span
			if span > BAND * BAND_FAR:
				want += dir
			elif span < BAND * BAND_NEAR:
				want -= dir
			else:
				## Perpendicular, with a slight inward bias so she does not
				## spiral off the band over a long wave.
				want += Vector2(-dir.y, dir.x) * 0.85 + dir * 0.15

	for field in game.fire_fields:
		var away: Vector2 = here - (field.position as Vector2)
		var reach := away.length()
		if reach < FIRE_RADIUS:
			want += (away / reach if reach > 1.0 else Vector2.UP) * 2.0

	var deck: Rect2 = SkyGearGame.DECK_RECT
	if here.x - deck.position.x < EDGE:
		want.x += 1.0
	elif deck.end.x - here.x < EDGE:
		want.x -= 1.0
	if here.y - deck.position.y < EDGE:
		want.y += 1.0
	elif deck.end.y - here.y < EDGE:
		want.y -= 1.0

	return want.normalized() if want.length_squared() > 0.0 else Vector2.ZERO


## One tick of play: press the keys `desired` asks for, and take the dash if the
## deck has closed on her. Call it BEFORE stepping the player, so the input she
## acts on is the one that matches the deck she is about to be stepped through.
func steer(game: SkyGearGame) -> void:
	release()
	if game.player == null or not is_instance_valid(game.player):
		return
	## Movement lives behind `controls_enabled`; between waves it is false and a
	## held key would be a key held through a draft.
	if not game.player.controls_enabled:
		return
	var move := desired(game)
	if move == Vector2.ZERO:
		return
	## Analog: `get_vector` reads action STRENGTH, so a unit vector goes in as a
	## unit vector rather than being quantised to the eight compass points. The
	## input map's 0.2 deadzone applies to the resulting length, which is 1.
	if move.x > 0.0: Input.action_press("move_right", move.x)
	elif move.x < 0.0: Input.action_press("move_left", -move.x)
	if move.y > 0.0: Input.action_press("move_down", move.y)
	elif move.y < 0.0: Input.action_press("move_up", -move.y)

	var target: SkyGearEnemy = game.nearest_enemy(game.player.global_position, 4000.0)
	var cornered := (target != null
		and game.player.global_position.distance_to(target.global_position) < DASH_AT
		and game.player.dash_charges > 0
		and game.player.dash_time_left <= 0.0)
	if cornered:
		game.player._try_dash(move)


## `Input` is a process-wide singleton. A key left down outlives the run that
## pressed it and would open the next one mid-stride.
func release() -> void:
	for action in ACTIONS:
		Input.action_release(action)
