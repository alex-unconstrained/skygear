#!/usr/bin/env python3
"""Render the title poster offline, at a chosen instant of its own clock.

    python tools/poster_preview.py --t 0 12 40 --out .shots/poster
    python tools/poster_preview.py --t 0 --boxes

WHY THIS EXISTS AND WHAT IT IS NOT. The poster is about to gain three drifting
parallax layers and a second hero, and the composition questions that decides —
does the Boilerwright's head collide with the logo, does a near cloud cross the
menu board, is the depth actually legible — are questions you answer by LOOKING.
Godot cannot be launched in the session this was written in, and a capture pass
contends with the one GPU besides (the 2026-08-11 freeze). So the layout
arithmetic is written down twice: once here in Python where it can be looked at,
and once in `hud.gd` where it ships.

THAT DUPLICATION IS A LIABILITY AND IT IS DECLARED RATHER THAN HIDDEN. Two
statements of one layout is exactly STATUS.md's failure mode two. It is accepted
here for one reason — this file draws NOTHING the player ever sees — and it is
held honest from the other end: `POSTER` below is the same table `sky_layers.json`
hands the renderer, the drift is the same formula, and the harness check
`menu · the poster's depth is a rate, not a coincidence` asserts the ordering
both of them depend on. If this preview and the game disagree, the preview is
wrong by definition and this file is what gets deleted.
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
GODOT = ROOT / "skygear-godot"
ART = GODOT / "assets" / "art"
LAYERS = json.loads((ART / "env" / "sky_layers.json").read_text(encoding="utf-8"))

W, H = 1920, 1080

## THE LAYER TABLE. `secs` is how long one clump takes to cross the whole loop —
## the ONE number that has to be monotonic front-to-back, because that ordering
## IS the parallax. `height` is the tallest clump in the layer as a fraction of
## the canvas; `alt` its mean altitude, `spread` how far clumps scatter around
## it; `alpha` the layer's own weight. Nearer weather is faster, larger, lower
## and more opaque, all four at once.
## `density` stretches the loop a clump's stations are spread around: 1.0 packs
## the layer as tightly as a clean off-screen wrap allows, and anything higher
## puts more empty sky between neighbours. It is the only dial here that is about
## TASTE rather than depth — six spires evenly spread over the tightest legal
## loop put five of them on screen at once, all with the same silhouette, and a
## sky with five identical castles in it is a wallpaper, not a horizon.
POSTER = [
    dict(key="far",   secs=190.0, height=0.20, alt=0.360, spread=0.085,
         alpha=0.62, density=1.0),
    dict(key="isles", secs=132.0, height=0.27, alt=0.500, spread=0.065,
         alpha=0.76, density=2.1),
    dict(key="near",  secs=74.0,  height=0.42, alt=0.645, spread=0.090,
         alpha=0.90, density=1.4),
]

## The golden angle, as a fraction of a turn. Stepping a clump index by this and
## taking the fraction gives altitudes that are evenly spread and never repeat a
## pattern the eye can count — a low-discrepancy sequence, which is what you want
## instead of either a straight line of clouds or a random one that clumps.
PHI = 0.6180339887


def swing(t: float, period: float, phase: float) -> float:
    return math.sin(t * math.tau / period + phase * math.tau)


def cross(t: float, period: float, phase: float) -> float:
    return (t / period + phase) % 1.0


def ship_x(c: float, view_w: float, ship_w: float) -> float:
    """`SkyGearHUD.poster_ship_x`, restated. She sails right to left (SG-274)."""
    return -ship_w - 60.0 + (1.0 - c) * (view_w + ship_w * 2.0 + 120.0)


def layer_placements(spec: dict, t: float) -> list[tuple[int, float, float, float]]:
    """(clump index, x, y, scale) for every clump of one layer at time t.

    THE LOOP. A clump is placed at its own station around a virtual loop of
    `span` pixels and the whole loop slides left at a constant rate; a clump that
    leaves the left edge reappears at the right because `span` is wider than the
    canvas plus the widest clump, so the wrap always happens off-screen. There is
    no seam to heal because there is no seam: these are objects, not a band.
    """
    data = LAYERS["layers"][spec["key"]]
    boxes = data["clumps"]
    n = len(boxes)
    tallest = max(b[3] for b in boxes)
    scale = H * spec["height"] / tallest
    widest = max(b[2] for b in boxes) * scale
    span = (W + widest + 40.0) * spec.get("density", 1.0)
    out = []
    for i, b in enumerate(boxes):
        station = span * i / float(n)
        x = (station - (t / spec["secs"]) * span) % span - widest
        ## Altitude: the golden-angle sequence spreads them, and a slow bob on a
        ## period that does not divide the drift keeps the layer from reading as
        ## a rigid line of objects on a rail.
        lift = (i * PHI) % 1.0 - 0.5
        y = H * (spec["alt"] + spec["spread"] * lift) + 14.0 * swing(t, 37.0 + i * 3.0, i * PHI)
        out.append((i, x, y, scale))
    return out


def cover(dst: Image.Image, src: Image.Image, anchor: tuple[float, float]) -> None:
    """`_poster_cover`: fill the canvas, preserve aspect, crop to the anchor."""
    s = max(W / src.width, H / src.height)
    w, h = int(src.width * s), int(src.height * s)
    im = src.resize((w, h), Image.LANCZOS)
    dst.alpha_composite(im, (int((W - w) * anchor[0]), int((H - h) * anchor[1])))


def paste(dst: Image.Image, sheet: Image.Image, box, at, size, alpha: float) -> None:
    x, y, w, h = box
    cut = sheet.crop((x, y, x + w, y + h)).resize(
        (max(1, int(size[0])), max(1, int(size[1]))), Image.LANCZOS)
    if alpha < 1.0:
        a = cut.getchannel("A").point(lambda v: int(v * alpha))
        cut.putalpha(a)
    dst.alpha_composite(cut, (int(at[0]), int(at[1])))


def vignette() -> Image.Image:
    v = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(v)
    for i in range(90):
        f = i / 90.0
        d.rectangle([int(-W * 0.15 + W * 0.62 * f), int(-H * 0.15 + H * 0.62 * f),
                     int(W * 1.15 - W * 0.62 * f), int(H * 1.15 - H * 0.62 * f)],
                    outline=(6, 4, 12, 5))
    return v


def render(t: float, boxes: bool) -> Image.Image:
    canvas = Image.new("RGBA", (W, H), (8, 6, 16, 255))
    cover(canvas, Image.open(ART / "env" / "sky_backdrop.png").convert("RGBA"), (0.5, 0.34))

    sheets = {s["key"]: Image.open(GODOT / "assets" / "art" / "env" /
                                   Path(LAYERS["layers"][s["key"]]["texture"]).name
                                   ).convert("RGBA") for s in POSTER}

    def draw_layer(spec):
        data = LAYERS["layers"][spec["key"]]
        for i, x, y, sc in layer_placements(spec, t):
            b = data["clumps"][i]
            paste(canvas, sheets[spec["key"]], b, (x, y - b[3] * sc * 0.5),
                  (b[2] * sc, b[3] * sc), spec["alpha"])

    draw_layer(POSTER[0])
    draw_layer(POSTER[1])

    ## The distant airship, between the isles and the near weather.
    ship = Image.open(ART / "env" / "airship_distant.png").convert("RGBA")
    SHIP_SRC = (88, 6, 338, 143)
    sw = H * 0.070
    sh = sw * SHIP_SRC[3] / SHIP_SRC[2]
    paste(canvas, ship, SHIP_SRC,
          (ship_x(cross(t, 104.0, 0.0), W, sw), H * 0.115 + 15.0 * swing(t, 41.0, 0.7)),
          (sw, sh), 0.60)

    draw_layer(POSTER[2])

    ## The prow, on the foot line.
    prow = Image.open(ART / "env" / "bow_prow.png").convert("RGBA")
    PROW_SRC = (103, 9, 833, 600)
    board_x = W - 40.0 - (460 + 26 * 2)
    rail_y = H - 72.0
    ph = min(max(H * 0.42, 210.0), 470.0)
    pw = ph * PROW_SRC[2] / PROW_SRC[3]
    prow_at = (board_x + 120.0 - pw * 0.72, rail_y + 62.0 - ph)
    paste(canvas, prow, PROW_SRC, prow_at, (pw, ph), 1.0)

    ## THE TWO HEROES. Measured alpha boxes, both of them (tools/cutout.py).
    cap = Image.open(ART / "heroes" / "corsair_hero_pose.png").convert("RGBA")
    CAP_SRC = (68, 54, 937, 1463)
    ch = H * 0.60
    cw = ch * CAP_SRC[2] / CAP_SRC[3]
    paste(canvas, cap, CAP_SRC, (-max(28.0, cw * 0.06), H - ch + 18.0), (cw, ch), 1.0)

    bw = Image.open(ART / "heroes" / "boilerwright_front_attack.png").convert("RGBA")
    BW_SRC = (26, 51, 952, 1389)
    bh = H * 0.525
    bww = bh * BW_SRC[2] / BW_SRC[3]
    paste(canvas, bw, BW_SRC, (cw * 0.74, H - bh + 14.0), (bww, bh), 1.0)

    canvas.alpha_composite(vignette())

    if boxes:
        d = ImageDraw.Draw(canvas)
        lock_w = min(820.0, board_x - 76.0)
        lock_x = 56.0 + (board_x - 56.0 - lock_w) * 0.42
        logo_h = lock_w * 1024.0 / 1536.0
        d.rectangle([lock_x, H * 0.055, lock_x + lock_w, H * 0.055 + logo_h],
                    outline=(255, 80, 80, 255), width=3)
        d.rectangle([board_x, H * 0.22, W - 40, rail_y], outline=(80, 200, 255, 255), width=3)
        d.rectangle([-max(28.0, cw * 0.06), H - ch + 18.0,
                     -max(28.0, cw * 0.06) + cw, H + 18.0], outline=(120, 255, 120, 255), width=2)
        d.rectangle([cw * 0.74, H - bh + 14.0, cw * 0.74 + bww, H + 14.0],
                    outline=(255, 220, 80, 255), width=2)
        d.text((14, 14), "t = %.1fs   red logo / blue board / green captain / gold boilerwright" % t)

    ## The logo itself, so a collision is judged against the art rather than a box.
    logo = Image.open(ART / "ui" / "logo_skygear.png").convert("RGBA")
    lock_w = min(820.0, board_x - 76.0)
    lock_x = 56.0 + (board_x - 56.0 - lock_w) * 0.42
    logo_h = lock_w * 1024.0 / 1536.0
    canvas.alpha_composite(
        logo.resize((int(lock_w), int(logo_h)), Image.LANCZOS),
        (int(lock_x), int(H * 0.055)))
    return canvas


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--t", nargs="+", type=float, default=[0.0])
    ap.add_argument("--out", default=".shots/poster")
    ap.add_argument("--boxes", action="store_true")
    a = ap.parse_args()
    out = ROOT / a.out
    out.mkdir(parents=True, exist_ok=True)
    for t in a.t:
        im = render(t, a.boxes)
        p = out / ("poster_t%05.1f%s.png" % (t, "_boxes" if a.boxes else ""))
        im.convert("RGB").save(p, quality=92)
        print(p.relative_to(ROOT))


if __name__ == "__main__":
    main()
