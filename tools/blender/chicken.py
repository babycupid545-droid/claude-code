"""Builds the cartoon chicken in Blender: one smooth mesh per colour region.

Objects (Roblox coords, feet at y=0, facing -z):
  Chicken__Body Chicken__Belly Chicken__Head Chicken__EyeWhite Chicken__Pupil Chicken__Shine
  Chicken__LidL Chicken__LidR Chicken__Cheek Chicken__Beak Chicken__BeakLower Chicken__Comb
  Chicken__Wattle Chicken__WingL Chicken__WingR Chicken__Tail Chicken__LegL Chicken__LegR
"""

import math

import bpy  # noqa: F401  (must load before bmesh)
import bmesh
from mathutils import Vector

import common as C


def beak(name, center, size, down=0.0):
    """A rounded, tapering beak pointing -z."""
    obj = C.uv_sphere(name, (0, 0, 0), (1, 1, 1), 32, 16)
    for v in obj.data.vertices:
        # Blender y = -roblox z; forward (roblox -z) is blender +y.
        fwd = max(0.0, v.co.y)  # 0..0.5
        taper = 1 - fwd * 1.5
        v.co.x *= taper
        v.co.z *= taper
        v.co.z -= fwd * fwd * down
    sx, sy, sz = size
    obj.scale = (sx, sz, sy)
    obj.location = C.R(*center)
    C.apply_all(obj)
    C.shade(obj, True)
    return obj


def leg(name, side):
    """Skinned leg: shin down to an ankle with three front toes and a back toe."""
    x = side * 0.62
    bm = bmesh.new()
    hip = bm.verts.new(C.R(x, 1.3, 0.22))
    knee = bm.verts.new(C.R(x, 0.78, 0.3))
    ankle = bm.verts.new(C.R(x, 0.22, 0.2))
    bm.edges.new((hip, knee))
    bm.edges.new((knee, ankle))
    radii = {hip: 0.24, knee: 0.17, ankle: 0.16}
    for deg in (-30, 0, 30):
        a = math.radians(deg)
        mid = bm.verts.new(C.R(x + math.sin(a) * 0.4, 0.12, 0.2 - math.cos(a) * 0.4))
        tip = bm.verts.new(C.R(x + math.sin(a) * 0.78, 0.08, 0.2 - math.cos(a) * 0.78))
        bm.edges.new((ankle, mid))
        bm.edges.new((mid, tip))
        radii[mid] = 0.1
        radii[tip] = 0.07
    back = bm.verts.new(C.R(x, 0.1, 0.55))
    bm.edges.new((ankle, back))
    radii[back] = 0.07
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    order = list(radii.keys())
    bm.free()
    obj = C.link(bpy.data.objects.new(name, me))
    skin = obj.modifiers.new("skin", "SKIN")
    for i, v in enumerate(obj.data.skin_vertices[0].data):
        r = list(radii.values())[i]
        v.radius = (r, r)
    obj.data.skin_vertices[0].data[0].use_root = True
    sub = obj.modifiers.new("sub", "SUBSURF")
    sub.levels = 2
    C.apply_all(obj)
    C.shade(obj, True)
    return obj


def feather(base, tip, r0, r1, n=6, flat=1.0):
    """Tapered feather from base to tip as a chain of shrinking balls (flat squashes x)."""
    balls = []
    for i in range(n):
        t = i / (n - 1)
        c = tuple(base[k] + (tip[k] - base[k]) * t for k in range(3))
        r = r0 + (r1 - r0) * t
        balls.append((c, r, (flat, 1, 1), None))
    return balls


def build():
    objs = []

    body = C.blob("Chicken__Body", [
        ((0, 2.4, 0.15), 1.0, (1.5, 1.32, 1.7), None),
        ((0, 3.0, 0.8), 0.8, (1.1, 0.85, 1.05), None),
        ((0, 2.9, 1.5), 0.55, (0.8, 0.95, 0.75), (-25, 0, 0)),
        ((0, 2.15, -0.55), 0.9, (1.3, 1.1, 0.95), None),
        ((-0.7, 1.55, 0.25), 0.6, (0.95, 0.95, 1.05), None),
        ((0.7, 1.55, 0.25), 0.6, (0.95, 0.95, 1.05), None),
        ((0, 3.25, -0.4), 0.62, (1.0, 0.9, 1.0), None),
    ], decimate=0.22)
    objs.append(body)

    belly = C.blob("Chicken__Belly", [
        ((0, 2.25, -1.12), 0.85, (1.22, 1.25, 0.5), None),
        ((0, 2.95, -1.08), 0.55, (1.0, 0.65, 0.45), None),
    ], smooth=4)
    objs.append(belly)

    head = C.blob("Chicken__Head", [
        ((0, 3.95, -0.75), 1.1, (1.08, 1.0, 1.02), None),
        ((-0.6, 3.62, -1.08), 0.42, (1, 0.85, 0.85), None),
        ((0.6, 3.62, -1.08), 0.42, (1, 0.85, 0.85), None),
        ((0, 4.75, 0.0), 0.32, (0.75, 1.0, 0.9), (-30, 0, 0)),
        ((0.22, 4.7, 0.15), 0.25, (0.6, 0.9, 0.8), (-40, 0, -20)),
    ], decimate=0.3)
    objs.append(head)

    # Eyes: big glossy whites, pupils, two highlights each.
    whites, pupils, shines, lids = [], [], [], []
    for side in (-1, 1):
        ex, ey, ez = side * 0.45, 4.1, -1.74
        whites.append(C.uv_sphere(f"ew{side}", (ex, ey, ez), (0.6, 0.78, 0.38), rot=(0, side * 20, 0)))
        pupils.append(C.uv_sphere(f"ep{side}", (ex - side * 0.03, ey - 0.03, ez - 0.12), (0.36, 0.5, 0.22), rot=(0, side * 20, 0)))
        shines.append(C.uv_sphere(f"es{side}", (ex - side * 0.1, ey + 0.13, ez - 0.22), (0.14, 0.14, 0.07), 16, 8))
        shines.append(C.uv_sphere(f"es2{side}", (ex + side * 0.05, ey - 0.14, ez - 0.21), (0.07, 0.07, 0.04), 12, 6))
        lid = C.uv_sphere("Chicken__Lid" + ("L" if side < 0 else "R"), (ex, ey, ez + 0.02), (0.62, 0.8, 0.42), rot=(0, side * 20, 0))
        lids.append(lid)
    objs.append(C.join("Chicken__EyeWhite", whites))
    objs.append(C.join("Chicken__Pupil", pupils))
    objs.append(C.join("Chicken__Shine", shines))
    objs.extend(lids)

    cheeks = [C.uv_sphere(f"ch{s}", (s * 0.8, 3.66, -1.42), (0.48, 0.28, 0.14), rot=(0, s * 40, 0)) for s in (-1, 1)]
    objs.append(C.join("Chicken__Cheek", cheeks))

    objs.append(beak("Chicken__Beak", (0, 3.82, -2.0), (0.7, 0.44, 0.95), down=0.25))
    objs.append(beak("Chicken__BeakLower", (0, 3.6, -1.86), (0.54, 0.26, 0.68)))

    objs.append(C.blob("Chicken__Comb", [
        ((0, 4.85, -1.3), 0.26, (0.65, 1, 1), None),
        ((0, 5.08, -0.98), 0.32, (0.65, 1.1, 1), None),
        ((0, 5.18, -0.58), 0.36, (0.65, 1.15, 1), None),
        ((0, 5.05, -0.18), 0.3, (0.65, 1.05, 1), None),
        ((0, 4.75, -0.75), 0.4, (0.6, 0.6, 1.4), None),
    ], voxel=0.035))
    objs.append(C.blob("Chicken__Wattle", [
        ((0, 3.3, -1.75), 0.2, (0.85, 1.2, 0.8), None),
        ((0, 3.08, -1.7), 0.17, (0.85, 1.15, 0.8), None),
    ], voxel=0.03, smooth=4))

    for side, name in ((-1, "Chicken__WingL"), (1, "Chicken__WingR")):
        x = side * 1.42
        balls = [
            ((x, 2.75, -0.1), 0.55, (0.42, 0.85, 1.0), None),
            ((x + side * 0.04, 2.45, 0.4), 0.58, (0.38, 0.85, 1.2), None),
        ]
        # Three flight feathers sweeping back and down.
        for k, (dy, dz) in enumerate(((-0.25, 1.35), (-0.5, 1.2), (-0.75, 1.0))):
            base = (x + side * 0.03, 2.35 - k * 0.12, 0.55)
            tip = (x + side * 0.02, 2.35 + dy, 0.55 + dz)
            balls += feather(base, tip, 0.4, 0.24, 6, flat=0.45)
        objs.append(C.blob(name, balls, voxel=0.04))

    tail = [((0, 2.95, 1.6), 0.45, (0.95, 0.85, 0.75), None)]
    for deg in (-36, -12, 12, 36):
        a = math.radians(deg)
        length = 1.65 - abs(deg) / 90
        base = (math.sin(a) * 0.15, 3.0, 1.65)
        tip = (math.sin(a) * length * 0.75, 3.0 + math.cos(a) * length * 0.85, 1.65 + length * 0.55)
        tail += feather(base, tip, 0.44, 0.26, 7, flat=0.5)
    objs.append(C.blob("Chicken__Tail", tail, voxel=0.04))

    objs.append(leg("Chicken__LegL", -1))
    objs.append(leg("Chicken__LegR", 1))
    return objs


PREVIEW_COLORS = {
    "Body": (250, 250, 246), "Belly": (255, 244, 222), "Head": (250, 250, 246), "EyeWhite": (255, 255, 255),
    "Pupil": (28, 22, 34), "Shine": (255, 255, 255), "LidL": (250, 250, 246), "LidR": (250, 250, 246),
    "Cheek": (255, 140, 160), "Beak": (255, 166, 40), "BeakLower": (230, 140, 30), "Comb": (232, 48, 56),
    "Wattle": (232, 48, 56), "WingL": (240, 240, 236), "WingR": (240, 240, 236), "Tail": (240, 240, 236),
    "LegL": (255, 166, 40), "LegR": (255, 166, 40),
}


if __name__ == "__main__":
    import sys
    C.reset()
    objs = build()
    for o in objs:
        key = o.name.split("__")[1]
        C.set_material(o, C.material(key, PREVIEW_COLORS.get(key, (200, 200, 200)), 0.45))
        if key.startswith("Lid"):
            o.hide_render = True
        print(o.name, C.tri_count(o))
    C.preview_setup(800, 800, 32)
    C.ground(40)
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/chicken.png"
    views = [((-5.5, 5.2, -9.5), "front"), ((10, 4, 1), "side"), ((5, 5.5, 9), "back")]
    for eye, label in views:
        C.camera(eye, (0, 2.8, 0), 50)
        C.render(out.replace(".png", f"_{label}.png"))
