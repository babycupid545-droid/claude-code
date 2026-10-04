--!strict
-- The "Progress" ScreenGui (built through GuiBuilder): levels and titles, daily quests and the
-- season pass, in the same cream card style as the Shop, plus the level-up celebration.
-- src/client/Controllers/ProgressUI.luau fills it in; it finds pieces by name.
--
--   Root/Dim, Root/Panel           the window (Header, Tabs, Pages/Level|Quests|Pass)
--   Root/LevelUp                   "LEVEL UP!" moment
--   Templates/TitleRow, QuestCard, TierColumn
--
-- Also builds the HUD's PASS button (a star with the level on it) for GuiBuilder.

local Kit = require(script.Parent.GuiKit)

local ProgressGui = {}

local T = Kit.Theme
local new = Kit.new
local rgb = Color3.fromRGB
local V2 = Vector2.new

local GOLD_CELL = rgb(255, 232, 170)

-- HUD button ------------------------------------------------------------------------------------

-- A compact button for the HUD Buttons row: a star with a small "PASS" caption, the player's
-- level on a gold tag, and a pink dot when something is waiting to be claimed.
function ProgressGui.hudButton(row: Instance, order: number): TextButton
	local button = Kit.button("Pass", "PASS", "star", V2(52, 48), nil, { LayoutOrder = order, Parent = row })
	local content = (button :: any).Border.Inner.Content
	local list = content:FindFirstChildOfClass("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.Padding = UDim.new(0, -1)
	content.Icon.Size = UDim2.fromOffset(24, 24)
	content.Label.TextSize = 12
	content.Label.Size = UDim2.fromOffset(0, 13)
	local tag = new("Frame", {
		Name = "Level",
		AnchorPoint = V2(1, 0.5),
		Position = UDim2.new(1, 4, 0, 2),
		Size = UDim2.fromOffset(0, 18),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = T.Gold,
		ZIndex = 5,
		Parent = button,
	}, { Kit.corner(9), Kit.stroke(T.Frame, 1.5), Kit.padding(5, 0), Kit.sheen(0.2) })
	Kit.text("Label", "1", 12, {
		Size = UDim2.fromOffset(0, 18),
		AutomaticSize = Enum.AutomaticSize.X,
		TextColor3 = T.Dark,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 6,
		Parent = tag,
	})
	new("Frame", {
		Name = "Alert",
		AnchorPoint = V2(0.5, 0.5),
		Position = UDim2.fromOffset(4, 4),
		Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = T.Pink,
		Visible = false,
		ZIndex = 5,
		Parent = button,
	}, { Kit.corner(7), Kit.stroke(T.Frame, 1.5) })
	return button
end

-- Pages -------------------------------------------------------------------------------------------

local function page(parent: Instance, name: string, visible: boolean): Frame
	return new("Frame", {
		Name = name,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = visible,
		Parent = parent,
	})
end

local STATS = {
	{ "Wins", "trophy", "WINS" },
	{ "Knockouts", "egg", "KNOCKOUTS" },
	{ "Crossings", "chickenRun", "CROSSINGS" },
	{ "Rounds", "play", "ROUNDS" },
}

local function buildLevelPage(pages: Instance, tpl: Instance)
	local levelPage = page(pages, "Level", true)

	-- Left: your level, XP and stats.
	local _, inner = Kit.card("Summary", V2(286, 414), "dark", { Parent = levelPage })
	Kit.sunburst("Burst", 230, { Position = UDim2.new(0.5, 0, 0, 66), ImageTransparency = 0.82, Parent = inner })
	Kit.icon("Star", "star", 120, { AnchorPoint = V2(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Parent = inner })
	local number = Kit.text("Number", "1", 32, {
		AnchorPoint = V2(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 70),
		Size = UDim2.fromOffset(100, 42),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 2,
		Parent = inner,
	})
	Kit.textStroke(number, 3)
	Kit.text("LevelText", "LEVEL 1", 24, {
		Position = UDim2.fromOffset(0, 126),
		Size = UDim2.new(1, 0, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = inner,
	})
	Kit.text("TitleText", "Hatchling", 17, {
		Position = UDim2.fromOffset(10, 156),
		Size = UDim2.new(1, -20, 0, 22),
		Font = T.Body,
		TextColor3 = T.Yellow,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = inner,
	})
	local bar = Kit.bar("XpBar", V2(246, 24), T.Yellow, {
		AnchorPoint = V2(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 190),
		Parent = inner,
	})
	Kit.stroke(T.Gold, 1.5, 0.3).Parent = bar
	local xp = Kit.text("Text", "0 / 100 XP", 14, {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
		Parent = bar,
	})
	Kit.textStroke(xp, 1.5)
	local nextRow = new("Frame", {
		Name = "Next",
		Position = UDim2.fromOffset(0, 222),
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundTransparency = 1,
		Parent = inner,
	}, { Kit.list("H", 5, "Center", "Center") })
	Kit.icon("Icon", "eggCoin", 20, { LayoutOrder = 1, Parent = nextRow })
	Kit.text("Label", "+33 at level 2", 14, {
		LayoutOrder = 2,
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		Font = T.Body,
		TextColor3 = T.TextSoft,
		Parent = nextRow,
	})
	new("Frame", {
		Name = "Divider",
		AnchorPoint = V2(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 258),
		Size = UDim2.fromOffset(246, 1),
		BackgroundColor3 = T.GoldSoft,
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
		Parent = inner,
	})
	local stats = new("Frame", {
		Name = "Stats",
		AnchorPoint = V2(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 270),
		Size = UDim2.fromOffset(250, 124),
		BackgroundTransparency = 1,
		Parent = inner,
	}, {
		new("UIGridLayout", {
			CellSize = UDim2.fromOffset(121, 58),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for i, spec in STATS do
		local cell = new("Frame", {
			Name = spec[1],
			LayoutOrder = i,
			BackgroundColor3 = T.Track,
			BackgroundTransparency = 0.45,
			Parent = stats,
		}, { Kit.corner(8) })
		Kit.icon("Icon", spec[2], 26, { AnchorPoint = V2(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), Parent = cell })
		Kit.text("Value", "0", 20, { Position = UDim2.fromOffset(40, 6), Size = UDim2.new(1, -46, 0, 24), Parent = cell })
		Kit.text("Name", spec[3], 11, {
			Position = UDim2.fromOffset(40, 32),
			Size = UDim2.new(1, -46, 0, 16),
			Font = T.Body,
			TextColor3 = T.TextSoft,
			Parent = cell,
		})
	end

	-- Right: titles.
	Kit.text("TitlesHeader", "TITLES", 22, {
		Position = UDim2.fromOffset(300, 0),
		Size = UDim2.fromOffset(200, 28),
		TextColor3 = T.Ink,
		Parent = levelPage,
	})
	Kit.text("TitlesCount", "0 / 0 UNLOCKED", 14, {
		AnchorPoint = V2(1, 0),
		Position = UDim2.new(1, -6, 0, 4),
		Size = UDim2.fromOffset(240, 22),
		Font = T.Body,
		TextColor3 = T.InkSoft,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = levelPage,
	})
	new("ScrollingFrame", {
		Name = "TitleList",
		Position = UDim2.fromOffset(298, 34),
		Size = UDim2.new(1, -298, 1, -34),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = T.Frame,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = levelPage,
	}, {
		new("UIGridLayout", {
			CellSize = UDim2.fromOffset(268, 62),
			CellPadding = UDim2.fromOffset(10, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Kit.padding(3),
	})

	-- One title.
	local row = new("Frame", {
		Name = "TitleRow",
		Size = UDim2.fromOffset(268, 62),
		BackgroundColor3 = T.CreamShade,
		Parent = tpl,
	}, { Kit.corner(10), Kit.stroke(T.Gold, 1.5, 0.35), Kit.scale() })
	Kit.icon("Icon", "rosette", 38, { AnchorPoint = V2(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), Parent = row })
	Kit.text("TitleName", "Road Runner", 17, {
		Position = UDim2.fromOffset(52, 8),
		Size = UDim2.new(1, -150, 0, 22),
		TextColor3 = T.Ink,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = row,
	})
	Kit.text("Requirement", "Reach level 5", 13, {
		Position = UDim2.fromOffset(52, 32),
		Size = UDim2.new(1, -150, 0, 18),
		Font = T.Body,
		TextColor3 = T.InkSoft,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = row,
	})
	Kit.button("Action", "EQUIP", nil, V2(88, 36), T.Green, {
		AnchorPoint = V2(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Parent = row,
	})
	Kit.icon("Lock", "lock", 26, {
		AnchorPoint = V2(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 0),
		Visible = false,
		Parent = row,
	})
end

local function buildQuestsPage(pages: Instance, tpl: Instance)
	local questsPage = page(pages, "Quests", false)
	local top = new("Frame", {
		Name = "Top",
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
		Parent = questsPage,
	})
	Kit.icon("Icon", "clock", 28, { AnchorPoint = V2(0, 0.5), Position = UDim2.new(0, 4, 0.5, 0), Parent = top })
	Kit.text("Timer", "NEW QUESTS IN 0h 0m", 20, {
		AnchorPoint = V2(0, 0.5),
		Position = UDim2.new(0, 40, 0.5, 0),
		Size = UDim2.fromOffset(420, 28),
		TextColor3 = T.Ink,
		Parent = top,
	})
	Kit.chip("Rerolls", "sparkle", "1 FREE SWAP TODAY", V2(220, 34), {
		AnchorPoint = V2(1, 0.5),
		Position = UDim2.new(1, -4, 0.5, 0),
		Parent = top,
	})
	new("Frame", {
		Name = "Cards",
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 1, -50),
		BackgroundTransparency = 1,
		Parent = questsPage,
	}, { Kit.list("H", 18, "Center", "Top") })

	-- One quest.
	local card, inner = Kit.card("QuestCard", V2(270, 360), "cream", { Parent = tpl })
	new("Frame", {
		Name = "Band",
		Size = UDim2.new(1, 0, 0, 96),
		BackgroundColor3 = T.Orange,
		Parent = inner,
	}, { Kit.corner(9), Kit.sheen(0.25) })
	Kit.icon("Glow", "glow", 120, {
		AnchorPoint = V2(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 48),
		ImageTransparency = 0.4,
		Parent = inner,
	})
	Kit.icon("Icon", "egg", 64, { AnchorPoint = V2(0.5, 0), Position = UDim2.new(0.5, 0, 0, 16), Parent = inner })
	Kit.text("QuestName", "Knock out 5 chickens", 20, {
		Position = UDim2.fromOffset(14, 108),
		Size = UDim2.new(1, -28, 0, 54),
		TextColor3 = T.Ink,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = inner,
	})
	local bar = Kit.bar("Bar", V2(226, 26), T.Orange, {
		AnchorPoint = V2(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 174),
		Parent = inner,
	})
	local progress = Kit.text("Text", "0 / 5", 15, {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
		Parent = bar,
	})
	Kit.textStroke(progress, 1.5)
	Kit.text("RewardsLabel", "REWARD", 12, {
		Position = UDim2.fromOffset(0, 214),
		Size = UDim2.new(1, 0, 0, 16),
		Font = T.Body,
		TextColor3 = T.InkSoft,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = inner,
	})
	local rewards = new("Frame", {
		Name = "Rewards",
		Position = UDim2.fromOffset(0, 234),
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundTransparency = 1,
		Parent = inner,
	}, { Kit.list("H", 8, "Center", "Center") })
	Kit.chip("Coins", "eggCoin", "+100", V2(100, 34), { LayoutOrder = 1, Parent = rewards })
	Kit.chip("Xp", "star", "+100 XP", V2(116, 34), { LayoutOrder = 2, Parent = rewards })
	Kit.button("Action", "SWAP QUEST", "check", V2(226, 44), T.Blue, {
		AnchorPoint = V2(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Parent = inner,
	})
	Kit.icon("Done", "check", 40, { AnchorPoint = V2(1, 0), Position = UDim2.new(1, 8, 0, -8), Visible = false, ZIndex = 5, Parent = card })
end

-- A reward cell on the pass track (free or premium).
local function rewardCell(parent: Instance, name: string, y: number, premium: boolean)
	local cell = new("Frame", {
		Name = name,
		Position = UDim2.fromOffset(4, y),
		Size = UDim2.new(1, -8, 0, 120),
		BackgroundColor3 = if premium then GOLD_CELL else T.Cream,
		Parent = parent,
	}, {
		Kit.corner(10),
		Kit.stroke(if premium then T.Orange else T.Gold, 2, 0.1),
		new("UIGradient", { Color = ColorSequence.new(rgb(255, 255, 255), rgb(232, 224, 210)), Rotation = 90 }),
	})
	Kit.icon("Glow", "glow", 84, {
		AnchorPoint = V2(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 32),
		ImageTransparency = 0.5,
		Parent = cell,
	})
	Kit.icon("Icon", "eggCoin", 44, { AnchorPoint = V2(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Parent = cell })
	Kit.text("Label", "+100", 14, {
		Position = UDim2.fromOffset(4, 52),
		Size = UDim2.new(1, -8, 0, 30),
		TextColor3 = T.Ink,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		Parent = cell,
	})
	Kit.button("Claim", "CLAIM", nil, V2(84, 30), T.Green, {
		AnchorPoint = V2(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -6),
		Parent = cell,
	})
	Kit.icon("Lock", "lock", 24, { Position = UDim2.fromOffset(-6, -8), Visible = false, ZIndex = 4, Parent = cell })
	Kit.icon("Check", "check", 30, { AnchorPoint = V2(1, 0), Position = UDim2.new(1, 8, 0, -8), Visible = false, ZIndex = 4, Parent = cell })
end

local function buildPassPage(pages: Instance, tpl: Instance)
	local passPage = page(pages, "Pass", false)

	-- Season banner.
	local _, inner = Kit.card("Season", V2(856, 92), "dark", { Parent = passPage })
	Kit.icon("Icon", "car", 60, { AnchorPoint = V2(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0), Parent = inner })
	Kit.text("SeasonLabel", "SEASON 1", 14, {
		Position = UDim2.fromOffset(84, 8),
		Size = UDim2.fromOffset(220, 18),
		TextColor3 = T.Pink,
		Parent = inner,
	})
	Kit.text("SeasonName", "ROAD TRIP", 28, {
		Position = UDim2.fromOffset(84, 24),
		Size = UDim2.fromOffset(230, 34),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = inner,
	})
	local timer = new("Frame", {
		Name = "Timer",
		Position = UDim2.fromOffset(84, 58),
		Size = UDim2.fromOffset(230, 20),
		BackgroundTransparency = 1,
		Parent = inner,
	}, { Kit.list("H", 5, "Left", "Center") })
	Kit.icon("Icon", "clock", 18, { LayoutOrder = 1, Parent = timer })
	Kit.text("Label", "Ends in 0d 0h", 14, {
		LayoutOrder = 2,
		Size = UDim2.fromOffset(0, 18),
		AutomaticSize = Enum.AutomaticSize.X,
		Font = T.Body,
		TextColor3 = T.TextSoft,
		Parent = timer,
	})
	Kit.text("Tier", "TIER 0", 24, {
		Position = UDim2.fromOffset(340, 10),
		Size = UDim2.fromOffset(150, 30),
		TextColor3 = T.Yellow,
		Parent = inner,
	})
	Kit.text("TierXp", "0 / 300 XP", 14, {
		Position = UDim2.fromOffset(450, 16),
		Size = UDim2.fromOffset(150, 20),
		Font = T.Body,
		TextColor3 = T.TextSoft,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = inner,
	})
	local tierBar = Kit.bar("TierBar", V2(260, 14), T.Yellow, { Position = UDim2.fromOffset(340, 46), Parent = inner })
	Kit.stroke(T.Gold, 1.5, 0.3).Parent = tierBar
	Kit.text("NextTier", "Next tier: +100 eggs", 13, {
		Position = UDim2.fromOffset(340, 62),
		Size = UDim2.fromOffset(260, 18),
		Font = T.Body,
		TextColor3 = T.TextSoft,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = inner,
	})
	Kit.text("PremiumLabel", "PREMIUM PASS", 13, {
		AnchorPoint = V2(1, 0),
		Position = UDim2.new(1, -14, 0, 6),
		Size = UDim2.fromOffset(200, 18),
		TextColor3 = T.Yellow,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = inner,
	})
	Kit.button("Premium", "R$ ...", "crown", V2(200, 48), T.Pink, {
		AnchorPoint = V2(1, 1),
		Position = UDim2.new(1, -14, 1, -8),
		Parent = inner,
	})

	-- The track: tier numbers, free rewards and premium rewards, scrolling sideways.
	local trackArea = new("Frame", {
		Name = "TrackArea",
		Position = UDim2.fromOffset(0, 102),
		Size = UDim2.new(1, 0, 1, -102),
		BackgroundTransparency = 1,
		Parent = passPage,
	})
	local function lane(name: string, y: number, sprite: string, text: string, color: Color3)
		local _, laneInner = Kit.card(name, V2(96, 120), "dark", { Position = UDim2.fromOffset(0, y), Parent = trackArea })
		Kit.icon("Icon", sprite, 44, { AnchorPoint = V2(0.5, 0), Position = UDim2.new(0.5, 0, 0, 18), Parent = laneInner })
		Kit.text("Label", text, 15, {
			Position = UDim2.fromOffset(0, 70),
			Size = UDim2.new(1, 0, 0, 22),
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = laneInner,
		})
	end
	lane("FreeLane", 40, "gift", "FREE", T.Text)
	lane("PremiumLane", 172, "crown", "PREMIUM", T.Yellow)

	new("ScrollingFrame", {
		Name = "Track",
		Position = UDim2.fromOffset(104, 0),
		Size = UDim2.new(1, -104, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = T.Frame,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ElasticBehavior = Enum.ElasticBehavior.Never,
		Parent = trackArea,
	}, { Kit.list("H", 0, "Left", "Top") })

	-- One tier: its number on a progress line, then the free and premium rewards.
	local column = new("Frame", {
		Name = "TierColumn",
		Size = UDim2.fromOffset(112, 300),
		BackgroundTransparency = 1,
		Parent = tpl,
	})
	local line = Kit.bar("Line", V2(112, 6), T.Orange, { Position = UDim2.fromOffset(0, 12), Parent = column })
	line.BackgroundTransparency = 0.35
	local head = new("Frame", {
		Name = "Head",
		AnchorPoint = V2(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 1),
		Size = UDim2.fromOffset(44, 28),
		BackgroundColor3 = T.Dark,
		ZIndex = 2,
		Parent = column,
	}, { Kit.corner(14), Kit.stroke(T.Gold, 2), Kit.scale() })
	Kit.text("Num", "1", 16, {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
		Parent = head,
	})
	rewardCell(column, "Free", 40, false)
	rewardCell(column, "Premium", 172, true)
end

local TABS = {
	{ "Level", "star", "LEVEL" },
	{ "Quests", "check", "QUESTS" },
	{ "Pass", "crown", "PASS" },
}

local function buildLevelUp(root: Frame)
	local levelUp = new("Frame", {
		Name = "LevelUp",
		AnchorPoint = V2(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.36),
		Size = UDim2.fromOffset(420, 250),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = root,
	}, { Kit.scale() })
	Kit.sunburst("Sunburst", 480, { Position = UDim2.fromScale(0.5, 0.42), Parent = levelUp })
	local _, inner = Kit.card("Card", V2(380, 160), "cream", {
		AnchorPoint = V2(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Parent = levelUp,
	})
	Kit.text("Title", "LEVEL UP!", 38, {
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(1, 0, 0, 44),
		TextColor3 = T.Orange,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = inner,
	})
	Kit.text("Sub", "New title: Road Runner", 16, {
		Position = UDim2.fromOffset(12, 70),
		Size = UDim2.new(1, -24, 0, 22),
		Font = T.Body,
		TextColor3 = T.Ink,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = inner,
	})
	Kit.chip("Reward", "eggCoin", "+0", V2(130, 38), {
		AnchorPoint = V2(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Parent = inner,
	})
	Kit.icon("Star", "star", 132, { AnchorPoint = V2(0.5, 0), Position = UDim2.new(0.5, 0, 0, -16), ZIndex = 3, Parent = levelUp })
	local number = Kit.text("Number", "2", 32, {
		AnchorPoint = V2(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 56),
		Size = UDim2.fromOffset(100, 42),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 4,
		Parent = levelUp,
	})
	Kit.textStroke(number, 3)
end

function ProgressGui.build(parent: Instance)
	local screen, root = Kit.screen("Progress", 5)
	local tpl = new("Folder", { Name = "Templates", Parent = screen })
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
	Kit.icon("Icon", "star", 42, { AnchorPoint = V2(0, 0.5), Position = UDim2.fromScale(0, 0.5), Parent = header })
	Kit.text("Title", "PROGRESS", 34, {
		AnchorPoint = V2(0, 0.5),
		Position = UDim2.new(0, 52, 0.5, 0),
		Size = UDim2.fromOffset(260, 40),
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
	for i, spec in TABS do
		local tab = Kit.button(spec[1], spec[3], spec[2], V2(136, 44), nil, { LayoutOrder = i, Parent = tabs })
		-- A pink dot when that tab has something to collect.
		new("Frame", {
			Name = "Alert",
			AnchorPoint = V2(0.5, 0.5),
			Position = UDim2.new(1, -4, 0, 4),
			Size = UDim2.fromOffset(14, 14),
			BackgroundColor3 = T.Pink,
			Visible = false,
			ZIndex = 5,
			Parent = tab,
		}, { Kit.corner(7), Kit.stroke(T.Frame, 1.5) })
	end

	local pages = new("Frame", {
		Name = "Pages",
		Position = UDim2.fromOffset(18, 124),
		Size = UDim2.new(1, -36, 1, -138),
		BackgroundTransparency = 1,
		Parent = inner,
	})
	buildLevelPage(pages, tpl)
	buildQuestsPage(pages, tpl)
	buildPassPage(pages, tpl)
	buildLevelUp(root)

	screen.Parent = parent
end

return ProgressGui
