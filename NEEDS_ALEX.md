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

## 7 · The furnace knight has an edge now — and two things about him are asset bugs (SG-86 / SG-131)

**Look at this first: `.shots/sg86/full-before-after.png`** (your build on the
left, the change on the right), and `.shots/sg86/knight-crop-before-after.png`
for the close crop. Both are the same frozen frame, same seed, same pose.

**What was actually wrong was not that he was dark, it was that he was darker
than the floor.** Measured, he sat at **40.81 against the planking's 47.83** —
15% darker than the boards he stands on, a warm brown figure on a warm brown
deck. Your paintings all carry a cool rim the deck never gave the mesh, so the
deck grew a third lamp: a cool `#9fc6e8` rim from the bow, energy 0.62, pitch
**-1 degree**. He is now **51.19 against 49.53** — the light went onto him and
not onto the planking. **I left headroom unspent on purpose**: the deck could
go to 55 before it matched your painting, and a boarder who out-glows his own
wind-up is a readability loss however well he measures.

**The first version of that fix was fake and I nearly shipped it.** At pitch -16
it improved every number this ticket was filed on — and the picture looked no
better, because it brightened him and the deck by the same eight points. It is
in the board row, and the harness now pins the pitch so it cannot drift back.

**NOTHING NEEDED FROM YOU ON THAT.** What does need you is **SG-131**, because
it costs asset work rather than code:

1. **His furnace grille is not emissive at all.** `armored_emission.png` peaks
   at 51/255 and 0.15% of it is non-black — there is no grille in the map. The
   ticket said raising `emission_energy` did nothing because the tonemapper was
   saturated; it did nothing because **there is nothing there to multiply**. The
   orange on his chest today is painted into the colour map and lit by a lamp.
2. **His armour is 70% metal with a black sky to reflect.** The metal map's
   median is 178/255 and nothing sets the environment's reflection source, so
   the plating shows a storm-dusk night sky — which is why big areas of him
   render nearly black while your painting is mid-tone brass. This is the single
   biggest reason the mesh reads darker than the sprite, and no light fixes it.

Both are a re-ingest, not a regeneration — **I do not think either needs Meshy
credits.** I did not touch them because they live in `tools/`, which another
agent held all night, and because changing metalness or reflections moves every
model on the deck at once and deserves its own measured row. **The instrument to
judge it already exists** (`tests/lit_probe.gd`), so whoever takes SG-131 can
show you a before/after the same way this one did.

**His axe is still missing.** Untouched, as briefed — that is the SG-38 seam and
it needs a weapon mesh, not a material.

---

## 8 · SG-131 — the knight's furnace is lit. One decision left, and it is smaller than I told you.

**Done, no credits spent, nothing for you to judge here:** his grille and visor now
glow. The emission map Meshy shipped was empty (peak 51/255), so nothing SG-86 did
with `emission_energy` could ever have worked. The new map is derived from his own
albedo — see `.shots/sg131/grille-before-after.png`, before on the left. It is
deliberately left **under** your painting's level rather than matched to it: he
should not out-glow his own wind-up.

**THE DECISION: his armour is 70% metallic and I did not change it. Last night's
note told you that moves every model on the deck. That was wrong and I am correcting
it — it moves exactly one.** Only three models in the repo have a metal map at all,
and only he has any metalness in it: **armored 178/255, boilerwright 0/255, captain
0/255.** He is the odd one out, not the convention.

Two ways to fix the black-plating look, and they are not the same size:

1. **Drop his metallic multiplier below 1.0 at ingest.** One model, one re-ingest,
   no other asset touched. Low risk now that we know nothing else is metallic.
2. **Set `Environment.reflected_light_source` to the ambient colour** — one line, but
   it changes the specular response of *everything* on the deck. Right now it is
   never set at all, so all metal reflects the near-black storm sky.

**I did not measure either at render level** — I started (2) and abandoned it when
the run hung — and I did not ship either, because you already have a deck-wide light
change from SG-86 in this build and two of those tangled together is not a fair thing
to ask you to judge. **My recommendation is (1) on its own row, after you have ruled
on the rim light.** (2) should wait until someone can show you a before/after of the
whole deck, not just of him.

**His axe is still missing and still untouched**, as briefed.

---

## 9 · Fire: the circle you can see is not the circle that burns you (SG-121)

**One question: which radius is the real one?** Three fire creators write a
`radius`. The RENDERER reads it (`view3d.gd:4470`) to size the flames, the scorch
under them and the permanent burn mark. The DAMAGE ignores it and uses a flat 78
units for everyone. So:

| fire | drawn at | burns at |
|---|---|---|
| Boilerwright's scald trail | 46 | 78 |
| broken lantern | 62 | 78 |
| RESIDUE, one stack | 84 | 78 |

Two of the three burn the captain standing somewhere no fire is drawn. The third
draws fire that does not burn. **My recommendation is to make the damage read the
field's own radius** — it is the number the art already agrees with, and "the
hitbox is the picture" is the fairness rule the telegraph work has been holding
everywhere else. That shrinks the lantern and the scald trail and grows RESIDUE,
which is a real balance change and is why it is on this list instead of in a
commit.

**Do not read this as urgent.** It is P3 and it has been true in every build. It
is here because both of the two things the board row told the next agent to do —
wire it up, or delete it — change the game, and neither should happen quietly.

There is a second field, `dps`, that genuinely nothing reads (13x residue, 9.0 for
the scald trail). Wiring that would move fire's damage rate a THIRD time in one
session, after SG-117 and SG-122. **My recommendation is to leave `dps` alone
until fire has been played after those two changes.**

---

## 10 · `lit_probe.gd` photographs however many boarders the clock spawned (SG-136)

**One question: may I re-baseline the furnace-knight numbers?** `--fixed-fps 60`
makes that tool repeatable — its molten reading goes from 0.24 / 0.23 / 0.25 over
three runs to **0.81 / 0.81 / 0.81, bit-identical**. But the flag also changes how
far the game has run by the time the tool takes its picture, so the deck holds
**8 boarders instead of 3**, and that is what moves the number, not the flag.

Which means the figure the knight's emission was tuned against was read off a
composition the machine's speed chose. **I did not touch the constants**, because
re-baselining them is changing tuning values to make a result look better and
that is the one thing every agent this session was told not to do on its own.

**My recommendation: yes, adopt the flag, and re-publish the bands in one commit
with both sets of numbers in the row.** It costs one afternoon and it is the
difference between a tool that can resolve a 1% asset change and one that cannot.

---

## 11 · SG-123 is finished but unlanded — and the collision was my fault, not yours

**Nothing here needs a decision. One thing needs your awareness.**

An agent working on SG-123 found `HEAD` moving underneath it and
`scripts/view3d.gd` growing ninety lines between two of its own commands. It
reported this as *you* being live in the tree. **It was not you — it was another
agent I had running in the same file, and I had told this one the tree was
exclusively its own.** That briefing was wrong and the collision follows
directly from it. Correcting it here because the agent's write-up named you, and
the record should not.

**What it did about it was right.** `git add <file>` stages the whole file, so
it could not land its fix without sweeping the other agent's unreviewed work
into its own commit under its own message. It **removed its change from the
tree** rather than leave it for the next `git commit -a` to collect, and left
the mechanism written out in the night log — about forty lines to re-apply.

**SG-123 is solved and was verified at 932/932** in a clean worktree, with three
checks demonstrated to fail on the old behaviour. I will re-apply it once the
deck work lands and `view3d.gd` is free.

**One near-miss worth recording:** to get a clean control the agent ran
`git stash` on `view3d.gd`, which took the other agent's uncommitted work with
it. It came back intact on `stash pop` and was verified — but that is closer
than it should have been. **No agent should run `git stash` in a shared tree**,
and that is now the rule rather than a lesson.

Your `weapons.json` was never touched by any of this, and still isn't.


---

## 12 · Boarders arrive by ship now — two stages of three, and decision 5 is answered by a default you can overrule in one line (SG-134 / SG-135)

**Your sentence unblocked the whole thing.** *"While they're jumping, they should
be immune to all damage until they hit the deck and start moving."* That was the
open question the design could not answer for itself, and it is built as a RULE
rather than a carve-out: one predicate, `SkyGearEnemy.can_be_hit()`, asked by
every path that can take health off a boarder — the funnel every skill goes
through, the burn tick that never went through it, and the cannon and crew
targeting loops, which used to be the only two things in the game that respected
the arrival window. The string `"climb"` no longer appears anywhere outside
`enemy.gd`. A damage source somebody writes next month inherits the rule without
being told about it.

**Two side effects you should know about, neither compensated.** A Colossus can
no longer be BURNED through his half-health turn — the burn tick was bypassing
the guard that everything else respected, so he was never as unburstable as the
code said. And a cannon or a crewman no longer aims at something it could not
hurt. Both make the game very slightly harder and both are one predicate away
from being reverted.

**WHAT IS BUILT:** a hull leaves the ambient wedge at the start of every wave but
the boss's, comes forward and up to a hold off the port bow, holds through the
fight, and rides the wave's own clear countdown home — **and its station is empty
sky while it is away**, which is the "fleet is one short" reading for free. And
the gold ring that `enemy.gd` has drawn around an arriving boarder since the port
began — in the hidden 2D scene, where no player has ever seen it — is on the
planking, closing from wide onto the boarder's own gameplay radius.

**WHAT IS NOT BUILT:** the drop itself. Boarders still appear on the planking
rather than falling onto it, so *"I still see enemies popping in"* is only
half-answered. That is SG-142, and everything it needs is now in place.

**DECISION 5 — WHICH SHIP IS THE ARRIVAL SHIP — IS NO LONGER BLOCKING.** I picked
a default and it is one named constant, `ARRIVAL_HULL_ORDER` in `view3d.gd`:
**one of the four hulls already flying comes forward per wave**, rotating
tender, barge, skiff, cutter. Three reasons it can be a default rather than a
question:

  * it answers no OTHER open question by accident — `skyship_barge_heavy` stays
    on the bench, so decision 3 is exactly where you left it;
  * cutting the list to a single entry turns it into the other answer, a
    dedicated arrival ship, with no other edit;
  * and it claims no channel nobody has measured — making the hull MEAN what is
    coming needs the hull to be legible, and it is not legible enough for that
    yet. See below.

The order is by how far each hull travels, longest first. That was a measurement,
not a taste: I wrote it cutter-first at first and the frames said no, because the
cutter's ambient station is already at the hold's own depth and height, so its
whole "arrival" is a sideways slide.

**AND THE THING YOU SHOULD BE TOLD RATHER THAN DISCOVER, because it is the part I
cannot fix.** The arriving hull reads **from the bow**, at the edge of the frame,
partly behind our own rail. **From mid-deck it is not visible at all** — SG-102
measured the deck as 100% of the frame at zoom 1.0 from the middle, and no
arrival ship can change that. `.shots/sg134/mid-z1.00-hold.png` is that fact
photographed rather than described. It is why the ring matters more than the
ship: the ring is the only channel that works where the fight actually happens.

**The mark the design told me to park the ship on was in the one place you cannot
see it,** and I found that by being the first thing ever to read it.
`SKYSHIP_BOW_HOLD` has been a constant with no reader since SG-102. Its `y` is a
KEEL and was reasoned about as a deck, which put the entire hull above the top of
the picture; and its `x` is dead ahead, which is where our own bow is — true of
the camera frustum and false of the photograph. Six candidate bearings are shot
at `.shots/sg134/holds/` with every other hull hidden, which is the experiment
that settled it.

**To look at it:** `.shots/sg134/` — four poses at both zooms, the hull at its
station and on the hold from ONE camera, so the pair is a real comparison; and
`ring-fight.png` / `ring-mid.png`, three boarders held at 98%, 50% and 6% of one
arrival window so the ring's CLOSE is visible in a still. Or run
`godot --path . --script tools/arrival_shot.gd` yourself.

---

## 2026-08-03 — two answers only you can give, both about the boarding hulk (SG-139 / SG-140)

Both came out of your three build-53 notes. Neither blocks anything shipped
today; both decide how far the fix goes.

**1. Should a DESTROYED hulk stop being solid?** — board SG-139

You asked for wrecks to "fade away after being destroyed". They now fade, but
only down to 28% rather than to nothing, and that is not a taste call: the
simulation keeps a broken hulk's collision hull for the rest of the run on
purpose (`hulk_hull()` answers for all three states, and `correct_player_position`
pushes the captain out of it). A wreck faded to zero would be an **invisible wall
across the bow** — a worse bug than the one you reported.

*Recommendation:* let the wreck stop colliding when it dies, and fade it to
nothing. It is one line in `game.gd` (`hulk_hull()` returning `{}` for the
destroyed state) plus one constant here, and the wreck then reads as debris you
walk through rather than a hulk you cannot see. The argument against is that a
broken boarding craft bolted to your hull arguably *should* still be in the way —
if you want that, say so and it stays at 28% and visible, which is also a
defensible answer.

**2. Do you want the hulk to be BIGGER than it now is?** — board SG-140

The thing you asked about in the middle of the frame is the enemy's **boarding
craft** — it grapples onto the bow on a push wave and unloads boarders until you
break it. It was drawn **528 ground units wide against a 380-wide collision
hull**, in a **440-wide lane**: wider than the lane it sits in, which is why it
read as blocking. It is now drawn at 380 — the same number the crew march on, the
splash measures against and you collide with — so it is 380 wide, 223 tall, 308
deep, and the lane is open.

That makes it noticeably smaller on screen than you have been seeing it. If that
now under-sells it, **the lever is `SkyGearLanes.HULK.radius` (currently 190)**,
which moves the picture and the collision together — raising it to 240 would put
it back near 480 wide and still inside the lane. I have not touched it because it
is a gameplay number, not a rendering one. Say a number, or say "leave it".

## 13 · Fourteen shipped models are shinier than this deck's light can pay for (SG-144)

The Colossus's "texture bug" was not decimation and not the export. Meshy writes
**no `metallicFactor` at all**, which glTF reads as **1.0** — not as neutral —
over a metallic map averaging 0.49 and peaking near chrome. SG-90 already learned
from a rendered frame that a metallic surface on a lamp-lit deck with nothing to
reflect goes black, and wrote that down. It reached one code path out of four.

That is fixed for the pipeline: the ceiling lives in `tools/lamplit.py` now and
the boss went 1.0000 → 0.3524 (read back out of `boss_parts.scn`, not asserted),
with the geometry byte-identical. **No credits spent — rebuilt from your old
`0803021335` export as you decided.**

**The decision I did not make for you.** `python tools/lamplit.py audit` says
**14 of 27 shipped models are over the same ceiling**:

    gunner 0.71 · scrapper 0.64 · steam_vent 0.56 · sword_gearblade 0.55
    harpoon_ballista 0.54 · salvage_pile 0.53 · wrench_pipe 0.51 · boiler 0.45
    sword_cutlass 0.44 · skyship_cutter 0.41 · lantern_post 0.36  (+3 more)

I clamped the four NEW edge models on the way in, but I did not touch the
fourteen. The ceiling was derived from one frame of a big dark machine that has
to read as a machine. Whether a **brass gearblade or a lantern post wants to be
shiny** is a judgement about that object and about your deck's light — restyling
fourteen shipped assets on my reading of one frame is the same overreach as the
bug, pointed the other way.

**Three ways to go, pick one:** (a) clamp all fourteen, one command, reversible;
(b) clamp only the dark machines that must not vanish (scrapper, gunner, boiler,
hulks) and leave the brass and blades bright on purpose; (c) leave it and treat
0.34 as a boss-only rule. I'd suggest **(b)** — the failure was always about
things disappearing, and a bright cutlass was never the complaint.

**One gap, honestly.** No harness check landed for any of this.
`tests/parity_test.gd` was carrying 362 uncommitted lines from another agent and
`git add` stages whole files, so adding mine would have committed their
unfinished work. The strings are written and ready to land:
`lamplit · the metallic ceiling is read from one place and not restated`,
`lamplit · every ingest path that writes a material clamps it`,
`lamplit · a palette row above the ceiling fails at import`.
The first two fail on `3a82cdb~1`; the third is a regression guard only.

## 14 · The new rail is good, and its scale is a choice only you should make (SG-145)

It's ingested, clamped, and it renders well — no plinth, you can genuinely see
the deck through it, 3,060 triangles so nothing had to be decimated. **It is not
wired up**, because placing it means editing `view3d.gd` and another agent is
holding that file today.

**The thing worth your ten seconds.** DECK-IDENTITY item 4 asks for "16
stanchions a side at 145-unit spacing with two horizontal rails at y = 66 and
118". This module **cannot produce that at any scale** — it is a *three*-bar
rail (two pipes plus a timber cap) where the spec describes a two-bar rail. So:

| | stanchion pitch | cap height | vs the captain (176) | modules over the 2320 deck |
|---|---|---|---|---|
| **A** — honour the spec's *spacing* | **145** (spec exact) | **146** | 83% | 8 × 290, exact |
| **B** — honour the spec's *height* | 116 | **117** (spec wanted 118) | 66% | 10 × 232, exact |

Both divide the deck length exactly. **I recommend B**: the "see the sky through
it" cue is a property of the module and survives scaling, whereas cap height is
what decides how much of your frame the rail eats. A costs you 28 units of
skyline for a spacing number; B costs you the spec's stanchion *count* (20 a
side, not 16) and nothing you can see.

**On occlusion, the honest version.** The camera's x tracks the captain's
(`view3d.gd:4202`), the rails sit at x = ±840, and no figure ever gets past
|x| = 750 — so a straight line from camera to figure never reaches the rail.
**At the shipped camera the side rails structurally cannot hide anybody**, which
means Pillar 6 does *not* force the smaller scale; the choice above is aesthetic.
I'd still make item 4's own pre-committed check (`view · no stanchion stands
between the camera and a figure at any zoom`, projected and measured) run before
it ships, because that argument is geometry and the rule here is measurement.

**One correction to the tiling plan.** "Place every 290 so the end stanchions
coincide" gives a uniform pitch, but *coincide* means a **doubled stanchion and
19.8 units of overlapping rail at every seam** — the module overhangs 0.114 past
each end post. Butt-joining instead bunches posts in pairs; spacing at 3 pitches
leaves a hole in the rail. **The clean fix is to trim the overhang off the asset
so the rail ends flush at the end posts**, after which 2 × pitch tiles perfectly
with nothing doubled. That's a small mesh edit and I'd do it before wiring.
