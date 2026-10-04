--!strict
-- Shape of a player's saved data, shared so the client knows what DataSync sends.

local Cosmetics = require(script.Parent.Cosmetics)
local Progression = require(script.Parent.Progression)

export type Equipped = {
	ChickenSkin: string,
	EggSkin: string,
	HitEffect: string,
	WinEffect: string,
	Emotes: { string },
}

export type Stats = {
	Wins: number,
	Rounds: number,
	Knockouts: number,
	Crossings: number,
}

-- Levels and titles. Level is worked out from Xp (Progression.levelInfo).
export type Progress = {
	Xp: number, -- lifetime XP
	Title: string, -- equipped title id ("" = none)
	Titles: { [string]: boolean }, -- titles granted by the season pass (others unlock by level/stats)
}

export type Quest = Progression.Quest
export type Quests = Progression.QuestState -- Day = UTC day number the quests are for
export type Season = Progression.SeasonState -- Claimed keys are "F<tier>" / "P<tier>"

export type Data = {
	Coins: number,
	Owned: { [string]: boolean },
	Equipped: Equipped,
	Stats: Stats,
	-- Recent Robux receipt ids, so a purchase is never granted twice.
	PurchaseIds: { string },
	Progress: Progress,
	Quests: Quests,
	Season: Season,
}

-- What the server sends to the owning client.
export type Snapshot = {
	coins: number,
	owned: { [string]: boolean },
	equipped: Equipped,
	stats: Stats,
	vip: boolean,
	progress: Progress,
	quests: Quests,
	season: Season,
}

local PlayerData = {}

function PlayerData.template(): Data
	return {
		Coins = 0,
		Owned = {},
		Equipped = {
			ChickenSkin = Cosmetics.default("ChickenSkin"),
			EggSkin = Cosmetics.default("EggSkin"),
			HitEffect = Cosmetics.default("HitEffect"),
			WinEffect = Cosmetics.default("WinEffect"),
			Emotes = { Cosmetics.default("Emote") },
		},
		Stats = {
			Wins = 0,
			Rounds = 0,
			Knockouts = 0,
			Crossings = 0,
		},
		PurchaseIds = {},
		-- Older saves get these filled in by Profile:Reconcile(); ProgressService repairs the rest.
		Progress = { Xp = 0, Title = "Hatchling", Titles = {} },
		Quests = { Day = 0, List = {}, Rerolls = 0 },
		Season = { Id = "", Xp = 0, Claimed = {}, Premium = false },
	}
end

-- Default items are always owned, even if they were added after the player's first visit.
function PlayerData.owns(owned: { [string]: boolean }, itemId: string): boolean
	local item = Cosmetics.get(itemId)
	return item ~= nil and (item.default == true or owned[itemId] == true)
end

return PlayerData
