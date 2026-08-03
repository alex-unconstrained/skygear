# NEEDS ALEX

**Build 58 live · harness 1023/1023.** Everything else is in
`skygear-godot/docs/NIGHT-LOG-2026-08-03.md`. This file is only your decisions.

---

## Decide these five — they unblock real work

**1 · The Colossus's health.** He is 2900 now (was 900). Fight went 9.8s → 23.8s.
Bot hold-rate 100% → 66%. **1800 buys most of the menace for a third of the
cost.** Keep 2900, or go to 1800?
→ *Answered, and it changes the question: **he does hit you.** Measured with a
captain standing still next to him, he lands **11.8 swings for 306 damage** in
his life — three times your health bar. Standing next to him kills you in 8
seconds. The reason he felt harmless is that you were **moving**: his swing aims
once, when the wind starts, and never re-aims, so a captain who walks is hit by
**1 in 3**. That is deliberate (it is what makes him dodgeable) and I did not
touch it. So 2900 vs 1800 is a real question again — my read is KEEP 2900.*

**1b · The furnace knight — you were exactly right, and it is not the hitbox.**
It has **342 health at wave 11 and lives 3.1 seconds**. Its attack cycle is 1.9
seconds. So in its entire life it gets **one swing**, for 34 damage, once. SG-97
gave it a slow 0.9s tell and called it *"a wall you read"* — **but nothing
survives long enough to read.** Nothing is wrong with its swing: standing next
to it, 60 of 60 swings land. It is purely health. **My recommendation: roughly
double it, 180 → 360**, which buys it ~6 seconds and three swings instead of
one. That is a balance change and it is yours, so I did not make it.

**2 · The rail's size — the renders are here now, pick one.**
`skygear-godot/.shots/sg157/scale-8`, `scale-10`, `scale-12`. Your rail is on
the deck and the two solid side bars it replaces are gone. The tiling is
arithmetic, so only whole tile counts divide the deck evenly and there are just
three worth looking at:

- **N = 8** — rail top at **89% of the captain**. The 290-unit tiling already established.
- **N = 10** — **71%. THIS IS WHAT SHIPS pending your eye**, because it is your own spec arrived at from the other end: DECK-IDENTITY item 4 asks for two rails at y = 66 and 118.
- **N = 12** — **59%.** Lowest, and it starts reading as a fence rather than a ship's rail.

It cannot hide her at any of them (the camera tracks her, the rails are outside
where figures walk), so this is purely how you want it to look.

**The bow, the stern and the mast are NOT placed**, and all three are refusals
with frames behind them rather than omissions — `bow-cut`, `stern-trial-s1.0`,
`stern-trial-s2.5`, `mast-trial` and `MAST-trial-vs-shipped.png` in the same
folder. Each reads badly at this camera. The mast is wired up behind a switch
that is **default OFF**, and the open question is whether yours should REPLACE
the procedural shadow casters, FEED them, or stand beside them — say which and
it is one line.

**3 · Fire's hitbox.** A fire pool **burns you from outside its own picture, by
up to 70%** — drawn at 46, burns at 78. Fix the damage to match the picture, or
the picture to match the damage? Both change balance.

**4 · Fourteen models are shinier than this deck's light allows.** All 27 ship
with metalness unset, which the format reads as *fully metallic* — that was the
Colossus's texture bug. Do the other fourteen get clamped too, or do some things
(brass, blades) get to stay shiny?

**5 · Heat 5 is a wall, not a rung.** Heats 0–4 sit in a 20-point band, then
Heat 5 holds **0 of 120 runs**, dead on wave 4 every time. Is that intended?

---

**6 · Making the telegraphs clearer — ✅ BUILT, you said go. Look at
`skygear-godot/.shots/sg158/v3/`.** Put `4-strike.png` next to `5-recover.png`
for either enemy. A melee exchange is three beats now instead of one:

- **The wind-up** — the red wedge, unchanged.
- **The strike** — an orange band along the *rim* of that wedge on the frame the
  damage lands. The rim on purpose: it is the one part of the wedge the enemy's
  own body cannot cover, and it is where you are standing when the blow arrives.
  Spent in a fifth of the recovery, so it can never read as the next warning.
- **The opening** — a **teal** ring on his own footprint, held through the
  recovery and fading as the window closes. Teal because it is the only mark in
  the game that says "now hit HIM", and red has to keep meaning danger.

Six new checks hold it. **What it looked like before is below**, kept because it
is the reason the shapes are what they are:

- **There is no "hit" visual at all.** The warning wedge is drawn only while the
  enemy is winding up. On the frame it actually strikes you, the wedge is simply
  **deleted** and nothing replaces it. Your whole visual account of being hit is
  a warning disappearing. The second of recovery afterwards — the window you are
  meant to punish — is unmarked too.
- **The enemy stands on top of its own warning.** The wedge is painted on the
  deck, and at our camera angle the enemy's body is between you and that patch of
  deck. The Colossus hides nearly all of his; the knight most of his.

**One thing changed from the plan, and the frames are why.** The recovery mark
was going to be a dim wedge on the deck. Built that way it was *invisible* — a
wedge is painted on the planking the boarder is standing on, which is the very
occlusion above. So it became a ring on his own footprint instead: a ring reads
as a property of HIM rather than of the deck, and it survives a body standing in
it. It has to be wide, too — at 1.5× his radius his feet still covered all of
it, and 2.5× is what clears him. There is a check pinning that now, because a
mark nobody can see is the failure mode this whole item is about.

---

## Smaller calls, whenever

- **Restoring the browser's `noCrit` rule made crit builds harder, and I did
  not compensate (SG-148).** Six secondary damage sources — the kill
  explosion, the vent, fire pools, kegs, the lane cannon and the crew — have
  been able to crit in this port and cannot in the build these numbers were
  tuned against. All six now obey the original. Measured, 612 runs an arm:
  for a **crit-built** captain the Colossus takes **12.6% longer** and the
  Heat 0 hold rate falls **83.5% -> 76.3%**. For everyone else the difference
  is too small to measure at that sample. **Keep the fidelity, or buy the
  seven points back somewhere?** Numbers in `docs/NIGHT-LOG-2026-08-03.md` §15.

- **Menus** — the title is rebuilt; Settings / How to Play / Controls / Pause
  are untouched pending your verdict on the direction.
- **Crew strafing** — four clips are wired up and unused on purpose. Want them?
- **Enemy bolts** — size is fixed; the style proposal is a hard ink rim plus a
  hot leading spike. Yes?
- **COLD DECK deals a draft with no weapon in it in ~31% of runs.** Intended?
- **The Colossus's lane-walk** — built, measured, and shipped OFF because it
  failed its own test. One word turns it on.

---

## Only you can unblock

- **The Aether Loom** — it is not on this machine. Either copy the server folder
  over from your other device, **or paste an image-API key** and I will rewrite
  `forge.py` to call the API directly and retire the dependency. Recommend the
  key. Wanted for the four HUD pieces and a real bug: the Boilerwright wears the
  Corsair's portrait.
- **Your cutlass fit** — still uncommitted (29 lines in `weapons.json`),
  preserved through every build. Re-fit and say the word.
- **Steam** — start the Steamworks paperwork whenever you want the clock
  running; it is the only critical path (tax interview alone is 2–7 business
  days). Full plan in `docs/STEAM-LAUNCH.md`. **Send friends the itch link, not
  a Steam key** — keys need a three-week wait for a first-time dev.
- ~~The ally-share mystery~~ — **closed by your own run report, nothing needed.**
  It reads `crew and cannons 11%`; the repaired rig reads 13%. They agree, so
  the old 58% was stale rather than a balance finding. Bonus: your range split
  reads **23% close** against the bot's **22%** — the bot now plays like you do,
  which means the numbers we have been quoting all day rest on an instrument
  that has finally been checked against a human.

---

## Known bugs, being worked — nothing needed from you

~~**Melee enemies do not hit you.**~~ **Answered — items 1 and 1b above.** The
rig and you were measuring two different players: it reports what the *bot*
experiences, and the bot kites while you stood still. Nothing in the hit path
was broken.

~~**Telegraphs are not clear enough.**~~ Your words. **Built — item 6 above.**

Everything else is on the board.
