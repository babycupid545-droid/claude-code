--!strict
-- Bounty on the leader. During a round, the chicken with the most knockouts (at least
-- Config.Bounty.MinKOs, counted in the "RoundKOs" attribute) wears a crown, and whoever
-- knocks it out earns bonus golden eggs. Clients draw the crown from the "Bounty" player
-- attribute (the reward on that chicken's head).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local PowerupLogic = require(Shared.PowerupLogic)
local Remotes = require(Shared.Remotes)

local Services = script.Parent
local ChickenService = require(Services.ChickenService)
local DataService = require(Services.DataService)

local BountyService = {}

export type Context = {
	getChickens: () -> { Player },
	isAlive: (Player) -> boolean,
}

local context: Context? = nil
local leader: Player? = nil
-- When each chicken reached its current knockout count (a counter, earlier wins ties).
local lastKOs: { [Player]: number } = {}
local reachedAt: { [Player]: number } = {}
local order = 0

local function feed(text: string)
	Remotes.Feed:FireAllClients(text, "crown")
end

local function knockouts(player: Player): number
	local kos = player:GetAttribute("RoundKOs")
	return if type(kos) == "number" then kos else 0
end

local function reward(player: Player): number
	local B = Config.Bounty
	return PowerupLogic.bountyReward(knockouts(player), B.Base, B.PerKO)
end

local function fx(name: string, player: Player, amount: number)
	local root = ChickenService.getRoot(player)
	if root then
		Remotes.PowerupFx:FireAllClients(name, root.Position, player.UserId, tostring(amount))
	end
end

local function setLeader(new: Player?)
	local old = leader
	if old and old ~= new then
		old:SetAttribute("Bounty", nil)
	end
	leader = new
	if new then
		new:SetAttribute("Bounty", reward(new))
	end
end

-- Re-picks the leader among the chickens still in the round and announces any change.
local function refresh()
	local ctx = context
	if not ctx then
		return
	end
	local candidates: { PowerupLogic.Candidate<Player> } = {}
	for _, player in ctx.getChickens() do
		local kos = knockouts(player)
		if kos ~= lastKOs[player] then
			lastKOs[player] = kos
			order += 1
			reachedAt[player] = order
		end
		table.insert(candidates, { id = player, kos = kos, at = reachedAt[player] or 0 })
	end
	local old = if leader and ctx.isAlive(leader) then leader else nil
	local new = PowerupLogic.pickLeader(old, candidates, Config.Bounty.MinKOs)
	if new == leader then
		-- Same leader with another knockout: the price goes up.
		if new and new:GetAttribute("Bounty") ~= reward(new) then
			new:SetAttribute("Bounty", reward(new))
		end
		return
	end
	setLeader(new)
	if new then
		local amount = reward(new)
		if old then
			feed(`{new.DisplayName} stole the crown from {old.DisplayName}! Bounty: {amount} golden eggs`)
		else
			feed(`{new.DisplayName} is the top chicken! Knock them out for {amount} golden eggs`)
		end
		fx("Bounty", new, amount)
	end
end

-- Called by RoundService for every chicken that leaves the round, after knockout credit is
-- given (`killer` is the chicken credited with it, if any).
function BountyService.onEliminated(victim: Player, killer: Player?)
	if not context then
		return
	end
	if victim == leader then
		local amount = reward(victim)
		setLeader(nil)
		if killer and killer.Parent then
			DataService.reward(killer, amount, "for the bounty!")
			feed(`BOUNTY CLAIMED! {killer.DisplayName} took down {victim.DisplayName} for {amount} golden eggs!`)
			fx("BountyClaimed", killer, amount)
		else
			feed(`The bounty on {victim.DisplayName} went unclaimed!`)
		end
	end
	refresh()
end

function BountyService.start(ctx: Context)
	BountyService.stop()
	context = ctx
end

function BountyService.stop()
	context = nil
	setLeader(nil)
	-- Belt and braces: no crown survives the round.
	for _, player in Players:GetPlayers() do
		player:SetAttribute("Bounty", nil)
	end
	table.clear(lastKOs)
	table.clear(reachedAt)
end

return BountyService
