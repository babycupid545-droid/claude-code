--!strict
-- Emotes: the server checks the player owns and equipped the emote, then tells every client
-- to show it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Cosmetics = require(Shared.Cosmetics)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)

local EmoteService = {}

local lastEmote: { [Player]: number } = {}

local function onEmote(player: Player, itemId: unknown)
	if type(itemId) ~= "string" then
		return
	end
	local item = Cosmetics.get(itemId)
	local data = DataService.get(player)
	if not item or item.slot ~= "Emote" or not data or not table.find(data.Equipped.Emotes, itemId) then
		return
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local t = os.clock()
	if t - (lastEmote[player] or 0) < Config.Emotes.Cooldown then
		return
	end
	lastEmote[player] = t
	Remotes.PlayEmote:FireAllClients(player.UserId, itemId)
end

function EmoteService.init()
	Remotes.Emote.OnServerEvent:Connect(onEmote)
	Players.PlayerRemoving:Connect(function(player)
		lastEmote[player] = nil
	end)
end

return EmoteService
