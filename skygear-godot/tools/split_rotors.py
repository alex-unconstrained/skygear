#!/usr/bin/env python3
"""Cut the GUNNER's propellers out of its one welded mesh, so the renderer can
spin them.

    python tools/split_rotors.py <textured.glb> <part-segmentation.glb>

WHY THIS EXISTS. The handoff spec wrote the gunner's shape before anyone had a
file to look at, and it was right: *"the right shape is a static mesh (rotor as
a separate child so the renderer can spin it) — no rig, no clips, and the loop
animates the spin and bob in code."* A propeller drone has no spine to rig and
nothing a Mixamo clip could say about it; what it has is three rotors, and the
only thing they do is turn.

What the delivered file is, though, is ONE MESH. `Meshy_AI_Clockwork_Sentry_
Sphe_0802232753_texture.glb` is a single welded surface — 10,344 triangles,
5,116 welded vertices, and a connected-component pass over it returns exactly
one component. There is no node to spin.

THE SECOND FILE IS THE ANSWER, and this is what it is FOR. The owner also
delivered a PART-SEGMENTATION export: the same object as 11 separate
geometries, flat-filled with categorical label colours, no UVs and no textures
at all. Ship that and the deck gets a harlequin; but as DATA it says which
triangle belongs to which part, which is precisely the fact the textured file
has lost. So the labels are transferred from the segmentation onto the textured
mesh by nearest neighbour, and then thrown away.

The transfer is by NORMALISED position, not raw coordinates: the segmentation
is KHR_mesh_quantization u16 in a 0..16383 box and the textured mesh is metres
about the origin. Their AABB ratios agree to three decimals on all three axes
(1.000 / 0.887 / 0.402), which is the check that they are the same object in
the same orientation — and it is asserted below rather than assumed, because a
re-export that flipped an axis would otherwise weld the blades to the chains
and nobody would see it until the thing spun.

THE PARTS ARE NAMED BY MEASUREMENT, not by index. `model_part1` is not
promised to be a blade by anything except where it is: the blade groups are the
Y-THIN, XZ-WIDE parts (99 units thick in a 14,529-unit model), which is the one
property a propeller has and a chain, a leg-mount or a hull does not. The
segmentation numbers its geometries in whatever order it pleases and a
hard-coded index would survive exactly one re-export.

THE PIVOTS COME OUT OF THE SAME MEASUREMENT. Each rotor group's own centroid
becomes its node origin, and its vertices are written relative to it — so
`rotation.y += w * delta` on the node spins the blades about their hub instead
of swinging them round the drone. All three rotors are horizontal discs (thin
in Y), so all three spin about local +Y and the renderer needs one rule, not
three.

Output is `assets/models/gunner/gunner.glb`: the same buffer, the same
material, the same four maps — four MESHES instead of one, named `Body`,
`RotorTop`, `RotorLeft` and `RotorRight`. Geometry is untouched, which is the
hulk bargain (board SG-76): 94% of one of these files is texture, so the
shrinking happens to the maps and the triangles are left alone.
"""
from __future__ import annotations

import json
import struct
import sys
from pathlib import Path

import numpy as np
from scipy.spatial import cKDTree

ROOT = Path(__file__).resolve().parent.parent

COMPONENT = {5120: "i1", 5121: "u1", 5122: "i2", 5123: "u2", 5125: "u4", 5126: "f4"}
COUNT = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}

## A blade is a THIN FLAT PLATE — the same fact `tools/meshy.py` names when it
## gives this one asset a triangle-budget override ("its two faces are a few
## millimetres apart"). Thin along the rotor axis, wide across it. Nothing else
## on this drone is both: the ring mounts are wide and DEEP, the hanging chains
## are thin and NARROW, the hull is neither.
##
## Measured in units of the model's longest axis, after a UNIFORM normalisation
## — per-axis normalisation would stretch this model's shallow Z by 2.5x and
## quietly bias every distance in the label transfer.
BLADE_WIDE = 0.10      ## across: a blade's own span
BLADE_BAND = 0.06      ## along the axis: how thick a stack of blades may be
BANDS = 120            ## Y slices the search runs in


def glb_read(path: Path) -> tuple[dict, bytes]:
    raw = path.read_bytes()
    if raw[:4] != b"glTF":
        raise SystemExit("%s is not a GLB" % path)
    off, js, blob = 12, None, b""
    while off < len(raw):
        length, kind = struct.unpack_from("<II", raw, off)
        chunk = raw[off + 8: off + 8 + length]
        if kind == 0x4E4F534A:
            js = json.loads(chunk.decode("utf-8"))
        else:
            blob = chunk
        off += 8 + length
    return js, blob


def glb_write(path: Path, js: dict, blob: bytes) -> int:
    while len(blob) % 4:
        blob += b"\x00"
    js_bytes = json.dumps(js, separators=(",", ":")).encode("utf-8")
    while len(js_bytes) % 4:
        js_bytes += b" "
    total = 12 + 8 + len(js_bytes) + 8 + len(blob)
    out = bytearray()
    out += b"glTF" + struct.pack("<II", 2, total)
    out += struct.pack("<II", len(js_bytes), 0x4E4F534A) + js_bytes
    out += struct.pack("<II", len(blob), 0x004E4942) + blob
    path.write_bytes(out)
    return total


def accessor(js: dict, blob: bytes, index: int) -> np.ndarray:
    a = js["accessors"][index]
    bv = js["bufferViews"][a["bufferView"]]
    n = COUNT[a["type"]]
    dt = np.dtype(COMPONENT[a["componentType"]])
    start = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    stride = bv.get("byteStride") or n * dt.itemsize
    raw = np.frombuffer(blob, dtype=np.uint8, count=stride * a["count"], offset=start)
    raw = raw.reshape(a["count"], stride)[:, : n * dt.itemsize].copy()
    return raw.view(dt).reshape(a["count"], n)


def unit_box(points: np.ndarray) -> np.ndarray:
    """Into the model's own bounding box at UNIFORM scale — the only frame in
    which a quantised segmentation and a metric mesh can be compared, and the
    only one in which the comparison does not distort shape."""
    lo, hi = points.min(0), points.max(0)
    return (points - lo) / max(float((hi - lo).max()), 1e-9)


def segmentation_labels(path: Path) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Every segmentation vertex, normalised, with the part it belongs to."""
    js, blob = glb_read(path)
    points, labels = [], []
    for i, mesh in enumerate(js["meshes"]):
        p = accessor(js, blob, mesh["primitives"][0]["attributes"]["POSITION"])
        points.append(p.astype(np.float64))
        labels.append(np.full(len(p), i, dtype=np.int32))
    raw = np.concatenate(points)
    return unit_box(raw), np.concatenate(labels), raw


def blade_bands(points: np.ndarray, labels: np.ndarray) -> list[tuple[int, float, float]]:
    """Where the propeller blades are, by shape alone: (part, y_low, y_high).

    Not "which parts are blades" — the segmentation gave the two side rotors
    their own geometries and left the TOP rotor inside the mast assembly it
    stands on, so a whole-part test finds four blades of six. The test that
    finds all three rotors is a test on BANDS: slice the model in Y, call a
    slice WIDE if its cross-section is more than a blade's span across, and a
    blade band is then a run of wide slices too THIN to be anything else. The
    mast under the top rotor is narrow; the ring mount around a side rotor is
    wide but four times too tall; the hull is both.

    A band is then extended past the last wide slice to the part's own end when
    there is nothing wide beyond it — the little brass cap on top of the mast
    rotor is hardware bolted to the blades, and it should turn with them.
    """
    lo = float(points[:, 1].min())
    hi = float(points[:, 1].max())
    step = (hi - lo) / BANDS
    found = []
    for part in np.unique(labels):
        p = points[labels == part]
        slot = np.clip(((p[:, 1] - lo) / step).astype(int), 0, BANDS - 1)
        wide = np.zeros(BANDS, dtype=bool)
        live = np.zeros(BANDS, dtype=bool)
        for b in np.unique(slot):
            q = p[slot == b]
            live[b] = True
            wide[b] = max(np.ptp(q[:, 0]), np.ptp(q[:, 2])) > BLADE_WIDE
        runs, start = [], None
        for b in range(BANDS):
            if wide[b] and start is None:
                start = b
            elif not wide[b] and start is not None:
                runs.append((start, b - 1))
                start = None
        if start is not None:
            runs.append((start, BANDS - 1))
        for a, b in runs:
            if (b - a + 1) * step > BLADE_BAND:
                continue
            ## nothing wide above -> the band owns everything above it, and
            ## likewise below. Hardware bolted to a blade turns with the blade.
            top = b if wide[b + 1:].any() else int(np.max(np.where(live)[0]))
            bottom = a if wide[:a].any() else int(np.min(np.where(live)[0]))
            found.append((int(part), lo + bottom * step,
                          lo + (top + 1) * step))
    return found


def main() -> int:
    if len(sys.argv) < 3:
        raise SystemExit(__doc__.splitlines()[2].strip())
    textured, segmented = Path(sys.argv[1]), Path(sys.argv[2])

    js, blob = glb_read(textured)
    prim = js["meshes"][0]["primitives"][0]
    attrs = dict(prim["attributes"])
    pos = accessor(js, blob, attrs["POSITION"]).astype(np.float64)
    idx = accessor(js, blob, prim["indices"]).reshape(-1).astype(np.int64)
    tris = idx.reshape(-1, 3)
    unit_pos = unit_box(pos)
    print("textured  %d verts  %d tris  span %s"
          % (len(pos), len(tris), np.round(pos.max(0) - pos.min(0), 3)))

    seg_unit, seg_label, seg_raw = segmentation_labels(segmented)
    seg_span = seg_raw.max(0) - seg_raw.min(0)
    tex_span = pos.max(0) - pos.min(0)
    ## THE ONE ASSERTION THAT MATTERS: same object, same orientation. Compared
    ## as ratios to the longest axis, because the two files are in different
    ## units and only their proportions can agree.
    ratio_a = seg_span / seg_span.max()
    ratio_b = tex_span / tex_span.max()
    print("segmented %d verts  %d parts  axis ratios %s vs %s"
          % (len(seg_unit), len(np.unique(seg_label)),
             np.round(ratio_a, 3), np.round(ratio_b, 3)))
    if np.abs(ratio_a - ratio_b).max() > 0.02:
        raise SystemExit("the two files are not the same object in the same "
                         "orientation — axis ratios disagree by %.3f"
                         % np.abs(ratio_a - ratio_b).max())

    bands = blade_bands(seg_unit, seg_label)
    for part, y0, y1 in bands:
        print("blade band: part %-3d y %.3f..%.3f" % (part, y0, y1))

    ## A ROTOR IS A CLUSTER OF BANDS, not a band. The segmentation gave each of
    ## the four side blades its own geometry — a two-blade prop is two plates
    ## with a gap at the hub — so five bands come back for three rotors. They
    ## are merged by proximity: two bands closer than a blade's own span are
    ## the same propeller.
    seats = []
    for band in bands:
        part, y0, y1 = band
        p = seg_unit[seg_label == part]
        p = p[(p[:, 1] >= y0) & (p[:, 1] <= y1)]
        seat = (p.min(0) + p.max(0)) / 2
        for group in seats:
            if np.linalg.norm(group["seat"] - seat) < BLADE_WIDE * 2.0:
                group["bands"].append(band)
                group["seat"] = (group["seat"] + seat) / 2
                break
        else:
            seats.append({"seat": seat, "bands": [band]})
    print("rotors: %d" % len(seats))
    if len(seats) != 3:
        raise SystemExit("expected three rotors, measured %d — the painted "
                         "drone has one on top and one to each side" % len(seats))

    ## Label every triangle by the segmentation vertex nearest its centroid,
    ## then keep the label only where the segmentation says BLADE.
    tree = cKDTree(seg_unit)
    centroid = unit_pos[tris].mean(axis=1)
    _dist, near = tree.query(centroid, k=1)
    tri_part = seg_label[near]
    tri_y = seg_unit[near][:, 1]

    ## Which rotor is which is read off its own seat: the highest is the mast
    ## rotor, the other two are left and right by X. Named for what a reader
    ## looking at the FRONT of the drone sees, which is the frame the painted
    ## art is drawn in and the frame the deck camera holds.
    seats.sort(key=lambda g: -g["seat"][1])
    order = ["Body", "RotorTop", "RotorLeft", "RotorRight"]
    named = {"RotorTop": seats[0]}
    side = sorted(seats[1:], key=lambda g: g["seat"][0])
    named["RotorLeft"], named["RotorRight"] = side[0], side[1]

    groups: dict[str, np.ndarray] = {}
    claimed = np.zeros(len(tris), dtype=bool)
    for name in order[1:]:
        pick = np.zeros(len(tris), dtype=bool)
        for part, y0, y1 in named[name]["bands"]:
            pick |= (tri_part == part) & (tri_y >= y0) & (tri_y <= y1)
        groups[name] = np.where(pick)[0]
        claimed |= pick
    groups["Body"] = np.where(~claimed)[0]
    for name in order:
        ids = groups[name]
        if len(ids) == 0:
            raise SystemExit("group %s came out empty — the split rule is wrong"
                             % name)
        p = pos[np.unique(tris[ids])]
        print("  %-11s %5d tris  centre %s  span %s"
              % (name, len(ids), np.round((p.min(0) + p.max(0)) / 2, 3),
                 np.round(p.max(0) - p.min(0), 3)))

    ## Rebuild: one mesh per group, each with its OWN vertex block written
    ## relative to the group's pivot, so the node origin is the hub.
    blob = bytearray(blob)
    views, accs, meshes, nodes = js["bufferViews"], js["accessors"], [], []
    for name in order:
        ids = groups[name]
        used = np.unique(tris[ids])
        remap = np.full(len(pos), -1, dtype=np.int64)
        remap[used] = np.arange(len(used))
        local = remap[tris[ids]].astype(np.uint32)
        p = pos[used]
        pivot = (p.min(0) + p.max(0)) / 2 if name != "Body" else np.zeros(3)
        new_attrs = {}
        for key, src in attrs.items():
            data = accessor(js, bytes(blob), src)[used].copy()
            if key == "POSITION":
                data = (data.astype(np.float64) - pivot).astype(np.float32)
            new_attrs[key] = _append(blob, views, accs, data,
                                     js["accessors"][src]["type"],
                                     js["accessors"][src]["componentType"],
                                     minmax=(key == "POSITION"))
        ## u16 indices — every group is well under 65,536 vertices once it is
        ## re-indexed to its own block, and halving the index buffer is free.
        narrow = len(used) < 65536
        ind = _append(blob, views, accs,
                      local.reshape(-1, 1).astype(np.uint16 if narrow else np.uint32),
                      "SCALAR", 5123 if narrow else 5125, target=34963)
        meshes.append({"name": name, "primitives": [{
            "attributes": new_attrs, "indices": ind,
            "material": prim.get("material", 0)}]})
        node = {"name": name, "mesh": len(meshes) - 1}
        if name != "Body":
            node["translation"] = [float(v) for v in pivot]
        nodes.append(node)

    js["meshes"] = meshes
    js["nodes"] = nodes
    js["scenes"] = [{"nodes": list(range(len(nodes)))}]
    js["scene"] = 0

    ## COMPACT. The old single mesh's position, normal, UV and index views are
    ## still in the buffer and nothing points at them any more — 0.9 MB of a
    ## file whose whole budget argument is that geometry is the cheap half.
    ## Keep what an accessor or an image names, drop the rest, and renumber.
    ## The ACCESSORS are pruned first, or the four dead ones keep their views
    ## alive and the compaction quietly does nothing.
    live: dict[int, int] = {}
    for mesh in meshes:
        p = mesh["primitives"][0]
        for key in list(p["attributes"]):
            p["attributes"][key] = live.setdefault(p["attributes"][key], len(live))
        p["indices"] = live.setdefault(p["indices"], len(live))
    accs = [accs[old] for old in sorted(live, key=lambda o: live[o])]
    js["accessors"] = accs
    keep, remap_view = [], {}
    for acc in accs:
        if acc.get("bufferView") is not None and acc["bufferView"] not in remap_view:
            remap_view[acc["bufferView"]] = None
    for img in js.get("images", []):
        if img.get("bufferView") is not None:
            remap_view[img["bufferView"]] = None
    packed = bytearray()
    for old in sorted(remap_view):
        view = dict(views[old])
        raw = bytes(blob[view.get("byteOffset", 0):
                         view.get("byteOffset", 0) + view["byteLength"]])
        while len(packed) % 4:
            packed.append(0)
        view["byteOffset"] = len(packed)
        packed += raw
        remap_view[old] = len(keep)
        keep.append(view)
    for acc in accs:
        if acc.get("bufferView") is not None:
            acc["bufferView"] = remap_view[acc["bufferView"]]
    for img in js.get("images", []):
        if img.get("bufferView") is not None:
            img["bufferView"] = remap_view[img["bufferView"]]
    js["bufferViews"] = keep
    blob = packed
    js["buffers"][0]["byteLength"] = len(blob)

    out = ROOT / "assets" / "models" / "gunner" / "gunner.glb"
    size = glb_write(out, js, bytes(blob))
    print("wrote %s  %.2f MB" % (out, size / 1e6))
    return 0


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
