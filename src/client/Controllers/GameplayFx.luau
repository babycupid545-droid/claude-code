--!strict
-- World effects for the round's systems:
--   * a glowing beacon over the sidewalk everyone must reach
--   * sprinkler sprays on the median
--   * golden egg pickups (Egg Rain)
--   * lighting for events (Night Drive, Fog) and car headlights at night
--   * ambient particles: pollen over the median, petals drifting across the arena, and
--     fireflies at night

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Layout = require(Shared.Layout)
local Remotes = require(Shared.Remotes)
local RoundState = require(Shared.RoundState)

local CameraFx = require(script.Parent.Parent.CameraFx)
local Effects = require(script.Parent.Parent.Effects)
local Sfx = require(script.Parent.Parent.Sfx)

local GameplayFx = {}

local player = Players.LocalPlayer
local GREEN = Color3.fromRGB(110, 255, 140)

-- Crossing beacon ------------------------------------------------------------------------------

local beacon: Model? = nil

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

local function buildBeacon(): Model
	local m = Instance.new("Model")
	m.Name = "CrossBeacon"
	local pillar = part({ Name = "Pillar", Shape = Enum.PartType.Cylinder, Size = Vector3.new(60, 6, 6), Color = GREEN, Transparency = 0.75 })
	pillar.CFrame = CFrame.new(0, 30, 0) * CFrame.Angles(0, 0, math.rad(90))
	pillar.Parent = m
	-- A big chevron arrow pointing down at the safe side.
	for _, arm in { -1, 1 } do
		local bar = part({ Name = "Arrow", Size = Vector3.new(9, 2.2, 2.2), Color = GREEN })
		bar.CFrame = CFrame.new(arm * 2.8, 18, 0) * CFrame.Angles(0, 0, arm * math.rad(-45))
		bar.Parent = m
	end
	local glow = part({ Name = "Ring", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 20, 20), Color = GREEN, Transparency = 0.6 })
	glow.CFrame = CFrame.new(0, Config.Map.SidewalkTopY + 0.15, 0) * CFrame.Angles(0, 0, math.rad(90))
	glow.Parent = m
	local light = Instance.new("PointLight")
	light.Color = GREEN
	light.Range = 30
	light.Brightness = 2
	light.Parent = glow
	m.PrimaryPart = glow
	m.Parent = workspace
	return m
end

local function updateBeacon()
	local target = RoundState:GetAttribute("CrossTarget")
	local alive = player:GetAttribute("Alive") == true
	if type(target) ~= "string" or target == "" or not alive then
		if beacon then
			beacon:Destroy()
			beacon = nil
		end
		return
	end
	local b = beacon or buildBeacon()
	beacon = b
	b:SetAttribute("Target", target)
end

local function stepBeacon()
	local b = beacon
	if not b then
		return
	end
	local target = b:GetAttribute("Target")
	local z = (Layout.innerEdge + Config.Map.SidewalkDepth / 2) * (if target == "A" then -1 else 1)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local x = if root then math.clamp(root.Position.X, -Layout.halfLength + 20, Layout.halfLength - 20) else 0
	-- Hide it once you're already there.
	local there = root ~= nil and Layout.zoneOf(root.Position.Z) == target
	local bob = math.sin(os.clock() * 4) * 1.5
	b:PivotTo(CFrame.new(x, bob, z))
	for _, p in b:GetChildren() do
		if p:IsA("BasePart") then
			p.LocalTransparencyModifier = if there then 0.85 else 0
		end
	end
end

-- Sprinklers ------------------------------------------------------------------------------------

local sprinklerHeads: { BasePart } = {}

local function findSprinklers()
	sprinklerHeads = {}
	local arena = workspace:FindFirstChild("Arena")
	local median = arena and arena:FindFirstChild("Median")
	if not median then
		return
	end
	for _, d in median:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Sprinkler") then
			table.insert(sprinklerHeads, d)
		end
	end
	table.sort(sprinklerHeads, function(a, b)
		return (a:GetAttribute("Sprinkler") :: number) < (b:GetAttribute("Sprinkler") :: number)
	end)
end

local function spray(head: BasePart, big: boolean)
	local holder = part({ Transparency = 1, Size = Vector3.one, Position = head.Position + Vector3.new(0, 0.6, 0) })
	holder.Parent = workspace
	local attachment = Instance.new("Attachment")
	attachment.Parent = holder
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(Color3.fromRGB(170, 220, 255), Color3.fromRGB(240, 250, 255))
	e.LightEmission = 0.3
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, if big then 1.4 else 0.6) })
	e.Speed = if big then NumberRange.new(30, 45) else NumberRange.new(6, 10)
	e.SpreadAngle = if big then Vector2.new(40, 40) else Vector2.new(15, 15)
	e.Acceleration = Vector3.new(0, -60, 0)
	e.Lifetime = NumberRange.new(0.6, 1.2)
	e.EmissionDirection = Enum.NormalId.Top
	e.Rate = if big then 400 else 60
	e.Parent = attachment
	task.delay(if big then 0.45 else 0.9, function()
		e.Enabled = false
	end)
	task.delay(2.5, function()
		holder:Destroy()
	end)
	if big then
		Sfx.playAt("Crumble", head.Position, { pitch = 1.8, volume = 0.6 })
		Sfx.playAt("Glide", head.Position, { pitch = 0.6 })
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and (root.Position - head.Position).Magnitude < Config.Median.SprinklerRadius + 4 then
			CameraFx.shake(0.3)
		end
	else
		Sfx.playAt("Glide", head.Position, { pitch = 1.6, volume = 0.5 })
	end
end

-- Ambient particles -----------------------------------------------------------------------------

local fireflies: ParticleEmitter? = nil

local function ambientEmitter(name: string, cf: CFrame, size: Vector3, props: { [string]: any }): ParticleEmitter
	local box = part({ Name = name, Transparency = 1, Size = size, CFrame = cf })
	box.Material = Enum.Material.SmoothPlastic
	box.Parent = workspace
	local e = Instance.new("ParticleEmitter")
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = box
	return e
end

local function buildAmbient()
	local M = Config.Map
	local y = M.RoadTopY
	-- Warm pollen motes hanging over the grass median.
	ambientEmitter("MedianPollen", CFrame.new(0, y + 6, 0), Vector3.new(Layout.halfLength * 2, 8, M.MedianWidth), {
		Rate = 14,
		Lifetime = NumberRange.new(4, 7),
		Speed = NumberRange.new(0.3, 1),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, 0.3, 0),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, 0.35), NumberSequenceKeypoint.new(1, 0) }),
		Color = ColorSequence.new(Color3.fromRGB(255, 240, 170)),
		LightEmission = 0.7,
		Transparency = NumberSequence.new(0.2),
	})
	-- Petals and leaves tumbling across the whole arena on the breeze.
	ambientEmitter("Petals", CFrame.new(0, y + 45, 0), Vector3.new(Layout.halfLength * 2.2, 4, Layout.outerEdge * 2.2), {
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Rate = 10,
		Lifetime = NumberRange.new(8, 12),
		Speed = NumberRange.new(1, 2),
		SpreadAngle = Vector2.new(40, 40),
		EmissionDirection = Enum.NormalId.Bottom,
		Acceleration = Vector3.new(3, -2.5, 1),
		Drag = 0.5,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-120, 120),
		Size = NumberSequence.new(0.45),
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 160, 190)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 230, 150)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 220, 110)),
		}),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.1, 0.1), NumberSequenceKeypoint.new(0.9, 0.1), NumberSequenceKeypoint.new(1, 1) }),
	})
	-- Fireflies, only during Night Drive.
	fireflies = ambientEmitter("Fireflies", CFrame.new(0, y + 7, 0), Vector3.new(Layout.halfLength * 2, 10, Layout.outerEdge * 2), {
		Rate = 0,
		Lifetime = NumberRange.new(3, 6),
		Speed = NumberRange.new(0.5, 2),
		SpreadAngle = Vector2.new(180, 180),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.5), NumberSequenceKeypoint.new(0.6, 0.15), NumberSequenceKeypoint.new(1, 0) }),
		Color = ColorSequence.new(Color3.fromRGB(200, 255, 120)),
		LightEmission = 1,
		LightInfluence = 0,
	})
end

-- Events: lighting ------------------------------------------------------------------------------

type Saved = { clock: number, brightness: number, ambient: Color3, outdoor: Color3, density: number?, haze: number? }
local saved: Saved? = nil
local nightActive = false

local function atmosphere(): Atmosphere?
	return Lighting:FindFirstChildOfClass("Atmosphere")
end

local function restoreLighting()
	local s = saved
	if not s then
		return
	end
	saved = nil
	TweenService:Create(Lighting, TweenInfo.new(2.5), {
		ClockTime = s.clock,
		Brightness = s.brightness,
		Ambient = s.ambient,
		OutdoorAmbient = s.outdoor,
	}):Play()
	local atm = atmosphere()
	if atm and s.density then
		TweenService:Create(atm, TweenInfo.new(2.5), { Density = s.density, Haze = s.haze or atm.Haze }):Play()
	end
end

local function save()
	if saved then
		return
	end
	local atm = atmosphere()
	saved = {
		clock = Lighting.ClockTime,
		brightness = Lighting.Brightness,
		ambient = Lighting.Ambient,
		outdoor = Lighting.OutdoorAmbient,
		density = if atm then atm.Density else nil,
		haze = if atm then atm.Haze else nil,
	}
end

local function onEvent()
	local id = RoundState:GetAttribute("Event")
	nightActive = id == "NightDrive"
	if fireflies then
		fireflies.Rate = if nightActive then 60 else 0
	end
	if id == "NightDrive" then
		save()
		TweenService:Create(Lighting, TweenInfo.new(2.5), {
			ClockTime = 0.3,
			Brightness = 1.2,
			Ambient = Color3.fromRGB(40, 45, 90),
			OutdoorAmbient = Color3.fromRGB(50, 60, 110),
		}):Play()
	elseif id == "Fog" then
		save()
		local atm = atmosphere()
		if atm then
			TweenService:Create(atm, TweenInfo.new(2.5), { Density = 0.78, Haze = 3 }):Play()
		end
	else
		restoreLighting()
	end
	if type(id) == "string" and id ~= "" then
		Sfx.play("SuddenDeath", { volume = 0.6, pitch = 1.2 })
	end
end

-- Headlights at night: SpotLights on every car's lights.
local function updateHeadlights()
	local traffic = workspace:FindFirstChild("Traffic")
	if not traffic then
		return
	end
	for _, car in traffic:GetChildren() do
		if car:IsA("Model") and car:GetAttribute("Lit") ~= nightActive then
			car:SetAttribute("Lit", nightActive)
			for _, d in car:GetDescendants() do
				if d:IsA("BasePart") and d.Name:find("Headlight") then
					local light = d:FindFirstChild("Beam")
					if nightActive and not light then
						local spot = Instance.new("SpotLight")
						spot.Name = "Beam"
						spot.Face = Enum.NormalId.Front
						spot.Range = 45
						spot.Angle = 70
						spot.Brightness = 4
						spot.Color = Color3.fromRGB(255, 245, 210)
						spot.Parent = d
					elseif not nightActive and light then
						light:Destroy()
					end
				end
			end
		end
	end
end

function GameplayFx.start()
	buildAmbient()
	RoundState:GetAttributeChangedSignal("CrossTarget"):Connect(updateBeacon)
	player:GetAttributeChangedSignal("Alive"):Connect(updateBeacon)
	RoundState:GetAttributeChangedSignal("Event"):Connect(onEvent)
	updateBeacon()

	Remotes.Sprinkler.OnClientEvent:Connect(function(index: number, phase: string)
		if #sprinklerHeads == 0 then
			findSprinklers()
		end
		local head = sprinklerHeads[index]
		if head then
			spray(head, phase == "burst")
		end
	end)
	Remotes.EggPickup.OnClientEvent:Connect(function(position: Vector3, userId: number)
		Effects.winAt(position, "GoldenRain")
		Sfx.playAt("Coin", position, { pitch = 1.2 })
		if userId == player.UserId then
			Sfx.play("Sparkle")
		end
	end)

	RunService.Heartbeat:Connect(function()
		stepBeacon()
		updateHeadlights()
	end)
end

return GameplayFx
