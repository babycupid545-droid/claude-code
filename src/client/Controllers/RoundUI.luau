--!strict
-- Drives the Hud ScreenGui (built in Studio, see src/builders/GuiBuilder.luau): round status
-- and timer, voting, the mode intro, 3-2-1-GO, results, kill feed, stamina, spectating,
-- the sudden death banner and full-screen effects (danger edges, egg splat, flashes).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Modes = require(Shared.Modes)
local Remotes = require(Shared.Remotes)
local RoundState = require(Shared.RoundState)

local Anim = require(script.Parent.Parent.Anim)
local CameraFx = require(script.Parent.Parent.CameraFx)
local Effects = require(script.Parent.Parent.Effects)
local Gui = require(script.Parent.Parent.Gui)
local MovementController = require(script.Parent.MovementController)
local MusicController = require(script.Parent.MusicController)
local Sfx = require(script.Parent.Parent.Sfx)
local Sprites = require(script.Parent.Parent.Sprites)
local TrafficRenderer = require(script.Parent.TrafficRenderer)

local RoundUI = {}

local player = Players.LocalPlayer

type ModeLook = { sprite: string, color: Color3 }
local MODE_LOOKS: { [string]: ModeLook } = {
	Solo = { sprite = "chickenRun", color = Color3.fromRGB(255, 150, 40) },
	Teams = { sprite = "team", color = Color3.fromRGB(60, 160, 255) },
	RushHour = { sprite = "lightning", color = Color3.fromRGB(160, 100, 255) },
	RoadRage = { sprite = "angry", color = Color3.fromRGB(255, 80, 80) },
}

type StateLook = { title: string, sprite: string }
local STATE_LOOKS: { [string]: StateLook } = {
	Waiting = { title = "WAITING", sprite = "users" },
	Voting = { title = "VOTE!", sprite = "vote" },
	Starting = { title = "GET READY", sprite = "clock" },
	InRound = { title = "CROSS!", sprite = "chickenRun" },
	Results = { title = "ROUND OVER", sprite = "trophy" },
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

local function secondsLeft(): number
	local endsAt = RoundState:GetAttribute("EndsAt")
	if type(endsAt) ~= "number" or endsAt <= 0 then
		return -1
	end
	return math.max(0, endsAt - workspace:GetServerTimeNow())
end

-- Feed ----------------------------------------------------------------------------------------

local function pushFeed(text: string, icon: string?)
	feedOrder += 1
	local line = Gui.template(hud, "FeedLine")
	line.LayoutOrder = -feedOrder -- newest on top
	Sprites.set(line.Row.Icon, icon or "info")
	line.Row.Text.Text = text
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
	task.delay(6, function()
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
		local content = card.Face.Content
		content.Bar.Votes.Text = tostring(c)
		Anim.tween(content.Bar.Fill, 0.35, { Size = UDim2.fromScale(if total > 0 then c / total else 0, 1) })
		card.Check.Visible = myVote == id
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
			card.Face.BackgroundColor3 = look.color
			card.Base.BackgroundColor3 = look.color:Lerp(Color3.new(0, 0, 0), 0.45)
			local content = card.Face.Content
			Sprites.set(content.Icon, look.sprite)
			content.ModeName.Text = string.upper(mode.name)
			content.Desc.Text = mode.description
			card.Parent = ui.vote.Cards
			Anim.juice(card)
			Anim.pop(card, 0.08 * i)
			card.Activated:Connect(function()
				if myVote ~= id then
					myVote = id
					Remotes.Vote:FireServer(id)
					Sfx.play("Vote")
					Anim.punch(card, 0.12)
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
	local id = RoundState:GetAttribute("ModeId")
	local mode = if type(id) == "string" then Modes.get(id) else nil
	if not mode then
		return
	end
	local look = MODE_LOOKS[mode.id] or MODE_LOOKS.Solo
	Sprites.set(ui.intro.Icon, look.sprite)
	ui.intro.Title.Text = string.upper(mode.name)
	ui.intro.Title.TextColor3 = look.color:Lerp(Color3.new(1, 1, 1), 0.25)
	ui.intro.Desc.Text = mode.description
	Anim.pop(ui.intro)
	Sfx.play("UiOpen")
end

local function showCountdownNumber(n: number)
	if ui.intro.Visible then
		Anim.hide(ui.intro)
	end
	ui.countdown.Number.Text = tostring(n)
	ui.countdown.Number.TextColor3 = Color3.fromRGB(255, 220, 80)
	if not ui.countdown.Visible then
		Anim.pop(ui.countdown)
	else
		Anim.punch(ui.countdown, 0.35)
	end
	Sfx.play(if n == 1 then "TickFinal" else "Tick")
end

local function flash(color: Color3, strength: number)
	ui.flash.BackgroundColor3 = color
	ui.flash.BackgroundTransparency = 1 - strength
	Anim.tween(ui.flash, 0.5, { BackgroundTransparency = 1 })
end

local function showGo()
	Anim.hide(ui.intro)
	ui.countdown.Number.Text = "GO!"
	ui.countdown.Number.TextColor3 = Color3.fromRGB(110, 240, 120)
	if not ui.countdown.Visible then
		Anim.pop(ui.countdown)
	else
		Anim.punch(ui.countdown, 0.5)
	end
	Sfx.play("Go")
	Sfx.play("Whistle")
	CameraFx.fovPunch(12)
	flash(Color3.new(1, 1, 1), 0.35)
	task.delay(0.9, function()
		Anim.hide(ui.countdown)
	end)
end

local function showResults()
	local message = RoundState:GetAttribute("Message")
	local iWon = table.find(winners, player.UserId) ~= nil
	local title = ui.results.Title
	if iWon then
		title.Text = "YOU WIN!"
		title.TextColor3 = Color3.fromRGB(255, 220, 70)
		Sprites.set(ui.results.Icon, "crown")
		Sfx.play("Fanfare")
		MusicController.duck(3)
		flash(Color3.fromRGB(255, 240, 180), 0.5)
	elseif #winners > 0 then
		title.Text = "WINNER!"
		title.TextColor3 = Color3.fromRGB(255, 220, 70)
		Sprites.set(ui.results.Icon, "trophy")
	else
		title.Text = "NOBODY MADE IT"
		title.TextColor3 = Color3.fromRGB(255, 120, 120)
		Sprites.set(ui.results.Icon, "skull")
	end
	ui.results.Winner.Text = if type(message) == "string" then message else ""
	ui.results.Reward.Visible = false
	Anim.pop(ui.results)
	-- Coins from the round arrive as toasts right after; tally them on the results card.
	task.delay(0.9, function()
		if state() == "Results" and roundCoins > 0 then
			Anim.pop(ui.results.Reward)
			Anim.countTo(ui.results.Reward.Row.Label, 0, roundCoins, 1, function(n)
				return `+{math.floor(n + 0.5)}`
			end)
			Sfx.play("Coin")
		end
	end)
end

local function showSuddenDeath()
	local banner = ui.suddenDeath
	banner.Position = UDim2.fromScale(-0.7, 0.3)
	banner.Visible = true
	Anim.tween(banner, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0.5, 0.3) })
	Sfx.play("SuddenDeath")
	CameraFx.shake(0.6)
	flash(Color3.fromRGB(255, 60, 60), 0.35)
	task.delay(2.6, function()
		local t = Anim.tween(banner, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Position = UDim2.fromScale(1.7, 0.3) })
		t.Completed:Once(function()
			banner.Visible = false
		end)
	end)
end

local function showEggSplat()
	local splat = ui.splat
	splat.Rotation = math.random(-30, 30)
	splat.Position = UDim2.fromScale(0.3 + math.random() * 0.4, 0.3 + math.random() * 0.3)
	splat.ImageTransparency = 0
	local emoji = splat:FindFirstChild("SpriteEmoji")
	if emoji then
		emoji.TextTransparency = 0
	end
	Anim.pop(splat)
	task.delay(0.8, function()
		Anim.tween(splat, 1.4, { ImageTransparency = 1, Position = splat.Position + UDim2.fromScale(0, 0.08) })
		if emoji then
			Anim.tween(emoji, 1.4, { TextTransparency = 1 })
		end
		task.delay(1.5, function()
			splat.Visible = false
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
		ui.spectateBar.NamePill.Row.Player.Text = target.DisplayName
		if not ui.spectateBar.Visible then
			Anim.pop(ui.spectateBar)
		else
			Anim.punch(ui.spectateBar.NamePill, 0.1)
		end
	end
end

-- State changes -------------------------------------------------------------------------------

local function onStateChanged()
	local s = state()
	local look = STATE_LOOKS[s] or STATE_LOOKS.Waiting
	ui.title.Text = look.title
	Sprites.set(ui.statusIcon, look.sprite)
	Anim.punch(ui.status, 0.12)

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
	local inRound = s == "Starting" or s == "InRound"
	Anim.setShown(ui.mode, inRound)
	Anim.setShown(ui.alive, inRound)
	if inRound then
		local id = RoundState:GetAttribute("ModeId")
		local mode = if type(id) == "string" then Modes.get(id) else nil
		local modeLook = MODE_LOOKS[if mode then mode.id else "Solo"] or MODE_LOOKS.Solo
		Sprites.set(ui.mode.Row.Icon, modeLook.sprite)
		ui.mode.Row.Label.Text = if mode then string.upper(mode.name) else ""
	end
	lastState = s
	lastSecond = -1
end

local lastAlive = -1
local wasAlive = false

local function render()
	local s = state()
	local left = secondsLeft()

	-- Timer, pulsing red over the last 5 seconds.
	if left >= 0 then
		local whole = math.ceil(left)
		ui.timer.Text = string.format("%d:%02d", whole // 60, whole % 60)
		if whole ~= lastSecond then
			lastSecond = whole
			local urgent = whole <= 5 and (s == "InRound" or s == "Voting")
			ui.timerPill.BackgroundColor3 = if urgent then Color3.fromRGB(255, 80, 80) else Color3.fromRGB(255, 201, 60)
			if urgent then
				Anim.punch(ui.timerPill, 0.15)
			end
			if s == "Starting" and whole >= 1 and whole <= 3 then
				showCountdownNumber(whole)
			end
		end
	else
		ui.timer.Text = "--"
	end
	if s == "Voting" then
		ui.vote.Header.Row.Timer.Text = tostring(math.ceil(math.max(left, 0)))
	elseif s == "Waiting" then
		local message = RoundState:GetAttribute("Message")
		ui.title.Text = if type(message) == "string" and message ~= "" then string.upper(message) else "WAITING"
	end

	-- Chickens left.
	local count = #alivePlayers()
	if count ~= lastAlive then
		lastAlive = count
		ui.alive.Row.Label.Text = `{count} LEFT`
		if ui.alive.Visible then
			Anim.punch(ui.alive, 0.2)
		end
	end

	-- Stamina.
	local alive = player:GetAttribute("Alive") == true
	local inRound = s == "InRound" or s == "Starting"
	Anim.setShown(ui.stamina, inRound and alive)
	local fill = ui.stamina.Track.Fill
	fill.Size = UDim2.fromScale(math.max(0.02, MovementController.getStamina()), 1)
	fill.BackgroundColor3 = if MovementController.isGliding() then Color3.fromRGB(255, 240, 150) else Color3.new(1, 1, 1)

	-- Spectate button for the eliminated.
	local canSpectate = s == "InRound" and not alive and player:GetAttribute("Driver") ~= true
	Anim.setShown(ui.spectateButton, canSpectate)
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
				edge.BackgroundTransparency = 1 - danger * (0.55 + 0.45 * pulse)
			end
		end
	end

	-- You just got eliminated.
	if wasAlive and not alive and (s == "InRound" or s == "Starting") then
		Sfx.play("Eliminated")
		MusicController.duck(2.5)
		flash(Color3.fromRGB(255, 70, 70), 0.4)
	end
	wasAlive = alive
end

function RoundUI.start()
	hud = Gui.screen("Hud")
	ui = {
		status = Gui.find(hud, "Top/Status"),
		statusIcon = Gui.find(hud, "Top/Status/Row/Icon"),
		title = Gui.find(hud, "Top/Status/Row/Title"),
		timerPill = Gui.find(hud, "Top/Status/Row/TimerPill"),
		timer = Gui.find(hud, "Top/Status/Row/TimerPill/Timer"),
		mode = Gui.find(hud, "Top/Info/Mode"),
		alive = Gui.find(hud, "Top/Info/Alive"),
		feed = Gui.find(hud, "Feed"),
		stamina = Gui.find(hud, "Stamina"),
		spectateBar = Gui.find(hud, "SpectateBar"),
		spectateButton = Gui.find(hud, "Side/Small/Spectate"),
		intro = Gui.find(hud, "Intro"),
		countdown = Gui.find(hud, "Countdown"),
		results = Gui.find(hud, "Results"),
		suddenDeath = Gui.find(hud, "SuddenDeath"),
		vote = Gui.find(hud, "Vote"),
		splat = Gui.find(hud, "Splat"),
		danger = Gui.find(hud, "Danger"),
		flash = Gui.find(hud, "Flash"),
	}
	Anim.autoJuice(hud)

	RoundState:GetAttributeChangedSignal("State"):Connect(onStateChanged)
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
	onStateChanged()

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
