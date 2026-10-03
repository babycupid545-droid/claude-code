--!strict
-- Every cosmetic in the game. The shop, inventory, saving and rendering all read this list.
--
-- An item's id is also the name of its art in ReplicatedStorage.Assets/<folder> (see
-- docs/ASSETS.md). Until that art exists, `look` describes a generated stand-in.

export type Slot = "ChickenSkin" | "EggSkin" | "HitEffect" | "WinEffect" | "Emote"
export type Rarity = "Common" | "Rare" | "Epic" | "Legendary" | "Exclusive"

export type Look = {
	colors: { Color3 }?, -- body / egg / particle colours (several = cycled or mixed)
	comb: Color3?,
	beak: Color3?,
	material: Enum.Material?,
	fire: boolean?,
	sparkles: boolean?,
	trail: Color3?,
	special: string?, -- slot-specific behaviour, see the renderers
	text: string?,
	count: number?,
}

export type Item = {
	id: string,
	slot: Slot,
	name: string,
	rarity: Rarity,
	price: number?, -- coins; nil when not sold for coins
	robux: boolean?, -- sold for Robux (Config.Monetization.ItemProducts)
	default: boolean?, -- everyone owns it from the start
	look: Look,
}

local WHITE = Color3.fromRGB(245, 245, 240)
local RED = Color3.fromRGB(220, 40, 40)
local ORANGE = Color3.fromRGB(255, 160, 30)
local RAINBOW = {
	Color3.fromRGB(255, 70, 70),
	Color3.fromRGB(255, 160, 40),
	Color3.fromRGB(255, 230, 60),
	Color3.fromRGB(80, 220, 100),
	Color3.fromRGB(60, 150, 255),
	Color3.fromRGB(170, 90, 255),
}

local items: { Item } = {
	-- Chicken skins ------------------------------------------------------------------
	{ id = "Classic", slot = "ChickenSkin", name = "Classic", rarity = "Common", default = true,
		look = { colors = { WHITE }, comb = RED, beak = ORANGE } },
	{ id = "BrownHen", slot = "ChickenSkin", name = "Brown Hen", rarity = "Common", price = 250,
		look = { colors = { Color3.fromRGB(150, 95, 55) }, comb = RED, beak = ORANGE } },
	{ id = "Bantam", slot = "ChickenSkin", name = "Bantam", rarity = "Common", price = 400,
		look = { colors = { Color3.fromRGB(215, 120, 50), Color3.fromRGB(60, 50, 45) }, comb = RED, beak = ORANGE } },
	{ id = "Midnight", slot = "ChickenSkin", name = "Midnight", rarity = "Rare", price = 900,
		look = { colors = { Color3.fromRGB(35, 35, 42) }, comb = Color3.fromRGB(200, 30, 70), beak = Color3.fromRGB(240, 200, 60) } },
	{ id = "RubberDuck", slot = "ChickenSkin", name = "Rubber Duck?", rarity = "Rare", price = 1200,
		look = { colors = { Color3.fromRGB(255, 220, 40) }, beak = ORANGE } },
	{ id = "Golden", slot = "ChickenSkin", name = "Golden Chicken", rarity = "Epic", price = 3000,
		look = { colors = { Color3.fromRGB(240, 190, 50) }, comb = RED, beak = ORANGE, material = Enum.Material.Foil, sparkles = true } },
	{ id = "Robo", slot = "ChickenSkin", name = "Robo-Chicken", rarity = "Legendary", price = 7500,
		look = { colors = { Color3.fromRGB(170, 175, 185) }, comb = Color3.fromRGB(60, 200, 255), beak = Color3.fromRGB(90, 90, 100), material = Enum.Material.DiamondPlate } },
	{ id = "Rainbow", slot = "ChickenSkin", name = "Rainbow Rooster", rarity = "Exclusive", robux = true,
		look = { colors = RAINBOW, comb = Color3.fromRGB(255, 70, 70), beak = ORANGE, sparkles = true } },

	-- Egg skins ----------------------------------------------------------------------
	{ id = "ClassicEgg", slot = "EggSkin", name = "Classic Egg", rarity = "Common", default = true,
		look = { colors = { Color3.fromRGB(255, 250, 235) } } },
	{ id = "BrownEgg", slot = "EggSkin", name = "Brown Egg", rarity = "Common", price = 200,
		look = { colors = { Color3.fromRGB(190, 130, 80) } } },
	{ id = "SpeckledEgg", slot = "EggSkin", name = "Speckled Egg", rarity = "Common", price = 350,
		look = { colors = { Color3.fromRGB(230, 215, 190) }, material = Enum.Material.Granite } },
	{ id = "EasterEgg", slot = "EggSkin", name = "Easter Egg", rarity = "Rare", price = 900,
		look = { colors = { Color3.fromRGB(255, 170, 200), Color3.fromRGB(170, 220, 255), Color3.fromRGB(200, 255, 170), Color3.fromRGB(255, 240, 150) } } },
	{ id = "RottenEgg", slot = "EggSkin", name = "Rotten Egg", rarity = "Rare", price = 1100,
		look = { colors = { Color3.fromRGB(120, 150, 60) }, trail = Color3.fromRGB(140, 200, 60) } },
	{ id = "GoldenEgg", slot = "EggSkin", name = "Golden Egg", rarity = "Epic", price = 2500,
		look = { colors = { Color3.fromRGB(245, 195, 50) }, material = Enum.Material.Foil, sparkles = true } },
	{ id = "FireballEgg", slot = "EggSkin", name = "Fireball", rarity = "Legendary", price = 6000,
		look = { colors = { Color3.fromRGB(255, 120, 30) }, material = Enum.Material.Neon, fire = true } },
	{ id = "DiamondEgg", slot = "EggSkin", name = "Diamond Egg", rarity = "Exclusive", robux = true,
		look = { colors = { Color3.fromRGB(150, 230, 255) }, material = Enum.Material.Glass, sparkles = true, trail = Color3.fromRGB(150, 230, 255) } },

	-- Hit effects --------------------------------------------------------------------
	{ id = "Splat", slot = "HitEffect", name = "Yolk Splat", rarity = "Common", default = true,
		look = { colors = { Color3.fromRGB(255, 220, 60), Color3.fromRGB(255, 255, 240) }, count = 18 } },
	{ id = "FeatherPuff", slot = "HitEffect", name = "Feather Puff", rarity = "Common", price = 300,
		look = { colors = { WHITE }, count = 25 } },
	{ id = "ConfettiPop", slot = "HitEffect", name = "Confetti Pop", rarity = "Rare", price = 800,
		look = { colors = RAINBOW, count = 35 } },
	{ id = "Sparkle", slot = "HitEffect", name = "Sparkle", rarity = "Epic", price = 2000,
		look = { colors = { Color3.fromRGB(150, 220, 255), Color3.fromRGB(255, 255, 255) }, count = 30, special = "Glow" } },
	{ id = "Boom", slot = "HitEffect", name = "Boom", rarity = "Legendary", price = 5000,
		look = { colors = { Color3.fromRGB(255, 140, 30), Color3.fromRGB(80, 80, 80) }, count = 30, special = "Explosion" } },
	{ id = "LoveTap", slot = "HitEffect", name = "Love Tap", rarity = "Exclusive", robux = true,
		look = { colors = { Color3.fromRGB(255, 90, 150), Color3.fromRGB(255, 180, 210) }, count = 30, special = "Glow", text = "❤" } },

	-- Win effects --------------------------------------------------------------------
	{ id = "Confetti", slot = "WinEffect", name = "Confetti", rarity = "Common", default = true,
		look = { colors = RAINBOW, special = "Burst" } },
	{ id = "GoldenRain", slot = "WinEffect", name = "Golden Rain", rarity = "Rare", price = 1500,
		look = { colors = { Color3.fromRGB(255, 210, 60), Color3.fromRGB(255, 240, 150) }, special = "Rain" } },
	{ id = "Fireworks", slot = "WinEffect", name = "Fireworks", rarity = "Epic", price = 3500,
		look = { colors = RAINBOW, special = "Fireworks" } },
	{ id = "Pillar", slot = "WinEffect", name = "Pillar of Light", rarity = "Legendary", price = 8000,
		look = { colors = { Color3.fromRGB(255, 250, 200) }, special = "Pillar" } },
	{ id = "Supernova", slot = "WinEffect", name = "Supernova", rarity = "Exclusive", robux = true,
		look = { colors = RAINBOW, special = "Supernova" } },

	-- Emotes -------------------------------------------------------------------------
	{ id = "Bawk", slot = "Emote", name = "Bawk!", rarity = "Common", default = true,
		look = { special = "Text", text = "BAWK!" } },
	{ id = "Spin", slot = "Emote", name = "Spin", rarity = "Common", price = 300,
		look = { special = "Spin" } },
	{ id = "Hop", slot = "Emote", name = "Happy Hop", rarity = "Common", price = 300,
		look = { special = "Hop" } },
	{ id = "LayEgg", slot = "Emote", name = "Lay an Egg", rarity = "Rare", price = 1000,
		look = { special = "LayEgg", text = "plop" } },
	{ id = "Dance", slot = "Emote", name = "Chicken Dance", rarity = "Epic", price = 2500,
		look = { special = "Dance", text = "♪ ♫ ♪" } },
	{ id = "Flex", slot = "Emote", name = "Flex", rarity = "Exclusive", robux = true,
		look = { special = "Text", text = "💪 TOO EASY 💪", sparkles = true } },
}

local SLOTS: { Slot } = { "ChickenSkin", "EggSkin", "HitEffect", "WinEffect", "Emote" }

-- Where an item's art lives under ReplicatedStorage.Assets.
local ASSET_FOLDERS: { [Slot]: string } = {
	ChickenSkin = "Chickens",
	EggSkin = "EggSkins",
	HitEffect = "HitEffects",
	WinEffect = "WinEffects",
	Emote = "Emotes",
}

local RARITY_COLORS: { [Rarity]: Color3 } = {
	Common = Color3.fromRGB(170, 170, 170),
	Rare = Color3.fromRGB(70, 150, 255),
	Epic = Color3.fromRGB(180, 90, 255),
	Legendary = Color3.fromRGB(255, 170, 30),
	Exclusive = Color3.fromRGB(255, 70, 120),
}

local byId: { [string]: Item } = {}
local defaults: { [Slot]: string } = {}
for _, item in items do
	assert(byId[item.id] == nil, `duplicate cosmetic id {item.id}`)
	byId[item.id] = item
	if item.default and not defaults[item.slot] then
		defaults[item.slot] = item.id
	end
end

local Cosmetics = {
	list = items,
	slots = SLOTS,
	assetFolders = ASSET_FOLDERS,
	rarityColors = RARITY_COLORS,
}

function Cosmetics.get(id: string?): Item?
	return if id then byId[id] else nil
end

function Cosmetics.default(slot: Slot): string
	return defaults[slot]
end

-- The item if it exists and is in that slot, otherwise the slot's default item.
function Cosmetics.resolve(slot: Slot, id: string?): Item
	local item = Cosmetics.get(id)
	if item and item.slot == slot then
		return item
	end
	return byId[defaults[slot]]
end

function Cosmetics.inSlot(slot: Slot): { Item }
	local result = {}
	for _, item in items do
		if item.slot == slot then
			table.insert(result, item)
		end
	end
	return result
end

return Cosmetics
