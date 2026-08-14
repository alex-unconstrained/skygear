#!/usr/bin/env python3
"""Make a generated cut-out safe to draw, and measure the box it really occupies.

    python tools/cutout.py .shots/imageforge/portrait_boilerwright_1.png \
                           skygear-godot/assets/art/ui/portrait_boilerwright.png

EVERY PLATE `imageforge.py` RETURNS NEEDS THIS BEFORE IT IS LIVE ART, and neither
of the two things it does is visible to somebody looking at the file.

THE VEIL. `background="transparent"` gives a real cut-out and the histogram says
so — on a far-cloud sheet, 85% of texels sit under alpha 32 and 14% over 224,
which is a hard edge, not a haze. But 4.45% of that sheet carries alpha 1..31
with a bounding box of the WHOLE CANVAS: a film of alpha exactly 1 over every
texel, corners included. It is invisible to a human and it is not invisible to an
alpha bounding box — a plate measured with the film still on it measures the
whole canvas, which is how a figure ends up drawn somewhere other than where the
arithmetic says it is.

THE JUNK RGB. Under the transparent region the model paints whatever it likes;
measured, the four corners of `sky_clouds_far_1.png` are olive `(122,136,121,0)`.
Alpha 0 hides that from a viewer and does NOT hide it from a filtered texture
lookup: Godot's bilinear sampler mixes the four texels around a sample point
INCLUDING their colour, so every soft edge drags olive into itself and the figure
wears a dirty green fringe against the violet sky. Push the nearest real colour
outward into the transparent region instead. Alpha never moves; only hidden RGB.

THE BOX. `hud.gd` draws its poster figures through measured alpha rects —
`HERO_SRC`, `PROW_SRC`, `CLOUD_FAR_SRC` — under a comment that states the rule:
*"Every one read off the file rather than estimated, because a source rect that
guesses at the transparent margin puts the figure somewhere other than where the
arithmetic says it is."* This prints the rect to paste in, so that stays true of
anything generated from here on.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

## Alpha under this is film rather than art. See the module docstring.
VEIL = 8


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


def alpha_box(rgba: np.ndarray) -> tuple[int, int, int, int]:
    """The rect the figure actually occupies, measured after the veil is gone."""
    ys, xs = np.where(rgba[..., 3] > 0)
    if not len(ys):
        return (0, 0, rgba.shape[1], rgba.shape[0])
    return (int(xs.min()), int(ys.min()),
            int(xs.max()) - int(xs.min()) + 1,
            int(ys.max()) - int(ys.min()) + 1)


def promote(src: Path, dest: Path) -> None:
    raw = np.array(Image.open(src).convert("RGBA"))
    before = alpha_box(raw)
    out = bleed(clean(raw))
    box = alpha_box(out)
    dest.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(out, "RGBA").save(dest)
    veiled = int(((raw[..., 3] > 0) & (raw[..., 3] < VEIL)).sum())
    print("%s -> %s" % (src.name, dest))
    print("  sheet %dx%d, %d film texels dropped" % (out.shape[1], out.shape[0], veiled))
    print("  alpha box BEFORE the clean: Rect2(%d, %d, %d, %d)" % before)
    print("  alpha box AFTER  the clean: Rect2(%d, %d, %d, %d)   <- use this one" % box)
    print("  aspect %.4f (w/h)" % (box[2] / float(box[3])))


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("dest")
    a = ap.parse_args()
    promote(Path(a.src).resolve(), Path(a.dest).resolve())


if __name__ == "__main__":
    main()
