#!/usr/bin/env python3
"""LABELLED SIDE-BY-SIDES from a pair manifest. The owner's judging lens.

    python tools/ab_sheet.py .shots/owner-review/_raw/manifest.json \
                             .shots/owner-review/mast-bow-stern

Reads the manifest a shot tool wrote — `{tag, title, note, a, b, label_a,
label_b}` — and writes one PNG per pair: the two frames at FULL resolution,
side by side, with the labels burned into the picture and the file named after
both halves.

WHY THE LABELS ARE IN THE PIXELS. A comparison that needs a covering note to
say which half is which is a comparison that will be misread the first time it
is forwarded, and both halves of these pairs are the same deck at the same
camera — there is no way to tell them apart by eye without being told. The
brief for this work asked for exactly that: *name the files so the comparison
is obvious without opening two of them.*

FULL RESOLUTION, NOT A THUMBNAIL. The mast pair's whole content is whether the
shroud lattice survives as LINES, and the lines are two or three pixels wide.
A sheet downscaled to fit a screen answers the question by throwing away the
evidence.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]

GUTTER = 12
HEADER = 116
MIN_HALF = 780
FOOTER = 46
BG = (16, 14, 18)
INK = (238, 234, 228)
DIM = (168, 160, 152)
## Left is always the deck AS IT SHIPS; right is always the piece under
## judgement. Colour carries it too, so the pair survives being cropped.
LEFT_TINT = (150, 156, 168)
RIGHT_TINT = (226, 176, 92)

## Fallback shorts when a manifest does not carry its own. Filenames, so no
## spaces and nothing a shell would argue with.
SHORTS = {
    "THE MAST": ("shipped-procedural-casters", "owners-mast_crowned"),
    "THE BOW": ("no-bow-model", "with-bow_ram"),
    "THE STERN": ("no-stern-model", "with-stern_counter"),
}


def _font(size: int, bold: bool = False):
    for name in (("arialbd.ttf", "seguisb.ttf") if bold else ("arial.ttf",)):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default(size)


def sheet(entry: dict, out_dir: Path) -> Path:
    a = Image.open(ROOT / entry["a"]).convert("RGB")
    b = Image.open(ROOT / entry["b"]).convert("RGB")
    ## An optional crop, in the SAVED FRAME's own pixels, measured by the shot
    ## tool through `unproject_position`. Both halves are cut to the same box —
    ## a pair cropped by eye, half by half, is a pair that can differ by the
    ## crop instead of by the thing under test.
    crop = entry.get("crop")
    if crop:
        x, y, cw, ch = (int(v) for v in crop)
        ## Enough of the deck around it that the planking is still there to
        ## judge the object against.
        cw, ch = max(cw, 560), max(ch, 460)
        x = max(0, min(x, a.size[0] - cw))
        y = max(0, min(y, a.size[1] - ch))
        a = a.crop((x, y, x + cw, y + ch))
        b = b.crop((x, y, x + cw, y + ch))
        ## A crop tighter than this is a specimen the owner has to lean in at.
        ## Both halves take the SAME resample, so nothing separates them but the
        ## thing under test.
        if cw < MIN_HALF:
            k = MIN_HALF / cw
            size = (MIN_HALF, int(round(ch * k)))
            a = a.resize(size, Image.LANCZOS)
            b = b.resize(size, Image.LANCZOS)
    w, h = a.size
    if b.size != a.size:
        raise SystemExit("%s: halves differ in size %s vs %s"
                         % (entry["tag"], a.size, b.size))

    sheet_w = w * 2 + GUTTER * 3
    sheet_h = HEADER + h + FOOTER + GUTTER
    img = Image.new("RGB", (sheet_w, sheet_h), BG)
    img.paste(a, (GUTTER, HEADER))
    img.paste(b, (GUTTER * 2 + w, HEADER))

    d = ImageDraw.Draw(img)
    ## The title on its own line and the note under it, never beside it: the
    ## sheet width is set by the FRAMES, so a one-line header is a header that
    ## silently runs off the edge of the narrow (cropped) sheets — which is what
    ## the first pass did.
    d.text((GUTTER, 12), entry["title"], font=_font(36, True), fill=INK)
    d.text((GUTTER + 2, 58),
           "%s  ·  %s, zoom %.2f" % (entry.get("note", ""),
                                     entry.get("spot", "?"),
                                     float(entry.get("zoom", 1.0))),
           font=_font(21), fill=DIM)

    ## The two banners sit ON the frames' top edge, so a crop of either half
    ## still carries its own label.
    for x0, label, tint in ((GUTTER, entry["label_a"], LEFT_TINT),
                            (GUTTER * 2 + w, entry["label_b"], RIGHT_TINT)):
        d.rectangle([x0, HEADER - 34, x0 + w, HEADER - 2], fill=(28, 25, 30))
        d.rectangle([x0, HEADER - 34, x0 + 8, HEADER - 2], fill=tint)
        d.text((x0 + 20, HEADER - 30), label, font=_font(23, True), fill=tint)

    d.text((GUTTER, HEADER + h + 12), entry.get("caption", ""),
           font=_font(22), fill=DIM)

    short_a, short_b = SHORTS.get(entry["title"], ("A", "B"))
    short_a = entry.get("short_a", short_a)
    short_b = entry.get("short_b", short_b)
    out_dir.mkdir(parents=True, exist_ok=True)
    path = out_dir / ("%s__LEFT-%s__RIGHT-%s.png"
                      % (entry["tag"], short_a, short_b))
    img.save(path)
    return path


def main(argv: list[str]) -> int:
    if len(argv) < 3:
        print(__doc__)
        return 2
    manifest = json.loads(Path(argv[1]).read_text(encoding="utf-8"))
    out_dir = Path(argv[2])
    if not out_dir.is_absolute():
        out_dir = ROOT / out_dir
    for entry in manifest:
        print("  %s" % sheet(entry, out_dir).relative_to(ROOT))
    print("%d sheets -> %s" % (len(manifest), out_dir))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
