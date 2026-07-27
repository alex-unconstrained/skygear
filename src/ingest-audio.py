#!/usr/bin/env python3
"""Pull delivered audio masters into the repo and regenerate the delivery index.

Audio differs from art in one way that matters: the loader cannot discover files
by guessing, because guessing means a fetch per manifest entry per extension and
a console full of 404s for everything not yet made. So the same step that copies
a file into the repo also writes `_audio_index.js`, naming exactly what exists
and with how many takes. The loader fetches only what is listed, which means no
404s and no hand-counting variants.

Re-run it whenever the staging folder changes; it is idempotent.

  python src/ingest-audio.py                      # copy, validate, write index
  python src/ingest-audio.py --check              # validate only, touch nothing
  python src/ingest-audio.py --from <dir>
"""
from __future__ import annotations

import argparse
import glob
import json
import math
import os
import re
import shutil
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST_SRC = ROOT / "src" / "storm-dusk" / "_audio.js"
INDEX_OUT = ROOT / "src" / "storm-dusk" / "_audio_index.js"
AUDIO_DIR = ROOT / "audio"
DEFAULT_SRC = Path(r"C:/Users/alexr/Dev/skygear-audio/out")
# Preference order: encoded first, raw last. mp3 sits with the encoded formats
# because that is what the music generator emits and re-encoding it would only
# lose another generation.
EXTS = (".ogg", ".m4a", ".mp3", ".wav")

# Spec §7 length budgets. A cue landing exactly on its cap was cut to fit, which
# is the pipeline working — but it also means nothing ended on its own terms, so
# it is worth seeing.
CAPS = {
    "shape_cleave": 0.180, "shape_lance": 0.260, "shape_gale": 0.400,
    "shape_mortar": 0.240, "shape_mortar_land": 0.450, "shape_whip": 0.200,
    "shape_beam_start": 0.200, "shape_beam_end": 0.300,
    "elem_ember": 0.300, "elem_frost": 0.350, "elem_arc": 0.250, "elem_steam": 0.320,
    "hit": 0.120, "crit": 0.200, "hurt": 0.350, "dash": 0.250,
    "ready": 0.090, "pickup": 0.200,
    "death_light": 0.300, "death_heavy": 0.600, "shoot_drone": 0.200,
    "telegraph": 0.400, "slam": 0.700, "boss_roar": 1.800, "climb": 0.400,
    "cannon_fire": 0.450, "cannon_hurt": 0.250, "cannon_down": 0.900,
    "crew_muster": 0.700, "crew_attack": 0.180, "crew_down": 0.400,
    "hulk_grapple": 1.400, "hulk_hit": 0.200, "hulk_break": 2.000,
    "crossing": 0.200,
    "boiler_hurt": 0.500, "wave_clear": 1.200, "wave_start": 0.900,
    "hover": 0.070, "click": 0.110, "card_pick": 0.500, "card_deal": 0.400,
    "slot_unlock": 0.600,
}


def manifest_files() -> dict[str, str]:
    """key -> relative path stem, straight out of AUDIO_MANIFEST."""
    src = MANIFEST_SRC.read_text(encoding="utf-8")
    out = {}
    for key, path in re.findall(r"(\w+):\s*\{\s*file:'([^']+)'", src):
        out[key] = path
    return out


def measure(path: Path):
    """Duration, peak, and whether the sound was still going when it was cut.

    Only WAV is inspectable with the stdlib; encoded files are reported as
    present and left to the ear.
    """
    if path.suffix != ".wav":
        return None
    with wave.open(str(path), "rb") as w:
        ch, sw, sr, n = w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()
        raw = w.readframes(n)
    if sw != 2:
        return {"dur": n / float(sr), "sr": sr, "ch": ch, "bits": sw * 8}
    s = struct.unpack("<%dh" % (len(raw) // 2), raw)
    if ch == 2:
        s = [(s[i] + s[i + 1]) // 2 for i in range(0, len(s), 2)]
    peak = max(abs(v) for v in s) / 32768.0 if s else 0.0

    def rms(a):
        return math.sqrt(sum(float(v) * v for v in a) / len(a)) / 32768.0 if a else 0.0

    total = rms(s)
    tail = rms(s[-int(sr * 0.05):]) if len(s) > sr * 0.05 else total
    runs = best = 0
    for v in s:
        if v >= 32767 or v <= -32768:
            runs += 1
            best = max(best, runs)
        else:
            runs = 0
    return {
        "dur": n / float(sr), "sr": sr, "ch": ch, "bits": sw * 8,
        "peak_db": 20 * math.log10(peak + 1e-9),
        "rms_db": 20 * math.log10(total + 1e-9),
        "tail_ratio": tail / (total + 1e-9),
        "clip_run": best,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--from", dest="src", default=str(DEFAULT_SRC))
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()
    src = Path(args.src)

    files = manifest_files()
    stem_to_key = {v: k for k, v in files.items()}

    found: dict[str, dict] = {}
    unmatched = []
    for ext in EXTS:
        for p in sorted(glob.glob(str(src / "**" / ("*" + ext)), recursive=True)):
            p = Path(p)
            rel = p.relative_to(src).as_posix()
            stem = rel[: -len(ext)]
            base = re.sub(r"_\d+$", "", stem)
            key = stem_to_key.get(base)
            if not key:
                unmatched.append(rel)
                continue
            e = found.setdefault(key, {"ext": ext, "stem": base, "takes": [], "src": []})
            if e["ext"] != ext:            # prefer encoded over raw when both exist
                if EXTS.index(ext) < EXTS.index(e["ext"]):
                    e.update(ext=ext, takes=[], src=[])
                else:
                    continue
            e["takes"].append(rel)
            e["src"].append(p)

    if unmatched:
        print("NOT IN MANIFEST (%d) — check the filename against AUDIO_MANIFEST:" % len(unmatched))
        for u in unmatched:
            print("   " + u)

    print("\n%-16s %-5s %5s %7s %7s %6s %5s  %s" %
          ("cue", "takes", "dur", "peak", "rms", "cut?", "clip", "flags"))
    total_bytes = 0
    for key in sorted(found):
        e = found[key]
        cap = CAPS.get(e["stem"].rsplit("/", 1)[-1])
        for p in e["src"]:
            total_bytes += p.stat().st_size
        m = measure(e["src"][0])
        flags = []
        if m:
            if cap and abs(m["dur"] - cap) < 0.003:
                flags.append("at-cap")
            if cap and m["dur"] > cap + 0.003:
                flags.append("OVER-CAP")
            if m.get("clip_run", 0) >= 3:
                flags.append("clipped")
            if m.get("tail_ratio", 0) > 0.5:
                flags.append("cut-mid-sound")
            if m.get("rms_db", 0) < -30:
                flags.append("very-quiet")
            print("%-16s %-5d %5.3f %7.1f %7.1f %6s %5d  %s" % (
                key, len(e["takes"]), m["dur"], m.get("peak_db", 0), m.get("rms_db", 0),
                ("yes" if "at-cap" in flags else "-"), m.get("clip_run", 0),
                " ".join(f for f in flags if f != "at-cap")))
        else:
            print("%-16s %-5d %5s %7s %7s %6s %5s  encoded" %
                  (key, len(e["takes"]), "-", "-", "-", "-", "-"))

    print("\n%d cue(s), %d file(s), %.1f MB" %
          (len(found), sum(len(e["takes"]) for e in found.values()), total_bytes / 1e6))
    if args.check:
        return

    for key, e in found.items():
        for p in e["src"]:
            dst = AUDIO_DIR / p.relative_to(src)
            dst.parent.mkdir(parents=True, exist_ok=True)
            # `--from audio` is now the normal case: tools/soundforge.py writes
            # generated cues straight into the repo's audio tree, and this step
            # exists to rebuild the index over whatever is there. Copying a file
            # onto itself raises SameFileError, so skip it rather than making
            # every caller stage a duplicate tree first.
            if dst.resolve() == p.resolve():
                continue
            shutil.copy2(p, dst)

    # Delivery loudness is wildly inconsistent — the first batch spanned 37 dB
    # of RMS, with the most-heard cue (hit) 30 dB under the loudest. Until the
    # encode pass does a proper loudness match, normalise every cue to a common
    # peak here so the mix is usable. This is a delivery correction, not a mix
    # decision: relative weighting between cues lives in AUDIO_MANIFEST.gain,
    # and as deliveries get closer to spec these numbers converge on 1.0.
    TARGET_PEAK_DB = -8.0
    index = {}
    for k, e in sorted(found.items()):
        # Music is mixed, not a one-shot: it already sits at a deliberate level
        # and its own bus fader controls it. Peak-normalising a five-minute
        # track against a 120ms impact is meaningless.
        if e["stem"].startswith("music/"):
            index[k] = {"ext": e["ext"], "n": len(e["takes"])}
            continue
        gains = []
        for p in e["src"]:
            m = measure(p)
            if m and "peak_db" in m:
                gains.append(10 ** ((TARGET_PEAK_DB - m["peak_db"]) / 20.0))
        g = round(min(8.0, max(0.15, sum(gains) / len(gains))), 3) if gains else 1.0
        index[k] = {"ext": e["ext"], "n": len(e["takes"])}
        if abs(g - 1.0) > 0.02:
            index[k]["g"] = g
    INDEX_OUT.write_text(
        "/* GENERATED by src/ingest-audio.py — do not edit.\n"
        "   What audio actually exists in the repo, and in how many takes. The\n"
        "   loader fetches only what is named here, so an undelivered cue costs\n"
        "   no request and logs no 404; it simply keeps its procedural voice. */\n"
        "const AUDIO_DELIVERED = " + json.dumps(index, indent=2) + ";\n",
        encoding="utf-8")
    print("wrote %s (%d cues)" % (INDEX_OUT.relative_to(ROOT), len(index)))
    for k, v in index.items():
        if "g" in v:
            print("   %-14s x%.2f  (%+.1f dB to reach %.0f dBFS peak)" %
                  (k, v["g"], 20 * math.log10(v["g"]), TARGET_PEAK_DB))


if __name__ == "__main__":
    main()
