--!strict
-- Building blocks for the game's barnyard GUI style: wooden plank panels with cream trim and
-- nails, a picket fence peeking out underneath, dark-wood readouts, chunky 3D push buttons,
-- painted signs, red ribbons and sprite-sheet icons (golden eggs are the currency).
--
-- Sizes are scale-based (with aspect-ratio constraints on top-level pieces) so the UI fits
-- every screen. Text uses TextScaled with a max size.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SpriteSheets = require(Shared:WaitForChild("SpriteSheets"))

local Kit = {}

local rgb = Color3.fromRGB

Kit.Theme = {
	Outline = rgb(58, 34, 22),
	Text = rgb(255, 255, 255),
	TextDim = rgb(255, 236, 200),
	-- Warm planks.
	PanelTop = rgb(190, 126, 74),
	PanelBottom = rgb(134, 82, 46),
	PillBg = rgb(82, 50, 30),
	Cream = rgb(255, 244, 214),
	Nail = rgb(96, 90, 100),
	Barn = rgb(204, 60, 50),
	Hay = rgb(246, 206, 96),
	Grass = rgb(104, 196, 72),
	Sky = rgb(110, 196, 255),
	Yellow = rgb(255, 205, 64),
	Orange = rgb(255, 150, 40),
	Green = rgb(104, 196, 72),
	Blue = rgb(72, 168, 236),
	Red = rgb(214, 62, 50),
	Purple = rgb(150, 100, 220),
	Pink = rgb(255, 120, 170),
	Grey = rgb(160, 150, 140),
	TitleFont = Enum.Font.LuckiestGuy,
	BodyFont = Enum.Font.FredokaOne,
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

-- Darker / lighter versions of a colour for 3D effects.
function Kit.shade(c: Color3, amount: number): Color3
	if amount >= 0 then
		return c:Lerp(Color3.new(1, 1, 1), amount)
	end
	return c:Lerp(Color3.new(0, 0, 0), -amount)
end

function Kit.corner(radius: number?, scale: boolean?): any
	return Kit.new("UICorner", {
		CornerRadius = if scale then UDim.new(radius or 0.25, 0) else UDim.new(0, radius or 12),
	})
end

function Kit.stroke(thickness: number?, color: Color3?, border: boolean?): any
	return Kit.new("UIStroke", {
		Thickness = thickness or 3,
		Color = color or T.Outline,
		ApplyStrokeMode = if border == false then Enum.ApplyStrokeMode.Contextual else Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	})
end

function Kit.vgradient(top: Color3, bottom: Color3): any
	return Kit.new("UIGradient", {
		Color = ColorSequence.new(top, bottom),
		Rotation = 90,
	})
end

function Kit.aspect(ratio: number): any
	return Kit.new("UIAspectRatioConstraint", { AspectRatio = ratio })
end

function Kit.list(direction: "H" | "V", padding: number?, align: string?): any
	return Kit.new("UIListLayout", {
		FillDirection = if direction == "H" then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		Padding = UDim.new(padding or 0.04, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = if align == "Left"
			then Enum.HorizontalAlignment.Left
			elseif align == "Right" then Enum.HorizontalAlignment.Right
			else Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})
end

function Kit.padding(scale: number): any
	return Kit.new("UIPadding", {
		PaddingLeft = UDim.new(scale, 0),
		PaddingRight = UDim.new(scale, 0),
		PaddingTop = UDim.new(scale, 0),
		PaddingBottom = UDim.new(scale, 0),
	})
end

-- Outlined cartoon text.
function Kit.text(name: string, text: string, props: Props?): TextLabel
	local label = Kit.new("TextLabel", {
		Name = name,
		Text = text,
		BackgroundTransparency = 1,
		TextColor3 = T.Text,
		Font = T.BodyFont,
		TextScaled = true,
		TextWrapped = true,
		Size = UDim2.fromScale(1, 1),
	}, {
		Kit.new("UIStroke", { Thickness = 2.5, Color = T.Outline, LineJoinMode = Enum.LineJoinMode.Round }),
		Kit.new("UITextSizeConstraint", { MaxTextSize = 48, MinTextSize = 8 }),
	})
	if props then
		for key, value in props do
			if key == "MaxTextSize" then
				(label:FindFirstChildOfClass("UITextSizeConstraint") :: UITextSizeConstraint).MaxTextSize = value
			elseif key == "StrokeThickness" then
				(label:FindFirstChildOfClass("UIStroke") :: UIStroke).Thickness = value
			else
				(label :: any)[key] = value
			end
		end
	end
	return label
end

-- An icon from the sprite sheets. The client fills in the image (or an emoji fallback)
-- from the Sprite attribute, so this works before the sheets are uploaded.
function Kit.icon(name: string, sprite: string, props: Props?): ImageLabel
	local id, s = SpriteSheets.find(sprite)
	local image = Kit.new("ImageLabel", {
		Name = name,
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.fromScale(1, 1),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		Image = id,
	})
	image:SetAttribute("Sprite", sprite)
	if s then
		image.ImageRectOffset = s.offset
		image.ImageRectSize = s.size
	end
	if props then
		for key, value in props do
			(image :: any)[key] = value
		end
	end
	return image
end

-- A tiling texture overlay (woodTile, hayTile, paperTile, printTile) filling its parent.
function Kit.texture(sprite: string, tile: number, transparency: number, corner: UDim?): ImageLabel
	local tex = Kit.icon("Texture", sprite, {
		Size = UDim2.fromScale(1, 1),
		SizeConstraint = Enum.SizeConstraint.RelativeXY,
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(tile, tile),
		ImageTransparency = transparency,
		ZIndex = 1,
	})
	if corner then
		Kit.new("UICorner", { CornerRadius = corner, Parent = tex })
	end
	return tex
end

-- Little nail heads in the corners of a board.
function Kit.nails(parent: Instance, inset: number?, size: number?)
	local i = inset or 10
	local d = size or 8
	for _, corner in { Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) } do
		Kit.new("Frame", {
			Name = "Nail",
			AnchorPoint = corner,
			Position = UDim2.new(corner.X, if corner.X == 0 then i else -i, corner.Y, if corner.Y == 0 then i else -i),
			Size = UDim2.fromOffset(d, d),
			BackgroundColor3 = T.Nail,
			ZIndex = 4,
			Parent = parent,
		}, {
			Kit.corner(1, true),
			Kit.new("UIStroke", { Thickness = 1.5, Color = T.Outline }),
			Kit.new("UIGradient", { Color = ColorSequence.new(rgb(230, 230, 240), rgb(90, 86, 96)), Rotation = 45 }),
		})
	end
end

-- A dark wooden capsule for HUD readouts.
function Kit.pill(name: string, props: Props?): Frame
	local pill = Kit.new("Frame", {
		Name = name,
		BackgroundColor3 = T.PillBg,
		BackgroundTransparency = 0.05,
	}, {
		Kit.corner(0.5, true),
		Kit.stroke(3),
		Kit.vgradient(Color3.new(1, 1, 1), rgb(170, 150, 140)),
	})
	Kit.texture("woodTile", 96, 0.55, UDim.new(0.5, 0)).Parent = pill
	if props then
		for key, value in props do
			(pill :: any)[key] = value
		end
	end
	return pill
end

-- A big wooden board: drop shadow, plank body with cream trim and nails, and a picket
-- fence with grass peeking out along the bottom. Content goes in `Body`.
function Kit.panel(name: string, top: Color3?, bottom: Color3?, props: Props?): (Frame, Frame)
	local container = Kit.new("Frame", {
		Name = name,
		BackgroundTransparency = 1,
	}, { Kit.new("UIScale", { Name = "AnimScale" }) })
	Kit.new("Frame", {
		Name = "Shadow",
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.new(0, 0, 0, 8),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.55,
		ZIndex = 0,
		Parent = container,
	}, { Kit.corner(22) })
	-- Fence and grass behind the board, poking out below it.
	Kit.icon("Fence", "fence", {
		AnchorPoint = Vector2.new(0.5, 0.35),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.new(1.02, 0, 0, 52),
		SizeConstraint = Enum.SizeConstraint.RelativeXY,
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(208, 52),
		ZIndex = 0,
		Parent = container,
	})
	Kit.icon("Grass", "grass", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 2),
		Size = UDim2.new(1.06, 0, 0, 34),
		SizeConstraint = Enum.SizeConstraint.RelativeXY,
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(136, 34),
		ZIndex = 0,
		Parent = container,
	})
	local body = Kit.new("Frame", {
		Name = "Body",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ClipsDescendants = false,
		Parent = container,
	}, {
		Kit.corner(22),
		Kit.stroke(4),
		Kit.vgradient(top or T.PanelTop, bottom or T.PanelBottom),
	})
	local planks = Kit.texture("woodTile", 220, 0.15, UDim.new(0, 22))
	planks.Name = "Pattern"
	planks.Parent = body
	Kit.new("Frame", {
		Name = "Trim",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -14, 1, -14),
		BackgroundTransparency = 1,
		ZIndex = 1,
		Parent = body,
	}, {
		Kit.corner(17),
		Kit.new("UIStroke", { Thickness = 3, Color = T.Cream, Transparency = 0.25 }),
	})
	Kit.nails(body, 16, 9)
	if props then
		for key, value in props do
			(container :: any)[key] = value
		end
	end
	return container, body
end

-- A painted wooden sign with a title on it (for panel headers and HUD banners).
function Kit.sign(name: string, text: string, props: Props?): Frame
	local sign = Kit.new("Frame", {
		Name = name,
		BackgroundColor3 = T.PanelTop,
	}, {
		Kit.corner(0.28, true),
		Kit.stroke(4),
		Kit.vgradient(rgb(255, 236, 210), rgb(190, 160, 140)),
		Kit.new("UIScale", { Name = "AnimScale" }),
	})
	Kit.texture("woodTile", 120, 0.2, UDim.new(0.28, 0)).Parent = sign
	Kit.nails(sign, 7, 7)
	Kit.text("Label", text, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.84, 0.74),
		Font = T.TitleFont,
		MaxTextSize = 44,
		StrokeThickness = 3,
		ZIndex = 3,
		Parent = sign,
	})
	if props then
		for key, value in props do
			(sign :: any)[key] = value
		end
	end
	return sign
end

-- A show ribbon with folded tails, for winners and event titles.
function Kit.ribbon(name: string, text: string, color: Color3?, props: Props?): Frame
	local ribbon = Kit.new("Frame", {
		Name = name,
		BackgroundTransparency = 1,
	}, { Kit.new("UIScale", { Name = "AnimScale" }) })
	-- The painted ribbon tails (when the farm sheet is uploaded)...
	Kit.icon("Art", "ribbon", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1.2, 1.25),
		SizeConstraint = Enum.SizeConstraint.RelativeXY,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(150, 20, 362, 100),
		ImageColor3 = if color then color:Lerp(Color3.new(1, 1, 1), 0.35) else Color3.new(1, 1, 1),
		ZIndex = 0,
		Parent = ribbon,
	})
	-- ...behind a band that always shows.
	Kit.new("Frame", {
		Name = "Band",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromScale(0.84, 0.74),
		BackgroundColor3 = color or T.Barn,
		ZIndex = 1,
		Parent = ribbon,
	}, {
		Kit.corner(0.2, true),
		Kit.stroke(4),
		Kit.vgradient(Color3.new(1, 1, 1), rgb(200, 190, 190)),
	})
	Kit.text("Label", text, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromScale(0.78, 0.62),
		Font = T.TitleFont,
		MaxTextSize = 56,
		StrokeThickness = 3.5,
		ZIndex = 3,
		Parent = ribbon,
	})
	if props then
		for key, value in props do
			(ribbon :: any)[key] = value
		end
	end
	return ribbon
end

-- A chunky 3D push button: a darker Base sits under the Face, which drops on press.
-- The button itself is the transparent TextButton, so `button.Activated` just works.
-- Children of Face.Content: Icon (optional) and Label.
function Kit.button(name: string, color: Color3, label: string?, sprite: string?, props: Props?, corner: number?): TextButton
	local button = Kit.new("TextButton", {
		Name = name,
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, { Kit.new("UIScale", { Name = "AnimScale" }) })
	button:SetAttribute("Juicy", true)
	button:SetAttribute("Color", color)
	Kit.new("Frame", {
		Name = "Base",
		Size = UDim2.new(1, 0, 1, -4),
		Position = UDim2.new(0, 0, 0, 6),
		BackgroundColor3 = Kit.shade(color, -0.45),
		Parent = button,
	}, { Kit.corner(corner or 0.3, true), Kit.stroke(3) })
	local face = Kit.new("Frame", {
		Name = "Face",
		Size = UDim2.new(1, 0, 1, -4),
		BackgroundColor3 = color,
		Parent = button,
	}, {
		Kit.corner(corner or 0.3, true),
		Kit.stroke(3),
		Kit.vgradient(Color3.new(1, 1, 1), Color3.fromRGB(205, 205, 215)),
	})
	-- Glossy top half.
	Kit.new("Frame", {
		Name = "Gloss",
		Size = UDim2.new(1, -8, 0.42, 0),
		Position = UDim2.new(0, 4, 0, 3),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.72,
		ZIndex = 2,
		Parent = face,
	}, { Kit.corner(0.5, true) })
	local content = Kit.new("Frame", {
		Name = "Content",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = face,
	}, { Kit.list("H", 0.04), Kit.padding(0.08) })
	if sprite then
		Kit.icon("Icon", sprite, {
			LayoutOrder = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 3,
			Parent = content,
		})
	end
	if label then
		Kit.text("Label", label, {
			LayoutOrder = 2,
			Font = T.TitleFont,
			Size = UDim2.fromScale(if sprite then 0.62 else 1, 0.9),
			ZIndex = 3,
			MaxTextSize = 36,
			Parent = content,
		})
	end
	if props then
		for key, value in props do
			(button :: any)[key] = value
		end
	end
	return button
end

-- A spinning sunburst for big moments (the client rotates anything tagged "SpinUi").
function Kit.sunburst(name: string, props: Props?): ImageLabel
	local burst = Kit.icon(name, "sunburst", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		ImageTransparency = 0.35,
		ImageColor3 = Color3.fromRGB(255, 230, 140),
		ZIndex = 0,
	})
	burst:AddTag("SpinUi")
	if props then
		for key, value in props do
			(burst :: any)[key] = value
		end
	end
	return burst
end

function Kit.screen(name: string, displayOrder: number?): ScreenGui
	return Kit.new("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
		DisplayOrder = displayOrder or 0,
	})
end

return Kit
