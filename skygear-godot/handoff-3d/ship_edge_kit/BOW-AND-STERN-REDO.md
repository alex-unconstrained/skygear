# The bow and the stern — remake, with the numbers that say why

Alex, 2026-08-03, looking at the A/B renders: *"Bow and Stern look horrible
here - definitely need to rework those and/or scale them better."*

Agreed, and the good news is that both failures are **proportion, not craft**.
Neither piece is badly made; each is the wrong *shape of box* for where it has
to sit. The rail from the same kit went straight in and ships at N = 10.

**Frames to look at first:** `../../.shots/owner-review/1-bow-stern-mast/` —
`bow-2-at-bow-line__*.png` and `stern-1-own-size__*.png` are the fair ones.
Left half of each sheet is the deck as it ships; right half is the piece in.

---

## The deck you are building for, in one block

Everything below is measured off the running game, not remembered.

```
deck rectangle        1680 wide  x  2320 fore-and-aft      (ground units)
lanes                 x = -560, 0, +560
the captain           176 units, sole to crown
the rail (accepted)   top at 125 units = 71% of the captain, tiled N = 10
camera                fixed 41 degrees, looking down the deck
```

**One ground unit = 0.01 m at model scale.** A piece modelled 1.90 long is
190 ground units before the placement scale is applied, which is why every kit
piece so far has been modelled at ~1.9 on its long axis. Keep doing that.

---

## 1 · THE BOW — it is a torpedo prow, and this ship is blunt

**What is wrong, measured.** `bow_ram` is **1.90 × 0.76 × 0.52** — a **3.64 : 1**
long-and-narrow spike. At the bow line it reads as *a dark elongated mass
directly behind her head*; pulled forward it becomes a big dark leaf hanging in
the sky, reading as a separate object rather than as part of the ship.

**The real problem is that it disagrees with the hull it is bolted to.** The deck
is 1680 wide and the bow only has ~560 of run to work with, so **this ship's bow
is wider than it is long.** A 3.64:1 spike is the silhouette of a torpedo boat.

**What to model instead: roughly 3 : 1 WIDE.**

```
across the ship (long axis, model it as ~1.90)    1680 ground units of hull
fore-and-aft (the run to the stem)                ~560 ground units   -> 0.63
above the deck plane                              ~90 ground units    -> 0.10
```

So: **1.90 wide × ~0.63 deep × ~0.10 tall**, modelled with the WIDTH on the long
axis. A broad blunt cutwater, not a lance.

**Look at the LEFT halves of the bow sheets before you start** — the hull apron
already reads as a bow: two bulwarks converging on a stem. You are not adding a
bow to a deck that lacks one, you are **giving the existing one a nose**. That
argues for restraint: a stem post, a rubbing strake carrying the bulwark line
round, maybe a modest ram boss on the centreline. If it reads as a separate
object, it is too big.

---

## 2 · THE STERN — closer than it looked, and it fails on SEATING

Be aware the earlier write-up was too harsh here and the render agent said so.

**What is wrong, measured.** `stern_counter` is **1.89 × 1.51 × 1.79** — a
**1.25 : 1** near-cube. Three placements were shot:

- **at its own size** — does **not** hide the captain, sits in the black void
  below the deck edge, and genuinely gives the frame a transom. Some of this is
  nice. **But it floats — it does not meet the deck edge.**
- **brought forward** — cuts the captain off at the waist. Unusable.
- **scaled toward the transom** — swallows the frame and the texture goes to mush.

**So the piece does not need to be smaller or bigger. It needs a flat top edge
that SEATS onto the deck.** A transom is a face that closes the hull; what is
there now is a block parked near one.

**What to model instead:**

```
across the ship (long axis, model it as ~1.90)    1680 ground units, to match the deck
down from the deck plane                          ~260 ground units   -> 0.29
fore-and-aft (how far it projects aft)            ~180 ground units   -> 0.20
```

Roughly **1.90 × 0.29 × 0.20**, and the thing that matters more than any of those
numbers: **the top face must be flat, level, and exactly the deck's width**, so
it butts against the deck edge with no gap and no overlap. Model it as if the
planking continues off the back of it.

It hangs BELOW the deck, into the dark, which is why it can be generous without
blocking anybody.

---

## The rules that make these drop straight in

All of `../README.md` still holds. The ones that bite hardest here:

- **GLB, Y up, metres.** Model along one axis; state which way is "forward" and
  I will handle rotation in placement.
- **No ground plane, no base, no plinth, no display stand.** This pipeline's most
  common failure.
- **House palette, flat albedo, no baked lighting or shadow.** The deck's light
  is real and a painted-in shadow fights it.
- **Metalness:** ingest clamps it now (Alex approved the clamp 2026-08-03, all
  17 over-metallic models done), so you need do nothing — but do not bake a
  mirror finish into the albedo either.
- **≤ 3,000 triangles each.** `rail_stanchion` came off your hand at 3,060, was
  judged by eye on the real GPU, and was adopted. Same kit, same camera, same
  budget. Ingest decimates with `tools/deck_trim.py`, which copies the texture
  bytes rather than re-encoding them.

## Delivery

Drop them anywhere and say where. Ingest is one manifest entry and one pipeline
run, **zero credits**, and I will shoot the same A/B pairs so the judgement is
made the same way it was made this time.

**Two failed attempts and I stop and come back to you** rather than burning more.
