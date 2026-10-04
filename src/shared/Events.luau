--!strict
-- Random round events. RoundService schedules a few per round; the client reads
-- RoundState.Event to show the banner and apply visual changes.

export type Event = {
	id: string,
	name: string,
	description: string,
	sprite: string,
	color: Color3,
}

local list: { Event } = {
	{ id = "NightDrive", name = "NIGHT DRIVE", description = "Lights out! Watch for headlights.", sprite = "star", color = Color3.fromRGB(110, 120, 255) },
	{ id = "Fog", name = "PEA SOUP FOG", description = "You can barely see the cars coming.", sprite = "info", color = Color3.fromRGB(180, 190, 200) },
	{ id = "EggRain", name = "GOLDEN EGG RAIN", description = "Grab golden eggs on the road for bonus eggs!", sprite = "egg", color = Color3.fromRGB(255, 205, 60) },
	{ id = "LowGravity", name = "LOW GRAVITY", description = "Jump higher, fall slower.", sprite = "feather", color = Color3.fromRGB(150, 220, 255) },
	{ id = "FeatherFrenzy", name = "FEATHER FRENZY", description = "Unlimited glide!", sprite = "feather", color = Color3.fromRGB(255, 255, 255) },
	{ id = "BigEggs", name = "BIG EGGS", description = "Eggs knock chickens way further.", sprite = "boom", color = Color3.fromRGB(255, 140, 60) },
	{ id = "SpeedDemons", name = "SPEED DEMONS", description = "Traffic goes much faster!", sprite = "lightning", color = Color3.fromRGB(255, 80, 80) },
	{ id = "HarvestTime", name = "HARVEST TIME", description = "Harvesters keep sweeping the median!", sprite = "car", color = Color3.fromRGB(110, 200, 90) },
}

local byId: { [string]: Event } = {}
for _, e in list do
	byId[e.id] = e
end

return {
	list = list,
	get = function(id: string?): Event?
		return if id then byId[id] else nil
	end,
}
