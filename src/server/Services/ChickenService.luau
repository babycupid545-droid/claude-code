--!strict
-- Spawns every player as a chicken in their equipped skin and handles squashing.
--
-- A skin with a rig in ReplicatedStorage.Assets.Chickens/<SkinId> uses that rig. Otherwise
-- the player gets a plain chubby body in the skin's colours with a generated beak, comb and
-- tail, so everyone is a chicken even before any art exists.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Assets = require(Shared.Assets)
local Config = require(Shared.Config)
local Cosmetics = require(Shared.Cosmetics)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)

local ChickenService = {}

local spawning: { [Player]: boolean } = {}

local function lobbySpawnCFrame(): CFrame
	local lobby = workspace:WaitForChild("Lobby", 30)
	local spawn = lobby and lobby:FindFirstChild("LobbySpawn") :: BasePart?
	if spawn then
		return spawn.CFrame + Vector3.new(math.random(-4, 4), 4, math.random(-4, 4))
	end
	return CFrame.new(Config.Map.LobbyCenter + Vector3.new(0, 5, 0))
end

local function color(colors: { Color3 }?, index: number): Color3
	if not colors or #colors == 0 then
		return Color3.new(1, 1, 1)
	end
	return colors[((index - 1) % #colors) + 1]
end

local function makeDescription(skin: Cosmetics.Item): HumanoidDescription
	local look = skin.look
	local desc = Instance.new("HumanoidDescription")
	desc.HeadColor = color(look.colors, 1)
	desc.TorsoColor = color(look.colors, 2)
	desc.LeftArmColor = color(look.colors, 3)
	desc.RightArmColor = color(look.colors, 4)
	-- Chicken legs are the beak colour.
	desc.LeftLegColor = look.beak or Color3.fromRGB(255, 160, 30)
	desc.RightLegColor = look.beak or Color3.fromRGB(255, 160, 30)
	-- Short and round.
	desc.HeightScale = 0.85
	desc.WidthScale = 1.25
	desc.DepthScale = 1.25
	desc.HeadScale = 1.15
	desc.BodyTypeScale = 0
	desc.ProportionScale = 0
	return desc
end

local function weldPart(parent: BasePart, offset: CFrame, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Name = "ChickenBit"
	p.CanCollide = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(p :: any)[key] = value
	end
	p.CFrame = parent.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = parent
	weld.Part1 = p
	weld.Parent = p
	p.Parent = parent
	return p
end

-- Beak, wattle, comb, tail and optional sparkles on a generated chicken.
local function decorate(character: Model, skin: Cosmetics.Item)
	local look = skin.look
	local head = character:WaitForChild("Head", 5) :: BasePart?
	local torso = (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")) :: BasePart?
	if not head or not torso then
		return
	end
	local h = head.Size
	local beak = look.beak or Color3.fromRGB(255, 160, 30)
	-- Head front is -Z.
	weldPart(head, CFrame.new(0, -h.Y * 0.05, -h.Z / 2 - 0.25), {
		Size = Vector3.new(h.X * 0.35, h.Y * 0.18, 0.55),
		Color = beak,
	})
	if look.comb then
		weldPart(head, CFrame.new(0, -h.Y * 0.32, -h.Z / 2 - 0.05), {
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.4, 0.4, 0.4),
			Color = look.comb,
		})
		for i = -1, 1 do
			weldPart(head, CFrame.new(0, h.Y / 2 + 0.12, i * h.Z * 0.22), {
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(0.45, 0.45, 0.45),
				Color = look.comb,
			})
		end
	end
	local t = torso.Size
	for i = -1, 1 do
		weldPart(
			torso,
			CFrame.new(i * t.X * 0.18, t.Y * 0.25, t.Z / 2 + 0.3) * CFrame.Angles(math.rad(35), 0, math.rad(i * 18)),
			{
				Size = Vector3.new(0.35, t.Y * 0.7, 0.35),
				Color = color(look.colors, i + 2),
				Material = look.material or Enum.Material.SmoothPlastic,
			}
		)
	end

	if look.material then
		for _, d in character:GetChildren() do
			if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" and not d.Name:find("Leg") and not d.Name:find("Foot") then
				d.Material = look.material
			end
		end
	end
	if look.sparkles then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = color(look.colors, 1)
		sparkles.Parent = torso
	end
end

local function setupCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	humanoid.UseJumpPower = true
	humanoid.JumpPower = Config.Chicken.JumpPower
	humanoid.WalkSpeed = Config.Chicken.WalkSpeed

	humanoid.Died:Connect(function()
		-- The chicken falls apart; let the pieces land and bounce instead of dropping through.
		for _, d in character:GetDescendants() do
			if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" and d.Transparency < 1 then
				d.CanCollide = true
			end
		end
		task.delay(Config.Timing.RespawnTime, function()
			if player.Parent == Players and player.Character == character then
				ChickenService.spawn(player)
			end
		end)
	end)
end

-- Builds a chicken rig at runtime if it wasn't built in Studio (see docs/STUDIO_SETUP.md).
function ChickenService.buildMissingRig(skin: Cosmetics.Item): Instance?
	local ok, result = pcall(function()
		local assets = ReplicatedStorage:FindFirstChild("Assets")
		if not assets then
			local f = Instance.new("Folder")
			f.Name = "Assets"
			f.Parent = ReplicatedStorage
			assets = f
		end
		local folder = (assets :: Instance):FindFirstChild("Chickens")
		if not folder then
			local f = Instance.new("Folder")
			f.Name = "Chickens"
			f.Parent = assets
			folder = f
		end
		local builder = require(ReplicatedStorage:WaitForChild("Builders"):WaitForChild("ChickenBuilder")) :: any
		local model = builder.build(skin)
		model.Parent = folder
		return model
	end)
	if not ok then
		warn("Couldn't build chicken rig:", result)
		return nil
	end
	return result
end

-- (Re)spawns a player in the lobby with their equipped skin.
function ChickenService.spawn(player: Player)
	if spawning[player] or player.Parent ~= Players then
		return
	end
	spawning[player] = true
	local skin = Cosmetics.resolve("ChickenSkin", DataService.equipped(player, "ChickenSkin"))
	local rig = Assets.find("Chickens", skin.id) or ChickenService.buildMissingRig(skin)

	local ok, err = pcall(function()
		if rig and rig:IsA("Model") and rig:FindFirstChildOfClass("Humanoid") and rig:FindFirstChild("HumanoidRootPart") then
			local character = rig:Clone()
			character.Name = player.Name
			character:SetAttribute("Skin", skin.id)
			character:SetAttribute("CustomRig", true)
			character:PivotTo(lobbySpawnCFrame())
			local old = player.Character
			player.Character = character
			character.Parent = workspace
			if old then
				old:Destroy()
			end
		else
			player:LoadCharacterWithHumanoidDescriptionAsync(makeDescription(skin))
			local character = player.Character
			if character then
				character:SetAttribute("Skin", skin.id)
				task.spawn(decorate, character, skin)
			end
		end
	end)
	if not ok then
		warn("Chicken spawn failed, using a default character:", err)
		pcall(player.LoadCharacterAsync, player)
	end
	spawning[player] = nil
end

function ChickenService.getRoot(player: Player): BasePart?
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

function ChickenService.getHumanoid(player: Player): Humanoid?
	local character = player.Character
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

-- Hit by a car: kill and fling the chicken with the car's momentum.
function ChickenService.squash(player: Player, carVelocity: Vector3)
	local humanoid = ChickenService.getHumanoid(player)
	local root = ChickenService.getRoot(player)
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	humanoid.Health = 0
	local position = if root then root.Position else Vector3.zero
	local fling = carVelocity * 0.6 + Vector3.new(0, 60, 0)
	Remotes.ChickenSplat:FireAllClients(player.UserId, position, fling)
end

function ChickenService.kill(player: Player)
	local humanoid = ChickenService.getHumanoid(player)
	if humanoid then
		humanoid.Health = 0
	end
end

function ChickenService.init()
	Players.CharacterAutoLoads = false
	Players.RespawnTime = Config.Timing.RespawnTime

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			setupCharacter(player, character)
		end)
		DataService.waitFor(player, 15)
		ChickenService.spawn(player)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayer, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		spawning[player] = nil
	end)

	-- Show a newly equipped skin right away, unless the player is busy in a round.
	DataService.EquippedChanged:Connect(function(player: Player, slot: string)
		if slot == "ChickenSkin" and player:GetAttribute("Alive") ~= true then
			ChickenService.spawn(player)
		end
	end)
end

return ChickenService
