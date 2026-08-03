#!/usr/bin/env python3
"""AUTHOR THE FURNACE KNIGHT'S EMISSION MAP OUT OF HIS OWN ALBEDO (board SG-131).

    python tests/grille_map.py            # write assets/models/armored/armored_emission.png
    python tests/grille_map.py --dry-run  # report only, touch nothing
    python tests/grille_map.py --gain 0.5 # a different brightness

IT IS IN `tests/` AND NOT IN `tools/` for the same reason `tests/lit_probe.gd`
is: `tools/` was held by another agent on the night this was written, and a
second writer in one directory is how work gets lost. It belongs beside
`tools/ingest_model.gd`, whose job it is arguably doing.


WHY AN EMISSION MAP HAS TO BE AUTHORED AT ALL

`assets/models/armored/armored_emission.png` shipped from Meshy effectively
empty: it peaks at 51/255 and only 0.146% of its texels clear 8. There is no
furnace in it. That, and not a saturated tonemapper, is why SG-86 found
`emission_energy` 6 -> 18 -> 40 moving nothing — `ingest_model.gd` sets
`emission = Color.BLACK` with the ADD operator, so the shader computes
`texture * energy` and any multiple of nothing is nothing.

The alternative to authoring one is another Meshy generation, which costs
credits and has already rejected this character twice (board SG-22).


HOW THE GRILLE IS FOUND, AND WHY IT IS NOT A BLIND COLOUR THRESHOLD

The albedo knows where the furnace is — it is painted into the sheet as
near-saturated molten orange. But a bare hot-orange threshold over a 1024 sheet
of rusted brass returns 10578 texels scattered across every rivet and trim edge
on the model, and lighting those would make the knight sparkle with orange
freckles. A threshold alone is not enough.

So the mask is SEEDED rather than thresholded. The shipped emission map is
almost empty, but the specks that ARE in it are not random: 1164 of its 1532
lit texels fall inside the albedo's hot-orange core below, against the 0.9% of
the sheet that core covers. Meshy marked the emitters, it just marked them at a
twentieth of the brightness they needed. So:

  1. threshold the albedo for hot orange -> 2378 connected components,
  2. keep ONLY the components that contain at least one shipped emission speck.

That leaves 12 components, 3977 texels, 0.38% of the sheet. Eight of them are
large enough to matter and ALL EIGHT WERE CROPPED OUT OF THE ALBEDO AND LOOKED
AT BY EYE before this script was allowed to write anything: every one is a
molten slit in dark metal — the chest furnace's slats and the visor's, split
across UV islands. None is trim, none is rust. The two sources agree, and
neither on its own would have been trustworthy.

The core is then grown a few texels into merely-warm neighbours (hysteresis, so
the grown region cannot jump an island boundary) and blurred, because the
painting's furnace has a soft glowing edge rather than a stencil's.


THE BRIGHTNESS IS THE TUNED PART

`ingest_model.gd` bakes `emission_energy` into `armored_mesh.res` at ingest, and
re-ingesting means running `tools/`. It does not need to: the map itself is a
continuous dial, and 6.0 is already in the manifest. GAIN below is that dial and
it was set by measurement, not by eye — `tests/lit_probe.gd` reports the
boarders' molten fraction against the sprite sheets' own, and the ceiling
matters more than the floor. See the SG-131 row.
"""

import argparse
import pathlib
import sys

import numpy as np
from PIL import Image
from scipy import ndimage as nd

ROOT = pathlib.Path(__file__).resolve().parent.parent
ALBEDO = ROOT / "assets/models/armored/armored_albedo.png"
EMISSION = ROOT / "assets/models/armored/armored_emission.png"

# The shipped map's lit texels, used as seeds. 8/255 is the threshold SG-131
# measured "effectively empty" with, so the seed set is exactly the 0.146%.
SEED_LEVEL = 8

# Hot orange in the albedo: the core the seeds have to land in.
CORE_S, CORE_V, CORE_HUE = 0.60, 0.62, 0.15
# And the looser warm window the core is allowed to grow into.
WARM_S, WARM_V, WARM_HUE = 0.45, 0.42, 0.19
GROW = 4
BLUR = 1.2

# Peak texel of the written map, 0..1. Times sRGB decode times the manifest's
# `emission_energy` 6.0 this is what the shader adds.
GAIN = 0.52


def _hsv(rgb):
    mx = rgb.max(axis=2)
    mn = rgb.min(axis=2)
    d = mx - mn + 1e-9
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    h = np.where(mx == r, ((g - b) / d) % 6,
                 np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) / 6.0
    s = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0.0)
    return np.minimum(np.abs(h), np.abs(1.0 - h)), s, mx


def build(gain, seed_from):
    albedo = np.asarray(Image.open(ALBEDO).convert("RGB")).astype(np.float32) / 255.0
    shipped = np.asarray(Image.open(seed_from).convert("RGB")).astype(np.float32)
    # THE SEEDS MUST BE MESHY'S, NOT THIS SCRIPT'S OWN OUTPUT. The default seed
    # file is the file this writes, so a second run would seed itself — stable
    # in practice, but it would quietly turn a two-source agreement into one
    # source. The shipped map peaks at 51/255 and an authored one peaks far
    # above; anything bright here is this script's output coming back round.
    # `git show <rev>:assets/models/armored/armored_emission.png` recovers it.
    if shipped.max() > 60.0:
        raise SystemExit(
            f"{seed_from} peaks at {int(shipped.max())}/255 — that is an authored map,"
            " not Meshy's. Pass --seed-from with the original (it is in git history).")
    seed = shipped.max(axis=2) > SEED_LEVEL

    hue, sat, val = _hsv(albedo)
    core = (sat >= CORE_S) & (val >= CORE_V) & (hue <= CORE_HUE)
    warm = (sat >= WARM_S) & (val >= WARM_V) & (hue <= WARM_HUE)

    labels, n = nd.label(core, structure=np.ones((3, 3)))
    kept_ids = sorted(set(np.unique(labels[seed & (labels > 0)])) - {0})
    kept = np.isin(labels, kept_ids)

    grown = nd.binary_dilation(kept, np.ones((3, 3)), iterations=GROW, mask=warm)
    alpha = nd.gaussian_filter(grown.astype(np.float32), BLUR)
    # The blur is allowed to soften the edge, not to leak past the warm region.
    alpha = np.clip(alpha, 0.0, 1.0) * grown

    # THE COLOUR IS THE ALBEDO'S OWN, normalised to full brightness so the map
    # carries the furnace's hue rather than a hue invented here. A texel that is
    # (0.98, 0.42, 0.09) in the sheet stays that ratio and is scaled to peak.
    peak = np.maximum(albedo.max(axis=2), 1e-6)[..., None]
    out = albedo / peak * alpha[..., None] * gain
    return np.clip(out, 0.0, 1.0), {
        "components": n,
        "seeds": int(seed.sum()),
        "seeds_in_core": int((seed & core).sum()),
        "kept_components": len(kept_ids),
        "core_texels": int(kept.sum()),
        "lit_texels": int((alpha > 0.02).sum()),
        "lit_pct": 100.0 * float((alpha > 0.02).mean()),
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--gain", type=float, default=GAIN)
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--out", default=str(EMISSION))
    ap.add_argument("--seed-from", default=str(EMISSION),
                    help="Meshy's original emission map; the default is the file this"
                         " overwrites, which only works on a clean tree")
    args = ap.parse_args()

    rgb, stats = build(args.gain, args.seed_from)
    for k, v in stats.items():
        print(f"  {k:18} {v}")
    print(f"  {'gain':18} {args.gain}")
    print(f"  {'peak texel':18} {int(rgb.max() * 255)}/255")

    if stats["kept_components"] == 0 or stats["core_texels"] < 500:
        print("REFUSING TO WRITE: the seed/threshold agreement collapsed —"
              " the albedo or the shipped map is not the one this was written for.")
        return 2
    if args.dry_run:
        print("  dry run, nothing written")
        return 0
    Image.fromarray((rgb * 255.0 + 0.5).astype(np.uint8)).save(args.out)
    print(f"  wrote {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
