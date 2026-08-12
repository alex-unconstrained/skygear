#!/usr/bin/env python3
"""Generate the game's sound effects and voice through ElevenLabs, and edit them
down to the budgets the spec already set.

The same principle as tools/forge.py, for audio: the prompt for every cue lives
in version control beside the manifest key it fills. Here that is taken one step
further — the prompts are NOT copied into this file. They are read out of
`docs/AUDIO-SPEC.md` §7 and `docs/VOICE-BRIEF.md` §4, which are the documents a
person edits when they want a different sound. There is exactly one copy of
every prompt and one copy of every spoken line, and this tool is a consumer of
them, not a second source.

  python tools/soundforge.py list                 # what exists, what does not
  python tools/soundforge.py sfx --dry            # show what it would send
  python tools/soundforge.py sfx                  # the whole SFX queue
  python tools/soundforge.py sfx --only hit,crit
  python tools/soundforge.py voice                # the whole line sheet
  python tools/soundforge.py voice --only vo_vent --force

Then, always:

  python src/ingest-audio.py --from audio         # rewrite the delivery index
  python tools/audio-check.py                     # levels, clipping, cut tails

THE EDIT STEP IS THE POINT. ElevenLabs will not generate below 0.5s and its
sounds are authored with generous tails, but a `hit` cue is 120ms and a `ready`
tick is 90ms. AUDIO-SPEC calls its duration table "an edit budget, not a
generation instruction", so every take is generated long, then trimmed to first
sound, cut to the budget, faded 4ms so the cut is never a click, and peak
normalised to -8 dBFS — the level the whole delivered mix already sits at.
"""
from __future__ import annotations

import argparse
import array
import io
import json
import math
import os
import re
import struct
import sys
import time
import urllib.error
import urllib.request
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
API = "https://api.elevenlabs.io/v1"
AUDIO = ROOT / "audio"
STATE = Path(__file__).resolve().parent / "soundforge-state.json"
TARGET_PEAK_DB = -8.0

# --- the cast ---------------------------------------------------------------
# Chosen from the stock library against VOICE-BRIEF §2. Pinned by id, because a
# voice picked by NAME in a later session is a different voice.
#
#   CAPTAIN   Will — YOUNG, male, American, relaxed. RECAST 2026-08-11 on the
#             owner's ruling (board SG-228): this was Lily, middle-aged and
#             British and female, which never matched the art — the sprite and
#             the 3D model have always been a young man. Two candidates were
#             generated in full and judged by ear side by side; the owner chose
#             Will. Charlie (IKne3meq5aSn9XLyUdCD, young, deep, Australian) was
#             the runner-up and his complete 50 takes are kept in /casting-ab/
#             rather than deleted, so this decision can be re-heard.
#             "Relaxed" is doing real work here: the brief wants unhurried
#             under pressure, and the crew are cast young too — so the captain
#             is separated from his own boarders by STEADINESS, not by age.
#             DO NOT cast Harry (SOYHLrjzK2X1ezoPC6cr) — he is a CREW voice
#             below, and the captain must not sound like one of them.
#   CREW      three voices, round-robined across takes, because the brief wants
#             six takes of "man down" to sound like six different people.
#   COLOSSUS  Ezekiel Wren, old and raspy, then processed. It is not a person.
VOICES = {
    # WILL — chosen by the owner on 2026-08-11 after hearing both sets side by
    # side (`/casting-ab/`). Charlie (IKne3meq5aSn9XLyUdCD, young/deep/
    # Australian) was the other candidate and his 50 takes are kept there.
    "captain":  ["bIHbv24MWmeRgasZH58o"],
    "crew":     ["SOYHLrjzK2X1ezoPC6cr", "N2lVS1w4EtoT3dr4eOWO", "HIGUfNOdjuWQwwapnTRW"],
    "boss":     ["2tTjAGX0n5ajDmazDcWk"],
}
SETTINGS = {
    "captain":  {"stability": 0.42, "similarity_boost": 0.80, "style": 0.25, "use_speaker_boost": True},
    "crew":     {"stability": 0.30, "similarity_boost": 0.72, "style": 0.45, "use_speaker_boost": True},
    "boss":     {"stability": 0.55, "similarity_boost": 0.85, "style": 0.15, "use_speaker_boost": True},
}

# Loop beds. AUDIO-SPEC puts their length in the CUE column rather than the
# length column ("bed — **loop, 30 s**"), so the parser cannot see it, and a
# two-second storm bed loops audibly. 22s is the API's ceiling.
LOOP_LEN = {"amb_storm": 22.0, "amb_ship": 22.0, "boiler_critical": 4.0,
            "shape_beam_loop": 1.0}

# Cues whose "line" in the brief is a stage direction rather than words. The
# brief is right — six takes of a dash grunt must not be six readings of the
# word "grunt" — so the direction is turned into ElevenLabs audio tags here.
# One entry per take, so each take is a different sound.
WORDLESS = {
    "vo_dash":      ["[exhales sharply]", "[grunts]", "[short effort grunt]",
                     "[breathes out hard]", "[hup]", "[exhales]"],
    "vo_crew_down": ["[cries out in pain]", "Ah—!", "[grunts in pain]",
                     "Man down!", "[gasps]", "[pained shout]"],
    "vo_vent":      ["[exhales] Better.", "Off me.", "[laughs once] Hah.",
                     "[breathes out slowly]"],
}

# --- the five v11 cues ------------------------------------------------------
# These postdate AUDIO-SPEC §7 and are specified in VOICE-BRIEF §7, which is a
# prose table rather than the §7 prompt format. Their prompts live here, in the
# same version control, and are the only prompts this file owns.
V11_SFX = {
    "keg_fuse": (0.45, 1,
        "A pressurised steam keg's fuse lit: a bright hissing jet of escaping steam "
        "that RISES in pitch and intensity, close and urgent, metal ticking under it, "
        "no explosion"),
    "keg_blow": (0.60, 1,
        "A steam pressure vessel exploding: a dull low wet steam burst with a heavy "
        "metallic rupture, escaping pressure roaring outward, debris scatter, dark "
        "and blunt rather than bright"),
    "crate_break": (0.30, 2,
        "A wooden cargo crate smashed apart: splintering timber with a scatter of "
        "small brass parts landing on a ship deck, short and dry"),
    "lantern_break": (0.25, 1,
        "A glass oil lantern shattering and the oil catching: thin bright glass break "
        "followed immediately by a soft whump of fire igniting, close, dry"),
    "vent": (0.55, 1,
        "A brass relief valve venting hard: a rising release of pressurised steam with "
        "a bright top and a satisfying fall, close, powerful, no machinery clank"),
}


# --- reading the specs ------------------------------------------------------
def manifest() -> dict[str, str]:
    """manifest key -> path stem, straight out of AUDIO_MANIFEST."""
    src = (ROOT / "src" / "storm-dusk" / "_audio.js").read_text(encoding="utf-8")
    return dict(re.findall(r"(\w+):\s*\{\s*file:'([^']+)'", src))


def parse_len(cell: str):
    """'≤180 ms' / '**loop, 1.0 s**' / '≤1.8 s' -> (seconds, is_loop)."""
    c = cell.replace("*", "").strip()
    loop = "loop" in c.lower()
    m = re.search(r"([\d.]+)\s*(ms|s)\b", c)
    if not m:
        return (2.0 if loop else 0.5), loop
    v = float(m.group(1))
    return (v / 1000.0 if m.group(2) == "ms" else v), loop


def sfx_specs() -> dict[str, dict]:
    """Every SFX cue in AUDIO-SPEC §7, keyed by manifest key."""
    doc = (ROOT / "docs" / "AUDIO-SPEC.md").read_text(encoding="utf-8")
    body = doc[doc.index("## 7 · SFX"):doc.index("## 8 · Voice")]
    stems = manifest()
    by_base = {}
    for k, stem in stems.items():
        by_base.setdefault(stem.rsplit("/", 1)[-1], k)

    out = {}
    for line in body.splitlines():
        if not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip("|").split("|")]
        if len(cells) < 4 or not cells[0].startswith("`"):
            continue
        base = cells[0].split("`")[1]
        key = by_base.get(base)
        if not key:
            continue
        takes = 1
        pick = re.search(r"pick (\d)", cells[0])
        if pick:
            takes = int(pick.group(1))
        dur, loop = parse_len(cells[2])
        if key in LOOP_LEN:
            dur, loop = LOOP_LEN[key], True
        prompt = cells[-1].strip().strip("*").strip()
        # some rows put a note before the prompt: "…— *prompt*"
        m = re.search(r"\*(.+)\*\s*$", cells[-1].strip())
        if m:
            prompt = m.group(1).strip()
        out[key] = {"key": key, "stem": stems[key], "prompt": prompt,
                    "cap": dur, "loop": loop, "takes": takes}

    for key, (cap, takes, prompt) in V11_SFX.items():
        if key in stems:
            out[key] = {"key": key, "stem": stems[key], "prompt": prompt,
                        "cap": cap, "loop": False, "takes": takes}
    return out


def voice_specs() -> dict[str, dict]:
    """Every spoken line in VOICE-BRIEF §4, keyed by manifest key."""
    doc = (ROOT / "docs" / "VOICE-BRIEF.md").read_text(encoding="utf-8")
    body = doc[doc.index("## 4 · The line sheet"):doc.index("## 5 · What NOT")]
    stems = manifest()
    out = {}
    for line in body.splitlines():
        if not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip("|").split("|")]
        if len(cells) < 5 or not cells[0].startswith("`"):
            continue
        key = cells[0].split("`")[1]
        if key not in stems:
            continue
        cap, _ = parse_len(cells[2])
        try:
            takes = int(re.search(r"\d+", cells[3]).group(0))
        except Exception:                                # noqa: BLE001
            takes = 3
        raw = cells[4]
        lines = [l.strip().strip('"').strip() for l in raw.split("·")]
        lines = [l for l in lines if l and not l.lower().startswith("a hard breath")]
        who = "crew" if "/crew/" in stems[key] else ("boss" if "/boss/" in stems[key] else "captain")
        out[key] = {"key": key, "stem": stems[key], "cap": cap, "takes": takes,
                    "lines": lines, "who": who, "wordless": "no words" in raw.lower()
                                                            or "effort only" in raw.lower()}
    return out


# --- audio in, audio out ----------------------------------------------------
def api_key() -> str:
    k = os.environ.get("ELEVENLABS_API_KEY", "").strip()
    if not k:
        env = ROOT / ".env.local"
        if env.exists():
            for line in env.read_text(encoding="utf-8").splitlines():
                if line.startswith("ELEVENLABS_API_KEY="):
                    k = line.split("=", 1)[1].strip()
    if not k:
        raise SystemExit("no ELEVENLABS_API_KEY (env, or .env.local — which is gitignored)")
    return k


def post(path: str, payload: dict, params: str = "") -> bytes:
    req = urllib.request.Request(
        API + path + (("?" + params) if params else ""),
        data=json.dumps(payload).encode("utf-8"),
        headers={"xi-api-key": api_key(), "content-type": "application/json",
                 "accept": "audio/*"},
        method="POST")
    with urllib.request.urlopen(req, timeout=240) as r:
        return r.read()


def pcm_to_samples(raw: bytes) -> array.array:
    a = array.array("h")
    a.frombytes(raw[: len(raw) - (len(raw) % 2)])
    if sys.byteorder == "big":
        a.byteswap()
    return a


def edit(samples: array.array, sr: int, cap: float, loop: bool) -> array.array:
    """Trim to first sound, cut to the budget, fade the cut, normalise to -8 dBFS.

    This is the step that makes a 0.5s minimum generation usable as a 90ms tick,
    and the reason `crew_muster_1` — delivered by hand, cut mid-sound with no
    fade — is the one master in the repo that still needs regenerating.
    """
    if not samples:
        return samples
    peak = max(1, max(abs(s) for s in samples))
    if not loop:
        thresh = max(120, int(peak * 0.02))
        start = 0
        for i, s in enumerate(samples):
            if abs(s) > thresh:
                start = max(0, i - int(sr * 0.004))     # keep 4ms of the attack
                break
        samples = samples[start:]
        # ...and trim the silence AFTER it, so a 0.4s grunt inside a 0.6s budget
        # ends when the breath does rather than 200ms of room tone later. Only
        # ever shortens: the budget is still the ceiling.
        quiet = max(60, int(peak * 0.008))
        end = len(samples)
        for i in range(len(samples) - 1, -1, -1):
            if abs(samples[i]) > quiet:
                end = min(len(samples), i + int(sr * 0.030))
                break
        samples = samples[:end]
        n = int(cap * sr)
        if len(samples) > n:
            samples = samples[:n]
        # A 4ms fade stops the click but leaves the cue at full level when it
        # ends, which is audibly a cut. Scale the release with the cue: 12% of
        # its own length, capped at 30ms, floored at 4ms.
        fade = min(int(sr * 0.030), max(int(sr * 0.004), int(len(samples) * 0.12)))
        fade = min(fade, len(samples))
        for i in range(fade):
            samples[len(samples) - fade + i] = int(samples[len(samples) - fade + i] * (1 - i / fade))
    peak = max(1, max(abs(s) for s in samples))
    g = (10 ** (TARGET_PEAK_DB / 20.0) * 32767.0) / peak
    for i in range(len(samples)):
        samples[i] = max(-32768, min(32767, int(samples[i] * g)))
    return samples


def write_wav(path: Path, samples: array.array, sr: int):
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(samples.tobytes())


def take_path(stem: str, i: int, takes: int) -> Path:
    """Single takes are the bare stem; variants are _1.._n. This is what the
    loader expects: AudioBank.fetch appends _N only when the index says n > 1."""
    name = stem if takes == 1 else "%s_%d" % (stem, i + 1)
    return AUDIO / (name + ".wav")


SR_TRY = ["pcm_44100", "pcm_24000", "pcm_22050"]


def gen_sfx(spec: dict, i: int) -> tuple[array.array, int]:
    # Generate long and edit down: the API floor is 0.5s and a tail we cut is
    # cheaper than a sound that stops before it has finished happening.
    want = 0.5 if spec["loop"] else max(0.5, min(22.0, spec["cap"] * 3.0))
    if spec["loop"]:
        want = max(1.0, min(22.0, spec["cap"]))
    last = None
    for fmt in SR_TRY:
        try:
            raw = post("/sound-generation", {
                "text": spec["prompt"],
                "duration_seconds": round(want, 2),
                "prompt_influence": 0.55,
                "loop": bool(spec["loop"]),
            }, "output_format=" + fmt)
            return pcm_to_samples(raw), int(fmt.split("_")[1])
        except urllib.error.HTTPError as e:              # noqa: PERF203
            last = "%s %s" % (e.code, e.read()[:180].decode("utf-8", "replace"))
    raise RuntimeError(last or "no format accepted")


def gen_voice(spec: dict, i: int) -> tuple[array.array, int]:
    who = spec["who"]
    vid = VOICES[who][i % len(VOICES[who])]
    if spec["key"] in WORDLESS:
        opts = WORDLESS[spec["key"]]
    else:
        opts = spec["lines"] or ["[exhales]"]
    text = opts[i % len(opts)]
    last = None
    for fmt in SR_TRY:
        try:
            raw = post("/text-to-speech/" + vid, {
                "text": text,
                "model_id": "eleven_multilingual_v2",
                "voice_settings": SETTINGS[who],
            }, "output_format=" + fmt)
            return pcm_to_samples(raw), int(fmt.split("_")[1])
        except urllib.error.HTTPError as e:              # noqa: PERF203
            last = "%s %s" % (e.code, e.read()[:180].decode("utf-8", "replace"))
    raise RuntimeError(last or "no format accepted")


# --- commands ---------------------------------------------------------------
def load_state() -> dict:
    return json.loads(STATE.read_text(encoding="utf-8")) if STATE.exists() else {}


def save_state(st: dict):
    STATE.write_text(json.dumps(st, indent=1, sort_keys=True), encoding="utf-8")


def delivered(spec: dict) -> bool:
    """Already in the repo, whichever shape it was delivered in. Several cues
    shipped as _1.._3 variants before the spec marked them 'pick 3', so testing
    only the name this run would produce would re-pay for them."""
    stem = spec["stem"]
    return ((AUDIO / (stem + ".wav")).exists()
            or (AUDIO / (stem + "_1.wav")).exists()
            or any((AUDIO / (stem + ext)).exists() for ext in (".ogg", ".mp3", ".m4a")))


def run(specs: dict, gen, a):
    st = load_state()
    todo = [s for s in specs.values() if a.force or not delivered(s)]
    if a.only:
        want = a.only.split(",")
        todo = [s for s in todo if s["key"] in want]
    todo.sort(key=lambda s: s["key"])
    if a.limit:
        todo = todo[: a.limit]
    calls = sum(s["takes"] for s in todo)
    print("%d cue(s), %d generation(s)" % (len(todo), calls))
    if a.dry:
        for s in todo:
            print("\n=== %-16s x%d  cap %.2fs%s ===\n%s"
                  % (s["key"], s["takes"], s["cap"], "  LOOP" if s.get("loop") else "",
                     s.get("prompt") or " · ".join(s.get("lines", []))))
        return 0
    ok = bad = 0
    for s in todo:
        for i in range(s["takes"]):
            p = take_path(s["stem"], i, s["takes"])
            try:
                samples, sr = gen(s, i)
                # Keep the untrimmed take beside the edit. The edit step is the
                # part most likely to want changing — fade length, trim
                # threshold, a shorter budget — and without the raw, every one
                # of those changes is another paid generation. `*.wav.orig` is
                # already gitignored.
                write_wav(Path(str(p) + ".orig"), samples, sr)
                samples = edit(samples, sr, s["cap"], s.get("loop", False))
                write_wav(p, samples, sr)
                st[s["key"]] = {"takes": s["takes"], "sr": sr}
                save_state(st)
                print("  %-18s %-40s %5.2fs @%dHz" %
                      (s["key"], p.relative_to(ROOT).as_posix(), len(samples) / sr, sr))
                ok += 1
            except Exception as e:                       # noqa: BLE001
                print("  %-18s FAILED  %s" % (s["key"], e))
                bad += 1
            time.sleep(a.gap)
    print("\n%d written, %d failed" % (ok, bad))
    print("next: python src/ingest-audio.py --from audio && python tools/audio-check.py")
    return 1 if bad else 0


def cmd_reedit(a):
    """Re-apply the edit to every take we still have a raw for. No API calls.

    This exists because the first pass shipped a 4ms fade and audio-check's
    tail heuristic — correctly — called the results cut off mid-sound. Fixing
    that by regenerating would have paid twice for the same sounds."""
    specs = {}
    specs.update(sfx_specs())
    specs.update(voice_specs())
    only = a.only.split(",") if a.only else None
    n = 0
    for key, spec in sorted(specs.items()):
        if only and key not in only:
            continue
        for i in range(spec["takes"]):
            p = take_path(spec["stem"], i, spec["takes"])
            raw = Path(str(p) + ".orig")
            if not raw.exists():
                continue
            with wave.open(str(raw), "rb") as w:
                sr = w.getframerate()
                samples = pcm_to_samples(w.readframes(w.getnframes()))
            samples = edit(samples, sr, spec["cap"], spec.get("loop", False))
            write_wav(p, samples, sr)
            n += 1
    print("re-edited %d take(s) from raws — no generations spent" % n)
    return 0


def cmd_encode(a):
    """WAV in the repo, OGG on the wire.

    141 delivered files at 44.1kHz 16-bit is 14 MB of PCM, against a 30 MB
    budget for the whole game including art. Vorbis at q0.5 takes that to about
    a tenth of it with no audible cost on cues this short, and the loader has
    always preferred .ogg — EXTS in ingest-audio.py puts encoded formats first.

    The untrimmed `*.wav.orig` raws stay on disk (gitignored) so a re-edit and
    re-encode never costs a generation.
    """
    try:
        import soundfile as sf
    except ImportError:
        raise SystemExit("pip install soundfile  (see requirements-tools.txt)")
    wavs = [p for p in sorted(AUDIO.rglob("*.wav"))]
    if not wavs:
        print("nothing to encode")
        return 0
    before = after = 0
    for w in wavs:
        out = w.with_suffix(".ogg")
        info = sf.info(str(w))
        # Streamed in blocks rather than one array: encoding a 44-second bed in
        # a single write overflows the stack in the bundled libsndfile on
        # Windows and takes the interpreter with it (0xC00000FD, no traceback).
        # Blocked writes are also what lets this run over the whole tree.
        with sf.SoundFile(str(out), "w", samplerate=info.samplerate,
                          channels=info.channels, format="OGG", subtype="VORBIS") as o:
            for block in sf.blocks(str(w), blocksize=32768, dtype="int16"):
                o.write(block)
        before += w.stat().st_size
        after += out.stat().st_size
        if not a.keep:
            w.unlink()
    print("encoded %d file(s): %.1f MB -> %.1f MB (%.0f%% smaller)"
          % (len(wavs), before / 1e6, after / 1e6, 100 * (1 - after / max(1, before))))
    print("next: python src/ingest-audio.py --from audio")
    return 0


def cmd_list(a):
    sfx, vo = sfx_specs(), voice_specs()
    for name, specs in (("SFX", sfx), ("VOICE", vo)):
        have = sum(1 for s in specs.values() if delivered(s))
        print("\n%s — %d of %d delivered" % (name, have, len(specs)))
        for k in sorted(specs):
            s = specs[k]
            print("   %s %-18s x%d  %5.2fs  %s" %
                  ("OK " if delivered(s) else "   ", k, s["takes"], s["cap"],
                   (s.get("prompt") or " · ".join(s.get("lines", [])))[:64]))
    return 0


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(required=True)
    sub.add_parser("list").set_defaults(fn=cmd_list)
    r = sub.add_parser("reedit")
    r.add_argument("--only", default="")
    r.set_defaults(fn=cmd_reedit)
    e = sub.add_parser("encode")
    e.add_argument("--keep", action="store_true", help="keep the WAVs beside the OGGs")
    e.set_defaults(fn=cmd_encode)
    for name in ("sfx", "voice"):
        p = sub.add_parser(name)
        p.add_argument("--only", default="")
        p.add_argument("--limit", type=int, default=0)
        p.add_argument("--force", action="store_true")
        p.add_argument("--dry", action="store_true")
        p.add_argument("--gap", type=float, default=0.6)
        p.set_defaults(fn=(lambda a, n=name: run(sfx_specs() if n == "sfx" else voice_specs(),
                                                 gen_sfx if n == "sfx" else gen_voice, a)))
    a = ap.parse_args()
    return a.fn(a)


if __name__ == "__main__":
    raise SystemExit(main())
