"""Both builds, same moment, side by side.

The original job was "I want the game screenshots of both versions to be almost
identical in quality before we consider this job done." A lot of VFX work went
in against that. The comparison itself was never made — every parity judgement
so far has been my memory of the browser build against a Godot screenshot, which
is not evidence, and some of it may be regression.

This makes the evidence. Both builds expose enough to be posed deterministically:

    browser   window.SKYGEAR.{startRun, startWave, spawnEnemy, step, render}
    godot     tools/parity_shot.gd, same calls on SkyGearGame

so the same seed, the same wave, the same boarders in the same lanes, stepped
the same number of fixed ticks, rendered from the same camera. Anything that
differs after that is a real difference rather than a timing accident.

    python tools/parity.py                 every scene
    python tools/parity.py --scene fight   just one
    python tools/parity.py --open          and open the result

Writes `.shots/parity/<scene>.png` — browser left, Godot right, labelled — plus
`.shots/parity/index.html` so all of them are one scroll.

WHAT IT CANNOT DO: judge. It puts them next to each other at the same size and
that is the whole trick. The eye does the rest, and the eye is the thing the
original request was about.
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
import webbrowser

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = os.path.dirname(ROOT)
OUT = os.path.join(REPO, ".shots", "parity")
BROWSER_BUILD = os.path.join(REPO, "storm-dusk-v11.html")
GODOT = os.path.expanduser(r"~\.local\bin\godot.exe")
SIZE = (1600, 900)

# The moments worth comparing. Chosen because each answers a different question
# about the port, not because they look nice:
#
#   deck      the ship itself, empty. Lighting, materials, the sky, the horizon.
#   fight     boarders in three lanes. Figure legibility at the real distance.
#   effects   several skills mid-cast. Telegraphs, elements, impact.
#   hud       the full HUD under load. Readability, which is what was reported.
SCENES = [
    {
        "id": "deck",
        "what": "the empty deck — lighting, materials, sky",
        "wave": 1, "enemies": [], "steps": 40, "casts": [],
    },
    {
        "id": "fight",
        "what": "boarders in three lanes — figure legibility at real distance",
        "wave": 5, "enemies": ["SCRAPPER", "SCRAPPER", "GUNNER", "SWARM",
                               "SWARM", "ARMORED"], "steps": 430, "casts": [],
    },
    {
        "id": "effects",
        "what": "skills mid-cast — telegraphs, elements, impact",
        "wave": 6, "enemies": ["SCRAPPER", "SCRAPPER", "SCRAPPER", "GUNNER"],
        "steps": 400, "casts": [0, 1],
    },
    {
        "id": "boss",
        "what": "the Colossus — the largest thing either build draws",
        "wave": 12, "enemies": ["BOSS", "SWARM", "SWARM"], "steps": 480,
        "casts": [],
    },
]

SEED = "PARITY"


def browser_shot(scene, path):
    """Pose the browser build through its own exports and photograph the canvas."""
    from playwright.sync_api import sync_playwright

    # `step` is the build's own fixed tick, so stepping N times is exactly what
    # the game does in N frames — no wall-clock waiting, and no frame-rate
    # dependence in the comparison.
    script = """
    (scene) => {
      const G = window.SKYGEAR;
      if (!G) return "no SKYGEAR export";
      G.startRun(scene.seed);
      // startRun opens the weapon draft. Leaving it open photographs a menu
      // rather than the deck, which is what the first run of this tool did.
      try { G.pickCard(0); } catch (e) { try { G.closeDraft(); } catch (e2) {} }
      // The same three extra skills the Godot side is given, so the hand is
      // comparable and the HUD has something in it.
      try {
        for (const [shape, element] of [["RANGED_AOE","FROST"],
                                        ["CHAIN","ARC"], ["CONE","STEAM"]]) {
          G.newSkill(shape, element);
        }
      } catch (e) {}
      G.startWave(scene.wave);
      scene.enemies.forEach((kind, i) => G.spawnEnemy(kind, i % 3));
      for (const slot of scene.casts) { try { G.castSlot(slot); } catch (e) {} }
      for (let i = 0; i < scene.steps; i++) G.step(G.DT);
      G.render();
      return "ok";
    }
    """
    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page(viewport={"width": SIZE[0], "height": SIZE[1]})
        page.goto("file:///" + BROWSER_BUILD.replace("\\", "/"))
        page.wait_for_timeout(2500)          # assets, fonts, the first frame
        result = page.evaluate(script, {**scene, "seed": SEED})
        if result != "ok":
            browser.close()
            return result
        page.wait_for_timeout(250)
        canvas = page.query_selector("canvas")
        (canvas or page).screenshot(path=path)
        browser.close()
    return "ok"


def godot_shot(scene, path):
    """The same pose, through the Godot harness's own entry points."""
    args = [GODOT, "--path", ROOT, "--resolution", "%dx%d" % SIZE,
            "--script", "tools/parity_shot.gd", "--",
            json.dumps({**scene, "seed": SEED, "out": path})]
    done = subprocess.run(args, capture_output=True, text=True, timeout=300)
    if "shot ok" not in done.stdout:
        return (done.stdout + done.stderr)[-400:]
    return "ok"


def stitch(scene, left, right, path):
    from PIL import Image, ImageDraw

    a = Image.open(left).convert("RGB")
    b = Image.open(right).convert("RGB")
    # Matched height, because two screenshots at different sizes are not a
    # comparison — the eye reads the size difference before anything else.
    h = min(a.height, b.height)
    a = a.resize((int(a.width * h / a.height), h))
    b = b.resize((int(b.width * h / b.height), h))
    bar = 34
    sheet = Image.new("RGB", (a.width + b.width + 6, h + bar), (14, 12, 20))
    sheet.paste(a, (0, bar))
    sheet.paste(b, (a.width + 6, bar))
    d = ImageDraw.Draw(sheet)
    d.text((10, 9), "BROWSER  v11", fill=(232, 195, 118))
    d.text((a.width + 16, 9), "GODOT", fill=(55, 240, 200))
    d.text((sheet.width // 2 - 90, 9), scene["what"][:60], fill=(150, 145, 160))
    sheet.save(path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--scene", help="just this one")
    ap.add_argument("--open", action="store_true", help="open the sheet after")
    args = ap.parse_args()

    if not os.path.exists(BROWSER_BUILD):
        sys.exit("no browser build at %s" % BROWSER_BUILD)
    os.makedirs(OUT, exist_ok=True)
    tmp = os.path.join(OUT, "_tmp")
    os.makedirs(tmp, exist_ok=True)

    wanted = [s for s in SCENES if not args.scene or s["id"] == args.scene]
    if not wanted:
        sys.exit("no scene called %r" % args.scene)

    made = []
    for scene in wanted:
        print("\n%-9s %s" % (scene["id"], scene["what"]))
        left = os.path.join(tmp, "%s-browser.png" % scene["id"])
        right = os.path.join(tmp, "%s-godot.png" % scene["id"])

        why = browser_shot(scene, left)
        if why != "ok":
            print("  browser failed: %s" % why)
            continue
        print("  browser ok")

        why = godot_shot(scene, right)
        if why != "ok":
            print("  godot failed: %s" % why)
            continue
        print("  godot   ok")

        sheet = os.path.join(OUT, "%s.png" % scene["id"])
        stitch(scene, left, right, sheet)
        made.append(scene)
        print("  -> %s" % os.path.relpath(sheet, REPO))

    if made:
        index = os.path.join(OUT, "index.html")
        with open(index, "w", encoding="utf-8") as f:
            f.write("<style>body{background:#0e0c14;color:#cfc4b4;"
                    "font:15px system-ui;margin:24px}"
                    "img{width:100%;margin:8px 0 28px;border:1px solid #2a2436}"
                    "h2{font-weight:600;margin:22px 0 2px}"
                    "p{color:#8f8697;margin:0}</style>\n")
            f.write("<h1>SkyGear — browser against Godot</h1>\n")
            f.write("<p>Same seed, same wave, same boarders, same number of "
                    "fixed ticks. Anything that differs is a real difference.</p>\n")
            for scene in made:
                f.write("<h2>%s</h2><p>%s</p><img src='%s.png'>\n"
                        % (scene["id"], scene["what"], scene["id"]))
        print("\nwrote %s" % os.path.relpath(index, REPO))
        if args.open:
            webbrowser.open("file:///" + index.replace("\\", "/"))
    shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    main()
