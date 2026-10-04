--!strict
-- Game modes. Each mode is data; RoundService reads these flags to run the round.
-- To add a mode: add an entry here and handle any new flag in RoundService.

export type Mode = {
	id: string,
	name: string,
	description: string,
	minPlayers: number,
	teams: boolean,
	rushHour: boolean,
	roadRage: boolean,
}

local Modes: { Mode } = {
	{
		id = "Solo",
		name = "Solo",
		description = "Every chicken for itself. Last one alive wins.",
		minPlayers = 1,
		teams = false,
		rushHour = false,
		roadRage = false,
	},
	{
		id = "Teams",
		name = "Teams",
		description = "Red vs Blue on opposite sides of the road. Last team standing wins.",
		minPlayers = 2,
		teams = true,
		rushHour = false,
		roadRage = false,
	},
	{
		id = "RushHour",
		name = "Rush Hour",
		description = "Traffic gets faster and busier every 15 seconds.",
		minPlayers = 1,
		teams = false,
		rushHour = true,
		roadRage = false,
	},
	{
		id = "RoadRage",
		name = "Road Rage",
		description = "Get squashed and you come back as a driver. Run them over!",
		minPlayers = 2,
		teams = false,
		rushHour = false,
		roadRage = true,
	},
}

local byId: { [string]: Mode } = {}
for _, mode in Modes do
	byId[mode.id] = mode
end

return {
	list = Modes,
	get = function(id: string): Mode?
		return byId[id]
	end,
}
