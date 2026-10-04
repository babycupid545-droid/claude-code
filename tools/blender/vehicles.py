"""Builds the road vehicles in Blender: smooth, bevelled cartoon cars.

Every vehicle faces -z, sits on y=0, is ~8 wide x ~14 long (the harvester is bigger), and is
split into colour regions: <Name>__Body (recoloured per variant), __Glass, __Tire, __Rim,
__Light (headlights), __Tail (tail lights), __Trim (bumpers, grille), plus extras.
"""

import math

import bpy  # noqa: F401
import common as C

W = 8.0


def wheels(prefix, zs, radius=1.45, width=1.3, x=None, y=None):
    tires, rims = [], []
    xx = x if x is not None else W / 2 - width / 2 + 0.15
    yy = y if y is not None else radius
    for z in zs:
        for side in (-1, 1):
            t = C.cylinder(f"{prefix}t", (side * (xx - width / 2), yy, z), (side * (xx + width / 2), yy, z), radius, 28)
            bev = t.modifiers.new("b", "BEVEL")
            bev.width = 0.25
            bev.segments = 3
            C.apply_all(t)
            C.shade(t, True)
            tires.append(t)
            rims.append(C.cylinder(f"{prefix}r", (side * (xx + width / 2 - 0.05), yy, z), (side * (xx + width / 2 + 0.08), yy, z), radius * 0.55, 20))
            rims.append(C.cylinder(f"{prefix}h", (side * (xx + width / 2), yy, z), (side * (xx + width / 2 + 0.16), yy, z), radius * 0.2, 12))
    return [C.join(f"{prefix}__Tire", tires), C.join(f"{prefix}__Rim", rims)]


def lights(prefix, front_z, back_z, y, spread=2.7, size=(1.6, 0.75, 0.3)):
    heads = [C.rounded_box(f"{prefix}hl", (s * spread, y, front_z - 0.05), size, 0.12) for s in (-1, 1)]
    tails = [C.rounded_box(f"{prefix}tl", (s * spread, y, back_z + 0.05), (size[0] * 0.9, size[1] * 0.9, size[2]), 0.12) for s in (-1, 1)]
    return [C.join(f"{prefix}__Light", heads), C.join(f"{prefix}__Tail", tails)]


def bumpers(prefix, front_z, back_z, y=1.25, width=W - 0.2):
    parts = [
        C.rounded_box(f"{prefix}bf", (0, y, front_z - 0.1), (width, 0.75, 0.6), 0.25),
        C.rounded_box(f"{prefix}bb", (0, y, back_z + 0.1), (width, 0.75, 0.6), 0.25),
        C.rounded_box(f"{prefix}gr", (0, y + 0.95, front_z - 0.02), (W * 0.42, 0.75, 0.2), 0.08),
    ]
    return C.join(f"{prefix}__Trim", parts)


def sedan(prefix="Sedan", hatch=False):
    back = 6.2 if hatch else 7
    body = C.extrude_profile(f"{prefix}__Body", [
        (-7, 0.95), (-7, 2.35), (-6.4, 2.85), (-3.0, 3.15), (back - 0.6, 3.15), (back, 2.7), (back, 0.95),
    ], W, bevel=0.45, segments=4)
    cab_back = back - (0.4 if hatch else 1.6)
    cab_len = cab_back - (-2.8)
    glass = C.rounded_box(f"{prefix}__Glass", (0, 3.15 + 0.85, (-2.8 + cab_back) / 2), (W - 1.0, 1.7, cab_len),
                          0.35, 4, taper_top=(0.86, 0.66))
    roof = C.rounded_box(f"{prefix}roof", (0, 4.85, (-2.8 + cab_back) / 2 + 0.15), (W - 1.7, 0.32, cab_len * 0.66), 0.14)
    body = C.join(f"{prefix}__Body", [body, roof])
    return [body, glass, bumpers(prefix, -7, back), *wheels(prefix, (-4.5, 4.3)), *lights(prefix, -7, back, 2.3)]


def sports(prefix="SportsCar"):
    body = C.extrude_profile(f"{prefix}__Body", [
        (-7, 0.8), (-7, 1.55), (-6.6, 1.8), (-2.2, 2.55), (4.6, 2.6), (7, 2.35), (7, 0.8),
    ], W, bevel=0.45, segments=4)
    glass = C.rounded_box(f"{prefix}__Glass", (0, 2.55 + 0.8, 1.2), (W - 1.4, 1.6, 4.8), 0.35, 4, taper_top=(0.8, 0.55))
    spoiler = [
        C.rounded_box(f"{prefix}sp", (0, 3.55, 6.4), (W, 0.25, 1.3), 0.1),
        C.rounded_box(f"{prefix}sl", (-2.8, 3.05, 6.4), (0.3, 1.0, 0.4), 0.08),
        C.rounded_box(f"{prefix}sr", (2.8, 3.05, 6.4), (0.3, 1.0, 0.4), 0.08),
    ]
    trim = C.join(f"{prefix}__Trim", [bumpers(prefix, -7, 7, 1.05), *spoiler])
    stripe = C.rounded_box(f"{prefix}__Stripe", (0, 2.62, -0.5), (1.4, 0.06, 11.5), 0.02)
    return [body, glass, trim, stripe, *wheels(prefix, (-4.5, 4.6), 1.35), *lights(prefix, -7, 7, 1.7, 2.8, (1.8, 0.5, 0.3))]


def pickup(prefix="Pickup"):
    body = C.extrude_profile(f"{prefix}__Body", [
        (-7, 0.95), (-7, 2.6), (-6.4, 3.05), (7, 3.05), (7, 0.95),
    ], W, bevel=0.4, segments=4)
    cab = C.rounded_box(f"{prefix}cab", (0, 3.05 + 1.25, -1.6), (W - 0.6, 2.5, 4.0), 0.4, 4, taper_top=(0.95, 0.85))
    glass = C.rounded_box(f"{prefix}__Glass", (0, 3.05 + 1.3, -1.75), (W - 0.45, 1.6, 3.6), 0.3, 3, taper_top=(0.95, 0.8))
    bed_walls = [
        C.rounded_box(f"{prefix}w1", (-(W / 2 - 0.3), 3.75, 3.4), (0.5, 1.4, 6.6), 0.15),
        C.rounded_box(f"{prefix}w2", ((W / 2 - 0.3), 3.75, 3.4), (0.5, 1.4, 6.6), 0.15),
        C.rounded_box(f"{prefix}w3", (0, 3.75, 6.75), (W - 0.2, 1.4, 0.5), 0.15),
    ]
    body = C.join(f"{prefix}__Body", [body, cab, *bed_walls])
    hay = C.rounded_box(f"{prefix}__Hay", (0, 3.95, 3.4), (4.2, 1.8, 2.8), 0.35, 3)
    return [body, glass, hay, bumpers(prefix, -7, 7), *wheels(prefix, (-4.4, 4.4), 1.55), *lights(prefix, -7, 7, 2.5)]


def van(prefix="Van", ice_cream=False):
    body = C.extrude_profile(f"{prefix}__Body", [
        (-7, 0.95), (-7, 2.9), (-5.6, 5.4), (-5.0, 5.8), (7, 5.8), (7, 0.95),
    ], W, bevel=0.55, segments=4)
    windshield = C.rounded_box(f"{prefix}ws", (0, 4.2, -6.1), (W - 1.2, 1.6, 1.6), 0.25, 3, rot=(-38, 0, 0))
    sides = [C.rounded_box(f"{prefix}sw{s}", (s * (W / 2 - 0.02), 4.4, -2.5), (0.12, 1.4, 4.0), 0.06) for s in (-1, 1)]
    glass = C.join(f"{prefix}__Glass", [windshield, *sides])
    objs = [body, glass, bumpers(prefix, -7, 7), *wheels(prefix, (-4.4, 4.6)), *lights(prefix, -7, 7, 2.3)]
    if ice_cream:
        stripe = C.rounded_box(f"{prefix}__Stripe", (0, 2.6, 0.6), (W + 0.06, 0.8, 12.5), 0.05)
        cone = C.cylinder(f"{prefix}cone", (0, 5.8, 2), (0, 8.4, 2), 0.05, 20, radius_b=1.0)
        cone.name = f"{prefix}__Cone"
        scoop = C.blob(f"{prefix}__Scoop", [
            ((0, 8.6, 2), 1.15, (1, 0.85, 1), None),
            ((0.4, 9.3, 2.2), 0.6, (1, 1, 1), None),
        ], voxel=0.06)
        cherry = C.uv_sphere(f"{prefix}__Cherry", (0, 9.8, 1.9), (0.5, 0.5, 0.5))
        objs += [stripe, cone, scoop, cherry]
    else:
        rack = [C.rounded_box(f"{prefix}rk{i}", (0, 6.05, z), (W - 1.4, 0.2, 0.3), 0.06) for i, z in enumerate((-2, 0.5, 3))]
        rails = [C.rounded_box(f"{prefix}rl{s}", (s * (W / 2 - 0.9), 6.05, 0.5), (0.3, 0.3, 6.0), 0.08) for s in (-1, 1)]
        objs.append(C.join(f"{prefix}__Rack", rack + rails))
    return objs


def tractor(prefix="Tractor"):
    hood = C.rounded_box(f"{prefix}hood", (0, 3.2, -3.2), (3.8, 2.8, 7.0), 0.5, 4, taper_top=(0.9, 0.95))
    seatbase = C.rounded_box(f"{prefix}sb", (0, 2.6, 2.6), (5.2, 0.8, 5.0), 0.3)
    fenders = [C.rounded_box(f"{prefix}fd{s}", (s * 3.2, 4.8, 3.4), (1.9, 0.4, 4.4), 0.2) for s in (-1, 1)]
    body = C.join(f"{prefix}__Body", [hood, seatbase, *fenders])
    roof = C.rounded_box(f"{prefix}__Roof", (0, 7.4, 2.6), (5.6, 0.35, 5.6), 0.2)
    posts = [C.rounded_box(f"{prefix}p{i}", (sx * 2.4, 5.0, sz), (0.3, 4.6, 0.3), 0.08) for i, (sx, sz) in enumerate(((-1, 0.4), (1, 0.4), (-1, 4.8), (1, 4.8)))]
    exhaust = C.cylinder(f"{prefix}ex", (0.9, 4.4, -4.6), (0.9, 6.4, -4.6), 0.25, 14)
    grille = C.rounded_box(f"{prefix}gr", (0, 3.1, -6.75), (3.2, 2.2, 0.2), 0.1)
    trim = C.join(f"{prefix}__Trim", [*posts, exhaust, grille])
    seat = C.rounded_box(f"{prefix}__Seat", (0, 3.7, 3.4), (1.9, 1.4, 1.5), 0.3)
    front = wheels(prefix + "F", (-4.6,), 1.25, 1.0, x=2.3)
    rear = wheels(prefix + "R", (3.4,), 2.35, 1.6, x=3.3)
    tire = C.join(f"{prefix}__Tire", [front[0], rear[0]])
    rim = C.join(f"{prefix}__Rim", [front[1], rear[1]])
    heads = [C.rounded_box(f"{prefix}hl{s}", (s * 1.2, 3.6, -6.8), (0.8, 0.8, 0.25), 0.1) for s in (-1, 1)]
    return [body, roof, trim, seat, tire, rim, C.join(f"{prefix}__Light", heads)]


def harvester(prefix="Harvester"):
    """Combine harvester for the median: 22 wide reel at the front, ~20 long, ~9 tall."""
    body = C.rounded_box(f"{prefix}b1", (0, 4.5, 2.5), (9.0, 5.0, 11.0), 0.6, 4)
    hopper = C.rounded_box(f"{prefix}b2", (0, 7.6, 5.0), (7.5, 2.4, 6.0), 0.5, 3, taper_top=(1.1, 1.1))
    cab = C.rounded_box(f"{prefix}cab", (0, 7.8, -1.6), (4.6, 3.2, 3.6), 0.4, 3)
    body = C.join(f"{prefix}__Body", [body, hopper, cab])
    glass = C.rounded_box(f"{prefix}__Glass", (0, 8.1, -1.7), (4.8, 2.2, 3.7), 0.3, 3)
    header = C.rounded_box(f"{prefix}hd", (0, 1.6, -6.2), (22, 1.6, 3.6), 0.4, 3)
    feeder = C.rounded_box(f"{prefix}fd", (0, 2.8, -4.0), (4.0, 2.0, 3.0), 0.3, 3, rot=(-20, 0, 0))
    trim = C.join(f"{prefix}__Trim", [header, feeder])
    reel = [C.cylinder(f"{prefix}axle", (-10.6, 3.4, -7.0), (10.6, 3.4, -7.0), 0.35, 16)]
    for i in range(6):
        a = i / 6 * math.tau
        y, z = 3.4 + math.sin(a) * 1.6, -7.0 + math.cos(a) * 1.6
        reel.append(C.cylinder(f"{prefix}bat{i}", (-10.6, y, z), (10.6, y, z), 0.18, 10))
    for x in (-10.4, -3.5, 3.5, 10.4):
        reel.append(C.cylinder(f"{prefix}disc{x}", (x - 0.1, 3.4, -7.0), (x + 0.1, 3.4, -7.0), 1.7, 20))
    reel_obj = C.join(f"{prefix}__Reel", reel)
    pipe = C.cylinder(f"{prefix}__Pipe", (3.5, 8.0, 6.5), (8.5, 9.0, 1.5), 0.45, 16)
    w = wheels(prefix, (-1.5, 5.8), 2.2, 1.6, x=4.6)
    heads = [C.rounded_box(f"{prefix}hl{s}", (s * 1.6, 9.6, -3.4), (0.9, 0.6, 0.25), 0.1) for s in (-1, 1)]
    beacon = C.uv_sphere(f"{prefix}__Beacon", (0, 9.7, -0.6), (0.7, 0.6, 0.7))
    return [body, glass, trim, reel_obj, pipe, *w, C.join(f"{prefix}__Light", heads), beacon]


def rage_car(prefix="RageCar"):
    objs = sports(prefix)
    spikes = []
    for z in (-0.5, 1.2, 2.9):
        spikes.append(C.cylinder(f"{prefix}sp{z}", (0, 4.0, z), (0, 5.4, z), 0.4, 10, radius_b=0.02))
    for s in (-1, 1):
        spikes.append(C.cylinder(f"{prefix}hs{s}", (s * 3.0, 1.4, -7.2), (s * 3.0, 1.4, -8.4), 0.3, 10, radius_b=0.02))
    objs.append(C.join(f"{prefix}__Chrome", spikes))
    flames = []
    for s in (-1, 1):
        for i in range(4):
            z = -5.0 + i * 2.2
            flames.append(C.rounded_box(f"{prefix}fl{s}{i}", (s * (W / 2 + 0.03), 1.6 + (i % 2) * 0.35, z), (0.06, 0.9 - i * 0.12, 2.0), 0.03, rot=(0, 0, 0)))
    objs.append(C.join(f"{prefix}__Flame", flames))
    brows = [C.rounded_box(f"{prefix}br{s}", (s * 2.6, 2.2, -7.1), (2.0, 0.3, 0.3), 0.08, rot=(0, 0, s * 20)) for s in (-1, 1)]
    objs.append(C.join(f"{prefix}__Brow", brows))
    return objs


def taxi(prefix="Taxi"):
    objs = sedan(prefix)
    sign = C.rounded_box(f"{prefix}__Sign", (0, 4.75, 0.9), (2.6, 0.75, 1.2), 0.2)
    checks = [C.rounded_box(f"{prefix}c{s}{i}", (s * (W / 2 + 0.02), 2.25, -5 + i * 1.6), (0.06, 0.55, 0.8), 0.02) for s in (-1, 1) for i in range(7) if i % 2 == 0]
    objs += [sign, C.join(f"{prefix}__Checker", checks)]
    return objs


def build():
    objs = []
    objs += sedan("Sedan")
    objs += sedan("Hatchback", hatch=True)
    objs += sports("SportsCar")
    objs += pickup("Pickup")
    objs += van("Van")
    objs += van("IceCreamVan", ice_cream=True)
    objs += tractor("Tractor")
    objs += taxi("Taxi")
    objs += rage_car("RageCar")
    objs += harvester("Harvester")
    return objs


PREVIEW = {
    "Body": (60, 130, 230), "Glass": (150, 205, 240), "Tire": (34, 32, 40), "Rim": (210, 214, 222),
    "Light": (255, 250, 210), "Tail": (255, 50, 50), "Trim": (70, 72, 84), "Stripe": (255, 255, 255),
    "Hay": (240, 202, 96), "Rack": (70, 72, 84), "Cone": (220, 170, 100), "Scoop": (255, 170, 200),
    "Cherry": (230, 40, 60), "Roof": (250, 240, 220), "Seat": (240, 200, 60), "Sign": (255, 250, 220),
    "Checker": (30, 30, 30), "Chrome": (210, 214, 222), "Flame": (255, 120, 30), "Brow": (255, 40, 40),
    "Reel": (220, 60, 50), "Pipe": (90, 150, 70), "Beacon": (255, 160, 30),
}
BODY = {"Sedan": (60, 130, 230), "Hatchback": (110, 200, 120), "SportsCar": (150, 80, 230), "Pickup": (240, 120, 40),
        "Van": (245, 245, 240), "IceCreamVan": (255, 160, 200), "Tractor": (70, 170, 70), "Taxi": (255, 205, 40),
        "RageCar": (30, 26, 36), "Harvester": (80, 160, 70)}

if __name__ == "__main__":
    import sys
    C.reset()
    objs = build()
    order = ["Sedan", "Hatchback", "SportsCar", "Pickup", "Van", "IceCreamVan", "Tractor", "Taxi", "RageCar", "Harvester"]
    for o in objs:
        name, key = o.name.split("__")
        rgb = BODY[name] if key == "Body" else PREVIEW.get(key, (200, 200, 200))
        emis = 2.0 if key in ("Light", "Tail", "Sign", "Beacon", "Flame") else 0
        C.set_material(o, C.material(f"{name}_{key}", rgb, 0.35 if key in ("Body", "Glass") else 0.6, emis))
        i = order.index(name)
        if name == "Harvester":
            o.location.x += 0
            o.location.y -= 30
        else:
            o.location.x += (i % 5) * 13 - 26
            o.location.y -= (i // 5) * 19
        print(o.name, C.tri_count(o))
    C.preview_setup(1300, 760, 32)
    C.ground(200, (150, 160, 150))
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/cars.png"
    C.camera((-30, 34, -40), (0, 0, 16), 38)
    C.render(out)
