# NEEDS ALEX — the morning list

_Written 2026-08-02 as you went to sleep; rewritten through the night as the
detail outgrew it. **Build 58 is live**, harness **997/997**. Evidence for
everything below is in `skygear-godot/docs/NIGHT-LOG-2026-08-03.md` — this file
is only what needs you._

> **The one thing to know before you play: fire is no longer a shield.** A
> hazard tick used to buy 0.55 s of *global* i-frames every 0.75 s, so standing
> in a fire pool made you immune to **everything**, a boarder's swing included,
> about 73% of the time. Measured directly: a captain swung at every 1.5 s for a
> minute took **700 damage standing in the fire and 1014 standing clear** — the
> pool was a 31% damage *shield*. It costs **1440** now. If a fight suddenly
> feels heavier, that is the game working rather than the game changing, and no
> tuning value was touched to get there.
>
> **Second thing, and it reaches backwards: do not trust any balance number in
> this repository that predates last night** — including ones I have shown you.
> `tools/balance.gd` never moved its bot while a comment in it claimed it did,
> so every simulated-run verdict was measured against a captain standing on her
> spawn point. The instruments have been repaired and the affected verdicts
> re-measured; two did not survive, one of which I had reported to you as
> settled. **One question that was waiting on your threshold has evaporated
> entirely.** The night log has all of it.

Everything here is either **a decision only you can make** or **a verdict only
your eyes can give**. Nothing in it blocks the loop — there is plenty to do
without any of it.

---

## 1 · Play build 58 and judge ten things

All shipped tonight; none can be settled by a checker.

| | The question |
|---|---|
| **The furnace knight** | Its telegraph drew a 120° wedge while its hit test was a full **circle** — sidestepping the flank, the exact move the picture invites, never worked. Now gated on arc. **Is 0.90s readable with gremlins on you? Does 34 damage feel like a mistake you made?** |
| **The deck marks** | Scorch and blood accumulate where things actually happened. My kill-test threshold was wrong, the rig built to replace it answered non-proportionally, so the agent took the cautious branch — half the cap, alpha 0.30 → 0.12 — and refused to quote the flattering number. **Too subtle now, or too much?** |
| **The crew** | 144 units (12.5% smaller) and they turn to face what they fight. **Right size? Right rule?** — see the strafe question below. |
| **Enemy bolts** | 2.3× smaller, now the browser's own radius. **Too far?** |
| **The cargo is cargo now** | Your "still 2D sprites" note. The eight cargo runs were a picture stamped on their **lids** — a side-on cut-out projected straight down, which at 41° is most of what you see. They are 120 real crate meshes now, one draw call. **The boarding hulk was also 39% oversized** — drawn 528 wide against its own 380 hull, in a 440 lane. Fixed to 380. **Does the deck read solid now?** |
| **They jump off the ship** | Your ask, complete. A transport pulls up, boarders leap from it and land on a closing ring, immune the whole way down and dangerous the moment they touch. **The honest limit:** the transport holds 3,000 units off the bow, so most of the crossing is off-frame — what you actually see is the last third, a figure appearing high near the bow and dropping onto its mark. **Does it read as arriving, or as appearing?** |
| **Fire's hitbox** | **The fire you can see is not the fire that burns you.** The renderer sizes flames, scorch and the burn mark from a `radius` the damage ignores: a scald trail is *drawn* at 46 and *burns* at 78; a lantern 62 against 78. So a pool burns you from outside its own picture, by up to 70%. Filed as SG-121 and **deliberately not fixed** — wiring the damage to the picture moves three hitboxes, deleting the field changes every drawn fire, and both are balance changes you should choose. It matters more since last night: fire stopped granting immunity and now delivers its authored rate. **Play it and say which way it should go.** |
| **The knight's furnace** | It burns now. His emission map was effectively **empty** — 0.15% non-black — so every `emission_energy` he was ever given multiplied nothing, which is why the earlier "raise the emission" attempts measured as no-ops. The map is authored from his own albedo, no Meshy credits spent. Molten fraction **0.19% → 0.62%**, deliberately under his painting's 1.12%: pushed further the furnace goes white and the lit count *falls*. **Does he read as lit from inside now?** |
| **The deck's new light** | A cool rim light from the bow, added overnight. The furnace knight measured **15% darker than the planking he stands on** — a warm brown figure on warm brown boards, because the deck had a key and a fill and no rim. He is now marginally brighter than his floor. **It is deck-wide, so the crates and rigging gained edges too.** Frames: `.shots/sg86/full-before-after.png`. **Does the deck look better, or just different?** |
| **The HUD cluster** | Bottom-left rebuilt on the Supervive lessons. **Does the direction feel right before it spreads to the hand and the lane readout?** |

---

## 2 · Ten decisions

1. **The Colossus: you asked for more HP, here is what it bought (SG-146).**
   Done — `hp` 900 → **2900**, picked by measurement, not feel. **One number to
   choose and one caveat to judge with your hands.**

   Wave-12 segment, Heat 0, `tools/boss_probe.gd`, n = 211 / 160 / 332 runs that
   reached wave 12:

   | | time to kill him | damage he deals you | runs you hold |
   |---|---|---|---|
   | hp 900 (build 53) | 9.7 s | 29.9 | 100% |
   | hp 1800 | 16.0 s | 83.4 | 92% |
   | **hp 2900 — shipped** | **23.8 s** | **123.4** | **66%** |

   **THE DECISION: 2900 or 1800.** 2900 is what "a lot more" honestly looks
   like; it also costs 34 points of hold-rate at Heat 0, and I have not softened
   anything to hide that. **1800 keeps most of the menace for 8 points.** One
   word in `game_data.gd` either way — say which and I will move it.

   **THE CAVEAT, and it is the one thing only you can settle.** His second-beat
   swing reaches **253 units**; my bot orbits at **210**, so it stands inside his
   reach and eats nearly everything. A player who backs out during beat 2 will
   take far less than 123. **So: does he feel dangerous, or does he feel like a
   long health bar?** If the latter, the honest fix is his *reach and cycle*, not
   more health again.

   **And one thing I built, measured, and did NOT ship on.** COLOSSUS-DESIGN's
   recommended root fix — he stops chasing you and walks the lane at the ship —
   is in the code behind `COLOSSUS_WALKS_THE_LANE`, defaulted **off**. It failed
   the kill-test the design wrote for itself in advance: the Boiler was supposed
   to start losing ≥40 HP a wave and it moved 9.5 → 11.3 (nothing), while he went
   from hitting you for 123 to hitting you for **exactly zero, in all 214 runs**.
   He can't reach the Boiler in time and he can't touch you on the way. The
   design's own rule for that result is *cut, not tune*. Flip the constant if you
   want to see it. Full numbers: `docs/COLOSSUS-DESIGN.md` §1a.

   **Also, §1 of that design doc was half wrong and §1a now says so.** It argued
   his swing "geometrically cannot land" on a moving captain. At hp 900 he was
   already dealing **66% of all wave-12 damage**. He can't land on someone
   *retreating*; he lands freely on someone *orbiting*, which is what the gauge
   rewards.

1b. **A crash I found and deliberately did not fix (SG-147, P1).** A crit
   explosion can crit and explode again, with no depth guard — `damage_enemy` →
   `_damage_circle` → `damage_enemy`. It hard-crashes the game with a stack
   overflow. Twice in ~1,400 headless runs, both in long boss fights, so **the
   longer Colossus makes it more likely, not less.** Probably a one-argument fix,
   but it is a live balance path and wants its own before-and-after rather than
   riding on a tuning commit. Say the word and it is next.

1c. **The Colossus is "too easy" — the original blank question, now mostly
   answered above.** No longer a blank question:
   `docs/COLOSSUS-DESIGN.md` is three designs, judged twice, each carrying a
   kill-test that would cut it. **Read §1 even if you read nothing else** — it
   answers *why* he is easy with his real numbers, and the answer is not
   "needs more damage". He pays 1.9 s frozen for a swing that geometrically
   cannot reach a moving captain, closes at 95 u/s against her 260, is pinned
   inside a 240-wide column on a 1,680-wide deck, and out-ranged by Ember
   Cleave by 97 units for free. His half-health turn *removes* the fight's only
   pressure by killing seven adds that each refund you pressure, dash and heal.
   The panel recommends **Option B** with three grafts; A and C are written up
   honestly in case you prefer one. **The recommendation is a recommendation.**
2. **Crew strafing.** The four `strafe` clips are unwired on purpose: while a
   sailor closes, his travel and threat vectors are the *same* vector, so a
   strafe would sell something the mover never does. **If you pictured
   sidestepping with the bayonet held on target, that's a different rule** — and
   the clips are ready for it.
3. **The Muster** (`docs/ENEMY-VARIETY-DESIGN.md` §2.1) — seeded wave mutations,
   the biggest remaining gameplay feature. **This no longer waits on you.** The
   held-rate observation I asked you to set a threshold for has evaporated: it
   was measured with a bot that never moved, and on the repaired rig it flips
   sign and loses significance (92% vs 86%, z=1.43, against the recorded 23/60
   vs 34/60, z≈2.0). Its own row had wondered whether it was "a bot fact". It
   was. One fewer decision for you; the Muster is now just unbuilt work.
4. **The menu direction.** The title is rebuilt; Settings / How to Play /
   Controls / Pause are deliberately untouched pending your verdict, because
   they are a different structure (label-left, value-right) wanting one more
   noun.
5. **Boarders arriving off a ship — you asked twice and it was never filed.**
   That is my failure, not the backlog's: an ask with no row is invisible to a
   loop that works the board. It is now SG-134 with a full design
   (`docs/BOARDING-ARRIVAL-DESIGN.md`) — three approaches, judged twice,
   recommendation is renderer-only so the sim never learns about it, with the
   landing point re-read every frame so a boarder shoved mid-flight bends its
   arc rather than teleporting. **It needs exactly one thing from you: which
   hull is the arrival ship** — which is the same question as decision 6 below,
   so answering that starts this.
   **ANSWERED 2026-08-03 — your words:** *"while they're jumping, they should
   be immune to all damage until they hit the deck and start moving."* That
   closes the either/or below, and it is being built as ONE authority every
   damage path consults rather than a check each path can forget.
   *Found while surveying it:* a boarder's 0.8 s climb
   draws a gold telegraph ring **in the hidden 2D scene, so nobody has ever seen
   it**, and only cannons and crew exempt a climbing boarder from damage — every
   skill, aura and fire pool already hits it. Harmless while it stands on the
   deck; not harmless once it is in the air. Filed as SG-135.
6. **The skyships** — which ship goes where, and which is the arrival ship? All
   five are in, placed in a wedge off the bow and below. A second barge is
   ingested but banked rather than flown.
7. **Heat 5 is a wall, not a rung — is that what you meant?** Measured
   overnight at proper sample size: Heats 0, 3 and 4 sit in a shallow 20-point
   band, then **Heat 5 holds 0 of 120 runs, dead on wave 4.02 with sd 0.18.**
   `SG-14` recorded the ladder as "graded rather than a cliff"; that is now
   refuted. Two caveats are ours, not yours: Heats 1 and 2 were never measured,
   and the bot never repairs or retreats, so you may well clear what it cannot.
   **Accept the wall and change the sentence, or keep the sentence and soften
   the rung?** Nothing has been tuned pending your answer.
8. **The ally-share mystery needs one fact only you have.** Your real run read
   **58%**; the repaired rig reads **13%**. I predicted the stationary bot
   explained the gap and I was wrong — stubbing the movement back out reads
   15%, so movement was worth two points. **What were your crew count and your
   draft in that run?** `ALLY_CAP := 32` is the first thing to check and
   explicitly not being called the answer.
9. **Bolts still "not cool"?** The agent fixed the measurable half (size) and
   stopped rather than guess at style. Its proposal if you agree: the browser's
   hard ink rim plus a hot leading spike.
10. **Heat 3 deals a weapon draft with no weapon in it, in about a third of
   runs — is that intended?** COLD DECK caps the draft at two cards, and as
   the shapes you already hold leave the pool those two are sometimes Field
   and Pulse — both passives, neither on a key. Measured on the repaired
   balance rig: **the captain was offered a passives-only weapon draft in 37
   of 120 Heat 3 runs (31%)**. This is a GAME fact, not a bot fact — a human
   at Heat 3 sees the same two cards. Flagged only because you have already
   ruled once that a draft should not deal "a card worse than a skip" (that
   is why SPARE PARTS leaves the catalogue under The Opening Bid), so this
   may be the same question one rung along. **If a two-passive deal is the
   intended bite of COLD DECK, nothing needs doing** — the fix, if you want
   one, is to guarantee one active in every weapon draft. No recommendation
   beyond: you should know it happens. (SG-130)

---

## 3 · What only you can unblock

**You are making the deck assets by hand** (your call, 2026-08-03) — so the
Loom is no longer blocking them, and nothing is waiting on Meshy credits.
**Drop the files anywhere and tell me the path; ingestion is one manifest entry
and one command.** The spec is `handoff-3d/README.md`: GLB, Y up, facing **+Z**
(the locked 41° camera only ever sees that side), metres, ≤4k tris, house
palette, flat albedo with no baked lighting, and **no ground plane, no base, no
plinth** — that last one is the failure this pipeline hits most often; a
generated railing once came back standing on its own timber bench.

Piece specs and sizes are in `handoff-3d/ship_edge_kit/PROMPTS.md`. **Do the
rail module first**: a rail reads as a rail only because you see sky *through*
it, so the periodic gap is the whole cue — ~145 units between stanchions, rails
at ~66 and ~118 units high. Tileable, so its left edge meets the right edge of
a copy of itself.

*Fixed this morning so it does not bite you:* `tools/ingest_model.py list`
crashed with a `KeyError` before printing anything, because it indexed
`spec["archive"]` on the manifest's prose entries. It works now.

**The Loom is still wanted, but only for 2D**: the four HUD pieces and a real
bug — **the Boilerwright wears the Corsair's portrait.** It is not a broken
path; `tools/forge.py` is only a *client* of a server at `127.0.0.1:8765` that
is not on this machine, and there is no stored image-API key. Either copy the
Loom server folder across, or paste a key and I will rewrite `forge.py` to call
the API directly and retire the server dependency. No rush now that the deck
assets are yours.

**Your cutlass fit is still uncommitted**, preserved through every build all day
(29 lines in `assets/models/weapons.json`). Re-fit it in the fixed lab
(`model_lab --fit captain`) and say the word to commit it.

---

## 4 · Waiting on your hands, not mine

- **The ship edge kit** — you approved it; prompts are in
  `handoff-3d/ship_edge_kit/PROMPTS.md`. **Do the rail module first**: a rail
  reads as a rail only because you see sky *through* it, and small repeated
  objects are exactly where generation fails.
- **The knight's axe** (~30 credits) — his painted version carries a
  double-bladed axe; the model's hands are empty because the pack that rigs him
  is a great-sword pack. Weapons are a separate bone-mounted layer.
- **The sword grip re-fit** — two minutes, `model_lab --fit captain`.
- **Which menu drifts right?** Re-measured tonight across 24 screens at four
  widths after enormous renderer change: zero findings. It stays open, but it
  cannot move without you naming the menu.

---

## 5 · What the loop actually did while you slept

**Builds 48 → 51. Harness 851 → 910.** Full detail, with every number and every
correction, is in `skygear-godot/docs/NIGHT-LOG-2026-08-03.md`. The digest:

**Fixed and shipped:** the results-screen regression (six string literals spelled
a newline by pressing Enter, so the delimiter was whatever that file's line
endings were); fire no longer grants immunity; the Colossus now hits inside the
wedge he is drawn; the balance bot moves; the screenshot tools actually freeze;
the rune mask reads telegraph pixels instead of red ones; keg layouts reproduce
from a seed; three tick accumulators keep their remainder.

**The night's real theme was instruments, not features.** Every tool that
decides whether a feature ships turned out to be unmeasured. In order: the shot
tools were photographing a moving scene (53% noise floor, now 0.00%); the rune
mask was 85% brazier fire; the balance bot had never moved; its "8% noise floor"
was sampling error at n=120, not a property of the instrument; `n=6` — the old
default — resolves a held-count to **±40 points**, which is why two board rows
disagreed for two days about the same number; and the bot drafts differently in
different arms, so a whole class of comparison was never interpretable.

**What that cost, honestly:** three published numbers were withdrawn, one shipped
feature's evidence evaporated (it still passes on a corrected measurement), one
feature's cut turned out to rest on a statistic gathered where the effect could
not appear, and one claim in the docs was refuted outright. **No tuning value was
changed anywhere to make any of this look better** — that was the standing rule
all night and it held.

**Twice an agent corrected itself unprompted** on a finding nobody would have
checked, and once withdrew a significant-looking result because the
pre-specified test disagreed with the post-hoc one. That is the part I would
keep if I could only keep one.

## 6 · Where the day got to

**Builds 32 → 53. Harness 499 → 926.** The deck went from half-painted to
all-mesh, and **every figure you modelled yourself was wired the same day you
made it** — the hulk's three states, the furnace knight, the crew, the goblins,
the drone, the Colossus, and a five-ship fleet.

Every dying thing on this deck now has a death. As of tonight, nothing vanishes
— it fades.

---

---

## 7 · Still open from today, in one place

Each of these was written up at length by the agent that found it; the full
evidence moved to `skygear-godot/docs/NIGHT-LOG-2026-08-03.md` so this file
stays a page. **None of them blocks the loop.**

1. **Fourteen shipped models are shinier than this deck's light allows.** All 27
   models ship with `metallicFactor` unset, which glTF reads as **1.0** — that
   was the Colossus's texture bug, now fixed at the pipeline level. The ceiling
   came from one frame of a big dark machine, and whether a brass gearblade
   *wants* to be shinier than a soot-blackened juggernaut is art, not a bug.
   Nothing was restyled. Three options and a recommendation are in the log.
2. **The rail's scale is yours.** At the 145-unit stanchion pitch the cap rail
   sits at **83% of the captain's height**. The side rails structurally cannot
   hide her, so readability does not decide it — it is aesthetic. Rendered
   candidates are coming to you rather than a silent pick.
3. **`lit_probe.gd` photographs whatever the clock spawned.** Pinning it makes
   it repeatable but re-poses the deck from 3 boarders to 8, which is what moves
   the number — so it is a rebaseline decision, not a bug fix. Nothing changed.
4. **Fire's hitbox** — the pool burns from outside its own picture by up to 70%.
   Both fixes are balance changes; it is on your play list.
5. **The knight's metalness** — 0.70 metallic over a dark albedo with a
   near-black sky to reflect. Measured, deliberately not shipped, and it is a
   one-model change rather than the deck-wide one I first told you.
