--!strict
-- Coins display, the Shop (all cosmetics + Robux coin packs / VIP), the emote picker and
-- toast notifications.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Cosmetics = require(Shared.Cosmetics)
local Remotes = require(Shared.Remotes)

local ClientData = require(script.Parent.Parent.ClientData)
local EmoteController = require(script.Parent.EmoteController)
local Ui = require(script.Parent.Parent.Ui)

local MenuUI = {}

local player = Players.LocalPlayer

type Tab = Cosmetics.Slot | "Coins"
local TABS: { { id: Tab, label: string } } = {
	{ id = "ChickenSkin", label = "🐔 Chickens" },
	{ id = "EggSkin", label = "🥚 Eggs" },
	{ id = "HitEffect", label = "💥 Hits" },
	{ id = "WinEffect", label = "🏆 Wins" },
	{ id = "Emote", label = "😀 Emotes" },
	{ id = "Coins", label = "🪙 Coins" },
}

local GREY = Color3.fromRGB(120, 120, 130)
local GREEN = Color3.fromRGB(70, 190, 90)
local ORANGE = Color3.fromRGB(255, 170, 40)
local PINK = Color3.fromRGB(255, 80, 140)

local gui: ScreenGui
local coinsLabel: TextLabel
local shopFrame: Frame
local grid: ScrollingFrame
local tabButtons: { [string]: TextButton } = {}
local emoteFrame: Frame
local toastList: Frame
local currentTab: Tab = "ChickenSkin"

-- Robux prices are looked up once per product.
local robuxPrices: { [number]: number } = {}
local function robuxLabel(productId: number, isPass: boolean, button: TextButton)
	local cached = robuxPrices[productId]
	if cached then
		button.Text = `R$ {cached}`
		return
	end
	button.Text = "R$ ..."
	task.spawn(function()
		local ok, info = pcall(
			MarketplaceService.GetProductInfoAsync,
			MarketplaceService,
			productId,
			if isPass then Enum.InfoType.GamePass else Enum.InfoType.Product
		)
		if ok and info and type(info.PriceInRobux) == "number" then
			robuxPrices[productId] = info.PriceInRobux
			if button.Parent then
				button.Text = `R$ {info.PriceInRobux}`
			end
		elseif button.Parent then
			button.Text = "R$ Buy"
		end
	end)
end

-- A colour preview for items without art.
local function swatch(item: Cosmetics.Item, parent: Instance)
	local frame = Ui.new("Frame", {
		Size = UDim2.new(1, -12, 0.5, 0),
		Position = UDim2.fromOffset(6, 6),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = parent,
	}, { Ui.corner(10) })
	local colors = item.look.colors
	if colors and #colors > 1 then
		local keys = {}
		for i, c in colors do
			table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), c))
		end
		Ui.new("UIGradient", { Color = ColorSequence.new(keys), Parent = frame })
	elseif colors then
		frame.BackgroundColor3 = colors[1]
	else
		frame.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
	end
	local icon = if item.slot == "Emote"
		then (item.look.text or item.name)
		elseif item.slot == "EggSkin" then "🥚"
		elseif item.slot == "ChickenSkin" then "🐔"
		elseif item.slot == "HitEffect" then "💥"
		else "🏆"
	Ui.label(icon, { Size = UDim2.fromScale(1, 0.7), Position = UDim2.fromScale(0, 0.15), Parent = frame })
end

local function card(order: number): Frame
	return Ui.new("Frame", {
		LayoutOrder = order,
		BackgroundColor3 = Color3.fromRGB(40, 40, 55),
		Parent = grid,
	}, { Ui.corner(12) })
end

local function actionButton(parent: Instance, text: string, color: Color3, onClick: (() -> ())?): TextButton
	local button = Ui.button(text, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -6),
		Size = UDim2.new(1, -12, 0, 32),
		BackgroundColor3 = color,
		Parent = parent,
	})
	if onClick then
		button.Activated:Connect(onClick)
	else
		button.AutoButtonColor = false
	end
	return button
end

local function itemCard(item: Cosmetics.Item, order: number)
	local data = ClientData.get()
	local frame = card(order)
	swatch(item, frame)
	Ui.label(item.name, {
		Position = UDim2.new(0, 6, 0.52, 0),
		Size = UDim2.new(1, -12, 0, 22),
		Parent = frame,
	})
	Ui.label(item.rarity, {
		Position = UDim2.new(0, 6, 0.52, 22),
		Size = UDim2.new(1, -12, 0, 16),
		TextColor3 = Cosmetics.rarityColors[item.rarity],
		Parent = frame,
	})

	local owned = ClientData.owns(item.id)
	local equipped = ClientData.isEquipped(item.id)
	if owned then
		if item.slot == "Emote" then
			actionButton(frame, if equipped then "Unequip" else "Equip", if equipped then GREY else GREEN, function()
				Remotes.EquipItem:FireServer(item.id)
			end)
		elseif equipped then
			actionButton(frame, "Equipped", GREY)
		else
			actionButton(frame, "Equip", GREEN, function()
				Remotes.EquipItem:FireServer(item.id)
			end)
		end
	elseif item.price then
		local affordable = data ~= nil and data.coins >= item.price
		actionButton(frame, `🪙 {item.price}`, if affordable then ORANGE else GREY, function()
			Remotes.BuyItem:FireServer(item.id)
		end)
	elseif item.robux then
		local productId = Config.Monetization.ItemProducts[item.id] or 0
		if productId == 0 then
			actionButton(frame, "Coming soon", GREY)
		else
			local button = actionButton(frame, "R$", PINK, function()
				MarketplaceService:PromptProductPurchase(player, productId)
			end)
			robuxLabel(productId, false, button)
		end
	end
end

local function coinsTab()
	local order = 0
	local data = ClientData.get()
	local passId = Config.Monetization.VipGamePassId
	order += 1
	local vipCard = card(order)
	Ui.label("👑 VIP", { Size = UDim2.new(1, 0, 0.3, 0), Position = UDim2.fromScale(0, 0.08), Parent = vipCard })
	Ui.label(`x{Config.Monetization.VipCoinMultiplier} coins from every round`, {
		Size = UDim2.new(1, -12, 0.25, 0),
		Position = UDim2.new(0, 6, 0.4, 0),
		Font = Enum.Font.GothamBold,
		Parent = vipCard,
	})
	if data and data.vip then
		actionButton(vipCard, "Owned", GREY)
	elseif passId == 0 then
		actionButton(vipCard, "Coming soon", GREY)
	else
		local button = actionButton(vipCard, "R$", PINK, function()
			MarketplaceService:PromptGamePassPurchase(player, passId)
		end)
		robuxLabel(passId, true, button)
	end

	for _, pack in Config.Monetization.CoinPacks do
		order += 1
		local frame = card(order)
		Ui.label(`🪙 {pack.coins}`, { Size = UDim2.new(1, 0, 0.3, 0), Position = UDim2.fromScale(0, 0.08), Parent = frame })
		Ui.label(pack.name, {
			Size = UDim2.new(1, -12, 0.2, 0),
			Position = UDim2.new(0, 6, 0.42, 0),
			Font = Enum.Font.GothamBold,
			Parent = frame,
		})
		if pack.productId == 0 then
			actionButton(frame, "Coming soon", GREY)
		else
			local button = actionButton(frame, "R$", PINK, function()
				MarketplaceService:PromptProductPurchase(player, pack.productId)
			end)
			robuxLabel(pack.productId, false, button)
		end
	end
end

local function refreshShop()
	if not shopFrame.Visible then
		return
	end
	for id, button in tabButtons do
		button.BackgroundColor3 = if id == currentTab then GREEN else ORANGE
	end
	for _, child in grid:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	if currentTab == "Coins" then
		coinsTab()
		return
	end
	for i, item in Cosmetics.inSlot(currentTab :: Cosmetics.Slot) do
		itemCard(item, i)
	end
end

local function refreshEmotes()
	for _, child in emoteFrame:GetChildren() do
		if child:IsA("GuiButton") then
			child:Destroy()
		end
	end
	local data = ClientData.get()
	if not data then
		return
	end
	if #data.equipped.Emotes == 0 then
		local hint = Ui.button("Equip emotes in the Shop", { Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = GREY, Parent = emoteFrame })
		hint.Activated:Connect(function()
			emoteFrame.Visible = false
			currentTab = "Emote"
			shopFrame.Visible = true
			refreshShop()
		end)
	end
	for i, id in data.equipped.Emotes do
		local item = Cosmetics.get(id)
		if item then
			local button = Ui.button(`{i}  {item.name}`, {
				LayoutOrder = i,
				Size = UDim2.new(1, 0, 0, 44),
				Parent = emoteFrame,
			})
			button.Activated:Connect(function()
				EmoteController.request(id)
				emoteFrame.Visible = false
			end)
		end
	end
end

local function refresh()
	local data = ClientData.get()
	coinsLabel.Text = if data then `🪙 {data.coins}{if data.vip then "  👑" else ""}` else "🪙 ..."
	refreshShop()
	refreshEmotes()
end

local function toast(text: string)
	local label = Ui.label(text, {
		Size = UDim2.new(1, 0, 0, 30),
		TextColor3 = Color3.fromRGB(255, 230, 120),
		Parent = toastList,
	})
	task.delay(2.5, function()
		TweenService:Create(label, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		task.wait(0.5)
		label:Destroy()
	end)
end

local function build()
	gui = Ui.new("ScreenGui", {
		Name = "MenuGui",
		ResetOnSpawn = false,
		DisplayOrder = 5,
		Parent = player:WaitForChild("PlayerGui"),
	})

	local side = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.42, 0),
		Size = UDim2.fromOffset(130, 170),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Ui.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	coinsLabel = Ui.label("🪙 ...", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 34), Parent = side })
	local shopButton = Ui.button("🛒 Shop", { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 50), Parent = side })
	local emoteButton = Ui.button("😀 Emotes", { LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 50), Parent = side })

	emoteFrame = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 152, 0.42, 0),
		Size = UDim2.fromOffset(200, 210),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	}, {
		Ui.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	shopFrame = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.9, 0.8),
		BackgroundColor3 = Color3.fromRGB(25, 25, 35),
		BackgroundTransparency = 0.05,
		Visible = false,
		Parent = gui,
	}, { Ui.corner(16), Ui.stroke(3), Ui.new("UISizeConstraint", { MaxSize = Vector2.new(780, 520) }) })
	Ui.label("Shop", {
		Position = UDim2.fromOffset(16, 8),
		Size = UDim2.new(0.5, 0, 0, 36),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = shopFrame,
	})
	local close = Ui.button("X", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(44, 40),
		BackgroundColor3 = Color3.fromRGB(220, 60, 60),
		Parent = shopFrame,
	})
	close.Activated:Connect(function()
		shopFrame.Visible = false
	end)

	local tabs = Ui.new("ScrollingFrame", {
		Position = UDim2.fromOffset(12, 54),
		Size = UDim2.new(1, -24, 0, 44),
		BackgroundTransparency = 1,
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 4,
		Parent = shopFrame,
	}, {
		Ui.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for i, tab in TABS do
		local button = Ui.button(tab.label, { LayoutOrder = i, Size = UDim2.fromOffset(118, 38), Parent = tabs })
		button.Activated:Connect(function()
			currentTab = tab.id
			refreshShop()
		end)
		tabButtons[tab.id] = button
	end

	grid = Ui.new("ScrollingFrame", {
		Position = UDim2.fromOffset(12, 106),
		Size = UDim2.new(1, -24, 1, -118),
		BackgroundTransparency = 1,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 6,
		Parent = shopFrame,
	}, {
		Ui.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(140, 180),
			CellPadding = UDim2.fromOffset(10, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	toastList = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -190),
		Size = UDim2.fromOffset(420, 120),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Ui.new("UIListLayout", {
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	shopButton.Activated:Connect(function()
		shopFrame.Visible = not shopFrame.Visible
		emoteFrame.Visible = false
		refreshShop()
	end)
	emoteButton.Activated:Connect(function()
		emoteFrame.Visible = not emoteFrame.Visible
		shopFrame.Visible = false
		refreshEmotes()
	end)
end

function MenuUI.start()
	build()
	ClientData.Changed:Connect(refresh)
	Remotes.Notify.OnClientEvent:Connect(toast)
	refresh()
end

return MenuUI
