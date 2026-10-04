--!strict
-- Run with: luau tests/Progression.spec.luau
local Progression = require("../src/shared/Progression")

local failures = 0
local function check(name: string, ok: boolean)
	if ok then
		print("ok   " .. name)
	else
		failures += 1
		print("FAIL " .. name)
	end
end

local curve: Progression.Curve = { Base = 100, Growth = 20, Cap = 1500, MaxLevel = 100 }

-- Levels ------------------------------------------------------------------------------------
do
	local level, into, need = Progression.levelInfo(0, curve)
	check("new players are level 1", level == 1 and into == 0 and need == 100)
	level, into, need = Progression.levelInfo(99, curve)
	check("99 xp is still level 1", level == 1 and into == 99 and need == 100)
	level, into, need = Progression.levelInfo(100, curve)
	check("100 xp is level 2", level == 2 and into == 0 and need == 120)
	check("level 3 needs 100 + 120", Progression.level(220, curve) == 3 and Progression.level(219, curve) == 2)

	local increasing = true
	for l = 2, curve.MaxLevel - 1 do
		if Progression.xpToNext(l, curve) < Progression.xpToNext(l - 1, curve) then
			increasing = false
		end
	end
	check("each level needs at least as much as the last", increasing)
	check("the curve is capped", Progression.xpToNext(99, curve) == curve.Cap)

	local roundTrip = true
	for l = 1, curve.MaxLevel do
		local total = Progression.totalXpFor(l, curve)
		if Progression.level(total, curve) ~= l or (l > 1 and Progression.level(total - 1, curve) ~= l - 1) then
			roundTrip = false
		end
	end
	check("totalXpFor matches levelInfo at every level", roundTrip)

	level, into, need = Progression.levelInfo(1e12, curve)
	check("huge xp stops at the max level", level == curve.MaxLevel and into == 0 and need == 0)
	check("bad xp counts as none", Progression.level(0 / 0, curve) == 1 and Progression.level(-50, curve) == 1)

	local coins = { Base = 30, PerLevel = 3, Milestone = 5, MilestoneBonus = 100 }
	check("level-up coins grow", Progression.levelUpCoins(3, coins) == 39)
	check("milestone levels pay a bonus", Progression.levelUpCoins(5, coins) == 145)
end

-- Titles ------------------------------------------------------------------------------------
do
	local stats = { Wins = 3, Knockouts = 100 }
	local byLevel: Progression.TitleDef = { id = "RoadRunner", name = "Road Runner", level = 5 }
	local byStat: Progression.TitleDef = { id = "Eggsterminator", name = "Eggsterminator", stat = "Knockouts", goal = 100 }
	local byWins: Progression.TitleDef = { id = "Champion", name = "Champion", stat = "Wins", goal = 50 }
	local bySeason: Progression.TitleDef = { id = "HighwayHero", name = "Highway Hero", season = true }
	check("level titles unlock at their level", Progression.titleUnlocked(byLevel, 5, stats, {}) and not Progression.titleUnlocked(byLevel, 4, stats, {}))
	check("stat titles unlock at their goal", Progression.titleUnlocked(byStat, 1, stats, {}) and not Progression.titleUnlocked(byWins, 99, stats, {}))
	check("season titles need granting", not Progression.titleUnlocked(bySeason, 99, stats, {}) and Progression.titleUnlocked(bySeason, 1, stats, { HighwayHero = true }))
	check("requirement text", Progression.titleRequirement(byLevel) == "Reach level 5" and Progression.titleRequirement(byStat) == "100 knockouts")
end

-- Daily quests --------------------------------------------------------------------------------
local pool: { Progression.QuestDef } = {
	{ id = "A", stat = "Knockout", goal = 5, text = "", coins = 10, xp = 10, icon = "egg" },
	{ id = "B", stat = "Win", goal = 1, text = "", coins = 10, xp = 10, icon = "trophy" },
	{ id = "C", stat = "Round", goal = 4, text = "", coins = 10, xp = 10, icon = "play" },
	{ id = "D", stat = "CrossStreak", goal = 3, text = "", coins = 10, xp = 10, icon = "chickenRun", best = true },
	{ id = "E", stat = "Glide", goal = 30, text = "", coins = 10, xp = 10, icon = "feather" },
	{ id = "Off", stat = "PowerUp", goal = 3, text = "", coins = 10, xp = 10, icon = "lightning", enabled = false },
}

do
	check("day boundaries are UTC midnight", Progression.day(86399) == 0 and Progression.day(86400) == 1)
	check("seconds to reset", Progression.secondsToReset(86400 * 5 + 3600) == 86400 - 3600)

	local a = Progression.rollQuests(pool, 3, 12345)
	local b = Progression.rollQuests(pool, 3, 12345)
	check("rolls are deterministic", table.concat(a, ",") == table.concat(b, ","))
	check("rolls pick the right count", #a == 3)

	local distinct, neverDisabled = true, true
	for seed = 1, 300 do
		local picked = Progression.rollQuests(pool, 3, Progression.questSeed(seed * 977, 20000 + seed, 0))
		local seen = {}
		for _, id in picked do
			if seen[id] then
				distinct = false
			end
			seen[id] = true
			if id == "Off" then
				neverDisabled = false
			end
		end
	end
	check("rolls never repeat a quest", distinct)
	check("disabled quests are never rolled", neverDisabled)
	check("a small pool gives what it has", #Progression.rollQuests(pool, 10, 7) == 5)

	local spread: { [string]: number } = {}
	for userId = 1, 500 do
		for _, id in Progression.rollQuests(pool, 3, Progression.questSeed(userId, 20500, 0)) do
			spread[id] = (spread[id] or 0) + 1
		end
	end
	local fair = true
	for _, id in { "A", "B", "C", "D", "E" } do
		-- 1500 picks over 5 quests: about 300 each.
		if (spread[id] or 0) < 200 or (spread[id] or 0) > 400 then
			fair = false
		end
	end
	check("rolls spread evenly over the pool", fair)

	local current = { "A", "B", "C" }
	local swapped = Progression.rerollQuest(pool, current, 99)
	check("a reroll picks a quest you don't have", swapped == "D" or swapped == "E")
	check("no reroll when nothing is left", Progression.rerollQuest(pool, { "A", "B", "C", "D", "E" }, 5) == nil)
end

do
	local state = Progression.newQuests(pool, 3, 100, 42)
	check("new quests start at zero", #state.List == 3 and state.List[1].Progress == 0 and not state.List[1].Done and state.Day == 100)

	local same, changed = Progression.refreshQuests(state, pool, 3, 100, 42)
	check("the same day keeps the quests", same == state and not changed)
	state.List[1].Progress = 2
	local nextDay, changed2 = Progression.refreshQuests(state, pool, 3, 101, 42)
	check("a new day rolls fresh quests", changed2 and nextDay.Day == 101 and nextDay.List[1].Progress == 0 and nextDay.Rerolls == 0)

	local broken: any = {
		Day = 100,
		Rerolls = "x",
		List = {
			{ Id = "A", Progress = 0 / 0, Done = false },
			{ Id = "Gone", Progress = 1, Done = false },
			{ Id = "A", Progress = 1, Done = false },
			{ Id = "Off", Progress = 0, Done = false },
			{ Id = "C", Progress = 99, Done = false },
		},
	}
	local fixed, changed3 = Progression.refreshQuests(broken, pool, 3, 100, 42)
	local ids = {}
	for _, q in fixed.List do
		table.insert(ids, q.Id)
	end
	check("broken saves are repaired", changed3 and #fixed.List == 3 and fixed.Rerolls == 0)
	check("repair keeps valid quests and fixes numbers", ids[1] == "A" and fixed.List[1].Progress == 0 and ids[2] == "C" and fixed.List[2].Progress == 4)
	check("repair fills with a new, different quest", ids[3] ~= "A" and ids[3] ~= "C" and ids[3] ~= "Off" and Progression.findQuest(pool, ids[3]) ~= nil)
	local fresh = Progression.refreshQuests(nil :: any, pool, 3, 7, 1)
	check("missing quest data rolls new quests", #fresh.List == 3 and fresh.Day == 7)
end

do
	local total = { Id = "A", Progress = 0, Done = false }
	local def = pool[1]
	local ch, done = Progression.advance(total, def, 2)
	check("totals add up", ch and not done and total.Progress == 2)
	ch, done = Progression.advance(total, def, 10)
	check("finishing clamps to the goal", ch and done and total.Progress == 5 and total.Done)
	ch, done = Progression.advance(total, def, 1)
	check("finished quests don't move", not ch and not done)

	local streak = { Id = "D", Progress = 0, Done = false }
	local sdef = pool[4]
	Progression.advance(streak, sdef, 2)
	Progression.advance(streak, sdef, 1)
	check("best-of quests keep the best value", streak.Progress == 2 and not streak.Done)
	ch, done = Progression.advance(streak, sdef, 3)
	check("best-of quests finish at the goal", ch and done)
	check("zero or negative amounts do nothing", not (Progression.advance({ Id = "A", Progress = 0, Done = false }, def, -3)))
end

-- Season pass ---------------------------------------------------------------------------------
local season: Progression.SeasonConfig = {
	Id = "S1",
	Tiers = 30,
	XpPerTier = 300,
	Free = { [2] = { coins = 100 }, [10] = { item = "ConeEgg" } },
	Premium = { [1] = { item = "HiVis" }, [2] = { coins = 200 }, [30] = { title = "HighwayHero" } },
}

do
	local tier, into, need = Progression.tierInfo(0, 300, 30)
	check("no tiers at first", tier == 0 and into == 0 and need == 300)
	tier, into, need = Progression.tierInfo(650, 300, 30)
	check("tiers every 300 xp", tier == 2 and into == 50 and need == 300)
	tier, into, need = Progression.tierInfo(1e9, 300, 30)
	check("the last tier caps", tier == 30 and into == 0 and need == 0)

	local state: Progression.SeasonState = { Id = "S1", Xp = 650, Claimed = {}, Premium = false }
	local reward, key = Progression.checkClaim(state, season, "free", 2)
	check("a reached free tier can be claimed", reward ~= nil and reward.coins == 100 and key == "F2")
	state.Claimed[key] = true
	check("a claimed tier can't be claimed again", select(2, Progression.checkClaim(state, season, "free", 2)) == "claimed")
	check("unreached tiers are locked", select(2, Progression.checkClaim(state, season, "free", 10)) == "locked")
	check("empty tiers have nothing", select(2, Progression.checkClaim(state, season, "free", 1)) == "reward")
	check("premium needs the pass", select(2, Progression.checkClaim(state, season, "premium", 1)) == "premium")
	state.Premium = true
	check("premium works with the pass", (Progression.checkClaim(state, season, "premium", 1)) ~= nil)
	local bad = true
	for _, args in { { "free", 2.5 }, { "free", 0 }, { "free", 31 }, { "gold", 1 }, { 1, 1 }, { "free", "2" }, { "free", 0 / 0 }, { "free", math.huge } } do
		if (Progression.checkClaim(state, season, args[1], args[2])) ~= nil then
			bad = false
		end
	end
	check("bad claim requests are refused", bad)
	check("old seasons can't claim", select(2, Progression.checkClaim({ Id = "S0", Xp = 1e6, Claimed = {}, Premium = true }, season, "free", 2)) == "season")
	check("unclaimed counts free and premium", Progression.unclaimed(state, season) == 2)

	local fresh, reset = Progression.seasonFor(state, "S2")
	check("a new season resets progress", reset and fresh.Id == "S2" and fresh.Xp == 0 and next(fresh.Claimed) == nil and not fresh.Premium)
	local kept, changed = Progression.seasonFor(state, "S1")
	check("the same season keeps progress", kept == state and not changed and kept.Xp == 650)
end

-- Formatting ----------------------------------------------------------------------------------
check("duration days", Progression.formatDuration(86400 * 3 + 3600 * 4 + 5) == "3d 4h")
check("duration hours", Progression.formatDuration(3600 * 5 + 60 * 12) == "5h 12m")
check("duration minutes", Progression.formatDuration(125) == "2m")
check("duration seconds", Progression.formatDuration(45) == "45s" and Progression.formatDuration(-5) == "0s")

if failures > 0 then
	error(`{failures} test(s) failed`)
end
print("all passed")
