--!strict
-- The game loop: Waiting -> Voting -> Starting -> InRound -> Results -> Voting ...
-- Eliminated chickens respawn in the lobby (or become drivers in Road Rage).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Modes = require(Shared.Modes)
local Remotes = require(Shared.Remotes)
local RoundState = require(Shared.RoundState)
local TrafficSchedule = require(Shared.TrafficSchedule)

local Services = script.Parent
local ChickenService = require(Services.ChickenService)
local DataService = require(Services.DataService)
local EggService = require(Services.EggService)
local MapBuilder = require(Services.MapBuilder)
local SidewalkService = require(Services.SidewalkService)
local TrafficService = require(Services.TrafficService)

local RoundService = {}

type Side = SidewalkService.Side

type Round = {
	mode: Modes.Mode,
	participants: { Player },
	alive: { [Player]: boolean },
	team: { [Player]: Side },
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

local function now(): number
	return workspace:GetServerTimeNow()
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
	if RoundState:GetAttribute("State") ~= "Voting" or type(modeId) ~= "string" then
		return
	end
	if not table.find(voteOptions, modeId) then
		return
	end
	votes[player] = modeId
	publishVotes()
end

local function runVote(): Modes.Mode
	local playerCount = #Players:GetPlayers()
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
	local chosen = Modes.get(best[rng:NextInteger(1, #best)])
	RoundState:SetAttribute("VoteOptions", "[]")
	return chosen or Modes.list[1]
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
		if count <= 1 and #r.participants >= 2 then
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
end

local function eliminate(r: Round, player: Player, reason: string, icon: string)
	if not r.alive[player] then
		return
	end
	r.alive[player] = false
	player:SetAttribute("Alive", false)

	-- Credit whoever egged this chicken just before it died.
	local egged = r.lastEgged[player]
	local shooter = egged and egged.shooter
	if egged and shooter and shooter.Parent and os.clock() - egged.at <= Config.Rewards.KnockoutWindow then
		feed(`{shooter.DisplayName} egged {player.DisplayName} to their doom!`, "egg")
		Remotes.Notify:FireClient(shooter, `KNOCKOUT! {player.DisplayName}`, "knockout", 0)
		DataService.addStat(shooter, "Knockouts", 1)
		DataService.reward(shooter, Config.Rewards.Knockout, "knockout")
	else
		feed(`{player.DisplayName} {reason}`, icon)
	end
	survivalReward(r, player)
	if r.mode.roadRage and player.Parent then
		player:SetAttribute("Driver", true)
		Remotes.Feed:FireClient(player, "You're a driver now. Run them over!", "angry")
	end
end

-- Road Rage -----------------------------------------------------------------------------

local function onLaunchRageCar(player: Player, lane: unknown, dir: unknown)
	local r = round
	if not r or not r.mode.roadRage or RoundState:GetAttribute("State") ~= "InRound" then
		return
	end
	if player:GetAttribute("Driver") ~= true then
		return
	end
	if type(lane) ~= "number" or type(dir) ~= "number" then
		return
	end
	if lane ~= math.floor(lane) or lane < 1 or lane > Config.Map.LaneCount or (dir ~= 1 and dir ~= -1) then
		return
	end
	local t = os.clock()
	if t - (r.lastRageLaunch[player] or 0) < Config.RoadRage.Cooldown then
		return
	end
	r.lastRageLaunch[player] = t
	TrafficService.launchRageCar(player, lane, dir)
end

-- Sidewalk events -----------------------------------------------------------------------

local function busiestSide(r: Round): Side
	local counts: { [Side]: number } = { A = 0, B = 0 }
	for _, player in aliveList(r) do
		local root = ChickenService.getRoot(player)
		local side = root and SidewalkService.sideOf(root.Position.Z)
		if side then
			counts[side] += 1
		end
	end
	if counts.A == counts.B then
		return if rng:NextNumber() < 0.5 then "A" else "B"
	end
	return if counts.A > counts.B then "A" else "B"
end

local function runSidewalkEvents(r: Round, roundStart: number)
	local S = Config.Sidewalk
	if r.mode.sidewalks == "Shrink" then
		while not r.ended do
			task.wait(S.ShrinkInterval)
			if r.ended then
				return
			end
			if SidewalkService.shrink(S.ShrinkWarning, S.MinRows) then
				feed("The sidewalks are crumbling!", "lightning")
			end
		end
		return
	end

	task.wait(math.max(0, roundStart + S.FirstCollapseAt - now()))
	local rest = S.CollapseRest
	while not r.ended do
		-- Drop the side with the most chickens on it, so nobody can camp.
		local side = busiestSide(r)
		feed(`Sidewalk {side} is collapsing! Cross the road!`, "lightning")
		SidewalkService.collapseSide(side, S.CollapseWarning, S.CollapseDuration)
		if r.ended then
			return
		end
		task.wait(rest)
		rest = math.max(S.CollapseRestMin, rest - S.CollapseRestStep)
	end
end

-- Round ---------------------------------------------------------------------------------

local function playersWithCharacters(): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		local humanoid = ChickenService.getHumanoid(player)
		if humanoid and humanoid.Health > 0 and ChickenService.getRoot(player) then
			table.insert(list, player)
		end
	end
	return list
end

local function runRound(mode: Modes.Mode): ({ Player }, string)
	SidewalkService.reset(arena, Config.Map.LaneCount * Config.Map.LaneWidth / 2)
	EggService.clear()
	RoundState:SetAttribute("SuddenDeath", false)

	local r: Round = {
		mode = mode,
		participants = playersWithCharacters(),
		alive = {},
		team = {},
		connections = {},
		lastRageLaunch = {},
		lastEgged = {},
		ended = false,
	}
	round = r
	RoundState:SetAttribute("ModeId", mode.id)

	-- Teams: shuffle then deal players onto the two sides.
	local shuffled = table.clone(r.participants)
	for i = #shuffled, 2, -1 do
		local j = rng:NextInteger(1, i)
		shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
	end
	for i, player in shuffled do
		local side: Side = if mode.teams
			then (if i % 2 == 1 then "A" else "B")
			else (if rng:NextNumber() < 0.5 then "A" else "B")
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
		end,
	})

	-- Traffic starts with the countdown so the road is already busy when the round begins.
	local trafficStart = math.floor(now())
	local countdown = Config.Timing.CountdownDuration
	TrafficService.start({
		rushHour = mode.rushHour,
		startTime = trafficStart,
		suddenDeathAt = countdown + Config.Timing.SuddenDeathAt,
		getChickens = function()
			return aliveList(r)
		end,
		onHit = function(player: Player, car: TrafficSchedule.Car)
			if not r.alive[player] or RoundState:GetAttribute("State") ~= "InRound" then
				return
			end
			eliminate(r, player, "got flattened by a car", "car")
			ChickenService.squash(player, Vector3.new(car.dir * car.speed, 0, 0))
		end,
	})

	setState("Starting", countdown, `{mode.name}: {mode.description}`)
	task.wait(countdown)
	if #aliveList(r) == 0 then
		r.ended = true
	end

	local roundStart = now()
	r.startedAt = roundStart
	setState("InRound", Config.Timing.RoundTimeLimit)
	task.spawn(runSidewalkEvents, r, roundStart)

	local suddenDeathAnnounced = false
	local winners: { Player } = {}
	local message = "Nobody made it!"
	while not r.ended do
		task.wait(0.1)
		local elapsed = now() - roundStart

		for _, player in aliveList(r) do
			local root = ChickenService.getRoot(player)
			if root and root.Position.Y < Config.Map.KillY then
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

	r.ended = true
	RoundState:SetAttribute("SuddenDeath", false)
	TrafficService.stop()
	EggService.setRules({
		canShoot = function()
			return false
		end,
		canHit = function()
			return false
		end,
	})
	for _, c in r.connections do
		c:Disconnect()
	end
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
end

local function giveRoundRewards(r: Round, winners: { Player })
	local R = Config.Rewards
	for _, player in r.participants do
		if player.Parent then
			DataService.addStat(player, "Rounds", 1)
			DataService.reward(player, R.Participate, "for playing")
			if r.alive[player] then
				survivalReward(r, player)
			end
		end
	end
	for _, player in winners do
		if player.Parent then
			DataService.addStat(player, "Wins", 1)
			DataService.reward(player, if r.mode.teams then R.TeamWin else R.Win, "for winning!")
		end
	end
end

local function waitForPlayers()
	while #Players:GetPlayers() < Config.MinPlayers do
		setState("Waiting", nil, `Waiting for players ({#Players:GetPlayers()}/{Config.MinPlayers})`)
		task.wait(1)
	end
end

function RoundService.init()
	arena = MapBuilder.prepare()
	SidewalkService.reset(arena, Config.Map.LaneCount * Config.Map.LaneWidth / 2)

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
	Players.PlayerRemoving:Connect(function(player)
		if votes[player] then
			votes[player] = nil
			publishVotes()
		end
	end)

	task.spawn(function()
		while true do
			waitForPlayers()
			local mode = runVote()
			local ok, winners, message = pcall(runRound, mode)
			if not ok then
				warn("Round failed:", winners)
				winners, message = {}, "Round cancelled"
				TrafficService.stop()
				if round then
					round.ended = true
					for _, c in round.connections do
						c:Disconnect()
					end
				end
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
