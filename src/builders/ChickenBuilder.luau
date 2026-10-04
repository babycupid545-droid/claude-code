--!strict
-- Builds a cartoon chicken character for every chicken skin, saved to
-- ReplicatedStorage.Assets.Chickens/<SkinId>. Players spawn as these.
--
-- With the Blender meshes imported (assets/models/Chicken.glb, see docs/STUDIO_SETUP.md) the
-- chicken is the smooth sculpted model, recoloured per skin. Without them, it's made of
-- smooth ellipsoids (Parts with a sphere SpecialMesh): a plump body with a fluffy chest, big round head, shiny eyes, blushing cheeks, beak, comb and wattle,
-- layered wings, a fanned tail, feathery thighs and orange legs with toes.
--
-- Rig: HumanoidRootPart -Root-> Body; Body -Neck-> Head, -LeftWing/-RightWing-> wings,
-- -LeftHip/-RightHip-> legs, -Tail-> tail. Every joint is a Motor6D, animated in code on
-- each client (src/client/Controllers/ChickenAnimator.luau), so no animation uploads needed.
-- The chicken faces -Z and stands with its feet at the model's base.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Cosmetics"))
local Meshes = require(script.Parent.Meshes)

local ChickenBuilder = {}

-- Bump when the chicken model changes so already-built rigs get rebuilt.
ChickenBuilder.RigVersion = 3

local HIP_HEIGHT = 1.3
local ROOT_SIZE = Vector3.new(2.2, 2, 2.2)
local ROOT_Y = HIP_HEIGHT + ROOT_SIZE.Y / 2

local BLACK = Color3.fromRGB(28, 22, 34)
local WHITE = Color3.fromRGB(255, 255, 255)
local BLUSH = Color3.fromRGB(255, 140, 160)
local DEFAULT_BEAK = Color3.fromRGB(255, 166, 40)

type Look = {
	main: Color3,
	belly: Color3,
	wing: Color3,
	wingTip: Color3,
	tail: Color3,
	head: Color3,
	beak: Color3,
	comb: Color3?,
	material: Enum.Material,
	rainbow: { Color3 }?,
	style: string, -- "Chicken" | "Duck" | "Robo"
	sparkles: boolean,
}

local function lookFor(skin: Cosmetics.Item): Look
	local l = skin.look
	local colors = l.colors or { WHITE }
	local main = colors[1]
	local h, s, v = main:ToHSV()
	-- Dark skins get a lighter chest; light skins a warm cream one.
	local belly = if v < 0.35
		then main:Lerp(WHITE, 0.25)
		elseif s < 0.15 then Color3.fromRGB(255, 244, 222)
		else main:Lerp(WHITE, 0.4)
	local wing = colors[2] or Color3.fromHSV(h, math.min(1, s * 1.05), v * 0.9)
	return {
		main = main,
		belly = belly,
		wing = wing,
		wingTip = wing:Lerp(BLACK, 0.18),
		tail = colors[2] or main:Lerp(BLACK, 0.12),
		head = main,
		beak = l.beak or DEFAULT_BEAK,
		comb = l.comb,
		material = l.material or Enum.Material.SmoothPlastic,
		rainbow = if #colors > 2 then colors else nil,
		style = if skin.id == "RubberDuck" then "Duck" elseif skin.id == "Robo" then "Robo" else "Chicken",
		sparkles = l.sparkles == true,
	}
end

-- Parts ------------------------------------------------------------------------------------

local function basePart(name: string, size: Vector3, cf: CFrame, color: Color3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanTouch = false
	p.Massless = true
	p.Anchored = false
	p.CastShadow = true
	p.Parent = parent
	return p
end

-- A smooth ellipsoid.
local function ell(name: string, size: Vector3, cf: CFrame, color: Color3, parent: Instance): Part
	local p = basePart(name, size, cf, color, parent)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

local function weld(to: BasePart, part: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = to
	w.Part1 = part
	w.Parent = part
end

local function motor(name: string, part0: BasePart, part1: BasePart, joint: CFrame)
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = part0
	m.Part1 = part1
	m.C0 = part0.CFrame:Inverse() * joint
	m.C1 = part1.CFrame:Inverse() * joint
	m.Parent = part1
end

local function addBill(model: Model, head: BasePart, center: CFrame, look: Look)
	weld(head, ell("Bill", Vector3.new(1.15, 0.34, 1.15), center * CFrame.new(0, -0.18, -1.3) * CFrame.Angles(math.rad(-6), 0, 0), look.beak, model))
	weld(head, ell("BillLower", Vector3.new(1.0, 0.24, 0.95), center * CFrame.new(0, -0.36, -1.18), look.beak:Lerp(BLACK, 0.12), model))
end

local function addAntenna(model: Model, head: BasePart, center: CFrame)
	local stalk = basePart("Antenna", Vector3.new(0.12, 1.1, 0.12), center * CFrame.new(0.45, 1.45, 0.2) * CFrame.Angles(0, 0, math.rad(-12)), Color3.fromRGB(90, 96, 110), model)
	stalk.Material = Enum.Material.Metal
	weld(head, stalk)
	local bulb = ell("AntennaTip", Vector3.new(0.34, 0.34, 0.34), center * CFrame.new(0.57, 2.0, 0.2), Color3.fromRGB(255, 70, 70), model)
	bulb.Material = Enum.Material.Neon
	weld(head, bulb)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 70, 70)
	light.Range = 6
	light.Brightness = 1.5
	light.Parent = bulb
end

-- Body parts ---------------------------------------------------------------------------------

local function buildHead(model: Model, body: BasePart, look: Look): BasePart
	local center = CFrame.new(0, 4.05, -0.75)
	local head = ell("Head", Vector3.new(2.25, 2.2, 2.2), center, look.head, model)
	-- A little tuft of feathers on the back of the head.
	weld(head, ell("HeadFluff", Vector3.new(1.3, 1.1, 1.0), center * CFrame.new(0, 0.55, 0.75) * CFrame.Angles(-0.5, 0, 0), look.head, model))

	-- Eyes: white, big black pupil, two highlights, and an eyelid for blinking.
	for _, side in { -1, 1 } do
		local eyeCf = center * CFrame.new(side * 0.5, 0.22, -0.88) * CFrame.Angles(0, side * math.rad(18), 0)
		local eye = ell(if side < 0 then "EyeL" else "EyeR", Vector3.new(0.66, 0.82, 0.4), eyeCf, WHITE, model)
		weld(head, eye)
		local pupilColor = if look.style == "Robo" then Color3.fromRGB(80, 220, 255) else BLACK
		local pupil = ell("Pupil", Vector3.new(0.4, 0.54, 0.3), eyeCf * CFrame.new(side * -0.04, -0.04, -0.12), pupilColor, model)
		if look.style == "Robo" then
			pupil.Material = Enum.Material.Neon
		end
		weld(head, pupil)
		weld(head, ell("Shine", Vector3.new(0.16, 0.16, 0.1), eyeCf * CFrame.new(side * -0.12, 0.13, -0.26), WHITE, model))
		weld(head, ell("Shine2", Vector3.new(0.08, 0.08, 0.06), eyeCf * CFrame.new(side * 0.06, -0.16, -0.25), WHITE, model))
		local lid = ell(if side < 0 then "LidL" else "LidR", Vector3.new(0.7, 0.86, 0.44), eyeCf * CFrame.new(0, 0, -0.03), look.head, model)
		lid.Transparency = 1
		weld(head, lid)
		-- Rosy cheeks.
		local cheek = ell("Cheek", Vector3.new(0.5, 0.3, 0.2), center * CFrame.new(side * 0.78, -0.25, -0.8) * CFrame.Angles(0, side * math.rad(35), 0), BLUSH, model)
		cheek.Transparency = 0.25
		weld(head, cheek)
	end

	-- Beak (upper and lower), or a duck bill.
	if look.style == "Duck" then
		addBill(model, head, center, look)
	else
		weld(head, ell("Beak", Vector3.new(0.72, 0.5, 1.0), center * CFrame.new(0, -0.08, -1.28) * CFrame.Angles(math.rad(-14), 0, 0), look.beak, model))
		weld(head, ell("BeakLower", Vector3.new(0.56, 0.3, 0.7), center * CFrame.new(0, -0.34, -1.15) * CFrame.Angles(math.rad(8), 0, 0), look.beak:Lerp(BLACK, 0.15), model))
	end

	-- Comb and wattle.
	local comb = look.comb
	if comb and look.style ~= "Duck" then
		type Lump = { at: Vector3, size: number }
		local lumps: { Lump } = {
			{ at = Vector3.new(0, 1.0, -0.62), size = 0.55 },
			{ at = Vector3.new(0, 1.2, -0.25), size = 0.78 },
			{ at = Vector3.new(0, 1.28, 0.18), size = 0.86 },
			{ at = Vector3.new(0, 1.12, 0.58), size = 0.68 },
		}
		for i, lump in lumps do
			local d = lump.size
			local part = ell(`Comb{i}`, Vector3.new(d * 0.68, d, d), center * CFrame.new(lump.at), comb, model)
			if look.style == "Robo" then
				part.Material = Enum.Material.Neon
			end
			weld(head, part)
		end
		weld(head, ell("Wattle", Vector3.new(0.34, 0.55, 0.3), center * CFrame.new(0, -0.74, -1.1), comb, model))
	end

	if look.style == "Robo" then
		addAntenna(model, head, center)
	end

	motor("Neck", body, head, CFrame.new(0, 3.3, -0.55))
	return head
end

local function buildWing(model: Model, body: BasePart, look: Look, side: number)
	local shoulder = CFrame.new(side * 1.3, 3.05, -0.25)
	local wingCf = shoulder * CFrame.new(side * 0.18, -0.65, 0.5) * CFrame.Angles(math.rad(-8), 0, side * math.rad(-8))
	local wing = ell(if side < 0 then "LeftWing" else "RightWing", Vector3.new(0.5, 1.6, 2.3), wingCf, look.wing, model)
	-- Layered feather tips on the wing.
	for i = 0, 2 do
		weld(
			wing,
			ell(
				"WingFeather",
				Vector3.new(0.4, 0.62 - i * 0.08, 0.95 - i * 0.1),
				wingCf * CFrame.new(side * 0.08, -0.2 - i * 0.12, 0.45 + i * 0.22) * CFrame.Angles(math.rad(14 + i * 10), 0, 0),
				look.wingTip,
				model
			)
		)
	end
	motor(if side < 0 then "LeftWing" else "RightWing", body, wing, shoulder)
end

local function buildTail(model: Model, body: BasePart, look: Look)
	local base = CFrame.new(0, 3.0, 1.55)
	local hub = ell("Tail", Vector3.new(0.9, 0.9, 0.7), base * CFrame.new(0, 0.1, 0.1), look.tail, model)
	local spread = { -32, -12, 12, 32 }
	for i, deg in spread do
		local color = if look.rainbow then look.rainbow[((i - 1) % #look.rainbow) + 1] else look.tail
		local feather = ell(
			"TailFeather",
			Vector3.new(0.42, 1.75 - math.abs(deg) / 60, 0.85),
			base * CFrame.Angles(math.rad(35), 0, math.rad(deg)) * CFrame.new(0, 0.85, 0.1),
			color,
			model
		)
		weld(hub, feather)
	end
	motor("Tail", body, hub, base)
end

local function buildLeg(model: Model, body: BasePart, look: Look, side: number)
	local hip = CFrame.new(side * 0.62, 1.4, 0.2)
	local legColor = look.beak
	local shin = basePart(if side < 0 then "LeftLeg" else "RightLeg", Vector3.new(0.95, 0.34, 0.34), hip * CFrame.new(0, -0.55, 0) * CFrame.Angles(0, 0, math.rad(90)), legColor, model)
	shin.Shape = Enum.PartType.Cylinder
	local ankle = hip * CFrame.new(0, -1.15, 0)
	weld(shin, ell("Ankle", Vector3.new(0.36, 0.3, 0.36), ankle, legColor, model))
	for _, deg in { -32, 0, 32 } do
		weld(shin, ell("Toe", Vector3.new(0.26, 0.2, 0.8), ankle * CFrame.new(0, -0.08, 0) * CFrame.Angles(0, math.rad(deg), 0) * CFrame.new(0, 0, -0.38), legColor, model))
	end
	weld(shin, ell("BackToe", Vector3.new(0.2, 0.16, 0.42), ankle * CFrame.new(0, -0.1, 0.25), legColor, model))
	motor(if side < 0 then "LeftHip" else "RightHip", body, shin, hip)
end

-- Smooth Blender chicken (assets/models/Chicken.glb) -----------------------------------------

-- Which joint each mesh region rides on, and the name it gets in the rig.
local MESH_REGIONS: { [string]: { joint: string, name: string } } = {
	Body = { joint = "Body", name = "Body" },
	Belly = { joint = "Body", name = "Chest" },
	Head = { joint = "Head", name = "Head" },
	EyeWhite = { joint = "Head", name = "Eyes" },
	Pupil = { joint = "Head", name = "Pupils" },
	Shine = { joint = "Head", name = "Shine" },
	LidL = { joint = "Head", name = "LidL" },
	LidR = { joint = "Head", name = "LidR" },
	Cheek = { joint = "Head", name = "Cheeks" },
	Beak = { joint = "Head", name = "Beak" },
	BeakLower = { joint = "Head", name = "BeakLower" },
	Comb = { joint = "Head", name = "Comb" },
	Wattle = { joint = "Head", name = "Wattle" },
	WingL = { joint = "LeftWing", name = "LeftWing" },
	WingR = { joint = "RightWing", name = "RightWing" },
	Tail = { joint = "Tail", name = "Tail" },
	LegL = { joint = "LeftHip", name = "LeftLeg" },
	LegR = { joint = "RightHip", name = "RightLeg" },
}

-- Joint pivots in the Blender chicken's space (feet at y = 0, facing -z).
local MESH_JOINTS: { [string]: CFrame } = {
	Head = CFrame.new(0, 3.25, -0.6),
	LeftWing = CFrame.new(-1.38, 2.95, -0.1),
	RightWing = CFrame.new(1.38, 2.95, -0.1),
	Tail = CFrame.new(0, 2.95, 1.45),
	LeftHip = CFrame.new(-0.55, 1.35, 0.25),
	RightHip = CFrame.new(0.55, 1.35, 0.25),
}
-- The main region of each moving joint (other regions on that joint weld to it).
local MESH_ANCHOR = { Body = "Body", Head = "Head", LeftWing = "WingL", RightWing = "WingR", Tail = "Tail", LeftHip = "LegL", RightHip = "LegR" }

local function meshColors(look: Look): { [string]: Color3 }
	local rainbow = look.rainbow
	return {
		Body = look.main,
		Belly = look.belly,
		Head = look.head,
		EyeWhite = WHITE,
		Pupil = if look.style == "Robo" then Color3.fromRGB(80, 220, 255) else BLACK,
		Shine = WHITE,
		LidL = look.head,
		LidR = look.head,
		Cheek = BLUSH,
		Beak = look.beak,
		BeakLower = look.beak:Lerp(BLACK, 0.15),
		Comb = look.comb or look.beak,
		Wattle = look.comb or look.beak,
		WingL = if rainbow then rainbow[2] else look.wing,
		WingR = if rainbow then rainbow[3] or rainbow[2] else look.wing,
		Tail = if rainbow then rainbow[1] else look.tail,
		LegL = look.beak,
		LegR = look.beak,
	}
end

-- Builds the rig from the imported meshes. Returns false if they aren't imported.
local function buildMeshBody(model: Model, root: BasePart, look: Look): boolean
	local regions = Meshes.regions("Chicken")
	local entry = Meshes.manifest("Chicken")
	if not regions or not entry then
		return false
	end
	local skip: { [string]: boolean } = {}
	if look.style == "Duck" then
		skip.Beak, skip.BeakLower, skip.Comb, skip.Wattle = true, true, true, true
	elseif not look.comb then
		skip.Comb, skip.Wattle = true, true
	end
	local colors = meshColors(look)
	local parts: { [string]: MeshPart } = {}
	for key, region in entry.regions do
		local info = MESH_REGIONS[key]
		if info and not skip[key] then
			local part = Meshes.place(regions[key], region, CFrame.new(), 1)
			part.Name = info.name
			part.Color = colors[key]
			part.Anchored = false
			part.CanCollide = false
			part.CanTouch = false
			part.Massless = true
			part.Parent = model
			parts[key] = part
		end
	end
	local body = parts.Body
	motor("Root", root, body, CFrame.new(0, ROOT_Y, 0))
	for joint, cf in MESH_JOINTS do
		local anchor = parts[MESH_ANCHOR[joint]]
		motor(if joint == "Head" then "Neck" else joint, body, anchor, cf)
	end
	for key, part in parts do
		local info = MESH_REGIONS[key]
		local anchorKey = MESH_ANCHOR[info.joint]
		if anchorKey ~= key then
			weld(parts[anchorKey], part)
		end
	end
	for _, key in { "LidL", "LidR" } do
		if parts[key] then
			parts[key].Transparency = 1
		end
	end
	if parts.Cheek then
		parts.Cheek.Transparency = 0.25
	end
	if look.style == "Robo" and parts.Pupil then
		parts.Pupil.Material = Enum.Material.Neon
		if parts.Comb then
			parts.Comb.Material = Enum.Material.Neon
		end
	end
	local headCenter = CFrame.new(0, 3.95, -0.75)
	if look.style == "Duck" then
		addBill(model, parts.Head, headCenter, look)
	elseif look.style == "Robo" then
		addAntenna(model, parts.Head, headCenter)
	end
	return true
end

local function finish(model: Model, look: Look)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
			if look.material ~= Enum.Material.SmoothPlastic then
				local keep = d.Name:find("Eye") or d.Name:find("Pupil") or d.Name:find("Shine") or d.Name:find("Cheek")
					or d.Name:find("Beak") or d.Name:find("Bill") or d.Name:find("Comb") or d.Name == "Wattle"
					or d.Name:find("Leg") or d.Name:find("Toe") or d.Name == "Ankle" or d.Name:find("Antenna")
				if not keep then
					d.Material = look.material
				end
			end
		end
	end
	if look.rainbow then
		local i = 0
		for _, d in model:GetChildren() do
			if d:IsA("BasePart") and (d.Name == "WingFeather" or d.Name:find("Wing") or d.Name == "Thigh") then
				i += 1
				d.Color = look.rainbow[(i % #look.rainbow) + 1]
			end
		end
	end
end

function ChickenBuilder.build(skin: Cosmetics.Item): Model
	local look = lookFor(skin)
	local model = Instance.new("Model")
	model.Name = skin.id

	local root = basePart("HumanoidRootPart", ROOT_SIZE, CFrame.new(0, ROOT_Y, 0), WHITE, model)
	root.Transparency = 1
	root.CanCollide = true
	root.Massless = false
	root.CastShadow = false

	-- The smooth Blender chicken when its meshes are imported, otherwise one made of parts.
	local usedMeshes = buildMeshBody(model, root, look)
	if not usedMeshes then
		-- Plump body, fluffy chest and feathery thighs.
		local body = ell("Body", Vector3.new(3.0, 2.7, 3.4), CFrame.new(0, 2.55, 0.15), look.main, model)
		weld(body, ell("Chest", Vector3.new(2.5, 2.35, 1.6), CFrame.new(0, 2.45, -0.75), look.belly, model))
		weld(body, ell("Back", Vector3.new(2.4, 1.4, 2.4), CFrame.new(0, 3.35, 0.65) * CFrame.Angles(0.25, 0, 0), look.main, model))
		for _, side in { -1, 1 } do
			weld(body, ell("Thigh", Vector3.new(1.05, 1.05, 1.25), CFrame.new(side * 0.72, 1.7, 0.25), look.main:Lerp(look.belly, 0.3), model))
		end
		motor("Root", root, body, CFrame.new(0, ROOT_Y, 0))

		buildHead(model, body, look)
		buildWing(model, body, look, -1)
		buildWing(model, body, look, 1)
		buildTail(model, body, look)
		buildLeg(model, body, look, -1)
		buildLeg(model, body, look, 1)
	end
	finish(model, look)
	model:SetAttribute("MeshRig", usedMeshes)
	model:SetAttribute("RigVersion", ChickenBuilder.RigVersion)

	local body = model:FindFirstChild("Body")
	if look.sparkles and body then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = look.main:Lerp(WHITE, 0.4)
		sparkles.Parent = body
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = HIP_HEIGHT
	humanoid.AutomaticScalingEnabled = false
	humanoid.Parent = model
	Instance.new("Animator").Parent = humanoid

	model.PrimaryPart = root
	model:SetAttribute("ChickenRig", true)
	return model
end

-- Builds every chicken skin into `folder` (skipping ones that already exist). Part-built
-- chickens are swapped for the smooth mesh ones once the meshes have been imported.
-- Returns how many were built.
function ChickenBuilder.buildAll(folder: Instance): number
	local upgrade = Meshes.available("Chicken")
	local count = 0
	for _, item in Cosmetics.inSlot("ChickenSkin") do
		local existing = folder:FindFirstChild(item.id)
		local stale = existing ~= nil and existing:GetAttribute("RigVersion") ~= ChickenBuilder.RigVersion
		if existing and ((upgrade and existing:GetAttribute("MeshRig") ~= true) or stale) then
			existing:Destroy()
			existing = nil
		end
		if not existing then
			ChickenBuilder.build(item).Parent = folder
			count += 1
		end
	end
	return count
end

return ChickenBuilder
