# NEEDS ALEX — the morning list

_Written 2026-08-02 as you went to sleep; rewritten through the night as the
detail outgrew it. **Build 53 is live**, harness **926/926**. Evidence for
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

## 1 · Play build 53 and judge eight things

All shipped tonight; none can be settled by a checker.

| | The question |
|---|---|
| **The furnace knight** | Its telegraph drew a 120° wedge while its hit test was a full **circle** — sidestepping the flank, the exact move the picture invites, never worked. Now gated on arc. **Is 0.90s readable with gremlins on you? Does 34 damage feel like a mistake you made?** |
| **The deck marks** | Scorch and blood accumulate where things actually happened. My kill-test threshold was wrong, the rig built to replace it answered non-proportionally, so the agent took the cautious branch — half the cap, alpha 0.30 → 0.12 — and refused to quote the flattering number. **Too subtle now, or too much?** |
| **The crew** | 144 units (12.5% smaller) and they turn to face what they fight. **Right size? Right rule?** — see the strafe question below. |
| **Enemy bolts** | 2.3× smaller, now the browser's own radius. **Too far?** |
| **Fire's hitbox** | **The fire you can see is not the fire that burns you.** The renderer sizes flames, scorch and the burn mark from a `radius` the damage ignores: a scald trail is *drawn* at 46 and *burns* at 78; a lantern 62 against 78. So a pool burns you from outside its own picture, by up to 70%. Filed as SG-121 and **deliberately not fixed** — wiring the damage to the picture moves three hitboxes, deleting the field changes every drawn fire, and both are balance changes you should choose. It matters more since last night: fire stopped granting immunity and now delivers its authored rate. **Play it and say which way it should go.** |
| **The knight's furnace** | It burns now. His emission map was effectively **empty** — 0.15% non-black — so every `emission_energy` he was ever given multiplied nothing, which is why the earlier "raise the emission" attempts measured as no-ops. The map is authored from his own albedo, no Meshy credits spent. Molten fraction **0.19% → 0.62%**, deliberately under his painting's 1.12%: pushed further the furnace goes white and the lit count *falls*. **Does he read as lit from inside now?** |
| **The deck's new light** | A cool rim light from the bow, added overnight. The furnace knight measured **15% darker than the planking he stands on** — a warm brown figure on warm brown boards, because the deck had a key and a fill and no rim. He is now marginally brighter than his floor. **It is deck-wide, so the crates and rigging gained edges too.** Frames: `.shots/sg86/full-before-after.png`. **Does the deck look better, or just different?** |
| **The HUD cluster** | Bottom-left rebuilt on the Supervive lessons. **Does the direction feel right before it spreads to the hand and the lane readout?** |

---

## 2 · Ten decisions

1. **The Colossus is "too easy" — pick a fight.** No longer a blank question:
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

**THE LOOM NEEDS A KEY, OR THE SERVER FOLDER — it is not a broken path.**
*(Re-diagnosed 2026-08-03, after you asked me to fix the tool.)* I searched this
machine. `tools/forge.py` is only a **client**: it POSTs to a Loom server on
`127.0.0.1:8765` that lives outside this repo. There is no
`run_aether_loom.ps1` anywhere here, no Loom directory, and no stored
`OPENAI_API_KEY` or `GOOGLE_API_KEY`. (`GitHub/ImageGen` is a different tool —
childcare flyers.) The dead Codex path in `ASSET-GENERATION.md` is a symptom,
not the cause.

Two ways out, and **I recommend the second**:

1. Copy the Loom server folder across from your other device — `forge.py` then
   works unchanged.
2. **Paste an image-API key** and I rewrite `forge.py` to call the API directly,
   retiring the server dependency: no second machine, no localhost service, and
   it stays fixed. The house `STYLE` block and the prompt-beside-the-manifest-key
   discipline survive either way. Stored gitignored, like the Meshy key.

Waiting on it: the ship edge-kit concepts and four HUD pieces, **including a
real bug — the Boilerwright wears the Corsair's portrait.**

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
