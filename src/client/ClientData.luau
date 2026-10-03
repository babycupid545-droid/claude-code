--!strict
-- The local player's saved data, kept up to date by the server's DataSync remote.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local PlayerData = require(Shared.PlayerData)
local Remotes = require(Shared.Remotes)

local ClientData = {}

local changed = Instance.new("BindableEvent")
-- Fires with no arguments whenever the data changes.
ClientData.Changed = changed.Event

local current: PlayerData.Snapshot? = nil

Remotes.DataSync.OnClientEvent:Connect(function(snapshot: PlayerData.Snapshot)
	current = snapshot
	changed:Fire()
end)

function ClientData.get(): PlayerData.Snapshot?
	return current
end

function ClientData.owns(itemId: string): boolean
	local data = current
	return data ~= nil and PlayerData.owns(data.owned, itemId)
end

function ClientData.isEquipped(itemId: string): boolean
	local data = current
	if not data then
		return false
	end
	local e = data.equipped
	return e.ChickenSkin == itemId
		or e.EggSkin == itemId
		or e.HitEffect == itemId
		or e.WinEffect == itemId
		or table.find(e.Emotes, itemId) ~= nil
end

function ClientData.equipped(slot: "EggSkin" | "HitEffect" | "WinEffect" | "ChickenSkin"): string?
	local data = current
	return if data then (data.equipped :: any)[slot] else nil
end

return ClientData
