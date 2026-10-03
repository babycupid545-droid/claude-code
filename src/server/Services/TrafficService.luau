--!strict
-- Server half of the traffic system. There are no car parts on the server: it builds the
-- same deterministic schedule as the clients and checks every living chicken against it.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local RoundState = require(Shared.RoundState)
local TrafficSchedule = require(Shared.TrafficSchedule)

local TrafficService = {}

local CHICKEN_RADIUS = 1.2

local schedule: TrafficSchedule.Schedule? = nil
local connection: RBXScriptConnection? = nil
local rageCount = 0

export type Options = {
	rushHour: boolean,
	startTime: number,
	suddenDeathAt: number,
	getChickens: () -> { Player },
	onHit: (Player, TrafficSchedule.Car) -> (),
}

local function chickenBox(player: Player): TrafficSchedule.Box?
	local character = player.Character
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return nil
	end
	local pos = root.Position
	local feetY = pos.Y - root.Size.Y / 2 - humanoid.HipHeight
	if humanoid.RigType == Enum.HumanoidRigType.R6 then
		-- R6 legs hang below the root instead of being counted in HipHeight.
		feetY -= 2
	end
	return {
		x = pos.X,
		z = pos.Z,
		feetY = feetY,
		radius = CHICKEN_RADIUS,
	}
end

function TrafficService.start(options: Options)
	TrafficService.stop()
	local T = Config.Traffic
	local params: TrafficSchedule.Params = {
		seed = Random.new():NextInteger(1, 2 ^ 30),
		startTime = options.startTime,
		laneCount = Config.Map.LaneCount,
		laneWidth = Config.Map.LaneWidth,
		roadLength = Config.Map.RoadLength,
		carLength = T.CarLength,
		baseSpeed = T.BaseSpeed,
		laneSpeedMin = T.LaneSpeedMin,
		laneSpeedMax = T.LaneSpeedMax,
		minGap = T.MinGap,
		maxGap = T.MaxGap,
		ramp = if options.rushHour
			then {
				every = Config.RushHour.Every,
				speedStep = Config.RushHour.SpeedStep,
				densityStep = Config.RushHour.DensityStep,
				maxMult = Config.RushHour.MaxMult,
			}
			else nil,
		suddenDeathAt = options.suddenDeathAt,
		suddenDeathMult = T.SuddenDeathMult,
	}
	local s = TrafficSchedule.new(params)
	schedule = s
	RoundState:SetAttribute("TrafficParams", HttpService:JSONEncode(params))

	connection = RunService.Heartbeat:Connect(function()
		local now = workspace:GetServerTimeNow()
		s:update(now)
		for _, player in options.getChickens() do
			local box = chickenBox(player)
			if box then
				-- The position we see is from when the player sent it, half a round trip ago.
				local ping = math.clamp(player:GetNetworkPing(), 0, 0.6)
				local t = now - ping / 2 - T.HitLatencyExtra
				local car =
					s:findHit(box, t, Config.Map.RoadTopY, T.CarWidth, T.CarHeight, T.HitForgiveness)
				if car then
					options.onHit(player, car)
				end
			end
		end
	end)
end

function TrafficService.stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	schedule = nil
	RoundState:SetAttribute("TrafficParams", "")
end

-- Road Rage: a driver sends one car down a lane. Everyone sees it after a short warning.
function TrafficService.launchRageCar(driver: Player, lane: number, dir: number): boolean
	local s = schedule
	if not s then
		return false
	end
	rageCount += 1
	local car: TrafficSchedule.Car = {
		id = `rage:{rageCount}`,
		lane = lane,
		dir = dir,
		speed = Config.RoadRage.Speed,
		spawnTime = workspace:GetServerTimeNow() + Config.RoadRage.LaunchDelay,
		kind = 0,
		driver = driver.UserId,
	}
	s:addCar(car)
	Remotes.RageCar:FireAllClients(car)
	return true
end

return TrafficService
