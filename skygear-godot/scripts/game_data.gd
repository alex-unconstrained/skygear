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
	"PULSE": {"name": "Pulse", "kind": "pulse", "damage": 34.0, "cooldown": 4.4,
		"radius": 210.0, "knock": 220.0, "passive": true, "cast_advance": 0.35},
	## Deployable, not passive. It was marked `passive: true`, which routed it to
	## `_update_passives`, where "sentry" fired a beam out of the PLAYER at the
	## nearest boarder. Nothing was ever placed on the deck — you drafted a turret
	## and got an invisible one welded to your own ribs. It is an active now: the
	## press puts an object on the planking where you are pointing.
	"SENTRY": {"name": "Sentry", "kind": "sentry", "damage": 14.0, "cooldown": 9.0,
		"range": 420.0, "deploy_range": 520.0, "life": 14.0, "fire_rate": 1.4,
		"knock": 70.0, "auto_after": 2.5, "max_live": 2},
	"RAY": {"name": "Beam", "kind": "ray", "damage": 7.0, "cooldown": 0.6,
		"range": 480.0, "width": 24.0, "knock": 40.0,
		"channel_time": 0.36, "channel_ticks": 4, "channel_move_scale": 0.60},
}

## `attack_range` is the distance that TRIPS a windup; `reach`/`swing` are how far
## and how wide the swing that follows actually lands — the browser's tuned melee
## values (`_core_patched.js` ENEMIES: SCRAPPER reach 92/swing 95°, ARMORED 118/120°,
## SWARM 64/80°). They were missing here, so the port faked reach with a flat
## `attack_range + 24..28` fudge AND drew a thin streak instead of the browser's
## filled swing wedge. Now one number: the sim hits at `reach + target_radius` and
## the telegraph wedge is drawn at `reach` (board SG-3).
##
## EVERY melee row carries both, including the Colossus (board SG-119). This
## comment used to end "Ranged/BOSS have no `reach` and keep their own treatments
## (a firing band, a phase ring)", and the BOSS half of that was never true — he
## was drawn a fan and hit in a circle. Only RANGED is exempt now: a shooter has
## a firing band and no wedge at all, which the harness pins at
## `telegraph · a ranged shooter is not handed a melee swing`.
const ENEMIES := {
	"SCRAPPER": {"hp": 60.0, "speed": 150.0, "damage": 12.0, "radius": 22.0, "attack_range": 66.0, "reach": 92.0, "swing": 1.658063, "windup": 0.40, "recover": 0.42, "ai": "melee", "scale": 0.25, "texture": "res://assets/art/enemies/automaton_front_idle.png"},
	"GUNNER": {"hp": 35.0, "speed": 110.0, "damage": 10.0, "radius": 21.0, "attack_range": 340.0, "windup": 0.45, "recover": 0.80, "ai": "ranged", "bolt_speed": 352.0, "scale": 0.25, "texture": "res://assets/art/enemies/drone_front_idle.png"},
	## THE FURNACE KNIGHT IS A WALL YOU READ, NOT A DPS CHECK (board SG-97, from
	## the build-44 playtest: *"slower more telegraphed hits, hard hitting but
	## designed to be dodged"*). Four numbers moved as ONE design, and the design
	## is: keep what the knight does to a target that cannot move, change
	## everything about what it does to a player who can.
	##
	##   windup  0.55 → 0.90  the READ. 0.55s is under a human's recognise-and-
	##       commit budget with twelve other things on the deck; 0.90s is the
	##       Colossus's own tell, and the two heavies now wind at one tempo. At
	##       260 u/s that is 234 units of walk after the wedge appears, against
	##       the 36 units of backward give between the trip (82) and the reach
	##       (118) — the dodge stops being a reflex and becomes a decision.
	##   recover 0.60 → 1.00  the PUNISH. A whiffed swing leaves a stationary
	##       180-HP target for a full second. Stepping around a knight has to PAY,
	##       or it is just retreating.
	##   damage  20 → 34      the MISTAKE. Three connected swings kill a full-HP
	##       captain (34×3 = 102). "Hard hitting" has to mean the health bar
	##       moves in a way you notice on the first hit, not the fifth.
	##   reach/swing unchanged (118 / 120°) — they are the drawn wedge, and the
	##       wedge is now the hitbox in BOTH dimensions (see `enemy.gd`, the arc
	##       gate). Moving them would move the tell.
	##
	## The cycle goes 1.15s → 1.90s and the damage rises with it, so throughput
	## against the boiler, the crew and the cannons — none of which dodge — is
	## 17.4 dps before and 17.9 after: the wave's pressure is intact and only the
	## player's half of the exchange changed. That is deliberate, and it is why
	## `tools/balance.gd` (whose bot never moves) reports this change as noise.
	##
	## ---------------------------------------------------------------------------
	## AND THEN SG-97's WHOLE DESIGN TURNED OUT TO BE UNREACHABLE, BECAUSE HE DIED
	## INSIDE ONE CYCLE OF IT (board SG-165, owner-approved 2026-08-03).
	##
	## `hp` 180 -> 360. The owner, over a full twelve-wave run: *"we definitely need
	## to buff up his health... due to the slow speed, he needs to be doing damage.
	## That's kind of the mechanic behind it."*
	##
	## SG-156 measured exactly why, and the finding is LIFETIME rather than
	## anything in the hit path. `tools/melee_probe.gd`'s LETHAL arm plays the real
	## run to the knight's last wave with the bot drafting, then pins the captain
	## and lets him die: at wave 11 and 288 effective HP he **LIVED 2.70 s** (sd
	## 0.23, n=23) and in that entire life resolved **0.83 swings and landed 0.78**,
	## for a mean of **26.6 damage** — a quarter of one captain, once. Against a
	## PINNED captain 353 of 353 resolved swings land, 0 swallowed, 0 elsewhere, at
	## 0.3 degrees off-axis: nothing about his hitbox, his arc gate or his damage
	## was ever broken. He simply never got a second swing.
	##
	## THE ARITHMETIC THAT PICKED 360, AND IT IS THE CYCLE. His own cycle is
	## `windup 0.90 + recover 1.00 = 1.90 s`. A life of 2.70 s is ONE cycle plus
	## change, so the 0.90 s tell SG-97 bought is a tell nobody survives to
	## complete — the four numbers above describe a fight the player never has.
	## Doubling the pool buys ~5.4 s, which is two to three cycles: enough for the
	## read-and-punish loop the design is built on to happen more than once.
	##
	## WHAT IT DOES NOT DO IS CHANGE WHAT HE IS. Speed 75, windup 0.90, recover
	## 1.00, damage 34, reach 118, swing 120 degrees are ALL untouched and all
	## harness-pinned. The trade stays exactly the one SG-97 authored — slow,
	## telegraphed, hard-hitting, dodgeable by stepping out of a wedge you can see
	## — and against everything that does not dodge (the Boiler, a cannon, a
	## crewman) his throughput is 17.9 dps before and 17.9 after. This buys him
	## TIME to be that thing, and nothing else. The measured result is at SG-165.
	"ARMORED": {"hp": 360.0, "speed": 75.0, "damage": 34.0, "radius": 32.0, "attack_range": 82.0, "reach": 118.0, "swing": 2.094395, "windup": 0.90, "recover": 1.00, "ai": "melee", "scale": 0.20, "texture": "res://assets/art/enemies/furnace_knight_front_idle.png"},
	"SWARM": {"hp": 20.0, "speed": 230.0, "damage": 6.0, "radius": 15.0, "attack_range": 46.0, "reach": 64.0, "swing": 1.396263, "windup": 0.40, "recover": 0.30, "ai": "melee", "scale": 0.22, "texture": "res://assets/art/enemies/gremlin_front_idle.png"},
	## THE COLOSSUS'S HITBOX WAS BIGGER THAN HIS TELEGRAPH IN BOTH DIMENSIONS
	## (board SG-119). He was the only melee row carrying no `reach` and no
	## `swing`, so the sim connected in a full 360° circle while the renderer
	## drew him a 120° fan out of a fallback constant.
	##
	## `reach` 146 is EXACTLY the number both files already used — the fallback
	## was `attack_range + 26` on each side — so the swing's DISTANCE does not
	## move by a unit: 163 to the captain before, 163 after, and 236+r on the
	## second beat before and after. The only thing that changes is the ARC,
	## from an unconditional circle to the 120° wedge that was always drawn.
	## That makes him easier, which is correct: this row fixes a shape that
	## lied, and his difficulty is a separate question sitting in
	## `docs/COLOSSUS-DESIGN.md` awaiting the owner. His damage, health,
	## windup and recover are untouched here on purpose.
	##
	## HIS HEALTH IS 2900, AND THE NUMBER WAS MEASURED RATHER THAN FELT (SG-146,
	## the owner on build 53: *"The Colossus fight is still super easy. I
	## defeated him really quickly"* and, asked which redesign he wanted, *"he
	## also just needs a lot more HP I think"*).
	##
	## THE MEASUREMENT. `tools/boss_probe.gd` times the wave-12 segment directly,
	## because a whole-run mean is the wrong instrument for one wave in twelve —
	## that is the mistake SG-119 paid for. At 900 (1,494 effective after the
	## 1 + 0.06x(wave-1) scaling) he was resolved in **9.7 s**, n=211 runs that
	## reached wave 12, sd 1.8. Wave 12 itself runs 19.4 s, so he was dead before
	## its halfway mark.
	##
	## WHAT 9.7 SECONDS COSTS THE DESIGN, which is the reason a number was chosen
	## instead of a multiplier. His attack cycle is `windup` 0.90 + `recover` 1.00
	## = 1.90 s, so at 9.7 s he completes **5 swings in the whole fight** — and he
	## turns at half health, so each beat gets **two and a half**. The turn is
	## meant to be the escalation. An escalation that gets two and a half swings
	## cannot be perceived as one; the player never sees the first beat's pattern
	## often enough to learn it, so there is nothing for the second to change.
	##
	## THE TARGET: eight cycles per beat, sixteen in the fight, **30.4 s**. At the
	## measured 153.7 effective HP per second the captain was actually dealing him
	## (1,494 / 9.72), that is 4,672 effective, and 4,672 / 1.66 = 2,814 on the
	## row. **2900** is the round number just above it.
	##
	## AND THE PREDICTION WAS WRONG BY A THIRD, WHICH IS RECORDED RATHER THAN
	## QUIETLY DROPPED: 2900 predicts 31.3 s at a CONSTANT 153.7 eff/s and he
	## actually dies at **23.8 s** (over runs the captain won). Damage-per-second
	## against him RISES as the fight goes on — the adds are cleared early and
	## everything then points at him — so a linear extrapolation from a 9.7 s
	## fight overshoots. Anyone re-deriving this number should fit the curve, not
	## the point.
	##
	## WHAT IT DID NOT BUY, stated here because the next person will otherwise
	## re-derive it: see the SG-146 numbers in `docs/COLOSSUS-DESIGN.md` §1a. More
	## health made the fight LONGER; on its own it did not make it more dangerous,
	## because §1's cycle analysis is about geometry and geometry does not care
	## how much health he has. The chase gate in `enemy.gd` is the half that does.
	"BOSS": {"hp": 2900.0, "speed": 95.0, "damage": 26.0, "radius": 70.0, "attack_range": 120.0, "reach": 146.0, "swing": 2.094395, "windup": 0.90, "recover": 1.0, "ai": "melee", "scale": 0.22, "texture": "res://assets/art/enemies/colossus_front_idle.png"},
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

## TWO CLASSES, AND THE SECOND IS NOT A RESKIN.
##
## Full reasoning in `docs/CLASS-2-DESIGN.md`. The short version is that the
## captain's question is "how long can you stand in it?" — her gauge fills from
## damage landed inside 210 units — and a class that simply fires further is not
## a second question, it is the answer v11 deleted when range-kiting turned out
## to heal faster than three lanes could hurt you.
##
## The Boilerwright's question is "where will the fight happen, and did you get
## there first?" He built the Boiler and keeps it lit, and he fights by cracking
## the ship's own steam mains open — so everything he throws is borrowed from the
## thing he is defending.
##
## HEAD is the same gauge with the opposite polarity. Hers fills by itself when
## the fight goes well and discharges automatically. His fills ONLY where he
## plants himself, never decays, and never spends itself: it is a bank, and every
## point in it is a point he chose not to spend.
const CLASSES := {
	"captain": {
		"name": "THE CAPTAIN",
		"blurb": "Fills his gauge by fighting close, and it vents itself.",
		"long": "Two recharging dashes with contact damage. His gauge fills from damage landed inside 210 units and empties when it is not, and at full it vents by itself for damage and health. Fast, evasive, and correct only where the boarders are.",
		"hp": 100.0, "speed": 260.0, "dashes": 2,
		"gauge": "PRESSURE",
		## Fills from fighting, decays out of it, discharges at the cap.
		"gauge_from_damage": true, "gauge_decays": true, "gauge_auto_vents": true,
		## EMBER CLEAVE. Was hardcoded inside `_process_basic_attack` as four
		## magic numbers, which is fine with one class and wrong with two.
		## `name` and `element` are separate because the element is now the
		## player's to change (board SG-99) and the SHAPE is not: an Arc Cleave is
		## still a Cleave. `element` here is the DEFAULT the pick starts from, not
		## a law — read it through `game.auto_element_id()`, never directly.
		##
		## THE RETURN CUT (design §17.7, board SG-208). The shape repeated one
		## identical fan forever; now it asks a question between the two halves of
		## it. The ODD cut opens twelve degrees to port for 20; the EVEN cut is the
		## RETURN, twelve degrees to starboard, and it pays 24 to a body whose
		## centre is inside 110 and 20 to one that is not. Two connected close cuts
		## are the shipped 44 (`combo_damage[0] + combo_damage[1] * 1.20`); playing
		## the return at the edge of the fan loses four.
		##
		## `damage: 22.0` STAYS, and it is not a second copy of the number: it is
		## what the swing is WORTH per cut on average when both halves connect
		## close (20 and 24), which is what the nameplate, `hud.gd`'s kit row and
		## `tools/hulk_probe.gd`'s dps figure are asking for. The resolver never
		## reads it — see `_process_basic_attack`, which reads `combo_damage`
		## whenever the row carries it.
		##
		## `period`, `range`, `arc` and `knock` are UNCHANGED. The two beats differ
		## in where the fan is centred and what it pays, and in nothing else: a
		## return that also swung faster or further would be a second ability
		## wearing the basic's name.
		"auto": {"kind": "arc", "name": "Cleave", "range": 190.0, "arc": 2.443,
			"damage": 22.0, "period": 0.36, "element": "EMBER", "knock": 150.0,
			"sound": "player/shape_cleave.ogg",
			"combo_damage": [20.0, 20.0],
			"combo_angle": 0.20944,
			"combo_close_range": 110.0,
			"combo_return_scale": 1.20},
		## THE ROWS THE COMPARISON SCREEN LAYS SIDE BY SIDE. Parallel keys, so the
		## screen is a table rather than two paragraphs — the player's question is
		## never "what is this class", it is "what do I get instead of the other
		## one", and only a shared row answers that.
		##
		## NO BALANCE NUMBERS IN HERE. There used to be a `body` row reading "100
		## health, 260 speed, two recharging dashes", which is three numbers
		## restated in prose next to the fields that own them — the two-functions-
		## one-number bug, waiting. The screen derives that row from `hp`, `speed`,
		## `dashes` and `overpressure` instead, so it cannot go stale.
		"compare": {
			"the question": "How long can you stand in it?",
			"the gauge": "PRESSURE — fills from damage you land inside 210 units",
			"and it": "empties when you are not, and VENTS ITSELF at full",
			"what it buys": "the vent, and the vent fires itself. Filling it IS the payoff.",
			"the vent": "40 damage around you and 10 health back, free",
			## SG-59's teaching line. Parallel key, no balance numbers — the rate
			## lives on `vent_rate` and the coach says it live; this row only has
			## to make the vents EXIST for a player reading the two classes.
			"free steam": "means nothing to him. His gauge comes from the fight, not from the ship.",
			"your keys": "Space dashes. Nothing else to press.",
			"stand": "wherever the boarders are — his spot moves, and he chases it",
			"you lose by": "kiting. Range is the losing line and the gauge says so.",
		},
		"starting": [["CLOSEHIT", "EMBER"]],
	},
	"boilerwright": {
		"name": "THE BOILERWRIGHT",
		"blurb": "Banks a head of steam where he stands, and spends it deliberately.",
		"long": "No dash, slower, tougher. Head fills only where he plants himself — on the Boiler, at a deck vent, or inside a main he cracked open — never decays, and never spends itself. While he has any, every weapon hits 45% harder. Slower to start and impossible to move once he has decided where the fight is.",
		"hp": 130.0, "speed": 205.0, "dashes": 0,
		"gauge": "HEAD",
		"gauge_from_damage": false, "gauge_decays": false, "gauge_auto_vents": false,
		## OVERPRESSURE. The reason banking is not hoarding: the gauge is a damage
		## multiplier the whole time it is above zero, so the choice is never
		## "spend or save", it is "spend now or keep the bonus".
		"overpressure": 0.45, "overpressure_cost": 10.0,
		## Where he fills. Standing still is the condition on all three, and the
		## rates are deliberately slow enough that a commute costs real damage.
		"boiler_rate": 45.0, "vent_rate": 18.0, "tap_rate": 26.0,
		## SCALD. A narrower, slower, weaker cone of steam rather than her wide
		## fast ember arc — he reaches slightly further and hits a third less
		## often, which is the difference between a brawler and a man holding a
		## line. Pure data; the simulation reads the same fields for both.
		"auto": {"kind": "cone", "name": "Scald", "range": 210.0, "arc": 1.134,
			"damage": 18.0, "period": 0.6, "element": "STEAM", "knock": 190.0,
			"sound": "player/shape_gale.ogg"},
		## BLEED JET. He has no dash, so the dash key does this instead: a short
		## hop that COSTS the bank and leaves scalding steam in the lane behind
		## him. Every dodge is damage he did not do, which is the sharpest thing
		## about the class and the reason the 25% anchored resist exists at all.
		"jet": {"distance": 220.0, "time": 0.16, "cost": 12.0,
			"trail": 5, "trail_radius": 46.0, "trail_dps": 9.0, "trail_life": 2.4},
		## He wants ground he can hold and hazards he can plant, not a rifle.
		## Weights rather than a different matrix: the 36 cells stay 36 and the
		## draft simply reaches for his shapes first.
		"shape_bias": {"RANGED_AOE": 3.0, "AURA": 3.0, "PULSE": 3.0, "CONE": 2.0,
			"SENTRY": 2.0, "CHAIN": 1.0, "RAY": 0.25, "LINE_BURST": 0.25},
		## Same keys as hers, in the same order, because the screen reads them as
		## rows. A key here that is not there is a row with one answer, which is
		## not a comparison — the harness checks the two sets match.
		"compare": {
			"the question": "Where will the fight happen, and did you get there first?",
			"the gauge": "HEAD — fills only where you plant yourself: the Boiler, a deck vent, a main you cracked",
			"and it": "never decays and never spends itself. It is a bank.",
			"what it buys": "OVERPRESSURE — every weapon you own hits harder the whole time the bank is not empty. That is the class.",
			"the vent": "V spends the whole bank: bigger the more you saved, and it repairs",
			"free steam": "the three grated deck vents bank HEAD for nothing — stand on the teal ring and it fills.",
			"your keys": "F cracks a steam main. V blows it down. Space is a BLEED JET, not a dash — it costs Head and leaves the lane scalding.",
			"stand": "behind your own steam, between it and the Boiler",
			"you lose by": "spending the bank. Empty, he is worse at everything.",
		},
		"starting": [["CONE", "STEAM"]],
	},
}


## THE FOUR NUMBERS THE TWO CLASSES ACTUALLY TRADE, derived rather than written.
##
## Reported after a playtest, verbatim: "Boilerwright feels slower — and I'm not
## sure I understand what the class actually does?" He IS slower, by 21%, and
## that is correct. What was missing is that nothing anywhere told the player
## what he bought with it. Three of these four rows are the price and the fourth
## is the goods.
##
## Read off `CLASSES` every time it is asked, never transcribed, because the one
## thing this table must never do is disagree with the simulation about a balance
## number. `better` is the id of whichever class wins the row, or "" where the
## row is not a contest — it is what lets the screen tint the winner and makes
## the trade visible without a sentence explaining it.
static func class_stats() -> Array:
	var ids: Array = CLASSES.keys()
	var rows: Array = []
	for spec in [
		{"name": "HEALTH", "of": func(k: Dictionary) -> float: return float(k.hp),
			"say": func(k: Dictionary) -> String: return "%d" % int(k.hp)},
		{"name": "TOP SPEED", "of": func(k: Dictionary) -> float: return float(k.speed),
			"say": func(k: Dictionary) -> String: return "%d" % int(k.speed)},
		{"name": "DASH", "of": func(k: Dictionary) -> float: return float(k.dashes),
			"say": func(k: Dictionary) -> String: return ("%d, recharging" % int(k.dashes)) \
				if int(k.dashes) > 0 else "none at all"},
		## The one that has never been on screen anywhere. A damage multiplier the
		## player cannot see is, as far as they are concerned, not in the game.
		{"name": "DAMAGE", "of": func(k: Dictionary) -> float: return float(k.get("overpressure", 0.0)),
			"say": func(k: Dictionary) -> String: return ("+%d%% while the gauge is up"
				% roundi(float(k.get("overpressure", 0.0)) * 100.0)) \
				if float(k.get("overpressure", 0.0)) > 0.0 else "base, always"},
	]:
		var row := {"name": str(spec.name), "values": {}, "better": ""}
		var best := -1.0
		var tied := false
		for id in ids:
			var kit: Dictionary = CLASSES[id]
			var amount: float = (spec.of as Callable).call(kit)
			row.values[id] = (spec.say as Callable).call(kit)
			if is_equal_approx(amount, best):
				tied = true
			elif amount > best:
				best = amount
				tied = false
				row.better = id
		if tied:
			row.better = ""
		rows.append(row)
	return rows


## Where a deck vent feeds him, in ground units from its grate. `_fill_head`
## measures the same 150 when it decides whether the bank is filling, and the
## renderer draws the Boilerwright's teal stand-here ring from THIS constant —
## the harness pins the two behaviourally (`vent · the ring is drawn at the
## radius the bank actually fills at`), because a ring painted at one radius
## and a gauge that fills at another is the two-functions-one-number bug
## wearing paint (board SG-59).
const VENT_STAND := 150.0

## A cracked steam main. His only new simulation object, and deliberately shaped
## exactly like `fire_fields` — same array-of-dictionaries, same tick, same
## `_damage_circle` — because a new kind of thing is renderer work and a copy of
## an existing one is not.
const TAP := {
	"radius": 130.0, "life": 8.0, "dps": 6.0, "cost": 18.0, "cooldown": 6.0,
	## Kills inside extend it, so holding a main is rewarded by the main lasting
	## longer, which is the loop the class is built around.
	"extend_on_kill": 0.6, "max_life": 14.0,
	## Anchored: inside your own main you take a quarter less.
	"anchor_resist": 0.25,
	## And the crew work faster in it. The reason he is the only class with a
	## reason to care the crew layer exists — his installation is what breaks a
	## hulk while he holds the lane.
	"crew_haste": 0.30,
}

## Blowdown. `vent_pressure` with the constants replaced by functions of Head —
## the same explosion, sized by what you banked.
const BLOWDOWN := {
	"min_head": 20.0, "damage_per_head": 0.9, "base_radius": 120.0,
	"radius_per_head": 1.6, "knock": 300.0,
	## Repairs the Boiler or a live cannon inside it. 0.35 per Head against the
	## Boiler charging 0.6 per Head is a 42% LOSS by construction: you cannot
	## repair the ship with the ship, and net-positive requires being out on the
	## deck at a vent or a main. That inequality is the whole guard against the
	## failure this class could have had.
	"repair_per_head": 0.35,
	## What the Boiler charges for its own heat, per point of Head. Against the
	## 0.35 above this is a 42% loss, which is the inequality that makes the
	## objective loseable — see `_fill_head`. The two numbers only mean anything
	## next to each other, so they live next to each other.
	"boiler_cost_per_head": 0.6,
}


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
	## THE THIRD VENT. There were two, in lanes 0 and 2, and none in the middle —
	## which for the Boilerwright means the centre lane is the one place he
	## cannot refill without walking off it. Two free taps and one starved lane
	## is not a decision, it is a lane nobody holds. On the y = +15 cross-passage,
	## so it covers the gap between the cargo runs rather than sitting inside one.
	{"type": "vent", "position": Vector2(40, 15)},
	{"type": "ballista", "position": Vector2(-700, -820)},
	{"type": "ballista", "position": Vector2(700, -820)},
	{"type": "railing", "position": Vector2(-780, -300)},
	{"type": "railing", "position": Vector2(-780, 240)},
	{"type": "railing", "position": Vector2(780, -300)},
	{"type": "railing", "position": Vector2(780, 240)},
]

## §7.3's keg-chain numbers: `explode_keg` deals 78 into a 175 radius and a
## keg dies at 34, so any keg within 200 units of a detonation detonates too.
## POWDER STORE's dropped kegs respect this spacing since board SG-51 (they
## could stack before). The seeded STOWAGE table that briefly stood here — a
## per-wave deal over these positions — was built and then CUT by SHIP-AND-
## MAPS §7.1's own kill-test (board SG-48: close-share flat vs live came back
## indistinguishable, so the variety was cosmetic; the rule was written before
## the numbers). The whole spine is at commit d10f09c if it is ever re-asked.
const KEG_SPACING := 200.0

static func skill_name(skill: Dictionary) -> String:
	return "%s %s" % [ELEMENTS[skill.element].name, SHAPES[skill.shape].name]

static func make_skill(shape: String, element: String) -> Dictionary:
	## Per-skill modifiers live on the instance, exactly as they do in the
	## browser build: a card that says "+30% range on Frost Mortar" has to be
	## able to say it about ONE of your skills, not about the shape table.
	var skill := {
		"shape": shape, "element": element, "cooldown_left": 0.0, "level": 1,
		"casts": 0,
		"mods": {
			"area": 1.0, "range": 1.0, "cooldown": 1.0, "damage": 1.0,
			"knock": 1.0, "multi": 1, "pierce": 0, "jumps": 0,
			"wide_cone": false,
		},
	}
	## AB-02. Only a Field owns an anchor. It starts unset so a build with no
	## active skill keeps following the captain until an accepted landing says
	## otherwise; the vector is still present for diagnostics and wave resets.
	if shape == "AURA":
		skill["field_anchor"] = Vector2.ZERO
		skill["field_anchor_set"] = false
	return skill


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

