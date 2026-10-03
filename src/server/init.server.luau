--!strict
-- Server entry point.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Create remotes and the round state object before anything else uses them.
require(ReplicatedStorage.Shared.Remotes)
require(ReplicatedStorage.Shared.RoundState)

local Services = script.Services
require(Services.DataService).init()
require(Services.MonetizationService).init()
require(Services.ChickenService).init()
require(Services.EggService).init()
require(Services.EmoteService).init()
require(Services.RoundService).init()
