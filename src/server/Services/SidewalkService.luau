--!strict
-- The two sidewalks are grids of tiles. During a round the side everyone is leaving shakes,
-- crumbles away, then rises back up so they can cross back (see RoundService's crossing loop).
--
-- Tiles come from Workspace.Arena.Sidewalks (attributes Side, Row). The server only flips
-- collisions and a "State" attribute; clients animate the shaking and falling smoothly.
--   State: "Solid" | "Warn" | "Down"

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(ReplicatedStorage.Shared.Layout)

local SidewalkService = {}

-- "A" (negative Z) or "B" (positive Z).
export type Side = string

type Tile = { part: BasePart, side: Side, row: number }

local tiles: { Tile } = {}

local function setState(tile: Tile, state: string)
	tile.part:SetAttribute("State", state)
	local solid = state ~= "Down"
	tile.part.CanCollide = solid
	tile.part.CanQuery = solid
end

-- Picks up the tiles under `arena` and resets them all to solid.
function SidewalkService.reset(arena: Instance)
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
			local tile: Tile = { part = part, side = side, row = row }
			setState(tile, "Solid")
			part.Transparency = 0
			table.insert(tiles, tile)
		end
	end
end

function SidewalkService.sideOf(z: number): Side?
	local zone = Layout.zoneOf(z)
	return if zone == "A" or zone == "B" then zone else nil
end

local function setSide(side: Side, state: string)
	for _, tile in tiles do
		if tile.side == side then
			setState(tile, state)
		end
	end
end

-- Shake and flash (still walkable).
function SidewalkService.warnSide(side: Side)
	setSide(side, "Warn")
end

-- Crumble away: anyone still standing on it falls.
function SidewalkService.dropSide(side: Side)
	setSide(side, "Down")
end

-- Rise back up.
function SidewalkService.raiseSide(side: Side)
	setSide(side, "Solid")
end

-- A random standing spot on a tile of that side, facing the road.
function SidewalkService.spawnCFrame(side: Side, rng: Random): CFrame
	local candidates = {}
	for _, tile in tiles do
		-- Keep spawns off the very edge.
		if tile.side == side and tile.row >= 2 then
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
		local edge = Layout.innerEdge + 10
		pos = Vector3.new(0, 4, if side == "A" then -edge else edge)
	end
	return CFrame.lookAt(pos, Vector3.new(pos.X, pos.Y, 0))
end

return SidewalkService
