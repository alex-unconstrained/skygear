#!/usr/bin/env python
"""Stitch a clip's frame sequence into one animated file (board SG-47).

The Godot half (tools/clip.gd) captures frame_0000.png ... into a directory;
this half turns them into something a person can actually watch. Split out of
the tool because Godot has no animated-image encoder and PIL is already on this
machine — and because a two-line Python step is easier to hold to a contract:

  * it REFUSES zero frames (exit 2) — an empty clip must be a loud failure at
    the stitch, not a 0-byte file somebody opens three days later;
  * it re-opens its own output and refuses to succeed (exit 3) unless the
    animation's frame count matches the frames it was given, so "the clip
    exists" and "the clip is whole" are the same claim.

    python tools/clip_stitch.py <frames_dir> <out.gif|out.apng> \
        [--delay-ms N] [--scale F]

GIF by default; name the output .apng (or .png) for an APNG instead. The
harness pins the zero-frame refusal headless (`clip · the stitcher refuses
zero frames`).
"""

import argparse
import sys
from pathlib import Path

from PIL import Image


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("frames_dir", help="directory of frame_*.png, in order")
    parser.add_argument("out", help="output file; .gif, or .apng/.png for APNG")
    parser.add_argument("--delay-ms", type=int, default=50,
                        help="per-frame delay in milliseconds (default 50 = 20 fps)")
    parser.add_argument("--scale", type=float, default=1.0,
                        help="resize factor; 0.5 halves a 1600x900 capture, "
                             "which is plenty for a motion call and a fifth of the bytes")
    args = parser.parse_args()

    frames = sorted(Path(args.frames_dir).glob("frame_*.png"))
    if not frames:
        print(f"clip_stitch: REFUSED - no frame_*.png in {args.frames_dir}",
              file=sys.stderr)
        return 2

    images = []
    for path in frames:
        image = Image.open(path).convert("RGB")
        if args.scale != 1.0:
            size = (max(1, round(image.width * args.scale)),
                    max(1, round(image.height * args.scale)))
            image = image.resize(size, Image.LANCZOS)
        images.append(image)

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    apng = out.suffix.lower() in (".apng", ".png")
    if not apng:
        # ONE palette for the whole clip, taken from the middle frame, and no
        # dithering. Per-frame palettes + dither on a noisy night deck tripled
        # the bytes (a 5 s fight came back 55 MB) and made the grain shimmer;
        # a shared palette cut the same clip to 15 MB with no motion call lost.
        reference = images[len(images) // 2].quantize(colors=256,
                                                      method=Image.MEDIANCUT)
        images = [image.quantize(palette=reference, dither=Image.Dither.NONE)
                  for image in images]
    images[0].save(out, save_all=True, append_images=images[1:],
                   duration=args.delay_ms, loop=0,
                   **({} if apng else {"optimize": True}))

    # The self-check: what landed is what was given, counted off the file
    # itself rather than trusted from the write path.
    with Image.open(out) as check:
        n = getattr(check, "n_frames", 1)
    if n != len(images):
        print(f"clip_stitch: WROTE {n} frames from {len(images)} inputs - refusing",
              file=sys.stderr)
        return 3

    print(f"stitched {n} frames x {args.delay_ms} ms "
          f"({n * args.delay_ms / 1000.0:.2f}s) -> {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
