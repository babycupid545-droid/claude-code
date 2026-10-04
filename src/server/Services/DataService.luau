--!strict
-- Saved player data (coins, cosmetics, stats) using ProfileStore, which session-locks each
-- profile so items can't be duplicated by joining two servers.
--
-- In Studio, data only saves if Game Settings > Security > "Enable Studio Access to API
-- Services" is on; otherwise ProfileStore uses a temporary in-memory store.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Cosmetics = require(Shared.Cosmetics)
local PlayerData = require(Shared.PlayerData)
local Remotes = require(Shared.Remotes)

-- ProfileStore's own generic types fight strict mode, so describe just what we use.
local ProfileStore = require(script.Parent.Parent.Packages.ProfileStore) :: any

local DataService = {}

type Data = PlayerData.Data
type Signal = { Connect: (Signal, (...any) -> ()) -> any, Wait: (Signal) -> ...any }
export type Profile = {
	Data: Data,
	LastSavedData: Data?,
	OnSessionEnd: Signal,
	OnAfterSave: Signal,
	IsActive: (Profile) -> boolean,
	Save: (Profile) -> (),
	EndSession: (Profile) -> (),
	Reconcile: (Profile) -> (),
	AddUserId: (Profile, number) -> (),
}

local SINGLE_SLOTS: { Cosmetics.Slot } = { "ChickenSkin", "EggSkin", "HitEffect", "WinEffect" }

local STORE_NAME = "PlayerData_v1"

local store = ProfileStore.New(STORE_NAME, PlayerData.template())
local profiles: { [Player]: Profile } = {}
local vip: { [Player]: boolean } = {}
local loadedEvent = Instance.new("BindableEvent")

-- Signal fired with (player) once a player's data is ready.
DataService.Loaded = loadedEvent.Event

local function snapshot(player: Player, data: Data): PlayerData.Snapshot
	return {
		coins = data.Coins,
		owned = data.Owned,
		equipped = data.Equipped,
		stats = data.Stats,
		vip = vip[player] == true,
	}
end

local function updateLeaderstats(player: Player, data: Data)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		return
	end
	local wins = stats:FindFirstChild("Wins") :: IntValue?
	local coins = stats:FindFirstChild("Coins") :: IntValue?
	if wins then
		wins.Value = data.Stats.Wins
	end
	if coins then
		coins.Value = data.Coins
	end
end

function DataService.sync(player: Player)
	local profile = profiles[player]
	if profile then
		updateLeaderstats(player, profile.Data)
		Remotes.DataSync:FireClient(player, snapshot(player, profile.Data))
	end
end

-- Fixes data that no longer matches the catalog (removed items, too many emotes).
local function sanitize(data: Data)
	local e = data.Equipped
	for _, slot in SINGLE_SLOTS do
		local current = (e :: any)[slot]
		local s: any = slot
		if not PlayerData.owns(data.Owned, current) or Cosmetics.resolve(s, current).id ~= current then
			(e :: any)[slot] = Cosmetics.default(s)
		end
	end
	local emotes = {}
	for _, id in e.Emotes do
		local item = Cosmetics.get(id)
		if item and item.slot == "Emote" and PlayerData.owns(data.Owned, id) and not table.find(emotes, id) then
			table.insert(emotes, id)
		end
		if #emotes >= Config.Emotes.MaxEquipped then
			break
		end
	end
	e.Emotes = emotes
end

local function onPlayerAdded(player: Player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local wins = Instance.new("IntValue")
	wins.Name = "Wins"
	wins.Parent = stats
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Parent = stats
	stats.Parent = player

	local profile: Profile? = store:StartSessionAsync(`Player_{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if profile == nil then
		player:Kick("Your chicken data couldn't load. Please rejoin!")
		return
	end
	profile:AddUserId(player.UserId)
	profile:Reconcile()
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		player:Kick("Your data was opened on another server. Please rejoin!")
	end)
	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	sanitize(profile.Data)
	profiles[player] = profile

	if Config.Monetization.VipGamePassId ~= 0 then
		local ok, owns = pcall(
			MarketplaceService.UserOwnsGamePassAsync,
			MarketplaceService,
			player.UserId,
			Config.Monetization.VipGamePassId
		)
		vip[player] = ok and owns == true
	end

	DataService.sync(player)
	loadedEvent:Fire(player)
end

function DataService.getProfile(player: Player): Profile?
	return profiles[player]
end

function DataService.get(player: Player): Data?
	local profile = profiles[player]
	return if profile then profile.Data else nil
end

-- Yields until the player's data is ready (or they leave / it times out).
function DataService.waitFor(player: Player, timeout: number?): Data?
	local deadline = os.clock() + (timeout or 30)
	while not profiles[player] and player.Parent == Players and os.clock() < deadline do
		task.wait(0.1)
	end
	return DataService.get(player)
end

function DataService.equipped(player: Player, slot: Cosmetics.Slot): string
	local data = DataService.get(player)
	if not data or slot == "Emote" then
		return Cosmetics.default(slot)
	end
	return Cosmetics.resolve(slot, (data.Equipped :: any)[slot]).id
end

function DataService.isVip(player: Player): boolean
	return vip[player] == true
end

function DataService.setVip(player: Player, value: boolean)
	vip[player] = value
	DataService.sync(player)
end

-- Gameplay rewards are multiplied for VIPs; purchases are not.
function DataService.reward(player: Player, amount: number, reason: string)
	local data = DataService.get(player)
	if not data or amount <= 0 then
		return
	end
	if vip[player] then
		amount *= Config.Monetization.VipCoinMultiplier
	end
	data.Coins += amount
	DataService.sync(player)
	Remotes.Notify:FireClient(player, `+{amount} eggs {reason}`, "coin", amount)
end

function DataService.addCoins(player: Player, amount: number)
	local data = DataService.get(player)
	if data then
		data.Coins += amount
		DataService.sync(player)
	end
end

function DataService.addStat(player: Player, stat: "Wins" | "Rounds" | "Knockouts", amount: number)
	local data = DataService.get(player)
	if data then
		data.Stats[stat] += amount
		DataService.sync(player)
	end
end

function DataService.owns(player: Player, itemId: string): boolean
	local data = DataService.get(player)
	return data ~= nil and PlayerData.owns(data.Owned, itemId)
end

function DataService.grant(player: Player, itemId: string)
	local data = DataService.get(player)
	if data and Cosmetics.get(itemId) then
		data.Owned[itemId] = true
		DataService.sync(player)
	end
end

local equippedChanged = Instance.new("BindableEvent")
-- Signal fired with (player, slot) when a player equips something.
DataService.EquippedChanged = equippedChanged.Event

local function onBuy(player: Player, itemId: unknown)
	if type(itemId) ~= "string" then
		return
	end
	local data = DataService.get(player)
	local item = Cosmetics.get(itemId)
	if not data or not item or not item.price then
		return
	end
	if PlayerData.owns(data.Owned, itemId) then
		return
	end
	if data.Coins < item.price then
		Remotes.Notify:FireClient(player, "Not enough golden eggs!", "error", 0)
		return
	end
	data.Coins -= item.price
	data.Owned[itemId] = true
	DataService.sync(player)
	Remotes.Notify:FireClient(player, `Unlocked {item.name}!`, "unlock", 0)
end

local function onEquip(player: Player, itemId: unknown)
	if type(itemId) ~= "string" then
		return
	end
	local data = DataService.get(player)
	local item = Cosmetics.get(itemId)
	if not data or not item or not PlayerData.owns(data.Owned, itemId) then
		return
	end
	if item.slot == "Emote" then
		local emotes = data.Equipped.Emotes
		local index = table.find(emotes, itemId)
		if index then
			table.remove(emotes, index)
		elseif #emotes < Config.Emotes.MaxEquipped then
			table.insert(emotes, itemId)
		else
			Remotes.Notify:FireClient(player, `You can equip {Config.Emotes.MaxEquipped} emotes. Unequip one first.`, "error", 0)
			return
		end
	else
		(data.Equipped :: any)[item.slot] = itemId
	end
	DataService.sync(player)
	equippedChanged:Fire(player, item.slot)
end

function DataService.init()
	Remotes.BuyItem.OnServerEvent:Connect(onBuy)
	Remotes.EquipItem.OnServerEvent:Connect(onEquip)
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local profile = profiles[player]
		profiles[player] = nil
		vip[player] = nil
		if profile then
			profile:EndSession()
		end
	end)
end

return DataService
