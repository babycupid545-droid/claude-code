--!strict
-- Low-poly farm props: trees, rocks, bushes, hay bales, fences, barns, silos, windmills,
-- clouds, street lamps and floating islands.

local Build = require(script.Parent.Build)
local Palette = require(script.Parent.Palette)

local Props = {}

local rng = function(): Random
	return Build.rng
end

function Props.pineTree(parent: Instance, base: CFrame, height: number): Model
	local m = Build.model("PineTree", parent)
	local trunkH = height * 0.25
	Build.cylinder(base * CFrame.new(0, trunkH / 2, 0), trunkH, height * 0.12, {
		Color = Palette.Trunk,
		Parent = m,
	})
	local layers = 3
	for i = 1, layers do
		local w = height * (0.62 - i * 0.12)
		local h = height * 0.32
		local y = trunkH + (i - 1) * height * 0.2 + h / 2
		-- Two crossed wedge pairs make a faceted cone.
		for r = 0, 3 do
			Build.wedge({
				Size = Vector3.new(w, h, w / 2),
				CFrame = base * CFrame.new(0, y, 0) * CFrame.Angles(0, math.rad(r * 90 + 45 * (i % 2)), 0) * CFrame.new(0, 0, -w / 4),
				Color = Build.vary(Palette.Pine, 0.03),
				Parent = m,
			})
		end
	end
	return m
end

function Props.roundTree(parent: Instance, base: CFrame, height: number): Model
	local m = Build.model("RoundTree", parent)
	local trunkH = height * 0.45
	Build.part({
		Size = Vector3.new(height * 0.12, trunkH, height * 0.12),
		CFrame = base * CFrame.new(0, trunkH / 2, 0) * CFrame.Angles(0, rng():NextNumber(0, 3), 0),
		Color = Palette.Trunk,
		Parent = m,
	})
	local leaf = if rng():NextNumber() < 0.25 then Palette.LeafAutumn else Palette.Leaf
	Build.gem(m, base * CFrame.new(0, trunkH + height * 0.22, 0), Vector3.one * height * 0.55, leaf)
	Build.gem(
		m,
		base * CFrame.new(height * 0.18, trunkH + height * 0.08, height * 0.05),
		Vector3.one * height * 0.35,
		leaf
	)
	return m
end

function Props.rock(parent: Instance, cf: CFrame, size: number): Model
	local m = Build.model("Rock", parent)
	Build.gem(m, cf, Vector3.new(size, size * 0.7, size * 0.9), Palette.Rock)
	return m
end

function Props.bush(parent: Instance, cf: CFrame, size: number): Model
	local m = Build.model("Bush", parent)
	Build.gem(m, cf * CFrame.new(0, size * 0.3, 0), Vector3.new(size, size * 0.7, size), Palette.Bush)
	if rng():NextNumber() < 0.5 then
		for _ = 1, 3 do
			Build.ball(
				cf * CFrame.new(rng():NextNumber(-0.4, 0.4) * size, size * 0.65, rng():NextNumber(-0.4, 0.4) * size),
				size * 0.18,
				{ Color = Palette.Flowers[rng():NextInteger(1, #Palette.Flowers)], Parent = m }
			)
		end
	end
	return m
end

function Props.flowers(parent: Instance, cf: CFrame, spread: number, count: number)
	for _ = 1, count do
		local c = cf * CFrame.new(rng():NextNumber(-spread, spread), 0, rng():NextNumber(-spread, spread))
		Build.part({
			Size = Vector3.new(0.2, 1, 0.2),
			CFrame = c * CFrame.new(0, 0.5, 0),
			Color = Palette.Grass,
			Parent = parent,
		})
		Build.part({
			Size = Vector3.new(0.7, 0.3, 0.7),
			CFrame = c * CFrame.new(0, 1.1, 0) * CFrame.Angles(0, rng():NextNumber(0, 3), 0),
			Color = Palette.Flowers[rng():NextInteger(1, #Palette.Flowers)],
			Parent = parent,
		})
	end
end

function Props.grassTuft(parent: Instance, cf: CFrame)
	for i = 1, 3 do
		Build.wedge({
			Name = "Tuft",
			Size = Vector3.new(0.3, 1.2 + rng():NextNumber() * 0.6, 0.8),
			CFrame = cf * CFrame.Angles(0, rng():NextNumber(0, math.pi * 2), rng():NextNumber(-0.3, 0.3)) * CFrame.new(0, 0.6, 0),
			Color = Build.vary(if i == 2 then Palette.GrassDark else Palette.Grass, 0.04),
			Parent = parent,
		})
	end
end

-- Big red barn doors standing open at the end of the median, `width` wide.
function Props.barnGate(parent: Instance, base: CFrame, width: number): Model
	local m = Build.model("BarnGate", parent)
	local h = 14
	for _, side in { -1, 1 } do
		Build.part({ Size = Vector3.new(2, h, 2), CFrame = base * CFrame.new(side * width / 2, h / 2, 0), Color = Palette.BarnRed, Parent = m })
		-- Open doors swung back.
		local door = Build.part({
			Size = Vector3.new(width / 2, h - 2, 0.6),
			CFrame = base * CFrame.new(side * (width / 2 + 0.5), (h - 2) / 2, 0) * CFrame.Angles(0, side * math.rad(-70), 0) * CFrame.new(side * width / 4, 0, 0),
			Color = Palette.BarnRed,
			Parent = m,
		})
		Build.part({ Size = Vector3.new(width / 2, 0.5, 0.7), CFrame = door.CFrame, Color = Palette.Trim, Parent = m })
	end
	Build.part({ Size = Vector3.new(width + 4, 2.4, 2.4), CFrame = base * CFrame.new(0, h + 1, 0), Color = Palette.Trim, Parent = m })
	Build.wedge({ Size = Vector3.new(width + 6, 5, 3), CFrame = base * CFrame.new(0, h + 4.7, 0), Color = Palette.Roof, Parent = m })
	return m
end

function Props.hayBale(parent: Instance, cf: CFrame, round: boolean?): Model
	local m = Build.model("HayBale", parent)
	if round then
		local p = Build.part({ Color = Palette.Hay, Parent = m })
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(4, 5, 5)
		p.CFrame = cf * CFrame.new(0, 2.5, 0)
		Build.part({ Size = Vector3.new(4.1, 0.3, 5.1), CFrame = cf * CFrame.new(0, 2.5, 0), Color = Palette.HayDark, Parent = m })
	else
		Build.part({ Size = Vector3.new(5, 3, 3), CFrame = cf * CFrame.new(0, 1.5, 0), Color = Palette.Hay, Parent = m })
		for _, x in { -1.4, 1.4 } do
			Build.part({ Size = Vector3.new(0.3, 3.05, 3.05), CFrame = cf * CFrame.new(x, 1.5, 0), Color = Palette.HayDark, Parent = m })
		end
	end
	return m
end

function Props.fence(parent: Instance, from: Vector3, to: Vector3, color: Color3?): Model
	local m = Build.model("Fence", parent)
	local c = color or Palette.Wood
	local dir = to - from
	local length = dir.Magnitude
	local cf = CFrame.lookAt(from, to)
	local posts = math.max(1, math.floor(length / 6))
	for i = 0, posts do
		local p = cf * CFrame.new(0, 1.6, -length * i / posts)
		Build.part({ Size = Vector3.new(0.6, 3.4, 0.6), CFrame = p, Color = c, Parent = m })
		Build.wedge({ Size = Vector3.new(0.6, 0.4, 0.6), CFrame = p * CFrame.new(0, 1.9, 0), Color = c, Parent = m })
	end
	for _, y in { 1.2, 2.5 } do
		Build.part({
			Size = Vector3.new(0.25, 0.5, length),
			CFrame = cf * CFrame.new(0, y, -length / 2),
			Color = Build.vary(c, 0.02),
			Parent = m,
		})
	end
	return m
end

function Props.barn(parent: Instance, base: CFrame, scale: number?): Model
	local s = scale or 1
	local m = Build.model("Barn", parent)
	local w, d, h = 22 * s, 28 * s, 14 * s
	Build.part({ Size = Vector3.new(w, h, d), CFrame = base * CFrame.new(0, h / 2, 0), Color = Palette.BarnRed, Parent = m })
	-- Roof: two wedges per side for a gambrel shape.
	for _, side in { -1, 1 } do
		Build.wedge({
			Size = Vector3.new(d + 1, h * 0.45, w * 0.28),
			CFrame = base * CFrame.new(side * w * 0.36, h + h * 0.225, 0) * CFrame.Angles(0, math.rad(-90 * side), 0),
			Color = Palette.Roof,
			Parent = m,
		})
		Build.wedge({
			Size = Vector3.new(d + 1, h * 0.3, w * 0.24),
			CFrame = base * CFrame.new(side * w * 0.12, h + h * 0.45 + h * 0.15, 0) * CFrame.Angles(0, math.rad(-90 * side), 0),
			Color = Palette.Roof,
			Parent = m,
		})
	end
	Build.part({
		Size = Vector3.new(w * 0.48, h * 0.45, d + 0.2),
		CFrame = base * CFrame.new(0, h + h * 0.225, 0),
		Color = Palette.BarnRed,
		Parent = m,
	})
	-- Front doors with the classic white X trim.
	local front = base * CFrame.new(0, 0, -d / 2 - 0.15)
	Build.part({ Size = Vector3.new(w * 0.5, h * 0.62, 0.3), CFrame = front * CFrame.new(0, h * 0.31, 0), Color = Palette.BarnDark, Parent = m })
	local dw, dh = w * 0.5, h * 0.62
	for _, sign in { -1, 1 } do
		Build.part({
			Size = Vector3.new(0.5, math.sqrt(dw * dw + dh * dh) * 0.95, 0.35),
			CFrame = front * CFrame.new(0, dh / 2, -0.05) * CFrame.Angles(0, 0, sign * math.atan2(dw, dh)),
			Color = Palette.Trim,
			Parent = m,
		})
	end
	for _, edge in { { 0, dh, dw + 0.5, 0.6 }, { -dw / 2, dh / 2, 0.6, dh }, { dw / 2, dh / 2, 0.6, dh } } do
		Build.part({
			Size = Vector3.new(edge[3], edge[4], 0.4),
			CFrame = front * CFrame.new(edge[1], edge[2], -0.08),
			Color = Palette.Trim,
			Parent = m,
		})
	end
	-- Hay loft window.
	Build.part({ Size = Vector3.new(w * 0.22, h * 0.25, 0.3), CFrame = front * CFrame.new(0, h * 1.05, 0), Color = Palette.BarnDark, Parent = m })
	Build.part({ Size = Vector3.new(w * 0.26, 0.5, 0.4), CFrame = front * CFrame.new(0, h * 1.18, -0.05), Color = Palette.Trim, Parent = m })
	return m
end

function Props.silo(parent: Instance, base: CFrame, height: number): Model
	local m = Build.model("Silo", parent)
	local dia = height * 0.32
	Build.cylinder(base * CFrame.new(0, height / 2, 0), height, dia, { Color = Palette.Metal, Material = Enum.Material.Metal, Parent = m })
	for i = 1, 4 do
		Build.cylinder(base * CFrame.new(0, height * i / 5, 0), 0.5, dia + 0.3, { Color = Palette.MetalDark, Parent = m })
	end
	Build.ball(base * CFrame.new(0, height, 0), dia, { Color = Palette.Roof, Parent = m })
	return m
end

function Props.windmill(parent: Instance, base: CFrame, height: number): Model
	local m = Build.model("Windmill", parent)
	-- Tapered tower from stacked, shrinking blocks.
	local steps = 5
	for i = 0, steps - 1 do
		local w = height * (0.32 - i * 0.035)
		Build.part({
			Size = Vector3.new(w, height / steps, w),
			CFrame = base * CFrame.new(0, (i + 0.5) * height / steps, 0) * CFrame.Angles(0, math.rad(45 * (i % 2) * 0.2), 0),
			Color = if i % 2 == 0 then Palette.Plaster else Build.vary(Palette.Plaster, 0.02),
			Parent = m,
		})
	end
	local capW = height * 0.2
	for r = 0, 3 do
		Build.wedge({
			Size = Vector3.new(capW, capW * 0.8, capW / 2),
			CFrame = base * CFrame.new(0, height + capW * 0.4, 0) * CFrame.Angles(0, math.rad(r * 90), 0) * CFrame.new(0, 0, -capW / 4),
			Color = Palette.Roof,
			Parent = m,
		})
	end
	-- Blades in their own model, tagged so clients spin them.
	local hub = base * CFrame.new(0, height * 0.92, -height * 0.16)
	local blades = Build.model("Blades", m)
	Build.ball(hub, 2.4, { Color = Palette.Wood, Parent = blades })
	for i = 0, 3 do
		local rot = hub * CFrame.Angles(0, 0, math.rad(i * 90))
		Build.part({ Size = Vector3.new(0.6, height * 0.42, 0.4), CFrame = rot * CFrame.new(0, height * 0.22, 0), Color = Palette.Wood, Parent = blades })
		Build.part({ Size = Vector3.new(height * 0.09, height * 0.34, 0.2), CFrame = rot * CFrame.new(height * 0.05, height * 0.25, 0), Color = Palette.Sail, Parent = blades })
	end
	-- Clients spin the model around its pivot's Z axis.
	blades.WorldPivot = hub
	Build.tag(blades, "Spin")
	blades:SetAttribute("SpinSpeed", 0.8)
	return m
end

function Props.farmhouse(parent: Instance, base: CFrame): Model
	local m = Build.model("Farmhouse", parent)
	local w, d, h = 16, 12, 9
	Build.part({ Size = Vector3.new(w, h, d), CFrame = base * CFrame.new(0, h / 2, 0), Color = Palette.Plaster, Parent = m })
	for _, side in { -1, 1 } do
		Build.wedge({
			Size = Vector3.new(w + 1.5, 6, d / 2 + 1),
			CFrame = base * CFrame.new(0, h + 3, side * (d / 4 + 0.5)) * CFrame.Angles(0, math.rad(if side == 1 then 180 else 0), 0),
			Color = Palette.RoofBlue,
			Parent = m,
		})
	end
	Build.part({ Size = Vector3.new(2, 5, 2), CFrame = base * CFrame.new(w * 0.3, h + 4, 0), Color = Palette.Brick, Parent = m })
	local front = base * CFrame.new(0, 0, -d / 2 - 0.1)
	Build.part({ Size = Vector3.new(3, 5.5, 0.3), CFrame = front * CFrame.new(0, 2.75, 0), Color = Palette.BarnDark, Parent = m })
	for _, x in { -5, 5 } do
		Build.part({ Size = Vector3.new(3, 3, 0.3), CFrame = front * CFrame.new(x, 5, 0), Color = Palette.Window, Material = Enum.Material.Glass, Parent = m })
		Build.part({ Size = Vector3.new(3.6, 0.4, 0.5), CFrame = front * CFrame.new(x, 3.3, 0), Color = Palette.Trim, Parent = m })
	end
	return m
end

function Props.lamp(parent: Instance, base: CFrame): Model
	local m = Build.model("Lamp", parent)
	Build.cylinder(base * CFrame.new(0, 6, 0), 12, 0.6, { Color = Palette.MetalDark, Parent = m })
	Build.part({ Size = Vector3.new(0.5, 0.5, 3), CFrame = base * CFrame.new(0, 12, -1.3), Color = Palette.MetalDark, Parent = m })
	local bulb = Build.part({
		Size = Vector3.new(1.4, 0.7, 1.8),
		CFrame = base * CFrame.new(0, 11.7, -2.6),
		Color = Palette.LampGlow,
		Material = Enum.Material.Neon,
		Parent = m,
	})
	local light = Instance.new("PointLight")
	light.Range = 16
	light.Brightness = 0.6
	light.Color = Palette.LampGlow
	light.Parent = bulb
	return m
end

function Props.cloud(parent: Instance, cf: CFrame, size: number): Model
	local m = Build.model("Cloud", parent)
	-- A flat base with smaller puffs stacked on top reads as a cartoon cloud.
	for i = 1, 7 do
		local tier = if i <= 3 then 0 else 1
		local w = size * (if tier == 0 then rng():NextNumber(0.7, 1.0) else rng():NextNumber(0.4, 0.6))
		local off = Vector3.new(rng():NextNumber(-0.7, 0.7) * size, tier * size * 0.22, rng():NextNumber(-0.25, 0.25) * size)
		local p = Build.part({
			Size = Vector3.new(w, size * (if tier == 0 then 0.28 else 0.32), w * rng():NextNumber(0.55, 0.8)),
			CFrame = cf * CFrame.new(off) * CFrame.Angles(0, rng():NextNumber(-0.4, 0.4), 0),
			Color = if tier == 0 then Color3.fromRGB(232, 238, 250) else Palette.Cloud,
			Parent = m,
		})
		p.CastShadow = false
	end
	Build.tag(m, "Drift")
	return m
end

-- The rocky underside of a floating island: stacked shrinking chunks hanging below `top`.
-- Tilts are kept tiny relative to the size so nothing pokes up through the surface.
function Props.islandUnderside(parent: Instance, top: CFrame, size: Vector2, depth: number)
	local layers = 4
	local layerH = depth / layers
	for i = 1, layers do
		local f = 1 - i / (layers + 1)
		local chunk = Vector3.new(size.X * f, layerH * 1.15, size.Y * f)
		local maxTilt = math.min(0.08, 0.8 / math.max(chunk.X, chunk.Z))
		local y = -(i - 0.5) * layerH - 0.3
		for _ = 1, 2 do
			Build.part({
				Size = chunk * Vector3.new(rng():NextNumber(0.85, 1), 1, rng():NextNumber(0.85, 1)),
				CFrame = top * CFrame.new(rng():NextNumber(-2, 2), y, rng():NextNumber(-2, 2)) * CFrame.Angles(
					rng():NextNumber(-maxTilt, maxTilt),
					rng():NextNumber(-0.3, 0.3) * math.min(1, 20 / math.max(chunk.X, chunk.Z)),
					rng():NextNumber(-maxTilt, maxTilt)
				),
				Color = Build.vary(if i == 1 then Palette.Dirt else Palette.Rock, 0.03),
				Parent = parent,
			})
		end
	end
	-- A pointy tip.
	Build.gem(parent, top * CFrame.new(0, -depth * 1.05, 0), Vector3.new(size.X * 0.15, depth * 0.4, size.Y * 0.15), Palette.Rock)
end

-- A small floating island with a grassy top and some props.
function Props.floatingIsland(parent: Instance, cf: CFrame, radius: number, decorate: ((Model, CFrame) -> ())?): Model
	local m = Build.model("FloatingIsland", parent)
	Build.part({ Size = Vector3.new(radius * 2, 2, radius * 2), CFrame = cf * CFrame.new(0, -1, 0), Color = Palette.Grass, Parent = m })
	Build.part({ Size = Vector3.new(radius * 2.05, 1.2, radius * 2.05), CFrame = cf * CFrame.new(0, -2.4, 0), Color = Palette.Dirt, Parent = m })
	Props.islandUnderside(m, cf * CFrame.new(0, -3, 0), Vector2.new(radius * 2, radius * 2), radius * 1.4)
	if decorate then
		decorate(m, cf)
	end
	Build.tag(m, "Bob")
	return m
end

return Props
