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

### 3D models for the remaining objects
Asked for. Deck props are all still billboards — crates, barrels, kegs, the
lantern posts, braziers, cannons, vents, rope, salvage. An agent is on it with
the Meshy pipeline.

The player's own workflow is worth matching: generate, strip the baked lighting,
remesh to a sane polycount, import. Our prompts already ask for flat albedo and
no baked light; the REMESH step is the one the pipeline does not do, and Meshy
has an endpoint for it.

### A model for the Boilerwright
Asked for. Harder than the props: he currently uses the captain's rig and her
animation set, so a static mesh cannot be dropped in the way a crate can. Either
the generated mesh gets retargeted onto the same skeleton, or he keeps her rig
and only the silhouette changes.

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

### The sky is better, not right
Reported twice. It was near-black and fogged; it is now a dusk gradient with
`fog_sky_affect` turned down. But the warm horizon band sits behind the bow at
most camera positions, so what you actually see is still mostly dark corners.
Needs either high cloud above the horizon, or a rethink of what is visible at
this camera pitch.

### The captain's grip on the sword
Reported. `weapon_fit` is interactive now (arrows nudge, ENTER saves) but **the
grip itself has not been re-fitted** — the tool was rebuilt, the number was not
changed. Two minutes in the fitter closes this.

### VFX plan items never started
From `VFX-PLAN.md`, with no code at all behind them:
- §3 chain and bolt trails as `ImmediateMesh` ribbons — still decal streaks
- §4 `FogVolume` for fields — still flat
- §6 the captain's weapon trail — and she now has a visible sword, so this
  matters more than when it was written
- §5 chromatic hit and radial blur — shake is done, these are not

### The furnace knight is still a sprite
Two Meshy attempts; neither read as the 180-hp thing you cannot walk through.
Not a bug — a deliberate call — but it is the one boarder breaking the 3D
consistency that was asked for, so it stays here until it is solved or dropped.

---

## Done

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
