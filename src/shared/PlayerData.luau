--!strict
-- Shape of a player's saved data, shared so the client knows what DataSync sends.

local Cosmetics = require(script.Parent.Cosmetics)

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
}

export type Data = {
	Coins: number,
	Owned: { [string]: boolean },
	Equipped: Equipped,
	Stats: Stats,
	-- Recent Robux receipt ids, so a purchase is never granted twice.
	PurchaseIds: { string },
}

-- What the server sends to the owning client.
export type Snapshot = {
	coins: number,
	owned: { [string]: boolean },
	equipped: Equipped,
	stats: Stats,
	vip: boolean,
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
		},
		PurchaseIds = {},
	}
end

-- Default items are always owned, even if they were added after the player's first visit.
function PlayerData.owns(owned: { [string]: boolean }, itemId: string): boolean
	local item = Cosmetics.get(itemId)
	return item ~= nil and (item.default == true or owned[itemId] == true)
end

return PlayerData
