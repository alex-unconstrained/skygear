# Skyship transports — four prompts, ready to paste into Meshy

Requested by Alex, 2026-08-02. These are **transports that boarders jump from**,
not scenery: one rises alongside, holds station, and its crew jumps the gap onto
your deck. That is why each one needs a deck or gunwale the eye can read figures
standing on.

Paste a prompt below straight into Meshy text-to-3D. Deliver the **plain
textured export** (`..._texture.glb`); if you also run part-segmentation on one
with a rotor or envelope that should move, **send both files** — the boss taught
us the segmentation export alone carries no UVs and no textures.

---

## 1 · THE SKIFF — fast, cheap, disposable

```
A small steampunk sky-skiff, a single-masted open boat hull of dark riveted
timber with brass strapping, a compact copper boiler amidships venting a short
stack, one small gas envelope above on iron struts, a low gunwale running its
length, grapple hooks coiled at the bow. Long and low, much wider than deep.
Stylised chunky game asset, blackened steel and warm brass and oxblood leather,
broad flat colour areas, flat albedo, no baked lighting, no crew, no ground, no
base.
```

## 2 · THE BARGE — the heavy one, carries the armoured boarders

```
A heavy steampunk sky-barge, a broad flat-bottomed freight hull of dark timber
and iron plate, two squat boiler stacks venting, a wide railed cargo deck with a
hinged boarding ramp folded along one side, four heavy lifting rotors in brass
ring mounts on outriggers. Long, wide and low. Stylised chunky game asset,
blackened steel, riveted brass, oxidised copper, broad flat colour areas, flat
albedo, no baked lighting, no crew, no ground, no base.
```

## 3 · THE CUTTER — sleek, armed, the one that looks dangerous

```
A sleek steampunk sky-cutter, a narrow armoured hull of blackened plate with
brass ribbing, a long pointed ram prow, a single swept envelope tight to the
hull, twin exhaust nacelles aft, a small forward gun on a pintle, boarding
planks stowed along the rail. Long and low with a knife silhouette. Stylised
chunky game asset, blackened steel and warm brass, broad flat colour areas, flat
albedo, no baked lighting, no crew, no ground, no base.
```

## 4 · THE HULK-TENDER — salvage-built, the scrap-goblins' ride

```
A ramshackle steampunk sky-tender built from salvage: mismatched timber and
plate patched with rivets and rope, a crooked patched gas bag lashed on with
netting, an exposed clattering engine with pipes going nowhere, a plank gangway
hanging off one side, hooks and chains dangling below. Long, low, asymmetric and
unbalanced. Stylised chunky game asset, rust, soot, weathered timber, tarnished
brass, broad flat colour areas, flat albedo, no baked lighting, no crew, no
ground, no base.
```

---

## Why the prompts are shaped this way

Every clause below is a lesson something already paid for:

- **"Long and low, wider than deep"** — the boarding hulk lost three prompted
  attempts to depth. At the locked 41° camera a deep hull sends its own mass up
  out of the top of the frame, leaving only a ramp lying across the deck.
- **"No crew"** — the game supplies figures; a modelled crewman is a permanent
  passenger that never moves.
- **"Flat albedo, no baked lighting"** — the deck's lighting is real (there is a
  per-model lights table now); a model carrying painted-in shadow fights it.
- **"No ground, no base"** — a plinth is the single most common Meshy failure
  here; the railing came back on a timber bench before it came back right.
- **Separate rotor/envelope masses** — the gunner drone arrived as one welded
  surface, so its propellers had to be found afterwards by measurement before
  they could spin. Keeping them as obvious separate masses saves that.

**Target size:** 600–900 ground units long (6–9 m) for the skiff, cutter and
tender; up to ~1400 for the barge. They are seen below and beside the ship, so
length and bulk read more than height. Exact scale is not critical — the ingest
measures and normalises — but landing within about 2× avoids surprises.

**Delivery:** drop the files anywhere and tell the loop the path. Ingestion is
one manifest entry and one pipeline run, zero credits.
