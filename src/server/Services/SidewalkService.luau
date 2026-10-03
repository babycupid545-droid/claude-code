--!strict
-- The two sidewalks are grids of tiles that can crumble away:
--   Collapse: a whole sidewalk drops for a few seconds, so everyone on it must cross.
--   Shrink:   the outermost row of both sidewalks falls away for good (Teams).

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local SidewalkService = {}

-- "A" (negative Z) or "B" (positive Z).
export type Side = string

local M = Config.Map
local ROAD_DEPTH = M.LaneCount * M.LaneWidth
local TILE_X = M.RoadLength / M.SidewalkColumns
local TILE_Z = M.SidewalkDepth / M.SidewalkRows
local THICKNESS = 3

local COLORS: { [Side]: Color3 } = {
	A = Color3.fromRGB(200, 200, 205),
	B = Color3.fromRGB(205, 200, 195),
}
local WARNING_COLOR = Color3.fromRGB(255, 70, 50)

type Tile = {
	part: Part,
	side: Side,
	row: number, -- 1 is next to the road
	removed: boolean, -- permanently gone (Shrink)
	down: boolean, -- temporarily gone (Collapse)
}

local tiles: { Tile } = {}
local folder: Folder? = nil
-- Bumped every reset so stale collapse/shrink threads from a previous round do nothing.
local generation = 0

local function sideSign(side: Side): number
	return if side == "A" then -1 else 1
end

local function setSolid(tile: Tile, solid: boolean)
	tile.part.CanCollide = solid
	tile.part.Transparency = if solid then 0 else 1
	tile.part.Color = COLORS[tile.side]
end

function SidewalkService.build(parent: Instance)
	if folder then
		folder:Destroy()
	end
	tiles = {}
	generation += 1
	local f = Instance.new("Folder")
	f.Name = "Sidewalks"
	for _, side in { "A", "B" } do
		local sign = sideSign(side)
		for row = 1, M.SidewalkRows do
			local z = sign * (ROAD_DEPTH / 2 + (row - 0.5) * TILE_Z)
			for col = 1, M.SidewalkColumns do
				local x = -M.RoadLength / 2 + (col - 0.5) * TILE_X
				local p = Instance.new("Part")
				p.Name = `{side}_{row}_{col}`
				p.Anchored = true
				p.Size = Vector3.new(TILE_X - 0.15, THICKNESS, TILE_Z - 0.15)
				p.Position = Vector3.new(x, M.SidewalkTopY - THICKNESS / 2, z)
				p.Material = Enum.Material.Concrete
				p.TopSurface = Enum.SurfaceType.Smooth
				p.Parent = f
				local tile: Tile = { part = p, side = side, row = row, removed = false, down = false }
				setSolid(tile, true)
				table.insert(tiles, tile)
			end
		end
	end
	f.Parent = parent
	folder = f
end

function SidewalkService.sideOf(z: number): Side?
	if z < -ROAD_DEPTH / 2 then
		return "A"
	elseif z > ROAD_DEPTH / 2 then
		return "B"
	end
	return nil
end

-- A random standing spot on a tile of that side, facing the road.
function SidewalkService.spawnCFrame(side: Side, rng: Random): CFrame
	local candidates = {}
	for _, tile in tiles do
		if tile.side == side and not tile.removed and not tile.down then
			table.insert(candidates, tile)
		end
	end
	local sign = sideSign(side)
	local pos: Vector3
	if #candidates > 0 then
		local tile = candidates[rng:NextInteger(1, #candidates)]
		local jitter = Vector3.new(rng:NextNumber(-0.3, 0.3) * TILE_X, 0, rng:NextNumber(-0.3, 0.3) * TILE_Z)
		pos = tile.part.Position + jitter
	else
		pos = Vector3.new(0, 0, sign * (ROAD_DEPTH / 2 + TILE_Z / 2))
	end
	pos = Vector3.new(pos.X, M.SidewalkTopY + 4, pos.Z)
	return CFrame.lookAt(pos, Vector3.new(pos.X, pos.Y, 0))
end

local function flashThenDrop(selected: { Tile }, warning: number, gen: number)
	local t = 0
	local on = false
	while t < warning do
		if gen ~= generation then
			return false
		end
		on = not on
		for _, tile in selected do
			tile.part.Color = if on then WARNING_COLOR else COLORS[tile.side]
		end
		-- Flash faster as the drop gets closer.
		local step = if warning - t < 1.5 then 0.15 else 0.35
		task.wait(step)
		t += step
	end
	if gen ~= generation then
		return false
	end
	for _, tile in selected do
		setSolid(tile, false)
	end
	return true
end

-- Yields for warning + duration.
function SidewalkService.collapseSide(side: Side, warning: number, duration: number)
	local gen = generation
	local selected = {}
	for _, tile in tiles do
		if tile.side == side and not tile.removed then
			tile.down = true
			table.insert(selected, tile)
		end
	end
	if not flashThenDrop(selected, warning, gen) then
		return
	end
	task.wait(duration)
	if gen ~= generation then
		return
	end
	for _, tile in selected do
		tile.down = false
		if not tile.removed then
			setSolid(tile, true)
		end
	end
end

-- Removes the outermost remaining row on both sides. Returns false once at the minimum.
function SidewalkService.shrink(warning: number): boolean
	local gen = generation
	local outer = 0
	for _, tile in tiles do
		if not tile.removed then
			outer = math.max(outer, tile.row)
		end
	end
	if outer <= Config.Sidewalk.MinRows then
		return false
	end
	local selected = {}
	for _, tile in tiles do
		if tile.row == outer and not tile.removed then
			tile.removed = true
			table.insert(selected, tile)
		end
	end
	task.spawn(flashThenDrop, selected, warning, gen)
	return true
end

return SidewalkService
