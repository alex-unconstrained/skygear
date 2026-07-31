#!/usr/bin/env python3
"""Export the Windows build and pack it for itch.io.

Windows first, hardware accelerated. The port is on Forward+ (Vulkan) rather
than the gl_compatibility renderer a web export needs — that decision is in
project.godot with its reasoning, and this script is the other half of it: the
artifact that ships is an .exe, not an HTML page.

  python tools/pack_itch.py              # export + zip
  python tools/pack_itch.py --no-export  # zip whatever is already in builds/

Then, once the itch project page exists:

  butler push builds/itch/SkyGear-Windows.zip <user>/<game>:windows

Godot will not create the export directory for you: exporting into a path whose
parent is missing fails with "Prepare Template: The given export path doesn't
exist", which reads like a template problem and is not one.
"""
import argparse
import os
import subprocess
import sys
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(HERE)
GODOT = os.environ.get("GODOT", "C:/Users/alexr/.local/bin/godot.exe")
EXE = os.path.join(PROJECT, "builds", "windows", "SkyGear-Godot.exe")
OUT_DIR = os.path.join(PROJECT, "builds", "itch")
OUT = os.path.join(OUT_DIR, "SkyGear-Windows.zip")

README = """SKYGEAR — Godot port, Windows build

Run SkyGear-Godot.exe. No installer, nothing written outside the game folder.

  W A S D   move
  mouse     aim
  LMB RMB   skills 1 and 2 (actives take these first)
  Q E       skills 3 and 4
  Space     dash (two charges)
  F         work the deck — repair a dead cannon you are standing at
  wheel     zoom
  1 2 3     pick a draft card
  R         reroll the draft
  Esc / P   pause

Keep the Boiler alive through twelve boarding waves. Every skill is a shape
crossed with an element, and the draft after each wave rewrites them.

Two captains. The CAPTAIN dashes twice and fights at range. The BOILERWRIGHT
has no dash at all — she banks Head from the Boiler itself and spends it on
jets, blowdowns and taps, and the pressure she is carrying is the resource the
whole class turns on. They do not play alike; the class screen says how.

Every fourth wave is not a wave. The browser version at
https://alex-unconstrained.github.io/skygear/ is the original.
"""


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--no-export", action="store_true")
    a = ap.parse_args()

    if not a.no_export:
        os.makedirs(os.path.dirname(EXE), exist_ok=True)
        r = subprocess.run([GODOT, "--path", PROJECT, "--headless",
                            "--export-release", "Windows Desktop", EXE],
                           capture_output=True, text=True)
        if r.returncode != 0 or not os.path.exists(EXE):
            sys.stderr.write(r.stdout[-2000:] + r.stderr[-2000:])
            print("export FAILED")
            return 1

    if not os.path.exists(EXE):
        print("no build at %s — run without --no-export" % EXE)
        return 1

    os.makedirs(OUT_DIR, exist_ok=True)
    with zipfile.ZipFile(OUT, "w", zipfile.ZIP_DEFLATED) as z:
        z.write(EXE, "SkyGear-Godot.exe")
        z.writestr("README.txt", README)

    names = zipfile.ZipFile(OUT).namelist()
    print("built %s — %d files, %.1f MB (from a %.1f MB exe)"
          % (os.path.relpath(OUT, PROJECT), len(names),
             os.path.getsize(OUT) / 1e6, os.path.getsize(EXE) / 1e6))
    print("upload as a WINDOWS download; do NOT tick 'played in the browser'.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
