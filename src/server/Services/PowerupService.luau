--!strict
-- Power-ups and special eggs. During a round, glowing pickups pop up now and then, mostly in
-- the lanes (risky to grab, big payoff). Walking into one grants it (checked here by distance,
-- like golden eggs):
--   Speed Boots    faster walking for a few seconds
--   Shield         the next car hit only bumps you aside (see absorbCarHit)
--   Mega Egg       your next egg is huge and knocks much harder (EggService)
--   Extra Feather  glide refilled and doubled for a few seconds (the client owns gliding)
--   Special eggs   load your next few eggs: sticky, bouncy, explosive or golden
-- What a chicken holds lives in player attributes (see Shared/Powerups) so the HUD and the
-- effects on every client can follow it. Everything is cleared when the round stops.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Layout = require(Shared.Layout)
local PowerupLogic = require(Shared.PowerupLogic)
local Powerups = require(Shared.Powerups)
local Remotes = require(Shared.Remotes)
local TrafficSchedule = require(Shared.TrafficSchedule)

local Services = script.Parent
local ChickenService = require(Services.ChickenService)
local DataService = require(Services.DataService)
local EggService = require(Services.EggService)
local ProgressService = require(Services.ProgressService)

local PowerupService = {}

export type Context = {
	getChickens: () -> { Player },
	isAlive: (Player) -> boolean,
}

type Pickup = {
	id: string,
	model: Model,
	position: Vector3,
	expires: number,
}

local ATTRIBUTES = { "Powerup", "PowerupEndsAt", "SpecialEgg", "SpecialAmmo", "StuckUntil" }

local rng = Random.new()
local running = 0 -- bumped to stop the loops of a previous round
local folder: Folder? = nil
local pickups: { Pickup } = {}
-- Bumped whenever a player's power-up or stickiness changes, so old timers do nothing.
local powerToken: { [Player]: number } = {}
local stuckToken: { [Player]: number } = {}
local shieldGraceUntil: { [Player]: number } = {}
-- Players we changed anything on this round, to clean them up at the end.
local touched: { [Player]: boolean } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function feed(text: string, icon: string)
	Remotes.Feed:FireAllClients(text, icon)
end

local function attr(player: Player, name: string): any
	return player:GetAttribute(name)
end

local function isStuck(player: Player): boolean
	local until_ = attr(player, "StuckUntil")
	return type(until_) == "number" and until_ > now()
end

-- Walk speed from what the chicken has going on. The server sets it on the humanoid, which
-- replicates to the owning client.
local function refreshSpeed(player: Player)
	local humanoid = ChickenService.getHumanoid(player)
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local P = Config.Powerups
	local speed = Config.Chicken.WalkSpeed
	if attr(player, "Powerup") == "Speed" then
		speed *= P.SpeedMult
	end
	if isStuck(player) then
		speed *= P.StickySlow
	end
	humanoid.WalkSpeed = speed
end

-- Power-ups ------------------------------------------------------------------------------------

local function clearPower(player: Player)
	powerToken[player] = (powerToken[player] or 0) + 1
	local had = attr(player, "Powerup")
	player:SetAttribute("Powerup", nil)
	player:SetAttribute("PowerupEndsAt", nil)
	if had == "Speed" then
		refreshSpeed(player)
	end
end

local function grantPower(player: Player, id: string)
	clearPower(player)
	touched[player] = true
	local P = Config.Powerups
	local duration = if id == "Speed" then P.SpeedDuration elseif id == "Feather" then P.FeatherDuration else 0
	player:SetAttribute("Powerup", id)
	player:SetAttribute("PowerupEndsAt", if duration > 0 then now() + duration else 0)
	refreshSpeed(player)
	if duration > 0 then
		local token = powerToken[player]
		task.delay(duration, function()
			if powerToken[player] == token and player.Parent then
				clearPower(player)
			end
		end)
	end
end

local function grantEggs(player: Player, id: string)
	touched[player] = true
	player:SetAttribute("SpecialEgg", id)
	player:SetAttribute("SpecialAmmo", Config.Powerups.SpecialAmmo)
end

local function clearEggs(player: Player)
	player:SetAttribute("SpecialEgg", nil)
	player:SetAttribute("SpecialAmmo", nil)
end

local function unstick(player: Player)
	stuckToken[player] = (stuckToken[player] or 0) + 1
	player:SetAttribute("StuckUntil", nil)
	refreshSpeed(player)
end

-- Sticky egg hit: slowed and grounded (no gliding) for a few seconds.
local function stick(player: Player)
	local duration = Config.Powerups.StickyDuration
	touched[player] = true
	stuckToken[player] = (stuckToken[player] or 0) + 1
	local token = stuckToken[player]
	player:SetAttribute("StuckUntil", now() + duration)
	refreshSpeed(player)
	task.delay(duration, function()
		if stuckToken[player] == token and player.Parent then
			unstick(player)
		end
	end)
end

-- Golden egg hit: steal a few golden eggs (never more than the target has).
local function steal(shooter: Player, target: Player)
	local data = DataService.get(target)
	if not data or not DataService.get(shooter) then
		return
	end
	local amount = math.min(Config.Powerups.GoldenSteal, math.max(0, math.floor(data.Coins)))
	if amount <= 0 then
		return
	end
	local root = ChickenService.getRoot(target)
	if root then
		Remotes.PowerupFx:FireAllClients("Steal", root.Position, shooter.UserId, tostring(amount))
	end
	DataService.addCoins(target, -amount)
	DataService.addCoins(shooter, amount)
	Remotes.Notify:FireClient(shooter, `+{amount} eggs stolen from {target.DisplayName}!`, "coin", amount)
	Remotes.Notify:FireClient(target, `{shooter.DisplayName} stole {amount} of your golden eggs!`, "error", 0)
end

-- Egg hooks (called by EggService) ---------------------------------------------------------------

-- Loads the egg being fired: a held Mega Egg is used up, and special ammo counts down.
local function loadEgg(player: Player): (boolean, string?)
	local mega = attr(player, "Powerup") == "MegaEgg"
	if mega then
		clearPower(player)
	end
	local special = attr(player, "SpecialEgg")
	local ammo = attr(player, "SpecialAmmo")
	if type(special) ~= "string" or not Powerups.get(special) or type(ammo) ~= "number" or ammo <= 0 then
		return mega, nil
	end
	if ammo <= 1 then
		clearEggs(player)
	else
		player:SetAttribute("SpecialAmmo", ammo - 1)
	end
	return mega, special
end

local function onSpecialHit(shooter: Player, target: Player, special: string)
	if special == "Sticky" then
		stick(target)
	elseif special == "Golden" then
		steal(shooter, target)
	end
end

-- Pickups -----------------------------------------------------------------------------------------

local function buildPickup(def: Powerups.Def, position: Vector3): Model
	local model = Instance.new("Model")
	model.Name = def.id
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:SetAttribute("Powerup", def.id)
	local function ball(name: string, size: number, props: { [string]: any }): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.one * size
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Color = def.color
		p.Position = position
		for k, v in props do
			(p :: any)[k] = v
		end
		p.Parent = model
		return p
	end
	-- Eggs look like eggs; power-ups are glowing orbs in a bubble.
	local core = ball("Core", if def.kind == "Egg" then 1.8 else 1.6, { Material = Enum.Material.Neon })
	if def.kind == "Egg" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Scale = Vector3.new(1, 1.3, 1)
		mesh.Parent = core
	end
	ball("Shell", 3.4, { Material = Enum.Material.ForceField, Transparency = 0.1 })
	local light = Instance.new("PointLight")
	light.Color = def.color
	light.Range = 12
	light.Brightness = 2
	light.Parent = core
	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = def.color
	sparkles.Parent = core
	model.PrimaryPart = core
	-- WorldAnimator bobs and spins it on the clients; PowerupFx adds the icon and a ground ring.
	model:AddTag("Bob")
	model:SetAttribute("BobSpin", true)
	return model
end

local function removePickup(index: number)
	local pickup = table.remove(pickups, index)
	if pickup then
		pickup.model:Destroy()
	end
end

local function grant(player: Player, def: Powerups.Def, position: Vector3)
	if def.kind == "Power" then
		grantPower(player, def.id)
	else
		grantEggs(player, def.id)
	end
	Remotes.PowerupFx:FireAllClients("Pickup", position, player.UserId, def.id)
	ProgressService.record(player, "PowerUp", 1)
	feed(`{player.DisplayName} grabbed {def.name}!`, def.sprite)
	Remotes.Notify:FireClient(player, `{def.name}! {def.description}`, "unlock", 0)
end

local function spawnPickup(ctx: Context)
	local f = folder
	if not f then
		return
	end
	local P = Config.Powerups
	local pool = if rng:NextNumber() < P.SpecialChance then Powerups.eggs else Powerups.powers
	local def = Powerups.get(pool[rng:NextInteger(1, #pool)])
	if not def then
		return
	end
	local laneZs = {}
	for _, lane in Layout.lanes do
		table.insert(laneZs, lane.z)
	end
	local nearXs = {}
	for _, player in ctx.getChickens() do
		local root = ChickenService.getRoot(player)
		if root then
			table.insert(nearXs, root.Position.X)
		end
	end
	local taken = {}
	for _, pickup in pickups do
		table.insert(taken, { x = pickup.position.X, z = pickup.position.Z })
	end
	local spot = PowerupLogic.pickSpot(function()
		return rng:NextNumber()
	end, {
		laneZs = laneZs,
		laneWidth = Config.Map.LaneWidth,
		medianHalf = Layout.medianHalf,
		halfLength = Layout.halfLength,
		edgeMargin = 15,
		roadChance = P.RoadChance,
		minSpacing = 20,
		nearRange = P.NearRange,
	}, taken, nearXs)
	local position = Vector3.new(spot.x, Config.Map.RoadTopY + 2.2, spot.z)
	local model = buildPickup(def, position)
	model.Parent = f
	table.insert(pickups, { id = def.id, model = model, position = position, expires = os.clock() + P.Lifetime })
end

-- Checks pickups against the chickens (server positions) and expires old ones.
local function checkPickups(ctx: Context)
	local radius = Config.Powerups.PickupRadius
	local i = 1
	while i <= #pickups do
		local pickup = pickups[i]
		local taker: Player? = nil
		for _, player in ctx.getChickens() do
			local root = ChickenService.getRoot(player)
			if root and (root.Position - pickup.position).Magnitude < radius then
				taker = player
				break
			end
		end
		local def = Powerups.get(pickup.id)
		if taker and def then
			grant(taker, def, pickup.position)
			removePickup(i)
		elseif os.clock() > pickup.expires then
			removePickup(i)
		else
			i += 1
		end
	end
end

local function spawnLoop(gen: number, ctx: Context)
	local P = Config.Powerups
	local nextSpawn = os.clock() + P.FirstAt
	while running == gen do
		checkPickups(ctx)
		if os.clock() >= nextSpawn then
			if #pickups < P.MaxOnMap then
				spawnPickup(ctx)
			end
			nextSpawn = os.clock() + rng:NextNumber(P.EveryMin, P.EveryMax)
		end
		task.wait(0.1)
	end
end

-- Shield ------------------------------------------------------------------------------------------

-- Called when a car hits a chicken. Returns true if a shield (or the moment of safety right
-- after one pops) saves it: the chicken is shoved out of the lane instead of eliminated.
function PowerupService.absorbCarHit(player: Player, car: TrafficSchedule.Car): boolean
	if os.clock() < (shieldGraceUntil[player] or 0) then
		return true
	end
	if attr(player, "Powerup") ~= "Shield" then
		return false
	end
	local P = Config.Powerups
	clearPower(player)
	shieldGraceUntil[player] = os.clock() + P.ShieldGrace
	local root = ChickenService.getRoot(player)
	if root then
		-- Out of the lane, away from the car's centre line, and a little along with it.
		local lane = Layout.lanes[car.lane]
		local carZ = car.z or (if lane then lane.z else root.Position.Z)
		local side = if root.Position.Z >= carZ then 1 else -1
		local bump = Vector3.new(car.dir * P.ShieldBump * 0.4, 30, side * P.ShieldBump)
		Remotes.Knockback:FireClient(player, bump)
		Remotes.PowerupFx:FireAllClients("ShieldPop", root.Position, player.UserId, "Shield")
	end
	feed(`{player.DisplayName}'s shield saved them from a car!`, "heart")
	return true
end

-- Round control ------------------------------------------------------------------------------------

-- A chicken left the round: it loses whatever it was holding.
function PowerupService.clearPlayer(player: Player)
	clearPower(player)
	clearEggs(player)
	unstick(player)
	shieldGraceUntil[player] = nil
end

function PowerupService.start(ctx: Context)
	PowerupService.stop()
	local f = Instance.new("Folder")
	f.Name = "Powerups"
	f.Parent = workspace
	folder = f
	task.spawn(spawnLoop, running, ctx)
end

function PowerupService.stop()
	running += 1
	for i = #pickups, 1, -1 do
		removePickup(i)
	end
	if folder then
		folder:Destroy()
		folder = nil
	end
	for player in touched do
		if player.Parent then
			PowerupService.clearPlayer(player)
			for _, name in ATTRIBUTES do
				player:SetAttribute(name, nil)
			end
		end
	end
	table.clear(touched)
	table.clear(shieldGraceUntil)
end

function PowerupService.init()
	EggService.setPowerups({
		load = loadEgg,
		onHit = onSpecialHit,
	})
	Players.PlayerRemoving:Connect(function(player)
		powerToken[player] = nil
		stuckToken[player] = nil
		shieldGraceUntil[player] = nil
		touched[player] = nil
	end)
end

return PowerupService
