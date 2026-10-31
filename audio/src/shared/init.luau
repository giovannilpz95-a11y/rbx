--[[
	GameAudio: the one place the game plays sound from (client only).

		local GameAudio = require(ReplicatedStorage.GameAudio)
		GameAudio.play("Coin")                       -- a named sound from Sounds.luau
		GameAudio.play("PopMatch", { pitch = 4 })    -- 4 semitones up
		GameAudio.playCues(cues)                     -- a list from FarmCues / CropPopCues
		GameAudio.setMusic("Puzzle")                 -- crossfade to another context's music (and ambience)
		GameAudio.setWorld("Visit")                  -- the music for where you are when no puzzle is open
		local hum = GameAudio.attachLoop("FactoryHum", part)  -- a loop that plays from a part
		hum.stop()
		GameAudio.setAmbience("AmbienceFarm")        -- or set the ambience bed by hand
		GameAudio.setVolume("Music", 0.5)            -- groups: Music, Ambience, Effects, Ui
		GameAudio.setMuted("Music", true)

	Volume groups are SoundGroups under SoundService.GameAudio, so the settings screen
	only changes a group's volume. Sounds without an uploaded asset yet stay silent (and
	Studio prints their name once), so the hooks can be tested before the upload.
]]

local ContentProvider = game:GetService("ContentProvider")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Sounds = require(script.Sounds)
local Mixer = require(script.Mixer)
local FarmCues = require(script.FarmCues)
local CropPopCues = require(script.CropPopCues)

local GameAudio = {}

GameAudio.Sounds = Sounds
GameAudio.FarmCues = FarmCues
GameAudio.CropPopCues = CropPopCues
GameAudio.stats = {} :: { [string]: number } -- name -> times asked to play (for tests and Studio checks)

local mixer = Mixer.new(Sounds.MAX_VOICES)
local ready = false
local groups: { [string]: SoundGroup } = {}
local baseVolume: { [string]: number } = {}
local muted: { [string]: boolean } = {}
local pools: { [string]: { Sound } } = {}
local poolNext: { [string]: number } = {}
local warned: { [string]: boolean } = {}
local soundFolder: Folder
local duckToken = 0
local ducking = false

local function note(key: string, message: string)
	if RunService:IsStudio() and not warned[key] then
		warned[key] = true
		print("[GameAudio] " .. message)
	end
end

local function applyVolume(group: string)
	local sg = groups[group]
	if sg == nil then
		return
	end
	local v = if muted[group] then 0 else baseVolume[group]
	if group == "Music" and ducking then
		v *= Sounds.DUCK_TO
	end
	sg.Volume = v
end

local function setup()
	if ready then
		return
	end
	ready = true
	local master = Instance.new("SoundGroup")
	master.Name = "GameAudio"
	master.Volume = 1
	master.Parent = SoundService
	for name, volume in Sounds.groups do
		local sg = Instance.new("SoundGroup")
		sg.Name = name
		sg.Parent = master -- nested groups multiply with the master
		groups[name] = sg
		baseVolume[name] = volume
		applyVolume(name)
	end
	soundFolder = Instance.new("Folder")
	soundFolder.Name = "GameAudioSounds"
	soundFolder.Parent = SoundService

	-- Build the pools for everything that has an asset, and preload them in the background.
	local toLoad = {}
	for name, sound in Sounds.list do
		local asset = Sounds.assetFor(sound)
		if asset and not sound.looped then
			local pool = {}
			for i = 1, sound.voices or 2 do
				local s = Instance.new("Sound")
				s.Name = name .. i
				s.SoundId = asset
				s.Volume = sound.volume
				s.SoundGroup = groups[sound.group]
				s.Parent = soundFolder
				table.insert(pool, s)
				table.insert(toLoad, s)
			end
			pools[name] = pool
		end
	end
	task.spawn(function()
		pcall(ContentProvider.PreloadAsync, ContentProvider, toLoad)
	end)
end

local function semitones(pitch: number?): number
	return 2 ^ ((pitch or 0) / 12)
end

-- Music ---------------------------------------------------------------------------

local ambienceName: string? = nil
local ambienceSound: Sound? = nil

local musicContext: string? = nil
local musicToken = 0
local musicSound: Sound? = nil
local musicIndex = 1
-- Where each context's music was when we left it, so coming back picks up mid-track.
local resumeAt: { [string]: { index: number, position: number } } = {}

local function fadeOut(sound: Sound)
	local t = TweenService:Create(sound, TweenInfo.new(Sounds.MUSIC_FADE), { Volume = 0 })
	t.Completed:Connect(function()
		sound:Destroy()
	end)
	t:Play()
end

local function playTrack(context: string, index: number, token: number, startAt: number?)
	local list = Sounds.music[context]
	if list == nil or #list == 0 or token ~= musicToken then
		return
	end
	musicIndex = index
	local track = list[(index - 1) % #list + 1]
	local s = Instance.new("Sound")
	s.Name = "Music_" .. context
	s.SoundId = track.id
	s.Volume = 0
	s.Looped = #list == 1
	s.SoundGroup = groups.Music
	s.Parent = soundFolder
	s.TimePosition = startAt or 0
	s:Play()
	musicSound = s
	TweenService:Create(s, TweenInfo.new(Sounds.MUSIC_FADE), { Volume = track.volume }):Play()
	if #list > 1 then
		s.Ended:Connect(function()
			s:Destroy()
			task.delay(Sounds.MUSIC_GAP, playTrack, context, index + 1, token)
		end)
	end
end

function GameAudio.setMusic(context: string?)
	setup()
	if context == musicContext then
		return
	end
	if musicSound and musicContext then
		resumeAt[musicContext] = { index = musicIndex, position = musicSound.TimePosition }
	end
	musicContext = context
	musicToken += 1
	if musicSound then
		fadeOut(musicSound)
		musicSound = nil
	end
	if context then
		local resume = resumeAt[context]
		resumeAt[context] = nil
		if resume then
			playTrack(context, resume.index, musicToken, resume.position)
		else
			playTrack(context, 1, musicToken)
		end
	end
	-- Each context brings its own ambience bed, or none (Crop Pop).
	GameAudio.setAmbience(if context then Sounds.contextAmbience[context] else nil)
end

function GameAudio.getMusic(): string?
	return musicContext
end

-- Where the player is in the world ("Farm" on their own farm, "Visit" on someone else's).
-- Crop Pop's screen sits on top: while it's open the world's music waits for it to close.
local worldContext = "Farm"
local inPuzzle = false

function GameAudio.setWorld(context: string)
	worldContext = context
	if not inPuzzle then
		GameAudio.setMusic(context)
	end
end

function GameAudio.setAmbience(name: string?)
	setup()
	if name == ambienceName then
		return
	end
	ambienceName = name
	if ambienceSound then
		fadeOut(ambienceSound)
		ambienceSound = nil
	end
	local sound = name and Sounds.list[name]
	local asset = sound and Sounds.assetFor(sound)
	if sound and asset then
		local s = Instance.new("Sound")
		s.Name = "Ambience_" .. (name :: string)
		s.SoundId = asset
		s.Looped = true
		s.Volume = 0
		s.SoundGroup = groups[sound.group]
		s.Parent = soundFolder
		s:Play()
		TweenService:Create(s, TweenInfo.new(Sounds.MUSIC_FADE * 2), { Volume = sound.volume }):Play()
		ambienceSound = s
	end
end

-- Dips the music for `seconds` (fanfares and jingles), then brings it back.
function GameAudio.duck(seconds: number)
	setup()
	duckToken += 1
	local token = duckToken
	ducking = true
	applyVolume("Music")
	task.delay(seconds + 0.3, function()
		if token == duckToken then
			ducking = false
			local sg = groups.Music
			local target = if muted.Music then 0 else baseVolume.Music
			TweenService:Create(sg, TweenInfo.new(0.8), { Volume = target }):Play()
		end
	end)
end

-- Effects -------------------------------------------------------------------------

export type PlayOptions = { pitch: number?, volume: number? }

function GameAudio.play(name: string, opts: PlayOptions?): boolean
	setup()
	GameAudio.stats[name] = (GameAudio.stats[name] or 0) + 1
	local sound = Sounds.list[name]
	if sound == nil then
		warn("[GameAudio] no sound named " .. name)
		return false
	end
	local pool = pools[name]
	if pool == nil then
		note(name, name .. ": not uploaded yet, silent (" .. tostring(sound.file) .. ")")
		return false
	end
	if muted[sound.group] or not mixer:tryStart(name, sound, os.clock()) then
		return false
	end
	-- Round robin over the pool, preferring a voice that isn't playing.
	local start = poolNext[name] or 1
	local voice = pool[start]
	for i = 0, #pool - 1 do
		local candidate = pool[(start + i - 1) % #pool + 1]
		if not candidate.IsPlaying then
			voice = candidate
			break
		end
	end
	poolNext[name] = start % #pool + 1
	voice.PlaybackSpeed = semitones(opts and opts.pitch)
	voice.Volume = sound.volume * (opts and opts.volume or 1)
	voice.TimePosition = 0
	voice:Play()
	if sound.duck then
		GameAudio.duck(sound.length or 1)
	end
	return true
end

-- Positional loops ----------------------------------------------------------------

local LOOP_NEAR = 12 -- studs: full volume this close
local LOOP_FAR = 70 -- studs: silent past this (a plot is about 290 across)

export type LoopHandle = { stop: () -> () }

-- Plays a looped sound from `parent` (a BasePart or Attachment), so it fades with distance
-- like the building it comes from. Silent (but still a handle) until the sound has an asset.
function GameAudio.attachLoop(name: string, parent: Instance, opts: PlayOptions?): LoopHandle
	setup()
	GameAudio.stats[name] = (GameAudio.stats[name] or 0) + 1
	local sound = Sounds.list[name]
	local asset = sound and Sounds.assetFor(sound)
	if sound == nil or asset == nil then
		if sound == nil then
			warn("[GameAudio] no sound named " .. name)
		else
			note(name, name .. ": not uploaded yet, silent (" .. tostring(sound.file) .. ")")
		end
		return { stop = function() end }
	end
	local s = Instance.new("Sound")
	s.Name = "Loop_" .. name
	s.SoundId = asset
	s.Looped = true
	s.Volume = 0
	s.PlaybackSpeed = semitones(opts and opts.pitch)
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = LOOP_NEAR
	s.RollOffMaxDistance = LOOP_FAR
	s.SoundGroup = groups[sound.group]
	s.Parent = parent
	-- Start somewhere in the loop, so two busy factories side by side don't chug in step.
	s.TimePosition = (sound.length or 0) * math.random()
	s:Play()
	TweenService:Create(s, TweenInfo.new(0.6), { Volume = sound.volume * (opts and opts.volume or 1) }):Play()
	local stopped = false
	return {
		stop = function()
			if not stopped then
				stopped = true
				fadeOut(s)
			end
		end,
	}
end

export type Cue = { sound: string, pitch: number?, delay: number? }

function GameAudio.playCues(cues: { Cue })
	for _, cue in cues do
		if cue.delay and cue.delay > 0 then
			task.delay(cue.delay, GameAudio.play, cue.sound, { pitch = cue.pitch })
		else
			GameAudio.play(cue.sound, { pitch = cue.pitch })
		end
	end
end

-- Crop Pop hooks (called through croppop/src/client/Sfx.luau) --------------------------

function GameAudio.cropPopPhase(phase: { [string]: any }, popIndex: number?)
	GameAudio.playCues(CropPopCues.phase(phase, popIndex))
end

function GameAudio.cropPopEvent(name: string)
	if name == "Open" then
		inPuzzle = true
		GameAudio.setMusic("Puzzle")
	elseif name == "Close" then
		inPuzzle = false
		GameAudio.setMusic(worldContext)
	else
		GameAudio.playCues(CropPopCues.event(name))
	end
end

-- Volume groups -------------------------------------------------------------------

function GameAudio.setVolume(group: string, volume: number)
	setup()
	assert(baseVolume[group] ~= nil, "unknown volume group " .. group)
	baseVolume[group] = math.clamp(volume, 0, 1)
	applyVolume(group)
end

function GameAudio.getVolume(group: string): number
	setup()
	return baseVolume[group]
end

function GameAudio.setMuted(group: string, isMuted: boolean)
	setup()
	assert(baseVolume[group] ~= nil, "unknown volume group " .. group)
	muted[group] = isMuted
	applyVolume(group)
end

function GameAudio.isMuted(group: string): boolean
	return muted[group] == true
end

return GameAudio
