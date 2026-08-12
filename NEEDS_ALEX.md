# NEEDS ALEX

**Build 70 live (`70-demo-polish-pass`, #1875503) · harness 1202/1202 · Field and
Pulse passed your G5 on 2026-08-11.** Detail lives in `skygear-godot/docs/BOARD.md`.
This file is only your decisions.

*Last cleaned 2026-08-11. Everything you answered is off this list.*

---

## What is in build 70, and what to look at

**Ten fixes, all from the 2026-08-11 demo-readiness audit.** The exe now has an
icon and calls itself SkyGear rather than "SkyGear Godot Port"; the title screen
no longer says GODOT PORT or "Milestone 1"; **every menu hover has sound for the
first time in the life of the port** (the code asked for `card_hover.ogg`, which
has never existed on disk, and `play_sfx` swallowed the miss silently); F3 and F4
no longer open the profiler and the layout editor in a shipped build, and the
pause sheet has stopped *telling you to press them*; RESTART RUN and QUIT TO
TITLE now take two presses; the title's last line no longer draws off the bottom
of the canvas after your first victory; and the exe no longer carries the test
suite and every probe inside it.

**AB-04 CLEAVE IS IN THIS BUILD AND HAS NOT BEEN REVIEWED.** The Captain's arc is
now a two-beat combo: the odd cut swings twelve degrees to port for 20, the even
one twelve degrees to starboard for 24 if the body is inside 110 units and 20 if
it is not — so two connected close swings still total the 44 it always did, and
fighting at the edge of your reach now costs you four. A miss does not advance
the beat. **IT HAS NOW BEEN REVIEWED — and it needs twenty seconds of your
eyes, item 5 below.** Both critic passes ran on 2026-08-11, serially this time so
they could not repeat the freeze. Systems: **PASS**. Presentation: **FAIL, then
PASS after one fix.** The tell that says which side the next cut enters from was
a 25-pixel, 0.30-alpha ember notch on ember-lit orange planking — the critic
hunting for it *with the diff open* logged it as a deck prop. It is now a pale
half-white wedge at 0.80, pinned by a check that fails if anyone dials it back.
Harness **1203/1203**, verified by me rather than quoted. **Cleave is reviewed
and unapproved — G5 is yours and I have not invented it.**

**Two things I could not fix without you** are items 3 and 4 below.

---

## Waiting on you

**0 · SEVEN ART PICKS, AND NOTHING GETS INGESTED UNTIL YOU CALL THEM.** The
Loom was never short of assets — it was pointing at a folder that no longer
existed. **33 already-paid generations were sitting on disk**, four candidates
each, and they cost nothing to recover. Contact sheets are built, one per
asset. My picks, argued rather than guessed: `ui_plate_wide` **2** (thinnest
border, most room left for text), `ui_plate_slot` **4** if you want the top tab
to hold the key binding else **2**, `ui_bar_housing` **4** — and **not 3 at any
price**, its leather straps cross the interior and a fill bar sliding under
them will read as broken — `ui_pressure_dial` **1**, `weapon_cutlass` **2**,
`weapon_gearblade` **2**, `weapon_boarding_axe` **3**. **One thing to settle
first:** every file these would replace already exists in `assets/art/ui/`,
while `forge.py list` insists they are "0 delivered". I did not overwrite your
live art on the strength of a contradiction I cannot explain. Board **SG-240**.

**0a · THE CUTSCENE NEEDS ONE ANSWER BEFORE SHOT 3 ROLLS.** Chibi proportions
like the sprite (identity-safe across five captain shots) or naturalistic
heroic (better trailer tone, real drift risk)? The rest of the package is
built: 9 shots, 50.04 s of footage plus a title card, under your 60 s ceiling.
It found the motive in your own material rather than inventing lore — the
Colossus's recorded *"GIVE ME THE ENGINE."* is the only stated motive that
exists anywhere in the game. **No new VO needed.** `docs/cutscene/`.

**0b · THE CAPTAIN'S PORTRAIT IS THE LAST PIECE OF THE GENDER FIX.** Casting,
voice and text are done and in the game — Will is installed, 50 takes, harness
green. `portrait_corsair.png` is still a red-haired woman in a blue coat, and
it is the **only** portrait in the project, which is why the Boilerwright wears
it too. It wants redrawing, not recolouring. Board **SG-228** / **SG-105**.

**5 · CLEAVE G5 — YOU ANSWERED THE FIRST QUESTION: "the cleave indicator is
correct."** That retires the packet's kill condition on your own eyes rather than
a critic's, and it is the answer that mattered most. **But the same look found a
new P1** — *"the vfx is triggering behind the player?"* — which is the swing
effect, not the tell, and is now **SG-226**; it reproduces in our own captures
(the arc sweeps south while the bodies taking damage stand north). Still open for
you, when you next play: **(b)** is 24-versus-20 something you *feel*, or only
something the floaters told you? **(c)** does anything hide the marker when you
fight beside the Boiler? The original ask, kept for context:
This is the last gate on AB-04 and no automated pass can stand in for it. Play
until boarders are actually reaching you, then answer: **(a)** without looking at
numbers, which side is the next cut coming from? **(b)** did you notice when you
stood close and got the big one — is 24-versus-20 something you *feel*, or only
something the floaters told you? **(c)** does anything hide the marker when you
fight beside the Boiler? Two critics disagree in a way only you can settle: the
tell reads at a glance on open deck, but in a crowded frame both critics had to
*hunt* for it for a second or two, and the Boiler's dome clips its lower edge.
I filed that as **SG-225** rather than quietly widening the fix. If (a) is "no",
the packet's own kill condition is back on the table. Board **SG-208**.

**1 · The upper deck's bay is thicker than the spec asked** — 0.57 as thick as
it is wide against "about a fifth". It costs nothing (it is all over apron you
cannot walk on) but a thinner bay would read taller. Only worth a reroll if it
bothers you when you look at it.

**2 · Heat 5 is a wall, not a rung.** Heats 0–4 sit in a 20-point band, then
Heat 5 holds **0 of 120 runs**, dead on wave 4 every time. You can judge this
yourself now — SETTINGS → **OPEN ALL HEATS** → any rung. A run above your earned
rung banks nothing, and having the switch on never voids a normal run.

**3 · What is in the demo?** There is no demo build — the one export preset
ships 100% of the game, and there is no gating seam in the code to hang one on
(`grep -i demo scripts/` returns nothing). Upload today's exe as a demo and you
hand over both heroes, the Colossus, the Workshop, Articles, fittings, and the
whole Heat ladder via OPEN ALL HEATS. **You already wrote a cut** — in
`docs/STEAM-LAUNCH.md`: *waves 1–6, Captain only, Heat 0, no fittings or berths,
results screen intact, end card naming what the full game has.* That has never
been a decision, only a proposal, so nobody has built it. Say yes to it, change
it, or say the demo is a later problem. Board **SG-213**.

**4 · The exe needs an icon, and it needs your eye once.** It currently ships
with **no icon at all** (the stock Godot logo in the taskbar and on the launch
splash), the product name *"SkyGear Godot Port"*, the description *"SkyGear v11
Godot port - Milestone 1"*, version `0.1.0.0`, and empty company and copyright.
Everything except the icon I can fix without you. The icon is an art asset and
those are yours — and the Loom is still not on this machine. A 256×256 is all it
needs. Board **SG-210**.

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
- **The Boilerwright speaks in the Captain's voice**, for the whole run — every
  player-facing key in `voice.gd` points at `captain/…` and there is no
  `boilerwright/` folder. Routing his keys to his own root makes him **mute**
  until takes exist. Wrong voice, no voice, or leave it until there are takes?
- **Every string in the game is Godot's fallback font**, on hand-authored brass.
  A display and a body face is a purchase and a taste call, and it moves every
  measured heading width, so it wants to be early or last — not in the middle.
- **A 4-damage Field tick and a 90-damage crit Mortar draw the same two sizes**
  — the floater's size argument is the crit flag, never the magnitude. Banding
  it by damage is a taste call, not a defect.

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

**Field and Pulse are in.** *"I approve of field and pulse changes. Those are
unblocked now."* (2026-08-11.) That one verdict passed both G5 gates: Field may
claim the last committed active landing instead of following you, and an
accepted active cast pulls every equipped Pulse discharge forward by 0.35 once.
SG-206 and SG-207 are HUMAN-VERIFIED and off the Active board. **It also freed
the packet behind them** — Cleave (AB-04) was sitting on the queue-order gate
and can now finish on its own evidence. **What it did not do is publish the
combat train**: that is still held by the combined IN-00 audit, which wants
AB-01–04, EL-00–03 and RF-01 all stable, and AB-04 is the one in hand. So
nothing goes to a public build on the strength of this verdict alone.

**Beam feels sweet.** The four-tick channel, 60% ordinary movement and
dash/Bleed Jet escape passed your hands-on gate on itch build 66. AB-01 is
accepted; later combat publication still waits for the combined IN-00 audit.

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
