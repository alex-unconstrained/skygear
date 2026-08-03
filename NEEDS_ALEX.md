# NEEDS ALEX

**Build 58 live · harness 997/997.** Everything else is in
`skygear-godot/docs/NIGHT-LOG-2026-08-03.md`. This file is only your decisions.

---

## Decide these five — they unblock real work

**1 · The Colossus's health.** He is 2900 now (was 900). Fight went 9.8s → 23.8s.
Bot hold-rate 100% → 66%. **1800 buys most of the menace for a third of the
cost.** Keep 2900, or go to 1800?
→ *But see the bug list below: you say he never hits you, and that changes what
this number even means. You may want to answer this after that is fixed.*

**2 · The rail's size.** Your rail sits with its cap at **83% of the captain's
height**. The spec wanted lower. It cannot hide her either way (the camera
tracks her, the rails are outside where figures walk), so this is purely how you
want it to look. Renders are coming to you — pick one.

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

## Smaller calls, whenever

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
- **The ally-share mystery** — your real run read 58%, the fixed rig reads 13%.
  **What was your crew count and draft in that run?**

---

## Known bugs, being worked — nothing needed from you

**Melee enemies do not hit you.** Your report: you stood next to the Colossus
and the furnace knight and took nothing. Our own rig measures the Colossus
dealing 123 damage a fight, so **the rig and you disagree and one of us is
wrong** — being investigated now, top priority.

**Telegraphs are not clear enough.** Your words. Being worked.

Everything else is on the board.
