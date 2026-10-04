--!strict
-- Builds the playable arena and the lobby as real Studio objects.
--
-- The arena is a floating island in the sky: a six-lane road between two tiled sidewalks,
-- rocky tunnels at both ends, and farm islands drifting around it. Falling off the island
-- (or through a collapsed sidewalk) drops you into the clouds.
--
-- Gameplay pieces the scripts rely on (names matter):
--   Workspace.Arena.Road.Lane1..N     drivable lanes
--   Workspace.Arena.Sidewalks.*       tiles with attributes Side ("A"/"B"), Row, Col
--   Workspace.Arena.Walls             invisible walls at the road ends
--   Workspace.Lobby.LobbySpawn        where everyone spawns
-- Everything in Arena.Decor / Lobby.Decor is free to edit or delete.

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local Build = require(script.Parent.Build)
local Palette = require(script.Parent.Palette)
local Props = require(script.Parent.Props)

local WorldBuilder = {}

local M = Config.Map
local ROAD_DEPTH = M.LaneCount * M.LaneWidth
local HALF_L = M.RoadLength / 2
local HALF_D = ROAD_DEPTH / 2
local OUTER_Z = HALF_D + M.SidewalkDepth
local TILE_X = M.RoadLength / M.SidewalkColumns
local TILE_Z = M.SidewalkDepth / M.SidewalkRows
local TILE_THICKNESS = 3

-- Gameplay geometry ------------------------------------------------------------------------

local function buildRoad(arena: Model)
	local road = Build.folder("Road", arena)
	for i = 1, M.LaneCount do
		local z = -HALF_D + (i - 0.5) * M.LaneWidth
		Build.part({
			Name = `Lane{i}`,
			Size = Vector3.new(M.RoadLength + 40, 4, M.LaneWidth),
			Position = Vector3.new(0, M.RoadTopY - 2, z),
			Color = if i % 2 == 0 then Palette.Asphalt else Palette.AsphaltDark:Lerp(Palette.Asphalt, 0.6),
			Material = Enum.Material.SmoothPlastic,
			Parent = road,
		})
	end

	local lines = Build.folder("Lines", road)
	for i = 1, M.LaneCount - 1 do
		local z = -HALF_D + i * M.LaneWidth
		if i == M.LaneCount / 2 then
			for _, off in { -0.5, 0.5 } do
				Build.part({
					Name = "CenterLine",
					Size = Vector3.new(M.RoadLength + 40, 0.06, 0.45),
					Position = Vector3.new(0, M.RoadTopY + 0.03, z + off),
					Color = Palette.CenterLine,
					CanCollide = false,
					CanQuery = false,
					Parent = lines,
				})
			end
		else
			for x = -HALF_L - 16, HALF_L + 16, 16 do
				Build.part({
					Name = "Dash",
					Size = Vector3.new(8, 0.06, 0.5),
					Position = Vector3.new(x, M.RoadTopY + 0.03, z),
					Color = Palette.LaneLine,
					CanCollide = false,
					CanQuery = false,
					Parent = lines,
				})
			end
		end
	end
	-- Zebra crossing in the middle of the road, for the "why did the chicken..." joke.
	for z = -HALF_D + 3, HALF_D - 3, 4.5 do
		Build.part({
			Name = "Zebra",
			Size = Vector3.new(14, 0.07, 2.4),
			Position = Vector3.new(0, M.RoadTopY + 0.035, z),
			Color = Palette.LaneLine,
			CanCollide = false,
			CanQuery = false,
			Parent = lines,
		})
	end
	-- Red/white curbs along both road edges (decorative, the tiles do the collision).
	for _, sign in { -1, 1 } do
		for x = -HALF_L, HALF_L - 4, 4 do
			Build.part({
				Name = "Curb",
				Size = Vector3.new(4, 0.7, 1.2),
				Position = Vector3.new(x + 2, M.RoadTopY + 0.2, sign * (HALF_D - 0.6)),
				Color = if (x / 4) % 2 == 0 then Palette.CurbRed else Palette.CurbWhite,
				CanCollide = false,
				CanQuery = false,
				Parent = lines,
			})
		end
	end
end

local function buildSidewalks(arena: Model)
	local folder = Build.folder("Sidewalks", arena)
	for _, side in { "A", "B" } do
		local sign = if side == "A" then -1 else 1
		for row = 1, M.SidewalkRows do
			local z = sign * (HALF_D + (row - 0.5) * TILE_Z)
			for col = 1, M.SidewalkColumns do
				local x = -HALF_L + (col - 0.5) * TILE_X
				local base = if side == "A" then Palette.SidewalkA else Palette.SidewalkB
				local checker = (row + col) % 2 == 0
				local tile = Build.part({
					Name = `{side}_{row}_{col}`,
					Size = Vector3.new(TILE_X - 0.2, TILE_THICKNESS, TILE_Z - 0.2),
					Position = Vector3.new(x, M.SidewalkTopY - TILE_THICKNESS / 2, z),
					Color = if checker then base else base:Lerp(Color3.new(0, 0, 0), 0.06),
					Material = Enum.Material.SmoothPlastic,
					Parent = folder,
				})
				tile:SetAttribute("Side", side)
				tile:SetAttribute("Row", row)
				tile:SetAttribute("Col", col)
				tile:SetAttribute("BaseColor", tile.Color)
			end
		end
	end
end

local function buildWalls(arena: Model)
	local walls = Build.folder("Walls", arena)
	local depth = ROAD_DEPTH + 2 * M.SidewalkDepth
	for _, sign in { -1, 1 } do
		Build.part({
			Name = "EndWall",
			Size = Vector3.new(2, M.WallHeight, depth),
			Position = Vector3.new(sign * (HALF_L + 1), M.WallHeight / 2 - 10, 0),
			Transparency = 1,
			CanQuery = false,
			CastShadow = false,
			Parent = walls,
		})
	end
end

-- Decoration -------------------------------------------------------------------------------

-- A mountain with a tunnel mouth over the road at one end.
local function buildTunnel(decor: Instance, sign: number)
	local m = Build.model(if sign < 0 then "TunnelWest" else "TunnelEast", decor)
	local faceX = sign * (HALF_L + 2)
	local mouthH = 16
	-- Dark inside so cars appear out of the shadows.
	Build.part({
		Name = "Darkness",
		Size = Vector3.new(30, mouthH, ROAD_DEPTH + 2),
		Position = Vector3.new(faceX + sign * 16, mouthH / 2, 0),
		Color = Color3.fromRGB(16, 14, 22),
		Parent = m,
	})
	-- Stone arch frame.
	Build.part({
		Name = "Lintel",
		Size = Vector3.new(4, 4, ROAD_DEPTH + 8),
		Position = Vector3.new(faceX + sign * 1, mouthH + 2, 0),
		Color = Palette.Rock:Lerp(Color3.new(1, 1, 1), 0.15),
		Parent = m,
	})
	for _, zs in { -1, 1 } do
		Build.part({
			Name = "Pillar",
			Size = Vector3.new(4, mouthH + 4, 4),
			Position = Vector3.new(faceX + sign * 1, (mouthH + 4) / 2 - 2, zs * (HALF_D + 2)),
			Color = Palette.Rock:Lerp(Color3.new(1, 1, 1), 0.15),
			Parent = m,
		})
	end
	-- Mountain chunks around and above the mouth.
	for _ = 1, 26 do
		local z = Build.rng:NextNumber(-OUTER_Z - 10, OUTER_Z + 10)
		local y = Build.rng:NextNumber(mouthH + 2, mouthH + 40)
		if math.abs(z) > HALF_D + 4 then
			y = Build.rng:NextNumber(-6, mouthH + 34)
		end
		local size = Build.rng:NextNumber(14, 30)
		Props.rock(m, CFrame.new(faceX + sign * (size * 0.4 + Build.rng:NextNumber(0, 18)), y, z), size)
	end
	-- Grass and pines on top.
	for _ = 1, 8 do
		local z = Build.rng:NextNumber(-OUTER_Z, OUTER_Z)
		Props.pineTree(m, CFrame.new(faceX + sign * Build.rng:NextNumber(14, 34), mouthH + 30 + Build.rng:NextNumber(0, 10), z), Build.rng:NextNumber(16, 26))
	end
	-- Road continues into the tunnel.
	Build.part({
		Name = "TunnelRoad",
		Size = Vector3.new(30, 1, ROAD_DEPTH),
		Position = Vector3.new(faceX + sign * 16, M.RoadTopY - 0.5, 0),
		Color = Palette.AsphaltDark,
		Parent = m,
	})
	-- Hanging warning sign above the mouth.
	local sign_ = Build.part({
		Name = "Sign",
		Size = Vector3.new(0.6, 5, 22),
		Position = Vector3.new(faceX - sign * 0.6, mouthH + 7, 0),
		Color = Color3.fromRGB(255, 200, 40),
		Parent = m,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = if sign < 0 then Enum.NormalId.Right else Enum.NormalId.Left
	gui.PixelsPerStud = 30
	gui.Parent = sign_
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "⚠ CHICKEN CROSSING ⚠"
	label.Font = Enum.Font.LuckiestGuy
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(30, 25, 40)
	label.Parent = gui
end

local function islandDecor(kind: string): (Model, CFrame) -> ()
	return function(m: Model, top: CFrame)
		if kind == "barn" then
			Props.barn(m, top * CFrame.new(0, 0, 4) * CFrame.Angles(0, math.rad(200), 0), 0.9)
			Props.silo(m, top * CFrame.new(16, 0, 10), 26)
			Props.hayBale(m, top * CFrame.new(-14, 0, -8), true)
			Props.hayBale(m, top * CFrame.new(-10, 0, -14))
			Props.fence(m, (top * CFrame.new(-20, 0, -20)).Position, (top * CFrame.new(10, 0, -22)).Position)
		elseif kind == "windmill" then
			Props.windmill(m, top * CFrame.Angles(0, math.rad(180), 0), 34)
			Props.roundTree(m, top * CFrame.new(12, 0, 8), 14)
			Props.flowers(m, top * CFrame.new(-6, 0, 6), 7, 14)
		elseif kind == "house" then
			Props.farmhouse(m, top * CFrame.Angles(0, math.rad(170), 0))
			Props.roundTree(m, top * CFrame.new(-13, 0, 5), 15)
			Props.bush(m, top * CFrame.new(8, 0, -9), 4)
			Props.lamp(m, top * CFrame.new(-6, 0, -9))
		elseif kind == "forest" then
			for _ = 1, 6 do
				local off = CFrame.new(Build.rng:NextNumber(-12, 12), 0, Build.rng:NextNumber(-12, 12))
				if Build.rng:NextNumber() < 0.5 then
					Props.pineTree(m, top * off, Build.rng:NextNumber(14, 22))
				else
					Props.roundTree(m, top * off, Build.rng:NextNumber(12, 18))
				end
			end
			Props.rock(m, top * CFrame.new(6, 1, -10), 5)
		else
			Props.roundTree(m, top, 13)
			Props.bush(m, top * CFrame.new(5, 0, 4), 3.5)
			Props.flowers(m, top * CFrame.new(-4, 0, -3), 4, 8)
		end
	end
end

local function buildScenery(decor: Instance)
	local scenery = Build.folder("Scenery", decor)
	-- Rocky underside of the arena island.
	Props.islandUnderside(
		scenery,
		CFrame.new(0, -3.2, 0),
		Vector2.new(M.RoadLength + 20, OUTER_Z * 2 + 4),
		70
	)
	-- Grassy lips just outside the sidewalks (below their top, so they don't catch anyone).
	for _, sign in { -1, 1 } do
		Build.part({
			Name = "GrassLip",
			Size = Vector3.new(M.RoadLength + 24, 2, 3),
			Position = Vector3.new(0, -2.2, sign * (OUTER_Z + 1.5)),
			Color = Palette.Grass,
			Parent = scenery,
		})
		Build.part({
			Name = "DirtLip",
			Size = Vector3.new(M.RoadLength + 22, 4, 3),
			Position = Vector3.new(0, -5, sign * (OUTER_Z + 1)),
			Color = Palette.Dirt,
			Parent = scenery,
		})
		-- Lamps hanging off the outer edge, below walking height.
		for x = -HALF_L + 20, HALF_L - 20, 40 do
			Props.lamp(scenery, CFrame.new(x, -14, sign * (OUTER_Z + 3)) * CFrame.Angles(0, if sign > 0 then math.pi else 0, 0))
		end
	end

	-- Farm islands floating around the arena.
	type IslandSpec = { cf: CFrame, radius: number, kind: string }
	local islands: { IslandSpec } = {
		{ cf = CFrame.new(-150, -10, 175), radius = 26, kind = "barn" },
		{ cf = CFrame.new(170, 8, 160), radius = 18, kind = "windmill" },
		{ cf = CFrame.new(220, -30, -40), radius = 20, kind = "forest" },
		{ cf = CFrame.new(-235, 20, -30), radius = 18, kind = "house" },
		{ cf = CFrame.new(40, -45, 230), radius = 14, kind = "small" },
		{ cf = CFrame.new(-60, 35, -260), radius = 16, kind = "windmill" },
		{ cf = CFrame.new(140, 25, -230), radius = 22, kind = "barn" },
		{ cf = CFrame.new(-200, -40, -190), radius = 15, kind = "forest" },
		{ cf = CFrame.new(-280, 0, 120), radius = 12, kind = "small" },
		{ cf = CFrame.new(290, 15, 60), radius = 13, kind = "small" },
	}
	for i, info in islands do
		local cf = info.cf * CFrame.Angles(0, Build.rng:NextNumber(0, math.pi * 2), 0)
		local island = Props.floatingIsland(scenery, cf, info.radius, islandDecor(info.kind))
		island.Name = `Island{i}`
	end

	-- Clouds above and below.
	local clouds = Build.folder("Clouds", decor)
	for _ = 1, 26 do
		local angle = Build.rng:NextNumber(0, math.pi * 2)
		local dist = Build.rng:NextNumber(230, 450)
		local y = if Build.rng:NextNumber() < 0.5 then Build.rng:NextNumber(-120, -50) else Build.rng:NextNumber(60, 130)
		Props.cloud(clouds, CFrame.new(math.cos(angle) * dist, y, math.sin(angle) * dist), Build.rng:NextNumber(14, 30))
	end
	-- A thick cloud layer far below: where fallen chickens go.
	for _ = 1, 22 do
		Props.cloud(
			clouds,
			CFrame.new(Build.rng:NextNumber(-260, 260), Build.rng:NextNumber(-150, -120), Build.rng:NextNumber(-260, 260)),
			Build.rng:NextNumber(40, 70)
		)
	end
end

function WorldBuilder.buildArena(parent: Instance): Model
	Build.reseed(1001)
	local arena = Build.model("Arena")
	buildRoad(arena)
	buildSidewalks(arena)
	buildWalls(arena)
	local decor = Build.folder("Decor", arena)
	buildTunnel(decor, -1)
	buildTunnel(decor, 1)
	buildScenery(decor)
	Build.decorative(decor)
	arena.Parent = parent
	return arena
end

-- Lobby ------------------------------------------------------------------------------------

function WorldBuilder.buildLobby(parent: Instance): Model
	Build.reseed(2002)
	local lobby = Build.model("Lobby")
	local c, s = M.LobbyCenter, M.LobbySize
	local top = CFrame.new(c.X, c.Y + s.Y / 2, c.Z)

	-- Grass island with a wooden deck at the front that looks over the road.
	local ground = Build.folder("Ground", lobby)
	Build.part({ Name = "Grass", Size = Vector3.new(s.X, 2, s.Z), CFrame = top * CFrame.new(0, -1, 0), Color = Palette.Grass, Parent = ground })
	local deckDepth = 14
	Build.part({
		Name = "Deck",
		Size = Vector3.new(s.X - 10, 1, deckDepth),
		CFrame = top * CFrame.new(0, 0.5, s.Z / 2 + deckDepth / 2 - 2),
		Color = Palette.Wood,
		Parent = ground,
	})
	for x = -s.X / 2 + 7, s.X / 2 - 7, 4 do
		Build.part({
			Name = "Plank",
			Size = Vector3.new(0.2, 0.05, deckDepth),
			CFrame = top * CFrame.new(x, 1.03, s.Z / 2 + deckDepth / 2 - 2),
			Color = Palette.WoodDark,
			CanCollide = false,
			Parent = ground,
		})
	end
	local decor = Build.folder("Decor", lobby)
	Props.islandUnderside(decor, top * CFrame.new(0, -2, 0), Vector2.new(s.X, s.Z), 40)
	for _, x in { -s.X / 2 + 8, s.X / 2 - 8 } do
		Build.cylinder(top * CFrame.new(x, -6, s.Z / 2 + deckDepth - 4), 14, 1.5, { Color = Palette.WoodDark, Parent = decor })
	end

	-- Fences around the edge (solid) and invisible walls so nobody falls out.
	local hw, hd = s.X / 2, s.Z / 2
	local frontZ = hd + deckDepth - 2
	local fencePts = {
		{ Vector3.new(-hw + 1, 0, -hd + 1), Vector3.new(hw - 1, 0, -hd + 1) },
		{ Vector3.new(-hw + 1, 0, -hd + 1), Vector3.new(-hw + 1, 0, hd - 1) },
		{ Vector3.new(hw - 1, 0, -hd + 1), Vector3.new(hw - 1, 0, hd - 1) },
		{ Vector3.new(-hw + 5, 1, frontZ - 0.5), Vector3.new(hw - 5, 1, frontZ - 0.5) },
	}
	local fences = Build.folder("Fences", lobby)
	for _, pts in fencePts do
		Props.fence(fences, (top * CFrame.new(pts[1])).Position, (top * CFrame.new(pts[2])).Position, Palette.Trim)
	end
	local guards = Build.folder("Guards", lobby)
	local guardH = 40
	for _, g in {
		{ Vector3.new(s.X, guardH, 1), Vector3.new(0, guardH / 2, -hd) },
		{ Vector3.new(1, guardH, s.Z + deckDepth), Vector3.new(-hw, guardH / 2, deckDepth / 2) },
		{ Vector3.new(1, guardH, s.Z + deckDepth), Vector3.new(hw, guardH / 2, deckDepth / 2) },
		{ Vector3.new(s.X, guardH, 1), Vector3.new(0, guardH / 2, frontZ) },
	} do
		Build.part({
			Name = "Guard",
			Size = g[1],
			CFrame = top * CFrame.new(g[2]),
			Transparency = 1,
			CanQuery = false,
			CastShadow = false,
			Parent = guards,
		})
	end

	-- The coop: a little barn at the back.
	-- Scale 0.55 makes it ~15 deep; keep its front well behind the spawn nest.
	Props.barn(decor, top * CFrame.new(0, 0, -hd + 10) * CFrame.Angles(0, math.pi, 0), 0.55)

	-- Straw nest spawn with eggs.
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(14, 1, 14)
	spawn.CFrame = top * CFrame.new(0, 0.5, 4)
	spawn.Color = Palette.Straw
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = lobby
	for _, d in spawn:GetChildren() do
		if d:IsA("Decal") then
			d:Destroy()
		end
	end
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		Build.part({
			Name = "NestRim",
			Size = Vector3.new(4, 1.4, 1.6),
			CFrame = top * CFrame.new(math.cos(a) * 7.5, 1, 4 + math.sin(a) * 7.5) * CFrame.Angles(0, -a - math.pi / 2, 0),
			Color = Build.vary(Palette.Hay, 0.04),
			Parent = decor,
		})
	end

	-- A giant golden egg on a pedestal (it bobs and spins in game).
	local statue = Build.model("GoldenEgg", decor)
	Build.cylinder(top * CFrame.new(-28, 1.5, 4), 3, 9, { Color = Palette.Plaster, Parent = statue })
	local egg = Build.part({
		Name = "Egg",
		Size = Vector3.new(6, 8, 6),
		CFrame = top * CFrame.new(-28, 8, 4),
		Color = Color3.fromRGB(255, 200, 50),
		Material = Enum.Material.Foil,
		Parent = statue,
	})
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = egg
	local sparkle = Instance.new("Sparkles")
	sparkle.SparkleColor = Color3.fromRGB(255, 230, 120)
	sparkle.Parent = egg
	Build.tag(egg, "Bob")
	egg:SetAttribute("BobSpin", true)

	-- How-to-play board.
	local board = Build.model("HowToPlay", decor)
	-- The SurfaceGui is on the Front face (-Z), so look at the spawn.
	local boardCf = CFrame.lookAt((top * CFrame.new(30, 8.5, 6)).Position, (top * CFrame.new(0, 8.5, 4)).Position)
	for _, x in { -6.5, 6.5 } do
		Build.part({ Size = Vector3.new(0.6, 8, 0.6), CFrame = boardCf * CFrame.new(x, -4.5, 0.4), Color = Palette.WoodDark, Parent = board })
	end
	local face = Build.part({
		Name = "Board",
		Size = Vector3.new(14, 9, 0.6),
		CFrame = boardCf,
		Color = Palette.Wood,
		Parent = board,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.PixelsPerStud = 40
	gui.Parent = face
	local list = Instance.new("TextLabel")
	list.Size = UDim2.fromScale(1, 1)
	list.BackgroundTransparency = 1
	list.TextScaled = true
	list.Font = Enum.Font.FredokaOne
	list.TextColor3 = Color3.fromRGB(255, 250, 235)
	list.Text = "HOW TO PLAY\n\nCross the road!\nHold JUMP to glide\nClick to shoot eggs 🥚\nLast chicken alive wins"
	list.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(70, 45, 30)
	stroke.Parent = list
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.06, 0)
	pad.PaddingBottom = UDim.new(0.06, 0)
	pad.PaddingLeft = UDim.new(0.06, 0)
	pad.PaddingRight = UDim.new(0.06, 0)
	pad.Parent = list

	-- Hay, trees, flowers.
	for _, p in { Vector3.new(-36, 0, -10), Vector3.new(-31, 0, -14), Vector3.new(38, 0, -12) } do
		Props.hayBale(decor, top * CFrame.new(p) * CFrame.Angles(0, Build.rng:NextNumber(0, 3), 0), Build.rng:NextNumber() < 0.5)
	end
	Props.roundTree(decor, top * CFrame.new(-38, 0, -20), 16)
	Props.roundTree(decor, top * CFrame.new(38, 0, -20), 14)
	Props.pineTree(decor, top * CFrame.new(-20, 0, -22), 18)
	Props.flowers(decor, top * CFrame.new(16, 0, -8), 6, 18)
	Props.flowers(decor, top * CFrame.new(-16, 0, 12), 6, 14)
	Props.lamp(decor, top * CFrame.new(-hw + 6, 0, hd + 6))
	Props.lamp(decor, top * CFrame.new(hw - 6, 0, hd + 6))

	lobby.Parent = parent
	return lobby
end

return WorldBuilder
