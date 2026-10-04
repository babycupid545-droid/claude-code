--!strict
-- Music: lobby loop between rounds, round loop while playing, an intense loop in sudden
-- death, crossfading between them. The HUD's music button mutes it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local AssetIds = require(Shared.AssetIds)
local RoundState = require(Shared.RoundState)

local Sfx = require(script.Parent.Parent.Sfx)

local MusicController = {}

local TRACKS = { Lobby = "MusicLobby", Round = "MusicRound", SuddenDeath = "MusicSuddenDeath" }
local VOLUME = 0.5

local sounds: { [string]: Sound } = {}
local current: string? = nil
local muted = false
local duckToken = 0

local function sound(track: string): Sound?
	if sounds[track] then
		return sounds[track]
	end
	local id = AssetIds.get(TRACKS[track])
	if id == "" then
		return nil
	end
	local s = Instance.new("Sound")
	s.Name = "Music" .. track
	s.SoundId = id
	s.Looped = true
	s.Volume = 0
	s.SoundGroup = Sfx.MusicGroup
	s.Parent = SoundService
	sounds[track] = s
	return s
end

local function play(track: string)
	if current == track then
		return
	end
	current = track
	for name, s in sounds do
		if name ~= track then
			local t = TweenService:Create(s, TweenInfo.new(1.2), { Volume = 0 })
			t:Play()
			t.Completed:Once(function()
				if current ~= name then
					s:Pause()
				end
			end)
		end
	end
	local s = sound(track)
	if s then
		if not s.IsPlaying then
			s.TimePosition = 0
			s:Play()
		end
		TweenService:Create(s, TweenInfo.new(1.2), { Volume = VOLUME }):Play()
	end
end

local function refresh()
	local state = RoundState:GetAttribute("State")
	if state == "InRound" and RoundState:GetAttribute("SuddenDeath") == true then
		play("SuddenDeath")
	elseif state == "InRound" or state == "Starting" then
		play("Round")
	else
		play("Lobby")
	end
end

-- Briefly lowers the music under a stinger (win fanfare, sad trombone).
function MusicController.duck(seconds: number)
	local group = Sfx.MusicGroup
	local full = if muted then 0 else 0.55
	TweenService:Create(group, TweenInfo.new(0.2), { Volume = full * 0.25 }):Play()
	-- Only the latest duck brings the music back, so overlapping stingers stay ducked.
	duckToken += 1
	local token = duckToken
	task.delay(seconds, function()
		if token ~= duckToken then
			return
		end
		TweenService:Create(group, TweenInfo.new(1), { Volume = if muted then 0 else 0.55 }):Play()
	end)
end

function MusicController.isMuted(): boolean
	return muted
end

function MusicController.setMuted(value: boolean)
	muted = value
	TweenService:Create(Sfx.MusicGroup, TweenInfo.new(0.4), { Volume = if muted then 0 else 0.55 }):Play()
end

function MusicController.start()
	RoundState:GetAttributeChangedSignal("State"):Connect(refresh)
	RoundState:GetAttributeChangedSignal("SuddenDeath"):Connect(refresh)
	refresh()
end

return MusicController
