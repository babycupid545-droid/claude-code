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

local function nearLocalPlayer(part: BasePart, radius: number): boolean
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root ~= nil and (root.Position - part.Position).Magnitude < radius
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
