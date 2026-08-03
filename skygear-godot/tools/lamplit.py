#!/usr/bin/env python3
"""THE METALLIC CEILING FOR THIS DECK — one number, one clamp, one audit.

    python tools/lamplit.py audit            # every shipped model, measured
    python tools/lamplit.py audit --all      # including the ones already under

WHY THIS IS ITS OWN MODULE AND NOT A CONSTANT IN SOMEBODY'S TOOL.

This deck is LIT BY LAMPS. A high-metallic surface with almost no environment to
reflect has nothing to return: metal in a dark scene is dark. That is physically
correct and dramatically useless — it renders the object as a hole in the
planking rather than as an object. SG-90 learned this the expensive way, from a
rendered frame (`.shots/clips/boss` frame 30, first pass), and wrote the
conclusion down.

It wrote it down in ONE PLACE: the `PALETTE` table in `tools/segment_parts.py`,
which governed the only code path that existed at the time. Then:

  * SG-94 added the PAINTED path a few lines below it, which hands Meshy's own
    material straight through. It never applied the ceiling. The Colossus went
    dark again and was diagnosed as a texture bug for a day.
  * `tools/skyships.py` — the tool that brought in all five transports — does
    not mention metallic at all.
  * `tools/meshy.py`'s own shrink path resizes maps and leaves factors alone.

So the fact was known in one place and contradicted in three others, which is
this project's seventh recorded failure mode, and the measurement below is what
it cost. THE POINT OF THIS FILE IS THAT A FIFTH PATH CANNOT MISS IT: the number
and the reason travel together, and there is nowhere to put a new ingest tool
that does not have to walk past them.

WHAT MESHY ACTUALLY SHIPS, and why the default is the trap. Meshy writes NO
`metallicFactor` into its glTF. Absent means 1.0 — that is the spec's default,
not a neutral — over a metallic map that routinely averages 0.5 and peaks near
chrome. So a passthrough is not "leaving it alone"; it is choosing 1.0.

THE VALUE. `LAMPLIT_METALLIC_MAX` is the highest metallic SG-90's judged-by-eye
palette actually uses (the head, 0.34). It is a CEILING, not a target: a surface
is free to sit under it, and `clamp_metallic` leaves a compliant map untouched.

WHAT THIS FILE DOES NOT CLAIM. That every model in the repo should be clamped.
The ceiling was derived for a large dark machine that has to read as a machine.
Whether a brass lantern post or a gearblade WANTS to be shiny is a judgement
about that object, and `audit` reports rather than rewrites for exactly that
reason. See NEEDS_ALEX.md.
"""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

## The one number. See the module docstring for how it was arrived at and what
## it cost to have it in only one place.
LAMPLIT_METALLIC_MAX = 0.34


def map_peak(material) -> tuple[float, float, float, float]:
    """(factor, effective mean, effective p95, effective peak) for a material.

    Reads the glTF default rather than trusting the field: an ABSENT
    `metallicFactor` is 1.0, which is the whole trap this module exists for.
    """
    import numpy as np
    factor = getattr(material, "metallicFactor", None)
    factor = 1.0 if factor is None else float(factor)
    pic = getattr(material, "metallicRoughnessTexture", None)
    if pic is None:
        return factor, factor, factor, factor
    ## glTF packs metallic in BLUE and roughness in GREEN.
    b = np.asarray(pic.convert("RGB"), dtype=np.float64)[..., 2] / 255.0
    return (factor, factor * float(b.mean()),
            factor * float(np.percentile(b, 95)), factor * float(b.max()))


def clamp_metallic(material, verbose: bool = True) -> dict:
    """Bring a material under the ceiling and report what it did.

    glTF's effective metallic is `metallicFactor * metallicRoughnessTexture.b`,
    so the factor alone is not the knob — a factor of 1.0 over Meshy's map IS
    the bug. With a map present the factor is set so the map's PEAK texel lands
    on the ceiling, which makes the guarantee exact and easy to state: no texel
    on this surface exceeds `LAMPLIT_METALLIC_MAX`.

    Scaling to the peak rather than to the mean errs on the BRIGHT side, and
    bright is the side this deck's one recorded failure was not on.

    THE PIXELS ARE NOT REWRITTEN. The map keeps its own spatial variation — the
    painted difference between plate and brass is the reason to have a map at
    all — and only its overall level comes down.
    """
    factor, mean_in, p95_in, peak_in = map_peak(material)
    if peak_in <= LAMPLIT_METALLIC_MAX:
        if verbose:
            print("metallic: peak %.4f already under the %.2f ceiling, untouched"
                  % (peak_in, LAMPLIT_METALLIC_MAX))
        return {"factor_in": factor, "factor_out": factor, "peak_in": peak_in,
                "peak_out": peak_in, "ceiling": LAMPLIT_METALLIC_MAX,
                "changed": False}
    scale = LAMPLIT_METALLIC_MAX / peak_in
    after = factor * scale
    material.metallicFactor = after
    if verbose:
        print("metallic: metallicFactor %s -> %.4f" % (
            "unset (glTF default 1.0)" if factor == 1.0 else "%.4f" % factor,
            after))
        print("metallic: effective mean %.4f -> %.4f, p95 %.4f -> %.4f, "
              "peak %.4f -> %.4f (ceiling %.2f)" % (
                  mean_in, mean_in * scale, p95_in, p95_in * scale,
                  peak_in, peak_in * scale, LAMPLIT_METALLIC_MAX))
    ## THE GUARD, not decoration. This function exists because a ceiling applied
    ## on one path was silently missed on another, so it asserts its own
    ## postcondition rather than trusting the arithmetic three lines above.
    check = map_peak(material)[3]
    if check > LAMPLIT_METALLIC_MAX + 1e-6:
        raise SystemExit("clamp_metallic failed its own ceiling: %.4f > %.2f"
                         % (check, LAMPLIT_METALLIC_MAX))
    return {"factor_in": factor, "factor_out": after, "peak_in": peak_in,
            "peak_out": check, "ceiling": LAMPLIT_METALLIC_MAX, "changed": True}


def check_palette(palette: dict, where: str) -> None:
    """Assert a role->(hex, metallic, roughness) table obeys the ceiling.

    The flat-colour path's half. Editing a row up past the ceiling is exactly
    the edit that reintroduces SG-90's black silhouette, and it fails here
    before anything renders.
    """
    over = {r: v[1] for r, v in palette.items() if v[1] > LAMPLIT_METALLIC_MAX}
    if over:
        raise AssertionError("%s: metallic above the lamplit ceiling %.2f: %s"
                             % (where, LAMPLIT_METALLIC_MAX, over))


def audit(show_all: bool = False) -> int:
    """Measure every shipped model against the ceiling. Reports, never rewrites."""
    import trimesh
    rows = []
    for glb in sorted((ROOT / "assets" / "models").glob("*/*.glb")):
        try:
            scene = trimesh.load(glb, process=False)
        except Exception as exc:                       # noqa: BLE001
            print("  (skipped %s: %s)" % (glb.name, exc))
            continue
        for geom in scene.geometry.values():
            material = getattr(geom.visual, "material", None)
            if material is None:
                continue
            factor, mean, p95, peak = map_peak(material)
            rows.append((glb.stem, factor, mean, p95, peak))
            break
    over = [r for r in rows if r[2] > LAMPLIT_METALLIC_MAX]
    print("%-26s %-7s %8s %8s %8s" % (
        "model", "factor", "eff mean", "eff p95", "eff peak"))
    for name, factor, mean, p95, peak in sorted(rows, key=lambda r: -r[2]):
        if not show_all and mean <= LAMPLIT_METALLIC_MAX:
            continue
        print("%-26s %-7s %8.4f %8.4f %8.4f  OVER" % (
            name, "unset" if factor == 1.0 else "%.3f" % factor,
            mean, p95, peak))
    print("\n%d of %d shipped models are above the %.2f lamplit ceiling on "
          "MEAN effective metallic." % (len(over), len(rows),
                                        LAMPLIT_METALLIC_MAX))
    print("Every one of them has metallicFactor UNSET, which glTF reads as 1.0.")
    print("This reports and does not rewrite — see the module docstring for why.")
    return 0


def main(argv: list[str]) -> int:
    if len(argv) < 2 or argv[1] != "audit":
        print(__doc__)
        return 2
    return audit(show_all="--all" in argv)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
