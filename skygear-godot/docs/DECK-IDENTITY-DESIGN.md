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
> **BUILT 2026-08-03 (SG-107), commit `b332c66`. The rig SHIPPED and passed its
> kill-test; the ENVELOPE HALF WAS CUT.** The lattice costs a rune **−0.47%** of
> its edge contrast at full light and **−2.67%** at the 0.22 darkness floor —
> negative, i.e. it improves them, because telegraphs are bright and it darkens
> the planking they sit on — while darkening 18–22% of the ring they are read
> against, so the pass is not a coincidence. Measured by `tools/rig_probe.gd`.
> Green as `rig · nothing in the rig is in the colour pass`, `rig · every caster
> is inside the moon's 34 m shadow distance`, `rig · the shrouds are thick enough
> to read as rope under a 2.2 blur`, `rig · and no mast stands in a lane, drawn
> or not`. The envelope is cut for three measured reasons, on the SG-107 board
> row; the check `rig · the envelope casts and does not draw` was NOT written,
> because the envelope does not cast. **Note on this item's own kill-test:** it
> names `ink.gd`'s floor, and §7.5 below had already established that 4.5 is a
> floor for TEXT and that the shipped rune figure is 1.91. The relative 3% gate
> decided; both numbers are printed.
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
> **BUILT 2026-08-03 (SG-107), commit `da58bf3`.** `moon_track()` reads the light
> live and `shadow_pose()` derives lean, elongation and throw from it; nothing
> restates the vector. Green as `shadow · the pool leans where the moon does —
> one light vector, read and not retyped`, `shadow · a mark 200 units up is wider
> and fainter than the same mark on the planking`, `shadow · a projectile's mark
> is directly beneath it and is never thrown`, `shadow · no mesh figure carries
> both a cast shadow and a full-strength blob`, `shadow · and it is still one
> batch, one material, one draw, capped at 256`. **THE DELETE BRANCH OF THIS
> ITEM'S KILL-TEST FIRED AND WAS NOT OBEYED**, and that is a live question for
> the owner rather than a settled call: with no ordnance on screen, batch-OFF
> costs only 1.91% of deck pixels — but that gate contradicts §13c above, which
> this same section calls non-negotiable, and it is not evidence about a bolt's
> mark or about a billboard that casts nothing. With ordnance in flight the gate
> does not fire (OFF 4.88%, corrected-vs-today 11.76%, floor 3.07%).
> `tools/shadow_probe.gd` reports the branch rather than taking it.
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
  **Superseded by §7 below** — the owner asked for it, so the system was built
  WITH the cap and the eviction policy. The rejection stands for the unbounded
  version and is the reason §7 leads with its numbers.
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

---

# 6. A HULL SHAPE AROUND A RECTANGLE

> *"can we address the deck shape and consider how to keep the playable area a
> rectangle, but make the visual deck look more shiplike"* — 2026-08-02

The ask contains its own answer, and it is worth saying plainly because it is the
part that makes everything below cheap: **the shape the player collides with and
the shape the player sees do not have to be the same object.** `DECK_RECT` is a
number in `game.gd:14`. The ship is a pile of `MeshInstance3D`s in
`view3d.gd:_build_world`. Nothing has ever required them to agree, and the only
reason the ship is a slab is that nobody ever drew anything the rectangle did not
already imply.

## 6.1 What does not move, and how that is guaranteed

`Rect2(-840, -1160, 1680, 2320)` — 1680 × 2320 — and everything measured against
it: `LANE_CENTERS = [-560, 0, 560]` (game.gd:16), the eight `CARGO_RECTS`
(game.gd:17–26), `cargo_rects()` (game.gd:3609), the crossings, the spawn line at
`y = -1115` (game.gd:2651), `correct_player_position` (game.gd:4135) and
`correct_enemy_position`. None of them is read by the hull and none of them is
written by it.

That is not a promise, it is a property of the construction, and there are two
halves to it:

* **The drawn deck is a strict SUPERSET of the collision rectangle.** Every piece
  of hull is outboard: `|x| >= 840`, or `y <= -1160`, or `y >= 1160`. The bow
  taper therefore *begins* at the bow line at full beam and narrows only forward
  of it; the stern likewise. Inside the rectangle the drawn deck is the same full
  1680-wide planking it is today.
* **The hull carries no collision of any kind.** It is `MeshInstance3D` and
  nothing else — no `StaticBody3D`, no entry in `CARGO_RECTS`, none in
  `fitting_walls`, no `hulk_hull()`. A `MeshInstance3D` has never stopped anybody
  in this game and cannot start now.

**Which way we err, and why.** Toward *drawn where she cannot stand*, never
*standable where nothing is drawn*. Superset, in one direction, always. A player
who walks to the rail and finds a foot of bulwark she cannot step onto has
learned the correct thing about a ship; a player who walks into empty space and
stops has found a bug. The superset direction also happens to be the one the
renderer can prove with a geometric assert rather than a playtest.

**The proof, and it is a pattern this repo already owns.** SG-56's bare-deck
baseline — `fittings · a ship with nothing berthed sails today's deck exactly —
byte for byte` (parity_test.gd:852) and `fittings · placing the whole berth set
consumes nothing from the seeded stream` (:869) — runs a seeded run and compares
`_ship_snapshot()` (:1085) and `rng.state` against a bare one. The hull gets the
same treatment plus the thing a fitting never needed: a lattice of
`correct_player_position` probes across and beyond the rectangle, asserting the
walkable set is identical to the shipped one to the unit.

## 6.2 What gets drawn

Three pieces, all outboard, all in `_build_world` beside the gunwale.

**a · The sheer strake.** DECK-DESIGN P3, mocked at
`.shots/deck/sheer-mid-z1.55.png` and prototyped in `deck_probe.gd:448`. Twenty
segments a side, a box 58 wide straddling the deck edge, top edge lifting on
`lift = 150·(1−t)^2.2 + 90·t^2.6`, `t` running 0 at the bow to 1 at the stern.
Peak 150 forward, 90 aft, zero amidships. **This is the curve.** A hull is read
almost entirely off its sheer line and there is not one curve anywhere in the
shipped outline.

*The trap P3 already wrote down and it is real:* boarders spawn at `y = -1115`,
45 units inside the bow edge, and a 150-unit bulwark is 0.85 captains. The
forward peak is therefore placed by measurement, not by taste — the lift at the
spawn band must leave a spawning boarder's silhouette unclipped from the shipped
camera, or the forward peak caps at 110.

**b · A bow that narrows.** Forward of `y = -1160`, a deck-level apron carrying
the planking from the full 1680 beam at the bow line to a stem 620 units ahead of
it. Not a wall — the vertical budget at the bow is **65 units of headroom at zoom
1.0** (DECK-DESIGN §1, and it is why `bow_prow.png` reads as a wall rather than a
prow). The taper lives in the deck PLANE, where there is no budget problem at
all, and the only thing that rises is the strake following it in.

**c · A stern.** Aft of `y = +1160`, a short counter, the strake sweeping up to
its 90 and closing across. The aft half of the ship is off screen unless the
captain walks into it (DECK-DESIGN §1: the visible band at zoom 1.0 is `focus+9`
to `focus−1312`), so this is the cheapest of the three and it is here because a
ship with a bow and no stern is a wedge.

## 6.3 Does it reach the frame? The honest measurement

DECK-DESIGN §1 is unambiguous and it is the constraint that has killed three
previous ideas: at zoom 1.0 with the captain **amidships**, the deck's half-width
at her own depth is 490 ground units against the deck's 840. The edge is off
screen for the near two thirds. No amount of hull fixes that frame, and this
document is not going to claim otherwise.

**But amidships is one lane of three.** `LANE_CENTERS` is `[-560, 0, 560]`, the
camera's x is the focus's x (`view3d.gd:3315`), and the deck's half-width is 840.
**A captain in either side lane is 280 ground units from her rail** — well inside
the 490 — and the edge is then in the near field, in the lower third, for as long
as she is in that lane. `.shots/sky/port-z1.00.png` is that frame in the shipped
build: the ship's edge runs corner to corner down the left of it and it is a
**straight flat gold band with no thickness**. That is the shot this item is for,
and it is not a rare shot — it is two of the three lanes.

So the claim, sized honestly:

| where the captain is | edge in the near field? | does the hull show? |
|---|---|---|
| port or starboard lane, zoom 1.0 | yes, near-field corner to corner | **yes — the money shot** |
| centre lane, zoom 1.0 | no, off screen laterally | only the far third |
| any lane, zoom >= 1.3 | yes | yes |
| the four `sky_shot` poses | port/starboard/bow: yes | yes |

## 6.4 The rail, and not breaking somebody else's plan

Item 4 above proposes replacing the two solid `14 × 40 × 2320` bars
(`view3d.gd:630`) with stanchions. **It has not landed** — there is no
`stanchion` anywhere in `scripts/` at the time of writing, though an untracked
`assets/models/railing_segment/` in the working tree says somebody is on it.

The hull therefore does not touch the gunwale block at all. It is built
**before** it and **outboard** of it, which is exactly what P3 asked for — *"build
it before the rail so the stanchions sit on it"* (DECK-DESIGN:373). The strake's
top edge is a stated function of `z` — one static function, `sheer_lift(z)` — so
whoever builds item 4 can seat a stanchion base on it with one call rather than a
second copy of the curve. The two compose in either order and neither reads the
other's constants.

## 6.5 Kill-test, pre-committed

1. **Occlusion.** Item 4's gate, applied here: a figure at one rail, the camera
   at the other, at every zoom. Any hull piece that projects between the camera
   and a figure and the piece is cut. `_occluded()` tests `CARGO_RECTS` only, so
   anything that *does* hide a figure fails silently — this is measured through
   `unproject_position`, never eyeballed.
2. **The spawn band.** A boarder spawned at `y = -1115` in each lane, from the
   shipped camera: any clipping of its silhouette by the forward strake and the
   forward peak drops from 150 to 110.
3. **The sim.** `_ship_snapshot()` equality, `rng.state` equality,
   `cargo_rects().size()` unchanged, and a `correct_player_position` lattice
   identical to the shipped build. Any one of them moves and the hull is reverted
   whole — there is no version of this feature that is worth one unit of walkable
   deck.

---

# 7. MARKS THAT ACCUMULATE — the deck as a record of the fight

> *"Maybe consider some subtle elements to break up the deck visuals? Blood
> stains, scorch marks? These could appear over time to add some irregularity to
> the deck."* — 2026-08-02

`VFX-PLAN.md` §7 deferred this, and the sentence it deferred it with is now the
specification: *"the keg scorch is in; a persistent accumulating set needs a cap
and an eviction policy, which is a system rather than an effect."* That was the
right call and it is not being overturned — the unbounded version is still
refused. What ships is the system, with the cap and the policy first, because
**every performance problem this project has had was an unbounded collection**:
the decals before `DECAL_BUDGET` (view3d.gd:4119), the seventy clustered shadow
`Decal`s before `SHADOW_CAP`, the ribbon pools before `_trim`. A feature whose
whole premise is "it grows for twelve waves" does not get to arrive without a
ceiling.

## 7.1 The numbers, first

```
MARK_CAP           24      hard maximum live marks. Never exceeded, ever.
MARK_PENDING_CAP    8      marks waiting for a retiring slot; oldest dropped
MARK_HOLD        90.0 s    full strength
MARK_FADE        60.0 s    then to nothing — a mark lives 150 s, ~3 waves
MARK_IN           0.35 s   a new mark fades in
MARK_EVICT        0.60 s   an evicted mark fades out. It never pops.
MARK_MIN_SEP     70.0 u    a same-kind mark this close DEEPENS instead of adding
MARK_ALPHA_MAX    0.12     the ceiling. Nothing on the planking is louder.
MARK_LIFT         1.0 u    above the deck; the shadow batch is at 2.0
```

**Why 24, when this section first argued for 48.** The draw bound was never the
constraint — the shadow batch carries 256 instances of the same quad in one call
and does not register in the profile. The coverage bound was: 48 marks measure
**12.5% of the planking painted** at full cap (`tools/marks_shot.gd` reports it
rather than computing it), against the 14% this section predicted. That part of
the design held.

**What did not hold was the legibility gate**, and 24 is the kill-test being
taken rather than talked around. At 24 the measured coverage is **5.7%**. §7.5
below carries the whole account, including the part where the measuring rig
turned out to be the least trustworthy thing in the experiment.

**Why 150 seconds.** A wave is 45–60 s. The deck should remember the last two or
three waves — enough that wave 9 looks like something happened on it, not so much
that wave 12 is uniformly brown and the memory means nothing. It also means the
cap is rarely reached in ordinary play, which is the correct relationship between
a cap and a game: the cap is the guarantee, not the mechanism.

## 7.2 Cap and eviction, which are the whole reason this was deferred

48 slots, and a slot is in one of three states.

* **A new mark takes a free slot.** If there is none, the **faintest live mark**
  is chosen — ties broken by age, oldest first — and set RETIRING: its alpha is
  driven to zero over `MARK_EVICT` = 0.6 s. **It is not deleted.** The whole
  reason for the retire state is that a mark vanishing between two frames is a
  pop, and a pop in the corner of the eye during a fight is worse than no mark at
  all.
* **The new mark waits in a pending queue** (<= 8, oldest dropped) and takes the
  slot the moment it clears, fading in over `MARK_IN`. Peak instance count is
  therefore `48 + 8 = 56` and the batch is sized for it. There is no path through
  this code that allocates a 57th anything.
* **Repeats deepen rather than multiply.** A mark of the same kind within
  `MARK_MIN_SEP` = 70 units does not create a slot; it adds to the existing
  mark's depth (capped at 1.0) and resets its age. This is the single most
  important line in the system: it is why a lane where six boarders died is one
  dark pool rather than six discs, why a bleed-jet trail of fire fields collapses
  into a scorched run instead of eating the cap, and why the cap is approached
  slowly enough that the eviction path is the exception rather than the rule.

## 7.3 Marks land where things happened

The requirement is that the deck late in a run is a record of the fight, not
random dirt, so every mark has a named cause and there is no clock anywhere in
this system.

| kind | cause | where the renderer sees it |
|---|---|---|
| **blood** | a boarder or crewman dies | the corpse is created, `view3d.gd:3237` |
| **oil** | a *machine* dies — the gunner drone | the same site, keyed off `model_key` |
| **scorch** | a blast of radius >= 150 | the `burst` arm, behind `_burst_new(fid)` |
| **scorch** | a fire field burns the boards | once per field id |
| **scald** | the Boilerwright cracks a main | once per tap id |

Deaths are nearly free evidence and that is why they lead: `_corpses[key] = {…}`
already fires exactly once, at the kill location, for every figure with a `die`
clip (`dies_on_screen`, view3d.gd:377). The blood pool is stamped from the same
line that decides a body exists.

**Why >= 150 and not "the keg".** The keg's burst is radius 175 (game.gd:3780)
and the hulk coming apart is 260 (game.gd:4105); a kill's own little burst is
`radius · 2.5` ≈ 60–100 and the boiler's is 90. A single threshold at 150
separates *the deck was scorched* from *something died*, needs no new field in
the sim, and cannot go stale the way `radius == 175.0` would. The kill keeps its
body's mark and does not get a scorch as well.

**No vent scald, and that is deliberate.** A vent has no event — `_fill_head`
(game.gd:3191) polls a distance every frame and emits nothing. A scald that
accumulated under each vent on the smoke clock would be item 6's named failure
exactly: *a decoration wearing an event's clothes*. The Boilerwright's cracked
main IS an event, at a place, chosen by a player, so that is where the scald
goes.

**Two refusals, both geometric.** A mark whose centre falls inside a
`CARGO_RECT` is refused — it would lie under a lane wall and climb nothing — and
a mark outside `DECK_RECT` inset by 20 is refused. Marks accumulate only while
`game.is_playing()` (game.gd:1609), so no sandbox pose, cutscene or model-lab
frame ever stains the live deck. The whole set is cleared when `_watch_cues`
(view3d.gd:3517) sees a run open: **a new run starts on clean boards.**

## 7.4 Subtlety: never a mechanic, and how that is enforced

Pillar 6 outranks this item by construction, not by argument, so the rules are
structural and each one is pinned by a check rather than by care:

* **A mark is never emissive.** Not dimly, not at all. The planking's own light
  is telegraphs, ground rings and glow pools; the moment a stain glows it has
  joined that vocabulary. One material, `SHADING_MODE_UNSHADED`,
  `BLEND_MODE_MIX`, no emission texture and no emission energy.
* **A mark is never a ring and never a circle outline.** Rings mean gameplay on
  this deck — the vent's teal stand-here ring (SG-59), a turn ring, a telegraph.
  Marks draw through `_blob_texture()`'s soft falloff and nothing else.
* **Alpha ceiling 0.30.** For scale: the contact-shadow batch under every figure
  already draws at up to 0.5 (`view3d.gd:4253`), on the same kind of quad, above
  these, and has shipped for weeks. A mark is strictly gentler than something the
  deck already carries everywhere.
* **They sit under the shadows.** `MARK_LIFT` 1.0 against the shadow batch's 2.0,
  on `LAYER_SHADOWS`, which every `Decal`'s `cull_mask` already excludes
  (view3d.gd:4154). A figure's contact shadow draws over its own blood.

## 7.5 Kill-test, pre-committed — written before a line was built

1. **Contrast — and this is the one that did not resolve cleanly.** The
   threshold this section originally named was `ink.gd`'s `CONTRAST_FLOOR = 4.5`,
   and measuring is what showed that to be the wrong yardstick: 4.5 is a floor
   for TEXT, and the **shipped** build's telegraph-rune-against-planking contrast
   is 1.91. A gate nothing has ever passed cannot decide anything. The gate that
   can is the relative one this project already uses elsewhere (items 2 and 5
   above): the marks may not cost more than ~3% of a rune's contrast.

   `tools/marks_shot.gd` was built to measure it — the four `telegraph_shot`
   windups over marked and unmarked planking. Three confounds were found in it,
   each of which had been quietly changing the answer:

   * two separate processes reach the shutter with the braziers at different
     points in their cycle — *fixed:* one process, two plates one frame apart,
     `_flicker` pinned;
   * `view._process` keeps advancing between those two plates and the brass
     gunwale measurably brightened — *fixed:* the renderer is stopped;
   * `GPUParticles3D` runs on the GPU's own clock and does not care that the tree
     stopped — *fixed:* particles hidden for the measurement.

   Before those fixes the same build reported the cost as 0.72%, 2.86%, 2.97%,
   6.60% and 13.55% on consecutive attempts, which is a measurement of the
   weather. **After all three fixes it still answers non-proportionally:**
   halving the cap and nearly halving the alpha moved the figure from 11.5% to
   9.1%, when the painted fraction of the frame fell by more than half. A rune
   median cannot move 8% when 5.7% of the deck is covered at alpha 0.12. Whatever
   that residual is, it is not the marks, and it has not been found.

   **RESOLVED 2026-08-03 BY SG-108, AND THE RESIDUAL WAS NOT REAL.** The lead
   below was right. Re-measured with the scene genuinely still — every tool that
   produced a number here now prints `still · two plates of a frozen scene
   differ by exactly zero` and **refuses to report anything if it is not** —
   **the marks cost a telegraph rune `+0.02%` of its contrast, and they darken
   `0.0%` of the planking ring it is read against.** That second figure is the
   one that matters: it holds even with the deepest mark this system can make
   stamped directly onto the strip of planking between each boarder and the
   captain, which is the planking the rune is actually read against. At
   `MARK_ALPHA_MAX 0.12` a mark does not move a planking pixel by the 0.004 of
   luminance the measurement counts as a change.
   `.shots/marks/marked-worst.png` is that frame; there is not a stain visible
   in it.

   **So the paragraph below this one is the record of a measurement, not of the
   feature, and the tuning it drove was decided on noise.** Cap 48 → 24 and
   alpha 0.30 → 0.12 were the pre-committed *"the density drops"* branch, taken
   because the marks appeared to be costing 11.5% of a rune's legibility. They
   were costing nothing measurable, before or after. **`MARK_CAP` to 12 now
   points the wrong way** — it would halve a feature that is already invisible.
   Nothing has been retuned on the strength of a re-measurement: the sentence
   below is still right that the deciding evidence is one playtest and not
   another rig. What has changed is what the rig can tell you. It can no longer
   tell you the marks are costing legibility, because they are not; it never
   could tell you whether they are worth seeing.

   **And two things about the numbers below that should be known before they are
   quoted again.** First, **11.5% and 9.1% are not reproducible from this
   repository** (SG-115): `marks_shot.gd` saved two PNGs and printed a coverage
   figure — it never computed a contrast, and no version of it in `git log` ever
   did. The measurement is in the tool now, through `tools/rune_read.gd`, which
   is the same rune mask and the same `ink.gd` formula `rig_probe.gd` decides
   on. Second, **that rune mask is a colour window** and on this deck it also
   selects the brazier bowls and an ARMORED boarder's lit plating (SG-116). Every
   answer above is a RELATIVE one measured over the identical pixel set in both
   plates, so contamination dilutes a cost toward zero rather than inventing one
   — but the ABSOLUTE figure **1.91** quoted throughout this section is a median
   over red things rather than over runes, and nothing should be decided on it
   until that is fixed.

   **THE LEAD, found 2026-08-03 by SG-107 while building the same kind of
   rig for item 2.** There is a fourth confound in this family and it is larger
   than the three above: **every rigged figure owns an `AnimationPlayer` that
   advances on the engine's own clock and answers to neither
   `game.set_process(false)` nor `view.set_process(false)`.** Seventeen boarders
   breathing through a walk cycle move their limbs, their weapons and their CAST
   SHADOWS between exposures. `tools/shadow_probe.gd` prints a noise floor — two
   plates of a frozen scene with nothing changed — and it read **53%** until the
   AnimationPlayers were stopped, at which point it read **0.00%**.
   `marks_shot.gd` never saw this because it shoots its two plates one frame
   apart, which shrinks the effect without removing it. **The mark cost should be
   re-measured with `Engine.time_scale = 0` and every `AnimationPlayer`'s
   `speed_scale` zeroed before `MARK_CAP` is moved to 12 on the strength of the
   old number.**

   **So the feature ships at the conservative end and this file says so** rather
   than quoting the flattering number. What IS established: hard cap, eviction
   without a pop, never emissive, never a ring, one draw, and gentler than the
   contact-shadow batch drawn *above* it, which has shipped for weeks at
   `Color(0.02, 0.015, 0.03)` and up to alpha 0.5. What is NOT established is a
   trustworthy figure for the telegraph cost. **The open lever is `MARK_CAP` to
   12, and the deciding evidence is one playtest, not another rig.**

   One thing the rig did settle, and it was worth the whole exercise: the mark
   tints were **an order of magnitude too bright**. These are unshaded colours
   written into the HDR buffer, and an honest bleached-timber scald at
   `Color(0.40, 0.375, 0.330)` composited *brighter than a telegraph rune*. The
   calibration point is the shadow batch, not a paint chip.

2. **Frame budget — PASSED.** `tests/bench.gd` at 60 boarders with the deck
   marked: `p99 7.09 / 7.89 / 12.59 ms` across three runs against the bench's own
   16.7 ms gate, and `p99 7.85 ms` with `MARK_CAP = 0`. The 12.59 was a single
   spike; **the medians are identical either way (6.06–6.25 ms)** and the draw
   count does not move (837–914 in both configurations, the variation being
   decals and effects). The structural gate holds by construction and by check:
   one MultiMesh, one material, one draw, no node per mark.
3. **Not-gameplay.** The proxy is structural because taste is not measurable in a
   harness: *no mark is ever emissive* and *no mark is ever a ring* are both
   checks, so the failure cannot arrive silently in somebody's later commit. The
   playtest question is one line: *did you ever think a stain meant something?*
   One yes and the density halves.
4. **The sim.** The same bare-deck baseline §6.1 uses. Marks are drawn by the
   renderer from state the renderer owns; if a single number in
   `_ship_snapshot()` or `rng.state` moves, something has been wired backwards
   and the whole item comes out.

## 7.6 Explicitly not

* **Marks that survive a run.** They are a record of *this* fight. A deck that
  opens wave 1 already bloody is set dressing, and set dressing is what §7 is
  trying not to be.
* **Marks under cargo, on crates, or up a wall.** A `Decal` would climb a crate;
  a MultiMesh quad cannot, and the answer is to refuse the placement rather than
  buy a `Decal` per mark and spend the `DECOR` budget that glow pools need.
* **Footprints, drag trails, or anything that tracks a moving figure.** Every
  mark here is one stamp at one instant from one event. A trail is a per-frame
  emitter, which is an unbounded collection wearing a new hat.
* **Marks that scale with a gameplay number through an opaque plate.** SG-78's
  rule. `_blob_texture()` is a guaranteed soft falloff; `burst_impact.png` and
  the painted ring are formally retired from this path and stay retired.
