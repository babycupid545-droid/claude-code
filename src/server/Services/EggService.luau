--!strict
-- Butt eggs. The client only sends an aim direction; the server launches the egg from the
-- chicken's server-side position, flies it, and decides who gets knocked back.
-- Power-ups (PowerupService) can make an egg mega or special: sticky, bouncy (ricochets once
-- off the ground or a car towards the nearest chicken), explosive or golden.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local EggPhysics = require(Shared.EggPhysics)
local Layout = require(Shared.Layout)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local TrafficService = require(script.Parent.TrafficService)

local EggService = {}

export type Rules = {
	canShoot: (Player) -> boolean,
	canHit: (shooter: Player, target: Player) -> boolean,
	onHit: ((shooter: Player, target: Player) -> ())?,
}

-- Set by PowerupService: what the next egg a chicken fires is loaded with, and what a special
-- egg does to the chicken it hits (on top of the knockback).
export type PowerupHooks = {
	load: (Player) -> (boolean, string?), -- (mega, special id)
	onHit: (shooter: Player, target: Player, special: string) -> (),
}

type Egg = {
	id: string,
	shooter: Player,
	origin: Vector3,
	velocity: Vector3,
	t: number,
	params: RaycastParams,
	hitEffect: string,
	skin: string,
	mega: boolean,
	special: string?,
	bounced: boolean,
	radius: number,
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
local powerups: PowerupHooks? = nil

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

	local mega, special = false, nil
	if powerups then
		mega, special = powerups.load(player)
	end
	local egg: Egg = {
		id = `{player.UserId}:{math.floor(localId) % 1e6}`,
		shooter = player,
		origin = EggPhysics.buttOrigin(root),
		velocity = direction.Unit * Config.Egg.Speed,
		t = 0,
		params = params,
		hitEffect = DataService.equipped(player, "HitEffect"),
		skin = DataService.equipped(player, "EggSkin"),
		mega = mega,
		special = special,
		bounced = false,
		radius = Config.Egg.Radius * (if mega then Config.Powerups.MegaEggScale else 1),
	}
	table.insert(eggs, egg)

	Remotes.EggShot:FireAllClients(player.UserId)
	local firedAt = workspace:GetServerTimeNow()
	for _, other in Players:GetPlayers() do
		if other ~= player then
			Remotes.EggFired:FireClient(other, egg.id, player.UserId, egg.origin, egg.velocity, firedAt, egg.skin, mega, special or "")
		end
	end
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

local function canHit(egg: Egg, target: Player): boolean
	return target ~= egg.shooter and rules.canHit(egg.shooter, target)
end

local function push(egg: Egg, target: Player, knockback: Vector3)
	local mult = knockbackMult * (if egg.mega then Config.Powerups.MegaEggKnockback else 1)
	-- The target's client owns its character physics, so it applies the push itself.
	Remotes.Knockback:FireClient(target, knockback * mult)
	if rules.onHit then
		rules.onHit(egg.shooter, target)
	end
end

-- Explosive eggs shove every chicken within the blast radius away from the impact.
local function explode(egg: Egg, position: Vector3)
	local P = Config.Powerups
	for _, target in Players:GetPlayers() do
		local root = rootOf(target)
		if root and canHit(egg, target) then
			local offset = root.Position - position
			local dist = offset.Magnitude
			if dist < P.ExplosiveRadius then
				local flat = offset * Vector3.new(1, 0, 1)
				local away = if flat.Magnitude > 0.1 then flat.Unit else EggPhysics.velocityAt(egg.velocity, egg.t) * Vector3.new(1, 0, 1)
				away = if away.Magnitude > 1e-3 then away.Unit else Vector3.xAxis
				local strength = P.ExplosiveKnockback * (1 - 0.5 * dist / P.ExplosiveRadius)
				push(egg, target, away * strength + Vector3.new(0, Config.Egg.KnockbackUp * 1.3, 0))
			end
		end
	end
end

-- Bouncy eggs ricochet once: towards the nearest chicken they can hit, else off the surface.
-- Clients see the old egg splat and a new one fly off.
local function bounce(egg: Egg, position: Vector3, normal: Vector3)
	local from = position + normal * (egg.radius + 0.2)
	local best: BasePart? = nil
	local bestDist = Config.Powerups.BouncyRange
	for _, target in Players:GetPlayers() do
		local root = rootOf(target)
		if root and canHit(egg, target) then
			local dist = (root.Position - from).Magnitude
			if dist < bestDist then
				best, bestDist = root, dist
			end
		end
	end
	local velocity
	if best then
		-- Lob it so gravity drops it right onto them.
		local delta = best.Position - from
		local t = math.max(0.08, delta.Magnitude / (Config.Egg.Speed * 0.8))
		velocity = delta / t + Vector3.new(0, 0.5 * Config.Egg.Gravity * t, 0)
	else
		local v = EggPhysics.velocityAt(egg.velocity, egg.t)
		velocity = (v - 2 * v:Dot(normal) * normal) * 0.7
	end
	Remotes.EggHit:FireAllClients(egg.id, position, egg.hitEffect, "Bounce")
	egg.id ..= "b"
	egg.origin = from
	egg.velocity = velocity
	egg.t = 0
	egg.bounced = true
	Remotes.EggFired:FireAllClients(
		egg.id,
		egg.shooter.UserId,
		egg.origin,
		egg.velocity,
		workspace:GetServerTimeNow(),
		egg.skin,
		egg.mega,
		egg.special or ""
	)
end

-- An egg hit something (`hit` is nil for cars, which only exist as math on the server).
-- Returns false if the egg bounced and keeps flying.
local function impact(egg: Egg, position: Vector3, normal: Vector3, hit: Instance?): boolean
	local model = hit and hit:FindFirstAncestorOfClass("Model")
	local target = model and Players:GetPlayerFromCharacter(model)
	local special = egg.special
	if special == "Bouncy" and not egg.bounced and not target then
		bounce(egg, position, normal)
		return false
	end
	if special == "Explosive" then
		explode(egg, position)
	elseif target and canHit(egg, target) then
		local flat = EggPhysics.velocityAt(egg.velocity, egg.t) * Vector3.new(1, 0, 1)
		local dir = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.zero
		push(egg, target, dir * Config.Egg.KnockbackHorizontal + Vector3.new(0, Config.Egg.KnockbackUp, 0))
		local hooks = powerups
		if special and hooks then
			hooks.onHit(egg.shooter, target, special)
		end
	end
	Remotes.EggHit:FireAllClients(egg.id, position, egg.hitEffect, special or "")
	return true
end

local function step(dt: number)
	local i = 1
	while i <= #eggs do
		local egg = eggs[i]
		local t1 = math.min(egg.t + dt, Config.Egg.Lifetime)
		local position, result = EggPhysics.step(egg.origin, egg.velocity, egg.t, t1, egg.params, egg.radius)
		egg.t = t1
		local done = egg.t >= Config.Egg.Lifetime
		if result then
			done = impact(egg, result.Position, result.Normal, result.Instance)
		elseif egg.special == "Bouncy" and not egg.bounced then
			local car = TrafficService.carAt(position, egg.radius)
			if car then
				local lane = Layout.lanes[car.lane]
				local carZ = car.z or (if lane then lane.z else position.Z)
				local normal = Vector3.new(0, 1, if position.Z >= carZ then 1 else -1).Unit
				done = impact(egg, position, normal, nil)
			end
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

function EggService.setPowerups(hooks: PowerupHooks?)
	powerups = hooks
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
