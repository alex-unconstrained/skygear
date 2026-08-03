"""Split a Meshy PART-SEGMENTATION export into a named, budgeted parts kit.

    python tools/segment_parts.py boss "<path to the part-segmentation glb>"

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
     throws them away for the project palette.

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
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
import trimesh

ROOT = Path(__file__).resolve().parent.parent

# The project law, restated from tools/meshy.py rather than imported, because
# that module reaches for an API key at import time. TRI_CEIL is what the
# previous prompted Colossus shipped at (assets/models/boss/meshy.json:
# "remeshed": {"tris": 8000}) and this kit is the same figure at the same
# on-screen height, so it gets the same budget and not a bigger one.
TRI_CEIL = 8000

# No part may fall below this. Area alone would spend nearly everything on the
# torso and leave the head — the part a player reads the machine's FACING from —
# as a lump. Same argument tools/meshy.py's TRI_FLOOR makes for whole props:
# what breaks at the bottom is features, and area has nothing to say about them.
TRI_PART_FLOOR = 220

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

# What the figure is DRAWN at, and it is not a number this file invented:
# scripts/view3d.gd's `boarder_height("BOSS")` is (120 + radius*3) with no
# FIGURE_SCALE row = 330 ground units, WORLD_SCALE 0.01 puts that at 3.30 m,
# and assets/models/boss/meshy.json already records "screen_units": 330.0 for
# the prompted Colossus this kit replaces. The glb is written AT that height so
# the file is self-describing; the renderer re-measures and re-scales anyway
# (SG-45: measure, do not assume), and agreeing with it costs nothing.
DRAWN_METRES = 3.30


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
    centred = [p for p in parts if abs(p["centre"][0]) < 0.15 * span_x]
    on_midline = {id(p) for p in centred}
    lateral = [p for p in parts if id(p) not in on_midline]
    if len(centred) != 3:
        raise SystemExit("expected 3 midline parts, measured %d" % len(centred))

    centred.sort(key=lambda p: -p["volume"])
    torso = centred[0]
    rest = sorted(centred[1:], key=lambda p: p["centre"][2])
    back, head = rest[0], rest[1]
    torso["role"], back["role"], head["role"] = "torso", "back", "head"

    # The arm chain hangs outboard of the leg chain — measured, not assumed:
    # the split falls in the empty band between the two clusters of |x|.
    xs = sorted(abs(p["centre"][0]) for p in lateral)
    gaps = [(xs[i + 1] - xs[i], (xs[i + 1] + xs[i]) / 2) for i in range(len(xs) - 1)]
    split = max(gaps)[1]
    arms = [p for p in lateral if abs(p["centre"][0]) >= split]
    legs = [p for p in lateral if abs(p["centre"][0]) < split]

    for chain, names in ((arms, ["shoulder", "arm", "fist"]), (legs, ["leg", "foot"])):
        # Top down by where the part STARTS, not where its centre is: a foot and
        # a shin overlap through most of their height and only their floors
        # separate them.
        ranked = sorted(chain, key=lambda p: -p["min"][1])
        for i, p in enumerate(ranked):
            p["role"] = names[i // 2]
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
        return np.array([0.0, lo[1], c[2]])
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
    import fast_simplification

    scene = trimesh.load(source)
    parts = _measure(scene)
    print("%s: %d geometries, %d triangles, scene %.4f x %.4f x %.4f" % (
        source.name, len(parts), sum(p["faces_in"] for p in parts),
        *(scene.bounds[1] - scene.bounds[0])))

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
        if target < p["faces_in"]:
            v, f = fast_simplification.simplify(
                np.asarray(mesh.vertices, dtype=np.float32),
                np.asarray(mesh.faces, dtype=np.int32),
                target_count=int(target))
            mesh = trimesh.Trimesh(vertices=v, faces=f, process=False)
        mesh.merge_vertices()
        mesh.fix_normals()

        # Pivot the geometry on its own joint and carry the joint on the node.
        # The scene that consumes this (tools/rig_parts.gd) then gets a hinge
        # for free: rotating the node rotates the part about the place it is
        # actually attached, which is the entire trick segmented movement runs on.
        joint = pivot(p)
        mesh.apply_translation(-joint)
        mesh.apply_scale(to_metres)
        placed = (joint - np.array([0.0, floor, 0.0])) * to_metres

        hexcol, metallic, rough = PALETTE[p["role"]]
        rgb = [int(hexcol[i:i + 2], 16) for i in (0, 2, 4)]
        mesh.visual = trimesh.visual.TextureVisuals(
            material=trimesh.visual.material.PBRMaterial(
                name=p["name"], baseColorFactor=rgb + [255],
                metallicFactor=metallic, roughnessFactor=rough))
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
                           "label; `colour` is what the part actually wears, assigned "
                           "by role out of the project palette."),
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
