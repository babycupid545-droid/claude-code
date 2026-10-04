--!strict
-- Client-side world animation:
--   * sidewalk tiles shake and flash before they drop, tumble away, and rise back up
--     (driven by the server's "State" attribute on each tile)
--   * things tagged in Studio: "Spin" (windmill blades), "Bob" (floating islands, the
--     golden egg), "Drift" (clouds)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CameraFx = require(script.Parent.Parent.CameraFx)
local Sfx = require(script.Parent.Parent.Sfx)

local WorldAnimator = {}

local WARN_COLOR = Color3.fromRGB(255, 70, 50)

type TileInfo = {
	home: CFrame,
	base: Color3,
	state: string,
	shaking: boolean,
}

local tileInfo: { [BasePart]: TileInfo } = {}
local lastAlarm = 0
local lastCrumble = 0
local debrisThisFrame = 0

local function nearLocalPlayer(part: BasePart, radius: number): boolean
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root ~= nil and (root.Position - part.Position).Magnitude < radius
end

-- One dust emitter, moved to each crumbling tile and burst there.
local dustPart: Part? = nil
local dustEmitter: ParticleEmitter? = nil

local function crumbleDust(position: Vector3, size: Vector3)
	if not dustPart or not dustPart.Parent then
		local p = Instance.new("Part")
		p.Name = "CrumbleDust"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Transparency = 1
		p.Parent = workspace
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/smoke_main.dds"
		e.Shape = Enum.ParticleEmitterShape.Box
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		e.Color = ColorSequence.new(Color3.fromRGB(225, 214, 196), Color3.fromRGB(170, 150, 130))
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 5) })
		e.Lifetime = NumberRange.new(0.8, 1.4)
		e.Speed = NumberRange.new(2, 6)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Drag = 2
		e.Acceleration = Vector3.new(0, 2, 0)
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-40, 40)
		e.Rate = 0
		e.Parent = p
		dustPart, dustEmitter = p, e
	end
	local p = dustPart :: Part
	p.Size = size
	p.CFrame = CFrame.new(position)
	local emitter = dustEmitter :: ParticleEmitter
	emitter:Emit(3)
end

-- A few chunks of pavement that tumble away (only near the local player, a few per frame).
local function debris(tile: BasePart)
	if debrisThisFrame >= 6 or not nearLocalPlayer(tile, 140) then
		return
	end
	debrisThisFrame += 1
	for _ = 1, 2 do
		local chunk = Instance.new("Part")
		chunk.Name = "Debris"
		chunk.Size = Vector3.new(1, 0.6, 1) * (0.8 + math.random() * 1.2)
		chunk.Color = tile.Color:Lerp(Color3.new(0, 0, 0), math.random() * 0.25)
		chunk.Material = tile.Material
		chunk.CanCollide = false
		chunk.CanQuery = false
		chunk.CanTouch = false
		chunk.CastShadow = false
		chunk.CFrame = tile.CFrame * CFrame.new((math.random() - 0.5) * tile.Size.X, 0, (math.random() - 0.5) * tile.Size.Z)
		chunk.AssemblyLinearVelocity = Vector3.new((math.random() - 0.5) * 16, 6 + math.random() * 10, (math.random() - 0.5) * 16)
		chunk.AssemblyAngularVelocity = Vector3.new(math.random() * 10, math.random() * 10, math.random() * 10)
		chunk.Parent = workspace
		task.delay(2.5, function()
			chunk:Destroy()
		end)
	end
end


local function setTileState(tile: BasePart, info: TileInfo, state: string)
	if state == info.state then
		return
	end
	info.state = state
	if state == "Warn" then
		info.shaking = true
		if os.clock() - lastAlarm > 1 then
			lastAlarm = os.clock()
			Sfx.play("Alarm")
		end
	elseif state == "Down" or state == "Gone" then
		info.shaking = false
		if os.clock() - lastCrumble > 0.4 then
			lastCrumble = os.clock()
			Sfx.playAt("Crumble", tile.Position)
			if nearLocalPlayer(tile, 60) then
				CameraFx.shake(0.35)
			end
		end
		crumbleDust(tile.Position, tile.Size)
		debris(tile)
		local spin = CFrame.Angles(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)
		TweenService:Create(tile, TweenInfo.new(1.1 + math.random() * 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			CFrame = info.home * CFrame.new(0, -45, 0) * spin,
			Transparency = 1,
		}):Play()
	else -- Solid
		info.shaking = false
		tile.CFrame = info.home * CFrame.new(0, -20, 0)
		tile.Color = info.base
		TweenService:Create(tile, TweenInfo.new(0.7, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			CFrame = info.home,
			Transparency = 0,
		}):Play()
	end
end

local function watchTile(tile: Instance)
	if not tile:IsA("BasePart") or tile:GetAttribute("Side") == nil then
		return
	end
	local base = tile:GetAttribute("BaseColor")
	local info: TileInfo = {
		home = tile.CFrame,
		base = if typeof(base) == "Color3" then base else tile.Color,
		state = "Solid",
		shaking = false,
	}
	tileInfo[tile] = info
	local function update()
		local state = tile:GetAttribute("State")
		setTileState(tile, info, if type(state) == "string" then state else "Solid")
	end
	tile:GetAttributeChangedSignal("State"):Connect(update)
	update()
end

local function watchArena(arena: Instance)
	local sidewalks = arena:WaitForChild("Sidewalks", 30)
	if not sidewalks then
		return
	end
	for _, tile in sidewalks:GetChildren() do
		watchTile(tile)
	end
	sidewalks.ChildAdded:Connect(watchTile)
end

-- Ambient motion for tagged models ----------------------------------------------------------

type Ambient = { inst: Instance, home: CFrame, phase: number }
local spins: { Ambient } = {}
local bobs: { Ambient } = {}
local drifts: { Ambient } = {}

local function pivotOf(inst: Instance): CFrame?
	if inst:IsA("Model") then
		return inst:GetPivot()
	elseif inst:IsA("BasePart") then
		return inst.CFrame
	end
	return nil
end

local function setPivot(inst: Instance, cf: CFrame)
	if inst:IsA("Model") then
		inst:PivotTo(cf)
	elseif inst:IsA("BasePart") then
		inst.CFrame = cf
	end
end

local function track(list: { Ambient }, inst: Instance)
	local home = pivotOf(inst)
	if home then
		table.insert(list, { inst = inst, home = home, phase = math.random() * math.pi * 2 })
	end
end

local function step(dt: number)
	local t = os.clock()
	debrisThisFrame = 0
	for tile, info in tileInfo do
		if info.shaking and tile.Parent then
			local flash = math.sin(t * 18) > 0
			tile.Color = if flash then WARN_COLOR else info.base
			tile.CFrame = info.home * CFrame.new((math.random() - 0.5) * 0.25, (math.random() - 0.5) * 0.15, (math.random() - 0.5) * 0.25)
		end
	end
	for _, a in spins do
		local speed = a.inst:GetAttribute("SpinSpeed")
		setPivot(a.inst, a.home * CFrame.Angles(0, 0, t * (if type(speed) == "number" then speed else 1)))
	end
	for _, a in bobs do
		local offset = CFrame.new(0, math.sin(t * 0.8 + a.phase) * 1.2, 0)
		if a.inst:GetAttribute("BobSpin") then
			offset *= CFrame.Angles(0, t * 0.8, 0)
		end
		setPivot(a.inst, a.home * offset)
	end
	for _, a in drifts do
		-- Slow back-and-forth drift (no teleporting when wrapping).
		setPivot(a.inst, a.home * CFrame.new(math.sin(t * 0.03 + a.phase) * 45, math.sin(t * 0.2 + a.phase) * 1.5, 0))
	end
end

function WorldAnimator.start()
	task.spawn(function()
		watchArena(workspace:WaitForChild("Arena"))
	end)
	local lists: { [string]: { Ambient } } = { Spin = spins, Bob = bobs, Drift = drifts }
	for tag, list in lists do
		for _, inst in CollectionService:GetTagged(tag) do
			track(list, inst)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(inst)
			track(list, inst)
		end)
	end
	RunService.Heartbeat:Connect(step)
end

return WorldAnimator
