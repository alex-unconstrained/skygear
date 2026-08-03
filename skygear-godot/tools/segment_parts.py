"""Split a Meshy PART-SEGMENTATION export into a named, budgeted parts kit.

    python tools/segment_parts.py boss "<segmentation glb>" ["<textured glb>"]

WHY THIS TOOL EXISTS. Every other figure on this deck is a SKINNED mesh: one
surface, one skeleton, weights that bend it. The Colossus is not, and that was
the owner's call:

    "I feel like if we just do simple segmented movement it might work well for
    the boss. It's not exactly a humanoid model, and it doesnt move that much,
    and its death animation could be the parts just falling apart."

He is right about the material. A riveted siege machine has no flesh to bend —
`tools/rig_local.gd` already argued that a rigid bind is "the honest material on
a riveted machine" and paid for it with candy-wrapper elbows it did not want.
A model delivered as SEPARATE GEOMETRIES needs no bind at all: each part is a
node, each joint is that node's origin, and a hinge is a rotation. The death the
owner asked for falls straight out of it — the parts are already apart.

THREE THINGS THE DELIVERED FILE IS, THAT A READER WOULD NOT GUESS:

  1. **It is 1.37 MILLION triangles** across 13 geometries, against a project law
     (`0.021 x px^2`, tools/meshy.py) that puts a 330-unit figure at 8,000. That
     is 171x over. There are NO SKIN WEIGHTS to preserve here, which is exactly
     why local decimation is safe: the thing that makes decimating the captain a
     standing decision (board SG-13) is that her weights ride her vertices. A
     rigid part carries nothing but its own surface.

  2. **It has no UVs and no texture images.** The part-segmentation endpoint
     returns a VISUALISATION: every part flat-filled with a categorical label
     colour out of a plotting palette — yellow, purple, green, blue, pink. Ship
     it as delivered and the deck gets a harlequin. The colours are DATA, not
     material, and this tool reads them as data (see `label_agrees`) and then
     throws them away — for the project palette when that is all there is, and
     for the owner's own paint when the TEXTURED TWIN is supplied (see below).

  3. **The label colours CORROBORATE the symmetry, and cannot establish it.**
     Meshy gives both halves of a pair the same label, so a pairing measured off
     mirrored geometry can be checked against something that is not geometry at
     all — and all five pairs agree. But thirteen parts are labelled out of a
     ten-colour palette, so the fists and the feet come back the same yellow:
     a label is not unique to a pair. The measurement leads and the colour
     confirms, which is why the part map below is derived and not typed.

NOTHING HERE IS INDEXED BY `GLTF_n`. The names come off the measurements — a
centred part is a spine part, an outboard chain is an arm, the lowest pair is
feet — so the same rules survive a re-export that renumbers the geometries,
which is the failure mode a hardcoded index has and a measurement does not.

THE MARRIAGE — the third argument, and what it is for.
=======================================================
The segmentation is a shape with no skin. The owner also has the TEXTURED twin
of the same sculpt: one welded surface, real UVs, and four painted maps. Neither
file is shippable alone — the first has the parts and no paint, the second has
the paint and no parts — and the boss shipped from the first, which is exactly
what "not sure what's going on with his texture" was looking at: flat untextured
geometry with the furnace lamp glowing inside it.

Pass both and the parts are cut FROM THE TEXTURED MESH, with the segmentation
demoted to what it is actually good for: a label source. This is the trick
`tools/split_rotors.py` plays on the gunner drone, in the same direction and for
the same reason, and the three things that make it sound here are MEASURED, not
assumed:

  * **The two exports are the same object in the same orientation.** Their axis
    ratios agree to 0.00002 (`[0.9424, 1.0, 0.644]` both ways). Asserted in
    `marry`, because a re-export that flipped an axis would weld the head to a
    foot and nothing downstream would notice.

  * **They are NOT the same topology, so nothing can simply be assigned.**
    1,318,962 textured triangles against 1,366,036 segmented ones; 696,655
    vertices against 682,804. That measurement is what rules out the cheap
    answer (hand the existing split the other file's material) and it is why the
    labels are transferred by NEAREST SURFACE rather than by index. The transfer
    is tight: the median textured triangle sits 0.00074 of the model's longest
    axis from the segmentation vertex that labels it — under 2.5 mm at the drawn
    height — and the worst sits at 0.0093, which is a plate's thickness.

  * **The transfer is proportionate.** Every one of the thirteen parts comes
    back with 96-98% of the triangle count its segmented twin had, tracking the
    two files' overall 96.5% ratio. A part being robbed by its neighbour would
    show up here as a pair that does not.

WHY THE SEAMS SURVIVE THE DECIMATION, which is the one thing that could quietly
ruin this. 5.4% of the textured mesh's vertices (37,446 of 696,655) are SEAM
DUPLICATES — one position carrying two UVs where the map is cut. In glTF those
are separate indices, so the face graph is already disconnected across every
seam, and an edge collapse cannot merge across one. The decimator therefore
never invents a triangle that straddles the map. What it does need is the UV of
each surviving vertex, and that comes out of `fast_simplification`'s own collapse
history (`replay_simplification` -> input-vertex -> output-vertex map) rather
than out of a nearest-neighbour guess: every output vertex inherits from an
input vertex it actually descends from, on its own side of the seam. Normals ride
across the same map, so the decimated part keeps the sculpt's shading intent
instead of the faceting a recompute would give it.

Doing it the other way round — transferring UVs onto the parts already cut from
the segmentation — was the cheaper option and is the wrong one for exactly this
reason: those parts were decimated by a pass that had never seen a UV, so their
vertices sit wherever quadric error put them and a triangle straddling a seam is
not merely possible but likely.

THE MAPS ARE SHRUNK BY THE PROJECT'S OWN LAW and not by a number invented here:
`tools/meshy.py`'s `shrink_glb`, the same function that took the boarding hulk
from 142 MB to 2.3 MB with its geometry untouched. A 330-unit figure renders at
616 px, which is over `TEX_FULL_ABOVE_PX`, so it earns a full 1024 base colour,
a 512 normal and 256 metallic-roughness and emission.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
import trimesh

ROOT = Path(__file__).resolve().parent.parent

# The project law, restated from tools/meshy.py rather than imported, because
# that module reaches for an API key at import time.
#
# THIS WAS 8000 UNTIL SG-155, AND 8000 WAS A NUMBER ABOUT A DIFFERENT FILE.
# It was what the previous prompted Colossus shipped at (assets/models/boss/
# meshy.json: "remeshed": {"tris": 8000}), and it was the right budget for the
# delivery it was written against: a 1,318,962-triangle textured twin, where
# reaching 8000 meant 165:1 and the surfaces were dense enough to survive it.
#
# THE DELIVERY CHANGED AND THE RATIO INVERTED. The textured twin now shipping
# is 30,606 triangles — already a game budget, already optimised. Holding it to
# 8000 is no longer a 165:1 cut of a dense mesh, it is a 4:1 cut of a sparse
# one, and on riveted plating built out of thin separate shells that does not
# thin the surface, it TEARS it. Measured at the shipped camera, same inputs,
# frames in `.shots/sg155/`:
#
#   ceiling  8000   25.7% kept   shattered — the silhouette is gone
#   ceiling 16000   51.8% kept   still torn, holes through the plating
#   ceiling 30000   93.2% kept   clean; the paint reads
#
# So the cut is not a dial to tune, it is a cliff, and the only side of it the
# machine survives on is the one that barely cuts at all.
#
# WHY 30000 IS NOT AN INDULGENCE, which is the owner's call (2026-08-03) and
# the argument he made it on: the kit lands at 28,512, and THE CAPTAIN IS
# 30,634 (the harness prints both). She is on screen every second of every run;
# the Colossus arrives once, at wave 12. A boss that costs less than the figure
# standing next to him all game is not the thing to spend the budget law on.
TRI_CEIL = 30000

# No part may fall below this. Area alone would spend nearly everything on the
# torso and leave the head — the part a player reads the machine's FACING from —
# as a lump. Same argument tools/meshy.py's TRI_FLOOR makes for whole props:
# what breaks at the bottom is features, and area has nothing to say about them.
TRI_PART_FLOOR = 220

# How far the two exports' axis ratios may disagree and still be believed to be
# the same object in the same orientation. Lifted from tools/split_rotors.py,
# which makes the same assertion for the same reason; the measured disagreement
# here is 0.00002, so this is three orders of margin and not a fudge.
AXIS_RATIO_TOLERANCE = 0.02

# THE METALLIC CEILING FOR THIS DECK — imported, not restated.
#
# It lived here as a number inside PALETTE, and that is precisely how it got
# missed: SG-90 learned from a rendered frame that this lamp-lit deck turns a
# metallic surface into a hole in the planking, wrote the conclusion into the
# only path that existed, and then SG-94 added the painted path below and handed
# Meshy's material straight through. An audit since found the same omission in
# `tools/skyships.py` and in every glb in `assets/models/` — Meshy ships NO
# metallicFactor at all, which glTF reads as 1.0.
#
# So the number and its reason now live in `tools/lamplit.py`, above every path
# that could miss them, and this file is one of its readers rather than its
# owner. Run `python tools/lamplit.py audit` for the measurement.
sys.path.insert(0, str(Path(__file__).resolve().parent))
from lamplit import (LAMPLIT_METALLIC_MAX, check_palette,  # noqa: E402
                     clamp_metallic)

# THE PALETTE, by role, out of DESIGN's own list — blackened steel, riveted warm
# brass, oxblood leather, oxidised copper, and sampled against the colours the
# PREVIOUS Colossus already wears on this deck (its albedo quantises to #211b1f
# plate, #7a4410/#886123/#bb8b33 brass, #3f3835 steel). Flat albedo, broad
# areas, no baked light — the handoff-3d rule for anything that renders a few
# hundred pixels tall.
#
# Assigned by ROLE so the machine reads as built rather than painted: the mass
# is dark plate, the moving limbs are brass, the feet are near-black iron, and
# the head is the brightest thing on it so the facing is legible at 616 px.
#
# THE FIRST PALETTE WAS TWO STOPS TOO DARK AND HALF OF THAT WAS THE METALLIC.
# Written against the sampled albedo alone it looked right in a colour picker and
# rendered as a black silhouette on the deck (.shots/clips/boss frame 30, first
# pass) — because this deck is LIT BY LAMPS, and a high-metallic surface with
# almost no environment to reflect has nothing to return. Metal in a dark scene
# is dark; that is physically correct and dramatically useless. So the metallic
# comes down to a third, the roughness stays high, and the albedo is lifted
# until the machine reads as blackened steel rather than as a hole in the deck.
# Judged from a rendered frame, which is the only place this is visible at all.
PALETTE = {
    "torso":    ("4e443d", 0.22, 0.62),   # hex, metallic, roughness
    "back":     ("a8762f", 0.30, 0.45),
    "head":     ("d19a3c", 0.34, 0.36),
    "shoulder": ("60554c", 0.24, 0.55),
    "arm":      ("ad8034", 0.30, 0.47),
    "fist":     ("453b34", 0.26, 0.52),
    "leg":      ("594d44", 0.22, 0.58),
    "foot":     ("342d29", 0.24, 0.64),
}

# The flat path's half of the ceiling, asserted at import so it cannot drift.
# Editing a PALETTE row up past the ceiling is exactly the edit that would
# reintroduce SG-90's black silhouette, and it now fails before anything renders.
check_palette(PALETTE, "segment_parts.PALETTE")


# What the figure is DRAWN at, and it is not a number this file invented:
# scripts/view3d.gd's `boarder_height("BOSS")` is (120 + radius*3) with no
# FIGURE_SCALE row = 330 ground units, WORLD_SCALE 0.01 puts that at 3.30 m,
# and assets/models/boss/meshy.json already records "screen_units": 330.0 for
# the prompted Colossus this kit replaces. The glb is written AT that height so
# the file is self-describing; the renderer re-measures and re-scales anyway
# (SG-45: measure, do not assume), and agreeing with it costs nothing.
DRAWN_METRES = 3.30

# The same height in the units tools/meshy.py's texture law is written in, which
# is GROUND units — it multiplies by its own PX_PER_UNIT to get the 616 px this
# file's palette note already cites. Kept beside DRAWN_METRES so the two cannot
# drift apart: they are one measurement in two units.
DRAWN_SCREEN_UNITS = 330.0


def _measure(scene: trimesh.Scene) -> list[dict]:
    """Every geometry in the SCENE's frame, with the numbers the names come from.

    The delivered file carries one shared node transform (a uniform 7e-06 scale
    and a translation) on all thirteen meshes, so the geometry arrives in the
    thousands and the scene reads 0.12 tall. Baking the transform in here is the
    whole of the unit-scale handling, and it is done by MEASURING the result
    rather than by trusting the number in the file.
    """
    out = []
    for node in sorted(scene.graph.nodes_geometry):
        transform, geom_name = scene.graph[node]
        mesh = scene.geometry[geom_name].copy()
        mesh.apply_transform(transform)
        low, high = mesh.bounds
        label = np.asarray(
            scene.geometry[geom_name].visual.material.baseColorFactor[:3], dtype=int)
        out.append({
            "source": geom_name,
            "mesh": mesh,
            "faces_in": int(len(mesh.faces)),
            "min": low, "max": high,
            "centre": (low + high) / 2.0,
            "size": high - low,
            "area": float(mesh.area),
            "volume": float(abs(mesh.volume)),
            "label": label,
        })
    return out


def _unit_box(points: np.ndarray) -> np.ndarray:
    """Into the model's own bounding box at UNIFORM scale — the only frame in
    which a quantised segmentation and a metric mesh can be compared, and the
    only one in which the comparison does not distort shape. Same normalisation
    tools/split_rotors.py uses, and for the same pair of files."""
    lo, hi = points.min(0), points.max(0)
    return (points - lo) / max(float((hi - lo).max()), 1e-9)


def marry(parts: list[dict], textured: Path) -> tuple[list[dict], object]:
    """Re-cut the parts out of the TEXTURED twin, using the segmentation only as
    a label source. Returns the re-measured parts and the shared material.

    Every measurement the rest of this file makes — the classification, the
    pivots, the area budget, the local boxes the death solve reads — is taken
    off the surface that actually ships, which after this call is the painted
    one. What survives from the segmentation is precisely two things per part:
    its NAME (via the geometry the labels came from) and its LABEL COLOUR (which
    only ever corroborated the symmetry).
    """
    scene = trimesh.load(textured, process=False)
    geoms = [scene.geometry[name] for name in sorted(scene.geometry)]
    if len(geoms) != 1:
        raise SystemExit("the textured twin should be one welded surface, "
                         "found %d geometries" % len(geoms))
    src = geoms[0]
    node = sorted(scene.graph.nodes_geometry)[0]
    transform, _ = scene.graph[node]
    pos = trimesh.transform_points(np.asarray(src.vertices, dtype=np.float64),
                                   transform)
    faces = np.asarray(src.faces, dtype=np.int64)
    uv = np.asarray(src.visual.uv, dtype=np.float64)
    normals = np.asarray(src.vertex_normals, dtype=np.float64)

    seg_pts = np.concatenate([p["mesh"].vertices for p in parts])
    seg_lab = np.concatenate([np.full(len(p["mesh"].vertices), i, dtype=np.int32)
                              for i, p in enumerate(parts)])

    ## THE ONE ASSERTION THAT MATTERS: same object, same orientation. Compared
    ## as ratios to the longest axis, because the two files are in different
    ## units and only their proportions can agree. Asserted rather than assumed
    ## — a re-export that flipped an axis would weld the head to a foot and
    ## every check downstream would still pass.
    seg_span = seg_pts.max(0) - seg_pts.min(0)
    tex_span = pos.max(0) - pos.min(0)
    ratio_seg, ratio_tex = seg_span / seg_span.max(), tex_span / tex_span.max()
    drift = float(np.abs(ratio_seg - ratio_tex).max())
    print("textured  %d verts  %d tris  %d maps" % (
        len(pos), len(faces),
        sum(1 for s in ("baseColorTexture", "metallicRoughnessTexture",
                        "normalTexture", "emissiveTexture")
            if getattr(src.visual.material, s, None) is not None)))
    print("axis ratios: segmentation %s vs textured %s (drift %.5f)" % (
        np.round(ratio_seg, 4), np.round(ratio_tex, 4), drift))
    if drift > AXIS_RATIO_TOLERANCE:
        raise SystemExit("the two exports are not the same object in the same "
                         "orientation — axis ratios disagree by %.4f" % drift)

    ## Label every textured triangle by the segmentation vertex nearest its
    ## centroid, both files normalised into their own unit box first.
    from scipy.spatial import cKDTree
    tree = cKDTree(_unit_box(seg_pts))
    centroid = _unit_box(pos)[faces].mean(axis=1)
    dist, near = tree.query(centroid, k=1, workers=-1)
    tri_part = seg_lab[near]
    print("label transfer: %d triangles, nearest segmentation vertex at "
          "median %.5f / p99 %.5f / max %.5f of the longest axis" % (
              len(faces), np.median(dist), np.percentile(dist, 99), dist.max()))

    for i, p in enumerate(parts):
        pick = np.where(tri_part == i)[0]
        if len(pick) == 0:
            raise SystemExit("part %s claimed no textured triangles — the "
                             "label transfer is wrong" % p["source"])
        used = np.unique(faces[pick])
        remap = np.full(len(pos), -1, dtype=np.int64)
        remap[used] = np.arange(len(used))
        mesh = trimesh.Trimesh(vertices=pos[used], faces=remap[faces[pick]],
                               process=False)
        low, high = mesh.bounds
        ## The proportion check: a part robbed by its neighbour shows up as a
        ## share of the textured mesh that does not track its share of the
        ## segmented one. Reported per part in `main`.
        p["seg_faces_in"] = p["faces_in"]
        p["mesh"] = mesh
        p["uv"] = uv[used]
        p["normals"] = normals[used]
        p["faces_in"] = int(len(mesh.faces))
        p["min"], p["max"] = low, high
        p["centre"] = (low + high) / 2.0
        p["size"] = high - low
        p["area"] = float(mesh.area)
        p["volume"] = float(abs(mesh.volume))
    return parts, src.visual.material


# glTF map slot -> the role name tools/meshy.py's texture law is keyed by.
MAP_SLOTS = {
    "baseColorTexture": "base_color",
    "normalTexture": "normal",
    "metallicRoughnessTexture": "metallic_roughness",
    "emissiveTexture": "emission",
}


def resize_maps(material, sides: dict) -> None:
    """Bring every map down to its budgeted side, FROM THE DELIVERED PIXELS.

    This happens before the kit is written rather than only after, and the
    reason is one lossy stage instead of two. trimesh passes a JPEG through
    untouched and re-encodes anything else as PNG, so a map resized here lands
    in the intermediate file losslessly and `meshy.shrink_glb` then makes the
    single JPEG from the same pixels a one-pass downscale would have. Leaving
    the 4096s in place instead measured at 39.7 dB against that one-pass
    reference — not visible at 616 px, but it is free to not spend it.
    """
    from PIL import Image
    for slot, role in MAP_SLOTS.items():
        pic = getattr(material, slot, None)
        if pic is None:
            continue
        side = sides[role]
        if pic.width > side or pic.height > side:
            pic = pic.resize((min(side, pic.width), min(side, pic.height)),
                             Image.LANCZOS)
            setattr(material, slot, pic)


def decimate_with_uv(mesh: trimesh.Trimesh, uv: np.ndarray, normals: np.ndarray,
                     target: int) -> tuple[trimesh.Trimesh, np.ndarray, np.ndarray]:
    """Collapse to `target` triangles and carry the UVs and normals across.

    The correspondence is not guessed. `fast_simplification` hands back its
    COLLAPSE HISTORY, and replaying it yields an input-vertex -> output-vertex
    map; every surviving vertex therefore inherits from a vertex it actually
    descends from, and — because glTF has already split the mesh at every UV
    seam into separate indices that no edge joins — from its own side of the
    seam. Where several input vertices land on one output vertex the nearest of
    them wins, which is the one that moved least.
    """
    import fast_simplification

    v = np.asarray(mesh.vertices, dtype=np.float32)
    f = np.asarray(mesh.faces, dtype=np.int32)
    _pts, _faces, collapses = fast_simplification.simplify(
        v, f, target_count=int(target), return_collapses=True)
    out_v, out_f, mapping = fast_simplification.replay_simplification(
        v, f, collapses)
    out_v = np.asarray(out_v, dtype=np.float64)
    mapping = np.asarray(mapping, dtype=np.int64)

    ## One input vertex per output vertex — the nearest, chosen by sorting the
    ## inputs by (their output vertex, their distance to it) and keeping each
    ## group's first.
    moved = np.linalg.norm(np.asarray(mesh.vertices) - out_v[mapping], axis=1)
    order = np.lexsort((moved, mapping))
    first = np.ones(len(order), dtype=bool)
    first[1:] = mapping[order][1:] != mapping[order][:-1]
    pick = order[first]
    out_uv = np.zeros((len(out_v), 2))
    out_n = np.zeros((len(out_v), 3))
    out_uv[mapping[pick]] = uv[pick]
    out_n[mapping[pick]] = normals[pick]
    out = trimesh.Trimesh(vertices=out_v, faces=np.asarray(out_f),
                          process=False)
    return out, out_uv, out_n


# How far apart two segmentation labels may be and still count as the same
# label. Meshy writes the two halves of a pair a shade apart — (189,189,33)
# against (189,190,34) — so an equality test finds nothing.
LABEL_TOLERANCE = 4


def label_agrees(parts: list[dict]) -> bool:
    """Does every measured pair carry the same segmentation label?

    This CHECKS the pairing; it can never drive it. Two reasons, and the second
    only showed up on the real file:

      * a label is a colour someone chose and a mirrored centroid is a fact
        about the mesh, so the fact is the evidence and the colour is the
        corroboration;
      * **the palette reuses colours.** Thirteen parts are labelled out of a
        ten-colour plotting palette, so the fists (189,189,33) and the feet
        (190,190,34) are the same yellow to within a shade. A label is therefore
        not unique to a pair and cannot identify one on its own — but the two
        halves of a pair always share theirs, which is exactly the claim the
        measurement needs corroborated.
    """
    for p in parts:
        if p["role"] in ("torso", "back", "head"):
            continue
        twin = next((q for q in parts if q is not p and q["role"] == p["role"]), None)
        if twin is None:
            return False
        if int(np.abs(p["label"] - twin["label"]).max()) > LABEL_TOLERANCE:
            return False
    return True


## How far two parts' mirrored centroids and their sizes may disagree, as a
## fraction of the model's half-span in x, and still be believed to be the two
## halves of one pair. Measured on the owner's second delivery the five real
## pairs agree to better than 0.02 and the nearest non-pair is 0.4 away, so this
## sits in the empty middle of that gap rather than on either side of it.
MIRROR_TOLERANCE = 0.08


def _mirror_twin(p: dict, parts: list[dict], span_x: float):
    """The part on the other side of the machine, or None if it stands alone.

    A limb has one by construction and a spine part cannot have one, which is
    what makes this — and not a distance from the midline — the honest test for
    which of the two a part is. Compared in the model's own x half-span so the
    tolerance means the same thing whatever units the export arrives in.
    """
    if span_x <= 0.0:
        return None
    best, best_err = None, MIRROR_TOLERANCE
    for q in parts:
        if q is p:
            continue
        ## Mirrored centroid: same y and z, opposite x. A part straddling the
        ## midline would "pair" with itself, which is why `q is p` is excluded
        ## and why a part whose own box contains x=0 is rejected below.
        if p["min"][0] <= 0.0 <= p["max"][0]:
            return None
        if np.sign(p["centre"][0]) == np.sign(q["centre"][0]):
            continue
        err = float(np.abs(np.array([p["centre"][0] + q["centre"][0],
                                     p["centre"][1] - q["centre"][1],
                                     p["centre"][2] - q["centre"][2]])).max())
        err = max(err, float(np.abs(p["size"] - q["size"]).max()))
        if err / span_x < best_err:
            best, best_err = q, err / span_x
    return best


def _pair_up(lateral: list[dict], span_x: float) -> list[list[dict]]:
    """The lateral parts gathered into mirrored pairs, each pair once."""
    seen: set[int] = set()
    groups = []
    for p in lateral:
        if id(p) in seen:
            continue
        twin = _mirror_twin(p, lateral, span_x)
        if twin is None or id(twin) in seen:
            groups.append([p])
            seen.add(id(p))
            continue
        groups.append([p, twin])
        seen.update((id(p), id(twin)))
    return groups


def _cy(group: list[dict]) -> float:
    """The pair's shared height, averaged over both halves."""
    return float(np.mean([p["centre"][1] for p in group]))


def _cx(group: list[dict]) -> float:
    """The pair's shared distance outboard."""
    return float(np.mean([abs(p["centre"][0]) for p in group]))


def classify(parts: list[dict]) -> list[dict]:
    """Name every part from its position and size. The rules, in order:

    * A part whose centre sits on the model's midline is a SPINE part. There are
      three: the biggest by volume is the TORSO, the one set back behind the
      midline is the BACK stack, and what is left — small, high, and centred
      front-to-back — is the HEAD.
    * Everything else comes in mirrored pairs. The pairs standing OUTBOARD of
      the torso's shoulder line are the arm chain, and top to bottom they are
      SHOULDER, ARM, FIST. The pairs tucked inboard are the leg chain: LEG, then
      FOOT under it.
    * `+X is the figure's LEFT`, because it faces +Z with +Y up and left is
      up x forward. Getting this backwards mirrors the whole machine, and it is
      the one fact here that no measurement can tell you.
    """
    span_x = max(abs(p["centre"][0]) for p in parts)

    ## THE SPLIT IS THE PAIRING, NOT A FRACTION OF THE SPAN.
    ##
    ## This used to read `abs(centre[x]) < 0.15 * span_x` and demand exactly
    ## three survivors. That held for the FIRST segmentation and broke on the
    ## owner's second one, which decomposes the same sculpt differently: two
    ## parts straddle the midline instead of three, the back stack comes back as
    ## a mirrored PAIR sitting high and inboard, and one 78-triangle detail has
    ## no twin at all. The 0.15 was a number fitted to one delivery, and a
    ## re-export is exactly the thing this file's docstring promises to survive.
    ##
    ## So the question asked is the one that actually distinguishes a spine part
    ## from a limb: DOES IT HAVE A MIRROR TWIN? A limb does by construction, a
    ## spine part cannot. That is a fact about the machine rather than about how
    ## far from zero this particular export happened to put a centroid.
    lateral, spine = [], []
    for p in parts:
        twin = _mirror_twin(p, parts, span_x)
        (lateral if twin is not None else spine).append(p)
    if len(spine) < 2:
        raise SystemExit("expected at least 2 unpaired spine parts, measured %d"
                         % len(spine))

    ## Biggest by volume is the torso; of what is left the REARMOST is the back
    ## stack and the other is the head. Unchanged, and it still lands correctly
    ## on both deliveries.
    spine.sort(key=lambda p: -p["volume"])
    torso = spine[0]
    torso["role"] = "torso"
    rest = sorted(spine[1:], key=lambda p: p["centre"][2])
    if len(rest) == 1:
        rest[0]["role"] = "head"
    else:
        rest[0]["role"] = "back"
        for q in rest[1:]:
            q["role"] = "head"

    ## THE SHOULDERS ARE FOUND BY HEIGHT, NOT BY BEING OUTBOARD.
    ##
    ## The old rule read the arm chain off the OUTBOARD cluster and took its top
    ## member as the shoulder. On this sculpt the shoulder stacks sit INBOARD —
    ## they are bolted to the torso and the arms swing out past them — so an
    ## outboard-first rule names them arms and runs the whole chain one place
    ## down. What is actually true of a shoulder on any figure is that it is the
    ## only paired part sitting ABOVE the middle of the torso.
    pairs = _pair_up(lateral, span_x)
    above = [g for g in pairs if _cy(g) > torso["centre"][1]]
    for g in above:
        for p in g:
            p["role"] = "shoulder"
    hanging = [g for g in pairs if g not in above]

    ## What hangs below the torso splits into two chains in |x| — the empty band
    ## between the two clusters, measured, as before — and each chain is named
    ## top down. The arms are the OUTBOARD chain and the legs the inboard one,
    ## which is the reading that survives the shoulders having been taken out of
    ## the contest above.
    xs = sorted(abs(_cx(g)) for g in hanging)
    gaps = [(xs[i + 1] - xs[i], (xs[i + 1] + xs[i]) / 2) for i in range(len(xs) - 1)]
    split = max(gaps)[1] if gaps else 0.0
    arms = [g for g in hanging if abs(_cx(g)) >= split]
    legs = [g for g in hanging if abs(_cx(g)) < split]

    for chain, names in ((arms, ["arm", "fist"]), (legs, ["leg", "foot"])):
        # Top down by where the part STARTS, not where its centre is: a foot and
        # a shin overlap through most of their height and only their floors
        # separate them.
        ranked = sorted(chain, key=lambda g: -max(p["min"][1] for p in g))
        if len(ranked) > len(names):
            raise SystemExit("chain has %d pairs but only %s to name them"
                             % (len(ranked), names))
        for i, g in enumerate(ranked):
            for p in g:
                p["role"] = names[i]
    for p in parts:
        if p["role"] in ("torso", "back", "head"):
            p["name"] = p["role"]
        else:
            p["name"] = "%s_%s" % (p["role"], "l" if p["centre"][0] > 0 else "r")
    return parts


def pivot(p: dict) -> np.ndarray:
    """Where this part HINGES, in the scene frame — and, on the day it dies,
    where it breaks. One point per role, read off that part's own box:

      torso/back/head   the bottom of the part, on the midline: a waist, a stack
                        root, a neck.
      shoulder          inboard and high — the pauldron swings from the body,
                        not from its own middle.
      arm/fist/leg/foot the TOP of the part, which for a limb segment is the
                        joint it hangs from: shoulder, elbow, hip, ankle.
    """
    c, lo, hi, s = p["centre"], p["min"], p["max"], p["size"]
    role = p["role"]
    if role in ("torso", "back", "head"):
        ## On the midline when the part actually STRADDLES it, and on its own
        ## centre when it does not. The owner's second segmentation hands the
        ## back role to a small unpaired detail sitting off to one side; forcing
        ## its hinge to x=0 would put the joint outside the geometry it is
        ## supposed to swing, and the death solve reads these joints.
        x = 0.0 if lo[0] <= 0.0 <= hi[0] else c[0]
        return np.array([x, lo[1], c[2]])
    if role == "shoulder":
        inboard = np.sign(c[0]) * (abs(c[0]) - s[0] * 0.5)
        return np.array([inboard, hi[1] - s[1] * 0.30, c[2]])
    return np.array([c[0], hi[1], c[2]])


def budget(parts: list[dict]) -> None:
    """Split TRI_CEIL between the parts by SURFACE AREA, floored, and equal
    across each mirrored pair.

    Area because triangles pay for silhouette and silhouette is area — the same
    argument tools/meshy.py makes for whole assets, applied one level down. The
    pair rule is not cosmetic: two limbs decimated independently to slightly
    different counts break symmetry in a way the eye catches immediately on a
    machine, which is the one shape where a viewer expects both sides to match.
    """
    # Share by area first — and the pair share is the pair's own total, so a
    # limb is not paid twice for having two of itself.
    by_role: dict[str, list[dict]] = {}
    for p in parts:
        by_role.setdefault(p["role"], []).append(p)
    for group in by_role.values():
        share = max(p["area"] for p in group)
        for p in group:
            p["area_share"] = share

    # Floors are honoured first and the REST of the budget is split between the
    # parts still above their floor. Scaling everything and re-flooring — the
    # obvious loop, and the one written first — hands every part its floor and
    # nothing else the moment the raw areas are small numbers, which is how a
    # 410k-triangle torso and a 22k head both came out at 614.
    floored: set[int] = set()
    for _ in range(len(parts)):
        free = [p for p in parts if id(p) not in floored]
        pool = TRI_CEIL - TRI_PART_FLOOR * len(floored)
        total = sum(p["area_share"] for p in free) or 1.0
        changed = False
        for p in free:
            p["target"] = pool * p["area_share"] / total
            if p["target"] < TRI_PART_FLOOR:
                p["target"] = float(TRI_PART_FLOOR)
                floored.add(id(p))
                changed = True
        if not changed:
            break
    for p in parts:
        p["target"] = min(int(round(p["target"])), p["faces_in"])


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    key, source = sys.argv[1], Path(sys.argv[2])
    if not source.exists():
        print("FAIL no such file: %s" % source)
        return 1
    textured = Path(sys.argv[3]) if len(sys.argv) > 3 else None
    if textured is not None and not textured.exists():
        print("FAIL no such file: %s" % textured)
        return 1
    import fast_simplification

    scene = trimesh.load(source)
    parts = _measure(scene)
    print("%s: %d geometries, %d triangles, scene %.4f x %.4f x %.4f" % (
        source.name, len(parts), sum(p["faces_in"] for p in parts),
        *(scene.bounds[1] - scene.bounds[0])))

    # THE MARRIAGE. After this the parts are the TEXTURED sculpt's; the
    # segmentation has done its one job and is only a name and a label colour
    # from here down. See the module docstring for why this direction and not
    # the other.
    painted = None
    metallic_note: dict | None = None
    sides: dict = {}
    if textured is not None:
        sys.path.insert(0, str(Path(__file__).resolve().parent))
        import meshy
        sides = meshy.tex_budget({"screen": DRAWN_SCREEN_UNITS})
        parts, painted = marry(parts, textured)
        # BEFORE the maps are resized, so the reported peak is the delivered
        # one rather than one LANCZOS has already smoothed the top off.
        metallic_note = clamp_metallic(painted)
        resize_maps(painted, sides)
        for p in parts:
            print("  %-8s %7d seg -> %7d textured tris (%.1f%%)" % (
                p["source"], p["seg_faces_in"], p["faces_in"],
                100.0 * p["faces_in"] / p["seg_faces_in"]))

    classify(parts)
    budget(parts)

    # The measured pairing, checked against the file's own labels. Printed
    # either way — a disagreement is a thing a human needs to see, not an
    # exception to swallow.
    measured = {}
    for p in parts:
        if p["role"] not in ("torso", "back", "head"):
            measured.setdefault(p["role"], []).append(p["source"])
    agree = label_agrees(parts)
    print("pairing: measured %s" % (" ".join(
        "%s=%s/%s" % (r, *sorted(v)) for r, v in sorted(measured.items()))))
    print("pairing: segmentation labels %s the measurement"
          % ("AGREE with" if agree else "DISAGREE with"))

    # Everything to metres at the drawn height, measured off the assembled
    # scene rather than read out of the file's transform.
    height = float(max(p["max"][1] for p in parts) - min(p["min"][1] for p in parts))
    floor = float(min(p["min"][1] for p in parts))
    to_metres = DRAWN_METRES / height
    print("unit scale: scene %.5f tall -> %.2f m (x%.3f), floor at %.5f" % (
        height, DRAWN_METRES, to_metres, floor))

    out_scene = trimesh.Scene()
    record = []
    for p in sorted(parts, key=lambda q: q["name"]):
        mesh = p["mesh"]
        target = p["target"]
        uv = normals = None
        if painted is None:
            if target < p["faces_in"]:
                v, f = fast_simplification.simplify(
                    np.asarray(mesh.vertices, dtype=np.float32),
                    np.asarray(mesh.faces, dtype=np.int32),
                    target_count=int(target))
                mesh = trimesh.Trimesh(vertices=v, faces=f, process=False)
            mesh.merge_vertices()
            mesh.fix_normals()
        else:
            # NEITHER `merge_vertices` NOR `fix_normals` on the painted path.
            # Merging welds the seam duplicates the UVs depend on — one position
            # carrying two UVs is not a duplicate to be tidied away, it is where
            # the map is cut — and recomputing normals throws away the sculpt's
            # own shading for the faceting of an 8,000-triangle approximation of
            # it. Both are right for an untextured part and wrong for this one.
            uv, normals = p["uv"], p["normals"]
            if target < p["faces_in"]:
                mesh, uv, normals = decimate_with_uv(mesh, uv, normals, target)

        # Pivot the geometry on its own joint and carry the joint on the node.
        # The scene that consumes this (tools/rig_parts.gd) then gets a hinge
        # for free: rotating the node rotates the part about the place it is
        # actually attached, which is the entire trick segmented movement runs on.
        joint = pivot(p)
        mesh.apply_translation(-joint)
        mesh.apply_scale(to_metres)
        placed = (joint - np.array([0.0, floor, 0.0])) * to_metres

        hexcol, metallic, rough = PALETTE[p["role"]]
        if painted is None:
            rgb = [int(hexcol[i:i + 2], 16) for i in (0, 2, 4)]
            mesh.visual = trimesh.visual.TextureVisuals(
                material=trimesh.visual.material.PBRMaterial(
                    name=p["name"], baseColorFactor=rgb + [255],
                    metallicFactor=metallic, roughnessFactor=rough))
        else:
            # ONE material instance shared by all thirteen parts, which is what
            # keeps four maps in the file instead of fifty-two: trimesh writes
            # one glTF material and one image per distinct material OBJECT, so
            # sharing the instance is the deduplication.
            mesh.visual = trimesh.visual.TextureVisuals(uv=uv, material=painted)
            mesh.vertex_normals = normals
        transform = np.eye(4)
        transform[:3, 3] = placed
        out_scene.add_geometry(mesh, node_name=p["name"], geom_name=p["name"],
                               transform=transform)

        record.append({
            "name": p["name"], "role": p["role"], "source": p["source"],
            "faces_in": p["faces_in"], "faces_out": int(len(mesh.faces)),
            "kept": round(len(mesh.faces) / p["faces_in"], 5),
            "label_colour": "%02x%02x%02x" % tuple(p["label"]),
            "joint_m": [round(float(x), 5) for x in placed],
            "size_m": [round(float(x * to_metres), 5) for x in p["size"]],
            # The part's own box RELATIVE TO ITS JOINT, in metres. The death
            # solve needs it: a part that breaks off tumbles about its centre of
            # mass, not about the hinge it used to swing on, and it comes to rest
            # when that centre is half its own thickness off the planking.
            "local_min_m": [round(float(x), 5) for x in mesh.bounds[0]],
            "local_max_m": [round(float(x), 5) for x in mesh.bounds[1]],
            "colour": hexcol, "metallic": metallic, "roughness": rough,
        })
        if painted is not None:
            # `colour` above stays in the record — it is the flat stand-in a
            # reader can fall back to and the one the untextured kit shipped —
            # but `textured` is what tools/rig_parts.gd reads, and while it is
            # true the part wears the kit's own painted material instead.
            record[-1]["textured"] = True
            record[-1]["seg_faces_in"] = p["seg_faces_in"]
        print("  %-10s %-8s %7d -> %5d  (%5.2f%%)  joint %7.3f %6.3f %6.3f m" % (
            p["name"], p["source"], p["faces_in"], len(mesh.faces),
            100.0 * len(mesh.faces) / p["faces_in"], *placed))

    # THE KIT IS A SOURCE, NOT A SHIPPED ASSET, so it lands beside every other
    # model original: `.model_originals/` is outside git and invisible to Godot
    # (a dot directory is not scanned), which is why the knight's and the
    # Boilerwright's sources live there and only their built artifacts are
    # committed. `tools/rig_parts.gd` reads this back through GLTFDocument —
    # the one loader that does not need an import step — and what ships is the
    # scene it builds.
    out_dir = ROOT / "assets" / "models" / key
    out_dir.mkdir(parents=True, exist_ok=True)
    kit_dir = ROOT / ".model_originals" / ("%s_parts" % key)
    kit_dir.mkdir(parents=True, exist_ok=True)
    glb = kit_dir / ("%s_parts.glb" % key)
    glb.write_bytes(trimesh.exchange.gltf.export_glb(out_scene))
    delivered = kit_dir / source.name
    if not delivered.exists():
        delivered.write_bytes(source.read_bytes())

    # THE MAPS COME DOWN BY THE PROJECT'S OWN LAW, applied by the project's own
    # function. `tools/meshy.py:shrink_glb` is what took the boarding hulk from
    # 142 MB to 2.3 MB with its geometry untouched, and the argument is the same
    # here: the triangles are already at the budget and 97% of what is left is
    # painted maps at the size a print job would want.
    #
    # 616 px on screen (330 ground units) is over TEX_FULL_ABOVE_PX, so this one
    # earns the full base colour: 1024 albedo, 512 normal, 256 for the two
    # lighting modulators. Imported here rather than restated because unlike the
    # triangle law these are not four numbers but an encoder — and the module
    # imports clean, whatever the note above TRI_CEIL inherited.
    maps = {}
    if painted is not None:
        import meshy
        was, now = meshy.shrink_glb(glb, sides, verbose=True)
        print("kit: %.2f -> %.2f MB" % (was / 1e6, now / 1e6))
        maps = {role: sides[role] for role in sorted(sides)}
        twin = kit_dir / textured.name
        if not twin.exists():
            twin.write_bytes(textured.read_bytes())

    total_in = sum(r["faces_in"] for r in record)
    total_out = sum(r["faces_out"] for r in record)
    (out_dir / "parts.json").write_text(json.dumps({
        "key": key,
        "note": ("The PART MAP for the segmented Colossus. `tools/segment_parts.py` "
                 "derived every name in it from the geometry's own bounds — nothing "
                 "here is keyed to a GLTF_n index, because a re-export renumbers "
                 "those and does not move the parts. The `source` field records "
                 "which geometry each name WAS in the delivered file so a later "
                 "reader can go back to it."),
        "delivered_as": source.name,
        "delivered_note": ("Meshy PART-SEGMENTATION export: 13 separate geometries, "
                           "no UVs, no texture images, each part flat-filled with a "
                           "categorical LABEL colour. `label_colour` records the "
                           "label; `colour` is what the part actually wears when "
                           "there is no painted twin, assigned by role out of the "
                           "project palette."),
        "textured_from": (textured.name if textured is not None else None),
        "textured_note": (None if painted is None else
                          "THE PARTS ARE CUT FROM THE TEXTURED TWIN, not from the "
                          "segmentation — the segmentation supplies the labels and "
                          "nothing else (tools/split_rotors.py plays the same trick "
                          "on the gunner). Every part therefore carries real UVs and "
                          "shares ONE painted material with four maps; `colour` is "
                          "kept as the flat fallback it used to be, and `textured` "
                          "is what tools/rig_parts.gd reads to leave the kit's own "
                          "material alone."),
        "texture_sides": maps or None,
        # What the lamplit ceiling did to the delivered material, recorded so a
        # reader can tell a clamped kit from an unclamped one without re-running
        # the tool — the unclamped kit is the one that shipped as a black
        # silhouette, and nothing in the glb itself says which it is.
        "lamplit_metallic_max": LAMPLIT_METALLIC_MAX,
        "metallic_clamp": metallic_note,
        "metallic_note": (None if metallic_note is None else
                          "Meshy delivers no metallicFactor, which in glTF means "
                          "1.0, over a metallic map peaking near chrome. This deck "
                          "is lit by lamps and has no environment to reflect, so a "
                          "metallic surface returns nothing and reads as a hole. "
                          "`factor_out` is set so the map's PEAK texel lands on "
                          "`lamplit_metallic_max`; the map's own pixels are "
                          "untouched, only its level. Same ceiling the flat "
                          "PALETTE obeys — see LAMPLIT_METALLIC_MAX."),
        "faces_in": total_in, "faces_out": total_out,
        "kept": round(total_out / total_in, 5),
        "tri_budget": TRI_CEIL, "tri_part_floor": TRI_PART_FLOOR,
        "drawn_metres": DRAWN_METRES,
        "scene_height_in": round(height, 6), "to_metres": round(to_metres, 4),
        "symmetry_labels_agree": agree,
        "parts": record,
    }, indent=2), encoding="utf-8")

    print("total %d -> %d triangles (%.3f%% kept, budget %d)" % (
        total_in, total_out, 100.0 * total_out / total_in, TRI_CEIL))
    print("wrote %s (%.2f MB) and parts.json" % (glb, glb.stat().st_size / 1e6))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
