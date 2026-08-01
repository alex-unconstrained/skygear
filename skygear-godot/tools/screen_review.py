#!/usr/bin/env python3
"""Photograph every screen at every resolution and lay them out to be judged.

    python tools/screen_review.py                 render everything, open it
    python tools/screen_review.py --tag before    keep this pass under a name
    python tools/screen_review.py --no-render     rebuild the page from disk
    python tools/screen_review.py --only workshop just the ones that match

WHY THIS EXISTS, and why it is not `screen_shot.gd`.

That tool photographs ONE screen well. This is for the other job: a human
sitting down to audit the whole game's UI in one pass, which is a different
activity with a different failure mode. Twenty-one screens at four widths is
eighty-four PNGs, and eighty-four files in a folder is not something a person
reviews — they open six, get bored, and the ultrawide ones nobody opens are
exactly where a dense layout breaks.

So: one page, every screen, resolutions side by side so the comparison is the
default rather than an effort. `text_audit.gd` already proves text sits inside
its frame and nothing overlaps; it has never had an opinion about whether a
screen looks GOOD, and it cannot. That judgement is the thing this hands over.

AND IT IS BUILT TO BE ARGUED WITH. Every shot carries its exact filename and a
copy button, because the feedback loop that matters is the user saying "this
one, this bit" — and a screenshot with no name attached costs a round trip to
identify. The filenames are stable across runs, so `--tag before` then
`--tag after` gives two pages that can be read against each other.
"""
import argparse
import os
import subprocess
import sys
import webbrowser

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
REPO = os.path.dirname(ROOT)
GODOT = os.environ.get("GODOT", os.path.expanduser(r"~\.local\bin\godot.exe"))

# The four the audit runs at. The two that matter most are the ends: the
# smallest window the project allows, where a dense layout runs out of room,
# and the ultrawide, where a fixed layout strands everything in the middle.
SIZES = ["1280x720", "1600x900", "1920x1080", "2560x1080"]

PAGE = """<!doctype html><meta charset="utf-8">
<title>SkyGear — every screen</title>
<style>
 :root { color-scheme: dark; }
 body { background:#14121a; color:#e8e2d8; font:14px/1.5 system-ui, sans-serif;
        margin:0; padding:28px 32px 80px; }
 h1 { font-size:20px; font-weight:600; margin:0 0 4px; }
 .sub { color:#8b8296; margin:0 0 28px; }
 h2 { font-size:16px; margin:38px 0 10px; padding-bottom:6px;
      border-bottom:1px solid #2a2635; color:#e8c376; }
 .row { display:flex; gap:14px; flex-wrap:wrap; align-items:flex-start; }
 .cell { background:#1c1926; border:1px solid #2a2635; border-radius:6px;
         padding:8px; }
 .cell img { display:block; max-width:100%%; width:420px; height:auto;
             border-radius:3px; cursor:zoom-in; }
 .cap { display:flex; justify-content:space-between; align-items:center;
        gap:10px; margin-top:6px; font-size:12px; color:#8b8296; }
 button { background:#2a2635; color:#cfc4b4; border:1px solid #3a3546;
          border-radius:4px; padding:2px 8px; font-size:11px; cursor:pointer; }
 button:hover { background:#3a3546; color:#fff; }
 dialog { border:none; background:#0d0b12; padding:0; max-width:96vw; }
 dialog img { display:block; max-width:96vw; max-height:92vh; }
 .miss { color:#ff8b6a; font-size:12px; }
</style>
<h1>SkyGear — every screen, every width</h1>
<p class="sub">%(count)d shots%(tagline)s. Click any image for full size. The
button copies that shot's filename, which is the fastest way to tell me
<em>which</em> one you mean.</p>
%(body)s
<dialog id="big" onclick="this.close()"><img id="bigimg"></dialog>
<script>
 const dlg = document.getElementById('big'), big = document.getElementById('bigimg');
 for (const img of document.querySelectorAll('.cell img')) {
   img.onclick = () => { big.src = img.src; dlg.showModal(); };
 }
 for (const b of document.querySelectorAll('button[data-name]')) {
   b.onclick = () => {
     navigator.clipboard.writeText(b.dataset.name);
     const was = b.textContent; b.textContent = 'copied';
     setTimeout(() => b.textContent = was, 900);
   };
 }
</script>
"""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tag", default="",
                    help="subfolder, so a before can sit beside an after")
    ap.add_argument("--only", default="",
                    help="substring; renders just the screens that match")
    ap.add_argument("--no-render", action="store_true")
    ap.add_argument("--no-open", action="store_true")
    a = ap.parse_args()

    shots = os.path.join(REPO, ".shots", "screens")
    if a.tag:
        shots = os.path.join(shots, a.tag)

    if not a.no_render:
        # One Godot launch per resolution rather than per screen: the tool
        # already loops the screen list internally, and starting the engine is
        # by far the most expensive thing here.
        for size in SIZES:
            args = [GODOT, "--path", ROOT, "--script", "tools/screen_shot.gd",
                    "--", a.only or "", size]
            if a.tag:
                args.append(a.tag)
            print("  rendering %s ..." % size)
            r = subprocess.run(args, capture_output=True, text=True)
            if r.returncode != 0:
                sys.stderr.write(r.stdout[-1500:] + r.stderr[-1500:])
                print("  FAILED at %s" % size)
                return 1

    if not os.path.isdir(shots):
        print("no shots at %s" % shots)
        return 1

    # Group by screen, so one screen's four widths sit on one row — which is
    # the comparison that finds layout bugs, and the one nobody makes by hand.
    by_screen = {}
    for name in sorted(os.listdir(shots)):
        if not name.endswith(".png"):
            continue
        stem = name[:-4]
        screen, _, size = stem.rpartition("-")
        by_screen.setdefault(screen or stem, []).append((size, name))

    if not by_screen:
        print("no PNGs in %s" % shots)
        return 1

    def order(pair):
        try:
            return SIZES.index(pair[0])
        except ValueError:
            return 99

    total = 0
    body = []
    for screen in sorted(by_screen):
        body.append("<h2>%s</h2><div class=\"row\">" % screen.replace("-", " "))
        for size, name in sorted(by_screen[screen], key=order):
            total += 1
            body.append(
                '<div class="cell"><img src="%s" loading="lazy" alt="%s">'
                '<div class="cap"><span>%s</span>'
                '<button data-name="%s">copy name</button></div></div>'
                % (name, name, size, name))
        body.append("</div>")

    index = os.path.join(shots, "index.html")
    with open(index, "w", encoding="utf-8") as f:
        f.write(PAGE % {"count": total, "body": "\n".join(body),
                        "tagline": (" &middot; <b>%s</b>" % a.tag) if a.tag else ""})

    print("")
    print("  %d shots across %d screens" % (total, len(by_screen)))
    print("  %s" % index)
    if not a.no_open:
        webbrowser.open("file:///" + index.replace("\\", "/"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
