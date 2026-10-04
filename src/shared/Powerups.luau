--!strict
-- Power-ups and special eggs that spawn on the road during a round (see PowerupService).
-- "Power" pickups give one timed or one-shot ability; "Egg" pickups load your next few eggs.
--
-- Player attributes (set by the server, read by the HUD and the visuals):
--   Powerup         id of the power-up you hold ("" / nil when none)
--   PowerupEndsAt   server time a timed power-up runs out (0 for one-shot ones)
--   SpecialEgg      id of the special egg loaded ("" / nil when none)
--   SpecialAmmo     how many special eggs are left
--   StuckUntil      server time a sticky egg wears off (slowed, can't glide)
--   Bounty          golden eggs paid for knocking out this chicken (the crowned leader)

export type Def = {
	id: string,
	name: string,
	kind: "Power" | "Egg",
	description: string,
	sprite: string,
	color: Color3,
	-- Tint for sprites that are plain white shapes (e.g. "splat").
	tint: Color3?,
}

local list: { Def } = {
	{ id = "Speed", name = "SPEED BOOTS", kind = "Power", description = "Run faster for a few seconds!", sprite = "lightning", color = Color3.fromRGB(255, 214, 64) },
	{ id = "Shield", name = "SHIELD", kind = "Power", description = "The next car just bumps you aside.", sprite = "heart", color = Color3.fromRGB(110, 200, 255) },
	{ id = "MegaEgg", name = "MEGA EGG", kind = "Power", description = "Your next egg is HUGE.", sprite = "bigEgg", color = Color3.fromRGB(255, 140, 50) },
	{ id = "Feather", name = "EXTRA FEATHER", kind = "Power", description = "Double glide, fully refilled!", sprite = "feather", color = Color3.fromRGB(215, 245, 255) },
	{ id = "Sticky", name = "STICKY EGGS", kind = "Egg", description = "Hits slow chickens down and ground them.", sprite = "splat", color = Color3.fromRGB(120, 230, 90), tint = Color3.fromRGB(120, 230, 90) },
	{ id = "Bouncy", name = "BOUNCY EGGS", kind = "Egg", description = "Ricochet once towards the nearest chicken.", sprite = "sparkle", color = Color3.fromRGB(255, 110, 200) },
	{ id = "Explosive", name = "EXPLOSIVE EGGS", kind = "Egg", description = "Blast every chicken nearby.", sprite = "boom", color = Color3.fromRGB(255, 90, 50) },
	{ id = "Golden", name = "GOLDEN EGGS", kind = "Egg", description = "Steal golden eggs from whoever you hit.", sprite = "eggCoin", color = Color3.fromRGB(255, 200, 40) },
}

local byId: { [string]: Def } = {}
local powers: { string } = {}
local eggs: { string } = {}
for _, def in list do
	byId[def.id] = def
	table.insert(if def.kind == "Power" then powers else eggs, def.id)
end

return {
	list = list,
	-- Ids by kind, for picking what spawns.
	powers = powers,
	eggs = eggs,
	get = function(id: unknown): Def?
		return if type(id) == "string" then byId[id] else nil
	end,
}
