--!strict
-- Sets up every character as a chicken (movement stats) and handles squashing.
-- Chicken skins hook in here later (see docs/GAME_DESIGN.md, cosmetics milestone).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local ChickenService = {}

local function setupCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	humanoid.UseJumpPower = true
	humanoid.JumpPower = Config.Chicken.JumpPower
	humanoid.WalkSpeed = Config.Chicken.WalkSpeed
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
	Players.RespawnTime = Config.Timing.RespawnTime
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(setupCharacter)
		if player.Character then
			task.spawn(setupCharacter, player.Character)
		end
	end)
	for _, player in Players:GetPlayers() do
		player.CharacterAdded:Connect(setupCharacter)
		if player.Character then
			task.spawn(setupCharacter, player.Character)
		end
	end
end

return ChickenService
