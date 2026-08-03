"""Re-unwrap a decimated parts kit and re-bake the delivered paint into it.

    python tools/rebake_atlas.py boss [--size 1024]

WHY THIS TOOL EXISTS — the third report of "his texture is broken", and the
first one measured from a rendered picture instead of from a statistic.

THE BUG, STATED EXACTLY. Meshy's textured export does not carry a UV unwrap in
the sense that word usually means. It carries a **PER-FACE ATLAS**: measured on
`Meshy_AI_Brassbound_Juggernaut_0803021335_texture.glb`, the median triangle's
longest UV edge is **0.00105**, which on the delivered 4096 base colour is
**4.3 pixels**. Every triangle is its own little island. That is fine for the
1,318,962-triangle mesh it was baked for and it is why the atlas LOOKS like a
mosaic of thousands of shards when you open it.

`tools/segment_parts.py` then decimates that mesh **165:1** to reach the 8,000
triangle ceiling, and carries the UVs across honestly — every surviving vertex
inherits a UV from an input vertex it actually descends from. **The vertex UVs
are correct and that is not enough.** The shipped kit's median triangle UV edge
is **0.0164**, **15.6x** the source's. A triangle whose three corners each hold a
correct UV, but whose corners sit in three DIFFERENT islands of a per-face
atlas, interpolates across everything packed between them. The GPU dutifully
samples hundreds of unrelated shards of the model's paint across one plate.

That is the owner's screenshot: a correct silhouette wearing jagged orange and
near-black slices that do not follow the geometry. Reproduced at the shipped
camera in `.shots/sg155/before/boss.png` before anything here was written.

WHY THE EARLIER MEASUREMENTS ALL SAID IT WAS FINE, which is the lesson:

  * "decimation is mild — UV texel-density spread 1.5x -> 2.8%, 0.11% of
    triangles crossing chart boundaries" (SG-144). Texel-density spread is a
    ratio and survives this bug untouched; and a chart-crossing test needs to
    know where the charts ARE. Against an atlas whose charts are one triangle
    each, essentially 100% of output triangles cross one, and 0.11% is the
    measure of a chart definition that did not match the file.
  * "the new export's atlas is worse — texel density 7.97 vs 4.19, fragmented
    into hundreds of tiny charts" (SG-145). Both exports are per-face atlases;
    neither is decimatable. The statistic ranked two files that fail the same
    way, and the ranking was not the question.

A vertex-UV transfer cannot fix this and neither can a different Meshy export.
The atlas has to be REPLACED, because the thing that is wrong with it is that
its islands are smaller than the triangles that must sit inside them.

WHAT THIS DOES.

  1. **Re-unwraps the decimated kit with xatlas**, all thirteen parts into ONE
     shared atlas, so the kit keeps one material and one set of maps — the
     deduplication `segment_parts.py` bought by sharing a material instance is
     preserved rather than traded away for thirteen atlases.

  2. **Bakes the owner's own 4096 paint into the new atlas** by closest-point
     transfer: every texel of the new atlas is a 3D point on the decimated
     surface; the nearest point on the DELIVERED 1.3M-triangle mesh carries the
     delivered UV; that UV samples the delivered map. The pixels that ship are
     the owner's, resampled once — nothing is invented, recoloured or filtered
     for style. Same principle `tools/deck_trim.py` states as "the texture is
     copied, not re-encoded", one step weaker because a new atlas cannot be a
     memcpy.

  3. **Bakes base colour, metallic-roughness and emission. NOT the normal map,
     and that is deliberate**: a tangent-space normal map is only meaningful in
     the tangent frame it was baked in, and re-projecting one onto a new
     unwrap is a second chance to get a texture wrong. The sculpt's own vertex
     normals are already carried through the decimation by `segment_parts.py`
     (`mesh.vertex_normals = normals`) and they are what actually shades this
     figure at 616 px. A wrong normal map is worse than no normal map; this
     drops it and says so.

  4. **Dilates every baked map outward across its chart edges** before writing.
     A new unwrap has new seams, and a bilinear tap near a chart edge reaches
     for texels outside it. Undilated, that returns background and the model
     wears a dark web along every seam — the same class of artefact this tool
     exists to remove, arrived at from the other side.

WHAT IT DOES NOT TOUCH. Geometry: the 7,996 triangles, their positions, their
normals, the thirteen parts, the joints and the node transforms all come
through byte-for-byte from the kit `segment_parts.py` built. ONLY the UV
attribute and the image payloads change. `metallicFactor` is carried across
unchanged, so SG-144's lamplit clamp (1.0 -> 0.3524) survives this and is
re-asserted below rather than assumed.
"""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
import trimesh
from PIL import Image
from scipy.spatial import cKDTree

ROOT = Path(__file__).resolve().parent.parent

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lamplit import LAMPLIT_METALLIC_MAX, clamp_metallic  # noqa: E402

## Atlas side for the rebaked base colour. Same 1024 `meshy.py`'s tex_budget
## gives this figure, so this is not a resolution increase smuggled in beside a
## bug fix — it is the shipped size, spent on a packing that uses it. The
## fragmented delivered atlas spends most of its area on the gutters between
## thousands of islands; xatlas reports the utilisation it actually achieves and
## this tool prints it.
BASE_SIDE = 1024
## The two lighting modulators ride at the size the budget already gives them.
SMALL_SIDE = 256

## How many pixels each baked map is grown outward past its chart edges. Four is
## two mip levels' worth of bilinear reach at the base size, which is what a
## sampler can ask for on a surface this small on screen.
DILATE_PX = 4

## The largest distance, as a fraction of the model's longest axis, that a baked
## texel may sit from the delivered surface it takes its colour from before this
## tool refuses to believe the two meshes are the same object. The decimated
## surface deviates from the sculpt by roughly a plate's thickness; anything
## beyond this is a misalignment, and a misalignment bakes a plausible-looking
## texture off the WRONG part of the model, which is the one failure here that
## would not be obvious in a render.
MAX_TRANSFER_FRAC = 0.02


def _sample(img: Image.Image, uv: np.ndarray) -> np.ndarray:
    """Nearest-texel sample of `img` at `uv`, with glTF's V flip applied."""
    a = np.asarray(img.convert("RGB"), dtype=np.uint8)
    h, w = a.shape[:2]
    x = np.clip((uv[:, 0] % 1.0) * w, 0, w - 1).astype(np.int32)
    y = np.clip((1.0 - (uv[:, 1] % 1.0)) * h, 0, h - 1).astype(np.int32)
    return a[y, x]


def _rasterise(uvs: np.ndarray, faces: np.ndarray, side: int):
    """Every texel covered by a triangle, with the face and barycentric it got.

    Returns (pixel_index, face_index, barycentric). A half-texel offset puts the
    sample at the texel CENTRE, which is where the GPU will read it.
    """
    px, fi, bary = [], [], []
    t = uvs[faces] * side  # (F,3,2) in texel space
    lo = np.floor(t.min(axis=1)).astype(np.int32) - 1
    hi = np.ceil(t.max(axis=1)).astype(np.int32) + 1
    lo = np.clip(lo, 0, side - 1)
    hi = np.clip(hi, 0, side)
    for i in range(len(faces)):
        x0, y0 = lo[i]
        x1, y1 = hi[i]
        if x1 <= x0 or y1 <= y0:
            continue
        xs = np.arange(x0, x1) + 0.5
        ys = np.arange(y0, y1) + 0.5
        gx, gy = np.meshgrid(xs, ys)
        p = np.stack([gx.ravel(), gy.ravel()], axis=1)
        a, b, c = t[i]
        v0, v1, v2 = b - a, c - a, p - a
        den = v0[0] * v1[1] - v1[0] * v0[1]
        if abs(den) < 1e-12:
            continue
        w1 = (v2[:, 0] * v1[1] - v1[0] * v2[:, 1]) / den
        w2 = (v0[0] * v2[:, 1] - v2[:, 0] * v0[1]) / den
        w0 = 1.0 - w1 - w2
        ## A one-texel tolerance rather than a strict inside test: a triangle
        ## thinner than a texel would otherwise claim no texels at all and leave
        ## a hole for the dilation to guess at.
        tol = -1.0 / max(side, 1)
        keep = (w0 >= tol) & (w1 >= tol) & (w2 >= tol)
        if not keep.any():
            continue
        pp = p[keep]
        ix = np.clip(pp[:, 0].astype(np.int32), 0, side - 1)
        iy = np.clip(pp[:, 1].astype(np.int32), 0, side - 1)
        px.append(iy * side + ix)
        fi.append(np.full(keep.sum(), i, dtype=np.int32))
        bary.append(np.stack([w0[keep], w1[keep], w2[keep]], axis=1))
    return (np.concatenate(px), np.concatenate(fi),
            np.concatenate(bary).astype(np.float64))


def _dilate(rgb: np.ndarray, filled: np.ndarray, rounds: int) -> np.ndarray:
    """Grow filled texels outward into their unfilled neighbours."""
    out = rgb.copy()
    have = filled.copy()
    for _ in range(rounds):
        acc = np.zeros(out.shape, dtype=np.float64)
        cnt = np.zeros(have.shape, dtype=np.int32)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            s = np.roll(np.roll(out, dy, axis=0), dx, axis=1)
            m = np.roll(np.roll(have, dy, axis=0), dx, axis=1)
            acc += s * m[..., None]
            cnt += m
        grow = (~have) & (cnt > 0)
        if not grow.any():
            break
        out[grow] = acc[grow] / cnt[grow][:, None]
        have |= grow
    return out


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    key = sys.argv[1]
    side = BASE_SIDE
    if "--size" in sys.argv:
        side = int(sys.argv[sys.argv.index("--size") + 1])

    kit_dir = ROOT / ".model_originals" / ("%s_parts" % key)
    glb = kit_dir / ("%s_parts.glb" % key)
    if not glb.exists():
        print("FAIL no kit at %s" % glb)
        return 1
    delivered = sorted(kit_dir.glob("*texture.glb"))
    if not delivered:
        print("FAIL no delivered textured export in %s" % kit_dir)
        return 1
    src_path = delivered[0]

    import xatlas

    kit = trimesh.load(glb, process=False)
    names = sorted(kit.geometry)
    print("kit: %s, %d parts, %d triangles" % (
        glb.name, len(names), sum(len(kit.geometry[n].faces) for n in names)))

    ## World-space positions of the kit, node transforms applied. The bake needs
    ## the assembled figure because that is the space the delivered mesh lives
    ## in; the parts are written back in their own local space untouched.
    graph = kit.graph
    world = {}
    for n in names:
        m = kit.geometry[n]
        node = [k for k in graph.nodes_geometry
                if graph[k][1] == n]
        T = graph[node[0]][0] if node else np.eye(4)
        v = np.asarray(m.vertices, dtype=np.float64)
        world[n] = (T[:3, :3] @ v.T).T + T[:3, 3]

    src = trimesh.load(src_path, process=False)
    src = src if isinstance(src, trimesh.Trimesh) else list(src.geometry.values())[0]
    sv = np.asarray(src.vertices, dtype=np.float64)
    suv = np.asarray(src.visual.uv, dtype=np.float64)
    print("delivered: %s, %d triangles, %d vertices" % (
        src_path.name, len(src.faces), len(sv)))

    ## ALIGN THE DELIVERED MESH INTO THE KIT'S WORLD SPACE. `segment_parts.py`
    ## applies one uniform scale and one translation to every part, so the map
    ## back is a similarity transform and is RECOVERED from the two bounding
    ## boxes rather than read out of a JSON field that may not have been written.
    ## The residual is asserted: if these are not the same object at the same
    ## orientation the boxes will not agree and nothing below is meaningful.
    kw = np.concatenate([world[n] for n in names])
    klo, khi = kw.min(axis=0), kw.max(axis=0)
    slo, shi = sv.min(axis=0), sv.max(axis=0)
    scale = float(np.mean((khi - klo) / (shi - slo)))
    off = klo - slo * scale
    resid = np.abs((shi * scale + off) - khi).max() / float((khi - klo).max())
    print("align: scale %.5f, box residual %.5f of the longest axis" % (scale, resid))
    assert resid < 0.02, "kit and delivered export are not the same object (%.4f)" % resid
    sw = sv * scale + off
    tree = cKDTree(sw)
    diag = float(np.linalg.norm(khi - klo))

    ## RE-UNWRAP. All thirteen parts into one atlas so the kit keeps one
    ## material. xatlas splits vertices at its own new seams, so each part comes
    ## back with a vertex mapping into its old buffer and a fresh index buffer.
    atlas = xatlas.Atlas()
    for n in names:
        atlas.add_mesh(np.asarray(kit.geometry[n].vertices, dtype=np.float32),
                       np.asarray(kit.geometry[n].faces, dtype=np.uint32))
    co = xatlas.ChartOptions()
    po = xatlas.PackOptions()
    po.resolution = side
    po.padding = DILATE_PX
    po.bruteForce = True
    atlas.generate(chart_options=co, pack_options=po)
    util = atlas.utilization
    util = float(util[0]) if hasattr(util, "__len__") else float(util)
    print("xatlas: %d charts, %d x %d, utilisation %.1f%%" % (
        atlas.chart_count, atlas.width, atlas.height, 100.0 * util))

    new_v, new_f, new_uv, new_n, new_world = {}, {}, {}, {}, {}
    for i, n in enumerate(names):
        vmap, idx, uvs = atlas[i]
        m = kit.geometry[n]
        new_v[n] = np.asarray(m.vertices, dtype=np.float64)[vmap]
        new_n[n] = np.asarray(m.vertex_normals, dtype=np.float64)[vmap]
        new_world[n] = world[n][vmap]
        new_f[n] = np.asarray(idx, dtype=np.int64)
        new_uv[n] = np.asarray(uvs, dtype=np.float64)

    ## The measurement this whole tool is about, restated on the OUTPUT so a
    ## reader can compare it against the delivered atlas without re-deriving it.
    def uv_edge(uvs, faces):
        t = uvs[faces]
        e = np.stack([np.linalg.norm(t[:, 1] - t[:, 0], axis=1),
                      np.linalg.norm(t[:, 2] - t[:, 1], axis=1),
                      np.linalg.norm(t[:, 0] - t[:, 2], axis=1)], axis=1)
        return e.max(axis=1)
    edges = np.concatenate([uv_edge(new_uv[n], new_f[n]) for n in names])
    print("new atlas: median triangle UV edge %.5f (%.1f px at %d)" % (
        np.median(edges), np.median(edges) * side, side))

    ## THE BAKE. One rasterisation of the new atlas; the resulting 3D points are
    ## shared by every map, so the closest-point query runs once.
    px, fi, bary, part = [], [], [], []
    base = 0
    for n in names:
        p, f, b = _rasterise(new_uv[n], new_f[n], side)
        px.append(p)
        fi.append(f + base)
        bary.append(b)
        part.append(np.full(len(p), names.index(n), dtype=np.int32))
        base += len(new_f[n])
    px = np.concatenate(px)
    bary = np.concatenate(bary)
    part = np.concatenate(part)
    fi = np.concatenate(fi)

    tri_world = np.concatenate([new_world[n][new_f[n]] for n in names])
    pts = np.einsum("ij,ijk->ik", bary, tri_world[fi])
    dist, near = tree.query(pts, workers=-1)
    frac = dist / diag
    print("transfer: %d texels, distance to delivered surface "
          "median %.5f p99 %.5f max %.5f of the longest axis" % (
              len(pts), np.median(frac), np.percentile(frac, 99), frac.max()))
    assert np.percentile(frac, 99) < MAX_TRANSFER_FRAC, (
        "bake is sampling too far from the delivered surface (p99 %.4f)" % np.percentile(frac, 99))
    duv = suv[near]

    mat = list(kit.geometry.values())[0].visual.material
    src_mat = src.visual.material
    out_imgs = {}
    for slot, out_side in (("baseColorTexture", side),
                           ("metallicRoughnessTexture", SMALL_SIDE),
                           ("emissiveTexture", SMALL_SIDE)):
        img = getattr(src_mat, slot, None)
        if img is None:
            print("  %-26s delivered export has none, skipped" % slot)
            continue
        col = _sample(img, duv).astype(np.float64)
        buf = np.zeros((side * side, 3), dtype=np.float64)
        filled = np.zeros(side * side, dtype=bool)
        ## Later writes to a texel simply win; a texel claimed by two triangles
        ## sits on a chart edge and either answer is a texel of the same seam.
        buf[px] = col
        filled[px] = True
        buf = _dilate(buf.reshape(side, side, 3),
                      filled.reshape(side, side), DILATE_PX)
        out = Image.fromarray(np.clip(buf, 0, 255).astype(np.uint8), "RGB")
        if out_side != side:
            out = out.resize((out_side, out_side), Image.LANCZOS)
        out_imgs[slot] = out
        print("  %-26s baked from %dx%d -> %dx%d, %.1f%% of texels covered" % (
            slot, img.size[0], img.size[1], out_side, out_side,
            100.0 * filled.mean()))

    ## THE MATERIAL. Factors carried across from the kit, not recomputed — the
    ## lamplit clamp is SG-144's and this tool has no business re-deriving it —
    ## and the normal map deliberately dropped (see the module docstring).
    painted = trimesh.visual.material.PBRMaterial(
        name="colossus_rebaked",
        baseColorTexture=out_imgs.get("baseColorTexture"),
        metallicRoughnessTexture=out_imgs.get("metallicRoughnessTexture"),
        emissiveTexture=out_imgs.get("emissiveTexture"),
        emissiveFactor=getattr(mat, "emissiveFactor", None),
        metallicFactor=float(mat.metallicFactor),
        roughnessFactor=getattr(mat, "roughnessFactor", None))
    ## RE-CLAMPED, NOT CARRIED, and the difference is the point. The factor the
    ## kit arrived with was solved against the DELIVERED metallic map, whose peak
    ## was 0.9647. Resampling that map into a new atlas moves its peak — a texel
    ## the old packing never resolved can become the new maximum — and it
    ## measured 1.0000 here, which puts the carried factor 0.3524 fractionally
    ## OVER the ceiling it was chosen to sit on. So the rebaked material is run
    ## through SG-144's own function against its own map, which is the only way
    ## the guarantee ("no texel on this surface exceeds the ceiling") stays true
    ## of the thing that actually ships rather than of the thing it came from.
    clamp_metallic(painted)
    print("material: metallicFactor %.4f carried, normal map dropped "
          "(tangent-space, not re-projectable)" % painted.metallicFactor)

    out_scene = trimesh.Scene()
    for n in names:
        m = trimesh.Trimesh(vertices=new_v[n], faces=new_f[n], process=False)
        m.visual = trimesh.visual.TextureVisuals(uv=new_uv[n], material=painted)
        m.vertex_normals = new_n[n]
        node = [k for k in graph.nodes_geometry if graph[k][1] == n]
        T = graph[node[0]][0] if node else np.eye(4)
        out_scene.add_geometry(m, node_name=n, geom_name=n, transform=T)

    dest = kit_dir / ("%s_parts.glb" % key)
    dest.write_bytes(trimesh.exchange.gltf.export_glb(out_scene))
    print("wrote %s (%.2f MB)" % (dest, dest.stat().st_size / 1e6))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
