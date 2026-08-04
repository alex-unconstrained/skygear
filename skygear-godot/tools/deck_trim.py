#!/usr/bin/env python3
"""DECIMATE A HAND-MADE DECK PIECE WITHOUT TOUCHING ITS TEXTURE. SG-148.

    python tools/deck_trim.py plan                    # what the law asks of each piece
    python tools/deck_trim.py thin bow_ram            # where the decimator will hurt it
    python tools/deck_trim.py trim bow_ram 3000       # write the trimmed glb
    python tools/deck_trim.py trim mast_crowned 6000 --suffix t6000   # a variant to judge
    python tools/deck_trim.py check assets/models/bow_ram/bow_ram.glb

WHY THIS IS NOT `segment_parts.py` AND NOT `meshy.py remesh`.

`tools/segment_parts.py` already owns the only UV-preserving decimation in this
repo — `decimate_with_uv`, which replays `fast_simplification`'s collapse history
so every surviving vertex inherits a UV from a vertex it descends from. That
function is right and this file CALLS IT rather than writing a second one. What
segment_parts cannot do is the rest of the job: it consumes a Meshy PART
SEGMENTATION export, splits it into a named kit, repaints from a role palette
and exports through trimesh. These four pieces are none of that. They are single
welded textured meshes the owner made by hand, and what they need is one
number changed.

`meshy.py remesh` is the other wrong tool and its own header says why: remesh
is a paid API call that comes back 2.75x LARGER because it re-encodes the maps.
The owner has said do not spend credits, and these pieces do not need a service
to lose triangles.

THE TEXTURE IS COPIED, NOT RE-ENCODED — this is the point of the file.

Loading one of these through trimesh and exporting it re-encodes four embedded
JPEGs, which is the exact regression `meshy.py`'s header measured on steam_vent.
So this rewrites the glb the way `tools/lamplit.py` rewrites a metallicFactor:
by hand. The new binary chunk is [new geometry][the original image bytes,
memcpy'd], the image bufferViews are re-pointed at their new offsets, and the
JPEG bytes that land are byte-for-byte the bytes that arrived. Every byte this
tool saves is a byte of geometry, which makes the before/after size number
mean something.

THE HAZARD, AND IT IS WRITTEN DOWN IN THIS REPO ALREADY.

`tools/meshy.py`'s `tri_budget` carries exactly one override, for the gunner
drone, and the reason is that a propeller blade is a THIN FLAT PLATE: its two
faces are millimetres apart, so an edge collapse across the plate does not lose
accuracy, it WELDS THE FRONT OF THE BLADE TO THE BACK. It came back from 3,000
with a hole punched through a blade.

A mast's shrouds and rigging lines are that same shape, so `thin` measures it
before anything is cut: it reports the thickness distribution of the mesh and
the triangle count living on members thinner than a given span, so the decision
about a target is made against a number rather than a hope. It cannot replace
LOOKING at the result — nothing here can, and the renders are the deliverable —
but it says in advance which piece is going to argue.

THE TARGET IS NOT 8,000. `meshy.py` is the law and its answer for all four of
these is 3,000, the FLOOR, because the area rule only bites above ~380 screen
pixels and the tallest of them is 355. 8,000 is the CEILING — the Colossus at
616 px — and reading it as the budget asks for 2.7x the triangles the camera
can show. The shipped sibling settles it: `rail_stanchion` came off the owner's
hand at 3,060, was judged by eye on the real GPU and adopted. Same kit, same
session, same 190-unit width, same camera. `plan` prints this arithmetic rather
than asserting it.
"""
from __future__ import annotations

import json
import struct
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]

# Close enough to budget that cutting is not worth a decimation pass. Alex has
# Meshy generate at ~3,000 now, so most deliveries land here and should go
# through untouched.
NEAR_ENOUGH = 0.85

# Below this share kept, say so. NOT a refusal — see the note at the point of
# use for why the refusal I first wrote here was wrong and what predicts damage
# instead.
CLIFF_EDGE = 0.80
MODELS = ROOT / "assets" / "models"

## The kit the owner hand-made on 2026-08-03, and the one number this file is
## about. `rail_stanchion` is here so `plan` can print the piece that SHIPPED
## next to the three that did not — it is the control, not a job.
KIT = ["rail_stanchion", "mast_crowned", "bow_ram", "stern_counter"]

## glTF component types, only the ones these files actually use.
FLOAT, U16, U32 = 5126, 5123, 5125

## How hard the UV transfer prefers the NEAREST piece of original surface over
## the assignment that keeps a triangle smallest in UV space. Both matter and
## they pull against each other: distance is what gets the right texture onto a
## vertex, UV compactness is what stops a triangle straddling a seam and
## smearing the whole atlas across itself.
##
## TUNED BY LOOKING, on the mast, which is the piece with the most seam per
## triangle (.shots/sg148/uvw/): at 200 the distance term drowns the seam test
## and the crown ring loses its brass to streaked steel; at 2 the ring, the yard
## bands and the six rigging lines all come back clean. Overridable through the
## environment so the next asset can be swept the same way rather than by
## editing this line.
UV_DIST_WEIGHT = float(__import__("os").environ.get("DECK_TRIM_UVW", "2.0"))


def read_glb(path: Path) -> tuple[dict, bytes]:
    """Split a .glb into its JSON and its binary chunk. No decoding."""
    raw = path.read_bytes()
    if raw[:4] != b"glTF":
        raise SystemExit("%s is not a binary glb" % path)
    off, chunks = 12, []
    while off < len(raw):
        clen, ctype = struct.unpack("<II", raw[off:off + 8])
        chunks.append((ctype, raw[off + 8:off + 8 + clen]))
        off += 8 + clen
    return json.loads(chunks[0][1].decode("utf-8")), (
        chunks[1][1] if len(chunks) > 1 else b"")


def write_glb(path: Path, gltf: dict, blob: bytes) -> None:
    js = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
    js += b" " * ((4 - len(js) % 4) % 4)
    body = struct.pack("<II", len(js), 0x4E4F534A) + js
    if blob:
        pad = blob + b"\x00" * ((4 - len(blob) % 4) % 4)
        body += struct.pack("<II", len(pad), 0x004E4942) + pad
    path.write_bytes(b"glTF" + struct.pack("<II", 2, 12 + len(body)) + body)


def accessor_array(gltf: dict, blob: bytes, index: int) -> np.ndarray:
    """Read one accessor out of the binary chunk as a numpy array."""
    acc = gltf["accessors"][index]
    view = gltf["bufferViews"][acc["bufferView"]]
    start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    n = acc["count"]
    width = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[acc["type"]]
    dtype = {FLOAT: "<f4", U16: "<u2", U32: "<u4"}[acc["componentType"]]
    size = np.dtype(dtype).itemsize * width
    stride = view.get("byteStride") or size
    if stride == size:
        out = np.frombuffer(blob, dtype=dtype, count=n * width, offset=start)
    else:                       # interleaved; walk it element by element
        out = np.concatenate([
            np.frombuffer(blob, dtype=dtype, count=width, offset=start + i * stride)
            for i in range(n)])
    return out.reshape(n, width) if width > 1 else out


def load_primitive(path: Path) -> dict:
    """The one mesh, one primitive these four pieces each are.

    Asserted rather than assumed: the surgical rebuild below re-points exactly
    one set of geometry accessors, and a second primitive would be silently
    dropped. Every one of the four measured as 1 node / 1 mesh / 1 primitive
    with POSITION, NORMAL and TEXCOORD_0, so the narrow case is the real case
    and the assertion is what keeps it honest for the next file.
    """
    gltf, blob = read_glb(path)
    if len(gltf["meshes"]) != 1 or len(gltf["meshes"][0]["primitives"]) != 1:
        raise SystemExit(
            "%s: %d meshes / %d primitives. This tool rebuilds ONE primitive; "
            "a multi-primitive piece needs the loop written before it is cut."
            % (path.name, len(gltf["meshes"]),
               sum(len(m["primitives"]) for m in gltf["meshes"])))
    prim = gltf["meshes"][0]["primitives"][0]
    if prim.get("mode", 4) != 4:
        raise SystemExit("%s: primitive mode %s is not TRIANGLES" % (
            path.name, prim.get("mode")))
    attrs = prim["attributes"]
    return {
        "gltf": gltf, "blob": blob, "prim": prim,
        "v": accessor_array(gltf, blob, attrs["POSITION"]).astype(np.float64),
        "n": accessor_array(gltf, blob, attrs["NORMAL"]).astype(np.float64),
        "uv": accessor_array(gltf, blob, attrs["TEXCOORD_0"]).astype(np.float64),
        "f": accessor_array(gltf, blob, prim["indices"]).astype(np.int64).reshape(-1, 3),
    }


def glb_path(key: str) -> Path:
    p = Path(key)
    return p if p.suffix == ".glb" else MODELS / key / (key + ".glb")


# --- the law ------------------------------------------------------------------
# Not re-derived here. `tools/meshy.py` owns the triangle budget for this
# project and this imports it, so if the camera moves and PX_PER_UNIT moves with
# it, these numbers move too instead of going stale in a second copy.
def law() -> object:
    import importlib.util
    spec = importlib.util.spec_from_file_location("_meshy", ROOT / "tools" / "meshy.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def plan() -> int:
    m = law()
    print("%-16s %9s %9s %8s %8s %8s %7s" % (
        "piece", "tris", "h (gu)", "px", "law", "ceiling", "over"))
    for key in KIT:
        path = glb_path(key)
        if not path.exists():
            print("%-16s  MISSING %s" % (key, path))
            continue
        d = load_primitive(path)
        ext = d["v"].max(axis=0) - d["v"].min(axis=0)
        gu = float(ext[1]) * 100.0          # 1 m = 100 ground units (handoff spec)
        a = {"screen": gu}
        tris = len(d["f"])
        budget = m.tri_budget(a)
        print("%-16s %9d %9.1f %8.1f %8d %8d %6.2fx" % (
            key, tris, gu, m.screen_px(a), budget, m.TRI_CEIL, tris / budget))
    print("\nThe law is tools/meshy.py tri_budget: 0.021 x px^2, floored at "
          "%d, capped at %d." % (m.TRI_FLOOR, m.TRI_CEIL))
    print("Every piece here is under the ~380 px where the area curve starts to "
          "bite, so every one lands on the FLOOR.")
    print("8,000 is the CEILING (the Colossus at 616 px), not this kit's budget.")
    return 0


# --- the hazard ---------------------------------------------------------------
def thickness(v: np.ndarray, f: np.ndarray) -> np.ndarray:
    """Per-face local thickness: how far it is to the surface on the other side.

    A cheap honest proxy for the gunner-drone failure. For each face centroid,
    shoot INWARD along -normal and take the distance to the nearest other
    vertex that lies within a narrow cone about that ray. A thin flat plate
    returns its own plate thickness; a solid hull returns something on the
    order of the hull's depth. The absolute value matters less than the SHAPE
    of the distribution — a thin-member model has a spike near zero and that
    spike is the geometry a decimator eats first.
    """
    from scipy.spatial import cKDTree
    fv = v[f]
    cent = fv.mean(axis=1)
    nrm = np.cross(fv[:, 1] - fv[:, 0], fv[:, 2] - fv[:, 0])
    ln = np.linalg.norm(nrm, axis=1)
    ok = ln > 0
    nrm[ok] /= ln[ok, None]
    tree = cKDTree(v)
    out = np.full(len(f), np.inf)
    ## Sample along the inward ray and ask how far the surface is at each step.
    ## The first step whose nearest vertex is closer than the step itself has
    ## passed through the far face, and that step is the thickness.
    span = float(np.linalg.norm(v.max(axis=0) - v.min(axis=0)))
    for t in np.linspace(span * 0.002, span * 0.25, 60):
        p = cent - nrm * t
        d, _ = tree.query(p)
        hit = (d < t * 0.5) & np.isinf(out)
        out[hit] = t
    return out


def thin(key: str, frac: float = 0.01) -> int:
    """Report how much of a piece lives on thin members. Cuts nothing."""
    path = glb_path(key)
    d = load_primitive(path)
    v, f = d["v"], d["f"]
    span = float(np.linalg.norm(v.max(axis=0) - v.min(axis=0)))
    th = thickness(v, f)
    finite = th[np.isfinite(th)]
    cut = span * frac
    n_thin = int((th <= cut).sum())
    print("%s: %d triangles, bbox diagonal %.4f m" % (path.name, len(f), span))
    print("  measurable thickness on %d of %d faces (%.1f%%)"
          % (len(finite), len(f), 100.0 * len(finite) / len(f)))
    if len(finite):
        for q in (5, 25, 50, 75):
            print("    p%-3d %.4f m" % (q, np.percentile(finite, q)))
    print("  faces on members thinner than %.1f%% of the diagonal (%.4f m): "
          "%d (%.1f%%)" % (frac * 100, cut, n_thin, 100.0 * n_thin / len(f)))
    print("  -- this is the gunner-drone shape. A high number here means the "
          "budget argument has to be made with pictures, not arithmetic.")
    return 0


# --- the cut ------------------------------------------------------------------
# WHY THIS DOES NOT CALL `segment_parts.decimate_with_uv`, WHICH IS THE REPO'S
# ONE UV-PRESERVING DECIMATION AND WHICH I TRIED FIRST.
#
# That function leans on a property it states plainly and which is TRUE OF THE
# ASSET IT WAS WRITTEN FOR and false of these: "glTF has already split the mesh
# at every UV seam into separate indices that no edge joins ... an edge collapse
# cannot merge across one." On the Colossus that is a safety guarantee, because
# 5.4% of its vertices are seam duplicates and the other 94.6% form a connected
# surface the decimator can actually work on.
#
# These four pieces are not that mesh. MEASURED, with `deck_trim.py` itself:
#
#     piece            faces    index-space verts / components   welded / comps
#     rail_stanchion    3,060        6,714 /  2,538                1,524 / 1
#     mast_crowned     10,312       21,995 /  8,355                5,070 / 1
#     bow_ram          30,666       58,090 / 22,504               15,311 / 1
#     stern_counter    30,410       62,808 / 24,044               15,157 / 1
#
# 22,504 components across 30,666 faces. In the index space the decimator sees,
# this model is not a hull, it is a heap of nearly-loose triangles: about 74% of
# its vertices are position duplicates, so almost every face is its own island.
# A quadric decimator given that cannot collapse an edge, because there are
# hardly any interior edges to collapse -- so it does the only other thing it
# can, and DELETES faces. The 3,000-triangle bow came back as confetti: a cloud
# of disconnected triangles in the shape of a boat. It is in the record at
# .shots/sg148/after-detail-shredded/bow_ram_t3000-y035.png and it is the same
# family of failure as the gunner drone's welded propeller, arrived at from the
# opposite direction -- there the decimator merged what should have stayed
# apart, here it could not merge anything at all.
#
# So the surface is WELDED BY POSITION FIRST, which makes it the one connected
# component it visually is, and the UVs are put back afterwards by the method
# below. The seam-straddle that welding risks is handled explicitly rather than
# by hoping the topology prevents it.
def decimate_welded(v: np.ndarray, f: np.ndarray, uv: np.ndarray,
                    nrm: np.ndarray, target: int) -> tuple:
    """Weld by position, decimate, then re-derive UVs by CHOOSING A CHART.

    The UV recovery is exact at every vertex and needs no resampling, because
    of a property worth stating: `fast_simplification` places surviving vertices
    ON ORIGINAL POSITIONS rather than at averaged midpoints. So every output
    vertex is an input position, and the only question is WHICH of the two or
    three UVs that position carries -- which is to say, which side of the seam
    this triangle is on.

    That question is answered PER FACE, by picking the combination of candidate
    UVs that makes the triangle smallest in UV space. A triangle that straddles
    a seam is enormous in UV space -- its corners sit in different charts -- so
    minimising the UV perimeter is exactly the test for "keep this triangle
    inside one chart", and it is chosen rather than assumed. The alternative,
    sampling the original surface for a UV at each output vertex, cannot express
    a seam at all: one position has one answer, and the seam is precisely where
    one position needs two.
    """
    import fast_simplification
    from scipy.spatial import cKDTree

    keyed = np.round(v, 6)
    uniq, inv = np.unique(keyed, axis=0, return_inverse=True)
    wf = inv[f]
    ## Welding can turn a sliver into a degenerate; drop those rather than hand
    ## the decimator a zero-area face.
    keep = (wf[:, 0] != wf[:, 1]) & (wf[:, 1] != wf[:, 2]) & (wf[:, 0] != wf[:, 2])
    wf = wf[keep]

    pts, faces = fast_simplification.simplify(
        uniq.astype(np.float32), wf.astype(np.int32), target_count=int(target))
    pts = np.asarray(pts, dtype=np.float64)
    faces = np.asarray(faces, dtype=np.int64)

    span = float(np.linalg.norm(uniq.max(axis=0) - uniq.min(axis=0)))

    ## CANDIDATES COME OFF THE ORIGINAL SURFACE, NOT OFF THE NEAREST ORIGINAL
    ## VERTEX, and the difference is visible. The first pass here assumed a
    ## surviving vertex sits exactly on an input position and could therefore
    ## just borrow that vertex's UV. It very nearly does -- but "very nearly" is
    ## up to 2% of the model's span, and 2% on a brass strap is a whole strap.
    ## The result was a hull with correct planking and scrambled fittings
    ## (.shots/sg148/after-detail-nearestvertex/). So each output vertex is
    ## projected ONTO the original triangles near it and the UV is interpolated
    ## barycentrically, which is exact wherever the surface did not move and
    ## degrades smoothly where it did.
    ##
    ## Several candidates are kept per vertex because ONE POSITION ON A SEAM HAS
    ## MORE THAN ONE RIGHT ANSWER, and which one is right is a property of the
    ## FACE, not of the vertex. That is the choice made below.
    fv = v[f]
    fuv = uv[f]
    fn = nrm[f]
    centroids = fv.mean(axis=1)
    ftree = cKDTree(centroids)
    k = min(24, len(centroids))
    _d, cand_faces = ftree.query(pts, k=k)

    ## THE GUNNER-DRONE HAZARD, WEARING A DIFFERENT HAT, AND IT COST A PASS TO
    ## SEE. A mast is a cylinder about 3 cm across. The faces nearest a point on
    ## its surface include the faces on the FAR SIDE of the pole -- they are
    ## 3 cm away, closer than most of the pole's own neighbours -- and the far
    ## side of a cylinder is the other end of the UV wrap. Sampling them turned
    ## clean timber into brass-and-steel marbling
    ## (.shots/sg148/ladder-marbled/), and it did it at 8,000 triangles as
    ## readily as at 3,000, which is what proved it was not a budget problem.
    ##
    ## So a candidate face must FACE THE SAME WAY as the surface the output
    ## vertex sits on. The same physical fact the drone override is about -- two
    ## surfaces a few millimetres apart -- caught here by orientation rather
    ## than paid for in triangles.
    face_n = np.cross(fv[:, 1] - fv[:, 0], fv[:, 2] - fv[:, 0])
    fl = np.linalg.norm(face_n, axis=1)
    face_n = face_n / np.where(fl[:, None] == 0, 1.0, fl[:, None])
    ## The output vertex's own normal, area-weighted off the decimated surface.
    dec_fn = np.cross(pts[faces[:, 1]] - pts[faces[:, 0]],
                      pts[faces[:, 2]] - pts[faces[:, 0]])
    vert_n = np.zeros_like(pts)
    for c in range(3):
        np.add.at(vert_n, faces[:, c], dec_fn)
    vl = np.linalg.norm(vert_n, axis=1)
    vert_n = vert_n / np.where(vl[:, None] == 0, 1.0, vl[:, None])

    def closest_on_triangle(p, a, b, c):
        """Closest point to p on triangle abc, and its barycentric weights."""
        ab, ac, ap = b - a, c - a, p - a
        d1 = np.einsum("ij,ij->i", ab, ap)
        d2 = np.einsum("ij,ij->i", ac, ap)
        bp = p - b
        d3 = np.einsum("ij,ij->i", ab, bp)
        d4 = np.einsum("ij,ij->i", ac, bp)
        cp = p - c
        d5 = np.einsum("ij,ij->i", ab, cp)
        d6 = np.einsum("ij,ij->i", ac, cp)
        va = d3 * d6 - d5 * d4
        vb = d5 * d2 - d1 * d6
        vc = d1 * d4 - d3 * d2
        denom = va + vb + vc
        safe = np.where(np.abs(denom) < 1e-20, 1e-20, denom)
        w = np.stack([va / safe, vb / safe, vc / safe], axis=1)
        ## Region tests collapse to a clamp for our purposes: a projection that
        ## lands outside the triangle is pulled back onto it, which is what a
        ## barycentric clamp-and-renormalise does.
        w = np.clip(w, 0.0, None)
        s = w.sum(axis=1, keepdims=True)
        w = np.where(s > 0, w / np.where(s == 0, 1, s), np.full_like(w, 1 / 3))
        return w

    ## (n_out, k) candidate uv / normal / distance
    n_out = len(pts)
    cand_uv = np.zeros((n_out, k, 2))
    cand_n = np.zeros((n_out, k, 3))
    cand_d = np.zeros((n_out, k))
    for j in range(k):
        fi = cand_faces[:, j]
        a, b, c = fv[fi, 0], fv[fi, 1], fv[fi, 2]
        w = closest_on_triangle(pts, a, b, c)
        proj = (w[:, 0:1] * a + w[:, 1:2] * b + w[:, 2:3] * c)
        d_j = np.linalg.norm(pts - proj, axis=1)
        ## A face pointing away from this vertex's own surface is the far side
        ## of a thin member. Pushed to the back of the queue rather than
        ## deleted, so a vertex whose neighbours ALL disagree still gets a UV
        ## instead of a hole.
        agree = np.einsum("ij,ij->i", face_n[fi], vert_n)
        cand_d[:, j] = np.where(agree < 0.3, d_j + span, d_j)
        cand_uv[:, j] = (w[:, 0:1] * fuv[fi, 0] + w[:, 1:2] * fuv[fi, 1]
                         + w[:, 2:3] * fuv[fi, 2])
        cand_n[:, j] = (w[:, 0:1] * fn[fi, 0] + w[:, 1:2] * fn[fi, 1]
                        + w[:, 2:3] * fn[fi, 2])

    ## Thin the candidate list: keep the nearest, then any that disagree with it
    ## in UV space by more than a chart's width -- those are the other sides of
    ## a seam and are the only alternatives worth searching.
    keep_idx = []
    for i in range(n_out):
        order_i = np.argsort(cand_d[i])
        chosen = [order_i[0]]
        for j in order_i[1:]:
            if len(chosen) >= 4:
                break
            if all(np.linalg.norm(cand_uv[i, j] - cand_uv[i, c2]) > 0.01
                   for c2 in chosen):
                chosen.append(j)
        keep_idx.append(chosen)

    ## THE CHOICE, PER FACE. A triangle straddling a seam is huge in UV space,
    ## so the assignment that minimises UV perimeter is the one that keeps the
    ## triangle inside a single chart. Distance is in the cost too, scaled by
    ## the model's span, so that where there is no seam to disambiguate the
    ## nearest surface point simply wins.
    out_v, out_uv, out_n, out_f = [], [], [], []
    for tri in faces:
        best, best_cost = None, None
        for j0 in keep_idx[tri[0]]:
            u0 = cand_uv[tri[0], j0]
            for j1 in keep_idx[tri[1]]:
                u1 = cand_uv[tri[1], j1]
                for j2 in keep_idx[tri[2]]:
                    u2 = cand_uv[tri[2], j2]
                    cost = (np.linalg.norm(u0 - u1) + np.linalg.norm(u1 - u2)
                            + np.linalg.norm(u2 - u0)
                            + UV_DIST_WEIGHT * (cand_d[tri[0], j0]
                                                + cand_d[tri[1], j1]
                                                + cand_d[tri[2], j2]) / span)
                    if best_cost is None or cost < best_cost:
                        best_cost, best = cost, (j0, j1, j2)
        base = len(out_v)
        for corner, j in zip(tri, best):
            out_v.append(pts[corner])
            out_uv.append(cand_uv[corner, j])
            out_n.append(cand_n[corner, j])
        out_f.append([base, base + 1, base + 2])

    out_v = np.asarray(out_v, dtype=np.float64)
    out_uv = np.asarray(out_uv, dtype=np.float64)
    out_n = np.asarray(out_n, dtype=np.float64)
    out_f = np.asarray(out_f, dtype=np.int64)

    ## Re-index: corners agreeing on position, uv AND normal are one vertex
    ## again. This is the inverse of the split that got us here and it takes the
    ## vertex count back down by roughly a factor of three.
    stack = np.hstack([np.round(out_v, 6), np.round(out_uv, 6),
                       np.round(out_n, 5)])
    _u, first, back = np.unique(stack, axis=0, return_index=True,
                                return_inverse=True)
    return (out_v[first], out_f_reindex(out_f, back), out_uv[first],
            out_n[first])


def out_f_reindex(out_f: np.ndarray, back: np.ndarray) -> np.ndarray:
    return back[out_f]


def trim(key: str, target: int, suffix: str | None = None,
         out: Path | None = None, anyway: bool = False) -> int:
    """Decimate to `target` triangles, carrying UVs, copying the images."""
    src = glb_path(key)
    d = load_primitive(src)
    gltf, blob, prim = d["gltf"], d["blob"], d["prim"]
    v, f, uv, nrm = d["v"], d["f"], d["uv"], d["n"]
    if target >= len(f):
        print("%s is already %d triangles, at or under the %d asked for."
              % (src.name, len(f), target))
        return 0

    # ALREADY-AT-BUDGET DELIVERIES PASS THROUGH UNTOUCHED (SG-177).
    #
    # Alex now has Meshy generate at ~3,000 rather than delivering a dense mesh
    # for us to cut, which removes the most dangerous step in the whole ingest.
    # Shaving the last few percent off a delivery that already meets budget buys
    # nothing measurable and spends a decimation pass to get it.
    kept_if_cut = float(target) / float(len(f))
    if kept_if_cut >= NEAR_ENOUGH and not anyway:
        print("%s is %d triangles against a %d budget (%.0f%%). Close enough — "
              "passing it through UNCUT rather than spending a decimation on "
              "%d triangles." % (src.name, len(f), target, 100.0 * kept_if_cut,
                                 len(f) - target))
        return 0

    # A DEEP CUT GETS A WARNING, NOT A REFUSAL — and the reason it is not a
    # refusal is that the first version of this WAS one and it was wrong.
    #
    # I wrote a rule refusing deep cuts on sources under 40,000 triangles,
    # citing the Colossus (30,606 -> 8,000, shredded), the skyship hulls
    # (10,200 -> 3,500, "clouds of loose brass shards") and the gunner drone.
    # Then I tested it against the prow ingested the same day: 9,770 -> 3,000 is
    # 30.7% kept, well inside what the rule refused, and it came through with
    # ZERO open boundary edges and 0.13% deviation. The rule would have blocked
    # a cut that demonstrably worked.
    #
    # Triangle count is not the predictor. `tools/skyships.py` already worked
    # out what is: those hulls were not a SURFACE — 91.7% of their edges were
    # used by one triangle and only 25% of their indexed vertices were distinct
    # positions, so the decimator was collapsing a cloud of loose shards. The
    # fix was welding by position, and `decimate_welded` — which this function
    # calls — does exactly that. The prow survives because it is welded first.
    # The other predictor is thin members, which `thin` measures and which no
    # amount of welding helps.
    #
    # So this says the deep cut is coming and names the two instruments that
    # actually answer it, rather than blocking on a number that does not.
    if kept_if_cut < CLIFF_EDGE:
        print("  note: keeping %.0f%% of %d triangles — a deep cut.\n"
              "        Usually fine here, because `decimate_welded` welds by "
              "position first,\n"
              "        which is what the skyship hulls needed. What actually "
              "predicts damage\n"
              "        is THIN MEMBERS: run `thin` before and `damage` after, "
              "and believe the\n"
              "        open-boundary-edge count over this note."
              % (100.0 * kept_if_cut, len(f)))

    out_v, out_f, out_uv, out_n = decimate_welded(v, f, uv, nrm, target)
    out_v = out_v.astype(np.float32)
    out_f = out_f.astype(np.uint32)
    out_uv = out_uv.astype(np.float32)
    ln = np.linalg.norm(out_n, axis=1)
    if (ln == 0).any():
        raise SystemExit("%d output vertices carried no normal" % int((ln == 0).sum()))
    out_n = (out_n / ln[:, None]).astype(np.float32)

    # THE SURGICAL REBUILD. New buffer = [geometry][the original image bytes].
    # Image bufferViews are copied byte-for-byte and merely re-pointed, so no
    # JPEG is ever decoded, let alone re-encoded. That is the whole reason this
    # does not go out through trimesh's exporter.
    parts, views, accessors = [], [], []
    cursor = 0

    def put(arr: np.ndarray, kind: str, ctype: int, target_hint: int) -> int:
        nonlocal cursor
        raw = arr.tobytes()
        pad = (4 - len(raw) % 4) % 4
        views.append({"buffer": 0, "byteOffset": cursor,
                      "byteLength": len(raw), "target": target_hint})
        parts.append(raw + b"\x00" * pad)
        cursor += len(raw) + pad
        acc = {"bufferView": len(views) - 1, "componentType": ctype,
               "count": len(arr), "type": kind}
        if kind == "VEC3" and ctype == FLOAT:
            acc["min"] = arr.min(axis=0).astype(float).tolist()
            acc["max"] = arr.max(axis=0).astype(float).tolist()
        accessors.append(acc)
        return len(accessors) - 1

    a_pos = put(out_v, "VEC3", FLOAT, 34962)
    a_nrm = put(out_n, "VEC3", FLOAT, 34962)
    a_uv = put(out_uv, "VEC2", FLOAT, 34962)
    a_idx = put(out_f.reshape(-1), "SCALAR", U32, 34963)

    image_bytes = 0
    for img in gltf.get("images", []):
        view = gltf["bufferViews"][img["bufferView"]]
        start = view.get("byteOffset", 0)
        raw = blob[start:start + view["byteLength"]]
        image_bytes += len(raw)
        pad = (4 - len(raw) % 4) % 4
        views.append({"buffer": 0, "byteOffset": cursor, "byteLength": len(raw)})
        parts.append(raw + b"\x00" * pad)
        cursor += len(raw) + pad
        img["bufferView"] = len(views) - 1

    new_blob = b"".join(parts)
    gltf["bufferViews"] = views
    gltf["accessors"] = accessors
    gltf["buffers"] = [{"byteLength": len(new_blob)}]
    prim["attributes"] = {"POSITION": a_pos, "NORMAL": a_nrm, "TEXCOORD_0": a_uv}
    prim["indices"] = a_idx

    dest = out or (src.with_name("%s_%s.glb" % (src.stem, suffix)) if suffix else src)
    before = src.stat().st_size
    write_glb(dest, gltf, new_blob)
    after = dest.stat().st_size
    print("%s -> %s" % (src.name, dest.name))
    print("  triangles %d -> %d (%.1f%% kept)" % (
        len(f), len(out_f), 100.0 * len(out_f) / len(f)))
    print("  file %.3f MB -> %.3f MB   (images %.3f MB carried through "
          "byte-for-byte)" % (before / 1e6, after / 1e6, image_bytes / 1e6))
    return 0


# --- the audit ----------------------------------------------------------------
def check(target: str) -> int:
    """Everything the handoff spec asks of a delivered piece, measured.

    Not a substitute for looking. `no plinth` in particular is reported as a
    NUMBER (how much of the footprint is a flat slab at the floor) because a
    generated railing shipped with one and nobody caught it off a thumbnail --
    but the rail that passed was passed by eye on the real GPU, and so should
    these be.
    """
    path = glb_path(target)
    d = load_primitive(path)
    gltf, blob = d["gltf"], d["blob"]
    v, f = d["v"], d["f"]
    lo, hi = v.min(axis=0), v.max(axis=0)
    ext = hi - lo
    print("%s" % path)
    print("  triangles      %d" % len(f))
    print("  file           %.3f MB" % (path.stat().st_size / 1e6))
    print("  bbox (m)       %.4f x %.4f x %.4f  (w x h x d)"
          % (ext[0], ext[1], ext[2]))
    print("  ground units   %.1f x %.1f x %.1f" % tuple(ext * 100))
    print("  metres/Y-up    %s" % ("plausible" if 0.2 < ext[1] < 8 else "SUSPECT"))
    print("  depth ratio    %.2f  (depth/width; the handoff asks these to be "
          "wide, not deep)" % (ext[2] / ext[0]))

    ## THE PLINTH PROBE. A base or ground plane is a large flat horizontal slab
    ## sitting in the bottom slice of the model, and it shows up as a big
    ## AREA-weighted share of down-facing triangles down there. Reported, with
    ## the rail's own number alongside as the passing control.
    fv = v[f]
    nrm = np.cross(fv[:, 1] - fv[:, 0], fv[:, 2] - fv[:, 0])
    area = np.linalg.norm(nrm, axis=1) / 2.0
    total = float(area.sum())
    with np.errstate(invalid="ignore", divide="ignore"):
        unit = nrm / np.linalg.norm(nrm, axis=1)[:, None]
    cy = fv[:, :, 1].mean(axis=1)
    floor_band = cy <= lo[1] + ext[1] * 0.03
    flat_down = np.abs(unit[:, 1]) > 0.95
    slab = float(area[floor_band & flat_down].sum())
    print("  floor slab     %.2f%% of surface area is flat and horizontal in the "
          "bottom 3%%" % (100.0 * slab / total))

    ## The lamplit ceiling, measured off the pixels that ship.
    from PIL import Image
    import io
    for mat in gltf.get("materials", []):
        pbr = mat.get("pbrMetallicRoughness", {})
        factor = float(pbr.get("metallicFactor", 1.0))
        mr = pbr.get("metallicRoughnessTexture")
        peak = mean = 1.0
        if mr is not None:
            img = gltf["images"][gltf["textures"][mr["index"]]["source"]]
            view = gltf["bufferViews"][img["bufferView"]]
            start = view.get("byteOffset", 0)
            pic = Image.open(io.BytesIO(
                blob[start:start + view["byteLength"]])).convert("RGB")
            b = np.asarray(pic, dtype=np.float64)[..., 2] / 255.0
            peak, mean = float(b.max()), float(b.mean())
        import importlib.util
        spec = importlib.util.spec_from_file_location(
            "_lamplit", ROOT / "tools" / "lamplit.py")
        lam = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(lam)
        ok = factor * peak <= lam.LAMPLIT_METALLIC_MAX + 1e-6
        print("  metallic       factor %.4f, effective mean %.4f peak %.4f  "
              "-> %s the %.2f lamplit ceiling"
              % (factor, factor * mean, factor * peak,
                 "UNDER" if ok else "**OVER**", lam.LAMPLIT_METALLIC_MAX))
    return 0


# --- the proof ----------------------------------------------------------------
def _welded(v: np.ndarray, f: np.ndarray):
    """Merge vertices by position, so UV seams stop counting as holes.

    glTF splits a vertex everywhere the map is cut, so a textured mesh straight
    off disk has thousands of boundary edges that are not holes at all. Welding
    on position first is what makes the boundary count below mean the thing it
    is being asked to mean.
    """
    import trimesh
    m = trimesh.Trimesh(vertices=v, faces=f, process=False)
    m.merge_vertices()
    return m


def _open_edges(mesh) -> int:
    """Edges used by exactly one face. On a welded mesh, that is a hole rim."""
    e = np.sort(np.asarray(mesh.edges), axis=1)
    _uniq, counts = np.unique(e, axis=0, return_counts=True)
    return int((counts == 1).sum())


def damage(key: str, variant: str) -> int:
    """Compare a trimmed piece against the owner's original, numerically.

    THREE NUMBERS, and each one is a named failure mode rather than a generic
    quality score:

      * BOUNDARY EDGES. A hole punched through a thin member is new open edge.
        The gunner drone's blade failure is exactly this and it is the one thing
        a triangle count cannot see. Counted on the position-welded mesh.
      * COMPONENTS. Rigging lines and shrouds that get eaten do not leave a
        hole, they DISAPPEAR -- the component count falls. A mast that loses a
        line loses a piece.
      * DEVIATION. How far the trimmed surface moved, as a fraction of the
        model's own size. Silhouette loss lives here.

    None of this replaces the renders. It says WHERE to look in them.
    """
    src = glb_path(key)
    dst = glb_path(variant) if Path(variant).suffix == ".glb" else \
        src.with_name("%s_%s.glb" % (src.stem, variant))
    a, b = load_primitive(src), load_primitive(dst)
    ma, mb = _welded(a["v"], a["f"]), _welded(b["v"], b["f"])
    span = float(np.linalg.norm(a["v"].max(axis=0) - a["v"].min(axis=0)))

    ## Deviation measured from the TRIMMED surface back to the original: sample
    ## points on what ships and ask how far each is from what the owner made.
    ##
    ## Point-to-POINT against a dense sampling of the original, not
    ## point-to-triangle: trimesh's exact query wants `rtree`, which is not in
    ## this environment, and 400k samples on a 2 m model sit ~2 mm apart, which
    ## is an order of magnitude finer than the deviations being judged. It
    ## reads slightly HIGH, which is the safe direction for a damage number.
    from scipy.spatial import cKDTree
    pts = mb.sample(60000)
    dist, _ = cKDTree(ma.sample(400000)).query(pts)

    ## Thin-member survival, the gunner-drone question asked directly.
    th_a, th_b = thickness(a["v"], a["f"]), thickness(b["v"], b["f"])
    cut = span * 0.01
    share_a = float((th_a <= cut).mean())
    share_b = float((th_b <= cut).mean())

    ext_a = a["v"].max(axis=0) - a["v"].min(axis=0)
    ext_b = b["v"].max(axis=0) - b["v"].min(axis=0)

    print("%-22s %12s %12s" % (dst.name, "original", "trimmed"))
    print("  %-20s %12d %12d" % ("triangles", len(a["f"]), len(b["f"])))
    print("  %-20s %12d %12d" % ("components", len(ma.split(only_watertight=False)),
                                 len(mb.split(only_watertight=False))))
    print("  %-20s %12d %12d" % ("open boundary edges",
                                 _open_edges(ma), _open_edges(mb)))
    print("  %-20s %12.4f %12.4f" % ("bbox width (m)", ext_a[0], ext_b[0]))
    print("  %-20s %12.4f %12.4f" % ("bbox height (m)", ext_a[1], ext_b[1]))
    print("  %-20s %12.4f %12.4f" % ("bbox depth (m)", ext_a[2], ext_b[2]))
    print("  %-20s %11.2f%% %11.2f%%" % ("faces on thin members",
                                         100 * share_a, 100 * share_b))
    print("  deviation from the owner's surface: mean %.4f m (%.2f%% of the "
          "%.3f m diagonal), p99 %.4f m, max %.4f m"
          % (dist.mean(), 100 * dist.mean() / span, span,
             np.percentile(dist, 99), dist.max()))
    return 0


def main(argv: list[str]) -> int:
    if len(argv) >= 4 and argv[1] == "damage":
        return damage(argv[2], argv[3])
    if len(argv) >= 2 and argv[1] == "plan":
        return plan()
    if len(argv) >= 3 and argv[1] == "thin":
        return thin(argv[2], float(argv[3]) if len(argv) > 3 else 0.01)
    if len(argv) >= 4 and argv[1] == "trim":
        suffix = None
        if "--suffix" in argv:
            suffix = argv[argv.index("--suffix") + 1]
        return trim(argv[2], int(argv[3]), suffix,
                    anyway="--anyway" in argv)
    if len(argv) >= 3 and argv[1] == "check":
        return check(argv[2])
    print(__doc__)
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
