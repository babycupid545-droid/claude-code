--!strict
-- The round state lives as attributes on one replicated object, so every client UI can
-- just listen for attribute changes.
--
-- Attributes:
--   State          "Waiting" | "Voting" | "Starting" | "InRound" | "Results"
--   EndsAt         server time (workspace:GetServerTimeNow()) the current state ends, or 0
--   VoteOptions    JSON array of mode ids
--   Votes          JSON object modeId -> count
--   ModeId         the mode being played
--   TrafficParams  JSON TrafficSchedule.Params, or "" when there is no traffic
--   Message        big centered text (winner, countdown hints)
-- Player attributes:
--   Alive          true while a chicken is in the current round
--   Driver         true while driving in Road Rage
--   Team           "A" | "B" | nil

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAME = "RoundState"

if RunService:IsServer() then
	local existing = ReplicatedStorage:FindFirstChild(NAME)
	if existing then
		return existing :: Configuration
	end
	local state = Instance.new("Configuration")
	state.Name = NAME
	state:SetAttribute("State", "Waiting")
	state:SetAttribute("EndsAt", 0)
	state:SetAttribute("VoteOptions", "[]")
	state:SetAttribute("Votes", "{}")
	state:SetAttribute("ModeId", "")
	state:SetAttribute("TrafficParams", "")
	state:SetAttribute("Message", "")
	state.Parent = ReplicatedStorage
	return state
end

return ReplicatedStorage:WaitForChild(NAME) :: Configuration
