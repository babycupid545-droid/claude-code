--!strict
-- Building blocks for the game's GUI: clean framed cards (a dark wood frame with a thin gold
-- border around a dark or cream panel), compact buttons, chips and progress bars.
--
-- Everything is laid out in pixels for a 1280x720 screen inside a full-screen "Root" frame;
-- the client scales Root to fit the real screen (see src/client/Gui.luau), so sizes stay
-- exact on every device. Text uses a fixed TextSize (no TextScaled), which keeps layouts
-- stable and avoids the jitter/expansion TextScaled can cause.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SpriteSheets = require(Shared:WaitForChild("SpriteSheets"))

local Kit = {}

local rgb = Color3.fromRGB

Kit.Theme = {
	Frame = rgb(96, 58, 32), -- the wooden frame around every card
	Gold = rgb(236, 178, 86), -- thin outer border
	GoldSoft = rgb(255, 216, 150), -- inner hairline
	Dark = rgb(44, 29, 20), -- dark panel
	Cream = rgb(255, 247, 230), -- light panel
	CreamShade = rgb(244, 230, 204),
	Ink = rgb(74, 46, 28), -- text on cream
	InkSoft = rgb(140, 104, 76),
	Text = rgb(255, 246, 228), -- text on dark
	TextSoft = rgb(226, 206, 178),
	Pink = rgb(255, 118, 176),
	Orange = rgb(255, 156, 46),
	Yellow = rgb(255, 204, 64),
	Green = rgb(110, 200, 84),
	Blue = rgb(76, 164, 236),
	Red = rgb(226, 74, 64),
	Purple = rgb(160, 110, 230),
	Grey = rgb(150, 138, 126),
	Track = rgb(28, 19, 13),
	Display = Enum.Font.FredokaOne,
	Body = Enum.Font.BuilderSansBold,
}

local T = Kit.Theme

export type Props = { [string]: any }

function Kit.new(className: string, props: Props?, children: { Instance }?): any
	local inst = Instance.new(className)
	local parent = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(inst :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = inst
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function apply(inst: Instance, props: Props?)
	if props then
		local parent = nil
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(inst :: any)[key] = value
			end
		end
		if parent then
			inst.Parent = parent
		end
	end
end

function Kit.corner(px: number): any
	return Kit.new("UICorner", { CornerRadius = UDim.new(0, px) })
end

function Kit.stroke(color: Color3, thickness: number?, transparency: number?): any
	return Kit.new("UIStroke", {
		Color = color,
		Thickness = thickness or 2,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	})
end

function Kit.padding(px: number, vertical: number?): any
	local v = vertical or px
	return Kit.new("UIPadding", {
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
		PaddingTop = UDim.new(0, v),
		PaddingBottom = UDim.new(0, v),
	})
end

function Kit.list(direction: "H" | "V", gap: number?, halign: string?, valign: string?): any
	return Kit.new("UIListLayout", {
		FillDirection = if direction == "H" then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		Padding = UDim.new(0, gap or 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = if halign == "Center"
			then Enum.HorizontalAlignment.Center
			elseif halign == "Right" then Enum.HorizontalAlignment.Right
			else Enum.HorizontalAlignment.Left,
		VerticalAlignment = if valign == "Top"
			then Enum.VerticalAlignment.Top
			elseif valign == "Bottom" then Enum.VerticalAlignment.Bottom
			else Enum.VerticalAlignment.Center,
	})
end

-- A soft top-to-bottom sheen for panels and buttons.
function Kit.sheen(strength: number?): any
	local s = strength or 0.12
	return Kit.new("UIGradient", {
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(1 - s, 1 - s, 1 - s)),
		Rotation = 90,
	})
end

function Kit.scale(): any
	return Kit.new("UIScale", { Name = "AnimScale" })
end

-- Text with a fixed size. `color`/`font` default to light display text.
function Kit.text(name: string, text: string, size: number, props: Props?): TextLabel
	local label = Kit.new("TextLabel", {
		Name = name,
		Text = text,
		TextSize = size,
		Font = T.Display,
		TextColor3 = T.Text,
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		Size = UDim2.new(1, 0, 0, size + 6),
	})
	apply(label, props)
	return label
end

-- A thin dark outline for text that sits on the 3D world (no panel behind it).
function Kit.textStroke(label: TextLabel, thickness: number?)
	Kit.new("UIStroke", {
		Thickness = thickness or 2,
		Color = T.Dark,
		Transparency = 0.1,
		LineJoinMode = Enum.LineJoinMode.Round,
		Parent = label,
	})
end

-- An icon from the sprite sheets. The client fills in the image (or an emoji fallback)
-- from the Sprite attribute, so this works before the sheets are uploaded.
function Kit.icon(name: string, sprite: string, size: number, props: Props?): ImageLabel
	local id, s = SpriteSheets.find(sprite)
	local image = Kit.new("ImageLabel", {
		Name = name,
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.fromOffset(size, size),
		Image = id,
	})
	image:SetAttribute("Sprite", sprite)
	if s then
		image.ImageRectOffset = s.offset
		image.ImageRectSize = s.size
	end
	apply(image, props)
	return image
end

-- The framed card every panel uses: wooden frame + gold border, and an `Inner` panel
-- (dark or cream) that holds the content. Returns the card and its Inner.
function Kit.card(name: string, size: Vector2, style: "dark" | "cream" | nil, props: Props?): (Frame, Frame)
	local cream = style == "cream"
	local card = Kit.new("Frame", {
		Name = name,
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundColor3 = T.Frame,
	}, {
		Kit.corner(12),
		Kit.stroke(T.Gold, 2),
		Kit.scale(),
	})
	local inner = Kit.new("Frame", {
		Name = "Inner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -8, 1, -8),
		BackgroundColor3 = if cream then T.Cream else T.Dark,
		BackgroundTransparency = if cream then 0 else 0.08,
		Parent = card,
	}, {
		Kit.corner(9),
		Kit.stroke(T.GoldSoft, 1, if cream then 0.2 else 0.55),
		Kit.new("UIGradient", {
			Color = if cream
				then ColorSequence.new(T.Cream, T.CreamShade)
				else ColorSequence.new(rgb(255, 255, 255), rgb(200, 200, 200)),
			Rotation = 90,
		}),
	})
	apply(card, props)
	return card, inner
end

-- A progress bar: dark Track with a Fill (0..1 via Fill.Size X scale).
function Kit.bar(name: string, size: Vector2, color: Color3?, props: Props?): Frame
	local track = Kit.new("Frame", {
		Name = name,
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundColor3 = T.Track,
		BackgroundTransparency = 0.2,
	}, { Kit.corner(math.floor(size.Y / 2)) })
	Kit.new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color or T.Orange,
		Parent = track,
	}, {
		Kit.corner(math.floor(size.Y / 2)),
		Kit.new("UIGradient", {
			Color = ColorSequence.new(rgb(255, 255, 255), rgb(215, 215, 215)),
			Rotation = 90,
		}),
	})
	apply(track, props)
	return track
end

-- A button styled like the cards. `color` = nil gives the dark HUD style; a colour gives a
-- filled accent button. The TextButton is the hit area (so `.Activated` just works); its
-- visuals live in Border > Inner > Content (Icon, Label).
function Kit.button(name: string, label: string?, sprite: string?, size: Vector2, color: Color3?, props: Props?): TextButton
	local button = Kit.new("TextButton", {
		Name = name,
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size.X, size.Y),
	}, { Kit.scale() })
	button:SetAttribute("Juicy", true)
	local border = Kit.new("Frame", {
		Name = "Border",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = T.Frame,
		Parent = button,
	}, { Kit.corner(10), Kit.stroke(T.Gold, 2) })
	local inner = Kit.new("Frame", {
		Name = "Inner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -6, 1, -6),
		BackgroundColor3 = color or T.Dark,
		BackgroundTransparency = if color then 0 else 0.08,
		Parent = border,
	}, { Kit.corner(8), Kit.sheen(if color then 0.22 else 0.1) })
	if color then
		inner:SetAttribute("Accent", color)
	end
	local content = Kit.new("Frame", {
		Name = "Content",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = inner,
	}, { Kit.list("H", 6, "Center", "Center") })
	local iconSize = math.floor(math.min(size.Y - 14, 28))
	if sprite then
		Kit.icon("Icon", sprite, iconSize, { LayoutOrder = 1, Parent = content })
	end
	if label then
		local text = Kit.text("Label", label, math.clamp(math.floor(size.Y * 0.38), 13, 22), {
			LayoutOrder = 2,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromScale(0, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = content,
		})
		if color then
			Kit.textStroke(text, 1.5)
		end
	end
	apply(button, props)
	return button
end

-- A small rounded chip (dark by default) holding an icon and a value.
function Kit.chip(name: string, sprite: string?, text: string, size: Vector2, props: Props?): Frame
	local chip = Kit.new("Frame", {
		Name = name,
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundColor3 = T.Dark,
		BackgroundTransparency = 0.1,
	}, {
		Kit.corner(math.floor(size.Y / 2)),
		Kit.stroke(T.Gold, 1.5, 0.3),
		Kit.padding(8, 0),
		Kit.list("H", 6, "Center", "Center"),
		Kit.scale(),
	})
	if sprite then
		Kit.icon("Icon", sprite, size.Y - 10, { LayoutOrder = 1, Parent = chip })
	end
	Kit.text("Label", text, math.floor(size.Y * 0.55), {
		LayoutOrder = 2,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		Parent = chip,
	})
	apply(chip, props)
	return chip
end

-- A spinning sunburst for big moments (the client rotates anything tagged "SpinUi").
function Kit.sunburst(name: string, size: number, props: Props?): ImageLabel
	local burst = Kit.icon(name, "sunburst", size, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		ImageTransparency = 0.55,
		ImageColor3 = rgb(255, 228, 150),
		ZIndex = 0,
	})
	burst:AddTag("SpinUi")
	apply(burst, props)
	return burst
end

-- A ScreenGui with a full-screen `Root` frame that the client scales to fit the screen.
function Kit.screen(name: string, displayOrder: number?): (ScreenGui, Frame)
	local screen = Kit.new("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
		DisplayOrder = displayOrder or 0,
	})
	local root = Kit.new("Frame", {
		Name = "Root",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = screen,
	}, { Kit.new("UIScale", { Name = "Fit" }) })
	return screen, root
end

return Kit
