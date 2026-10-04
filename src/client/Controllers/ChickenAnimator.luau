--!strict
-- Animates every chicken in code, on every client, from how it's moving:
--   * walk: the classic chicken head-lock (the head holds still, then snaps forward), a
--     bouncy waddle with squash on each step, knees lifting, tail swishing, dust puffs
--   * jump: a crouch, a big wing flap and tucked legs; landing squashes and kicks up dust
--   * glide: wings spread wide with fluttering tips, body pitched forward, legs trailing,
--     tail fanned, and wind trails off the wing tips
--   * shoot: a squat, the tail flicks up as the egg pops out, wings flare and the head
--     glances back
--   * idle: breathing, looking around, pecking, the odd wing ruffle; eyes blink
-- Joint motion (Motor6D.Transform) is local to each client, so every client runs this for
-- all chickens. No animation uploads needed.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local ChickenAnimator = {}

type Rig = {
	model: Model,
	root: BasePart,
	humanoid: Humanoid,
	motors: { [string]: Motor6D },
	lids: { BasePart },
	trails: { Trail },
	phase: number,
	walk: number,
	air: number,
	glide: number,
	seed: number,
	nextBlink: number,
	blinkUntil: number,
	nextPeck: number,
	peckStart: number,
	nextRuffle: number,
	ruffleStart: number,
	shootStart: number,
	landStart: number,
	landPower: number,
	wasAirborne: boolean,
	lastFallSpeed: number,
	lastStep: number,
	flapPhase: number,
}

local rigs: { [Model]: Rig } = {}
local JOINTS = { "Root", "Neck", "LeftWing", "RightWing", "LeftHip", "RightHip", "Tail" }

-- Shared dust emitter: moved to where a puff is needed, then Emit()ed.
local dustPart: Part? = nil
local dust: ParticleEmitter? = nil

local function getDust(): ParticleEmitter
	if dust and dustPart and dustPart.Parent then
		return dust
	end
	local p = Instance.new("Part")
	p.Name = "ChickenDust"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.one * 0.2
	p.Parent = workspace
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(235, 225, 205))
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1.6) })
	e.Lifetime = NumberRange.new(0.35, 0.6)
	e.Speed = NumberRange.new(2, 5)
	e.SpreadAngle = Vector2.new(80, 80)
	e.Acceleration = Vector3.new(0, 3, 0)
	e.Drag = 4
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-90, 90)
	e.EmissionDirection = Enum.NormalId.Top
	e.Rate = 0
	e.Parent = p
	dustPart, dust = p, e
	return e
end

local function puff(position: Vector3, count: number)
	local e = getDust()
	local p = dustPart :: Part
	p.CFrame = CFrame.new(position)
	e:Emit(count)
end

-- Wind trails off each wing tip, shown while gliding.
local function addTrails(model: Model): { Trail }
	local trails = {}
	for _, name in { "LeftWing", "RightWing" } do
		local wing = model:FindFirstChild(name)
		if wing and wing:IsA("BasePart") then
			local s = wing.Size
			local a0 = Instance.new("Attachment")
			a0.Name = "TrailTip"
			a0.Position = Vector3.new(0, -s.Y * 0.3, s.Z * 0.42)
			a0.Parent = wing
			local a1 = Instance.new("Attachment")
			a1.Name = "TrailBase"
			a1.Position = Vector3.new(0, -s.Y * 0.05, s.Z * 0.2)
			a1.Parent = wing
			local trail = Instance.new("Trail")
			trail.Attachment0 = a0
			trail.Attachment1 = a1
			trail.Lifetime = 0.35
			trail.MinLength = 0.1
			trail.FaceCamera = true
			trail.LightEmission = 0.4
			trail.Color = ColorSequence.new(Color3.new(1, 1, 1))
			trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) })
			trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.2) })
			trail.Enabled = false
			trail.Parent = wing
			table.insert(trails, trail)
		end
	end
	return trails
end

local function register(model: Model)
	if rigs[model] or model:GetAttribute("ChickenRig") ~= true then
		return
	end
	local root = model:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	local humanoid = model:WaitForChild("Humanoid", 10) :: Humanoid?
	if not root or not humanoid then
		return
	end
	local motors: { [string]: Motor6D } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") and table.find(JOINTS, d.Name) then
			motors[d.Name] = d
		end
	end
	local lids = {}
	for _, name in { "LidL", "LidR" } do
		local lid = model:FindFirstChild(name)
		if lid and lid:IsA("BasePart") then
			table.insert(lids, lid)
		end
	end
	local now = os.clock()
	rigs[model] = {
		model = model,
		root = root,
		humanoid = humanoid,
		motors = motors,
		lids = lids,
		trails = addTrails(model),
		phase = 0,
		walk = 0,
		air = 0,
		glide = 0,
		seed = math.random() * 100,
		nextBlink = now + math.random() * 3,
		blinkUntil = 0,
		nextPeck = now + 3 + math.random() * 4,
		peckStart = -10,
		nextRuffle = now + 8 + math.random() * 10,
		ruffleStart = -10,
		shootStart = -10,
		landStart = -10,
		landPower = 0,
		wasAirborne = false,
		lastFallSpeed = 0,
		lastStep = 0,
		flapPhase = 0,
	}
	model.Destroying:Connect(function()
		rigs[model] = nil
	end)
end

local function setT(rig: Rig, name: string, cf: CFrame)
	local m = rig.motors[name]
	if m and m.Parent then
		m.Transform = cf
	end
end

local function approach(current: number, target: number, rate: number, dt: number): number
	return current + (target - current) * math.min(1, rate * dt)
end

-- 0 -> 1 -> 0 envelope over `length` seconds since `start` (fast attack, smooth release).
local function pulse(t: number, start: number, length: number): number
	local x = (t - start) / length
	if x < 0 or x > 1 then
		return 0
	end
	if x < 0.2 then
		return math.sin(x / 0.2 * math.pi / 2)
	end
	return math.cos((x - 0.2) / 0.8 * math.pi / 2) ^ 2
end

local function animate(rig: Rig, dt: number, t: number)
	local v = rig.root.AssemblyLinearVelocity
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	local state = rig.humanoid:GetState()
	local airborne = state == Enum.HumanoidStateType.Freefall
		or state == Enum.HumanoidStateType.Jumping
		or math.abs(v.Y) > 6
	local gliding = airborne and v.Y < 0 and v.Y > -(Config.Chicken.GlideFallSpeed + 3)

	-- Landing: squash proportional to how hard we came down, plus a dust ring.
	if rig.wasAirborne and not airborne then
		rig.landStart = t
		rig.landPower = math.clamp(rig.lastFallSpeed / 60, 0.25, 1)
		puff(rig.root.Position - Vector3.new(0, rig.humanoid.HipHeight + 1, 0), math.floor(4 + rig.landPower * 8))
	end
	if airborne then
		rig.lastFallSpeed = math.max(0, -v.Y)
	end
	rig.wasAirborne = airborne

	rig.walk = approach(rig.walk, if airborne then 0 else math.clamp(speed / Config.Chicken.WalkSpeed, 0, 1.3), 10, dt)
	rig.air = approach(rig.air, if airborne then 1 else 0, 12, dt)
	rig.glide = approach(rig.glide, if gliding then 1 else 0, 8, dt)
	local lastPhase = rig.phase
	if rig.walk > 0.05 then
		rig.phase += dt * (7 + speed * 0.45)
	end
	local walk, air, glide, phase = rig.walk, rig.air, rig.glide, rig.phase
	local s = math.sin(phase)
	local idle = math.max(0, 1 - walk) * (1 - air)
	local flapAir = air * (1 - glide)

	-- Footsteps: a little dust puff each time a foot plants.
	if walk > 0.6 and math.floor(lastPhase / math.pi) ~= math.floor(phase / math.pi) and t - rig.lastStep > 0.12 then
		rig.lastStep = t
		local side = if math.floor(phase / math.pi) % 2 == 0 then -1 else 1
		local foot = rig.root.CFrame * CFrame.new(side * 0.6, -(rig.humanoid.HipHeight + 1), 0)
		puff(foot.Position, 2)
	end

	local shoot = pulse(t, rig.shootStart, 0.4)
	local land = pulse(t, rig.landStart, 0.28) * rig.landPower
	local ruffle = pulse(t, rig.ruffleStart, 0.7)

	-- Body: bounce with a squash at each footfall, waddle roll, lean into the run, pitch
	-- forward to glide, squat to shoot, and breathe when idle.
	local stepBounce = math.abs(s)
	local bodyY = stepBounce * 0.28 * walk
		- (1 - stepBounce) * 0.06 * walk
		+ math.sin(t * 2.2 + rig.seed) * 0.04 * idle
		- 0.35 * land
		- 0.22 * shoot
	local pitch = -0.14 * math.min(walk, 1) + 0.12 * flapAir - 0.35 * glide - 0.2 * shoot - 0.15 * land
	setT(rig, "Root", CFrame.new(0, bodyY, 0) * CFrame.Angles(pitch, math.sin(phase) * 0.05 * walk, s * 0.15 * walk))

	-- Legs: step with a knee-lift (lifted leg rides up), tuck when jumping, trail back when
	-- gliding, brace when landing.
	local lift = 0.18 * walk
	local tuckAngle = -0.7 * flapAir - 0.9 * glide
	setT(rig, "LeftHip", CFrame.new(0, math.max(0, s) * lift, 0) * CFrame.Angles(s * 0.65 * walk + tuckAngle - 0.3 * land, 0, 0.12 * land))
	setT(rig, "RightHip", CFrame.new(0, math.max(0, -s) * lift, 0) * CFrame.Angles(-s * 0.65 * walk + tuckAngle - 0.3 * land, 0, -0.12 * land))

	-- Head: the chicken head-lock. Over each step the head drifts back relative to the body
	-- (holding still in the world), then snaps forward.
	local stepT = (phase * 2 / (2 * math.pi)) % 1
	local lock = if stepT < 0.75 then stepT / 0.75 else 1 - (stepT - 0.75) / 0.25
	local headZ = (lock - 0.5) * 0.5 * math.min(walk, 1)
	local peck = 0
	if idle > 0.5 and t > rig.nextPeck then
		rig.peckStart = t
		rig.nextPeck = t + 3 + math.random() * 5
	end
	local pt = t - rig.peckStart
	if pt < 0.45 then
		peck = math.sin(pt / 0.45 * math.pi)
	end
	local look = math.noise(rig.seed, t * 0.35) * 0.9 * idle
	setT(
		rig,
		"Neck",
		CFrame.new(0, -0.15 * peck - 0.1 * land, headZ - 0.25 * peck + 0.15 * glide)
			* CFrame.Angles(-0.7 * peck + 0.1 * flapAir + 0.3 * glide - 0.2 * shoot, look + 0.6 * shoot, 0.1 * shoot)
	)

	-- Wings: strong flaps going up, wide spread with fluttering tips when gliding, flare when
	-- shooting, a small swing walking, and the odd idle ruffle.
	rig.flapPhase += dt * (if glide > 0.5 then 34 else 22) * math.max(air, 0.2)
	local flap = flapAir * (0.75 + math.sin(rig.flapPhase) * 0.75)
	local spread = glide * (1.25 + math.sin(rig.flapPhase * 1.4) * 0.12)
	local wingOut = flap + spread
		+ math.sin(phase * 2) * 0.12 * walk
		+ math.sin(t * 2 + rig.seed) * 0.03 * idle
		+ 0.7 * shoot
		+ ruffle * (0.5 + math.sin(t * 30) * 0.35)
	local wingSweep = -0.25 * glide + 0.2 * flap
	setT(rig, "LeftWing", CFrame.Angles(wingSweep, 0, -wingOut))
	setT(rig, "RightWing", CFrame.Angles(wingSweep, 0, wingOut))
	if idle > 0.8 and t > rig.nextRuffle then
		rig.ruffleStart = t
		rig.nextRuffle = t + 10 + math.random() * 12
	end
	for _, trail in rig.trails do
		trail.Enabled = glide > 0.5
	end

	-- Tail: wags idle and walking, fans up in the air, flicks up hard as the egg pops out.
	local wag = math.sin(t * 3.2 + rig.seed) * 0.15 * idle + math.sin(phase * 2) * 0.25 * walk
	setT(rig, "Tail", CFrame.Angles(0.25 * air - 0.2 * glide - 0.9 * shoot, wag, wag * 0.3))

	-- Blink (and squint when shooting).
	if t > rig.nextBlink then
		rig.blinkUntil = t + 0.12
		rig.nextBlink = t + 2 + math.random() * 3.5
	end
	local closed = t < rig.blinkUntil or shoot > 0.6
	for _, lid in rig.lids do
		lid.Transparency = if closed then 0 else 1
	end
end

local function step(dt: number)
	local t = os.clock()
	for model, rig in rigs do
		if not model.Parent then
			rigs[model] = nil
		elseif rig.humanoid.Health > 0 then
			animate(rig, dt, t)
		end
	end
end

local function watchPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		task.spawn(register, character)
	end)
	if player.Character then
		task.spawn(register, player.Character)
	end
end

-- Plays the egg-shooting animation on a chicken (called right away for your own shots).
function ChickenAnimator.shoot(model: Model?)
	local rig = model and rigs[model]
	if rig then
		rig.shootStart = os.clock()
	end
end

function ChickenAnimator.start()
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	Remotes.EggShot.OnClientEvent:Connect(function(userId: number)
		-- Your own shots already animated locally.
		if userId == Players.LocalPlayer.UserId then
			return
		end
		local shooter = Players:GetPlayerByUserId(userId)
		ChickenAnimator.shoot(shooter and shooter.Character)
	end)
	RunService.PreSimulation:Connect(step)
end

return ChickenAnimator
