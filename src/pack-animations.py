#!/usr/bin/env python3
"""Pack loose animation frames into a single horizontal strip.

Loose per-frame PNGs cost more than they look: 28 frames of the two existing
cycles are 3.9 MB, which is more than every still asset in the game combined.
One PNG per cycle shares a compression dictionary across all frames and comes
in 33-35% smaller, in one request instead of thirteen.

  python src/pack-animations.py                     # every loose folder
  python src/pack-animations.py hero_front_run      # one
  python src/pack-animations.py --size 512 colossus_attack
"""
from __future__ import annotations

import argparse
import glob
import os
import re
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ANIM = ROOT / "assets" / "animations"


def pack(folder: Path, size: int, keep: bool) -> None:
    frames = sorted(glob.glob(str(folder / "*.png")))
    if not frames:
        print("skip  %-24s no frames" % folder.name)
        return
    ims = [Image.open(f).convert("RGBA") for f in frames]
    strip = Image.new("RGBA", (size * len(ims), size), (0, 0, 0, 0))
    for i, im in enumerate(ims):
        if im.size != (size, size):
            im = im.resize((size, size), Image.LANCZOS)
        strip.paste(im, (i * size, 0))
    # `_front` is redundant in a strip name: back views stay still-only
    out = ANIM / (re.sub(r"_front(?=_|$)", "", folder.name) + ".png")
    strip.save(out, optimize=True)
    loose = sum(os.path.getsize(f) for f in frames)
    new = os.path.getsize(out)
    print("OK    %-24s %2d frames  %5.0f KB -> %5.0f KB  (%.0f%% smaller)  %s" % (
        folder.name, len(ims), loose / 1024, new / 1024,
        100 * (1 - new / loose), out.name))
    if not keep:
        for f in frames:
            os.remove(f)
        try:
            folder.rmdir()
        except OSError:
            pass


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("names", nargs="*")
    ap.add_argument("--size", type=int, default=384,
                    help="frame size; the brief says 384, 512 for the Colossus")
    ap.add_argument("--keep", action="store_true", help="do not delete the loose frames")
    a = ap.parse_args()
    folders = ([ANIM / n for n in a.names] if a.names
               else sorted(p for p in ANIM.iterdir() if p.is_dir()))
    if not folders:
        print("no loose frame folders in %s" % ANIM)
        return
    for f in folders:
        pack(f, a.size, a.keep)


if __name__ == "__main__":
    main()
