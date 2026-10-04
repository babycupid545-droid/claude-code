--!strict
-- Where everything is on the arena, computed from Config.Map. Shared by the builders,
-- server and clients so they always agree.
--
--   z:  -outer ... -inner | road A lanes | -medianHalf ... medianHalf | road B lanes | inner ... outer
--        sidewalk A                         grass median                              sidewalk B

local Config = require(script.Parent.Config)

local M = Config.Map

export type Lane = { z: number, dir: number, road: string }

local Layout = {}

Layout.medianHalf = M.MedianWidth / 2
Layout.roadDepth = M.LanesPerRoad * M.LaneWidth
Layout.innerEdge = Layout.medianHalf + Layout.roadDepth -- where the sidewalks start
Layout.outerEdge = Layout.innerEdge + M.SidewalkDepth -- far edge of the sidewalks
Layout.halfLength = M.RoadLength / 2

-- Lanes ordered from side A to side B. Every lane has its own direction, re-rolled each round
-- (Layout.randomDirections / setDirections; the server shares them through the RoundState
-- "LaneDirs" attribute). Until then each road starts as a plain two-way road:
--   sidewalk A | <- <- -> -> | median | <- <- -> -> | sidewalk B
local lanes: { Lane } = {}
local half = math.floor(M.LanesPerRoad / 2)
for i = 1, M.LanesPerRoad do
	-- i counts from the road's -Z edge.
	table.insert(lanes, { z = -Layout.innerEdge + (i - 0.5) * M.LaneWidth, dir = if i <= half then -1 else 1, road = "A" })
end
for i = 1, M.LanesPerRoad do
	table.insert(lanes, { z = Layout.medianHalf + (i - 0.5) * M.LaneWidth, dir = if i <= half then -1 else 1, road = "B" })
end
Layout.lanes = lanes

-- Random direction for every lane, with both directions on each road (so no road is all one
-- way). Returns -1/1 per lane, in lane order.
function Layout.randomDirections(rng: Random): { number }
	local dirs = {}
	for _ = 1, 2 do -- road A, then road B
		local roadDirs
		repeat
			roadDirs = {}
			local sum = 0
			for _ = 1, M.LanesPerRoad do
				local d = if rng:NextNumber() < 0.5 then -1 else 1
				table.insert(roadDirs, d)
				sum += d
			end
		until math.abs(sum) < M.LanesPerRoad
		for _, d in roadDirs do
			table.insert(dirs, d)
		end
	end
	return dirs
end

-- Applies lane directions (from randomDirections or decodeDirections).
function Layout.setDirections(dirs: { number })
	for i, lane in lanes do
		local d = dirs[i]
		if d == 1 or d == -1 then
			lane.dir = d
		end
	end
end

-- "+--+-++-" style strings for the LaneDirs attribute.
function Layout.encodeDirections(): string
	local out = {}
	for _, lane in lanes do
		table.insert(out, if lane.dir > 0 then "+" else "-")
	end
	return table.concat(out)
end

function Layout.decodeDirections(text: string): { number }
	local dirs = {}
	for i = 1, #text do
		table.insert(dirs, if text:sub(i, i) == "+" then 1 else -1)
	end
	return dirs
end

-- "A" / "B" for the sidewalks, "Median", "Road", or nil off the sides.
function Layout.zoneOf(z: number): string?
	local az = math.abs(z)
	if az <= Layout.medianHalf then
		return "Median"
	elseif az <= Layout.innerEdge then
		return "Road"
	elseif az <= Layout.outerEdge then
		return if z < 0 then "A" else "B"
	end
	return nil
end

-- Index of the lane at z, if any.
function Layout.laneAt(z: number): number?
	for i, lane in lanes do
		if math.abs(lane.z - z) <= M.LaneWidth / 2 then
			return i
		end
	end
	return nil
end

function Layout.sideName(side: string): string
	return (M.SideNames :: any)[side] or side
end

return Layout
