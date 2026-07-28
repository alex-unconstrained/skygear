"""Bring the captain out of her T-pose.

Meshy exports a static, unrigged mesh in a T-pose: arms straight out from the
shoulders. That is a fine thing to hand to a rigger and a bad thing to stand on
a deck — a character with her arms held out horizontally reads as a mannequin no
matter how good the texture is, and this one is the thing the player looks at
for a whole run.

There is no skeleton, so there is nothing to pose. What there IS, is a clean
separation in the geometry: the body occupies |x| < 0.24 and the arms run out to
|x| = 0.95, with a trough between them. So the arms can be rotated down about a
shoulder pivot directly on the vertices, with the angle ramped in across the
joint so the shoulder bends instead of tearing.

This is a weighted vertex deform, which is what a skin cluster is — it just has
one bone per side and a hand-authored falloff. It is not a substitute for a rig.
If Meshy can rig and export an idle / run / swing set as glTF, that replaces all
of this and gives us a captain who moves; see DESIGN.md 13e.

    python tools/pose_captain.py <source.obj> <dest.obj>
"""

import io
import math
import sys

# The joint. `INNER` is where the deform starts to take, `OUTER` where it is at
# full strength — measured off the vertex histogram, where the body ends at 0.24
# and the arm proper starts around 0.34.
INNER = 0.22
OUTER = 0.36
SHOULDER_Y = 0.30           # mean height of the arm mass
DROP = math.radians(52.0)   # how far the arms come down
FORWARD = math.radians(14.0)  # and slightly in front of her, so it is a stance


def smoothstep(a, b, x):
    if b <= a:
        return 0.0
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3.0 - 2.0 * t)


def pose(x, y, z):
    side = 1.0 if x >= 0.0 else -1.0
    weight = smoothstep(INNER, OUTER, abs(x))
    if weight <= 0.0:
        return x, y, z
    px = side * INNER
    dx, dy = x - px, y - SHOULDER_Y
    # down, about the shoulder, in the plane of the body
    a = -DROP * weight * side
    rx = dx * math.cos(a) - dy * math.sin(a)
    ry = dx * math.sin(a) + dy * math.cos(a)
    x2, y2 = px + rx, SHOULDER_Y + ry
    # and forward, so the arms hang in front rather than flat at her sides
    b = FORWARD * weight * side
    dxx = x2 - px
    rx2 = dxx * math.cos(b) - z * math.sin(b)
    rz2 = dxx * math.sin(b) + z * math.cos(b)
    return px + rx2, y2, rz2


def main(src, dest):
    out = []
    moved = 0
    for line in io.open(src, encoding="utf-8", errors="ignore"):
        if line.startswith("v "):
            parts = line.split()
            x, y, z = float(parts[1]), float(parts[2]), float(parts[3])
            nx, ny, nz = pose(x, y, z)
            if (nx, ny, nz) != (x, y, z):
                moved += 1
            out.append("v %.6f %.6f %.6f\n" % (nx, ny, nz))
        elif line.startswith("vn "):
            # Normals are re-derived on import (`generate_tangents`), and a
            # rotated vertex with an unrotated normal lights wrongly. Dropping
            # them is cheaper and more correct than rotating them by a weight
            # they were never authored against.
            continue
        elif line.startswith("mtllib"):
            out.append("mtllib captain.mtl\n")
        elif line.startswith("f "):
            # faces reference v/vt/vn — strip the now-absent normal index
            fields = ["f"]
            for chunk in line.split()[1:]:
                bits = chunk.split("/")
                fields.append("/".join(bits[:2]))
            out.append(" ".join(fields) + "\n")
        else:
            out.append(line)
    io.open(dest, "w", encoding="utf-8").writelines(out)
    print("posed %d of %d vertices" % (moved, sum(1 for l in out if l.startswith("v "))))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
