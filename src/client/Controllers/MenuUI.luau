--!strict
-- The side menu (golden eggs, Shop, Emotes, music), the Shop window, the emote wheel and toast
-- notifications. Uses the Hud, Shop and Emotes ScreenGuis built in Studio.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Cosmetics = require(Shared.Cosmetics)
local Remotes = require(Shared.Remotes)

local Anim = require(script.Parent.Parent.Anim)
local CameraFx = require(script.Parent.Parent.CameraFx)
local ClientData = require(script.Parent.Parent.ClientData)
local EmoteController = require(script.Parent.EmoteController)
local Gui = require(script.Parent.Parent.Gui)
local MusicController = require(script.Parent.MusicController)
local Previews = require(script.Parent.Parent.Previews)
local Sfx = require(script.Parent.Parent.Sfx)
local Sprites = require(script.Parent.Parent.Sprites)

local MenuUI = {}

local player = Players.LocalPlayer

local GREEN = Color3.fromRGB(80, 210, 100)
local GREY = Color3.fromRGB(150, 150, 170)
local ORANGE = Color3.fromRGB(255, 150, 40)
local PINK = Color3.fromRGB(255, 100, 170)
local YELLOW = Color3.fromRGB(255, 201, 60)

local SLOT_SPRITES: { [string]: string } = {
	ChickenSkin = "chicken",
	EggSkin = "egg",
	HitEffect = "boom",
	WinEffect = "trophy",
	Emote = "emote",
}

local hud: ScreenGui
local shop: ScreenGui
local emotes: ScreenGui
local ui: { [string]: any } = {}

local currentTab = "ChickenSkin"
local shownCoins = 0
local spinning: { Model } = {}
local robuxPrices: { [number]: number } = {}

-- Helpers -------------------------------------------------------------------------------------

local function setButton(button: any, text: string?, color: Color3?, sprite: string?)
	local content = button.Face.Content
	local label = content:FindFirstChild("Label")
	if label and text then
		label.Text = text
	end
	if color then
		button.Face.BackgroundColor3 = color
		button.Base.BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.45)
	end
	local icon = content:FindFirstChild("Icon")
	if icon then
		icon.Visible = sprite ~= nil
		if sprite then
			Sprites.set(icon, sprite)
		end
	end
end

local function robuxPrice(id: number, isPass: boolean, button: any)
	local cached = robuxPrices[id]
	if cached then
		setButton(button, `R$ {cached}`)
		return
	end
	setButton(button, "R$ ...")
	task.spawn(function()
		local ok, info = pcall(
			MarketplaceService.GetProductInfoAsync,
			MarketplaceService,
			id,
			if isPass then Enum.InfoType.GamePass else Enum.InfoType.Product
		)
		if ok and info and type(info.PriceInRobux) == "number" then
			robuxPrices[id] = info.PriceInRobux
			if button.Parent then
				setButton(button, `R$ {info.PriceInRobux}`)
			end
		elseif button.Parent then
			setButton(button, "R$ BUY")
		end
	end)
end

-- Coins in the corner -------------------------------------------------------------------------

local function updateCoins()
	local data = ClientData.get()
	if not data then
		return
	end
	local target = data.coins
	if target ~= shownCoins then
		local label = ui.coinsAmount
		Anim.countTo(label, shownCoins, target, 0.7)
		Anim.countTo(ui.shopCoins, shownCoins, target, 0.7)
		if target > shownCoins then
			Anim.punch(ui.coinsPill, 0.15)
		end
		shownCoins = target
	end
end

-- Shop ------------------------------------------------------------------------------------------

local function rarityColors(item: Cosmetics.Item): (Color3, Color3)
	local c = Cosmetics.rarityColors[item.rarity]
	return c:Lerp(Color3.new(1, 1, 1), 0.15), c:Lerp(Color3.new(0, 0, 0), 0.45)
end

local function itemCard(item: Cosmetics.Item, order: number)
	local data = ClientData.get()
	local card = Gui.template(shop, "ItemCard")
	card.LayoutOrder = order
	local top, bottom = rarityColors(item)
	card.RarityGradient.Color = ColorSequence.new(top, bottom)
	card.Glow.ImageColor3 = top
	card.ItemName.Text = item.name
	card.Rarity.Text = string.upper(item.rarity)
	card.Rarity.TextColor3 = top:Lerp(Color3.new(1, 1, 1), 0.4)

	-- Preview: 3D for skins and eggs, an icon for everything else.
	if item.slot == "ChickenSkin" or item.slot == "EggSkin" then
		card.Preview.Visible = true
		card.PreviewIcon.Visible = false
		local model = if item.slot == "ChickenSkin" then Previews.chicken(item.id) else Previews.egg(item.id)
		table.insert(spinning, Previews.show(card.Preview, model))
	else
		card.Preview.Visible = false
		Sprites.set(card.PreviewIcon, SLOT_SPRITES[item.slot])
		card.PreviewIcon.ImageColor3 = if item.look.colors then item.look.colors[1]:Lerp(Color3.new(1, 1, 1), 0.5) else Color3.new(1, 1, 1)
	end

	local owned = ClientData.owns(item.id)
	local equipped = ClientData.isEquipped(item.id)
	card.Equipped.Visible = equipped
	card.Lock.Visible = not owned
	local action = card.Action
	if owned then
		if item.slot == "Emote" then
			setButton(action, if equipped then "UNEQUIP" else "EQUIP", if equipped then GREY else GREEN)
		else
			setButton(action, if equipped then "EQUIPPED" else "EQUIP", if equipped then GREY else GREEN)
		end
		action.Activated:Connect(function()
			if item.slot == "Emote" or not equipped then
				Remotes.EquipItem:FireServer(item.id)
				Sfx.play("Equip")
				Anim.punch(card, 0.08)
			end
		end)
	elseif item.price then
		local affordable = data ~= nil and data.coins >= item.price
		setButton(action, tostring(item.price), if affordable then ORANGE else GREY, "eggCoin")
		action.Activated:Connect(function()
			if ClientData.get() and (ClientData.get() :: any).coins >= item.price then
				Remotes.BuyItem:FireServer(item.id)
			else
				Sfx.play("Error")
				Anim.shake(action, 5, 0.3)
			end
		end)
	elseif item.robux then
		local productId = Config.Monetization.ItemProducts[item.id] or 0
		if productId == 0 then
			setButton(action, "SOON", GREY)
		else
			setButton(action, "R$", PINK)
			robuxPrice(productId, false, action)
			action.Activated:Connect(function()
				MarketplaceService:PromptProductPurchase(player, productId)
			end)
		end
	end
	if item.rarity == "Epic" or item.rarity == "Legendary" or item.rarity == "Exclusive" then
		Anim.shine(card.Shine)
	end
	card.Parent = ui.grid
	Anim.juice(action)
	Anim.pop(card, 0.025 * order)
end

local function packCard(order: number, title: string, subtitle: string, sprite: string, id: number, isPass: boolean, owned: boolean)
	local card = Gui.template(shop, "PackCard")
	card.LayoutOrder = order
	card.RarityGradient.Color = ColorSequence.new(Color3.fromRGB(255, 210, 90), Color3.fromRGB(200, 120, 30))
	card.Glow.ImageColor3 = YELLOW
	card.Preview.Visible = false
	Sprites.set(card.PreviewIcon, sprite)
	card.ItemName.Text = title
	card.Rarity.Text = subtitle
	card.Lock.Visible = false
	card.Equipped.Visible = owned
	local action = card.Action
	if owned then
		setButton(action, "OWNED", GREY)
	elseif id == 0 then
		setButton(action, "SOON", GREY)
	else
		setButton(action, "R$", PINK)
		robuxPrice(id, isPass, action)
		action.Activated:Connect(function()
			if isPass then
				MarketplaceService:PromptGamePassPurchase(player, id)
			else
				MarketplaceService:PromptProductPurchase(player, id)
			end
		end)
	end
	Anim.shine(card.Shine)
	card.Parent = ui.grid
	Anim.juice(action)
	Anim.pop(card, 0.04 * order)
end

local function refreshShop()
	if not ui.panel.Visible then
		return
	end
	for id, tab in ui.tabs do
		setButton(tab, nil, if id == currentTab then GREEN else ORANGE)
		tab.AnimScale.Scale = if id == currentTab then 1.06 else 1
	end
	for _, child in ui.grid:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	table.clear(spinning)
	if currentTab == "Coins" then
		local data = ClientData.get()
		local M = Config.Monetization
		packCard(1, "VIP", `x{M.VipCoinMultiplier} EGGS FOREVER`, "crown", M.VipGamePassId, true, data ~= nil and data.vip)
		for i, pack in M.CoinPacks do
			packCard(i + 1, `{pack.coins} EGGS`, string.upper(pack.name), if i == #M.CoinPacks then "barn" elseif i == 1 then "basket" else "nest", pack.productId, false, false)
		end
		return
	end
	for i, item in Cosmetics.inSlot(currentTab :: Cosmetics.Slot) do
		itemCard(item, i)
	end
end

local function openShop(tab: string?)
	if tab then
		currentTab = tab
	end
	Anim.hide(ui.wheel)
	ui.dim.Visible = true
	ui.dim.BackgroundTransparency = 1
	Anim.tween(ui.dim, 0.25, { BackgroundTransparency = 0.45 })
	Anim.pop(ui.panel)
	Sfx.play("UiOpen")
	refreshShop()
end

local function closeShop()
	Anim.tween(ui.dim, 0.2, { BackgroundTransparency = 1 }).Completed:Once(function()
		ui.dim.Visible = false
	end)
	Anim.hide(ui.panel)
	Sfx.play("UiClose")
end

-- Emote wheel ---------------------------------------------------------------------------------

local function refreshWheel()
	local data = ClientData.get()
	local equipped = if data then data.equipped.Emotes else {}
	for i = 1, Config.Emotes.MaxEquipped do
		local slot = ui.wheel:FindFirstChild(`Slot{i}`)
		if slot then
			local id = equipped[i]
			local item = Cosmetics.get(id)
			setButton(slot, if item then string.upper(item.name) else "EMPTY", if item then YELLOW else GREY)
		end
	end
end

local function toggleWheel()
	if ui.wheel.Visible then
		Anim.hide(ui.wheel)
		Sfx.play("UiClose")
	else
		refreshWheel()
		Anim.pop(ui.wheel)
		Sfx.play("UiOpen")
	end
end

-- Toasts ----------------------------------------------------------------------------------------

type ToastLook = { sprite: string, color: Color3, sound: string }
local TOASTS: { [string]: ToastLook } = {
	coin = { sprite = "eggCoin", color = YELLOW, sound = "Coin" },
	error = { sprite = "close", color = Color3.fromRGB(255, 110, 110), sound = "Error" },
	unlock = { sprite = "star", color = Color3.fromRGB(140, 255, 150), sound = "Purchase" },
	knockout = { sprite = "egg", color = Color3.fromRGB(255, 200, 90), sound = "Knockout" },
	info = { sprite = "info", color = Color3.new(1, 1, 1), sound = "Toast" },
}

local toastOrder = 0
local function toast(text: string, kind: string?)
	local look = TOASTS[kind or "info"] or TOASTS.info
	toastOrder += 1
	local t = Gui.template(hud, "Toast")
	t.LayoutOrder = toastOrder
	Sprites.set(t.Row.Icon, look.sprite)
	t.Row.Text.Text = text
	t.Row.Text.TextColor3 = look.color
	t.Parent = ui.toasts
	Anim.pop(t)
	Sfx.play(look.sound)
	if kind == "knockout" then
		CameraFx.shake(0.25)
	end
	local count = 0
	for _, child in ui.toasts:GetChildren() do
		if child:IsA("Frame") then
			count += 1
		end
	end
	if count > 4 then
		for _, child in ui.toasts:GetChildren() do
			if child:IsA("Frame") and child ~= t then
				child:Destroy()
				break
			end
		end
	end
	task.delay(2.6, function()
		if t.Parent then
			Anim.hide(t, function()
				t:Destroy()
			end)
		end
	end)
end

-- Start ------------------------------------------------------------------------------------------

function MenuUI.start()
	hud = Gui.screen("Hud")
	shop = Gui.screen("Shop")
	emotes = Gui.screen("Emotes")
	ui = {
		coinsPill = Gui.find(hud, "Side/Coins"),
		coinsAmount = Gui.find(hud, "Side/Coins/Row/Amount"),
		plus = Gui.find(hud, "Side/Coins/Row/Plus"),
		shopButton = Gui.find(hud, "Side/Shop"),
		emotesButton = Gui.find(hud, "Side/Emotes"),
		musicButton = Gui.find(hud, "Side/Small/Music"),
		toasts = Gui.find(hud, "Toasts"),
		dim = Gui.find(shop, "Dim"),
		panel = Gui.find(shop, "Panel"),
		shopCoins = Gui.find(shop, "Panel/Body/Header/Coins/Row/Amount"),
		close = Gui.find(shop, "Panel/Body/Header/Close"),
		grid = Gui.find(shop, "Panel/Body/Grid"),
		wheel = Gui.find(emotes, "Wheel"),
		tabs = {},
	}
	for _, tab in Gui.find(shop, "Panel/Body/Tabs"):GetChildren() do
		if tab:IsA("GuiButton") then
			ui.tabs[tab.Name] = tab
			tab.Activated:Connect(function()
				if currentTab ~= tab.Name then
					currentTab = tab.Name
					refreshShop()
				end
			end)
		end
	end
	Anim.autoJuice(shop)
	Anim.autoJuice(emotes)
	Anim.autoJuice(hud)

	ui.shopButton.Activated:Connect(function()
		if ui.panel.Visible then
			closeShop()
		else
			openShop()
		end
	end)
	ui.plus.Activated:Connect(function()
		openShop("Coins")
	end)
	ui.close.Activated:Connect(closeShop)
	ui.dim.Activated:Connect(closeShop)
	ui.emotesButton.Activated:Connect(toggleWheel)
	Gui.find(emotes, "Wheel/Close").Activated:Connect(toggleWheel)
	for i = 1, Config.Emotes.MaxEquipped do
		local slot = ui.wheel:FindFirstChild(`Slot{i}`)
		if slot then
			slot.Activated:Connect(function()
				local data = ClientData.get()
				local id = data and data.equipped.Emotes[i]
				if id then
					EmoteController.request(id)
					toggleWheel()
				else
					openShop("Emote")
				end
			end)
		end
	end
	ui.musicButton.Activated:Connect(function()
		MusicController.setMuted(not MusicController.isMuted())
		setButton(ui.musicButton, nil, nil, if MusicController.isMuted() then "speakerMute" else "speaker")
	end)

	ClientData.Changed:Connect(function()
		updateCoins()
		refreshShop()
		if ui.wheel.Visible then
			refreshWheel()
		end
	end)
	Remotes.Notify.OnClientEvent:Connect(function(text: string, kind: string?)
		toast(text, kind)
	end)
	updateCoins()

	-- Slowly turn the 3D previews while the shop is open.
	RunService.RenderStepped:Connect(function(dt: number)
		if not ui.panel.Visible then
			return
		end
		for _, model in spinning do
			if model.Parent then
				local center = model:GetAttribute("Center")
				local pivot = model:GetPivot()
				if typeof(center) == "Vector3" then
					model:PivotTo(CFrame.new(center) * CFrame.Angles(0, dt * 0.8, 0) * CFrame.new(-center) * pivot)
				end
			end
		end
	end)
end

return MenuUI
