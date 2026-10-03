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
	-- The road runs along the X axis; chickens cross it along Z.
	RoadLength = 240,
	LaneCount = 6,
	LaneWidth = 14,
	RoadTopY = 0,
	-- Sidewalk A is at negative Z, sidewalk B at positive Z.
	SidewalkDepth = 40,
	SidewalkRows = 4,
	SidewalkColumns = 12,
	SidewalkTopY = 0.5,
	WallHeight = 80,
	-- Anything below this is eliminated (fell off the map).
	KillY = -40,
	LobbyCenter = Vector3.new(0, 70, -150),
	LobbySize = Vector3.new(90, 1, 50),
}

Config.Chicken = {
	WalkSpeed = 18,
	JumpPower = 75, -- about 14 studs high: enough to clear a car with good timing
	GlideFallSpeed = 9,
	GlideHorizontalSpeed = 26,
	GlideStamina = 1.6, -- seconds of gliding
	GlideRecharge = 0.8, -- stamina per second while on the ground
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
	Cooldown = 0.5,
	Radius = 0.6,
	KnockbackHorizontal = 60,
	KnockbackUp = 28,
	KnockbackDuration = 0.25,
}

Config.Sidewalk = {
	-- Solo-style modes: one whole sidewalk collapses at a time, forcing everyone across.
	FirstCollapseAt = 20,
	-- Pause between one collapse ending and the next warning; shrinks each time.
	CollapseRest = 12,
	CollapseRestMin = 4,
	CollapseRestStep = 2,
	CollapseWarning = 4,
	CollapseDuration = 7,
	-- Teams: the outer row of both sidewalks falls away on a timer.
	ShrinkInterval = 25,
	ShrinkWarning = 4,
	MinRows = 1,
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
	Knockout = 15, -- egging someone shortly before they die
	KnockoutWindow = 4,
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
		{ productId = 0, coins = 500, name = "Handful of Coins" },
		{ productId = 0, coins = 1500, name = "Bucket of Coins" },
		{ productId = 0, coins = 5000, name = "Barn of Coins" },
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
