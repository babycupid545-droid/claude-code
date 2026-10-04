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
	-- Every lane gets a random direction each round (see Layout.randomDirections).
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
	-- The lobby floats above and behind side A. Its viewing deck sticks out a further 12
	-- studs towards the road (+Z) from the front edge of LobbySize.
	LobbyCenter = Vector3.new(0, 70, -222),
	LobbySize = Vector3.new(140, 1, 84),
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

-- Power-ups and special eggs that pop up on the road and median during rounds (see
-- Shared/Powerups). Mostly in the lanes: risky to grab, big payoff.
Config.Powerups = {
	FirstAt = 10, -- seconds into the round
	EveryMin = 5, -- seconds between spawns
	EveryMax = 9,
	MaxOnMap = 3,
	Lifetime = 16, -- an untouched pickup vanishes after this
	PickupRadius = 4.5,
	RoadChance = 0.75, -- the rest land on the median
	NearRange = 45, -- lands within this many studs (along the road) of a random chicken
	SpecialChance = 0.35, -- chance a spawn is a special egg rather than a power-up
	SpeedMult = 1.4,
	SpeedDuration = 6,
	FeatherDuration = 8,
	FeatherGlideMult = 2,
	ShieldGrace = 1.2, -- after a shield pops, cars can't hit you for this long
	ShieldBump = 55, -- how hard the absorbed car shoves you out of its lane
	MegaEggScale = 2.6, -- size of a mega egg
	MegaEggKnockback = 2.2,
	SpecialAmmo = 3, -- eggs loaded by a special egg pickup
	StickySlow = 0.5, -- walk speed multiplier while stuck
	StickyDuration = 3,
	BouncyRange = 60, -- a bouncy egg ricochets towards a chicken this close
	ExplosiveRadius = 10,
	ExplosiveKnockback = 75,
	GoldenSteal = 5, -- golden eggs stolen per golden egg hit
}

-- The chicken with the most knockouts this round wears a crown with a price on its head.
Config.Bounty = {
	MinKOs = 2,
	Base = 20, -- golden eggs for knocking out the leader...
	PerKO = 10, -- ...plus this per knockout they had
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
	-- Game Pass for this season's premium pass track (make a new pass each season).
	SeasonPassId = 0,
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

-- Progression: levels, titles, daily quests and the season pass (ProgressService). -----------
-- These types match src/shared/Progression.luau, which does the maths.
type TitleDef = { id: string, name: string, level: number?, stat: string?, goal: number?, season: boolean? }
type QuestDef = {
	id: string,
	stat: string,
	goal: number,
	text: string,
	coins: number,
	xp: number,
	icon: string,
	best: boolean?,
	enabled: boolean?,
}
type Reward = { coins: number?, item: string?, title: string? }

Config.Progress = {
	-- XP for playing. Every XP point also counts towards the season pass.
	Xp = {
		Round = 20, -- each round played
		Crossing = 10, -- each crossing made in time
		Knockout = 25,
		Win = 60,
		TeamWin = 40,
		SurviveEvery = 30, -- seconds alive per survival bonus
		Survive = 5,
	},
	-- XP from level N to N+1 = Base + Growth * (N - 1), at most Cap.
	Curve = { Base = 100, Growth = 20, Cap = 1500, MaxLevel = 100 },
	-- Golden eggs for reaching a level: Base + PerLevel * level, plus a bonus every Milestone levels.
	LevelUpCoins = { Base = 30, PerLevel = 3, Milestone = 5, MilestoneBonus = 100 },
	-- Titles show above your chicken. Unlocked by level, by a stat, or by the season pass.
	Titles = {
		{ id = "Hatchling", name = "Hatchling", level = 1 },
		{ id = "SpringChicken", name = "Spring Chicken", level = 3 },
		{ id = "RoadRunner", name = "Road Runner", level = 5 },
		{ id = "EggSlinger", name = "Egg Slinger", level = 10 },
		{ id = "TrafficDodger", name = "Traffic Dodger", level = 15 },
		{ id = "SkyGlider", name = "Sky Glider", level = 20 },
		{ id = "RoostRuler", name = "Ruler of the Roost", level = 30 },
		{ id = "RoadLegend", name = "Road Legend", level = 50 },
		{ id = "Eggsterminator", name = "Eggsterminator", stat = "Knockouts", goal = 100 },
		{ id = "Champion", name = "Champion Cluck", stat = "Wins", goal = 50 },
		{ id = "Commuter", name = "Daily Commuter", stat = "Crossings", goal = 250 },
		{ id = "Veteran", name = "Barnyard Veteran", stat = "Rounds", goal = 500 },
		{ id = "RoadTripper", name = "Road Tripper", season = true },
		{ id = "HighwayHero", name = "Highway Hero", season = true },
	} :: { TitleDef },
}

-- Three daily quests per player, new every midnight UTC, with one free reroll a day.
-- Quests finish by themselves and pay out straight away.
Config.Quests = {
	Count = 3,
	FreeRerolls = 1,
	-- stat: the game event that advances it. best = progress is the best single value (a streak).
	Pool = {
		{ id = "Knockouts5", stat = "Knockout", goal = 5, text = "Knock out 5 chickens", coins = 120, xp = 150, icon = "egg" },
		{ id = "Streak3", stat = "CrossStreak", goal = 3, best = true, text = "Survive 3 crossings in a row", coins = 90, xp = 120, icon = "chickenRun" },
		{ id = "Win1", stat = "Win", goal = 1, text = "Win a round", coins = 150, xp = 200, icon = "trophy" },
		{ id = "Play4", stat = "Round", goal = 4, text = "Play 4 rounds", coins = 60, xp = 100, icon = "play" },
		{ id = "Glide20", stat = "Glide", goal = 20, text = "Glide for 20 seconds", coins = 80, xp = 110, icon = "feather" },
		{ id = "Hits15", stat = "EggHit", goal = 15, text = "Hit 15 chickens with eggs", coins = 100, xp = 130, icon = "boom" },
		{ id = "Crossings8", stat = "Crossing", goal = 8, text = "Make 8 crossings", coins = 80, xp = 110, icon = "arrowRight" },
		{ id = "Survive90", stat = "SurviveTime", goal = 90, best = true, text = "Stay alive 90 seconds in one round", coins = 90, xp = 120, icon = "clock" },
		-- Turn on once power-ups call ProgressService.record(player, "PowerUp", 1).
		{ id = "PowerUps3", stat = "PowerUp", goal = 3, text = "Collect 3 power-ups", coins = 80, xp = 100, icon = "lightning" },
	} :: { QuestDef },
}

-- The season pass: tiers of season XP (earned with normal XP while the season runs), a free
-- track and a premium track (Config.Monetization.SeasonPassId). A new Id resets everyone's
-- season progress; claimed cosmetics and titles are kept. Season cosmetics are in Cosmetics
-- with `season = true` (never sold in the shop).
Config.Season = {
	Id = "S1",
	Number = 1,
	Name = "Road Trip",
	EndsAt = 1796083200, -- 2026-12-01 00:00 UTC (Unix time)
	Tiers = 30,
	XpPerTier = 300,
	-- Golden eggs instead of an item you somehow already own.
	DuplicateCoins = 250,
	Free = {
		[2] = { coins = 100 },
		[4] = { coins = 150 },
		[6] = { coins = 150 },
		[8] = { coins = 200 },
		[10] = { item = "ConeEgg" },
		[12] = { coins = 200 },
		[14] = { coins = 250 },
		[16] = { coins = 250 },
		[18] = { coins = 300 },
		[20] = { item = "Honk" },
		[22] = { coins = 300 },
		[24] = { coins = 350 },
		[26] = { coins = 350 },
		[28] = { coins = 400 },
		[30] = { title = "RoadTripper" },
	} :: { [number]: Reward },
	Premium = {
		[1] = { item = "HiVis" },
		[2] = { coins = 200 },
		[3] = { coins = 200 },
		[4] = { coins = 250 },
		[5] = { item = "TireSmoke" },
		[6] = { coins = 250 },
		[7] = { coins = 300 },
		[8] = { coins = 300 },
		[9] = { coins = 300 },
		[10] = { item = "HubcapEgg" },
		[11] = { coins = 350 },
		[12] = { coins = 350 },
		[13] = { coins = 350 },
		[14] = { coins = 400 },
		[15] = { item = "Checkered" },
		[16] = { coins = 400 },
		[17] = { coins = 400 },
		[18] = { coins = 450 },
		[19] = { coins = 450 },
		[20] = { item = "VictoryLap" },
		[21] = { coins = 450 },
		[22] = { coins = 500 },
		[23] = { coins = 500 },
		[24] = { coins = 500 },
		[25] = { item = "Headlights" },
		[26] = { coins = 550 },
		[27] = { coins = 550 },
		[28] = { title = "HighwayHero" },
		[29] = { coins = 600 },
		[30] = { item = "RoadKing" },
	} :: { [number]: Reward },
}

return Config
