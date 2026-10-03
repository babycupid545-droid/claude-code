--!strict
-- Road Rage: once squashed you get a top-down view of the road, pick a lane, and send a
-- car down it from either end.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local RoundState = require(Shared.RoundState)

local Ui = require(script.Parent.Parent.Ui)

local DriverController = {}

local player = Players.LocalPlayer
local M = Config.Map

local active = false
local lane = math.ceil(M.LaneCount / 2)
local lastLaunch = 0
local gui: ScreenGui
local cooldownLabel: TextLabel
local laneMarker: Part? = nil

local function laneZ(index: number): number
	return -M.LaneCount * M.LaneWidth / 2 + (index - 0.5) * M.LaneWidth
end

local function updateMarker()
	if laneMarker then
		laneMarker.Position = Vector3.new(0, M.RoadTopY + 0.2, laneZ(lane))
	end
end

local function changeLane(delta: number)
	lane = math.clamp(lane + delta, 1, M.LaneCount)
	updateMarker()
end

local function launch(dir: number)
	if os.clock() - lastLaunch < Config.RoadRage.Cooldown then
		return
	end
	lastLaunch = os.clock()
	Remotes.LaunchRageCar:FireServer(lane, dir)
end

local function onAction(name: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	if name == "DriverUp" then
		changeLane(-1)
	elseif name == "DriverDown" then
		changeLane(1)
	elseif name == "DriverLeft" then
		launch(-1)
	elseif name == "DriverRight" then
		launch(1)
	end
	return Enum.ContextActionResult.Sink
end

local function shouldBeActive(): boolean
	return player:GetAttribute("Driver") == true and RoundState:GetAttribute("State") == "InRound"
end

local function setActive(on: boolean)
	if on == active then
		return
	end
	active = on
	gui.Enabled = on
	local camera = workspace.CurrentCamera
	if on then
		camera.CameraType = Enum.CameraType.Scriptable
		-- Looking towards -Z from above: screen-right is +X, screen-up is lane 1.
		camera.CFrame = CFrame.lookAt(Vector3.new(0, 170, 95), Vector3.new(0, 0, 0))
		laneMarker = Ui.new("Part", {
			Name = "DriverLane",
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Size = Vector3.new(M.RoadLength, 0.2, M.LaneWidth),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(255, 60, 60),
			Transparency = 0.7,
			Parent = workspace,
		})
		updateMarker()
		ContextActionService:BindAction("DriverUp", onAction, false, Enum.KeyCode.W, Enum.KeyCode.Up, Enum.KeyCode.DPadUp)
		ContextActionService:BindAction("DriverDown", onAction, false, Enum.KeyCode.S, Enum.KeyCode.Down, Enum.KeyCode.DPadDown)
		ContextActionService:BindAction("DriverLeft", onAction, false, Enum.KeyCode.A, Enum.KeyCode.Left, Enum.KeyCode.ButtonX)
		ContextActionService:BindAction("DriverRight", onAction, false, Enum.KeyCode.D, Enum.KeyCode.Right, Enum.KeyCode.ButtonB)
	else
		camera.CameraType = Enum.CameraType.Custom
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
		if laneMarker then
			laneMarker:Destroy()
			laneMarker = nil
		end
		for _, name in { "DriverUp", "DriverDown", "DriverLeft", "DriverRight" } do
			ContextActionService:UnbindAction(name)
		end
	end
end

local function buildGui()
	gui = Ui.new("ScreenGui", {
		Name = "DriverGui",
		ResetOnSpawn = false,
		Enabled = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local panel = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(340, 150),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local function btn(text: string, pos: UDim2, onClick: () -> ())
		local b = Ui.button(text, {
			Size = UDim2.fromOffset(100, 56),
			Position = pos,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Parent = panel,
		})
		b.Activated:Connect(onClick)
	end
	btn("▲", UDim2.new(0.5, 0, 0, 30), function()
		changeLane(-1)
	end)
	btn("▼", UDim2.new(0.5, 0, 0, 92), function()
		changeLane(1)
	end)
	btn("◀ GO", UDim2.new(0, 50, 0, 60), function()
		launch(-1)
	end)
	btn("GO ▶", UDim2.new(1, -50, 0, 60), function()
		launch(1)
	end)
	cooldownLabel = Ui.label("", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -170),
		Size = UDim2.fromOffset(400, 34),
		Parent = gui,
	})
end

function DriverController.start()
	buildGui()
	local function refresh()
		setActive(shouldBeActive())
	end
	player:GetAttributeChangedSignal("Driver"):Connect(refresh)
	RoundState:GetAttributeChangedSignal("State"):Connect(refresh)
	refresh()
	-- The default camera scripts reset the camera on respawn; take it back.
	player.CharacterAdded:Connect(function()
		if active then
			task.defer(function()
				if active then
					workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
					workspace.CurrentCamera.CFrame = CFrame.lookAt(Vector3.new(0, 170, 95), Vector3.new(0, 0, 0))
				end
			end)
		end
	end)

	RunService.RenderStepped:Connect(function()
		if not active then
			return
		end
		local left = Config.RoadRage.Cooldown - (os.clock() - lastLaunch)
		cooldownLabel.Text = if left > 0
			then string.format("Reloading car... %.1f", left)
			else "DRIVER: pick a lane (W/S) and send a car (A/D)"
	end)
end

return DriverController
