#!/usr/bin/env python3
"""Turn generated sky SHEETS into a layer of individually placeable clumps.

    python tools/skyslice.py --compose far  .shots/imageforge/sky_clouds_far_1.png ...
    python tools/skyslice.py --report

WHY THIS EXISTS. `_draw_poster` could only ever SWAY its two cloud textures,
because each of them (`env/clouds_far.png`, `env/clouds_near.png`, both 2048x512)
carries ONE painted cloud mass across the middle third of an otherwise empty
canvas — so the renderer reads a 512-672 px region out of it and rocks that
region back and forth. A band that SCROLLS has to be horizontally seamless, and
no image API guarantees that; you heal the wrap seam afterwards and hope the
repeat is not visible.

Discrete clumps have no seam to heal. A clump that walks off the left edge
re-enters at the right, so the loop is free, and the motion reads as the ship
sailing rather than as a texture sliding. This tool is what turns generated
sheets into that set of clumps, and it does three jobs, none of them optional.

1. THE VEIL. `gpt-image-1` returns a real cut-out and the measurement says so —
   85% of a far-cloud sheet sits under alpha 32 and 14% over 224, which is a hard
   edge, not a haze. But 4.45% of it carries alpha 1..31 with a bounding box of
   the ENTIRE CANVAS: a film of alpha exactly 1 over every texel, corners
   included, painted the same olive as the junk RGB. Invisible to a human, and it
   broke both of the other two jobs at once.

2. ALPHA BLEED. The RGB *under* the transparent region is whatever the model
   happened to paint there — measured, the corners of `sky_clouds_far_1.png` are
   olive `(122,136,121,0)`. Alpha 0 hides that from a human and does NOT hide it
   from a filtered texture lookup: Godot's bilinear sampler mixes the four texels
   around a sample point including their colour, so every soft cloud edge drags
   olive into itself and wears a dirty green fringe against the violet sky. Push
   the nearest real colour outward instead. Alpha never moves; only hidden RGB.

3. THE BOXES, AND WHICH TEXELS BELONG TO WHICH CLUMP. Two thresholds are needed
   and they do different jobs: clumps are SEPARATED at ALPHA_FLOOR (at VEIL the
   far sheet's five clouds merge into two, because the model painted a continuous
   haze band joining them at their bases) but they are DRAWN out to VEIL, because
   the feather between the two is most of what makes a cloud read as one.
   Growing each body box by a fixed pad is the obvious way to reconcile that and
   it is wrong: measured on `sky_clouds_far_2.png`, adjacent clumps' boxes
   already overlap by 2 px, so a 20 px pad pulled a hard-cut slice of each
   neighbour into its box — six of nine clumps came back with alpha 255 sitting
   on a box border. Instead every visible texel is assigned to the NEAREST body,
   so a clump owns its own feather and nothing of anyone else's, and the box is
   whatever that ownership turns out to span.

Sheets are composed from candidates in `.shots/imageforge/` rather than
generated here, so looking at a roll before it becomes live art stays a
deliberate step.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parent.parent
ENV = ROOT / "skygear-godot" / "assets" / "art" / "env"
INDEX = ENV / "sky_layers.json"

## The layers, back to front. The renderer keys off these names and nothing else.
LAYERS = {
    "far": dict(dest="sky_clouds_far.png",
                note="distant cloud masses, slowest, palest"),
    "isles": dict(dest="sky_isles.png",
                  note="floating rock islands, mid depth"),
    "near": dict(dest="sky_clouds_near.png",
                 note="near storm cloud, fastest, largest, most saturated"),
}

## A clump smaller than this fraction of its source sheet is a stray wisp the
## model left behind, not a cloud. A fraction rather than a pixel count, so the
## threshold means the same thing if a sheet is ever generated at another size.
MIN_AREA_FRAC = 0.0015
## Under this is film, not art. See §1 above.
VEIL = 8
## Bodies are separated here. Swept across all six rolls: at 24 the far sheet's
## five clouds merge into two; from 64 up every sheet returns exactly the count
## its prompt asked for (far 5, isles 3, near 3) and holds it to 192. 96 sits in
## the middle of that plateau rather than on the edge of one.
ALPHA_FLOOR = 96
## The gap left between clumps on a composed sheet.
GAP = 24


def clean(rgba: np.ndarray) -> np.ndarray:
    """Drop the sub-visible film. Returns a copy; only alpha moves."""
    out = rgba.copy()
    out[..., 3] = np.where(out[..., 3] < VEIL, 0, out[..., 3])
    return out


def bleed(rgba: np.ndarray) -> np.ndarray:
    """Push real colour outward into the transparent region. Alpha untouched.

    One distance transform gives, for every texel, the index of the nearest texel
    that HAS presence — so it replaces the whole iterative dilate, exactly, and
    there is no round count to tune wrong.
    """
    out = rgba.copy()
    solid = out[..., 3] > 0
    if solid.all() or not solid.any():
        return out
    _, (iy, ix) = ndimage.distance_transform_edt(~solid, return_indices=True)
    out[..., :3] = out[iy, ix, :3]
    return out


def clumps_of(path: Path) -> tuple[list[np.ndarray], int]:
    """Every clean clump on a sheet, each as its own tight masked RGBA array.

    A CLUMP THAT TOUCHES THE SHEET EDGE IS REFUSED, and this is not fussiness.
    Every clump here is going to DRIFT: it walks off one side of the screen and
    re-enters at the other. A cloud the generator ran off the edge of its canvas
    ends in a dead straight vertical cut, and a straight-edged cloud sailing into
    frame is the one thing on this poster that could not possibly be weather.
    Measured: both near-cloud rolls put two of their three clouds against an
    edge, which is why that layer is composed from several rolls rather than one.
    """
    rgba = clean(np.array(Image.open(path).convert("RGBA")))
    alpha = rgba[..., 3]
    height, width = alpha.shape

    body = alpha > ALPHA_FLOOR
    labels, count = ndimage.label(body)
    if count == 0:
        return [], 0

    ## OWNERSHIP. Every visible texel is assigned to the nearest BODY, so a clump
    ## carries its own feather and none of its neighbour's. The distance
    ## transform of the body's inverse hands back, per texel, the coordinates of
    ## the nearest body texel — read the label there and that is the owner.
    _, (iy, ix) = ndimage.distance_transform_edt(~body, return_indices=True)
    owner = np.where(body, labels, labels[iy, ix])
    owner = np.where(alpha > 0, owner, 0)

    min_area = MIN_AREA_FRAC * alpha.size
    cuts: list[tuple[int, np.ndarray]] = []
    refused = 0
    for k in range(1, count + 1):
        if int((labels == k).sum()) < min_area:
            continue
        mask = owner == k
        ys, xs = np.where(mask)
        x0, x1 = int(xs.min()), int(xs.max()) + 1
        y0, y1 = int(ys.min()), int(ys.max()) + 1
        ## The BODY is what decides "ran off the canvas" — a feather reaching the
        ## edge is a wisp fading out, which is fine; a body reaching it is a cut.
        bys, bxs = np.where(labels == k)
        if int(bxs.min()) <= 1 or int(bxs.max()) >= width - 2:
            refused += 1
            continue
        if int(bys.min()) <= 1 or int(bys.max()) >= height - 2:
            refused += 1
            continue
        cut = rgba[y0:y1, x0:x1].copy()
        ## Anything in this box that belongs to somebody else is erased, which is
        ## what makes overlapping boxes harmless.
        cut[..., 3] = np.where(mask[y0:y1, x0:x1], cut[..., 3], 0)
        cuts.append((x0, cut))
    cuts.sort(key=lambda c: c[0])
    return [c for _x, c in cuts], refused


def compose(sources: list[Path], layer: str) -> None:
    """Lay the clean clumps of several sheets onto one layer sheet.

    WHY A LAYER IS ALLOWED MORE THAN ONE PARENT. The near-cloud prompt asked for
    three separated clouds and got three, twice — but a close storm cloud is
    large, and both rolls ran two of the three off the canvas, leaving ONE usable
    clump per roll. One cloud is not a layer: it is the same silhouette returning
    every loop, and the near layer travels fastest, so it would return soonest.
    Taking the clean clump from each roll — and from the painted sheet this
    project already owns, which is in the same hand because it came from the same
    brief — buys a layer with real variety out of art already paid for.
    """
    if layer not in LAYERS:
        raise SystemExit("no such layer: %s (have %s)" % (layer, ", ".join(LAYERS)))
    picked: list[tuple[np.ndarray, str]] = []
    for src in sources:
        cuts, refused = clumps_of(src.resolve())
        picked += [(c, src.name) for c in cuts]
        print("  %-26s %d clump(s)%s" % (
            src.name, len(cuts),
            ", %d refused for running off the canvas" % refused if refused else ""))
    if not picked:
        raise SystemExit("no clean clumps in %s" % ", ".join(s.name for s in sources))

    ## Exactly as wide as the clumps laid side by side and as tall as the tallest.
    ## No guessed canvas, no wasted texture memory.
    out_w = sum(c.shape[1] for c, _ in picked) + GAP * (len(picked) + 1)
    out_h = max(c.shape[0] for c, _ in picked) + GAP * 2
    out = np.zeros((out_h, out_w, 4), np.uint8)

    boxes: list[list[int]] = []
    x = GAP
    for cut, name in picked:
        h, w = cut.shape[:2]
        ## Vertically centred on the new sheet. A clump's height WITHIN its source
        ## is not meaningful here — the renderer places each clump at its own
        ## authored altitude, so carrying the source framing across would only
        ## bake one roll's composition into another's.
        y = (out_h - h) // 2
        out[y:y + h, x:x + w] = cut
        boxes.append([x, y, w, h])
        print("    %-26s %4dx%-4d -> x %4d y %4d" % (name, w, h, x, y))
        x += w + GAP

    ## Bleed the COMPOSED sheet. Each clump arrived carrying its parent's bleed
    ## only within its own cut; the fresh gaps between clumps are zeroed RGBA, so
    ## without this the texels just outside a clump would be pure black and a
    ## filtered lookup would drag black into its wisps — the same defect as the
    ## olive, one shade politer.
    _write(layer, bleed(out), boxes, " + ".join(sorted({n for _c, n in picked})))


def _write(layer: str, sheet: np.ndarray, boxes: list[list[int]], parents: str) -> None:
    dest = ENV / LAYERS[layer]["dest"]
    Image.fromarray(sheet, "RGBA").save(dest)
    index = json.loads(INDEX.read_text(encoding="utf-8")) if INDEX.exists() else {}
    index["_"] = "written by tools/skyslice.py — do not hand-edit"
    index.setdefault("layers", {})
    index["layers"][layer] = {
        "texture": "res://assets/art/env/" + LAYERS[layer]["dest"],
        "sheet": [int(sheet.shape[1]), int(sheet.shape[0])],
        "note": LAYERS[layer]["note"],
        "from": parents,
        "clumps": boxes,
    }
    INDEX.write_text(json.dumps(index, indent=1) + "\n", encoding="utf-8")
    print("%s <- %s" % (dest.relative_to(ROOT), parents))
    print("  %d clumps, %dx%d sheet" % (len(boxes), sheet.shape[1], sheet.shape[0]))


def report() -> None:
    if not INDEX.exists():
        print("no %s yet" % INDEX.relative_to(ROOT))
        return
    index = json.loads(INDEX.read_text(encoding="utf-8"))
    for name, spec in index.get("layers", {}).items():
        on = (ROOT / "skygear-godot" /
              spec["texture"].replace("res://", "")).exists()
        print("%-6s %-46s %2d clumps  %s" % (
            name, spec["texture"], len(spec["clumps"]),
            "ON DISK" if on else "MISSING"))


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--compose", nargs="+", metavar="LAYER SHEET...")
    ap.add_argument("--report", action="store_true")
    a = ap.parse_args()
    if a.compose:
        compose([Path(p) for p in a.compose[1:]], a.compose[0])
    else:
        report()


if __name__ == "__main__":
    main()
