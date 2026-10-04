--!strict
-- Run with: luau tests/TrafficSchedule.spec.luau
local TrafficSchedule = require("../src/shared/TrafficSchedule")

local failures = 0
local function check(name: string, ok: boolean)
	if ok then
		print("ok   " .. name)
	else
		failures += 1
		print("FAIL " .. name)
	end
end

local function params(seed: number): TrafficSchedule.Params
	return {
		seed = seed,
		startTime = 1000,
		lanes = {
			{ z = -64, dir = 1 }, { z = -50, dir = 1 }, { z = -36, dir = 1 }, { z = -22, dir = 1 },
			{ z = 22, dir = -1 }, { z = 36, dir = -1 }, { z = 50, dir = -1 }, { z = 64, dir = -1 },
		},
		roadLength = 240,
		carLength = 14,
		baseSpeed = 120,
		laneSpeedMin = 0.8,
		laneSpeedMax = 1.45,
		minGap = 1.3,
		maxGap = 3.6,
		suddenDeathAt = 120,
		suddenDeathMult = 1.5,
	}
end

local function snapshot(s: TrafficSchedule.Schedule, t: number): string
	local parts = {}
	local cars = s:activeCars(t)
	table.sort(cars, function(a, b)
		return a.id < b.id
	end)
	for _, car in cars do
		table.insert(parts, string.format("%s@%.4f", car.id, s:carX(car, t)))
	end
	return table.concat(parts, ",")
end

-- Same seed gives the same cars, no matter how often or when update is called.
do
	local a = TrafficSchedule.new(params(42))
	local b = TrafficSchedule.new(params(42))
	local t = 1000
	while t < 1060 do
		t += 1 / 60
		a:update(t)
	end
	b:update(1030)
	b:update(1060)
	check("deterministic across update cadence", snapshot(a, 1060) == snapshot(b, 1060))
	check("there is traffic", #a:activeCars(1060) > 0)
end

do
	local a = TrafficSchedule.new(params(1))
	local b = TrafficSchedule.new(params(2))
	a:update(1030)
	b:update(1030)
	check("different seeds differ", snapshot(a, 1030) ~= snapshot(b, 1030))
end

-- Cars stay inside their lane's travel range and move in the lane direction.
do
	local s = TrafficSchedule.new(params(7))
	s:update(1020)
	local okRange, okDir = true, true
	for _, car in s:activeCars(1020) do
		local x = s:carX(car, 1020)
		if math.abs(x) > 240 / 2 + 14 then
			okRange = false
		end
		local lane = s.lanes[car.lane]
		if lane.dir ~= car.dir then
			okDir = false
		end
	end
	check("cars on road range", okRange)
	check("cars follow lane direction", okDir)
end

-- A chicken standing on a car gets hit; jumping above it does not.
do
	local s = TrafficSchedule.new(params(9))
	s:update(1010)
	local car = s:activeCars(1010)[1]
	local x, z = s:carX(car, 1010), s:laneZ(car.lane)
	local hit = s:findHit({ x = x, z = z, feetY = 0, radius = 1 }, 1010, 0, 8, 6, 0.75)
	check("standing in a car's path is a hit", hit ~= nil)
	local overhead = s:findHit({ x = x, z = z, feetY = 8, radius = 1 }, 1010, 0, 8, 6, 0.75)
	check("flying over a car is safe", overhead == nil)
	local sidewalk = s:findHit({ x = x, z = 90, feetY = 0, radius = 1 }, 1010, 0, 8, 6, 0.75)
	check("sidewalk is safe", sidewalk == nil)
end

-- Sudden death makes traffic faster.
do
	local s = TrafficSchedule.new(params(3))
	local before = s:multipliers(1000 + 119)
	local after = s:multipliers(1000 + 121)
	check("sudden death speeds up", after > before)
end

-- Rush hour ramps up and is capped.
do
	local p = params(3)
	p.ramp = { every = 15, speedStep = 0.12, densityStep = 0.15, maxMult = 2.2 }
	p.suddenDeathAt = nil
	local s = TrafficSchedule.new(p)
	local m0 = s:multipliers(1000)
	local m1 = s:multipliers(1000 + 31)
	local mMax = s:multipliers(1000 + 10000)
	check("rush hour ramps", m1 > m0)
	check("rush hour capped", mMax == 2.2)
end

-- Extra (Road Rage) cars are hit-checked like normal ones.
do
	local s = TrafficSchedule.new(params(5))
	s:addCar({ id = "rage:1", lane = 2, dir = 1, speed = 170, spawnTime = 1005, kind = 1, driver = 123 })
	s:update(1005.5)
	local car = nil
	for _, c in s:activeCars(1005.5) do
		if c.id == "rage:1" then
			car = c
		end
	end
	check("rage car is active", car ~= nil)
end

-- Special vehicles use their own z and size (the median harvester).
do
	local s = TrafficSchedule.new(params(11))
	s:addCar({ id = "h:1", lane = 0, dir = 1, speed = 50, spawnTime = 1000, kind = 0, z = 0, length = 20, width = 22, height = 9, vehicle = "Harvester" })
	s:update(1002)
	local x = s:carX(s.cars[#s.cars], 1002)
	for _, c in s.cars do
		if c.id == "h:1" then
			x = s:carX(c, 1002)
		end
	end
	check("harvester hits on the median", s:findHit({ x = x, z = 8, feetY = 0, radius = 1 }, 1002, 0, 8, 6, 0.75) ~= nil)
	check("harvester is tall", s:findHit({ x = x, z = 0, feetY = 7, radius = 1 }, 1002, 0, 8, 6, 0.75) ~= nil)
end

-- Event windows speed traffic up only while they last.
do
	local p = params(4)
	p.suddenDeathAt = nil
	p.windows = { { start = 30, stop = 50, speed = 1.6, density = 1.3 } }
	local s = TrafficSchedule.new(p)
	check("window off before", s:multipliers(1000 + 29) == 1)
	check("window on during", s:multipliers(1000 + 40) == 1.6)
	check("window off after", s:multipliers(1000 + 51) == 1)
end

if failures > 0 then
	error(`{failures} test(s) failed`)
end
print("all tests passed")
