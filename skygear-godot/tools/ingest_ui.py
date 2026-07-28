#!/usr/bin/env python3
"""Bring forged HUD furniture into the Godot port.

`tools/forge.py` in the repo root drives the Loom and then hands results to
`src/loom-ingest.py`, which places them by looking the key up in the BROWSER
build's asset manifest. These nine pieces are port-side HUD furniture — the
browser draws its panels with its own code and has no slot for them — so
registering them there would mean the browser downloading nine images it never
draws, purely so this build could have them.

So this is the same two steps, aimed at `assets/art/ui/` instead: key the chroma
field to transparency with a soft edge ramp, then fit to the size the HUD
actually asks for. The prompts and the candidate choices still live in
`tools/forge.py` and `tools/forge-state.json`, so the decisions are still in one
place and still in version control.

  python tools/ingest_ui.py            # every piece that has a finished job
  python tools/ingest_ui.py --force    # re-fetch ones already on disk
"""
from __future__ import annotations

import argparse
import json
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent
LOOM = "http://127.0.0.1:8765"
STATE = REPO / "tools" / "forge-state.json"
OUT = ROOT / "assets" / "art" / "ui"

# Same ramp as `src/loom-ingest.py`: a hard cut at the flat field, a soft edge
# so a riveted brass corner does not come out with a green fringe on it.
TRANSPARENT = 60.0
OPAQUE = 150.0

# forge key -> (file we write, longest edge, whether to trim to content)
#
# Trimming matters for the plates: the Loom centres the subject with a margin,
# and a nine-slice against a margin puts the frame in the wrong place. It must
# NOT happen to the two fill bands, which are authored edge to edge on purpose.
PIECES = {
    "ui_plate_wide": ("plate_wide.png", 512, True),
    "ui_plate_slot": ("plate_slot.png", 256, True),
    "ui_bar_housing": ("bar_housing.png", 512, True),
    "ui_bar_fill_hot": ("bar_fill_hot.png", 256, False),
    "ui_bar_fill_cold": ("bar_fill_cold.png", 256, False),
    "ui_pressure_dial": ("pressure_dial.png", 256, True),
    "ui_cooldown_sweep": ("cooldown_sweep.png", 256, True),
    "ui_dash_pip": ("dash_pip.png", 64, True),
    "ui_lane_track": ("lane_track.png", 256, True),
}


def job(job_id: str) -> dict:
    with urllib.request.urlopen("%s/api/forge-jobs/%s" % (LOOM, job_id), timeout=20) as r:
        return json.load(r)


def key_chroma(image, chroma: str):
    chroma = chroma.lstrip("#")
    kr, kg, kb = (int(chroma[i:i + 2], 16) for i in (0, 2, 4))
    image = image.convert("RGBA")
    px = image.load()
    w, h = image.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            d = ((r - kr) ** 2 + (g - kg) ** 2 + (b - kb) ** 2) ** 0.5
            if d <= TRANSPARENT:
                px[x, y] = (r, g, b, 0)
            elif d < OPAQUE:
                ramp = (d - TRANSPARENT) / (OPAQUE - TRANSPARENT)
                px[x, y] = (r, g, b, int(a * ramp))
    return image


def main() -> int:
    from PIL import Image

    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()

    if not STATE.exists():
        raise SystemExit("no forge state at %s — run tools/forge.py run hud first" % STATE)
    state = json.loads(STATE.read_text(encoding="utf-8"))
    OUT.mkdir(parents=True, exist_ok=True)
    scratch = ROOT / "import_staging" / "ui"
    scratch.mkdir(parents=True, exist_ok=True)

    done = 0
    for key, (filename, size, trim) in PIECES.items():
        dest = OUT / filename
        if dest.exists() and not args.force:
            print("  %-20s already delivered" % key)
            continue
        record = state.get(key) or {}
        if not record.get("id"):
            print("  %-20s no job submitted" % key)
            continue
        info = job(record["id"])
        candidates = info.get("candidates") or []
        if info.get("status") != "complete" or not candidates:
            print("  %-20s %s %d%%" % (key, info.get("status"), info.get("progress", 0)))
            continue
        ## The recorded pick, or the first. With four candidates the workbench is
        ## where the choice gets made; `pick` is where it survives.
        index = min(int(record.get("pick", 0)), len(candidates) - 1)
        url = candidates[index].get("url")
        raw = scratch / ("%s.png" % key)
        with urllib.request.urlopen(LOOM + url, timeout=60) as r:
            raw.write_bytes(r.read())

        image = key_chroma(Image.open(raw), info.get("chroma_key", "#00FF00"))
        if image.getchannel("A").getextrema()[1] == 0:
            print("  %-20s REFUSED: keyed to nothing, wrong chroma?" % key)
            continue
        if trim:
            box = image.getbbox()
            if box:
                image = image.crop(box)
        scale = size / max(image.size)
        image = image.resize((max(1, round(image.width * scale)),
                              max(1, round(image.height * scale))), Image.LANCZOS)
        image.save(dest, optimize=True)
        print("  %-20s -> %-20s %s  candidate %d" % (key, filename, image.size, index + 1))
        done += 1

    for leftover in scratch.glob("*.png"):
        leftover.unlink()
    print("%d piece(s) delivered" % done)
    return 0


if __name__ == "__main__":
    sys.exit(main())
