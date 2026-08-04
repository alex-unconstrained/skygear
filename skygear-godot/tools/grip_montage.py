"""Stitch a directory of grip frames into one contact sheet (SG-170).

A grip is judged by comparing poses, not by staring at one of them: the whole
question is whether a haft that sits right in a resting fist is still in that
fist at the middle of a swing. Forty PNGs opened one at a time cannot answer
that; one sheet, phases across and angles down, can.

    python tools/grip_montage.py .shots/sg170/v2 armored
    python tools/grip_montage.py .shots/sg170/v2            all subjects

Writes `<dir>/sheet-<who>.png` beside the frames.
"""
import sys
import pathlib
from PIL import Image, ImageDraw

CELL_W = 520


def sheet(folder: pathlib.Path, who: str) -> pathlib.Path | None:
    frames = sorted(p for p in folder.glob(f"{who}-*.png") if "sheet" not in p.name)
    if not frames:
        return None
    # phases across, camera angles down: the two axes the fit has to survive.
    phases = sorted({p.stem.rsplit("-", 1)[0] for p in frames})
    angles = sorted({p.stem.rsplit("-", 1)[1] for p in frames})
    probe = Image.open(frames[0])
    scale = CELL_W / probe.width
    cell_h = int(probe.height * scale)
    out = Image.new("RGB", (CELL_W * len(phases), (cell_h + 18) * len(angles)),
                    (16, 14, 20))
    draw = ImageDraw.Draw(out)
    for r, angle in enumerate(angles):
        for c, phase in enumerate(phases):
            f = folder / f"{phase}-{angle}.png"
            if not f.exists():
                continue
            out.paste(Image.open(f).convert("RGB").resize((CELL_W, cell_h)),
                      (c * CELL_W, r * (cell_h + 18) + 18))
            draw.text((c * CELL_W + 6, r * (cell_h + 18) + 4),
                      f"{phase.replace(who + '-', '')}  [{angle}]", (235, 220, 200))
    path = folder / f"sheet-{who}.png"
    out.save(path)
    return path


def main() -> None:
    folder = pathlib.Path(sys.argv[1])
    if len(sys.argv) > 2:
        subjects = [sys.argv[2].lower()]
    else:
        subjects = sorted({p.name.split("-")[0] for p in folder.glob("*.png")
                           if not p.name.startswith("sheet")})
    for who in subjects:
        made = sheet(folder, who)
        if made:
            print(made)


if __name__ == "__main__":
    main()
