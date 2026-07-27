#!/usr/bin/env python3
"""Validate animation strips before they are wired in.

Three things go wrong with generated cycles and only one of them is visible in
a contact sheet:

  1. frame count does not divide the canvas    -- obvious, caught immediately
  2. frames are not all the same size          -- caught by 1
  3. the figure drifts between frames          -- INVISIBLE at rest, and reads
                                                  as feet sliding on the deck

(3) is the reason this exists. The engine measures a strip once and applies that
anchor to every frame; it cannot correct per-frame drift.

  python src/check-animations.py
  python src/check-animations.py assets/animations/hero_attack.png
"""
from __future__ import annotations

import glob
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ANIM = ROOT / "assets" / "animations"
ALPHA = 40          # same threshold the engine's measureSprite uses
DRIFT_X = 0.02      # horizontal: the sprite must not translate inside its frame
# Vertical tolerance depends on the cycle. A run has a flight phase where both
# feet leave the ground, so its lowest point genuinely rises and falls — that
# bob is meant to be baked in, and the renderer zeroes its own bob when a run
# frame is showing. An idle or an attack has a planted foot and should not move.
DRIFT_Y = {"run": 0.12, "idle": 0.03, "attack": 0.05}
DRIFT_Y_DEFAULT = 0.05


def bounds(im: Image.Image):
    """Where the figure sits, as fractions of the frame.

    Horizontal position is measured from the BASE of the figure — its lowest
    quarter — not the whole silhouette. A run cycle swings its arms and leans,
    which moves the silhouette's centre several percent without the body going
    anywhere; the feet are what must stay planted, and using the full bounding
    box flags every honest run cycle as drifting.
    """
    a = im.getchannel("A") if im.mode == "RGBA" else None
    if a is None:
        return None
    mask = a.point(lambda v: 255 if v > ALPHA else 0)
    bb = mask.getbbox()
    if not bb:
        return None
    w, h = im.size
    x0, y0, x1, y1 = bb
    base_top = max(y0, int(y1 - (y1 - y0) * 0.25))
    base = mask.crop((0, base_top, w, y1)).getbbox()
    bx = ((base[0] + base[2]) / 2.0 / w) if base else ((x0 + x1) / 2.0 / w)
    return (bx, y1 / float(h), (x1 - x0) / float(w), (y1 - y0) / float(h))


def check_strip(path: Path) -> bool:
    im = Image.open(path).convert("RGBA")
    W, H = im.size
    if W % H != 0:
        print("FAIL %-28s %dx%d — width is not a whole number of %dpx frames"
              % (path.name, W, H, H))
        return False
    n = W // H
    cx, feet, fw, fh = [], [], [], []
    empty = []
    for i in range(n):
        f = im.crop((i * H, 0, (i + 1) * H, H))
        b = bounds(f)
        if b is None:
            empty.append(i)
            continue
        cx.append(b[0]); feet.append(b[1]); fw.append(b[2]); fh.append(b[3])
    if not cx:
        print("FAIL %-28s every frame is empty" % path.name)
        return False

    state = next((k for k in DRIFT_Y if k in path.stem), None)
    tol_y = DRIFT_Y.get(state, DRIFT_Y_DEFAULT)
    # Oscillation is not drift. A run alternates its feet, so the base swings
    # left and right every cycle and that is the animation working. What breaks
    # is NET displacement: a cycle that ends somewhere other than it started
    # never returns, and the character slides across the deck a little further
    # every loop. Compare the start of the cycle against the end.
    k = max(1, len(cx) // 4)
    mean = lambda a: sum(a) / len(a)
    dx = abs(mean(cx[:k]) - mean(cx[-k:]))
    swing = max(cx) - min(cx)
    dy = max(feet) - min(feet)
    ok = not empty and dx <= DRIFT_X and dy <= tol_y
    flags = []
    if empty:
        flags.append("EMPTY frames " + ",".join(str(e) for e in empty))
    if dx > DRIFT_X:
        flags.append("net drift %.1f%% across the cycle — it does not return "
                     "to where it started, so it slides" % (dx * 100))
    if dy > tol_y:
        flags.append("feet move %.1f%% vertically (%s tolerance %.0f%%)"
                     % (dy * 100, state or "default", tol_y * 100))
    print("%s %-28s %2d frames @%d  figure %.0f%% tall  swing %.1f%%  %s" % (
        "OK  " if ok else "WARN", path.name, n, H,
        (sum(fh) / len(fh)) * 100, swing * 100, "; ".join(flags)))
    return ok


def main():
    args = sys.argv[1:]
    paths = [Path(a) for a in args] if args else sorted(
        Path(p) for p in glob.glob(str(ANIM / "*.png")))
    if not paths:
        print("no strips in %s (loose per-frame folders are not checked here)" % ANIM)
        return 0
    results = [check_strip(p) for p in paths]   # not all(): must check every strip
    good = all(results)
    print("PASS" if good else "WARN — see above")
    return 0 if good else 1


if __name__ == "__main__":
    raise SystemExit(main())
