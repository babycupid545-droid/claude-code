--!strict
-- The game loop: Waiting -> Voting -> Starting -> InRound -> Results -> Voting ...
-- Eliminated chickens respawn in the lobby (or become drivers in Road Rage).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Layout = require(Shared.Layout)
local Modes = require(Shared.Modes)
local Remotes = require(Shared.Remotes)
local RoundState = require(Shared.RoundState)
local TrafficSchedule = require(Shared.TrafficSchedule)

local Services = script.Parent
local BountyService = require(Services.BountyService)
local ChickenService = require(Services.ChickenService)
local DataService = require(Services.DataService)
local EggService = require(Services.EggService)
local EventService = require(Services.EventService)
local HazardService = require(Services.HazardService)
local MapBuilder = require(Services.MapBuilder)
local PowerupService = require(Services.PowerupService)
local ProgressService = require(Services.ProgressService)
local SidewalkService = require(Services.SidewalkService)
local TrafficService = require(Services.TrafficService)

local RoundService = {}

type Side = SidewalkService.Side

type Round = {
	mode: Modes.Mode,
	participants: { Player },
	alive: { [Player]: boolean },
	team: { [Player]: Side },
	-- The character each chicken started the round with.
	characters: { [Player]: Model },
	connections: { RBXScriptConnection },
	lastRageLaunch: { [Player]: number },
	-- Who last egged each chicken, for knockout credit.
	lastEgged: { [Player]: { shooter: Player, at: number } },
	-- Server time the round went live (after the countdown).
	startedAt: number?,
	ended: boolean,
}

local rng = Random.new()
local arena: Model
local round: Round? = nil
local votes: { [Player]: string } = {}
local voteOptions: { string } = {}

local teamObjects: { [Side]: Team } = {}
local lastAfkChange: { [Player]: number } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

-- AFK players sit in the lobby: they don't vote, count towards starting, or join rounds.
local function isAfk(player: Player): boolean
	return player:GetAttribute("Afk") == true
end

local function activePlayers(): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		if not isAfk(player) then
			table.insert(list, player)
		end
	end
	return list
end

local function setState(state: string, duration: number?, message: string?)
	RoundState:SetAttribute("State", state)
	RoundState:SetAttribute("EndsAt", if duration then now() + duration else 0)
	RoundState:SetAttribute("Message", message or "")
end

-- Kill-feed line; `icon` is a sprite name from the UI sheet.
local function feed(text: string, icon: string?)
	Remotes.Feed:FireAllClients(text, icon or "info")
end

local function aliveList(r: Round): { Player }
	local list = {}
	for player, isAlive in r.alive do
		if isAlive and player.Parent then
			table.insert(list, player)
		end
	end
	return list
end

-- Voting ------------------------------------------------------------------------------

local function publishVotes()
	local counts: { [string]: number } = {}
	for _, id in voteOptions do
		counts[id] = 0
	end
	for _, id in votes do
		counts[id] = (counts[id] or 0) + 1
	end
	RoundState:SetAttribute("Votes", HttpService:JSONEncode(counts))
end

local function onVote(player: Player, modeId: unknown)
	if RoundState:GetAttribute("State") ~= "Voting" or type(modeId) ~= "string" or isAfk(player) then
		return
	end
	if not table.find(voteOptions, modeId) then
		return
	end
	votes[player] = modeId
	publishVotes()
end

local function runVote(): Modes.Mode
	local playerCount = #activePlayers()
	local eligible = {}
	for _, mode in Modes.list do
		if playerCount >= mode.minPlayers then
			table.insert(eligible, mode.id)
		end
	end
	-- Offer up to three random modes.
	voteOptions = {}
	while #eligible > 0 and #voteOptions < 3 do
		table.insert(voteOptions, table.remove(eligible, rng:NextInteger(1, #eligible)) :: string)
	end
	table.clear(votes)
	RoundState:SetAttribute("VoteOptions", HttpService:JSONEncode(voteOptions))
	publishVotes()
	setState("Voting", Config.Timing.VoteDuration, "Vote for the next mode!")
	task.wait(Config.Timing.VoteDuration)

	local counts: { [string]: number } = {}
	for _, id in votes do
		counts[id] = (counts[id] or 0) + 1
	end
	local best, bestCount = {}, -1
	for _, id in voteOptions do
		local c = counts[id] or 0
		if c > bestCount then
			best, bestCount = { id }, c
		elseif c == bestCount then
			table.insert(best, id)
		end
	end
	local chosen = if #best > 0 then Modes.get(best[rng:NextInteger(1, #best)]) else nil
	RoundState:SetAttribute("VoteOptions", "[]")
	-- Someone may have left during the vote; don't start a mode there are too few players for.
	if not chosen or #activePlayers() < chosen.minPlayers then
		return Modes.list[1]
	end
	return chosen
end

-- Elimination ---------------------------------------------------------------------------

local function checkWinner(r: Round): (boolean, { Player }, string?)
	local alive = aliveList(r)
	if r.mode.teams then
		local teamsAlive: { [Side]: boolean } = {}
		local count = 0
		for _, player in alive do
			local side = r.team[player]
			if side and not teamsAlive[side] then
				teamsAlive[side] = true
				count += 1
			end
		end
		-- A lone tester (or everyone dying at once) ends when nobody is left.
		if count == 0 or (count == 1 and #r.participants >= 2) then
			local side: Side? = if teamsAlive.A then "A" elseif teamsAlive.B then "B" else nil
			if side then
				local winners = {}
				for _, player in r.participants do
					if r.team[player] == side and player.Parent then
						table.insert(winners, player)
					end
				end
				return true, winners, `{teamObjects[side].Name} win!`
			end
			return true, {}, "Nobody made it!"
		end
		return false, {}, nil
	end

	-- Solo-style: last chicken standing. Testing alone in Studio ends when you die.
	local needed = if #r.participants >= 2 then 1 else 0
	if #alive <= needed then
		if #alive == 1 and #r.participants >= 2 then
			return true, alive, `{alive[1].DisplayName} crossed the road!`
		end
		return true, {}, "Nobody made it!"
	end
	return false, {}, nil
end

local function survivalReward(r: Round, player: Player)
	local startedAt = r.startedAt
	if not startedAt or not player.Parent then
		return
	end
	local R = Config.Rewards
	local coins = math.floor((now() - startedAt) / R.SurviveEvery) * R.SurviveCoins
	DataService.reward(player, coins, "for surviving")
	ProgressService.survived(player, now() - startedAt)
end

local function eliminate(r: Round, player: Player, reason: string, icon: string)
	if not r.alive[player] then
		return
	end
	r.alive[player] = false
	player:SetAttribute("Alive", false)

	-- Credit the last chicken that egged this one (the kill counts however it died).
	local egged = r.lastEgged[player]
	local shooter = egged and egged.shooter
	local window = Config.Rewards.KnockoutWindow
	local killer: Player? = nil
	if egged and shooter and shooter ~= player and shooter.Parent and (window <= 0 or os.clock() - egged.at <= window) then
		killer = shooter
		feed(`{shooter.DisplayName} egged {player.DisplayName} to their doom!`, "egg")
		Remotes.Notify:FireClient(shooter, `KNOCKOUT! {player.DisplayName}`, "knockout", 0)
		DataService.addStat(shooter, "Knockouts", 1)
		DataService.reward(shooter, Config.Rewards.Knockout, "for the knockout")
		ProgressService.knockout(shooter)
		local kos = shooter:GetAttribute("RoundKOs")
		shooter:SetAttribute("RoundKOs", (if type(kos) == "number" then kos else 0) + 1)
	else
		feed(`{player.DisplayName} {reason}`, icon)
	end
	PowerupService.clearPlayer(player)
	BountyService.onEliminated(player, killer)
	survivalReward(r, player)
	if r.mode.roadRage and player.Parent and not isAfk(player) then
		player:SetAttribute("Driver", true)
		Remotes.Feed:FireClient(player, "You're a driver now. Run them over!", "angry")
	end
end

-- Road Rage -----------------------------------------------------------------------------

local function onLaunchRageCar(player: Player, lane: unknown)
	local r = round
	if not r or not r.mode.roadRage or RoundState:GetAttribute("State") ~= "InRound" then
		return
	end
	if player:GetAttribute("Driver") ~= true then
		return
	end
	if type(lane) ~= "number" then
		return
	end
	if lane ~= math.floor(lane) or lane < 1 or lane > #Layout.lanes then
		return
	end
	local t = os.clock()
	-- A little slack for network jitter, so a launch the client shows as ready isn't dropped.
	if t - (r.lastRageLaunch[player] or 0) < Config.RoadRage.Cooldown * 0.9 then
		return
	end
	r.lastRageLaunch[player] = t
	TrafficService.launchRageCar(player, lane)
end

-- AFK -----------------------------------------------------------------------------------------

-- Takes effect from the next round: a chicken already in a round keeps playing (going AFK
-- never kills it). An eliminated Road Rage driver just stops driving.
local function onSetAfk(player: Player, afk: unknown)
	if type(afk) ~= "boolean" then
		return
	end
	local t = os.clock()
	if t - (lastAfkChange[player] or 0) < 0.5 then
		return
	end
	lastAfkChange[player] = t
	player:SetAttribute("Afk", afk)
	if afk then
		if votes[player] then
			votes[player] = nil
			publishVotes()
		end
		local r = round
		if r and not r.alive[player] and player:GetAttribute("Driver") == true then
			player:SetAttribute("Driver", false)
		end
	end
end

-- Crossing ---------------------------------------------------------------------------------

-- Everyone starts on side A. They must reach the other side before the one they left
-- crumbles; it rises again a few seconds later and they must cross back. Each phase is shorter.
-- True once every chicken still in the round is standing on `target`.
local function allAcross(r: Round, target: Side): boolean
	local any = false
	for player, alive in r.alive do
		if alive then
			local root = ChickenService.getRoot(player)
			if not root or Layout.zoneOf(root.Position.Z) ~= target then
				return false
			end
			any = true
		end
	end
	return any
end

local function runCrossing(r: Round, roundStart: number)
	local S = Config.Shuttle
	local leaving: Side = "A"
	local phase = S.FirstPhase
	local deadline = roundStart + phase
	while not r.ended do
		local target: Side = if leaving == "A" then "B" else "A"
		local phaseStart = now()
		RoundState:SetAttribute("CrossTarget", target)
		RoundState:SetAttribute("CrossDeadline", deadline)
		feed(`Run to the {Layout.sideName(target)} side!`, "arrowRight")

		-- Wait for the deadline, but move straight on once every chicken has made it across.
		local warned = false
		local early = false
		while now() < deadline do
			if r.ended then
				return
			end
			if now() - phaseStart >= S.EarlyAfter and allAcross(r, target) then
				early = true
				break
			end
			if not warned and now() >= deadline - S.Warning then
				warned = true
				SidewalkService.warnSide(leaving)
			end
			task.wait(0.2)
		end
		if r.ended then
			return
		end
		if early then
			feed(`Everyone made it! Back to the {Layout.sideName(leaving)} side!`, "check")
		end
		ProgressService.crossingDone(aliveList(r), target)
		SidewalkService.dropSide(leaving)

		-- The next deadline counts from this drop.
		phase = math.max(S.MinPhase, phase - S.PhaseStep)
		deadline = now() + phase
		task.wait(S.RiseDelay)
		if r.ended then
			return
		end
		SidewalkService.raiseSide(leaving)
		leaving = target
	end
end

-- Round ---------------------------------------------------------------------------------

local function playersWithCharacters(): { Player }
	local list = {}
	for _, player in activePlayers() do
		local humanoid = ChickenService.getHumanoid(player)
		if humanoid and humanoid.Health > 0 and ChickenService.getRoot(player) then
			table.insert(list, player)
		end
	end
	return list
end

-- Stops everything a round started. Also used when a round errors, so it must be safe to call
-- twice and with no round at all.
local function stopRound(r: Round?)
	if r then
		r.ended = true
		for _, c in r.connections do
			c:Disconnect()
		end
		table.clear(r.connections)
	end
	RoundState:SetAttribute("SuddenDeath", false)
	RoundState:SetAttribute("CrossTarget", "")
	RoundState:SetAttribute("CrossDeadline", 0)
	HazardService.stop()
	EventService.stop()
	PowerupService.stop()
	BountyService.stop()
	SidewalkService.reset(arena)
	TrafficService.stop()
	EggService.setRules({
		canShoot = function()
			return false
		end,
		canHit = function()
			return false
		end,
	})
end

local function runRound(mode: Modes.Mode): ({ Player }, string)
	SidewalkService.reset(arena)
	EggService.clear()
	RoundState:SetAttribute("SuddenDeath", false)

	local r: Round = {
		mode = mode,
		participants = playersWithCharacters(),
		alive = {},
		team = {},
		characters = {},
		connections = {},
		lastRageLaunch = {},
		lastEgged = {},
		ended = false,
	}
	round = r
	RoundState:SetAttribute("ModeId", mode.id)
	RoundState:SetAttribute("RoundPlayers", #r.participants)
	for _, player in Players:GetPlayers() do
		player:SetAttribute("RoundKOs", 0)
	end

	-- Teams: shuffle then deal players onto the two sides.
	local shuffled = table.clone(r.participants)
	for i = #shuffled, 2, -1 do
		local j = rng:NextInteger(1, i)
		shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
	end
	for i, player in shuffled do
		-- Everyone starts on side A (in Teams, Blue starts across the road on B).
		local side: Side = if mode.teams and i % 2 == 0 then "B" else "A"
		r.team[player] = side
		if mode.teams then
			player.Team = teamObjects[side]
			player:SetAttribute("Team", side)
		end
		r.alive[player] = true
		player:SetAttribute("Alive", true)
		player:SetAttribute("Driver", false)

		local character = player.Character
		local humanoid = ChickenService.getHumanoid(player)
		if character and humanoid then
			r.characters[player] = character
			character:PivotTo(SidewalkService.spawnCFrame(side, rng))
			table.insert(
				r.connections,
				humanoid.Died:Connect(function()
					if r.alive[player] then
						eliminate(r, player, "became a pancake", "skull")
					end
				end)
			)
		end
	end

	table.insert(
		r.connections,
		Players.PlayerRemoving:Connect(function(player)
			if r.alive[player] then
				eliminate(r, player, "flew the coop", "feather")
			end
		end)
	)

	EggService.setRules({
		canShoot = function(player)
			return r.alive[player] == true and RoundState:GetAttribute("State") == "InRound"
		end,
		canHit = function(shooter, target)
			if not r.alive[target] then
				return false
			end
			return not mode.teams or r.team[shooter] ~= r.team[target]
		end,
		onHit = function(shooter, target)
			r.lastEgged[target] = { shooter = shooter, at = os.clock() }
			ProgressService.eggHit(shooter)
		end,
	})

	-- Traffic starts with the countdown so the road is already busy when the round begins.
	-- Its start time is rounded down, so measure the event offsets from the moment the round
	-- actually goes live; otherwise speed-ups would land up to a second before their banners.
	local trafficStart = math.floor(now())
	local countdown = Config.Timing.CountdownDuration
	local liveAt = now() + countdown
	local liveOffset = liveAt - trafficStart
	local events = EventService.plan(Config.Timing.RoundTimeLimit)
	local hazardContext: HazardService.Context = {
		getChickens = function()
			return aliveList(r)
		end,
		isAlive = function(player)
			return r.alive[player] == true
		end,
	}
	TrafficService.start({
		rushHour = mode.rushHour,
		startTime = trafficStart,
		suddenDeathAt = liveOffset + Config.Timing.SuddenDeathAt,
		windows = EventService.trafficWindows(events, liveOffset),
		getChickens = function()
			return aliveList(r)
		end,
		onHit = function(player: Player, car: TrafficSchedule.Car)
			if not r.alive[player] or RoundState:GetAttribute("State") ~= "InRound" then
				return
			end
			if PowerupService.absorbCarHit(player, car) then
				return
			end
			if car.vehicle == "Harvester" then
				eliminate(r, player, "got harvested", "car")
			elseif car.driver then
				local driver = Players:GetPlayerByUserId(car.driver)
				eliminate(r, player, `got run over by {if driver then driver.DisplayName else "a driver"}`, "angry")
			else
				eliminate(r, player, "got flattened by a car", "car")
			end
			ChickenService.squash(player, Vector3.new(car.dir * car.speed, 0, 0))
		end,
	})

	setState("Starting", countdown, `{mode.name}: {mode.description}`)
	task.wait(math.max(0, liveAt - now()))
	if #aliveList(r) == 0 then
		r.ended = true
	end

	local roundStart = liveAt
	r.startedAt = roundStart
	setState("InRound", Config.Timing.RoundTimeLimit)
	task.spawn(runCrossing, r, roundStart)
	HazardService.start(arena, hazardContext)
	EventService.run(events, roundStart, hazardContext)
	PowerupService.start(hazardContext)
	BountyService.start(hazardContext)

	local suddenDeathAnnounced = false
	local winners: { Player } = {}
	local message = "Nobody made it!"
	while not r.ended do
		task.wait(0.1)
		local elapsed = now() - roundStart

		for _, player in aliveList(r) do
			local root = ChickenService.getRoot(player)
			if player.Character ~= r.characters[player] or not root or not ChickenService.getHumanoid(player) then
				-- The round chicken was replaced or removed without dying (we'd never see its
				-- Died event), so it can't be hit any more and would stall the round.
				eliminate(r, player, "flew the coop", "feather")
			elseif root.Position.Y < Config.Map.KillY then
				eliminate(r, player, "fell into the clouds", "skull")
				ChickenService.kill(player)
			end
		end

		if not suddenDeathAnnounced and elapsed >= Config.Timing.SuddenDeathAt then
			suddenDeathAnnounced = true
			RoundState:SetAttribute("SuddenDeath", true)
			feed("SUDDEN DEATH! Traffic speeds up!", "fire")
		end

		local over, w, m = checkWinner(r)
		if over then
			winners, message = w, m or message
			break
		end
		if elapsed >= Config.Timing.RoundTimeLimit then
			winners = aliveList(r)
			message = if #winners > 0 then "Time's up! Survivors win!" else message
			break
		end
	end

	stopRound(r)
	return winners, message
end

local function cleanupRound(r: Round)
	for _, player in r.participants do
		if player.Parent then
			player:SetAttribute("Alive", nil)
			player:SetAttribute("Driver", nil)
			player:SetAttribute("Team", nil)
			-- Back to neutral (the type definitions don't allow nil here).
			local untyped: any = player
			untyped.Team = nil
			-- Survivors go back to the lobby.
			if r.alive[player] then
				task.spawn(ChickenService.spawn, player)
			end
		end
	end
	round = nil
	RoundState:SetAttribute("ModeId", "")
	RoundState:SetAttribute("RoundPlayers", 0)
end

local function giveRoundRewards(r: Round, winners: { Player })
	local R = Config.Rewards
	for _, player in r.participants do
		if player.Parent then
			DataService.addStat(player, "Rounds", 1)
			DataService.reward(player, R.Participate, "for playing")
			ProgressService.roundPlayed(player)
			if r.alive[player] then
				survivalReward(r, player)
			end
		end
	end
	for _, player in winners do
		if player.Parent then
			DataService.addStat(player, "Wins", 1)
			DataService.reward(player, if r.mode.teams then R.TeamWin else R.Win, "for winning!")
			ProgressService.won(player, r.mode.teams)
		end
	end
end

local function waitForPlayers()
	while #activePlayers() < Config.MinPlayers do
		setState("Waiting", nil, `Waiting for players ({#activePlayers()}/{Config.MinPlayers})`)
		task.wait(1)
	end
end

function RoundService.init()
	arena = MapBuilder.prepare()
	SidewalkService.reset(arena)

	local function makeTeam(side: Side, name: string, color: BrickColor)
		local team = Instance.new("Team")
		team.Name = name
		team.TeamColor = color
		team.AutoAssignable = false
		team.Parent = Teams
		teamObjects[side] = team
	end
	makeTeam("A", "Red Hens", BrickColor.new("Bright red"))
	makeTeam("B", "Blue Roosters", BrickColor.new("Bright blue"))

	Remotes.Vote.OnServerEvent:Connect(onVote)
	Remotes.LaunchRageCar.OnServerEvent:Connect(onLaunchRageCar)
	Remotes.SetAfk.OnServerEvent:Connect(onSetAfk)
	Players.PlayerRemoving:Connect(function(player)
		lastAfkChange[player] = nil
		if votes[player] then
			votes[player] = nil
			publishVotes()
		end
	end)

	task.spawn(function()
		while true do
			waitForPlayers()
			local mode = runVote()
			-- Players can leave during the vote; go back to waiting instead of starting a
			-- round nobody can win.
			if #activePlayers() < Config.MinPlayers then
				continue
			end
			local ok, winners, message = pcall(runRound, mode)
			if not ok then
				warn("Round failed:", winners)
				winners, message = {}, "Round cancelled"
				xpcall(stopRound, function(err)
					warn("Round cleanup failed:", err)
				end, round)
			end
			local celebrations = {}
			for _, player in winners :: { Player } do
				table.insert(celebrations, { userId = player.UserId, effect = DataService.equipped(player, "WinEffect") })
			end
			Remotes.WinEffect:FireAllClients(celebrations)
			if ok and round then
				giveRoundRewards(round, winners :: { Player })
			end
			setState("Results", Config.Timing.ResultsDuration, message :: string)
			task.wait(Config.Timing.ResultsDuration)
			if round then
				cleanupRound(round)
			end
		end
	end)
end

return RoundService
