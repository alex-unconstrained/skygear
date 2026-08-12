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
## HOW SHE DRAFTS (SG-130), and why the rule is written the way it is.
##
## **THE POLICY IN ONE SENTENCE: she takes the best card she is offered, where
## "best" is a fixed published order over the CARD, and the number of cards on
## the table is not part of the decision.**
##
## The order is `DRAFT_ORDER`: the six active shapes in the catalogue's own
## order, then the two passives — Field and Pulse — last. Ties, and any draft of
## cards that are not weapons at all (the upgrade drafts), go to the first card
## offered. That is the whole rule. `draft_pick` never reads `options.size()`.
##
## THIS REPLACES A RULE THAT DID READ THE COUNT, and the replacement is the
## point of SG-130. The old rule preferred a passive when the draft offered <=4
## cards and took cell 0 when it offered more. THE OPENING BID's entire mechanic
## is that a weapon draft becomes the 32-cell matrix, so signing that Article
## silently swapped the bot for a different bot: measured passive share was
## 5.20% in the baseline arm and 0.00% in the bid arm, 114 of 120 runs against
## 0 of 120. The two arms differed in the vow AND in who was playing them, and
## no comparison across them could be attributed to the vow.
##
## WHY PASSIVES RANK LAST, since that is the part with a judgement in it.
##
##   1. It is what the repository already measured. A drafted passive returns
##      about 5% of a run's damage for a whole slot; `balance.gd` prints that
##      finding under every batch. Ranking last is the competent read, not a
##      thumb on any scale — and "competent, not optimal" is this bot's whole
##      character.
##   2. It is the ONLY ranking that keeps passive share width-invariant. There
##      are two passive shapes out of eight, so a draft of three or more
##      DISTINCT shapes always contains an active: with passives last she takes
##      a passive only when the game leaves her nothing else — COLD DECK's
##      two-card hand, or The Second Hand's fifth draft, which deals passives
##      exclusively. Widening the offer cannot hand her one. Rank passives ANY
##      HIGHER and widening the offer makes a passive strictly more likely to be
##      present and therefore taken, which re-creates SG-130 in a gentler form.
##      **So this is not a free choice: an order that puts a passive above any
##      active reconfounds every Article that changes draft width.**
##
## THE LEMMA THAT LETS YOU READ AN ARM WITHOUT RE-DERIVING ANY OF THIS, and the
## most reusable thing SG-130 produced. Actives occupy ranks 0..5 and passives
## 6..7, so the minimum rank offered is a passive's ONLY when no active is on the
## table at all:
##
##     **`draft_pick` returns a passive IF AND ONLY IF every card offered is a
##     passive.**
##
## It is an identity, not a tendency, and it converts a statistical question into
## a structural one. **Any residual gap in passive rate between two arms is a
## difference in what the GAME OFFERED, never a difference in what she
## PREFERRED.** That is the exact opposite of the bug: under the old rule the two
## arms held different preferences, which is why nothing measured across them
## meant anything. Under this rule they hold the same preference and the offer
## does the rest — so a gap is attributable to whatever changed the offer, which
## is the thing you were trying to measure.
##
## WORKED EXAMPLE, from the SG-130 re-run itself, because the number surprises
## people: at Heat 3 the baseline arm still drafted a passive in 37 of 120 runs.
## That is not the bug coming back. HEAT 3 IS COLD DECK, which caps the hand at
## two cards, and as held shapes leave the pool a two-card deal can be Field and
## Pulse and nothing else. By the lemma those 37 runs are precisely the runs
## where the game offered her no active weapon. The check
## `bot · she takes a passive only when the draft leaves her nothing else` is
## that lemma as a harness assertion, and it goes red on the old rule.
##
## THE PASSIVE PROBE. Asking "is a passive worth a slot?" needs a captain who
## deliberately drafts one, and that is what the old rule was reaching for. It
## is an explicit flag now — `passive_probe`, which inverts the order so the two
## passives rank FIRST — rather than something a draft width switches on by
## accident. **It is an instrument, not an arm. A probe run may only be compared
## with another probe run; never put one beside a normal arm.**
##
## WHAT SHE STILL DOES NOT DO, stated because it is the first thing to suspect
## when a result surprises you: she never repairs, never shoves a crate, never
## works the deck, never rerolls a draft, and never retreats from a wave she is
## losing. Those are the remaining bot facts.

## Named here rather than read from the table so the bot's policy cannot change
## silently underneath a recorded measurement when a tuning pass moves a number.
## `BAND` is `SkyGearData.CLOSE.range` as of 2026-08-03; the check
## `bot · the bot's band is the gauge's own range` fails if they ever diverge.
const BAND := 210.0
const BAND_NEAR := 0.55   ## inside this fraction of the band she backs off
const BAND_FAR := 1.00    ## beyond this fraction she closes
const EDGE := 140.0       ## steer off a deck wall this close
const DASH_AT := 90.0     ## dash defensively only when something is this close

const ACTIONS := ["move_left", "move_right", "move_up", "move_down"]

## HER DRAFT ORDER, best first. Named here rather than derived at the point of
## use for the same reason `BAND` is: a recorded measurement must not change
## meaning because somebody reordered a table. The check
## `bot · the draft order is the catalogue's, with the passives at the back`
## fails if this stops being exactly the draftable shapes with every passive
## behind every active.
const DRAFT_ORDER := ["CHAIN", "RANGED_AOE", "CONE", "LINE_BURST", "RAY",
	"SENTRY", "AURA", "PULSE"]

## Prefer the passives instead — the "is a slot spent on a Field worth it?"
## instrument, off by default. Read the header before you set it: a probe run is
## not an arm and may only be compared with another probe run.
var passive_probe := false


## Where a card sits in her order — lower is better. A pure function of the
## CARD, which is the whole of SG-130: nothing here reads how many other cards
## are on the table, so widening a draft cannot change what she thinks of any
## card in it.
func rank_of(option: Variant) -> int:
	var shape := ""
	if option is Dictionary:
		var skill: Variant = (option as Dictionary).get("skill", {})
		if skill is Dictionary:
			shape = str((skill as Dictionary).get("shape", ""))
	if shape == "":
		## Not a weapon card — the upgrade drafts. She has no opinion, so every
		## card ranks the same and the tie-break below takes the first offered.
		return DRAFT_ORDER.size()
	var at := DRAFT_ORDER.find(shape)
	if at < 0:
		return DRAFT_ORDER.size()
	if passive_probe and bool(SkyGearData.SHAPES.get(shape, {}).get("passive", false)):
		## Ahead of every active, keeping the passives' order among themselves.
		return at - DRAFT_ORDER.size()
	return at


## Which card she takes: the best-ranked one offered, ties to the first offered.
## Call it for EVERY draft, including the opening one — that draft is a 32-cell
## matrix under The Opening Bid too, so hard-coding cell 0 there would leave
## half of SG-130 unfixed.
func draft_pick(options: Array) -> int:
	var best := 0
	var best_rank := 1 << 30
	for i in options.size():
		var rank := rank_of(options[i])
		if rank < best_rank:
			best_rank = rank
			best = i
	return best


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
		## Reads the pool's OWN radius (board SG-164) rather than a private
		## constant she used to keep a second copy of, or she flees a pool by a
		## remembered number instead of the one that is actually burning.
		if reach < float(field.radius):
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
