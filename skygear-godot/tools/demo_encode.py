#!/usr/bin/env python
"""Encode the demo reel's frame sequences into one shareable mp4.

The Godot half (tools/demo_reel.gd) captures each shot to
`.shots/demo/<id>/frame_%04d.png` at 1600x900. This half cuts them together in
directory order and encodes H.264. It is a file rather than a shell one-liner
for the same reason `tools/clip_stitch.py` is: the flags that decide whether a
dark deck bands are worth keeping somewhere a person can read and change them.

    python tools/demo_encode.py [--fps 30] [--out <path.mp4>] [--crf 18]

WHY IT LOOKS FOR ffmpeg THE WAY IT DOES. There is no ffmpeg on PATH on this
machine, but `imageio_ffmpeg` ships a full ffmpeg 7.1 binary inside its wheel
and that package is already installed. So: PATH first (a real install wins if
one ever appears), then the wheel's copy. If neither is there the script says
so and exits 4 rather than quietly producing a GIF nobody asked for.

CUTS ARE HARD, deliberately. A dissolve between two shots framed this
differently reads as mush at 30 fps; the only ramps here are a fade up from
black at the head and a fade to black at the tail, so the thing has a top and a
bottom when it autoplays in a chat window.

THE FRAMES ARE HARD-LINKED, not copied, into one renumbered sequence for
ffmpeg's image2 reader — six hundred 1600x900 PNGs is most of a gigabyte and
there is no reason to write it twice. `os.link` falls back to a copy if the
scratch directory ever lands on another volume.
"""

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SHOTS = ROOT / ".shots" / "demo"


def find_ffmpeg() -> str | None:
    on_path = shutil.which("ffmpeg")
    if on_path:
        return on_path
    try:
        import imageio_ffmpeg
        return imageio_ffmpeg.get_ffmpeg_exe()
    except Exception:
        return None


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fps", type=int, default=30)
    parser.add_argument("--crf", type=int, default=18,
                        help="x264 quality; lower is better. 18 was picked by "
                             "looking, not by rule of thumb: the reel was cut "
                             "at 14 (37 MB) and at 20 (15 MB) and the two "
                             "darkest frames in it — the opening sky and the "
                             "arrival's empty deck, which are where a night "
                             "deck bands if it is going to — were "
                             "indistinguishable. 18 sits between them at about "
                             "20 MB, under the 25 MB attachment limit most "
                             "places still enforce, with no banding.")
    parser.add_argument("--out", default=str(ROOT / "skygear_demo.mp4"))
    parser.add_argument("--shots", default=str(SHOTS))
    args = parser.parse_args()

    ffmpeg = find_ffmpeg()
    if not ffmpeg:
        print("demo_encode: no ffmpeg on PATH and imageio_ffmpeg is not "
              "installed - cannot produce an mp4", file=sys.stderr)
        return 4

    shots_dir = Path(args.shots)
    shot_dirs = sorted(p for p in shots_dir.iterdir() if p.is_dir())
    if not shot_dirs:
        print(f"demo_encode: REFUSED - no shot directories in {shots_dir}",
              file=sys.stderr)
        return 2

    scratch = Path(tempfile.mkdtemp(prefix="skygear_reel_"))
    n = 0
    manifest = []
    try:
        for shot in shot_dirs:
            frames = sorted(shot.glob("frame_*.png"))
            if not frames:
                print(f"demo_encode: REFUSED - {shot.name} has no frames",
                      file=sys.stderr)
                return 2
            for frame in frames:
                target = scratch / f"{n:05d}.png"
                try:
                    os.link(frame, target)
                except OSError:
                    shutil.copyfile(frame, target)
                n += 1
            manifest.append((shot.name, len(frames)))

        duration = n / float(args.fps)
        # Fade up from black over the first 12 frames and down over the last
        # 15. `st` is in seconds, so it is derived from the real frame count
        # rather than hand-typed - a tail fade that starts late is a video that
        # ends on a cut to black.
        fade_out_at = max(0.0, duration - 0.5)
        vf = (f"fade=t=in:st=0:d=0.4,"
              f"fade=t=out:st={fade_out_at:.3f}:d=0.5,"
              f"format=yuv420p")

        cmd = [
            ffmpeg, "-y",
            "-framerate", str(args.fps),
            "-i", str(scratch / "%05d.png"),
            "-vf", vf,
            "-c:v", "libx264",
            "-preset", "slow",
            "-crf", str(args.crf),
            # 4:2:0 + the constrained profile is what makes this play in a
            # browser, a phone and Discord without transcoding.
            "-profile:v", "high",
            "-level", "4.1",
            "-pix_fmt", "yuv420p",
            "-movflags", "+faststart",
            "-an",
            str(args.out),
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            sys.stderr.write(result.stderr[-4000:])
            print(f"demo_encode: ffmpeg exited {result.returncode}",
                  file=sys.stderr)
            return 3
    finally:
        shutil.rmtree(scratch, ignore_errors=True)

    out = Path(args.out)
    if not out.exists() or out.stat().st_size == 0:
        print("demo_encode: ffmpeg reported success but the file is missing "
              "or empty - refusing", file=sys.stderr)
        return 3

    print(f"cut {len(manifest)} shots, {n} frames, {n / args.fps:.2f}s @ {args.fps} fps")
    for name, count in manifest:
        print(f"  {name:<12} {count:>4} frames  {count / args.fps:5.2f}s")
    print(f"-> {out}  ({out.stat().st_size / 1_048_576:.1f} MB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
