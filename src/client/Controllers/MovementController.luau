--!strict
-- Chicken movement that has to feel instant, so it runs on the client (which owns its
-- character's physics): gliding, egg knockback, and being flung by a car.
-- Power-ups: Extra Feather doubles (and refills) glide stamina; a sticky egg grounds you.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Assets = require(Shared.Assets)
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local RoundState = require(Shared.RoundState)

local CameraFx = require(script.Parent.Parent.CameraFx)
local Effects = require(script.Parent.Parent.Effects)
local Sfx = require(script.Parent.Parent.Sfx)

local MovementController = {}

local C = Config.Chicken
local player = Players.LocalPlayer

local humanoid: Humanoid? = nil
local root: BasePart? = nil
local stamina = C.GlideStamina
local gliding = false
local glideTrack: AnimationTrack? = nil
local windLoop: Sound? = nil
local activePush: LinearVelocity? = nil
-- Coyote time: a jump pressed just after walking off an edge still counts.
local COYOTE_TIME = 0.12
local lastGrounded = 0
local jumpedSinceGrounded = false

local function maxStamina(): number
	local feather = player:GetAttribute("Powerup") == "Feather"
	return C.GlideStamina * (if feather then Config.Powerups.FeatherGlideMult else 1)
end

local function isStuck(): boolean
	local stuck = player:GetAttribute("StuckUntil")
	return type(stuck) == "number" and stuck > workspace:GetServerTimeNow()
end

local function jumpHeld(h: Humanoid): boolean
	return h.Jump
		or UserInputService:IsKeyDown(Enum.KeyCode.Space)
		or UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonA)
end

local function setGliding(on: boolean)
	if on == gliding then
		return
	end
	gliding = on
	-- Wind while gliding, plus a slightly wider view for a sense of speed.
	if on then
		Sfx.play("Glide", { pitchJitter = 0.1 })
		windLoop = Sfx.loop("Wind", { volume = 0.8 })
		CameraFx.setFovTarget(8)
	else
		if windLoop then
			windLoop:Destroy()
			windLoop = nil
		end
		CameraFx.setFovTarget(0)
	end
	if glideTrack then
		if on then
			glideTrack:Play(0.15)
		else
			glideTrack:Stop(0.2)
		end
	end
end

local function onCharacter(character: Model)
	local h = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local r = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not h or not r then
		return
	end
	-- Respawning mid-glide (e.g. sent back to the lobby) must not leave the wind looping or
	-- the camera zoomed out.
	setGliding(false)
	humanoid, root = h, r
	stamina = C.GlideStamina
	glideTrack = nil
	lastGrounded = 0
	jumpedSinceGrounded = false
	h.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Jumping then
			jumpedSinceGrounded = true
			Sfx.play("Jump", { pitchJitter = 0.08 })
		elseif new == Enum.HumanoidStateType.Landed then
			Sfx.play("Land", { pitchJitter = 0.1 })
		end
	end)
	local animation = Assets.find("Animations", "Glide")
	local animator = h:FindFirstChildOfClass("Animator")
	if animation and animation:IsA("Animation") and animator then
		glideTrack = animator:LoadAnimation(animation)
	end
end

local function step(dt: number)
	local h, r = humanoid, root
	if not h or not r or h.Health <= 0 or not r.Parent then
		setGliding(false)
		return
	end
	local max = maxStamina()
	stamina = math.min(stamina, max)
	local grounded = h.FloorMaterial ~= Enum.Material.Air
	if grounded then
		lastGrounded = os.clock()
		if h:GetState() ~= Enum.HumanoidStateType.Jumping then
			jumpedSinceGrounded = false
		end
		stamina = math.min(max, stamina + dt * C.GlideRecharge)
		setGliding(false)
		return
	end

	local velocity = r.AssemblyLinearVelocity
	if velocity.Y < 0 and stamina > 0 and jumpHeld(h) and not isStuck() then
		setGliding(true)
		-- Feather Frenzy event: unlimited glide.
		if RoundState:GetAttribute("Event") ~= "FeatherFrenzy" then
			stamina = math.max(0, stamina - dt)
		end
		local move = h.MoveDirection
		local horizontal = if move.Magnitude > 0.1
			then move.Unit * C.GlideHorizontalSpeed
			else Vector3.new(velocity.X, 0, velocity.Z)
		r.AssemblyLinearVelocity = Vector3.new(horizontal.X, math.max(velocity.Y, -C.GlideFallSpeed), horizontal.Z)
	else
		setGliding(false)
	end
end

local function onJumpRequest()
	local h, r = humanoid, root
	if not h or not r or h.Health <= 0 or jumpedSinceGrounded then
		return
	end
	if h.FloorMaterial ~= Enum.Material.Air or os.clock() - lastGrounded > COYOTE_TIME then
		return
	end
	if h:GetState() ~= Enum.HumanoidStateType.Freefall then
		return
	end
	jumpedSinceGrounded = true
	local v = r.AssemblyLinearVelocity
	r.AssemblyLinearVelocity = Vector3.new(v.X, h.JumpPower, v.Z)
	h:ChangeState(Enum.HumanoidStateType.Jumping)
end

local function applyKnockback(velocity: Vector3)
	local r = root
	if not r or typeof(velocity) ~= "Vector3" then
		return
	end
	-- Two pushes at once (egg + sprinkler) would fight each other with infinite force.
	if activePush then
		activePush:Destroy()
		activePush = nil
	end
	Sfx.play("Boing", { pitchJitter = 0.1 })
	Sfx.play("EggHit")
	CameraFx.shake(0.45)
	-- A LinearVelocity briefly overrides the humanoid's own movement so the push lands.
	local attachment = Instance.new("Attachment")
	attachment.Parent = r
	local push = Instance.new("LinearVelocity")
	push.Attachment0 = attachment
	push.MaxForce = math.huge
	push.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	push.VectorVelocity = velocity
	push.RelativeTo = Enum.ActuatorRelativeTo.World
	push.Destroying:Once(function()
		attachment:Destroy()
	end)
	push.Parent = r
	activePush = push
	task.delay(Config.Egg.KnockbackDuration, function()
		if activePush ~= push then
			-- A newer push replaced this one (and destroyed it).
			return
		end
		activePush = nil
		push:Destroy()
		if r.Parent then
			r.AssemblyLinearVelocity = velocity * 0.5
		end
	end)
end

local function onSplat(userId: number, position: Vector3, fling: Vector3)
	Effects.feathers(position)
	if userId ~= player.UserId then
		return
	end
	local character = player.Character
	if not character then
		return
	end
	CameraFx.shake(0.9)
	-- Our client still owns the ragdoll for a moment, so send it flying.
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			d.AssemblyLinearVelocity = fling + Vector3.new(math.random(-20, 20), math.random(0, 20), math.random(-20, 20))
			d.AssemblyAngularVelocity = Vector3.new(math.random(-15, 15), math.random(-15, 15), math.random(-15, 15))
		end
	end
end

-- 0..1, for the stamina bar.
function MovementController.getStamina(): number
	return stamina / maxStamina()
end

function MovementController.isGliding(): boolean
	return gliding
end

function MovementController.start()
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	RunService.PreSimulation:Connect(step)
	UserInputService.JumpRequest:Connect(onJumpRequest)
	Remotes.Knockback.OnClientEvent:Connect(applyKnockback)
	Remotes.ChickenSplat.OnClientEvent:Connect(onSplat)
	-- Extra Feather: a full (double) tank right away.
	player:GetAttributeChangedSignal("Powerup"):Connect(function()
		if player:GetAttribute("Powerup") == "Feather" then
			stamina = maxStamina()
		end
	end)
end

return MovementController
