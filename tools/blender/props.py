"""Builds the farm props in Blender. Each prop is one or more colour-region objects named
"<Prop>__<ColorKey>", with its base at y=0 and centred on x/z (Roblox coords)."""

import math
import random

import bpy  # noqa: F401
import common as C


def tree_round(name="TreeRound", seed=1):
    rng = random.Random(seed)
    trunk = C.cylinder(f"{name}__Trunk", (0, 0, 0), (0.15, 6.5, 0.1), 0.75, 8, radius_b=0.45, smooth=False)
    leaves = [
        C.ico(f"{name}l0", (0, 8.6, 0), (7.2, 6.4, 7.0), 2, 0.12, rng.randint(0, 999)),
        C.ico(f"{name}l1", (2.3, 7.2, 1.0), (4.8, 4.2, 4.6), 2, 0.12, rng.randint(0, 999)),
        C.ico(f"{name}l2", (-2.0, 7.5, -1.2), (4.6, 4.0, 4.4), 2, 0.12, rng.randint(0, 999)),
        C.ico(f"{name}l3", (0.6, 10.6, 0.4), (4.2, 3.6, 4.0), 2, 0.12, rng.randint(0, 999)),
    ]
    return [trunk, C.join(f"{name}__Leaf", leaves)]


def tree_pine(name="TreePine", seed=2):
    rng = random.Random(seed)
    trunk = C.cylinder(f"{name}__Trunk", (0, 0, 0), (0, 3.2, 0), 0.6, 8, radius_b=0.45, smooth=False)
    tiers = []
    for i, (y0, h, r) in enumerate(((2.6, 5.0, 3.6), (5.4, 4.4, 2.9), (8.0, 3.8, 2.1))):
        cone = C.cylinder(f"{name}c{i}", (0, y0, 0), (0, y0 + h, 0), r, 9, radius_b=0.05, smooth=False)
        for v in cone.data.vertices:
            k = 1 + rng.uniform(-0.08, 0.08)
            v.co.x *= k
            v.co.y *= k
        tiers.append(cone)
    return [trunk, C.join(f"{name}__Pine", tiers)]


def bush(name="Bush", seed=3):
    rng = random.Random(seed)
    parts = [
        C.ico(f"{name}b0", (0, 1.4, 0), (3.6, 2.8, 3.4), 2, 0.12, rng.randint(0, 999)),
        C.ico(f"{name}b1", (1.4, 1.0, 0.6), (2.4, 2.0, 2.2), 2, 0.12, rng.randint(0, 999)),
        C.ico(f"{name}b2", (-1.3, 1.0, -0.5), (2.2, 1.9, 2.2), 2, 0.12, rng.randint(0, 999)),
    ]
    berries = [C.uv_sphere(f"{name}f{i}", (rng.uniform(-1.3, 1.3), rng.uniform(1.6, 2.6), rng.uniform(-1.5, -0.9)), (0.35, 0.35, 0.35), 10, 6) for i in range(5)]
    return [C.join(f"{name}__Bush", parts), C.join(f"{name}__Berry", berries)]


def rock(name, seed, squash=0.65):
    return [C.ico(f"{name}__Rock", (0, 1.0 * squash, 0), (2.2, 2.0 * squash, 1.9), 1, 0.28, seed)]


def flower(name="Flower"):
    stem = C.cylinder(f"{name}__Stem", (0, 0, 0), (0, 1.4, 0), 0.08, 6)
    petals = []
    for i in range(6):
        a = i / 6 * math.tau
        petals.append(C.uv_sphere(f"{name}p{i}", (math.cos(a) * 0.32, 1.45, math.sin(a) * 0.32), (0.42, 0.14, 0.3), 12, 6, rot=(0, -math.degrees(a), 0)))
    center = C.uv_sphere(f"{name}__Center", (0, 1.5, 0), (0.3, 0.2, 0.3), 12, 6)
    return [stem, C.join(f"{name}__Petal", petals), center]


def grass_tuft(name="GrassTuft", seed=4):
    rng = random.Random(seed)
    blades = []
    for i in range(7):
        a = rng.uniform(0, math.tau)
        lean = rng.uniform(0.1, 0.35)
        top = (math.cos(a) * lean * 1.4, rng.uniform(1.0, 1.7), math.sin(a) * lean * 1.4)
        blades.append(C.cylinder(f"{name}g{i}", (math.cos(a) * 0.15, 0, math.sin(a) * 0.15), top, 0.12, 4, radius_b=0.01, smooth=False))
    return [C.join(f"{name}__Grass", blades)]


def hay_bale(name="HayBale"):
    bale = C.rounded_box(f"{name}__Hay", (0, 1.5, 0), (5.0, 3.0, 3.0), 0.35, 3)
    bands = [C.rounded_box(f"{name}b{s}", (s * 1.4, 1.5, 0), (0.25, 3.08, 3.08), 0.12) for s in (-1, 1)]
    return [bale, C.join(f"{name}__HayBand", bands)]


def hay_roll(name="HayRoll"):
    roll = C.cylinder(f"{name}__Hay", (-2.1, 2.5, 0), (2.1, 2.5, 0), 2.5, 28)
    bev = roll.modifiers.new("b", "BEVEL")
    bev.width = 0.45
    bev.segments = 4
    C.apply_all(roll)
    C.shade(roll, True)
    bands = [C.cylinder(f"{name}r{s}", (s * 1.2 - 0.12, 2.5, 0), (s * 1.2 + 0.12, 2.5, 0), 2.56, 28) for s in (-1, 1)]
    swirl = C.cylinder(f"{name}s", (2.12, 2.5, 0), (2.2, 2.5, 0), 1.2, 20)
    return [roll, C.join(f"{name}__HayBand", bands + [swirl])]


def fence(name="Fence"):
    """One 8-stud fence segment along x."""
    parts = []
    for x in (-4, 4):
        parts.append(C.rounded_box(f"{name}p{x}", (x, 1.7, 0), (0.6, 3.4, 0.6), 0.12))
        parts.append(C.cylinder(f"{name}t{x}", (x, 3.4, 0), (x, 3.85, 0), 0.32, 8, radius_b=0.02, smooth=False))
    for y in (1.2, 2.6):
        parts.append(C.rounded_box(f"{name}r{y}", (0, y, 0), (8.6, 0.5, 0.25), 0.1))
    return [C.join(f"{name}__Wood", parts)]


def barn(name="Barn"):
    w, d, h = 22.0, 28.0, 14.0
    walls = C.rounded_box(f"{name}__Red", (0, h / 2, 0), (w, h, d), 0.4, 3)
    # Gambrel roof as an extruded profile across z (we extrude across x, so swap by building on z axis).
    roof = C.extrude_profile(f"{name}roof", [
        (-w / 2 - 1.2, h - 0.2), (-w * 0.36, h + 5.6), (0, h + 8.6), (w * 0.36, h + 5.6), (w / 2 + 1.2, h - 0.2),
        (w / 2 + 0.2, h - 0.6), (w * 0.33, h + 4.9), (0, h + 7.8), (-w * 0.33, h + 4.9), (-w / 2 - 0.2, h - 0.6),
    ], d + 2.0, bevel=0.15, segments=2)
    roof.rotation_euler = (0, 0, math.radians(90))
    C.apply_all(roof)
    roof.name = f"{name}__Roof"
    gable = C.extrude_profile(f"{name}gable", [
        (-w / 2, h - 0.2), (-w * 0.36, h + 5.4), (0, h + 8.2), (w * 0.36, h + 5.4), (w / 2, h - 0.2),
    ], d - 0.4, bevel=0.1, segments=1)
    gable.rotation_euler = (0, 0, math.radians(90))
    C.apply_all(gable)
    walls = C.join(f"{name}__Red", [walls, gable])
    fz = -d / 2 - 0.15
    trims = [
        C.rounded_box(f"{name}t1", (0, h * 0.64, fz), (w * 0.56, 0.7, 0.4), 0.1),
        C.rounded_box(f"{name}t2", (-w * 0.27, h * 0.32, fz), (0.7, h * 0.64, 0.4), 0.1),
        C.rounded_box(f"{name}t3", (w * 0.27, h * 0.32, fz), (0.7, h * 0.64, 0.4), 0.1),
        C.rounded_box(f"{name}x1", (0, h * 0.32, fz - 0.05), (0.6, h * 0.72, 0.35), 0.08, rot=(0, 0, 40)),
        C.rounded_box(f"{name}x2", (0, h * 0.32, fz - 0.05), (0.6, h * 0.72, 0.35), 0.08, rot=(0, 0, -40)),
        C.rounded_box(f"{name}lw", (0, h * 1.06, fz), (w * 0.26, 0.5, 0.4), 0.1),
    ]
    for sx in (-1, 1):
        for sz in (-1, 1):
            trims.append(C.rounded_box(f"{name}c{sx}{sz}", (sx * (w / 2), h / 2, sz * (d / 2)), (0.8, h, 0.8), 0.12))
    dark = [
        C.rounded_box(f"{name}door", (0, h * 0.32, fz + 0.1), (w * 0.5, h * 0.62, 0.3), 0.05),
        C.rounded_box(f"{name}loft", (0, h * 0.9, fz + 0.1), (w * 0.22, h * 0.28, 0.3), 0.05),
    ]
    vane = [C.cylinder(f"{name}vp", (0, h + 8.4, 0), (0, h + 11.0, 0), 0.12, 6),
            C.rounded_box(f"{name}va", (0, h + 10.6, 0), (0.15, 0.9, 2.6), 0.04)]
    return [walls, roof, C.join(f"{name}__White", trims), C.join(f"{name}__Dark", dark), C.join(f"{name}__Metal", vane)]


def silo(name="Silo"):
    body = C.cylinder(f"{name}__Metal", (0, 0, 0), (0, 26, 0), 4.2, 28)
    dome = C.uv_sphere(f"{name}__Roof", (0, 26, 0), (8.6, 6.0, 8.6), 28, 14)
    bands = [C.cylinder(f"{name}b{i}", (0, y - 0.25, 0), (0, y + 0.25, 0), 4.3, 28) for i, y in enumerate((5, 10, 15, 20, 25))]
    ladder = [C.rounded_box(f"{name}l{s}", (s * 0.6, 13, -4.3), (0.2, 26, 0.2), 0.05) for s in (-1, 1)]
    ladder += [C.rounded_box(f"{name}lr{i}", (0, y, -4.3), (1.3, 0.15, 0.15), 0.04) for i, y in enumerate(range(1, 26, 2))]
    return [body, dome, C.join(f"{name}__Band", bands + ladder)]


def windmill(name="Windmill"):
    tower = C.cylinder(f"{name}__Plaster", (0, 0, 0), (0, 24, 0), 6.0, 8, radius_b=3.8, smooth=False)
    cap = C.cylinder(f"{name}cap", (0, 24, 0), (0, 30, 0), 4.6, 8, radius_b=0.3, smooth=False)
    rim = C.cylinder(f"{name}rim", (0, 23.6, 0), (0, 24.6, 0), 4.5, 8, smooth=False)
    door = C.rounded_box(f"{name}door", (0, 2.4, -5.75), (2.6, 4.8, 0.6), 0.2)
    windows = [C.rounded_box(f"{name}w{i}", (0, y, -(6.0 - y * 0.09)), (1.6, 2.2, 0.6), 0.15) for i, y in enumerate((9, 16))]
    hub = C.cylinder(f"{name}hub", (0, 25, -4.0), (0, 25, -5.2), 0.9, 12)
    return [tower, C.join(f"{name}__Roof", [cap, rim]), C.join(f"{name}__Dark", [door, *windows]), C.join(f"{name}__Wood", [hub])]


def windmill_blades(name="WindmillBlades"):
    """Centered on the hub (0, 0, 0), facing -z."""
    frames, sails = [], []
    for i in range(4):
        a = math.radians(i * 90 + 45)
        dx, dy = math.cos(a), math.sin(a)
        frames.append(C.cylinder(f"{name}f{i}", (0, 0, 0), (dx * 13, dy * 13, 0), 0.3, 8))
        # Sail panel beside the spar.
        px, py = -dy, dx
        cx, cy = dx * 7.5 + px * 1.3, dy * 7.5 + py * 1.3
        sail = C.rounded_box(f"{name}s{i}", (cx, cy, 0.05), (2.4, 10.5, 0.2), 0.08, rot=(0, 0, math.degrees(a) - 90))
        sails.append(sail)
        for k in range(1, 6):
            r = 2.5 + k * 2
            bx, by = dx * r + px * 1.3, dy * r + py * 1.3
            frames.append(C.cylinder(f"{name}r{i}{k}", (dx * r, dy * r, -0.1), (bx + px * 1.2, by + py * 1.2, -0.1), 0.1, 6))
    hub = C.uv_sphere(f"{name}h", (0, 0, 0), (2.0, 2.0, 1.2), 16, 8)
    return [C.join(f"{name}__Wood", frames + [hub]), C.join(f"{name}__Sail", sails)]


def farmhouse(name="Farmhouse"):
    w, d, h = 16.0, 12.0, 9.0
    walls = C.rounded_box(f"{name}__Plaster", (0, h / 2, 0), (w, h, d), 0.3)
    roof = C.extrude_profile(f"{name}r", [(-d / 2 - 1.2, h - 0.3), (0, h + 6.0), (d / 2 + 1.2, h - 0.3), (d / 2 + 1.2, h - 0.9), (0, h + 5.3), (-d / 2 - 1.2, h - 0.9)], w + 1.6, bevel=0.12, segments=2)
    gable = C.extrude_profile(f"{name}g", [(-d / 2, h - 0.3), (0, h + 5.6), (d / 2, h - 0.3)], w - 0.4, bevel=0.1, segments=1)
    walls = C.join(f"{name}__Plaster", [walls, gable])
    roof.name = f"{name}__Roof"
    chimney = C.rounded_box(f"{name}__Brick", (w * 0.3, h + 4.5, 1.5), (2.0, 5.0, 2.0), 0.15)
    fz = -d / 2 - 0.1
    windows = [C.rounded_box(f"{name}w{x}", (x, 5.2, fz), (2.8, 2.8, 0.3), 0.15) for x in (-4.5, 4.5)]
    frames = [C.rounded_box(f"{name}wf{x}", (x, 5.2, fz + 0.05), (3.4, 3.4, 0.25), 0.15) for x in (-4.5, 4.5)]
    door = C.rounded_box(f"{name}__Door", (0, 2.8, fz), (2.8, 5.6, 0.35), 0.15)
    porch = [C.rounded_box(f"{name}pf", (0, 0.4, fz - 2.2), (8.0, 0.8, 4.4), 0.15),
             C.rounded_box(f"{name}pr", (0, 6.6, fz - 2.2), (8.6, 0.4, 4.8), 0.15)]
    porch += [C.rounded_box(f"{name}pp{x}", (x, 3.6, fz - 4.0), (0.45, 6.0, 0.45), 0.1) for x in (-3.6, 3.6)]
    return [walls, roof, chimney, C.join(f"{name}__Window", windows), C.join(f"{name}__White", frames), door, C.join(f"{name}__Wood", porch)]


def lamp(name="Lamp"):
    pole = C.cylinder(f"{name}p", (0, 0, 0), (0, 12, 0), 0.32, 10)
    arm = C.cylinder(f"{name}a", (0, 11.6, 0), (0, 12.2, -2.4), 0.18, 8)
    base = C.cylinder(f"{name}b", (0, 0, 0), (0, 1, 0), 0.7, 10, radius_b=0.4)
    head = C.cylinder(f"{name}h", (0, 12.4, -2.6), (0, 11.2, -2.6), 0.4, 10, radius_b=1.0)
    bulb = C.uv_sphere(f"{name}__Glow", (0, 11.1, -2.6), (1.1, 0.6, 1.1), 16, 8)
    return [C.join(f"{name}__Metal", [pole, arm, base, head]), bulb]


def cloud(name, seed):
    rng = random.Random(seed)
    balls = [((0, 0.5, 0), 2.6, (1.6, 0.8, 1.0), None)]
    for _ in range(6):
        balls.append(((rng.uniform(-3.8, 3.8), rng.uniform(0.6, 1.8), rng.uniform(-1.2, 1.2)), rng.uniform(1.3, 2.1), (1, 0.95, 1), None))
    obj = C.blob(f"{name}__Cloud", balls, voxel=0.12, smooth=10, decimate=0.25)
    # Flat bottom.
    for v in obj.data.vertices:
        if v.co.z < 0:
            v.co.z *= 0.3
    return [obj]


def island(name="Island", seed=5):
    """Floating island chunk: grass top (radius 10), dirt rim, rocky underside to y=-16."""
    rng = random.Random(seed)
    top = C.cylinder(f"{name}__Grass", (0, -0.6, 0), (0, 0, 0), 10, 14, smooth=False)
    dirt = C.cylinder(f"{name}__Dirt", (0, -2.6, 0), (0, -0.5, 0), 10.2, 14, radius_b=10.1, smooth=False)
    under = C.cylinder(f"{name}u", (0, -16, 0), (0, -2.5, 0), 1.0, 14, radius_b=9.6, smooth=False)
    for v in under.data.vertices:
        if v.co.z < -0.1 and v.co.z > -14:
            k = 1 + rng.uniform(-0.18, 0.18)
            v.co.x *= k
            v.co.y *= k
    chunks = [under]
    for i in range(6):
        a = rng.uniform(0, math.tau)
        chunks.append(C.ico(f"{name}c{i}", (math.cos(a) * 6, rng.uniform(-9, -4), math.sin(a) * 6), (5, 6, 5), 1, 0.25, rng.randint(0, 999)))
    return [top, dirt, C.join(f"{name}__Rock", chunks)]


def sprinkler(name="Sprinkler"):
    base = C.cylinder(f"{name}b", (0, 0, 0), (0, 0.35, 0), 1.0, 14, radius_b=0.8)
    pipe = C.cylinder(f"{name}p", (0, 0.35, 0), (0, 1.1, 0), 0.22, 10)
    head = C.uv_sphere(f"{name}h", (0, 1.25, 0), (0.6, 0.45, 0.6), 14, 8)
    nozzles = [C.cylinder(f"{name}n{i}", (0, 1.3, 0), (math.cos(i * 2.1) * 0.6, 1.45, math.sin(i * 2.1) * 0.6), 0.08, 6) for i in range(3)]
    return [C.join(f"{name}__Metal", [pipe, head] + nozzles), C.join(f"{name}__Dark", [base])]


def corn(name="Corn", seed=6):
    rng = random.Random(seed)
    stalk = C.cylinder(f"{name}__Stalk", (0, 0, 0), (0.1, 7, 0), 0.22, 8, radius_b=0.12)
    leaves = []
    for i in range(6):
        a = rng.uniform(0, math.tau)
        y = 1.5 + i * 0.9
        tip = (math.cos(a) * 2.2, y + 0.9, math.sin(a) * 2.2)
        leaves.append(C.cylinder(f"{name}l{i}", (0, y, 0), tip, 0.3, 4, radius_b=0.02, smooth=False))
    cobs = [C.uv_sphere(f"{name}c{i}", (0.35 * s, 4.2 + i * 0.6, 0.2), (0.5, 1.4, 0.5), 12, 8, rot=(0, 0, s * 15)) for i, s in enumerate((-1, 1))]
    tassel = C.cylinder(f"{name}t", (0.1, 7, 0), (0.2, 8, 0), 0.15, 5, radius_b=0.02)
    return [stalk, C.join(f"{name}__Leaf", leaves), C.join(f"{name}__Cob", cobs + [tassel])]


def pumpkin(name="Pumpkin"):
    lobes = [C.uv_sphere(f"{name}l{i}", (math.cos(i / 7 * math.tau) * 0.55, 1.0, math.sin(i / 7 * math.tau) * 0.55), (1.3, 1.9, 1.3), 16, 10) for i in range(7)]
    stem = C.cylinder(f"{name}__Stem", (0, 1.8, 0), (0.15, 2.5, 0.05), 0.18, 6, radius_b=0.1)
    return [C.join(f"{name}__Pumpkin", lobes), stem]


def mailbox(name="Mailbox"):
    post = C.rounded_box(f"{name}__Wood", (0, 1.8, 0), (0.5, 3.6, 0.5), 0.08)
    box = C.extrude_profile(f"{name}b", [(-1.2, 3.4), (-1.2, 4.2), (-0.6, 4.6), (0.6, 4.6), (1.2, 4.2), (1.2, 3.4)], 1.4, bevel=0.1)
    box.rotation_euler = (0, 0, math.radians(90))
    C.apply_all(box)
    box.name = f"{name}__Red"
    flag = C.rounded_box(f"{name}__Flag", (0.75, 4.4, 0.2), (0.1, 0.9, 0.45), 0.03)
    return [post, box, flag]


def nest(name="Nest", seed=7):
    rng = random.Random(seed)
    bpy.ops.mesh.primitive_torus_add(major_radius=6.5, minor_radius=1.4, major_segments=40, minor_segments=10)
    t = bpy.context.active_object
    t.name = f"{name}__Straw"
    for v in t.data.vertices:
        k = 1 + rng.uniform(-0.12, 0.12)
        v.co.z *= k
    t.location = C.R(0, 0.9, 0)
    t.scale.z = 0.7
    C.apply_all(t)
    C.shade(t, False)
    eggs = [C.uv_sphere(f"{name}e{i}", (math.cos(a) * 2.2, 1.0, math.sin(a) * 2.2), (1.2, 1.55, 1.2), 16, 10) for i, a in enumerate((0.3, 2.4, 4.4))]
    return [t, C.join(f"{name}__Egg", eggs)]


def golden_egg(name="GoldenEgg"):
    ped = C.cylinder(f"{name}p", (0, 0, 0), (0, 3, 0), 4.5, 16)
    ring = C.cylinder(f"{name}r", (0, 2.8, 0), (0, 3.3, 0), 4.9, 16)
    egg = C.uv_sphere(f"{name}__Gold", (0, 7.4, 0), (6.0, 8.0, 6.0), 32, 16)
    for v in egg.data.vertices:
        if v.co.z > 7.4:
            f = 1 - (v.co.z - 7.4) / 4.0 * 0.18
            v.co.x *= f
            v.co.y *= f
    return [C.join(f"{name}__Stone", [ped, ring]), egg]


def tunnel_arch(name="TunnelArch"):
    """Stone arch 64 wide x 22 tall around a tunnel mouth, facing -z."""
    blocks = []
    w, h = 60.0, 18.0
    for i in range(19):
        a = math.pi * i / 18
        x, y = math.cos(a) * w / 2, 4 + math.sin(a) * (h - 4)
        blocks.append(C.rounded_box(f"{name}b{i}", (x, y, 0), (4.6, 3.6, 4.0), 0.4, rot=(0, 0, math.degrees(a) - 90)))
    for s in (-1, 1):
        blocks.append(C.rounded_box(f"{name}p{s}", (s * w / 2, 2.2, 0), (4.2, 5.2, 4.4), 0.4))
    key = C.rounded_box(f"{name}k", (0, h + 0.4, -0.2), (5.4, 4.6, 4.6), 0.5)
    return [C.join(f"{name}__Stone", blocks + [key])]


def build():
    objs = []
    objs += tree_round("TreeRound", 1)
    objs += tree_round("TreeRound2", 11)
    objs += tree_pine("TreePine", 2)
    objs += bush("Bush", 3)
    objs += rock("Rock1", 21)
    objs += rock("Rock2", 22, 0.8)
    objs += rock("Rock3", 23, 0.5)
    objs += flower("Flower")
    objs += grass_tuft("GrassTuft", 4)
    objs += hay_bale("HayBale")
    objs += hay_roll("HayRoll")
    objs += fence("Fence")
    objs += barn("Barn")
    objs += silo("Silo")
    objs += windmill("Windmill")
    objs += windmill_blades("WindmillBlades")
    objs += farmhouse("Farmhouse")
    objs += lamp("Lamp")
    objs += cloud("Cloud1", 31)
    objs += cloud("Cloud2", 32)
    objs += island("Island", 5)
    objs += sprinkler("Sprinkler")
    objs += corn("Corn", 6)
    objs += pumpkin("Pumpkin")
    objs += mailbox("Mailbox")
    objs += nest("Nest", 7)
    objs += golden_egg("GoldenEgg")
    objs += tunnel_arch("TunnelArch")
    return objs


PREVIEW = {
    "Trunk": (122, 82, 58), "Leaf": (96, 186, 86), "Pine": (52, 140, 92), "Bush": (78, 168, 80), "Berry": (230, 60, 80),
    "Rock": (130, 122, 132), "Stem": (90, 160, 70), "Petal": (255, 120, 160), "Center": (255, 220, 80), "Grass": (96, 180, 80),
    "Hay": (240, 202, 96), "HayBand": (190, 140, 60), "Wood": (176, 124, 84), "Red": (196, 58, 52), "Roof": (84, 74, 88),
    "White": (250, 248, 240), "Dark": (90, 40, 40), "Metal": (190, 196, 206), "Band": (110, 116, 130), "Plaster": (245, 238, 222),
    "Sail": (250, 245, 235), "Window": (150, 210, 245), "Door": (120, 70, 50), "Brick": (170, 90, 70), "Glow": (255, 226, 150),
    "Cloud": (250, 252, 255), "Grass_": (106, 190, 90), "Dirt": (150, 102, 70), "Stalk": (120, 170, 70), "Cob": (250, 210, 80),
    "Pumpkin": (240, 130, 40), "Flag": (230, 50, 50), "Straw": (240, 205, 110), "Egg": (255, 250, 235), "Gold": (255, 200, 60),
    "Stone": (200, 196, 190),
}

if __name__ == "__main__":
    import sys
    C.reset()
    objs = build()
    names = []
    for o in objs:
        n = o.name.split("__")[0]
        if n not in names:
            names.append(n)
    spacing = {"Barn": 34, "Silo": 14, "Windmill": 18, "WindmillBlades": 28, "Farmhouse": 22, "Island": 24, "TunnelArch": 70, "GoldenEgg": 12}
    small = [n for n in names if spacing.get(n, 8) == 8]
    big = [n for n in names if n not in small]
    place = {}
    for row, group, gap in ((0, small, 7), (1, big, None)):
        cursor = 0.0
        for n in group:
            sp = gap or spacing[n]
            place[n] = [cursor + sp / 2, row]
            cursor += sp
        for n in group:
            place[n][0] -= cursor / 2
    for o in objs:
        n, key = o.name.split("__")
        rgb = PREVIEW.get(key, (200, 200, 200))
        C.set_material(o, C.material(f"{n}_{key}", rgb, 0.6, 1.5 if key == "Glow" else 0))
        px, row = place[n]
        if row == 0:
            o.location.x += px * 0.9
            o.location.y += 0
        else:
            o.location.x += px * 0.45
            o.location.y -= 70
            o.scale = (0.45, 0.45, 0.45)
        if n == "WindmillBlades":
            o.location.z += 14 * 0.45
        if n == "Island":
            o.location.z += 16 * 0.45
        print(o.name, C.tri_count(o))
    C.preview_setup(1600, 600, 24)
    C.ground(600, (140, 200, 120))
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/props.png"
    C.camera((0, 70, -110), (0, 0, 40), 30)
    C.render(out)
