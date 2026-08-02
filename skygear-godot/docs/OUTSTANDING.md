# What was asked for, and whether it is done

Every item here came from a playtest or a direct request. Nothing goes in from
me having an idea.

**Why this file exists.** The skybox was reported twice and slipped twice. The
aesthetic audit — the original job — was quietly dropped somewhere around the
fourth feature. Both happened for the same reason: I kept picking the next
interesting thing, and there was no list to pick from instead. A list I write
into is not a process fix on its own, but it is the part that was missing.

**The rule:** an item leaves this file when it is done or when it is explicitly
dropped with a reason. Not when it is partly done, and not when it stops being
interesting. `SkyGear Tools.bat todo` prints the open ones.

---

## Open

### The variety direction, from the owner — enemies vary the run, the ship changes between runs
Answered 2026-08-02, 00:30, when asked whether to resurrect the cut stowage
spine: *"When you're talking about deck variety, it should be minor deck
variety within waves because the ship itself shouldn't change during the
playthrough that much. It should be more based on the enemies. The ship
modification should happen in between runs. As you complete all twelve waves,
you would want to see modifications and changes and upgrades that can be made
to the ship itself."*

Three consequences: (1) the stowage spine stays CUT — per-wave deck shuffling
was the wrong axis, the kill-test and the owner agree; (2) run-to-run variety
work goes to the ENEMY side (composition, mutations, behaviors — the plan's
figure thread grows a variety limb; needs its own design pass); (3) the
fittings system is UNBLOCKED and reframed: fittings are between-run ship
modifications earned by finishing waves, visible on the deck at run start,
never changing mid-run. POST-PARITY-PLAN items 3/5 proceed on that basis.

### The editor can't REACH the screens — round two of the alignment ask
Reported 2026-08-01, after SG-42 shipped: *"You still didnt fix the screens
tool to allow me to interactively edit UI/text."* SG-42's "you edit the
screen you are ON — the game navigates" rule is the miss: reaching the
results screen means winning a run, reaching GAMEOVER means dying.

**SHIPPED 2026-08-02 (board SG-44) — left OPEN for your hands-on verdict,
like SG-42 itself.** Press **P** inside F4 and pick any of the 23 screens the
audit shoots — the list IS the audit's list, posed by ONE shared poser
(`scripts/screen_poser.gd`) that the text audit, the batch camera and the
editor all call, so a second drifting copy cannot exist (harness-pinned).
Picking poses the screen live on a SANDBOX — real widgets, real strings,
never your run — and the SG-42 editor works on it exactly as everywhere:
descend, drag, nudge, type, verdicts, Ctrl+S, F12. Offsets save under the
same screen id the real screen reads, so an alignment fixed on a posed
GAMEOVER is fixed on the one you die into. **Esc hands the game back
exactly** — mid-run included; the run's clock, boarders and RNG hold still
under the glass (the cutscene player's "camera comes back exactly" contract,
now a harness check). Try: F4 anywhere → P → "deck lost" → move something →
Ctrl+S → Esc. Full evidence on board row SG-44; `docs/HUD-LAYOUT.md` §"The
screen picker" is the how-to.

### UI alignment must be EDITABLE, not just photographed
Asked 2026-08-01 after running the screens audit: *"I got all of the
screenshots but I'm not able to directly edit/align content within UI
elements. Add this functionality as the primary purpose, and then the massive
screenshot dump is a secondary."*

**SHIPPED 2026-08-01 (board SG-42) — left OPEN for your hands-on verdict,
like the crate and the lab.** F4 now works on EVERY screen, and it reaches
INSIDE: on the fight HUD it is the plate editor you know; everywhere else
(title, draft, pause, settings, workshop, results, comparison, controls) it
captures the screen's own elements — labels, readouts, buttons, the card
emblem — as the screen draws them. Click a panel, click again for what is
inside; drag, arrow-nudge (Shift ×10, Alt ×0.1), or click the offset readout
and TYPE it (Enter applies, malformed refused). Ctrl+Z undoes, Ctrl+S saves
into the same hud_layout.json family (`SkyGear Tools.bat layout` promotes),
Ctrl+R resets the one screen, F12 photographs the screen you are fixing.
The verdict bar runs the text audit's own detectors live while you edit.
You edit the screen you are ON — the game navigates. The 84-shot dump stays
as the secondary batch-evidence mode (`SkyGear Tools.bat screens`). Full
evidence on the board row; docs/HUD-LAYOUT.md is the how-to.

### Projectiles look like cheap 2D sprites — the first ask of the post-parity era
Asked 2026-08-01 with a screenshot of the cartoon fireball bolts: *"Can we get
better VFX particles? Instead of these 2D sprites that look like they are
cheap? What did our VFX investigation into Godot yield for us?"*

The bolts are the browser's painted sprites billboarded into 3D — kept
because parity said keep them, un-blocked the moment parity was retired. The
research audit's architecture is already in place (emit_particle injection,
behaviour-keyed emitters, element motion signatures); what was never done is
making the projectiles THEMSELVES 3D — emissive cores, particle trails,
per-element light. Board SG-40, queued behind the lighting pass (same file).

**SHIPPED (SG-40, 2026-08-01) — awaiting your eyes; NOT closed.** Every bolt
head is a real emissive mesh now — a low sphere stretched into a teardrop down
its own velocity, glowing from its own light so the bloom catches it, with a
small omni under the nearest few. The painted fireball is gone from the default
path and kept only as the art-missing fallback. Element identity rides the
MOTION, not the hue: Ember is a fat throbbing ball shedding rising flecks,
Frost a long narrow shard with a tight sinking wake, Arc a hard slug flickering
fast, Steam a soft round billow; the enemy's inbound shot is a blunt oxblood
orb that sheds nothing (so a lane of them stays legible) and our cannon a tight
brass slug — theirs and ours never confused. Pools stay capped (24 cores, 6
lights), the ground shadow stays under every bolt, and the telegraphs and the
SG-34 lighting are untouched and green. Measured under a saturated wave (51
live bolts): p99 5.98 ms against the 16.7 ms budget. Before/after posed frames
in `.shots/vfx-sg40-before/` and `.shots/vfx-sg40-after/`. This stays OPEN
because YOU judge whether it reads better now — play it and say. Harness
517/517.

### The lab needs a usability pass — typed values, and yaw/roll collapse
Asked 2026-08-01, with a screenshot of MOUNT mode on the cutlass: *"Yaw and
roll here seem to do the same thing. I like the changes to the Lab, but I do
feel as though it can be made more user friendly. Allow me to type in values
as well. Send an agent to do a full improvement pass on the lab."*

The yaw/roll observation has a probable mechanical cause, not just a UI one:
the fit in the screenshot sits at pitch −96°, on top of the ±90° gimbal
singularity where the yaw and roll axes align — nudges that edit Euler
components will do the same thing there. Board SG-39: typed input on every
numeric row, rotation nudges applied about the weapon's live local axes
rather than Euler fields, and a general friendliness pass.

**SHIPPED (SG-39, 2026-08-01) — awaiting your hands-on verdict; NOT closed.**
The mechanical cause was confirmed by measurement: at pitch −90 the stored Euler
yaw and roll build the *same* basis to 1.6e-8 — genuinely one control, not a
perception issue. Three things are in the next build.

1. **The collapse is gone.** Every rotation nudge — the PITCH/YAW/ROLL buttons,
the A/D/W/S/Q/E keys, the wheel, and right-drag — now composes a turn about the
blade's OWN live local axis instead of incrementing an Euler field, so the three
rows always do visibly different things at any orientation (measured 0.59 apart
at the exact pitch that used to collapse). The file stays Euler, and your saved
cutlass fit loads to the identical pose it saved at — guarded so it cannot
regress.

2. **Type any value.** Click a number on any row — MOUNT's seven, the four LIGHT
rows, the nine FX dials — type it, ENTER applies, ESC or a click away cancels,
and a malformed entry is refused with the old value kept. One reused box, not
seven.

3. **Friendlier all round.** Hovering (or nudging) a rotation row lights the
matching coloured axis line on the blade so you can SEE which line it spins.
Shift makes every step ×10 and Alt makes it ×0.1, both spelled out in the header.
The wheel over a row nudges it. The dev-note instruction block was rewritten to a
plain hint. The "no size for this" line now reads as information, not an error.
And Ctrl+Z takes back the last nudge or typed entry.

Play it and say — if a control still fights you, that is the thing to name.

### The crate mechanics suck — the owner, after playing them
Reported 2026-08-01, verbatim: *"The crate mechanics kind of suck to be honest.
Don't like them at all, the hold to move is not fun. It's too easy to just get
stuck on the crates yourself and lose your ability to move between lanes."*

Two distinct defects in that: the 2.8-second hold-to-heave channel is not fun
as an interaction, and the crate collides with the CAPTAIN — which breaks
pillar 4 (cross-passages preserve mobility) for the one person the deck is
supposed to serve. The crate exists to shape the BOARDERS' movement, never
hers. Board SG-37; the rework replaces the channel with an instant shove and
makes the crate something she can never be trapped by. If it still is not fun
after that, the verb gets dropped with this entry as the reason.

**REWORK SHIPPED (SG-37, 2026-08-01) — awaiting your re-judgement; NOT closed.**
Both halves are in the next build. The channel is gone: the deckwork key at the
crate now SHOVES it instantly (the prompt reads "TAP", the coach says "TAP … to
shove"), the captain keeps moving and fighting, and a ~1s per-crate cooldown
replaces the seconds-standing-still as the cost — each tap still steps one stage
of stow→narrow→funnel→stow (a fixed distance per press). And she is NEVER blocked
by the crate: her collision now clamps only the eight fixed cargo walls and
excludes the movable crate entirely, so she slips straight through it while the
boarders stay fully funnelled by it (deliberate divergence, commented at the
site and pinned). This stays OPEN because YOU judge whether it is fun now, not
us — play it and say. If it still is not fun, it gets dropped with this entry as
the reason.

### The Boilerwright's mobility gap is 60%, not the 21% the numbers say
Reported at playtest as "Boilerwright feels slower", alongside "I'm not sure I
understand what the class actually does". The second half is fixed — the
comparison screen is built and Overpressure is a ring round the dial. The first
half turned out to be real and much larger than the stat sheet admits.

205 against 260 is 79%, and that is TOP SPEED — a number nobody experiences.
What a player experiences is ground covered while a lane walks down on them.
Measured over six seconds, `class · but ground covered against a dashing
captain is worse than that`: **he covers 40% of her distance.** `ACCEL` is
shared so he actually reaches his top speed faster than she reaches hers; the
entire gap is the dash.

The 33% first recorded here (2026-07-31) was a noisy sample: that measurement
read `global_position` after `move_and_slide()`, which steps by the engine's
real-frame physics delta rather than the 0.05 sim tick, so the ratio swung
across 200–570% run to run and 33% was one draw of it. SG-1 (2026-08-01)
rebuilt the measurement to integrate `|velocity| * 0.05` — the speed the sim
actually produces — which is bit-for-bit repeatable: captain 3076, boilerwright
1228, every run. The gap is real and the direction is unchanged; the corrected,
deterministic figure is **40% of her ground, a 60% gap**, not 33%/67%.

Read it as an upper bound: she dashes on every cooldown and he never spends
bank on the Bleed Jet, which is the widest the gap can be. But the jet costs
the bank that carries the multiplier the class is built on, so closing the gap
means giving up the reason to be the class — and that IS the trade the player
is feeling.

Not a bug and no numbers changed. It is a design question the measurement now
makes answerable: either he is compensated somewhere a player can feel, or the
comparison screen has to say plainly that he trades mobility for damage. What
must not happen is tuning it by feel — that is what the number is for.


### A cutscene tool — BUILT, AND ONE SHOT IS WIRED. Three trigger points are empty
Asked for: *"set up frame, key frame, camera movement… use the in-game renderer…
save those so that they can play at certain times during the game."* All four
halves are in. `SkyGear Tools.bat cutscene`.

- **Author.** A timeline with keyframes you add, drag in time, delete and scrub.
  Drag to orbit, right-drag to slide the shot across the deck, wheel to push in;
  every one of those numbers is also a labelled minus/plus row with its live
  value beside it, in GROUND UNITS. AUTO-KEY records a keyframe wherever you move
  the camera. Five easing curves per segment, because a linear camera reads as a
  machine on a rail. Nothing needs a key a laptop lacks.
- **The real renderer.** It instantiates `scenes/main3d.tscn` — the real deck,
  models, lighting and lens — the way the model lab's FX mode does. The STAGE
  panel puts the Colossus or three boarders on the planking so there is something
  to frame.
- **Saved** to `assets/cutscenes/<id>.json`, with an index beside it.
- **Played.** `scripts/cutscene.gd` is the reader and `scripts/cutscene_player.gd`
  drives the camera; both existed before the first file did. A shot names a `cue`,
  and the four cues are real call sites: `boss_arrival` in `game.gd::spawn_enemy`,
  and `wave_start` / `victory` / `defeat` watched in `view3d.gd::_watch_cues`.
  **`colossus_arrival` plays at wave 12** when the boss climbs aboard.

**DONE (SG-8, 2026-08-01).** All four cues now carry a shot, and the suggested
run opening was added as a fifth cue: `run_open` (2.5s establishing crane),
`wave_start` as a short milestone flourish narrowed to the event waves 4 and 8
(never wave 12 — it would suppress the Colossus), `victory` (a 5.4s crane-up to
the sky the deck framing never shows), and `defeat` (a 3.6s heavy push onto the
dying Boiler, held for the results screen). The run opening's one line of code
is a flag `begin_run` raises and `view3d.gd::_watch_cues` spends on the first
wave — it cannot fire from `begin_run` itself, which settles into the opening
draft where a cutscene is not allowed. Fifteen new harness checks, 463→478.

**Two things worth knowing before authoring one.** The camera CAN break the
shipped solve — a key carries its own field of view, height and roll — and the
gameplay camera is put back exactly when the shot ends, pinned by
`cutscene · THE GAMEPLAY CAMERA COMES BACK EXACTLY` and the four checks beside
it. And a key can be PINNED to the live gameplay camera, which is how a shot
hands back without a cut; the Colossus arrival ends on one.

### The lab needs animation and VFX playback — BUILT; one dial has no home
Asked for, and now built. `SkyGear Tools.bat lab`, three modes on three buttons.

- **Animation** plays. A timeline along the bottom in VIEW and MOUNT: click any
  of the fourteen clips, PLAY, drag the bar to scrub, STEP one 60th of a second
  at a time, and five speed presets down to a tenth. Mounting no longer resets
  the pose, so a weapon can be nudged AT the frame it slips. `--clip <name>
  --at <0..1> --shot <png>` renders one named frame headless, which is what a
  before-and-after on a grip needs.
- **VFX** loop. FX mode instantiates the real `main3d.tscn` — the real renderer,
  the real deck, the real camera — and fires the same `_fx` dictionary the skill
  code fires, on a period you set. Six shapes, four elements, and dials for
  radius, arc, life, damage, glow, particle size, particle lifetime and a
  slow-motion time scale. Nothing is re-implemented; a second copy of the effect
  code was the thing to avoid.
- **Modifiers** are exposed: wireframe, clay, flat lighting, a grid in GROUND
  units with a 176-unit ruler post, the skeleton drawn over the mesh, RGB axes
  on the selected bone, five backdrops, and the key light swung, raised and
  dimmed. Everything is a button or a drag; nothing needs a key a laptop lacks.

**What it still cannot do, and why.** The FX dials do not write to a file. Every
one of them is a *constant* in `view3d.gd` or a literal in a `_fx({...})` call,
and inventing a JSON for them would be the sixth time this project shipped a
table nothing reads. SAVE in FX mode puts the numbers on the clipboard next to
the exact constant they belong to instead. Giving them a real home means giving
the renderer a reader first — that is a renderer change, not a tool change.

**And one thing the lab found:** `ELEMENT_FX[*].life` in `view3d.gd` is dead.
Four elements declare a particle lifetime and `impact_at` never reads it — the
emitter's own `lifetime = 1.0` governs all three families. That is failure mode
one, already in the tree. It cannot be fixed by reading the field, either:
`emit_particle` has no per-particle lifetime flag, so honouring it means one
emitter per element rather than per behaviour.


### ~~THE CAMERA IS ZOOMED IN~~ — MEASURED, AND IT IS NOT. The claim was right after all
Kept as a record of a finding that did not survive being measured — the
popup-drift pattern again. I had said the camera was "ported exactly" from the
browser's `CAM.recompute()` solve, then the first parity run made me doubt it:
side by side, Godot *looked* like it showed less of the deck, so this entry
recorded a framing gap and made it upstream of everything else.

**There is no framing gap. The port IS exact.** Measured rather than eyeballed —
`tools/cam_measure.gd` puts a known ground length on screen in both builds at one
output resolution and unprojects it: the browser's own `CAM.project()` math and
Godot's `Camera3D.unproject_position` land **on the same pixel** for every length
tested.

| known length | browser px | godot px | ratio |
| --- | --- | --- | --- |
| deck full width 1680 @ focus depth | 3288.1 | 3288.1 | 1.000 |
| deck full width 1680 @ the bow | 1137.5 | 1137.5 | 1.000 |
| one lane 560 @ focus depth | 1096.0 | 1096.0 | 1.000 |
| bow→stern depth @ keel | 1695.7 | 1695.7 | 1.000 |

The captain's own ground point lands at the identical pixel `(960, 705.4)` in
both. No `WORLD_SCALE`, deck-rectangle, camera-distance or FOV discrepancy
exists, and no browser zoom-out was dropped.

**Why the impression, then.** The browser's focal length is not the bare 1320 —
`recompute()` sets `_f = f * View.unit` (`reference/web-source/_render_head.js:53`),
and `View.unit = clamp(min(w/1400, h/860), …)` scales it with the output
resolution. That is *exactly* what Godot's fixed vertical FOV of
2·atan(430/1320) already does at any 16:9 window, so the two frame identically at
every size. What actually differed was the picture the earlier comparisons were
made against: the browser side was long drawing its procedural sky FALLBACK
because Chromium blocked its `new Image()` loads over `file://` (now fixed in
`parity.py`, which serves over HTTP and asserts the art arrived) — every "the
camera is zoomed in" judgement was made against a stand-in render. Fresh
side-by-sides with the real art are in `.shots/parity/`.

Nothing was changed in the solve, deliberately — the two harness checks that pin
it (`camera · the lens is the browser's focal length`, 36.09°, and
`camera · the captain stands where the art was framed for`, 0.600 of screen
height) were confirmed to assert the CORRECT invariant, not the bug. The one real
residual the side-by-sides show — the Boiler PROP mesh reading larger than the
browser's flat `boilerH: 132` block — is a model-scale question, not a camera
one, and is board item SG-27.

One latent inconsistency noted while here, harmless: `parity.py` passes
`--resolution 1600x900` but the project's `canvas_items` stretch keeps the render
viewport at 1920×1080, so the Godot half is captured at 1080p and the browser
half at 900p. Both are 16:9 and the stitch matches height, so the framing
comparison is unaffected — but the tool's `SIZE` is not the Godot render size.

### Enemy attack telegraphs are missing or much weaker
The browser draws a large teal ellipse on the deck when a boarder winds up. In
the same posed moment Godot draws nothing comparable. Pillar 6 of the design is
that every attack is readable before it lands, so this is the readability item
the whole VFX plan was ranked around.

### ~~AESTHETIC PARITY — the original job~~ — SUPERSEDED BY THE OWNER, 2026-08-01
> *"I want the game screenshots of both versions to be almost identical in
> quality before we consider this job done."*

Closed by a newer instruction, verbatim: *"we can move beyond trying to
achieve visual parity with web v11 — we are now in uncharted and exciting new
territory as we build the Godot version to be better than the web one ever
was."*

What the parity chase accomplished before it was retired: the comparison tool
(`SkyGear Tools.bat parity`, six scenes), the camera proven pixel-exact
(SG-2), the Boiler rescaled (SG-27), telegraphs rebuilt (SG-3), the skill-bar
posing fixed (SG-4), and the lighting/card gaps found (SG-34/35 — both being
worked at the moment the goal changed, redirected mid-flight to "better than,
not identical to"). **The browser is a reference now, not a ceiling.** The
parity tool stays — it answers "did we regress something the browser did
well," which is still a real question; it just no longer defines done.

### 3D models for the remaining objects — MOSTLY DONE, three rejected
Asked for. Ten generated through `tools/meshy.py run props`, 360 credits.

**On the deck now:** the Boiler, the powder keg, the lantern post, the crate
stack, the steam vent, the deck cannon and the salvage pile. `PROP_MODEL` in
`view3d.gd` is the switch; deleting a row puts one back to painted.

**Generated, on disk, deliberately not wired** — each reads worse at the real
camera than the art it would replace, reasoning at the missing row in
`tools/static_model.gd`: the **brazier** (grey rock instead of burning coals, and
238 ground units across), **crate_small** (a bright orange treasure chest), and
the **boarding hulk** (see its own item below).

**Never generated:** `rope_coil`, 30 ground units tall, the shortest thing in
`PROP_HEIGHT`. The prompt is written and costs 30 credits if anyone disagrees.

~~Still worth doing: the REMESH step.~~ Done, and the premise here was wrong:
94% of every file was TEXTURE, not geometry. 218,332 triangles across 17 assets
is 11.5 MB; the other 170 MB was 68 embedded 2048-square JPEGs. 182 MB to 9 MB,
and the exe from 242 to 168. The captain was excluded and that has its own
entry below.

### Text legibility, not containment
Asked for: skills, cards and HUD elements are hard to READ. Distinct from the
text audit, which only proves text is inside its frame — a 7pt label perfectly
contained on textured brass passes that check and is still unreadable. `_fits`
shrinking text to fit is itself a suspect. An agent is measuring contrast and
point size before changing anything.

### Deckwork needs MORE VERBS — the prompt is done
Repairing a dead cannon works and is now findable: the coach announces that a
downed gun can come back (naming the bound key, not a hard-coded R), and a
prompt over the gun says you are standing where it works, with the progress
under it and the reason when it refuses. Three checks, including one asserting
the line carries the live binding and not the raw `{key}` token.

What the ask was actually about is still owed: dragging a crate to close a
lane, funnelling, shaping where the fight happens. Each is one entry in the
verb table in `scripts/deckwork.gd`.

### A cloak with cloth physics
Raised again. Godot has `SoftBody3D`, which is the obvious route, but it wants a
mesh with pinned vertices and the captain's rig came out of Mixamo without one.
Options, cheapest first: a bone chain on the existing skeleton driven by her
velocity (no new mesh, no solver, works with the animation blend); a separate
`SoftBody3D` cape pinned to a shoulder bone; or a vertex shader that fakes it.
The bone chain is almost certainly right for a figure this size on screen — at
this camera distance the cape is about forty pixels tall.

**BUILT 2026-08-02 (board SG-23), the bone-chain route as chosen above — left
open here for the owner's eyes on the cloth, like the crate and the lab.**
Four cape bones on a mount at her chest, a 32-triangle skinned banner in
procedural oxblood, a spring chain that trails at a run (1.19 rad, measured),
CRACKS on the dash (2.11 rad — the signature move gets the signature cloth),
sways at the ship's own periods when she stands, and snaps to a bitwise-exact
rest when the sway is off (the framing-check rule). Clamped so it can never
cross her torso at the 41° camera. Captain only, one `HERO_CLOAKS` row per
class — the Boilerwright opts in later with a row, not a build. Seven
`cloak ·` checks; pictures in `.shots/cloak/`.

### Popup menus drifting right — REPORTED, NOT REPRODUCED
Seen while watching screenshot runs go past. I measured it and could not find
it: the pause panel's left edge sits at exactly x=869 and the draft's at x=611,
identical on every frame across eight samples with the ship swaying underneath.
The HUD control does not move and its size does not change.

Two things I can think of that would produce the impression, neither confirmed:
the camera sways continuously (0.42 degrees of yaw, 0.85 of roll), so the WORLD
drifts behind a static menu and the relative motion can read as the menu
moving; or a menu I did not test does it. Needs to know WHICH menu before it
can be chased further.

Left open rather than closed, because "I could not reproduce it" is not the
same as "it does not happen."

### Documentation claims that are not enforceable
From the Fable audit. The pattern is right — every design doc ends with a list
of where the build departs from it — but the claims inside are not checkable, so
they rot silently:

- ~~three documents restate "the whole tree is worth less than three draft cards"
  and the check behind it compares only `crit_chance` (x1.06 against x2.28). It
  cannot fail~~ — **FIXED (SG-11).** `shop · the whole tree is worth less than
  three cards` now measures the real aggregate on both sides: the maxed tree's
  offensive product (crit_chance+range+vent_radius = **×1.31**) against the three
  per-skill cards read from the live catalogue (**×2.28**). Measured fully the
  inequality HOLDS, and a second check `shop · the three-card yardstick is the
  real catalogue, not three typed numbers` keeps the card side from drifting back
  to typed constants. META §4.1 and SHIP-AND-MAPS §7.2 updated to name it.
- ~~`CLASS-2-DESIGN.md` says "BUILT AND COMPLETE" over an omissions list missing
  at least four entries.~~ — **FIXED (SG-11).** Six audited entries added to the
  omissions list (repair budget, the 40-Head allowance, the six per-class cards,
  SUPERHEAT, per-class card gating + label, kegs as a Head source), and the stale
  "Head does not cost Boiler HP" entry corrected (the flat charge is now built).

The audit's proposed rule is the fix and it has been adopted (SG-11): **any claim
of harness coverage must name the check string** — recorded as BOARD rule 2,
extended to design docs, and swept through `skygear-godot/*.md` +
`skygear-godot/docs/*.md` (claims named where a check exists, marked `UNVERIFIED —`
where none does).

### ~~The airstream washes over the sky~~ — FIXED, and it was a bug not a tuning problem
Worth keeping as a record of a wrong diagnosis. This entry assumed the ribbons
were correctly built and merely too wide, and proposed narrowing
`STREAK_SPREAD` — a number three other things are calibrated against.

They were not correctly built. `Basis.scaled()` multiplies the basis ROWS,
which is a scale in the PARENT frame, and the streak basis is a 90 degree
rotation — so the two never lined up. The local X column points down the keel
and scaling the world-X row leaves it untouched, so THE 190-430 UNIT LENGTH WAS
DISCARDED and landed on the athwartships column instead. Forty-eight additive
plates up to 430 units wide ACROSS the ship at head height, sweeping over the
deck.

Found by measuring rather than by eye — `tools/deck_probe.gd -- airsize`
prints wanted against got, and it now reads 366.9 x 1.4 against a wanted
366.9 x 1.38, long axis (0,0,-1) down the keel. Fixed by scaling the columns
at construction. `STREAK_SPREAD` never moved.

### A 3D model for the boarding hulk — TRIED TWICE, SPRITE KEPT
Reported, and attempted: two Meshy generations, 60 credits, both rejected. Both
are on disk at `assets/models/boarding_hulk/` and the full reasoning is at the
missing row in `tools/static_model.gd`. Short version:

v1 came back a submarine. v2 is a good model — a wide armoured box, a round door
open with fire in its throat, a ramp down — and still loses, to something no
prompt fixes. The sprite wins because a billboard **turns to face the camera**,
so all 420 units of the hulk are always presented square-on as a wall of armour
with a glowing hole in it. The mesh is as deep as it is wide; at 41 degrees its
mass goes up out of frame and all that is left on screen is the ramp, lying
across the middle of the deck like a staircase. Posed against the sprite at the
bow and again from mid-deck, it loses both times.

The three states turned out not to be the hard part: the ramps are down in all
three PNGs and the whole difference is the door, and `game.gd` sets
`hulk.vulnerable = true` on the frame it grapples on and never clears it, so
SEALED is currently unreachable. One mesh of the OPEN state plus the painted
wreck would have covered it.

**If this is tried again it should be modelled by hand, not prompted** — it needs
to be much wider and much shallower than text-to-3D will return, with the ramps
as separate low geometry. The renderer wiring is already in place and inert
(`HULK_MODEL` in `view3d.gd`); a wrapped `.tscn` appearing is all it takes.


### The captain's grip on the sword
Reported. `weapon_fit` is interactive now (arrows nudge, ENTER saves) but **the
grip itself has not been re-fitted** — the tool was rebuilt, the number was not
changed. Two minutes in the fitter closes this.

The lab can now show it MOVING, which is the part that was missing: MOUNT, then
play `swing2` and scrub. Nudging is live at whatever frame you paused on, and
SAVE writes `assets/models/weapons.json`.

**A claim that was here and is wrong.** The lab agent reported that at frame 75
of 136 of `swing2` the cutlass sits beside her hip rather than in her fist —
"a grip that only holds at rest". It does not. Measured: the `BoneAttachment3D`
tracks `mixamorig_RightHand` to **0.002 m at rest and 0.002 m at that exact
frame**, and rendering the frame shows her right hand IS down at her hip in
that pose, which is where the sword looked detached. The pose was misread.

What is still possibly wrong is smaller and different: the fit carries a −120°
pitch and no offset, tuned against the rest pose, and a wrist that rotates
through a swing can make a correct attachment read badly. That is a fitting
judgement to make in the lab with the timeline running, not a bug.

### The captain is 30,634 triangles and was skipped by the remesh
Found by the lab, which flags her HEAVY in its own readout. She is **5.7 MB of
the 18 MB the models now cost** — a third of the budget on one asset — and she
is not in `.model_originals/`, so the pass that took every prop from 182 MB to
9 MB never touched her.

Probably correct to have skipped her, and that is the point of writing it down
rather than leaving it implied: decimating a 33-bone skinned mesh risks the
skin weights, and Meshy's remesh would return no rig at all, so the route that
worked for the props cannot be pointed at her. But by that pass's own budget —
`0.021 x px²` at her on-screen height — she should be 3,000 to 8,000 triangles.
She is 4 to 10 times over, and she is the one figure on screen 100% of the
time.

Needs a decision, not silence. The candidates are a skin-weight-preserving
decimation done locally, a hand-authored LOD, or accepting the cost and saying
so here.

### VFX plan items never started — TWO LEFT
From `VFX-PLAN.md`. §3 and §4 landed on 2026-07-31; these two did not:

- **§6 the captain's weapon trail.** The Cleave now draws a sweeping ribbon
  through the air, which covers the swing visually, but it is driven by the
  EFFECT's clock rather than by the `swing` clip through a `BoneAttachment3D` on
  her hand — so it is an arc where the blade approximately is, not a trail the
  blade actually left. The audit's two-layer construction (hot core, wide outer)
  exists in `_beam_ribbon` and would port straight across.
- **§5 chromatic hit and radial blur.** Shake and hit-stop are done. The
  research audit argues against the other two on readability grounds
  (`VFX-RESEARCH-AUDIT.md`, "Screen effects": avoid continuous chromatic
  aberration and radial blur, and if used restrict them to a prewarmed sub-150ms
  boss transition). Not started, and should probably be dropped rather than
  built — but that is a decision, not an omission, and nobody has made it.

### The Boilerwright looks exactly like the captain
Asked for as "a model for the second player class", and it is the one thing on
this list that **cannot** be closed by the Meshy pipeline as it stands.

`SkyGearView3D._sync_captain` loads one constant, `CAPTAIN_SCENE`, for both
classes. So the heavy engineer who built the Boiler is currently a fast
red-coated woman with a cutlass, and the only way to tell which class you picked
is the gauge. `CLASS-2-DESIGN.md` §7 already books him as **commissioned art**
and it is right: he needs the captain's 33-bone Mixamo skeleton and her clip
set, plus the plant/kneel clip §7 names, and a Meshy text-to-3D result has no
skeleton, no clips and no rest pose to retarget from. `tools/static_model.gd`
exists precisely because that is true, and it produces static scenes — a static
scene in `_sync_captain` is a statue that slides around the deck.

Two routes, and the choice has to be made before anyone spends:

1. **Mesh, then Meshy's own rig + animation endpoints** (`/openapi/v1/rigging`,
   then the animation library). Cheapest, but his clips would then be Meshy's,
   not the axe pack's, so his timings would not match hers and `anim_timing.gd`
   measures against skill windows.
2. **Mesh, then retarget the axe pack onto it** through `tools/ingest_model.py`
   and `tools/models.json`, which is how the captain was built and the only
   route where the two classes move on the same clock. Needs the auto-rig to
   come back with Mixamo bone names.

Until that is decided, generating a mesh is 30 credits on step one of three.
Nothing has been spent and no prompt is in the manifest, deliberately: an entry
in `tools/meshy.py` is a thing you can run, and running this one buys an asset
the renderer has no way to display.

### The furnace knight is still a sprite
Two Meshy attempts; neither read as the 180-hp thing you cannot walk through.
Not a bug — a deliberate call — but it is the one boarder breaking the 3D
consistency that was asked for, so it stays here until it is solved or dropped.

### The Workshop is a visual tree now — and Heat is a ladder (SG-14, 2026-08-01)
> *"We need to also work on making the workshop more of a visual tree — love the
> abilities and such, but the menu itself is quite dull/boring. Needs a visual
> pass."*

Done, and the ask listed four things to use judgement about. Three landed: node
state at a glance, rank as rivets, what a node does on hover, the running total
including what a respec returns, and the Articles as their own object — a
sidebar of wax seals on a cord rather than more rows.

**The fourth is now done too.** "Articles and Heat given their own visual
identity rather than more rows" — Heat was a single cycling `ui.choice` row on
the title, the exact treatment the ask objected to. It is now a **ladder**: five
clickable rungs, cleared ones lit brass, the next reachable one teal, locked
ones dim with a padlock that states its unlock rule on hover, and the selected
rung's one sentence spelled out beneath. STOKED (Heat 0) is the ground you stand
on rather than a rung — clicking the rung you are on steps back down to it, and
the header always names where you stand. Mouse-first, keyboard still works,
rebind-safe (menu navigation is not on the gameplay action map). It passed the
title's own audit pass, which it needed: the title is the one screen where a
widget-count change had already produced a COLLIDE. Text audit CONTAINMENT clean
and zero COLLIDE at all four widths with the fullest state posed (three rungs
cleared, the fourth reachable, the fifth locked, the longest blurb selected).

The other candidate fix — **moving the picker into the Workshop** — stays
rejected, not deferred: Heat is a per-run choice made on the way into a run and
the Workshop is where you spend between runs, so putting it there makes you visit
two screens to start.

And the prerequisite is met: **Heat 3, 4 and 5 now exist** as real, cumulative,
tested difficulty modifiers (rungs before the rung display, as the ledger asked)
— Cold Deck (two cards on one reroll), Boarders Aloft (a hulk on waves 4/6/8/10)
and Skeleton Crew (no crew muster, cannons at half health). The balance tool
takes a Heat argument now and reports the difficulty as a distribution: across
six seeds the bot held Heat 0 five times to average wave 11.7, held Heat 3 none
to average wave 10.2, and held Heat 5 none, dying on wave 4 every run.

---

## Done

- **Player projectiles and VFX reading as 2D.** Both halves. The hitscan shapes
  now draw a travelling bolt inside the window the effect already lived for —
  the head runs out along the line and the tail chases it — so a Lance has
  something in the air without the simulation gaining a projectile. And chains,
  beams, sweeps, cones, shockwaves and the Mortar's shell are GEOMETRY now
  rather than decal streaks: strips of triangles whose width is offset
  perpendicular to the line of sight, so they face the camera instead of lying
  on the planking. Every element has its own width, wander, kink and rise, so
  the four are distinguishable by shape and not only by hue. Ground decals stay
  underneath all of them, dimmed — they are still the half that says where on
  the deck a thing will cross you. `VFX-PLAN.md` §3 and §4; nine harness checks,
  all of them on the cap. Whole-frame cost avg 7.6 → 8.4 ms against 16.7.
- **Deck cannons: visible shots and clear health bars.** The shot landed in the
  previous pass; the bar is here. The lane panel in the corner already carried
  the number and the corner was the wrong place for it — it says a cannon is
  dying without saying which of the three guns in front of you it is. Now the
  same number is over the gun as well, in the boarders' own language
  (`_health_bar`, same bed, same ticks), unprojected from the world so it holds
  its size when the wheel pulls the camera back. Hidden at full health. A dead
  gun shows an empty red bed, the word DOWN, and fills the bar back up as you
  repair it; in the world it gets a scorch, a guttering ember and a plume of
  vented steam, so the broken lane reads as broken from across the deck.
- **THE SKYBOX — clouds, a moon, and parallax.** Reported three times. The
  first two passes treated it as a colour problem and the third found out why
  they could not have worked: the browser's `drawEnvironment` stretches
  `assets/env/sky_backdrop.png` over the WHOLE viewport behind the deck, and
  that painting — a moon breaking through cloud upper left, banked purple
  cumulus, a warm ember lower right — is what the player remembers. Its two
  scrolling cloud bands are pinned to the horizon and `CAM.horizonY()` returns
  **-761.58** at 1600x900, so they have been drawn off the top of the screen for
  the life of the build; nobody has ever seen them.

  Here the painting is a **sky shader** rather than a quad: it is sampled by view
  direction through the browser's own projection, so at the shipped framing it
  lands where the browser puts it to the pixel, and being at infinity it cannot
  shear or slide when the wheel pulls the camera back. The parallax comes from
  **six real cloud quads at two real distances** — 300 and 640 metres, the pair
  that turns the browser's 16 and 34 pixels a second into an angular rate at one
  drift speed — so the layers part against each other and against the deck for
  free under the perspective camera. `tools/sky_shot.gd` (or
  `SkyGear Tools.bat sky`) poses the four places the sky is actually visible;
  before and after are in `.shots/sky-before/` and `.shots/sky/`. Measured at
  under 0.1 ms on the GPU, which is inside the noise floor. Seven harness
  checks, `sky · the backdrop is the browser's painting, not a gradient`
  through `sky · the far plane clears the furthest corner of the field`.

- **The sky gradient itself** — the same item, one layer down, and closed by the
  same change. There is no gradient any more except as the fallback for a build
  with the art missing.

- **Sentries drop nothing** — were `passive: true`, firing an invisible beam from
  the player. Now placed at the cursor or auto-dropped.
- **Skill aiming and projectiles** — aim came from the hidden 2D scene; now
  unprojected from the cursor onto the deck plane.
- **UI readability** — the whole HUD rebuilt on a widget layer; text audit across
  16 screens at 4 resolutions, clean.
- **Card text escaping its frame** — three functions disagreed about where the
  brass ends. One `rail()` now, and a tool that fails the build if text leaves a
  frame or two widgets share pixels.
- **Clicking skills to select upgrades did nothing** — there was no widget layer.
- **SFX and character audio inaudible** — mixer ducking, five channels in
  settings.
- **Ice-skating movement** — a forward run cycle played while moving backwards,
  a dash that never stopped, and braking as soft as acceleration.
- **Animation popping and getting stuck on terrain** — root motion was sliding
  the mesh 129 ground units off the simulation's position.
- **Animation speed not matching skills** — clips now stretch to the skill's own
  window; `hub -- timing` measures it.
- **Fullscreen, high resolution by default.**
- **A sword asset** — Meshy cutlass, in her hand via a bone attachment.
- **3D boarders** — four of five.
- **Boiler health prominent** — moved to top centre.
- **Crew and cannons doing too much damage** — rebalanced to meat shields.
- **Enemy health bars and status** — bigger, with drain-timed status chips.
- **The second class** — the Boilerwright, complete.
- **Every 4 waves an event** — 4, 8 and 12, named and announced.
- **Meta-progression** — the Workshop, the Articles, and Heat.
- **A HUD alignment tool** — F4, with sub-element positioning.
- **Old versions demoable on the website.**
- **All the tools in one place** — `SkyGear Tools.bat`.
- **Movement felt slower after the skating fix** — I over-corrected. Braking
  went 2700 to 5200, which stops in 0.05s and reads as glue, and the dash was
  made to exit at exactly walking speed so it covered less ground than the old
  gliding one. 3600 and a 1.55x dash exit; the checks now pin the SHAPE
  (stopping quicker than starting, but not instantly) rather than the numbers.
- **Mousewheel zoom** — pulls the camera back along its own axis rather than
  widening the field of view, so the projection every telegraph and billboard
  height is calibrated against does not move. Out only, never closer than the
  shipped framing.
