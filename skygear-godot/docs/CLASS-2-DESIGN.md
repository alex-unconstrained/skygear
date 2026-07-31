# The second class — the Boilerwright

Status: **BUILT AND COMPLETE.** Head, Tap Main, Blowdown, Bleed Jet, Scald,
Overpressure, the no-dash body, the per-class draft weighting, the Anchored
resist, kills extending a main, the crew haste inside one and the third deck
vent are all in and covered by the harness.

Two things §3 describes that are deliberately NOT built, and are not oversights:

- **Head does not cost Boiler HP.** §2 charges 0.6 Boiler HP per point past a
  40-per-wave allowance. The allowance, the meter and the per-wave reset are
  three pieces of bookkeeping for a cost the player pays at the moment they are
  least able to read a new number, and Blowdown's repair rate already encodes
  the loss the charge was there to guarantee. If the Boiler tap turns out to be
  the dominant fill in play, this is the first thing to add back.
- **No per-class card weighting.** The SHAPES are weighted; the 41 cards are not.
  A card table that offers differently per class is a second table to balance,
  and the shape bias already steers the build.

Everything below is the reasoning, unchanged. Where the build disagrees with it,
the build is the newer decision and the difference is commented at the code.

## 0. The question this class answers

The captain's question is **"how long can you stand in it?"** Her gauge fills from
damage landed inside 210 units and from being crowded, and v11 exists because the
answer used to be "you don't have to" — range-kiting healed faster than three lanes
could hurt you. A class that fires further is not a second question, it is the answer
v11 deleted. So: **"where will the fight happen, and did you get there first?"** His
power is a function of the ground he prepared, not of his distance to a boarder.

Rejected first: a ranged mirror (above); a turret-placer (SENTRY is already a shape,
so the fantasy is spoken for at the draft layer, and installations that kill for you
play themselves); a hard tether to the Boiler (any leash short enough to constrain
you at the bow forbids the bow, and waves 4 and 8 are at the bow — a leash is a
fence, not a loop); and any new shape kind, since every new kind is renderer and VFX
work. Zero added.

## 1. The fantasy, in two sentences

He built the Boiler, has kept it lit for thirty years, and is the only one aboard who
knows exactly what it will cost to keep it lit tonight. He fights by cracking the
ship's own steam mains open into the boarders' faces, so everything he throws is
borrowed from the thing he is defending.

## 2. The core loop and its resource

**Head** (as in a head of steam), 0–100, replaces pressure. Same widget, opposite
polarity: hers fills by itself when the fight goes well and discharges automatically;
his fills only where he plants himself, never decays, and never spends itself.

**Builds — three taps, nothing else. Standing still is the condition on all three.**

| Source | Rate | Cost |
|---|---|---|
| The Boiler, standing on it | 45/s | free for the first 40 Head each wave, then **0.6 Boiler HP per point** |
| Deck vents (3, one per lane — already props) | 18/s | free, unlimited, slow |
| **Tap Main**, cracked open anywhere | 26/s for 8s | 18 Head to open, 6s cooldown |

**Spends — four sinks, so the gauge is a decision every second.** Three are abilities
(§3); the fourth is **Overpressure**: while Head > 0 every drafted skill deals +45% and
applies its element at double duration, at 10 Head a cast. At zero he is base damage,
no dash, 205 speed — an empty Boilerwright is *strictly worse at kiting than the
captain*. The anti-kite argument is structural, not a number.

**The cap is load-bearing.** A Tap Main pays 208 Head over its life and the gauge holds
100, so you cannot fill up and leave — you spend while holding ground, which is the
behaviour the class is for.

**The failure state, named.** Hers was healing faster than three lanes can hurt you.
His is **repairing the Boiler faster than three lanes can break it** — an objective
you can top up indefinitely is unlosable and the game is a formality. Three guards,
in order of how much work they do:

1. **The exchange rate is a loss by construction.** The Boiler charges 0.6 HP per
   Head past allowance; Blowdown repairs 0.35 HP per Head. Boiler → Head → Boiler is
   a 42% loss. *You cannot repair the ship with the ship.* Net-positive requires
   being out on the deck at a vent or a main you opened — exactly the position the
   class exists to make you take.
2. **A repair budget** structurally identical to `heal_budget`: 10 HP/s, refilling,
   every source on the same ceiling, because capping the sum is the version that
   never needs re-tuning when a card is added.
3. **No card may move either number.** Cards raise the allowance and the radius; the
   0.6, the 0.35 and the 10/s are fixed, written down here because the first person
   to add a repair card will want to move them.

No vent heal, no lifesteal, salvage only: she keeps herself alive, he keeps the ship alive.

## 3. Abilities

Four drafted slots on LMB/RMB/Q/E from the same 36-cell matrix, unchanged — pillar 3 is
not negotiable. Two new keybinds carry the class instead.

| Ability | Fits the matrix? |
|---|---|
| **Scald** — fixed auto-attack, CONE × STEAM, range 210, arc 1.134, 18 dmg, 0.6s. Replaces Ember Cleave. | **Yes.** Pure data, an entry beside `STARTING_SKILLS`. |
| **Four drafted skills** — as hers, with a per-class weighting over `shape_order` favouring RANGED_AOE / AURA / PULSE / CONE and starving RAY / LINE_BURST. | **Yes.** A weight table plus ~10 lines in `open_draft`. |
| **Tap Main** (`F`) — plant a live main at your feet: 130 radius, 8s, 6 STEAM dmg/s inside, 26 Head/s while you stand in it. Kills inside extend it 0.6s. Crew inside swing 30% faster. | **No.** New machinery, but a `taps` array with the exact shape of `fire_fields`, ticking `_damage_circle`. |
| **Blowdown** (`V`) — spend the gauge, min 20. Damage 0.9 × Head, radius 120 + 1.6 × Head, STEAM, knock 300; repairs 0.35 × Head to a Boiler or live cannon inside. Must call `hulk_splash` or push waves are unwinnable. | **No,** but it is `vent_pressure()` with the constants replaced by functions of Head, reusing the existing scaled `circle` effect. |
| **Bleed Jet** (dash key) — 220 units over 0.16s for 12 Head, leaving five scald fields behind. **Anchored**, its passive counterpart: inside any live tap he is knockback immune with 25% DR. | **No,** but it is `_try_dash` with a cost and a call to `_field`; Anchored is two lines. |

The last three rows are where it does not fit. None is a *shape*: nothing here enters
the draft matrix, the 36 cells stay 36, no new VFX kind appears, and Tap Main is the
only new simulation object — itself a copy of one that ships.

## 4. Movement and positioning

She has two recharging dashes with contact damage and a refund on close kills: fast,
evasive, her correct position defined *relative to boarders* — it moves, she chases.

He has **no dash**, moves at 205 against her 260, and carries 130 max HP. His
reposition is Bleed Jet, which costs Head, so **every dodge is damage he did not
do** — the opposite of a free recharging charge, and at zero Head he cannot dodge at
all. That is the sharpest thing about him and also the second-order risk (§8); the
25% anchored DR and the extra 30 HP are the compensation. His position is defined
*relative to the deck*, which does not move: **behind his hazard, between it and the
Boiler**, shepherding boarders back in with Steam knockback. She pulls enemies toward
her; he pushes them away and up the lane. Delay is the win condition.

The best free idea here is geography: **the cargo runs gap at roughly y = −470,
y = +15 and y = +515**, so a tap in a cross-passage covers two lanes at once and the
y = +515 gap sits on the cannon line — learning those three numbers *is* learning the
class. `PROP_LAYOUT` has vents at (−680, 620) and (700, 120), lanes 0 and 2, none in
lane 1; it needs a third, which is one line of data.

## 5. The twelve waves

- **1–3.** Thin crowds, one lane at a time. He is weak here and knows it; the
  allowance is generous against a 500 HP Boiler and the commute is cheap. This is
  where he learns where the three vents are, which the rest of the run runs on.
- **4 and 8, the pushes.** His hardest content and his best fantasy. The hulk sits at
  y = −1000, 1850 from the Boiler, and a push does not end until it breaks. The
  intended play is a forward main at the bow, held; the crew-speed bonus inside a tap
  means his installation is what breaks the hulk while he holds the lane. He is the
  only class with a reason to care the crew layer exists.
- **5–7, ARMORED.** Mass 2.6 halves his knockback and slow boarders walk through
  hazards instead of being herded into them. Blowdown is the answer, and this is the
  first band where banking the gauge and running Overpressure genuinely conflict.
- **9–11.** Two and three lanes live at once and he cannot be in two places. Concede
  one to the cannon and the crew; hold the cross-passage covering the other two.
- **12, the Colossus — the same fight read inverted.** For her the 1.6s turn is a
  breather. For him it is **the window**: `take_damage` returns 0 through it and
  `on_boss_turn` clears the adds, so it is 1.6s to lay a main and charge to full
  under its nose. Then beat two adds +90 attack range, which punishes an anchored man
  precisely — the boss taking away the position he spent the turn building. Mass 24
  puts shepherding off the table and it becomes a draw-and-dump race against 900 HP.
  **The boss code is unchanged:** a second boss fight for nothing, because the class
  reads the existing one differently.

## 6. Draft interaction

**Alive — 25 of 41:** all 10 SCOPE_SKILL, all 8 SCOPE_ELEMENT, all 4 SCOPE_ALL,
SCOPE_META, SCOPE_DECK (kegs are a Head source, so POWDER MONKEY gets *better*), and
SCOPE_SHIP. Several are *better* than for her: `knock` and `scald` go from filler to
core because shepherding is his verb, `residue` is a zone card on a zone class,
`boilerhp`/`boilerdr` become build pieces, and Frost improves because a slowed
boarder stays in a field.

**Dead — eight, all SCOPE_CAPTAIN:** `dashcd`, `dashchg`, `dashdmg` (no dash);
`ventheal`, `ventdmg`, `pressrate`, `dressing` (all read `pressure`); `lifesteal`
("inside your own reach" is her spatial rule). Survivors: `hp`, `spd`, `crit`,
`critx`, `scrap`. The gate exists already — each card carries a `can` predicate, so
eight gain `and g.hero == "captain"` and `SCOPE_LABEL[SCOPE_CAPTAIN]` becomes
per-class text. `fresh_mods()` keeps the dash keys; an unused mod costs nothing and
removing them breaks her. Six new:

| Card | Scope | Effect |
|---|---|---|
| LONG HOSE | captain | Tap Main lasts 4s longer. |
| BLEED VALVE | captain | Bleed Jet costs 40% less; its trail burns 50% harder. |
| SECOND MAIN | captain, epic | Two taps open at once. |
| REGULATOR | ship | The Boiler's free allowance is 70 a wave, up from 40. *Allowance, never the exchange rate.* |
| CROSS-BRACE | ship | Blowdown's repair radius +60%, reaching cannons at any health. *Radius, never the 0.35, never the budget.* |
| SUPERHEAT | all, epic | Above 70 Head, Overpressure is +90% instead of +45%. |

## 7. What it costs to build

| Item | Kind | Note |
|---|---|---|
| Head, tap/spend, Overpressure, Bleed Jet (`player.gd`) | simulation | ~140 lines; mirrors `_update_pressure` and `_try_dash` |
| `taps` array, tick, expiry, crew bonus | simulation | copy of `fire_fields`; pool capped, per the standing rule |
| Blowdown, repair, `repair_budget`, and `draw_from_boiler()` as a path distinct from `damage_boiler` | simulation | scaled `vent_pressure()` plus `hulk_splash`; the draw must **not** be reduced by `boilerdr` and must not fire the hurt SFX or the boiler-low voice line |
| Scald, shape weights, third deck vent, all tuning | data | `game_data.gd` only |
| 8 `can` gates, 6 cards, per-class scope label | data + small sim | `cards.gd` |
| Class select, `game.hero`, Head gauge, tap-share in the report and run log | simulation + HUD | re-skin of the pressure gauge, one icon via `tools/forge.py` |
| Tap ring, steam column, Blowdown ring | renderer/VFX | **all three exist** — Decal ring (§13e), `steam` behaviour emitter (§13m). No new VFX kind. |
| **Rigged character** (idle, walk, run, two attacks, flinch) + portrait | **art, commissioned** | Mixamo-shaped; `tools/ingest_model.py` makes ingest a `models.json` edit, portrait via `tools/forge.py` |
| **A plant / kneel-to-deck clip** | **art, commissioned** | the one clip with no off-the-shelf equivalent. Tap Main is his signature; without it he teleports mains into existence. |
| **A hose or wrench mesh on a hand bone** | **art, commissioned** | §13l already records that the axe pack ships no axe. Second instance — solve the attachment once, for both. |
| Voice, 19 keys | audio, **deferrable** | policy is that an absent line is silence, never a synth impression. He can ship mute and it is not a bug. |

Checks: Head rises only on a tap and only while stationary; a draw past allowance cuts
`boiler_hp` and is not reduced by `boilerdr`; Boiler → Head → repair is net-negative
for **every** card combination in the catalogue; repair respects its budget; Blowdown
at zero does nothing and Blowdown splashes the hulk; taps expire and their pool is
capped; the dash action is inert and the dash cards never offered; a seed deals him
the same hand twice.

## 8. The one risk, and the cheapest test

**The commute is the game.** The failure is not that he is weak — it is that a wave is
twenty-five seconds of walking to a tap, standing on it and walking back, and walking
is not gameplay. Everything above is arranged against it (the cap forces spending
while you hold; three free vents; a portable main), but arrangement is not evidence.

**Test it without building the class.** No model, no `cards.gd`, no Blowdown: take the
captain as she is, add one float, and change three things in `game.gd` — damage ×1.0
at zero Head and ×1.45 above it at 10 a cast; Head fills only while stationary within
130 units of the Boiler or a vent; `_try_dash` returns immediately. An afternoon, no
art, no draft work, no new VFX. Play waves 1, 4 and 9.

**Then instrument the number rather than trusting the feeling.** `note_range` already
buckets time by distance to the nearest boarder and `_close_share()` reduces a run to
the one number that says whether her loop landed. His equivalent is **seconds with
Head at zero and no boarder within 400 units** — walking, useless, not yet anywhere.
Above 10% of wave time and the geography is wrong, which is a data fix (more taps,
longer taps, a cheaper main) made before anything expensive has been ordered.
