--!strict
-- Checks that the uploaded sound and image assets can load, and explains in the Output
-- window what's wrong if they can't. Runs once when you join.

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetIds = require(ReplicatedStorage.Shared.AssetIds)

local AudioCheck = {}

local NAMES = { "Sfx", "MusicLobby", "MusicRound", "MusicSuddenDeath", "UiSheet", "FarmSheet" }

function AudioCheck.run()
	task.spawn(function()
		local probes: { Instance } = {}
		local nameOf: { [string]: string } = {}
		for _, name in NAMES do
			local id = AssetIds.get(name)
			if id == "" then
				warn(`[Assets] {name}: no id set in src/shared/AssetIds.luau`)
			else
				local probe: Instance
				if name == "UiSheet" or name == "FarmSheet" then
					local image = Instance.new("ImageLabel")
					image.Image = id
					probe = image
				else
					local sound = Instance.new("Sound")
					sound.SoundId = id
					probe = sound
				end
				nameOf[id] = name
				table.insert(probes, probe)
			end
		end
		local failed = 0
		ContentProvider:PreloadAsync(probes, function(assetId: string, status: Enum.AssetFetchStatus)
			local name = nameOf[assetId] or assetId
			if status == Enum.AssetFetchStatus.Success then
				print(`[Assets] {name}: loaded`)
			else
				failed += 1
				warn(`[Assets] {name} ({assetId}) failed to load: {status.Name}`)
			end
		end)
		if failed > 0 then
			warn(
				"[Assets] Some files didn't load. Usual causes: (1) Roblox is still reviewing a new upload; "
					.. "wait a few minutes and try again. (2) The files were uploaded to your account but the game "
					.. "belongs to a group (or the other way round): upload them to the same owner as the game. "
					.. "(3) The place isn't published yet: File > Publish to Roblox, then test again."
			)
		end
		for _, probe in probes do
			probe:Destroy()
		end
	end)
end

return AudioCheck
