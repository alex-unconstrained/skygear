# Vertical-slice level kit — engine compositing requirements

Five assets, plus the characters already delivered, to test whether the whole
scene holds together stylistically before the remaining ~57 are generated.

This document is only about **what the engine does with each layer**. Style,
palette and lighting still come from `skygear-visual-asset-spec-v1.md`.

---

## Camera bake — CORRECTED

**Generate at 49°, render at 41°.** These are deliberately different and the
combination was tested as a matched set in engine.

| | |
|---|---|
| **Asset bake** | **49°** — the `production_49deg` set. It reads as genuinely looked-down-at: crown of the head visible, shoulders foreshortened, boots seen from above. The 40° trial set reads nearly eye-level and sits like a standee. |
| **Engine pitch** | **0.72 rad (41°)** — a steeper camera compresses the depth *ahead* of the captain badly, which matters more now the design is going lane-based. You need to see down your lane. |

Painting a touch steeper than the camera is the right error to make: figures
read as grounded. The reverse — eye-level art on a steep floor — is what looks
broken. My earlier "stand down the 49° set" call was wrong; it came from a test
that varied engine pitch against one fixed bake, which could only ever favour
the bake it was holding constant.

Re-check any time: `?art=40` / `?art=49` swaps the set, `?pitch=` or the `[` `]`
keys move the camera, and `F3` shows both.

---

## The layering, outermost first

The scene is composited in this order. Each asset needs to behave in its slot.

```
  1  sky backdrop          screen-space, stretched to viewport
  2  cloud strips          screen-space, horizontal parallax
  3  distant airship       screen-space, drifts
  4  bow / prow            projected: placed at the deck's far edge, depth-scaled
  5  deck                  CODE-DRAWN projected quads + painterly grain
  6  ground layer          CODE-DRAWN: light pools, telegraph runes, decals, AoE
  7  billboards            props + crew + boarders + captain, painter-sorted
  8  x-ray pass            CODE-DRAWN rims for anything hidden behind geometry
  9  air FX                beams, chain arcs, muzzle flashes, particles
 10  envelope underside    screen-space, across the top of frame
 11  vignette + flashes    CODE-DRAWN
 12  HUD
```

Layers 5, 6, 8 and 11 are code and will be tuned to match whatever the painted
layers do — that is the point of this slice.

---

## Per-asset requirements

### 1 · `env/sky_backdrop.png` — 2048×1024, **opaque**
- Stretched to fill the entire viewport at any aspect from 16:9 to ultrawide.
  **Keep nothing load-bearing near the edges** — they get cropped or stretched.
- The **moonbreak must sit upper-left**. The whole two-source lighting model
  depends on it, and every sprite is lit assuming it is there.
- Engine already lays its own vignette over the top: **do not bake a heavy
  vignette in** or it will double and crush the corners.
- Cloud strips drift across the middle band — keep that band relatively calm so
  they read as separate depth.

### 2 · `env/envelope_top.png` — 2048×768, **transparent**
- Drawn across the top of frame at 42% of viewport height, over the world.
- **Must fade to fully transparent at its bottom edge.** Any hard edge cuts a
  visible line straight across the deck. This is the single easiest way for this
  asset to fail.
- Rigging and netting dropping toward the viewer should live in the lower third
  — that is what ties it to the deck below.
- It is the nearest thing to camera. It occludes nothing and casts no shadow the
  engine knows about; if you want it to feel like it shades the deck, that is
  already handled in code.

### 3 · `env/bow_prow.png` — 1024×640, **transparent**
- Placed at the deck's far edge and **scaled by the projection**, so it shrinks
  as the camera pulls back. Paint it flat — no vanishing point, no perspective
  convergence. The engine supplies the perspective by where it sits.
- **Bottom-centre of the canvas is the contact point** with the far deck edge.
- Navigation lanterns near the left and right thirds; the engine can add emissive
  glow at those positions, so paint the fixture, not a huge halo.

### 4 · `props/cannon_deck.png` — 640×512, **transparent**
- A billboard, base at bottom-centre, drawn ~96 world units tall.
- **It registers as an occluder in the x-ray pass**, so it needs a solid,
  readable silhouette — the engine tests coverage against its bounding box and
  will draw rims for boarders hidden behind it.
- Seen from many angles as the camera follows; keep it strongly asymmetric only
  if you accept it mirroring (§2.2).

### 5 · `props/lantern_post.png` — 384×768, **transparent**
- **This is the scene's warm light source**, and the engine already emits both
  the bloom at the flame and the pool of light on the deck beneath it, in code,
  so they respond correctly to the projection.
- **Do not paint a large glow halo into the asset** — it will double with the
  engine's and blow out. A tight bloom right at the flame is fine and welcome.
- Tall and thin, and deliberately **not** an occluder, so height is free.

---

## Two things the engine now handles for you

**Crop variance is absorbed.** The loader measures each sprite's real alpha
bounds and derives its own feet anchor, horizontal centre and figure height, so
`worldH` sizes the *figure* rather than the canvas. The first four trial assets
put their feet at 79.7 / 85.6 / 88.5 / 88.7 % of canvas height and all four sit
correctly on the deck. Aim for consistency, but it is no longer load-bearing.

**Framing is pitch-invariant.** The camera solves for its own offset so the
captain sits at a fixed 60% of screen height whatever the pitch. Changing the
angle no longer silently re-frames the fight, which is what made the first
comparison meaningless.

---

## Still missing, and it will show

`ARMORED` / Furnace Knight has no `back_idle`. It is big, slow and lingers, and
the moment it turns away it snaps to the procedural stand-in — a completely
different look. Worth adding when the character batch resumes. §4.2 currently
grants a back view only to the melee grunt.
