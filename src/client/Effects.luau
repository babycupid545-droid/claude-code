--!strict
-- Client-side visual effects. Templates in ReplicatedStorage.Assets.Effects override the
-- generated defaults (see docs/ASSETS.md).

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage.Shared.Assets)

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

local function anchorAt(position: Vector3, lifetime: number): Attachment
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.one
	part.Position = position
	part.Parent = effectsFolder()
	Debris:AddItem(part, lifetime)
	local attachment = Instance.new("Attachment")
	attachment.Parent = part
	return attachment
end

local function defaultBurst(color: Color3, size: number): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
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

-- Emits every ParticleEmitter in the template (or a generated one) once at a position.
local function emitTemplate(templateName: string, position: Vector3, fallback: () -> ParticleEmitter, count: number)
	local attachment = anchorAt(position, 3)
	local template = Assets.find("Effects", templateName)
	local emitters: { ParticleEmitter } = {}
	if template then
		local clone = template:Clone()
		for _, d in clone:GetDescendants() do
			if d:IsA("ParticleEmitter") then
				table.insert(emitters, d)
			end
		end
		if clone:IsA("ParticleEmitter") then
			table.insert(emitters, clone)
		end
		for _, e in emitters do
			e.Parent = attachment
		end
		if #emitters == 0 then
			clone:Destroy()
		end
	end
	if #emitters == 0 then
		local e = fallback()
		e.Parent = attachment
		table.insert(emitters, e)
	end
	for _, e in emitters do
		e:Emit(count)
	end
	local sound = Assets.find("Sounds", templateName)
	if sound and sound:IsA("Sound") then
		local s = sound:Clone()
		s.Parent = attachment
		s:Play()
	end
end

function Effects.eggHit(position: Vector3)
	emitTemplate("EggHit", position, function()
		return defaultBurst(Color3.fromRGB(255, 220, 60), 0.6)
	end, 18)
end

function Effects.feathers(position: Vector3)
	emitTemplate("Feathers", position, function()
		return defaultBurst(Color3.fromRGB(250, 250, 245), 0.9)
	end, 40)
end

-- Confetti on each winner for a few seconds.
function Effects.win(userIds: { number })
	for _, userId in userIds do
		local player = Players:GetPlayerByUserId(userId)
		local character = player and player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			emitTemplate("Win", (root :: BasePart).Position + Vector3.new(0, 4, 0), function()
				local e = defaultBurst(Color3.fromHSV(math.random(), 0.8, 1), 0.5)
				e.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
					ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 220, 60)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 160, 255)),
				})
				e.Speed = NumberRange.new(25, 45)
				e.Lifetime = NumberRange.new(1.5, 3)
				e.Acceleration = Vector3.new(0, -15, 0)
				return e
			end, 120)
		end
	end
end

return Effects
