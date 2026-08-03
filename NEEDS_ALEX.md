# NEEDS ALEX — the morning list

_Written 2026-08-02 as you went to sleep; rewritten 2026-08-03 as the night's
detail outgrew it. **Build 51 is live**, harness **910/910**. The evidence for
everything below is in `skygear-godot/docs/NIGHT-LOG-2026-08-03.md` — this file
is only what needs you._

> **What changed between 49 and 50 that you will actually feel:** fire is no
> longer a shield. Standing in a fire pool used to make you immune to
> *everything* — a swing included — 73% of the time. Measured directly: a
> captain swung at every 1.5 s for a minute took **700 damage inside the fire
> and 1014 outside it**. It costs **1440** now. If wave 8 suddenly feels
> heavier, that is why, and it is the game working rather than the game
> changing.

> **Standing in fire made you immune to almost everything. It is FIXED** —
> SG-117, found and verified last night, fixed 2026-08-03; a hazard tick bought
> 0.55 s of *global* i-frames every 0.75 s, so a fire pool was the safest square
> on the deck. If a fight ever felt oddly survivable, that is why. **Standing in
> a pool used to be 31% SAFER than standing beside it; it now costs 42% more.**
> The measured before/after — including the part where the run-level rig
> **cannot** resolve the change and I am not pretending it can — is in
> **§SG-117 / SG-118** near the bottom. No tuning value was changed.
>
> **And read §SG-118 in the same section before you trust any balance number in
> this repo**, including ones I have shown you before: `tools/balance.gd` never
> moved its bot, while a comment in it said it did. Every simulated-run verdict
> here was measured against a captain standing on her spawn point. **One number
> from SG-57 that was waiting on your threshold has flipped sign** and no longer
> asks you anything.
>
> **Every measurement in this file was re-taken overnight on repaired tools** — the night log records which ones changed.
> The screenshot tools were photographing a moving scene and calling it still —
> every rigged figure's `AnimationPlayer` ignores both `set_process(false)`
> calls, so the noise floor was **53%**. It is now **0.00%**, and the three
> answers taken against it were re-measured. **Two of them did not survive**,
> including one I reported to you as settled: the rigging does NOT improve
> telegraph contrast, and the evidence behind the shadow-layer verdict is gone.
> **No tuning value was changed on the strength of a re-measurement** — the
> corrections are written down and the two live questions are yours. The marks
> finding is the one to read: the halving that shipped was decided on noise.
>
> **And §SG-116 at the very bottom supersedes the rigging number in §SG-108,
> which I gave you as settled twice.** The tool that decides what a telegraph is
> worth was picking its pixels by COLOUR, so it was measuring the brazier fire
> and an ARMORED boarder's lit plating as telegraph — **85% of what it called
> "rune" was not rune.** Corrected, the rigging costs a rune about **1.5%**
> rather than 0.88%. **The gate is 3%, so it still passes, nothing was cut and
> nothing was tuned** — this is the boring answer and you can act on it. The
> part worth two minutes is that the ABSOLUTE contrast figure fell to **1.24**,
> below anything previously written down, and that the deck-marks pass is a
> coincidence by its own printed criterion (SG-124).

Everything here is either **a decision only you can make** or **a verdict only
your eyes can give**. Nothing in it blocks the loop — there is plenty to do
without any of it.

---

## 1 · Play build 53 and judge seven things

All shipped tonight; none can be settled by a checker.

| | The question |
|---|---|
| **The furnace knight** | Its telegraph drew a 120° wedge while its hit test was a full **circle** — sidestepping the flank, the exact move the picture invites, never worked. Now gated on arc. **Is 0.90s readable with gremlins on you? Does 34 damage feel like a mistake you made?** |
| **The deck marks** | Scorch and blood accumulate where things actually happened. My kill-test threshold was wrong, the rig built to replace it answered non-proportionally, so the agent took the cautious branch — half the cap, alpha 0.30 → 0.12 — and refused to quote the flattering number. **Too subtle now, or too much?** |
| **The crew** | 144 units (12.5% smaller) and they turn to face what they fight. **Right size? Right rule?** — see the strafe question below. |
| **Enemy bolts** | 2.3× smaller, now the browser's own radius. **Too far?** |
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
   *Found while surveying it, and worth knowing now:* a boarder's 0.8 s climb
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

## 3 · Two things only you can unblock

**The Aether Loom is not running, and the path in the docs does not exist on
this machine.** `ASSET-GENERATION.md` says
`C:/Users/alexr/Documents/Codex/2026-07-26/done-66-images-fully-specced-for`
then `.\run_aether_loom.ps1` — that directory is not there. Once it is up, four
things are specced and waiting: the ship edge-kit concepts and four HUD pieces,
**including a real bug — the Boilerwright wears the Corsair's portrait.**

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

## SG-131 — the knight's furnace is lit. One decision left, and it is smaller than I told you.

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
