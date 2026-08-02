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

## The queue

### furnace_knight/ — FINAL Meshy reject (two attempts, July)
The 180-hp mini-boss that cannot be walked through; still a 2D sprite, the
one boarder breaking deck consistency. Neither attempt read as a wall of
armor. Target: ~2.0 m tall, massive silhouette, furnace-grille chest that
emits (emission map: hot orange, nothing else). Reference PNGs in folder.

### boarding_hulk/ — FINAL Meshy reject (three attempts; SG-64, 2026-08-02)
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

*(Agents append new entries below as two-strike rejects occur, copying the
2D reference art in and writing the target spec in this format.)*
