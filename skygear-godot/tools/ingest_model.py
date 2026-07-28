#!/usr/bin/env python3
"""Ingest a rigged character into the game, from an archive to a usable scene.

The captain took an afternoon and three false starts to bring in, and none of
the work was about her. Every rigged model has the same six problems:

  1. **It is enormous.** Seven FBX files at 27 MB each, because every animation
     export embeds the whole mesh AND its 25 MB texture. 190 MB for one skinned
     mesh and eight seconds of keyframes.
  2. **Every clip has its own skeleton**, with its own rest pose, up to 84
     degrees apart on the same named bone. Godot stores skeletal tracks as the
     bone local pose, so playing a clip authored on rest B against rest A
     composes the difference in — her arms went over her head.
  3. **The clips do not agree where the rig lives.** Five under
     `Armature/Skeleton3D`, one under `target_character/Skeleton3D` off a Rigify
     export. Godot resolves tracks by node path, so the odd one animated nothing.
  4. **The imported material points into the staging directory**, which is then
     deleted. The resource fails to load, and nothing says why.
  5. **The maps are far too big** for a figure a hundred and eighty pixels tall.
  6. **The root carries a unit scale** that a naive placement overwrites.

So this does the whole thing, from the manifest, and asserts the result is
self-contained before it lets you keep it.

  python tools/ingest_model.py list
  python tools/ingest_model.py captain
  python tools/ingest_model.py captain --keep-staging   # to inspect the imports

Two phases: this script unpacks and downscales, then drives Godot headless
through `tools/ingest_model.gd` for everything that needs the engine's importer.
"""
from __future__ import annotations

import argparse
import fnmatch
import json
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "tools" / "models.json"
STAGING = ROOT / "import_staging"
GODOT = Path("C:/Users/alexr/.local/bin/godot.exe")


def load_manifest() -> dict:
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    return {k: v for k, v in data.items() if not k.startswith("_")}


def unpack(archive: Path, into: Path) -> Path:
    """Get the archive onto disk as a directory, whatever form it arrived in."""
    into.mkdir(parents=True, exist_ok=True)
    if archive.is_dir():
        return archive
    with zipfile.ZipFile(archive) as z:
        z.extractall(into)
    # archives usually contain a single top-level folder; if so, use it
    entries = [p for p in into.iterdir() if p.name != "__MACOSX"]
    if len(entries) == 1 and entries[0].is_dir():
        return entries[0]
    return into


def find(source: Path, pattern: str) -> Path:
    hits = sorted(p for p in source.rglob("*") if fnmatch.fnmatch(p.name, pattern))
    if not hits:
        raise SystemExit("no file in %s matches %s" % (source, pattern))
    return hits[0]


def downscale(src: Path, dest: Path, size: int) -> None:
    from PIL import Image

    image = Image.open(src)
    mode = "RGBA" if image.mode in ("RGBA", "LA", "P") else "RGB"
    image = image.convert(mode)
    if max(image.size) > size:
        image = image.resize((size, size), Image.LANCZOS)
    dest.parent.mkdir(parents=True, exist_ok=True)
    image.save(dest, optimize=True)
    print("    %-14s %s -> %d px, %.1f MB" % (dest.name, Image.open(src).size, size,
                                              dest.stat().st_size / 1e6))


def godot(*args: str) -> str:
    result = subprocess.run([str(GODOT), "--path", str(ROOT), *args],
                            capture_output=True, text=True)
    return (result.stdout or "") + (result.stderr or "")


def ingest(name: str, spec: dict, keep_staging: bool) -> int:
    print("== %s" % name)
    archive = Path(spec["archive"])
    if not archive.is_absolute():
        archive = ROOT / archive
    if not archive.exists():
        raise SystemExit("archive not found: %s" % archive)

    scratch = STAGING / "_unpacked"
    if STAGING.exists():
        shutil.rmtree(STAGING, ignore_errors=True)
    source = unpack(archive, scratch)
    print("  unpacked %s" % source)

    out = ROOT / "assets" / "models" / name
    out.mkdir(parents=True, exist_ok=True)

    print("  maps:")
    maps = {}
    for role, cfg in spec.get("maps", {}).items():
        try:
            src = find(source, cfg["match"])
        except SystemExit:
            print("    %-14s (absent)" % role)
            continue
        dest = out / ("%s_%s.png" % (name, role))
        downscale(src, dest, int(cfg["size"]))
        maps[role] = dest.name

    ## Only the files Godot has to import go into staging, and they go in flat
    ## with predictable names so the .gd half does not have to glob.
    wanted = {"rig": spec["rig"]}
    for clip, pattern in spec["clips"].items():
        wanted["clip_" + clip] = pattern
    staged = {}
    for key, pattern in wanted.items():
        src = find(source, pattern)
        dest = STAGING / (key + src.suffix.lower())
        shutil.copy2(src, dest)
        staged[key] = dest.name
    shutil.rmtree(scratch, ignore_errors=True)
    print("  staged %d files for import" % len(staged))

    job = {
        "name": name,
        "rig": staged["rig"],
        "clips": {c: staged["clip_" + c] for c in spec["clips"]},
        "loop": spec.get("loop", []),
        "height": spec.get("height", 176.0),
        "facing": spec.get("facing", 0.0),
        "maps": maps,
    }
    (STAGING / "job.json").write_text(json.dumps(job, indent=2), encoding="utf-8")

    print("  importing…")
    godot("--headless", "--editor", "--quit")
    print("  building…")
    report = godot("--headless", "--script", "tools/ingest_model.gd")
    for line in report.splitlines():
        if line.startswith(("  ", "OK", "FAIL", "clips", "bones", "height")):
            print("  " + line.strip())

    if not keep_staging:
        shutil.rmtree(STAGING, ignore_errors=True)
        ## The verify runs AFTER staging is gone, deliberately. A scene that
        ## loads while its sources are still on disk proves nothing — the
        ## captain passed exactly that test and then failed to load in the game.
        print("  verifying with the sources deleted…")
        verify = godot("--headless", "--script", "tools/verify_model.gd", "--", name)
        for line in verify.splitlines():
            if line.startswith(("OK", "FAIL")):
                print("  " + line.strip())
        if "FAIL" in verify:
            return 1
    else:
        print("  staging kept at %s" % STAGING)
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("name", nargs="?", help="entry in tools/models.json, or 'list'")
    ap.add_argument("--keep-staging", action="store_true",
                    help="leave the imported FBXs in place to inspect")
    args = ap.parse_args()
    manifest = load_manifest()
    if not args.name or args.name == "list":
        for key, spec in manifest.items():
            built = (ROOT / "assets" / "models" / key / ("%s.tscn" % key)).exists()
            print("%-12s %-9s %d clips  %s" % (key, "BUILT" if built else "-",
                                               len(spec.get("clips", {})),
                                               spec["archive"]))
        return 0
    if args.name not in manifest:
        raise SystemExit("unknown model %r; try `list`" % args.name)
    return ingest(args.name, manifest[args.name], args.keep_staging)


if __name__ == "__main__":
    sys.exit(main())
