# The deck's identity — what makes it a ship, and a steampunk one

**A design pass, not an implementation pass.** Nothing in `scripts/` was changed to
produce this. It answers the owner's 2026-08-02 question — *"more ways to make the
deck feel more shiplike, and more steampunk"* — plus the two asks that came with
it, clouds and shadows. It is written against `docs/DECK-DESIGN.md`, whose
measurements are the constraint on everything below, and against the shipped
`scripts/view3d.gd`. Where a claim here is a claim about the code, the line is
named so it can be checked rather than believed.

## 1. What a player should feel, in order

1. **I am standing on a ship, not a floor.** DECK-DESIGN §1 measured why this
   fails: 94% of the default frame is planking and the near two thirds has no
   ship's edge in it at all. Anything that fixes this must reach the middle of
   the frame or the rail at zoom.
2. **The ship is a machine, and it is working.** Steam, heat and light already
   exist on this deck and none of them is connected to anything: the brazier
   throbs at 11 Hz, the lantern at 6, the vent at 2.1, and the vents puff on a
   flat `SMOKE_EVERY = 0.10` metronome. Independent decorations that happen to be
   warm are not an engine.
3. **The ship is flying.** Third, not first, because the camera cannot help: the
   horizon is off the top of the frame at every zoom and sky is visible in four
   poses only. Speed has to arrive on the deck or it does not arrive.
4. **The ship is dying, or it is not.** `boiler_hp` currently drives one lamp's
   brightness and a HUD number. It should be readable in peripheral vision.
5. **Nothing above competes with a telegraph.** Pillar 6 outranks items 1–4. Any
   item that trades readability for atmosphere loses by construction, not by
   argument.

## 2. The ordered plan

### 1 · The rig overhead, as shadow only — and the envelope with it
**What.** Three masts, yards and shrouds built as real geometry with
`cast_shadow = SHADOW_CASTING_SETTING_SHADOWS_ONLY`, at the numbers DECK-DESIGN
P2 already measured: masts 1500 units at `(280, 900)`, `(−280, 260)`,
`(280, −560)` — on the lane dividers — yard at 0.74·h, six shrouds each. Plus one
line: `view3d.gd:772` sets the envelope to `SHADOW_CASTING_SETTING_OFF`, and that
quad is 36 × 11 m whose lowest edge sits at +5° elevation while the top of the
frame is −23°. It is built, transformed every frame and can never be seen.
**Why a player feels it.** The moon's direction is `(−0.344, −0.788, −0.510)`, so
every shadow lands 0.437·h to port and 0.647·h toward the bow: a mast aft of the
camera prints its rig across the middle of the deck. The caster lives where the
camera never looks; the shadow lives where the player is looking all run.
**Kill-test.** `tools/telegraph_shot.gd` posing the wave-6 set under the lattice,
run through `tools/legibility_probe.gd` at full light *and* at the wave-8
`set_darkness()` floor of 0.22. Any rune's measured edge contrast against
planking below `ink.gd`'s floor where the lattice crosses it — or one playtest
report of a missed telegraph — and the rig is cut to the envelope alone.
**Checks.** `rig · nothing in the rig is in the colour pass`; `rig · every caster
is inside the 34 m shadow distance`; `rig · the envelope casts and does not
draw`. **Traps already written down:** `directional_shadow_max_distance` is 34.0,
so a mast placed further aft silently stops casting, and `shadow_blur` is 2.2, so
shroud radius is 8–10, not 4, or the ropes read as lighting. **Size:** days.

### 2 · One shadow authority — the mark leans where the moon does, and lifts when the thing does
**What.** `_flush_shadows` (view3d.gd:4249) builds `Basis().scaled(Vector3(width,
1.0, width * 0.62))` — a scale, no light term — while `rig3d.gd:286` sets every
figure mesh to `SHADOW_CASTING_ON`. Two functions disagreeing about one number,
which is the second failure mode in STATUS. `_shadow()` gains height and
footprint arguments; the basis is built from `_moon.global_transform.basis.z`
read live, never retyped. Where a mesh figure already casts, its blob drops to a
small contact core instead of a second full-strength ellipse.
**Why a player feels it.** Today a boarder has two shadows pointing different
ways and a shell 200 units up drags a hard disc as if lying on the boards.
Corrected, a figure is connected to the planking and an airborne thing is
legibly airborne. **Projectiles are exempt from the lean and stay centred** —
DESIGN §13c and the audit both say the mark directly under a bolt is what tells
you where it will cross you. Height scaling applies; the offset does not.
**Kill-test.** `tools/deck_probe.gd` renders the bench pose three ways: today's
ellipse, the corrected pool, and the batch switched off entirely. If OFF is not
measurably worse than today, **the blob layer is deleted and the moon does the
whole job** — that outcome is allowed to win. If corrected differs from today by
under 3% of deck-region pixels at zoom 1.0, only the height falloff ships.
**Checks.** `shadow · the pool leans where the moon does — one light vector, read
and not retyped`; `shadow · a mark 200 units up is wider and fainter than the
same mark on the planking`; `shadow · a projectile's mark is directly beneath it
and is never thrown`; `shadow · no mesh figure carries both a cast shadow and a
full-strength blob`; the existing three (one batch, capped, decals do not paint
onto it) stay green. **Size:** days.

### 3 · The ship exhales aft
**What.** Every plume rises vertically on `ELEMENT_FX.STEAM.rise`. Add one wind
vector — a constant aft term plus the lateral shear `_sync_airstream` already
computes from `game.player.velocity.x`, one owner, one number — to the
per-particle velocity at the existing `emit_particle` sites, plus a permanent
slow exhaust off the Boiler stack on the wreck-smoke metering.
**Why a player feels it.** Steam blown backwards is the most legible speed cue a
steam vehicle has, it is the effect the owner named as liked, and unlike anything
in the sky it reads at every zoom and every camera drag.
**Kill-test.** `tools/legibility_probe.gd` at a wave-8 and a wave-12 pose with
full advection: any telegraph's contrast below the ink floor, or aft-blown steam
covering a larger fraction of the deck rect than today's vertical column, and the
advection goes to zero. **Checks.** `steam · a plume's emitted velocity carries
the wind term`; `steam · the plume count and the pool cap are unchanged`;
`steam · the vent's teal stand-here ring is unchanged in radius and alpha` — the
mechanic is the ring (SG-59), the plume is decoration. **Size:** hours.

### 4 · A rail you can see the sky through
**What.** DECK-DESIGN P1, mocked at `.shots/deck/rail-starboard-z1.00.png` and
still unbuilt: the two 14 × 40 × 2320 solid bars at `view3d.gd:630` become 16
stanchions a side at 145-unit spacing with two horizontal rails at y = 66 and
118. **Why a player feels it.** A rail reads as a rail because you see past it;
the periodic gap is the entire cue, and a solid 40-unit bar cannot produce it at
any camera. It is the cheapest "shiplike" line in the repo. **Kill-test.** The
inferred claim in DECK-DESIGN §6 gets tested rather than repeated: render a
boarder at one rail with the camera at the other. Any occlusion and the item is
cut — `_occluded()` tests `CARGO_RECTS` only, so anything that does hide a figure
fails silently. **Checks.** `view · no stanchion stands between the camera and a
figure at any zoom` (projected, measured); `view · the rail adds no occluder
`_occluded()` cannot see`. **Size:** hours.

### 5 · The stroke — one machine clock, driven by the Boiler
**What.** One `_machine_phase` in view3d.gd advanced at a rate off `_boiler_lamp`'s
own life term: ~0.85 Hz at full health, ~0.5 Hz and ragged as `boiler_hp` falls.
`lights.json` gains one optional field, `"drive": "machine"`, read beside the
existing hz/depth/shape; seeded on the brazier, lantern and vent rows. The vent
plume emits on the stroke crest instead of `SMOKE_EVERY`.
**Why a player feels it.** The deck acquires a pulse and the pulse is the
Boiler's life — the lamps and vents fall out of time before the player looks at
the gauge. **Kill-test.** `tools/clip.gd` captures 6 s at full `boiler_hp` and
6 s at 25%; autocorrelation on the capture must show stroke periods differing by
≥35%. Indistinguishable and the whole item is cut, table field included.
Separately, a live telegraph's boundary contrast must not move more than 3%
across a full stroke, or it is cut rather than damped. **Checks.**
`view · model lights are accents, and the budget says so in numbers` stays green
at `MODEL_LIGHT_CAP = 8` / `MODEL_LIGHT_ENERGY_BUDGET = 7.5` — no ninth light is
asked for; and the anti-orphan guard is extended to `lights.json` so `drive`
cannot become failure mode one. **Size:** days.

### 6 · Relief blows — steam that fires because something happened
**What.** A ~0.35 s hard jet of ~14 particles into the existing `steam` emitter
plus a one-frame kick on that vent's `steam_vent` spot, fired at the vent nearest
a real sim event. Closed list: Boiler damaged, keg detonation, a wave's first
landing, repair complete, Boilerwright taps a vent. At most one per vent per
1.2 s, at most three live, refused silently if the vent's footprint lies inside a
live telegraph's projection box. **Why a player feels it.** The ship becomes the
third participant; the Boiler taking a hit is currently a dim nobody notices.
**Kill-test.** Thirty simulated seconds with no events must produce exactly zero
blows — a blow that can fire on a clock is a decoration wearing an event's
clothes, and the item is cut. **Checks.** `steam · a blow only fires on a named
event, never on a clock`; `steam · at most three live and one per vent per
cooldown`; `steam · a blow never lands inside a live telegraph's box`. **Size:** days.

### 7 · Footprint families — six shadow shapes in the same single draw
**What.** `mm.use_custom_data = true` and one small unshaded shader picking a cell
from a generated six-mask atlas: upright figure, heavy figure, cornered crate,
long carriage, round keg, ragged hulk. The kind comes from the same call site
that today types a literal width, so the data cannot go unread.
**Why a player feels it.** A crate's shadow with corners is a crate before you
look up, and a crowd's composition is readable off the floor at 41° where bodies
overlap and footprints do not. **Kill-test, run before the shader is written:**
measure how many screen pixels a pool actually occupies at the shipped camera,
render the six masks and the plain ellipse at that size, and diff. Within 8%
identical and the atlas is cut to two masks or to none, and item 2 ships alone.
Hard gate: still one draw call, one material, `SHADOW_CAP` 256 — a second
material and the shape half is cut. **Checks.** `shadow · every caster names a
footprint family — none falls through to the default disc`; `shadow · the batch
is still one draw and one material after the atlas`. **Size:** days.

### 8 · Wet planking, through the Decal ORM channel nothing has ever written
**What.** Every mark on this deck is albedo plus a premultiplied emission map;
`Decal.texture_orm` has never been used once. Wet wood is low roughness, not dark
paint — at a 41° camera the moon's glint is the whole cue. Three users: a
condensate pool under each vent that spreads while it charges and dries after it
is tapped; a slick across the grating; a ring around the Boiler that goes matte
as the furnace dies. **Why a player feels it.** The owner's own report was "can't
seem to visually identify a vent"; SG-59 gave vents identity, this gives them
STATE, readable from across the deck. **Kill-test.** Render charged and tapped at
1600×900 and measure specular luminance delta inside the mark's footprint. Under
4% it is cut whole. Second gate: if a reader cannot say which of the wet mark and
SG-59's teal ring is the gameplay one, the wet goes. **Checks.** `deck · a
charged vent's mark is wetter than a tapped one — the ORM channel is written, not
the albedo`; `deck · a vent with no charge has no mark`. **Size:** days.

### 9 · Clouds — a near wisp layer and authored variety (ask a; §3 below)
**Size:** days. ### 10 · Brass with a highlight that moves
**What.** The gunwale, capping rails and Boiler straps are fixed metallic/roughness
lit by a 32-pixel probe of a near-flat sky, so the brass is painted gold. Add a
generated brushed detail normal, anisotropy aligned along each rail's run, and
slightly lower roughness. **Why a player feels it.** Running past a brazier lights
the rail along its length and puts it out behind her, and the 0.85° roll makes the
highlight crawl at rest. **Kill-test.** Probe the gunwale's brightest pixel at two
sway phases 1.7 s apart with the captain stationary: the centroid must travel
≥8 px at 1600×900, or the item is cut rather than brightened. Guard: the SG-34
deck-region mean luminance moves less than 3%. **Size:** hours.

## 3. The two asks, head-on

### CLOUDS — variations, sizes, shapes, Z layers

The honest frame first: **sky is visible in four poses and never mid-fight.**
`SkyGear Tools.bat sky` poses them. Cloud work is therefore worth doing, is worth
doing cheaply, and cannot be the answer to "the deck should feel shiplike."

What ships, all inside `_build_clouds` / `_sync_clouds` with no new shader:

* **A third Z layer, and it is the NEAR one.** Six small wisps at ~120 m —
  4000–6000 ground units wide, not 18000 — thin and pale. `CLOUD_DRIFT` is 720
  units/s, so its angular rate is ~0.060 rad/s against the near band's 0.024 and
  the far band's 0.0113: 2.5× the fastest thing currently in the sky. Speed
  differential is what makes parallax legible; a third slow layer is a third
  backdrop.
* **The wedge is an ANGLE, not a distance.** The harness gate
  `CAM_HEIGHT / tan(el) · sin(az) < rail_gap` has no range term, so a nearer layer
  at the same 23–30° elevations clears the same gunwale. **This is why the layer
  goes at the existing elevations and not at 35–45° down** — steeper is behind the
  planking by construction.
* **`CLOUD_WRAP` is 20000 units.** At 120 m a 200 m excursion swings a wisp far
  outside the wedge, so the wisp layer needs its own shorter wrap, and the wedge
  check must be evaluated **across the whole run** rather than at mid-drift, which
  is all it samples today.
* **Variety without new art.** The 2048×512 sheets are about two-thirds
  transparent and carry several distinct masses, all of which every quad shows at
  once. Give each `CLOUD_FIELD` row an authored `uv` window plus its own width and
  aspect: six quads become six shapes at four sizes off one texture. **Authored
  rows, never a seeded roll** — SG-48 cut a seeded-variety system when a
  measurement said it changed nothing, and authored rows are what keeps the wedge
  check checkable.

**Kill-test.** Judged at gameplay framing at the four sky-visible poses across a
30 s drift, not at a posed camera. Distinct cloud silhouettes intersecting the
frame must go up, and per-frame cloud pixel coverage must **not** rise more than
15% — "ten clouds were a fog" is the recorded failure of the first pass. No
measurable increase in silhouette variety at those four poses and the layer and
the UV windows are both cut as invisible-by-geometry.

**Checks.** The two existing gates (`sky · every cloud is inside the wedge the
camera can actually see`, `sky · and clears the gunwale rather than sitting behind
it`) must pass for all three layers **at every point in their run**; new
`sky · three layers, three angular rates, and the nearest crosses fastest`
(measured through `unproject_position`, the pattern already in the harness);
`sky · the cloud field is dealt from a fixed table and consumes no RNG`;
`sky · the far plane clears the furthest corner of the field` re-measured.

**Not doing:** more mass at 640 m (spends triangles on the smallest part of the
wedge and reproduces the six-not-ten seam), a fourth layer, and cloud shadows
moving across the deck — a 12% band sweeping a telegraph is pillar 6 traded for
decoration, and it would have to survive both a legibility gate and a
perceptibility gate that probably cannot both pass.

### SHADOWS — what replaces one circle, and what it costs

The ask is a bug report and it is correct. Three things are true in the shipped
build: `_flush_shadows` builds an axis-aligned ellipse with **no light term**;
`rig3d.gd:286` sets figure meshes to `SHADOW_CASTING_ON`, so the moon already
casts a real shadow for every rigged figure; and the moon's own vector throws
that real shadow 0.437·h to port and 0.647·h toward the bow. **So a boarder has
two shadows pointing in different directions, and the one the owner is looking at
is the sticker.**

What replaces the circle, in three tiers, in this order:

* **Tier A — one authority (item 2).** The instance basis is built from the live
  moon vector: every mark leans the same way, elongates by `1/sin(elevation)`, and
  offsets along the light. A figure that already casts drops to a tight contact
  core. Projectiles keep a centred mark.
* **Tier B — height (item 2).** Offset and width grow with height, alpha falls.
  This is a readability gain, not decoration: a thing in the air and its landing
  spot stop being the same pixel — except for bolts, where they must stay the same
  pixel, and that exemption is pinned by its own check.
* **Tier C — shape (item 7), and it is gated.** Six masks through
  `use_custom_data`, measured against the plain ellipse at the pixel size a pool
  actually occupies before any shader is written.

**What it costs.** Nothing structural: `SHADOW_CAP` stays 256, one MultiMesh, one
material, one draw call, no new nodes, ~120 lines in two functions plus ten call
sites. Tier C's only real risk is that these are roughly forty-pixel marks and
the masks may not resolve — which is why that is measured first and cut cleanly.
`tests/bench.gd` at sixty boarders holds p99 in its current band or tiers A and C
go and only the light-aligned yaw ships, because the yaw alone answers "the same
circle for all objects" and is free.

## 4. Explicitly not, with reasons

* **Visible rigging, stays, ratlines or a pennant in the near or middle field.**
  Tested twice and failed twice with pictures: `.shots/deck/rig-mid-z1.00.png`,
  `rig2-mid-z1.55.png`. A 10 cm rope four metres from the lens is a 30-pixel bar
  with the captain behind it. Item 1 is the shadows-only version and it is the
  only version that works.
* **Tilting the camera to show the horizon.** The 41° solve is measured against
  the browser's math to the pixel and three systems are calibrated against it.
  Buying a horizon re-frames every telegraph, decal and billboard height.
* **Volumetric or raymarched clouds.** The research audit rules directly: painted
  layered clouds match the art direction and are far cheaper.
* **Screen-space speed lines, motion blur, radial or chromatic effects, and any
  CompositorEffect.** VFX-PLAN §5's half was dropped by the owner on 2026-08-01
  (SG-19). Local refraction quads standing between the camera and the deck are
  the same trade with a different noun — a telegraph seen through one is
  distorted by construction, and a decorative-only effect does not get to charge
  the frame tail.
* **Real per-object shadow maps for billboards, or a second shadowed light.** A
  camera-facing card has no depth; shadow-mapping one gives a flat cross. The
  audit's "one shadowed directional light" stands — the dynamism asked for is in
  the shape and throw of the mark, not in a second atlas.
* **A custom deck or sky shader.** VFX-PLAN §7: shaders are where a project like
  this loses a week. Item 8 uses the Decal ORM channel the engine already has.
* **Hull work below the deck line, a wake, or keel spray.** D3 measured and
  photographed it: the deck's own lip occludes everything under it from every
  inboard camera. It buys a few pixels of gold.
* **Wind that touches the simulation** — drift on knockback, a push on
  projectiles. The sim is the one source of truth for where things are.
* **A seeded cloudscape or per-run weather.** SG-48 built this shape, measured it
  and cut it; ENEMY-VARIETY §3 carries the written rejection of sky-as-variety.
* **Unbounded scorch or soot accumulation.** Refused in VFX-PLAN §7 for the right
  reason: it needs a cap and an eviction policy, which makes it a system.
* **Raising the model-light budget.** Every item above rides lights already inside
  `MODEL_LIGHT_CAP = 8` and `MODEL_LIGHT_ENERGY_BUDGET = 7.5`.
* **New generated machinery — pistons, walking beams, animated gauges.** Credits,
  a T-pose review cycle, and a mesh that must clear the art it replaces. Item 5
  tests the same fiction with lights and steam that already exist. If a player
  reads the ship's pulse from that, a piston is the next ask with evidence behind
  it; if they do not, a piston would not have helped.

## 5. Build this one first

**Item 1 — the rig overhead as shadow only, with the envelope's one line.**

It is the only item on this list whose readability cost is zero *by
construction* rather than by gate: `SHADOWS_ONLY` puts no pixels in the colour
pass, so nothing can occlude a boarder, and the casters live aft of the camera
where the frame never reaches. It is the only item that puts a ship cue into the
middle of the **default** frame — the 94% that is planking. It is already
measured, already photographed against the shipped build
(`.shots/deck/rigshadow-mid-z1.00.png` exists today), already costed at ~60 lines,
and confirmed unbuilt: there is no `_build_rigging` and no `SHADOWS_ONLY` anywhere
in `view3d.gd`. It carries its two implementation traps in writing. And the
envelope half is one character of a constant on a quad the renderer builds and
transforms every frame and no camera can ever see.

The deciding reason is the owner's own pattern: he praises what he can see. This
is the item where an A/B picture can be put in front of him this afternoon rather
than after a week of work.