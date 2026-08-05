# NEEDS ALEX

**Build 64 live · harness 1133/1133.** Detail lives in `skygear-godot/docs/BOARD.md`.
This file is only your decisions.

*Last cleaned 2026-08-04. Everything you answered is off this list.*

---

## Waiting on you

**1 · The deck edge — pick one, it is built and switched off.**
`skygear-godot/.shots/owner-review/5-deck-edge-rail/`. Your rail reused in place
of the flat mustard boxes you photographed. Two halves, independently switchable:

- **The breast rail** — the bar across the frame in your screenshot, as 14 of
  your modules. **This is the one I would take.** The boundary runs unbroken and
  you see the deck through it instead of over it. 85,680 tris.
- **The strake capping** — the long run down both deck edges, as a low run under
  the main rail. It works, and only at matched pitch (halve the pitch and it
  reads busy). But it is **barely noticeable at mid-deck**, where you actually
  play, and costs 61,200 tris. I would skip it.

Both default OFF. Say which and it is one word. Option A's retint already
shipped, so what you have in 62 is the toned-down flat version.

**2 · The upper deck's bay is thicker than the spec asked** — 0.57 as thick as
it is wide against "about a fifth". It costs nothing (it is all over apron you
cannot walk on) but a thinner bay would read taller. Only worth a reroll if it
bothers you when you look at it.

**3 · Heat 5 is a wall, not a rung.** Heats 0–4 sit in a 20-point band, then
Heat 5 holds **0 of 120 runs**, dead on wave 4 every time. You can judge this
yourself now — SETTINGS → **OPEN ALL HEATS** → any rung. A run above your earned
rung banks nothing, and having the switch on never voids a normal run.

---

## Smaller calls, whenever

- **The crew look stacked.** They stand one man per lane on purpose: spreading
  the idle watch ±120 apart cost **24% of their damage and 17% more damage
  taken**, because a stacked watch is four swings landing on one boarder with no
  walking between. Making it *look* like a watch is buyable renderer-side
  without moving the simulation. Want it?
- **RESIDUE buys nothing measurable.** A fire pool's `dps` has never been read by
  anything — every pool burns at a hardcoded 7.5 while RESIDUE authors 13.0 per
  stack. That is a damage rate and you were explicit about which side moves.
- **Menus** — the title is rebuilt; Settings / How to Play / Controls / Pause
  are untouched pending your verdict on the direction.
- **Crew strafing** — four clips wired up and unused. The lane-assist work
  created no case for them (travel and threat are still one vector). Want them?
- **Enemy bolts** — size is fixed; the style proposal is a hard ink rim plus a
  hot leading spike. Yes?
- **COLD DECK deals a draft with no weapon in it in ~31% of runs.** Intended?

---

## Only you can unblock

- **The Aether Loom** — not on this machine. Copy the server folder over, **or
  paste an image-API key** and I will rewrite `forge.py` to call the API directly
  and retire the dependency. Recommend the key. Wanted for the four HUD pieces
  and a real bug: the Boilerwright wears the Corsair's portrait.
- **Steam** — start the paperwork whenever you want the clock running; it is the
  only critical path (the tax interview alone is 2–7 business days). Full plan in
  `docs/STEAM-LAUNCH.md`. **Send friends the itch link, not a Steam key** — keys
  need a three-week wait for a first-time dev.

---

## Things you should know, no action needed

**Your run history was destroyed by our own harness, and it is not
recoverable.** Every harness run cleared `runs.json` and refilled it with test
fixtures; your log is now five rows and all five are ours. `keys.cfg` and
`workshop.json` were being written too. All four files are diverted to scratch
copies now, proved by a full-tree checksum that comes back identical across a
run. It will not happen again. I am sorry — it was happening while I was
reporting clean runs at you.

**Two numbers I gave you were overstated.** The measuring rigs turned out to be
deterministic, so `reps` never bought sample size — "612 runs an arm" was n=6
repeated. The *directions* of today's findings hold (they are large and
independently measured); the decimal places do not. The tools now refuse to
print a verdict their sample cannot support.

**The pause and settings screens write your config file every frame** while you
are on them. Disk thrash on every player's machine, and it is what made a flaky
harness check hard to diagnose. Filed, not yet fixed.

---

## What you decided, and what it turned into

**CRIT STAYS** — SG-148 reverted, the gate deleted rather than switched off.
Crit-built captains kill the Colossus 7.8% faster and take 13.9% less in wave 12.
The rule is written down: browser fidelity is not a rationale for anything.

**The Colossus walks the lane and stomps.** He ignores you, goes for the cannon,
then the objective. Measured: **21% more dangerous and the run 12.7 points
easier** — because an escapable circle has no tail of runs where he corners a
kiting captain. Your run then caught that his stomp was preempting his own swing
and leaving him at 32% of his swing rate, so he never actually destroyed a
cannon. Fixed: 208 → 442 cannon damage a minute.

**The furnace knight got his health**, and your "too fast" note found something
much bigger: **every boarder's swing was accelerating mid-swing** to a 4× clamp
and playing 2.5 times per hit. Now constant at 0.75–0.96×, simulation untouched.

**The rail ships at N = 10. Your prow is on the ship.** Your stern is not, and
that finding is worth more than the piece: **this camera never sees the outside
of the hull.** Two sterns of completely different proportion failed identically.
Nobody should model a hull, transom or counter for this game.

**Clamp them all** — 17 models plus the procedural deck, which had never been in
that audit and was shinier than every model standing on it.

**Your mast shadows win**, over the analysis that recommended otherwise.

**Your three weapons are in hands**, and the lab opens on the right figures now.

**The upper deck is built** from your four pieces plus your rail — a forecastle,
not a lid, because five posts carry it to lit brass foot plates and your stair
cuts diagonally through the middle.

**The hulk dies in 16.7 s** instead of 28.3: the cast path has always ended in a
hull-splash call and the basic attack never got that line.

**The crew leave a cleared lane** and no longer swing at bare planking.
