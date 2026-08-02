# SkyGear — 3D VFX plan

What Godot can give this game that Canvas 2D never could, in the order the
return justifies the work. Written 2026-07-28, against the state in §13e of
DESIGN.md: ground effects are real projected `Decal`s, the aura is a volume, and
everything else is still a flat sprite or a generated texture.

The through-line: **the browser faked depth and lighting by hand because it had
no choice.** Everything below is a place where we are still faking something the
renderer would do properly and cheaper.

---

## 0. The rule everything is measured against

A VFX change earns its place if a player can **answer a question faster** with it
than without. Ranked by that, not by how it looks in a still:

1. *Is that thing about to hit me?*
2. *Did my hit land, and how hard?*
3. *Where is the edge of my own ability?*
4. *Which element is that?*
5. *Is this ship flying?*

Anything that answers none of these is decoration, goes last, and gets cut first
when the frame budget bites.

---

## 1. Impact particles — `GPUParticles3D` (highest return)

**Question answered: did my hit land, and how hard.**

Right now a hit produces a number and a ring. The number is the only thing that
scales with damage. Everything in `assets/art/fx/` — `ember_particle`,
`puff_steam`, `puff_smoke_dark`, `burst_impact` — exists to be a particle and is
currently used, at most, as a flat decal.

- One pooled `GPUParticles3D` per element, `emitting` pulsed on hit, with
  `amount_ratio` scaled by damage. Godot 4 lets you change `amount_ratio` without
  rebuilding the system, which is the difference between this being free and
  being a stutter.
- `ParticleProcessMaterial` with `emission_shape = SPHERE`, gravity **up** for
  steam and **down** for scrap, `damping` high so they die in place rather than
  drifting into the next fight.
- Billboard mode `PARTICLE_BILLBOARD_ENABLED`, `texture` per element.
- **Budget: one system per element, 4 total, 64 particles each.** Not one per
  hit — a keg chain into forty boarders creates forty systems and that is the
  browser's audio-node leak with a different noun.

**Cost:** ~200 lines. **Risk:** low. **Do first.**

## 2. Element identity through light, not hue — `OmniLight3D` flashes

**Question answered: which element is that, and did it land.**

Colour-blind players get nothing from a teal ring versus an orange one; the v10
review flagged this and shape motifs were the answer in 2D. In 3D there is a
second channel: a hit **lights the deck around it**.

- A small pool of 8 `OmniLight3D`s, claimed on impact, colour from the element,
  energy decaying over ~0.18s.
- Ember warm and slow to fade, Frost cold and instant, Arc a double-flash, Steam
  a soft wide bloom.
- Costs nothing to read at a glance and works with the glow chain already on.

**Cost:** ~80 lines. **Risk:** low, but cap the pool.

## 3. Trails that are geometry, not decals — `ImmediateMesh` ribbons

**Question answered: is that thing about to hit me.**

Enemy bolts currently draw a streak decal on the deck plus a spark in the air.
The decal is the readable half (F-05 was about exactly this) but the bolt itself
has no body. A ribbon mesh built from the trail points the simulation already
keeps would give the projectile a shape in the air *and* keep the ground shadow.

- `ImmediateMesh`, rebuilt per frame from `bolt.trail`, two verts per point
  offset perpendicular to the camera, unshaded additive.
- Same for the Whip's chain jumps, which are currently straight decals on the
  floor and are actually arcs through the air.

**Cost:** ~150 lines. **Risk:** medium — per-frame mesh rebuilds need a cap.

## 4. Volumetric fog for the fields — `FogVolume`

**Question answered: where is the edge of my own ability.**

The aura is a cylinder with a soft wall (§13e) and it works. A `FogVolume` with
`FogMaterial` would make a Steam Field actually *steam*: density falling off from
the centre, the boarders inside it genuinely hazed.

- One `FogVolume` per aura, `shape = CYLINDER`, sized from `skill_stats`.
- Requires `Environment.volumetric_fog_enabled`, which has a real frame cost and
  must be a settings toggle, defaulting **on** for the Windows build and off on
  anything reporting an integrated GPU.

**Cost:** ~60 lines. **Risk:** the frame cost. Measure before committing.

## 5. Screen-space impact — camera shake, chromatic hit, radial blur

**Question answered: did my hit land.**

The browser had screen shake and a tester blamed it for lag; profiling showed it
was innocent (V12-PLAN §2). In 3D it is a transform on the camera rather than a
canvas transform, so it is genuinely free.

- Additive shake: a decaying random offset **on top of** the existing sway, never
  replacing it, so the two do not fight.
- A hit-stop of 40–70 ms on a kill, which the browser has as `killStop` and the
  port does not have at all. This is the single highest-value item on this list
  per line of code, and it is not really VFX.

**Cost:** ~40 lines. **Risk:** none. **Do alongside §1.**

**DECIDED 2026-08-01 — the chromatic hit and radial blur are DROPPED, by the
owner.** Shake and hit-stop shipped; the other two halves of this section are
not built and will not be: `VFX-RESEARCH-AUDIT.md` ("Screen effects") argues
against both on readability grounds, and Alex made the call ("drop 5 for
now"). If it is ever revisited, the audit's constraint stands — prewarmed,
sub-150ms, boss transitions only. Board SG-19 records the decision.

## 6. The captain's weapon trail

**Question answered: did my hit land, and which way was I facing.**

She swings a mesh now. A ribbon following her gauntlet through the swing arc, cut
from the same `slash_arc.png`, tied to the `swing` clip's time rather than to a
timer, so it matches whatever the animation actually does.

Needs a bone attachment (`BoneAttachment3D` on the hand bone), which the rig
supports — 24 named bones, `RightHand` among them.

**Cost:** ~120 lines. **Risk:** low. **After the boarders are meshes.**

**DONE 2026-08-01 (board SG-18).** Built as written, with one correction the
build surfaced: the blade tip is read off the SKELETON's solved pose
(`get_bone_global_pose`), not off the attachment node, which the engine
refreshes a frame late. The tip is sampled every swinging frame into a capped
ring, aged out inside 0.16 s, and drawn as the `_beam_ribbon` two-layer
construction; the fx-clock `_sweep_ribbon` stands down while the blade drives
and stays as the billboard tier's tell. Works for BOTH classes — the
Boilerwright's empty hand gets the same mount with a knuckle's reach
(`mount_hand`). Pinned by the seven `trail ·` checks in the harness
(`trail · the blade tip moves with the swing clip — a bone is being sampled,
not a timer` is the load-bearing one); pictures in `.shots/vfx-sg18/`.

## 7. Deferred: things deliberately NOT on this list

- **A custom shader for the deck.** The procedural planking works and shaders are
  where a project like this loses a week.
- **SDF global illumination / SDFGI.** Beautiful, and a fixed camera over a small
  deck gets almost none of the benefit for a large fraction of the frame.
- **Particle collision.** Sparks bouncing off crates reads as clever for one
  screenshot and costs a depth pass.
- **Decals for blood/scorch accumulation.** The keg scorch is in; a persistent
  accumulating set needs a cap and an eviction policy, which is a system rather
  than an effect.

---

## Order of work

## DONE, 2026-07-28

Items 1, 2 and 5 are in. `scripts/impact.gd` owns hit-stop and shake; the
renderer owns the particles and the light.

- **Hit-stop** at the browser's numbers (70 ms on a kill, 40 on a big hit) and
  with its rule: a big hit always lands, small ones respect a refractory window
  or a Field ticking into six boarders freezes the game six times a second. It
  works by handing the simulation a smaller delta, **never** by touching
  `Engine.time_scale` — a global scale also slows the animation blends, the music
  and the voice, which is not a hit landing, it is the game skipping. Effects and
  the renderer keep running through it, because a frozen explosion reads as a
  crash.
- **Shake** is added to the sway rather than replacing it, on two frequencies so
  it does not read as a sine, capped so a keg cannot throw the deck, decaying
  exponentially so it settles rather than being dragged back. Taking a hit shakes
  harder than landing one.
- **Impact particles**, one `GPUParticles3D` per element rather than one per hit
  — forty boarders dying to a keg chain is forty systems otherwise, which is the
  browser's audio-node leak with a different noun. `amount_ratio` scales the
  burst by damage without rebuilding the system. Steam rises and scrap falls,
  because that is the one thing a particle can say that a ring cannot.
- **Element light flashes**, a pool of eight. Colour-blind players get nothing
  from a teal ring against an orange one; a hit that lights the deck is a second
  channel that does not depend on hue.

Fourteen checks, and every one of them asserts a **cap** rather than a look:
sixty hits in a frame create nothing new.

## DONE, 2026-07-31 — items 3 and 4

Reported again, and more bluntly: *"projectiles and vfx from the player still
look like 2D instead of 3D."* Two separate faults, and only the second was on
this list.

**§3, the ribbons.** Chains, bolts and beams were `_streak_texture` DECALS, and
a decal is a mark projected onto whatever is under it, which for these was
always the planking. At 41 degrees a mark on the floor and an object in the air
are the same picture only when the object in the air is lying on the floor, so a
bolt of lightning read as a scuff. They are geometry now — a strip of triangles
whose width is offset perpendicular to the LINE OF SIGHT at every point, so it
turns its face to the camera instead of vanishing to a hairline.

Every shape in the game got one, not only the three the plan named, because the
most-seen effect in this game is not a Whip: it is the captain's Cleave firing
every 0.36 s for an entire run, and it was a painted fan on the floor.

- **arc** — the blade leads, the trail follows it round, and the ribbon descends
  from 132 units to 58 across the sweep so it reads as a chop through a body.
- **cone** — five plumes blown out of her instead of one wedge on the deck.
- **line** — the head runs out along the shot over the first 42% of the effect's
  life and the tail chases it: **hitscan skills now have a projectile**, drawn
  inside the window the effect already existed for, with no simulation change.
- **chain** — `lift` on the effect, so a Whip jump is an arc over a boarder's
  head rather than a line between two pairs of feet.
- **beam** — a wide soft sleeve with a narrow hot core running inside it.
- **circle** — the ring on the planking stays and a wall of air stands up off it.
- **aoe** — the Mortar records where it was thrown FROM and a shell arcs out.
- **projectiles** — the deck cannons' shots and the drones' now have trails in
  the air, in two colours, because two kinds of ordnance cross the same lanes in
  opposite directions.

Each element has its own handwriting in `ELEMENT_RIBBON` — width, wander, kink,
rise — so Frost is a narrow straight shard that sags and Steam is a broad
wandering cloud that rises, and the two are told apart in grayscale. The
palette colour is SATURATED before it is brightened, because additive blending
turns a pale hue into white and the first pass drew all four elements the same.

**The cost, and what it forced.** Written the obvious way — `ImmediateMesh` and
`surface_add_vertex`, which is what this document proposed — it cost **6.4 ms of
the frame** at the bench's sixty-boarder load, more than twice the whole rest of
the renderer. Three engine calls per vertex at three and a half thousand
vertices is ten thousand crossings out of GDScript every frame, and the crossing
is the cost rather than the geometry. Rewritten as preallocated `Packed*Array`s
handed to one `ArrayMesh` call, the same triangles cost **0.6 ms**.

**§4, the fog.** `FogVolume` per aura, global volumetric density at zero so only
the volumes contribute. Measured, as this document asked: `tests/bench.gd` at 60
boarders reports avg 7.79 / p99 9.54 ms without it and 7.92 / 10.70 with — but
only with temporal reprojection left ON. Off, as the research audit recommends
for a volume that follows a moving player, the tail goes to 13.6 ms, and four
milliseconds of it is not a price a passive that most runs never draft gets to
charge every frame. The trade bought back is a short smear of haze behind the
captain while she runs, which on a Steam Field is what steam does.

Nine checks, and they assert the same thing every other item on this list
asserts: the **cap**. Five hundred ribbons in one frame write no more than the
budget and the ones that do not fit are dropped whole rather than half-drawn.
Plus two that are not about caps at all — every skill effect must NAME the
element its trail is shaped from, and a chain jump must arc where a lance does
not, because both are the "data with no reader" failure inverted and both fail
silently by drawing everything as Ember.

Whole-frame cost of the two items together, three runs each at 60 boarders:
avg **7.6 → 8.4 ms**, p99 unchanged inside its own noise. Budget is 16.7.

Remaining: item 6 (the captain's weapon trail — the Cleave sweep covers the
swing visually now, but it is not bone-driven and does not follow the clip), and
the parts of item 5 the research audit argued against on readability grounds.

Remaining before this pass: item 3 (bolt and chain ribbons), item 6 (weapon
trail, wants the boarder meshes first), item 4 (volumetric fields, measure
before committing).

| # | Item | Answers | Cost | Do |
| - | ---- | ------- | ---- | -- |
| 1 | Impact particles | hit landed | ~200 ln | now |
| 5 | Hit-stop + additive shake | hit landed | ~40 ln | now |
| 2 | Element light flashes | which element | ~80 ln | now |
| 3 | Bolt/chain ribbons | about to hit me | ~150 ln | DONE 07-31 |
| 6 | Weapon trail | hit landed | ~120 ln | after boarder meshes |
| 4 | Volumetric fields | edge of my ability | ~60 ln | DONE 07-31 |

Every one of these gets a harness check that asserts the **pool is capped**,
because every performance problem this project has had — the browser's audio
nodes, its uncapped `fx` list, the 200-million-call health bar — was an unbounded
collection and not a slow algorithm.
