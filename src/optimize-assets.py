#!/usr/bin/env python3
"""Validate or downsample runtime PNGs to the dimensions in ASSET_MANIFEST.

High-resolution generation masters should live outside the runtime asset trees.
This tool writes only exact-size runtime derivatives and refuses to upscale.

Examples:
  python src/optimize-assets.py --check
  python src/optimize-assets.py --write --set production
"""
from __future__ import annotations

import argparse
import os
import re
from pathlib import Path

from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[1]
MANIFEST_SOURCE = ROOT / "src" / "storm-dusk" / "_render_assets.js"
ENTRY_RE = re.compile(
    r"file:\s*'assets/(?P<file>[^']+)'\s*,\s*w:\s*(?P<w>\d+)\s*,\s*h:\s*(?P<h>\d+)"
)
SET_DIRS = {"production": ROOT / "assets", "49": ROOT / "assets-49"}


def target_dimensions() -> dict[str, tuple[int, int]]:
    source = MANIFEST_SOURCE.read_text(encoding="utf-8")
    targets = {
        match.group("file"): (int(match.group("w")), int(match.group("h")))
        for match in ENTRY_RE.finditer(source)
    }
    if not targets:
        raise RuntimeError(f"no asset targets parsed from {MANIFEST_SOURCE}")
    return targets


def render_derivative(image: Image.Image, target: tuple[int, int], allow_upscale: bool = False) -> Image.Image:
    tw, th = target
    sw, sh = image.size
    if (sw < tw or sh < th) and not allow_upscale:
        raise ValueError(f"refusing to upscale {sw}x{sh} to {tw}x{th}; pass --allow-upscale only for an approved exception")
    has_alpha = image.mode in {"RGBA", "LA"} or "transparency" in image.info
    if has_alpha:
        source = image.convert("RGBA")
        fitted = ImageOps.contain(source, target, method=Image.Resampling.LANCZOS)
        output = Image.new("RGBA", target, (0, 0, 0, 0))
        output.alpha_composite(fitted, ((tw - fitted.width) // 2, (th - fitted.height) // 2))
        return output
    source = image.convert("RGB")
    return ImageOps.fit(source, target, method=Image.Resampling.LANCZOS, centering=(0.5, 0.5))


def process(asset_set: str, write: bool, allow_upscale: bool, targets: dict[str, tuple[int, int]]) -> tuple[int, int, int, int]:
    root = SET_DIRS[asset_set]
    mismatches = changed = before_bytes = after_bytes = 0
    if not root.is_dir():
        return mismatches, changed, before_bytes, after_bytes
    for path in sorted(root.rglob("*.png")):
        relative = path.relative_to(root).as_posix()
        if relative not in targets:
            # Animation frames are declared per sequence in ANIMATION_MANIFEST,
            # not per file in ASSET_MANIFEST, and there are dozens of them. They
            # are validated by the sequence check below instead.
            if relative.startswith("animations/"):
                continue
            raise ValueError(f"runtime PNG is missing from ASSET_MANIFEST: {path}")
        target = targets[relative]
        with Image.open(path) as source:
            source.load()
            current = source.size
            before_bytes += current[0] * current[1] * 4
            after_bytes += target[0] * target[1] * 4
            if current == target:
                print(f"OK     {asset_set:>2}  {relative:<46} {current[0]}x{current[1]}")
                continue
            mismatches += 1
            print(
                f"RESIZE {asset_set:>2}  {relative:<46} "
                f"{current[0]}x{current[1]} -> {target[0]}x{target[1]}"
            )
            if not write:
                continue
            output = render_derivative(source, target, allow_upscale=allow_upscale)
            temporary = path.with_name(path.name + ".tmp")
            output.save(temporary, format="PNG", optimize=True, compress_level=9)
            os.replace(temporary, path)
            changed += 1
    return mismatches, changed, before_bytes, after_bytes


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--set", choices=["production", "49", "all"], default="all")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--check", action="store_true", help="report mismatches and fail; the default")
    mode.add_argument("--write", action="store_true", help="write exact-size runtime derivatives")
    parser.add_argument("--allow-upscale", action="store_true", help="permit an explicitly approved undersized source")
    args = parser.parse_args()
    targets = target_dimensions()
    sets = ["production", "49"] if args.set == "all" else [args.set]
    totals = [0, 0, 0, 0]
    for asset_set in sets:
        result = process(asset_set, args.write, args.allow_upscale, targets)
        totals = [a + b for a, b in zip(totals, result)]
    mismatches, changed, before_bytes, after_bytes = totals
    print(
        f"decoded RGBA budget: {before_bytes / 1024 / 1024:.1f} MiB -> "
        f"{after_bytes / 1024 / 1024:.1f} MiB"
    )
    if args.write:
        print(f"wrote {changed} optimized runtime PNG(s)")
        return 0
    if mismatches:
        print(f"FAIL: {mismatches} runtime PNG(s) do not match manifest dimensions")
        return 1
    print("PASS: runtime PNG dimensions match ASSET_MANIFEST")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())