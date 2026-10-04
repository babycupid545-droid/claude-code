--!strict
-- Power-up and bounty visuals, drawn on every client:
--   * pickups: an icon above each one, a ring on the road and a soft light column so they read
--     from across the road (the glowing orb itself is the server's, bobbed by WorldAnimator)
--   * on chickens: shield bubble, speed trail, glowing butt (mega egg), feather sparkles,
--     orbiting eggs for loaded special eggs, green goo while stuck, and the bounty crown
--   * special egg looks and splats, shield pops, stolen eggs, bounty fanfare
-- Everything follows the player attributes listed in Shared/Powerups.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Powerups = require(Shared.Powerups)
local Remotes = require(Shared.Remotes)

local CameraFx = require(script.Parent.Parent.CameraFx)
local Effects = require(script.Parent.Parent.Effects)
local Sfx = require(script.Parent.Parent.Sfx)
local Ui = require(script.Parent.Parent.Ui)

local PowerupFx = {}

local player = Players.LocalPlayer
local GOLD = Color3.fromRGB(255, 205, 60)
local DARK = Color3.fromRGB(44, 29, 20)

local folder: Folder -- client-only parts
local billboards: Folder -- in PlayerGui, so Sprites fills in the icons

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = folder
	return p
end

local function burst(position: Vector3, color: Color3, count: number, size: number, speed: number?)
	local holder = part({ Transparency = 1, Size = Vector3.one, Position = position })
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(color, Color3.new(1, 1, 1):Lerp(color, 0.5))
	e.LightEmission = 0.6
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
	e.Lifetime = NumberRange.new(0.4, 0.9)
	e.Speed = NumberRange.new((speed or 20) * 0.5, speed or 20)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, -30, 0)
	e.Drag = 2
	e.Enabled = false
	e.Parent = holder
	e:Emit(count)
	Debris:AddItem(holder, 2)
end

-- A flat ring that grows and fades (explosions, pickups, shield pops).
local function shockwave(position: Vector3, color: Color3, radius: number)
	local ring = part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 2, 2),
		CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Transparency = 0.2,
	})
	TweenService:Create(ring, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.3, radius * 2, radius * 2),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 0.5)
end

local function localRoot(): BasePart?
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

local function near(position: Vector3, range: number): boolean
	local root = localRoot()
	return root ~= nil and (root.Position - position).Magnitude < range
end

local function billboard(name: string, adornee: Instance, size: UDim2, offset: Vector3): BillboardGui
	return Ui.new("BillboardGui", {
		Name = name,
		Adornee = adornee,
		Size = size,
		StudsOffset = offset,
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = 260,
		ResetOnSpawn = false,
		Parent = billboards,
	})
end

local function icon(sprite: string, size: number, tint: Color3?, props: { [string]: any }?): ImageLabel
	local image = Ui.new("ImageLabel", {
		Name = "Icon",
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.fromOffset(size, size),
		ImageColor3 = tint or Color3.new(1, 1, 1),
	})
	image:SetAttribute("Sprite", sprite)
	if props then
		for k, v in props do
			(image :: any)[k] = v
		end
	end
	return image
end

-- Pickups ------------------------------------------------------------------------------------------

type PickupLook = { ring: Part, column: Part, gui: BillboardGui, base: Vector3, phase: number }
local pickupLooks: { [Model]: PickupLook } = {}

local function decoratePickup(model: Instance)
	if not model:IsA("Model") or pickupLooks[model] then
		return
	end
	local def = Powerups.get(model:GetAttribute("Powerup"))
	local core = model:WaitForChild("Core", 5)
	if not def or not core or not core:IsA("BasePart") or not model.Parent then
		return
	end
	local ground = Vector3.new(core.Position.X, Config.Map.RoadTopY + 0.12, core.Position.Z)
	local ring = part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.15, 7, 7),
		CFrame = CFrame.new(ground) * CFrame.Angles(0, 0, math.rad(90)),
		Color = def.color,
		Transparency = 0.45,
	})
	local column = part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(16, 1.4, 1.4),
		CFrame = CFrame.new(ground + Vector3.new(0, 8, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = def.color,
		Transparency = 0.75,
	})
	local gui = billboard("Pickup", core, UDim2.fromOffset(120, 84), Vector3.new(0, 3.4, 0))
	local badge = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(52, 52),
		BackgroundColor3 = DARK,
		BackgroundTransparency = 0.15,
		Parent = gui,
	}, {
		Ui.new("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Ui.new("UIStroke", { Color = def.color, Thickness = 3 }),
	})
	icon(def.sprite, 36, def.tint, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Parent = badge })
	Ui.label(def.name, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.new(1, 0, 0, 22),
		TextScaled = false,
		TextSize = 15,
		TextColor3 = def.color,
		Parent = gui,
	})
	pickupLooks[model] = { ring = ring, column = column, gui = gui, base = ground, phase = math.random() * 6 }
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) then
			local look = pickupLooks[model]
			pickupLooks[model] = nil
			if look then
				look.ring:Destroy()
				look.column:Destroy()
				look.gui:Destroy()
			end
		end
	end)
end

local function watchPickups(f: Instance)
	for _, child in f:GetChildren() do
		task.spawn(decoratePickup, child)
	end
	f.ChildAdded:Connect(function(child)
		task.spawn(decoratePickup, child)
	end)
end

local function stepPickups()
	local t = os.clock()
	for _, look in pickupLooks do
		local pulse = 0.5 + 0.5 * math.sin(t * 4 + look.phase)
		local d = 6 + pulse * 2
		look.ring.Size = Vector3.new(0.15, d, d)
		look.ring.Transparency = 0.35 + pulse * 0.3
	end
end

-- Chickens -----------------------------------------------------------------------------------------

-- Visuals on one chicken, by key ("Shield", "Speed", ...). Each key owns a few instances.
type ChickenLook = { character: Model?, items: { [string]: { Instance } } }
local chickenLooks: { [Player]: ChickenLook } = {}

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function attachment(root: BasePart, position: Vector3): Attachment
	local a = Instance.new("Attachment")
	a.Name = "PowerupFx"
	a.Position = position
	a.Parent = root
	return a
end

local function makeShield(): { Instance }
	local bubble = part({
		Name = "ShieldBubble",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 7.5,
		Color = Color3.fromRGB(120, 210, 255),
		Material = Enum.Material.ForceField,
	})
	return { bubble }
end

local function makeSpeed(root: BasePart): { Instance }
	local a0 = attachment(root, Vector3.new(0, 0.9, 0.6))
	local a1 = attachment(root, Vector3.new(0, -1, 0.6))
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 236, 120), Color3.fromRGB(255, 160, 40))
	trail.LightEmission = 0.8
	trail.Lifetime = 0.35
	trail.Transparency = NumberSequence.new(0.25, 1)
	trail.Parent = root
	return { trail, a0, a1 }
end

local function makeMega(): { Instance }
	local glow = part({ Name = "MegaButt", Shape = Enum.PartType.Ball, Size = Vector3.one, Color = Color3.fromRGB(255, 150, 50) })
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 150, 50)
	light.Range = 9
	light.Brightness = 2.5
	light.Parent = glow
	return { glow }
end

local function makeFeather(root: BasePart): { Instance }
	local a = attachment(root, Vector3.new(0, 0.5, 0))
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 230, 255))
	e.LightEmission = 0.8
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	e.Lifetime = NumberRange.new(0.6, 1.1)
	e.Speed = NumberRange.new(2, 5)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, -3, 0)
	e.Rate = 22
	e.Parent = a
	return { a }
end

local function makeSpecial(def: Powerups.Def): { Instance }
	local items: { Instance } = {}
	for i = 1, Config.Powerups.SpecialAmmo do
		local egg = part({ Name = `SpecialEgg{i}`, Size = Vector3.new(0.6, 0.6, 0.6), Color = def.color })
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Scale = Vector3.new(1, 1.3, 1)
		mesh.Parent = egg
		table.insert(items, egg)
	end
	return items
end

local function makeStuck(character: Model, root: BasePart): { Instance }
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.fromRGB(110, 230, 80)
	highlight.FillTransparency = 0.45
	highlight.OutlineColor = Color3.fromRGB(40, 120, 30)
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Adornee = character
	highlight.Parent = character
	local a = attachment(root, Vector3.new(0, 0.6, 0))
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(Color3.fromRGB(120, 235, 90), Color3.fromRGB(60, 160, 40))
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0.1) })
	e.Lifetime = NumberRange.new(0.5, 0.9)
	e.Speed = NumberRange.new(0.5, 2)
	e.SpreadAngle = Vector2.new(60, 60)
	e.EmissionDirection = Enum.NormalId.Bottom
	e.Acceleration = Vector3.new(0, -25, 0)
	e.Rate = 30
	e.Parent = a
	return { highlight, a }
end

local function makeCrown(character: Model, root: BasePart): { Instance }
	local head = character:FindFirstChild("Head")
	local adornee = if head and head:IsA("BasePart") then head else root
	local gui = billboard("BountyCrown", adornee, UDim2.fromOffset(110, 74), Vector3.new(0, if adornee == root then 4.6 else 3, 0))
	local crown = icon("crown", 42, nil, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Parent = gui })
	crown.Name = "Crown"
	local tag = Ui.new("Frame", {
		Name = "Tag",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = DARK,
		BackgroundTransparency = 0.1,
		Parent = gui,
	}, {
		Ui.new("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Ui.new("UIStroke", { Color = GOLD, Thickness = 2 }),
		Ui.new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
		Ui.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	icon("eggCoin", 18, nil, { LayoutOrder = 1, Parent = tag })
	Ui.label("0", {
		Name = "Amount",
		LayoutOrder = 2,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 22),
		TextScaled = false,
		TextSize = 16,
		TextColor3 = GOLD,
		Parent = tag,
	})
	-- A golden glow and sparkles so the leader stands out in the crowd.
	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = GOLD
	sparkles.Parent = root
	local light = Instance.new("PointLight")
	light.Color = GOLD
	light.Range = 10
	light.Brightness = 1.5
	light.Parent = root
	return { gui, sparkles, light }
end

local function destroyItems(items: { Instance })
	for _, inst in items do
		inst:Destroy()
	end
end

-- What a chicken should be wearing right now, as key -> maker.
local function wanted(p: Player, character: Model, root: BasePart): { [string]: () -> { Instance } }
	local want: { [string]: () -> { Instance } } = {}
	local power = p:GetAttribute("Powerup")
	if power == "Shield" then
		want.Shield = makeShield
	elseif power == "Speed" then
		want.Speed = function()
			return makeSpeed(root)
		end
	elseif power == "MegaEgg" then
		want.MegaEgg = makeMega
	elseif power == "Feather" then
		want.Feather = function()
			return makeFeather(root)
		end
	end
	local def = Powerups.get(p:GetAttribute("SpecialEgg"))
	local ammo = p:GetAttribute("SpecialAmmo")
	if def and type(ammo) == "number" and ammo > 0 then
		want["Special:" .. def.id] = function()
			return makeSpecial(def)
		end
	end
	local stuck = p:GetAttribute("StuckUntil")
	if type(stuck) == "number" and stuck > serverNow() then
		want.Stuck = function()
			return makeStuck(character, root)
		end
	end
	if type(p:GetAttribute("Bounty")) == "number" then
		want.Crown = function()
			return makeCrown(character, root)
		end
	end
	return want
end

-- Moves the anchored visuals along with the chicken.
local function place(p: Player, key: string, items: { Instance }, root: BasePart, t: number)
	local cf = root.CFrame
	if key == "Shield" then
		local bubble = items[1] :: BasePart
		bubble.CFrame = cf
		bubble.Transparency = 0.15 + 0.15 * math.sin(t * 5)
	elseif key == "MegaEgg" then
		local glow = items[1] :: BasePart
		local s = 1 + 0.35 * math.sin(t * 9)
		glow.Size = Vector3.one * s
		glow.CFrame = cf * CFrame.new(0, 0.3, 1.4)
	elseif key:sub(1, 8) == "Special:" then
		local ammo = p:GetAttribute("SpecialAmmo")
		local count = if type(ammo) == "number" then ammo else 0
		for i, item in items do
			local egg = item :: BasePart
			local angle = t * 2.5 + (i - 1) * (math.pi * 2 / #items)
			egg.CFrame = CFrame.new(root.Position + Vector3.new(math.cos(angle) * 2.4, 0.6, math.sin(angle) * 2.4))
				* CFrame.Angles(0, -angle, 0)
			egg.Transparency = if i <= count then 0 else 1
		end
	elseif key == "Crown" then
		local gui = items[1] :: BillboardGui
		local crown = gui:FindFirstChild("Crown")
		if crown and crown:IsA("GuiObject") then
			crown.Rotation = 8 * math.sin(t * 3)
		end
		local tag = gui:FindFirstChild("Tag")
		local amount = tag and tag:FindFirstChild("Amount")
		local bounty = p:GetAttribute("Bounty")
		if amount and amount:IsA("TextLabel") and type(bounty) == "number" then
			amount.Text = tostring(bounty)
		end
	end
end

local function stepChickens()
	local t = os.clock()
	for _, p in Players:GetPlayers() do
		local look: ChickenLook? = chickenLooks[p]
		local character = p.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local alive = root ~= nil and humanoid ~= nil and humanoid.Health > 0
		if look and look.character ~= character then
			-- New chicken (respawned): start over.
			for _, items in look.items do
				destroyItems(items)
			end
			look = nil
			chickenLooks[p] = nil
		end
		if not alive or not character or not root then
			if look then
				for _, items in look.items do
					destroyItems(items)
				end
				table.clear(look.items)
			end
			continue
		end
		local l: ChickenLook = look or { character = character, items = {} }
		chickenLooks[p] = l
		local want = wanted(p, character, root)
		for key, items in l.items do
			if not want[key] then
				destroyItems(items)
				l.items[key] = nil
			end
		end
		for key, make in want do
			local items = l.items[key]
			if not items then
				items = make()
				l.items[key] = items
			end
			place(p, key, items, root, t)
		end
	end
end

-- Eggs -------------------------------------------------------------------------------------------

-- Makes a fired egg look mega and/or special.
function PowerupFx.decorateEgg(model: Instance, mega: boolean?, special: string?)
	local main: BasePart? = if model:IsA("BasePart")
		then model
		elseif model:IsA("Model") then (model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true))
		else nil
	if mega then
		local scale = Config.Powerups.MegaEggScale
		if model:IsA("Model") then
			model:ScaleTo(model:GetScale() * scale)
		elseif model:IsA("BasePart") then
			model.Size *= scale
		end
	end
	local def = Powerups.get(special)
	if not main or not (def or mega) then
		return
	end
	local color = if def then def.color else Color3.fromRGB(255, 150, 50)
	if def and model:IsA("BasePart") then
		model.Color = def.color
		model.Material = Enum.Material.Neon
	end
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = if mega then 12 else 8
	light.Brightness = 3
	light.Parent = main
	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = color
	sparkles.Parent = main
end

-- Extra splat for special eggs ("Bounce" = a bouncy egg ricocheting).
function PowerupFx.eggSplat(position: Vector3, special: string)
	if special == "Bounce" then
		burst(position, Color3.fromRGB(255, 110, 200), 12, 0.5, 14)
		Sfx.playAt("Boing", position, { pitch = 1.3, pitchJitter = 0.1 })
		return
	end
	local def = Powerups.get(special)
	if not def then
		return
	end
	if special == "Explosive" then
		local radius = Config.Powerups.ExplosiveRadius
		local explosion = Instance.new("Explosion")
		explosion.Position = position
		explosion.BlastRadius = radius
		explosion.BlastPressure = 0
		explosion.DestroyJointRadiusPercent = 0
		explosion.Parent = folder
		burst(position, def.color, 40, 1.2, 40)
		shockwave(position, Color3.fromRGB(255, 170, 60), radius)
		Sfx.playAt("Firework", position, { pitch = 0.7 })
		Sfx.playAt("Crumble", position, { pitch = 1.4, volume = 0.6 })
		if near(position, radius * 2.5) then
			CameraFx.shake(0.6)
		end
	elseif special == "Sticky" then
		burst(position, def.color, 26, 0.8, 16)
		Sfx.playAt("Plop", position, { pitch = 0.8 })
	elseif special == "Golden" then
		burst(position, def.color, 24, 0.6, 22)
		Sfx.playAt("Coin", position, { pitch = 1.1 })
	else
		burst(position, def.color, 16, 0.5)
	end
end

-- Server events ------------------------------------------------------------------------------------

local function onFx(fx: string, position: Vector3, userId: number, detail: string)
	local mine = userId == player.UserId
	if fx == "Pickup" then
		local def = Powerups.get(detail)
		local color = if def then def.color else GOLD
		burst(position, color, 30, 0.7, 26)
		shockwave(position - Vector3.new(0, 1.8, 0), color, 8)
		if not mine then
			Sfx.playAt("Sparkle", position)
		end
	elseif fx == "ShieldPop" then
		burst(position, Color3.fromRGB(150, 220, 255), 40, 0.8, 34)
		shockwave(position, Color3.fromRGB(150, 220, 255), 9)
		Sfx.playAt("Boing", position, { pitch = 0.8 })
		Sfx.playAt("Crumble", position, { pitch = 2, volume = 0.5 })
		if mine then
			CameraFx.shake(0.7)
			CameraFx.fovPunch(8)
		end
	elseif fx == "Steal" then
		burst(position + Vector3.new(0, 2, 0), GOLD, 26, 0.6, 24)
		Effects.floatText(position + Vector3.new(0, 3, 0), `-{detail}`, GOLD)
		Sfx.playAt("Coin", position, { pitch = 0.9 })
	elseif fx == "Bounty" then
		burst(position + Vector3.new(0, 4, 0), GOLD, 30, 0.6, 18)
		Sfx.play("Knockout", { pitch = 1.25, volume = 0.6 })
	elseif fx == "BountyClaimed" then
		Effects.winAt(position, "GoldenRain")
		Sfx.play(if mine then "Fanfare" else "Knockout", { volume = 0.6 })
		if mine then
			CameraFx.fovPunch(10)
		end
	end
end

function PowerupFx.start()
	local f = Instance.new("Folder")
	f.Name = "PowerupFx"
	f.Parent = workspace
	folder = f
	local b = Instance.new("Folder")
	b.Name = "PowerupBillboards"
	b.Parent = player:WaitForChild("PlayerGui")
	billboards = b

	local existing = workspace:FindFirstChild("Powerups")
	if existing then
		watchPickups(existing)
	end
	workspace.ChildAdded:Connect(function(child: Instance)
		if child.Name == "Powerups" and child:IsA("Folder") then
			watchPickups(child)
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		local look = chickenLooks[p]
		chickenLooks[p] = nil
		if look then
			for _, items in look.items do
				destroyItems(items)
			end
		end
	end)
	Remotes.PowerupFx.OnClientEvent:Connect(onFx)
	RunService.RenderStepped:Connect(function()
		stepPickups()
		stepChickens()
	end)
end

return PowerupFx
