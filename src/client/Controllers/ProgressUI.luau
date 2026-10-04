--!strict
-- The Progress window (opened with the HUD's PASS button): LEVEL (level, XP, titles to equip),
-- QUESTS (today's three quests, one free swap) and PASS (the season track with free and
-- premium rewards). Also the level tag on the PASS button, "+XP" pops and the level-up moment.
--
-- Uses the Progress ScreenGui (src/builders/ProgressGui.luau). Everything shown comes from the
-- server's DataSync; buttons only send requests, which the server checks.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Cosmetics = require(Shared.Cosmetics)
local PlayerData = require(Shared.PlayerData)
local Progression = require(Shared.Progression)
local Remotes = require(Shared.Remotes)

local Anim = require(script.Parent.Parent.Anim)
local CameraFx = require(script.Parent.Parent.CameraFx)
local ClientData = require(script.Parent.Parent.ClientData)
local Gui = require(script.Parent.Parent.Gui)
local Sfx = require(script.Parent.Parent.Sfx)
local Sprites = require(script.Parent.Parent.Sprites)

local ProgressUI = {}

local player = Players.LocalPlayer

local rgb = Color3.fromRGB
local GREEN = rgb(110, 200, 84)
local GREY = rgb(150, 138, 126)
local ORANGE = rgb(255, 156, 46)
local PINK = rgb(255, 110, 170)
local BLUE = rgb(76, 164, 236)
local YELLOW = rgb(255, 204, 64)
local DARK = rgb(44, 29, 20)
local INK = rgb(74, 46, 28)
local INK_SOFT = rgb(140, 104, 76)

local SLOT_SPRITES: { [string]: string } = {
	ChickenSkin = "chicken",
	EggSkin = "egg",
	HitEffect = "boom",
	WinEffect = "trophy",
	Emote = "emote",
}

local P = Config.Progress
local Q = Config.Quests
local S = Config.Season

type Snapshot = PlayerData.Snapshot

local screen: ScreenGui
local hud: ScreenGui
local ui: { [string]: any } = {}
local currentTab = "Level"
local columns: { any } = {}
local passPrice: number? = nil
local shownLevel: number? = nil
local levelUps: { { level: number, coins: number, titles: { string } } } = {}
local showingLevelUp = false

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function darkButton(button: any)
	local inner = button.Border.Inner
	inner.BackgroundColor3 = DARK
	inner.BackgroundTransparency = 0.08
	inner:SetAttribute("Accent", nil)
end

local function commas(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

local function levelInfo(data: Snapshot): (number, number, number)
	return Progression.levelInfo(data.progress.Xp, P.Curve)
end

local function statsOf(data: Snapshot): { [string]: number }
	local s = data.stats
	return { Wins = s.Wins, Knockouts = s.Knockouts, Rounds = s.Rounds, Crossings = s.Crossings or 0 }
end

local function season(data: Snapshot): Progression.SeasonState
	local state = data.season
	if state and state.Id == S.Id then
		return state
	end
	return { Id = S.Id, Xp = 0, Claimed = {}, Premium = false }
end

local function titleName(id: string): string?
	for _, def in P.Titles do
		if def.id == id then
			return def.name
		end
	end
	return nil
end

-- What a pass reward looks like: icon, tint, label.
local function rewardLook(reward: Progression.Reward): (string, Color3, string)
	if reward.coins then
		return "eggCoin", Color3.new(1, 1, 1), `+{reward.coins}`
	end
	local item = Cosmetics.get(reward.item)
	if item then
		local tint = if item.look.colors then item.look.colors[1]:Lerp(Color3.new(1, 1, 1), 0.35) else Color3.new(1, 1, 1)
		return SLOT_SPRITES[item.slot] or "gift", tint, item.name
	end
	return "rosette", Color3.new(1, 1, 1), `"{titleName(reward.title or "") or "Title"}"`
end

local function rewardText(reward: Progression.Reward?): string
	if not reward then
		return ""
	end
	if reward.coins then
		return `+{reward.coins} eggs`
	end
	local item = Cosmetics.get(reward.item)
	if item then
		return item.name
	end
	return `{titleName(reward.title or "") or "a title"} title`
end

-- HUD -------------------------------------------------------------------------------------------

local function renderHud(data: Snapshot)
	local level = levelInfo(data)
	ui.passLevel.Text = tostring(level)
	if shownLevel and level > shownLevel then
		Anim.punch(ui.passButton, 0.2)
	end
	shownLevel = level
	local claimable = Progression.unclaimed(season(data), S) > 0
	ui.passAlert.Visible = claimable
	ui.tabs.Pass.Alert.Visible = claimable
end

-- "+25 XP" rising from the PASS button.
local function showXpPop(amount: number)
	local label = Instance.new("TextLabel")
	label.Name = "XpPop"
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 0, -2)
	label.Size = UDim2.fromOffset(90, 20)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextSize = 17
	label.TextColor3 = YELLOW
	label.Text = `+{amount} XP`
	label.ZIndex = 10
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = DARK
	stroke.Parent = label
	label.Parent = ui.passButton
	Anim.tween(label, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0, -34) })
	task.delay(0.6, function()
		Anim.tween(label, 0.5, { TextTransparency = 1 })
		Anim.tween(stroke, 0.5, { Transparency = 1 })
	end)
	task.delay(1.2, function()
		label:Destroy()
	end)
	Anim.punch(ui.passTag, 0.25)
end

-- Several gains at once (round end) rise one after another.
local nextPopAt = 0
local function xpPop(amount: number)
	local t = os.clock()
	local at = math.max(t, nextPopAt)
	nextPopAt = at + 0.3
	if at > t then
		task.delay(at - t, showXpPop, amount)
	else
		showXpPop(amount)
	end
end

-- Level-up moment -------------------------------------------------------------------------------

local function nextLevelUp()
	local item = table.remove(levelUps, 1)
	if not item then
		showingLevelUp = false
		return
	end
	showingLevelUp = true
	local frame = ui.levelUp
	frame.Number.Text = tostring(item.level)
	frame.Card.Inner.Sub.Text = if #item.titles > 0
		then `New title: {table.concat(item.titles, ", ")}!`
		else `You reached level {item.level}!`
	frame.Card.Inner.Reward.Label.Text = `+{item.coins}`
	frame.Card.Inner.Reward.Visible = item.coins > 0
	Anim.pop(frame)
	Sfx.play("Fanfare")
	Sfx.play("Sparkle")
	CameraFx.fovPunch(4)
	task.delay(0.35, function()
		Anim.punch(frame.Star, 0.25)
	end)
	task.delay(2.8, function()
		Anim.hide(frame, nextLevelUp)
	end)
end

local function onLevelUp(level: number, coins: number, titles: { string })
	table.insert(levelUps, { level = level, coins = coins, titles = titles })
	if not showingLevelUp then
		nextLevelUp()
	end
end

-- LEVEL tab ---------------------------------------------------------------------------------------

local function renderLevel(data: Snapshot)
	local page = ui.pages.Level
	local summary = page.Summary.Inner
	local level, into, need = levelInfo(data)
	summary.Number.Text = tostring(level)
	summary.LevelText.Text = `LEVEL {level}`
	summary.TitleText.Text = titleName(data.progress.Title) or "No title"
	if need > 0 then
		summary.XpBar.Fill.Size = UDim2.fromScale(math.max(0.03, into / need), 1)
		summary.XpBar.Text.Text = `{commas(into)} / {commas(need)} XP`
		summary.Next.Label.Text = `+{Progression.levelUpCoins(level + 1, P.LevelUpCoins)} eggs at level {level + 1}`
		summary.Next.Visible = true
	else
		summary.XpBar.Fill.Size = UDim2.fromScale(1, 1)
		summary.XpBar.Text.Text = "MAX LEVEL"
		summary.Next.Visible = false
	end
	local stats = statsOf(data)
	for name, value in stats do
		local cell = summary.Stats:FindFirstChild(name)
		if cell then
			cell.Value.Text = commas(value)
		end
	end

	local list = page.TitleList
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local unlockedCount = 0
	for i, def in P.Titles do
		local row = Gui.template(screen, "TitleRow")
		local open = Progression.titleUnlocked(def, level, stats, data.progress.Titles)
		local equipped = data.progress.Title == def.id
		row.LayoutOrder = i
		row.TitleName.Text = def.name
		row.TitleName.TextColor3 = if open then INK else INK_SOFT
		local requirement = Progression.titleRequirement(def)
		if not open and def.stat then
			requirement = `{commas(math.min(stats[def.stat] or 0, def.goal or 0))} / {requirement}`
		end
		row.Requirement.Text = requirement
		row.Icon.ImageTransparency = if open then 0 else 0.55
		row.Lock.Visible = not open
		row.Action.Visible = open
		row.BackgroundColor3 = if equipped then rgb(226, 246, 206) elseif open then rgb(244, 230, 204) else rgb(236, 226, 210)
		row.UIStroke.Color = if equipped then GREEN else rgb(236, 178, 86)
		row.UIStroke.Transparency = if equipped then 0 else 0.35
		row.UIStroke.Thickness = if equipped then 2.5 else 1.5
		if open then
			unlockedCount += 1
			Gui.setButton(row.Action, if equipped then "WORN" else "WEAR", if equipped then GREY else GREEN)
			row.Action.Activated:Connect(function()
				Remotes.EquipTitle:FireServer(if equipped then "" else def.id)
				Sfx.play("Equip")
				Anim.punch(row, 0.05)
			end)
			Anim.juice(row.Action)
		end
		row.Parent = list
	end
	page.TitlesCount.Text = `{unlockedCount} / {#P.Titles} UNLOCKED`
end

-- QUESTS tab --------------------------------------------------------------------------------------

local function renderQuestTimer(data: Snapshot)
	local page = ui.pages.Quests
	page.Top.Timer.Text = `NEW QUESTS IN {Progression.formatDuration(Progression.secondsToReset(serverNow()))}`
	local left = math.max(0, Q.FreeRerolls - data.quests.Rerolls)
	page.Top.Rerolls.Label.Text = if left > 0 then `{left} FREE SWAP TODAY` else "NO SWAPS LEFT TODAY"
end

local function renderQuests(data: Snapshot, animate: boolean)
	local page = ui.pages.Quests
	renderQuestTimer(data)
	local cards = page.Cards
	for _, child in cards:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local today = Progression.day(serverNow())
	local stale = data.quests.Day ~= today
	local swapsLeft = Q.FreeRerolls - data.quests.Rerolls
	for i, quest in data.quests.List do
		local def = Progression.findQuest(Q.Pool, quest.Id)
		if def then
			local card = Gui.template(screen, "QuestCard")
			local inner = card.Inner
			card.LayoutOrder = i
			local color = if quest.Done then GREEN else ORANGE
			inner.Band.BackgroundColor3 = color
			inner.Bar.Fill.BackgroundColor3 = color
			Sprites.set(inner.Icon, def.icon)
			inner.QuestName.Text = def.text
			local progress = math.min(quest.Progress, def.goal)
			inner.Bar.Fill.Size = UDim2.fromScale(math.max(0.03, progress / def.goal), 1)
			inner.Bar.Text.Text = if quest.Done then "COMPLETE!" else `{progress} / {def.goal}`
			inner.Rewards.Coins.Label.Text = `+{def.coins}`
			inner.Rewards.Xp.Label.Text = `+{def.xp} XP`
			card.Done.Visible = quest.Done
			local action = inner.Action
			if quest.Done then
				Gui.setButton(action, "REWARD COLLECTED", GREY, "check")
			elseif swapsLeft > 0 and not stale then
				Gui.setButton(action, "SWAP QUEST", BLUE, "")
				action.Activated:Connect(function()
					Remotes.RerollQuest:FireServer(i)
					Sfx.play("UiClick")
					Anim.shake(card, 4, 0.25)
				end)
				Anim.juice(action)
			else
				action.Visible = false
			end
			card.Parent = cards
			if animate then
				Anim.pop(card, 0.05 * i)
			end
		end
	end
end

-- PASS tab ----------------------------------------------------------------------------------------

local function premiumButton(state: Progression.SeasonState)
	local button = ui.premium
	local id = Config.Monetization.SeasonPassId
	if state.Premium then
		Gui.setButton(button, "OWNED", GREEN, "check")
	elseif id == 0 then
		Gui.setButton(button, "SOON", GREY, "crown")
	elseif passPrice then
		Gui.setButton(button, `R$ {passPrice}`, PINK, "crown")
	else
		Gui.setButton(button, "R$ ...", PINK, "crown")
	end
end

local function fetchPassPrice()
	local id = Config.Monetization.SeasonPassId
	if id == 0 then
		return
	end
	task.spawn(function()
		local ok, info = pcall(MarketplaceService.GetProductInfoAsync, MarketplaceService, id, Enum.InfoType.GamePass)
		if ok and info and type(info.PriceInRobux) == "number" then
			passPrice = info.PriceInRobux
			local data = ClientData.get()
			if data then
				premiumButton(season(data))
			end
		end
	end)
end

local function renderSeasonTimer()
	local left = S.EndsAt - serverNow()
	ui.pages.Pass.Season.Inner.Timer.Label.Text = if left > 0 then `Ends in {Progression.formatDuration(left)}` else "Season over"
end

local function styleCell(cell: any, reward: Progression.Reward?, reached: boolean, claimed: boolean, locked: boolean, track: "free" | "premium", tier: number)
	cell.Claim.Visible = false
	cell.Lock.Visible = false
	cell.Check.Visible = false
	if not reward then
		cell.BackgroundTransparency = 0.85
		cell.UIStroke.Transparency = 0.8
		cell.Icon.Visible = false
		cell.Glow.Visible = false
		cell.Label.Text = ""
		return
	end
	local sprite, tint, label = rewardLook(reward)
	cell.BackgroundTransparency = 0
	cell.UIStroke.Transparency = 0.1
	cell.Icon.Visible = true
	cell.Glow.Visible = reward.coins == nil
	Sprites.set(cell.Icon, sprite)
	cell.Icon.ImageColor3 = tint
	cell.Label.Text = label
	local faded = claimed or not reached or locked
	cell.Icon.ImageTransparency = if claimed then 0.5 else 0
	cell.Label.TextColor3 = if faded then INK_SOFT else INK
	if claimed then
		cell.Check.Visible = true
	elseif not reached or locked then
		cell.Lock.Visible = true
	else
		cell.Claim.Visible = true
		Gui.setButton(cell.Claim, "CLAIM", GREEN)
	end
	cell:SetAttribute("Track", track)
	cell:SetAttribute("Tier", tier)
end

local function buildTrack()
	local track = ui.pages.Pass.TrackArea.Track
	for _, child in track:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	table.clear(columns)
	for tier = 1, S.Tiers do
		local column = Gui.template(screen, "TierColumn")
		column.LayoutOrder = tier
		column.Name = `Tier{tier}`
		column.Head.Num.Text = tostring(tier)
		for _, lane in { "free", "premium" } do
			local cell = if lane == "free" then column.Free else column.Premium
			cell.Claim.Activated:Connect(function()
				Remotes.ClaimTier:FireServer(lane, tier)
				Sfx.play("Coin")
				Anim.punch(cell, 0.1)
			end)
			Anim.juice(cell.Claim)
		end
		column.Parent = track
		columns[tier] = column
	end
end

local function renderPass(data: Snapshot, scrollToCurrent: boolean)
	local page = ui.pages.Pass
	local state = season(data)
	local tier, into, need = Progression.tierInfo(state.Xp, S.XpPerTier, S.Tiers)
	local banner = page.Season.Inner
	banner.SeasonLabel.Text = `SEASON {S.Number}`
	banner.SeasonName.Text = string.upper(S.Name)
	banner.Tier.Text = `TIER {tier}`
	if need > 0 then
		banner.TierXp.Text = `{commas(into)} / {commas(need)} XP`
		banner.TierBar.Fill.Size = UDim2.fromScale(math.max(0.03, into / need), 1)
		local nextFree, nextPremium = S.Free[tier + 1], S.Premium[tier + 1]
		local nextReward = if nextFree then nextFree else nextPremium
		banner.NextTier.Text = if nextReward then `Next tier: {rewardText(nextReward)}` else ""
	else
		banner.TierXp.Text = "ALL TIERS DONE!"
		banner.TierBar.Fill.Size = UDim2.fromScale(1, 1)
		banner.NextTier.Text = ""
	end
	renderSeasonTimer()
	premiumButton(state)

	if #columns == 0 then
		buildTrack()
	end
	for t, column in columns do
		local reached = t <= tier
		column.Head.BackgroundColor3 = if reached then ORANGE else DARK
		column.Head.Num.TextColor3 = if reached then Color3.new(1, 1, 1) else rgb(226, 206, 178)
		-- The line fills up to the current tier, and part-way into the next one.
		local fill = if reached then 1 elseif t == tier + 1 and need > 0 then into / need else 0
		column.Line.Fill.Size = UDim2.fromScale(fill, 1)
		column.Line.Fill.Visible = fill > 0
		styleCell(column.Free, S.Free[t], reached, state.Claimed[Progression.claimKey("free", t)] == true, false, "free", t)
		styleCell(column.Premium, S.Premium[t], reached, state.Claimed[Progression.claimKey("premium", t)] == true, not state.Premium, "premium", t)
	end
	if scrollToCurrent then
		-- Show the current tier near the left, with one claimed tier before it for context.
		local track = page.TrackArea.Track
		local first = math.max(0, tier - 1)
		for t = 1, tier do
			if (S.Free[t] and not state.Claimed[Progression.claimKey("free", t)])
				or (state.Premium and S.Premium[t] and not state.Claimed[Progression.claimKey("premium", t)])
			then
				first = t - 1
				break
			end
		end
		track.CanvasPosition = Vector2.new(math.max(0, first - 1) * 112, 0)
	end
end

-- Window -----------------------------------------------------------------------------------------

-- `fresh`: the window or tab was just opened (animate cards, scroll the pass to your tier).
local function render(fresh: boolean?)
	local data = ClientData.get()
	if not data or not data.progress then
		return
	end
	renderHud(data)
	if not ui.panel.Visible then
		return
	end
	ui.coins.Text = commas(data.coins)
	for name, tab in ui.tabs do
		ui.pages[name].Visible = name == currentTab
		if name == currentTab then
			Gui.setButton(tab, nil, ORANGE)
		else
			darkButton(tab)
		end
	end
	if currentTab == "Level" then
		renderLevel(data)
	elseif currentTab == "Quests" then
		renderQuests(data, fresh == true)
	else
		renderPass(data, fresh == true)
	end
end

local shopPanel: GuiObject?
local shopDim: GuiObject?

local function close()
	if not ui.panel.Visible then
		return
	end
	Anim.tween(ui.dim, 0.2, { BackgroundTransparency = 1 }).Completed:Once(function(s)
		if s == Enum.PlaybackState.Completed then
			ui.dim.Visible = false
		end
	end)
	Anim.hide(ui.panel)
	Sfx.play("UiClose")
end

local function open(tab: string?)
	if tab then
		currentTab = tab
	end
	-- One window at a time: put the shop away.
	if shopPanel and shopPanel.Visible then
		Anim.hide(shopPanel)
		if shopDim then
			shopDim.Visible = false
		end
	end
	ui.dim.Visible = true
	ui.dim.BackgroundTransparency = 1
	Anim.tween(ui.dim, 0.25, { BackgroundTransparency = 0.45 })
	Anim.pop(ui.panel)
	Sfx.play("UiOpen")
	render(true)
end

function ProgressUI.open(tab: string?)
	open(tab)
end

-- Start ------------------------------------------------------------------------------------------

function ProgressUI.start()
	screen = Gui.screen("Progress")
	hud = Gui.screen("Hud")
	local root = Gui.find(screen, "Root")
	ui = {
		dim = Gui.find(root, "Dim"),
		panel = Gui.find(root, "Panel"),
		coins = Gui.find(root, "Panel/Inner/Header/Coins/Label"),
		close = Gui.find(root, "Panel/Inner/Header/Close"),
		pages = {
			Level = Gui.find(root, "Panel/Inner/Pages/Level"),
			Quests = Gui.find(root, "Panel/Inner/Pages/Quests"),
			Pass = Gui.find(root, "Panel/Inner/Pages/Pass"),
		},
		tabs = {},
		premium = Gui.find(root, "Panel/Inner/Pages/Pass/Season/Inner/Premium"),
		levelUp = Gui.find(root, "LevelUp"),
		passButton = Gui.find(hud, "Root/Buttons/Pass"),
		passTag = Gui.find(hud, "Root/Buttons/Pass/Level"),
		passLevel = Gui.find(hud, "Root/Buttons/Pass/Level/Label"),
		passAlert = Gui.find(hud, "Root/Buttons/Pass/Alert"),
	}
	for _, name in { "Level", "Quests", "Pass" } do
		local tab = Gui.find(root, `Panel/Inner/Tabs/{name}`)
		ui.tabs[name] = tab
		tab.Activated:Connect(function()
			if currentTab ~= name then
				currentTab = name
				render(true)
			end
		end)
	end
	if Gui.isTouch() then
		-- The touch layout has less height to spare; centre the window exactly.
		ui.panel.Position = UDim2.fromScale(0.5, 0.5)
		ui.levelUp.Position = UDim2.fromScale(0.5, 0.4)
	end
	Anim.autoJuice(screen)

	ui.passButton.Activated:Connect(function()
		if ui.panel.Visible then
			close()
		else
			open()
		end
	end)
	ui.close.Activated:Connect(close)
	ui.dim.Activated:Connect(close)
	ui.premium.Activated:Connect(function()
		local data = ClientData.get()
		local id = Config.Monetization.SeasonPassId
		if id ~= 0 and data and not season(data).Premium then
			MarketplaceService:PromptGamePassPurchase(player, id)
		elseif id == 0 then
			Sfx.play("Error")
			Anim.shake(ui.premium, 5, 0.3)
		end
	end)

	-- Close when the shop opens (and the other way round, in open()).
	task.spawn(function()
		local shop = Gui.screen("Shop")
		shopPanel = Gui.find(shop, "Root/Panel")
		shopDim = Gui.find(shop, "Root/Dim")
		local panel = shopPanel :: GuiObject
		panel:GetPropertyChangedSignal("Visible"):Connect(function()
			if panel.Visible then
				close()
			end
		end)
	end)

	ClientData.Changed:Connect(function()
		render(false)
	end)
	Remotes.XpGain.OnClientEvent:Connect(xpPop)
	Remotes.LevelUp.OnClientEvent:Connect(onLevelUp)
	fetchPassPrice()
	render(false)

	-- Countdowns.
	task.spawn(function()
		while true do
			task.wait(1)
			local data = ClientData.get()
			if data and data.quests and ui.panel.Visible then
				if currentTab == "Quests" then
					renderQuestTimer(data)
				elseif currentTab == "Pass" then
					renderSeasonTimer()
				end
			end
		end
	end)
end

return ProgressUI
