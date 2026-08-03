# The ship's edge kit — four pieces that stop the deck being a floor

Requested by Alex, 2026-08-02, after the deck read as *"a floating plane - not
the deck of a ship."* That complaint is measured fact: `docs/DECK-DESIGN.md` §1
found **94% of the default frame is planking, and the near two thirds carries no
ship's edge at all.** The defect is peripheral, so the fix is peripheral — these
four pieces wrap the play rectangle without changing a single gameplay number.

**The rectangle never moves.** 1680 × 2320 ground units, lanes at ±560, eight
cargo rects, three crossings, the spawn line. Everything below sits OUTSIDE or
ALONG that boundary; none of it is walked on and none of it collides.

## The pipeline — his idea, and it beats text prompts

1. **Aether Loom → a 2D concept** in the house style. It is the tool that drew
   every character sprite in this game, so the style arrives as a picture rather
   than as adjectives.
2. **Meshy image-to-3D** from that concept instead of text-to-3D. Every prompt
   failure recorded in `tools/meshy.py` was a text prompt losing an argument
   with itself; an image cannot do that.
3. Deliver the textured export. Send a part-segmentation twin only if something
   should move.

**THE LOOM IS NOT RUNNING** — checked, connection refused on 8765. To start it:

```powershell
cd C:/Users/alexr/Documents/Codex/2026-07-26/done-66-images-fully-specced-for
.\run_aether_loom.ps1
```

It serves at http://127.0.0.1:8765. Once it is up, the concept prompts below can
be pasted straight in — or say the word and an agent will drive `tools/forge.py`.

---

## The four pieces

### 1 · THE RAIL MODULE — worth the most, and the one generation keeps failing

**What:** ONE section of gunwale that TILES along both sides — a repeating unit,
not a full-length rail. Two horizontal rails on stanchions, a capping timber,
ironwork at the foot.

**Why it leads:** a rail reads as a rail because you SEE SKY THROUGH IT. The
periodic gap is the entire cue, and the current solid bar cannot produce it at
any camera. It is also where prompting fails worst — a generated railing came
back standing on its own timber plinth (SG-72), because a small repeated object
invites a base.

**Hard requirements:** free-standing; **no plinth, no base, no ground**; the gaps
between stanchions genuinely open; tileable, so its left edge meets the right
edge of a copy of itself.

**Size:** ~145 units between stanchions, rails at ~66 and ~118 units high
(measured in `docs/DECK-IDENTITY-DESIGN.md` item 4).

### 2 · THE BOW ASSEMBLY — replaces the painted prow he asked to delete

**What:** the forward end — a stem narrowing to a point, the timber apron
carrying the deck forward, the rail returning around the curve, a cathead or
figurehead if it earns its place.

**Why:** `assets/art/env/bow_prow.png` is being retired because at this camera a
painted prow can only read as a wall — there are **65 units of vertical headroom
at the bow at zoom 1.0**, so the ship's nose must live in the deck PLANE and be
looked ALONG rather than at.

**Hard requirement:** it must read as depth receding away from the player, never
as a fence standing in front of her. Long and low, tapering in plan.

### 3 · THE STERN ASSEMBLY

**What:** the aft end — transom, rail return, the hull tapering closed.

**Why:** cheapest of the three edges, since the aft half is off screen unless the
captain walks into it. It is here because *a ship with a bow and no stern is a
wedge.*

### 4 · THE MAST-AND-RIGGING KIT *(optional, and wanted anyway)*

**What:** a mast with a yard and shrouds — one unit, repeated three times.

**Why it is worth more than it looks:** `DECK-IDENTITY-DESIGN.md` item 1 wants
these as **shadow casters only**. The camera never looks up, so the masts
themselves are never seen — but the moon throws their rigging as a lattice
**across the middle of the deck**, which is the 94% of frame the player stares at
all run. A mast you cannot see is the cheapest shiplike line available.

**Size:** ~1500 units tall, yard at ~0.74 of height, six shrouds a side.

---

## 2D concept prompts — for the Loom, once it is running

These are concept sheets to feed Meshy image-to-3D, so they ask for a clean
view on a plain background rather than a scene. `tools/forge.py` appends the
house `STYLE` block automatically — do not reword it.

**RAIL MODULE**
```
A single repeating section of airship deck railing: two horizontal rails on
turned iron stanchions with a capping timber and riveted brass feet, free
standing, nothing beneath it, the gaps between stanchions clearly open. Three
quarter view, complete silhouette, plain flat background, no ground, no plinth,
no base, no deck, no scenery, no figures.
```

**BOW ASSEMBLY**
```
The forward end of a steampunk airship hull seen from above and to one side: a
timber stem narrowing to a point, riveted brass strapping, the deck apron
carrying forward and tapering, the gunwale rail returning around the curve. Long
and low, tapering in plan. Three quarter view from high, complete silhouette,
plain flat background, no ground, no water, no scenery, no figures.
```

**STERN ASSEMBLY**
```
The aft end of a steampunk airship hull seen from above and to one side: a flat
transom of riveted timber and brass, the gunwale rail returning around it,
lanterns on the corners, the hull tapering closed beneath. Three quarter view
from high, complete silhouette, plain flat background, no ground, no water, no
scenery, no figures.
```

**MAST AND RIGGING**
```
A single steampunk airship mast: a banded timber pole with iron collars, one
horizontal yard across it, six rope shrouds running down to iron deadeyes, a
small crow's nest. Free standing, nothing beneath it. Front view, complete
silhouette, plain flat background, no ground, no base, no deck, no scenery, no
figures.
```

---

## Standing rules that still apply

Everything in `../README.md` holds — Y up, face toward **+Z** (the locked 41°
camera only ever sees that side), metres, ≤4,000 triangles per piece, the house
palette, flat albedo with no baked lighting, and **no ground plane, no base, no
plinth** — the most common failure here, and the exact one the railing already
hit.

**Delivery:** drop the files anywhere and tell the loop the path. Ingestion is
one manifest entry and one pipeline run, zero credits.

**Sequencing:** an agent is building the bow, stern and sheer as procedural
geometry right now. Look at that first, then hand-model whichever pieces still
read wrong. Replacing a known-bad part beats betting the whole edge on one
generation.
