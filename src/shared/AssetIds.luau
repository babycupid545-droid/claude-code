--!strict
-- Paste the ids of the files you uploaded from assets/ here (see docs/ASSETS.md).
-- Numbers or "rbxassetid://..." strings both work. Leave 0 for anything not uploaded yet:
-- the game falls back to emoji icons and silence.

local ids = {
	-- assets/ui/UiSheet.png  (Image)
	UiSheet = 74198106090898,
	-- assets/ui/FarmSheet.png  (Image) - barn/wood HUD art and the golden egg currency icon
	FarmSheet = 133433996440989,
	-- assets/audio/Sfx.ogg  (Audio) - every sound effect in one file
	Sfx = 91824233357331,
	-- assets/audio/*.ogg  (Audio) - music loops
	MusicLobby = 127732959707686,
	MusicRound = 92407757121776,
	MusicSuddenDeath = 126264889973948,
}

local AssetIds = {}

-- "rbxassetid://123" for a set id, or "" when it hasn't been uploaded yet.
function AssetIds.get(name: string): string
	local value = (ids :: any)[name]
	if type(value) == "number" then
		return if value > 0 then `rbxassetid://{value}` else ""
	elseif type(value) == "string" then
		if value == "" or value:match("^rbxassetid://") then
			return value
		end
		local digits = value:match("%d+")
		return if digits then `rbxassetid://{digits}` else ""
	end
	return ""
end

return AssetIds
