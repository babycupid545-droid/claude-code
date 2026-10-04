--!strict
-- Turns the imported Blender meshes into ready-made models.
--
-- After File > Import 3D of assets/models/*.glb, the MeshParts (named "<Asset>__<Region>",
-- e.g. "Chicken__Body") go anywhere inside ReplicatedStorage.Assets.Meshes. This module
-- finds them by name and lays them out from MeshManifest (the authored position and size of
-- every region), so it doesn't matter how the importer scaled or centred them.
--
-- If an asset's meshes are missing (not imported yet), `build` returns nil and the builders
-- fall back to their part-based versions.

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

-- Does the imported mesh have the authored proportions? (Catches a mesh that was imported
-- rotated, e.g. with a different "up" axis.)
local function proportionsMatch(part: MeshPart, size: Vector3): boolean
	local ratios = {}
	for _, axis in { "X", "Y", "Z" } do
		local authored = (size :: any)[axis] :: number
		if authored > 0.4 then
			table.insert(ratios, ((part.Size :: any)[axis] :: number) / authored)
		end
	end
	if #ratios < 2 then
		return true
	end
	local lo, hi = math.huge, 0
	for _, r in ratios do
		lo = math.min(lo, r)
		hi = math.max(hi, r)
	end
	return hi / lo < 1.25
end

-- Returns every imported region of `asset`, or nil if any is missing or looks wrong.
function Meshes.regions(asset: string): { [string]: MeshPart }?
	local entry = Manifest[asset]
	if not entry then
		return nil
	end
	local all = index()
	local out: { [string]: MeshPart } = {}
	for key, region in entry.regions do
		local part = all[`{asset}__{key}`]
		if not part then
			if meshesFolder() then
				warnOnce(asset, `{asset}: "{asset}__{key}" not found in ReplicatedStorage.Assets.Meshes, using the part-built version`)
			end
			return nil
		end
		if not proportionsMatch(part, region.size) then
			warnOnce(asset, `{asset}__{key} looks rotated; re-import {entry.file} with World Up = Y (default). Using the part-built version`)
			return nil
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
	part.Size = region.size * scale
	part.CFrame = base * CFrame.new(region.center * scale)
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
