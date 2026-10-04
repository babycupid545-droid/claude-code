--!strict
-- Levels and titles, daily quests and the season pass.
--
-- XP comes from game events that RoundService reports (rounds, crossings, knockouts, wins,
-- survival); every XP point also counts as season XP while the season runs. Quests advance from
-- the same events plus egg hits and gliding (sampled here). Clients can only ask to equip a
-- title, reroll a quest or claim a pass tier; everything is checked here first.
--
-- Pure maths (curve, quest rolls, tier checks) is in Shared/Progression.

local Debris = game:GetService("Debris")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Cosmetics = require(Shared.Cosmetics)
local Layout = require(Shared.Layout)
local PlayerData = require(Shared.PlayerData)
local Progression = require(Shared.Progression)
local Remotes = require(Shared.Remotes)
local RoundState = require(Shared.RoundState)

local Kit = require(ReplicatedStorage:WaitForChild("Builders"):WaitForChild("GuiKit")) :: any

local DataService = require(script.Parent.DataService)

local ProgressService = {}

type Data = PlayerData.Data

local P = Config.Progress
local Q = Config.Quests
local S = Config.Season

-- Quest events whose amount is a running total ("best" quests take the best single value).
export type Stat = "Round" | "Crossing" | "Knockout" | "Win" | "EggHit" | "Glide" | "CrossStreak" | "SurviveTime" | "PowerUp" | string

local titleById: { [string]: Progression.TitleDef } = {}
for _, def in P.Titles do
	titleById[def.id] = def
end

-- Per-session state (not saved).
local streaks: { [Player]: number } = {} -- crossings in a row this round
local glideTime: { [Player]: number } = {} -- seconds glided not yet counted
local wasGliding: { [Player]: boolean } = {}
local announced: { [Player]: { [string]: boolean } } = {} -- titles we've already told them about
local lastRequest: { [Player]: number } = {}

local function now(): number
	return os.time()
end

local function seasonRunning(): boolean
	return S.Id ~= "" and now() < S.EndsAt
end

local function statsOf(data: Data): { [string]: number }
	local s = data.Stats
	return { Wins = s.Wins, Knockouts = s.Knockouts, Rounds = s.Rounds, Crossings = s.Crossings }
end

local function levelOf(data: Data): number
	return Progression.level(data.Progress.Xp, P.Curve)
end

local function unlocked(data: Data, def: Progression.TitleDef): boolean
	return Progression.titleUnlocked(def, levelOf(data), statsOf(data), data.Progress.Titles)
end

local function throttled(player: Player, gap: number): boolean
	local t = os.clock()
	if t - (lastRequest[player] or 0) < gap then
		return true
	end
	lastRequest[player] = t
	return false
end

-- Nameplate -------------------------------------------------------------------------------------

-- Level and title for everyone to see (also read by the HUD player board).
local function publish(player: Player, data: Data)
	player:SetAttribute("Level", levelOf(data))
	local def = titleById[data.Progress.Title]
	player:SetAttribute("Title", if def then def.name else "")
end

local T = Kit.Theme

-- A small dark pill above the chicken: a gold level badge and the equipped title.
local function buildNameplate(player: Player, adornee: BasePart): BillboardGui
	local gui = Kit.new("BillboardGui", {
		Name = "Nameplate",
		Adornee = adornee,
		Size = UDim2.fromOffset(220, 30),
		StudsOffsetWorldSpace = Vector3.new(0, if adornee.Name == "Head" then 3.4 else 5, 0),
		MaxDistance = 75,
		LightInfluence = 0,
		ResetOnSpawn = false,
		-- Your own plate would sit in the middle of your view; the HUD shows your level instead.
		PlayerToHideFrom = player,
	})
	local pill = Kit.new("Frame", {
		Name = "Pill",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = T.Dark,
		BackgroundTransparency = 0.15,
		Parent = gui,
	}, {
		Kit.corner(13),
		Kit.stroke(T.Gold, 1.5, 0.15),
		Kit.new("UIPadding", { PaddingLeft = UDim.new(0, 3), PaddingRight = UDim.new(0, 10) }),
		Kit.list("H", 6, "Center", "Center"),
	})
	local badge = Kit.new("Frame", {
		Name = "Badge",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(28, 20),
		BackgroundColor3 = T.Gold,
		Parent = pill,
	}, { Kit.corner(10), Kit.sheen(0.25) })
	Kit.text("Level", "1", 14, {
		Size = UDim2.fromScale(1, 1),
		TextColor3 = T.Dark,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = badge,
	})
	Kit.text("Title", "", 15, {
		LayoutOrder = 2,
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		TextColor3 = T.Text,
		Parent = pill,
	})
	return gui
end

local plates: { [Player]: BillboardGui } = {}

local function refreshPlate(player: Player)
	local gui = plates[player]
	if not gui or not gui.Parent then
		return
	end
	local level = player:GetAttribute("Level")
	local title = player:GetAttribute("Title")
	local pill = gui:FindFirstChild("Pill") :: any
	pill.Badge.Level.Text = tostring(if type(level) == "number" then level else 1)
	local text = if type(title) == "string" then title else ""
	pill.Title.Text = text
	pill.Title.Visible = text ~= ""
	-- With no title the pill is just the badge.
	pill.UIPadding.PaddingRight = UDim.new(0, if text ~= "" then 10 else 3)
end

local function attachPlate(player: Player, character: Model)
	local adornee = (character:WaitForChild("Head", 5) or character:FindFirstChild("HumanoidRootPart")) :: BasePart?
	if not adornee or player.Character ~= character then
		return
	end
	local gui = buildNameplate(player, adornee)
	gui.Parent = character
	plates[player] = gui
	refreshPlate(player)
end

-- A burst of golden sparkles around the chicken (everyone sees it).
local function celebrate(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "LevelUpFx"
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 230, 120), Color3.fromRGB(255, 170, 40))
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
	emitter.Lifetime = NumberRange.new(0.7, 1.2)
	emitter.Speed = NumberRange.new(10, 18)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, -12, 0)
	emitter.Rate = 140
	emitter.Parent = attachment
	attachment.Parent = root
	task.delay(0.35, function()
		emitter.Enabled = false
	end)
	Debris:AddItem(attachment, 2)
end

-- Titles ----------------------------------------------------------------------------------------

-- Tells the player about titles unlocked since we last looked (level, stats or the pass).
local function announceTitles(player: Player, data: Data, quiet: boolean?): { string }
	local seen = announced[player]
	if not seen then
		seen = {}
		announced[player] = seen
	end
	local fresh = {}
	for _, def in P.Titles do
		if not seen[def.id] and unlocked(data, def) then
			seen[def.id] = true
			table.insert(fresh, def.name)
			if not quiet and not def.level then
				Remotes.Notify:FireClient(player, `New title: {def.name}!`, "unlock", 0)
			end
		end
	end
	return fresh
end

-- XP ------------------------------------------------------------------------------------------------

local function ensureSeason(data: Data): boolean
	local season, changed = Progression.seasonFor(data.Season, S.Id)
	data.Season = season
	return changed
end

-- Adds XP (and season XP), handling level-ups. Doesn't sync; callers do.
local function giveXp(player: Player, data: Data, amount: number)
	amount = math.floor(amount)
	if amount <= 0 then
		return
	end
	local before = levelOf(data)
	data.Progress.Xp += amount
	if seasonRunning() then
		ensureSeason(data)
		data.Season.Xp += amount
	end
	local after = levelOf(data)
	Remotes.XpGain:FireClient(player, amount)
	if after > before then
		local coins = 0
		for level = before + 1, after do
			coins += Progression.levelUpCoins(level, P.LevelUpCoins)
		end
		data.Coins += coins
		publish(player, data)
		refreshPlate(player)
		local titles = announceTitles(player, data, true)
		Remotes.LevelUp:FireClient(player, after, coins, titles)
		celebrate(player)
		if after % 5 == 0 then
			Remotes.Feed:FireAllClients(`{player.DisplayName} reached level {after}!`, "star")
		end
	end
end

-- Quests ------------------------------------------------------------------------------------------

-- New quests at midnight UTC (and repairs saved quests). Returns whether they changed.
local function refreshQuests(player: Player, data: Data): boolean
	local quests, changed = Progression.refreshQuests(data.Quests, Q.Pool, Q.Count, Progression.day(now()), player.UserId)
	data.Quests = quests
	return changed
end

-- Advances matching quests; finished ones pay out at once. Doesn't sync; returns whether
-- anything changed.
local function advanceQuests(player: Player, data: Data, stat: string, amount: number): boolean
	if refreshQuests(player, data) then
		Remotes.Notify:FireClient(player, "New daily quests!", "info", 0)
	end
	local changed = false
	for _, quest in data.Quests.List do
		local def = Progression.findQuest(Q.Pool, quest.Id)
		if def and def.stat == stat then
			local moved, done = Progression.advance(quest, def, amount)
			changed = changed or moved
			if done then
				data.Coins += def.coins
				Remotes.Notify:FireClient(player, `Quest done: {def.text}! +{def.coins} eggs`, "unlock", def.coins)
				giveXp(player, data, def.xp)
			end
		end
	end
	return changed
end

-- Public API -------------------------------------------------------------------------------------

-- Gives XP for `reason` (shown on the client as a little "+N XP").
function ProgressService.addXp(player: Player, amount: number)
	local data = DataService.get(player)
	if data and amount > 0 then
		giveXp(player, data, amount)
		DataService.sync(player)
	end
end

-- Counts a game event towards daily quests, e.g. record(player, "PowerUp", 1).
function ProgressService.record(player: Player, stat: Stat, amount: number)
	local data = DataService.get(player)
	if data and advanceQuests(player, data, stat, amount) then
		DataService.sync(player)
	end
end

local function award(player: Player, xp: number, stat: Stat?, amount: number?)
	local data = DataService.get(player)
	if not data then
		return
	end
	if stat then
		advanceQuests(player, data, stat, amount or 1)
	end
	giveXp(player, data, xp)
	announceTitles(player, data)
	DataService.sync(player)
end

-- RoundService hooks.

function ProgressService.roundPlayed(player: Player)
	award(player, P.Xp.Round, "Round", 1)
end

function ProgressService.won(player: Player, teams: boolean)
	award(player, if teams then P.Xp.TeamWin else P.Xp.Win, "Win", 1)
end

function ProgressService.knockout(shooter: Player)
	award(shooter, P.Xp.Knockout, "Knockout", 1)
end

function ProgressService.eggHit(shooter: Player)
	ProgressService.record(shooter, "EggHit", 1)
end

-- When a chicken's round ends (eliminated or survived): survival XP and the survive quest.
function ProgressService.survived(player: Player, seconds: number)
	local data = DataService.get(player)
	if not data then
		return
	end
	advanceQuests(player, data, "SurviveTime", math.floor(seconds))
	giveXp(player, data, math.floor(seconds / P.Xp.SurviveEvery) * P.Xp.Survive)
	DataService.sync(player)
end

-- A crossing phase ended (the side dropped, or everyone made it): the chickens in `alive`
-- standing on `target` made the crossing; the rest lose their streak.
function ProgressService.crossingDone(alive: { Player }, target: string)
	for _, player in alive do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local data = DataService.get(player)
		if not root or Layout.zoneOf(root.Position.Z) ~= target then
			streaks[player] = 0
		elseif data then
			data.Stats.Crossings += 1
			local streak = (streaks[player] or 0) + 1
			streaks[player] = streak
			advanceQuests(player, data, "Crossing", 1)
			advanceQuests(player, data, "CrossStreak", streak)
			giveXp(player, data, P.Xp.Crossing)
			announceTitles(player, data)
			DataService.sync(player)
		end
	end
end

-- Requests from clients ----------------------------------------------------------------------------

local function onEquipTitle(player: Player, id: unknown)
	if type(id) ~= "string" or throttled(player, 0.25) then
		return
	end
	local data = DataService.get(player)
	if not data or data.Progress.Title == id then
		return
	end
	if id ~= "" then
		local def = titleById[id]
		if not def or not unlocked(data, def) then
			return
		end
	end
	data.Progress.Title = id
	publish(player, data)
	refreshPlate(player)
	DataService.sync(player)
end

local function onRerollQuest(player: Player, index: unknown)
	if type(index) ~= "number" or throttled(player, 0.5) then
		return
	end
	local data = DataService.get(player)
	if not data then
		return
	end
	if refreshQuests(player, data) then
		-- The day rolled over; they get fresh quests (and a fresh reroll) anyway.
		DataService.sync(player)
		return
	end
	local quests = data.Quests
	local quest = quests.List[index]
	if not quest or quest.Done then
		return
	end
	if quests.Rerolls >= Q.FreeRerolls then
		Remotes.Notify:FireClient(player, "No rerolls left today. New quests at midnight!", "error", 0)
		return
	end
	local ids = {}
	for _, q in quests.List do
		table.insert(ids, q.Id)
	end
	local seed = Progression.questSeed(player.UserId, quests.Day, quests.Rerolls + 1)
	local id = Progression.rerollQuest(Q.Pool, ids, seed)
	if not id then
		Remotes.Notify:FireClient(player, "No other quests to swap in!", "error", 0)
		return
	end
	quests.List[index] = { Id = id, Progress = 0, Done = false }
	quests.Rerolls += 1
	DataService.sync(player)
end

local function onClaimTier(player: Player, track: unknown, tier: unknown)
	if throttled(player, 0.2) then
		return
	end
	local data = DataService.get(player)
	if not data then
		return
	end
	ensureSeason(data)
	local reward, key = Progression.checkClaim(data.Season, S, track, tier)
	if not reward then
		if key == "premium" then
			Remotes.Notify:FireClient(player, "That reward needs the premium pass.", "error", 0)
		end
		return
	end
	data.Season.Claimed[key] = true
	if reward.coins then
		data.Coins += reward.coins
		Remotes.Notify:FireClient(player, `+{reward.coins} golden eggs!`, "coin", reward.coins)
	end
	local item = Cosmetics.get(reward.item)
	if item then
		if PlayerData.owns(data.Owned, item.id) then
			data.Coins += S.DuplicateCoins
			Remotes.Notify:FireClient(player, `Already had {item.name}: +{S.DuplicateCoins} eggs`, "coin", S.DuplicateCoins)
		else
			data.Owned[item.id] = true
			Remotes.Notify:FireClient(player, `Unlocked {item.name}! Equip it in the shop.`, "unlock", 0)
		end
	end
	local title = reward.title and titleById[reward.title]
	if title then
		data.Progress.Titles[title.id] = true
		announceTitles(player, data)
	end
	DataService.sync(player)
end

-- Loading ------------------------------------------------------------------------------------------

-- Repairs progression data on load (older saves, removed quests/titles, a new season).
local function prepare(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local progress = data.Progress
	if type(progress.Xp) ~= "number" or progress.Xp ~= progress.Xp or progress.Xp < 0 then
		progress.Xp = 0
	end
	progress.Xp = math.floor(progress.Xp)
	if type(data.Stats.Crossings) ~= "number" then
		data.Stats.Crossings = 0
	end
	refreshQuests(player, data)
	ensureSeason(data)
	local def = titleById[progress.Title]
	if progress.Title ~= "" and (not def or not unlocked(data, def)) then
		progress.Title = ""
	end
	-- Everything already unlocked counts as announced.
	announced[player] = nil
	announceTitles(player, data, true)
	publish(player, data)
	DataService.sync(player)

	if Config.Monetization.SeasonPassId ~= 0 and not data.Season.Premium then
		local ok, owns = pcall(
			MarketplaceService.UserOwnsGamePassAsync,
			MarketplaceService,
			player.UserId,
			Config.Monetization.SeasonPassId
		)
		if ok and owns == true and DataService.get(player) == data then
			data.Season.Premium = true
			DataService.sync(player)
		end
	end
end

-- Gliding is client physics, so it's estimated here: a chicken falling at the glide speed for
-- two samples in a row is gliding (a normal fall passes that speed in a blink).
local SAMPLE = 0.1
local function sampleGliding()
	local inRound = RoundState:GetAttribute("State") == "InRound"
	local target = -Config.Chicken.GlideFallSpeed
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local gliding = false
		if inRound and root and player:GetAttribute("Alive") == true then
			local vy = root.AssemblyLinearVelocity.Y
			gliding = math.abs(vy - target) < 1.5
		end
		if gliding and wasGliding[player] then
			local total = (glideTime[player] or 0) + SAMPLE
			if total >= 1 then
				local whole = math.floor(total)
				total -= whole
				ProgressService.record(player, "Glide", whole)
			end
			glideTime[player] = total
		end
		wasGliding[player] = gliding
	end
end

function ProgressService.init()
	Remotes.EquipTitle.OnServerEvent:Connect(onEquipTitle)
	Remotes.RerollQuest.OnServerEvent:Connect(onRerollQuest)
	Remotes.ClaimTier.OnServerEvent:Connect(onClaimTier)

	DataService.Loaded:Connect(prepare)
	for _, player in Players:GetPlayers() do
		if DataService.get(player) then
			task.spawn(prepare, player)
		end
	end

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			attachPlate(player, character)
		end)
		player:GetAttributeChangedSignal("Level"):Connect(function()
			refreshPlate(player)
		end)
		player:GetAttributeChangedSignal("Title"):Connect(function()
			refreshPlate(player)
		end)
		if player.Character then
			task.spawn(attachPlate, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		streaks[player] = nil
		glideTime[player] = nil
		wasGliding[player] = nil
		announced[player] = nil
		lastRequest[player] = nil
		plates[player] = nil
	end)

	-- A new round starts every streak from zero.
	RoundState:GetAttributeChangedSignal("State"):Connect(function()
		if RoundState:GetAttribute("State") == "Starting" then
			table.clear(streaks)
		end
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local id = Config.Monetization.SeasonPassId
		if not purchased or id == 0 or passId ~= id then
			return
		end
		local data = DataService.get(player)
		if data then
			ensureSeason(data)
			data.Season.Premium = true
			DataService.sync(player)
			Remotes.Notify:FireClient(player, "Premium pass unlocked! Claim your rewards.", "unlock", 0)
		end
	end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= SAMPLE then
			acc = 0
			sampleGliding()
		end
	end)

	-- Quests reset at midnight UTC for players who are online through it.
	task.spawn(function()
		while true do
			task.wait(30)
			local day = Progression.day(now())
			for _, player in Players:GetPlayers() do
				local data = DataService.get(player)
				if data and data.Quests.Day ~= day then
					refreshQuests(player, data)
					DataService.sync(player)
					Remotes.Notify:FireClient(player, "New daily quests!", "info", 0)
				end
			end
		end
	end)
end

return ProgressService
