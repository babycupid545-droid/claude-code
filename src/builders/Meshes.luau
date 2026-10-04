--!strict
-- Turns the imported Blender meshes into ready-made models.
--
-- After File > Import 3D of assets/models/*.glb (or .fbx), the MeshParts (named
-- "<Asset>__<Region>", e.g. "Chicken__Body") go anywhere inside
-- ReplicatedStorage.Assets.Meshes. This module finds them by name and lays them out using
-- MeshManifest (the authored position and size of every region).
--
-- Importers don't all agree on axes, units or facing direction (the glTF importer, for one,
-- turns models around to face Roblox's forward). So for each imported file this works out
-- how the import was turned, scaled and moved, by matching where every piece landed against
-- where it was authored, and undoes that. Pieces then always come out the right way round,
-- whatever the import settings were.
--
-- If an asset's meshes are missing (not imported yet), `build` returns nil and the builders
-- fall back to their part-built versions.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Manifest = require(script.Parent.MeshManifest)

local Meshes = {}

export type Options = {
	-- Colour per region key; regions without one keep their imported colour.
	colors: { [string]: Color3 }?,
	materials: { [string]: Enum.Material }?,
	-- Uniform scale applied to the authored size.
	scale: number?,
	-- Where the asset's base-centre point sits relative to the model pivot.
	origin: CFrame?,
	anchored: boolean?,
	-- Regions to leave out (e.g. a duck has no comb).
	skip: { [string]: boolean }?,
}

-- How one imported file relates to the authored scene: imported = translation + scale * rotation * authored.
type Fit = { rotation: CFrame, scale: number, translation: Vector3 }

local warned: { [string]: boolean } = {}

local function warnOnce(key: string, message: string)
	if not warned[key] then
		warned[key] = true
		warn(`[Meshes] {message}`)
	end
end

local function meshesFolder(): Instance?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	return assets and assets:FindFirstChild("Meshes")
end

-- Imported MeshParts by their "<Asset>__<Region>" name. Tolerates suffixes the importer adds
-- for duplicates ("Chicken__Body.001", "Chicken__Body (1)").
local function index(): { [string]: MeshPart }
	local found: { [string]: MeshPart } = {}
	local folder = meshesFolder()
	if not folder then
		return found
	end
	for _, d in folder:GetDescendants() do
		if d:IsA("MeshPart") then
			local name = d.Name:match("^([%w]+__[%w]+)") or d.Name
			if not found[name] then
				found[name] = d
			end
		end
	end
	return found
end

-- The 24 ways to turn a box onto its axes (every axis-aligned rotation).
local ROTATIONS: { CFrame } = {}
do
	local axes = { Vector3.xAxis, Vector3.yAxis, Vector3.zAxis }
	for _, x in axes do
		for _, y in axes do
			if y ~= x then
				for _, sx in { 1, -1 } do
					for _, sy in { 1, -1 } do
						local vx, vy = x * sx, y * sy
						table.insert(ROTATIONS, CFrame.fromMatrix(Vector3.zero, vx, vy, vx:Cross(vy)))
					end
				end
			end
		end
	end
end

-- Works out how `file` was imported, from all of its pieces that are present.
local fits: { [string]: Fit } = {}
local unfit: { [string]: boolean } = {}
local function fitFor(file: string, all: { [string]: MeshPart }): Fit?
	if unfit[file] then
		return nil
	end
	local cached = fits[file]
	if cached then
		return cached
	end
	local authored: { Vector3 } = {}
	local imported: { Vector3 } = {}
	for asset, entry in Manifest do
		if entry.file == file then
			for key, region in entry.regions do
				local part = all[`{asset}__{key}`]
				if part then
					table.insert(authored, region.center)
					table.insert(imported, part.Position)
				end
			end
		end
	end
	local n = #authored
	if n < 3 then
		unfit[file] = true
		return nil
	end
	local ca, ci = Vector3.zero, Vector3.zero
	for i = 1, n do
		ca += authored[i]
		ci += imported[i]
	end
	ca /= n
	ci /= n
	local spreadA, spreadI = 0, 0
	for i = 1, n do
		spreadA += (authored[i] - ca).Magnitude ^ 2
		spreadI += (imported[i] - ci).Magnitude ^ 2
	end
	if spreadA < 1e-6 or spreadI < 1e-6 then
		-- The importer put every piece in the same place; nothing to line up against.
		unfit[file] = true
		return nil
	end
	local best: Fit? = nil
	local bestError = math.huge
	for _, rotation in ROTATIONS do
		local dot = 0
		for i = 1, n do
			dot += (imported[i] - ci):Dot(rotation * (authored[i] - ca))
		end
		local scale = dot / spreadA
		if scale > 0 then
			local err = 0
			for i = 1, n do
				err += ((imported[i] - ci) - rotation * (authored[i] - ca) * scale).Magnitude ^ 2
			end
			if err < bestError then
				bestError = err
				best = { rotation = rotation, scale = scale, translation = ci - rotation * ca * scale }
			end
		end
	end
	if not best or bestError / spreadI > 0.02 then
		warnOnce(file, `{file}: the imported pieces don't line up with the model (were some moved?). Delete them and import assets/models/{file} again`)
		unfit[file] = true
		return nil
	end
	fits[file] = best
	return best
end

-- Does the imported piece have the authored shape (in any orientation)? Catches meshes from an
-- older version of the model.
local function shapeMatches(part: MeshPart, size: Vector3, fit: Fit?): boolean
	local a = { size.X, size.Y, size.Z }
	local b = { part.Size.X, part.Size.Y, part.Size.Z }
	table.sort(a)
	table.sort(b)
	local s = if fit then fit.scale else b[3] / math.max(a[3], 1e-3)
	for i = 1, 3 do
		if a[i] > 0.4 then
			local ratio = b[i] / (a[i] * s)
			if ratio < 0.93 or ratio > 1.07 then
				return false
			end
		end
	end
	return true
end

-- Remembers which fit each found piece uses (for `place`).
local fitOf: { [MeshPart]: Fit } = setmetatable({}, { __mode = "k" }) :: any

-- Returns every imported region of `asset`, or nil if any is missing or looks wrong.
function Meshes.regions(asset: string): { [string]: MeshPart }?
	local entry = Manifest[asset]
	if not entry then
		return nil
	end
	local all = index()
	table.clear(fits)
	table.clear(unfit)
	local fit = fitFor(entry.file, all)
	local out: { [string]: MeshPart } = {}
	for key, region in entry.regions do
		local part = all[`{asset}__{key}`]
		if not part then
			if meshesFolder() then
				warnOnce(asset, `{asset}: "{asset}__{key}" not found in ReplicatedStorage.Assets.Meshes, using the part-built version`)
			end
			return nil
		end
		if not shapeMatches(part, region.size, fit) then
			warnOnce(asset, `{asset}__{key} doesn't match the current model: delete the old {asset} meshes from ReplicatedStorage.Assets.Meshes and import assets/models/{entry.file} again. Using the part-built version for now`)
			return nil
		end
		if fit then
			fitOf[part] = fit
		end
		out[key] = part
	end
	return out
end

function Meshes.available(asset: string): boolean
	return Meshes.regions(asset) ~= nil
end

function Meshes.manifest(asset: string): Manifest.Asset?
	return Manifest[asset]
end

-- Clones one region into place: `base` is the asset's base-centre CFrame.
function Meshes.place(source: MeshPart, region: Manifest.Region, base: CFrame, scale: number): MeshPart
	local part = source:Clone()
	for _, child in part:GetChildren() do
		if child:IsA("SurfaceAppearance") or child:IsA("Decal") or child:IsA("Texture") then
			child:Destroy()
		end
	end
	pcall(function()
		part.TextureID = ""
	end)
	local fit = fitOf[source]
	if fit then
		-- Undo the import's turn, scale and offset: back to authored space, keeping the piece's
		-- own orientation relative to the file.
		local inverse = fit.rotation:Inverse()
		local position = inverse * (source.Position - fit.translation) / fit.scale
		local rotation = inverse * source.CFrame.Rotation
		part.Size = source.Size * (scale / fit.scale)
		part.CFrame = base * CFrame.new(position * scale) * rotation
	else
		-- Couldn't work out the import; trust the authored layout.
		part.Size = region.size * scale
		part.CFrame = base * CFrame.new(region.center * scale)
	end
	part.Material = Enum.Material.SmoothPlastic
	part.CastShadow = true
	part.DoubleSided = false
	return part
end

-- Builds `asset` as a Model of MeshParts (pivot at the model origin), or nil if the meshes
-- aren't imported. Regions are named by their key ("Body", "Glass", ...).
function Meshes.build(asset: string, opts: Options?): Model?
	local o: Options = opts or {}
	local regions = Meshes.regions(asset)
	local entry = Manifest[asset]
	if not regions or not entry then
		return nil
	end
	local scale = o.scale or 1
	local base = o.origin or CFrame.new()
	local model = Instance.new("Model")
	model.Name = asset
	for key, region in entry.regions do
		if not (o.skip and o.skip[key]) then
			local part = Meshes.place(regions[key], region, base, scale)
			part.Name = key
			part.Anchored = o.anchored ~= false
			local color = o.colors and o.colors[key]
			if color then
				part.Color = color
			end
			local material = o.materials and o.materials[key]
			if material then
				part.Material = material
			end
			part.Parent = model
		end
	end
	model.WorldPivot = CFrame.new()
	return model
end

return Meshes
