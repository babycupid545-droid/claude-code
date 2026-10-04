--!strict
-- Shooting butt eggs and drawing everyone's eggs. Your own egg appears instantly; the
-- server decides what it hits and tells everyone where it splatted.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local EggPhysics = require(Shared.EggPhysics)
local Remotes = require(Shared.Remotes)
local RoundState = require(Shared.RoundState)

local ClientData = require(script.Parent.Parent.ClientData)
local Effects = require(script.Parent.Parent.Effects)
local Sfx = require(script.Parent.Parent.Sfx)
local ChickenAnimator = require(script.Parent.ChickenAnimator)

local EggController = {}

local ACTION = "ShootEgg"
local player = Players.LocalPlayer

type VisualEgg = {
	model: Instance,
	origin: Vector3,
	velocity: Vector3,
	t: number,
	params: RaycastParams,
}

local eggs: { [string]: VisualEgg } = {}
local folder: Folder
local lastShot = 0
local nextLocalId = 0
local bound = false

local function placeEgg(egg: VisualEgg, position: Vector3)
	local v = EggPhysics.velocityAt(egg.velocity, egg.t)
	local cf = if v.Magnitude > 1e-3 then CFrame.lookAt(position, position + v) else CFrame.new(position)
	local model = egg.model
	if model:IsA("Model") then
		model:PivotTo(cf)
	elseif model:IsA("BasePart") then
		model.CFrame = cf
	end
end

local function spawnVisual(id: string, shooter: Model?, origin: Vector3, velocity: Vector3, startT: number, skin: string?)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { folder }
	if shooter then
		table.insert(exclude, shooter)
	end
	local traffic = workspace:FindFirstChild("Traffic")
	if traffic then
		table.insert(exclude, traffic)
	end
	params.FilterDescendantsInstances = exclude

	local egg: VisualEgg = {
		model = Effects.makeEgg(skin),
		origin = origin,
		velocity = velocity,
		t = math.max(0, startT),
		params = params,
	}
	egg.model.Parent = folder
	placeEgg(egg, EggPhysics.position(origin, velocity, egg.t))
	eggs[id] = egg
end

local function removeEgg(id: string)
	local egg = eggs[id]
	if egg then
		egg.model:Destroy()
		eggs[id] = nil
	end
end

local function aimDirection(origin: Vector3, character: Model): Vector3
	local camera = workspace.CurrentCamera
	local screen: Vector2
	if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		-- Phones aim where the camera looks.
		screen = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y * 0.4)
	else
		screen = UserInputService:GetMouseLocation()
	end
	local ray = camera:ViewportPointToRay(screen.X, screen.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, folder }
	local result = workspace:Raycast(ray.Origin, ray.Direction * 600, params)
	local target = if result then result.Position else ray.Origin + ray.Direction * 600
	local dir = target - origin
	if dir.Magnitude < 1e-3 then
		return camera.CFrame.LookVector
	end
	return dir.Unit
end

local function shoot()
	local now = os.clock()
	if now - lastShot < Config.Egg.Cooldown then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not character or not root then
		return
	end
	lastShot = now
	nextLocalId += 1
	local origin = EggPhysics.buttOrigin(root)
	local direction = aimDirection(origin, character)
	spawnVisual(
		`{player.UserId}:{nextLocalId}`,
		character,
		origin,
		direction * Config.Egg.Speed,
		0,
		ClientData.equipped("EggSkin")
	)
	Remotes.ShootEgg:FireServer(direction, nextLocalId)
	Sfx.play("EggShoot", { pitchJitter = 0.12 })
	ChickenAnimator.shoot(player.Character)
end

local function onAction(_: string, state: Enum.UserInputState, _input: InputObject): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		shoot()
	end
	return Enum.ContextActionResult.Pass
end

local function canShoot(): boolean
	return player:GetAttribute("Alive") == true and RoundState:GetAttribute("State") == "InRound"
end

local function refreshBinding()
	local want = canShoot()
	if want == bound then
		return
	end
	bound = want
	if want then
		ContextActionService:BindAction(
			ACTION,
			onAction,
			true,
			Enum.UserInputType.MouseButton1,
			Enum.KeyCode.ButtonR2,
			Enum.KeyCode.E
		)
		ContextActionService:SetTitle(ACTION, "🥚")
		ContextActionService:SetPosition(ACTION, UDim2.new(1, -150, 1, -150))
	else
		ContextActionService:UnbindAction(ACTION)
	end
end

local function step(dt: number)
	for id, egg in eggs do
		local t0 = egg.t
		local t1 = math.min(t0 + dt, Config.Egg.Lifetime)
		egg.t = t1
		local position, result = EggPhysics.step(egg.origin, egg.velocity, t0, t1, egg.params)
		if result or t1 >= Config.Egg.Lifetime then
			removeEgg(id)
		else
			placeEgg(egg, position)
		end
	end
end

function EggController.start()
	folder = Instance.new("Folder")
	folder.Name = "Eggs"
	folder.Parent = workspace

	Remotes.EggFired.OnClientEvent:Connect(
		function(id: string, shooterUserId: number, origin: Vector3, velocity: Vector3, firedAt: number, skin: string)
			local shooter = Players:GetPlayerByUserId(shooterUserId)
			local elapsed = workspace:GetServerTimeNow() - firedAt
			spawnVisual(id, shooter and shooter.Character, origin, velocity, elapsed, skin)
			Sfx.playAt("EggShoot", origin, { pitchJitter = 0.12 })
		end
	)
	Remotes.EggHit.OnClientEvent:Connect(function(id: string, position: Vector3, hitEffect: string)
		removeEgg(id)
		Effects.eggHit(position, hitEffect)
	end)

	player:GetAttributeChangedSignal("Alive"):Connect(refreshBinding)
	RoundState:GetAttributeChangedSignal("State"):Connect(refreshBinding)
	refreshBinding()

	RunService.RenderStepped:Connect(step)
end

return EggController
