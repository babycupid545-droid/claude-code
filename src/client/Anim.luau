--!strict
-- UI animation toolkit: pops, punches, slides, shakes, count-ups, shines and juicy buttons.
-- Pieces scale through a child UIScale named "AnimScale" (created if missing).

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Sfx = require(script.Parent.Sfx)

local Anim = {}

local BACK_OUT = TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local BACK_IN = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In)
local QUICK = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

function Anim.tween(obj: Instance, info: TweenInfo | number, props: { [string]: any }): Tween
	local ti = if typeof(info) == "number" then TweenInfo.new(info, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) else info
	local t = TweenService:Create(obj, ti :: TweenInfo, props)
	t:Play()
	return t
end

function Anim.scaleOf(obj: GuiObject): UIScale
	local existing = obj:FindFirstChild("AnimScale")
	if existing and existing:IsA("UIScale") then
		return existing
	end
	local scale = Instance.new("UIScale")
	scale.Name = "AnimScale"
	scale.Parent = obj
	return scale
end

-- Shows with a bouncy grow from nothing.
function Anim.pop(obj: GuiObject, delay: number?)
	local scale = Anim.scaleOf(obj)
	scale.Scale = 0
	obj.Visible = true
	if delay and delay > 0 then
		task.delay(delay, function()
			Anim.tween(scale, BACK_OUT, { Scale = 1 })
		end)
	else
		Anim.tween(scale, BACK_OUT, { Scale = 1 })
	end
end

-- Shrinks away, then hides.
function Anim.hide(obj: GuiObject, onDone: (() -> ())?)
	if not obj.Visible then
		if onDone then
			onDone()
		end
		return
	end
	local scale = Anim.scaleOf(obj)
	local t = Anim.tween(scale, BACK_IN, { Scale = 0 })
	t.Completed:Once(function(state)
		if state == Enum.PlaybackState.Completed then
			obj.Visible = false
			scale.Scale = 1
		end
		if onDone then
			onDone()
		end
	end)
end

function Anim.setShown(obj: GuiObject, shown: boolean)
	if shown and not obj.Visible then
		Anim.pop(obj)
	elseif not shown and obj.Visible then
		Anim.hide(obj)
	end
end

-- A quick "boing" on something that just changed.
function Anim.punch(obj: GuiObject, amount: number?)
	local scale = Anim.scaleOf(obj)
	scale.Scale = 1 + (amount or 0.18)
	Anim.tween(scale, TweenInfo.new(0.35, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Scale = 1 })
end

-- Slides in from an offset (in scale units of the parent).
function Anim.slideIn(obj: GuiObject, from: UDim2, duration: number?)
	local target = obj.Position
	obj.Position = target + from
	obj.Visible = true
	Anim.tween(obj, TweenInfo.new(duration or 0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = target })
end

function Anim.shake(obj: GuiObject, strength: number?, duration: number?)
	local base = obj.Position
	local s = strength or 6
	local stop = os.clock() + (duration or 0.3)
	task.spawn(function()
		while os.clock() < stop and obj.Parent do
			obj.Position = base + UDim2.fromOffset(math.random(-s, s), math.random(-s, s))
			task.wait(0.02)
		end
		obj.Position = base
	end)
end

-- Counts a number label up or down.
function Anim.countTo(label: TextLabel, from: number, to: number, duration: number?, format: ((number) -> string)?)
	local fmt = format or function(n: number): string
		return tostring(math.floor(n + 0.5))
	end
	local value = Instance.new("NumberValue")
	value.Value = from
	value.Changed:Connect(function(v)
		label.Text = fmt(v)
	end)
	local t = Anim.tween(value, TweenInfo.new(duration or 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = to })
	t.Completed:Once(function()
		label.Text = fmt(to)
		value:Destroy()
	end)
end

-- Sweeps a UIGradient across a frame (for shiny rare cards).
function Anim.shine(frame: GuiObject)
	local gradient = frame:FindFirstChildOfClass("UIGradient")
	if not gradient then
		return
	end
	frame.Visible = true
	task.spawn(function()
		while frame.Parent do
			gradient.Offset = Vector2.new(-1, 0)
			local t = Anim.tween(gradient, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { Offset = Vector2.new(1, 0) })
			t.Completed:Wait()
			task.wait(1.6 + math.random() * 1.5)
		end
	end)
end

-- Juicy buttons: grow on hover, face presses down on click, with sounds.
local juiced: { [Instance]: boolean } = {}
function Anim.juice(button: GuiButton)
	if juiced[button] then
		return
	end
	juiced[button] = true
	local scale = Anim.scaleOf(button)
	local face = button:FindFirstChild("Face") :: GuiObject?
	local faceHome = if face then face.Position else nil
	button.MouseEnter:Connect(function()
		Anim.tween(scale, QUICK, { Scale = 1.06 })
		Sfx.play("UiHover")
	end)
	button.MouseLeave:Connect(function()
		Anim.tween(scale, QUICK, { Scale = 1 })
		if face and faceHome then
			Anim.tween(face, QUICK, { Position = faceHome })
		end
	end)
	button.MouseButton1Down:Connect(function()
		Anim.tween(scale, QUICK, { Scale = 0.94 })
		if face and faceHome then
			Anim.tween(face, QUICK, { Position = faceHome + UDim2.fromOffset(0, 4) })
		end
	end)
	local function release()
		Anim.tween(scale, BACK_OUT, { Scale = 1 })
		if face and faceHome then
			Anim.tween(face, QUICK, { Position = faceHome })
		end
	end
	button.MouseButton1Up:Connect(release)
	button.Activated:Connect(function()
		Sfx.play("UiClick")
		release()
	end)
	button.Destroying:Connect(function()
		juiced[button] = nil
	end)
end

-- Juices every button marked Juicy under `root`, now and in the future.
function Anim.autoJuice(root: Instance)
	local function check(d: Instance)
		if d:IsA("GuiButton") and d:GetAttribute("Juicy") then
			Anim.juice(d)
		end
	end
	for _, d in root:GetDescendants() do
		check(d)
	end
	root.DescendantAdded:Connect(check)
end

-- Spins every image tagged "SpinUi" (sunbursts).
function Anim.start()
	RunService.RenderStepped:Connect(function(dt: number)
		for _, img in CollectionService:GetTagged("SpinUi") do
			if img:IsA("GuiObject") and img.Visible then
				img.Rotation = (img.Rotation + dt * 18) % 360
			end
		end
	end)
end

return Anim
