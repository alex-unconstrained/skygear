# COLOSSUS-DESIGN — making the wave-12 boss a fight

Status: **DESIGN, part-built. READ §1a BEFORE §1 — §1's central claim was measured and is half wrong, and §2's root fix was built, measured, and failed its own kill-test (SG-146).** Written 2026-08-03 against the owner's build report,
verbatim: *"Collosus is way too easy - he needs to be scary the player."* This is
about the fight, not the picture — his texture bug is fixed and tracked
separately. Three designs were written independently and judged twice; both
judgements are carried below, including where they disagreed. **Nothing here has
been decided.** The recommendation is a recommendation.

Sources read: `docs/BOARD.md` (SG-96, SG-73, SG-94/95), `docs/ENEMY-VARIETY-DESIGN.md`
§1–2.1, `DESIGN.md` §2 (the seven pillars), `STATUS.md` §"the five recurring failure
modes", `docs/DECK-IDENTITY-DESIGN.md`, `scripts/enemy.gd`, `scripts/game.gd`,
`scripts/game_data.gd`, `scripts/view3d.gd`, `tools/balance.gd`.

---

## 1. Why he is easy today

**His attack cycle is self-defeating against anything that moves, and he has
nothing else in his kit.** He trips his windup at `attack_range 120 + target
radius 17 = 137` units and then stands perfectly still for `windup 0.90 s` while a
260 u/s captain walks 234 units — putting her at ~371, comfortably outside the
163-unit swing (`reach` is absent from `ENEMIES.BOSS`, so `_swing_hits` falls back
to 26) — and then stands still for another `recover 1.00 s`. Every time the
Colossus decides to attack a mobile player he pays 1.9 seconds of frozen uptime
for a swing that geometrically cannot land, and he closes at 95 u/s against her
260 plus two 265-unit dashes, so he never gets the initiative back. His only real
throughput is **26 damage per 1.90 s = 13.7 dps** against things that don't dodge
— the Boiler, a cannon, a crewman — which is *below* a furnace knight's 17.9, and
even that is limited to the `x ∈ [-120, +120]` column `correct_enemy_position`
(`game.gd:4402-4429`) pins him inside on a deck 1,680 wide. Against him the
player has a free 61-dps Ember Cleave that reaches his centre at **260** — because
every player damage test adds the target's radius 70 (`_damage_circle/_cone/_line`,
`game.gd:3146-3174`) — out-ranging his swing by **97 units for free, forever**,
plus an auto-venting pressure gauge that his own 1,494 effective HP keeps topped
for 40 damage and 10 healing every two seconds. And the half-health turn, meant to
be the escalation, *removes* the fight's only real pressure: `on_boss_turn`
(`game.gd:4043-4053`) kills the four SWARM and three SCRAPPER through
`on_enemy_killed`, paying **+9 pressure each, a 0.30 s dash refund each, 10%
scrap-heal rolls and press-gang crew**, then hands back a 1v1 whose entire second
beat is `attack_range += 90`. He is not a fight the player must solve; he is
1,494 HP of stationary target that feeds her resources while she out-walks a
1.9-second swing.

One more fact, because it inverts the furnace-knight lesson rather than repeating
it: `view3d.gd:4488-4509` draws him a **120° fan at 146**, while `_swing_hits`
(`enemy.gd:127-137`) returns `true` unconditionally for a row with no `"swing"` key
— a **360° circle at 163**. His hitbox is both wider and longer than his picture.
That makes him *harder*, not easier, which is the proof that the easiness comes
from the cycle and the range, not from the shape lie. The shape lie still has to
go, and every design below deletes it the same way: by giving `ENEMIES.BOSS` the
`reach`/`swing` fields it is the only melee row missing, so that no enemy in the
game takes the reach-less branch and the carve-out comment about him
"telegraphing with a phase ring rather than a fan" — which is false today — can be
deleted with it.

> **SHIPPED 2026-08-03, ahead of your decision (board SG-119).** The paragraph
> above is written in the present tense and is now history: `ENEMIES.BOSS`
> carries `reach` 146 and `swing` 120°, both carve-out branches are deleted, and
> the wedge is one function that the renderer calls instead of re-deriving. The
> shape lie is gone. **Nothing else about him moved** — 146 is exactly the
> `attack_range + 26` both fallbacks already computed, so his swing lands at the
> same 163 (253 on the second beat) it always did, and his damage, health,
> windup and recover are harness-pinned unchanged. **He is therefore easier than
> when §1 was measured, by the arc alone**: the share of bearings his swing
> connects from went 1.000 → 0.335. That is deliberately NOT compensated here,
> because §2's recommendation is the place to answer how hard he should be, and
> a shape correction that also carried a buff would have made this document's
> question unanswerable. Read §1's difficulty analysis as still standing — it
> concluded the easiness comes from the cycle and the range rather than the
> shape — but read its *numbers* as pre-SG-119.

---

## 1a. What §1 got wrong, measured (SG-146, 2026-08-03)

**§1 above is an argument from geometry and it is half wrong. This section is the
measurement, and it exists because the owner's next decision should rest on
numbers rather than on the arithmetic in §1.** Nothing above has been edited;
read §1 as the reasoning that was available before the fight had ever been
timed, and read this as what the fight actually does.

**THE INSTRUMENT.** `tools/boss_probe.gd` — new, because `tools/balance.gd`
reports a WHOLE-RUN mean and the Colossus is one wave in twelve, which is the
error SG-119 paid for. It times the wave-12 segment directly and reports against
the number of runs that REACHED wave 12. Alongside it, `tel.taken_by_source`
finally reads the `source` string `damage_player` has always been passed and has
never recorded — so "who actually hit her" is a measurement now instead of an
inference. Heat 0, four arms off one base commit:

| | hp 900 (build 53) | hp 1800 | **hp 2900 (shipped)** | hp 2900 + lane walk |
|---|---|---|---|---|
| n (reached wave 12) | 211 | 160 | 332 | 214 |
| boss time-to-kill | 9.7 s | 16.0 s | 22.0 s | 24.0 s |
| ...on runs she won | 9.8 s | 16.2 s | 23.8 s | 24.2 s |
| damage taken in wave 12 | 45.5 | 94.4 | 131.5 | 13.4 |
| **...of that, BY HIM** | **29.9** | **83.4** | **123.4** | **0.00** (sd 0.00) |
| damage taken per second | 2.35 | 4.59 | 6.04 | 0.59 |
| Boiler HP lost in wave 12 | 9.5 | 4.6 | 4.8 | 11.3 |
| runs held | 100% | 92% | 66% | 99% |

**FINDING 1 — §1's central claim is false, and it was false before any of this
landed.** §1 says his swing "geometrically cannot land" on a moving captain and
that his real throughput is only against things that do not dodge. At hp 900 he
was already dealing **66% of all wave-12 damage** (29.9 of 45.5). The reason is
one number §1 does not mention: **his second-beat swing reaches
`146 + 90 + 17 = 253` units, and `tools/bot.gd` holds a 210-unit band.** The
thing he is fighting stands inside his reach. §1's 234-units-of-walk arithmetic
assumes a captain who keeps retreating; the bot orbits at a fixed radius, and so,
mostly, does a player who wants her pressure gauge to fill.

**So the honest form of §1's conclusion is narrower: he cannot land on a captain
who RETREATS, and he lands freely on one who ORBITS.** That is a very different
design problem, and it is not solved by taking his chase away.

**FINDING 2 — health alone did not make a longer boring fight. It made a shorter
patience and a real threat.** Wave 12 got 24% longer while damage taken in it
rose 189%, so danger *per second* rose 157% (t=16.5). His own share went 29.9 →
123.4. **Read it with its caveat: this is measured against a bot that orbits at
210 inside a 253-unit reach.** How much survives a player who backs out during
beat 2 is a question for the owner's hands, and it is the first thing to watch in
build 56.

**FINDING 3 — the chase gate (§2 graft 1) fails its own pre-committed kill-test,
and is therefore SHIPPED OFF.** §2's amended statistic (2) set the bar in
advance: *"Median Boiler HP lost during wave 12 must rise by >= 40 of 500 against
a baseline of ~0."* Measured **9.5 → 11.3, Welch t = 0.51**, with the Boiler
still taking nothing at all in 88% of runs. The design's own rule for that
outcome is written down and it is **CUT, not tune**.

It fails in the other direction too, and worse: with the gate on **he deals the
captain exactly zero, mean 0.00 with 0.00 spread over 214 runs.** Not "rarely" —
never, structurally. The victim chain in `enemy.gd` is if/elif and
`target_turret`/`target_crew` are only populated in the `else` branch, so a boss
who is not targeting the captain never tests her against his swing at all. §4's
own honest weakness — *"it can read as indifference"* — arrives here as a number.

**Why the Boiler clock does not bite:** he needs 20.7 s to walk 1,965 units to
the Boiler, he lives 23.8 s, and he now meets the lane cannon first. The clock
the design is built on barely fits inside the fight and mostly does not. For the
gate to earn its `true` he must live long enough to arrive, or start nearer the
ship, or gain the multi-victim resolve §4 prices at ~220 lines — all decisions,
not tunings.

**WHAT THIS DOES NOT SETTLE.** Whether 2900 is the right number. It buys a fight
that is genuinely dangerous and costs 34 points of hold-rate at Heat 0; hp 1800
buys most of the danger (his damage 29.9 → 83.4) for 8. That is the owner's
trade and it is in `NEEDS_ALEX.md`, with the curve, rather than being decided
here.

---

## 2. Recommendation

**Build OPTION B — STOKE · WASH · COOL, with three grafts.** It is the only one
of the three that makes the *player* afraid rather than the ship, which is what
the owner actually asked for. The dread is a gauge she can watch filling, and the
counterplay is to walk **into** a machine that hits for 30 — pillar 5
("close-range risk earns pressure, healing, and dash tempo") pointed at the
player for once. Its telegraph craft is also the best of the three: a thin static
outline held at the full 300 for the whole 1.10 s answers *where do I stand*, not
merely *something is coming*, and gold ring versus red fan is one-frame
distinguishable at any zoom.

It does not win unamended. Three things get grafted onto it, and the first two
are load-bearing, not polish:

1. **From SLAG MARCH — the one-line root fix.** Gate the `distance_to(player)
   < 280` branch at `enemy.gd:212` on `kind != "BOSS"`. The Colossus targets
   lane-1 cannon → crew → Boiler, always. STOKE·WASH·COOL as written never
   touches the loop that *is* the easiness: he still walks at a 260 u/s captain
   at 95 u/s and still freezes to swing where she was. Gating the chase deletes
   that loop outright, and it closes the design's other hole for free — a 300-unit
   wash defines "too far to matter" at 300, and Lance (520), Beam (480), Mortar
   (420) and Whip (480) all sit outside it. With the chase gone, standing at 480
   is no longer free: it is priced in Boiler HP.

2. **From SLAG MARCH — `damage_player` gains `grants_invuln := true`, and every
   ground-hazard tick passes `false`.** `player.gd:197` sets 0.55 s of
   invulnerability on *any* hit taken. A captain standing in a wash's fire pool,
   ticking every 0.25 s, is therefore permanently immune to the 30-damage wash
   and the 30-damage slam — standing in the fire becomes the safest place on the
   deck, the exact inversion of the design. This is also a live bug on today's
   `fire_fields`, so it ships regardless of which option is chosen.

3. **From THE FURNACE MARCH — the two-sided connect gate**, moved out of the bot
   statistics (where it saturates against a stationary bot) and into the harness
   as a geometric assertion: the wedge that connects is the wedge that was drawn,
   and the circle that connects is the circle that was drawn.

**And its kill-test must be amended before a line lands, or it does not ship.**
STOKE·WASH·COOL's required statistic (2) — "the median fraction of wave-12 time
the bot spends within 300 units of the Colossus must fall by ≥15 percentage
points" — cannot fire. `tools/balance.gd` hand-steps `game._process(0.05)` and
casts at `nearest_enemy` every fourth step; **it issues no movement input at
all** (the comment at line 187 says "keeps moving"; the loop does not move it —
that comment is itself a claim asserted from memory). The fraction sits near 1.0
in both arms and can never fall, and the design's own rule says (1)-passes-
(2)-fails means CUT, not tune. As written the design deletes itself on evidence it
never gathered. The amendment, which keeps the pre-commitment honest and is
readable from a stationary bot:

> **Amended statistic (2).** Median Boiler HP lost during wave 12 must rise by
> ≥ 40 of 500 against a baseline of ~0 — the direct test of "you can no longer
> ignore him", enabled by graft 1 — AND the four harness geometry rows must pass.
> Statistic (1) and the 40–120 guard rail are unchanged. If (1) passes and the
> amended (2) does not, the furnace is a damage tax wearing a ring decal and it
> is CUT by ENEMY-VARIETY §2.3, not tuned.

Cost with grafts: **~200 lines**, no new art, no new models, no new animation
clips, no new subsystem. Call it three to four days including the noise floor and
the harness rows, not "days" loosely.

---

## 3. Three fixes that ship regardless of which option wins

Written out separately because they are true under all three designs and two of
them are bugs, not features.

- **`ENEMIES.BOSS` gains `reach` and `swing`** (`game_data.gd:70`). This deletes
  the `_swing_hits` carve-out (`enemy.gd:132-133`) and the `view3d.gd:4496-4501`
  fallback branch by construction. After it, no enemy takes the reach-less path.
- **`damage_player(… grants_invuln := false)` for ground hazards.** See graft 2.
  Live bug on `fire_fields` today.
- **The fire-field radius disagreement.** `_update_fire_fields` hardcodes `78.0`
  (`game.gd:3929`) while the renderer reads `f.get("radius", 62.0)`. Two functions
  disagreeing about one number is the failure mode that has produced three visual
  bugs; this one is live right now.
- **A named STEAM rule for the boss.** `_apply_element` sets `state = "move"`
  (`enemy.gd:402-403`), which cancels a live windup. The Boilerwright's basic
  attack is a STEAM cone on a 0.6 s period. Whatever the boss's attack becomes,
  STEAM must not be able to delete it — the rule must be written down and
  harness-checked, not discovered in a playtest.

---

## 4. Option A — SLAG MARCH

*"The Colossus stops chasing you and starts taking the deck away."*

**Pitch.** He ignores the captain entirely and walks at the Boiler on a
57-second clock, cleaving everything inside a 150° fan that out-reaches her free
Cleave — and every 150 damage you deal him, he vents molten slag onto the exact
spot you dealt it from, so the ground you are standing on to win the fight is
consumed in proportion to how hard and where you fight.

**Mechanics.**

- **He stops chasing her.** Gate `enemy.gd:212`'s `distance_to(player) < 280`
  branch on `kind != "BOSS"`. He becomes a clock: 1,965 units at 95 u/s = 20.7 s
  to the Boiler, then 26 per 1.9 s burns 500 HP in 36 s. Ignore him ~57 s and the
  run is lost. You cannot kite him; you come to him.
- **The fan is the hitbox, and it hits everything in it.** `reach: 300,
  swing: 150` on the BOSS row. Reach 300 + her body 17 = **317 against the 260
  her free Cleave reaches him from** — for the first time his swing out-ranges her
  standoff. The if/elif victim chain (`enemy.gd:266-273`) becomes independent
  `if`s: one swing hits player AND cannon AND crew AND Boiler inside the fan.
  Beat 2 adds +90 to both and drops recover 1.00 → 0.60 (cycle 1.90 → 1.50 s).
- **The dodge is angular.** At 260 out, 30° off axis, leaving a 150° fan costs
  ~45° of arc = 204 units = 0.78 s, or one dash. Directly behind him is free —
  and that pocket is what the next mechanic eats.
- **SLAG.** `vent_charge` accumulates in `take_damage`; every **150 damage** fires
  a vent at the `origin` of the blow, clamped inside `DECK_RECT` inset 40 and
  pushed ≥120 from his centre. A vent is a **0.70 s ring telegraph at radius 140**,
  then **one 34-damage circular hit at 140** (one resolve, not a tick — 0.55 s of
  i-frames makes chip nearly worthless), then **slag for 12 s** drawn with the
  existing `fire_fields` scorch+fire decal pair. 1,494 HP ≈ **10 vents**; at 61 dps
  that is a crater at her feet every 2.5 s.
- **What slag costs, per 0.5 s tick.** Player 7. Boiler 2.0. Crew 4. Cannon 3.
  **Enemies immune** — it is his furnace, and that asymmetry is what makes it
  denial rather than a gift. Radius lives in the dict, read by sim and renderer.
- **The turn stops paying her.** Delete the kill loop in `on_boss_turn`. Keep the
  1.6 s immunity, the gold ring, the banner, the roar; the boarders keep coming,
  and he lays **8 slag discs of radius 140 on a circle of radius 300, life 14 s**.
- **Two holes closed:** `if kind != "BOSS"` on the STEAM state reset, and
  `grants_invuln := false` for hazard ticks.

**Why it is scary.** Every decision costs her something. She cannot leave — he is
a countdown on the Boiler. She cannot stand at her comfortable 260. And the
harder she burns him, the faster the flanking ground she needs is consumed:
~616,000 square units of deck deleted over the fight, every unit of it at a spot
she chose to stand on.

**Kill-test — verbatim, as written.**

> Extend `tools/balance.gd` with a wave-12 boss probe. Per the variety doc's §1
> rule and the bot's own admission that it is not deterministic, **measure the
> noise floor first**: two identical replays per seed, publish the floor, file it
> in `NEEDS_ALEX.md` before a line lands. Then 8 seeds x Heat 0 and Heat 2, before
> and after. PRIMARY STATISTIC — **SFS, the slag-free standoff fraction**: sampled
> at 4 Hz through wave 12, the fraction of the annulus 210-320 units from the
> Colossus that lies inside `DECK_RECT` and is free of live slag (256 Monte-Carlo
> points per sample, drawn from an isolated stream salted off `rng` so it displaces
> no sim roll); take the median over the wave. **CUT the design if median SFS >=
> 0.80 in more than 2 of 8 seeds** — the ground never actually closes, the denial
> is decoration, and this is the flat-vs-stowed verdict again. **ALSO CUT (as
> unfair rather than scary) if median SFS <= 0.15 in more than 2 of 8** — that is a
> cage, the dodge the telegraph invites does not exist, and pillar 6 is broken.
> SECONDARY GUARDS, both must clear or the design gets exactly one retune and is
> then cut: median `tel.taken_by_wave[12]` must separate from the pre-change
> baseline by at least 1.5x the measured noise floor's 95th percentile; and median
> Boiler HP at wave-12 clear must fall by >= 40, or "he ignores you and walks at
> the ship" is a claim the simulation does not support. HARNESS CHECKS to go with
> it: `boss - the swing that connects is the wedge that was drawn` (no enemy takes
> the reach-less branch), `boss - venting the Colossus leaves rng.state untouched`
> (placement is derived from damage events, it rolls nothing), `boss - slag's
> radius is one number the sim and the renderer both read`, `boss - the turn no
> longer pays the captain for the boarders it called`.

**Cost.** Claimed 150–180 lines across `game_data.gd`, `enemy.gd`, `game.gd`,
`view3d.gd`, `tools/balance.gd`, `tests/parity_test.gd`. **Judge 2 says call it
220** and is right: "change the if/elif chain to independent ifs" does *not*
produce multi-victim swings, because `target_turret` and `target_crew` are
populated in an `else` branch and are empty whenever `targets_player` is true —
multi-victim requires rewriting the targeting block at `enemy.gd:205-228` into a
candidate gather plus a crew sweep that does not exist (only `nearest_crew` does).
The SFS Monte-Carlo probe is ~40 more lines in `balance.gd` than "the probe"
implies.

**Honest weaknesses.** As an answer to *"scary to the player"* it is a half-step —
he stops attacking her almost entirely, and its own risk 4 admits it can read as
indifference. Vents key off the damage **origin**, so a Mortar or Lance run
craters its own impact point and fights a boss on a clean deck; the wave-12 draft
decides whether the fight exists. And SFS measures the feature's own output —
slag coverage — which proves placement, not fear. It is a coverage assay, and the
design leans on its secondaries more than it admits.

---

## 5. Option B — STOKE · WASH · COOL *(recommended)*

*"The Colossus's furnace is the fight."*

**Pitch.** Stop trying to make him catch her: give him a visible furnace gauge
that fills on a clock, blows a deck-wide scalding ring at 300 units (wider than
her free-Cleave standoff of 260) and leaves fire pools behind — and make the only
way to hold that clock back the thing the pillars already want: standing close
enough to keep venting STEAM into him, and walking him onto kegs.

**Mechanics.**

- **The honest slam.** `reach 210.0`, `swing 1.745` (100°) on the BOSS row —
  deleting `_swing_hits`'s carve-out and `view3d.gd`'s `else` branch. Windup
  0.90 → 0.55, recover 1.00 → 0.45, damage 26 → 30. A fast, readable, sidesteppable
  jab: 0.55 s against 260 u/s is 143 units of lateral travel, ~34° of angular
  clearance at 210 — clearing a 100° fan needs an early step or a dash.
- **The furnace gauge.** One float, `stoke` 0..100, **+11/s** in beat 1, drawn every
  frame it is above zero as a brass arc around his feet in the existing
  `_ring_texture()` decal idiom. A mechanic with no marker is an invisible elite,
  and pillar 6 forbids it.
- **The wash.** At stoke 100 he plants: `state = "wash"`, **1.10 s** of telegraph,
  then **one circular hit at radius 300** for **30** (34 in beat 2). The telegraph is
  a circle because the hitbox is a circle: a thin static outline held at the full
  300 for the whole 1.10 s, plus a filled ring growing 40 → 300, both
  `_ring_texture()` decals, gold `#ffd36b` so it never reads as the red slam fan.
  300 is load-bearing — her free Cleave reaches him at 260, so the standoff that
  makes him a free pressure battery is *inside* the wash. Answers she already owns:
  back out past 300 and stop dealing damage, dash through (265 units of i-frames,
  2 charges, so it costs tempo), or eat it.
- **The wash lights the deck.** Four fire fields via the existing `_field()` call
  (`game.gd:3893`) at radius ~270 on the quadrant diagonals off his facing —
  four visible gaps — plus `light_fuse()` on every keg inside 300.
- **Cooling, and it is the point.** **STEAM on the Colossus drains 12 stoke**, at
  most once per 1.2 s. Two universal sources: her pressure vent (`game.gd:3598`
  already applies STEAM at radius 200) and any keg. A keg within 260 drains **40**
  and staggers 1.2 s. So the fastest way to hold the wash back is to be inside 200
  of him — inside his 227-unit slam.
- **A wash once begun cannot be stopped.** `_apply_element("STEAM")` must not
  reset `state == "wash"`, or her auto-venting gauge deletes the mechanic. STEAM
  still cancels the slam. Named rule, named check.
- **The turn stops paying her — he DRINKS them.** Silent removal, no
  `on_enemy_killed` rewards, **+8 stoke each capped at +40**. Banner "IT DRINKS
  THEM". Clearing the adds before 50% becomes a plannable decision.
- **Beat 2 is the furnace, not one number.** Drop `attack_range += 90`. Stoke rate
  ×1.6 (a wash every ~5.7 s unvented against ~9 s), wash radius 300 → 380, damage 34,
  5 pools, cooling halved, fan 100° → 130° at reach 260. Every one of those the
  picture shows.
- **Untouched on purpose:** hp 900, the 1 + 0.06×(wave−1) scaling, speed 95,
  mass 24, the lane clamp, the 1.6 s turn immunity.

**Why it is scary.** Ignoring him has a price that arrives on a clock she can
see. The gauge fills whether she is winning or not, and the only lever on it is
standing inside the reach of a machine that hits for 30. Backing off is safe and
loses; going in is terrifying and works.

**Kill-test — verbatim, as written.**

> Run `tools/balance.gd` headless, 6 seeds × Heat 0 and Heat 2, furnace ON vs a
> forced-OFF build (stoke rate 0, wash disabled, turn payout restored) — after
> first measuring the replay noise floor from two identical replays per seed and
> filing the threshold in `NEEDS_ALEX.md`, per ENEMY-VARIETY §1. TWO statistics,
> both required. (1) DAMAGE: median player damage taken during wave 12 must rise
> by ≥40 points (40% of a 100-HP captain) beyond the noise floor. (2) BEHAVIOUR:
> the median fraction of wave-12 time the bot spends within 300 units of the
> Colossus must fall by ≥15 percentage points, AND median wave-12 duration must
> move beyond the floor. If (1) passes and (2) does not, the furnace is a damage
> tax wearing a ring decal — it moved the health bar without moving the player —
> and it is CUT by the §2.3 standard, not tuned. Guard rail in the other
> direction: if median wave-12 damage taken rises by >120 (an unavoidable kill on a
> fresh captain) it gets exactly ONE tuning pass on wash damage and stoke rate; if
> it cannot be brought inside the 40–120 band while (2) still passes, it is cut and
> the distribution is printed as the reason.

**This kill-test cannot fire as written** — see §2. Statistic (2) is replaced by
the amended (2) before any line lands. That replacement is itself a
pre-commitment: it goes in `NEEDS_ALEX.md` with the noise floor, before the work.

**Cost.** The most new machinery of the three: one enemy state, `stoke` and
`cool_cooldown`, a `_boss_wash()` built from `_field()` + `light_fuse()` + one
distance test, a brass gauge arc, an `on_boss_turn` rewrite, two fields on one
row, ~30 lines in `view3d.gd`. Seven harness rows: `boss · the slam's hitbox is
the wedge that was drawn`, `boss · the wash connects exactly where the ring was
drawn`, `boss · a wash once begun cannot be cancelled by STEAM`, `boss · STEAM
cools the furnace, and a keg cools it more`, `boss · the turn pays the player
nothing — no pressure, no dash, no scrap, no crew`, `boss · absorbed boarders show
on the gauge`, `boss · the furnace is drawn whenever it is above zero`. Each proven
to bite by reverting the line it guards.

**Honest weaknesses.** `light_fuse()` is real (`prop.gd:111`) and props restow each
wave, so the keg lever exists — but the claim that wave 12 "guarantees 3 kegs
inside lane 1's ±120 band" is **not verifiable**: keg placement is a
clearance-search over the layout, not an authored guarantee. Either it is authored
or the claim comes out. STEAM builds get a discount on the encounter the run ends
with. And the vent auto-fires at 100 pressure — the player never presses "cool", so
the decision is positional, not a button, and she may never learn *why* the gauge
slowed. The gauge visibly ticking backward on a vent has to carry that read; it is
a legibility item to watch in playtest, not to assume.

---

## 6. Option C — THE FURNACE MARCH

*"He burns the deck he crosses, and the fire is the clock on the ship."*

**Pitch.** He stops being a slow melee you out-walk and becomes a walking furnace
that converts deck into denied ground — his wake, his whiffed swings and the seven
boarders he consumes at the turn all leave fire on the planking, and in beat two
he abandons the player, breaks his lane clamp and marches at the Boiler, so kiting
him now costs the ship.

**Mechanics.**

- `reach: 330`, `swing: 150`, `attack_range` 120 → 260, windup 0.90 → 0.70, recover
  1.00 → 0.60. Trips at 277 — exactly the standoff her free Cleave reaches him from
  — connects to 347, cycle 1.30 s for 26 = **20.0 dps**, above the furnace knight's
  17.9. A straight sprint back from 277 clears 347 in the 0.70 s wind (182 units),
  so the dodge is disengage-or-dash; the 150° fan means sidestepping no longer
  clears it.
- **CINDER WAKE.** While `state == "move"`, `game._field({radius: 78, time: 6.0,
  tick: 0.25, boss: true})` every 1.2 s in beat 1, 0.7 s in beat 2 — at 95 u/s a
  stamp every 114 units against a 156-unit-wide field, a near-continuous burning
  corridor down the middle column he is clamped inside.
- **The whiff is the arena change.** On resolve, hit *or* miss, three more fields at
  `reach × 0.62` (~205) at −55/0/+55° off `attack_direction`, life 5.0 s, all strictly
  inside the wedge that was drawn.
- **`_update_fire_fields` grows one branch.** `boss: true` skips the enemy pass
  entirely (his fire is his), ticks **5.0** on the player instead of 3.0 (**20 dps**),
  and within `boiler_radius + 78` calls `damage_boiler(1.5)` per tick — 6 dps on the
  ship, 36 HP per full field. Hard cap 14 live boss fields, oldest evicted.
- **The turn feeds the deck.** A `consumed` flag suppresses every payout in
  `on_enemy_killed`, and one 8-second field drops at each consumed body across all
  three lanes. Banner `IT STOKES THE FIRES`.
- **Beat 2 is a march on the ship.** Movement target unconditionally
  `boiler_position`; walk speed ×1.58 (95 → 150); the lane clamp released via the
  ignore-lane argument `correct_enemy_position` already takes. He is still 150
  against her 260 — she can out-walk him, she just cannot out-walk him and win.
- **Body-blocking has a price**: in beat 2 the swing tests the player first when
  she is inside the fan, and `attack_direction` is locked at the Boiler, so the
  wedge on the planking is exactly the ground between him and the ship.
- **Renderer:** ~10 lines, `boss: true` fields draw the shipped fire vocabulary in
  the hostile `TG_DANGER` family with a hard rim at exactly 78.

**Kill-test — verbatim, as written.**

> `tools/balance.gd`, 6 seeds x 3 replays, Heat 0, wave 12 isolated, before-tree vs
> after-tree from pristine `git archive` extracts (the SG-94 discipline). The replay
> noise floor is measured FIRST from two identical replays per seed and filed in
> `NEEDS_ALEX.md` before a line of this lands (ENEMY-VARIETY §1's rule). CUT if ANY
> of these four fire. (1) **Median wave-12 player damage taken** does not rise by
> more than 2x the noise floor — the fight is still a kite and the hazards are
> scenery. (2) **Boss swing-connect rate on the player** (swings that hit her /
> swings resolved with her inside the drawn fan) is a TWO-SIDED gate: below 0.25 the
> geometry still whiffs and the reach numbers failed; above 0.70 it cannot be dodged
> and this is the furnace knight in a new coat — the top end cuts the numbers, not
> the concept, and the reach/windup go back for one pass only. (3) **Median Boiler
> HP lost during wave 12 < 60 of 500** (baseline is ~0): the "Boiler under direct
> threat" claim is false and beat 2's march reverts to today's `attack_range += 90`.
> (4) **Earth-mover distance between the player's wave-12 time-in-cell histograms**
> (60-unit cells over `DECK_RECT`, normalised) before vs after is under 3x the same
> statistic's own noise-floor EMD: she is standing where she always stood, the
> ground was never actually denied, and the CINDER WAKE half is cut even if 1-3 all
> pass. Statistics 2 and 4 are the load-bearing ones because neither needs the bot
> to kite like a human. Guard rail, not a cut: if bot loss rate on wave 12 exceeds
> 60% this is a Heat rung wearing a design's clothes and the damage numbers come
> down before anything else is judged.

**This kill-test does not hold either, and worse than Option B's.** Statistic (4)
is zero by construction against an immobile bot in both arms, and it is wired to
cut CINDER WAKE even if 1–3 pass. Statistic (2) saturates near 1.0 against a
stationary player and trips its own >0.70 unfair gate every run. Both are declared
load-bearing. Statistic (3) is sound. If this option is chosen, (2) becomes a
harness geometry assertion and (4) is replaced by a hand-played judgement.

**Cost.** Cheapest of the three by a clear margin: ~40 lines in `enemy.gd`, ~30 in
`game.gd`, ~10 in `view3d.gd`, six numbers on one row, and the clamp release rides
an argument that already exists.

**Honest weaknesses.** Fairness is the worst of the three: 20 dps boss fire is
nearly double the player's own, laid by a **wake with no per-field telegraph** — the
ground turns lethal by his walking rather than by a picture, which is pillar 6
spent for atmosphere when pillar 6 outranks atmosphere. Fourteen hostile-tinted
fields under three lanes of telegraph runes is the exact trade DECK-IDENTITY §1.5
says loses. It is also the only proposal that **declines to decide the STEAM
question** ("either… or the counter is knowingly accepted") — a 0.6 s Boilerwright
cone against a 0.70 s windup deletes every slam it is built on, and leaving that
open is the "claims asserted from memory" failure mode booked in advance. Beat 2
is a 70-radius, mass-24 body's first ride on the ignore-lane branch. And
`damage_boiler` from a 4 Hz tick spams `boiler_hurt.ogg` and a burst FX per tick,
not merely the low-boiler latch it flags.

---

## 7. Where the panel disagreed

Disagreement is information; none of this is smoothed over.

- **They split on the winner, 1–1.** Judge 1 chose STOKE·WASH·COOL (fear 8,
  fairness 9, fit 9, cost 8) on the grounds that it is the only design that makes
  the *player* afraid. Judge 2 chose SLAG MARCH (fear 9, fairness 8, fit 8,
  cost 6) on the grounds that it is the only design whose kill-test can actually
  fire. Both critiques are correct and they are about different things: one is
  about the fiction, the other about the evidence. The recommendation takes
  judge 1's design and judge 2's evidence.
- **They disagreed about cost by nearly a factor of two, in opposite directions.**
  Judge 1 scored STOKE·WASH·COOL cost 8 and FURNACE MARCH cost 6; judge 2 scored
  them 5 and 8. Judge 2 counted the new state, the gauge, the wash resolver and
  the keg coupling and called STOKE "more than days"; judge 1 counted only the
  reused decal idioms. On the evidence in the files, **judge 2 is closer** —
  STOKE·WASH·COOL is the most new machinery of the three and FURNACE MARCH is
  genuinely the cheapest.
- **They disagreed about the worst idea.** Judge 1 named SLAG MARCH's turn crown
  (a design mistake). Judge 2 named STOKE·WASH·COOL's un-fireable behaviour
  statistic (a method mistake) and called FURNACE MARCH's EMD the same error at
  lower stakes. Both are listed in §8.
- **They agreed, unprompted and separately, on two grafts**: the `grants_invuln`
  inversion and the `kind != "BOSS"` chase gate. When two independent readers
  converge on the same two lines, those two lines are the real finding.
- **Neither judge trusts `balance.gd` to see this fight.** Judge 1 says the
  dodgeability half is a hands-on judgement and must not be smuggled into bot
  numbers; judge 2 says three of the six declared statistics across the batch are
  pinned by an immobile bot. Read together: **the bot can measure damage, Boiler
  HP and geometry, and it cannot measure kiting.** Every statistic below the line
  is written to that limit, and the dodgeability verdict goes to the owner's eye
  with frames.

---

## 8. What we are deliberately NOT doing

- **SLAG MARCH's turn crown** — eight slag discs at radius 300 for 14 seconds,
  laid so the captain cannot use her free Cleave on the boss at all without
  standing in fire. Judge 1's named worst idea, and correctly: that is not fear,
  it is fourteen seconds where the right play is to walk away and press nothing.
  It lands hardest on the melee draft that has no alternative while a Lance build
  ignores it. Removing the player's basic attack is the one escalation that reads
  as arbitrary rather than earned.
- **Any kill-test statistic that requires the bot to move.** Judge 2's named
  worst idea. STOKE's required statistic (2) and FURNACE's EMD (4) both cut a
  design on evidence the harness cannot gather. Pre-commitment only means
  something if the measurement can come back either way.
- **A stat nudge.** More HP, more damage, more speed. SG-96's own wording rules it
  out, and §1 shows why: the problem is the cycle and the range, not the numbers
  on the bar.
- **A second special-case telegraph.** The shape lie is fixed by *deleting* the
  reach-less branch, not by adding a matching carve-out. After this no enemy takes
  that path, and the false comment about the phase ring goes with it.
- **Summons, adds, or a new mesh.** Nothing in the codebase makes the Colossus
  spawn anything and none of the three options adds it. Zero new art, zero new
  models, zero new animation clips, across all three. The boss kit's five clips
  (`idle`, `walk`, `swing`, `turn`, `die`) all still map.
- **Keeping the turn's payout.** All three delete it, and it should be run as its
  own arm in the kill-test so the damage-taken movement is separable from the
  design's own effect. Suppressing +63 pressure, seven dash refunds, scrap heals
  and press-gang crew is a real removal of wave-12 income the rest of the wave was
  tuned against.
- **Leaving the STEAM interaction undecided.** See §3.
- **Softening the boss if Heat 2 spikes.** If wave-12 damage taken more than
  triples at Heat 2, the honest answer is to move the wave-12 SCRAPPER batch.
  Difficulty is Heat's job (ENEMY-VARIETY §1); it is not the boss's job to
  compensate for a rung.

---

## 9. Build order, and what each option needs from Alex first

**Before any line of any option lands** — this is the ENEMY-VARIETY §1 rule and
the STATUS "a measuring rig nobody measured" rule together:

0. Measure `balance.gd`'s replay noise floor for wave 12 (two identical replays
   per seed, 6–8 seeds, Heat 0 and Heat 2) and **file it in `NEEDS_ALEX.md`
   with the chosen thresholds.** Photograph nothing and claim nothing until the
   floor is on paper. Note that `balance.gd` issues no movement input; if that is
   ever fixed, several of the statistics above become usable and the file should
   say so.

**If Option B (recommended):**

1. The three universal fixes (§3) as one commit, with their harness rows —
   `reach`/`swing` on the BOSS row, `grants_invuln`, the fire-field radius, the
   STEAM rule. This is the shape-lie fix and two live bugs; it is worth landing
   even if the boss work then stalls.
2. The chase gate (`kind != "BOSS"`) alone, measured alone. This is the root fix
   and its effect must be separable from the furnace's.
3. `stoke`, the gauge decal, and the wash — sim and renderer reading one radius
   from one place, with the static outline at the full radius held for the whole
   1.10 s.
4. Cooling: the 1.2 s drain, the vent path, the keg path.
5. `on_boss_turn` rewrite (DRINKS, +8 capped at +40, no payouts) and beat 2.
6. Seven harness rows, each proven to bite by reverting the line it guards. Motion
   evidence re-filmed through `tools/boss_shot.gd` (which walks him in on his own
   AI) and `tools/still.gd` for every frozen plate.
7. Run the amended kill-test. Publish the distribution, not the verdict.

**Decisions only Alex can make, per option:**

| | Needs from him |
|---|---|
| **All three** | Which option. Sign-off on the noise floor and thresholds in `NEEDS_ALEX.md` before work starts. Whether wave 12's SCRAPPER batch may move if Heat 2 spikes. Banner text and one voice line for the changed turn. |
| **A — SLAG MARCH** | Whether "he ignores you" is acceptable as the emotional answer to "scary to the player" — its own author flags that it can read as indifference. Whether the vent should key off the damage origin (ranged builds farm a clean deck) or the player's position. |
| **B — STOKE·WASH·COOL** | **Whether keg placement at wave 12 is authored or left to the clearance search.** The design's central lever assumes ~3 kegs inside the ±120 band and the layout does not guarantee it — either he blesses an authored placement or the keg cooler is downgraded to a bonus. Also: is a passive auto-vent an acceptable "cool" input, or does the captain need a button? |
| **C — FURNACE MARCH** | A ruling on fire density versus pillar 6 — 14 hostile-tinted fields under three lanes of runes is the DECK-IDENTITY §1.5 trade, and if the `rig_probe.gd` 3%-edge-contrast gate fires, the fill goes to near-zero and the design leans entirely on the rim. He should see one posed frame of that before it is built, not after. |

**Art, models, animation: none, for any of the three.** The only new assets any
option could want are audio — one cue for the wash or the vent — and that is a
nice-to-have, not a blocker.
