"""Renders preview images of what the Studio builders create, without Studio.

It bundles tools/preview/mock.luau (a tiny fake Roblox engine) with the builder sources,
runs that with the `luau` CLI to dump every part, then rasterizes the parts with numpy.

Usage: python3 tools/preview/render.py <cars|arena|lobby> <out.png> [--luau path/to/luau]
"""

import math
import os
import re
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image

USE_MESHES = "--meshes" in sys.argv
MESH_CACHE = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".cache", "meshes.txt")
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

MODULES = [
    "src/shared/Config.luau", "src/shared/Layout.luau", "src/shared/AssetIds.luau", "src/shared/UiSprites.luau",
    "src/builders/Build.luau", "src/builders/Palette.luau", "src/builders/Props.luau",
    "src/builders/WorldBuilder.luau", "src/builders/CarBuilder.luau", "src/builders/LightingBuilder.luau",
    "src/shared/Cosmetics.luau", "src/builders/ChickenBuilder.luau",
    "src/builders/MeshManifest.luau", "src/builders/Meshes.luau",
]

DRIVER = r'''
local what, useMeshes = "%s", %s
local root = Instance.new("Folder")
local function mod(n) return mockRequire(builders:FindFirstChild(n)) end
if useMeshes then
	-- Pretend the .glb files were imported: one MeshPart per region, at half scale, turned
	-- around and moved (the builders must undo all of that).
	local assets = Instance.new("Folder")
	assets.Name = "Assets"
	assets.Parent = service("ReplicatedStorage")
	local meshes = Instance.new("Folder")
	meshes.Name = "Meshes"
	meshes.Parent = assets
	for asset, entry in mod("MeshManifest") do
		for key, region in entry.regions do
			local mp = Instance.new("MeshPart")
			mp.Name = asset .. "__" .. key
			mp.MeshId = asset .. "__" .. key
			mp.Size = region.size * 0.5
			-- Like the glTF importer: the whole file turned to face the other way (and moved).
			mp.CFrame = CFrame.new(10, 0, 5) * CFrame.Angles(0, math.pi, 0) * CFrame.new(region.center * 0.5)
			mp.Parent = meshes
		end
	end
end
if what == "cars" then
	mod("CarBuilder").build(root)
elseif what == "arena" then
	mod("WorldBuilder").buildArena(root)
elseif what == "lobby" then
	mod("WorldBuilder").buildLobby(root)
elseif what == "chickens" or what == "chicken" then
	mod("ChickenBuilder").buildAll(root)
elseif what == "pose" or what == "glide" or what == "shoot" then
	-- Classic chicken posed mid-stride with wings up and head pecking, to check joint directions.
	local cosm = mockRequire(shared:FindFirstChild("Cosmetics"))
	local m = mod("ChickenBuilder").build(cosm.get("Classic"))
	m.Parent = root
	local poses = {
		LeftWing = CFrame.Angles(0, 0, -1.0), RightWing = CFrame.Angles(0, 0, 1.0),
		LeftHip = CFrame.Angles(0.8, 0, 0), RightHip = CFrame.Angles(-0.8, 0, 0),
		Neck = CFrame.new(0, -0.15, -0.25) * CFrame.Angles(-0.7, 0.4, 0), Tail = CFrame.Angles(0, 0.3, 0),
	}
	-- Same numbers as ChickenAnimator at glide = 1 / shoot = 1.
	if what == "glide" then
		poses = {
			Root = CFrame.Angles(-0.35, 0, 0),
			LeftWing = CFrame.Angles(-0.25, 0, -1.25), RightWing = CFrame.Angles(-0.25, 0, 1.25),
			LeftHip = CFrame.Angles(-0.9, 0, 0), RightHip = CFrame.Angles(-0.9, 0, 0),
			Neck = CFrame.new(0, 0, 0.15) * CFrame.Angles(0.3, 0, 0), Tail = CFrame.Angles(0.05, 0, 0),
		}
	elseif what == "shoot" then
		poses = {
			Root = CFrame.new(0, -0.22, 0) * CFrame.Angles(-0.2, 0, 0),
			LeftWing = CFrame.Angles(0, 0, -0.7), RightWing = CFrame.Angles(0, 0, 0.7),
			Neck = CFrame.Angles(-0.2, 0.6, 0.1), Tail = CFrame.Angles(-0.9, 0, 0),
		}
	end
	-- Welded decorations follow their Part0.
	local welds = {}
	for _, d in m:GetDescendants() do
		if d.ClassName == "WeldConstraint" then
			table.insert(welds, { d.Part0, d.Part1, d.Part0.CFrame:Inverse() * d.Part1.CFrame })
		end
	end
	-- Root first: every other joint hangs off the body.
	for pass = 1, 2 do
		for _, d in m:GetDescendants() do
			if d.ClassName == "Motor6D" and poses[d.Name] and ((d.Name == "Root") == (pass == 1)) then
				d.Part1.CFrame = d.Part0.CFrame * d.C0 * poses[d.Name] * d.C1:Inverse()
			end
		end
	end
	for _, w in welds do
		w[2].CFrame = w[1].CFrame * w[3]
	end
end
local function attached(o)
	local p = o.Parent
	while p do
		if p == root then return true end
		p = p.Parent
	end
	return false
end
local function topModel(o)
	local p, last = o.Parent, nil
	while p and p ~= root do last = p; p = p.Parent end
	return last
end
local shared = service("ReplicatedStorage"):FindFirstChild("Shared")
local carIndex = {}
for i, c in root:GetChildren() do carIndex[c] = i end
for _, o in all do
	if o:IsA("BasePart") and attached(o) and (o.Transparency or 0) < 1 then
		local cf = o.CFrame
		local px, py, pz = cf.p[1], cf.p[2], cf.p[3]
		if what == "cars" then
			local i = carIndex[topModel(o)] or 0
			px += ((i - 1) %% 5) * 13 - 26
			pz += math.floor((i - 1) / 5) * 20 - 10
		elseif what == "chickens" then
			local i = carIndex[topModel(o)] or 0
			px += ((i - 1) %% 4) * 7 - 10.5
			pz += math.floor((i - 1) / 4) * 9
		elseif what == "chicken" and (carIndex[topModel(o)] or 0) ~= 1 then
			continue
		end
		local mesh = if o.ClassName == "MeshPart" then o.MeshId else "none"
		for _, ch in o:GetChildren() do
			if ch.ClassName == "SpecialMesh" then mesh = "sphere" end
		end
		local s, r, c = o.Size, cf.r, o.Color
		print(string.format("P;%%s;%%s;%%f,%%f,%%f;%%f,%%f,%%f,%%f,%%f,%%f,%%f,%%f,%%f;%%f,%%f,%%f;%%f,%%f,%%f;%%f;%%s;%%s",
			o.ClassName, o.Shape and o.Shape.Name or "Block", s[1], s[2], s[3],
			r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9], px, py, pz, c.R, c.G, c.B,
			o.Transparency or 0, mesh, o.Material and o.Material.Name or "SmoothPlastic"))
	end
end
'''


def bundle(what):
    parts = [open(os.path.join(ROOT, "tools/preview/mock.luau")).read()]
    for rel in MODULES:
        src = open(os.path.join(ROOT, rel)).read()
        src = re.sub(r"^export type", "type", src, flags=re.M)
        src = src.replace("--!strict", "")
        parts.append(f'__modules["./{rel}"] = function(script, require)\n{src}\nend\n')
    parts.append(DRIVER % (what, "true" if USE_MESHES else "false"))
    return "\n".join(parts)


def run(what, luau):
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as f:
        f.write(bundle(what))
        path = f.name
    out = subprocess.run([luau, path], capture_output=True, text=True)
    if out.returncode != 0:
        sys.exit(out.stdout[-3000:] + out.stderr[-3000:])
    parts = []
    for line in out.stdout.splitlines():
        if not line.startswith("P;"):
            continue
        _, cls, shape, size, rot, pos, col, tr, mesh, mat = line.split(";")
        parts.append({
            "cls": cls, "shape": shape,
            "size": np.array([float(v) for v in size.split(",")]),
            "rot": np.array([float(v) for v in rot.split(",")]).reshape(3, 3),
            "pos": np.array([float(v) for v in pos.split(",")]),
            "color": np.array([float(v) for v in col.split(",")]),
            "transparency": float(tr), "mesh": mesh, "material": mat,
        })
    return parts


# --- geometry (unit shapes, centered, size 1) ---------------------------------------------------

def box_tris():
    v = np.array([[x, y, z] for x in (-.5, .5) for y in (-.5, .5) for z in (-.5, .5)])
    faces = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    tris = []
    for a, b, c, d in faces:
        tris += [(v[a], v[b], v[c]), (v[a], v[c], v[d])]
    return np.array(tris)


def wedge_tris():
    # Roblox wedge: full bottom, tall back face at +Z, slope down to the front (-Z).
    A, B = np.array([-.5, -.5, -.5]), np.array([.5, -.5, -.5])
    C, D = np.array([.5, -.5, .5]), np.array([-.5, -.5, .5])
    E, F = np.array([-.5, .5, .5]), np.array([.5, .5, .5])
    return np.array([(A, B, C), (A, C, D), (D, C, F), (D, F, E), (A, D, E), (B, F, C), (A, E, F), (A, F, B)])


def cylinder_tris(n=16):
    tris = []
    for i in range(n):
        a0, a1 = 2 * math.pi * i / n, 2 * math.pi * (i + 1) / n
        p0 = np.array([0, .5 * math.cos(a0), .5 * math.sin(a0)])
        p1 = np.array([0, .5 * math.cos(a1), .5 * math.sin(a1)])
        l, r = np.array([-.5, 0, 0]), np.array([.5, 0, 0])
        tris += [(p0 + l, p1 + l, p1 + r), (p0 + l, p1 + r, p0 + r), (l, p1 + l, p0 + l), (r, p0 + r, p1 + r)]
    return np.array(tris)


def sphere_tris(nu=14, nv=8):
    tris = []
    for i in range(nu):
        for j in range(nv):
            def pt(a, b):
                th, ph = 2 * math.pi * a / nu, math.pi * b / nv
                return np.array([.5 * math.sin(ph) * math.cos(th), .5 * math.cos(ph), .5 * math.sin(ph) * math.sin(th)])
            tris += [(pt(i, j), pt(i + 1, j), pt(i + 1, j + 1)), (pt(i, j), pt(i + 1, j + 1), pt(i, j + 1))]
    return np.array(tris)


SHAPES = {"box": box_tris(), "wedge": wedge_tris(), "cyl": cylinder_tris(), "ball": sphere_tris()}


_MESHES = None


def mesh_tris(name):
    """Unit-box-normalised triangles of an exported Blender region (see export_all.py)."""
    global _MESHES
    if _MESHES is None:
        _MESHES = {}
        cur = None
        with open(MESH_CACHE) as f:
            for line in f:
                if line.startswith("o "):
                    cur = []
                    _MESHES[line[2:].strip()] = cur
                elif line.startswith("t "):
                    v = [float(x) for x in line[2:].split()]
                    cur.append([v[0:3], v[3:6], v[6:9]])
        for k, tris in _MESHES.items():
            a = np.array(tris)
            lo, hi = a.reshape(-1, 3).min(0), a.reshape(-1, 3).max(0)
            _MESHES[k] = (a - (lo + hi) / 2) / np.maximum(hi - lo, 1e-3)
    return _MESHES[name]


def part_tris(p):
    if p["cls"] == "MeshPart":
        unit = mesh_tris(p["mesh"])
    elif p["cls"] == "WedgePart":
        unit = SHAPES["wedge"]
    elif p["shape"] == "Cylinder":
        unit = SHAPES["cyl"]
    elif p["shape"] == "Ball" or p["mesh"] == "sphere":
        unit = SHAPES["ball"]
    else:
        unit = SHAPES["box"]
    local = unit * p["size"]
    return local @ p["rot"].T + p["pos"]


# --- rasterizer ----------------------------------------------------------------------------

def render(parts, eye, target, out, w=1100, h=700, fov=50):
    eye, target = np.array(eye, float), np.array(target, float)
    fwd = target - eye
    fwd /= np.linalg.norm(fwd)
    right = np.cross(fwd, [0, 1, 0])
    right /= np.linalg.norm(right)
    up = np.cross(right, fwd)
    f = 0.5 * h / math.tan(math.radians(fov) / 2)

    img = np.zeros((h, w, 3))
    sky_top, sky_bottom = np.array([0.45, 0.65, 0.95]), np.array([0.85, 0.92, 1.0])
    for y in range(h):
        img[y] = sky_top + (sky_bottom - sky_top) * (y / h)
    zbuf = np.full((h, w), np.inf)
    light = np.array([-0.4, 0.85, -0.35])
    light /= np.linalg.norm(light)

    for p in parts:
        tris = part_tris(p)
        base = p["color"]
        for tri in tris:
            n = np.cross(tri[1] - tri[0], tri[2] - tri[0])
            nl = np.linalg.norm(n)
            if nl == 0:
                continue
            n /= nl
            rel = tri - eye
            cz = rel @ fwd
            if np.any(cz < 0.5):
                continue
            sx = w / 2 + f * (rel @ right) / cz
            sy = h / 2 - f * (rel @ up) / cz
            x0, x1 = max(int(sx.min()), 0), min(int(sx.max()) + 1, w)
            y0, y1 = max(int(sy.min()), 0), min(int(sy.max()) + 1, h)
            if x0 >= x1 or y0 >= y1:
                continue
            if np.dot(n, fwd) > 0:
                n = -n
            shade = 0.45 + 0.65 * max(0.0, float(np.dot(n, light)))
            if p["material"] == "Neon":
                shade = 1.3
            color = np.clip(base * shade, 0, 1)
            xs, ys = np.meshgrid(np.arange(x0, x1) + 0.5, np.arange(y0, y1) + 0.5)
            d = (sy[1] - sy[2]) * (sx[0] - sx[2]) + (sx[2] - sx[1]) * (sy[0] - sy[2])
            if abs(d) < 1e-9:
                continue
            l0 = ((sy[1] - sy[2]) * (xs - sx[2]) + (sx[2] - sx[1]) * (ys - sy[2])) / d
            l1 = ((sy[2] - sy[0]) * (xs - sx[2]) + (sx[0] - sx[2]) * (ys - sy[2])) / d
            l2 = 1 - l0 - l1
            inside = (l0 >= 0) & (l1 >= 0) & (l2 >= 0)
            if not inside.any():
                continue
            z = 1 / (l0 / cz[0] + l1 / cz[1] + l2 / cz[2])
            region = zbuf[y0:y1, x0:x1]
            mask = inside & (z < region)
            region[mask] = z[mask]
            tile = img[y0:y1, x0:x1]
            if p["transparency"] > 0:
                a = 1 - p["transparency"]
                tile[mask] = tile[mask] * (1 - a) + color * a
            else:
                tile[mask] = color
    # Light fog for depth.
    fog = np.clip((zbuf - 150) / 600, 0, 0.6)[..., None]
    fog[np.isinf(zbuf)] = 0
    img = img * (1 - fog) + np.array([0.82, 0.88, 1.0]) * fog
    Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)).save(out)


VIEWS = {
    "cars": [((-20, 22, -42), (0, 0, 0))],
    "arena": [((-210, 140, -300), (0, -10, 0)), ((0, 76, -173), (0, 0, 10)), ((-60, 9, -95), (10, 2, 0))],
    "lobby": [((40, 105, -70), (0, 72, -150))],
    "pose": [((-6, 4.5, -8), (0, 2.8, 0)), ((9, 3.5, 0), (0, 2.8, 0))],
    "glide": [((-7, 6, -8), (0, 2.8, 0)), ((10, 3.5, 0), (0, 2.8, 0))],
    "shoot": [((9, 3.5, 2), (0, 2.8, 0))],
    "chickens": [((-12, 14, -30), (0, 3, 4))],
    "chicken": [((-5, 4.5, -9), (0, 2.8, 0)), ((8, 4, 5), (0, 2.8, 0)), ((0, 3.2, -11), (0, 3, 0))],
}


def main():
    what, out = sys.argv[1], sys.argv[2]
    luau = sys.argv[sys.argv.index("--luau") + 1] if "--luau" in sys.argv else "luau"
    parts = run(what, luau)
    print(f"{len(parts)} parts")
    base, ext = os.path.splitext(out)
    for i, (eye, target) in enumerate(VIEWS[what]):
        render(parts, eye, target, out if i == 0 else f"{base}_{i}{ext}")


if __name__ == "__main__":
    main()
