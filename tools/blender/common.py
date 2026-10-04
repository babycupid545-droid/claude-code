"""Shared Blender helpers for the asset scripts (run with the `bpy` Python module).

Coordinates: helpers take ROBLOX coordinates (x right, y up, z back; models face -z) and
convert to Blender (x right, y forward, z up). The FBX export maps them back for Roblox.
Each object is one colour region named "<Asset>__<ColorKey>"; the Studio builder groups
objects by asset name and colours them from the ColorKey.
"""

import math
import os

import bpy  # noqa: F401  (must load before bmesh)
import bmesh
from mathutils import Matrix, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def R(x, y, z):
    """Roblox coords -> Blender coords."""
    return Vector((x, -z, y))


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def link(obj):
    bpy.context.scene.collection.objects.link(obj)
    return obj


def activate(obj):
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)


def apply_all(obj):
    activate(obj)
    for mod in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def shade(obj, smooth=True):
    for p in obj.data.polygons:
        p.use_smooth = smooth


# --- organic blobs -------------------------------------------------------------------------------

def blob(name, balls, voxel=0.045, smooth=8, decimate=0.35, resolution=None):
    """Organic shape: ellipsoids fused with a voxel remesh and smoothed so joins blend softly.

    balls: list of (roblox_center (x,y,z), radius, (sx, sy, sz) scale, roblox_rotation_deg or None).
    Each ellipsoid's diameters are 2 * radius * scale.
    """
    parts = []
    for i, (center, radius, scale, rot) in enumerate(balls):
        size = (2 * radius * scale[0], 2 * radius * scale[1], 2 * radius * scale[2])
        parts.append(uv_sphere(f"{name}_{i}", center, size, 24, 12, rot))
    obj = join(name, parts) if len(parts) > 1 else parts[0]
    obj.name = name
    remesh = obj.modifiers.new("remesh", "REMESH")
    remesh.mode = "VOXEL"
    remesh.voxel_size = voxel
    if smooth:
        sm = obj.modifiers.new("smooth", "CORRECTIVE_SMOOTH")
        sm.iterations = smooth
        sm.factor = 0.6
        sm.use_only_smooth = True
    apply_all(obj)
    if decimate and decimate < 1:
        dec = obj.modifiers.new("dec", "DECIMATE")
        dec.ratio = decimate
        apply_all(obj)
    shade(obj, True)
    return obj


# --- primitives -----------------------------------------------------------------------------------

def uv_sphere(name, center, size, segments=32, rings=16, rot=None):
    """Ellipsoid of the given Roblox size (diameters)."""
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=0.5, location=(0, 0, 0))
    obj = bpy.context.active_object
    obj.name = name
    sx, sy, sz = size
    obj.scale = (sx, sz, sy)
    if rot:
        rx, ry, rz = (math.radians(a) for a in rot)
        obj.rotation_mode = "XYZ"
        obj.rotation_euler = (rx, -rz, ry)
    obj.location = R(*center)
    apply_all(obj)
    shade(obj, True)
    return obj


def cylinder(name, a, b, radius, verts=24, radius_b=None, smooth=True):
    """Cylinder (optionally tapered) from Roblox point a to b."""
    pa, pb = R(*a), R(*b)
    d = pb - pa
    length = d.length
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=radius, radius2=radius_b if radius_b is not None else radius,
                                    depth=length, location=(0, 0, 0))
    obj = bpy.context.active_object
    obj.name = name
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized())
    obj.location = (pa + pb) / 2
    apply_all(obj)
    shade(obj, smooth)
    return obj


def rounded_box(name, center, size, bevel=0.2, segments=3, rot=None, taper_top=None):
    """Bevelled box with Roblox size; taper_top scales the top face (x, z) for cabins/roofs."""
    sx, sy, sz = size
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * sx, v.co.y * sz, v.co.z * sy))
        if taper_top and v.co.z > 0:
            v.co.x *= taper_top[0]
            v.co.y *= taper_top[1]
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = link(bpy.data.objects.new(name, me))
    if bevel > 0:
        mod = obj.modifiers.new("bevel", "BEVEL")
        mod.width = bevel
        mod.segments = segments
        mod.limit_method = "ANGLE"
    if rot:
        rx, ry, rz = (math.radians(a) for a in rot)
        obj.rotation_mode = "XYZ"
        obj.rotation_euler = (rx, -rz, ry)
    obj.location = R(*center)
    apply_all(obj)
    shade(obj, True)
    activate(obj)
    bpy.ops.object.shade_auto_smooth(angle=math.radians(40)) if hasattr(bpy.ops.object, "shade_auto_smooth") else None
    return obj


def extrude_profile(name, profile, width, bevel=0.25, segments=3, z_offset=0.0):
    """Side silhouette (list of (z, y) Roblox points, z along the length) extruded across x."""
    bm = bmesh.new()
    front, back = [], []
    for z, y in profile:
        front.append(bm.verts.new(R(-width / 2, y, z + z_offset)))
        back.append(bm.verts.new(R(width / 2, y, z + z_offset)))
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    n = len(profile)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new([front[i], front[j], back[j], back[i]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = link(bpy.data.objects.new(name, me))
    if bevel > 0:
        mod = obj.modifiers.new("bevel", "BEVEL")
        mod.width = bevel
        mod.segments = segments
        mod.limit_method = "ANGLE"
    apply_all(obj)
    shade(obj, True)
    return obj


def ico(name, center, size, subdiv=2, noise=0.0, seed=0, flat=True, rot=None):
    """Faceted low-poly blob (rocks, foliage) with optional vertex noise."""
    import random
    rng = random.Random(seed)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdiv, radius=0.5)
    obj = bpy.context.active_object
    obj.name = name
    for v in obj.data.vertices:
        k = 1 + rng.uniform(-noise, noise)
        v.co *= k
    sx, sy, sz = size
    obj.scale = (sx, sz, sy)
    if rot:
        rx, ry, rz = (math.radians(a) for a in rot)
        obj.rotation_euler = (rx, -rz, ry)
    obj.location = R(*center)
    apply_all(obj)
    shade(obj, not flat)
    return obj


def join(name, objs):
    objs = [o for o in objs if o]
    activate(objs[0])
    for o in objs[1:]:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = name
    return obj


def mirror_x(obj, name):
    """Copy of obj mirrored across x."""
    copy = obj.copy()
    copy.data = obj.data.copy()
    copy.name = name
    link(copy)
    copy.scale.x = -1
    apply_all(copy)
    me = copy.data
    me.flip_normals() if hasattr(me, "flip_normals") else None
    return copy


def tri_count(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


# --- materials / preview rendering --------------------------------------------------------------

def material(name, rgb, rough=0.55, emission=0.0, metal=0.0, alpha=1.0):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    col = (rgb[0] / 255, rgb[1] / 255, rgb[2] / 255, 1)
    bsdf.inputs["Base Color"].default_value = col
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if emission > 0:
        bsdf.inputs["Emission Color"].default_value = col
        bsdf.inputs["Emission Strength"].default_value = emission
    if alpha < 1:
        bsdf.inputs["Alpha"].default_value = alpha
    mat.diffuse_color = col
    return mat


def set_material(obj, mat):
    obj.data.materials.clear()
    obj.data.materials.append(mat)


def preview_setup(width=900, height=700, samples=48):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    scene.render.resolution_x = width
    scene.render.resolution_y = height
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.55, 0.75, 1.0, 1)
    bg.inputs["Strength"].default_value = 0.9
    scene.world = world
    sun = link(bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN")))
    sun.data.energy = 3.2
    sun.data.angle = math.radians(8)
    sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(-35))
    scene.view_settings.view_transform = "Standard"
    return scene


def camera(eye_roblox, target_roblox, lens=50):
    cam = link(bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam")))
    cam.data.lens = lens
    eye, target = R(*eye_roblox), R(*target_roblox)
    cam.location = eye
    direction = target - eye
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = cam
    return cam


def ground(size=60, rgb=(120, 190, 110)):
    bpy.ops.mesh.primitive_plane_add(size=size, location=(0, 0, 0))
    g = bpy.context.active_object
    g.name = "PreviewGround"
    set_material(g, material("ground", rgb, 0.9))
    return g


def render(path):
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def export_fbx(path, objects):
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    for o in objects:
        o.select_set(True)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.fbx(
        filepath=path,
        use_selection=True,
        object_types={"MESH"},
        apply_unit_scale=True,
        apply_scale_options="FBX_SCALE_ALL",
        axis_forward="-Z",
        axis_up="Y",
        mesh_smooth_type="FACE",
        add_leaf_bones=False,
        bake_anim=False,
        path_mode="STRIP",
    )


def export_preview_mesh(path, objects):
    """Plain-text triangle dump in Roblox coords for tools/preview (name, color key, triangles)."""
    with open(path, "w") as f:
        for o in objects:
            me = o.data
            me.calc_loop_triangles()
            f.write(f"o {o.name}\n")
            for tri in me.loop_triangles:
                pts = []
                for vi in tri.vertices:
                    v = o.matrix_world @ me.vertices[vi].co
                    pts.append(f"{v.x:.3f} {v.z:.3f} {-v.y:.3f}")
                f.write("t " + " ".join(pts) + "\n")
