--!strict
-- Drives the Hud ScreenGui (built in Studio, see src/builders/GuiBuilder.luau):
--   * the round card (top): what's happening, a timer and a progress bar; shows the current
--     event while one is running
--   * the stats bar (bottom): round time, chickens alive, your golden eggs (MenuUI)
--   * the objective card (bottom left): what to do right now (run to the other side...)
--   * the board (top right): players, alive first, with their wins
--   * feed, voting, mode intro, 3-2-1-GO, results, sudden death, stamina, spectating, AFK,
--     and full-screen effects (danger edges, egg splat, flashes)

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Events = require(Shared.Events)
local Layout = require(Shared.Layout)
local Modes = require(Shared.Modes)
local Remotes = require(Shared.Remotes)
local RoundState = require(Shared.RoundState)

local Anim = require(script.Parent.Parent.Anim)
local CameraFx = require(script.Parent.Parent.CameraFx)
local EggController = require(script.Parent.EggController)
local Effects = require(script.Parent.Parent.Effects)
local Gui = require(script.Parent.Parent.Gui)
local MovementController = require(script.Parent.MovementController)
local MusicController = require(script.Parent.MusicController)
local Sfx = require(script.Parent.Parent.Sfx)
local Sprites = require(script.Parent.Parent.Sprites)
local TrafficRenderer = require(script.Parent.TrafficRenderer)

local RoundUI = {}

local player = Players.LocalPlayer

local PINK = Color3.fromRGB(255, 118, 176)
local GREEN = Color3.fromRGB(140, 230, 110)
local ORANGE = Color3.fromRGB(255, 156, 46)
local YELLOW = Color3.fromRGB(255, 204, 64)
local RED = Color3.fromRGB(235, 80, 70)
local CREAM = Color3.fromRGB(255, 246, 228)

type ModeLook = { sprite: string, color: Color3 }
local MODE_LOOKS: { [string]: ModeLook } = {
	Solo = { sprite = "chickenRun", color = Color3.fromRGB(255, 150, 40) },
	Teams = { sprite = "team", color = Color3.fromRGB(70, 160, 240) },
	RushHour = { sprite = "lightning", color = Color3.fromRGB(160, 110, 230) },
	RoadRage = { sprite = "angry", color = Color3.fromRGB(226, 74, 64) },
}

type StateLook = { title: string, sprite: string }
local STATE_LOOKS: { [string]: StateLook } = {
	Waiting = { title = "Waiting for players", sprite = "users" },
	Voting = { title = "Vote for a mode", sprite = "vote" },
	Starting = { title = "Get ready...", sprite = "clock" },
	InRound = { title = "Cross the road!", sprite = "chickenRun" },
	Results = { title = "Round over", sprite = "trophy" },
}

local hud: ScreenGui
local ui: { [string]: any } = {}

local myVote: string? = nil
local lastState: string? = nil
local lastSecond = -1
local winners: { number } = {}
local roundCoins = 0
local spectating = false
local spectateIndex = 0
local feedOrder = 0
local endsAtStart = 0 -- when the current EndsAt countdown began (for the progress bar)
local crossStart = 0
local lastCrossSecond = -1
local wasSafe: boolean? = nil

local function decode(attribute: string, default: any): any
	local raw = RoundState:GetAttribute(attribute)
	if type(raw) ~= "string" or raw == "" then
		return default
	end
	local ok, value = pcall(HttpService.JSONDecode, HttpService, raw)
	return if ok then value else default
end

local function alivePlayers(): { Player }
	local list = {}
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("Alive") == true then
			table.insert(list, p)
		end
	end
	return list
end

local function state(): string
	local s = RoundState:GetAttribute("State")
	return if type(s) == "string" then s else "Waiting"
end

local function now(): number
	return workspace:GetServerTimeNow()
end

local function secondsLeft(): number
	local endsAt = RoundState:GetAttribute("EndsAt")
	if type(endsAt) ~= "number" or endsAt <= 0 then
		return -1
	end
	return math.max(0, endsAt - now())
end

local function clock(seconds: number): string
	local whole = math.ceil(seconds)
	return string.format("%d:%02d", whole // 60, whole % 60)
end

local function currentEvent(): Events.Event?
	local id = RoundState:GetAttribute("Event")
	return if type(id) == "string" and id ~= "" then Events.get(id) else nil
end

local function currentMode(): Modes.Mode?
	local id = RoundState:GetAttribute("ModeId")
	return if type(id) == "string" then Modes.get(id) else nil
end

local function isAfk(): boolean
	return player:GetAttribute("Afk") == true
end

-- Feed ----------------------------------------------------------------------------------------

local function pushFeed(text: string, icon: string?)
	feedOrder += 1
	local line = Gui.template(hud, "FeedLine")
	line.LayoutOrder = -feedOrder -- newest on top
	Sprites.set(line.Icon, icon or "info")
	line.Text.Text = text
	line.Visible = false
	line.Parent = ui.feed
	Anim.pop(line)
	local lines = {}
	for _, child in ui.feed:GetChildren() do
		if child:IsA("Frame") then
			table.insert(lines, child)
		end
	end
	if #lines > 5 then
		table.sort(lines, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		lines[#lines]:Destroy()
	end
	task.delay(7, function()
		if line.Parent then
			Anim.hide(line, function()
				line:Destroy()
			end)
		end
	end)
end

-- Voting -------------------------------------------------------------------------------------

local voteCards: { [string]: any } = {}

local function updateVoteCounts()
	local counts: { [string]: number } = decode("Votes", {})
	local total = 0
	for _, c in counts do
		total += c
	end
	for id, card in voteCards do
		local c = counts[id] or 0
		local inner = card.Border.Inner
		inner.Bar.Votes.Text = if c == 1 then "1 vote" else `{c} votes`
		Anim.tween(inner.Bar.Fill, 0.35, { Size = UDim2.fromScale(if total > 0 then c / total else 0, 1) })
		local mine = myVote == id
		card.Check.Visible = mine
		card.Border.UIStroke.Color = if mine then GREEN else Color3.fromRGB(236, 178, 86)
		card.Border.UIStroke.Thickness = if mine then 3 else 2
	end
end

local function rebuildVotes()
	for _, card in voteCards do
		card:Destroy()
	end
	table.clear(voteCards)
	local options: { string } = decode("VoteOptions", {})
	for i, id in options do
		local mode = Modes.get(id)
		if mode then
			local look = MODE_LOOKS[id] or MODE_LOOKS.Solo
			local card = Gui.template(hud, "VoteCard")
			card.Name = id
			card.LayoutOrder = i
			card.Visible = false
			local inner = card.Border.Inner
			inner.Band.BackgroundColor3 = look.color
			inner.Bar.Fill.BackgroundColor3 = look.color
			inner.Bar.Fill.Size = UDim2.fromScale(0, 1)
			Sprites.set(inner.Icon, look.sprite)
			inner.ModeName.Text = string.upper(mode.name)
			inner.Desc.Text = mode.description
			card.Parent = ui.vote.Cards
			Anim.juice(card)
			Anim.pop(card, 0.07 * i)
			card.Activated:Connect(function()
				if isAfk() then
					Sfx.play("Error")
					Anim.shake(card, 4, 0.25)
					return
				end
				if myVote ~= id then
					myVote = id
					Remotes.Vote:FireServer(id)
					Sfx.play("Vote")
					Anim.punch(card, 0.08)
					updateVoteCounts()
				end
			end)
			voteCards[id] = card
		end
	end
	updateVoteCounts()
end

-- Big moments ---------------------------------------------------------------------------------

local function showIntro()
	local mode = currentMode()
	if not mode then
		return
	end
	local look = MODE_LOOKS[mode.id] or MODE_LOOKS.Solo
	local inner = ui.intro.Inner
	Sprites.set(inner.Icon, look.sprite)
	inner.Title.Text = string.upper(mode.name)
	inner.Title.TextColor3 = look.color
	inner.Desc.Text = mode.description
	Anim.pop(ui.intro)
	Sfx.play("UiOpen")
end

local function showCountdownNumber(n: number)
	if ui.intro.Visible then
		Anim.hide(ui.intro)
	end
	ui.countdown.Number.Text = tostring(n)
	ui.countdown.Number.TextColor3 = YELLOW
	if not ui.countdown.Visible then
		Anim.pop(ui.countdown)
	else
		Anim.punch(ui.countdown, 0.2)
	end
	Sfx.play(if n == 1 then "TickFinal" else "Tick")
end

local function flash(color: Color3, strength: number)
	ui.flash.BackgroundColor3 = color
	ui.flash.BackgroundTransparency = 1 - strength
	Anim.tween(ui.flash, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 })
end

local function showGo()
	Anim.hide(ui.intro)
	ui.countdown.Number.Text = "GO!"
	ui.countdown.Number.TextColor3 = GREEN
	if not ui.countdown.Visible then
		Anim.pop(ui.countdown)
	else
		Anim.punch(ui.countdown, 0.25)
	end
	Sfx.play("Go")
	Sfx.play("Whistle")
	CameraFx.fovPunch(10)
	flash(Color3.new(1, 1, 1), 0.2)
	task.delay(0.9, function()
		Anim.hide(ui.countdown)
	end)
end

local function showResults()
	local message = RoundState:GetAttribute("Message")
	local iWon = table.find(winners, player.UserId) ~= nil
	local inner = ui.results.Card.Inner
	local title = inner.Title
	if iWon then
		title.Text = "YOU WIN!"
		title.TextColor3 = ORANGE
		Sprites.set(ui.results.Icon, "crown")
		Sfx.play("Fanfare")
		MusicController.duck(3)
		flash(Color3.fromRGB(255, 240, 180), 0.3)
	elseif #winners > 0 then
		title.Text = "WINNER!"
		title.TextColor3 = ORANGE
		Sprites.set(ui.results.Icon, "trophy")
	else
		title.Text = "NOBODY MADE IT"
		title.TextColor3 = RED
		Sprites.set(ui.results.Icon, "eggCrack")
	end
	inner.Winner.Text = if type(message) == "string" then message else ""
	inner.Reward.Visible = false
	Anim.pop(ui.results)
	-- Eggs from the round arrive as toasts right after; tally them on the results card.
	task.delay(0.9, function()
		if state() == "Results" and roundCoins > 0 then
			Anim.pop(inner.Reward)
			Anim.countTo(inner.Reward.Label, 0, roundCoins, 1, function(n)
				return `+{math.floor(n + 0.5)}`
			end)
			Sfx.play("Coin")
		end
	end)
end

local function showSuddenDeath()
	local banner = ui.suddenDeath
	banner.Position = UDim2.fromScale(-0.8, 0.3)
	banner.Visible = true
	Anim.tween(banner, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0.5, 0.3) })
	Sfx.play("SuddenDeath")
	CameraFx.shake(0.5)
	flash(Color3.fromRGB(255, 60, 60), 0.25)
	task.delay(2.6, function()
		local t = Anim.tween(banner, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.In), { Position = UDim2.fromScale(1.8, 0.3) })
		t.Completed:Once(function()
			banner.Visible = false
		end)
	end)
end

local splatToken = 0
local function showEggSplat()
	splatToken += 1
	local token = splatToken
	local splat = ui.splat
	splat.Rotation = math.random(-30, 30)
	splat.Position = UDim2.fromScale(0.3 + math.random() * 0.4, 0.3 + math.random() * 0.3)
	local start = splat.Position
	splat.ImageTransparency = 0
	local emoji = splat:FindFirstChild("SpriteEmoji")
	if emoji then
		emoji.TextTransparency = 0
	end
	splat.Visible = true
	local scale = Anim.scaleOf(splat)
	scale.Scale = 0.6
	Anim.tween(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
	task.delay(0.8, function()
		if token ~= splatToken then
			return
		end
		Anim.tween(splat, 1.4, { ImageTransparency = 1, Position = start + UDim2.fromScale(0, 0.08) })
		if emoji then
			Anim.tween(emoji, 1.4, { TextTransparency = 1 })
		end
		task.delay(1.5, function()
			if token == splatToken then
				splat.Visible = false
			end
		end)
	end)
end

-- Spectating ----------------------------------------------------------------------------------

local function resetCamera()
	spectating = false
	Anim.setShown(ui.spectateBar, false)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		workspace.CurrentCamera.CameraSubject = humanoid
	end
end

local function spectate(step: number)
	local alive = alivePlayers()
	if #alive == 0 then
		resetCamera()
		return
	end
	spectateIndex = ((spectateIndex - 1 + step) % #alive) + 1
	local target = alive[spectateIndex]
	local humanoid = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		spectating = true
		workspace.CurrentCamera.CameraSubject = humanoid
		ui.spectateBar.NameCard.Inner.Player.Text = target.DisplayName
		if not ui.spectateBar.Visible then
			Anim.pop(ui.spectateBar)
		else
			Anim.punch(ui.spectateBar.NameCard, 0.06)
		end
	end
end

-- Objective card ---------------------------------------------------------------------------------

local objectiveKey = ""
local function setObjective(key: string, title: string, sub: string, color: Color3, sprite: string)
	local inner = ui.objective.Inner
	inner.Title.Text = title
	inner.Sub.Text = sub
	inner.Title.TextColor3 = color
	if key ~= objectiveKey then
		objectiveKey = key
		Sprites.set(inner.Icon, sprite)
		Anim.punch(ui.objective, 0.06)
	end
end

local function onCrossTarget()
	crossStart = now()
	lastCrossSecond = -1
	wasSafe = nil
	local target = RoundState:GetAttribute("CrossTarget")
	if type(target) == "string" and target ~= "" and player:GetAttribute("Alive") == true then
		Anim.shake(ui.objective, 6, 0.35)
	end
end

local function renderObjective(s: string, alive: boolean)
	local inner = ui.objective.Inner
	local bar = inner.Bar
	if isAfk() then
		bar.Visible = false
		setObjective("afk", "YOU'RE AFK", "You'll sit out rounds until you press BACK.", YELLOW, "clock")
		return
	end
	if s == "InRound" and alive then
		local target = RoundState:GetAttribute("CrossTarget")
		local deadline = RoundState:GetAttribute("CrossDeadline")
		if type(target) == "string" and target ~= "" and type(deadline) == "number" then
			local left = math.max(0, deadline - now())
			local total = math.max(1, deadline - crossStart)
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local safe = root ~= nil and Layout.zoneOf(root.Position.Z) == target
			local name = string.upper(Layout.sideName(target))
			local leaving = string.lower(Layout.sideName(if target == "A" then "B" else "A"))
			local whole = math.ceil(left)
			if safe then
				setObjective("safe" .. target, "SAFE! HOLD ON...", `The {leaving} side crumbles in {whole}s.`, GREEN, if target == "A" then "barn" else "windmill")
			else
				setObjective("run" .. target, `RUN TO THE {name}!`, `The {leaving} side crumbles in {whole}s.`, PINK, if target == "A" then "barn" else "windmill")
			end
			if safe ~= wasSafe then
				if safe and wasSafe ~= nil then
					Sfx.play("Coin", { pitch = 1.4, volume = 0.4 })
				end
				wasSafe = safe
			end
			bar.Visible = true
			local urgent = left <= Config.Shuttle.Warning and not safe
			bar.Fill.Size = UDim2.fromScale(math.clamp(left / total, 0, 1), 1)
			bar.Fill.BackgroundColor3 = if urgent then RED elseif safe then GREEN else YELLOW
			if whole ~= lastCrossSecond then
				lastCrossSecond = whole
				if urgent and whole > 0 then
					Anim.punch(ui.objective, 0.04)
					Sfx.play(if whole <= 1 then "TickFinal" else "Tick", { volume = 0.55 })
				end
			end
			return
		end
	end
	bar.Visible = false
	local mode = currentMode()
	if s == "InRound" then
		if player:GetAttribute("Driver") == true then
			setObjective("driver", "ROAD RAGE!", "Pick a lane and send cars at the chickens.", RED, "angry")
		else
			setObjective("out", "YOU GOT SQUASHED", "Spectate the survivors or wait for the next round.", RED, "eggCrack")
		end
	elseif s == "Starting" then
		setObjective("start" .. (if mode then mode.id else ""), "GET READY!", if mode then mode.description else "The round is about to start.", ORANGE, "clock")
	elseif s == "Voting" then
		setObjective("vote", "VOTE FOR A MODE", "Pick the next game below.", PINK, "vote")
	elseif s == "Results" then
		setObjective("results", "ROUND OVER", "Next round starts in a moment.", ORANGE, "trophy")
	else
		local message = RoundState:GetAttribute("Message")
		setObjective(
			"wait",
			"WAITING FOR CHICKENS",
			if type(message) == "string" and message ~= "" then message else "The game starts when enough chickens are here.",
			PINK,
			"chick"
		)
	end
end

-- Board -------------------------------------------------------------------------------------------

local lastBoard = 0
local function wins(p: Player): number
	local stats = p:FindFirstChild("leaderstats")
	local w = stats and stats:FindFirstChild("Wins")
	return if w and w:IsA("IntValue") then w.Value else 0
end

local function knockouts(p: Player): number
	local kos = p:GetAttribute("RoundKOs")
	return if type(kos) == "number" then kos else 0
end

local function renderBoard(s: string)
	if os.clock() - lastBoard < 0.5 then
		return
	end
	lastBoard = os.clock()
	local inner = ui.board.Inner
	local inRound = s == "InRound" or s == "Starting"
	local players = Players:GetPlayers()
	table.sort(players, function(a, b)
		if inRound then
			local aa, ba = a:GetAttribute("Alive") == true, b:GetAttribute("Alive") == true
			if aa ~= ba then
				return aa
			end
		end
		local wa, wb = if inRound then knockouts(a) else wins(a), if inRound then knockouts(b) else wins(b)
		if wa ~= wb then
			return wa > wb
		end
		return a.DisplayName < b.DisplayName
	end)
	local mode = currentMode()
	inner.Stat.Text = if inRound then "KOs" else "WINS"
	if inRound then
		inner.Title.Text = if mode then string.upper(mode.name) else "ROUND"
		local total = RoundState:GetAttribute("RoundPlayers")
		local alive = #alivePlayers()
		inner.Big.Text = if type(total) == "number" and total > 0 then `{alive} OF {total} LEFT` else `{alive} LEFT`
	else
		inner.Title.Text = "TOP CHICKENS"
		inner.Big.Text = `{#players} IN LOBBY`
	end
	local rows = inner.Rows
	local existing = {}
	for _, child in rows:GetChildren() do
		if child:IsA("Frame") then
			table.insert(existing, child)
		end
	end
	local shown = math.min(#players, 8)
	for i = 1, shown do
		local p = players[i]
		local row = existing[i]
		if not row then
			row = Gui.template(hud, "BoardRow")
			row.Parent = rows
		end
		row.LayoutOrder = i
		row.Rank.Text = `{i}.`
		local lv = p:GetAttribute("Level") -- set by ProgressService
		row.Player.Text = (if type(lv) == "number" then `Lv{lv} ` else "") .. p.DisplayName .. (if p:GetAttribute("Afk") == true then " (AFK)" else "")
		row.Value.Text = tostring(if inRound then knockouts(p) else wins(p))
		local out = inRound and p:GetAttribute("Alive") ~= true
		row.Player.TextTransparency = if out then 0.55 else 0
		row.Rank.TextTransparency = if out then 0.55 else 0
		row.BackgroundColor3 = if p == player then Color3.fromRGB(255, 214, 170) else Color3.fromRGB(244, 230, 204)
		row.BackgroundTransparency = if p == player then 0 else 0.2
	end
	for i = shown + 1, #existing do
		existing[i]:Destroy()
	end
end

-- State changes -------------------------------------------------------------------------------

local function onStateChanged()
	local s = state()
	endsAtStart = now()

	if s == "Voting" then
		myVote = nil
		roundCoins = 0
		Anim.pop(ui.vote)
		rebuildVotes()
	elseif ui.vote.Visible then
		Anim.hide(ui.vote)
	end
	if s == "Starting" then
		showIntro()
	end
	if s == "InRound" and lastState == "Starting" then
		showGo()
	end
	if s == "Results" then
		showResults()
	elseif ui.results.Visible then
		Anim.hide(ui.results)
	end
	if s ~= "Starting" and s ~= "InRound" then
		Anim.hide(ui.intro)
		if spectating then
			resetCamera()
		end
	end
	-- While voting, everything but the round card and the vote gets out of the way.
	local voting = s == "Voting"
	for _, widget in { ui.objective, ui.board, ui.feed, ui.stats, ui.buttons } do
		Anim.setShown(widget, not voting)
	end
	Anim.punch(ui.roundCard, 0.06)
	lastState = s
	lastSecond = -1
	lastBoard = 0
end

local lastEvent: string? = nil
local function onEvent()
	local event = currentEvent()
	local id = if event then event.id else nil
	if id == lastEvent then
		return
	end
	lastEvent = id
	if event then
		Anim.punch(ui.roundCard, 0.12)
		Anim.shake(ui.roundCard, 5, 0.3)
		Sfx.play("Whistle", { pitch = 1.1 })
		pushFeed(`{event.name}: {event.description}`, event.sprite)
	end
end

local lastAlive = -1
local wasAlive = false
local eggReady = true
local lastRoundCardKey = ""

local function renderRoundCard(s: string, left: number)
	local inner = ui.roundCard.Inner
	local event = currentEvent()
	local title: string, sprite: string, color: Color3
	local timeLeft: number, total: number
	if event and s == "InRound" then
		local endsAt = RoundState:GetAttribute("EventEndsAt")
		title, sprite, color = event.name, event.sprite, event.color
		timeLeft = if type(endsAt) == "number" and endsAt > 0 then math.max(0, endsAt - now()) else -1
		total = Config.Events.Duration
	else
		local look = STATE_LOOKS[s] or STATE_LOOKS.Waiting
		local mode = currentMode()
		title, sprite, color = look.title, look.sprite, ORANGE
		if s == "InRound" and mode then
			title = mode.name
			local modeLook = MODE_LOOKS[mode.id]
			if modeLook then
				sprite, color = modeLook.sprite, modeLook.color
			end
		end
		timeLeft = left
		local endsAt = RoundState:GetAttribute("EndsAt")
		total = if type(endsAt) == "number" then endsAt - endsAtStart else 1
	end
	local key = title .. sprite
	if key ~= lastRoundCardKey then
		lastRoundCardKey = key
		inner.Title.Text = title
		Sprites.set(inner.Icon, sprite)
	end
	inner.Time.Text = if timeLeft >= 0 then clock(timeLeft) else "--"
	inner.Bar.Visible = timeLeft >= 0
	inner.Bar.Fill.BackgroundColor3 = color
	if timeLeft >= 0 then
		inner.Bar.Fill.Size = UDim2.fromScale(math.clamp(timeLeft / math.max(total, 1), 0, 1), 1)
	end
end

local function render()
	local s = state()
	local left = secondsLeft()
	local alive = player:GetAttribute("Alive") == true

	renderRoundCard(s, left)

	-- Timer in the stats bar, turning red over the last 5 seconds.
	local timeLabel = ui.stats.Inner.Row.Time.Label
	if left >= 0 then
		local whole = math.ceil(left)
		timeLabel.Text = clock(left)
		if whole ~= lastSecond then
			lastSecond = whole
			local urgent = whole <= 5 and (s == "InRound" or s == "Voting")
			timeLabel.TextColor3 = if urgent then RED else CREAM
			if urgent then
				Anim.punch(ui.stats.Inner.Row.Time, 0.15)
			end
			if s == "Starting" and whole >= 1 and whole <= 3 then
				showCountdownNumber(whole)
			end
		end
	else
		timeLabel.Text = "--"
	end
	if s == "Voting" then
		ui.vote.Header.Inner.Timer.Text = tostring(math.ceil(math.max(left, 0)))
	end

	-- Chickens left.
	local count = #alivePlayers()
	local total = RoundState:GetAttribute("RoundPlayers")
	local inRound = s == "InRound" or s == "Starting"
	local aliveText = if inRound and type(total) == "number" and total > 0 then `{count}/{total}` else tostring(#Players:GetPlayers())
	local aliveLabel = ui.stats.Inner.Row.Alive.Label
	if aliveLabel.Text ~= aliveText then
		aliveLabel.Text = aliveText
		if count < lastAlive and inRound then
			Anim.punch(ui.stats.Inner.Row.Alive, 0.2)
		end
	end
	lastAlive = count

	renderObjective(s, alive)
	renderBoard(s)

	-- Egg recharge: a thin bar that fills back up after each shot, with a pop when it's ready.
	local playing = s == "InRound" and alive
	Anim.setShown(ui.eggCharge, playing)
	local charge = EggController.charge()
	ui.eggCharge.Track.Fill.Size = UDim2.fromScale(math.max(0.02, charge), 1)
	ui.eggCharge.Track.Fill.BackgroundColor3 = if charge >= 1 then Color3.fromRGB(255, 246, 228) else Color3.fromRGB(196, 170, 130)
	ui.eggCharge.Icon.ImageTransparency = if charge >= 1 then 0 else 0.45
	if charge >= 1 and not eggReady and playing then
		Anim.punch(ui.eggCharge, 0.12)
	end
	eggReady = charge >= 1

	-- Stamina.
	Anim.setShown(ui.stamina, playing)
	local fill = ui.stamina.Track.Fill
	fill.Size = UDim2.fromScale(math.max(0.02, MovementController.getStamina()), 1)
	fill.BackgroundColor3 = if MovementController.isGliding() then Color3.fromRGB(150, 220, 255) else YELLOW

	-- Spectate button for the eliminated.
	local canSpectate = s == "InRound" and not alive and player:GetAttribute("Driver") ~= true
	if ui.spectateButton.Visible ~= canSpectate then
		ui.spectateButton.Visible = canSpectate
		if canSpectate then
			Anim.pop(ui.spectateButton)
		end
	end
	if not canSpectate and spectating then
		resetCamera()
	end

	-- Red screen edges when a car is about to hit you.
	local danger = if alive and s == "InRound" then TrafficRenderer.danger() else 0
	ui.danger.Visible = danger > 0.05
	if ui.danger.Visible then
		local pulse = 0.5 + 0.5 * math.sin(os.clock() * 20)
		for _, edge in ui.danger:GetChildren() do
			if edge:IsA("Frame") then
				edge.BackgroundTransparency = 1 - danger * (0.5 + 0.4 * pulse)
			end
		end
	end

	-- You just got eliminated.
	if wasAlive and not alive and (s == "InRound" or s == "Starting") then
		Sfx.play("Eliminated")
		MusicController.duck(2.5)
		flash(Color3.fromRGB(255, 70, 70), 0.3)
	end
	wasAlive = alive
end

-- AFK ---------------------------------------------------------------------------------------------

local function refreshAfk()
	local afk = isAfk()
	local inner = ui.afk.Border.Inner
	if afk then
		Gui.setButton(ui.afk, "BACK", ORANGE, "play")
	else
		Gui.setButton(ui.afk, "AFK", nil, "clock")
		inner.BackgroundColor3 = Color3.fromRGB(44, 29, 20)
		inner.BackgroundTransparency = 0.08
		inner:SetAttribute("Accent", nil)
	end
	Anim.punch(ui.afk, 0.1)
end

-- Phones and tablets: keep the bottom-left corner free for the thumbstick.
local function touchLayout()
	if not Gui.isTouch() then
		return
	end
	ui.objective.AnchorPoint = Vector2.new(0.5, 0)
	ui.objective.Position = UDim2.new(0.5, 0, 0, 84)
	ui.buttons.AnchorPoint = Vector2.new(0, 0.5)
	ui.buttons.Position = UDim2.new(0, 12, 0.56, 0)
	ui.buttons.Size = UDim2.fromOffset(140, 300)
	local list = ui.buttons:FindFirstChildOfClass("UIListLayout")
	if list then
		list.FillDirection = Enum.FillDirection.Vertical
	end
	ui.feed.Size = UDim2.fromOffset(340, 100)
end

function RoundUI.start()
	hud = Gui.screen("Hud")
	local root = Gui.find(hud, "Root")
	ui = {
		roundCard = Gui.find(root, "RoundCard"),
		stats = Gui.find(root, "Stats"),
		objective = Gui.find(root, "Objective"),
		buttons = Gui.find(root, "Buttons"),
		afk = Gui.find(root, "Buttons/Afk"),
		spectateButton = Gui.find(root, "Buttons/Spectate"),
		board = Gui.find(root, "Board"),
		feed = Gui.find(root, "Feed"),
		stamina = Gui.find(root, "Stamina"),
		eggCharge = Gui.find(root, "EggCharge"),
		spectateBar = Gui.find(root, "SpectateBar"),
		intro = Gui.find(root, "Intro"),
		countdown = Gui.find(root, "Countdown"),
		results = Gui.find(root, "Results"),
		suddenDeath = Gui.find(root, "SuddenDeath"),
		vote = Gui.find(root, "Vote"),
		splat = Gui.find(root, "Splat"),
		danger = Gui.find(root, "Danger"),
		flash = Gui.find(root, "Flash"),
	}
	touchLayout()
	Anim.autoJuice(hud)

	RoundState:GetAttributeChangedSignal("State"):Connect(onStateChanged)
	RoundState:GetAttributeChangedSignal("EndsAt"):Connect(function()
		endsAtStart = now()
	end)
	RoundState:GetAttributeChangedSignal("VoteOptions"):Connect(function()
		if state() == "Voting" then
			rebuildVotes()
		end
	end)
	RoundState:GetAttributeChangedSignal("Votes"):Connect(updateVoteCounts)
	RoundState:GetAttributeChangedSignal("SuddenDeath"):Connect(function()
		if RoundState:GetAttribute("SuddenDeath") == true then
			showSuddenDeath()
		end
	end)
	RoundState:GetAttributeChangedSignal("CrossTarget"):Connect(onCrossTarget)
	RoundState:GetAttributeChangedSignal("Event"):Connect(onEvent)
	onStateChanged()
	onCrossTarget()
	local event = currentEvent()
	lastEvent = if event then event.id else nil

	Remotes.Feed.OnClientEvent:Connect(pushFeed)
	Remotes.Knockback.OnClientEvent:Connect(showEggSplat)
	Remotes.WinEffect.OnClientEvent:Connect(function(celebrations: { { userId: number, effect: string } })
		winners = {}
		for _, c in celebrations do
			table.insert(winners, c.userId)
		end
		Effects.win(celebrations)
	end)
	Remotes.Notify.OnClientEvent:Connect(function(_text: string, kind: string?, amount: number?)
		if kind == "coin" and type(amount) == "number" then
			roundCoins += amount
		end
	end)

	ui.afk.Activated:Connect(function()
		Remotes.SetAfk:FireServer(not isAfk())
	end)
	player:GetAttributeChangedSignal("Afk"):Connect(function()
		refreshAfk()
		if isAfk() and state() == "Voting" then
			myVote = nil
			updateVoteCounts()
		end
	end)
	if isAfk() then
		refreshAfk()
	end

	ui.spectateButton.Activated:Connect(function()
		if spectating then
			resetCamera()
		else
			spectate(1)
		end
	end)
	ui.spectateBar.Prev.Activated:Connect(function()
		spectate(-1)
	end)
	ui.spectateBar.Next.Activated:Connect(function()
		spectate(1)
	end)
	player.CharacterAdded:Connect(function()
		if spectating then
			task.defer(spectate, 0)
		end
	end)

	RunService.RenderStepped:Connect(render)
end

return RoundUI
