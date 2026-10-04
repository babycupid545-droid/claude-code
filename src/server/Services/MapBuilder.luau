--!strict
-- Finds the arena and lobby you built in Studio (see docs/STUDIO_SETUP.md). If they don't
-- exist yet, builds them at runtime with the same builders so the game always works.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Builders = ReplicatedStorage:WaitForChild("Builders")

local MapBuilder = {}

local function warnMissing(what: string)
	warn(
		`[Map] Workspace.{what} not found, building it at runtime. Run the build command in Studio `
			.. "to get an editable copy (docs/STUDIO_SETUP.md)."
	)
end

function MapBuilder.arena(): Model
	local arena = workspace:FindFirstChild("Arena")
	if arena and arena:IsA("Model") then
		return arena
	end
	warnMissing("Arena")
	return require(Builders:WaitForChild("WorldBuilder")).buildArena(workspace)
end

function MapBuilder.lobby(): Model
	local lobby = workspace:FindFirstChild("Lobby")
	if lobby and lobby:IsA("Model") then
		return lobby
	end
	warnMissing("Lobby")
	return require(Builders:WaitForChild("WorldBuilder")).buildLobby(workspace)
end

function MapBuilder.lighting()
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		require(Builders:WaitForChild("LightingBuilder")).build()
	end
end

function MapBuilder.cars()
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local cars = assets and assets:FindFirstChild("Cars")
	if cars and #cars:GetChildren() > 0 then
		return
	end
	if not assets then
		assets = Instance.new("Folder")
		assets.Name = "Assets"
		assets.Parent = ReplicatedStorage
	end
	local folder = Instance.new("Folder")
	folder.Name = "Cars"
	require(Builders:WaitForChild("CarBuilder")).build(folder)
	folder.Parent = assets
end

-- Everyone must spawn in the lobby, so switch off any other spawn in the place.
function MapBuilder.prepare(): (Model, Model)
	MapBuilder.lighting()
	MapBuilder.cars()
	local arena = MapBuilder.arena()
	local lobby = MapBuilder.lobby()
	local spawn = lobby:FindFirstChild("LobbySpawn")
	for _, d in workspace:GetDescendants() do
		if d:IsA("SpawnLocation") and d ~= spawn then
			d.Enabled = false
		end
	end
	if workspace:FindFirstChild("Baseplate") then
		warn("Delete Workspace.Baseplate: chickens must be able to fall off the sidewalks.")
	end
	return arena, lobby
end

return MapBuilder
