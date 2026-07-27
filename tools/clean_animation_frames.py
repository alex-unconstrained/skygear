"""Prepare chroma-keyed animation frames for SKYGEAR's billboard renderer."""

from __future__ import annotations

import argparse
from pathlib import Path

import cv2
import numpy as np
from PIL import Image


def clean_frame(source: Path, destination: Path) -> None:
    rgba = np.asarray(Image.open(source).convert("RGBA"), dtype=np.float32)
    rgb = rgba[..., :3]
    alpha = rgba[..., 3]

    red, green, blue = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    magenta = np.minimum(red, blue)
    dominance = magenta - green
    saturation = np.clip((dominance - 8.0) / 72.0, 0.0, 1.0)
    brightness = np.clip((magenta - 28.0) / 128.0, 0.0, 1.0)
    contamination = saturation * brightness
    alpha *= 1.0 - 0.97 * contamination

    edge = 1.0 - alpha / 255.0
    spill = np.clip(dominance - 6.0, 0.0, 180.0) * contamination * (0.35 + 0.65 * edge)
    rgb[..., 0] = np.maximum(0.0, red - spill * 0.78)
    rgb[..., 2] = np.maximum(0.0, blue - spill * 0.78)
    alpha = np.clip((alpha - 52.0) * (255.0 / 203.0), 0.0, 255.0)

    binary = (alpha >= 26.0).astype(np.uint8)
    count, labels, stats, _ = cv2.connectedComponentsWithStats(binary, 8)
    if count > 1:
        largest = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
        keep = (labels == largest).astype(np.uint8)
        keep = cv2.dilate(keep, np.ones((7, 7), np.uint8), iterations=1)
        alpha *= keep

    alpha[alpha < 10.0] = 0.0
    rgb[alpha == 0.0] = 0.0
    output = np.dstack((np.clip(rgb, 0, 255), alpha)).astype(np.uint8)
    destination.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(output, "RGBA").save(destination, optimize=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path, help="Directory containing frame_*.png")
    parser.add_argument("destination", type=Path, help="Output frame directory")
    args = parser.parse_args()
    frames = sorted(args.source.glob("frame_*.png"))
    if not frames:
        raise SystemExit(f"No frame_*.png files found in {args.source}")
    for frame in frames:
        clean_frame(frame, args.destination / frame.name)
    print(f"Cleaned {len(frames)} frames into {args.destination}")


if __name__ == "__main__":
    main()
