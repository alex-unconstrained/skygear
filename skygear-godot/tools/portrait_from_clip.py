"""Freeze one frame of the portrait plate into the HUD's captain portrait.

    python tools/portrait_from_clip.py --sheet       contact sheet of candidates
    python tools/portrait_from_clip.py --frame 71    commit that one

Board SG-228. Casting, voice and text all shipped on 2026-08-11; the art did
not. `assets/art/ui/portrait_corsair.png` is a red-haired woman in a blue coat
who matches neither the sprite, nor the model, nor the owner's ruling that the
captain is a young man — and it is the ONLY portrait in the project, which is
why the Boilerwright wears it too.

WHERE THE PIXELS COME FROM. There is no image generator on this machine (the
Aether Loom is not here, board SG-105); there is a video one. `shot_10` is a
124-frame push onto the captain's face, generated from the SAME two character
references the film's five captain shots use, so the portrait and the cinematic
cannot disagree about who he is. 124 frames at 1344x768 is 124 candidate faces
at more head-pixels than cropping the 512px sprite could ever give.

THE MASK IS A CIRCLE, AND THAT IS NOT DECORATION. `hud.gd::_draw_game_hud`
paints a dark disc, then draws this texture as a RECT inside it, then lays the
brass rim over the top — so an OPAQUE image shows its corners as a square
sitting in a round porthole. The file it replaces is a cut-out on transparency
for exactly this reason. A circular alpha, feathered at the edge, is the
shape the porthole is already built to receive.
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
CLIP = ROOT / ".shots" / "cutscene" / "take1" / "shot_10.mp4"
WORK = ROOT / ".shots" / "cutscene" / "portrait"
DST = ROOT / "assets" / "art" / "ui" / "portrait_corsair.png"
SIZE = 512                       ## what the file it replaces is, exactly


def ffmpeg() -> str:
    on_path = shutil.which("ffmpeg")
    if on_path:
        return on_path
    import imageio_ffmpeg
    return imageio_ffmpeg.get_ffmpeg_exe()


def frames() -> list[Path]:
    """Every frame of the plate, once. Cached — decoding is the slow part."""
    WORK.mkdir(parents=True, exist_ok=True)
    got = sorted(WORK.glob("f_*.png"))
    if got:
        return got
    if not CLIP.exists():
        sys.exit("no %s — run tools/cutscene_render.py --shot 10" % CLIP)
    subprocess.run([ffmpeg(), "-y", "-loglevel", "error", "-i", str(CLIP),
                    str(WORK / "f_%03d.png")], check=True)
    return sorted(WORK.glob("f_*.png"))


def sheet() -> Path:
    """A contact sheet of every 6th frame, numbered, for picking by eye."""
    picks = frames()[::6]
    cols = 6
    rows = (len(picks) + cols - 1) // cols
    tw, th = 320, 183
    out = Image.new("RGB", (cols * tw, rows * th), (12, 10, 18))
    d = ImageDraw.Draw(out)
    for i, p in enumerate(picks):
        im = Image.open(p).convert("RGB").resize((tw, th), Image.LANCZOS)
        x, y = (i % cols) * tw, (i // cols) * th
        out.paste(im, (x, y))
        ## The REAL frame number, not the index into this sheet — it is what
        ## `--frame` takes, and an off-by-six here would be invisible and wrong.
        d.text((x + 6, y + 4), str(int(p.stem.split("_")[1])), fill=(255, 220, 140))
    dst = WORK / "contact_sheet.png"
    out.save(dst)
    return dst


def commit(n: int, cx: float, cy: float, span: float) -> Path:
    """Crop a square bust around (cx, cy), mask it to a disc, save at 512."""
    src = WORK / ("f_%03d.png" % n)
    if not src.exists():
        sys.exit("no frame %d — run --sheet first" % n)
    im = Image.open(src).convert("RGB")
    half = im.height * span * 0.5
    box = (round(im.width * cx - half), round(im.height * cy - half),
           round(im.width * cx + half), round(im.height * cy + half))
    ## Clamped INSIDE the frame rather than allowed to run off it: PIL pads an
    ## out-of-bounds crop with black, and black inside the disc reads as a hole.
    dx = min(0, box[0]) + max(0, box[2] - im.width)
    dy = min(0, box[1]) + max(0, box[3] - im.height)
    box = (box[0] - dx, box[1] - dy, box[2] - dx, box[3] - dy)
    bust = im.crop(box).resize((SIZE, SIZE), Image.LANCZOS).convert("RGBA")

    ## The disc, feathered. Two pixels inside the edge so the resample cannot
    ## leave a hard ring, and blurred so the brass rim has something to sit on.
    mask = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(mask).ellipse((2, 2, SIZE - 3, SIZE - 3), fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(2.4))
    bust.putalpha(mask)

    if DST.exists():
        keep = DST.with_suffix(".png.pre-SG-228")
        if not keep.exists():
            shutil.copy2(DST, keep)
    bust.save(DST)
    return DST


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--sheet", action="store_true")
    ap.add_argument("--frame", type=int)
    ## The plate is framed head-and-shoulders already, so these rarely move —
    ## they are here because "rarely" is not "never" and a reroll is six minutes.
    ap.add_argument("--cx", type=float, default=0.5)
    ap.add_argument("--cy", type=float, default=0.46)
    ap.add_argument("--span", type=float, default=0.92,
                    help="crop height as a fraction of the frame's")
    a = ap.parse_args()
    if a.sheet:
        print(sheet())
        return
    if a.frame is None:
        sys.exit("pass --sheet to look, or --frame N to commit one")
    print(commit(a.frame, a.cx, a.cy, a.span))


if __name__ == "__main__":
    main()
