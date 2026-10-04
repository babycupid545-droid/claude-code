--!strict
-- A small toolkit for building low-poly models out of parts: blocks, wedges, cylinders,
-- faceted "gems" for trees and rocks. Every builder in this folder uses it.

local Build = {}

export type Props = { [string]: any }

-- A stable random generator so every rebuild produces the same map.
Build.rng = Random.new(20261004)

function Build.reseed(seed: number)
	Build.rng = Random.new(seed)
end

local function apply(p: BasePart, props: Props?)
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	p.CastShadow = true
	if props then
		local parent = props.Parent
		for key, value in props do
			if key ~= "Parent" then
				(p :: any)[key] = value
			end
		end
		if parent then
			p.Parent = parent
		end
	end
end

function Build.part(props: Props?): Part
	local p = Instance.new("Part")
	apply(p, props)
	return p
end

function Build.wedge(props: Props?): WedgePart
	local p = Instance.new("WedgePart")
	apply(p, props)
	return p
end

function Build.cornerWedge(props: Props?): CornerWedgePart
	local p = Instance.new("CornerWedgePart")
	apply(p, props)
	return p
end

-- Cylinder standing upright (Roblox cylinders lie along X by default).
function Build.cylinder(cf: CFrame, height: number, diameter: number, props: Props?): Part
	local p = Build.part(props)
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(height, diameter, diameter)
	p.CFrame = cf * CFrame.Angles(0, 0, math.rad(90))
	return p
end

function Build.ball(cf: CFrame, diameter: number, props: Props?): Part
	local p = Build.part(props)
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(diameter, diameter, diameter)
	p.CFrame = cf
	return p
end

function Build.model(name: string, parent: Instance?): Model
	local m = Instance.new("Model")
	m.Name = name
	if parent then
		m.Parent = parent
	end
	return m
end

function Build.folder(name: string, parent: Instance?): Folder
	local f = Instance.new("Folder")
	f.Name = name
	if parent then
		f.Parent = parent
	end
	return f
end

-- Slight random variation of a colour, so big builds don't look flat.
function Build.vary(c: Color3, amount: number?): Color3
	local h, s, v = c:ToHSV()
	local a = amount or 0.04
	return Color3.fromHSV(
		(h + Build.rng:NextNumber(-a, a) * 0.3) % 1,
		math.clamp(s + Build.rng:NextNumber(-a, a), 0, 1),
		math.clamp(v + Build.rng:NextNumber(-a, a), 0, 1)
	)
end

-- A faceted low-poly blob: a few rotated blocks overlapping into one chunky shape.
function Build.gem(parent: Instance, cf: CFrame, size: Vector3, color: Color3, props: Props?)
	local count = 3
	for i = 1, count do
		local rot = CFrame.Angles(
			Build.rng:NextNumber(-0.6, 0.6),
			Build.rng:NextNumber(0, math.pi),
			Build.rng:NextNumber(-0.6, 0.6)
		)
		local scale = 1 - (i - 1) * 0.12
		local p = Build.part({
			Size = size * scale,
			CFrame = cf * rot,
			Color = Build.vary(color, 0.03),
			Parent = parent,
		})
		if props then
			for key, value in props do
				(p :: any)[key] = value
			end
		end
	end
end

-- Makes everything under `root` decorative: no collisions, ignored by eggs and touches.
function Build.decorative(root: Instance)
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
end

-- Hides big builds from per-frame physics work.
function Build.anchorAll(root: Instance)
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
end

-- Tags for client-side ambient animation (see the client's AmbientAnimator).
function Build.tag(instance: Instance, tag: string)
	instance:AddTag(tag)
end

return Build
