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

## THE DEMO BUILD (board SG-213). A second export preset, not a second source
## tree: `Windows Desktop (Demo)` declares `custom_features="demo"` and that tag
## is the ONLY thing `scripts/demo.gd` reads. Both artifacts come off the same
## commit and the same harness run, which is what makes a demo-only bug
## impossible rather than unlikely.
DEMO_PRESET = "Windows Desktop (Demo)"
DEMO_EXE = os.path.join(PROJECT, "builds", "windows-demo", "SkyGear-Demo.exe")
DEMO_OUT = os.path.join(OUT_DIR, "SkyGear-Demo-Windows.zip")

## What the demo's own README says instead of the full one's tail. The cut is
## the owner's, `docs/STEAM-LAUNCH.md`: waves 1-6, Captain only, Heat 0, no
## fittings or berths.
DEMO_TAIL = """This is the DEMO. It is waves 1 to 6 with the Captain, and it
stops before the Brass Colossus.

The full game continues from there: twelve waves and the Colossus at the end of
them, the Boilerwright as a second captain who holds ground instead of taking
it, the Workshop, the Berths and the Articles between runs, and five rungs of
Heat with a ladder that remembers.

An opening film plays the first time you launch it. It is skippable from the
first frame, and SETTINGS has a WATCH THE OPENING row if you want it back.
"""

README_TMPL = """SKYGEAR — Windows build

Run SkyGear-Godot.exe. No installer, nothing written outside the game folder.

  W A S D   move
  mouse     aim
  LMB RMB   skills 1 and 2 (actives take these first)
  Q E       skills 3 and 4
  F V       the Boilerwright's tap and blowdown. On the captain these are
            his keyed Articles, if he is carrying any.
  Space     dash, two charges — or the Boilerwright's bleed jet, which is
            how he moves instead.
  R (hold)  work the deck — repair a dead cannon you are standing at.
            Holding is the point: it is a commitment, and walking away,
            casting or taking a hit all abandon it.
  wheel     zoom out (the shipped framing is as close as it gets)
  1 2 3 4   pick a draft card — four, because a talent can deal a fourth
  R         reroll the draft
  F11       leave fullscreen
  Esc / P   pause

Keep the Boiler alive through {WAVES} boarding waves. Every skill is a shape
crossed with an element, and the draft after each wave rewrites them.

Two captains, and they do not play alike. The CAPTAIN dashes twice and has to
fight CLOSE — his gauge fills from damage landed inside 210 units, and range is
the losing line. The BOILERWRIGHT has no dash at all: he banks Head from the
Boiler where he stands, and the pressure he is carrying is the resource the
whole class turns on. The class screen says how, in numbers.

Every fourth wave is not a wave.
"""


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--no-export", action="store_true")
    ap.add_argument("--demo", action="store_true",
                    help="export and pack the demo cut (SG-213) instead")
    a = ap.parse_args()

    preset = DEMO_PRESET if a.demo else "Windows Desktop"
    exe = DEMO_EXE if a.demo else EXE
    out = DEMO_OUT if a.demo else OUT
    inside = "SkyGear-Demo.exe" if a.demo else "SkyGear-Godot.exe"
    readme = README_TMPL.replace("{WAVES}", "six" if a.demo else "twelve")
    if a.demo:
        readme += DEMO_TAIL

    if not a.no_export:
        os.makedirs(os.path.dirname(exe), exist_ok=True)
        r = subprocess.run([GODOT, "--path", PROJECT, "--headless",
                            "--export-release", preset, exe],
                           capture_output=True, text=True)
        if r.returncode != 0 or not os.path.exists(exe):
            sys.stderr.write(r.stdout[-2000:] + r.stderr[-2000:])
            print("export FAILED")
            return 1

    if not os.path.exists(exe):
        print("no build at %s — run without --no-export" % exe)
        return 1

    os.makedirs(OUT_DIR, exist_ok=True)
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        z.write(exe, inside)
        z.writestr("README.txt", readme)

    names = zipfile.ZipFile(out).namelist()
    print("built %s — %d files, %.1f MB (from a %.1f MB exe)"
          % (os.path.relpath(out, PROJECT), len(names),
             os.path.getsize(out) / 1e6, os.path.getsize(exe) / 1e6))
    print("upload as a WINDOWS download; do NOT tick 'played in the browser'.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
