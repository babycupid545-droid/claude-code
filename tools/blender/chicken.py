"""Builds the chicken in Blender: a plump low-poly hen, one mesh per colour region.

Objects (Roblox coords, feet at y=0, facing -z):
  Chicken__Body Chicken__Head Chicken__Pupil Chicken__LidL Chicken__LidR Chicken__Beak
  Chicken__BeakLower Chicken__Comb Chicken__WingL Chicken__WingR Chicken__Tail
  Chicken__LegL Chicken__LegR
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


def facet(obj, tris, angle=32):
    """Low-poly look: decimate to about `tris` triangles, then smooth only gentle angles so
    the big facets read as crisp edges (like a hand-made low-poly model)."""
    current = C.tri_count(obj)
    if current > tris:
        dec = obj.modifiers.new("facet", "DECIMATE")
        dec.ratio = tris / current
        C.apply_all(obj)
    C.activate(obj)
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(angle))
    return obj


def thin_leg(name, side):
    """Thin bird leg: thigh stub, shin bending back, long splayed toes and a back toe."""
    x = side * 0.55
    bm = bmesh.new()
    hip = bm.verts.new(C.R(x, 1.35, 0.25))
    knee = bm.verts.new(C.R(x, 0.85, 0.42))
    ankle = bm.verts.new(C.R(x, 0.16, 0.18))
    bm.edges.new((hip, knee))
    bm.edges.new((knee, ankle))
    radii = {hip: 0.15, knee: 0.1, ankle: 0.09}
    for deg in (-32, 0, 32):
        a = math.radians(deg)
        mid = bm.verts.new(C.R(x + math.sin(a) * 0.45, 0.07, 0.18 - math.cos(a) * 0.45))
        tip = bm.verts.new(C.R(x + math.sin(a) * 0.95, 0.04, 0.18 - math.cos(a) * 0.95))
        bm.edges.new((ankle, mid))
        bm.edges.new((mid, tip))
        radii[mid] = 0.06
        radii[tip] = 0.035
    back = bm.verts.new(C.R(x, 0.05, 0.55))
    bm.edges.new((ankle, back))
    radii[back] = 0.04
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = C.link(bpy.data.objects.new(name, me))
    obj.modifiers.new("skin", "SKIN")
    values = list(radii.values())
    for i, v in enumerate(obj.data.skin_vertices[0].data):
        v.radius = (values[i], values[i])
    obj.data.skin_vertices[0].data[0].use_root = True
    sub = obj.modifiers.new("sub", "SUBSURF")
    sub.levels = 1
    C.apply_all(obj)
    C.shade(obj, True)
    return obj


def build():
    """A plump low-poly hen: egg-shaped body flowing into the head, shell-like wings, a
    pointed upturned tail, bead eyes, a small beak and comb, and thin legs with long toes."""
    objs = []

    body = C.blob("Chicken__Body", [
        ((0, 2.4, 0.2), 1.0, (1.5, 1.3, 1.85), None),       # main egg
        ((0, 2.1, -0.55), 1.0, (1.38, 1.15, 1.05), None),   # full chest
        ((0, 3.2, -0.6), 0.9, (1.15, 1.15, 1.0), None),     # thick neck flowing into the head
        ((0, 3.0, 1.0), 0.8, (1.1, 1.0, 1.0), None),        # back rising toward the tail
        ((0, 1.6, 0.2), 0.8, (1.35, 0.7, 1.4), None),       # round underside
    ], voxel=0.05, smooth=6, decimate=None)
    objs.append(facet(body, 300, 28))

    head = C.blob("Chicken__Head", [
        ((0, 3.95, -0.72), 0.86, (1.0, 1.05, 1.0), None),
        ((0, 3.55, -0.7), 0.82, (1.05, 0.9, 1.0), None),
    ], voxel=0.05, smooth=6, decimate=None)
    objs.append(facet(head, 170, 28))

    # Pointed tail sweeping up and back.
    tail = [((0, 3.1, 1.4), 0.8, (0.6, 1.0, 0.95), None)]
    tail += feather((0, 3.3, 1.55), (0, 4.85, 2.2), 0.82, 0.1, 9, flat=0.42)
    objs.append(facet(C.blob("Chicken__Tail", tail, voxel=0.045, smooth=3, decimate=None), 90, 28))

    # Shell-like wings hugging the sides.
    for side, name in ((-1, "Chicken__WingL"), (1, "Chicken__WingR")):
        x = side * 1.3
        wing = C.blob(name, [
            ((x * 1.04, 2.45, 0.4), 1.0, (0.32, 0.95, 1.35), (-12, side * 6, 0)),
            ((x * 1.04 + side * 0.03, 2.15, 1.1), 0.62, (0.3, 0.85, 1.1), (-25, side * 6, 0)),
        ], voxel=0.04, smooth=4, decimate=None)
        objs.append(facet(wing, 80, 28))

    # Bead eyes and their blink lids.
    beads, lids = [], []
    for side in (-1, 1):
        ex, ey, ez = side * 0.5, 4.05, -1.43
        beads.append(C.uv_sphere(f"eye{side}", (ex, ey, ez), (0.22, 0.24, 0.2), 10, 6))
        lid = C.uv_sphere("Chicken__Lid" + ("L" if side < 0 else "R"), (ex, ey, ez + 0.02), (0.28, 0.3, 0.25), 10, 6)
        lids.append(lid)
    objs.append(C.join("Chicken__Pupil", beads))
    objs.extend(lids)

    objs.append(facet(beak("Chicken__Beak", (0, 3.72, -1.66), (0.5, 0.3, 0.6), down=0.35), 50))
    objs.append(facet(beak("Chicken__BeakLower", (0, 3.57, -1.55), (0.38, 0.17, 0.4)), 30))

    comb = C.blob("Chicken__Comb", [
        ((0, 4.72, -1.05), 0.22, (0.62, 1.0, 1.0), None),
        ((0, 4.9, -0.72), 0.27, (0.62, 1.1, 1.0), None),
        ((0, 4.82, -0.38), 0.23, (0.62, 1.0, 1.0), None),
        ((0, 4.62, -0.7), 0.3, (0.55, 0.6, 1.45), None),
    ], voxel=0.035, smooth=3, decimate=None)
    objs.append(facet(comb, 60, 28))

    objs.append(facet(thin_leg("Chicken__LegL", -1), 260, 50))
    objs.append(facet(thin_leg("Chicken__LegR", 1), 260, 50))
    return objs


PREVIEW_COLORS = {
    "Body": (228, 216, 194), "Belly": (255, 244, 222), "Head": (228, 216, 194), "EyeWhite": (255, 255, 255),
    "Pupil": (20, 16, 18), "Shine": (255, 255, 255), "LidL": (228, 216, 194), "LidR": (228, 216, 194),
    "Cheek": (255, 140, 160), "Beak": (255, 166, 40), "BeakLower": (230, 140, 30), "Comb": (214, 52, 60),
    "Wattle": (232, 48, 56), "WingL": (222, 209, 186), "WingR": (222, 209, 186), "Tail": (222, 209, 186),
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
    bpy.context.scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.45
    C.ground(40)
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/chicken.png"
    views = [((-5.5, 5.2, -9.5), "front"), ((10, 4, 1), "side"), ((5, 5.5, 9), "back")]
    for eye, label in views:
        C.camera(eye, (0, 2.8, 0), 50)
        C.render(out.replace(".png", f"_{label}.png"))
