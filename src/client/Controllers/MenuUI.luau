--!strict
-- The menu buttons (Shop, Emotes, music), your golden eggs counter, the Shop window, the emote
-- picker and toast notifications. Uses the Hud, Shop and Emotes ScreenGuis built in Studio.

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

local GREEN = Color3.fromRGB(110, 200, 84)
local GREY = Color3.fromRGB(150, 138, 126)
local ORANGE = Color3.fromRGB(255, 156, 46)
local PINK = Color3.fromRGB(255, 110, 170)
local YELLOW = Color3.fromRGB(255, 204, 64)
local DARK = Color3.fromRGB(44, 29, 20)

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

-- Dark (unselected) style for a Kit.button.
local function darkButton(button: any)
	local inner = button.Border.Inner
	inner.BackgroundColor3 = DARK
	inner.BackgroundTransparency = 0.08
	inner:SetAttribute("Accent", nil)
end

local function robuxPrice(id: number, isPass: boolean, button: any)
	local cached = robuxPrices[id]
	if cached then
		Gui.setButton(button, `R$ {cached}`)
		return
	end
	Gui.setButton(button, "R$ ...")
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
				Gui.setButton(button, `R$ {info.PriceInRobux}`)
			end
		elseif button.Parent then
			Gui.setButton(button, "R$ BUY")
		end
	end)
end

-- Golden eggs counter -------------------------------------------------------------------------

local function updateCoins()
	local data = ClientData.get()
	if not data then
		return
	end
	local target = data.coins
	if target ~= shownCoins then
		Anim.countTo(ui.coinsLabel, shownCoins, target, 0.7)
		Anim.countTo(ui.shopCoins, shownCoins, target, 0.7)
		if target > shownCoins then
			Anim.punch(ui.coins, 0.18)
		end
		shownCoins = target
	end
end

-- Shop ------------------------------------------------------------------------------------------

local function rarityColors(item: Cosmetics.Item): (Color3, Color3)
	local c = Cosmetics.rarityColors[item.rarity]
	return c:Lerp(Color3.new(1, 1, 1), 0.15), c:Lerp(Color3.new(0, 0, 0), 0.25)
end

local function itemCard(item: Cosmetics.Item, order: number)
	local data = ClientData.get()
	local card = Gui.template(shop, "ItemCard")
	local inner = card.Inner
	card.LayoutOrder = order
	card.Visible = false
	local top, bottom = rarityColors(item)
	inner.RarityBar.RarityGradient.Color = ColorSequence.new(top, bottom)
	inner.RarityBar.Rarity.Text = string.upper(item.rarity)
	inner.Glow.ImageColor3 = top
	inner.ItemName.Text = item.name

	-- Preview: 3D for skins and eggs, an icon for everything else.
	if item.slot == "ChickenSkin" or item.slot == "EggSkin" then
		inner.Preview.Visible = true
		inner.PreviewIcon.Visible = false
		local model = if item.slot == "ChickenSkin" then Previews.chicken(item.id) else Previews.egg(item.id)
		table.insert(spinning, Previews.show(inner.Preview, model))
	else
		inner.Preview.Visible = false
		inner.PreviewIcon.Visible = true
		Sprites.set(inner.PreviewIcon, SLOT_SPRITES[item.slot])
		inner.PreviewIcon.ImageColor3 = if item.look.colors then item.look.colors[1]:Lerp(Color3.new(1, 1, 1), 0.5) else Color3.new(1, 1, 1)
	end

	local owned = ClientData.owns(item.id)
	local equipped = ClientData.isEquipped(item.id)
	card.Equipped.Visible = equipped
	card.Lock.Visible = not owned
	local action = inner.Action
	if owned then
		if item.slot == "Emote" then
			Gui.setButton(action, if equipped then "REMOVE" else "EQUIP", if equipped then GREY else GREEN, "")
		else
			Gui.setButton(action, if equipped then "EQUIPPED" else "EQUIP", if equipped then GREY else GREEN, "")
		end
		action.Activated:Connect(function()
			if item.slot == "Emote" or not equipped then
				Remotes.EquipItem:FireServer(item.id)
				Sfx.play("Equip")
				Anim.punch(card, 0.06)
			end
		end)
	elseif item.price then
		local affordable = data ~= nil and data.coins >= item.price
		Gui.setButton(action, tostring(item.price), if affordable then ORANGE else GREY, "eggCoin")
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
			Gui.setButton(action, "SOON", GREY, "")
		else
			Gui.setButton(action, "R$", PINK, "")
			robuxPrice(productId, false, action)
			action.Activated:Connect(function()
				MarketplaceService:PromptProductPurchase(player, productId)
			end)
		end
	end
	if item.rarity == "Epic" or item.rarity == "Legendary" or item.rarity == "Exclusive" then
		Anim.shine(inner.Shine)
	end
	card.Parent = ui.grid
	Anim.juice(action)
	Anim.pop(card, 0.02 * order)
end

local function packCard(order: number, title: string, subtitle: string, sprite: string, id: number, isPass: boolean, owned: boolean)
	local card = Gui.template(shop, "PackCard")
	local inner = card.Inner
	card.LayoutOrder = order
	card.Visible = false
	inner.RarityBar.RarityGradient.Color = ColorSequence.new(Color3.fromRGB(255, 214, 100), Color3.fromRGB(226, 140, 40))
	inner.RarityBar.Rarity.Text = subtitle
	inner.Glow.ImageColor3 = YELLOW
	inner.Preview.Visible = false
	inner.PreviewIcon.Visible = true
	Sprites.set(inner.PreviewIcon, sprite)
	inner.ItemName.Text = title
	card.Lock.Visible = false
	card.Equipped.Visible = owned
	local action = inner.Action
	if owned then
		Gui.setButton(action, "OWNED", GREY, "")
	elseif id == 0 then
		Gui.setButton(action, "SOON", GREY, "")
	else
		Gui.setButton(action, "R$", PINK, "")
		robuxPrice(id, isPass, action)
		action.Activated:Connect(function()
			if isPass then
				MarketplaceService:PromptGamePassPurchase(player, id)
			else
				MarketplaceService:PromptProductPurchase(player, id)
			end
		end)
	end
	Anim.shine(inner.Shine)
	card.Parent = ui.grid
	Anim.juice(action)
	Anim.pop(card, 0.04 * order)
end

local function refreshTabs()
	for id, tab in ui.tabs do
		if id == currentTab then
			Gui.setButton(tab, nil, ORANGE)
		else
			darkButton(tab)
		end
	end
end

local function refreshShop()
	if not ui.panel.Visible then
		return
	end
	refreshTabs()
	for _, child in ui.grid:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	table.clear(spinning)
	ui.grid.CanvasPosition = Vector2.zero
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

local closePicker: () -> ()

local function openShop(tab: string?)
	if tab then
		currentTab = tab
	end
	closePicker()
	ui.dim.Visible = true
	ui.dim.BackgroundTransparency = 1
	Anim.tween(ui.dim, 0.25, { BackgroundTransparency = 0.45 })
	Anim.pop(ui.panel)
	Sfx.play("UiOpen")
	refreshShop()
end

local function closeShop()
	if not ui.panel.Visible then
		return
	end
	Anim.tween(ui.dim, 0.2, { BackgroundTransparency = 1 }).Completed:Once(function(s)
		if s == Enum.PlaybackState.Completed then
			ui.dim.Visible = false
		end
	end)
	Anim.hide(ui.panel)
	Sfx.play("UiClose")
end

-- Emote picker --------------------------------------------------------------------------------

local function refreshPicker()
	local data = ClientData.get()
	local equipped = if data then data.equipped.Emotes else {}
	for i = 1, Config.Emotes.MaxEquipped do
		local slot = ui.slots:FindFirstChild(`Slot{i}`)
		if slot then
			local item = Cosmetics.get(equipped[i])
			Gui.setButton(slot, if item then string.upper(item.name) else "+ ADD")
			slot.Border.Inner.Content.Label.TextColor3 = if item then Color3.fromRGB(255, 246, 228) else Color3.fromRGB(226, 206, 178)
		end
	end
end

local function togglePicker()
	if ui.picker.Visible then
		Anim.hide(ui.picker)
		Sfx.play("UiClose")
	else
		refreshPicker()
		Anim.pop(ui.picker)
		Sfx.play("UiOpen")
	end
end

closePicker = function()
	if ui.picker.Visible then
		Anim.hide(ui.picker)
	end
end

-- Toasts ----------------------------------------------------------------------------------------

type ToastLook = { sprite: string, color: Color3, sound: string }
local TOASTS: { [string]: ToastLook } = {
	coin = { sprite = "eggCoin", color = YELLOW, sound = "Coin" },
	error = { sprite = "close", color = Color3.fromRGB(255, 120, 110), sound = "Error" },
	unlock = { sprite = "star", color = Color3.fromRGB(150, 240, 130), sound = "Purchase" },
	knockout = { sprite = "egg", color = Color3.fromRGB(255, 200, 90), sound = "Knockout" },
	info = { sprite = "info", color = Color3.fromRGB(255, 246, 228), sound = "Toast" },
}

local toastOrder = 0
local function toast(text: string, kind: string?)
	local look = TOASTS[kind or "info"] or TOASTS.info
	toastOrder += 1
	local t = Gui.template(hud, "Toast")
	t.LayoutOrder = toastOrder
	t.Visible = false
	Sprites.set(t.Icon, look.sprite)
	t.Text.Text = text
	t.Text.TextColor3 = look.color
	t.Parent = ui.toasts
	Anim.pop(t)
	Sfx.play(look.sound)
	if kind == "knockout" then
		CameraFx.shake(0.25)
	end
	local list = {}
	for _, child in ui.toasts:GetChildren() do
		if child:IsA("Frame") then
			table.insert(list, child)
		end
	end
	if #list > 3 then
		table.sort(list, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		list[1]:Destroy()
	end
	task.delay(2.8, function()
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
	local hudRoot = Gui.find(hud, "Root")
	ui = {
		coins = Gui.find(hudRoot, "Stats/Inner/Row/Eggs"),
		coinsLabel = Gui.find(hudRoot, "Stats/Inner/Row/Eggs/Label"),
		shopButton = Gui.find(hudRoot, "Buttons/Shop"),
		emotesButton = Gui.find(hudRoot, "Buttons/Emotes"),
		musicButton = Gui.find(hudRoot, "Buttons/Music"),
		toasts = Gui.find(hudRoot, "Toasts"),
		dim = Gui.find(shop, "Root/Dim"),
		panel = Gui.find(shop, "Root/Panel"),
		shopCoins = Gui.find(shop, "Root/Panel/Inner/Header/Coins/Label"),
		close = Gui.find(shop, "Root/Panel/Inner/Header/Close"),
		grid = Gui.find(shop, "Root/Panel/Inner/Grid"),
		picker = Gui.find(emotes, "Root/Picker"),
		slots = Gui.find(emotes, "Root/Picker/Inner/Slots"),
		tabs = {},
	}
	if Gui.isTouch() then
		ui.picker.AnchorPoint = Vector2.new(0, 0.5)
		ui.picker.Position = UDim2.new(0, 164, 0.56, 0)
	else
		-- Just above the Emotes button.
		ui.picker.Position = UDim2.new(0, 132, 1, -68)
	end
	for _, tab in Gui.find(shop, "Root/Panel/Inner/Tabs"):GetChildren() do
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
	ui.coins.Activated:Connect(function()
		openShop("Coins")
	end)
	ui.close.Activated:Connect(closeShop)
	ui.dim.Activated:Connect(closeShop)
	ui.emotesButton.Activated:Connect(togglePicker)
	Gui.find(emotes, "Root/Picker/Inner/Close").Activated:Connect(togglePicker)
	for i = 1, Config.Emotes.MaxEquipped do
		local slot = ui.slots:FindFirstChild(`Slot{i}`)
		if slot then
			slot.Activated:Connect(function()
				local data = ClientData.get()
				local id = data and data.equipped.Emotes[i]
				if id then
					EmoteController.request(id)
					togglePicker()
				else
					openShop("Emote")
				end
			end)
		end
	end
	ui.musicButton.Activated:Connect(function()
		MusicController.setMuted(not MusicController.isMuted())
		Gui.setButton(ui.musicButton, nil, nil, if MusicController.isMuted() then "speakerMute" else "speaker")
	end)

	ClientData.Changed:Connect(function()
		updateCoins()
		refreshShop()
		if ui.picker.Visible then
			refreshPicker()
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
