--!strict
-- Client-side visuals for cosmetics: egg models, hit effects, win effects and feathers.
-- Art in ReplicatedStorage.Assets overrides the generated stand-ins (see docs/ASSETS.md).

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Assets = require(Shared.Assets)
local Cosmetics = require(Shared.Cosmetics)

local Effects = {}

local function effectsFolder(): Folder
	local existing = workspace:FindFirstChild("ClientEffects")
	if existing then
		return existing :: Folder
	end
	local folder = Instance.new("Folder")
	folder.Name = "ClientEffects"
	folder.Parent = workspace
	return folder
end

local function anchorPart(position: Vector3, size: Vector3, lifetime: number): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = size
	part.Position = position
	part.Parent = effectsFolder()
	Debris:AddItem(part, lifetime)
	return part
end

local function colorSequence(colors: { Color3 }?): ColorSequence
	if not colors or #colors == 0 then
		return ColorSequence.new(Color3.new(1, 1, 1))
	end
	if #colors == 1 then
		return ColorSequence.new(colors[1])
	end
	local keys = {}
	for i, c in colors do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), c))
	end
	return ColorSequence.new(keys)
end

local function makeEmitter(colors: { Color3 }?, size: number): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = colorSequence(colors)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Lifetime = NumberRange.new(0.5, 1.1)
	emitter.Speed = NumberRange.new(12, 26)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, -30, 0)
	emitter.Drag = 2
	emitter.RotSpeed = NumberRange.new(-200, 200)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.Enabled = false
	return emitter
end

local function burst(position: Vector3, colors: { Color3 }?, count: number, size: number, glow: boolean?)
	local part = anchorPart(position, Vector3.one, 4)
	local emitter = makeEmitter(colors, size)
	if glow then
		emitter.LightEmission = 1
		emitter.Acceleration = Vector3.zero
	end
	emitter.Parent = part
	emitter:Emit(count)
end

local function playSound(name: string, parent: Instance)
	local sound = Assets.find("Sounds", name)
	if sound and sound:IsA("Sound") then
		local s = sound:Clone()
		s.Parent = parent
		s:Play()
	end
end

-- Plays an art template: emits every disabled ParticleEmitter once (EmitCount attribute,
-- default 30) and switches enabled ones on for its Duration attribute (default 3s).
local function playTemplate(template: Instance, position: Vector3): boolean
	local clone = template:Clone()
	local emitters: { ParticleEmitter } = {}
	if clone:IsA("ParticleEmitter") then
		table.insert(emitters, clone)
	end
	for _, d in clone:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			table.insert(emitters, d)
		end
	end
	if #emitters == 0 then
		clone:Destroy()
		return false
	end
	local duration = template:GetAttribute("Duration")
	local lifetime = if type(duration) == "number" then duration else 3
	local part = anchorPart(position, Vector3.one, lifetime + 3)
	for _, e in emitters do
		e.Parent = part
		if e.Enabled then
			task.delay(lifetime, function()
				e.Enabled = false
			end)
		else
			local count = e:GetAttribute("EmitCount")
			e:Emit(if type(count) == "number" then count else 30)
		end
	end
	if clone.Parent == nil then
		clone:Destroy()
	end
	return true
end

local function floatText(position: Vector3, text: string, color: Color3)
	local part = anchorPart(position, Vector3.one, 1.2)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(80, 50)
	gui.AlwaysOnTop = true
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = color
	label.Font = Enum.Font.FredokaOne
	label.Parent = gui
	TweenService:Create(gui, TweenInfo.new(1.1), { StudsOffset = Vector3.new(0, 4, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(1.1), { TextTransparency = 1 }):Play()
end

-- Egg projectiles -----------------------------------------------------------------------

function Effects.makeEgg(skinId: string?): Instance
	local skin = Cosmetics.resolve("EggSkin", skinId)
	local template = Assets.find("EggSkins", skin.id)
	if template and (template:IsA("BasePart") or template:IsA("Model")) then
		local clone = template:Clone()
		local parts: { Instance } = clone:GetDescendants()
		table.insert(parts, clone)
		for _, d in parts do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
			end
		end
		return clone
	end

	local look = skin.look
	local part = Instance.new("Part")
	part.Size = Vector3.new(1, 1, 1)
	local colors = look.colors or { Color3.new(1, 1, 1) }
	part.Color = colors[math.random(1, #colors)]
	part.Material = look.material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.new(1, 1, 1.35)
	mesh.Parent = part
	if look.fire then
		local fire = Instance.new("Fire")
		fire.Size = 3
		fire.Heat = 0
		fire.Parent = part
	end
	if look.sparkles then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = part.Color
		sparkles.Parent = part
	end
	if look.trail then
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, 0.3, 0)
		a0.Parent = part
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -0.3, 0)
		a1.Parent = part
		local trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Color = ColorSequence.new(look.trail)
		trail.Lifetime = 0.25
		trail.Transparency = NumberSequence.new(0.2, 1)
		trail.Parent = part
	end
	return part
end

-- Hit effects ---------------------------------------------------------------------------

function Effects.eggHit(position: Vector3, effectId: string?)
	local item = Cosmetics.resolve("HitEffect", effectId)
	local template = Assets.find("HitEffects", item.id)
	if not (template and playTemplate(template, position)) then
		local look = item.look
		burst(position, look.colors, look.count or 18, 0.6, look.special == "Glow")
		if look.special == "Explosion" then
			local explosion = Instance.new("Explosion")
			explosion.Position = position
			explosion.BlastRadius = 4
			explosion.BlastPressure = 0
			explosion.DestroyJointRadiusPercent = 0
			explosion.Parent = effectsFolder()
		end
		if look.text then
			floatText(position, look.text, (look.colors or { Color3.new(1, 1, 1) })[1])
		end
	end
	local part = anchorPart(position, Vector3.one, 3)
	playSound("EggHit", part)
end

function Effects.feathers(position: Vector3)
	local template = Assets.find("Effects", "Feathers")
	if not (template and playTemplate(template, position)) then
		burst(position, { Color3.fromRGB(250, 250, 245) }, 40, 0.9)
	end
	playSound("Feathers", anchorPart(position, Vector3.one, 3))
end

-- Win effects ---------------------------------------------------------------------------

local function confetti(position: Vector3, colors: { Color3 }?)
	local part = anchorPart(position, Vector3.one, 5)
	local e = makeEmitter(colors, 0.5)
	e.Speed = NumberRange.new(25, 45)
	e.Lifetime = NumberRange.new(1.5, 3)
	e.Acceleration = Vector3.new(0, -15, 0)
	e.Parent = part
	e:Emit(120)
end

local function rain(position: Vector3, colors: { Color3 }?)
	local part = anchorPart(position + Vector3.new(0, 14, 0), Vector3.new(14, 1, 14), 7)
	local e = makeEmitter(colors, 0.4)
	e.Shape = Enum.ParticleEmitterShape.Box
	e.EmissionDirection = Enum.NormalId.Bottom
	e.SpreadAngle = Vector2.new(5, 5)
	e.Speed = NumberRange.new(8, 14)
	e.Lifetime = NumberRange.new(1.5, 2)
	e.LightEmission = 0.6
	e.Rate = 120
	e.Enabled = true
	e.Parent = part
	task.delay(4, function()
		e.Enabled = false
	end)
end

local function fireworks(position: Vector3, colors: { Color3 }?)
	local palette = colors or { Color3.new(1, 1, 1) }
	for i = 1, 3 do
		task.delay((i - 1) * 0.5, function()
			local color = palette[math.random(1, #palette)]
			local rocket = anchorPart(position, Vector3.new(0.6, 0.6, 0.6), 1)
			rocket.Transparency = 0
			rocket.Material = Enum.Material.Neon
			rocket.Color = color
			local top = position + Vector3.new(math.random(-8, 8), math.random(22, 30), math.random(-8, 8))
			local tween = TweenService:Create(rocket, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = top })
			tween:Play()
			tween.Completed:Wait()
			burst(top, { color, Color3.new(1, 1, 1) }, 70, 0.7, true)
		end)
	end
end

local function pillar(position: Vector3, colors: { Color3 }?)
	local beam = anchorPart(position + Vector3.new(0, 100, 0), Vector3.new(200, 6, 6), 5)
	beam.Shape = Enum.PartType.Cylinder
	beam.CFrame = CFrame.new(beam.Position) * CFrame.Angles(0, 0, math.rad(90))
	beam.Material = Enum.Material.Neon
	beam.Color = (colors or { Color3.new(1, 1, 0.8) })[1]
	beam.Transparency = 0.2
	TweenService:Create(beam, TweenInfo.new(4), { Transparency = 1, Size = Vector3.new(200, 1, 1) }):Play()
	burst(position, colors, 60, 0.8, true)
end

local WIN_STYLES: { [string]: (Vector3, { Color3 }?) -> () } = {
	Burst = confetti,
	Rain = rain,
	Fireworks = fireworks,
	Pillar = pillar,
	Supernova = function(position, colors)
		pillar(position, { Color3.new(1, 1, 1) })
		fireworks(position, colors)
		confetti(position, colors)
	end,
}

function Effects.winAt(position: Vector3, effectId: string?)
	local item = Cosmetics.resolve("WinEffect", effectId)
	local template = Assets.find("WinEffects", item.id)
	if not (template and playTemplate(template, position)) then
		local style: (Vector3, { Color3 }?) -> () = WIN_STYLES[item.look.special or "Burst"] or confetti
		style(position, item.look.colors)
	end
	playSound("Win", anchorPart(position, Vector3.one, 5))
end

function Effects.win(celebrations: { { userId: number, effect: string } })
	for _, c in celebrations do
		local player = Players:GetPlayerByUserId(c.userId)
		local character = player and player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			Effects.winAt((root :: BasePart).Position + Vector3.new(0, 3, 0), c.effect)
		end
	end
end

Effects.floatText = floatText

return Effects
