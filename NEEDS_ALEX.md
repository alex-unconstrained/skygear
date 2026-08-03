# NEEDS ALEX

**Build 58 live · harness 1023/1023.** Detail lives in
`skygear-godot/docs/NIGHT-LOG-2026-08-03.md` and `docs/BOARD.md`. This file is
only your decisions.

*Last cleaned 2026-08-03 after your review pass. Everything you answered has
been taken off this list and is either done or being built right now.*

---

## Waiting on you — and two of them are just waiting on pictures

**1 · The bow, the stern and the mast.** You asked to see them, and to see them
*against* the procedural shadow casters so there is something to judge. Being
rendered now — same frame, same light, same pose, only the piece changing. When
they land, the mast question is the real one: should yours **replace** the
procedural casters, **feed** them, or **stand beside** them?

**2 · The shininess question — examples being rendered.** You asked what this
actually looks like, which is fair. The short version: all 27 models ship with
metalness unset, which the file format reads as *fully metallic*, and this deck
is lamp-lit with almost nothing to reflect — so those surfaces return no light
and read as a hole rather than an object. That was the Colossus's texture bug.
Fourteen others are in the same state. You are being shown the same model
clamped and unclamped so you can say whether brass and blades get to stay shiny.

**3 · Heat 5 is a wall, not a rung** — Heats 0–4 sit in a 20-point band, then
Heat 5 holds **0 of 120 runs**, dead on wave 4 every time. You said you have only
ever played Heat 1, so **the ladder is being unlocked for you** — you will be
able to jump straight to any Heat and answer this from the deck instead of from
my table.

---

## Smaller calls, whenever

- **Menus** — the title is rebuilt; Settings / How to Play / Controls / Pause are
  untouched pending your verdict on the direction.
- **Crew strafing** — four clips are wired up and unused on purpose. Want them?
- **Enemy bolts** — size is fixed; the style proposal is a hard ink rim plus a
  hot leading spike. Yes?
- **COLD DECK deals a draft with no weapon in it in ~31% of runs.** Intended?

---

## Only you can unblock

- **The Aether Loom** — not on this machine. Either copy the server folder over
  from your other device, **or paste an image-API key** and I will rewrite
  `forge.py` to call the API directly and retire the dependency. Recommend the
  key. Wanted for the four HUD pieces and a real bug: the Boilerwright wears the
  Corsair's portrait.
- **Your cutlass fit** — still uncommitted (29 lines in `weapons.json`),
  preserved through every build. Re-fit and say the word.
- **Steam** — start the Steamworks paperwork whenever you want the clock
  running; it is the only critical path (the tax interview alone is 2–7 business
  days). Full plan in `docs/STEAM-LAUNCH.md`. **Send friends the itch link, not a
  Steam key** — keys need a three-week wait for a first-time dev.

---

## What you decided today, and what it turned into

**CRIT STAYS. SG-148 is being reverted.** You were right to stop it. It had taken
crit away from six secondary damage sources — the kill explosion, the vent, fire
pools, kegs, the lane cannon and the crew — and the *only* argument for it was
that the browser build did it that way. That is not a good enough reason, and I
have written the rule down so it does not come back: **browser fidelity is no
longer a rationale for anything, mechanics included.** SG-147's real fix (a crit
explosion could crit its own explosion, forever) survives the revert.

**The Colossus keeps his health and stops being a meat shield.** Your design:
he ignores the captain, walks for the middle, kills the cannon, then goes for the
objective — and his damage becomes an area around him, so closing to kill him is
what costs you. Being built. Worth knowing: the lane-walk half already existed,
built and shipped **off**, because on its own it took his damage to the player to
a structural zero. Your area-damage idea is exactly the missing half.

**The furnace knight gets his health.** Measured: he has 342 effective health at
wave 11, lives 3.1 seconds, and his attack cycle is 1.9 — so across his whole
life he lands **one** swing. Nothing is wrong with his hit; he simply dies before
he can use it. Roughly doubling him buys three swings. Being built.

**The rail ships at N = 10.** "It looks great. I think size 10 is good." Done.

**Fire: the picture moves, not the damage.** Drawn at 46, burns at 78 — the
drawing grows to match. No balance change.

**Telegraphs: you liked them, and the edges are being hardened.** "The edge of
that should be very clear to the player... lined with something a little harder,
as opposed to that soft edge." Agreed and being done — the boundary of a danger
zone is the most important line in the game, and a soft gradient makes "am I in
it?" a guess. The rule being applied is one already written down for the rings in
this codebase: *a fill you can see through and an edge you cannot miss.*

**Your three weapon models are in.** The pike, the axe and the wrench are
ingested from Downloads and being fitted — the crew, the furnace knight and the
gremlin have had empty hands until now.
