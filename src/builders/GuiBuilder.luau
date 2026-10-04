--!strict
-- Builds every ScreenGui into StarterGui so you can see and tweak the UI in Studio.
-- The client scripts find pieces by name, so rename with care (restyle freely).
--
--   Hud     round card (top), stats bar (bottom), objective card + buttons (bottom left),
--           players board (top right), feed (top left), toasts, stamina, voting, mode
--           intro, countdown, results, sudden death banner, spectate bar, screen effects
--   Shop    tabs, item grid, item/pack card templates
--   Emotes  emote picker
--   Driver  Road Rage controls
--
-- Layout is in pixels for a 1280x720 screen, inside each screen's Root frame; the client
-- scales Root to fit (src/client/Gui.luau).

local Kit = require(script.Parent.GuiKit)

local GuiBuilder = {}

local T = Kit.Theme
local new = Kit.new
local rgb = Color3.fromRGB
local V2 = Vector2.new

local function templates(parent: Instance): Folder
	return new("Folder", { Name = "Templates", Parent = parent })
end

local function hidden<O>(obj: O): O
	(obj :: any).Visible = false
	return obj
end

-- HUD ---------------------------------------------------------------------------------------

local function buildRoundCard(root: Frame)
	local _, inner = Kit.card("RoundCard", V2(340, 66), "dark", {
		AnchorPoint = V2(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Parent = root,
	})
	Kit.icon("Icon", "clock", 28, { Position = UDim2.fromOffset(12, 8), Parent = inner })
	Kit.text("Title", "Waiting for players", 20, {
		Position = UDim2.fromOffset(48, 7),
		Size = UDim2.new(1, -130, 0, 28),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = inner,
	})
	Kit.text("Time", "0:00", 22, {
		AnchorPoint = V2(1, 0),
		Position = UDim2.new(1, -12, 0, 7),
		Size = UDim2.fromOffset(80, 28),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = inner,
	})
	local bar = Kit.bar("Bar", V2(10, 6), T.Orange, { AnchorPoint = V2(0, 1), Position = UDim2.new(0, 48, 1, -11), Parent = inner })
	bar.Size = UDim2.new(1, -60, 0, 6)
end

local function statGroup(parent: Instance, name: string, sprite: string, text: string, order: number, button: boolean)
	local group = new(if button then "TextButton" else "Frame", {
		Name = name,
		LayoutOrder = order,
		Size = UDim2.fromOffset(0, 40),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Parent = parent,
	}, { Kit.list("H", 7, "Center", "Center"), Kit.scale() })
	if button then
		group.Text = ""
		group.AutoButtonColor = false
	end
	Kit.icon("Icon", sprite, 26, { LayoutOrder = 1, Parent = group })
	Kit.text("Label", text, 22, {
		LayoutOrder = 2,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 30),
		Parent = group,
	})
end

local function buildStats(root: Frame)
	local _, inner = Kit.card("Stats", V2(360, 54), "dark", {
		AnchorPoint = V2(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Parent = root,
	})
	local row = new("Frame", { Name = "Row", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = inner }, {
		Kit.list("H", 26, "Center", "Center"),
	})
	statGroup(row, "Time", "clock", "0:00", 1, false)
	statGroup(row, "Alive", "chick", "0/0", 2, false)
	statGroup(row, "Eggs", "eggCoin", "0", 3, true)

	-- Egg recharge and glide stamina, just above the stats bar.
	local eggs = hidden(new("Frame", {
		Name = "EggCharge",
		AnchorPoint = V2(1, 1),
		Position = UDim2.new(0.5, -10, 1, -72),
		Size = UDim2.fromOffset(150, 22),
		BackgroundTransparency = 1,
		Parent = root,
	}, { Kit.scale() }))
	Kit.icon("Icon", "egg", 24, { AnchorPoint = V2(0, 0.5), Position = UDim2.fromScale(0, 0.5), Parent = eggs })
	local eggTrack = Kit.bar("Track", V2(10, 10), T.Cream, { AnchorPoint = V2(0, 0.5), Position = UDim2.new(0, 30, 0.5, 0), Parent = eggs })
	eggTrack.Size = UDim2.new(1, -30, 0, 10)
	Kit.stroke(T.Gold, 1.5, 0.2).Parent = eggTrack

	local stamina = hidden(new("Frame", {
		Name = "Stamina",
		AnchorPoint = V2(0, 1),
		Position = UDim2.new(0.5, 10, 1, -72),
		Size = UDim2.fromOffset(150, 22),
		BackgroundTransparency = 1,
		Parent = root,
	}, { Kit.scale() }))
	Kit.icon("Icon", "feather", 24, { AnchorPoint = V2(0, 0.5), Position = UDim2.fromScale(0, 0.5), Parent = stamina })
	local track = Kit.bar("Track", V2(10, 10), T.Yellow, { AnchorPoint = V2(0, 0.5), Position = UDim2.new(0, 30, 0.5, 0), Parent = stamina })
	track.Size = UDim2.new(1, -30, 0, 10)
	Kit.stroke(T.Gold, 1.5, 0.2).Parent = track
end

local function buildObjective(root: Frame)
	local _, inner = Kit.card("Objective", V2(420, 72), "dark", {
		AnchorPoint = V2(0, 1),
		Position = UDim2.new(0, 12, 1, -68),
		Parent = root,
	})
	Kit.icon("Icon", "chick", 30, { Position = UDim2.fromOffset(10, 8), Parent = inner })
	Kit.text("Title", "WAITING FOR CHICKENS", 20, {
		Position = UDim2.fromOffset(48, 6),
		Size = UDim2.new(1, -60, 0, 26),
		TextColor3 = T.Pink,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = inner,
	})
	Kit.text("Sub", "The game starts when enough chickens are here.", 15, {
		Position = UDim2.fromOffset(48, 32),
		Size = UDim2.new(1, -60, 0, 18),
		Font = T.Body,
		TextColor3 = T.TextSoft,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = inner,
	})
	local bar = Kit.bar("Bar", V2(10, 5), T.Green, { AnchorPoint = V2(0, 1), Position = UDim2.new(0, 48, 1, -8), Visible = false, Parent = inner })
	bar.Size = UDim2.new(1, -60, 0, 5)
end

local function buildButtons(root: Frame)
	local row = new("Frame", {
		Name = "Buttons",
		AnchorPoint = V2(0, 1),
		Position = UDim2.new(0, 12, 1, -12),
		Size = UDim2.fromOffset(560, 48),
		BackgroundTransparency = 1,
		Parent = root,
	}, { Kit.list("H", 8, "Left", "Center") })
	Kit.button("Shop", "SHOP", "shop", V2(112, 48), nil, { LayoutOrder = 1, Parent = row })
	Kit.button("Emotes", "EMOTES", "emote", V2(132, 48), nil, { LayoutOrder = 2, Parent = row })
	Kit.button("Afk", "AFK", "clock", V2(96, 48), nil, { LayoutOrder = 3, Parent = row })
	Kit.button("Music", nil, "speaker", V2(48, 48), nil, { LayoutOrder = 4, Parent = row })
	Kit.button("Spectate", nil, "eye", V2(48, 48), nil, { LayoutOrder = 5, Visible = false, Parent = row })
end

local function buildBoard(root: Frame, tpl: Folder)
	local _, inner = Kit.card("Board", V2(250, 300), "cream", {
		AnchorPoint = V2(1, 0),
		Position = UDim2.new(1, -12, 0, 64),
		Parent = root,
	})
	Kit.icon("Icon", "trophy", 22, { Position = UDim2.fromOffset(12, 9), Parent = inner })
	Kit.text("Title", "TOP CHICKENS", 16, {
		Position = UDim2.fromOffset(40, 8),
		Size = UDim2.new(1, -110, 0, 22),
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextColor3 = T.Pink,
		Parent = inner,
	})
	Kit.text("Stat", "WINS", 13, {
		AnchorPoint = V2(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(60, 18),
		TextColor3 = T.InkSoft,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = inner,
	})
	Kit.text("Big", "LOBBY", 24, {
		Position = UDim2.fromOffset(12, 34),
		Size = UDim2.new(1, -24, 0, 30),
		TextColor3 = T.Ink,
		Parent = inner,
	})
	new("Frame", {
		Name = "Rows",
		Position = UDim2.fromOffset(8, 70),
		Size = UDim2.new(1, -16, 1, -78),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = inner,
	}, { Kit.list("V", 3, "Left", "Top") })

	local row = new("Frame", {
		Name = "BoardRow",
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundColor3 = T.CreamShade,
		BackgroundTransparency = 0.2,
		Parent = tpl,
	}, { Kit.corner(6) })
	Kit.text("Rank", "1.", 15, {
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.new(0, 26, 1, 0),
		Font = T.Body,
		TextColor3 = T.InkSoft,
		Parent = row,
	})
	Kit.text("Player", "Chicken", 15, {
		Position = UDim2.fromOffset(32, 0),
		Size = UDim2.new(1, -92, 1, 0),
		Font = T.Body,
		TextColor3 = T.Ink,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = row,
	})
	Kit.text("Value", "0", 15, {
		AnchorPoint = V2(1, 0),
		Position = UDim2.new(1, -8, 0, 0),
		Size = UDim2.new(0, 56, 1, 0),
		TextColor3 = T.Orange,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = row,
	})
end

local function buildFeedAndToasts(root: Frame, tpl: Folder)
	new("Frame", {
		Name = "Feed",
		Position = UDim2.fromOffset(12, 64),
		Size = UDim2.fromOffset(340, 210),
		BackgroundTransparency = 1,
		Parent = root,
	}, { Kit.list("V", 4, "Left", "Top") })
	local line = new("Frame", {
		Name = "FeedLine",
		Size = UDim2.fromOffset(340, 30),
		BackgroundColor3 = T.Dark,
		BackgroundTransparency = 0.2,
		Parent = tpl,
	}, { Kit.corner(8), Kit.stroke(T.Gold, 1, 0.55), Kit.scale() })
	Kit.icon("Icon", "info", 20, { AnchorPoint = V2(0, 0.5), Position = UDim2.new(0, 7, 0.5, 0), Parent = line })
	Kit.text("Text", "Something happened", 14, {
		Position = UDim2.fromOffset(34, 0),
		Size = UDim2.new(1, -42, 1, 0),
		Font = T.Body,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = line,
	})

	new("Frame", {
		Name = "Toasts",
		AnchorPoint = V2(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -104),
		Size = UDim2.fromOffset(420, 180),
		BackgroundTransparency = 1,
		Parent = root,
	}, { Kit.list("V", 6, "Center", "Bottom") })
	local toast = new("Frame", {
		Name = "Toast",
		Size = UDim2.fromOffset(0, 40),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = T.Dark,
		BackgroundTransparency = 0.08,
		Parent = tpl,
	}, {
		Kit.corner(10),
		Kit.stroke(T.Gold, 2),
		Kit.padding(14, 0),
		Kit.list("H", 8, "Center", "Center"),
		Kit.scale(),
	})
	Kit.icon("Icon", "eggCoin", 26, { LayoutOrder = 1, Parent = toast })
	Kit.text("Text", "+10 eggs", 19, {
		LayoutOrder = 2,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 30),
		TextColor3 = T.Yellow,
		Parent = toast,
	})
end

local function buildVote(root: Frame, tpl: Folder)
	local vote = hidden(new("Frame", {
		Name = "Vote",
		AnchorPoint = V2(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -150),
		Size = UDim2.fromOffset(720, 290),
		BackgroundTransparency = 1,
		Parent = root,
	}, { Kit.scale() }))
	local _, header = Kit.card("Header", V2(320, 46), "dark", {
		AnchorPoint = V2(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Parent = vote,
	})
	Kit.icon("Icon", "vote", 26, { AnchorPoint = V2(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0), Parent = header })
	Kit.text("Title", "VOTE FOR A MODE", 19, {
		AnchorPoint = V2(0, 0.5),
		Position = UDim2.new(0, 46, 0.5, 0),
		Size = UDim2.new(1, -110, 0, 26),
		Parent = header,
	})
	Kit.text("Timer", "15", 20, {
		AnchorPoint = V2(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(50, 26),
		TextColor3 = T.Yellow,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = header,
	})
	new("Frame", {
		Name = "Cards",
		AnchorPoint = V2(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.new(1, 0, 0, 230),
		BackgroundTransparency = 1,
		Parent = vote,
	}, { Kit.list("H", 14, "Center", "Center") })

	-- One option: a cream card button.
	local card = new("TextButton", {
		Name = "VoteCard",
		Size = UDim2.fromOffset(222, 226),
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Parent = tpl,
	}, { Kit.scale() })
	card:SetAttribute("Juicy", true)
	local _, inner = Kit.card("Border", V2(222, 226), "cream", { Size = UDim2.fromScale(1, 1), Parent = card })
	new("Frame", {
		Name = "Band",
		Size = UDim2.new(1, 0, 0, 74),
		BackgroundColor3 = T.Orange,
		Parent = inner,
	}, { Kit.corner(9), Kit.sheen(0.25) })
	Kit.icon("Icon", "chickenRun", 64, { AnchorPoint = V2(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Parent = inner })
	Kit.text("ModeName", "SOLO", 22, {
		Position = UDim2.fromOffset(10, 80),
		Size = UDim2.new(1, -20, 0, 28),
		TextColor3 = T.Ink,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = inner,
	})
	Kit.text("Desc", "Description", 14, {
		Position = UDim2.fromOffset(12, 108),
		Size = UDim2.new(1, -24, 0, 56),
		Font = T.Body,
		TextColor3 = T.InkSoft,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = inner,
	})
	local bar = Kit.bar("Bar", V2(10, 20), T.Orange, { AnchorPoint = V2(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Parent = inner })
	bar.Size = UDim2.new(1, -28, 0, 20)
	Kit.text("Votes", "0", 14, {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
		Parent = bar,
	})
	Kit.icon("Check", "check", 34, { AnchorPoint = V2(1, 0), Position = UDim2.new(1, 8, 0, -8), Visible = false, ZIndex = 5, Parent = card })
end

local function buildBigMoments(root: Frame)
	-- Mode intro during the countdown.
	local _, introInner = Kit.card("Intro", V2(540, 140), "cream", {
		AnchorPoint = V2(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.36),
		Visible = false,
		Parent = root,
	})
	Kit.icon("Icon", "chickenRun", 96, { AnchorPoint = V2(0, 0.5), Position = UDim2.new(0, 16, 0.5, 0), Parent = introInner })
	Kit.text("Title", "SOLO", 40, {
		Position = UDim2.fromOffset(128, 16),
		Size = UDim2.new(1, -144, 0, 46),
		TextColor3 = T.Orange,
		Parent = introInner,
	})
	Kit.text("Desc", "Every chicken for itself.", 17, {
		Position = UDim2.fromOffset(130, 64),
		Size = UDim2.new(1, -146, 0, 56),
		Font = T.Body,
		TextColor3 = T.Ink,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = introInner,
	})

	-- 3, 2, 1, GO!
	local countdown = hidden(new("Frame", {
		Name = "Countdown",
		AnchorPoint = V2(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(300, 200),
		BackgroundTransparency = 1,
		Parent = root,
	}, { Kit.scale() }))
	Kit.sunburst("Sunburst", 420, { Parent = countdown })
	local number = Kit.text("Number", "3", 130, {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = T.Yellow,
		Parent = countdown,
	})
	Kit.textStroke(number, 5)

	-- Winner screen.
	local results = hidden(new("Frame", {
		Name = "Results",
		AnchorPoint = V2(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(480, 270),
		BackgroundTransparency = 1,
		Parent = root,
	}, { Kit.scale() }))
	Kit.sunburst("Sunburst", 560, { Parent = results })
	local _, rInner = Kit.card("Card", V2(480, 220), "cream", {
		AnchorPoint = V2(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Parent = results,
	})
	Kit.text("Title", "WINNER!", 42, {
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 0, 48),
		TextColor3 = T.Orange,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = rInner,
	})
	Kit.text("Winner", "", 18, {
		Position = UDim2.fromOffset(16, 92),
		Size = UDim2.new(1, -32, 0, 48),
		Font = T.Body,
		TextColor3 = T.Ink,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = rInner,
	})
	Kit.chip("Reward", "eggCoin", "+0", V2(150, 40), {
		AnchorPoint = V2(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Visible = false,
		Parent = rInner,
	})
	Kit.icon("Icon", "crown", 92, { AnchorPoint = V2(0.5, 0), Position = UDim2.fromScale(0.5, 0), ZIndex = 3, Parent = results })

	-- Sudden death banner with hazard stripes.
	local banner = hidden(new("Frame", {
		Name = "SuddenDeath",
		AnchorPoint = V2(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.new(1.3, 0, 0, 76),
		BackgroundColor3 = rgb(40, 22, 20),
		Rotation = -3,
		Parent = root,
	}, { Kit.stroke(T.Gold, 3) }))
	Kit.icon("Stripes", "stripes", 64, {
		Size = UDim2.fromScale(1, 1),
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(56, 56),
		ImageTransparency = 0.25,
		Parent = banner,
	})
	local label = Kit.text("Label", "SUDDEN DEATH!", 50, {
		Size = UDim2.fromScale(1, 1),
		TextColor3 = rgb(255, 96, 80),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 2,
		Parent = banner,
	})
	Kit.textStroke(label, 4)
end

local function buildSpectate(root: Frame)
	local bar = hidden(new("Frame", {
		Name = "SpectateBar",
		AnchorPoint = V2(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -74),
		Size = UDim2.fromOffset(400, 48),
		BackgroundTransparency = 1,
		Parent = root,
	}, { Kit.list("H", 8, "Center", "Center"), Kit.scale() }))
	Kit.button("Prev", nil, "arrowLeft", V2(48, 48), nil, { LayoutOrder = 1, Parent = bar })
	local _, inner = Kit.card("NameCard", V2(272, 48), "dark", { LayoutOrder = 2, Parent = bar })
	Kit.icon("Icon", "eye", 24, { AnchorPoint = V2(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), Parent = inner })
	Kit.text("Player", "Spectating", 18, {
		AnchorPoint = V2(0, 0.5),
		Position = UDim2.new(0, 42, 0.5, 0),
		Size = UDim2.new(1, -52, 0, 26),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = inner,
	})
	Kit.button("Next", nil, "arrowRight", V2(48, 48), nil, { LayoutOrder = 3, Parent = bar })
end

local function buildOverlays(root: Frame)
	Kit.icon("Splat", "splat", 380, {
		AnchorPoint = V2(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		ImageColor3 = rgb(255, 250, 235),
		Visible = false,
		ZIndex = 8,
		Parent = root,
	})
	-- Red screen edges when a car is about to hit you.
	local danger = new("Frame", {
		Name = "Danger",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 7,
		Parent = root,
	})
	type Edge = { name: string, size: UDim2, pos: UDim2, rot: number }
	local edges: { Edge } = {
		{ name = "Top", size = UDim2.fromScale(1, 0.18), pos = UDim2.fromScale(0, 0), rot = 90 },
		{ name = "Bottom", size = UDim2.fromScale(1, 0.18), pos = UDim2.fromScale(0, 0.82), rot = -90 },
		{ name = "Left", size = UDim2.fromScale(0.12, 1), pos = UDim2.fromScale(0, 0), rot = 0 },
		{ name = "Right", size = UDim2.fromScale(0.12, 1), pos = UDim2.fromScale(0.88, 0), rot = 180 },
	}
	for _, e in edges do
		new("Frame", {
			Name = e.name,
			Size = e.size,
			Position = e.pos,
			BackgroundColor3 = rgb(255, 40, 40),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 7,
			Parent = danger,
		}, {
			new("UIGradient", {
				Rotation = e.rot,
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
			}),
		})
	end
	new("Frame", {
		Name = "Flash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 9,
		Parent = root,
	})
end

local function buildHud(parent: Instance)
	local hud, root = Kit.screen("Hud", 1)
	local tpl = templates(hud)
	buildRoundCard(root)
	buildStats(root)
	buildObjective(root)
	buildButtons(root)
	buildBoard(root, tpl)
	buildFeedAndToasts(root, tpl)
	buildVote(root, tpl)
	buildSpectate(root)
	buildBigMoments(root)
	buildOverlays(root)
	hud.Parent = parent
end

-- SHOP --------------------------------------------------------------------------------------

local SHOP_TABS = {
	{ "ChickenSkin", "chicken", "SKINS" },
	{ "EggSkin", "egg", "AMMO" },
	{ "HitEffect", "boom", "HITS" },
	{ "WinEffect", "trophy", "WINS" },
	{ "Emote", "emote", "EMOTES" },
	{ "Coins", "basket", "EGGS" },
}

local function buildShop(parent: Instance)
	local shop, root = Kit.screen("Shop", 5)
	local tpl = templates(shop)
	new("TextButton", {
		Name = "Dim",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = rgb(20, 12, 8),
		BackgroundTransparency = 0.45,
		AutoButtonColor = false,
		Text = "",
		Visible = false,
		Parent = root,
	})
	local _, inner = Kit.card("Panel", V2(900, 560), "cream", {
		AnchorPoint = V2(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Visible = false,
		Parent = root,
	})

	local header = new("Frame", {
		Name = "Header",
		Position = UDim2.fromOffset(18, 12),
		Size = UDim2.new(1, -36, 0, 48),
		BackgroundTransparency = 1,
		Parent = inner,
	})
	Kit.icon("Icon", "shop", 42, { AnchorPoint = V2(0, 0.5), Position = UDim2.fromScale(0, 0.5), Parent = header })
	Kit.text("Title", "SHOP", 34, {
		AnchorPoint = V2(0, 0.5),
		Position = UDim2.new(0, 52, 0.5, 0),
		Size = UDim2.fromOffset(200, 40),
		TextColor3 = T.Ink,
		Parent = header,
	})
	Kit.chip("Coins", "eggCoin", "0", V2(160, 40), { AnchorPoint = V2(1, 0.5), Position = UDim2.new(1, -58, 0.5, 0), Parent = header })
	Kit.button("Close", nil, "close", V2(46, 46), nil, { AnchorPoint = V2(1, 0.5), Position = UDim2.fromScale(1, 0.5), Parent = header })

	local tabs = new("Frame", {
		Name = "Tabs",
		Position = UDim2.fromOffset(18, 70),
		Size = UDim2.new(1, -36, 0, 44),
		BackgroundTransparency = 1,
		Parent = inner,
	}, { Kit.list("H", 8, "Left", "Center") })
	for i, spec in SHOP_TABS do
		Kit.button(spec[1], spec[3], spec[2], V2(136, 44), nil, { LayoutOrder = i, Parent = tabs })
	end

	new("ScrollingFrame", {
		Name = "Grid",
		Position = UDim2.fromOffset(18, 124),
		Size = UDim2.new(1, -36, 1, -138),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = T.Frame,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = inner,
	}, {
		Kit.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(156, 212),
			CellPadding = UDim2.fromOffset(12, 12),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
		Kit.padding(6),
	})

	-- Item card template.
	local card, cInner = Kit.card("ItemCard", V2(156, 212), "cream", { Parent = tpl })
	local band = new("Frame", {
		Name = "RarityBar",
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = cInner,
	}, {
		Kit.corner(9),
		new("UIGradient", { Name = "RarityGradient", Color = ColorSequence.new(T.Grey, T.Grey), Rotation = 90 }),
	})
	Kit.text("Rarity", "COMMON", 13, {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 2,
		Parent = band,
	})
	Kit.icon("Glow", "glow", 130, {
		AnchorPoint = V2(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 78),
		ImageTransparency = 0.45,
		Parent = cInner,
	})
	new("ViewportFrame", {
		Name = "Preview",
		AnchorPoint = V2(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 28),
		Size = UDim2.fromOffset(110, 100),
		BackgroundTransparency = 1,
		Ambient = rgb(200, 200, 200),
		LightColor = rgb(255, 250, 240),
		Parent = cInner,
	})
	Kit.icon("PreviewIcon", "egg", 80, {
		AnchorPoint = V2(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 36),
		Visible = false,
		Parent = cInner,
	})
	Kit.text("ItemName", "Item", 16, {
		Position = UDim2.fromOffset(6, 130),
		Size = UDim2.new(1, -12, 0, 22),
		TextColor3 = T.Ink,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = cInner,
	})
	Kit.button("Action", "EQUIP", "eggCoin", V2(132, 38), T.Green, {
		AnchorPoint = V2(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Parent = cInner,
	})
	Kit.icon("Equipped", "check", 30, { AnchorPoint = V2(1, 0), Position = UDim2.new(1, 6, 0, -6), Visible = false, ZIndex = 5, Parent = card })
	Kit.icon("Lock", "lock", 24, { Position = UDim2.fromOffset(-4, -6), Visible = false, ZIndex = 5, Parent = card })
	-- A sheen that sweeps across rare cards.
	new("Frame", {
		Name = "Shine",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.55,
		Visible = false,
		ZIndex = 4,
		Parent = cInner,
	}, {
		Kit.corner(9),
		new("UIGradient", {
			Rotation = 25,
			Offset = V2(-1, 0),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.45, 1),
				NumberSequenceKeypoint.new(0.5, 0.2),
				NumberSequenceKeypoint.new(0.55, 1),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})

	-- Egg pack / VIP card template.
	local pack = card:Clone()
	pack.Name = "PackCard"
	pack.Parent = tpl

	shop.Parent = parent
end

-- EMOTES ------------------------------------------------------------------------------------

local function buildEmotes(parent: Instance)
	local emotes, root = Kit.screen("Emotes", 4)
	local _, inner = Kit.card("Picker", V2(276, 164), "dark", {
		AnchorPoint = V2(0, 1),
		Position = UDim2.new(0, 12, 1, -150),
		Visible = false,
		Parent = root,
	})
	Kit.text("Title", "EMOTES", 18, { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -60, 0, 24), Parent = inner })
	Kit.button("Close", nil, "close", V2(30, 30), nil, { AnchorPoint = V2(1, 0), Position = UDim2.new(1, -6, 0, 4), Parent = inner })
	local slots = new("Frame", {
		Name = "Slots",
		Position = UDim2.fromOffset(8, 40),
		Size = UDim2.new(1, -16, 1, -48),
		BackgroundTransparency = 1,
		Parent = inner,
	}, {
		Kit.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(124, 50),
			CellPadding = UDim2.fromOffset(4, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for i = 1, 4 do
		local slot = Kit.button(`Slot{i}`, "EMPTY", nil, V2(124, 50), nil, { LayoutOrder = i, Parent = slots })
		Kit.text("Key", tostring(i), 13, {
			Position = UDim2.fromOffset(7, 3),
			Size = UDim2.fromOffset(14, 16),
			TextColor3 = T.Yellow,
			ZIndex = 4,
			Parent = slot,
		})
	end
	emotes.Parent = parent
end

-- DRIVER ------------------------------------------------------------------------------------

local function buildDriver(parent: Instance)
	local driver, root = Kit.screen("Driver", 3)
	driver.Enabled = false
	local _, inner = Kit.card("Banner", V2(520, 56), "dark", {
		AnchorPoint = V2(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 84),
		Parent = root,
	})
	Kit.icon("Icon", "angry", 34, { AnchorPoint = V2(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0), Parent = inner })
	Kit.text("Label", "ROAD RAGE! RUN THEM OVER!", 22, {
		AnchorPoint = V2(0, 0.5),
		Position = UDim2.new(0, 56, 0.5, 0),
		Size = UDim2.new(1, -68, 0, 28),
		TextColor3 = rgb(255, 120, 100),
		Parent = inner,
	})

	local controls = new("Frame", {
		Name = "Controls",
		AnchorPoint = V2(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -76),
		Size = UDim2.fromOffset(560, 200),
		BackgroundTransparency = 1,
		Parent = root,
	})
	Kit.button("Up", nil, "arrowUp", V2(84, 64), T.Blue, { AnchorPoint = V2(0.5, 0), Position = UDim2.fromScale(0.5, 0), Parent = controls })
	Kit.button("Down", nil, "arrowDown", V2(84, 64), T.Blue, { AnchorPoint = V2(0.5, 0), Position = UDim2.fromOffset(280, 72), Parent = controls })
	Kit.button("Left", "GO", "arrowLeft", V2(150, 64), T.Red, { Position = UDim2.fromOffset(20, 40), Parent = controls })
	Kit.button("Right", "GO", "arrowRight", V2(150, 64), T.Red, { AnchorPoint = V2(1, 0), Position = UDim2.new(1, -20, 0, 40), Parent = controls })
	local cooldown = Kit.bar("Cooldown", V2(420, 30), T.Yellow, { AnchorPoint = V2(0.5, 1), Position = UDim2.fromScale(0.5, 1), Parent = controls })
	Kit.stroke(T.Gold, 2).Parent = cooldown
	Kit.text("Hint", "W/S lane - A/D send a car", 16, {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
		Parent = cooldown,
	})
	driver.Parent = parent
end

GuiBuilder.Names = { "Hud", "Shop", "Emotes", "Driver" }
-- Bump when the GUI changes enough that older built copies should be replaced.
GuiBuilder.Version = 4

function GuiBuilder.build(parent: Instance, only: string?)
	local builders: { [string]: (Instance) -> () } = {
		Hud = buildHud,
		Shop = buildShop,
		Emotes = buildEmotes,
		Driver = buildDriver,
	}
	for _, name in GuiBuilder.Names do
		if (only == nil or only == name) and not parent:FindFirstChild(name) then
			builders[name](parent)
			-- GUI inside a Folder still renders, so templates must start hidden.
			local screen = parent:FindFirstChild(name)
			if screen then
				screen:SetAttribute("GuiVersion", GuiBuilder.Version)
			end
			local tpl = screen and screen:FindFirstChild("Templates")
			if tpl then
				for _, t in tpl:GetChildren() do
					if t:IsA("GuiObject") then
						t.Visible = false
					end
				end
			end
		end
	end
end

return GuiBuilder
