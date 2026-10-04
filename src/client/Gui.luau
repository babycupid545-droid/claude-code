--!strict
-- Gets the ScreenGuis built in Studio (StarterGui > Hud, Shop, Emotes, Driver). If one was
-- never built, or was built by an older version of the game, a fresh copy is built at runtime
-- with the same builder so the game still works.
--
-- Every screen is designed at 1280x720 inside a "Root" frame; Gui.screen scales Root to fit
-- the real screen (a bit larger on touch devices so buttons stay easy to hit).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Gui = {}

local player = Players.LocalPlayer
local cache: { [string]: ScreenGui } = {}
local DESIGN = Vector2.new(1280, 720)

local function builder(): any
	return require(ReplicatedStorage:WaitForChild("Builders"):WaitForChild("GuiBuilder")) :: any
end

function Gui.isTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

-- How much to scale the 1280x720 design for this screen.
function Gui.fitScale(): number
	local camera = workspace.CurrentCamera
	local size = if camera then camera.ViewportSize else DESIGN
	if Gui.isTouch() then
		return math.clamp(math.min(size.X / 1100, size.Y / 560), 0.45, 1.4)
	end
	return math.clamp(math.min(size.X / DESIGN.X, size.Y / DESIGN.Y), 0.5, 1.6)
end

local fitted: { [ScreenGui]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function fit(screen: ScreenGui)
	local root = screen:FindFirstChild("Root")
	local scale = root and root:FindFirstChild("Fit")
	if not root or not root:IsA("GuiObject") or not scale or not scale:IsA("UIScale") then
		return
	end
	local function apply()
		local s = Gui.fitScale()
		scale.Scale = s
		-- Root is made 1/s of the screen so that, once scaled, it covers it exactly.
		root.Size = UDim2.fromScale(1 / s, 1 / s)
	end
	apply()
	if not fitted[screen] then
		fitted[screen] = true
		local camera = workspace.CurrentCamera
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(apply)
		end
	end
end

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
	end
	local version = if screen then screen:GetAttribute("GuiVersion") else nil
	if not screen or type(version) ~= "number" or version < builder().Version then
		if screen then
			warn(`[Gui] StarterGui.{name} is from an older version, using a fresh one (run the build command in Studio to update it)`)
			screen:Destroy()
		else
			warn(`[Gui] StarterGui.{name} not found, building it at runtime (run the build command in Studio)`)
		end
		builder().build(playerGui, name)
		screen = playerGui:WaitForChild(name)
	end
	local gui = screen :: ScreenGui
	fit(gui)
	cache[name] = gui
	return gui
end

-- Finds a descendant by a slash path, e.g. Gui.find(hud, "Root/RoundCard/Inner/Title").
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

-- Sets a Kit.button's label, accent colour and icon (nil leaves that part as it is).
function Gui.setButton(button: any, text: string?, color: Color3?, sprite: string?)
	local inner = button:FindFirstChild("Border") and button.Border:FindFirstChild("Inner")
	if not inner then
		return
	end
	local content = inner:FindFirstChild("Content")
	local label = content and content:FindFirstChild("Label")
	if label and text then
		label.Text = text
	end
	if color then
		inner.BackgroundColor3 = color
		inner.BackgroundTransparency = 0
		inner:SetAttribute("Accent", color)
	end
	-- sprite "" hides the icon.
	local icon = content and content:FindFirstChild("Icon")
	if icon and sprite then
		icon.Visible = sprite ~= ""
		if sprite ~= "" then
			icon:SetAttribute("Sprite", sprite)
		end
	end
end

return Gui
