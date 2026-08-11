#!/usr/bin/env python3
"""Draw the SkyGear application icon.

  python tools/make_icon.py

Writes `assets/art/ui/icon.png` (256) and `assets/art/ui/icon.ico` (16..256).
The PNG is `config/icon` in project.godot — the window and alt-tab icon. The ICO
is `application/icon` in export_presets.cfg — the taskbar, the Explorer tile and
the Properties dialog. Windows needs the ICO; Godot needs the PNG; they are the
same drawing.

WHY THIS IS A SCRIPT AND NOT A PNG SOMEBODY DREW ONCE. Board rule 2 asks where a
thing came from, and an icon checked in as thirty kilobytes of pixels answers
that with nothing. This file is the answer: every colour below is READ FROM THE
GAME, not picked to look nice next to it —

  BRASS      #b0813f   scripts/hud.gd:864
  BRASS_LIT  #e8c376   scripts/hud.gd:865
  MENU_TEAL  #37f0c8   scripts/hud.gd:200
  ink field  #0d0b12   scripts/hud.gd:942

so if the game's brass ever moves, this redraws against the new brass instead of
drifting away from it.

THE ONE CONSTRAINT THAT DECIDED THE DESIGN IS SIZE. This is a taskbar icon
before it is anything else, and the honest test is 16x16, not 256x256. That
rules out the ship: a hull, a rail and three masts are four pixels of grey mush
at tab size. What survives is one ring and one bolt — the gear the game is named
for, and the storm it is set in. Everything here is drawn at 4x and resampled,
because the teeth alias badly otherwise.
"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(HERE)
OUT_DIR = os.path.join(PROJECT, "assets", "art", "ui")

SS = 4               # supersample factor
SIZE = 256
N = SIZE * SS

BRASS = (0xb0, 0x81, 0x3f, 255)
BRASS_LIT = (0xe8, 0xc3, 0x76, 255)
TEAL = (0x37, 0xf0, 0xc8, 255)
CREAM = (0xff, 0xe6, 0xb0, 255)
INK = (0x0d, 0x0b, 0x12, 255)
INK_SOFT = (0x18, 0x13, 0x24, 255)

TEETH = 10
R_OUTER = 0.455      # tooth tip, as a fraction of the canvas
R_ROOT = 0.395       # tooth root
R_INNER = 0.320      # inner bore — the dark disc the bolt sits on
TOOTH_FRAC = 0.52    # how much of each pitch the tooth occupies


def gear_polygon(cx, cy, r_tip, r_root, teeth, tooth_frac):
    """A gear outline as one closed polygon.

    Walked in pitch order: each tooth contributes a flank up to the tip, the tip
    itself, a flank back down, and the root gap that follows it. The tips are
    given a slight taper (`0.93`) so the teeth read as cast metal rather than as
    square pegs — at 16 px that taper is the difference between a gear and a
    circle with dents.
    """
    pts = []
    pitch = 2.0 * math.pi / teeth
    half = pitch * tooth_frac * 0.5
    for i in range(teeth):
        a = i * pitch
        for ang, r in (
            (a - half, r_root),
            (a - half * 0.93, r_tip),
            (a + half * 0.93, r_tip),
            (a + half, r_root),
            (a + pitch - half, r_root),
        ):
            pts.append((cx + math.cos(ang) * r, cy + math.sin(ang) * r))
    return pts


def vertical_sheen(size, top, bottom):
    """A one-pixel-wide vertical ramp blown up to `size` — the lit-from-above
    gradient every brass plate in the game already has."""
    ramp = Image.new("RGBA", (1, size))
    for y in range(size):
        t = y / max(1, size - 1)
        ramp.putpixel((0, y), tuple(
            int(top[c] + (bottom[c] - top[c]) * t) for c in range(4)))
    return ramp.resize((size, size), Image.BILINEAR)


def draw() -> Image.Image:
    img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = N / 2.0

    # ---- the ink field -------------------------------------------------
    # A rounded square rather than a full circle: Windows sits this on a
    # light taskbar as often as a dark one, and the dark field is what keeps
    # the teal bolt legible in both.
    pad = N * 0.035
    d.rounded_rectangle([pad, pad, N - pad, N - pad],
                        radius=N * 0.20, fill=INK)
    # A soft warmer core so the plate is not flat black under the gear.
    glow = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse(
        [c - N * 0.34, c - N * 0.34, c + N * 0.34, c + N * 0.34], fill=INK_SOFT)
    glow = glow.filter(ImageFilter.GaussianBlur(N * 0.045))
    img.alpha_composite(glow)

    # ---- the gear ------------------------------------------------------
    ring = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    rd = ImageDraw.Draw(ring)
    rd.polygon(gear_polygon(c, c, N * R_OUTER, N * R_ROOT, TEETH, TOOTH_FRAC),
               fill=BRASS)
    # The bore. Punched after the teeth so the ring is one solid annulus.
    rd.ellipse([c - N * R_INNER, c - N * R_INNER,
                c + N * R_INNER, c + N * R_INNER], fill=(0, 0, 0, 0))

    lit = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    lit.paste(vertical_sheen(N, BRASS_LIT, BRASS), (0, 0))
    lit.putalpha(ring.split()[3])
    img.alpha_composite(lit)

    # An ink rim on the gear, inside and out. This is the "and ink" half of
    # the identity: every brass edge in the game is drawn against a dark line.
    rim = max(1.0, N * 0.006)
    d.line(gear_polygon(c, c, N * R_OUTER, N * R_ROOT, TEETH, TOOTH_FRAC)
           + [gear_polygon(c, c, N * R_OUTER, N * R_ROOT, TEETH, TOOTH_FRAC)[0]],
           fill=INK, width=int(rim * 1.6), joint="curve")
    d.ellipse([c - N * R_INNER, c - N * R_INNER,
               c + N * R_INNER, c + N * R_INNER],
              outline=INK, width=int(rim * 2.2))

    # ---- the bolt ------------------------------------------------------
    # Drawn from the centre outward in canvas fractions so it scales with the
    # bore rather than with the frame.
    # THESE NUMBERS WERE SET AT 16 PX, NOT AT 256. The first draft used a
    # slender bolt with a cream core inset inside it; at tab size the ink rim
    # ate both flanks and the core split what was left into two grey stripes,
    # so it read as a smudge rather than as a bolt. What fixed it was making
    # the arms thick enough to survive their own outline and dropping the
    # inset core entirely — the hot centre now comes from the halo behind the
    # shape instead of from a second polygon inside it.
    def bolt(scale):
        pts = [(0.105, -0.275), (-0.150, 0.020), (-0.010, 0.020),
               (-0.105, 0.275), (0.165, -0.045), (0.020, -0.045)]
        return [(c + x * N * scale, c + y * N * scale) for x, y in pts]

    halo = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    ImageDraw.Draw(halo).polygon(
        bolt(1.30), fill=(TEAL[0], TEAL[1], TEAL[2], 165))
    halo = halo.filter(ImageFilter.GaussianBlur(N * 0.028))
    img.alpha_composite(halo)

    p = bolt(1.0)
    # Cream first, then teal inset over it, so the bright edge is a RIM on the
    # outside of the bolt rather than a stripe down its middle. At 16 px the
    # rim survives as a lightening of the whole shape; a stripe would not.
    d.polygon(bolt(1.10), fill=CREAM)
    d.polygon(p, fill=TEAL)
    d.line(p + [p[0]], fill=INK, width=int(max(1.0, N * 0.0045)), joint="curve")

    return img.resize((SIZE, SIZE), Image.LANCZOS)


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    icon = draw()
    png = os.path.join(OUT_DIR, "icon.png")
    ico = os.path.join(OUT_DIR, "icon.ico")
    icon.save(png)
    # 16 is the one that actually matters and the one that breaks first, so it
    # is resampled from the 256 rather than generated separately.
    icon.save(ico, sizes=[(256, 256), (128, 128), (64, 64),
                          (48, 48), (32, 32), (16, 16)])
    print("wrote", png)
    print("wrote", ico)


if __name__ == "__main__":
    main()
