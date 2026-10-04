--!strict
-- Gets the ScreenGuis built in Studio (StarterGui > Hud, Shop, Emotes, Driver). If one was
-- never built, it's created at runtime with the same builder so the game still works.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Gui = {}

local player = Players.LocalPlayer
local cache: { [string]: ScreenGui } = {}

function Gui.screen(name: string): ScreenGui
	local cached = cache[name]
	if cached and cached.Parent then
		return cached
	end
	local playerGui = player:WaitForChild("PlayerGui")
	local screen: Instance?
	if StarterGui:FindFirstChild(name) then
		-- Copied into PlayerGui when the first character spawns.
		screen = playerGui:WaitForChild(name)
	else
		screen = playerGui:FindFirstChild(name)
		if not screen then
			warn(`[Gui] StarterGui.{name} not found, building it at runtime (run the build command in Studio)`)
			local builder = require(ReplicatedStorage:WaitForChild("Builders"):WaitForChild("GuiBuilder")) :: any
			builder.build(playerGui, name)
			screen = playerGui:WaitForChild(name)
		end
	end
	cache[name] = screen :: ScreenGui
	return screen :: ScreenGui
end

-- Finds a descendant by a slash path, e.g. Gui.find(hud, "Top/Status/Row/Title").
function Gui.find(root: Instance, path: string): any
	local node: Instance = root
	for part in path:gmatch("[^/]+") do
		node = node:WaitForChild(part, 10) :: Instance
		if not node then
			error(`[Gui] missing {root.Name}/{path} - rebuild the GUI or check names`)
		end
	end
	return node
end

-- Clones a template from a screen's Templates folder.
function Gui.template(screen: Instance, name: string): any
	local folder = screen:WaitForChild("Templates")
	local clone: any = folder:WaitForChild(name):Clone()
	clone.Visible = true
	return clone
end

return Gui
