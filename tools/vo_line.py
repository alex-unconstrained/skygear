#!/usr/bin/env python3
"""One-off voice lines, in a pinned cast voice, for something that is not a cue.

    python tools/vo_line.py --list
    python tools/vo_line.py --key cine_boiler_1
    python tools/vo_line.py --all

WHY THIS EXISTS BESIDE `soundforge.py`. That tool generates the GAME's voice
table: it reads `docs/VOICE-BRIEF.md`, walks every key, and takes its lines from
the brief. The opening film is not in that table and must not be — a cinematic
line is written for one moment in one edit, it has no gameplay trigger, and
adding it to the brief would make `soundforge` regenerate it every time the
brief is touched.

But it must use the SAME VOICE. `soundforge.VOICES["captain"]` is Will, chosen
by the owner on 2026-08-11 after hearing both candidates side by side, and
`soundforge.SETTINGS["captain"]` is the delivery that was chosen with him. So
this file imports both rather than restating them: a cinematic line that drifts
off the cast voice is worse than no line.

It also reuses `soundforge.edit()` — the trim-to-first-sound, cut-to-budget,
fade-the-cut, normalise-to--8dBFS step — so a line generated here sits at the
same level as every take already in the game.

COSTS MONEY. Each line below is one ElevenLabs call. `--list` is free and shows
what would be generated. Existing files are never overwritten without `--force`.
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import soundforge as sf                                          # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "skygear-godot" / "assets" / "audio" / "voice"

## THE LINES, AND WHERE EACH ONE GOES.
##
## The film already carries five voice cues, all of them takes that existed for
## gameplay reasons. What it does NOT have is the protagonist stating the stakes
## in his own words: the storyboard's rule was "the captain is not a narrator",
## which is right for the opening three shots and leaves shot 4 — the Boiler,
## the WHY of the whole film — silent. The only statement of motive in the cut
## is the enemy's, at 41 s, which is very late for a 53 s film.
##
## `who` picks the pinned cast voice. `cap` is the budget `edit()` trims to.
LINES = {
    ## Shot 4, the Boiler. The stakes, said by the person they belong to,
    ## twenty seconds earlier than the enemy says them.
    "cine_boiler_1": ("captain", 3.0,
                      "She's the only thing holding us up."),
    "cine_boiler_2": ("captain", 3.4,
                      "Keep her lit, and she keeps us flying."),
    ## Shot 9, his answer to "GIVE ME THE ENGINE." The film currently answers
    ## with `wave_start_3`, "Hold the deck." — which is a good line and is not
    ## an ANSWER. This one is.
    "cine_answer_1": ("captain", 3.0,
                      "Then come and take her."),
    "cine_answer_2": ("captain", 3.6,
                      "You want the engine? Come aboard."),
}


def ffmpeg() -> str:
    on_path = shutil.which("ffmpeg")
    if on_path:
        return on_path
    try:
        import imageio_ffmpeg
        return imageio_ffmpeg.get_ffmpeg_exe()
    except ImportError:
        sys.exit("no ffmpeg, and imageio_ffmpeg is not installed")


def generate(key: str, force: bool) -> Path:
    who, cap, text = LINES[key]
    dst = OUT / who / (key + ".ogg")
    if dst.exists() and not force:
        print("%-16s exists, skipping (--force to replace)" % key)
        return dst
    dst.parent.mkdir(parents=True, exist_ok=True)

    ## The same door `soundforge.gen_voice` uses, with the same pinned voice and
    ## the same delivery settings — imported, never restated.
    ##
    ## AND THE SAME FORMAT FALLBACK. `SR_TRY` is a LIST for a reason: this
    ## account's tier rejects `pcm_44100` with a 403 —
    ## *"Output format 'pcm_44100' is only available on the Pro tier and
    ## above"* — and the working format is the next one down. Taking `SR_TRY[0]`
    ## and calling it a day gets a 403 that looks like a bad API key.
    import urllib.error
    vid = sf.VOICES[who][0]
    last = None
    samples = rate = None
    for fmt in sf.SR_TRY:
        try:
            raw = sf.post("/text-to-speech/" + vid, {
                "text": text,
                "model_id": "eleven_multilingual_v2",
                "voice_settings": sf.SETTINGS[who],
            }, "output_format=" + fmt)
            samples, rate = sf.pcm_to_samples(raw), int(fmt.split("_")[1])
            break
        except urllib.error.HTTPError as e:
            last = "%s %s" % (e.code, e.read()[:200].decode("utf-8", "replace"))
    if samples is None:
        sys.exit("every audio format was refused: %s" % last)
    samples = sf.edit(samples, rate, cap, False)

    wav = dst.with_suffix(".wav")
    sf.write_wav(wav, samples, rate)
    ## Vorbis, because the game's loader prefers .ogg and every other take in
    ## the tree is one. `soundforge encode` would do this for the whole tree;
    ## one line does not need the whole tree walked.
    subprocess.run([ffmpeg(), "-y", "-loglevel", "error", "-i", str(wav),
                    "-c:a", "libvorbis", "-q:a", "4", str(dst)], check=True)
    wav.unlink()
    print("%-16s %-42s -> %s (%.1f KB)"
          % (key, '"%s"' % text, dst.relative_to(ROOT), dst.stat().st_size / 1e3))
    return dst


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--key", action="append", help="one key, repeatable")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--force", action="store_true")
    a = ap.parse_args()

    if a.list or not (a.key or a.all):
        print("%-16s %-9s %-6s %s" % ("KEY", "VOICE", "CAP", "LINE"))
        for k, (who, cap, text) in LINES.items():
            on_disk = (OUT / who / (k + ".ogg")).exists()
            print("%-16s %-9s %-6.1f %-44s %s"
                  % (k, who, cap, '"%s"' % text, "ON DISK" if on_disk else ""))
        return

    for k in (sorted(LINES) if a.all else a.key):
        if k not in LINES:
            sys.exit("no such key: %s" % k)
        generate(k, a.force)


if __name__ == "__main__":
    main()
