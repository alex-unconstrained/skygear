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


def clamp_glb(path: Path, verbose: bool = True) -> dict:
    """Apply the ceiling to a .glb IN PLACE, by editing its glTF JSON only.

    Surgical on purpose. Loading a Meshy glb through trimesh and re-exporting it
    re-encodes every image and rewrites every buffer, which is a lossy round
    trip taken for the sake of one float. This rewrites the single JSON chunk
    and copies the binary chunk through untouched, so the pixels that land are
    byte-for-byte the pixels that arrived.

    `metallicFactor` ABSENT means 1.0 in glTF, so an absent field is written
    rather than skipped — the absence is the bug, not a neutral.
    """
    import json as _json
    import struct

    import numpy as np
    from PIL import Image

    raw = path.read_bytes()
    if raw[:4] != b"glTF":
        raise SystemExit("%s is not a binary glb" % path)
    _magic, _ver, _total = struct.unpack("<III", raw[:12])
    off, chunks = 12, []
    while off < len(raw):
        clen, ctype = struct.unpack("<II", raw[off:off + 8])
        chunks.append((ctype, raw[off + 8:off + 8 + clen]))
        off += 8 + clen
    gltf = _json.loads(chunks[0][1].decode("utf-8"))
    blob = chunks[1][1] if len(chunks) > 1 else b""

    ## Decode each metallic-roughness image once so the peak is measured off the
    ## pixels that actually ship rather than off an assumption about them.
    def _peak(tex_index: int) -> float:
        src = gltf["textures"][tex_index].get("source")
        if src is None:
            return 1.0
        image = gltf["images"][src]
        view = gltf["bufferViews"][image["bufferView"]]
        start = view.get("byteOffset", 0)
        data = blob[start:start + view["byteLength"]]
        import io
        pic = Image.open(io.BytesIO(data)).convert("RGB")
        return float(np.asarray(pic, dtype=np.float64)[..., 2].max() / 255.0)

    notes = []
    for mat in gltf.get("materials", []):
        pbr = mat.setdefault("pbrMetallicRoughness", {})
        factor = float(pbr.get("metallicFactor", 1.0))
        mr = pbr.get("metallicRoughnessTexture")
        peak_map = 1.0 if mr is None else _peak(mr["index"])
        peak_in = factor * peak_map
        if peak_in <= LAMPLIT_METALLIC_MAX:
            notes.append({"material": mat.get("name"), "changed": False,
                          "peak_in": peak_in})
            continue
        after = LAMPLIT_METALLIC_MAX / peak_map
        pbr["metallicFactor"] = after
        notes.append({"material": mat.get("name"), "changed": True,
                      "factor_in": factor, "factor_out": after,
                      "peak_in": peak_in, "peak_out": after * peak_map})
        if verbose:
            print("  %-22s metallicFactor %s -> %.4f  (peak %.4f -> %.4f)" % (
                str(mat.get("name"))[:22],
                "unset" if "metallicFactor" not in pbr else "%.3f" % factor,
                after, peak_in, after * peak_map))

    if not any(n["changed"] for n in notes):
        if verbose:
            print("  already under the %.2f ceiling, untouched"
                  % LAMPLIT_METALLIC_MAX)
        return {"changed": False, "materials": notes}

    js = _json.dumps(gltf, separators=(",", ":")).encode("utf-8")
    js += b" " * ((4 - len(js) % 4) % 4)
    out = bytearray(b"glTF") + struct.pack("<I", 2)
    body = struct.pack("<II", len(js), 0x4E4F534A) + js
    if blob:
        pad = blob + b"\x00" * ((4 - len(blob) % 4) % 4)
        body += struct.pack("<II", len(pad), 0x004E4942) + pad
    out += struct.pack("<I", 12 + len(body)) + body
    path.write_bytes(bytes(out))
    return {"changed": True, "materials": notes}


## KEPT ABOVE THE CEILING BY THE OWNER, 2026-08-13, ON A PHOTOGRAPHED A/B.
##
## These thirteen carry no `metallicFactor`, which glTF reads as 1.0, and the
## audit below correctly reports that their peak texel is over the ceiling. They
## were clamped on 2026-08-12 (board SG-291) and the clamp was REVERTED the next
## day on the owner's verdict.
##
## He was shown five of them as labelled side-by-sides — `tools/shiny_ab.gd`,
## both plates in one frozen scene, only the metallic factor changed between
## them, noise floor 0.00% — and chose the fully-metallic plate on every one:
## "B across the board."
##
## THIS LIST EXISTS SO THE NEXT PASS DOES NOT UNDO A DECISION IT CANNOT SEE. The
## audit's verdict on these is still that they are over; what changes is that it
## says WHY they are still here, rather than presenting a settled taste call as
## an outstanding defect for somebody to helpfully fix. Anything NOT on this list
## and over the ceiling is a real finding.
##
## The ceiling itself is unmoved and still governs everything else — including
## every flat-albedo material the renderer builds in code, which is the surface
## class SG-179 was actually about and which was NOT part of this A/B.
OWNER_KEPT = {
    "boarding_hulk", "boarding_hulk_sealed", "brazier", "cannon_deck",
    "crate_small", "crate_stack", "mast_section", "powder_keg",
    "railing_segment", "skyship_barge", "skyship_barge_heavy",
    "skyship_skiff", "skyship_tender",
}


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
    ## JUDGED ON THE PEAK, WHICH IS WHAT `clamp_metallic` GUARANTEES (board
    ## SG-291). This read `r[2]` — the MEAN — for the whole life of the tool,
    ## and the two halves of one module therefore disagreed about what the
    ## ceiling meant: the clamp sets the factor so the map's peak texel lands on
    ## LAMPLIT_METALLIC_MAX and says so in its own docstring ("no texel on this
    ## surface exceeds"), while the audit passed anything whose AVERAGE texel was
    ## under it. A metallic map is mostly dark by construction — it is a mask,
    ## and the painted difference between plate and brass is the reason to have
    ## one — so the mean of a map whose brass is at 1.0 sits comfortably under
    ## 0.34 and the audit called it ok. Thirteen shipped props were over on peak
    ## and every one of them printed `ok`, including the railing the player runs
    ## along (p95 0.9176, peak 1.0000) and the deck cannon (0.7961 / 1.0000).
    ##
    ## The mean and p95 columns STAY, because they are the useful context — a
    ## peak of 1.0 over a mean of 0.04 is a few bright rivets and a peak of 1.0
    ## over a mean of 0.28 is most of the object — but the verdict is the peak.
    high = [r for r in rows if r[4] > LAMPLIT_METALLIC_MAX + 1e-6]
    kept = [r for r in high if r[0] in OWNER_KEPT]
    over = [r for r in high if r[0] not in OWNER_KEPT]
    print("%-26s %-7s %8s %8s %8s" % (
        "model", "factor", "eff mean", "eff p95", "eff peak"))
    for name, factor, mean, p95, peak in sorted(rows, key=lambda r: -r[4]):
        if not show_all and peak <= LAMPLIT_METALLIC_MAX + 1e-6:
            continue
        ## The verdict is per row, not printed on every line. `--all` shows the
        ## models already UNDER the ceiling, and stamping OVER on those too made
        ## a clamped kit read as an unclamped one — which it did, on the day the
        ## seventeen were clamped and the audit still looked full of failures.
        print("%-26s %-7s %8.4f %8.4f %8.4f  %s" % (
            name, "unset" if factor == 1.0 else "%.3f" % factor,
            mean, p95, peak,
            ("KEPT" if name in OWNER_KEPT else "OVER")
            if peak > LAMPLIT_METALLIC_MAX + 1e-6 else "ok"))
    print("\n%d of %d shipped models have a texel above the %.2f lamplit "
          "ceiling and are not accounted for."
          % (len(over), len(rows), LAMPLIT_METALLIC_MAX))
    if kept:
        print("%d more are over it and are KEPT THERE BY THE OWNER "
              "(2026-08-13, on a 0.00%% noise-floor A/B): %s."
              % (len(kept), ", ".join(sorted(r[0] for r in kept))))
        print("Do not re-clamp those without asking him again — see "
              "OWNER_KEPT above.")
    ## Only true while there ARE any. It was printed unconditionally, so the
    ## run that cleared the last one still ended on a sentence about how they
    ## all have it unset.
    if over:
        unset = [r[0] for r in over if r[1] == 1.0]
        if unset:
            print("%d of them carry an UNSET metallicFactor, which glTF reads "
                  "as 1.0: %s." % (len(unset), ", ".join(sorted(unset))))
        print("Run `lamplit.py clamp <file.glb> ...` on each; it writes the "
              "factor only and never touches a pixel.")
    elif kept:
        print("Nothing is outstanding. The %d above are the owner's." % len(kept))
    else:
        ## THE SENTENCE THAT USED TO LIVE HERE WAS FALSE, AND IT WAS PRINTED
        ## DIRECTLY BENEATH THE COLUMN THAT REFUTED IT (board SG-291). It read:
        ## "N carry an UNSET metallicFactor and pass anyway, because their map is
        ## dark enough that 1.0 x map stays under the ceiling." That is a claim
        ## about the PEAK; the audit was judging the mean, so nothing had ever
        ## checked it; and it was wrong for all thirteen models it named, four of
        ## which peaked at exactly 1.0. An explanation the tool cannot support is
        ## worse than no explanation, because it tells the next reader to stop
        ## looking. What is printed now is what was actually established.
        still_unset = [r[0] for r in rows if r[1] == 1.0]
        if still_unset:
            print("%d carry an UNSET metallicFactor and pass anyway, because "
                  "their map's PEAK texel is under the ceiling even at a factor "
                  "of 1.0 — measured, not assumed: %s."
                  % (len(still_unset), ", ".join(sorted(still_unset))))
    print("This reports and does not rewrite — see the module docstring for why.")
    return 0


def main(argv: list[str]) -> int:
    if len(argv) >= 2 and argv[1] == "audit":
        return audit(show_all="--all" in argv)
    if len(argv) >= 3 and argv[1] == "clamp":
        bad = 0
        for name in argv[2:]:
            target = Path(name)
            if not target.exists():
                print("FAIL no such file: %s" % target)
                bad += 1
                continue
            print("%s:" % target.name)
            clamp_glb(target)
        return bad
    print(__doc__)
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
