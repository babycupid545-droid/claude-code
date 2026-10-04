--!strict
-- Draws the cars. Every client rebuilds the server's deterministic schedule and moves
-- local, anchored car models with it, so cars stay smooth at any speed.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Assets = require(Shared.Assets)
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local RoundState = require(Shared.RoundState)
local TrafficSchedule = require(Shared.TrafficSchedule)

local CameraFx = require(script.Parent.Parent.CameraFx)
local Sfx = require(script.Parent.Parent.Sfx)
local Ui = require(script.Parent.Parent.Ui)

local TrafficRenderer = {}

local T = Config.Traffic
local M = Config.Map

local CAR_COLORS = {
	Color3.fromRGB(230, 60, 50),
	Color3.fromRGB(40, 120, 230),
	Color3.fromRGB(250, 200, 40),
	Color3.fromRGB(60, 190, 90),
	Color3.fromRGB(240, 240, 240),
	Color3.fromRGB(40, 40, 45),
	Color3.fromRGB(250, 130, 30),
	Color3.fromRGB(150, 70, 200),
}

local schedule: TrafficSchedule.Schedule? = nil
local models: { [string]: Model } = {}
local folder: Folder
local warningLights: { [string]: Part } = {}
-- Per-car sound bookkeeping.
local engines: { [string]: Sound } = {}
local whooshed: { [string]: boolean } = {}
local announced: { [string]: boolean } = {}
local danger = 0

local function noCollide(model: Instance)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
end

-- Placeholder car: body, cabin, headlights. Pivot is the center; the front faces -Z.
local function makeDefaultCar(kind: number): Model
	local model = Instance.new("Model")
	local color = CAR_COLORS[(kind % #CAR_COLORS) + 1]
	local body = Ui.new("Part", {
		Name = "Body",
		Size = Vector3.new(T.CarWidth, T.CarHeight * 0.5, T.CarLength),
		CFrame = CFrame.new(0, -T.CarHeight * 0.2, 0),
		Color = color,
		Material = Enum.Material.SmoothPlastic,
		Parent = model,
	})
	Ui.new("Part", {
		Name = "Cabin",
		Size = Vector3.new(T.CarWidth * 0.85, T.CarHeight * 0.45, T.CarLength * 0.5),
		CFrame = CFrame.new(0, T.CarHeight * 0.27, T.CarLength * 0.08),
		Color = Color3.fromRGB(170, 210, 240),
		Material = Enum.Material.Glass,
		Transparency = 0.2,
		Parent = model,
	})
	for _, side in { -1, 1 } do
		Ui.new("Part", {
			Name = "Headlight",
			Size = Vector3.new(1.4, 0.8, 0.3),
			CFrame = CFrame.new(side * T.CarWidth * 0.33, -T.CarHeight * 0.15, -T.CarLength / 2),
			Color = Color3.fromRGB(255, 250, 200),
			Material = Enum.Material.Neon,
			Parent = model,
		})
	end
	model.PrimaryPart = body
	model.WorldPivot = CFrame.new()
	return model
end

-- A puff of exhaust (and road dust) streaming off the back; harvesters spit out straw.
local function addExhaust(model: Model, car: TrafficSchedule.Car)
	local length = car.length or T.CarLength
	local height = car.height or T.CarHeight
	local holder = Instance.new("Part")
	holder.Name = "FxHolder"
	holder.Transparency = 1
	holder.Size = Vector3.one * 0.2
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Anchored = true
	holder.CFrame = model:GetPivot() * CFrame.new(0, -height / 2 + 0.6, length / 2)
	holder.Parent = model
	local attachment = Instance.new("Attachment")
	attachment.Parent = holder
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "Exhaust"
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.EmissionDirection = Enum.NormalId.Back
	smoke.Rate = if car.vehicle == "Harvester" then 30 else 22
	smoke.Lifetime = NumberRange.new(0.5, 0.9)
	smoke.Speed = NumberRange.new(3, 6)
	smoke.SpreadAngle = Vector2.new(25, 25)
	smoke.Drag = 3
	smoke.Acceleration = Vector3.new(0, 4, 0)
	smoke.Rotation = NumberRange.new(0, 360)
	smoke.RotSpeed = NumberRange.new(-60, 60)
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 3.2) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	smoke.Color = ColorSequence.new(Color3.fromRGB(215, 210, 205), Color3.fromRGB(170, 165, 160))
	smoke.Parent = attachment
	if car.vehicle == "Harvester" then
		local straw = Instance.new("ParticleEmitter")
		straw.Name = "Straw"
		straw.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		straw.EmissionDirection = Enum.NormalId.Top
		straw.Rate = 60
		straw.Lifetime = NumberRange.new(0.8, 1.4)
		straw.Speed = NumberRange.new(10, 20)
		straw.SpreadAngle = Vector2.new(50, 50)
		straw.Acceleration = Vector3.new(0, -40, 0)
		straw.Rotation = NumberRange.new(0, 360)
		straw.RotSpeed = NumberRange.new(-300, 300)
		straw.Size = NumberSequence.new(0.6)
		straw.Color = ColorSequence.new(Color3.fromRGB(250, 214, 100), Color3.fromRGB(214, 160, 60))
		straw.LightEmission = 0.2
		straw.Parent = attachment
	end
	-- It's part of the model, so PivotTo carries it along with the car.
end

local function makeCar(car: TrafficSchedule.Car): Model
	local model: Model
	if car.vehicle == "Harvester" then
		local template = Assets.find("Cars", "Harvester")
		if template and template:IsA("Model") then
			model = template:Clone()
		else
			model = makeDefaultCar(3)
			model:ScaleTo(1.5)
		end
	elseif car.driver then
		local template = Assets.find("Cars", "RageCar")
		if template and template:IsA("Model") then
			model = template:Clone()
		else
			model = makeDefaultCar(0)
			local body = model:FindFirstChild("Body") :: Part
			body.Color = Color3.fromRGB(200, 20, 20)
			body.Material = Enum.Material.Neon
		end
		local driver = Players:GetPlayerByUserId(car.driver)
		local tag = Ui.new("BillboardGui", {
			Size = UDim2.fromOffset(160, 40),
			StudsOffset = Vector3.new(0, T.CarHeight, 0),
			AlwaysOnTop = true,
			Parent = model,
		})
		Ui.label(if driver then `{driver.DisplayName} 😡` else "😡", {
			Size = UDim2.fromScale(1, 1),
			TextColor3 = Color3.fromRGB(255, 90, 90),
			Parent = tag,
		})
	else
		local options = {}
		for _, item in Assets.list("Cars") do
			if item:IsA("Model") and item.Name ~= "RageCar" and item.Name ~= "Harvester" then
				table.insert(options, item)
			end
		end
		if #options > 0 then
			model = (options[(car.kind % #options) + 1] :: Model):Clone()
		else
			model = makeDefaultCar(car.kind)
		end
	end
	model.Name = car.id
	noCollide(model)
	addExhaust(model, car)
	model.Parent = folder
	local body = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if body then
		local engine = Sfx.loop("CarEngine", {
			parent = body,
			volume = if car.driver then 0.6 else 0.35,
			pitch = 0.7 + car.speed / 350,
			pitchJitter = 0.06,
		})
		if engine then
			engines[car.id] = engine
		end
	end
	return model
end

local function localRoot(): BasePart?
	local character = Players.LocalPlayer.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

-- Sounds and screen effects for cars near the local chicken.
local function carFeedback(s: TrafficSchedule.Schedule, t: number)
	local root = localRoot()
	danger = 0
	if not root then
		return
	end
	local p = root.Position
	for _, car in s:activeCars(t) do
		local x = s:carX(car, t)
		local laneZ = s:carZ(car)
		local dz = math.abs(laneZ - p.Z)
		-- Whoosh as it passes close by.
		if not whooshed[car.id] and dz < 22 and math.abs(x - p.X) < 16 and math.abs(p.Y - M.RoadTopY) < 40 then
			whooshed[car.id] = true
			Sfx.playAt("CarWhoosh", Vector3.new(x, M.RoadTopY + 3, laneZ), { pitch = 0.8 + car.speed / 400, pitchJitter = 0.05 })
			if dz < M.LaneWidth then
				CameraFx.shake(0.18)
				CameraFx.fovPunch(4)
			end
		end
		-- How soon will it reach me if I stay in this lane?
		if dz < (car.width or T.CarWidth) / 2 + 3 and p.Y < M.RoadTopY + (car.height or T.CarHeight) + 4 then
			local eta = (p.X - x) / (car.dir * car.speed)
			if eta > 0 and eta < 1.1 then
				danger = math.max(danger, 1 - eta / 1.1)
			end
		end
	end
	for _, car in s:incomingCars(t, T.WarningTime) do
		if not announced[car.id] then
			announced[car.id] = true
			local laneZ = s:carZ(car)
			local entry = Vector3.new(-car.dir * M.RoadLength / 2, M.RoadTopY + 4, laneZ)
			if car.vehicle == "Harvester" then
				Sfx.playAt("Alarm", entry)
				Sfx.playAt("RageHorn", entry, { pitch = 0.6 })
			elseif car.driver then
				Sfx.playAt("RageHorn", entry)
			elseif math.abs(laneZ - p.Z) < M.LaneWidth / 2 + 2 and math.abs(p.Y - M.RoadTopY) < 15 then
				Sfx.play("LaneWarning")
				if math.random() < 0.35 then
					Sfx.playAt("CarHorn", entry, { pitchJitter = 0.15 })
				end
			end
		end
	end
end

-- 0..1: how close a car is to hitting the local chicken (for the red screen edges).
function TrafficRenderer.danger(): number
	return danger
end

local function laneLightKey(lane: number, dir: number): string
	return `{lane}:{dir}`
end

local function buildWarningLights(s: TrafficSchedule.Schedule)
	for _, light in warningLights do
		light:Destroy()
	end
	table.clear(warningLights)
	for lane, spec in s.params.lanes do
		-- The light sits on the tunnel the lane's cars come out of. Each road is two-way, so
		-- every tunnel mouth has lights over half its lanes.
		local x = -spec.dir * (M.RoadLength / 2 - 0.4)
		warningLights[laneLightKey(lane, spec.dir)] = Ui.new("Part", {
			Name = "LaneWarning",
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Size = Vector3.new(0.4, 2.5, M.LaneWidth * 0.6),
			Position = Vector3.new(x, M.RoadTopY + 8, spec.z),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(60, 20, 20),
			Parent = folder,
		})
	end
	-- Big flashing lights over the median barn gates for the harvester.
	for _, dir in { 1, -1 } do
		warningLights[laneLightKey(0, dir)] = Ui.new("Part", {
			Name = "HarvesterWarning",
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Size = Vector3.new(1, 3, Config.Map.MedianWidth * 0.8),
			Position = Vector3.new(-dir * (M.RoadLength / 2 + 5), M.RoadTopY + 17, 0),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(60, 20, 20),
			Parent = folder,
		})
	end
end

local function clear()
	for _, model in models do
		model:Destroy()
	end
	table.clear(models)
	table.clear(engines)
	table.clear(whooshed)
	table.clear(announced)
	danger = 0
	for _, light in warningLights do
		light:Destroy()
	end
	table.clear(warningLights)
	schedule = nil
end

local function onParamsChanged()
	clear()
	local json = RoundState:GetAttribute("TrafficParams")
	if type(json) ~= "string" or json == "" then
		return
	end
	local ok, params = pcall(HttpService.JSONDecode, HttpService, json)
	if not ok then
		warn("Bad traffic params", params)
		return
	end
	local s = TrafficSchedule.new(params :: TrafficSchedule.Params)
	schedule = s
	buildWarningLights(s)
end

local function render()
	local s = schedule
	if not s then
		return
	end
	local t = workspace:GetServerTimeNow()
	s:update(t)

	local seen: { [string]: boolean } = {}
	for _, car in s:activeCars(t) do
		seen[car.id] = true
		local model = models[car.id]
		if not model then
			model = makeCar(car)
			models[car.id] = model
		end
		local pos = Vector3.new(s:carX(car, t), M.RoadTopY + (car.height or T.CarHeight) / 2, s:carZ(car))
		model:PivotTo(CFrame.lookAt(pos, pos + Vector3.new(car.dir, 0, 0)))
	end
	for id, model in models do
		if not seen[id] then
			model:Destroy()
			models[id] = nil
			engines[id] = nil
			whooshed[id] = nil
			announced[id] = nil
		end
	end
	carFeedback(s, t)

	local lit: { [string]: boolean } = {}
	for _, car in s:incomingCars(t, T.WarningTime) do
		lit[laneLightKey(car.lane, car.dir)] = true
	end
	for _, car in s:incomingCars(t, Config.Median.HarvesterWarning) do
		if car.vehicle == "Harvester" then
			lit[laneLightKey(0, car.dir)] = true
		end
	end
	local blink = math.floor(os.clock() * 8) % 2 == 0
	for key, light in warningLights do
		light.Color = if lit[key] and blink then Color3.fromRGB(255, 40, 30) else Color3.fromRGB(60, 20, 20)
	end
end

function TrafficRenderer.start()
	folder = Instance.new("Folder")
	folder.Name = "Traffic"
	folder.Parent = workspace

	RoundState:GetAttributeChangedSignal("TrafficParams"):Connect(onParamsChanged)
	onParamsChanged()

	Remotes.RageCar.OnClientEvent:Connect(function(car: TrafficSchedule.Car)
		if schedule then
			schedule:addCar(car)
		end
	end)

	RunService:BindToRenderStep("Traffic", Enum.RenderPriority.First.Value, render)
end

return TrafficRenderer
