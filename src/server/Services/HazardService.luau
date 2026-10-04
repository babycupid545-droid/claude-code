--!strict
-- Dangers on the grass median: a combine harvester sweeps it now and then (after a warning),
-- and sprinklers burst, knocking nearby chickens around. Plus golden eggs during Egg Rain.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Layout = require(Shared.Layout)
local Remotes = require(Shared.Remotes)

local Services = script.Parent
local ChickenService = require(Services.ChickenService)
local DataService = require(Services.DataService)
local TrafficService = require(Services.TrafficService)

local HazardService = {}

local rng = Random.new()
local sprinklers: { BasePart } = {}
local running = 0 -- bumped to stop the loops of a previous round
local harvestEvery: number? = nil -- set during Harvest Time

export type Context = {
	getChickens: () -> { Player },
	isAlive: (Player) -> boolean,
}

local function burstSprinkler(index: number, ctx: Context)
	local head = sprinklers[index]
	if not head then
		return
	end
	local M = Config.Median
	Remotes.Sprinkler:FireAllClients(index, "warn")
	task.wait(M.SprinklerWarning)
	Remotes.Sprinkler:FireAllClients(index, "burst")
	for _, player in ctx.getChickens() do
		local root = ChickenService.getRoot(player)
		if root then
			local offset = (root.Position - head.Position) * Vector3.new(1, 0, 1)
			local dist = offset.Magnitude
			if dist < M.SprinklerRadius then
				local away = if dist > 0.1 then offset.Unit else Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)).Unit
				local strength = M.SprinklerPush * (1 - dist / M.SprinklerRadius * 0.5)
				Remotes.Knockback:FireClient(player, away * strength + Vector3.new(0, 35, 0))
			end
		end
	end
end

local function sprinklerLoop(gen: number, ctx: Context)
	local M = Config.Median
	while running == gen do
		task.wait(rng:NextNumber(M.SprinklerEveryMin, M.SprinklerEveryMax))
		if running ~= gen or #sprinklers == 0 then
			continue
		end
		task.spawn(burstSprinkler, rng:NextInteger(1, #sprinklers), ctx)
	end
end

local function harvesterLoop(gen: number)
	local M = Config.Median
	task.wait(rng:NextNumber(8, 14))
	while running == gen do
		local dir = if rng:NextNumber() < 0.5 then 1 else -1
		if TrafficService.launchHarvester(dir) then
			Remotes.Feed:FireAllClients("A harvester is coming down the median!", "car")
		end
		local wait = harvestEvery or rng:NextNumber(M.HarvesterEveryMin, M.HarvesterEveryMax)
		task.wait(wait)
	end
end

-- Golden egg pickups -------------------------------------------------------------------------

local eggFolder: Folder? = nil

local function spawnGoldenEgg(gen: number, ctx: Context)
	local E = Config.Events
	local lane = Layout.lanes[rng:NextInteger(1, #Layout.lanes)]
	local z = if rng:NextNumber() < 0.25 then rng:NextNumber(-Layout.medianHalf + 2, Layout.medianHalf - 2) else lane.z
	local x = rng:NextNumber(-Layout.halfLength + 15, Layout.halfLength - 15)
	local egg = Instance.new("Part")
	egg.Name = "GoldenEgg"
	egg.Anchored = true
	egg.CanCollide = false
	egg.CanQuery = false
	egg.CanTouch = false
	egg.Size = Vector3.new(1.6, 2.1, 1.6)
	egg.Color = Color3.fromRGB(255, 200, 50)
	egg.Material = Enum.Material.Neon
	egg.Position = Vector3.new(x, Config.Map.RoadTopY + 1.6, z)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = egg
	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = Color3.fromRGB(255, 230, 120)
	sparkles.Parent = egg
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 210, 90)
	light.Range = 10
	light.Parent = egg
	egg:AddTag("Bob")
	egg:SetAttribute("BobSpin", true)
	egg.Parent = eggFolder

	local expires = os.clock() + E.EggRainLifetime
	task.spawn(function()
		while egg.Parent and os.clock() < expires and running == gen do
			for _, player in ctx.getChickens() do
				local root = ChickenService.getRoot(player)
				if root and (root.Position - egg.Position).Magnitude < 4 then
					DataService.reward(player, E.EggRainReward, "from a golden egg!")
					Remotes.EggPickup:FireAllClients(egg.Position, player.UserId)
					egg:Destroy()
					return
				end
			end
			task.wait(0.1)
		end
		egg:Destroy()
	end)
end

function HazardService.eggRain(seconds: number, ctx: Context)
	local gen = running
	local stop = os.clock() + seconds
	task.spawn(function()
		while os.clock() < stop and running == gen do
			spawnGoldenEgg(gen, ctx)
			task.wait(Config.Events.EggRainEvery)
		end
	end)
end

-- Harvest Time: harvesters every few seconds until cleared.
function HazardService.setHarvestEvery(seconds: number?)
	harvestEvery = seconds
end

-- Round control --------------------------------------------------------------------------------

function HazardService.start(arena: Instance, ctx: Context)
	running += 1
	harvestEvery = nil
	sprinklers = {}
	local median = arena:FindFirstChild("Median")
	if median then
		for _, d in median:GetDescendants() do
			if d:IsA("BasePart") and d:GetAttribute("Sprinkler") then
				table.insert(sprinklers, d)
			end
		end
		table.sort(sprinklers, function(a, b)
			return (a:GetAttribute("Sprinkler") :: number) < (b:GetAttribute("Sprinkler") :: number)
		end)
	end
	if eggFolder then
		eggFolder:Destroy()
	end
	local f = Instance.new("Folder")
	f.Name = "GoldenEggs"
	f.Parent = workspace
	eggFolder = f
	local gen = running
	task.spawn(sprinklerLoop, gen, ctx)
	task.spawn(harvesterLoop, gen)
end

function HazardService.stop()
	running += 1
	harvestEvery = nil
	if eggFolder then
		eggFolder:Destroy()
		eggFolder = nil
	end
end

return HazardService
