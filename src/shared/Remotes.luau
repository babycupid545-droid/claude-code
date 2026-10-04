--!strict
-- Every RemoteEvent the game uses. The server creates them; clients wait for them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = {
	-- client -> server
	"Vote", -- (modeId: string)
	"ShootEgg", -- (direction: Vector3, localId: number)
	"LaunchRageCar", -- (lane: number) send a car down that lane (it drives the lane's way)
	"BuyItem", -- (itemId: string) buy a cosmetic with coins
	"EquipItem", -- (itemId: string) equip (emotes: toggle in/out of the emote wheel)
	"Emote", -- (itemId: string)
	"SetAfk", -- (afk: boolean) go AFK (sit out the next rounds) or come back
	"EquipTitle", -- (titleId: string) wear an unlocked title ("" = none)
	"RerollQuest", -- (index: number) swap a daily quest (free once a day)
	"ClaimTier", -- (track: "free" | "premium", tier: number) claim a season pass reward
	-- server -> client
	"EggFired", -- (eggId: string, shooterUserId: number, origin: Vector3, velocity: Vector3, firedAt: number, eggSkin: string, mega: boolean, special: string)
	"EggHit", -- (eggId: string, position: Vector3, hitEffect: string, special: string) special "Bounce" = ricochet
	"Knockback", -- (velocity: Vector3)
	"RageCar", -- (car: TrafficSchedule.Car)
	"ChickenSplat", -- (userId: number, position: Vector3, velocity: Vector3)
	"Feed", -- (text: string, icon: string) icon is a UI sprite name
	"WinEffect", -- (winners: { { userId: number, effect: string } })
	"DataSync", -- (snapshot: DataSnapshot) the local player's saved data
	"PlayEmote", -- (userId: number, itemId: string)
	"Sprinkler", -- (index: number, phase: "warn" | "burst")
	"EggPickup", -- (position: Vector3, userId: number) a golden egg was collected
	"EggShot", -- (userId: number) someone fired an egg (for the shooting animation)
	"Notify", -- (text: string, kind: "coin" | "error" | "unlock" | "knockout" | "info", amount: number)
	"XpGain", -- (amount: number) the local player earned XP
	"LevelUp", -- (level: number, coins: number, titles: { string }) the local player levelled up
	"PowerupFx", -- (fx: "Pickup" | "ShieldPop" | "Steal" | "Bounty" | "BountyClaimed", position: Vector3, userId: number, detail: string) detail = power-up id or egg amount
}

local folder: Instance
if RunService:IsServer() then
	local f = Instance.new("Folder")
	f.Name = "Remotes"
	for _, name in NAMES do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = f
	end
	f.Parent = ReplicatedStorage
	folder = f
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

local Remotes = {}
for _, name in NAMES do
	Remotes[name] = folder:WaitForChild(name) :: RemoteEvent
end

return Remotes :: { [string]: RemoteEvent }
