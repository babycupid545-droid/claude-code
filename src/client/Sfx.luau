--!strict
-- Plays sound effects from the single Sfx sprite file (AssetIds.Sfx), using regions listed
-- in SoundSprites. A Sound named like the effect in ReplicatedStorage.Assets.Sounds
-- overrides it, so any effect can be swapped for a Creator Store sound.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage.Shared
local AssetIds = require(Shared.AssetIds)
local Assets = require(Shared.Assets)
local SoundSprites = require(Shared.SoundSprites)

local Sfx = {}

export type Options = {
	parent: any, -- a part/attachment for 3D sound; nil for 2D
	volume: number?,
	pitch: number?,
	pitchJitter: number?,
}

local SPRITE_ID = AssetIds.get("Sfx")

local function group(name: string, volume: number): SoundGroup
	local existing = SoundService:FindFirstChild(name)
	if existing and existing:IsA("SoundGroup") then
		return existing
	end
	local g = Instance.new("SoundGroup")
	g.Name = name
	g.Volume = volume
	g.Parent = SoundService
	return g
end

Sfx.Group = group("SfxGroup", 1)
Sfx.MusicGroup = group("MusicGroup", 0.55)

local last: { [string]: number } = {}

local function makeSound(name: string, opts: Options?): (Sound?, number)
	local override = Assets.find("Sounds", name)
	local region = SoundSprites[name]
	local sound: Sound
	local length = 2
	if override and override:IsA("Sound") then
		sound = override:Clone()
		length = if sound.TimeLength > 0 then sound.TimeLength else 3
	elseif region and SPRITE_ID ~= "" then
		sound = Instance.new("Sound")
		sound.SoundId = SPRITE_ID
		sound.PlaybackRegionsEnabled = true
		sound.PlaybackRegion = NumberRange.new(region.start, region.start + region.length)
		sound.Volume = region.volume
		length = region.length
		if region.looped then
			sound.Looped = true
			sound.LoopRegion = sound.PlaybackRegion
		end
	else
		return nil, 0
	end
	sound.Name = name
	sound.SoundGroup = Sfx.Group
	if opts then
		if opts.volume then
			sound.Volume *= opts.volume
		end
		local pitch = opts.pitch or 1
		if opts.pitchJitter then
			pitch *= 1 + (math.random() * 2 - 1) * opts.pitchJitter
		end
		sound.PlaybackSpeed = pitch
		length /= pitch
		if opts.parent then
			sound.RollOffMode = Enum.RollOffMode.InverseTapered
			sound.RollOffMinDistance = 12
			sound.RollOffMaxDistance = 220
		end
	end
	return sound, length
end

-- Plays a one-shot. Returns the Sound (or nil if nothing is uploaded yet).
function Sfx.play(name: string, opts: Options?): Sound?
	-- Don't stack the exact same sound many times in one frame.
	local now = os.clock()
	if last[name] and now - last[name] < 0.03 then
		return nil
	end
	last[name] = now
	local sound, length = makeSound(name, opts)
	if not sound then
		return nil
	end
	sound.Parent = if opts and opts.parent then opts.parent else SoundService
	sound:Play()
	Debris:AddItem(sound, length + 0.3)
	return sound
end

-- Plays a looping sound until you Destroy() it (engines, wind).
function Sfx.loop(name: string, opts: Options?): Sound?
	local sound = makeSound(name, opts)
	if not sound then
		return nil
	end
	sound.Looped = true
	sound.Parent = if opts and opts.parent then opts.parent else SoundService
	sound:Play()
	return sound
end

-- 3D one-shot at a world position.
function Sfx.playAt(name: string, position: Vector3, opts: Options?): Sound?
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.one
	holder.Position = position
	holder.Parent = workspace:FindFirstChild("ClientEffects") or workspace
	local o: Options = { parent = holder }
	if opts then
		o.volume, o.pitch, o.pitchJitter = opts.volume, opts.pitch, opts.pitchJitter
	end
	local sound = Sfx.play(name, o)
	Debris:AddItem(holder, 4)
	return sound
end

return Sfx
