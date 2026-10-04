--!strict
-- Random events during a round (Night Drive, Egg Rain, Low Gravity...). The whole schedule is
-- picked when the round starts, so traffic speed-ups can be baked into the deterministic
-- traffic schedule that every client also computes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Events = require(Shared.Events)
local Remotes = require(Shared.Remotes)
local RoundState = require(Shared.RoundState)
local TrafficSchedule = require(Shared.TrafficSchedule)

local Services = script.Parent
local EggService = require(Services.EggService)
local HazardService = require(Services.HazardService)

local EventService = {}

export type Planned = { id: string, at: number, stop: number } -- seconds after the round goes live

local DEFAULT_GRAVITY = 196.2
local rng = Random.new()
local running = 0

-- Picks events for a round of `length` seconds.
function EventService.plan(length: number): { Planned }
	local E = Config.Events
	local pool = table.clone(Events.list)
	local planned: { Planned } = {}
	local at = E.FirstAt
	while at + E.Duration <= length and #pool > 0 do
		local event = table.remove(pool, rng:NextInteger(1, #pool)) :: Events.Event
		table.insert(planned, { id = event.id, at = at, stop = at + E.Duration })
		at += E.Duration + E.Gap
	end
	return planned
end

-- Traffic speed-up windows for the plan, relative to the traffic start time.
function EventService.trafficWindows(planned: { Planned }, offset: number): { TrafficSchedule.Window }
	local windows = {}
	for _, p in planned do
		if p.id == "SpeedDemons" then
			table.insert(windows, {
				start = offset + p.at,
				stop = offset + p.stop,
				speed = Config.Events.SpeedDemonsMult,
				density = 1.3,
			})
		end
	end
	return windows
end

local function apply(id: string, on: boolean, ctx: HazardService.Context)
	local E = Config.Events
	if id == "LowGravity" then
		workspace.Gravity = if on then E.LowGravity else DEFAULT_GRAVITY
	elseif id == "BigEggs" then
		EggService.setKnockbackMult(if on then E.BigEggsMult else 1)
	elseif id == "EggRain" and on then
		HazardService.eggRain(E.Duration, ctx)
	elseif id == "HarvestTime" then
		HazardService.setHarvestEvery(if on then E.HarvestTimeEvery else nil)
	end
	-- NightDrive, Fog, FeatherFrenzy and SpeedDemons visuals happen on the clients.
end

local function clearAll()
	workspace.Gravity = DEFAULT_GRAVITY
	EggService.setKnockbackMult(1)
	HazardService.setHarvestEvery(nil)
	RoundState:SetAttribute("Event", "")
	RoundState:SetAttribute("EventEndsAt", 0)
end

-- Runs the plan; `roundStart` is the server time the round went live.
function EventService.run(planned: { Planned }, roundStart: number, ctx: HazardService.Context)
	running += 1
	local gen = running
	task.spawn(function()
		for _, p in planned do
			local wait = roundStart + p.at - workspace:GetServerTimeNow()
			if wait > 0 then
				task.wait(wait)
			end
			if running ~= gen then
				return
			end
			local event = Events.get(p.id)
			if event then
				RoundState:SetAttribute("Event", p.id)
				RoundState:SetAttribute("EventEndsAt", roundStart + p.stop)
				Remotes.Feed:FireAllClients(`EVENT: {event.name}! {event.description}`, event.sprite)
				apply(p.id, true, ctx)
				-- Wait until the absolute end time so events don't drift from EventEndsAt.
				task.wait(math.max(0, roundStart + p.stop - workspace:GetServerTimeNow()))
				if running ~= gen then
					return
				end
				apply(p.id, false, ctx)
				RoundState:SetAttribute("Event", "")
				RoundState:SetAttribute("EventEndsAt", 0)
			end
		end
	end)
end

function EventService.stop()
	running += 1
	clearAll()
end

return EventService
