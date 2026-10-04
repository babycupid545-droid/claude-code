--!strict
-- UI animation toolkit: smooth show/hide (fade + gentle scale), punches, shakes, count-ups,
-- shines and responsive buttons.
--
-- Every animation targets fixed values (scale 1, the element's home position, its original
-- transparency) and cancels the previous tween on the same property first, so rapid or
-- overlapping animations can never stack up and make things grow or drift.
-- Pieces scale through a child UIScale named "AnimScale" (created if missing).

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Sfx = require(script.Parent.Sfx)

local Anim = {}

local SHOW = TweenInfo.new(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local SHOW_FADE = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local HIDE = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local HOVER = TweenInfo.new(0.16, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local PRESS = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PUNCH = TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

-- Running tweens by object and property, so a new tween replaces the old one.
local running: { [Instance]: { [string]: Tween } } = setmetatable({}, { __mode = "k" }) :: any

local function play(obj: Instance, info: TweenInfo, props: { [string]: any }): Tween
	local mine = running[obj]
	if not mine then
		mine = {}
		running[obj] = mine
	end
	for prop in props do
		local old = mine[prop]
		if old then
			old:Cancel()
		end
	end
	local t = TweenService:Create(obj, info, props)
	for prop in props do
		mine[prop] = t
	end
	t:Play()
	return t
end

function Anim.tween(obj: Instance, info: TweenInfo | number, props: { [string]: any }): Tween
	local ti = if typeof(info) == "number" then TweenInfo.new(info, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) else info
	return play(obj, ti :: TweenInfo, props)
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

-- Fading -------------------------------------------------------------------------------------
-- Each element's design-time transparency is remembered the first time it's seen, and fades
-- always go between that and fully transparent.

local FADE_PROPS: { [string]: { string } } = {
	Frame = { "BackgroundTransparency" },
	TextLabel = { "BackgroundTransparency", "TextTransparency" },
	TextButton = { "BackgroundTransparency", "TextTransparency" },
	ImageLabel = { "BackgroundTransparency", "ImageTransparency" },
	ImageButton = { "BackgroundTransparency", "ImageTransparency" },
	ScrollingFrame = { "BackgroundTransparency", "ScrollBarImageTransparency" },
	UIStroke = { "Transparency" },
}
local MAX_FADE = 80 -- bigger widgets just scale (fading hundreds of pieces costs too much)

local originals: { [Instance]: { [string]: number } } = setmetatable({}, { __mode = "k" }) :: any
local fading: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function original(inst: Instance, prop: string): number
	local saved = originals[inst]
	if not saved then
		saved = {}
		originals[inst] = saved
	end
	local v = saved[prop]
	if v == nil then
		v = (inst :: any)[prop] :: number
		saved[prop] = v
	end
	return v
end

local function fadeTargets(root: Instance): { Instance }?
	local list = { root }
	for _, d in root:GetDescendants() do
		if FADE_PROPS[d.ClassName] then
			table.insert(list, d)
			if #list > MAX_FADE then
				return nil
			end
		end
	end
	return list
end

-- Fades `root` and its pieces in (to their design values) or out (to invisible).
local function fade(root: Instance, visible: boolean, info: TweenInfo): boolean
	local targets = fadeTargets(root)
	if not targets then
		return false
	end
	fading[root] = not visible
	for _, inst in targets do
		local props = FADE_PROPS[inst.ClassName]
		if props then
			local goal = {}
			for _, prop in props do
				local base = original(inst, prop)
				if visible then
					goal[prop] = base
				else
					goal[prop] = 1
				end
			end
			play(inst, info, goal)
		end
	end
	return true
end

-- Puts every piece straight back to its design transparency.
local function unfade(root: Instance)
	if fading[root] == nil then
		return
	end
	fading[root] = nil
	local targets = fadeTargets(root)
	if not targets then
		return
	end
	for _, inst in targets do
		local saved = originals[inst]
		if saved then
			for prop, value in saved do
				local mine = running[inst]
				if mine and mine[prop] then
					mine[prop]:Cancel()
				end
				(inst :: any)[prop] = value
			end
		end
	end
end

-- Show / hide ----------------------------------------------------------------------------------

-- Shows with a soft fade and a small grow, optionally after a delay.
function Anim.pop(obj: GuiObject, delay: number?)
	local scale = Anim.scaleOf(obj)
	local function go()
		local didFade = false
		if not obj.Visible or fading[obj] then
			scale.Scale = 0.86
			-- Start from transparent, then fade to the design values.
			local targets = fadeTargets(obj)
			if targets then
				for _, inst in targets do
					local props = FADE_PROPS[inst.ClassName]
					if props then
						for _, prop in props do
							local _ = original(inst, prop)
							local target: any = inst
							target[prop] = 1
						end
					end
				end
				didFade = true
			end
		end
		obj.Visible = true
		play(scale, SHOW, { Scale = 1 })
		if didFade then
			fade(obj, true, SHOW_FADE)
		end
	end
	if delay and delay > 0 then
		task.delay(delay, go)
	else
		go()
	end
end
Anim.show = Anim.pop

-- Fades and shrinks a little, then hides.
function Anim.hide(obj: GuiObject, onDone: (() -> ())?)
	if not obj.Visible then
		if onDone then
			onDone()
		end
		return
	end
	local scale = Anim.scaleOf(obj)
	fade(obj, false, HIDE)
	local t = play(scale, HIDE, { Scale = 0.9 })
	t.Completed:Once(function(state)
		if state == Enum.PlaybackState.Completed then
			obj.Visible = false
			scale.Scale = 1
			unfade(obj)
		end
		if onDone then
			onDone()
		end
	end)
end

function Anim.setShown(obj: GuiObject, shown: boolean)
	local hiding = fading[obj] == true
	if shown and (not obj.Visible or hiding) then
		Anim.pop(obj)
	elseif not shown and obj.Visible and not hiding then
		Anim.hide(obj)
	end
end

-- A quick bump on something that just changed (always settles back to exactly 1).
function Anim.punch(obj: GuiObject, amount: number?)
	local scale = Anim.scaleOf(obj)
	if fading[obj] then
		return
	end
	scale.Scale = 1 + math.min(amount or 0.12, 0.25)
	play(scale, PUNCH, { Scale = 1 })
end

-- Slides in from an offset relative to the element's home position.
local homes: { [GuiObject]: UDim2 } = setmetatable({}, { __mode = "k" }) :: any
local function home(obj: GuiObject): UDim2
	local h = homes[obj]
	if not h then
		h = obj.Position
		homes[obj] = h
	end
	return h
end

function Anim.slideIn(obj: GuiObject, from: UDim2, duration: number?)
	local target = home(obj)
	obj.Position = target + from
	obj.Visible = true
	play(obj, TweenInfo.new(duration or 0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = target })
end

local shaking: { [GuiObject]: number } = setmetatable({}, { __mode = "k" }) :: any
function Anim.shake(obj: GuiObject, strength: number?, duration: number?)
	local base = home(obj)
	local s = strength or 5
	local stop = os.clock() + (duration or 0.3)
	local already = shaking[obj] ~= nil
	shaking[obj] = stop
	if already then
		return
	end
	task.spawn(function()
		while obj.Parent and os.clock() < (shaking[obj] or 0) do
			local left = ((shaking[obj] or 0) - os.clock()) / (duration or 0.3)
			local k = math.clamp(left, 0, 1)
			obj.Position = base + UDim2.fromOffset(math.random(-s, s) * k, math.random(-s, s) * k)
			task.wait(0.025)
		end
		shaking[obj] = nil
		obj.Position = base
	end)
end

-- Counts a number label from one value to another (a new count replaces a running one).
local counting: { [TextLabel]: NumberValue } = setmetatable({}, { __mode = "k" }) :: any
function Anim.countTo(label: TextLabel, from: number, to: number, duration: number?, format: ((number) -> string)?)
	local fmt = format or function(n: number): string
		return tostring(math.floor(n + 0.5))
	end
	local old = counting[label]
	if old then
		old:Destroy()
	end
	local value = Instance.new("NumberValue")
	value.Value = from
	counting[label] = value
	value.Changed:Connect(function(v)
		label.Text = fmt(v)
	end)
	local t = play(value, TweenInfo.new(duration or 0.6, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Value = to })
	t.Completed:Once(function(state)
		if state == Enum.PlaybackState.Completed and counting[label] == value then
			label.Text = fmt(to)
			counting[label] = nil
			value:Destroy()
		end
	end)
end

-- Sweeps a UIGradient across a frame now and then (for shiny rare cards).
function Anim.shine(frame: GuiObject)
	local gradient = frame:FindFirstChildOfClass("UIGradient")
	if not gradient or frame:GetAttribute("Shining") then
		return
	end
	frame:SetAttribute("Shining", true)
	frame.Visible = true
	task.spawn(function()
		while frame.Parent do
			gradient.Offset = Vector2.new(-1, 0)
			local t = play(gradient, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { Offset = Vector2.new(1, 0) })
			t.Completed:Wait()
			task.wait(1.8 + math.random() * 1.5)
		end
	end)
end

-- Buttons: lift on hover, squish on press, settle on release, with sounds. The button's
-- Inner panel brightens a touch on hover.
local juiced: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
function Anim.juice(button: GuiButton)
	if juiced[button] then
		return
	end
	juiced[button] = true
	local scale = Anim.scaleOf(button)
	local inner: GuiObject? = nil
	local border = button:FindFirstChild("Border")
	if border then
		inner = border:FindFirstChild("Inner") :: GuiObject?
	end
	local hovering = false
	local function brighten(on: boolean)
		if inner then
			local base = original(inner, "BackgroundTransparency")
			local accent = inner:GetAttribute("Accent")
			if typeof(accent) ~= "Color3" then
				play(inner, HOVER, { BackgroundTransparency = if on then math.max(0, base - 0.08) else base })
			end
		end
	end
	button.MouseEnter:Connect(function()
		hovering = true
		play(scale, HOVER, { Scale = 1.05 })
		brighten(true)
		Sfx.play("UiHover", { volume = 0.5 })
	end)
	button.MouseLeave:Connect(function()
		hovering = false
		play(scale, HOVER, { Scale = 1 })
		brighten(false)
	end)
	button.MouseButton1Down:Connect(function()
		play(scale, PRESS, { Scale = 0.94 })
	end)
	local function release()
		play(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = if hovering then 1.05 else 1 })
	end
	button.MouseButton1Up:Connect(release)
	button.Activated:Connect(function()
		Sfx.play("UiClick")
		release()
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

-- Slowly spins every image tagged "SpinUi" (sunbursts).
function Anim.start()
	RunService.RenderStepped:Connect(function(dt: number)
		for _, img in CollectionService:GetTagged("SpinUi") do
			if img:IsA("GuiObject") and img.Visible then
				img.Rotation = (img.Rotation + dt * 14) % 360
			end
		end
	end)
end

return Anim
