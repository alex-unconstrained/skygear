# 3D handoff — assets Meshy could not deliver, for Alex to model manually

**The rule (owner, 2026-08-02):** when Meshy fails an asset twice, agents stop
spending and the asset lands here — its 2D reference art copied in, with the
exact spec the pipeline needs. Nothing in this folder is waiting on an agent;
everything is waiting on a human with a modeling tool.

## What the pipeline needs from any model you make

- **Format:** GLB preferred (FBX and OBJ both ingestible). One file per asset.
- **Orientation:** Y up, the asset's FACE toward **+Z** — the locked 41° camera
  looks down-deck, so +Z is the side players see. A prop authored face-+Z reads
  square-on; anything deep loses its depth off the top of the frame (the
  boarding-hulk lesson).
- **Scale:** meters; the target height in each asset's spec below. 1 m = 100
  ground units. Exact scale matters less than proportions — the ingest
  measures and normalizes — but landing within 2× avoids surprises.
- **Budget:** ≤ 4,000 triangles for props (`0.021 × px²` at on-screen height is
  the project law); base color ≤ 1024². Chunky readable forms, broad flat
  color areas — no micro-detail; it renders at most a few hundred pixels tall.
- **Palette:** blackened steel, riveted warm brass, oxblood leather, oxidised
  copper accents, warm timber. Flat albedo, no baked lighting or shadows.
- **Figures only:** clean A-pose, arms clear of the torso, a neck present,
  hands empty (weapons are separate bone-mounted meshes), no cape/cloth
  (cloth is its own layer). These are hard rules — Mixamo and the retargeter
  both refuse violations.
- **Delivery:** drop the file in this asset's folder (or anywhere) and tell
  the loop the path — ingestion is `tools/models.json` + one pipeline run;
  static props wire via `PROP_MODEL`/`static_model.gd`, figures via the rig
  path.

## The queue — **FOUR FIGURES, requested by the owner 2026-08-02**

The rule that filled this folder was "two Meshy strikes and it escalates".
These four did not wait for the strikes: after making the hulk and the knight
himself in one afternoon, the owner asked for the whole remaining figure
migration to come here instead — *"I think the best way to do the figure
migration is to have me make the 3D meshes manually and then rig them, the same
way we did the other enemies."* Route confirmed by results: two hand-made
assets shipped the day five prompted attempts failed.

**The route that worked twice, in order:** model the mesh → export OBJ →
upload to Mixamo (OBJ, not FBX — an FBX carrying structure makes Mixamo try to
map an existing skeleton and refuse) → place the auto-rig markers → download
one clip **with skin**, the rest **without skin** → hand the loop the folder.
Ingestion is one `models.json` entry and one pipeline run, zero credits.

**Priority order** (biggest visual return first): SWARM, then the COLOSSUS,
then CREW; the GUNNER last and probably never — read its entry.

### swarm_gremlin/ — the fastest and most numerous boarder
**Height 83 ground units (0.83 m)** — the smallest thing on the deck, and it
comes six at a time in later waves, so it is the figure a player sees most
after the captain. 20 hp, 230 speed: a scuttling scrap-goblin. Small, low,
quick; hunched is fine, but the standing rules still bind — A-pose with arms
CLEAR of the torso and a neck present, or Mixamo's rigger refuses (it refused
the old scrapper mesh five times for exactly that, and the fault was
proportion, not pose). Hands EMPTY; if it should carry a shiv, that is a
separate bone-mounted asset. Clips wanted: walk/run, one swing, a flinch,
and a **death** — the knight's pack gave the game its first death animation
and the swarm dying in numbers is where it will read most.

### colossus_boss/ — **RESOLVED BY THE OWNER (2026-08-02)** — was: the wave-12 boss, the one figure with a fight of its own
**Height ~360 ground units (3.6 m), the biggest thing that walks.** It has two
beats the sim already plays: it TURNS at half health (cannot be burst through
the turn) and it vents what it called. Clips wanted beyond the usual: an
**idle**, a **walk**, at least two distinct **attacks**, a **turn/roar** beat
for the half-health moment, and a **death** — its death is the end of a run and
currently it just stops existing. Massive, slow, armoured; the painted one is
a hunched brass giant. Same A-pose/neck/empty-hands rules.

**DELIVERED, and the spec above stays as history — but read what follows before
writing another entry like it, because this spec asked for the wrong thing and
got something better.** The owner modelled the Brassbound Juggernaut and
delivered it as a Meshy **part-segmentation** export: not one mesh, but THIRTEEN
separate geometries. And he chose the approach with it — *"I feel like if we just
do simple segmented movement it might work well for the boss. It's not exactly a
humanoid model, and it doesnt move that much, and its death animation could be
the parts just falling apart."* Wired under board **SG-90**
(`assets/models/boss/`, 330 ground units, 7,994 triangles from 1,366,036, five
clips, `.shots/clips/boss.gif`).

**THE SEGMENTED ROUTE IS WHY IT WORKED, and it is the thing this folder should
carry forward.** Every rule at the top of this file — A-pose, arms clear, a neck
present, hands empty — exists to satisfy **Mixamo's auto-rigger**, and this asset
never went near it. It did not need to:

* **A machine delivered in pieces needs no rig at all.** `tools/rig_local.gd`
  argued that a rigid bind is "the honest material on a riveted machine", and
  paid for it with candy-wrapper elbows it did not want — it pays that because
  the scrapper arrives as ONE SURFACE and a surface has to be cut somehow. This
  arrived already cut, so a part is a node, its joint is that node's origin, and
  a hinge is a rotation. No skeleton, no skin weights, no seam to stretch, and
  `scripts/rig3d.gd` drives it without knowing it is not a rig.
* **The death fell out of the format.** "The parts just falling apart" is not an
  effect that had to be invented for this model; it is the articulation running
  backwards, and every part breaks at the joint it hinged on because those are
  the same point. It plays through the furnace knight's existing death seam with
  no simulation change and no new pool.
* **And it made the decimation free.** 1.37 MILLION triangles arrived against a
  budget of 8,000. Decimating the CAPTAIN is still an open decision (board SG-13)
  purely because her skin weights ride her vertices — a rigid part carries
  nothing but its own surface, so this was local, safe and cost zero credits.

Three things a future spec should say that this one did not:

* **Say whether the asset may arrive SEGMENTED.** This entry asked for a rigged
  humanoid because that was the only shape the pipeline had. For anything that is
  a machine rather than a body — and `gunner_drone/` below is the other one —
  segmented parts are the better ask, and there is a route for it now:
  `tools/segment_parts.py` then `tools/rig_parts.gd`, both zero-credit.
* **A part-segmentation export is a VISUALISATION, and its colours are labels.**
  It carries no UVs and no texture images; every part arrives flat-filled from a
  plotting palette. Ship it as delivered and the deck gets a harlequin. Budget a
  palette pass — and expect any emission the painted version had, here the
  furnace grate, to become a LIGHT instead, because there are no UVs to map one
  onto.
* **The height in this entry was wrong, and was not used.** It asked for ~360
  ground units; the archetype's own arithmetic says **330**, and the renderer's
  `boarder_height` is the single copy of it. Same discipline as the knight's 216:
  a spec should cite the simulation's number rather than estimate one beside it.

### crew/ — your own sailors, the last friendly 2D figures
Three painted states (front idle, front attack, back idle) and they stand
beside the cannons all run. They are the only ALLY figures left flat, so once
the boarders are meshes they will be the thing that looks wrong. Height should
read a touch under the captain's 176 gu — call it **~1.7 m**. Clips: idle,
walk, a work/attack swing, a death. One mesh serves every crew member (they
are identical by design); a second variant would be a bonus, never a
requirement.

### gunner_drone/ — **probably never; read before spending an hour**
**Height 92 ground units (0.92 m)**, a hovering propeller drone that shoots
from 340 units. The scrapper pilot's verdict was explicit: *"the GUNNER is a
propeller drone that will never pass a humanoid rig — prop-spin/bob
procedurally instead."* It has no legs, no spine and no arms to place markers
on, so Mixamo is the wrong tool for it entirely. If you want it in 3D, the
right shape is a **static mesh** (rotor as a separate child so the renderer can
spin it) — no rig, no clips, and the loop animates the spin and bob in code.
Deliver it that way and it is a twenty-minute wiring job; deliver it rigged and
the rig is wasted.

---

## Resolved — the two you already did

Both resolved by the owner's own hand in one day: the boarding hulk (three
models, one per painted state, SG-76) and the furnace knight (SG-85). The two
specs stay below as history — they are the format an entry gets written in,
and the notes under each are what the specs failed to say.

### furnace_knight/ — **RESOLVED BY THE OWNER (2026-08-02)** — was: FINAL Meshy reject (two attempts, July)
The 180-hp mini-boss that cannot be walked through; still a 2D sprite, the
one boarder breaking deck consistency. Neither attempt read as a wall of
armor. Target: ~2.0 m tall, massive silhouette, furnace-grille chest that
emits (emission map: hot orange, nothing else). Reference PNGs in folder.

**DELIVERED, and the spec above stays as history.** The owner modelled him as
the **Emberforge Sentinel** and ran the OBJ through Mixamo's auto-rigger,
delivering the SG-74 Boilerwright shape exactly: one rigged character FBX plus
51 animation-only clips on that same rig. Wired under board **SG-85** as the
SECOND rigged boarder (`assets/models/armored/`, 216 ground units, 3,080
triangles, 11 clips wired of 51 aboard) — and he brings the first death
animation this game has ever played.

Three things worth carrying forward, because they are what the spec was FOR:

* **The emissive chest was met, and it made the pipeline grow a reader.** The
  spec's "emission map: hot orange, nothing else" is literally what his sheet
  contains, and until this asset `tools/ingest_model.gd` threw every emission
  map away. It reads one now. Two numbers for whoever writes the next spec: a
  Meshy emission sheet is authored DIM (his peaks at 49/255, which is 0.03 in
  linear light and invisible at 1x — the energy is manifest data), and the
  material's emission BASE must stay black, because the operator is ADD and a
  white base lights the whole mesh instead of tinting the map.
* **The height and the proportions landed.** ~2.0 m asked, 2.16 m drawn — the
  simulation's own number for the archetype, not a guess — and at the real
  camera the mass reads: he is a wall.
* **What a figure spec should ALSO say: what is in its hands.** The painted
  knight carries a double-bladed axe and the model carries nothing, because the
  animation pack that rigs him is a great-sword pack with no weapon mesh in it.
  Weapons are a separate bone-mounted layer here (that rule is above, and it is
  right) — but the spec never said "and the axe is a second asset", so nobody
  costed it. Filed as SG-86.

### boarding_hulk/ — **RESOLVED BY THE OWNER (2026-08-02)** — was: FINAL Meshy reject (three attempts; SG-64)
v1 a submarine; v2 a box whose mass vanished up out of frame; v3 — the
owner's one constrained re-attempt — got the WALL (face filling the top of
frame, ramp on the planking: .shots/sg64/hulk-after-mid.png) and lost anyway:
pale cracked STONE masonry and a Gothic ARCH door against three painted
states of dark round-iris iron, and the depth ratio ignored a third time
(measured 1.639 deep against 1.899 wide; asked for 0.25 — text-to-3D will
not hold a depth ratio, now known at ninety credits' certainty). Target: a
wide SHALLOW armored wall — much wider (4.2 m) than deep (≤1.2 m), ramps as
separate low geometry, one glowing open ROUND IRIS door in the +Z face, dark
iron plate + near-black timber + brass straps (all three painted states wear
the iris — the mesh must be the same object as the sealed/destroyed
sprites it swaps with). Reference PNGs in folder.

**DELIVERED, and the spec above stays as history.** The owner ran his own
session on 2026-08-02 and made THREE models, one per painted state — which is
more than this entry asked for, and it is the part no prompt ever got: the same
hull wearing a shut door, an open one and a burst one, so the swap is a face
changing rather than a different vehicle arriving. Wired under board SG-76
(`assets/models/boarding_hulk_{sealed,open,destroyed}/`, judged at the bow and
from mid-deck, all three adopted).

Two things this queue should carry forward, because they are what the spec was
FOR and they were not all met:

* **The depth ratio was violated a fourth time** — 0.58, 0.59 and 0.81 against
  the 0.25 asked for here. It is a NOTE on the owner's own models, not a
  rejection, and at the real camera the depth is not the disaster three
  prompted attempts made it: the models are WIDE (1.87–1.90 against 0.93–1.11
  tall), so the mass stays in frame instead of going up out of it, which was
  the actual v2 failure. What it does cost is written on SG-84 — a hull deep
  enough to swallow the captain, because nothing stops her at it.
* **A hand-modelled asset needs no prompt but still needs a sidecar.** Each
  state carries a `meshy.json` recording the file the owner delivered, the
  state he stated, why the mapping was overruled (two of the three were
  swapped), and the spec line it departs from. Anyone reading these folders in
  six months gets the same story the generated props' sidecars tell.

**The mapping he stated was wrong in two places, and the models said so.**
"Ironbound Gate" (stated OPEN) is the SEALED face; "Emberforge Core" (stated
CLOSED) is the OPEN one — it is the only one of the three with anything alight
in its emission map. Verify by looking, not by reading the file name: that is
the rule this folder should keep for anything delivered by hand.

*(Agents append new entries below as two-strike rejects occur, copying the
2D reference art in and writing the target spec in this format.)*
