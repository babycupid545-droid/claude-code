--!strict
-- Butt eggs. The client only sends an aim direction; the server launches the egg from the
-- chicken's server-side position, flies it, and decides who gets knocked back.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local EggPhysics = require(Shared.EggPhysics)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)

local EggService = {}

export type Rules = {
	canShoot: (Player) -> boolean,
	canHit: (shooter: Player, target: Player) -> boolean,
	onHit: ((shooter: Player, target: Player) -> ())?,
}

type Egg = {
	id: string,
	shooter: Player,
	origin: Vector3,
	velocity: Vector3,
	t: number,
	params: RaycastParams,
	hitEffect: string,
}

local rules: Rules = {
	canShoot = function()
		return false
	end,
	canHit = function()
		return false
	end,
}
local eggs: { Egg } = {}
local lastShot: { [Player]: number } = {}
local knockbackMult = 1

local function isFiniteVector(v: Vector3): boolean
	return v.X == v.X and v.Y == v.Y and v.Z == v.Z and v.Magnitude < math.huge
end

local function onShoot(player: Player, direction: unknown, localId: unknown)
	if typeof(direction) ~= "Vector3" or type(localId) ~= "number" then
		return
	end
	if not isFiniteVector(direction) or direction.Magnitude < 1e-3 then
		return
	end
	if not rules.canShoot(player) then
		return
	end
	local now = os.clock()
	-- A little slack for network jitter.
	if now - (lastShot[player] or 0) < Config.Egg.Cooldown * 0.8 then
		return
	end
	lastShot[player] = now

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not character or not root then
		return
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { character }
	local lobby = workspace:FindFirstChild("Lobby")
	if lobby then
		table.insert(exclude, lobby)
	end
	params.FilterDescendantsInstances = exclude

	local egg: Egg = {
		id = `{player.UserId}:{math.floor(localId) % 1e6}`,
		shooter = player,
		origin = EggPhysics.buttOrigin(root),
		velocity = direction.Unit * Config.Egg.Speed,
		t = 0,
		params = params,
		hitEffect = DataService.equipped(player, "HitEffect"),
	}
	table.insert(eggs, egg)

	Remotes.EggShot:FireAllClients(player.UserId)
	local firedAt = workspace:GetServerTimeNow()
	local eggSkin = DataService.equipped(player, "EggSkin")
	for _, other in Players:GetPlayers() do
		if other ~= player then
			Remotes.EggFired:FireClient(other, egg.id, player.UserId, egg.origin, egg.velocity, firedAt, eggSkin)
		end
	end
end

local function onEggHit(egg: Egg, result: RaycastResult)
	local model = result.Instance:FindFirstAncestorOfClass("Model")
	local target = model and Players:GetPlayerFromCharacter(model)
	if target and target ~= egg.shooter and rules.canHit(egg.shooter, target) then
		local flat = EggPhysics.velocityAt(egg.velocity, egg.t) * Vector3.new(1, 0, 1)
		local push = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.zero
		local knockback = (push * Config.Egg.KnockbackHorizontal + Vector3.new(0, Config.Egg.KnockbackUp, 0)) * knockbackMult
		-- The target's client owns its character physics, so it applies the push itself.
		Remotes.Knockback:FireClient(target, knockback)
		if rules.onHit then
			rules.onHit(egg.shooter, target)
		end
	end
	Remotes.EggHit:FireAllClients(egg.id, result.Position, egg.hitEffect)
end

local function step(dt: number)
	local i = 1
	while i <= #eggs do
		local egg = eggs[i]
		local t1 = math.min(egg.t + dt, Config.Egg.Lifetime)
		local _, result = EggPhysics.step(egg.origin, egg.velocity, egg.t, t1, egg.params)
		egg.t = t1
		local done = egg.t >= Config.Egg.Lifetime
		if result then
			onEggHit(egg, result)
			done = true
		end
		if done then
			eggs[i] = eggs[#eggs]
			eggs[#eggs] = nil
		else
			i += 1
		end
	end
end

function EggService.setRules(newRules: Rules)
	rules = newRules
end

-- Big Eggs event.
function EggService.setKnockbackMult(mult: number)
	knockbackMult = mult
end

function EggService.clear()
	table.clear(eggs)
end

function EggService.init()
	Remotes.ShootEgg.OnServerEvent:Connect(onShoot)
	RunService.Heartbeat:Connect(step)
	Players.PlayerRemoving:Connect(function(player)
		lastShot[player] = nil
	end)
end

return EggService
