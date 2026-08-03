# NEEDS ALEX — the morning list

_Written 2026-08-02, ~23:15, as you went to sleep. Build 48 is live on itch._

Everything here is either **a decision only you can make** or **a verdict only
your eyes can give**. Nothing in it blocks the loop — there is plenty to do
without any of it.

---

## 1 · Play build 48 and judge five things

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
   every width, from tonight's menu rebuild narrowing the banner's interior.
   Already diagnosed; it is a width fix.
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

**Builds 32 → 48. Harness 499 → 851.** The deck went from half-painted to
all-mesh, and **every figure you modelled yourself was wired the same day you
made it** — the hulk's three states, the furnace knight, the crew, the goblins,
the drone, the Colossus, and a five-ship fleet.

Every dying thing on this deck now has a death. As of tonight, nothing vanishes
— it fades.
