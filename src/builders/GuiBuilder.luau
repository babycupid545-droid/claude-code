--!strict
-- Builds every ScreenGui into StarterGui so you can see and tweak the UI in Studio.
-- The client scripts find pieces by name, so rename with care (restyle freely).
--
--   Hud     status bar, timer, players left, side menu, feed, toasts, stamina, spectate,
--           mode intro, countdown, results, voting, sudden death banner, screen effects
--   Shop    tabs, item grid, item/pack card templates
--   Emotes  emote wheel
--   Driver  Road Rage controls

local Kit = require(script.Parent.GuiKit)

local GuiBuilder = {}

local T = Kit.Theme
local new = Kit.new
local rgb = Color3.fromRGB

local function templates(parent: Instance): Folder
	return new("Folder", { Name = "Templates", Parent = parent })
end

-- HUD ---------------------------------------------------------------------------------------

local function buildTop(hud: ScreenGui)
	local top = new("Frame", {
		Name = "Top",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromScale(1, 0.15),
		BackgroundTransparency = 1,
		Parent = hud,
	}, { Kit.aspect(4), Kit.list("V", 0.06) })

	local status = Kit.pill("Status", { LayoutOrder = 1, Size = UDim2.fromScale(0.78, 0.55), Parent = top })
	new("Frame", { Name = "Row", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = status }, {
		Kit.list("H", 0.03),
		Kit.padding(0.08),
	})
	local row = status:FindFirstChild("Row") :: Frame
	Kit.icon("Icon", "clock", { LayoutOrder = 1, Size = UDim2.fromScale(1, 1.25), Parent = row })
	Kit.text("Title", "WAITING", { LayoutOrder = 2, Font = T.TitleFont, Size = UDim2.fromScale(0.52, 1), MaxTextSize = 34, Parent = row })
	local timerPill = new("Frame", {
		Name = "TimerPill",
		LayoutOrder = 3,
		Size = UDim2.fromScale(0.27, 1),
		BackgroundColor3 = T.Yellow,
		Parent = row,
	}, { Kit.corner(0.5, true), Kit.stroke(3), Kit.vgradient(Color3.new(1, 1, 1), rgb(230, 200, 150)) })
	Kit.text("Timer", "0:00", { Font = T.TitleFont, MaxTextSize = 32, Parent = timerPill })

	local info = new("Frame", {
		Name = "Info",
		LayoutOrder = 2,
		Size = UDim2.fromScale(0.78, 0.36),
		BackgroundTransparency = 1,
		Parent = top,
	}, { Kit.list("H", 0.03) })
	type PillSpec = { name: string, sprite: string, text: string, width: number }
	local pills: { PillSpec } = {
		{ name = "Mode", sprite = "chickenRun", text = "SOLO", width = 0.48 },
		{ name = "Alive", sprite = "users", text = "0 LEFT", width = 0.36 },
	}
	for i, spec in pills do
		local pill = Kit.pill(spec.name, {
			LayoutOrder = i,
			Size = UDim2.fromScale(spec.width, 1),
			Visible = false,
			Parent = info,
		})
		local inner = new("Frame", { Name = "Row", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = pill }, {
			Kit.list("H", 0.04),
			Kit.padding(0.1),
		})
		Kit.icon("Icon", spec.sprite, { LayoutOrder = 1, Size = UDim2.fromScale(1, 1.3), Parent = inner })
		Kit.text("Label", spec.text, { LayoutOrder = 2, Font = T.TitleFont, Size = UDim2.fromScale(0.7, 1), MaxTextSize = 24, Parent = inner })
	end
end

-- Under the top bar: where to run next (with a countdown bar), and the current event.
local function buildBanners(hud: ScreenGui)
	local cross = Kit.sign("CrossBanner", "RUN TO THE WINDMILL!", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.165),
		Size = UDim2.fromScale(0.5, 0.085),
		Visible = false,
		Parent = hud,
	})
	Kit.aspect(6.5).Parent = cross
	local label = cross:FindFirstChild("Label") :: TextLabel
	label.Size = UDim2.fromScale(0.66, 0.6)
	label.Position = UDim2.fromScale(0.5, 0.4)
	Kit.icon("Icon", "windmill", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.07, 0.45),
		Size = UDim2.fromScale(1.35, 1.35),
		ZIndex = 4,
		Parent = cross,
	})
	local time = new("Frame", {
		Name = "TimePill",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.92, 0.45),
		Size = UDim2.fromScale(0.13, 0.78),
		BackgroundColor3 = T.Yellow,
		ZIndex = 4,
		Parent = cross,
	}, { Kit.corner(0.5, true), Kit.stroke(3), Kit.vgradient(Color3.new(1, 1, 1), rgb(230, 200, 150)) })
	Kit.text("Time", "9", { Font = T.TitleFont, MaxTextSize = 30, ZIndex = 5, Parent = time })
	local track = new("Frame", {
		Name = "Track",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.9),
		Size = UDim2.fromScale(0.66, 0.16),
		BackgroundColor3 = T.PillBg,
		ZIndex = 4,
		Parent = cross,
	}, { Kit.corner(0.5, true), Kit.stroke(2) })
	new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = T.Green,
		ZIndex = 5,
		Parent = track,
	}, { Kit.corner(0.5, true), Kit.vgradient(Color3.new(1, 1, 1), rgb(190, 200, 190)) })

	local event = Kit.ribbon("EventBanner", "SPEED DEMONS", T.Purple, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.262),
		Size = UDim2.fromScale(0.42, 0.075),
		Visible = false,
		Parent = hud,
	})
	Kit.aspect(5.2).Parent = event
	local eventLabel = event:FindFirstChild("Label") :: TextLabel
	eventLabel.Size = UDim2.fromScale(0.58, 0.6)
	Kit.icon("Icon", "lightning", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.11, 0.42),
		Size = UDim2.fromScale(1.15, 1.15),
		ZIndex = 4,
		Parent = event,
	})
	Kit.text("Desc", "Cars are way faster!", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.92),
		Size = UDim2.fromScale(1.1, 0.5),
		MaxTextSize = 22,
		ZIndex = 4,
		Parent = event,
	})
	Kit.text("Time", "", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.86, 0.45),
		Size = UDim2.fromScale(0.1, 0.5),
		Font = T.TitleFont,
		TextColor3 = T.Yellow,
		MaxTextSize = 26,
		ZIndex = 4,
		Parent = event,
	})
end

local function buildSide(hud: ScreenGui)
	local side = new("Frame", {
		Name = "Side",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.45, 0),
		Size = UDim2.fromScale(0.5, 0.42),
		BackgroundTransparency = 1,
		Parent = hud,
	}, { Kit.aspect(0.42), Kit.list("V", 0.035, "Left") })

	local coins = Kit.pill("Coins", { LayoutOrder = 1, Size = UDim2.fromScale(1, 0.16), Parent = side })
	local row = new("Frame", { Name = "Row", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = coins }, {
		Kit.list("H", 0.04, "Left"),
		Kit.padding(0.06),
	})
	Kit.icon("Icon", "eggCoin", { LayoutOrder = 1, Size = UDim2.fromScale(1, 1.35), Parent = row })
	Kit.text("Amount", "0", { LayoutOrder = 2, Font = T.TitleFont, Size = UDim2.fromScale(0.5, 1), TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 30, Parent = row })
	Kit.button("Plus", T.Green, "+", nil, { LayoutOrder = 3, Size = UDim2.fromScale(0.22, 1.05), Parent = row })

	Kit.button("Shop", T.Yellow, "SHOP", "shop", { LayoutOrder = 2, Size = UDim2.fromScale(1, 0.22), Parent = side })
	Kit.button("Emotes", T.Blue, "EMOTES", "emote", { LayoutOrder = 3, Size = UDim2.fromScale(1, 0.22), Parent = side })
	local small = new("Frame", { Name = "Small", LayoutOrder = 4, Size = UDim2.fromScale(1, 0.2), BackgroundTransparency = 1, Parent = side }, {
		Kit.list("H", 0.06, "Left"),
	})
	Kit.button("Music", T.Purple, nil, "speaker", { LayoutOrder = 1, Size = UDim2.fromScale(0.44, 1), Parent = small })
	Kit.button("Spectate", T.Pink, nil, "eye", { LayoutOrder = 2, Size = UDim2.fromScale(0.44, 1), Visible = false, Parent = small })
end

local function buildFeedAndToasts(hud: ScreenGui, tpl: Folder)
	new("Frame", {
		Name = "Feed",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 8),
		Size = UDim2.fromScale(1, 0.3),
		BackgroundTransparency = 1,
		Parent = hud,
	}, { Kit.aspect(1.5), Kit.list("V", 0.03, "Right") })

	local line = Kit.pill("FeedLine", { Size = UDim2.fromScale(1, 0.15), AutomaticSize = Enum.AutomaticSize.None, Parent = tpl })
	local row = new("Frame", { Name = "Row", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = line }, {
		Kit.list("H", 0.02, "Left"),
		Kit.padding(0.12),
	})
	Kit.icon("Icon", "skull", { LayoutOrder = 1, Size = UDim2.fromScale(1, 1.2), Parent = row })
	Kit.text("Text", "Chicken got flattened", { LayoutOrder = 2, Size = UDim2.fromScale(0.85, 1), TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 20, Parent = row })

	new("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.82),
		Size = UDim2.fromScale(1, 0.22),
		BackgroundTransparency = 1,
		Parent = hud,
	}, {
		Kit.aspect(2.6),
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0.03, 0),
		}),
	})
	local toast = Kit.pill("Toast", { Size = UDim2.fromScale(0.8, 0.24), BackgroundColor3 = rgb(150, 46, 38), Parent = tpl })
	new("UIScale", { Name = "AnimScale", Parent = toast })
	local trow = new("Frame", { Name = "Row", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = toast }, {
		Kit.list("H", 0.03),
		Kit.padding(0.1),
	})
	Kit.icon("Icon", "eggCoin", { LayoutOrder = 1, Size = UDim2.fromScale(1, 1.3), Parent = trow })
	Kit.text("Text", "+10 eggs", { LayoutOrder = 2, Font = T.TitleFont, Size = UDim2.fromScale(0.82, 1), TextColor3 = T.Yellow, MaxTextSize = 28, Parent = trow })
end

local function buildStamina(hud: ScreenGui)
	local stamina = new("Frame", {
		Name = "Stamina",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.91),
		Size = UDim2.fromScale(1, 0.045),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = hud,
	}, { Kit.aspect(7), new("UIScale", { Name = "AnimScale" }) })
	Kit.icon("Icon", "feather", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.02, 0.5),
		Size = UDim2.fromScale(1, 1.8),
		ZIndex = 3,
		Parent = stamina,
	})
	local track = new("Frame", {
		Name = "Track",
		Position = UDim2.fromScale(0.06, 0.1),
		Size = UDim2.fromScale(0.94, 0.8),
		BackgroundColor3 = T.PillBg,
		Parent = stamina,
	}, { Kit.corner(0.5, true), Kit.stroke(3) })
	new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = track,
	}, {
		Kit.corner(0.5, true),
		new("UIGradient", { Color = ColorSequence.new(rgb(255, 236, 140), rgb(246, 176, 50)) }),
	})
end

local function buildSpectate(hud: ScreenGui)
	local bar = new("Frame", {
		Name = "SpectateBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.97),
		Size = UDim2.fromScale(1, 0.085),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = hud,
	}, { Kit.aspect(6), Kit.list("H", 0.02), new("UIScale", { Name = "AnimScale" }) })
	Kit.button("Prev", T.Blue, nil, "arrowLeft", { LayoutOrder = 1, Size = UDim2.fromScale(0.16, 1), Parent = bar })
	local name = Kit.pill("NamePill", { LayoutOrder = 2, Size = UDim2.fromScale(0.6, 0.85), Parent = bar })
	local row = new("Frame", { Name = "Row", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = name }, {
		Kit.list("H", 0.03),
		Kit.padding(0.1),
	})
	Kit.icon("Icon", "eye", { LayoutOrder = 1, Size = UDim2.fromScale(1, 1.2), Parent = row })
	Kit.text("Player", "Spectating", { LayoutOrder = 2, Font = T.TitleFont, Size = UDim2.fromScale(0.8, 1), MaxTextSize = 30, Parent = row })
	Kit.button("Next", T.Blue, nil, "arrowRight", { LayoutOrder = 3, Size = UDim2.fromScale(0.16, 1), Parent = bar })
end

local function centerBlock(hud: ScreenGui, name: string, heightScale: number, aspect: number): Frame
	return new("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromScale(1, heightScale),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = hud,
	}, { Kit.aspect(aspect), new("UIScale", { Name = "AnimScale" }) })
end

local function buildBigMoments(hud: ScreenGui)
	-- Mode intro during the countdown.
	local intro = centerBlock(hud, "Intro", 0.42, 1.9)
	Kit.sunburst("Sunburst", { Size = UDim2.fromScale(0.9, 1.7), ImageTransparency = 0.6, Parent = intro })
	Kit.icon("Icon", "chickenRun", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(1, 0.42), Parent = intro })
	Kit.text("Title", "SOLO", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromScale(1, 0.3), Font = T.TitleFont, TextColor3 = T.Yellow, MaxTextSize = 90, StrokeThickness = 4, Parent = intro })
	Kit.text("Desc", "Every chicken for itself.", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.74), Size = UDim2.fromScale(0.95, 0.18), MaxTextSize = 34, Parent = intro })

	-- 3, 2, 1, GO!
	local countdown = centerBlock(hud, "Countdown", 0.3, 1)
	countdown.Position = UDim2.fromScale(0.5, 0.55)
	Kit.sunburst("Sunburst", { Size = UDim2.fromScale(1.6, 1.6), Parent = countdown })
	Kit.text("Number", "3", { Font = T.TitleFont, TextColor3 = T.Yellow, MaxTextSize = 200, StrokeThickness = 6, Parent = countdown })

	-- Winner screen.
	local results = centerBlock(hud, "Results", 0.5, 1.6)
	Kit.sunburst("Sunburst", { Size = UDim2.fromScale(1.1, 1.75), Parent = results })
	Kit.icon("Icon", "crown", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(1, 0.32), Parent = results })
	Kit.ribbon("TitleRibbon", "", T.Barn, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.fromScale(0.8, 0.32), ZIndex = 0, Parent = results })
	Kit.text("Title", "WINNER!", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.32), Size = UDim2.fromScale(1, 0.28), Font = T.TitleFont, TextColor3 = T.Yellow, MaxTextSize = 96, StrokeThickness = 5, Parent = results })
	Kit.text("Winner", "", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.6), Size = UDim2.fromScale(1, 0.16), MaxTextSize = 44, Parent = results })
	local reward = Kit.pill("Reward", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.8), Size = UDim2.fromScale(0.45, 0.15), Visible = false, Parent = results })
	local rrow = new("Frame", { Name = "Row", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = reward }, {
		Kit.list("H", 0.04),
		Kit.padding(0.1),
	})
	Kit.icon("Icon", "eggCoin", { LayoutOrder = 1, Size = UDim2.fromScale(1, 1.3), Parent = rrow })
	Kit.text("Label", "+0", { LayoutOrder = 2, Font = T.TitleFont, TextColor3 = T.Yellow, Size = UDim2.fromScale(0.6, 1), MaxTextSize = 34, Parent = rrow })

	-- Sudden death banner with hazard stripes.
	local banner = new("Frame", {
		Name = "SuddenDeath",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromScale(1.2, 0.11),
		BackgroundColor3 = rgb(30, 25, 30),
		Visible = false,
		Rotation = -3,
		Parent = hud,
	}, { Kit.stroke(5) })
	local stripes = Kit.icon("Stripes", "stripes", {
		Size = UDim2.fromScale(1, 1),
		SizeConstraint = Enum.SizeConstraint.RelativeXY,
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(64, 64),
		Parent = banner,
	})
	stripes.ImageTransparency = 0.1
	Kit.text("Label", "SUDDEN DEATH!", { Font = T.TitleFont, TextColor3 = T.Red, MaxTextSize = 80, StrokeThickness = 6, ZIndex = 2, Parent = banner })
end

local function buildVote(hud: ScreenGui, tpl: Folder)
	local vote = new("Frame", {
		Name = "Vote",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.97),
		Size = UDim2.fromScale(1, 0.5),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = hud,
	}, { Kit.aspect(2.3), new("UIScale", { Name = "AnimScale" }) })
	local header = Kit.pill("Header", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromScale(0.62, 0.17),
		BackgroundColor3 = T.Barn,
		BackgroundTransparency = 0,
		Parent = vote,
	})
	local hrow = new("Frame", { Name = "Row", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = header }, {
		Kit.list("H", 0.03),
		Kit.padding(0.1),
	})
	Kit.icon("Icon", "vote", { LayoutOrder = 1, Size = UDim2.fromScale(1, 1.3), Parent = hrow })
	Kit.text("Title", "VOTE FOR A MODE", { LayoutOrder = 2, Font = T.TitleFont, Size = UDim2.fromScale(0.62, 1), MaxTextSize = 36, Parent = hrow })
	Kit.text("Timer", "15", { LayoutOrder = 3, Font = T.TitleFont, TextColor3 = T.Yellow, Size = UDim2.fromScale(0.15, 1), MaxTextSize = 36, Parent = hrow })
	new("Frame", {
		Name = "Cards",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromScale(1, 0.76),
		BackgroundTransparency = 1,
		Parent = vote,
	}, { Kit.list("H", 0.025) })

	-- One card per mode option.
	local card = Kit.button("VoteCard", T.Blue, nil, nil, { Size = UDim2.fromScale(0.31, 1) }, 0.12)
	card.Parent = tpl
	local face = card:FindFirstChild("Face") :: Frame
	local content = face:FindFirstChild("Content") :: Frame
	content:ClearAllChildren()
	Kit.sunburst("Burst", { Size = UDim2.fromScale(1.3, 1.3), Position = UDim2.fromScale(0.5, 0.3), ImageTransparency = 0.75, ZIndex = 2, Parent = content })
	Kit.icon("Icon", "chickenRun", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.04), Size = UDim2.fromScale(1, 0.36), ZIndex = 3, Parent = content })
	Kit.text("ModeName", "SOLO", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.fromScale(0.94, 0.17), Font = T.TitleFont, MaxTextSize = 34, ZIndex = 3, Parent = content })
	Kit.text("Desc", "Description", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.565), Size = UDim2.fromScale(0.92, 0.215), MaxTextSize = 18, TextColor3 = rgb(255, 250, 235), ZIndex = 3, Parent = content })
	local barTrack = new("Frame", {
		Name = "Bar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.815),
		Size = UDim2.fromScale(0.86, 0.12),
		BackgroundColor3 = T.PillBg,
		ZIndex = 3,
		Parent = content,
	}, { Kit.corner(0.5, true), Kit.stroke(2) })
	new("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.Yellow, ZIndex = 4, Parent = barTrack }, {
		Kit.corner(0.5, true),
	})
	Kit.text("Votes", "0", { Font = T.TitleFont, ZIndex = 5, MaxTextSize = 20, Parent = barTrack })
	Kit.icon("Check", "check", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.92, 0.06),
		Size = UDim2.fromScale(0.3, 0.3),
		SizeConstraint = Enum.SizeConstraint.RelativeXX,
		Visible = false,
		ZIndex = 6,
		Parent = card,
	})
end

local function buildOverlays(hud: ScreenGui)
	local splat = Kit.icon("Splat", "splat", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.7, 0.7),
		Visible = false,
		ZIndex = 20,
		Parent = hud,
	})
	splat:SetAttribute("Overlay", true)

	local danger = new("Frame", {
		Name = "Danger",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 19,
		Parent = hud,
	})
	type EdgeSpec = { size: UDim2, pos: UDim2, rot: number }
	local edges: { EdgeSpec } = {
		{ size = UDim2.fromScale(1, 0.18), pos = UDim2.fromScale(0, 0), rot = 90 },
		{ size = UDim2.fromScale(1, 0.18), pos = UDim2.fromScale(0, 0.82), rot = -90 },
		{ size = UDim2.fromScale(0.12, 1), pos = UDim2.fromScale(0, 0), rot = 0 },
		{ size = UDim2.fromScale(0.12, 1), pos = UDim2.fromScale(0.88, 0), rot = 180 },
	}
	for _, spec in edges do
		new("Frame", {
			Name = "Edge",
			Size = spec.size,
			Position = spec.pos,
			BackgroundColor3 = rgb(255, 40, 40),
			BorderSizePixel = 0,
			ZIndex = 19,
			Parent = danger,
		}, {
			new("UIGradient", {
				Rotation = spec.rot,
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
			}),
		})
	end

	new("Frame", {
		Name = "Flash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 30,
		Parent = hud,
	})
end

local function buildHud(parent: Instance)
	local hud = Kit.screen("Hud", 1)
	local tpl = templates(hud)
	buildTop(hud)
	buildBanners(hud)
	buildSide(hud)
	buildFeedAndToasts(hud, tpl)
	buildStamina(hud)
	buildSpectate(hud)
	buildBigMoments(hud)
	buildVote(hud, tpl)
	buildOverlays(hud)
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
	local shop = Kit.screen("Shop", 10)
	shop.Enabled = true
	local tpl = templates(shop)
	new("TextButton", {
		Name = "Dim",
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Visible = false,
		Parent = shop,
	})
	local panel, body = Kit.panel("Panel", nil, nil, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(0.92, 0.84),
		Visible = false,
		Parent = shop,
	})
	new("UISizeConstraint", { MaxSize = Vector2.new(960, 600), Parent = panel })

	local header = new("Frame", {
		Name = "Header",
		Size = UDim2.fromScale(1, 0.15),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = body,
	}, { Kit.padding(0.12) })
	Kit.icon("Icon", "shop", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromScale(1, 1.5), Parent = header })
	Kit.text("Title", "SHOP", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0.09, 0.5), Size = UDim2.fromScale(0.3, 1.2), Font = T.TitleFont, TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 54, StrokeThickness = 4, Parent = header })
	local coins = Kit.pill("Coins", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(0.86, 0.5), Size = UDim2.fromScale(0.24, 1.1), Parent = header })
	local crow = new("Frame", { Name = "Row", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = coins }, {
		Kit.list("H", 0.04),
		Kit.padding(0.08),
	})
	Kit.icon("Icon", "eggCoin", { LayoutOrder = 1, Size = UDim2.fromScale(1, 1.3), Parent = crow })
	Kit.text("Amount", "0", { LayoutOrder = 2, Font = T.TitleFont, Size = UDim2.fromScale(0.62, 1), MaxTextSize = 32, Parent = crow })
	Kit.button("Close", T.Red, nil, "close", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.fromScale(1.3, 1.3), SizeConstraint = Enum.SizeConstraint.RelativeYY, Parent = header })

	local tabs = new("Frame", {
		Name = "Tabs",
		Position = UDim2.fromScale(0.03, 0.16),
		Size = UDim2.fromScale(0.94, 0.11),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = body,
	}, { Kit.list("H", 0.012) })
	for i, tab in SHOP_TABS do
		Kit.button(tab[1], T.Orange, tab[3], tab[2], { LayoutOrder = i, Size = UDim2.fromScale(0.155, 1), Parent = tabs })
	end

	new("ScrollingFrame", {
		Name = "Grid",
		Position = UDim2.fromScale(0.03, 0.3),
		Size = UDim2.fromScale(0.94, 0.66),
		BackgroundTransparency = 1,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = T.Yellow,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 2,
		Parent = body,
	}, {
		new("UIGridLayout", {
			CellSize = UDim2.new(0.185, 0, 0, 210),
			CellPadding = UDim2.new(0.018, 0, 0, 14),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
		new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }),
	})

	-- Item card template.
	local card = new("Frame", {
		Name = "ItemCard",
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 2,
		Parent = tpl,
	}, {
		Kit.corner(16),
		Kit.stroke(3),
		new("UIGradient", { Name = "RarityGradient", Rotation = 90, Color = ColorSequence.new(rgb(120, 120, 140), rgb(70, 70, 90)) }),
		new("UIScale", { Name = "AnimScale" }),
	})
	Kit.icon("Glow", "glow", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.33),
		Size = UDim2.fromScale(1.1, 1.1),
		SizeConstraint = Enum.SizeConstraint.RelativeXX,
		ImageTransparency = 0.45,
		ZIndex = 2,
		Parent = card,
	})
	new("ViewportFrame", {
		Name = "Preview",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.04),
		Size = UDim2.fromScale(0.86, 0.52),
		BackgroundTransparency = 1,
		Ambient = rgb(200, 200, 210),
		LightColor = rgb(255, 250, 240),
		LightDirection = Vector3.new(-1, -1.5, -1),
		ZIndex = 3,
		Visible = false,
		Parent = card,
	})
	Kit.icon("PreviewIcon", "egg", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.08),
		Size = UDim2.fromScale(0.62, 0.62),
		SizeConstraint = Enum.SizeConstraint.RelativeXX,
		ZIndex = 3,
		Parent = card,
	})
	Kit.text("ItemName", "Item", { Position = UDim2.fromScale(0.05, 0.57), Size = UDim2.fromScale(0.9, 0.12), Font = T.TitleFont, MaxTextSize = 22, ZIndex = 3, Parent = card })
	Kit.text("Rarity", "COMMON", { Position = UDim2.fromScale(0.05, 0.69), Size = UDim2.fromScale(0.9, 0.08), MaxTextSize = 16, ZIndex = 3, Parent = card })
	Kit.button("Action", T.Green, "EQUIP", "eggCoin", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.97),
		Size = UDim2.fromScale(0.86, 0.17),
		ZIndex = 4,
		Parent = card,
	})
	Kit.icon("Equipped", "check", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.88, 0.07),
		Size = UDim2.fromScale(0.26, 0.26),
		SizeConstraint = Enum.SizeConstraint.RelativeXX,
		Visible = false,
		ZIndex = 6,
		Parent = card,
	})
	Kit.icon("Lock", "lock", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.12, 0.07),
		Size = UDim2.fromScale(0.22, 0.22),
		SizeConstraint = Enum.SizeConstraint.RelativeXX,
		Visible = false,
		ZIndex = 6,
		Parent = card,
	})
	-- A shine that sweeps across rare cards.
	new("Frame", {
		Name = "Shine",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0,
		ZIndex = 5,
		Visible = false,
		Parent = card,
	}, {
		Kit.corner(16),
		new("UIGradient", {
			Rotation = 25,
			Offset = Vector2.new(-1, 0),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.45, 1),
				NumberSequenceKeypoint.new(0.5, 0.55),
				NumberSequenceKeypoint.new(0.55, 1),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})

	-- Egg pack / VIP card template.
	local pack = card:Clone()
	pack.Name = "PackCard"
	pack.Parent = tpl
	local packIcon = pack:FindFirstChild("PreviewIcon") :: ImageLabel
	packIcon:SetAttribute("Sprite", "basket")

	shop.Parent = parent
end

-- EMOTES ------------------------------------------------------------------------------------

local function buildEmotes(parent: Instance)
	local gui = Kit.screen("Emotes", 8)
	local wheel = new("Frame", {
		Name = "Wheel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 0.5),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	}, { Kit.aspect(1), new("UIScale", { Name = "AnimScale" }) })
	new("Frame", {
		Name = "Ring",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.86, 0.86),
		BackgroundColor3 = T.PanelBottom,
		BackgroundTransparency = 0.25,
		Parent = wheel,
	}, { Kit.corner(0.5, true), Kit.stroke(4), Kit.vgradient(Color3.new(1, 1, 1), rgb(170, 160, 200)) })
	Kit.button("Close", T.Red, nil, "close", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.2, 0.2),
		Parent = wheel,
	})
	local spots = { UDim2.fromScale(0.5, 0.17), UDim2.fromScale(0.83, 0.5), UDim2.fromScale(0.5, 0.83), UDim2.fromScale(0.17, 0.5) }
	for i, pos in spots do
		local slot = Kit.button(`Slot{i}`, T.Yellow, "EMOTE", nil, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = pos,
			Size = UDim2.fromScale(0.3, 0.24),
			Parent = wheel,
		})
		Kit.text("Key", tostring(i), {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.1, 0.1),
			Size = UDim2.fromScale(0.28, 0.4),
			Font = T.TitleFont,
			TextColor3 = T.Yellow,
			ZIndex = 5,
			Parent = slot,
		})
	end
	gui.Parent = parent
end

-- DRIVER ------------------------------------------------------------------------------------

local function buildDriver(parent: Instance)
	local gui = Kit.screen("Driver", 6)
	gui.Enabled = false
	local banner = Kit.pill("Banner", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.17, 0),
		Size = UDim2.fromScale(1, 0.08),
		BackgroundColor3 = T.Red,
		BackgroundTransparency = 0,
		Parent = gui,
	})
	Kit.aspect(7).Parent = banner
	local brow = new("Frame", { Name = "Row", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = banner }, {
		Kit.list("H", 0.02),
		Kit.padding(0.1),
	})
	Kit.icon("Icon", "angry", { LayoutOrder = 1, Size = UDim2.fromScale(1, 1.3), Parent = brow })
	Kit.text("Label", "ROAD RAGE! RUN THEM OVER!", { LayoutOrder = 2, Font = T.TitleFont, Size = UDim2.fromScale(0.85, 1), MaxTextSize = 36, Parent = brow })

	local controls = new("Frame", {
		Name = "Controls",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.97),
		Size = UDim2.fromScale(1, 0.34),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { Kit.aspect(2.2) })
	Kit.button("Up", T.Blue, nil, "arrowUp", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(0.2, 0.42), Parent = controls })
	Kit.button("Down", T.Blue, nil, "arrowDown", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.fromScale(0.2, 0.42), Parent = controls })
	Kit.button("Left", T.Red, "GO", "arrowLeft", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0.05, 0.5), Size = UDim2.fromScale(0.26, 0.42), Parent = controls })
	Kit.button("Right", T.Red, "GO", "arrowRight", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(0.95, 0.5), Size = UDim2.fromScale(0.26, 0.42), Parent = controls })
	local cooldown = new("Frame", {
		Name = "Cooldown",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, -0.16),
		Size = UDim2.fromScale(0.5, 0.1),
		BackgroundColor3 = T.PillBg,
		Parent = controls,
	}, { Kit.corner(0.5, true), Kit.stroke(3) })
	new("Frame", { Name = "Fill", Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.Yellow, Parent = cooldown }, { Kit.corner(0.5, true) })
	Kit.text("Hint", "W/S lane - A/D send a car", { Font = T.TitleFont, MaxTextSize = 20, ZIndex = 2, Parent = cooldown })
	gui.Parent = parent
end

-- Entry -------------------------------------------------------------------------------------

GuiBuilder.Names = { "Hud", "Shop", "Emotes", "Driver" }
-- Bump when the GUI changes enough that older built copies should be replaced.
GuiBuilder.Version = 2

-- Builds any GUI missing from `parent` (StarterGui in Studio, PlayerGui as a fallback).
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
