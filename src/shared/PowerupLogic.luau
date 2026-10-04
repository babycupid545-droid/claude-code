--!strict
-- Pure helpers for power-ups and the bounty (no Roblox APIs, so tests/Powerups.spec.luau can
-- run them with plain Luau).

local PowerupLogic = {}

export type Area = {
	laneZs: { number }, -- lane centres
	laneWidth: number,
	medianHalf: number,
	halfLength: number, -- roads run from -halfLength to halfLength along X
	edgeMargin: number, -- keep this far from the road ends
	roadChance: number, -- 0..1, the rest land on the median
	minSpacing: number, -- from other pickups
	nearRange: number, -- how far along X from a chicken a pickup may land
}

export type Spot = { x: number, z: number }

-- Picks where a pickup lands: mostly in a lane (near its centre), sometimes on the median,
-- along X close to a random chicken so it's reachable, and away from other pickups.
-- `random` returns a number in [0, 1).
function PowerupLogic.pickSpot(random: () -> number, area: Area, taken: { Spot }, nearXs: { number }): Spot
	local maxX = area.halfLength - area.edgeMargin
	local spot: Spot = { x = 0, z = 0 }
	for _ = 1, 12 do
		local z
		if #area.laneZs > 0 and random() < area.roadChance then
			local lane = area.laneZs[math.floor(random() * #area.laneZs) + 1]
			z = lane + (random() - 0.5) * area.laneWidth * 0.4
		else
			z = (random() * 2 - 1) * math.max(0, area.medianHalf - 3)
		end
		local x
		if #nearXs > 0 then
			x = nearXs[math.floor(random() * #nearXs) + 1] + (random() * 2 - 1) * area.nearRange
		else
			x = (random() * 2 - 1) * maxX
		end
		spot = { x = math.clamp(x, -maxX, maxX), z = z }
		local clear = true
		for _, other in taken do
			local dx, dz = other.x - spot.x, other.z - spot.z
			if dx * dx + dz * dz < area.minSpacing * area.minSpacing then
				clear = false
				break
			end
		end
		if clear then
			break
		end
	end
	return spot
end

export type Candidate<K> = {
	id: K,
	kos: number,
	at: number, -- when they reached their current count (earlier wins ties)
}

-- Who should wear the bounty crown: the chicken with the most knockouts (at least `minKOs`).
-- The current holder keeps it on a tie; otherwise ties go to whoever got there first.
-- `candidates` should only hold chickens still in the round.
function PowerupLogic.pickLeader<K>(current: K?, candidates: { Candidate<K> }, minKOs: number): K?
	local best: Candidate<K>? = nil
	local holder: Candidate<K>? = nil
	for _, c in candidates do
		if current ~= nil and c.id == current then
			holder = c
		end
		if c.kos >= minKOs then
			if not best or c.kos > best.kos or (c.kos == best.kos and c.at < best.at) then
				best = c
			end
		end
	end
	if holder and holder.kos >= minKOs and best and holder.kos >= best.kos then
		return holder.id
	end
	return if best then best.id else nil
end

-- Golden eggs paid for knocking out the leader.
function PowerupLogic.bountyReward(kos: number, base: number, perKO: number): number
	return base + perKO * kos
end

return PowerupLogic
