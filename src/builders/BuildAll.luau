--!strict
-- Builds the whole game world and UI into Studio as real, editable objects.
--
-- Run it from the Studio command bar (View > Command Bar), in Edit mode (not Play):
--
--   local b=game.ReplicatedStorage.Builders:Clone() b.Parent=game.ServerStorage local ok,e=pcall(require(b.BuildAll)) b:Destroy() print(ok and "Built!" or e)
--
-- It only builds what's missing, so your edits are safe. To rebuild something, delete it
-- first (e.g. Workspace.Arena, StarterGui.Hud, ReplicatedStorage.Assets.Cars or one chicken in
-- ReplicatedStorage.Assets.Chickens) and run it again.
-- Ctrl+Z undoes a whole build.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local CarBuilder = require(script.Parent.CarBuilder)
local ChickenBuilder = require(script.Parent.ChickenBuilder)
local GuiBuilder = require(script.Parent.GuiBuilder)
local LightingBuilder = require(script.Parent.LightingBuilder)
local WorldBuilder = require(script.Parent.WorldBuilder)

local function childFolder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function assetsFolder(name: string): Folder
	return childFolder(childFolder(ReplicatedStorage, "Assets"), name)
end

return function()
	local recording = nil
	pcall(function()
		recording = ChangeHistoryService:TryBeginRecording("Build Chicken Crossing")
	end)

	local built = {}
	local function step(label: string, exists: boolean, fn: () -> ())
		if exists then
			print(`[Build] {label}: already exists, skipped (delete it to rebuild)`)
			return
		end
		fn()
		table.insert(built, label)
	end

	LightingBuilder.build()
	table.insert(built, "Lighting")

	-- Old placeholder pieces from earlier versions get in the way.
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
		print("[Build] Removed Workspace.Baseplate (chickens need to be able to fall)")
	end
	for _, d in workspace:GetChildren() do
		if d:IsA("SpawnLocation") then
			d:Destroy()
			print("[Build] Removed the default SpawnLocation (everyone spawns in the lobby)")
		end
	end

	step("Arena", workspace:FindFirstChild("Arena") ~= nil, function()
		WorldBuilder.buildArena(workspace)
	end)
	step("Lobby", workspace:FindFirstChild("Lobby") ~= nil, function()
		WorldBuilder.buildLobby(workspace)
	end)
	local cars = assetsFolder("Cars")
	step("Cars", #cars:GetChildren() > 0 and not CarBuilder.needsUpgrade(cars), function()
		CarBuilder.build(cars)
	end)
	-- One chicken per skin; builds any that are missing.
	local chickens = assetsFolder("Chickens")
	if ChickenBuilder.buildAll(chickens) > 0 then
		table.insert(built, "Chickens")
	else
		print("[Build] Chickens: already exist, skipped (delete one to rebuild it)")
	end
	for _, name in GuiBuilder.Names do
		step(`GUI {name}`, StarterGui:FindFirstChild(name) ~= nil, function()
			GuiBuilder.build(StarterGui, name)
		end)
	end

	pcall(function()
		if recording then
			ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
		end
	end)
	print(`[Build] Done: {table.concat(built, ", ")}`)
end
