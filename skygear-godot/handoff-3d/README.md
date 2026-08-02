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

## The queue — **EMPTY as of 2026-08-02**

Both entries below are resolved, both by the owner's own hand in one day: the
boarding hulk (three models, one per painted state, SG-76) and the furnace
knight (SG-85). Nothing in this folder is waiting on anybody. The two specs
stay below as history — they are the format the next reject gets written in,
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
