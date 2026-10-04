--!strict
-- Run with: luau tests/Powerups.spec.luau
local PowerupLogic = require("../src/shared/PowerupLogic")

local failures = 0
local function check(name: string, ok: boolean)
	if ok then
		print("ok   " .. name)
	else
		failures += 1
		print("FAIL " .. name)
	end
end

-- A small deterministic random source.
local function lcg(seed: number): () -> number
	local state = seed
	return function()
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
end

-- Same as Layout with the default Config.Map: two 4-lane roads around a 30-stud median.
local LANES = { -81, -67, -53, -39, 39, 53, 67, 81 }
local AREA: PowerupLogic.Area = {
	laneZs = LANES,
	laneWidth = 14,
	medianHalf = 15,
	halfLength = 160,
	edgeMargin = 15,
	roadChance = 0.75,
	minSpacing = 20,
	nearRange = 45,
}

local function inLane(z: number): boolean
	for _, lane in LANES do
		if math.abs(z - lane) <= 14 * 0.2 + 1e-9 then
			return true
		end
	end
	return false
end

-- Spawn spots: on a lane or the median, inside the road ends, mostly in lanes.
do
	local random = lcg(7)
	local onRoad, onMedian, bad = 0, 0, 0
	for _ = 1, 2000 do
		local spot = PowerupLogic.pickSpot(random, AREA, {}, {})
		if math.abs(spot.x) > 145 then
			bad += 1
		elseif inLane(spot.z) then
			onRoad += 1
		elseif math.abs(spot.z) <= 12 then
			onMedian += 1
		else
			bad += 1
		end
	end
	check("spots land in a lane or on the median", bad == 0)
	check("most spots are on the road", onRoad > 1300 and onRoad < 1700)
	check("some spots are on the median", onMedian > 300)
end

-- Spots stay near the chickens (along the road) and clamp at the road ends.
do
	local random = lcg(11)
	local far = 0
	for _ = 1, 500 do
		local spot = PowerupLogic.pickSpot(random, AREA, {}, { 100 })
		if math.abs(spot.x - 100) > 45 + 1e-9 or spot.x > 145 then
			far += 1
		end
	end
	check("spots land near a chicken", far == 0)
end

-- Spots keep their distance from pickups already on the map.
do
	local random = lcg(3)
	local taken: { PowerupLogic.Spot } = {}
	for _ = 1, 4 do
		table.insert(taken, PowerupLogic.pickSpot(random, AREA, taken, {}))
	end
	local tooClose = false
	for i = 1, #taken do
		for j = i + 1, #taken do
			local dx, dz = taken[i].x - taken[j].x, taken[i].z - taken[j].z
			if math.sqrt(dx * dx + dz * dz) < 20 then
				tooClose = true
			end
		end
	end
	check("spots are spread out", not tooClose)
end

-- Bounty leader.
do
	local pick = PowerupLogic.pickLeader
	check("nobody under the minimum", pick(nil, { { id = "a", kos = 1, at = 1 }, { id = "b", kos = 0, at = 2 } }, 2) == nil)
	check("most knockouts leads", pick(nil, { { id = "a", kos = 2, at = 1 }, { id = "b", kos = 3, at = 2 } }, 2) == "b")
	check("tie goes to who got there first", pick(nil, { { id = "a", kos = 3, at = 5 }, { id = "b", kos = 3, at = 2 } }, 2) == "b")
	check("holder keeps the crown on a tie", pick("a", { { id = "a", kos = 3, at = 5 }, { id = "b", kos = 3, at = 2 } }, 2) == "a")
	check("crown changes hands when passed", pick("a", { { id = "a", kos = 3, at = 1 }, { id = "b", kos = 4, at = 2 } }, 2) == "b")
	check("eliminated holder (not a candidate) loses it", pick("a", { { id = "b", kos = 2, at = 2 } }, 2) == "b")
	check("eliminated holder and nobody else qualifies", pick("a", { { id = "b", kos = 1, at = 2 } }, 2) == nil)
	check("bounty reward", PowerupLogic.bountyReward(3, 20, 10) == 50)
end

if failures > 0 then
	error(`{failures} test(s) failed`)
end
print("all tests passed")
