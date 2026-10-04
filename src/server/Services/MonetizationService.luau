--!strict
-- Robux purchases: coin packs and Robux-only cosmetics (developer products), and the VIP
-- game pass. Receipts are only confirmed to Roblox once the grant has been saved, so a
-- server crash can never take someone's Robux without giving them the item.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Cosmetics = require(Shared.Cosmetics)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)

local MonetizationService = {}

local MAX_RECEIPTS = 50

-- productId -> function that grants it
local grants: { [number]: (Player) -> () } = {}

local function registerProducts()
	for _, pack in Config.Monetization.CoinPacks do
		if pack.productId ~= 0 then
			grants[pack.productId] = function(player)
				DataService.addCoins(player, pack.coins)
				Remotes.Notify:FireClient(player, `+{pack.coins} golden eggs! Thanks for your support!`, "coin", pack.coins)
			end
		end
	end
	for itemId, productId in Config.Monetization.ItemProducts do
		local item = Cosmetics.get(itemId)
		if productId ~= 0 and item then
			grants[productId] = function(player)
				DataService.grant(player, itemId)
				Remotes.Notify:FireClient(player, `Unlocked {item.name}!`, "unlock", 0)
			end
		end
	end
end

local function processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local grant = grants[receipt.ProductId]
	if not player or not grant then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local profile = DataService.getProfile(player)
	if not profile or not profile:IsActive() then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local purchaseId = receipt.PurchaseId :: string
	local ids = profile.Data.PurchaseIds
	if not table.find(ids, purchaseId) then
		while #ids >= MAX_RECEIPTS do
			table.remove(ids, 1)
		end
		table.insert(ids, purchaseId)
		grant(player)
	end

	-- Only report success once the receipt id is in a successful save.
	local function isSaved(): boolean
		local saved = profile.LastSavedData
		return saved ~= nil and saved.PurchaseIds ~= nil and table.find(saved.PurchaseIds, purchaseId) ~= nil
	end
	if not isSaved() then
		profile:Save()
	end
	while not isSaved() do
		if not profile:IsActive() then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		profile.OnAfterSave:Wait()
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService.init()
	registerProducts()
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if purchased and passId == Config.Monetization.VipGamePassId and passId ~= 0 then
			DataService.setVip(player, true)
			Remotes.Notify:FireClient(player, "You're VIP! Double golden eggs from every round.", "unlock", 0)
		end
	end)
end

return MonetizationService
