class_name SkyGearGame
extends Node2D

enum State { TITLE, PLAY, DRAFT, PAUSE, GAMEOVER, VICTORY }

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const PROP_SCENE := preload("res://scenes/prop.tscn")
## The shared screen poser (board SG-44) — the same list and the same `pose()`
## the text audit and the batch camera run, reached by the F4 picker. Preloaded,
## not `class_name`: see the note at the top of `scripts/screen_poser.gd`.
const ScreenPoser := preload("res://scripts/screen_poser.gd")
const GAME_SCENE_PATH := "res://scenes/main.tscn"

const DECK_RECT := Rect2(-840, -1160, 1680, 2320)
const BOILER_POSITION := Vector2(0, 850)
const LANE_CENTERS := [-560.0, 0.0, 560.0]
const CARGO_RECTS := [
	Rect2(-340, -870, 120, 300),
	Rect2(-340, -370, 120, 270),
	Rect2(-340, 130, 120, 280),
	Rect2(-340, 620, 120, 250),
	Rect2(220, -870, 120, 300),
	Rect2(220, -370, 120, 270),
	Rect2(220, 130, 120, 280),
	Rect2(220, 620, 120, 250),
]

## THE CRATE-MOVING FAMILY IS TABLED (board SG-68). The owner, 2026-08-02:
## "the current push crate mechanic is boring. table that feature for now we
## can revisit interactions like that later." TABLED, not deleted — this one
## flag gates the whole family so the revisit is flipping a line, not an
## archaeology dig: the shove verb and the winch verb leave the deckwork
## table (`SkyGearDeckwork.actions`), the movable crate becomes an ORDINARY
## stowed prop at its home (`_stow_barricade` — no cargo rect, no funnel, no
## x-ray shadow, no verb target), the coach's shove line goes quiet (it is
## gated on `barricade`, which stays null), the HUD prompt never draws (no
## verb is ever offered), and THE WINCH fitting is unavailable
## (`SkyGearFittings.tabled`: unearnable, unberthable, shown as TABLED on
## THE BERTHS). A `static var` rather than `const` ONLY so the harness can
## flip it in a sandbox and prove the family comes back whole
## (`deckwork · the tabled verbs come back with one flag`); nothing in the
## shipped game ever writes it.
static var CRATE_VERBS_ENABLED := false

## THE DRAGGABLE CRATE — the deckwork verb "HEAVE THE CRATE" (board SG-10).
##
## A movable cargo stack the captain heaves across the PORT lane to funnel the
## boarders walking down it. The eight rects above are the fixed lane walls; this
## is the one piece of cargo that moves, and it moves because a player decided to
## reshape where the fight happens.
##
## BALANCE IS GEOMETRY, not a new currency. `BARRICADE_SIZE.x` is 150 against a
## 380-unit lane band, so one crate NARROWS a lane and can pin the whole column to
## one side of it — but it can never wall the lane shut for free, which is the
## thing that would trivialise funnelling. The only cost is the seconds out of the
## fight, the sharpest cost the deck has (see `scripts/deckwork.gd`).
##
## `BARRICADE_STAGES` are the crate-centre x per heave, all at one y: stowed among
## the bow cargo (blocks no lane), narrowing the band, then pinned to the inboard
## edge so the port lane funnels outboard. A heave cycles 0 -> 1 -> 2 -> 0, so the
## same key that closes the flank also opens it again.
const BARRICADE_SIZE := Vector2(150.0, 130.0)
const BARRICADE_Y := -480.0
const BARRICADE_LANE := 0
const BARRICADE_STAGES := [-280.0, -560.0, -450.0]
## The shove is instant (board SG-37), so the cost that stops it being
## machine-gunned across the deck is this per-crate cooldown rather than seconds
## of standing still. ~1s: long enough to feel deliberate, short enough that
## re-shaping a collapsing lane is never a waiting game. Tune to feel.
const BARRICADE_COOLDOWN := 1.0

## THE WINCH — the deckwork verb the WINCH fitting grants (board SG-56, built
## to the SG-37 lesson: instant tap, never a channel, and the crate can never
## trap the captain). Each tap hauls the nearest crate STACK a fixed distance
## toward her — the player placing their own cover, which is the only laning
## the simulation supports (boarders are on rails, SHIP-AND-MAPS §2) — and it
## stops short of her by WINCH_GAP so a stack can never land on the spot she
## is standing on. The cost is the same shape as the shove's: a short cooldown
## rather than seconds standing still.
const WINCH_STEP := 150.0
const WINCH_GAP := 90.0
const WINCH_COOLDOWN := 1.0

## THE MOST ALLIED UNITS THAT CAN EVER BE ALIVE AT ONCE — standing crew (the
## muster, the press-gang, anything a card spawns) plus deployed sentries,
## counted together by `allies_alive()` and refused at the door (board SG-62).
## Crew had NO ceiling: a muster is 3 lanes × (2 + Muster Roll) = up to 9 every
## 14 seconds, crew never expire, and on a deck the player clears before the
## boarders reach them the count only climbs — the no-attrition arithmetic is
## 700+ by a run's end. The number: the lane layer's own doctrine is "a dozen
## crew" (lanes.gd), a full double muster arriving on top of that is 9 more,
## and the fattest sentry loadout is 8 (2 per slot × 4 slots, their own
## retire-oldest law) — 12 + 9 + 8 = 29, so 32 with margin. It bites nothing
## the game intends and everything runaway.
const ALLY_CAP := 32

@onready var player: SkyGearPlayer = $Player
@onready var hud: SkyGearHUD = $HUD/Overlay
var audio: SkyGearAudio
## The captain, her crew and the thing in the last wave. Every line below sits
## on top of a mechanical cue that already fires, so the layer is flavour and
## never information — see `scripts/voice.gd` for why that rule exists.
var voice: SkyGearVoice
## Hit-stop and shake. The one thing in this project allowed to scale time, and
## it does it by handing the simulation a smaller delta rather than by touching
## `Engine.time_scale` — a global scale also slows the animation blends, the
## music and the voice, which is not a hit landing, it is the game skipping.
var impact: SkyGearImpact
## Frame cost and scene counts, always on. F3 shows it. Costs a float write a
## frame, which is less than the cost of never knowing why a build got slow.
var profiler: SkyGearProfiler
var show_profiler := false
## The 3D renderer, when it is the one drawing. Set by `SkyGearView3D` so the
## simulation can tell it a hit happened without knowing anything else about it.
var view: SkyGearView3D
var _said_first_board := false
var _said_boiler_low := false

var rng := RandomNumberGenerator.new()
## A SECOND stream, for anything that only affects the picture.
##
## The browser build keeps these apart deliberately and this is why: damage
## numbers were given a little random scatter so a stack of them is readable,
## the scatter was drawn from `rng`, and every crit roll, scrap roll and spawn
## jitter for the rest of the run shifted by however many boarders had been hit.
## A seed has to reproduce a run, so nothing cosmetic may touch it.
## SEEDED, since board SG-120 — from the run's own seed text XOR `VISUAL_SALT`,
## in `set_seed_text`. "Cosmetic" was never quite true: the `extra_kegs` talent
## places real, explosive kegs from this stream.
var visual_rng := RandomNumberGenerator.new()
## THERE WAS BRIEFLY A THIRD STREAM. Board SG-48 built SHIP-AND-MAPS §4 as
## written — `layout_rng`, a STOWAGE table, a per-wave seeded deal — and then
## ran the §7.1 kill-test the design pre-committed to: `tools/balance.gd`,
## six seeds × ten reps, deal live against deal flat. Close-share came back
## indistinguishable (5.38% vs 5.25%, t≈0.36), and so did everything else the
## bot measures. The rule was written before the numbers existed: variety
## that does not change where you stand is cosmetic AND GETS CUT, not tuned.
## The whole spine — stream, table, `tools/stow.gd`, seven checks, the
## kill-test lever — lives at commit d10f09c if a sharper instrument ever
## re-asks the question. What survived is the POWDER STORE spacing fix in
## `restow_props`, which was a real §7.3 bug regardless (board SG-51).
var state := State.TITLE
var state_name := "TITLE"
var wave := 0
var wave_time := 0.0
## HOW LONG "WAVE CLEAR" HOLDS before the draft opens. It was a literal at the
## one place it is assigned, which is fine until something outside the simulation
## needs to know how long the beat lasts — and something does now: the arrival
## transport rides this countdown back to its ambient station
## (`view3d.gd::arrival_u`), so the hull is home on the frame the draft appears.
## Same lesson as `SkyGearEnemy.TURN_TIME`: a renderer that re-declares a window
## the sim owns is two files holding one number.
const WAVE_CLEAR_TIME := 1.6
var wave_clear_time := -1.0
var spawn_queue: Array[Dictionary] = []
var skills: Array[Dictionary] = []
var draft_options: Array[Dictionary] = []
var opening_draft := false
## Raised by `begin_run`, spent by `view3d.gd::_watch_cues` the first frame the
## deck reaches PLAY — the establishing `run_open` shot cannot fire from here,
## because `begin_run` settles into the opening DRAFT and a cutscene is stopped
## the moment the game is in a menu (`cutscene_player.advance`). So the code
## line is a flag, and the watcher fires the cue where a camera is allowed to.
var run_opening := false
var boiler_hp := 500.0
## The Boiler's own health. BOILER_BASE_HP is a const because `begin_run` has to
## be able to return to it: the talent below is `+=`, and without a reset every
## run in a session compounded the last one's maximum (board SG-260).
const BOILER_BASE_HP := 500.0
var boiler_max_hp := BOILER_BASE_HP
var boiler_position := BOILER_POSITION
var boiler_radius := 62.0
var end_reason := ""
var basic_cooldown := 0.0
## HOW MANY BASIC SWINGS HAVE ACTUALLY RESOLVED (design §17.7, board SG-208).
##
## Not how many times the swing came off cooldown, and not how many bodies were
## standing in the fan: it counts the swings that FOUND something — a hittable
## body or a vulnerable hull — and bit it. That is the whole of why it exists.
## A miss that advanced it would leave the side tell on the deck pointing one
## way and the next cut's damage resolving the other, for the rest of the fight;
## an increment inside the cone loop would do the same after every crowd.
##
## Reset by `begin_run`, like every other thing about a run in progress.
var basic_swing_serial := 0
## THE AUTO-ATTACK'S ELEMENT, AND WHERE THE CHOICE LIVES (board SG-99, from the
## build-44 playtest: *"Can we get a way to change the auto-attack to another
## element? So it's not always fire?"*).
##
## IT LIVED ON THE TITLE SCREEN AND IT IS A WAVE-4 CHOICE NOW (board SG-275).
##
## SG-99 put it on a plate directly under WHO IS ABOARD, and ruled out the three
## alternatives for reasons that are worth keeping because two of them still
## hold:
##
##   * **A card** would have been cheapest to build — `cards.gd` already has
##     RETUNE CORE, which re-elements a slot — but a card is DEALT. "So it's not
##     always fire" is a request about every run, and an answer that arrives in
##     some runs is not one.
##   * **The opening weapon draft** deals SHAPES; the Cleave is deliberately not
##     among them (`DRAFT_SHAPES`), and the matrix the Opening Bid opens is
##     8 draftable shapes × 4 elements. Putting the auto in there changes that
##     arithmetic and puts the Cleave back on a card.
##   * **A Workshop node** would gate a flavour choice behind scrip, which makes
##     "not always fire" a thing you grind for.
##
## WHAT THE OWNER CHANGED, 2026-08-12, after playing it: *"I don't think we
## should have the player pick the element of their cleave before they start
## playing. I think that should happen maybe as a bonus on round four, because at
## that point they would have kind of settled on what element they want to focus
## on."* SG-99 answered "where can this live" and got the timing wrong — the
## choice was being asked at the one moment in the run when the player has no
## information to answer it with. By wave 4 the hand is full and the build has a
## colour, and the question is about that build instead of about nothing.
##
## AND IT IS STILL NOT A CARD, WHICH IS WHY SG-99's FIRST BULLET SURVIVES. The
## offer is not dealt: it is NAMED, rng-free, at a fixed wave, and it does not
## replace the draft the player was owed — `choose_draft` re-opens the normal
## draft behind it. It arrives in every run that reaches wave 4, and it consumes
## no RNG at all, which is the `_bid_matrix` precedent and the only reason it can
## exist without shifting every seeded card deal, crit and spawn jitter.
##
## `""` means "whatever the class brings" — so a player who never takes the offer
## gets a byte-identical run to the one they got before this existed.
var auto_element := ""
## AND IT IS RESET BY `begin_run` NOW, WHICH IT DELIBERATELY WAS NOT. While the
## choice was made before the run it belonged with `class_id` and `heat` — a
## property of the run you are ABOUT to start. It is made DURING the run now, so
## leaving it standing would carry run one's Frost Cleave silently into run two.
## That is `boiler_max_hp`'s bug (SG-271) by another route, and the rule it broke
## is the same one: a thing chosen inside a run is cleared when the next one
## starts.
func auto_element_id() -> String:
	if auto_element != "" and SkyGearData.ELEMENTS.has(auto_element):
		return auto_element
	return str(class_data().get("auto", {}).get("element", "EMBER"))


## "Ember Cleave", "Frost Scald" — one function, so the report, the run log and
## anything else that names the basic attack cannot drift from what it fires.
func auto_name() -> String:
	return "%s %s" % [str(SkyGearData.ELEMENTS[auto_element_id()].name),
		str(class_data().get("auto", {}).get("name", "Cleave"))]


## THE WAVE THE CORE IS OFFERED ON, and it is the owner's number: *"maybe as a
## bonus on round four"*. Named once because three readers ask — the draft that
## deals it, `begin_run` that clears the latch, and the harness.
##
## FOUR IS ALSO WHERE THE HAND IS FULL, which is why the number is not three or
## five. The opening draft deals the first weapon and waves 1, 2 and 3 deal the
## rest, so the draft that opens when wave 4 clears is the first one at which the
## player is choosing ABOUT a build rather than still assembling one. That is the
## "settled on what element they want to focus on" the ask names, in the
## schedule's own terms.
##
## IT IS INSIDE THE DEMO CUT TOO. `SkyGearDemo.last_wave()` is 6, so a demo run
## reaches wave 4 and gets the offer — no second branch, no second number.
const CORE_WAVE := 4

## Whether this run has already been offered the core. A LATCH rather than a
## `wave == CORE_WAVE` test at the point of use, because the draft can be
## re-entered — `reroll_draft` calls `open_draft` again on the same wave — and an
## offer that re-deals itself would let a player take it, reroll, and take it
## again. Cleared by `begin_run` with everything else about a run in progress.
var core_offered := false


## THE FOUR CORES, AS A DRAFT. Named, never dealt: every element every time, in
## the table's own order, and there is no `rng` call anywhere in it. That is the
## `_bid_matrix` precedent and it is what lets this exist without moving a single
## seeded card, crit or spawn jitter in the run it sits in the middle of.
##
## THE ONE HE ALREADY SWINGS IS IN THE LIST, and that is deliberate. Offering
## only the other three would make this a forced re-tune, and "keep what I have"
## is a real answer to a question about a build you have settled into — the more
## so because the class picked this element for him without ever saying so.
##
## The card carries `shape: CLOSEHIT` so the face draws the Cleave's own slash
## glyph rather than a themed fallback: `SkyGearCards.emblem_shape` reads
## `card.shape` for exactly this case. The scope is CAPTAIN because that is what
## it affects — his basic attack — and `affects()` returns no lit slot glyphs for
## it, which is true: re-tuning the core touches none of the four weapons.
func _core_offer() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var weapon: String = str(class_data().get("auto", {}).get("name", "Cleave"))
	var here := auto_element_id()
	for element in SkyGearData.ELEMENTS.keys():
		var id := str(element)
		out.append({
			"kind": "core",
			"element": id,
			"shape": "CLOSEHIT",
			"scope": SkyGearCards.SCOPE_CAPTAIN,
			"class_label": SkyGearCards.SCOPE_LABEL[SkyGearCards.SCOPE_CAPTAIN],
			"rarity": SkyGearCards.RARITY_DEFAULT,
			"title": ("%s %s" % [str(SkyGearData.ELEMENTS[id].name), weapon]).to_upper(),
			## The card that is already true says so, so "keep it" is visibly an
			## option rather than a card that looks identical to the other three.
			"text": ("what you already swing · %s" if id == here
				else "re-tune the core · %s") % str(SkyGearData.ELEMENTS[id].blurb),
		})
	return out


## Is the draft currently on screen the core offer? Asked by the reroll (which
## refuses it) and by the HUD (which draws no reroll strip over it), off the
## OPTIONS rather than off `wave` or the latch — because what those two callers
## need to know is what is in front of the player right now, and only the options
## can answer that after a reload or inside a posed screen.
func core_draft() -> bool:
	if draft_options.is_empty():
		return false
	return str((draft_options[0] as Dictionary).get("kind", "")) == "core"
var pressure := 0.0
var pressure_grace := 0.0
## Which captain is aboard. The gauge, the speed, the health and whether there
## is a dash at all come from here — see `SkyGearData.CLASSES`.
var class_id := "captain"
## Cracked steam mains, the Boilerwright's one new simulation object. Same shape
## as `fire_fields` on purpose.
var taps: Array[Dictionary] = []
var tap_cooldown := 0.0
var vent_cooldown := 0.0
var damage_multiplier := 1.0
## LONG ARMS. A separate multiplier from the per-skill one so a talent and a card
## cannot overwrite each other.
var range_multiplier := 1.0
var projectiles: Array[Dictionary] = []
var effects: Array[Dictionary] = []
## Damage and healing, as numbers that leave the body they came from. The
## browser has had these since v2 and they are not decoration: a fight where
## every hit looks the same is a fight you cannot tune a build against, and the
## whole v11 upgrade system asks the player to notice which skill is carrying.
var floaters: Array[Dictionary] = []
var salvage: Array[Dictionary] = []
var fire_fields: Array[Dictionary] = []
var dash_hit_ids := {}

## v11.2 parity. `mods` is every global modifier a card can move; `tel` is what
## the player actually did, which the draft reads to decide which slot an
## upgrade should land on.
var mods: Dictionary = SkyGearCards.fresh_mods()
var tel: Dictionary = SkyGearTelemetry.fresh()
var rerolls := 0
var seed_text := ""
var src_slot := -1                  ## slot currently resolving, for attribution
var heal_budget := 0.0
var steal_budget := 0.0
var cards_taken: Array[String] = []
var run_time := 0.0
## Whether the last finished run reached the disk. Shown on the results screen,
## because a run log that silently is not being written is worse than none.
var run_logged := false
## Where the cursor is on the deck, as the 3D view sees it.
##
## The 2D scene is hidden, so `get_global_mouse_position()` on it answers a
## question about a space nobody is looking at. The renderer that owns the camera
## owns the answer; this is where it puts it. Unset in the plain 2D scene, which
## still uses the 2D mouse and is still what the harness drives.
var cursor_ground := Vector2.ZERO
var cursor_valid := false


func set_cursor_ground(at: Vector2) -> void:
	cursor_ground = at
	cursor_valid = true


## The point every skill aims at. One place, so a cast, the captain's facing and
## the renderer cannot disagree about where the player is pointing.
func aim_target() -> Vector2:
	if cursor_valid:
		return cursor_ground
	return player.get_global_mouse_position()
## The controls screen. `rebinding_index` is which row is listening for a key,
## or -1; `rebind_conflict` is the action that already owns the last key tried.
## The HUD layout editor (F4). State lives here rather than in the HUD because
## the HUD is a view and input belongs to the thing that owns input.
var layout_edit := false
var layout_pick := "captain"
## Which element INSIDE the selected plate is being edited, or "" for the plate
## itself. Panel-level placement was not enough: a glyph can sit off-centre in
## its own slot, and the only fix was another round trip through me.
var layout_item := ""
var layout_saved := false
## Why the last Ctrl+S wrote nothing, or "" — shown in the alarm colour, because
## a save that silently does nothing is the bug that was reported (SG-83).
var layout_save_error := ""
var _layout_drag := ""
var _layout_resize := false
var _layout_from := Vector2.ZERO
## The SCREEN mode's selection (SG-42) — every screen that is not the gameplay
## HUD. A panel index into `hud.edit_panels` (0 is the page, -1 nothing), then a
## selected element key inside it. Two levels, same as the plates.
var layout_panel := -1
var layout_key := ""
## The typed-offset box (the SG-39 pattern: click the number, type, Enter
## applies, Esc cancels, malformed refused). `layout_sizing` says WHICH of the
## two readouts is open: the offset pair, or the w×h pair (SG-80).
var layout_typing := false
var layout_typed := ""
var layout_sizing := false
## The screen mode's resize drag (SG-80): which element a grabbed handle is
## resizing, and which dimensions that handle moves — e is width, s is height,
## se is both.
var _layout_resize_key := ""
var _layout_resize_mask := Vector2.ZERO
## Where F12 put the last photograph, for the header to show.
var layout_shot := ""
var _layout_screen := ""             ## which screen the selection belongs to
var _layout_undo: Dictionary = {}    ## single-level, the SG-39 convention
var _layout_drag_key := ""           ## screen mode: the element being dragged

## THE SCREEN PICKER (board SG-44) — round two of the owner's alignment ask.
## SG-42's rule was "you edit the screen you are ON — the game navigates", and
## the game being the screen picker meant reaching the results screen to edit it
## required WINNING and GAMEOVER required DYING. So F4 grew a picker: P lists
## the same screens the audit shoots, and picking one poses it on a SANDBOX — a
## second, silent, invisible copy of `main.tscn` the shared poser drives —
## never on the live run. The live game freezes while the pose is up (its sim,
## its enemies, its player), the sandbox's HUD draws the posed screen with the
## editor over it, and Esc frees the sandbox and hands the run back exactly as
## it was — the cutscene player's "the gameplay camera comes back exactly" is
## the precedent, and the harness holds this side to it (`editor · and leaving
## the pose hands the run back exactly`).
var pose_game: SkyGearGame = null    ## the sandbox this game posed, live side
var pose_owner: SkyGearGame = null   ## the game that posed me, sandbox side
var pose_name := ""                  ## which audit screen is posed, live side
var layout_picker := false           ## the picker list is up
var picker_at := 0                   ## the picker's keyboard cursor
var _posing := false                 ## mid-pose; input waits for the pose to land
var _pose_controls := false          ## player.controls_enabled before the pose
## Whether a finished run reaches the run log on disk. True for every real game;
## the shared poser turns it off (board SG-49) because a POSED ending is a
## picture of the screen, not a run — the audit was appending a dozen fake rows
## to the player's own log per pass, and the picker would have added one per
## pose.
var log_runs := true


## WHETHER THE DEVELOPER KEYS EXIST FOR WHOEVER IS HOLDING THIS BUILD (board
## SG-214). F3 opens the profiler and F4 opens the LAYOUT EDITOR — which does
## not stop the simulation, draws an absolute Windows path on screen, and names
## `SkyGear Tools.bat` to the player. Both shipped live in the exported build,
## and the pause sheet ADVERTISED F4 and F3 in its own footer, which is the half
## that made this worth gating rather than merely worth hiding.
##
## `OS.has_feature("editor")` is false in an exported release and true in the
## editor and in every `godot --path . --script` tool run, so the harness and the
## probes keep the keys they were built around. It is a plain `var` rather than a
## function so a check can force it false and drive the real `_unhandled_input`.
##
## F12 and P need no gate of their own: both are inside the layout editor and
## unreachable until F4 has opened it.
var dev_tools := OS.has_feature("editor")


## The game that owns the editor session — me, or whoever posed me. The sandbox's
## HUD asks this to draw the picker, which lives on the owner's side of the glass.
func pose_master() -> SkyGearGame:
	return pose_owner if pose_owner != null else self

var keys_open := false
var settings_open := false
var how_open := false
var workshop_open := false
## THE TWO CLASSES, SIDE BY SIDE. `CLASSES[*].compare` has carried parallel rows
## since the Boilerwright landed and nothing has ever read them — the picker
## showed one sentence, so a player choosing between a 260-speed captain and a
## 205-speed engineer had no way to see what the 55 bought. See `_draw_compare`.
var compare_open := false
## The Heat this run is being played at. Chosen at the title, fixed for the run,
## and zero until a first victory — so there is exactly one difficulty until the
## game has been beaten and every harness claim is against that one.
var heat := 0
## OPEN ALL HEATS (board SG-160). The settings sheet's playtest bypass, mirrored
## here from `audio.open_heats` so every reader on the hot path — the title
## ladder, `begin_run`'s clamp — asks the game rather than reaching through a
## node that is null in the harness. `toggle_open_heats` is the only writer and
## it writes both, the same shape `toggle_fullscreen` uses, so the settings row
## and the file on disk cannot drift apart.
var open_heats := false
## DECKWORK. What you are standing next to that you could work on, and how far
## through doing it you are. See `scripts/deckwork.gd` — a verb table rather than
## a repair button, because the ask was framed as the seed of the player shaping
## the ground rather than as one feature.
var deckwork: Dictionary = {}
var deckwork_progress := 0.0
## The draggable crate, as the PROP the player sees — so the thing that blocks and
## the thing that is drawn are one object, mirrored into 3D with no renderer change
## (board SG-10). Null until the deck is first stowed; re-stowed home every wave.
var barricade: SkyGearProp = null
var barricade_stage := 0
## Ticks down after each shove; a shove is refused while it is above zero. See
## `BARRICADE_COOLDOWN` and `_update_deckwork`.
var barricade_cooldown := 0.0
## The winch verb's own cooldown, same idiom. Exists only while the WINCH
## fitting is berthed, but ticking an unused float is cheaper than a branch.
var winch_cooldown := 0.0
## What you keep between runs. Loaded once; nothing before a first victory.
var workshop: Dictionary = SkyGearWorkshop.load_state()
## THE SHIP THIS RUN SAILS (board SG-56): the berthed fitting set, snapshotted
## by `begin_run` and NEVER re-read from the workshop after — the owner's rule
## is that the ship does not change mid-run, so a berth signed mid-run waits
## for the next run. `refresh_berthed()` is the only other writer and it runs
## between runs (boot, the berth screen), where the title deck should show
## what is berthed. Everything fitting-shaped in the simulation asks
## `fitted()`, so there is exactly one copy of the answer.
var run_fittings: Array = []
## Cross-passage closures the berthed set adds — the SCUPPER GRATING. Clamp
## the CAPTAIN only (`correct_player_position`); deliberately absent from
## `cargo_rects()`, so boarders and the x-ray pass are provably untouched.
var fitting_walls: Array = []
## The berth screen (SG-56), the Workshop's sibling. Opened from the title
## only — there is no key, so it is structurally a between-runs screen.
var berths_open := false


func fitted(id: String) -> bool:
	return run_fittings.has(id)


## Re-snapshot the berthed set from the save. Between runs only: boot, and the
## berth screen after a change — so the title's live deck (and its wreck) show
## what will sail, while a running deck keeps the set it began with.
func refresh_berthed() -> void:
	run_fittings = SkyGearFittings.sailing(workshop)
	fitting_walls = SkyGearFittings.walls(run_fittings)
## What the last run paid, so the results screen can say so rather than the
## player finding out two screens later.
var banked: Dictionary = {}
## THE TREE, RESOLVED, for the length of a run. Everything below reads this
## rather than calling `resolved()` again — a talent that could change mid-run
## would be a card, and cards are the draft's job.
var talents: Dictionary = {}


## One accessor, so a node whose field nobody reads is a grep away from being
## found rather than silently inert. That is the trap this whole commit exists
## to close: the last one shipped thirteen fields that resolved and did nothing.
func talent(field: String) -> float:
	return float(talents.get(field, 0.0))


## The sigil side, resolved for the run the same way the scrip side is.
var articles: Dictionary = {}
## Once-a-run and once-a-wave Articles need somewhere to remember they fired.
var article_used: Dictionary = {}
var brace_cooldown := 0.0
var brace_left := 0.0


func article(id: String) -> bool:
	return bool(articles.get(id, false))


## How many weapons this run may hold. Four, or five under THE SECOND HAND —
## asked here, once, so the slot loops, the draft threshold and the HUD cannot
## each carry their own copy of the number (failure mode two).
func skill_capacity() -> int:
	return 5 if article("second_hand") else 4


## THE OPENING BID's picker keyboard: which cell of the matrix the arrows are
## on. Lives on the game rather than the HUD because choosing is a simulation
## act — the HUD only draws the ring.
var draft_cursor := 0
## The one line of advice, if there is one worth giving. Read-only against the
## simulation, so a bad hint is a wrong sentence rather than a wrong game.
var coach := SkyGearCoach.new()
var coach_line := ""
## The named event running this wave, or "". Every fourth wave has one.
var active_event := ""
var event_banner_left := 0.0
const EVENT_BANNER_TIME := 4.0
## When the run report was last put on the clipboard, so the button can say so.
## A button that does something invisible is a button a player presses four times.
var copied_at := -99.0
var rebinding_index := -1
var rebind_conflict := ""

## The lane layer. Plain data, drawn by this node — see scripts/lanes.gd.
const BASE_Y := 730.0
const BOW_Y := -1000.0
var turrets: Array[Dictionary] = []
var crew: Array[Dictionary] = []
var hulk: Dictionary = {}
## AB-01: one simulation-owned Beam channel. Rendering reads this row; it owns
## no second clock. Every production spawn receives a nonzero serial before the
## per-channel element guard can observe it.
var active_channel: Dictionary = {}
var _next_enemy_spawn_serial := 1
## How long the boarding hulk hangs on the hull SEALED before its door opens
## (board SG-76). It is not decoration: `damage_hulk` already refuses a hulk
## that is not `vulnerable`, so this is the beat where the thing is bolted to
## your ship and there is nothing yet to shoot at — and it is the only window
## in which the sealed face, which the art has had all along, is on screen.
const HULK_GRAPPLE_TIME := 2.5
var crew_timer := 0.0

func _ready() -> void:
	rng.seed = 0x5A17C0DE
	## The berthed set, live from boot — the title screen is the real deck, and
	## a berthed wreck should be riding off the bow before a run ever starts.
	refresh_berthed()
	player.game = self
	hud.game = self
	player.controls_enabled = false
	player.visible = false
	audio = SkyGearAudio.new()
	audio.name = "Audio"
	add_child(audio)
	## `add_child` runs `_ready`, which is where `settings.cfg` is read — so the
	## bypass is live before the first title frame is drawn rather than one
	## settings visit later (board SG-160). Gated on `dev_tools`: a build-71
	## tester who left OPEN ALL HEATS on has no way to switch it off in an
	## exported build (the settings row is behind `dev_tools`, `toggle_open_heats`
	## has no keybinding by design) — so a stored `true` surviving into a build
	## with no control for it must not survive at all. `dev_tools` is a var
	## initializer, assigned before `_ready` runs, so it is already set here.
	open_heats = audio.open_heats and dev_tools
	profiler = SkyGearProfiler.new()
	profiler.name = "Profiler"
	add_child(profiler)
	impact = SkyGearImpact.new()
	impact.name = "Impact"
	add_child(impact)
	voice = SkyGearVoice.new()
	voice.name = "Voice"
	voice.audio = audio
	add_child(voice)
	player.dash_started.connect(_on_dash_started)
	SkyGearKeybinds.capture_defaults()
	SkyGearKeybinds.load_saved()
	## THE WINDOW CANNOT SHRINK BELOW THE SIZE THE TYPE WAS CALIBRATED FOR.
	## `scripts/ink.gd` chose MIN_PT so a 12pt glyph survives the 0.83 downscale of
	## a 1600 window with a pixel of stem left, and nothing narrower — but until now
	## nothing stopped the window going narrower, and at 1280 the HUD's smallest text
	## is 8 physical pixels, the smudge MIN_PT exists to prevent. The 1920 canvas
	## does not reflow (the whole layout scales to the window), so the only lever on
	## physical legibility is this floor. Guarded null-safe because the harness
	## builds a game outside a window tree.
	var win := get_window()
	if win != null:
		win.min_size = Vector2i(SkyGearInk.MIN_WINDOW_W, SkyGearInk.MIN_WINDOW_H)
	## min_size governs a WINDOW and this game opens borderless fullscreen, so on a
	## 1366-wide laptop 12 pt lands at 8.5 physical px against a floor of 10.0 and
	## nothing stops it. Say so rather than shipping type nobody can read.
	## A HEADLESS run has no screen to query — `screen_get_size()` returns (0, 0)
	## — and the harness builds dozens of games, so unguarded this fires on every
	## one of them. Same guard `_maybe_play_opening()` already uses two lines down.
	if DisplayServer.get_name() != "headless":
		var screen_w: int = DisplayServer.screen_get_size().x
		if screen_w < SkyGearInk.MIN_SUPPORTED_W:
			push_warning("SkyGear supports %d wide and up; this display is %d — text will be below the legibility floor."
				% [SkyGearInk.MIN_SUPPORTED_W, screen_w])
	## THE LABEL, WITHOUT THE COUPLING. `config/name` stays "SkyGear: Godot Port"
	## because Godot derives `%APPDATA%/Godot/app_userdata/<name>` from it and the
	## player's runs.json, workshop.json, keys.cfg, settings.cfg and hud_layout.json
	## all live under the old one (board SG-223). Renaming it is a migration, not a
	## copyedit; setting the title is neither.
	DisplayServer.window_set_title("SkyGear")
	_maybe_play_opening()
	queue_redraw()


## THE OPENING CINEMATIC, ONCE (SG-242). Everything about when it does NOT play
## is deliberate, and each clause is a real case:
##
##   * a POSED SANDBOX is a picture of a screen and must not start a film — the
##     same rule `play_sfx` and the music director already obey (SG-44);
##   * a HEADLESS run has no video decoder and no window to put one in, and the
##     harness builds dozens of games;
##   * a player who has SEEN it gets the title, which is rule 2 in
##     `scripts/opening.gd` and the difference between an opening and an
##     obstacle.
##
## The film is marked seen when it STARTS, not when it ends. A player who skips
## it at second three has decided; asking them again next launch is asking them
## to decide again.
func _maybe_play_opening() -> void:
	if pose_owner != null or DisplayServer.get_name() == "headless":
		return
	if not ResourceLoader.exists(SkyGearOpening.FILM) or SkyGearOpening.seen():
		return
	replay_opening()
	SkyGearOpening.mark_seen()


## SETTINGS → WATCH THE OPENING. The same door, without the once-only gate: a
## player who skipped it at second three and then wondered what it was should
## not have to delete a config file to find out.
func replay_opening() -> void:
	if pose_owner != null or DisplayServer.get_name() == "headless":
		return
	if not ResourceLoader.exists(SkyGearOpening.FILM):
		return
	if has_node("Opening"):
		return
	var film := SkyGearOpening.new()
	film.name = "Opening"
	add_child(film)

func _unhandled_input(event: InputEvent) -> void:
	## The layout editor, first and greedy. It is a mode, and a mode that lets
	## the game underneath react to the same click is a mode that fights you.
	if layout_edit and _layout_input(event):
		get_viewport().set_input_as_handled()
		return
	## While a screen is POSED over the run (SG-44), every key that is not the
	## editor's belongs to nobody: the game underneath is frozen and must come
	## back exactly, and Enter on a posed title starting a second run is the
	## kind of leak "frozen" exists to forbid. F4 is the one exception — it
	## drops the pose and the editor together.
	if pose_game != null:
		if not _posing and event is InputEventKey and event.pressed \
				and not event.echo and event.keycode == KEY_F4:
			end_pose()
			layout_edit = false
			layout_picker = false
			hud.audit = null
			hud.ink = null
			hud.queue_redraw()
		get_viewport().set_input_as_handled()
		return
	## The rebind screen swallows everything while it is open, so that pressing
	## W to bind W does not also walk you into a boarder.
	if rebinding_index >= 0:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE:
				rebinding_index = -1
				rebind_conflict = ""
			else:
				_apply_rebind(event)
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.pressed:
			_apply_rebind(event)
			get_viewport().set_input_as_handled()
		return
	## The draft, with a mouse. It was keyboard-only — 1, 2, 3 — and a screen full
	## of cards that do not respond to being clicked reads as a screen that is
	## broken, not as a screen with a keyboard shortcut.
	if state == State.DRAFT and event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		var where: Vector2 = hud.get_local_mouse_position()
		## THE OPENING BID's matrix: more than four options is the grid, and the
		## grid's geometry is `bid_cells` — the same static the HUD draws from,
		## so the click and the picture cannot disagree (the `hud_plates` rule).
		if draft_options.size() > 4:
			var cells := SkyGearHUD.bid_cells(hud.size, draft_options.size())
			for i in cells.size():
				if cells[i].has_point(where):
					choose_draft(i)
					get_viewport().set_input_as_handled()
					return
		else:
			## `mini(4...)` — the FOURTH CARD fix's other half (SG-46): the hit
			## test capped at three too, so even a drawn fourth card would have
			## ignored its own click.
			var cards := SkyGearHUD.draft_cards(hud.size, mini(4, draft_options.size()))
			for i in cards.size():
				if cards[i].has_point(where):
					choose_draft(i)
					get_viewport().set_input_as_handled()
					return
		if SkyGearHUD.reroll_button(hud.size).has_point(where):
			reroll_draft()
			get_viewport().set_input_as_handled()
			return
	## THE WHEEL ZOOMS. Checked before anything else consumes a mouse button —
	## wheel events ARE button events in Godot, and the draft's card hit-test runs
	## on any press.
	if event is InputEventMouseButton and event.pressed and view != null:
		var wheel := event as InputEventMouseButton
		if wheel.button_index == MOUSE_BUTTON_WHEEL_UP:
			view.zoom_by(-1.0)
			get_viewport().set_input_as_handled()
			return
		if wheel.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			view.zoom_by(1.0)
			get_viewport().set_input_as_handled()
			return

	## A menu that is open owns the pointer and the arrow keys. Checked before
	## the game's own bindings, or Space dashes while you are choosing a button.
	## How-to-play and settings each own everything while up, including over a
	## paused game.
	if workshop_open:
		if hud.ui.handle(event):
			hud.queue_redraw()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			workshop_open = false
			hud.queue_redraw()
			get_viewport().set_input_as_handled()
			return
	elif berths_open:
		if hud.ui.handle(event):
			hud.queue_redraw()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			berths_open = false
			hud.queue_redraw()
			get_viewport().set_input_as_handled()
			return
	elif compare_open:
		if hud.ui.handle(event):
			hud.queue_redraw()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventKey and event.pressed and event.keycode in [KEY_ESCAPE, KEY_F7]:
			compare_open = false
			hud.queue_redraw()
			get_viewport().set_input_as_handled()
			return
	elif how_open:
		if hud.ui.handle(event):
			hud.queue_redraw()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventKey and event.pressed 				and event.keycode in [KEY_ESCAPE, KEY_F1]:
			how_open = false
			hud.queue_redraw()
			get_viewport().set_input_as_handled()
			return
	elif settings_open:
		if hud.ui.handle(event):
			hud.queue_redraw()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			settings_open = false
			if audio != null:
				audio.save_settings()
			hud.queue_redraw()
			get_viewport().set_input_as_handled()
			return
	elif (state == State.PAUSE or state == State.TITLE
			or state == State.GAMEOVER or state == State.VICTORY) 			and not keys_open and hud.ui.handle(event):
		hud.queue_redraw()
		get_viewport().set_input_as_handled()
		return
	if event is not InputEventKey or not event.pressed or event.echo:
		return
	## F11, always, in every state. A game that opens fullscreen and offers no
	## way out is a game people force-quit, and the choice is remembered.
	if event.keycode == KEY_F11:
		toggle_fullscreen()
		hud.queue_redraw()
		get_viewport().set_input_as_handled()
		return
	## The Boilerwright's two bindings. Both no-ops for the captain, and both
	## deliberately outside the four drafted slots — the 36-cell matrix stays 36.
	## F and V belong to the class first and to the Articles second. The
	## Boilerwright's are his signature rather than a binding, which is why the
	## keyed Articles are captain-only — see `SkyGearWorkshop.ARTICLES`.
	if event.keycode == KEY_F and state == State.PLAY:
		if tap_main() or use_article_f():
			get_viewport().set_input_as_handled()
			return
	if event.keycode == KEY_V and state == State.PLAY:
		if blowdown() or use_article_v():
			get_viewport().set_input_as_handled()
			return
	## The three doors the demo cut closes also have keys, and a hidden plate
	## with a live key is not hidden (SG-213).
	if event.keycode == KEY_F6 and bool(workshop.unlocked) \
			and not SkyGearDemo.active():
		workshop_open = not workshop_open
		hud.queue_redraw()
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_F1:
		how_open = not how_open
		hud.queue_redraw()
		get_viewport().set_input_as_handled()
		return
	## The two of them, side by side. A key as well as the title-screen button,
	## because it is also worth reading mid-run — "what does this class do" is a
	## question a player has in wave three, not only at the picker.
	if event.keycode == KEY_F7 and not SkyGearDemo.active():
		compare_open = not compare_open
		hud.queue_redraw()
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_F5:
		settings_open = not settings_open
		if not settings_open and audio != null:
			audio.save_settings()
		hud.queue_redraw()
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_F3 and dev_tools:
		show_profiler = not show_profiler
		if show_profiler:
			profiler.reset()
		hud.queue_redraw()
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_F4 and dev_tools:
		layout_edit = not layout_edit
		layout_saved = false
		layout_typing = false
		layout_sizing = false
		layout_picker = false
		layout_shot = ""
		layout_key = ""
		layout_panel = -1
		_layout_undo = {}
		_layout_drag = ""
		_layout_drag_key = ""
		_layout_resize_key = ""
		## The editor attaches the audit funnels for its live verdict; closing it
		## must detach them or every later frame keeps appending to arrays nobody
		## reads again.
		if not layout_edit:
			hud.audit = null
			hud.ink = null
		hud.queue_redraw()
		get_viewport().set_input_as_handled()
		return
	## The controls screen. Fixed keys, deliberately: rebinding your way out of
	## the rebind screen leaves no way back in.
	if event.keycode == KEY_F2 and state in [State.TITLE, State.PAUSE]:
		keys_open = not keys_open
		queue_redraw()
		hud.queue_redraw()
		get_viewport().set_input_as_handled()
		return
	if keys_open:
		if event.keycode == KEY_ESCAPE:
			keys_open = false
		elif event.keycode == KEY_BACKSPACE:
			SkyGearKeybinds.reset()
			rebind_conflict = ""
		else:
			var slot := _digit_slot(event.keycode)
			if slot >= 0 and slot < SkyGearKeybinds.REBINDABLE.size():
				rebinding_index = slot
				rebind_conflict = ""
		hud.queue_redraw()
		get_viewport().set_input_as_handled()
		return
	if state == State.TITLE and event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		begin_run()
		get_viewport().set_input_as_handled()
		return
	if state in [State.GAMEOVER, State.VICTORY]:
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
			restart_run()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ESCAPE:
			go_to_title()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_C:
			# the report is the thing a tester pastes into a message; make
			# taking it one key rather than a screenshot of a screen
			copy_run_report()
			_fx({"kind": "banner", "text": "REPORT COPIED", "time": 0.0, "life": 1.6})
			get_viewport().set_input_as_handled()
			return
	if state == State.DRAFT:
		if event.keycode == KEY_R:
			reroll_draft()
			get_viewport().set_input_as_handled()
			return
		## THE OPENING BID's matrix drives on arrows and Enter — thirty-two
		## cells is past what number keys can name. Four columns, so vertical
		## steps are ±4; the cursor clamps rather than wraps.
		if draft_options.size() > 4:
			var step := 0
			match event.keycode:
				KEY_LEFT: step = -1
				KEY_RIGHT: step = 1
				KEY_UP: step = -4
				KEY_DOWN: step = 4
			if step != 0:
				draft_cursor = clampi(draft_cursor + step, 0,
					draft_options.size() - 1)
				hud.queue_redraw()
				get_viewport().set_input_as_handled()
				return
			if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
				choose_draft(draft_cursor)
				get_viewport().set_input_as_handled()
				return
		var choice := -1
		if event.keycode in [KEY_1, KEY_KP_1]:
			choice = 0
		elif event.keycode in [KEY_2, KEY_KP_2]:
			choice = 1
		elif event.keycode in [KEY_3, KEY_KP_3]:
			choice = 2
		elif event.keycode in [KEY_4, KEY_KP_4]:
			## FOURTH CARD's key (SG-46). The talent dealt a fourth option and
			## the keyboard stopped at 3, so the bought card was unreachable.
			choice = 3
		if choice >= 0:
			choose_draft(choice)
			get_viewport().set_input_as_handled()
			return
	## Volume, from the keyboard, at any time — the browser build has a settings
	## panel and this build has downloads, so the minimum is that a player can
	## turn it down without leaving the game or opening the Windows mixer.
	if audio != null:
		if event.keycode == KEY_M:
			audio.toggle_mute()
			_fx({"kind": "banner", "text": "MUTED" if audio.muted else "UNMUTED",
				"time": 0.0, "life": 1.0})
			get_viewport().set_input_as_handled()
			return
		if event.keycode in [KEY_MINUS, KEY_KP_SUBTRACT, KEY_EQUAL, KEY_KP_ADD]:
			var step := -0.1 if event.keycode in [KEY_MINUS, KEY_KP_SUBTRACT] else 0.1
			audio.set_volume("master", float(audio.volumes.master) + step)
			_fx({"kind": "banner",
				"text": "VOLUME %d%%" % roundi(float(audio.volumes.master) * 100.0),
				"time": 0.0, "life": 1.0})
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("pause"):
		if state == State.PLAY:
			_set_state(State.PAUSE)
		elif state == State.PAUSE:
			_set_state(State.PLAY)
		get_viewport().set_input_as_handled()

## The layout editor. Returns whether it consumed the event.
##
## Everything here writes to `SkyGearHUD.layout`, which is the same object the
## HUD draws from — so a drag is visible on the panel being dragged rather than
## on a wireframe of it. That is the whole point: the thing being positioned is
## the real panel with the real content at the real resolution.
func _layout_input(event: InputEvent) -> bool:
	## The picker and the pose come first (SG-44). A pose mid-build swallows
	## everything — the sandbox is between screens and there is nothing coherent
	## to edit; it lands within a dozen frames.
	if _posing:
		return true
	if _picker_input(event):
		return true
	if pose_game != null:
		## The editor is standing on the SANDBOX's screen: its selection, its
		## typed box, its element registry. Everything delegates to the
		## sandbox's own handler — same code, its state — except a top-level
		## Esc, which is the way back through the glass.
		if event is InputEventKey and event.pressed and not event.echo \
				and (event as InputEventKey).keycode == KEY_ESCAPE \
				and not pose_game.layout_typing:
			var deep: bool = (pose_game.hud.edit_screen == "hud" \
					and pose_game.layout_item != "") \
				or (pose_game.hud.edit_screen != "hud" \
					and (pose_game.layout_key != "" or pose_game.layout_panel >= 0))
			if not deep:
				end_pose()
				return true
		return pose_game._layout_input(event)

	var view: Vector2 = hud.size
	var where: Vector2 = hud.get_local_mouse_position()
	if SkyGearHUD.layout == null:
		SkyGearHUD.layout = SkyGearHudLayout.load_layout()
	var layout := SkyGearHUD.layout

	## The game navigated under the editor (F1/F5/F6/F7 fall through on
	## purpose — the game is the screen picker). Selection belongs to a screen;
	## a new screen starts unselected.
	if hud.edit_screen != _layout_screen:
		_layout_screen = hud.edit_screen
		layout_key = ""
		layout_panel = -1
		layout_typing = false
		layout_sizing = false
		_layout_drag = ""
		_layout_drag_key = ""
		_layout_resize_key = ""

	## The typed-offset box owns every key while it is open.
	if layout_typing and _typed_input(event):
		return true

	if event is InputEventKey and event.pressed and not event.echo:
		var key0 := event as InputEventKey
		## F12: photograph THIS screen, without the editor's own chrome — the
		## single-screen evidence shot. The 84-shot batch stays in
		## `tools/screen_review.py`.
		if key0.keycode == KEY_F12:
			_snap_screen()
			return true
		## Ctrl+Z, single-level (the SG-39 convention): a swap, so a second
		## Ctrl+Z brings the edit back.
		if key0.ctrl_pressed and key0.keycode == KEY_Z:
			if not _layout_undo.is_empty():
				var now := layout.snapshot()
				layout.restore(_layout_undo)
				_layout_undo = now
				layout_saved = false
				layout_shot = ""
			hud.queue_redraw()
			return true

	if hud.edit_screen != "hud":
		return _layout_screen_input(event, layout, where)

	var plate_rect: Rect2 = SkyGearHUD.hud_plates(view).get(layout_pick, Rect2())

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			## The offset readout opens the typed box; the w×h readout opens its
			## SIZE sibling (SG-80) — the same widget, the other pair.
			if hud.edit_offset_box != Rect2() and hud.edit_offset_box.has_point(where):
				var entry0: Dictionary = layout.plates.get(layout_pick, {}) if layout_item == "" \
					else layout._bag(layout_pick).get(layout_item, {})
				if not entry0.is_empty():
					layout_typed = "%s, %s" % [_trim_num(float(entry0.offset[0])),
						_trim_num(float(entry0.offset[1]))]
					layout_typing = true
					layout_sizing = false
					hud.queue_redraw()
					return true
			if hud.edit_size_box != Rect2() and hud.edit_size_box.has_point(where):
				var entry1: Dictionary = layout.plates.get(layout_pick, {}) if layout_item == "" \
					else layout._bag(layout_pick).get(layout_item, {})
				if not entry1.is_empty():
					layout_typed = "%s, %s" % [_trim_num(float(entry1.size[0])),
						_trim_num(float(entry1.size[1]))]
					layout_typing = true
					layout_sizing = true
					hud.queue_redraw()
					return true
			var hit := SkyGearHUD.pick_at(view, where, layout_pick)
			if hit.is_empty():
				return true
			layout_pick = str(hit.plate)
			layout_item = str(hit.item)
			_layout_drag = layout_pick
			_layout_resize = bool(hit.resize)
			_layout_from = where
			_layout_undo = layout.snapshot()
			layout_saved = false
			layout_shot = ""
		else:
			_layout_drag = ""
		hud.queue_redraw()
		return true

	if event is InputEventMouseMotion and _layout_drag != "":
		var delta: Vector2 = where - _layout_from
		_layout_from = where
		if _layout_resize:
			layout.resize(layout_pick, layout_item, delta)
		else:
			layout.nudge(layout_pick, layout_item, delta)
		layout_saved = false
		hud.queue_redraw()
		return true

	if event is not InputEventKey or not event.pressed:
		return event is InputEventMouseMotion
	var key := event as InputEventKey
	## Ctrl+S and Ctrl+R rather than S and R, because a layout you have spent two
	## minutes on should not be resettable by leaning on the keyboard.
	if key.ctrl_pressed and key.keycode == KEY_S:
		_save_layout(layout)
		hud.queue_redraw()
		return true
	if key.ctrl_pressed and key.keycode == KEY_R:
		_layout_undo = layout.snapshot()
		layout.reset()
		layout_item = ""
		layout_saved = false
		hud.queue_redraw()
		return true
	## Tab walks plates; Enter drops into the elements inside one and Escape
	## comes back out. Two levels, one key each.
	if key.keycode == KEY_TAB:
		var step: int = -1 if key.shift_pressed else 1
		if layout_item == "":
			var order: Array = SkyGearHudLayout.ORDER
			var at: int = maxi(0, order.find(layout_pick))
			layout_pick = order[(at + step + order.size()) % order.size()]
		else:
			var items := layout.items_of(layout_pick)
			var at2: int = maxi(0, items.find(layout_item))
			layout_item = items[(at2 + step + items.size()) % items.size()]
		hud.queue_redraw()
		return true
	if key.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		var items2 := layout.items_of(layout_pick)
		if layout_item == "" and not items2.is_empty():
			layout_item = items2[0]
		hud.queue_redraw()
		return true
	if key.keycode == KEY_ESCAPE:
		if layout_item != "":
			layout_item = ""
			hud.queue_redraw()
			return true
		layout_edit = false
		hud.audit = null
		hud.ink = null
		hud.queue_redraw()
		return true
	if key.keycode == KEY_A:
		var anchors: Array = SkyGearHudLayout.ANCHORS
		var entry: Dictionary = layout.plates.get(layout_pick, {}) if layout_item == "" \
			else layout._bag(layout_pick).get(layout_item, {})
		if not entry.is_empty():
			var current := str(entry.anchor)
			_layout_undo = layout.snapshot()
			layout.set_anchor(layout_pick, layout_item,
				anchors[(maxi(0, anchors.find(current)) + 1) % anchors.size()],
				view, plate_rect)
			layout_saved = false
		hud.queue_redraw()
		return true
	## C centres the selected element in its plate, which is the single most
	## common thing anyone wants from a screen like this and is fiddly by hand.
	if key.keycode == KEY_C and layout_item != "":
		_layout_undo = layout.snapshot()
		layout.set_anchor(layout_pick, layout_item, "centre", view, plate_rect)
		var entry2: Dictionary = layout._bag(layout_pick).get(layout_item, {})
		if not entry2.is_empty():
			entry2.offset = [0.0, float(entry2.offset[1])] if key.shift_pressed \
				else [0.0, 0.0]
		layout_saved = false
		hud.queue_redraw()
		return true
	var step_px: float = 10.0 if key.shift_pressed else 1.0
	var nudge := Vector2.ZERO
	match key.keycode:
		KEY_LEFT: nudge = Vector2(-step_px, 0)
		KEY_RIGHT: nudge = Vector2(step_px, 0)
		KEY_UP: nudge = Vector2(0, -step_px)
		KEY_DOWN: nudge = Vector2(0, step_px)
		_: return false
	_layout_undo = layout.snapshot()
	if key.alt_pressed:
		layout.resize(layout_pick, layout_item, nudge)
	else:
		layout.nudge(layout_pick, layout_item, nudge)
	layout_saved = false
	hud.queue_redraw()
	return true


## The SCREEN mode (SG-42): the elements of whatever screen is up, captured by
## the HUD as it drew. Two levels — click a panel, click again (or double-click)
## for the element inside — and the element moves by drag, by arrows (Shift ×10,
## Alt ×0.1) or by a typed offset. Everything writes through
## `layout.screens[hud.edit_screen]`, offsets RELATIVE to the element's home.
func _layout_screen_input(event: InputEvent, layout: SkyGearHudLayout,
		where: Vector2) -> bool:
	var screen: String = hud.edit_screen

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed:
			_layout_drag_key = ""
			_layout_resize_key = ""
			return true
		## The offset readout opens the typed box — only an element carries one.
		if layout_key != "" and hud.edit_offset_box != Rect2() \
				and hud.edit_offset_box.has_point(where):
			var off := layout.screen_offset(screen, layout_key)
			layout_typed = "%s, %s" % [_trim_num(off.x), _trim_num(off.y)]
			layout_typing = true
			layout_sizing = false
			hud.queue_redraw()
			return true
		## The w×h readout opens the typed SIZE box (SG-80), prefilled with the
		## LAYOUT size — the code's own plus the saved delta — because that is
		## the number Enter sets. What gets stored is the difference.
		if layout_key != "" and hud.edit_size_box != Rect2() \
				and hud.edit_size_box.has_point(where) \
				and hud.edit_elements.has(layout_key):
			var lay: Vector2 = ((hud.edit_elements[layout_key] as Dictionary).get(
				"base", Vector2.ZERO) as Vector2) + layout.screen_size(screen, layout_key)
			layout_typed = "%s, %s" % [_trim_num(lay.x), _trim_num(lay.y)]
			layout_typing = true
			layout_sizing = true
			hud.queue_redraw()
			return true
		## A grabbed handle starts a RESIZE drag rather than a move (SG-80).
		## Tested before the selection logic below, so a grip sitting over a
		## neighbouring element resizes the thing it is drawn on.
		if layout_key != "":
			for handle in hud.edit_handles:
				if not (hud.edit_handles[handle] as Rect2).grow(2.0).has_point(where):
					continue
				_layout_resize_key = layout_key
				_layout_resize_mask = SkyGearHUD.HANDLE_MASK.get(str(handle), Vector2.ONE)
				_layout_from = where
				_layout_undo = layout.snapshot()
				layout_saved = false
				layout_shot = ""
				hud.queue_redraw()
				return true
		var hit_panel: int = hud.panel_at(where)
		var hit_key: String = hud.element_at(where)
		var dbl: bool = (event as InputEventMouseButton).double_click
		if dbl and hit_key != "":
			## Double-click goes straight through to the element.
			layout_panel = hit_panel
			layout_key = hit_key
		elif layout_key != "":
			## Element level: another element, or empty space backs out a level.
			if hit_key != "":
				layout_key = hit_key
				layout_panel = hit_panel
			else:
				layout_key = ""
				layout_panel = hit_panel
		elif layout_panel >= 0:
			## Panel level: a second click inside the selected panel DESCENDS;
			## a click elsewhere moves the panel selection.
			if hit_panel == layout_panel and hit_key != "":
				layout_key = hit_key
			else:
				layout_panel = hit_panel
		else:
			layout_panel = hit_panel
		if layout_key != "" and hud.edit_elements.has(layout_key) \
				and (hud.edit_elements[layout_key].box as Rect2).grow(3.0).has_point(where):
			_layout_drag_key = layout_key
			_layout_from = where
			_layout_undo = layout.snapshot()
		layout_shot = ""
		hud.queue_redraw()
		return true

	## The resize drag (SG-80). Only the handle's own dimensions of the mouse
	## travel reach the size, and the travel goes through the SAME SG-58
	## drag-lock session a move uses — so Shift locks a resize to its dominant
	## dimension exactly as it locks a move to its dominant axis. Clamped after
	## every step, so a drag past the floor stores the floor rather than a
	## number the draw code will quietly refuse.
	if event is InputEventMouseMotion and _layout_resize_key != "":
		var travel: Vector2 = (where - _layout_from) * _layout_resize_mask
		_layout_from = where
		layout.resize_screen(screen, _layout_resize_key, travel)
		_clamp_screen_size(layout, screen, _layout_resize_key)
		layout_saved = false
		hud.queue_redraw()
		return true

	if event is InputEventMouseMotion and _layout_drag_key != "":
		var delta: Vector2 = where - _layout_from
		_layout_from = where
		layout.nudge_screen(screen, _layout_drag_key, delta)
		layout_saved = false
		hud.queue_redraw()
		return true

	if event is not InputEventKey or not event.pressed:
		return event is InputEventMouseMotion
	var key := event as InputEventKey
	if key.ctrl_pressed and key.keycode == KEY_S:
		_save_layout(layout)
		layout_shot = ""
		hud.queue_redraw()
		return true
	## Ctrl+R here resets THIS screen — the other twenty keep their work.
	if key.ctrl_pressed and key.keycode == KEY_R:
		_layout_undo = layout.snapshot()
		layout.clear_screen(screen)
		layout_saved = false
		hud.queue_redraw()
		return true
	if key.keycode == KEY_TAB:
		var step: int = -1 if key.shift_pressed else 1
		if layout_key == "" and layout_panel < 0:
			layout_panel = 0
		elif layout_key == "":
			## Walk panels at panel level.
			var count: int = maxi(1, hud.edit_panels.size())
			layout_panel = (layout_panel + step + count) % count
		else:
			var items: Array[String] = hud.elements_of_panel(layout_panel)
			if not items.is_empty():
				var at: int = maxi(0, items.find(layout_key))
				layout_key = items[(at + step + items.size()) % items.size()]
		hud.queue_redraw()
		return true
	if key.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		if layout_panel < 0:
			layout_panel = 0
		if layout_key == "":
			var items: Array[String] = hud.elements_of_panel(layout_panel)
			if not items.is_empty():
				layout_key = items[0]
		hud.queue_redraw()
		return true
	if key.keycode == KEY_ESCAPE:
		if layout_key != "":
			layout_key = ""
		elif layout_panel >= 0:
			layout_panel = -1
		else:
			layout_edit = false
			hud.audit = null
			hud.ink = null
		hud.queue_redraw()
		return true
	if layout_key == "":
		return false
	## Arrow nudges, the SG-39 steps: Shift ×10, Alt ×0.1 — and CTRL+arrows
	## resize by the same steps (SG-80), Right/Down growing and Left/Up
	## shrinking, which is the keyboard half of the handles.
	var step_px: float = 10.0 if key.shift_pressed else (0.1 if key.alt_pressed else 1.0)
	var nudge := Vector2.ZERO
	match key.keycode:
		KEY_LEFT: nudge = Vector2(-step_px, 0)
		KEY_RIGHT: nudge = Vector2(step_px, 0)
		KEY_UP: nudge = Vector2(0, -step_px)
		KEY_DOWN: nudge = Vector2(0, step_px)
		_: return false
	_layout_undo = layout.snapshot()
	if key.ctrl_pressed:
		layout.resize_screen(screen, layout_key, nudge)
		_clamp_screen_size(layout, screen, layout_key)
	else:
		layout.nudge_screen(screen, layout_key, nudge)
	layout_saved = false
	hud.queue_redraw()
	return true


## CTRL+S, THE ONE WAY OUT OF THE EDITOR (SG-83). Both editor modes call this
## and nothing else writes, so "did it save" has exactly one answer — and the
## answer is SHOWN either way: the header prints the real path on success and
## the failure in the alarm colour on a refusal. It printed "layout is clean"
## on a failed write before, which is the reported-bug shape: silence where an
## alarm belongs.
func _save_layout(layout: SkyGearHudLayout) -> void:
	layout_saved = layout.save()
	layout_save_error = "" if layout_saved else \
		"COULD NOT SAVE to %s — nothing was written" % \
		ProjectSettings.globalize_path(SkyGearHudLayout.store)
	## The header is drawn by whichever HUD is on the glass — the sandbox's
	## while a pose is up — off ITS game's flags. Mirrored, so the confirmation
	## lands on the screen the person is actually looking at.
	for other in [pose_game, pose_owner]:
		if other != null:
			other.layout_saved = layout_saved
			other.layout_save_error = layout_save_error


## THE FLOOR, APPLIED TO WHATEVER A RESIZE JUST STORED (SG-80). A size delta may
## never take an element below its floor — one MIN_PT glyph for a text box, the
## 8 px item floor for a widget or a mark — and a single-line string never
## stores a HEIGHT delta at all, because its height is its point size, which
## belongs to `ink.gd`.
##
## The draw funnels in `hud.gd` apply the same floors when they lay the element
## out, because a hand-edited file never comes through this path. Clamping the
## STORED number as well is what keeps a drag honest: without it, dragging 200
## px past the floor and back would spend 200 px of travel doing nothing on the
## way out.
func _clamp_screen_size(layout: SkyGearHudLayout, screen: String, key: String) -> void:
	var element: Dictionary = hud.edit_elements.get(key, {})
	if element.is_empty():
		return
	var base: Vector2 = element.get("base", Vector2.ZERO)
	var least: Vector2 = element.get("min", Vector2.ZERO)
	var delta := layout.screen_size(screen, key)
	var clamped := Vector2(maxf(delta.x, least.x - base.x), maxf(delta.y, least.y - base.y))
	if str(element.get("kind", "text")) == "text":
		clamped.y = 0.0
	if not clamped.is_equal_approx(delta):
		layout.set_screen_size(screen, key, clamped)


## The typed-offset box. Enter applies a well-formed "dx, dy" (an undo point);
## Esc cancels; a malformed entry is REFUSED and the old value kept — a bad
## entry never moves anything. Everything else while it is open is swallowed.
func _typed_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton and event.pressed:
		## Clicking away cancels — the entry only takes on Enter.
		layout_typing = false
		hud.queue_redraw()
		return true
	if event is not InputEventKey:
		return false
	if not event.pressed:
		return true
	var key := event as InputEventKey
	## A CHORD IS NOT A CHARACTER (SG-83). Ctrl+S and Ctrl+Z used to be typed
	## into the box as the letters "s" and "z" — the save key silently dead for
	## as long as a readout was open. They fall through to the editor now, which
	## is what every text field in every program does.
	if key.ctrl_pressed and key.keycode in [KEY_S, KEY_Z]:
		return false
	match key.keycode:
		KEY_ESCAPE:
			layout_typing = false
		KEY_ENTER, KEY_KP_ENTER:
			var parsed := SkyGearHudLayout.parse_offset(layout_typed)
			if bool(parsed.ok):
				var layout := SkyGearHUD.layout
				_layout_undo = layout.snapshot()
				var typed := Vector2(float(parsed.x), float(parsed.y))
				if hud.edit_screen != "hud":
					if layout_key != "" and layout_sizing:
						## A TYPED SIZE IS ABSOLUTE "w, h" (SG-80); what is
						## STORED is its distance from the element's computed
						## home size, so a code-side reflow keeps the intent
						## rather than the pixels — the same home-relative rule
						## the offset half has carried since SG-42. Floored
						## through the clamp every resize path shares.
						var home_size: Vector2 = hud.edit_elements.get(
							layout_key, {}).get("base", Vector2.ZERO)
						layout.set_screen_size(hud.edit_screen, layout_key,
							typed - home_size)
						_clamp_screen_size(layout, hud.edit_screen, layout_key)
					elif layout_key != "":
						layout.set_screen_offset(hud.edit_screen, layout_key, typed)
				else:
					var entry: Dictionary = layout.plates.get(layout_pick, {}) \
						if layout_item == "" else layout._bag(layout_pick).get(layout_item, {})
					if not entry.is_empty():
						if layout_sizing:
							## A plate and its items store ABSOLUTE sizes, so
							## the typed pair lands directly — held to the same
							## floors `layout.resize` enforces on the corner
							## drag, so the two ways in cannot disagree.
							var floor_x: float = 40.0 if layout_item == "" else 8.0
							var floor_y: float = 28.0 if layout_item == "" else 8.0
							entry.size = [maxf(floor_x, typed.x), maxf(floor_y, typed.y)]
						else:
							entry.offset = [typed.x, typed.y]
				layout_saved = false
			layout_typing = false
		KEY_BACKSPACE:
			layout_typed = layout_typed.substr(0, maxi(0, layout_typed.length() - 1))
		_:
			var ch := char(key.unicode) if key.unicode > 0 else ""
			if ch != "" and "0123456789.,+- ".contains(ch):
				layout_typed += ch
	hud.queue_redraw()
	return true


## A number the way a person would type it back: no trailing ".0" on whole
## offsets, one decimal on the rest.
func _trim_num(v: float) -> String:
	if is_equal_approx(v, roundf(v)):
		return str(int(roundf(v)))
	return "%.1f" % v


## F12: one photograph of the CURRENT screen with the editor chrome hidden —
## the single-screen evidence shot, into the same folder the batch tool fills.
## Windowed only by nature (SG-29: readback hangs headless), which the editor
## always is — it is a thing a person is looking at.
func _snap_screen() -> void:
	if hud.edit_hide:
		return
	hud.edit_hide = true
	hud.queue_redraw()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	hud.edit_hide = false
	hud.queue_redraw()
	if img == null:
		layout_shot = "(no frame came back)"
		return
	var dir := ProjectSettings.globalize_path("res://.shots/screens")
	DirAccess.make_dir_recursive_absolute(dir)
	## Named by the frame that actually came back, not the design canvas.
	var file := "edit-%s-%dx%d.png" % [hud.edit_screen, img.get_width(), img.get_height()]
	img.save_png(dir + "/" + file)
	layout_shot = ".shots/screens/" + file


## --- the screen picker and the posed sandbox (SG-44) -------------------------

## The HUD a person is actually looking at: the sandbox's while a pose is up.
func _pose_hud() -> SkyGearHUD:
	return pose_game.hud if pose_game != null else hud


func _picker_index(name: String) -> int:
	for i in ScreenPoser.SCREENS.size():
		if str(ScreenPoser.SCREENS[i].name) == name:
			return i
	return 0


## The picker: P lists every screen the audit shoots — the poser's own list, so
## the editor cannot cover less than the batch page covers. Arrows + Enter or a
## click poses one; Esc, P again or a click outside closes the list. Only the
## editor session's OWNER runs this; a sandbox hands everything back.
func _picker_input(event: InputEvent) -> bool:
	if pose_owner != null:
		return false
	var typing: bool = layout_typing \
		or (pose_game != null and pose_game.layout_typing)
	if not layout_picker:
		if event is InputEventKey and event.pressed and not event.echo \
				and (event as InputEventKey).keycode == KEY_P and not typing:
			layout_picker = true
			picker_at = _picker_index(pose_name)
			_pose_hud().queue_redraw()
			return true
		return false
	## Open: the list owns every event until it closes.
	if event is InputEventMouseButton and event.pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var where: Vector2 = _pose_hud().get_local_mouse_position()
		var rows: Array = _pose_hud().picker_rows
		for i in rows.size():
			if (rows[i] as Rect2).has_point(where):
				picker_at = i
				pose_screen(str(ScreenPoser.SCREENS[i].name))
				return true
		## Clicking away closes, same as the typed-offset box.
		layout_picker = false
		_pose_hud().queue_redraw()
		return true
	if event is not InputEventKey or not event.pressed:
		return true
	var key := event as InputEventKey
	## EXCEPT CTRL+S (SG-83). The list owning "every event" meant the one key
	## that commits your work was dead while it was open, with no sign of it —
	## and "I pressed Ctrl+S and nothing happened" is exactly what was reported.
	## Saving is never modal.
	if key.ctrl_pressed and key.keycode == KEY_S:
		if SkyGearHUD.layout == null:
			SkyGearHUD.layout = SkyGearHudLayout.load_layout()
		_save_layout(SkyGearHUD.layout)
		_pose_hud().queue_redraw()
		return true
	match key.keycode:
		KEY_ESCAPE, KEY_P:
			layout_picker = false
		KEY_UP:
			picker_at = maxi(0, picker_at - 1)
		KEY_DOWN:
			picker_at = mini(ScreenPoser.SCREENS.size() - 1, picker_at + 1)
		KEY_ENTER, KEY_KP_ENTER:
			pose_screen(str(ScreenPoser.SCREENS[picker_at].name))
	_pose_hud().queue_redraw()
	return true


## Pose any audit screen right here. Builds the sandbox on first use — a second,
## hidden, silent `main.tscn` the shared poser drives — and freezes the live
## game for as long as a pose is up. The sandbox is reused across picks exactly
## as the audit reuses one game across its whole matrix, and the poser starts
## every pose from a clean ephemeral workshop either way.
func pose_screen(name: String) -> void:
	if not layout_edit or _posing:
		return
	var screen: Dictionary = ScreenPoser.find(name)
	if screen.is_empty():
		return
	layout_picker = false
	_posing = true
	pose_name = name
	if pose_game == null:
		## Freeze the run. `is_playing()` holds the boarders (they read it
		## every physics frame), `controls_enabled` holds the captain, and
		## `set_process(false)` holds the simulation clock — `run_time` must
		## not move a tick while the glass is up.
		_pose_controls = player.controls_enabled
		player.controls_enabled = false
		## Outright, not just deaf to input: a captain frozen mid-slide would
		## otherwise glide to a stop and recharge her dash under the glass, and
		## "exactly" means neither.
		player.set_physics_process(false)
		set_process(false)
		hud.visible = false
		var sandbox: SkyGearGame = (load(GAME_SCENE_PATH) as PackedScene).instantiate()
		## Set BEFORE it enters the tree, so `_ready`, `begin_run` and every
		## step after already know they are behind the glass: no sfx, no music,
		## no run log, no reaching through the shared groups.
		sandbox.pose_owner = self
		## Its 2D world is nobody's picture — the pose IS the HUD, and the HUD
		## rides a CanvasLayer, which parent visibility does not reach.
		sandbox.visible = false
		add_child(sandbox)
		sandbox.set_process_unhandled_input(false)
		## Its player's camera must never contest the live one.
		var cam := sandbox.player.get_node_or_null("Camera2D")
		if cam != null:
			cam.enabled = false
		## And its voice director would DUCK the live mix while it spoke — the
		## duck writes the shared audio buses. No clips, no lines, no duck.
		sandbox.voice.clips = {}
		sandbox.layout_edit = true
		pose_game = sandbox
	await ScreenPoser.pose(get_tree(), pose_game, pose_game.hud, screen, hud.size)
	if pose_game != null:
		## Still means STILL under an editor: the captain answers polled input
		## regardless of focus, so her physics stops outright — no drift while
		## a person is lining a label up.
		pose_game.player.set_physics_process(false)
		pose_game.player.controls_enabled = false
		pose_game.hud.queue_redraw()
	_posing = false


## Drop the pose: free the sandbox, thaw the run. The contract is the cutscene
## player's — what comes back is EXACTLY what was frozen — and the harness holds
## this side to it (`editor · and leaving the pose hands the run back exactly`).
func end_pose() -> void:
	if pose_game == null or _posing:
		return
	pose_game.queue_free()
	pose_game = null
	pose_name = ""
	layout_picker = false
	hud.visible = true
	set_process(true)
	player.set_physics_process(true)
	player.controls_enabled = _pose_controls
	hud.queue_redraw()


## 1-9 then 0, so ten rows are reachable without a cursor.
## Named, because a menu button calling `_set_state` directly is a menu button
## that has to know about states.
## Fullscreen, as a function rather than a key handler, so the settings row and
## F11 cannot drift apart.
func toggle_fullscreen() -> void:
	var full: bool = DisplayServer.window_get_mode() in [
		DisplayServer.WINDOW_MODE_FULLSCREEN,
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full
		else DisplayServer.WINDOW_MODE_FULLSCREEN)
	if audio != null:
		audio.fullscreen = not full
		audio.save_settings()


## OPEN ALL HEATS (board SG-160), on the same shape as `toggle_fullscreen` and
## for the same reason: one function, so the settings row and the file on disk
## cannot disagree. Turning it OFF while a high rung is picked does not need to
## reach in and fix `heat` — `begin_run`'s clamp already refuses to start a run
## above the ceiling, and the title's own ladder re-clamps what it draws.
func toggle_open_heats() -> void:
	open_heats = not open_heats
	if audio != null:
		audio.open_heats = open_heats
		audio.save_settings()


func copy_report() -> void:
	copy_run_report()


## A different twelve waves. `restart_run` deliberately keeps the seed, so this
## is the other half of the pair rather than a variant of it.
func new_seed_run() -> void:
	go_to_title()
	set_seed_text(_random_seed_text())
	begin_run()


func quit_game() -> void:
	if audio != null:
		audio.save_settings()
	get_tree().quit()


func toggle_pause() -> void:
	if state == State.PLAY:
		_set_state(State.PAUSE)
	elif state == State.PAUSE:
		_set_state(State.PLAY)


## Start the same run again. The SAME seed, so "let me try that once more"
## means the same twelve waves rather than a different game — which is the only
## version of a restart that lets you learn anything.
func restart_run() -> void:
	var again := seed_text
	go_to_title()
	set_seed_text(again)
	begin_run()


## Which CONTROLS row a keypress selects. The mapping itself lives in
## `SkyGearKeybinds.SLOTS` beside the labels the sheet draws, because holding it
## in two places is what left PAUSE unreachable (DR-09b) — the sheet printed a
## digit this function had never been taught to read.
func _digit_slot(code: int) -> int:
	return SkyGearKeybinds.slot_for(code)


func _apply_rebind(event: InputEvent) -> void:
	var action: String = SkyGearKeybinds.REBINDABLE[rebinding_index][0]
	var clash := SkyGearKeybinds.rebind(action, event)
	rebind_conflict = clash
	if clash == "":
		rebinding_index = -1
	hud.queue_redraw()


func _process(delta: float) -> void:
	## Effects and the renderer keep running through a hit-stop — a frozen frame
	## with a frozen explosion on it reads as a crash, not as impact. Only the
	## simulation stops.
	_update_effects(delta)
	if state != State.PLAY:
		queue_redraw()
		return
	delta = impact.advance(delta)
	if delta <= 0.0:
		queue_redraw()
		return
	## The draft can raise the dash ceiling, so the player has to be told. Synced
	## here rather than at the card, because a card that reaches into the player
	## is a card that has to be undone if the run is reset.
	## A CLASS WITH NO DASH KEEPS NO DASH. The `maxi(1, ...)` floor was written
	## when everyone had at least one, and it silently outranked the Boilerwright
	## the same way a const once outranked the card that raises this number — the
	## HUD showed him a dash pip he could not use. A class that starts at zero
	## stays at zero unless a card explicitly moves it.
	## A CLASS WITH NO DASH HAS NO DASH, unconditionally. The first version of
	## this let a card through: it only forced zero while `mods.dash_charges` was
	## at or below the default, so the one epic that RAISES it handed the
	## Boilerwright three dashes. A guard with an escape hatch is not a guard, and
	## the cards are now gated too — belt and braces, because this exact number
	## has escaped its ceiling twice before.
	if int(class_data().get("dashes", SkyGearPlayer.START_DASH_CHARGES)) <= 0:
		player.max_dash_charges = 0
	else:
		player.max_dash_charges = maxi(1, int(mods.dash_charges))
	_update_deckwork(delta)
	event_banner_left = maxf(0.0, event_banner_left - delta)
	coach_line = coach.advise(self, delta)
	_update_cooldowns(delta)
	_update_active_channel(delta)
	_update_wave(delta)
	_update_projectiles(delta)
	_update_passives(delta)
	_update_sentries(delta)
	_update_pressure(delta)
	_update_salvage(delta)
	_update_fire_fields(delta)
	_update_taps(delta)
	## KEEL HAULING. Anything the dash passes through comes with you — which turns
	## a dash from an escape into a way to MOVE the fight, and is the only thing
	## in the game that lets you take a boarder off a lane rather than off its
	## feet. Applied while the dash is live rather than on contact, so a boarder
	## caught at the start is still coming at the end.
	if article("keel_hauling") and player.dash_time_left > 0.0:
		var drag: Vector2 = player.velocity * delta * 0.85
		for enemy in enemies():
			if not is_instance_valid(enemy) or enemy.dead:
				continue
			if enemy.global_position.distance_to(player.global_position) > 90.0:
				continue
			## Mass resists it, same as knockback — a Colossus is not being towed.
			enemy.global_position += drag / maxf(1.0, float(enemy.mass) * 0.5)
	brace_cooldown = maxf(0.0, brace_cooldown - delta)
	brace_left = maxf(0.0, brace_left - delta)
	_check_deadman()
	run_time += delta
	_update_turrets(delta)
	_update_crew(delta)
	_update_hulk(delta)
	_process_skill_input(delta)
	_process_basic_attack(delta)
	_process_dash_impacts()
	queue_redraw()

## IS THE SIMULATION FROZEN THIS INSTANT — the hit-stop, asked rather than
## assumed (board SG-286).
##
## `_process` already gates ITSELF on `impact.advance`, and its comment says
## "Only the simulation stops." The simulation's two MOVING BODIES are not in
## `_process`: `SkyGearPlayer._physics_process` and `SkyGearEnemy._physics_process`
## are, and until this existed nothing outside `impact.gd` had ever read
## `stop_left` at all. So a 0.070 s kill-stop paused the wave logic and the
## projectiles and left the swordsman and the twenty-one goblins running at full
## speed through the whole of it — a captain who killed mid-dash covered 116
## ground units inside a window the player was being told was frozen.
##
## THE THREE CONDITIONS ARE EACH LOAD-BEARING. `state == State.PLAY`, because
## `_process` returns BEFORE `advance` in every other state and a `stop_left`
## that is never decremented would freeze the bodies for good — including the
## dead hero's own slide to a halt in GAMEOVER (SG-282). `impact.enabled`,
## because the harness turns hit-stop off in `_new_game` precisely so a check
## that advances three seconds advances three seconds. And `stop_left > 0.0`,
## which is the stop itself.
##
## The RENDERER is deliberately not gated by this and must not be: `_process`'s
## own comment is right that a frozen frame with a frozen explosion on it reads
## as a crash rather than as impact. Effects, particles and the camera keep
## running. What stops is what the word says — the simulation.
func sim_frozen() -> bool:
	return state == State.PLAY and impact != null and impact.enabled \
		and impact.stop_left > 0.0


func is_playing() -> bool:
	## A pose freezes both sides of the glass (SG-44): the live run holds its
	## breath while a sandbox is posed over it — this is what stops its boarders
	## walking while the person is aligning GAMEOVER — and a posed sandbox is a
	## still picture, so its own boarders hold too. The enemies read this every
	## physics frame; nothing else does.
	return state == State.PLAY and pose_game == null and pose_owner == null


## THIS game's enemies and props — never the tree's (board SG-50). Both groups
## are tree-wide, and there was exactly one game per tree until the harness grew
## a second and the F4 picker's sandbox made two-at-once the normal case. Every
## sweep that iterated the raw group then reached through the glass:
## `go_to_title` on a posed sandbox would have FREED the live run's boarders and
## props, `restow_props` would have swept its deck, and the sandbox's auto-attack
## would have cut down boarders in a run the player gets back "exactly as it
## was". Every simulation sweep goes through these two now.
func enemies() -> Array[Node]:
	var mine: Array[Node] = []
	for node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(node) and node.game == self:
			mine.append(node)
	return mine


func props() -> Array[Node]:
	var mine: Array[Node] = []
	for node in get_tree().get_nodes_in_group("props"):
		if is_instance_valid(node) and node.game == self:
			mine.append(node)
	return mine

## The salt that makes `visual_rng` a SEEDED stream instead of an auto-randomized
## one (board SG-120). It is a constant rather than a wave term because the
## cosmetic stream is per-RUN, and it is checked against the only other salted
## stream in the game by `seed · the cosmetic stream cannot collide with a tempo
## stream` — the tempo deal is `hash(seed_text) ^ (wave * 2654435761 + 7919)`,
## and this value is not of that form for any wave the game deals.
const VISUAL_SALT := 0x5C0BE11A

func set_seed_text(text: String) -> void:
	## A seed a player can hand to someone else. Same idea as the browser's
	## ?seed=, and the reason card rolls draw from `rng` and never from
	## randf() at the call site.
	seed_text = text.strip_edges().to_upper()
	if seed_text == "":
		seed_text = _random_seed_text()
	rng.seed = hash(seed_text)
	## AND THE COSMETIC STREAM IS SEEDED TOO (board SG-120). It never was:
	## `visual_rng` was a bare `RandomNumberGenerator.new()`, which Godot 4
	## auto-randomizes, so the promise written three lines above — that a seed
	## reproduces a run — was false for everything drawn from it. Mostly that
	## is floater jitter and nobody would notice; it is NOT cosmetic where the
	## `extra_kegs` talent places its kegs, because a keg is 26 damage inside
	## 192 units and a lane-clearing bomb when it goes off, so two players on
	## one seed got different decks.
	##
	## Seeded HERE, beside `rng`, rather than at `begin_run` where the row
	## suggested: this is the one function that knows the seed, so the two
	## streams cannot get out of step, and a tool that sets a seed without
	## starting a run (most of `tools/`) gets a reproducible picture too.
	## The XOR salt is the SG-57 isolated-stream idiom — it consumes nothing
	## from `rng` and shares no state with it.
	visual_rng.seed = hash(seed_text) ^ VISUAL_SALT


func _random_seed_text() -> String:
	const ALPHABET := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var out := ""
	var source := RandomNumberGenerator.new()
	source.randomize()
	for _i in 6:
		out += ALPHABET[source.randi_range(0, ALPHABET.length() - 1)]
	return out


## The class table, for whoever is aboard.
func class_data() -> Dictionary:
	return SkyGearData.CLASSES.get(class_id, SkyGearData.CLASSES.captain)


func set_class(id: String) -> void:
	## A DEMO SAILS WITH ONE CAPTAIN (SG-213). Enforced at the setter rather than
	## only by hiding the picker, because a save written by the full game — which
	## a friend running both builds will have — carries a `class_id` this build
	## must not honour.
	if SkyGearDemo.active():
		class_id = SkyGearDemo.CLASS_ID
		return
	if SkyGearData.CLASSES.has(id):
		class_id = id


## Is the gauge a bank rather than a meter? Everything about the Boilerwright
## follows from this one answer, so it is asked in one place.
func gauge_is_banked() -> bool:
	return not bool(class_data().get("gauge_from_damage", true))


## OVERPRESSURE. Every weapon hits harder while there is anything in the bank,
## and each cast spends some — so the bonus is not a reward for hoarding, it is
## the thing hoarding is FOR, and it runs out.
func overpressure_multiplier() -> float:
	if pressure <= 0.0:
		return 1.0
	return 1.0 + float(class_data().get("overpressure", 0.0))


func spend_overpressure() -> void:
	var cost: float = float(class_data().get("overpressure_cost", 0.0))
	if cost <= 0.0:
		return
	pressure = maxf(0.0, pressure - cost)
	player.set_pressure(pressure)


## HOW LONG AGO OVERPRESSURE WENT OUT, for the HUD to flash.
##
## The bonus is a plain multiplier that has never appeared anywhere on screen,
## so from the player's chair it does not exist — which is most of "I'm not sure
## I understand what the class actually does". A gauge falling to zero has to
## read as something being TAKEN, not as a bar reaching the bottom.
var overpressure_lost := 0.0
var _had_overpressure := false


## Watch the one boundary that matters and announce both crossings. Done in one
## place, after every spend has already run for the frame, because there are four
## paths out of the bank — a cast, a jet, a main and a blowdown — and four call
## sites announcing the same event is the shape of bug this project keeps
## shipping.
func _watch_overpressure(delta: float) -> void:
	overpressure_lost = maxf(0.0, overpressure_lost - delta)
	if not gauge_is_banked():
		_had_overpressure = false
		return
	var up: bool = pressure > 0.0
	if up == _had_overpressure:
		return
	_had_overpressure = up
	if up:
		add_floater("OVERPRESSURE", player.global_position, Color("#ff9a4a"), true)
		return
	overpressure_lost = 1.6
	add_floater("OVERPRESSURE LOST", player.global_position, Color("#ff4d37"), true)
	play_sfx("player/hurt.ogg", -14.0)


func begin_run() -> void:
	## FIRST. Everything this run constructs — the cannons, the Boiler, the body —
	## reads `talents`, so resolving it after any of them is a talent that applies
	## to nothing. Shot Locker did exactly that until a check compared a kitted
	## cannon against a bare one and found them identical.
	## Clamped on the way in, so a save file edited to Heat 9 is Heat 2 — and, with
	## OPEN ALL HEATS on (board SG-160), Heat 5 rather than Heat 2, because the
	## ceiling is what the player may be OFFERED. What such a run is worth is not
	## decided here: `SkyGearWorkshop.bank` reads `heat_available` and pays a
	## bypassed run nothing, so there is still exactly one place that knows the
	## rule.
	heat = clampi(heat, 0, SkyGearWorkshop.heat_ceiling(workshop, open_heats))
	talents = SkyGearWorkshop.resolved(workshop)
	articles = SkyGearWorkshop.articles_for(workshop, class_id)
	## THE SHIP, RESOLVED ONCE — the fittings' whole application point (board
	## SG-56, the owner's rule verbatim: "the ship itself shouldn't change
	## during the playthrough… modification should happen in between runs").
	## Snapshotted HERE and never re-read: `restow_props` places the set's
	## geometry each wave from this array, the clamp reads `fitting_walls`,
	## the verb table asks `fitted()`. Editing the workshop's berths after
	## this line changes the NEXT run, pinned by `fittings · the ship never
	## changes mid-run — a berth signed mid-run waits for the next run`.
	refresh_berthed()
	winch_cooldown = 0.0
	berths_open = false
	article_used = {}
	brace_cooldown = 0.0
	brace_left = 0.0
	_cancel_active_channel()
	range_multiplier = 1.0 + talent("range")
	## Never mid-run. A tree you can edit while being shot at is a fifth ability
	## button, which is the one thing the design says it must not become.
	workshop_open = false
	coach.reset()
	coach_line = ""
	settings_open = false
	keys_open = false
	how_open = false
	compare_open = false
	for enemy in enemies():
		enemy.queue_free()
	for prop in props():
		prop.queue_free()
	player.reset_for_run()
	player.visible = true
	wave = 0
	boiler_hp = boiler_max_hp
	skills.clear()
	projectiles.clear()
	effects.clear()
	salvage.clear()
	fire_fields.clear()
	spawn_queue.clear()
	damage_multiplier = 1.0
	pressure = 0.0
	pressure_grace = 0.0
	overpressure_lost = 0.0
	_had_overpressure = false
	taps.clear()
	tap_cooldown = 0.0
	vent_cooldown = 0.0
	basic_cooldown = 0.0
	## And the beat with it (SG-208): a run that opened on the return cut would
	## be a run whose first swing pays for ground the player was never asked to
	## take. Every run starts on the port cut.
	basic_swing_serial = 0
	end_reason = ""
	## THE CORE IS A CHOICE MADE INSIDE A RUN NOW (board SG-275), so both halves of
	## it are cleared here. Without the first line the offer arrives once per
	## session rather than once per run; without the second, run one's Frost Cleave
	## is still swinging in run two — which is `boiler_max_hp`'s bug (SG-271) with
	## a different field's name on it.
	core_offered = false
	auto_element = ""
	opening_draft = true
	## The establishing shot is owed for this run; the renderer spends it on wave 1.
	run_opening = true
	draft_options.clear()
	turrets = SkyGearLanes.make_turrets(LANE_CENTERS, BASE_Y)
	## SHOT LOCKER. Applied here rather than inside `make_turrets`, because the
	## lanes module is shared with the harness's own fixtures and a talent
	## reaching into it would make every lane test depend on a save file.
	if talent("turret_hp") > 0.0:
		for t in turrets:
			t.max_hp = float(t.max_hp) * (1.0 + talent("turret_hp"))
			t.hp = float(t.max_hp)
	## HEAT 5 · SKELETON CREW brings the deck cannons up half-dead. Applied after
	## Shot Locker so the two compose — a talent that buys +15% health still buys
	## it, the ladder just starts you lower. `hp` follows `max_hp` so a cannon is
	## at its (reduced) full, not merely capped.
	var heat_turret: float = SkyGearWorkshop.turret_hp_scale_for(int(heat))
	if not is_equal_approx(heat_turret, 1.0):
		for t in turrets:
			t.max_hp = float(t.max_hp) * heat_turret
			t.hp = float(t.max_hp)
	## THE SPARE GUN (SG-56). Appended AFTER Shot Locker and the Heat scale,
	## which both set `hp = max_hp` — a gun that ships dead has to stay at
	## zero, so its `max_hp` takes the same two scales by hand and its `hp`
	## does not. The repair verb that already exists is how it ever fires.
	if fitted("spare_gun"):
		var spare: Dictionary = SkyGearFittings.spare_gun_turret()
		spare.max_hp = float(spare.max_hp) * (1.0 + talent("turret_hp")) * heat_turret
		turrets.append(spare)
	crew.clear()
	sentries.clear()
	hulk = {}
	crew_timer = 2.5
	mods = SkyGearCards.fresh_mods()
	## Five attribution buckets under THE SECOND HAND, or the fifth hand's work
	## would be silently dropped from the report and the draft's slot targeting.
	tel = SkyGearTelemetry.fresh(skill_capacity())
	cards_taken.clear()
	## HEAT 3 · COLD DECK cuts the starting rerolls to one. The base is capped
	## here and the Deep Pockets talent adds onto it below, so the ladder sets the
	## floor and the tree lifts off it rather than the two fighting over one number.
	rerolls = SkyGearWorkshop.start_rerolls_for(int(heat), int(SkyGearData.DRAFT.rerolls))
	heal_budget = float(SkyGearData.CLOSE.heal_cap_per_sec)
	steal_budget = float(SkyGearData.CLOSE.lifesteal_cap_per_sec)
	run_time = 0.0
	src_slot = -1
	if seed_text == "":
		set_seed_text("")
	## WHAT THE WORKSHOP GRANTS, resolved once here and never again. A talent that
	## could change mid-run would be a card, and cards are the draft's job.
	##
	## Applied BEFORE the class kit reads `hp`, so a Padded Coat stacks onto
	## whichever body the class describes rather than onto the captain's.
	player.dash_recharge_bonus = talent("dash_recharge")
	mods.crit_chance = float(mods.crit_chance) + float(talents.get("crit_chance", 0.0))
	mods.pressure_rate = float(mods.pressure_rate) + float(talents.get("pressure_rate", 0.0))
	mods.vent_heal = float(mods.vent_heal) + float(talents.get("vent_heal", 0.0))
	mods.vent_radius = float(mods.vent_radius) + float(talents.get("vent_radius", 0.0))
	rerolls += int(talents.get("rerolls", 0.0))
	## THE OPENING BID's cost, applied AFTER every grant so nothing lifts it back
	## up: the bid is final, and a vow Deep Pockets could buy out of would be a
	## discount rather than a vow. (`reroll_draft` refuses too, for the rerolls a
	## CARD might add mid-run — SPARE PARTS also stops being dealt.)
	if article("opening_bid"):
		rerolls = 0
	boiler_max_hp = BOILER_BASE_HP + float(talents.get("boiler_hp", 0.0))
	boiler_hp = boiler_max_hp

	## The body the class describes. Done here rather than in `SkyGearPlayer`
	## because the class is a run-level choice and the player node outlives runs.
	var kit: Dictionary = class_data()
	player.max_hp = float(kit.get("hp", SkyGearPlayer.MAX_HP)) 		+ float(talents.get("max_hp", 0.0))
	player.hp = player.max_hp
	player.move_speed = float(kit.get("speed", SkyGearPlayer.SPEED)) 		* (1.0 + float(talents.get("move_speed", 0.0)))
	player.max_dash_charges = int(kit.get("dashes", SkyGearPlayer.START_DASH_CHARGES))
	player.dash_charges = player.max_dash_charges
	## THE OPENING BID: the opening hand is not dealt, it is named. The whole
	## matrix, from the first draft of the run.
	if article("opening_bid"):
		draft_options = _bid_matrix()
	else:
		for skill in SkyGearData.STARTING_SKILLS:
			var instance := SkyGearData.make_skill(skill.shape, skill.element)
			draft_options.append(_weapon_option(instance))
	draft_cursor = 0
	_set_state(State.DRAFT)


## One weapon as one draft option — the dict the card face, the click handler
## and `choose_draft` all read. Built here once; it used to be written out
## longhand in two places and The Opening Bid would have made it four.
func _weapon_option(instance: Dictionary) -> Dictionary:
	return {
		"kind": "skill",
		"scope": SkyGearCards.SCOPE_NEW,
		"class_label": SkyGearCards.SCOPE_LABEL[SkyGearCards.SCOPE_NEW],
		"rarity": SkyGearCards.RARITY_DEFAULT,
		"slot": skills.size(),
		"title": SkyGearData.skill_name(instance).to_upper(),
		"text": "%s · %s" % [SkyGearData.SHAPES[instance.shape].kind,
			SkyGearData.ELEMENTS[instance.element].blurb],
		"skill": instance,
	}


## THE OPENING BID's whole matrix: every draftable shape you do not already
## hold, in all four elements, shape-major so cell (row, col) is index
## row * 4 + col — the same order `SkyGearHUD.bid_cells` lays the grid out in.
## Deterministic and rng-free: naming a cell is the opposite of a deal.
func _bid_matrix() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var used: Array[String] = []
	for skill in skills:
		used.append(skill.shape)
	## THE KEYLESS WELL TAKES ONLY WHAT FIGHTS ALONE (board SG-279). The Article
	## opens the matrix instead of dealing it, and "everything you do not hold" was
	## read as literally everything — which put a Mortar in the well with no key.
	## Same rule as the weighted dealer, asked through the same function.
	var pool: Array = alone_shapes() if keyless_draft() else DRAFT_SHAPES
	var fresh: Array = []
	for shape in pool:
		if not str(shape) in used:
			fresh.append(str(shape))
	## AND IF YOU HOLD EVERY ONE OF THEM ALREADY, THE OFFER IS THEM AGAIN. Two
	## self-firing shapes exist, so a hand of four that has taken both would filter
	## this matrix down to nothing — and an empty draft is not a hard choice, it is
	## a run that cannot continue: `choose_draft` has no index to accept and the
	## state never leaves DRAFT. The weighted dealer already falls through its own
	## guard to a duplicate for this case; this is the same answer, said out loud.
	if fresh.is_empty():
		fresh = pool.duplicate()
	for shape in fresh:
		for element in ["EMBER", "FROST", "ARC", "STEAM"]:
			out.append(_weapon_option(SkyGearData.make_skill(str(shape),
				str(element))))
	return out

## The run report. Same shape as the browser build's, because the point of it is
## that a tester pastes it into a message and the numbers mean the same thing on
## both sides — including which skill actually did the work, which is the
## question every balance conversation so far has had to guess at.
func run_report() -> String:
	var lines: Array[String] = []
	var won := state == State.VICTORY
	## The first line COPY REPORT puts on a tester's clipboard, so it is the
	## first line of every bug report and every balance conversation this game
	## will ever have. It said "Godot port" (board SG-211).
	lines.append("SKYGEAR")
	## ONE OUTCOME, ONE NOUN. The screen has always said DECK LOST
	## (`hud.gd::_draw_results`) while the clipboard said BOARDED — two words
	## for the single moment a frustrated player is most likely to screenshot,
	## and the pair that reads as a bug in a bug report. DECK LOST wins because
	## it is the half the player actually sees and because it is the true
	## opposite of DECK HELD; BOARDED named the cause, not the outcome.
	lines.append(("DECK HELD" if won else "DECK LOST") + " — " + end_reason)
	var header := "wave %d/%d · %s · seed %s" % [wave, SkyGearDemo.last_wave(),
		_format_time(run_time), seed_text]
	## A Heat run's seed replays the same waves against different enemy health,
	## so a report line that hides its Heat is a report that cannot reproduce
	## its own run. Heat 0 stays silent — STOKED is the ground, not a mode.
	if heat > 0:
		header += " · Heat %d" % heat
	lines.append(header)
	## The berthed set is part of what the seed replays onto, so a fitted run's
	## report names it — and a bare ship stays silent, which keeps every
	## pre-fitting report byte-identical (the same rule as the Heat suffix).
	if not run_fittings.is_empty():
		var kept: Array[String] = []
		for fit_id in run_fittings:
			kept.append(str((SkyGearFittings.FITTINGS.get(str(fit_id), {}) as Dictionary
				).get("name", str(fit_id))))
		lines.append("refit · " + ", ".join(kept))
	var build: Array[String] = ["%s (auto)" % auto_name()]
	for skill in skills:
		build.append(SkyGearData.skill_name(skill))
	lines.append("build: " + "  /  ".join(build))
	if not cards_taken.is_empty():
		lines.append("draft: " + ", ".join(cards_taken))

	var total := float(tel.basic.damage) + float(tel.deck.damage) + float(tel.allies.damage)
	for row in tel.per:
		total += float(row.damage)
	if total > 0.0:
		lines.append("")
		lines.append("skills — damage · share · casts · kills")
		lines.append(_report_row(auto_name().to_lower(), float(tel.basic.damage), total,
			int(tel.basic.casts), int(tel.basic.kills)))
		for i in tel.per.size():
			var row: Dictionary = tel.per[i]
			if str(row.shape) == "":
				continue
			lines.append(_report_row(
				SkyGearData.skill_name({"shape": row.shape, "element": row.element}),
				float(row.damage), total, int(row.casts), int(row.kills)))
		if float(tel.allies.damage) > 0.0:
			lines.append(_report_row("crew and cannons", float(tel.allies.damage), total, 0, 0))
		if float(tel.deck.damage) > 0.0:
			lines.append(_report_row("the deck", float(tel.deck.damage), total, 0, 0))
	var reaction_rows: Array[String] = []
	var reaction_ids: Array[String] = []
	for reaction_id in tel.get("reactions", {}).keys():
		reaction_ids.append(str(reaction_id))
	reaction_ids.sort()
	for reaction_id in reaction_ids:
		var reaction: Dictionary = tel.reactions[reaction_id]
		if int(reaction.get("triggers", 0)) <= 0:
			continue
		reaction_rows.append("  %-20s %7d  %d triggers" % [
			reaction_id, roundi(float(reaction.get("damage", 0.0))),
			int(reaction.get("triggers", 0))])
	if not reaction_rows.is_empty():
		lines.append("")
		lines.append("reactions — damage · triggers")
		lines.append_array(reaction_rows)
	var rt: Dictionary = tel.range_time
	var span: float = float(rt.close) + float(rt.mid) + float(rt.far) + float(rt.none)
	if span > 1.0:
		lines.append("range: %d%% close · %d%% mid · %d%% far · %d%% clear" % [
			roundi(float(rt.close) / span * 100.0), roundi(float(rt.mid) / span * 100.0),
			roundi(float(rt.far) / span * 100.0), roundi(float(rt.none) / span * 100.0)])
	lines.append("vents %d · healed %d · salvage %d · rerolls %d" % [
		int(tel.vents), roundi(float(tel.healed)), int(tel.salvage), int(tel.rerolls)])
	return "\n".join(lines)


func _report_row(name: String, damage: float, total: float, casts: int, kills: int) -> String:
	return "  %-20s %7d  %d%%   %d casts  %d kills" % [
		name, roundi(damage), roundi(damage / maxf(1.0, total) * 100.0), casts, kills]


func _format_time(seconds: float) -> String:
	return "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]


func copy_run_report() -> void:
	DisplayServer.clipboard_set(run_report())
	copied_at = run_time


func go_to_title() -> void:
	_cancel_active_channel()
	if audio != null:
		audio.stop_music()
	for enemy in enemies():
		enemy.queue_free()
	for prop in props():
		prop.queue_free()
	player.visible = false
	projectiles.clear()
	effects.clear()
	_set_state(State.TITLE)

func _set_state(next_state: State) -> void:
	var was := state
	state = next_state
	state_name = State.keys()[state]
	player.controls_enabled = state == State.PLAY
	if next_state in [State.TITLE, State.DRAFT, State.GAMEOVER, State.VICTORY]:
		_cancel_active_channel()
	## A finished run goes on disk. One run is an anecdote; the reason v11 tracks
	## damage per skill and time at each range is so ten of them can be read as a
	## shape, and a report that dies when you press Enter cannot be.
	## SG-67: the third ending had no sentence. Both defeats have always named
	## themselves — "%s fell on wave %d." (SG-261: the drawn class's own name,
	## not a hardcoded "The captain"), "The Boiler was destroyed on
	## wave %d." — and a win arrived with `end_reason` still empty, so the run
	## report's second line read `DECK HELD — ` and the results screen printed
	## nothing under the verdict. The browser's own line, verbatim. Written HERE
	## rather than at the two `_set_state(State.VICTORY)` call sites (the last
	## wave clearing, and a wave started past the end of the table) because a
	## reason kept in two places is a reason that drifts; and only when nothing
	## has already been said, so a posed VICTORY keeps the line the poser set.
	if next_state == State.VICTORY and end_reason == "":
		end_reason = "Twelve waves repelled. The deck is yours."
	if was != next_state and (next_state == State.VICTORY or next_state == State.GAMEOVER):
		## `log_runs` is off for POSED endings (board SG-49): the audit, the
		## batch camera and the F4 picker all walk a game through GAMEOVER and
		## VICTORY as a pose, and every one of those was a fake row in the
		## player's own run log — a dozen per audit pass. A pose still shows
		## `run_logged` true, because "saved to the run log" is the healthy
		## string the screen is being measured and aligned with.
		run_logged = not log_runs or SkyGearRunLog.record({
			"won": next_state == State.VICTORY,
			"wave": wave,
			"time": _format_time(run_time),
			"seed": seed_text,
			"build": _build_names(),
			"cards": cards_taken.duplicate(),
			"reason": end_reason,
			"vents": int(tel.vents),
			"healed": roundi(float(tel.healed)),
			"salvage": int(tel.salvage),
			"rerolls": int(tel.rerolls),
			"close_share": _close_share(),
			"class_id": class_id,
			## Without this a Heat 2 row cannot reproduce its own run: the seed
			## replays the same waves against different enemy health.
			"heat": heat,
			## And without THIS a fitted run cannot either: the berthed set is
			## part of the deck the seed replays onto (SG-53's blocked half,
			## closed by SG-56). Old rows simply lack the key and read bare.
			"ship": run_fittings.duplicate(),
			"report": run_report(),
		})
		## And what it was worth. Nothing accrues before a first victory — the
		## gate lives in `SkyGearWorkshop.bank`, not here, so there is exactly one
		## place that knows the rule.
		banked = SkyGearWorkshop.bank(workshop, {
			"won": next_state == State.VICTORY, "wave": wave,
			"seed": seed_text, "vents": int(tel.vents),
			"healed": roundi(float(tel.healed)),
			## Salvage rides along for the WINCH's earn rule — a field the run
			## row above already records, which is the fittings' whole bargain:
			## no new tracking.
			"salvage": int(tel.salvage),
			"close_share": _close_share(), "class_id": class_id,
			"heat": heat,
		})
	hud.queue_redraw()


func _build_names() -> Array[String]:
	var out: Array[String] = ["%s (auto)" % auto_name()]
	for skill in skills:
		out.append(SkyGearData.skill_name(skill))
	return out


## The fraction of the run spent inside close range, as a percentage. It is the
## one number that says whether the v11 loop landed, so it goes in the log on its
## own rather than only inside the report text.
func _close_share() -> int:
	var rt: Dictionary = tel.range_time
	var span: float = float(rt.close) + float(rt.mid) + float(rt.far) + float(rt.none)
	if span <= 0.0:
		return 0
	return roundi(float(rt.close) / span * 100.0)

## WHERE A DRAFTED WEAPON LANDS.
##
## Skills used to append in draft order, so the first two you took owned the
## left and right mouse buttons whatever they were — and AURA and PULSE are
## PASSIVE. They fire on their own timer and ignore the press entirely, so a run
## that drafted two passives early gave the player two dead mouse buttons and no
## way to move either.
##
## Actives take the mouse from the left; passives fill from the far end. Neither
## is locked — a fifth draft still has to go somewhere — but the common case
## stops being wrong.
func _slot_skill(skill: Dictionary) -> void:
	var passive: bool = bool(SkyGearData.SHAPES[skill.shape].get("passive", false))
	## Grow to the size we need, marking the gaps so they can be filled in
	## whichever order the class of skill prefers. Capacity is 4, or 5 under THE
	## SECOND HAND — and the fifth is passive by construction (`open_draft` deals
	## it only the shapes that fight alone), so the far end it fills from is the
	## keyless slot.
	while skills.size() < skill_capacity():
		skills.append({})
	var order: Array = range(skills.size() - 1, -1, -1) if passive \
		else range(skills.size())
	for slot in order:
		if (skills[slot] as Dictionary).is_empty():
			skills[slot] = skill
			_trim_empty_slots()
			return
	## Nothing free: the oldest of its own kind gives way, so a fifth passive
	## replaces a passive rather than evicting your Cleave.
	skills[order[0]] = skill
	_trim_empty_slots()


## The rest of the game counts `skills.size()` to mean "how many you have", so
## the placeholders cannot outlive the placement.
func _trim_empty_slots() -> void:
	var kept: Array[Dictionary] = []
	for entry in skills:
		if not (entry as Dictionary).is_empty():
			kept.append(entry)
	skills = kept


func choose_draft(index: int) -> void:
	if state != State.DRAFT or index < 0 or index >= draft_options.size():
		return
	var option: Dictionary = draft_options[index]
	cards_taken.append(str(option.get("title", "?")))
	match option.kind:
		"card":
			if option.has("apply"):
				option.apply.call(self)
		"skill":
			if skills.size() < skill_capacity():
				_slot_skill(option.skill.duplicate(true))
				if voice != null:
					voice.say("slot", 1)
		"damage":
			damage_multiplier *= 1.15
		"health":
			player.max_hp += 12.0
			player.heal(12.0)
		"boiler":
			boiler_hp = minf(boiler_max_hp, boiler_hp + 60.0)
		"pressure":
			pressure = minf(99.0, pressure + 35.0)
		"dash":
			player.refund_dash(0.65)
		"core":
			## The whole of the choice, in one assignment. Every reader in the game
			## goes through `auto_element_id()` — the swing, the renderer's tell,
			## the HUD ring, the run report — so they turn together or not at all.
			auto_element = str(option.get("element", ""))
	play_sfx("ui/card_pick.ogg", -4.0)
	draft_options.clear()
	## AND THE CORE DOES NOT END THE INTERMISSION (board SG-275). It was inserted
	## in FRONT of the draft, not in place of it, so what happens next is the draft
	## the player was owed: same wave, same position in the seeded stream, and
	## `core_offered` already latched so this cannot recur.
	if str(option.kind) == "core":
		open_draft()
		return
	if opening_draft:
		opening_draft = false
		start_wave(1)
	else:
		start_wave(wave + 1)

## A push wave grapples a fresh hulk to the hull. Without a fresh one per push
## the browser build spawned it once at run start and never reset it, so
## breaking it on wave 4 left it permanently dead — and wave 8 then satisfied
## its "ends when their hulk does" condition on the first frame.
## A boarding hulk grapples on and keeps sending them until it is broken.
## The event for a wave, or "" — the single place anything asks the question.
static func event_for(wave_number: int) -> String:
	return str(SkyGearData.WAVE_EVENTS.get(wave_number, ""))


## Does a boarding hulk grapple on this wave? The data says so for 4 and 8, and
## HEAT 4 · BOARDERS ALOFT adds 6 and 10. Every place that asks — the begin, the
## hulk-scaling count, the not-clear-until-the-hulk-is gate — asks HERE, so a
## push wave is one fact rather than three that can drift (failure mode two). Not
## static: it reads the run's own `heat`.
func is_push_wave(wave_number: int) -> bool:
	if wave_number < 1 or wave_number > SkyGearData.WAVES.size():
		return false
	return SkyGearWorkshop.pushes_on(int(heat), wave_number,
		bool(SkyGearData.WAVES[wave_number - 1].get("push", false)))


func event_data() -> Dictionary:
	if active_event == "":
		return {}
	return SkyGearData.EVENTS.get(active_event, {})


## Announce it and turn it on. Announced BEFORE the first boarder rather than
## alongside them: an event you notice halfway through is a difficulty spike.
func _begin_event(id: String) -> void:
	active_event = id
	var data: Dictionary = SkyGearData.EVENTS.get(id, {})
	if data.is_empty():
		return
	event_banner_left = EVENT_BANNER_TIME
	if voice != null:
		voice.say(str(data.get("voice", "wave_start")), 3)
	play_sfx("world/wave_start.ogg", -2.0)
	## No `_fx` banner. The event CARD says the name, and a flying banner saying it
	## again lands on top of the card — which is exactly how it looked.
	## The blackout is the only one that changes the deck rather than what is on
	## it, so the renderer has to be told.
	if view != null and view.has_method("set_darkness"):
		view.set_darkness(float(data.get("darkness", 0.0)))


func _end_event() -> void:
	if active_event == "" :
		return
	active_event = ""
	event_banner_left = 0.0
	if view != null and view.has_method("set_darkness"):
		view.set_darkness(0.0)


func _begin_push(wave_number: int) -> void:
	if voice != null:
		voice.say("push", 2)
	var index := 0
	for i in wave_number:
		if is_push_wave(i + 1):
			index += 1
	hulk = SkyGearLanes.make_hulk(BOW_Y, 1.0 + maxi(0, index - 1) * 0.20)
	## SEALED, and it stays that way for `HULK_GRAPPLE_TIME`. This line used to
	## read `hulk.vulnerable = true` — set on the frame it grappled and never
	## cleared — so `make_hulk`'s own `vulnerable: false` was dead the moment it
	## was written and the sealed state was unreachable in a shipped run. The
	## door opens in `_update_hulk`, which is also the only place it can now.
	hulk.grapple = HULK_GRAPPLE_TIME
	play_sfx("lane/hulk_grapple.ogg", -4.0)


func start_wave(next_wave: int) -> void:
	_cancel_active_channel()
	reset_field_anchors()
	wave = next_wave
	## A posed sandbox starts no music (SG-44) — the live game's own track is
	## already playing, and a second combat loop under a posed GAMEOVER is the
	## editor audibly leaking. Its one-shots die in `play_sfx`; this is the loop.
	if audio != null and pose_owner == null:
		var is_boss := next_wave >= 1 and next_wave <= SkyGearData.WAVES.size() 			and bool(SkyGearData.WAVES[next_wave - 1].get("boss", false))
		audio.play_music(audio.track_for(next_wave, is_boss))
	if wave > SkyGearDemo.last_wave():
		if voice != null:
			voice.say("victory", 4)
		_set_state(State.VICTORY)
		return
	restow_props()
	_end_event()
	if next_wave >= 1 and next_wave <= SkyGearData.WAVES.size():
		if is_push_wave(next_wave):
			_begin_push(next_wave)
		var event_id := event_for(next_wave)
		if event_id != "":
			_begin_event(event_id)
	spawn_queue = _build_spawn_queue(wave)
	if voice != null and wave > 0:
		voice.say("wave_start", 1)
	## Wave-start talents. Flat, capped, and paid at the one moment a player is
	## reading the screen rather than being shot at.
	var granted: Dictionary = SkyGearWorkshop.resolved(workshop)
	if float(granted.get("wave_heal", 0.0)) > 0.0:
		player.heal(float(granted.wave_heal))
	if float(granted.get("wave_pressure", 0.0)) > 0.0:
		pressure = maxf(pressure, float(granted.wave_pressure))
		player.set_pressure(pressure)
	if float(granted.get("boiler_repair", 0.0)) > 0.0 and wave > 1:
		boiler_hp = minf(boiler_max_hp, boiler_hp + float(granted.boiler_repair))
	article_used.erase("scuttle")
	article_used.erase("deadmans_switch")
	wave_time = 0.0
	wave_clear_time = -1.0
	projectiles.clear()
	player.heal(4.0)
	_set_state(State.PLAY)
	play_sfx("world/wave_start.ogg", -5.0)
	_fx({"kind": "banner", "text": "WAVE %d" % wave, "time": 0.0, "life": 2.0})

## --- TEMPO (board SG-57, ENEMY-VARIETY-DESIGN §2.2) --------------------------
## Surge and lull instead of one metronome for twelve waves. Three authored
## profiles, dealt per wave from an ISOLATED stream — the stowage spine's proven
## pattern (d10f09c), consuming nothing from `rng` or `visual_rng` — and a
## profile is a pure function from (batch, member) to a time offset at the one
## line below that writes `time`. The existing sort and the 64-cap absorb it.
const TEMPO_PROFILES: Array[String] = ["STEADY", "SURGE", "CRESCENDO"]
## Today's exact spacing, kept as the short mode everywhere: STEADY is
## byte-identical to the queue this game has always dealt.
const TEMPO_INTRA := 0.22
## No profile pushes a spawn more than this many seconds past the wave's
## authored last batch — the wave's length stays the author's call.
const TEMPO_OVERHANG := 8.0

## The deal for one wave: which profile, and the profile's rolled numbers.
## The stream is seeded `hash(seed_text) ^ (wave * 2654435761 + 7919)` — the
## `+ 7919` is a DIFFERENT salt than the cut stowage stream used (d10f09c,
## `wave * 2654435761` bare), so a future resurrection cannot collide with
## this one. Rolled fresh per wave, so nothing leaks between waves either.
##
## Pinned STEADY, by the design's own rules: waves 1–2 (the taught opening is
## §1's fixed list), event waves and push waves (4/8/12 — and BOARDERS ALOFT's
## extra pushes on 6/10 at Heat 4, because `is_push_wave` is the one place that
## question is asked). The roll happens BEFORE the pin so the stream is
## consumed uniformly; a pinned wave just discards it.
##
## `SKYGEAR_TEMPO_FLAT` is the kill-test lever (the SG-48 idiom): set, every
## wave deals STEADY and the run is today's rhythm exactly.
func tempo_for(wave_number: int) -> Dictionary:
	var stream := RandomNumberGenerator.new()
	stream.seed = hash(seed_text) ^ (wave_number * 2654435761 + 7919)
	var deal := {
		"profile": TEMPO_PROFILES[stream.randi_range(0, 2)],
		## SURGE: pulses of 2–4 spawns separated by 4–6 s lulls.
		"pulse": stream.randi_range(2, 4),
		"lull": stream.randf_range(4.0, 6.0),
		## CRESCENDO: spacing tightening monotonically through the wave.
		"wide": stream.randf_range(0.45, 0.65),
		"tight": stream.randf_range(0.06, 0.10),
	}
	if wave_number <= 2 			or event_for(wave_number) != "" or is_push_wave(wave_number) 			or OS.get_environment("SKYGEAR_TEMPO_FLAT") != "":
		deal.profile = "STEADY"
	return deal


## The pure function itself: (deal, batch, member index) -> seconds after the
## batch's authored time. STEADY is `member * 0.22`, today's line verbatim.
static func tempo_offset(deal: Dictionary, batch_time: float, count: int,
		member: int, wave_last: float) -> float:
	match str(deal.get("profile", "STEADY")):
		"SURGE":
			## Members arrive in pulses at the metronome's own 0.22, separated
			## by the dealt lull. The lull is never shrunk to fit — a 2.6 s
			## "lull" is the valley the kill-test forbids — so the number of
			## lulls is capped by the room instead: what the overhang allows
			## past this batch's authored start. A batch with no room (or one
			## member) degenerates to STEADY, honestly.
			var lull := float(deal.lull)
			var room := wave_last + TEMPO_OVERHANG - batch_time
			var max_lulls := maxi(0, int(floor((room - (count - 1) * TEMPO_INTRA) / lull)))
			var pulses := clampi(int(ceil(count / float(deal.pulse))), 1, max_lulls + 1)
			var base := int(floor(count / float(pulses)))
			var extra := count % pulses
			var first := 0
			var start := 0.0
			for p in pulses:
				var size := base + (1 if p < extra else 0)
				if member < first + size:
					return start + (member - first) * TEMPO_INTRA
				start += (size - 1) * TEMPO_INTRA + lull
				first += size
			return start
		"CRESCENDO":
			## Per-batch spacing slides from `wide` to `tight` along the wave's
			## authored timeline, so the drip tightens monotonically into a
			## flood. Worst case (7 members at 0.65) tops out at 3.9 s — well
			## inside the overhang by construction.
			var u := 0.0 if wave_last <= 0.0 else clampf(batch_time / wave_last, 0.0, 1.0)
			return member * lerpf(float(deal.wide), float(deal.tight), u)
		_:
			return member * TEMPO_INTRA


func _build_spawn_queue(wave_number: int) -> Array[Dictionary]:
	var queue: Array[Dictionary] = []
	var definition: Dictionary = SkyGearData.WAVES[wave_number - 1]
	var tempo := tempo_for(wave_number)
	var wave_last := 0.0
	for batch in definition.batches:
		wave_last = maxf(wave_last, float(batch[0]))
	for batch in definition.batches:
		var lanes: Array = []
		var lane_spec: Variant = batch[3] if batch.size() > 3 else rng.randi_range(0, 2)
		if lane_spec is String and lane_spec == "all":
			lanes = [0, 1, 2]
		else:
			lanes = [int(lane_spec)]
		for lane_value in lanes:
			for i in int(batch[2]):
				queue.append({
					"time": float(batch[0]) + tempo_offset(tempo, float(batch[0]), int(batch[2]), i, wave_last),
					"type": str(batch[1]),
					"lane": int(lane_value),
				})
	queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.time < b.time)
	return queue

func _update_wave(delta: float) -> void:
	if wave_clear_time >= 0.0:
		wave_clear_time -= delta
		if wave_clear_time <= 0.0:
			## `SkyGearDemo.last_wave()`, not `WAVES.size()` — the demo cut ends
			## the run at wave 6 (SG-213). The full build's answer is unchanged.
			if wave >= SkyGearDemo.last_wave():
				if voice != null:
					voice.say("victory", 4)
				_set_state(State.VICTORY)
			else:
				open_draft()
		return
	wave_time += delta
	while not spawn_queue.is_empty() and float(spawn_queue[0].time) <= wave_time and enemy_count() < 64:
		var entry: Dictionary = spawn_queue.pop_front()
		spawn_enemy(entry.type, entry.lane)
	## A push wave is not over until its hulk is. Otherwise the wave that exists
	## to make you leave the objective can be won by standing on the objective.
	var push_pending := false
	if wave >= 1 and wave <= SkyGearData.WAVES.size():
		if is_push_wave(wave):
			push_pending = hulk.is_empty() or not bool(hulk.get("dead", false))
	if spawn_queue.is_empty() and enemy_count() == 0 and wave > 0 and not push_pending:
		_cancel_active_channel()
		wave_clear_time = WAVE_CLEAR_TIME
		play_sfx("world/wave_clear.ogg", -4.0)
		if voice != null:
			voice.say("wave_clear", 1)
		_fx({"kind": "banner", "text": "WAVE CLEAR", "time": 0.0, "life": 1.6})
	elif push_pending and spawn_queue.is_empty() and enemy_count() < 6 and wave > 0 \
			and hulk_state() == "open":
		# they keep coming while the hulk lives — that is what it is for, and a
		# shut door sends nobody: the trickle is the DISGORGING, so it waits on
		# the state the renderer is drawing (SG-76). In practice the wave's own
		# queue outlasts the grapple window many times over, so this gates
		# nothing today — it is here so the picture and the simulation cannot
		# disagree the day either number moves.
		for lane in LANE_CENTERS.size():
			spawn_queue.append({"time": wave_time + 1.0 + lane * 0.4,
				"type": "SCRAPPER" if lane != 1 else "SWARM", "lane": lane})

## Weighted by how much the player actually uses a slot, never absolute: the
## least-used slot keeps a real chance, because an upgrade is also how a
## neglected skill becomes worth pressing. Roughly 3:1 in favour of the skill
## carrying the run.
func pick_slot_by_use(candidates: Array) -> int:
	if candidates.is_empty():
		return -1
	if candidates.size() == 1:
		return int(candidates[0])
	var weights: Array[float] = []
	var total := 0.0
	for i in candidates:
		var w: float = 0.25 + SkyGearTelemetry.use(tel, int(i)) * 2.25
		weights.append(w)
		total += w
	var roll := rng.randf() * total
	for k in candidates.size():
		roll -= weights[k]
		if roll <= 0.0:
			return int(candidates[k])
	return int(candidates[candidates.size() - 1])


## Three upgrade cards, weighted, no duplicates, drawn from the seeded stream.
func roll_upgrade_cards(count: int) -> Array[Dictionary]:
	var available: Array = []
	for card in SkyGearCards.catalogue():
		if bool(card.can.call(self)):
			available.append(card)
	var out: Array[Dictionary] = []
	var used := {}
	for _i in count:
		var pool: Array = []
		for card in available:
			if not used.has(card.id):
				pool.append(card)
		if pool.is_empty():
			pool = available
		if pool.is_empty():
			break
		var total := 0.0
		var weights: Array[float] = []
		for card in pool:
			var w: float = maxf(0.01, float(card.weight.call(self)))
			weights.append(w)
			total += w
		var roll := rng.randf() * total
		var index := pool.size() - 1
		for k in pool.size():
			roll -= weights[k]
			if roll <= 0.0:
				index = k
				break
		var chosen: Dictionary = pool[index]
		used[chosen.id] = true
		var instance: Dictionary = chosen.make.call(self, Callable(self, "pick_slot_by_use"))
		instance["id"] = chosen.id
		instance["kind"] = "card"
		instance["rarity"] = chosen.rarity
		instance["scope"] = chosen.scope
		instance["class_label"] = SkyGearCards.SCOPE_LABEL[chosen.scope]
		out.append(instance)
	return out


## Reroll. Two per RUN rather than per draft, so spending one is a decision
## about which hand was bad enough to be worth it. Refused once a card has been
## chosen, and it draws from the seeded stream so a replay that rerolls at the
## same moment sees the same second hand.
func reroll_draft() -> bool:
	## THE OPENING BID is final. Refused HERE as well as zeroed at `begin_run`,
	## because a card (SPARE PARTS) can add rerolls mid-run and the vow outranks
	## the card — this is the drawback path, and the harness executes it.
	if article("opening_bid"):
		return false
	## AND SO IS THE CORE OFFER, for the plainer reason that there is nothing in
	## it to roll: `_core_offer` deals all four elements every time and touches no
	## RNG. Refusing it is not a nicety — `open_draft` latches `core_offered`, so a
	## reroll here would spend the offer and hand back an ordinary draft.
	if core_draft():
		return false
	if state != State.DRAFT or rerolls <= 0:
		return false
	rerolls -= 1
	tel.rerolls += 1
	var was_opening := opening_draft
	open_draft()
	opening_draft = was_opening
	return true


## The eight draftable shapes — the rows of the 32-cell matrix. One list, used
## by the weighted dealer AND by The Opening Bid's open matrix, so the two can
## never disagree about what is draftable (failure mode two). CLOSEHIT is not
## here because the Cleave is the auto attack, not a card.
const DRAFT_SHAPES := ["CHAIN", "RANGED_AOE", "CONE", "LINE_BURST", "RAY",
	"AURA", "PULSE", "SENTRY"]


## --- THE KEYLESS WELL, AND THE ONE RULE IT HAS (board SG-279) -----------------
##
## THE SECOND HAND grants a fifth slot and there is no fifth key. That is what
## the Article IS — `hud.gd` prints AUTO on the well's tab instead of a binding,
## and the Articles' own rule is against a binding nobody remembers. So the fifth
## weapon has to be one that fires itself, or the player has bought a button they
## cannot press.
##
## THE RULE EXISTED AND ONE OF THE TWO DEALERS DID NOT ASK IT. `open_draft`'s
## weighted branch narrowed the fifth draft to the shapes carrying
## `passive: true`; `_bid_matrix` — the whole open grid THE OPENING BID deals
## instead — had no such filter and offered every shape in the game. Take a Mortar
## from it and `_slot_skill` fills actives forward into the only free index, which
## is 4, and `_process_skill_input` walks `skill_1..skill_4` and never reaches it.
##
## AND IT WAS NOT REACHABLE, WHICH IS SAID PLAINLY RATHER THAN QUIETLY FIXED.
## `workshop.gd`'s ARTICLES table gives The Opening Bid `"excludes":
## "second_hand"` and the Second Hand `"excludes": "opening_bid"`, and
## `can_take` enforces it — so no save can hold both, and no run has ever been
## able to open the matrix while the capacity is five. The owner's report
## (*"Let's make sure that that slot is always filled with an auto, because I
## found myself just spamming my moves a lot and just so many different hot keys
## to keep in mind"*) describes a thing that was already true; this is not the
## bug he hit.
##
## SO WHY THE FILTER STAYS. The invariant "the keyless well holds only what fires
## itself" was being guaranteed by a purchase constraint in a different file. That
## is the shape of a rule nobody can see from where it matters: lift the exclusion
## for any reason — a balance pass, a ninth Article, a Workshop rework — and the
## dead button comes back silently, in the one dealer that never asked. Both
## dealers ask the same two functions now, so the rule holds by construction here
## and the exclusion is what it should be, a design choice about Articles rather
## than the thing standing between a player and an unpressable slot.

## The shapes that fight on their own — Field and Pulse today, read off the
## table's own `passive` flag rather than named here, so a new self-firing shape
## joins them by being authored rather than by being remembered.
static func alone_shapes() -> Array:
	var out: Array = []
	for shape in DRAFT_SHAPES:
		if bool(SkyGearData.SHAPES[str(shape)].get("passive", false)):
			out.append(str(shape))
	return out


## Is the draft about to open the one whose card lands in the keyless well? The
## hand is full at four and the capacity is five, so the next weapon can only go
## to index 4 — `_slot_skill` fills actives forward from 0 and passives backward
## from the end, and both arrive at the same place once 0..3 are taken.
func keyless_draft() -> bool:
	return skill_capacity() > 4 and skills.size() >= 4


## The eight shapes, ordered by how much this class wants them. Deterministic
## given the seed: the bias multiplies a per-shape roll, so a starved shape can
## still come up and a favoured one is not guaranteed — the same run on the same
## seed still deals the same cards.
func _weighted_shapes() -> Array[String]:
	var bias: Dictionary = class_data().get("shape_bias", {})
	var scored: Array = []
	for shape in DRAFT_SHAPES:
		scored.append({"shape": shape,
			"score": rng.randf() * float(bias.get(shape, 1.0))})
	scored.sort_custom(func(a, b): return float(a.score) > float(b.score))
	var out: Array[String] = []
	for row in scored:
		out.append(str(row.shape))
	return out


## What the next wave is made of, as a line. MANIFEST buys the right to read it
## during the draft instead of finding out when it walks at you — information
## that widens the decision you are already making, which is the whole argument
## for the Log branch.
## WATCH BILL. How many boarders are still queued for a lane — the lane readout
## shows what is ON the deck, which tells you where the fight is and nothing
## about where it is going. Read straight off the spawn queue, so it is exactly
## true rather than an estimate.
func queued_in_lane(lane: int) -> int:
	var n := 0
	for entry in spawn_queue:
		if int(entry.lane) == lane and float(entry.time) > wave_time:
			n += 1
	return n


func next_wave_manifest() -> String:
	var next := wave + 1
	if next < 1 or next > SkyGearData.WAVES.size():
		return ""
	var counts := {}
	for batch in SkyGearData.WAVES[next - 1].batches:
		var kind := str(batch[1])
		var lanes: int = 3 if (batch.size() > 3 and batch[3] is String) else 1
		counts[kind] = int(counts.get(kind, 0)) + int(batch[2]) * lanes
	var parts: Array[String] = []
	for kind in counts.keys():
		parts.append("%d %s" % [int(counts[kind]), str(kind).to_lower()])
	var line := "wave %d — %s" % [next, ", ".join(parts)]
	var event_id := event_for(next)
	if event_id != "":
		line += "  ·  %s" % str(SkyGearData.EVENTS[event_id].name)
	return line


func open_draft() -> void:
	if voice != null:
		voice.say("draft")
	draft_options.clear()
	## THE CORE, ONCE, WHEN WAVE 4 CLEARS (board SG-275). First in the chain
	## because it is not one of the others: it does not deal a card, and it does
	## not spend the draft — `choose_draft` calls this function again the moment it
	## is answered, `core_offered` is already set by then, and the weapon or
	## upgrade the player was owed arrives behind it rather than instead of it.
	##
	## `not opening_draft` because the opening draft runs at `wave == 0`; the guard
	## is belt and braces against a future schedule that opens one on wave 4.
	if wave == CORE_WAVE and not opening_draft and not core_offered:
		core_offered = true
		draft_options = _core_offer()
	elif skills.size() < skill_capacity() and article("opening_bid"):
		## THE OPENING BID. The matrix is not dealt, it is opened: every shape
		## you do not hold, in all four elements, and you name the cell. The
		## weighted dealer, the element-match rule and Fourth Card all step
		## aside — there is nothing to widen when everything is already offered.
		## What the vow costs is downstream: `rerolls` is zero all run.
		draft_options = _bid_matrix()
	elif skills.size() < skill_capacity():
		## THE ORDER IS WEIGHTED BY CLASS. Same eight shapes, same 36 cells — the
		## draft simply reaches for his first. He wants ground he can hold and
		## hazards he can plant; a Beam on a man who cannot chase is a weapon he
		## will never be in position to use, and offering it is a wasted card
		## rather than a hard choice.
		##
		## A bias of 0.25 does not forbid a shape, it makes it rare. Forbidding
		## would mean two different matrices to balance, which is the thing the
		## class design explicitly refused to do.
		var shape_order: Array[String] = _weighted_shapes()
		## THE SECOND HAND. The fifth draft — the one that would have been the
		## run's first upgrade cards — deals only the shapes that fight on their
		## own (Field, Pulse), because no fifth key exists and an active in the
		## keyless slot would be a dead button. The card it displaced IS the
		## price; the harness holds a check on exactly that draft. Both halves of
		## the question are functions now (board SG-279), because `_bid_matrix` has
		## to ask the same one and used not to.
		if keyless_draft():
			var alone: Array[String] = []
			for shape in alone_shapes():
				alone.append(str(shape))
			shape_order = alone
		var element_order: Array[String] = ["EMBER", "FROST", "ARC", "STEAM"]
		var used_shapes: Array[String] = []
		for skill in skills:
			used_shapes.append(skill.shape)
		var cursor := rng.randi_range(0, shape_order.size() - 1)
		## FOURTH CARD. One more weapon on the opening hand only — the draft that
		## decides the shape of the whole run is the one worth widening, and doing
		## it every draft would be a multiplier on the card system rather than a
		## bigger version of it.
		## HEAT 3 · COLD DECK caps the hand at two. Capped against what the draft
		## wanted, so Fourth Card still WIDENS a normal draft — the ladder can only
		## take a card away, never conjure one — and the cap reads the same field
		## the upgrade draw does, one wave later.
		var offers: int = SkyGearWorkshop.draft_offers_for(int(heat),
			3 + (1 if talent("fourth_card") > 0.0 and wave <= 1 else 0))
		for i in offers:
			var shape: String = shape_order[(cursor + i) % shape_order.size()]
			var guard := 0
			while shape in used_shapes and guard < shape_order.size():
				cursor += 1
				shape = shape_order[(cursor + i) % shape_order.size()]
				guard += 1
			# One option deliberately matches the element you already run, so
			# committing to a colour across several shapes is a build rather
			# than a consolation prize.
			var element: String = element_order[rng.randi_range(0, element_order.size() - 1)]
			if i == 0 and not skills.is_empty():
				element = str(skills[rng.randi_range(0, skills.size() - 1)].element)
			var instance := SkyGearData.make_skill(shape, element)
			draft_options.append({
				"kind": "skill",
				"scope": SkyGearCards.SCOPE_NEW,
				"class_label": SkyGearCards.SCOPE_LABEL[SkyGearCards.SCOPE_NEW],
				"slot": skills.size(),
				"title": SkyGearData.skill_name(instance).to_upper(),
				"text": "%s · %s" % [SkyGearData.SHAPES[shape].kind, SkyGearData.ELEMENTS[element].blurb],
				## A weapon is common; the card face reads the field either way, and a
				## field that is present on two drafts out of three is a field somebody
				## eventually indexes into and crashes on.
				"rarity": SkyGearCards.RARITY_DEFAULT,
				"skill": instance,
			})
	else:
		draft_options = roll_upgrade_cards(SkyGearWorkshop.draft_offers_for(int(heat), 3))
	for option in draft_options:
		if not option.has("scope"):
			option["scope"] = SkyGearCards.SCOPE_NEW
			option["class_label"] = SkyGearCards.SCOPE_LABEL[SkyGearCards.SCOPE_NEW]
		option["affects"] = SkyGearCards.affects(self, option)
	draft_cursor = 0
	_set_state(State.DRAFT)
	play_sfx("ui/card_deal.ogg", -5.0)

func spawn_enemy(kind: String, lane: int) -> void:
	var enemy: SkyGearEnemy = ENEMY_SCENE.instantiate()
	add_child(enemy)
	enemy.spawn_serial = _next_enemy_spawn_serial
	_next_enemy_spawn_serial += 1
	enemy.global_position = Vector2(LANE_CENTERS[lane] + rng.randf_range(-58.0, 58.0), -1115.0)
	enemy.configure(self, kind, lane, wave)
	play_sfx("enemy/climb.ogg", -12.0)
	## THE ONE MOMENT A CUTSCENE CANNOT READ OFF THE STATE. The other three cues
	## are transitions the renderer already watches every frame; this is the frame
	## the Colossus is instantiated, and only the spawn knows about it. The call
	## does nothing at all unless a file in `assets/cutscenes/` claims the cue —
	## see `SkyGearCutscene.CUES`.
	if kind == "BOSS" and view != null:
		view.cue("boss_arrival")
	if voice != null:
		if kind == "BOSS":
			voice.say("boss_arrive", 3)
		elif not _said_first_board:
			_said_first_board = true
			voice.say("first_board", 2)

func enemy_count() -> int:
	var count := 0
	for enemy in enemies():
		if is_instance_valid(enemy) and not enemy.dead:
			count += 1
	return count


## --- THE CAPTAIN'S TWO BEATS (design §17.7, board SG-208) ---------------------
##
## The fixed arc repeated one identical fan forever, so there was never a
## question inside it. It has one now: the ODD cut opens twelve degrees to port,
## the EVEN cut is the RETURN twelve degrees to starboard, and the return pays
## more to a body whose centre is inside 110. Standing on the ground through
## both halves is the shipped 44; fanning at the edge of the reach is 40.
##
## THREE READS, AND THE SEAM BELOW USES ALL THREE. Nothing here stores a second
## copy of the beat, and nothing outside this file may: `cleave_next_beat()` is
## `basic_swing_serial` arithmetic, so the renderer's tell and the damage that
## lands cannot drift apart, because there is only one number.


## The row's own two-beat authoring, or `{}` for a basic that has none.
##
## ASKED, NOT NAME-MATCHED. The Boilerwright's `"kind": "cone"` Scald and the
## drafted `CLOSEHIT` Cleave card are untouched by this packet because they
## carry no `combo_damage` — not because a class id or a shape name was tested
## against them somewhere. A row that wants the beat authors it.
func cleave_combo() -> Dictionary:
	var auto: Dictionary = class_data().get("auto", {})
	return auto if auto.has("combo_damage") else {}


## Which side the NEXT cut opens from. Read-only and DERIVED — the tell on the
## deck, the harness and anything else that wants to know all ask this one
## question of the one counter.
func cleave_next_beat() -> String:
	if cleave_combo().is_empty():
		return "port"
	return "starboard" if basic_swing_serial % 2 == 1 else "port"


## What a body standing `distance` from the captain is paid by a cut worth
## `base`, given the close band THIS swing latched (`close_range` is 0.0 on the
## opening cut, which has no band at all).
##
## One place, because the cone asks it of every body it caught and the hull asks
## it of its own centre. Two copies of the 110 would be two chances for the
## crowd and the hull to disagree about the same swing.
func cleave_close_damage(base: float, distance: float, close_range: float,
		close_scale: float) -> float:
	if close_range <= 0.0 or distance > close_range:
		return base
	return base * close_scale


func _process_basic_attack(delta: float) -> void:
	basic_cooldown = maxf(0.0, basic_cooldown - delta)
	if not active_channel.is_empty():
		return
	if basic_cooldown > 0.0:
		return
	var auto: Dictionary = class_data().get("auto", {})
	if auto.is_empty():
		return
	var reach := float(auto.range)
	## THE HULL IS A THING SHE CAN SWING AT (board SG-186, the owner: *"Boarding
	## hulk took a long time to kill."*).
	##
	## `_resolve_cast` has ended in `hulk_splash` since it was written, under the
	## comment *"every shape must be able to bite the hulk, or breaking one is the
	## job of whichever weapon happens to be shaped like a structure-killer"*. The
	## BASIC ATTACK is the one shape that never got that line, and it is between a
	## third and a half of a run's damage — 36% of the owner's own twelve-wave
	## run. So the single largest damage source in the game could not touch the
	## one target the game asks you to break on a clock.
	##
	## IT IS TWO DEFECTS AND THE SECOND IS THE BIGGER ONE. Even with the splash
	## line added, this function returns early when no BOARDER is inside reach —
	## so a captain standing on the hull with the lane momentarily clear cannot
	## swing at all. Measured with `tools/hulk_probe.gd` before this change: a
	## captain parked at the hull for the whole fight swung her auto **2 times in
	## 28 seconds**. The hull is now a target of last resort: a boarder still wins
	## the aim every time one is in reach, so nothing about fighting boarders
	## changes, and the swing only turns on the hull when there is nothing else to
	## hit.
	##
	## THE REACH IT USES IS `hulk_splash_reaches`, NOT `auto.range` measured to the
	## hull's edge. Those are different numbers (190 + 190 = 380 against a splash
	## band of 340) and picking the wrong one would have drawn a cleave through a
	## hull that took nothing.
	var target := nearest_enemy(player.global_position, reach)
	var aim_at: Vector2 = Vector2.ZERO
	if target != null:
		aim_at = target.global_position
	elif hulk_splash_reaches(player.global_position):
		aim_at = Vector2(hulk.position)
	else:
		return
	var direction := (aim_at - player.global_position).normalized()
	## The ELEMENT is the run's, not the table's (SG-99). Everything else about
	## the swing — reach, arc, damage, period, knock, sound — is still the class's
	## own, because the ask was to change what it is made of and not what it is.
	var element := auto_element_id()
	## THE BEAT, LATCHED (design §17.7, board SG-208).
	##
	## ONE decision for the whole swing — which side the fan opens from and what
	## its cut is worth — taken HERE, above the cone, because the alternative is
	## deciding it per target and a crowd would then be paid out of two different
	## beats at once. What the cone still asks per body is the 110, and only the
	## 110: distance is a fact about a body, the beat is a fact about the swing.
	##
	## AND THE SERIAL ADVANCES HERE, past the target gate above and before
	## anything resolves — so the cut that is about to land is the one the deck
	## has been telling the player about, and a swing that found nothing has
	## already returned without touching it.
	##
	## A row with no `combo_damage` falls through every line of this untouched:
	## `side` stays empty, `close_range` stays 0.0, `swing` stays the row's own
	## `damage`, the direction is not rotated and the serial does not move.
	var combo: Dictionary = cleave_combo()
	var side := ""
	var swing: float = float(auto.damage)
	var close_range := 0.0
	var close_scale := 1.0
	if not combo.is_empty():
		var is_return := basic_swing_serial % 2 == 1
		side = "starboard" if is_return else "port"
		var beats: Array = combo.combo_damage
		swing = float(beats[1]) if is_return else float(beats[0])
		## Port is a LEFT-HAND turn on this deck: +y runs down the screen, so a
		## negative rotation carries the fan to the captain's port side.
		direction = direction.rotated(
			float(combo.combo_angle) * (1.0 if is_return else -1.0))
		if is_return:
			close_range = float(combo.combo_close_range)
			close_scale = float(combo.combo_return_scale)
		basic_swing_serial += 1
	swing *= damage_multiplier * overpressure_multiplier()
	_damage_cone(player.global_position, direction, reach, float(auto.arc),
		swing, element, float(auto.knock), true, close_range, close_scale)
	## THE LINE `_resolve_cast` HAS ALWAYS HAD (board SG-186). Unconditional, like
	## its twin: a cleave that catches a boarder standing against the hull bites
	## the hull too, which is what "every shape must be able to bite it" means and
	## what every skill in the game already does.
	##
	## The hull is a body with a centre, so the return asks the same 110 of it
	## through the same function every other body is asked through, and hands the
	## splash ONE already-resolved number.
	var hull_swing := swing
	if not hulk.is_empty():
		hull_swing = cleave_close_damage(swing,
			Vector2(hulk.position).distance_to(player.global_position),
			close_range, close_scale)
	hulk_splash(player.global_position, hull_swing)
	basic_cooldown = float(auto.period)
	## `side` rides along so the picture can enter from the side that connected.
	## It carries no geometry: `direction`, `radius` and `arc` are the simulation's
	## own, unchanged, and the renderer's lead-in is read off this effect's own
	## clock rather than a second one — see `view3d.gd::cleave_lead`.
	_fx({"kind": str(auto.kind), "position": player.global_position,
		"direction": direction.angle(), "radius": reach, "arc": float(auto.arc),
		"element": element, "side": side,
		"color": SkyGearData.ELEMENTS[element].color,
		"time": 0.0, "life": 0.16, "follow": true})
	play_sfx(str(auto.sound), -7.0)

## SENTRY AUTOCAST — hold the slot's own key to arm it (board SG-98, from the
## build-44 playtest: *"Can we make sentry abilities be toggle-able to always
## drop on player at their location? Maybe by holding the hotkey and that
## triggers a visual indicator it's on autocast."*).
##
## Three rules that fall out of "hold the hotkey", each of which is a way this
## could have gone wrong:
##
##   * **Only a sentry slot watches for a hold.** Every other slot keeps the
##     press-to-cast it has always had, on `is_action_just_pressed`, with no
##     added latency and no behaviour to re-learn. Autocast means nothing for a
##     Lance; a hold-detector on all four would tax every skill in the game to
##     pay for one.
##   * **A sentry slot fires on RELEASE.** You cannot know a press was a tap
##     until it ends. The cost is the few milliseconds of a real tap; the
##     alternative — cast on press, then also toggle — deploys a sentry every
##     time you arm one, which is a toggle that fights you.
##   * **The key is whatever `keybinds.gd` says it is.** `skill_%d` is the
##     action; the hold works on a rebound key because it never sees a letter.
##
## The flag lives on the skill DICT (`skill.autocast`), beside `sentry_idle`,
## and that is the whole of why it survives: a wave change never touches
## `skills`, a pause only stops `_process`, and the draft replaces a whole dict
## — so a freshly drafted sentry starts disarmed, which is the right default,
## and a slot that shuffles under `_trim_empty_slots` carries its arming with it
## instead of handing it to whoever inherits the index.
const AUTOCAST_HOLD := 0.45
var _skill_held: Array[float] = []
var _skill_hold_spent: Array[bool] = []


func sentry_slot(index: int) -> bool:
	return index >= 0 and index < skills.size() \
		and str(SkyGearData.SHAPES[skills[index].shape].kind) == "sentry"


## The one question the HUD, the coach and the harness all ask.
func autocast_armed(index: int) -> bool:
	return sentry_slot(index) and bool(skills[index].get("autocast", false))


func set_autocast(index: int, on: bool) -> void:
	if not sentry_slot(index):
		return
	skills[index].autocast = on
	## Standing down clears the grace timer too, so disarming mid-count does not
	## leave a sentry half-way to placing itself.
	skills[index].sentry_idle = 0.0
	play_sfx("ui/click.ogg", -6.0 if on else -10.0)


func _process_skill_input(delta: float) -> void:
	var actions := ["skill_1", "skill_2", "skill_3", "skill_4"]
	_skill_held.resize(actions.size())
	_skill_hold_spent.resize(actions.size())
	for i in mini(skills.size(), actions.size()):
		if not sentry_slot(i):
			if Input.is_action_just_pressed(actions[i]):
				cast_skill(i)
			_skill_held[i] = 0.0
			_skill_hold_spent[i] = false
			continue
		if Input.is_action_pressed(actions[i]):
			if Input.is_action_just_pressed(actions[i]):
				_skill_held[i] = 0.0
				_skill_hold_spent[i] = false
			_skill_held[i] = float(_skill_held[i]) + delta
			if float(_skill_held[i]) >= AUTOCAST_HOLD and not bool(_skill_hold_spent[i]):
				_skill_hold_spent[i] = true
				set_autocast(i, not autocast_armed(i))
		elif Input.is_action_just_released(actions[i]):
			if not bool(_skill_hold_spent[i]):
				cast_skill(i)
			_skill_held[i] = 0.0
			_skill_hold_spent[i] = false

## Base shape table x per-skill mods x global mods, in one place. Everything
## that fires reads this rather than the SHAPES table, so a card that says
## "+30% range" is felt by the cast, the preview and the harness alike.
## The live numbers for a skill. Delegates, because the draft has to be able to
## ask the same question about a HYPOTHETICAL set of mods — "what would this be
## if I took that card" — and a function that can only read `self` cannot answer
## it. Same arithmetic, one copy.
func skill_stats(skill: Dictionary) -> Dictionary:
	return stats_with(skill, mods, damage_multiplier, range_multiplier)


static func stats_with(skill: Dictionary, mods: Dictionary,
		damage_multiplier: float, range_multiplier: float = 1.0) -> Dictionary:
	var shape: Dictionary = SkyGearData.SHAPES[skill.shape]
	var m: Dictionary = skill.get("mods", {})
	var element: String = skill.element
	var elem_damage: float = float(mods.elem_damage.get(element, 1.0))
	var elem_cooldown: float = float(mods.elem_cooldown.get(element, 1.0))
	var out := {
		"kind": str(shape.kind),
		"damage": float(shape.damage) * float(m.get("damage", 1.0)) * elem_damage * damage_multiplier,
		"cooldown": float(shape.cooldown) * float(m.get("cooldown", 1.0)) * elem_cooldown * 0.8,
		## No `mods.knock_multiplier` here — `damage_enemy` is the single funnel
		## and applies it to EVERY source (which is PRESSURE SPIKE's own text).
		## It was applied in both places, so the skill path squared it: +40%
		## printed on the card, +96% dealt on the deck (board SG-66, found
		## chasing SG-62's fling).
		"knock": float(shape.get("knock", 0.0)) * float(m.get("knock", 1.0)),
		"multi": int(m.get("multi", 1)),
		## LONG ARMS is folded in through `damage_multiplier`'s sibling rather than
		## through `m`, which belongs to the skill and is what a card writes.
		"range": float(shape.get("range", 0.0)) * float(m.get("range", 1.0))
			* range_multiplier,
		"radius": float(shape.get("radius", 0.0)) * float(m.get("area", 1.0)),
		"width": float(shape.get("width", 0.0)) * float(m.get("area", 1.0)),
		"arc": float(shape.get("arc", 0.0)),
		"pierce": int(m.get("pierce", 0)),
		"jumps": int(shape.get("jumps", 0)) + int(m.get("jumps", 0)),
		"jump_range": float(shape.get("jump_range", 0.0)) * float(m.get("range", 1.0)),
		"tick_rate": float(shape.get("tick_rate", 1.0)),
	}
	# a wider cone is a shape change, not a scalar
	if out.kind == "cone":
		out.arc = (1.658 if bool(m.get("wide_cone", false)) else out.arc) * (1.0 + (float(m.get("area", 1.0)) - 1.0) * 0.55)
	elif out.kind == "arc":
		out.arc = out.arc * (1.0 + (float(m.get("area", 1.0)) - 1.0) * 0.55)
	elif out.kind == "ray":
		out["channel_time"] = float(shape.channel_time)
		out["channel_ticks"] = int(shape.channel_ticks)
		out["channel_move_scale"] = float(shape.channel_move_scale)
		out.cooldown = maxf(float(out.cooldown), float(out.channel_time))
	return out


## AB-02 · FIELD CLAIMS GROUND. These are the only readers/writers of the
## per-skill anchor. While unset, the answer is deliberately live: a Field-only
## hand preserves the shipped follow behavior for the entire wave.
func field_center(skill: Dictionary) -> Vector2:
	if bool(skill.get("field_anchor_set", false)):
		return Vector2(skill.get("field_anchor", player.global_position))
	return player.global_position


func relocate_fields(land: Vector2) -> void:
	for skill in skills:
		var shape: Dictionary = SkyGearData.SHAPES[skill.shape]
		if str(shape.get("kind", "")) != "aura":
			continue
		skill.field_anchor = land
		skill.field_anchor_set = true


func reset_field_anchors() -> void:
	var diagnostic := player.global_position if player != null else Vector2.ZERO
	for skill in skills:
		var shape: Dictionary = SkyGearData.SHAPES[skill.shape]
		if str(shape.get("kind", "")) != "aura":
			continue
		skill.field_anchor = diagnostic
		skill.field_anchor_set = false


## AB-03 · PULSE REWARDS CASTING CADENCE. The period is derived through the
## same stats path the firing scheduler uses; the public clock hides a carried
## negative remainder as due-now without rewriting simulation state.
func pulse_period(skill: Dictionary) -> float:
	return float(skill_stats(skill).cooldown)


func pulse_time_left(skill: Dictionary) -> float:
	return maxf(0.0, float(skill.get("passive_timer", 0.0)))


func advance_pulses() -> void:
	for pulse in skills:
		var shape: Dictionary = SkyGearData.SHAPES[pulse.shape]
		if str(shape.get("kind", "")) != "pulse":
			continue
		var period := pulse_period(pulse)
		var floor := -period + 0.001
		pulse.passive_timer = maxf(float(pulse.get("passive_timer", 0.0))
			- float(shape.cast_advance), floor)


func cast_skill(index: int, aim_at = null) -> void:
	if index < 0 or index >= skills.size():
		return
	if not active_channel.is_empty():
		return
	var skill: Dictionary = skills[index]
	var shape: Dictionary = SkyGearData.SHAPES[skill.shape]
	if bool(shape.get("passive", false)) or float(skill.cooldown_left) > 0.0:
		return
	var origin := player.global_position
	var target: Vector2 = aim_at if aim_at is Vector2 else aim_target()
	# An explicit aim has to steer the DIRECTION too, not only the landing point:
	# a Cleave aimed at a target it is facing away from hits nothing, which is
	# how six casts recorded six presses and zero damage.
	var direction: Vector2 = ((target - origin).normalized() if aim_at is Vector2
		else player.aim_direction)
	var st := skill_stats(skill)
	## A deployable does not resolve into damage here — it puts an object down
	## and that object does the work.
	if str(st.kind) == "sentry":
		SkyGearTelemetry.note_cast(tel, index, skill)
		skill.casts = int(skill.get("casts", 0)) + 1
		deploy_sentry(skill, target, true)
		player.attack_time = 0.30
		return
	var previous_src := src_slot
	src_slot = index
	skill.casts = int(skill.get("casts", 0)) + 1
	SkyGearTelemetry.note_cast(tel, index, skill)
	# FIFTH GEAR: every fifth cast of a skill is free and doubled.
	var free_cast := false
	var damage := float(st.damage)
	if bool(mods.fifth_gear) and int(skill.casts) % 5 == 0:
		damage *= 2.0
		free_cast = true
	## OVERPRESSURE. Every weapon hits harder while there is anything in the bank,
	## and the cast spends some. Applied here rather than inside `skill_stats`
	## because it is a property of the MOMENT, not of the weapon — the card
	## preview would otherwise show a number that changes while you read it.
	damage *= overpressure_multiplier()
	spend_overpressure()
	var shots: int = maxi(1, int(st.multi))
	if shots > 1:
		damage *= 0.7
	if str(st.kind) == "ray":
		var channel_time := float(st.channel_time)
		var channel_ticks := int(st.channel_ticks)
		active_channel = {
			"slot": index, "elapsed": 0.0, "next_tick": 0,
			"tick_interval": channel_time / float(maxi(1, channel_ticks - 1)),
			"forced_target": aim_at if aim_at is Vector2 else null,
			"snapshot": {
				"damage": damage, "range": float(st.range), "width": float(st.width),
				"knock": float(st.knock), "element": str(skill.element),
				"shots": shots, "ticks": channel_ticks,
				"channel_time": channel_time,
				"channel_move_scale": float(st.channel_move_scale),
				"residue": float(mods.residue),
				"evolution": (skill.get("evolution", {}) as Dictionary).duplicate(true),
				"free": free_cast,
			},
			"last_land": origin,
			"element_applied_serials": {},
		}
		skill.cooldown_left = 0.0 if free_cast else float(st.cooldown)
		## Beam pays and advances at channel start. Completion and cancellation
		## never reach another advance call.
		advance_pulses()
		player.attack_time = maxf(channel_time,
			clampf(float(st.cooldown) * 0.85, 0.24, 0.62))
		play_sfx(_shape_sound(skill.shape), -5.0)
		_resolve_beam_tick()
		src_slot = previous_src
		return
	var land := origin
	for _shot in shots:
		land = _resolve_cast(st, skill, origin, direction, target, damage)
	# Every shape must be able to bite the hulk, or breaking one is the job of
	# whichever weapon happens to be shaped like a structure-killer.
	hulk_splash(land, damage * float(shots))
	# RESIDUE: a burning field wherever the shape landed.
	if float(mods.residue) > 0.0:
		## `radius` used to be `62.0 + 22.0 * mods.residue` here and nothing burned
		## by it — the tick has always used one flat radius (SG-163). The rate is
		## named by `source`/`stacks` now (SG-164) — the table decides it, not
		## this call site.
		_field({"position": land, "source": "residue",
			"stacks": float(mods.residue), "time": 2.0, "tick": 0.0})
	## All shots, hulk splash and Residue are resolved before the one public
	## landing. A multi-shot cast therefore claims ground once, at its final land.
	relocate_fields(land)
	skill.cooldown_left = 0.0 if free_cast else float(st.cooldown)
	## Regular and multi-shot casts publish their final Field landing and pay
	## cooldown before advancing Pulse once.
	advance_pulses()
	## How long the swing is allowed to last, from the SKILL. It was a flat 0.26
	## for everything, so a Beam at a 0.48 cooldown and a Mortar at 2.08 got the
	## same animation window and neither matched. Floored so a fast skill still
	## shows a swing, capped so a slow one does not leave her posing.
	player.attack_time = clampf(float(st.cooldown) * 0.85, 0.24, 0.62)
	play_sfx(_shape_sound(skill.shape), -5.0)
	src_slot = previous_src


func combat_move_scale() -> float:
	return 1.0 if active_channel.is_empty() \
		else float(active_channel.snapshot.channel_move_scale)


## One endpoint query for damage and presentation. Explicit targets are fixed;
## an ordinary cast re-reads the captain's current aim on every tick/frame.
func active_channel_line() -> Dictionary:
	if active_channel.is_empty():
		return {}
	var snap: Dictionary = active_channel.snapshot
	var origin := player.global_position
	var forced: Variant = active_channel.get("forced_target")
	var target: Vector2 = forced if forced is Vector2 else aim_target()
	var direction: Vector2 = (target - origin).normalized() if forced is Vector2 \
		else player.aim_direction
	if direction.length_squared() <= 0.000001:
		direction = Vector2.UP
	return {"from": origin, "to": origin + direction * float(snap.range),
		"element": str(snap.element)}


func _resolve_beam_tick() -> void:
	if active_channel.is_empty():
		return
	var snap: Dictionary = active_channel.snapshot
	var line := active_channel_line()
	if line.is_empty():
		return
	var previous_src := src_slot
	src_slot = int(active_channel.slot)
	for _shot in int(snap.shots):
		_damage_line(line.from, line.to, float(snap.width), float(snap.damage),
			str(snap.element), float(snap.knock), true,
			active_channel.element_applied_serials)
	active_channel.last_land = Vector2(line.from).lerp(Vector2(line.to), 0.5)
	active_channel.next_tick = int(active_channel.next_tick) + 1
	src_slot = previous_src


func _update_active_channel(delta: float) -> void:
	if active_channel.is_empty():
		return
	active_channel.elapsed = float(active_channel.elapsed) + delta
	var snap: Dictionary = active_channel.snapshot
	var safety := 0
	while int(active_channel.next_tick) < int(snap.ticks) \
			and float(active_channel.elapsed) + 0.000001 \
				>= float(active_channel.next_tick) * float(active_channel.tick_interval) \
			and safety < 8:
		_resolve_beam_tick()
		safety += 1
	if not active_channel.is_empty() and int(active_channel.next_tick) >= int(snap.ticks):
		_finish_active_channel()


func _finish_active_channel() -> void:
	if active_channel.is_empty():
		return
	var row := active_channel
	active_channel = {}
	var snap: Dictionary = row.snapshot
	hulk_splash(Vector2(row.last_land), float(snap.damage) * float(snap.shots))
	if float(snap.residue) > 0.0:
		## THE CHANNELLED RESIDUE PATH — the one nobody counted. Same table,
		## same source name, so an instant cast and a channelled one leave the
		## same fire (board SG-164).
		_field({"position": Vector2(row.last_land), "source": "residue",
			"stacks": float(snap.residue), "time": 2.0, "tick": 0.0})
	## Completion publishes the inherited Ray midpoint. Cancellation clears the
	## channel without reaching this function, so it publishes nothing.
	relocate_fields(Vector2(row.last_land))


func _cancel_active_channel() -> void:
	active_channel = {}


func _resolve_cast(st: Dictionary, skill: Dictionary, origin: Vector2, direction: Vector2, target_in: Vector2, damage: float) -> Vector2:
	var target := target_in
	var shape: Dictionary = SkyGearData.SHAPES[skill.shape]
	var land := origin
	match str(st.kind):
		"arc":
			_damage_cone(origin, direction, float(st.range), float(st.arc), damage, skill.element, float(st.knock), true)
			_fx({"kind": "arc", "position": origin, "direction": direction.angle(), "radius": float(st.range), "arc": float(st.arc), "element": skill.element, "color": SkyGearData.ELEMENTS[skill.element].color, "time": 0.0, "life": 0.2, "follow": true})
			land = origin + direction * float(st.range) * 0.62
		"line":
			var end := origin + direction * float(st.range)
			_damage_line(origin, end, float(st.width), damage, skill.element, float(st.knock), true)
			_fx({"kind": "line", "from": origin, "to": end, "element": skill.element, "color": SkyGearData.ELEMENTS[skill.element].color, "time": 0.0, "life": 0.18})
			land = origin + direction * float(st.range) * 0.5
		"cone":
			_damage_cone(origin, direction, float(st.range), float(st.arc), damage, skill.element, float(st.knock), true)
			_fx({"kind": "cone", "position": origin, "direction": direction.angle(), "radius": float(st.range), "arc": float(st.arc), "element": skill.element, "color": SkyGearData.ELEMENTS[skill.element].color, "time": 0.0, "life": 0.22, "follow": true})
			land = origin + direction * float(st.range) * 0.55
		"aoe":
			var offset := target - origin
			if offset.length() > float(st.range):
				target = origin + offset.normalized() * float(st.range)
			_damage_circle(target, float(st.radius), damage, skill.element, float(st.knock), true, true)
			## `from` is the THROW. The renderer arcs a shell out of her hand to
			## where the ring landed, and a Mortar is the only shape in the game
			## that has a throw — everything else either starts on her or is
			## already there, which is why nothing else writes this field.
			_fx({"kind": "circle", "position": target, "from": origin, "radius": float(st.radius), "element": skill.element, "color": SkyGearData.ELEMENTS[skill.element].color, "time": 0.0, "life": 0.28})
			land = target
		"chain":
			land = _cast_chain(origin, target, st, skill.element, damage)
		"ray":
			var end := origin + direction * float(st.range)
			_damage_line(origin, end, float(st.width), damage * 4.0, skill.element, float(st.knock), true)
			_fx({"kind": "beam", "from": origin, "to": end, "element": skill.element, "color": SkyGearData.ELEMENTS[skill.element].color, "time": 0.0, "life": 0.32})
			land = origin + direction * float(st.range) * 0.5
	return land

func _cast_chain(origin: Vector2, target_position: Vector2, st: Dictionary, element: String, damage: float) -> Vector2:
	var current: SkyGearEnemy = nearest_enemy(target_position, float(st.range))
	if current == null:
		current = nearest_enemy(origin, float(st.range))
	if current == null:
		return origin
	var visited := {}
	var from := origin
	var jump_count := int(st.jumps) + (1 if element == "ARC" else 0)
	for jump in jump_count:
		if current == null:
			break
		visited[current.get_instance_id()] = true
		damage_enemy(current, damage * pow(0.85, jump), element, float(st.knock), from, true)
		## `lift` is what makes a chain a chain. A Whip jump between two boarders
		## is an arc THROUGH THE AIR, and drawing it as a straight segment on the
		## deck — which is what it was — is the single clearest example of the
		## thing that was reported: the effect existed, and it was painted on the
		## floor. 150 units is head height on a SCRAPPER plus a little.
		_fx({"kind": "line", "from": from, "to": current.global_position, "lift": 150.0, "element": element, "color": SkyGearData.ELEMENTS[element].color, "time": 0.0, "life": 0.22})
		from = current.global_position
		current = nearest_enemy_excluding(from, float(st.jump_range), visited)
	return from

func _update_cooldowns(delta: float) -> void:
	vent_cooldown = maxf(0.0, vent_cooldown - delta)
	for skill in skills:
		skill.cooldown_left = maxf(0.0, float(skill.cooldown_left) - delta)
		## A ready sentry you have not placed places itself, after a grace period
		## long enough that it never steals a press you were about to make.
		if str(SkyGearData.SHAPES[skill.shape].kind) != "sentry":
			continue
		if float(skill.cooldown_left) > 0.0 or state != State.PLAY:
			skill.sentry_idle = 0.0
			continue
		var idle := float(skill.get("sentry_idle", 0.0)) + delta
		skill.sentry_idle = idle
		var st := skill_stats(skill)
		## ARMED means the grace is zero. The idle auto-place already put a ready
		## sentry at the captain's feet after `auto_after` seconds — the whole of
		## autocast is that a toggled slot stops waiting to be sure you were not
		## about to press it, because you have said you never will.
		var grace: float = 0.0 if bool(skill.get("autocast", false)) \
			else float(st.get("auto_after", 2.5))
		if idle >= grace:
			deploy_sentry(skill, player.global_position, false)

const PASSIVE_CATCHUP_MAX := 8

func _update_passives(delta: float) -> void:
	for skill in skills:
		var shape: Dictionary = SkyGearData.SHAPES[skill.shape]
		if not bool(shape.get("passive", false)):
			continue
		var timer := float(skill.get("passive_timer", 0.0)) - delta
		if timer > 0.0:
			skill.passive_timer = timer
			continue
		# A passive has no press, so its damage is all it can be judged on —
		# attribute it to its slot the same way a cast is.
		var previous_src := src_slot
		src_slot = skills.find(skill)
		## A passive never goes through `cast_skill`, so its telemetry row never
		## had a shape written to it — and `run_report` skips rows with no shape.
		## The damage was counted in the total and then not printed, so a build
		## with a Sentry and a Field showed shares summing to 87% and the missing
		## thirteen was the player's own passives. A balance pass run against that
		## report would have been a balance pass against bad data.
		SkyGearTelemetry.note_passive(tel, src_slot, skill)
		var st := skill_stats(skill)
		## THE PERIOD IS CARRIED, NOT RESET (board SG-126) — the same discarded
		## remainder SG-122 fixed for a fire pool. `passive_timer = period` threw
		## away the overshoot, so a drafted card's authored rate was really
		## `ceil(period / delta) * delta` and a Field's `tick_rate` of 1.8 — a
		## value that divides neither 1/60 nor 0.05 — was not the rate it ticked
		## at. `timer` is already <= 0 here and is the overshoot; adding the
		## period to it carries the remainder into the next interval.
		var period := 0.0
		match str(st.kind):
			"aura": period = 1.0 / maxf(0.2, float(st.tick_rate))
			"pulse": period = float(st.cooldown)
		if period <= 0.0:
			## A passive shape with no period would spin this loop forever. Skip
			## it rather than tick it: a shape that wants a rate has to name one.
			skill.passive_timer = 0.0
			src_slot = previous_src
			continue
		## `while`, per SG-122: a step longer than the period delivers every tick
		## it spans instead of one. `CATCHUP_MAX` is a safety bound, not a rate
		## decision — at the frame rates this game runs (1/60) and this rig steps
		## (0.05) against periods of 0.5 s and up it never binds; it exists so a
		## debugger pause cannot turn a resumed frame into a burst.
		var fired := 0
		while timer <= 0.0 and fired < PASSIVE_CATCHUP_MAX:
			match str(st.kind):
				"aura":
					_damage_circle(field_center(skill), float(st.radius), float(st.damage), skill.element, 0.0, true, false)
				"pulse":
					_damage_circle(player.global_position, float(st.radius), float(st.damage), skill.element, float(st.knock), true, false)
					_fx({"kind": "circle", "follow": true, "position": player.global_position, "radius": float(st.radius), "element": skill.element, "color": SkyGearData.ELEMENTS[skill.element].color, "time": 0.0, "life": 0.3})
			timer += period
			fired += 1
		skill.passive_timer = maxf(timer, 0.0) if fired >= PASSIVE_CATCHUP_MAX else timer
		src_slot = previous_src

## The single funnel for damage dealt to a boarder. Crit, brittle, lifesteal,
## pressure and telemetry all happen here, once, because every other version of
## this project put them in four places and one of them was always wrong.
##
## CRIT IS A BROAD MECHANIC IN THIS GAME AND EVERY DAMAGE SOURCE GETS IT
## (SG-159, the owner, overruling SG-148: *"Why are we getting rid of CRIT?
## That's an important mechanic. Please don't get rid of CRIT. We've moved so
## far beyond the browser version of this game... We've transcended that."*).
## The kill explosion, the vent, a fire pool's tick, the kegs, the lane cannon
## and the crew ALL crit, `can_crit` defaults TRUE, and a new damage source
## crits unless somebody writes down a reason here that it must not.
##
## AND "THE BROWSER DID IT THIS WAY" IS NOT SUCH A REASON — not in this file and
## not in this game. SG-148 took crit off those six on browser-fidelity grounds
## and was reverted whole; the rule and the argument are both gone. If a source
## should ever stop critting, the case has to be made about how the GODOT game
## plays and it has to be measured. There is exactly one such case today, and it
## is not about taste at all:
##
## `can_crit` EXISTS FOR TERMINATION. AN EXPLOSION MAY NOT EXPLODE: the crit
## explosion below re-enters
## this function through `_damage_circle`, and while every re-entry can roll its
## own crit there is no quantity that decreases, so the recursion terminates
## only when the rolls happen to stop. That is not a termination argument, it is
## a probability, and twice in ~1,400 wave-12 runs the probability lost.
## Passing `false` on that one edge makes AN EXPLOSION'S OWN DEPTH EXACTLY 1 by
## construction — `crit` cannot be true when `can_crit` is false, so the branch
## that recurses cannot be reached from inside itself, for any seed, at any
## frame rate.
##
## AND THE PRECISE CLAIM, because "it cannot recurse" would be too strong. One
## re-entry survives: an explosion can KILL, `_kill_enemy` opens a `kill_explode`
## circle, and that circle crits normally. So the cycle can still be walked —
## but only ever across a kill, and a dead boarder cannot die twice. Every
## traversal now costs one living boarder permanently, so the depth is bounded
## by the number of figures on the deck instead of by nothing at all. That is
## the difference between a terminating program and a lucky one, and it is the
## property to preserve if anyone edits this path.
##
## SO THE ONLY ORDINARY-DAMAGE `false` IS THE ONE RECURSIVE EDGE. Six other
## call sites carried one between SG-148 and SG-159 and none of them do now;
## the twelve `crit ·` checks in `tests/parity_test.gd` name those sources.
## EL-00 adds the explicit status entrance below as a separate declared
## exception: delayed status may never crit or consume the gameplay stream.


func damage_enemy(enemy: SkyGearEnemy, amount: float, element: String, knock: float,
		origin: Vector2, grants_pressure: bool, can_crit: bool = true,
		element_once: Variant = null, applies_slow_bonus: bool = true,
		extends_taps: bool = true) -> float:
	if not is_instance_valid(enemy) or enemy.dead:
		return 0.0
	var scaled := amount
	if applies_slow_bonus and enemy.slow_time > 0.0:
		scaled *= 1.0 + float(mods.slow_damage)
	## Short-circuited on `can_crit`, so the one hit that may not crit consumes
	## nothing from the seeded stream and every other roll in the run lands where
	## it would have landed anyway.
	var crit := can_crit and rng.randf() < float(mods.crit_chance)
	if crit:
		scaled *= 2.0
	var hit_at := enemy.global_position
	var dealt := enemy.take_damage(scaled, origin, element,
		knock * float(mods.knock_multiplier), element_once, src_slot)
	var killed := enemy.dead or enemy.hp <= 0.0
	## Status declines the same optional edge as Tap extension: a delayed tick
	## owns no hit-stop/floater clock and consumes no visual RNG (that stream
	## also places gameplay kegs, so cosmetic consumption is not physically free).
	if extends_taps and impact != null and dealt >= 1.0:
		impact.note_hit(dealt, killed)
		## And the picture of it. The renderer owns the particles; the simulation
		## only says a hit of this size, of this element, landed here.
		if view != null:
			view.impact_at(hit_at, element, dealt)
			## ...and the BODY reacts, which it never has (board SG-217). Not
			## on the kill — a corpse has a death clip and a flinch inside it
			## reads as a stumble the animation then contradicts.
			if not killed:
				view.react_enemy_hit(enemy, dealt)
	if extends_taps and dealt >= 1.0:
		# a lane cannon fires no element, so this cannot assume the table has one
		var tint: Color = Color("#eee5d5")
		if SkyGearData.ELEMENTS.has(element):
			tint = SkyGearData.ELEMENTS[element].color
		add_floater("%d" % roundi(dealt), hit_at, Color("#ffe08a") if crit else tint, crit)
		## A CONNECTING HIT MAKES A SOUND (board SG-216). This funnel is the
		## project's declared single entrance for damage dealt to a boarder, and
		## for the life of the port it contained no `play_sfx` at all: kills,
		## hulk hits, prop breaks and player-hurt all sounded, and the ordinary
		## landed blow — the thing the player does most — did not. Meanwhile
		## `hit_2`..`hit_5`, `crit_1..3` and the four `elem_*` takes had shipped
		## since 2026-08-01 with exactly one reader between them, and that one
		## was a fallback for an unknown CAST shape.
		##
		## A kill already has its own voice, so this stays out of its way and
		## sounds only the non-lethal blow — the one that had nothing.
		if not killed:
			_sound_hit(element, crit)
	SkyGearTelemetry.note_damage(tel, src_slot, dealt, killed)
	## A KILL INSIDE A MAIN EXTENDS IT. `extend_on_kill` was data nothing read.
	## This is the loop the class is built around: hold the ground and the ground
	## holds longer, so a main placed where the fight actually is pays for itself
	## and one placed out of the way simply expires. Capped at `max_life`, or a
	## good position becomes a permanent one.
	if extends_taps and killed and not taps.is_empty():
		for tap in taps:
			if hit_at.distance_to(Vector2(tap.position)) <= float(tap.radius):
				tap.life = minf(float(SkyGearData.TAP.max_life),
					float(tap.life) + float(SkyGearData.TAP.extend_on_kill))
				break
	if crit and float(mods.crit_explode) > 0.0:
		## THE ONE RECURSIVE EDGE IN THE DAMAGE PATH, and the `false` on the end
		## is the whole of SG-147 — a TERMINATION argument, not a balance one, and
		## the reason SG-159 left it standing while it put crit back everywhere
		## else. Do not remove it and do not let a caller pass `true` here: the
		## harness pins it as `crit · an explosion may not explode`.
		_damage_circle(enemy.global_position, 70.0, 20.0, element, 60.0,
			false, false, false, element_once)
	if grants_pressure:
		register_damage(dealt, enemy.global_position)
	return dealt


## The one non-recursive status/reaction entrance. It borrows the ordinary
## funnel's hit, kill and attribution bookkeeping, while explicitly declining
## the mechanics a delayed tick must never acquire.
func damage_status(enemy: SkyGearEnemy, amount: float, source_slot: int,
		reaction_id: String) -> float:
	var previous_src := src_slot
	src_slot = source_slot
	var dealt := damage_enemy(enemy, amount, "", 0.0, Vector2.ZERO,
		source_slot >= -1, false, null, false, false)
	src_slot = previous_src
	if dealt > 0.0:
		SkyGearTelemetry.note_reaction(tel, reaction_id, dealt)
	return dealt

func register_damage(amount: float, hit_position: Vector2) -> void:
	if amount <= 0.0:
		return
	# Close range is the condition on BOTH payouts: pressure and lifesteal. In
	# the browser build this was the fix for a run that healed faster than three
	# lanes of boarders could hurt it, from maximum range.
	if player.global_position.distance_to(hit_position) <= float(SkyGearData.CLOSE.range):
		## HERS ONLY. A banked gauge fills from the GROUND, never from the fight —
		## that one sentence is the whole class. I added `_fill_head` and never
		## gated the two paths it was meant to REPLACE, so the Boilerwright was
		## getting both: an audit measured a single 40-damage close hit filling
		## Head by 68, which is faster than eight seconds standing inside his own
		## Tap Main. As shipped he was the captain with a free 45% multiplier —
		## the exact collapse `CLASS-2-DESIGN.md` §0 exists to refuse.
		if not gauge_is_banked():
			pressure = minf(100.0, pressure + amount * float(SkyGearData.CLOSE.pressure_per_damage) * float(mods.pressure_rate))
		pressure_grace = float(SkyGearData.CLOSE.pressure_grace)
		player.set_pressure(pressure)
		if float(mods.lifesteal) > 0.0:
			heal_player(amount * float(mods.lifesteal), "steal")


## One ceiling on all healing, as a refilling budget. Vent, salvage, field
## dressing and cards all draw from it; lifesteal has a tighter one inside it.
## A cap on the SUM is the only version of this that does not need re-tuning
## every time a healing card is added.
func heal_player(amount: float, source: String) -> float:
	if amount <= 0.0 or player.hp <= 0.0:
		return 0.0
	var allowed := amount
	if source == "steal":
		allowed = minf(allowed, steal_budget)
		steal_budget -= allowed
	if source != "wave":
		allowed = minf(allowed, heal_budget)
		heal_budget -= allowed
	if allowed <= 0.0:
		return 0.0
	var healed := player.heal(allowed)
	tel.healed += healed
	# Healing has to be as legible as damage or the close-quarters loop is
	# invisible: the whole point of pressure, vent and salvage is that you can
	# see them paying you back for standing in range.
	if healed >= 1.0:
		add_floater("+%d" % roundi(healed), player.global_position, Color("#37f0c8"))
	return healed

## `can_crit` is forwarded and never re-raised, so a circle opened by a no-crit
## caller stays no-crit for every enemy it touches. That is what turns the
## depth-1 rule above into a property of the call graph rather than a habit.
func _damage_circle(center: Vector2, radius: float, damage: float, element: String,
		knock: float, grants_pressure: bool, hits_props: bool,
		can_crit: bool = true, element_once: Variant = null) -> void:
	for enemy in enemies():
		if is_instance_valid(enemy) and not enemy.dead and enemy.global_position.distance_to(center) <= radius + enemy.radius:
			damage_enemy(enemy, damage, element, knock, center, grants_pressure,
				can_crit, element_once)
	if hits_props:
		_damage_props_circle(center, radius, damage)

## `close_range`/`close_scale` are the Captain's return cut and nothing else
## (SG-208): at the default 0.0 band this function is byte-for-byte the cone
## every other shape has always fired. The band is asked PER BODY, of the body's
## own centre, which is the whole point — one swing, one beat, and the ground
## each body chose to stand on decides what it is paid. Props are not bodies and
## keep the latched cut.
func _damage_cone(origin: Vector2, direction: Vector2, radius: float, arc: float, damage: float, element: String, knock: float, hits_props: bool, close_range: float = 0.0, close_scale: float = 1.0) -> void:
	for enemy in enemies():
		if not is_instance_valid(enemy) or enemy.dead:
			continue
		var target_delta: Vector2 = enemy.global_position - origin
		if target_delta.length() <= radius + enemy.radius and absf(direction.angle_to(target_delta.normalized())) <= arc * 0.5:
			damage_enemy(enemy, cleave_close_damage(damage, target_delta.length(),
				close_range, close_scale), element, knock, origin, true)
	if hits_props:
		for prop in props():
			if is_instance_valid(prop) and prop.is_targetable():
				var prop_delta: Vector2 = prop.global_position - origin
				if prop_delta.length() <= radius + prop.radius and absf(direction.angle_to(prop_delta.normalized())) <= arc * 0.5:
					prop.damage(damage)

func _damage_line(start: Vector2, end: Vector2, width: float, damage: float,
		element: String, knock: float, hits_props: bool,
		element_once: Variant = null) -> void:
	for enemy in enemies():
		if is_instance_valid(enemy) and not enemy.dead and _distance_to_segment(enemy.global_position, start, end) <= width + enemy.radius:
			damage_enemy(enemy, damage, element, knock, start, true, true, element_once)
	if hits_props:
		for prop in props():
			if is_instance_valid(prop) and prop.is_targetable() and _distance_to_segment(prop.global_position, start, end) <= width + prop.radius:
				prop.damage(damage)

func _damage_props_circle(center: Vector2, radius: float, damage: float) -> void:
	for prop in props():
		if is_instance_valid(prop) and prop.is_targetable() and prop.global_position.distance_to(center) <= radius + prop.radius:
			prop.damage(damage)

func nearest_enemy(origin: Vector2, max_distance: float) -> SkyGearEnemy:
	return nearest_enemy_excluding(origin, max_distance, {})

func nearest_enemy_excluding(origin: Vector2, max_distance: float, excluded: Dictionary) -> SkyGearEnemy:
	var nearest: SkyGearEnemy
	var best := max_distance
	for enemy in enemies():
		if not is_instance_valid(enemy) or enemy.dead or excluded.has(enemy.get_instance_id()):
			continue
		var distance := origin.distance_to(enemy.global_position)
		if distance < best:
			best = distance
			nearest = enemy
	return nearest

## What the running event is worth. Kept as one function so a card that reads
## "salvage" and an event that grants it cannot disagree about the total.
func event_salvage_bonus() -> float:
	return float(event_data().get("salvage_bonus", 0.0))


func event_pressure_bonus() -> float:
	return float(event_data().get("pressure_bonus", 0.0))


## OVER THE SIDE.
##
## The intent from the start and it has never once happened, because the deck
## clamp ran every frame and put everybody back. Now that a hard enough shove can
## carry a boarder past the rail, this is what it is worth.
##
## It routes through the ordinary kill so every downstream thing — the gauge, the
## close-kill dash refund, salvage, the wave counter — behaves exactly as it does
## for a boarder killed with a sword. An enemy that leaves the deck is dealt
## with; making it a second kind of death would mean auditing every one of those
## for a case that differs only in the cue.
func on_enemy_overboard(enemy: SkyGearEnemy) -> void:
	add_floater("OVERBOARD", enemy.global_position, Color("#8fd6ff"), true)
	play_sfx("world/wave_clear.ogg", -12.0)
	enemy.kill()


func on_enemy_killed(enemy: SkyGearEnemy) -> void:
	var close_kill := enemy.global_position.distance_to(player.global_position) <= float(SkyGearData.CLOSE.range)
	if close_kill:
		if not gauge_is_banked():
			pressure = minf(100.0, pressure + 9.0 * (1.0 + event_pressure_bonus()))
		pressure_grace = float(SkyGearData.CLOSE.pressure_grace)
		player.refund_dash(float(SkyGearData.CLOSE.dash_refund))
		## PRESS-GANG. A close kill sometimes gets back up on your side. Rolled on
		## the seeded stream, so a run with it is still reproducible. The ALLY_CAP
		## test sits AFTER the roll on purpose: the stream is consumed identically
		## whether or not the deck is full (board SG-62).
		if article("press_gang") and rng.randf() < 0.06 and allies_alive() < ALLY_CAP:
			crew.append(SkyGearLanes.make_crew(enemy.lane, LANE_CENTERS, BASE_Y, rng))
			crew[crew.size() - 1].position = enemy.global_position
			play_sfx("lane/crew_muster.ogg", -12.0)
		if rng.randf() < float(SkyGearData.CLOSE.scrap_chance) * (1.0 + event_salvage_bonus()):
			## SALVAGER. Flat, on top of the base heal.
			_scrap({"position": enemy.global_position,
				"heal": float(SkyGearData.CLOSE.scrap_heal) + talent("salvage_heal"),
				"time": 12.0})
			tel.salvage += 1
	if rng.randf() < float(mods.scrap_chance) * (1.0 + event_salvage_bonus()):
		_scrap({"position": enemy.global_position, "heal": 12.0, "time": 12.0})
		tel.salvage += 1
	if float(mods.kill_explode) > 0.0:
		## IT CRITS (SG-159). This is also the one surviving re-entry into the
		## crit-explode cycle `damage_enemy` describes: a kill explosion can crit,
		## that crit can open its own explosion, and that explosion can kill again.
		## Bounded, because every traversal costs a living boarder permanently —
		## which is the property to check before adding anything to this line.
		_damage_circle(enemy.global_position, 80.0, float(mods.kill_explode), "EMBER", 70.0, false, false)
	if float(mods.kill_autofire) > 0.0 and rng.randf() < float(mods.kill_autofire) and skills.size() > 0:
		var previous: float = float(skills[0].cooldown_left)
		skills[0].cooldown_left = 0.0
		cast_skill(0, enemy.global_position)
		skills[0].cooldown_left = previous
	play_sfx("enemy/death_heavy_1.ogg" if enemy.kind in ["ARMORED", "BOSS"] else "enemy/death_light_1.ogg", -8.0)
	_fx({"kind": "burst", "position": enemy.global_position, "radius": enemy.radius * 2.5, "color": Color("#ff9a5a"), "time": 0.0, "life": 0.25})

func _update_pressure(delta: float) -> void:
	var close_range := float(SkyGearData.CLOSE.range)
	var nearby := 0
	var nearest := -1.0
	for enemy in enemies():
		if not is_instance_valid(enemy) or enemy.dead:
			continue
		var d: float = enemy.global_position.distance_to(player.global_position)
		if nearest < 0.0 or d < nearest:
			nearest = d
		if d <= close_range * 0.85:
			nearby += 1
	SkyGearTelemetry.note_range(tel, delta, nearest, close_range)
	# both budgets refill continuously
	heal_budget = minf(float(SkyGearData.CLOSE.heal_cap_per_sec), heal_budget + float(SkyGearData.CLOSE.heal_cap_per_sec) * delta)
	steal_budget = minf(float(SkyGearData.CLOSE.lifesteal_cap_per_sec), steal_budget + float(SkyGearData.CLOSE.lifesteal_cap_per_sec) * delta)
	## A BANKED gauge fills from the GROUND, not from the fight, and never leaks.
	## Hers is a meter that reads how well the last few seconds went; his is a
	## bank that reads how much ground he has held. Same widget, opposite meaning.
	if gauge_is_banked():
		_fill_head(delta)
	elif nearby >= 2:
		pressure = minf(100.0, pressure + float(SkyGearData.CLOSE.pressure_idle) * float(mods.pressure_rate) * delta * (1.0 + (nearby - 2) * 0.25))
		pressure_grace = float(SkyGearData.CLOSE.pressure_grace)
	else:
		pressure_grace = maxf(0.0, pressure_grace - delta)
		if pressure_grace <= 0.0:
			pressure = maxf(0.0, pressure - float(SkyGearData.CLOSE.pressure_decay) * delta)
	# FIELD DRESSING pays below 60% health only: a heal that cannot be banked at
	# full health is a comeback, one that runs all run is a difficulty setting.
	if float(mods.dressing) > 0.0 and pressure >= 50.0 and player.hp < player.max_hp * 0.60:
		heal_player(float(mods.dressing) * delta, "regen")
	## Only hers discharges by itself. His sits there until he decides, which is
	## the entire difference between a meter and a bank.
	if bool(class_data().get("gauge_auto_vents", true)) 			and pressure >= 100.0 and vent_cooldown <= 0.0:
		vent_pressure()
	player.set_pressure(pressure)
	_watch_overpressure(delta)

## STANDING STILL IS THE CONDITION ON ALL THREE. He fills on the Boiler, at a
## deck vent, or inside a main he cracked open — and a main is the only one he
## can put where he wants, which is why the class is about choosing ground.
##
## Moving does not empty the bank; it simply stops filling it. A gauge that
## drained the moment you repositioned would make the class a statue rather than
## a man who picks his spot.
func _fill_head(delta: float) -> void:
	var kit: Dictionary = class_data()
	var rate := 0.0
	## The Boiler is the fastest and the only one that COSTS — it is the ship's
	## own heat, and taking it is taking the thing you are defending.
	##
	## I cut this charge when the class was built, on the argument that Blowdown's
	## repair rate already encoded the loss. That was wrong and the design said so
	## in advance: guard #1 of three, and the only one that makes Boiler to Head
	## to Boiler a LOSS. Without it an audit measured 300 Boiler HP repaired for
	## free in thirty seconds — the named failure state, live.
	##
	## 0.6 HP per point, against Blowdown returning 0.35, is a 42% loss by
	## construction. You cannot repair the ship with the ship.
	var on_boiler: bool = player.global_position.distance_to(boiler_position) <= 220.0
	if on_boiler:
		rate = maxf(rate, float(kit.get("boiler_rate", 0.0)))
	for prop in props():
		if not is_instance_valid(prop) or str(prop.prop_type) != "vent":
			continue
		if player.global_position.distance_to(prop.global_position) <= SkyGearData.VENT_STAND:
			rate = maxf(rate, float(kit.get("vent_rate", 0.0)))
	for tap in taps:
		if player.global_position.distance_to(Vector2(tap.position)) <= float(tap.radius):
			rate = maxf(rate, float(kit.get("tap_rate", 0.0)))
	if rate <= 0.0:
		return
	var before := pressure
	pressure = minf(100.0, pressure + rate * delta)
	## And the ship pays for what it gave. Charged on what was actually BANKED,
	## not on the rate, so a full gauge stops costing anything the moment it can
	## hold no more.
	if on_boiler:
		var taken: float = pressure - before
		boiler_hp = maxf(1.0, boiler_hp
			- taken * float(SkyGearData.BLOWDOWN.boiler_cost_per_head))


## Crack a main open where you are standing. His signature, and the only new
## object in the simulation.
## BLEED JET. The dash key, for a class with no dash.
##
## Deliberately worse than hers in every way except one: it costs the gauge, it
## grants no charge back, and it cannot be spammed because the bank runs out. The
## one thing it does that hers does not is leave the lane behind you on fire —
## so a retreat is also a wall, which is the only way a man who cannot outrun
## anything gets to reposition at all.
func bleed_jet(direction: Vector2) -> bool:
	var spec: Dictionary = class_data().get("jet", {})
	if spec.is_empty() or state != State.PLAY or pressure < float(spec.cost):
		return false
	var heading := direction.normalized() if direction.length_squared() > 0.0 \
		else player.aim_direction
	if heading.length_squared() == 0.0:
		return false
	pressure -= float(spec.cost)
	player.set_pressure(pressure)
	## The scald trail is laid BEFORE the move, along the path he is about to
	## take — a trail placed afterwards starts where he ended, which is behind
	## whatever he was running from.
	var steps: int = maxi(1, int(spec.trail))
	for i in steps:
		var at: Vector2 = player.global_position \
			+ heading * float(spec.distance) * (float(i) / float(steps))
		## `spec.trail_radius` (46) was passed here and burned nothing — it sized
		## only the picture, which is exactly the 46-drawn/78-burned gap SG-163
		## closes; the key is deleted now rather than left unread. `trail_dps` is
		## gone too — the rate is the table's, keyed by `source` (board SG-164).
		_field({"position": at, "source": "scald_trail",
			"time": float(spec.trail_life), "tick": 0.0})
	player.jet(heading, float(spec.distance), float(spec.time))
	play_sfx("player/dash.ogg", -4.0)
	return true


func tap_main() -> bool:
	if not gauge_is_banked() or state != State.PLAY:
		return false
	var spec: Dictionary = SkyGearData.TAP
	if tap_cooldown > 0.0 or pressure < float(spec.cost):
		return false
	pressure -= float(spec.cost)
	player.set_pressure(pressure)
	tap_cooldown = float(spec.cooldown)
	taps.append({
		"position": player.global_position, "radius": float(spec.radius),
		"life": float(spec.life), "max_life": float(spec.max_life), "tick": 0.0,
	})
	_fx({"kind": "circle", "position": player.global_position,
		"radius": float(spec.radius),
		"element": "STEAM",
		"color": SkyGearData.ELEMENTS.STEAM.color, "time": 0.0, "life": 0.4})
	play_sfx("player/shape_gale.ogg", -3.0)
	return true


## How much faster a crewman at this spot works. One inside a live main swings
## thirty percent quicker; everyone else is unchanged.
func _crew_haste(at: Vector2) -> float:
	if taps.is_empty():
		return 1.0
	for tap in taps:
		if at.distance_to(Vector2(tap.position)) <= float(tap.radius):
			return 1.0 + float(SkyGearData.TAP.crew_haste)
	return 1.0


## DEADMAN'S SWITCH. Below a quarter the Boiler blows its own steam across the
## deck. Once a wave, so it is a reprieve rather than a floor — a Boiler that
## saved itself every time would mean the objective could not be lost.
func _check_deadman() -> void:
	if not article("deadmans_switch") or bool(article_used.get("deadmans_switch", false)):
		return
	if boiler_hp > boiler_max_hp * 0.25 or boiler_hp <= 0.0:
		return
	article_used["deadmans_switch"] = true
	_damage_circle(boiler_position, 700.0, 200.0, "STEAM", 320.0, false, false)
	_fx({"kind": "circle", "position": boiler_position, "radius": 700.0,
		"element": "STEAM",
		"color": SkyGearData.ELEMENTS.STEAM.color, "time": 0.0, "life": 0.5})
	_fx({"kind": "banner", "text": "THE BOILER VENTS", "time": 0.0, "life": 1.8})
	if impact != null:
		impact.add_shake(18.0)
	play_sfx("player/shape_mortar_land.ogg", -1.0)


## BRACE and RECALL, both on F, never both owned. SCUTTLE on V.
func use_article_f() -> bool:
	if state != State.PLAY or brace_cooldown > 0.0:
		return false
	if article("brace"):
		brace_cooldown = 18.0
		brace_left = 0.35
		player.invulnerability_left = maxf(player.invulnerability_left, 0.35)
		_fx({"kind": "circle", "position": player.global_position, "radius": 120.0,
			"color": Color("#9be8d2"), "time": 0.0, "life": 0.3})
		play_sfx("player/ready.ogg", -6.0)
		return true
	if article("recall"):
		brace_cooldown = 45.0
		_fx({"kind": "circle", "position": player.global_position, "radius": 140.0,
			"color": Color("#8fa6c9"), "time": 0.0, "life": 0.3})
		player.global_position = boiler_position + Vector2(0.0, 160.0)
		player.velocity = Vector2.ZERO
		player.invulnerability_left = maxf(player.invulnerability_left, 0.25)
		_fx({"kind": "circle", "position": player.global_position, "radius": 140.0,
			"color": Color("#8fa6c9"), "time": 0.0, "life": 0.3})
		play_sfx("player/dash.ogg", -4.0)
		return true
	return false


func use_article_v() -> bool:
	if state != State.PLAY or not article("scuttle"):
		return false
	if bool(article_used.get("scuttle", false)):
		return false
	var lit := 0
	for prop in props():
		if not is_instance_valid(prop) or prop.dead or str(prop.prop_type) != "keg":
			continue
		prop.fuse_left = 0.05 + lit * 0.06
		lit += 1
	if lit == 0:
		return false
	article_used["scuttle"] = true
	_fx({"kind": "banner", "text": "SCUTTLE", "time": 0.0, "life": 1.4})
	return true


## TWO SHAPES OF VERB. A repair is HELD, not pressed — a commitment you can
## abandon by walking away, because the cost is the seconds and seconds you can
## take back are not a cost. The crate shove is INSTANT (board SG-37) — it fires
## on the key going down and the sim steps the crate at once; its cost is a short
## cooldown, not standing still. The `instant` flag on the spec selects between them.
func _update_deckwork(delta: float) -> void:
	## The shove cooldown ticks regardless of state, so a wave never opens with it
	## mid-charge from the wave before. The winch's ticks beside it, same reason.
	barricade_cooldown = maxf(0.0, barricade_cooldown - delta)
	winch_cooldown = maxf(0.0, winch_cooldown - delta)
	if state != State.PLAY:
		deckwork = {}
		deckwork_progress = 0.0
		return
	var here := SkyGearDeckwork.available(self)
	## A different target, or none, resets. Progress that survives walking to
	## another cannon is progress you did not pay for.
	if here.is_empty() or (not deckwork.is_empty()
			and str(deckwork.spec.id) + str(deckwork.target) != str(here.spec.id) + str(here.target)):
		deckwork = here
		deckwork_progress = 0.0
		if here.is_empty():
			return
	deckwork = here
	## INSTANT VERBS — the crate shove (board SG-37). No channel: the sim steps the
	## crate the frame the key goes DOWN and the captain keeps moving and fighting.
	## The owner rejected the 2.8s hold ("the hold to move is not fun… too easy to
	## get stuck on the crates yourself"), so there is no progress to fill and no
	## standing-still requirement — only a short per-crate cooldown so it cannot be
	## machine-gunned across the deck, and the same "boarders on it" refusal.
	if bool(here.spec.get("instant", false)):
		deckwork_progress = 0.0
		## Each instant verb pays its own cooldown — the shove's and the winch's
		## are separate, so hauling cover does not lock the flank crate.
		var winching: bool = str(here.spec.id) == "winch_crate"
		if bool(here.contested) or (winch_cooldown if winching else barricade_cooldown) > 0.0:
			return
		if Input.is_action_just_pressed("deckwork"):
			SkyGearDeckwork.perform(self, here.spec, here.target)
			if winching:
				winch_cooldown = WINCH_COOLDOWN
			else:
				barricade_cooldown = BARRICADE_COOLDOWN
			play_sfx("lane/crew_muster.ogg", -6.0)
			_fx({"kind": "circle", "position": Vector2(here.target.position),
				"radius": 90.0, "color": Color("#37f0c8"), "time": 0.0, "life": 0.32})
		return
	## CHANNELLED VERBS — repair, held not pressed.
	if not Input.is_action_pressed("deckwork"):
		deckwork_progress = 0.0
		return
	## Three ways to lose it, and all three are the same idea: you were doing
	## something else. Standing still and unbothered is the only way through.
	if bool(here.contested) or player.velocity.length() > 24.0 			or player.attack_time > 0.0 or player.hurt_time > 0.0:
		deckwork_progress = 0.0
		return
	deckwork_progress += delta / maxf(0.1, float(here.spec.seconds))
	if deckwork_progress >= 1.0:
		SkyGearDeckwork.perform(self, here.spec, here.target)
		deckwork_progress = 0.0
		deckwork = {}
		play_sfx("lane/crew_muster.ogg", -6.0)
		_fx({"kind": "circle", "position": player.global_position, "radius": 90.0,
			"color": Color("#37f0c8"), "time": 0.0, "life": 0.32})


## A STEAM TAP'S TICK PERIOD IS 0.5 SECONDS AT EVERY FRAME RATE (board SG-126).
##
## The same discarded remainder SG-122 fixed for a fire pool: `tap.tick = 0.5`
## threw away however far past zero the countdown overshot, so the true period
## was `ceil(0.5 / delta) * delta` and the main's rate was a function of how fast
## the machine was drawing. It is CARRIED now, and it is a `while` so a step
## LONGER than the period delivers every tick it spans.
##
## This one is the captain's own gauge spend, so the number it moves is a PLAYER
## damage rate — which is exactly why SG-122 filed it rather than folding it in.
## The tick damage is `dps * TAP_TICK` rather than a second hand-written 0.5, so
## the rate and the period cannot drift apart: STATUS's second failure mode is
## two functions disagreeing about one number, and this was one number written
## twice on adjacent lines.
const TAP_TICK := 0.5

func _update_taps(delta: float) -> void:
	tap_cooldown = maxf(0.0, tap_cooldown - delta)
	var i := taps.size() - 1
	while i >= 0:
		var tap: Dictionary = taps[i]
		tap.life = float(tap.life) - delta
		if float(tap.life) <= 0.0:
			taps.remove_at(i)
			i -= 1
			continue
		tap.tick = float(tap.tick) - delta
		while float(tap.tick) <= 0.0:
			tap.tick = float(tap.tick) + TAP_TICK
			_damage_circle(Vector2(tap.position), float(tap.radius),
				float(SkyGearData.TAP.dps) * TAP_TICK, "STEAM", 0.0, false, false)
		i -= 1


## Is he standing in his own steam? Anchored: no knockback, and less damage.
func anchored() -> bool:
	if not gauge_is_banked():
		return false
	for tap in taps:
		if player.global_position.distance_to(Vector2(tap.position)) <= float(tap.radius):
			return true
	return false


## BLOWDOWN. `vent_pressure` with the constants replaced by functions of Head:
## the same explosion, sized by what you banked, and it repairs.
func blowdown() -> bool:
	if not gauge_is_banked() or state != State.PLAY:
		return false
	var spec: Dictionary = SkyGearData.BLOWDOWN
	if pressure < float(spec.min_head):
		return false
	var head := pressure
	pressure = 0.0
	player.set_pressure(pressure)
	var radius: float = float(spec.base_radius) + float(spec.radius_per_head) * head
	_damage_circle(player.global_position, radius,
		float(spec.damage_per_head) * head, "STEAM", float(spec.knock), false, true)
	## It has to bite the hulk, or a push is unwinnable for him.
	hulk_splash(player.global_position, float(spec.damage_per_head) * head)
	## And it repairs — at a rate that makes Boiler to Head to Boiler a 42% loss,
	## so you cannot repair the ship with the ship.
	var repair: float = float(spec.repair_per_head) * head
	if player.global_position.distance_to(boiler_position) <= radius:
		boiler_hp = minf(boiler_max_hp, boiler_hp + repair)
	for turret in turrets:
		if bool(turret.dead):
			continue
		if player.global_position.distance_to(Vector2(turret.position)) <= radius:
			turret.hp = minf(float(SkyGearLanes.TURRET.hp), float(turret.hp) + repair)
	_fx({"kind": "circle", "position": player.global_position, "radius": radius,
		"element": "STEAM",
		"color": SkyGearData.ELEMENTS.STEAM.color, "time": 0.0, "life": 0.42})
	if impact != null:
		impact.note_hit(60.0, true)
	play_sfx("player/shape_mortar_land.ogg", -2.0)
	return true


func vent_pressure() -> void:
	pressure = 0.0
	pressure_grace = 0.0
	vent_cooldown = float(SkyGearData.CLOSE.vent_cooldown)
	var radius := float(SkyGearData.CLOSE.vent_radius) * float(mods.vent_radius)
	# `grants_pressure` is false on purpose: the vent refilling its own gauge
	# from its own blast makes venting self-sustaining in a crowd, which is the
	# healing failure this whole system was rebuilt to remove.
	## The vent CRITS (SG-159) — it is a blow the player spends a full gauge on.
	_damage_circle(player.global_position, radius, float(SkyGearData.CLOSE.vent_damage) * float(mods.vent_damage), "STEAM", float(SkyGearData.CLOSE.vent_knock), false, false)
	heal_player(float(SkyGearData.CLOSE.vent_heal) + float(mods.vent_heal), "vent")
	tel.vents += 1
	_fx({"kind": "circle", "follow": true, "position": player.global_position, "radius": radius, "element": "STEAM", "color": Color("#f2eaff"), "time": 0.0, "life": 0.5})
	if impact != null:
		impact.note_explosion(7.0)
	play_sfx("player/vent.ogg", -2.0)
	if voice != null:
		voice.say("vent")

## `grants_invuln` defaults TRUE so every existing caller keeps today's
## behaviour; every PERIODIC / damage-over-time source passes FALSE (SG-117).
## As of 2026-08-03 there is exactly one such source in the game — the fire
## fields — and the sweep that established that is on the board: enemy burn
## stacks are a DoT on the ENEMY, and the steam taps' half-second tick calls
## `_damage_circle`, which iterates enemies and props and never the captain.
## The flag is threaded rather than special-cased on `_source` so the next
## hazard is a parameter rather than a rediscovery.
func damage_player(amount: float, source: String = "", grants_invuln: bool = true) -> void:
	if state != State.PLAY:
		return
	## ANCHORED. Declared in `SkyGearData.TAP.anchor_resist` and read by
	## `anchored()` since the class landed, and until now nothing applied it —
	## the table said 25% and the player took full damage, which is worse than
	## not having the field at all.
	##
	## It is the compensation for having no dash: he cannot leave, so standing
	## his ground has to be worth something. Only inside a main he opened
	## himself, so it is a reward for the placement rather than a passive.
	if anchored():
		amount *= 1.0 - float(SkyGearData.TAP.anchor_resist)
	## SECOND SHIFT. The first killing blow of a run leaves you at 1 and vents.
	## Checked BEFORE the hit lands rather than after, because `take_damage`
	## clamps at zero and a corpse cannot be resurrected without knowing it was
	## about to be one.
	if article("second_shift") and not bool(article_used.get("second_shift", false)) 			and amount >= player.hp and player.invulnerability_left <= 0.0:
		article_used["second_shift"] = true
		player.hp = 1.0
		player.invulnerability_left = 1.5
		pressure = 100.0
		vent_cooldown = 0.0
		vent_pressure()
		_fx({"kind": "banner", "text": "SECOND SHIFT", "time": 0.0, "life": 2.0})
		if impact != null:
			impact.add_shake(16.0)
		play_sfx("player/ready.ogg", -2.0)
		return
	if player.take_damage(amount, grants_invuln):
		tel.taken += amount
		tel.taken_by_wave[wave] = float(tel.taken_by_wave.get(wave, 0.0)) + amount
		## WHO ACTUALLY HIT HER (SG-146). Every caller of this function has passed
		## a source string since the function was written — `enemy.gd` passes the
		## boarder's `kind`, and the deck passes "bolt", "keg" and "fire" — and
		## until now the parameter was named `_source` because NOTHING READ IT.
		## That is STATUS failure mode one, live in the damage path: the question
		## "is the Colossus dangerous, or is it the four gremlins standing next to
		## him?" was unanswerable from a total that had the answer in its argument
		## list the whole time. Keyed by wave AND source, because the question is
		## always about one wave — a run total cannot tell a wave-12 boss swing
		## from a wave-3 gremlin.
		var by: Dictionary = tel.taken_by_source.get(wave, {})
		by[source] = float(by.get(source, 0.0)) + amount
		tel.taken_by_source[wave] = by
		play_sfx("player/hurt.ogg", -3.0)
		player.hurt_time = 0.34
		if impact != null:
			## Taking one shakes harder than landing one. The browser does the
			## same and it is the difference between a hit you notice and a
			## health bar you notice afterwards.
			impact.add_shake(4.5 + amount * 0.12)
		add_floater("-%d" % roundi(amount), player.global_position, Color("#ff4d37"), true)
		if voice != null and player.hp <= player.max_hp * 0.32 and player.hp > 0.0:
			voice.say("hurt_low", 2)
		_fx({"kind": "burst", "position": player.global_position, "radius": 65.0, "color": Color("#ff4d37"), "time": 0.0, "life": 0.18})
		if player.hp <= 0.0:
			end_reason = "%s fell on wave %d." % [str(class_data().name).capitalize(), wave]
			if voice != null:
				voice.say("defeat", 4)
			_set_state(State.GAMEOVER)

func damage_boiler(amount: float) -> void:
	if voice != null and not _said_boiler_low and boiler_hp <= boiler_max_hp * 0.4:
		_said_boiler_low = true
		voice.say("boiler_low", 2)
	if state != State.PLAY:
		return
	boiler_hp = maxf(0.0, boiler_hp - amount)
	play_sfx("world/boiler_hurt.ogg", -6.0)
	_fx({"kind": "burst", "position": BOILER_POSITION, "radius": 90.0, "color": Color("#ff7a2f"), "time": 0.0, "life": 0.2})
	if boiler_hp <= 0.0:
		end_reason = "The Boiler was destroyed on wave %d." % wave
		if voice != null:
			voice.say("defeat", 4)
		_set_state(State.GAMEOVER)

func spawn_enemy_bolt(origin: Vector2, target: Vector2, damage: float, speed: float) -> void:
	var direction := (target - origin).normalized()
	_bolt({
		"position": origin,
		"velocity": direction * speed,
		"damage": damage,
		"life": 4.0,
		"trail": [origin],
	})

func _update_projectiles(delta: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var bolt: Dictionary = projectiles[i]
		bolt.life = float(bolt.life) - delta
		bolt.position += bolt.velocity * delta
		var trail: Array = bolt.trail
		trail.push_front(bolt.position)
		if trail.size() > 9:
			trail.pop_back()
		var remove := float(bolt.life) <= 0.0 or not DECK_RECT.grow(80.0).has_point(bolt.position)
		## OURS OR THEIRS. Every bolt used to be hostile because every bolt WAS,
		## and the cannon shot added above would otherwise fly down the lane and
		## damage the captain and the Boiler it was fired to defend.
		## OURS OR THEIRS. Every bolt used to be hostile because every bolt WAS,
		## and a cannon shot would otherwise fly down the lane and damage the
		## captain and the Boiler it was fired to defend. A friendly bolt looks
		## for a boarder and is done either way — it never touches anything else.
		if bool(bolt.get("friendly", false)):
			if not remove:
				var hit := nearest_enemy(bolt.position, 46.0)
				if hit != null:
					var was := src_slot
					src_slot = -3             # allies: the ship's own guns
					## The ship's own guns crit too (SG-159).
					damage_enemy(hit, float(bolt.damage), "", 90.0, bolt.position, false)
					src_slot = was
					remove = true
			if remove:
				projectiles.remove_at(i)
			continue
		if not remove and bolt.position.distance_to(player.global_position) <= 27.0:
			damage_player(float(bolt.damage), "bolt")
			remove = true
		if not remove and bolt.position.distance_to(BOILER_POSITION) <= boiler_radius:
			damage_boiler(float(bolt.damage))
			remove = true
		if not remove:
			for prop in props():
				if is_instance_valid(prop) and prop.is_targetable() and bolt.position.distance_to(prop.global_position) <= prop.radius + 8.0:
					prop.damage(float(bolt.damage))
					remove = true
					break
		if remove:
			projectiles.remove_at(i)

## ONE source of truth for where cargo stands, so the collision clamp, the boarder
## funnel and the debug draw can never disagree about it (STATUS failure mode two:
## two functions disagreeing about one number). The eight fixed lane walls, plus
## the draggable crate whenever it is on the deck.
func cargo_rects() -> Array:
	var rects: Array = CARGO_RECTS.duplicate()
	var box := barricade_rect()
	if box.size.x > 0.0:
		rects.append(box)
	return rects


## The crate's footprint, or a zero rect when it is not on the deck (never stowed,
## or smashed). Derived from the PROP's live position, so what blocks a boarder and
## what the renderer mirrors into 3D are the same object.
func barricade_rect() -> Rect2:
	if barricade == null or not is_instance_valid(barricade) or bool(barricade.dead):
		return Rect2()
	return Rect2(barricade.global_position - BARRICADE_SIZE * 0.5, BARRICADE_SIZE)


## What the deckwork table is offered as a target, or {} when the crate is off the
## board. A plain dict like a turret, keyed on the live position so the deckwork
## commit/abort identity check is stable between heaves.
func barricade_target() -> Dictionary:
	if barricade == null or not is_instance_valid(barricade) or bool(barricade.dead):
		return {}
	return {"position": barricade.global_position, "kind": "crate"}


## Heave the crate one step along its cycle. Called by `deckwork.gd`'s perform, so
## the verb table stays what-and-how-long and the sim owns the move.
func heave_barricade() -> void:
	## TABLED (board SG-68) — the null `barricade` already refuses, but the
	## flag is stated here too so the refusal survives any future re-stow edit.
	if not CRATE_VERBS_ENABLED:
		return
	if barricade == null or not is_instance_valid(barricade) or bool(barricade.dead):
		return
	barricade_stage = (barricade_stage + 1) % BARRICADE_STAGES.size()
	barricade.global_position = Vector2(BARRICADE_STAGES[barricade_stage], BARRICADE_Y)


## THE WINCH's haul (SG-56): drag a crate STACK a fixed step toward the
## captain, stopping WINCH_GAP short of her — she is never trapped by cover
## she placed (the SG-37 lesson; crates do not clamp her anyway, but a stack
## parked on her feet would hide her and eat her own shots). Clamped inside
## the deck. Called by the verb table's perform; the verb exists only while
## the WINCH fitting is berthed (`SkyGearDeckwork.available` asks `fitted`).
func winch_crate(prop: SkyGearProp) -> void:
	## TABLED (board SG-68): the fitting cannot sail (`SkyGearFittings.tabled`)
	## so the verb row never appears — and the haul itself refuses too, so a
	## stale save or a direct call cannot move a stack while the family is down.
	if not CRATE_VERBS_ENABLED:
		return
	if prop == null or not is_instance_valid(prop) or prop.dead:
		return
	var to_her: Vector2 = player.global_position - prop.global_position
	var gap := to_her.length()
	if gap <= WINCH_GAP + 1.0:
		return
	var step: float = minf(WINCH_STEP, gap - WINCH_GAP)
	var landed: Vector2 = prop.global_position + to_her.normalized() * step
	prop.global_position = Vector2(
		clampf(landed.x, DECK_RECT.position.x + 60.0, DECK_RECT.end.x - 60.0),
		clampf(landed.y, DECK_RECT.position.y + 60.0, DECK_RECT.end.y - 60.0))


## Put the crate back at its home. The deck re-stows between waves (a pinned
## behavior), and the crate re-stows with it BY DESIGN: a flank you closed is one
## you close again next wave, paying the seconds each time. That is the balance —
## never a permanent free wall — and it is legible, because the crate visibly
## returns to the bow every wave with the rest of the ordnance.
func _stow_barricade() -> void:
	barricade_stage = 0
	## TABLED (board SG-68): the deck still LOOKS the same — a crate stack
	## stands at the same home — but it is an ORDINARY stowed prop, exactly
	## like every other stack: `barricade` stays null, so it is never a verb
	## target, never a cargo rect (no boarder funnel, no x-ray shadow — the
	## eight fixed walls are the whole collision story, for her AND for them),
	## and the coach's shove line (gated on `barricade`) stays quiet.
	if not CRATE_VERBS_ENABLED:
		barricade = null
		var stowed: SkyGearProp = PROP_SCENE.instantiate()
		add_child(stowed)
		stowed.global_position = Vector2(BARRICADE_STAGES[0], BARRICADE_Y)
		stowed.configure(self, "crates")
		return
	barricade = PROP_SCENE.instantiate()
	add_child(barricade)
	barricade.global_position = Vector2(BARRICADE_STAGES[0], BARRICADE_Y)
	barricade.configure(self, "crates")


func restow_props() -> void:
	for prop in props():
		if is_instance_valid(prop):
			prop.dead = true
			prop.queue_free()
	var keg_spots: Array[Vector2] = []
	for entry in SkyGearData.PROP_LAYOUT:
		var prop: SkyGearProp = PROP_SCENE.instantiate()
		add_child(prop)
		prop.global_position = entry.position
		prop.configure(self, entry.type)
		if str(entry.type) == "keg":
			keg_spots.append(Vector2(entry.position))
	## The draggable crate re-stows with everything else — see `_stow_barricade`.
	## The old one was freed in the loop above (it lives in the "props" group).
	_stow_barricade()
	## THE BERTHED FITTINGS' GEOMETRY (SG-56): the bow barricade's crate line,
	## the fourth vent, the scupper's vent. From the RUN's snapshot, never the
	## live workshop, and constant across all twelve waves — the deck re-stows
	## per wave, so "applied once at run start" means the same set deals the
	## same pieces every wave of this run. Consumes NOTHING from either rng
	## stream (positions are authored), pinned by `fittings · placing the whole
	## berth set consumes nothing from the seeded stream`. The `fitting` meta
	## keeps a barricade-line crate out of the winch's hands: a FIXED crate
	## line a verb could drag off the bow would not be fixed.
	for entry in SkyGearFittings.deck_props(run_fittings):
		var fit_prop: SkyGearProp = PROP_SCENE.instantiate()
		add_child(fit_prop)
		fit_prop.global_position = entry.position
		fit_prop.configure(self, entry.type)
		fit_prop.set_meta("fitting", true)
	## POWDER STORE. Extra ordnance, stowed away from the layout's own kegs so it
	## reads as a stockpile rather than as one keg mysteriously duplicated. Placed
	## with the cosmetic stream, or a talent would move every seeded roll after it.
	##
	## And placed OUTSIDE `KEG_SPACING` of every keg already standing — §7.3
	## noted the drop could violate the chain minimum, and a talent that stacks
	## its keg onto a stowed one is a lane-clearing bomb nobody designed. Forty
	## candidates from the cosmetic stream, keep the first clear one (or the
	## farthest-from-trouble one if the deck is somehow that crowded — with at
	## most a handful of kegs on 1.0M square units it never is).
	for i in int(talent("extra_kegs")):
		var best := Vector2.ZERO
		var best_clearance := -1.0
		for _try in 40:
			var candidate := Vector2(
				visual_rng.randf_range(DECK_RECT.position.x + 200.0, DECK_RECT.end.x - 200.0),
				visual_rng.randf_range(-300.0, 500.0))
			var clearance := INF
			for other in keg_spots:
				clearance = minf(clearance, other.distance_to(candidate))
			if clearance > best_clearance:
				best_clearance = clearance
				best = candidate
			if clearance >= SkyGearData.KEG_SPACING:
				break
		keg_spots.append(best)
		var keg: SkyGearProp = PROP_SCENE.instantiate()
		add_child(keg)
		keg.global_position = best
		keg.configure(self, "keg")

func on_prop_destroyed(prop: SkyGearProp) -> void:
	if prop.prop_type == "crate":
		_scrap({"position": prop.global_position, "heal": 12.0, "time": 12.0})
		play_sfx("prop/crate_break_1.ogg", -5.0)
	elif prop.prop_type == "lantern":
		_field({"position": prop.global_position, "time": 6.0, "tick": 0.0})
		play_sfx("prop/lantern_break.ogg", -5.0)
	_fx({"kind": "burst", "position": prop.global_position, "radius": 70.0, "color": Color("#e8c376"), "time": 0.0, "life": 0.25})

func explode_keg(prop: SkyGearProp) -> void:
	if voice != null:
		voice.say("keg")
	if impact != null:
		impact.note_explosion(11.0)
	var center := prop.global_position
	## A keg CRITS (SG-159). It is the loudest thing on the deck and it is
	## allowed to be the biggest number on the deck.
	_damage_circle(center, 175.0, 78.0, "STEAM", 380.0, false, false)
	if center.distance_to(player.global_position) <= 192.0:
		damage_player(26.0, "keg")
	_damage_props_circle(center, 175.0, 78.0)
	_fx({"kind": "burst", "position": center, "radius": 175.0, "color": Color("#ffe08a"), "time": 0.0, "life": 0.45})
	play_sfx("prop/keg_blow.ogg", -1.0)

func _update_salvage(delta: float) -> void:
	for i in range(salvage.size() - 1, -1, -1):
		var item: Dictionary = salvage[i]
		item.time = float(item.time) - delta
		if item.position.distance_to(player.global_position) <= 42.0:
			player.heal(float(item.heal))
			play_sfx("player/pickup.ogg", -5.0)
			salvage.remove_at(i)
		elif float(item.time) <= 0.0:
			salvage.remove_at(i)

## A FIRE POOL'S TICK PERIOD IS 0.25 SECONDS AT EVERY FRAME RATE (board SG-122).
##
## It used to RESET the accumulator — `field.tick = 0.25` — which throws away
## however far past zero the countdown overshot, so the true period was
## `ceil(0.25 / delta) * delta` and the pool's rate was a function of how fast
## the machine was drawing. It is CARRIED now (`+= FIRE_TICK`), so the remainder
## survives into the next interval and the long-run rate is the authored one
## whatever the step. That is not a rounding nicety: it cost an hour in the
## SG-117 session, when `hazard · and a fire pool now deals its authored 12 dps`
## read 10.2 at a hand-stepped 0.05 and looked exactly like the fix
## underdelivering. 0.05 does not divide 0.25 in binary floating point, so five
## steps land a hair SHORT of zero, a sixth is required, and the period rounds
## up to 0.30 — a 17% shortfall produced entirely by the reset.
##
## And it is a `while` rather than an `if`, so a step LONGER than the period
## delivers every tick it covers instead of one. A hitching frame should cost
## the captain standing in fire what the fire was authored to cost her; the
## number of iterations is bounded by the pool's own remaining `time`.
const FIRE_TICK := 0.25

## HOW FAR A FIRE POOL BURNS — AND, SINCE SG-163, HOW BIG IT IS DRAWN.
##
## A pool burned you from OUTSIDE ITS OWN PICTURE, by up to 70%. This literal was
## written twice in this function and a THIRD number sized the picture: the
## renderer took the pool's span from `field.radius`, which the three `_field()`
## sites set to 46 (the Sear trail), 62 (a burning prop) and 62 + 22·residue.
## The Sear trail is the worst of them — drawn at 46, burning at 78 — so the ring
## of deck between them looked safe, was not, and a player who had learned the
## edge of the picture had learned the wrong edge.
##
## This is STATUS's second failure mode, the one `SkyGearHUD.rail()` and
## `scripts/ink.gd` both exist because of: two derivations of one number, drifting.
## There is one derivation now. `fire_pool_radius()` is the only place the number
## is written; the tick reads it, the hidden 2D `_draw` reads it, and
## `view3d.gd` reads it through the accessor rather than off the field dictionary.
##
## THE OWNER CHOSE WHICH SIDE MOVES, verbatim: *"For the fire hitbox, match the
## burn size. Fix the picture to match the damage."* So this value is exactly the
## 78.0 the damage has always used and no balance number changed — the picture
## grew to meet it. `hazard · a fire pool is drawn at exactly the radius it burns
## at` is the regression guard this bug earns.
const FIRE_RADIUS := 78.0


## The pool's radius, for the burn AND for the drawing. A function rather than a
## bare constant because the renderer is what has to be stopped from keeping its
## own copy, and a call it can make is the thing that stops it.
func fire_pool_radius() -> float:
	return FIRE_RADIUS


## The captain's share of a pool's rate. DERIVED, not chosen: the shipped pair
## was 7.5 to a boarder and 3.0 to her, and 3.0 / 7.5 is 0.4. Writing it as the
## ratio keeps that asymmetry true when a source's rate moves.
const PLAYER_FIRE_SHARE := 0.4


## Per-source damage rate (board SG-164). `_field()` stamps this into every
## pool the way it stamps `radius` (SG-163), so a caller cannot put a rate into
## a pool the burn will ignore. An unknown source falls back to `lantern`
## rather than to zero, so a typo in a `source` string still burns.
func fire_pool_dps(source: String, stacks: float) -> float:
	var row: Dictionary = SkyGearData.FIRE_SOURCES.get(
		source, SkyGearData.FIRE_SOURCES["lantern"])
	var base: float = float(row.dps)
	if bool(row.get("per_stack", false)):
		return base * maxf(1.0, stacks)
	return base


func _update_fire_fields(delta: float) -> void:
	for i in range(fire_fields.size() - 1, -1, -1):
		var field: Dictionary = fire_fields[i]
		field.time = float(field.time) - delta
		field.tick = float(field.tick) - delta
		while float(field.tick) <= 0.0:
			field.tick = float(field.tick) + FIRE_TICK
			## A pool tick CRITS (SG-159), per tick, four times a second.
			## The radius is asked for, never restated (SG-163) — four numbers
			## used to claim to be this one. The rate is asked for too now
			## (SG-164) — `field.dps` is stamped by `_field()`, never authored here.
			_damage_circle(field.position, fire_pool_radius(), float(field.dps) * FIRE_TICK, "EMBER", 0.0, false, false)
			if field.position.distance_to(player.global_position) <= fire_pool_radius():
				## NO I-FRAMES (SG-117). This tick fires four times a second, and
				## granting the standard 0.55 s window made a fire pool the safest
				## place on the deck: two ticks in three were swallowed by the
				## window the previous tick opened — so the pool dealt about a
				## third of its authored rate — and, far worse, that window is one
				## global variable, so it blocked boarders' swings and gunners'
				## bolts too. Standing in fire was a defensive move.
				damage_player(float(field.dps) * FIRE_TICK * PLAYER_FIRE_SHARE, "fire", false)
		if float(field.time) <= 0.0:
			fire_fields.remove_at(i)

func _on_dash_started() -> void:
	_cancel_active_channel()
	dash_hit_ids.clear()
	play_sfx("player/dash.ogg", -4.0)
	if voice != null:
		voice.maybe("dash", 1.0 / 6.0)

func _process_dash_impacts() -> void:
	if player.dash_time_left <= 0.0:
		return
	for enemy in enemies():
		if not is_instance_valid(enemy) or enemy.dead:
			continue
		var id := enemy.get_instance_id()
		if not dash_hit_ids.has(id) and enemy.global_position.distance_to(player.global_position) <= enemy.radius + 30.0:
			dash_hit_ids[id] = true
			damage_enemy(enemy, 30.0 * damage_multiplier, "STEAM", 260.0, player.global_position, true)
	for prop in props():
		if not is_instance_valid(prop) or not prop.is_targetable():
			continue
		var id := prop.get_instance_id()
		if not dash_hit_ids.has(id) and prop.global_position.distance_to(player.global_position) <= prop.radius + 28.0:
			dash_hit_ids[id] = true
			if prop.prop_type == "keg":
				prop.light_fuse()
			else:
				prop.damage(30.0)

## --- deck cannons ---------------------------------------------------------
## One per lane, gating it. Boarders have to break it to pass, which is what
## makes a lane a lane rather than a stripe on the floor.
func _update_turrets(delta: float) -> void:
	## The lane call. Checked here rather than in the HUD because the HUD is a
	## view and a view that fires audio is a view that fires audio twice the
	## moment anything else draws.
	if voice != null and state == State.PLAY:
		for enemy in enemies():
			if not is_instance_valid(enemy) or enemy.dead:
				continue
			var depth: float = (enemy.global_position.y - DECK_RECT.position.y) / DECK_RECT.size.y
			if depth > 0.80:
				voice.say("lane_critical", 2)
				break
	for t in turrets:
		t.flash = maxf(0.0, float(t.flash) - delta)
		t.fire_flash = maxf(0.0, float(t.fire_flash) - delta)
		if bool(t.dead):
			continue
		t.cooldown = maxf(0.0, float(t.cooldown) - delta)
		# the boarder nearest the Boiler in this lane, so a cannon covers the
		# thing behind it rather than the thing in front of it
		#
		# …and it does not aim at something it could not hurt if it hit. This
		# used to type the string `"climb"` here and again in the crew loop
		# below — two of the game's own files holding an opinion about which
		# boarders are real, while every player skill held the other one. The
		# question belongs to the boarder: `SkyGearEnemy.can_be_hit()`.
		var best: SkyGearEnemy = null
		var best_y := -99999.0
		for enemy in enemies():
			if not is_instance_valid(enemy) or not enemy.can_be_hit():
				continue
			if enemy.lane != int(t.lane):
				continue
			if enemy.global_position.distance_to(t.position) > SkyGearLanes.TURRET.range:
				continue
			if enemy.global_position.y > best_y:
				best_y = enemy.global_position.y
				best = enemy
		if best == null:
			continue
		t.angle = (best.global_position - Vector2(t.position)).angle()
		if float(t.cooldown) > 0.0:
			continue
		## GUN CREW. Faster reload, which is a smaller number not a bigger one.
		t.cooldown = float(SkyGearLanes.TURRET.cooldown) / (1.0 + talent("turret_rate"))
		t.fire_flash = 0.14
		## A CANNON FIRES SOMETHING. It used to deal its damage the instant the
		## flash played — a gun with a muzzle flash, a bang, and no shot. So the
		## most numerous ally on the deck was contributing damage a player could
		## hear but never see, which is why the lanes read as decoration.
		##
		## A real travelling shot, resolved on arrival. Fast enough that a boarder
		## walking at 150 cannot outrun it across 400 units of range, so this is a
		## readability change and not a stealth nerf — but it CAN miss a target
		## that dies first, which is correct: the shot was already in the air.
		var to_target: Vector2 = best.global_position - Vector2(t.position)
		_bolt({
			"position": Vector2(t.position) + to_target.normalized() * 30.0,
			"velocity": to_target.normalized() * SkyGearLanes.TURRET.shot_speed,
			"damage": SkyGearLanes.TURRET.damage, "life": 1.4,
			"friendly": true, "trail": [],
		})
		play_sfx("lane/cannon_fire_1.ogg", -9.0)


func damage_turret(t: Dictionary, amount: float) -> void:
	if bool(t.dead):
		return
	t.hp = maxf(0.0, float(t.hp) - amount)
	t.flash = 0.16
	if float(t.hp) <= 0.0:
		t.dead = true
		play_sfx("lane/cannon_down_1.ogg", -4.0)
		if voice != null:
			voice.say("cannon_down", 1)
		_fx({"kind": "burst", "position": t.position, "radius": 120.0,
			"color": Color("#ff9a5a"), "time": 0.0, "life": 0.4})
	else:
		play_sfx("lane/cannon_hurt_1.ogg", -12.0)


## Everything it called in the first beat is vented with it, so the turn is a
## clear moment and not a moment spent fighting six swarmers.
func on_boss_turn(boss) -> void:
	for enemy in enemies():
		if is_instance_valid(enemy) and enemy != boss and not enemy.dead:
			enemy.hp = 0.0
			enemy.kill()
	_fx({"kind": "circle", "position": boss.global_position, "radius": 420.0,
		"color": Color("#ffd36b"), "time": 0.0, "life": 0.9})
	_fx({"kind": "banner", "text": "IT TURNS", "time": 0.0, "life": 2.4})
	play_sfx("enemy/boss_roar.ogg", -1.0)
	if voice != null:
		voice.say("boss_turn", 3)


func nearest_crew(origin: Vector2, max_distance: float) -> Dictionary:
	var best: Dictionary = {}
	var best_distance := max_distance
	for c in crew:
		if bool(c.dead):
			continue
		var d: float = Vector2(c.position).distance_to(origin)
		if d < best_distance:
			best_distance = d
			best = c
	return best


func turret_in_lane(lane: int) -> Dictionary:
	for t in turrets:
		if int(t.lane) == lane and not bool(t.dead):
			return t
	return {}


## --- crew -----------------------------------------------------------------
## Every allied UNIT alive: standing crew plus deployed sentries — the two
## things that spawn during play. The deck cannons are structures with fixed
## berths (three, plus the Spare Gun fitting) and are not counted. Everything
## that spawns an ally asks this against `ALLY_CAP` first.
func allies_alive() -> int:
	var alive := sentries.size()
	for c in crew:
		if not bool(c.dead):
			alive += 1
	return alive


## WHO EACH CREWMAN IS FIGHTING THIS TICK — one answer for the whole watch,
## computed once, in one place (board SG-187).
##
## Returns an array parallel to `crew`: the boarder that hand is to go at, or
## null for a hand with nobody to go at — who marches a vulnerable hulk if there
## is one and otherwise holds his station. The FOUR RULES it enforces, and the
## reasoning and the arithmetic behind each of them, are written at
## `SkyGearLanes.ASSIST_LEASH`; this function is only their bookkeeping.
##
## IT IS SEPARATE FROM `_update_crew` BECAUSE THE ANSWER IS NOT PER-MAN. Rules 3
## and 4 — one man per boarder, and every lane keeps its anchor — are statements
## about the WATCH, and a loop that decides one sailor at a time cannot make them
## without a second pass over the others. And it is PUBLIC for the reason
## `hulk_state()` is: the harness asserts on the decision itself rather than on
## the positions it eventually produces, so a check about who a man is fighting
## cannot pass or fail on walking speed and tick counts.
func crew_orders() -> Array:
	var orders: Array = []
	orders.resize(crew.size())
	var hulk_open := not hulk.is_empty() and not bool(hulk.get("dead", true)) \
		and bool(hulk.get("vulnerable", false))
	## PASS ONE — HIS OWN LANE, WHICH OUTRANKS EVERYTHING (rule 1). This is the
	## scan the crew have always had, unchanged and still first: nothing below
	## can reach a man who has a boarder in his own lane, so the recall is the
	## ORDER OF THESE TWO PASSES rather than a rule that has to fire.
	var free: Array[int] = []
	var anchored := {}
	for i in crew.size():
		var c: Dictionary = crew[i]
		orders[i] = null
		if bool(c.get("dead", false)):
			continue
		var target: SkyGearEnemy = null
		var best := 1e9
		for enemy in enemies():
			## Never one he could not hurt — the same guard the cannons carry.
			if not is_instance_valid(enemy) or not enemy.can_be_hit():
				continue
			if enemy.lane != int(c.lane):
				continue
			var d: float = enemy.global_position.distance_to(c.position)
			if d < best:
				best = d
				target = enemy
		if target != null:
			orders[i] = target
			continue
		## RULE 4, THE ANCHOR: the longest-serving UNENGAGED hand in a lane holds
		## it. `crew` is muster order, so this is stable frame to frame and the
		## man it picks is that lane's veteran. A hand already fighting in his
		## own lane does not consume the anchor slot — he is in his lane either
		## way, and spending the slot on him would send a lane's whole idle
		## remainder next door.
		if not anchored.has(int(c.lane)):
			anchored[int(c.lane)] = true
			continue
		## A HULK WITH ITS DOOR OPEN OUTRANKS A NEIGHBOUR'S FIGHT. Breaking it is
		## the crew's actual job and the one thing they are better at than the
		## captain — `siege` is 22 against a swing of 1.5 — so a push wave must
		## not find the watch helping in the lane next door.
		if hulk_open:
			continue
		free.append(i)
	## PASS TWO — THE ASSIST (rules 2 and 3), in muster order, one man per
	## boarder. Muster order rather than nearest-first: a nearest-first rule
	## changes its mind every time two men swap distances, and that is a rule you
	## can watch flickering on the deck.
	var claimed := {}
	for i in free:
		var c: Dictionary = crew[i]
		var post: Vector2 = SkyGearLanes.station(LANE_CENTERS, int(c.lane), BOW_Y)
		var pick: SkyGearEnemy = null
		var best := 1e9
		for enemy in enemies():
			if not is_instance_valid(enemy) or not enemy.can_be_hit():
				continue
			if absi(int(enemy.lane) - int(c.lane)) != 1:
				continue
			if claimed.has(enemy.get_instance_id()):
				continue
			## MEASURED FROM HIS STATION, not from where he happens to be
			## standing. A leash measured from his feet is not a leash: it lets
			## a man walk the length of the deck one leash at a time. Measured
			## from the post it is also the whole of the bound — he walks in a
			## straight line at a point inside a circle he is already inside, so
			## he cannot leave it, and a boarder that walks OUT of it stops
			## qualifying next tick and the man turns for home.
			var d: float = enemy.global_position.distance_to(post)
			if d > SkyGearLanes.ASSIST_LEASH or d >= best:
				continue
			best = d
			pick = enemy
		if pick != null:
			claimed[pick.get_instance_id()] = true
			orders[i] = pick
	return orders


## Your own boarders, pushing the other way. They are minions: they hold a lane
## while you are somewhere else, and on a push they are what breaks the hulk if
## you do not.
func _update_crew(delta: float) -> void:
	var pushing := not hulk.is_empty() and not bool(hulk.get("dead", true))
	crew_timer -= delta
	if crew_timer <= 0.0:
		## The timer resets whether or not anyone musters — HEAT 5 · SKELETON CREW
		## stops the muster, not the clock, so the deck does not spin trying to
		## spawn crew every frame. Under Skeleton Crew you hold the lanes with what
		## you brought; the press-gang and salvage crew you EARN in a run still
		## arrive, because those are the player's doing, not the ship's.
		crew_timer = SkyGearLanes.CREW.push_every if pushing else SkyGearLanes.CREW.every
		if SkyGearWorkshop.musters(int(heat)):
			var mustered := 0
			for lane in LANE_CENTERS.size():
				## MUSTER ROLL. One more hand per lane per muster.
				for _i in int(SkyGearLanes.CREW.per_wave) + int(talent("extra_crew")):
					## THE ALLY CAP (board SG-62). A full deck musters nobody.
					if allies_alive() >= ALLY_CAP:
						break
					crew.append(SkyGearLanes.make_crew(lane, LANE_CENTERS, BASE_Y, rng))
					mustered += 1
			if mustered > 0:
				play_sfx("lane/crew_muster.ogg", -10.0)
				if voice != null:
					voice.say("crew_muster")

	## WHO EVERY HAND IS FIGHTING, DECIDED FOR THE WHOLE WATCH AT ONCE (SG-187).
	## Removals below cannot invalidate it: this loop runs BACKWARDS, so an entry
	## removed at `i` only shifts entries the loop has already visited.
	var orders := crew_orders()
	for i in range(crew.size() - 1, -1, -1):
		var c: Dictionary = crew[i]
		c.flash = maxf(0.0, float(c.flash) - delta)
		if bool(c.dead):
			crew.remove_at(i)
			continue
		var target: SkyGearEnemy = orders[i] if i < orders.size() else null
		if target != null and not is_instance_valid(target):
			target = null
		## HIS OWN STATION, which used to be an inline `BOW_Y + 260.0` here and
		## is a function now because the leash is measured from it.
		var post: Vector2 = SkyGearLanes.station(LANE_CENTERS, int(c.lane), BOW_Y)
		var goal: Vector2 = post
		var reach := float(SkyGearLanes.CREW.reach)
		## HOLDING is "there is nothing on this deck for this man to swing at",
		## and before SG-187 there was no such state. A crewman with no target
		## walked at the head of his lane and the arrival test below was
		## `distance <= reach` — a test that asks how far away his GOAL is and
		## never asks whether anything is standing in it — so he arrived, wound
		## up, swung at bare planking, recovered and did it again for the rest of
		## the wave. That is the second half of the owner's sentence, and it is
		## this one boolean.
		var holding := false
		if target != null:
			goal = target.global_position
		elif not hulk.is_empty() and not bool(hulk.dead) and bool(hulk.vulnerable):
			goal = hulk.position
			reach = float(hulk.radius) + 40.0
		else:
			holding = true
		var to_goal: Vector2 = goal - Vector2(c.position)
		var distance := to_goal.length()
		## WHICH WAY THIS SAILOR IS POINTED, and it is the goal he is already
		## walking at (board SG-103). Owner, build-44: *"Crew members walk
		## backwards, they should face enemies when walking."* The renderer had
		## no way to know — a crewman is the one figure on this deck that
		## carried no direction at all, so `view3d.gd` handed the rig a literal
		## `Vector2(0, -1)` and every sailor faced the bow forever, including
		## the ones `_update_crew` had just turned round to chase a boarder back
		## down the deck.
		##
		## These are the SAME TWO FIELDS every boarder already carries
		## (`SkyGearEnemy.attack_direction` and `.velocity`) under the same two
		## names, so one renderer function can answer for an ally and an enemy
		## alike rather than the crew getting a second rule of their own. Both
		## are derived from `to_goal`, which was computed three lines up for the
		## simulation's own use: no RNG is touched, nothing here reads them
		## back, and they die with the man.
		if holding:
			## A MAN AT HIS POST WATCHES THE BOW, which is where boarders come
			## from — not whichever way the last thing he killed happened to lie.
			c["attack_direction"] = Vector2(0.0, -1.0)
		elif distance > 0.001:
			c["attack_direction"] = to_goal / distance
		c["velocity"] = Vector2.ZERO
		match str(c.state):
			"move":
				if not holding and distance <= reach:
					c.state = "windup"
					c.state_time = SkyGearLanes.CREW.windup
				elif distance > (SkyGearLanes.POST_SLACK if holding else reach):
					var heading: Vector2 = to_goal / distance
					c["velocity"] = heading * float(SkyGearLanes.CREW.speed)
					## The step is CLAMPED to the distance left. Walking at a
					## boarder it never mattered — `reach` is 52 and a step is
					## six — but walking home to a post he is allowed to stand
					## ON, an overshoot is a man crossing his own station and
					## turning round for the rest of the wave.
					c.position = Vector2(c.position) + heading \
						* minf(float(SkyGearLanes.CREW.speed) * delta, distance)
			"windup":
				## CREW INSIDE A MAIN SWING FASTER. The last unread field, and the
				## one that makes the Boilerwright the only class with a reason to
				## care the crew layer exists: his installation is what lets four
				## sailors break a hulk while he holds the lane.
				c.state_time = float(c.state_time) - delta * _crew_haste(c.position)
				if float(c.state_time) <= 0.0:
					c.state = "recover"
					c.state_time = SkyGearLanes.CREW.recover
					var previous := src_slot
					## -4 rather than -3 (SG-187): a crew swing still lands in
					## `tel.allies` — `note_damage` falls through to it — and now
					## also lands in `tel.crew`, so "did the assist make the crew
					## stronger?" is a question the rig can answer without the
					## three deck cannons in the total.
					src_slot = -4
					if target != null and target.global_position.distance_to(c.position) <= reach + 20.0:
						## A crewman's swing crits as well (SG-159).
						damage_enemy(target, SkyGearLanes.CREW.damage, "", 60.0, c.position, false)
						play_sfx("lane/crew_attack_1.ogg", -14.0)
					elif not hulk.is_empty() and not bool(hulk.dead) and bool(hulk.vulnerable) \
							and Vector2(hulk.position).distance_to(c.position) <= reach + 30.0:
						damage_hulk(SkyGearLanes.CREW.siege)
					src_slot = previous
			"recover":
				c.state_time = float(c.state_time) - delta
				if float(c.state_time) <= 0.0:
					c.state = "move"


## Called from the lane update once a lane is genuinely breaking. The HUD
## already shouts it; this is the crew shouting it too.
func note_lane_critical() -> void:
	if voice != null:
		voice.say("lane_critical", 2)


func hurt_crew(c: Dictionary, amount: float) -> void:
	if bool(c.dead):
		return
	c.hp = float(c.hp) - amount
	c.flash = 0.14
	if float(c.hp) <= 0.0:
		c.dead = true
		play_sfx("lane/crew_down_1.ogg", -12.0)
		if voice != null:
			voice.say("crew_down")


## --- the boarding hulk ------------------------------------------------------
## THE THREE STATES, and one function that answers which one — the `hulk_bar`
## pattern (SG-61): the renderer picks a mesh with this, the harness asserts on
## it, and neither can drift from the other because there is one answer.
##
##   ""          nothing grappled on
##   "sealed"    bolted to the hull, plate shut, nothing to bite yet
##   "open"      the door is open and it is sending boarders down the ramps
##   "destroyed" broken, and the wreck stays for the rest of the wave
func hulk_state() -> String:
	if hulk.is_empty():
		return ""
	if bool(hulk.get("dead", false)):
		return "destroyed"
	return "open" if bool(hulk.get("vulnerable", false)) else "sealed"


func _update_hulk(delta: float) -> void:
	if hulk.is_empty():
		return
	hulk.flash = maxf(0.0, float(hulk.get("flash", 0.0)) - delta)
	## The grapple settles, THEN the door opens. Counted here rather than at the
	## call site because this is the one function that owns the hulk's clock,
	## and a second countdown somewhere else is how `vulnerable` got stuck true.
	if not bool(hulk.get("dead", false)) and not bool(hulk.get("vulnerable", false)):
		hulk.grapple = maxf(0.0, float(hulk.get("grapple", 0.0)) - delta)
		if float(hulk.grapple) <= 0.0:
			hulk.vulnerable = true
			play_sfx("lane/hulk_grapple.ogg", -10.0)


func damage_hulk(amount: float) -> void:
	if hulk.is_empty() or bool(hulk.dead) or not bool(hulk.vulnerable):
		return
	hulk.hp = maxf(0.0, float(hulk.hp) - amount)
	hulk.flash = 0.12
	play_sfx("lane/hulk_hit.ogg", -14.0)
	if float(hulk.hp) <= 0.0:
		hulk.dead = true
		play_sfx("lane/hulk_break.ogg", -2.0)
		_fx({"kind": "burst", "position": hulk.position, "radius": 260.0,
			"color": Color("#ffd36b"), "time": 0.0, "life": 0.6})


## A shape that lands on or near the hulk hurts it, so every weapon can bite it
## rather than only the ones that happen to target structures.
func hulk_splash(at: Vector2, amount: float) -> void:
	if hulk_splash_reaches(at):
		damage_hulk(amount)


## HOW FAR OFF THE HULL A SHAPE STILL BITES IT — one band, asked rather than
## re-derived (board SG-186, and SG-119's rule one deck over).
##
## This was a literal inside `hulk_splash` and nothing else could see it. The
## moment the basic attack needed to know whether the hull was worth swinging at,
## the choice was between asking this question and inventing a second reach out
## of `auto.range` — which is STATUS failure mode two with a boarding craft
## bolted to it: the swing would have connected at one distance and the damage
## landed at another, and the player would have watched a cleave pass through a
## hull for nothing.
const HULK_SPLASH_BAND := 150.0


func hulk_splash_reaches(at: Vector2) -> bool:
	if hulk.is_empty() or bool(hulk.dead) or not bool(hulk.vulnerable):
		return false
	return Vector2(hulk.position).distance_to(at) < float(hulk.radius) + HULK_SPLASH_BAND


## THE HULL'S FOOTPRINT, or `{}` when nothing is grappled to the bow (board
## SG-84). The `barricade_rect()`/`cargo_rects()` pattern, for the one shape on
## this deck that is a circle: ONE accessor, so the captain's clamp reads the
## same `hulk.radius` the crew march on (`_crew_step`), every splash measures
## against (`hulk_splash`) and the renderer shadows at. A push-out that carried
## its own copy of that number would be failure mode two with a boarding craft
## bolted to it.
##
## It answers for ALL THREE states, because `hulk_state()` draws a mesh in all
## three: a broken hulk is a WRECK that stays for the rest of the wave, and a
## wreck is exactly as solid to walk into as a sealed one.
func hulk_hull() -> Dictionary:
	if hulk_state() == "":
		return {}
	return {"position": Vector2(hulk.position), "radius": float(hulk.radius)}


func correct_player_position(position: Vector2, radius: float) -> Vector2:
	var corrected := Vector2(
		clampf(position.x, DECK_RECT.position.x + radius, DECK_RECT.end.x - radius),
		clampf(position.y, DECK_RECT.position.y + radius, DECK_RECT.end.y - radius)
	)
	## DELIBERATE DIVERGENCE (board SG-37): the captain clamps against the eight
	## FIXED cargo walls (`CARGO_RECTS`) ONLY — never `cargo_rects()`, which also
	## carries the movable crate. She is NEVER collision-blocked by the crate: it
	## exists to shape the BOARDERS' paths (pillar 4 — cross-passages preserve HER
	## mobility), and a crate she can wall herself in behind is exactly the trap the
	## owner rejected ("too easy to just get stuck on the crates yourself and lose
	## your ability to move between lanes"). So she slips through it freely while
	## enemies still path against the full `cargo_rects()` (8 walls + live crate)
	## in `correct_enemy_position`/`_funnel_past_crate`. Her collision and the enemy
	## rects therefore disagree about the crate BY SPECIFICATION, not by accident
	## (STATUS failure mode two: two functions disagreeing about one number is a bug
	## UNLESS the disagreement is the spec, stated). Pinned by
	## `deck · the captain is never blocked by the heaved crate`.
	##
	## PLUS the berthed closures (SG-56): the SCUPPER GRATING's sealed
	## crossing clamps HER — that is the fitting's whole cost — while staying
	## out of `cargo_rects()`, so boarders and the x-ray are provably
	## untouched (they live in the lane bands; the grating lives in the dead
	## strip between them). One combined loop, so the push-out arithmetic
	## cannot fork into a second copy (failure mode two).
	for cargo: Rect2 in CARGO_RECTS + fitting_walls:
		var expanded: Rect2 = cargo.grow(radius)
		if expanded.has_point(corrected):
			var left_distance := absf(corrected.x - expanded.position.x)
			var right_distance := absf(expanded.end.x - corrected.x)
			var top_distance := absf(corrected.y - expanded.position.y)
			var bottom_distance := absf(expanded.end.y - corrected.y)
			var nearest_side := minf(minf(left_distance, right_distance), minf(top_distance, bottom_distance))
			if nearest_side == left_distance:
				corrected.x = expanded.position.x
			elif nearest_side == right_distance:
				corrected.x = expanded.end.x
			elif nearest_side == top_distance:
				corrected.y = expanded.position.y
			else:
				corrected.y = expanded.end.y

	## AND THE HULL IS NOT A PLACE (board SG-84).
	##
	## Until SG-76 the boarding hulk was a painted card and walking "into" it
	## meant standing in FRONT of one — harmless, and so nothing ever stopped
	## her. It is a 429-unit-deep hull now, and at the bow she went inside it
	## and vanished but for the tip of her cutlass
	## (`.shots/hulk-states/inside-the-hulk.png`). She is stopped at it in the
	## same function and on the same principle as cargo: a push-out to the
	## nearest outside, off the SAME number — `hulk_hull()` is the one
	## accessor, and `hulk.radius` is what the crew already march on and what
	## every splash already measures against.
	##
	## THE BOARDERS ARE UNTOUCHED, and that is the point of doing it here: this
	## is the CAPTAIN's clamp. Enemies go through `correct_enemy_position`,
	## which has never known about the hulk and still does not — they come OUT
	## of the thing, and a wall around it would strand every boarder it lands.
	##
	## THE BOW IS NOT AN EXIT. The hull is bolted across the bow at (0, -1000)
	## with a 190 radius, and the deck runs 143 units north of its centre —
	## so the geometrically shortest way out of the circle is sometimes off the
	## ship. When the nearest outside will not survive the deck clamp she comes
	## out ASTERN at her own x: the way she came in, and the only side of that
	## circle with planking under it.
	var hull: Dictionary = hulk_hull()
	if not hull.is_empty():
		var centre: Vector2 = hull.position
		var keep: float = float(hull.radius) + radius
		var out: Vector2 = corrected - centre
		var gap: float = out.length()
		if gap < keep:
			## Dead on the centre there is no direction to leave by, so she
			## leaves the way the fallback would send her anyway: astern.
			var away: Vector2 = (out / gap) if gap > 0.001 else Vector2(0.0, 1.0)
			var pushed := centre + away * keep
			var landed := Vector2(
				clampf(pushed.x, DECK_RECT.position.x + radius,
					DECK_RECT.end.x - radius),
				clampf(pushed.y, DECK_RECT.position.y + radius,
					DECK_RECT.end.y - radius))
			if landed.distance_to(centre) < keep - 0.01:
				var dx: float = clampf(landed.x - centre.x, -keep, keep)
				landed.y = clampf(centre.y + sqrt(maxf(keep * keep - dx * dx, 0.0)),
					DECK_RECT.position.y + radius, DECK_RECT.end.y - radius)
			corrected = landed
	return corrected

## THE LANES MERGE AT THE STERN.
##
## Found by a design pass and then measured: this clamped every boarder to
## `LANE_CENTERS[lane] +- 190` for its whole life, so a lane 0 or lane 2 boarder
## could get no closer than 385 units to the Boiler — against an attack reach of
## 94 for a scrapper and 148 for the Colossus. TWO OF THREE LANES COULD NEVER
## DAMAGE THE OBJECTIVE. Melee in the outer lanes walked to the stern and stood
## there; only lane 1, and gunners firing from anywhere, could ever hurt it.
##
## So "hold three lanes" was really "hold the middle one", and the lane readout
## has been reporting threat from the outer two that could not materialise.
##
## The clamp is still right for most of the deck — it is what makes a lane a lane
## and keeps the readout honest. It is only wrong at the END. Boarders converge
## over the last stretch, which is what a boarding action looks like anyway: they
## come up the ship in columns and pile onto the thing they came for.
##
## MERGE_FROM is chosen so the columns are unmistakably separate for the whole
## approach and only close in the final quarter, where the player is already
## making a stand rather than reading lanes.
const MERGE_FROM := 380.0

## `shoved` relaxes the lane band to the whole deck for exactly as long as a real
## knockback is carrying someone. Without it a boarder can never reach the rail —
## the band stops 90 units short of it — and "knock them off the ship" was
## unreachable no matter how hard you hit, which is what was reported.
##
## Only the BAND is relaxed. The deck bounds below still hold, so a shoved
## boarder walks to the edge and is caught there rather than sliding into the
## void; going over is decided by `_went_over`, before this ever runs.
func correct_enemy_position(position: Vector2, lane: int, radius: float,
		shoved: bool = false) -> Vector2:
	var centre: float = LANE_CENTERS[lane]
	var half := 190.0
	if shoved:
		centre = DECK_RECT.get_center().x
		half = DECK_RECT.size.x * 0.5
	## How far into the merge this boarder is. 0 on the approach, 1 at the stern.
	## Normalised against the BOILER, not the deck edge. Against the edge the
	## merge is only 60% complete where the Boiler actually stands, which still
	## left the outer lanes 142 units away from a 94-unit reach — closer than the
	## 385 they started at, and still unable to touch it. They are converging on
	## the thing they are walking to, so that is what the merge should finish at.
	var into: float = clampf((position.y - MERGE_FROM)
		/ maxf(1.0, BOILER_POSITION.y - MERGE_FROM), 0.0, 1.0)
	if into > 0.0:
		## Eased, so the columns bend toward the Boiler rather than snapping to
		## it — a linear merge reads as three lines kinking at the same y.
		var pull: float = into * into
		centre = lerpf(centre, BOILER_POSITION.x, pull)
		## And the band widens as it converges, or three columns arriving at the
		## same centre would overlap into one stack of bodies.
		half = lerpf(half, 300.0, pull)
	var held := Vector2(
		clampf(position.x, centre - half + radius, centre + half - radius),
		clampf(position.y, DECK_RECT.position.y + radius, DECK_RECT.end.y - radius)
	)
	return _funnel_past_crate(held, centre, half, radius)


## THE FUNNEL. A boarder walks its lane in a straight column; the draggable crate
## is the one thing that bends that column, so this is where "heave a crate to
## close a lane" becomes true rather than painted. Eject the boarder from the
## crate's footprint to the nearer OPEN side, then re-hold it in the band — so a
## heaved crate narrows the routing, measurably, instead of closing the lane in the
## picture while boarders walk straight through it (STATUS failure mode one).
##
## Never ejected toward the STERN: the thing meant to STOP a boarder must never be
## the thing that shoves it a step closer to the Boiler.
func _funnel_past_crate(p: Vector2, centre: float, half: float, radius: float) -> Vector2:
	var box := barricade_rect()
	if box.size.x <= 0.0:
		return p
	box = box.grow(radius)
	if not box.has_point(p):
		return p
	var d_left := p.x - box.position.x
	var d_right := box.end.x - p.x
	var d_bow := p.y - box.position.y          ## toward the bow, -y
	if d_bow <= d_left and d_bow <= d_right:
		p.y = box.position.y                   ## pinned column: held at the bow face
	elif d_left <= d_right:
		p.x = box.position.x
	else:
		p.x = box.end.x
	p.x = clampf(p.x, centre - half + radius, centre + half - radius)
	return p

## One-shot cues, on the SFX bus, with a ceiling on how many can exist at once.
##
## The browser build leaked a Web Audio node per cue because nothing ever
## disconnected them, and a keg chain into forty boarders creates on the order of
## a hundred cues in one frame. Godot frees a finished player, but a hundred
## nodes a frame is still a hundred nodes a frame, so the cap is here from the
## start rather than after a playtest reports lag.
const MAX_VOICES := 24
var _voices := 0

func play_sfx(relative_path: String, volume_db: float = -6.0) -> void:
	## A posed sandbox is a picture, not a mixer (SG-44): the pose steps a whole
	## begin_run/start_wave through this, and the live game is already playing
	## the real one of every sound it would make.
	if pose_owner != null:
		return
	if _voices >= MAX_VOICES:
		return
	var full_path := "res://assets/audio/sfx/" + relative_path
	if not ResourceLoader.exists(full_path):
		return
	var audio := AudioStreamPlayer.new()
	audio.stream = load(full_path)
	audio.volume_db = volume_db
	audio.bus = "UI" if relative_path.begins_with("ui/") else "SFX"
	add_child(audio)
	_voices += 1
	audio.finished.connect(func ():
		_voices -= 1
		audio.queue_free())
	audio.play()

## The acoustics of a landed blow: which body it has, and what it was made of.
##
## THE ROLL RIDES `visual_rng`, NEVER `rng`. `rng` is the seeded gameplay stream
## — the one that decides crits, drafts and keg placement — and a seed has to
## replay the same run whether or not the mixer had a free voice. Drawing a
## sample variation from it would make the sound of a hit change the fight.
##
## Crit gets its own family rather than a louder `hit_*`: the floater already
## says a crit happened in colour and size, and a signature the ear can name is
## worth more than 3 dB. Element rides ON TOP at low level for the same reason
## the floater is tinted — it is the second question, not the first.
func _sound_hit(element: String, crit: bool) -> void:
	if crit:
		play_sfx("player/crit_%d.ogg" % (visual_rng.randi() % 3 + 1), -7.0)
	else:
		play_sfx("player/hit_%d.ogg" % (visual_rng.randi() % 5 + 1), -11.0)
	## Four elements have takes; PHYSICAL and anything unnamed have none, and a
	## missing file would be swallowed silently by `play_sfx` — so the set is
	## named here rather than trusted.
	if element in ["EMBER", "FROST", "ARC", "STEAM"]:
		play_sfx("player/elem_%s.ogg" % element.to_lower(), -19.0)


func _shape_sound(shape: String) -> String:
	match shape:
		"CLOSEHIT": return "player/shape_cleave.ogg"
		"LINE_BURST": return "player/shape_lance.ogg"
		"CONE": return "player/shape_gale.ogg"
		"RANGED_AOE": return "player/shape_mortar.ogg"
		"CHAIN": return "player/shape_whip.ogg"
		"RAY": return "player/shape_beam_start.ogg"
		_: return "player/hit_1.ogg"

func _distance_to_segment(point: Vector2, start: Vector2, end: Vector2) -> float:
	var segment := end - start
	var length_squared := segment.length_squared()
	if length_squared <= 0.001:
		return point.distance_to(start)
	var t := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * t)

## Everything the renderer pools needs a name that outlives its position in a
## list. The 3D view keyed its billboards and decals by ARRAY INDEX, and every
## one of these arrays is compacted with `remove_at` the moment an entry expires
## — so effect 3 became effect 4 mid-frame and the node drawing it kept its
## place while its contents changed underneath. On screen that is a ring turning
## into a beam, jumping across the deck and resizing halfway through its own
## fade, which is exactly what a passive build produces most of: a Field and a
## Sentry append and expire something several times a second.
var _fx_seq := 0
## Deployed sentries, oldest first. Dictionaries rather than nodes for the same
## reason the crew and the turrets are: the simulation scene is never seen, and
## `view3d` mirrors whatever is in this array.
var sentries: Array[Dictionary] = []
var _sentry_seq := 0


## --- deployables ------------------------------------------------------------
##
## A sentry you place is a decision about WHERE the next ten seconds happen, and
## that is the whole appeal of the shape. Two rules, from the report:
##
##   * pressing it puts one at the cursor, because a turret you cannot aim is a
##     turret that always lands in the wrong lane;
##   * ignoring it deploys one anyway, because it is drafted into the same four
##     slots as everything else and a slot that demands a decision every nine
##     seconds is a slot nobody picks.
##
## The auto is deliberately the WORSE of the two — at your feet, where you were
## already standing — so aiming is rewarded without the lazy line being a trap.
func deploy_sentry(skill: Dictionary, at: Vector2, manual: bool) -> void:
	var st := skill_stats(skill)
	var slot := skills.find(skill)
	## Within arm's reach of the deck and of you: an unclamped cursor places one
	## in the sky over the bow, and an unclamped range makes it a global turret.
	var offset := at - player.global_position
	var reach := float(st.get("deploy_range", 520.0))
	if offset.length() > reach:
		at = player.global_position + offset.normalized() * reach
	at = Vector2(
		clampf(at.x, DECK_RECT.position.x + 60.0, DECK_RECT.end.x - 60.0),
		clampf(at.y, DECK_RECT.position.y + 60.0, DECK_RECT.end.y - 60.0))

	## One slot's sentries retire oldest-first rather than stacking, or a nine
	## second cooldown over a twelve wave run is a deck made of turrets.
	var mine: Array = []
	for s in sentries:
		if int(s.slot) == slot:
			mine.append(s)
	var cap: int = maxi(1, int(st.get("max_live", 2)))
	while mine.size() >= cap:
		var oldest: Dictionary = mine.pop_front()
		sentries.erase(oldest)

	## THE ALLY CAP is total and hard (board SG-62). Sentries are already
	## bounded by the retire-oldest law above, so this only ever fires on a
	## deck flooded with crew — and then the cast is honoured by retiring the
	## oldest sentry standing, or refused outright (cooldown unspent) on the
	## one deck that has none to retire.
	if allies_alive() >= ALLY_CAP:
		if sentries.is_empty():
			return
		sentries.pop_front()

	_sentry_seq += 1
	sentries.append({
		"id": _sentry_seq, "slot": slot, "position": at,
		"element": str(skill.element), "damage": float(st.damage),
		"range": float(st.range), "knock": float(st.get("knock", 70.0)),
		"fire_period": 1.0 / maxf(0.1, float(st.get("fire_rate", 1.4))),
		"fire_timer": 0.35,   ## a beat before the first shot, so it reads as arriving
		"life": float(st.get("life", 14.0)), "max_life": float(st.get("life", 14.0)),
		"born": run_time, "manual": manual, "facing": player.aim_direction.angle(),
	})
	skill.cooldown_left = float(st.cooldown)
	skill.sentry_idle = 0.0
	play_sfx("player/shape_mortar_land.ogg", -4.0)
	## The arrival, so a placement you made on purpose is visibly acknowledged.
	_fx({"kind": "circle", "position": at, "radius": 90.0,
		"element": skill.element,
		"color": SkyGearData.ELEMENTS[skill.element].color, "time": 0.0, "life": 0.34})
	## An auto-placement is a fallback, not a player commitment. This line is
	## after every refusal and after append, so a failed manual placement cannot
	## claim ground either.
	if manual:
		relocate_fields(at)
		## This point is after successful append, Field relocation and cooldown.
		## Automatic and refused placements return without reaching it.
		advance_pulses()


func _update_sentries(delta: float) -> void:
	var previous_src := src_slot
	var i := sentries.size() - 1
	while i >= 0:
		var s: Dictionary = sentries[i]
		s.life = float(s.life) - delta
		if float(s.life) <= 0.0:
			## It ends as a small vent rather than blinking out, or a player who
			## is watching the lane never learns the thing expired.
			_fx({"kind": "circle", "position": s.position, "radius": 70.0,
				"element": str(s.element),
				"color": SkyGearData.ELEMENTS[str(s.element)].color, "time": 0.0, "life": 0.3})
			sentries.remove_at(i)
			i -= 1
			continue
		s.fire_timer = float(s.fire_timer) - delta
		if float(s.fire_timer) <= 0.0:
			var target := nearest_enemy(s.position, float(s.range))
			if target != null:
				s.facing = (target.global_position - Vector2(s.position)).angle()
				## Attributed to the SLOT that placed it. A turret whose damage
				## lands in nobody's row is a turret the run report says is worth
				## nothing, which is how the last balance pass got bad data.
				src_slot = int(s.slot)
				damage_enemy(target, float(s.damage), str(s.element),
					float(s.knock), s.position, true)
				## A sentry sits on the planking, so its shot leaves LOWER than a
				## cast does and there is no arc on it: it is a mounted gun, not a
				## thrown thing. `lift` stays absent and the renderer draws it flat,
				## which is what separates it from a Whip jump.
				_fx({"kind": "line", "from": s.position, "to": target.global_position,
					"element": str(s.element),
					"color": SkyGearData.ELEMENTS[str(s.element)].color,
					"time": 0.0, "life": 0.14})
				s.fire_timer = float(s.fire_period)
			else:
				## Idle scan, so an empty lane is cheap rather than a hot loop.
				s.fire_timer = 0.25
		i -= 1
	src_slot = previous_src


func _fx(d: Dictionary) -> void:
	_fx_seq += 1
	d["id"] = _fx_seq
	effects.append(d)


func _field(d: Dictionary) -> void:
	_fx_seq += 1
	d["id"] = _fx_seq
	## A POOL'S RADIUS IS THE POOL'S, NOT THE CALLER'S (board SG-163). The three
	## sites that make pools each passed their own `radius` — 46, 62, and
	## 62 + 22·residue — and the tick that burns has never read any of them: it
	## burns at `FIRE_RADIUS` for every pool from every source. The renderer read
	## the caller's number, which is how a pool came to be drawn at 46 and burn at
	## 78. Stamped here so the dictionary cannot carry a size the simulation does
	## not honour; the two `radius` arguments that used to be passed in are gone
	## rather than silently overwritten. Whether a Sear trail's pool SHOULD be
	## smaller than a residue pool was board SG-164's open question and it is
	## ANSWERED, in the rate table below rather than here: every pool burns at
	## one radius, full stop — `FIRE_SOURCES` (`game_data.gd`) carries a rate
	## per source and deliberately no radius, so a per-source size cannot
	## re-open what SG-163 already closed.
	d["radius"] = FIRE_RADIUS
	## A POOL'S RATE IS THE TABLE'S, NOT THE CALLER'S (board SG-164), on the
	## same principle as the radius stamp above: the four creators name a
	## `source` and, where it varies, `stacks`; the rate itself is decided here
	## so a caller cannot put a number in the dictionary the tick will ignore.
	d["dps"] = fire_pool_dps(str(d.get("source", "lantern")), float(d.get("stacks", 1.0)))
	fire_fields.append(d)


func _bolt(d: Dictionary) -> void:
	_fx_seq += 1
	d["id"] = _fx_seq
	projectiles.append(d)


func _scrap(d: Dictionary) -> void:
	_fx_seq += 1
	d["id"] = _fx_seq
	salvage.append(d)


func _update_effects(delta: float) -> void:
	for i in range(effects.size() - 1, -1, -1):
		effects[i].time = float(effects[i].time) + delta
		if float(effects[i].time) >= float(effects[i].life):
			effects.remove_at(i)
	## Anything anchored to the captain rides with her. The browser carries a
	## `follow` flag for the same reason: a cleave baked at the position you cast
	## it from slides out of your hands the moment you keep moving, which at
	## dash speed is most of its own lifetime.
	if player != null:
		for e in effects:
			if bool(e.get("follow", false)):
				e["position"] = player.global_position
	for i in range(floaters.size() - 1, -1, -1):
		var f: Dictionary = floaters[i]
		f.time = float(f.time) + delta
		f.position = Vector2(f.position) + Vector2(f.drift) * delta
		if float(f.time) >= float(f.life):
			floaters.remove_at(i)


## A number, leaving a body. Capped, because a swarm wave with a chain skill can
## produce sixty in a frame and sixty numbers is not more information than eight.
func add_floater(text: String, at: Vector2, colour: Color, big: bool = false) -> void:
	if floaters.size() >= 40:
		floaters.remove_at(0)
	floaters.append({
		"text": text, "position": at + Vector2(visual_rng.randf_range(-14.0, 14.0), -10.0),
		"drift": Vector2(visual_rng.randf_range(-26.0, 26.0), -78.0),
		"color": colour, "big": big, "time": 0.0, "life": 0.85 if not big else 1.1,
	})

## THE AIRSTREAM.
##
## Asked of the browser build in exactly these words: what am I supposed to be
## looking at to see that this ship is flying? The answer was "two cloud bands
## drifting", which is to say nothing. The strongest available cue that a
## vehicle is moving is not the scenery — it is stuff going past you.
##
## Ported here with the two things the browser version was missing when it was
## reviewed: it is constant rather than intermittent, and it SHEARS with the
## captain's lateral movement, which says "you are moving through air" rather
## than only "the ship is".
const AIRSTREAM_LANES := 54

func _draw_airstream() -> void:
	var t := float(Time.get_ticks_msec()) * 0.001
	var shear: float = clampf(player.velocity.x / 320.0, -1.0, 1.0) if player != null else 0.0
	for i in AIRSTREAM_LANES:
		var seed_value := float(i) * 0.6180339887
		var lane := fmod(seed_value, 1.0)
		var speed := 1.45 + fmod(seed_value * 7.3, 1.0) * 1.1
		var phase := fmod(t * speed * 0.42 + lane, 1.0)
		var y: float = DECK_RECT.position.y - 200.0 + phase * (DECK_RECT.size.y + 500.0)
		var x: float = DECK_RECT.position.x + lane * DECK_RECT.size.x + sin(seed_value * 31.7) * 90.0
		var length := 90.0 + fmod(seed_value * 13.0, 1.0) * 130.0
		var alpha := 0.06 + fmod(seed_value * 3.1, 1.0) * 0.07
		# the shear: streaks lean against the way the captain is moving
		var lean := -shear * 26.0
		draw_line(Vector2(x, y), Vector2(x + lean, y + length),
			Color(0.62, 0.72, 0.88, alpha), 1.6 + fmod(seed_value * 5.0, 1.0) * 2.0)


func _draw() -> void:
	draw_rect(Rect2(-5000, -5000, 10000, 10000), Color("#17152a"))
	draw_rect(DECK_RECT.grow(24.0), Color("#0d0b12"))
	draw_rect(DECK_RECT, Color("#3d2e30"))
	for y in range(int(DECK_RECT.position.y), int(DECK_RECT.end.y), 58):
		draw_line(Vector2(DECK_RECT.position.x, y), Vector2(DECK_RECT.end.x, y), Color(0.33, 0.25, 0.24, 0.62), 2.0)
	for x in range(int(DECK_RECT.position.x), int(DECK_RECT.end.x), 116):
		draw_line(Vector2(x, DECK_RECT.position.y), Vector2(x, DECK_RECT.end.y), Color(0.12, 0.09, 0.11, 0.28), 2.0)
	draw_rect(DECK_RECT, Color("#b0813f"), false, 8.0)
	_draw_airstream()
	for cargo in cargo_rects():
		draw_rect(cargo, Color("#17131a"))
		draw_rect(cargo.grow(-8.0), Color("#54413c"))
		for y in range(int(cargo.position.y) + 18, int(cargo.end.y), 42):
			draw_line(Vector2(cargo.position.x + 8, y), Vector2(cargo.end.x - 8, y), Color("#b0813f"), 3.0)

	## --- the lane layer -----------------------------------------------------
	## Simulated since this milestone, and drawn here rather than as scene nodes
	## for the same reason it is simulated as plain data: three cannons, a dozen
	## crew and one hulk do not need a Node2D lifetime each.
	if not hulk.is_empty() and not bool(hulk.dead):
		var hull_flash: float = float(hulk.get("flash", 0.0))
		draw_circle(Vector2(hulk.position) + Vector2(0, 20), float(hulk.radius) * 0.9,
			Color(0.01, 0.01, 0.02, 0.5))
		draw_circle(hulk.position, float(hulk.radius),
			Color("#3a2a2e").lerp(Color.WHITE, hull_flash * 2.0))
		draw_circle(hulk.position, float(hulk.radius) * 0.62, Color("#241b25"))
		draw_arc(hulk.position, float(hulk.radius) + 14.0, -PI, -PI + TAU * float(hulk.hp) / float(hulk.max_hp),
			64, Color("#ff4d37"), 9.0)
		# grapples, so it reads as attached rather than parked
		for g in 5:
			var gx: float = float(hulk.position.x) - 150.0 + g * 75.0
			draw_line(Vector2(gx, float(hulk.position.y) + float(hulk.radius) * 0.6),
				Vector2(gx * 0.6, float(hulk.position.y) + float(hulk.radius) + 90.0),
				Color("#4a4a55"), 6.0)

	for t in turrets:
		var pos: Vector2 = t.position
		var dead_gun := bool(t.dead)
		draw_circle(pos + Vector2(0, 12), float(t.radius) * 1.15, Color(0.01, 0.01, 0.02, 0.5))
		var body := Color("#2a2027") if dead_gun else Color("#4a4a55")
		if float(t.flash) > 0.0:
			body = body.lerp(Color.WHITE, 0.6)
		draw_circle(pos, float(t.radius), body)
		if not dead_gun:
			draw_circle(pos, float(t.radius) * 0.55, Color("#b0813f"))
			var muzzle: Vector2 = pos + Vector2.RIGHT.rotated(float(t.angle)) * (float(t.radius) + 26.0)
			draw_line(pos, muzzle, Color("#e8c376"), 9.0)
			if float(t.fire_flash) > 0.0:
				draw_circle(muzzle, 14.0, Color("#ffd36b"))
			draw_arc(pos, float(t.radius) + 10.0, -PI * 0.5,
				-PI * 0.5 + TAU * float(t.hp) / float(t.max_hp), 32, Color("#37f0c8"), 4.0)
		else:
			draw_line(pos + Vector2(-22, -22), pos + Vector2(22, 22), Color("#ff4d37"), 5.0)
			draw_line(pos + Vector2(22, -22), pos + Vector2(-22, 22), Color("#ff4d37"), 5.0)

	for c in crew:
		if bool(c.dead):
			continue
		var cpos: Vector2 = c.position
		draw_circle(cpos + Vector2(0, 8), float(c.radius) * 1.1, Color(0.01, 0.01, 0.02, 0.45))
		var tint := Color("#8fa6c9")
		if float(c.flash) > 0.0:
			tint = tint.lerp(Color.WHITE, 0.7)
		draw_circle(cpos, float(c.radius), tint)
		draw_circle(cpos + Vector2(0, -float(c.radius) * 0.7), float(c.radius) * 0.55, Color("#e8e2d2"))
		if float(c.hp) < float(c.max_hp):
			var w := 26.0
			draw_rect(Rect2(cpos.x - w * 0.5, cpos.y - float(c.radius) - 12.0, w, 4.0), Color("#241b25"))
			draw_rect(Rect2(cpos.x - w * 0.5, cpos.y - float(c.radius) - 12.0,
				w * float(c.hp) / float(c.max_hp), 4.0), Color("#37f0c8"))

	draw_circle(BOILER_POSITION + Vector2(0, 14), 78.0, Color(0.01, 0.01, 0.02, 0.55))
	draw_circle(BOILER_POSITION, boiler_radius, Color("#5b3b25"))
	draw_circle(BOILER_POSITION, 46.0, Color("#b0813f"))
	draw_circle(BOILER_POSITION, 31.0, Color("#37f0c8") if boiler_hp > boiler_max_hp * 0.3 else Color("#ff4d37"))
	draw_arc(BOILER_POSITION, boiler_radius + 8.0, 0.0, TAU * boiler_hp / boiler_max_hp, 48, Color("#e8c376"), 5.0)

	for field in fire_fields:
		var flicker := 0.82 + 0.12 * sin(Time.get_ticks_msec() * 0.012 + field.position.x)
		## The hidden 2D scene, and it read 78.0 as a literal too (SG-163). The rim
		## arc had its own third number — 64 — so even the debug view disagreed
		## with itself about where the pool ends. Both come off `fire_pool_radius()`
		## now; only the flicker is a fraction of it.
		draw_circle(field.position, fire_pool_radius(), Color(0.82, 0.20, 0.05, 0.16))
		draw_arc(field.position, fire_pool_radius() * flicker, 0.0, TAU, 28,
			Color(1.0, 0.42, 0.08, 0.66), 6.0)
	for item in salvage:
		draw_circle(item.position, 18.0, Color("#6bbf72"))
		draw_arc(item.position, 25.0, 0.0, TAU, 18, Color("#e8c376"), 3.0)
	for bolt in projectiles:
		# where it is ON THE DECK, not where it is in the air. Reported against
		# the browser build: enemy fire was hard to track, and an unshadowed
		# sprite has no position you can step out of the way of.
		draw_circle(Vector2(bolt.position) + Vector2(0, 22), 9.0, Color(0.02, 0.015, 0.03, 0.45))
		var trail: Array = bolt.trail
		for i in range(trail.size() - 1):
			var alpha := 0.55 * (1.0 - float(i) / maxf(1.0, trail.size()))
			draw_line(trail[i], trail[i + 1], Color(1.0, 0.35, 0.12, alpha), maxf(2.0, 8.0 - i))
		_draw_flat_ellipse(bolt.position + Vector2(0, 13), 13.0, 5.0, Color(0.02, 0.01, 0.02, 0.55))
		draw_circle(bolt.position, 10.0, Color("#ff5a2f"))
		draw_circle(bolt.position, 4.0, Color("#ffe08a"))
	for effect in effects:
		_draw_effect(effect)

func _draw_effect(effect: Dictionary) -> void:
	var progress := float(effect.time) / float(effect.life)
	var alpha := 1.0 - progress
	var color: Color = effect.get("color", Color.WHITE)
	color.a *= alpha
	match str(effect.kind):
		"arc":
			draw_arc(effect.position, float(effect.radius) * (0.88 + progress * 0.12), float(effect.direction) - 1.22, float(effect.direction) + 1.22, 36, color, 12.0 * alpha + 2.0)
		"line":
			draw_line(effect.from, effect.to, color, 10.0 * alpha + 2.0)
		"beam":
			draw_line(effect.from, effect.to, color, 22.0 * alpha + 5.0)
			draw_line(effect.from, effect.to, Color(1, 1, 1, alpha), 5.0)
		"cone":
			var left := Vector2.from_angle(float(effect.direction) - float(effect.arc) * 0.5) * float(effect.radius)
			var right := Vector2.from_angle(float(effect.direction) + float(effect.arc) * 0.5) * float(effect.radius)
			draw_colored_polygon(PackedVector2Array([effect.position, effect.position + left, effect.position + right]), Color(color.r, color.g, color.b, alpha * 0.22))
			draw_line(effect.position, effect.position + left, color, 4.0)
			draw_line(effect.position, effect.position + right, color, 4.0)
		"circle":
			draw_arc(effect.position, float(effect.radius) * progress, 0.0, TAU, 48, color, 10.0 * alpha + 2.0)
		"burst":
			draw_circle(effect.position, float(effect.radius) * progress, Color(color.r, color.g, color.b, alpha * 0.28))
			draw_arc(effect.position, float(effect.radius) * progress, 0.0, TAU, 36, color, 8.0)

func _draw_flat_ellipse(center: Vector2, width: float, height: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 24:
		var angle := TAU * float(i) / 24.0
		points.append(center + Vector2(cos(angle) * width, sin(angle) * height))
	draw_colored_polygon(points, color)

