--!strict
-- Points every ImageLabel with a "Sprite" attribute at the right spot on the UI sprite sheet.
-- Until the sheet is uploaded (AssetIds.UiSheet), icons fall back to emoji so the UI is
-- still readable.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local AssetIds = require(Shared.AssetIds)
local UiSprites = require(Shared.UiSprites)

local Sprites = {}

local EMOJI: { [string]: string } = {
	coin = "🪙", shop = "🛒", emote = "😀", trophy = "🏆", egg = "🥚", chicken = "🐔",
	clock = "⏱️", skull = "💀", crown = "👑", check = "✅", close = "✖️", lock = "🔒",
	star = "⭐", heart = "❤️", lightning = "⚡", car = "🚗", note = "🎵", gear = "⚙️",
	gift = "🎁", flagRed = "🚩", flagBlue = "🏳️", vote = "🗳️", eye = "👁️",
	arrowUp = "⬆️", arrowDown = "⬇️", arrowLeft = "⬅️", arrowRight = "➡️", play = "▶️",
	sparkle = "✨", fire = "🔥", feather = "🪶", boom = "💥", users = "👥", angry = "😡",
	speaker = "🔊", speakerMute = "🔇", team = "⚔️", info = "ℹ️", chickenRun = "🐔", splat = "🍳",
}

local sheet = AssetIds.get("UiSheet")

local function apply(image: any)
	local name = image:GetAttribute("Sprite")
	if type(name) ~= "string" then
		return
	end
	local sprite = UiSprites[name]
	local fallback = image:FindFirstChild("SpriteEmoji")
	if sheet ~= "" and sprite then
		image.Image = sheet
		image.ImageRectOffset = sprite.offset
		image.ImageRectSize = sprite.size
		if fallback then
			fallback:Destroy()
		end
		return
	end
	image.Image = ""
	local emoji = EMOJI[name]
	if not emoji then
		if fallback then
			fallback:Destroy()
		end
		return
	end
	local label = fallback :: TextLabel?
	if not label then
		local l = Instance.new("TextLabel")
		l.Name = "SpriteEmoji"
		l.BackgroundTransparency = 1
		l.Size = UDim2.fromScale(1, 1)
		l.TextScaled = true
		l.Font = Enum.Font.FredokaOne
		l.TextColor3 = Color3.new(1, 1, 1)
		l.ZIndex = image.ZIndex
		l.Parent = image
		label = l
	end
	(label :: TextLabel).Text = emoji
end

local function watch(inst: Instance)
	if inst:IsA("ImageLabel") or inst:IsA("ImageButton") then
		if inst:GetAttribute("Sprite") ~= nil then
			apply(inst)
		end
		inst:GetAttributeChangedSignal("Sprite"):Connect(function()
			apply(inst)
		end)
	end
end

-- Changes which sprite an image shows.
function Sprites.set(image: Instance, name: string)
	image:SetAttribute("Sprite", name)
end

function Sprites.hasSheet(): boolean
	return sheet ~= ""
end

function Sprites.start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	for _, d in playerGui:GetDescendants() do
		watch(d)
	end
	playerGui.DescendantAdded:Connect(watch)
end

return Sprites
