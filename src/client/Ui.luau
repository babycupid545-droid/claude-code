--!strict
-- Tiny helper for building UI and parts in code: Ui.new("Frame", { Size = ..., Parent = ... })

local Ui = {}

function Ui.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)
	local parent = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(instance :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function Ui.corner(radius: number?): Instance
	return Ui.new("UICorner", { CornerRadius = UDim.new(0, radius or 10) })
end

function Ui.stroke(thickness: number?): Instance
	return Ui.new("UIStroke", { Thickness = thickness or 2, Color = Color3.fromRGB(30, 30, 30) })
end

-- A rounded, outlined text button that is comfortable to tap on phones.
function Ui.button(text: string, props: { [string]: any }?): TextButton
	local button = Ui.new("TextButton", {
		Text = text,
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundColor3 = Color3.fromRGB(255, 170, 40),
		AutoButtonColor = true,
	}, { Ui.corner(12), Ui.stroke(3), Ui.new("UIPadding", {
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 4),
	}) })
	if props then
		for key, value in props do
			(button :: any)[key] = value
		end
	end
	return button
end

function Ui.label(text: string, props: { [string]: any }?): TextLabel
	local label = Ui.new("TextLabel", {
		Text = text,
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
	}, { Ui.new("UIStroke", { Thickness = 2, Color = Color3.fromRGB(20, 20, 20) }) })
	if props then
		for key, value in props do
			(label :: any)[key] = value
		end
	end
	return label
end

return Ui
