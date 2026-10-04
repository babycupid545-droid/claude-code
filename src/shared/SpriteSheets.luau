--!strict
-- Finds a named UI sprite on either sheet: the farm sheet (FarmSprites, assets/ui/FarmSheet.png)
-- or the original icon sheet (UiSprites, assets/ui/UiSheet.png).
--
-- Until FarmSheet is uploaded, farm icons borrow the closest icon from the original sheet, so
-- the UI never shows blanks (textures like woodTile just stay hidden).

local AssetIds = require(script.Parent.AssetIds)
local FarmSprites = require(script.Parent.FarmSprites)
local UiSprites = require(script.Parent.UiSprites)

export type Sprite = { offset: Vector2, size: Vector2 }

local SpriteSheets = {}

local STAND_INS: { [string]: string } = {
	eggCoin = "egg",
	bigEgg = "egg",
	basket = "egg",
	nest = "egg",
	barn = "flagRed",
	windmill = "flagBlue",
	chick = "chicken",
	eggCrack = "skull",
	rosette = "trophy",
	bell = "lightning",
	sun = "star",
	horseshoe = "star",
	corn = "gift",
	wheat = "gift",
	hayBale = "gift",
	pitchfork = "angry",
	cloud = "info",
	footprint = "chickenRun",
}

-- Returns the image id ("" if that sheet isn't uploaded) and the sprite's rect.
function SpriteSheets.find(name: string): (string, Sprite?)
	local farm = FarmSprites[name]
	if farm then
		local id = AssetIds.get("FarmSheet")
		if id ~= "" then
			return id, farm
		end
		local standIn = STAND_INS[name]
		if standIn and UiSprites[standIn] then
			return AssetIds.get("UiSheet"), UiSprites[standIn]
		end
		return "", farm
	end
	local ui = UiSprites[name]
	if ui then
		return AssetIds.get("UiSheet"), ui
	end
	return "", nil
end

-- The original-sheet name a farm sprite falls back to (for emoji fallbacks).
function SpriteSheets.standIn(name: string): string?
	return STAND_INS[name]
end

return SpriteSheets
