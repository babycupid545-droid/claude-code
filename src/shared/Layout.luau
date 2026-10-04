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

-- Lanes ordered from side A to side B. Each road is a two-way road with right-hand traffic:
-- the two lanes on its -Z half drive -X, the two on its +Z half drive +X, with a double
-- yellow centre line between them. Both roads use the same pattern:
--   sidewalk A | <- <- || -> -> | median | <- <- || -> -> | sidewalk B
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
