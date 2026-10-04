--!strict
-- Road Rage: once squashed you get a top-down view of the road, pick a lane, and send a
-- car down it from either end.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Layout = require(Shared.Layout)
local Remotes = require(Shared.Remotes)
local RoundState = require(Shared.RoundState)

local Anim = require(script.Parent.Parent.Anim)
local Gui = require(script.Parent.Parent.Gui)
local Sfx = require(script.Parent.Parent.Sfx)
local Ui = require(script.Parent.Parent.Ui)

local DriverController = {}

local player = Players.LocalPlayer
local M = Config.Map

local active = false
local lane = 1
local lastLaunch = 0
local gui: ScreenGui
local cooldownFill: Frame
local hint: TextLabel
local laneMarker: Part? = nil

local function laneZ(index: number): number
	return Layout.lanes[index].z
end

local function updateMarker()
	if laneMarker then
		laneMarker.Position = Vector3.new(0, M.RoadTopY + 0.2, laneZ(lane))
	end
end

local function changeLane(delta: number)
	lane = math.clamp(lane + delta, 1, #Layout.lanes)
	Sfx.play("UiClick", { pitch = 1 + lane * 0.05 })
	updateMarker()
end

local function launch(dir: number)
	if os.clock() - lastLaunch < Config.RoadRage.Cooldown then
		Sfx.play("Error")
		return
	end
	lastLaunch = os.clock()
	Remotes.LaunchRageCar:FireServer(lane)
	Sfx.play("RageHorn")
	if laneMarker then
		laneMarker.Transparency = 0.2
		Anim.tween(laneMarker, 0.6, { Transparency = 0.7 })
	end
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
		camera.CFrame = CFrame.lookAt(Vector3.new(0, 230, 130), Vector3.new(0, 0, 0))
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

local function bindGui()
	gui = Gui.screen("Driver")
	Anim.autoJuice(gui)
	local controls = Gui.find(gui, "Controls")
	controls.Up.Activated:Connect(function()
		changeLane(-1)
	end)
	controls.Down.Activated:Connect(function()
		changeLane(1)
	end)
	controls.Left.Activated:Connect(function()
		launch(-1)
	end)
	controls.Right.Activated:Connect(function()
		launch(1)
	end)
	cooldownFill = Gui.find(gui, "Controls/Cooldown/Fill")
	hint = Gui.find(gui, "Controls/Cooldown/Hint")
end

function DriverController.start()
	bindGui()
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
					workspace.CurrentCamera.CFrame = CFrame.lookAt(Vector3.new(0, 230, 130), Vector3.new(0, 0, 0))
				end
			end)
		end
	end)

	RunService.RenderStepped:Connect(function()
		if not active then
			return
		end
		local left = Config.RoadRage.Cooldown - (os.clock() - lastLaunch)
		local ready = left <= 0
		cooldownFill.Size = UDim2.fromScale(math.clamp(1 - left / Config.RoadRage.Cooldown, 0, 1), 1)
		cooldownFill.BackgroundColor3 = if ready then Color3.fromRGB(110, 230, 120) else Color3.fromRGB(255, 201, 60)
		hint.Text = if ready then `LANE {lane} - READY!` else string.format("RELOADING %.1f", left)
	end)
end

return DriverController
