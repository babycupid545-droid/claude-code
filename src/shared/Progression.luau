--!strict
-- Pure progression maths shared by the server and the client: the level curve, titles, daily
-- quest rolls and resets, and season pass tiers and claims.
--
-- No Roblox APIs in here, so it runs in plain Luau (tests/Progression.spec.luau). The numbers
-- live in Config.Progress / Config.Quests / Config.Season and are passed in.

export type Curve = { Base: number, Growth: number, Cap: number, MaxLevel: number }
export type LevelCoins = { Base: number, PerLevel: number, Milestone: number, MilestoneBonus: number }

export type TitleDef = {
	id: string,
	name: string,
	level: number?, -- unlocked at this level
	stat: string?, -- ...or when this stat (Stats.<stat>) reaches `goal`
	goal: number?,
	season: boolean?, -- ...or granted by a season pass reward
}

export type QuestDef = {
	id: string,
	stat: string, -- the event that advances it (see ProgressService.record)
	goal: number,
	text: string,
	coins: number,
	xp: number,
	icon: string, -- UI sprite
	best: boolean?, -- progress is the best single value (e.g. a streak), not a running total
	enabled: boolean?, -- false keeps it out of the rolls
}

export type Quest = { Id: string, Progress: number, Done: boolean }
export type QuestState = { Day: number, List: { Quest }, Rerolls: number }

export type Reward = { coins: number?, item: string?, title: string? }
export type SeasonConfig = {
	Id: string,
	Tiers: number,
	XpPerTier: number,
	Free: { [number]: Reward },
	Premium: { [number]: Reward },
}
export type SeasonState = { Id: string, Xp: number, Claimed: { [string]: boolean }, Premium: boolean }

local DAY = 86400

local Progression = {}

local function isWhole(n: unknown): boolean
	return type(n) == "number" and n == n and n == math.floor(n) and n > -math.huge and n < math.huge
end

-- Levels --------------------------------------------------------------------------------------

-- XP needed to go from `level` to `level + 1`.
function Progression.xpToNext(level: number, curve: Curve): number
	return math.min(curve.Cap, curve.Base + curve.Growth * (level - 1))
end

-- The level for a lifetime XP total, the XP earned into that level and the XP the next level
-- needs (0 at the max level).
function Progression.levelInfo(xp: number, curve: Curve): (number, number, number)
	local rest = if xp == xp then math.max(0, math.floor(xp)) else 0
	local level = 1
	while level < curve.MaxLevel do
		local need = Progression.xpToNext(level, curve)
		if rest < need then
			return level, rest, need
		end
		rest -= need
		level += 1
	end
	return curve.MaxLevel, 0, 0
end

function Progression.level(xp: number, curve: Curve): number
	return (Progression.levelInfo(xp, curve))
end

-- Total XP it takes to reach `level` from nothing.
function Progression.totalXpFor(level: number, curve: Curve): number
	local total = 0
	for l = 1, math.min(level, curve.MaxLevel) - 1 do
		total += Progression.xpToNext(l, curve)
	end
	return total
end

-- Golden eggs for reaching `level`.
function Progression.levelUpCoins(level: number, coins: LevelCoins): number
	local amount = coins.Base + coins.PerLevel * level
	if coins.Milestone > 0 and level % coins.Milestone == 0 then
		amount += coins.MilestoneBonus
	end
	return amount
end

-- Titles --------------------------------------------------------------------------------------

function Progression.titleUnlocked(def: TitleDef, level: number, stats: { [string]: number }, granted: { [string]: boolean }): boolean
	if def.season then
		return granted[def.id] == true
	end
	if def.stat then
		return (stats[def.stat] or 0) >= (def.goal or 0)
	end
	return level >= (def.level or 1)
end

local STAT_WORDS: { [string]: string } = {
	Wins = "wins",
	Knockouts = "knockouts",
	Crossings = "crossings",
	Rounds = "rounds played",
}

-- What unlocks a title, for the UI ("Reach level 5", "100 knockouts").
function Progression.titleRequirement(def: TitleDef): string
	if def.season then
		return "Season pass reward"
	elseif def.stat then
		return `{def.goal or 0} {STAT_WORDS[def.stat] or string.lower(def.stat)}`
	end
	return `Reach level {def.level or 1}`
end

-- Daily quests --------------------------------------------------------------------------------

-- Quests reset at midnight UTC: the day number of a Unix time, and the seconds left in it.
function Progression.day(t: number): number
	return t // DAY
end

function Progression.secondsToReset(t: number): number
	return DAY - t % DAY
end

-- A seed for a player's quest rolls on a day (salt: 0 for the daily roll, n for the nth reroll).
function Progression.questSeed(userId: number, day: number, salt: number): number
	return (math.abs(userId) % 1000003 * 7919 + day * 104729 + salt * 15485863) % 2147483646 + 1
end

-- A tiny deterministic RNG (Lehmer), returning integers in [1, n].
local function makeRng(seed: number): (number) -> number
	local state = math.floor(math.abs(seed)) % 2147483647
	if state == 0 then
		state = 1
	end
	return function(n: number): number
		state = (state * 48271) % 2147483647
		return state % n + 1
	end
end

local function questOptions(pool: { QuestDef }, exclude: { string }): { string }
	local options = {}
	for _, def in pool do
		if def.enabled ~= false and not table.find(exclude, def.id) and not table.find(options, def.id) then
			table.insert(options, def.id)
		end
	end
	return options
end

function Progression.findQuest(pool: { QuestDef }, id: string): QuestDef?
	for _, def in pool do
		if def.id == id then
			return def
		end
	end
	return nil
end

-- Picks `count` different enabled quests (fewer if the pool is smaller).
function Progression.rollQuests(pool: { QuestDef }, count: number, seed: number, exclude: { string }?): { string }
	local options = questOptions(pool, exclude or {})
	local rng = makeRng(seed)
	local picked = {}
	while #picked < count and #options > 0 do
		table.insert(picked, table.remove(options, rng(#options)) :: string)
	end
	return picked
end

-- A quest to swap in that isn't one of `current`, or nil if there's none left.
function Progression.rerollQuest(pool: { QuestDef }, current: { string }, seed: number): string?
	return Progression.rollQuests(pool, 1, seed, current)[1]
end

function Progression.newQuests(pool: { QuestDef }, count: number, day: number, userId: number): QuestState
	local list = {}
	for _, id in Progression.rollQuests(pool, count, Progression.questSeed(userId, day, 0)) do
		table.insert(list, { Id = id, Progress = 0, Done = false })
	end
	return { Day = day, List = list, Rerolls = 0 }
end

-- Makes saved quests valid for `day`: a new day rolls fresh ones; otherwise removed/disabled
-- or duplicate quests are replaced, bad numbers fixed and missing slots filled.
-- Returns the (possibly new) state and whether anything changed.
function Progression.refreshQuests(state: QuestState, pool: { QuestDef }, count: number, day: number, userId: number): (QuestState, boolean)
	if type(state) ~= "table" or state.Day ~= day or type(state.List) ~= "table" then
		return Progression.newQuests(pool, count, day, userId), true
	end
	local changed = false
	if not isWhole(state.Rerolls) or state.Rerolls < 0 then
		state.Rerolls = 0
		changed = true
	end
	local kept: { Quest } = {}
	local ids: { string } = {}
	for _, q in state.List do
		local def = if type(q) == "table" and type(q.Id) == "string" then Progression.findQuest(pool, q.Id) else nil
		if def and def.enabled ~= false and not table.find(ids, q.Id) and #kept < count then
			if type(q.Progress) ~= "number" or q.Progress ~= q.Progress or q.Progress < 0 then
				q.Progress = 0
				changed = true
			end
			if q.Progress > def.goal then
				q.Progress = def.goal
				changed = true
			end
			if type(q.Done) ~= "boolean" then
				q.Done = q.Progress >= def.goal
				changed = true
			end
			table.insert(kept, q)
			table.insert(ids, q.Id)
		else
			changed = true
		end
	end
	if #kept < count then
		for _, id in Progression.rollQuests(pool, count - #kept, Progression.questSeed(userId, day, 1000 + #kept), ids) do
			table.insert(kept, { Id = id, Progress = 0, Done = false })
			changed = true
		end
	end
	state.List = kept
	return state, changed
end

-- Adds an event to a quest. Returns whether its progress changed and whether it just finished.
function Progression.advance(quest: Quest, def: QuestDef, amount: number): (boolean, boolean)
	if quest.Done or amount <= 0 then
		return false, false
	end
	local before = quest.Progress
	local value = if def.best then math.max(before, amount) else before + amount
	quest.Progress = math.min(value, def.goal)
	if quest.Progress >= def.goal then
		quest.Done = true
		return true, true
	end
	return quest.Progress ~= before, false
end

-- Season pass ---------------------------------------------------------------------------------

-- The tier reached with `xp` (0 = none yet), the XP into the next tier and what it needs
-- (0 once every tier is reached).
function Progression.tierInfo(xp: number, perTier: number, tiers: number): (number, number, number)
	local whole = if xp == xp then math.max(0, math.floor(xp)) else 0
	local tier = math.min(tiers, whole // perTier)
	if tier >= tiers then
		return tiers, 0, 0
	end
	return tier, whole - tier * perTier, perTier
end

function Progression.claimKey(track: "free" | "premium", tier: number): string
	return (if track == "premium" then "P" else "F") .. tostring(tier)
end

-- A fresh season state when the season changed (claimed cosmetics stay owned elsewhere).
function Progression.seasonFor(state: SeasonState?, seasonId: string): (SeasonState, boolean)
	if type(state) == "table" and state.Id == seasonId then
		local changed = false
		if type(state.Xp) ~= "number" or state.Xp ~= state.Xp or state.Xp < 0 then
			state.Xp = 0
			changed = true
		end
		if type(state.Claimed) ~= "table" then
			state.Claimed = {}
			changed = true
		end
		if type(state.Premium) ~= "boolean" then
			state.Premium = false
			changed = true
		end
		return state, changed
	end
	return { Id = seasonId, Xp = 0, Claimed = {}, Premium = false }, true
end

-- Checks a claim request from a client. `track` and `tier` are untrusted.
-- Returns the reward and its claim key, or nil and the reason.
function Progression.checkClaim(state: SeasonState, season: SeasonConfig, track: unknown, tier: unknown): (Reward?, string)
	if state.Id ~= season.Id then
		return nil, "season"
	end
	if track ~= "free" and track ~= "premium" then
		return nil, "track"
	end
	if not isWhole(tier) then
		return nil, "tier"
	end
	local t = tier :: number
	if t < 1 or t > season.Tiers then
		return nil, "tier"
	end
	local reward = if track == "premium" then season.Premium[t] else season.Free[t]
	if not reward then
		return nil, "reward"
	end
	local reached = Progression.tierInfo(state.Xp, season.XpPerTier, season.Tiers)
	if t > reached then
		return nil, "locked"
	end
	if track == "premium" and not state.Premium then
		return nil, "premium"
	end
	local key = Progression.claimKey(track, t)
	if state.Claimed[key] then
		return nil, "claimed"
	end
	return reward, key
end

-- How many rewards are waiting to be claimed (for a badge on the HUD button).
function Progression.unclaimed(state: SeasonState, season: SeasonConfig): number
	if state.Id ~= season.Id then
		return 0
	end
	local reached = Progression.tierInfo(state.Xp, season.XpPerTier, season.Tiers)
	local count = 0
	for t = 1, reached do
		if season.Free[t] and not state.Claimed[Progression.claimKey("free", t)] then
			count += 1
		end
		if state.Premium and season.Premium[t] and not state.Claimed[Progression.claimKey("premium", t)] then
			count += 1
		end
	end
	return count
end

-- Formatting ----------------------------------------------------------------------------------

-- "3d 4h", "5h 12m", "12m", "45s".
function Progression.formatDuration(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	local d, h, m = s // DAY, (s % DAY) // 3600, (s % 3600) // 60
	if d > 0 then
		return `{d}d {h}h`
	elseif h > 0 then
		return `{h}h {m}m`
	elseif m > 0 then
		return `{m}m`
	end
	return `{s}s`
end

return Progression
