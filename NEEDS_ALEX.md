# NEEDS ALEX — the morning list

_Written 2026-08-02 as you went to sleep; updated overnight. **Build 49 is live**
— it carries everything below plus the overnight work._

> **Read §SG-108 at the bottom before you trust any measurement in this file.**
> The screenshot tools were photographing a moving scene and calling it still —
> every rigged figure's `AnimationPlayer` ignores both `set_process(false)`
> calls, so the noise floor was **53%**. It is now **0.00%**, and the three
> answers taken against it were re-measured. **Two of them did not survive**,
> including one I reported to you as settled: the rigging does NOT improve
> telegraph contrast, and the evidence behind the shadow-layer verdict is gone.
> **No tuning value was changed on the strength of a re-measurement** — the
> corrections are written down and the two live questions are yours. The marks
> finding is the one to read: the halving that shipped was decided on noise.

Everything here is either **a decision only you can make** or **a verdict only
your eyes can give**. Nothing in it blocks the loop — there is plenty to do
without any of it.

---

## 1 · Play build 49 and judge five things

All shipped tonight; none can be settled by a checker.

| | The question |
|---|---|
| **The furnace knight** | Its telegraph drew a 120° wedge while its hit test was a full **circle** — sidestepping the flank, the exact move the picture invites, never worked. Now gated on arc. **Is 0.90s readable with gremlins on you? Does 34 damage feel like a mistake you made?** |
| **The deck marks** | Scorch and blood accumulate where things actually happened. My kill-test threshold was wrong, the rig built to replace it answered non-proportionally, so the agent took the cautious branch — half the cap, alpha 0.30 → 0.12 — and refused to quote the flattering number. **Too subtle now, or too much?** |
| **The crew** | 144 units (12.5% smaller) and they turn to face what they fight. **Right size? Right rule?** — see the strafe question below. |
| **Enemy bolts** | 2.3× smaller, now the browser's own radius. **Too far?** |
| **The HUD cluster** | Bottom-left rebuilt on the Supervive lessons. **Does the direction feel right before it spreads to the hand and the lane readout?** |

---

## 2 · Six decisions

1. **The Colossus is "too easy" — what should scary mean?** Filed, deliberately
   not guessed at. More damage, a mechanic you must answer, or something that
   changes the deck? The biggest open design question.
2. **Crew strafing.** The four `strafe` clips are unwired on purpose: while a
   sailor closes, his travel and threat vectors are the *same* vector, so a
   strafe would sell something the mover never does. **If you pictured
   sidestepping with the bayonet held on target, that's a different rule** — and
   the clips are ready for it.
3. **The Muster** (`docs/ENEMY-VARIETY-DESIGN.md` §2.1) — seeded wave mutations,
   the biggest remaining gameplay feature. Waits on **your noise-floor
   threshold** from the tempo measurements.
4. **The menu direction.** The title is rebuilt; Settings / How to Play /
   Controls / Pause are deliberately untouched pending your verdict, because
   they are a different structure (label-left, value-right) wanting one more
   noun.
5. **The skyships** — which ship goes where, and which is the arrival ship? All
   five are in, placed in a wedge off the bow and below. A second barge is
   ingested but banked rather than flown.
6. **Bolts still "not cool"?** The agent fixed the measurable half (size) and
   stopped rather than guess at style. Its proposal if you agree: the browser's
   hard ink rim plus a hot leading spike.

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

## 5 · What the loop is doing while you sleep

One agent, three items, none needing you:

1. **The audit regression** — the results screen's report head overflows at
   every width. *(My diagnosis here — "the menu rebuild narrowed the banner" —
   turned out to be wrong. It was never a width problem. See §7.)*
2. **The rig overhead, as shadow only** — the top-ranked item in
   `docs/DECK-IDENTITY-DESIGN.md`, and my answer to "it feels like a floating
   plane": masts, yards and shrouds built as **shadow casters with no visible
   mesh**, so the camera never sees them while the moon prints their rigging
   across the middle of the deck. It carries a pre-committed kill-test — if the
   lattice hurts telegraph contrast it gets cut, because pillar 6 outranks
   atmosphere.
3. **One shadow authority** — figures currently carry **two** shadows pointing
   different ways, and an airborne shell drags a hard disc as if lying on the
   boards. Marks will lean where the moon does and fade with height.
   Projectiles stay exempt and centred, because the mark under a bolt is what
   tells you where it will cross you.

If a kill-test says cut, it gets cut — and you will find the frames and the
numbers here rather than a feature nobody measured.

---

## 6 · Where the day got to

**Builds 32 → 49. Harness 499 → 862.** The deck went from half-painted to
all-mesh, and **every figure you modelled yourself was wired the same day you
made it** — the hulk's three states, the furnace knight, the crew, the goblins,
the drone, the Colossus, and a five-ship fleet.

Every dying thing on this deck now has a death. As of tonight, nothing vanishes
— it fades.

---

## 7 · Overnight, after you went to sleep (SG-106, SG-107)

> **Superseded in part.** Two of this section's measurements were refuted the
> same night by SG-108, which fixed the instrument that produced them. Where
> they disagree, **§SG-108 is right and this section is wrong**. Kept in place
> because the mistake is the useful part.

**Harness 851 → 862. Text audit clean. Pushed, and build 49 is live.** Three things landed:
the audit regression, the rig overhead, and the shadow authority.

### Look at these two first, they are pictures

* **`.shots/sg107/rig-before-mid-z1.00.png` against `rig-only-mid-z1.00.png`.**
  *(Re-shot at a quiet tick by SG-108 — the numbers in this section were not
  all confirmed; see §SG-108. The picture still stands.)*
  This is the whole of item 1 in one A/B, and it is the thing you have said
  twice that the deck needed — the floor now has a ship's rigging printed
  across the middle of it. Nothing is in the colour pass, so nothing can stand
  in front of a boarder. Same pair at z1.55.
* **`.shots/sg107/rig-after-*.png` is the version WITH the envelope casting, and
  I cut it.** Compare it against `rig-only-*` and you will see the broad grey
  wash over the bow that I did not think was worth 1% of the deck's light. If
  you disagree, it is one enum and one material line and it is written down in
  `view3d.gd` beside the constant.

### Four questions I had to answer myself because you were asleep

1. **The envelope: cast, or stop drawing it?** The design says make the gas bag
   cast, on the grounds that it can never be seen. I cut it — it costs a further
   1% of deck luminance for a soft wash, it is not the one-character change the
   doc expected (a transparent material is never rasterised into the shadow map,
   so it also needs a dithered `ALPHA_HASH` cutout), and **it is parked on the
   camera**, so its shadow would slide across the planking as the captain walks
   — which is the exact trade the design's own "explicitly not" list refuses one
   page earlier. **But the finding underneath it is real and unbanked:** that
   quad is invisible and is transformed every frame anyway. The cheap correct
   answer is probably to stop DRAWING it rather than to start casting it. I did
   not, because "never seen" has only ever been argued from the gameplay camera
   and the four `sky_shot` poses drag it. **Your call, and it is a minute's work
   either way.**
2. **The blob layer's delete gate fired, and I did not obey it.** Item 2
   pre-commits that if switching the whole contact-shadow batch OFF is not
   measurably worse than today, the layer is deleted and the moon does the job.
   Posed with no ordnance on screen it is not worse — 1.91% of deck pixels,
   under the 3% gate. That half is true and it is why every mesh figure now
   drops to a small contact core. **But that gate contradicts §13c**, which the
   same document calls non-negotiable: a bolt's mark must sit directly under the
   bolt, and the moon's shadow of a bolt lands 0.44 of its height to port, which
   answers a question nobody asked. A painted billboard casts nothing at all, so
   its blob is the only thing holding it to the deck. Posed with ordnance
   actually in flight the gate does not fire (OFF 4.88%, corrected-vs-today
   11.76%). **I kept the layer. If you want it gone, it should go for
   projectiles LAST or not at all.**
3. **`rig · …` collides with the animation rig's own check namespace.** The
   design pre-committed those exact strings and the board quotes them, so I used
   them verbatim rather than inventing `rigging · …`. The harness now has `rig ·
   a turn is rate limited` (a skeleton) next to `rig · no mast stands in a lane`
   (a ship). Ugly, harmless, one rename if it bothers you.
4. **Which contrast floor decides a telegraph.** Item 1's kill-test names
   `ink.gd`'s floor, which is 4.5 and is a floor for TEXT; §7.5 had already
   measured the shipped rune-against-planking figure at **1.91** and written
   down that a gate nothing has ever passed cannot decide anything. I used
   §7.5's relative 3% gate and printed both numbers every run. If you meant the
   absolute one, the rig fails it — and so does the shipped build without the
   rig, which is the point.

### One thing worth knowing about every measurement in this repo

The shadow tool prints its own **noise floor** — two plates of a frozen scene
with nothing changed between them — and that line is the most useful thing I
built tonight. It read **53%**. Three answers had already been produced against
it before I checked. It was not debanding and it was not the volumetric fog:
**every rigged figure owns an `AnimationPlayer` that runs on the engine's own
clock and ignores both `game.set_process(false)` and `view.set_process(false)`.**
Seventeen boarders were breathing through a walk cycle and moving their own cast
shadows between exposures. Frozen, the floor is 0.00%.

`tools/marks_shot.gd` has the same hole and only got away with it because it
shoots one frame apart. **SG-101's "residual it could not find" — the one §7.5
says is "not the marks, and it has not been found" — is very likely this.** That
is a re-measurement worth doing before you trust the mark-density number.

### Still owed to you from tonight

The shadow A/B plates (`shadow-today` / `-corrected` / `-off`) caught the
captain mid-swing, so a fire arc dominates the frame and they are poor pictures
even though the numbers behind them are sound. Worth re-shooting at a quieter
tick before you judge the look of the contact cores by eye.

---

## SG-108 — the freeze is fixed, and three published numbers did not survive it

*opus/SG-108, 2026-08-03. Every figure below was measured with the scene
genuinely still: `still · two plates of a frozen scene differ by exactly zero`
prints **0.00%** on every run of every tool that produced them, and each tool
now REFUSES to report anything if it does not.*

**The short version: the freeze was real, the fix was real, and two of the three
answers that rode on the old noise floor came back different. One of them
contradicts a decision that has already shipped. None of the tuning has been
touched — that is yours to call.**

### 1. SG-101's "residual that is not the marks and has not been found" — FOUND

It was the AnimationPlayers. SG-107's guess was right.

| | old (unfrozen) | now (floor 0.00%) |
|---|---|---|
| what the marks cost a telegraph rune | **9.1%** (11.5% before the halving) | **+0.02%** |
| of the planking ring, how much the marks darken | not measured | **0.0%** |

It is not a small correction, it is the whole number. And it has a consequence
you should know about: **the halving was decided on noise.** SG-101 took the
pre-committed "the density drops" branch — `MARK_CAP` 48 → 24 and
`MARK_ALPHA_MAX` 0.30 → 0.12 — because the marks appeared to be costing 11.5%
of a rune's legibility. They were costing roughly nothing, then and now.

At the shipped tuning I cannot see a single mark in a real frame. Look at
`.shots/marks/marked-worst.png`: that is a wave-12 deck with the cap full AND
with the deepest mark this system can make stamped directly onto the planking
each rune is read against, and the deck reads clean. The marks ARE being drawn —
24 of them, the cap full, and `marked-worst.png` and `clean-worst.png` are
genuinely different files — they are simply too faint at alpha 0.12 to move a
planking pixel by the 0.004 of luminance the measurement counts as a change.

**So the open lever points the other way now.** `MARK_CAP` to 12 was on the
table; on this evidence it would take a feature that is already invisible and
halve it again. If anything the question is whether 24 / 0.12 is worth having at
all, or whether the alpha should go back up. **I changed nothing** — the row
said the deciding evidence is one playtest and not another rig, and that is
still true. The rig can now only tell you the marks are not costing you
legibility; whether they are worth seeing is a look judgement.

### 2. SG-107's rig kill-test — same verdict, but "the rig HELPS" was wrong

| | old | now |
|---|---|---|
| what the lattice costs a rune, full light | **−0.47%** (an improvement) | **+0.88%** (a cost) |
| … at the wave-8 darkness floor 0.22 | **−2.67%** (an improvement) | **+0.29–0.57%** (a cost) |
| of the planking ring, how much the lattice darkens | **18–22%** | **9.2–9.9%** |

**The rig still passes its gate comfortably** — nothing here is near 3%, so the
decision to ship it stands and nothing needs undoing. But the claim on the board
that the lattice *improves* rune contrast, and that it darkens a fifth of the
planking ring, are both artifacts of the boarders moving. It costs a little, as
you would expect a shadow to.

### 3. SG-107's shadow kill-test — THIS ONE CONTRADICTS WHAT SHIPPED

| | old (floor 3.07%) | now (floor 0.00%) |
|---|---|---|
| batch OFF vs today, no ordnance | 1.91% | **1.70–2.09%** |
| batch OFF vs today, ordnance in flight | **4.88%** | **1.85–2.16%** |
| corrected vs today, ordnance in flight | **11.76%** | **2.18–2.28%** |
| corrected vs OFF, ordnance in flight | **9.62%** | **2.00–2.30%** |

The no-ordnance figure reproduces almost exactly. **The ordnance figures do
not** — and those were the evidence for keeping the shadow layer whole. SG-107's
row reads *"VERDICT: THE AUTHORITY SHIPS WHOLE"* on the strength of 11.76% and
9.62%. On a still scene every one of those numbers is under the item's own 3%
gate, in both passes, on four consecutive runs.

By DECK-IDENTITY item 2's pre-committed rules, that means two branches fire that
were reported as not firing: the **delete gate** (OFF is not measurably worse
than today) and **"only the height falloff ships"** (corrected differs from
today by under 3%).

**I did not delete the layer and I did not change the code.** SG-107's actual
argument for keeping it was never the 11.76% — it was §13c: a projectile's mark
must sit under the bolt because that is what tells you where it will cross you,
and a painted billboard casts nothing at all so its blob is the only thing
holding it to the planking. Neither of those is a claim a pixel count over
FIGURES can settle, and neither is weakened by the numbers above. But the row's
stated evidence is gone, so the question genuinely returns to you:

> **Does the contact-shadow layer stay, on the §13c argument alone, now that the
> pixel measurement no longer supports it?**

My recommendation is that it stays, for §13c's two cases, and that the row stops
citing the 11.76%.

### The pictures you asked for

`.shots/sg107/shadow-today.png`, `-corrected.png`, `-off.png` — re-shot at a
quiet tick. The old set caught the captain mid-swing and a fire arc filled the
middle of the frame; these have no effect in them at all, so the contact cores
under the figures are actually judgeable. `shadow-ord-*.png` is the same three
with ordnance in flight, for §13c's half.

