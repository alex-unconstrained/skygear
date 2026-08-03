#!/usr/bin/env python3
"""Bring the owner's five transports in, from 235 MB of Meshy to 4 MB of fleet.

    python tools/skyships.py            # the whole fleet
    python tools/skyships.py cutter     # one of them
    python tools/skyships.py --measure  # measure only, write nothing

WHAT ARRIVED, AND WHY THE NAMES IN THIS FILE ARE NOT THE OWNER'S.
================================================================
Five textured exports and four part-segmentation twins, generated from
`handoff-3d/skyship_transports/PROMPTS.md` — the four archetypes that document
asks for (skiff / barge / cutter / hulk-tender) plus a second barge. Meshy named
them, and Meshy's names are about grandeur rather than about the object: every
single one is misleading and two are close to inverted.

  "The Iron Zephyr"        is the RAMSHACKLE SALVAGE TENDER, the slowest and
                           most patched thing in the fleet. A zephyr it is not.
  "Copper Cloud Voyager"   is the little open SKIFF — one boiler, one gas bag on
                           struts, grapple hooks coiled at the bow.
  "Gilded Leviathan"       is the CUTTER, and it is the NARROWEST hull delivered
                           (0.460 across against the barge's 0.940). A leviathan
                           is the one thing it is not.
  "Brass Leviathan"        is the BARGE the prompt describes almost line for
                           line — flat freight hull, railed cargo deck, hinged
                           ramp, four rotors in brass ring mounts on outriggers.
  "The Brass Leviathan"    is a SECOND barge: deeper, three stacks, bladed
                           rotors. A variant, not a duplicate.

The mapping was made BY LOOKING, not by reading — the same method that caught
the boarding hulk's three state labels being swapped (`tools/static_model.gd`).
Each sculpt was rendered side-on, three-quarter, front and plan, and matched
against the owner's own concept paintings; the frames are in
`.shots/skyships/id/`. Four of the five land on a concept image feature for
feature — the skiff's coiled bow hooks, the barge's rope-and-stanchion rail, the
cutter's pintle gun and ram prow, the tender's hanging plank gangway and its
paddle wheel — which is corroboration a name cannot give.

So the keys here are ROLES. `skyship_cutter` is a promise about a silhouette;
"Gilded Leviathan" is a promise about nothing.

WHAT THIS DOES, IN THREE STEPS, AND WHY EACH IS THE CHEAP ONE.
==============================================================
1. **SHRINK THE MAPS.** 98% of every delivered file is texture and 31 MB of it
   is a single 4096 PNG NORMAL map — per ship, five times over. The budget is
   `meshy.shrink_glb`'s and the size is argued in `BUDGET` below.

2. **CUT THE MOVING MASSES OUT**, where a segmentation twin exists AND something
   on the ship should actually move. This is the boss's trick and the drone's
   (`tools/segment_parts.py`, `tools/split_rotors.py`): the segmentation carries
   no UVs and no images and is worthless as geometry, but it says which triangle
   belongs to which part, which is exactly the fact the welded textured export
   has lost. Labels transfer by nearest neighbour in a uniformly normalised box
   and are then thrown away; the parts are cut FROM THE TEXTURED MESH.

   ONLY WHAT SHOULD MOVE. Two ships are split and three are not, and the three
   are the interesting decision: the cutter's envelope is STRAPPED TIGHT to its
   hull and bobbing it would tear it off the straps, the tender has no
   segmentation twin to label from, and the second barge is banked rather than
   placed. Fragmenting a hull because a tool can is how a static prop acquires
   seams nobody asked for.

3. **AND THEY ARE NOT DECIMATED.** This step was written, run, looked at, and
   deleted, and the reason is worth more than the code was — see
   `WHY NOTHING IS DECIMATED` below.
"""
from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import meshy                                            # noqa: E402
from split_rotors import accessor, glb_read, glb_write  # noqa: E402

DOWNLOADS = Path.home() / "Downloads"
ORIGINALS = ROOT / ".model_originals" / "skyships"
OUT_ROOT = ROOT / "assets" / "models"

# --- THE TEXTURE BUDGET -------------------------------------------------------
# `meshy.tex_budget` keys off an asset's on-screen HEIGHT, and for a figure —
# which is roughly as tall as it is wide — height is a fair stand-in for how much
# atlas the thing spends. A HULL IS NOT: these run four times longer than they
# are tall, Meshy packs the whole ship into one atlas, and the length is where
# the texels go. Keyed off height these would all fall under the 260-px
# threshold and take a 512 base; keyed off the LONGEST on-screen dimension, which
# is the honest input, they run 211 to 423 px and three of the four clear it.
#
# The numbers are measured, not guessed. `tools/skyship_probe.gd` puts each ship
# at its shipped station, and at the mid-deck pose they cover:
#
#     cutter   423 px long      barge   392 px      skiff  260 px      tender  211 px
#
# So: one budget for the fleet, at the tier the closest of them earns. A base
# colour at 1024 over a 423-px hull is about 1.9 texels per pixel — comfortable;
# at 512 it would be 0.93, which is soft on the one ship the player looks at.
# Uniform rather than per-ship on purpose: the arrival ship (see the board) will
# hold station at the bow, much closer than any of these, and whichever hull is
# picked for it must already be good enough to come forward.
BUDGET = {"base_color": 1024, "normal": 512, "metallic_roughness": 256,
          "emission": 256}

# --- WHY NOTHING IS DECIMATED -------------------------------------------------
# `meshy.tri_budget` is `0.021 * px^2` between a 3,000 floor and an 8,000 ceiling,
# and at the measured sizes above it asks for 3,757 (cutter), 3,227 (barge) and
# the floor for the other two. Every ship arrived at ~10,200 — a little over 3x —
# and these are rigid props with no skin weights, which is exactly the condition
# that makes local decimation a free and standing decision elsewhere in this
# repo (board SG-13; the boss went 1.37M -> 8k). So it was written, and run at
# 3,500, and the four hulls came back as clouds of loose brass shards.
# `.shots/skyships/decimated-3500-shredded-*.png` is what that looks like, kept
# because a paragraph does not.
#
# THE FIRST DIAGNOSIS WAS WRONG and cost a second run: the UV correspondence
# looked like the suspect, it was rebuilt out of `fast_simplification`'s collapse
# history the way `tools/segment_parts.py::decimate_with_uv` does it, and the
# hulls shredded identically. So it was measured instead of guessed at again:
#
#     the cutter, as delivered:   10,258 triangles
#                                 20,401 INDEXED vertices
#                                  5,125 distinct POSITIONS  (25.1%)
#                                 91.7% of its edges are used by ONE triangle
#     the same mesh welded by position:  0.0% boundary edges
#
# The delivered topology is not a surface, it is ten thousand triangles that
# happen to touch. Meshy splits a vertex at every atlas seam and this atlas is
# seams; a quadric decimator joins nothing across a boundary edge, so with 92% of
# them boundary it cannot COLLAPSE anything and can only DELETE — which is a hole,
# and ten thousand of them is the frame above.
#
# Buying the reduction honestly means weld -> simplify -> re-split at the seams,
# and that is real machinery guarding a real risk (a seam smeared across the
# atlas is the harlequin failure one step removed) for a prize this file does not
# need. `tools/meshy.py` already said so out loud: "once the maps are 512 instead
# of 2048, geometry is about 0.1 MB of a 0.3 MB prop ... triangles stopped being
# the expensive thing." The texture pass takes 235 MB to 4.9 MB. The four placed
# ships carry 41,000 triangles between them, in the far field, never skinned and
# never animated. That is the cheaper mistake by a wide margin, and if triangles
# ever do become the expensive thing the paragraph above is the recipe.

# key -> (textured export, segmentation twin or None)
FLEET = {
    "skyship_skiff": (
        "Meshy_AI_Copper_Cloud_Voyager_0803033101_texture.glb",
        "Meshy_AI_Copper Cloud Voyager_1785727050_part-segmentation.glb"),
    "skyship_barge": (
        "Meshy_AI_Brass_Leviathan_0803032244_texture.glb",
        "Meshy_AI_Brass Leviathan_1785727188_part-segmentation.glb"),
    "skyship_cutter": (
        "Meshy_AI_Gilded_Leviathan_0803032741_texture.glb",
        "Meshy_AI_Gilded Leviathan_1785727502_part-segmentation.glb"),
    "skyship_tender": (
        "Meshy_AI_The_Iron_Zephyr_0803032809_texture.glb", None),
    "skyship_barge_heavy": (
        "Meshy_AI_The_Brass_Leviathan_0803032304_texture.glb",
        "Meshy_AI_The Brass Leviathan_1785727208_part-segmentation.glb"),
}

# key -> which masses to cut out, and nothing else gets cut.
#
#   "rotors"   the four lifting rotors in their brass ring mounts, one per
#              corner of the barge's outriggers. Each becomes its own node with
#              its own centroid as origin, so `rotation.y += w * delta` turns the
#              blades about the hub instead of swinging them round the hull —
#              which is the bug `tools/split_rotors.py` was written to avoid.
#   "envelope" the skiff's gas bag, which rides ABOVE the hull on iron struts and
#              is the one mass on this fleet a slow vertical bob belongs on.
#
# THE CUTTER IS DELIBERATELY ABSENT and it has a segmentation twin. Its envelope
# is swept tight to the hull under brass strapping — the prompt asked for exactly
# that — and a mass that is strapped down does not bob. Splitting it would buy a
# seam and a temptation.
MASSES = {
    "skyship_barge": ["rotors"],
    "skyship_skiff": ["envelope"],
}


# --- finding the masses, by measurement --------------------------------------
# NOTHING HERE IS INDEXED BY `GLTF_n`, for the reason `tools/split_rotors.py`
# gives at length: the segmentation numbers its geometries in whatever order it
# pleases and a hard-coded index survives exactly one re-export. Each rule below
# names a property the mass HAS and nothing else on the ship does, and the count
# it must return is asserted.

def find_rotors(parts: list[dict]) -> list[int]:
    """A lifting rotor is a HORIZONTAL DISC AT A CORNER.

    Three properties together, and no other part of a barge has all three: its
    plan footprint is round (x and z within a third of each other), it is thin
    through the axis it turns about (y well under its own diameter), and it sits
    OUT at a corner of the hull rather than along the centreline — which is what
    "four heavy lifting rotors in brass ring mounts on outriggers" means.

    "OUT" IS MEASURED AGAINST THE SHIP'S OWN BOX, and the first version of this
    rule was not: it tested `abs(cz - 0.5)`, as if the normalised model filled
    the unit cube. The normalisation is UNIFORM — it has to be, or the shape
    tests above are measuring a stretch — so a barge half as wide as it is long
    occupies z in 0..0.495 and its centreline is at 0.247, not 0.5. Two of the
    four rotors read as amidships and the run stopped, which is the assert
    below doing its job.
    """
    lo = np.min([p["centre"] - p["size"] / 2 for p in parts], axis=0)
    hi = np.max([p["centre"] + p["size"] / 2 for p in parts], axis=0)
    mid, extent = (lo + hi) / 2, hi - lo
    out = []
    for i, p in enumerate(parts):
        sx, sy, sz = p["size"]
        c = p["centre"]
        disc = abs(sx - sz) < 0.35 * max(sx, sz)
        thin = sy < 0.75 * max(sx, sz)
        corner = (abs(c[0] - mid[0]) > 0.25 * extent[0]
                  and abs(c[2] - mid[2]) > 0.25 * extent[2])
        big = 0.05 < max(sx, sz) < 0.35
        if disc and thin and corner and big:
            out.append(i)
    return out


def find_envelope(parts: list[dict]) -> list[int]:
    """The gas bag is the HIGHEST LONG MASS.

    Height alone would pick a stack crown or a mast finial, and length alone
    would pick the hull. The bag is the only part that is both — at least a
    third of the ship long, and centred higher than anything else on it.
    """
    long_ones = [i for i, p in enumerate(parts) if p["size"][0] > 0.30]
    if not long_ones:
        return []
    top = max(long_ones, key=lambda i: parts[i]["centre"][1])
    ## and it must genuinely stand clear of the next-highest, or it is the hull
    ## of a ship that has no bag and this rule has found nothing.
    rest = [parts[i]["centre"][1] for i in long_ones if i != top]
    if rest and parts[top]["centre"][1] - max(rest) < 0.05:
        return []
    return [top]


FINDERS = {"rotors": (find_rotors, 4), "envelope": (find_envelope, 1)}


def describe(js: dict, blob: bytes) -> list[dict]:
    """Every segmentation part, in the model's own UNIFORMLY normalised box.

    Uniform, not per-axis: a per-axis normalisation stretches a shallow hull's z
    by two and a half and quietly biases every shape test above — the same trap
    `split_rotors.unit_box` names.
    """
    raw = [accessor(js, blob, m["primitives"][0]["attributes"]["POSITION"]).astype(np.float64)
           for m in js["meshes"]]
    stacked = np.concatenate(raw)
    lo = stacked.min(0)
    span = float((stacked.max(0) - lo).max())
    parts = []
    for i, pts in enumerate(raw):
        n = (pts - lo) / span
        parts.append({"index": i, "points": n,
                      "centre": (n.min(0) + n.max(0)) / 2,
                      "size": n.max(0) - n.min(0)})
    return parts


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("only", nargs="?", default="")
    ap.add_argument("--measure", action="store_true",
                    help="report and write nothing")
    args = ap.parse_args()

    ORIGINALS.mkdir(parents=True, exist_ok=True)
    keys = [k for k in FLEET if not args.only or k.endswith(args.only)]
    if not keys:
        raise SystemExit("no ship called %r. one of: %s"
                         % (args.only, ", ".join(FLEET)))

    for key in keys:
        tex_name, seg_name = FLEET[key]
        source = DOWNLOADS / tex_name
        if not source.exists():
            source = ORIGINALS / tex_name
        if not source.exists():
            raise SystemExit("missing textured export: %s" % tex_name)

        print("\n%s   <- %s" % (key, tex_name))
        for name in filter(None, (tex_name, seg_name)):
            src = DOWNLOADS / name
            if src.exists() and not (ORIGINALS / name).exists():
                shutil.copy2(src, ORIGINALS / name)

        out_dir = OUT_ROOT / key
        out_dir.mkdir(parents=True, exist_ok=True)
        dest = out_dir / (key + ".glb")
        work = dest.with_suffix(".work.glb")
        shutil.copy2(source, work)

        before = work.stat().st_size
        was_tris = _tris(work)
        _, _ = meshy.shrink_glb(work, BUDGET)

        wanted = MASSES.get(key, [])
        cut: list[str] = []
        if wanted:
            seg = ORIGINALS / seg_name if seg_name else None
            cut = split_masses(work, seg, wanted, dry=args.measure)

        after_tris = _tris(work)
        if args.measure:
            work.unlink()
            continue
        work.replace(dest)
        print("    %-14s %6.1f MB -> %5.2f MB   %6d -> %5d tris   masses: %s"
              % ("RESULT", before / 1e6, dest.stat().st_size / 1e6,
                 was_tris, after_tris, ", ".join(cut) if cut else "(none split)"))
    return 0


def _tris(path: Path) -> int:
    js, _ = glb_read(path)
    return sum(js["accessors"][p["indices"]]["count"] // 3
               for m in js["meshes"] for p in m["primitives"])


def split_masses(path: Path, seg: Path | None, wanted: list[str],
                 dry: bool = False) -> list[str]:
    """Cut the named masses out of the textured mesh, using the segmentation as a
    LABEL SOURCE and then discarding it. Returns the node names written."""
    from scipy.spatial import cKDTree

    if seg is None or not seg.exists():
        print("    no segmentation twin -- nothing split")
        return []

    sjs, sblob = glb_read(seg)
    parts = describe(sjs, sblob)

    picked: dict[str, list[int]] = {}
    for mass in wanted:
        finder, expect = FINDERS[mass]
        found = finder(parts)
        if len(found) != expect:
            raise SystemExit(
                "%s: the %s rule matched %d parts, expected %d. The rule is a "
                "measurement and a re-export may have changed the shape it "
                "measures -- read tools/skyships.py rather than editing this "
                "number." % (seg.name, mass, len(found), expect))
        picked[mass] = found
        for i in found:
            print("    %-9s part %-3d centre=%s size=%s"
                  % (mass, i,
                     np.array2string(parts[i]["centre"], precision=3),
                     np.array2string(parts[i]["size"], precision=3)))

    js, blob = glb_read(path)
    prim = js["meshes"][0]["primitives"][0]
    pos = accessor(js, blob, prim["attributes"]["POSITION"]).astype(np.float64)

    ## THE FRAMES MUST AGREE BEFORE A LABEL MAY CROSS BETWEEN THEM. The
    ## segmentation is KHR_mesh_quantization in a 0..16383 box and the textured
    ## mesh is metres about the origin; their AABB RATIOS are the check that they
    ## are the same object in the same orientation, and it is asserted rather
    ## than assumed because a re-export that flipped an axis would weld the
    ## rotors to the stacks and nobody would see it until something spun.
    seg_all = np.concatenate([p["points"] for p in parts])
    tex_lo, tex_span = pos.min(0), pos.max(0) - pos.min(0)
    tex_n = (pos - tex_lo) / float(tex_span.max())
    a = seg_all.max(0) - seg_all.min(0)
    b = tex_n.max(0) - tex_n.min(0)
    if np.max(np.abs(a - b)) > 0.02:
        raise SystemExit("the two exports are not the same object in the same "
                         "orientation: segmentation extent %s vs textured %s"
                         % (np.array2string(a, precision=3),
                            np.array2string(b, precision=3)))
    print("    frames agree   seg %s  ~  tex %s"
          % (np.array2string(a, precision=3), np.array2string(b, precision=3)))

    ## Transfer. Every textured vertex takes the label of the nearest
    ## segmentation vertex; only the masses we asked for keep theirs.
    labels = np.concatenate([np.full(len(p["points"]), p["index"])
                             for p in parts])
    nearest = cKDTree(seg_all).query(tex_n, k=1)[1]
    vert_part = labels[nearest]

    groups: dict[str, np.ndarray] = {}
    for mass, indices in picked.items():
        member = np.isin(vert_part, indices)
        if mass == "rotors":
            ## Four rotors, four nodes — one part index each, and each keeps its
            ## OWN centroid as its origin so it turns about its hub.
            for n, idx in enumerate(sorted(
                    indices, key=lambda i: (parts[i]["centre"][0],
                                            parts[i]["centre"][2]))):
                groups["Rotor%d" % (n + 1)] = np.isin(vert_part, [idx])
        else:
            groups["Envelope"] = member

    if dry:
        for name, mask in groups.items():
            print("    %-9s %d vertices" % (name, int(mask.sum())))
        return list(groups)

    _write_split(path, js, blob, prim, pos, groups)
    return list(groups)


def _write_split(path: Path, js: dict, blob: bytes, prim: dict,
                 pos: np.ndarray, groups: dict[str, np.ndarray]) -> None:
    """Rebuild the GLB as `Body` plus one mesh per named mass.

    A triangle belongs to a mass only if ALL THREE of its vertices do — a face
    straddling the boundary is hull, not rotor, which keeps the seam on the hull
    side and never punches a hole through it.
    """
    tris = accessor(js, blob, prim["indices"]).reshape(-1, 3).astype(np.int64)
    owner = np.zeros(len(tris), dtype=np.int64)          # 0 = Body
    for n, (_name, mask) in enumerate(groups.items(), start=1):
        owner[mask[tris].all(1)] = n

    blob = bytearray(blob)
    views, accs = js["bufferViews"], js["accessors"]
    meshes, nodes = [], []
    for n, name in enumerate(["Body"] + list(groups)):
        ids = np.flatnonzero(owner == n)
        if len(ids) == 0:
            continue
        used = np.unique(tris[ids])
        remap = np.zeros(len(pos), dtype=np.int64)
        remap[used] = np.arange(len(used))
        local = remap[tris[ids]]
        p = pos[used]
        pivot = (p.min(0) + p.max(0)) / 2 if name != "Body" else np.zeros(3)
        attrs = {}
        for key, src in prim["attributes"].items():
            data = accessor(js, bytes(blob), src)[used].copy()
            if key == "POSITION":
                data = (data.astype(np.float64) - pivot).astype(np.float32)
            attrs[key] = _append(blob, views, accs, data,
                                 accs[src]["type"], accs[src]["componentType"],
                                 minmax=(key == "POSITION"))
        narrow = len(used) < 65536
        ind = _append(blob, views, accs,
                      local.reshape(-1, 1).astype(np.uint16 if narrow else np.uint32),
                      "SCALAR", 5123 if narrow else 5125, target=34963)
        meshes.append({"name": name, "primitives": [{
            "attributes": attrs, "indices": ind,
            "material": prim.get("material", 0)}]})
        node = {"name": name, "mesh": len(meshes) - 1}
        if name != "Body":
            node["translation"] = [float(v) for v in pivot]
        nodes.append(node)
        print("    cut %-9s %6d tris" % (name, len(ids)))

    js["meshes"] = meshes
    js["nodes"] = nodes
    js["scenes"] = [{"nodes": list(range(len(nodes)))}]
    js["scene"] = 0
    _compact(js, blob, path)


def _compact(js: dict, blob: bytearray, path: Path) -> None:
    """Drop every buffer view no accessor or image names, then renumber.

    Without this the replaced position/normal/UV/index views are still in the
    file with nothing pointing at them — most of a megabyte in a file whose whole
    budget argument is that geometry is the cheap half.
    """
    live: dict[int, int] = {}
    for mesh in js["meshes"]:
        p = mesh["primitives"][0]
        for key in list(p["attributes"]):
            p["attributes"][key] = live.setdefault(p["attributes"][key], len(live))
        p["indices"] = live.setdefault(p["indices"], len(live))
    accs = [js["accessors"][old] for old in sorted(live, key=lambda o: live[o])]
    js["accessors"] = accs

    views = js["bufferViews"]
    wanted: dict[int, int | None] = {}
    for acc in accs:
        if acc.get("bufferView") is not None:
            wanted[acc["bufferView"]] = None
    for img in js.get("images", []):
        if img.get("bufferView") is not None:
            wanted[img["bufferView"]] = None
    packed, keep = bytearray(), []
    for old in sorted(wanted):
        view = dict(views[old])
        start = view.get("byteOffset", 0)
        raw = bytes(blob[start:start + view["byteLength"]])
        while len(packed) % 4:
            packed.append(0)
        view["byteOffset"] = len(packed)
        packed += raw
        wanted[old] = len(keep)
        keep.append(view)
    for acc in accs:
        if acc.get("bufferView") is not None:
            acc["bufferView"] = wanted[acc["bufferView"]]
    for img in js.get("images", []):
        if img.get("bufferView") is not None:
            img["bufferView"] = wanted[img["bufferView"]]
    js["bufferViews"] = keep
    js["buffers"] = [{"byteLength": len(packed)}]
    glb_write(path, js, bytes(packed))


def _append(blob: bytearray, views: list, accs: list, data: np.ndarray,
            kind: str, component: int, target: int | None = None,
            minmax: bool = False) -> int:
    while len(blob) % 4:
        blob.append(0)
    offset = len(blob)
    raw = np.ascontiguousarray(data).tobytes()
    blob += raw
    view = {"buffer": 0, "byteOffset": offset, "byteLength": len(raw)}
    if target is not None:
        view["target"] = target
    views.append(view)
    acc = {"bufferView": len(views) - 1, "componentType": component,
           "count": len(data), "type": kind}
    if minmax:
        acc["min"] = [float(v) for v in data.min(0)]
        acc["max"] = [float(v) for v in data.max(0)]
    accs.append(acc)
    return len(accs) - 1


if __name__ == "__main__":
    sys.exit(main())
