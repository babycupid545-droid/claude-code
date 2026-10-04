--!strict
-- The two sidewalks are grids of tiles that can crumble away:
--   Collapse: a whole sidewalk drops for a few seconds, so everyone on it must cross.
--   Shrink:   the outermost row of both sidewalks falls away for good (Teams).
--
-- Tiles come from Workspace.Arena.Sidewalks (attributes Side, Row). The server only flips
-- collisions and a "State" attribute; clients animate the shaking and falling smoothly.
--   State: "Solid" | "Warn" | "Down" | "Gone"

local SidewalkService = {}

-- "A" (negative Z) or "B" (positive Z).
export type Side = string

type Tile = {
	part: BasePart,
	side: Side,
	row: number, -- 1 is next to the road
	removed: boolean, -- permanently gone (Shrink)
	down: boolean, -- temporarily gone (Collapse)
}

local tiles: { Tile } = {}
local roadHalfDepth = 42
-- Bumped every reset so stale collapse/shrink threads from a previous round do nothing.
local generation = 0

local function setState(tile: Tile, state: string)
	tile.part:SetAttribute("State", state)
	local solid = state == "Solid" or state == "Warn"
	tile.part.CanCollide = solid
	tile.part.CanQuery = solid
end

-- Picks up the tiles under `arena` and resets them all to solid.
function SidewalkService.reset(arena: Instance, halfRoadDepth: number)
	generation += 1
	roadHalfDepth = halfRoadDepth
	tiles = {}
	local folder = arena:FindFirstChild("Sidewalks")
	if not folder then
		warn("[Sidewalks] Arena has no Sidewalks folder")
		return
	end
	for _, part in folder:GetChildren() do
		local side = part:GetAttribute("Side")
		local row = part:GetAttribute("Row")
		if part:IsA("BasePart") and type(side) == "string" and type(row) == "number" then
			local tile: Tile = { part = part, side = side, row = row, removed = false, down = false }
			setState(tile, "Solid")
			part.Transparency = 0
			table.insert(tiles, tile)
		end
	end
end

function SidewalkService.sideOf(z: number): Side?
	if z < -roadHalfDepth then
		return "A"
	elseif z > roadHalfDepth then
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
	local pos: Vector3
	if #candidates > 0 then
		local tile = candidates[rng:NextInteger(1, #candidates)]
		local size = tile.part.Size
		pos = tile.part.Position
			+ Vector3.new(rng:NextNumber(-0.3, 0.3) * size.X, size.Y / 2 + 3.5, rng:NextNumber(-0.3, 0.3) * size.Z)
	else
		pos = Vector3.new(0, 4, if side == "A" then -roadHalfDepth - 5 else roadHalfDepth + 5)
	end
	return CFrame.lookAt(pos, Vector3.new(pos.X, pos.Y, 0))
end

local function warnThenDrop(selected: { Tile }, warning: number, gen: number): boolean
	for _, tile in selected do
		setState(tile, "Warn")
	end
	task.wait(warning)
	if gen ~= generation then
		return false
	end
	for _, tile in selected do
		setState(tile, if tile.removed then "Gone" else "Down")
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
	if not warnThenDrop(selected, warning, gen) then
		return
	end
	task.wait(duration)
	if gen ~= generation then
		return
	end
	for _, tile in selected do
		tile.down = false
		if not tile.removed then
			setState(tile, "Solid")
		end
	end
end

-- Removes the outermost remaining row on both sides. Returns false once at the minimum.
function SidewalkService.shrink(warning: number, minRows: number): boolean
	local gen = generation
	local outer = 0
	for _, tile in tiles do
		if not tile.removed then
			outer = math.max(outer, tile.row)
		end
	end
	if outer <= minRows then
		return false
	end
	local selected = {}
	for _, tile in tiles do
		if tile.row == outer and not tile.removed then
			tile.removed = true
			table.insert(selected, tile)
		end
	end
	task.spawn(warnThenDrop, selected, warning, gen)
	return true
end

return SidewalkService
