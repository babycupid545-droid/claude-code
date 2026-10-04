--!strict
-- Low-poly vehicles for the road, saved to ReplicatedStorage.Assets.Cars. Every model is
-- 8 wide x 6 tall x 14 long, pivoted at its center with the front facing -Z.

local Build = require(script.Parent.Build)
local Palette = require(script.Parent.Palette)

local CarBuilder = {}

local W, H, L = 8, 6, 14
local GROUND = -H / 2
local GLASS = Color3.fromRGB(150, 205, 240)
local TIRE = Color3.fromRGB(34, 32, 40)
local HUB = Color3.fromRGB(200, 205, 215)
local BUMPER = Color3.fromRGB(70, 72, 84)

local function wheels(m: Model, z: { number }, diameter: number?, width: number?)
	local d = diameter or 2.8
	local w = width or 1.3
	for _, zz in z do
		for _, x in { -1, 1 } do
			local tire = Build.part({ Name = "Wheel", Color = TIRE, Parent = m })
			tire.Shape = Enum.PartType.Cylinder
			tire.Size = Vector3.new(w, d, d)
			tire.CFrame = CFrame.new(x * (W / 2 - w / 2 + 0.05), GROUND + d / 2, zz)
			local hub = Build.part({ Name = "Hub", Color = HUB, Parent = m })
			hub.Shape = Enum.PartType.Cylinder
			hub.Size = Vector3.new(w + 0.1, d * 0.45, d * 0.45)
			hub.CFrame = tire.CFrame
		end
	end
end

local function lights(m: Model, frontZ: number, backZ: number, y: number)
	for _, x in { -1, 1 } do
		Build.part({
			Name = "Headlight",
			Size = Vector3.new(1.6, 0.8, 0.3),
			CFrame = CFrame.new(x * (W / 2 - 1.3), y, frontZ - 0.1),
			Color = Color3.fromRGB(255, 250, 210),
			Material = Enum.Material.Neon,
			Parent = m,
		})
		Build.part({
			Name = "Taillight",
			Size = Vector3.new(1.4, 0.7, 0.3),
			CFrame = CFrame.new(x * (W / 2 - 1.2), y, backZ + 0.1),
			Color = Color3.fromRGB(255, 50, 50),
			Material = Enum.Material.Neon,
			Parent = m,
		})
	end
	for _, z in { frontZ, backZ } do
		Build.part({ Name = "Bumper", Size = Vector3.new(W - 0.4, 0.7, 0.5), CFrame = CFrame.new(0, GROUND + 1.3, z), Color = BUMPER, Parent = m })
	end
end

-- Lower body + cabin with sloped windshield and rear window: the classic car silhouette.
local function sedanBody(m: Model, color: Color3, cabinFront: number, cabinBack: number, roofY: number)
	local bodyTop = GROUND + 3.2
	Build.part({ Name = "Body", Size = Vector3.new(W - 0.2, 2.2, L - 0.4), CFrame = CFrame.new(0, bodyTop - 1.1, 0), Color = color, Parent = m })
	local cabinH = roofY - bodyTop
	local slope = 2.2
	local cabinLen = cabinBack - cabinFront - slope * 2
	Build.part({
		Name = "Cabin",
		Size = Vector3.new(W - 1, cabinH, cabinLen),
		CFrame = CFrame.new(0, bodyTop + cabinH / 2, (cabinFront + cabinBack) / 2),
		Color = color,
		Parent = m,
	})
	Build.wedge({
		Name = "Windshield",
		Size = Vector3.new(W - 1, cabinH, slope),
		CFrame = CFrame.new(0, bodyTop + cabinH / 2, cabinFront + slope / 2),
		Color = GLASS,
		Material = Enum.Material.Glass,
		Transparency = 0.15,
		Parent = m,
	})
	Build.wedge({
		Name = "RearWindow",
		Size = Vector3.new(W - 1, cabinH, slope),
		CFrame = CFrame.new(0, bodyTop + cabinH / 2, cabinBack - slope / 2) * CFrame.Angles(0, math.pi, 0),
		Color = GLASS,
		Material = Enum.Material.Glass,
		Transparency = 0.15,
		Parent = m,
	})
	for _, x in { -1, 1 } do
		Build.part({
			Name = "SideWindow",
			Size = Vector3.new(0.1, cabinH * 0.55, cabinLen * 0.85),
			CFrame = CFrame.new(x * (W - 1) / 2, bodyTop + cabinH * 0.55, (cabinFront + cabinBack) / 2),
			Color = GLASS,
			Material = Enum.Material.Glass,
			Parent = m,
		})
	end
	-- Body-coloured roof and a dark grille so it reads as a car, not a glass box.
	Build.part({
		Name = "Roof",
		Size = Vector3.new(W - 0.8, 0.35, cabinLen + 0.6),
		CFrame = CFrame.new(0, roofY + 0.05, (cabinFront + cabinBack) / 2),
		Color = color,
		Parent = m,
	})
	Build.part({
		Name = "Grille",
		Size = Vector3.new(W * 0.45, 0.9, 0.2),
		CFrame = CFrame.new(0, bodyTop - 0.9, -L / 2 + 0.15),
		Color = Color3.fromRGB(40, 40, 50),
		Parent = m,
	})
	return bodyTop
end

local function finish(m: Model)
	m.WorldPivot = CFrame.new()
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = true
		end
	end
end

local function sedan(name: string, color: Color3): Model
	local m = Build.model(name)
	sedanBody(m, color, -3.5, 4.5, H / 2 - 0.2)
	wheels(m, { -4.4, 4.4 })
	lights(m, -L / 2, L / 2, GROUND + 2.4)
	return m
end

local function taxi(): Model
	local m = sedan("Taxi", Color3.fromRGB(255, 205, 40))
	Build.part({ Name = "TaxiSign", Size = Vector3.new(2.4, 0.9, 1.2), CFrame = CFrame.new(0, H / 2 + 0.25, 0.5), Color = Color3.fromRGB(255, 250, 230), Material = Enum.Material.Neon, Parent = m })
	for z = -6, 6, 2 do
		for _, x in { -1, 1 } do
			Build.part({
				Name = "Checker",
				Size = Vector3.new(0.1, 0.5, 1),
				CFrame = CFrame.new(x * (W / 2 - 0.05), GROUND + 2.6, z + ((z / 2) % 2) * 0.5),
				Color = Color3.fromRGB(30, 30, 30),
				Parent = m,
			})
		end
	end
	return m
end

local function hatchback(): Model
	local m = Build.model("Hatchback")
	sedanBody(m, Color3.fromRGB(110, 200, 120), -2.5, 6.6, H / 2 - 0.3)
	wheels(m, { -4.2, 4.4 })
	lights(m, -L / 2, L / 2, GROUND + 2.4)
	return m
end

local function sports(): Model
	local m = Build.model("SportsCar")
	local color = Color3.fromRGB(150, 80, 230)
	Build.part({ Name = "Body", Size = Vector3.new(W - 0.2, 1.8, L - 0.4), CFrame = CFrame.new(0, GROUND + 1.9, 0.3), Color = color, Parent = m })
	Build.wedge({ Name = "Nose", Size = Vector3.new(W - 0.2, 1.2, 3), CFrame = CFrame.new(0, GROUND + 1.6, -L / 2 + 1.4), Color = color, Parent = m })
	Build.wedge({
		Name = "Windshield",
		Size = Vector3.new(W - 1.4, 1.6, 3.5),
		CFrame = CFrame.new(0, GROUND + 3.6, -1),
		Color = GLASS,
		Material = Enum.Material.Glass,
		Parent = m,
	})
	Build.part({ Name = "Roof", Size = Vector3.new(W - 1.4, 1.6, 3), CFrame = CFrame.new(0, GROUND + 3.6, 2.2), Color = Color3.fromRGB(40, 30, 60), Parent = m })
	Build.part({ Name = "Spoiler", Size = Vector3.new(W, 0.3, 1.4), CFrame = CFrame.new(0, GROUND + 4.2, L / 2 - 0.9), Color = Color3.fromRGB(40, 30, 60), Parent = m })
	for _, x in { -2.8, 2.8 } do
		Build.part({ Name = "SpoilerLeg", Size = Vector3.new(0.3, 1.3, 0.4), CFrame = CFrame.new(x, GROUND + 3.4, L / 2 - 0.9), Color = Color3.fromRGB(40, 30, 60), Parent = m })
	end
	Build.part({ Name = "Stripe", Size = Vector3.new(1.4, 0.05, L - 0.6), CFrame = CFrame.new(0, GROUND + 2.83, 0.3), Color = Color3.fromRGB(255, 255, 255), Parent = m })
	wheels(m, { -4.4, 4.6 }, 2.6)
	lights(m, -L / 2, L / 2, GROUND + 2)
	return m
end

local function pickup(): Model
	local m = Build.model("Pickup")
	local color = Color3.fromRGB(240, 120, 40)
	local bodyTop = GROUND + 3.4
	Build.part({ Name = "Body", Size = Vector3.new(W - 0.2, 2.4, L - 0.4), CFrame = CFrame.new(0, bodyTop - 1.2, 0), Color = color, Parent = m })
	Build.part({ Name = "Cab", Size = Vector3.new(W - 0.6, 2.4, 4), CFrame = CFrame.new(0, bodyTop + 1.2, -1.6), Color = color, Parent = m })
	Build.wedge({ Name = "Windshield", Size = Vector3.new(W - 0.6, 2.4, 1.6), CFrame = CFrame.new(0, bodyTop + 1.2, -4.4), Color = GLASS, Material = Enum.Material.Glass, Parent = m })
	-- Bed with walls and a hay bale in it.
	Build.part({ Name = "BedFloor", Size = Vector3.new(W - 0.6, 0.3, 6), CFrame = CFrame.new(0, bodyTop + 0.15, 3.6), Color = Palette.WoodDark, Parent = m })
	for _, x in { -1, 1 } do
		Build.part({ Name = "BedWall", Size = Vector3.new(0.4, 1.4, 6.4), CFrame = CFrame.new(x * (W / 2 - 0.4), bodyTop + 0.7, 3.6), Color = color, Parent = m })
	end
	Build.part({ Name = "Tailgate", Size = Vector3.new(W - 0.4, 1.4, 0.4), CFrame = CFrame.new(0, bodyTop + 0.7, L / 2 - 0.4), Color = color, Parent = m })
	Build.part({ Name = "Hay", Size = Vector3.new(4, 1.8, 2.6), CFrame = CFrame.new(0, bodyTop + 1.2, 3.4), Color = Palette.Hay, Parent = m })
	wheels(m, { -4.4, 4.4 }, 3)
	lights(m, -L / 2, L / 2, GROUND + 2.6)
	return m
end

local function van(name: string, color: Color3, iceCream: boolean): Model
	local m = Build.model(name)
	Build.part({ Name = "Body", Size = Vector3.new(W - 0.2, H - 1.4, L - 1.6), CFrame = CFrame.new(0, GROUND + 1 + (H - 1.4) / 2, 0.6), Color = color, Parent = m })
	Build.wedge({ Name = "Nose", Size = Vector3.new(W - 0.2, 2, 1.6), CFrame = CFrame.new(0, GROUND + 2, -L / 2 + 0.8), Color = color, Parent = m })
	Build.part({ Name = "Windshield", Size = Vector3.new(W - 0.8, 1.8, 0.2), CFrame = CFrame.new(0, GROUND + 3.9, -L / 2 + 1.55), Color = GLASS, Material = Enum.Material.Glass, Parent = m })
	for _, x in { -1, 1 } do
		Build.part({ Name = "SideWindow", Size = Vector3.new(0.1, 1.6, 3), CFrame = CFrame.new(x * (W / 2 - 0.05), GROUND + 3.9, -3.5), Color = GLASS, Material = Enum.Material.Glass, Parent = m })
	end
	if iceCream then
		Build.part({ Name = "Stripe", Size = Vector3.new(W, 0.8, L - 1.6), CFrame = CFrame.new(0, GROUND + 2.2, 0.6), Color = Color3.fromRGB(255, 255, 255), Parent = m })
		-- Giant cone on the roof.
		local cone = Build.model("Cone", m)
		for r = 0, 3 do
			Build.wedge({
				Size = Vector3.new(1.6, 2.2, 0.8),
				CFrame = CFrame.new(0, H / 2 + 0.6, 2) * CFrame.Angles(math.pi, math.rad(r * 90), 0) * CFrame.new(0, 0, -0.4),
				Color = Color3.fromRGB(220, 170, 100),
				Parent = cone,
			})
		end
		Build.ball(CFrame.new(0, H / 2 + 2, 2), 2.2, { Color = Color3.fromRGB(255, 170, 200), Parent = cone })
		Build.ball(CFrame.new(0, H / 2 + 3.1, 2), 0.6, { Color = Color3.fromRGB(230, 40, 60), Parent = cone })
	else
		Build.part({ Name = "RoofRack", Size = Vector3.new(W - 1.6, 0.4, 6), CFrame = CFrame.new(0, H / 2 - 0.2, 1.5), Color = BUMPER, Parent = m })
	end
	wheels(m, { -4.4, 4.6 })
	lights(m, -L / 2, L / 2, GROUND + 2.2)
	return m
end

local function tractor(): Model
	local m = Build.model("Tractor")
	local green = Color3.fromRGB(70, 170, 70)
	Build.part({ Name = "Hood", Size = Vector3.new(3.6, 2.6, 7), CFrame = CFrame.new(0, GROUND + 3, -3.2), Color = green, Parent = m })
	Build.part({ Name = "Grille", Size = Vector3.new(3.2, 2.2, 0.3), CFrame = CFrame.new(0, GROUND + 3, -6.8), Color = BUMPER, Parent = m })
	Build.cylinder(CFrame.new(0.9, GROUND + 5.3, -4.5), 2.2, 0.5, { Name = "Exhaust", Color = BUMPER, Parent = m })
	Build.part({ Name = "CabinFloor", Size = Vector3.new(5, 0.6, 5), CFrame = CFrame.new(0, GROUND + 2.6, 2.6), Color = green, Parent = m })
	Build.part({ Name = "CabinRoof", Size = Vector3.new(5.4, 0.4, 5.4), CFrame = CFrame.new(0, H / 2 - 0.2, 2.6), Color = Color3.fromRGB(250, 240, 220), Parent = m })
	for _, x in { -2.3, 2.3 } do
		for _, z in { 0.4, 4.8 } do
			Build.part({ Name = "Post", Size = Vector3.new(0.3, 3.2, 0.3), CFrame = CFrame.new(x, H / 2 - 2, z), Color = BUMPER, Parent = m })
		end
	end
	Build.part({ Name = "Seat", Size = Vector3.new(1.8, 1.2, 1.4), CFrame = CFrame.new(0, GROUND + 3.5, 3.2), Color = Color3.fromRGB(240, 200, 60), Parent = m })
	-- Small front wheels, huge rear wheels.
	for _, x in { -1, 1 } do
		local front = Build.part({ Name = "Wheel", Color = TIRE, Parent = m })
		front.Shape = Enum.PartType.Cylinder
		front.Size = Vector3.new(1, 2.4, 2.4)
		front.CFrame = CFrame.new(x * 2.4, GROUND + 1.2, -4.6)
		local rear = Build.part({ Name = "Wheel", Color = TIRE, Parent = m })
		rear.Shape = Enum.PartType.Cylinder
		rear.Size = Vector3.new(1.6, 4.6, 4.6)
		rear.CFrame = CFrame.new(x * 3.2, GROUND + 2.3, 3.4)
		local hub = Build.part({ Name = "Hub", Color = Color3.fromRGB(240, 200, 60), Parent = m })
		hub.Shape = Enum.PartType.Cylinder
		hub.Size = Vector3.new(1.7, 2.2, 2.2)
		hub.CFrame = rear.CFrame
	end
	for _, x in { -1, 1 } do
		Build.part({ Name = "Headlight", Size = Vector3.new(0.8, 0.8, 0.3), CFrame = CFrame.new(x * 1.2, GROUND + 3.4, -6.9), Color = Color3.fromRGB(255, 250, 210), Material = Enum.Material.Neon, Parent = m })
	end
	return m
end

local function rageCar(): Model
	local m = Build.model("RageCar")
	local black = Color3.fromRGB(30, 26, 36)
	sedanBody(m, black, -2.8, 4.6, H / 2 - 0.4)
	-- Flame decals made of neon wedges.
	for i = 0, 3 do
		for _, x in { -1, 1 } do
			Build.wedge({
				Name = "Flame",
				Size = Vector3.new(0.1, 1.1 - i * 0.15, 2.4),
				CFrame = CFrame.new(x * (W / 2 - 0.05), GROUND + 2.1 + (i % 2) * 0.4, -5 + i * 2.2) * CFrame.Angles(0, math.pi, 0),
				Color = if i % 2 == 0 then Color3.fromRGB(255, 80, 30) else Color3.fromRGB(255, 200, 40),
				Material = Enum.Material.Neon,
				Parent = m,
			})
		end
	end
	-- Angry eyebrows over the headlights and roof spikes.
	for _, x in { -1, 1 } do
		Build.part({
			Name = "Brow",
			Size = Vector3.new(2, 0.4, 0.4),
			CFrame = CFrame.new(x * 2.6, GROUND + 3.2, -L / 2 + 0.1) * CFrame.Angles(0, 0, math.rad(-20 * x)),
			Color = Color3.fromRGB(255, 40, 40),
			Material = Enum.Material.Neon,
			Parent = m,
		})
	end
	for z = -1, 3, 2 do
		for r = 0, 3 do
			Build.wedge({
				Name = "Spike",
				Size = Vector3.new(0.8, 1.2, 0.4),
				CFrame = CFrame.new(0, H / 2 + 0.2, z) * CFrame.Angles(0, math.rad(r * 90), 0) * CFrame.new(0, 0, -0.2),
				Color = Color3.fromRGB(200, 205, 215),
				Material = Enum.Material.Metal,
				Parent = m,
			})
		end
	end
	wheels(m, { -4.4, 4.4 }, 3.2, 1.6)
	lights(m, -L / 2, L / 2, GROUND + 2.4)
	for _, d in m:GetChildren() do
		if d.Name == "Headlight" and d:IsA("BasePart") then
			d.Color = Color3.fromRGB(255, 40, 40)
		end
	end
	return m
end

function CarBuilder.build(folder: Instance)
	local cars = {
		sedan("Sedan", Color3.fromRGB(60, 130, 230)),
		sedan("SedanRed", Color3.fromRGB(225, 60, 55)),
		taxi(),
		hatchback(),
		sports(),
		pickup(),
		van("Van", Color3.fromRGB(245, 245, 240), false),
		van("IceCreamVan", Color3.fromRGB(255, 160, 200), true),
		tractor(),
		rageCar(),
	}
	for _, car in cars do
		finish(car)
		car.Parent = folder
	end
end

return CarBuilder
