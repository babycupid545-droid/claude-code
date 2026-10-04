--!strict
-- Animates every chicken in code, on every client, from how it's moving:
--   * waddle: body bobs and rocks side to side, legs step
--   * the classic chicken head-bob while walking; looking around and pecking when idle
--   * wings flap when jumping, flutter when gliding
--   * tail wags; eyes blink
-- Joint motion (Motor6D.Transform) is local to each client, so every client runs this for
-- all chickens. No animation uploads needed.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local ChickenAnimator = {}

type Rig = {
	model: Model,
	root: BasePart,
	humanoid: Humanoid,
	motors: { [string]: Motor6D },
	lids: { BasePart },
	phase: number,
	walk: number,
	air: number,
	glide: number,
	seed: number,
	nextBlink: number,
	blinkUntil: number,
	nextPeck: number,
	peckStart: number,
}

local rigs: { [Model]: Rig } = {}
local JOINTS = { "Root", "Neck", "LeftWing", "RightWing", "LeftHip", "RightHip", "Tail" }

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
		phase = 0,
		walk = 0,
		air = 0,
		glide = 0,
		seed = math.random() * 100,
		nextBlink = now + math.random() * 3,
		blinkUntil = 0,
		nextPeck = now + 3 + math.random() * 4,
		peckStart = -10,
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

local function animate(rig: Rig, dt: number, t: number)
	local v = rig.root.AssemblyLinearVelocity
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	local state = rig.humanoid:GetState()
	local airborne = state == Enum.HumanoidStateType.Freefall
		or state == Enum.HumanoidStateType.Jumping
		or math.abs(v.Y) > 6
	local gliding = airborne and v.Y < 0 and v.Y > -(Config.Chicken.GlideFallSpeed + 3)

	rig.walk = approach(rig.walk, if airborne then 0 else math.clamp(speed / Config.Chicken.WalkSpeed, 0, 1.3), 10, dt)
	rig.air = approach(rig.air, if airborne then 1 else 0, 12, dt)
	rig.glide = approach(rig.glide, if gliding then 1 else 0, 10, dt)
	if rig.walk > 0.05 then
		rig.phase += dt * (7 + speed * 0.45)
	end
	local walk, air, glide, phase = rig.walk, rig.air, rig.glide, rig.phase
	local s = math.sin(phase)
	local idle = math.max(0, 1 - walk) * (1 - air)

	-- Body: bounce, waddle roll, lean forward when running, breathe when idle.
	setT(
		rig,
		"Root",
		CFrame.new(0, math.abs(s) * 0.25 * walk + math.sin(t * 2.2 + rig.seed) * 0.04 * idle, 0)
			* CFrame.Angles(-0.12 * math.min(walk, 1) + 0.15 * air, 0, s * 0.14 * walk)
	)

	-- Legs step while walking and tuck up in the air.
	setT(rig, "LeftHip", CFrame.Angles(s * 0.6 * walk - 0.6 * air, 0, 0))
	setT(rig, "RightHip", CFrame.Angles(-s * 0.6 * walk - 0.6 * air, 0, 0))

	-- Head: thrust forward/back twice per stride; idle looking around and pecking.
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
		CFrame.new(0, -0.15 * peck, -math.sin(phase * 2) * 0.22 * walk - 0.25 * peck)
			* CFrame.Angles(-0.7 * peck + 0.1 * air, look, 0)
	)

	-- Wings: big flaps when jumping, a fast spread flutter when gliding, small swing walking.
	local flap = air * (1 - glide) * (0.6 + math.sin(t * 26) * 0.6)
		+ glide * (1.05 + math.sin(t * 40) * 0.18)
		+ math.sin(phase * 2) * 0.1 * walk
		+ math.sin(t * 2 + rig.seed) * 0.03 * idle
	setT(rig, "LeftWing", CFrame.Angles(0, 0, -flap))
	setT(rig, "RightWing", CFrame.Angles(0, 0, flap))

	-- Tail wags.
	local wag = math.sin(t * 3.2 + rig.seed) * 0.15 * idle + math.sin(phase * 2) * 0.22 * walk
	setT(rig, "Tail", CFrame.Angles(0.2 * air, wag, 0))

	-- Blink.
	if t > rig.nextBlink then
		rig.blinkUntil = t + 0.12
		rig.nextBlink = t + 2 + math.random() * 3.5
	end
	local closed = t < rig.blinkUntil
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

function ChickenAnimator.start()
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	RunService.PreSimulation:Connect(step)
end

return ChickenAnimator
