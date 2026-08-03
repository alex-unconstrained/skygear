#!/usr/bin/env python3
"""THE SHININESS QUESTION, AS PICTURES. Drives `tools/shiny_ab.gd`.

    python tools/shiny_ab.py                    # the seven-model spread
    python tools/shiny_ab.py lantern_post boss  # a chosen few

The owner asked to see what `tools/lamplit.py audit` is talking about. The audit
prints a table; this stands the model on the real deck under the real lamps and
photographs it BOTH WAYS.

THE CLAMPED FACTOR COMES FROM THE .GLB, NOT FROM A GUESS. It is
`LAMPLIT_METALLIC_MAX / peak texel of the metallic map` — the same arithmetic
`lamplit.clamp_glb` uses, imported from that module rather than retyped, so the
number in the picture is the number the clamp would actually apply. NOTHING ON
DISK IS REWRITTEN by any of this: the .glbs are read, the shot tool moves one
float in memory, and the audit's own refusal to rewrite stands.

THE SPREAD IS CHOSEN TO SPAN THE ARGUMENT rather than to win it: two figures
(the case the ceiling was derived for), two deck machines, one brass lamp that
is barely over the line, and two blades — because "some things get to stay
shiny" is the open half of the question and a blade is where it is most likely
to be true.
"""
from __future__ import annotations

import io
import json
import os
import struct
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from lamplit import LAMPLIT_METALLIC_MAX  # noqa: E402

OUT_RAW = "res://.shots/owner-review/_raw-shiny"
OUT_SHEETS = ".shots/owner-review/2-shininess"

## model -> one line saying why it is in the spread. Printed into the sheet.
SPREAD = {
    "gunner": "a boarder — the case the 0.34 ceiling was derived for",
    "scrapper": "the commonest boarder in the game",
    "harpoon_ballista": "a deck machine that has to read as a machine",
    "steam_vent": "deck furniture, and it carries its own light",
    "lantern_post": "brass, and only just over the line (mean 0.357)",
    "sword_gearblade": "a blade — where staying shiny might win",
    "sword_cutlass": "the captain's own cutlass, in her hand every run",
}

## `axe_furnace` is the shiniest thing the audit finds (effective mean 0.786) and
## it is NOT in the spread, because it cannot be rendered: it is the only .glb
## under assets/models with no `.import` beside it, so Godot has never imported
## it and `ResourceLoader` cannot see it — while `assets/models/weapons.json`
## names its path as a mountable weapon. Reported rather than fixed; it is a
## different job from photographing a ceiling, and STATUS.md's note that the
## furnace knight's "hands are empty where the sprite carries an axe" (SG-86)
## may well be the same fact seen from the other end.


def peak_texel(glb: Path) -> float:
    """The brightest BLUE texel of the material's metallic-roughness map.

    glTF packs metallic in blue. Read straight out of the .glb's own JSON and
    buffer, the way `lamplit.clamp_glb` reads it, so the factor computed here is
    the factor that clamp would write.
    """
    import numpy as np
    from PIL import Image

    raw = glb.read_bytes()
    off, chunks = 12, []
    while off < len(raw):
        clen, _ctype = struct.unpack("<II", raw[off:off + 8])
        chunks.append(raw[off + 8:off + 8 + clen])
        off += 8 + clen
    gltf = json.loads(chunks[0].decode("utf-8"))
    blob = chunks[1] if len(chunks) > 1 else b""
    peak = 0.0
    for mat in gltf.get("materials", []):
        mr = mat.get("pbrMetallicRoughness", {}).get("metallicRoughnessTexture")
        if mr is None:
            peak = max(peak, 1.0)
            continue
        src = gltf["textures"][mr["index"]].get("source")
        image = gltf["images"][src]
        view = gltf["bufferViews"][image["bufferView"]]
        start = view.get("byteOffset", 0)
        pic = Image.open(io.BytesIO(blob[start:start + view["byteLength"]]))
        peak = max(peak, float(np.asarray(pic.convert("RGB"))[..., 2].max() / 255.0))
    return peak or 1.0


def main(argv: list[str]) -> int:
    wanted = argv[1:] or list(SPREAD)
    models, notes = {}, {}
    for key in wanted:
        glb = ROOT / "assets" / "models" / key / ("%s.glb" % key)
        if not glb.exists():
            print("  no .glb for %s — skipped" % key)
            continue
        peak = peak_texel(glb)
        models[key] = round(LAMPLIT_METALLIC_MAX / peak, 4)
        notes[key] = SPREAD.get(key, "")
        print("  %-18s map peak %.4f  ->  metallic %.4f" % (key, peak, models[key]))
    if not models:
        return 1

    spec = {"models": models, "out": OUT_RAW, "zoom": 1.3}
    for key, note in notes.items():
        spec["note_%s" % key] = note

    godot = os.environ.get("GODOT") or str(
        Path(os.environ["USERPROFILE"]) / ".local" / "bin" / "godot.exe")
    ## WINDOWED. Every frame is a framebuffer readback and `--headless` has no
    ## rendering device — it writes empty PNGs and says nothing (SG-29).
    cmd = [godot, "--path", str(ROOT), "--resolution", "1600x900",
           "--script", "tools/shiny_ab.gd", "--", json.dumps(spec)]
    print("\n$ %s" % " ".join(cmd[:6]))
    if subprocess.call(cmd) != 0:
        return 2

    manifest = ROOT / OUT_RAW.replace("res://", "") / "manifest.json"
    return subprocess.call([sys.executable, str(ROOT / "tools" / "ab_sheet.py"),
                            str(manifest), OUT_SHEETS])


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
