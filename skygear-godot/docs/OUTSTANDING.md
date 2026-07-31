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


### THE CAMERA IS ZOOMED IN — found by the comparison, first time it has been run
The single largest parity gap, and it contradicts a claim I have made
repeatedly. I have said the camera was "ported exactly" from the browser's
`CAM.recompute()` solve. Side by side at the same resolution, on three separate
scenes, **Godot shows materially less of the deck**: the same crates, cannons
and lanterns are larger, fewer of them fit, and the Boiler dominates the lower
third in a way it never does in the browser.

That is not a lighting or effects difference. It changes how much of the fight
you can see at once, which is a gameplay difference wearing a visual one — and
it is upstream of every other parity judgement, because two builds framed
differently cannot be compared on anything else.

Not yet diagnosed. Candidates: the solve is right but `WORLD_SCALE` or the deck
rectangle differs; the FOV is right but the camera distance is not; or the
browser applies a zoom-out the port dropped. **Measure it before touching it** —
put a known length on screen in both and compare pixels.

### Enemy attack telegraphs are missing or much weaker
The browser draws a large teal ellipse on the deck when a boarder winds up. In
the same posed moment Godot draws nothing comparable. Pillar 6 of the design is
that every attack is readable before it lands, so this is the readability item
the whole VFX plan was ranked around.

### AESTHETIC PARITY — the original job, never finished
> *"I want the game screenshots of both versions to be almost identical in
> quality before we consider this job done."*

Substantial VFX work landed (tonemapper, particles, decals, batched shadows,
element light, a camera solve I believed was exact) but **the comparison itself was
never made**. Every parity judgement so far has been my memory of the browser
build against a Godot screenshot, which is not evidence. Some of it may be
regression and I would not know.

**The tool now exists** — `python tools/parity.py`, or `SkyGear Tools.bat parity`.
Both builds are posed through their own exports at the same seed, wave,
boarders and tick count, then stitched side by side at matched height into
`.shots/parity/`. The first run found the two items above, one of which
contradicts something I had asserted several times.

What remains is the work it revealed, plus scenes for the HUD and the draft.

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

Still worth doing: the REMESH step. Our prompts ask for flat albedo and no baked
light and get it, but nothing downsamples the mesh after refine, and Meshy has an
endpoint for it. Every one of these is ~10 MB of GLB for an object 60 to 200
pixels tall.

### Text legibility, not containment
Asked for: skills, cards and HUD elements are hard to READ. Distinct from the
text audit, which only proves text is inside its frame — a 7pt label perfectly
contained on textured brass passes that check and is still unreadable. `_fits`
shrinking text to fit is itself a suspect. An agent is measuring contrast and
point size before changing anything.

### Telling the player how the two classes differ
Asked for. There are full descriptions in `CLASSES` that nothing reads, and the
picker shows one line. Comparable rows are now in the data; the screen that lays
them side by side is not built yet.

### Deckwork needs a prompt, and then it needs more verbs
The system is in and repairing a dead cannon works (hold R while standing at
it), but there is NO ON-SCREEN PROMPT yet — an interaction nobody is told about
is an interaction nobody performs. `hud.gd` was being rewritten by another
agent when this landed, so the prompt and the progress ring are still owed.

Then the verbs the ask was actually about: dragging a crate to close a lane,
funnelling, shaping where the fight happens. Each is one entry in the table.

### A cloak with cloth physics
Raised again. Godot has `SoftBody3D`, which is the obvious route, but it wants a
mesh with pinned vertices and the captain's rig came out of Mixamo without one.
Options, cheapest first: a bone chain on the existing skeleton driven by her
velocity (no new mesh, no solver, works with the animation blend); a separate
`SoftBody3D` cape pinned to a shoulder bone; or a vertex shader that fakes it.
The bone chain is almost certainly right for a figure this size on screen — at
this camera distance the cape is about forty pixels tall.

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

- three documents restate "the whole tree is worth less than three draft cards"
  and the check behind it compares only `crit_chance` (x1.06 against x2.28). It
  cannot fail, which means it is not evidence of anything.
- `CLASS-2-DESIGN.md` says "BUILT AND COMPLETE" over an omissions list missing at
  least four entries.

The audit's proposed rule is the fix and it should be adopted: **any claim of
harness coverage must name the check string**, so an untested claim is visibly
untested. Not done.

### The airstream washes over the sky now that there is a sky
Not reported — found while doing the skybox, and written down rather than fixed
because fixing it means moving a number three other things are calibrated
against.

The 48 airstream ribbons live 0.7 to 4.9 metres above the deck and spread
`STREAK_SPREAD` = 1500 ground units across, which is 7.5 metres either side of
the keel against a deck that is 8.4. Close to the lens they project wide, so
several of them cross the open air past the gunwale, and additive pale streaks
over what used to be a flat dark slab were invisible while over a moonlit
cloudscape they read as horizontal bars. Visible in every shot in
`.shots/sky/`, clearest in `starboard-z1.55.png`.

Two candidate fixes, neither measured: narrow `STREAK_SPREAD` so the air stays
over the planking, or fade a ribbon out as it passes outside the deck rectangle.
The second is more correct and costs a per-ribbon test. Left alone for now
because the airstream is F-03 and its width was tuned against how the deck
reads, not against how the sky does.

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

### The Workshop is a visual tree now — HEAT IS STILL A ROW
> *"We need to also work on making the workshop more of a visual tree — love the
> abilities and such, but the menu itself is quite dull/boring. Needs a visual
> pass."*

Done, and the ask listed four things to use judgement about. Three landed: node
state at a glance, rank as rivets, what a node does on hover, the running total
including what a respec returns, and the Articles as their own object — a
sidebar of wax seals on a cord rather than more rows.

**The fourth did not.** "Articles and Heat given their own visual identity
rather than more rows" — Heat is not in the Workshop at all. It is a single
cycling `ui.choice` row on the TITLE screen, which is exactly the treatment the
ask objects to, and it is still that. The two candidate fixes, and why neither
was taken in the same pass:

- **A rung ladder on the title.** Five clickable rungs with the cleared ones lit
  and the next one reachable, instead of one row you cycle. Small, contained,
  mouse-first, and the right answer. Not done because the title screen is the
  one screen where a widget-count change has already produced a COLLIDE — the
  Heat row is what put DIFFICULTY, CAPTAIN and THE WORKSHOP on top of each other
  — and it wanted its own audit pass rather than the tail of someone else's.
- **Moving the picker into the Workshop.** Rejected rather than deferred. Heat
  is a per-run choice made on the way into a run; the Workshop is where you
  spend between runs. Putting it there makes you visit two screens to start.

There is also a smaller thing worth writing down while it is fresh: **Heat 3, 4
and 5 do not exist**, so the ladder a rung display would draw is two rungs long.
Whoever builds the display should probably build it after the rungs.

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
