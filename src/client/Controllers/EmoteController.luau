--!strict
-- Plays emotes. An Animation in ReplicatedStorage.Assets.Emotes/<id> is played on the
-- emoting player's character (animations replicate). Without one, a generated stand-in is
-- shown: text bubbles, spins, hops, a laid egg...

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Assets = require(Shared.Assets)
local Cosmetics = require(Shared.Cosmetics)
local Remotes = require(Shared.Remotes)

local ClientData = require(script.Parent.Parent.ClientData)
local Effects = require(script.Parent.Parent.Effects)

local EmoteController = {}

local player = Players.LocalPlayer
local KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four }

local function rootOf(p: Player): BasePart?
	local character = p.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

-- Only the emoting player's own client moves its character; the movement replicates.
local function spin(root: BasePart, turns: number, duration: number)
	local humanoid = root.Parent and root.Parent:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.AutoRotate = false
	end
	local start = os.clock()
	local base = root.CFrame
	local connection
	connection = RunService.PreSimulation:Connect(function()
		local alpha = math.min(1, (os.clock() - start) / duration)
		if not root.Parent then
			connection:Disconnect()
			return
		end
		root.CFrame = CFrame.new(root.Position) * base.Rotation * CFrame.Angles(0, alpha * turns * math.pi * 2, 0)
		if alpha >= 1 then
			connection:Disconnect()
			if humanoid then
				humanoid.AutoRotate = true
			end
		end
	end)
end

local function hop(root: BasePart, times: number)
	local humanoid = root.Parent and root.Parent:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	task.spawn(function()
		for _ = 1, times do
			humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			task.wait(0.45)
		end
	end)
end

local function layEgg(root: BasePart)
	local egg = Effects.makeEgg(ClientData.equipped("EggSkin"))
	local position = root.Position - Vector3.new(0, 2.4, 0) + root.CFrame.LookVector * 1.5
	if egg:IsA("BasePart") then
		egg.Size *= 2.2
		egg.CFrame = CFrame.new(position) * CFrame.Angles(math.rad(90), 0, 0)
	elseif egg:IsA("Model") then
		egg:ScaleTo(2.2)
		egg:PivotTo(CFrame.new(position) * CFrame.Angles(math.rad(90), 0, 0))
	end
	egg.Parent = workspace:FindFirstChild("ClientEffects") or workspace
	task.delay(4, function()
		egg:Destroy()
	end)
end

local function play(userId: number, itemId: string)
	local emoter = Players:GetPlayerByUserId(userId)
	local item = Cosmetics.get(itemId)
	local root = emoter and rootOf(emoter)
	if not emoter or not item or not root then
		return
	end
	local isMe = emoter == player

	local animation = Assets.find("Emotes", item.id)
	if animation and animation:IsA("Animation") then
		if isMe then
			local humanoid = root.Parent and root.Parent:FindFirstChildOfClass("Humanoid")
			local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
			if animator then
				animator:LoadAnimation(animation):Play()
			end
		end
		return
	end

	local look = item.look
	local special = look.special
	if look.text then
		Effects.floatText(root.Position + Vector3.new(0, 4, 0), look.text, Color3.fromRGB(255, 240, 120))
	end
	if look.sparkles then
		local sparkles = Instance.new("Sparkles")
		sparkles.Parent = root
		task.delay(2, function()
			sparkles:Destroy()
		end)
	end
	if special == "LayEgg" then
		layEgg(root)
	end
	if not isMe then
		return
	end
	if special == "Spin" then
		spin(root, 2, 0.8)
	elseif special == "Hop" then
		hop(root, 3)
	elseif special == "Dance" then
		hop(root, 2)
		spin(root, 3, 1.6)
	end
end

-- Asks the server to play an equipped emote.
function EmoteController.request(itemId: string)
	Remotes.Emote:FireServer(itemId)
end

function EmoteController.start()
	Remotes.PlayEmote.OnClientEvent:Connect(play)
	ContextActionService:BindAction("EmoteKeys", function(_, state, input)
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		local data = ClientData.get()
		local index = table.find(KEYS, input.KeyCode)
		if data and index and data.equipped.Emotes[index] then
			EmoteController.request(data.equipped.Emotes[index])
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, table.unpack(KEYS))
end

return EmoteController
