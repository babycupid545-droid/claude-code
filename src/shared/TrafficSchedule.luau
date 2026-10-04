--!strict
-- Deterministic traffic.
--
-- The server picks a seed and a start time and sends them to every client. The server and
-- every client then build the exact same schedule from them, so each client can move its
-- cars locally (smooth, no network cost) while the server checks hits with the same math.
--
-- This module is pure Luau (no Roblox APIs) so it runs both in game and in tests/.

local TrafficSchedule = {}
TrafficSchedule.__index = TrafficSchedule

export type Ramp = {
	every: number,
	speedStep: number,
	densityStep: number,
	maxMult: number,
}

export type LaneSpec = { z: number, dir: number }

-- A stretch of the round where traffic is faster/denser (events like Speed Demons).
export type Window = { start: number, stop: number, speed: number, density: number }

export type Params = {
	seed: number,
	startTime: number,
	lanes: { LaneSpec },
	roadLength: number,
	carLength: number,
	baseSpeed: number,
	laneSpeedMin: number,
	laneSpeedMax: number,
	minGap: number,
	maxGap: number,
	ramp: Ramp?,
	suddenDeathAt: number?,
	suddenDeathMult: number?,
	windows: { Window }?, -- times relative to startTime
}

export type Car = {
	id: string,
	lane: number,
	dir: number, -- +1 drives towards +X, -1 towards -X
	speed: number,
	spawnTime: number, -- time the car's front bumper reaches the road edge
	kind: number, -- picks a car model; renderer takes it modulo the model count
	driver: number?, -- UserId of a Road Rage driver
	-- Special vehicles (the median harvester) override these:
	z: number?,
	length: number?,
	width: number?,
	height: number?,
	vehicle: string?,
}

type Lane = {
	index: number,
	dir: number,
	speed: number,
	seed: number,
	nextSpawn: number,
	count: number,
}

export type Schedule = typeof(setmetatable(
	{} :: {
		params: Params,
		lanes: { Lane },
		cars: { Car },
		generatedUntil: number,
	},
	TrafficSchedule
))

local LOOKAHEAD = 3
local KEEP_AFTER = 2

-- Park-Miller "minimal standard" generator. Every product stays below 2^53, so the
-- sequence is bit-for-bit identical on every machine.
local MODULUS = 2147483647
local function nextSeed(seed: number): number
	return (seed * 48271) % MODULUS
end
local function toUnit(seed: number): number
	return (seed - 1) / (MODULUS - 1)
end
local function normalizeSeed(seed: number): number
	local s = math.floor(math.abs(seed)) % MODULUS
	if s == 0 then
		s = 1
	end
	return s
end

function TrafficSchedule.new(params: Params): Schedule
	local self = setmetatable({
		params = params,
		lanes = {},
		cars = {},
		generatedUntil = params.startTime,
	}, TrafficSchedule)

	local seed = normalizeSeed(params.seed)
	for i, spec in params.lanes do
		seed = nextSeed(seed)
		local speedRoll = toUnit(seed)
		seed = nextSeed(seed)
		local laneSeed = seed
		seed = nextSeed(seed)
		local firstGap = toUnit(seed) * params.maxGap
		table.insert(self.lanes, {
			index = i,
			dir = spec.dir,
			speed = params.baseSpeed
				* (params.laneSpeedMin + (params.laneSpeedMax - params.laneSpeedMin) * speedRoll),
			seed = laneSeed,
			nextSpawn = params.startTime + firstGap,
			count = 0,
		})
	end
	return self
end

-- Speed and density multipliers at a moment of the round.
function TrafficSchedule.multipliers(self: Schedule, t: number): (number, number)
	local p = self.params
	local elapsed = t - p.startTime
	local speedMult, densityMult = 1, 1
	local ramp = p.ramp
	if ramp then
		local steps = math.max(0, math.floor(elapsed / ramp.every))
		speedMult = math.min(ramp.maxMult, 1 + steps * ramp.speedStep)
		densityMult = math.min(ramp.maxMult, 1 + steps * ramp.densityStep)
	end
	if p.suddenDeathAt and elapsed >= p.suddenDeathAt then
		local m = p.suddenDeathMult or 1.5
		speedMult *= m
		densityMult *= m
	end
	if p.windows then
		for _, w in p.windows do
			if elapsed >= w.start and elapsed < w.stop then
				speedMult *= w.speed
				densityMult *= w.density
			end
		end
	end
	return speedMult, densityMult
end

function TrafficSchedule.laneZ(self: Schedule, lane: number): number
	local spec = self.params.lanes[lane]
	return if spec then spec.z else 0
end

-- The z a car drives along (special vehicles carry their own).
function TrafficSchedule.carZ(self: Schedule, car: Car): number
	return car.z or self:laneZ(car.lane)
end

function TrafficSchedule.carLength(self: Schedule, car: Car): number
	return car.length or self.params.carLength
end

-- Where the car's center is at time t.
function TrafficSchedule.carX(self: Schedule, car: Car, t: number): number
	local p = self.params
	local startX = -car.dir * (p.roadLength / 2 + self:carLength(car) / 2)
	return startX + car.dir * car.speed * (t - car.spawnTime)
end

function TrafficSchedule.carEndTime(self: Schedule, car: Car): number
	local p = self.params
	return car.spawnTime + (p.roadLength + self:carLength(car)) / car.speed
end

function TrafficSchedule.addCar(self: Schedule, car: Car)
	table.insert(self.cars, car)
end

-- Generates cars up to t + LOOKAHEAD and forgets cars that left the road long ago.
-- Generation never depends on *when* update is called, only on the seed.
function TrafficSchedule.update(self: Schedule, t: number)
	local p = self.params
	local horizon = t + LOOKAHEAD
	if horizon > self.generatedUntil then
		for _, lane in self.lanes do
			while lane.nextSpawn <= horizon do
				local spawnTime = lane.nextSpawn
				local speedMult, densityMult = self:multipliers(spawnTime)
				lane.seed = nextSeed(lane.seed)
				local kind = 1 + (lane.seed % 1000)
				lane.count += 1
				table.insert(self.cars, {
					id = `{lane.index}:{lane.count}`,
					lane = lane.index,
					dir = lane.dir,
					speed = lane.speed * speedMult,
					spawnTime = spawnTime,
					kind = kind,
				})
				lane.seed = nextSeed(lane.seed)
				local gap = p.minGap + (p.maxGap - p.minGap) * toUnit(lane.seed)
				lane.nextSpawn = spawnTime + gap / densityMult
			end
		end
		self.generatedUntil = horizon
	end

	local i = 1
	while i <= #self.cars do
		if self:carEndTime(self.cars[i]) < t - KEEP_AFTER then
			-- Order doesn't matter, so swap-remove.
			self.cars[i] = self.cars[#self.cars]
			self.cars[#self.cars] = nil
		else
			i += 1
		end
	end
end

-- Cars on the road at time t. Call update(t) first.
function TrafficSchedule.activeCars(self: Schedule, t: number): { Car }
	local result = {}
	for _, car in self.cars do
		if t >= car.spawnTime and t <= self:carEndTime(car) then
			table.insert(result, car)
		end
	end
	return result
end

-- Cars that will enter the road within `within` seconds of t (for lane warning lights).
function TrafficSchedule.incomingCars(self: Schedule, t: number, within: number): { Car }
	local result = {}
	for _, car in self.cars do
		if car.spawnTime > t and car.spawnTime <= t + within then
			table.insert(result, car)
		end
	end
	return result
end

export type Box = {
	x: number,
	z: number,
	feetY: number,
	radius: number,
}

-- Returns the car overlapping a chicken at time t, if any. Chickens high enough in the air
-- (jumping or gliding) pass over cars.
function TrafficSchedule.findHit(
	self: Schedule,
	box: Box,
	t: number,
	roadTopY: number,
	carWidth: number,
	carHeight: number,
	forgiveness: number
): Car?
	for _, car in self.cars do
		if t >= car.spawnTime and t <= self:carEndTime(car) then
			local height = car.height or carHeight
			if box.feetY <= roadTopY + height - forgiveness then
				local reachX = self:carLength(car) / 2 + box.radius - forgiveness
				local reachZ = (car.width or carWidth) / 2 + box.radius - forgiveness
				if math.abs(self:carZ(car) - box.z) < reachZ and math.abs(self:carX(car, t) - box.x) < reachX then
					return car
				end
			end
		end
	end
	return nil
end

return TrafficSchedule
