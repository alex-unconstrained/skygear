# The upper deck — a KIT, so the code can build a run of any length

Alex, 2026-08-03:

> *"Maybe we just need more objects like we did with the Ship kit so we can just
> more procedurally build out the prow and stern. For example I wanted there to
> be an upper level that you can see from the deck but you don't actually, or at
> least not currently, go on to it. I'm having it make a staircase model so
> that's where I think would be useful. Maybe I need to know what those might
> look like and I can create the assets."*

Yes — and the answer is five pieces, one of which you have already made.

**Two frames to look at before you read anything else.** They are the whole
brief in a picture:

- `../../.shots/sg176/kit-stem-z1.00.png` — the upper level MOCKED UP out of
  plain boxes, with **your own `rail_stanchion` module** standing on top of it,
  photographed through the shipped renderer at the shipped camera. That is the
  shape you are making. It is boxes; you are making the good version.
- `../../.shots/sg176/band-stem-z1.00.png` — the same view with the band the
  camera can actually see tinted green, and the deck plane drawn in yellow.

---

## First, the thing that killed the last two pieces

You remade the stern once already and it still did not ship. That was not the
model. **At this camera you never see the outside of the hull** — anything at or
below the level of the planking is behind the ship's own edge, and the second
stern changed *nothing at all* in the picture when it was seated correctly.

So before writing a word of this I measured the space instead of guessing at it:
eight and a half thousand marker cubes planted through the air off the bow and
off the stern, each one photographed in and out of the same frozen frame, at
four different camera positions. What came back is simple enough to say in three
sentences.

**The deck plane is the floor of everything visible.** Not one marker below the
planking read at any distance, at either end, at any zoom. That is why two
sterns died, and it is the single rule this kit exists to obey: *build upward
from the deck, never downward from it.*

**Above the deck at the bow there is a real wedge of space, and it closes as it
goes forward.** Standing at the bow she can see about two and a half of her own
height of air above the deck line — but walk that same volume forward by about a
third of the ship's width and the frame top has shut it down to roughly one of
her. The space is a wedge, not a box. **Everything you make should be low and
wide.** A tall piece does not get taller in the frame; it gets cut off.

**And from the middle of the deck — where the player spends the whole run — you
see only the UNDERSIDE.** At the default zoom, nothing at the bow reads at all.
Zoom out and the upper level comes back, but what comes back is the beam under
its front edge and the dark soffit behind that. The floor up there and the rail
around it are above the top of the frame. So: **the most-seen surface in this
whole kit is the underside of the platform and the beam under its edge.** Spend
your detail there. The deck up top is the part almost nobody sees.

---

## What NOT to make — the cut list

This is the most useful part of the document, because it is the hour you do not
spend.

- **Nothing below the deck line.** No hull plating, no transom, no counter, no
  keel, no chains or catheads hanging under the sheer. It cannot be seen. This
  is measured, twice, on two different models.
- **Nothing far out past the ends.** Beyond about half the ship's width past the
  bow, the visible band is a sliver at eye level and a whole module out there is
  a few dozen pixels. A figurehead on a long beak is wasted work.
- **No second flight and no landing on the stair.** One straight flight fits the
  space; two flights would need twice the depth and the far half of it lands
  outside the wedge.
- **No new railing.** See below — yours already works up there.
- **No detail on the outboard thirds.** At the default zoom from the bow, only
  the middle half of the ship's width is reliably in frame. Put the interest in
  the middle and let the ends be plain.

---

## The principle: it tiles

The rail is the one piece of the first kit that shipped, and the reason is not
that it was the best-made — it is that it **repeats**. One module, placed ten
times, builds a rail of any length, and the code chooses the length. The bow and
the stern failed partly because each was one bespoke object that had to be right
in exactly one spot.

So every piece below is a **module**: it butts against a copy of itself, and the
code decides how many. Model one. We will place five, or seven, or one.

---

## 1 · THE PLATFORM BAY — the piece that matters most

**What it is:** one bay of the raised deck's floor — the edge beam you see from
below, the knees bracing it, and a short stretch of planking on top. Copies of
it sit side by side across the ship to make the whole platform.

**Its role:** this is the underside the player looks at all run. The front beam
is the silhouette; the soffit behind it is the shadow. Everything else in the
kit hangs off this one.

```
One bay of a steampunk airship's raised forecastle deck, seen from below and to
one side: a heavy squared timber edge beam running across the front, banded with
riveted iron straps and a brass corner plate at each end, two curved timber knees
bracing back under it, and short deck planking laid across the top. Blackened
iron, warm brass, dark oiled timber, honestly worn — a working ship, not a
carved one. A single free-standing piece with square butt ends so it sits flush
against a copy of itself. Three quarter view from slightly below, complete
silhouette, plain flat background, no ground, no base, no plinth, no figures.
```

**Ratios:** roughly **as deep as it is wide**, and **shallow** — the whole bay,
beam and all, should be about a fifth as thick as it is wide. Think of a heavy
table top with one bold beam under its front edge, not a floor slab.

**What it must read as at a distance:** from across the deck it is a dark
horizontal BAR with a lit top edge. If the front beam does not read as one clean
straight line at fifty pixels tall, it will read as mush. Keep the front face
flat and let the knees be the only things breaking the line.

**How it tiles:** butt ends, left face against right face. **About five of them
make the width of the ship**, so model one that is roughly a fifth of the beam.

---

## 2 · THE SUPPORT POST — what holds it up

**What it is:** a single column standing on the main deck and carrying the
platform above it.

```
A single support post from a steampunk airship deck: a squared dark timber
column with iron collar bands at top and bottom, a riveted brass foot plate
where it meets the planking, and a short flared bracket at the head where it
takes the beam above. Plain, structural, and slightly scuffed at the base where
boots have kicked it. Free standing, nothing beneath it. Front view, complete
silhouette, plain flat background, no ground, no base, no plinth, no figures.
```

**Ratios:** about **three times as tall as it is thick**, and the platform it
holds sits a little over head height — you should be able to picture her walking
under it without ducking. That is the same height as **two of the rails you
already made, stacked**, which is the easiest way to judge it.

**What it must read as at a distance:** a dark vertical tick under the long
horizontal of the beam. Four or five of them make the whole thing read as
STRUCTURE rather than as a floating shelf. Do not make it ornate; at this size
an ornate post is a smudge.

**How it tiles:** one per bay joint, so **five or six across the ship**.

---

## 3 · THE STAIRCASE — the one you are already making

**What it is:** one straight flight from the main deck up to the platform.

```
A short straight staircase from a steampunk airship's main deck to its raised
forecastle: an open flight of thick dark timber treads on two iron stringers,
each tread edged with a worn brass nosing strip, riveted plates where the
stringers meet the deck, and a simple pipe handrail with plain stanchions up one
side. Sturdy, ship's-work, well used. Free standing, nothing beneath it, no
surrounding floor. Three quarter view, complete silhouette, plain flat
background, no ground, no base, no plinth, no figures.
```

**Ratios — and these are the ones that matter most in this document:**

- It must climb **exactly the height of the platform**, which is **two of your
  rail modules stacked**. Build it to that and it lands; build it to anything
  else and it either floats or buries its top tread.
- **A little longer than it is tall** — call it four of run for every three of
  rise. A steeper flight reads as a ladder; a shallower one runs out of the
  wedge and off the top of the frame.
- **About a dozen risers**, each roughly an eighth of the captain's height.
- **ONE flight. No landing, no turn.**

**What it must read as at a distance:** this is the piece with the hardest job.
From across the deck it stands about two hundred pixels tall, so a tread is
worth fifteen or twenty. **A dozen bold risers read as a stair. Forty fine ones
read as a ramp.** Chunky and few. The brass nosing strips are worth their weight
here — a bright line on the front of every tread is what says "steps" at a
glance.

**And where it goes, which the mock-up got wrong first time:** the flight climbs
**forward, out on the open deck, toward the platform's front edge**. My first
mock ran it underneath the platform and the piece simply vanished from the
picture — the platform was between the stair and the lens. A stair here has to
be seen climbing *toward* the thing it lands on.

**How many:** one, at the port side. A second on the starboard side if you want
the symmetry; it is a copy of the same file.

---

## 4 · THE CORNER POST — where a run ends

**What it is:** the piece that finishes the platform's edge at each end of the
run, so the rail and the beam do not just stop in mid-air.

```
A corner post from a steampunk airship's upper deck rail: a stout dark timber
newel with iron banding, a squared brass cap on top, a small hooded oil lantern
bracketed to its outboard face, and a riveted iron shoe at the base. Free
standing, nothing beneath it. Front view, complete silhouette, plain flat
background, no ground, no base, no plinth, no figures.
```

**Ratios:** **a little taller than the rail** — it should stand about a head
above the rail cap so the run visibly terminates — and **roughly twice as thick
as a rail stanchion**, so it reads as an ending rather than as one more post.

**What it must read as at a distance:** a full stop. The lantern is there
because at this camera a small bright point at the end of a long dark run is the
cheapest way to make the eye find the corner.

**How many:** two per platform, four in total if we build both ends.

---

## 5 · THE RAIL — **you have already made this one, and it works**

I checked this properly rather than assuming it: the mock-up in
`kit-stem-z1.00.png` has **your existing `rail_stanchion` module** standing on
the platform, laid across the ship instead of along it, at **exactly the scale
the deck already ships it at**. It reads. It tiles. Its top lands comfortably
inside the visible band.

**So there is no new railing asset in this kit.** Seven copies of the module you
already made cross the ship. Same file, same scale, no work.

That is worth more than a new piece would be — it makes the upper level look
like it belongs to the same ship, and it is the second time that module has paid
for itself.

---

## The rules that make a piece drop straight in

Everything in `../README.md` still holds. These are the ones that bite on this
kit specifically, and I have deliberately dropped the ones that are our job
rather than yours:

- **One object. No ground plane, no base, no plinth, no display stand, no
  figures.** This is far and away the most common failure in this pipeline.
- **Flat albedo, no baked lighting and no painted-in shadow.** The deck's light
  is real and moving; a shadow painted into the texture fights it every frame.
- **The house palette:** blackened iron, warm riveted brass, oxidised copper,
  dark oiled timber, honest wear. No mirror finishes — metalness is clamped on
  the way in, so a chrome-looking generation will come out matte anyway.
- **Square butt ends on anything that tiles**, so a copy sits flush against it.
- **Don't fret the triangle count.** We trim everything to about three thousand
  on ingest, which is what `rail_stanchion` came off your hand at. Detail finer
  than that will not survive, so it is not worth generating.
- **Don't worry about which way it faces.** We measure the heading off the mesh
  and set it in the manifest — the last ingest had to do that anyway because the
  delivery note was wrong about it.
- **If a generation comes back wrong twice, stop and tell me.** Standing rule.

**Delivery:** the plain textured export, dropped anywhere, and tell me the path.
Ingest is one manifest entry and one pipeline run, zero credits. If a piece has
something that should move separately, send the part-segmentation twin too.

---

## What this is, and what it is not

**This is set dressing.** It carries no collision, she cannot walk on it, and
the deck she does walk is unchanged by a single unit. Nothing in the kit stands
inside the play rectangle or between the camera and any figure — the mock-up was
checked against her at the bow and does not touch her.

**If the upper level should ever be WALKABLE that is a different and much larger
job** — a second floor plane, a height for every figure, pathing between the two
levels and a camera that can cope with both. Worth wanting; not worth
smuggling in through an art task. Say the word and it gets its own board row.

One thing we will have to decide when the pieces land, so it is written down
here: **the mock-up throws a hard bar of shadow across the planking.** That may
be atmospheric or it may hurt the readability of the fight underneath it. It is
a one-line switch on our side either way, and it is not something you need to
build around.
