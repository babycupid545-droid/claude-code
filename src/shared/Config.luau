--!strict
-- All gameplay tuning numbers live here so balancing never needs a code change.
-- Distances are in studs, times in seconds, speeds in studs/second.

local RunService = game:GetService("RunService")

local Config = {}

Config.MaxPlayers = 16
-- In Studio you can test alone; live servers need two chickens to start a round.
Config.MinPlayers = if RunService:IsStudio() then 1 else 2

Config.Timing = {
	VoteDuration = 15,
	CountdownDuration = 5,
	ResultsDuration = 7,
	RoundTimeLimit = 240,
	-- Every mode speeds up traffic at this point so rounds always end.
	SuddenDeathAt = 120,
	RespawnTime = 3,
}

Config.Map = {
	-- Two roads run along the X axis with a grass median between them; chickens cross along Z.
	--   sidewalk A | road A | median | road B | sidewalk B
	-- Each road is two-way: half its lanes drive -X, half +X (see Layout.lanes).
	RoadLength = 320,
	LanesPerRoad = 4,
	LaneWidth = 14,
	MedianWidth = 30,
	RoadTopY = 0,
	SidewalkDepth = 40,
	SidewalkRows = 4,
	SidewalkColumns = 20,
	SidewalkTopY = 0.5,
	WallHeight = 80,
	-- Anything below this is eliminated (fell off the map).
	KillY = -40,
	LobbyCenter = Vector3.new(0, 70, -205),
	LobbySize = Vector3.new(90, 1, 50),
	-- What players call each side (signs and HUD).
	SideNames = { A = "BARN", B = "WINDMILL" },
}

Config.Chicken = {
	WalkSpeed = 14,
	JumpPower = 62, -- about 10 studs high: clears a car only with good timing
	GlideFallSpeed = 9,
	GlideHorizontalSpeed = 26,
	GlideStamina = 1.0, -- seconds of gliding
	GlideRecharge = 2.0, -- stamina per second while on the ground (refills in under a second)
}

Config.Traffic = {
	CarLength = 14,
	CarWidth = 8,
	CarHeight = 6,
	BaseSpeed = 120,
	LaneSpeedMin = 0.8,
	LaneSpeedMax = 1.45,
	MinGap = 1.3,
	MaxGap = 3.6,
	SuddenDeathMult = 1.5,
	-- Hits are forgiven by this many studs so near-misses feel fair.
	HitForgiveness = 0.75,
	-- Extra delay (on top of half the player's ping) when checking hits on the server.
	HitLatencyExtra = 0.05,
	-- How long before a car enters the road its lane warning light turns on.
	WarningTime = 0.7,
}

Config.RushHour = {
	Every = 15,
	SpeedStep = 0.12,
	DensityStep = 0.15,
	MaxMult = 2.2,
}

Config.Egg = {
	Speed = 140,
	Gravity = 40,
	Lifetime = 1.6,
	Cooldown = 1.2, -- seconds between eggs (shown under the stats bar)
	Radius = 0.6,
	KnockbackHorizontal = 60,
	KnockbackUp = 28,
	KnockbackDuration = 0.25,
}

-- Crossing: everyone must reach the other sidewalk before the one they're on crumbles.
-- It rises again a moment later, and then they must cross back. Each phase is shorter.
Config.Shuttle = {
	FirstPhase = 25, -- seconds to make the first crossing (walking the 142-stud gap takes ~10s)
	PhaseStep = 2, -- each following phase is this much shorter...
	MinPhase = 15, -- ...down to this
	EarlyAfter = 3, -- once every chicken is across (and at least this long has passed), move on
	Warning = 4, -- tiles shake and flash for this long before dropping
	RiseDelay = 3, -- how long a dropped sidewalk stays down
}

-- The grass median is safe from cars but not from these.
Config.Median = {
	HarvesterEveryMin = 16,
	HarvesterEveryMax = 26,
	HarvesterWarning = 2.5,
	HarvesterSpeed = 55,
	HarvesterLength = 20,
	HarvesterWidth = 22,
	HarvesterHeight = 9,
	SprinklerEveryMin = 2.5,
	SprinklerEveryMax = 5,
	SprinklerWarning = 1,
	SprinklerRadius = 13,
	SprinklerPush = 70,
}

-- Random events that spice up rounds. Several per round, each announced on screen.
Config.Events = {
	FirstAt = 25, -- seconds into the round
	Gap = 18, -- quiet time between events
	Duration = 24,
	SpeedDemonsMult = 1.6,
	LowGravity = 70,
	BigEggsMult = 2.3,
	EggRainEvery = 0.35,
	EggRainReward = 3,
	EggRainLifetime = 7,
	HarvestTimeEvery = 5,
}

Config.RoadRage = {
	Cooldown = 3,
	Speed = 170,
	LaunchDelay = 0.6,
}

Config.Rewards = {
	Participate = 10,
	SurviveEvery = 30, -- seconds alive per survival bonus
	SurviveCoins = 5,
	Knockout = 25, -- the last chicken to egg someone gets this when they die
	KnockoutWindow = 0, -- seconds the egg credit lasts (0 = until the chicken dies)
	Win = 50,
	TeamWin = 30,
}

Config.Emotes = {
	MaxEquipped = 4,
	Cooldown = 2,
}

-- Robux. Create these in the Creator Dashboard (Monetization > Developer Products / Passes)
-- and paste the ids here. Anything left at 0 is shown as "coming soon" and can't be bought.
Config.Monetization = {
	VipGamePassId = 0,
	VipCoinMultiplier = 2,
	CoinPacks = {
		{ productId = 0, coins = 500, name = "Basket of Eggs" },
		{ productId = 0, coins = 1500, name = "Nest of Eggs" },
		{ productId = 0, coins = 5000, name = "Barn Full of Eggs" },
	},
	-- Robux-only cosmetics: item id -> developer product id.
	ItemProducts = {
		Rainbow = 0,
		DiamondEgg = 0,
		LoveTap = 0,
		Supernova = 0,
		Flex = 0,
	} :: { [string]: number },
}

return Config
