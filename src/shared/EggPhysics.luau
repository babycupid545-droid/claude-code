--!strict
-- Egg flight, shared by the server (which decides hits) and clients (which draw eggs).

local Config = require(script.Parent.Config)

local EggPhysics = {}

local GRAVITY = Vector3.new(0, -Config.Egg.Gravity, 0)

function EggPhysics.position(origin: Vector3, velocity: Vector3, t: number): Vector3
	return origin + velocity * t + GRAVITY * (0.5 * t * t)
end

function EggPhysics.velocityAt(velocity: Vector3, t: number): Vector3
	return velocity + GRAVITY * t
end

-- Where an egg leaves the chicken: just behind and slightly above the root part.
function EggPhysics.buttOrigin(root: BasePart): Vector3
	return (root.CFrame * CFrame.new(0, 0.3, 1.6)).Position
end

-- Moves an egg from t0 to t1 with a sphere cast so fast eggs can't skip through targets.
-- `radius` defaults to Config.Egg.Radius (mega eggs are bigger).
function EggPhysics.step(
	origin: Vector3,
	velocity: Vector3,
	t0: number,
	t1: number,
	params: RaycastParams,
	radius: number?
): (Vector3, RaycastResult?)
	local from = EggPhysics.position(origin, velocity, t0)
	local to = EggPhysics.position(origin, velocity, t1)
	local delta = to - from
	if delta.Magnitude < 1e-3 then
		return to, nil
	end
	local result = workspace:Spherecast(from, radius or Config.Egg.Radius, delta, params)
	return to, result
end

return EggPhysics
