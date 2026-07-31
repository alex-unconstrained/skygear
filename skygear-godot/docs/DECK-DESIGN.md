# The deck, and why it reads as a slab

**A design pass, not an implementation pass.** Nothing in `scripts/` was changed to
produce this document. Every number below came out of `tools/deck_probe.gd` and
every picture is a real render of the shipped build with proposal geometry added
at runtime. The tool is the deliverable alongside this file: it will answer the
same questions again after somebody implements half of this.

```
godot --path . --script tools/deck_probe.gd -- measure
godot --path . --script tools/deck_probe.gd -- <variant> [spot] [zoom]
```

Variants: `base noair airfix airsize headroom rail hull rig rig2 rigshadow sheer
catwalk combo best`. Spots: `mid port starboard bow stern`. Shots land in
`.shots/deck/`. The HUD is switched off in all of them, which is the only reason
they can be read — the existing `tools/sky_shot.gd` output has a wave banner
across the middle of every frame.

---

## 1. The camera is the whole argument

Everything below is ranked by one measurement, so it goes first. From
`deck_probe.gd -- measure`, computed from the four constants in `view3d.gd`
(`PITCH 0.72`, `CAM_HEIGHT 760`, `CAM_NEAR 460`, `FOCAL 1320 @ REF_HEIGHT 860`):

| | |
|---|---|
| pitch | 41.25° below horizontal |
| vertical field | 36.1° (half 18.04°) |
| horizontal field | 60.2° (half 30.08°) |
| **top of frame looks** | **23.21° below horizontal** |
| bottom of frame looks | 59.30° below horizontal |

**The horizon is never in shot.** Not at any zoom, because the wheel moves the
camera along its own axis and never touches the lens. You would need a pitch of
18° or less. `tools/sky_shot.gd` already says this; it is repeated here because
three of the intuitive fixes for "it doesn't feel like altitude" are horizon
fixes and all three are impossible.

**94% of the frame is planking.** At zoom 1.0 with the captain amidships, the far
edge of the deck sits at 94% of frame height. At zoom 1.55 it is 75%. That is
not a composition choice anybody made, it is what a 41° camera 7.6 m above a
23 m deck does.

### The vertical budget

How tall a thing can be at a given depth before its top leaves the frame. `z` is
measured from the captain (the focus point); negative is toward the bow.

| depth | max height, zoom 1.0 | zoom 1.55 |
|---|---|---|
| focus +0 (at the captain) | 563 | 872 |
| focus −400 | 391 | 701 |
| focus −800 | 220 | 529 |
| focus −1160 (the bow) | **65** | 375 |

For scale: `CAPTAIN_HEIGHT` is 176 ground units. **At the bow you have less than
half a captain of headroom.** This is why `bow_prow.png` — 900 units tall — is a
wall across the top of the frame rather than a prow.

It is also why the reverse is true and worse: a vertical object near the camera
is enormous. `.shots/deck/headroom-mid-z1.00.png` is a grid of 1200-unit measuring
poles and the near ones are 200-pixel bars that obliterate the play area. There
is no height at which a mast is both visible-as-a-mast and harmless.

### The lateral budget

Half the frame width in ground units, at deck level. The deck's half-width is 840.

| depth | zoom 1.0 | zoom 1.55 |
|---|---|---|
| focus +0 | 490 — **edge off screen** | 760 — edge off screen |
| focus −400 | 665 — edge off screen | 934 — in frame |
| focus −800 | 839 — edge off screen | 1109 — in frame |
| focus −1160 | 996 — in frame | 1265 — in frame |

**At the default zoom the deck has no visible edge for the near two thirds of the
frame.** The rails only enter shot in the far third. Look at
`.shots/deck/base-mid-z1.00.png`: there is not one pixel of ship's edge anywhere
in it. The player's own position, and everything within a lane of them, is
rendered as an unbounded floor.

Combined with the bottom ray (which crosses the deck at focus+9), the visible
deck band at zoom 1.0 is `focus+9` to `focus−1312` — 1321 of the deck's 2320
units. **Roughly the aft half of the ship is never on screen unless the captain
walks into it.**

### What this rules in and out

* Anything at the deck EDGE only pays off at zoom > 1.3, or when the captain is
  at a rail. Worth doing — those are the money shots — but it cannot fix the
  default frame.
* Anything BELOW the deck plane is invisible. You are always looking down at the
  edge from inboard, so the deck's own lip occludes everything under it. Proven,
  not assumed: `hull` and `catwalk` in §4.
* Anything ABOVE the deck plane in the near field is a bar across the screen.
* Which leaves **the deck surface itself**, and **shadows cast onto it**, as the
  only channel that reaches the 94%.

---

## 2. What is actually there now

Read from `scripts/game.gd`, `scripts/game_data.gd` and `scripts/view3d.gd`.

* `DECK_RECT = Rect2(-840, -1160, 1680, 2320)` — 16.8 m × 23.2 m of walkable deck.
  **Gameplay. Do not move it.**
* `LANE_CENTERS = [-560, 0, 560]`, dividers at ±280.
* `CARGO_RECTS` — eight boxes at x ∈ [−340,−220] and [220,340], `WALL_MODULE_H`
  125 units tall. These are the lane walls and the only geometry that can hide
  anybody. **Gameplay.**
* The gunwale: a `BoxMesh` 14 × 40 × 2320 down each side, plus two end caps.
  40 units is 0.4 m — a quarter of the captain's shin. Solid, no gaps.
* The hull: one box, 300 tall, **0.94 × the deck's width**, i.e. inset 50 units
  on each side, sitting under the deck.
* `bow_prow.png` — a 900-unit Sprite3D at `z = −1310`, leaning back 14°.
* The envelope: a 36 m × 11 m quad pinned 6.2 m above and 15 m ahead of the
  camera. Its lowest edge sits at about +5° elevation. **The top of the frame is
  at −23°, so the envelope is entirely off screen at every position and zoom.**
  It is being built, transformed and never seen.
* `PROP_LAYOUT` — 30 props. Tallest is one `mast` at 340 units (1.9 captains) at
  (0, −180). Four `railing` props at x = ±780, 52 units tall, four isolated
  trestles rather than a rail. Cargo runs are 125 units — waist-high on the
  captain.
* Sway: 0.42° yaw, 0.85° roll, 26 units heave.
* The clouds: six painted banks at 25–30° BELOW horizontal, 300 m and 640 m out,
  drifting aft at real angular rates. This is good work and it is the one thing
  currently selling altitude.
* `_occluded()` / `_xray()` — a silhouette pass that draws a flat-tinted ghost of
  any figure hidden behind cargo. **Hard-coded to test `CARGO_RECTS` only, with
  an axis-aligned rectangle test.** Any new occluder either has to be added here
  or has to be designed so it can never occlude. This is the single most
  important constraint on the proposals below and it is why the top three all
  live outboard of the rail or cast no geometry at all.

---

## 3. Diagnosis

Seven faults, in the order they cost you.

### D1. There is no edge in the frame the player is looking at

Measured in §1. The near two thirds of the default frame has no ship boundary in
it at all. This is the single largest reason the deck reads as a floor rather
than as a vessel: a floor is a surface you can't see the end of.

`.shots/deck/base-mid-z1.00.png` — no edge anywhere.
`.shots/deck/base-mid-z1.55.png` — the whole ship, and it is a trapezoid.

### D2. The edge that does show is a line, not a rail

At the port and starboard positions the boundary is: planking, one gold stripe
about fifteen pixels wide, then sky. Nothing between. No stanchions, no gaps you
see the sky through, no thickness, no hull below the line.
`.shots/deck/base-starboard-z1.00.png`.

A ship's rail reads as a rail because **you see past it** — the periodic gap
between stanchions is the cue. A solid 40-unit bar cannot produce that cue at any
camera. This is the highest-value fix in the document and it is the cheapest.

### D3. The hull is real geometry that no camera can see

The hull box exists — 300 units deep — and is inset 3% laterally, so from any
inboard position the deck's own edge occludes it completely. I flared it 46 units
OUTBOARD in three courses with ribs (`.shots/deck/hull-starboard-z1.00.png`,
`hull-mid-z1.55.png`) and the change is a few pixels of extra gold and some
notches. **The intuitive answer — "there's no hull below the deck line" — is
true, and fixing it buys almost nothing.** Say so up front so nobody spends a
week on it.

### D4. The silhouette is a perspective rectangle

At zoom 1.55 the ship is a clean trapezoid: two straight converging lines, level
fore and aft, meeting a flat gold band at the bow. No sheer, no tumblehome, no
taper, no bulwark, no stern. Real hulls are read almost entirely from the curve
of the sheer line, and there is not one curve anywhere in the outline.

### D5. The deck plane is uniform and the props are scattered on it

One planking texture at one tiling, one roughness, edge to edge, with `PROP_LAYOUT`
sprinkled over it. There are no coamings, no hatch rims, no deck seams that follow
a hull, no ring bolts, no ropes running fore-and-aft, no change of material where
a working deck would have one. Nothing tells you which way is forward except the
lane geometry. The cargo runs are 0.7 captains tall and read as warehouse pallets.
`.shots/deck/base-stern-z1.00.png` is the extreme case: the Boiler, three cannons
and a hundred per cent planking. It looks like an engine room floor.

### D6. The airstream is drawing horizontal haze bars across the fight — a real bug

`_build_airstream`'s own comment states the intent and warns against exactly the
failure it produces:

> NOT billboarded. A billboard yaws to face the camera, which overrode the heading
> and drew every streak as a horizontal bar across the screen — precisely the one
> direction air rushing down a keel does not travel.

`deck_probe.gd -- airsize` measures the transforms that come out of
`_sync_airstream`:

```
streak 0
  wanted   366.9 x 1.38 ground units (len x width)
  got      100.0 x 366.9 ground units
  long axis in world  (0, 0, -1)
  short axis in world (-1, 0, 0)
  normal              (0, 1, 0)
```

The length and the width are swapped, and the length that was meant to run down
the keel is running **across the ship**. The cause is `Basis.scaled()` at
`view3d.gd:2319`: it multiplies the basis ROWS, which is a scale in the PARENT
frame, and the basis is a 90° rotation — so the keel-length lands on world X and
the 2 cm width lands on world Y (where a literal `1.0` then throws it away
entirely).

What ships is **48 additive horizontal plates, 1 m fore-and-aft by 2.6–4.3 m
athwartships, floating 0.7–4.9 m above the deck**, sweeping aft at 14.5 m/s. They
are the broad pale bands over the planking and the cargo in every screenshot in
this repository. They read as a dirty lens.

A/B: `.shots/deck/base-mid-z1.55.png` against `.shots/deck/airfix-mid-z1.55.png`
(the same build with the meshes pre-compensated so the intended ribbon comes out).
The bands vanish. The frame is dramatically cleaner.

And then the second finding: at the intended dimensions the airstream is
**invisible**. A 2 cm ribbon is two pixels. So the fix is two changes, not one —
see P4.

### D7. Nothing above the deck exists at all

No masts worth the name, no rigging, no stays, no yards, no envelope in frame, no
smoke, no flags, nothing crossing the sky. The one `mast` prop is 3.4 m of
painted billboard that reads as a lamp post. The camera cannot show you what is
overhead — but it can show you the **shadow** of what is overhead, and that
channel is completely unused.

### What the new skybox already fixed, and what it did not

The painted backdrop and the parallaxed cloud banks are good and they matter.
They fix: the colour and content of the sky (there is a moon and weather now,
not a gradient); the sense of being *above* something, because the clouds are
placed 25–30° BELOW horizontal, which is exactly right; and a real parallax
against the deck when the camera moves.

They do not fix, and cannot: the 94% of the frame that is planking; the absence
of an edge (D1, D2); the trapezoid silhouette (D4); any sense of forward speed
(the clouds drift at 0.011–0.024 rad/s, which is slow and lateral, not
oncoming); and the total absence of anything overhead (D7). **The sky is now
good wallpaper behind a problem that is not in the sky.**

---

## 4. Proposals, ranked by impact per effort

Each says where it hooks, what it costs in readability, and whether it is a
gameplay change. **Nothing in P1–P5 touches `DECK_RECT`, `LANE_CENTERS`,
`CARGO_RECTS` or `PROP_LAYOUT`. They are all cosmetic by construction.** P6 and
P7 are flagged.

---

### P1 — A rail you can see the sky through  ·  highest impact, ~40 lines

**Mock: `.shots/deck/rail-starboard-z1.00.png`, against
`.shots/deck/base-starboard-z1.00.png`. Also in `combo-mid-z1.55.png`.**

Replace the two 14 × 40 × 2320 gunwale bars with stanchions and two horizontal
rails, and let the sky through the gaps.

* Stanchions: `BoxMesh(15, 120, 15)`, one every **145 ground units** down each
  side at `x = DECK_RECT.position.x` and `.end.x`. 16 a side, 32 total.
* Rails: two `BoxMesh(13, 11, DECK_RECT.size.y)` at **y = 66 and y = 118**.
* Iron for the posts (`#3a3038`, metallic 0.5), brass for the bars (`#c08f45`,
  metallic 0.65, roughness 0.42) so the moon rims the top rail.
* Hook: `view3d.gd _build_world()`, the `for side in [-1.0, 1.0]` block at ~L436.
  Keep the two end caps at the bow and stern for now.

120 units is 0.68 captains — chest height on a standing figure, which is what a
rail is, and low enough that it never reads as a wall. The stanchions also cast
a rhythm of short shadows inboard, which is free deck detail.

**Readability cost: none, and this is provable rather than hopeful.** The camera
x-position is `_focus.x`, which follows the captain, who is clamped inside
`DECK_RECT`. The rails are AT `DECK_RECT`'s edges. So a rail can never be between
the camera and a figure on the deck — it is always beyond them. The only edge case
is a sight line running nearly parallel to a rail, where the line of sight drops
below 120 units only in the last 5% of its length; worst case is a stanchion
clipping a boarder's boots when both are hard against the same rail. No change to
`_occluded()` is needed.

**Gameplay change: no.**

---

### P2 — Rigging that is only a shadow  ·  the one that reaches the 94%

**Mock: `.shots/deck/rigshadow-mid-z1.00.png`, against
`.shots/deck/base-mid-z1.00.png`.**

This is the proposal the measurement produced and it is the one I would ship
first if I could only ship one, because it is the only item on the list that puts
a ship cue into the middle of the default frame.

Build masts, yards and shrouds as real geometry, then set
`cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY` on every
piece. Godot renders them into the moon's shadow atlas and into no other pass.
**Zero pixels of occlusion, zero pixels of geometry, a full rig printed across the
planking.** Compare the two shots: the captain and every lane are completely
unobstructed and the deck has stopped being a blank floor.

Numbers that worked:

* Three masts, `CylinderMesh` top radius 13 / bottom 26, **height 1500**, 8
  segments, at `(x, z)` = `(280, 900)`, `(−280, 260)`, `(280, −560)` — i.e. on the
  lane dividers, so if any of them is ever promoted to visible geometry it still
  is not standing in a lane.
* A yard at 0.74 × height, `CylinderMesh` r 10, length 1150, rotated 90° about Z.
* Six shrouds per mast: r 4 cylinders from `y = 0.82 × height` down to feet
  spread 300 / 490 / 680 units either side.
* Hook: a new `_build_rigging()` called from `_build_world()` after
  `_build_cargo()`.

The moon is at `rotation_degrees(-52, 34, 0)`, giving a light direction of
`(−0.344, −0.788, −0.510)`. **Every shadow lands 0.437 of its caster's height to
port and 0.647 of it toward the bow.** So a 1500-unit mast at `z = +900` — which
is aft of the camera and never in shot — prints its shadow from there to
`z = −70`, straight across the middle of the deck. That is the trick: the caster
lives where the camera cannot go, the shadow lives where the player is looking.

Two things to get right in implementation:

1. `moon.directional_shadow_max_distance` is **34.0 m** and was deliberately
   tightened to "the deck plus a margin". A 15 m mast at `z = +900` is inside
   that; masts placed further aft will silently stop casting. Re-check the
   number if you move them.
2. `moon.shadow_blur` is 2.2, which softens a 4-unit shroud into a broad band. In
   the mock the mast shadows read slightly as lighting rather than as rope. Either
   thicken the shrouds (they cost nothing — they are never drawn) or reduce blur
   and accept harder contact shadows elsewhere. Try shroud radius 8–10 first.

**Readability cost: none by construction.** There is no geometry in the colour
pass to occlude anything. The only risk is *visual* noise — a shadow lattice
competing with the telegraph decals that warn about incoming attacks. Mitigation:
keep the shadow contrast low (they are already at `shadow_opacity 0.72`, shared
with everything else) and keep the lattice diagonal, since every telegraph in the
game is a circle, a cone or a lane-aligned strip. Worth one playtest specifically
looking for "did I miss a telegraph".

**Gameplay change: no.**

**What NOT to do:** `.shots/deck/rig-mid-z1.00.png` and
`.shots/deck/rig2-mid-z1.55.png` are the same rig with the geometry visible. A
10 cm rope four metres from the lens is a 30-pixel bar; the captain is behind one
of them. Visible rigging anywhere in the near or middle field is fatal. This was
tested twice and failed twice before the shadows-only version was tried.

---

### P3 — A sheer line, so the silhouette stops being a rectangle  ·  ~30 lines

**Mock: `.shots/deck/sheer-mid-z1.55.png`, and in `combo-mid-z1.55.png`.**

Add a strake **outboard** of `DECK_RECT` whose top edge rises toward both ends.
Nothing walkable changes; what changes is the outline against the sky.

* 20 segments a side, `BoxMesh(58, 30 + lift, segment_length)`, centred 29 units
  outboard of the deck edge.
* `lift = 150 · (1−t)^2.2 + 90 · t^2.6`, `t` running 0 at the bow to 1 at the
  stern. Peak 150 forward, 90 aft, zero amidships.
* Hook: same block as P1. Build it before the rail so the stanchions sit on it.

Stack it with P1: the rail rides the sheer and rises at both ends, which is where
the shape actually becomes legible. In `combo-mid-z1.55.png` the two together
change the read of the ship more than anything else in this document.

**Readability cost: none.** Entirely outboard of `DECK_RECT`, and it rises away
from the camera, not toward it.

**Gameplay change: no** — but be careful. A bulwark that rises to 150 units at the
bow is 0.85 captains, and boarders spawn at `y = −1115`, 45 units inside the bow
edge. Check that a spawning boarder is not clipped at the knee by the forward
peak. If it is, cap the forward lift at 110 or move the peak 200 units further
forward, outside the spawn band.

---

### P4 — Fix the airstream, then make it visible  ·  the bug, and then the tuning

Two separate changes and they must not be confused.

**P4a, the bug.** `view3d.gd:2319`:

```gdscript
basis = basis.scaled(Vector3(_stream_len[i * 2] * WORLD_SCALE,
    _stream_len[i * 2 + 1] * WORLD_SCALE, 1.0))
```

`Basis.scaled()` scales in the parent frame. With this basis that puts the length
on world X. The direct fix is to stop scaling the basis at all and put the
dimensions on the mesh instead — give each streak its own `QuadMesh` with
`size = Vector2(length, width) * WORLD_SCALE` at build time and leave
`_sync_airstream` writing an unscaled rotation. Rebuild cost is nothing; there are
48 of them and they are built once.

Verify with `deck_probe.gd -- airsize`, which prints wanted-versus-got. That check
should have existed before this shipped and now it does.

**P4b, the tuning.** `.shots/deck/airfix-mid-z1.55.png` is the corrected geometry
and the streaks are close to invisible — 2 cm is two pixels. The intended
dimensions were never checked either. Proposed starting point:

* Width 14–22 ground units rather than 1.1–2.4. Still a hairline at 3.7 m long,
  but a *visible* hairline.
* Tilt them out of horizontal. A flat ribbon with an up-facing normal is
  foreshortened by `sin(41°) = 0.66` and lit by nothing. Roll each streak
  60–80° about the keel axis so it presents an edge-on-ish face and catches the
  moon rim.
* Bias the population toward `y = 70–200` (ankle to waist) rather than the current
  70–490. Air you can see moving *past the deck surface* sells speed; air at head
  height sells fog.
* Add a second, separate population **on** the deck plane: 20–30 short streaks at
  `y = 4`, alpha 0.10, moving aft at the same rate. Dust and spray skidding along
  the planking is the cheapest speed cue there is and it lands in the 94%.

**Readability cost:** currently *negative* — the shipped bug is actively costing
readability by washing pale bands over boarders. P4a is a readability win. P4b
must be checked at additive alpha; keep total streak alpha at or under today's
0.19 so the fix cannot become a new veil.

**Gameplay change: no.**

---

### P5 — Deck surface work  ·  moderate effort, reaches the 94%

The other channel that gets into the middle of the frame. In rough order of
payoff per hour:

1. **Coamings on the hatches.** `PROP_HEIGHT.hatch` is 44 units of flat painted
   sprite. A hatch on a real deck has a raised rim you would trip over. A
   `BoxMesh` frame 24 units proud, 20 wide, around each of the two hatches. Reads
   as "a hole in a deck" rather than "a decal".
2. **Ring bolts and fore-and-aft ropes.** Cheap `Decal`s on the deck, one every
   ~300 units along the lane dividers. This is what says "working deck".
3. **A darker outboard third.** The deck material is one uniform tile edge to
   edge. Vertex-colour or a second decal band darkening the planking outboard of
   `x = ±620`, where no lantern reaches, would frame the lanes and push the eye
   inward. It also makes the rail rim brighter by contrast.
4. **Plank runs that curve.** `mat.uv1_scale = Vector3(1.8, 7.0, 1.0)` on a flat
   plane gives perfectly straight, perfectly parallel plank lines. Real deck
   planks follow the sheer and nib into a margin plank at the edge. A texture
   whose lines converge slightly toward the bow, plus a distinct margin plank
   along each edge, changes the read of the whole surface for the cost of one
   texture. This is the single highest-value item in P5 and the one I would
   prototype next.
5. **Camber.** The deck is dead flat. A real deck crowns 1:50 — about 170 units
   across a 16.8 m beam. **Do not do this with real geometry**: it would move the
   ground plane that `ground_at()` unprojects against and that every skill aims
   with, which makes it a gameplay change and a bug farm. Fake it in the normal
   map and the plank texture only.

**Readability cost: low but not zero for item 3** — darkening the outboard third
darkens boarders standing in it. Cap the darkening at about 15% and check a
boarder silhouette against it at wave 8, when `set_darkness()` is already pulling
the lights down.

**Gameplay change: no**, provided item 5 stays in the material.

---

### P6 — The prow, and the envelope  ·  two existing assets, both mis-placed

Not new content — two things already in the build that are in the wrong place.

**The prow.** `bow_prow.png` is 900 units tall at `z = −1310`, and per §1 the
budget at the bow is 65 units at zoom 1.0. So it is a wall across the top of the
frame (`.shots/sky/bow-z1.00.png` — it hides the captain entirely), and at other
positions its base floats with deck and the gunwale cap visible *behind and under*
it, which is what a flat pasted into a 3D scene looks like. It is a beautiful
asset doing the wrong job.

Suggested: drop it to ~520 units, push it forward to `z ≈ −1420`, and rake it
back further (it is at −75.6° now; −62° would let you see over it from the bow).
Then add a low bulwark of real geometry across `z = DECK_RECT.position.y`, 130
units tall, so the deck ends at something rather than at the sprite's floating
base. The sprite becomes the thing beyond the bulwark instead of the bulwark
itself.

**The envelope.** Measured in §2: its lowest edge is at about **+5° elevation**
and the top of the frame is at **−23°**. It is off screen at every camera position
and zoom, permanently. It costs a quad and a transform every frame and returns
nothing. Either delete it, or — better — give it the P2 treatment: make it a
`SHADOWS_ONLY` caster. A gas bag the size of the ship hanging overhead should put
the entire deck in soft shade with a bright rim where the moon gets past it, and
*that* the camera can see. This may be the cheapest single line in the whole
document.

**Readability cost:** the envelope-as-shadow darkens the whole deck; it must be
tuned against `set_darkness()` and the wave-8 lights-out event, not on a bright
deck. The prow bulwark is at the bow edge where boarders spawn — check spawn
clipping, as in P3.

**Gameplay change: no**, but the prow bulwark is 130 units of new geometry at the
spawn line. It sits outside `DECK_RECT` and boarders walk aft from `y = −1115`, so
it should never be between the camera and a boarder — verify rather than assume.

---

### P7 — Verticality  ·  ranked last, and mostly ruled out

The brief asks for steps, raised gun platforms, a quarterdeck. The measurement
says most of it is not available and it is more useful to say so plainly.

* **Inside the three lanes: no.** Anything tall enough to see from 41° is tall
  enough to hide a boarder, and `_occluded()` — the x-ray pass that keeps the game
  fair — only tests `CARGO_RECTS` with an axis-aligned rectangle test. Every new
  occluder is either a fairness regression or a rewrite of that function. Not
  worth it for a level change.
* **Below the deck line: no, it is invisible.** I built an outboard gallery,
  dropped 70 units with brackets and its own rail
  (`.shots/deck/catwalk-mid-z1.55.png`). All you see is the tips of the gallery's
  outer rail poking above the deck edge at the far end. Same lesson as D3.
* **Above the deck line, outboard: yes, and it is the only version that works.**
  Raise the outboard strip (P3's sheer strake) into a proper bulwark with a
  cap rail you could stand behind, and run a **narrow raised catwalk on top of the
  cargo runs** at `y = 125`. The cargo tops are already the tallest thing on the
  deck, they are already occluders that `_occluded()` knows about, and putting a
  handrail and gratings up there adds a second visible level without adding a
  single new occluder. Non-walkable — this is set dressing on top of existing
  collision.
* **Behind the Boiler: maybe, and it is a gameplay change.** The Boiler is at
  `(0, 850)` and the deck runs to `y = +1160`, so there is a 310-unit strip aft of
  it that nothing uses. A raised quarterdeck there, two steps up, with a wheel and
  a binnacle, would fix the worst composition in the game
  (`.shots/deck/base-stern-z1.00.png` is 100% planking with an engine on it) —
  **but it changes where the player can stand while defending the Boiler, which
  is the most important tactical position in the run.** Flagged as a gameplay
  change. Do not slip it in. If it is wanted, the cheap version is set dressing
  at deck level: a ship's wheel, a binnacle with a lit compass, a stern lantern
  and a taffrail, all non-walkable, all in that 310-unit strip.

---

## 5. Recommended order

| | proposal | effort | reaches the default frame? | gameplay |
|---|---|---|---|---|
| 1 | P4a airstream bug | ~10 lines | **yes** — removes a defect | no |
| 2 | P2 shadow rigging | ~60 lines | **yes** | no |
| 3 | P1 stanchion rail | ~40 lines | edges + zoom-out | no |
| 4 | P6 envelope → shadows-only | ~1 line | **yes** | no |
| 5 | P3 sheer strake | ~30 lines | zoom-out silhouette | no |
| 6 | P5.4 plank runs + margin plank | one texture | **yes** | no |
| 7 | P4b airstream tuning | ~20 lines | **yes** | no |
| 8 | P6 prow reposition + bulwark | ~25 lines | bow only | check spawns |
| 9 | P5.1–3 deck hardware | half a day | **yes** | low |
| 10 | P7 cargo-top catwalk | ~40 lines | mid-frame verticality | no |
| — | P7 quarterdeck | — | stern only | **YES — flag it** |
| — | D3 hull work | — | almost nothing | no |

Items 1, 2, 3 and 5 rendered together are
**`.shots/deck/best-mid-z1.55.png`**, against `base-mid-z1.55.png`. That pair is
the whole document in two pictures: the rail runs the full length of both sides
with sky between the stanchions and rises at the bow with the sheer, a rig prints
across the planking from masts nobody can see, the haze bars are gone, and the
captain and all three lanes are more legible than they are today, not less. Also
rendered at `best-port-*`, `best-starboard-*` and `best-bow-*`.

Items 1, 2 and 4 are the ones that touch the 94% of the frame the player actually
looks at, and together they are under seventy lines.

---

## 6. Tested versus inferred

**Measured, with the numbers in this document:** the pitch, both fields of view,
the top and bottom ray elevations, the impossibility of the horizon, the 94% /
75% deck fractions, the full vertical budget table, the full lateral budget table,
the visible deck band, the moon's light direction and shadow offsets, and the
airstream's actual versus intended dimensions.

**Rendered and looked at:** base at five positions and two zooms; the headroom
ruler; rail; hull; sheer; catwalk; two versions of visible rigging; shadow-only
rigging; the corrected airstream; and the combinations. Twenty-nine images, all in
`.shots/deck/`, all reproducible from `tools/deck_probe.gd`.

**Inferred, not tested — treat as claims to check:**

* That P1's rail can never occlude a figure. The geometry argument in P1 is sound
  (the rails sit at the clamp boundary the camera also obeys) but I did not render
  a boarder standing at a rail with the camera at the opposite rail.
* That the shadow lattice in P2 will not compete with attack telegraphs. Needs one
  playtest, not a screenshot.
* Every number in P4b, P5 and P6. Those are proposals with starting values, not
  measured results.
* The P3 sheer's interaction with the boarder spawn band at `y = −1115`.
* Performance. Nothing here was profiled. P1 adds 36 draw calls of trivial
  geometry, P2 adds shadow-atlas work for three masts and eighteen shrouds inside
  an atlas that already covers the whole deck, and P6's envelope change is free.
  `scripts/profiler.gd` is always on; check it rather than trusting this
  paragraph.

**All of it was rendered against a tree three other agents were editing
concurrently.** Two runs failed mid-pass on parse errors in `scripts/hud.gd` and
`scripts/cutscene_player.gd` that had nothing to do with this work. Re-run the
tool once the tree is quiet if any shot looks wrong.

---

## 7. Image index

All under `.shots/deck/` unless noted.

| file | what it shows |
|---|---|
| `base-mid-z1.00.png` | the shipped default frame. No edge, no sky, 94% planking. |
| `base-mid-z1.55.png` | **the complaint, in one picture.** A trapezoid slab. |
| `best-mid-z1.55.png` | **P1 + P2 + P3 + P4a together.** A/B against the row above. |
| `best-starboard-z1.00.png` | the same, at the rail. |
| `best-bow-z1.55.png` | the same, at the bow. |
| `base-starboard-z1.00.png` | the deck edge as a gold stripe with sky beyond. |
| `base-bow-z1.00.png` | the prow floating over the deck; the best sky read in the game. |
| `base-stern-z1.00.png` | the worst composition. Boiler, cannons, 100% floor. |
| `headroom-mid-z1.00.png` | measuring poles. Near-field verticality obliterates the frame. |
| `headroom-mid-z1.55.png` | the vertical budget made visible; no pole has a visible top. |
| `rail-starboard-z1.00.png` | **P1.** A/B against `base-starboard-z1.00.png`. |
| `rigshadow-mid-z1.00.png` | **P2.** A/B against `base-mid-z1.00.png`. |
| `rig-mid-z1.00.png` | what visible rigging does. Do not ship this. |
| `rig2-mid-z1.55.png` | second attempt at visible rigging. Also fatal. |
| `sheer-mid-z1.55.png` | **P3.** A/B against `base-mid-z1.55.png`. |
| `combo-mid-z1.55.png` | rail + sheer + hull + visible rig. The edges work; the rig does not. |
| `hull-starboard-z1.00.png` | **D3.** A flared hull, and how little it buys. |
| `hull-mid-z1.55.png` | the same, on the silhouette. |
| `catwalk-mid-z1.55.png` | **P7.** Below the deck line is invisible. |
| `airfix-mid-z1.55.png` | **P4a.** The airstream bands gone. A/B against `base-mid-z1.55.png`. |
| `noair-mid-z1.55.png` | the streaks hidden entirely, as a control. |
| `../sky/bow-z1.00.png` | the prow hiding the captain (this one has the HUD on). |
