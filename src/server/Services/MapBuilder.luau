--!strict
-- Builds the greybox arena (road, walls) and the lobby balcony in code, so the game runs
-- with zero art. Decorations from ServerStorage.Assets.ArenaDecor / LobbyDecor are cloned in
-- on top when they exist (see docs/ASSETS.md).

local ServerStorage = game:GetService("ServerStorage")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local MapBuilder = {}

local M = Config.Map
local ROAD_DEPTH = M.LaneCount * M.LaneWidth

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(p :: any)[key] = value
	end
	return p
end

local function cloneDecor(name: string, parent: Instance)
	local assets = ServerStorage:FindFirstChild("Assets")
	local decor = assets and assets:FindFirstChild(name)
	if decor then
		decor:Clone().Parent = parent
	end
end

function MapBuilder.roadDepth(): number
	return ROAD_DEPTH
end

function MapBuilder.buildArena(): Model
	local arena = Instance.new("Model")
	arena.Name = "Arena"

	-- One asphalt slab per lane so lanes read clearly.
	for i = 1, M.LaneCount do
		local z = -ROAD_DEPTH / 2 + (i - 0.5) * M.LaneWidth
		part({
			Name = `Lane{i}`,
			Size = Vector3.new(M.RoadLength, 4, M.LaneWidth),
			Position = Vector3.new(0, M.RoadTopY - 2, z),
			Color = Color3.fromRGB(52, 54, 60),
			Material = Enum.Material.Asphalt,
			Parent = arena,
		})
		-- Dashed lane line on the edge between lanes.
		if i < M.LaneCount then
			local lineZ = z + M.LaneWidth / 2
			local isMiddle = i == M.LaneCount / 2
			if isMiddle then
				part({
					Name = "CenterLine",
					Size = Vector3.new(M.RoadLength, 0.05, 0.8),
					Position = Vector3.new(0, M.RoadTopY + 0.025, lineZ),
					Color = Color3.fromRGB(255, 200, 40),
					CanCollide = false,
					CanQuery = false,
					Parent = arena,
				})
			else
				local dash, step = 8, 16
				for x = -M.RoadLength / 2 + dash / 2, M.RoadLength / 2, step do
					part({
						Name = "LaneDash",
						Size = Vector3.new(dash, 0.05, 0.5),
						Position = Vector3.new(x, M.RoadTopY + 0.025, lineZ),
						Color = Color3.fromRGB(235, 235, 235),
						CanCollide = false,
						CanQuery = false,
						Parent = arena,
					})
				end
			end
		end
	end

	-- Invisible walls at both ends of the road so chickens can't run off along it. Cars are
	-- client-only and don't collide, so they drive straight through.
	local totalDepth = ROAD_DEPTH + 2 * M.SidewalkDepth
	for _, sign in { -1, 1 } do
		part({
			Name = "EndWall",
			Size = Vector3.new(2, M.WallHeight, totalDepth),
			Position = Vector3.new(sign * (M.RoadLength / 2 + 1), M.WallHeight / 2 - 10, 0),
			Transparency = 1,
			CanQuery = false,
			Parent = arena,
		})
		-- Tunnel mouths so cars appear from somewhere.
		part({
			Name = "Tunnel",
			Size = Vector3.new(6, 14, ROAD_DEPTH + 6),
			Position = Vector3.new(sign * (M.RoadLength / 2 + 3), M.RoadTopY + 10, 0),
			Color = Color3.fromRGB(90, 80, 70),
			Material = Enum.Material.Brick,
			CanCollide = false,
			CanQuery = false,
			Parent = arena,
		})
	end

	cloneDecor("ArenaDecor", arena)
	arena.Parent = workspace
	return arena
end

function MapBuilder.buildLobby(): (Model, SpawnLocation)
	local lobby = Instance.new("Model")
	lobby.Name = "Lobby"
	local c, s = M.LobbyCenter, M.LobbySize

	part({
		Name = "Floor",
		Size = s,
		Position = c,
		Color = Color3.fromRGB(240, 220, 160),
		Material = Enum.Material.Wood,
		Parent = lobby,
	})
	-- Glass walls; the wall facing the road is low so the lobby doubles as a viewing balcony.
	local wallH = 14
	local walls = {
		{ Vector3.new(s.X, wallH, 1), Vector3.new(0, wallH / 2, -s.Z / 2) },
		{ Vector3.new(s.X, 4, 1), Vector3.new(0, 2, s.Z / 2) },
		{ Vector3.new(1, wallH, s.Z), Vector3.new(-s.X / 2, wallH / 2, 0) },
		{ Vector3.new(1, wallH, s.Z), Vector3.new(s.X / 2, wallH / 2, 0) },
	}
	for _, w in walls do
		part({
			Name = "Glass",
			Size = w[1],
			Position = c + w[2],
			Transparency = 0.6,
			Material = Enum.Material.Glass,
			Color = Color3.fromRGB(180, 220, 255),
			Parent = lobby,
		})
	end
	-- Invisible tall wall on the balcony side so nobody jumps out of the lobby.
	part({
		Name = "BalconyGuard",
		Size = Vector3.new(s.X, 30, 1),
		Position = c + Vector3.new(0, 15, s.Z / 2),
		Transparency = 1,
		CanQuery = false,
		Parent = lobby,
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.Position = c + Vector3.new(0, 1, -s.Z / 4)
	spawn.Color = Color3.fromRGB(255, 170, 60)
	spawn.Parent = lobby

	cloneDecor("LobbyDecor", lobby)
	lobby.Parent = workspace

	-- Everyone must spawn in the lobby, so switch off any other spawn in the place.
	for _, d in workspace:GetDescendants() do
		if d:IsA("SpawnLocation") and d ~= spawn then
			d.Enabled = false
		end
	end
	if workspace:FindFirstChild("Baseplate") then
		warn("Delete Workspace.Baseplate: chickens must be able to fall off the sidewalks.")
	end
	return lobby, spawn
end

return MapBuilder
