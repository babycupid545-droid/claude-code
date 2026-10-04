--!strict
-- The power-up chips on the HUD (built in src/builders/GuiBuilder.luau), just above the egg
-- and stamina bars: the power-up you hold with its time left, and the special eggs you have
-- loaded with how many are left. Driven by the player attributes in Shared/Powerups.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Powerups = require(Shared.Powerups)
local RoundState = require(Shared.RoundState)

local Anim = require(script.Parent.Parent.Anim)
local Gui = require(script.Parent.Parent.Gui)
local Sprites = require(script.Parent.Parent.Sprites)

local PowerupUI = {}

local player = Players.LocalPlayer
local WHITE = Color3.new(1, 1, 1)

type Chip = { frame: any, key: string, count: number }
local power: Chip
local special: Chip

-- Shows the chip for `def` (or hides it), punching it whenever what it shows changes.
local function setChip(chip: Chip, def: Powerups.Def?, shown: boolean, key: string)
	Anim.setShown(chip.frame, shown and def ~= nil)
	if not def or key == chip.key then
		return
	end
	chip.key = key
	local inner = chip.frame.Inner
	inner.Title.Text = def.name
	inner.Title.TextColor3 = def.color
	Sprites.set(inner.Icon, def.sprite)
	inner.Icon.ImageColor3 = def.tint or WHITE
	inner.Bar.Fill.BackgroundColor3 = def.color
	if chip.frame.Visible then
		Anim.punch(chip.frame, 0.15)
	end
end

local function duration(id: string): number
	local P = Config.Powerups
	return if id == "Speed" then P.SpeedDuration elseif id == "Feather" then P.FeatherDuration else 0
end

local function render()
	local playing = player:GetAttribute("Alive") == true and RoundState:GetAttribute("State") == "InRound"

	local def = Powerups.get(player:GetAttribute("Powerup"))
	setChip(power, def, playing, if def then def.id else "")
	if def then
		local inner = power.frame.Inner
		local total = duration(def.id)
		local endsAt = player:GetAttribute("PowerupEndsAt")
		if total > 0 and type(endsAt) == "number" and endsAt > 0 then
			local left = math.max(0, endsAt - workspace:GetServerTimeNow())
			inner.Value.Text = `{math.ceil(left)}s`
			inner.Bar.Fill.Size = UDim2.fromScale(math.clamp(left / total, 0.02, 1), 1)
		else
			-- One-shot: lasts until used.
			inner.Value.Text = if def.id == "MegaEgg" then "NEXT" else "READY"
			inner.Bar.Fill.Size = UDim2.fromScale(1, 1)
		end
	end

	local eggDef = Powerups.get(player:GetAttribute("SpecialEgg"))
	local ammo = player:GetAttribute("SpecialAmmo")
	local count = if type(ammo) == "number" then ammo else 0
	setChip(special, if count > 0 then eggDef else nil, playing, if eggDef then eggDef.id else "")
	if eggDef and count > 0 then
		local inner = special.frame.Inner
		inner.Value.Text = `x{count}`
		inner.Bar.Fill.Size = UDim2.fromScale(math.clamp(count / Config.Powerups.SpecialAmmo, 0.02, 1), 1)
		if count < special.count and special.frame.Visible then
			Anim.punch(special.frame, 0.1)
		end
	end
	special.count = count
end

function PowerupUI.start()
	local hud = Gui.screen("Hud")
	power = { frame = Gui.find(hud, "Root/Powerups/Power"), key = "", count = 0 }
	special = { frame = Gui.find(hud, "Root/Powerups/Special"), key = "", count = 0 }
	RunService.RenderStepped:Connect(render)
end

return PowerupUI
