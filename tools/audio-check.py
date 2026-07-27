#!/usr/bin/env python3
"""Measure every delivered audio master against AUDIO-SPEC, and fix what can be
fixed without regenerating.

The acceptance criteria in V10-PLAN §5 say "no delivered master clips; no
runtime rescue above ±6 dB". Neither half was measurable before this: the
loudness correction the ingest writes is a single number in a generated file,
and whether a master clips was something someone checked once by hand and wrote
down in a document.

What CAN be fixed offline:
  * A master that arrived too quiet. Amplifying at runtime and amplifying here
    are the same arithmetic, but doing it here means the correction factor in
    the index converges on 1.0, so the number stops hiding how far off the
    delivery was — and a short fade is applied at both ends so the lift does not
    expose a click.
  * A master whose peak is pinned at full scale. The distortion is baked in and
    attenuation cannot undo it, but pulling the peak down to -1 dBFS stops it
    slamming the master-bus compressor and dragging every other cue with it.

What CANNOT: the distortion itself, and a cue that was cut off mid-sound. Both
are flagged and both need regenerating, which needs a key this environment does
not have.

  python tools/audio-check.py            # report only
  python tools/audio-check.py --fix      # normalise in place, keeping a backup
"""
from __future__ import annotations

import argparse
import re
import array
import math
import shutil
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AUDIO = ROOT / "audio"

# -8 dBFS. Not -1: this is what src/ingest-audio.py targets as the working
# peak, and normalising to a different number here just moves the whole
# problem into the correction factor the index writes.
TARGET_PEAK = 0.398
RESCUE_LIMIT_DB = 6.0        # the acceptance criterion
FADE_MS = 4.0


def read_wav(p: Path):
    with wave.open(str(p), "rb") as w:
        n, sw, ch, fr = w.getnframes(), w.getsampwidth(), w.getnchannels(), w.getframerate()
        raw = w.readframes(n)
    if sw != 2:
        return None
    a = array.array("h")
    a.frombytes(raw)
    return dict(data=a, rate=fr, ch=ch, width=sw, frames=n)


def write_wav(p: Path, d):
    with wave.open(str(p), "wb") as w:
        w.setnchannels(d["ch"])
        w.setsampwidth(d["width"])
        w.setframerate(d["rate"])
        w.writeframes(d["data"].tobytes())


def measure(d):
    a = d["data"]
    if not len(a):
        return dict(peak=0.0, rms=0.0, clipped=0, runs=0, seconds=0.0, tail=0.0)
    peak = 0
    sq = 0.0
    clipped = 0
    runs = 0
    run = 0
    for v in a:
        av = -v if v < 0 else v
        if av > peak:
            peak = av
        sq += float(v) * float(v)
        if av >= 32767:
            clipped += 1
            run += 1
            if run == 3:            # three consecutive is a flat top, not a sample
                runs += 1
        else:
            run = 0
    n = len(a)
    # How loud is it still, at the very end? A cue that stops at most of its own
    # energy was cut off rather than allowed to finish.
    tailn = max(1, int(d["rate"] * 0.02) * d["ch"])
    tail = math.sqrt(sum(float(v) * float(v) for v in a[-tailn:]) / tailn) / 32768.0
    return dict(peak=peak / 32768.0,
                rms=math.sqrt(sq / n) / 32768.0,
                clipped=clipped, runs=runs,
                seconds=n / d["ch"] / d["rate"],
                tail=tail)


def db(x):
    return -99.0 if x <= 0 else 20 * math.log10(x)


def apply_gain(d, g):
    a = d["data"]
    rate, ch = d["rate"], d["ch"]
    fade = max(1, int(rate * FADE_MS / 1000.0)) * ch
    n = len(a)
    for i in range(n):
        v = a[i] * g
        # a short fade at both ends: lifting a quiet master by 12 dB will expose
        # any DC step at the boundaries as a click
        if i < fade:
            v *= i / fade
        elif i > n - fade:
            v *= (n - i) / fade
        if v > 32767:
            v = 32767
        elif v < -32768:
            v = -32768
        a[i] = int(v)
    return d


def loop_cues():
    """Which manifest entries are loops, read from the manifest rather than
    guessed from the filename."""
    src = (ROOT / "src" / "storm-dusk" / "_audio.js").read_text(encoding="utf-8")
    out = set()
    for m in re.finditer(r"(\w+):\s*\{\s*file:'([^']+)'([^}]*)\}", src):
        if "loop:true" in m.group(3).replace(" ", ""):
            out.add(m.group(2).rsplit("/", 1)[-1])
    return out


_LOOPS = None


def is_loop(path):
    global _LOOPS
    if _LOOPS is None:
        _LOOPS = loop_cues()
    return re.sub(r"_\d+$", "", path.stem) in _LOOPS


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--fix", action="store_true")
    a = ap.parse_args()

    files = sorted(AUDIO.rglob("*.wav"))
    if not files:
        print("no wav masters under audio/")
        return 0

    print("%-26s %7s %7s %7s %6s  %s" % ("cue", "peak", "rms", "rescue", "len", "notes"))
    bad = 0
    for p in files:
        d = read_wav(p)
        if d is None:
            print("%-26s  not 16-bit PCM — skipped" % p.name)
            continue
        m = measure(d)
        rescue = TARGET_PEAK / m["peak"] if m["peak"] > 0 else 0
        notes = []
        if m["runs"]:
            notes.append("CLIPS (%d flat runs, %d samples) — regenerate" % (m["runs"], m["clipped"]))
        # A LOOP is supposed to be at full level when it ends — that is what
        # makes the join inaudible — so the cut-off heuristic is exactly wrong
        # for one. It fired on amb_storm, amb_ship and boiler_critical the day
        # they landed and all three were correct; the check was not.
        if (m["tail"] > m["rms"] * 0.8 and m["seconds"] > 0.25
                and not is_loop(p)):
            notes.append("cut off mid-sound — regenerate shorter")
        if abs(db(rescue)) > RESCUE_LIMIT_DB:
            notes.append("needs %+.1f dB" % db(rescue))
        if notes:
            bad += 1

        if a.fix and m["peak"] > 0 and abs(db(rescue)) > 0.5 and not m["runs"]:
            bak = p.with_suffix(".wav.orig")
            if not bak.exists():
                shutil.copy2(p, bak)
            write_wav(p, apply_gain(d, rescue))
            notes.append("normalised %+.1f dB" % db(rescue))
        elif a.fix and m["runs"] and m["peak"] >= 0.999:
            # cannot un-clip, but can stop it slamming the master compressor
            bak = p.with_suffix(".wav.orig")
            if not bak.exists():
                shutil.copy2(p, bak)
            write_wav(p, apply_gain(d, TARGET_PEAK))
            notes.append("peak pulled to -8 dBFS")

        print("%-26s %6.1fdB %6.1fdB %+6.1fdB %5.2fs  %s"
              % (p.stem, db(m["peak"]), db(m["rms"]), db(rescue), m["seconds"],
                 "; ".join(notes)))

    print("\n%d of %d masters need regenerating or correction." % (bad, len(files)))
    if a.fix:
        print("Originals kept beside each file as .wav.orig.")
        print("Now run:  python src/ingest-audio.py --from audio  (rewrites the index)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
