#!/usr/bin/env python3
"""Bridge Aether Loom output into the game repo.

The Loom (a separate local tool) forges stills and animation loops. Nothing
connected its output to this repository, so every asset so far was moved by
hand. This does it, correctly and repeatably:

  * animation — loop/frames/*.png  ->  assets/animations/<name>.png strip
  * still     — a forged candidate ->  assets/<path>.png at manifest dimensions

Both paths key the chroma background to transparency, resize to the size the
engine actually asks for, and then run the existing validators, so a bad asset
is rejected here rather than discovered in the game.

  python src/loom-ingest.py list
  python src/loom-ingest.py anim ae1807fe020c hero_run
  python src/loom-ingest.py anim <job> colossus_attack --size 512
  python src/loom-ingest.py still <file.png> hero_front_attack
  python src/loom-ingest.py still <file.png> hero_front_attack --chroma "#00FF00"
"""
from __future__ import annotations

import argparse
import glob
import io
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
LOOM = Path(r"C:/Users/alexr/Documents/Codex/2026-07-26/done-66-images-fully-specced-for")
STUDIO = LOOM / "output" / "studio_jobs"
FORGE = LOOM / "output" / "forge_jobs"
MANIFEST = ROOT / "src" / "storm-dusk" / "_render_assets.js"

# A source PNG's chroma field is far flatter than generative video's, so it can
# be keyed much more tightly than the video path's 45/105. These are for stills.
STILL_TRANSPARENT = 26.0
STILL_OPAQUE = 78.0


def manifest_targets() -> dict[str, tuple[str, int, int]]:
    """key -> (relative path, w, h) from ASSET_MANIFEST."""
    src = MANIFEST.read_text(encoding="utf-8")
    out = {}
    for key, path, w, h in re.findall(
        r"(\w+):\s*\{\s*file:'assets/([^']+)'\s*,\s*w:\s*(\d+)\s*,\s*h:\s*(\d+)", src
    ):
        out[key] = (path, int(w), int(h))
    return out


def key_chroma(im: Image.Image, chroma: str) -> Image.Image:
    """Replace a flat chroma field with alpha, with a soft edge ramp."""
    chroma = chroma.lstrip("#")
    kr, kg, kb = (int(chroma[i:i + 2], 16) for i in (0, 2, 4))
    im = im.convert("RGBA")
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            d = ((r - kr) ** 2 + (g - kg) ** 2 + (b - kb) ** 2) ** 0.5
            if d <= STILL_TRANSPARENT:
                px[x, y] = (r, g, b, 0)
            elif d < STILL_OPAQUE:
                ramp = (d - STILL_TRANSPARENT) / (STILL_OPAQUE - STILL_TRANSPARENT)
                px[x, y] = (r, g, b, int(a * ramp))
    return im


def already_keyed(im: Image.Image) -> bool:
    """True if the image already carries real transparency."""
    if im.mode != "RGBA":
        return False
    lo, hi = im.getchannel("A").getextrema()
    return lo < 8


def cmd_list(_: argparse.Namespace) -> int:
    print("ANIMATION JOBS  (output/studio_jobs)")
    rows = []
    for d in sorted(STUDIO.glob("*/"), key=lambda p: p.stat().st_mtime, reverse=True):
        frames = sorted((d / "loop" / "frames").glob("*.png"))
        if not frames:
            continue
        man = d / "loop" / "loop_manifest.json"
        meta = json.loads(man.read_text()) if man.exists() else {}
        rows.append((d.name, len(frames), meta.get("output_fps", "?"),
                     round(meta.get("loop_match_score", 0), 4)))
    if not rows:
        print("  none with a finished loop")
    for name, n, fps, score in rows:
        # lower match score = the loop boundary poses agree more closely
        print("  %-14s %2d frames  %sfps  loop-match %.4f%s"
              % (name, n, fps, score, "  <-- weak" if score > 0.05 else ""))

    print("\nFORGE JOBS  (output/forge_jobs)")
    cands = sorted(FORGE.glob("*/*.png"), key=lambda p: p.stat().st_mtime, reverse=True)
    if not cands:
        print("  none")
    for p in cands[:20]:
        im = Image.open(p)
        print("  %-14s %-18s %s  %s" % (p.parent.name, p.name, im.size,
                                        "keyed" if already_keyed(im) else "on chroma"))
    return 0


def cmd_anim(a: argparse.Namespace) -> int:
    job = STUDIO / a.job
    frames = sorted((job / "loop" / "frames").glob("*.png"))
    if not frames:
        print("no loop frames in %s — has the job finished?" % job)
        return 1
    size = a.size
    strip = Image.new("RGBA", (size * len(frames), size), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        im = Image.open(f).convert("RGBA")
        if not already_keyed(im):
            im = key_chroma(im, a.chroma)
        if im.size != (size, size):
            im = im.resize((size, size), Image.LANCZOS)
        strip.paste(im, (i * size, 0))
    out = ROOT / "assets" / "animations" / (a.name + ".png")
    out.parent.mkdir(parents=True, exist_ok=True)
    strip.save(out, optimize=True)
    print("wrote %s — %d frames @%d, %.0f KB"
          % (out.relative_to(ROOT), len(frames), size, out.stat().st_size / 1024))
    return subprocess.call([sys.executable, str(ROOT / "src" / "check-animations.py"), str(out)])


def cmd_still(a: argparse.Namespace) -> int:
    targets = manifest_targets()
    if a.key not in targets:
        print("'%s' is not in ASSET_MANIFEST. Known keys containing that text:" % a.key)
        for k in sorted(targets):
            if a.key.lower() in k.lower():
                print("   %-22s -> assets/%s  %dx%d" % (k, *targets[k]))
        return 1
    rel, w, h = targets[a.key]
    src = Path(a.source)
    if not src.exists():
        print("no such file: %s" % src)
        return 1

    im = Image.open(src).convert("RGBA")
    if not already_keyed(im):
        print("keying %s against %s ..." % (src.name, a.chroma))
        im = key_chroma(im, a.chroma)
    else:
        print("%s already has alpha; not re-keying" % src.name)

    bb = im.getchannel("A").point(lambda v: 255 if v > 40 else 0).getbbox()
    if not bb:
        print("REFUSED: the keyed image is entirely transparent. Wrong chroma colour?")
        return 1
    # keep the subject's own proportions; fit inside the target box, centred
    sub = im.crop(bb)
    scale = min(w / sub.width, h / sub.height) * a.fill
    new = (max(1, int(sub.width * scale)), max(1, int(sub.height * scale)))
    sub = sub.resize(new, Image.LANCZOS)
    canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    canvas.paste(sub, ((w - new[0]) // 2, int((h - new[1]) * a.anchor)), sub)

    out = ROOT / "assets" / rel
    out.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(out, optimize=True)
    print("wrote %s  %dx%d  %.0f KB" % (out.relative_to(ROOT), w, h, out.stat().st_size / 1024))
    keep = ROOT / "assets" / "_masters" / (Path(rel).stem + "_master.png")
    keep.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, keep)
    print("master kept at %s" % keep.relative_to(ROOT))
    return subprocess.call([sys.executable, str(ROOT / "src" / "optimize-assets.py"), "--check"])


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)

    sub.add_parser("list", help="show Loom jobs ready to ingest").set_defaults(fn=cmd_list)

    pa = sub.add_parser("anim", help="loop frames -> animation strip")
    pa.add_argument("job")
    pa.add_argument("name", help="e.g. hero_attack — becomes assets/animations/<name>.png")
    pa.add_argument("--size", type=int, default=384, help="frame size (512 for the Colossus)")
    pa.add_argument("--chroma", default="#FF00FF")
    pa.set_defaults(fn=cmd_anim)

    ps = sub.add_parser("still", help="a forged PNG -> a manifest asset")
    ps.add_argument("source", help="path to the candidate PNG")
    ps.add_argument("key", help="ASSET_MANIFEST key, e.g. hero_front_attack")
    ps.add_argument("--chroma", default="#00FF00", help="the plate colour that was used")
    ps.add_argument("--fill", type=float, default=0.88,
                    help="fraction of the target box the figure fills")
    ps.add_argument("--anchor", type=float, default=0.92,
                    help="0 = top, 1 = bottom; characters sit near the bottom")
    ps.set_defaults(fn=cmd_still)

    a = ap.parse_args()
    return a.fn(a)


if __name__ == "__main__":
    raise SystemExit(main())
