"""Renders preview screenshots of the GUI built by src/builders/GuiBuilder.luau, without Studio.

Runs the builder in the fake engine (tools/preview/mock.luau), sets up a few game states the
way the client scripts would, dumps the instance tree as JSON and lays it out / draws it with
a small reimplementation of Roblox's UI layout rules.

Usage: python3 tools/preview/render_gui.py <scenario> <out.png> --luau <luau> --fonts <dir>
       scenarios: vote, round, go, intro, results, shop, emotes, afk, driver, level, quests, pass, levelup
"""

import json
import math
import os
import re
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SPRITES = {}
# The preview shows every sheet as if uploaded (later sheets win: the clean icon set beats the
# farm sheet, which beats the original sheet, like SpriteSheets.find).
for _png, _index in (("UiSheet.png", "UiSprites.luau"), ("FarmSheet.png", "FarmSprites.luau"),
                     ("IconSheet.png", "IconSprites.luau")):
    _sheet = Image.open(os.path.join(ROOT, "assets/ui", _png)).convert("RGBA")
    for m in re.findall(r"(\w+) = \{ offset = Vector2.new\((\d+), (\d+)\), size = Vector2.new\((\d+), (\d+)\) \}",
                        open(os.path.join(ROOT, "src/shared", _index)).read()):
        SPRITES[m[0]] = (_sheet, int(m[1]), int(m[2]), int(m[3]), int(m[4]))
W, H = 1280, 720
SS = 2  # supersample for smoother edges

MODULES = ["src/shared/Config.luau", "src/shared/AssetIds.luau", "src/shared/UiSprites.luau",
           "src/shared/FarmSprites.luau", "src/shared/IconSprites.luau", "src/shared/SpriteSheets.luau",
           "src/shared/Modes.luau", "src/shared/Cosmetics.luau", "src/shared/Progression.luau",
           "src/builders/GuiKit.luau", "src/builders/ProgressGui.luau", "src/builders/GuiBuilder.luau"]

SCENARIO = r'''
local scenario = "%s"
local root = Instance.new("Folder")
local GuiBuilder = mockRequire(builders:FindFirstChild("GuiBuilder"))
GuiBuilder.build(root)
local Modes = mockRequire(shared:FindFirstChild("Modes"))
local Cosmetics = mockRequire(shared:FindFirstChild("Cosmetics"))
local hud, shop, emotesGui, driver = root.Hud, root.Shop, root.Emotes, root.Driver
local H, S, E, D = hud.Root, shop.Root, emotesGui.Root, driver.Root
local function setSprite(img, s) img:SetAttribute("Sprite", s) end
local function tpl(screen, name) local c = screen.Templates[name]:Clone(); c.Visible = true; return c end
local function setButton(b, text, color)
	local inner = b.Border.Inner
	if text and inner.Content:FindFirstChild("Label") then inner.Content.Label.Text = text end
	if color then inner.BackgroundColor3 = color; inner.BackgroundTransparency = 0 end
end
local function feed(text, icon, i)
	local line = tpl(hud, "FeedLine")
	line.LayoutOrder = i
	setSprite(line.Icon, icon)
	line.Text.Text = text
	line.Parent = H.Feed
end
local function toast(text, icon, color, i)
	local t = tpl(hud, "Toast")
	t.LayoutOrder = i
	setSprite(t.Icon, icon)
	t.Text.Text = text
	t.Text.TextColor3 = color
	t.Parent = H.Toasts
end
local function board(title, big, names, outFrom)
	H.Board.Inner.Title.Text = title
	H.Board.Inner.Big.Text = big
	for i, n in names do
		local row = tpl(hud, "BoardRow")
		row.LayoutOrder = i
		row.Rank.Text = i .. "."
		row.Player.Text = n[1]
		row.Value.Text = tostring(n[2])
		if outFrom and i >= outFrom then row.Player.TextTransparency = 0.55; row.Rank.TextTransparency = 0.55 end
		if n[1] == "CJR2" then row.BackgroundColor3 = Color3.fromRGB(255, 214, 170); row.BackgroundTransparency = 0 end
		row.Parent = H.Board.Inner.Rows
	end
end
local players = { { "Quertosir", 19 }, { "SillyGoose_3", 18 }, { "CornyJokes", 15 }, { "Kentucky", 10 }, { "Clover_Patch", 10 }, { "CJR2", 4 } }
H.Stats.Inner.Row.Eggs.Label.Text = "1,250"
local function objective(title, sub, color, sprite)
	H.Objective.Inner.Title.Text = title
	H.Objective.Inner.Sub.Text = sub
	if color then H.Objective.Inner.Title.TextColor3 = color end
	if sprite then setSprite(H.Objective.Inner.Icon, sprite) end
end
if scenario == "vote" then
	H.RoundCard.Inner.Title.Text = "Vote for a mode"
	setSprite(H.RoundCard.Inner.Icon, "vote")
	H.RoundCard.Inner.Time.Text = "0:12"
	H.RoundCard.Inner.Bar.Fill.Size = UDim2.fromScale(0.7, 1)
	objective("VOTE FOR A MODE", "Pick the next game below.", nil, "vote")
	board("TOP CHICKENS", "6 IN LOBBY", players)
	H.Vote.Visible = true
	H.Vote.Header.Inner.Timer.Text = "12"
	local looks = { Solo = { "chickenRun", Color3.fromRGB(255, 150, 40) }, Teams = { "team", Color3.fromRGB(70, 160, 240) }, RoadRage = { "angry", Color3.fromRGB(226, 74, 64) } }
	local votes = { Solo = 3, Teams = 1, RoadRage = 4 }
	for i, id in { "Solo", "Teams", "RoadRage" } do
		local mode = Modes.get(id)
		local card = tpl(hud, "VoteCard")
		card.LayoutOrder = i
		local inner = card.Border.Inner
		inner.Band.BackgroundColor3 = looks[id][2]
		inner.Bar.Fill.BackgroundColor3 = looks[id][2]
		setSprite(inner.Icon, looks[id][1])
		inner.ModeName.Text = string.upper(mode.name)
		inner.Desc.Text = mode.description
		inner.Bar.Fill.Size = UDim2.fromScale(votes[id] / 8, 1)
		inner.Bar.Votes.Text = votes[id] .. " votes"
		card.Check.Visible = id == "RoadRage"
		if id == "RoadRage" then card.Border.UIStroke.Color = Color3.fromRGB(140, 230, 110); card.Border.UIStroke.Thickness = 3 end
		card.Parent = H.Vote.Cards
	end
	feed("Cluckers joined the game", "info", 1)
	feed("Henrietta egged Nugget to their doom!", "egg", 2)
elseif scenario == "round" then
	H.RoundCard.Inner.Title.Text = "SPEED DEMONS"
	setSprite(H.RoundCard.Inner.Icon, "lightning")
	H.RoundCard.Inner.Time.Text = "0:08"
	H.RoundCard.Inner.Bar.Fill.Size = UDim2.fromScale(0.35, 1)
	H.RoundCard.Inner.Bar.Fill.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
	H.Stats.Inner.Row.Time.Label.Text = "2:32"
	H.Stats.Inner.Row.Alive.Label.Text = "5/6"
	objective("RUN TO THE WINDMILL!", "The barn side crumbles in 7s.", nil, "windmill")
	H.Objective.Inner.Bar.Visible = true
	H.Objective.Inner.Bar.Fill.Size = UDim2.fromScale(0.45, 1)
	H.Objective.Inner.Bar.Fill.BackgroundColor3 = Color3.fromRGB(255, 204, 64)
	board("RUSH HOUR", "5 OF 6 LEFT", players, 6)
	H.Stamina.Visible = true
	H.Stamina.Track.Fill.Size = UDim2.fromScale(0.65, 1)
	H.EggCharge.Visible = true
	H.EggCharge.Track.Fill.Size = UDim2.fromScale(0.4, 1)
	local function chip(c, title, sprite, value, fill, color)
		c.Visible = true
		c.Inner.Title.Text = title
		c.Inner.Title.TextColor3 = color
		setSprite(c.Inner.Icon, sprite)
		c.Inner.Value.Text = value
		c.Inner.Bar.Fill.Size = UDim2.fromScale(fill, 1)
		c.Inner.Bar.Fill.BackgroundColor3 = color
	end
	chip(H.Powerups.Power, "SPEED BOOTS", "lightning", "4s", 0.66, Color3.fromRGB(255, 214, 64))
	chip(H.Powerups.Special, "EXPLOSIVE EGGS", "boom", "x2", 0.66, Color3.fromRGB(255, 90, 50))
	feed("Nugget got flattened by a car", "car", 3)
	feed("Henrietta egged Drumstick to their doom!", "egg", 2)
	feed("SPEED DEMONS: Traffic goes much faster!", "lightning", 1)
	toast("+15 eggs for a knockout", "eggCoin", Color3.fromRGB(255, 204, 64), 1)
	toast("KNOCKOUT! Drumstick", "egg", Color3.fromRGB(255, 200, 90), 2)
elseif scenario == "go" then
	H.RoundCard.Inner.Title.Text = "Rush Hour"
	setSprite(H.RoundCard.Inner.Icon, "lightning")
	H.RoundCard.Inner.Time.Text = "3:00"
	H.Stats.Inner.Row.Time.Label.Text = "3:00"
	H.Stats.Inner.Row.Alive.Label.Text = "6/6"
	objective("RUN TO THE WINDMILL!", "The barn side crumbles in 25s.", nil, "windmill")
	board("RUSH HOUR", "6 OF 6 LEFT", players)
	H.Countdown.Visible = true
	H.Countdown.Number.Text = "GO!"
	H.Countdown.Number.TextColor3 = Color3.fromRGB(140, 230, 110)
	H.Danger.Visible = true
elseif scenario == "intro" then
	H.RoundCard.Inner.Title.Text = "Get ready..."
	H.RoundCard.Inner.Time.Text = "0:04"
	objective("GET READY!", "Every chicken for itself. Last one alive wins.", Color3.fromRGB(255, 156, 46), "clock")
	board("SOLO", "6 OF 6 LEFT", players)
	H.Intro.Visible = true
elseif scenario == "results" then
	H.RoundCard.Inner.Title.Text = "Round over"
	setSprite(H.RoundCard.Inner.Icon, "trophy")
	H.RoundCard.Inner.Time.Text = "0:05"
	objective("ROUND OVER", "Next round starts in a moment.", Color3.fromRGB(255, 156, 46), "trophy")
	board("TOP CHICKENS", "6 IN LOBBY", players)
	H.Results.Visible = true
	H.Results.Card.Inner.Title.Text = "YOU WIN!"
	H.Results.Card.Inner.Winner.Text = "CJR2 crossed the road!"
	H.Results.Card.Inner.Reward.Visible = true
	H.Results.Card.Inner.Reward.Label.Text = "+85"
	toast("+50 eggs for winning!", "eggCoin", Color3.fromRGB(255, 204, 64), 1)
elseif scenario == "shop" then
	S.Dim.Visible = true
	S.Panel.Visible = true
	S.Panel.Inner.Header.Coins.Label.Text = "1,250"
	setButton(S.Panel.Inner.Tabs.ChickenSkin, nil, Color3.fromRGB(255, 156, 46))
	local states = { "EQUIPPED", "EQUIP", "250", "400", "900", "1200", "3000", "R$ 99", "300", "800" }
	local i = 0
	for _, item in Cosmetics.list do
		if item.slot == "ChickenSkin" or (item.slot == "EggSkin" and i < 10) then
			i += 1
			if i > 10 then break end
			local card = tpl(shop, "ItemCard")
			card.LayoutOrder = i
			local inner = card.Inner
			local c = Cosmetics.rarityColors[item.rarity]
			inner.RarityBar.RarityGradient.Color = ColorSequence.new(c:Lerp(Color3.new(1, 1, 1), 0.15), c:Lerp(Color3.new(0, 0, 0), 0.25))
			inner.RarityBar.Rarity.Text = string.upper(item.rarity)
			inner.Glow.ImageColor3 = c
			inner.ItemName.Text = item.name
			inner.Preview.Visible = false
			inner.PreviewIcon.Visible = true
			setSprite(inner.PreviewIcon, if item.slot == "ChickenSkin" then "chicken" else "egg")
			local st = states[i]
			local color = if st == "EQUIPPED" then Color3.fromRGB(150, 138, 126) elseif st == "EQUIP" then Color3.fromRGB(110, 200, 84) elseif st:sub(1, 2) == "R$" then Color3.fromRGB(255, 110, 170) else Color3.fromRGB(255, 156, 46)
			setButton(inner.Action, st, color)
			inner.Action.Border.Inner.Content.Icon.Visible = tonumber(st) ~= nil
			card.Equipped.Visible = st == "EQUIPPED"
			card.Lock.Visible = st ~= "EQUIPPED" and st ~= "EQUIP"
			card.Parent = S.Panel.Inner.Grid
		end
	end
elseif scenario == "emotes" then
	E.Picker.Visible = true
	E.Picker.Position = UDim2.new(0, 132, 1, -68)
	local names = { "BAWK!", "SPIN", "HAPPY HOP", "+ ADD" }
	for i = 1, 4 do setButton(E.Picker.Inner.Slots["Slot" .. i], names[i]) end
	objective("WAITING FOR CHICKENS", "The game starts when enough chickens are here.", nil, "chick")
	board("TOP CHICKENS", "6 IN LOBBY", players)
elseif scenario == "afk" then
	objective("YOU'RE AFK", "You'll sit out rounds until you press BACK.", Color3.fromRGB(255, 204, 64), "clock")
	setButton(H.Buttons.Afk, "BACK", Color3.fromRGB(255, 156, 46))
	setSprite(H.Buttons.Afk.Border.Inner.Content.Icon, "play")
	board("TOP CHICKENS", "6 IN LOBBY", players)
elseif scenario == "driver" then
	driver.Enabled = true
	D.Controls.Cooldown.Fill.Size = UDim2.fromScale(0.6, 1)
	D.Controls.Cooldown.Hint.Text = "RELOADING 1.2"
	objective("ROAD RAGE!", "Pick a lane and send cars at the chickens.", Color3.fromRGB(235, 80, 70), "angry")
	H.Buttons.Spectate.Visible = false
end
-- Progress window (levels, quests, season pass): filled in the way ProgressUI does it.
if scenario == "level" or scenario == "quests" or scenario == "pass" or scenario == "levelup" then
	local Config = mockRequire(shared:FindFirstChild("Config"))
	local Progression = mockRequire(shared:FindFirstChild("Progression"))
	local progressGui = root.Progress
	local G = progressGui.Root
	local ORANGE, GREEN, GREY, BLUE, PINK = Color3.fromRGB(255, 156, 46), Color3.fromRGB(110, 200, 84), Color3.fromRGB(150, 138, 126), Color3.fromRGB(76, 164, 236), Color3.fromRGB(255, 110, 170)
	local INK, INK_SOFT = Color3.fromRGB(74, 46, 28), Color3.fromRGB(140, 104, 76)
	local function setIcon(b, sprite)
		local icon = b.Border.Inner.Content:FindFirstChild("Icon")
		if icon then icon.Visible = sprite ~= ""; if sprite ~= "" then setSprite(icon, sprite) end end
	end
	H.Buttons.Pass.Level.Label.Text = "12"
	objective("WAITING FOR CHICKENS", "The game starts when enough chickens are here.", nil, "chick")
	board("TOP CHICKENS", "6 IN LOBBY", players)
	local function openTab(tab)
		G.Dim.Visible = true
		G.Panel.Visible = true
		local inner = G.Panel.Inner
		inner.Header.Coins.Label.Text = "1,250"
		for _, t in { "Level", "Quests", "Pass" } do
			inner.Pages[t].Visible = t == tab
			if t == tab then setButton(inner.Tabs[t], nil, ORANGE) end
		end
		inner.Tabs.Pass.Alert.Visible = true
		return inner.Pages[tab]
	end
	if scenario == "level" then
		local pg = openTab("Level")
		local s = pg.Summary.Inner
		s.Number.Text = "12"
		s.LevelText.Text = "LEVEL 12"
		s.TitleText.Text = "Egg Slinger"
		s.XpBar.Fill.Size = UDim2.fromScale(140 / 320, 1)
		s.XpBar.Text.Text = "140 / 320 XP"
		s.Next.Label.Text = "+69 eggs at level 13"
		local stats = { Wins = 23, Knockouts = 87, Crossings = 164, Rounds = 141 }
		for name, v in stats do s.Stats[name].Value.Text = tostring(v) end
		local count = 0
		for i, def in Config.Progress.Titles do
			local row = tpl(progressGui, "TitleRow")
			row.LayoutOrder = i
			local open = Progression.titleUnlocked(def, 12, stats, {})
			local equipped = def.id == "EggSlinger"
			row.TitleName.Text = def.name
			row.TitleName.TextColor3 = if open then INK else INK_SOFT
			local req = Progression.titleRequirement(def)
			if not open and def.stat then req = math.min(stats[def.stat], def.goal) .. " / " .. req end
			row.Requirement.Text = req
			row.Icon.ImageTransparency = if open then 0 else 0.55
			row.Lock.Visible = not open
			row.Action.Visible = open
			row.BackgroundColor3 = if equipped then Color3.fromRGB(226, 246, 206) elseif open then Color3.fromRGB(244, 230, 204) else Color3.fromRGB(236, 226, 210)
			if equipped then row.UIStroke.Color = GREEN; row.UIStroke.Transparency = 0; row.UIStroke.Thickness = 2.5 end
			if open then
				count += 1
				setButton(row.Action, if equipped then "WORN" else "WEAR", if equipped then GREY else GREEN)
			end
			row.Parent = pg.TitleList
		end
		pg.TitlesCount.Text = count .. " / " .. #Config.Progress.Titles .. " UNLOCKED"
	elseif scenario == "quests" then
		local pg = openTab("Quests")
		pg.Top.Timer.Text = "NEW QUESTS IN 7h 42m"
		pg.Top.Rerolls.Label.Text = "1 FREE SWAP TODAY"
		local states = { { "Knockouts5", 3, false }, { "Win1", 1, true }, { "Glide20", 6, false } }
		for i, st in states do
			local def = Progression.findQuest(Config.Quests.Pool, st[1])
			local card = tpl(progressGui, "QuestCard")
			local inner = card.Inner
			card.LayoutOrder = i
			local color = if st[3] then GREEN else ORANGE
			inner.Band.BackgroundColor3 = color
			inner.Bar.Fill.BackgroundColor3 = color
			setSprite(inner.Icon, def.icon)
			inner.QuestName.Text = def.text
			inner.Bar.Fill.Size = UDim2.fromScale(math.max(0.03, st[2] / def.goal), 1)
			inner.Bar.Text.Text = if st[3] then "COMPLETE!" else st[2] .. " / " .. def.goal
			inner.Rewards.Coins.Label.Text = "+" .. def.coins
			inner.Rewards.Xp.Label.Text = "+" .. def.xp .. " XP"
			card.Done.Visible = st[3]
			if st[3] then
				setButton(inner.Action, "REWARD COLLECTED", GREY)
			else
				setButton(inner.Action, "SWAP QUEST", BLUE)
				setIcon(inner.Action, "")
			end
			card.Parent = pg.Cards
		end
	elseif scenario == "pass" then
		local pg = openTab("Pass")
		local S = Config.Season
		local b = pg.Season.Inner
		b.SeasonLabel.Text = "SEASON " .. S.Number
		b.SeasonName.Text = string.upper(S.Name)
		b.Timer.Label.Text = "Ends in 57d 11h"
		local xp = 7 * 300 + 120
		local tier, into, need = Progression.tierInfo(xp, S.XpPerTier, S.Tiers)
		b.Tier.Text = "TIER " .. tier
		b.TierXp.Text = into .. " / " .. need .. " XP"
		b.TierBar.Fill.Size = UDim2.fromScale(into / need, 1)
		b.NextTier.Text = "Next tier: +250 eggs"
		setButton(b.Premium, "R$ 399", PINK)
		local claimed = { F2 = true, F4 = true }
		local track = pg.TrackArea.Track
		track.CanvasPosition = Vector2.new(2 * 112, 0)
		local function cell(c, reward, reached, isClaimed, locked)
			c.Claim.Visible = false
			if not reward then
				c.BackgroundTransparency = 0.85
				c.UIStroke.Transparency = 0.8
				c.Icon.Visible = false
				c.Glow.Visible = false
				c.Label.Text = ""
				return
			end
			local sprite, label, tint = "eggCoin", "", Color3.new(1, 1, 1)
			if reward.coins then
				label = "+" .. reward.coins
			elseif reward.item then
				local item = Cosmetics.get(reward.item)
				local slots = { ChickenSkin = "chicken", EggSkin = "egg", HitEffect = "boom", WinEffect = "trophy", Emote = "emote" }
				sprite = slots[item.slot]
				label = item.name
				if item.look.colors then tint = item.look.colors[1]:Lerp(Color3.new(1, 1, 1), 0.35) end
			else
				sprite = "rosette"
				label = "Title"
			end
			setSprite(c.Icon, sprite)
			c.Icon.ImageColor3 = tint
			c.Glow.Visible = reward.coins == nil
			c.Label.Text = label
			c.Icon.ImageTransparency = if isClaimed then 0.5 else 0
			c.Label.TextColor3 = if isClaimed or not reached or locked then INK_SOFT else INK
			c.Check.Visible = isClaimed
			c.Lock.Visible = not isClaimed and (not reached or locked)
			if reached and not isClaimed and not locked then
				c.Claim.Visible = true
			end
		end
		for t = 1, S.Tiers do
			local col = tpl(progressGui, "TierColumn")
			col.LayoutOrder = t
			col.Head.Num.Text = tostring(t)
			local reached = t <= tier
			col.Head.BackgroundColor3 = if reached then ORANGE else Color3.fromRGB(44, 29, 20)
			local fill = if reached then 1 elseif t == tier + 1 then into / need else 0
			col.Line.Fill.Size = UDim2.fromScale(fill, 1)
			col.Line.Fill.Visible = fill > 0
			cell(col.Free, S.Free[t], reached, claimed["F" .. t] == true, false)
			cell(col.Premium, S.Premium[t], reached, false, true)
			col.Parent = track
		end
	elseif scenario == "levelup" then
		local L = G.LevelUp
		L.Visible = true
		L.Number.Text = "12"
		L.Card.Inner.Sub.Text = "New title: Egg Slinger!"
		L.Card.Inner.Reward.Label.Text = "+66"
		H.RoundCard.Inner.Title.Text = "RUN!"
		H.Stats.Inner.Row.Time.Label.Text = "1:42"
		H.Stats.Inner.Row.Alive.Label.Text = "4/6"
		toast("+25 eggs for the knockout", "eggCoin", Color3.fromRGB(255, 204, 64), 1)
	end
end
print("JSON" .. dumpTree(root))
'''

FONTS = {}


def font(name, size):
    key = (name, size)
    if key not in FONTS:
        fdir = FONT_DIR
        if name == "LuckiestGuy":
            f = ImageFont.truetype(os.path.join(fdir, "LuckiestGuy.ttf"), size)
        else:
            f = ImageFont.truetype(os.path.join(fdir, "Fredoka.ttf"), size)
            try:
                f.set_variation_by_name("Bold" if name == "FredokaOne" else "SemiBold")
            except Exception:
                pass
        FONTS[key] = f
    return FONTS[key]


def nine_slice(src, center, w, h, scale):
    """Roblox-style 9-slice: corners keep their size (times `scale`), edges/centre stretch."""
    x0, y0, x1, y1 = center
    sw, sh = src.size
    cols = [(0, x0), (x0, x1), (x1, sw)]
    rows = [(0, y0), (y0, y1), (y1, sh)]
    cw = [max(1, int(x0 * scale)), 0, max(1, int((sw - x1) * scale))]
    rh = [max(1, int(y0 * scale)), 0, max(1, int((sh - y1) * scale))]
    cw[1] = max(1, w - cw[0] - cw[2])
    rh[1] = max(1, h - rh[0] - rh[2])
    out = Image.new("RGBA", (max(1, w), max(1, h)))
    oy = 0
    for (ry0, ry1), th in zip(rows, rh):
        ox = 0
        for (cx0, cx1), tw in zip(cols, cw):
            if cx1 > cx0 and ry1 > ry0:
                out.alpha_composite(src.crop((cx0, ry0, cx1, ry1)).resize((tw, th), Image.LANCZOS), (ox, oy))
            ox += tw
        oy += th
    return out


def run_luau(scenario, luau):
    parts = [open(os.path.join(ROOT, "tools/preview/mock.luau")).read()]
    parts.append('local shared = service("ReplicatedStorage"):FindFirstChild("Shared")')
    parts.append('for _, n in { "Modes", "Cosmetics", "Progression", "FarmSprites", "IconSprites", "SpriteSheets" } do moduleInst(n, "./src/shared/" .. n .. ".luau").Parent = shared end')
    parts.append('for _, n in { "GuiKit", "ProgressGui", "GuiBuilder" } do moduleInst(n, "./src/builders/" .. n .. ".luau").Parent = builders end')
    for rel in MODULES:
        src = open(os.path.join(ROOT, rel)).read()
        src = re.sub(r"^export type", "type", src, flags=re.M).replace("--!strict", "")
        parts.append(f'__modules["./{rel}"] = function(script, require)\n{src}\nend\n')
    parts.append(SCENARIO % scenario)
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as f:
        f.write("\n".join(parts))
        path = f.name
    out = subprocess.run([luau, path], capture_output=True, text=True)
    for line in out.stdout.splitlines():
        if line.startswith("JSON"):
            return json.loads(line[4:])
    sys.exit(out.stdout[-3000:] + out.stderr[-3000:])


# --- layout ---------------------------------------------------------------------------------------

GUI_CLASSES = {"Frame", "TextLabel", "TextButton", "ImageLabel", "ImageButton", "ScrollingFrame", "ViewportFrame"}


def P(n, key, default=None):
    return n["props"].get(key, default)


def kids(n, cls=None):
    return [c for c in n["children"] if cls is None or P(c, "ClassName") in cls]


def child_of_class(n, cls):
    for c in n["children"]:
        if P(c, "ClassName") == cls:
            return c
    return None


def udim2(v, default=(0, 0, 0, 0)):
    return v["udim2"] if v else default


def text_width(n):
    size = P(n, "TextSize", 14)
    f = font(P(n, "Font", "FredokaOne"), max(6, int(size * SS)))
    return f.getbbox(P(n, "Text", "") or " ")[2] / SS + 2


def auto_width(n, ph):
    """Width of an AutomaticSize X element (text, or a horizontal list of children)."""
    if P(n, "ClassName") in ("TextLabel", "TextButton") and P(n, "Text", ""):
        return text_width(n)
    pad = child_of_class(n, "UIPadding")
    extra = 0
    if pad:
        extra = P(pad, "PaddingLeft", {"udim": [0, 0]})["udim"][1] + P(pad, "PaddingRight", {"udim": [0, 0]})["udim"][1]
    lst = child_of_class(n, "UIListLayout")
    items = [c for c in n["children"] if P(c, "ClassName") in GUI_CLASSES and P(c, "Visible", True)]
    if lst and P(lst, "FillDirection") == "Horizontal":
        gap = P(lst, "Padding", {"udim": [0, 0]})["udim"][1]
        return sum(resolve_size(c, 0, ph)[0] for c in items) + gap * max(0, len(items) - 1) + extra
    return max([resolve_size(c, 0, ph)[0] for c in items] or [0]) + extra


def resolve_size(n, pw, ph):
    sx, ox, sy, oy = udim2(P(n, "Size"), (0, 100, 0, 100))
    constraint = P(n, "SizeConstraint", "RelativeXY")
    basex = ph if constraint == "RelativeYY" else pw
    basey = pw if constraint == "RelativeXX" else ph
    w, h = sx * basex + ox, sy * basey + oy
    if P(n, "AutomaticSize") in ("X", "XY"):
        w = max(w, auto_width(n, h if h > 0 else ph))
    ar = child_of_class(n, "UIAspectRatioConstraint")
    if ar:
        r = P(ar, "AspectRatio", 1)
        if w / max(h, 1e-6) > r:
            w = h * r
        else:
            h = w / r
    sc = child_of_class(n, "UISizeConstraint")
    if sc:
        mx = P(sc, "MaxSize", {"v2": [1e9, 1e9]})["v2"]
        mn = P(sc, "MinSize", {"v2": [0, 0]})["v2"]
        w = min(max(w, mn[0]), mx[0])
        h = min(max(h, mn[1]), mx[1])
    return w, h


def anim_scale(n):
    for c in n["children"]:
        if P(c, "ClassName") == "UIScale":
            return P(c, "Scale", 1)
    return 1


def layout(n, x, y, w, h, out):
    """Computes absolute rects for n's GUI children; n occupies (x,y,w,h)."""
    pad = child_of_class(n, "UIPadding")
    cx, cy, cw, ch = x, y, w, h
    if pad:
        l = P(pad, "PaddingLeft", {"udim": [0, 0]})["udim"]
        r = P(pad, "PaddingRight", {"udim": [0, 0]})["udim"]
        t = P(pad, "PaddingTop", {"udim": [0, 0]})["udim"]
        b = P(pad, "PaddingBottom", {"udim": [0, 0]})["udim"]
        pl, pr = l[0] * w + l[1], r[0] * w + r[1]
        pt, pb = t[0] * h + t[1], b[0] * h + b[1]
        cx, cy, cw, ch = x + pl, y + pt, w - pl - pr, h - pt - pb
    children = [c for c in n["children"] if P(c, "ClassName") in GUI_CLASSES]
    lst = child_of_class(n, "UIListLayout")
    grid = child_of_class(n, "UIGridLayout")
    if lst:
        horizontal = P(lst, "FillDirection") == "Horizontal"
        padding = P(lst, "Padding", {"udim": [0, 0]})["udim"]
        gap = padding[0] * (cw if horizontal else ch) + padding[1]
        items = sorted([c for c in children if P(c, "Visible", True)], key=lambda c: P(c, "LayoutOrder", 0))
        sizes = [resolve_size(c, cw, ch) for c in items]
        total = sum(s[0] if horizontal else s[1] for s in sizes) + gap * max(0, len(items) - 1)
        halign = P(lst, "HorizontalAlignment", "Left")
        valign = P(lst, "VerticalAlignment", "Top")
        if horizontal:
            start = cx + {"Left": 0, "Center": (cw - total) / 2, "Right": cw - total}.get(halign, 0)
        else:
            start = cy + {"Top": 0, "Center": (ch - total) / 2, "Bottom": ch - total}.get(valign, 0)
        pos = start
        for c, (iw, ih) in zip(items, sizes):
            s = anim_scale(c)
            if horizontal:
                iy = cy + {"Top": 0, "Center": (ch - ih) / 2, "Bottom": ch - ih}.get(valign, 0)
                place(c, pos, iy, iw, ih, s, out)
                pos += iw + gap
            else:
                ix = cx + {"Left": 0, "Center": (cw - iw) / 2, "Right": cw - iw}.get(halign, 0)
                place(c, ix, pos, iw, ih, s, out)
                pos += ih + gap
        return
    if grid:
        cell = udim2(P(grid, "CellSize"))
        cpad = udim2(P(grid, "CellPadding"))
        gw, gh = cell[0] * cw + cell[1], cell[2] * ch + cell[3]
        px, py = cpad[0] * cw + cpad[1], cpad[2] * ch + cpad[3]
        per_row = max(1, int((cw + px) // (gw + px)))
        items = sorted([c for c in children if P(c, "Visible", True)], key=lambda c: P(c, "LayoutOrder", 0))
        row_w = per_row * gw + (per_row - 1) * px
        off = (cw - row_w) / 2 if P(grid, "HorizontalAlignment") == "Center" else 0
        for i, c in enumerate(items):
            r, col = divmod(i, per_row)
            place(c, cx + off + col * (gw + px), cy + r * (gh + py), gw, gh, anim_scale(c), out)
        return
    for c in children:
        cw2, ch2 = resolve_size(c, cw, ch)
        psx, pox, psy, poy = udim2(P(c, "Position"))
        ax, ay = P(c, "AnchorPoint", {"v2": [0, 0]})["v2"]
        px = cx + psx * cw + pox - ax * cw2
        py = cy + psy * ch + poy - ay * ch2
        place(c, px, py, cw2, ch2, anim_scale(c), out)


CLIP = {}  # id(node) -> (x0, y0, x1, y1) it is clipped to by an ancestor
CLIP_STACK = [None]


def intersect(a, b):
    if a is None:
        return b
    return (max(a[0], b[0]), max(a[1], b[1]), min(a[2], b[2]), min(a[3], b[3]))


def place(n, x, y, w, h, scale, out):
    if not P(n, "Visible", True):
        return
    if scale != 1:
        mx, my = x + w / 2, y + h / 2
        w, h = w * scale, h * scale
        x, y = mx - w / 2, my - h / 2
    out.append((n, x, y, w, h))
    if CLIP_STACK[-1] is not None:
        CLIP[id(n)] = CLIP_STACK[-1]
    start = len(out)
    # ScrollingFrames (and ClipsDescendants frames) clip their contents; scrolling shifts them.
    scrolling = P(n, "ClassName") == "ScrollingFrame"
    clips = scrolling or P(n, "ClipsDescendants", False)
    if clips:
        CLIP_STACK.append(intersect(CLIP_STACK[-1], (x, y, x + w, y + h)))
    ox, oy = P(n, "CanvasPosition", {"v2": [0, 0]})["v2"] if scrolling else (0, 0)
    layout(n, x - ox, y - oy, w, h, out)
    if clips:
        CLIP_STACK.pop()
    # Children draw above their parent; siblings by ZIndex (stable).
    sub = out[start:]
    del out[start:]
    direct = []
    # Re-sort only direct grandchildren groups is overkill; sort the whole subtree by depth-first z.
    out.extend(sub)


# --- drawing --------------------------------------------------------------------------------------

def rounded_mask(w, h, radius):
    m = Image.new("L", (max(1, int(w)), max(1, int(h))), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, m.width - 1, m.height - 1], radius=max(0, int(radius)), fill=255)
    return m


def corner_radius(n, w, h):
    c = child_of_class(n, "UICorner")
    if not c:
        return 0
    s, o = P(c, "CornerRadius", {"udim": [0, 8]})["udim"]
    return min(s * min(w, h) + o * SS, min(w, h) / 2)


def gradient_image(n, w, h, base):
    g = child_of_class(n, "UIGradient") or next((c for c in n["children"] if P(c, "ClassName") == "UIGradient"), None)
    w, h = max(1, int(w)), max(1, int(h))
    color = np.ones((h, w, 3)) * np.array(base)
    alpha = np.ones((h, w))
    if g:
        rot = P(g, "Rotation", 0)
        off = P(g, "Offset", {"v2": [0, 0]})["v2"]
        yy, xx = np.mgrid[0:h, 0:w]
        u = (xx + 0.5) / w - 0.5
        v = (yy + 0.5) / h - 0.5
        a = math.radians(rot)
        t = np.clip(u * math.cos(a) + v * math.sin(a) + 0.5 - (off[0] * math.cos(a) + off[1] * math.sin(a)), 0, 1)
        cs = P(g, "Color")
        if cs:
            keys = cs["cseq"]
            ts = [k[0] for k in keys]
            for ch in range(3):
                color[..., ch] *= np.interp(t, ts, [k[1 + ch] for k in keys])
        ns = P(g, "Transparency")
        if ns:
            keys = ns["nseq"]
            alpha *= 1 - np.interp(t, [k[0] for k in keys], [k[1] for k in keys])
    return color, alpha


def draw_node(canvas, n, x, y, w, h):
    cls = P(n, "ClassName")
    X, Y, Wd, Ht = x * SS, y * SS, w * SS, h * SS
    if Wd < 1 or Ht < 1:
        return
    radius = corner_radius(n, Wd, Ht)
    bt = P(n, "BackgroundTransparency", 0)
    stroke = next((c for c in n["children"] if P(c, "ClassName") == "UIStroke"
                   and P(c, "ApplyStrokeMode") == "Border"), None)
    if stroke is None and cls in ("Frame", "ScrollingFrame") and child_of_class(n, "UIStroke") and \
            P(child_of_class(n, "UIStroke"), "ApplyStrokeMode") != "Contextual":
        stroke = child_of_class(n, "UIStroke")
    if stroke and bt < 1:
        th = P(stroke, "Thickness", 1) * SS
        col = tuple(int(c * 255) for c in P(stroke, "Color", {"c3": [0, 0, 0]})["c3"])
        m = rounded_mask(Wd + 2 * th, Ht + 2 * th, radius + th)
        # Only the ring: the inside shows through translucent backgrounds, as in Roblox.
        hole = Image.new("L", m.size, 0)
        hole.paste(rounded_mask(Wd, Ht, radius), (int(th), int(th)))
        m = Image.fromarray(np.clip(np.array(m, dtype=np.int16) - np.array(hole, dtype=np.int16), 0, 255).astype(np.uint8))
        m = m.point(lambda a: int(a * (1 - P(stroke, "Transparency", 0))))
        layer = Image.new("RGBA", canvas.size)
        layer.paste(Image.new("RGBA", m.size, col + (255,)), (int(X - th), int(Y - th)), m)
        canvas.alpha_composite(layer)
    if bt < 1:
        base = P(n, "BackgroundColor3", {"c3": [0.64, 0.64, 0.64]})["c3"]
        color, alpha = gradient_image(n, Wd, Ht, base)
        alpha = alpha * (1 - bt)
        img = Image.fromarray(np.dstack([np.clip(color * 255, 0, 255), alpha * 255]).astype(np.uint8), "RGBA")
        mask = rounded_mask(Wd, Ht, radius)
        a = np.array(img.split()[3]) * (np.array(mask) / 255)
        img.putalpha(Image.fromarray(a.astype(np.uint8)))
        canvas.alpha_composite(img, (int(X), int(Y)))
    if cls in ("ImageLabel", "ImageButton"):
        sprite = n["attrs"].get("Sprite")
        if sprite in SPRITES and P(n, "ImageTransparency", 0) < 1:
            sheet, ox, oy, sw, sh = SPRITES[sprite]
            src = sheet.crop((int(ox), int(oy), int(ox + sw), int(oy + sh)))
            tint = P(n, "ImageColor3", {"c3": [1, 1, 1]})["c3"]
            arr = np.array(src).astype(float)
            arr[..., :3] *= np.array(tint)
            arr[..., 3] *= 1 - P(n, "ImageTransparency", 0)
            src = Image.fromarray(arr.clip(0, 255).astype(np.uint8), "RGBA")
            if P(n, "ScaleType") == "Slice" and P(n, "SliceCenter"):
                x0, y0, x1, y1 = (int(v) for v in P(n, "SliceCenter")["rect"])
                layer = nine_slice(src, (x0, y0, x1, y1), int(Wd), int(Ht), SS * 0.5)
                canvas.alpha_composite(layer, (int(X), int(Y)))
            elif P(n, "ScaleType") == "Tile":
                tile = P(n, "TileSize", {"udim2": [0, 32, 0, 32]})["udim2"]
                tw, th = max(4, int(tile[1] * SS)), max(4, int(tile[3] * SS))
                t = src.resize((tw, th), Image.LANCZOS)
                layer = Image.new("RGBA", (int(Wd), int(Ht)))
                for ty in range(0, int(Ht), th):
                    for tx in range(0, int(Wd), tw):
                        layer.alpha_composite(t, (tx, ty))
                if radius:
                    a = np.array(layer.split()[3]) * (np.array(rounded_mask(Wd, Ht, radius)) / 255)
                    layer.putalpha(Image.fromarray(a.astype(np.uint8)))
                canvas.alpha_composite(layer, (int(X), int(Y)))
            else:
                s = min(Wd / sw, Ht / sh) if P(n, "ScaleType", "Stretch") == "Fit" else None
                if s:
                    iw, ih = max(1, int(sw * s)), max(1, int(sh * s))
                    img = src.resize((iw, ih), Image.LANCZOS)
                    rot = P(n, "Rotation", 0)
                    if rot:
                        img = img.rotate(-rot, resample=Image.BICUBIC, expand=False)
                    canvas.alpha_composite(img, (int(X + (Wd - iw) / 2), int(Y + (Ht - ih) / 2)))
                else:
                    canvas.alpha_composite(src.resize((max(1, int(Wd)), max(1, int(Ht))), Image.LANCZOS), (int(X), int(Y)))
    if cls in ("TextLabel", "TextButton") and P(n, "Text", ""):
        draw_text(canvas, n, X, Y, Wd, Ht)


def draw_text(canvas, n, X, Y, Wd, Ht):
    text = P(n, "Text", "")
    fname = P(n, "Font", "FredokaOne")
    color = tuple(int(c * 255) for c in P(n, "TextColor3", {"c3": [0, 0, 0]})["c3"]) + (int(255 * (1 - P(n, "TextTransparency", 0))),)
    tsc = child_of_class(n, "UITextSizeConstraint")
    max_size = (P(tsc, "MaxTextSize", 100) if tsc else 100) * SS
    stroke = next((c for c in n["children"] if P(c, "ClassName") == "UIStroke"
                   and P(c, "ApplyStrokeMode", "Contextual") == "Contextual"), None)
    sw = int(P(stroke, "Thickness", 0) * SS) if stroke else 0
    scol = tuple(int(c * 255) for c in P(stroke, "Color", {"c3": [0, 0, 0]})["c3"]) if stroke else None
    scaled = P(n, "TextScaled", False)
    size = int(min(max_size, Ht)) if scaled else int(P(n, "TextSize", 14) * SS)
    wrap = P(n, "TextWrapped", False)
    if stroke and P(stroke, "Transparency", 0) > 0.5:
        sw = 0

    def wrap_lines(f):
        if not wrap:
            return text.split("\n")
        out_lines = []
        for para in text.split("\n"):
            cur = ""
            for word in para.split(" "):
                trial = (cur + " " + word).strip()
                if f.getbbox(trial)[2] + 2 * sw <= Wd or not cur:
                    cur = trial
                else:
                    out_lines.append(cur)
                    cur = word
            out_lines.append(cur)
        return out_lines

    while scaled and size > 6:
        f = font(fname, size)
        lines = wrap_lines(f)
        widths = [f.getbbox(l)[2] for l in lines]
        if max(widths) + 2 * sw <= Wd and size * 1.15 * len(lines) <= Ht:
            break
        size -= 2
    f = font(fname, size)
    lines = wrap_lines(f)
    d = ImageDraw.Draw(canvas)
    line_h = size * 1.15
    total = line_h * len(lines)
    ty = Y if P(n, "TextYAlignment", "Center") == "Top" else Y + (Ht - total) / 2
    align = P(n, "TextXAlignment", "Center")
    for l in lines:
        bbox = f.getbbox(l)
        lw = bbox[2]
        tx = X + {"Left": sw, "Right": Wd - lw - sw}.get(align, (Wd - lw) / 2)
        d.text((tx, ty + (line_h - size) / 2 - bbox[1] * 0.3), l, font=f, fill=color,
               stroke_width=sw, stroke_fill=scol)
        ty += line_h


def render(tree, scenario, out):
    canvas = Image.new("RGBA", (W * SS, H * SS))
    # Fake game scene behind the UI.
    bg = Image.new("RGBA", (W * SS, H * SS))
    d = ImageDraw.Draw(bg)
    for yy in range(H * SS):
        t = yy / (H * SS)
        d.line([(0, yy), (W * SS, yy)], fill=(int(120 + 80 * t), int(170 + 60 * t), 255, 255))
    d.polygon([(0, H * SS * 0.62), (W * SS, H * SS * 0.55), (W * SS, H * SS), (0, H * SS)], fill=(62, 64, 74, 255))
    canvas.alpha_composite(bg)
    rects = []
    for screen in tree["children"]:
        if P(screen, "ClassName") != "ScreenGui" or P(screen, "Enabled", True) is False:
            continue
        layout(screen, 0, 0, W, H, rects)
    for n, x, y, w, h in rects:
        clip = CLIP.get(id(n))
        if clip is None:
            draw_node(canvas, n, x, y, w, h)
            continue
        x0, y0, x1, y1 = clip
        if x + w <= x0 or x >= x1 or y + h <= y0 or y >= y1:
            continue
        m = 4  # strokes reach a little outside
        if x - m >= x0 and y - m >= y0 and x + w + m <= x1 and y + h + m <= y1:
            draw_node(canvas, n, x, y, w, h)
            continue
        layer = Image.new("RGBA", canvas.size)
        draw_node(layer, n, x, y, w, h)
        box = (max(0, int(x0 * SS)), max(0, int(y0 * SS)), min(canvas.width, int(x1 * SS)), min(canvas.height, int(y1 * SS)))
        if box[2] > box[0] and box[3] > box[1]:
            canvas.alpha_composite(layer.crop(box), (box[0], box[1]))
    canvas.resize((W, H), Image.LANCZOS).convert("RGB").save(out)


def main():
    global FONT_DIR
    scenario, out = sys.argv[1], sys.argv[2]
    luau = sys.argv[sys.argv.index("--luau") + 1]
    FONT_DIR = sys.argv[sys.argv.index("--fonts") + 1]
    tree = run_luau(scenario, luau)
    # ScreenGuis sorted by DisplayOrder.
    tree["children"].sort(key=lambda s: P(s, "DisplayOrder", 0))
    render(tree, scenario, out)


if __name__ == "__main__":
    main()
