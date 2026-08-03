# Skyship transports — four prompts, in the house frames

Requested by Alex, 2026-08-02. These are **transports that boarders jump from**,
not scenery: one rises alongside, holds station, and its crew jumps the gap onto
your deck. That is why each needs a deck or gunwale the eye can read figures
standing on.

**These use the project's canonical style clauses verbatim**, from
`skygear-godot/tools/meshy.py` — `PALETTE`, and the texture clauses `SURFACE`
and `SURFACE_WOOD`. That file's own comment is the reason: *"The palette
sentence is deliberately shared and deliberately not re-typed — it is the one
clause that has to stay identical across thirty painted assets and everything
generated beside them."* Do not reword them; change the subject line.

## How to run these — it is TWO prompts per ship, not one

Meshy generates geometry first, then paints it in a refine pass. The manifest
keeps those separate on purpose: *"The refine stage is only painting an existing
mesh, so geometry words ('no stand', 'symmetrical') are wasted tokens there — it
takes colour and material direction instead."*

So for each ship below: paste **PROMPT** into text-to-3D, then paste **TEXTURE**
into the refine/texture step for that same model.

**Which texture clause each ship gets matters.** `SURFACE` names five metals and
no timber — a wooden object textured from it comes back a riveted brass
strongbox, which is exactly how the small crate failed. Timber hulls therefore
take `SURFACE_WOOD`. It is chosen per ship below; do not swap them.

---

## 1 · THE SKIFF — fast, cheap, disposable *(timber hull)*

**PROMPT**
```
One small steampunk sky-skiff alone, hovering level, seen from the side. A
single open boat hull of dark riveted timber with brass strapping, a compact
copper boiler amidships venting a short stack, one small gas envelope above on
iron struts, a low gunwale running its full length, grapple hooks coiled at the
bow. Long and low, much wider than deep. No ground plane, no scenery, no crew,
no figures, no duplicate, no lettering. Stylised game-ready steampunk airship:
blackened steel, riveted brass fittings, oxblood leather, oxidised copper
accents, honest wear at the edges. Chunky readable forms and broad flat colour
areas, not photoreal, no micro-detail. Flat albedo, no baked lighting, no baked
shadow.
```

**TEXTURE**
```
Hand-painted stylised game texture: weathered dark timber planks with open
grain, warm polished brass corner brackets and rivets, deep oxblood leather
strapping, coarse pale hemp rope, dull oxidised-copper patina in the recesses.
Any furnace, grate, vent or ember is hot orange; nothing else emits light. Broad
flat colour areas, no baked lighting, no baked shadow, no text, no logos.
```

---

## 2 · THE BARGE — the heavy one, carries the armoured boarders *(timber hull)*

**PROMPT**
```
One heavy steampunk sky-barge alone, hovering level, seen from the side. A broad
flat-bottomed freight hull of dark timber and iron plate, two squat boiler
stacks venting, a wide railed cargo deck with a hinged boarding ramp folded
along one side, four heavy lifting rotors in brass ring mounts on outriggers.
Long, wide and low. No ground plane, no scenery, no crew, no figures, no
duplicate, no lettering. Stylised game-ready steampunk airship: blackened steel,
riveted brass fittings, oxblood leather, oxidised copper accents, honest wear at
the edges. Chunky readable forms and broad flat colour areas, not photoreal, no
micro-detail. Flat albedo, no baked lighting, no baked shadow.
```

**TEXTURE**
```
Hand-painted stylised game texture: weathered dark timber planks with open
grain, blackened iron plate, warm polished brass rivets and ring mounts, deep
oxblood leather strapping, coarse pale hemp rope, dull oxidised-copper patina in
the recesses. Any furnace, grate, vent or ember is hot orange; nothing else
emits light. Broad flat colour areas, no baked lighting, no baked shadow, no
text, no logos.
```

---

## 3 · THE CUTTER — sleek, armed, the dangerous one *(armoured, metal)*

**PROMPT**
```
One sleek steampunk sky-cutter alone, hovering level, seen from the side. A
narrow armoured hull of blackened plate with brass ribbing, a long pointed ram
prow, a single swept gas envelope tight to the hull, twin exhaust nacelles aft,
a small forward gun on a pintle, boarding planks stowed along the rail. Long and
low with a knife silhouette. No ground plane, no scenery, no crew, no figures,
no duplicate, no lettering. Stylised game-ready steampunk airship: blackened
steel, riveted brass fittings, oxblood leather, oxidised copper accents, honest
wear at the edges. Chunky readable forms and broad flat colour areas, not
photoreal, no micro-detail. Flat albedo, no baked lighting, no baked shadow.
```

**TEXTURE**
```
Hand-painted stylised game texture: blackened gunmetal, warm polished brass,
deep oxblood leather, dull oxidised-copper patina settled in the recesses, bare
worn metal along the working edges. Any furnace, grate, vent, ember or lamp
flame is hot orange; nothing else emits light. Broad flat colour areas, no baked
lighting, no baked shadow, no text, no logos.
```

---

## 4 · THE HULK-TENDER — salvage-built, the scrap-goblins' ride *(timber, ruined)*

**PROMPT**
```
One ramshackle steampunk sky-tender alone, hovering level, seen from the side,
built from salvage: mismatched timber and iron plate patched with rivets and
rope, a crooked patched gas bag lashed on with netting, an exposed clattering
engine with pipes going nowhere, a plank gangway hanging off one side, hooks and
chains dangling below. Long, low, asymmetric and unbalanced. No ground plane, no
scenery, no crew, no figures, no duplicate, no lettering. Stylised game-ready
steampunk airship: blackened steel, riveted brass fittings, oxblood leather,
oxidised copper accents, honest wear at the edges. Chunky readable forms and
broad flat colour areas, not photoreal, no micro-detail. Flat albedo, no baked
lighting, no baked shadow.
```

**TEXTURE**
```
Hand-painted stylised game texture: weathered grey timber with open grain and
split boards, rust-streaked iron patches, tarnished dull brass, soot staining,
coarse pale hemp rope and frayed netting, dull oxidised-copper patina in the
recesses. Any furnace, grate, vent or ember is hot orange; nothing else emits
light. Broad flat colour areas, no baked lighting, no baked shadow, no text, no
logos.
```

---

## Why the prompts are shaped this way

Every clause is a lesson something already paid for, and they are recorded in
`tools/meshy.py` beside the frames:

- **"Long and low, much wider than deep"** — the boarding hulk lost three
  prompted attempts to depth. At the locked 41° camera a deep hull sends its own
  mass up out of the top of the frame, leaving only a ramp lying across the deck.
- **"No ground plane, no base"** — the single most common failure here; the deck
  railing came back standing on a timber bench before it came back right.
- **"No crew, no figures"** — the game supplies figures; a modelled crewman is a
  passenger who never moves. (The manifest learned this the other way round:
  calling a character a "prop" returned a suit of armour on a display stand.)
- **"Flat albedo, no baked lighting"** — the deck's lighting is real now, with a
  per-model lights table; a model carrying painted-in shadow fights it.
- **One vocabulary per prompt.** Three assets in this project failed because a
  single prompt carried both halves of an argument — the furnace knight's "no
  glow" against its glowing grate, the hulk's "no airship" against a frame that
  said "airship prop", a wrench prompted in sword nouns. These prompts say
  "airship" and never negate it; that is why the hulk's own "no balloon, no
  sail, no mast, no rigging" line is deliberately absent here — a transport is a
  ship and is allowed all four.
- **Separate rotor and envelope masses** — the gunner drone arrived as one
  welded surface, so its propellers had to be found afterwards by measurement
  before they could spin. Keep them visually distinct and that is free.

**Target size:** 600–900 ground units long (6–9 m) for skiff, cutter and tender;
up to ~1400 for the barge. Seen below and beside the ship, so length and bulk
read more than height. Exact scale is not critical — the ingest measures and
normalises — but landing within about 2× avoids surprises.

**Delivery:** the plain textured export (`..._texture.glb`). If you also run
part-segmentation on one with a rotor or envelope that should move, **send both
files** — the boss taught us the segmentation export alone carries no UVs and no
textures at all. Drop them anywhere and tell the loop the path; ingestion is one
manifest entry and one pipeline run, zero credits.

**When these land**, the four frames above should be folded back into
`tools/meshy.py` as a `SHIP`/`STYLE_SHIP` entry beside `PROP`, `TOOL`, `FLYER`
and `HULK`, so the next vehicle is one manifest line rather than a fresh
paraphrase. Recorded so it is not forgotten.
