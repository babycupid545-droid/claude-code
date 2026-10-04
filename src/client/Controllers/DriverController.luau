--!strict
-- Road Rage: once squashed you get a top-down view of the road, pick a lane, and send a
-- car down it. The car drives the way that lane's traffic goes (each road is two-way), so
-- the lane marker shows arrows for the direction.

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
local markerArrows: { Part } = {}

local ARROW_XS = { -120, -60, 0, 60, 120 }

local function updateMarker()
	local marker = laneMarker
	if not marker then
		return
	end
	local spec = Layout.lanes[lane]
	marker.Position = Vector3.new(0, M.RoadTopY + 0.2, spec.z)
	-- Chevrons (two arms each) pointing the way cars drive in this lane.
	for i, arm in markerArrows do
		local x = ARROW_XS[math.ceil(i / 2)]
		local side = if i % 2 == 0 then 1 else -1
		arm.CFrame = CFrame.new(x, M.RoadTopY + 0.35, spec.z)
			* CFrame.Angles(0, (if spec.dir > 0 then 0 else math.pi) + side * math.rad(40), 0)
			* CFrame.new(-2.6, 0, 0)
	end
end

local function changeLane(delta: number)
	lane = math.clamp(lane + delta, 1, #Layout.lanes)
	Sfx.play("UiClick", { pitch = 1 + lane * 0.05 })
	updateMarker()
end

local function launch()
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
	elseif name == "DriverLeft" or name == "DriverRight" then
		launch()
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
		for _ = 1, #ARROW_XS * 2 do
			table.insert(
				markerArrows,
				Ui.new("Part", {
					Name = "Arrow",
					Anchored = true,
					CanCollide = false,
					CanQuery = false,
					CanTouch = false,
					Size = Vector3.new(6, 0.2, 1.2),
					Material = Enum.Material.Neon,
					Color = Color3.fromRGB(255, 240, 230),
					Transparency = 0.2,
					Parent = laneMarker,
				})
			)
		end
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
		table.clear(markerArrows)
		for _, name in { "DriverUp", "DriverDown", "DriverLeft", "DriverRight" } do
			ContextActionService:UnbindAction(name)
		end
	end
end

local function bindGui()
	gui = Gui.screen("Driver")
	Anim.autoJuice(gui)
	local controls = Gui.find(gui, "Root/Controls")
	controls.Up.Activated:Connect(function()
		changeLane(-1)
	end)
	controls.Down.Activated:Connect(function()
		changeLane(1)
	end)
	controls.Left.Activated:Connect(launch)
	controls.Right.Activated:Connect(launch)
	cooldownFill = Gui.find(gui, "Root/Controls/Cooldown/Fill")
	hint = Gui.find(gui, "Root/Controls/Cooldown/Hint")
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
		-- The camera looks towards -Z, so +X is screen-right.
		local arrow = if Layout.lanes[lane].dir > 0 then "→" else "←"
		hint.Text = if ready then `LANE {lane} {arrow} READY!` else string.format("RELOADING %.1f", left)
	end)
end

return DriverController
