--!strict
-- Building blocks for the game's GUI style: chunky cartoon panels with thick dark outlines,
-- gradient fills, 3D push buttons and sprite-sheet icons.
--
-- Sizes are scale-based (with aspect-ratio constraints on top-level pieces) so the UI fits
-- every screen. Text uses TextScaled with a max size.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AssetIds = require(Shared:WaitForChild("AssetIds"))
local UiSprites = require(Shared:WaitForChild("UiSprites"))

local Kit = {}

local rgb = Color3.fromRGB

Kit.Theme = {
	Outline = rgb(43, 29, 58),
	Text = rgb(255, 255, 255),
	TextDim = rgb(225, 215, 245),
	PanelTop = rgb(108, 84, 170),
	PanelBottom = rgb(64, 46, 118),
	PillBg = rgb(40, 28, 70),
	Yellow = rgb(255, 201, 60),
	Orange = rgb(255, 150, 40),
	Green = rgb(80, 210, 100),
	Blue = rgb(60, 160, 255),
	Red = rgb(255, 80, 80),
	Purple = rgb(160, 100, 255),
	Pink = rgb(255, 100, 170),
	Grey = rgb(150, 150, 170),
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

-- An icon from the sprite sheet. The client fills in the image (or an emoji fallback)
-- from the Sprite attribute, so this works before the sheet is uploaded.
function Kit.icon(name: string, sprite: string, props: Props?): ImageLabel
	local s = UiSprites[sprite]
	local image = Kit.new("ImageLabel", {
		Name = name,
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.fromScale(1, 1),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		Image = AssetIds.get("UiSheet"),
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

-- A dark translucent capsule for HUD readouts.
function Kit.pill(name: string, props: Props?): Frame
	local pill = Kit.new("Frame", {
		Name = name,
		BackgroundColor3 = T.PillBg,
		BackgroundTransparency = 0.15,
	}, {
		Kit.corner(0.5, true),
		Kit.stroke(3),
		Kit.vgradient(Color3.new(1, 1, 1), Color3.fromRGB(190, 180, 210)),
	})
	if props then
		for key, value in props do
			(pill :: any)[key] = value
		end
	end
	return pill
end

-- A big panel: drop shadow + gradient body + subtle dot pattern. Content goes in `Body`.
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
	Kit.new("ImageLabel", {
		Name = "Pattern",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = AssetIds.get("UiSheet"),
		ImageRectOffset = UiSprites.dots.offset,
		ImageRectSize = UiSprites.dots.size,
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(40, 40),
		ImageTransparency = 0.92,
		ZIndex = 1,
		Parent = body,
	}, { Kit.corner(22) }):SetAttribute("Sprite", "dots")
	if props then
		for key, value in props do
			(container :: any)[key] = value
		end
	end
	return container, body
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
