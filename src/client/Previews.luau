--!strict
-- Small 3D models for shop previews (shown in ViewportFrames).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Assets = require(Shared.Assets)
local Cosmetics = require(Shared.Cosmetics)

local Effects = require(script.Parent.Effects)

local Previews = {}

local function part(model: Model, size: Vector3, cf: CFrame, color: Color3, sphere: boolean?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if sphere then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	p.Parent = model
	return p
end

-- A chubby cartoon chicken in a skin's colours (front faces -Z).
function Previews.chicken(skinId: string): Model
	local skin = Cosmetics.resolve("ChickenSkin", skinId)
	local rig = Assets.find("Chickens", skin.id)
	if rig and rig:IsA("Model") then
		local clone = rig:Clone()
		for _, d in clone:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
			elseif d:IsA("Script") or d:IsA("LocalScript") then
				d:Destroy()
			end
		end
		return clone
	end
	local look = skin.look
	local colors = look.colors or { Color3.new(1, 1, 1) }
	local function c(i: number): Color3
		return colors[((i - 1) % #colors) + 1]
	end
	local m = Instance.new("Model")
	local body = part(m, Vector3.new(3.2, 3, 3.8), CFrame.new(0, 2.4, 0.3), c(1), true)
	part(m, Vector3.new(2.3, 2.3, 2.3), CFrame.new(0, 4.4, -1), c(2), true)
	part(m, Vector3.new(0.7, 0.5, 1), CFrame.new(0, 4.3, -2.3), look.beak or Color3.fromRGB(255, 160, 30))
	part(m, Vector3.new(0.45, 0.7, 0.45), CFrame.new(0, 3.7, -2.05), look.comb or c(2), true)
	if look.comb then
		for i = -1, 1 do
			part(m, Vector3.new(0.6, 0.6, 0.6), CFrame.new(0, 5.6, -1 + i * 0.45), look.comb, true)
		end
	end
	for _, x in { -0.55, 0.55 } do
		part(m, Vector3.new(0.4, 0.4, 0.4), CFrame.new(x, 4.7, -2.05), Color3.fromRGB(30, 25, 35), true)
		part(m, Vector3.new(0.6, 2, 2.4), CFrame.new(x * 3, 2.6, 0.4) * CFrame.Angles(0.2, 0, 0), c(3), true)
		part(m, Vector3.new(0.3, 1.2, 0.3), CFrame.new(x * 1.3, 0.6, 0.3), look.beak or Color3.fromRGB(255, 160, 30))
	end
	for i = -1, 1 do
		part(m, Vector3.new(0.5, 1.8, 0.5), CFrame.new(i * 0.5, 3.4, 2.1) * CFrame.Angles(0.6, 0, i * 0.3), c(i + 2), false)
	end
	if look.material then
		body.Material = look.material
	end
	m.PrimaryPart = body
	return m
end

function Previews.egg(skinId: string): Model
	local egg = Effects.makeEgg(skinId)
	local m = Instance.new("Model")
	if egg:IsA("BasePart") then
		egg.Size *= 3
		egg.CFrame = CFrame.Angles(math.rad(90), 0, 0)
	elseif egg:IsA("Model") then
		egg:ScaleTo(3)
		egg:PivotTo(CFrame.Angles(math.rad(90), 0, 0))
	end
	egg.Parent = m
	return m
end

-- Puts a model in a viewport with a camera framing it. Returns the model for spinning.
function Previews.show(viewport: ViewportFrame, model: Model): Model
	viewport:ClearAllChildren()
	local world = Instance.new("WorldModel")
	world.Parent = viewport
	model.Parent = world
	local cf, size = model:GetBoundingBox()
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	local dist = size.Magnitude * 1.7
	camera.CFrame = CFrame.lookAt(cf.Position + Vector3.new(dist * 0.35, dist * 0.25, -dist), cf.Position)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	model:SetAttribute("Center", cf.Position)
	return model
end

return Previews
