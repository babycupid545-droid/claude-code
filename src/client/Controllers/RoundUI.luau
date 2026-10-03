--!strict
-- The HUD: round status + timer, mode voting, big messages, kill feed, glide stamina,
-- chickens-left counter and spectating.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Modes = require(Shared.Modes)
local Remotes = require(Shared.Remotes)
local RoundState = require(Shared.RoundState)

local Effects = require(script.Parent.Parent.Effects)
local MovementController = require(script.Parent.MovementController)
local Ui = require(script.Parent.Parent.Ui)

local RoundUI = {}

local player = Players.LocalPlayer

local STATE_TITLES: { [string]: string } = {
	Waiting = "Waiting",
	Voting = "Vote!",
	Starting = "Get ready",
	InRound = "Cross the road!",
	Results = "Round over",
}

local gui: ScreenGui
local statusLabel: TextLabel
local aliveLabel: TextLabel
local messageLabel: TextLabel
local votePanel: Frame
local feedList: Frame
local staminaBar: Frame
local staminaFill: Frame
local spectateButton: TextButton
local spectateName: TextLabel

local myVote: string? = nil
local spectateIndex = 0
local spectating = false

local function decode(attribute: string, default: any): any
	local raw = RoundState:GetAttribute(attribute)
	if type(raw) ~= "string" or raw == "" then
		return default
	end
	local ok, value = pcall(HttpService.JSONDecode, HttpService, raw)
	return if ok then value else default
end

local function alivePlayers(): { Player }
	local list = {}
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("Alive") == true then
			table.insert(list, p)
		end
	end
	return list
end

-- Voting -------------------------------------------------------------------------------

local function rebuildVotes()
	for _, child in votePanel:GetChildren() do
		if child:IsA("GuiButton") then
			child:Destroy()
		end
	end
	local options: { string } = decode("VoteOptions", {})
	local counts: { [string]: number } = decode("Votes", {})
	votePanel.Visible = RoundState:GetAttribute("State") == "Voting" and #options > 0
	for i, id in options do
		local mode = Modes.get(id)
		if mode then
			local chosen = myVote == id
			local button = Ui.button("", {
				LayoutOrder = i,
				Size = UDim2.new(1 / 3, -8, 1, 0),
				BackgroundColor3 = if chosen then Color3.fromRGB(80, 200, 90) else Color3.fromRGB(255, 170, 40),
				Parent = votePanel,
			})
			Ui.label(mode.name, {
				Size = UDim2.new(1, 0, 0.32, 0),
				Parent = button,
			})
			Ui.label(mode.description, {
				Position = UDim2.fromScale(0, 0.34),
				Size = UDim2.new(1, 0, 0.42, 0),
				TextColor3 = Color3.fromRGB(255, 250, 230),
				Font = Enum.Font.GothamBold,
				Parent = button,
			})
			Ui.label(`{counts[id] or 0} vote(s)`, {
				Position = UDim2.fromScale(0, 0.78),
				Size = UDim2.new(1, 0, 0.2, 0),
				Parent = button,
			})
			button.Activated:Connect(function()
				myVote = id
				Remotes.Vote:FireServer(id)
				rebuildVotes()
			end)
		end
	end
end

-- Feed ---------------------------------------------------------------------------------

local feedOrder = 0
local function pushFeed(text: string)
	feedOrder += 1
	local label = Ui.label(text, {
		LayoutOrder = feedOrder,
		Size = UDim2.new(1, 0, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = feedList,
	})
	-- Keep only the newest few lines.
	local lines = {}
	for _, child in feedList:GetChildren() do
		if child:IsA("TextLabel") then
			table.insert(lines, child)
		end
	end
	if #lines > 5 then
		table.sort(lines, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		lines[1]:Destroy()
	end
	task.delay(6, function()
		label:Destroy()
	end)
end

-- Spectating ---------------------------------------------------------------------------

local function resetCamera()
	spectating = false
	spectateName.Visible = false
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		workspace.CurrentCamera.CameraSubject = humanoid
	end
end

local function spectateNext()
	local alive = alivePlayers()
	if #alive == 0 then
		resetCamera()
		return
	end
	spectateIndex = (spectateIndex % #alive) + 1
	local target = alive[spectateIndex]
	local humanoid = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		spectating = true
		workspace.CurrentCamera.CameraSubject = humanoid
		spectateName.Text = `Watching {target.DisplayName}`
		spectateName.Visible = true
	end
end

-- Build --------------------------------------------------------------------------------

local function build()
	gui = Ui.new("ScreenGui", {
		Name = "RoundGui",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		Parent = player:WaitForChild("PlayerGui"),
	})

	local top = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.new(0.5, 0, 0, 48),
		BackgroundColor3 = Color3.fromRGB(30, 30, 40),
		BackgroundTransparency = 0.3,
		Parent = gui,
	}, { Ui.corner(12), Ui.new("UISizeConstraint", { MinSize = Vector2.new(260, 0), MaxSize = Vector2.new(520, 48) }) })
	statusLabel = Ui.label("", {
		Size = UDim2.new(1, -16, 1, -8),
		Position = UDim2.fromOffset(8, 4),
		Parent = top,
	})
	aliveLabel = Ui.label("", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 60),
		Size = UDim2.fromOffset(220, 28),
		Parent = gui,
	})

	messageLabel = Ui.label("", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.new(0.8, 0, 0, 60),
		TextColor3 = Color3.fromRGB(255, 230, 90),
		Parent = gui,
	})

	votePanel = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.new(0.8, 0, 0, 150),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	}, {
		Ui.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 12),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Ui.new("UISizeConstraint", { MaxSize = Vector2.new(720, 150) }),
	})

	feedList = Ui.new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 100),
		Size = UDim2.fromOffset(360, 170),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Ui.new("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			Padding = UDim.new(0, 2),
		}),
	})

	staminaBar = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -110),
		Size = UDim2.fromOffset(200, 12),
		BackgroundColor3 = Color3.fromRGB(30, 30, 40),
		BackgroundTransparency = 0.3,
		Visible = false,
		Parent = gui,
	}, { Ui.corner(6) })
	staminaFill = Ui.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(120, 220, 255),
		Parent = staminaBar,
	}, { Ui.corner(6) })

	spectateButton = Ui.button("👀 Spectate", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -16),
		Size = UDim2.fromOffset(160, 50),
		Visible = false,
		Parent = gui,
	})
	spectateButton.Activated:Connect(spectateNext)
	spectateName = Ui.label("", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -72),
		Size = UDim2.fromOffset(260, 28),
		TextXAlignment = Enum.TextXAlignment.Left,
		Visible = false,
		Parent = gui,
	})
end

local function onStateChanged()
	local state = RoundState:GetAttribute("State")
	if state == "Voting" then
		myVote = nil
	end
	if state ~= "InRound" and spectating then
		resetCamera()
	end
	rebuildVotes()
end

local function render()
	local state = RoundState:GetAttribute("State") :: string?
	local endsAt = RoundState:GetAttribute("EndsAt") :: number?
	local title = STATE_TITLES[state or ""] or ""
	local message = RoundState:GetAttribute("Message") :: string?
	if endsAt and endsAt > 0 then
		local left = math.max(0, math.ceil(endsAt - workspace:GetServerTimeNow()))
		statusLabel.Text = string.format("%s  %d:%02d", title, left // 60, left % 60)
	elseif state == "Waiting" and message then
		statusLabel.Text = message
	else
		statusLabel.Text = title
	end

	local showMessage = (state == "Starting" or state == "Results" or state == "Voting") and message ~= nil
	messageLabel.Visible = showMessage
	messageLabel.Text = message or ""

	local inRound = state == "InRound" or state == "Starting"
	aliveLabel.Visible = inRound
	if inRound then
		aliveLabel.Text = `🐔 {#alivePlayers()} left`
	end

	local alive = player:GetAttribute("Alive") == true
	staminaBar.Visible = inRound and alive
	staminaFill.Size = UDim2.fromScale(MovementController.getStamina(), 1)
	staminaFill.BackgroundColor3 = if MovementController.isGliding()
		then Color3.fromRGB(255, 220, 90)
		else Color3.fromRGB(120, 220, 255)

	spectateButton.Visible = state == "InRound" and not alive and player:GetAttribute("Driver") ~= true
end

function RoundUI.start()
	build()
	RoundState:GetAttributeChangedSignal("State"):Connect(onStateChanged)
	RoundState:GetAttributeChangedSignal("VoteOptions"):Connect(rebuildVotes)
	RoundState:GetAttributeChangedSignal("Votes"):Connect(rebuildVotes)
	onStateChanged()

	Remotes.Feed.OnClientEvent:Connect(pushFeed)
	Remotes.WinEffect.OnClientEvent:Connect(Effects.win)
	player.CharacterAdded:Connect(function()
		if not spectating then
			return
		end
		-- Respawning resets the camera subject; keep watching.
		task.defer(function()
			spectateIndex -= 1
			spectateNext()
		end)
	end)

	RunService.RenderStepped:Connect(render)
end

return RoundUI
