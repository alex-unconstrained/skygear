#!/usr/bin/env python3
"""Generate 2D art with OpenAI's image model, into this project's own style.

    python tools/imageforge.py --list
    python tools/imageforge.py --key logo_skygear
    python tools/imageforge.py --key hero_boilerwright --n 3
    python tools/imageforge.py --key logo_skygear --force

WHY THIS EXISTS BESIDE `forge.py`. That tool drives the **Aether Loom**, a local
image server which is not on this machine and has not been for weeks — board
SG-105 has been BLOCKED on it, and SG-240's 33 paid generations are stranded
behind it. This is a second, independent door to the same job, and it needs
nothing running locally.

THE KEY IS AT **USER** SCOPE, NOT PROCESS SCOPE. `OPENAI_API_KEY` is set in the
Windows user environment; a Git Bash shell started from an older session does
not inherit it and `os.environ` comes back empty, which reads exactly like "no
key configured". This file reads the user scope explicitly before giving up —
that one line is the difference between "generate the art" and "ask the owner
for a key he already set".

TRANSPARENCY IS THE POINT for most of these. `background="transparent"` gives a
real cut-out PNG, which is what a logo and a hero plate both need; the older
image APIs could not do it and every asset had to be keyed by hand afterwards.
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GODOT = ROOT / "skygear-godot"
MODEL = "gpt-image-1"

## THE HOUSE STYLE, appended to every prompt so a new asset lands in the same
## game as the old ones. Lifted from what the cutscene prompts proved works.
STYLE = (
    "Hand-painted stylised game art in a storm-dusk steampunk palette: brass and "
    "warm gold, ember orange, deep violet shadow, moonlit silver rim-light. "
    "Painterly brushwork with crisp ink-dark edges, rich fine detail on metal. "
    "No text unless the prompt asks for it, no watermark, no photorealism."
)

ASSETS = {
    ## --- THE LOGO -------------------------------------------------------------
    ## The owner, twice: "I dont need the title written in the same lame font as
    ## everything else... a badass 'skygear' steampunk title", pointing at the
    ## Heroes of Newerth lockup — an ILLUSTRATED logo, not typeset text.
    "logo_skygear": dict(
        size="1536x1024", background="transparent",
        dest="skygear-godot/assets/art/ui/logo_skygear.png",
        prompt=(
            "A video game LOGO: the single word \"SKYGEAR\" as an ornate "
            "illustrated steampunk emblem, centred, on a fully transparent "
            "background. The letters are heavy carved antique metal — aged "
            "brass and dark iron with a bevelled edge, a bright polished "
            "highlight along the top of each letter and a deep shadow beneath, "
            "so the word reads as a solid three-dimensional casting. Rivets set "
            "into the letterforms. Fine engraved filigree in the metal. "
            "Behind and around the word: a pair of swept brass airship wings or "
            "propeller blades spreading left and right, interlocking cogs and "
            "gear teeth peeking from behind the letters, a few copper pipes and "
            "a small pressure gauge worked into the ornament, and faint ember "
            "light glowing out from the gaps between the metal as if a furnace "
            "burns behind it. Wisps of steam. "
            "The word SKYGEAR must be spelled exactly S-K-Y-G-E-A-R, perfectly "
            "legible, dominant, and the largest element. Symmetrical, "
            "emblem-like, game title treatment, high detail."),
    ),
    ## --- THE HEROES -----------------------------------------------------------
    ## Poster plates. The captain has three sprites already; the Boilerwright has
    ## NO 2D art anywhere in the project, only a 3D model whose albedo is an
    ## unreadable UV atlas.
    "hero_boilerwright": dict(
        size="1024x1536", background="transparent",
        dest="skygear-godot/assets/art/heroes/boilerwright_front_attack.png",
        prompt=(
            "Full-body character art of a heavy steampunk engineer, on a fully "
            "transparent background. STYLISED CHIBI PROPORTIONS: a large "
            "expressive head, compact powerful body roughly three and a half "
            "heads tall, small hands and feet, oversized weapon. "
            "He is broad and thickset, planted with his feet wide apart and "
            "immovable. Scorched heavy leather and a soot-stained canvas apron "
            "over riveted iron shoulder plates. Thick gauntlets. A brass "
            "pressure harness strapped across his chest with a round glass "
            "gauge at its centre, the needle high in the red. Two copper pipes "
            "run from the harness over his shoulders to a small riveted boiler "
            "tank on his back, venting white steam. A broad weathered face, "
            "short dark beard, shaved head, a leather welding cap with a "
            "cracked smoked-glass visor pushed up on his brow. He grips a huge "
            "iron pipe-wrench like a warhammer. Ember firelight from below on "
            "the brass, cool moonlight rimming his shoulders. Determined, "
            "patient, dangerous."),
    ),
    "hero_captain": dict(
        size="1024x1536", background="transparent",
        dest="skygear-godot/assets/art/heroes/corsair_hero_pose.png",
        prompt=(
            "Full-body character art of a young sky-corsair captain, on a fully "
            "transparent background. STYLISED CHIBI PROPORTIONS: a large "
            "expressive head, compact heroic body roughly three and a half "
            "heads tall, small hands and feet, oversized weapon. "
            "A red brass-buckled greatcoat with a gold-starred hem flaring "
            "behind him, brass goggles pushed up into spiked brown hair, an "
            "ornate brass clockwork gauntlet on one arm, dark boots with brass "
            "fittings. He stands in a confident wide hero stance, a large "
            "curved cutlass held low and out to one side, its edge catching "
            "ember light, the other fist clenched. Coat and hair caught in the "
            "wind. Ember firelight from below, cool moonlight rimming one "
            "shoulder. Confident, defiant, unafraid."),
    ),
}


def api_key() -> str:
    k = os.environ.get("OPENAI_API_KEY", "").strip()
    if k:
        return k
    ## THE USER SCOPE. Set in the Windows user environment; a shell started
    ## before it was set does not inherit it, and `os.environ` is then empty in
    ## a way that looks exactly like "no key configured".
    if sys.platform == "win32":
        try:
            out = subprocess.run(
                ["powershell", "-NoProfile", "-Command",
                 "[Environment]::GetEnvironmentVariable('OPENAI_API_KEY','User')"],
                capture_output=True, text=True, timeout=30)
            k = (out.stdout or "").strip()
            if k:
                return k
        except Exception:                                    # noqa: BLE001
            pass
    sys.exit("OPENAI_API_KEY is not set in the process OR the Windows user scope")


def generate(key: str, n: int, force: bool) -> list[Path]:
    spec = ASSETS[key]
    dest = ROOT / spec["dest"]
    if dest.exists() and not force and n == 1:
        print("%s exists — --force to replace, or --n 2+ to add candidates" % key)
        return [dest]

    body = {
        "model": MODEL,
        "prompt": spec["prompt"] + "\n\n" + STYLE,
        "size": spec["size"],
        "n": n,
        "output_format": "png",
    }
    if spec.get("background"):
        body["background"] = spec["background"]
    ## `quality` is the lever that matters for an emblem with letterforms in it.
    body["quality"] = spec.get("quality", "high")

    req = urllib.request.Request(
        "https://api.openai.com/v1/images/generations",
        data=json.dumps(body).encode("utf-8"),
        headers={"Authorization": "Bearer " + api_key(),
                 "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=600) as r:
            payload = json.loads(r.read())
    except urllib.error.HTTPError as e:
        sys.exit("HTTP %s: %s" % (e.code, e.read()[:900].decode("utf-8", "replace")))

    out: list[Path] = []
    dest.parent.mkdir(parents=True, exist_ok=True)
    cand = ROOT / ".shots" / "imageforge"
    cand.mkdir(parents=True, exist_ok=True)
    for i, item in enumerate(payload.get("data", [])):
        raw = base64.b64decode(item["b64_json"])
        ## Candidates always land in scratch; only a single generation is
        ## promoted to the real path, so a --n 4 run can never silently
        ## overwrite live art with an unlooked-at roll.
        c = cand / ("%s_%d.png" % (key, i + 1))
        c.write_bytes(raw)
        out.append(c)
        print("  candidate %d -> %s (%.0f KB)" % (i + 1, c, len(raw) / 1e3))
    if n == 1 and out:
        dest.write_bytes(out[0].read_bytes())
        print("%s -> %s" % (key, dest.relative_to(ROOT)))
        out = [dest]
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--key", action="append")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--n", type=int, default=1, help="candidates; >1 stays in scratch")
    ap.add_argument("--force", action="store_true")
    a = ap.parse_args()

    if a.list or not (a.key or a.all):
        for k, s in ASSETS.items():
            on = (ROOT / s["dest"]).exists()
            print("%-20s %-10s %-52s %s" % (k, s["size"], s["dest"],
                                            "ON DISK" if on else ""))
        return
    for k in (sorted(ASSETS) if a.all else a.key):
        if k not in ASSETS:
            sys.exit("no such key: %s" % k)
        print(k)
        generate(k, a.n, a.force)


if __name__ == "__main__":
    main()
